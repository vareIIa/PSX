## Um chunk virando no AOS POUCOS, com orcamento de tempo por quadro
## (PLANO_DESEMPENHO_E_HORIZONTE, Fase 2).
##
## O defeito
## ---------
## `ChunkManager._montar` fazia tudo num quadro so: malhas, colisao, oclusor e
## TODOS os props. Dirigindo a 70 km/h entram ~3 chunks por segundo, e o quadro
## do chunk durava 18-20 ms de mediana e ate 73 ms (24/09/2026). Medido parte
## por parte em `tests/bancada_custo_chunk.gd` (40 chunks do trajeto): malhas
## 0,8 ms de mediana, colisao e oclusor quase nada — e os props pesados juntos
## no mesmo quadro: gente parada a 2,3 ms cada (a primeira, fria, 108 ms), a TV
## do bar e a sinuca perto de 20 ms.
##
## O desenho
## ---------
## Cada chunk pronto na thread vira uma MONTAGEM que anda por etapas:
##
##   encomendas o corpo de cada convidado e morador do chunk vai montar no
##              WorkerThreadPool (`VariantesDeCorpo`): quando o prop nascer, la
##              em `props`, o Corpo so pendura (2,2 ms -> 0,2 ms cada)
##   malhas    uma superficie por vez, ate o prazo do quadro
##   colisao   o corpo inteiro e o oclusor (baratos, medidos)
##   entrar    o no entra na arvore com o alcance de desenho ja aplicado
##   props     um por vez, ate o prazo do quadro
##   pronto    alcance reaplicado (cobre os props), e so AQUI o chunk passa a
##             contar como carregado e o sinal sai
##
## "Carregado" continua querendo dizer COMPLETO: transito, blitz, NPC e mapa
## perguntam `esta_carregado` para decidir se podem por coisa em cima.
##
## O prazo e dividido entre as montagens da mais perta para a mais longe, e
## cada quadro faz pelo menos UM passo, senao um prop mais caro que o prazo
## travaria a fila para sempre.
##
## `--montagem-inteira` volta ao `_montar` de um quadro so: e o par da bancada.
##
## Casca e promocao (Horizonte, passo 1)
## -------------------------------------
## No anel visual, alem do raio de simulacao, o chunk e so CASCA (`casca`):
## malhas sem o balde @perto e o oclusor; nada de encomenda, colisao ou prop.
## Quando o jogador chega, a casca e PROMOVIDA (`promover`) no mesmo no: entram
## as malhas @perto, o corpo de colisao e os props. `tirar_simulacao` faz o
## caminho de volta. As pecas que sao da casca levam a meta `casca`.
class_name MontagemDeChunk
extends RefCounted

## Tempo de montagem por quadro, em microssegundos. Um chunk tipico cabe em um
## ou dois quadros; dirigindo entram tres por segundo.
const ORCAMENTO_US := 2500

enum Etapa { ENCOMENDAS, MALHAS, COLISAO, ENTRAR, PROPS, PRONTO }

var coord: Vector2i
var dados: Dictionary
var no: Node3D
var etapa: Etapa = Etapa.ENCOMENDAS

var _materiais: Array = []
var _i_mat := 0
var _i_prop := 0
var _i_encomenda := 0
## So malhas de longe e oclusor: termina sem colisao nem prop.
var so_casca := false
## O no ja e uma casca na arvore: so entra o que falta para o chunk completo.
var promovendo := false


func _init(c: Vector2i, d: Dictionary, existente: Node3D = null) -> void:
	coord = c
	dados = d
	var superficies: Dictionary = d["superficies"]
	_materiais = superficies.keys()
	if existente != null:
		no = existente
	else:
		no = Node3D.new()
		no.name = "chunk_%03d_%03d" % [c.x, c.y]
		no.position = Vector3(c.x * ChunkManager.TAM, 0.0, c.y * ChunkManager.TAM)
	no.set_meta(&"triangulos", d["triangulos"])
	if ChunkManager.guardar_superficies:
		no.set_meta(&"superficies", superficies)


## A casca do anel visual: as malhas que se veem de longe e o oclusor.
static func casca(c: Vector2i, d: Dictionary) -> MontagemDeChunk:
	var m := MontagemDeChunk.new(c, d)
	m.so_casca = true
	m.etapa = Etapa.MALHAS
	m._materiais = m._materiais.filter(func(x: Variant) -> bool:
		return not ChunkManager.e_perto(StringName(x)))
	# A casca nao tem chao para a grama: a meta so volta na promocao.
	m.no.remove_meta(&"superficies")
	return m


## A casca `existente` vira chunk completo, com os dados de uma construcao nova
## (a mesma semente: as malhas que ja estao penduradas sao as mesmas).
static func promover(c: Vector2i, d: Dictionary, existente: Node3D) -> MontagemDeChunk:
	var m := MontagemDeChunk.new(c, d, existente)
	m.promovendo = true
	m._materiais = m._materiais.filter(func(x: Variant) -> bool:
		return ChunkManager.e_perto(StringName(x)))
	return m


## Volta a casca: sai tudo o que nao e dela (colisao, props, malhas @perto e o
## que outros sistemas penduraram no chunk, como a grama). Sai da arvore agora,
## e nao no fim do quadro, para uma promocao seguinte nao achar nome ocupado.
static func tirar_simulacao(alvo: Node3D) -> void:
	if not is_instance_valid(alvo):
		return
	alvo.remove_meta(&"superficies")
	for filho: Node in alvo.get_children():
		if filho.has_meta(&"casca"):
			continue
		alvo.remove_child(filho)
		filho.queue_free()


## Anda ate `prazo_us` (relogio de `Time.get_ticks_usec`). Faz pelo menos um
## passo. Devolve verdadeiro quando o chunk esta completo.
func andar(prazo_us: int) -> bool:
	var primeiro := true
	while etapa != Etapa.PRONTO:
		if not primeiro and Time.get_ticks_usec() >= prazo_us:
			return false
		primeiro = false
		_passo()
	return true


func _passo() -> void:
	match etapa:
		Etapa.ENCOMENDAS:
			if so_casca:
				etapa = Etapa.MALHAS
				return
			# Um convidado por passo: a ficha do registro custa ~0,1 ms.
			var props: Array = dados["props"]
			while _i_encomenda < props.size():
				var prop: Dictionary = props[_i_encomenda]
				_i_encomenda += 1
				var tipo := String(prop.get("tipo", ""))
				if tipo == "convidado" or tipo == "morador":
					var ficha := RegistroCivil.identidade(ChunkManager.id_do_convidado(prop))
					if not ficha.is_empty():
						VariantesDeCorpo.encomendar(ficha.get("aparencia", {}))
					return
			etapa = Etapa.MALHAS
		Etapa.MALHAS:
			if _i_mat >= _materiais.size():
				etapa = Etapa.COLISAO
				return
			var material: StringName = _materiais[_i_mat]
			_i_mat += 1
			_malha(material)
		Etapa.COLISAO:
			# A casca ja trouxe o oclusor; a casca nao leva corpo.
			ChunkManager.montar_colisao(no, dados, not so_casca, not promovendo)
			etapa = Etapa.ENTRAR
		Etapa.ENTRAR:
			if not no.is_inside_tree():
				ChunkManager.raiz.add_child(no)
				ChunkManager.versao_desenho += 1
			ChunkManager._aplicar_alcance(no)
			etapa = Etapa.PRONTO if so_casca else Etapa.PROPS
		Etapa.PROPS:
			var props: Array = dados["props"]
			if _i_prop >= props.size():
				# Os props que desenham (a placa da rua) entram no mesmo alcance
				# que `_montar` dava: a reaplicacao cobre os filhos novos.
				ChunkManager._aplicar_alcance(no)
				etapa = Etapa.PRONTO
				return
			var prop: Dictionary = props[_i_prop]
			_i_prop += 1
			ChunkManager._coord_do_prop = coord
			var criado := ChunkManager._criar_prop(prop)
			if criado != null:
				no.add_child(criado)


func _malha(material: StringName) -> void:
	var superficies: Dictionary = dados["superficies"]
	var d: Dictionary = superficies[material]
	if PSXMesh.dados_vazio(d):
		return
	var mi := MeshInstance3D.new()
	mi.name = String(material)
	mi.mesh = ChunkManager.malha_de(dados, material)
	var base_mat := StringName(String(material).get_slice("@", 0))
	ChunkManager.marcar_balde(mi, material)
	mi.material_override = ChunkManager._material(base_mat)
	mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if ChunkManager.SEM_SOMBRA.has(base_mat)
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	if no.is_inside_tree():
		ChunkManager.aplicar_alcance_em(mi)
	no.add_child(mi)


## Desfaz uma montagem que saiu do alcance antes de terminar. A promocao leva a
## casca junto: quem cancela uma promocao e porque o chunk saiu de todo raio.
func cancelar() -> void:
	if is_instance_valid(no):
		if no.is_inside_tree():
			no.queue_free()
		else:
			no.free()

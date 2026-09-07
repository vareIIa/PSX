## Autoload. Entra e sai de interiores sem tela de carregamento.
##
## A promessa da Fase 4 e que a porta abra e o jogador entre, sem corte. O truque
## tem tres partes:
##
##   1. O interior e construido numa thread, no mesmo formato do chunk.
##   2. A construcao comeca junto com a animacao da porta, que dura 1,2 s.
##   3. Os chunks da rua ficam carregados, so escondidos, entao sair e imediato.
##
## Manter a cidade na memoria custa uns 48 MB e paga com uma saida instantanea.
## Descarregar e recarregar levaria os mesmos 49 chunks de volta pela fila.
extends Node

## Interiores vivem bem acima da cidade. Separar por espaco em vez de por cena
## evita trocar de arvore, que e o que faria a rua ter de recarregar na volta.
const DESLOCAMENTO := Vector3(0.0, 2000.0, 0.0)

## Duracao da abertura da porta. E o orcamento de tempo da construcao, e ainda
## sobra a cortina depois dela para esconder a troca.
const ABERTURA := 1.2

const MAT_DIR := "res://resources/materials/mat_%s.tres"

signal entrou()
signal saiu()

var dentro: bool = false

var _raiz: Node3D
var _no: Node3D
var _retorno := Transform3D()
var _semente: int = 0
var _tipo: StringName = &"apartamento"

## Comodos abertos por dentro de outro comodo, do mais antigo para o mais novo.
##
## Existe por causa da estufa. A porta dos fundos da casa da fumaca nao leva a
## rua: leva a outro interior, e sair de la tem de devolver o jogador para a
## SALA, e nao para a calcada. Sem pilha, `sair` so conhece um destino.
##
## Cada item guarda o que e preciso para reconstruir o comodo de tras — semente
## e planta — mais onde o jogador reaparece nele, que e do lado de dentro da
## porta que ele acabou de atravessar.
var _pilha: Array[Dictionary] = []

## Entrada forcada do proximo comodo, quando ele nao e entrado pela porta da
## frente. Vazio quer dizer "use a entrada da planta".
var _forcado: Dictionary = {}
var _tarefa: int = -1
var _dados: Dictionary = {}
var _mutex := Mutex.new()
var _pronto_em: float = 0.0
var _materiais: Dictionary[StringName, ShaderMaterial] = {}

## Cortina preta da troca. Sem ela o jogador e teleportado no meio de um quadro
## e o corte aparece, o que joga fora todo o trabalho de esconder a construcao.
const FECHA := 0.22
const ABRE := 0.34
var _cortina: ColorRect


func _ready() -> void:
	set_process(false)
	_montar_cortina()


func _montar_cortina() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 140
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada)

	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_cortina)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)


func _escurecer(duracao: float) -> void:
	var t := create_tween()
	t.tween_property(_cortina, "color:a", 1.0, duracao)
	await t.finished


func _clarear(duracao: float) -> void:
	create_tween().tween_property(_cortina, "color:a", 0.0, duracao)


## Comeca a entrada. `retorno` e para onde o jogador volta ao sair, e `tipo` diz
## que planta montar: &"apartamento" ou &"casa".
func entrar(semente: int, retorno: Transform3D,
		tipo: StringName = &"apartamento") -> void:
	if dentro or _tarefa >= 0:
		return
	_retorno = retorno
	_pilha.clear()
	_forcado = {}
	_iniciar(semente, tipo, ABERTURA)


## Passa de um interior para outro sem voltar a rua.
##
## `volta` e `volta_olhar` sao onde o jogador reaparece AQUI quando sair de la —
## do lado de dentro da porta que ele esta atravessando, olhando para o comodo.
## Sem isso ele voltaria ao ponto de entrada da casa, do outro lado da sala, e a
## porta dos fundos leria como teleporte.
func atravessar(semente: int, tipo: StringName, volta: Vector3,
		volta_olhar: Vector3) -> void:
	if not dentro or _tarefa >= 0:
		return
	_pilha.append({
		"semente": _semente, "tipo": _tipo,
		"pos": volta, "olhar": volta_olhar,
	})
	_iniciar(semente, tipo, ABERTURA)


## Comeca a construcao de um comodo. `espera` e o orcamento de tempo da
## animacao da porta: a construcao pode acabar antes, mas entrar antes de a
## porta terminar de abrir entrega que o interior ja estava pronto.
func _iniciar(semente: int, tipo: StringName, espera: float) -> void:
	_semente = semente
	_tipo = tipo
	_pronto_em = float(Time.get_ticks_msec()) / 1000.0 + espera
	_dados = {}
	_tarefa = WorkerThreadPool.add_task(_construir.bind(semente, tipo), false, "interior")
	set_process(true)


func sair() -> void:
	if not dentro or _tarefa >= 0:
		return

	# Comodo aberto por dentro de outro: sair volta para o de tras, e nao para a
	# rua. A cortina ja esta fechada, entao a construcao nao precisa de orcamento
	# de tempo nenhum — o que ela tem de esconder ja esta escondido.
	if not _pilha.is_empty():
		var anterior: Dictionary = _pilha.pop_back()
		dentro = false
		await _escurecer(FECHA)
		_forcado = {"pos": anterior["pos"], "olhar": anterior["olhar"]}
		_iniciar(int(anterior["semente"]), StringName(anterior["tipo"]), 0.0)
		return

	dentro = false
	await _escurecer(FECHA)

	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		jogador.global_transform = _retorno
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")

	if _no != null:
		_no.queue_free()
		_no = null

	_mostrar_cidade(true)
	_liberar_ambiente()
	_clarear(ABRE)
	saiu.emit()


func _exit_tree() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
	if _no != null and is_instance_valid(_no):
		_no.free()
		_no = null
	_pilha.clear()
	_dados.clear()
	_materiais.clear()


## Onde se acrescenta um lugar novo.
##
## Todo builder devolve o mesmo contrato — superficies, props, colisao, entrada,
## olhar, saida e, opcionalmente, ambiente — entao quem chama nunca precisa
## saber que planta e essa. Lugar novo custa uma linha aqui e um arquivo de
## planta; nada mais no resto do sistema muda.
static func _planta(tipo: StringName, semente: int) -> Dictionary:
	match tipo:
		&"casa":
			return CasaBuilder.construir(semente)
		&"mercado":
			return MercadoBuilder.construir(semente)
		&"casa_fumaca":
			return CasaFumacaBuilder.construir(semente)
		&"estufa":
			return EstufaBuilder.construir(semente)
		_:
			return InteriorBuilder.construir(semente)


func _construir(semente: int, tipo: StringName) -> void:
	# A escolha da planta e feita aqui dentro, na thread, e nao antes: e o
	# trabalho pesado, e e para isso que existe a thread.
	var d := _planta(tipo, semente)
	_mutex.lock()
	_dados = d
	_mutex.unlock()


func _process(_delta: float) -> void:
	if _tarefa < 0:
		set_process(false)
		return

	_mutex.lock()
	var pronto := not _dados.is_empty()
	_mutex.unlock()
	if not pronto:
		return
	# Espera a porta terminar de abrir mesmo que a construcao acabe antes. Entrar
	# no meio da animacao entrega que o interior ja estava pronto.
	if float(Time.get_ticks_msec()) / 1000.0 < _pronto_em:
		return

	WorkerThreadPool.wait_for_task_completion(_tarefa)
	_tarefa = -1
	set_process(false)
	# Fecha a cortina antes de trocar o mundo por baixo do jogador.
	await _escurecer(FECHA)
	_materializar()
	_clarear(ABRE)


func _materializar() -> void:
	var arvore := get_tree().current_scene
	if arvore == null:
		return

	# Trocar de comodo sem voltar a rua deixa o anterior na arvore. Ele sai
	# aqui, e nao em `sair`: entre o pedido e este ponto passa a construcao
	# inteira na thread, e o jogador continuaria de pe dentro dele.
	if _no != null and is_instance_valid(_no):
		_no.queue_free()
		_no = null

	_no = Node3D.new()
	_no.name = "Interior"
	_no.position = DESLOCAMENTO

	var superficies: Dictionary = _dados["superficies"]
	for material: StringName in superficies:
		var d: Dictionary = superficies[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no.add_child(mi)

	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in _dados["colisao"]:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		corpo.add_child(forma)
	_no.add_child(corpo)

	for prop: Dictionary in _dados["props"]:
		var criado := _criar_prop(prop)
		if criado != null:
			_no.add_child(criado)

	_no.add_child(_saida())
	arvore.add_child(_no)

	var entrada: Vector3 = _dados["entrada"]
	var olhar: Vector3 = _dados["olhar"]
	if not _forcado.is_empty():
		entrada = _forcado["pos"]
		olhar = _forcado["olhar"]
		_forcado = {}
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		jogador.global_position = DESLOCAMENTO + entrada + Vector3(0.0, 0.15, 0.0)
		if jogador.has_method("olhar_para"):
			jogador.call("olhar_para", DESLOCAMENTO + olhar)
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")

	_mostrar_cidade(false)
	_forcar_ambiente()
	dentro = true
	entrou.emit()


## Cria um prop do interior. Mesmo esquema do ChunkManager: a thread devolve
## descricao, e a criacao de no acontece so aqui.
func _criar_prop(prop: Dictionary) -> Node3D:
	var tipo: String = prop.get("tipo", "")

	if tipo == "lampada":
		var l := Lampada.new()
		l.position = prop["pos"]
		l.padrao = prop["padrao"]
		l.semente = prop["semente"]
		l.cor = prop.get("cor", Color("ffe0b0"))
		l.energia = prop.get("energia", 1.5)
		l.alcance = prop.get("alcance", 6.0)
		l.facho_visivel = prop.get("facho", false)
		# A geometria do facho vem do prop quando ele pede. O padrao da Lampada e
		# de POSTE — 3,1 m de raio e 6,3 m de altura — e num comodo de tres
		# metros de pe direito um cone desse tamanho atravessa o teto e estoura
		# metade da imagem em branco. Foi o que a primeira captura da estufa
		# mostrou, e nao ha aviso nenhum que pegue isso.
		l.raio_topo = float(prop.get("raio_topo", l.raio_topo))
		l.raio_base = float(prop.get("raio_base", l.raio_base))
		l.altura_facho = float(prop.get("altura_facho", l.altura_facho))
		return l

	if tipo == "npc":
		var npc := Npc.new()
		npc.position = prop["pos"]
		npc.giro_inicial = prop.get("giro", 0.0)
		npc.semente = prop.get("semente", _semente)
		# A ficha e resolvida AQUI, e nao no builder. `RegistroCivil.identidade`
		# mantem cache, e o builder roda no WorkerThreadPool: consultar o
		# registro de la e uma corrida esperando a hora de acontecer. O builder
		# manda so a faixa de idade que o perfil da casa pede.
		var id := RegistroCivil.id_de_faixa(int(prop.get("semente", _semente)),
			int(prop.get("idade_min", 30)), int(prop.get("idade_max", 80)))
		npc.preparar(RegistroCivil.identidade(id), int(prop.get("perfil", 0)))
		return npc

	if tipo == "televisao":
		var tv := Televisao.new()
		tv.position = prop["pos"]
		tv.giro = prop.get("giro", 0.0)
		return tv

	if tipo == "convidado":
		return _criar_convidado(prop)

	if tipo == "ventilador":
		var v := Ventilador.new()
		v.position = prop["pos"]
		v.rotation.y = prop.get("giro", 0.0)
		v.oscila = bool(prop.get("oscila", true))
		v.fase = float(prop.get("fase", 0.0))
		return v

	if tipo == "porta_interna":
		return _porta_interna(prop)

	if tipo == "som_ambiente":
		return _criar_som(prop)

	if tipo == "porta_trancada":
		var porta := Porta.new()
		porta.position = prop["pos"]
		porta.rotation.y = prop.get("giro", 0.0)
		porta.trancada = true
		return porta

	if tipo == "save":
		var ponto := PontoDeSave.new()
		ponto.position = prop["pos"]
		ponto.rotation.y = prop.get("giro", 0.0)
		ponto.nome_do_local = prop.get("local", "Telefone")
		return ponto

	if tipo == "item":
		var item := ItemNoChao.new()
		item.position = prop["pos"]
		item.item_id = prop["item"]
		item.quantidade = prop.get("quantidade", 1)
		item.indice = prop.get("indice", 0)
		# Interiores nao tem coordenada de chunk, entao o item e registrado na
		# faixa reservada. Sem isso o bilhete da mesa volta toda vez que o
		# jogador entra de novo na casa.
		item.chunk = Vector2i(_semente, WorldState.INTERIOR)
		return item

	push_warning("Interiores: prop desconhecido '%s'" % tipo)
	return null


## Uma pessoa da casa da fumaca.
##
## A ficha vem do RegistroCivil como a de qualquer pedestre, e por isso da para
## conversar com ela, perguntar o nome e ver a identidade — a mesma carteira que
## sai na rua sai aqui. A faixa de idade e estreita de proposito: e uma casa de
## amigos de vinte anos, e a idade e a primeira coisa que o rosto entrega.
func _criar_convidado(prop: Dictionary) -> Node3D:
	var semente := int(prop.get("semente", _semente))
	var id := RegistroCivil.id_de_faixa(semente, 18, 26)
	var ficha := RegistroCivil.identidade(id)
	if ficha.is_empty():
		return null
	var c := Convidado.new()
	c.name = "convidado_%d" % id
	# Cada um destes precisa de tipo escrito a mao: o que sai de um Dictionary e
	# Variant, e o projeto trata declaracao sem tipo como erro. `as` nao serve
	# para enum nem para Vector3 — so para classe — entao a conversao vem da
	# anotacao, que e a forma que o resto do mundo usa (ver ChunkBuilder).
	var pontos: Array[Vector3] = []
	for bruto: Variant in prop.get("pontos", []):
		var ponto: Vector3 = bruto
		pontos.append(ponto)
	var papel: Convidado.Papel = prop.get("papel", Convidado.Papel.LIVRE)
	var foco: Vector3 = prop.get("foco", Vector3.ZERO)
	c.preparar(ficha, papel, pontos, bool(prop.get("fuma", false)), foco)
	c.position = prop["pos"]
	return c


## Uma fonte de som parada no espaco.
##
## Toca em laco e atenua com a distancia, entao a musica cresce conforme o
## jogador anda em direcao a ela. Isso e o oposto de trilha sonora: e um objeto
## que faz barulho, e o jogador pode andar ate ele e ver o que e.
##
## Se houver arquivo do usuario na pasta combinada, ele ganha do som gerado —
## e assim que se troca a trilha da casa sem tocar no jogo.
func _criar_som(prop: Dictionary) -> Node3D:
	var stream: AudioStream = null
	var pasta := String(prop.get("pasta", ""))
	if not pasta.is_empty():
		stream = AudioDirector.musica_do_usuario(pasta)
	if stream == null:
		stream = AudioDirector.stream(StringName(prop.get("som", &"")))
	if stream == null:
		return null

	var p := AudioStreamPlayer3D.new()
	p.name = "Som"
	p.bus = &"Music"
	p.stream = stream
	p.position = prop["pos"]
	p.volume_db = float(prop.get("volume", -12.0))
	p.max_distance = float(prop.get("alcance", 12.0))
	p.unit_size = 3.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	# Os WAV gerados nao sao marcados como laco no importador, porque varios
	# tambem servem de efeito curto. Reencadear no fim custa uma conexao e
	# funciona igual para arquivo do usuario, que pode ser de qualquer tamanho.
	p.finished.connect(p.play)
	# autoplay, e nao play(): este no ainda nao entrou na arvore — quem o
	# adiciona e _materializar, depois que _criar_prop devolve — e tocar antes
	# disso e erro de execucao.
	p.autoplay = true
	return p


## Porta que leva a outro interior, dentro deste.
##
## E irma da porta de saida e nao da porta da rua: a folha e a mesma, o tempo de
## abertura e o mesmo, e o que muda e o destino — em vez de `sair`, ela chama
## `atravessar`, que empilha este comodo antes de construir o proximo.
func _porta_interna(prop: Dictionary) -> Node3D:
	var area := Interativo.new()
	area.name = "PortaInterna"
	area.rotulo = String(prop.get("rotulo", "Abrir"))
	area.position = prop["pos"]

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = prop.get("tamanho", Vector3(1.3, 2.1, 1.0))
	forma.shape = box
	area.add_child(forma)

	var folha := Node3D.new()
	folha.name = "Folha"
	var dobradica: Vector3 = prop["dobradica"]
	folha.position = dobradica - area.position
	folha.rotation.y = float(prop.get("giro", 0.0))
	var mi := MeshInstance3D.new()
	mi.mesh = PSXMesh.box(Vector3(0.9, 2.05, 0.07), 1.0)
	mi.material_override = _material(&"porta")
	mi.position = Vector3(0.45, 1.025, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	folha.add_child(mi)
	area.add_child(folha)

	area.acionado.connect(func(_quem: Node) -> void:
		_abrir_interna(area, folha, prop))
	return area


func _abrir_interna(area: Interativo, folha: Node3D, prop: Dictionary) -> void:
	if not area.habilitado:
		return
	area.habilitado = false
	AudioDirector.tocar(&"porta_trinco", area.global_position, -4.0)

	var giro := folha.rotation.y
	var angulo := deg_to_rad(float(prop.get("angulo", 92.0)))
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func() -> void:
		AudioDirector.tocar(&"porta_abre", area.global_position, -6.0))
	t.tween_property(folha, "rotation:y", giro + angulo, 0.42)

	# A construcao comeca JUNTO com a folha, e nao depois dela: e a mesma
	# promessa da porta da rua, e o tempo da animacao e o orcamento dela.
	var volta: Vector3 = prop["volta"]
	var olhar: Vector3 = prop["volta_olhar"]
	atravessar(int(prop.get("semente", _semente)),
		StringName(prop.get("destino", &"apartamento")), volta, olhar)


## Porta de saida: area de acionamento mais a folha, que abre antes de o jogador
## sair. A folha existe pelo mesmo motivo da porta da rua — sem ela o jogador
## atravessaria um vao vazio e a casa nao teria fechado nunca.
func _saida() -> Node3D:
	var s: Dictionary = _dados.get("saida", {})
	var area := Interativo.new()
	area.name = "Saida"
	area.rotulo = "Sair"
	area.position = s.get("pos", Vector3(0.25, 1.0, InteriorBuilder.ENTRADA.z))

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = s.get("tamanho", Vector3(0.7, 2.0, 1.4))
	forma.shape = box
	area.add_child(forma)

	if s.has("deslizante"):
		var par := _folhas_deslizantes(area, s["deslizante"])
		area.acionado.connect(func(_quem: Node) -> void:
			_abrir_deslizante(area, par, s["deslizante"]))
		return area

	if not s.has("dobradica"):
		area.acionado.connect(func(_quem: Node) -> void: sair())
		return area

	var folha := Node3D.new()
	folha.name = "FolhaSaida"
	folha.position = s["dobradica"] - area.position
	folha.rotation.y = s.get("giro", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = PSXMesh.box(Vector3(0.9, 2.05, 0.07), 1.0)
	mi.material_override = _material(&"porta")
	mi.position = Vector3(0.45, 1.025, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	folha.add_child(mi)
	area.add_child(folha)

	area.acionado.connect(func(_quem: Node) -> void: _abrir_saida(area, folha, s))
	return area


## Duas folhas de vidro que correm para os lados. Devolve as duas, na ordem
## esquerda e direita em coordenada local da porta.
func _folhas_deslizantes(area: Interativo, d: Dictionary) -> Array[Node3D]:
	var giro: float = d.get("giro", 0.0)
	var largura: float = d.get("largura", 0.9)
	var altura: float = d.get("altura", 2.2)
	var centro: Vector3 = d["centro"] - area.position

	# O giro fica num no acima das folhas. Se ele estivesse na propria folha, o
	# deslizamento em X aconteceria no eixo do pai e nao no da porta, e uma porta
	# virada para outra direcao correria de lado errado.
	var base := Node3D.new()
	base.name = "PortaAutomatica"
	base.position = centro
	base.rotation.y = giro
	area.add_child(base)

	var par: Array[Node3D] = []
	for lado: float in [-1.0, 1.0]:
		var trilho := Node3D.new()
		trilho.name = "Folha%s" % ("E" if lado < 0.0 else "D")
		base.add_child(trilho)

		var mi := MeshInstance3D.new()
		# Vidro com caixilho: o quadro de aluminio e o que faz a folha ler como
		# porta de loja em vez de painel solto no vao.
		mi.mesh = PSXMesh.box(Vector3(largura, altura, 0.05), 1.0)
		mi.material_override = _material(&"mercado_vidro")
		mi.position = Vector3(lado * largura * 0.5, altura * 0.5, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trilho.add_child(mi)

		var caixilho := MeshInstance3D.new()
		caixilho.mesh = PSXMesh.box(Vector3(0.06, altura, 0.08), 1.0)
		caixilho.material_override = _material(&"metal")
		caixilho.position = Vector3(lado * (largura - 0.03), altura * 0.5, 0.0)
		caixilho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trilho.add_child(caixilho)

		par.append(trilho)
	return par


## Porta automatica: as folhas correm, esperam e o jogador sai.
##
## O tempo e mais curto que o da porta de dobradica porque porta automatica abre
## rapido, e uma que demora um segundo le como defeito.
func _abrir_deslizante(area: Interativo, par: Array[Node3D], d: Dictionary) -> void:
	if not area.habilitado:
		return
	area.habilitado = false
	AudioDirector.tocar(&"porta_desliza", area.global_position, -5.0)

	var curso: float = d.get("curso", 0.85)
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for k in par.size():
		var lado := -1.0 if k == 0 else 1.0
		t.tween_property(par[k], "position:x", par[k].position.x + lado * curso, 0.5)
	t.chain().tween_callback(sair)


func _abrir_saida(area: Interativo, folha: Node3D, s: Dictionary) -> void:
	if not area.habilitado:
		return
	area.habilitado = false
	AudioDirector.tocar(&"porta_trinco", area.global_position, -4.0)

	var giro := folha.rotation.y
	var angulo := deg_to_rad(float(s.get("angulo", 96.0)))
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func() -> void:
		AudioDirector.tocar(&"porta_abre", area.global_position, -6.0))
	t.tween_property(folha, "rotation:y", giro + angulo, 0.42)
	# A cortina de `sair` cobre o resto: a folha nao precisa terminar o curso
	# para o corte funcionar, precisa ter comecado.
	t.tween_callback(sair)


func _mostrar_cidade(visivel: bool) -> void:
	if ChunkManager.raiz != null:
		ChunkManager.raiz.visible = visivel
	var chuva := get_tree().current_scene.get_node_or_null("Chuva") as GPUParticles3D
	if chuva != null:
		chuva.visible = visivel
		chuva.emitting = visivel


## Ambiente do lugar. Cada planta pode pedir o seu: a casa e quente e baixa, e a
## loja de conveniencia e branca e chapada. Metade do que separa os dois comodos
## esta aqui, e nao daria para conseguir so com lampada.
func _forcar_ambiente() -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog == null:
		return
	fog.forcar(String(_dados.get("ambiente", "res://resources/fog/fog_interior.tres")))


func _liberar_ambiente() -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		fog.liberar()


func _material(nome: StringName) -> ShaderMaterial:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho := MAT_DIR % nome
	if not ResourceLoader.exists(caminho):
		push_error("Interiores: material ausente %s" % caminho)
		return null
	var m := load(caminho) as ShaderMaterial
	_materiais[nome] = m
	return m

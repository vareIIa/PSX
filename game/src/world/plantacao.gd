## A plantacao viva: os vasos, o que cresce neles e a prateleira que enche.
##
## Tudo o que esta sala mostra sai de `Plantio`, que nao tem no nenhum. Este
## arquivo so traduz numero em malha e em area de interacao, e e por isso que o
## fazendeiro que trabalha com o jogador olhando e o que trabalhou enquanto ele
## estava fora chegam ao mesmo resultado: nao existe uma segunda regra aqui.
##
## Uma malha, e nao vinte e quatro nos
## -----------------------------------
## Cada vaso podia ser um no com a propria malha. Seriam 24 MeshInstance3D numa
## sala so, contra um orcamento de 120 chamadas de desenho no jogo inteiro (ver
## ART-BIBLE), e tudo isso para mostrar uma coisa que muda de dois em dois
## minutos.
##
## Entao a plantacao inteira e UMA malha por material, refeita quando alguma
## coisa muda de verdade. Refazer custa uns 600 triangulos de construcao — menos
## que um quadro de um carro — e acontece quando o jogador rega, quando o
## fazendeiro colhe, ou a cada vez que o crescimento anda o bastante para
## aparecer na tela. O resto do tempo nao custa nada.
##
## As areas de interacao sao Area3D, que nao desenham nada, e essas sim sao uma
## por vaso: e o alvo do raio da camera, e ele precisa saber em qual vaso o
## jogador esta olhando.
class_name Plantacao
extends Node3D

## De quanto em quanto tempo o crescimento e reavaliado. Meio segundo: o relogio
## anda ao dobro do tempo real, entao meio segundo real e um minuto de relogio a
## cada 30 s — reavaliar mais rapido que isso e conta que nao muda nada.
const PASSO := 0.5

## Quanto o crescimento precisa andar para valer uma malha nova. 4% da altura de
## uma planta e menos de um pixel a 480x270 na distancia do corredor; abaixo
## disso refazer a malha e trabalho que ninguem ve.
const DEGRAU := 0.04

const VASO := 0.46
const PLANTA := 1.22
## Altura do broto recem-regado. Nao e zero: vaso com terra molhada e nada
## dentro e igual a vaso com terra seca, e o jogador que acabou de regar merece
## ver que alguma coisa aconteceu.
const BROTO := 0.18

## Quanto sai do saco e da caixa por vez. Quatro cargas de terra e duas sementes
## e o bastante para o jogador plantar um vaso inteiro sem voltar, e pouco o
## bastante para a estacao de insumos continuar sendo um lugar aonde se vai.
const TERRA_POR_VEZ := 4
const SEMENTES_POR_VEZ := 2

const ITEM_TERRA: StringName = &"terra"
const ITEM_SEMENTE: StringName = &"semente_maconha"
const ITEM_REGADOR: StringName = &"regador"
const ITEM_COLHEITA: StringName = &"maconha"

signal mudou()

var semente: int = 0
## Onde esta cada vaso, em coordenada da planta do comodo.
var vasos_em: Array[Vector3] = []
## Os nove lugares da prateleira de potes, do primeiro a encher ao ultimo.
var potes_em: Array[Vector3] = []
## Estacao de insumos: onde pegar terra, semente e agua. Vazio esconde a area.
var saco_em := Vector3.ZERO
var caixa_em := Vector3.ZERO
var tanque_em := Vector3.ZERO

var _estado: Dictionary = {}
var _malhas: Dictionary[StringName, MeshInstance3D] = {}
var _areas: Array[Interativo] = []
var _desde_o_passo: float = 0.0
var _assinatura: PackedFloat32Array = PackedFloat32Array()
var _triangulos: int = 0


func _ready() -> void:
	add_to_group(&"plantacao")
	_estado = Plantio.sincronizar(semente, vasos_em.size(),
		Profissoes.quantos(&"fazendeiro"))
	_montar_areas()
	_montar_insumos()
	_refazer()
	set_process(true)


func vasos() -> Array:
	return _estado.get("vasos", [])


func colhido() -> int:
	return int(_estado.get("colhido", 0))


func agua_do_regador() -> int:
	return int(_estado.get("regador", 0))


func triangulos() -> int:
	return _triangulos


# --- o tempo ----------------------------------------------------------------

func _process(delta: float) -> void:
	_desde_o_passo += delta
	if _desde_o_passo < PASSO:
		return
	_desde_o_passo = 0.0
	# O jogador esta na sala, entao o trabalho dos contratados acontece pelas
	# pernas deles e nao pela conta: `sincronizar` com zero fazendeiro. Quem
	# trabalha aqui dentro e o Convidado de rotina fazendeiro, e contar duas
	# vezes faria a plantacao andar ao dobro justo quando ha alguem olhando.
	var e := Plantio.sincronizar(semente, vasos_em.size(), 0)
	_estado = e
	if _mudou_o_bastante():
		_refazer()


## A malha so se refaz quando a imagem muda. Compara a assinatura visual — fase
## e altura de cada vaso, mais quanto tem na prateleira — e nao o estado inteiro:
## agua caindo de 0,81 para 0,80 nao muda um pixel.
func _mudou_o_bastante() -> bool:
	var v := vasos()
	var nova := PackedFloat32Array()
	nova.resize(Plantio.quantos(v) * 2 + 1)
	for i in Plantio.quantos(v):
		nova[i * 2] = float(int(Plantio.fase_de(v, i)))
		nova[i * 2 + 1] = Plantio.crescimento_de(v, i)
	nova[nova.size() - 1] = float(colhido())
	if _assinatura.size() != nova.size():
		return true
	for k in nova.size():
		if absf(nova[k] - _assinatura[k]) > (DEGRAU if k % 2 == 1 else 0.001):
			return true
	return false


# --- a malha ----------------------------------------------------------------

func _refazer() -> void:
	var sup: Dictionary = {}
	var v := vasos()
	for i in mini(Plantio.quantos(v), vasos_em.size()):
		_desenhar_vaso(sup, v, i)
	_desenhar_prateleira(sup)

	_triangulos = 0
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		_triangulos += PSXMesh.dados_triangulos(d)
		var mi: MeshInstance3D = _malhas.get(material, null)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = String(material)
			mi.material_override = Interiores.material(material)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_malhas[material] = mi
		mi.mesh = PSXMesh.dados_para_mesh(d)

	_assinatura = PackedFloat32Array()
	_assinatura.resize(Plantio.quantos(v) * 2 + 1)
	for i in Plantio.quantos(v):
		_assinatura[i * 2] = float(int(Plantio.fase_de(v, i)))
		_assinatura[i * 2 + 1] = Plantio.crescimento_de(v, i)
	_assinatura[_assinatura.size() - 1] = float(colhido())

	_atualizar_rotulos()
	mudou.emit()


## Um vaso e o que estiver dentro dele.
##
## O vaso e sempre o mesmo cubo de feltro; o que conta a fase e o TOPO dele. Um
## vaso vazio mostra o proprio feltro escuro por dentro, um com terra mostra
## terra, e terra recem-regada e a mesma celula mais escura. Nada disso custa
## textura nova: sao duas celulas e um tingimento de vertice.
func _desenhar_vaso(sup: Dictionary, v: Array, i: int) -> void:
	var base := vasos_em[i]
	var fase := Plantio.fase_de(v, i)
	var tem_terra := fase != Plantio.Fase.VAZIO
	var topo := EstufaBuilder.C_TERRA if tem_terra else EstufaBuilder.C_VASO
	var cor_topo := Color.WHITE
	if tem_terra:
		# Terra molhada e terra mais escura. E a unica leitura de agua que a
		# sala tem, e ela precisa existir: sem isso "regar" e um rotulo que nao
		# muda nada na tela, e o jogador para de regar.
		var molhada := Plantio.agua_de(v, i)
		cor_topo = Color(1.0, 1.0, 1.0).lerp(Color(0.50, 0.46, 0.42), molhada)
	elif not tem_terra:
		cor_topo = Color(0.42, 0.42, 0.44)

	AtlasKit.caixa(sup, EstufaBuilder.MAT, base + Vector3(0.0, VASO * 0.5, 0.0),
		Vector3(VASO, VASO, VASO), EstufaBuilder.C_VASO, Color.WHITE, 0.0,
		Vector2i(-1, -1), topo)

	# O topo de novo, 1 cm acima: `caixa` usa uma celula so para o topo e a cor
	# da caixa inteira, e a terra precisa de cor propria. Uma placa deitada
	# resolve sem duplicar a caixa.
	if fase != Plantio.Fase.VAZIO:
		AtlasKit.deitado(sup, EstufaBuilder.MAT,
			base + Vector3(0.0, VASO, 0.0), Vector2(VASO * 0.86, VASO * 0.86),
			topo, 0.0, cor_topo)

	if fase == Plantio.Fase.SEMEADO:
		# A estaca. E o unico jeito de um vaso semeado nao ser igual a um vaso
		# so com terra — e essa diferenca e metade do que o ciclo tem a mostrar.
		AtlasKit.caixa_livre(sup, EstufaBuilder.MAT,
			base + Vector3(0.09, VASO + 0.11, 0.04),
			Vector3(0.015, 0.22, 0.015), Basis(Vector3.FORWARD, 0.16),
			EstufaBuilder.C_MADEIRA, Color(0.86, 0.80, 0.68))
		return

	if fase != Plantio.Fase.CRESCENDO and fase != Plantio.Fase.PRONTA:
		return

	_desenhar_planta(sup, v, i, base)


## A planta, do broto ao pe carregado.
##
## Uma so medida governa o desenho: `crescimento`. Ela estica a altura, abre a
## largura, acrescenta a terceira placa cruzada la pelo meio do ciclo e, no fim,
## poe as cabecas floridas. Assim o jogador consegue OLHAR para um vaso e dizer
## quanto falta, sem barra, sem numero e sem abrir menu nenhum — que e como um
## jogo de 1999 diria isso.
func _desenhar_planta(sup: Dictionary, v: Array, i: int,
		base: Vector3) -> void:
	var cresc := Plantio.crescimento_de(v, i)
	var madura := Plantio.fase_de(v, i) == Plantio.Fase.PRONTA
	var altura: float = lerpf(BROTO, PLANTA, cresc)
	var larg: float = lerpf(0.22, 0.88, sqrt(cresc))

	# Variacao por vaso: altura, giro e um tom de verde. Vem do indice e nao de
	# sorteio, senao a planta muda de cara a cada malha refeita — e a malha se
	# refaz sozinha enquanto o jogador olha.
	var rng := RandomNumberGenerator.new()
	rng.seed = (semente * 31 + i) ^ 0x5A17
	altura *= rng.randf_range(0.88, 1.10)
	var giro := rng.randf_range(0.0, TAU)
	var verde := 0.88 + rng.randf() * 0.24
	# Broto e mais claro que planta feita. E o que a planta faz de verdade, e
	# tambem o que separa as primeiras linhas das ultimas de relance.
	var cor := Color(verde * 0.94, verde, verde * 0.84).lerp(
		Color(0.72, 0.92, 0.58), maxf(0.0, 0.55 - cresc))

	var placas: int = 2 if cresc < 0.45 else 3
	var meio := base + Vector3(0.0, VASO + altura * 0.5, 0.0)
	for k in placas:
		AtlasKit.folha_ao_vento(sup, EstufaBuilder.MAT_FOLHA,
			Vector2(larg, altura),
			Transform3D(Basis(Vector3.UP, giro + PI * float(k)
				/ float(placas)), meio), EstufaBuilder.C_FOLHA, cor)

	if not madura:
		return
	var topo := base + Vector3(0.0, VASO + altura - 0.06, 0.0)
	for k in 2:
		AtlasKit.folha_ao_vento(sup, EstufaBuilder.MAT_FOLHA,
			Vector2(0.30, 0.46),
			Transform3D(Basis(Vector3.UP, giro + PI * 0.5 * float(k)), topo),
			EstufaBuilder.C_BUD, cor)


## Os potes da colheita. E o placar da sala.
##
## Um pote cheio por doze colheitas, da esquerda para a direita, e o que esta
## enchendo aparece pela metade. O jogador que entra depois de uma noite fora
## sabe, sem contar nada, quanto trabalho foi feito ali — e se nao houver
## ninguem contratado, sabe tambem que nenhum foi.
func _desenhar_prateleira(sup: Dictionary) -> void:
	if potes_em.is_empty():
		return
	var p := Plantio.prateleira(colhido())
	var cheios := int(p["cheios"])
	var parcial := float(p["parcial"])
	for k in potes_em.size():
		var onde := potes_em[k] + Vector3(0.0, 0.11, 0.0)
		# O vidro e sempre igual; o que muda e o que tem dentro. Entao o pote e
		# uma caixa de celula de vidro e o conteudo e uma caixa menor por
		# dentro, com a altura do quanto ha.
		AtlasKit.caixa(sup, EstufaBuilder.MAT_RECORTE, onde,
			Vector3(0.17, 0.22, 0.17), EstufaBuilder.C_POTE_VAZIO)
		var quanto := 0.0
		if k < cheios:
			quanto = 1.0
		elif k == cheios:
			quanto = parcial
		if quanto < 0.06:
			continue
		var h: float = 0.19 * quanto
		AtlasKit.caixa(sup, EstufaBuilder.MAT,
			potes_em[k] + Vector3(0.0, 0.012 + h * 0.5, 0.0),
			Vector3(0.14, h, 0.14), EstufaBuilder.C_SECAGEM,
			Color(0.86, 0.88, 0.80))


# --- interacao --------------------------------------------------------------

func _montar_areas() -> void:
	for i in vasos_em.size():
		var area := Interativo.new()
		area.name = "Vaso%d" % i
		area.rotulo = "Vaso"
		area.position = vasos_em[i] + Vector3(0.0, 0.55, 0.0)
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.80, 1.10, 0.80)
		forma.shape = box
		area.add_child(forma)
		var indice := i
		area.acionado.connect(func(_quem: Node) -> void: _mexer(indice))
		add_child(area)
		_areas.append(area)


## O rotulo diz o que falta, e e a unica coisa que diz.
##
## Nao ha aviso na tela, nao ha caixa de dialogo e nao ha tutorial: se o jogador
## nao tem terra na mochila, o vaso escrito "Precisa de terra" ensina duas
## coisas de uma vez — o que aquele vaso quer e que existe terra para pegar em
## algum lugar. E a estacao de insumos esta na mesma sala.
func _atualizar_rotulos() -> void:
	var v := vasos()
	for i in mini(_areas.size(), Plantio.quantos(v)):
		var o_que := Plantio.acao(v, i)
		_areas[i].rotulo = _falta(o_que) if not _pode(o_que) \
			else Plantio.rotulo(v, i)


func _pode(o_que: StringName) -> bool:
	match o_que:
		&"terra":
			return Inventario.tem(ITEM_TERRA)
		&"semente":
			return Inventario.tem(ITEM_SEMENTE)
		&"agua":
			return Inventario.tem(ITEM_REGADOR) and agua_do_regador() > 0
		&"colher":
			return true
	return true


func _falta(o_que: StringName) -> String:
	match o_que:
		&"terra":
			return "Precisa de terra"
		&"semente":
			return "Precisa de semente"
		&"agua":
			if not Inventario.tem(ITEM_REGADOR):
				return "Precisa de um regador"
			return "O regador esta vazio"
	return "Deixar crescer"


func _mexer(i: int) -> void:
	var v := vasos()
	if i >= Plantio.quantos(v):
		return
	var o_que := Plantio.acao(v, i)
	if o_que == &"" or not _pode(o_que):
		return

	match o_que:
		&"terra":
			Inventario.remover(ITEM_TERRA)
		&"semente":
			Inventario.remover(ITEM_SEMENTE)
		&"agua":
			_estado["regador"] = agua_do_regador() - 1

	var colheu := Plantio.aplicar(v, i, o_que)
	if colheu > 0:
		_estado["colhido"] = colhido() + colheu
	_gravar()
	_refazer()


## Feito por um fazendeiro, e nao pelo jogador.
##
## Nao consome insumo nenhum: Helmer e Jota vao ao saco de terra e ao tanque
## com as proprias pernas, e cobrar deles a mesma mochila do jogador faria a
## plantacao parar assim que o jogador gastasse a ultima semente — o que
## transformaria a profissao numa promessa quebrada.
func trabalhar(i: int, o_que: StringName) -> int:
	var v := vasos()
	if i >= Plantio.quantos(v) or o_que != Plantio.acao(v, i):
		return 0
	var colheu := Plantio.aplicar(v, i, o_que)
	if colheu > 0:
		_estado["colhido"] = colhido() + colheu
	_gravar()
	_refazer()
	return colheu


## O que o proximo fazendeiro livre deve fazer, e onde.
func tarefa_para(de_onde: Vector3) -> Dictionary:
	var t := Plantio.proxima_tarefa(vasos(), vasos_em, de_onde)
	if t.is_empty():
		return t
	t["onde"] = vasos_em[int(t["vaso"])]
	return t


func _gravar() -> void:
	Plantio.gravar(semente, _estado)


# --- a estacao de insumos ---------------------------------------------------

## Saco de terra, caixa de semente e tanque de agua.
##
## Sao o que faz a sala ser uma OPERACAO e nao um canteiro: o ciclo precisa de
## um lugar de onde as coisas saem, e esse lugar precisa ser um lugar — com
## chao, com distancia e com o trabalho de ir ate la. Helmer e Jota vao a ele
## pelas mesmas pernas que o jogador.
func _montar_insumos() -> void:
	if saco_em != Vector3.ZERO:
		_estacao("Terra", "Pegar terra", saco_em, Vector3(1.0, 1.0, 0.9),
			func() -> void:
				Inventario.adicionar(ITEM_TERRA, TERRA_POR_VEZ))
	if caixa_em != Vector3.ZERO:
		_estacao("Sementes", "Pegar sementes", caixa_em,
			Vector3(0.7, 0.7, 0.7),
			func() -> void:
				Inventario.adicionar(ITEM_SEMENTE, SEMENTES_POR_VEZ))
	if tanque_em != Vector3.ZERO:
		_estacao("Tanque", "Encher o regador", tanque_em,
			Vector3(1.1, 1.4, 1.1),
			func() -> void:
				# Sem regador na mochila, encher agua nao quer dizer nada. Ele
				# esta pendurado na propria estacao, e pegar e o mesmo gesto.
				if not Inventario.tem(ITEM_REGADOR):
					Inventario.adicionar(ITEM_REGADOR)
				_estado["regador"] = Plantio.REGADOR
				_gravar())
	if not potes_em.is_empty():
		_estacao("Potes", "Pegar da colheita",
			potes_em[potes_em.size() / 2] + Vector3(0.0, 0.1, 0.0),
			Vector3(potes_em.size() * 0.24, 0.6, 0.5),
			func() -> void: _pegar_da_prateleira())


func _estacao(nome: String, rotulo: String, onde: Vector3, tamanho: Vector3,
		acao: Callable) -> void:
	var area := Interativo.new()
	area.name = nome
	area.rotulo = rotulo
	area.position = onde
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tamanho
	forma.shape = box
	area.add_child(forma)
	area.acionado.connect(func(_quem: Node) -> void:
		acao.call()
		_atualizar_rotulos())
	add_child(area)


## O jogador tira da prateleira o que foi colhido ali.
##
## Sai do placar e entra na mochila, e a prateleira diminui na mesma hora: e a
## mesma colheita, e ela nao pode existir nos dois lugares ao mesmo tempo.
func _pegar_da_prateleira() -> void:
	var quanto: int = mini(colhido(), 5)
	if quanto <= 0:
		return
	# `adicionar` devolve o que SOBROU sem lugar, e nao o que entrou. Com a
	# conta invertida, a prateleira entregava a colheita e continuava com ela:
	# a mesma erva existia na mochila e no placar ao mesmo tempo, e so um
	# criterio que compara os dois lados pegaria isso.
	var sobrou := Inventario.adicionar(ITEM_COLHEITA, quanto)
	var entrou := quanto - sobrou
	if entrou <= 0:
		return
	_estado["colhido"] = colhido() - entrou
	_gravar()
	_refazer()

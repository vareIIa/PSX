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
## Entao cada FILEIRA de vasos e uma malha por material (seis fileiras, mais a
## prateleira de potes), refeita quando alguma coisa nela muda de verdade: quando
## o jogador rega, quando o fazendeiro colhe, ou a cada vez que o crescimento
## anda o bastante para aparecer na tela. O desenho e o do KitEstufa — um pe
## florido tem uns sete mil triangulos —, montado numa thread, e so o vaso que
## mudou e refeito: os outros da fileira saem do cache. O resto do tempo nao
## custa nada.
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
## As estacoes das galerias, uma por andar (EstufaBuilder.estacoes): andar,
## variedade, saco, caixa, tanque e o caixote da colheita daquele andar.
var estacoes: Array[Dictionary] = []

## O grupo de malha da prateleira de potes; os outros sao o numero da fileira.
const PRATELEIRA := -1
## O grupo da pilha de sacolas do deposito (DepositoDaEstufa).
const DEPOSITO := -2
## Quantos grupos (fileira ou galeria) uma tarefa da thread monta de uma vez.
const GRUPOS_POR_TAREFA := 3

var _estado: Dictionary = {}
## "grupo:material" -> a malha daquele material naquele grupo.
var _malhas: Dictionary[String, MeshInstance3D] = {}
## A fileira de cada vaso: vasos na mesma linha da sala dividem a malha.
var _fileira: PackedInt32Array = PackedInt32Array()
## A chave (`_chave`) com que cada vaso esta desenhado agora.
var _desenhado: Array[PackedFloat32Array] = []
var _prateleira_desenhada := -1
## A pilha: o que foi desenhado (assinatura), quantos sacos do topo ainda estao
## no ar (a sacola voando da mao do fazendeiro), e o que o jogador pega nela.
var _deposito_desenhado := ""
var _no_ar := 0
var _pilha_colisao: StaticBody3D
var _pilha_formas: Array[CollisionShape3D] = []
## A vitrine do deposito: um saco aberto por variedade, e e dele que o jogador
## tira (a pilha murcha junto).
var _vitrine: Dictionary[StringName, Interativo] = {}
var _sacos_da_pilha: Array = []
## vaso -> {chave, sup}: o desenho de cada vaso, para refazer a fileira sem
## refazer os vizinhos. So a tarefa da vez mexe nele.
var _cache: Dictionary = {}
var _tarefa := -1
var _pedido: Dictionary = {}
var _sujo := false
## vaso -> [quem, ate quando (msec)]: o vaso que um fazendeiro ja foi fazer.
var _reservas: Dictionary = {}
## andar -> o Interativo do caixote.
var _caixotes: Dictionary = {}
var _areas: Array[Interativo] = []
var _desde_o_passo: float = 0.0
var _assinatura: PackedFloat32Array = PackedFloat32Array()
var _triangulos: int = 0


func _ready() -> void:
	add_to_group(&"plantacao")
	IWeed.registrar_estufa(semente, vasos_em.size())
	_estado = Plantio.sincronizar(semente, vasos_em.size(),
		Profissoes.quantos(&"fazendeiro"))
	_separar_fileiras()
	_montar_areas()
	_montar_insumos()
	_refazer()
	set_process(true)


func _exit_tree() -> void:
	# A tarefa escreve no pedido e no cache deste no: nao pode sobreviver a ele.
	if _tarefa != -1:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1


## A fileira de cada vaso pela linha em que ele esta (o Z da sala). Cada
## galeria e um grupo so: seis vasos, e refazer seis nao custa mais que uma
## fileira da lavoura.
func _separar_fileiras() -> void:
	var linhas: Array[float] = []
	_fileira.resize(vasos_em.size())
	for i in vasos_em.size():
		var andar := Variedades.andar_do_vaso(i)
		if andar > 1:
			_fileira[i] = 100 + andar
			continue
		var z := vasos_em[i].z
		var f := -1
		for k in linhas.size():
			if absf(linhas[k] - z) < 0.3:
				f = k
		if f < 0:
			linhas.append(z)
			f = linhas.size() - 1
		_fileira[i] = f


## A malha da sala acabou de ser montada, sem nada pendente na thread.
func pronta() -> bool:
	return _tarefa == -1 and not _sujo


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
	_colher_tarefa()
	_desde_o_passo += delta
	if _desde_o_passo < PASSO:
		return
	_desde_o_passo = 0.0
	# Com o jogador na sala, o trabalho dos contratados acontece pelas pernas
	# deles e nao pela conta: `sincronizar` com zero fazendeiro. Quem trabalha
	# aqui dentro e o Convidado de rotina fazendeiro, e contar duas vezes faria a
	# plantacao andar ao dobro justo quando ha alguem olhando.
	var e := Plantio.sincronizar(semente, vasos_em.size(), _fazendeiros_pela_conta())
	_estado = e
	if _mudou_o_bastante():
		_refazer()
	elif _sujo:
		_despachar()


## Quantos fazendeiros a conta deve pagar agora: zero se eles estao de pe aqui
## dentro, trabalhando, e a folha inteira se estao parados.
##
## A estufa debaixo da casa da rua existe antes de o jogador entrar (o
## InteriorNoMundo monta a casa quando ela chega perto e congela quem mora nela).
## Com zero fixo, o tempo de casa pre-aquecida andava sem ninguem trabalhar: os
## fazendeiros congelados nao regavam, e a conta tambem nao.
func _fazendeiros_pela_conta() -> int:
	var pai := get_parent()
	if pai != null:
		for irmao: Node in pai.get_children():
			if irmao is Convidado and irmao.can_process():
				return 0
	return Profissoes.quantos(&"fazendeiro")


## A malha so se refaz quando a imagem muda. Compara a assinatura visual — fase
## e altura de cada vaso, mais quanto tem na prateleira — e nao o estado inteiro:
## agua caindo de 0,81 para 0,80 nao muda um pixel.
func _mudou_o_bastante() -> bool:
	var nova := _assinatura_atual()
	if _assinatura.size() != nova.size():
		return true
	for k in nova.size():
		if absf(nova[k] - _assinatura[k]) > (DEGRAU if k % 2 == 1 else 0.001):
			return true
	return false


# --- a malha ----------------------------------------------------------------

## Pede a malha nova do que mudou. A montagem e numa thread (`_montar`): o pe
## florido do KitEstufa tem sete mil triangulos e custa dez milissegundos, e
## vinte e quatro deles no quadro em que a casa entra no alcance seriam um
## quarto de segundo de tela parada. Aqui so se compara e se despacha.
func _refazer() -> void:
	_sujo = true
	_despachar()
	_assinatura = _assinatura_atual()
	_atualizar_rotulos()
	mudou.emit()


## O que o vaso `i` desenha, em numeros: fase, altura em degraus de DEGRAU e a
## agua em quartos. A malha dele so se refaz quando isto muda.
func _chave(v: Array, i: int) -> PackedFloat32Array:
	var fase := Plantio.fase_de(v, i)
	var c := 0.0
	if fase == Plantio.Fase.CRESCENDO or fase == Plantio.Fase.PRONTA:
		c = snappedf(Plantio.crescimento_de(v, i), DEGRAU)
	var agua := 0.0
	if fase != Plantio.Fase.VAZIO:
		agua = snappedf(Plantio.agua_de(v, i), 0.25)
	return PackedFloat32Array([float(int(fase)), c, agua])


## Manda para a thread as fileiras em que algum vaso mudou, e a prateleira se a
## colheita mudou. Uma tarefa por vez: o que mudar enquanto ela roda fica
## marcado em `_sujo` e sai na proxima.
func _despachar() -> void:
	if _tarefa != -1 or not _sujo:
		return
	_sujo = false
	var v := vasos()
	var pedido := {"fileiras": {}, "cache": _cache}
	var mudadas := {}
	for i in mini(Plantio.quantos(v), vasos_em.size()):
		var chave := _chave(v, i)
		if i >= _desenhado.size() or _desenhado[i] != chave:
			# Tres grupos por tarefa, no maximo: a primeira montagem tem as oito
			# galerias inteiras (41 pes cada), e subir tudo de uma vez era um
			# quadro parado quando a casa entrava no alcance. O resto sai nas
			# tarefas seguintes.
			if mudadas.size() >= GRUPOS_POR_TAREFA and not mudadas.has(_fileira[i]):
				_sujo = true
				continue
			mudadas[_fileira[i]] = true
	for i in mini(Plantio.quantos(v), vasos_em.size()):
		var f := _fileira[i]
		if not mudadas.has(f):
			continue
		if not pedido["fileiras"].has(f):
			pedido["fileiras"][f] = []
		var andar := Variedades.andar_do_vaso(i)
		pedido["fileiras"][f].append({"i": i, "chave": _chave(v, i),
			"base": vasos_em[i], "semente": semente * 31 + i,
			"variedade": Variedades.do_vaso(i),
			"pe_direito": EstufaBuilder.pe_direito(andar)})
	if colhido() != _prateleira_desenhada and not potes_em.is_empty():
		pedido["prateleira"] = {"potes": potes_em.duplicate(),
			"colhido": colhido()}
	var dep := _assinatura_do_deposito()
	if dep != _deposito_desenhado and not potes_em.is_empty():
		_sacos_da_pilha = DepositoDaEstufa.sacos(Plantio.pilha_de(_estado),
			_estado.get("colheitas", {}), _no_ar)
		pedido["deposito"] = {"sacos": _sacos_da_pilha.duplicate(true),
			"estoque": (_estado.get("colheitas", {}) as Dictionary).duplicate(), "assinatura": dep}
	if pedido["fileiras"].is_empty() and not pedido.has("prateleira") \
			and not pedido.has("deposito"):
		return
	_pedido = pedido
	_tarefa = WorkerThreadPool.add_task(_montar.bind(pedido),
		false, "plantacao")


## Na thread. So le o pedido e escreve nele (e no cache, que so a tarefa da vez
## toca): nada de no, nada de autoload.
static func _montar(pedido: Dictionary) -> void:
	var cache: Dictionary = pedido["cache"]
	var saida := {}
	for f: int in pedido["fileiras"]:
		var sup := {}
		for item: Dictionary in pedido["fileiras"][f]:
			var i: int = item["i"]
			var guardado: Dictionary = cache.get(i, {})
			if guardado.is_empty() or guardado["chave"] != item["chave"]:
				var s := {}
				_desenhar_vaso(s, item)
				guardado = {"chave": item["chave"], "sup": s}
				cache[i] = guardado
			_juntar(sup, guardado["sup"])
		saida[f] = sup
	if pedido.has("prateleira"):
		var sup := {}
		_desenhar_prateleira(sup, pedido["prateleira"])
		saida[PRATELEIRA] = sup
	if pedido.has("deposito"):
		var sup := {}
		DepositoDaEstufa.desenhar(sup, pedido["deposito"]["sacos"], pedido["deposito"]["estoque"])
		saida[DEPOSITO] = sup
	pedido["saida"] = saida


## De volta ao quadro principal: sobe as malhas prontas.
func _colher_tarefa() -> void:
	if _tarefa == -1 or not WorkerThreadPool.is_task_completed(_tarefa):
		return
	WorkerThreadPool.wait_for_task_completion(_tarefa)
	_tarefa = -1
	var pedido := _pedido
	_pedido = {}
	var saida: Dictionary = pedido.get("saida", {})
	for f: int in saida:
		_subir(f, saida[f])
	for f: int in pedido["fileiras"]:
		for item: Dictionary in pedido["fileiras"][f]:
			var i: int = item["i"]
			while _desenhado.size() <= i:
				_desenhado.append(PackedFloat32Array())
			_desenhado[i] = item["chave"]
	if pedido.has("prateleira"):
		_prateleira_desenhada = int(pedido["prateleira"]["colhido"])
	if pedido.has("deposito"):
		_deposito_desenhado = String(pedido["deposito"]["assinatura"])
		_colisao_da_pilha((pedido["deposito"]["sacos"] as Array).size())
		_atualizar_rotulos()
	# Pelo tamanho do indice que a malha ja guarda, e nao por
	# `PSXMesh.triangle_count`, que le cada superficie de volta da GPU: com as
	# dezenas de malhas da lavoura isso eram 10 ms no quadro em que a tarefa
	# chegava (tests/bancada_fps_dirigir.gd --faixas-proc). O numero e o mesmo.
	_triangulos = 0
	for mi: MeshInstance3D in _malhas.values():
		var am := mi.mesh as ArrayMesh
		if am == null:
			continue
		for s in am.get_surface_count():
			var n := am.surface_get_array_index_len(s)
			_triangulos += (n if n > 0 else am.surface_get_array_len(s)) / 3
	_despachar()


## Uma MeshInstance3D por material de cada grupo (fileira de vasos ou a
## prateleira), filhas diretas da plantacao.
func _subir(grupo: int, sup: Dictionary) -> void:
	for chave: String in _malhas.keys():
		if chave.begins_with("%d:" % grupo) and not sup.has(StringName(chave.get_slice(":", 1))):
			(_malhas[chave] as MeshInstance3D).mesh = null
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		var chave := "%d:%s" % [grupo, material]
		var mi: MeshInstance3D = _malhas.get(chave, null)
		if PSXMesh.dados_vazio(d):
			if mi != null:
				mi.mesh = null
			continue
		if mi == null:
			mi = MeshInstance3D.new()
			var nome := "Fileira%d" % grupo
			if grupo == PRATELEIRA:
				nome = "Prateleira"
			elif grupo == DEPOSITO:
				nome = "Deposito"
			mi.name = "%s_%s" % [nome, material]
			mi.material_override = Interiores.material(material)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.layers = _camadas()
			if grupo >= 100:
				# 41 pes por galeria e oito galerias: o andar a mais de treze metros
				# esta na nevoa e nao desenha. Da grade da lavoura ainda se ve o 2
				# ao 5 descendo; do elevador, os vizinhos.
				mi.visibility_range_end = 13.0
				mi.visibility_range_end_margin = 4.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mi)
			_malhas[chave] = mi
		mi.mesh = PSXMesh.dados_para_mesh(d)


## A camada de luz da sala em volta. Na estufa debaixo da casa da rua quem marca
## e o InteriorNoMundo, pelo no que nasce; no comodo teleportado a marca e feita
## uma vez so (Interiores._separar_luz_da_estufa), e a malha que chega depois
## pegaria a camada 1 e ficaria no escuro. Copia a de uma malha da propria sala.
func _camadas() -> int:
	var pai := get_parent()
	if pai != null:
		for irmao: Node in pai.get_children():
			if irmao is MeshInstance3D:
				return (irmao as MeshInstance3D).layers
	return 1


## Junta os baldes de um vaso no da fileira.
static func _juntar(destino: Dictionary, fonte: Dictionary) -> void:
	for material: StringName in fonte:
		var f: Dictionary = fonte[material]
		if not destino.has(material):
			destino[material] = {"v": PackedVector3Array(), "n": PackedVector3Array(),
				"uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
		var d: Dictionary = destino[material]
		var base := (d["v"] as PackedVector3Array).size()
		var v: PackedVector3Array = d["v"]
		v.append_array(f["v"])
		d["v"] = v
		var n: PackedVector3Array = d["n"]
		n.append_array(f["n"])
		d["n"] = n
		var uv: PackedVector2Array = d["uv"]
		uv.append_array(f["uv"])
		d["uv"] = uv
		var c: PackedColorArray = d["c"]
		c.append_array(f["c"])
		d["c"] = c
		var idx: PackedInt32Array = d["i"]
		var novos: PackedInt32Array = f["i"]
		var ini := idx.size()
		idx.resize(ini + novos.size())
		for k in novos.size():
			idx[ini + k] = novos[k] + base
		d["i"] = idx


func _assinatura_atual() -> PackedFloat32Array:
	var v := vasos()
	var nova := PackedFloat32Array()
	nova.resize(Plantio.quantos(v) * 2 + 1)
	for i in Plantio.quantos(v):
		nova[i * 2] = float(int(Plantio.fase_de(v, i)))
		nova[i * 2 + 1] = Plantio.crescimento_de(v, i)
	nova[nova.size() - 1] = float(colhido())
	return nova


## Um vaso e o que estiver dentro dele (KitEstufa).
##
## Vazio, o feltro mostra o fundo: e um poco, e nao uma caixa tampada. Com
## terra, a terra escurece com a agua — e a unica leitura de agua que a sala
## tem, e sem ela "regar" seria um rotulo que nao muda nada na tela. Semeado, a
## estaca com o envelope da semente espetada na terra. Crescendo e pronto, o pe.
static func _desenhar_vaso(sup: Dictionary, item: Dictionary) -> void:
	var chave: PackedFloat32Array = item["chave"]
	var base: Vector3 = item["base"]
	var sid: int = item["semente"]
	var fase := int(chave[0])
	var v: StringName = item.get("variedade", &"comum")
	if v != &"comum":
		_desenhar_variedade(sup, item, v)
		return
	KitEstufa.vaso(sup, base, fase != Plantio.Fase.VAZIO, chave[2], sid)
	var terra := base + Vector3(0.0, KitEstufa.TERRA_Y, 0.0)
	if fase == Plantio.Fase.SEMEADO:
		KitEstufa.estaca(sup, terra, sid)
		return
	if fase != Plantio.Fase.CRESCENDO and fase != Plantio.Fase.PRONTA:
		return
	# Variacao por vaso: tom de verde e giro. Vem do indice e nao de sorteio,
	# senao a planta muda de cara a cada malha refeita.
	var rng := RandomNumberGenerator.new()
	rng.seed = sid ^ 0x5A17
	var tom := rng.randf_range(0.9, 1.08)
	var verde := Color(tom * 0.96, tom, tom * 0.9)
	# O recem-regado ja e muda com o primeiro par de folhas: nada de vaso de terra
	# molhada sem nada dentro para o jogador que acabou de regar.
	var c := lerpf(0.06, 1.0, chave[1])
	KitEstufa.planta(sup, terra, c, fase == Plantio.Fase.PRONTA, sid, verde)


## O vaso de uma galeria: o recipiente e a planta da variedade do andar
## (KitEstufa.variedade) — o vaso pendurado da Morcega, a bandeja do Bonsai.
static func _desenhar_variedade(sup: Dictionary, item: Dictionary, v: StringName) -> void:
	var chave: PackedFloat32Array = item["chave"]
	var base: Vector3 = item["base"]
	var sid: int = item["semente"]
	var fase := int(chave[0])
	var pd: float = item.get("pe_direito", 2.61)
	KitEstufa.recipiente(sup, base, v, fase != Plantio.Fase.VAZIO, chave[2], sid, pd)
	var info := KitEstufa.recipiente_info(v, pd)
	var terra: Vector3 = base + Vector3(info["terra"])
	if fase == Plantio.Fase.SEMEADO:
		KitEstufa.estaca_da_variedade(sup, terra, v, sid)
		return
	if fase != Plantio.Fase.CRESCENDO and fase != Plantio.Fase.PRONTA:
		return
	KitEstufa.variedade(sup, terra, lerpf(0.06, 1.0, chave[1]),
		fase == Plantio.Fase.PRONTA, sid, v, pd)


## Os potes da colheita. E o placar da sala.
##
## Um pote cheio por doze colheitas, da esquerda para a direita, e o que esta
## enchendo aparece pela metade. O jogador que entra depois de uma noite fora
## sabe, sem contar nada, quanto trabalho foi feito ali — e se nao houver
## ninguem contratado, sabe tambem que nenhum foi.
static func _desenhar_prateleira(sup: Dictionary, dados: Dictionary) -> void:
	var potes: Array = dados["potes"]
	var p := Plantio.prateleira(int(dados["colhido"]))
	var cheios := int(p["cheios"])
	var parcial := float(p["parcial"])
	for k in potes.size():
		var quanto := 0.0
		if k < cheios:
			quanto = 1.0
		elif k == cheios:
			quanto = parcial
		# O rotulo olha para o corredor (+X da sala), com um tanto de mao.
		var giro := PI * 0.5 + sin(float(k) * 2.3) * 0.25
		KitEstufa.pote(sup, potes[k], quanto if quanto >= 0.06 else 0.0, giro)
	# A prateleira cheia transborda: segunda fila no tampo e caixote de pote no
	# chao (DepositoDaEstufa). O placar continua contando depois do nono pote.
	var colh := int(dados["colhido"])
	var alem := colh - Plantio.POTES * Plantio.POR_POTE
	if alem > 0:
		DepositoDaEstufa.desenhar_potes_extras(sup, potes, alem / Plantio.POR_POTE,
			float(alem % Plantio.POR_POTE) / float(Plantio.POR_POTE))


# --- interacao --------------------------------------------------------------

func _montar_areas() -> void:
	for i in vasos_em.size():
		var area := Interativo.new()
		area.name = "Vaso%d" % i
		area.rotulo = "Vaso"
		area.position = vasos_em[i] + Vector3(0.0, 0.55, 0.0)
		var tamanho := Vector3(0.80, 1.10, 0.80)
		var andar := Variedades.andar_do_vaso(i)
		if andar > 1:
			# A area e a do recipiente da variedade: a Morcega pende do forro, e
			# quem olha para ela olha para cima.
			var info := KitEstufa.recipiente_info(Variedades.do_vaso(i),
				EstufaBuilder.pe_direito(andar))
			var a: Dictionary = info["area"]
			area.position = vasos_em[i] + Vector3(a["pos"])
			tamanho = a["tamanho"]
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = tamanho
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
		# Crescendo com agua nao pede nada: um [E] "Deixar crescer" que nao faz
		# nada ensinava o jogador a apertar a tecla a toa.
		_areas[i].habilitado = o_que != &""
	var potes := get_node_or_null("Potes") as Interativo
	if potes != null:
		# Prateleira vazia nao tem o que pegar.
		potes.habilitado = colhido() > 0
	for andar: int in _caixotes:
		var cx := _caixotes[andar] as Interativo
		var do_andar := Variedades.do_andar(andar)
		var n := Plantio.colheita_de(_estado, do_andar)
		cx.rotulo = "Pegar %s (%d)" % [Variedades.nome(do_andar), n]
		cx.habilitado = n > 0
	for var_: StringName in _vitrine:
		var n := Plantio.colheita_de(_estado, var_)
		_vitrine[var_].rotulo = "Pegar %s (%d)" % [Variedades.nome(var_), n]
		_vitrine[var_].habilitado = n > 0


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
	Plantio.guardar_colheita(_estado, i, colheu)
	if colheu > 0 and Variedades.andar_do_vaso(i) > 1:
		var var_ := Variedades.do_vaso(i)
		Cinema.fala("%d de %s. Ta no caixote do andar." % [colheu, Variedades.nome(var_)])
	_gravar()
	_refazer()


## Feito por um fazendeiro, e nao pelo jogador.
##
## Nao consome insumo nenhum: Helmer e Jota vao ao saco de terra e ao tanque
## com as proprias pernas, e cobrar deles a mesma mochila do jogador faria a
## plantacao parar assim que o jogador gastasse a ultima semente — o que
## transformaria a profissao numa promessa quebrada.
##
## `sacola`: o id de quem colheu. A colheita vai para a sacola dele
## (SacolaDeColheita), e so chega ao caixote quando ele esvazia.
func trabalhar(i: int, o_que: StringName, sacola: int = -1) -> int:
	var v := vasos()
	if i >= Plantio.quantos(v) or o_que != Plantio.acao(v, i):
		return 0
	var colheu := Plantio.aplicar(v, i, o_que)
	if sacola >= 0 and colheu > 0:
		Plantio.por_na_sacola(_estado, sacola, Variedades.do_vaso(i), colheu)
	else:
		Plantio.guardar_colheita(_estado, i, colheu)
	_reservas.erase(i)
	_gravar()
	_refazer()
	return colheu


## Onde as maos de quem colhe pegam a planta do vaso `i` (coordenada da
## plantacao): no meio da copa. A Morcega pende do teto, e a copa esta ABAIXO
## da terra; o bonsai e baixo, na mesa dele.
func copa(i: int) -> Vector3:
	var base := vasos_em[i]
	var v := Variedades.do_vaso(i)
	var andar := EstufaBuilder.andar_de_y(base.y)
	var mao: Vector3 = KitEstufa.recipiente_info(v, EstufaBuilder.pe_direito(andar))["mao"]
	match v:
		&"morcega":
			return base + mao + Vector3(0.0, -0.22, 0.0)
		&"bonsai":
			return base + mao + Vector3(0.0, 0.14, 0.0)
	return base + mao + Vector3(0.0, 0.5, 0.0)


## O que o proximo fazendeiro livre deve fazer, e onde.
##
## `quem` reserva o vaso por um minuto e meio: os outros escolhem outro. A
## reserva cai quando o trabalho e feito ou quando o tempo acaba (quem desistiu
## no meio do caminho nao prende o vaso para sempre).
func tarefa_para(de_onde: Vector3, quem: Object = null) -> Dictionary:
	var agora := Time.get_ticks_msec()
	var ignorar := {}
	for i: int in _reservas.keys():
		var r: Array = _reservas[i]
		if not is_instance_valid(r[0]) or int(r[1]) < agora:
			_reservas.erase(i)
		elif r[0] != quem:
			ignorar[i] = true
	var t := Plantio.proxima_tarefa(vasos(), vasos_em, de_onde, ignorar)
	if t.is_empty():
		return t
	t["onde"] = vasos_em[int(t["vaso"])]
	if quem != null:
		_reservas[int(t["vaso"])] = [quem, agora + 90000]
	return t


## A sacola de um fazendeiro, como o Plantio guardou.
func sacola(id: int) -> Dictionary:
	return Plantio.sacola_de(_estado, id)


## Despeja a sacola no caixote: cada variedade no dela, a comum na prateleira.
## Devolve quantas unidades entraram.
func esvaziar_sacola(id: int) -> int:
	var carga := Plantio.esvaziar_sacola(_estado, id)
	var total := 0
	for v: StringName in carga:
		Plantio.guardar_por_variedade(_estado, v, int(carga[v]))
		total += int(carga[v])
	_gravar()
	_refazer()
	_atualizar_rotulos()
	return total


## O fazendeiro despeja a sacola no deposito da lavoura: a erva comum vai para
## os potes, cada variedade para o estoque dela, e o saco vai para a pilha.
## Devolve para onde o saco voa (coordenada da plantacao) e o raio que ele tem
## la, ou vazio se nao ha saco a empilhar (so erva comum). O saco fica "no ar"
## — fora do desenho da pilha — ate `pousou_na_pilha`.
func despejar_na_pilha(id: int) -> Dictionary:
	var carga := Plantio.esvaziar_sacola(_estado, id)
	var dominante := &""
	var maior := 0
	for v: StringName in carga:
		var q := int(carga[v])
		Plantio.guardar_por_variedade(_estado, v, q)
		if v != &"comum" and q > maior:
			maior = q
			dominante = v
	# Uma sacola misturada vira um saco por variedade; o que voa da mao dele e o
	# da maior, e por isso entra por ultimo (e o "no ar" e o topo da lista).
	for v: StringName in carga:
		if v != &"comum" and v != dominante:
			Plantio.empilhar(_estado, v, int(carga[v]))
	var voo := {}
	if dominante != &"":
		Plantio.empilhar(_estado, dominante, maior)
		var todos := DepositoDaEstufa.sacos(Plantio.pilha_de(_estado),
			_estado.get("colheitas", {}), 0)
		var k := mini(todos.size() - 1, DepositoDaEstufa.vagas() - 1)
		for j in todos.size():
			var e: Dictionary = todos[todos.size() - 1 - j]
			if StringName(e["v"]) == dominante:
				k = mini(todos.size() - 1 - j, DepositoDaEstufa.vagas() - 1)
				break
		voo = DepositoDaEstufa.voo(k, maior)
		_no_ar += 1
	_gravar()
	_refazer()
	_sujo = true
	_despachar()
	return voo


## O saco que voava chegou na pilha: agora ela o desenha.
func pousou_na_pilha() -> void:
	_no_ar = maxi(0, _no_ar - 1)
	_sujo = true
	_despachar()


## Onde o fazendeiro para para jogar a sacola, e para onde olha (coordenada da
## plantacao).
func ponto_do_deposito(so_comum: bool = false) -> Dictionary:
	# Saco so de erva comum nao vai para a pilha: e despejado nos potes, na
	# frente da bancada.
	if so_comum:
		return {"de": EstufaBuilder.BANCADA + Vector3(0.8, 0.0, 0.0),
			"olhar": EstufaBuilder.BANCADA + Vector3(0.0, 0.78, 0.0)}
	return {"de": DepositoDaEstufa.PONTO, "olhar": DepositoDaEstufa.OLHAR}


func _assinatura_do_deposito() -> String:
	return "%s|%s|%d" % [str(Plantio.pilha_de(_estado)), str(_estado.get("colheitas", {})), _no_ar]


## A colisao da pilha, palete por palete, na altura que ela tem agora.
func _colisao_da_pilha(n: int) -> void:
	if _pilha_colisao == null:
		_pilha_colisao = StaticBody3D.new()
		_pilha_colisao.name = "PilhaColisao"
		add_child(_pilha_colisao)
		for p: Dictionary in DepositoDaEstufa.PALETES:
			var forma := CollisionShape3D.new()
			forma.shape = BoxShape3D.new()
			_pilha_colisao.add_child(forma)
			_pilha_formas.append(forma)
	var alturas := DepositoDaEstufa.alturas(n)
	for k in _pilha_formas.size():
		var p: Dictionary = DepositoDaEstufa.PALETES[k]
		var tam := Basis(Vector3.UP, float(p["giro"])) * Vector3(DepositoDaEstufa.PALETE.x, 0.0,
			DepositoDaEstufa.PALETE.y)
		var alto := alturas[k]
		(_pilha_formas[k].shape as BoxShape3D).size = Vector3(absf(tam.x) - 0.06, alto,
			absf(tam.z) - 0.06)
		_pilha_formas[k].position = (p["centro"] as Vector3) + Vector3(0.0, alto * 0.5, 0.0)
		# Palete vazio: a colisao dele ja vem do comodo, e a caixa aqui sai do caminho.
		_pilha_formas[k].disabled = alto <= DepositoDaEstufa.ALTURA_PALETE + 0.01


## O jogador tira da vitrine: cinco da variedade daquele saco aberto.
func _pegar_da_vitrine(v: StringName) -> void:
	var quanto: int = mini(Plantio.colheita_de(_estado, v), 5)
	if quanto <= 0:
		return
	var sobrou := Inventario.adicionar(Variedades.item(v), quanto)
	var entrou := quanto - sobrou
	if entrou <= 0:
		Cinema.fala("Nao cabe mais nada na mochila.")
		return
	Plantio.tirar_colheita(_estado, v, entrou)
	AudioDirector.tocar(&"pegar", global_position, -6.0)
	_gravar()
	_sujo = true
	_despachar()


## Onde se esvazia a sacola num andar: o caixote da galeria, ou a prateleira de
## potes da lavoura. Coordenada da plantacao.
func deposito(andar: int) -> Vector3:
	if andar > 1:
		for e: Dictionary in estacoes:
			if int(e["andar"]) == andar:
				return e["caixote"]
	if not potes_em.is_empty():
		return potes_em[potes_em.size() / 2]
	return saco_em


## Onde pegar o insumo de uma acao no andar dado. A lavoura tem a estacao dela;
## cada galeria, a sua (EstufaBuilder.estacoes). ZERO: nada a buscar.
func insumo(o_que: StringName, andar: int = 1) -> Vector3:
	var chave := ""
	match o_que:
		&"terra":
			chave = "saco"
		&"semente":
			chave = "caixa"
		&"agua":
			chave = "tanque"
		_:
			return Vector3.ZERO
	if andar > 1:
		for e: Dictionary in estacoes:
			if int(e["andar"]) == andar:
				return e[chave]
	match chave:
		"saco":
			return saco_em
		"caixa":
			return caixa_em
	return tanque_em


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
	for e: Dictionary in estacoes:
		var andar := int(e["andar"])
		var v := StringName(e["variedade"])
		_estacao("Terra%d" % andar, "Pegar terra", e["saco"], Vector3(0.9, 0.7, 0.7),
			func() -> void:
				Inventario.adicionar(ITEM_TERRA, TERRA_POR_VEZ))
		_estacao("Sementes%d" % andar, "Pegar sementes de %s" % Variedades.nome(v),
			e["caixa"], Vector3(0.6, 0.5, 0.6),
			func() -> void:
				Inventario.adicionar(ITEM_SEMENTE, SEMENTES_POR_VEZ))
		_estacao("Tanque%d" % andar, "Encher o regador", e["tanque"],
			Vector3(1.0, 1.3, 1.1),
			func() -> void:
				if not Inventario.tem(ITEM_REGADOR):
					Inventario.adicionar(ITEM_REGADOR)
				_estado["regador"] = Plantio.REGADOR
				_gravar())
		_caixotes[andar] = _estacao("Caixote%d" % andar, "", e["caixote"],
			Vector3(0.9, 0.7, 0.7), func() -> void: _pegar_do_caixote(v))
	if not potes_em.is_empty():
		# A pilha de sacolas: uma area sobre os tres paletes.
		# A vitrine: um saco aberto por variedade no palete da ponta da bancada.
		for i in Variedades.ANDARES_DE_GALERIA:
			var v := Variedades.do_andar(i + 2)
			_vitrine[v] = _estacao("Vitrine%d" % (i + 2), "",
				DepositoDaEstufa.vitrine_lugar(i) + Vector3(0.0, 0.3, 0.0),
				Vector3(0.28, 0.5, 0.36), func() -> void: _pegar_da_vitrine(v))
		_estacao("Potes", "Pegar da colheita",
			potes_em[potes_em.size() / 2] + Vector3(0.0, 0.1, 0.0),
			Vector3(potes_em.size() * 0.24, 0.6, 0.5),
			func() -> void: _pegar_da_prateleira())


func _estacao(nome: String, rotulo: String, onde: Vector3, tamanho: Vector3,
		acao: Callable) -> Interativo:
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
	return area


## O jogador tira do caixote de uma galeria a erva daquele andar, cinco por vez.
func _pegar_do_caixote(v: StringName) -> void:
	var quanto: int = mini(Plantio.colheita_de(_estado, v), 5)
	if quanto <= 0:
		return
	var sobrou := Inventario.adicionar(Variedades.item(v), quanto)
	var entrou := quanto - sobrou
	if entrou <= 0:
		Cinema.fala("Nao cabe mais nada na mochila.")
		return
	Plantio.tirar_colheita(_estado, v, entrou)
	AudioDirector.tocar(&"pegar", global_position, -6.0)
	_gravar()


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

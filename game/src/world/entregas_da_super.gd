## As entregas da Super: da planta do andar 10 ate o cliente na rua.
##
## O ciclo inteiro, em quatro tempos:
##   1. o jogador colhe a planta gigante do andar 10 (SuperQuarto) e ganha doses;
##   2. entrega as doses ao Jota ou ao Helmer, na conversa;
##   3. na rua, na frente do jogador, um dos dois encontra um cliente e entrega;
##   4. o cliente fuma, e SO AI vem o efeito que a dupla promete no andar 10:
##      olho de gato (e ele segue na rua com os olhos acesos), o decimo que
##      "enxerga som", explodir, ou voar — e quem voa volta, de vez em quando,
##      cruzando o ceu.
##
## Nada aqui mexe no Pedestre nem na Multidao. O cliente e um pedestre que ja
## estava andando, congelado por fora (fisica desligada) enquanto a cena dura;
## o entregador e um Corpo solto que vem pela calcada em que o cliente andava,
## de frente para ele. Os dois arquivos sao de outra frente, e o que a cena
## precisa deles — posicao, velocidade, o Corpo filho — ja e publico.
##
## O estado mora no WorldState e entra no save: se a planta esta pronta, quanto
## falta para crescer, quantas doses a dupla tem para entregar, quem ficou com
## olho de gato e quem voou.
class_name EntregasDaSuper
extends Node

enum Efeito { OLHO_DE_GATO, ENXERGA_SOM, EXPLODE, VOA }

## Faixa de coordenada das pessoas (FalasNpc.PESSOA), com um id negativo: id de
## gente e sempre positivo, entao ninguem mora aqui.
const COORD := Vector2i(-7, 424243)
const ITEM := &"super_maconha"
const DOSES_POR_COLHEITA := 4
## Minutos de jogo ate a planta dar de novo. O relogio anda a 2x: tres minutos
## de verdade na rua.
const CRESCE_MINUTOS := 360.0
## O sorteio do efeito, na ordem do enum. O "nove de cada dez" do Helmer e da
## linha comum; a colheita traz as duas prateleiras misturadas, e a de cima e
## a que explode e a que voa.
const PESOS: Array[float] = [0.58, 0.07, 0.19, 0.16]
const MATERIAL_LUZ := "res://resources/materials/mat_estufa_luz.tres"
## A fumaca de pneu, e nao a do baseado: a do baseado e de dentro de casa e
## some com a distancia, e a 16 m a explosao saiu sem nuvem nenhuma. A de pneu
## foi afinada para ser vista a 26 m.
const MATERIAL_FUMACA := "res://resources/materials/mat_fumaca_pneu.tres"
const NOMES := {&"jota": "JOTA", &"helmer": "HELMER"}

## Uma fase da cena de entrega, para quem fotografa: "chegando", "entregue",
## "efeito". `onde` e o pe do cliente.
signal fase(nome: StringName, onde: Vector3)

var _rng := RandomNumberGenerator.new()
var _min_antes := -1
var _espera := 25.0
var _em_cena := false
var _relogio_olhos := 0.0
var _espera_voo := 200.0
var _forcado := -1
var _ja_voou_na_sessao := false


func _ready() -> void:
	add_to_group(&"entregas_da_super")
	_rng.randomize()
	_espera_voo = _rng.randf_range(150.0, 280.0)


# --- estado -------------------------------------------------------------------

static func _ler(chave: StringName, padrao: Variant) -> Variant:
	return WorldState.obter(COORD, chave, padrao)


static func _gravar(chave: StringName, valor: Variant) -> void:
	WorldState.definir(COORD, chave, valor)


static func planta_pronta() -> bool:
	return bool(_ler(&"pronta", true))


static func horas_para_crescer() -> int:
	return maxi(1, ceili(float(_ler(&"cresce", 0.0)) / 60.0))


static func pendentes() -> int:
	return int(_ler(&"pendentes", 0))


## Colhe a planta. Devolve quantas doses entraram no inventario; zero quando
## ainda nao esta pronta ou quando nao cabe nada.
static func colher() -> int:
	if not planta_pronta():
		return 0
	var sobra := Inventario.adicionar(ITEM, DOSES_POR_COLHEITA)
	var entrou := DOSES_POR_COLHEITA - sobra
	if entrou <= 0:
		return 0
	_gravar(&"pronta", false)
	_gravar(&"cresce", CRESCE_MINUTOS)
	return entrou


## A dupla recebe `n` doses para entregar. Guarda tambem quem sao Jota e
## Helmer: o id deles depende da semente do mundo, e a cena da rua precisa da
## cara de cada um sem estar dentro da estufa.
static func encomendar(n: int) -> void:
	_gravar(&"pendentes", pendentes() + n)
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or c.ficha.is_empty():
			continue
		var quem := RegistroCivil.personagem_de(int(c.ficha["id"]))
		if NOMES.has(quem):
			_gravar(quem, int(c.ficha["id"]))


## Para testes e capturas: a proxima entrega sai ja, com este efeito.
func forcar(efeito: int) -> void:
	_forcado = efeito
	_gravar(&"pendentes", pendentes() + 1)
	_espera = 0.0


# --- laco ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_contar_crescimento()
	if Interiores.dentro:
		return
	_relogio_olhos -= delta
	if _relogio_olhos <= 0.0:
		_relogio_olhos = 1.5
		_vestir_olhos()
	if not _em_cena and pendentes() > 0:
		_espera -= delta
		if _espera <= 0.0:
			var cliente := _achar_cliente()
			if cliente == null:
				_espera = 3.0
			else:
				_entregar(cliente)
	var voadores: Array = _ler(&"voadores", [])
	if not voadores.is_empty() and not _em_cena:
		_espera_voo -= delta
		if _espera_voo <= 0.0:
			_espera_voo = _rng.randf_range(180.0, 360.0)
			_voo(int(voadores[_rng.randi() % voadores.size()]))


## O relogio do jogo nao conta dias, entao o crescimento conta minutos: a
## diferenca entre este quadro e o anterior, dando a volta na meia-noite.
func _contar_crescimento() -> void:
	var m := WorldState.relogio.minutos()
	if _min_antes >= 0 and m != _min_antes:
		var falta := float(_ler(&"cresce", 0.0))
		if falta > 0.0:
			falta = maxf(0.0, falta - float(posmod(m - _min_antes, 1440)))
			_gravar(&"cresce", falta)
			if falta <= 0.0:
				_gravar(&"pronta", true)
	_min_antes = m


## Um pedestre na frente do jogador, entre 8 e 22 m: longe o bastante para a
## cena caber inteira no quadro, perto o bastante para a nevoa nao comer. A
## primeira versao buscava a 22 m e a foto mostrava a fumaca e um vulto.
func _achar_cliente() -> Pedestre:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if jogador == null or cam == null:
		return null
	var frente := -cam.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var ja: Array = _ler(&"olhos", [])
	var melhor: Pedestre = null
	var nota_melhor := INF
	for p: Pedestre in Multidao.lista():
		if not is_instance_valid(p) or not p.is_physics_processing() or not p.visible:
			continue
		if ja.has(int(p.ficha.get("id", 0))):
			continue
		var d := p.global_position - jogador.global_position
		if absf(d.y) > 2.5:
			continue
		var plano := Vector3(d.x, 0.0, d.z)
		var dist := plano.length()
		if dist < 8.0 or dist > 22.0:
			continue
		var alinhado := plano.normalized().dot(frente)
		if alinhado < 0.55:
			continue
		var nota := absf(dist - 13.0) - alinhado * 8.0
		if nota < nota_melhor:
			nota_melhor = nota
			melhor = p
	return melhor


## Devolve int, e nao Efeito: `as Efeito` num int devolve null em silencio.
func _sortear() -> int:
	if _forcado >= 0:
		var f := _forcado
		_forcado = -1
		return f
	var r := _rng.randf()
	for k in PESOS.size():
		r -= PESOS[k]
		if r <= 0.0:
			return k
	return Efeito.OLHO_DE_GATO


# --- a cena -------------------------------------------------------------------

func _entregar(cliente: Pedestre) -> void:
	_em_cena = true
	_gravar(&"pendentes", pendentes() - 1)
	var efeito := _sortear()
	var quem: StringName = &"jota" if _rng.randf() < 0.6 else &"helmer"
	var outro: StringName = &"helmer" if quem == &"jota" else &"jota"
	var id_entregador := int(_ler(quem, -1))
	# Sem o id gravado (a encomenda nao passou pela conversa, como num teste),
	# vai outra pessoa da cidade: Corpo sem aparencia nao monta.
	if id_entregador < 0:
		id_entregador = int(cliente.ficha.get("id", 1)) + 7919
	var ficha: Dictionary = RegistroCivil.identidade(id_entregador)

	# A calcada: para onde o cliente estava andando. O entregador vem de la, de
	# frente, e volta por onde veio — e o unico caminho que se sabe livre.
	var v := cliente.velocity
	var dir := Vector3(v.x, 0.0, v.z)
	if dir.length() < 0.1:
		dir = -cliente.global_transform.basis.z
		dir.y = 0.0
	dir = dir.normalized()
	cliente.set_physics_process(false)
	var corpo_c := cliente.get_node_or_null(^"Corpo") as Corpo
	var pe := cliente.global_position
	var de := pe + dir * 11.0

	var entregador := Node3D.new()
	entregador.name = "EntregadorDaSuper"
	add_child(entregador)
	entregador.global_position = de
	var corpo_e := Corpo.new()
	corpo_e.name = "Corpo"
	entregador.add_child(corpo_e)
	corpo_e.montar(ficha.get("aparencia", {}))
	_encarar(cliente, de)

	Cinema.fala("%s (celular): Entrega saindo. Olha ali na frente." % NOMES[outro])
	fase.emit(&"chegando", pe)
	await _andar(entregador, corpo_e, pe + dir * 0.8, [corpo_c], 1.45)
	if not is_instance_valid(cliente):
		_ir_embora(entregador, corpo_e, de)
		_fim()
		return

	# A entrega.
	_encarar(entregador, pe)
	_encarar(cliente, entregador.global_position)
	corpo_e.falar(true)
	Cinema.fala("%s: Chegou a encomenda. Direto do andar dez." % NOMES[quem])
	AudioDirector.tocar(&"pegar", pe + Vector3(0.0, 1.0, 0.0), -4.0)
	fase.emit(&"entregue", pe)
	await _parado(1.9, [corpo_c, corpo_e])
	corpo_e.falar(false)
	_ir_embora(entregador, corpo_e, de + dir * 4.0)

	# O cliente fuma, e so entao o efeito.
	if is_instance_valid(corpo_c):
		corpo_c.postura(Corpo.Postura.FUMANDO)
		corpo_c.tragando = true
		_fumaca(pe + Vector3(0.0, corpo_c.altura_da_boca() + 0.1, 0.0), 1, Color(0.9, 0.9, 0.86, 0.55), 0.5)
	await _parado(2.8, [corpo_c])
	if not is_instance_valid(cliente):
		_fim()
		return
	if is_instance_valid(corpo_c):
		corpo_c.tragando = false

	match efeito:
		Efeito.OLHO_DE_GATO:
			_vestir_olhos_em(cliente)
			var lista: Array = _ler(&"olhos", [])
			lista.append(int(cliente.ficha.get("id", 0)))
			_gravar(&"olhos", lista)
			fase.emit(&"efeito", pe)
			Cinema.fala("HELMER (celular): Olho de gato. Nove de cada dez.")
			await _parado(2.2, [corpo_c])
			_soltar(cliente, corpo_c)
		Efeito.ENXERGA_SOM:
			fase.emit(&"efeito", pe)
			Cinema.fala("HELMER (celular): Esse e o decimo. Enxerga som.")
			for k in 6:
				if is_instance_valid(corpo_c):
					corpo_c.olhar_lateral(0.7 if k % 2 == 0 else -0.7)
				await _parado(0.55, [corpo_c])
			if is_instance_valid(corpo_c):
				corpo_c.olhar_lateral(0.0)
			_soltar(cliente, corpo_c)
		Efeito.EXPLODE:
			_explodir(cliente, pe)
			fase.emit(&"efeito", pe)
			Cinema.fala("JOTA (celular): Esse era da prateleira de baixo.")
			await get_tree().create_timer(2.5).timeout
		Efeito.VOA:
			fase.emit(&"efeito", pe)
			Cinema.fala("JOTA (celular): E pros mais ousado... voam.")
			var lista: Array = _ler(&"voadores", [])
			lista.append(int(cliente.ficha.get("id", 0)))
			_gravar(&"voadores", lista)
			await _subir(cliente, corpo_c)
	_gravar(&"entregas", int(_ler(&"entregas", 0)) + 1)
	_fim()


func _fim() -> void:
	_em_cena = false
	_espera = _rng.randf_range(70.0, 130.0)


func _encarar(no: Node3D, ponto: Vector3) -> void:
	var d := ponto - no.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var g := no.global_rotation
	g.y = atan2(-d.x, -d.z)
	no.global_rotation = g


func _andar(no: Node3D, corpo: Corpo, ate: Vector3, outros: Array, velocidade: float) -> void:
	while is_instance_valid(no):
		var delta := get_process_delta_time()
		var d := ate - no.global_position
		d.y = 0.0
		if d.length() < 0.08:
			break
		_encarar(no, ate)
		no.global_position += d.normalized() * minf(d.length(), velocidade * delta)
		corpo.animar(velocidade, delta)
		for c: Variant in outros:
			if is_instance_valid(c):
				(c as Corpo).animar(0.0, delta)
		await get_tree().process_frame


func _parado(segundos: float, corpos: Array) -> void:
	var t := 0.0
	while t < segundos:
		var delta := get_process_delta_time()
		t += delta
		for c: Variant in corpos:
			if is_instance_valid(c):
				(c as Corpo).animar(0.0, delta)
		await get_tree().process_frame


func _ir_embora(no: Node3D, corpo: Corpo, para: Vector3) -> void:
	await _andar(no, corpo, para, [], 1.45)
	if is_instance_valid(no):
		no.queue_free()


func _soltar(cliente: Pedestre, corpo: Corpo) -> void:
	if not is_instance_valid(cliente):
		return
	if is_instance_valid(corpo):
		corpo.postura(Corpo.Postura.LIVRE)
	cliente.set_physics_process(true)


func _sumir(cliente: Pedestre) -> void:
	cliente.visible = false
	for filho: Node in cliente.get_children():
		var forma := filho as CollisionShape3D
		if forma != null:
			forma.set_deferred(&"disabled", true)


# --- efeitos ------------------------------------------------------------------

## Dois pontos verdes acesos no rosto, presos no osso da cabeca. O mesmo
## encaixe dos olhos vermelhos do Convidado: o deslocamento vai no filho,
## porque o BoneAttachment3D reescreve a propria transformada a cada quadro.
func _vestir_olhos_em(p: Node3D) -> void:
	if p.has_meta(&"olho_de_gato"):
		return
	var corpo := p.get_node_or_null(^"Corpo") as Corpo
	if corpo == null or corpo.esqueleto() == null:
		return
	var no := BoneAttachment3D.new()
	no.name = "OlhoDeGato"
	corpo.esqueleto().add_child(no)
	no.bone_idx = corpo.osso_da_cabeca()
	var sup: Dictionary = {}
	for s: float in [-1.0, 1.0]:
		# Grandes de proposito: com 3 cm cada, a dez metros eram meio pixel.
		AtlasKit.face(sup, &"l", Vector2(0.056, 0.04),
			Transform3D(Basis(), Vector3(s * 0.052, 0.02, 0.012)),
			EstufaBuilder.C_LENTE, Color(0.62, 1.0, 0.22))
	var mi := MeshInstance3D.new()
	mi.mesh = PSXMesh.dados_para_mesh(sup[&"l"])
	mi.material_override = load(MATERIAL_LUZ) as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(mi)
	mi.transform = corpo.plano_do_rosto()
	p.set_meta(&"olho_de_gato", true)


## Quem ja levou olho de gato continua na cidade com ele: todo pedestre que
## nascer com um desses ids ganha os olhos de novo.
func _vestir_olhos() -> void:
	var ids: Array = _ler(&"olhos", [])
	if ids.is_empty():
		return
	for p: Pedestre in Multidao.lista():
		if is_instance_valid(p) and not p.has_meta(&"olho_de_gato") \
				and ids.has(int(p.ficha.get("id", 0))):
			_vestir_olhos_em(p)


func _explodir(cliente: Pedestre, pe: Vector3) -> void:
	var centro := pe + Vector3(0.0, 1.0, 0.0)
	AudioDirector.tocar(&"tiro", centro, 4.0, 0.42)
	AudioDirector.tocar(&"trovao_perto", centro, -6.0, 1.6)
	_sumir(cliente)
	# O clarao: placas acesas que crescem e somem em dois decimos. A luz sozinha
	# acende o chao e mais nada; na nevoa, o que se ve de longe e a coisa acesa.
	# Seis placas finas em angulos sorteados, e nao tres em pe: tres placas em
	# pe liam como um painel claro parado no meio da calcada.
	var sup: Dictionary = {}
	for j in 6:
		var giro := Basis(Vector3.UP, _rng.randf() * TAU) 			* Basis(Vector3.RIGHT, _rng.randf_range(-1.2, 1.2)) 			* Basis(Vector3.BACK, _rng.randf() * TAU)
		AtlasKit.face(sup, &"l", Vector2(1.5, 0.28), Transform3D(giro, Vector3.ZERO),
			EstufaBuilder.C_LENTE, Color(0.85, 1.0, 0.6))
	var clarao := MeshInstance3D.new()
	clarao.mesh = PSXMesh.dados_para_mesh(sup[&"l"])
	clarao.material_override = load(MATERIAL_LUZ) as Material
	clarao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clarao)
	clarao.global_position = centro
	var tc := create_tween()
	tc.tween_property(clarao, ^"scale", Vector3.ONE * 2.4, 0.22)
	tc.tween_callback(clarao.queue_free)
	_fumaca(centro, 16, Color(0.5, 1.0, 0.35, 1.0), 2.6)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.8, 1.0, 0.6)
	luz.light_energy = 7.0
	luz.omni_range = 9.0
	add_child(luz)
	luz.global_position = centro
	var t := create_tween()
	t.tween_property(luz, ^"light_energy", 0.0, 0.35)
	t.tween_callback(luz.queue_free)


func _subir(cliente: Pedestre, corpo: Corpo) -> void:
	for filho: Node in cliente.get_children():
		var forma := filho as CollisionShape3D
		if forma != null:
			forma.set_deferred(&"disabled", true)
	if is_instance_valid(corpo):
		corpo.postura(Corpo.Postura.LIVRE)
	var inicio := cliente.global_position
	var giro0 := cliente.global_rotation.y
	var t := 0.0
	const DURA := 13.0
	while t < DURA and is_instance_valid(cliente):
		var delta := get_process_delta_time()
		t += delta
		var k := t / DURA
		cliente.global_position = inicio + Vector3(sin(t * 0.9) * 0.3,
			42.0 * k * k, cos(t * 0.7) * 0.3)
		var g := cliente.global_rotation
		g.y = giro0 + t * 0.6
		cliente.global_rotation = g
		if is_instance_valid(corpo):
			corpo.animar(0.0, delta, false)
		await get_tree().process_frame
	if is_instance_valid(cliente):
		_sumir(cliente)


## Placas cruzadas da fumaca do baseado que sobem, crescem e somem.
func _fumaca(onde: Vector3, quantas: int, cor: Color, tamanho: float) -> void:
	var mat := load(MATERIAL_FUMACA) as Material
	for k in quantas:
		var sup := PSXMesh.dados_vazios()
		for j in 2:
			PSXMesh.acumular(sup, PSXMesh.placa_dados(Vector2(tamanho, tamanho),
				100.0, cor), Transform3D(Basis(Vector3.UP, PI * 0.5 * float(j)), Vector3.ZERO))
		var mi := MeshInstance3D.new()
		mi.mesh = PSXMesh.dados_para_mesh(sup)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var espalha := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.2, 1.0),
			_rng.randf_range(-1.0, 1.0)) * (0.0 if quantas == 1 else 1.4)
		mi.global_position = onde
		var t := create_tween().set_parallel(true)
		t.tween_property(mi, ^"global_position", onde + espalha + Vector3(0.0, 0.9, 0.0), 2.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(mi, ^"scale", Vector3.ONE * 2.6, 2.4)
		t.chain().tween_callback(mi.queue_free)


## Para testes e capturas: o voo de volta de quem voou por ultimo, ja.
func voo_agora() -> void:
	var voadores: Array = _ler(&"voadores", [])
	if not voadores.is_empty():
		_voo(int(voadores[voadores.size() - 1]))


## O no do voo em andamento, se houver.
func voando() -> Node3D:
	return get_node_or_null(^"QuemVoaVolta") as Node3D


## Quem voou volta: um Corpo com a cara do cliente cruzando o ceu, deitado no
## ar, de um lado a outro da rua. Nunca no mesmo bairro, mas volta.
func _voo(id: int) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return
	var ficha := RegistroCivil.identidade(id)
	var ang := _rng.randf() * TAU
	var lado := Vector3(cos(ang), 0.0, sin(ang))
	var ortogonal := Vector3(-lado.z, 0.0, lado.x)
	var centro := jogador.global_position + ortogonal * _rng.randf_range(6.0, 13.0) \
		+ Vector3(0.0, _rng.randf_range(11.0, 15.0), 0.0)
	var no := Node3D.new()
	no.name = "QuemVoaVolta"
	add_child(no)
	var corpo := Corpo.new()
	corpo.name = "Corpo"
	no.add_child(corpo)
	corpo.montar(ficha.get("aparencia", {}))
	# Deitado de brucos, na direcao do voo.
	corpo.rotation = Vector3(-PI * 0.45, 0.0, 0.0)
	corpo.position = Vector3(0.0, 0.0, 0.9)
	var de := centro - lado * 42.0
	var para := centro + lado * 42.0
	no.global_position = de
	_encarar(no, para)
	if not _ja_voou_na_sessao:
		_ja_voou_na_sessao = true
		Cinema.fala("...quem voa sempre volta.")
	var t := 0.0
	const DURA := 22.0
	while t < DURA and is_instance_valid(no):
		var delta := get_process_delta_time()
		t += delta
		no.global_position = de.lerp(para, t / DURA) + Vector3(0.0, sin(t * 1.3) * 0.4, 0.0)
		corpo.animar(0.0, delta, false)
		await get_tree().process_frame
	if is_instance_valid(no):
		no.queue_free()

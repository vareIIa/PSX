## Missao 1, tarefa B: gestos de cena, posturas do carro, oculos e o Ator.
##
##     godot --headless --path game res://tests/m1_b.tscn
##
## Cena, e nao `--script`: o Ator fala com AudioDirector, Inventario e
## WorldState, e autoload so existe com a arvore do jogo de verdade.
##
## Mede pela ponta, como o resto da pasta: o gesto que "roda" mas deixa a mao a
## doze centimetros do oculos passa em qualquer teste de sinal e falha na tela.
## Entao cada gesto confere tres coisas — o sinal de fim chega no tempo, os ossos
## mexem no meio dele, e o corpo volta — e os que tocam alguma coisa conferem
## ONDE a mao chegou: o dedo na ponte do oculos, o papel no chao aos pes de
## quem devia, os pes acima do piso encostado no carro.
##
## Imprime `[m1_b] OK|XX nome detalhe` e sai com 1 se algum criterio falhar.
extends Node3D

## Ossos que tem de mexer no meio do gesto, em radianos (o maior entre os onze).
const MEXEU := 0.12
## A mao na armacao: o centro da palma a menos de uma mao (9 cm, a caixa dela)
## do centro do oculos. O indicador estendido cobre o resto.
const MAO_NO_OCULOS := 0.09

var _passou := 0
var _total := 0
var _cena: Node3D
var _berg: Ator


func _ready() -> void:
	_rodar()


func _rodar() -> void:
	await get_tree().process_frame
	_cena = Node3D.new()
	_cena.name = "TesteM1B"
	add_child(_cena)
	_chao()
	_berg = _criar_berg()
	_berg.position = Vector3(0.0, 0.0, 0.0)
	_cena.add_child(_berg)
	await _quadros(5)

	_conferir("elenco_no_acha_o_berg", Elenco.no(get_tree(), &"berg") == _berg, "")
	_conferir("osso_do_oculos", _berg.corpo().esqueleto().get_bone_count() > Corpo.Osso.OCULOS,
		"%d ossos" % _berg.corpo().esqueleto().get_bone_count())

	await _todos_os_gestos()
	await _oculos()
	await _papel()
	await _posturas()
	await _andar()
	await _ouricado()
	await _carro()
	await _vagar()

	print("\n[m1_b] %d de %d criterios" % [_passou, _total])
	AudioDirector.silenciar_tudo()
	get_tree().quit(0 if _passou == _total else 1)


# --- montagem -----------------------------------------------------------------

func _chao() -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(80.0, 1.0, 80.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.5, 0.0)
	corpo.add_child(forma)
	_cena.add_child(corpo)


func _criar_berg() -> Ator:
	var ficha := Elenco.ficha(Elenco.BERG)
	var ap: Dictionary = (ficha.get("aparencia", {}) as Dictionary).duplicate(true)
	# A tarefa D poe o oculos no Elenco; aqui o teste nao depende dela.
	ap["oculos"] = Aparencia.OCULOS_ESCURO
	ficha["aparencia"] = ap
	var a := Ator.new()
	a.name = "Berg"
	a.preparar(Elenco.BERG, ficha)
	return a


# --- gestos -------------------------------------------------------------------

func _todos_os_gestos() -> void:
	var c := _berg.corpo()
	for g: int in Corpo.GestoCena.values():
		if g == Corpo.GestoCena.NENHUM:
			continue
		var nome: String = Corpo.GestoCena.keys()[g]
		# Os de carro e os de sentado precisam da postura de onde partem.
		match g:
			Corpo.GestoCena.SAIR_CARRO, Corpo.GestoCena.MEXER_NO_RADIO, \
					Corpo.GestoCena.APERTAR_VOLANTE:
				c.altura_assento = 0.30
				c.postura(Corpo.Postura.DIRIGINDO)
			Corpo.GestoCena.DESENCOSTAR:
				c.postura(Corpo.Postura.ENCOSTADO_CARRO)
			_:
				c.postura(Corpo.Postura.LIVRE)
		await _quadros(25)
		var antes := _pose(c)
		var dur := Corpo.duracao_do_gesto(g)
		var terminou := [false]
		var marcas: Array[StringName] = []
		var ouvir := func(m_g: Corpo.GestoCena, m: StringName) -> void:
			if m_g == g:
				marcas.append(m)
		c.marca_do_gesto.connect(ouvir)
		var fim := func(f: Corpo.GestoCena) -> void:
			if f == g:
				terminou[0] = true
		c.gesto_de_cena_terminou.connect(fim)
		_berg.fazer(g)
		var maior := 0.0
		var t := 0.0
		while not terminou[0] and t < dur + 1.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			maior = maxf(maior, _diferenca(antes, _pose(c)))
		c.marca_do_gesto.disconnect(ouvir)
		c.gesto_de_cena_terminou.disconnect(fim)
		_conferir("gesto_" + nome.to_lower(), terminou[0] and maior >= MEXEU,
			"fim=%s mexeu=%.2f rad marcas=%s dur=%.1f" % [terminou[0], maior, marcas, dur])
		if g == Corpo.GestoCena.ENTRAR_CARRO:
			_conferir("entrar_termina_sentado", c.postura_atual() == Corpo.Postura.DIRIGINDO,
				Corpo.Postura.keys()[c.postura_atual()])
		if g == Corpo.GestoCena.SAIR_CARRO or g == Corpo.GestoCena.DESENCOSTAR:
			_conferir(nome.to_lower() + "_termina_de_pe", c.postura_atual() == Corpo.Postura.LIVRE,
				Corpo.Postura.keys()[c.postura_atual()])
		await _quadros(10)
		_berg.corpo().abaixar_oculos(0.0)
		_limpar_papel()
	c.postura(Corpo.Postura.LIVRE)
	await _quadros(20)


func _oculos() -> void:
	var c := _berg.corpo()
	c.postura(Corpo.Postura.LIVRE)
	c.abaixar_oculos(0.0)
	await _quadros(20)
	var sk := c.esqueleto()
	var repouso := (sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.OCULOS)).origin
	var cabeca0 := (sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.CABECA)).origin
	var dur := Corpo.duracao_do_gesto(Corpo.GestoCena.BAIXAR_OCULOS)
	var menor := INF
	var ouvido := [false]
	var pico := func(g: Corpo.GestoCena, m: StringName) -> void:
		if g == Corpo.GestoCena.BAIXAR_OCULOS and m == &"baixou":
			ouvido[0] = true
	c.marca_do_gesto.connect(pico)
	_berg.fazer(Corpo.GestoCena.BAIXAR_OCULOS)
	var t := 0.0
	while t < dur + 0.3:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > dur * 0.3 and t < dur * 0.75:
			var oc := (sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.OCULOS)).origin
			menor = minf(menor, _palma(c).distance_to(oc))
	c.marca_do_gesto.disconnect(pico)
	var baixo := (sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.OCULOS)).origin
	var cabeca1 := (sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.CABECA)).origin
	# A descida medida contra a cabeca: o queixo tambem baixou no gesto.
	var desceu := (repouso.y - cabeca0.y) - (baixo.y - cabeca1.y)
	_conferir("mao_chega_no_oculos", menor <= MAO_NO_OCULOS and ouvido[0],
		"%.1f cm (limite %.0f)" % [menor * 100.0, MAO_NO_OCULOS * 100.0])
	_conferir("oculos_fica_na_ponta_do_nariz",
		c.oculos_abaixado() >= 0.99 and desceu >= Corpo.OCULOS_DESCE * 0.8,
		"abaixado=%.2f desceu=%.1f cm" % [c.oculos_abaixado(), desceu * 100.0])
	await _berg.fazer(Corpo.GestoCena.SUBIR_OCULOS)
	await _quadros(5)
	var de_volta := (sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.OCULOS)).origin
	var cabeca2 := (sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.CABECA)).origin
	_conferir("oculos_volta_ao_lugar", c.oculos_abaixado() <= 0.01
		and absf((de_volta.y - cabeca2.y) - (repouso.y - cabeca0.y)) < 0.004,
		"abaixado=%.2f" % c.oculos_abaixado())


func _papel() -> void:
	_berg.corpo().postura(Corpo.Postura.LIVRE)
	_berg.global_position = Vector3.ZERO
	_berg.encarar(Vector3(0.0, 0.0, -5.0))
	await _quadros(10)
	var destino := Vector3(0.6, 0.0, -2.0)
	_berg.mirar_papel(destino)
	var caiu: Array[BilheteNoAr] = []
	_berg.papel_caiu.connect(func(p: BilheteNoAr) -> void: caiu.append(p), CONNECT_ONE_SHOT)
	await _berg.fazer(Corpo.GestoCena.JOGAR_PAPEL)
	var t := 0.0
	while caiu.is_empty() and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_conferir("papel_cai", not caiu.is_empty(), "%.1f s depois do gesto" % t)
	if caiu.is_empty():
		return
	var p := caiu[0]
	_conferir("papel_aos_pes_do_jogador", p.global_position.distance_to(destino) < 0.05
		and absf(p.global_position.y) < 0.02, "%s" % p.global_position)
	var mesmo := _berg.soltar_papel()
	_conferir("um_papel_so", mesmo != p or p.no_chao(), "")
	var item := p.item()
	_conferir("papel_vira_item", item != null and item.item_id == &"bilhete_berg"
		and item.rotulo_atual() == "Pegar o papel", "")
	if item == null:
		return
	var antes := Inventario.quantidade(&"bilhete_berg")
	var pego := [false]
	p.pego.connect(func(_q: Node) -> void: pego[0] = true)
	item.interagir(_cena)
	await _quadros(3)
	_conferir("papel_vai_pro_inventario",
		Inventario.quantidade(&"bilhete_berg") == antes + 1 and pego[0],
		"%d -> %d" % [antes, Inventario.quantidade(&"bilhete_berg")])


func _posturas() -> void:
	var c := _berg.corpo()
	_berg.global_position = Vector3.ZERO
	for p: int in [Corpo.Postura.ENCOSTADO_CARRO, Corpo.Postura.CARONA]:
		c.altura_assento = 0.30
		c.postura(p)
		var menor := INF
		var quadril_atras := -INF
		# Dois ciclos de troca de peso: cruzado e aberto.
		var t := 0.0
		while t < Corpo.CICLO_PESO_CARRO + 1.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			var sk := c.esqueleto()
			for canela: int in [Corpo.Osso.CANELA_E, Corpo.Osso.CANELA_D]:
				var g := sk.global_transform * sk.get_bone_global_pose(canela)
				var pe := g * Vector3(0.0, -(Corpo.Y_JOELHO - Corpo.Y_TORNOZELO) * c.altura() / Corpo.ALTURA_REF, 0.0)
				menor = minf(menor, pe.y - c.global_position.y)
			var q := sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.QUADRIL)
			quadril_atras = maxf(quadril_atras, (c.global_transform.affine_inverse() * q.origin).z)
		var nome: String = Corpo.Postura.keys()[p]
		_conferir(nome.to_lower() + "_pe_acima_do_chao", menor >= -0.01,
			"tornozelo mais baixo %.1f cm" % (menor * 100.0))
		if p == Corpo.Postura.ENCOSTADO_CARRO:
			_conferir("encostado_quadril_para_tras", quadril_atras > 0.10,
				"quadril %.0f cm atras dos pes" % (quadril_atras * 100.0))
	c.postura(Corpo.Postura.LIVRE)
	await _quadros(10)


func _andar() -> void:
	_berg.global_position = Vector3.ZERO
	await _quadros(5)
	var alvo := Vector3(3.0, 0.0, -4.0)
	var t0 := Time.get_ticks_msec()
	var rapido := [0.0]
	var medir := func() -> void:
		rapido[0] = maxf(rapido[0], _berg.corpo()._rapidez)
	get_tree().process_frame.connect(medir)
	await _berg.andar_ate(alvo)
	get_tree().process_frame.disconnect(medir)
	var s := (Time.get_ticks_msec() - t0) / 1000.0
	var esperado := alvo.length() / Ator.VEL_ANDAR
	_conferir("andar_chega", _berg.global_position.distance_to(alvo) <= Ator.PERTO + 0.02,
		"%.2f m do alvo em %.1f s (ideal %.1f)" % [_berg.global_position.distance_to(alvo), s, esperado])
	_conferir("andar_anima_o_passo", rapido[0] > 1.0 and rapido[0] < Ator.VEL_ANDAR + 0.3,
		"rapidez maxima %.2f m/s" % rapido[0])
	var frente := -_berg.global_transform.basis.z
	_conferir("andar_vira_para_o_passo", frente.dot(alvo.normalized()) > 0.95,
		"%.2f" % frente.dot(alvo.normalized()))


func _ouricado() -> void:
	var c := _berg.corpo()
	c.postura(Corpo.Postura.LIVRE)
	_berg.ouricado(true)
	await _quadros(10)
	var antes := _pose(c)
	var maior := 0.0
	var t := 0.0
	while t < 2.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		maior = maxf(maior, _diferenca(antes, _pose(c)))
	_conferir("ouricado_mexe", maior > 0.1, "%.2f rad em 2,5 s" % maior)
	var ch := _berg.get_node_or_null(^"Chaveiro") as Node3D
	_conferir("chaveiro_na_mao", ch != null and ch.visible
		and ch.global_position.distance_to(c.pega_no_mundo().origin) < 0.05, "")
	_berg.ouricado(false)
	await _quadros(10)


func _carro() -> void:
	var carro := Carro.new()
	carro.name = "Marea"
	# Ficha vazia: carro sem motorista (com ficha, a IA sai dirigindo).
	carro.preparar({}, Vector2i.ZERO, Vector4i.ZERO, 7)
	carro.modelo = Carroceria.Modelo.MAREA
	carro.tinta_fixa = Color(0.04, 0.04, 0.05)
	_cena.add_child(carro)
	carro.estacionar_solto(Vector3(6.0, 0.0, 6.0), 0.0)
	await _quadros(20)
	# Preso, como o carro de cena (a tarefa C prende o dela): solto no chao do
	# teste o corpo do Ator encostando empurrava o carro.
	carro.prender_estacionado(true)
	await _quadros(5)
	# Encostado no paralama do lado do carona, como na C3.
	await _berg.encostar_no_carro(carro, 1.0)
	_conferir("encosta_no_carro", _berg.corpo().postura_atual() == Corpo.Postura.ENCOSTADO_CARRO, "")
	await _berg.fazer(Corpo.GestoCena.DESENCOSTAR)
	await _berg.contornar_carro(carro, Carro.Banco.MOTORISTA)
	var porta := carro.ponto_da_porta(Carro.Banco.MOTORISTA)
	_conferir("contorna_ate_a_porta", _berg.global_position.distance_to(porta.origin) < 0.25,
		"%.2f m" % _berg.global_position.distance_to(porta.origin))
	await _berg.entrar_no_carro(carro, Carro.Banco.MOTORISTA)
	_conferir("entra_e_senta", _berg.corpo().postura_atual() == Corpo.Postura.DIRIGINDO, "")
	await _berg.sair_do_carro(carro, Carro.Banco.MOTORISTA)
	_conferir("sai_de_pe_na_porta", _berg.corpo().postura_atual() == Corpo.Postura.LIVRE
		and _berg.global_position.distance_to(porta.origin) < 0.3 and _berg.visible,
		"%.2f m" % _berg.global_position.distance_to(porta.origin))
	carro.queue_free()
	await _quadros(3)


func _vagar() -> void:
	var centro := Vector3(-5.0, 0.0, 5.0)
	_berg.global_position = centro
	await _quadros(5)
	_berg.vagar_em(centro, 3.0, Vector3(-5.0, 12.0, -2.0))
	var longe := 0.0
	var t := 0.0
	var andou := false
	var inicio := _berg.global_position
	while t < 20.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if _berg.global_position.distance_to(inicio) > 0.5:
			andou = true
		var d := Vector2(_berg.global_position.x - centro.x, _berg.global_position.z - centro.z)
		longe = maxf(longe, d.length())
	_conferir("vagar_anda_no_raio", andou and longe <= 3.2 and _berg.vagando(),
		"mais longe do centro %.1f m" % longe)
	var alvo := Vector3(-5.0, 0.0, 9.5)
	await _berg.andar_ate(alvo)
	_conferir("vagar_para_quando_o_roteiro_chama", not _berg.vagando()
		and _berg.global_position.distance_to(alvo) < 0.2, "")


# --- medidas ------------------------------------------------------------------

func _pose(c: Corpo) -> Array[Quaternion]:
	var sk := c.esqueleto()
	var q: Array[Quaternion] = []
	for o in 11:
		q.append(sk.get_bone_pose_rotation(o))
	return q


static func _diferenca(a: Array[Quaternion], b: Array[Quaternion]) -> float:
	var maior := 0.0
	for i in a.size():
		maior = maxf(maior, a[i].angle_to(b[i]))
	return maior


## O centro da palma direita: `GestoDeCarga.PALMA` alem do punho, ao longo do
## antebraco (o ponto que o IK dos gestos leva ao alvo).
static func _palma(c: Corpo) -> Vector3:
	var sk := c.esqueleto()
	var s := c.altura() / Corpo.ALTURA_REF
	var a := sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.ANTEBRACO_D)
	var l := (Corpo.Y_COTOVELO - Corpo.Y_PUNHO) * s + GestoDeCarga.PALMA * s
	return a * Vector3(0.0, -l, 0.0)


func _limpar_papel() -> void:
	for n: Node in _cena.get_children():
		if n is BilheteNoAr:
			n.queue_free()


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _conferir(nome: String, ok: bool, detalhe: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("[m1_b] %s %-36s %s" % ["OK" if ok else "XX", nome, detalhe])

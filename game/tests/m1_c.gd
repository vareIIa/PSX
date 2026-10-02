## Missao 1, tarefa C: o carro do Berg. Portas, banco, carona, dirigir sozinho,
## estacionar com duas rodas na calcada e o passeio que some.
##
##     godot --headless --path game --fixed-fps 60 --script res://tests/m1_c.gd
##
## Bancada e nao cidade: chao plano (`Relevo.ativo = false`), meio-fio de caixa
## posto a mao ao lado da faixa, e a malha de ruas da `Vias`, que e funcao pura
## da coordenada e responde sem a cidade carregada. Sem transito em volta.
##
##   CRIAR     o carro de cena nasce na calcada: rodas do lado do meio-fio em
##             cima dele, as da rua no asfalto, torto, preso, fora da tecla.
##   PORTAS    as duas abrem e fecham: sinal, angulo da dobradica, lataria
##             trocada pela recortada so enquanto ha porta aberta.
##   BANCO     um Ator ao volante (DIRIGINDO) e outro de carona (CARONA), filhos
##             do carro e sem colisao; levantar devolve de pe, com colisao.
##   CARONA    o jogador embarca animado no banco do passageiro (cabine montada,
##             camera dela na tela), e desce animado.
##   IR_PARA   tres quadras pela malha, com o jogador de carona, e chega.
##   VAGA      estaciona na calcada: duas rodas acima do meio-fio, presas.
##   VAGAR     anda a esmo, some fora da vista (sem tela, ja esta), e o Berg
##             sai do carro escondido para a missao o por na igreja.
extends SceneTree

const MEIO_FIO := 0.16

var _passou := 0
var _total := 0
var _mundo: Node3D
var _carro_script: GDScript
var _sinais := {}


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	await process_frame
	(load("res://src/world/relevo.gd") as GDScript).set(&"ativo", false)
	_carro_script = load("res://src/world/carro.gd") as GDScript
	_mundo = Node3D.new()
	_mundo.name = "Mundo"
	root.add_child(_mundo)
	_chao(Vector3.ZERO, Vector3(900.0, 1.0, 900.0), 0.0)
	var transito: Node = root.get_node(^"Transito")
	transito.set(&"raiz", _mundo)
	# O relogio dos sinais anda no _process do Transito, que fica desligado na
	# bancada (nao ha cidade para povoar). Sem ele o primeiro vermelho e eterno.
	var semaforo := load("res://src/world/semaforo.gd") as GDScript
	physics_frame.connect(func() -> void: semaforo.call(&"avancar", 1.0 / 60.0))
	print("\n=== M1-C: carro do Berg ===\n")

	var vias := load("res://src/world/vias.gd") as GDScript
	var inicio := _faixa_reta(vias, Vector3(8.0, 0.0, 8.0))
	if inicio.is_empty():
		_conta("faixa", false, "nenhuma faixa perto da origem")
		_fim()
		return
	var dir: Vector3 = inicio["dir"]
	var direita := dir.cross(Vector3.UP)
	var ponto: Vector3 = inicio["ponto"]
	# A calcada a direita da faixa: o carro para com as rodas da direita nela.
	var vaga := ponto + direita * 1.3
	_calcada(vaga, dir, direita)

	var elenco := load("res://src/systems/elenco.gd") as GDScript
	var ficha: Dictionary = elenco.call(&"ficha", &"berg")
	var pose := Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), vaga)
	var c: Node3D = transito.call(&"criar_carro_de_cena", ficha, pose)
	await physics_frame
	await _criar(c, transito)
	await _portas(c)
	await _banco(c, ficha)
	await _carona(c)
	await _ir_e_estacionar(c, vias, dir)
	await _vagar(c, ficha)
	_fim()


func _fim() -> void:
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %-14s %s" % ["ok" if ok else "FALHOU", nome, texto])


# --- montagem da bancada ------------------------------------------------------

func _chao(centro: Vector3, tam: Vector3, topo: float) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tam
	forma.shape = caixa
	corpo.add_child(forma)
	corpo.position = Vector3(centro.x, topo - tam.y * 0.5, centro.z)
	_mundo.add_child(corpo)
	return corpo


## Um meio-fio: caixa de 16 cm, comprida ao longo da faixa, comecando a 0,3 m
## do centro da vaga para a direita.
func _calcada(vaga: Vector3, dir: Vector3, direita: Vector3) -> void:
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(4.0, MEIO_FIO, 16.0)
	forma.shape = caixa
	corpo.add_child(forma)
	corpo.basis = Basis(Vector3.UP, atan2(-dir.x, -dir.z))
	corpo.position = vaga + direita * (0.3 + 2.0) + Vector3.UP * (MEIO_FIO * 0.5)
	_mundo.add_child(corpo)


func _faixa_reta(vias: GDScript, perto: Vector3) -> Dictionary:
	for t: Dictionary in vias.call(&"trechos_perto", perto, 0.0, 60.0):
		var tr: Vector4i = t["trecho"]
		if tr.x != 0:
			continue
		return {"ponto": t["ponto"], "dir": vias.call(&"direcao", tr.z, tr.w),
			"trecho": tr, "de": t["de"]}
	return {}


func _contar_sinal(c: Object, nome: StringName) -> void:
	_sinais[nome] = 0
	c.connect(nome, func(_a: Variant = null) -> void:
		_sinais[nome] = int(_sinais[nome]) + 1)


## Altura de cada roda no mundo: [FE, FD, TE, TD].
func _rodas_no_mundo(c: Node3D) -> PackedFloat32Array:
	var m: Dictionary = c.call(&"medidas")
	var meia := float(m["bitola"]) * 0.5
	var eixo := float(m["entre_eixos"]) * 0.5
	var out := PackedFloat32Array()
	for k in 4:
		var p: Vector3 = c.global_transform * Vector3(meia if k % 2 == 1 else -meia,
			0.0, -eixo if k < 2 else eixo)
		out.append(p.y)
	return out


func _esperar(seg: float) -> void:
	var t := 0.0
	while t < seg:
		await physics_frame
		t += 1.0 / 60.0


# --- etapas -------------------------------------------------------------------

func _criar(c: Node3D, transito: Node) -> void:
	_conta("criar", c != null and is_instance_valid(c), "carro de cena criado")
	var h := _rodas_no_mundo(c)
	var calcada := minf(h[1], h[3])
	var rua := maxf(h[0], h[2])
	_conta("criar_calcada", calcada > MEIO_FIO * 0.75 and rua < 0.05,
		"rodas da calcada %.3f / %.3f, da rua %.3f / %.3f" % [h[1], h[3], h[0], h[2]])
	var rolagem := rad_to_deg(asin(clampf(c.global_transform.basis.x.y, -1.0, 1.0)))
	_conta("criar_torto", absf(rolagem) > 4.0 and absf(rolagem) < 9.0,
		"inclinado %.1f graus (roteiro: ~6)" % rolagem)
	_conta("criar_preso", bool(c.get(&"freeze")) and bool(transito.call(&"estacionado", c)),
		"preso e registrado no Transito")
	_conta("criar_tecla", String(c.call(&"rotulo_de_acao")).is_empty()
		and transito.call(&"mais_perto", c.global_position, 5.0) == null,
		"a tecla de entrar nao acha o carro do Berg")
	_conta("criar_berg", c.has_meta(&"do_berg") and c.get_node_or_null(^"AdesivoSaoThome") != null,
		"Marea do Berg: rebaixado, calota e adesivo")


func _portas(c: Node3D) -> void:
	_contar_sinal(c, &"porta_abriu")
	_contar_sinal(c, &"porta_fechou")
	var lataria: MeshInstance3D = c.get(&"_corpo_malha")
	var inteira := lataria.mesh
	var portas: Node3D = c.get(&"_portas")
	_conta("portas_prontas", portas != null and bool(portas.call(&"pronta")),
		"portas recortadas ao nascer")
	if portas == null:
		return
	var tris := 0
	for f: Node in portas.find_children("Porta", "MeshInstance3D", true, false):
		var mi := f as MeshInstance3D
		tris += mi.mesh.get_faces().size() / 3
	_conta("portas_malha", tris > 60, "%d triangulos nas duas portas" % tris)
	_conta("portas_ociosas", not portas.visible and lataria.mesh == inteira,
		"fechadas: malha inteira, sem chamada a mais")
	await c.call(&"abrir_porta", 0)
	await c.call(&"abrir_porta", 1)
	var giro0 := rad_to_deg((portas.get_node(^"DobradicaMotorista") as Node3D).rotation.y)
	var giro1 := rad_to_deg((portas.get_node(^"DobradicaPassageiro") as Node3D).rotation.y)
	_conta("portas_abertas", absf(giro0 + 62.0) < 2.0 and absf(giro1 - 62.0) < 2.0
		and lataria.mesh != inteira and portas.visible,
		"dobradicas em %.0f / %.0f graus, lataria recortada" % [giro0, giro1])
	await c.call(&"fechar_porta", 0)
	await c.call(&"fechar_porta", 1)
	_conta("portas_fechadas", lataria.mesh == inteira and not portas.visible
		and absf(float(c.call(&"abertura_da_porta", 0))) < 0.001,
		"fechadas: malha inteira de volta")
	_conta("portas_sinais", int(_sinais[&"porta_abriu"]) == 2
		and int(_sinais[&"porta_fechou"]) == 2,
		"abriu %d, fechou %d" % [_sinais[&"porta_abriu"], _sinais[&"porta_fechou"]])


func _novo_ator(ficha: Dictionary) -> Node3D:
	var a: Node3D = (load("res://src/world/ator.gd") as GDScript).new()
	a.call(&"preparar", &"berg", ficha)
	_mundo.add_child(a)
	return a


func _banco(c: Node3D, ficha: Dictionary) -> void:
	var berg := _novo_ator(ficha)
	berg.global_position = (c.call(&"ponto_da_porta", 0) as Transform3D).origin
	await physics_frame
	await berg.call(&"entrar_no_carro", c, 0)
	var corpo: Node = berg.call(&"corpo")
	_conta("banco_motorista", c.call(&"ocupante", 0) == berg and berg.get_parent() == c
		and int(corpo.call(&"postura_atual")) == int(corpo.get_script().get_script_constant_map()["Postura"]["DIRIGINDO"])
		and (berg as CollisionObject3D).collision_layer == 0,
		"Berg ao volante, filho do carro, sem colisao")
	var outro := _novo_ator(ficha)
	c.call(&"sentar_no_banco", outro, 1)
	var c2: Node = outro.call(&"corpo")
	_conta("banco_carona", c.call(&"ocupante", 1) == outro
		and int(c2.call(&"postura_atual")) == int(c2.get_script().get_script_constant_map()["Postura"]["CARONA"]),
		"Ator de carona em CARONA")
	var saiu: Node3D = c.call(&"levantar_do_banco", 1)
	_conta("banco_levantar", saiu == outro and outro.get_parent() == _mundo
		and (outro as CollisionObject3D).collision_layer != 0
		and c.call(&"ocupante", 1) == null,
		"de pe ao lado da porta, com colisao")
	outro.queue_free()


func _carona(c: Node3D) -> void:
	var cena := load("res://scenes/player/player.tscn") as PackedScene
	var jogador: Node3D = cena.instantiate()
	_mundo.add_child(jogador)
	jogador.global_position = (c.call(&"ponto_da_porta", 1) as Transform3D).origin \
		+ Vector3(0.0, 0.05, 1.5)
	await physics_frame
	await physics_frame
	await jogador.call(&"embarcar", c, 1, true)
	var cab := c.get_node_or_null(^"CabineDoJogador")
	var cam_cab: Camera3D = cab.call(&"camera_de_dentro") if cab != null else null
	_conta("carona_entrou", bool(jogador.call(&"de_carona")) and cab != null
		and cam_cab != null and cam_cab.current
		and c.call(&"ocupante", 1) == jogador
		and float(c.call(&"abertura_da_porta", 1)) < 0.001,
		"no banco do passageiro, camera da cabine, porta fechada")
	_jogador = jogador


var _jogador: Node3D


func _ir_e_estacionar(c: Node3D, vias: GDScript, dir: Vector3) -> void:
	_contar_sinal(c, &"chegou_ao_destino")
	# Tres quadras: um ponto de faixa em outra rua, a uns cem metros.
	var alvo := Vector3.INF
	var origem := c.global_position
	for t: Dictionary in vias.call(&"trechos_perto", origem, 85.0, 110.0):
		var tr: Vector4i = t["trecho"]
		var d: Vector3 = vias.call(&"direcao", tr.z, tr.w)
		if tr.x == 0 and absf(d.dot(dir)) < 0.1:
			alvo = t["ponto"]
			break
	if not alvo.is_finite():
		_conta("ir_para", false, "nenhuma rua transversal a 100 m")
		return
	var t0 := Time.get_ticks_msec()
	var feito := [false]
	var tarefa := func() -> void:
		await c.call(&"ir_para", alvo)
		feito[0] = true
	tarefa.call()
	var seg := 0.0
	while not feito[0] and seg < 150.0:
		await physics_frame
		seg += 1.0 / 60.0
		if OS.has_environment("M1C_TRACO") and int(seg * 60.0) % 60 == 0:
			print("    t=%.0f pos=%s cena=%s jog=%s pp=%s pm=%s" % [seg,  c.global_position.snapped(Vector3.ONE * 0.1), c.call(&"modo_de_cena"), _jogador.global_position.snapped(Vector3.ONE * 0.1), _jogador.get_instance_id(), Engine.get_physics_frames()])
	var dist := Vector2(c.global_position.x - alvo.x, c.global_position.z - alvo.z).length()
	_conta("ir_para", feito[0] and dist < 12.0 and int(_sinais[&"chegou_ao_destino"]) == 1,
		"%.0f m ate o alvo em %.0f s de jogo (%.1f s reais), parou a %.1f m"
		% [origem.distance_to(alvo), seg, (Time.get_ticks_msec() - t0) / 1000.0, dist])
	_conta("ir_para_carona", _jogador != null and bool(_jogador.call(&"de_carona"))
		and _jogador.global_position.distance_to(c.global_position) < 2.0,
		"o jogador foi junto, de carona (%s, a %.1f m do carro)" % [_jogador.call(&"de_carona"),
			_jogador.global_position.distance_to(c.global_position)])
	# Desce antes de estacionar: a vaga e da cena 6A, com os dois saindo.
	await _jogador.call(&"desembarcar_animado")
	_conta("carona_desceu", not bool(_jogador.call(&"de_carona")) and _jogador.visible
		and c.get_node_or_null(^"CabineDoJogador") == null,
		"de pe ao lado da porta, cabine desmontada")

	# A vaga: a direita da faixa em que ele parou, na calcada.
	var frente := -c.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var direita := frente.cross(Vector3.UP)
	var vaga := c.global_position + frente * 7.0 + direita * 1.3
	vaga.y = 0.0
	_calcada(vaga, frente, direita)
	var pose := Transform3D(Basis(Vector3.UP, atan2(-frente.x, -frente.z)), vaga)
	var feito2 := [false]
	var tarefa2 := func() -> void:
		await c.call(&"estacionar_na_calcada", pose, true)
		feito2[0] = true
	tarefa2.call()
	seg = 0.0
	while not feito2[0] and seg < 20.0:
		await physics_frame
		seg += 1.0 / 60.0
	var h := _rodas_no_mundo(c)
	var giro := rad_to_deg(wrapf(c.global_rotation.y - atan2(-frente.x, -frente.z), -PI, PI))
	_conta("vaga", feito2[0] and minf(h[1], h[3]) > MEIO_FIO * 0.75 and maxf(h[0], h[2]) < 0.05,
		"rodas da calcada %.3f / %.3f, da rua %.3f / %.3f, %.1f s"
		% [h[1], h[3], h[0], h[2], seg])
	_conta("vaga_torto", absf(giro) > 5.0 and absf(giro) < 12.0
		and bool(c.get(&"freeze")) and int(c.get(&"motorista")) == 0,
		"torto %.1f graus, preso, sem motorista" % giro)


func _vagar(c: Node3D, _ficha: Dictionary) -> void:
	_contar_sinal(c, &"sumiu")
	var berg: Node3D = c.call(&"ocupante", 0)
	var tarefa := func() -> void:
		await c.call(&"vagar", 5.0)
	tarefa.call()
	var seg := 0.0
	var andou := 0.0
	var antes := c.global_position
	while is_instance_valid(c) and seg < 40.0:
		await physics_frame
		seg += 1.0 / 60.0
		if is_instance_valid(c):
			andou += c.global_position.distance_to(antes)
			antes = c.global_position
	_conta("vagar", not is_instance_valid(c) and int(_sinais[&"sumiu"]) == 1 and andou > 15.0,
		"andou %.0f m e sumiu aos %.1f s" % [andou, seg])
	_conta("vagar_berg", berg != null and is_instance_valid(berg) and not berg.visible
		and berg.has_meta(&"sumiu_com_carro"),
		"o Berg saiu do carro, escondido, para a igreja")

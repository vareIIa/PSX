## O elevador de carga da estufa: cabine de barra, talha de corrente e uma
## botoeira que so conhece dois andares.
##
## E o unico jeito de chegar ao andar 10, e a viagem e o ponto: onze segundos
## subindo o poco com as galerias passando pela grade e a placa de cada andar
## pintada na parede da frente. Teleporte entregaria o andar 10 e roubaria o
## predio.
##
## A cabine e um AnimatableBody3D, e o jogador vai em pe no piso dela como iria
## numa plataforma qualquer: o CharacterBody3D herda a velocidade do chao. Ele
## vai travado so para nao andar — a camera continua livre, porque olhar em
## volta e o que se faz num elevador de obra.
##
## A lista de andares tem dez linhas e a botoeira aceita duas. Os outros oito
## andares existem como placa, como recusa e como piada, e nao custam sala
## nenhuma. Ver PLANO_CASA_FUMACA_V2.md, secao 13.
class_name Elevador
extends Node3D

const MATERIAL := "res://resources/materials/mat_estufa.tres"
const MATERIAL_LUZ := "res://resources/materials/mat_estufa_luz.tres"
const MATERIAL_QUADROS := "res://resources/materials/mat_estufa_quadros.tres"

## A cabine, em planta e em altura. Cabe no vao de 2 x 2 do andaime com 15 cm
## de folga de cada lado: menos que isso, a barra raspa no montante a cada
## andar que passa.
const LADO := 1.7
const ALTO := 2.3
## Metros por segundo no meio da viagem. Talha de obra: devagar o bastante para
## ler a placa de cada andar, rapido o bastante para nao virar cutscene.
const VELOCIDADE := 2.4
## Barras por parede. Doze dao 14 cm de vao, que e grade e nao janela.
const BARRAS := 12
## Tinta de maquina de obra. Vai sobre a celula de lona, que e branca: sobre a
## mangueira, que e preta, qualquer tinta sai preta.
const AMARELO := Color(0.90, 0.70, 0.12)

const ANDARES: PackedStringArray = [
	"LAVOURA", "SECAGEM", "MUDA", "MUDA TAMBEM", "MUDA AINDA",
	"NAO SUBIR", "NAO SUBIR (SERIO)", "O ANDAR DO CHEIRO", "???",
	"SO O JOTA E O HELMER",
]

## Onde o piso da cabine para no andar 10, em coordenada do comodo.
@export var topo: float = 25.15
## Onde a corrente termina, na polia da talha.
@export var polia: float = 28.5

## Na hora em que a cabine sai do lugar, com a grade ja fechada. Quem esta no
## andar de destino tem a viagem inteira para se arrumar.
signal partiu(para: int)
signal chegou(andar: int)

var _cabine: AnimatableBody3D
var _porta: CollisionShape3D
var _barras_porta: Array[Node3D] = []
var _corrente: MeshInstance3D
var _motor: AudioStreamPlayer3D
var _botao: Interativo
var _chapa: Interativo
var _luz_recusa: MeshInstance3D
var _andando := false
var _no_topo := false
var _proximo_falso := 2
## Os andares interditados dao sinal de vida quando a cabine passa: batidas na
## porta do 7 e dois olhos no escuro do 9, que fecham quando a cabine chega na
## altura deles. O cenario parado (nevoa do 8, a porta) e do EstufaBuilder.
var _olhos: MeshInstance3D
var _olho_antes := -1.0


func _ready() -> void:
	add_to_group(&"elevador")
	_cabine = AnimatableBody3D.new()
	_cabine.name = "Cabine"
	_cabine.sync_to_physics = true
	add_child(_cabine)
	_montar_cabine()
	_montar_colisao()
	_montar_porta()
	_montar_botoeira()
	_montar_corrente()
	_montar_olhos()
	_motor = AudioStreamPlayer3D.new()
	_motor.name = "Talha"
	_motor.stream = AudioDirector.em_loop(&"catraca_loop")
	_motor.pitch_scale = 0.62
	_motor.volume_db = -9.0
	_motor.bus = &"SFX"
	_motor.position = Vector3(0.0, ALTO + 0.3, 0.0)
	_cabine.add_child(_motor)
	_atualizar_rotulos()


func _process(_delta: float) -> void:
	# A corrente vai do gancho no teto da cabine ate a polia, e encurta enquanto
	# sobe. E uma malha de um metro esticada: corrente escura a vinte metros nao
	# mostra elo nenhum.
	var base := _cabine.position.y + ALTO + 0.22
	_corrente.position = Vector3(0.0, base, 0.0)
	_corrente.scale = Vector3(1.0, maxf(0.05, polia - base), 1.0)


func _physics_process(_delta: float) -> void:
	if not _andando:
		return
	var olho := _cabine.position.y + 1.62
	if _olho_antes >= 0.0:
		var bate := EstufaBuilder.PE * 6.0 + 1.3
		if (_olho_antes - bate) * (olho - bate) < 0.0:
			_bater_na_porta()
		if _olhos.visible and absf(olho - _olhos.position.y) < 1.1:
			_olhos.visible = false
	_olho_antes = olho


func _bater_na_porta() -> void:
	var porta := to_global(Vector3(0.0, EstufaBuilder.PE * 6.0 + 1.2,
		EstufaBuilder.FUNDO - EstufaBuilder.ELEVADOR.z - 0.1))
	for k in 3:
		AudioDirector.tocar(StringName("passo_madeira_%d" % (k + 1)), porta, 3.0, 0.7)
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(0.6).timeout
	AudioDirector.tocar(&"porta_trinco", porta, 0.0, 0.85)


# --- montagem -----------------------------------------------------------------

func _montar_cabine() -> void:
	var sup: Dictionary = {}
	var h := LADO * 0.5
	# O piso de chapa, rente ao chao do andar quando parada.
	AtlasKit.caixa(sup, &"e", Vector3(0.0, -0.05, 0.0), Vector3(LADO, 0.1, LADO),
		EstufaBuilder.C_PISO, Color(0.58, 0.58, 0.56))
	# Os quatro montantes e o quadro de cima.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			AtlasKit.caixa(sup, &"e", Vector3(sx * (h - 0.035), ALTO * 0.5,
				sz * (h - 0.035)), Vector3(0.07, ALTO, 0.07),
				EstufaBuilder.C_LONA, AMARELO)
	for s: float in [-1.0, 1.0]:
		AtlasKit.caixa(sup, &"e", Vector3(0.0, ALTO, s * (h - 0.035)),
			Vector3(LADO, 0.08, 0.07), EstufaBuilder.C_LONA, AMARELO)
		AtlasKit.caixa(sup, &"e", Vector3(s * (h - 0.035), ALTO, 0.0),
			Vector3(0.07, 0.08, LADO), EstufaBuilder.C_LONA, AMARELO)
	# O teto de chapa e o olhal da corrente.
	AtlasKit.caixa(sup, &"e", Vector3(0.0, ALTO + 0.055, 0.0),
		Vector3(LADO, 0.03, LADO), EstufaBuilder.C_REFLETOR, Color(0.5, 0.5, 0.5))
	AtlasKit.caixa(sup, &"e", Vector3(0.0, ALTO + 0.15, 0.0),
		Vector3(0.12, 0.18, 0.12), EstufaBuilder.C_LONA, AMARELO)
	# Tres paredes de barra, com rodape e travessa no meio. A quarta e a porta.
	var paredes: Array = [
		[Vector3(-h, 0.0, 0.0), Vector3(0.0, 0.0, 1.0)],
		[Vector3(h, 0.0, 0.0), Vector3(0.0, 0.0, 1.0)],
		[Vector3(0.0, 0.0, h), Vector3(1.0, 0.0, 0.0)],
	]
	for p: Array in paredes:
		var centro: Vector3 = p[0]
		var eixo: Vector3 = p[1]
		var dentro := centro - centro.normalized() * 0.02
		for k in BARRAS:
			var em := dentro + eixo * lerpf(-h + 0.1, h - 0.1,
				float(k) / float(BARRAS - 1))
			AtlasKit.tubo(sup, &"e", em + Vector3(0.0, 0.2, 0.0),
				em + Vector3(0.0, ALTO - 0.04, 0.0), 0.012,
				EstufaBuilder.C_LONA, AMARELO)
		var comp := Vector3(absf(eixo.x) * LADO + 0.04, 0.0,
			absf(eixo.z) * LADO + 0.04)
		AtlasKit.caixa(sup, &"e", dentro + Vector3(0.0, 0.1, 0.0),
			comp + Vector3(0.0, 0.2, 0.0) + (Vector3.ONE - eixo.abs()) * 0.02,
			EstufaBuilder.C_REFLETOR, Color(0.5, 0.5, 0.48))
		AtlasKit.caixa(sup, &"e", dentro + Vector3(0.0, 1.05, 0.0),
			comp + Vector3(0.0, 0.05, 0.0) + (Vector3.ONE - eixo.abs()) * 0.03,
			EstufaBuilder.C_LONA, AMARELO)
	# O trilho da porta, em cima e embaixo.
	for y: float in [0.03, ALTO - 0.1]:
		AtlasKit.tubo(sup, &"e", Vector3(-h, y, -h), Vector3(h, y, -h), 0.02,
			EstufaBuilder.C_LONA, AMARELO)
	_instanciar(_cabine, sup)


func _montar_colisao() -> void:
	var h := LADO * 0.5
	for c: Array in [
			[Vector3(LADO, 0.1, LADO), Vector3(0.0, -0.05, 0.0)],
			[Vector3(0.06, ALTO, LADO), Vector3(-h, ALTO * 0.5, 0.0)],
			[Vector3(0.06, ALTO, LADO), Vector3(h, ALTO * 0.5, 0.0)],
			[Vector3(LADO, ALTO, 0.06), Vector3(0.0, ALTO * 0.5, h)]]:
		_cabine.add_child(_forma(c[0], c[1]))
	# A porta so e solida com a cabine andando. Parada, a grade esta recolhida
	# num canto e o vao e livre.
	_porta = _forma(Vector3(LADO, ALTO, 0.06), Vector3(0.0, ALTO * 0.5, -h))
	_porta.disabled = true
	_cabine.add_child(_porta)


## A porta pantografica: barras que correm para o canto oeste quando abre.
func _montar_porta() -> void:
	var sup: Dictionary = {}
	AtlasKit.tubo(sup, &"e", Vector3(0.0, 0.08, 0.0),
		Vector3(0.0, ALTO - 0.14, 0.0), 0.014, EstufaBuilder.C_LONA,
		Color(0.42, 0.42, 0.40))
	var malha := PSXMesh.dados_para_mesh(sup[&"e"])
	var mat := load(MATERIAL) as Material
	for k in BARRAS:
		var barra := MeshInstance3D.new()
		barra.mesh = malha
		barra.material_override = mat
		barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		barra.position = Vector3(_x_da_barra(k, true), 0.0, -LADO * 0.5 - 0.02)
		_cabine.add_child(barra)
		_barras_porta.append(barra)


func _x_da_barra(k: int, aberta: bool) -> float:
	var h := LADO * 0.5
	if aberta:
		return -h + 0.06 + float(k) * 0.028
	return lerpf(-h + 0.06, h - 0.06, float(k) / float(BARRAS - 1))


## A botoeira amarela e a chapa com a lista, na parede leste por dentro.
func _montar_botoeira() -> void:
	var sup: Dictionary = {}
	var h := LADO * 0.5
	var caixa := Vector3(h - 0.07, 1.2, -0.42)
	# Girada para a frente olhar para dentro (-X): o x da caixa vira o z do mundo.
	AtlasKit.caixa(sup, &"e", caixa, Vector3(0.2, 0.36, 0.08),
		EstufaBuilder.C_LONA, AMARELO, -PI * 0.5, EstufaBuilder.C_PAINEL)
	AtlasKit.caixa(sup, &"e", caixa + Vector3(-0.045, 0.02, 0.0),
		Vector3(0.03, 0.05, 0.05), EstufaBuilder.C_MANGUEIRA,
		Color(0.2, 0.75, 0.25))
	AtlasKit.caixa(sup, &"e", caixa + Vector3(-0.045, -0.09, 0.0),
		Vector3(0.03, 0.05, 0.05), EstufaBuilder.C_MANGUEIRA,
		Color(0.85, 0.18, 0.14))
	# O conduite do cabo de comando, subindo ate o teto da cabine.
	AtlasKit.tubo(sup, &"e", caixa + Vector3(0.0, 0.18, 0.0),
		Vector3(caixa.x, ALTO, caixa.z), 0.018, EstufaBuilder.C_MANGUEIRA,
		Color(0.25, 0.25, 0.25))
	var chapa := Vector3(h - 0.05, 1.32, 0.2)
	EstufaBuilder.placa_atlas(sup, &"q", chapa, Vector2(0.4, 0.3), -PI * 0.5,
		EstufaBuilder.RECT_CHAPA)
	_instanciar(_cabine, sup)

	# A luzinha que acende quando o andar recusa.
	var luz: Dictionary = {}
	AtlasKit.face(luz, &"luz", Vector2(0.04, 0.04),
		Transform3D(Basis(Vector3.UP, -PI * 0.5), caixa + Vector3(-0.042, 0.13, 0.0)),
		EstufaBuilder.C_LENTE, Color(1.0, 0.35, 0.2))
	_luz_recusa = MeshInstance3D.new()
	_luz_recusa.mesh = PSXMesh.dados_para_mesh(luz[&"luz"])
	_luz_recusa.material_override = load(MATERIAL_LUZ) as Material
	_luz_recusa.visible = false
	_cabine.add_child(_luz_recusa)

	_botao = _interativo(caixa + Vector3(-0.04, 0.0, 0.0), Vector3(0.14, 0.42, 0.28))
	_botao.acionado.connect(_ao_botao)
	_chapa = _interativo(chapa + Vector3(-0.03, 0.0, 0.0), Vector3(0.1, 0.34, 0.44))
	_chapa.acionado.connect(_ao_chapa)


## Dois pontos acesos no fundo da galeria do 9, olhando para o vao.
func _montar_olhos() -> void:
	var sup: Dictionary = {}
	for s: float in [-1.0, 1.0]:
		AtlasKit.face(sup, &"luz", Vector2(0.07, 0.035),
			Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.0, s * 0.055)),
			EstufaBuilder.C_LENTE, Color(0.72, 1.0, 0.28))
	_olhos = MeshInstance3D.new()
	_olhos.name = "Olhos"
	_olhos.mesh = PSXMesh.dados_para_mesh(sup[&"luz"])
	_olhos.material_override = load(MATERIAL_LUZ) as Material
	_olhos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Na galeria oeste do 9, a tres metros e meio do vao: longe o bastante para
	# nao dar para ver de quem sao.
	_olhos.position = Vector3(-3.4, EstufaBuilder.PE * 8.0 + 1.42, 0.4)
	add_child(_olhos)


func _montar_corrente() -> void:
	var sup: Dictionary = {}
	AtlasKit.tubo(sup, &"e", Vector3.ZERO, Vector3(0.0, 1.0, 0.0), 0.025,
		EstufaBuilder.C_MANGUEIRA, Color(0.2, 0.2, 0.2))
	_corrente = MeshInstance3D.new()
	_corrente.name = "Corrente"
	_corrente.mesh = PSXMesh.dados_para_mesh(sup[&"e"])
	_corrente.material_override = load(MATERIAL) as Material
	_corrente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_corrente)


func _instanciar(pai: Node3D, sup: Dictionary) -> void:
	var caminhos := {&"e": MATERIAL, &"luz": MATERIAL_LUZ, &"q": MATERIAL_QUADROS}
	for chave: StringName in sup:
		var mi := MeshInstance3D.new()
		mi.mesh = PSXMesh.dados_para_mesh(sup[chave])
		mi.material_override = load(caminhos[chave]) as Material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(mi)


func _forma(tam: Vector3, pos: Vector3) -> CollisionShape3D:
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tam
	f.shape = b
	f.position = pos
	return f


func _interativo(pos: Vector3, tam: Vector3) -> Interativo:
	var a := Interativo.new()
	a.position = pos
	a.add_child(_forma(tam, Vector3.ZERO))
	_cabine.add_child(a)
	return a


# --- viagem -------------------------------------------------------------------

func _atualizar_rotulos() -> void:
	_botao.rotulo = "Descer pro 1" if _no_topo else "Subir pro 10"
	_chapa.rotulo = "Apertar o %d" % _proximo_falso


## Se o jogador esta em pe dentro da cabine. O botao se alcanca do vao da
## porta, e sem esta conta a cabine subia sozinha e deixava o jogador no terreo
## sem jeito de chama-la de volta.
func dentro(quem: Node3D) -> bool:
	var local := _cabine.to_local(quem.global_position)
	return absf(local.x) < LADO * 0.5 and absf(local.z) < LADO * 0.5 \
		and local.y > -0.4 and local.y < 1.2


func no_topo() -> bool:
	return _no_topo


func andando() -> bool:
	return _andando


func cabine() -> AnimatableBody3D:
	return _cabine


func botao() -> Interativo:
	return _botao


func chapa() -> Interativo:
	return _chapa


func _ao_botao(quem: Node) -> void:
	var jogador := quem as Node3D
	if _andando or jogador == null:
		return
	if not dentro(jogador):
		Cinema.fala("Entra na cabine primeiro.")
		return
	_andando = true
	_botao.habilitado = false
	_chapa.habilitado = false
	var subir := not _no_topo
	AudioDirector.tocar(&"clique", _botao.global_position, -6.0)
	jogador.call("travar", true)
	# A grade fecha no lugar em que ela corre, e quem estiver em pe no vao seria
	# empurrado por uma colisao que nasce por dentro dele.
	var local := _cabine.to_local(jogador.global_position)
	if local.z < -0.45:
		local.z = -0.45
		jogador.global_position = _cabine.to_global(local)
	await _grade(false)
	_porta.set_deferred(&"disabled", false)
	_olho_antes = -1.0
	_motor.play()
	partiu.emit(10 if subir else 1)
	var alvo := topo if subir else 0.0
	var tempo := absf(alvo - _cabine.position.y) / VELOCIDADE + 1.2
	var t := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# O tranco de talha velha antes de pegar: cinco centimetros para o lado
	# errado. E o que diz "isto e uma corrente segurando voce".
	t.tween_property(_cabine, ^"position:y",
		_cabine.position.y + (-0.05 if subir else 0.05), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_cabine, ^"position:y", alvo, tempo) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_motor.stop()
	AudioDirector.tocar(&"porta_trava", _cabine.global_position + Vector3(0.0, 1.0, 0.0), -4.0)
	_no_topo = subir
	# Os olhos reabrem com a cabine longe: ninguem ve voltar.
	_olhos.visible = true
	_porta.set_deferred(&"disabled", true)
	await _grade(true)
	jogador.call("travar", false)
	_andando = false
	_botao.habilitado = true
	_chapa.habilitado = true
	_atualizar_rotulos()
	if subir:
		Cinema.fala("10  SO O JOTA E O HELMER")
	chegou.emit(10 if subir else 1)


## Os outros oito botoes. Um de cada vez, em ordem, para quem apertar todos ler
## a lista inteira pela boca do elevador.
func _ao_chapa(_quem: Node) -> void:
	if _andando:
		return
	var n := _proximo_falso
	_proximo_falso = 2 + (n - 1) % 8
	AudioDirector.tocar(&"clique", _chapa.global_position, -6.0)
	AudioDirector.tocar(&"bzum", _chapa.global_position, -12.0)
	_luz_recusa.visible = true
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(_luz_recusa):
			_luz_recusa.visible = false)
	Cinema.fala("%d  %s\nEsse andar ta interditado." % [n, ANDARES[n - 1]])
	_atualizar_rotulos()


func _grade(aberta: bool) -> void:
	AudioDirector.tocar(&"porta_desliza", _cabine.global_position + Vector3(0.0, 1.0, -0.8), -6.0)
	var t := create_tween().set_parallel(true)
	for k in _barras_porta.size():
		t.tween_property(_barras_porta[k], ^"position:x", _x_da_barra(k, aberta), 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await t.finished

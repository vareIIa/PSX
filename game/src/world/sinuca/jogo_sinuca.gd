## A mesa de sinuca do bar, jogavel: [E] para jogar bola 8 contra quem esta na
## mesa.
##
## A malha da mesa e do chunk (DesenhoSinuca, via KitBar); aqui mora o que se
## mexe: as dezesseis bolas (uma MultiMesh), o taco, a linha-guia, a camera da
## partida e o painel. Parado, o no nao processa nada — nem `_process`, nem
## `_physics_process`, nem entrada. A sessao de otimizacao mede o bar com a mesa
## ociosa, e ociosa ela custa uma chamada de desenho.
##
##     mouse             mira (Shift: fino); com o botao seguro, puxa o taco
##     soltar o botao    taca
##     botao direito     desiste da puxada
##     W A S D           efeito (ponto do taco na branca); X zera
##     roda              aproxima e afasta
##     C                 vista de cima (Tab e o inventario)
##     E / Esc           sai da mesa
##
## A fisica e FisicaSinuca (passo fixo, 600 Hz); as regras, RegrasSinuca; o
## adversario, CerebroSinuca.
class_name JogoSinuca
extends Interativo

enum Fase { OCIOSA, BOLA_NA_MAO, MIRANDO, TACANDO, ROLANDO, IA, FIM }

const MATERIAL_BOLA := "res://resources/materials/mat_bar_sinuca_bola.tres"
const DICA := "[mouse] mirar  [segure e puxe] força  [WASD] efeito  [C] de cima  [E] sair"
const DICA_MAO := "[mouse] mover a branca  [clique] soltar  [E] sair"
const DICA_FIM := "[clique] outra partida  [E] sair"

const SENSIBILIDADE := 0.0021
const FINO := 0.16
const PITCH := Vector2(deg_to_rad(7.0), deg_to_rad(64.0))
const DIST := Vector3(0.42, 0.85, 1.7)
## Velocidade do taco no fim da puxada. A quebra do adversario usa 5,6.
const V_MAX := 6.2
const V_MIN := 0.22
## Quanto o taco recua na puxada cheia, em metros.
const RECUO := 0.27
## Quanto o mouse precisa descer para a puxada cheia (pixels).
const PUXADA_PIXELS := 520.0
const ELEVACAO := deg_to_rad(4.0)
const HABILIDADE := 0.72
## As bolas somem a 22 m: de mais longe, cada uma e um pixel, e sao dezesseis.
const ALCANCE := 22.0
## Quanto tempo a bola leva para sumir na cacapa.
const QUEDA := 0.32

var semente := 0

var _fisica := FisicaSinuca.new()
var _regras := RegrasSinuca.new()
var _fase := Fase.OCIOSA
var _jogador: Node3D
var _antes: Transform3D
var _camera: Camera3D
var _cam_de_jogo: Camera3D
var _painel: PainelSinuca
var _mm: MultiMesh
var _taco: Node3D
var _guia: MeshInstance3D
var _guia_malha: ImmediateMesh
var _escondidos: Array[Node] = []
## O corpo de terceira pessoa estava visivel? Em primeira pessoa ele fica
## escondido, e devolver `true` na saida mostrava o boneco atravessando a camera.
var _corpo_antes := false

var _phi := 0.0
var _pitch := deg_to_rad(20.0)
var _dist := 0.85
var _efeito := Vector2.ZERO
var _puxada := 0.0
var _puxando := false
var _de_cima := false
var _ev_lidos := 0
var _caindo: Dictionary = {}
var _cam_pos := Vector3.ZERO
var _cam_olha := Vector3.ZERO
var _cam_pronta := false
var _rng := RandomNumberGenerator.new()
var _som_t: Dictionary = {}
var _tempo := 0.0

var _nome_adv := "ZÉ"
var _ia: Dictionary = {}
var _ia_t := 0.0
var _tacada: Dictionary = {}
var _tacando_t := 0.0
var _tacadas := 0
var _partidas := 0

## `--sinuca-demo`: os dois lados jogam sozinhos (bancada de captura).
var _auto := false
var _fotos := ""
var _fotos_tiradas: Dictionary = {}


## O que e igual em toda mesa: a esfera das bolas, as malhas do taco (material ->
## ArrayMesh, na ordem em que o taco as pendura) e o material da linha-guia.
## Montados na primeira mesa e compartilhados: ninguem escreve neles (a bola
## anda pela MultiMesh da mesa, o taco pelo no, a guia pela ImmediateMesh).
static var _esfera: SphereMesh
static var _malhas_taco: Array = []
static var _mat_guia: StandardMaterial3D


static func criar(prop: Dictionary) -> JogoSinuca:
	var j := JogoSinuca.new()
	j.name = "Sinuca"
	j.position = prop["pos"]
	j.rotation.y = float(prop.get("giro", 0.0))
	j.semente = int(prop.get("semente", 0))
	return j


func _ready() -> void:
	super()
	rotulo = "Jogar sinuca"
	add_to_group(&"sinuca")
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(MesaSinuca.FORA.x + 0.5, 1.3, MesaSinuca.FORA.y + 0.5)
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.75, 0.0)
	add_child(forma)
	acionado.connect(_pegar)
	_rng.seed = semente
	_fisica.arrumar(semente)
	_montar_bolas()
	_montar_taco()
	_montar_guia()
	_atualizar_bolas()
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	if OS.get_cmdline_user_args().has("--sinuca-demo"):
		_demo.call_deferred()


# --- montagem -----------------------------------------------------------------

func _montar_bolas() -> void:
	if _esfera == null:
		_esfera = SphereMesh.new()
		_esfera.radius = MesaSinuca.R
		_esfera.height = MesaSinuca.R * 2.0
		# 16 x 8: 224 triangulos por bola. De perto, com a luz por pixel, a
		# silhueta ainda le redonda; a 18 x 10 eram 360, e a mesa inteira saia
		# 5.800.
		_esfera.radial_segments = 16
		_esfera.rings = 8
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = _esfera
	_mm.instance_count = FisicaSinuca.BOLAS
	for i in FisicaSinuca.BOLAS:
		# A celula da bola no atlas (4 x 4), como o rotulo do mercado.
		_mm.set_instance_custom_data(i, Color(float(i % 4) * 0.25, float(i / 4) * 0.25,
			0.25, 0.25))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Bolas"
	mi.multimesh = _mm
	mi.material_override = load(MATERIAL_BOLA) as Material
	mi.visibility_range_end = ALCANCE
	add_child(mi)


## O taco: madeira clara afinando para a ponta, anel branco, sola azul de giz e o
## punho escuro. A ponta fica na origem e o taco corre para +Z.
func _montar_taco() -> void:
	_taco = Node3D.new()
	_taco.name = "Taco"
	_taco.visible = false
	add_child(_taco)
	if _malhas_taco.is_empty():
		var s := {}
		var comp := 1.45
		Peca.tubo(s, &"tabua", PackedVector3Array([Vector3(0, 0, 0.03), Vector3(0, 0, comp * 0.62)]),
			0.008, 8, Color("d8b67c"), false, PackedFloat32Array([0.0062, 0.0105]))
		Peca.tubo(s, &"tabua", PackedVector3Array([Vector3(0, 0, comp * 0.62), Vector3(0, 0, comp)]),
			0.013, 8, Color("3a2016"), true, PackedFloat32Array([0.0105, 0.0145]))
		Peca.tubo(s, &"mercado_louca", PackedVector3Array([Vector3(0, 0, 0.008), Vector3(0, 0, 0.03)]),
			0.0062, 8, Color("f2efe6"), false)
		Peca.tubo(s, &"metal_pintado", PackedVector3Array([Vector3(0, 0, 0.0), Vector3(0, 0, 0.008)]),
			0.006, 8, Color("2f6fb8"), true)
		for mat: StringName in s:
			var cores: PackedColorArray = s[mat]["c"]
			for k in cores.size():
				cores[k] = cores[k].srgb_to_linear()
			s[mat]["c"] = cores
			_malhas_taco.append([mat, PSXMesh.dados_para_mesh(s[mat])])
	for par: Array in _malhas_taco:
		var mi := MeshInstance3D.new()
		mi.mesh = par[1]
		mi.material_override = load("res://resources/materials/mat_%s.tres" % par[0]) as Material
		_taco.add_child(mi)


func _montar_guia() -> void:
	_guia_malha = ImmediateMesh.new()
	_guia = MeshInstance3D.new()
	_guia.name = "Guia"
	_guia.mesh = _guia_malha
	if _mat_guia == null:
		_mat_guia = StandardMaterial3D.new()
		_mat_guia.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_guia.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_guia.vertex_color_use_as_albedo = true
		_mat_guia.vertex_color_is_srgb = true
		_mat_guia.albedo_color = Color(1, 1, 1, 1)
	_guia.material_override = _mat_guia
	_guia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_guia)


# --- pegar e largar -------------------------------------------------------------

func _pegar(quem: Node) -> void:
	var j := quem as Node3D
	if _fase != Fase.OCIOSA or j == null or not j.has_method("travar"):
		return
	if j.has_method("dirigindo") and bool(j.call("dirigindo")):
		return
	_jogador = j
	_antes = j.global_transform
	j.call("travar", true)
	_esconder_corpo(j)
	if j.has_method("ocupar"):
		j.call("ocupar", DICA, Callable(self, "_largar"))
	habilitado = false
	_nome_adv = _achar_adversario()
	_abrir()
	_nova_partida()


func _abrir() -> void:
	_esconder_hud(true)
	_cam_de_jogo = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "CameraDaSinuca"
	_camera.top_level = true
	_camera.fov = 52.0
	_camera.near = 0.03
	if _cam_de_jogo != null:
		_camera.far = _cam_de_jogo.far
		# Mesma exposicao do olho do jogador: camera nova sem os atributos dele
		# saia com outra luz (memoria "viewport novo nao herda a exposicao").
		_camera.attributes = _cam_de_jogo.attributes
		_camera.environment = _cam_de_jogo.environment
	add_child(_camera)
	_camera.current = true
	_cam_pronta = false
	_painel = PainelSinuca.new()
	_painel.nomes = ["VOCÊ" if not _auto else "LADO A", _nome_adv]
	add_child(_painel)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process(true)
	set_physics_process(true)
	set_process_input(true)
	AudioDirector.tocar_ui(&"clique", -10.0)


func _largar() -> void:
	if _fase == Fase.OCIOSA:
		return
	_fase = Fase.OCIOSA
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	_taco.visible = false
	_guia_malha.clear_surfaces()
	if _painel != null:
		_painel.queue_free()
		_painel = null
	if _camera != null:
		_camera.queue_free()
		_camera = null
	if _cam_de_jogo != null and is_instance_valid(_cam_de_jogo):
		_cam_de_jogo.current = true
	_esconder_hud(false)
	var j := _jogador
	_jogador = null
	if j != null and is_instance_valid(j):
		j.global_transform = _antes
		if j.has_method("mostrar_corpo"):
			j.call("mostrar_corpo", _corpo_antes)
		j.call("travar", false)
		if j.has_method("desocupar"):
			j.call("desocupar")
	habilitado = true
	# As bolas ficam onde pararam: a mesa largada no meio do jogo continua assim.
	_fisica.ate_parar(8.0)
	_caindo.clear()
	_atualizar_bolas()


func _exit_tree() -> void:
	# O chunk descarregando com alguem jogando: devolve o jogador antes de sumir.
	_largar()


func _esconder_corpo(j: Node3D) -> void:
	var corpo := j.get_node_or_null(^"Corpo") as Node3D
	_corpo_antes = corpo != null and corpo.visible
	if j.has_method("mostrar_corpo"):
		j.call("mostrar_corpo", false)


func _achar_adversario() -> String:
	var melhor: Node3D = null
	var dist := 4.5
	for c: Node in get_tree().get_nodes_in_group(&"convidado"):
		var n := c as Node3D
		if n == null:
			continue
		var d := n.global_position.distance_to(global_position)
		if d < dist:
			dist = d
			melhor = n
	if melhor != null and "ficha" in melhor:
		var ficha: Dictionary = melhor.get("ficha")
		var nome := String(ficha.get("apelido", ""))
		if nome.is_empty():
			nome = String(ficha.get("nome", "")).get_slice(" ", 0)
		if not nome.is_empty():
			return nome.to_upper()
	return "ZÉ"


func _esconder_hud(esconder: bool) -> void:
	if esconder:
		_escondidos.clear()
		for no: Node in get_tree().get_nodes_in_group(&"hud"):
			var item := no as CanvasItem
			if item != null and item.visible:
				item.visible = false
				_escondidos.append(no)
				continue
			var camada := no as CanvasLayer
			if camada != null and camada.visible:
				camada.visible = false
				_escondidos.append(no)
		return
	for no: Node in _escondidos:
		if not is_instance_valid(no):
			continue
		if no is CanvasItem:
			(no as CanvasItem).visible = true
		elif no is CanvasLayer:
			(no as CanvasLayer).visible = true
	_escondidos.clear()


# --- partida --------------------------------------------------------------------

func _nova_partida() -> void:
	_partidas += 1
	_fisica.arrumar(semente + _partidas * 7919)
	_regras = RegrasSinuca.new()
	_caindo.clear()
	_tacadas = 0
	_efeito = Vector2.ZERO
	_atualizar_bolas()
	_painel.grupos = _regras.grupo
	_painel.vez = 0
	_painel.na_mesa.fill(true)
	_painel.recado("SINUCA · BOLA 8", "%s quebra" % ("Você" if not _auto else "O lado A"),
		HudTema.TEXTO, 3.0)
	_comecar_vez()


## Quem esta na vez comeca: com a branca na mao, mirando, ou pensando (IA).
func _comecar_vez() -> void:
	_puxada = 0.0
	_puxando = false
	_painel.vez = _regras.vez
	_painel.grupos = _regras.grupo
	if _regras.fim:
		_fase = Fase.FIM
		_taco.visible = false
		_painel.dica = DICA_FIM
		return
	var humano := _regras.vez == 0 and not _auto
	if not _fisica.na_mesa(0):
		_fisica.por(0, _perto_livre(Vector2(MesaSinuca.linha_de_cabeceira(), 0.0)))
	if humano:
		_phi = _mira_inicial()
		if _regras.bola_na_mao:
			_fase = Fase.BOLA_NA_MAO
			_painel.dica = DICA_MAO
		else:
			_fase = Fase.MIRANDO
			_painel.dica = DICA
	else:
		_fase = Fase.IA
		_ia = {}
		_ia_t = 0.0
		_painel.dica = "[E] sair"
	_atualizar_bolas()


## A mira comeca na bola legal mais perto: ninguem gosta de girar a camera meia
## mesa antes de cada tacada.
func _mira_inicial() -> float:
	var melhor := INF
	var phi := 0.0
	for n in _regras.alvos(_fisica):
		var d := _fisica.r[n].distance_to(_fisica.r[0])
		if d < melhor:
			melhor = d
			phi = (_fisica.r[n] - _fisica.r[0]).angle()
	return phi


func _perto_livre(p: Vector2) -> Vector2:
	for k in 60:
		var q := p + Vector2(0.03 * float(k % 10) * (1.0 if k % 2 == 0 else -1.0),
			0.03 * float(k / 10) * (1.0 if k % 4 < 2 else -1.0))
		if _fisica.cabe(q):
			return q
	return p


# --- entrada --------------------------------------------------------------------

func _input(evento: InputEvent) -> void:
	if _fase == Fase.OCIOSA:
		return
	if evento.is_action_pressed("pausa"):
		_largar()
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey and evento.is_pressed() and not evento.is_echo():
		var k := (evento as InputEventKey).physical_keycode
		if k == KEY_C:
			_de_cima = not _de_cima
		elif k == KEY_X:
			_efeito = Vector2.ZERO
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if _auto:
		return
	match _fase:
		Fase.BOLA_NA_MAO:
			_entrada_mao(evento)
		Fase.MIRANDO:
			_entrada_mira(evento)
		Fase.FIM:
			if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed \
					and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_nova_partida()
				get_viewport().set_input_as_handled()


func _entrada_mira(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		var rel := (evento as InputEventMouseMotion).relative
		if _puxando:
			_puxada = clampf(_puxada + rel.y / PUXADA_PIXELS, 0.0, 1.0)
		else:
			var s := SENSIBILIDADE * (FINO if Input.is_key_pressed(KEY_SHIFT) else 1.0)
			_phi = wrapf(_phi - rel.x * s, -PI, PI)
			_pitch = clampf(_pitch + rel.y * SENSIBILIDADE * 0.7, PITCH.x, PITCH.y)
		get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_puxando = true
					_puxada = 0.0
				elif _puxando:
					_puxando = false
					if _puxada > 0.03:
						_tacar(lerpf(V_MIN, V_MAX, pow(_puxada, 1.3)), _phi, ELEVACAO,
							_efeito.x, _efeito.y)
					else:
						_puxada = 0.0
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					_puxando = false
					_puxada = 0.0
			MOUSE_BUTTON_WHEEL_UP:
				_dist = maxf(DIST.x, _dist / 1.12)
			MOUSE_BUTTON_WHEEL_DOWN:
				_dist = minf(DIST.z, _dist * 1.12)
			_:
				return
		get_viewport().set_input_as_handled()


func _entrada_mao(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		var rel := (evento as InputEventMouseMotion).relative
		# Vista de cima: direita da tela e +x da mesa, cima da tela e +y.
		var p := _fisica.r[0] + Vector2(rel.x, -rel.y) * 0.0022
		var hx := MesaSinuca.COMP * 0.5 - MesaSinuca.R
		var hy := MesaSinuca.LARG * 0.5 - MesaSinuca.R
		if _regras.so_cabeceira:
			p.x = clampf(p.x, -hx, MesaSinuca.linha_de_cabeceira())
		p = Vector2(clampf(p.x, -hx, hx), clampf(p.y, -hy, hy))
		_fisica.r[0] = p
		_atualizar_bolas()
		get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed \
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _fisica.cabe(_fisica.r[0]):
			_fase = Fase.MIRANDO
			_painel.dica = DICA
			_phi = _mira_inicial()
			AudioDirector.tocar(&"sinuca_tabela", _mundo(_fisica.r[0]), -20.0, 1.4)
		else:
			_painel.recado("NÃO CABE AQUI", "encostada em outra bola", HudTema.ALERTA, 1.4)
		get_viewport().set_input_as_handled()


# --- quadro ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_tempo += delta
	if _fase == Fase.OCIOSA:
		return
	if _fase == Fase.MIRANDO and not _auto:
		var mexe := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
		if mexe != Vector2.ZERO:
			_efeito += mexe * delta * 0.9
			if _efeito.length() > FisicaSinuca.EFEITO_MAX:
				_efeito = _efeito.normalized() * FisicaSinuca.EFEITO_MAX
	if _fase == Fase.IA:
		_passo_ia(delta)
	if _fase == Fase.TACANDO:
		_passo_tacada(delta)
	_posicionar_taco()
	_desenhar_guia()
	_seguir_camera(delta)
	_painel.forca = _puxada
	_painel.mostrar_forca = _fase == Fase.MIRANDO or _fase == Fase.TACANDO \
		or (_fase == Fase.IA and _ia.has("tacada"))
	_painel.efeito = _efeito
	_painel.mostrar_efeito = _fase == Fase.MIRANDO or _fase == Fase.TACANDO
	for i in FisicaSinuca.BOLAS:
		_painel.na_mesa[i] = _fisica.na_mesa(i)
	_fotografar_se_pedido()


func _physics_process(delta: float) -> void:
	if _fase != Fase.ROLANDO:
		return
	_fisica.avancar(delta)
	_ouvir_eventos()
	_animar_quedas(delta)
	_atualizar_bolas()
	if not _fisica.em_movimento() and _caindo.is_empty():
		_fim_da_tacada()


# --- tacada ---------------------------------------------------------------------

## O taco vai para a frente; a bola so sai quando a ponta chega nela.
func _tacar(v0: float, phi: float, theta: float, a: float, b: float) -> void:
	_tacada = {"v0": v0, "phi": phi, "theta": theta, "a": a, "b": b,
		"de": maxf(_puxada, 0.05)}
	_phi = phi
	_tacando_t = 0.0
	_fase = Fase.TACANDO


func _passo_tacada(delta: float) -> void:
	_tacando_t += delta
	# A estocada leva de 60 a 120 ms: mais forte, mais rapida.
	var dur := lerpf(0.13, 0.06, clampf(float(_tacada["v0"]) / V_MAX, 0.0, 1.0))
	var t := clampf(_tacando_t / dur, 0.0, 1.0)
	_puxada = lerpf(float(_tacada["de"]), -0.02, t * t)
	if t >= 1.0:
		_fisica.tacar(_tacada["v0"], _tacada["phi"], _tacada["theta"], _tacada["a"],
			_tacada["b"])
		_ev_lidos = 0
		_tacadas += 1
		_fase = Fase.ROLANDO
		_puxada = 0.0
		_efeito = Vector2.ZERO
		_painel.dica = ""
		print("[sinuca] tacada=%d vez=%d v0=%.2f phi=%.3f" % [_tacadas, _regras.vez,
			float(_tacada["v0"]), float(_tacada["phi"])])


func _fim_da_tacada() -> void:
	var res := _regras.avaliar(_fisica)
	if res["recolocar_8"]:
		_fisica.por(8, _perto_livre(MesaSinuca.marca_do_pe()))
	var quem := _nome_de(int(res["tacou"]))
	var proximo := _nome_de(_regras.vez)
	print("[sinuca] fim_tacada=%d caidas=%s falta=%s motivo=%s vez=%d" % [_tacadas,
		str(res["caidas"]), str(res["falta"]), String(res["motivo"]), _regras.vez])
	if res["fim"]:
		var venceu := int(res["vencedor"])
		var titulo := ("VOCÊ GANHOU" if venceu == 0 else "%s GANHOU" % _nome_adv) \
			if not _auto else "%s GANHOU" % _nome_de(venceu)
		_painel.recado(titulo, "a 8 caiu" if not res["falta"] else "a 8 caiu com falta",
			HudTema.OK if venceu == 0 or _auto else HudTema.PERIGO, 6.0)
		print("[sinuca] fim_de_jogo vencedor=%d tacadas=%d" % [venceu, _tacadas])
	elif res["falta"]:
		_painel.recado("FALTA", "%s — bola na mão para %s" % [String(res["motivo"]),
			proximo.to_lower() if proximo == "VOCÊ" else proximo], HudTema.ALERTA, 3.0)
	elif res["grupo_definido"]:
		var g := _regras.grupo[int(res["tacou"])]
		_painel.recado("%s %s" % [quem, "FICA COM AS " + RegrasSinuca.nome_do_grupo(g)],
			"", HudTema.TEXTO, 2.6)
	elif not res["continua"]:
		_painel.recado("SUA VEZ" if _regras.vez == 0 and not _auto else "VEZ DE %s" % proximo,
			"", HudTema.TEXTO, 1.8)
	_comecar_vez()
	if _auto and _regras.fim and OS.get_cmdline_user_args().has("--sinuca-sair"):
		await get_tree().create_timer(2.5).timeout
		_fotografar("fim")
		get_tree().quit(0)


func _nome_de(lado: int) -> String:
	if _auto:
		return "LADO A" if lado == 0 else _nome_adv
	return "VOCÊ" if lado == 0 else _nome_adv


# --- adversario -----------------------------------------------------------------

## O adversario: pensa, poe a branca se ela esta na mao, mira devagar, puxa e taca.
func _passo_ia(delta: float) -> void:
	_ia_t += delta
	if not _ia.has("tacada"):
		if _ia_t < 0.7:
			return
		if _regras.bola_na_mao:
			var p := CerebroSinuca.bola_na_mao(_fisica, _regras.alvos(_fisica), _regras.so_cabeceira)
			_fisica.por(0, p)
			_atualizar_bolas()
		var t := CerebroSinuca.escolher(_fisica, _regras.alvos(_fisica), HABILIDADE, _rng,
			_regras.quebra)
		_ia = {"tacada": t, "phi0": _phi, "t0": _ia_t}
		return
	var t: Dictionary = _ia["tacada"]
	var desde := _ia_t - float(_ia["t0"])
	# Um segundo girando o taco ate a linha, meio segundo puxando, e vai.
	var giro := clampf(desde / 1.0, 0.0, 1.0)
	_phi = lerp_angle(float(_ia["phi0"]), float(t["phi"]), giro * giro * (3.0 - 2.0 * giro))
	_efeito = Vector2(float(t["a"]), float(t["b"])) * clampf(desde - 0.8, 0.0, 1.0)
	var alvo_puxada := clampf(float(t["v0"]) / V_MAX, 0.08, 1.0)
	_puxada = alvo_puxada * clampf((desde - 1.1) / 0.55, 0.0, 1.0)
	if desde > 1.9:
		_ia = {}
		_tacar(float(t["v0"]), float(t["phi"]), float(t["theta"]), float(t["a"]), float(t["b"]))


# --- desenho --------------------------------------------------------------------

func _atualizar_bolas() -> void:
	for i in FisicaSinuca.BOLAS:
		if _caindo.has(i):
			continue
		if not _fisica.na_mesa(i):
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		_mm.set_instance_transform(i, Transform3D(Basis(_fisica.orientacao[i]),
			MesaSinuca.no_pano(_fisica.r[i])))


## A bola que caiu escorrega para o centro da cacapa e desce, e so entao some.
func _animar_quedas(delta: float) -> void:
	for i: int in _caindo.keys():
		var q: Dictionary = _caindo[i]
		q["t"] = float(q["t"]) + delta
		var t := clampf(float(q["t"]) / QUEDA, 0.0, 1.0)
		var de: Vector3 = q["de"]
		var para: Vector3 = q["para"]
		var p := de.lerp(para, minf(1.0, t * 1.6)) + Vector3(0.0, -0.11 * t * t, 0.0)
		if t >= 1.0:
			_caindo.erase(i)
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		else:
			_mm.set_instance_transform(i, Transform3D(Basis(_fisica.orientacao[i]), p))


func _posicionar_taco() -> void:
	var com_taco := _fase == Fase.MIRANDO or _fase == Fase.TACANDO \
		or (_fase == Fase.IA and _ia.has("tacada"))
	_taco.visible = com_taco and _fisica.na_mesa(0)
	if not _taco.visible:
		return
	var bola := MesaSinuca.no_pano(_fisica.r[0])
	var horiz := Vector3(cos(_phi), 0.0, -sin(_phi))
	var d := (horiz * cos(ELEVACAO) - Vector3.UP * sin(ELEVACAO)).normalized()
	var lado := d.cross(Vector3.UP).normalized()
	var cima := lado.cross(d).normalized()
	var r := MesaSinuca.R
	var ab := _efeito * r
	var contato := bola + lado * ab.x + cima * ab.y \
		- d * sqrt(maxf(0.0, r * r - ab.length_squared()))
	# Respira um pouco na mira: o taco parado de todo le como foto.
	var respira := 0.004 * sin(_tempo * 2.2) if _fase == Fase.MIRANDO and not _puxando else 0.0
	var ponta := contato - d * (0.012 + _puxada * RECUO + respira)
	var z := -d
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	_taco.transform = Transform3D(Basis(x, y, z), ponta)


## Linha-guia: da branca ate o primeiro contato, a bola fantasma, para onde a
## bola batida vai e para onde a branca desvia. So na mira de quem joga.
func _desenhar_guia() -> void:
	_guia_malha.clear_surfaces()
	var mostra := (_fase == Fase.MIRANDO and not _auto) \
		or (_auto and _fase == Fase.IA and _regras.vez == 0 and _ia.has("tacada"))
	if not mostra or not _fisica.na_mesa(0):
		return
	var o := _fisica.r[0]
	var d := Vector2(cos(_phi), sin(_phi))
	var hit := _fisica.raio(o, d, 0)
	var branco := Color(1, 1, 1, 0.55)
	_guia_malha.surface_begin(Mesh.PRIMITIVE_LINES)
	var tipo := StringName(hit["tipo"])
	var fim := o + d * (1.2 if tipo == &"nada" else float(hit["t"]))
	_linha(o + d * MesaSinuca.R, fim, branco)
	if tipo == &"bola":
		var j := int(hit["bola"])
		var fantasma: Vector2 = hit["fantasma"]
		_circulo(fantasma, MesaSinuca.R, branco)
		var n := (_fisica.r[j] - fantasma).normalized()
		var corte := clampf(d.dot(n), 0.0, 1.0)
		var legal := _regras.alvos(_fisica).has(j)
		var cor_alvo := Color(1.0, 0.86, 0.45, 0.7) if legal else Color(1.0, 0.35, 0.3, 0.7)
		_linha(_fisica.r[j] + n * MesaSinuca.R, _fisica.r[j] + n * (MesaSinuca.R + 0.38 * corte + 0.04),
			cor_alvo)
		var tang := d - n * d.dot(n)
		if tang.length() > 0.02:
			_linha(fantasma, fantasma + tang.normalized() * 0.2 * sqrt(1.0 - corte * corte),
				Color(0.65, 0.85, 1.0, 0.5))
	elif tipo == &"tabela":
		var nrm: Vector2 = hit["normal"]
		var refl := d - 2.0 * d.dot(nrm) * nrm
		_linha(fim, fim + refl * 0.22, Color(1, 1, 1, 0.3))
	_guia_malha.surface_end()


func _linha(a: Vector2, b: Vector2, cor: Color) -> void:
	var y := MesaSinuca.ALTURA_PANO + 0.004
	_guia_malha.surface_set_color(cor)
	_guia_malha.surface_add_vertex(Vector3(a.x, y, -a.y))
	_guia_malha.surface_set_color(cor)
	_guia_malha.surface_add_vertex(Vector3(b.x, y, -b.y))


func _circulo(c: Vector2, raio: float, cor: Color) -> void:
	for k in 20:
		var a0 := TAU * float(k) / 20.0
		var a1 := TAU * float(k + 1) / 20.0
		_linha(c + Vector2(cos(a0), sin(a0)) * raio, c + Vector2(cos(a1), sin(a1)) * raio, cor)


# --- camera ---------------------------------------------------------------------

func _seguir_camera(delta: float) -> void:
	if _camera == null:
		return
	var pos: Vector3
	var olha: Vector3
	var cima := Vector3.UP
	var perto := 0.03
	var bola := MesaSinuca.no_pano(_fisica.r[0])
	var horiz := Vector3(cos(_phi), 0.0, -sin(_phi))
	var mirando := _fase == Fase.MIRANDO or _fase == Fase.TACANDO \
		or (_fase == Fase.IA and _ia.has("tacada"))
	# A mira do adversario se ve de mais longe, como na transmissao: quem joga
	# assiste a linha dele sem o taco na cara.
	var dist := _dist if (_regras.vez == 0 or _auto) else 1.25
	var pitch := _pitch if (_regras.vez == 0 or _auto) else deg_to_rad(26.0)
	if _de_cima or _fase == Fase.BOLA_NA_MAO:
		# Alta o bastante para a mesa inteira caber no quadro de 16:9, e abaixo
		# do forro (3 m).
		pos = Vector3(0.0, MesaSinuca.ALTURA_PANO + 1.95, 0.001)
		olha = Vector3(0.0, MesaSinuca.ALTURA_PANO, 0.0)
		cima = Vector3(0.0, 0.0, -1.0)
		# A luminaria fica entre a camera e o pano: o corte perto a tira.
		perto = 1.1
	elif mirando:
		pos = bola - horiz * dist * cos(pitch) + Vector3.UP * (dist * sin(pitch) + 0.02)
		olha = bola + horiz * 0.4 - Vector3.UP * 0.02
	else:
		# Vista da jogada: do lado de quem tacou, com a mesa inteira. ABAIXO das
		# cupulas (0,95 m acima do pano): mais alto, a luminaria tapava o topo
		# do quadro.
		var centro := Vector3(0.0, MesaSinuca.ALTURA_PANO, 0.0)
		pos = centro - horiz * 1.85 + Vector3.UP * 0.82
		olha = centro + horiz * 0.1 - Vector3.UP * 0.05
	var k := 1.0 - exp(-(14.0 if mirando else 5.0) * delta)
	if not _cam_pronta:
		k = 1.0
		_cam_pronta = true
	_cam_pos = _cam_pos.lerp(pos, k)
	_cam_olha = _cam_olha.lerp(olha, k)
	_camera.near = perto
	var g := global_transform
	var p := g * _cam_pos
	var alvo := g * _cam_olha
	var up := (g.basis * cima).normalized()
	if (alvo - p).normalized().cross(up).length() < 0.01:
		up = (g.basis * Vector3(0.0, 0.0, -1.0)).normalized()
	_camera.look_at_from_position(p, alvo, up)


# --- som ------------------------------------------------------------------------

func _mundo(p: Vector2) -> Vector3:
	return global_transform * MesaSinuca.no_pano(p)


func _ouvir_eventos() -> void:
	var ev := _fisica.eventos
	while _ev_lidos < ev.size():
		var e: Dictionary = ev[_ev_lidos]
		_ev_lidos += 1
		var forca := absf(float(e.get("forca", 0.0)))
		match StringName(e["tipo"]):
			&"taco":
				_som(&"sinuca_taco", e["pos"], lerpf(-18.0, -2.0, clampf(forca / 8.0, 0.0, 1.0)))
			&"bola":
				_som(&"sinuca_bola", e["pos"], lerpf(-26.0, -3.0, clampf(forca / 5.0, 0.0, 1.0)))
			&"tabela":
				_som(&"sinuca_tabela", e["pos"], lerpf(-26.0, -6.0, clampf(forca / 4.0, 0.0, 1.0)))
			&"cacapa":
				var i := int(e["a"])
				_som(&"sinuca_cacapa", e["pos"], -4.0)
				var c: Vector2 = e["pos"]
				_caindo[i] = {"t": 0.0, "de": MesaSinuca.no_pano(_fisica.r[i]),
					"para": Vector3(c.x, MesaSinuca.altura_bola() - 0.02, -c.y)}


## Um som por tipo a cada 30 ms, no maximo: a quebra tem dezenas de choques num
## quadro, e cada um tomaria uma voz da piscina do AudioDirector.
func _som(nome: StringName, onde: Vector2, volume: float) -> void:
	var agora := Time.get_ticks_msec()
	if agora - int(_som_t.get(nome, -1000)) < 30:
		return
	_som_t[nome] = agora
	AudioDirector.tocar(nome, _mundo(onde), volume, _rng.randf_range(0.94, 1.06))


# --- demo e fotos ---------------------------------------------------------------

## `--sinuca-demo`: a mesa mais perto do jogador comeca sozinha, os dois lados na
## IA. `--sinuca-fotos=DIR` grava os momentos; `--sinuca-sair` fecha no fim.
func _demo() -> void:
	await get_tree().create_timer(2.5).timeout
	var j := get_tree().get_first_node_in_group(&"player") as Node3D
	if j == null or j.global_position.distance_to(global_position) > 14.0:
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sinuca-fotos="):
			_fotos = arg.trim_prefix("--sinuca-fotos=")
			DirAccess.make_dir_recursive_absolute(_fotos)
	if OS.get_cmdline_user_args().has("--sinuca-humano"):
		await _jogar_como_gente(j)
		return
	_auto = true
	_jogador = j
	_antes = j.global_transform
	j.call("travar", true)
	_esconder_corpo(j)
	habilitado = false
	_nome_adv = _achar_adversario()
	_abrir()
	_nova_partida()
	print("[sinuca] demo mesa=%s adversario=%s" % [str(global_position), _nome_adv])


## `--sinuca-humano`: o caminho de quem joga, pela ENTRADA e nao pelos metodos.
## Aciona a mesa como o [E] aciona, solta a branca com um clique, gira a mira
## com o mouse, segura o botao, puxa e solta. Se o input quebrar, a tacada nao
## acontece e o teste acusa (memoria "teste que chama o metodo nao aperta a
## tecla").
func _jogar_como_gente(j: Node3D) -> void:
	interagir(j)
	await get_tree().create_timer(1.0).timeout
	print("[sinuca] humano fase=%d (bola na mao=%d)" % [_fase, Fase.BOLA_NA_MAO])
	_mouse(Vector2(40.0, -20.0))
	await get_tree().create_timer(0.3).timeout
	_clique(true)
	_clique(false)
	await get_tree().create_timer(0.5).timeout
	print("[sinuca] humano fase=%d (mirando=%d)" % [_fase, Fase.MIRANDO])
	_fotografar("humano_mira")
	for k in 6:
		_mouse(Vector2(-8.0, 0.0))
		await get_tree().process_frame
	_clique(true)
	for k in 12:
		_mouse(Vector2(0.0, 35.0))
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	print("[sinuca] humano puxada=%.2f" % _puxada)
	_fotografar("humano_puxada")
	_clique(false)
	await get_tree().create_timer(0.5).timeout
	print("[sinuca] humano tacou=%d fase=%d" % [_tacadas, _fase])
	while _fase == Fase.ROLANDO or _fase == Fase.TACANDO:
		await get_tree().process_frame
	print("[sinuca] humano depois fase=%d vez=%d" % [_fase, _regras.vez])
	if OS.get_cmdline_user_args().has("--sinuca-sair"):
		var e := InputEventAction.new()
		e.action = &"pausa"
		e.pressed = true
		Input.parse_input_event(e)
		await get_tree().create_timer(0.5).timeout
		print("[sinuca] humano saiu fase=%d" % _fase)
		get_tree().quit(0)


func _mouse(rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	Input.parse_input_event(e)


func _clique(apertado: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = apertado
	Input.parse_input_event(e)


func _fotografar_se_pedido() -> void:
	if _fotos.is_empty():
		return
	if _fase == Fase.IA and _ia.has("tacada") and _tacadas == 0 \
			and _ia_t - float(_ia["t0"]) > 1.4:
		_fotografar("mira")
	if _fase == Fase.ROLANDO and _tacadas == 1 and _fisica.tempo > 1.0:
		_fotografar("quebra")
	if _fase == Fase.IA and _ia.has("tacada") and _tacadas == 3 \
			and _ia_t - float(_ia["t0"]) > 1.5:
		_de_cima = true
		if _ia_t - float(_ia["t0"]) > 1.8:
			_fotografar("de_cima")
	elif _tacadas >= 4 and _de_cima:
		_de_cima = false
	if _fase == Fase.IA and _ia.has("tacada") and _tacadas == 5 \
			and _ia_t - float(_ia["t0"]) > 1.5:
		_fotografar("mira_meio")


func _fotografar(nome: String) -> void:
	if _fotos.is_empty() or _fotos_tiradas.has(nome):
		return
	_fotos_tiradas[nome] = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_fotos.path_join(nome + ".png"))
	# O custo do quadro fotografado, para quem mede o bar (sessao de otimizacao).
	print("[sinuca] foto=%s chamadas=%d primitivas=%d fps=%d" % [nome,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		Engine.get_frames_per_second()])

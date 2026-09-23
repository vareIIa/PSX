## Vitrine de carrocerias. Ferramenta de olho, nao conteudo.
##
## Monta os cinco modelos da Carroceria lado a lado, sem fisica, sem IA e sem
## nevoa, com camera fixa. Existe porque defeito de lataria — face invertida,
## vidro flutuando, roda fora do arco — nao aparece no transito: o carro passa a
## trinta metros dentro da nevoa e o olho perdoa. Aqui ele nao perdoa.
##
##     godot --path game res://scenes/test/carros_teste.tscn -- \
##         --shot=captures/carros.png --shot-frame=8 --shot-quit
##
## O angulo padrao e tres quartos dianteiro, que e o unico que mostra frente,
## lateral e teto de uma vez. `--vista=tras` e `--vista=cima` trocam a camera
## sem mexer no arquivo.
extends Node3D

const ESPACO := 6.0
const MODELOS: Array[Carroceria.Modelo] = [
	Carroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,
	Carroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI,
	Carroceria.Modelo.MAREA, Carroceria.Modelo.FUSCA,
]

@onready var _geo: Node3D = $Geometria
@onready var _cam: Camera3D = $Camera

## Orbita do olho humano. A vitrine existe para achar defeito de lataria, e uma
## camera fixa mostra um angulo so: face invertida, vidro flutuando e roda fora
## do arco costumam aparecer justo no angulo que a foto nao pegou. Arrastar com
## o botao esquerdo gira, a roda do mouse aproxima.
##
## So vale em perspectiva. Em `--orto` a camera e um instrumento de medida: se o
## usuario puder gira-la, a silhueta medida deixa de ser comparavel com a print
## de referencia, que e a unica coisa que aquele modo serve para fazer.
var _orbita := false
var _giro := Vector2.ZERO
var _raio := 0.0
var _alvo := Vector3(0.0, 0.7, 0.0)
var _foco := 0
var _com_gente := true
var _com_interior := true
var _de_longe := false
var _amassados: Array = []
var _com_trinca := false


func _unhandled_input(evento: InputEvent) -> void:
	if not _orbita:
		return
	# Setas andam a mira de carro em carro. Sem isto a orbita gira em torno do
	# meio da fila e o ultimo modelo — que e sempre o carro novo — fica a
	# dezoito metros do centro, longe demais para se olhar de perto.
	if evento is InputEventKey and (evento as InputEventKey).pressed:
		var passo := 0
		match (evento as InputEventKey).keycode:
			KEY_RIGHT, KEY_D:
				passo = 1
			KEY_LEFT, KEY_A:
				passo = -1
			_:
				passo = 0
		if passo != 0 and _geo.get_child_count() > 0:
			_foco = clampi(_foco + passo, 0, _geo.get_child_count() - 1)
			var alvo: Node3D = _geo.get_child(_foco)
			_alvo = alvo.position + Vector3(0.0, 0.7, 0.0)
			_raio = minf(_raio, 7.0)
			_recolocar()
			return
	if evento is InputEventMouseButton:
		var b := evento as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_raio = maxf(2.0, _raio * 0.9)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_raio = minf(60.0, _raio * 1.1)
		else:
			return
		_recolocar()
	elif evento is InputEventMouseMotion:
		var m := evento as InputEventMouseMotion
		if not (m.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return
		_giro.x -= m.relative.x * 0.006
		# Trava perto do polo: passar dele inverte o mundo de cabeca para baixo.
		_giro.y = clampf(_giro.y + m.relative.y * 0.006, -1.3, 1.3)
		_recolocar()


func _recolocar() -> void:
	_cam.position = _alvo + Vector3(
		sin(_giro.x) * cos(_giro.y), sin(_giro.y), cos(_giro.x) * cos(_giro.y)
	) * _raio
	_cam.look_at(_alvo, Vector3.UP)


func _ready() -> void:
	var vista := "frente"
	## Projecao paralela. Existe para comparar com print de referencia: em
	## perspectiva o para-lama do lado de ca projeta mais alto que a linha de
	## centro, e medir a silhueta assim acusa erro de modelagem que nao existe.
	var orto := false
	## -1 monta os cinco; 0..4 monta so aquele, e a camera chega perto.
	var so := -1
	## Pose explicita da camera, em graus de azimute / graus de elevacao /
	## metros. Existe para MEDIR: defeito temporal — vidro piscando, textura
	## escorregando — so aparece comparando duas capturas com angulos vizinhos, e
	## para isso o angulo precisa ser um numero na linha de comando, nao o
	## resultado de um arrasto de mouse. NAN = usa a vista nomeada.
	var giro := NAN
	var elev := 12.0
	var dist := 6.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vista="):
			vista = arg.trim_prefix("--vista=")
		elif arg.begins_with("--so="):
			so = arg.trim_prefix("--so=").to_int()
		elif arg.begins_with("--giro="):
			giro = arg.trim_prefix("--giro=").to_float()
		elif arg.begins_with("--elev="):
			elev = arg.trim_prefix("--elev=").to_float()
		elif arg.begins_with("--dist="):
			dist = arg.trim_prefix("--dist=").to_float()
		elif arg == "--orto":
			orto = true
		elif arg == "--rua":
			_montar_rua()
		elif arg == "--sem-gente":
			_com_gente = false
		elif arg == "--sem-interior":
			_com_interior = false
		elif arg == "--longe":
			# A versao de longe do LOD, vista de perto (PLANO_CARROS_AAA, F9).
			_de_longe = true
		elif arg == "--amassado":
			# Uma batida de fabrica na porta da direita (F8).
			_amassados = [[Vector3(-1.0, 0.0, 0.1), 0.38]]
		elif arg == "--trinca":
			# O para-brisa trincado (F8).
			_com_trinca = true

	var tris := 0
	var x := -ESPACO * (MODELOS.size() - 1) * 0.5
	for k in MODELOS.size():
		if so >= 0 and k != so:
			continue
		var modelo: Carroceria.Modelo = MODELOS[k]
		var tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]
		var d := Carroceria.montar(modelo, tinta, k * 13, true, true, _amassados)
		if _de_longe and not (d["longe"] as Dictionary).is_empty():
			var l: Dictionary = d["longe"]
			d["corpo"] = l["corpo"]
			d["eixo_tras"] = l["eixo_tras"]
			d["eixo_frente"] = l["eixo_tras"]
		var raiz := Node3D.new()
		raiz.name = "Carro%d" % k
		raiz.position = (Vector3.ZERO if so >= 0
			else Vector3(x + ESPACO * k, 0.0, 0.0))
		_geo.add_child(raiz)

		# Lataria e interior com o material gravado em cada superficie: o vidro
		# tem o dele (PLANO_CARROS_AAA, F1).
		_por(raiz, d["corpo"], "", Vector3.ZERO)
		# Metade da fila metalica, para comparar lado a lado (F7).
		var lataria := raiz.get_child(raiz.get_child_count() - 1) as MeshInstance3D
		lataria.set_instance_shader_parameter(&"metalico", 1.0 if k % 2 == 1 else 0.0)
		if _com_trinca:
			for a: Dictionary in d["aberturas"]:
				if a["tipo"] == &"parabrisa":
					var c: Vector3 = a["centro"]
					lataria.set_instance_shader_parameter(&"trinca",
						Vector4(c.x + 0.25, c.y - 0.05, c.z, 0.85))
		if _com_interior:
			_por(raiz, d["interior"], "", Vector3.ZERO)
		_por(raiz, d["luzes"], Carroceria.MATERIAL_LUZ, Vector3.ZERO)
		# O motorista no mesmo banco em que o `Carro` senta o da IA. E ele que
		# prova que o vidro deixa ver alguem la dentro.
		if _com_gente:
			var gente := Corpo.new()
			gente.name = "Motorista"
			raiz.add_child(gente)
			gente.montar(Aparencia.de_ficha({"id": 101 + k * 17,
				"sexo": "F" if k % 2 == 1 else "M", "idade": 38}))
			Carro.sentar(gente, d)
		var eixo: float = float(d["entre_eixos"]) * 0.5
		# Frente visual em -Z, igual ao Carro e ao carro_cena depois da meia volta.
		_por(raiz, d["eixo_frente"], Carroceria.MATERIAL,
			Vector3(0.0, Carroceria.RAIO_RODA, -eixo))
		_por(raiz, d["eixo_tras"], Carroceria.MATERIAL,
			Vector3(0.0, Carroceria.RAIO_RODA, eixo))
		tris += int(d["triangulos"])
		print("[vitrine] %d: %d triangulos, %.2f x %.2f x %.2f m"
			% [modelo, int(d["triangulos"]), d["largura"], d["altura"], d["comprimento"]])

	print("[vitrine] %d triangulos" % tris)
	if orto:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = 2.4 if so >= 0 else 22.0
	if is_nan(giro):
		_posicionar_camera(vista, 0.42 if so >= 0 else 1.0, orto)
		return
	_alvo = Vector3(0.0, 0.7, 0.0)
	_giro = Vector2(deg_to_rad(giro), deg_to_rad(elev))
	_raio = dist
	_orbita = not orto
	_recolocar()


func _por(pai: Node3D, malha: Mesh, caminho: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	if not caminho.is_empty():
		mi.material_override = load(caminho) as ShaderMaterial
	mi.position = pos
	pai.add_child(mi)


## Ceu, sol com sombra e chao de asfalto. Para JULGAR MATERIAL: sem ceu o verniz e
## o cromo nao tem o que refletir, e o fundo cinza chapado da vitrine faz todo
## acabamento parecer igual. O padrao continua o fundo neutro, que e o que as
## prints de referencia de silhueta usam.
func _montar_rua() -> void:
	var ceu_mat := ProceduralSkyMaterial.new()
	ceu_mat.sky_top_color = Color(0.32, 0.46, 0.66)
	ceu_mat.sky_horizon_color = Color(0.70, 0.74, 0.78)
	ceu_mat.ground_horizon_color = Color(0.46, 0.44, 0.42)
	ceu_mat.ground_bottom_color = Color(0.20, 0.19, 0.18)
	var ceu := Sky.new()
	ceu.sky_material = ceu_mat
	var amb := Environment.new()
	amb.background_mode = Environment.BG_SKY
	amb.sky = ceu
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	amb.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	amb.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.ssr_enabled = true
	($Ambiente as WorldEnvironment).environment = amb
	var sol := $Sol as DirectionalLight3D
	sol.shadow_enabled = true
	if OS.get_cmdline_user_args().has("--sem-sombra"):
		sol.shadow_enabled = false
	sol.light_energy = 1.4
	var chao := MeshInstance3D.new()
	chao.name = "Chao"
	var plano := PlaneMesh.new()
	plano.size = Vector2(80.0, 40.0)
	chao.mesh = plano
	var mat_chao := StandardMaterial3D.new()
	mat_chao.albedo_color = Color(0.20, 0.20, 0.21)
	mat_chao.roughness = 0.85
	chao.material_override = mat_chao
	add_child(chao)


func _posicionar_camera(vista: String, perto: float, orto: bool = false) -> void:
	# Em projecao paralela a camera desce para a altura do alvo. Elevada, uma
	# ortografica vira planta inclinada: mostra o teto e empurra bico e rabo para
	# cima, o que sabota justamente a medida de silhueta que ela existe para dar.
	#
	# A frente do carro aponta para -Z depois da meia volta da Carroceria.
	if orto:
		_cam.position = Vector3(9.0, 0.75, 0.0)
		if vista == "tras":
			_cam.position = Vector3(0.0, 0.75, 9.0)
		elif vista == "frente_rua":
			_cam.position = Vector3(0.0, 0.75, -9.0)
		elif vista == "cima":
			_cam.position = Vector3(0.0, 9.0, 0.01)
		_cam.look_at(Vector3(0.0, 0.75, 0.0) if vista != "cima"
			else Vector3.ZERO, Vector3.UP)
		return
	match vista:
		"tras":
			_cam.position = Vector3(0.0, 2.6, -11.0) * perto
		"cima":
			_cam.position = Vector3(0.0, 12.0, 0.01) * perto
		"lado":
			_cam.position = Vector3(11.0, 1.6, 0.0) * perto
		_:
			# Enquadra a fila INTEIRA. A camera antiga foi posta quando eram
			# cinco modelos e o ultimo da fila caia fora do quadro — e o ultimo
			# da fila e sempre o carro novo, que e o que se quer olhar.
			if perto >= 1.0:
				_cam.position = Vector3(3.0, 7.6, 25.0)
			else:
				_cam.position = Vector3(6.5, 2.6, 11.0) * perto
	_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
	# Guarda a pose de partida como estado da orbita, para o primeiro arrasto
	# continuar de onde a camera ja esta em vez de dar um salto.
	_orbita = not orto
	_alvo = Vector3(0.0, 0.7, 0.0)
	var d := _cam.position - _alvo
	_raio = d.length()
	_giro = Vector2(atan2(d.x, d.z), asin(clampf(d.y / maxf(_raio, 0.001), -1.0, 1.0)))

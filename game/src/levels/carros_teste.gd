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


func _ready() -> void:
	var vista := "frente"
	## Projecao paralela. Existe para comparar com print de referencia: em
	## perspectiva o para-lama do lado de ca projeta mais alto que a linha de
	## centro, e medir a silhueta assim acusa erro de modelagem que nao existe.
	var orto := false
	## -1 monta os cinco; 0..4 monta so aquele, e a camera chega perto.
	var so := -1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vista="):
			vista = arg.trim_prefix("--vista=")
		elif arg.begins_with("--so="):
			so = arg.trim_prefix("--so=").to_int()
		elif arg == "--orto":
			orto = true

	var tris := 0
	var x := -ESPACO * (MODELOS.size() - 1) * 0.5
	for k in MODELOS.size():
		if so >= 0 and k != so:
			continue
		var modelo: Carroceria.Modelo = MODELOS[k]
		var tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]
		if modelo == Carroceria.Modelo.FUSCA:
			tinta = Carroceria.TINTA_FUSCA
		var d := Carroceria.montar(modelo, tinta, k * 13)
		var raiz := Node3D.new()
		raiz.name = "Carro%d" % k
		raiz.position = (Vector3.ZERO if so >= 0
			else Vector3(x + ESPACO * k, 0.0, 0.0))
		_geo.add_child(raiz)

		_por(raiz, d["corpo"], Carroceria.MATERIAL, Vector3.ZERO)
		_por(raiz, d["luzes"], Carroceria.MATERIAL_LUZ, Vector3.ZERO)
		var eixo: float = float(d["entre_eixos"]) * 0.5
		# Os eixos vem sem a meia volta da lataria; no transito quem os posiciona
		# e o Carro. Aqui a vitrine faz o mesmo para o arco bater com a roda.
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
	_posicionar_camera(vista, 0.42 if so >= 0 else 1.0, orto)


func _por(pai: Node3D, malha: Mesh, caminho: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = load(caminho) as ShaderMaterial
	mi.position = pos
	pai.add_child(mi)


func _posicionar_camera(vista: String, perto: float, orto: bool = false) -> void:
	# Em projecao paralela a camera desce para a altura do alvo. Elevada, uma
	# ortografica vira planta inclinada: mostra o teto e empurra bico e rabo para
	# cima, o que sabota justamente a medida de silhueta que ela existe para dar.
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
	# Perto aproxima em XZ; altura nao esmaga (senao --so=N deixa a camera
	# na altura do para-choque e o perfil vira um "traseira" achatado).
	var d := clampf(perto, 0.35, 1.0)
	var hy := maxf(1.0, 1.0 / sqrt(d))
	match vista:
		"tras":
			_cam.position = Vector3(0.0, 2.6 * hy, 11.0 * d)
		"cima":
			_cam.position = Vector3(0.0, 12.0 * d, 0.01)
		"lado":
			_cam.position = Vector3(8.5 * d, 1.55 * hy, 0.0)
		"frente_rua":
			# Olha a FRETE real do carro (que aponta -Z).
			_cam.position = Vector3(4.2 * d, 2.1 * hy, -8.0 * d)
		"dentro":
			_cam.position = Vector3(0.0, 1.15, 0.35)
		_:
			if perto >= 1.0:
				# Enquadra a fila INTEIRA. Com a camera antiga, posta quando eram
				# cinco modelos, o ultimo da fila caia fora do quadro — e o
				# ultimo da fila e sempre o carro novo, que e justamente o que se
				# quer olhar.
				_cam.position = Vector3(3.0, 7.6, 25.0)
			else:
				_cam.position = Vector3(6.5 * d, 2.8 * hy, 11.0 * d)
	_cam.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)

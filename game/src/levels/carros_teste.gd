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
]

@onready var _geo: Node3D = $Geometria
@onready var _cam: Camera3D = $Camera


func _ready() -> void:
	var vista := "frente"
	## -1 monta os cinco; 0..4 monta so aquele, e a camera chega perto.
	var so := -1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vista="):
			vista = arg.trim_prefix("--vista=")
		elif arg.begins_with("--so="):
			so = arg.trim_prefix("--so=").to_int()

	var tris := 0
	var x := -ESPACO * (MODELOS.size() - 1) * 0.5
	for k in MODELOS.size():
		if so >= 0 and k != so:
			continue
		var modelo: Carroceria.Modelo = MODELOS[k]
		var tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]
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
	_posicionar_camera(vista, 0.42 if so >= 0 else 1.0)


func _por(pai: Node3D, malha: Mesh, caminho: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = load(caminho) as ShaderMaterial
	mi.position = pos
	pai.add_child(mi)


func _posicionar_camera(vista: String, perto: float) -> void:
	match vista:
		"tras":
			_cam.position = Vector3(0.0, 2.6, -11.0) * perto
		"cima":
			_cam.position = Vector3(0.0, 12.0, 0.01) * perto
		"lado":
			_cam.position = Vector3(11.0, 1.6, 0.0) * perto
		_:
			_cam.position = Vector3(7.0, 5.2, 17.0) * perto if perto >= 1.0 else Vector3(6.5, 2.6, 11.0) * perto
	_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)

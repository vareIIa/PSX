## `--capo-lentes=DIR`: duas lentes de fora presas no carro, olhando o do capo
## (a do lado do motorista, na altura do ombro dele, e a de cima do nariz, nas
## costas), gravando um quadro a cada 0,1 s do relogio da cena em
## DIR/<lente>/r_<t>.png — o formato do `tools/mosaico_rajada.py`. As mesmas
## lentes `ombro_lado` e `ombro_costas` da `BancadaCerco`, na cena de verdade
## (a rajada da abertura e a lente do motorista).
class_name LentesDoCapo
extends Node

const LENTES := {
	"ombro_lado": [Vector3(-1.45, 1.42, -1.25), Vector3(-0.18, 1.08, -1.05), 40.0],
	"ombro_costas": [Vector3(-0.2, 1.9, -2.6), Vector3(-0.18, 1.1, -1.0), 42.0],
}
const PASSO := 0.1
const TAMANHO := Vector2i(960, 540)

var carro: Node3D
var pasta := ""
## O relogio da cena (s).
var relogio: Callable
var ligada := false
var _vps: Dictionary = {}
var _proxima := -INF


func _ready() -> void:
	# Depois de quem anima (o cerco, a abertura): a lente ve o quadro pronto.
	process_priority = 200
	for nome: String in LENTES:
		var vp := SubViewport.new()
		vp.name = "Lente_" + nome
		vp.size = TAMANHO
		vp.world_3d = get_viewport().world_3d
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = float(LENTES[nome][2])
		cam.near = 0.02
		cam.far = 400.0
		vp.add_child(cam)
		cam.current = true
		_vps[nome] = [vp, cam]
		DirAccess.make_dir_recursive_absolute(pasta.path_join(nome))


func _process(_delta: float) -> void:
	if carro == null or not is_instance_valid(carro):
		return
	var cx := carro.global_transform
	for nome: String in _vps:
		var cam: Camera3D = _vps[nome][1]
		var de: Vector3 = cx * (LENTES[nome][0] as Vector3)
		var para: Vector3 = cx * (LENTES[nome][1] as Vector3)
		cam.global_transform = Transform3D(Basis.looking_at(para - de, Vector3.UP), de)
	if not ligada or not relogio.is_valid():
		return
	var t: float = relogio.call()
	if t >= _proxima:
		_proxima = t + PASSO - 0.005
		_fotografar(t)


func _fotografar(t: float) -> void:
	await RenderingServer.frame_post_draw
	for nome: String in _vps:
		var vp: SubViewport = _vps[nome][0]
		vp.get_texture().get_image().save_png(pasta.path_join(nome).path_join("r_%07.2f.png" % t))

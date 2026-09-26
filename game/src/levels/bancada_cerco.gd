## Bancada do cerco no carro: o Marea batido, o fogo no capo e o
## `CercoNoCarro` de verdade, fotografado de varias lentes de fora ao mesmo
## tempo — sem rodar os quarenta segundos da estrada.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 1920x1080 --fixed-fps 30 \
##        res://scenes/test/bancada_cerco.tscn -- --fotos=DIR [--cabine] [--neutra] \
##        [--so=frente,lado,tras,pov,vidro] [--ate=S]
##
## A bancada faz o papel da `AberturaEstrada` (os mesmos nomes que o cerco
## le: `_carro`, `_romeiros`, `_cam`, `_raiz`, `_mostrar`, `_estalar`,
## `relance`), e toca a deixa no mesmo ritmo da cena: `comecar`, as sete
## mensagens, `congelar`, e quatro cabecadas. `--fixed-fps 30` antes do `--`
## poe o relogio em passos iguais: a foto de uma lente nao atrasa a cena.
##
## Cada lente grava um quadro a cada 0,1 s em DIR/<lente>/r_<t>.png (o tempo e
## o do `comecar`), no formato do `tools/mosaico_rajada.py`.
##
## Lentes: `frente` (quina do motorista, alta, o capo e o para-brisa), `lado`
## (do carona: o para-lama e o vidro que o do teto sobe), `tras` (o porta-malas),
## `pov` (o olho do motorista, com o relance), `vidro` (de fora, rente ao
## para-brisa: a testa batendo).
##
## `--cabine` liga o interior (a lente `pov` ve as teias e o sangue; de fora o
## vidro da cabine aparece por cima). `--neutra` acende uma luz de chave para
## julgar contato, alem do fogo.
class_name BancadaCerco
extends Node3D

const ALTURAS := [1.82, 1.74, 1.88, 1.80, 1.12, 1.86, 1.78, 1.84, 1.82, 1.76, 1.90, 1.80,
	1.10, 1.84]
const TIPOS := [0, 1, 3, 0, 2, 0, 3, 0, 0, 1, 0, 3, 2, 0]
## A deixa, em segundos desde `comecar` (a mesma conta de `RECADO_TEMPOS`).
const MENSAGENS := [0.35, 1.6, 2.35, 2.75, 3.7, 4.55, 5.37]
const CONGELA := 5.98
## [quando chama, ate o impacto]
const CABECADAS := [[7.4, 0.9], [8.75, 0.55], [10.1, 0.5], [11.35, 0.3]]
const FIM := 13.0
const COMECA := 1.2
const LENTES := {
	"frente": [Vector3(-3.4, 2.4, -5.2), Vector3(-0.1, 1.0, -1.3), 42.0],
	"lado": [Vector3(4.6, 2.3, -1.6), Vector3(0.3, 1.05, -0.8), 42.0],
	"tras": [Vector3(-3.2, 3.2, 5.2), Vector3(0.0, 1.1, 0.6), 42.0],
	"cima": [Vector3(-2.6, 4.6, -2.4), Vector3(0.0, 1.0, -0.6), 48.0],
	"pov": [Vector3(-0.4, 1.16, 0.12), Vector3(-0.38, 1.12, -1.0), 56.0],
	"vidro": [Vector3(-1.25, 1.55, -1.05), Vector3(-0.34, 1.12, -0.72), 40.0],
	# De perto, para julgar mao e manga: a quina do capo onde ele sobe, e o
	# para-lama do carona por onde o do teto vai.
	"capo_perto": [Vector3(-1.7, 1.45, -3.0), Vector3(-0.4, 0.95, -1.75), 36.0],
	"teto_perto": [Vector3(1.9, 2.0, -1.9), Vector3(0.35, 1.3, -0.7), 40.0],
}

var _carro: CarroCena
var _romeiros: Array[Corpo] = []
var _cam: Camera3D
var _raiz: Node3D
var _cerco: CercoNoCarro
var _pasta := ""
var _cabine := false
var _neutra := false
var _so: PackedStringArray = []
var _ate := FIM
## `--tamanho=LxA`: o quadro de cada lente (960x540 por padrao).
var _tamanho := Vector2i(960, 540)
var _vps: Dictionary = {}
var _t := -COMECA
var _proxima_foto := 0.0
var _relance_de: Callable
var _relance_peso := 0.0
var _passo := 0
var _chamadas: Array = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a == "--cabine":
			_cabine = true
		elif a == "--neutra":
			_neutra = true
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=").split(",")
		elif a.begins_with("--ate="):
			_ate = float(a.trim_prefix("--ate="))
		elif a.begins_with("--tamanho="):
			var lxa := a.trim_prefix("--tamanho=").split("x")
			_tamanho = Vector2i(int(lxa[0]), int(lxa[1]))
	_raiz = self
	_montar_palco()
	_carro = CarroCena.new()
	_carro.name = "Carro"
	_carro.com_som = false
	add_child(_carro)
	_carro.preparar_batida()
	_carro.amassar_frente(1.0, 1.0)
	_carro.mostrar_cabine(_cabine)
	var fogo := IncendioDoCapo.new()
	_carro.add_child(fogo)
	fogo.position = AberturaEstrada.INCENDIO_NO_CARRO
	fogo.pegar_fogo(1.0, 0.1)
	fogo.fumegar(1.0, 0.1)
	# O chao onde o carro esta.
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(30, 30)
	chao.mesh = plano
	var barro := StandardMaterial3D.new()
	barro.albedo_color = Color(0.07, 0.055, 0.045)
	barro.roughness = 0.35
	chao.material_override = barro
	add_child(chao)
	chao.global_position = Vector3(_carro.global_position.x, _carro.global_position.y,
		_carro.global_position.z)
	for i in ALTURAS.size():
		_romeiros.append(_encapuzado("Romeiro%d" % i, i + 1, float(ALTURAS[i]), int(TIPOS[i])))
	_montar_lentes()
	_cerco = CercoNoCarro.new()
	_cerco.name = "CercoNoCarro"
	add_child(_cerco)
	_cerco.usar_chao_plano(0.0)
	_cerco.montar(self)
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta)


func _encapuzado(nome: String, i: int, altura: float, tipo: int) -> Corpo:
	var c := Corpo.new()
	c.name = nome
	add_child(c)
	c.montar(AberturaEstrada._aparencia_de_encapuzado(i, altura,
		AberturaEstrada.OMBRO_ENCAPUZADO, false))
	c.jeito = {"curvatura": [0.05, 0.16, 0.03, 0.22][tipo], "cabeca": 0.1}
	c.visible = false
	MonstroDaEstrada.vestir(c, i, AberturaEstrada.OMBRO_ENCAPUZADO / 0.42, false)
	var aura := AuraNegra.criar(AberturaEstrada.AURA_CAIXA * (altura / 1.9),
		AberturaEstrada.AURA_FIGURA, 0.9)
	aura.emitting = false
	c.add_child(aura)
	aura.position = Vector3(0.0, altura * 0.42, 0.0)
	c.set_meta(&"aura", aura)
	c.position = Vector3(8.0 + float(i), 0.0, 8.0)
	return c


func _montar_palco() -> void:
	var mundo := WorldEnvironment.new()
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0.01, 0.012, 0.016)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color(0.25, 0.3, 0.4)
	amb.ambient_light_energy = 0.3 if _neutra else 0.18
	amb.tonemap_mode = Environment.TONE_MAPPER_AGX
	amb.glow_enabled = true
	amb.glow_intensity = 0.4
	amb.ssao_enabled = true
	mundo.environment = amb
	add_child(mundo)
	var lua := DirectionalLight3D.new()
	lua.rotation_degrees = Vector3(-50, 30, 0)
	lua.light_color = Color(0.55, 0.65, 0.9)
	lua.light_energy = 0.8 if _neutra else 0.22
	lua.shadow_enabled = true
	add_child(lua)
	_cam = Camera3D.new()
	_cam.fov = 56.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()


func _montar_lentes() -> void:
	for nome: String in LENTES:
		if not _so.is_empty() and not _so.has(nome):
			continue
		var vp := SubViewport.new()
		vp.name = "Lente_" + nome
		vp.size = _tamanho
		vp.world_3d = get_viewport().world_3d
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = float(LENTES[nome][2])
		cam.near = 0.02
		cam.cull_mask = 0xFFFFF
		vp.add_child(cam)
		cam.current = true
		_vps[nome] = [vp, cam]
		if not _pasta.is_empty():
			DirAccess.make_dir_recursive_absolute(_pasta.path_join(nome))


func _process(delta: float) -> void:
	_t += delta
	_passo += 1
	_mover_lentes()
	var agora := _t
	if agora >= 0.0 and not _chamou("comecar"):
		_cerco.aquecer(true, _cam.global_position + _cam.global_basis * Vector3(0, 0, -3))
		_cerco.aquecer(false, Vector3.ZERO)
		_cerco.comecar()
	for i in MENSAGENS.size():
		if agora >= float(MENSAGENS[i]) and not _chamou("m%d" % i):
			_cerco.mensagem(i, MENSAGENS.size())
	if agora >= CONGELA and not _chamou("congela"):
		_cerco.congelar()
	for g in CABECADAS.size():
		var c: Array = CABECADAS[g]
		if agora >= float(c[0]) and not _chamou("cab%d" % g):
			_cerco.cabecada(g, float(c[1]))
	if agora >= 0.0 and agora >= _proxima_foto and not _pasta.is_empty():
		_proxima_foto += 0.1
		_fotografar(agora)
	if agora >= _ate:
		_cerco.desligar()
		print("[bancada_cerco] fim")
		get_tree().quit()


func _chamou(nome: String) -> bool:
	if _chamadas.has(nome):
		return true
	_chamadas.append(nome)
	return false


func _mover_lentes() -> void:
	var cx := _carro.global_transform
	for nome: String in _vps:
		var cam: Camera3D = _vps[nome][1]
		var de: Vector3 = cx * (LENTES[nome][0] as Vector3)
		var para: Vector3 = cx * (LENTES[nome][1] as Vector3)
		if nome == "pov":
			var r := _cerco.rosto_no_capo()
			if r.is_finite():
				para = para.lerp(r, 0.5)
			if _relance_peso > 0.001 and _relance_de.is_valid():
				var pr: Vector3 = _relance_de.call()
				if pr.is_finite():
					para = para.lerp(pr, _relance_peso)
		cam.global_transform = Transform3D(Basis.looking_at(para - de, Vector3.UP), de)
	_cam.global_transform = (_vps["pov"][1] as Camera3D).global_transform if _vps.has("pov") \
		else Transform3D(Basis.looking_at(cx * Vector3(0, 1, -1) - cx * Vector3(-0.4, 1.16, 0.12),
			Vector3.UP), cx * Vector3(-0.4, 1.16, 0.12))


func _fotografar(t: float) -> void:
	await RenderingServer.frame_post_draw
	for nome: String in _vps:
		var vp: SubViewport = _vps[nome][0]
		vp.get_texture().get_image().save_png(_pasta.path_join(nome).path_join("r_%07.2f.png" % t))


# --- o que o cerco pede da abertura -----------------------------------------

func _mostrar(c: Corpo, _alvo: Node3D = null, _rapidez: float = 0.0) -> void:
	c.visible = true
	var aura := c.get_meta(&"aura", null) as AuraNegra
	if aura != null:
		aura.acender()


func _estalar(_c: Corpo, _forca: float, _roteiro: bool = true) -> void:
	pass


func relance(ponto: Callable, ida: float, fica: float, volta: float,
		peso: float = 1.0, _fov: float = 0.0) -> void:
	print("[bancada_cerco] relance em t=%.2f" % _t)
	_relance_de = ponto
	var tw := create_tween()
	tw.tween_property(self, "_relance_peso", peso, ida)
	tw.tween_interval(fica)
	tw.tween_property(self, "_relance_peso", 0.0, volta)

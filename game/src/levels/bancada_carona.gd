## Bancada do padre da janela do carona (`PadresNasJanelas`): o Marea batido,
## o fogo no capo e o romeiro 3 vestido como na cena, montado na janela da
## direita e batendo nos mesmos tempos da abertura — sem rodar os quarenta
## segundos da estrada.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 1920x1080 --fixed-fps 30 \
##        res://scenes/test/bancada_carona.tscn -- --carona-lente=DIR \
##        [--carona-sonda] [--pov=DIR] [--ate=S]
##
## A bancada faz o papel da `AberturaEstrada` para o `PadresNasJanelas`
## (`_relogio_cena`, `_som`) e pede os golpes nos tempos da cena, contados do
## `montar`: +1,4 s e +3,3 s (os timers da abertura) e +5,93 s (o do relance,
## depois da segunda do principal). `--pov=DIR` grava a lente principal (o
## olho do motorista, virado para a janela da direita) a cada 0,1 s.
extends Node3D

## [quando, recua, bote, longe, forca], em s desde o `montar`.
const GOLPES := [[1.4, 0.5, 0.09, 0.14, 0.55], [3.3, 0.36, 0.08, 0.1, 0.7],
	[5.93, 0.3, 0.07, 0.12, 0.8]]
const COMECA := 1.5
const FIM := 7.5
## O romeiro 3 da cena: `FIGURAS[3]` (altura, tipo).
const ALTURA := 1.80
const TIPO := 0

var _relogio_cena := 0.0
## Como a da cena: o `PadresNasJanelas` le o romeiro 3 daqui (o tipo dele).
var _romeiros: Array = []
var _carro: CarroCena
var _cam: Camera3D
var _corpo: Corpo
var _outros: PadresNasJanelas
var _t := -COMECA
var _ate := FIM
var _pov := ""
var _proxima := 0.0
var _feitos: Array = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--pov="):
			_pov = a.trim_prefix("--pov=")
			DirAccess.make_dir_recursive_absolute(_pov)
		elif a.begins_with("--ate="):
			_ate = float(a.trim_prefix("--ate="))
	_palco()
	_carro = CarroCena.new()
	_carro.name = "Carro"
	_carro.com_som = false
	add_child(_carro)
	_carro.preparar_batida()
	_carro.amassar_frente(1.0, 1.0)
	_carro.mostrar_cabine(true)
	var fogo := IncendioDoCapo.new()
	_carro.add_child(fogo)
	fogo.position = AberturaEstrada.INCENDIO_NO_CARRO
	fogo.pegar_fogo(1.0, 0.1)
	fogo.fumegar(1.0, 0.1)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(30, 30)
	chao.mesh = plano
	var barro := StandardMaterial3D.new()
	barro.albedo_color = Color(0.07, 0.055, 0.045)
	barro.roughness = 0.35
	chao.material_override = barro
	add_child(chao)
	_corpo = _encapuzado("Romeiro3", 4, ALTURA, TIPO)
	_romeiros = [null, null, null, _corpo]
	PadresNasJanelas.preparar_bracos(_carro.cabine)
	for b: BracoVivo in _carro.cabine.get_meta(&"bracos_carona", []):
		# O aquecer do cerco: desenhados uma vez, e apagados.
		b.ombro = Vector3(0.6, 1.4, 0.0)
		b.pular(BracoVivo.pega(Vector3(0.6, 1.0, 0.0), Vector3.DOWN, Vector3.RIGHT, &"apoio"))
		b.refazer()


## A mesma assinatura da `AberturaEstrada._encapuzado`: o `PadresNasJanelas`
## monta aqui o corpo dele na altura da janela.
func _encapuzado(nome: String, i: int, altura: float, tipo: int) -> Corpo:
	var c := Corpo.new()
	c.name = nome
	add_child(c)
	c.montar(AberturaEstrada._aparencia_de_encapuzado(i, altura,
		AberturaEstrada.OMBRO_ENCAPUZADO, false))
	c.jeito = {"curvatura": [0.05, 0.16, 0.03, 0.22][tipo],
		"cabeca": [0.08, 0.20, 0.05, 0.26][tipo] + 0.02 * float(i % 3)}
	c.visible = false
	MonstroDaEstrada.vestir(c, i, AberturaEstrada.OMBRO_ENCAPUZADO / 0.42, false)
	c.set_meta(&"tique", TiqueMacabro.new(c, i, TiqueMacabro.Modo.FUNDO))
	c.com_rosto = true
	c.position = Vector3(6.0, 0.0, 6.0)
	return c


func _palco() -> void:
	var mundo := WorldEnvironment.new()
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0.02, 0.022, 0.03)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color(0.25, 0.3, 0.4)
	amb.ambient_light_energy = 0.35
	amb.tonemap_mode = Environment.TONE_MAPPER_AGX
	amb.ssao_enabled = true
	mundo.environment = amb
	add_child(mundo)
	var lua := DirectionalLight3D.new()
	lua.rotation_degrees = Vector3(-40, 60, 0)
	lua.light_color = Color(0.6, 0.68, 0.9)
	lua.light_energy = 0.7
	lua.shadow_enabled = true
	add_child(lua)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()


func _process(delta: float) -> void:
	_t += delta
	_relogio_cena = _t
	_mirar()
	if _corpo.visible:
		# Como o `_assombrar` da cena: `dominado` derruba a assinatura da pose, e
		# o corpo escreve a pose inteira de novo neste quadro. Sem isto a pose
		# fica no cache (parado, ela muda a cada ~0,38 s) e a cabecada, que
		# multiplica por cima do que esta no osso, se acumula quadro a quadro.
		_corpo.dominado = false
		_corpo.animar(0.0, delta)
		var tique := _corpo.get_meta(&"tique", null) as TiqueMacabro
		if tique != null:
			tique.passo(delta)
	if _t >= 0.0 and not _feitos.has("montar"):
		_feitos.append("montar")
		_outros = PadresNasJanelas.montar(self, _carro, _romeiros, _cam,
			_abertura(&"porta_frente", 1))
	for g in GOLPES.size():
		var gp: Array = GOLPES[g]
		if _t >= float(gp[0]) and not _feitos.has(g):
			_feitos.append(g)
			print("[bancada_carona] pede golpe %d em t=%.2f" % [g, _t])
			_outros.golpe(gp[1], gp[2], gp[3], gp[4])
	if not _pov.is_empty() and _t >= 0.0 and _t + 1e-4 >= _proxima:
		_proxima += 0.1
		_foto(_t)
	if _t >= _ate:
		print("[bancada_carona] fim")
		get_tree().quit()


## O olho do motorista, virado para a janela da direita (o relance da cena).
func _mirar() -> void:
	var cab := _carro.cabine
	var olho := cab.to_global(cab.olho())
	var a := _abertura(&"porta_frente", 1)
	var para := cab.to_global(a["centro"] as Vector3) if not a.is_empty() else olho + Vector3.RIGHT
	# Parada no vidro (um palmo acima do meio): e o movimento dele que se julga.
	para += Vector3.UP * 0.08
	_cam.global_transform = Transform3D(Basis.looking_at(para - olho, Vector3.UP), olho)


func _abertura(tipo: StringName, lado: int) -> Dictionary:
	for a: Dictionary in _carro.medidas().get("aberturas", []):
		if a["tipo"] == tipo and (tipo == &"parabrisa" or int(a["lado"]) == lado):
			return a
	return {}


func _som(nome: StringName, _db: float = 0.0, _tom: float = 1.0) -> void:
	print("[bancada_carona] som %s em t=%.2f" % [nome, _t])


func _foto(t: float) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_pov.path_join("r_%07.2f.png" % t))

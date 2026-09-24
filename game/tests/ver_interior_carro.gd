## Vitrine do interior em alta: painel, radio, console, freio de mao e cambio,
## de varios angulos e em dois climas de luz.
##
##     godot --path game --script res://tests/ver_interior_carro.gd -- --saida=DIR
##     ... --modelo=MAREA --tam=1920x1080 --luz=dia|noite --vistas=frente,radio
##
## SEM --headless: precisa de janela para o shader compilar.
##
## Por que existe, se ja ha `ver_cabine.gd`
## ----------------------------------------
## `ver_cabine` fotografa a 480x270 olhando para a frente e para a porta: e a
## vitrine da CASCA. O que esta aqui e a vitrine da MOBILIA — o console entre os
## bancos so aparece olhando para baixo, o radio so aparece virando a cabeca para
## a direita, e em 480x270 um botao de radio e um pixel.
extends SceneTree

const MODELOS := {
	"MAREA": Carroceria.Modelo.MAREA, "SEDA": Carroceria.Modelo.SEDA,
	"HATCH": Carroceria.Modelo.HATCH, "PERUA": Carroceria.Modelo.PERUA,
	"PICAPE": Carroceria.Modelo.PICAPE, "FUSCA": Carroceria.Modelo.FUSCA,
	"TAXI": Carroceria.Modelo.TAXI,
}

## Cada vista: guinada, arfagem (graus), deslocamento do olho (m, espaco do
## carro) e FOV. "frente" e o plano de quem dirige; as outras sao a cabeca
## virando para o que o jogador procura com a mao.
const VISTAS := {
	"frente": [0.0, -4.0, Vector3.ZERO, 74.0],
	"painel": [0.0, -18.0, Vector3.ZERO, 60.0],
	"radio": [-32.0, -30.0, Vector3.ZERO, 58.0],
	"console": [-28.0, -52.0, Vector3.ZERO, 66.0],
	"passageiro": [28.0, -24.0, Vector3(0.80, 0.0, 0.0), 70.0],
	"pala": [-62.0, -16.0, Vector3(0.30, -0.02, -0.12), 50.0],
	"cambio": [0.0, -62.0, Vector3(0.40, 0.0, 0.05), 60.0],
	"porta_trecos": [-10.0, -40.0, Vector3(0.38, -0.20, 0.10), 55.0],
	"porta": [35.0, -14.0, Vector3.ZERO, 74.0],
	"banco_tras": [180.0, -24.0, Vector3(0.40, 0.05, 0.10), 80.0],
}

## Closes: o nome de um ponto do interior, o FOV e de onde o olho olha (m,
## somados ao olho do motorista).
const CLOSES := {
	"z_cluster": ["cluster", 30.0, Vector3(0.0, 0.0, 0.0)],
	"z_radio": ["radio", 26.0, Vector3(0.10, -0.03, 0.0)],
	"z_ar": ["ar", 26.0, Vector3(0.10, -0.06, 0.0)],
	"z_cambio": ["cambio", 34.0, Vector3(0.30, 0.0, 0.10)],
	"z_tomada": ["tomada", 34.0, Vector3(0.30, -0.12, 0.10)],
	"z_coluna": ["coluna", 40.0, Vector3(0.22, -0.10, 0.02)],
	"z_freio": ["freio", 40.0, Vector3(0.30, 0.0, 0.05)],
	"z_pala": ["pala", 36.0, Vector3(0.55, 0.02, 0.10)],
	"zz_radio": ["radio", 12.0, Vector3(0.40, -0.12, -0.12)],
	"z_pedais": ["pedais", 60.0, Vector3(0.25, -0.30, 0.10)],
	"z_porta": ["porta", 62.0, Vector3(0.45, -0.05, 0.05)],
	"z_porta_tras": ["porta_tras", 70.0, Vector3(0.55, -0.02, 0.35)],
	"z_banco": ["banco", 60.0, Vector3(0.10, 0.10, -0.55)],
	"z_lado_coluna": ["coluna", 42.0, Vector3(0.42, -0.14, 0.02)],
}

var _saida := ""
var _modelos: Array[String] = []
var _vistas: Array[String] = []
var _tam := Vector2i(1600, 900)
var _noite := false


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			_saida = a.trim_prefix("--saida=")
		elif a.begins_with("--modelo="):
			_modelos.append(a.trim_prefix("--modelo=").to_upper())
		elif a.begins_with("--vistas="):
			_vistas.assign(a.trim_prefix("--vistas=").split(","))
		elif a.begins_with("--tam="):
			var p := a.trim_prefix("--tam=").split("x")
			_tam = Vector2i(p[0].to_int(), p[1].to_int())
		elif a == "--luz=noite":
			_noite = true
	if _modelos.is_empty():
		_modelos = ["MAREA"]
	if _vistas.is_empty():
		_vistas.assign(VISTAS.keys())
		_vistas.append_array(CLOSES.keys())
	_rodar.call_deferred()


func _rodar() -> void:
	for nome: String in _modelos:
		if not MODELOS.has(nome):
			print("modelo desconhecido: %s" % nome)
			continue
		await _fotografar(nome, MODELOS[nome])
	quit(0)


func _fotografar(nome: String, modelo: int) -> void:
	var vp := SubViewport.new()
	vp.size = _tam
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)

	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if _noite:
		env.background_color = Color(0.03, 0.035, 0.05)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.10, 0.11, 0.14)
		env.ambient_light_energy = 1.0
	else:
		env.background_color = Color(0.62, 0.66, 0.70)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.64, 0.68)
		env.ambient_light_energy = 0.8
	amb.environment = env
	vp.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	sol.light_energy = 0.12 if _noite else 1.0
	sol.light_color = Color(0.6, 0.7, 1.0) if _noite else Color(1.0, 0.95, 0.86)
	sol.shadow_enabled = true
	vp.add_child(sol)

	var medidas := Carroceria.montar(modelo, CarroCena.TINTA, CarroCena.SEMENTE,
		true, false)
	var carro := Node3D.new()
	vp.add_child(carro)
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"] as ArrayMesh
	lataria.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	carro.add_child(lataria)
	var cab := CarroCabine.new()
	carro.add_child(cab)
	cab.montar(medidas)
	# Um instante de estrada: 62 km/h em terceira, seta esquerda na metade
	# acesa, freio solto, o radio numa FM.
	cab.marcar(62.0)
	var it := cab.interior()
	if it != null:
		it.acender_painel(1.0 if _noite else 0.0)
		it.giro(2600.0)
		it.marcha("3")
		it.freio_de_mao(false)
		it.seta(-1, true)
		it.visor_estacao("FM 92,7")

	# `--carregador`: o carregador de isqueiro de `AoVolante`, com as mesmas
	# medidas e o mesmo lugar, para conferir que ele entra na tomada.
	if OS.get_cmdline_user_args().has("--carregador") and it != null:
		var olho0 := cab.olho()
		var lado := cab.lado_do_motorista()
		var dentro := -signf(lado) if absf(lado) > 0.01 else 1.0
		var no := Node3D.new()
		no.position = olho0 + Vector3(0.36 * dentro, -0.50, -0.46)
		no.rotation = Vector3(deg_to_rad(-25.0), 0.0, 0.0)
		cab.add_child(no)
		var corpo := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.011
		cil.bottom_radius = 0.012
		cil.height = 0.045
		corpo.mesh = cil
		corpo.rotation.x = PI * 0.5
		no.add_child(corpo)

	# A luz de painel e a de teto da cabine do jogador, para a noite nao ser
	# so o que o mostrador acende.
	if _noite:
		var luz := OmniLight3D.new()
		luz.position = cab.olho() + CabineDoJogador.LUZ_PAINEL_DO_OLHO
		luz.omni_range = CabineDoJogador.LUZ_PAINEL_ALCANCE
		luz.light_energy = CabineDoJogador.LUZ_PAINEL_ENERGIA
		luz.light_color = CabineDoJogador.LUZ_PAINEL_COR
		carro.add_child(luz)

	var cam := Camera3D.new()
	cam.near = 0.02
	vp.add_child(cam)
	cam.make_current()

	for vista: String in _vistas:
		if CLOSES.has(vista) and it != null:
			var cl: Array = CLOSES[vista]
			var alvo := _foco(cab, it, String(cl[0]))
			cam.fov = float(cl[1])
			var de: Vector3 = cab.olho() + (cl[2] as Vector3)
			cam.transform = Transform3D(Basis(), de).looking_at(alvo, Vector3.UP)
		elif VISTAS.has(vista):
			var v: Array = VISTAS[vista]
			cam.fov = float(v[3])
			var olho: Vector3 = cab.olho() + (v[2] as Vector3)
			cam.transform = Transform3D(
				Basis(Vector3.UP, deg_to_rad(float(v[0])))
					* Basis(Vector3.RIGHT, deg_to_rad(float(v[1]))), olho)
		else:
			print("vista desconhecida: %s" % vista)
			continue
		# Duas passadas: a primeira sai com o mundo meio montado. Ver a memoria
		# do projeto "primeira execucao nao vale captura".
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var arquivo := "int_%s_%s%s.png" % [nome.to_lower(), vista,
			"_noite" if _noite else ""]
		if _saida != "":
			img.save_png(_saida.path_join(arquivo))
		print("%s %s -> %s" % [nome, vista, arquivo])
	vp.queue_free()
	await process_frame


## Um ponto do interior pelo nome, no espaco do carro.
func _foco(cab: CarroCabine, it: CabineInterior, nome: String) -> Vector3:
	var g := it.g
	var topo: float = g["topo"]
	var zl: float = g["lip_z"]
	var piso: float = g["piso"]
	var olho := cab.olho()
	match nome:
		"cluster":
			return CabinePainel.centro_do_cluster(it)
		"radio":
			return Vector3(0.0, topo - 0.02 - CabinePainel.CENTRO_RADIO, zl + 0.01)
		"ar":
			return Vector3(0.0, topo - 0.02 - CabinePainel.CENTRO_AR - 0.02, zl + 0.0)
		"cambio":
			return Vector3(0.0, piso + 0.33, olho.z - 0.13)
		"tomada":
			return it.tomada().origin
		"coluna":
			return (g["volante"] as Vector3) + Vector3(0.05, -0.08, -0.14)
		"freio":
			return Vector3(0.0, piso + 0.22, olho.z + 0.18)
		"pala":
			return CabinePainel.centro_do_cluster(it) + Vector3(0.0, 0.07, 0.0)
		"porta":
			return Vector3(-0.72, piso + 0.40, -0.05)
		"porta_tras":
			return Vector3(-0.70, piso + 0.40, 0.75)
		"banco":
			return Vector3(-0.40, piso + 0.40, olho.z + 0.30)
		"pedais":
			return Vector3(olho.x, piso + 0.15, maxf(float(g["z_frente"]) + 0.14, olho.z - 0.62))
	return olho + Vector3.FORWARD

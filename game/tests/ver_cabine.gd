## Vitrine do interior: fotografa a cabine de qualquer modelo, de qualquer
## angulo, sem precisar da cutscene.
##
##     godot --path game --script res://tests/ver_cabine.gd -- --saida=DIR
##     ... --modelo=FUSCA --yaw=-35 --pitch=-4
##
## SEM --headless: precisa de janela para o shader compilar.
##
## Por que existe
## --------------
## O plano de dentro da Estrada Velha olha para a frente e nao vira a cabeca, e
## por isso a porta do motorista — forro, maçaneta, manivela, trava — nunca
## aparece na captura da cutscene. O criterio C13 do PLANO_CHUVA_CABINE_AAA pede
## exatamente essa imagem: "maçaneta, manivela, trava e apoio de braco aparecem
## com a cabeca virada 35 graus para a esquerda".
##
## Serve tambem para olhar um modelo que ainda nao tem cena propria: Fusca,
## picape e perua nunca foram vistos por dentro.
extends SceneTree

const MODELOS := {
	"MAREA": Carroceria.Modelo.MAREA, "SEDA": Carroceria.Modelo.SEDA,
	"HATCH": Carroceria.Modelo.HATCH, "PERUA": Carroceria.Modelo.PERUA,
	"PICAPE": Carroceria.Modelo.PICAPE, "FUSCA": Carroceria.Modelo.FUSCA,
	"TAXI": Carroceria.Modelo.TAXI,
}

## Mesmo enquadramento do plano de dentro da cutscene.
const FOV := 74.0
const TAMANHO := Vector2i(480, 270)

var _saida := ""
var _modelos: Array[String] = []
var _yaws: Array[float] = [0.0, -35.0]
var _pitch := -4.0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			_saida = a.trim_prefix("--saida=")
		elif a.begins_with("--modelo="):
			_modelos.append(a.trim_prefix("--modelo=").to_upper())
		elif a.begins_with("--yaw="):
			_yaws = [a.trim_prefix("--yaw=").to_float()]
		elif a.begins_with("--pitch="):
			_pitch = a.trim_prefix("--pitch=").to_float()
	if _modelos.is_empty():
		_modelos.assign(MODELOS.keys())
	_rodar.call_deferred()


func _rodar() -> void:
	for nome: String in _modelos:
		if not MODELOS.has(nome):
			print("modelo desconhecido: %s" % nome)
			continue
		for yaw: float in _yaws:
			await _fotografar(nome, MODELOS[nome], yaw)
	quit(0)


func _fotografar(nome: String, modelo: int, yaw: float) -> void:
	var vp := SubViewport.new()
	vp.size = TAMANHO
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)

	# Luz de dia fraca e ceu claro: a vitrine mostra GEOMETRIA, e a calibracao
	# de luz da cena e outra conversa (Fase 5).
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.66, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 1.0
	amb.environment = env
	vp.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sol.light_energy = 0.9
	sol.shadow_enabled = false
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

	var cam := Camera3D.new()
	cam.fov = FOV
	cam.near = 0.02
	cam.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(_pitch)),
		cab.olho())
	vp.add_child(cam)
	cam.make_current()

	# Duas passadas: a primeira sai com o mundo meio montado. Ver a memoria do
	# projeto "primeira execucao nao vale captura".
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	var arquivo := "cabine_%s_yaw%+03d.png" % [nome.to_lower(), int(yaw)]
	if _saida != "":
		img.save_png(_saida.path_join(arquivo))
	print("%s: olho %s, yaw %+.0f -> %s" % [nome, cab.olho(), yaw, arquivo])
	vp.queue_free()
	await process_frame

## Bancada do fumante: a mao chega na boca? a blunt encosta nos labios? a
## fumaca sai de onde tem de sair?
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_fumo.gd -- --saida=DIR
##
##   posturas.png   uma linha por postura (de pe, sofa, chao, encostado,
##                  dancando): repouso, a caminho, na boca puxando, soltando
##   estilos.png    os sete estilos no momento que os distingue, de pe
##   blunt.png      a blunt de perto: MODERNO e PS1 STYLE, com cinza e sem
##
## Imprime `[fumo] chave=valor`. As medidas, com o corpo NA BOCA (alcance 1):
##
##   labio_mm     da boca da blunt ao ponto dos labios. A Blunt mira ali; se
##                passar de 6 mm a mira nao esta sendo aplicada.
##   pega_mm      da pega da mao ao alvo que o IK pediu. Acima de 15 mm o braco
##                nao chegou (postura que prende o ombro, alvo fora do alcance).
##   dedo_mm      da pega da mao ao eixo da blunt: os dedos seguram a blunt, ou
##                ela passa ao lado da mao?
##   mao_boca_cm  da pega aos labios, que e o que o olho le como "na boca".
##
## E, sem o relogio de verdade, a mesma conta com o gesto antigo, para o antes.
extends SceneTree

const QUADRO := Vector2i(280, 280)

var _saida := ""
var _vp: SubViewport
var _cam: Camera3D
var _mundo: Node3D


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_rodar()


func _rodar() -> void:
	await process_frame
	_vp = SubViewport.new()
	_vp.size = QUADRO
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2730")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a8078")
	env.ambient_light_energy = 0.7
	ambiente.environment = env
	_mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 0.9
	luz.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-140.0), 0.0)
	_mundo.add_child(luz)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_mundo.add_child(_cam)
	_cam.current = true

	await _antes()
	await _posturas()
	await _estilos()
	await _blunt_de_perto()
	quit()


# --- montagem ---------------------------------------------------------------

func _fumante(semente: int) -> Array:
	var c := Corpo.new()
	c.com_rosto = true
	_mundo.add_child(c)
	c.montar(Aparencia.de_ficha({"id": semente, "sexo": &"M", "idade": 27}))
	c.fumo = Tragada.new(semente)
	var b := Blunt.new()
	_mundo.add_child(b)
	b.montar(c, semente)
	return [c, b]


func _desmontar(par: Array) -> void:
	(par[0] as Node).queue_free()
	(par[1] as Node).queue_free()


## Leva o relogio ao instante `t` do estilo e anima o corpo ate la em passos de
## 1/15 s, que e o degrau da pose.
func _posar(c: Corpo, b: Blunt, estilo: Tragada.Estilo, t: float) -> void:
	c.fumo.forcar(estilo, maxf(0.0, t - 1.0))
	var passo := 1.0 / 15.0
	var andou := 0.0
	while andou < minf(t, 1.0) - 0.0001:
		c.animar(0.0, passo)
		andou += passo
	c.animar(0.0, 0.0001)
	b.atualizar(0.0001)


## Em que instante do estilo cada fase comeca.
func _inicio(estilo: Tragada.Estilo, fase: Tragada.Fase) -> float:
	var d: Array = Tragada.DURACOES[estilo]
	var t := 0.0
	for i in int(fase):
		t += float(d[i])
	return t


func _meio(estilo: Tragada.Estilo, fase: Tragada.Fase, p: float = 0.5) -> float:
	var d: Array = Tragada.DURACOES[estilo]
	return _inicio(estilo, fase) + float(d[fase]) * p


func _enquadrar_rosto(c: Corpo, lado: float = 1.0, dist: float = 0.95) -> void:
	var boca := c.boca_no_mundo().origin
	var alvo := boca + Vector3(0.05 * lado, -0.12, 0.0)
	# Tres quartos pela frente e pelo lado da mao (o corpo olha para -Z).
	_cam.position = alvo + Vector3(0.55 * lado, 0.12, -0.85).normalized() * dist
	_cam.look_at(alvo, Vector3.UP)


func _medir(nome: String, c: Corpo, b: Blunt) -> void:
	var boca := c.boca_no_mundo()
	var pega := c.pega_no_mundo().origin
	var alvo := boca * Corpo.ALVO_DA_PEGA
	var labio := boca.origin + boca.basis * Vector3(0.0, 0.0, 0.004)
	var eixo := b.global_transform.basis.x.normalized()
	var rel := pega - b.global_position
	var fora := (rel - eixo * rel.dot(eixo)).length()
	print("[fumo] %s labio_mm=%.1f pega_mm=%.1f dedo_mm=%.1f mao_boca_cm=%.1f" % [
		nome, b.global_position.distance_to(labio) * 1000.0,
		pega.distance_to(alvo) * 1000.0, fora * 1000.0,
		pega.distance_to(boca.origin) * 100.0])


# --- antes: o gesto antigo, sem relogio ------------------------------------

func _antes() -> void:
	var c := Corpo.new()
	_mundo.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 5, "sexo": &"M", "idade": 27}))
	c.postura(Corpo.Postura.FUMANDO)
	# O pico do ciclo antigo: 16% a 44% de 6,5 s.
	var andou := 0.0
	while andou < 6.5 * 0.3:
		c.animar(0.0, 1.0 / 15.0)
		andou += 1.0 / 15.0
	var sk := c.esqueleto()
	var ante := sk.global_transform * sk.get_bone_global_pose(c.osso_da_mao())
	var punho := ante * Vector3(0.0, -0.24, 0.07)
	print("[fumo] antes punho_boca_cm=%.1f" % (punho.distance_to(c.boca_no_mundo().origin) * 100.0))
	c.queue_free()
	await process_frame


# --- posturas ---------------------------------------------------------------

func _posturas() -> void:
	var quadros: Array = []
	var casos := [
		["em_pe", Corpo.Postura.FUMANDO, 0.0],
		["sofa", Corpo.Postura.ASSENTO, 0.47],
		["chao", Corpo.Postura.SENTADO, 0.0],
		["encostado", Corpo.Postura.ENCOSTADO, 0.0],
		["dancando", Corpo.Postura.DANCANDO, 0.0],
	]
	var e := Tragada.Estilo.CURTA
	for caso: Array in casos:
		var par := _fumante(11)
		var c: Corpo = par[0]
		var b: Blunt = par[1]
		c.tragando = true
		if float(caso[2]) > 0.0:
			c.altura_assento = float(caso[2])
		c.postura(caso[1])
		for t: float in [_inicio(e, Tragada.Fase.ESPERA) + 0.5,
				_meio(e, Tragada.Fase.SOBE, 0.5),
				_meio(e, Tragada.Fase.PUXA, 0.5),
				_meio(e, Tragada.Fase.SOLTA, 0.25)]:
			_posar(c, b, e, t)
			if c.fumo.fase() == Tragada.Fase.PUXA:
				_medir(String(caso[0]), c, b)
			_enquadrar_rosto(c, 1.0, 1.5)
			quadros.append(await _foto(0 if c.fumo.fase() != Tragada.Fase.SOLTA else 24))
			if c.fumo.fase() == Tragada.Fase.PUXA:
				# De perfil e de perto: a blunt entra na boca?
				var boca := c.boca_no_mundo().origin
				_cam.position = boca + Vector3(0.42, 0.02, -0.05)
				_cam.look_at(boca + Vector3(0.0, -0.04, -0.03), Vector3.UP)
				quadros.append(await _foto(0))
		_desmontar(par)
		await process_frame
	_folha(quadros, 5, "posturas.png")


# --- estilos ----------------------------------------------------------------

func _estilos() -> void:
	var quadros: Array = []
	var S := Tragada.Estilo
	var F := Tragada.Fase
	var momentos := [
		[S.CURTA, F.PUXA, 0.5, 0],
		[S.FUNDA, F.SOLTA, 0.3, 20],
		[S.DUPLA, F.PUXA, 0.5, 0],
		[S.NARIZ, F.SOLTA, 0.3, 20],
		[S.DE_LADO, F.SOLTA, 0.3, 20],
		[S.TOSSE, F.SOLTA, 0.26, 16],
		[S.CINZA, F.PUXA, 0.1, 0],
		[S.FUNDA, F.PRENDE, 0.9, 0],
	]
	for m: Array in momentos:
		var par := _fumante(23)
		var c: Corpo = par[0]
		var b: Blunt = par[1]
		c.postura(Corpo.Postura.FUMANDO)
		_posar(c, b, m[0], _meio(m[0], m[1], m[2]))
		if m[1] == F.PUXA and m[0] != S.CINZA:
			_medir("estilo_" + Tragada.nome(m[0]), c, b)
		_enquadrar_rosto(c, 1.0, 1.35)
		quadros.append(await _foto(int(m[3])))
		print("[fumo] estilo=%s fase=%d alcance=%.2f baforada=%.2f" % [
			Tragada.nome(m[0]), c.fumo.fase(), c.fumo.alcance(), c.fumo.baforada()])
		_desmontar(par)
		await process_frame
	_folha(quadros, 4, "estilos.png")


# --- a blunt de perto -------------------------------------------------------

func _blunt_de_perto() -> void:
	var quadros: Array = []
	for pixel in [1, 0]:
		Blunt.estilo_forcado = pixel
		for estilo: Tragada.Estilo in [Tragada.Estilo.CURTA, Tragada.Estilo.CINZA]:
			var par := _fumante(31)
			var c: Corpo = par[0]
			var b: Blunt = par[1]
			c.postura(Corpo.Postura.FUMANDO)
			c.fumo.cinza = 0.9
			var t := _meio(estilo, Tragada.Fase.PUXA, 0.5 if estilo == Tragada.Estilo.CURTA else 0.9)
			_posar(c, b, estilo, t)
			var eixo := b.global_transform.basis.x
			var meio := b.global_position + eixo * 0.06
			var lado := eixo.cross(Vector3.UP).normalized()
			_cam.position = meio + lado * 0.16 + Vector3.UP * 0.05
			_cam.look_at(meio, Vector3.UP)
			quadros.append(await _foto(0))
			_desmontar(par)
			await process_frame
	Blunt.estilo_forcado = -1
	_folha(quadros, 4, "blunt.png")


# --- foto -------------------------------------------------------------------

## Com `quadros` > 0, espera um segundo e meio de relogio para a fumaca nascer:
## a baforada so existe andando, e 0,4 s depois de soltar ela ainda e um fio.
func _foto(quadros: int) -> Image:
	if quadros > 0:
		await create_timer(1.5).timeout
	for i in 3:
		await process_frame
	return _vp.get_texture().get_image()


func _folha(quadros: Array, colunas: int, nome: String) -> void:
	if _saida.is_empty():
		return
	var linhas := ceili(float(quadros.size()) / colunas)
	var folha := Image.create(QUADRO.x * colunas, QUADRO.y * linhas, false, Image.FORMAT_RGBA8)
	for i in quadros.size():
		var img: Image = quadros[i]
		img.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(img, Rect2i(Vector2i.ZERO, QUADRO),
			Vector2i((i % colunas) * QUADRO.x, (i / colunas) * QUADRO.y))
	DirAccess.make_dir_recursive_absolute(_saida)
	folha.save_png(_saida.path_join(nome))

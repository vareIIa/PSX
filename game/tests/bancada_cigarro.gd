## Bancada do cigarro da abertura (`Cigarro`) e da fumaca nova da casa (o FIO
## da brasa e a baforada).
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_cigarro.gd -- --saida=DIR
##
##   perto.png     o cigarro livre de perto: parado, puxando, e a bituca;
##                 MODERNO em cima, PS1 STYLE embaixo
##   corpo.png     o cigarro na mao de um corpo, de pe e encostado: repouso, na
##                 boca, soltando
##   blunt.png     a blunt da casa com a mesma fumaca: repouso e soltando
##
## Imprime `[cigarro] chave=valor`: labio_mm (da boca do filtro aos labios, na
## tragada) e raio_mm/comprimento_mm medidos na malha.
extends SceneTree

const QUADRO := Vector2i(400, 400)

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
	env.background_color = Color("1c1b22")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a8078")
	env.ambient_light_energy = 0.55
	ambiente.environment = env
	_mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 0.8
	luz.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-140.0), 0.0)
	_mundo.add_child(luz)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.near = 0.01
	_mundo.add_child(_cam)
	_cam.current = true

	if OS.get_cmdline_user_args().has("--ponto-fixo"):
		_ponto_fixo()
		quit()
		return
	await _perto()
	await _no_corpo()
	await _blunt()
	quit()


# --- de perto ---------------------------------------------------------------

func _perto() -> void:
	var quadros: Array = []
	for pixel in [1, 0]:
		Blunt.estilo_forcado = pixel
		for caso: Array in [[0.3, 0.0, 0.4], [0.3, 1.0, 0.5], [Cigarro.QUEIMA_BITUCA, 0.0, 0.1]]:
			var c := Cigarro.new()
			_mundo.add_child(c)
			c.montar(null, 7)
			c.consumo = caso[0]
			c.puxada = caso[1]
			c.cinza = caso[2]
			c.rotation = Vector3(0.0, 0.0, deg_to_rad(8.0))
			c.position = Vector3.ZERO
			var meio := Vector3(Cigarro.COMPRIMENTO_CIGARRO * 0.42, 0.0, 0.0)
			_cam.position = meio + Vector3(0.0, 0.035, 0.15)
			_cam.look_at(meio, Vector3.UP)
			if pixel == 1 and caso[1] == 0.0 and caso[0] < 0.5:
				_medir_malha(c)
			quadros.append(await _foto(1.6))
			c.queue_free()
			await process_frame
	Blunt.estilo_forcado = -1
	_folha(quadros, 3, "perto.png")


func _medir_malha(c: Cigarro) -> void:
	var papel := c.get_node("Peca/Papel") as MeshInstance3D
	var aabb := papel.mesh.get_aabb()
	print("[cigarro] comprimento_mm=%.1f diametro_mm=%.2f" % [aabb.size.x * 1000.0,
		aabb.size.y * 1000.0])


# --- no corpo ---------------------------------------------------------------

func _fumante(semente: int, postura: Corpo.Postura) -> Array:
	var c := Corpo.new()
	c.com_rosto = true
	_mundo.add_child(c)
	c.montar(Aparencia.de_ficha({"id": semente, "sexo": &"M", "idade": 27}))
	c.fumo = Tragada.new(semente)
	c.fumo.consumido = 0.3
	c.postura(postura)
	var g := Cigarro.new()
	_mundo.add_child(g)
	g.montar(c, semente)
	return [c, g]


func _posar(c: Corpo, g: Blunt, estilo: Tragada.Estilo, t: float) -> void:
	c.fumo.forcar(estilo, maxf(0.0, t - 1.0))
	var passo := 1.0 / 15.0
	var andou := 0.0
	while andou < minf(t, 1.0) - 0.0001:
		c.animar(0.0, passo)
		g.atualizar(passo)
		andou += passo
	c.animar(0.0, 0.0001)
	g.atualizar(0.0001)


func _meio(estilo: Tragada.Estilo, fase: Tragada.Fase, p: float = 0.5) -> float:
	var d: Array = Tragada.DURACOES[estilo]
	var t := 0.0
	for i in int(fase):
		t += float(d[i])
	# A espera nao tem duracao na tabela: meio segundo depois de soltar.
	return t + (float(d[fase]) * p if int(fase) < d.size() else 0.5)


func _enquadrar(c: Corpo, dist: float) -> void:
	var boca := c.boca_no_mundo().origin
	var alvo := boca + Vector3(0.05, -0.16, 0.0)
	_cam.position = alvo + Vector3(0.55, 0.1, -0.85).normalized() * dist
	_cam.look_at(alvo, Vector3.UP)


func _no_corpo() -> void:
	var quadros: Array = []
	var S := Tragada.Estilo
	var F := Tragada.Fase
	for postura: Corpo.Postura in [Corpo.Postura.FUMANDO, Corpo.Postura.ENCOSTADO]:
		for m: Array in [[S.CURTA, F.ESPERA, 0.3, 0.0], [S.FUNDA, F.PUXA, 0.5, 0.0],
				[S.FUNDA, F.SOLTA, 0.3, 1.6]]:
			var par := _fumante(11, postura)
			var c: Corpo = par[0]
			var g: Cigarro = par[1]
			_posar(c, g, m[0], _meio(m[0], m[1], m[2]))
			if m[1] == F.PUXA:
				var boca := c.boca_no_mundo()
				var labio := boca.origin + boca.basis * Vector3(0.0, 0.0, 0.004)
				print("[cigarro] %s labio_mm=%.1f" % [Corpo.Postura.keys()[postura],
					g.global_position.distance_to(labio) * 1000.0])
				# A mao na boca, no referencial da cabeca: para onde as costas
				# dela apontam (o eixo do cigarro rigido nos dedos) e onde esta
				# a pega contada dos labios.
				var mao := c.pega_no_mundo()
				var inv := boca.basis.inverse()
				print("[cigarro] %s eixo_mao=%s pega_do_labio=%s mira=%s" % [
					Corpo.Postura.keys()[postura],
					(inv * (mao.basis * g.dir_repouso).normalized()).snappedf(0.01),
					(inv * (mao.origin - labio)).snappedf(0.001),
					(inv * (g.global_transform.basis.x)).snappedf(0.01)])
			var bm := c.boca_no_mundo()
			var hb := bm.basis.inverse() * c.pega_no_mundo().basis
			var cb := c.global_transform.basis.inverse() * c.pega_no_mundo().basis
			print("[cigarro] base %s fase=%d cabeca x=%s y=%s z=%s | corpo x=%s y=%s z=%s" % [
				Corpo.Postura.keys()[postura], c.fumo.fase(),
				hb.x.snappedf(0.01), hb.y.snappedf(0.01), hb.z.snappedf(0.01),
				cb.x.snappedf(0.01), cb.y.snappedf(0.01), cb.z.snappedf(0.01)])
			_enquadrar(c, 1.25)
			quadros.append(await _foto(float(m[3])))
			if m[1] == F.PUXA:
				# De perfil e de perto: o filtro entra na boca?
				var boca := c.boca_no_mundo().origin
				_cam.position = boca + Vector3(0.30, 0.02, -0.06)
				_cam.look_at(boca + Vector3(0.0, -0.03, -0.03), Vector3.UP)
				quadros.append(await _foto(0.0))
			(par[0] as Node).queue_free()
			(par[1] as Node).queue_free()
			await process_frame
	_folha(quadros, 4, "corpo.png")


## Procura o `alvo_da_pega` em que o cigarro rigido nos dedos (eixo da mao
## vezes `dir_repouso`) poe a boca do filtro nos labios: o alvo muda o IK, o IK
## muda o giro da mao, e o giro muda o eixo. Imprime o alvo a cada volta.
func _ponto_fixo() -> void:
	var par := _fumante(11, Corpo.Postura.FUMANDO)
	var c: Corpo = par[0]
	var g: Cigarro = par[1]
	for volta in 8:
		_posar(c, g, Tragada.Estilo.FUNDA, _meio(Tragada.Estilo.FUNDA, Tragada.Fase.PUXA, 0.5))
		var boca := c.boca_no_mundo()
		var mao := c.pega_no_mundo()
		var eixo := (boca.basis.inverse() * (mao.basis * g.dir_repouso)).normalized()
		var alvo := eixo * (g.pega + 0.004)
		print("[cigarro] volta %d eixo=%s alvo=%s" % [volta, eixo.snappedf(0.01), alvo.snappedf(0.0005)])
		c.alvo_da_pega = alvo


# --- a blunt ----------------------------------------------------------------

func _blunt() -> void:
	var quadros: Array = []
	var S := Tragada.Estilo
	var F := Tragada.Fase
	for m: Array in [[S.CURTA, F.ESPERA, 0.3, 2.0], [S.FUNDA, F.PUXA, 0.6, 0.0],
			[S.FUNDA, F.SOLTA, 0.25, 0.9], [S.DE_LADO, F.SOLTA, 0.3, 1.2]]:
		var c := Corpo.new()
		c.com_rosto = true
		_mundo.add_child(c)
		c.montar(Aparencia.de_ficha({"id": 23, "sexo": &"M", "idade": 27}))
		c.fumo = Tragada.new(23)
		c.postura(Corpo.Postura.FUMANDO)
		var b := Blunt.new()
		_mundo.add_child(b)
		b.montar(c, 23)
		_posar(c, b, m[0], _meio(m[0], m[1], m[2]))
		_enquadrar(c, 1.4)
		quadros.append(await _foto(float(m[3]), c, b))
		c.queue_free()
		b.queue_free()
		await process_frame
	_folha(quadros, 4, "blunt.png")


# --- foto -------------------------------------------------------------------

## `espera` segundos de relogio antes da foto, com o corpo e o fumo andando (a
## fumaca so existe andando).
func _foto(espera: float, c: Corpo = null, _g: Blunt = null) -> Image:
	var t := 0.0
	while t < espera:
		await process_frame
		var d := 1.0 / 60.0
		t += d
		# A blunt anda sozinha (`_process`); o corpo nao.
		if c != null:
			c.animar(0.0, d)
	for i in 3:
		await process_frame
	return _vp.get_texture().get_image()


func _folha(quadros: Array, colunas: int, nome: String) -> void:
	if _saida.is_empty() or quadros.is_empty():
		return
	var linhas := int(ceil(float(quadros.size()) / colunas))
	var folha := Image.create(QUADRO.x * colunas, QUADRO.y * linhas, false, Image.FORMAT_RGBA8)
	for i in quadros.size():
		var q: Image = quadros[i]
		q.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(q, Rect2i(Vector2i.ZERO, QUADRO),
			Vector2i((i % colunas) * QUADRO.x, (i / colunas) * QUADRO.y))
	DirAccess.make_dir_recursive_absolute(_saida)
	folha.save_png(_saida.path_join(nome))
	print("[cigarro] folha %s" % _saida.path_join(nome))

## Modo foto: o criterio A29 do PLANO_AAA_4K.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_foto.gd
##     (SEM --headless: sem janela nao ha profundidade de campo)
##     --saida=DIR grava as fotos da bancada
##
## A cena e de bancada e nao a cidade: duas caixas claras contra fundo escuro, a
## 3 m e a 14 m. Silhueta contra fundo e a unica borda que se mede sem depender
## de textura, de luz e de material — e o que se quer saber aqui e o que o
## DESFOQUE faz com ela.
##
## O que cada medida faz
## ---------------------
## A29a  **Camera livre.** Entrar troca a camera corrente pela da foto, pausa o
##       jogo, e andar move a camera da foto sem mexer na do jogador.
## A29b  **Sem HUD.** Toda camada do grupo `hud` some na entrada e volta na
##       saida. Pelo grupo, que e como a `Cinematica` ja faz.
## A29c  **Profundidade de campo.** Foco na caixa de perto: a borda da caixa de
##       LONGE tem de amolecer, e a de perto tem de continuar dura. Medir so a
##       de longe nao serviria — uma foto inteira borrada passaria.
## A29d  **Exposicao.** Duas paradas para cima clareiam a cena.
## A29e  **Filtro.** Preto e branco zera a saturacao; o quente aumenta.
## A29f  **Foto em 4K.** O PNG gravado tem 3840x2160, mesmo com a janela em
##       1280x720 — a foto e renderizada a parte, e nao capturada da tela.
## A29g  **A foto tem o brilho da tela.** O viewport da foto nasce agora e a
##       exposicao automatica nao roda nele: sem conserto, a mesma vista saiu
##       com 9 de brilho na viela e 138 no interior, contra 43 da janela nas
##       duas. E o criterio que guarda o `_assentar` do `ModoFoto`.
extends SceneTree

## A caixa de perto fica no EIXO da camera: o foco automatico e um raio pelo
## centro da tela, e com ela de lado o raio saia pelo vao entre as duas. A de
## longe fica bem afastada de lado porque, no eixo, a de perto a TAPA — e a
## medida da borda dela dava zero, que e o que uma caixa escondida mede.
const PERTO := Vector3(0.0, 0.0, -4.0)
const LONGE := Vector3(4.5, 0.0, -14.0)

## O autoload, pelo caminho.
##
## `Foto` como identificador nao resolve num script de SceneTree: o script e
## compilado antes de a lista de autoload existir, e o compilador so enxerga
## nome de CLASSE (e por isso que `UiEstilo` e `EstiloVisual` funcionam nas
## outras bancadas — os dois tem `class_name`). O no esta em /root assim que o
## primeiro quadro comeca.
var _modo: Node
var _raiz: Node3D
var _camera: Camera3D
var _hud: CanvasLayer
var _saida := ""
var _passou := 0
var _total := 0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_medir()


func _montar() -> Node3D:
	_raiz = Node3D.new()
	var ambiente := WorldEnvironment.new()
	ambiente.add_to_group(&"fog_controller")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = env
	var attr := CameraAttributesPractical.new()
	# Exposicao automatica LIGADA, como no jogo. E o que faz a medida A29g valer
	# alguma coisa: com ela desligada, a foto e a tela combinariam por acidente.
	attr.auto_exposure_enabled = true
	attr.auto_exposure_scale = 0.4
	ambiente.camera_attributes = attr
	_raiz.add_child(ambiente)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	sol.light_energy = 1.4
	_raiz.add_child(sol)

	for pos: Vector3 in [PERTO, LONGE]:
		_raiz.add_child(_caixa(pos))

	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 1.0, 0.0)
	_camera.fov = 60.0
	_camera.current = true
	_raiz.add_child(_camera)
	return _raiz


## Caixa clara com corpo estatico: o corpo existe para o foco automatico, que
## acha a distancia por raio.
func _caixa(pos: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.position = pos + Vector3(0.0, 1.0, 0.0)
	var malha := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(1.4, 2.0, 1.4)
	malha.mesh = caixa
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.84, 0.8)
	mat.roughness = 0.9
	malha.material_override = mat
	corpo.add_child(malha)
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = caixa.size
	forma.shape = box
	corpo.add_child(forma)
	return corpo


func _medir() -> void:
	root.add_child(_montar())
	_hud = CanvasLayer.new()
	_hud.add_to_group(&"hud")
	var marca := ColorRect.new()
	marca.color = Color(1, 0, 0)
	marca.size = Vector2(40, 8)
	_hud.add_child(marca)
	root.add_child(_hud)
	await process_frame
	# Depois dos autoloads, e nao antes: o `EstiloVisual` escreve o modo de
	# escala no _ready dele, que roda depois do _init desta bancada. Escrito
	# antes, ficava valendo o dele, `unproject_position` respondia em 480x270 e a
	# medida procurava a borda da caixa a 400 px de onde ela estava.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await process_frame
	_modo = root.get_node_or_null(^"/root/Foto")
	if _modo == null:
		print("[X ] o autoload Foto nao existe")
		quit(1)
		return
	await process_frame

	print("\n=== A29: modo foto ===\n")
	await _medir_camera()
	await _medir_profundidade()
	await _medir_exposicao()
	await _medir_filtro()
	await _medir_arquivo()
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


func _medir_camera() -> void:
	var antes := _camera.global_position
	_modo.call(&"entrar")
	await process_frame
	var cam := _modo.call(&"camera") as Camera3D
	var virou: bool = cam != null and root.get_camera_3d() == cam
	var pausado: bool = paused
	var foco: float = _modo.call(&"foco")
	if cam != null:
		cam.global_position += Vector3(0.0, 0.0, -2.0)
	await process_frame
	var andou := cam != null and cam.global_position.distance_to(antes) > 1.5
	var jogador_parado := _camera.global_position.distance_to(antes) < 0.001
	_conta("A29a camera livre", virou and pausado and andou and jogador_parado,
		"a camera da foto assumiu, o jogo pausou, ela andou %.1f m e a do jogador ficou"
			% (cam.global_position.distance_to(antes) if cam != null else 0.0))
	# O foco automatico da entrada tem de achar a caixa de perto (3 m de fundo,
	# menos a metade da caixa: 2,3 m).
	_conta("A29a foco automatico", absf(foco - 3.3) < 0.5,
		"apontando para a caixa de 4 m, o foco entrou em %.2f m" % foco)
	_conta("A29b sem HUD", not _hud.visible,
		"a camada de HUD sumiu ao entrar")
	if cam != null:
		cam.global_position = antes


func _medir_profundidade() -> void:
	_modo.call(&"por_foco", 3.3)
	_modo.call(&"por_diafragma", 0)
	await process_frame
	var img_nitida := await _foto("foto_sem_desfoque")
	_modo.call(&"por_diafragma", 4)
	await process_frame
	var img_borrada := await _foto("foto_com_desfoque")
	var perto_a := _dureza(img_nitida, PERTO)
	var perto_b := _dureza(img_borrada, PERTO)
	var longe_a := _dureza(img_nitida, LONGE)
	var longe_b := _dureza(img_borrada, LONGE)
	var amoleceu := longe_a / maxf(longe_b, 0.0001)
	var ficou := perto_b / maxf(perto_a, 0.0001)
	# 1,8x, e o teto medido e 2x: o raio do desfoque do Godot satura, e subir a
	# abertura de 0,2 para 0,35 mudou a dureza da borda de longe em nada (1,97
	# para 1,92). Com o foco DESLIGADO a mesma medida da 1,0x cravado, entao o
	# criterio continua reprovando quem nao tiver profundidade de campo.
	_conta("A29c profundidade de campo", amoleceu >= 1.8 and ficou >= 0.7,
		"a caixa de 14 m fica %.1fx mais mole (%.3f -> %.3f) e a de 4 m guarda %.0f%% da borda"
			% [amoleceu, longe_a, longe_b, ficou * 100.0])
	_modo.call(&"por_diafragma", 2)


func _medir_exposicao() -> void:
	_modo.call(&"por_parada", 3)
	await process_frame
	var normal := _media(await _foto("foto_exposicao_0"))
	_modo.call(&"por_parada", 6)
	await process_frame
	var clara := _media(await _foto("foto_exposicao_2"))
	var ganho := clara / maxf(normal, 0.0001)
	# 1,3x, e nao 4x: duas paradas dobram a luz duas vezes NO SENSOR, e o tonemap
	# filmico comprime o alto da curva — e ele que faz a foto parecer foto. O que
	# se mede aqui e se o controle chega na imagem, nao a matematica do sensor.
	_conta("A29d exposicao", ganho >= 1.3,
		"duas paradas para cima clareiam %.2fx (%.3f -> %.3f)" % [ganho, normal, clara])
	_modo.call(&"por_parada", 3)


func _medir_filtro() -> void:
	_modo.call(&"por_filtro_nome", "nenhum")
	await process_frame
	var cor := _saturacao(await _foto("foto_filtro_nenhum"))
	_modo.call(&"por_filtro_nome", "preto e branco")
	await process_frame
	var pb := _saturacao(await _foto("foto_filtro_pb"))
	_modo.call(&"por_filtro_nome", "quente")
	await process_frame
	var quente := _saturacao(await _foto("foto_filtro_quente"))
	_conta("A29e filtro", pb < 0.01 and quente > cor,
		"saturacao %.3f sem filtro, %.3f no preto e branco, %.3f no quente"
			% [cor, pb, quente])
	_modo.call(&"por_filtro_nome", "nenhum")


func _medir_arquivo() -> void:
	var caminho: String = await _modo.call(&"fotografar")
	var ok := not caminho.is_empty()
	var larg := 0
	var alt := 0
	if ok:
		var img := Image.load_from_file(caminho)
		if img != null:
			larg = img.get_width()
			alt = img.get_height()
	_conta("A29f foto em 4K", larg == 3840 and alt == 2160,
		"gravou %dx%d com a janela em %dx%d" % [larg, alt, root.size.x, root.size.y])
	if ok:
		var foto := Image.load_from_file(caminho)
		var tela := await _foto("foto_tela")
		var b_foto := _media(foto)
		var b_tela := _media(tela)
		var razao := b_foto / maxf(b_tela, 0.0001)
		# +-40%: a foto nao leva o pos-processamento, e vinheta mais linha de
		# varredura tiram um quinto do brilho da janela. O que se persegue aqui e
		# a ordem de grandeza — o defeito media 4x para baixo e 3x para cima.
		_conta("A29g brilho da foto", razao > 0.6 and razao < 1.4,
			"a foto tem %.2fx o brilho da tela (%.3f contra %.3f)"
				% [razao, b_foto, b_tela])
	_modo.call(&"sair")
	await process_frame
	_conta("A29b HUD de volta", _hud.visible, "a camada de HUD voltou ao sair")


func _foto(nome: String) -> Image:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	if _saida != "":
		img.save_png("%s/%s.png" % [_saida, nome])
	return img


## Dureza da borda vertical da caixa: o maior degrau de luminancia entre pixels
## vizinhos na linha que passa pelo meio dela.
func _dureza(img: Image, alvo: Vector3) -> float:
	var faixa := _faixa(img, alvo)
	var y := faixa.y
	var pior := 0.0
	for x in range(maxi(1, faixa.x - 60), mini(img.get_width() - 1, faixa.x + 60)):
		var a := _lum(img.get_pixel(x - 1, y))
		var b := _lum(img.get_pixel(x + 1, y))
		pior = maxf(pior, absf(b - a))
	return pior


## Onde a borda esquerda da caixa cai na tela, e em que linha medir.
func _faixa(img: Image, alvo: Vector3) -> Vector2i:
	var cam := _modo.call(&"camera") as Camera3D
	if cam == null:
		cam = _camera
	var canto := alvo + Vector3(-0.7, 1.0, 0.0)
	var p := cam.unproject_position(canto)
	return Vector2i(clampi(int(p.x), 1, img.get_width() - 2),
		clampi(int(p.y), 1, img.get_height() - 2))


func _media(img: Image) -> float:
	var soma := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			soma += _lum(img.get_pixel(x, y))
			n += 1
	return soma / maxf(float(n), 1.0)


## Saturacao media dos pixels que tem luz: num quadro quase preto, o fundo
## domina a media e qualquer filtro pareceria nao fazer nada.
func _saturacao(img: Image) -> float:
	var soma := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			var maior := maxf(c.r, maxf(c.g, c.b))
			if maior < 0.12:
				continue
			var menor := minf(c.r, minf(c.g, c.b))
			soma += (maior - menor) / maior
			n += 1
	return soma / maxf(float(n), 1.0)


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

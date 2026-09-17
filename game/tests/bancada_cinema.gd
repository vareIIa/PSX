## Cena cortada: o criterio A30 do PLANO_AAA_4K.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_cinema.gd
##     (SEM --headless: tarja e desfoque so existem com janela)
##     --saida=DIR grava as fotos
##
## O que cada medida faz
## ---------------------
## A30a  **Formato de cinema.** As tarjas sao medidas NA IMAGEM, contando linha
##       preta de cima e de baixo, e o que se confere e a proporcao que sobra.
##       Conferir a constante `TARJA` provaria so que a constante existe.
## A30b  **Legenda na area segura.** Tres frases, da curta a longa demais: a
##       caixa de texto tem de caber entre as tarjas e respeitar a margem
##       lateral. Uma legenda de tres linhas que sobe para debaixo da tarja e o
##       jeito classico de perder a primeira linha.
## A30c  **Tempo de leitura.** A duracao pedida pelo roteiro e um piso, nao uma
##       ordem: uma frase longa com duracao curta tem de ficar o tempo de ser
##       lida.
## A30d  **Profundidade de campo no plano marcado.** Foco no sujeito de perto: a
##       caixa de longe amolece e a de perto continua dura. Mesma regua da
##       bancada do modo foto.
extends SceneTree

const PERTO := Vector3(0.0, 0.0, -4.0)
const LONGE := Vector3(4.5, 0.0, -14.0)
## O formato que a cena cortada promete.
const FORMATO := 2.35
const FOLGA_FORMATO := 0.03

const CURTA := "Acorda."
const MEDIA := "Va ate a casa da fumaca, na esquina da praca."
const LONGA := "Foi assim que eu cheguei nesta cidade, sem documento, " + \
	"sem dinheiro e com o endereco de um homem que eu nunca tinha visto."

var _cinema: Node
var _raiz: Node3D
var _camera: Camera3D
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
	attr.auto_exposure_enabled = false
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
	_camera.current = true
	_raiz.add_child(_camera)
	return _raiz


func _caixa(pos: Vector3) -> MeshInstance3D:
	var malha := MeshInstance3D.new()
	malha.position = pos + Vector3(0.0, 1.0, 0.0)
	var caixa := BoxMesh.new()
	caixa.size = Vector3(1.4, 2.0, 1.4)
	malha.mesh = caixa
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.84, 0.8)
	mat.roughness = 0.9
	malha.material_override = mat
	return malha


func _medir() -> void:
	root.add_child(_montar())
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await process_frame
	_cinema = root.get_node_or_null(^"/root/Cinema")
	if _cinema == null:
		print("[X ] o autoload Cinema nao existe")
		quit(1)
		return
	print("\n=== A30: cena cortada ===\n")
	await _medir_formato()
	await _medir_legenda()
	_medir_leitura()
	await _medir_profundidade()
	_cinema.call(&"encerrar")
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


func _medir_formato() -> void:
	var antes := await _foto("cinema_sem_tarja")
	_cinema.call(&"iniciar", true)
	await process_frame
	var img := await _foto("cinema_com_tarja")
	var tarja_antes := _tarja_medida(antes)
	var tarja := _tarja_medida(img)
	var util := 270.0 - float(tarja) * 2.0
	var formato := 480.0 / maxf(util, 1.0)
	_conta("A30a formato de cinema", absf(formato - FORMATO) <= FOLGA_FORMATO and tarja_antes == 0,
		"a tarja passa de %d para %d px de cada lado, deixando %.0f linhas de imagem: %.3f:1 (pedido %.2f:1)"
			% [tarja_antes, tarja, util, formato, FORMATO])


## Altura da tarja preta, contada NA IMAGEM.
##
## Preto de tarja e preto puro; o fundo da bancada e 0,02, que ja e outra coisa.
## Contar por pixel, e nao ler a constante, e o que faz a medida valer.
##
## A coluna e x=200 e nao o meio da janela: com o esticamento desligado, a
## interface e desenhada 1:1 no canto de 480x270 da janela, entao a tarja so
## existe ate x=480. Medir no meio de uma janela de 1280 mediria o 3D.
func _tarja_medida(img: Image) -> int:
	var x := 200
	var n := 0
	for y in 135:
		if _lum(img.get_pixel(x, y)) > 0.004:
			break
		n += 1
	return n


func _medir_legenda() -> void:
	var rotulo := _achar_legenda()
	if rotulo == null:
		_conta("A30b legenda na area segura", false, "nao achei o rotulo da legenda")
		return
	var tarja := float(_cinema.get(&"TARJA"))
	var pior := ""
	var ok := true
	for texto: String in [CURTA, MEDIA, LONGA]:
		_cinema.call(&"legenda", texto, 3.0)
		await process_frame
		await process_frame
		var caixa := Rect2(rotulo.position, rotulo.size)
		var alto := rotulo.get_line_count() * UiEstilo.altura_da_linha(rotulo.get_theme_font(&"font"))
		var topo := caixa.position.y + caixa.size.y - alto
		var dentro := topo >= tarja and caixa.position.y + caixa.size.y <= 270.0 - tarja \
			and caixa.position.x >= UiEstilo.MARGEM \
			and caixa.position.x + caixa.size.x <= 480.0 - UiEstilo.MARGEM
		if not dentro:
			ok = false
			pior = "\"%s...\" em %d linhas, topo em %.0f (tarja ate %.0f), base em %.0f" % [
				texto.substr(0, 18), rotulo.get_line_count(), topo, tarja,
				caixa.position.y + caixa.size.y]
	if _saida != "":
		(await _foto("cinema_legenda")).save_png("%s/cinema_legenda.png" % _saida)
	_conta("A30b legenda na area segura", ok,
		"as tres frases cabem entre as tarjas e dentro da margem" if ok else pior)
	_cinema.call(&"legenda", "", 0.0)


func _achar_legenda() -> Label:
	for n: Node in _cinema.find_children("*", "Label", true, false):
		var r := n as Label
		if r != null and r.name == "Legenda":
			return r
	return null


func _medir_leitura() -> void:
	var curta: float = _cinema.call(&"tempo_de_leitura", CURTA)
	var longa: float = _cinema.call(&"tempo_de_leitura", LONGA)
	# 14 caracteres por segundo, mais o tempo de aparecer e o de sumir.
	var esperado := float(LONGA.length()) / 14.0
	_conta("A30c tempo de leitura", curta >= 1.8 and longa >= esperado,
		"\"%s\" pede %.1f s e a frase de %d caracteres pede %.1f s (leitura crua: %.1f s)"
			% [CURTA, curta, LONGA.length(), longa, esperado])


func _medir_profundidade() -> void:
	_cinema.call(&"enquadrar", Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -4.0), 60.0)
	_cinema.call(&"sem_profundidade")
	await process_frame
	var nitida := await _foto("cinema_sem_foco")
	_cinema.call(&"profundidade", 3.3, 0.2, 2.0)
	await process_frame
	var borrada := await _foto("cinema_com_foco")
	var perto_a := _dureza(nitida, PERTO)
	var perto_b := _dureza(borrada, PERTO)
	var longe_a := _dureza(nitida, LONGE)
	var longe_b := _dureza(borrada, LONGE)
	var amoleceu := longe_a / maxf(longe_b, 0.0001)
	var ficou := perto_b / maxf(perto_a, 0.0001)
	# 1,8x, e o teto medido e 2x: o raio do desfoque do Godot satura, e subir a
	# abertura de 0,2 para 0,35 mudou a dureza da borda de longe em nada (1,97
	# para 1,92). Com o foco DESLIGADO a mesma medida da 1,0x cravado, entao o
	# criterio continua reprovando quem nao tiver profundidade de campo.
	_conta("A30d profundidade de campo", amoleceu >= 1.8 and ficou >= 0.7,
		"a caixa de 14 m fica %.1fx mais mole (%.3f -> %.3f) e o sujeito guarda %.0f%% da borda"
			% [amoleceu, longe_a, longe_b, ficou * 100.0])


func _foto(nome: String) -> Image:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	if _saida != "":
		img.save_png("%s/%s.png" % [_saida, nome])
	return img


func _dureza(img: Image, alvo: Vector3) -> float:
	var cam := root.get_camera_3d()
	if cam == null:
		return 0.0
	var p := cam.unproject_position(alvo + Vector3(-0.7, 1.0, 0.0))
	var x0 := clampi(int(p.x), 1, img.get_width() - 2)
	var y := clampi(int(p.y), 1, img.get_height() - 2)
	var pior := 0.0
	for x in range(maxi(1, x0 - 60), mini(img.get_width() - 1, x0 + 60)):
		pior = maxf(pior, absf(_lum(img.get_pixel(x + 1, y)) - _lum(img.get_pixel(x - 1, y))))
	return pior


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

## Autoload. Modo foto: camera livre, foco, exposicao, filtro e PNG em 4K.
##
##     F10 entra e sai. Dentro: WASD/QE anda, mouse olha, Shift acelera,
##     F foca no que esta no centro, [ e ] abrem o diafragma, - e + a
##     exposicao, C troca o filtro, Enter tira a foto.
##
## O criterio A29 do PLANO_AAA_4K.
##
## Por que a foto nao e a tela
## ---------------------------
## Um print da tela sai no tamanho da janela, com HUD, e com o pos-processamento
## de 480x270 carimbado por cima. A foto e uma renderizacao PROPRIA, num
## SubViewport de 3840x2160 com o mesmo mundo e uma copia da camera: sai em 4K
## mesmo numa janela de 1280x720, sem nenhuma camada de interface, porque
## SubViewport nenhum tem canvas do jogo dentro.
##
## Sem o pos, e de proposito: grao e dither sao desenhados na grade de 480x270, e
## em 4K eles viram um carimbo de outra resolucao em cima da imagem. O que a foto
## guarda e a cena — luz, material, nevoa e profundidade de campo.
##
## Por que o ajuste vive na camera, e nao no mundo
## -----------------------------------------------
## Foco e exposicao sao do `CameraAttributesPractical`, e filtro e do
## `Environment`. Os dois sao DUPLICADOS na entrada e pendurados na camera da
## foto (`Camera3D.attributes` e `Camera3D.environment` vencem os do mundo). O
## ambiente do nivel nao e tocado, entao sair do modo foto nao tem o que
## restaurar, e um bug aqui nao pode deixar a cidade com cara de foto.
##
## O jogo fica pausado e este no roda assim mesmo (`PROCESS_MODE_ALWAYS`): foto
## de jogo com chuva andando sai borrada de movimento de gente, e enquadrar
## alguem que continua andando e impossivel.
class_name ModoFoto
extends CanvasLayer

## Acima do pos, como a barra de vida: e informacao do jogo, nao da imagem. Nada
## disto entra na foto, que vem de outro viewport.
const CAMADA := 160

const TAMANHO_FOTO := Vector2i(3840, 2160)
const PASTA := "user://fotos"

## Rodadas de acerto de exposicao, e quantos quadros cada uma desenha antes de
## ler a imagem. Ver `_assentar`.
const RODADAS := 4
const QUADROS_POR_LEITURA := 4
## Quanto o brilho da foto pode ficar longe do da tela, em fracao.
const TOLERANCIA := 0.05
## Quanto o multiplicador pode andar numa rodada so.
const PASSO_MAX := 8.0

## Metros por segundo da camera livre, e o multiplicador do Shift.
const VELOCIDADE := 6.0
const CORRIDA := 4.0
const SENSIBILIDADE := 0.0022

## Diafragma: quanto o desfoque cresce fora do foco. O passo e multiplicativo
## porque o olho le desfoque em razao, nao em diferenca.
const DIAFRAGMA := [0.0, 0.03, 0.06, 0.12, 0.2]
const DIAFRAGMA_PADRAO := 2
## Onde a transicao do foco comeca a ficar mole, em metros.
const TRANSICAO := 2.0

## Passos de exposicao, em paradas de camera (cada uma dobra a luz).
const PARADAS := [-2.0, -1.0, -0.5, 0.0, 0.5, 1.0, 2.0]
const PARADA_PADRAO := 3

enum Filtro { NENHUM, PRETO_E_BRANCO, QUENTE, FRIO, CONTRASTE }

const FILTROS := {
	Filtro.NENHUM: "nenhum",
	Filtro.PRETO_E_BRANCO: "preto e branco",
	Filtro.QUENTE: "quente",
	Filtro.FRIO: "frio",
	Filtro.CONTRASTE: "contraste",
}

signal entrou()
signal saiu()
signal fotografou(caminho: String)

var ativo: bool = false

var _camera: Camera3D
var _anterior: Camera3D
var _attr: CameraAttributesPractical
var _env: Environment
var _foco: float = 8.0
var _diafragma: int = DIAFRAGMA_PADRAO
var _parada: int = PARADA_PADRAO
var _filtro: int = Filtro.NENHUM
var _giro := Vector2.ZERO
var _escondidos: Array[Node] = []
var _mouse_antes: int = Input.MOUSE_MODE_VISIBLE
var _barra: Label
var _pausa_antes: bool = false
## Exposicao do mundo na entrada; as paradas multiplicam ela.
var _exposicao_base: float = -1.0


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_montar()


func _montar() -> void:
	_barra = Label.new()
	_barra.name = "Barra"
	_barra.position = Vector2(UiEstilo.MARGEM, UiEstilo.MARGEM)
	_barra.add_theme_color_override(&"font_color", Color(0.98, 0.98, 0.96))
	_barra.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	_barra.add_theme_constant_override(&"shadow_offset_x", 1)
	_barra.add_theme_constant_override(&"shadow_offset_y", 1)
	UiEstilo.aplicar(_barra, load(UiEstilo.FONTE_P) as Font)
	add_child(_barra)


func alternar() -> void:
	if ativo:
		sair()
	else:
		entrar()


func entrar() -> void:
	if ativo:
		return
	var atual := get_viewport().get_camera_3d()
	if atual == null:
		push_warning("ModoFoto: nao ha camera 3D para copiar")
		return
	_anterior = atual
	_camera = Camera3D.new()
	_camera.name = "CameraFoto"
	_camera.fov = atual.fov
	_camera.near = atual.near
	_camera.far = maxf(atual.far, 600.0)
	# `current_scene` e nulo num script de bancada (`--script`), e tambem entre
	# uma troca de cena e outra. Sem este `else` a camera nascia fora da arvore,
	# o modo foto abortava calado e o que aparecia era a cena de sempre.
	var cena: Node = get_tree().current_scene
	if cena == null or not cena.is_inside_tree():
		cena = get_tree().root
	cena.add_child(_camera)
	_camera.global_transform = atual.global_transform
	var e := _camera.global_rotation
	_giro = Vector2(e.y, e.x)
	_attr = _atributos_do_mundo()
	_env = _ambiente_do_mundo()
	_camera.attributes = _attr
	_camera.environment = _env
	_camera.current = true
	_foco = _distancia_do_centro()
	_aplicar()

	_esconder_hud(true)
	_mouse_antes = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pausa_antes = get_tree().paused
	get_tree().paused = true
	ativo = true
	visible = true
	entrou.emit()


func sair() -> void:
	if not ativo:
		return
	ativo = false
	visible = false
	get_tree().paused = _pausa_antes
	Input.mouse_mode = _mouse_antes
	_esconder_hud(false)
	if _anterior != null and is_instance_valid(_anterior):
		_anterior.current = true
	_anterior = null
	if _camera != null and is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	_attr = null
	_env = null
	saiu.emit()


## Copia dos atributos do mundo, com a profundidade de campo ligada.
##
## Copia, e nao os do mundo: a exposicao automatica do jogo tem piso e teto
## calibrados (ver a memoria do piso de exposicao), e a foto mexe na exposicao
## por paradas — sem duplicar, um passo aqui mudaria a noite do jogo inteiro.
func _atributos_do_mundo() -> CameraAttributesPractical:
	var mundo := get_tree().get_first_node_in_group(&"fog_controller") as WorldEnvironment
	var base: CameraAttributes = null
	if mundo != null:
		base = mundo.camera_attributes
	if _anterior != null and _anterior.attributes != null:
		base = _anterior.attributes
	var a: CameraAttributesPractical = null
	if base is CameraAttributesPractical:
		a = (base as CameraAttributesPractical).duplicate() as CameraAttributesPractical
	else:
		a = CameraAttributesPractical.new()
		if base != null:
			a.exposure_multiplier = base.exposure_multiplier
			a.auto_exposure_enabled = base.auto_exposure_enabled
	return a


## Copia dos atributos com a exposicao no BRACO.
##
## A exposicao automatica nao roda no viewport da foto — e isto foi medido, nao
## suposto. Com ela ligada, o brilho da foto ficou cravado no mesmo valor por
## 120 quadros; escrevendo os atributos direto na camera, passou a andar 1% a
## cada oito quadros, e acelerar o olho eletronico nao mudou nada. Enquanto a
## janela do jogo entregava 43 de brilho medio nas quatro paradas (que e a
## exposicao automatica dela fazendo o trabalho), a foto entregava 9 na viela e
## 138 no interior: sensibilidade fixa.
##
## Entao a foto mede em vez de confiar. Ela liga a exposicao MANUAL e procura o
## multiplicador que faz a imagem dela ter o brilho da tela — que e, afinal, a
## promessa do modo foto: sai o que se esta vendo. Ver `_assentar`.
func _para_foto(base: CameraAttributes) -> CameraAttributes:
	var copia: CameraAttributes = null
	if base != null:
		copia = base.duplicate() as CameraAttributes
	if copia == null:
		copia = CameraAttributesPractical.new()
	copia.auto_exposure_enabled = false
	return copia


## Os atributos que o jogo esta usando agora: a `Lente` os escreve no
## WorldEnvironment, e a foto quer exatamente a mesma lente.
func _atributos_do_jogo() -> CameraAttributes:
	var mundo := get_tree().get_first_node_in_group(&"fog_controller") as WorldEnvironment
	if mundo != null and mundo.camera_attributes != null:
		return mundo.camera_attributes
	return null


func _ambiente_do_mundo() -> Environment:
	var mundo := get_tree().get_first_node_in_group(&"fog_controller") as WorldEnvironment
	var base: Environment = null
	if mundo != null:
		base = mundo.environment
	if base == null:
		base = get_viewport().find_world_3d().environment
	if base == null:
		return Environment.new()
	return base.duplicate() as Environment


## Escreve foco, diafragma, exposicao e filtro na camera da foto.
func _aplicar() -> void:
	if _attr == null or _env == null:
		return
	var abertura: float = DIAFRAGMA[_diafragma]
	_attr.dof_blur_amount = abertura
	_attr.dof_blur_far_enabled = abertura > 0.0
	_attr.dof_blur_far_distance = _foco
	_attr.dof_blur_far_transition = TRANSICAO
	_attr.dof_blur_near_enabled = abertura > 0.0
	_attr.dof_blur_near_distance = maxf(0.1, _foco - TRANSICAO)
	_attr.dof_blur_near_transition = TRANSICAO
	_attr.exposure_multiplier = _atributos_base_exposicao() * pow(2.0, PARADAS[_parada])
	_env.adjustment_enabled = _filtro != Filtro.NENHUM
	_env.adjustment_saturation = 1.0
	_env.adjustment_contrast = 1.0
	_env.adjustment_brightness = 1.0
	match _filtro:
		Filtro.PRETO_E_BRANCO:
			_env.adjustment_saturation = 0.0
			_env.adjustment_contrast = 1.08
		Filtro.QUENTE:
			_env.adjustment_saturation = 1.25
			_env.adjustment_brightness = 1.04
		Filtro.FRIO:
			_env.adjustment_saturation = 0.78
			_env.adjustment_brightness = 0.97
		Filtro.CONTRASTE:
			_env.adjustment_contrast = 1.35
			_env.adjustment_saturation = 1.1
	_escrever_barra()


func _atributos_base_exposicao() -> float:
	if _exposicao_base < 0.0:
		_exposicao_base = _attr.exposure_multiplier if _attr != null else 1.0
	return _exposicao_base


func _escrever_barra() -> void:
	if _barra == null:
		return
	_barra.text = "FOTO   foco %.1f m   diafragma %d/%d   exposicao %+.1f   filtro %s" % [
		_foco, _diafragma, DIAFRAGMA.size() - 1, PARADAS[_parada], FILTROS[_filtro]]


func _esconder_hud(esconder: bool) -> void:
	if esconder:
		_escondidos.clear()
		for no: Node in get_tree().get_nodes_in_group(&"hud"):
			var item := no as CanvasItem
			if item != null and item.visible:
				item.visible = false
				_escondidos.append(no)
				continue
			var camada := no as CanvasLayer
			if camada != null and camada.visible:
				camada.visible = false
				_escondidos.append(no)
		return
	for no: Node in _escondidos:
		if not is_instance_valid(no):
			continue
		var item := no as CanvasItem
		if item != null:
			item.visible = true
			continue
		var camada := no as CanvasLayer
		if camada != null:
			camada.visible = true
	_escondidos.clear()


## Quantos metros ate o que esta no meio da tela. E o foco que o fotografo
## espera do botao: apontou, focou.
func _distancia_do_centro() -> float:
	if _camera == null:
		return _foco
	var de := _camera.global_position
	var ate := de - _camera.global_transform.basis.z * _camera.far
	var mundo := _camera.get_world_3d()
	if mundo == null:
		return _foco
	var consulta := PhysicsRayQueryParameters3D.create(de, ate)
	consulta.collide_with_areas = false
	var bate := mundo.direct_space_state.intersect_ray(consulta)
	if bate.is_empty():
		return _foco
	return maxf(0.2, de.distance_to(bate["position"] as Vector3))


func _unhandled_input(evento: InputEvent) -> void:
	if InputMap.has_action(&"modo_foto") and evento.is_action_pressed(&"modo_foto"):
		alternar()
		get_viewport().set_input_as_handled()
		return
	if not ativo:
		return
	var mm := evento as InputEventMouseMotion
	if mm != null:
		_giro.x -= mm.relative.x * SENSIBILIDADE
		_giro.y = clampf(_giro.y - mm.relative.y * SENSIBILIDADE, -1.5, 1.5)
		get_viewport().set_input_as_handled()
		return
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_ESCAPE:
			sair()
		KEY_F:
			_foco = _distancia_do_centro()
			_aplicar()
		KEY_BRACKETLEFT:
			_diafragma = maxi(0, _diafragma - 1)
			_aplicar()
		KEY_BRACKETRIGHT:
			_diafragma = mini(DIAFRAGMA.size() - 1, _diafragma + 1)
			_aplicar()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_parada = maxi(0, _parada - 1)
			_aplicar()
		KEY_EQUAL, KEY_KP_ADD:
			_parada = mini(PARADAS.size() - 1, _parada + 1)
			_aplicar()
		KEY_C:
			_filtro = (_filtro + 1) % FILTROS.size()
			_aplicar()
		KEY_ENTER, KEY_KP_ENTER:
			fotografar()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not ativo or _camera == null:
		return
	_camera.global_rotation = Vector3(_giro.y, _giro.x, 0.0)
	var frente := -_camera.global_transform.basis.z
	var lado := _camera.global_transform.basis.x
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		d += frente
	if Input.is_key_pressed(KEY_S):
		d -= frente
	if Input.is_key_pressed(KEY_D):
		d += lado
	if Input.is_key_pressed(KEY_A):
		d -= lado
	if Input.is_key_pressed(KEY_E):
		d += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		d -= Vector3.UP
	if d == Vector3.ZERO:
		return
	var v := VELOCIDADE
	if Input.is_key_pressed(KEY_SHIFT):
		v *= CORRIDA
	_camera.global_position += d.normalized() * v * delta


## A foto, em 3840x2160, do mesmo mundo e da mesma camera.
##
## O SubViewport recebe o World3D por referencia — a cena nao e montada de novo,
## so renderizada de outro angulo de leitura. `UPDATE_ONCE` mais dois quadros de
## espera porque a textura so existe depois do quadro em que o viewport desenha.
func fotografar() -> String:
	if _camera == null:
		return ""
	return await fotografar_camera(_camera, PASTA, "")


## A mesma foto, de uma camera qualquer e sem entrar no modo.
##
## E o que deixa a rota de captura (`--rota-4k`) tirar a foto de 4K de cada
## parada com a camera dela: a rota ja sabe esperar o streaming assentar, e
## refazer isso aqui dentro seria uma segunda rota.
func fotografar_camera(de: Camera3D, pasta: String, nome: String) -> String:
	if de == null or not de.is_inside_tree():
		return ""
	DirAccess.make_dir_recursive_absolute(pasta)
	var vp := SubViewport.new()
	vp.size = TAMANHO_FOTO
	vp.world_3d = get_viewport().find_world_3d()
	vp.own_world_3d = false
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = de.fov
	cam.near = de.near
	cam.far = de.far
	# Fora do modo foto (a rota chamando), os ajustes sao os do mundo. O
	# `camera_attributes` do WorldEnvironment NAO alcanca a camera de outro
	# viewport: medido, o brilho da foto ficava cravado no mesmo valor por 120
	# quadros — nao era exposicao que nao tinha assentado, era exposicao
	# automatica que nao estava rodando. Ele e escrito na camera, e ai roda.
	cam.attributes = _para_foto(_attr if _attr != null else _atributos_do_jogo())
	if _env != null:
		cam.environment = _env
	vp.add_child(cam)
	cam.global_transform = de.global_transform
	cam.current = true
	var img := await _assentar(vp, cam, await _brilho_da_tela())
	vp.queue_free()
	if img == null:
		return ""
	var arquivo := nome
	if arquivo.is_empty():
		arquivo = "foto_%s" % Time.get_datetime_string_from_system(false, false) 			.replace(":", "").replace("-", "").replace("T", "_")
	var caminho := "%s/%s.png" % [pasta, arquivo]
	var erro := img.save_png(caminho)
	if erro != OK:
		push_warning("ModoFoto: nao consegui gravar %s (erro %d)" % [caminho, erro])
		return ""
	print("[foto] %s (%dx%d)" % [caminho, img.get_width(), img.get_height()])
	fotografou.emit(caminho)
	return caminho


## O brilho que a tela esta entregando agora. E o alvo da foto.
func _brilho_da_tela() -> float:
	await RenderingServer.frame_post_draw
	var tela := get_viewport().get_texture()
	if tela == null:
		return -1.0
	var img := tela.get_image()
	if img == null:
		return -1.0
	return _brilho(img)


## Renderiza ate a foto ter o brilho da tela, mexendo no multiplicador.
##
## Tres a quatro rodadas bastam porque a correcao e a RAZAO entre o brilho
## pedido e o obtido: exposicao e multiplicativa, entao a primeira correcao ja
## chega perto e as seguintes so acertam a casa decimal. O limite por rodada
## existe para o caso de uma cena em que o alvo nao seja alcancavel (um quarto
## preto, uma tela branca), onde a razao dispararia.
func _assentar(vp: SubViewport, cam: Camera3D, alvo: float) -> Image:
	var img: Image = null
	for rodada in RODADAS:
		for _q in QUADROS_POR_LEITURA:
			await get_tree().process_frame
		img = vp.get_texture().get_image()
		if img == null:
			return null
		var brilho := _brilho(img)
		if alvo <= 0.0 or brilho <= 0.0:
			break
		var razao := alvo / brilho
		if absf(razao - 1.0) <= TOLERANCIA:
			break
		if rodada == RODADAS - 1:
			break
		var atrib := cam.attributes
		if atrib == null:
			break
		atrib.exposure_multiplier *= clampf(razao, 1.0 / PASSO_MAX, PASSO_MAX)
	return img


## Brilho medio por amostragem esparsa: ler 8 milhoes de pixels um a um para
## decidir se a exposicao parou seria mais caro que a propria foto.
static func _brilho(img: Image) -> float:
	var soma := 0.0
	var n := 0
	for y in range(0, img.get_height(), 32):
		for x in range(0, img.get_width(), 32):
			var c := img.get_pixel(x, y)
			soma += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return soma / maxf(float(n), 1.0)


# --- para a bancada ---------------------------------------------------------

func foco() -> float:
	return _foco


func filtro() -> int:
	return _filtro


func camera() -> Camera3D:
	return _camera


## Pelo nome que aparece na barra. E o que a bancada usa: enum de autoload nao
## se alcanca de um script de SceneTree.
func por_filtro_nome(nome: String) -> bool:
	for f: int in FILTROS:
		if FILTROS[f] == nome:
			por_filtro(f)
			return true
	return false


func por_filtro(f: int) -> void:
	_filtro = f
	_aplicar()


func por_diafragma(i: int) -> void:
	_diafragma = clampi(i, 0, DIAFRAGMA.size() - 1)
	_aplicar()


func por_parada(i: int) -> void:
	_parada = clampi(i, 0, PARADAS.size() - 1)
	_aplicar()


func por_foco(m: float) -> void:
	_foco = maxf(0.2, m)
	_aplicar()

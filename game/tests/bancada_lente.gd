## A lente: exposicao, obturador e foco. Criterio A15 do PLANO_AAA_4K.
##
##     godot --path game --script res://tests/bancada_lente.gd
##     (SEM --headless: exposicao, compute e pos-processamento pedem janela)
##     --saida=DIR grava as fotos
##
## Sao quatro perguntas, e nenhuma delas e a mesma:
##
## A15a  **O interior fica legivel.** Com exposicao automatica, a mediana do
##       quadro dentro de um quarto escuro sobe — o olho se acostuma. Sem ela, o
##       quarto e a mesma chapa preta que a rua clara deixou para tras.
## A15b  **A rua assenta em ate 2 s.** Saindo do quarto para a rua, a mediana
##       sobe e PARA. O tempo ate ela ficar a 5% do valor final e o numero. Tem
##       teto (2 s) e tem CHAO (0,25 s): assentar em zero nao e exposicao
##       automatica, e corte — que e o que o jogo fazia antes desta fase.
## A15c  **O obturador so abre dirigindo.** A 3 m/s (o jogador correndo faz 4,6)
##       a forca e zero; a 16 m/s ela e cheia. E, a 16 m/s, ligar o obturador
##       tira pelo menos METADE da energia de borda dos postes — senao o numero
##       de cima seria so uma variavel que ninguem le.
## A15d  **Foco raso nao existe no jogo.** A profundidade de campo nasce
##       desligada e so liga quando alguem pede (cutscene, modo foto).
##
## Por que o par de A15c muda so o obturador
## -----------------------------------------
## Comparar 3 m/s com 16 m/s mediria tambem o TAA, que reprojeta o quadro
## anterior e ja borra sozinho quando a camera corre. O par honesto e a MESMA
## velocidade com e sem obturador — e por isso a `Lente` tem `travar_desfoque`.
##
## Por que mediana e nao media
## ---------------------------
## A porta e uma fonte de luz dentro do quadro. Na media ela pesa tanto quanto o
## quarto inteiro e o numero vira o brilho da porta; na mediana ela e so mais um
## punhado de pixels claros, e o que sobra e o que o jogador consegue enxergar.
extends SceneTree

## A bancada trava o fps porque a exposicao e um filtro alimentado por delta: o
## que a define e tempo de parede, e nao contagem de quadros.
const FPS := 60
## Segundos de amostragem depois de sair para a rua.
const JANELA_S := 4.0
## Quanto do valor final conta como "assentou".
const FOLGA := 0.05
## Teto e chao do criterio A15b, em segundos.
const TETO_S := 2.0
const CHAO_S := 0.25

## Onde a camera fica dentro do quarto, e para onde olha (a porta).
const DENTRO := Vector3(0.0, 1.6, 2.4)
const OLHA_PORTA := Vector3(0.0, 1.5, -3.6)
## E o mesmo par ja na rua, dois passos depois da porta.
const FORA := Vector3(0.0, 1.6, -5.6)
const OLHA_RUA := Vector3(0.0, 1.5, -14.0)

## O corredor de postes do A15c e A15d fica longe do quarto, no mesmo mundo: uma
## segunda cena custaria um segundo `WorldEnvironment` e a lente e uma so.
const PISTA := Vector3(200.0, 1.6, 0.0)
## Velocidades do par do obturador, em m/s.
const VEL_PE := 3.0
const VEL_CARRO := 16.0
## Segundos andando antes de fotografar: a `Lente` suaviza a velocidade e ela
## leva meio segundo para chegar ao valor.
const EMBALO_S := 1.2

var _raiz: Node3D
var _camera: Camera3D
var _env: Environment
var _atrib: CameraAttributesPractical
var _lente: Node
var _saida := ""
var _so_obturador := false
## Piso de sensibilidade do quarto. O padrao e o do jogo; `--piso=N` calibra.
var _piso_interior := -1.0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--piso="):
			_piso_interior = arg.trim_prefix("--piso=").to_float()
		elif arg == "--so-obturador":
			# A parte da exposicao leva quinze segundos de rampa; ao afinar o
			# obturador ela so atrasa a volta.
			_so_obturador = true
	Engine.max_fps = FPS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.add_child.call_deferred(_montar())
	_medir()


func _montar() -> Node3D:
	_raiz = Node3D.new()

	var ambiente := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	# Ceu de dia. E ele que entra pela porta e estoura o quadro de dentro.
	_env.background_color = Color(0.55, 0.62, 0.74)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.60, 0.70)
	_env.ambient_light_energy = 0.9
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_white = 3.0
	ambiente.environment = _env
	ambiente.add_to_group(&"fog_controller")
	_raiz.add_child(ambiente)

	_camera = Camera3D.new()
	_camera.fov = 66.0
	_camera.position = DENTRO
	_camera.look_at_from_position(DENTRO, OLHA_PORTA, Vector3.UP)
	_raiz.add_child(_camera)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-46.0, 24.0, 0.0)
	sol.light_energy = 1.7
	sol.light_color = Color(1.0, 0.96, 0.90)
	sol.shadow_enabled = true
	_raiz.add_child(sol)

	_montar_quarto()
	_montar_rua()
	_montar_pista()
	return _raiz


## O quarto: caixa de 6x3x9 com uma porta de 1,2 m na parede do fundo.
##
## A porta e feita de DOIS pedacos de parede, e nao de um buraco recortado: o
## que importa aqui e o retangulo claro dentro do quadro escuro, e dois blocos
## com um vao entre eles produzem exatamente isso sem malha nenhuma na mao.
func _montar_quarto() -> void:
	var cinza := StandardMaterial3D.new()
	cinza.albedo_color = Color(0.42, 0.41, 0.40)
	cinza.roughness = 0.95

	# chao, teto e tres paredes inteiras
	_caixa(Vector3(0.0, -0.05, 0.0), Vector3(6.0, 0.1, 9.0), cinza)
	_caixa(Vector3(0.0, 3.0, 0.0), Vector3(6.0, 0.1, 9.0), cinza)
	_caixa(Vector3(-3.0, 1.5, 0.0), Vector3(0.1, 3.0, 9.0), cinza)
	_caixa(Vector3(3.0, 1.5, 0.0), Vector3(0.1, 3.0, 9.0), cinza)
	_caixa(Vector3(0.0, 1.5, 4.5), Vector3(6.0, 3.0, 0.1), cinza)
	# parede da porta, em dois pedacos, com vao de 1,2 m no meio
	_caixa(Vector3(-1.8, 1.5, -4.5), Vector3(2.4, 3.0, 0.1), cinza)
	_caixa(Vector3(1.8, 1.5, -4.5), Vector3(2.4, 3.0, 0.1), cinza)
	_caixa(Vector3(0.0, 2.6, -4.5), Vector3(1.2, 0.8, 0.1), cinza)

	# Uma lampada fraca. Sem ela o quarto e preto absoluto e nao ha o que
	# revelar: exposicao automatica levanta o que esta LA, nao inventa sinal.
	var lampada := OmniLight3D.new()
	lampada.position = Vector3(0.0, 2.5, 1.2)
	lampada.light_energy = 0.9
	lampada.light_color = Color(1.0, 0.85, 0.62)
	lampada.omni_range = 7.0
	_raiz.add_child(lampada)

	# Objetos de leitura: e neles que se ve se o interior "abriu". Uma parede
	# lisa sobe de brilho sem ganhar informacao nenhuma.
	var claro := StandardMaterial3D.new()
	claro.albedo_color = Color(0.72, 0.70, 0.66)
	_caixa(Vector3(-1.9, 0.45, 0.2), Vector3(0.9, 0.9, 0.9), claro)
	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = Color(0.16, 0.15, 0.15)
	_caixa(Vector3(1.7, 0.6, -0.4), Vector3(1.0, 1.2, 0.8), escuro)


## A rua: chao claro e duas fachadas, para a saida ter o que enquadrar.
func _montar_rua() -> void:
	var asfalto := StandardMaterial3D.new()
	asfalto.albedo_color = Color(0.38, 0.38, 0.39)
	asfalto.roughness = 0.9
	_caixa(Vector3(0.0, -0.05, -14.0), Vector3(40.0, 0.1, 20.0), asfalto)
	var fachada := StandardMaterial3D.new()
	fachada.albedo_color = Color(0.62, 0.58, 0.52)
	_caixa(Vector3(-7.0, 3.0, -16.0), Vector3(4.0, 6.0, 12.0), fachada)
	_caixa(Vector3(7.0, 3.0, -16.0), Vector3(4.0, 6.0, 12.0), fachada)


## A pista do obturador e do foco: postes escuros contra um muro claro.
##
## Postes verticais e movimento HORIZONTAL de proposito. O rastro do desfoque
## corre no sentido em que a camera anda; medido numa borda vertical, ele vira
## uma queda de inclinacao que nao se confunde com nada. Numa borda horizontal o
## mesmo rastro nao mexeria em nada e a bancada mediria zero com o efeito ligado.
func _montar_pista() -> void:
	var muro := StandardMaterial3D.new()
	muro.albedo_color = Color(0.78, 0.76, 0.72)
	muro.roughness = 0.95
	_caixa(PISTA + Vector3(0.0, 4.0, -12.0), Vector3(90.0, 8.0, 0.4), muro)
	_caixa(PISTA + Vector3(0.0, -0.05, -6.0), Vector3(90.0, 0.1, 14.0), muro)

	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = Color(0.08, 0.08, 0.09)
	escuro.roughness = 0.8
	# Perto: e neles que o obturador trabalha, porque perto anda mais na tela.
	for i in 24:
		_caixa(PISTA + Vector3(-34.0 + float(i) * 3.0, 2.0, -5.0),
			Vector3(0.22, 4.0, 0.22), escuro)
	# Longe: a fileira do fundo e a que o foco raso desmancha em A15d.
	for i in 30:
		_caixa(PISTA + Vector3(-34.0 + float(i) * 2.4, 1.6, -11.4),
			Vector3(0.16, 3.2, 0.16), escuro)


func _caixa(onde: Vector3, tam: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = tam
	m.mesh = caixa
	m.material_override = mat
	m.position = onde
	_raiz.add_child(m)


func _medir() -> void:
	await process_frame
	await process_frame
	_lente = root.get_node_or_null(^"/root/Lente")
	if _lente == null:
		print("[lente] sem o autoload Lente: nada a medir")
		quit(1)
		return
	if _piso_interior <= 0.0:
		# O piso que o jogo usa num interior. Lido da classe por `get_script`,
		# e nao pelo nome dela: ver o cabecalho sobre o `--script`.
		_piso_interior = float(_lente.get_script().get_script_constant_map()["ISO_PISO_INTERIOR"])
	# A lente nasce antes desta cena existir, entao o ambiente dela e outro.
	_lente.call(&"aplicar")
	await process_frame

	var passou := 0
	var alvo := 5
	if _so_obturador:
		alvo = 2
		_atrib = _lente.call(&"atributos") as CameraAttributesPractical
		_atrib.auto_exposure_enabled = false
		_camera.attributes = _atrib
	else:
		passou += await _medir_exposicao()
	passou += await _medir_obturador()
	if not _so_obturador:
		passou += await _medir_foco()

	print("[lente] %d de %d criterios" % [passou, alvo])
	quit(0 if passou == alvo else 1)


# ---------------------------------------------------------------- A15a e A15b

func _medir_exposicao() -> int:
	print("[lente] === sem exposicao automatica (a base) ===")
	var base := await _correr(false)
	print("[lente] === com exposicao automatica ===")
	var novo := await _correr(true)

	var passou := 0
	var dentro_base := float(base["dentro"])
	var dentro_novo := float(novo["dentro"])
	var ganho := dentro_novo / maxf(dentro_base, 0.0001)
	print("[lente] A15a interior: mediana %.1f/255 sem, %.1f/255 com (x%.2f)"
		% [dentro_base * 255.0, dentro_novo * 255.0, ganho])
	if ganho >= 1.6:
		passou += 1

	var tempo := float(novo["tempo"])
	print("[lente] A15b rua: assentou em %.2f s (base %.2f s), de %.1f para %.1f/255"
		% [tempo, float(base["tempo"]), dentro_novo * 255.0,
			float(novo["fora"]) * 255.0])
	if tempo <= TETO_S and tempo >= CHAO_S:
		passou += 1
	return passou


## Uma corrida inteira: assenta no quarto, sai para a rua, amostra ate assentar.
##
## Devolve `{dentro, fora, tempo}` — mediana dentro, mediana final na rua e os
## segundos que a segunda levou para parar de subir.
func _correr(automatica: bool) -> Dictionary:
	_atrib = _lente.call(&"atributos") as CameraAttributesPractical
	_atrib.auto_exposure_enabled = automatica
	# O piso do INTERIOR: a bancada e um quarto escuro com porta para a rua, e
	# nela nao ha `Interiores` nem clima para a lente decidir sozinha.
	_lente.call(&"forcar_piso", _piso_interior)
	_lente.call(&"sem_foco")
	_lente.call(&"travar_desfoque", 0.0)
	_camera.attributes = _atrib

	# Assentar no escuro. Dois segundos e meio e mais do que a rampa precisa, e e
	# o que garante que o "dentro" medido e o regime, e nao o meio do caminho.
	_pousar(DENTRO, OLHA_PORTA)
	await _esperar(2.5)
	var dentro := _mediana(await _foto("dentro_auto" if automatica else "dentro_base"))

	# Sai para a rua. Um teleporte, e nao uma caminhada: o que se mede e a
	# resposta do medidor de luz a um degrau, e caminhada mistura a rampa da
	# exposicao com a rampa do enquadramento.
	#
	# E o piso volta a ser o do lugar, como no jogo ao sair de um interior: a
	# rampa dele entra no tempo medido.
	_pousar(FORA, OLHA_RUA)
	_lente.call(&"forcar_piso", -1.0)

	var t0 := Time.get_ticks_msec()
	var amostras: Array[Vector2] = []
	while (Time.get_ticks_msec() - t0) < int(JANELA_S * 1000.0):
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img == null:
			continue
		amostras.append(Vector2(float(Time.get_ticks_msec() - t0) / 1000.0,
			_mediana(img)))
	var fora := await _foto("fora_auto" if automatica else "fora_base")
	return {
		"dentro": dentro,
		"fora": _mediana(fora),
		"tempo": _tempo_de_assentar(amostras),
	}


# ----------------------------------------------------------------------- A15c

func _medir_obturador() -> int:
	var passou := 0
	_atrib.auto_exposure_enabled = false
	_lente.call(&"travar_desfoque", -1.0)

	# O portao: a pe a forca tem de ser zero, no carro tem de abrir.
	var a_pe := await _andar(VEL_PE)
	var de_carro := await _andar(VEL_CARRO)
	print("[lente] A15c portao: a %.0f m/s forca %.3f, a %.0f m/s forca %.3f"
		% [VEL_PE, a_pe, VEL_CARRO, de_carro])
	if a_pe <= 0.001 and de_carro > 0.0:
		passou += 1

	# O par: a MESMA velocidade, com e sem obturador.
	_lente.call(&"travar_desfoque", 0.0)
	var sem := _energia_de_borda(await _andar_e_fotografar(VEL_CARRO, "obturador_sem"))
	_lente.call(&"travar_desfoque", float(_lente.call(&"obturador")))
	var com := _energia_de_borda(await _andar_e_fotografar(VEL_CARRO, "obturador_com"))

	# Sonda: o rastro reconstruido, pintado na tela. Em tonemap LINEAR, porque o
	# AgX que a lente escolhe entorta cada canal de um jeito e a leitura precisa
	# sair em pixel. A conta de referencia e 29,6 px para um poste a 5 m andando
	# 0,267 m por quadro, feita na CPU contra `unproject_position`.
	var tom := _env.tonemap_mode
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_lente.call(&"depurar", 3)
	var pintado := await _andar_e_fotografar(VEL_CARRO, "obturador_rastro")
	_lente.call(&"depurar", 0)
	_env.tonemap_mode = tom
	_lente.call(&"travar_desfoque", -1.0)
	print("[lente] sonda: maior rastro reconstruido %.1f px (obturador inteiro, antes do teto)"
		% (_maior_vermelho(pintado) / 0.02))

	print("[lente] A15c energia de borda a %.0f m/s: sem obturador %.1f, com %.1f (x%.2f)"
		% [VEL_CARRO, sem, com, sem / maxf(com, 0.001)])
	# Metade da energia: a borda de um poste virou rampa de pelo menos o dobro
	# da largura. Abaixo disso o olho ainda le "cena nitida com fantasma".
	if com <= sem * 0.5:
		passou += 1
	return passou


## Anda pela pista por `EMBALO_S` e devolve a forca do obturador no fim.
func _andar(velocidade: float) -> float:
	_pousar(PISTA + Vector3(-30.0, 0.0, 0.0), PISTA + Vector3(-30.0, 1.5, -12.0))
	await _esperar(0.3)
	var passo := velocidade / float(FPS)
	var quadros := int(EMBALO_S * float(FPS))
	for i in quadros:
		_camera.global_position += Vector3(passo, 0.0, 0.0)
		await process_frame
	return float(_lente.call(&"forca_do_desfoque"))


func _andar_e_fotografar(velocidade: float, nome: String) -> Image:
	await _andar(velocidade)
	# Mais alguns quadros andando, porque a foto sai DEPOIS do movimento: parar
	# para fotografar zeraria o vetor de movimento e mediria a cena parada.
	var passo := velocidade / float(FPS)
	for i in 6:
		_camera.global_position += Vector3(passo, 0.0, 0.0)
		await process_frame
	# O QUADRO FOTOGRAFADO TAMBEM ANDA.
	#
	# O laco acima move a camera e espera o quadro seguinte; quando ele termina,
	# o quadro em que a corrotina acorda nao tem movimento nenhum — e e esse que
	# `frame_post_draw` entrega. Sem este passo a mais, toda foto desta bancada
	# era de uma camera parada, e o desfoque media 1,03x com o efeito funcionando.
	_camera.global_position += Vector3(passo, 0.0, 0.0)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and _saida != "":
		img.save_png("%s/lente_%s.png" % [_saida, nome])
	return img


# ----------------------------------------------------------------------- A15d

func _medir_foco() -> int:
	var passou := 0
	_lente.call(&"travar_desfoque", 0.0)
	if bool(_lente.call(&"profundidade_ligada")):
		print("[lente] A15d REPROVA: o jogo nasceu com profundidade de campo")
		_lente.call(&"travar_desfoque", -1.0)
		return 0

	_pousar(PISTA + Vector3(0.0, 0.0, 6.0), PISTA + Vector3(0.0, 1.5, -12.0))
	await _esperar(0.6)
	var solto := _borda_do_fundo(await _foto("foco_infinito"))
	# Foco a 2,5 m: os postes de perto (11 m) e os de longe (18 m) saem os dois
	# do plano focal, e o fundo e onde isso se mede sem o rastro atrapalhar.
	_lente.call(&"focar", 2.5, 0.2)
	await _esperar(0.6)
	var raso := _borda_do_fundo(await _foto("foco_raso"))
	var ligou := bool(_lente.call(&"profundidade_ligada"))
	_lente.call(&"sem_foco")
	_lente.call(&"travar_desfoque", -1.0)
	print("[lente] A15d fundo: foco infinito %.1f, foco raso %.1f (x%.2f mais macio), API liga %s"
		% [solto, raso, solto / maxf(raso, 0.001), "sim" if ligou else "nao"])
	if ligou and raso <= solto * 0.70:
		passou += 1
	return passou


# ----------------------------------------------------------------------- comum

func _pousar(onde: Vector3, olhar: Vector3) -> void:
	_camera.look_at_from_position(onde, olhar, Vector3.UP)
	# Salto nao e velocidade: sem isto o primeiro quadro depois de cada teleporte
	# sairia borrado de ponta a ponta e a exposicao continuaria contando do
	# enquadramento anterior.
	_lente.call(&"recomecar")


## Quando a curva entrou na folga do valor final e nao saiu mais.
##
## Varre de TRAS para a frente: o primeiro ponto que estourar a folga, olhando de
## tras, e o ultimo instante em que ainda nao havia assentado. Varrer de frente
## para tras erraria em qualquer curva que cruze o valor final antes de parar
## nele — e a exposicao do Godot passa um pouco do ponto antes de voltar.
static func _tempo_de_assentar(amostras: Array[Vector2]) -> float:
	if amostras.size() < 8:
		return -1.0
	var soma := 0.0
	for i in range(amostras.size() - 10, amostras.size()):
		soma += amostras[i].y
	var alvo := soma / 10.0
	for i in range(amostras.size() - 1, -1, -1):
		if absf(amostras[i].y - alvo) > FOLGA * maxf(alvo, 0.001):
			return amostras[i].x
	return 0.0


func _esperar(segundos: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < int(segundos * 1000.0):
		await process_frame


func _foto(nome: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and _saida != "":
		img.save_png("%s/lente_%s.png" % [_saida, nome])
	return img


## Mediana da luminancia, de 0 a 1. Amostra de 3 em 3 pixels: o valor nao se move
## na terceira casa e a varredura cabe num quadro.
static func _mediana(img: Image) -> float:
	if img == null:
		return 0.0
	var vals: PackedFloat32Array = []
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			vals.append(img.get_pixel(x, y).get_luminance())
	if vals.is_empty():
		return 0.0
	vals.sort()
	return vals[vals.size() / 2]


## A inclinacao da borda vertical mais dura da faixa, em niveis por pixel.
##
## Mesma regua da penumbra (criterio A13, `bancada_luz`): borda dura muda tudo
## em dois pixels e da inclinacao alta; borda borrada espalha a mesma diferenca
## por varios e da inclinacao baixa. O percentil 99,5 pega a borda e ignora o
## grao do pos-processo.
static func _gradiente(img: Image, y0: float, y1: float) -> float:
	if img == null:
		return 0.0
	var grads: PackedFloat32Array = []
	for y in range(int(img.get_height() * y0), int(img.get_height() * y1), 2):
		for x in range(4, img.get_width() - 4, 1):
			grads.append(absf(img.get_pixel(x + 2, y).get_luminance()
				- img.get_pixel(x - 2, y).get_luminance()))
	if grads.size() < 100:
		return 0.0
	grads.sort()
	return grads[int(grads.size() * 0.995)] * 255.0


static func _maior_vermelho(img: Image) -> float:
	if img == null:
		return -1.0
	var maior := 0.0
	for y in range(int(img.get_height() * 0.15), int(img.get_height() * 0.58), 2):
		for x in range(0, img.get_width(), 2):
			maior = maxf(maior, img.get_pixel(x, y).srgb_to_linear().r)
	return maior


## A ENERGIA de borda da faixa dos postes: a media do quadrado da diferenca
## entre pixels vizinhos, em niveis de 0 a 255.
##
## Por que energia, e nao a borda mais dura (a regua da penumbra, A13).
## Desfoque de movimento com amostras deslocadas por ruido deixa a borda como
## uma rampa de nove pixels com DEGRAUS de ruido dentro — e o percentil 99,5 le
## o degrau, nao a rampa. Medido: com o efeito funcionando e a rampa visivel no
## perfil do poste, aquela regua dava 1,16x. A energia nao se engana: um degrau
## de altura H espalhado por N pixels soma H^2/N, e o ruido, que e pequeno,
## entra ao quadrado e quase nao pesa.
static func _energia_de_borda(img: Image) -> float:
	if img == null:
		return 0.0
	var soma := 0.0
	var n := 0
	for y in range(int(img.get_height() * 0.42), int(img.get_height() * 0.72), 2):
		var antes := img.get_pixel(0, y).get_luminance()
		for x in range(1, img.get_width()):
			var agora := img.get_pixel(x, y).get_luminance()
			var d := (agora - antes) * 255.0
			soma += d * d
			n += 1
			antes = agora
	return soma / maxf(float(n), 1.0)


## A fileira do fundo fica na faixa do horizonte.
static func _borda_do_fundo(img: Image) -> float:
	return _gradiente(img, 0.30, 0.44)

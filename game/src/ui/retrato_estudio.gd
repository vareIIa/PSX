## O estudio do retrato da carteira: corpo, luz e uma camera que chega perto.
##
## A foto 3x4 era uma camera cravada no busto. Servia para escolher rosto e
## camisa e mentia para todo o resto: a calca, o sapato e a altura nao entravam
## no quadro, e o jogador escolhia o que nao via. Aqui a camera tem ZOOM — do
## rosto inteiro na janela ate o corpo da cabeca aos pes — e cada aba pede o seu
## enquadramento: ROSTO chega na cara, ROUPA abre ate a cintura, CALCA e PES
## abrem o corpo inteiro. O jogador pode aproximar e afastar por cima disso com
## a roda do mouse, e girar a pessoa arrastando.
##
## O corpo e o MESMO `Corpo` da calcada, montado pela mesma funcao. O retrato
## continua sem ter como mentir.
##
## Mora fora de `criacao.gd` porque la ja vive o documento inteiro, e porque o
## estudio e uma coisa que se testa sozinha: dada uma aparencia e um zoom, a
## camera tem de enquadrar a cabeca inteira.
class_name RetratoEstudio
extends Node

## FOV da lente. Estreito, de retrato: achata o rosto do jeito que foto de
## documento achata, e deixa a distancia da camera fazer o zoom.
const FOV := 25.0

## Enquadramentos-chave, de 0 (rosto) a 1 (corpo inteiro). Cada um e a altura
## de mundo que cabe na janela e onde fica o centro, as duas coisas medidas a
## partir do alto da cabeca — assim a mesma chave serve para 1,50 m e 1,94 m.
##
##   zoom   janela            centro
##   0,0    0,42 m            altura - 0,14     a cara, com folga de cabelo
##   0,5    1,02 m            altura - 0,43     da cintura para cima
##   1,0    altura x 1,16     altura x 0,50     cabeca aos pes, com chao
##
## A folga acima da cabeca e de sete a oito centimetros nas duas primeiras. Com
## dois, a primeira captura encostou o cabelo na moldura.
const JANELA_ROSTO := 0.42
const CENTRO_ROSTO := 0.14
const JANELA_MEIO := 1.02
const CENTRO_MEIO := 0.43
const JANELA_CORPO := 1.16
## Quao depressa a camera chega no enquadramento pedido. Suave, e nao travada
## em passos como a pose: e movimento de camera de estudio, nao de personagem.
const SUAVIDADE := 9.0
## Balanco lento de quem nao mexeu: a pessoa vira um pouco para cada lado,
## mostrando o perfil, e volta. Some no primeiro arrasto.
const BALANCO := 0.35

var viewport: SubViewport
var _corpo: Corpo
var _camera: Camera3D
var _sombra: MeshInstance3D
var _altura: float = 1.72

var _zoom: float = 0.4
var _zoom_alvo: float = 0.4
var _giro: float = 0.0
var _giro_alvo: float = 0.0
var _mexeu_no_giro: bool = false
var _relogio: float = 0.0
## Para onde a cabeca esta virada atras do cursor, e para onde quer virar.
var _olhar: float = 0.0
var _olhar_alvo: float = 0.0
## Quanto tempo a pessoa esta parada sem reagir a nada. Passou de
## `_proximo_ocio`, ela faz um gesto de quem espera.
var _parado: float = 0.0
var _proximo_ocio: float = 6.0

## Quanto a cabeca vira atras do cursor, no maximo. Pouco: e um olhar, nao um
## pescoco de coruja, e ele ainda soma com o giro do corpo.
const OLHAR_MAXIMO := 0.42


func _init(tamanho: Vector2i) -> void:
	name = "RetratoEstudio"
	viewport = SubViewport.new()
	viewport.size = tamanho
	# Mundo proprio: sem isto o retrato renderiza a cidade que esta atras do
	# menu, com nevoa e chuva.
	viewport.own_world_3d = true
	# Fundo transparente: quem pinta o fundo de estudio e o documento, em 2D,
	# com o degrade e a vinheta que uma parede 3D nao da nesse tamanho.
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	add_child(viewport)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8e8c80")
	env.ambient_light_energy = 0.95
	ambiente.environment = env
	viewport.add_child(ambiente)

	# Luz de estudio em duas: a principal, quente, de cima e da direita, e uma
	# de preenchimento fria do outro lado. Com uma luz so, o lado de sombra das
	# caixas vira chapado e a pessoa perde o volume que a lateral da.
	var chave := DirectionalLight3D.new()
	chave.light_energy = 1.40
	chave.light_color = Color(1.0, 0.96, 0.9)
	chave.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(-150.0), 0.0)
	chave.shadow_enabled = false
	viewport.add_child(chave)
	var preenche := DirectionalLight3D.new()
	preenche.light_energy = 0.38
	preenche.light_color = Color(0.72, 0.80, 0.95)
	preenche.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(140.0), 0.0)
	preenche.shadow_enabled = false
	viewport.add_child(preenche)

	# Sombra de contato no chao. So aparece no enquadramento de corpo inteiro,
	# e e ela que diz que a pessoa esta de pe em algum lugar e nao boiando.
	_sombra = MeshInstance3D.new()
	var disco := QuadMesh.new()
	disco.size = Vector2(0.95, 0.62)
	disco.orientation = PlaneMesh.FACE_Y
	_sombra.mesh = disco
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _textura_da_sombra()
	mat.albedo_color = Color(0.05, 0.06, 0.08, 0.55)
	_sombra.material_override = mat
	_sombra.position = Vector3(0.0, 0.004, 0.0)
	_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(_sombra)

	_camera = Camera3D.new()
	_camera.name = "CameraRetrato"
	_camera.fov = FOV
	_camera.near = 0.05
	viewport.add_child(_camera)
	_camera.current = true
	_enquadrar(true)


static func _textura_da_sombra() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Quantos pixels de render por pixel logico da carteira.
##
## No PS1 STYLE e um: a foto de 104 px e grossa como tudo na tela, e deve ser.
## No MODERNO o 2D escala em vetor ate a janela e so esta foto ficava em 104,
## esticada — a pessoa, que e o assunto da tela, era a unica coisa em blocos
## numa carteira nitida. Aqui ela renderiza na resolucao em que aparece, com
## MSAA, e passa a ter o acabamento do resto.
var _base: Vector2i


func nitidez(fator: int) -> void:
	if _base == Vector2i.ZERO:
		_base = viewport.size
	fator = clampi(fator, 1, 8)
	viewport.size = _base * fator
	viewport.msaa_3d = Viewport.MSAA_4X if fator > 1 else Viewport.MSAA_DISABLED


func ligar(ligado: bool) -> void:
	viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if ligado
		else SubViewport.UPDATE_DISABLED)


func textura() -> Texture2D:
	return viewport.get_texture()


func corpo() -> Corpo:
	return _corpo


# --- vestir -------------------------------------------------------------------

## Refaz o corpo com a aparencia nova e dispara a reacao.
##
## A reacao ATRAVESSA a remontagem. Clicar tres vezes seguidas na seta da
## camisa monta tres corpos; se cada um recomecasse o gesto do zero, a mao
## subiria, cairia e subiria de novo a cada clique — um tique nervoso. Se o
## gesto em curso e o mesmo, o corpo novo herda o relogio, preso no comeco da
## janela cheia: a mao fica no lugar enquanto o jogador continua trocando.
func vestir(aparencia: Dictionary, reacao: int = 0) -> void:
	var herda_tipo := 0
	var herda_t := 0.0
	if _corpo != null and _corpo.reacao() != 0:
		herda_tipo = _corpo.reacao()
		herda_t = _corpo.tempo_da_reacao()
		_corpo.queue_free()
	elif _corpo != null:
		_corpo.queue_free()
	_corpo = Corpo.new()
	# De perto um rosto que nunca pisca le como boneco de cera.
	_corpo.piscar = true
	_corpo.detalhado = true
	viewport.add_child(_corpo)
	_corpo.montar(aparencia)
	_corpo.rotation.y = _giro
	_altura = float(aparencia.get("altura", 1.72))
	_preencher_pescoco(aparencia)
	if reacao != 0:
		_parado = 0.0
		var t0 := 0.0
		if reacao == herda_tipo:
			t0 = minf(herda_t, ReacaoCorpo.duracao(reacao) * 0.30)
		_corpo.reagir(reacao, t0)
	elif herda_tipo != 0:
		_corpo.reagir(herda_tipo, herda_t)
	_corpo.animar(0.0, 0.016)


## So no retrato: o Corpo tem ~4 cm entre o topo do tronco (y 1,38) e a caixa da
## nuca (y 1,425). Na rua some; de perto vira "cabeca flutuando". Um pescoco de
## verdade, no eixo do corpo, mergulhado no tronco — e nao um tapume.
func _preencher_pescoco(apar: Dictionary) -> void:
	var sk := _corpo.esqueleto()
	if sk == null:
		return
	var esc := float(apar.get("altura", 1.72)) / 1.72
	var att := BoneAttachment3D.new()
	att.name = "PescocoRetrato"
	att.bone_name = "cabeca"
	sk.add_child(att)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.125, 0.24 * esc, 0.115)
	mi.mesh = box
	mi.position = Vector3(0.0, -0.135 * esc, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Aparencia.pele_na_tela(apar).darkened(0.12)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(mi)


# --- camera -------------------------------------------------------------------

## Enquadramento pedido pela aba. Zera o que o jogador tinha aproximado: trocar
## de aba e pedir outra foto.
func focar(zoom: float) -> void:
	_zoom_alvo = clampf(zoom, 0.0, 1.0)


func aproximar(passo: float) -> void:
	_zoom_alvo = clampf(_zoom_alvo + passo, 0.0, 1.0)


func girar(radianos: float) -> void:
	_mexeu_no_giro = true
	_giro_alvo = wrapf(_giro_alvo + radianos, -PI, PI)


## De volta de frente, e o balanco volta.
func de_frente() -> void:
	_mexeu_no_giro = false
	_giro_alvo = 0.0


## A pessoa aprova o documento: joinha.
func aprovar() -> void:
	if _corpo != null:
		_corpo.reagir(ReacaoCorpo.APROVADO)
		_parado = 0.0


## Para onde olhar, de -1 (esquerda da tela) a 1 (direita).
##
## A camera olha para +Z; a direita da TELA e o -X do mundo, e virar a cara
## para -X e giro positivo na convencao do Corpo. Por isso o sinal nao inverte.
func olhar_para(x: float) -> void:
	_olhar_alvo = clampf(x, -1.0, 1.0) * OLHAR_MAXIMO


func zoom() -> float:
	return _zoom


func zoom_alvo() -> float:
	return _zoom_alvo


func giro() -> float:
	return _giro


func processar(delta: float) -> void:
	_relogio += delta
	var k := 1.0 - exp(-SUAVIDADE * delta)
	_zoom = lerpf(_zoom, _zoom_alvo, k)
	if not _mexeu_no_giro:
		# Balanco lento em volta da frente, e nunca muito: e de frente que se
		# escolhe rosto e camisa.
		_giro_alvo = sin(_relogio * 0.5) * BALANCO
	_giro = lerp_angle(_giro, _giro_alvo, k)
	if _corpo != null:
		_corpo.rotation.y = _giro
		_olhar = lerpf(_olhar, _olhar_alvo, 1.0 - exp(-6.0 * delta))
		# Descontado o giro do corpo: a cabeca procura o cursor, e nao um ponto
		# preso no ombro.
		_corpo.olhar_lateral(_olhar - _giro * 0.5)
		_ocio(delta)
		_corpo.animar(0.0, delta)
	_enquadrar(false)


## Parado demais, a pessoa faz alguma coisa: troca o peso de perna, olha em
## volta, confere o relogio. Intervalo sorteado, e nunca o mesmo gesto duas
## vezes seguidas.
var _ultimo_ocio: int = 0


func _ocio(delta: float) -> void:
	if _corpo.reacao() != 0:
		_parado = 0.0
		return
	_parado += delta
	if _parado < _proximo_ocio:
		return
	var opcoes := ReacaoCorpo.OCIOSAS.duplicate()
	opcoes.erase(_ultimo_ocio)
	_ultimo_ocio = opcoes[randi() % opcoes.size()]
	_corpo.reagir(_ultimo_ocio)
	_parado = 0.0
	_proximo_ocio = randf_range(5.0, 9.0)


## A janela e o centro no zoom atual, em metros. Publico para a verificacao.
func janela_e_centro(z: float) -> Vector2:
	var janela := 0.0
	var centro := 0.0
	if z <= 0.5:
		var t := z / 0.5
		janela = lerpf(JANELA_ROSTO, JANELA_MEIO, t)
		centro = lerpf(_altura - CENTRO_ROSTO, _altura - CENTRO_MEIO, t)
	else:
		var t := (z - 0.5) / 0.5
		janela = lerpf(JANELA_MEIO, _altura * JANELA_CORPO, t)
		centro = lerpf(_altura - CENTRO_MEIO, _altura * 0.5, t)
	return Vector2(janela, centro)


func _enquadrar(_imediato: bool) -> void:
	if _camera == null:
		return
	var jc := janela_e_centro(_zoom)
	var dist := jc.x * 0.5 / tan(deg_to_rad(FOV * 0.5))
	_camera.position = Vector3(0.0, jc.y, -dist)
	_camera.look_at(Vector3(0.0, jc.y, 0.0), Vector3.UP)
	if _sombra != null:
		# A sombra entra quando o chao entra no quadro.
		var mat := _sombra.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.55 * clampf((_zoom - 0.55) / 0.3, 0.0, 1.0)

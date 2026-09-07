## A TV de tubo, e a partida que esta passando nela.
##
## O gabinete nao esta aqui. Ele e feito de caixas e vai fundido na superficie
## do comodo, pelo mesmo motivo do poste de luz e do semaforo: caixa parada nao
## precisa de no, e no custa chamada de desenho. O que sobra para esta classe e
## o que MUDA — a imagem, a luz que ela joga na sala, e o chiado.
##
## Como a partida se move
## ----------------------
## Quatro quadros de campo desenhados no atlas, alternados a oito por segundo. A
## malha nao e reconstruida: existem quatro ArrayMesh prontos, com a UV apontando
## para uma celula cada, e a troca e uma atribuicao de recurso. Custa o mesmo que
## nao trocar nada.
##
## Oito quadros por segundo e escolha, e nao limite. A trinta, a imagem fica
## fluida e denuncia que ha um video ali; a oito, com o vulto dos jogadores
## pulando de lugar, o olho le "jogo de futebol de PS2" — que e o alvo.
##
## A luz e a metade do trabalho
## ----------------------------
## Uma TV acesa num comodo escuro nao e um retangulo brilhante: e a coisa que
## pinta todo mundo de azul e faz a silhueta de quem esta sentado na frente. A
## luz aqui acompanha o quadro — muda de energia junto com a imagem — e e por
## isso que a sala parece ter uma televisao em vez de um cartaz iluminado.
##
## Modo estatica (abertura CRT)
## ----------------------------
## Na cinematic da abertura o tubo NAO mostra futebol: so neve/sopro de tubo.
## Quem liga isso e a cidade no boot; o gameplay da casa continua com a partida.
class_name Televisao
extends Node3D

const MATERIAL_TELA := "res://resources/materials/mat_casa_tela.tres"

## Celulas da partida no atlas da casa. Ver tools/gerar_casa.py.
const QUADROS := 4
const LINHA_CAMPO := 0

## Quadros por segundo da imagem.
const CADENCIA := 8.0

## Tamanho do tubo, em metros. Vinte e nove polegadas na diagonal, que era a TV
## grande de sala — o "tubao". A primeira versao tinha vinte polegadas e a
## captura mostrou o problema na hora: a TV virou um retangulo verde no fundo do
## comodo, e o comodo inteiro existe em funcao dela.
const TELA := Vector2(0.55, 0.42)

@export var giro: float = 0.0

var _tela: MeshInstance3D
var _malhas: Array[ArrayMesh] = []
var _luz: OmniLight3D
var _chiado: AudioStreamPlayer3D
var _relogio: float = 0.0
var _quadro: int = 0
var _modo_estatica: bool = false
var _mat_partida: Material
var _mat_neve: StandardMaterial3D
var _malha_neve: ArrayMesh


func _ready() -> void:
	add_to_group(&"televisao")
	rotation.y = giro
	_montar_tela()
	_montar_luz()
	_montar_chiado()
	set_process(true)


func _montar_tela() -> void:
	for k in QUADROS:
		_malhas.append(_quadro_da_partida(Vector2i(k, LINHA_CAMPO)))
	_mat_partida = load(MATERIAL_TELA) as Material
	_malha_neve = _malha_placa_cheia()
	_mat_neve = StandardMaterial3D.new()
	_mat_neve.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_neve.albedo_color = Color(0.12, 0.13, 0.14)
	_mat_neve.emission_enabled = true
	_mat_neve.emission = Color(0.55, 0.58, 0.62)
	_mat_neve.emission_energy_multiplier = 1.35
	_tela = MeshInstance3D.new()
	_tela.name = "Tubo"
	_tela.mesh = _malhas[0]
	_tela.material_override = _mat_partida
	_tela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tela)


static func _quadro_da_partida(celula: Vector2i) -> ArrayMesh:
	var d := PSXMesh.placa_dados(TELA, 100.0, Color.WHITE)
	var r := Carroceria.uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	return PSXMesh.dados_para_mesh(d)


static func _malha_placa_cheia() -> ArrayMesh:
	var d := PSXMesh.placa_dados(TELA, 100.0, Color.WHITE)
	return PSXMesh.dados_para_mesh(d)


func _montar_luz() -> void:
	_luz = OmniLight3D.new()
	_luz.name = "Brilho"
	# Meio metro a frente do tubo. Na posicao da tela, a luz ilumina o proprio
	# gabinete e quem esta sentado fica na sombra dele.
	_luz.position = Vector3(0.0, 0.0, 0.5)
	_luz.omni_range = 6.6
	_luz.light_energy = 2.4
	_luz.light_color = Color(0.72, 0.84, 1.0)
	_luz.shadow_enabled = false
	add_child(_luz)


func _montar_chiado() -> void:
	var s := AudioDirector.stream(&"tv_chiado")
	if s == null:
		return
	_chiado = AudioStreamPlayer3D.new()
	_chiado.name = "Chiado"
	_chiado.bus = &"SFX"
	_chiado.stream = s
	_chiado.max_distance = 6.0
	_chiado.unit_size = 1.4
	_chiado.volume_db = -24.0
	_chiado.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	# O arquivo nao e marcado como loop no importador, porque o chiado tambem
	# serve de efeito curto em outro lugar. Aqui ele tem de nao acabar.
	_chiado.finished.connect(_chiado.play)
	add_child(_chiado)
	_chiado.play()


## Neve/sopro de tubo — sem futebol. Usado na abertura CRT.
func mostrar_estatica(ligado: bool = true) -> void:
	_modo_estatica = ligado
	if _tela == null:
		return
	if ligado:
		_tela.mesh = _malha_neve
		_tela.material_override = _mat_neve
		if _luz != null:
			_luz.light_color = Color(0.78, 0.8, 0.84)
			_luz.light_energy = 1.7
		# CRT open: neve visual sim, chiado nao — cam colada no tubo
		# tornaria o loop finished->play ensurdecedor e eterno.
		if _chiado != null:
			_chiado.stop()
			_chiado.volume_db = -80.0
	else:
		_tela.mesh = _malhas[_quadro]
		_tela.material_override = _mat_partida
		if _luz != null:
			_luz.light_color = Color(0.72, 0.84, 1.0)
			_luz.light_energy = 2.4
		# Volta ao futebol: chiado de TV de sala (loop via finished).
		if _chiado != null:
			_chiado.volume_db = -24.0
			if not _chiado.playing:
				_chiado.play()


func _process(delta: float) -> void:
	_relogio += delta
	if _modo_estatica:
		# Neve: pisca a emissao e a luz, sem trocar UV de campo.
		var flicker := 0.55 + 0.45 * absf(sin(_relogio * 37.0)) + 0.15 * absf(sin(_relogio * 11.0))
		if _mat_neve != null:
			var g := 0.35 + 0.45 * flicker
			_mat_neve.emission = Color(g, g * 1.02, g * 1.05)
			_mat_neve.emission_energy_multiplier = 0.9 + flicker * 1.1
			_mat_neve.albedo_color = Color(0.08 + flicker * 0.1, 0.09 + flicker * 0.1, 0.1 + flicker * 0.1)
		if _luz != null:
			_luz.light_energy = 1.2 + flicker * 1.4
		return
	var passo := 1.0 / CADENCIA
	if _relogio < passo:
		return
	_relogio -= passo
	_quadro = (_quadro + 1) % QUADROS
	_tela.mesh = _malhas[_quadro]
	if _luz != null:
		# A energia oscila com o quadro. Nao e ruido aleatorio: e a imagem
		# mudando de media, e por isso ela bate junto com a troca de quadro em
		# vez de piscar por conta propria.
		_luz.light_energy = 2.15 + float((_quadro * 7) % 5) * 0.14

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
	_tela = MeshInstance3D.new()
	_tela.name = "Tubo"
	_tela.mesh = _malhas[0]
	_tela.material_override = load(MATERIAL_TELA) as Material
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


func _process(delta: float) -> void:
	_relogio += delta
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

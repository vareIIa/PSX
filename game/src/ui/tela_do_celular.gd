## A tela do celular que esta NA MAO do personagem, e nao na tela do jogo.
##
## Por que existe
## --------------
## A cena da estrada abria o aparelho do jogo por cima da imagem (o `Celular`,
## em CanvasLayer) enquanto o personagem segurava outro telefone em 3D: dois
## celulares na tela ao mesmo tempo. Aqui o mesmo app de Mensagens desenha num
## `SubViewport`, e a textura dele vai para o vidro do aparelho 3D. O jogador
## le a conversa, ve as letras sumindo e, por cima do aparelho, a estrada — um
## celular so, dentro do quadro.
##
## O desenho e o de `AppMensagens`, sem copia: o app nao sabe se esta num
## CanvasLayer ou num vidro.
class_name TelaDoCelular
extends Node

## Pixels da textura por unidade do app. Quatro: a tela chega a encher meio
## quadro na leitura, e com tres a letra de seis unidades ja borrava.
const ESCALA := 4.0
## A grade do app no vidro do iPhone 4S: a mesma largura (146) e a altura da tela
## 2:3 dele (74,9 x 49,9 mm). O aparelho do jogo continua com 186.
const ALTO := AppCelular.L * 1.5

var app: AppMensagens
## Aproxima o pe da conversa: 1 e a tela inteira; acima disso o ultimo balao e
## o rodape crescem ancorados no canto de baixo — e o que da para ler com o
## aparelho caido no tapete, a meio metro do olho.
var zoom: float = 1.0:
	set(valor):
		zoom = maxf(1.0, valor)
		_enquadrar()

var _vp: SubViewport
var _visor: Control


func _init(o_app: AppMensagens) -> void:
	app = o_app
	app.altura_tela = ALTO
	name = "TelaDoCelular"


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.name = "Tela"
	_vp.size = Vector2i(int(AppCelular.L * ESCALA), int(ALTO * ESCALA))
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_visor = Control.new()
	_visor.name = "Visor"
	_visor.size = Vector2(AppCelular.L, ALTO)
	_visor.draw.connect(_desenhar)
	_vp.add_child(_visor)
	_enquadrar()


func textura() -> ViewportTexture:
	return _vp.get_texture()


func _process(delta: float) -> void:
	if app == null:
		return
	app.processar(delta)
	_visor.queue_redraw()


func _enquadrar() -> void:
	if _visor == null:
		return
	var k := ESCALA * zoom
	_visor.scale = Vector2(k, k)
	var tam := Vector2(_vp.size)
	_visor.position = tam - Vector2(AppCelular.L, ALTO) * k


func _desenhar() -> void:
	if app == null:
		return
	app.desenhar(_visor)
	# A barra de status e a mesma do aparelho do jogo: sinal, REDE, a hora do
	# relogio do mundo e a bateria.
	app.barra_status(_visor, Color("0b0d10"), Color.WHITE, 0.62)

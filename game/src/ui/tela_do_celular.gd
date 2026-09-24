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

## Pixels da textura por unidade do app. Oito: a tela chega a encher meio
## quadro na leitura, e com quatro a letra de seis unidades ficava 1:1 com o
## pixel da tela ja em 1080p — em 4K borrava. O vidro faz a media de oito
## amostras por pixel (`Iphone4S.TELA_SHADER`), entao sobra resolucao sem
## serrilhar.
const ESCALA := 8.0
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
	app.f_reg = _vetorial(app.f_reg)
	app.f_semi = _vetorial(app.f_semi)
	app.f_bold = _vetorial(app.f_bold)


## A mesma fonte do app em campo de distancia (MSDF). O app escreve em letra de
## seis unidades e o visor amplia oito vezes: a fonte de sistema rasterizava a
## letra em seis pixels e a ampliacao a borrava — dobrar a textura nao mudava
## nada. Em MSDF a letra e desenhada no tamanho em que aparece.
static func _vetorial(f: Font) -> Font:
	var sf := f as SystemFont
	if sf == null:
		return f
	var v := sf.duplicate() as SystemFont
	v.multichannel_signed_distance_field = true
	v.msdf_size = 48
	v.msdf_pixel_range = 8
	return v


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

## Minimapa do canto. Um cartao de papel preso na tela, com o mapa dentro.
##
## Fica na camada 100, abaixo do pos-processamento em 150: assim ele recebe grao,
## dither e vinheta como o resto da imagem. Um mapa nitido por cima de uma cena
## suja denunciaria na hora que e uma camada de interface moderna colada num jogo
## que finge ser de 1999.
##
## Some dentro de casa e da loja. Ali o mapa da rua nao ajuda em nada, e o cartao
## ocupando o canto num comodo apertado atrapalha o unico que importa, que e olhar
## o comodo.
class_name Minimapa
extends CanvasLayer

const TELA := Vector2(480.0, 270.0)
const LADO := 82.0
const MARGEM := 7.0
const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"

## Metros por pixel. A 2,3 o cartao cobre 188 m de lado, o que da tres a quatro
## quadras — perto o bastante para servir de bussola e longe o bastante para a
## avenida seguinte aparecer antes de o jogador chegar nela.
const ESCALA := 2.3

var _mapa: Mapa
var _raiz: Control
var _rotulo: Label
var _alvo: Node3D
## O mapa so se redesenha quando o jogador anda. Mas o que ele MOSTRA tambem
## muda quando um chunk termina de carregar, e isso acontece com o jogador
## parado: quem chega num lugar e para de andar via o cartao congelado no estado
## de antes de a rua existir, coberto pela vela do desconhecido.
var _sujo: bool = false
var _desde_redesenho: float = 0.0


func _ready() -> void:
	layer = 100
	# Cena cortada esconde o HUD pelo grupo. Sem isto o cartao do canto fica
	# desenhado por cima da abertura, que e o unico momento do jogo em que a
	# tela nao pode ter interface nenhuma.
	add_to_group(&"hud")
	_montar()
	Interiores.entrou.connect(_ao_entrar)
	Interiores.saiu.connect(_ao_sair)
	Gps.destino_mudou.connect(_ao_mudar_destino)
	# A missao move o alfinete verde tanto ao comecar quanto ao acabar.
	Missoes.iniciou.connect(func(_m: Dictionary) -> void: _ao_mudar_destino())
	Missoes.concluiu.connect(func(_m: Dictionary) -> void: _ao_mudar_destino())
	_ao_mudar_destino()
	ChunkManager.chunk_carregado.connect(func(_c: Vector2i) -> void: _sujo = true)
	ChunkManager.chunk_descarregado.connect(func(_c: Vector2i) -> void: _sujo = true)
	set_process(true)


func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var canto := Vector2(TELA.x - LADO - MARGEM, MARGEM)

	# Sombra do cartao, dois pixels abaixo e a direita. E o que descola o papel do
	# fundo sem precisar de moldura grossa.
	var sombra := ColorRect.new()
	sombra.color = Color(0.05, 0.04, 0.03, 0.45)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	sombra.position = canto + Vector2(2.0, 2.0)
	sombra.size = Vector2(LADO, LADO)

	_mapa = Mapa.new()
	_mapa.estilo = Mapa.Estilo.CARTAO
	_mapa.metros_por_pixel = ESCALA
	_raiz.add_child(_mapa)
	_mapa.position = canto
	_mapa.size = Vector2(LADO, LADO)

	# Fita adesiva na quina de cima, como o resto da interface de papel.
	var fita := TextureRect.new()
	var caminho := UI % "ui_fita"
	if ResourceLoader.exists(caminho):
		fita.texture = load(caminho)
	fita.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fita.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fita)
	fita.position = canto + Vector2(LADO * 0.5 - 17.0, -5.0)
	fita.size = Vector2(34.0, 11.0)
	fita.pivot_offset = Vector2(17.0, 5.5)
	fita.rotation = deg_to_rad(-4.0)

	_rotulo = Label.new()
	_rotulo.add_theme_color_override(&"font_color", Color(0.84, 0.79, 0.66))
	if ResourceLoader.exists(FONTE_P):
		_rotulo.add_theme_font_override(&"font", load(FONTE_P))
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_rotulo)
	_rotulo.position = canto + Vector2(0.0, LADO + 1.0)
	_rotulo.size = Vector2(LADO, 12.0)


## Intervalo minimo entre redesenhos forcados. Redesenhar a cada chunk carregado
## custaria uma varredura de trinta e seis quadras por quadro durante todo o
## carregamento, e a diferenca nao se ve.
const INTERVALO := 0.45


func _process(delta: float) -> void:
	if not visible:
		return
	_desde_redesenho += delta
	if _alvo == null or not is_instance_valid(_alvo):
		_alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if _alvo == null:
			return
	var pos := _alvo.global_position
	if _desde_redesenho >= INTERVALO:
		# Quem pergunta pela rota e este cartao, e nao o aparelho: o GPS esta
		# fechado quase o tempo todo e nao tem `_process` rodando para notar que
		# o jogador saiu do caminho. O intervalo ja existe para o redesenho, e a
		# conta de desvio cabe folgada dentro dele.
		if Gps.manter_rota(pos):
			_sujo = true
	if _sujo and _desde_redesenho >= INTERVALO:
		_sujo = false
		_desde_redesenho = 0.0
		_mapa.forcar_redesenho()
	_mapa.apontar(pos, _alvo.rotation.y)
	# Com rota tracada o rotulo vira bussola. A coordenada de quadra continua
	# valendo, mas quem acabou de escolher um destino no GPS quer saber quanto
	# falta — e fechar o aparelho nao pode apagar a escolha da tela.
	var rota := Gps.rotulo_do_destino(pos)
	if rota != "":
		_rotulo.text = rota
		return
	# Coordenada em quadra, nao em metro. "128, -64" nao diz nada a ninguem; o
	# indice do quarteirao e o que o jogador consegue casar com o que ve.
	_rotulo.text = "%d-%d" % [floori(pos.x / Mapa.TAM), floori(pos.z / Mapa.TAM)]


func _ao_mudar_destino() -> void:
	_mapa.pinos = Gps.pinos_do_destino()
	_mapa.rota = Gps.rota_do_destino()
	_mapa.forcar_redesenho()


func _ao_entrar() -> void:
	visible = false


func _ao_sair() -> void:
	# Durante cena cortada o HUD fica desligado a pedido do Cinema. Restaurar
	# aqui no meio do corte mercado -> casa faria o cartao piscar entre os dois
	# comodos — exatamente o flash que a abertura nao pode ter.
	if Cinema.ativa:
		return
	visible = true
	_mapa.forcar_redesenho()

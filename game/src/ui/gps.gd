## Autoload. O aplicativo de GPS do celular, com o aparelho deitado na frente do
## rosto.
##
## O que ele e
## -----------
## O mesmo telefone de `celular.gd`, virado de lado. `M` abre direto neste app,
## sem passar pela grade de icones, porque olhar o mapa e a coisa que o jogador
## mais vai querer fazer com o aparelho e um menu no caminho de uma coisa
## frequente e pedagio. A grade continua la: quem abre o telefone com `C` e
## escolhe GPS cai exatamente nesta tela — e o mesmo app, nao uma segunda.
##
## Por que uma camada propria, e nao mais uma Tela do celular
## ----------------------------------------------------------
## Porque o aparelho muda de orientacao. `celular.gd` inteiro esta escrito em
## cima de um visor de 146 por 186 em pe, e a regra de ouro daquele arquivo —
## dezesseis letras por linha — e uma consequencia disso. Deitado o visor tem 269
## por 210, cabem trinta letras, e a barra de filtros e a lista de destinos so
## existem porque cabem. Enfiar isso la dentro seria manter dois conjuntos de
## medidas no mesmo arquivo, e um deles ficaria errado.
##
## O mundo continua rodando
## ------------------------
## Nao ha `get_tree().paused`, nem fundo opaco. O jogador para de andar — o
## aparelho ocupa as duas maos — mas a chuva cai, o transito passa e o pedestre
## atravessa atras do telefone. Esse e o ponto: o GPS e um objeto que a pessoa
## levanta no meio da rua, e nao uma tela de menu que congela o jogo. Se o mundo
## parasse, o telefone deixaria de estar na rua e viraria interface.
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"

const TELA := Vector2(480.0, 270.0)

# --- geometria do aparelho deitado -------------------------------------------
#
# O corpo e a MESMA textura de `fone_corpo.png` que o telefone em pe usa, girada
# noventa graus. Redesenhar um chassi deitado daria dois aparelhos diferentes no
# mesmo jogo, e o jogador repararia — e o mesmo telefone, so que na mao virada.
#
# As medidas saem por proporcao das constantes do celular em pe, e nao a olho:
# `CORPO` la tem 168 por 252 e o vao da tela cai em (11, 34) com 146 por 186.
# Deitado, a moldura grossa de cima e de baixo vira a das laterais, que e
# exatamente o que acontece com um telefone de verdade.

## Comprimento do aparelho na tela. Nao enche os 480: sobram 58 px de mundo de
## cada lado e a rua continua visivel em volta do telefone, que e o que faz a
## cena ler como "alguem levantou o celular" e nao como "abriu uma janela".
const CORPO_L := 364.0
const CORPO_S := CORPO_L * 168.0 / 252.0
const CORPO := Rect2((TELA.x - CORPO_L) * 0.5, (TELA.y - CORPO_S) * 0.5 - 1.0,
	CORPO_L, CORPO_S)

## Vao da tela, deitado. Derivado de CORPO pelas proporcoes acima.
const VISOR := Rect2(
	CORPO.position.x + CORPO_L * (1.0 - 220.0 / 252.0),
	CORPO.position.y + CORPO_S * (11.0 / 168.0),
	CORPO_L * (186.0 / 252.0),
	CORPO_S * (146.0 / 168.0))

## Inclinacao do aparelho. Um retangulo perfeitamente alinhado a tela e um
## painel; um grau e meio de torto e uma coisa segurada por uma mao.
const INCLINACAO := -1.4

# --- faixas dentro do visor --------------------------------------------------

const BARRA := 12.0
const FILTRO_Y := 13.0
const FILTRO_H := 15.0
const MAPA := Rect2(3.0, 30.0, VISOR.size.x - 6.0, 116.0)
const LISTA_Y := 149.0
const LINHA_H := 16.0
const LINHAS := 3

# Mesma paleta de LCD do telefone em pe. Duas paletas fariam o GPS parecer outro
# aparelho.
const FUNDO := Color("101a14")
const VERDE := Color("9fd8a0")
const VERDE_FRACO := Color("5c8a63")
const VERDE_FORTE := Color("d8f2c8")
const ALERTA := Color("d98a5c")
const CAIXA := Color("1c2c22")
const CHIP := Color("26402f")

## Escalas do mapa, em metros por pixel. A do meio e a de abrir: 3,6 poe 947 m
## de bairro nos 263 px do quadro, que e a distancia em que a avenida seguinte
## ainda cabe na tela. As pontas existem para achar a rua (1,8) e para achar o
## bairro (7,5).
const ESCALAS: Array[float] = [1.8, 2.6, 3.6, 5.2, 7.5]

## Raio da varredura de lugares, em chunks. Nao e o mapa inteiro porque o mapa e
## infinito: um GPS que promete listar tudo esta prometendo uma varredura que
## nunca termina.
##
## Doze e o numero que `tests/custo_gps.gd` mediu: 384 m em volta, 625 chunks,
## 7,3 ms e 213 lugares — dos quais 5 casas da fumaca, 12 mercados, 5 parques e
## 51 orelhoes. Oito chunks ja deixavam o filtro de mercado com dois itens, que
## e uma lista que nao vale a barra de filtros; dezesseis custavam 12,4 ms para
## acrescentar quase so portaria. Os 7 ms sao um quadro perdido, e ele cai
## enquanto o aparelho ainda esta subindo transparente na animacao de abertura,
## que e o instante menos visivel que existe. Reabrir perto nao paga nada: a
## varredura fica guardada ate o jogador andar REVARRER chunks.
const RAIO_CHUNKS := 12

## Quantos chunks o jogador precisa andar para a varredura valer a pena de novo.
## Com quatro, ele anda 128 m antes de a lista ser refeita, e a lista so muda de
## verdade nas pontas.
const REVARRER := 4

## Teto de alfinetes no mapa. Quarenta ja cobrem o quadro inteiro na escala
## fechada; alem disso e mancha, nao informacao.
const MAX_PINOS := 40

## Categorias do filtro, na ordem em que aparecem na barra.
##
## A casa da fumaca tem filtro proprio, e e a unica planta do jogo que tem. Pelo
## mesmo motivo de ela ter icone proprio no mapa: e o unico endereco da cidade
## que o jogador vai querer reencontrar depois de sair, e procurar uma porta
## verde em vinte quadras iguais e sorte, nao exploracao.
const FILTROS: Array[Dictionary] = [
	{"id": &"tudo", "nome": "TUDO", "icone": &"porta"},
	{"id": &"casa_fumaca", "nome": "CASA VERDE", "icone": &"casa_verde"},
	{"id": &"mercado", "nome": "MERCADO", "icone": &"mercado"},
	{"id": &"casa", "nome": "CASAS", "icone": &"casa"},
	{"id": &"apartamento", "nome": "PORTARIAS", "icone": &"predio"},
	{"id": &"parque", "nome": "PARQUES", "icone": &"parque"},
	{"id": &"telefone", "nome": "ORELHOES", "icone": &"telefone"},
]

## Nome que cada categoria recebe na lista. Curto por medida: sobram dezoito
## caracteres na linha depois do icone e do bloco de distancia.
const NOMES := {
	&"casa_fumaca": "CASA DA FUMACA",
	&"mercado": "MERCADO",
	&"casa": "CASA",
	&"apartamento": "PORTARIA",
	&"telefone": "ORELHAO",
}

const ROSA_DOS_VENTOS: Array[String] = ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]

signal abriu()
signal fechou()
## Emitido quando o jogador traca ou apaga uma rota. O minimapa ouve: escolher
## um destino no GPS e fechar o aparelho tem de deixar alguma coisa na tela, ou
## a escolha nao serviu para nada.
signal destino_mudou()

var ativo: bool = false
## Destino tracado, ou vazio. Mesma forma dos itens de `_lugares`.
var destino: Dictionary = {}

var _raiz: Control
var _visor: Control
var _mapa: Mapa
var _fonte: Font
var _mono: Font
var _icones: Dictionary[StringName, Texture2D] = {}

var _lugares: Array[Dictionary] = []
var _resultados: Array[Dictionary] = []
var _varrido_em := Vector2i(1 << 20, 1 << 20)
var _filtro: int = 0
var _sel: int = 0
var _rolagem: int = 0
var _escala: int = 2
var _centro := Vector3.ZERO
## Falso depois que o jogador escolhe um lugar da lista: dali em diante a vista
## acompanha a selecao, e nao a pessoa.
var _seguir: bool = true
## Verdadeiro quando o app foi aberto de dentro da grade de icones do telefone.
## Fechar volta para a grade, e nao para a rua: sair de um app cai no menu do
## aparelho, e nao com o telefone no bolso.
var _veio_do_celular: bool = false
var _relogio: float = 0.0
var _piscar: float = 0.0


func _ready() -> void:
	# Acima do celular em pe (128) e do pos-processamento nao: a camada de pos
	# esta em 150, e o telefone tem de receber grao e dither como o resto da
	# imagem. Um visor limpo por cima de uma cena suja entrega a interface.
	layer = 129
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte = load(FONTE_P) as Font
	_mono = load(FONTE_MONO) as Font
	for nome: StringName in [&"mercado", &"casa", &"casa_verde", &"predio",
			&"parque", &"telefone", &"porta", &"norte"]:
		var caminho := UI % ("icone_%s" % nome)
		if ResourceLoader.exists(caminho):
			_icones[nome] = load(caminho)
	_montar()
	_raiz.visible = false
	set_process(false)


# --- montagem ---------------------------------------------------------------

func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Gps"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.pivot_offset = TELA * 0.5

	# Sombra do aparelho sobre a rua. Sem ela o telefone flutua recortado na
	# frente do mundo; com ela ele tem um corpo entre a camera e a cena.
	var sombra := ColorRect.new()
	sombra.color = Color(0.02, 0.02, 0.02, 0.42)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	sombra.position = CORPO.position + Vector2(5.0, 6.0)
	sombra.size = CORPO.size

	# O chassi e a textura do telefone em pe, girada. Um TextureRect de
	# 90 graus manda o retangulo local [0..S]x[0..L] para x em [-L..0]: por isso
	# a posicao leva o comprimento inteiro somado no x.
	var corpo := TextureRect.new()
	var caminho := UI % "fone_corpo"
	if ResourceLoader.exists(caminho):
		corpo.texture = load(caminho)
	corpo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	corpo.stretch_mode = TextureRect.STRETCH_SCALE
	corpo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(corpo)
	corpo.size = Vector2(CORPO.size.y, CORPO.size.x)
	corpo.rotation_degrees = 90.0
	corpo.position = CORPO.position + Vector2(CORPO.size.x, 0.0)

	_visor = Control.new()
	_visor.name = "Visor"
	_visor.clip_contents = true
	_visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_visor)
	_visor.position = VISOR.position
	_visor.size = VISOR.size
	_visor.draw.connect(_desenhar)

	# Mesmo Mapa do cartao do canto e da pagina do pause. Terceira implementacao
	# do desenho do bairro seria a terceira chance de o mapa mentir.
	_mapa = Mapa.new()
	_mapa.estilo = Mapa.Estilo.PAGINA
	_mapa.metros_por_pixel = ESCALAS[_escala]
	_visor.add_child(_mapa)
	_mapa.position = MAPA.position
	_mapa.size = MAPA.size


# --- abrir e fechar ---------------------------------------------------------

func abrir(do_celular: bool = false) -> void:
	# Mesma guarda do lado de la: um aparelho de cada vez. Quem abre o GPS a
	# partir da grade de icones fecha o telefone em pe antes de chamar isto.
	if ativo or Celular.ativo:
		return
	ativo = true
	_veio_do_celular = do_celular
	_raiz.visible = true
	set_process(true)
	_travar_jogador(true)
	AudioDirector.tocar_ui(&"celular_abre", -8.0)

	_seguir = true
	_centro = _posicao_do_jogador()
	_varrer()
	_filtrar()
	_animar_entrada()
	_atualizar_mapa()
	abriu.emit()


func fechar() -> void:
	if not ativo:
		return
	ativo = false
	set_process(false)
	AudioDirector.tocar_ui(&"clique", -14.0)

	var volta := _veio_do_celular
	_veio_do_celular = false
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "rotation_degrees", -68.0, 0.16)
	t.tween_property(_raiz, "scale", Vector2(0.72, 0.72), 0.16)
	t.tween_property(_raiz, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.16)
	t.chain().tween_callback(func() -> void: _raiz.visible = false)

	if volta:
		# Voltou para a grade de icones: o telefone se levanta de novo na mao.
		Celular.abrir()
	else:
		_travar_jogador(false)
	fechou.emit()


## Levanta e DEITA o aparelho. A entrada nasce em pe, pequena e embaixo, como o
## telefone saindo do bolso, e termina deitada e no lugar. E a animacao que
## conta a historia inteira do gesto: sem ela o mapa so aparece, e um mapa que
## aparece e um menu.
func _animar_entrada() -> void:
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_raiz.rotation_degrees = -68.0
	_raiz.scale = Vector2(0.72, 0.72)
	_raiz.position = Vector2(0.0, 34.0)
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "modulate", Color.WHITE, 0.14)
	t.tween_property(_raiz, "rotation_degrees", INCLINACAO, 0.3)
	t.tween_property(_raiz, "scale", Vector2.ONE, 0.3)
	t.tween_property(_raiz, "position", Vector2.ZERO, 0.3)


func _travar_jogador(preso: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", preso)


## Onde o GPS acha que a pessoa esta.
##
## Dentro de casa o corpo do jogador esta dois mil metros acima da cidade, num
## comodo que nao tem endereco nenhum — o mapa da rua ali seria ruido puro. O
## aparelho usa entao o ponto de retorno, que e a calcada da porta por onde ele
## entrou, e a barra diz SEM SINAL. E o que um GPS faz de verdade quando perde o
## ceu: mostra o ultimo lugar em que ele sabia onde estava.
func _posicao_do_jogador() -> Vector3:
	if Interiores.dentro:
		return Interiores.posicao_de_retorno()
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return _centro
	return jogador.global_position


func _rumo_do_jogador() -> float:
	if Interiores.dentro:
		return 0.0
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	return 0.0 if jogador == null else jogador.rotation.y


func _process(delta: float) -> void:
	_relogio += delta
	_piscar += delta
	if _seguir:
		_centro = _posicao_do_jogador()
	_mapa.pos_jogador = _posicao_do_jogador()
	_mapa.rumo = _rumo_do_jogador()
	_mapa.centro = _centro
	# O visor pisca a meio segundo, como o do telefone em pe. O mapa nao entra
	# nesse ritmo: ele varre dezenas de quadras por desenho e so muda quando a
	# vista muda, entao quem manda nele e `_atualizar_mapa`.
	if fmod(_piscar, 0.5) < delta:
		_visor.queue_redraw()


# --- varredura de lugares ---------------------------------------------------

## Le a cidade sem construir nada. `pontos_de_interesse` e estatica e devolve o
## mesmo resultado para a mesma coordenada, entao o GPS enxerga vinte quadras
## alem do que o ChunkManager carregou — e por isso que ele consegue apontar uma
## casa da fumaca em rua onde o jogador nunca pisou.
func _varrer() -> void:
	var aqui := Vector2i(floori(_centro.x / Mapa.TAM), floori(_centro.z / Mapa.TAM))
	var perto := absi(aqui.x - _varrido_em.x) < REVARRER 		and absi(aqui.y - _varrido_em.y) < REVARRER
	if perto and not _lugares.is_empty():
		return
	_varrido_em = aqui
	_lugares.clear()
	for cz in range(aqui.y - RAIO_CHUNKS, aqui.y + RAIO_CHUNKS + 1):
		for cx in range(aqui.x - RAIO_CHUNKS, aqui.x + RAIO_CHUNKS + 1):
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				var lugar := _lugar_de(ponto, cx, cz)
				if not lugar.is_empty():
					_lugares.append(lugar)


func _lugar_de(ponto: Dictionary, cx: int, cz: int) -> Dictionary:
	var categoria: StringName = ponto["tipo"]
	if categoria == &"porta":
		categoria = ponto["interior"]
	var p: Vector3 = ponto["pos"]
	var mundo := Vector3(float(cx) * Mapa.TAM + p.x, p.y, float(cz) * Mapa.TAM + p.z)
	var chunk := Vector2i(cx, cz)
	return {
		"categoria": categoria,
		"nome": String(ponto.get("nome", NOMES.get(categoria, "PONTO"))),
		"mundo": mundo,
		"chunk": chunk,
		"icone": _icone_de(categoria),
		"endereco": "%d-%d" % [absi(cx), absi(cz)],
	}


static func _icone_de(categoria: StringName) -> StringName:
	match categoria:
		&"casa_fumaca":
			return &"casa_verde"
		&"apartamento":
			return &"predio"
		_:
			return categoria


func _filtrar() -> void:
	var id: StringName = FILTROS[_filtro]["id"]
	var de := _posicao_do_jogador()
	_resultados.clear()
	for lugar: Dictionary in _lugares:
		if id != &"tudo" and lugar["categoria"] != id:
			continue
		var copia := lugar.duplicate()
		copia["distancia"] = _plano(de).distance_to(_plano(lugar["mundo"]))
		_resultados.append(copia)
	_resultados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distancia"]) < float(b["distancia"]))
	_sel = 0
	_rolagem = 0


static func _plano(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# --- mapa -------------------------------------------------------------------

func _atualizar_mapa() -> void:
	_mapa.metros_por_pixel = ESCALAS[_escala]
	_mapa.centro = _centro
	_mapa.pos_jogador = _posicao_do_jogador()
	_mapa.rumo = _rumo_do_jogador()
	_mapa.pinos = _pinos()
	_mapa.forcar_redesenho()
	_visor.queue_redraw()


## Alfinetes do filtro atual.
##
## Em TUDO nao ha alfinete nenhum, e nao por economia: o alfinete atravessa a
## nevoa do que nao foi visitado, e um TUDO alfinetado entregaria o bairro
## inteiro na primeira vez que o jogador abrisse o aparelho. Pedir uma categoria
## e uma pergunta; a resposta revela o que foi perguntado e mais nada.
func _pinos() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not destino.is_empty():
		saida.append({"pos": _plano(destino["mundo"]), "destaque": true})
	if StringName(FILTROS[_filtro]["id"]) == &"tudo":
		return saida
	for i in mini(_resultados.size(), MAX_PINOS):
		var r := _resultados[i]
		saida.append({
			"pos": _plano(r["mundo"]),
			"icone": r["icone"],
			"destaque": i == _sel,
		})
	return saida


# --- desenho ----------------------------------------------------------------

func _texto(pos: Vector2, texto: String, cor: Color = VERDE, fonte: Font = null,
		largura: float = -1.0,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := fonte if fonte != null else _fonte
	if f == null:
		return
	_visor.draw_string(f, pos, texto, alinhamento, largura, 11, cor)


func _caixa(r: Rect2, cor: Color, preenchido: bool = true) -> void:
	_visor.draw_rect(r, cor, preenchido, 1.0 if not preenchido else -1.0)


func _desenhar() -> void:
	_visor.draw_rect(Rect2(Vector2.ZERO, VISOR.size), FUNDO)
	_desenhar_barra()
	_desenhar_filtros()
	_desenhar_moldura_do_mapa()
	_desenhar_lista()
	_desenhar_rodape()

	# Varredura do LCD, igual a do telefone em pe. E o que diz que aquilo e uma
	# tela dentro do mundo e nao um desenho colado na camera.
	for y in range(0, int(VISOR.size.y), 3):
		_visor.draw_rect(Rect2(0.0, float(y), VISOR.size.x, 1.0),
			Color(0.0, 0.0, 0.0, 0.16))


func _desenhar_barra() -> void:
	_caixa(Rect2(0.0, 0.0, VISOR.size.x, BARRA), CAIXA)
	# Tres colunas que nao se encostam: sinal a esquerda ate 60 px, lugar no meio
	# ate 200, relogio e bateria no que sobra. Foi medido, e nao estimado — com o
	# rotulo de satelite por extenso, "TERRENO BALDIO" centralizado entrava em
	# cima dele.
	var sinal := "S/SINAL" if Interiores.dentro else "GPS %d" % (
		7 + int(fmod(_relogio, 3.0)))
	_texto(Vector2(4.0, 9.0), sinal, ALERTA if Interiores.dentro else VERDE_FRACO)

	_texto(Vector2(60.0, 9.0), _mapa.onde_estou().substr(0, 16),
		VERDE_FORTE, null, 140.0, HORIZONTAL_ALIGNMENT_CENTER)

	var minutos := 134 + int(_relogio / 6.0)
	_texto(Vector2(VISOR.size.x - 66.0, 9.0),
		"%02d:%02d" % [(minutos / 60) % 24, minutos % 60], VERDE, _mono, 42.0,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var largura := 12.0
	var x := VISOR.size.x - largura - 4.0
	_caixa(Rect2(x, 3.0, largura, 6.0), VERDE_FRACO, false)
	_caixa(Rect2(x + largura, 5.0, 1.5, 2.0), VERDE_FRACO)
	_caixa(Rect2(x + 1.0, 4.0, (largura - 2.0) * Celular.bateria, 4.0),
		VERDE if Celular.bateria > 0.2 else ALERTA)


## Barra de categorias. Mostra tres de uma vez, com a escolhida no meio e larga:
## a lista inteira nao cabe nos 269 px, e cortar sem mostrar vizinho esconderia
## que ha mais filtro para os lados. A do meio ganha o dobro de largura porque e
## a unica que precisa caber nome mais contagem — "CASA VERDE (3)".
const CHIP_LADO := 72.0


func _desenhar_filtros() -> void:
	var meio := VISOR.size.x - CHIP_LADO * 2.0
	for passo: int in [-1, 0, 1]:
		var i := posmod(_filtro + passo, FILTROS.size())
		var x := 0.0 if passo < 0 else (CHIP_LADO if passo == 0 else CHIP_LADO + meio)
		var largura := CHIP_LADO if passo != 0 else meio
		var r := Rect2(x + 1.0, FILTRO_Y, largura - 2.0, FILTRO_H)
		var atual := passo == 0
		_caixa(r, CHIP if atual else CAIXA)
		var nome := String(FILTROS[i]["nome"])
		nome = "%s (%d)" % [nome, _resultados.size()] if atual else nome.substr(0, 9)
		_texto(Vector2(r.position.x, r.position.y + 11.0), nome,
			VERDE_FORTE if atual else VERDE_FRACO, null, r.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)


func _desenhar_moldura_do_mapa() -> void:
	_caixa(MAPA.grow(1.0), VERDE_FRACO, false)
	# Escala escrita por cima do canto do mapa. Sem ela "300 m" no visor nao quer
	# dizer nada: o jogador nao tem como saber quanto do bairro esta vendo.
	var barra := 40.0
	var metros := barra * ESCALAS[_escala]
	var y := MAPA.end.y - 6.0
	var x := MAPA.position.x + 5.0
	_visor.draw_rect(Rect2(x, y, barra, 3.0), Color(0.0, 0.0, 0.0, 0.55))
	_visor.draw_rect(Rect2(x, y, barra, 1.0), VERDE_FORTE)
	_texto(Vector2(x + barra + 4.0, y + 4.0), "%d M" % roundi(metros), VERDE_FORTE)


## Colunas da linha da lista. O nome come tudo o que sobra depois do icone e do
## bloco de distancia, porque e o unico campo em que "CASA DA FUMACA" tem de
## caber inteiro: cortado em "CASA DA FUM" ele deixa de ser o lugar que o
## jogador esta procurando e vira mais uma casa.
const COL_ICONE := 5.0
const COL_NOME := 19.0
const COL_DISTANCIA := 180.0


func _desenhar_lista() -> void:
	if _resultados.is_empty():
		_caixa(Rect2(2.0, LISTA_Y, VISOR.size.x - 4.0, LINHA_H * float(LINHAS)), CAIXA)
		_texto(Vector2(8.0, LISTA_Y + 14.0), "NADA DESTA CATEGORIA", VERDE)
		_texto(Vector2(8.0, LISTA_Y + 28.0), "NUM RAIO DE %d M." % roundi(
			float(RAIO_CHUNKS) * Mapa.TAM), VERDE_FRACO)
		return

	var de := _posicao_do_jogador()
	for k in LINHAS:
		var i := _rolagem + k
		if i >= _resultados.size():
			break
		var r := _resultados[i]
		var y := LISTA_Y + float(k) * LINHA_H
		var escolhido := i == _sel
		if escolhido:
			_caixa(Rect2(2.0, y, VISOR.size.x - 6.0, LINHA_H - 1.0), CHIP)

		# Icone da categoria na frente do nome. Numa lista de vinte linhas
		# parecidas e o que deixa achar o mercado sem ler nada.
		var icone: Texture2D = _icones.get(r["icone"])
		if icone != null:
			_visor.draw_texture_rect(icone,
				Rect2(Vector2(COL_ICONE, y + 2.0), Vector2(11.0, 11.0)), false)

		# Quadra nunca visitada sai em tom fraco. O GPS sabe que o lugar existe
		# — e o que um GPS faz — mas quem nao esteve la nao tem por que ver o
		# nome com o mesmo peso de quem ja foi.
		var conhecido := WorldState.visitado(r["chunk"])
		var cor := VERDE_FORTE if escolhido else (VERDE if conhecido else VERDE_FRACO)
		_texto(Vector2(COL_NOME, y + 11.0), String(r["nome"]).substr(0, 18), cor)
		_texto(Vector2(COL_DISTANCIA, y + 11.0), "%s %s" % [
			_distancia(float(r["distancia"])), _bussola(de, r["mundo"])],
			cor, _mono, VISOR.size.x - COL_DISTANCIA - 8.0,
			HORIZONTAL_ALIGNMENT_RIGHT)

		# Moldura cor de alerta na linha que ja e a rota. Sem ela, sair da linha
		# com a seta apaga o unico sinal de qual delas foi escolhida.
		if not destino.is_empty() and destino["mundo"] == r["mundo"]:
			_caixa(Rect2(2.0, y, VISOR.size.x - 6.0, LINHA_H - 1.0), ALERTA, false)

	# Trilho de rolagem na borda direita. Tres linhas de uma lista de quarenta
	# precisam dizer que ha mais trinta e sete.
	if _resultados.size() > LINHAS:
		var altura := LINHA_H * float(LINHAS)
		var polegar := maxf(6.0, altura * float(LINHAS) / float(_resultados.size()))
		var t := float(_rolagem) / float(maxi(1, _resultados.size() - LINHAS))
		_caixa(Rect2(VISOR.size.x - 3.0, LISTA_Y, 2.0, altura), CAIXA)
		_caixa(Rect2(VISOR.size.x - 3.0, LISTA_Y + (altura - polegar) * t, 2.0,
			polegar), VERDE_FRACO)


func _desenhar_rodape() -> void:
	var y := VISOR.size.y - 3.0
	var meia := VISOR.size.x * 0.5
	if destino.is_empty():
		_texto(Vector2(4.0, y), "[W/S] LISTA  [A/D] FILTRO  [E] ROTA", VERDE_FRACO)
		_texto(Vector2(meia, y), "[Z/X] ZOOM  [ESC] SAI", VERDE_FRACO, null,
			meia - 4.0, HORIZONTAL_ALIGNMENT_RIGHT)
		return
	var de := _posicao_do_jogador()
	_texto(Vector2(4.0, y), "ROTA %s %s  %s %s" % [
		String(destino["nome"]).substr(0, 16), String(destino["endereco"]),
		_distancia(_plano(de).distance_to(_plano(destino["mundo"]))),
		_bussola(de, destino["mundo"])], ALERTA)
	_texto(Vector2(meia, y), "[E] APAGA  [ESC] SAI", VERDE_FRACO, null,
		meia - 4.0, HORIZONTAL_ALIGNMENT_RIGHT)


static func _distancia(metros: float) -> String:
	return "%d M" % roundi(metros) if metros < 1000.0 else "%.1f KM" % (metros / 1000.0)


## Rumo em ponto cardeal. O norte do mundo e o menos Z, que e o mesmo norte que a
## rosa do minimapa desenha — se as duas discordassem, o GPS mandaria o jogador
## para o lado contrario do que a bussola do canto mostra.
static func _bussola(de: Vector3, para: Vector3) -> String:
	var d := _plano(para) - _plano(de)
	if d.length_squared() < 1.0:
		return "AQUI"
	var setor := roundi(atan2(d.x, -d.y) / (PI / 4.0))
	return ROSA_DOS_VENTOS[posmod(setor, 8)]


# --- entrada ----------------------------------------------------------------

func _pode_abrir() -> bool:
	return not (Conversa.ativo or Dialogo.ativo or Documento.ativo
		or get_tree().paused)


func _input(evento: InputEvent) -> void:
	if not ativo:
		# `M` abre o GPS direto, sem passar pela grade de icones. Com o telefone
		# ja aberto na mao, `M` continua valendo: ele troca de app.
		if evento.is_action_pressed("gps") and _pode_abrir():
			var do_celular := Celular.ativo
			if do_celular:
				Celular.fechar()
			abrir(do_celular)
			get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("gps") or evento.is_action_pressed("celular"):
		# Fechar pelo mesmo botao que abriu. Vindo da grade, `M` sai do app para
		# a rua direto — quem apertou M queria o mapa, nao o menu do aparelho.
		_veio_do_celular = false
		fechar()
		get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("pausa"):
		fechar()
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		_tracar_rota()
	elif evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
		_andar_lista(1)
	elif evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
		_andar_lista(-1)
	elif evento.is_action_pressed("mover_dir") or evento.is_action_pressed("ui_right"):
		_trocar_filtro(1)
	elif evento.is_action_pressed("mover_esq") or evento.is_action_pressed("ui_left"):
		_trocar_filtro(-1)
	else:
		var tecla := evento as InputEventKey
		if tecla == null or not tecla.pressed or tecla.echo:
			return
		match tecla.keycode:
			KEY_Z, KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom(1)
			KEY_X, KEY_EQUAL, KEY_KP_ADD:
				_zoom(-1)
			KEY_Q:
				# Voltar a vista para a pessoa. Depois de percorrer a lista o
				# mapa esta em cima de um mercado a trezentos metros, e achar o
				# proprio corpo de novo nao pode custar fechar o aparelho.
				_seguir = true
				_centro = _posicao_do_jogador()
				AudioDirector.tocar_ui(&"clique", -20.0)
				_atualizar_mapa()
			_:
				return
	get_viewport().set_input_as_handled()


func _andar_lista(passo: int) -> void:
	if _resultados.is_empty():
		return
	AudioDirector.tocar_ui(&"clique", -24.0)
	_sel = posmod(_sel + passo, _resultados.size())
	_rolagem = clampi(_rolagem, maxi(0, _sel - LINHAS + 1), _sel)
	_rolagem = mini(_rolagem, maxi(0, _resultados.size() - LINHAS))
	# Percorrer a lista leva a vista junto. E a unica maneira de o nome na linha
	# virar um lugar: sem isso o jogador le "MERCADO 240 M SE" e continua sem
	# saber em que rua.
	_seguir = false
	_centro = _resultados[_sel]["mundo"]
	_atualizar_mapa()


func _trocar_filtro(passo: int) -> void:
	AudioDirector.tocar_ui(&"celular_tecla", -18.0)
	_filtro = posmod(_filtro + passo, FILTROS.size())
	_filtrar()
	_seguir = true
	_centro = _posicao_do_jogador()
	_atualizar_mapa()


func _zoom(passo: int) -> void:
	var novo := clampi(_escala + passo, 0, ESCALAS.size() - 1)
	if novo == _escala:
		return
	_escala = novo
	AudioDirector.tocar_ui(&"clique", -20.0)
	_atualizar_mapa()


func _tracar_rota() -> void:
	if _resultados.is_empty():
		return
	var alvo := _resultados[_sel]
	if not destino.is_empty() and destino["mundo"] == alvo["mundo"]:
		destino = {}
		AudioDirector.tocar_ui(&"clique", -12.0)
	else:
		destino = alvo.duplicate()
		AudioDirector.tocar_ui(&"celular_ok", -10.0)
	destino_mudou.emit()
	_atualizar_mapa()


# --- consulta de fora -------------------------------------------------------

## Alfinete do destino para quem desenha outro mapa. Vazio quando nao ha rota.
func pinos_do_destino() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not destino.is_empty():
		saida.append({"pos": _plano(destino["mundo"]), "destaque": true})
	return saida


## Distancia e rumo ate a rota, ja formatados. Vazio quando nao ha rota.
func rotulo_do_destino(de: Vector3) -> String:
	if destino.is_empty():
		return ""
	return "%s %s" % [_distancia(_plano(de).distance_to(_plano(destino["mundo"]))),
		_bussola(de, destino["mundo"])]


## Publica: a verificacao automatizada traca a rota do primeiro resultado sem
## depender de tecla.
func tracar_rota_no_primeiro() -> void:
	_sel = 0
	_tracar_rota()


## Publica: a verificacao automatizada abre o app e escolhe uma categoria sem
## depender de tecla.
func filtrar_por(id: StringName) -> int:
	for i in FILTROS.size():
		if StringName(FILTROS[i]["id"]) == id:
			_filtro = i
			_filtrar()
			_atualizar_mapa()
			return _resultados.size()
	return -1

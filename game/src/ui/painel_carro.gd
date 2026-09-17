## O painel do carro: conta-giros, velocimetro, marcha e as luzes do painel.
##
## Por que ele existe
## ------------------
## Porque ate aqui a instrumentacao do carro era uma linha de texto emprestada do
## prompt de interacao — "3a  47 km/h  [Ctrl] buzina". Isso informa e nao
## instrumenta: o numero aparece no mesmo lugar em que aparece "Entrar na casa",
## com a mesma tinta, e some junto com ele. Dirigir e a unica coisa no jogo em
## que o jogador olha um valor CONTINUO o tempo todo, e valor continuo se le em
## angulo, nao em digito.
##
## Por que ele e escuro e o resto do HUD e de papel
## ------------------------------------------------
## O resto da interface e papel porque e do JOGADOR: o cartao de missao, o
## minimapa, a ficha. Este nao e. Ele e do carro — e a unica peca de HUD que
## pertence a um objeto do mundo, aparece quando se senta nele e some quando se
## desce. Desenha-lo em papel o faria ler como mais uma anotacao do investigador,
## e o que ele tem de parecer e o mostrador atras do volante.
##
## O desenho de 17/09/2026
## -----------------------
## A primeira versao era uma caixa de 112x52 com um relogio de 40 px, solta a
## direita do meio da tela e encostada no prompt de teclas — o jogador pediu que
## ela ficasse mais bonita e mais bem posta. Virou um mostrador redondo no canto
## de baixo da direita, alinhado com o minimapa: arco de segmentos para a
## rotacao, numero grande para a velocidade, a marcha numa caixa que acende na
## hora de trocar, e as luzes que um painel tem — setas, farol e freio de mao. A
## geometria inteira mora em `PainelLayout`, e a posicao sai da vinheta do
## estilo em uso; o porque esta la.
##
## Camada 100, como o minimapa: abaixo do pos-processamento, para o mostrador
## receber grao e dither junto com a cena. Um painel nitido sobre uma imagem
## suja denuncia na hora que e interface moderna colada num jogo de 1999.
class_name PainelCarro
extends CanvasLayer

# --- tinta ------------------------------------------------------------------
# Paleta de mostrador de carro de 98: plastico preto, risco cor de osso, luz
# ambar. Nao sai do `UiEstilo` porque aquela e a paleta do PAPEL, e este e o
# unico pedaco de HUD que pertence a um objeto do mundo. Ver o cabecalho.
const MOLDURA := Color("0d0b08")
## A face escurece para a borda: o meio um pouco mais claro da ao disco o
## volume de um vidro, e o numero fica sobre a parte clara.
const FUNDO_BORDA := Color("15110c")
const FUNDO_MEIO := Color("2b231b")
const RIMO := Color("5d5044")
const RISCO := Color("b8a88c")
const NUMERO := Color("f0e2c0")
const APAGADO := Color("7d7061")
## Segmento aceso no uso normal, perto da troca e no vermelho.
const OSSO := Color("e6d8b6")
const AMBAR := Color("f09a3a")
const VERMELHO := Color("b23a22")
const VERMELHO_ACESO := Color("f24b2c")
## Seta e farol: verde de lampada de painel.
const VERDE := Color("5ad26a")
## Luz de troca. Acende no fim da faixa e pisca quando o limitador corta.
const LUZ_TROCA := Color("f08a30")

## Quao depressa o arco e o numero perseguem o valor real.
##
## Mostrador que nao atrasa nao le como mostrador: um instrumento de agulha tem
## massa, e e o atraso que o olho reconhece como "o motor esta subindo". Rapido
## demais e ele treme com o ruido da fisica; devagar demais e ele mente.
const INERCIA_GIRO := 11.0
const INERCIA_KMH := 7.0

## A luz de troca acende a partir daqui, em giro normalizado. Os segmentos
## dessa faixa ficam ambar.
const ACENDE_TROCA := 0.82
const PISCA := 0.09

## Mil rpm por ponto na borda do mostrador.
const RPM_POR_PONTO := 1000.0

## As palavras da linha de baixo do numero. A bancada mede que cada uma cabe.
const ROTULO_UNIDADE := "km/h"
const ROTULO_MOTOR := "MOTOR"
const ROTULO_VIROU := "VIROU"

var _face: Control
var _fonte_t: Font
var _fonte_m: Font
var _fonte_p: Font
## Centro do mostrador, em coordenadas de tela. Sai de `PainelLayout.centro`.
var _c := Vector2.ZERO
var _vinheta_usada := -1.0
## Linhas com borda suave? So quando a interface e desenhada na resolucao da
## janela (MODERNO). No PS1 STYLE ela e desenhada em 480x270 e ampliada, e a
## borda suave vira borrao.
var _aa := false

var _carro: Carro
## Leitura congelada, para a bancada fotografar um estado sem carro.
var _fixo := false
var _giro: float = 0.0
var _kmh: float = 0.0
var _marcha: String = "1"
var _cortando: bool = false
var _freio_mao: bool = false
var _capotou: bool = false
var _ligado: bool = false
var _farol: bool = false
var _seta: int = 0
var _seta_acesa: bool = false
var _pisca_t: float = 0.0
## Onde o vermelho comeca NESTE carro, e o fundo de escala dele. Lidos ao
## entrar: nao mudam dirigindo.
var _vermelho: float = 0.84
var _fundo_rpm: float = 6000.0


func _ready() -> void:
	layer = UiEstilo.CAMADA_MAPA
	# Cena cortada esconde o HUD pelo grupo.
	add_to_group(&"hud")
	# Como o teste encontra o painel sem o Player ter de entrega-lo.
	add_to_group(&"painel_carro")
	visible = false

	_fonte_t = load(UiEstilo.FONTE_T) as Font
	_fonte_m = load(UiEstilo.FONTE_M) as Font
	_fonte_p = load(UiEstilo.FONTE_P) as Font

	_face = Control.new()
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.position = Vector2.ZERO
	_face.size = UiEstilo.TELA
	add_child(_face)
	_face.draw.connect(_desenhar)
	_reposicionar()
	set_process(false)


# --- ligar e desligar -------------------------------------------------------

## Passa a acompanhar um carro. `null` esconde o painel.
func acompanhar(c: Carro) -> void:
	_carro = c
	_fixo = false
	visible = c != null
	set_process(c != null)
	if c == null:
		return
	# Comeca ja no valor certo: um arco que sobe do zero toda vez que se entra
	# num carro em movimento e uma animacao que ninguem pediu.
	_vermelho = c.vermelho_normalizado()
	_fundo_rpm = c.giro_de_fundo()
	_giro = c.giro_normalizado()
	_kmh = absf(c.velocidade()) * 3.6
	_ler_carro()
	_reposicionar()
	_face.queue_redraw()


## Mostra um estado fixo, sem carro. E o que a bancada usa para fotografar o
## painel em cada situacao sem precisar dirigir ate ela.
##
## Chaves: giro, kmh, marcha, ligado, cortando, freio_mao, capotou, farol,
## seta (-1, 0, 1), seta_acesa, vermelho, fundo_rpm.
func mostrar_fixo(d: Dictionary) -> void:
	_carro = null
	_fixo = true
	_giro = float(d.get("giro", 0.0))
	_kmh = float(d.get("kmh", 0.0))
	_marcha = String(d.get("marcha", "1"))
	_ligado = bool(d.get("ligado", true))
	_cortando = bool(d.get("cortando", false))
	_freio_mao = bool(d.get("freio_mao", false))
	_capotou = bool(d.get("capotou", false))
	_farol = bool(d.get("farol", _ligado))
	_seta = int(d.get("seta", 0))
	_seta_acesa = bool(d.get("seta_acesa", _seta != 0))
	_vermelho = float(d.get("vermelho", 0.84))
	_fundo_rpm = float(d.get("fundo_rpm", 6000.0))
	_pisca_t = 0.0
	visible = true
	set_process(false)
	_reposicionar()
	_face.queue_redraw()


func _process(delta: float) -> void:
	if _fixo:
		return
	if not is_instance_valid(_carro):
		acompanhar(null)
		return
	_pisca_t += delta
	_giro = lerpf(_giro, _carro.giro_normalizado(), minf(1.0, INERCIA_GIRO * delta))
	_kmh = lerpf(_kmh, absf(_carro.velocidade()) * 3.6,
		minf(1.0, INERCIA_KMH * delta))
	_ler_carro()
	_reposicionar()
	_face.queue_redraw()


func _ler_carro() -> void:
	_marcha = _carro.rotulo_marcha()
	_cortando = _carro.cortando()
	_freio_mao = _carro.freio_de_mao()
	_capotou = _carro.capotado()
	_ligado = _carro.ligado
	_farol = _carro.fachos_acesos() > 0
	_seta = _carro.seta()
	_seta_acesa = _carro.seta_acesa()


## Recalcula o centro quando a vinheta muda — troca de estilo ou o controle de
## vinheta das opcoes.
func _reposicionar() -> void:
	var v := _vinheta()
	var janela := get_window()
	_aa = janela != null \
		and janela.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if is_equal_approx(v, _vinheta_usada):
		return
	_vinheta_usada = v
	_c = PainelLayout.centro(v)


## A intensidade da vinheta em uso. `Settings` e autoload: lido pelo caminho
## longo, para esta classe continuar compilando onde ele nao existe.
func _vinheta() -> float:
	var s := get_node_or_null(^"/root/Settings")
	if s == null:
		return UiEstilo.VINHETA_PADRAO
	return float(s.get(&"vignette"))


# --- o que o teste le -------------------------------------------------------

func mostrado() -> bool:
	return visible


func kmh_mostrado() -> float:
	return _kmh


func giro_mostrado() -> float:
	return _giro


func marcha_mostrada() -> String:
	return _marcha


## Quanto sobra, no pior caso, entre a palavra mais larga da linha de baixo e o
## arco. Negativo quer dizer que alguma encosta nos segmentos.
func folga_do_rotulo() -> float:
	var y := PainelLayout.ROTULO.y + PainelLayout.ROTULO_TAM.y * 0.5
	var corda := PainelLayout.corda_livre(y)
	var pior := INF
	for palavra: String in [ROTULO_UNIDADE, ROTULO_MOTOR, ROTULO_VIROU]:
		pior = minf(pior, corda - UiEstilo.largura(_fonte_p, palavra))
	return pior


## O mesmo para o numero: tres algarismos na casa fixa.
func folga_do_numero() -> float:
	var casa := UiEstilo.largura(_fonte_t, "0")
	var y := PainelLayout.NUMERO.y - PainelLayout.NUMERO_TAM.y * 0.5
	return PainelLayout.corda_livre(y) - casa * 3.0


## O centro do mostrador na tela.
func centro() -> Vector2:
	return _c


## O pior fator de vinheta sobre o texto do painel. Abaixo de
## `UiEstilo.VINHETA_MIN` o numero apaga pela borda.
func vinheta_da_quina() -> float:
	return PainelLayout.vinheta_do_texto(_c, _vinheta())


# --- desenho ----------------------------------------------------------------

func _desenhar() -> void:
	_disco()
	_arco()
	_setas()
	_velocidade()
	_marcha_engatada()
	_lampadas()


## O corpo do mostrador.
##
## Sombra, aro escuro, face com degrade e um fio de luz no alto a esquerda. O fio
## nao e enfeite: sem ele, um disco escuro sobre uma rua escura nao le como
## PECA, le como buraco na imagem — e o mesmo motivo pelo qual o minimapa tem
## contorno de 1 px, escrito em `UiEstilo.PAPEL_BORDA`.
func _disco() -> void:
	var r := PainelLayout.RAIO
	_face.draw_circle(_c + Vector2(2.0, 2.0), r + 0.5,
		Color(0.02, 0.015, 0.01, 0.55), true, -1.0, _aa)
	_face.draw_circle(_c, r, MOLDURA, true, -1.0, _aa)
	const ANEIS := 6
	for k in ANEIS:
		var t := float(k) / float(ANEIS - 1)
		_face.draw_circle(_c, lerpf(r - 1.5, r * 0.3, t),
			FUNDO_BORDA.lerp(FUNDO_MEIO, t), true, -1.0, _aa)
	# O fio de luz: de 195 a 295 graus na convencao da tela, que e o alto a
	# esquerda — de onde a luz de um painel de verdade costuma vir.
	_face.draw_arc(_c, r - 0.5, deg_to_rad(195.0), deg_to_rad(295.0), 24,
		Color(RIMO, 0.95), 1.0, _aa)
	# Um fio escuro entre o arco e a face: sem ele o arco apagado se mistura ao
	# degrade e o disco perde a borda de dentro.
	_face.draw_arc(_c, PainelLayout.ARCO_DENTRO - 1.0, 0.0, TAU, 48,
		Color(MOLDURA, 0.8), 1.0, _aa)
	# Um ponto por mil rpm, entre o arco e o aro. E a escala do angulo: um
	# Fusca mostra seis pontos, um Marea oito.
	var pontos := int(floorf(_fundo_rpm / RPM_POR_PONTO))
	for k in pontos + 1:
		var t := float(k) * RPM_POR_PONTO / maxf(_fundo_rpm, 1.0)
		var cor := RISCO if t < _vermelho else VERMELHO
		_face.draw_circle(_c + PainelLayout.no_arco(t, PainelLayout.ARCO_FORA + 1.6),
			0.75, Color(cor, 0.9), true, -1.0, _aa)


## O arco de segmentos da rotacao.
##
## Aceso ate o giro atual, osso no uso normal, ambar na faixa de troca e
## vermelho no corte. Apagado, cada segmento continua desenhado em sombra: e o
## arco vazio que da a escala, como a agulha em repouso num relogio.
func _arco() -> void:
	var n := PainelLayout.acesos(_giro) if _ligado else 0
	var total := PainelLayout.SEGMENTOS
	var primeiro_verm := int(ceilf(_vermelho * float(total) - 0.001))
	var primeiro_ambar := int(ceilf(ACENDE_TROCA * float(total) - 0.001))
	var raio := (PainelLayout.ARCO_FORA + PainelLayout.ARCO_DENTRO) * 0.5
	var larg := PainelLayout.ARCO_FORA - PainelLayout.ARCO_DENTRO
	# O brilho vai numa passada so, antes: desenhado junto de cada segmento ele
	# tingiria o vizinho ja pintado.
	if _aa:
		for k in n:
			var a := PainelLayout.angulos_do_segmento(k)
			_face.draw_arc(_c, raio, a.x, a.y, 4,
				Color(_cor_acesa(k, primeiro_ambar, primeiro_verm), 0.22),
				larg + 3.5, true)
	for k in total:
		var a := PainelLayout.angulos_do_segmento(k)
		var cor: Color
		if k < n:
			cor = _cor_acesa(k, primeiro_ambar, primeiro_verm)
		elif k >= primeiro_verm:
			cor = Color(VERMELHO, 0.45)
		else:
			cor = Color(RIMO, 0.5)
		if _aa:
			_face.draw_arc(_c, raio, a.x, a.y, 4, cor, larg, true)
		else:
			_segmento_cheio(a, cor)


## Um segmento como quadrilatero cheio. E o caminho do PS1 STYLE: `draw_arc`
## grosso sem suavizacao, a 480x270, sai como um risco torto por segmento — cada
## ponta rasterizada de um jeito —, e o arco vira serrilha em vez de luzes.
func _segmento_cheio(a: Vector2, cor: Color) -> void:
	var fora := PainelLayout.ARCO_FORA
	var dentro := PainelLayout.ARCO_DENTRO
	var d0 := Vector2(cos(a.x), sin(a.x))
	var d1 := Vector2(cos(a.y), sin(a.y))
	_face.draw_colored_polygon(PackedVector2Array([
		_c + d0 * fora, _c + d1 * fora, _c + d1 * dentro, _c + d0 * dentro,
	]), cor)


func _cor_acesa(k: int, primeiro_ambar: int, primeiro_verm: int) -> Color:
	if k >= primeiro_verm:
		return VERMELHO_ACESO
	if k >= primeiro_ambar:
		return AMBAR
	return OSSO


## O numero grande, com cada algarismo numa casa de largura fixa: sem isso o
## numero inteiro pula de lugar quando "9" vira "10" e o "1" estreito passa.
func _velocidade() -> void:
	var texto := "%d" % roundi(maxf(0.0, _kmh))
	var tam := UiEstilo.tamanho_nativo(_fonte_t)
	var casa := UiEstilo.largura(_fonte_t, "0")
	var meio := _c + PainelLayout.NUMERO
	var base := meio.y + _meia_altura(_fonte_t)
	var x := meio.x - casa * float(texto.length()) * 0.5
	var cor := NUMERO if _ligado else APAGADO
	for ch in texto:
		var w := UiEstilo.largura(_fonte_t, ch)
		_face.draw_string(_fonte_t, Vector2(roundf(x + (casa - w) * 0.5), roundf(base)),
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, cor)
		x += casa

	# A linha de baixo tem UM lugar, e por isso tem UMA palavra.
	#
	# Eram tres candidatas desenhadas por dois metodos diferentes, e elas se
	# atropelavam ("MOTOCKM/H" numa captura). A regra ficou generica: a linha
	# tem um dono, e o mais grave ganha. A unidade e quem cede sempre, porque e
	# a unica que nao informa nada. O freio de mao saiu daqui: ele tem lampada.
	#
	# A unidade em minusculas, como no mostrador impresso: ela e legenda do
	# numero, nao aviso. As duas palavras de aviso cabem na corda de dentro do
	# arco — "CAPOTOU" nao cabia e encostava nos segmentos, e virou "VIROU".
	var rotulo := ROTULO_UNIDADE
	var cor_rotulo := RISCO
	if _capotou:
		rotulo = ROTULO_VIROU
		cor_rotulo = VERMELHO_ACESO
	elif not _ligado:
		rotulo = ROTULO_MOTOR
		cor_rotulo = APAGADO
	_texto_centrado(_fonte_p, rotulo, _c + PainelLayout.ROTULO, cor_rotulo)


## A marcha, na caixa da abertura de baixo.
##
## A caixa e a luz de troca: a borda acende ambar quando e hora de trocar e
## pisca enquanto o limitador corta — o instante em que o som tranca. A luz e o
## som contam a mesma verdade por caminhos diferentes, e e essa coincidencia que
## faz o corte ser entendido em vez de estranhado.
func _marcha_engatada() -> void:
	var caixa := Rect2(_c + PainelLayout.MARCHA - PainelLayout.MARCHA_TAM * 0.5,
		PainelLayout.MARCHA_TAM)
	var troca := _ligado and _giro >= ACENDE_TROCA
	if troca and _cortando:
		troca = fposmod(_pisca_t, PISCA * 2.0) < PISCA
	if troca and _aa:
		_face.draw_rect(caixa.grow(1.5), Color(LUZ_TROCA, 0.30), true)
	_face.draw_rect(caixa, MOLDURA, true)
	_face.draw_rect(caixa, LUZ_TROCA if troca else RIMO, false, 1.0)
	var cor := NUMERO if _ligado else APAGADO
	if troca:
		cor = LUZ_TROCA
	_texto_centrado(_fonte_m, _marcha, _c + PainelLayout.MARCHA, cor)


## Farol e freio de mao, um de cada lado da marcha.
func _lampadas() -> void:
	_icone_farol(_c + PainelLayout.FAROL, VERDE if _farol else Color(RIMO, 0.7))
	_icone_freio(_c + PainelLayout.FREIO,
		VERMELHO_ACESO if _freio_mao else Color(RIMO, 0.7))


## As duas setas, acima do mostrador. So a do lado ligado acende, e so na
## metade acesa do ciclo — o mesmo relogio da lampada do carro.
func _setas() -> void:
	for lado: int in [-1, 1]:
		var p := _c + (PainelLayout.SETA_ESQ if lado < 0 else PainelLayout.SETA_DIR)
		var acesa := _seta == lado and _seta_acesa
		var cor := VERDE if acesa else Color(RIMO, 0.6)
		var m := PainelLayout.SETA * 0.5
		var s := float(lado)
		var ponta := PackedVector2Array([
			p + Vector2(s * m, 0.0),
			p + Vector2(0.0, -m),
			p + Vector2(0.0, m),
		])
		if acesa and _aa:
			_face.draw_circle(p, m + 2.0, Color(VERDE, 0.18), true, -1.0, true)
		_face.draw_colored_polygon(ponta, cor)
		_face.draw_rect(Rect2(p + Vector2(-s * m if s > 0.0 else 0.0, -1.25),
			Vector2(m, 2.5)), cor, true)


## Farol baixo: meia lua virada para a frente e tres raios inclinados para o
## chao, o simbolo que todo painel usa.
func _icone_farol(p: Vector2, cor: Color) -> void:
	var m := PainelLayout.LAMPADA * 0.5
	var corpo := PackedVector2Array()
	for k in 9:
		var a := lerpf(-PI * 0.5, PI * 0.5, float(k) / 8.0)
		corpo.append(p + Vector2(0.5, 0.0) + Vector2(cos(a), sin(a)) * m * 0.8)
	_face.draw_colored_polygon(corpo, cor)
	for k in 3:
		var y := p.y - m * 0.6 + float(k) * m * 0.6
		_face.draw_line(Vector2(p.x - 0.5, y), Vector2(p.x - m - 0.5, y + 1.2),
			cor, 1.0, _aa)


## Freio: o "(!)" dos carros da epoca, em traco.
##
## Era um "P" de fonte entre os parenteses, e a letra nao centrava: a caixa de
## avanco do glifo inclui o espacamento, e o P saia meio pixel para um lado e um
## para baixo. Em traco o simbolo fica no meio por construcao.
func _icone_freio(p: Vector2, cor: Color) -> void:
	var m := PainelLayout.LAMPADA * 0.5 + 0.5
	_face.draw_arc(p, m, deg_to_rad(125.0), deg_to_rad(235.0), 8, cor, 1.0, _aa)
	_face.draw_arc(p, m, deg_to_rad(-55.0), deg_to_rad(55.0), 8, cor, 1.0, _aa)
	_face.draw_rect(Rect2(p + Vector2(-0.6, -3.0), Vector2(1.2, 3.6)), cor, true)
	_face.draw_rect(Rect2(p + Vector2(-0.6, 1.8), Vector2(1.2, 1.2)), cor, true)


func _texto_centrado(fonte: Font, texto: String, meio: Vector2, cor: Color) -> void:
	var w := UiEstilo.largura(fonte, texto)
	_face.draw_string(fonte,
		Vector2(roundf(meio.x - w * 0.5), roundf(meio.y + _meia_altura(fonte))),
		texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiEstilo.tamanho_nativo(fonte), cor)


## Quanto a linha de base fica abaixo do meio de uma maiuscula.
##
## A maiuscula das fontes do projeto ocupa uns tres quartos da ascendente — no
## titulo, 13 de 17 px —; o resto e respiro em cima. Metade disso poe o texto no
## meio da caixa, e nao meio pixel abaixo.
const CAPITULAR := 0.76


func _meia_altura(fonte: Font) -> float:
	return fonte.get_ascent(UiEstilo.tamanho_nativo(fonte)) * CAPITULAR * 0.5

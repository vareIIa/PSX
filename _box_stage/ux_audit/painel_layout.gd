## Onde o painel do carro fica, e onde fica cada coisa dentro dele. Funcao pura.
##
## Mesmo contrato de `FaixaLayout` e `CartaoLayout`: quem desenha e quem mede
## consultam a MESMA resposta, sem Node e sem autoload.
##
## O desenho
## ---------
## Um mostrador redondo. A rotacao e um arco de segmentos em volta dele, que
## acendem da esquerda para a direita e mudam de cor perto do corte; a
## velocidade e o numero grande no meio; a marcha fica numa caixa na abertura de
## baixo do arco, entre o farol e o freio de mao; as setas ficam acima, uma de
## cada lado, como as luzes de um painel de verdade.
##
## Onde ele fica
## -------------
## No canto de baixo da direita, com a borda direita na mesma coluna do minimapa
## — os dois sao a interface do canto direito, e alinhados leem como um
## conjunto. O canto nao e o mesmo nos dois estilos, e isso sai da conta:
##
##   a vinheta do pos escurece as quinas. No MODERNO ela e fraca (0,18) e o
##   mostrador encosta na margem. No PS1 STYLE ela e forte (0,45), e na margem o
##   numero da marcha chegaria a 0,21 — abaixo do piso de `UiEstilo.VINHETA_MIN`.
##   Ali o mostrador anda para dentro, na diagonal, ate TODO texto passar do
##   piso. Nao e gosto: e a mesma regra que ja pos a faixa no meio do rodape.
##
## Ele nunca entra na coluna da faixa de estado (`FaixaLayout.LARGURA_MAX`
## centrada), senao o prompt de teclas passa por baixo do mostrador.
class_name PainelLayout
extends RefCounted

## Raio de fora do mostrador.
const RAIO := 34.0
## O arco de segmentos: raio de fora e de dentro.
const ARCO_FORA := 31.0
const ARCO_DENTRO := 26.0
## Varredura do arco, em graus na convencao matematica (0 a direita, y para
## cima). 240 graus: comeca embaixo a esquerda e termina embaixo a direita,
## deixando embaixo a abertura em que a marcha mora.
const ANG_INICIO := 210.0
const ANG_VARRE := -240.0
## Quantos segmentos o arco tem. 24 da um segmento a cada 10 graus: a 720p cada
## um tem uns 12 px de largura, e a 480x270 uns 5 px. Com 30 os blocos do PS1
## STYLE tinham 4 px e rasterizavam como riscos tortos, e nao como luzes.
const SEGMENTOS := 24
## Vao entre dois segmentos, em graus. Com 1 grau o vao tinha meio pixel da base
## e sumia: a primeira foto mostrou uma barra continua, e nao luzes.
const VAO_SEGMENTO := 2.4

## Onde cada coisa fica, relativa ao centro.
## O numero da velocidade: centro da caixa.
const NUMERO := Vector2(0.0, -4.0)
const NUMERO_TAM := Vector2(40.0, 15.0)
## A unidade, logo abaixo do numero.
const ROTULO := Vector2(0.0, 7.5)
const ROTULO_TAM := Vector2(34.0, 9.0)
## A marcha, na abertura de baixo.
const MARCHA := Vector2(0.0, 21.0)
const MARCHA_TAM := Vector2(15.0, 15.0)
## Farol e freio de mao, um de cada lado da marcha.
const FAROL := Vector2(-16.0, 21.0)
const FREIO := Vector2(16.0, 21.0)
const LAMPADA := 8.0
## As setas, acima do mostrador.
const SETA_ESQ := Vector2(-29.0, -29.0)
const SETA_DIR := Vector2(29.0, -29.0)
const SETA := 7.0

## A borda direita do minimapa. Ver `minimapa.gd`.
const DIREITA := UiEstilo.TELA.x - UiEstilo.MARGEM
const BAIXO := UiEstilo.TELA.y - UiEstilo.MARGEM
## Vao ate a coluna da faixa de estado.
const VAO_FAIXA := 6.0
## O ponto mais alto em que o CENTRO do mostrador pode ficar: o disco nao
## sobe no minimapa, que vai de 7 a 89, nem no rotulo dele, que desce ate 102
## (ver `minimapa.gd`). Com dois pixels de vao.
const TOPO_CENTRO := 104.0 + RAIO


## O centro do mostrador para uma vinheta de `intensidade`.
##
## Parte do canto e anda um pixel por vez para o meio da tela ate todo texto
## passar do piso. Na coluna da faixa ele para de andar para a esquerda e sobe
## RETO, ate o minimapa. Se nem la o texto passa (vinheta perto do maximo da
## barra de opcoes), fica no ponto em que ele e mais legivel.
##
## Ate 18/09/2026 o passo era sempre na diagonal e parava em 60 px: depois de
## encostar na coluna o mostrador subia meio pixel por passo, e com a vinheta
## em 0,7 — um estilo personalizado salvo nesta maquina — a marcha ficou em
## 0,29, apagada na quina. So os dois presets tinham sido medidos.
static func centro(intensidade: float) -> Vector2:
	var canto := Vector2(DIREITA - RAIO, BAIXO - RAIO)
	var dir := (UiEstilo.TELA * 0.5 - canto).normalized()
	var c := canto
	var melhor := canto
	var nota := -1.0
	var k := 0
	while c.y >= TOPO_CENTRO:
		var v := vinheta_do_texto(c, intensidade)
		if v >= UiEstilo.VINHETA_MIN:
			return c
		if v > nota:
			nota = v
			melhor = c
		k += 1
		# Arredondado para dentro (para cima e para a esquerda): meio pixel para
		# o canto poderia devolver o texto para baixo do piso.
		var d := (canto + dir * float(k)).floor()
		if d.x >= x_minimo():
			c = d
		else:
			# Encostou na coluna da faixa: daqui em diante so sobe.
			c = Vector2(x_minimo(), c.y - 1.0)
	return melhor


## O menor x de centro que nao invade a coluna da faixa.
static func x_minimo() -> float:
	var faixa_dir := (UiEstilo.TELA.x + FaixaLayout.LARGURA_MAX) * 0.5
	return faixa_dir + VAO_FAIXA + RAIO


## As caixas de texto, em coordenadas de tela.
static func textos(c: Vector2) -> Array[Rect2]:
	return [
		_caixa(c + NUMERO, NUMERO_TAM),
		_caixa(c + ROTULO, ROTULO_TAM),
		_caixa(c + MARCHA, MARCHA_TAM),
	]


## Tudo que o painel desenha, em coordenadas de tela: o disco e as setas.
static func contorno(c: Vector2) -> Rect2:
	var r := Rect2(c - Vector2(RAIO, RAIO), Vector2(RAIO, RAIO) * 2.0)
	r = r.merge(_caixa(c + SETA_ESQ, Vector2(SETA, SETA)))
	r = r.merge(_caixa(c + SETA_DIR, Vector2(SETA, SETA)))
	# A sombra do disco, dois pixels para baixo e para a direita.
	return r.grow_individual(0.0, 0.0, 2.0, 2.0)


## O pior fator de vinheta entre as quinas de todo texto do painel.
static func vinheta_do_texto(c: Vector2, intensidade: float) -> float:
	var pior := 1.0
	for r: Rect2 in textos(c):
		pior = minf(pior, UiEstilo.vinheta_do_rect(r, intensidade))
	return pior


## Onde o segmento `k` comeca e acaba, em radianos na convencao da TELA (y para
## baixo), que e a de `draw_arc`, com `VAO_SEGMENTO` entre vizinhos.
static func angulos_do_segmento(k: int) -> Vector2:
	var passo := ANG_VARRE / float(SEGMENTOS)
	var de := ANG_INICIO + passo * float(k)
	var ate := de + passo
	var vao := signf(passo) * VAO_SEGMENTO
	return Vector2(-deg_to_rad(de + vao * 0.5), -deg_to_rad(ate - vao * 0.5))


## Quantos segmentos acendem para um giro normalizado.
static func acesos(giro: float) -> int:
	return clampi(int(roundf(clampf(giro, 0.0, 1.0) * float(SEGMENTOS))), 0, SEGMENTOS)


## Um ponto do arco, em coordenadas relativas ao centro, para a fracao `t` da
## varredura e o raio `r`.
static func no_arco(t: float, r: float) -> Vector2:
	var a := deg_to_rad(ANG_INICIO + ANG_VARRE * t)
	return Vector2(cos(a), -sin(a)) * r


## A largura livre dentro do arco na altura `y` (relativa ao centro): a corda do
## circulo de dentro do arco. Texto mais largo que isto encosta nos segmentos.
static func corda_livre(y: float) -> float:
	var r := ARCO_DENTRO - 1.5
	return 2.0 * sqrt(maxf(0.0, r * r - y * y))


static func _caixa(meio: Vector2, tam: Vector2) -> Rect2:
	return Rect2(meio - tam * 0.5, tam)

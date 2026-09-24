"""Rostos de estudio e barbas em recorte, para a criacao de personagem.

As tres linhas que a tela de criacao acrescentou ao atlas
---------------------------------------------------------
    linha  9   oito rostos masculinos desenhados a mao
    linha 10   oito rostos femininos desenhados a mao
    linha 11   barbas em recorte (alfa), coladas por cima de qualquer rosto

Por que rostos novos, e nao os sorteados retocados
--------------------------------------------------
Os dezesseis rostos das linhas 0 e 1 sao a cara da cidade: cada pedestre tira o
seu dali pelo id, e mexer no desenho deles muda a cara de gente que o jogador ja
conheceu. Alem disso eles trazem oculos e barba SORTEADOS dentro da celula —
Helmer e o motivo de a linha do elenco existir. Na criacao isso vira defeito:
quem escolhe o rosto nao escolhe se ele vem de oculos.

Os rostos daqui sao LIMPOS. Barba e oculos sao escolha a parte: a barba mora na
linha 11 e entra num quad de recorte colado na cara; os oculos sao geometria
(ver `Vestuario`). Por isso as feicoes ficam SEMPRE nas mesmas linhas de pixel —
olho em 14 e 15, nariz de 16 a 20, boca em 23 —, e a barba desenhada para um
serve em todos.

O que "polido" quer dizer em 32 px
----------------------------------
Nao e mais detalhe: e VALOR no lugar certo. Os sorteados tem olho de um pixel de
pupila num branco chapado e boca de uma linha. Aqui ha palpebra (o traco escuro
em cima do olho, que e o que faz o olho ler como olho a 480x270), iris com brilho,
nariz com lado de luz e lado de sombra, labio de cima mais escuro que o de baixo,
e o queixo e as macas modelados por meio-tom. E o que um sprite de PS1 bem
desenhado fazia com a mesma paleta.
"""

import random

from PIL import Image, ImageDraw

CELULA = 32

LINHA_ESTUDIO_M = 9
LINHA_ESTUDIO_F = 10
LINHA_BARBA = 11

PELE = (238, 222, 206)
LUZ = (248, 238, 228)
MEIO = (224, 206, 190)
SOMBRA = (206, 186, 170)
FUNDO = (184, 162, 146)
ESCURO = (72, 54, 44)
PALPEBRA = (58, 42, 34)
BRANCO = (246, 242, 236)
BRILHO = (255, 255, 255)
LABIO_SUP = (150, 92, 86)
LABIO_INF = (190, 128, 120)
BATOM_SUP = (160, 70, 74)
BATOM_INF = (200, 104, 106)
RUBOR = (240, 198, 190)

# Cor de iris. Sao poucas e escuras de proposito: a cor de vertice da pele
# multiplica a celula inteira, e uma iris clara num tom de pele escuro vira
# branco de olho.
IRIS = [(70, 50, 38), (52, 44, 40), (88, 70, 44), (60, 76, 70), (64, 70, 92)]

# Mesma cor clara dos cabelos: o tom de verdade vem do tint (cor do cabelo).
PELO = (232, 228, 222)
PELO_ESCURO = (206, 200, 194)


# Pedacos da cara a NAO desenhar (ver `gerar_npc.PULAR`): o `gerar_rosto.py`
# acha cada pedaco pela diferenca entre a cara inteira e a cara sem ele.
PULAR: set = set()


def _novo(cor=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", (CELULA, CELULA), cor)


def _p(d, x, y, cor) -> None:
    if 0 <= x < CELULA and 0 <= y < CELULA:
        d.point((x, y), fill=cor + (255,) if len(cor) == 3 else cor)


def _r(d, x0, y0, x1, y1, cor) -> None:
    d.rectangle((x0, y0, x1, y1), fill=cor + (255,) if len(cor) == 3 else cor)


# --- a massa da cabeca -------------------------------------------------------

def _cabeca(d, queixo: int, macas: bool) -> None:
    """Massa, volume e contorno do maxilar.

    `queixo` e quantos pixels o maxilar afina de cada lado nas ultimas linhas:
    zero e um queixo quadrado, tres e um rosto fino. E o traco que mais separa
    um rosto do outro de frente, e a caixa da cabeca nao muda — quem afina e a
    sombra.
    """
    _r(d, 0, 0, 31, 31, PELE)
    # Sem luz na testa. Em retangulo ela lia como listra, em pontos como
    # xadrez — e de todo jeito e a faixa que a franja cobre.
    # Laterais em dois tons: o volume sai do meio-tom, e nao da linha escura.
    _r(d, 0, 0, 1, 31, SOMBRA)
    _r(d, 2, 0, 3, 31, MEIO)
    _r(d, 30, 0, 31, 31, SOMBRA)
    _r(d, 28, 0, 29, 31, MEIO)
    # Maxilar: as quinas de baixo escurecem em escada, e o queixo fica aceso.
    for k in range(queixo + 3):
        y = 31 - k
        largura = queixo + 3 - k
        _r(d, 0, y, largura + 1, y, SOMBRA)
        _r(d, 30 - largura, y, 31, y, SOMBRA)
    _r(d, 5, 31, 26, 31, MEIO)
    _r(d, 14, 28, 17, 28, LUZ)
    if macas:
        # Maca do rosto: meio-tom embaixo do osso, luz em cima.
        for lado in (-1, 1):
            cx = 16 + lado * 9
            _r(d, cx - 1, 17, cx + 1, 17, LUZ)
            _r(d, cx - 2, 20, cx + 1, 21, MEIO) if lado < 0 else _r(
                d, cx - 1, 20, cx + 2, 21, MEIO)


def _olho(d, cx: int, larg: int, iris, fem: bool, lado: int,
          puxado: int) -> None:
    """Olho em quatro valores: palpebra, branco, iris, brilho.

    A palpebra e o traco mais escuro da cara, e e ele — e nao a pupila — que
    faz o olho ler como olho a 480x270. `puxado` sobe o canto de fora um pixel.
    """
    x0 = cx - larg
    x1 = cx + larg - 1
    _r(d, x0, 14, x1, 15, BRANCO)
    # Iris de dois pixels, com brilho no canto de cima virado para a luz.
    ix = cx - 1
    _r(d, ix, 14, ix + 1, 15, iris)
    _p(d, ix + (0 if lado < 0 else 1), 14, BRILHO)
    _p(d, ix + (1 if lado < 0 else 0), 15, PALPEBRA)
    # Palpebra de cima, passando um pixel alem do olho para o lado de fora.
    fora = x1 + 1 if lado > 0 else x0 - 1
    _r(d, x0, 13, x1, 13, PALPEBRA)
    _p(d, fora, 13 - puxado, PALPEBRA)
    if fem:
        # Cilio: um pixel a mais para fora, na mesma linha. Subindo em gancho,
        # como estava, o olho inteiro lia como espanto.
        _p(d, fora + (1 if lado > 0 else -1), 12, PALPEBRA)
    # Palpebra de baixo em meio-tom, e a olheira embaixo dela.
    _r(d, x0, 16, x1, 16, SOMBRA)


def _sobrancelha(d, cx: int, larg: int, forma: str, grossa: bool,
                 lado: int) -> None:
    """Sobrancelha por forma, e nao por espessura so.

    A forma carrega a expressao: arqueada le como surpresa leve, reta como
    serio, caida para fora como cansaco, subindo para fora como decidido.
    """
    x0 = cx - larg - 1
    x1 = cx + larg
    dentro, fora = (x1, x0) if lado < 0 else (x0, x1)
    passo = 1 if fora > dentro else -1
    for i, x in enumerate(range(dentro, fora + passo, passo)):
        t = i / max(1, abs(fora - dentro))
        if forma == "arco":
            y = 11 - (1 if 0.3 < t < 0.85 else 0)
        elif forma == "caida":
            y = 10 + (1 if t > 0.6 else 0)
        elif forma == "sobe":
            y = 11 - (1 if t > 0.45 else 0)
        else:
            y = 11
        _p(d, x, y, ESCURO)
        if grossa and t < 0.8:
            _p(d, x, y - 1, ESCURO)
    # O inicio, perto do nariz, e mais cheio que a ponta.
    _p(d, dentro, 12 if forma != "caida" else 11, ESCURO)


def _nariz(d, largo: bool, comprido: int) -> None:
    """Nariz com lado de luz e lado de sombra. A luz vem da esquerda."""
    fim = 19 + comprido
    for y in range(14, fim):
        _p(d, 15, y, LUZ)
        _p(d, 17, y, MEIO)
    _p(d, 17, fim - 1, SOMBRA)
    # Ponta e narinas.
    _r(d, 15, fim, 17, fim, SOMBRA)
    _p(d, 14 if not largo else 13, fim, FUNDO)
    _p(d, 18 if not largo else 19, fim, FUNDO)
    _p(d, 16, fim + 1, MEIO)


def _boca(d, largura: int, forma: str, fem: bool, cheia: bool) -> None:
    """Labio de cima escuro, de baixo claro. Os cantos dizem o humor."""
    sup = BATOM_SUP if fem else LABIO_SUP
    inf = BATOM_INF if fem else LABIO_INF
    x0 = 16 - largura // 2
    x1 = 16 + (largura - 1) // 2 + (0 if largura % 2 else 1)
    _r(d, x0, 23, x1, 23, sup)
    _r(d, x0 + 1, 24, x1 - 1, 24, inf)
    if cheia:
        # Arco do cupido: dois picos, e o vale no meio. Uma linha cheia em cima
        # da boca fazia um coracao vermelho no meio da cara.
        _p(d, x0 + 1, 22, sup)
        _p(d, x1 - 1, 22, sup)
        # Labio de baixo tao largo quanto o de cima: afinando linha a linha, a
        # boca virava um triangulo apontado para o queixo.
        _r(d, x0, 24, x1, 24, inf)
        _r(d, x0 + 1, 25, x1 - 1, 25, inf)
    # Sombra embaixo do labio: e o que da volume a boca.
    _r(d, x0 + 2, 26 if cheia else 25, x1 - 2, 26 if cheia else 25, MEIO)
    if forma == "sorriso":
        _p(d, x0 - 1, 22, sup)
        _p(d, x1 + 1, 22, sup)
    elif forma == "serio":
        _p(d, x0 - 1, 24, SOMBRA)
        _p(d, x1 + 1, 24, SOMBRA)
    elif forma == "meio":
        _p(d, x1 + 1, 22, sup)


# Receitas. Escritas e nao sorteadas: a criacao mostra os oito lado a lado, e
# oito sorteios tendem a dar tres parecidos.
RECEITAS_M = [
    # iris, sep, larg, sobrancelha, grossa, nariz largo, comprimento, boca, forma, queixo, extra
    (0, 7, 3, "reta", True, False, 0, 6, "serio", 0, ""),
    (1, 7, 3, "sobe", True, True, 1, 7, "meio", 0, "vinco"),
    (2, 6, 3, "arco", False, False, 0, 5, "sorriso", 2, "sardas"),
    (0, 8, 3, "caida", True, True, 1, 6, "serio", 1, "olheira"),
    (3, 7, 2, "reta", False, False, 0, 5, "meio", 2, ""),
    (4, 7, 3, "sobe", True, False, 1, 7, "sorriso", 1, "cicatriz"),
    (1, 6, 3, "caida", False, True, 0, 6, "serio", 0, "rugas"),
    (2, 7, 3, "arco", True, False, 1, 6, "sorriso", 1, "pinta"),
]

RECEITAS_F = [
    (0, 7, 3, "arco", False, False, 0, 5, "sorriso", 3, "rubor"),
    (3, 7, 3, "sobe", False, False, 0, 5, "meio", 2, "pinta"),
    (1, 6, 3, "arco", True, False, 0, 6, "serio", 2, ""),
    (2, 7, 3, "reta", False, True, 1, 6, "sorriso", 1, "sardas"),
    (4, 7, 3, "sobe", False, False, 0, 5, "serio", 3, "rubor"),
    (0, 8, 3, "arco", False, False, 0, 6, "meio", 2, "olheira"),
    (1, 7, 2, "caida", True, False, 0, 5, "sorriso", 2, "rubor"),
    (2, 7, 3, "arco", False, False, 1, 5, "serio", 2, "rugas"),
]


def rosto_estudio(indice: int, fem: bool) -> Image.Image:
    receita = (RECEITAS_F if fem else RECEITAS_M)[indice % 8]
    (iris, sep, larg, sobr, grossa, largo, comprido, boca, forma, queixo,
     extra) = receita
    im = _novo()
    d = ImageDraw.Draw(im)
    _cabeca(d, queixo, macas=fem or indice % 2 == 0)
    for lado in (-1, 1):
        cx = 16 + lado * sep
        if "sobrancelhas" not in PULAR:
            _sobrancelha(d, cx, larg, sobr, grossa and not fem, lado)
        if "olhos" not in PULAR:
            _olho(d, cx, larg, IRIS[iris], fem, lado, 0)
    _nariz(d, largo, comprido)
    if "boca" not in PULAR:
        _boca(d, boca, forma, fem, cheia=fem)

    rng = random.Random(7331 + indice * 17 + (500 if fem else 0))
    if extra == "sardas":
        for _ in range(16):
            x = rng.choice([rng.randint(7, 12), rng.randint(20, 25)])
            y = rng.randint(16, 21)
            _p(d, x, y, MEIO if rng.random() < 0.6 else SOMBRA)
        for x in (14, 16, 18):
            _p(d, x, 17, MEIO)
    elif extra == "rubor":
        for lado in (-1, 1):
            cx = 16 + lado * 9
            _r(d, cx - 1, 19, cx + 1, 20, RUBOR)
    elif extra == "pinta":
        _p(d, 21, 22, FUNDO)
    elif extra == "vinco":
        # Sulco nasolabial: dois tracos do nariz ate o canto da boca.
        for lado in (-1, 1):
            _p(d, 16 + lado * 3, 21, MEIO)
            _p(d, 16 + lado * 4, 22, MEIO)
    elif extra == "olheira":
        for lado in (-1, 1):
            cx = 16 + lado * sep
            _r(d, cx - larg + 1, 17, cx + larg - 2, 17, MEIO)
    elif extra == "cicatriz":
        # Corte na sobrancelha: o pixel que falta e o que se ve.
        _p(d, 16 + sep + 1, 11, LUZ)
        _p(d, 16 + sep + 1, 10, LUZ)
        _p(d, 16 + sep + 2, 12, MEIO)
    elif extra == "rugas":
        # Testa, pe de galinha e o sulco: idade em seis tracos.
        d.line((11, 6, 20, 6), fill=MEIO + (255,))
        d.line((12, 8, 19, 8), fill=MEIO + (255,))
        for lado in (-1, 1):
            fx = 16 + lado * (sep + larg + 1)
            _p(d, fx, 14, MEIO)
            _p(d, fx, 16, MEIO)
            _p(d, 16 + lado * 4, 22, MEIO)
    # Textura de pele: meia duzia de pontos em meio-tom, fora das feicoes.
    for _ in range(14):
        x, y = rng.randint(4, 27), rng.randint(3, 28)
        if 10 <= y <= 26 and 9 <= x <= 22:
            continue
        _p(d, x, y, MEIO)
    return im


# --- barbas em recorte --------------------------------------------------------
#
# Desenhadas em claro sobre alfa zero: o tom vem da cor do cabelo por vertice,
# como o cabelo de verdade. O material que as desenha tem recorte ligado (ver
# `Corpo._material_recorte`), entao o que e alfa zero some e a cara aparece.

BARBA_POR_FAZER = 0
BARBA_BIGODE = 1
BARBA_CAVANHAQUE = 2
BARBA_CHEIA = 3
BARBA_ESPESSA = 4


def _pelo(d, x, y, rng=None) -> None:
    cor = PELO
    if rng is not None and rng.random() < 0.35:
        cor = PELO_ESCURO
    _p(d, x, y, cor + (255,))


def _dentro_da_boca(x: int, y: int) -> bool:
    return 12 <= x <= 20 and 22 <= y <= 24


def barba(estilo: int) -> Image.Image:
    im = _novo()
    d = ImageDraw.Draw(im)
    rng = random.Random(2600 + estilo * 37)
    if estilo == BARBA_POR_FAZER:
        # Chapisco, e nao mancha: a densidade cai para as bordas, e o bigode
        # ralo fica em cima do labio.
        for y in range(20, 32):
            for x in range(3, 29):
                if _dentro_da_boca(x, y):
                    continue
                borda = min(x - 3, 28 - x)
                chance = 0.42 if borda > 4 else 0.18
                if y == 20 or y == 21:
                    chance = 0.5 if 12 <= x <= 20 else 0.0
                if rng.random() < chance:
                    _p(d, x, y, PELO_ESCURO + (255,))
    elif estilo == BARBA_BIGODE:
        for x in range(11, 22):
            _pelo(d, x, 21, rng)
            _pelo(d, x, 22 if not 13 <= x <= 19 else 21, rng)
        for lado in (-1, 1):
            _pelo(d, 16 + lado * 6, 22)
            _pelo(d, 16 + lado * 6, 23)
            _pelo(d, 16 + lado * 7, 23)
    elif estilo == BARBA_CAVANHAQUE:
        for x in range(12, 21):
            _pelo(d, x, 21, rng)
        for lado in (-1, 1):
            for y in range(22, 26):
                _pelo(d, 16 + lado * 5, y, rng)
        for y in range(25, 32):
            meio = 3 if y < 30 else 2
            for x in range(16 - meio, 17 + meio):
                _pelo(d, x, y, rng)
    elif estilo in (BARBA_CHEIA, BARBA_ESPESSA):
        topo = 18 if estilo == BARBA_ESPESSA else 20
        for y in range(topo, 32):
            for x in range(0, 32):
                if _dentro_da_boca(x, y):
                    continue
                # A barba sobe pelas costeletas nas laterais e desce na frente;
                # a borda de cima e uma curva, e nao uma linha reta cortando a
                # cara em duas.
                borda_cima = topo + (0 if x < 5 or x > 26 else
                                     (2 if 9 <= x <= 22 else 1))
                if y < borda_cima:
                    continue
                if 13 <= x <= 19 and y == topo + 2 and estilo == BARBA_CHEIA:
                    continue
                _pelo(d, x, y, rng)
        # Lateral inteira ate a testa, porque a barba cheia encosta na costeleta.
        for y in range(10, topo):
            for x in (0, 1, 30, 31):
                _pelo(d, x, y, rng)
    return im


# Coluna 5 da linha de barbas: os olhos FECHADOS, para piscar.
#
# Um quad de recorte tingido pela cor da pele, colado na cara por um decimo de
# segundo. Cobre de 4 a 13 e de 18 a 27 em x, de 12 a 16 em y: e onde caem os
# olhos de TODOS os rostos, os sorteados (que variam um pixel para cima e para
# baixo) e os de estudio. A sobrancelha fica de fora, e e ela que faz a
# piscada ler como piscada e nao como olho sumindo.
PALPEBRA_COLUNA = 5


def palpebra() -> Image.Image:
    im = _novo()
    d = ImageDraw.Draw(im)
    for lado in (-1, 1):
        cx = 16 + lado * 7
        x0, x1 = cx - 5, cx + 4
        _r(d, x0, 12, x1, 16, PELE)
        _r(d, x0 + 1, 13, x1 - 1, 13, MEIO)
        # O traco do olho fechado, com as pontas caindo um pixel.
        _r(d, x0 + 1, 15, x1 - 1, 15, PALPEBRA)
        _p(d, x0, 14, PALPEBRA)
        _p(d, x1, 14, PALPEBRA)
    return im


def colar_linhas(atlas: Image.Image, colar) -> None:
    for i in range(8):
        colar(atlas, i, LINHA_ESTUDIO_M, rosto_estudio(i, False))
        colar(atlas, i, LINHA_ESTUDIO_F, rosto_estudio(i, True))
    for estilo in range(5):
        colar(atlas, estilo, LINHA_BARBA, barba(estilo))
    colar(atlas, PALPEBRA_COLUNA, LINHA_BARBA, palpebra())

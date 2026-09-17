#!/usr/bin/env python3
"""Atlas de personagem, documento de identidade e chrome do celular.

Um atlas, e nao uma textura por pessoa
--------------------------------------
Uma cidade com dez pedestres na tela e um problema de draw call antes de ser um
problema de arte: o ART-BIBLE secao 10 da 120 chamadas por quadro para o jogo
inteiro, e a cidade ja gasta a maior parte. Textura por NPC tambem obrigaria a
gerar imagem em tempo de execucao, que e o tipo de custo que aparece como
engasgo justo quando alguem dobra a esquina.

Entao tudo que veste uma pessoa mora aqui, num atlas de 256x256 dividido em
celulas de 32x32. A variacao sai de duas coisas que nao custam arquivo nenhum:

    qual celula      escolhe rosto, cabelo, camisa, calca
    cor de vertice   escolhe tom de pele, cor de cabelo, cor de roupa

Oito rostos vezes oito cabelos vezes oito camisas vezes oito calcas ja da 4096
silhuetas, e a cor multiplica isso por milhares. E a mesma economia que o PS1
fazia por falta de memoria de textura.

Por que o rosto e desenhado em pele quase branca
------------------------------------------------
O shader multiplica ALBEDO pela cor de vertice. Desenhar a pele no tom final
faria o tom multiplicar duas vezes e todo mundo sairia escuro demais. A celula e
desenhada clara, quase branca, e o tom vem do tint.

    python tools/gerar_npc.py
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
TEXTURAS = RAIZ / "game" / "assets" / "textures"
UI = RAIZ / "game" / "assets" / "ui"

CELULA = 32
GRADE = 8
LADO = CELULA * GRADE

# O atlas tem NOVE linhas, e nao oito.
#
# As oito primeiras sao gente sorteada: rosto, cabelo, camisa, calca. A nona e
# de gente com NOME — Helmer e Jota, da estufa —, e ela existe porque uma pessoa
# especifica nao cabe no sorteio. O rosto sorteado poe oculos em 22% dos casos e
# barba por fazer em 45%, sem controle de qual; Helmer usa oculos redondos e
# bigode SEMPRE, e alguem que as vezes aparece sem oculos nao e a mesma pessoa.
#
# Cabem oito caras com nome na linha, e hoje moram quatro celulas nela. As
# outras quatro sao para os proximos.
LINHAS_TOTAIS = 9
ALTURA_ATLAS = CELULA * LINHAS_TOTAIS

# A tabela de linhas tem copia em src/systems/aparencia.gd. Sao dois arquivos
# porque um e Python e o outro roda no jogo; o verificador confere que o numero
# de variantes bate dos dois lados.
LINHA_ROSTO_M = 0
LINHA_ROSTO_F = 1
LINHA_PECAS = 2
LINHA_CABELO = 3
LINHA_CAMISA = 4
LINHA_COSTAS = 5
LINHA_CALCA = 6
LINHA_CASACO = 7
LINHA_ELENCO = 8

# Colunas da linha do elenco.
ELENCO_ROSTO_HELMER = 0
ELENCO_ROSTO_JOTA = 1
ELENCO_PERFIL_HELMER = 2
ELENCO_PERFIL_JOTA = 3
ELENCO_PELE_ESPINHOS = 4
ELENCO_NUCA_ESPINHOS = 5
ELENCO_CABELO_CACHEADO = 6

VARIANTES = 8

# Pele quase branca: o tom real entra por cor de vertice.
PELE = (238, 222, 206)
SOMBRA = (206, 186, 170)
ESCURO = (92, 70, 58)
BOCA = (150, 96, 88)


def novo(cor=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", (CELULA, CELULA), cor)


def colar(atlas: Image.Image, col: int, linha: int, im: Image.Image) -> None:
    atlas.paste(im, (col * CELULA, linha * CELULA))


def ruidinho(d: ImageDraw.ImageDraw, rng: random.Random, caixa, cor, n: int) -> None:
    """Sujeira de um pixel. Superficie chapada em 32x32 le como plastico."""
    x0, y0, x1, y1 = caixa
    for _ in range(n):
        d.point((rng.randint(x0, x1), rng.randint(y0, y1)), fill=cor)


# --- rostos -----------------------------------------------------------------

def rosto(semente: int, feminino: bool) -> Image.Image:
    """Rosto de frente em 32x32.

    Trinta e dois pixels nao comportam anatomia, comportam LEITURA. O que
    distingue um rosto do outro aqui e, em ordem de importancia: distancia entre
    os olhos, espessura da sobrancelha, presenca de barba e formato da boca.
    Todo o resto e enfeite que some na tela de 480x270.
    """
    rng = random.Random(semente * 7919 + (1 if feminino else 0))
    im = novo()
    d = ImageDraw.Draw(im)

    # Massa da cabeca. Ocupa a celula quase inteira: a caixa da cabeca no 3D e
    # justa, e sobra de textura vira moldura vazia em volta da cara.
    d.rectangle((0, 0, 31, 31), fill=PELE + (255,))
    # Sombra nas laterais, que e o que da volume sem precisar de normal map.
    d.rectangle((0, 0, 2, 31), fill=SOMBRA + (255,))
    d.rectangle((29, 0, 31, 31), fill=SOMBRA + (255,))
    d.rectangle((0, 28, 31, 31), fill=SOMBRA + (255,))

    largura_olho = rng.choice([3, 3, 4])
    sep = rng.choice([6, 7, 7, 8])
    y_olho = rng.choice([13, 14, 14, 15])
    cx = 16

    # Sobrancelha. A espessura e o traco que mais muda a expressao.
    grossura = rng.choice([1, 1, 2])
    inclina = rng.choice([-1, 0, 0, 1])
    for lado in (-1, 1):
        ox = cx + lado * sep
        x0 = ox - largura_olho
        x1 = ox + largura_olho - 1
        y = y_olho - 4
        d.rectangle((x0, y, x1, y + grossura - 1), fill=ESCURO + (255,))
        if inclina:
            ponta = x1 if lado > 0 else x0
            d.point((ponta, y + inclina), fill=ESCURO + (255,))

    # Olhos: branco com pupila escura. Um pixel de branco de cada lado da pupila
    # e o que faz o olho parecer olho e nao furo.
    for lado in (-1, 1):
        ox = cx + lado * sep
        d.rectangle((ox - largura_olho + 1, y_olho, ox + largura_olho - 1,
                     y_olho + 1), fill=(246, 242, 236, 255))
        d.rectangle((ox - 1, y_olho, ox, y_olho + 1), fill=ESCURO + (255,))

    if rng.random() < 0.22:
        # Oculos: aro fino em volta de cada olho, ligado por uma ponte de um
        # pixel. Aro cheio vira mascara de mergulho neste tamanho.
        aro = (96, 84, 74, 255)
        for lado in (-1, 1):
            ox = cx + lado * sep
            d.rectangle((ox - largura_olho, y_olho - 1, ox + largura_olho,
                         y_olho + 2), outline=aro)
        d.point((cx, y_olho + 1), fill=aro)

    # Nariz: uma sombra vertical curta e duas narinas. Desenhar o nariz inteiro
    # em 32 px vira um borrao no meio da cara.
    ny = y_olho + rng.choice([4, 5, 6])
    d.line((cx, y_olho + 2, cx, ny), fill=SOMBRA + (255,))
    d.point((cx - 1, ny), fill=(150, 122, 108, 255))
    d.point((cx + 1, ny), fill=(150, 122, 108, 255))

    # Boca.
    by = min(26, ny + rng.choice([3, 4, 5]))
    largura_boca = rng.choice([4, 5, 6])
    cor_boca = (176, 84, 88, 255) if feminino and rng.random() < 0.55 else BOCA + (255,)
    d.line((cx - largura_boca // 2, by, cx + largura_boca // 2, by), fill=cor_boca)
    curva = rng.choice([-1, 0, 0, 1])
    if curva:
        d.point((cx - largura_boca // 2, by - curva), fill=cor_boca)
        d.point((cx + largura_boca // 2, by - curva), fill=cor_boca)

    if not feminino and rng.random() < 0.45:
        # Barba por fazer: sombra chapiscada no queixo, nao um retangulo cheio.
        # Preenchido, o queixo vira um bloco escuro colado na cara — foi assim
        # que saiu na primeira versao, e a 32 px lia como focinho.
        sombra_barba = (176, 152, 134, 255)
        for _ in range(70):
            x = rng.randint(cx - 6, cx + 6)
            y = rng.randint(by + 1, 26)
            # Rareia nas bordas, para a barba ter contorno em vez de moldura.
            if abs(x - cx) > 4 and rng.random() < 0.55:
                continue
            d.point((x, y), fill=sombra_barba)
        if rng.random() < 0.5:
            for x in range(cx - 3, cx + 4):
                d.point((x, by - 2), fill=sombra_barba)

    if rng.random() < 0.3:
        # Rugas: dois tracos na testa. Envelhece o rosto sem mexer na geometria.
        d.line((cx - 6, 7, cx + 6, 7), fill=SOMBRA + (255,))
        d.line((cx - 4, 9, cx + 4, 9), fill=SOMBRA + (255,))

    ruidinho(d, rng, (3, 3, 28, 28), (222, 204, 190, 255), 18)
    return im


# --- o elenco ----------------------------------------------------------------
#
# Gente com nome. Tudo aqui e escrito a mao, sem rng: e a diferenca entre um
# personagem e um sorteio que por acaso deu naquilo.
#
# O que precisa estar certo em 32 px nao e semelhanca, sao os TRACOS QUE SE
# CITAM. Ninguem descreve um rosto pelo formato do queixo; descreve pelo "o de
# oculos redondo e cabelo armado" e pelo "o alto de bigode". Entao o desenho
# gasta os pixels nos oculos, no bigode e no alargador, e o resto e a mesma cara
# de todo mundo.


def _base_da_cara():
    """Massa da cabeca e sombras laterais, igual ao rosto sorteado."""
    im = novo()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 31, 31), fill=PELE + (255,))
    d.rectangle((0, 0, 2, 31), fill=SOMBRA + (255,))
    d.rectangle((29, 0, 31, 31), fill=SOMBRA + (255,))
    d.rectangle((0, 28, 31, 31), fill=SOMBRA + (255,))
    return im, d


def _olhos(d, sep: int, y: int, largura: int) -> None:
    for lado in (-1, 1):
        ox = 16 + lado * sep
        d.rectangle((ox - largura + 1, y, ox + largura - 1, y + 1),
                    fill=(246, 242, 236, 255))
        d.rectangle((ox - 1, y, ox, y + 1), fill=ESCURO + (255,))


def _sobrancelhas(d, sep: int, y: int, largura: int, grossura: int,
                  cor) -> None:
    for lado in (-1, 1):
        ox = 16 + lado * sep
        d.rectangle((ox - largura, y, ox + largura - 1, y + grossura - 1),
                    fill=cor)


def _bigode(d, y: int, largura: int, cor) -> None:
    """Bigode de guidao, que e o dos dois.

    Duas linhas e as pontas caindo, e nao um retangulo cheio: a 32 px o bigode
    preenchido vira uma barra preta embaixo do nariz e le como tarja de censura.
    Sao as pontas caindo um pixel que fazem a forma ser lida como bigode.
    """
    d.line((16 - largura, y, 16 + largura, y), fill=cor)
    d.line((16 - largura, y + 1, 16 + largura, y + 1), fill=cor)
    for lado in (-1, 1):
        d.point((16 + lado * (largura + 1), y + 1), fill=cor)
        d.point((16 + lado * (largura + 1), y + 2), fill=cor)


def rosto_helmer() -> Image.Image:
    """Oculos redondos de aro fino, bigode e cavanhaque.

    Os oculos sao o traco principal e por isso sao ARO FECHADO redondo, gastando
    quatro pixels de altura por olho. E muito para uma celula de 32, e e o
    certo: sem o aro fechado eles leem como olheira.
    """
    im, d = _base_da_cara()
    sep, y_olho, larg = 7, 14, 3
    aro = (58, 52, 50, 255)

    # A sobrancelha sobe DOIS pixels acima do normal, para ficar fora do aro.
    # No primeiro desenho ela caia em cima da moldura dos oculos e sumia — e
    # sobrancelha e o traco que mais carrega expressao num rosto de 32 px.
    _sobrancelhas(d, sep, y_olho - 6, larg + 1, 2, ESCURO + (255,))
    _olhos(d, sep, y_olho, larg)

    for lado in (-1, 1):
        ox = 16 + lado * sep
        d.ellipse((ox - larg - 1, y_olho - 3, ox + larg + 1, y_olho + 4),
                  outline=aro)
    d.line((16 - 2, y_olho, 16 + 2, y_olho), fill=aro)
    # As hastes ate as orelhas. Sem elas os aros flutuam na cara.
    d.line((3, y_olho - 1, 16 - sep - larg - 1, y_olho), fill=aro)
    d.line((28, y_olho - 1, 16 + sep + larg + 1, y_olho), fill=aro)

    ny = y_olho + 6
    d.line((16, y_olho + 3, 16, ny), fill=SOMBRA + (255,))
    d.point((15, ny), fill=(150, 122, 108, 255))
    d.point((17, ny), fill=(150, 122, 108, 255))

    _bigode(d, ny + 2, 4, ESCURO + (255,))
    d.line((13, 26, 19, 26), fill=BOCA + (255,))
    # Cavanhaque embaixo do labio.
    d.rectangle((14, 28, 18, 30), fill=ESCURO + (255,))
    # Barba rala no maxilar: e o que a foto tem e o que separa Helmer de Jota.
    rng = random.Random(9001)
    for _ in range(54):
        x = rng.randint(8, 24)
        y = rng.randint(27, 31)
        if abs(x - 16) > 6 and rng.random() < 0.6:
            continue
        d.point((x, y), fill=(176, 152, 134, 255))
    return im


def rosto_jota() -> Image.Image:
    """Oculos de aro alto, bigode, sardas e queixo raspado.

    Os oculos dele sao o oposto dos de Helmer: barra escura so em CIMA, o resto
    do aro claro. E o unico jeito de dois rostos de oculos e bigode nao lerem
    como a mesma pessoa a dois metros.
    """
    im, d = _base_da_cara()
    sep, y_olho, larg = 7, 14, 4
    barra = (42, 38, 40, 255)
    vidro = (198, 196, 194, 255)

    # Mesma correcao do Helmer: acima da barra escura dos oculos, e nao atras.
    _sobrancelhas(d, sep, y_olho - 6, larg, 1, (120, 96, 74, 255))
    _olhos(d, sep, y_olho, larg - 1)

    for lado in (-1, 1):
        ox = 16 + lado * sep
        d.line((ox - larg, y_olho - 3, ox + larg, y_olho - 3), fill=barra)
        d.line((ox - larg, y_olho - 2, ox + larg, y_olho - 2), fill=barra)
        d.line((ox - larg, y_olho + 4, ox + larg, y_olho + 4), fill=vidro)
        d.line((ox - larg, y_olho - 1, ox - larg, y_olho + 4), fill=vidro)
        d.line((ox + larg, y_olho - 1, ox + larg, y_olho + 4), fill=vidro)
    d.line((16 - 2, y_olho - 3, 16 + 2, y_olho - 3), fill=barra)

    ny = y_olho + 6
    d.line((16, y_olho + 3, 16, ny), fill=SOMBRA + (255,))
    d.point((15, ny), fill=(150, 122, 108, 255))
    d.point((17, ny), fill=(150, 122, 108, 255))

    _bigode(d, ny + 2, 5, (108, 78, 52, 255))
    # Boca mais cheia e queixo LIMPO: Jota nao tem barba, e o queixo raspado e
    # metade do que o distingue de Helmer de longe.
    d.line((13, 26, 19, 26), fill=(178, 108, 104, 255))
    d.point((13, 25), fill=(178, 108, 104, 255))
    d.point((19, 25), fill=(178, 108, 104, 255))

    rng = random.Random(9002)
    for _ in range(22):
        lado = rng.choice((-1, 1))
        x = 16 + lado * rng.randint(4, 10)
        y = rng.randint(17, 23)
        d.point((x, y), fill=(214, 176, 152, 255))
    return im


def cabelo_cacheado() -> Image.Image:
    """Cabelo em cacho, para a linha do elenco.

    As oito celulas de cabelo da linha 3 sao todas FIO VERTICAL, que e o
    desenho de cabelo liso. Tingir fio vertical de preto e chamar de cacheado
    nao funciona: continua lendo como liso escuro, porque o que diz "cacho" e a
    interrupcao da linha, e nao a cor.

    Aqui nao ha linha nenhuma. Sao tufos redondos encavalados, cada um com um
    lado claro e a sombra embaixo — e a sombra que separa um tufo do outro, e
    sem ela o conjunto vira uma mancha de ruido.
    """
    im = novo()
    d = ImageDraw.Draw(im)
    base = (232, 228, 222)
    d.rectangle((0, 0, 31, 31), fill=base + (255,))
    rng = random.Random(9101)
    # A celula se repete pelas faces da caixa de cabelo, entao os tufos que
    # encostam na borda tem de continuar do outro lado: por isso cada um e
    # desenhado tambem deslocado de 32 px nos dois eixos.
    for _ in range(26):
        cx = rng.randint(0, 31)
        cy = rng.randint(0, 31)
        r = rng.randint(3, 5)
        claro = tuple(min(255, c + rng.randint(4, 16)) for c in base)
        escuro = tuple(max(0, c - rng.randint(30, 52)) for c in base)
        for ox in (-32, 0, 32):
            for oy in (-32, 0, 32):
                x, y = cx + ox, cy + oy
                d.ellipse((x - r, y - r + 1, x + r, y + r + 1),
                          fill=escuro + (255,))
                d.ellipse((x - r, y - r, x + r - 1, y + r - 1),
                          fill=claro + (255,))
    return im


def perfil_alargador(cor) -> Image.Image:
    """Lado da cabeca com alargador no lobo.

    E o unico traco dos dois que aparece de perfil, e de perfil e como o jogador
    mais os ve: eles trabalham de lado para o corredor. Preto no Helmer,
    vermelho no Jota — a cor e o que separa os dois a cinco metros, quando o
    rosto ja nao se le.
    """
    im = novo()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 31, 31), fill=PELE + (255,))
    d.rectangle((0, 0, 2, 31), fill=SOMBRA + (255,))
    d.rectangle((0, 28, 31, 31), fill=SOMBRA + (255,))
    d.ellipse((13, 12, 19, 21), fill=(226, 208, 192, 255),
              outline=(174, 150, 136, 255))
    d.point((16, 16), fill=(170, 146, 132, 255))
    # O disco no lobo, com aro escuro em volta: sem contorno vira um ponto de
    # cor e le como brinco comum.
    d.ellipse((14, 20, 18, 24), fill=cor + (255,), outline=(58, 44, 40, 255))
    return im


def _espinho(d, x: int, y: int, dx: int, dy: int, cor) -> None:
    """Um espinho: a haste e o gancho. E a forma inteira da tatuagem."""
    d.line((x, y, x + dx, y + dy), fill=cor)
    d.line((x + dx, y + dy, x + dx - dy // 2, y + dy + dx // 2), fill=cor)


def pele_com_espinhos(e_nuca: bool) -> Image.Image:
    """Pele tatuada de espinhos pretos: pescoco, antebraco e mao do Jota.

    Uma celula serve os tres lugares, e nao e economia: a tatuagem dele e um
    desenho continuo que sobe do peito ate a mao, e a mesma celula repetida e
    justamente o que da a leitura de "e tudo a mesma coisa correndo pelo corpo".
    """
    im = novo()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 31, 31), fill=PELE + (255,))
    if e_nuca:
        d.rectangle((0, 24, 31, 31), fill=SOMBRA + (255,))
    tinta = (38, 34, 36, 255)
    rng = random.Random(9003 if e_nuca else 9004)
    # Duas hastes longas atravessando a celula, e os espinhos saindo delas. Sem
    # a haste continua, os ganchos soltos leem como sujeira na pele.
    for haste in range(2):
        x = 7 + haste * 13
        for y in range(0, 32, 2):
            d.point((x + rng.randint(-1, 1), y), fill=tinta)
            d.point((x + rng.randint(-1, 1), y + 1), fill=tinta)
    for _ in range(14):
        x = rng.randint(4, 27)
        y = rng.randint(2, 28)
        _espinho(d, x, y, rng.choice((-5, -4, 4, 5)), rng.choice((-3, 3)),
                 tinta)
    return im


# --- cabelo -----------------------------------------------------------------

def cabelo(indice: int) -> Image.Image:
    """Capacete de cabelo, visto de cima, de tras e dos lados.

    O cabelo e uma caixa por cima da cabeca, e nao pixel pintado na testa. Assim
    a silhueta muda de verdade: e a silhueta que distingue as pessoas a quinze
    metros na nevoa, nao o rosto, que a essa distancia tem quatro pixels.
    """
    im = novo()
    d = ImageDraw.Draw(im)
    rng = random.Random(4001 + indice * 131)
    base = (232, 228, 222)
    d.rectangle((0, 0, 31, 31), fill=base + (255,))
    # Fios: linhas verticais de tom levemente diferente. Chapado vira capacete
    # de plastico; com fio vira cabelo mesmo tingido de qualquer cor.
    for x in range(0, 32, 2):
        tom = rng.randint(-26, 10)
        cor = tuple(max(0, min(255, c + tom)) for c in base)
        d.line((x, 0, x + rng.randint(-1, 1), 31), fill=cor + (255,))
    if indice % 4 == 1:
        d.rectangle((9, 0, 11, 31), fill=(178, 172, 166, 255))
    if indice % 4 == 2:
        for _ in range(40):
            x, y = rng.randint(0, 30), rng.randint(0, 30)
            d.rectangle((x, y, x + 1, y + 1), fill=(200, 196, 190, 255))
    if indice >= 6:
        for y in range(0, 32, 3):
            d.line((0, y, 31, y + rng.randint(-1, 1)), fill=(196, 190, 184, 255))
    return im


# --- roupa ------------------------------------------------------------------

def camisa(indice: int, costas: bool) -> Image.Image:
    """Peito e costas do tronco.

    O padrao e desenhado quase branco pelo mesmo motivo da pele: a cor da roupa
    e sorteada por pessoa e entra como tint. O que varia aqui e o PADRAO — liso,
    listrado, xadrez, gola aberta — e padrao sobrevive ao tint.
    """
    im = novo()
    d = ImageDraw.Draw(im)
    rng = random.Random(9001 + indice * 617 + (7 if costas else 0))
    base = (236, 232, 226)
    d.rectangle((0, 0, 31, 31), fill=base + (255,))
    escuro = (198, 192, 184, 255)
    tipo = indice % 4

    if tipo == 0 and indice < 4:
        for y in range(2, 32, 5):
            d.rectangle((0, y, 31, y + 1), fill=escuro)
    elif tipo == 1:
        for x in range(1, 32, 4):
            d.line((x, 0, x, 31), fill=escuro)
    elif tipo == 2:
        for y in range(0, 32, 6):
            d.rectangle((0, y, 31, y + 1), fill=escuro)
        for x in range(0, 32, 6):
            d.rectangle((x, 0, x + 1, 31), fill=escuro)
    elif tipo == 3:
        ruidinho(d, rng, (0, 0, 31, 31), escuro, 90)

    if not costas:
        # Gola em V e uma sombra no meio: e o que faz o peito ler como frente.
        d.polygon([(12, 0), (16, 7), (20, 0)], fill=(174, 168, 160, 255))
        if indice % 3 == 0:
            d.line((16, 7, 16, 31), fill=(186, 180, 172, 255))
        if indice % 5 == 0:
            for y in range(9, 30, 4):
                d.point((16, y), fill=(120, 116, 110, 255))
    else:
        d.line((0, 3, 31, 3), fill=(210, 205, 198, 255))

    d.rectangle((0, 29, 31, 31), fill=(196, 190, 182, 255))
    return im


def casaco(indice: int) -> Image.Image:
    """Jaqueta ou casaco fechado. Ocupa o lugar da camisa quando a pessoa usa."""
    im = novo()
    d = ImageDraw.Draw(im)
    rng = random.Random(3301 + indice * 811)
    base = (230, 226, 220)
    d.rectangle((0, 0, 31, 31), fill=base + (255,))
    d.rectangle((14, 0, 17, 31), fill=(198, 192, 186, 255))
    d.line((16, 0, 16, 31), fill=(150, 146, 140, 255))
    if indice % 2 == 0:
        for y in range(4, 30, 6):
            d.rectangle((15, y, 17, y + 1), fill=(120, 116, 110, 255))
    d.polygon([(8, 0), (16, 6), (24, 0)], fill=(206, 200, 194, 255))
    d.rectangle((3, 20, 10, 23), fill=(206, 200, 194, 255))
    d.rectangle((21, 20, 28, 23), fill=(206, 200, 194, 255))
    if indice >= 5:
        ruidinho(d, rng, (0, 0, 31, 31), (208, 202, 196, 255), 70)
    return im


def calca(indice: int) -> Image.Image:
    """Calca, saia ou bermuda. A peca cobre as duas pernas na mesma celula."""
    im = novo()
    d = ImageDraw.Draw(im)
    rng = random.Random(5501 + indice * 409)
    base = (234, 230, 224)
    d.rectangle((0, 0, 31, 31), fill=base + (255,))
    # Cinto: uma faixa escura no topo. E o que separa camisa de calca quando as
    # duas caem em cores parecidas.
    d.rectangle((0, 0, 31, 2), fill=(150, 140, 130, 255))
    d.rectangle((14, 0, 17, 2), fill=(104, 96, 88, 255))
    if indice % 3 == 0:
        d.line((16, 3, 16, 31), fill=(206, 200, 192, 255))
    if indice % 3 == 1:
        ruidinho(d, rng, (0, 3, 31, 31), (208, 204, 198, 255), 110)
        d.line((2, 5, 2, 31), fill=(206, 200, 192, 255))
        d.line((29, 5, 29, 31), fill=(206, 200, 192, 255))
    if indice % 3 == 2:
        for y in range(6, 32, 7):
            d.line((0, y, 31, y), fill=(214, 210, 204, 255))
    return im


# --- pecas soltas -----------------------------------------------------------

def perfil(feminino: bool) -> Image.Image:
    """Lado da cabeca: orelha e sombra. Sem isso o perfil fica sem referencia e
    a cabeca le como caixa de papelao quando a pessoa passa de lado."""
    im = novo()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 31, 31), fill=PELE + (255,))
    d.rectangle((0, 0, 2, 31), fill=SOMBRA + (255,))
    d.rectangle((0, 28, 31, 31), fill=SOMBRA + (255,))
    d.ellipse((13, 12, 19, 21), fill=(226, 208, 192, 255), outline=(174, 150, 136, 255))
    d.point((16, 16), fill=(170, 146, 132, 255))
    if feminino:
        d.point((16, 22), fill=(206, 178, 92, 255))   # brinco
    return im


def nuca() -> Image.Image:
    im = novo()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 31, 31), fill=PELE + (255,))
    d.rectangle((0, 24, 31, 31), fill=SOMBRA + (255,))
    return im


def mao() -> Image.Image:
    im = novo()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 31, 31), fill=PELE + (255,))
    for x in range(4, 30, 7):
        d.line((x, 14, x, 31), fill=(206, 186, 170, 255))
    return im


def manga() -> Image.Image:
    """Braco de camisa. A faixa escura embaixo e a barra da manga."""
    im = novo()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 31, 31), fill=(234, 230, 224, 255))
    d.rectangle((0, 29, 31, 31), fill=(200, 194, 186, 255))
    return im


def sapato(indice: int) -> Image.Image:
    im = novo()
    d = ImageDraw.Draw(im)
    base = [(224, 220, 214), (206, 200, 194), (232, 228, 222)][indice % 3]
    d.rectangle((0, 0, 31, 31), fill=base + (255,))
    d.rectangle((0, 26, 31, 31), fill=(150, 146, 140, 255))
    if indice % 2 == 0:
        d.line((6, 8, 25, 8), fill=(186, 180, 174, 255))
        d.line((6, 13, 25, 13), fill=(186, 180, 174, 255))
    return im


def montar_atlas() -> None:
    atlas = Image.new("RGBA", (LADO, ALTURA_ATLAS), (0, 0, 0, 0))
    for i in range(VARIANTES):
        colar(atlas, i, LINHA_ROSTO_M, rosto(i, False))
        colar(atlas, i, LINHA_ROSTO_F, rosto(i, True))
        colar(atlas, i, LINHA_CABELO, cabelo(i))
        colar(atlas, i, LINHA_CAMISA, camisa(i, False))
        colar(atlas, i, LINHA_COSTAS, camisa(i, True))
        colar(atlas, i, LINHA_CALCA, calca(i))
        colar(atlas, i, LINHA_CASACO, casaco(i))

    # Linha de pecas soltas, na ordem que aparencia.gd espera.
    colar(atlas, 0, LINHA_PECAS, perfil(False))
    colar(atlas, 1, LINHA_PECAS, perfil(True))
    colar(atlas, 2, LINHA_PECAS, nuca())
    colar(atlas, 3, LINHA_PECAS, mao())
    colar(atlas, 4, LINHA_PECAS, manga())
    colar(atlas, 5, LINHA_PECAS, sapato(0))
    colar(atlas, 6, LINHA_PECAS, sapato(1))
    colar(atlas, 7, LINHA_PECAS, sapato(2))

    TEXTURAS.mkdir(parents=True, exist_ok=True)
    colar(atlas, ELENCO_ROSTO_HELMER, LINHA_ELENCO, rosto_helmer())
    colar(atlas, ELENCO_ROSTO_JOTA, LINHA_ELENCO, rosto_jota())
    colar(atlas, ELENCO_PERFIL_HELMER, LINHA_ELENCO, perfil_alargador((36, 32, 34)))
    colar(atlas, ELENCO_PERFIL_JOTA, LINHA_ELENCO, perfil_alargador((176, 34, 30)))
    colar(atlas, ELENCO_PELE_ESPINHOS, LINHA_ELENCO, pele_com_espinhos(False))
    colar(atlas, ELENCO_NUCA_ESPINHOS, LINHA_ELENCO, pele_com_espinhos(True))
    colar(atlas, ELENCO_CABELO_CACHEADO, LINHA_ELENCO, cabelo_cacheado())

    atlas.save(TEXTURAS / "npc_atlas.png", "PNG", optimize=True)
    print("npc_atlas            %dx%d  %d celulas" % (
        LADO, ALTURA_ATLAS, GRADE * LINHAS_TOTAIS))


# --- documento --------------------------------------------------------------

def guilhoche() -> None:
    """Fundo do documento: a trama de linhas finas de um papel de seguranca.

    Nao e o desenho de nenhum documento real, e nem poderia ser: sao ondas de
    seno em 128x128, quase sem contraste, feitas para ler como trama impressa
    atras do texto e sumir por baixo dele. E o mesmo truque do papel da prancha.
    """
    lado = 128
    im = Image.new("RGB", (lado, lado), (226, 232, 220))
    px = im.load()
    import math
    for y in range(lado):
        for x in range(lado):
            a = math.sin(x * 0.42) * math.cos(y * 0.31)
            b = math.sin((x + y) * 0.19)
            c = math.sin((x - y) * 0.27 + 1.1)
            v = (a + b * 0.6 + c * 0.5) / 2.1
            tom = int(10 * v)
            px[x, y] = (max(0, min(255, 222 + tom)),
                        max(0, min(255, 230 + tom)),
                        max(0, min(255, 214 + tom)))
    UI.mkdir(parents=True, exist_ok=True)
    im.save(UI / "doc_guilhoche.png", "PNG", optimize=True)
    print("doc_guilhoche        %dx%d" % (lado, lado))


def brasao() -> None:
    """Selo do documento.

    Deliberadamente NAO e o brasao da Republica. E um escudo generico com uma
    estrela, desenhado em 24 px: serve de marca de documento oficial dentro da
    ficcao do jogo sem reproduzir insignia de Estado nenhuma.
    """
    lado = 24
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    tinta = (46, 76, 52, 255)
    d.polygon([(12, 1), (22, 5), (22, 13), (12, 22), (2, 13), (2, 5)],
              fill=(214, 224, 206, 255), outline=tinta)
    d.polygon([(12, 5), (14, 10), (19, 10), (15, 13), (17, 18), (12, 15),
               (7, 18), (9, 13), (5, 10), (10, 10)], fill=tinta)
    im.save(UI / "doc_brasao.png", "PNG", optimize=True)
    print("doc_brasao           %dx%d" % (lado, lado))


def polegar() -> None:
    """Impressao digital do canto do documento. Aneis concentricos deformados."""
    lado = 32
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    px = im.load()
    import math
    for y in range(lado):
        for x in range(lado):
            dx = (x - 16) / 11.0
            dy = (y - 16) / 14.0
            r = math.sqrt(dx * dx + dy * dy)
            if r > 1.0:
                continue
            onda = math.sin(r * 15.0 + math.sin(dy * 3.0) * 1.4)
            if onda > 0.25:
                px[x, y] = (58, 52, 48, 220)
    im.save(UI / "doc_digital.png", "PNG", optimize=True)
    print("doc_digital          %dx%d" % (lado, lado))


# --- celular ----------------------------------------------------------------

def corpo_do_celular() -> None:
    """Carcaca do aparelho, em 168x252.

    O tamanho nao e escolha estetica: e o tamanho em que ele aparece na tela, e
    a textura e desenhada nele para cada pixel dela ser um pixel da tela. Com
    escala nao inteira e filtro nearest a moldura de um pixel vira ora um, ora
    dois, e o aparelho fica com a borda tremida.

    A largura veio de uma conta de texto, nao de gosto: o visor tem 146 px e a
    fonte pequena rende uns nove por caractere, entao cabem dezesseis letras por
    linha. Com os 130 px da primeira versao cabiam quatorze, e "REGISTRO NAO
    ENCONTRADO" — que e a resposta mais comum do portal — saia cortada.
    """
    larg, alt = 168, 252
    im = Image.new("RGBA", (larg, alt), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, larg - 1, alt - 1), radius=13,
                        fill=(74, 84, 92, 255), outline=(128, 140, 148, 255), width=2)
    d.rounded_rectangle((3, 3, larg - 4, alt - 4), radius=11,
                        fill=(38, 42, 46, 255))
    # Vao da tela. O jogo desenha por cima; aqui so fica o poco escuro.
    d.rectangle((11, 34, 156, 219), fill=(12, 14, 16, 255))
    d.rectangle((10, 33, 157, 220), outline=(96, 106, 114, 255))
    # Alto-falante e camera.
    d.rounded_rectangle((64, 18, 104, 23), radius=2, fill=(18, 20, 22, 255))
    d.ellipse((116, 17, 123, 24), fill=(18, 20, 22, 255),
              outline=(96, 106, 114, 255))
    # Botao de baixo.
    d.ellipse((71, alt - 28, 97, alt - 6), fill=(26, 28, 30, 255),
              outline=(112, 122, 130, 255))
    d.rounded_rectangle((78, alt - 22, 90, alt - 12), radius=2,
                        outline=(88, 96, 104, 255))
    # Brilho diagonal no plastico, numa camada propria.
    #
    # Desenhar direto com alfa 20 nao clareia: ImageDraw SUBSTITUI o pixel, alfa
    # incluso. As riscas viravam furos de alfa 20 atravessados no aparelho, e
    # dava para ver a rua atraves da carcaca — foi o que apareceu na captura
    # como "telefone transparente em certa parte". Compor a camada por cima
    # mistura, que e o que se queria desde o inicio.
    brilho = Image.new("RGBA", (larg, alt), (0, 0, 0, 0))
    bd = ImageDraw.Draw(brilho)
    for i in range(0, alt * 2, 3):
        x0, y0 = 4 + i // 2, 4
        x1, y1 = x0 - 40, alt - 5
        bd.line((x0, y0, x1, y1), fill=(112, 122, 130, 22))
    im.alpha_composite(brilho)
    # Recorta de volta o poco da tela, que o brilho invadiu.
    d.rectangle((11, 34, 156, 219), fill=(12, 14, 16, 255))
    im.save(UI / "fone_corpo.png", "PNG", optimize=True)
    print("fone_corpo           %dx%d" % (larg, alt))


ICONES_APP = {
    "portal": "escudo",
    "contatos": "pessoa",
    "mapa": "mapa",
    "mensagens": "envelope",
    "camera": "camera",
    "galeria": "foto",
    "radio": "antena",
    "config": "engrenagem",
    "telefone": "fone",
}


def icone_app(qual: str) -> Image.Image:
    """Icone de aplicativo em 16x16, so silhueta.

    Mesma regra dos icones do mapa: neste tamanho nao existe desenho bonito,
    existe desenho que se distingue dos outros oito a um relance.
    """
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    b = (246, 244, 238, 255)
    if qual == "escudo":
        d.polygon([(8, 1), (14, 4), (14, 9), (8, 15), (2, 9), (2, 4)], fill=b)
        d.polygon([(8, 4), (9, 7), (12, 7), (10, 9), (11, 12), (8, 10),
                   (5, 12), (6, 9), (4, 7), (7, 7)], fill=(60, 70, 60, 255))
    elif qual == "pessoa":
        d.ellipse((5, 2, 10, 7), fill=b)
        d.pieslice((2, 7, 13, 18), 180, 360, fill=b)
    elif qual == "mapa":
        d.polygon([(1, 4), (5, 2), (10, 5), (14, 3), (14, 12), (10, 14),
                   (5, 11), (1, 13)], fill=b)
        d.line((5, 2, 5, 11), fill=(60, 70, 60, 255))
        d.line((10, 5, 10, 14), fill=(60, 70, 60, 255))
    elif qual == "envelope":
        d.rectangle((1, 4, 14, 12), fill=b, outline=(60, 70, 60, 255))
        d.line((1, 4, 8, 9), fill=(60, 70, 60, 255))
        d.line((14, 4, 8, 9), fill=(60, 70, 60, 255))
    elif qual == "camera":
        d.rectangle((1, 5, 14, 13), fill=b)
        d.rectangle((5, 2, 10, 5), fill=b)
        d.ellipse((5, 6, 11, 12), fill=(60, 70, 60, 255))
        d.ellipse((7, 8, 9, 10), fill=b)
    elif qual == "foto":
        d.rectangle((1, 3, 14, 13), fill=b, outline=(60, 70, 60, 255))
        d.polygon([(3, 12), (7, 6), (10, 12)], fill=(60, 70, 60, 255))
        d.ellipse((10, 5, 12, 7), fill=(60, 70, 60, 255))
    elif qual == "antena":
        d.rectangle((7, 6, 9, 15), fill=b)
        d.line((3, 2, 7, 6), fill=b)
        d.line((13, 2, 9, 6), fill=b)
        d.ellipse((6, 4, 10, 8), fill=b)
    elif qual == "engrenagem":
        d.ellipse((3, 3, 13, 13), fill=b)
        for a in range(0, 360, 45):
            import math
            x = 8 + int(6 * math.cos(math.radians(a)))
            y = 8 + int(6 * math.sin(math.radians(a)))
            d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=b)
        d.ellipse((6, 6, 10, 10), fill=(60, 70, 60, 255))
    elif qual == "fone":
        d.polygon([(2, 3), (6, 3), (7, 7), (5, 9), (7, 11), (10, 13), (12, 11),
                   (14, 13), (13, 15), (9, 15), (4, 11), (2, 6)], fill=b)
    return im


def icones_do_celular() -> None:
    for nome, forma in ICONES_APP.items():
        icone_app(forma).save(UI / ("app_%s.png" % nome), "PNG", optimize=True)
    print("app_*                %d icones 16x16" % len(ICONES_APP))


def main() -> int:
    montar_atlas()
    guilhoche()
    brasao()
    polegar()
    corpo_do_celular()
    icones_do_celular()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# Redesenha as linhas de ROSTO, CAMISA e CASACO do npc_atlas.
#
# Por que um gerador e nao um PNG pintado a mao
# ---------------------------------------------
# Sao 32 celulas de 32x32 que precisam concordar entre si: a mesma gola no mesmo
# pixel, o mesmo par de olhos na mesma altura, a mesma barra na mesma linha. Em
# editor de imagem isso se mantem por disciplina; aqui se mantem por construcao,
# e trocar "a golaeh dois pixels mais alta" e uma linha em vez de 32 edicoes.
#
# As celulas saem em CINZA CLARO de proposito. O jogo tinge a peca pela cor
# escolhida (multiplicacao no shader), entao o que esta no atlas e o TECIDO --
# trama, costura, botao, ziper -- e nunca a cor. Celula escura tinge para preto.
#
# Preserva as linhas 2 (pecas), 3 (cabelo), 5 (costas) e 6 (calca) intactas: le
# o PNG existente, repinta so as linhas 0, 1, 4 e 7, e grava por cima.
#
# Uso: python tools/gerar_atlas_npc.py

from PIL import Image, ImageDraw
import os

CEL = 32
ATLAS = os.path.join("game", "assets", "textures", "npc_atlas.png")

L_ROSTO_M, L_ROSTO_F, L_CAMISA, L_CASACO = 0, 1, 4, 7

# --- paleta de pele -----------------------------------------------------------
PELE = (238, 222, 206, 255)
LADO = (206, 186, 170, 255)
QUEIXO = (222, 204, 190, 255)
SOMBRA = (208, 186, 172, 255)
TINTA = (92, 70, 58, 255)
TINTA_FRACA = (140, 116, 100, 255)
BOCA = (150, 96, 88, 255)
BOCA_FORTE = (168, 78, 78, 255)
DENTE = (250, 246, 240, 255)
OLHO = (250, 248, 244, 255)
VIDRO = (222, 230, 234, 255)

# --- paleta de tecido ---------------------------------------------------------
# Base clara: e ela que recebe a cor escolhida pelo jogador.
PANO = (214, 210, 202, 255)
PANO_CLARO = (240, 238, 232, 255)
PANO_MEIO = (192, 188, 179, 255)
PANO_FUNDO = (150, 146, 138, 255)
COSTURA = (120, 116, 108, 255)
FERRAGEM = (96, 94, 88, 255)
BRILHO = (246, 244, 240, 255)


def cel_box(c, r):
    return (c * CEL, r * CEL, c * CEL + CEL, r * CEL + CEL)


def nova(cor):
    im = Image.new("RGBA", (CEL, CEL), cor)
    return im, ImageDraw.Draw(im)


# =============================================================================
# ROSTOS
# =============================================================================
# O molde: faixa lateral escura nos dois lados (a lateral da cabeca, que a
# projecao do cubo estica), faixa de queixo embaixo, e o meio para as feicoes.
#
# Caricato quer dizer POUCA feicao e MUITA diferenca entre elas. Os rostos que
# havia aqui tinham olho de um pixel e sobrancelha de um pixel: em 32x32 vistos
# a trinta pixels de altura na tela, todos viravam a mesma cara. Aqui cada rosto
# perde detalhe e ganha um TRACO -- bigode, barba, oculos, cicatriz, olheira --
# que sobrevive a distancia.

def molde_rosto():
    im, d = nova(PELE)
    d.rectangle([0, 0, 2, 31], fill=LADO)
    d.rectangle([29, 0, 31, 31], fill=LADO)
    d.rectangle([0, 28, 31, 31], fill=QUEIXO)
    return im, d


def olhos(d, y, largura=4, altura=3, pupila=TINTA, aberto=True):
    for cx in (9, 22):
        x0 = cx - largura // 2
        if aberto:
            d.rectangle([x0, y, x0 + largura - 1, y + altura - 1], fill=OLHO)
            d.rectangle([x0 + 1, y + 1, x0 + 2, y + altura - 1], fill=pupila)
        else:
            d.rectangle([x0, y + 1, x0 + largura - 1, y + 1], fill=pupila)


def sobrancelhas(d, y, espessura=2, inclinacao=0, cor=TINTA, larg=7):
    # Um poligono inclinado, e nao dois retangulos empilhados. A versao com o
    # retangulo extra na ponta desenhava um degrau solto que, a trinta pixels de
    # altura na tela, lia como sujeira no rosto e nao como sobrancelha franzida.
    for lado, cx in ((-1, 9), (1, 22)):
        x0 = cx - larg // 2
        x1 = x0 + larg - 1
        sobe = inclinacao * lado
        d.polygon([(x0, y - min(0, sobe)), (x1, y + max(0, sobe)),
                   (x1, y + espessura + max(0, sobe)),
                   (x0, y + espessura - min(0, sobe))], fill=cor)


def nariz(d, topo=15, base=19, largura=2):
    d.rectangle([16 - largura // 2, topo, 16 + largura // 2, base], fill=SOMBRA)
    d.rectangle([15, base, 17, base], fill=TINTA_FRACA)


def boca_linha(d, y, larg=7, cor=BOCA):
    d.rectangle([16 - larg // 2, y, 16 + larg // 2, y + 1], fill=cor)


def boca_sorriso(d, y, larg=9):
    d.rectangle([16 - larg // 2, y, 16 + larg // 2, y + 2], fill=BOCA)
    d.rectangle([16 - larg // 2 + 1, y, 16 + larg // 2 - 1, y], fill=DENTE)
    d.point((16 - larg // 2 - 1, y - 1), fill=TINTA_FRACA)
    d.point((16 + larg // 2 + 1, y - 1), fill=TINTA_FRACA)


def bigode(d, y, larg=11, cor=TINTA):
    d.rectangle([16 - larg // 2, y, 16 + larg // 2, y + 2], fill=cor)
    d.rectangle([16 - larg // 2 - 1, y + 1, 16 - larg // 2, y + 3], fill=cor)
    d.rectangle([16 + larg // 2, y + 1, 16 + larg // 2 + 1, y + 3], fill=cor)


def barba(d, topo=19, cor=(120, 96, 80, 255)):
    # Com linha de mandibula, e nao um retangulo.
    #
    # A primeira versao preenchia um bloco de quatro a vinte e sete e descia ate
    # a borda da celula: na cara ela virava uma caixa preta encostada no queixo,
    # sem forma de barba nenhuma. Barba tem contorno — sobe pelas costeletas,
    # afina no queixo, e o bigode fica separado do resto por uma folga de pele.
    d.polygon([(3, 13), (7, 13), (8, topo), (12, topo + 5), (16, topo + 7),
               (20, topo + 5), (24, topo), (25, 13), (28, 13), (28, 27),
               (3, 27)], fill=cor)
    d.rectangle([0, 28, 31, 31], fill=cor)
    # Fio mais claro por cima: barba de uma cor so e mancha.
    for x in range(4, 28, 2):
        for y in range(topo + 2, 27, 2):
            if (x + y) % 4 == 0:
                d.point((x, y), fill=(146, 122, 104, 255))


def oculos(d, y, redondo=True, cor=TINTA):
    for cx in (9, 22):
        if redondo:
            d.ellipse([cx - 5, y - 2, cx + 4, y + 5], outline=cor, fill=VIDRO)
        else:
            d.rectangle([cx - 6, y - 1, cx + 5, y + 4], outline=cor, fill=VIDRO)
    d.rectangle([14, y + 1, 17, y + 1], fill=cor)
    d.rectangle([3, y, 4, y + 1], fill=cor)
    d.rectangle([27, y, 28, y + 1], fill=cor)


def sardas(d, cor=TINTA_FRACA):
    for x, y in [(7, 19), (10, 20), (12, 18), (20, 18), (23, 20), (25, 19),
                 (8, 22), (24, 22)]:
        d.point((x, y), fill=cor)


def olheiras(d, y, cor=(206, 182, 172, 255)):
    for cx in (9, 22):
        d.rectangle([cx - 3, y, cx + 2, y + 1], fill=cor)


def rostos_masculinos():
    saida = []

    # 0 - serio, mandibula pesada
    im, d = molde_rosto()
    sobrancelhas(d, 9, 3, 1)
    olhos(d, 13)
    nariz(d, 15, 20, 3)
    boca_linha(d, 23, 9)
    d.rectangle([4, 25, 8, 27], fill=SOMBRA)
    d.rectangle([23, 25, 27, 27], fill=SOMBRA)
    saida.append(im)

    # 1 - bigodudo
    im, d = molde_rosto()
    sobrancelhas(d, 9, 3)
    olhos(d, 13)
    nariz(d, 15, 18, 3)
    bigode(d, 20)
    boca_linha(d, 24, 7)
    saida.append(im)

    # 2 - barbudo, nariz grande
    im, d = molde_rosto()
    sobrancelhas(d, 8, 3)
    olhos(d, 12)
    d.rectangle([14, 14, 18, 20], fill=SOMBRA)
    d.rectangle([13, 20, 19, 21], fill=TINTA_FRACA)
    barba(d, 22)
    saida.append(im)

    # 3 - de oculos
    im, d = molde_rosto()
    sobrancelhas(d, 8, 2)
    olhos(d, 13, 3, 3)
    oculos(d, 12)
    nariz(d, 17, 20)
    boca_linha(d, 24, 5)
    saida.append(im)

    # 4 - cansado, barba por fazer
    im, d = molde_rosto()
    sobrancelhas(d, 10, 2, -1)
    olhos(d, 14, 4, 2)
    olheiras(d, 17)
    nariz(d, 17, 20)
    boca_linha(d, 24, 7, TINTA_FRACA)
    for x in range(5, 28, 2):
        for y in range(21, 28, 2):
            if (x + y) % 4 == 0:
                d.point((x, y), fill=TINTA_FRACA)
    saida.append(im)

    # 5 - sorridente
    im, d = molde_rosto()
    sobrancelhas(d, 7, 2)
    olhos(d, 12, 4, 3)
    nariz(d, 16, 19)
    boca_sorriso(d, 22)
    d.rectangle([4, 13, 5, 16], fill=SOMBRA)
    d.rectangle([26, 13, 27, 16], fill=SOMBRA)
    saida.append(im)

    # 6 - cicatriz sobre o olho
    im, d = molde_rosto()
    sobrancelhas(d, 9, 3, 2)
    olhos(d, 13)
    for i in range(9):
        d.point((7 + i // 3, 7 + i), fill=(178, 132, 118, 255))
    d.rectangle([6, 7, 7, 17], fill=(190, 146, 130, 255))
    nariz(d, 16, 20, 3)
    boca_linha(d, 24, 8)
    saida.append(im)

    # 7 - magro, faces fundas
    im, d = molde_rosto()
    sobrancelhas(d, 7, 2, -1)
    olhos(d, 12, 3, 3)
    # Cunhas, e nao barras: duas colunas retas de sombra leem como listra.
    d.polygon([(4, 14), (9, 17), (9, 23), (4, 25)], fill=SOMBRA)
    d.polygon([(27, 14), (22, 17), (22, 23), (27, 25)], fill=SOMBRA)
    nariz(d, 14, 21, 2)
    boca_linha(d, 25, 5, TINTA_FRACA)
    saida.append(im)
    return saida


def rostos_femininos():
    saida = []

    # 0 - neutra
    im, d = molde_rosto()
    sobrancelhas(d, 9, 1, 1, TINTA_FRACA, 6)
    olhos(d, 13, 5, 3)
    d.rectangle([6, 12, 11, 12], fill=TINTA)
    d.rectangle([20, 12, 25, 12], fill=TINTA)
    nariz(d, 17, 19)
    boca_linha(d, 23, 6, BOCA_FORTE)
    saida.append(im)

    # 1 - sardenta
    im, d = molde_rosto()
    sobrancelhas(d, 9, 1, 0, TINTA_FRACA, 6)
    olhos(d, 13, 5, 4)
    nariz(d, 17, 19)
    boca_sorriso(d, 22, 7)
    sardas(d)
    saida.append(im)

    # 2 - severa
    im, d = molde_rosto()
    sobrancelhas(d, 9, 2, 2, TINTA, 7)
    olhos(d, 14, 4, 2)
    nariz(d, 17, 20)
    boca_linha(d, 24, 7, BOCA)
    saida.append(im)

    # 3 - de oculos
    im, d = molde_rosto()
    sobrancelhas(d, 8, 1, 1, TINTA_FRACA, 6)
    olhos(d, 13, 4, 3)
    oculos(d, 12, False)
    nariz(d, 18, 20)
    boca_linha(d, 24, 5, BOCA_FORTE)
    saida.append(im)

    # 4 - sorridente com covinhas
    im, d = molde_rosto()
    sobrancelhas(d, 8, 1, 1, TINTA_FRACA, 6)
    olhos(d, 12, 5, 4)
    nariz(d, 16, 18)
    boca_sorriso(d, 21, 9)
    d.point((10, 24), fill=SOMBRA)
    d.point((21, 24), fill=SOMBRA)
    saida.append(im)

    # 5 - olhos grandes
    im, d = molde_rosto()
    sobrancelhas(d, 7, 1, 0, TINTA_FRACA, 5)
    olhos(d, 11, 6, 5)
    nariz(d, 18, 20, 2)
    boca_linha(d, 24, 5, BOCA_FORTE)
    saida.append(im)

    # 6 - batom forte
    im, d = molde_rosto()
    sobrancelhas(d, 8, 2, 1, TINTA, 7)
    olhos(d, 13, 5, 3)
    nariz(d, 17, 19)
    d.rectangle([12, 22, 20, 24], fill=BOCA_FORTE)
    d.rectangle([13, 22, 19, 22], fill=(192, 104, 104, 255))
    saida.append(im)

    # 7 - cansada
    im, d = molde_rosto()
    sobrancelhas(d, 10, 1, -1, TINTA_FRACA, 6)
    olhos(d, 14, 5, 2)
    olheiras(d, 17)
    nariz(d, 18, 20)
    boca_linha(d, 25, 6, TINTA_FRACA)
    saida.append(im)
    return saida


# =============================================================================
# TECIDOS
# =============================================================================
# Cada funcao pinta a TRAMA no fundo; gola, botao e costura entram depois. A
# separacao importa porque a trama e o que muda entre uma camisa e um casaco do
# mesmo tecido, e a gola e o que muda entre duas pecas do mesmo tecido.

def trama_lisa(d):
    for y in range(0, 32, 4):
        d.rectangle([0, y, 31, y], fill=(220, 217, 210, 255))


def trama_listrada(d, passo=3):
    for x in range(0, 32, passo):
        d.rectangle([x, 0, x, 31], fill=PANO_MEIO)
        d.rectangle([x + 1, 0, x + 1, 31], fill=(204, 200, 192, 255))


def trama_xadrez(d, passo=6):
    for x in range(0, 32, passo):
        d.rectangle([x, 0, x + 1, 31], fill=PANO_MEIO)
    for y in range(0, 32, passo):
        d.rectangle([0, y, 31, y + 1], fill=PANO_MEIO)
    for x in range(0, 32, passo):
        for y in range(0, 32, passo):
            d.rectangle([x, y, x + 1, y + 1], fill=PANO_FUNDO)


def trama_jeans(d):
    # Sarja: diagonal de tres em tres, que e o que faz o brim parecer brim.
    for y in range(32):
        for x in range(32):
            if (x + y) % 3 == 0:
                d.point((x, y), fill=PANO_MEIO)
            elif (x + y) % 6 == 1:
                d.point((x, y), fill=(224, 221, 214, 255))


def trama_canelada(d):
    for x in range(0, 32, 3):
        d.rectangle([x, 0, x, 31], fill=(226, 223, 216, 255))
        d.rectangle([x + 1, 0, x + 1, 31], fill=PANO_MEIO)


def trama_trancada(d):
    # Trico de trança: losangos empilhados em duas colunas largas.
    for y in range(0, 32, 8):
        for cx in (8, 23):
            for i in range(8):
                d.point((cx - 3 + i, y + i), fill=PANO_MEIO)
                d.point((cx + 4 - i, y + i), fill=PANO_MEIO)
    for x in range(0, 32, 15):
        d.rectangle([x, 0, x + 1, 31], fill=PANO_FUNDO)


def trama_couro(d):
    d.rectangle([0, 0, 31, 31], fill=(196, 192, 186, 255))
    for y in range(0, 32, 5):
        d.rectangle([0, y, 31, y], fill=(186, 182, 176, 255))
    # Lustro: o couro e a unica peca com reflexo, e e o reflexo que o nomeia.
    d.rectangle([5, 6, 8, 26], fill=(216, 213, 208, 255))
    d.rectangle([24, 8, 26, 24], fill=(210, 207, 202, 255))


def trama_nylon(d):
    for y in range(0, 32, 2):
        d.rectangle([0, y, 31, y], fill=(224, 222, 216, 255))
    for x in range(0, 32, 2):
        for y in range(0, 32, 4):
            d.point((x, y), fill=PANO_MEIO)


def trama_pontinhos(d):
    for x in range(2, 32, 6):
        for y in range(3, 32, 6):
            d.rectangle([x, y, x + 1, y + 1], fill=PANO_MEIO)
            d.point((x + 3, y + 3), fill=PANO_FUNDO)


# --- pecas de acabamento ------------------------------------------------------

def gola_v(d, prof=6, cor=PANO_FUNDO):
    for i in range(prof):
        d.point((15 - i // 2, i), fill=cor)
        d.point((16 + i // 2, i), fill=cor)
    d.rectangle([13, 0, 18, 1], fill=cor)


def gola_camisa(d, cor=PANO_FUNDO):
    d.polygon([(10, 0), (15, 0), (16, 5), (11, 4)], fill=PANO_CLARO, outline=cor)
    d.polygon([(21, 0), (16, 0), (15, 5), (20, 4)], fill=PANO_CLARO, outline=cor)


def gola_alta(d, cor=PANO_FUNDO):
    d.rectangle([9, 0, 22, 4], fill=PANO_CLARO)
    d.rectangle([9, 0, 22, 0], fill=cor)
    d.rectangle([9, 4, 22, 4], fill=cor)


def lapelas(d, cor=PANO_FUNDO):
    d.polygon([(9, 0), (15, 0), (16, 12), (12, 14)], fill=PANO_CLARO, outline=cor)
    d.polygon([(22, 0), (16, 0), (15, 12), (19, 14)], fill=PANO_CLARO, outline=cor)


def capuz(d, cor=PANO_FUNDO):
    d.ellipse([7, -6, 24, 8], fill=PANO_CLARO, outline=cor)
    d.rectangle([7, 5, 24, 7], fill=PANO_MEIO)
    d.rectangle([7, 7, 24, 7], fill=cor)


def placa_botoes(d, quantos=4, y0=6, cor=FERRAGEM):
    d.rectangle([14, 0, 17, 31], fill=PANO_CLARO)
    d.rectangle([14, 0, 14, 31], fill=COSTURA)
    d.rectangle([17, 0, 17, 31], fill=COSTURA)
    passo = (30 - y0) // max(1, quantos)
    for i in range(quantos):
        y = y0 + i * passo
        d.rectangle([15, y, 16, y + 1], fill=cor)


def ziper(d, y0=4, cor=FERRAGEM):
    d.rectangle([15, y0, 16, 31], fill=cor)
    for y in range(y0, 32, 2):
        d.point((15, y), fill=(200, 198, 192, 255))
    d.rectangle([14, y0, 17, y0 + 2], fill=cor)


def bolso(d, x0, y0, larg=9, alt=8, aba=True):
    d.rectangle([x0, y0, x0 + larg, y0 + alt], outline=COSTURA)
    if aba:
        d.rectangle([x0 - 1, y0 - 3, x0 + larg + 1, y0], fill=PANO_CLARO,
                    outline=COSTURA)
        d.point((x0 + larg // 2, y0 - 1), fill=FERRAGEM)


def barra(d, y=29, cor=COSTURA):
    d.rectangle([0, y, 31, y], fill=cor)
    d.rectangle([0, y + 2, 31, y + 2], fill=(226, 223, 216, 255))


def camisas():
    saida = []

    # 0 - lisa de botao
    im, d = nova(PANO)
    trama_lisa(d)
    gola_camisa(d)
    placa_botoes(d, 4, 7)
    bolso(d, 4, 12, 7, 6, False)
    barra(d)
    saida.append(im)

    # 1 - listrada
    im, d = nova(PANO)
    trama_listrada(d)
    gola_camisa(d)
    placa_botoes(d, 4, 7)
    barra(d)
    saida.append(im)

    # 2 - xadrez de flanela
    im, d = nova(PANO)
    trama_xadrez(d, 6)
    gola_camisa(d)
    placa_botoes(d, 5, 6)
    bolso(d, 3, 11, 8, 7)
    bolso(d, 21, 11, 8, 7)
    barra(d)
    saida.append(im)

    # 3 - jeans
    im, d = nova(PANO)
    trama_jeans(d)
    gola_camisa(d)
    placa_botoes(d, 4, 7)
    bolso(d, 3, 12, 8, 7)
    bolso(d, 21, 12, 8, 7)
    barra(d, 29, PANO_FUNDO)
    saida.append(im)

    # 4 - malha canelada, gola V
    im, d = nova(PANO)
    trama_canelada(d)
    gola_v(d, 9)
    barra(d)
    saida.append(im)

    # 5 - estampa de pontinhos
    im, d = nova(PANO)
    trama_pontinhos(d)
    gola_camisa(d)
    placa_botoes(d, 4, 7)
    barra(d)
    saida.append(im)

    # 6 - polo
    im, d = nova(PANO)
    trama_lisa(d)
    gola_camisa(d)
    d.rectangle([14, 4, 17, 13], fill=PANO_CLARO, outline=COSTURA)
    d.rectangle([15, 6, 16, 7], fill=FERRAGEM)
    d.rectangle([15, 10, 16, 11], fill=FERRAGEM)
    d.rectangle([0, 24, 31, 24], fill=PANO_MEIO)
    barra(d)
    saida.append(im)

    # 7 - gola alta de trico
    im, d = nova(PANO)
    trama_canelada(d)
    gola_alta(d)
    d.rectangle([0, 26, 31, 27], fill=PANO_MEIO)
    barra(d)
    saida.append(im)
    return saida


def casacos():
    saida = []

    # 0 - jaqueta jeans
    im, d = nova(PANO)
    trama_jeans(d)
    d.rectangle([0, 9, 31, 9], fill=COSTURA)
    gola_camisa(d)
    placa_botoes(d, 5, 6)
    bolso(d, 3, 12, 8, 7)
    bolso(d, 21, 12, 8, 7)
    d.rectangle([0, 27, 31, 28], fill=PANO_MEIO)
    barra(d, 29, PANO_FUNDO)
    saida.append(im)

    # 1 - jaqueta de couro
    im, d = nova(PANO)
    trama_couro(d)
    lapelas(d)
    # Ziper na diagonal: e o que diz "couro" antes de qualquer textura.
    for i in range(20):
        d.point((13 + i // 3, 10 + i), fill=FERRAGEM)
        d.point((14 + i // 3, 10 + i), fill=(206, 204, 198, 255))
    d.rectangle([0, 26, 31, 28], fill=(180, 176, 170, 255))
    d.rectangle([0, 26, 31, 26], fill=COSTURA)
    saida.append(im)

    # 2 - moletom com capuz
    im, d = nova(PANO)
    trama_lisa(d)
    capuz(d)
    d.rectangle([12, 7, 13, 15], fill=COSTURA)
    d.rectangle([18, 7, 19, 15], fill=COSTURA)
    d.point((12, 15), fill=FERRAGEM)
    d.point((19, 15), fill=FERRAGEM)
    # Bolso canguru.
    d.polygon([(6, 18), (25, 18), (24, 26), (7, 26)], outline=COSTURA)
    d.rectangle([0, 27, 31, 29], fill=PANO_MEIO)
    saida.append(im)

    # 3 - blazer
    im, d = nova(PANO)
    trama_lisa(d)
    lapelas(d)
    d.rectangle([13, 16, 14, 17], fill=FERRAGEM)
    d.rectangle([13, 22, 14, 23], fill=FERRAGEM)
    d.rectangle([20, 12, 27, 13], fill=COSTURA)
    d.rectangle([4, 20, 11, 21], fill=COSTURA)
    saida.append(im)

    # 4 - corta-vento de nylon
    im, d = nova(PANO)
    trama_nylon(d)
    gola_alta(d)
    d.rectangle([0, 11, 31, 12], fill=PANO_FUNDO)
    d.rectangle([0, 20, 31, 21], fill=PANO_MEIO)
    ziper(d, 5)
    d.rectangle([0, 27, 31, 29], fill=PANO_MEIO)
    saida.append(im)

    # 5 - casaco de la trancada
    im, d = nova(PANO)
    trama_trancada(d)
    gola_alta(d)
    placa_botoes(d, 4, 8, PANO_FUNDO)
    d.rectangle([0, 28, 31, 29], fill=PANO_MEIO)
    saida.append(im)

    # 6 - capa de chuva com capuz
    #
    # Pregas verticais largas e um lustro: capa de chuva e a unica peca que
    # reflete, e sem o reflexo ela vira um moletom sem bolso.
    im, d = nova(PANO_CLARO)
    for x in range(0, 32, 5):
        d.rectangle([x, 6, x, 31], fill=PANO_MEIO)
        d.rectangle([x + 1, 6, x + 1, 31], fill=(238, 236, 231, 255))
    capuz(d)
    d.rectangle([8, 8, 9, 30], fill=BRILHO)
    d.rectangle([23, 10, 24, 28], fill=(242, 240, 236, 255))
    ziper(d, 8)
    saida.append(im)

    # 7 - capa comprida
    #
    # Sem manga, sem botao, com fecho no pescoco e o pano caindo em pregas que
    # abrem para baixo. E a silhueta, e nao a textura, que faz uma capa.
    im, d = nova(PANO)
    trama_lisa(d)
    d.polygon([(11, 0), (20, 0), (22, 4), (9, 4)], fill=PANO_CLARO,
              outline=COSTURA)
    d.rectangle([14, 2, 17, 3], fill=FERRAGEM)
    for i, x in enumerate(range(2, 32, 6)):
        abertura = i - 2
        d.line([(x, 5), (x + abertura, 31)], fill=PANO_MEIO)
        d.line([(x + 1, 5), (x + 1 + abertura, 31)], fill=(228, 225, 218, 255))
    d.rectangle([0, 30, 31, 31], fill=PANO_FUNDO)
    saida.append(im)
    return saida


def main():
    im = Image.open(ATLAS).convert("RGBA")
    linhas = {
        L_ROSTO_M: rostos_masculinos(),
        L_ROSTO_F: rostos_femininos(),
        L_CAMISA: camisas(),
        L_CASACO: casacos(),
    }
    for r, celulas in linhas.items():
        assert len(celulas) == 8, "linha %d tem %d celulas" % (r, len(celulas))
        for c, cel in enumerate(celulas):
            im.paste(cel, cel_box(c, r))
    im.save(ATLAS)
    print("atlas regravado: linhas", sorted(linhas.keys()))


if __name__ == "__main__":
    main()

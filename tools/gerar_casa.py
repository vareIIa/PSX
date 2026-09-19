#!/usr/bin/env python3
"""Atlas da casa da fumaca: TV de tubo, console, controle e a tela do jogo.

Por que a tela do jogo esta num atlas, e nao num render
------------------------------------------------------
A TV precisa mostrar uma partida acontecendo. Renderizar um jogo de futebol
dentro do jogo custaria um SubViewport, uma camera e uma cena inteira por uma
imagem de dezesseis centimetros na tela — e essa e a definicao de custo sem
retorno. Aqui a partida sao QUATRO quadros de campo desenhados no atlas, que a
Televisao alterna a oito por segundo. A oito quadros, com o vulto dos jogadores
mudando de lugar, o olho completa o resto: e o mesmo truque das poses travadas
do corpo, e e o que um PS1 faria.

O campo e desenhado da diagonal alta, que e o angulo de transmissao que todo
jogo de futebol da epoca usava. De frente ninguem reconhece; da diagonal, o
verde listrado com a area e o circulo central dizem "futebol" antes de qualquer
outra coisa aparecer.

    python tools/gerar_casa.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
TEXTURAS = RAIZ / "game" / "assets" / "textures"

CELULA = 32
GRADE = 8
LADO = CELULA * GRADE

# --- linha 0: a partida, quatro quadros --------------------------------------
GRAMA_CLARA = (56, 118, 52)
GRAMA_ESCURA = (44, 100, 42)
LINHA = (196, 214, 190)


def colar(im: Image.Image, c: Image.Image, col: int, lin: int) -> None:
    im.paste(c, (col * CELULA, lin * CELULA))


def campo(quadro: int, rng: random.Random) -> Image.Image:
    """Um quadro da partida, visto da diagonal alta."""
    c = Image.new("RGBA", (CELULA, CELULA), GRAMA_ESCURA + (255,))
    d = ImageDraw.Draw(c)

    # Listras do gramado, inclinadas: e o corte da maquina, e e o que da
    # profundidade a um campo desenhado em trinta e dois pixels.
    for k in range(-4, CELULA, 6):
        d.polygon([(k, CELULA), (k + 3, CELULA), (k + 9, 0), (k + 6, 0)],
                  fill=GRAMA_CLARA + (255,))

    # Linhas do campo. A do meio e o circulo central bastam: area e escanteio
    # viram sujeira nesse tamanho.
    d.line((2, 20, CELULA - 3, 12), fill=LINHA + (255,))
    d.ellipse((11, 12, 21, 20), outline=LINHA + (255,))
    # Uma area, no canto de cima, para o campo ter fundo.
    d.rectangle((9, 1, 23, 6), outline=LINHA + (255,))

    # Os vultos. Sao dois pixels cada, e e o deslocamento deles entre quadros
    # que faz a partida existir. As posicoes vem de uma orbita lenta por jogador,
    # e nao de sorteio por quadro: sorteado, o time inteiro pisca de lugar.
    t = quadro / 4.0
    times = [((228, 232, 236), (30, 34, 40)), ((40, 60, 150), (220, 220, 60))]
    for j in range(9):
        base_x = 5 + (j * 7) % 22
        base_y = 6 + (j * 5) % 20
        ang = math.tau * (t + j * 0.11)
        x = int(base_x + math.cos(ang) * 2.2)
        y = int(base_y + math.sin(ang) * 1.4)
        cor = times[j % 2][0]
        d.rectangle((x, y, x + 1, y + 2), fill=cor + (255,))
        d.point((x, y + 3), fill=times[j % 2][1] + (255,))

    # A bola, que anda mais que todo mundo.
    bx = int(16 + math.cos(math.tau * t) * 9)
    by = int(15 + math.sin(math.tau * t * 1.3) * 5)
    d.point((bx, by), fill=(250, 250, 246, 255))

    # Placar: a tarja escura no alto, com dois blocos de numero. Ilegivel de
    # proposito — o que se le e "tem placar", e placar e o que separa uma tela
    # de futebol de um campo vazio.
    d.rectangle((3, 0, 20, 4), fill=(20, 22, 28, 220))
    d.rectangle((4, 1, 8, 3), fill=(220, 220, 210, 255))
    d.rectangle((15, 1, 19, 3), fill=(220, 220, 210, 255))
    _ = rng
    return c


# --- linha 1: TV, console, controle ------------------------------------------

def plasticos(im: Image.Image, rng: random.Random) -> None:
    def plastico(base, sujeira, riscos=0):
        c = Image.new("RGBA", (CELULA, CELULA), base + (255,))
        cam = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
        d = ImageDraw.Draw(cam)
        for _ in range(sujeira):
            d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                    fill=tuple(max(0, v - 22) for v in base) + (70,))
        for _ in range(riscos):
            x = rng.randrange(CELULA)
            y = rng.randrange(CELULA)
            d.line((x, y, x + rng.randrange(2, 7), y), fill=(255, 255, 255, 26))
        c.alpha_composite(cam)
        return c

    # 0 gabinete da TV: o bege que amarelou. E a cor que data o objeto sozinha.
    colar(im, plastico((186, 178, 156), 40, 6), 0, 1)
    # 1 traseira da TV, mais escura e com as ranhuras de ventilacao.
    c = plastico((150, 144, 126), 30)
    d = ImageDraw.Draw(c)
    for y in range(6, 26, 3):
        d.line((6, y, CELULA - 7, y), fill=(112, 106, 92, 255))
    colar(im, c, 1, 1)
    # 2 moldura preta em volta do tubo.
    colar(im, plastico((34, 34, 36), 20), 2, 1)
    # 3 console: o preto fosco do PS2, com a listra do leitor.
    c = plastico((28, 28, 32), 18, 3)
    d = ImageDraw.Draw(c)
    d.rectangle((0, 13, CELULA, 16), fill=(48, 48, 54, 255))
    d.ellipse((22, 4, 28, 10), outline=(90, 90, 100, 255))
    colar(im, c, 3, 1)
    # 4 controle: cinza com os quatro botoes.
    c = plastico((196, 194, 190), 22)
    d = ImageDraw.Draw(c)
    for (bx, by, cor) in [(22, 8, (60, 150, 90)), (26, 12, (190, 60, 60)),
                          (22, 16, (70, 90, 180)), (18, 12, (200, 150, 60))]:
        d.ellipse((bx, by, bx + 3, by + 3), fill=cor + (255,))
    d.rectangle((5, 10, 11, 15), fill=(110, 110, 114, 255))
    colar(im, c, 4, 1)
    # 5 cabo: preto liso, esticado ao longo da celula.
    c = Image.new("RGBA", (CELULA, CELULA), (22, 22, 24, 255))
    d = ImageDraw.Draw(c)
    d.line((0, 12, CELULA, 12), fill=(44, 44, 48, 255))
    colar(im, c, 5, 1)
    # 6 madeira do rack da TV.
    c = plastico((104, 74, 48), 46)
    d = ImageDraw.Draw(c)
    for y in range(2, CELULA, 7):
        d.line((0, y, CELULA, y), fill=(86, 60, 38, 255))
    colar(im, c, 6, 1)
    # 7 tecido do sofa.
    c = plastico((92, 82, 96), 60)
    colar(im, c, 7, 1)


# --- linha 2: caixa de CD, poster, cinzeiro ----------------------------------

def miudezas(im: Image.Image, rng: random.Random) -> None:
    # 0 caixinha de CD pirata, com a capa borrada. E o objeto que conta a
    # historia do comodo sem uma linha de texto.
    c = Image.new("RGBA", (CELULA, CELULA), (216, 214, 210, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((3, 3, CELULA - 4, CELULA - 4), fill=(40, 90, 50, 255))
    d.rectangle((3, 3, CELULA - 4, 9), fill=(200, 40, 36, 255))
    for k in range(5):
        d.line((6, 13 + k * 3, 6 + rng.randrange(8, 20), 13 + k * 3),
               fill=(230, 230, 220, 255))
    colar(im, c, 0, 2)

    # 1 poster de time na parede.
    c = Image.new("RGBA", (CELULA, CELULA), (222, 218, 208, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 0, CELULA - 1, 7), fill=(180, 30, 34, 255))
    d.ellipse((10, 11, 22, 23), fill=(240, 240, 236, 255),
              outline=(30, 30, 34, 255))
    d.line((10, 17, 22, 17), fill=(30, 30, 34, 255))
    colar(im, c, 1, 2)

    # 2 cinzeiro cheio.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.ellipse((2, 6, CELULA - 3, CELULA - 7), fill=(180, 176, 168, 255),
              outline=(120, 116, 110, 255))
    d.ellipse((7, 11, CELULA - 8, CELULA - 12), fill=(96, 92, 88, 255))
    # Pontas apagadas, com a boquilha de papel torcida numa ponta e a cinza na
    # outra. O que identifica um baseado a essa escala nao e o tamanho: e a
    # ponta conica e a cor de papel pardo, contra o branco reto do cigarro.
    for _ in range(7):
        x = rng.randrange(9, 21)
        y = rng.randrange(12, 19)
        d.line((x, y, x + 3, y + 1), fill=(206, 188, 152, 255))
        d.point((x + 4, y + 1), fill=(58, 52, 46, 255))
    colar(im, c, 2, 2)

    # 3 garrafa deitada.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rectangle((4, 12, 24, 20), fill=(58, 96, 52, 220))
    d.rectangle((24, 14, 29, 18), fill=(58, 96, 52, 220))
    d.rectangle((8, 13, 18, 19), fill=(210, 200, 170, 255))
    colar(im, c, 3, 2)


# --- linha 2, colunas 4 a 7: o console e o controle ---------------------------

def console(im: Image.Image, rng: random.Random) -> None:
    """O PS2 em pe e o DualShock 2.

    Quatro celulas e nao uma. A versao anterior era UMA celula preta com uma
    listra, aplicada nas seis faces de uma caixa deitada: a listra do leitor
    aparecia no topo, no fundo e nos dois lados, e a frente nao tinha nada.
    Lido de tres metros era um losango escuro no chao, indistinguivel de uma
    caixa de pizza fechada.

    O que faz um PS2 ser reconhecivel nao e a cor — preto fosco e todo aparelho
    da epoca. Sao tres coisas, e cada uma mora numa face diferente:

      frente   a faixa das duas portas de controle e dos dois memory card, os
               dois botoes redondos e o ponto azul aceso
      lado     a faixa vertical clara do logo, que e a assinatura do aparelho
               em pe e o unico detalhe que se le a cinco metros
      topo     as ranhuras de ventilacao e a tampa da baia de expansao

    Em pe, e nao deitado. A silhueta vertical e o que identifica o aparelho de
    longe, e era como metade do Brasil usava.
    """
    preto = (26, 26, 30)

    def corpo(sujeira: int) -> Image.Image:
        c = Image.new("RGBA", (CELULA, CELULA), preto + (255,))
        d = ImageDraw.Draw(c)
        for _ in range(sujeira):
            d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                    fill=(44, 44, 50, 90))
        return c

    # 4 frente: a faixa de portas embaixo, os botoes e o LED em cima.
    c = corpo(16)
    d = ImageDraw.Draw(c)
    # A costura da bandeja, so aqui. Horizontal na celula porque a face da
    # frente do aparelho em pe e alta e estreita: a UV estica a celula ao longo
    # da altura e a linha vira a divisao do leitor.
    d.line((2, 12, CELULA - 3, 12), fill=(62, 62, 70, 255))
    d.line((2, 13, CELULA - 3, 13), fill=(12, 12, 14, 255))
    # Botao de liga e botao de eject, redondos, lado a lado.
    for bx in (8, 20):
        d.ellipse((bx, 4, bx + 4, 8), fill=(52, 52, 58, 255),
                  outline=(78, 78, 86, 255))
    # O LED. E um pixel e meio de azul num campo preto, e e a unica luz fria
    # baixa do comodo — ver CasaFumacaBuilder._console_e_cabos, que poe uma
    # Omni minuscula no mesmo ponto.
    d.rectangle((15, 5, 16, 7), fill=(90, 180, 255, 255))
    # As duas portas de controle e os dois memory card, na faixa de baixo.
    d.rectangle((3, 20, CELULA - 4, 28), fill=(18, 18, 22, 255))
    for px in (5, 18):
        d.rectangle((px, 22, px + 8, 26), fill=(40, 40, 46, 255),
                    outline=(70, 70, 78, 255))
    colar(im, c, 4, 2)

    # 5 lado: a faixa vertical do logo.
    c = corpo(12)
    d = ImageDraw.Draw(c)
    d.rectangle((4, 0, 9, CELULA - 1), fill=(52, 52, 60, 255))
    d.rectangle((5, 0, 8, CELULA - 1), fill=(120, 120, 130, 255))
    # Tres blocos claros dentro da faixa: e o logo a trinta e dois pixels. Ler
    # "PlayStation" nessa escala e impossivel e nao e o ponto — o ponto e haver
    # marca escrita ali, que e o que separa um aparelho de uma caixa preta.
    for y in (7, 15, 23):
        d.rectangle((5, y, 8, y + 3), fill=(226, 226, 232, 255))
    colar(im, c, 5, 2)

    # 6 topo e traseira: ventilacao e a tampa da baia.
    c = corpo(10)
    d = ImageDraw.Draw(c)
    for y in range(6, 27, 3):
        d.line((6, y, CELULA - 7, y), fill=(14, 14, 16, 255))
    d.rectangle((9, 11, 22, 21), outline=(48, 48, 56, 255))
    colar(im, c, 6, 2)

    # 7 DualShock 2: preto, dois analogicos, direcional e os quatro botoes.
    #
    # O controle de antes era CINZA com quatro botoes coloridos e um
    # direcional — a cara de um controle de 16 bits, uma geracao antes do
    # aparelho que estava no chao ao lado dele.
    #
    # A celula e OPACA e preenche os 32 px, e nao um recorte com o contorno do
    # controle. Quem desenha a forma e a geometria: tres caixas, corpo e dois
    # cabos de mao. Recorte num objeto de quinze centimetros e o mesmo erro que
    # `Adereco` documenta no cigarro — com `alpha_cutoff`, quase tudo some e
    # sobra um risco na tela.
    c = corpo(14)
    d = ImageDraw.Draw(c)
    # Direcional a esquerda, quatro botoes a direita. Os simbolos do PS2 sao
    # cinza sobre preto e nao coloridos: colorido aqui le como Super Nintendo.
    d.rectangle((3, 14, 10, 17), fill=(48, 48, 54, 255))
    d.rectangle((5, 11, 8, 20), fill=(48, 48, 54, 255))
    for (bx, by) in [(24, 11), (27, 14), (24, 18), (21, 14)]:
        d.ellipse((bx, by, bx + 3, by + 3), fill=(98, 98, 106, 255))
    # Os dois analogicos, embaixo e no meio.
    for bx in (12, 18):
        d.ellipse((bx, 19, bx + 4, 23), fill=(34, 34, 40, 255),
                  outline=(78, 78, 88, 255))
    # A fresta entre os dois gatilhos, no alto.
    d.line((2, 5, CELULA - 3, 5), fill=(12, 12, 14, 255))
    colar(im, c, 7, 2)


# --- linha 7: os quatro cartazes da parede ------------------------------------

def cartazes(im: Image.Image, rng: random.Random) -> None:
    """Quatro cartazes diferentes, um por parede.

    Os quatro da sala usavam a MESMA celula — um poster de time, repetido em
    quatro alturas e quatro inclinacoes. Numa parede de nove metros e oitenta
    isso nao le como quatro cartazes: le como quatro copias, e copia denuncia
    gerador. O cabecalho do comodo diz que os cartazes existem porque parede
    limpa de nove metros le como corredor de escola; quatro iguais leem como
    corredor de escola com um poster oficial.

    Nenhum deles e legivel, e nao e para ser. A trinta e dois pixels o que
    identifica um cartaz e a MANCHA: onde esta a area escura, onde esta a cor
    forte, se ha um rosto ou uma tipografia. Quatro manchas diferentes bastam
    para o olho parar de contar copias.
    """

    def papel(base):
        c = Image.new("RGBA", (CELULA, CELULA), base + (255,))
        d = ImageDraw.Draw(c)
        # Amassado e sujeira: cartaz de parede de sala nao e impressao nova.
        for _ in range(26):
            x = rng.randrange(CELULA)
            y = rng.randrange(CELULA)
            d.point((x, y), fill=tuple(max(0, v - 26) for v in base) + (110,))
        return c

    # 0 banda: fundo preto e tipografia branca em bloco. A mancha e o contraste
    # duro no terco de cima.
    c = papel((22, 20, 26))
    d = ImageDraw.Draw(c)
    for k in range(4):
        largura = rng.randrange(5, 11)
        d.rectangle((3 + k * 7, 5, 3 + k * 7 + largura - 4, 12),
                    fill=(236, 232, 226, 255))
    d.rectangle((4, 18, CELULA - 5, 20), fill=(180, 36, 40, 255))
    for k in range(3):
        d.rectangle((6, 23 + k * 3, 6 + rng.randrange(10, 20), 24 + k * 3),
                    fill=(120, 116, 112, 255))
    colar(im, c, 0, 7)

    # 1 time: a camisa listrada em preto e branco, de pe, com o numero nas
    # costas. A primeira versao — branco com faixa azul em cima e embaixo e um
    # hexagono azul no meio — era, pixel por pixel, a bandeira de Israel. Camisa
    # listrada vertical e o que "cartaz de time" le no Brasil, e nao le como
    # bandeira de pais nenhum.
    c = papel((214, 208, 196))
    d = ImageDraw.Draw(c)
    preto = (26, 24, 26, 255)
    branco = (232, 230, 224, 255)
    camisa = [(9, 6), (13, 4), (19, 4), (23, 6), (28, 11), (25, 14), (23, 12),
              (23, 28), (9, 28), (9, 12), (7, 14), (4, 11)]
    d.polygon(camisa, fill=branco)
    for x in range(10, 23, 4):
        d.rectangle((x, 5, x + 1, 27), fill=preto)
    d.polygon([(13, 4), (16, 7), (19, 4)], fill=(150, 140, 128, 255))
    d.rectangle((13, 13, 19, 20), fill=branco)
    d.text((13, 12), "9", fill=preto)
    d.polygon(camisa, outline=(60, 56, 54, 255))
    colar(im, c, 1, 7)

    # 2 filme: um rosto grande em alto contraste, meia cara na sombra. E a
    # mancha mais reconhecivel das quatro — o olho acha cara em qualquer escala.
    c = papel((30, 26, 30))
    d = ImageDraw.Draw(c)
    d.ellipse((8, 4, 24, 24), fill=(206, 176, 148, 255))
    d.rectangle((16, 4, 24, 24), fill=(96, 78, 70, 255))
    d.ellipse((11, 11, 14, 14), fill=(24, 22, 24, 255))
    d.ellipse((18, 11, 21, 14), fill=(24, 22, 24, 255))
    d.rectangle((3, 27, CELULA - 4, 30), fill=(200, 40, 36, 255))
    colar(im, c, 2, 7)

    # 3 calendario de oficina: carro vermelho baixo e um mes em tarja.
    c = papel((216, 214, 206))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 0, CELULA - 1, 4), fill=(40, 44, 52, 255))
    d.rectangle((3, 14, 28, 21), fill=(190, 34, 32, 255))
    d.polygon([(8, 14), (12, 9), (21, 9), (24, 14)], fill=(150, 24, 22, 255))
    d.ellipse((6, 19, 11, 24), fill=(28, 26, 28, 255))
    d.ellipse((20, 19, 25, 24), fill=(28, 26, 28, 255))
    for k in range(4):
        d.line((4, 26 + k, CELULA - 5, 26 + k), fill=(160, 156, 150, 255))
    colar(im, c, 3, 7)



# --- linha 3: o que a casa e --------------------------------------------------

def juventude(im: Image.Image, rng: random.Random) -> None:
    """Baseado, saquinho, mochila, skate e caixa de som.

    Estas celulas fazem mais pelo lugar do que a planta inteira. Uma sala com
    sofa e TV e uma sala; a mesma sala com skate encostado na parede, mochila
    largada no chao e caixa de som no canto e a casa de alguem de dezenove anos
    cujos pais nao estao. E isso que o comodo tem de dizer no primeiro quadro.
    """
    # 0 baseado: papel pardo, cone para a ponta acesa, boquilha torcida atras.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.polygon([(3, 14), (3, 18), (25, 19), (25, 13)], fill=(214, 198, 164, 255))
    d.polygon([(3, 14), (3, 18), (7, 17), (7, 15)], fill=(178, 158, 124, 255))
    d.line((7, 15, 7, 17), fill=(150, 132, 104, 255))
    # A brasa. O ponto quente e desenhado aqui, mas quem acende de verdade e a
    # luz do no: uma brasa pintada na textura nao ilumina o rosto de quem fuma.
    d.rectangle((25, 13, 28, 19), fill=(255, 150, 60, 255))
    d.rectangle((27, 14, 28, 18), fill=(255, 226, 170, 255))
    colar(im, c, 0, 3)

    # 1 saquinho: plastico com o verde dentro. Sem folha desenhada — a folha de
    # cinco pontas vira mancha a trinta e dois pixels, e o que le e a massa
    # verde irregular dentro de um retangulo transparente.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rectangle((5, 6, 26, 27), fill=(228, 232, 228, 90),
                outline=(200, 206, 200, 160))
    d.rectangle((5, 3, 26, 7), fill=(206, 212, 206, 200))
    for _ in range(26):
        x = rng.randrange(8, 24)
        y = rng.randrange(11, 25)
        t = rng.randrange(2, 4)
        verde = (rng.randrange(58, 96), rng.randrange(98, 140), rng.randrange(44, 70))
        d.ellipse((x, y, x + t, y + t), fill=verde + (255,))
    colar(im, c, 1, 3)

    # 2 mochila: lona com bolso, ziper e alca.
    c = Image.new("RGBA", (CELULA, CELULA), (48, 58, 84, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((4, 16, CELULA - 5, CELULA - 2), fill=(40, 50, 74, 255))
    d.line((4, 15, CELULA - 5, 15), fill=(150, 152, 158, 255))
    d.arc((8, 2, 24, 18), 180, 360, fill=(30, 38, 58, 255), width=3)
    for x in range(6, 26, 3):
        d.point((x, 15), fill=(200, 200, 206, 255))
    colar(im, c, 2, 3)

    # 3 lixa do skate: preta, gasta no meio pelo pe.
    c = Image.new("RGBA", (CELULA, CELULA), (30, 30, 32, 255))
    d = ImageDraw.Draw(c)
    for _ in range(90):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=(56, 56, 60, 120))
    d.ellipse((9, 8, 23, 24), fill=(74, 72, 70, 90))
    colar(im, c, 3, 3)

    # 4 fundo do shape: o desenho da marca, que aqui e so cor e faixa.
    c = Image.new("RGBA", (CELULA, CELULA), (168, 44, 40, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 11, CELULA, 20), fill=(232, 218, 60, 255))
    d.ellipse((11, 11, 21, 21), fill=(30, 30, 34, 255))
    colar(im, c, 4, 3)

    # 5 frente da caixa de som: dois cones e o painel prateado dos anos 2000.
    c = Image.new("RGBA", (CELULA, CELULA), (36, 36, 40, 255))
    d = ImageDraw.Draw(c)
    d.ellipse((3, 10, 21, 28), fill=(24, 24, 26, 255), outline=(96, 96, 102, 255))
    d.ellipse((9, 16, 15, 22), fill=(70, 70, 76, 255))
    d.ellipse((22, 6, 29, 13), fill=(24, 24, 26, 255), outline=(96, 96, 102, 255))
    d.rectangle((2, 1, CELULA - 3, 5), fill=(150, 152, 158, 255))
    d.rectangle((4, 2, 12, 4), fill=(40, 120, 180, 255))
    colar(im, c, 5, 3)

    # 6 lateral da caixa: madeira revestida, como toda caixa dessa epoca.
    c = Image.new("RGBA", (CELULA, CELULA), (58, 48, 42, 255))
    d = ImageDraw.Draw(c)
    for y in range(1, CELULA, 5):
        d.line((0, y, CELULA, y), fill=(48, 40, 34, 255))
    colar(im, c, 6, 3)

    # 7 fumaca: mancha macia, para o quad que sobe do cinzeiro e da brasa.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    meio = CELULA / 2.0
    for r in range(15, 0, -1):
        alfa = int(78 * (1.0 - r / 15.0) ** 1.6)
        d.ellipse((meio - r, meio - r, meio + r, meio + r),
                  fill=(214, 216, 210, alfa))
    colar(im, c, 7, 3)


# --- linha 4: fumaca e olhos --------------------------------------------------

def _ruido_wrap(rng: random.Random, celulas: int) -> list[list[float]]:
    """Ruido de valor que fecha nas quatro bordas.

    Tem de fechar: a camada do teto e uma placa com a UV correndo, e uma textura
    que nao emenda mostra uma costura atravessando a sala a cada volta.
    """
    grade = [[rng.random() for _ in range(celulas)] for _ in range(celulas)]
    campo = [[0.0] * CELULA for _ in range(CELULA)]
    passo = CELULA / celulas
    for y in range(CELULA):
        for x in range(CELULA):
            gx = x / passo
            gy = y / passo
            x0, y0 = int(gx) % celulas, int(gy) % celulas
            x1, y1 = (x0 + 1) % celulas, (y0 + 1) % celulas
            fx, fy = gx - int(gx), gy - int(gy)
            # Suavizacao cubica: linear deixa losango visivel na grade.
            fx = fx * fx * (3 - 2 * fx)
            fy = fy * fy * (3 - 2 * fy)
            a = grade[y0][x0] * (1 - fx) + grade[y0][x1] * fx
            b = grade[y1][x0] * (1 - fx) + grade[y1][x1] * fx
            campo[y][x] = a * (1 - fy) + b * fy
    return campo


def fumaca(im: Image.Image, rng: random.Random) -> None:
    """As duas fumacas: a camada do teto e a coluna que sobe de um cigarro."""
    # 0 camada do teto: nuvem que emenda nos quatro lados. Duas oitavas bastam —
    # a terceira nao muda nada a 480x270 e triplica o custo do script.
    grosso = _ruido_wrap(rng, 4)
    fino = _ruido_wrap(rng, 8)
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    px = c.load()
    for y in range(CELULA):
        for x in range(CELULA):
            v = grosso[y][x] * 0.68 + fino[y][x] * 0.32
            # O corte tira o fundo e deixa so os grumos: sem ele a camada e um
            # veu uniforme, que le como vidro sujo e nao como fumaca.
            a = max(0.0, (v - 0.42) / 0.58)
            # Tom quente: vapor de sauna, nao nevoa fria de rua.
            tom = 214 + int(v * 26)
            px[x, y] = (tom, tom - 14, tom - 28, int(a * 210))
    colar(im, c, 0, 4)

    # 1 olhos vermelhos: mascara alinhada com a celula do rosto.
    #
    # As coordenadas nao sao inventadas — sao as do gerar_npc: olho em y de 13 a
    # 15, centro em x 16, separacao de 6 a 8. A mancha e larga o bastante para
    # cobrir as tres separacoes possiveis, porque a mascara e uma so para todos
    # os rostos e nao da para saber qual saiu.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    cam = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(cam)
    for lado in (-1, 1):
        ox = 16 + lado * 7
        # Duas passadas: a mancha larga e fraca em volta do olho, e o traco
        # forte na palpebra de baixo, que e onde o vermelho aparece de verdade.
        # Alfa baixo: em PSX, vermelho cheio vira farol; sangue discreto basta.
        for raio, alfa in ((6, 42), (4, 68), (2, 96)):
            d.ellipse((ox - raio, 14 - raio, ox + raio, 14 + raio),
                      fill=(148, 52, 46, alfa))
        d.line((ox - 5, 16, ox + 5, 16), fill=(162, 54, 48, 112))
        d.line((ox - 4, 17, ox + 4, 17), fill=(132, 44, 40, 72))
    c.alpha_composite(cam)
    colar(im, c, 1, 4)

    # 2 baforada: coluna vertical que emenda em cima e embaixo, para a UV poder
    # correr para cima sem fim.
    grade = _ruido_wrap(rng, 4)
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    px = c.load()
    for y in range(CELULA):
        for x in range(CELULA):
            v = grade[y][x]
            # Estreita no pe e larga no topo: e a forma de uma baforada subindo.
            meio = abs(x - CELULA / 2.0) / (CELULA / 2.0)
            largura = 0.28 + 0.72 * (1.0 - y / CELULA)
            corte = max(0.0, 1.0 - meio / max(0.08, largura))
            a = max(0.0, (v - 0.40) / 0.60) * corte * (0.35 + 0.65 * (y / CELULA))
            px[x, y] = (228, 214, 196, int(min(1.0, a) * 215))
    colar(im, c, 2, 4)


# --- linhas 5 e 6: a estufa ---------------------------------------------------

def _folha_de_cinco(d, cx: float, cy: float, raio: float, ang: float,
                    cor, borda) -> None:
    """Uma folha de cinco pontas, desenhada foliolo por foliolo.

    Nao e enfeite: a folha de cannabis e uma SILHUETA, reconhecida antes de
    qualquer cor, e e a unica coisa que precisa estar certa nesta celula.
    Desenhada como mancha verde, a planta vira arbusto e a estufa perde o
    assunto.

    Os cinco foliolos tem comprimentos diferentes — o do meio e o maior e os das
    pontas os menores — porque folha com cinco dedos iguais le como estrela.
    """
    comprimentos = (0.62, 0.86, 1.0, 0.86, 0.62)
    for k, escala in enumerate(comprimentos):
        a = ang + (k - 2) * 0.42
        comp = raio * escala
        larg = max(1.2, comp * 0.22)
        dx, dy = math.cos(a) * comp * 0.5, math.sin(a) * comp * 0.5
        px, py = cx + dx, cy + dy
        nx, ny = -math.sin(a) * larg, math.cos(a) * larg
        # Retangulo girado a mao: o PIL nao gira primitiva, e para um foliolo de
        # oito pixels o poligono de quatro pontos sai melhor que a elipse.
        d.polygon([(px - dx, py - dy), (px + nx * 0.5, py + ny * 0.5),
                   (px + dx, py + dy), (px - nx * 0.5, py - ny * 0.5)],
                  fill=cor, outline=borda)


def estufa_planta(im: Image.Image, rng: random.Random) -> None:
    """Linha 5: a planta, o vaso, a parede espelhada e o equipamento."""
    # 0 folhagem: o painel que se cruza para virar planta. Recorte por alfa, e
    # por isso o fundo e transparente e a massa verde tem de ter vao: folhagem
    # sem buraco entre as folhas vira placa pintada de verde.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    for _ in range(14):
        cx = rng.uniform(5, 27)
        cy = rng.uniform(4, 29)
        raio = rng.uniform(7, 12)
        tom = rng.randrange(-16, 17)
        verde = (46 + tom, 96 + tom, 44 + tom // 2, 255)
        _folha_de_cinco(d, cx, cy, raio, rng.uniform(0, math.tau), verde,
                        (28, 58, 30, 255))
    colar(im, c, 0, 5)

    # 1 cabeca florida: o topo do ramo, mais claro e com os pistilos alaranjados.
    # E a celula que diz "esta pronta" — folha verde sozinha e so mato.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    for k in range(9):
        y = 3 + k * 3
        larg = int(3 + (CELULA - y) * 0.30)
        d.ellipse((16 - larg, y, 16 + larg, y + 6),
                  fill=(88, 130, 66, 255), outline=(60, 96, 50, 255))
    for _ in range(40):
        d.point((rng.randrange(6, 26), rng.randrange(4, 30)),
                fill=(206, 132, 54, 255))
    for _ in range(60):
        d.point((rng.randrange(6, 26), rng.randrange(4, 30)),
                fill=(150, 190, 110, 180))
    colar(im, c, 1, 5)

    # 2 vaso de feltro preto, com a costura e a alca.
    c = Image.new("RGBA", (CELULA, CELULA), (38, 38, 40, 255))
    d = ImageDraw.Draw(c)
    for _ in range(120):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=(56, 56, 58, 160))
    d.rectangle((0, 4, CELULA, 6), fill=(28, 28, 30, 255))
    d.rectangle((6, 12, 12, 22), outline=(64, 64, 68, 255))
    colar(im, c, 2, 5)

    # 3 mylar: a manta espelhada da parede. O amassado e o assunto — chapa lisa
    # nao le como mylar, le como aluminio novo, que nao e o que forra estufa.
    c = Image.new("RGBA", (CELULA, CELULA), (188, 192, 196, 255))
    d = ImageDraw.Draw(c)
    for _ in range(26):
        x0, y0 = rng.randrange(CELULA), rng.randrange(CELULA)
        d.line((x0, y0, x0 + rng.randrange(-9, 10), y0 + rng.randrange(-9, 10)),
               fill=(220, 226, 230, 255))
    for _ in range(20):
        x0, y0 = rng.randrange(CELULA), rng.randrange(CELULA)
        d.line((x0, y0, x0 + rng.randrange(-7, 8), y0 + rng.randrange(-7, 8)),
               fill=(146, 152, 160, 255))
    colar(im, c, 3, 5)

    # 4 refletor: o capuz de aluminio da luminaria, visto por fora.
    c = Image.new("RGBA", (CELULA, CELULA), (168, 172, 176, 255))
    d = ImageDraw.Draw(c)
    for y in range(0, CELULA, 4):
        d.line((0, y, CELULA, y), fill=(140, 144, 150, 255))
    d.rectangle((10, 12, 21, 19), fill=(96, 98, 104, 255))
    colar(im, c, 4, 5)

    # 5 mangueira preta de irrigacao, com as nervuras.
    c = Image.new("RGBA", (CELULA, CELULA), (26, 26, 28, 255))
    d = ImageDraw.Draw(c)
    for x in range(0, CELULA, 3):
        d.line((x, 0, x, CELULA), fill=(44, 44, 48, 255))
    d.line((0, 10, CELULA, 10), fill=(70, 70, 76, 255))
    colar(im, c, 5, 5)

    # 6 tanque de agua: o azul do reservatorio, com a regua de nivel.
    c = Image.new("RGBA", (CELULA, CELULA), (46, 92, 140, 255))
    d = ImageDraw.Draw(c)
    for _ in range(60):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=(58, 108, 158, 200))
    d.rectangle((24, 2, 28, CELULA - 3), fill=(150, 200, 220, 120))
    for y in range(6, CELULA - 4, 6):
        d.line((23, y, 29, y), fill=(230, 236, 240, 255))
    colar(im, c, 6, 5)

    # 7 grade do ventilador: aneis concentricos sobre transparente.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    meio = CELULA / 2.0
    for r in range(3, 16, 3):
        d.ellipse((meio - r, meio - r, meio + r, meio + r),
                  outline=(184, 186, 190, 255))
    for k in range(8):
        a = math.tau * k / 8.0
        d.line((meio, meio, meio + math.cos(a) * 15, meio + math.sin(a) * 15),
               fill=(184, 186, 190, 255))
    d.ellipse((meio - 3, meio - 3, meio + 3, meio + 3), fill=(70, 70, 74, 255))
    colar(im, c, 7, 5)


def estufa_colheita(im: Image.Image, rng: random.Random) -> None:
    """Linha 6: chao, painel, potes, secagem, saco, duto, lona e terra."""
    # 0 piso epoxi cinza, com respingo de terra.
    c = Image.new("RGBA", (CELULA, CELULA), (108, 110, 108, 255))
    d = ImageDraw.Draw(c)
    for _ in range(140):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=(96, 98, 96, 180))
    for _ in range(10):
        x, y = rng.randrange(CELULA), rng.randrange(CELULA)
        d.ellipse((x, y, x + rng.randrange(2, 6), y + rng.randrange(2, 5)),
                  fill=(78, 72, 62, 140))
    colar(im, c, 0, 6)

    # 1 painel de controle: temporizador e disjuntores. E o objeto que faz a
    # sala ler como INSTALACAO e nao como canteiro — planta em vaso qualquer um
    # tem; timer, contator e cabo em canaleta e que dizem estufa montada.
    c = Image.new("RGBA", (CELULA, CELULA), (206, 206, 200, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((2, 2, CELULA - 3, CELULA - 3), outline=(120, 120, 116, 255))
    d.rectangle((5, 5, 26, 13), fill=(24, 30, 26, 255))
    d.rectangle((7, 7, 15, 11), fill=(90, 220, 140, 255))
    for x in range(6, 26, 5):
        d.rectangle((x, 18, x + 3, 26), fill=(60, 60, 64, 255))
        d.point((x + 1, 19), fill=(230, 80, 60, 255))
    colar(im, c, 1, 6)

    # 2 pote de vidro com a colheita dentro.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rectangle((6, 5, 25, CELULA - 3), fill=(214, 224, 218, 90),
                outline=(180, 192, 186, 200))
    d.rectangle((5, 2, 26, 6), fill=(150, 146, 140, 255))
    for _ in range(34):
        x = rng.randrange(8, 23)
        y = rng.randrange(12, 27)
        t = rng.randrange(2, 5)
        d.ellipse((x, y, x + t, y + t),
                  fill=(rng.randrange(70, 104), rng.randrange(110, 146),
                        rng.randrange(48, 74), 255))
    colar(im, c, 2, 6)

    # 3 ramo pendurado secando, de cabeca para baixo. Recorte.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.line((16, 0, 16, CELULA - 4), fill=(96, 84, 56, 255), width=2)
    for k in range(6):
        y = 4 + k * 4
        larg = 3 + k
        for lado in (-1, 1):
            d.line((16, y, 16 + lado * larg * 2, y + 5),
                   fill=(74, 96, 54, 255), width=2)
            _folha_de_cinco(d, 16 + lado * larg * 2, y + 6, 5.0,
                            math.pi * 0.5, (66, 92, 50, 255), (44, 64, 38, 255))
    colar(im, c, 3, 6)

    # 4 saco de papel pardo da colheita, dobrado no alto.
    c = Image.new("RGBA", (CELULA, CELULA), (150, 122, 84, 255))
    d = ImageDraw.Draw(c)
    for _ in range(80):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=(136, 110, 74, 180))
    d.rectangle((0, 0, CELULA, 6), fill=(122, 98, 66, 255))
    d.line((0, 7, CELULA, 7), fill=(96, 78, 52, 255))
    for y in range(10, CELULA, 8):
        d.line((4, y, CELULA - 5, y), fill=(138, 112, 76, 255))
    colar(im, c, 4, 6)

    # 5 duto flexivel de aluminio, com o sanfonado.
    c = Image.new("RGBA", (CELULA, CELULA), (162, 166, 172, 255))
    d = ImageDraw.Draw(c)
    for x in range(0, CELULA, 4):
        d.line((x, 0, x, CELULA), fill=(128, 132, 140, 255))
        d.line((x + 1, 0, x + 1, CELULA), fill=(200, 204, 210, 255))
    colar(im, c, 5, 6)

    # 6 lona branca da tenda, com o vinco e a costura.
    c = Image.new("RGBA", (CELULA, CELULA), (222, 222, 216, 255))
    d = ImageDraw.Draw(c)
    for _ in range(50):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=(206, 206, 200, 200))
    for y in range(0, CELULA, 11):
        d.line((0, y, CELULA, y), fill=(196, 196, 190, 255))
    colar(im, c, 6, 6)

    # 7 terra do vaso, molhada.
    c = Image.new("RGBA", (CELULA, CELULA), (62, 50, 38, 255))
    d = ImageDraw.Draw(c)
    for _ in range(180):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=(rng.randrange(44, 84), rng.randrange(34, 62),
                      rng.randrange(24, 46), 255))
    for _ in range(14):
        x, y = rng.randrange(CELULA), rng.randrange(CELULA)
        d.ellipse((x, y, x + 2, y + 2), fill=(34, 28, 22, 255))
    colar(im, c, 7, 6)


# --- linha 7, colunas 4 a 7: os insumos ---------------------------------------

def estufa_insumos(im: Image.Image, rng: random.Random) -> None:
    """As quatro celulas que fazem a estufa virar uma OPERACAO.

    Ate aqui a sala tinha planta e equipamento, e isso ja e uma estufa bonita.
    O que faltava era o que ENTRA: terra, semente e agua. Sao as tres coisas que
    o jogador vai buscar e as tres que Helmer e Jota carregam o dia inteiro, e
    nenhuma delas tinha celula — o saco de papel da colheita (4,6) e o que SAI,
    e usar o mesmo desenho para as duas pontas do ciclo faria a sala inteira
    parecer ter um objeto so.

    O pote vazio e a quarta, e existe pelo mesmo motivo: o pote CHEIO ja existia
    em (2,6), e uma prateleira que enche precisa dos dois para mostrar que
    encheu.
    """
    # 4 pote de vidro VAZIO. Recorte, e quase todo transparente: vidro sem nada
    # dentro e contorno e reflexo, e mais que isso vira copo de plastico leitoso.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rectangle((6, 5, 25, CELULA - 3), fill=(214, 224, 218, 46),
                outline=(180, 192, 186, 200))
    d.rectangle((5, 2, 26, 6), fill=(150, 146, 140, 255))
    # O brilho vertical do vidro, unico no lado esquerdo: dois brilhos simetricos
    # leem como plastico moldado, e um so le como vidro.
    d.line((9, 9, 9, CELULA - 6), fill=(240, 246, 244, 150))
    colar(im, c, 4, 7)

    # 5 saco de terra. Plastico preto com a tarja impressa, que e como saco de
    # substrato e vendido — o saco de papel pardo e o da colheita, e sao coisas
    # diferentes na mesma sala.
    c = Image.new("RGBA", (CELULA, CELULA), (48, 46, 44, 255))
    d = ImageDraw.Draw(c)
    for _ in range(90):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=(62, 60, 58, 170))
    d.rectangle((0, 11, CELULA, 21), fill=(206, 200, 186, 255))
    d.rectangle((3, 13, CELULA - 4, 19), fill=(74, 112, 58, 255))
    for x in range(6, 27, 4):
        d.line((x, 14, x, 18), fill=(206, 200, 186, 255))
    # A dobra do alto e o vinco de baixo: saco liso le como caixa preta.
    d.line((0, 5, CELULA, 5), fill=(30, 28, 28, 255))
    d.line((0, CELULA - 5, CELULA, CELULA - 5), fill=(30, 28, 28, 255))
    colar(im, c, 5, 7)

    # 6 regador. Verde de ferramenta, com o bico e a rosca da crivo.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rectangle((7, 10, 23, 29), fill=(62, 104, 74, 255),
                outline=(40, 72, 52, 255))
    for y in range(12, 28, 4):
        d.line((8, y, 22, y), fill=(72, 118, 84, 255))
    # O bico sobe do corpo e cai para fora: bico reto le como caneca.
    d.line((23, 14, 29, 7), fill=(62, 104, 74, 255), width=3)
    d.ellipse((26, 3, CELULA - 1, 9), fill=(150, 156, 152, 255),
              outline=(40, 72, 52, 255))
    # A alca por cima, que e o que distingue regador de lata.
    d.arc((9, 2, 21, 14), 190, 350, fill=(40, 72, 52, 255), width=2)
    colar(im, c, 6, 7)

    # 7 caixa de sementes: madeira clara, com as divisorias e as sementes.
    c = Image.new("RGBA", (CELULA, CELULA), (146, 116, 78, 255))
    d = ImageDraw.Draw(c)
    for y in range(0, CELULA, 6):
        d.line((0, y, CELULA, y), fill=(132, 104, 70, 255))
    d.rectangle((2, 2, CELULA - 3, CELULA - 3), outline=(98, 76, 52, 255))
    d.line((CELULA // 2, 3, CELULA // 2, CELULA - 4), fill=(98, 76, 52, 255))
    for _ in range(26):
        x = rng.randrange(4, CELULA - 6)
        y = rng.randrange(6, CELULA - 6)
        # Semente de cannabis e uma gota malhada, e nao um ponto: a mancha e o
        # que a faz nao virar sujeira na madeira.
        d.ellipse((x, y, x + 3, y + 4), fill=(92, 74, 50, 255),
                  outline=(54, 42, 28, 255))
        d.point((x + 1, y + 1), fill=(160, 140, 104, 255))
    colar(im, c, 7, 7)


def lente(im: Image.Image) -> None:
    """A lente acesa da luminaria, na celula 3 da linha 4.

    Vai num material emissivo: quem ILUMINA a estufa e a lampada do no, e esta
    celula e o que se ve quando o jogador olha para cima. Sem ela a luminaria
    fica com um retangulo preto embaixo e luz saindo do nada.
    """
    c = Image.new("RGBA", (CELULA, CELULA), (255, 244, 214, 255))
    d = ImageDraw.Draw(c)
    for y in range(0, CELULA, 5):
        d.line((0, y, CELULA, y), fill=(255, 232, 178, 255))
    d.rectangle((0, 0, CELULA - 1, CELULA - 1), outline=(228, 200, 150, 255))
    colar(im, c, 3, 4)


def main() -> int:
    TEXTURAS.mkdir(parents=True, exist_ok=True)
    rng = random.Random(19981114)
    im = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))

    for k in range(4):
        colar(im, campo(k, rng), k, 0)
    plasticos(im, rng)
    miudezas(im, rng)
    console(im, rng)
    cartazes(im, rng)
    juventude(im, rng)
    fumaca(im, rng)
    lente(im)
    estufa_planta(im, rng)
    estufa_colheita(im, rng)
    estufa_insumos(im, rng)

    destino = TEXTURAS / "casa_atlas.png"
    im.save(destino)
    print(f"gravado {destino.relative_to(RAIZ)}  {LADO}x{LADO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

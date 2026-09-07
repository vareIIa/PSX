#!/usr/bin/env python3
"""Atlas do carro: lataria, vidro, roda, farol e as lentes do semaforo.

Mesma economia do atlas de gente, pelo mesmo motivo
---------------------------------------------------
Um transito de seis carros com textura propria seriam seis imagens carregadas
para cinco silhuetas que o jogador ve a trinta metros dentro da nevoa. Aqui ha
UMA imagem de 256x256, dividida em celulas de 32, e a variacao vem de onde nao
custa arquivo:

    qual celula      capo, porta, cacamba, grade, para-choque
    cor de vertice   a pintura inteira do carro

Doze tintas na tabela de Carroceria vezes cinco silhuetas dao sessenta carros
distintos com um arquivo so.

Por que os paineis sao quase brancos
------------------------------------
Pelo mesmo motivo do rosto no atlas de gente: o shader multiplica o albedo pela
cor de vertice, e um painel ja pintado multiplicaria duas vezes — todo carro
sairia escuro. A celula carrega SO a informacao que a cor nao carrega: o brilho
da quina, a linha da porta, a sujeira embaixo. A cor vem do tint.

    python tools/gerar_carro.py
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

# Chapa quase branca. O tom real entra por cor de vertice.
CHAPA = (232, 230, 226)
CHAPA_SOMBRA = (196, 194, 190)
CHAPA_BRILHO = (250, 250, 248)


def colar(im: Image.Image, c: Image.Image, col: int, lin: int) -> None:
    im.paste(c, (col * CELULA, lin * CELULA))


def ruido(d: ImageDraw.ImageDraw, rng: random.Random, n: int,
          cor: tuple[int, int, int], alfa: int = 40) -> None:
    """Sujeira. Sempre em camada propria, nunca direto no alfa da celula.

    ImageDraw SUBSTITUI o pixel, alfa incluso, em vez de compor: desenhar com
    alfa 40 sobre uma chapa opaca faz um buraco de alfa 40, e a carroceria fica
    transparente. Foi assim que a carcaca do celular ficou vazada.
    """
    for _ in range(n):
        x = rng.randrange(CELULA)
        y = rng.randrange(CELULA)
        d.point((x, y), fill=cor + (alfa,))


def chapa_base(rng: random.Random, sujeira: int = 26) -> Image.Image:
    """Painel liso com uma leve variacao de chapa."""
    c = Image.new("RGBA", (CELULA, CELULA), CHAPA + (255,))
    marcas = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(marcas)
    ruido(d, rng, sujeira, CHAPA_SOMBRA, 34)
    c.alpha_composite(marcas)
    return c


# --- linha 0: paineis de lataria --------------------------------------------

def paineis(im: Image.Image, rng: random.Random) -> None:
    # 0 lataria lisa
    colar(im, chapa_base(rng, 14), 0, 0)

    # 1 lataria suja: o carro velho da frota. Uma em sete, ver Carroceria.
    c = chapa_base(rng, 20)
    marcas = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(marcas)
    for _ in range(4):
        x = rng.randrange(2, CELULA - 6)
        y = rng.randrange(CELULA - 12, CELULA - 2)
        d.ellipse((x, y, x + rng.randrange(3, 7), y + 2), fill=(120, 96, 74, 120))
    d.line((0, CELULA - 3, CELULA, CELULA - 2), fill=(108, 92, 76, 90))
    c.alpha_composite(marcas)
    colar(im, c, 1, 0)

    # 2 capo: duas nervuras longitudinais, que e o que o olho le como capo.
    c = chapa_base(rng, 10)
    d = ImageDraw.Draw(c)
    for x in (10, 21):
        d.line((x, 2, x, CELULA - 3), fill=CHAPA_SOMBRA + (255,))
        d.line((x + 1, 2, x + 1, CELULA - 3), fill=CHAPA_BRILHO + (255,))
    colar(im, c, 2, 0)

    # 3 teto: chapa quase lisa, com o vinco da calha nas bordas.
    c = chapa_base(rng, 8)
    d = ImageDraw.Draw(c)
    d.line((1, 0, 1, CELULA), fill=CHAPA_SOMBRA + (255,))
    d.line((CELULA - 2, 0, CELULA - 2, CELULA), fill=CHAPA_SOMBRA + (255,))
    colar(im, c, 3, 0)

    # 4 porta: a linha de recorte e a macaneta. E a celula mais vista do carro,
    # porque a lateral e o que se ve de dentro de outro carro e da calcada.
    c = chapa_base(rng, 12)
    d = ImageDraw.Draw(c)
    d.line((11, 3, 11, CELULA - 6), fill=CHAPA_SOMBRA + (255,))
    d.line((12, 3, 12, CELULA - 6), fill=CHAPA_BRILHO + (255,))
    d.line((2, CELULA - 9, CELULA - 3, CELULA - 9), fill=CHAPA_SOMBRA + (255,))
    d.rectangle((14, 11, 18, 13), fill=(150, 148, 146, 255))
    colar(im, c, 4, 0)

    # 5 traseira: a tampa e o vinco embaixo do vigia.
    c = chapa_base(rng, 12)
    d = ImageDraw.Draw(c)
    d.line((2, 9, CELULA - 3, 9), fill=CHAPA_SOMBRA + (255,))
    d.line((2, 10, CELULA - 3, 10), fill=CHAPA_BRILHO + (255,))
    colar(im, c, 5, 0)

    # 6 soleira: a faixa escura embaixo da porta, onde a lama bate.
    c = Image.new("RGBA", (CELULA, CELULA), (108, 104, 100, 255))
    d = ImageDraw.Draw(c)
    ruido(d, rng, 40, (72, 66, 60), 200)
    colar(im, c, 6, 0)

    # 7 cacamba: chapa corrugada da picape.
    c = chapa_base(rng, 16)
    d = ImageDraw.Draw(c)
    for y in range(3, CELULA - 2, 5):
        d.line((0, y, CELULA, y), fill=CHAPA_SOMBRA + (255,))
    colar(im, c, 7, 0)


# --- linha 1: vidro e detalhe da frente -------------------------------------

def vidros(im: Image.Image, rng: random.Random) -> None:
    def vidro(reflexo: bool) -> Image.Image:
        c = Image.new("RGBA", (CELULA, CELULA), (70, 82, 92, 255))
        cam = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
        d = ImageDraw.Draw(cam)
        # A faixa clara atravessada e o unico reflexo que um vidro de PS1 tem, e
        # e o que impede o para-brisa de ler como buraco preto no carro.
        if reflexo:
            d.polygon([(0, CELULA - 6), (CELULA, 4), (CELULA, 12),
                       (0, CELULA + 2)], fill=(168, 190, 206, 110))
        d.rectangle((0, 0, CELULA - 1, 1), fill=(40, 44, 48, 255))
        c.alpha_composite(cam)
        return c

    colar(im, vidro(True), 0, 1)
    colar(im, vidro(False), 1, 1)
    colar(im, vidro(True), 2, 1)

    # 3 grade: barras horizontais escuras.
    c = Image.new("RGBA", (CELULA, CELULA), (52, 52, 56, 255))
    d = ImageDraw.Draw(c)
    for y in range(2, CELULA - 1, 4):
        d.line((1, y, CELULA - 2, y), fill=(96, 96, 100, 255))
    colar(im, c, 3, 1)

    # 4 para-choque: cromado gasto.
    c = Image.new("RGBA", (CELULA, CELULA), (176, 178, 180, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 0, CELULA, CELULA // 2), fill=(206, 208, 210, 255))
    ruido(d, rng, 30, (120, 118, 116), 160)
    colar(im, c, 4, 1)

    # 5 placa: cinza do Brasil dos anos noventa, com tres letras e quatro
    # numeros insinuados. Nao da para ler a 480x270 e nao precisa: o que se le e
    # que ALI tem uma placa, e e isso que faz o carro parecer registrado.
    c = Image.new("RGBA", (CELULA, CELULA), (206, 206, 202, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((1, 8, CELULA - 2, CELULA - 9), outline=(60, 60, 64, 255))
    for i, x in enumerate(range(4, 28, 3)):
        if i == 3:
            continue
        d.line((x, 12, x, 19), fill=(40, 40, 44, 255))
    colar(im, c, 5, 1)

    # 6 letreiro de taxi.
    c = Image.new("RGBA", (CELULA, CELULA), (232, 226, 210, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 0, CELULA - 1, 5), fill=(180, 40, 32, 255))
    for x in range(6, 26, 4):
        d.line((x, 12, x, 22), fill=(40, 40, 44, 255))
    colar(im, c, 6, 1)

    # 7 fundo: o assoalho, visto so quando o carro capota.
    c = Image.new("RGBA", (CELULA, CELULA), (84, 82, 80, 255))
    d = ImageDraw.Draw(c)
    ruido(d, rng, 60, (58, 54, 50), 200)
    colar(im, c, 7, 1)


# --- linha 2: roda ----------------------------------------------------------

def rodas(im: Image.Image, rng: random.Random) -> None:
    # 0 banda de rodagem: a celula e esticada em volta do pneu, entao os sulcos
    # tem de ser verticais para sairem transversais na roda.
    c = Image.new("RGBA", (CELULA, CELULA), (44, 44, 46, 255))
    d = ImageDraw.Draw(c)
    for x in range(0, CELULA, 3):
        d.line((x, 0, x, CELULA), fill=(30, 30, 32, 255))
    d.rectangle((0, 0, CELULA, 2), fill=(58, 58, 60, 255))
    d.rectangle((0, CELULA - 3, CELULA, CELULA), fill=(58, 58, 60, 255))
    colar(im, c, 0, 2)

    # 1 calota: disco com cinco furos. Cinco e o numero que le como roda; quatro
    # le como carrinho de mao.
    c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.ellipse((0, 0, CELULA - 1, CELULA - 1), fill=(168, 170, 172, 255))
    d.ellipse((4, 4, CELULA - 5, CELULA - 5), fill=(140, 142, 144, 255))
    for k in range(5):
        a = math.tau * k / 5.0
        x = CELULA / 2 + math.cos(a) * 8.5
        y = CELULA / 2 + math.sin(a) * 8.5
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(70, 70, 74, 255))
    d.ellipse((13, 13, 18, 18), fill=(200, 202, 204, 255))
    colar(im, c, 1, 2)


# --- linha 3: lampadas ------------------------------------------------------

def lampadas(im: Image.Image) -> None:
    def lente(nucleo: tuple[int, int, int], borda: tuple[int, int, int],
              vertical: bool = False) -> Image.Image:
        c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
        cam = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
        d = ImageDraw.Draw(cam)
        d.rectangle((0, 0, CELULA - 1, CELULA - 1), fill=borda + (255,))
        # Um degrade de dois passos, e nao um liso: e o que faz a lampada ter
        # miolo. Tres passos ja nao se distinguem a 480x270.
        d.rectangle((3, 3, CELULA - 4, CELULA - 4),
                    fill=tuple((a + b) // 2 for a, b in zip(nucleo, borda)) + (255,))
        d.rectangle((7, 7, CELULA - 8, CELULA - 8), fill=nucleo + (255,))
        if vertical:
            for y in range(0, CELULA, 4):
                d.line((0, y, CELULA, y), fill=borda + (140,))
        c.alpha_composite(cam)
        return c

    colar(im, lente((255, 252, 236), (206, 190, 140), True), 0, 3)
    colar(im, lente((255, 96, 74), (150, 30, 24)), 1, 3)
    colar(im, lente((255, 60, 44), (170, 20, 16)), 2, 3)
    colar(im, lente((248, 248, 244), (170, 172, 176)), 3, 3)
    # As tres do semaforo. Ficam no mesmo atlas porque um semaforo e uma lampada
    # e nao vale um arquivo de 256x256 para tres quadrados.
    colar(im, lente((255, 70, 56), (140, 26, 20)), 4, 3)
    colar(im, lente((255, 196, 70), (150, 110, 24)), 5, 3)
    colar(im, lente((96, 255, 128), (24, 130, 50)), 6, 3)


def main() -> int:
    TEXTURAS.mkdir(parents=True, exist_ok=True)
    rng = random.Random(20260906)
    im = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))

    paineis(im, rng)
    vidros(im, rng)
    rodas(im, rng)
    lampadas(im)

    destino = TEXTURAS / "carro_atlas.png"
    im.save(destino)
    print(f"gravado {destino.relative_to(RAIZ)}  {LADO}x{LADO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

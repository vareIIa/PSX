#!/usr/bin/env python3
"""Atlas da bicicleta: tubo, aro com raios, pneu, selim, coroa e o sino.

Por que um atlas so e por que ele e pequeno
-------------------------------------------
A bicicleta e UM objeto no mundo — nao ha frota dela como ha de carro — entao a
tentacao seria dar textura propria a cada peca. Seria um erro pelo lado do
orcamento e pelo lado do desenho: seis materiais distintos num objeto de dois
metros sao seis trocas de estado para uma coisa que o jogador ve inteira de uma
vez so, e a bicicleta pararia de parecer uma peca so de metal pintado.

128x128 em celulas de 32 dao dezesseis celulas. Onze bastam.

Por que os tubos sao quase brancos
----------------------------------
Mesma razao do atlas do carro: o shader multiplica o albedo pela cor de vertice.
A celula do tubo carrega SO o que a cor nao carrega — o brilho no alto do
cilindro e a sombra embaixo, que e o que faz um prisma de quatro lados ler como
cano redondo. A pintura vem do tint.

O aro e o unico recorte
-----------------------
Raio de bicicleta tem meio milimetro. Modelar cada um seriam trinta e seis
quadrilateros por roda, um absurdo contra o teto do ART-BIBLE secao 10. Aqui a
roda inteira e UM quadrilatero com alfa: raios, aro e cubo desenhados na
textura, e o material corta o resto por ALPHA_SCISSOR. A 480x270 um raio tem um
pixel de largura de qualquer jeito — desenhar ou modelar dao a mesma imagem, e
uma delas custa dois triangulos.

    python tools/gerar_bicicleta.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
TEXTURAS = RAIZ / "game" / "assets" / "textures"

CELULA = 32
GRADE = 4
LADO = CELULA * GRADE

VAZIO = (0, 0, 0, 0)


def nova() -> Image.Image:
    return Image.new("RGBA", (CELULA, CELULA), VAZIO)


def colar(im: Image.Image, c: Image.Image, col: int, lin: int) -> None:
    im.paste(c, (col * CELULA, lin * CELULA))


def tubo(claro: tuple, medio: tuple, escuro: tuple, risco: bool = False) -> Image.Image:
    """Cilindro fingido: faixas horizontais do brilho para a sombra.

    A UV do tubo corre com V ao redor da circunferencia, entao a coluna de
    cores vira a curva de luz do cano. E o truque mais barato que existe para
    dar volume a um prisma de quatro lados.
    """
    c = nova()
    d = ImageDraw.Draw(c)
    faixas = [
        (0, 4, medio), (4, 9, claro), (9, 13, (255, 255, 255, 255)),
        (13, 19, claro), (19, 25, medio), (25, 32, escuro),
    ]
    for y0, y1, cor in faixas:
        d.rectangle((0, y0, CELULA - 1, y1 - 1), fill=cor)
    if risco:
        # Risco de uso: a bicicleta nao e nova, e uma lasca na pintura e o que
        # mais rapido tira o ar de modelo de catalogo.
        d.line((7, 20, 13, 21), fill=escuro)
        d.line((22, 6, 26, 6), fill=medio)
    return c


def couro() -> Image.Image:
    c = Image.new("RGBA", (CELULA, CELULA), (210, 206, 200, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 0, CELULA - 1, 6), fill=(244, 242, 238, 255))
    d.rectangle((0, 25, CELULA - 1, CELULA - 1), fill=(158, 154, 148, 255))
    # Costura em volta. Tracejada, senao vira um contorno de adesivo.
    for x in range(2, CELULA - 2, 4):
        d.point((x, 3), fill=(120, 116, 110, 255))
        d.point((x, CELULA - 4), fill=(120, 116, 110, 255))
    return c


def borracha() -> Image.Image:
    """Manopla e pedal. Preta com friso, que e o que se ve de perto."""
    c = Image.new("RGBA", (CELULA, CELULA), (58, 56, 56, 255))
    d = ImageDraw.Draw(c)
    for y in range(0, CELULA, 4):
        d.line((0, y, CELULA - 1, y), fill=(38, 36, 36, 255))
    d.rectangle((0, 8, CELULA - 1, 12), fill=(78, 76, 76, 255))
    return c


def pneu() -> Image.Image:
    """Banda de rodagem. Pneu de bicicleta e estreito e quase liso; o que se ve
    e a linha central e as mordidas da lateral."""
    c = Image.new("RGBA", (CELULA, CELULA), (42, 40, 42, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 13, CELULA - 1, 18), fill=(54, 52, 54, 255))
    for y in range(0, CELULA, 5):
        d.line((2, y, 8, y + 1), fill=(30, 28, 30, 255))
        d.line((CELULA - 9, y, CELULA - 3, y + 1), fill=(30, 28, 30, 255))
    d.line((0, 0, CELULA - 1, 0), fill=(28, 26, 28, 255))
    return c


def aro() -> Image.Image:
    """A roda inteira num quadrilatero: aro, raios e cubo, com o resto vazado.

    Doze raios, e nao trinta e seis. Numa celula de 32 pixels o trigesimo
    sexto raio cai no mesmo pixel do trigesimo quinto e a roda vira um disco
    cinza — que e exatamente o defeito que se quer evitar.
    """
    c = nova()
    d = ImageDraw.Draw(c)
    meio = (CELULA - 1) / 2.0
    r_ext = 15.5
    r_aro = 12.6
    r_int = 10.8
    cromo = (206, 208, 210, 255)
    # De fora para dentro: pneu preto, aro cromado, vazio. O pneu tem de estar
    # AQUI e nao so na cinta de doze lados — de lado, que e como a bicicleta e
    # vista na maior parte do tempo, a cinta some e sobra o desenho.
    d.ellipse((meio - r_ext, meio - r_ext, meio + r_ext, meio + r_ext),
              fill=(46, 44, 46, 255))
    d.ellipse((meio - r_aro, meio - r_aro, meio + r_aro, meio + r_aro), fill=cromo)
    d.ellipse((meio - r_int, meio - r_int, meio + r_int, meio + r_int), fill=VAZIO)
    # Raios. Saem tangentes ao cubo, como numa roda de verdade, e nao radiais:
    # a leve inclinacao e o que da a impressao de teia quando a roda gira.
    for k in range(12):
        a = math.tau * k / 12.0
        ax = meio + math.cos(a + 0.28) * 3.2
        ay = meio + math.sin(a + 0.28) * 3.2
        bx = meio + math.cos(a) * r_aro
        by = meio + math.sin(a) * r_aro
        d.line((ax, ay, bx, by), fill=(176, 178, 182, 255))
    # Cubo.
    d.ellipse((meio - 3.4, meio - 3.4, meio + 3.4, meio + 3.4), fill=(150, 150, 154, 255))
    d.ellipse((meio - 1.4, meio - 1.4, meio + 1.4, meio + 1.4), fill=(96, 96, 100, 255))
    return c


def coroa() -> Image.Image:
    """Coroa dentada. Tambem recortada, pelos vazados entre os bracos."""
    c = nova()
    d = ImageDraw.Draw(c)
    meio = (CELULA - 1) / 2.0
    d.ellipse((meio - 13, meio - 13, meio + 13, meio + 13), fill=(168, 166, 162, 255))
    d.ellipse((meio - 9.5, meio - 9.5, meio + 9.5, meio + 9.5), fill=(138, 136, 132, 255))
    # Vazados entre os bracos da coroa: cinco furos, que e o desenho classico.
    for k in range(5):
        a = math.tau * k / 5.0 + 0.3
        fx = meio + math.cos(a) * 6.4
        fy = meio + math.sin(a) * 6.4
        d.ellipse((fx - 3.0, fy - 3.0, fx + 3.0, fy + 3.0), fill=VAZIO)
    # Dentes.
    for k in range(20):
        a = math.tau * k / 20.0
        dx = meio + math.cos(a) * 14.4
        dy = meio + math.sin(a) * 14.4
        d.point((dx, dy), fill=(196, 194, 190, 255))
    d.ellipse((meio - 2.2, meio - 2.2, meio + 2.2, meio + 2.2), fill=(90, 90, 94, 255))
    return c


def latao() -> Image.Image:
    """A cupula do sino. Latao escovado, com o brilho no alto."""
    c = Image.new("RGBA", (CELULA, CELULA), (176, 138, 58, 255))
    d = ImageDraw.Draw(c)
    d.rectangle((0, 0, CELULA - 1, 5), fill=(236, 206, 128, 255))
    d.rectangle((0, 6, CELULA - 1, 11), fill=(206, 170, 86, 255))
    d.rectangle((0, 24, CELULA - 1, CELULA - 1), fill=(124, 94, 40, 255))
    # Anel gravado, que e o que toda campainha de bicicleta tem no meio.
    d.line((0, 18, CELULA - 1, 18), fill=(120, 90, 36, 255))
    d.line((0, 19, CELULA - 1, 19), fill=(226, 196, 120, 255))
    return c


def corrente() -> Image.Image:
    """Corrente vista de lado. Repete no U, entao os elos correm com o quadro."""
    c = nova()
    d = ImageDraw.Draw(c)
    for x in range(0, CELULA, 4):
        d.rectangle((x, 13, x + 2, 18), fill=(96, 94, 92, 255))
        d.point((x + 3, 15), fill=(140, 138, 134, 255))
        d.point((x + 3, 16), fill=(140, 138, 134, 255))
    return c


def lente(centro: tuple, borda: tuple) -> Image.Image:
    c = Image.new("RGBA", (CELULA, CELULA), borda + (255,))
    d = ImageDraw.Draw(c)
    d.ellipse((3, 3, CELULA - 4, CELULA - 4), fill=centro + (255,))
    d.ellipse((9, 8, 19, 16), fill=tuple(min(255, v + 40) for v in centro) + (255,))
    d.ellipse((0, 0, CELULA - 1, CELULA - 1), outline=(48, 46, 44, 255))
    return c


def main() -> int:
    TEXTURAS.mkdir(parents=True, exist_ok=True)
    im = Image.new("RGBA", (LADO, LADO), VAZIO)

    colar(im, tubo((228, 226, 222, 255), (188, 186, 182, 255),
                   (128, 126, 124, 255), risco=True), 0, 0)
    colar(im, tubo((232, 234, 238, 255), (186, 190, 196, 255),
                   (108, 112, 118, 255)), 1, 0)
    colar(im, couro(), 2, 0)
    colar(im, borracha(), 3, 0)

    colar(im, pneu(), 0, 1)
    colar(im, aro(), 1, 1)
    colar(im, coroa(), 2, 1)
    colar(im, latao(), 3, 1)

    colar(im, lente((248, 246, 232), (86, 84, 80)), 0, 2)
    colar(im, lente((214, 48, 40), (92, 24, 20)), 1, 2)
    colar(im, corrente(), 2, 2)

    destino = TEXTURAS / "bicicleta_atlas.png"
    im.save(destino)
    print(f"gravado {destino.relative_to(RAIZ)}  {LADO}x{LADO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Icones dos itens que o bar vende e o mercado nao: a cerveja e a pinga.

Mesmo jeito dos icones da lanchonete (`gerar_lojas.py`, `_icone`): desenho a
384 px reduzido para 96, sem contorno, luz de cima. So escreve os proprios
arquivos.

    python tools/gerar_itens_do_bar.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
ICONES = RAIZ / "game" / "assets" / "icones"


def _icone(nome, pintar):
    lado = 384
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pintar(d)
    im = im.resize((96, 96), Image.LANCZOS)
    ICONES.mkdir(parents=True, exist_ok=True)
    im.save(ICONES / f"{nome}.png", "PNG", optimize=True)
    print(f"icones/{nome}.png")


def _cerveja(d):
    # A 600 de vidro ambar, com o rotulo branco e vermelho e a tampinha, e o
    # copo americano cheio do lado.
    d.rounded_rectangle((70, 150, 180, 360), 26, fill=(92, 46, 16, 255))
    d.polygon([(76, 170), (174, 170), (148, 96), (102, 96)], fill=(92, 46, 16, 255))
    d.rectangle((104, 36, 146, 100), fill=(92, 46, 16, 255))
    d.rectangle((100, 26, 150, 44), fill=(200, 176, 60, 255))
    d.rectangle((70, 220, 180, 300), fill=(238, 232, 214, 255))
    d.ellipse((96, 236, 154, 284), fill=(196, 40, 34, 255))
    d.rectangle((80, 160, 94, 350), fill=(150, 88, 40, 255))
    # Copo americano: cerveja, espuma e o brilho do vidro.
    d.polygon([(214, 190), (330, 190), (318, 360), (226, 360)], fill=(222, 150, 40, 255))
    d.polygon([(210, 150), (334, 150), (330, 196), (214, 196)], fill=(248, 244, 232, 255))
    d.line([(236, 206), (244, 344)], fill=(250, 214, 120, 255), width=10)
    for x in (240, 270, 300):
        d.ellipse((x, 250, x + 8, 258), fill=(250, 200, 100, 255))


def _pinga(d):
    # A dose no copinho lagoinha e a garrafa de 51 atras.
    d.rounded_rectangle((170, 120, 300, 350), 20, fill=(214, 218, 196, 200))
    d.polygon([(180, 136), (290, 136), (262, 70), (208, 70)], fill=(214, 218, 196, 200))
    d.rectangle((218, 20, 252, 74), fill=(214, 218, 196, 220))
    d.rectangle((214, 12, 256, 30), fill=(40, 90, 150, 255))
    d.rectangle((170, 190, 300, 280), fill=(242, 206, 60, 255))
    d.rectangle((190, 210, 280, 250), fill=(200, 40, 34, 255))
    d.polygon([(60, 230), (180, 230), (168, 360), (72, 360)], fill=(232, 238, 240, 230))
    d.polygon([(70, 280), (172, 280), (166, 356), (76, 356)], fill=(240, 222, 150, 255))
    d.line([(86, 240), (92, 350)], fill=(255, 255, 255, 255), width=8)


def main():
    _icone("cerveja", _cerveja)
    _icone("pinga", _pinga)


if __name__ == "__main__":
    main()

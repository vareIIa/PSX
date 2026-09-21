#!/usr/bin/env python3
"""Tira a cor de uma textura e poe a media num cinza medio.

    python tools/neutralizar_textura.py courino tecido tapete

Couro, tecido e tapete da casa da fumaca sao tingidos por vertice: o shader
multiplica o albedo pela cor da malha. Um couro que vem PRETO do ambientCG nao
vira marrom por multiplicacao, e um veludo que vem vermelho so vira vermelho
mais escuro. Aqui a foto perde a cor e ganha media fixa, e a trama fica: quem
pinta e o movel. Vale para as duas fidelidades (256 px e 1024 px).
"""
import sys
from pathlib import Path
from PIL import Image, ImageOps, ImageStat

RAIZ = Path(__file__).resolve().parent.parent
MEDIA = 0.62
CONTRASTE = 1.25


def neutralizar(caminho: Path) -> None:
    img = Image.open(caminho)
    modo = img.mode
    cinza = ImageOps.grayscale(img.convert("RGB"))
    media = ImageStat.Stat(cinza).mean[0] / 255.0
    def f(v: int) -> int:
        x = (v / 255.0 - media) * CONTRASTE + MEDIA
        return max(0, min(255, round(x * 255)))
    cinza = cinza.point(f)
    saida = Image.merge("RGB", (cinza, cinza, cinza))
    if modo == "P":
        saida = saida.quantize(256)
    saida.save(caminho)
    print(f"  {caminho.relative_to(RAIZ)}  media {media:.2f} -> {MEDIA:.2f}")


def main() -> int:
    for nome in sys.argv[1:]:
        neutralizar(RAIZ / "game/assets/textures" / f"{nome}.png")
        neutralizar(RAIZ / "game/assets/textures_hd" / f"{nome}.jpg")
    return 0


if __name__ == "__main__":
    sys.exit(main())

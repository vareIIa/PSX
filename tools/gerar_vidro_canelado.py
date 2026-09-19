#!/usr/bin/env python3
"""Vidro canelado: o vidro de bandeira e de porta de casa brasileira.

Caneluras verticais que quebram a luz de dentro em faixas. A bandeira magenta
da casa da fumaca usava a textura de ladrilho de calcada, e no MODERNO (onde o
conjunto HD e escolhido pelo nome do arquivo) ela saia como piso aceso.

    python tools/gerar_vidro_canelado.py
"""

import math
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "game" / "assets" / "textures" / "vidro_canelado.png"
LADO = 128
CANELURAS = 16


def main() -> int:
    im = Image.new("RGB", (LADO, LADO))
    px = im.load()
    for x in range(LADO):
        fase = (x / LADO) * CANELURAS
        f = fase - math.floor(fase)
        # Cada canelura e uma lente: clara no meio, escura na aresta.
        v = 0.62 + 0.38 * math.sin(f * math.pi) ** 0.8
        for y in range(LADO):
            ruido = 0.97 + 0.03 * math.sin(y * 0.37 + x * 0.11)
            c = int(255 * max(0.0, min(1.0, v * ruido)))
            px[x, y] = (c, c, c)
    im.save(DESTINO)
    print(f"gravado {DESTINO.relative_to(RAIZ)}  {LADO}x{LADO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

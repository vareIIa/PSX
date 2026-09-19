#!/usr/bin/env python3
"""Textura do tufo de fumaca das particulas (FumacaParticulas).

Um tufo macio e irregular: queda radial suave multiplicada por ruido fractal.
Redondo e liso ele le como bolha de sabao; com o ruido, cada particula girando
mostra um desenho diferente e o fio de fumaca parece se desfazer.

    python tools/gerar_fumaca_puff.py
"""

import math
import random
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "game" / "assets" / "textures" / "fx_fumaca_puff.png"
LADO = 128


def _grade(rng: random.Random, n: int) -> list[list[float]]:
    return [[rng.random() for _ in range(n + 1)] for _ in range(n + 1)]


def _amostra(g: list[list[float]], n: int, x: float, y: float) -> float:
    gx, gy = min(x, 0.9999) * n, min(y, 0.9999) * n
    i, j = int(gx), int(gy)
    fx, fy = gx - i, gy - j
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = g[j][i] * (1 - fx) + g[j][i + 1] * fx
    b = g[j + 1][i] * (1 - fx) + g[j + 1][i + 1] * fx
    return a * (1 - fy) + b * fy


def main() -> int:
    rng = random.Random(4471)
    oitavas = [(4, 0.5), (8, 0.27), (16, 0.15), (32, 0.08)]
    grades = [(_grade(rng, n), n, p) for n, p in oitavas]
    im = Image.new("RGBA", (LADO, LADO))
    px = im.load()
    for y in range(LADO):
        for x in range(LADO):
            u, v = x / (LADO - 1), y / (LADO - 1)
            r = math.hypot(u - 0.5, v - 0.5) * 2.0
            queda = max(0.0, 1.0 - r) ** 1.7
            ruido = sum(_amostra(g, n, u, v) * p for g, n, p in grades)
            a = max(0.0, min(1.0, queda * (0.35 + ruido * 1.1) - 0.04))
            px[x, y] = (255, 255, 255, int(a * 255))
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    im.save(DESTINO)
    print(f"gravado {DESTINO.relative_to(RAIZ)}  {LADO}x{LADO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

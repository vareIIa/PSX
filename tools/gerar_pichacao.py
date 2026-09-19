#!/usr/bin/env python3
"""Pichacao da fachada da casa da fumaca.

Pixo paulistano: letra alta, reta e pontuda, tinta preta de spray, com o
escorrido embaixo de cada traco. Era desenhada com cinco caixas finas e uma
travessa, e na captura do MODERNO lia como uma cerca quebrada flutuando na
parede (captures/fumaca_v2/antes/11).

    python tools/gerar_pichacao.py
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "game" / "assets" / "textures" / "pichacao.png"
LARG, ALT = 512, 256
ESCALA = 2


def letra(d: ImageDraw.ImageDraw, x: float, topo: float, base: float,
          larg: float, rng: random.Random, grossura: int) -> list[tuple[float, float]]:
    """Um glifo de pixo: haste alta e dois ou tres tracos retos. Devolve os pes."""
    pes = []
    meio = (topo + base) * 0.5
    tipo = rng.randrange(5)
    h = [(x, topo - rng.uniform(0, 18)), (x, base)]
    d.line(h, fill=255, width=grossura)
    pes.append((x, base))
    if tipo == 0:      # A pontudo
        d.line([(x, topo), (x + larg, base)], fill=255, width=grossura)
        d.line([(x + larg * 0.2, meio), (x + larg * 0.7, meio)], fill=255, width=grossura)
        pes.append((x + larg, base))
    elif tipo == 1:    # N
        d.line([(x, topo), (x + larg, base)], fill=255, width=grossura)
        d.line([(x + larg, base), (x + larg, topo + 10)], fill=255, width=grossura)
        pes.append((x + larg, base))
    elif tipo == 2:    # E de tres barras
        for y in (topo, meio, base):
            d.line([(x, y), (x + larg * 0.8, y - 6)], fill=255, width=grossura)
    elif tipo == 3:    # R com perna
        d.line([(x, topo), (x + larg, topo + 14), (x, meio)], fill=255, width=grossura)
        d.line([(x, meio), (x + larg, base)], fill=255, width=grossura)
        pes.append((x + larg, base))
    else:              # M alto
        d.line([(x, topo), (x + larg * 0.5, meio), (x + larg, topo)], fill=255, width=grossura)
        d.line([(x + larg, topo), (x + larg, base)], fill=255, width=grossura)
        pes.append((x + larg, base))
    return pes


def main() -> int:
    rng = random.Random(5512)
    W, H = LARG * ESCALA, ALT * ESCALA
    alfa = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(alfa)
    grossura = 11 * ESCALA
    x = 26.0 * ESCALA
    pes: list[tuple[float, float]] = []
    for _ in range(6):
        larg = rng.uniform(30, 46) * ESCALA
        topo = rng.uniform(26, 44) * ESCALA
        base = rng.uniform(176, 190) * ESCALA
        pes += letra(d, x, topo, base, larg, rng, grossura)
        x += larg + rng.uniform(16, 26) * ESCALA
    # O sublinhado torto que assina a pixacao.
    d.line([(24 * ESCALA, 206 * ESCALA), (x - 10 * ESCALA, 198 * ESCALA)],
           fill=255, width=7 * ESCALA)
    # Escorrido: tinta acumulada no pe de cada traco descendo a parede.
    for px, py in pes:
        if rng.random() < 0.75:
            comp = rng.uniform(12, 48) * ESCALA
            dx = px + rng.uniform(-4, 4) * ESCALA
            d.line([(dx, py), (dx, py + comp)], fill=255, width=3 * ESCALA)
            d.ellipse((dx - 3 * ESCALA, py + comp - 2 * ESCALA,
                       dx + 3 * ESCALA, py + comp + 4 * ESCALA), fill=255)
    # Borda de spray: um pouco de nevoa, depois recortada pelo material.
    alfa = alfa.filter(ImageFilter.GaussianBlur(1.6 * ESCALA))
    alfa = alfa.resize((LARG, ALT), Image.LANCZOS)
    im = Image.new("RGBA", (LARG, ALT), (22, 20, 24, 0))
    im.putalpha(alfa)
    # Tinta nao e preto chapado: fica mais rala onde o spray passou rapido.
    px = im.load()
    for yy in range(ALT):
        for xx in range(LARG):
            r, g, b, a = px[xx, yy]
            if a:
                v = rng.randint(14, 34)
                px[xx, yy] = (v, v - 2, v + 3, a)
    im.save(DESTINO)
    print(f"gravado {DESTINO.relative_to(RAIZ)}  {LARG}x{ALT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Gera as texturas placeholder da sala de teste da Fase 1.

Tudo dentro da spec do ART-BIBLE secao 6: 128 px, tileable, 256 cores com dither.
Sao placeholders honestos, nao arte final: existem para provar que o shader esta
certo, e vao ser trocados quando houver textura de verdade.

    python tools/gen_texturas_base.py -o game/assets/textures
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 128
RNG = np.random.default_rng(1995)


def fbm(shape: tuple[int, int], octaves: int = 5, persist: float = 0.55) -> np.ndarray:
    """Ruido fractal tileable por soma de ruidos em resolucoes que dividem o lado."""
    out = np.zeros(shape, dtype=np.float64)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        res = 2 ** (o + 1)
        if res > shape[0]:
            break
        low = RNG.random((res, res))
        # np.tile antes do resize garante que a borda fecha
        img = Image.fromarray((low * 255).astype(np.uint8)).resize(shape, Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255.0 * amp
        total += amp
        amp *= persist
    return out / max(total, 1e-6)


def norm(a: np.ndarray) -> np.ndarray:
    lo, hi = a.min(), a.max()
    return (a - lo) / max(hi - lo, 1e-6)


def tint(mask: np.ndarray, dark: str, light: str) -> np.ndarray:
    """Mapeia uma mascara 0..1 para uma rampa entre duas cores hex."""
    d = np.array([int(dark.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    l = np.array([int(light.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    m = mask[..., None]
    return d * (1.0 - m) + l * m


def concreto() -> np.ndarray:
    """Parede de concreto encardido, com manchas verticais de umidade."""
    base = norm(fbm((SIZE, SIZE), octaves=6))
    escorrido = norm(fbm((SIZE, SIZE), octaves=3))
    escorrido = np.minimum.accumulate(escorrido, axis=0)  # escorre para baixo
    m = np.clip(base * 0.72 + escorrido * 0.28, 0, 1)
    m = m * 0.55 + 0.30
    return tint(m, "#3a3a33", "#9d9a8b")


def piso_madeira() -> np.ndarray:
    """Tabua corrida horizontal com veio e juntas escuras."""
    y = np.arange(SIZE)[:, None].repeat(SIZE, 1)
    x = np.arange(SIZE)[None, :].repeat(SIZE, 0)

    altura = 16
    tabua = y // altura
    junta = ((y % altura) < 1).astype(np.float64)

    # deslocamento por tabua, para as pontas nao alinharem
    desloc = (tabua * 37) % SIZE
    veio = norm(fbm((SIZE, SIZE), octaves=5))
    veio = np.take_along_axis(veio, ((x + desloc) % SIZE).astype(np.intp), axis=1)

    variacao = ((tabua * 53) % 7) / 7.0 * 0.16
    m = np.clip(0.42 + veio * 0.34 + variacao - junta * 0.34, 0, 1)
    return tint(m, "#2b1d12", "#9c6f42")


def reboco() -> np.ndarray:
    """Teto de reboco claro, quase liso."""
    m = np.clip(0.62 + norm(fbm((SIZE, SIZE), octaves=6)) * 0.22, 0, 1)
    return tint(m, "#585449", "#b8b3a1")


def tabua() -> np.ndarray:
    """Tabua bruta usada para tapar a porta."""
    veio = norm(fbm((SIZE, SIZE), octaves=6))
    listra = np.sin(np.arange(SIZE)[:, None] * 0.55) * 0.06
    m = np.clip(0.34 + veio * 0.40 + listra, 0, 1)
    return tint(m, "#241708", "#8a5f31")


def porta() -> np.ndarray:
    """Porta de madeira com almofada, desenhada como retangulos chapados."""
    m = np.full((SIZE, SIZE), 0.58)
    m += norm(fbm((SIZE, SIZE), octaves=5)) * 0.16

    def painel(y0: int, y1: int, x0: int, x1: int) -> None:
        m[y0:y1, x0:x1] -= 0.16
        m[y0 + 3:y1 - 3, x0 + 3:x1 - 3] += 0.20

    painel(12, 58, 18, 110)
    painel(70, 116, 18, 110)
    m = np.clip(m, 0, 1)
    return tint(m, "#33241a", "#b09268")


def metal() -> np.ndarray:
    """Luminaria e detalhe metalico."""
    m = np.clip(0.40 + norm(fbm((SIZE, SIZE), octaves=4)) * 0.30, 0, 1)
    return tint(m, "#1d1f1e", "#787f78")


TEXTURAS = {
    "concreto_parede": concreto,
    "piso_madeira": piso_madeira,
    "teto_reboco": reboco,
    "tabua": tabua,
    "porta": porta,
    "metal": metal,
}


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera texturas placeholder na spec PSX.")
    ap.add_argument("-o", "--saida", type=Path, default=Path("game/assets/textures"))
    ap.add_argument("--colors", type=int, default=256)
    args = ap.parse_args()
    args.saida.mkdir(parents=True, exist_ok=True)

    for nome, fn in TEXTURAS.items():
        arr = np.clip(fn(), 0, 255).astype(np.uint8)
        img = Image.fromarray(arr, "RGB").quantize(
            colors=args.colors, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG
        )
        destino = args.saida / f"{nome}.png"
        img.save(destino, "PNG", optimize=True)
        print(f"{destino}  {SIZE}x{SIZE}  {args.colors} cores")

    print(f"\n{len(TEXTURAS)} texturas geradas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

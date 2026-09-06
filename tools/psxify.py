#!/usr/bin/env python3
"""Converte imagens para a especificacao de textura do ART-BIBLE (secao 6).

Reduz para no maximo 128 px, quantiza para 256 cores com dither Floyd-Steinberg
e grava PNG sem perda. Aceita arquivo unico ou pasta inteira.

    python tools/psxify.py foto.jpg -o game/assets/textures/parede.png
    python tools/psxify.py refs/ -o game/assets/textures/ --size 128 --colors 256
    python tools/psxify.py refs/ -o out/ --tileable
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow nao encontrado. Rode: python -m pip install Pillow")

EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".webp", ".tga", ".tif", ".tiff"}


def make_tileable(img: Image.Image, blend: float = 0.12) -> Image.Image:
    """Espelha e mistura as bordas para a textura fechar em tiling."""
    w, h = img.size
    bw, bh = max(1, int(w * blend)), max(1, int(h * blend))

    out = img.copy()
    # borda esquerda recebe a direita espelhada, com alpha em rampa
    left = img.crop((w - bw, 0, w, h)).transpose(Image.FLIP_LEFT_RIGHT)
    mask = Image.linear_gradient("L").rotate(270, expand=True).resize((bw, h))
    out.paste(left, (0, 0), mask)

    top = out.crop((0, h - bh, w, h)).transpose(Image.FLIP_TOP_BOTTOM)
    mask = Image.linear_gradient("L").resize((w, bh))
    out.paste(top, (0, 0), mask)
    return out


def psxify(src: Path, dst: Path, size: int, colors: int, tileable: bool) -> str:
    img = Image.open(src).convert("RGB")
    before = f"{img.width}x{img.height}"

    if tileable:
        img = make_tileable(img)

    # Reduz para potencia de dois nao maior que `size`, preservando o lado maior.
    longest = max(img.size)
    if longest > size:
        scale = size / longest
        new = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
        # BOX preserva o pixel duro melhor que LANCZOS nessa escala
        img = img.resize(new, Image.BOX)

    # Quantizacao com dither Floyd-Steinberg, que e o que produz o granulado
    # caracteristico das texturas de PS1.
    img = img.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG)

    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG", optimize=True)
    return f"{src.name}: {before} -> {img.width}x{img.height}, {colors} cores"


def main() -> int:
    ap = argparse.ArgumentParser(description="Converte imagens para a spec de textura PSX.")
    ap.add_argument("entrada", type=Path, help="arquivo ou pasta de origem")
    ap.add_argument("-o", "--saida", type=Path, required=True, help="arquivo ou pasta de destino")
    ap.add_argument("--size", type=int, default=128, help="lado maior em pixels (padrao 128)")
    ap.add_argument("--colors", type=int, default=256, help="cores na paleta (padrao 256)")
    ap.add_argument("--tileable", action="store_true", help="espelha as bordas para fechar em tiling")
    args = ap.parse_args()

    if not args.entrada.exists():
        return print(f"erro: {args.entrada} nao existe") or 1

    if args.entrada.is_file():
        dst = args.saida
        if dst.is_dir() or not dst.suffix:
            dst = dst / (args.entrada.stem + ".png")
        print(psxify(args.entrada, dst, args.size, args.colors, args.tileable))
        return 0

    fontes = sorted(p for p in args.entrada.rglob("*") if p.suffix.lower() in EXTS)
    if not fontes:
        return print(f"erro: nenhuma imagem em {args.entrada}") or 1

    for src in fontes:
        rel = src.relative_to(args.entrada).with_suffix(".png")
        print(psxify(src, args.saida / rel, args.size, args.colors, args.tileable))
    print(f"\n{len(fontes)} imagens convertidas para {args.saida}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Monta a folha de comparacao entre as capturas e as prints de referencia.

E o artefato de aceite visual da Fase 1: se as colunas nao baterem em dither,
queda de luz e distorcao de textura, o contrato grafico nao fechou.

    python tools/montar_comparacao.py

Depende das capturas em captures/, geradas por:
    ./dev.sh shot off ; ./dev.sh shot denso
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

LARGURA = 480
PAD, GAP, TOPO = 16, 12, 26
FUNDO = (16, 20, 18)
TEXTO = (206, 194, 162)

RAIZ = Path(__file__).resolve().parent.parent
CAPS = RAIZ / "captures"
REFS = RAIZ / "PRINTS"


def escala(caminho: Path, largura: int = LARGURA) -> Image.Image:
    im = Image.open(caminho).convert("RGB")
    return im.resize((largura, round(im.height * largura / im.width)), Image.LANCZOS)


def recorte(caminho: Path, box: tuple[int, int, int, int], fator: int = 4) -> Image.Image:
    """Recorte ampliado com nearest, para o pixel e o dither ficarem legiveis."""
    im = Image.open(caminho).convert("RGB").crop(box)
    return im.resize((im.width * fator, im.height * fator), Image.NEAREST)


def main() -> int:
    faltando = [
        p for p in (
            CAPS / "fase1_off.png", CAPS / "fase1_denso.png",
            CAPS / "fase1_sem_pos.png", CAPS / "ab_liso.png",
        ) if not p.exists()
    ]
    if faltando:
        print("capturas ausentes:", ", ".join(p.name for p in faltando))
        print("rode: ./dev.sh shot off  e  ./dev.sh shot denso")
        return 1

    linhas = [
        ("REFERENCIA  corredor de concreto", escala(REFS / "1_uPwt5ZFRdmAcPbF_OlEXLA.webp"),
         "NOSSO  Fase 1, preset off", escala(CAPS / "fase1_off.png")),
        ("REFERENCIA  nevoa densa", escala(REFS / "1_uK7r0x3HpJmSVeUa2c60lg.webp"),
         "NOSSO  Fase 1, preset denso", escala(CAPS / "fase1_denso.png")),
        ("ZOOM 4x  COM snap + UV afim", recorte(CAPS / "fase1_sem_pos.png", (150, 120, 270, 190)),
         "ZOOM 4x  SEM snap + UV afim", recorte(CAPS / "ab_liso.png", (150, 120, 270, 190))),
        ("ZOOM 4x  dither, 32 niveis por canal", recorte(CAPS / "fase1_sem_pos.png", (60, 30, 180, 100)),
         "ZOOM 4x  chao, textura nadando", recorte(CAPS / "fase1_off.png", (170, 180, 290, 250))),
    ]

    total_w = PAD * 2 + LARGURA * 2 + GAP
    total_h = PAD + sum(TOPO + max(a.height, b.height) + GAP for _, a, _, b in linhas) + PAD

    folha = Image.new("RGB", (total_w, total_h), FUNDO)
    desenho = ImageDraw.Draw(folha)

    y = PAD
    for rot_esq, esq, rot_dir, dir_ in linhas:
        desenho.text((PAD, y), rot_esq, fill=TEXTO)
        desenho.text((PAD + LARGURA + GAP, y), rot_dir, fill=TEXTO)
        folha.paste(esq, (PAD, y + TOPO - 4))
        folha.paste(dir_, (PAD + LARGURA + GAP, y + TOPO - 4))
        y += TOPO + max(esq.height, dir_.height) + GAP

    destino = CAPS / "COMPARACAO_FASE1.png"
    folha.save(destino)
    print(f"{destino.relative_to(RAIZ)}  {folha.width}x{folha.height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

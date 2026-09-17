#!/usr/bin/env python3
"""Escada de valor de um comodo: quanto piso, parede e teto diferem em luminancia.

Por que isto e uma ferramenta e nao um olho
-------------------------------------------
"A sala esta chapada" e uma frase. O que conserta e um numero, e o numero e a
distancia de LUMINANCIA entre as tres superficies grandes do comodo. Um quarto
em que o piso e o teto tem o mesmo valor nao tem leitura vertical nenhuma: a
camera gira e nada muda de tom, e o resultado e a massa marrom uniforme que
todas as capturas da casa da fumaca tinham antes da Fase 3.

A conta e a que o shader faz: media da textura x `tint` do material x tint de
VERTICE que o construtor passa. Os tres se multiplicam em `psx_surface`
(ALBEDO = texel.rgb * COLOR.rgb, com texel ja incluindo o tint do material), e
e por isso que da para escurecer o teto de um comodo so sem tocar no
`mat_teto.tres`, que e compartilhado com a casa comum, o mercado e o bar.

    python tools/medir_valor.py
"""

import re
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
TEXTURAS = RAIZ / "game" / "assets" / "textures"
MATERIAIS = RAIZ / "game" / "resources" / "materials"

# Comodo -> (arquivo do construtor, [(rotulo, material, constante do tint)]).
# O tint de vertice vem do PROPRIO codigo do construtor, e nao de uma copia
# aqui: se alguem mexer na constante, esta medida acompanha.
COMODOS = {
    "casa_fumaca": (
        "game/src/world/casa_fumaca_builder.gd",
        [("teto", "teto", "TETO_TINTA"),
         ("piso", "piso", "PISO_TINTA"),
         ("parede", "reboco", "CORES_PAREDE")],
    ),
}


def luminancia(c) -> float:
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def media_da_textura(nome: str):
    im = Image.open(TEXTURAS / f"{nome}.png").convert("RGB")
    px = list(im.getdata())
    n = len(px)
    return tuple(sum(p[i] for p in px) / n for i in range(3))


def do_material(nome: str):
    """Textura media ja multiplicada pelo `tint` do .tres."""
    txt = (MATERIAIS / f"mat_{nome}.tres").read_text(encoding="utf-8")
    tex = re.search(r"textures/([a-z_0-9]+)\.png", txt).group(1)
    tint = [float(v) for v in
            re.search(r"tint = Color\(([^)]+)\)", txt).group(1).split(",")][:3]
    base = media_da_textura(tex)
    return tuple(base[i] * tint[i] for i in range(3)), tex


def tints_do_codigo(fonte: str, constante: str):
    """Todos os Color() de uma constante do construtor. Lista porque a cor da
    parede e sorteada entre tres."""
    txt = (RAIZ / fonte).read_text(encoding="utf-8")
    linha = re.search(r"const %s := Color\(([^)]+)\)" % constante, txt)
    if linha:
        v = [float(x) for x in linha.group(1).split(",")][:3]
        return [(constante, tuple(v))]
    # `Array[Color]` tem um colchete no meio da declaracao, entao a busca
    # ancora no `= [` e fecha no `]` que comeca a linha.
    bloco = re.search(r"const %s.*?= \[(.*?)^\]" % constante, txt, re.S | re.M)
    if not bloco:
        return [("sem tint", (1.0, 1.0, 1.0))]
    saida = []
    for h in re.findall(r'Color\("([0-9a-f]{6})"\)', bloco.group(1)):
        saida.append((h, tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))))
    return saida


def main() -> int:
    for comodo, (fonte, camadas) in COMODOS.items():
        print(f"--- {comodo} ---")
        valores = []
        for rotulo, material, constante in camadas:
            base, tex = do_material(material)
            for nome_tint, tint in tints_do_codigo(fonte, constante):
                cor = tuple(base[i] * tint[i] for i in range(3))
                lum = luminancia(cor)
                valores.append(lum)
                print(f"  {rotulo:8s} {lum:6.1f}   mat_{material} ({tex})"
                      f" x {nome_tint}")
        if valores:
            amplitude = max(valores) - min(valores)
            print(f"  amplitude: {amplitude:.0f} pontos de 255")
            # Abaixo disto o comodo nao tem leitura vertical: girar a camera nao
            # troca o tom de nada. Foi o estado da casa da fumaca por seis meses.
            if amplitude < 60.0:
                print("  ATENCAO: amplitude baixa, o comodo le chapado")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

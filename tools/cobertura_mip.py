#!/usr/bin/env python3
"""Tabela de cobertura por mip das texturas de folha (PLANO_FLORA_AAA, rodada 3).

    python tools/cobertura_mip.py            reescreve game/src/world/cobertura_folha.gd
    python tools/cobertura_mip.py --mostrar  so imprime

O defeito
---------
Folha recortada por alfa AFINA e FURA de longe. O mipmap faz a media do alfa: um
capim de 3 texels de largura, no nivel 3, e uma nevoa de alfa 0,2 que nao passa
do limiar 0,45, e a moita inteira some; a copa vira lasca com buraco. O
`psx_folha_pixel` compensava com uma reta (`alfa_por_mip` 0,22 por nivel) e com
o limiar afrouxando de longe; a reta e a mesma para a copa densa (que engordava)
e para a lamina fina (que ainda sumia).

O conserto (Castano, "Computing Alpha Mipmaps", 2010; Golus, "Anti-aliased
Alpha Test", 2017): para cada nivel de mip, a escala do alfa que devolve a MESMA
fracao de texels acima do limiar que o nivel 0 tem. A conta e feita aqui, sobre a
mesma cadeia de medias 2x2 que a placa faz, por CELULA do atlas (a lamina de
capim e a copa densa pedem escalas diferentes), e o shader le a tabela.

O Godot gera os mips sozinho (nao da para gravar o mip ja corrigido na textura),
por isso a correcao mora no shader, e a tabela num .gd gerado.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
HD = RAIZ / "game" / "assets" / "textures_hd"
SAIDA = RAIZ / "game" / "src" / "world" / "cobertura_folha.gd"

NIVEIS = 12
# textura -> (colunas, linhas, limiar do material)
TEXTURAS = {
    "vegetacao_atlas": (4, 4, 0.5),
    "plantas_atlas": (4, 4, 0.5),
    "mato_atlas": (8, 8, 0.42),
    "flores": (8, 8, 0.45),
    "folhagem_recorte": (1, 1, 0.45),
}
MAX_ESCALA = 6.0


def cadeia(a: np.ndarray) -> list[np.ndarray]:
    niveis = [a]
    while min(niveis[-1].shape) > 1 and len(niveis) < NIVEIS:
        v = niveis[-1]
        h, w = v.shape[0] // 2, v.shape[1] // 2
        niveis.append(v[:h * 2, :w * 2].reshape(h, 2, w, 2).mean(axis=(1, 3)))
    return niveis


def escala_para(alfa: np.ndarray, cobertura: float, limiar: float) -> float:
    """A escala s tal que a fracao de alfa*s >= limiar seja `cobertura`."""
    if cobertura <= 0.0 or alfa.size == 0:
        return 1.0
    q = float(np.quantile(alfa, max(0.0, 1.0 - cobertura)))
    if q <= 1e-4:
        return MAX_ESCALA
    return float(np.clip(limiar / q, 1.0, MAX_ESCALA))


def tabela(nome: str, colunas: int, linhas: int, limiar: float) -> list[float]:
    img = Image.open(HD / f"{nome}.png").convert("RGBA")
    a = np.asarray(img, np.float32)[..., 3] / 255.0
    niveis = cadeia(a)
    fora = []
    for cy in range(linhas):
        for cx in range(colunas):
            h0 = a.shape[0] // linhas
            w0 = a.shape[1] // colunas
            cel0 = a[cy * h0:(cy + 1) * h0, cx * w0:(cx + 1) * w0]
            cob = float((cel0 >= limiar).mean())
            linha = []
            for k in range(NIVEIS):
                if k >= len(niveis):
                    linha.append(linha[-1])
                    continue
                v = niveis[k]
                h = v.shape[0] // linhas
                w = v.shape[1] // colunas
                if h < 1 or w < 1:
                    linha.append(linha[-1] if linha else 1.0)
                    continue
                cel = v[cy * h:(cy + 1) * h, cx * w:(cx + 1) * w]
                linha.append(1.0 if k == 0 else escala_para(cel, cob, limiar))
            # Nunca menor que o nivel anterior: a escala so cresce com a distancia
            # (senao a copa pulsa ao se afastar).
            for k in range(1, NIVEIS):
                linha[k] = max(linha[k], linha[k - 1])
            fora.extend(linha)
    return fora


def main() -> int:
    mostrar = "--mostrar" in sys.argv
    linhas_gd = []
    for nome, (c, l, lim) in TEXTURAS.items():
        if not (HD / f"{nome}.png").exists():
            print("sem", nome)
            continue
        t = tabela(nome, c, l, lim)
        print(f"{nome}: {c}x{l} limiar {lim}")
        for i in range(c * l):
            fila = t[i * NIVEIS:(i + 1) * NIVEIS]
            print("   cel %2d  " % i + " ".join("%.2f" % x for x in fila))
        numeros = ", ".join("%.3f" % x for x in t)
        linhas_gd.append(f'\t&"{nome}": [Vector2i({c}, {l}), [{numeros}]],')
    if mostrar:
        return 0
    texto = (
        "## GERADO por tools/cobertura_mip.py: nao edite a mao.\n"
        "##\n"
        "## Escala do alfa por nivel de mip e por celula de atlas, que devolve a\n"
        "## cobertura do nivel 0 (a folha recortada nao afina nem fura de longe).\n"
        "## Quem le e `Vegetacao.ajustar_folha` (uniforms `cobertura_mip` e\n"
        "## `cobertura_grade` do psx_folha_pixel). Rode o script de novo sempre\n"
        "## que um atlas de folha mudar.\n"
        "class_name CoberturaFolha\n"
        "extends RefCounted\n\n"
        f"const NIVEIS := {NIVEIS}\n\n"
        "## textura HD -> [grade (colunas, linhas), escala por celula e nivel]\n"
        "const TABELA := {\n" + "\n".join(linhas_gd) + "\n}\n"
    )
    SAIDA.write_text(texto, encoding="utf-8", newline="\n")
    print("gravado", SAIDA)
    return 0


if __name__ == "__main__":
    sys.exit(main())

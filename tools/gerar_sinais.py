#!/usr/bin/env python3
"""Texturas da sinalizacao de cruzamento: tinta de via e icone de pedestre.

Tres arquivos, todos dentro da spec do ART-BIBLE secao 6 (<=256 px, paleta
curta, sem filtro):

    marca_via     tinta branca gasta da pista — faixa de pedestre, eixo,
                  linha de retencao. NAO e uma linha desenhada: e a superficie
                  da tinta, e a geometria fina do ChunkBuilder recorta o
                  formato. Por isso ela tem sujeira e falha, senao a faixa sai
                  como um retangulo de plastico novo.
    sinal_anda    bonequinho andando, recorte por alfa sobre transparente.
    sinal_para    bonequinho parado, de pe, mesma grade.

O icone e 16x16 uteis: no tamanho em que ele aparece na tela nao cabe desenho,
cabe silhueta. Uma figura anda, a outra fica de pe com os bracos ao corpo, e a
diferenca se le a um relance mesmo na nevoa.

    python tools/gerar_sinais.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "textures"
RNG = np.random.default_rng(2087)


def marca_via() -> None:
    """128 px de tinta branca suja, tileavel."""
    lado = 128
    base = RNG.random((lado // 8, lado // 8))
    grao = np.asarray(
        Image.fromarray((base * 255).astype(np.uint8)).resize((lado, lado), Image.BICUBIC),
        dtype=np.float64,
    ) / 255.0
    # Branco encardido: nem o branco do papel, nem cinza de asfalto. A tinta de
    # rua velha vive perto de 0.72 de valor, e o grao tira 0.15 disso em manchas.
    v = 0.78 - grao * 0.16
    # Falhas onde o pneu comeu a tinta: buracos escuros esparsos.
    falha = RNG.random((lado, lado))
    v = np.where(falha > 0.93, v * 0.45, v)
    px = (np.clip(v, 0.0, 1.0) * 255).astype(np.uint8)
    im = Image.fromarray(np.stack([px, px, px], axis=-1), "RGB")
    im.quantize(colors=16, method=Image.FASTOCTREE).save(SAIDA / "marca_via.png")
    print("marca_via        128x128")


# Cada figura e uma lista de linhas de 16 caracteres. '#' pinta, ' ' deixa vazar.
ANDA = [
    "                ",
    "        ###     ",
    "        ###     ",
    "       #####    ",
    "      #####     ",
    "   #######      ",
    "  ##  ####      ",
    "      #####     ",
    "      ## ###    ",
    "     ##   ##    ",
    "     ##    ##   ",
    "    ##     ##   ",
    "   ##      ###  ",
    "  ###       ##  ",
    " ###           ",
    "                ",
]

PARA = [
    "                ",
    "      ####      ",
    "      ####      ",
    "     ######     ",
    "    ########    ",
    "   ## #### ##   ",
    "   ## #### ##   ",
    "   ## #### ##   ",
    "      ####      ",
    "      ####      ",
    "     ##  ##     ",
    "     ##  ##     ",
    "     ##  ##     ",
    "    ###  ###    ",
    "    ###  ###    ",
    "                ",
]


def _figura(linhas: list[str], nome: str) -> None:
    lado = 16
    px = np.zeros((lado, lado, 4), dtype=np.uint8)
    for y, linha in enumerate(linhas):
        for x, c in enumerate(linha):
            if c == "#":
                px[y, x] = (236, 236, 232, 255)
    Image.fromarray(px, "RGBA").save(SAIDA / f"{nome}.png")
    print(f"{nome:16s} 16x16")


def main() -> int:
    SAIDA.mkdir(parents=True, exist_ok=True)
    marca_via()
    _figura(ANDA, "sinal_anda")
    _figura(PARA, "sinal_para")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

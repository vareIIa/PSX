#!/usr/bin/env python3
"""Monta o conjunto PBR do preset MODERNO (PLANO_AAA_4K, Fase 3).

    python tools/texturas_hd.py                 as superficies da lista
    python tools/texturas_hd.py asfalto tijolo  so as pedidas
    python tools/texturas_hd.py --todas         todo o catalogo do ambientCG

De onde vem
-----------
Do MESMO zip do ambientCG que `baixar_texturas.py` ja guardou em
`.tools/cache_texturas` — ele usa so o mapa de cor e joga fora o resto. Aqui o
resto e aproveitado: normal, rugosidade e oclusao de ambiente. Sem rede, sem
segunda fonte, e o PS1 continua saindo da mesma foto, pela reducao que sempre
fez. Uma fonte, duas fidelidades (secao 4.1 do plano).

O que sai, e por que so tres arquivos
-------------------------------------
    <nome>.jpg      cor, 1024 px, como a foto e — sem o ganho de contraste que
                    a versao PS1 leva para sobreviver a quantizacao
    <nome>_n.jpg    normal (NormalGL: +Y para cima, que e a convencao do Godot)
    <nome>_ru.png   R = rugosidade, G = oclusao de ambiente

Rugosidade e oclusao viajam juntas num arquivo porque sao mapas de um canal cada
e uma textura de tres canais custa o mesmo que uma de um. PNG nesse, e nao JPG,
porque o bloco do JPG num mapa de rugosidade vira mancha de brilho.

Por que 1024 e nao 2048
-----------------------
Medido por `tests/medir_texel.gd`: a 1024 px, TODA superficie da cidade passa do
alvo de 512 px/m do criterio A8 — o asfalto sai em 512, a parede suja em 757, o
metal em 818. A 2048 seria o dobro disso e o quadruplo de VRAM, para detalhe que
a rua nao tem como mostrar. O cache ja esta em 1K; se um dia 2K fizer falta, e
so baixar o zip 2K e rodar isto de novo.
"""

import argparse
import io
import re
import sys
import zipfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from baixar_texturas import CACHE, CATALOGO  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "game" / "assets" / "textures_hd"
LADO = 1024

## As superficies que o conjunto HD cobre por enquanto.
##
## Nao e o catalogo inteiro de proposito: estas seis respondem por quase toda a
## area visivel da cidade — `tests/medir_texel.gd` mede 5.232 m2 de parede suja,
## 1.778 de terra, 831 de asfalto, 469 de calcada, 331 de metal e 170 de metal
## ondulado. O resto entra quando tiver medida que justifique o peso no git.
PADRAO = [
    "concreto_sujo",
    "terra",
    "asfalto",
    "calcada",
    "tijolo",
    "metal_ondulado",
]

MAPAS = {
    "cor": r"_Color\.(jpg|jpeg|png)$",
    "normal": r"_NormalGL\.(jpg|jpeg|png)$",
    "rugosidade": r"_Roughness\.(jpg|jpeg|png)$",
    "oclusao": r"_AmbientOcclusion\.(jpg|jpeg|png)$",
}


def do_zip(z: zipfile.ZipFile, padrao: str):
    """O primeiro arquivo do zip que casa com o padrao, ja aberto."""
    for nome in z.namelist():
        if re.search(padrao, nome, re.I):
            return Image.open(io.BytesIO(z.read(nome)))
    return None


def montar(nome: str, asset: str) -> bool:
    zips = sorted(CACHE.glob(f"{asset}_*.zip"))
    if not zips:
        print(f"  {nome}: sem zip em cache para {asset} "
              f"(rode tools/baixar_texturas.py {nome})")
        return False
    with zipfile.ZipFile(zips[0]) as z:
        cor = do_zip(z, MAPAS["cor"])
        normal = do_zip(z, MAPAS["normal"])
        rug = do_zip(z, MAPAS["rugosidade"])
        ocl = do_zip(z, MAPAS["oclusao"])
    if cor is None:
        print(f"  {nome}: zip sem mapa de cor")
        return False

    DESTINO.mkdir(parents=True, exist_ok=True)
    cor = cor.convert("RGB").resize((LADO, LADO), Image.LANCZOS)
    cor.save(DESTINO / f"{nome}.jpg", quality=92, subsampling=0)

    if normal is not None:
        normal = normal.convert("RGB").resize((LADO, LADO), Image.LANCZOS)
        normal.save(DESTINO / f"{nome}_n.jpg", quality=95, subsampling=0)

    # Rugosidade no vermelho, oclusao no verde. Sem um deles, o canal vai
    # neutro: rugosidade 1 (fosco) e oclusao 1 (sem sombra de contato).
    if rug is not None or ocl is not None:
        r = (rug.convert("L").resize((LADO, LADO), Image.LANCZOS) if rug
             else Image.new("L", (LADO, LADO), 255))
        g = (ocl.convert("L").resize((LADO, LADO), Image.LANCZOS) if ocl
             else Image.new("L", (LADO, LADO), 255))
        b = Image.new("L", (LADO, LADO), 0)
        Image.merge("RGB", (r, g, b)).save(DESTINO / f"{nome}_ru.png")

    achados = [k for k, v in (("cor", cor), ("normal", normal),
                              ("rugosidade", rug), ("oclusao", ocl)) if v]
    print(f"  {nome}: {LADO} px, {', '.join(achados)}")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("nomes", nargs="*")
    ap.add_argument("--todas", action="store_true")
    args = ap.parse_args()

    nomes = args.nomes or (list(CATALOGO) if args.todas else PADRAO)
    print(f"conjunto HD em {DESTINO.relative_to(RAIZ)}")
    feitos = 0
    for nome in nomes:
        if nome not in CATALOGO:
            print(f"  {nome}: nao esta no catalogo do ambientCG")
            continue
        if montar(nome, CATALOGO[nome][0]):
            feitos += 1
    print(f"{feitos} de {len(nomes)} superficies")
    print("Agora: godot --headless --path game --import  e depois "
          "python tools/importar_hd.py (mipmap, compressao de VRAM)")
    return 0 if feitos else 1


if __name__ == "__main__":
    sys.exit(main())

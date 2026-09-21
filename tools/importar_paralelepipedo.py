#!/usr/bin/env python3
"""Paralelepipedo: a rua de pedra da cidade do interior.

    python tools/importar_paralelepipedo.py          baixa, reduz e monta o HD
    godot --headless --path game --import            (depois)
    python tools/importar_paralelepipedo.py --hd     so ajusta o .import do HD

Por que um script proprio
-------------------------
Mesma fonte e mesmo caminho do resto da cidade — ambientCG, CC0 —, e mesmas
funcoes: `baixar_texturas.psxificar` faz a versao do PS1 e
`texturas_hd.montar` o conjunto de 1024 px do MODERNO. So nao entra no
CATALOGO daqueles scripts, porque o catalogo e a lista que eles rodam inteira, e
este material nasceu junto com o Tracado da cidade (rua de pedra em bairro de
casas), e nao com o pacote de texturas.

O asset
-------
PavingStones119: blocos retangulares de granito em fiadas, com capim nas juntas.
E o paralelepipedo de rua de Minas — nao a pedra portuguesa em leque (essa e
calcada de praca) nem o bloquete intertravado (esse e estacionamento de
supermercado). Escolhido contra outros sete candidatos da busca "cobblestone".
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from baixar_texturas import baixar_zip, consultar_id, extrair_cor, psxificar  # noqa: E402
import texturas_hd  # noqa: E402
from importar_hd import ajustar  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
NOME = "paralelepipedo"
ASSET = "PavingStones119"
LADO = 256
CONTRASTE = 1.16


def importar() -> int:
    achado = consultar_id(ASSET)
    if achado is None:
        print("asset nao encontrado")
        return 1
    dados = baixar_zip(*achado)
    if dados is None:
        return 1
    cor = extrair_cor(dados)
    if cor is None:
        print("zip sem mapa de cor")
        return 1
    destino = RAIZ / "game" / "assets" / "textures" / f"{NOME}.png"
    psxificar(cor, LADO, CONTRASTE).save(destino, "PNG", optimize=True)
    print(f"{NOME}: {ASSET} {cor.width}x{cor.height} -> {LADO} px, 256 cores")
    if not texturas_hd.montar(NOME, ASSET):
        return 1
    print("agora: godot --headless --path game --import  e depois  --hd")
    return 0


def ajustar_hd() -> int:
    pasta = RAIZ / "game" / "assets" / "textures_hd"
    feitos = 0
    for arq in sorted(pasta.glob(f"{NOME}*.import")):
        if ajustar(arq):
            print(f"ajustado {arq.name}")
        feitos += 1
    if feitos == 0:
        print("nenhum .import ainda: rode o --import do godot antes")
        return 1
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--hd", action="store_true",
                    help="so ajusta mipmap e compressao do conjunto HD")
    args = ap.parse_args()
    return ajustar_hd() if args.hd else importar()


if __name__ == "__main__":
    sys.exit(main())

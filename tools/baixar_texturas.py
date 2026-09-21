#!/usr/bin/env python3
"""Baixa texturas CC0 do ambientCG e converte para a spec PSX do ART-BIBLE.

Fonte: https://ambientcg.com — tudo em CC0, dominio publico, sem atribuicao
obrigatoria e sem risco de direito autoral. E o mesmo caminho que estudios como
Chilla's Art usam: foto real reduzida e quantizada rende muito mais detalhe que
ruido procedural.

    python tools/baixar_texturas.py                 baixa o catalogo inteiro
    python tools/baixar_texturas.py asfalto calcada baixa so os nomes dados
    python tools/baixar_texturas.py --limpar-cache
"""

import argparse
import io
import json
import re
import shutil
import sys
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "game" / "assets" / "textures"
CACHE = RAIZ / ".tools" / "cache_texturas"
API = "https://ambientcg.com/api/v2/full_json"
UA = {"User-Agent": "psx-game-dev/1.0 (asset pipeline)"}

# nome no projeto -> (busca no ambientCG, lado em px, ganho de contraste)
#
# O lado maior segue o ART-BIBLE secao 6: 256 px para superficie que o jogador
# pisa ou encosta o nariz, 128 px para o resto. Contraste acima de 1.0 compensa
# a perda de faixa dinamica na quantizacao para 256 cores.
CATALOGO: dict[str, tuple[str, int, float]] = {
    # rua e chao externo
    "asfalto":           ("Road013A",           256, 1.22),
    "asfalto_remendo":   ("Road012B",           256, 1.20),
    "asfalto_faixa":     ("Road009C",           256, 1.20),
    "calcada":           ("PavingStones128",    256, 1.20),
    "calcada_ladrilho":  ("PavingStones146",    256, 1.18),
    "meio_fio":          ("Concrete044D",       128, 1.18),
    "terra":             ("Ground037",          256, 1.20),
    # paredes externas
    "concreto_parede":   ("Concrete042A",       256, 1.26),
    "concreto_sujo":     ("Concrete030",        256, 1.24),
    "azulejo_fachada":   ("Tiles143",           256, 1.20),
    "tijolo":            ("Bricks097",          256, 1.18),
    "metal_ondulado":    ("CorrugatedSteel009", 256, 1.22),
    "metal_enferrujado": ("CorrugatedSteel007C",256, 1.20),
    "reboco":            ("Plaster001",         256, 1.20),
    # interiores
    "piso_madeira":      ("WoodFloor051",       256, 1.22),
    "piso_ceramico":     ("Tiles140",           256, 1.18),
    "madeira_tabua":     ("Planks037A",         128, 1.20),
    "metal":             ("Metal046B",          128, 1.18),
    # casa da fumaca (PLANO_CASA_FUMACA_V2, F3)
    "courino":           ("Leather026",         256, 1.15),
    "tecido":            ("Fabric026",          256, 1.15),
    "tapete":            ("Carpet012",          256, 1.15),
    "azulejo_cozinha":   ("Tiles101",           256, 1.15),
    "mdf":               ("Wood049",            256, 1.15),
    "plastico":          ("Plastic010",         128, 1.10),
}

# Variantes pedem indices diferentes do resultado da busca, senao vem tudo igual.
DESEMPATE: dict[str, int] = {}


ID_EXATO = re.compile(r"^[A-Z][A-Za-z]+\d+[A-Z]?$")


def resolver(termo: str, indice: int) -> tuple[str, str] | None:
    """Id exato vira download direto; qualquer outra coisa cai na busca.

    Escolher o asset pelo id tira a roleta da busca, que devolvia material
    diferente a cada execucao e fazia a textura mudar sem ninguem pedir.
    """
    if ID_EXATO.match(termo):
        # Montar a URL na mao da 404 em parte do catalogo, porque nem todo asset
        # publica o mesmo conjunto de arquivos. A API devolve o link que existe.
        return consultar_id(termo)
    return buscar(termo, indice)


def consultar_id(asset_id: str) -> tuple[str, str] | None:
    q = urllib.parse.urlencode({"type": "Material", "id": asset_id,
                                "include": "downloadData", "limit": 1})
    try:
        req = urllib.request.Request(f"{API}?{q}", headers=UA)
        with urllib.request.urlopen(req, timeout=40) as r:
            achados = json.load(r).get("foundAssets", [])
    except Exception as e:
        print(f"    consulta '{asset_id}' falhou: {e}")
        return None
    if not achados:
        print(f"    id '{asset_id}' nao existe no catalogo")
        return None
    cats = (achados[0].get("downloadFolders", {}).get("default", {})
            .get("downloadFiletypeCategories", {}))
    for grupo in cats.values():
        for d in grupo.get("downloads", []):
            if d.get("attribute") == "1K-JPG" and d.get("downloadLink"):
                return asset_id, d["downloadLink"]
    print(f"    '{asset_id}' sem variante 1K-JPG")
    return None


def buscar(termo: str, indice: int) -> tuple[str, str] | None:
    """Devolve (id, url do zip 1K-JPG) do n-esimo resultado da busca."""
    q = urllib.parse.urlencode({
        "type": "Material", "q": termo, "limit": 12,
        "include": "downloadData", "sort": "popular",
    })
    try:
        req = urllib.request.Request(f"{API}?{q}", headers=UA)
        with urllib.request.urlopen(req, timeout=40) as r:
            dados = json.load(r)
    except Exception as e:
        print(f"    busca '{termo}' falhou: {e}")
        return None

    achados = dados.get("foundAssets", [])
    if not achados:
        return None

    for asset in achados[indice:] + achados[:indice]:
        cats = (asset.get("downloadFolders", {}).get("default", {})
                .get("downloadFiletypeCategories", {}))
        for grupo in cats.values():
            for d in grupo.get("downloads", []):
                if d.get("attribute") == "1K-JPG" and d.get("downloadLink"):
                    return asset.get("assetId", termo), d["downloadLink"]
    return None


def baixar_zip(asset_id: str, url: str) -> bytes | None:
    CACHE.mkdir(parents=True, exist_ok=True)
    cache = CACHE / f"{asset_id}_1K-JPG.zip"
    if cache.exists() and cache.stat().st_size > 10_000:
        return cache.read_bytes()
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=180) as r:
            dados = r.read()
    except Exception as e:
        print(f"    download falhou: {e}")
        return None
    cache.write_bytes(dados)
    return dados


def extrair_cor(dados: bytes) -> Image.Image | None:
    """Tira o mapa de cor do zip. Normal, roughness e AO nao servem: o contrato
    PSX nao tem iluminacao per-pixel."""
    try:
        z = zipfile.ZipFile(io.BytesIO(dados))
    except zipfile.BadZipFile:
        return None
    nomes = [n for n in z.namelist() if re.search(r"_Color\.(jpg|jpeg|png)$", n, re.I)]
    if not nomes:
        nomes = [n for n in z.namelist() if re.search(r"\.(jpg|jpeg|png)$", n, re.I)]
    if not nomes:
        return None
    return Image.open(io.BytesIO(z.read(nomes[0]))).convert("RGB")


def psxificar(img: Image.Image, lado: int, contraste: float) -> Image.Image:
    """Reduz, realca e quantiza. ART-BIBLE secao 6.

    A reducao vai em passos de metade com LANCZOS em vez de um BOX direto de 4x.
    BOX faz media de blocos 4x4 e transforma estrutura em papa; a piramide
    preserva a frequencia media, que e onde mora a leitura de asfalto, azulejo e
    concreto. O unsharp depois devolve o micro-contraste que a reducao come, e e
    o que faz a textura ainda ler a 256 px numa tela de 480x270.
    """
    menor = min(img.size)
    esq, topo = (img.width - menor) // 2, (img.height - menor) // 2
    img = img.crop((esq, topo, esq + menor, topo + menor))

    while img.width > lado * 2:
        img = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
    if img.width != lado:
        img = img.resize((lado, lado), Image.LANCZOS)

    img = img.filter(ImageFilter.UnsharpMask(radius=1.1, percent=125, threshold=2))
    img = ImageEnhance.Contrast(img).enhance(contraste)
    img = ImageEnhance.Color(img).enhance(1.15)

    return img.quantize(colors=256, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG)


def main() -> int:
    ap = argparse.ArgumentParser(description="Importa texturas CC0 na spec PSX.")
    ap.add_argument("nomes", nargs="*", help="nomes do catalogo; vazio faz todos")
    ap.add_argument("--limpar-cache", action="store_true")
    args = ap.parse_args()

    if args.limpar_cache and CACHE.exists():
        shutil.rmtree(CACHE)
        print("cache limpo")

    alvos = args.nomes or list(CATALOGO)
    desconhecidos = [n for n in alvos if n not in CATALOGO]
    if desconhecidos:
        print("nomes fora do catalogo:", ", ".join(desconhecidos))
        return 1

    DESTINO.mkdir(parents=True, exist_ok=True)
    ok = falhas = 0

    for nome in alvos:
        termo, lado, contraste = CATALOGO[nome]
        print(f"{nome:18s} <- {termo}")

        achado = resolver(termo, DESEMPATE.get(nome, 0))
        if achado is None:
            print("    sem resultado"); falhas += 1; continue

        asset_id, url = achado
        dados = baixar_zip(asset_id, url)
        if dados is None:
            falhas += 1; continue

        cor = extrair_cor(dados)
        if cor is None:
            print("    zip sem mapa de cor"); falhas += 1; continue

        origem = f"{cor.width}x{cor.height}"
        psxificar(cor, lado, contraste).save(DESTINO / f"{nome}.png", "PNG", optimize=True)
        print(f"    {asset_id}  {origem} -> {lado}x{lado}  256 cores")
        ok += 1

    print(f"\n{ok} texturas importadas, {falhas} falhas")
    print("fonte: ambientCG, licenca CC0")
    return 0 if falhas == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

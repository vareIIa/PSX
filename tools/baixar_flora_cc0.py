#!/usr/bin/env python3
"""Baixa as fotos CC0 de folha, capim e casca do ambientCG para a flora AAA.

PLANO_FLORA_AAA, rodada 3. A folha dos atlas da rodada 1 e 2 era DESENHADA
(elipse com nervura, `gerar_vegetacao_hd.py`): de perto, em 4K, lia como
ilustracao vetorial. Aqui a folha e FOTO escaneada (LeafSet do ambientCG, CC0:
dominio publico, sem atribuicao), com mapa de opacidade, normal e rugosidade de
verdade. O gerador (`gerar_flora_foto.py`) recorta cada folha da foto e monta os
ramos das celulas com elas.

    python tools/baixar_flora_cc0.py            baixa o que falta no cache
    python tools/baixar_flora_cc0.py --lista    so mostra o catalogo

O cache fica em .tools/cache_flora/ (fora do git, como o de texturas). Sem
rede, o gerador cai de volta na folha desenhada.
"""

import argparse
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CACHE = RAIZ / ".tools" / "cache_flora"
API = "https://ambientcg.com/api/v2/full_json"
UA = {"User-Agent": "psx-game-dev/1.0 (asset pipeline)"}

# id -> (resolucao, para que serve). Id exato: a busca devolvia outro asset a
# cada execucao e a textura mudava sem ninguem pedir (baixar_texturas.py).
CATALOGO: dict[str, tuple[str, str]] = {
    # folhas
    "LeafSet022": ("2K-JPG", "mangueira: lanceolada, verde-escura, lustrosa"),
    "LeafSet003": ("2K-JPG", "oiti e abacateiro: eliptica"),
    "LeafSet018": ("2K-JPG", "jaqueira: larga e grossa"),
    "LeafSet023": ("2K-JPG", "pata-de-vaca, folha clara em coracao"),
    "LeafSet024": ("2K-JPG", "folha miuda de copa (ipe fora da florada)"),
    "LeafSet001": ("2K-JPG", "ficus, jabuticaba: eliptica pequena"),
    "LeafSet013": ("2K-JPG", "foliolo estreito: sibipiruna, angico (composta)"),
    "LeafSet021": ("2K-JPG", "lanceolada estreita: goiabeira, bambu"),
    "LeafSet017": ("2K-JPG", "hera: unha-de-gato do muro"),
    "LeafSet014": ("2K-JPG", "serrilhada clara: arbusto, murta"),
    "LeafSet004": ("2K-JPG", "coracao: bracteas e trepadeira"),
    "LeafSet006": ("2K-JPG", "folha amarelando: seca de agosto"),
    "LeafSet008": ("2K-JPG", "folha seca: chao"),
    "LeafSet030": ("2K-JPG", "folha seca marrom: chao"),
    "Leaf003": ("2K-JPG", "folha recortada: samambaia, mato"),
    # capim
    "Foliage001": ("2K-JPG", "lamina de capim"),
    "Foliage004": ("2K-JPG", "lamina de capim fina"),
    "Foliage006": ("2K-JPG", "capim com espiga"),
    "Foliage002": ("2K-JPG", "pendao seco"),
    "Foliage003": ("2K-JPG", "pendao fino"),
    # casca
    "Bark001": ("2K-JPG", "casca rachada escura: mangueira, jaqueira, angico"),
    "Bark012": ("2K-JPG", "casca rachada marrom: a casca comum"),
    "Bark004": ("2K-JPG", "casca cinza: ipe, oiti, sibipiruna"),
    "Bark009": ("2K-JPG", "casca lisa manchada: goiabeira, jabuticabeira"),
}


def link(asset_id: str, resolucao: str) -> str | None:
    q = urllib.parse.urlencode({"id": asset_id, "include": "downloadData", "limit": 1})
    try:
        req = urllib.request.Request(f"{API}?{q}", headers=UA)
        with urllib.request.urlopen(req, timeout=40) as r:
            achados = json.load(r).get("foundAssets", [])
    except Exception as e:
        print(f"    consulta '{asset_id}' falhou: {e}")
        return None
    if not achados:
        print(f"    '{asset_id}' nao existe")
        return None
    for pasta in achados[0].get("downloadFolders", {}).values():
        for grupo in pasta.get("downloadFiletypeCategories", {}).values():
            for d in grupo.get("downloads", []):
                if d.get("attribute") == resolucao and d.get("downloadLink"):
                    return d["downloadLink"]
    return None


def baixar(asset_id: str, resolucao: str) -> Path | None:
    CACHE.mkdir(parents=True, exist_ok=True)
    destino = CACHE / f"{asset_id}_{resolucao}.zip"
    if destino.exists() and destino.stat().st_size > 10_000:
        return destino
    url = link(asset_id, resolucao)
    if url is None:
        return None
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=300) as r:
            dados = r.read()
    except Exception as e:
        print(f"    download de {asset_id} falhou: {e}")
        return None
    destino.write_bytes(dados)
    return destino


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lista", action="store_true")
    args = ap.parse_args()
    falhou = 0
    for asset_id, (res, uso) in CATALOGO.items():
        if args.lista:
            print(f"{asset_id:12s} {res:7s} {uso}")
            continue
        p = baixar(asset_id, res)
        if p is None:
            falhou += 1
            print(f"FALHOU {asset_id}")
        else:
            print(f"ok {asset_id} ({p.stat().st_size // 1024} KB)")
    return 1 if falhou else 0


if __name__ == "__main__":
    sys.exit(main())

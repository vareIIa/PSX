#!/usr/bin/env python3
"""Ajusta a importacao do conjunto HD: mipmap e compressao de VRAM.

    python tools/importar_hd.py
    godot --headless --path game --import      (rode depois)

Por que e um script e nao um ajuste no editor
---------------------------------------------
O `project.godot` desliga mipmap para TODA textura (`[importer_defaults]`,
ART-BIBLE secao 6): e o que mantem a textura do PS1 nadando e granulada de longe
em vez de virar borrao cinza. O conjunto HD precisa do oposto — sem mipmap, uma
parede de 1024 px vista de longe em 4K cintila a cada passo do jogador.

Como os dois convivem: o padrao do projeto continua valendo, e aqui so as
texturas de `assets/textures_hd/` recebem o ajuste, arquivo por arquivo, no
`[params]` do `.import` que o Godot ja gerou.

    mipmaps/generate=true     cintilacao some na distancia
    compress/mode=2           VRAM comprimida (S3TC/BPTC): ~6x menos memoria
    compress/normal_map=1     so nos mapas de normal, que comprimem por outro
                              caminho (dois canais); tratar normal como cor
                              mancha o relevo
    roughness/mode             fica como esta: a rugosidade daqui vem do
                              ambientCG, e nao e derivada do mapa de normal

O filtro (ponto ou linear) e o anisotropico NAO sao decididos aqui: no Godot 4
eles vivem no sampler do shader. Ver `psx_surface_pixel.gdshader`, que pede
`filter_linear_mipmap_anisotropic` no conjunto HD e mantem `filter_nearest` no
albedo do PS1.
"""

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DIR = RAIZ / "game" / "assets" / "textures_hd"

AJUSTES = {
    "mipmaps/generate": "true",
    "compress/mode": "2",
}


def ajustar(caminho: Path) -> bool:
    texto = caminho.read_text(encoding="utf-8")
    alvo = dict(AJUSTES)
    # Mapa de normal comprime por outro caminho.
    alvo["compress/normal_map"] = "1" if caminho.name.endswith("_n.jpg.import") else "0"
    mudou = False
    linhas = []
    for linha in texto.splitlines():
        chave = linha.split("=", 1)[0]
        if chave in alvo:
            nova = f"{chave}={alvo[chave]}"
            mudou = mudou or nova != linha
            linhas.append(nova)
        else:
            linhas.append(linha)
    if mudou:
        caminho.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    return mudou


def main() -> int:
    if not DIR.is_dir():
        print(f"{DIR} nao existe; rode tools/texturas_hd.py antes")
        return 1
    arquivos = sorted(DIR.glob("*.import"))
    if not arquivos:
        print("nenhum .import: rode `godot --headless --path game --import` antes")
        return 1
    mudados = sum(1 for a in arquivos if ajustar(a))
    print(f"{mudados} de {len(arquivos)} .import ajustados em "
          f"{DIR.relative_to(RAIZ)}")
    print("Agora: godot --headless --path game --import")
    return 0


if __name__ == "__main__":
    sys.exit(main())

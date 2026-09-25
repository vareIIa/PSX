"""Cor media de cada material de chunk, para o anel distante (Horizonte).

O chunk desenha ALBEDO = textura * tint * cor do vertice (psx_surface.gdshader).
O Horizonte nao tem textura: cada ponto da planta leva a media da textura do
material, ja vezes o tint, e a cor do vertice por cima. Calcular isso no jogo
pediria ler a textura de volta da GPU (milissegundos por material, no quadro);
aqui sai uma vez, do PNG de origem.

A media e LINEAR (a textura e source_color: sRGB no disco, linear no shader) e
so dos pixels opacos (a copa de cartao e meio transparente, e o fundo dela nao
e cor de folha).

    python tools/gerar_cores_horizonte.py

Escreve game/resources/horizonte/cores_materiais.json:
    { "asfalto": [r, g, b], ... }   (linear, 0..1)

Rode de novo quando entrar material novo: o jogo usa cinza e avisa no log para
o que nao estiver na tabela.
"""
import json
import os
import re

from PIL import Image

RAIZ = os.path.join(os.path.dirname(__file__), "..", "game")
MATERIAIS = os.path.join(RAIZ, "resources", "materials")
SAIDA = os.path.join(RAIZ, "resources", "horizonte", "cores_materiais.json")


def linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


LUT = [linear(float(i)) for i in range(256)]


def cor_media(caminho):
    img = Image.open(caminho).convert("RGBA")
    # 64 x 64 chega para a media e deixa a ferramenta instantanea.
    img.thumbnail((64, 64), Image.BOX)
    soma = [0.0, 0.0, 0.0]
    n = 0
    for r, g, b, a in img.getdata():
        if a < 128:
            continue
        soma[0] += LUT[r]
        soma[1] += LUT[g]
        soma[2] += LUT[b]
        n += 1
    if n == 0:
        return None
    return [s / n for s in soma]


def main():
    cores = {}
    faltam = []
    for nome in sorted(os.listdir(MATERIAIS)):
        if not nome.startswith("mat_") or not nome.endswith(".tres"):
            continue
        texto = open(os.path.join(MATERIAIS, nome), encoding="utf-8").read()
        mat = nome[4:-5]
        ids = dict(re.findall(r'\[ext_resource type="Texture2D" path="res://([^"]+)" id="([^"]+)"\]', texto))
        ids = {v: k for k, v in ids.items()}
        m = re.search(r'shader_parameter/albedo_tex = ExtResource\("([^"]+)"\)', texto)
        tint = [1.0, 1.0, 1.0]
        t = re.search(r"shader_parameter/tint = Color\(([^)]+)\)", texto)
        if t:
            tint = [linear(float(x) * 255.0) for x in t.group(1).split(",")[:3]]
        if not m or m.group(1) not in ids:
            faltam.append(mat)
            continue
        png = os.path.join(RAIZ, ids[m.group(1)])
        if not os.path.exists(png):
            faltam.append(mat)
            continue
        media = cor_media(png)
        if media is None:
            faltam.append(mat)
            continue
        cores[mat] = [round(media[i] * tint[i], 5) for i in range(3)]
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "w", encoding="utf-8") as f:
        json.dump(cores, f, indent=1, sort_keys=True)
    print("materiais: %d com cor, sem textura: %s" % (len(cores), ", ".join(faltam)))


if __name__ == "__main__":
    main()

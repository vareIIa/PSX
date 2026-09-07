#!/usr/bin/env python3
"""Gera icones e definicoes de item.

Icone de 64 px desenhado em formas chapadas, no espirito da referencia de
inventario: recorte simples sobre fundo transparente, sem sombra nem degrade. A
tela tem 480x270, entao um icone de 64 px ja ocupa um oitavo da largura.

    python tools/gerar_itens.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
ICONES = RAIZ / "game" / "assets" / "icones"
ITENS = RAIZ / "game" / "resources" / "itens"
S = 64

MODELO = '''[gd_resource type="Resource" script_class="Item" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/systems/item.gd" id="1_item"]
[ext_resource type="Texture2D" path="res://assets/icones/{id}.png" id="2_icone"]

[resource]
script = ExtResource("1_item")
id = &"{id}"
nome = "{nome}"
descricao = "{descricao}"
tipo = {tipo}
icone = ExtResource("2_icone")
empilhavel = {empilhavel}
max_pilha = {max_pilha}
consumivel = {consumivel}
cura = {cura}
municao_de = &"{municao_de}"
'''

# Tipos, na ordem do enum em item.gd
CURA, MUNICAO, ARMA, FERRAMENTA, CHAVE, DOCUMENTO = range(6)


def novo() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def contorno(d: ImageDraw.ImageDraw, forma: str, caixa, cor, borda=(24, 20, 18, 255)) -> None:
    """Preenche e contorna. O contorno escuro e o que faz o icone recortar do
    fundo de papelao da prancha."""
    if forma == "rect":
        d.rectangle(caixa, fill=cor, outline=borda, width=2)
    elif forma == "ellipse":
        d.ellipse(caixa, fill=cor, outline=borda, width=2)


def icone_bandagem() -> Image.Image:
    im, d = novo()
    contorno(d, "ellipse", (8, 8, 56, 56), (238, 235, 226, 255))
    contorno(d, "ellipse", (24, 24, 40, 40), (196, 190, 176, 255))
    d.rectangle((6, 28, 30, 38), fill=(224, 219, 206, 255), outline=(24, 20, 18, 255), width=2)
    return im


def icone_pistola() -> Image.Image:
    im, d = novo()
    corpo = (86, 96, 70, 255)
    d.rectangle((10, 22, 54, 34), fill=corpo, outline=(24, 20, 18, 255), width=2)
    d.polygon([(20, 34), (34, 34), (28, 54), (16, 54)], fill=corpo, outline=(24, 20, 18, 255))
    d.rectangle((44, 16, 52, 24), fill=(60, 68, 50, 255), outline=(24, 20, 18, 255), width=2)
    return im


def icone_municao() -> Image.Image:
    im, d = novo()
    d.rectangle((8, 20, 56, 48), fill=(38, 36, 40, 255), outline=(24, 20, 18, 255), width=2)
    d.rectangle((12, 24, 52, 30), fill=(180, 52, 44, 255))
    for x in range(16, 50, 10):
        d.rectangle((x, 34, x + 6, 44), fill=(196, 158, 78, 255), outline=(24, 20, 18, 255))
    return im


def icone_lanterna() -> Image.Image:
    im, d = novo()
    d.rectangle((14, 26, 44, 40), fill=(64, 62, 58, 255), outline=(24, 20, 18, 255), width=2)
    d.polygon([(44, 20), (58, 14), (58, 52), (44, 46)],
              fill=(198, 192, 170, 255), outline=(24, 20, 18, 255))
    d.rectangle((18, 30, 26, 36), fill=(140, 136, 128, 255))
    return im


def icone_bateria() -> Image.Image:
    im, d = novo()
    d.rectangle((22, 12, 42, 54), fill=(48, 62, 88, 255), outline=(24, 20, 18, 255), width=2)
    d.rectangle((28, 6, 36, 12), fill=(180, 174, 158, 255), outline=(24, 20, 18, 255))
    d.rectangle((26, 22, 38, 30), fill=(206, 176, 62, 255))
    return im


def icone_chave() -> Image.Image:
    im, d = novo()
    cor = (188, 158, 84, 255)
    contorno(d, "ellipse", (10, 18, 34, 42), cor)
    contorno(d, "ellipse", (18, 26, 26, 34), (0, 0, 0, 0))
    d.rectangle((32, 27, 56, 33), fill=cor, outline=(24, 20, 18, 255), width=2)
    d.rectangle((46, 33, 52, 42), fill=cor, outline=(24, 20, 18, 255), width=2)
    return im


def icone_pe_de_cabra() -> Image.Image:
    im, d = novo()
    cor = (150, 66, 48, 255)
    d.line([(14, 52), (46, 16)], fill=cor, width=8)
    d.line([(14, 52), (46, 16)], fill=(24, 20, 18, 255), width=2)
    d.polygon([(42, 10), (56, 18), (48, 26), (38, 20)], fill=cor, outline=(24, 20, 18, 255))
    return im


def icone_bilhete() -> Image.Image:
    im, d = novo()
    d.polygon([(14, 8), (50, 8), (50, 56), (14, 56)],
              fill=(226, 218, 194, 255), outline=(24, 20, 18, 255))
    for y in range(18, 50, 7):
        d.line([(20, y), (44, y)], fill=(120, 110, 96, 255), width=2)
    return im


def icone_radio() -> Image.Image:
    im, d = novo()
    d.rectangle((10, 20, 54, 50), fill=(58, 54, 50, 255), outline=(24, 20, 18, 255), width=2)
    d.rectangle((16, 26, 36, 38), fill=(30, 28, 26, 255))
    for x in range(18, 36, 5):
        d.line([(x, 26), (x, 38)], fill=(90, 86, 80, 255))
    contorno(d, "ellipse", (42, 28, 50, 36), (176, 148, 72, 255))
    d.line([(48, 20), (54, 6)], fill=(140, 136, 128, 255), width=3)
    return im


def icone_identidade() -> Image.Image:
    """A carteira, fechada, vista de frente. Verde e com foto: as duas coisas que
    fazem o olho reconhecer o documento antes de ler a etiqueta."""
    im, d = novo()
    d.rectangle((8, 14, 56, 50), fill=(206, 216, 196, 255),
                outline=(24, 20, 18, 255), width=2)
    # Faixa do cabecalho.
    d.rectangle((8, 14, 56, 22), fill=(58, 92, 64, 255))
    # Foto 3x4 no canto, que e o que da a leitura de documento.
    d.rectangle((13, 26, 27, 45), fill=(130, 142, 148, 255),
                outline=(40, 44, 40, 255))
    d.ellipse((17, 29, 24, 36), fill=(196, 172, 148, 255))
    d.pieslice((14, 36, 27, 50), 180, 360, fill=(90, 96, 100, 255))
    # Linhas de campo.
    for i, y in enumerate(range(28, 46, 5)):
        d.line([(31, y), (52 - i * 4, y)], fill=(96, 104, 92, 255), width=2)
    return im


ITEM_DEFS = [
    # id, nome, descricao, tipo, icone, empilhavel, pilha, consumivel, cura, municao_de
    ("bandagem", "Bandagem", "Para o sangue. Nao resolve o que causou.",
     CURA, icone_bandagem, True, 5, True, 35, ""),
    ("remedio", "Remedio", "Amargo. Meu pai tomava um desses todo dia.",
     CURA, icone_bandagem, True, 3, True, 70, ""),
    ("pistola", "Pistola", "Arma pesada. Espero nao precisar.",
     ARMA, icone_pistola, False, 1, False, 0, ""),
    ("municao_9mm", "Municao 9mm", "Conte antes de sair. Depois nao da tempo.",
     MUNICAO, icone_municao, True, 30, False, 0, "pistola"),
    ("lanterna", "Lanterna", "A luz acaba antes da noite.",
     FERRAMENTA, icone_lanterna, False, 1, False, 0, ""),
    ("bateria", "Bateria", "Ainda tem carga. Acho.",
     FERRAMENTA, icone_bateria, True, 6, True, 0, ""),
    ("radio", "Radio", "So pega chiado. O chiado tambem diz alguma coisa.",
     FERRAMENTA, icone_radio, False, 1, False, 0, ""),
    ("chave_apartamento", "Chave", "Numero apagado. Abre alguma porta.",
     CHAVE, icone_chave, False, 1, False, 0, ""),
    ("pe_de_cabra", "Pe de cabra", "Serve para abrir. Serve para outras coisas.",
     FERRAMENTA, icone_pe_de_cabra, False, 1, False, 0, ""),
    ("bilhete", "Bilhete", "A letra treme no fim. Ela escreveu com pressa.",
     DOCUMENTO, icone_bilhete, False, 1, False, 0, ""),
    ("identidade", "Identidade", "Sou eu. O nome, o numero, a data. Enquanto eu tiver isto, alguem pode provar que eu existi.",
     DOCUMENTO, icone_identidade, False, 1, False, 0, ""),
]


def main() -> int:
    ICONES.mkdir(parents=True, exist_ok=True)
    ITENS.mkdir(parents=True, exist_ok=True)

    for (iid, nome, desc, tipo, fn, emp, pilha, cons, cura, mun) in ITEM_DEFS:
        img = fn()
        # Quantiza mantendo o alfa: o icone recorta sobre o papelao da prancha.
        # MEDIANCUT nao aceita RGBA; octree aceita e preserva a transparencia.
        img.quantize(colors=64, method=Image.FASTOCTREE).save(
            ICONES / f"{iid}.png", "PNG", optimize=True)

        (ITENS / f"{iid}.tres").write_text(MODELO.format(
            id=iid, nome=nome, descricao=desc.replace('"', "'"), tipo=tipo,
            empilhavel=str(emp).lower(), max_pilha=pilha,
            consumivel=str(cons).lower(), cura=cura, municao_de=mun,
        ), encoding="utf-8")
        print(f"{iid:20s} {nome}")

    print(f"\n{len(ITEM_DEFS)} itens e icones")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

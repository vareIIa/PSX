#!/usr/bin/env python3
"""Atlas de letreiros de loja da rua comercial (ComercioVivo, PLANO_CASAS_AAA F3).

    python tools/gerar_letreiros.py

Dezesseis placas de 2:8 (duas colunas, oito linhas) com o nome pintado em letra
escura sobre fundo claro. O fundo sai branco-sujo de proposito: o shader multiplica
a textura pela cor do vertice, entao a mesma placa vira amarela, verde, azul
conforme a loja, e a letra continua escura.

Duas saidas, a mesma arte:
    game/assets/textures/letreiros.png      256 px (PS1 STYLE, teto do ART-BIBLE 6)
    game/assets/textures_hd/letreiros.png  1024 px (MODERNO, TexturasHD pelo nome)

E o segundo atlas, o da rua de servico (IndustriaViva, PLANO_CASAS_AAA F4): o nome
da firma pintado direto na parede do galpao, da oficina e do armazem, na mesma grade:
    game/assets/textures/letreiros_industria.png
    game/assets/textures_hd/letreiros_industria.png

E conteudo trocavel: para pintar nomes reais de uma cidade, edite NOMES e rode de
novo, ou substitua os dois PNG por arte propria na mesma grade. Nenhum codigo le
os nomes: ComercioVivo so sorteia a celula (0 a 15).
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
PS1 = RAIZ / "game" / "assets" / "textures" / "letreiros.png"
HD = RAIZ / "game" / "assets" / "textures_hd" / "letreiros.png"
PS1_INDUSTRIA = RAIZ / "game" / "assets" / "textures" / "letreiros_industria.png"
HD_INDUSTRIA = RAIZ / "game" / "assets" / "textures_hd" / "letreiros_industria.png"

# Lojas de rua de cidade do interior de Minas. Nomes inventados.
NOMES = [
    ("PADARIA", "PÃO DE MINAS"),
    ("FARMÁCIA", "SÃO JOSÉ"),
    ("ARMARINHO", "DONA CIDA"),
    ("BAR DO TIÃO", ""),
    ("LOTÉRICA", "BOA SORTE"),
    ("MERCEARIA", "BOA VISTA"),
    ("MAT. DE CONSTRUÇÃO", "IRMÃOS REZENDE"),
    ("SALÃO", "BELEZA PURA"),
    ("AÇOUGUE", "SANTA RITA"),
    ("PAPELARIA", "ALFA"),
    ("SAPATARIA", "CENTRAL"),
    ("BAZAR", "TUDO 1,99"),
    ("LANCHONETE", "DO ZÉ"),
    ("ÓTICA", "VISÃO"),
    ("BORRACHARIA", "24 HORAS"),
    ("RELOJOARIA", "O TEMPO"),
]
# Firmas de rua de servico e de industria do interior de Minas. Nomes inventados.
# A ordem e o contrato com IndustriaViva.CELULAS (qual oficio usa qual celula).
NOMES_INDUSTRIA = [
    ("SERRALHERIA SÃO JOSÉ", "PORTÕES E GRADES"),
    ("MARCENARIA", "ESTRELA"),
    ("AUTO MECÂNICA", "DO BETO"),
    ("BORRACHARIA", "24 HORAS"),
    ("FUNILARIA E PINTURA", "IRMÃOS SILVA"),
    ("DEPÓSITO RIO VERDE", "AREIA · BRITA · CIMENTO"),
    ("CEREALISTA", "MINEIRA"),
    ("ARMAZÉM DE CAFÉ", "SANTA CRUZ"),
    ("COOPERATIVA", "DE LATICÍNIOS"),
    ("TORNEARIA", "PRECISÃO"),
    ("VIDRAÇARIA", "CRISTAL"),
    ("MADEIREIRA", "BOA ESPERANÇA"),
    ("OFICINA DE MOTOS", ""),
    ("FÁBRICA DE", "DOCE DE LEITE"),
    ("TRANSPORTADORA", "SERRA AZUL"),
    ("CERÂMICA", "SÃO BENTO"),
]
# Cor da letra: preto de tinta, vermelho, azul e verde escuros.
TINTAS = [(24, 22, 20), (120, 22, 18), (20, 40, 96), (22, 70, 36)]
FONTES = ["impact.ttf", "ariblk.ttf", "georgiab.ttf", "trebucbd.ttf",
          "bahnschrift.ttf", "verdanab.ttf"]
DIR_FONTES = Path("C:/Windows/Fonts")

LADO = 1024
COLUNAS, LINHAS = 2, 8


def fonte(nome: str, tamanho: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(DIR_FONTES / nome), tamanho)


def caber(texto: str, nome: str, largura: int, altura: int) -> ImageFont.FreeTypeFont:
    tam = altura
    while tam > 8:
        f = fonte(nome, tam)
        caixa = f.getbbox(texto)
        if caixa[2] - caixa[0] <= largura and caixa[3] - caixa[1] <= altura:
            return f
        tam -= 2
    return fonte(nome, 8)


def placa(indice: int, w: int, h: int, rng: random.Random,
          nomes: list = NOMES) -> Image.Image:
    fundo = (238 + rng.randint(-8, 6), 234 + rng.randint(-8, 6), 224 + rng.randint(-8, 6))
    im = Image.new("RGB", (w, h), fundo)
    d = ImageDraw.Draw(im)
    tinta = TINTAS[indice % len(TINTAS)]
    nome_fonte = FONTES[indice % len(FONTES)]
    linha1, linha2 = nomes[indice]
    # Filete pintado em volta, como a placa de rua.
    m = max(3, h // 18)
    d.rectangle([m, m, w - m - 1, h - m - 1], outline=tinta, width=max(2, h // 40))
    if linha2:
        f1 = caber(linha1, nome_fonte, int(w * 0.86), int(h * 0.42))
        f2 = caber(linha2, nome_fonte, int(w * 0.7), int(h * 0.28))
        d.text((w // 2, int(h * 0.38)), linha1, font=f1, fill=tinta, anchor="mm")
        d.text((w // 2, int(h * 0.75)), linha2, font=f2, fill=tinta, anchor="mm")
    else:
        f1 = caber(linha1, nome_fonte, int(w * 0.86), int(h * 0.6))
        d.text((w // 2, h // 2), linha1, font=f1, fill=tinta, anchor="mm")
    # Tinta velha: sujeira e desbotado, pouco.
    ruido = Image.effect_noise((w, h), 18).convert("L").filter(ImageFilter.GaussianBlur(1.2))
    sujo = Image.new("RGB", (w, h), (150, 140, 120))
    im = Image.composite(sujo, im, ruido.point(lambda v: max(0, v - 150)))
    return im


def atlas_de(nomes: list, semente: int, hd: Path, ps1: Path) -> None:
    rng = random.Random(semente)
    w, h = LADO // COLUNAS, LADO // LINHAS
    atlas = Image.new("RGB", (LADO, LADO), (230, 226, 216))
    for k in range(COLUNAS * LINHAS):
        atlas.paste(placa(k, w, h, rng, nomes), ((k % COLUNAS) * w, (k // COLUNAS) * h))
    hd.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(hd)
    atlas.resize((256, 256), Image.LANCZOS).save(ps1)
    print(f"letreiros: {len(nomes)} placas -> {hd.name} (1024) e {ps1.name} (256)")


def main() -> int:
    atlas_de(NOMES, 7, HD, PS1)
    atlas_de(NOMES_INDUSTRIA, 11, HD_INDUSTRIA, PS1_INDUSTRIA)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

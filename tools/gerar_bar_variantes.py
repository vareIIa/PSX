#!/usr/bin/env python3
"""Placas e toldos dos outros bares da cidade (BarVivo).

O Bar do Seu Ze tem letreiro e toldo proprios (tools/gerar_bar.py, intocado).
Os outros bares usam o mesmo salao e trocam o que troca de um boteco para outro
em Minas: a placa pintada — nome, letra, cor do fundo, a segunda linha — e a
listra do toldo.

    bares_nomes.png   atlas 2 x 8, a ordem e BarVivo.NOMES (256 px no PS1,
                      1024 px no MODERNO em textures_hd/)
    bar_toldo_verde / bar_toldo_azul / bar_toldo_laranja   256 px, como o original

Os materiais sao escritos aqui (o gerar_materiais.py reescreveria todos os da
tabela); as linhas vao tambem na tabela dele, para um regen futuro.

    python tools/gerar_bar_variantes.py
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "tools"))
import gerar_bar as gb  # noqa: E402
import gerar_materiais as gm  # noqa: E402

TEXTURAS = RAIZ / "game" / "assets" / "textures"
TEXTURAS_HD = RAIZ / "game" / "assets" / "textures_hd"
FONTES = Path("C:/Windows/Fonts")

# A mesma ordem de BarVivo.NOMES (game/src/world/bar_vivo.gd): e a celula.
NOMES = [
    ("BAR DO TIÃO", "CERVEJA GELADA"),
    ("BOTECO DO JOÃO", "DESDE 1974"),
    ("BAR SÃO JORGE", "SINUCA · PETISCOS"),
    ("BAR DO GERALDO", ""),
    ("BAR DA DONA CIDA", "TIRA-GOSTO"),
    ("BOTEQUIM", "BOA VISTA"),
    ("BAR DO MINEIRO", "CACHAÇA DE ALAMBIQUE"),
    ("BAR DO BIGODE", ""),
    ("BAR SANTA LUZIA", "MERCEARIA"),
    ("BAR DO LUIZINHO", "TORRESMO · PASTEL"),
    ("BAR PONTO CERTO", ""),
    ("BAR DO ZEQUINHA", "SINUCA"),
    ("CANTINHO DO", "TORRESMO"),
    ("BAR DA ESQUINA", "CERVEJA GELADA"),
    ("BAR DO CHICÃO", ""),
    ("BOTECO DO TONHO", "FORRÓ SÁBADO"),
]

# Placa pintada a mao: (fundo, letra, sombra da letra, filete).
PLACAS = [
    ((214, 176, 58), (150, 34, 30), (120, 90, 30), (150, 34, 30)),    # amarelo e vermelho
    ((176, 42, 38), (246, 236, 210), (90, 20, 18), (246, 236, 210)),  # vermelho e creme
    ((40, 96, 60), (236, 204, 70), (18, 50, 30), (236, 204, 70)),     # verde e amarelo
    ((36, 64, 118), (240, 240, 232), (16, 30, 60), (214, 176, 58)),   # azul e branco
    ((238, 232, 218), (30, 70, 130), (170, 164, 150), (176, 42, 38)), # branco, azul, filete vermelho
    ((226, 128, 44), (40, 30, 24), (160, 84, 26), (40, 30, 24)),      # laranja e preto
    ((24, 24, 22), (236, 196, 60), (80, 64, 20), (236, 196, 60)),     # preto e amarelo
    ((200, 212, 196), (120, 30, 40), (140, 150, 136), (60, 90, 60)),  # verde-claro e vinho
]
LETRAS = ["impact.ttf", "ariblk.ttf", "georgiab.ttf", "trebucbd.ttf", "bahnschrift.ttf",
          "verdanab.ttf", "comicbd.ttf", "tahomabd.ttf", "segoeuib.ttf"]


def _fonte(nome: str, tam: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTES / nome), tam)


def _caber(texto: str, nome: str, w: int, h: int) -> ImageFont.FreeTypeFont:
    tam = h
    while tam > 6:
        f = _fonte(nome, tam)
        x0, y0, x1, y1 = f.getbbox(texto)
        if x1 - x0 <= w and y1 - y0 <= h:
            return f
        tam -= 1
    return _fonte(nome, 6)


def placa(indice: int, w: int, h: int) -> Image.Image:
    r = random.Random(4400 + indice)
    fundo, letra, sombra, filete = PLACAS[(indice * 5 + 3) % len(PLACAS)]
    nome_fonte = LETRAS[(indice * 7 + 2) % len(LETRAS)]
    linha1, linha2 = NOMES[indice]
    im = Image.new("RGB", (w, h), fundo)
    d = ImageDraw.Draw(im)
    m = max(2, h // 16)
    # Filete pintado e, em metade das placas, uma faixa em cima e em baixo.
    if indice % 2 == 0:
        d.rectangle([0, 0, w, m * 2], fill=filete)
        d.rectangle([0, h - m * 2, w, h], fill=filete)
    else:
        d.rectangle([m, m, w - m - 1, h - m - 1], outline=filete, width=max(2, h // 28))
    s = max(1, h // 40)
    if linha2:
        f1 = _caber(linha1, nome_fonte, int(w * 0.88), int(h * 0.5))
        f2 = _caber(linha2, "arialbd.ttf" if (FONTES / "arialbd.ttf").exists() else nome_fonte,
                    int(w * 0.6), int(h * 0.2))
        for dx, dy, cor in ((s, s, sombra), (0, 0, letra)):
            d.text((w // 2 + dx, int(h * 0.42) + dy), linha1, font=f1, fill=cor, anchor="mm")
        d.text((w // 2, int(h * 0.8)), linha2, font=f2, fill=letra, anchor="mm")
    else:
        f1 = _caber(linha1, nome_fonte, int(w * 0.88), int(h * 0.62))
        for dx, dy, cor in ((s, s, sombra), (0, 0, letra)):
            d.text((w // 2 + dx, h // 2 + dy), linha1, font=f1, fill=cor, anchor="mm")
    # Tinta velha: desbotado e sujeira, pouco.
    ruido = Image.effect_noise((w, h), 22).convert("L").filter(ImageFilter.GaussianBlur(1.0))
    im = Image.composite(im, Image.new("RGB", (w, h), tuple(min(255, c + 18) for c in fundo)),
                         ruido.point(lambda v: 255 if v > 70 + r.randint(0, 20) else 200))
    return im


def atlas_nomes() -> None:
    for lado, destino, cores in ((1024, TEXTURAS_HD, 0), (256, TEXTURAS, 64)):
        cw, ch = lado // 2, lado // 8
        atlas = Image.new("RGB", (lado, lado))
        for k in range(len(NOMES)):
            # Desenha grande e reduz: a letra pequena do PS1 sai com meio-tom.
            im = placa(k, cw * 2 if lado < 1024 else cw, ch * 2 if lado < 1024 else ch)
            atlas.paste(im.resize((cw, ch), Image.LANCZOS), ((k % 2) * cw, (k // 2) * ch))
        destino.mkdir(parents=True, exist_ok=True)
        if cores:
            atlas = atlas.quantize(colors=cores, method=Image.MEDIANCUT)
        atlas.save(destino / "bares_nomes.png", "PNG", optimize=True)
        print(f"bares_nomes {lado}  -> {destino.name}")


def toldo(nome: str, listra: tuple, fundo: tuple = (238, 234, 222)) -> None:
    lado = gb.LADO
    im = Image.new("RGB", (lado, lado), fundo)
    d = ImageDraw.Draw(im)
    faixa = lado // 8
    for i in range(0, 8, 2):
        d.rectangle((i * faixa, 0, (i + 1) * faixa - 1, lado), fill=listra)
    escura = tuple(int(c * 0.45) for c in listra)
    for i in range(1, 8):
        d.line([(i * faixa, 0), (i * faixa, lado)], fill=escura, width=1)
    gb.salvar(nome, gb.grao(im, 3.0), 12)


def materiais() -> None:
    for nome, tex, tile, tint, snap, affine in gm.MATERIAIS:
        if nome not in ("bar_nomes", "bar_toldo_verde", "bar_toldo_azul", "bar_toldo_laranja"):
            continue
        vento, vv = gm.VENTO.get(nome, (0.0, 1.0))
        rec = gm.RECORTE.get(nome, 0.0)
        emis, en = gm.EMISSIVOS.get(nome, ("0, 0, 0", 0.0))
        (gm.DESTINO / f"mat_{nome}.tres").write_text(gm.MODELO.format(
            shader="psx_surface", nome=nome, tex=tex, tile=f"{tile:g}", tint=tint, snap=snap,
            affine=affine, emis=emis, energia=f"{en:g}", vento=f"{vento:g}", vento_vel=f"{vv:g}",
            recorte=f"{rec:g}"), encoding="utf-8")
        print("mat_" + nome)


def main() -> int:
    atlas_nomes()
    toldo("bar_toldo_verde", (46, 118, 70))
    toldo("bar_toldo_azul", (40, 80, 150))
    toldo("bar_toldo_laranja", (214, 110, 36))
    materiais()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

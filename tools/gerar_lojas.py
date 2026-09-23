#!/usr/bin/env python3
"""Texturas das lojas de verdade (LojaViva / KitLoja).

A loja da rua comercial deixou de ser uma casca atras da porta de enrolar: e
um salao em que se entra, arrumado pelo que a placa diz. O que enche o salao e
a frente da prateleira — a fileira de pao, de caixa de remedio, de carretel —,
e ela e um cartao por prateleira, recortado por alfa: a silhueta de cada
produto contra a tabua de tras, sem um triangulo por produto.

    loja_produtos.png   atlas 4 x 8 de celulas 2:1, a ordem e KitLoja.P_*
                        (256 px no PS1, 2048 px no MODERNO em textures_hd/)
    loja_cartazes.png   atlas 4 x 4: o cartaz de parede de cada ramo
    icones/<item>.png   96 px, os itens novos que as lojas vendem

Os materiais sao escritos aqui (o gerar_materiais.py reescreveria todos os da
tabela); as linhas vao tambem na tabela dele, para um regen futuro.

    python tools/gerar_lojas.py
"""

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "tools"))
import gerar_materiais as gm  # noqa: E402

TEXTURAS = RAIZ / "game" / "assets" / "textures"
TEXTURAS_HD = RAIZ / "game" / "assets" / "textures_hd"
ICONES = RAIZ / "game" / "assets" / "icones"
FONTES = Path("C:/Windows/Fonts")

# Celula do atlas de produtos, na escala HD. Tudo e desenhado nela e reduzido.
CW, CH = 512, 256
COLS, LINS = 4, 8

rnd = random.Random(1998)


def fonte(nome: str, tam: int) -> ImageFont.FreeTypeFont:
    caminho = FONTES / nome
    if caminho.exists():
        return ImageFont.truetype(str(caminho), tam)
    return ImageFont.load_default()


def caber(texto: str, nome: str, w: int, h: int) -> ImageFont.FreeTypeFont:
    tam = h
    while tam > 6:
        f = fonte(nome, tam)
        x0, y0, x1, y1 = f.getbbox(texto)
        if x1 - x0 <= w and y1 - y0 <= h:
            return f
        tam -= 1
    return fonte(nome, 6)


def escurecer(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + ((c[3],) if len(c) > 3 else ())


def hsv(h, s, v, a=255):
    import colorsys
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return (int(r * 255), int(g * 255), int(b * 255), a)


def sombreado(d: ImageDraw.ImageDraw, caixa, cor, raio=0, luz=1.12, sombra=0.72):
    """Caixa com luz em cima a esquerda e sombra em baixo a direita."""
    x0, y0, x1, y1 = caixa
    if raio:
        d.rounded_rectangle(caixa, raio, fill=cor)
    else:
        d.rectangle(caixa, fill=cor)
    w = max(1, (x1 - x0) // 9)
    d.rectangle((x0, y0, x0 + w, y1), fill=escurecer(cor, luz))
    d.rectangle((x1 - w, y0, x1, y1), fill=escurecer(cor, sombra))


def elipse_sombreada(d, caixa, cor):
    x0, y0, x1, y1 = caixa
    d.ellipse(caixa, fill=escurecer(cor, 0.8))
    w, h = x1 - x0, y1 - y0
    d.ellipse((x0 + w * 0.08, y0 + h * 0.05, x1 - w * 0.2, y1 - h * 0.25), fill=cor)
    d.ellipse((x0 + w * 0.22, y0 + h * 0.14, x0 + w * 0.5, y0 + h * 0.4),
              fill=escurecer(cor, 1.18))


# --- celulas de produto -------------------------------------------------------
# Cada funcao pinta uma celula RGBA de CW x CH. Alfa 0 e o fundo da prateleira
# (a tabua de tras aparece): e o recorte que faz a fileira ler como fileira.

def paes(im, d):
    # Pao frances em fila, em dois andares de cesto de vime.
    for fila, y in enumerate((150, 40)):
        d.rounded_rectangle((6, y + 80, CW - 6, y + 104), 8, fill=(150, 104, 56, 255))
        for k in range(0, CW - 10, 10):
            d.line([(6 + k, y + 82), (6 + k + 6, y + 102)], fill=(118, 80, 40, 255), width=2)
        x = 14
        while x < CW - 70:
            w = rnd.randint(64, 80)
            cor = (214 + rnd.randint(-14, 10), 150 + rnd.randint(-16, 10), 72, 255)
            elipse_sombreada(d, (x, y + 30 + rnd.randint(-4, 4), x + w, y + 90), cor)
            d.arc((x + w * 0.25, y + 36, x + w * 0.75, y + 70), 200, 340,
                  fill=(236, 204, 140, 255), width=4)
            x += w - 8


def bolos(im, d):
    x = 10
    while x < CW - 100:
        tipo = rnd.randint(0, 2)
        if tipo == 0:
            # Bolo de fuba em forma redonda, fatia faltando.
            d.ellipse((x, 150, x + 130, 196), fill=(170, 170, 176, 255))
            d.rectangle((x, 110, x + 130, 172), fill=(222, 170, 72, 255))
            d.ellipse((x, 88, x + 130, 134), fill=(236, 190, 96, 255))
            d.polygon([(x + 65, 111), (x + 130, 100), (x + 130, 140)], fill=(250, 226, 150, 255))
            x += 140
        elif tipo == 1:
            # Rosca com acucar.
            d.ellipse((x, 100, x + 120, 190), fill=(200, 140, 64, 255))
            d.ellipse((x + 38, 128, x + 82, 162), fill=(0, 0, 0, 0))
            for _ in range(40):
                px, py = x + rnd.randint(10, 110), 100 + rnd.randint(8, 60)
                d.point((px, py), fill=(250, 248, 240, 255))
            x += 128
        else:
            # Sonho empilhado.
            for k in range(3):
                elipse_sombreada(d, (x + k * 8, 150 - k * 38, x + 90 + k * 8, 196 - k * 38),
                                 (228, 176, 96, 255))
                d.ellipse((x + 30 + k * 8, 160 - k * 38, x + 60 + k * 8, 176 - k * 38),
                          fill=(250, 240, 220, 255))
            x += 108


def remedios(im, d):
    # Caixinhas em pe, com faixa de cor e a tarja.
    x = 6
    while x < CW - 40:
        w = rnd.randint(34, 58)
        h = rnd.randint(90, 180)
        base = (238, 238, 232, 255)
        sombreado(d, (x, CH - 12 - h, x + w, CH - 12), base)
        faixa = rnd.choice([(40, 90, 170), (200, 40, 40), (40, 140, 90), (230, 150, 30),
                            (130, 60, 150)]) + (255,)
        d.rectangle((x + 2, CH - 12 - h + 14, x + w - 2, CH - 12 - h + 34), fill=faixa)
        if rnd.random() < 0.3:
            d.rectangle((x + 2, CH - 30, x + w - 2, CH - 22), fill=(30, 30, 30, 255))
        for k in range(3):
            y = CH - 12 - h + 46 + k * 12
            if y < CH - 40:
                d.line([(x + 6, y), (x + w - 8, y)], fill=(120, 120, 130, 255), width=2)
        x += w + rnd.randint(2, 6)


def frascos(im, d):
    x = 8
    while x < CW - 40:
        w = rnd.randint(34, 52)
        h = rnd.randint(100, 200)
        cor = hsv(rnd.random(), rnd.uniform(0.35, 0.8), rnd.uniform(0.6, 0.95))
        topo = CH - 10 - h
        d.rounded_rectangle((x, topo + 26, x + w, CH - 10), 10, fill=cor)
        d.rectangle((x + w * 0.3, topo, x + w * 0.7, topo + 28),
                    fill=rnd.choice([(240, 240, 240, 255), (40, 40, 40, 255), (200, 170, 60, 255)]))
        d.rectangle((x + 4, topo + 70, x + w - 4, topo + 110), fill=(246, 244, 236, 255))
        d.rectangle((x + 3, topo + 30, x + 9, CH - 16), fill=escurecer(cor, 1.2))
        x += w + rnd.randint(4, 10)


def carreteis(im, d):
    for linha, y0 in enumerate((20, 132)):
        x = 8
        while x < CW - 40:
            cor = hsv(rnd.random(), rnd.uniform(0.5, 0.95), rnd.uniform(0.55, 0.98))
            d.rectangle((x, y0, x + 40, y0 + 12), fill=(206, 180, 130, 255))
            d.rectangle((x + 4, y0 + 12, x + 36, y0 + 88), fill=cor)
            for k in range(y0 + 16, y0 + 88, 6):
                d.line([(x + 4, k), (x + 36, k)], fill=escurecer(cor, 0.82), width=1)
            d.rectangle((x + 6, y0 + 12, x + 11, y0 + 88), fill=escurecer(cor, 1.2))
            d.rectangle((x, y0 + 88, x + 40, y0 + 100), fill=(206, 180, 130, 255))
            x += 46


def tecidos(im, d):
    # Rolos de tecido deitados, vistos de ponta, e o pano caindo.
    x = 4
    while x < CW - 90:
        cor = hsv(rnd.random(), rnd.uniform(0.3, 0.8), rnd.uniform(0.5, 0.95))
        w = rnd.randint(80, 110)
        d.rectangle((x, 30, x + w, CH - 8), fill=cor)
        padrao = rnd.randint(0, 2)
        if padrao == 0:
            for k in range(x, x + w, 14):
                d.line([(k, 30), (k, CH - 8)], fill=escurecer(cor, 0.7), width=4)
        elif padrao == 1:
            for yy in range(40, CH - 8, 22):
                for xx in range(x + 8, x + w - 6, 22):
                    d.ellipse((xx, yy, xx + 8, yy + 8), fill=(250, 246, 236, 255))
        d.rectangle((x, 30, x + 8, CH - 8), fill=escurecer(cor, 1.18))
        d.rectangle((x + w - 8, 30, x + w, CH - 8), fill=escurecer(cor, 0.7))
        d.ellipse((x + w * 0.2, 6, x + w * 0.8, 44), fill=escurecer(cor, 0.9))
        d.ellipse((x + w * 0.42, 18, x + w * 0.58, 32), fill=(90, 70, 50, 255))
        x += w + 6


def racao(im, d):
    # Sacos de racao empilhados de frente: o cachorro e o nome.
    x = 4
    while x < CW - 120:
        w = rnd.randint(120, 150)
        cor = rnd.choice([(200, 40, 40), (230, 170, 30), (40, 110, 60), (40, 80, 150),
                          (220, 110, 30)]) + (255,)
        d.rounded_rectangle((x, 26, x + w, CH - 6), 14, fill=cor)
        d.rectangle((x + 8, 26, x + w - 8, 44), fill=escurecer(cor, 0.7))
        d.ellipse((x + w * 0.2, 80, x + w * 0.8, 170), fill=(236, 220, 190, 255))
        # Focinho e orelhas: o cachorro da embalagem.
        d.ellipse((x + w * 0.36, 108, x + w * 0.64, 160), fill=(170, 120, 70, 255))
        d.ellipse((x + w * 0.26, 94, x + w * 0.4, 132), fill=(110, 70, 40, 255))
        d.ellipse((x + w * 0.6, 94, x + w * 0.74, 132), fill=(110, 70, 40, 255))
        d.ellipse((x + w * 0.46, 130, x + w * 0.54, 140), fill=(20, 20, 20, 255))
        f = caber("RAÇÃO", "impact.ttf", int(w * 0.8), 30)
        d.text((x + w * 0.5, 62), "RAÇÃO", font=f, fill=(250, 246, 230, 255), anchor="mm")
        d.text((x + w * 0.5, 200), "15 kg", font=fonte("arialbd.ttf", 22),
               fill=(250, 246, 230, 255), anchor="mm")
        d.rectangle((x + 4, 30, x + 14, CH - 12), fill=escurecer(cor, 1.15))
        x += w + 6


def latas(im, d):
    for y0 in (24, 136):
        x = 6
        while x < CW - 50:
            w = rnd.randint(46, 60)
            cor = hsv(rnd.random(), rnd.uniform(0.4, 0.9), rnd.uniform(0.55, 0.95))
            d.rectangle((x, y0 + 8, x + w, y0 + 96), fill=(190, 190, 196, 255))
            d.rectangle((x, y0 + 22, x + w, y0 + 82), fill=cor)
            d.ellipse((x + w * 0.25, y0 + 36, x + w * 0.75, y0 + 68), fill=(246, 240, 226, 255))
            d.rectangle((x, y0 + 8, x + 6, y0 + 96), fill=(236, 236, 240, 255))
            d.rectangle((x + w - 6, y0 + 8, x + w, y0 + 96), fill=(120, 120, 126, 255))
            x += w + 4


def pacotes(im, d):
    # Arroz, feijao, acucar e cafe: o pacote de 1 kg em pe.
    marcas = [((246, 244, 236), (40, 110, 60), "ARROZ"), ((150, 40, 30), (240, 200, 60), "CAFÉ"),
              ((250, 250, 250), (40, 80, 160), "AÇÚCAR"), ((60, 40, 30), (230, 150, 40), "FEIJÃO"),
              ((236, 200, 60), (170, 40, 30), "FUBÁ")]
    x = 6
    while x < CW - 60:
        fundo, letra, nome = rnd.choice(marcas)
        w = rnd.randint(62, 80)
        h = rnd.randint(150, 200)
        sombreado(d, (x, CH - 8 - h, x + w, CH - 8), fundo + (255,))
        d.rectangle((x + 2, CH - 8 - h + 30, x + w - 2, CH - 8 - h + 64), fill=letra + (255,))
        f = caber(nome, "arialbd.ttf", w - 10, 26)
        d.text((x + w / 2, CH - 8 - h + 47), nome, font=f, fill=fundo + (255,), anchor="mm")
        d.text((x + w / 2, CH - 34), "1 kg", font=fonte("arial.ttf", 18),
               fill=escurecer(letra + (255,), 0.8), anchor="mm")
        x += w + 3


def cimento(im, d):
    x = 2
    for pilha in range(3):
        w = 160
        for k in range(4):
            y = CH - 8 - (k + 1) * 56
            cor = (196, 190, 176, 255) if pilha % 2 == 0 else (206, 196, 170, 255)
            d.rounded_rectangle((x + rnd.randint(-4, 4), y, x + w + rnd.randint(-4, 4), y + 54),
                                18, fill=cor)
            d.rectangle((x + 20, y + 14, x + w - 20, y + 36), fill=(40, 70, 140, 255)
                        if pilha != 1 else (190, 40, 36, 255))
            d.text((x + w / 2, y + 25), "CIMENTO" if pilha != 1 else "ARGAMASSA",
                   font=caber("ARGAMASSA", "arialbd.ttf", w - 50, 18), fill=(250, 250, 250, 255),
                   anchor="mm")
        x += w + 8


def tintas(im, d):
    for y0 in (20, 136):
        x = 8
        while x < CW - 70:
            w = rnd.randint(70, 84)
            cor = hsv(rnd.random(), rnd.uniform(0.3, 0.9), rnd.uniform(0.6, 0.98))
            d.rectangle((x, y0 + 4, x + w, y0 + 96), fill=(206, 206, 210, 255))
            d.rectangle((x, y0 + 20, x + w, y0 + 70), fill=(246, 246, 246, 255))
            d.ellipse((x + 6, y0 + 26, x + 36, y0 + 64), fill=cor)
            d.rectangle((x + 40, y0 + 34, x + w - 6, y0 + 42), fill=escurecer(cor, 0.7))
            d.rectangle((x + 40, y0 + 48, x + w - 14, y0 + 54), fill=(120, 120, 120, 255))
            d.line([(x + 6, y0 + 4), (x + w / 2, y0 - 10), (x + w - 6, y0 + 4)],
                   fill=(90, 90, 90, 255), width=3)
            x += w + 6


def cosmeticos(im, d):
    x = 6
    while x < CW - 24:
        tipo = rnd.random()
        cor = hsv(rnd.random(), rnd.uniform(0.5, 0.95), rnd.uniform(0.55, 0.95))
        if tipo < 0.55:
            # Esmalte: vidrinho e tampa preta.
            d.rounded_rectangle((x, CH - 70, x + 26, CH - 12), 6, fill=cor)
            d.rectangle((x + 7, CH - 104, x + 19, CH - 70), fill=(20, 20, 20, 255))
            d.rectangle((x + 3, CH - 66, x + 8, CH - 18), fill=escurecer(cor, 1.3))
            x += 32
        else:
            d.rounded_rectangle((x, CH - 170, x + 44, CH - 12), 12, fill=cor)
            d.rectangle((x + 12, CH - 196, x + 32, CH - 170), fill=(240, 240, 240, 255))
            d.rectangle((x + 4, CH - 120, x + 40, CH - 80), fill=(250, 250, 250, 255))
            x += 50


def carnes(im, d):
    # A bandeja da vitrine do acougue: bife, linguica, frango.
    x = 8
    while x < CW - 110:
        w = rnd.randint(110, 140)
        d.rectangle((x, 120, x + w, CH - 10), fill=(226, 230, 232, 255))
        d.rectangle((x + 4, 124, x + w - 4, CH - 14), fill=(200, 206, 210, 255))
        tipo = rnd.randint(0, 2)
        if tipo == 0:
            for k in range(3):
                cx = x + 18 + k * (w - 36) / 3
                d.ellipse((cx, 128 + k * 6, cx + 50, 206 + k * 4), fill=(170, 40, 44, 255))
                d.ellipse((cx + 6, 134 + k * 6, cx + 20, 150 + k * 6), fill=(236, 220, 200, 255))
        elif tipo == 1:
            for k in range(5):
                yy = 132 + k * 22
                d.rounded_rectangle((x + 10, yy, x + w - 10, yy + 18), 9, fill=(176, 70, 60, 255))
                d.line([(x + 16, yy + 5), (x + w - 16, yy + 5)], fill=(210, 110, 96, 255), width=2)
        else:
            for k in range(2):
                cx = x + 10 + k * (w / 2 - 6)
                d.ellipse((cx, 130, cx + w / 2 - 8, 220), fill=(232, 196, 150, 255))
                d.ellipse((cx + 8, 140, cx + 30, 170), fill=(246, 222, 186, 255))
        d.rectangle((x + w - 40, 100, x + w - 4, 122), fill=(250, 250, 250, 255))
        d.text((x + w - 22, 111), "%d,%02d" % (rnd.randint(3, 12), rnd.choice([0, 50, 90])),
               font=fonte("arialbd.ttf", 14), fill=(190, 30, 30, 255), anchor="mm")
        x += w + 8


def cadernos(im, d):
    x = 6
    while x < CW - 50:
        w = rnd.randint(50, 70)
        h = rnd.randint(150, 210)
        cor = hsv(rnd.random(), rnd.uniform(0.4, 0.9), rnd.uniform(0.5, 0.95))
        sombreado(d, (x, CH - 8 - h, x + w, CH - 8), cor)
        d.rectangle((x + 2, CH - 8 - h, x + 8, CH - 8), fill=(40, 40, 40, 255))
        d.ellipse((x + w * 0.3, CH - 8 - h + 40, x + w * 0.9, CH - 8 - h + 90),
                  fill=escurecer(cor, 1.25))
        x += w + 2
    # Pote de lapis na ponta.
    d.rectangle((CW - 44, 140, CW - 8, CH - 8), fill=(60, 60, 60, 255))
    for k in range(6):
        d.line([(CW - 40 + k * 6, 140), (CW - 44 + k * 7, 70 + rnd.randint(0, 20))],
               fill=hsv(rnd.random(), 0.8, 0.9), width=4)


def caixas_sapato(im, d):
    for y0 in (8, 128):
        x = 4
        while x < CW - 90:
            w = rnd.randint(96, 120)
            cor = rnd.choice([(220, 200, 170), (240, 240, 236), (60, 60, 64), (200, 70, 50),
                              (60, 100, 160), (230, 170, 60)]) + (255,)
            sombreado(d, (x, y0, x + w, y0 + 112), cor)
            d.rectangle((x, y0, x + w, y0 + 18), fill=escurecer(cor, 0.82))
            d.rectangle((x + w * 0.6, y0 + 40, x + w - 8, y0 + 80), fill=(250, 250, 250, 255))
            d.text((x + w * 0.8, y0 + 60), str(rnd.randint(34, 44)), font=fonte("arialbd.ttf", 22),
                   fill=(30, 30, 30, 255), anchor="mm")
            x += w + 4


def sapatos(im, d):
    x = 8
    while x < CW - 100:
        cor = rnd.choice([(50, 30, 20), (120, 70, 40), (20, 20, 20), (180, 40, 50), (240, 236, 230),
                          (60, 90, 150)]) + (255,)
        w = rnd.randint(96, 116)
        tipo = rnd.randint(0, 2)
        if tipo == 0:
            # Sapato social de perfil.
            d.polygon([(x, CH - 20), (x + 12, CH - 60), (x + 44, CH - 64), (x + w - 10, CH - 44),
                       (x + w, CH - 20)], fill=cor)
            d.rectangle((x, CH - 20, x + w, CH - 12), fill=(30, 20, 14, 255))
        elif tipo == 1:
            # Bota.
            d.polygon([(x + 6, CH - 20), (x + 6, CH - 140), (x + 44, CH - 140), (x + 50, CH - 60),
                       (x + w, CH - 44), (x + w, CH - 20)], fill=cor)
            d.rectangle((x + 4, CH - 20, x + w, CH - 12), fill=(30, 20, 14, 255))
        else:
            # Tenis.
            d.polygon([(x, CH - 22), (x + 8, CH - 70), (x + 46, CH - 76), (x + w, CH - 40),
                       (x + w, CH - 22)], fill=(240, 240, 240, 255))
            d.polygon([(x + 20, CH - 66), (x + 50, CH - 70), (x + 80, CH - 44), (x + 30, CH - 40)],
                      fill=cor)
            d.rectangle((x, CH - 22, x + w, CH - 12), fill=(190, 60, 40, 255))
        d.rectangle((x + 10, CH - 110, x + 46, CH - 90), fill=(250, 246, 200, 255))
        d.text((x + 28, CH - 100), "%d,90" % rnd.randint(19, 79), font=fonte("arialbd.ttf", 12),
               fill=(190, 30, 30, 255), anchor="mm")
        x += w + 12


def brinquedos(im, d):
    x = 6
    while x < CW - 40:
        tipo = rnd.randint(0, 3)
        cor = hsv(rnd.random(), 0.85, 0.95)
        if tipo == 0:
            # Bola.
            d.ellipse((x, CH - 82, x + 70, CH - 12), fill=cor)
            d.arc((x + 6, CH - 76, x + 64, CH - 18), 200, 340, fill=(250, 250, 250, 255), width=5)
            x += 76
        elif tipo == 1:
            # Balde de plastico.
            d.polygon([(x, CH - 110), (x + 70, CH - 110), (x + 60, CH - 12), (x + 10, CH - 12)],
                      fill=cor)
            d.arc((x, CH - 150, x + 70, CH - 80), 180, 360, fill=escurecer(cor, 0.6), width=4)
            x += 78
        elif tipo == 2:
            # Carrinho.
            d.rectangle((x, CH - 60, x + 80, CH - 30), fill=cor)
            d.rectangle((x + 16, CH - 86, x + 60, CH - 60), fill=escurecer(cor, 0.8))
            for rx in (x + 8, x + 56):
                d.ellipse((rx, CH - 38, rx + 22, CH - 14), fill=(30, 30, 30, 255))
            x += 88
        else:
            # Boneca na caixa.
            d.rectangle((x, CH - 180, x + 64, CH - 12), fill=(236, 110, 170, 255))
            d.rectangle((x + 8, CH - 166, x + 56, CH - 30), fill=(250, 220, 236, 255))
            d.ellipse((x + 20, CH - 156, x + 44, CH - 128), fill=(236, 196, 160, 255))
            d.polygon([(x + 16, CH - 128), (x + 48, CH - 128), (x + 52, CH - 40), (x + 12, CH - 40)],
                      fill=hsv(rnd.random(), 0.7, 0.9))
            x += 70


def utensilios(im, d):
    # Pendurados no gancho: peneira, concha, vassoura, caneca esmaltada.
    d.rectangle((0, 10, CW, 18), fill=(90, 90, 96, 255))
    x = 12
    while x < CW - 40:
        tipo = rnd.randint(0, 3)
        d.line([(x + 20, 18), (x + 20, 34)], fill=(60, 60, 60, 255), width=3)
        if tipo == 0:
            d.ellipse((x - 10, 34, x + 60, 104), fill=(200, 190, 150, 255))
            for k in range(x - 4, x + 56, 6):
                d.line([(k, 40), (k, 98)], fill=(150, 140, 110, 255), width=1)
            d.line([(x + 25, 104), (x + 25, 180)], fill=(150, 110, 60, 255), width=8)
            x += 80
        elif tipo == 1:
            d.line([(x + 20, 34), (x + 20, 150)], fill=(200, 200, 206, 255), width=6)
            d.ellipse((x, 140, x + 40, 180), fill=(200, 200, 206, 255))
            x += 50
        elif tipo == 2:
            cor = hsv(rnd.random(), 0.8, 0.85)
            d.line([(x + 20, 34), (x + 20, 170)], fill=(170, 120, 60, 255), width=6)
            d.polygon([(x - 8, 170), (x + 48, 170), (x + 56, 240), (x - 16, 240)], fill=cor)
            x += 70
        else:
            cor = rnd.choice([(250, 250, 250), (40, 90, 170), (200, 40, 40)]) + (255,)
            d.rectangle((x, 40, x + 50, 100), fill=cor)
            d.ellipse((x + 44, 50, x + 66, 90), outline=cor, width=6)
            d.line([(x, 42), (x + 50, 42)], fill=(30, 30, 60, 255), width=4)
            x += 76


def salgados(im, d):
    d.rectangle((0, 150, CW, CH), fill=(210, 206, 196, 255))
    x = 8
    while x < CW - 60:
        tipo = rnd.randint(0, 2)
        if tipo == 0:
            # Coxinha.
            d.polygon([(x + 30, 60), (x + 60, 150), (x, 150)], fill=(206, 130, 50, 255))
            d.ellipse((x, 100, x + 60, 170), fill=(214, 140, 56, 255))
            d.ellipse((x + 10, 110, x + 28, 130), fill=(232, 176, 90, 255))
            x += 66
        elif tipo == 1:
            # Pastel.
            d.pieslice((x, 80, x + 110, 210), 180, 360, fill=(226, 180, 90, 255))
            for k in range(x + 6, x + 104, 10):
                d.line([(k, 145), (k + 4, 138)], fill=(180, 130, 60, 255), width=2)
            x += 116
        else:
            # Pao de queijo.
            for k in range(3):
                elipse_sombreada(d, (x + k * 34, 110 + (k % 2) * 8, x + 44 + k * 34, 160 + (k % 2) * 8),
                                 (234, 196, 110, 255))
            x += 116


def garrafas(im, d):
    x = 8
    while x < CW - 30:
        tipo = rnd.random()
        if tipo < 0.4:
            cor = (40, 110, 50, 255)
            rot = (240, 220, 60, 255)
        elif tipo < 0.7:
            cor = (40, 20, 16, 255)
            rot = (200, 30, 30, 255)
        else:
            cor = (200, 110, 30, 255)
            rot = (40, 90, 160, 255)
        d.rounded_rectangle((x, 100, x + 34, CH - 8), 8, fill=cor)
        d.polygon([(x + 4, 100), (x + 30, 100), (x + 22, 50), (x + 12, 50)], fill=cor)
        d.rectangle((x + 12, 30, x + 22, 52), fill=cor)
        d.rectangle((x + 11, 26, x + 23, 34), fill=(210, 190, 60, 255))
        d.rectangle((x, 150, x + 34, 196), fill=rot)
        d.rectangle((x + 4, 104, x + 9, CH - 16), fill=escurecer(cor, 1.6))
        x += 40


def oculos(im, d):
    # O expositor: tres fileiras de oculos no feltro.
    for y0 in (30, 110, 190):
        x = 16
        while x < CW - 90:
            cor = rnd.choice([(20, 20, 20), (120, 60, 30), (180, 160, 60), (160, 40, 40),
                              (40, 60, 120)]) + (255,)
            escuro = rnd.random() < 0.5
            lente = (40, 50, 50, 255) if escuro else (190, 210, 220, 255)
            d.ellipse((x, y0, x + 36, y0 + 28), fill=lente, outline=cor, width=4)
            d.ellipse((x + 44, y0, x + 80, y0 + 28), fill=lente, outline=cor, width=4)
            d.line([(x + 34, y0 + 8), (x + 46, y0 + 8)], fill=cor, width=3)
            x += 96


def relogios(im, d):
    x = 10
    while x < CW - 60:
        r = rnd.randint(28, 44)
        cy = rnd.randint(70, 180)
        caixa = rnd.choice([(200, 170, 70), (190, 190, 196), (40, 40, 40)]) + (255,)
        d.ellipse((x, cy - r, x + 2 * r, cy + r), fill=caixa)
        d.ellipse((x + 5, cy - r + 5, x + 2 * r - 5, cy + r - 5), fill=(246, 242, 230, 255))
        cx = x + r
        for k in range(12):
            a = k * math.pi / 6
            d.point((cx + math.cos(a) * (r - 10), cy + math.sin(a) * (r - 10)), fill=(20, 20, 20, 255))
        a = rnd.random() * math.tau
        d.line([(cx, cy), (cx + math.cos(a) * (r - 14), cy + math.sin(a) * (r - 14))],
               fill=(20, 20, 20, 255), width=3)
        a = rnd.random() * math.tau
        d.line([(cx, cy), (cx + math.cos(a) * (r - 8), cy + math.sin(a) * (r - 8))],
               fill=(20, 20, 20, 255), width=2)
        # Pulseira.
        d.rectangle((cx - 10, cy + r, cx + 10, min(CH - 6, cy + r + 40)), fill=escurecer(caixa, 0.7))
        d.rectangle((cx - 10, max(4, cy - r - 40), cx + 10, cy - r), fill=escurecer(caixa, 0.7))
        x += 2 * r + 14


def pneus(im, d):
    # A banda de rodagem de pneus em pe, lado a lado.
    x = 4
    while x < CW - 70:
        w = rnd.randint(66, 80)
        d.rounded_rectangle((x, 10, x + w, CH - 6), 16, fill=(34, 34, 36, 255))
        for yy in range(20, CH - 12, 16):
            d.line([(x + 8, yy), (x + w / 2, yy + 8), (x + w - 8, yy)], fill=(18, 18, 20, 255),
                   width=4)
        d.rectangle((x + 3, 16, x + 9, CH - 14), fill=(62, 62, 66, 255))
        x += w + 4


def ferramentas(im, d):
    # Painel de eucatex furado com as ferramentas penduradas.
    d.rectangle((0, 0, CW, CH), fill=(170, 140, 100, 255))
    for yy in range(8, CH, 16):
        for xx in range(8, CW, 16):
            d.ellipse((xx, yy, xx + 3, yy + 3), fill=(120, 96, 66, 255))
    x = 16
    while x < CW - 50:
        tipo = rnd.randint(0, 3)
        if tipo == 0:
            # Martelo.
            d.line([(x + 20, 40), (x + 20, 200)], fill=(150, 100, 50, 255), width=10)
            d.rectangle((x, 30, x + 44, 56), fill=(70, 70, 76, 255))
            x += 60
        elif tipo == 1:
            # Chave inglesa.
            d.line([(x + 18, 60), (x + 18, 210)], fill=(170, 170, 176, 255), width=12)
            d.ellipse((x, 30, x + 36, 70), fill=(170, 170, 176, 255))
            d.rectangle((x + 12, 26, x + 24, 46), fill=(170, 140, 100, 255))
            x += 50
        elif tipo == 2:
            # Serrote.
            d.polygon([(x, 60), (x + 70, 50), (x + 70, 190), (x, 170)], fill=(190, 190, 196, 255))
            for k in range(60, 190, 8):
                d.line([(x + 70, k), (x + 76, k + 4)], fill=(120, 120, 126, 255), width=2)
            d.rectangle((x - 4, 40, x + 30, 80), fill=(190, 60, 30, 255))
            x += 90
        else:
            # Alicate.
            cor = hsv(rnd.random(), 0.8, 0.8)
            d.line([(x + 10, 110), (x + 4, 210)], fill=cor, width=10)
            d.line([(x + 22, 110), (x + 30, 210)], fill=cor, width=10)
            d.polygon([(x + 8, 110), (x + 24, 110), (x + 20, 50), (x + 12, 50)], fill=(80, 80, 86, 255))
            x += 48


def loteria(im, d):
    d.rectangle((0, 0, CW, CH), fill=(0, 0, 0, 0))
    x = 8
    while x < CW - 70:
        w = 70
        cor = rnd.choice([(30, 130, 70), (40, 90, 170), (220, 120, 30), (150, 40, 130)]) + (255,)
        d.rectangle((x, 20, x + w, CH - 16), fill=(250, 250, 246, 255))
        d.rectangle((x, 20, x + w, 50), fill=cor)
        for yy in range(60, CH - 30, 14):
            for xx in range(x + 6, x + w - 8, 12):
                d.rectangle((xx, yy, xx + 7, yy + 8), outline=cor, width=1)
        x += w + 6


def potes(im, d):
    x = 8
    while x < CW - 80:
        w = rnd.randint(72, 90)
        d.rounded_rectangle((x, 60, x + w, CH - 8), 12, fill=(214, 226, 226, 255))
        conteudo = hsv(rnd.random(), 0.8, 0.9)
        for _ in range(26):
            px, py = x + rnd.randint(8, w - 18), rnd.randint(80, CH - 26)
            d.ellipse((px, py, px + 12, py + 12), fill=hsv(rnd.random(), 0.8, 0.95))
        d.rectangle((x + 6, 40, x + w - 6, 62), fill=(200, 40, 40, 255))
        d.rectangle((x + 4, 64, x + 10, CH - 14), fill=(246, 250, 250, 255))
        x += w + 8
        _ = conteudo


def cachacas(im, d):
    x = 8
    while x < CW - 40:
        cor = rnd.choice([(230, 200, 120, 200), (246, 240, 220, 200), (200, 140, 60, 220)])
        d.rounded_rectangle((x, 90, x + 40, CH - 8), 6, fill=cor[:3] + (255,))
        d.rectangle((x + 14, 40, x + 26, 92), fill=cor[:3] + (255,))
        d.rectangle((x + 13, 32, x + 27, 44), fill=(90, 60, 40, 255))
        d.rectangle((x + 2, 140, x + 38, 190), fill=rnd.choice([(250, 246, 230), (40, 70, 40),
                                                                  (120, 30, 30)]) + (255,))
        d.rectangle((x + 4, 96, x + 9, CH - 16), fill=(255, 255, 250, 255))
        x += 46


def balaios(im, d):
    x = 4
    while x < CW - 110:
        w = rnd.randint(110, 140)
        cor = (180 + rnd.randint(-20, 20), 140, 80, 255)
        d.polygon([(x, 90), (x + w, 90), (x + w - 16, CH - 8), (x + 16, CH - 8)], fill=cor)
        for yy in range(96, CH - 8, 10):
            d.line([(x + 6, yy), (x + w - 6, yy)], fill=escurecer(cor, 0.75), width=2)
        for xx in range(x + 10, x + w - 6, 12):
            d.line([(xx, 92), (xx + 4, CH - 10)], fill=escurecer(cor, 0.85), width=1)
        d.arc((x + 10, 30, x + w - 10, 150), 180, 360, fill=escurecer(cor, 0.7), width=8)
        x += w + 6


def bijuterias(im, d):
    d.rectangle((0, 0, CW, CH), fill=(30, 30, 36, 255))
    for y0 in (20, 140):
        x = 10
        while x < CW - 60:
            d.rectangle((x, y0, x + 56, y0 + 100), fill=(236, 230, 214, 255))
            cor = rnd.choice([(220, 190, 70), (200, 200, 210), (170, 40, 60), (50, 120, 170)]) + (255,)
            d.arc((x + 8, y0 + 8, x + 48, y0 + 70), 0, 180, fill=cor, width=3)
            d.ellipse((x + 22, y0 + 64, x + 34, y0 + 78), fill=cor)
            x += 64


def revistas(im, d):
    x = 4
    while x < CW - 70:
        w = rnd.randint(72, 90)
        cor = hsv(rnd.random(), 0.6, 0.9)
        d.rectangle((x, 30, x + w, CH - 8), fill=cor)
        d.rectangle((x + 4, 34, x + w - 4, 62), fill=(250, 250, 250, 255))
        d.rectangle((x + 10, 80, x + w - 10, 170), fill=hsv(rnd.random(), 0.4, 0.7))
        d.line([(x + 6, 190), (x + w - 12, 190)], fill=(250, 250, 250, 255), width=4)
        x += w + 4


def sementes(im, d):
    # Pacotinhos de semente de horta pendurados no expositor.
    for y0 in (14, 132):
        x = 8
        while x < CW - 50:
            d.rectangle((x, y0, x + 50, y0 + 106), fill=(246, 242, 226, 255))
            d.ellipse((x + 6, y0 + 20, x + 44, y0 + 70), fill=hsv(rnd.choice([0.0, 0.08, 0.3, 0.14]),
                                                                  0.8, 0.8))
            d.rectangle((x, y0, x + 50, y0 + 14), fill=(40, 110, 50, 255))
            x += 56


def linguica(im, d):
    # Linguica pendurada no varal do acougue: recorte puro.
    d.line([(0, 10), (CW, 10)], fill=(120, 120, 126, 255), width=4)
    x = 10
    while x < CW - 40:
        for k in range(rnd.randint(2, 4)):
            y = 14 + k * 58
            d.rounded_rectangle((x, y, x + 26, y + 56), 12, fill=(150, 60, 50, 255))
            d.line([(x + 6, y + 8), (x + 6, y + 48)], fill=(190, 96, 80, 255), width=3)
        x += 36


PRODUTOS = [
    paes, bolos, remedios, frascos,
    carreteis, tecidos, racao, latas,
    pacotes, cimento, tintas, cosmeticos,
    carnes, cadernos, caixas_sapato, sapatos,
    brinquedos, utensilios, salgados, garrafas,
    oculos, relogios, pneus, ferramentas,
    loteria, potes, cachacas, balaios,
    bijuterias, revistas, sementes, linguica,
]


def atlas_produtos() -> None:
    lado = CW * COLS
    atlas = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    for i, f in enumerate(PRODUTOS):
        cel = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        f(cel, ImageDraw.Draw(cel))
        # Contorno escuro de 2 px: a silhueta tem de ler a 480x270, contra
        # tabua clara ou escura.
        a = cel.getchannel("A")
        borda = a.filter(ImageFilter.MaxFilter(5))
        contorno = Image.new("RGBA", (CW, CH), (26, 22, 20, 255))
        contorno.putalpha(borda)
        cel = Image.alpha_composite(contorno, cel)
        atlas.alpha_composite(cel, ((i % COLS) * CW, (i // COLS) * CH))
    salvar_par("loja_produtos", atlas)


# --- cartazes -----------------------------------------------------------------

CARTAZES = [
    ("cruz", None),
    ("PÃO QUENTINHO", "6h  e  17h"),
    ("tabela", ["ALCATRA 6,90", "COSTELA 3,50", "LINGUIÇA 4,20", "FRANGO 2,80"]),
    ("RESULTADO", "04 12 23 35 41 58"),
    ("CORTE  R$ 8", "ESCOVA  R$ 12"),
    ("XEROX  0,10", "PLASTIFICAÇÃO"),
    ("LIQUIDAÇÃO", "50% OFF"),
    ("TUDO", "1,99"),
    ("tabela", ["COXINHA 1,50", "PASTEL 2,00", "PÃO DE QUEIJO 1,00", "CAFÉ 0,50"]),
    ("EXAME DE VISTA", "GRÁTIS"),
    ("CONSERTOS", "EM GERAL"),
    ("RAÇÃO A GRANEL", "VACINAS"),
    ("CIMENTO", "R$ 9,50"),
    ("FIADO SÓ", "AMANHÃ"),
    ("santo", None),
    ("PNEUS NOVOS", "E REMOLDADOS"),
]
FUNDOS_CARTAZ = [(250, 246, 232), (244, 214, 60), (250, 250, 250), (40, 110, 70),
                 (250, 236, 240), (230, 240, 250), (220, 40, 40), (250, 200, 30),
                 (246, 240, 220), (30, 70, 130), (240, 236, 226), (60, 120, 60),
                 (240, 240, 236), (250, 246, 232), (200, 220, 240), (30, 30, 30)]
LETRAS_CARTAZ = [(30, 140, 60), (170, 30, 24), (30, 30, 30), (250, 250, 240),
                 (170, 30, 90), (30, 60, 140), (250, 250, 240), (170, 30, 24),
                 (30, 30, 30), (250, 250, 240), (30, 30, 30), (250, 240, 200),
                 (40, 70, 140), (170, 30, 24), (40, 40, 60), (240, 200, 40)]


def atlas_cartazes() -> None:
    cel = 512
    atlas = Image.new("RGB", (cel * 4, cel * 4), (240, 236, 226))
    for i, (a, b) in enumerate(CARTAZES):
        im = Image.new("RGB", (cel, cel), FUNDOS_CARTAZ[i])
        d = ImageDraw.Draw(im)
        letra = LETRAS_CARTAZ[i]
        d.rectangle((10, 10, cel - 11, cel - 11), outline=letra, width=8)
        if a == "cruz":
            d.rectangle((196, 80, 316, 432), fill=(30, 150, 70))
            d.rectangle((80, 196, 432, 316), fill=(30, 150, 70))
            f = caber("FARMÁCIA", "arialbd.ttf", 420, 60)
            d.text((cel / 2, 470), "FARMÁCIA", font=f, fill=(30, 110, 50), anchor="mm")
        elif a == "santo":
            # Calendario de parede com a santa: a moldura azul, o manto, 1998.
            d.rectangle((60, 40, cel - 60, 300), fill=(70, 110, 170))
            d.polygon([(256, 70), (330, 290), (182, 290)], fill=(40, 60, 130))
            d.ellipse((226, 70, 286, 130), fill=(230, 200, 160))
            d.ellipse((200, 50, 312, 150), outline=(240, 200, 60), width=6)
            d.text((cel / 2, 340), "1998", font=fonte("georgiab.ttf", 56), fill=(170, 30, 24),
                   anchor="mm")
            for k in range(5):
                for j in range(7):
                    d.rectangle((70 + j * 54, 380 + k * 24, 110 + j * 54, 398 + k * 24),
                                outline=(60, 60, 60), width=1)
        elif a == "tabela":
            d.rectangle((24, 24, cel - 25, 110), fill=letra)
            d.text((cel / 2, 67), "PREÇOS", font=fonte("impact.ttf", 70),
                   fill=FUNDOS_CARTAZ[i], anchor="mm")
            for k, linha in enumerate(b):
                f = caber(linha, "comicbd.ttf", 440, 64)
                d.text((cel / 2, 170 + k * 88), linha, font=f, fill=letra, anchor="mm")
        else:
            f1 = caber(a, rnd.choice(["impact.ttf", "arialbd.ttf", "comicbd.ttf"]), 440, 150)
            d.text((cel / 2, 180), a, font=f1, fill=letra, anchor="mm")
            f2 = caber(b, "arialbd.ttf", 420, 110)
            d.text((cel / 2, 360), b, font=f2, fill=letra, anchor="mm")
        # Papel envelhecido: o durex nos cantos e a luz de cima.
        for cx, cy in ((30, 30), (cel - 60, 30)):
            d.rectangle((cx, cy, cx + 30, cy + 18), fill=(236, 230, 200))
        atlas.paste(im, ((i % 4) * cel, (i // 4) * cel))
    salvar_par("loja_cartazes", atlas)


# --- itens --------------------------------------------------------------------

def _icone(nome: str, pintar) -> None:
    lado = 384
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pintar(d)
    im = im.resize((96, 96), Image.LANCZOS)
    ICONES.mkdir(parents=True, exist_ok=True)
    im.save(ICONES / f"{nome}.png", "PNG", optimize=True)
    print(f"icones/{nome}.png")


def _pao_de_queijo(d):
    for cx, cy, r in ((150, 210, 90), (250, 190, 80), (200, 120, 70)):
        d.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), fill=(190, 140, 60, 255))
        d.ellipse((cx - r + 8, cy - r * 0.8 + 6, cx + r - 20, cy + r * 0.8 - 18), fill=(236, 196, 112, 255))
        d.ellipse((cx - r * 0.5, cy - r * 0.55, cx, cy - r * 0.15), fill=(250, 228, 170, 255))


def _cafe(d):
    d.ellipse((60, 250, 324, 330), fill=(230, 230, 226, 255))
    d.polygon([(110, 130), (274, 130), (254, 290), (130, 290)], fill=(246, 246, 242, 255))
    d.ellipse((110, 110, 274, 160), fill=(90, 50, 30, 255))
    d.arc((250, 160, 330, 250), 270, 90, fill=(246, 246, 242, 255), width=18)
    d.line([(150, 90), (160, 40)], fill=(220, 220, 220, 200), width=8)
    d.line([(210, 90), (200, 30)], fill=(220, 220, 220, 200), width=8)


def _coxinha(d):
    d.polygon([(192, 40), (310, 260), (74, 260)], fill=(196, 120, 44, 255))
    d.ellipse((70, 170, 314, 350), fill=(206, 130, 50, 255))
    d.ellipse((110, 200, 190, 260), fill=(236, 180, 96, 255))
    for _ in range(90):
        x, y = rnd.randint(90, 300), rnd.randint(120, 330)
        d.point((x, y), fill=(160, 90, 30, 255))


def _guarana(d):
    d.rounded_rectangle((130, 150, 254, 360), 30, fill=(40, 110, 50, 255))
    d.polygon([(140, 160), (244, 160), (216, 70), (168, 70)], fill=(40, 110, 50, 255))
    d.rectangle((170, 30, 214, 76), fill=(210, 190, 60, 255))
    d.rectangle((130, 210, 254, 300), fill=(240, 220, 60, 255))
    d.ellipse((168, 230, 216, 280), fill=(200, 40, 30, 255))
    d.rectangle((140, 160, 156, 350), fill=(90, 170, 100, 255))


def _torresmo(d):
    for cx, cy in ((140, 200), (240, 170), (200, 270)):
        d.rounded_rectangle((cx - 80, cy - 40, cx + 80, cy + 40), 20, fill=(214, 160, 80, 255))
        d.rectangle((cx - 80, cy - 40, cx + 80, cy - 16), fill=(170, 100, 40, 255))
        for k in range(8):
            d.ellipse((cx - 70 + k * 18, cy - 10, cx - 58 + k * 18, cy + 2), fill=(240, 200, 130, 255))


def _rapadura(d):
    d.polygon([(70, 180), (250, 110), (330, 190), (150, 270)], fill=(150, 90, 40, 255))
    d.polygon([(70, 180), (150, 270), (150, 320), (70, 230)], fill=(110, 64, 28, 255))
    d.polygon([(150, 270), (330, 190), (330, 240), (150, 320)], fill=(128, 76, 34, 255))
    d.polygon([(120, 170), (240, 126), (270, 150), (150, 196)], fill=(236, 226, 196, 255))


ITENS = {"pao_de_queijo": _pao_de_queijo, "cafe": _cafe, "coxinha": _coxinha,
         "guarana": _guarana, "torresmo": _torresmo, "rapadura": _rapadura}


# --- saida --------------------------------------------------------------------

def salvar_par(nome: str, im: Image.Image) -> None:
    """HD em textures_hd (mesmo nome: o conjunto HD vai pelo nome do arquivo)
    e o PS1 em 256 px, quantizado. RGBA: o alfa vira tesoura (0 ou 255)."""
    TEXTURAS_HD.mkdir(parents=True, exist_ok=True)
    im.save(TEXTURAS_HD / f"{nome}.png", "PNG", optimize=True)
    ps1 = im.resize((256, 256), Image.LANCZOS)
    if ps1.mode == "RGBA":
        alfa = ps1.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
        rgb = ps1.convert("RGB").quantize(colors=96, method=Image.MEDIANCUT).convert("RGB")
        ps1 = rgb.convert("RGBA")
        ps1.putalpha(alfa)
    else:
        ps1 = ps1.quantize(colors=96, method=Image.MEDIANCUT)
    ps1.save(TEXTURAS / f"{nome}.png", "PNG", optimize=True)
    print(f"{nome}.png  {im.width}px HD, 256px PS1")


def materiais() -> None:
    for nome, tex, tile, tint, snap, affine in gm.MATERIAIS:
        if not nome.startswith("loja_"):
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
    atlas_produtos()
    atlas_cartazes()
    for nome, f in ITENS.items():
        _icone(nome, f)
    materiais()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

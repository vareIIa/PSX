"""Atlas do andar 10 da estufa: os oito quadros, a chapa do elevador e as placas.

Saida: game/assets/textures/estufa_quadros.png (1024 x 1024, 256 cores).

Os quadros sao pastiche de quadro famoso desenhado aqui, e nao baixado: pastiche
de obra baixada da internet e problema de direito autoral sem necessidade
nenhuma, e a graca esta no desvio, nao na copia. Cada um e pintado a 128 px e
ampliado sem filtro para 256 — o pixel grosso e o do PS1, e nao um defeito.

Mapa do atlas (x, y, largura, altura), o mesmo de EstufaBuilder.rect_*:
  quadros 0..7    (k % 4) * 256, (k / 4) * 256, 256, 256
  andar n 1..10   ((n-1) % 2) * 512, 512 + ((n-1) / 2) * 64, 512, 64
  chapa           0, 832, 256, 192
  placa do quarto 256, 832, 512, 96
  placa da planta 256, 928, 512, 96
  explode / voa   768, 832 / 768, 928, 256, 96

Rodar: python tools/gerar_quadros_maconha.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "textures" / "estufa_quadros.png"
FONTES = Path("C:/Windows/Fonts")

ANDARES = [
    "LAVOURA", "SECAGEM", "MUDA", "MUDA TAMBEM", "MUDA AINDA",
    "NAO SUBIR", "NAO SUBIR (SERIO)", "O ANDAR DO CHEIRO", "???",
    "SO O JOTA E O HELMER",
]


def fonte(nome: str, tam: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTES / nome), tam)


# --- pincel -------------------------------------------------------------------

def pinceladas(img: Image.Image, rng: random.Random, n: int, forca: int,
               comp: int = 3) -> None:
    """Riscos curtos de cor vizinha: e o que separa tela pintada de vetor."""
    px = img.load()
    w, h = img.size
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x, y = rng.randrange(w), rng.randrange(h)
        r, g, b = px[x, y][:3]
        k = rng.randint(-forca, forca)
        cor = (max(0, min(255, r + k)), max(0, min(255, g + k)),
               max(0, min(255, b + k)))
        a = rng.uniform(0, math.pi)
        d.line([(x, y), (x + math.cos(a) * comp, y + math.sin(a) * comp)],
               fill=cor, width=1)


def folha(d: ImageDraw.ImageDraw, cx: float, cy: float, tam: float,
          cor, contorno=None, giro: float = 0.0, cabo: bool = True) -> None:
    """A folha de sete pontas, serrilhada. `cy` e a base dos foliolos."""
    angulos = [0, 26, -26, 55, -55, 88, -88]
    comps = [1.0, 0.9, 0.9, 0.7, 0.7, 0.42, 0.42]
    for ang, c in zip(angulos, comps):
        a = math.radians(ang + giro)
        dx, dy = math.sin(a), -math.cos(a)
        nx, ny = -dy, dx
        L = tam * c
        W = tam * 0.075 * (0.7 + 0.3 * c)
        esq, dir_ = [], []
        passos = 13
        for i in range(passos + 1):
            t = i / passos
            larg = math.sin(math.pi * min(1.0, t * 1.15)) * W
            serra = 1.0 if i % 2 == 0 else 0.45
            px = cx + dx * L * t
            py = cy + dy * L * t
            esq.append((px + nx * larg * serra, py + ny * larg * serra))
            dir_.append((px - nx * larg * serra, py - ny * larg * serra))
        pontos = esq + list(reversed(dir_))
        d.polygon(pontos, fill=cor, outline=contorno)
        d.line([(cx, cy), (cx + dx * L * 0.9, cy + dy * L * 0.9)],
               fill=contorno or cor, width=1)
    if cabo:
        a = math.radians(giro)
        d.line([(cx, cy), (cx - math.sin(a) * tam * 0.45,
                           cy + math.cos(a) * tam * 0.45)],
               fill=contorno or cor, width=2)


def gradiente(img: Image.Image, cima, baixo) -> None:
    d = ImageDraw.Draw(img)
    w, h = img.size
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(
            int(cima[i] + (baixo[i] - cima[i]) * t) for i in range(3)))


def vinheta(img: Image.Image, forca: float = 0.45) -> None:
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
            k = 1.0 - forca * min(1.0, (dx * dx + dy * dy) * 0.6)
            r, g, b = px[x, y][:3]
            px[x, y] = (int(r * k), int(g * k), int(b * k))


# --- os oito quadros (128 px) ---------------------------------------------------

def q_folha_dourada(rng):
    img = Image.new("RGB", (128, 128), (158, 18, 24))
    d = ImageDraw.Draw(img)
    for i in range(0, 128, 8):
        d.line([(0, i), (128, i)], fill=(146, 14, 20))
    d.rectangle([5, 5, 122, 122], outline=(214, 170, 52), width=2)
    d.rectangle([9, 9, 118, 118], outline=(120, 12, 16), width=1)
    folha(d, 64, 76, 50, (226, 182, 48), (150, 104, 20))
    for sx, sy in [(20, 22), (108, 22), (20, 106), (108, 106)]:
        d.regular_polygon((sx, sy, 5), 5, fill=(226, 182, 48))
    pinceladas(img, rng, 900, 14)
    vinheta(img, 0.35)
    return img


def q_girassol(rng):
    img = Image.new("RGB", (128, 128))
    gradiente(img, (222, 186, 74), (204, 160, 58))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 92, 128, 128], fill=(196, 120, 46))
    d.line([(0, 92), (128, 92)], fill=(150, 84, 30), width=2)
    # O vaso de barro amarelo, com a faixa azul do original.
    d.polygon([(46, 120), (82, 120), (88, 92), (84, 78), (44, 78), (40, 92)],
              fill=(226, 174, 64), outline=(140, 96, 30))
    d.rectangle([42, 86, 86, 90], fill=(60, 96, 150))
    cabecas = [(40, 38, 13), (80, 30, 15), (62, 56, 12), (98, 58, 11),
               (28, 64, 10)]
    for hx, hy, r in cabecas:
        d.line([(hx, hy), (64 + (hx - 64) * 0.3, 80)], fill=(70, 110, 40),
               width=2)
    for hx, hy, r in cabecas:
        for k in range(14):
            a = k / 14 * math.tau + rng.uniform(-0.1, 0.1)
            px, py = hx + math.cos(a) * r, hy + math.sin(a) * r
            d.ellipse([px - 4, py - 3, px + 4, py + 3],
                      fill=rng.choice([(244, 196, 40), (232, 160, 30),
                                       (250, 210, 70)]))
        d.ellipse([hx - r * 0.72, hy - r * 0.72, hx + r * 0.72, hy + r * 0.72],
                  fill=(96, 66, 30))
        # O miolo do girassol e uma folha: e a piada inteira do quadro.
        folha(d, hx, hy + r * 0.28, r * 0.62, (78, 150, 52), (40, 90, 30),
              cabo=False)
    pinceladas(img, rng, 1600, 22, 4)
    return img


def q_ultima_ceia(rng):
    img = Image.new("RGB", (128, 128), (118, 92, 64))
    d = ImageDraw.Draw(img)
    # A sala em perspectiva, fugindo para a janela do meio.
    d.polygon([(0, 0), (128, 0), (88, 30), (40, 30)], fill=(96, 74, 52))
    d.polygon([(0, 0), (40, 30), (40, 78), (0, 100)], fill=(104, 80, 56))
    d.polygon([(128, 0), (88, 30), (88, 78), (128, 100)], fill=(104, 80, 56))
    d.rectangle([40, 30, 88, 78], fill=(132, 104, 72))
    for jx in (46, 58, 70):
        d.rectangle([jx, 38, jx + 10, 58], fill=(170, 196, 214))
    d.rectangle([56, 36, 72, 60], fill=(196, 214, 226))
    for k, x in enumerate([4, 12, 20, 22]):
        d.rectangle([x, 26 + k * 16, x + 6, 36 + k * 16], fill=(70, 54, 40))
    # Os treze, atras da mesa.
    mantos = [(150, 40, 40), (60, 80, 140), (70, 120, 70), (180, 140, 60),
              (120, 60, 110), (160, 90, 50)]
    for k in range(13):
        x = 8 + k * 9.3
        cor = mantos[(k * 5) % len(mantos)]
        if k == 6:
            cor = (170, 36, 36)
        topo = 66 + (k % 3) * 2 - (4 if k == 6 else 0)
        d.rounded_rectangle([x - 4, topo, x + 4, topo + 22], 3, fill=cor)
        d.ellipse([x - 3, topo - 7, x + 3, topo - 1],
                  fill=(206, 164, 120) if k % 4 else (180, 132, 92))
        d.ellipse([x - 3, topo - 8, x + 3, topo - 4], fill=(70, 46, 26))
    d.polygon([(52, 64), (76, 64), (74, 70), (54, 70)], fill=(52, 78, 150))
    # A mesa comprida e a toalha.
    d.rectangle([2, 86, 126, 96], fill=(232, 226, 210))
    d.rectangle([2, 96, 126, 110], fill=(206, 198, 180))
    for x in range(6, 124, 12):
        d.ellipse([x, 88, x + 5, 91], fill=(180, 170, 150))
    # O baseado no meio da mesa, aceso, e a fumaca subindo em espiral.
    d.line([(58, 89), (70, 87)], fill=(246, 244, 236), width=2)
    d.point((71, 87), fill=(255, 120, 30))
    d.point((72, 86), fill=(255, 200, 60))
    pts = [(72 + math.sin(t * 0.7) * (3 + t * 0.5), 86 - t * 2.2)
           for t in range(14)]
    d.line(pts, fill=(214, 214, 206), width=1)
    pinceladas(img, rng, 1000, 12)
    vinheta(img, 0.4)
    return img


def q_mona_lisa(rng):
    img = Image.new("RGB", (128, 128))
    gradiente(img, (150, 160, 120), (92, 96, 64))
    d = ImageDraw.Draw(img)
    # A paisagem de fundo com a estrada serpenteando.
    d.polygon([(0, 60), (30, 48), (60, 56), (96, 44), (128, 54), (128, 128),
               (0, 128)], fill=(96, 104, 70))
    d.line([(4, 64), (16, 60), (28, 58)], fill=(170, 150, 100), width=1)
    d.line([(100, 58), (112, 60), (124, 57)], fill=(170, 150, 100), width=1)
    # O corpo, o cabelo e o rosto.
    d.polygon([(24, 128), (36, 84), (64, 76), (92, 84), (104, 128)],
              fill=(52, 40, 28))
    d.polygon([(46, 88), (64, 82), (82, 88), (74, 100), (54, 100)],
              fill=(186, 146, 100))
    d.ellipse([40, 22, 88, 90], fill=(58, 40, 24))
    d.ellipse([48, 30, 80, 76], fill=(206, 164, 112))
    # Os olhos vermelhos: o branco inteiro tomado, a pupila pequena.
    for ex in (56, 72):
        d.ellipse([ex - 5, 46, ex + 5, 52], fill=(214, 56, 50))
        d.ellipse([ex - 2, 47, ex + 1, 51], fill=(40, 24, 16))
        d.line([(ex - 6, 45), (ex + 5, 44)], fill=(150, 108, 70))
    d.line([(64, 52), (62, 62)], fill=(170, 128, 88))
    d.arc([56, 60, 72, 70], 20, 160, fill=(140, 80, 60), width=1)
    # As maos cruzadas.
    d.ellipse([46, 108, 66, 118], fill=(206, 164, 112))
    d.ellipse([60, 106, 82, 116], fill=(214, 172, 120))
    pinceladas(img, rng, 1100, 10)
    vinheta(img, 0.5)
    return img


def q_general_jota(rng):
    img = Image.new("RGB", (128, 128))
    gradiente(img, (40, 58, 44), (18, 26, 20))
    d = ImageDraw.Draw(img)
    # A farda.
    d.polygon([(10, 128), (22, 88), (50, 78), (78, 78), (106, 88), (118, 128)],
              fill=(76, 86, 48))
    d.polygon([(54, 80), (64, 102), (74, 80)], fill=(222, 218, 200))
    d.line([(64, 84), (64, 102)], fill=(120, 30, 30), width=3)
    for ex in (22, 94):
        d.rectangle([ex, 84, ex + 14, 90], fill=(214, 170, 52))
        for k in range(4):
            d.line([(ex + 2 + k * 3, 90), (ex + 2 + k * 3, 95)],
                   fill=(214, 170, 52))
    # As medalhas: fileira de fita colorida e, no meio, a folha de ouro.
    cores = [(190, 40, 40), (40, 90, 170), (230, 200, 60), (40, 140, 70),
             (230, 230, 230)]
    for fila in range(3):
        for k in range(4):
            x, y = 26 + k * 7, 100 + fila * 6
            d.rectangle([x, y, x + 5, y + 3], fill=cores[(k + fila) % 5])
    folha(d, 88, 110, 9, (226, 182, 48), (150, 104, 20))
    # O rosto, o bigode e o oculos de aviador.
    d.rectangle([56, 64, 72, 80], fill=(176, 126, 84))
    d.ellipse([46, 30, 82, 72], fill=(188, 136, 92))
    d.ellipse([50, 44, 62, 52], fill=(30, 30, 34))
    d.ellipse([66, 44, 78, 52], fill=(30, 30, 34))
    d.line([(62, 47), (66, 47)], fill=(200, 180, 90))
    d.point((53, 46), fill=(160, 180, 200))
    d.point((69, 46), fill=(160, 180, 200))
    d.polygon([(54, 60), (64, 57), (74, 60), (72, 63), (64, 61), (56, 63)],
              fill=(40, 28, 20))
    # O quepe.
    d.ellipse([42, 22, 86, 38], fill=(70, 80, 44))
    d.rectangle([46, 32, 82, 38], fill=(30, 30, 26))
    d.rectangle([46, 30, 82, 32], fill=(214, 170, 52))
    folha(d, 64, 29, 5, (226, 182, 48), None, cabo=False)
    pinceladas(img, rng, 1100, 12)
    vinheta(img, 0.45)
    return img


def q_gato(rng):
    img = Image.new("RGB", (128, 128))
    gradiente(img, (46, 36, 90), (20, 18, 44))
    d = ImageDraw.Draw(img)
    pelo, escuro = (216, 136, 60), (150, 84, 34)
    d.polygon([(28, 44), (36, 10), (56, 34)], fill=pelo)
    d.polygon([(100, 44), (92, 10), (72, 34)], fill=pelo)
    d.polygon([(34, 38), (38, 20), (50, 34)], fill=(230, 160, 150))
    d.polygon([(94, 38), (90, 20), (78, 34)], fill=(230, 160, 150))
    d.ellipse([20, 26, 108, 112], fill=pelo)
    for k in range(4):
        d.line([(52 + k * 8, 30), (54 + k * 8, 44)], fill=escuro, width=2)
    d.ellipse([46, 70, 82, 104], fill=(240, 222, 196))
    # Um olho fechado, piscando...
    d.arc([36, 54, 58, 66], 200, 340, fill=(40, 24, 16), width=2)
    # ...e o outro aberto, verde, com a pupila em fenda.
    d.ellipse([70, 50, 92, 68], fill=(150, 214, 60))
    d.ellipse([79, 51, 83, 67], fill=(16, 16, 16))
    d.point((86, 55), fill=(255, 255, 255))
    d.polygon([(60, 76), (68, 76), (64, 81)], fill=(210, 110, 110))
    d.arc([54, 78, 64, 88], 0, 150, fill=(60, 36, 24))
    d.arc([64, 78, 74, 88], 30, 180, fill=(60, 36, 24))
    for s in (-1, 1):
        for k in range(3):
            d.line([(64 + s * 12, 82 + k * 3), (64 + s * 44, 76 + k * 7)],
                   fill=(250, 246, 236))
    pinceladas(img, rng, 900, 12)
    vinheta(img, 0.4)
    return img


def q_dedo_de_deus(rng):
    img = Image.new("RGB", (128, 128))
    gradiente(img, (150, 176, 196), (208, 204, 184))
    d = ImageDraw.Draw(img)
    for cx, cy, r in [(96, 20, 22), (116, 36, 18), (80, 30, 16), (20, 100, 24)]:
        d.ellipse([cx - r, cy - r * 0.6, cx + r, cy + r * 0.6],
                  fill=(226, 222, 212))
    pele = (214, 170, 124)
    # O braco de Adao, de baixo, com o dedo mole e um baseado na mao.
    d.polygon([(0, 104), (0, 88), (40, 74), (54, 72), (56, 78), (42, 84),
               (0, 104)], fill=pele)
    d.line([(54, 74), (62, 76)], fill=pele, width=3)
    d.line([(48, 80), (60, 70)], fill=(246, 244, 236), width=2)
    # O braco de Deus, de cima, de manga rosa, e o isqueiro na ponta do dedo.
    d.polygon([(128, 28), (128, 52), (96, 62), (80, 62), (80, 54), (100, 44)],
              fill=(200, 140, 150))
    d.polygon([(84, 56), (70, 62), (70, 66), (86, 62)], fill=pele)
    d.rectangle([62, 58, 70, 72], fill=(200, 40, 40))
    d.rectangle([62, 56, 70, 59], fill=(180, 180, 186))
    # A chama, no espaco entre os dois dedos, onde o original tinha o vazio.
    d.polygon([(64, 56), (66, 44), (70, 56)], fill=(252, 196, 50))
    d.polygon([(65, 56), (66, 49), (68, 56)], fill=(255, 250, 200))
    pinceladas(img, rng, 1000, 10)
    vinheta(img, 0.3)
    return img


def q_nota_fiscal(rng):
    # A nota e pintada a 256 direto: e o unico quadro que e texto.
    img = Image.new("RGB", (256, 256), (92, 24, 30))
    d = ImageDraw.Draw(img)
    d.rectangle([28, 16, 228, 240], fill=(220, 214, 196))
    d.rectangle([40, 24, 216, 232], fill=(246, 242, 230))
    for x in range(40, 216, 8):
        d.polygon([(x, 232), (x + 4, 238), (x + 8, 232)], fill=(246, 242, 230))
    f = fonte("consolab.ttf", 12)
    fp = fonte("consola.ttf", 10)
    d.fontmode = "1"
    linhas = [
        ("CUPOM FISCAL", f), ("AGRO-PET DO BAIRRO", fp), ("-" * 28, fp),
        ("TERRA ADUBADA 50KG   89,90", fp), ("LAMPADA 600W x8     640,00", fp),
        ("VASO 200L             72,00", fp), ("TALHA DE CORRENTE   310,00", fp),
        ("ANDAIME (USADO)     150,00", fp), ("GATO (EMPRESTADO)     0,00", fp),
        ("-" * 28, fp), ("TOTAL R$        1261,90", f),
        ("", fp), ("CPF NA NOTA? NAO", fp), ("OBRIGADO, VOLTE", fp),
        ("SEMPRE (VOLTA)", fp),
    ]
    y = 34
    for texto, fnt in linhas:
        d.text((46, y), texto, font=fnt, fill=(40, 40, 44))
        y += 13
    # O carimbo de PAGO, torto, por cima.
    carimbo = Image.new("RGBA", (120, 44), (0, 0, 0, 0))
    dc = ImageDraw.Draw(carimbo)
    dc.fontmode = "1"
    dc.rectangle([2, 2, 117, 41], outline=(190, 30, 30, 230), width=3)
    dc.text((14, 4), "PAGO", font=fonte("impact.ttf", 32),
            fill=(190, 30, 30, 230))
    carimbo = carimbo.rotate(14, expand=True)
    img.paste(carimbo, (104, 150), carimbo)
    return img


QUADROS = [q_folha_dourada, q_girassol, q_ultima_ceia, q_mona_lisa,
           q_general_jota, q_gato, q_dedo_de_deus, q_nota_fiscal]


# --- placas ---------------------------------------------------------------------

def placa_andar(n: int) -> Image.Image:
    """Tinta amarela sobre tabua escura, pincel largo: placa de obra."""
    img = Image.new("RGB", (512, 64), (44, 42, 38))
    d = ImageDraw.Draw(img)
    rng = random.Random(900 + n)
    for y in range(0, 64, 3):
        d.line([(0, y), (512, y)], fill=(40 + rng.randint(-4, 4),) * 3)
    d.rectangle([0, 0, 511, 63], outline=(26, 24, 22), width=3)
    d.fontmode = "1"
    cor = (236, 196, 40) if n not in (6, 7) else (226, 64, 44)
    d.text((18, 6), f"{n}", font=fonte("impact.ttf", 50), fill=cor)
    d.text((96, 10), ANDARES[n - 1], font=fonte("impact.ttf", 40), fill=cor)
    pinceladas(img, rng, 600, 18, 2)
    return img


def chapa() -> Image.Image:
    img = Image.new("RGB", (256, 192), (196, 198, 196))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 255, 191], outline=(110, 112, 110), width=4)
    for cx, cy in [(8, 8), (247, 8), (8, 183), (247, 183)]:
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(120, 122, 120))
    d.fontmode = "1"
    f = fonte("consolab.ttf", 14)
    for k, nome in enumerate(ANDARES):
        n = k + 1
        y = 12 + k * 17
        cor = (30, 30, 34) if n in (1, 10) else (150, 40, 36)
        d.text((14, y), f"{n:>2}", font=f, fill=cor)
        d.text((44, y), nome, font=f, fill=cor)
    return img


def placa_texto(tam, fundo, texto, cor, fnt, borda) -> Image.Image:
    img = Image.new("RGB", tam, fundo)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, tam[0] - 1, tam[1] - 1], outline=borda, width=4)
    d.fontmode = "1"
    caixa = d.multiline_textbbox((0, 0), texto, font=fnt, align="center",
                                 spacing=2)
    w, h = caixa[2] - caixa[0], caixa[3] - caixa[1]
    d.multiline_text(((tam[0] - w) / 2 - caixa[0], (tam[1] - h) / 2 - caixa[1]),
                     texto, font=fnt, fill=cor, align="center", spacing=2)
    return img


def main() -> int:
    atlas = Image.new("RGB", (1024, 1024), (0, 0, 0))
    for k, pintar in enumerate(QUADROS):
        q = pintar(random.Random(0x0CA7 + k * 31))
        if q.size != (256, 256):
            q = q.resize((256, 256), Image.NEAREST)
        atlas.paste(q, ((k % 4) * 256, (k // 4) * 256))
    for n in range(1, 11):
        atlas.paste(placa_andar(n), (((n - 1) % 2) * 512,
                                     512 + ((n - 1) // 2) * 64))
    atlas.paste(chapa(), (0, 832))
    atlas.paste(placa_texto((512, 96), (40, 22, 52), "SUPER QUARTO\nDA MACONHA",
                            (120, 230, 90), fonte("impact.ttf", 38),
                            (190, 150, 40)), (256, 832))
    atlas.paste(placa_texto((512, 96), (236, 232, 220),
                            "NAO ENCOSTA NA PLANTA.\nELA LEMBRA.",
                            (160, 30, 30), fonte("impact.ttf", 34),
                            (160, 30, 30)), (256, 928))
    atlas.paste(placa_texto((256, 96), (236, 232, 220), "EXPLODE",
                            (200, 40, 30), fonte("impact.ttf", 46),
                            (200, 40, 30)), (768, 832))
    atlas.paste(placa_texto((256, 96), (236, 232, 220), "VOA",
                            (40, 90, 190), fonte("impact.ttf", 58),
                            (40, 90, 190)), (768, 928))
    # 256 cores, como toda textura do jogo.
    atlas = atlas.quantize(colors=256, method=Image.Quantize.MEDIANCUT,
                           dither=Image.Dither.NONE).convert("RGB")
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(SAIDA)
    print(f"{SAIDA.relative_to(RAIZ)}  {atlas.size[0]}x{atlas.size[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

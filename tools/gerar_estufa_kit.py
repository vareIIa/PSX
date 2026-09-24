#!/usr/bin/env python3
"""Atlas do kit de objetos da estufa (KitEstufa): folha, flor, terra, feltro e rotulos.

    python tools/gerar_estufa_kit.py              grava os dois atlas
    python tools/gerar_estufa_kit.py --previa=DIR e uma folha de contato ampliada

Saidas:
    game/assets/textures/estufa_kit.png       512 px, 256 cores, alfa binario (PS1 STYLE)
    game/assets/textures_hd/estufa_kit.png    2048 px, alfa de cobertura (MODERNO)

O MESMO desenho nos dois: tudo e pintado a 2048 (em 2x e reduzido, para a borda
da folha sair com meio-tom) e o de 512 sai dele. A UV do KitEstufa e uma so para
os dois estilos, e por isso o mapa abaixo e contrato: `KitEstufa.R_*` tem os
mesmos retangulos, em pixel do atlas de 512.

Por que um atlas proprio, e nao celulas no casa_atlas
-----------------------------------------------------
A celula da casa tem 32 px. Um foliolo de maconha tem de mostrar o serrilhado,
que e a assinatura da folha inteira: sao uns vinte dentes por lado, e em 32 px
cada dente seria meio pixel. Aqui o foliolo tem 48 x 192 (192 x 768 no HD), e o
dente tem 8 px — o bastante para a silhueta ler serrilhada a um metro.

A flor e o mesmo raciocinio: o que faz um botao de maconha ler como botao e o
pelo laranja (pistilo) e a geada branca (tricoma) por cima de calices verdes.
Nada disso cabe numa celula de 32 px.

Alfa
----
Folha, foliolo de flor, cotiledone, folha seca e o tufo de pistilo tem alfa: sao
cartao recortado (material `estufa_kit_folha`). O resto e opaco. O fundo
transparente de cada celula de recorte recebe a cor da propria folha por
dilatacao antes da reducao — sem isso o mipmap do HD mistura preto na borda e a
folha ganha contorno escuro.

Mapa do atlas (x, y, largura, altura), em pixel do atlas de 512:
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
SAIDA_PS1 = RAIZ / "game" / "assets" / "textures" / "estufa_kit.png"
SAIDA_HD = RAIZ / "game" / "assets" / "textures_hd" / "estufa_kit.png"
FONTES = Path("C:/Windows/Fonts")

BASE = 512
HD = 2048
K = HD // BASE          # 4
SS = 2                  # superamostragem do desenho

# Mesmo mapa de KitEstufa.R_*. Mudar aqui e la juntos.
REG: dict[str, tuple[int, int, int, int]] = {
    "foliolo":      (0, 0, 48, 192),
    "acucar":       (48, 0, 48, 128),
    "cotiledone":   (48, 128, 48, 64),
    "caule":        (96, 0, 32, 128),
    "semente":      (96, 128, 32, 32),
    "etiqueta":     (96, 160, 32, 32),
    "bud":          (128, 0, 128, 128),
    "terra":        (256, 0, 128, 128),
    "feltro":       (384, 0, 128, 128),
    "rotulo0":      (128, 128, 128, 64),
    "rotulo1":      (256, 128, 128, 64),
    "rotulo2":      (384, 128, 128, 64),
    "rotulo3":      (0, 192, 128, 64),
    "tampa":        (128, 192, 64, 48),
    "serrilha":     (128, 240, 64, 16),
    "metal":        (192, 192, 64, 64),
    "plastico":     (256, 192, 64, 64),
    "saco":         (320, 192, 64, 64),
    "crivo":        (384, 192, 64, 64),
    "madeira":      (448, 192, 64, 64),
    "rotulo_terra": (0, 256, 128, 192),
    "envelope0":    (128, 256, 64, 96),
    "envelope1":    (192, 256, 64, 96),
    "envelope2":    (256, 256, 64, 96),
    "envelope3":    (320, 256, 64, 96),
    "caixa_dentro": (384, 256, 128, 64),
    "lcd":          (384, 320, 64, 32),
    "painel":       (448, 320, 64, 64),
    "tanque":       (384, 352, 64, 64),
    "pistilo":      (128, 352, 64, 64),
    "seco":         (192, 352, 48, 160),
    "zip":          (0, 448, 64, 16),
}

# As celulas das variedades do poco (KitEstufa.variedade), no espaco que sobrava.
# Ficam num mapa a parte porque o PS1 delas e reduzido a 256 cores SEPARADO:
# a paleta do atlas antigo sai identica, pixel por pixel, e nada do que ja
# estava desenhado muda de cor por causa de um roxo novo na folha.
REG_VARIEDADES: dict[str, tuple[int, int, int, int]] = {
    "foliolo_roxo": (240, 352, 48, 160),
    "bud_brilho":   (288, 352, 96, 96),
    "ceramica":     (288, 448, 64, 64),
    "casca":        (352, 448, 32, 64),
}

# As celulas recortadas: alfa binario no PS1, dilatacao de cor no fundo.
RECORTADAS = {"foliolo", "acucar", "cotiledone", "pistilo", "seco", "foliolo_roxo"}

# A geometria do foliolo no KitEstufa e um losango: base em v = 1, a linha larga
# em v = 1 - T_LARGO e a ponta em v = 0. O desenho tem de caber DENTRO dele, e
# e por isso que a folha sai com a base em cunha, que e o que ela tem de verdade.
T_LARGO = 0.42


def fonte(nome: str, tam: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(str(FONTES / nome), tam)
    except OSError:
        return ImageFont.load_default()


# --- ruido ------------------------------------------------------------------

def ruido(w: int, h: int, rng: np.random.Generator, celula: int,
          oitavas: int = 4) -> np.ndarray:
    """Ruido de valor que FECHA nas bordas (0..1). Cada oitava e uma grade
    aleatoria pequena ampliada em bicubico sobre ela mesma repetida 3x3 — o
    centro da ampliacao continua na vizinha, e a textura repete sem costura."""
    total = np.zeros((h, w), np.float32)
    peso = 0.0
    amp = 1.0
    c = celula
    for _ in range(oitavas):
        gx = max(1, w // c)
        gy = max(1, h // c)
        g = rng.random((gy, gx)).astype(np.float32)
        t = np.tile(g, (3, 3))
        img = Image.fromarray((t * 255).astype(np.uint8), "L")
        img = img.resize((w * 3, h * 3), Image.BICUBIC)
        a = np.asarray(img, np.float32)[h:2 * h, w:2 * w] / 255.0
        total += a * amp
        peso += amp
        amp *= 0.5
        c = max(2, c // 2)
    return total / peso


def cor_ruido(base: tuple[int, int, int], n: np.ndarray, forca: float) -> np.ndarray:
    """Cor de base modulada pelo ruido, em float 0..255 (h, w, 3)."""
    b = np.array(base, np.float32)[None, None, :]
    return np.clip(b * (1.0 + (n[..., None] - 0.5) * 2.0 * forca), 0, 255)


def para_img(rgb: np.ndarray) -> Image.Image:
    """Imagem RGB, e nao RGBA: o ImageDraw em modo "RGBA" sobre uma imagem RGBA
    mistura tambem o ALFA do destino, e todo traco semitransparente abria um
    buraco na textura opaca (a terra saiu furada na primeira previa)."""
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def envolto(d: ImageDraw.ImageDraw, w: int, h: int, desenhar) -> None:
    """Desenha a mesma coisa nas oito vizinhas: e o que faz o traco que cruza a
    borda continuar do outro lado, e a textura repetir sem costura."""
    for dx in (-w, 0, w):
        for dy in (-h, 0, h):
            desenhar(d, dx, dy)


# --- folha ------------------------------------------------------------------

def _meia_largura(t: float) -> float:
    """Meia largura do foliolo (0..1 da meia celula) ao longo do comprimento.

    Largo a 40% do pe, ponta longa e fina (acuminada), e a base em cunha. O
    teto e o losango da geometria (ver T_LARGO), com 4% de folga."""
    if t <= 0.0 or t >= 1.0:
        return 0.0
    natural = math.sin(math.pi * t ** 0.756) ** 1.25
    if t > 0.75:
        natural *= 1.0 - 0.25 * ((t - 0.75) / 0.25)
    if t < T_LARGO:
        losango = t / T_LARGO
    else:
        losango = (1.0 - t) / (1.0 - T_LARGO)
    return min(natural * 0.92, losango * 0.96)


def _contorno_foliolo(w: int, h: int, dentes: int, fundo: float,
                      rng: random.Random, torto: float = 0.0) -> list[tuple[float, float]]:
    """Poligono do foliolo serrilhado. O dente aponta para a PONTA da folha: a
    borda cresce devagar ate o bico e cai de uma vez, que e como a serra da
    maconha e desenhada (e o que a separa de folha de urtiga ou de hortela)."""
    cx = w * 0.5
    meia = w * 0.5
    passos = 900
    esq: list[tuple[float, float]] = []
    dir_: list[tuple[float, float]] = []
    fase_e = rng.random()
    fase_d = rng.random()
    for k in range(passos + 1):
        t = k / passos
        y = h * (1.0 - t) * 0.985 + h * 0.008
        base = _meia_largura(t)
        serra = 1.0
        if 0.06 < t < 0.965:
            env = min(1.0, (t - 0.06) / 0.1) * min(1.0, (0.965 - t) / 0.08)
            for lado, fase in ((0, fase_e), (1, fase_d)):
                s = t * dentes + fase
                f = s - math.floor(s)
                v = 1.0 - fundo * env * (1.0 - f ** 1.7)
                if lado == 0:
                    serra_e = v
                else:
                    serra_d = v
        else:
            serra_e = serra_d = serra
        curva = torto * math.sin(math.pi * t) * w * 0.08
        esq.append((cx + curva - meia * base * serra_e, y))
        dir_.append((cx + curva + meia * base * serra_d, y))
    return esq + dir_[::-1]


def desenhar_foliolo(w: int, h: int, seed: int, cor: tuple[int, int, int],
                     nervura: tuple[int, int, int], geada: float = 0.0,
                     dentes: int = 22, fundo: float = 0.2,
                     seco: bool = False) -> Image.Image:
    """Um foliolo inteiro, com nervura central, nervuras secundarias indo para
    cada dente, borda mais escura e o pe mais claro."""
    rng = random.Random(seed)
    nrng = np.random.default_rng(seed)
    W, H = w * SS, h * SS
    pts = _contorno_foliolo(W, H, dentes, fundo, rng, torto=0.35 if seco else 0.0)
    mascara = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mascara).polygon(pts, fill=255)

    # Superficie: cor com ruido fino e um gradiente do pe (claro) para a ponta.
    n = ruido(W, H, nrng, max(8, W // 6), 4)
    rgb = cor_ruido(cor, n, 0.10)
    ys = np.linspace(0.0, 1.0, H, dtype=np.float32)[:, None]   # 0 no topo (ponta)
    xs = np.abs(np.linspace(-1.0, 1.0, W, dtype=np.float32))[None, :]
    rgb *= (0.92 + 0.10 * ys)[..., None]
    # A borda escurece: a folha e mais fina e mais cheia de clorofila la.
    borda = np.asarray(mascara.filter(ImageFilter.GaussianBlur(W * 0.09)), np.float32) / 255.0
    rgb *= (0.78 + 0.22 * np.clip(borda * 1.6, 0, 1))[..., None]
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")

    cx = W * 0.5
    topo = H * 0.02
    pe = H * 0.99
    # Nervuras secundarias: saem da central em angulo agudo, em direcao a cada
    # dente, e somem antes da borda.
    for k in range(dentes):
        for lado in (-1, 1):
            t = (k + 0.3 + rng.random() * 0.3) / dentes
            if t < 0.06 or t > 0.93:
                continue
            y0 = pe - (pe - topo) * t
            larg = _meia_largura(min(0.99, t + 0.06)) * W * 0.5
            x1 = cx + lado * larg * 0.86
            y1 = y0 - H * 0.055
            a = int(70 if not seco else 45)
            d.line([(cx, y0), (x1, y1)], fill=nervura + (a,), width=max(1, SS))
    # Nervura central, grossa no pe e fina na ponta.
    for k in range(40):
        t0 = k / 40
        t1 = (k + 1) / 40
        larg = max(1, int(round((5.5 - 4.5 * t0) * SS * w / 48)))
        d.line([(cx, pe - (pe - topo) * t0), (cx, pe - (pe - topo) * t1)],
               fill=nervura + (220,), width=larg)
    if seco:
        # Folha seca: manchas de marrom e a borda enrolada, mais escura.
        for _ in range(40):
            x = rng.uniform(W * 0.25, W * 0.75)
            y = rng.uniform(H * 0.1, H * 0.9)
            r = rng.uniform(W * 0.02, W * 0.07)
            d.ellipse([x - r, y - r * 1.8, x + r, y + r * 1.8],
                      fill=(110, 84, 40, rng.randint(30, 80)))
    if geada > 0.0:
        # Tricomas: pontos brancos cobrindo a folha de acucar, mais densos no
        # pe (que fica colado na flor).
        qtd = int(W * H * 0.018 * geada)
        for _ in range(qtd):
            x = rng.uniform(0, W)
            y = rng.uniform(0, H)
            t = 1.0 - y / H
            if rng.random() > 1.1 - t * 0.9:
                continue
            r = rng.choice((0.8, 1.0, 1.0, 1.4, 2.0)) * SS * 0.7
            a = rng.randint(150, 250)
            d.ellipse([x - r, y - r, x + r, y + r], fill=(238, 242, 226, a))

    img.putalpha(mascara)
    return img.resize((w, h), Image.LANCZOS)


def desenhar_cotiledone(w: int, h: int, seed: int) -> Image.Image:
    """Folha de semente: oval, lisa, sem serra, verde-clara."""
    W, H = w * SS, h * SS
    nrng = np.random.default_rng(seed)
    mascara = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mascara)
    pts = []
    for k in range(200):
        t = k / 199
        y = H * (0.98 - 0.96 * t)
        lw = math.sin(math.pi * t) ** 0.7 * (0.9 if t > 0.5 else 0.8 + 0.1 * t / 0.5)
        pts.append((W * 0.5 - W * 0.47 * lw, y))
    pts += [(W - x, y) for (x, y) in reversed(pts)]
    md.polygon(pts, fill=255)
    n = ruido(W, H, nrng, W // 4, 3)
    rgb = cor_ruido((120, 176, 70), n, 0.08)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    d.line([(W * 0.5, H * 0.97), (W * 0.5, H * 0.1)], fill=(170, 210, 120, 160), width=SS * 2)
    img.putalpha(mascara)
    return img.resize((w, h), Image.LANCZOS)


# --- flor -------------------------------------------------------------------

def _mesma_cor(c: tuple[int, int, int]) -> tuple[int, int, int]:
    return c


def desenhar_bud(w: int, h: int, seed: int, base: tuple[int, int, int] = (44, 70, 30),
                 tinge=_mesma_cor,
                 cores_pistilo: list | None = None) -> Image.Image:
    """A superficie de uma flor de maconha, repetivel nos dois eixos.

    Tres camadas, na ordem em que o olho as separa a um metro:
      calices   gotas verdes sobrepostas, cada uma com luz em cima e sombra
                embaixo — e o que faz o botao ter volume e nao ser uma bola lisa
      pistilos  pelos curvos laranja, ferrugem e creme saindo entre os calices
      tricomas  geada branca por cima de tudo, que e o que faz a erva "brilhar"
    """
    rng = random.Random(seed)
    nrng = np.random.default_rng(seed)
    W, H = w * SS, h * SS
    n = ruido(W, H, nrng, W // 6, 4)
    rgb = cor_ruido(base, n, 0.25)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")

    # Calices, em quatro passadas do fundo para a frente: os de tras mais
    # escuros, que e a oclusao entre eles.
    for passada in range(4):
        qtd = int(W * H / (SS * SS) * 0.0011)
        luz = 0.62 + passada * 0.13
        for _ in range(qtd):
            x = rng.uniform(0, W)
            y = rng.uniform(0, H)
            comp = rng.uniform(16, 30) * SS * K / 4
            larg = comp * rng.uniform(0.5, 0.72)
            ang = rng.uniform(-0.9, 0.9) - math.pi / 2
            verde = (rng.randint(104, 136), rng.randint(140, 172), rng.randint(62, 84))
            if rng.random() < 0.12:
                verde = (rng.randint(118, 150), rng.randint(128, 150), rng.randint(70, 90))
            verde = tinge(verde)

            def gota(dd: ImageDraw.ImageDraw, dx: float, dy: float,
                     x=x, y=y, comp=comp, larg=larg, ang=ang, verde=verde, luz=luz) -> None:
                ca, sa = math.cos(ang), math.sin(ang)
                pts = []
                for k in range(16):
                    t = k / 16 * math.tau
                    px = math.cos(t) * comp * 0.5
                    py = math.sin(t) * larg * 0.5 * (1.0 - 0.35 * max(0.0, math.cos(t)))
                    pts.append((x + dx + px * ca - py * sa, y + dy + px * sa + py * ca))
                sombra = tuple(int(c * luz * 0.55) for c in verde)
                dd.polygon([(p[0] + SS, p[1] + SS * 1.5) for p in pts], fill=sombra + (150,))
                dd.polygon(pts, fill=tuple(int(c * luz) for c in verde) + (255,))
                # Brilho do calice: uma gota menor e mais clara deslocada para
                # a ponta e para cima.
                bx = x + dx + ca * comp * 0.14 - SS * 0.8
                by = y + dy + sa * comp * 0.14 - SS * 0.8
                r = larg * 0.22
                claro = tuple(min(255, int(c * luz * 1.28 + 18)) for c in verde)
                dd.ellipse([bx - r, by - r, bx + r, by + r], fill=claro + (170,))
            envolto(d, W, H, gota)

    # Pistilos: pelos curvos. Maioria laranja, parte ferrugem (os mais velhos)
    # e parte creme (os novos). Espessura de dois pixels no HD.
    cores = [((226, 122, 38), 0.5), ((196, 92, 30), 0.25), ((170, 70, 34), 0.12),
             ((236, 214, 170), 0.13)]
    if cores_pistilo is not None:
        cores = cores_pistilo
    qtd = int(W * H / (SS * SS) * 0.0024)
    for _ in range(qtd):
        r = rng.random()
        acc = 0.0
        cor = cores[0][0]
        for c, p in cores:
            acc += p
            if r <= acc:
                cor = c
                break
        x = rng.uniform(0, W)
        y = rng.uniform(0, H)
        ang = rng.uniform(0, math.tau)
        curva = rng.uniform(-0.28, 0.28)
        passo = rng.uniform(3.0, 4.6) * SS
        pts = [(x, y)]
        for _k in range(rng.randint(5, 9)):
            ang += curva
            x += math.cos(ang) * passo
            y += math.sin(ang) * passo
            pts.append((x, y))
        largura = max(2, int(SS * rng.choice((1.5, 2.0, 2.5))))

        def pelo(dd: ImageDraw.ImageDraw, dx: float, dy: float, pts=pts, cor=cor,
                 largura=largura) -> None:
            q = [(p[0] + dx, p[1] + dy) for p in pts]
            dd.line([(p[0] + SS * 0.6, p[1] + SS * 0.8) for p in q],
                    fill=(40, 30, 14, 90), width=largura)
            dd.line(q, fill=cor + (255,), width=largura)
        envolto(d, W, H, pelo)

    # Tricomas: geada. Muitos pontos pequenos e alguns maiores com nucleo claro
    # (a cabeca da glandula, que e o que reflete a luz da lampada).
    qtd = int(W * H / (SS * SS) * 0.03)
    for _ in range(qtd):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H)
        r = rng.choice((0.6, 0.8, 0.8, 1.0, 1.3)) * SS
        a = rng.randint(110, 230)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(232, 238, 222, a))
    for _ in range(int(W * H / (SS * SS) * 0.004)):
        x = rng.uniform(0, W)
        y = rng.uniform(0, H)
        r = rng.uniform(1.6, 2.4) * SS
        d.ellipse([x - r, y - r, x + r, y + r], fill=(245, 248, 238, 200))
        d.ellipse([x - r * 0.4, y - r * 0.4, x + r * 0.4, y + r * 0.4], fill=(255, 255, 255, 255))
    return img.resize((w, h), Image.LANCZOS)


def desenhar_pistilo(w: int, h: int, seed: int) -> Image.Image:
    """Tufo de pistilos saindo de um ponto: cartao para a ponta da cola."""
    rng = random.Random(seed)
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (210, 110, 40, 0))
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(46):
        x, y = W * 0.5 + rng.uniform(-W * 0.1, W * 0.1), H * 0.96
        ang = -math.pi / 2 + rng.uniform(-0.9, 0.9)
        curva = rng.uniform(-0.09, 0.09)
        comp = rng.uniform(0.35, 0.8) * H
        passos = 14
        pts = [(x, y)]
        for _k in range(passos):
            ang += curva
            x += math.cos(ang) * comp / passos
            y += math.sin(ang) * comp / passos
            pts.append((x, y))
        cor = rng.choice([(228, 126, 40), (228, 126, 40), (200, 94, 32), (238, 218, 176)])
        d.line(pts, fill=cor + (255,), width=max(2, int(SS * 2.2)))
    return img.resize((w, h), Image.LANCZOS)


# --- caule, semente, terra, feltro -----------------------------------------

def desenhar_caule(w: int, h: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    nrng = np.random.default_rng(seed)
    n = ruido(w, h, nrng, max(4, w // 4), 3)
    rgb = cor_ruido((96, 140, 58), n, 0.12)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    # Fibras verticais, claras e escuras: o caule da maconha e canelado.
    for k in range(int(w * 0.6)):
        x = rng.uniform(0, w)
        cor = (150, 190, 100, 90) if rng.random() < 0.5 else (50, 84, 30, 90)
        for dx in (-w, 0, w):
            d.line([(x + dx, 0), (x + dx + rng.uniform(-2, 2), h)], fill=cor, width=max(1, K // 2))
    # Pelinhos claros.
    for _ in range(int(w * h * 0.004)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        d.line([(x, y), (x + rng.uniform(-3, 3), y - rng.uniform(2, 5))], fill=(200, 220, 170, 120))
    return img


def desenhar_semente(w: int, h: int, seed: int) -> Image.Image:
    """Casca de semente: cinza-marrom com a rajada de tigre, repetivel em u."""
    rng = random.Random(seed)
    nrng = np.random.default_rng(seed)
    n = ruido(w, h, nrng, max(4, w // 4), 3)
    rgb = cor_ruido((132, 112, 84), n, 0.16)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(26):
        x = rng.uniform(0, w)
        y = rng.uniform(0, h)
        pts = [(x, y)]
        for _k in range(8):
            x += rng.uniform(-3, 3) * K / 4
            y += rng.uniform(2, 6) * K / 4
            pts.append((x, y))
        cor = (58, 44, 30, rng.randint(150, 230))

        def rajada(dd, dx, dy, pts=pts, cor=cor) -> None:
            dd.line([(p[0] + dx, p[1] + dy) for p in pts], fill=cor, width=max(2, K))
        envolto(d, w, h, rajada)
    # A crista clara da costura.
    d.line([(0, h * 0.5), (w, h * 0.5)], fill=(186, 168, 136, 150), width=max(1, K // 2))
    return img


def desenhar_terra(w: int, h: int, seed: int) -> Image.Image:
    """Substrato: humus escuro, fibra de coco, perlita branca e casca."""
    rng = random.Random(seed)
    nrng = np.random.default_rng(seed)
    n = ruido(w, h, nrng, w // 8, 5)
    rgb = cor_ruido((60, 43, 31), n, 0.42)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    # Torroes: manchas escuras e claras.
    for _ in range(int(w * h * 0.0016)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(3, 12)
        cor = (32, 22, 16, 120) if rng.random() < 0.6 else (96, 70, 48, 110)
        envolto(d, w, h, lambda dd, dx, dy, x=x, y=y, r=r, cor=cor:
                dd.ellipse([x + dx - r, y + dy - r * 0.8, x + dx + r, y + dy + r * 0.8], fill=cor))
    # Fibra de coco.
    for _ in range(int(w * h * 0.0022)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, math.tau)
        c = rng.uniform(6, 18)
        cor = (138, 98, 62, rng.randint(120, 200))
        envolto(d, w, h, lambda dd, dx, dy, x=x, y=y, a=a, c=c, cor=cor:
                dd.line([(x + dx, y + dy), (x + dx + math.cos(a) * c, y + dy + math.sin(a) * c)],
                        fill=cor, width=2))
    # Casca de pinus.
    for _ in range(int(w * h * 0.0004)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(4, 9)
        a = rng.uniform(0, math.tau)
        pts = [(x + math.cos(a + k * 1.7) * r * rng.uniform(0.6, 1.2),
                y + math.sin(a + k * 1.7) * r * rng.uniform(0.6, 1.2)) for k in range(5)]
        cor = (104, 62, 38, 255)
        envolto(d, w, h, lambda dd, dx, dy, pts=pts, cor=cor:
                dd.polygon([(p[0] + dx, p[1] + dy) for p in pts], fill=cor))
    # Perlita: grao branco arredondado com sombra embaixo e brilho em cima.
    for _ in range(int(w * h * 0.0011)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(3, 8) * K / 4

        def perla(dd, dx, dy, x=x, y=y, r=r) -> None:
            dd.ellipse([x + dx - r, y + dy - r * 0.6, x + dx + r * 1.1, y + dy + r * 1.3], fill=(22, 16, 12, 150))
            dd.ellipse([x + dx - r, y + dy - r, x + dx + r, y + dy + r], fill=(206, 204, 196, 255))
            dd.ellipse([x + dx - r * 0.6, y + dy - r * 0.7, x + dx + r * 0.2, y + dy + r * 0.1], fill=(244, 244, 238, 255))
        envolto(d, w, h, perla)
    return img


def desenhar_feltro(w: int, h: int, seed: int) -> Image.Image:
    """Feltro do vaso: carvao com fibra. A faixa de cima (v < 0,12) e a bainha
    costurada da boca, e a geometria da dobra le so ela."""
    rng = random.Random(seed)
    nrng = np.random.default_rng(seed)
    n = ruido(w, h, nrng, w // 8, 5)
    rgb = cor_ruido((58, 58, 60), n, 0.2)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(int(w * h * 0.06)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, math.tau)
        c = rng.uniform(2, 6) * K / 4
        v = rng.randint(30, 92)
        envolto(d, w, h, lambda dd, dx, dy, x=x, y=y, a=a, c=c, v=v:
                dd.line([(x + dx, y + dy), (x + dx + math.cos(a) * c, y + dy + math.sin(a) * c)],
                        fill=(v, v, v + 2, 110)))
    # A bainha: faixa mais escura com a costura tracejada.
    faixa = int(h * 0.12)
    d.rectangle([0, 0, w, faixa], fill=(30, 30, 32, 120))
    y = faixa * 0.55
    passo = w / 16
    for k in range(16):
        x = k * passo
        d.line([(x + passo * 0.15, y), (x + passo * 0.75, y)], fill=(150, 150, 146, 230), width=max(2, K // 2))
    d.line([(0, faixa), (w, faixa)], fill=(22, 22, 24, 200), width=max(2, K // 2))
    return img


def desenhar_etiqueta(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (226, 224, 214, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 2, w - 3, h - 3], outline=(170, 168, 160), width=2)
    f = fonte("arialbd.ttf", int(h * 0.36))
    d.text((w / 2, h * 0.42), "25L", font=f, fill=(40, 90, 50), anchor="mm")
    f2 = fonte("arial.ttf", int(h * 0.16))
    d.text((w / 2, h * 0.75), "FELTRO", font=f2, fill=(60, 60, 60), anchor="mm")
    return img


# --- rotulos ------------------------------------------------------------------

def folha_icone(d: ImageDraw.ImageDraw, cx: float, cy: float, tam: float,
                cor: tuple[int, ...], n: int = 7) -> None:
    """Folha de maconha estilizada: n foliolos em leque, o do meio maior."""
    meio = (n - 1) / 2
    for k in range(n):
        off = k - meio
        ang = -math.pi / 2 + off * (math.pi * 0.62 / meio if meio else 0)
        comp = tam * (1.0 - abs(off) / (meio + 1.2) * 0.75)
        larg = comp * 0.2
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for j in range(24):
            t = j / 23
            lw = math.sin(math.pi * t ** 0.8) * larg * 0.5
            pts.append((cx + ca * comp * t - sa * lw, cy + sa * comp * t + ca * lw))
        for j in range(23, -1, -1):
            t = j / 23
            lw = math.sin(math.pi * t ** 0.8) * larg * 0.5
            pts.append((cx + ca * comp * t + sa * lw, cy + sa * comp * t - ca * lw))
        d.polygon(pts, fill=cor)
    d.line([(cx, cy), (cx, cy + tam * 0.35)], fill=cor, width=max(2, int(tam * 0.05)))


def papel(w: int, h: int, cor: tuple[int, int, int], seed: int, forca: float = 0.06) -> Image.Image:
    n = ruido(w, h, np.random.default_rng(seed), max(4, w // 10), 4)
    return para_img(cor_ruido(cor, n, forca))


def desenhar_rotulo(w: int, h: int, k: int) -> Image.Image:
    """Quatro rotulos de pote. Nomes de linhagem genericos, sem marca nenhuma."""
    if k == 0:
        img = papel(w, h, (236, 228, 204), 11)
        d = ImageDraw.Draw(img)
        d.rectangle([6, 6, w - 7, h - 7], outline=(60, 110, 60), width=5)
        folha_icone(d, w * 0.15, h * 0.52, h * 0.34, (60, 120, 58))
        d.text((w * 0.58, h * 0.36), "Skunk", font=fonte("segoeprb.ttf", int(h * 0.3)),
               fill=(40, 40, 40), anchor="mm")
        d.text((w * 0.58, h * 0.72), "colheita 14/09", font=fonte("segoepr.ttf", int(h * 0.15)),
               fill=(70, 70, 70), anchor="mm")
    elif k == 1:
        img = papel(w, h, (250, 250, 246), 12, 0.03)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, w, int(h * 0.3)], fill=(196, 210, 40))
        d.text((w * 0.5, h * 0.15), "LEMON HAZE", font=fonte("arialbd.ttf", int(h * 0.2)),
               fill=(30, 30, 30), anchor="mm")
        d.text((w * 0.5, h * 0.55), "SATIVA  28 g", font=fonte("bahnschrift.ttf", int(h * 0.2)),
               fill=(40, 40, 40), anchor="mm")
        d.text((w * 0.5, h * 0.83), "lote 07 - estufa", font=fonte("arial.ttf", int(h * 0.13)),
               fill=(90, 90, 90), anchor="mm")
    elif k == 2:
        # Fita crepe escrita a caneta: o rotulo de quem nao tem impressora.
        img = papel(w, h, (222, 204, 150), 13, 0.1)
        d = ImageDraw.Draw(img)
        for x in range(0, w, 6):
            d.line([(x, 0), (x + 3, 5)], fill=(200, 180, 128))
            d.line([(x, h - 1), (x + 3, h - 6)], fill=(200, 180, 128))
        d.text((w * 0.5, h * 0.42), "PURPLE", font=fonte("segoeprb.ttf", int(h * 0.36)),
               fill=(70, 30, 90), anchor="mm")
        d.text((w * 0.5, h * 0.8), "nao mexer!!", font=fonte("segoepr.ttf", int(h * 0.15)),
               fill=(40, 40, 60), anchor="mm")
    else:
        img = papel(w, h, (26, 26, 28), 14, 0.08)
        d = ImageDraw.Draw(img)
        d.rectangle([5, 5, w - 6, h - 6], outline=(200, 170, 80), width=3)
        folha_icone(d, w * 0.18, h * 0.54, h * 0.3, (200, 170, 80))
        d.text((w * 0.6, h * 0.4), "OG", font=fonte("impact.ttf", int(h * 0.36)),
               fill=(236, 230, 214), anchor="mm")
        d.text((w * 0.6, h * 0.76), "INDICA", font=fonte("arialbd.ttf", int(h * 0.15)),
               fill=(200, 170, 80), anchor="mm")
    return img


def desenhar_envelope(w: int, h: int, k: int) -> Image.Image:
    """Pacotinho de semente, de pe na caixa. A aba fica em cima."""
    fundos = [(236, 232, 220), (186, 150, 104), (36, 36, 38), (70, 128, 70)]
    tinta = [(50, 110, 50), (60, 40, 20), (220, 200, 120), (240, 240, 230)]
    nomes = ["AUTO\nSKUNK", "HAZE", "KUSH", "DIESEL"]
    img = papel(w, h, fundos[k], 20 + k, 0.07)
    d = ImageDraw.Draw(img)
    d.line([(0, h * 0.14), (w, h * 0.14)], fill=tuple(int(c * 0.75) for c in fundos[k]), width=3)
    folha_icone(d, w * 0.5, h * 0.42, h * 0.2, tinta[k])
    f = fonte("arialbd.ttf", int(w * 0.17))
    d.multiline_text((w * 0.5, h * 0.66), nomes[k], font=f, fill=tinta[k], anchor="mm",
                     align="center", spacing=2)
    d.text((w * 0.5, h * 0.88), "x5 fem.", font=fonte("arial.ttf", int(w * 0.13)),
           fill=tinta[k], anchor="mm")
    return img


def desenhar_caixa_dentro(w: int, h: int) -> Image.Image:
    img = papel(w, h, (28, 30, 30), 30, 0.08)
    d = ImageDraw.Draw(img)
    d.rectangle([8, 8, w - 9, h - 9], outline=(80, 150, 80), width=4)
    folha_icone(d, w * 0.14, h * 0.55, h * 0.36, (90, 170, 90))
    d.text((w * 0.58, h * 0.4), "SEMENTES", font=fonte("impact.ttf", int(h * 0.3)),
           fill=(226, 226, 214), anchor="mm")
    d.text((w * 0.58, h * 0.74), "banco caseiro - desde 1994", font=fonte("arial.ttf", int(h * 0.12)),
           fill=(140, 190, 140), anchor="mm")
    return img


def desenhar_rotulo_terra(w: int, h: int) -> Image.Image:
    """A cara do saco de substrato: marca inventada, impresso em plastico preto."""
    img = papel(w, h, (24, 24, 26), 40, 0.1)
    d = ImageDraw.Draw(img)
    d.rectangle([0, int(h * 0.1), w, int(h * 0.2)], fill=(58, 140, 60))
    d.text((w * 0.5, h * 0.15), "SUBSTRATO PARA CULTIVO", font=fonte("arialbd.ttf", int(w * 0.07)),
           fill=(240, 240, 230), anchor="mm")
    d.text((w * 0.5, h * 0.3), "TERRA", font=fonte("impact.ttf", int(w * 0.24)),
           fill=(240, 236, 220), anchor="mm")
    d.text((w * 0.5, h * 0.41), "FORTE", font=fonte("impact.ttf", int(w * 0.24)),
           fill=(120, 196, 80), anchor="mm")
    # O brotinho: dois cotiledones num circulo.
    cx, cy, r = w * 0.5, h * 0.6, w * 0.17
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(58, 44, 30), outline=(120, 196, 80), width=6)
    d.rectangle([cx - r, cy + r * 0.3, cx + r, cy + r * 0.32], fill=(90, 66, 44))
    d.line([(cx, cy + r * 0.3), (cx, cy - r * 0.2)], fill=(120, 196, 80), width=8)
    d.ellipse([cx - r * 0.62, cy - r * 0.55, cx - r * 0.02, cy - r * 0.12], fill=(120, 196, 80))
    d.ellipse([cx + r * 0.02, cy - r * 0.55, cx + r * 0.62, cy - r * 0.12], fill=(120, 196, 80))
    d.text((w * 0.5, h * 0.78), "com perlita e humus", font=fonte("arial.ttf", int(w * 0.07)),
           fill=(200, 200, 190), anchor="mm")
    d.rectangle([w * 0.3, h * 0.83, w * 0.7, h * 0.92], fill=(240, 236, 220))
    d.text((w * 0.5, h * 0.875), "50 L", font=fonte("arialbd.ttf", int(w * 0.1)),
           fill=(24, 24, 26), anchor="mm")
    return img


# --- metal, plastico, equipamento -------------------------------------------

def desenhar_metal(w: int, h: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    nrng = np.random.default_rng(seed)
    n = ruido(w, h, nrng, max(4, w // 6), 3)
    rgb = cor_ruido((188, 190, 192), n, 0.06)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(int(h * 3)):
        y = rng.uniform(0, h)
        v = rng.randint(150, 230)
        d.line([(0, y), (w, y + rng.uniform(-1, 1))], fill=(v, v, v + 3, 60))
    return img


def desenhar_plastico(w: int, h: int, seed: int) -> Image.Image:
    n = ruido(w, h, np.random.default_rng(seed), max(4, w // 4), 3)
    rgb = cor_ruido((236, 236, 236), n, 0.04)
    ys = np.linspace(1.04, 0.94, h, dtype=np.float32)[:, None, None]
    return para_img(rgb * ys)


def desenhar_saco(w: int, h: int, seed: int) -> Image.Image:
    """Plastico preto de saco: vincos claros e brilho mole."""
    rng = random.Random(seed)
    n = ruido(w, h, np.random.default_rng(seed), w // 4, 4)
    rgb = cor_ruido((30, 30, 32), n, 0.3)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(18):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, math.tau)
        c = rng.uniform(w * 0.2, w * 0.6)
        v = rng.randint(60, 110)
        envolto(d, w, h, lambda dd, dx, dy, x=x, y=y, a=a, c=c, v=v:
                dd.line([(x + dx, y + dy), (x + dx + math.cos(a) * c, y + dy + math.sin(a) * c)],
                        fill=(v, v, v + 4, 90), width=max(2, K)))
    return img.filter(ImageFilter.GaussianBlur(1.2))


def desenhar_crivo(w: int, h: int) -> Image.Image:
    """A cara do chuveirinho do regador: disco com furos em aneis."""
    img = Image.new("RGBA", (w, h), (208, 210, 206, 255))
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, h / 2
    d.ellipse([cx - w * 0.49, cy - h * 0.49, cx + w * 0.49, cy + h * 0.49], fill=(190, 192, 188),
              outline=(120, 122, 118), width=max(2, K))
    for anel, n in ((0.0, 1), (0.14, 7), (0.26, 13), (0.37, 19)):
        for k in range(n):
            a = k / n * math.tau
            x = cx + math.cos(a) * anel * w
            y = cy + math.sin(a) * anel * h
            r = w * 0.028
            d.ellipse([x - r, y - r, x + r, y + r], fill=(38, 40, 40))
    return img


def desenhar_madeira(w: int, h: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    n = ruido(w, h, np.random.default_rng(seed), max(4, w // 5), 3)
    rgb = cor_ruido((188, 146, 98), n, 0.08)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    for k in range(22):
        y0 = rng.uniform(0, h)
        amp = rng.uniform(1, 4)
        fase = rng.uniform(0, math.tau)
        pts = [(x, y0 + math.sin(x / w * math.tau * 2 + fase) * amp) for x in range(0, w + 1, 4)]
        d.line(pts, fill=(130, 92, 56, rng.randint(60, 140)), width=max(1, K // 2))
    return img


def sete_segmentos(d: ImageDraw.ImageDraw, x: float, y: float, alt: float,
                   digito: str, cor: tuple[int, ...]) -> float:
    """Um digito de visor de LCD desenhado em segmentos. Devolve a largura."""
    larg = alt * 0.5
    e = alt * 0.12
    seg = {
        "a": [(x + e, y), (x + larg - e, y), (x + larg - e * 1.5, y + e), (x + e * 1.5, y + e)],
        "b": [(x + larg, y + e), (x + larg, y + alt / 2 - e * 0.5), (x + larg - e, y + alt / 2 - e), (x + larg - e, y + e * 1.5)],
        "c": [(x + larg, y + alt / 2 + e * 0.5), (x + larg, y + alt - e), (x + larg - e, y + alt - e * 1.5), (x + larg - e, y + alt / 2 + e)],
        "d": [(x + e, y + alt), (x + larg - e, y + alt), (x + larg - e * 1.5, y + alt - e), (x + e * 1.5, y + alt - e)],
        "e": [(x, y + alt / 2 + e * 0.5), (x, y + alt - e), (x + e, y + alt - e * 1.5), (x + e, y + alt / 2 + e)],
        "f": [(x, y + e), (x, y + alt / 2 - e * 0.5), (x + e, y + alt / 2 - e), (x + e, y + e * 1.5)],
        "g": [(x + e, y + alt / 2 - e * 0.5), (x + larg - e, y + alt / 2 - e * 0.5),
              (x + larg - e, y + alt / 2 + e * 0.5), (x + e, y + alt / 2 + e * 0.5)],
    }
    mapa = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
            "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abfgcd"}
    for s in mapa.get(digito, ""):
        d.polygon(seg[s], fill=cor)
    return larg + e * 1.2


def desenhar_lcd(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (18, 18, 20, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([w * 0.05, h * 0.1, w * 0.95, h * 0.9], fill=(70, 150, 214))
    cor = (236, 246, 255)
    alt = h * 0.56
    x = w * 0.16
    y = h * 0.22
    for ch in "28":
        x += sete_segmentos(d, x, y, alt, ch, cor)
    d.rectangle([x, y + alt - alt * 0.12, x + alt * 0.12, y + alt], fill=cor)
    x += alt * 0.22
    x += sete_segmentos(d, x, y, alt, "4", cor)
    d.text((x + alt * 0.1, y + alt), "g", font=fonte("arialbd.ttf", int(alt * 0.55)), fill=cor, anchor="lb")
    return img


def desenhar_painel(w: int, h: int) -> Image.Image:
    """Tampo da balanca: preto com os dois botoes e o nome."""
    img = papel(w, h, (30, 30, 32), 50, 0.08)
    d = ImageDraw.Draw(img)
    for k, txt in enumerate(("ON", "TARE")):
        x = w * (0.28 + 0.44 * k)
        y = h * 0.62
        r = w * 0.13
        d.rounded_rectangle([x - r, y - r * 0.6, x + r, y + r * 0.6], radius=r * 0.3,
                            fill=(62, 62, 66), outline=(100, 100, 104), width=2)
        d.text((x, y), txt, font=fonte("arialbd.ttf", int(w * 0.075)), fill=(210, 210, 210), anchor="mm")
    d.text((w * 0.5, h * 0.28), "0,01 g  /  500 g", font=fonte("arial.ttf", int(w * 0.07)),
           fill=(150, 150, 150), anchor="mm")
    return img


def desenhar_tanque(w: int, h: int) -> Image.Image:
    img = papel(w, h, (240, 240, 236), 60, 0.03)
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, w - 5, h - 5], outline=(30, 80, 160), width=4)
    cx, cy = w * 0.5, h * 0.36
    r = w * 0.14
    d.polygon([(cx, cy - r * 1.6), (cx - r, cy + r * 0.2), (cx + r, cy + r * 0.2)], fill=(40, 110, 200))
    d.ellipse([cx - r, cy - r * 0.8, cx + r, cy + r * 1.2], fill=(40, 110, 200))
    d.text((w * 0.5, h * 0.7), "AGUA", font=fonte("arialbd.ttf", int(w * 0.16)), fill=(30, 60, 120), anchor="mm")
    d.text((w * 0.5, h * 0.86), "NAO BEBER", font=fonte("arial.ttf", int(w * 0.09)), fill=(160, 40, 40), anchor="mm")
    return img


def desenhar_tampa(w: int, h: int) -> Image.Image:
    """Topo da tampa do pote: preto fosco com aneis concentricos; o KitEstufa
    mapeia o disco no centro desta celula."""
    img = Image.new("RGB", (w, h), (26, 26, 28))
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = w / 2, h / 2
    for k in range(10):
        r = min(w, h) * 0.5 * (1.0 - k * 0.09)
        v = 30 + (k % 2) * 8
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(v, v, v + 2, 255), width=max(1, K // 2))
    return img


def desenhar_serrilha(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (24, 24, 26, 255))
    d = ImageDraw.Draw(img)
    passo = w / 24
    for k in range(24):
        x = k * passo
        d.rectangle([x, 0, x + passo * 0.4, h], fill=(58, 58, 62))
    return img


def desenhar_zip(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (236, 236, 236, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, h * 0.2, w, h * 0.45], fill=(200, 40, 40))
    d.rectangle([0, h * 0.55, w, h * 0.8], fill=(210, 210, 214))
    return img


# --- variedades ---------------------------------------------------------------

def _ciano(c: tuple[int, int, int]) -> tuple[int, int, int]:
    """Calice da Vagalume: o verde da flor vira ciano claro. A emissao do
    material multiplica a textura, e por isso a flor que acende tem de ser
    CLARA aqui — tinta de vertice nao clareia (cor de vertice corta em um)."""
    r, g, b = c
    return (min(255, int(g * 0.7 + 40)), min(255, int(g * 1.35 + 20)),
            min(255, int(g * 1.25 + 30)))


def desenhar_bud_brilho(w: int, h: int) -> Image.Image:
    """A flor que acende: o mesmo desenho do botao (calice, pelo e geada), em
    ciano claro, com o pelo lilas e branco no lugar do laranja."""
    return desenhar_bud(w, h, 16, base=(96, 186, 178), tinge=_ciano,
                        cores_pistilo=[((226, 206, 250), 0.45), ((188, 150, 236), 0.3),
                                       ((250, 250, 255), 0.25)])


def desenhar_ceramica(w: int, h: int, seed: int) -> Image.Image:
    """Esmalte de bandeja de bonsai, CLARO para a tinta de vertice dar a cor:
    poca de esmalte mais escura embaixo (v = 1), pintas de ferro e o craquele
    fino. Repete em u."""
    rng = random.Random(seed)
    n = ruido(w, h, np.random.default_rng(seed), max(4, w // 4), 4)
    rgb = cor_ruido((214, 214, 218), n, 0.07)
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None, None]
    rgb = rgb * (1.02 - 0.2 * ys ** 2)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    # Escorrido do esmalte: faixas verticais mais claras que param em alturas
    # diferentes.
    for _ in range(9):
        x = rng.uniform(0, w)
        fim = rng.uniform(h * 0.3, h * 0.85)
        larg = rng.uniform(1.5, 3.5) * K / 2
        envolto(d, w, h, lambda dd, dx, dy, x=x, fim=fim, larg=larg:
                dd.line([(x + dx, dy), (x + dx, fim + dy)], fill=(245, 245, 248, 70),
                        width=max(1, int(larg))))
    # Craquele.
    for _ in range(26):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        pts = [(x, y)]
        for _k in range(4):
            x += rng.uniform(-w * 0.12, w * 0.12)
            y += rng.uniform(-h * 0.12, h * 0.12)
            pts.append((x, y))
        envolto(d, w, h, lambda dd, dx, dy, pts=pts:
                dd.line([(p[0] + dx, p[1] + dy) for p in pts], fill=(120, 120, 126, 60), width=1))
    # Pintas de ferro.
    for _ in range(int(w * h * 0.0012)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(0.5, 1.1) * K / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=(70, 52, 40, rng.randint(70, 150)))
    return img


def desenhar_casca(w: int, h: int, seed: int) -> Image.Image:
    """Casca de tronco velho: sulcos no comprido (v corre ao longo do tubo),
    cristas claras entre eles e liquen cinza-esverdeado aqui e ali. Repete em u
    e em v."""
    rng = random.Random(seed)
    n = ruido(w, h, np.random.default_rng(seed), max(4, w // 4), 4)
    rgb = cor_ruido((126, 104, 84), n, 0.16)
    img = para_img(rgb)
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(int(w * 0.9)):
        x = rng.uniform(0, w)
        escuro = rng.random() < 0.55
        cor = (54, 40, 30, 190) if escuro else (176, 156, 128, 120)
        larg = max(1, int(rng.uniform(1.0, 2.6) * K / 2))
        amp = rng.uniform(1.0, 3.0) * K / 2
        fase = rng.uniform(0, math.tau)
        pts = [(x + math.sin(y / h * math.tau * 2 + fase) * amp, y) for y in range(0, h + 1, 4)]
        envolto(d, w, h, lambda dd, dx, dy, pts=pts, cor=cor, larg=larg:
                dd.line([(p[0] + dx, p[1] + dy) for p in pts], fill=cor, width=larg))
    for _ in range(10):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(2, 6) * K / 2
        envolto(d, w, h, lambda dd, dx, dy, x=x, y=y, r=r:
                dd.ellipse([x + dx - r, y + dy - r * 1.6, x + dx + r, y + dy + r * 1.6],
                           fill=(150, 160, 130, 90)))
    return img


def desenhar_variedade(nome: str, w: int, h: int) -> Image.Image:
    if nome == "foliolo_roxo":
        # Roxo quase preto, nervura lilas: a folha da Vagalume some no andar
        # apagado e sobra a flor acesa.
        return desenhar_foliolo(w, h, 15, (58, 30, 72), (156, 96, 178))
    if nome == "bud_brilho":
        return desenhar_bud_brilho(w, h)
    if nome == "ceramica":
        return desenhar_ceramica(w, h, 17)
    if nome == "casca":
        return desenhar_casca(w, h, 18)
    raise KeyError(nome)


# --- montagem -----------------------------------------------------------------

def desenhar(nome: str, w: int, h: int) -> Image.Image:
    if nome == "foliolo":
        return desenhar_foliolo(w, h, 1, (62, 116, 42), (150, 196, 108))
    if nome == "acucar":
        return desenhar_foliolo(w, h, 2, (60, 104, 44), (140, 180, 110), geada=1.0,
                                dentes=12, fundo=0.16)
    if nome == "seco":
        return desenhar_foliolo(w, h, 3, (150, 132, 64), (190, 170, 110), dentes=18,
                                fundo=0.12, seco=True)
    if nome == "cotiledone":
        return desenhar_cotiledone(w, h, 4)
    if nome == "caule":
        return desenhar_caule(w, h, 5)
    if nome == "semente":
        return desenhar_semente(w, h, 6)
    if nome == "etiqueta":
        return desenhar_etiqueta(w, h)
    if nome == "bud":
        return desenhar_bud(w, h, 7)
    if nome == "pistilo":
        return desenhar_pistilo(w, h, 8)
    if nome == "terra":
        return desenhar_terra(w, h, 9)
    if nome == "feltro":
        return desenhar_feltro(w, h, 10)
    if nome.startswith("rotulo") and nome[-1].isdigit():
        return desenhar_rotulo(w, h, int(nome[-1]))
    if nome == "rotulo_terra":
        return desenhar_rotulo_terra(w, h)
    if nome.startswith("envelope"):
        return desenhar_envelope(w, h, int(nome[-1]))
    if nome == "caixa_dentro":
        return desenhar_caixa_dentro(w, h)
    if nome == "tampa":
        return desenhar_tampa(w, h)
    if nome == "serrilha":
        return desenhar_serrilha(w, h)
    if nome == "metal":
        return desenhar_metal(w, h, 11)
    if nome == "plastico":
        return desenhar_plastico(w, h, 12)
    if nome == "saco":
        return desenhar_saco(w, h, 13)
    if nome == "crivo":
        return desenhar_crivo(w, h)
    if nome == "madeira":
        return desenhar_madeira(w, h, 14)
    if nome == "lcd":
        return desenhar_lcd(w, h)
    if nome == "painel":
        return desenhar_painel(w, h)
    if nome == "tanque":
        return desenhar_tanque(w, h)
    if nome == "zip":
        return desenhar_zip(w, h)
    raise KeyError(nome)


def dilatar(img: Image.Image, passos: int = 12) -> Image.Image:
    """Poe no fundo transparente a cor da folha mais proxima, sem mexer no alfa."""
    arr = np.asarray(img, np.float32).copy()
    a = arr[..., 3] / 255.0
    cheio = a > 0.5
    rgb = arr[..., :3] * cheio[..., None]
    peso = cheio.astype(np.float32)
    for _ in range(passos):
        soma = np.zeros_like(rgb)
        ps = np.zeros_like(peso)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            soma += np.roll(np.roll(rgb, dx, 1), dy, 0)
            ps += np.roll(np.roll(peso, dx, 1), dy, 0)
        novo = (peso == 0) & (ps > 0)
        rgb[novo] = soma[novo] / ps[novo][..., None]
        peso[novo] = 1.0
    falta = peso == 0
    if falta.any():
        media = arr[..., :3][cheio].mean(axis=0) if cheio.any() else np.array([60, 110, 40])
        rgb[falta] = media
    arr[..., :3] = np.where(cheio[..., None], arr[..., :3], rgb)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")


def montar() -> tuple[Image.Image, Image.Image]:
    hd = Image.new("RGBA", (HD, HD), (0, 0, 0, 0))
    ps1 = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    for nome, (x, y, w, h) in REG.items():
        cel = desenhar(nome, w * K, h * K).convert("RGBA")
        if nome in RECORTADAS:
            cel = dilatar(cel, 24)
        hd.paste(cel, (x * K, y * K))
        # O PS1 sai da reducao da MESMA celula, uma por uma, para a borda de uma
        # nao sangrar na vizinha.
        pequena = cel.resize((w, h), Image.LANCZOS)
        if nome in RECORTADAS:
            arr = np.asarray(pequena).copy()
            arr[..., 3] = np.where(arr[..., 3] >= 128, 255, 0)
            pequena = Image.fromarray(arr, "RGBA")
        ps1.paste(pequena, (x, y))
    # 256 cores no PS1, com o alfa guardado a parte.
    alfa = ps1.getchannel("A")
    rgb = ps1.convert("RGB").quantize(256, dither=Image.Dither.FLOYDSTEINBERG).convert("RGB")
    ps1 = rgb.copy()
    ps1.putalpha(alfa)
    # As variedades: cada celula com a PROPRIA paleta de 256 (a CLUT por
    # pagina do PS1), colada depois da reducao do atlas antigo.
    for nome, (x, y, w, h) in REG_VARIEDADES.items():
        cel = desenhar_variedade(nome, w * K, h * K).convert("RGBA")
        if nome in RECORTADAS:
            cel = dilatar(cel, 24)
        hd.paste(cel, (x * K, y * K))
        pequena = cel.resize((w, h), Image.LANCZOS)
        arr = np.asarray(pequena).copy()
        if nome in RECORTADAS:
            arr[..., 3] = np.where(arr[..., 3] >= 128, 255, 0)
        else:
            arr[..., 3] = 255
        a_cel = Image.fromarray(arr[..., 3], "L")
        q = Image.fromarray(arr[..., :3], "RGB").quantize(
            256, dither=Image.Dither.FLOYDSTEINBERG).convert("RGB")
        q.putalpha(a_cel)
        ps1.paste(q, (x, y))
    return hd, ps1


def main() -> int:
    hd, ps1 = montar()
    previa = ""
    for arg in sys.argv[1:]:
        if arg.startswith("--previa="):
            previa = arg.split("=", 1)[1]
    SAIDA_HD.parent.mkdir(parents=True, exist_ok=True)
    hd.save(SAIDA_HD)
    ps1.save(SAIDA_PS1)
    print(f"{SAIDA_HD}  {hd.size}")
    print(f"{SAIDA_PS1}  {ps1.size}")
    if previa:
        p = Path(previa)
        p.mkdir(parents=True, exist_ok=True)
        fundo = Image.new("RGBA", hd.size, (120, 60, 120, 255))
        fundo.alpha_composite(hd)
        fundo.convert("RGB").save(p / "estufa_kit_hd.png")
        fundo2 = Image.new("RGBA", ps1.size, (120, 60, 120, 255))
        fundo2.alpha_composite(ps1)
        fundo2.resize((1024, 1024), Image.NEAREST).convert("RGB").save(p / "estufa_kit_ps1.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

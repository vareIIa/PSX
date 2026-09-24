"""Atlas de rotulos dos itens do cultivo (pote, saco de terra, envelope, crivo).

    python tools/gerar_rotulos_cultivo.py

Gera game/assets/itens_cultivo/rotulos.png, 1024 x 2048, lido por
game/src/ui/item_modelo.gd. As regioes abaixo sao o CONTRATO com aquele
arquivo: mudou uma, muda a constante de la (REG_*), senao o rotulo sai cortado.

Por que textura, e nao cor chapada
----------------------------------
Os itens do cultivo sao todos marrom-esverdeados. O que separa um saco de terra
de um saco de lixo, e um envelope de semente de um bilhete, e o IMPRESSO: faixa,
marca, folha estampada. Em vertice nao se escreve "SUBSTRATO".

Desenha em 2x e reduz com Lanczos: o poligono da folha sai sem serrilhado e a
letra fina nao some na reducao. Depois do primeiro --import o .import desta
imagem pede mipmap (a vitrine desenha o pote a 128 px, e sem mipmap o rotulo de
1024 cintila girando).
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "itens_cultivo" / "rotulos.png"
FONTES = Path("C:/Windows/Fonts")

LADO = 1024
K = 2  # fator de desenho

# Regioes em pixel do atlas final (x, y, largura, altura). Espelhadas em
# item_modelo.gd.
REG_POTE = (0, 0, 512, 256)
REG_POTE_SUPER = (512, 0, 512, 256)
REG_SACO = (0, 256, 1024, 384)
REG_ENV_FRENTE = (0, 640, 288, 384)
REG_ENV_VERSO = (288, 640, 288, 384)
REG_CRIVO = (576, 640, 192, 192)
REG_TERRA = (768, 640, 256, 256)
REG_KRAFT = (576, 832, 192, 192)

# As variedades da estufa (game/src/systems/variedades.gd): um rotulo de pote
# por andar, do mesmo tamanho do REG_POTE, numa folha nova EMBAIXO da antiga.
# O atlas cresceu para 1024 x 2048 e a metade de cima e desenhada e reduzida
# sozinha, como antes: os rotulos que ja existiam saem identicos, byte a byte.
ALTURA = 2 * LADO
VARIEDADES = ["morcega", "bonsai", "saca_rolha", "girafa", "pompom", "chorona",
              "gambazona", "vagalume"]
REG_VAR = {v: (512 * (i % 2), LADO + 256 * (i // 2), 512, 256)
           for i, v in enumerate(VARIEDADES)}

rnd = random.Random(420)


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


def texto_centro(d: ImageDraw.ImageDraw, cx: float, cy: float, texto: str,
                 f: ImageFont.FreeTypeFont, cor) -> None:
    d.text((cx, cy), texto, font=f, fill=cor, anchor="mm")


def folha(d: ImageDraw.ImageDraw, bx: float, by: float, tam: float, cor,
          rot: float = 0.0) -> None:
    """Folha de cannabis de sete foliolos serrilhados, base em (bx, by)."""
    angulos = [-78, -50, -24, 0, 24, 50, 78]
    comps = [0.36, 0.64, 0.88, 1.0, 0.88, 0.64, 0.36]
    for ang, comp in zip(angulos, comps):
        a = math.radians(ang + rot)
        ux, uy = math.sin(a), -math.cos(a)
        px, py = -uy, ux
        L = tam * comp
        W = tam * 0.11 * (0.75 + 0.25 * comp)
        lado_a, lado_b = [], []
        n = 22
        for i in range(n + 1):
            s = i / n
            w = W * math.sin(math.pi * s) ** 0.8 * (1.0 - 0.35 * s)
            # Serrilha: dente a cada passo, so no meio da lamina.
            if 0.12 < s < 0.92 and i % 2 == 1:
                w *= 1.28
            cx, cy = bx + ux * L * s, by + uy * L * s
            lado_a.append((cx + px * w, cy + py * w))
            lado_b.append((cx - px * w, cy - py * w))
        d.polygon(lado_a + lado_b[::-1], fill=cor)
    # Cabo.
    a = math.radians(180 + rot)
    d.line([(bx, by), (bx + math.sin(a) * tam * 0.28, by - math.cos(a) * tam * 0.28)],
           fill=cor, width=max(2, int(tam * 0.035)))


def ruido_papel(img: Image.Image, forca: int, semente: int) -> Image.Image:
    """Fibra de papel: ruido fino esticado na horizontal, somado a imagem."""
    r = random.Random(semente)
    w, h = img.size
    ru = Image.new("L", (w // 4, h // 4))
    ru.putdata([128 + r.randint(-forca, forca) for _ in range((w // 4) * (h // 4))])
    ru = ru.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(1.2))
    ru3 = Image.merge("RGB", (ru, ru, ru))
    # a + (ruido - 128), cortado em 0..255.
    return ImageChops.add(img.convert("RGB"), ru3, scale=1.0, offset=-128)


def desgaste(img: Image.Image, semente: int, qtd: int, cor) -> Image.Image:
    """Arranhoes e manchas de uso: o impresso novo demais le como render."""
    r = random.Random(semente)
    d = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    for _ in range(qtd):
        x, y = r.uniform(0, w), r.uniform(0, h)
        comp = r.uniform(6, 40) * K
        a = r.uniform(0, math.pi)
        d.line([(x, y), (x + math.cos(a) * comp, y + math.sin(a) * comp)],
               fill=cor, width=r.randint(1, 2))
    return img


# --- pecas ---------------------------------------------------------------

def rotulo_pote() -> Image.Image:
    w, h = REG_POTE[2] * K, REG_POTE[3] * K
    img = Image.new("RGB", (w, h), (236, 228, 208))
    img = ruido_papel(img, 10, 1)
    d = ImageDraw.Draw(img, "RGBA")
    # Faixa verde de cima e de baixo: o que o olho acha primeiro no pote.
    d.rectangle([0, 0, w, 58 * K], fill=(38, 84, 46))
    d.rectangle([0, h - 34 * K, w, h], fill=(38, 84, 46))
    d.rectangle([0, 58 * K, w, 62 * K], fill=(196, 160, 72))
    d.rectangle([0, h - 38 * K, w, h - 34 * K], fill=(196, 160, 72))
    texto_centro(d, w * 0.5, 30 * K, "ESTUFA", caber("ESTUFA", "impact.ttf", 300 * K, 46 * K),
                 (236, 228, 208))
    # Folha no circulo a esquerda.
    d.ellipse([28 * K, 76 * K, 152 * K, 200 * K], fill=(38, 84, 46))
    folha(d, 90 * K, 178 * K, 92 * K, (224, 216, 190))
    # Nome da variedade e peso.
    d.text((172 * K, 78 * K), "SKUNK", font=fonte("impact.ttf", 58 * K), fill=(30, 36, 28))
    d.text((174 * K, 146 * K), "CURADA  \u2022  CORTE 09", font=fonte("arialbd.ttf", 17 * K),
           fill=(70, 74, 62))
    # Peso escrito a caneta, torto, por cima do impresso. A tela do "7g" tinha
    # 70 px de altura e cortava a perna do g, que ficava lendo "7a": agora a
    # tela e folgada e o texto vai ancorado pela linha de base, com a perna
    # inteira abaixo dela.
    peso = Image.new("RGBA", (170 * K, 120 * K), (0, 0, 0, 0))
    dp = ImageDraw.Draw(peso)
    caneta = "segoeprb.ttf" if (FONTES / "segoeprb.ttf").exists() else "arialbd.ttf"
    dp.text((10 * K, 70 * K), "7g", font=fonte(caneta, 46 * K), fill=(28, 40, 110, 235),
            anchor="ls")
    peso = peso.rotate(9, resample=Image.BICUBIC, expand=True)
    img.paste(peso, (380 * K, 58 * K), peso)
    d = ImageDraw.Draw(img, "RGBA")
    # Linhas de texto miudo (le como texto sem precisar ler).
    for i in range(3):
        d.rectangle([174 * K, (178 + i * 9) * K, (174 + 150 - i * 30) * K, (182 + i * 9) * K],
                    fill=(90, 92, 80))
    return desgaste(img, 2, 26, (255, 255, 255, 60))


def rotulo_super() -> Image.Image:
    w, h = REG_POTE_SUPER[2] * K, REG_POTE_SUPER[3] * K
    img = Image.new("RGB", (w, h), (22, 16, 26))
    img = ruido_papel(img, 6, 3)
    d = ImageDraw.Draw(img, "RGBA")
    ouro = (214, 176, 84)
    roxo = (150, 92, 206)
    # Moldura dupla dourada: e o rotulo "de reserva", e tem de parecer caro.
    d.rectangle([8 * K, 8 * K, w - 8 * K, h - 8 * K], outline=ouro, width=3 * K)
    d.rectangle([16 * K, 16 * K, w - 16 * K, h - 16 * K], outline=ouro, width=1 * K)
    d.ellipse([30 * K, 52 * K, 176 * K, 198 * K], fill=(58, 30, 84))
    d.ellipse([30 * K, 52 * K, 176 * K, 198 * K], outline=ouro, width=2 * K)
    folha(d, 103 * K, 178 * K, 104 * K, roxo)
    d.text((190 * K, 50 * K), "SUPER", font=fonte("impact.ttf", 92 * K), fill=ouro)
    d.text((194 * K, 158 * K), "ANDAR 10  \u2022  LUZ ROXA", font=fonte("arialbd.ttf", 19 * K),
           fill=(196, 170, 222))
    d.rectangle([194 * K, 190 * K, 470 * K, 193 * K], fill=ouro)
    d.text((194 * K, 200 * K), "NAO E PRA PRACA", font=fonte("arialbd.ttf", 15 * K),
           fill=(160, 140, 180))
    return desgaste(img, 4, 18, (255, 255, 255, 40))


def saco() -> Image.Image:
    """Volta inteira do saco: frente na metade esquerda, verso na direita.

    x = 0 e o canto esquerdo do saco visto de frente; 0,5 o canto direito.
    """
    w, h = REG_SACO[2] * K, REG_SACO[3] * K
    amarelo = (222, 164, 40)
    verde = (34, 92, 44)
    img = Image.new("RGB", (w, h), amarelo)
    img = ruido_papel(img, 5, 5)
    d = ImageDraw.Draw(img, "RGBA")
    fw = w // 2
    # --- frente ---
    # Topo verde: fica em volta da boca, e o que dobra.
    d.rectangle([0, 0, w, 44 * K], fill=verde)
    # Faixa de terra fotografada embaixo, com borda ondulada.
    onda = [(0, h)]
    for i in range(0, fw + 1, 8 * K):
        onda.append((i, h - 150 * K + math.sin(i / (60 * K)) * 10 * K))
    onda.append((fw, h))
    d.polygon(onda, fill=(74, 50, 34))
    r = random.Random(9)
    for _ in range(2600):
        x = r.uniform(0, fw)
        y = r.uniform(h - 140 * K, h)
        c = r.choice([(52, 34, 24), (96, 66, 44), (40, 28, 20), (120, 86, 56)])
        rr = r.uniform(1, 3.5) * K
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=c)
    for _ in range(260):  # perlita
        x = r.uniform(0, fw)
        y = r.uniform(h - 138 * K, h)
        rr = r.uniform(1.5, 3.5) * K
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(238, 234, 222))
    # Broto saindo da terra: e a marca.
    folha(d, fw * 0.3, h - 146 * K, 74 * K, (46, 120, 52))
    # Marca e nome.
    d.rounded_rectangle([40 * K, 60 * K, fw - 40 * K, 126 * K], radius=12 * K, fill=verde)
    texto_centro(d, fw * 0.5, 94 * K, "TERRA VEGETAL",
                 caber("TERRA VEGETAL", "impact.ttf", fw - 110 * K, 52 * K), (246, 236, 200))
    texto_centro(d, fw * 0.5, 142 * K, "SUBSTRATO PARA VASOS",
                 caber("SUBSTRATO PARA VASOS", "arialbd.ttf", fw - 120 * K, 22 * K), (40, 36, 24))
    texto_centro(d, 24 * K + 48 * K, 28 * K, "RAIZ FORTE", fonte("ariblk.ttf", 17 * K),
                 (230, 206, 110))
    # Selo de volume.
    d.ellipse([fw - 118 * K, 150 * K, fw - 30 * K, 238 * K], fill=(196, 40, 32))
    d.ellipse([fw - 112 * K, 156 * K, fw - 36 * K, 232 * K], outline=(250, 230, 200), width=2 * K)
    texto_centro(d, fw - 74 * K, 188 * K, "25", fonte("impact.ttf", 40 * K), (250, 240, 220))
    texto_centro(d, fw - 74 * K, 216 * K, "LITROS", fonte("arialbd.ttf", 12 * K), (250, 240, 220))
    # --- verso ---
    x0 = fw + 60 * K
    d.text((x0, 70 * K), "MODO DE USAR", font=fonte("arialbd.ttf", 22 * K), fill=(40, 36, 24))
    for i in range(7):
        d.rectangle([x0, (106 + i * 16) * K, x0 + (330 - (i % 3) * 50) * K, (112 + i * 16) * K],
                    fill=(110, 84, 30))
    d.text((x0, 230 * K), "COMPOSICAO", font=fonte("arialbd.ttf", 16 * K), fill=(40, 36, 24))
    for i in range(3):
        d.rectangle([x0, (256 + i * 14) * K, x0 + (260 - i * 40) * K, (261 + i * 14) * K],
                    fill=(110, 84, 30))
    # Codigo de barras.
    bx = w - 190 * K
    d.rectangle([bx - 8 * K, 60 * K, bx + 128 * K, 150 * K], fill=(246, 240, 226))
    xx = bx
    while xx < bx + 118 * K:
        lw = r.choice([1, 1, 2, 3]) * K
        d.rectangle([xx, 66 * K, xx + lw - 1, 136 * K], fill=(20, 20, 20))
        xx += lw + r.choice([1, 2]) * K
    # Vinco de fundo: o plastico amassa e o impresso clareia na dobra.
    for _ in range(40):
        y = r.uniform(0, h)
        d.line([(0, y), (w, y + r.uniform(-30, 30) * K)], fill=(255, 255, 255, 14), width=K)
    return desgaste(img, 6, 70, (255, 248, 220, 70))


def envelope_frente() -> Image.Image:
    w, h = REG_ENV_FRENTE[2] * K, REG_ENV_FRENTE[3] * K
    img = Image.new("RGB", (w, h), (184, 148, 102))
    img = ruido_papel(img, 12, 7)
    d = ImageDraw.Draw(img, "RGBA")
    # Carimbo vermelho, meio falhado.
    carimbo = Image.new("RGBA", (w, 80 * K), (0, 0, 0, 0))
    dc = ImageDraw.Draw(carimbo)
    dc.rectangle([22 * K, 10 * K, w - 22 * K, 70 * K], outline=(170, 34, 30, 230), width=4 * K)
    texto_centro(dc, w * 0.5, 40 * K, "SEMENTES", caber("SEMENTES", "impact.ttf", w - 70 * K, 44 * K),
                 (170, 34, 30, 230))
    r = random.Random(11)
    px = carimbo.load()
    for y in range(carimbo.height):
        for x in range(carimbo.width):
            c = px[x, y]
            if c[3] > 0 and r.random() < 0.22:
                px[x, y] = (c[0], c[1], c[2], int(c[3] * 0.25))
    carimbo = carimbo.rotate(-4, resample=Image.BICUBIC)
    img.paste(carimbo, (0, 36 * K), carimbo)
    d = ImageDraw.Draw(img, "RGBA")
    # Folha grande estampada em verde.
    folha(d, w * 0.5, 300 * K, 150 * K, (44, 98, 50, 235))
    # Etiqueta branca com o lote, e o "x5" a caneta.
    d.rectangle([40 * K, 318 * K, w - 40 * K, 368 * K], fill=(240, 236, 224))
    d.text((52 * K, 322 * K), "MALHADA  x5", font=fonte("arialbd.ttf", 22 * K), fill=(30, 40, 110))
    d.text((52 * K, 348 * K), "LOTE 10 / ESTUFA", font=fonte("arial.ttf", 13 * K), fill=(60, 60, 60))
    # Borda de cola escurecida nos lados e no fundo (onde o papel foi colado).
    d.rectangle([0, 0, 8 * K, h], fill=(150, 116, 76, 160))
    d.rectangle([w - 8 * K, 0, w, h], fill=(150, 116, 76, 160))
    d.rectangle([0, h - 10 * K, w, h], fill=(150, 116, 76, 160))
    return desgaste(img, 12, 30, (90, 60, 30, 70))


def envelope_verso() -> Image.Image:
    w, h = REG_ENV_VERSO[2] * K, REG_ENV_VERSO[3] * K
    img = Image.new("RGB", (w, h), (180, 144, 98))
    img = ruido_papel(img, 12, 13)
    d = ImageDraw.Draw(img, "RGBA")
    # As abas coladas do envelope: um V e as duas laterais.
    sombra = (140, 106, 66, 150)
    d.line([(0, h * 0.45), (w * 0.5, h * 0.72), (w, h * 0.45)], fill=sombra, width=3 * K)
    d.line([(w * 0.5, h * 0.72), (w * 0.5, h)], fill=sombra, width=2 * K)
    d.text((w * 0.5, h * 0.88), "Nao molhar", font=fonte("arial.ttf", 14 * K), fill=(90, 60, 36),
           anchor="mm")
    return desgaste(img, 14, 26, (90, 60, 30, 60))


def kraft() -> Image.Image:
    w, h = REG_KRAFT[2] * K, REG_KRAFT[3] * K
    img = Image.new("RGB", (w, h), (178, 142, 96))
    img = ruido_papel(img, 12, 17)
    d = ImageDraw.Draw(img, "RGBA")
    # Faixa de cola da aba, mais brilhante.
    d.rectangle([0, h * 0.72, w, h * 0.86], fill=(196, 164, 112, 200))
    return img


def crivo() -> Image.Image:
    """Face do crivo: latao com anel de furos concentricos."""
    w, h = REG_CRIVO[2] * K, REG_CRIVO[3] * K
    img = Image.new("RGB", (w, h), (176, 140, 72))
    img = ruido_papel(img, 10, 19)
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = w / 2, h / 2
    raio = w * 0.47
    d.ellipse([cx - raio, cy - raio, cx + raio, cy + raio], outline=(120, 90, 40), width=4 * K)
    furo = 3.4 * K
    d.ellipse([cx - furo, cy - furo, cx + furo, cy + furo], fill=(24, 18, 10))
    for anel in range(1, 6):
        rr = anel * raio * 0.16
        n = 6 * anel
        for i in range(n):
            a = i / n * math.tau + anel * 0.3
            x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr
            d.ellipse([x - furo, y - furo, x + furo, y + furo], fill=(24, 18, 10))
            d.arc([x - furo - K, y - furo - K, x + furo + K, y + furo + K], 200, 340,
                  fill=(226, 196, 130), width=K)
    return img


def terra() -> Image.Image:
    """Terra com perlita vista de cima (a boca do saco)."""
    w, h = REG_TERRA[2] * K, REG_TERRA[3] * K
    img = Image.new("RGB", (w, h), (58, 40, 28))
    d = ImageDraw.Draw(img, "RGBA")
    r = random.Random(23)
    for _ in range(9000):
        x, y = r.uniform(0, w), r.uniform(0, h)
        c = r.choice([(40, 28, 20), (76, 52, 36), (92, 64, 44), (34, 24, 18), (64, 46, 30)])
        rr = r.uniform(1.2, 4.0) * K
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=c)
    for _ in range(140):  # fibra de casca
        x, y = r.uniform(0, w), r.uniform(0, h)
        a = r.uniform(0, math.pi)
        comp = r.uniform(6, 16) * K
        d.line([(x, y), (x + math.cos(a) * comp, y + math.sin(a) * comp)], fill=(120, 80, 44),
               width=2 * K)
    for _ in range(220):  # perlita
        x, y = r.uniform(0, w), r.uniform(0, h)
        rr = r.uniform(1.8, 4.2) * K
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(236, 232, 220))
        d.ellipse([x - rr * 0.4, y - rr * 0.8, x + rr * 0.5, y], fill=(255, 255, 250))
    return img


# --- variedades ------------------------------------------------------------------
#
# Um rotulo por andar, com a mesma planta do rotulo SKUNK (faixa em cima, selo
# redondo a esquerda, nome grande, andar embaixo) e o resto todo trocado: fundo,
# tinta, selo e bilhete a caneta. No icone de 64 px o pote e do tamanho de um
# polegar e o rotulo vira duas manchas de cor; o que separa uma variedade da
# outra de longe e a cor do fundo e o desenho do selo, e o nome e para perto.

def morcego(d: ImageDraw.ImageDraw, cx: float, cy: float, s: float, cor) -> None:
    """Morcego de asa aberta, envergadura 2s."""
    for lado in (-1, 1):
        pts = [(cx, cy - s * 0.12)]
        # Borda de cima da asa: sobe ate o "dedo" e desce.
        pts += [(cx + lado * s * 0.35, cy - s * 0.38), (cx + lado * s * 0.72, cy - s * 0.42),
                (cx + lado * s * 1.0, cy - s * 0.18)]
        # Borda de baixo, recortada em tres arcos.
        for k, (x0, x1) in enumerate([(1.0, 0.7), (0.7, 0.42), (0.42, 0.14)]):
            n = 8
            for i in range(1, n + 1):
                t = i / n
                x = x0 + (x1 - x0) * t
                y = 0.10 - 0.16 * math.sin(math.pi * t) + k * 0.03
                pts.append((cx + lado * s * x, cy + s * y))
        pts.append((cx, cy + s * 0.2))
        d.polygon(pts, fill=cor)
    d.ellipse([cx - s * 0.16, cy - s * 0.3, cx + s * 0.16, cy + s * 0.26], fill=cor)
    # Orelhas.
    d.polygon([(cx - s * 0.13, cy - s * 0.2), (cx - s * 0.1, cy - s * 0.45), (cx - s * 0.02, cy - s * 0.26)],
              fill=cor)
    d.polygon([(cx + s * 0.13, cy - s * 0.2), (cx + s * 0.1, cy - s * 0.45), (cx + s * 0.02, cy - s * 0.26)],
              fill=cor)


def bonsai_arvore(d: ImageDraw.ImageDraw, cx: float, by: float, s: float, tronco, copa,
                  bandeja) -> None:
    """Bonsai de tronco torto e copa em nuvens, na bandeja, base em (cx, by)."""
    d.polygon([(cx - s * 0.62, by - s * 0.16), (cx + s * 0.62, by - s * 0.16),
               (cx + s * 0.5, by), (cx - s * 0.5, by)], fill=bandeja)
    pts_e, pts_d = [], []
    n = 14
    for i in range(n + 1):
        t = i / n
        x = cx + s * (0.18 * math.sin(t * 5.0) - 0.1 * t)
        y = by - s * 0.16 - s * 0.86 * t
        larg = s * (0.13 - 0.08 * t)
        pts_e.append((x - larg, y))
        pts_d.append((x + larg, y))
    d.polygon(pts_e + pts_d[::-1], fill=tronco)
    # Galho para a direita.
    d.line([(cx + s * 0.05, by - s * 0.55), (cx + s * 0.42, by - s * 0.62)], fill=tronco,
           width=max(2, int(s * 0.07)))
    for (ox, oy, rx, ry) in [(-0.05, -1.04, 0.42, 0.17), (0.42, -0.7, 0.26, 0.12),
                             (-0.34, -0.8, 0.26, 0.11)]:
        x, y = cx + s * ox, by + s * oy
        d.ellipse([x - s * rx, y - s * ry, x + s * rx, y + s * ry], fill=copa)


def espiral(d: ImageDraw.ImageDraw, cx: float, top: float, s: float, cor, sombra) -> None:
    """Saca-rolha visto de lado: cabo em cima e a mola descendo."""
    d.rounded_rectangle([cx - s * 0.5, top, cx + s * 0.5, top + s * 0.16], radius=s * 0.08, fill=cor)
    d.rectangle([cx - s * 0.04, top + s * 0.14, cx + s * 0.04, top + s * 0.32], fill=cor)
    voltas = 4.0
    n = 120
    pts = []
    for i in range(n + 1):
        t = i / n
        a = t * voltas * math.tau
        r = s * 0.26 * (1.0 - 0.55 * t)
        pts.append((cx + math.sin(a) * r, top + s * 0.32 + t * s * 1.0, math.cos(a)))
    larg = max(2, int(s * 0.07))
    # Metade de tras primeiro, escura; a da frente por cima.
    for frente in (False, True):
        for i in range(n):
            x0, y0, z0 = pts[i]
            x1, y1, _z1 = pts[i + 1]
            if (z0 > 0) == frente:
                d.line([(x0, y0), (x1, y1)], fill=cor if frente else sombra, width=larg)


def pirulito(d: ImageDraw.ImageDraw, cx: float, cy: float, s: float, bola, franja, palito) -> None:
    d.rectangle([cx - s * 0.04, cy, cx + s * 0.04, cy + s * 0.95], fill=palito)
    r = random.Random(31)
    for i in range(46):
        a = i / 46 * math.tau
        rr = s * 0.13
        x, y = cx + math.cos(a) * s * 0.44, cy + math.sin(a) * s * 0.44
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=franja)
    d.ellipse([cx - s * 0.46, cy - s * 0.46, cx + s * 0.46, cy + s * 0.46], fill=bola)
    for _ in range(18):
        a = r.uniform(0, math.tau)
        dd = r.uniform(0, s * 0.36)
        x, y = cx + math.cos(a) * dd, cy + math.sin(a) * dd
        rr = s * 0.05
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=franja)


def gota(d: ImageDraw.ImageDraw, cx: float, cy: float, s: float, cor) -> None:
    """Lagrima de altura ~1,6 s: ponta em cima, bojo embaixo, centro em (cx, cy)."""
    pts = []
    n = 40
    for i in range(n + 1):
        t = math.tau * i / n
        x = math.sin(t) * math.sin(t * 0.5) ** 1.3 * s * 0.62
        y = -math.cos(t) * s * 0.8
        pts.append((cx + x, cy + y))
    d.polygon(pts, fill=cor)


def salgueiro(d: ImageDraw.ImageDraw, cx: float, top: float, s: float, cor) -> None:
    for k in range(-4, 5):
        pts = []
        for i in range(21):
            t = i / 20
            x = cx + k * s * 0.13 * math.sin(math.pi * 0.5 * min(t * 2.2, 1.0))
            y = top + s * 0.18 * math.sin(math.pi * min(t * 2.2, 1.0) * 0.5) * (1 - 0.3 * abs(k) / 4) \
                + max(0.0, t - 0.45) * s * (1.2 - 0.12 * abs(k))
            pts.append((x, y))
        d.line(pts, fill=cor, width=max(2, int(s * 0.03)))
        for x, y in pts[10::3]:
            d.ellipse([x - s * 0.035, y - s * 0.012, x + s * 0.035, y + s * 0.07], fill=cor)


def nuvem(d: ImageDraw.ImageDraw, cx: float, cy: float, s: float, cor) -> None:
    for ox, oy, rr in [(-0.32, 0.06, 0.26), (0.0, -0.1, 0.34), (0.32, 0.04, 0.27),
                       (0.12, 0.16, 0.24), (-0.14, 0.16, 0.24)]:
        x, y = cx + ox * s, cy + oy * s
        d.ellipse([x - rr * s, y - rr * s, x + rr * s, y + rr * s], fill=cor)


def fumaca(d: ImageDraw.ImageDraw, cx: float, by: float, s: float, cor) -> None:
    for k in (-1, 0, 1):
        pts = []
        for i in range(24):
            t = i / 23
            pts.append((cx + k * s * 0.28 + math.sin(t * 9.0 + k) * s * 0.08, by - t * s))
        d.line(pts, fill=cor, width=max(2, int(s * 0.06)))


def brilho(img: Image.Image, pontos, cor, raio: float, forca: float = 1.0) -> Image.Image:
    """Pontos que brilham: miolo claro e halo borrado, somados a imagem."""
    halo = Image.new("RGB", img.size, (0, 0, 0))
    dh = ImageDraw.Draw(halo)
    for x, y, esc in pontos:
        rr = raio * esc
        dh.ellipse([x - rr * 2.4, y - rr * 2.4, x + rr * 2.4, y + rr * 2.4],
                   fill=tuple(int(c * 0.55 * forca) for c in cor))
    halo = halo.filter(ImageFilter.GaussianBlur(raio * 1.6))
    out = ImageChops.add(img.convert("RGB"), halo)
    d = ImageDraw.Draw(out)
    for x, y, esc in pontos:
        rr = raio * esc
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(230, 255, 250))
    return out


# Tinta de cada rotulo. `fundo` e o papel, `faixa` as duas faixas e o selo,
# `filete` o fio entre faixa e papel, `nome` e `miudo` a tinta do texto,
# `caneta` o bilhete.
ESTILO_VAR = {
    "morcega": dict(andar=2, nome="MORCEGA", sub="SECAGEM  \u2022  NASCE PENDURADA",
                    fundo=(34, 24, 42), faixa=(92, 52, 120), filete=(196, 150, 222),
                    nome_cor=(232, 214, 246), miudo=(170, 150, 190), cabeca=(236, 224, 246),
                    caneta=(214, 70, 96, 240), bilhete="de ponta-cabeca"),
    "bonsai": dict(andar=3, nome="BONSAI", sub="DO JOTA  \u2022  20 MIN DE PACIENCIA",
                   fundo=(232, 206, 160), faixa=(128, 64, 30), filete=(214, 170, 90),
                   nome_cor=(58, 34, 18), miudo=(110, 76, 48), cabeca=(246, 230, 196),
                   caneta=(28, 40, 110, 235), bilhete="fala com ela"),
    "saca_rolha": dict(andar=4, nome="SACA-ROLHA", sub="MUDA TAMBEM  \u2022  CAULE EM MOLA",
                       fundo=(222, 242, 234), faixa=(26, 110, 102), filete=(236, 190, 80),
                       nome_cor=(18, 60, 56), miudo=(60, 104, 96), cabeca=(226, 246, 238),
                       caneta=(150, 40, 30, 235), bilhete="gira!"),
    "girafa": dict(andar=5, nome="GIRAFA", sub="MUDA AINDA  \u2022  BATE NO TETO",
                   fundo=(244, 204, 88), faixa=(110, 62, 24), filete=(250, 232, 170),
                   nome_cor=(70, 38, 14), miudo=(120, 80, 30), cabeca=(250, 228, 150),
                   caneta=(28, 40, 110, 235), bilhete="baratinha"),
    "pompom": dict(andar=6, nome="POMPOM", sub="NAO DESCER  \u2022  REDONDA DE NASCENCA",
                   fundo=(250, 196, 214), faixa=(206, 46, 110), filete=(255, 244, 248),
                   nome_cor=(120, 18, 64), miudo=(170, 70, 110), cabeca=(255, 236, 244),
                   caneta=(28, 40, 110, 235), bilhete="fofinha"),
    "chorona": dict(andar=7, nome="CHORONA", sub="NAO DESCER (SERIO)",
                    fundo=(206, 222, 242), faixa=(38, 58, 128), filete=(150, 190, 240),
                    nome_cor=(24, 38, 92), miudo=(80, 100, 150), cabeca=(220, 232, 250),
                    caneta=(28, 40, 110, 235), bilhete="nao chora..."),
    "gambazona": dict(andar=8, nome="GAMBAZONA", sub="O ANDAR DO CHEIRO",
                      fundo=(206, 232, 72), faixa=(34, 50, 20), filete=(250, 250, 200),
                      nome_cor=(30, 44, 12), miudo=(70, 90, 24), cabeca=(214, 240, 90),
                      caneta=(150, 30, 30, 240), bilhete="FEDE!!"),
    "vagalume": dict(andar=9, nome="VAGALUME", sub="ANDAR ???  \u2022  APAGUE A LUZ",
                     fundo=(12, 16, 34), faixa=(24, 150, 146), filete=(120, 255, 236),
                     nome_cor=(130, 255, 236), miudo=(90, 170, 170), cabeca=(8, 20, 30),
                     caneta=(130, 255, 236, 235), bilhete="brilha"),
}


def _fundo_variedade(v: str, img: Image.Image, e: dict) -> Image.Image:
    """Estampa do papel, por baixo de tudo."""
    w, h = img.size
    d = ImageDraw.Draw(img, "RGBA")
    r = random.Random(700 + VARIEDADES.index(v))
    if v == "morcega":
        for _ in range(14):
            morcego(d, r.uniform(160, 500) * K, r.uniform(70, 220) * K, r.uniform(10, 18) * K,
                    (70, 50, 90, 120))
    elif v == "bonsai":
        # Veio de madeira clara: a etiqueta e uma plaquinha.
        for i in range(34):
            y0 = r.uniform(0, h)
            pts = [(x, y0 + math.sin(x / (40 * K) + i) * 6 * K) for x in range(0, w + 1, 8 * K)]
            d.line(pts, fill=(180, 140, 90, 70), width=K)
    elif v == "saca_rolha":
        for i in range(-6, 22):
            x0 = i * 34 * K
            d.line([(x0, 0), (x0 + 120 * K, h)], fill=(26, 110, 102, 22), width=10 * K)
    elif v == "girafa":
        # Manchas de girafa: poligonos marrons com borda clara.
        for gy in range(0, 280, 62):
            for gx in range(-20, 540, 70):
                cx = (gx + (31 if (gy // 62) % 2 else 0) + r.uniform(-10, 10)) * K
                cy = (gy + r.uniform(-8, 8)) * K
                pts = []
                lados = r.randint(5, 7)
                for k in range(lados):
                    a = k / lados * math.tau + r.uniform(-0.3, 0.3)
                    rr = r.uniform(20, 28) * K
                    pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.9))
                d.polygon(pts, fill=(176, 100, 36))
    elif v == "pompom":
        for gy in range(0, 280, 34):
            for gx in range(0, 540, 34):
                cx = (gx + (17 if (gy // 34) % 2 else 0)) * K
                cy = gy * K
                d.ellipse([cx - 7 * K, cy - 7 * K, cx + 7 * K, cy + 7 * K], fill=(255, 244, 248, 200))
    elif v == "chorona":
        for _ in range(60):
            x, y = r.uniform(0, w), r.uniform(0, h)
            gota(d, x, y, r.uniform(7, 12) * K, (120, 160, 220, 90))
    elif v == "gambazona":
        for _ in range(9):
            nuvem(d, r.uniform(150, 500) * K, r.uniform(80, 210) * K, r.uniform(26, 44) * K,
                  (160, 200, 40, 110))
    elif v == "vagalume":
        pass
    return img


def _selo_variedade(v: str, img: Image.Image, e: dict) -> Image.Image:
    d = ImageDraw.Draw(img, "RGBA")
    c = e["cabeca"]
    cx, cy = 90 * K, 138 * K
    if v == "morcega":
        morcego(d, cx, cy + 6 * K, 56 * K, c)
    elif v == "bonsai":
        bonsai_arvore(d, cx, cy + 50 * K, 88 * K, c, c, c)
    elif v == "saca_rolha":
        espiral(d, cx, cy - 52 * K, 84 * K, c, (120, 180, 170))
    elif v == "girafa":
        # A folha la no alto de um pescoco comprido.
        d.line([(cx, cy + 56 * K), (cx + 4 * K, cy - 10 * K)], fill=c, width=5 * K)
        folha(d, cx + 4 * K, cy - 8 * K, 46 * K, c)
        for oy in (20, 38):
            d.ellipse([cx - 3 * K, cy + (oy - 4) * K, cx + 7 * K, cy + (oy + 4) * K],
                      fill=(110, 62, 24))
    elif v == "pompom":
        pirulito(d, cx, cy - 12 * K, 70 * K, c, (255, 190, 214), c)
    elif v == "chorona":
        salgueiro(d, cx, cy - 46 * K, 92 * K, c)
        gota(d, cx + 30 * K, cy + 30 * K, 22 * K, (150, 200, 255))
    elif v == "gambazona":
        fumaca(d, cx, cy - 4 * K, 50 * K, c)
        nuvem(d, cx, cy + 20 * K, 70 * K, c)
    elif v == "vagalume":
        # O vagalume em diagonal: cabeca em cima a esquerda, asas abertas e o
        # rabo aceso embaixo a direita. Em volta, a trilha de pontinhos.
        ang = math.radians(-40)
        eixo = (math.sin(ang), math.cos(ang))

        def ao_longo(t: float, lado: float = 0.0) -> tuple:
            return (cx - eixo[0] * t * K + eixo[1] * lado * K, cy + eixo[1] * t * K + eixo[0] * lado * K)

        rabo = ao_longo(24)
        trilha = [(cx + math.cos(a) * 46 * K, cy + math.sin(a) * 46 * K, 0.5 + 0.3 * math.sin(a * 3))
                  for a in [x * 0.42 + 3.3 for x in range(8)]]
        img = brilho(img, [(rabo[0], rabo[1], 1.0)], (80, 255, 230), 15 * K, 1.5)
        img = brilho(img, trilha, (70, 240, 220), 3.2 * K)
        d = ImageDraw.Draw(img, "RGBA")
        escuro = (22, 26, 40)
        for lado in (-1, 1):
            p = ao_longo(-8, lado * 16)
            elipse_rot(d, p, 24 * K, 9 * K, -ang + lado * 0.6, (170, 214, 230, 150))
        elipse_rot(d, ao_longo(-4), 24 * K, 10 * K, -ang, escuro)
        cab = ao_longo(-30)
        d.ellipse([cab[0] - 9 * K, cab[1] - 9 * K, cab[0] + 9 * K, cab[1] + 9 * K], fill=escuro)
        for lado in (-1, 1):
            a0 = ao_longo(-36, lado * 4)
            a1 = ao_longo(-52, lado * 12)
            d.line([a0, a1], fill=escuro, width=2 * K)
    return img


def elipse_rot(d: ImageDraw.ImageDraw, c: tuple, rx: float, ry: float, ang: float, cor) -> None:
    """Elipse de semieixo rx na direcao (sin ang, cos ang) e ry na perpendicular."""
    ux, uy = math.sin(ang), math.cos(ang)
    pts = []
    for i in range(32):
        t = i / 32 * math.tau
        a, b = math.cos(t) * rx, math.sin(t) * ry
        pts.append((c[0] + ux * a - uy * b, c[1] + uy * a + ux * b))
    d.polygon(pts, fill=cor)


def rotulo_variedade(v: str) -> Image.Image:
    e = ESTILO_VAR[v]
    x0, y0, w1, h1 = REG_VAR[v]
    w, h = w1 * K, h1 * K
    img = Image.new("RGB", (w, h), e["fundo"])
    img = ruido_papel(img, 8, 40 + VARIEDADES.index(v))
    img = _fundo_variedade(v, img, e)
    if v == "vagalume":
        r = random.Random(77)
        pontos = [(r.uniform(150, 500) * K, r.uniform(64, 220) * K, r.uniform(0.5, 1.0))
                  for _ in range(26)]
        img = brilho(img, pontos, (70, 240, 220), 3.2 * K)
    d = ImageDraw.Draw(img, "RGBA")
    faixa = e["faixa"]
    # Faixas e filetes: a mesma arquitetura do SKUNK.
    d.rectangle([0, 0, w, 58 * K], fill=faixa)
    d.rectangle([0, h - 34 * K, w, h], fill=faixa)
    d.rectangle([0, 58 * K, w, 62 * K], fill=e["filete"])
    d.rectangle([0, h - 38 * K, w, h - 34 * K], fill=e["filete"])
    if v == "gambazona":
        # Fita de perigo embaixo: preto e limao na diagonal.
        for i in range(-2, 40):
            xa = i * 26 * K
            d.polygon([(xa, h - 34 * K), (xa + 13 * K, h - 34 * K), (xa - 1 * K, h), (xa - 14 * K, h)],
                      fill=(206, 232, 72))
    cab = "ESTUFA  \u2022  ANDAR %d" % e["andar"] if v != "vagalume" else "ESTUFA  \u2022  ANDAR 9 (?)"
    texto_centro(d, w * 0.5, 30 * K, cab, caber(cab, "impact.ttf", 340 * K, 40 * K), e["cabeca"])
    # Selo redondo.
    d.ellipse([28 * K, 76 * K, 152 * K, 200 * K], fill=faixa)
    d.ellipse([28 * K, 76 * K, 152 * K, 200 * K], outline=e["filete"], width=2 * K)
    img = _selo_variedade(v, img, e)
    d = ImageDraw.Draw(img, "RGBA")
    # Nome: cabe na largura, e a placa por tras quando o fundo e estampado.
    fn = caber(e["nome"], "impact.ttf", 318 * K, 66 * K)
    bx = d.textbbox((172 * K, 76 * K), e["nome"], font=fn)
    if v == "girafa":
        # Placa lisa atras do texto todo: a mancha de girafa comia o miudo.
        d.rounded_rectangle([164 * K, 70 * K, 500 * K, 214 * K], radius=10 * K, fill=(250, 232, 170))
    elif v in ("pompom", "gambazona", "chorona"):
        d.rounded_rectangle([bx[0] - 6 * K, bx[1] - 5 * K, bx[2] + 6 * K, bx[3] + 5 * K], radius=6 * K,
                            fill=e["fundo"])
    if v == "vagalume":
        glow = Image.new("RGB", img.size, (0, 0, 0))
        ImageDraw.Draw(glow).text((172 * K, 76 * K), e["nome"], font=fn, fill=(40, 160, 150))
        img = ImageChops.add(img, glow.filter(ImageFilter.GaussianBlur(6 * K)))
        d = ImageDraw.Draw(img, "RGBA")
    d.text((172 * K, 76 * K), e["nome"], font=fn, fill=e["nome_cor"])
    fs = caber(e["sub"], "arialbd.ttf", 318 * K, 17 * K)
    sy = max(bx[3] + 10 * K, 150 * K)
    d.text((174 * K, sy), e["sub"], font=fs, fill=e["miudo"])
    for i in range(3):
        d.rectangle([174 * K, (sy + 30 * K + i * 9 * K), (174 + 150 - i * 30) * K, (sy + 34 * K + i * 9 * K)],
                    fill=e["miudo"])
    # O bilhete a caneta, torto, embaixo a direita.
    nota = Image.new("RGBA", (220 * K, 70 * K), (0, 0, 0, 0))
    dn = ImageDraw.Draw(nota)
    caneta = "segoeprb.ttf" if (FONTES / "segoeprb.ttf").exists() else "arialbd.ttf"
    dn.text((8 * K, 50 * K), e["bilhete"], font=caber(e["bilhete"], caneta, 200 * K, 34 * K),
            fill=e["caneta"], anchor="ls")
    nota = nota.rotate(7, resample=Image.BICUBIC, expand=True)
    img.paste(nota, (296 * K, 158 * K), nota)
    claro = sum(e["fundo"]) > 380
    return desgaste(img, 50 + VARIEDADES.index(v), 20,
                    (255, 255, 255, 50) if not claro else (120, 100, 70, 40))


def main() -> None:
    atlas = Image.new("RGB", (LADO * K, LADO * K), (128, 128, 128))
    pecas = [
        (REG_POTE, rotulo_pote()),
        (REG_POTE_SUPER, rotulo_super()),
        (REG_SACO, saco()),
        (REG_ENV_FRENTE, envelope_frente()),
        (REG_ENV_VERSO, envelope_verso()),
        (REG_KRAFT, kraft()),
        (REG_CRIVO, crivo()),
        (REG_TERRA, terra()),
    ]
    for (x, y, _w, _h), img in pecas:
        atlas.paste(img.convert("RGB"), (x * K, y * K))
    atlas = atlas.resize((LADO, LADO), Image.LANCZOS)
    # A folha das variedades e reduzida a parte: o Lanczos da emenda puxaria a
    # borda de baixo dos rotulos antigos.
    folha_var = Image.new("RGB", (LADO * K, (ALTURA - LADO) * K), (128, 128, 128))
    for v in VARIEDADES:
        x, y, _w, _h = REG_VAR[v]
        folha_var.paste(rotulo_variedade(v).convert("RGB"), (x * K, (y - LADO) * K))
    folha_var = folha_var.resize((LADO, ALTURA - LADO), Image.LANCZOS)
    final = Image.new("RGB", (LADO, ALTURA), (128, 128, 128))
    final.paste(atlas, (0, 0))
    final.paste(folha_var, (0, LADO))
    atlas = final
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(SAIDA, optimize=True)
    print(f"{SAIDA} ({SAIDA.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()

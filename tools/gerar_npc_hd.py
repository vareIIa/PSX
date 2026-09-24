"""O atlas de gente em 4x, para o conjunto HD do MODERNO.

O atlas de 256 px e desenhado pixel a pixel (ver gerar_npc.py). No PS1 STYLE ele
e lido com filtro ponto e e exatamente o que deve ser. No MODERNO a mesma cara
de 32 px ocupa a foto inteira da carteira numa tela 4K, e ai o filtro ponto
mostra degrau e o linear mostra borrao — nenhum dos dois e acabamento.

O que se faz aqui e ampliar com Scale2x, duas vezes: um pixel vira quatro, e a
regra olha os vizinhos para arredondar so as DIAGONAIS (a borda da sobrancelha,
o contorno do labio, o aro dos oculos), mantendo as retas retas e as cores
exatamente as do desenho. Nao inventa detalhe nem cor: e o mesmo desenho, com
o serrilhado de 32 px trocado por curva. O shader do MODERNO le isto com filtro
linear e mipmap (`albedo_hd`), e `TexturasHD` casa pelo nome do arquivo.

Celula por celula, com a borda repetida: o atlas e um mosaico de pecas
diferentes, e uma regra que olhasse o vizinho do outro lado da costura puxaria
cabelo para dentro da cara.

Tecido
------
Nas celulas de roupa o 4x ganha o que o desenho de 32 px nao tem espaco para
ter: a TRAMA. Cada familia de peca tem a sua — malha fina na camisa e na manga,
sarja diagonal na calca, trama cruzada no agasalho, couro granulado no sapato —
entrando de leve na cor e forte no mapa de normal (`npc_atlas_n.png`). O mapa
de normal leva tambem o relevo do PROPRIO desenho: a costura, o bolso, o botao
e o ziper que ja estavam pintados viram sulco e saliencia, porque saem do
passa-alta da luminancia (linha escura afunda, ponto claro sobe). Rosto, pele e
cabelo ficam de normal plana: a cabeca do jogo e caixa pintada, e deve ser.

    python tools/gerar_npc_hd.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
ORIGEM = RAIZ / "game" / "assets" / "textures" / "npc_atlas.png"
DESTINO = RAIZ / "game" / "assets" / "textures_hd" / "npc_atlas.png"
DESTINO_N = RAIZ / "game" / "assets" / "textures_hd" / "npc_atlas_n.png"
CELULA = 32
ESCALA = 4

# Linhas do atlas (ver Aparencia / gerar_npc.py).
LINHA_PECAS = 2
LINHA_CAMISA = 4
LINHA_COSTAS = 5
LINHA_CALCA = 6
LINHA_CASACO = 7
PECA_MANGA = 4
PECAS_SAPATO = (5, 6, 7)

# Familia de tecido por celula. Forca: quanto a trama entra na cor e na normal,
# e quanto o desenho vira relevo.
MALHA = {"trama": "malha", "cor": 0.05, "normal": 1.0, "desenho": 1.4}
SARJA = {"trama": "sarja", "cor": 0.07, "normal": 1.2, "desenho": 1.6}
LONA = {"trama": "lona", "cor": 0.05, "normal": 1.0, "desenho": 1.6}
COURO = {"trama": "couro", "cor": 0.04, "normal": 0.8, "desenho": 1.2}


def familia(cx: int, cy: int):
    if cy in (LINHA_CAMISA, LINHA_COSTAS):
        return MALHA
    if cy == LINHA_CALCA:
        return SARJA
    if cy == LINHA_CASACO:
        return LONA
    if cy == LINHA_PECAS and cx == PECA_MANGA:
        return MALHA
    if cy == LINHA_PECAS and cx in PECAS_SAPATO:
        return COURO
    return None


def scale2x(px: list, w: int, h: int) -> list:
    """Scale2x (EPX) numa grade de tuplas, com a borda repetida."""
    saida = [[None] * (w * 2) for _ in range(h * 2)]
    for y in range(h):
        for x in range(w):
            p = px[y][x]
            a = px[max(0, y - 1)][x]
            b = px[y][min(w - 1, x + 1)]
            c = px[y][max(0, x - 1)]
            d = px[min(h - 1, y + 1)][x]
            e0 = a if (c == a and c != d and a != b) else p
            e1 = b if (a == b and a != c and b != d) else p
            e2 = c if (d == c and d != b and c != a) else p
            e3 = d if (b == d and b != a and d != c) else p
            saida[y * 2][x * 2] = e0
            saida[y * 2][x * 2 + 1] = e1
            saida[y * 2 + 1][x * 2] = e2
            saida[y * 2 + 1][x * 2 + 1] = e3
    return saida


def trama(tipo: str, x: int, y: int, ruido: list, lado: int) -> float:
    """Altura da trama em [-1, 1], periodica dentro da celula de `lado` px."""
    if tipo == "malha":
        # Colunas de laçada: sulco vertical a cada 3 px, e a laçada em V.
        col = math.sin(2 * math.pi * x / 3.0)
        lac = math.sin(2 * math.pi * (y + (x % 3) * 0.7) / 4.0)
        return 0.75 * col + 0.25 * lac
    if tipo == "sarja":
        # Diagonal de sarja, a 2 por 1, como brim de calca.
        return math.sin(2 * math.pi * (x + 2 * y) / 6.0)
    if tipo == "lona":
        return math.sin(2 * math.pi * x / 4.0) * math.sin(2 * math.pi * y / 4.0)
    # Couro: grao de ruido suavizado.
    return ruido[y % lado][x % lado]


def _dados(im: Image.Image) -> list:
    """Pixels da imagem em lista, sem o aviso de obsoleto do Pillow novo."""
    ler = getattr(im, "get_flattened_data", None)
    return list(ler()) if ler is not None else list(im.getdata())


def _ruido_suave(lado: int, rng: random.Random) -> list:
    im = Image.new("L", (lado, lado))
    im.putdata([rng.randint(0, 255) for _ in range(lado * lado)])
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    px = list(_dados(im))
    lo, hi = min(px), max(px)
    esc = 2.0 / max(1, hi - lo)
    return [[(px[y * lado + x] - lo) * esc - 1.0 for x in range(lado)] for y in range(lado)]


def tecer(img: Image.Image, fam: dict, rng: random.Random) -> Image.Image:
    """Normal da celula, e a trama aplicada na cor de `img` (in place)."""
    lado = img.size[0]
    ruido = _ruido_suave(lado, rng)
    lum = img.convert("L")
    borrado = lum.filter(ImageFilter.GaussianBlur(3.0))
    lp = list(_dados(lum))
    bp = list(_dados(borrado))
    alfa = list(_dados(img.getchannel("A")))
    altura = []
    cor = img.load()
    for y in range(lado):
        for x in range(lado):
            i = y * lado + x
            t = trama(fam["trama"], x, y, ruido, lado)
            fio = (rng.random() - 0.5) * 0.3
            # Passa-alta do desenho: linha escura vira sulco, ponto claro sobe.
            desenho = (lp[i] - bp[i]) / 255.0 * fam["desenho"] * 4.0
            h = 0.35 * t * fam["normal"] + 0.1 * fio + desenho
            altura.append(h if alfa[i] > 0 else 0.0)
            if alfa[i] > 0:
                k = 1.0 + fam["cor"] * t + 0.02 * fio
                r, g, b, a = cor[x, y]
                cor[x, y] = (min(255, int(r * k)), min(255, int(g * k)),
                             min(255, int(b * k)), a)
    normal = Image.new("RGB", (lado, lado))
    npx = normal.load()
    for y in range(lado):
        for x in range(lado):
            # Borda repetida, como no Scale2x: a costura da celula nao pode
            # puxar relevo da peca vizinha.
            hx0 = altura[y * lado + max(0, x - 1)]
            hx1 = altura[y * lado + min(lado - 1, x + 1)]
            hy0 = altura[max(0, y - 1) * lado + x]
            hy1 = altura[min(lado - 1, y + 1) * lado + x]
            # Convencao OpenGL (verde para cima), a do Godot: a imagem desce
            # em y, entao o declive em y entra com o sinal trocado.
            nx = -(hx1 - hx0) * 0.5
            ny = (hy1 - hy0) * 0.5
            nz = 1.0
            m = math.sqrt(nx * nx + ny * ny + nz * nz)
            npx[x, y] = (int((nx / m * 0.5 + 0.5) * 255), int((ny / m * 0.5 + 0.5) * 255),
                         int((nz / m * 0.5 + 0.5) * 255))
    return normal


def gerar() -> None:
    atlas = Image.open(ORIGEM).convert("RGBA")
    largura, altura = atlas.size
    lado = CELULA * ESCALA
    hd = Image.new("RGBA", (largura * ESCALA, altura * ESCALA), (0, 0, 0, 0))
    normais = Image.new("RGB", hd.size, (128, 128, 255))
    rng = random.Random(1987)
    for cy in range(altura // CELULA):
        for cx in range(largura // CELULA):
            cel = atlas.crop((cx * CELULA, cy * CELULA, (cx + 1) * CELULA,
                              (cy + 1) * CELULA))
            if cel.getbbox() is None:
                continue
            px = [[cel.getpixel((x, y)) for x in range(CELULA)]
                  for y in range(CELULA)]
            px = scale2x(px, CELULA, CELULA)
            px = scale2x(px, CELULA * 2, CELULA * 2)
            img = Image.new("RGBA", (lado, lado))
            img.putdata([c for linha in px for c in linha])
            fam = familia(cx, cy)
            if fam is not None:
                normais.paste(tecer(img, fam, rng), (cx * lado, cy * lado))
            hd.paste(img, (cx * lado, cy * lado))
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    hd.save(DESTINO, "PNG", optimize=True)
    normais.save(DESTINO_N, "PNG", optimize=True)
    print("npc_atlas hd         %dx%d (+ normal)" % hd.size)


if __name__ == "__main__":
    gerar()

#!/usr/bin/env python3
"""Texturas do parque: o canteiro de flores, a agua do lago e o nenufar.

Por que as flores sao um atlas e nao uma textura por especie
------------------------------------------------------------
Uma flor no jogo e um par de planos cruzados de meio metro. A 480x270, a
trinta metros, ela ocupa quatro pixels. Dar textura propria a cada especie
seria oito materiais — oito trocas de estado por chunk de parque — para uma
diferenca que so existe de perto. Um atlas de 8x8 celulas de 32 px, no mesmo
formato do resto do jogo (Carroceria.uv), poe todas no mesmo desenho e todas
no mesmo material.

Por que a flor e desenhada DE LADO
-----------------------------------
Porque e assim que ela e vista. O plano cruzado fica em pe no chao, entao a
celula tem de conter a planta inteira em perfil: caule saindo da borda de
baixo, folhas no meio, botao no alto. A tentacao e desenhar a flor vista de
cima, que e como se desenha um icone — e o resultado no jogo e um adesivo
flutuando de canto para o jogador.

Cada celula e desenhada em 128 px e reduzida para 32 com LANCZOS. Desenhar
direto em 32 da petala de um pixel com serrilhado de escada; reduzir de 128
da a mesma petala com a borda macia que o alfa depois recorta.

Por que a agua e uma textura e nao so o shader
-----------------------------------------------
O psx_agua.gdshader rola DUAS copias desta textura em velocidades e direcoes
diferentes e soma. Sozinho, o shader daria uma superficie de cor lisa com
ondas de vertice; sozinha, a textura daria um lago congelado. O movimento que
se le como agua nasce do batimento entre as duas copias, e para isso a textura
precisa de estrutura em duas escalas: a ondulacao larga e o brilho fino.

    python tools/gerar_parque.py
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "textures"

CELULA = 32
GRADE = 8
ATLAS = CELULA * GRADE
## Fator de supersampling da celula. Ver o cabecalho.
ESCALA = 4
D = CELULA * ESCALA

LADO_AGUA = 128
VAZIO = (0, 0, 0, 0)

rng = np.random.default_rng(6421)


def salvar(nome: str, img: Image.Image, cores: int = 64) -> None:
    SAIDA.mkdir(parents=True, exist_ok=True)
    metodo = Image.FASTOCTREE if img.mode == "RGBA" else Image.MEDIANCUT
    img.quantize(colors=cores, method=metodo).save(SAIDA / f"{nome}.png", "PNG",
                                                   optimize=True)
    print(f"{nome:24s} {img.width}x{img.height}  {img.mode}")


def fbm(lado: int, oitavas: int = 5, persist: float = 0.55) -> np.ndarray:
    """Ruido fractal que fecha nas bordas. Mesma receita do gerar_cidade."""
    out = np.zeros((lado, lado), dtype=np.float64)
    amp, total = 1.0, 0.0
    for o in range(oitavas):
        res = 2 ** (o + 1)
        if res > lado:
            break
        baixo = rng.random((res, res))
        grade = np.tile(baixo, (2, 2))
        img = Image.fromarray((grade * 255).astype(np.uint8)).resize(
            (lado * 2, lado * 2), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64)[:lado, :lado] / 255.0 * amp
        total += amp
        amp *= persist
    return out / max(total, 1e-6)


def norm(a: np.ndarray) -> np.ndarray:
    lo, hi = a.min(), a.max()
    return (a - lo) / max(hi - lo, 1e-6)


def rampa(m: np.ndarray, escuro: str, claro: str) -> np.ndarray:
    d = np.array([int(escuro.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    c = np.array([int(claro.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    x = m[..., None]
    return d * (1.0 - x) + c * x


# --- desenho das celulas ----------------------------------------------------

def tela() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    c = Image.new("RGBA", (D, D), VAZIO)
    return c, ImageDraw.Draw(c)


def reduzir(c: Image.Image) -> Image.Image:
    """Volta para 32 px e endurece o alfa.

    O corte em 110 e proposital: LANCZOS deixa uma auréola de alfa baixo em
    volta da petala, e o ALPHA_SCISSOR do material corta em 0,45. Sem endurecer
    aqui, a flor ganha uma borda de pixels quase transparentes que o scissor
    mantem e que aparecem como sujeira cinza contra o ceu."""
    p = c.resize((CELULA, CELULA), Image.LANCZOS)
    a = np.asarray(p, dtype=np.int16).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def caule(d: ImageDraw.ImageDraw, x: float, topo: float, cor: tuple,
          curva: float = 0.0, grosso: int = 3) -> None:
    """Caule em arco. Reto ele le como arame; a curva e o que faz vergar."""
    pontos = []
    for i in range(9):
        t = i / 8.0
        y = D - 1 - (D - 1 - topo) * t
        # A curva cresce com o quadrado: o pe fica firme e a ponta que balanca.
        pontos.append((x + curva * t * t, y))
    d.line(pontos, fill=cor, width=grosso, joint="curve")


def folha(d: ImageDraw.ImageDraw, x: float, y: float, comp: float,
          ang: float, cor: tuple) -> None:
    ex = x + math.cos(ang) * comp
    ey = y - math.sin(ang) * comp
    meio = ((x + ex) * 0.5, (y + ey) * 0.5 - comp * 0.18)
    d.polygon([(x, y), meio, (ex, ey),
               ((x + ex) * 0.5, (y + ey) * 0.5 + comp * 0.16)], fill=cor)


def corola(d: ImageDraw.ImageDraw, x: float, y: float, raio: float,
           petalas: int, cor: tuple, miolo: tuple, giro: float = 0.0) -> None:
    for k in range(petalas):
        a = math.tau * k / petalas + giro
        px = x + math.cos(a) * raio * 0.62
        py = y - math.sin(a) * raio * 0.62
        r = raio * 0.46
        d.ellipse((px - r, py - r, px + r, py + r), fill=cor)
    r = raio * 0.34
    d.ellipse((x - r, y - r, x + r, y + r), fill=miolo)


VERDE = (86, 106, 58, 255)
VERDE_CLARO = (112, 134, 72, 255)
VERDE_ESCURO = (62, 80, 44, 255)


def moita(cor_flor: tuple, miolo: tuple, petalas: int, n: int,
          alto: float, raio: float) -> Image.Image:
    """Um punhado da mesma flor. Uma flor sozinha nao existe num canteiro."""
    c, d = tela()
    postos = []
    for i in range(n):
        t = (i + 0.5) / n
        x = D * (0.14 + 0.72 * t) + rng.uniform(-D * 0.05, D * 0.05)
        topo = D * (1.0 - alto * rng.uniform(0.72, 1.0))
        curva = rng.uniform(-D * 0.07, D * 0.07)
        postos.append((x, topo, curva))
    # Todos os caules primeiro, todas as corolas depois: assim nenhum caule
    # passa por cima de uma flor vizinha.
    for x, topo, curva in postos:
        caule(d, x, topo, VERDE, curva)
        folha(d, x, D * 0.78, D * 0.13, rng.uniform(0.1, 0.7) + (0 if rng.random() < 0.5 else math.pi), VERDE_ESCURO)
    for x, topo, curva in postos:
        corola(d, x + curva, topo, D * raio, petalas, cor_flor, miolo,
               rng.uniform(0.0, 1.0))
    return c


def espiga(cor_flor: tuple) -> Image.Image:
    """Lavanda: nao tem corola, tem espiga. E a silhueta que a distingue."""
    c, d = tela()
    for i in range(7):
        x = D * (0.16 + 0.68 * (i + 0.5) / 7) + rng.uniform(-D * 0.03, D * 0.03)
        topo = D * rng.uniform(0.18, 0.34)
        curva = rng.uniform(-D * 0.09, D * 0.09)
        caule(d, x, topo, VERDE, curva, 2)
        for k in range(9):
            t = k / 8.0
            bx = x + curva * (0.35 + t) * 0.5
            by = topo + (D * 0.30) * t
            r = D * 0.035 * (1.0 - t * 0.4)
            tom = tuple(min(255, v + int(26 * (1.0 - t))) for v in cor_flor[:3]) + (255,)
            d.ellipse((bx - r, by - r, bx + r, by + r), fill=tom)
    return c


def capim() -> Image.Image:
    """Tufo de capim alto. Preenche o canteiro entre as flores e some sozinho
    na distancia, que e o que se quer dele."""
    c, d = tela()
    for i in range(14):
        x = D * rng.uniform(0.1, 0.9)
        alt = D * rng.uniform(0.42, 0.9)
        curva = rng.uniform(-D * 0.22, D * 0.22)
        cor = VERDE_CLARO if rng.random() < 0.4 else VERDE
        if rng.random() < 0.18:
            cor = (140, 138, 86, 255)
        caule(d, x, D - alt, cor, curva, 2)
    return c


def taboa() -> Image.Image:
    """Junco de beira de lago, com a espiga marrom. E a planta que diz 'agua
    parada' sem precisar de mais nada."""
    c, d = tela()
    for i in range(9):
        x = D * rng.uniform(0.12, 0.88)
        alt = D * rng.uniform(0.6, 0.98)
        curva = rng.uniform(-D * 0.1, D * 0.1)
        caule(d, x, D - alt, VERDE_ESCURO, curva, 3)
        if rng.random() < 0.55:
            topo = D - alt
            w = D * 0.055
            d.rounded_rectangle((x + curva - w, topo, x + curva + w, topo + D * 0.22),
                                radius=int(w), fill=(104, 72, 42, 255))
            d.line((x + curva, topo, x + curva, topo - D * 0.1),
                   fill=VERDE_ESCURO, width=2)
    return c


def nenufar(com_flor: bool) -> Image.Image:
    """Vista de CIMA — esta celula vai deitada na agua, nao em pe."""
    c, d = tela()
    for i in range(4 if com_flor else 6):
        r = D * rng.uniform(0.13, 0.21)
        x = D * rng.uniform(0.2, 0.8)
        y = D * rng.uniform(0.2, 0.8)
        tom = (rng.integers(58, 74), rng.integers(84, 104), rng.integers(46, 60), 255)
        tom = tuple(int(v) for v in tom)
        d.ellipse((x - r, y - r, x + r, y + r), fill=tom)
        # A fenda em V. E o unico detalhe que faz o disco virar folha.
        a = rng.uniform(0.0, math.tau)
        d.polygon([(x, y),
                   (x + math.cos(a - 0.3) * r * 1.1, y + math.sin(a - 0.3) * r * 1.1),
                   (x + math.cos(a + 0.3) * r * 1.1, y + math.sin(a + 0.3) * r * 1.1)],
                  fill=VAZIO)
        d.arc((x - r, y - r, x + r, y + r), 0, 360, fill=(46, 64, 38, 255), width=2)
    if com_flor:
        x, y = D * 0.5, D * 0.46
        corola(d, x, y, D * 0.19, 8, (238, 226, 234, 255), (232, 206, 120, 255))
    return c


# --- agua -------------------------------------------------------------------

def agua_lago() -> None:
    """Agua de lago: verde-escura por baixo, com ondulacao larga e brilho fino.

    Duas escalas, e nao uma. Ver o cabecalho — o shader rola duas copias desta
    imagem e o batimento entre elas so vira movimento se cada escala andar por
    conta propria."""
    onda = norm(fbm(LADO_AGUA, 3, 0.5))
    fino = norm(fbm(LADO_AGUA, 7, 0.8))
    # A onda larga domina; o fino entra como textura de superficie.
    m = np.clip(onda * 0.72 + fino * 0.28, 0.0, 1.0)
    arr = rampa(m ** 1.3, "#16262a", "#3f6b66")

    # Cristas: a linha de brilho no alto da ondulacao. Estreita de proposito —
    # brilho largo le como gelo, e o que se quer e o reflexo quebrado do ceu.
    crista = (onda > 0.72) & (fino > 0.52)
    arr[crista] = arr[crista] * 0.3 + np.array([150, 178, 176]) * 0.7
    borda = (onda > 0.64) & (onda <= 0.72)
    arr[borda] = arr[borda] * 0.7 + np.array([96, 126, 126]) * 0.3

    # Verde de fundo em manchas: limo. Sem ele a agua e azul de piscina, e o
    # lago do parque nao e uma piscina.
    limo = norm(fbm(LADO_AGUA, 4, 0.62))
    arr = arr * (1.0 - limo[..., None] * 0.22) + np.array([44, 64, 46]) * limo[..., None] * 0.22
    arr += rng.normal(0.0, 3.0, arr.shape)
    salvar("agua_lago", Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"))


def espuma() -> None:
    """Faixa de espuma da margem. Uma tira: opaca embaixo, sumindo para cima."""
    a = np.zeros((LADO_AGUA, LADO_AGUA, 4), dtype=np.float64)
    ruido = norm(fbm(LADO_AGUA, 6, 0.75))
    queda = np.linspace(1.0, 0.0, LADO_AGUA)[:, None] ** 1.6
    alfa = np.clip((ruido * 0.75 + 0.35) * queda * 1.8 - 0.22, 0.0, 1.0)
    a[..., 0] = 214 + ruido * 30
    a[..., 1] = 226 + ruido * 24
    a[..., 2] = 224 + ruido * 24
    a[..., 3] = np.where(alfa > 0.34, 255, 0)
    salvar("espuma", Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA"), 32)


# --- atlas ------------------------------------------------------------------

def main() -> int:
    im = Image.new("RGBA", (ATLAS, ATLAS), VAZIO)

    celulas = {
        (0, 0): moita((242, 240, 232, 255), (232, 200, 92, 255), 5, 5, 0.62, 0.075),
        (1, 0): moita((196, 56, 48, 255), (58, 40, 34, 255), 5, 4, 0.70, 0.085),
        (2, 0): moita((228, 186, 62, 255), (198, 148, 40, 255), 6, 4, 0.66, 0.080),
        (3, 0): espiga((132, 106, 186, 255)),
        (4, 0): capim(),
        (5, 0): taboa(),
        (6, 0): moita((226, 168, 54, 255), (86, 62, 34, 255), 9, 3, 0.86, 0.105),
        (7, 0): moita((222, 128, 172, 255), (236, 214, 132, 255), 6, 6, 0.52, 0.065),
        (0, 1): nenufar(False),
        (1, 1): nenufar(True),
    }
    for (col, lin), c in celulas.items():
        im.paste(reduzir(c), (col * CELULA, lin * CELULA))

    salvar("flores", im, 64)
    agua_lago()
    espuma()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

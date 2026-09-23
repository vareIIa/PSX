#!/usr/bin/env python3
"""Atlas da vegetacao da cidade: os cartoes de que a copa e feita.

Por que cartao, e nao caixa
---------------------------
A arvore da cidade era um tronco com cinco caixas de folha em volta
(KitParque.arvore, KitEstrada.arvore). A caixa com textura de folha repetida
le de longe como cubo verde: a silhueta e reta, e a luz cai igual nas quatro
faces. Arvore de jogo AAA e feita de cartao: um quadrilatero com a silhueta de
um RAMO desenhada no alfa, varios deles cruzados em volta do volume da copa, e
a normal de cada vertice apontando para fora do centro da copa (Vegetacao) — a
luz sai redonda e a borda sai recortada, como a de uma arvore.

As celulas (4 x 4)
------------------
    linha 0   ramo_mangueira   ramo_miudo (oiti)   ramo_claro (abacateiro)   ramo_seco
    linha 1   ipe_amarelo      ipe_rosa            primavera                 mata (copa de longe)
    linha 2   palma            bananeira           bambu                     arbusto
    linha 3   touceira         hera                flor_canteiro             sombra (miolo da copa)

A folha e desenhada, uma a uma (elipse girada, tres camadas de tom, a de cima
mais clara) dentro de uma silhueta de aglomerado; a flor, em cachos. Cada
celula guarda uma margem livre, e a cor da folha e espalhada por baixo do alfa
zero: o mipmap nao puxa preto nem a celula vizinha para a borda do recorte.

    python tools/gerar_vegetacao.py          os dois conjuntos
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "textures"
SAIDA_HD = RAIZ / "game" / "assets" / "textures_hd"

## Lado da celula no conjunto HD; o do PS1 e 1/8 disto (atlas de 256).
CEL = 512
N = 4
MARGEM = 0.06
rng = np.random.default_rng(5501)


def cor(c, var: float = 0.0):
    r, g, b = c
    k = 1.0 + rng.uniform(-var, var)
    return (int(np.clip(r * k, 0, 255)), int(np.clip(g * k, 0, 255)),
            int(np.clip(b * k, 0, 255)), 255)


def elipse(d: ImageDraw.ImageDraw, cx, cy, comp, larg, ang, c, ponta=0.0):
    """Folha: elipse girada, com a ponta afinada (`ponta` > 0 puxa uma ponta)."""
    pts = []
    for k in range(18):
        t = k / 18 * math.tau
        x = math.cos(t) * comp
        y = math.sin(t) * larg * (1.0 - ponta * max(0.0, math.cos(t)) ** 2)
        ca, sa = math.cos(ang), math.sin(ang)
        pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    d.polygon(pts, fill=c)


def _impar(v: float) -> int:
    k = max(3, int(v))
    return k if k % 2 == 1 else k + 1


def silhueta(lado: int, lobos: int, raio: float, achata: float = 1.0,
             centro=(0.5, 0.52)) -> np.ndarray:
    """Mascara de aglomerado: uniao de circulos em volta do centro."""
    yy, xx = np.mgrid[0:lado, 0:lado] / lado
    m = np.zeros((lado, lado), dtype=bool)
    cx, cy = centro
    m |= ((xx - cx) ** 2 + ((yy - cy) / achata) ** 2) < (raio * 0.62) ** 2
    for _ in range(lobos):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.25, 0.62) * raio
        r = rng.uniform(0.28, 0.42) * raio
        px, py = cx + math.cos(a) * d, cy + math.sin(a) * d * achata
        m |= ((xx - px) ** 2 + ((yy - py) / achata) ** 2) < r ** 2
    return m


def ramo(lado: int, paleta, comp: float, larg: float, n: int, lobos=9, raio=0.44,
         ponta=0.5, achata=0.92, brilho=None, centro=(0.5, 0.52),
         im: Image.Image | None = None) -> Image.Image:
    """Aglomerado de folha: `n` folhas em tres camadas, dentro da silhueta."""
    mask = silhueta(lado, lobos, raio, achata, centro)
    alvo = np.argwhere(mask)
    if im is None:
        im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for camada, (c0, frac) in enumerate(zip(paleta, (0.45, 0.35, 0.2))):
        for _ in range(int(n * frac)):
            y, x = alvo[rng.integers(len(alvo))]
            # A camada de cima fica no alto do aglomerado: luz de cima.
            if camada == 2 and y > lado * (centro[1] + raio * 0.2) and rng.random() < 0.7:
                continue
            s = rng.uniform(0.75, 1.25)
            elipse(d, x, y, comp * lado * s, larg * lado * s, rng.uniform(0, math.tau),
                   cor(c0, 0.1), ponta)
    # A franja: folha solta rareando em volta do aglomerado. Sem ela cada cartao
    # tinha contorno fechado e a copa lia como um cacho de bolas.
    dentro = mask
    for alcance, frac in ((0.05, 0.1), (0.11, 0.035)):
        fora = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255, "L")
                          .filter(ImageFilter.MaxFilter(_impar(lado * alcance)))) > 0
        anel = np.argwhere(fora & ~dentro)
        dentro = fora
        if not len(anel):
            continue
        for _ in range(int(n * frac)):
            y, x = anel[rng.integers(len(anel))]
            s = rng.uniform(0.7, 1.1)
            elipse(d, x, y, comp * lado * s, larg * lado * s, rng.uniform(0, math.tau),
                   cor(paleta[1], 0.12), ponta)
    if brilho is not None:
        # O reflexo da folha lisa (mangueira): um traco claro em poucas folhas.
        for _ in range(n // 16):
            y, x = alvo[rng.integers(len(alvo))]
            if y > lado * 0.5:
                continue
            elipse(d, x, y, comp * lado * 0.7, larg * lado * 0.7, rng.uniform(0, math.tau),
                   cor(brilho, 0.08), 0.5)
    return im


def cacho(lado: int, folhas, flores, n_folha: int, n_flor: int, raio=0.44,
          tam_flor=0.022) -> Image.Image:
    """Copa florida (ipe, primavera): poucas folhas e muitos cachos de flor."""
    im = ramo(lado, folhas, 0.03, 0.013, n_folha, raio=raio)
    mask = silhueta(lado, 10, raio, 0.9)
    alvo = np.argwhere(mask)
    d = ImageDraw.Draw(im)
    for camada, c0 in enumerate(flores):
        for _ in range(n_flor // len(flores)):
            y, x = alvo[rng.integers(len(alvo))]
            if camada == len(flores) - 1 and y > lado * 0.62:
                continue
            # Cacho: cinco petalas em volta de um ponto.
            r = tam_flor * lado * rng.uniform(0.7, 1.3)
            for k in range(5):
                a = k / 5 * math.tau + rng.uniform(0, 1)
                elipse(d, x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.6, r * 0.7,
                       r * 0.45, a, cor(c0, 0.08))
    return im


def mata(lado: int) -> Image.Image:
    """Copa de mata vista de longe: cinco copas encostadas, a de tras mais alta e
    mais escura, e o pe fechado (nao ha ceu entre os troncos da mata)."""
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    paletas = [((30, 52, 28), (46, 74, 36), (76, 104, 52)),
               ((36, 60, 30), (56, 86, 42), (92, 118, 58)),
               ((44, 66, 34), (68, 94, 46), (112, 128, 66))]
    copas = [(0.3, 0.36, 0.2), (0.68, 0.34, 0.2), (0.18, 0.56, 0.18), (0.5, 0.52, 0.22),
             (0.82, 0.56, 0.17)]
    # O pe primeiro, atras: folha escura e larga, sem ceu entre os troncos.
    ramo(lado, ((22, 38, 20), (30, 50, 26), (42, 66, 32)), 0.02, 0.012, 2600, lobos=12,
         raio=0.42, achata=0.5, centro=(0.5, 0.7), im=im)
    for k, (cx, cy, r) in enumerate(copas):
        ramo(lado, paletas[k % 3], 0.02, 0.012, 1400, lobos=8, raio=r * 1.15, achata=0.85,
             centro=(cx, cy), im=im)
    return im


def palma(lado: int) -> Image.Image:
    """Folha de palmeira: raque em arco do canto de baixo a esquerda ate a direita,
    foliolos pendendo dos dois lados."""
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = []
    for k in range(41):
        t = k / 40
        x = lado * (0.08 + 0.84 * t)
        y = lado * (0.5 - 0.22 * math.sin(t * math.pi * 0.85) + 0.1 * t)
        pts.append((x, y))
    for k in range(1, 40):
        x, y = pts[k]
        dx = pts[k + 1][0] - pts[k - 1][0]
        dy = pts[k + 1][1] - pts[k - 1][1]
        ang = math.atan2(dy, dx)
        comp = lado * 0.2 * math.sin(math.pi * min(1.0, (k / 40) * 1.15)) + lado * 0.03
        for lado_f in (-1, 1):
            a = ang + lado_f * (1.0 + rng.uniform(-0.15, 0.15)) + 0.35
            c = cor((70, 104, 44) if lado_f < 0 else (92, 124, 56), 0.12)
            fx = x + math.cos(a) * comp * 0.5
            fy = y + math.sin(a) * comp * 0.5
            elipse(d, fx, fy, comp * 0.5, lado * 0.009, a, c, 0.6)
    d.line(pts, fill=(96, 92, 58, 255), width=max(2, lado // 90))
    return im


def bananeira(lado: int) -> Image.Image:
    """Folha de bananeira: larga, nervura clara no meio, rasgada nas bordas."""
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = lado * 0.5
    topo, fundo = lado * 0.07, lado * 0.93
    for k in range(60):
        t = k / 59
        y = topo + (fundo - topo) * t
        meia = lado * 0.2 * math.sin(math.pi * min(1.0, t * 1.08)) ** 0.7
        # Rasgo: a folha abre em tiras perpendiculares a nervura.
        if rng.random() < 0.22 and 0.15 < t < 0.9:
            continue
        for lado_f in (-1, 1):
            w = meia * rng.uniform(0.82, 1.0)
            c = cor((78, 118, 46) if lado_f < 0 else (96, 136, 56), 0.07)
            d.polygon([(cx, y), (cx + lado_f * w, y - lado * 0.01),
                       (cx + lado_f * w, y + lado * 0.012), (cx, y + lado * 0.016)], fill=c)
    d.line([(cx, topo), (cx, fundo)], fill=(170, 176, 110, 255), width=max(2, lado // 70))
    return im


def bambu(lado: int) -> Image.Image:
    """Touceira de bambu: colmos finos com no, folha em ponta de lanca no alto."""
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for k in range(9):
        x0 = lado * (0.35 + rng.uniform(-0.12, 0.12))
        x1 = x0 + lado * rng.uniform(-0.25, 0.25)
        w = max(2, int(lado * 0.014))
        c = cor((118, 128, 64), 0.12)
        d.line([(x0, lado * 0.97), (x1, lado * 0.06)], fill=c, width=w)
        for n in range(6):
            t = 0.1 + n * 0.15
            x = x0 + (x1 - x0) * t
            y = lado * 0.97 + (lado * 0.06 - lado * 0.97) * t
            d.line([(x - w, y), (x + w, y)], fill=(80, 84, 44, 255), width=max(1, w // 2))
    for _ in range(420):
        t = rng.uniform(0.05, 0.75)
        x = lado * (0.5 + rng.uniform(-0.35, 0.35) * (1 - t * 0.6))
        y = lado * (0.06 + t * 0.8)
        elipse(d, x, y, lado * 0.04, lado * 0.007, rng.uniform(-0.8, 0.8) + (0.3 if x > lado / 2 else -0.3 + math.pi),
               cor((86, 118, 50), 0.14), 0.7)
    return im


def touceira(lado: int) -> Image.Image:
    """Capim colonião: laminas longas saindo de um tufo."""
    im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(160):
        x0 = lado * (0.5 + rng.uniform(-0.1, 0.1))
        ang = rng.uniform(-1.1, 1.1)
        comp = lado * rng.uniform(0.45, 0.88)
        curva = rng.uniform(-0.25, 0.25)
        pts = []
        for k in range(8):
            t = k / 7
            a = ang * t + curva * t * t
            pts.append((x0 + math.sin(a) * comp * t * 0.6, lado * 0.95 - math.cos(a) * comp * t))
        seco = rng.random() < 0.25
        c = cor((150, 140, 80) if seco else (96, 124, 58), 0.15)
        d.line(pts, fill=c, width=max(2, lado // 150))
    return im


def hera(lado: int) -> Image.Image:
    """Hera cobrindo muro: folha miuda, rala na borda."""
    return ramo(lado, ((44, 74, 36), (64, 98, 44), (98, 130, 62)), 0.022, 0.016, 2600,
                lobos=14, raio=0.5, ponta=0.3, achata=1.0)


def flor_canteiro(lado: int) -> Image.Image:
    """Canteiro de beira de muro: folhagem baixa com flor vermelha e branca."""
    im = ramo(lado, ((50, 84, 40), (70, 108, 48), (104, 136, 64)), 0.03, 0.012, 1100,
              raio=0.46, achata=0.6)
    d = ImageDraw.Draw(im)
    alvo = np.argwhere(silhueta(lado, 8, 0.44, 0.6))
    for _ in range(140):
        y, x = alvo[rng.integers(len(alvo))]
        if y > lado * 0.62:
            continue
        c = [(214, 52, 48), (238, 230, 214), (236, 170, 40)][rng.integers(3)]
        r = lado * 0.012
        d.ellipse([x - r, y - r, x + r, y + r], fill=cor(c, 0.06))
    return im


def sombra(lado: int) -> Image.Image:
    """O miolo da copa: folha escura e fechada, para os cartoes de dentro."""
    return ramo(lado, ((24, 40, 22), (34, 54, 28), (46, 70, 34)), 0.035, 0.016, 1800,
                lobos=12, raio=0.5, achata=1.0)


def celulas(lado: int):
    return [
        ramo(lado, ((30, 52, 26), (44, 74, 34), (62, 96, 42)), 0.05, 0.016, 1500,
             brilho=(84, 116, 60)),                                        # mangueira
        ramo(lado, ((42, 72, 34), (60, 96, 42), (92, 128, 58)), 0.022, 0.014, 3200),  # oiti
        ramo(lado, ((56, 90, 42), (82, 118, 54), (122, 150, 74)), 0.042, 0.02, 1500),  # abacateiro
        ramo(lado, ((96, 94, 50), (128, 120, 60), (160, 146, 78)), 0.03, 0.014, 1700),  # seco
        cacho(lado, ((70, 90, 40), (90, 110, 50), (110, 130, 60)),
              ((200, 140, 20), (236, 188, 36), (252, 222, 80)), 300, 900),  # ipe amarelo
        cacho(lado, ((70, 90, 40), (90, 110, 50), (110, 130, 60)),
              ((176, 80, 130), (222, 122, 170), (242, 168, 204)), 300, 900),  # ipe rosa
        cacho(lado, ((44, 76, 36), (64, 100, 44), (92, 128, 58)),
              ((150, 22, 86), (196, 40, 118), (226, 78, 150)), 900, 700, tam_flor=0.018),  # primavera
        mata(lado),
        palma(lado),
        bananeira(lado),
        bambu(lado),
        ramo(lado, ((36, 62, 30), (54, 88, 40), (86, 120, 56)), 0.026, 0.014, 2200,
             raio=0.46, achata=0.72),                                       # arbusto
        touceira(lado),
        hera(lado),
        flor_canteiro(lado),
        sombra(lado),
    ]


def sangrar(im: Image.Image) -> Image.Image:
    """Espalha a cor da folha por baixo do alfa zero (sem isso o mipmap da borda
    do recorte puxa preto e a copa fica com contorno escuro)."""
    arr = np.asarray(im).astype(np.float64)
    a = arr[..., 3] / 255.0
    # Piramide de media ponderada pelo alfa: cada nivel preenche o buraco do de
    # baixo com a cor media da folha em volta.
    niveis = [(arr[..., :3] * a[..., None], a)]
    while niveis[-1][1].shape[0] > 4:
        c, p = niveis[-1]
        h = c.shape[0] // 2
        c = c.reshape(h, 2, h, 2, 3).mean(axis=(1, 3))
        p = p.reshape(h, 2, h, 2).mean(axis=(1, 3))
        niveis.append((c, p))
    cheio = niveis[-1][0] / np.maximum(niveis[-1][1], 1e-6)[..., None]
    for c, p in reversed(niveis[:-1]):
        cheio = cheio.repeat(2, axis=0).repeat(2, axis=1)
        aqui = c / np.maximum(p, 1e-6)[..., None]
        cheio = np.where((p > 0.02)[..., None], aqui, cheio)
    falta = arr[..., 3] < 8
    arr[..., :3] = np.where(falta[..., None], cheio, arr[..., :3])
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def montar(cel: int) -> Image.Image:
    # Desenha em 2x e reduz: a borda da folha sai com meio-tom.
    grande = cel * 2
    atlas = Image.new("RGBA", (cel * N, cel * N), (0, 0, 0, 0))
    for k, im in enumerate(celulas(grande)):
        m = int(grande * MARGEM)
        # A margem livre: o desenho encolhe para dentro dela.
        dentro = im.resize((grande - 2 * m, grande - 2 * m), Image.LANCZOS)
        quadro = Image.new("RGBA", (grande, grande), (0, 0, 0, 0))
        quadro.alpha_composite(dentro, (m, m))
        quadro = quadro.resize((cel, cel), Image.LANCZOS)
        atlas.alpha_composite(quadro, ((k % N) * cel, (k // N) * cel))
    return sangrar(atlas)


def main() -> None:
    hd = montar(CEL)
    SAIDA_HD.mkdir(parents=True, exist_ok=True)
    hd.save(SAIDA_HD / "vegetacao_atlas.png", optimize=True)
    print("vegetacao_atlas (HD)", hd.size)
    ps1 = hd.resize((256, 256), Image.LANCZOS)
    ps1 = ps1.quantize(colors=96, method=Image.FASTOCTREE).convert("RGBA")
    ps1.save(SAIDA / "vegetacao_atlas.png", optimize=True)
    print("vegetacao_atlas", ps1.size)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Sangue no vidro do carro: a testa do padre batendo na janela.

Por que assado e nao procedural no shader
-----------------------------------------
Sangue de cabecada num vidro e tres coisas ao mesmo tempo, e cada uma pede
uma forma que o shader nao desenha barato:

- a MARCA da testa: a pele craquelada da criatura carimbada no vidro, com a
  borda empurrada (o sangue espremido para fora quando a testa aperta) e as
  rachaduras da pele como fios vazios no meio da mancha;
- o RESPINGO: centenas de gotas arremessadas do impacto, grandes perto e
  miudas longe, esticadas na direcao em que voaram, cada uma com a
  gotinha-satelite atras (a forma de ponto de exclamacao);
- os ESCORRIDOS: filetes que descem da borda de baixo da marca e das gotas
  gordas, tortos, afinando, com a conta na ponta.

Tudo isso vira uma textura por golpe. O shader so carimba a celula no ponto
da testa e revela os escorridos com o tempo.

Canais (linear, sem sRGB)
-------------------------
    R  espessura (0 a 1): o shader tira a normal e o escuro dela
    G  tempo de chegada (0 a 1): 0 aparece no impacto; nos escorridos, a
       fracao do tempo de escorrer em que a frente passa por aquele pixel
    B  diluicao pela chuva (0 sangue puro, 1 aguado e rosado)
    A  cobertura, com borda suavizada

Atlas 4096 x 4096 com quatro celulas de 2048 (0,40 m de vidro cada, 0,195 mm
por texel):
    0  golpe 1: a primeira marca, pouco respingo, tres ou quatro escorridos
    1  golpe 2: mais forte, a marca maior e o respingo largo
    2  golpe 3: o vidro ja partindo, respingo pesado
    3  arrasto: o rosto escorregando, um borrao vertical que desce

O impacto fica em (0,5, 0,26) da celula: os escorridos tem 70% dela para
descer.

    python tools/gerar_sangue_vidro.py [--previa DIR]
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "monstros" / "sangue"

CELULA = 2048
METROS = 0.40
TEXEL = METROS / CELULA
IMPACTO = (0.5, 0.26)


def m2px(m: float) -> float:
    return m / TEXEL


class Tela:
    """Os campos de uma celula: o potencial (metaballs somados), a espessura
    extra de cada peca, o tempo de chegada e a diluicao."""

    def __init__(self, n: int) -> None:
        self.n = n
        self.campo = np.zeros((n, n), np.float32)
        self.tempo = np.full((n, n), 2.0, np.float32)
        self.dilui = np.zeros((n, n), np.float32)
        self.buraco = np.zeros((n, n), np.float32)

    def _janela(self, cx: float, cy: float, r: float):
        x0 = max(0, int(cx - r - 2))
        x1 = min(self.n, int(cx + r + 3))
        y0 = max(0, int(cy - r - 2))
        y1 = min(self.n, int(cy + r + 3))
        if x0 >= x1 or y0 >= y1:
            return None
        ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        return (slice(y0, y1), slice(x0, x1)), xs, ys

    def elipse(self, cx: float, cy: float, rx: float, ry: float, ang: float,
               peso: float, t: float = 0.0, dilui: float = 0.0,
               dura: float = 2.2, traco: bool = False) -> None:
        """Metaball eliptica: potencial 1 no centro caindo em (1 - d^2)^dura.

        `traco`: o potencial entra pelo MAXIMO e nao pela soma. Um filete e
        centenas de carimbos a pixel e pouco um do outro; somados, o campo
        passava do limiar longe do eixo e o filete de 2 mm saia um cano de
        1 cm."""
        r = max(rx, ry) * 1.6
        w = self._janela(cx, cy, r)
        if w is None:
            return
        sl, xs, ys = w
        c, s = np.cos(ang), np.sin(ang)
        dx, dy = xs - cx, ys - cy
        u = (dx * c + dy * s) / max(rx, 0.3)
        v = (-dx * s + dy * c) / max(ry, 0.3)
        d2 = u * u + v * v
        k = np.clip(1.0 - d2 / 2.56, 0.0, 1.0) ** dura * peso
        if traco:
            self.campo[sl] = np.maximum(self.campo[sl], k * 1.9)
        else:
            self.campo[sl] += k
        dentro = k > 0.05
        self.tempo[sl] = np.where(dentro, np.minimum(self.tempo[sl], t), self.tempo[sl])
        if dilui > 0.0:
            self.dilui[sl] = np.maximum(self.dilui[sl], np.where(dentro, dilui * np.clip(k, 0, 1), 0.0))

    def furo(self, mascara: np.ndarray, sl) -> None:
        self.buraco[sl] = np.maximum(self.buraco[sl], mascara)


def ruido_suave(n: int, escala: float, rng: np.random.Generator) -> np.ndarray:
    """Ruido de valor suave (-1 a 1), com o comprimento de onda `escala` em px."""
    m = max(2, int(n / escala) + 3)
    g = rng.standard_normal((m, m)).astype(np.float32)
    z = ndimage.zoom(g, n / (m - 3), order=3)[:n, :n]
    return z / (np.abs(z).max() + 1e-6)


def fbm(n: int, escalas, rng) -> np.ndarray:
    out = np.zeros((n, n), np.float32)
    amp = 1.0
    tot = 0.0
    for e in escalas:
        out += ruido_suave(n, e, rng) * amp
        tot += amp
        amp *= 0.55
    return out / tot


def rachas_da_pele(n: int, celula_px: float, rng) -> np.ndarray:
    """As rachaduras da pele da criatura (Voronoi de bordas finas), 0 a 1: o que
    a testa craquelada carimba no vidro como fios sem sangue."""
    pts_n = int((n / celula_px) ** 2)
    pts = rng.uniform(0, n, (pts_n, 2)).astype(np.float32)
    # Distancia a primeira e a segunda semente por pixel, em grade grossa e
    # depois ampliada (a racha tem 2-3 px de largura; ampliar 4x e suave o
    # bastante).
    k = 4
    m = n // k
    ys, xs = np.mgrid[0:m, 0:m].astype(np.float32) * k
    from scipy.spatial import cKDTree
    arv = cKDTree(pts)
    d, _ = arv.query(np.stack([xs.ravel(), ys.ravel()], 1), k=2)
    borda = (d[:, 1] - d[:, 0]).reshape(m, m)
    borda = ndimage.zoom(borda, k, order=1)[:n, :n]
    return np.clip(1.0 - borda / 2.2, 0.0, 1.0)


def marca_da_testa(t: Tela, cx: float, cy: float, largura_m: float, forca: float,
                   rng) -> None:
    """A testa apertando o vidro: uma elipse torta de bordas espremidas."""
    rx = m2px(largura_m * 0.5)
    ry = rx * rng.uniform(0.62, 0.78)
    ang = rng.uniform(-0.2, 0.2)
    # Corpo da marca: varias metaballs sobrepostas, a borda irregular.
    for _ in range(26):
        a = rng.uniform(0, 2 * np.pi)
        r = rng.uniform(0.0, 0.62) ** 0.8
        ox = np.cos(a) * rx * r
        oy = np.sin(a) * ry * r
        t.elipse(cx + ox, cy + oy, rx * rng.uniform(0.32, 0.55),
                 ry * rng.uniform(0.32, 0.55), ang + rng.uniform(-0.5, 0.5),
                 rng.uniform(0.7, 1.0) * (0.8 + 0.4 * forca))
    # O anel espremido: gotas gordas coladas na borda, mais embaixo (a
    # gravidade ja puxa no primeiro instante).
    for _ in range(int(40 + 40 * forca)):
        a = rng.uniform(0, 2 * np.pi)
        bx = np.cos(a) * rx * rng.uniform(0.9, 1.08)
        by = np.sin(a) * ry * rng.uniform(0.9, 1.08)
        g = rng.uniform(0.05, 0.13) * rx * (1.0 + 0.5 * max(0.0, np.sin(a)))
        t.elipse(cx + bx, cy + by, g, g * rng.uniform(0.7, 1.1), a, rng.uniform(0.6, 1.1))
    # As rachas da pele como fios vazios, so dentro da marca.
    r = int(max(rx, ry) * 1.3)
    w = t._janela(cx, cy, r)
    if w is None:
        return
    sl, xs, ys = w
    h, wd = xs.shape
    tam = max(h, wd)
    racha = np.zeros((h, wd), np.float32)
    r0 = rachas_da_pele(tam + 8, m2px(0.006), rng)
    racha[:, :] = r0[:h, :wd]
    dx = (xs - cx) / rx
    dy = (ys - cy) / ry
    miolo = np.clip(1.0 - (dx * dx + dy * dy), 0.0, 1.0)
    t.furo(racha * np.clip(miolo * 2.2, 0, 1) * 0.9, sl)


def respingo(t: Tela, cx: float, cy: float, n: int, alcance_m: float, forca: float,
             rng) -> list:
    """As gotas arremessadas. Devolve as gordas (x, y, raio), que ainda podem
    escorrer."""
    gordas = []
    for _ in range(n):
        # Mais para os lados e para baixo: a testa desce batendo.
        a = rng.uniform(0, 2 * np.pi)
        a += 0.35 * np.sin(a) * (np.sin(a) > 0)
        dist = m2px(alcance_m) * (rng.lognormal(-1.3, 0.55))
        dist = min(dist, m2px(alcance_m) * 1.4)
        x = cx + np.cos(a) * dist
        y = cy + np.sin(a) * dist * 0.85
        # Longe = miuda; perto = gorda. E quanto mais rapida, mais esticada.
        raio = m2px(0.0045) * (1.0 - min(dist / m2px(alcance_m), 1.0)) ** 1.4 \
            * rng.lognormal(0.0, 0.45) * (0.7 + 0.5 * forca) + m2px(0.00035)
        estica = 1.0 + min(dist / m2px(alcance_m), 1.0) * rng.uniform(0.6, 2.6)
        t.elipse(x, y, raio * estica, raio, a, rng.uniform(0.85, 1.2), dura=2.0)
        # A satelite: uma gotinha atras, na mesma linha, e as vezes um fio.
        if raio > m2px(0.0008) and rng.random() < 0.55:
            s = raio * rng.uniform(0.25, 0.45)
            d2 = raio * estica * rng.uniform(1.6, 2.8)
            t.elipse(x + np.cos(a) * d2, y + np.sin(a) * d2 * 0.85, s * 1.3, s, a,
                     rng.uniform(0.8, 1.1))
        if raio > m2px(0.0022):
            gordas.append((x, y, raio))
    # Nevoa de sangue: a poeira miuda que so se ve contra a luz.
    for _ in range(int(n * 2.5)):
        a = rng.uniform(0, 2 * np.pi)
        dist = m2px(alcance_m) * rng.uniform(0.15, 1.25)
        x = cx + np.cos(a) * dist
        y = cy + np.sin(a) * dist * 0.85
        r = m2px(rng.uniform(0.00025, 0.0007))
        t.elipse(x, y, r, r, 0.0, rng.uniform(0.7, 1.0), dilui=0.3, dura=1.6)
    return gordas


def escorrido(t: Tela, x0: float, y0: float, largura_px: float, comprimento_m: float,
              t0: float, rng, dilui: float = 0.0) -> None:
    """Um filete descendo: caminho torto (a gota procura o caminho do vidro
    molhado), afinando, com a conta na ponta. O tempo de chegada anda como
    s ~ t^0,6: rapido no comeco, freando conforme o filete perde sangue."""
    comp = m2px(comprimento_m)
    passos = int(comp / 1.2) + 2
    x = x0
    vx = 0.0
    y = y0
    for i in range(passos):
        f = i / max(passos - 1, 1)
        if y > t.n - largura_px * 4.0 - 8:
            break
        vx += rng.normal(0.0, 0.05)
        vx *= 0.94
        x += vx
        y += 1.2
        # Afina ate 45% e engrossa na conta, no fim.
        w = largura_px * (1.0 - 0.55 * f) * (1.0 + 0.12 * np.sin(i * 0.07 + x0))
        chega = t0 + (1.0 - t0) * f ** (1.0 / 0.6)
        t.elipse(x, y, w, w * 1.3, np.pi * 0.5, 0.95, t=chega,
                 dilui=dilui * f, dura=2.0, traco=True)
    conta = largura_px * rng.uniform(1.25, 1.6)
    t.elipse(x, y + conta * 0.3, conta, conta * 1.25, np.pi * 0.5, 1.25,
             t=1.0, dura=2.0, traco=True)


def celula(variante: int, semente: int) -> np.ndarray:
    rng = np.random.default_rng(semente)
    n = CELULA
    t = Tela(n)
    cx = IMPACTO[0] * n
    cy = IMPACTO[1] * n
    if variante in (0, 1, 2):
        forca = [0.55, 0.8, 1.0][variante]
        largura = [0.070, 0.085, 0.095][variante]
        marca_da_testa(t, cx, cy, largura, forca, rng)
        gordas = respingo(t, cx, cy, [180, 320, 460][variante],
                          [0.09, 0.13, 0.16][variante], forca, rng)
        # Os escorridos da marca: da metade de baixo da borda.
        rx = m2px(largura * 0.5)
        ry = rx * 0.7
        k = [4, 6, 8][variante]
        xs = np.sort(rng.uniform(-0.85, 0.85, k))
        for x in xs:
            yb = cy + ry * np.sqrt(max(0.0, 1.0 - x * x)) * 0.92
            w = m2px(rng.uniform(0.0011, 0.0024)) * (0.8 + 0.3 * forca)
            escorrido(t, cx + x * rx, yb, w,
                      rng.uniform(0.10, 0.27) * (0.7 + 0.4 * forca),
                      rng.uniform(0.0, 0.12), rng, dilui=rng.uniform(0.2, 0.6))
        # E as gotas gordas mais pesadas escorrem tambem, curtas.
        rng.shuffle(gordas)
        for (x, y, r) in gordas[: [3, 6, 9][variante]]:
            escorrido(t, x, y, min(r * 0.45, m2px(0.0016)), rng.uniform(0.03, 0.10),
                      rng.uniform(0.05, 0.3), rng, dilui=0.5)
    else:
        # O arrasto: a testa escorregando 12 cm para baixo e um pouco de lado.
        # Os riscos sao da pele (a racha arrasta um fio vazio, a placa arrasta
        # um fio cheio): sorteados UMA vez e seguidos o caminho inteiro, senao
        # o arrasto vira pontilhado.
        riscos = []
        for j in range(17):
            off = (j - 8) / 8.0 + rng.normal(0.0, 0.025)
            riscos.append((off, rng.uniform(0.035, 0.09), rng.uniform(0.55, 1.0),
                           rng.uniform(0.55, 1.0)))
        passos = 160
        xf = cx
        for i in range(passos):
            f = i / (passos - 1)
            x = cx + m2px(0.018) * np.sin(f * 2.1) + m2px(0.008) * f
            y = cy + m2px(0.12) * f
            w = m2px(0.032) * (1.0 - 0.4 * f)
            xf = x
            for (off, larg, peso, ate) in riscos:
                if f > ate:
                    continue
                t.elipse(x + off * w, y, w * larg, m2px(0.0022), 0.0,
                         peso * (1.0 - 0.45 * abs(off)) * (1.0 - 0.3 * f),
                         t=0.25 * f, traco=True)
        for _ in range(6):
            x = xf + rng.uniform(-1, 1) * m2px(0.016)
            escorrido(t, x, cy + m2px(0.115), m2px(rng.uniform(0.0011, 0.0022)),
                      rng.uniform(0.06, 0.16), 0.25, rng, dilui=0.5)

    # Espessura e cobertura: o potencial acima do limiar e sangue.
    limiar = 0.5
    campo = t.campo
    borda = 1.2 / max(1.0, float(np.percentile(campo[campo > 0.01], 60)) if (campo > 0.01).any() else 1.0)
    cob = np.clip((campo - limiar) / 0.12 + 0.5, 0.0, 1.0)
    cob = cob * cob * (3.0 - 2.0 * cob)
    esp = np.clip((campo - limiar) / 1.6, 0.0, 1.0) ** 0.7
    # Variacao de espessura por dentro (o sangue nao assenta liso) e as rachas.
    varia = fbm(n, [m2px(0.012), m2px(0.004)], rng) * 0.18
    esp = np.clip(esp * (1.0 + varia) - t.buraco * 0.9, 0.0, 1.0)
    cob = np.clip(cob - t.buraco * 0.85, 0.0, 1.0)
    del borda
    tempo = np.clip(t.tempo, 0.0, 1.0)
    tempo[cob < 0.02] = 1.0
    dilui = np.clip(t.dilui + np.clip(0.35 - esp, 0, 1) * 0.5, 0.0, 1.0)
    out = np.stack([esp, tempo, dilui, cob], -1)
    return (np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


# --- o rosto -----------------------------------------------------------------
# A cara do padre sendo destruida nas cabecadas, vista de frente, no espaco da
# malha da cabeca (tools/gerar_padre.py): x de -0,09 a 0,09 m, y de 0,11 (topo)
# a -0,25 (pescoco). O shader da pele projeta de frente. Dois mapas:
#
#   rosto_sangue  R espessura, G tempo de chegada (o progresso global do
#                 sangue: ~0,34 depois do golpe 1, ~0,66 do 2, 1 do 3), B o
#                 rasgo da testa, A cobertura
#   rosto_gore    R corte de vidro (perfil em V: > 0,6 dentro do talho, o resto
#                 e a borda inchada), G em que golpe o corte abre (1/3, 2/3,
#                 1), B onde a pele arranca (quanto maior, mais cedo), A onde o
#                 osso aparece
ROSTO_X = 0.09
ROSTO_TOPO = 0.11
ROSTO_BASE = -0.25
ROSTO_PX = 2048
FERIDA_Y = 0.058
OLHO_X = 0.031
OLHO_Y = 0.004

# Os cortes do vidro: (x, y, angulo, comprimento, largura, golpe). Rasgo de
# caco e reto com quebras bruscas, nao curva.
CORTES = [
    (0.020, 0.070, 0.30, 0.026, 0.0012, 1),
    (-0.026, 0.044, -0.50, 0.019, 0.0010, 1),
    (0.000, 0.004, 0.10, 0.034, 0.0017, 2),
    (0.046, -0.030, -0.90, 0.042, 0.0013, 2),
    (-0.036, 0.026, 0.20, 0.030, 0.0015, 2),
    (0.012, -0.046, 0.40, 0.024, 0.0012, 2),
    # O rasgo grande do terceiro golpe, em dois: inteiro (15 cm) lia como listra.
    (-0.035, 0.025, -0.62, 0.060, 0.0019, 3),
    (0.030, -0.042, -0.76, 0.050, 0.0017, 3),
    (0.000, -0.100, 0.20, 0.044, 0.0015, 3),
    (-0.052, -0.040, 1.40, 0.048, 0.0014, 3),
    (0.036, -0.012, 0.10, 0.030, 0.0013, 3),
    (0.004, 0.082, -1.20, 0.042, 0.0016, 3),
    (0.058, -0.078, -0.60, 0.042, 0.0014, 3),
    (-0.020, -0.066, 0.90, 0.030, 0.0012, 3),
]


def _dim():
    w = ROSTO_PX
    h = int(ROSTO_PX * (ROSTO_TOPO - ROSTO_BASE) / (2 * ROSTO_X))
    return w, h, w / (2 * ROSTO_X)


def _para_px(x: float, y: float):
    w, h, px = _dim()
    return (x + ROSTO_X) * px, (ROSTO_TOPO - y) * px


def _polilinha_do_corte(c, rng):
    x, y, a, comp, larg, golpe = c
    n = 7
    pts = []
    d = np.array([np.cos(a), np.sin(a)])
    nrm = np.array([-d[1], d[0]])
    for i in range(n):
        f = i / (n - 1) - 0.5
        desvio = rng.normal(0, 0.0012) if 0 < i < n - 1 else 0.0
        pts.append(np.array([x, y]) + d * f * comp + nrm * desvio)
    return pts


def _filete(t, x, y, larg, ate, t0, rng, dilui=0.0, puxa_orbita=True):
    """Um filete descendo pela cara a partir de (x, y), chegando em t0 e
    escorrendo ate o fim do progresso."""
    vx = 0.0
    passo = 0.0006
    n = int(max(0.0, y - ate) / passo)
    w, h, px = _dim()
    for i in range(n):
        f = i / max(n - 1, 1)
        if puxa_orbita:
            for lado in (-1.0, 1.0):
                dx = OLHO_X * lado - x
                dy = OLHO_Y - y
                if abs(dy) < 0.02 and abs(dx) < 0.016:
                    vx += dx * 0.02
        if -0.045 < y < -0.005 and abs(x) < 0.012:
            vx += np.sign(x if abs(x) > 1e-4 else rng.normal()) * 0.00012
        vx += rng.normal(0, 0.00005)
        vx *= 0.9
        x += vx
        y -= passo
        cx, cy = _para_px(x, y)
        ww = larg * (1.0 - 0.4 * f) * px
        chega = t0 + (1.0 - t0) * f ** (1.0 / 0.6)
        t.elipse(cx, cy, ww, ww * 1.4, np.pi * 0.5, 0.95, t=chega, traco=True, dilui=dilui)
    cx, cy = _para_px(x, y)
    t.elipse(cx, cy + larg * px * 0.4, larg * px * 1.5, larg * px * 1.9, np.pi * 0.5,
             1.2, t=1.0, traco=True)


def rosto() -> np.ndarray:
    rng = np.random.default_rng(4242)
    w, h, px = _dim()
    t = Tela(max(w, h))
    # A ferida: um rasgo deitado e torto na testa, com a borda inchada.
    fx, fy = _para_px(0.004, FERIDA_Y)
    for i in range(40):
        f = i / 39.0
        x = fx + (f - 0.5) * 0.052 * px
        y = fy + np.sin(f * 5.0) * 0.003 * px + rng.normal(0, 0.0006 * px)
        r = (0.0026 + 0.0018 * np.sin(f * np.pi)) * px
        t.elipse(x, y, r, r * 0.7, 0.0, 1.1, t=0.0, traco=True)
    for _ in range(40):
        a = rng.uniform(0, 2 * np.pi)
        d = rng.uniform(0.0, 0.03) * px
        r = rng.uniform(0.002, 0.006) * px
        t.elipse(fx + np.cos(a) * d * 1.3, fy + np.sin(a) * d * 0.6, r, r * 0.8, a,
                 rng.uniform(0.4, 0.8), t=0.0)
    # Os filetes da testa: os da orbita caem nela e enchem a olheira.
    for x0 in sorted(rng.uniform(-0.024, 0.024, 6)):
        larg = rng.uniform(0.0009, 0.0018)
        ate = rng.uniform(-0.22, -0.05) if abs(x0) > 0.012 else rng.uniform(-0.24, -0.12)
        _filete(t, x0, FERIDA_Y - 0.004, larg, ate, 0.0, rng)
    for lado in (-1.0, 1.0):
        cx, cy = _para_px(OLHO_X * lado, OLHO_Y - 0.004)
        for _ in range(14):
            t.elipse(cx + rng.normal(0, 0.004) * px, cy + rng.normal(0, 0.003) * px,
                     0.0085 * px, 0.006 * px, rng.uniform(-0.3, 0.3), 0.55, t=0.3)
    # O nariz esmagado (golpe 2): as duas narinas despejam, grosso, pela boca e
    # pelo queixo; e a boca enche.
    for lado in (-1.0, 1.0):
        for k in range(3):
            _filete(t, 0.008 * lado + rng.normal(0, 0.002), -0.032, rng.uniform(0.0016, 0.0028),
                    rng.uniform(-0.25, -0.16), 0.35 + 0.02 * k, rng, puxa_orbita=False)
    cx, cy = _para_px(0.0, -0.05)
    for _ in range(30):
        t.elipse(cx + rng.normal(0, 0.009) * px, cy + rng.normal(0, 0.006) * px,
                 0.005 * px, 0.0035 * px, rng.uniform(-0.4, 0.4), 0.6, t=0.45)
    # Cada corte sangra do golpe em que abre: filetes finos da borda de baixo.
    rng_c = np.random.default_rng(4242)
    for c in CORTES:
        pts = _polilinha_do_corte(c, rng_c)
        t0 = (c[5] - 1) / 3.0 + 0.02
        for p in pts[1:-1:2]:
            _filete(t, p[0], p[1], rng.uniform(0.0007, 0.0013), p[1] - rng.uniform(0.03, 0.12),
                    t0, rng, puxa_orbita=False)
    # A orbita esquerda (golpe 3, o olho sai): despeja pela bochecha.
    for k in range(5):
        _filete(t, -OLHO_X + rng.normal(0, 0.006), OLHO_Y - 0.01, rng.uniform(0.0016, 0.003),
                rng.uniform(-0.22, -0.12), 0.68 + 0.02 * k, rng, puxa_orbita=False)

    campo = t.campo[:h, :w]
    cob = np.clip((campo - 0.5) / 0.12 + 0.5, 0.0, 1.0)
    cob = cob * cob * (3.0 - 2.0 * cob)
    esp = np.clip((campo - 0.5) / 1.6, 0.0, 1.0) ** 0.7
    tempo = np.clip(t.tempo[:h, :w], 0.0, 1.0)
    tempo[cob < 0.02] = 1.0
    ferida = np.zeros((h, w), np.float32)
    for i in range(40):
        f = i / 39.0
        x = fx + (f - 0.5) * 0.048 * px
        y = fy + np.sin(f * 5.0) * 0.003 * px
        r = (0.0008 + 0.0009 * np.sin(f * np.pi)) * px
        jan = t._janela(x, y, r * 1.5)
        if jan is None:
            continue
        sl, xs, ys = jan
        d = ((xs - x) / r) ** 2 + ((ys - y) / (r * 0.8)) ** 2
        ferida[sl] = np.maximum(ferida[sl], np.clip(1.0 - d, 0.0, 1.0))
    out = np.stack([esp, tempo, ferida, cob], -1)
    return (np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def gore() -> np.ndarray:
    rng = np.random.default_rng(666)
    w, h, px = _dim()
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    mx = xs / px - ROSTO_X
    my = ROSTO_TOPO - ys / px
    corte = np.zeros((h, w), np.float32)
    nivel = np.ones((h, w), np.float32)
    rng_c = np.random.default_rng(4242)
    for c in CORTES:
        pts = _polilinha_do_corte(c, rng_c)
        larg = c[4]
        x0 = min(p[0] for p in pts) - larg * 4
        x1 = max(p[0] for p in pts) + larg * 4
        y0 = min(p[1] for p in pts) - larg * 4
        y1 = max(p[1] for p in pts) + larg * 4
        c0 = int(max(0, (x0 + ROSTO_X) * px))
        c1 = int(min(w, (x1 + ROSTO_X) * px + 1))
        r0 = int(max(0, (ROSTO_TOPO - y1) * px))
        r1 = int(min(h, (ROSTO_TOPO - y0) * px + 1))
        if c0 >= c1 or r0 >= r1:
            continue
        qx = mx[r0:r1, c0:c1]
        qy = my[r0:r1, c0:c1]
        d = np.full(qx.shape, 1e3, np.float32)
        ao_longo = np.zeros(qx.shape, np.float32)
        total = sum(float(np.linalg.norm(pts[i + 1] - pts[i])) for i in range(len(pts) - 1))
        acum = 0.0
        for i in range(len(pts) - 1):
            a = pts[i]
            b = pts[i + 1]
            ab = b - a
            l2 = float(ab @ ab)
            tt = np.clip(((qx - a[0]) * ab[0] + (qy - a[1]) * ab[1]) / l2, 0, 1)
            dx = qx - (a[0] + ab[0] * tt)
            dy = qy - (a[1] + ab[1] * tt)
            di = np.sqrt(dx * dx + dy * dy)
            s_i = (acum + tt * np.sqrt(l2)) / total
            ao_longo = np.where(di < d, s_i, ao_longo)
            d = np.minimum(d, di)
            acum += float(np.sqrt(l2))
        # O talho e mais largo no meio e fecha nas pontas; a borda e serrilhada.
        lw = larg * (0.35 + 0.65 * np.sin(np.clip(ao_longo, 0, 1) * np.pi) ** 0.6)
        serra = 1.0 + 0.1 * np.sin(ao_longo * 47.0 + c[0] * 1e3) + 0.06 * np.sin(ao_longo * 131.0)
        perfil = np.clip(1.0 - d / (lw * 2.6 * serra), 0.0, 1.0)
        antes = corte[r0:r1, c0:c1]
        nv = nivel[r0:r1, c0:c1]
        novo = perfil > antes
        nivel[r0:r1, c0:c1] = np.where(novo & (perfil > 0.01), c[5] / 3.0, nv)
        corte[r0:r1, c0:c1] = np.maximum(antes, perfil)
    nivel[corte < 0.01] = 1.0

    def gauss(cx, cy, sx, sy=None):
        sy = sx if sy is None else sy
        return np.exp(-(((mx - cx) / sx) ** 2 + ((my - cy) / sy) ** 2))

    ruido = fbm(max(w, h), [px * 0.012, px * 0.004, px * 0.0015], rng)[:h, :w]
    # Onde a pele arranca: a testa (a cratera), o nariz, o meio da cara, a
    # orbita esquerda (o olho sai) e a carnificina da ponte ao maxilar.
    rasga = (1.00 * gauss(0.0, 0.050, 0.022, 0.018)
             + 0.92 * gauss(0.0, -0.018, 0.016, 0.022)
             + 0.62 * gauss(0.0, -0.005, 0.040, 0.036)
             + 0.85 * gauss(-OLHO_X, OLHO_Y, 0.018, 0.016)
             + 0.58 * gauss(0.018, -0.058, 0.024, 0.018)
             + 0.45 * gauss(-0.02, -0.07, 0.02, 0.016))
    rasga = np.clip(rasga * (0.78 + 0.45 * ruido), 0.0, 1.0)
    # Onde o osso aparece: o frontal no fundo da cratera, os ossos do nariz
    # partidos, a borda da orbita esquerda.
    osso = (1.0 * gauss(0.0, 0.054, 0.010, 0.008)
            + 0.85 * gauss(0.0, 0.010, 0.006, 0.010)
            + 0.7 * gauss(-OLHO_X, OLHO_Y + 0.013, 0.012, 0.004)
            + 0.5 * gauss(-OLHO_X - 0.012, OLHO_Y - 0.004, 0.004, 0.012))
    osso = np.clip(osso * (0.75 + 0.5 * ruido), 0.0, 1.0)
    out = np.stack([corte, nivel, rasga, osso], -1)
    return (np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--previa", default="")
    args = ap.parse_args()
    SAIDA.mkdir(parents=True, exist_ok=True)
    atlas = np.zeros((CELULA * 2, CELULA * 2, 4), np.uint8)
    for v in range(4):
        c = celula(v, 7717 + v * 131)
        y = (v // 2) * CELULA
        x = (v % 2) * CELULA
        atlas[y:y + CELULA, x:x + CELULA] = c
        cob = c[..., 3] > 127
        print(f"celula {v}: cobertura {cob.mean() * 100:.2f}%  escorrido {((c[..., 1] > 5) & cob).mean() * 100:.2f}%")
    Image.fromarray(atlas, "RGBA").save(SAIDA / "vidro_sangue.png", optimize=False, compress_level=6)
    print("->", SAIDA / "vidro_sangue.png")
    r = rosto()
    Image.fromarray(r, "RGBA").save(SAIDA / "rosto_sangue.png", compress_level=6)
    print("->", SAIDA / "rosto_sangue.png", r.shape)
    g = gore()
    Image.fromarray(g, "RGBA").save(SAIDA / "rosto_gore.png", compress_level=6)
    print("->", SAIDA / "rosto_gore.png", g.shape)
    if args.previa:
        d = Path(args.previa)
        d.mkdir(parents=True, exist_ok=True)
        # Previa: sangue escuro sobre um fundo de vidro noturno com luz de fogo.
        a = atlas.astype(np.float32) / 255.0
        fundo = np.zeros_like(a[..., :3])
        yy = np.linspace(0, 1, a.shape[0])[:, None]
        fundo[..., 0] = 0.25 + 0.35 * yy
        fundo[..., 1] = 0.12 + 0.1 * yy
        fundo[..., 2] = 0.08
        esp = a[..., 0:1]
        trans = np.concatenate([np.full_like(esp, 0.9), np.full_like(esp, 0.08),
                                np.full_like(esp, 0.06)], -1) ** (1.0 + esp * 4.0)
        cor = fundo * (1 - a[..., 3:4]) + fundo * trans * a[..., 3:4]
        Image.fromarray((np.clip(cor, 0, 1) * 255).astype(np.uint8)).resize((2048, 2048)).save(d / "previa.png")
        Image.fromarray(atlas[..., 1]).resize((2048, 2048)).save(d / "tempo.png")
        ra = r.astype(np.float32) / 255.0
        base = np.full(ra.shape[:2] + (3,), 0.7, np.float32)
        cor = base * (1 - ra[..., 3:4]) + np.array([0.35, 0.02, 0.02]) * (1 - ra[..., 0:1] * 0.6) * ra[..., 3:4]
        Image.fromarray((np.clip(cor, 0, 1) * 255).astype(np.uint8)).resize((512, 1024)).save(d / "rosto.png")
        ga = g.astype(np.float32) / 255.0
        cor = np.full(ga.shape[:2] + (3,), 0.72, np.float32)
        rasgo = (ga[..., 2:3] > 0.35).astype(np.float32)
        cor = cor * (1 - rasgo) + np.array([0.3, 0.03, 0.03]) * rasgo
        cor = np.where(ga[..., 3:4] > 0.45, np.array([0.8, 0.74, 0.6]), cor)
        talho = (ga[..., 0:1] > 0.6).astype(np.float32)
        cor = cor * (1 - talho) + np.array([0.05, 0.0, 0.0]) * talho
        Image.fromarray((np.clip(cor, 0, 1) * 255).astype(np.uint8)).resize((512, 1024)).save(d / "gore.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())

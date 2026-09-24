#!/usr/bin/env python3
"""Conjunto HD do chao e do canteiro (PLANO_FLORA_AAA, etapas 3 e 4).

    python tools/gerar_flora_hd.py                 os quatro conjuntos
    python tools/gerar_flora_hd.py --so=grama      so um (folhagem, recorte, flores, grama)
    python tools/gerar_flora_hd.py --saida=DIR     grava fora do jogo (ensaio)

Usa o motor de folha do `gerar_vegetacao_hd.py` (folha com altura, dobra e
nervura, num buffer de profundidade), agora tambem em LADRILHO: a folha que
passa de uma borda continua na oposta.

    folhagem           ladrilho opaco de folha miuda: a cerca viva podada, o
                       palmito, o caule da bananeira (1,67 m por ladrilho)
    folhagem_recorte   o mesmo em ramos soltos com vao: a casca de fora do
                       arbusto de caixa e da sebe
    flores             o atlas do canteiro, 8 x 8 celulas, as MESMAS do
                       `gerar_parque.py` no mesmo lugar (a UV e uma so)
    grama              o gramado da praca e do parque visto de cima: lamina
                       miuda, trevo, lamina seca, terra entre elas (2 m)

Cada um sai com `_n` (normal, R = +u, G = +v para baixo) e `_ru` (R rugosidade,
G oclusao, B espessura). O PS1 STYLE continua nos de 256 px de sempre.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gerar_vegetacao_hd as v  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "textures_hd"
SS = 2
srgb = v.srgb


def u8(x):
    return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)


def gravar(nome: str, cor: np.ndarray, nrm: np.ndarray, ru: np.ndarray, alfa: bool) -> None:
    SAIDA.mkdir(parents=True, exist_ok=True)
    if alfa:
        a = cor[..., 3]
        cor = cor.copy()
        cor[..., :3] = v.sangrar(cor[..., :3], a)
        nrm = v.sangrar(nrm, a)
        ru = v.sangrar(ru, a)
        Image.fromarray(u8(cor), "RGBA").save(SAIDA / f"{nome}.png", optimize=True)
    else:
        Image.fromarray(u8(cor[..., :3]), "RGB").save(SAIDA / f"{nome}.png", optimize=True)
    nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=2, keepdims=True), 1e-6)
    Image.fromarray(u8(nrm * 0.5 + 0.5), "RGB").save(SAIDA / f"{nome}_n.png", optimize=True)
    Image.fromarray(u8(ru), "RGB").save(SAIDA / f"{nome}_ru.png", optimize=True)
    print(nome, cor.shape[0], "px", "(alfa)" if alfa else "")


def fundo(t: v.Tela, cor, z, rug=0.85, esp=0.2, ruido=0.08):
    """Enche o ladrilho inteiro no fundo: o que se ve entre as folhas."""
    m = t.z < z
    c = np.asarray(cor, np.float32)
    f = 1.0 + t.rng.normal(0.0, ruido, t.z.shape).astype(np.float32)
    for k in range(3):
        t.cor[..., k][m] = (c[k] * f)[m]
    t.z[m] = z
    t.rug[m] = rug
    t.esp[m] = esp


# ----------------------------------------------------------------- folhagem

def folhagem(recorte: bool, lado: int = 1024):
    """Folha miuda de cerca viva (murta, pingo-de-ouro): elipse de 2 a 3 cm,
    dobrada, lustrosa, a ponta nova mais amarela."""
    rng = np.random.default_rng(8100 + int(recorte))
    t = v.Tela(lado * SS, rng, envolve=True)
    L = t.L
    verdes = [srgb((40, 70, 30)), srgb((52, 86, 36)), srgb((64, 98, 42)), srgb((46, 78, 34))]
    nova = srgb((112, 134, 48))
    if not recorte:
        fundo(t, srgb((16, 28, 14)), -L * 0.2)
    # Alguns galhinhos por baixo, que aparecem nos vaos.
    for i in range(60 if recorte else 90):
        x0, y0 = rng.uniform(0, L, 2)
        pts, _ = v._curva(rng, x0, y0, -L * 0.04, rng.uniform(0, math.tau), L * rng.uniform(0.06, 0.12),
                          5, 0.25, 0.1)
        t.galho(pts, L * 0.0022, L * 0.0012, srgb((88, 72, 52)))
    # A folha: espalhada (cerca podada e uma superficie de folha), ou em tufos
    # com vao entre eles (o recorte).
    n = 26000 if not recorte else 15000
    if recorte:
        centros = rng.uniform(0, L, (150, 2))
        pos = centros[rng.integers(len(centros), size=n)] + rng.normal(0, L * 0.03, (n, 2))
    else:
        pos = rng.uniform(0, L, (n, 2))
    for i in range(n):
        x, y = pos[i] % L
        z = -L * 0.04 * rng.uniform(0, 1) ** 0.7
        c = verdes[rng.integers(len(verdes))] * rng.uniform(0.88, 1.12)
        if z > -L * 0.008 and rng.random() < 0.3:
            c = nova * rng.uniform(0.9, 1.1)
        comp_f = L * rng.uniform(0.013, 0.022)
        t.folha(x, y, rng.uniform(0, math.tau), comp_f, comp_f * 0.24, z, c,
                forma=(0.48, 0.8), incl=rng.normal(0, 0.45), rola=rng.normal(0, 0.4), dobra=0.25,
                arco=0.08, curva=rng.normal(0, 0.05), rug=0.38, esp=0.85, nerv=0.3, n_nerv=5)
    return t.mapas()


# ------------------------------------------------------------------- flores

def _descer(t: v.Tela):
    """O canteiro nasce da borda de baixo da celula (o cartao em pe tem o pe no
    chao): tudo desce a margem que o desenho guardou."""
    d = t.lim[0]
    for nome in ("z", "cor", "n", "rug", "esp"):
        a = getattr(t, nome)
        a[d:] = a[:-d].copy()
        if nome == "z":
            a[:d] = v.FUNDO


def _haste(t, x0, altura, curva, cor=(66, 96, 44)):
    L = t.L
    rng = t.rng
    pts, _ = v._curva(rng, x0, L * 0.95, rng.uniform(-6, 6), -math.pi / 2 + curva,
                      altura, 8, 0.05, 0.0)
    t.galho(pts, L * 0.006, L * 0.004, srgb(cor), rug=0.6, esp=0.5)
    return pts


def _folhas_da_haste(t, pts, n, comp, cor=(58, 92, 40)):
    rng = t.rng
    for k in range(n):
        (x, y, z), a = v._ponto(pts, rng.uniform(0.05, 0.7))
        lado = 1 if k % 2 == 0 else -1
        t.folha(x, y, a + lado * rng.uniform(0.7, 1.3), t.L * comp * rng.uniform(0.8, 1.2),
                t.L * comp * 0.2, z + rng.uniform(-3, 3), srgb(cor) * rng.uniform(0.85, 1.1),
                forma=(0.45, 0.8), incl=rng.normal(0, 0.5), rola=rng.normal(0, 0.4), dobra=0.3,
                arco=0.1, curva=0.1 * lado, rug=0.55, esp=0.9, nerv=0.3, n_nerv=4)


def moita(cor_flor, miolo, petalas, n, alto, raio):
    def f(t: v.Tela):
        rng = t.rng
        L = t.L
        # A base fechada: folha larga no pe, que e onde o canteiro tem massa.
        for _ in range(26):
            x = L * (0.5 + rng.uniform(-0.3, 0.3))
            ang = -math.pi / 2 + rng.uniform(-1.3, 1.3)
            t.folha(x, L * 0.95, ang, L * rng.uniform(0.1, 0.18), L * 0.022, rng.uniform(-10, 10),
                    srgb((56, 90, 40)) * rng.uniform(0.85, 1.1), forma=(0.5, 0.8),
                    incl=rng.normal(0.2, 0.4), rola=rng.normal(0, 0.4), dobra=0.3, arco=0.1,
                    curva=rng.normal(0, 0.1), rug=0.55, esp=0.9, nerv=0.3, n_nerv=5)
        for k in range(n + 3):
            x0 = L * (0.5 + rng.uniform(-0.28, 0.28))
            h = L * alto * rng.uniform(0.7, 1.08)
            pts = _haste(t, x0, h, rng.uniform(-0.3, 0.3))
            _folhas_da_haste(t, pts, 4, 0.09)
            if k < n:
                (x, y, z), a = v._ponto(pts, 1.0)
                # Corola vista de lado: o disco achata pelo angulo dela.
                t.flor(x, y, L * raio * rng.uniform(0.85, 1.15), z + 12,
                       srgb(cor_flor) * rng.uniform(0.92, 1.05), petalas=petalas, miolo=srgb(miolo),
                       giro=rng.uniform(0, math.tau), funil=0.12, lobo=0.85,
                       achata=rng.uniform(0.35, 0.95), incl=rng.normal(0, 0.2), rola=rng.normal(0, 0.3))
        _descer(t)
    return f


def espiga(cor):
    def f(t: v.Tela):
        rng = t.rng
        L = t.L
        for k in range(9):
            x0 = L * (0.5 + rng.uniform(-0.25, 0.25))
            pts = _haste(t, x0, L * rng.uniform(0.62, 0.85), rng.uniform(-0.25, 0.25), (84, 104, 64))
            _folhas_da_haste(t, pts, 3, 0.1, (86, 110, 70))
            for s in np.linspace(0.7, 1.0, 14):
                (x, y, z), a = v._ponto(pts, s)
                for lado in (-1, 1):
                    t.flor(x + lado * L * 0.008, y, L * 0.009, z + 5, srgb(cor) * rng.uniform(0.85, 1.1),
                           petalas=4, funil=0.3, lobo=0.5, achata=0.8)
        _descer(t)
    return f


def capim(t: v.Tela):
    rng = t.rng
    L = t.L
    for _ in range(90):
        x0 = L * (0.5 + rng.uniform(-0.2, 0.2))
        ang = -math.pi / 2 + rng.uniform(-0.8, 0.8)
        lado = 1 if ang > -math.pi / 2 else -1
        seco = rng.random() < 0.15
        t.folha(x0, L * 0.95, ang, L * rng.uniform(0.35, 0.8), L * 0.0055, rng.uniform(-20, 20),
                srgb((168, 152, 90) if seco else (84, 118, 52)) * rng.uniform(0.85, 1.1),
                forma=(0.15, 0.6), incl=rng.normal(0.2, 0.3), rola=rng.normal(0, 0.3), dobra=0.5,
                arco=0.0, curva=0.12 * lado, rug=0.6, esp=0.85, nerv=0.3, n_nerv=0, borda=0.05,
                ponta_seca=0.3 if rng.random() < 0.3 else 0.0)
    _descer(t)


def taboa(t: v.Tela):
    rng = t.rng
    L = t.L
    for _ in range(40):
        x0 = L * (0.5 + rng.uniform(-0.2, 0.2))
        ang = -math.pi / 2 + rng.uniform(-0.3, 0.3)
        t.folha(x0, L * 0.95, ang, L * rng.uniform(0.6, 0.88), L * 0.01, rng.uniform(-20, 20),
                srgb((96, 120, 60)) * rng.uniform(0.85, 1.1), forma=(0.2, 0.5),
                incl=rng.normal(0.1, 0.2), rola=rng.normal(0, 0.4), dobra=0.2, arco=0.0,
                curva=rng.normal(0, 0.08), rug=0.5, esp=0.8, nerv=0.2, n_nerv=0,
                ponta_seca=0.25 if rng.random() < 0.5 else 0.0)
    for _ in range(5):
        x0 = L * (0.5 + rng.uniform(-0.15, 0.15))
        pts = _haste(t, x0, L * rng.uniform(0.7, 0.86), rng.uniform(-0.1, 0.1), (110, 118, 70))
        (x, y, z), a = v._ponto(pts, 0.82)
        (x2, y2, z2), _a = v._ponto(pts, 0.95)
        t.galho([(x, y, z + 20), (x2, y2, z2 + 20)], L * 0.022, L * 0.02, srgb((96, 64, 38)),
                rug=0.9, esp=0.1)
    _descer(t)


def nenufar(com_flor: bool):
    """Vista de CIMA: a celula vai deitada na agua."""
    def f(t: v.Tela):
        rng = t.rng
        L = t.L
        cx, cy, r = L * 0.5, L * 0.5, L * 0.4
        caixa = t._caixa(cx - r, cy - r, cx + r, cy + r)
        sl, xx, yy = caixa
        dx, dy = xx - cx, yy - cy
        rr = np.sqrt(dx * dx + dy * dy) / r
        th = np.arctan2(dy, dx)
        entalhe = np.abs(((th - 0.4 + math.pi) % math.tau) - math.pi) < 0.09 + 0.02 * (1 - rr)
        m = (rr <= 1.0) & ~(entalhe & (rr > 0.02))
        veio = 0.92 + 0.08 * np.cos(th * 22.0) ** 8
        borda = 1.0 - 0.25 * v.suave(0.85, 1.0, rr)
        base = srgb((52, 94, 44))
        f_ = veio * borda * (0.95 + 0.1 * rr) * (1 + rng.normal(0, 0.02, m.shape))
        canais = [base[k] * f_ for k in range(3)]
        z = 5.0 - 6.0 * rr ** 2
        nx = dx / r * 0.12
        ny = dy / r * 0.12
        nz = np.ones_like(rr)
        t._gravar(sl, m, z.astype(np.float32), canais, nx, ny, nz, 0.25, 0.9)
        if com_flor:
            cxf, cyf = L * 0.52, L * 0.46
            for camada, (n, comp, cor) in enumerate([(14, 0.2, (236, 228, 232)), (12, 0.15, (246, 236, 244)),
                                                     (10, 0.1, (250, 246, 250))]):
                for k in range(n):
                    a = k / n * math.tau + camada * 0.3 + rng.normal(0, 0.05)
                    t.folha(cxf, cyf, a, L * comp, L * comp * 0.2, 20 + camada * 12, srgb(cor),
                            forma=(0.5, 0.7), incl=0.35 + camada * 0.25, rola=0.0, dobra=0.3, arco=0.05,
                            rug=0.5, esp=1.0, nerv=0.15, n_nerv=3, borda=0.05,
                            cor_nerv=srgb((250, 210, 230)))
            t.flor(cxf, cyf, L * 0.035, 70, srgb((240, 196, 60)), petalas=12, funil=0.2, lobo=0.3)
    return f


def tapete(cores, miolo, tipo):
    """Chao embaixo da arvore visto de CIMA (a celula vai deitada): a trombeta
    caida do ipe, ou a folha seca. Denso no meio e ralo na borda, para o cartao
    nao ter contorno."""
    cores = [srgb(c) for c in cores]

    def f(t: v.Tela):
        rng = t.rng
        L = t.L
        n = 520 if tipo == "flor" else 380
        for _ in range(n):
            # Raio com queda suave: sqrt deixa uniforme; a potencia adensa o meio.
            a = rng.uniform(0, math.tau)
            d = L * 0.44 * rng.uniform(0, 1) ** 0.75
            x, y = L * 0.5 + math.cos(a) * d, L * 0.5 + math.sin(a) * d
            if rng.random() < (d / (L * 0.44)) ** 2 * 0.7:
                continue
            c = np.asarray(cores[rng.integers(len(cores))], np.float32) * rng.uniform(0.85, 1.1)
            if tipo == "flor":
                # Flor caida murcha: um terco ja escurecido.
                if rng.random() < 0.3:
                    c = c * np.float32([0.62, 0.52, 0.4])
                t.flor(x, y, L * rng.uniform(0.018, 0.028), rng.uniform(0, 20), c, petalas=5,
                       miolo=miolo, giro=rng.uniform(0, math.tau), funil=0.5, lobo=0.6,
                       achata=rng.uniform(0.4, 1.0), incl=rng.normal(0, 0.3), rola=rng.normal(0, 0.3))
            else:
                comp = L * rng.uniform(0.05, 0.1)
                t.folha(x, y, rng.uniform(0, math.tau), comp, comp * 0.2, rng.uniform(0, 20), c,
                        forma=(0.45, 0.9), incl=rng.normal(0, 0.15), rola=rng.normal(0, 0.15),
                        dobra=0.5, arco=-0.15, curva=rng.normal(0, 0.15), rug=0.85, esp=0.4,
                        nerv=0.35, n_nerv=8, ponta_seca=0.4)
    return f


def flores():
    CEL = 256
    N = 8
    lado = CEL * N
    celulas = {
        (0, 0): moita((242, 240, 232), (232, 200, 92), 5, 5, 0.62, 0.05),
        (1, 0): moita((196, 40, 40), (58, 40, 34), 5, 4, 0.70, 0.055),
        (2, 0): moita((232, 186, 50), (198, 140, 36), 6, 4, 0.66, 0.052),
        (3, 0): espiga((126, 100, 184)),
        (4, 0): capim,
        (5, 0): taboa,
        (6, 0): moita((230, 170, 40), (86, 58, 30), 9, 3, 0.86, 0.075),
        (7, 0): moita((226, 128, 176), (236, 214, 132), 6, 6, 0.52, 0.048),
        (0, 1): nenufar(False),
        (1, 1): nenufar(True),
        # Chao embaixo da arvore da praca (ArvoreEsqueleto.de_parque): so HD; no
        # PS1 a celula e vazia e o cartao nao desenha.
        (2, 1): tapete([(236, 186, 22), (246, 204, 40), (222, 164, 16)], srgb((150, 96, 20)), "flor"),
        (3, 1): tapete([(222, 110, 168), (236, 138, 188), (206, 94, 152)], srgb((250, 220, 120)), "flor"),
        (4, 1): tapete([(132, 104, 58), (150, 118, 62), (110, 86, 50), (96, 104, 56), (160, 132, 70)],
                       None, "folha"),
    }
    cor = np.zeros((lado, lado, 4), np.float32)
    nrm = np.zeros((lado, lado, 3), np.float32)
    nrm[..., 2] = 1.0
    ru = np.zeros((lado, lado, 3), np.float32)
    ru[..., 0] = 0.6
    ru[..., 1] = 1.0
    for k, ((col, lin), fazer) in enumerate(celulas.items()):
        t = v.Tela(CEL * SS, np.random.default_rng(8300 + k))
        fazer(t)
        c, n, r = t.mapas()
        y, x = lin * CEL, col * CEL
        cor[y:y + CEL, x:x + CEL] = c
        nrm[y:y + CEL, x:x + CEL] = n
        ru[y:y + CEL, x:x + CEL] = r
    return cor, nrm, ru


# --------------------------------------------------------------------- mato

def _capim(t, n, cores, alto=(0.45, 0.85), abre=0.9, seco=0.2, pendao=0):
    rng = t.rng
    L = t.L
    for _ in range(n):
        x0 = L * (0.5 + rng.uniform(-0.3, 0.3))
        ang = -math.pi / 2 + rng.uniform(-abre, abre)
        lado = 1 if ang > -math.pi / 2 else -1
        e_seco = rng.random() < seco
        c = srgb((150, 132, 80) if e_seco else cores[rng.integers(len(cores))]) * rng.uniform(0.85, 1.1)
        t.folha(x0, L * 0.95, ang, L * rng.uniform(*alto), L * rng.uniform(0.004, 0.007),
                rng.uniform(-20, 20), c, forma=(0.15, 0.6), incl=rng.normal(0.2, 0.3),
                rola=rng.normal(0, 0.3), dobra=0.5, arco=0.0, curva=0.12 * lado + rng.normal(0, 0.05),
                rug=0.65, esp=0.6 if e_seco else 0.9, nerv=0.3, n_nerv=0, borda=0.05,
                ponta_seca=0.3 if rng.random() < 0.35 else 0.0)
    for _ in range(pendao):
        x0 = L * (0.5 + rng.uniform(-0.2, 0.2))
        pts = _haste(t, x0, L * rng.uniform(0.6, 0.82), rng.uniform(-0.3, 0.3), (150, 136, 84))
        for s_ in np.linspace(0.72, 1.0, 12):
            (x, y, z), a = v._ponto(pts, s_)
            for lado in (-1, 1):
                t.folha(x, y, a + lado * 0.6, L * 0.035, L * 0.004, z + 3, srgb((184, 158, 104)),
                        forma=(0.4, 0.8), dobra=0.0, arco=0.0, rug=0.8, esp=0.6, nerv=0.0, n_nerv=0)


def m_capim(t):
    _capim(t, 150, [(84, 110, 56), (100, 124, 64), (70, 94, 48)], seco=0.12)
    _capim(t, 60, [(52, 70, 38)], alto=(0.15, 0.3), abre=1.3, seco=0.0)
    _descer(t)


def m_capim_seco(t):
    _capim(t, 130, [(150, 132, 78), (168, 146, 88), (124, 116, 70)], seco=0.5, pendao=6)
    _descer(t)


def m_samambaia(t):
    rng = t.rng
    L = t.L
    for _ in range(9):
        x0 = L * (0.5 + rng.uniform(-0.2, 0.2))
        pts, _a = v._curva(rng, x0, L * 0.95, 0.0, -math.pi / 2 + rng.uniform(-0.9, 0.9),
                           L * rng.uniform(0.5, 0.8), 10, 0.08, 0.02)
        t.galho(pts, L * 0.004, L * 0.002, srgb((80, 90, 44)), rug=0.6, esp=0.5)
        for s_ in np.linspace(0.15, 0.98, 18):
            (x, y, z), a = v._ponto(pts, s_)
            comp = L * 0.07 * (1.0 - s_ * 0.75)
            for lado in (-1, 1):
                t.folha(x, y, a + lado * 1.25, comp, comp * 0.18, z + 2,
                        srgb((70, 104, 46)) * rng.uniform(0.9, 1.1), forma=(0.3, 1.0),
                        incl=rng.normal(0, 0.3), rola=rng.normal(0, 0.3), dobra=0.2, arco=0.05,
                        curva=0.05 * lado, rug=0.6, esp=0.9, nerv=0.3, n_nerv=0, serra=10)
    _descer(t)


def m_folha_larga(t):
    """Taioba: folha grande em ponta de flecha na ponta de um peciolo longo."""
    rng = t.rng
    L = t.L
    for _ in range(5):
        x0 = L * (0.5 + rng.uniform(-0.18, 0.18))
        pts = _haste(t, x0, L * rng.uniform(0.35, 0.6), rng.uniform(-0.45, 0.45), (92, 120, 60))
        (x, y, z), a = v._ponto(pts, 1.0)
        t.folha(x, y, a + rng.uniform(-0.6, 0.6), L * rng.uniform(0.28, 0.36), L * 0.13, z + 10,
                srgb((74, 112, 48)) * rng.uniform(0.9, 1.1), forma=(0.3, 0.75), incl=rng.normal(0, 0.3),
                rola=rng.normal(0, 0.3), dobra=0.3, arco=0.15, rug=0.45, esp=0.9, nerv=0.5, n_nerv=7)
    _descer(t)


def m_moita(t):
    rng = t.rng
    L = t.L
    _capim(t, 60, [(66, 88, 46)], alto=(0.2, 0.4), abre=1.3, seco=0.1)
    for _ in range(260):
        a = rng.uniform(0, math.pi)
        d = L * 0.3 * math.sqrt(rng.uniform(0, 1))
        x, y = L * 0.5 + math.cos(a) * d * 1.3, L * 0.95 - math.sin(a) * d
        comp = L * rng.uniform(0.035, 0.06)
        t.folha(x, y, rng.uniform(0, math.tau), comp, comp * 0.3, rng.uniform(0, 20),
                srgb((60, 90, 42)) * rng.uniform(0.85, 1.12), forma=(0.5, 0.8), incl=rng.normal(0, 0.4),
                rola=rng.normal(0, 0.4), dobra=0.25, arco=0.08, rug=0.5, esp=0.85, nerv=0.3, n_nerv=5)
    _descer(t)


def m_galho_seco(t):
    rng = t.rng
    L = t.L
    for _ in range(6):
        x0 = L * (0.5 + rng.uniform(-0.15, 0.15))
        pts, _a = v._curva(rng, x0, L * 0.95, 0.0, -math.pi / 2 + rng.uniform(-0.5, 0.5),
                           L * rng.uniform(0.5, 0.8), 8, 0.2, 0.0)
        t.galho(pts, L * 0.008, L * 0.003, srgb((96, 80, 60)), rug=0.9, esp=0.1)
        for _k in range(3):
            (x, y, z), a = v._ponto(pts, rng.uniform(0.3, 0.8))
            sp, _b = v._curva(rng, x, y, z, a + (0.7 if rng.random() < 0.5 else -0.7),
                              L * rng.uniform(0.12, 0.25), 5, 0.3, 0.0)
            t.galho(sp, L * 0.004, L * 0.002, srgb((104, 88, 64)), rug=0.9, esp=0.1)
            for _j in range(3):
                (x2, y2, z2), a2 = v._ponto(sp, rng.uniform(0.3, 1.0))
                t.folha(x2, y2, a2 + rng.uniform(-1.2, 1.2), L * 0.04, L * 0.012, z2 + 2,
                        srgb((136, 104, 60)) * rng.uniform(0.85, 1.1), forma=(0.5, 0.8),
                        incl=rng.normal(0, 0.4), rola=rng.normal(0, 0.4), dobra=0.5, arco=0.2,
                        curva=0.2, rug=0.85, esp=0.5, nerv=0.3, n_nerv=5)
    _descer(t)


def m_flor(t):
    rng = t.rng
    L = t.L
    _capim(t, 90, [(80, 106, 54), (66, 90, 46)], alto=(0.3, 0.6), seco=0.1)
    for _ in range(26):
        x0 = L * (0.5 + rng.uniform(-0.3, 0.3))
        pts = _haste(t, x0, L * rng.uniform(0.35, 0.7), rng.uniform(-0.3, 0.3))
        (x, y, z), a = v._ponto(pts, 1.0)
        # Picao do mato: petala branca curta, miolo amarelo.
        t.flor(x, y, L * rng.uniform(0.018, 0.026), z + 10, srgb((238, 236, 226)), petalas=5,
               miolo=srgb((226, 190, 60)), giro=rng.uniform(0, math.tau), funil=0.1, lobo=0.8,
               achata=rng.uniform(0.4, 1.0))
    _descer(t)


def m_capim_ralo(t):
    _capim(t, 70, [(84, 110, 56), (100, 124, 64)], seco=0.2)
    _descer(t)


def m_folhico(t):
    """Folha seca no chao da mata, vista de cima, em ladrilho."""
    rng = t.rng
    L = t.L
    fundo(t, srgb((84, 64, 44)), -L * 0.05, rug=0.95, esp=0.0, ruido=0.1)
    cores = [(132, 104, 58), (150, 118, 62), (110, 86, 50), (96, 80, 50), (160, 132, 70), (90, 96, 52)]
    for _ in range(1400):
        x, y = rng.uniform(0, L, 2)
        comp = L * rng.uniform(0.04, 0.09)
        t.folha(x, y, rng.uniform(0, math.tau), comp, comp * 0.22, rng.uniform(-L * 0.02, 0),
                srgb(cores[rng.integers(len(cores))]) * rng.uniform(0.85, 1.1), forma=(0.45, 0.9),
                incl=rng.normal(0, 0.15), rola=rng.normal(0, 0.15), dobra=0.5, arco=-0.12,
                curva=rng.normal(0, 0.15), rug=0.85, esp=0.0, nerv=0.35, n_nerv=8, ponta_seca=0.4)
    for _ in range(30):
        x0, y0 = rng.uniform(0, L, 2)
        pts, _a = v._curva(rng, x0, y0, 5.0, rng.uniform(0, math.tau), L * rng.uniform(0.1, 0.3), 6, 0.2, 0.0)
        t.galho(pts, L * 0.004, L * 0.002, srgb((96, 78, 56)), rug=0.9, esp=0.0)


def _terra(t, base, pedras, tam_pedra, cor_pedra, molhado=False):
    """Chao de terra batida em ladrilho: ruido de cor, torrao, pedrisco."""
    rng = t.rng
    L = t.L
    fundo(t, srgb(base), -L * 0.05, rug=0.3 if molhado else 0.92, esp=0.0, ruido=0.07)
    # Relevo miudo: torroes como folhas largas e chatas, quase da cor do chao.
    for _ in range(900):
        x, y = rng.uniform(0, L, 2)
        comp = L * rng.uniform(0.02, 0.05)
        c = srgb(base) * rng.uniform(0.85, 1.12)
        t.folha(x, y, rng.uniform(0, math.tau), comp, comp * 0.6, -L * 0.05 + rng.uniform(1, 4), c,
                forma=(0.5, 0.5), incl=rng.normal(0, 0.25), rola=rng.normal(0, 0.25), dobra=0.0,
                arco=0.15, rug=0.3 if molhado else 0.95, esp=0.0, nerv=0.0, n_nerv=0, borda=0.1)
    for _ in range(pedras):
        x, y = rng.uniform(0, L, 2)
        r = L * tam_pedra * rng.uniform(0.5, 1.4)
        c = srgb(cor_pedra) * rng.uniform(0.75, 1.2)
        t.flor(x, y, r, -L * 0.05 + 4 + r * 0.5, c, petalas=7, funil=-0.6, lobo=0.25,
               achata=rng.uniform(0.6, 1.0), giro=rng.uniform(0, math.tau), rug=0.5 if molhado else 0.8,
               esp=0.0)


def m_barro(t):
    _terra(t, (150, 82, 50), 160, 0.008, (122, 100, 80))


def m_cascalho(t):
    _terra(t, (138, 92, 62), 900, 0.012, (128, 116, 100))


def m_poca(t):
    _terra(t, (104, 58, 38), 60, 0.008, (100, 84, 68), molhado=True)


def mato():
    """O atlas da beira de estrada em 2048 (8 x 8 celulas de 256), as mesmas
    celulas do `gerar_estrada.py` no mesmo lugar. Cada celula sai com a MESMA
    cor media da antiga: a estrada de terra tinge as celulas de chao por faixa
    (COR_BARRO, COR_TRILHA...), e essa conta foi afinada em cima da cor antiga."""
    CEL = 256
    N = 8
    lado = CEL * N
    celulas = {
        (0, 0): (m_capim, False), (1, 0): (m_capim_seco, False), (2, 0): (m_samambaia, False),
        (3, 0): (m_folha_larga, False), (4, 0): (m_moita, False), (5, 0): (m_galho_seco, False),
        (6, 0): (m_flor, False), (7, 0): (m_capim_ralo, False),
        (0, 1): (m_folhico, True), (1, 1): (m_barro, True), (2, 1): (m_cascalho, True),
        (3, 1): (m_poca, True),
    }
    velho = np.asarray(Image.open(RAIZ / "game/assets/textures/mato_atlas.png").convert("RGBA")).astype(np.float32) / 255.0
    cv = velho.shape[0] // N
    cor = np.zeros((lado, lado, 4), np.float32)
    nrm = np.zeros((lado, lado, 3), np.float32)
    nrm[..., 2] = 1.0
    ru = np.zeros((lado, lado, 3), np.float32)
    ru[..., 0] = 0.8
    ru[..., 1] = 1.0
    for k, ((col, lin), (fazer, ladrilho)) in enumerate(celulas.items()):
        rng = np.random.default_rng(8700 + k)
        t = v.Tela(CEL * SS, rng, envolve=ladrilho)
        fazer(t)
        c, n, r = t.mapas()
        # A cor media da celula antiga.
        vc = velho[lin * cv:(lin + 1) * cv, col * cv:(col + 1) * cv]
        mv = vc[..., 3] > 0.5
        mn = c[..., 3] > 0.5
        if mv.any() and mn.any():
            alvo = vc[mv][:, :3].mean(0)
            agora = c[mn][:, :3].mean(0)
            c[..., :3] *= np.clip(alvo / np.maximum(agora, 1e-3), 0.5, 2.0)
        if ladrilho:
            c[..., 3] = 1.0
        y, x = lin * CEL, col * CEL
        cor[y:y + CEL, x:x + CEL] = c
        nrm[y:y + CEL, x:x + CEL] = n
        ru[y:y + CEL, x:x + CEL] = r
    return cor, nrm, ru


# -------------------------------------------------------------------- grama

def grama(lado: int = 1024):
    """Gramado batatais/esmeralda visto de cima, 2 m por ladrilho: a lamina e
    curta e em pe (de cima ela aparece encurtada), o verde varia por touceira,
    ha trevo e lamina seca, e a terra aparece pouco entre as touceiras."""
    rng = np.random.default_rng(8500)
    t = v.Tela(lado * SS, rng, envolve=True)
    L = t.L
    fundo(t, srgb((62, 54, 36)), -L * 0.02, rug=0.95, esp=0.1, ruido=0.12)
    # Manchas de tom (touceiras), em baixa frequencia e periodicas.
    fx = rng.uniform(0, math.tau, 6)
    def tom(x, y):
        s = 0.0
        for k in range(3):
            s += math.sin((x / L) * math.tau * (k + 1) + fx[k]) * math.cos((y / L) * math.tau * (k + 2) + fx[k + 3])
        return s / 3.0
    verdes = [srgb((70, 104, 44)), srgb((82, 116, 50)), srgb((96, 128, 56)), srgb((62, 94, 40))]
    seco = srgb((150, 136, 84))
    n = 70000
    xs = rng.uniform(0, L, n)
    ys = rng.uniform(0, L, n)
    for i in range(n):
        x, y = xs[i], ys[i]
        h = tom(x, y)
        c = verdes[rng.integers(len(verdes))] * (1.0 + 0.12 * h) * rng.uniform(0.9, 1.1)
        if rng.random() < 0.07 + 0.05 * max(0.0, -h):
            c = seco * rng.uniform(0.85, 1.1)
        comp = L * rng.uniform(0.008, 0.02)
        t.folha(x, y, rng.uniform(0, math.tau), comp, L * rng.uniform(0.0007, 0.0011),
                rng.uniform(0, L * 0.012), c, forma=(0.2, 0.7), incl=rng.uniform(0.3, 1.3),
                rola=rng.normal(0, 0.3), dobra=0.4, arco=0.0, curva=rng.normal(0, 0.1),
                rug=0.7, esp=0.8, nerv=0.25, n_nerv=0, borda=0.04,
                ponta_seca=0.3 if rng.random() < 0.15 else 0.0)
    # Trevo: tres foliolos redondos, em moitinhas.
    for _ in range(26):
        cx, cy = rng.uniform(0, L, 2)
        for _k in range(rng.integers(6, 16)):
            x = cx + rng.normal(0, L * 0.012)
            y = cy + rng.normal(0, L * 0.012)
            g = rng.uniform(0, math.tau)
            c = srgb((58, 98, 42)) * rng.uniform(0.9, 1.1)
            for j in range(3):
                t.folha(x, y, g + j * math.tau / 3, L * 0.0055, L * 0.0028, L * 0.014, c,
                        forma=(0.7, 0.6), incl=rng.normal(0, 0.2), rola=rng.normal(0, 0.2), dobra=0.2,
                        arco=0.05, rug=0.6, esp=0.9, nerv=0.3, n_nerv=0)
    return t.mapas()


def main() -> int:
    global SAIDA
    so = None
    for arg in sys.argv[1:]:
        if arg.startswith("--so="):
            so = arg.split("=", 1)[1].split(",")
        elif arg.startswith("--saida="):
            SAIDA = Path(arg.split("=", 1)[1])
    if so is None or "folhagem" in so:
        c, n, r = folhagem(False)
        # O ladrilho antigo era claro (verde 84); a folha com oclusao sai 65.
        # O ganho aproxima, para a cerca nao escurecer contra o resto da praca.
        c[..., :3] *= 1.2
        gravar("folhagem", c, n, r, alfa=False)
    if so is None or "recorte" in so:
        c, n, r = folhagem(True)
        c[..., :3] *= 1.2
        gravar("folhagem_recorte", c, n, r, alfa=True)
    if so is None or "flores" in so:
        c, n, r = flores()
        gravar("flores", c, n, r, alfa=True)
    if so is None or "mato" in so:
        c, n, r = mato()
        gravar("mato_atlas", c, n, r, alfa=True)
    if so is None or "grama" in so:
        c, n, r = grama()
        gravar("grama", c, n, r, alfa=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())

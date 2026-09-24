"""Atlas de PLANTAS de quintal mineiro (PLANO_FLORA_AAA, rodada 2).

O `vegetacao_atlas` tem 16 celulas e todas ja tem dono (copa, palma, bananeira
inteira, bambu inteiro...). As plantas novas da rodada 2 sao montadas em 3D
(bambu de colmo roliço, mamoeiro, cacho de banana) ou sao miudezas de quintal
que a cidade nao tinha (capim-gordura, espada-de-sao-jorge, taioba, mato de
calcada, maria-sem-vergonha, samambaia, costela-de-adao, horta, folha caida),
e precisam de celula propria. Este atlas e o material `plantas`.

Mesmo motor de folha do `gerar_vegetacao_hd.py` (Tela: profundidade, normal,
rugosidade, oclusao, espessura). Saem:

    game/assets/textures_hd/plantas_atlas.png      2048, cor + recorte
    game/assets/textures_hd/plantas_atlas_n.png    normal (BC5)
    game/assets/textures_hd/plantas_atlas_ru.png   R rugosidade, G oclusao, B espessura
    game/assets/textures/plantas_atlas.png         256, o do PS1 STYLE (256 cores,
                                                   recorte binario)

Celulas (coluna, linha), a mesma tabela de `Plantas` no jogo:

    (0,0) bambu_ramo      (1,0) mamao_folha     (2,0) banana_cacho    (3,0) mamao_frutos
    (0,1) capim_gordura   (1,1) espada          (2,1) taioba          (3,1) mato_calcada
    (0,2) maria_sem_verg. (1,2) jabuticaba      (2,2) goiaba          (3,2) maracuja
    (0,3) samambaia       (1,3) costela_adao    (2,3) folha_caida     (3,3) horta

Planta EM PE (bambu, capim, espada, taioba, mato, maria-sem-vergonha, costela,
horta, cacho, frutos) tem o pe no meio da borda de BAIXO da celula: o cartao do
jogo e ancorado ali. A samambaia pende do meio da borda de CIMA (o xaxim).

    python tools/gerar_plantas_hd.py [--previa=DIR] [--so=nome,nome]
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gerar_vegetacao_hd as gv  # noqa: E402
from gerar_vegetacao_hd import Especie, Tela, _curva, _folhas_no_galho, _ponto, ramo, srgb  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
SAIDA_HD = RAIZ / "game" / "assets" / "textures_hd"
SAIDA_PS1 = RAIZ / "game" / "assets" / "textures"
CEL = 512
N = 4


def _lamina(t: Tela, x, y, ang, comp, larg, z, cor, **k):
    base = dict(forma=(0.3, 1.0), incl=0.0, rola=0.0, dobra=0.3, arco=0.05, curva=0.0,
                rug=0.55, esp=0.9, nerv=0.3, n_nerv=0, borda=0.08)
    base.update(k)
    t.folha(x, y, ang, comp, larg, z, cor, **base)


# ------------------------------------------------------------------ linha 0

def c_bambu_ramo(t: Tela):
    """Ramo de bambu: galhinho fino com leques de folha em lanca pendendo.
    Vai pendurado ao longo do colmo roliço do bambu 3D."""
    rng = t.rng
    L = t.L
    pts, _ = _curva(rng, L * 0.5, L * 0.95, -20, -math.pi / 2 + 0.08, L * 0.82, 10, 0.06, 0.02)
    t.galho(pts, L * 0.006, L * 0.003, srgb((136, 140, 72)), rug=0.4, esp=0.2)
    verdes = [srgb((70, 108, 40)), srgb((84, 122, 48)), srgb((98, 134, 56)), srgb((62, 96, 38))]
    for s in np.linspace(0.12, 1.0, 9):
        (x, y, z), a = _ponto(pts, s)
        for lado in (-1, 1):
            # Galho de lado com o leque na ponta.
            a1 = a + lado * rng.uniform(0.7, 1.2)
            c1 = L * rng.uniform(0.08, 0.16) * (1.1 - 0.4 * s)
            sp, _ = _curva(rng, x, y, z, a1, c1, 4, 0.12, 0.05)
            t.galho(sp, L * 0.0028, L * 0.0016, srgb((120, 126, 66)), rug=0.45, esp=0.2)
            (fx, fy, fz), fa = _ponto(sp, 1.0)
            n = rng.integers(4, 8)
            for k in range(n):
                # Folha em lanca, caindo para fora e para baixo.
                aa = fa + lado * (0.3 + 1.1 * k / n) + rng.normal(0, 0.12)
                aa = aa + (math.pi / 2 - aa) * 0.25 * (k / n)
                comp = L * rng.uniform(0.13, 0.2)
                c = verdes[rng.integers(len(verdes))] * rng.uniform(0.9, 1.1)
                _lamina(t, fx, fy, aa, comp, L * rng.uniform(0.012, 0.017), fz + k * 2 + rng.uniform(0, 8), c,
                        forma=(0.3, 1.2), incl=rng.normal(0, 0.25), rola=rng.normal(0, 0.3), dobra=0.35,
                        arco=0.06, curva=0.1 * lado + rng.normal(0, 0.04), rug=0.5, nerv=0.35,
                        ponta_seca=0.3 if rng.random() < 0.1 else 0.0)


def c_mamao_folha(t: Tela):
    """Folha de mamoeiro vista de cima: palmada, sete lobos fundos, cada lobo
    recortado de novo. O peciolo sai para baixo."""
    rng = t.rng
    L = t.L
    cx, cy = L * 0.5, L * 0.55
    verde = srgb((72, 112, 44))
    t.galho([(cx, cy, 30), (cx, L * 0.95, 10)], L * 0.012, L * 0.009, srgb((150, 164, 96)), rug=0.5, esp=0.4)
    n = 7
    for k in range(n):
        # Leque de 290 graus, a abertura para o peciolo.
        a = math.pi / 2 + math.radians(35) + math.radians(290) * (k + 0.5) / n
        comp = L * (0.43 if k in (2, 3, 4) else 0.36) * rng.uniform(0.92, 1.05)
        c = verde * rng.uniform(0.9, 1.1)
        z = 20 + 6 * math.cos(a - math.pi * 1.5)
        _lamina(t, cx, cy, a, comp, comp * 0.2, z, c, forma=(0.55, 0.9), dobra=0.25, arco=0.08,
                incl=-0.08, rug=0.45, nerv=0.55, n_nerv=8, serra=0, borda=0.1)
        # Os sub-lobos: dois de cada lado, saindo da nervura do lobo.
        for f, lado in ((0.45, -1), (0.45, 1), (0.7, -1), (0.7, 1)):
            x = cx + math.cos(a) * comp * f
            y = cy + math.sin(a) * comp * f
            _lamina(t, x, y, a + lado * rng.uniform(0.6, 0.9), comp * rng.uniform(0.3, 0.42), comp * 0.08,
                    z + 1, c * rng.uniform(0.95, 1.05), forma=(0.45, 0.9), dobra=0.2, arco=0.05,
                    rug=0.45, nerv=0.4, n_nerv=4, borda=0.1)


def c_banana_cacho(t: Tela):
    """Cacho de banana verde pendurado, com o coracao roxo na ponta."""
    rng = t.rng
    L = t.L
    pts, _ = _curva(rng, L * 0.5, L * 0.07, 0, math.pi / 2, L * 0.62, 12, 0.03, 0.0)
    t.galho(pts, L * 0.016, L * 0.01, srgb((122, 132, 70)), rug=0.6, esp=0.2)
    pencas = 7
    for p in range(pencas):
        s = 0.1 + 0.55 * p / pencas
        (x, y, z), a = _ponto(pts, s)
        dedos = 9 - p // 2
        for d in range(dedos):
            lado = (d / (dedos - 1)) * 2 - 1
            # A banana nasce na penca e curva para CIMA (geotropismo).
            ang = -math.pi / 2 + lado * 1.25 + rng.normal(0, 0.06)
            comp = L * rng.uniform(0.13, 0.16) * (1.0 - 0.02 * p)
            c = srgb((104, 138, 48)) * rng.uniform(0.9, 1.08)
            _lamina(t, x + lado * L * 0.03, y + L * 0.035, ang, comp, L * 0.02, z + 10 - abs(lado) * 8, c,
                    forma=(0.5, 0.5), dobra=0.0, arco=0.12, curva=-0.12 * lado, rug=0.35, esp=0.2,
                    nerv=0.15, n_nerv=0, borda=0.2, ponta_seca=0.12)
    # O coracao: bracteas roxas sobrepostas.
    (x, y, z), a = _ponto(pts, 0.92)
    for k in range(5):
        c = srgb((104, 36, 56)) * rng.uniform(0.85, 1.1)
        _lamina(t, x + rng.normal(0, 2), y - L * 0.04 + k * L * 0.012, math.pi / 2 + rng.normal(0, 0.08),
                L * (0.16 - k * 0.018), L * (0.05 - k * 0.004), z + 40 + k * 3, c, forma=(0.4, 0.55),
                dobra=0.5, arco=0.06, rug=0.4, esp=0.3, nerv=0.25, n_nerv=5, borda=0.15)


def c_mamao_frutos(t: Tela):
    """O tronco do mamoeiro logo abaixo da copa: cicatrizes de folha e os
    mamoes grudados, verdes e um amarelando."""
    rng = t.rng
    L = t.L
    cx = L * 0.5
    t.galho([(cx, L * 0.02, 0), (cx, L * 0.98, 0)], L * 0.07, L * 0.075, srgb((128, 136, 104)), rug=0.7, esp=0.1)
    for k in range(18):
        y = L * rng.uniform(0.05, 0.95)
        x = cx + rng.uniform(-1, 1) * L * 0.05
        t.flor(x, y, L * 0.018, L * 0.08, srgb((96, 100, 74)), petalas=3, funil=0.4, lobo=0.2, achata=0.6)
    for k in range(9):
        lado = -1 if k % 2 == 0 else 1
        y = L * (0.12 + 0.8 * k / 9) + rng.normal(0, L * 0.02)
        x = cx + lado * L * rng.uniform(0.07, 0.14)
        maduro = rng.random() < 0.2
        c = srgb((214, 150, 40) if maduro else (106, 138, 52)) * rng.uniform(0.9, 1.08)
        _lamina(t, x, y - L * 0.09, math.pi / 2 + lado * 0.15, L * 0.2, L * 0.07, L * 0.1 + rng.uniform(0, 10), c,
                forma=(0.55, 0.45), dobra=-0.7, arco=0.15, rug=0.3, esp=0.15, nerv=0.0, n_nerv=0, borda=0.25)


# ------------------------------------------------------------------ linha 1

def c_capim_gordura(t: Tela):
    """Capim-gordura: a touceira fina e macia do barranco de Minas, com a
    pluma vermelho-arroxeada da semente — o morro "cor de vinho" de abril."""
    rng = t.rng
    L = t.L
    for _ in range(420):
        x0 = L * (0.5 + rng.normal(0, 0.1))
        ang = -math.pi / 2 + rng.uniform(-1.2, 1.2)
        comp = L * rng.uniform(0.25, 0.55)
        seco = rng.random() < 0.18
        c = srgb((170, 150, 96) if seco else (104, 128, 60)) * rng.uniform(0.85, 1.12)
        lado = 1 if ang > -math.pi / 2 else -1
        _lamina(t, x0, L * 0.96, ang, comp, L * rng.uniform(0.004, 0.006), rng.uniform(-40, 40), c,
                forma=(0.15, 0.6), incl=rng.normal(0.2, 0.3), rola=rng.normal(0, 0.3), dobra=0.4,
                curva=0.16 * lado + rng.normal(0, 0.05), rug=0.7 + 0.15 * seco, esp=0.6 if seco else 0.85,
                nerv=0.3, borda=0.05, ponta_seca=0.35 if rng.random() < 0.4 else 0.0)
    for _ in range(26):
        x0 = L * (0.5 + rng.normal(0, 0.08))
        pts, _a = _curva(rng, x0, L * 0.96, 30, -math.pi / 2 + rng.uniform(-0.7, 0.7), L * rng.uniform(0.55, 0.85),
                         10, 0.07, 0.0)
        t.galho(pts, L * 0.0024, L * 0.0016, srgb((140, 110, 90)), rug=0.7, esp=0.5)
        for s in np.linspace(0.6, 1.0, 22):
            (x, y, z), a = _ponto(pts, s)
            for lado in (-1, 1):
                c = srgb((158, 72, 84) if rng.random() < 0.7 else (196, 150, 150)) * rng.uniform(0.85, 1.12)
                _lamina(t, x, y, a + lado * rng.uniform(0.3, 0.8), L * rng.uniform(0.02, 0.045), L * 0.005, z + 4, c,
                        forma=(0.4, 0.7), dobra=0.0, arco=0.0, rug=0.85, esp=0.7, nerv=0.0, borda=0.2)


def c_espada(t: Tela):
    """Espada-de-sao-jorge: a touceira de lamina dura em pe que toda casa de
    Minas tem no vaso da porta, verde-escuro com faixa clara e a borda amarela."""
    rng = t.rng
    L = t.L
    for k in range(16):
        x0 = L * (0.5 + rng.normal(0, 0.07))
        ang = -math.pi / 2 + rng.normal(0, 0.14)
        comp = L * rng.uniform(0.55, 0.9)
        larg = L * rng.uniform(0.028, 0.04)
        z = rng.uniform(-30, 30)
        # Borda amarela: a lamina de baixo, um pouco mais larga.
        _lamina(t, x0, L * 0.97, ang, comp, larg * 1.18, z, srgb((196, 176, 70)) * rng.uniform(0.9, 1.05),
                forma=(0.45, 0.45), dobra=0.25, arco=0.02, curva=rng.normal(0, 0.03), rug=0.3, esp=0.35,
                nerv=0.0, borda=0.0)
        c = srgb((44, 78, 40)) * rng.uniform(0.85, 1.1)
        _lamina(t, x0, L * 0.97, ang, comp * 0.995, larg, z + 2, c, forma=(0.45, 0.45), dobra=0.25,
                arco=0.02, curva=rng.normal(0, 0.03), rug=0.3, esp=0.35, nerv=0.5,
                cor_nerv=srgb((118, 150, 96)), n_nerv=int(rng.integers(9, 15)), borda=0.0)


def c_taioba(t: Tela):
    """Taioba: folhas grandes em seta, lisas e claras, em peciolo longo."""
    rng = t.rng
    L = t.L
    for k in range(6):
        ang = -math.pi / 2 + (k / 5 - 0.5) * 1.6 + rng.normal(0, 0.1)
        comp = L * rng.uniform(0.35, 0.55)
        pts, fim = _curva(rng, L * 0.5 + rng.normal(0, 6), L * 0.97, -10 + k * 4, ang, comp, 6, 0.05, 0.1)
        t.galho(pts, L * 0.009, L * 0.006, srgb((112, 144, 70)), rug=0.45, esp=0.5)
        (x, y, z), a = _ponto(pts, 1.0)
        # A lamina pende da ponta do peciolo.
        queda = a + (math.pi / 2 - a) * 0.55 * (1 if a < math.pi / 2 else -1)
        c = srgb((92, 134, 56)) * rng.uniform(0.9, 1.1)
        _lamina(t, x, y, queda, L * rng.uniform(0.3, 0.38), L * rng.uniform(0.13, 0.17), z + 6, c,
                forma=(0.25, 0.75), dobra=0.35, arco=0.1, incl=-0.1, rug=0.3, nerv=0.55, n_nerv=7, borda=0.1)


def c_mato_calcada(t: Tela):
    """O mato de fresta de calcada e pe de muro: tiririca, picao com a florzinha
    amarela, dente-de-leao, trevo. Baixo, ralo, mais verde-amarelado."""
    rng = t.rng
    L = t.L
    for _ in range(170):
        x0 = L * (0.5 + rng.normal(0, 0.16))
        ang = -math.pi / 2 + rng.uniform(-1.0, 1.0)
        c = srgb((110, 136, 58) if rng.random() < 0.8 else (160, 150, 90)) * rng.uniform(0.85, 1.12)
        _lamina(t, x0, L * 0.97, ang, L * rng.uniform(0.15, 0.42), L * rng.uniform(0.004, 0.007), rng.uniform(-30, 30),
                c, forma=(0.2, 0.7), incl=rng.normal(0.2, 0.3), dobra=0.4, curva=rng.normal(0, 0.12), rug=0.65,
                nerv=0.3, ponta_seca=0.3 if rng.random() < 0.3 else 0.0)
    # Picao: haste com folha serrilhada e a flor amarela no alto.
    for _ in range(7):
        x0 = L * (0.5 + rng.normal(0, 0.15))
        pts, _a = _curva(rng, x0, L * 0.97, 10, -math.pi / 2 + rng.normal(0, 0.25), L * rng.uniform(0.4, 0.7), 6, 0.08, 0.0)
        t.galho(pts, L * 0.004, L * 0.003, srgb((96, 118, 60)), esp=0.4)
        for s in (0.3, 0.55, 0.78):
            (x, y, z), a = _ponto(pts, s)
            for lado in (-1, 1):
                _lamina(t, x, y, a + lado * 1.0, L * 0.09, L * 0.022, z + 3, srgb((80, 116, 48)) * rng.uniform(0.9, 1.1),
                        forma=(0.4, 0.8), serra=9, dobra=0.3, rug=0.6, nerv=0.4, n_nerv=4)
        (x, y, z), a = _ponto(pts, 1.0)
        t.flor(x, y, L * 0.022, z + 8, srgb((236, 196, 40)), petalas=5, miolo=srgb((170, 120, 30)), funil=0.2,
               lobo=0.4, achata=rng.uniform(0.5, 1.0))
    # Dente-de-leao e trevo rente ao chao.
    for _ in range(5):
        x = L * rng.uniform(0.2, 0.8)
        t.flor(x, L * rng.uniform(0.62, 0.8), L * 0.028, 60, srgb((244, 210, 44)), petalas=16,
               miolo=srgb((220, 170, 30)), funil=0.1, lobo=0.3, achata=0.55)


def c_maria(t: Tela):
    """Maria-sem-vergonha: a moita baixa do canto de sombra do quintal, folha
    macia e a flor chata de cinco petalas, rosa, vermelha, branca e lilas."""
    rng = t.rng
    L = t.L
    e = Especie(raio=0.44, ramos=13, subs=3, enche=260, grossura=0.004,
                casca=srgb((120, 150, 80)), filotaxia="alterna", passo=0.03, angulo=(0.5, 1.0),
                cores=[srgb((58, 98, 44)), srgb((72, 112, 50)), srgb((86, 126, 56))],
                comp=0.075, razao=0.45, forma=(0.45, 0.85), giro=0.45, dobra=0.2, arco=0.08,
                curva=0.05, rug=0.5, esp=0.95, nerv=0.3, n_nerv=6, serra=12, verso=0.08,
                seca=0.01, cor_seca=(130, 110, 60), ponta_seca=0.0)
    ramo(t, e)
    cores = [(236, 84, 150), (222, 40, 70), (244, 238, 236), (196, 120, 214), (246, 120, 110)]
    base = cores[rng.integers(len(cores))]
    for _ in range(150):
        a = rng.uniform(0, math.tau)
        d = L * 0.4 * math.sqrt(rng.uniform(0, 1))
        x, y = L * 0.5 + math.cos(a) * d, L * 0.52 + math.sin(a) * d * 0.85
        c = base if rng.random() < 0.7 else cores[rng.integers(len(cores))]
        t.flor(x, y, L * rng.uniform(0.022, 0.03), L * 0.06 + rng.uniform(0, 20), srgb(c) * rng.uniform(0.92, 1.05),
               petalas=5, miolo=srgb((250, 240, 220)), giro=rng.uniform(0, math.tau), funil=0.05, lobo=0.9,
               incl=rng.normal(0, 0.2), rola=rng.normal(0, 0.2), rug=0.55, esp=0.8)


# ------------------------------------------------------------------ linha 2

def c_jabuticaba(t: Tela):
    """Copa de jabuticabeira: folha miuda e fechada, verde-escuro com a
    brotacao rosada, e a fruta preta grudada no galho."""
    rng = t.rng
    L = t.L
    ramo(t, Especie(raio=0.46, ramos=15, subs=4, enche=900, grossura=0.005,
                    casca=srgb((150, 120, 96)), filotaxia="alterna", passo=0.012, angulo=(0.6, 1.1),
                    cores=[srgb((30, 56, 26)), srgb((38, 66, 30)), srgb((46, 76, 34))],
                    comp=0.035, razao=0.32, forma=(0.4, 0.9), giro=0.5, dobra=0.3, arco=0.08,
                    curva=0.06, rug=0.4, esp=0.8, nerv=0.25, n_nerv=5, serra=0, verso=0.06,
                    seca=0.02, cor_seca=(130, 96, 60), ponta_seca=0.0, nova=0.07))
    for _ in range(45):
        a = rng.uniform(0, math.tau)
        d = L * 0.36 * math.sqrt(rng.uniform(0.2, 1))
        x, y = L * 0.5 + math.cos(a) * d, L * 0.52 + math.sin(a) * d
        t.flor(x, y, L * 0.013, L * 0.1 + rng.uniform(0, 15), srgb((24, 16, 24)) * rng.uniform(0.9, 1.3),
               petalas=5, funil=-0.8, lobo=0.0, rug=0.15, esp=0.1)


def c_goiaba(t: Tela):
    """Copa de goiabeira: folha oval de nervura marcada, verde-oliva claro, e a
    goiaba verde-amarela."""
    rng = t.rng
    L = t.L
    ramo(t, Especie(raio=0.46, ramos=13, subs=3, enche=520, grossura=0.005,
                    casca=srgb((140, 112, 84)), filotaxia="alterna", passo=0.022, angulo=(0.9, 1.3),
                    cores=[srgb((78, 108, 46)), srgb((92, 120, 52)), srgb((104, 130, 58))],
                    comp=0.07, razao=0.5, forma=(0.5, 0.75), giro=0.45, dobra=0.3, arco=0.1,
                    curva=0.04, rug=0.6, esp=0.8, nerv=0.6, n_nerv=12, serra=0, verso=0.15,
                    seca=0.05, cor_seca=(170, 140, 60), ponta_seca=0.03))
    for _ in range(9):
        a = rng.uniform(0, math.tau)
        d = L * 0.32 * math.sqrt(rng.uniform(0.2, 1))
        x, y = L * 0.5 + math.cos(a) * d, L * 0.55 + math.sin(a) * d
        c = srgb((170, 180, 70) if rng.random() < 0.5 else (140, 170, 64))
        t.flor(x, y, L * 0.03, L * 0.12, c * rng.uniform(0.9, 1.1), petalas=5, funil=-0.9, lobo=0.0,
               rug=0.4, esp=0.2)


def c_maracuja(t: Tela):
    """Maracuja no muro: gavinha, folha de tres lobos, a flor branca de coroa
    roxa e o fruto. Chapado contra a parede, como a hera."""
    rng = t.rng
    L = t.L
    for _ in range(26):
        pts, _a = _curva(rng, L * rng.uniform(0.1, 0.9), L * rng.uniform(0.1, 0.9), rng.uniform(-10, 10),
                         rng.uniform(0, math.tau), L * rng.uniform(0.25, 0.45), 10, 0.22, 0.0)
        t.galho(pts, L * 0.004, L * 0.003, srgb((96, 120, 58)), esp=0.2)
        for s in np.linspace(0.1, 0.95, 6):
            (x, y, z), a = _ponto(pts, s)
            lado = 1 if rng.random() < 0.5 else -1
            c = srgb((56, 96, 40)) * rng.uniform(0.85, 1.12)
            base = a + lado * 1.2
            for dl in (-0.7, 0.0, 0.7):
                _lamina(t, x, y, base + dl, L * (0.075 if dl == 0 else 0.06), L * 0.022, z + 3, c,
                        forma=(0.45, 0.8), dobra=0.3, arco=0.06, rug=0.4, nerv=0.45, n_nerv=5)
    for _ in range(9):
        x, y = L * rng.uniform(0.15, 0.85), L * rng.uniform(0.15, 0.85)
        t.flor(x, y, L * 0.045, 40, srgb((238, 236, 230)), petalas=10, miolo=srgb((96, 50, 130)),
               funil=0.15, lobo=0.5, giro=rng.uniform(0, math.tau))
        t.flor(x, y, L * 0.012, 46, srgb((220, 210, 120)), petalas=5, funil=0.0, lobo=0.3)
    for _ in range(4):
        x, y = L * rng.uniform(0.15, 0.85), L * rng.uniform(0.2, 0.9)
        t.flor(x, y, L * 0.04, 50, srgb((210, 180, 50) if rng.random() < 0.5 else (120, 150, 60)),
               petalas=5, funil=-0.9, lobo=0.0, rug=0.3, esp=0.2)


# ------------------------------------------------------------------ linha 3

def c_samambaia(t: Tela):
    """Samambaia do xaxim da varanda: frondes pinadas saindo do alto e
    pendendo em cascata."""
    rng = t.rng
    L = t.L
    for k in range(22):
        a0 = math.pi / 2 + (k / 21 - 0.5) * 2.6 + rng.normal(0, 0.08)
        comp = L * rng.uniform(0.5, 0.85)
        pts = []
        x, y, z = L * 0.5 + rng.normal(0, 6), L * 0.06, 20 + rng.uniform(-10, 10)
        a = a0 - (0.9 if a0 < math.pi / 2 else -0.9) * 0.7
        seg = comp / 14
        for i in range(15):
            pts.append((x, y, z))
            # Sobe um pouco e cai: a fronde velha pende.
            a = a + (math.pi / 2 - a) * 0.12
            x += math.cos(a) * seg
            y += math.sin(a) * seg
        t.galho(pts, L * 0.0035, L * 0.002, srgb((96, 110, 56)), esp=0.4)
        verde = srgb((88, 134, 50)) * rng.uniform(0.88, 1.1)
        for s in np.linspace(0.08, 1.0, 26):
            (px, py, pz), pa = _ponto(pts, s)
            for lado in (-1, 1):
                comp_p = L * 0.05 * math.sin(math.pi * min(1.0, s * 1.1)) + L * 0.008
                _lamina(t, px, py, pa + lado * 1.25, comp_p, L * 0.009, pz + 2, verde,
                        forma=(0.4, 0.9), serra=6, dobra=0.3, arco=0.03, rug=0.55, nerv=0.3,
                        ponta_seca=0.3 if rng.random() < 0.04 else 0.0)


def c_costela(t: Tela):
    """Costela-de-adao: folha grande recortada ate perto da nervura, lustrosa.
    Cada folha e uma nervura com os dedos saindo dos dois lados."""
    rng = t.rng
    L = t.L
    for k in range(5):
        ang = -math.pi / 2 + (k / 4 - 0.5) * 1.7 + rng.normal(0, 0.08)
        pts, _ = _curva(rng, L * 0.5 + rng.normal(0, 8), L * 0.97, -20 + k * 5, ang, L * rng.uniform(0.2, 0.32), 5, 0.04, 0.1)
        t.galho(pts, L * 0.008, L * 0.006, srgb((70, 104, 50)), rug=0.4, esp=0.4)
        (x, y, z), a = _ponto(pts, 1.0)
        comp = L * rng.uniform(0.34, 0.42)
        dirx, diry = math.cos(a), math.sin(a)
        # A folha se abre para fora do peciolo: nervura central.
        nerv = [(x + dirx * comp * s, y + diry * comp * s, z + 8) for s in np.linspace(0, 1, 9)]
        t.galho(nerv, L * 0.005, L * 0.002, srgb((96, 130, 60)), rug=0.35, esp=0.4)
        c = srgb((42, 84, 36)) * rng.uniform(0.9, 1.1)
        dedos = 8
        for d in range(dedos):
            s = 0.08 + 0.86 * d / dedos
            (px, py, pz), pa = _ponto(nerv, s)
            meia = math.sin(math.pi * min(1.0, s * 1.05)) ** 0.7
            for lado in (-1, 1):
                _lamina(t, px, py, pa + lado * (1.2 - 0.5 * s), comp * 0.42 * meia + 2, comp * 0.075, pz + 1, c,
                        forma=(0.5, 0.5), dobra=0.1, arco=0.04, curva=0.08 * lado, rug=0.25, esp=0.5,
                        nerv=0.3, n_nerv=0, borda=0.1)


def c_folha_caida(t: Tela):
    """Folhico de quintal: folha seca de mangueira, abacateiro e ipe caida,
    amarela, parda e uma ou outra verde. Deitada no chao."""
    rng = t.rng
    L = t.L
    cores = [(150, 112, 56), (176, 134, 60), (120, 86, 48), (196, 162, 76), (104, 76, 44), (96, 112, 50)]
    for _ in range(170):
        x, y = L * rng.uniform(0.1, 0.9), L * rng.uniform(0.1, 0.9)
        if (x / L - 0.5) ** 2 + (y / L - 0.5) ** 2 > 0.16 * rng.uniform(0.6, 1.0):
            continue
        c = srgb(cores[rng.integers(len(cores))]) * rng.uniform(0.85, 1.1)
        grande = rng.random() < 0.45
        comp = L * (rng.uniform(0.09, 0.14) if grande else rng.uniform(0.04, 0.07))
        _lamina(t, x, y, rng.uniform(0, math.tau), comp, comp * rng.uniform(0.18, 0.3), rng.uniform(0, 30), c,
                forma=(0.45, 0.8), dobra=rng.uniform(0.2, 0.7), arco=rng.uniform(-0.1, 0.12),
                curva=rng.normal(0, 0.12), rug=0.85, esp=0.3, nerv=0.4, n_nerv=7, borda=0.2)


def c_horta(t: Tela):
    """Canteiro de horta visto de lado: couve de folha azulada no talo, alface
    em roseta e cebolinha."""
    rng = t.rng
    L = t.L
    for k in range(3):
        x = L * (0.2 + 0.3 * k) + rng.normal(0, 6)
        t.galho([(x, L * 0.97, 0), (x, L * 0.55, 0)], L * 0.012, L * 0.01, srgb((150, 170, 130)), rug=0.5, esp=0.3)
        for f in range(7):
            ang = -math.pi / 2 + (f / 6 - 0.5) * 2.4 + rng.normal(0, 0.1)
            y0 = L * (0.55 + 0.05 * rng.uniform(0, 1))
            _lamina(t, x, y0, ang, L * rng.uniform(0.2, 0.28), L * rng.uniform(0.08, 0.1), 10 + f * 3,
                    srgb((72, 110, 88)) * rng.uniform(0.9, 1.1), forma=(0.55, 0.6), dobra=0.35, arco=0.1,
                    incl=-0.1, rug=0.45, nerv=0.55, cor_nerv=srgb((170, 190, 160)), n_nerv=6, borda=0.1)
    for k in range(4):
        x = L * (0.08 + 0.28 * k) + rng.normal(0, 5)
        for f in range(14):
            ang = -math.pi / 2 + rng.uniform(-1.3, 1.3)
            _lamina(t, x, L * 0.97, ang, L * rng.uniform(0.08, 0.13), L * 0.045, 30 + rng.uniform(0, 12),
                    srgb((128, 170, 70)) * rng.uniform(0.9, 1.1), forma=(0.6, 0.5), dobra=0.2, arco=0.08,
                    rug=0.5, nerv=0.35, n_nerv=5, serra=14, borda=0.1)
    for _ in range(30):
        x = L * rng.uniform(0.05, 0.95)
        _lamina(t, x, L * 0.97, -math.pi / 2 + rng.normal(0, 0.12), L * rng.uniform(0.25, 0.35), L * 0.005,
                rng.uniform(-10, 40), srgb((70, 116, 50)) * rng.uniform(0.9, 1.1), forma=(0.3, 0.7), dobra=0.6,
                rug=0.4, nerv=0.0, ponta_seca=0.2 if rng.random() < 0.3 else 0.0)


CELULAS = [
    ("bambu_ramo", c_bambu_ramo), ("mamao_folha", c_mamao_folha),
    ("banana_cacho", c_banana_cacho), ("mamao_frutos", c_mamao_frutos),
    ("capim_gordura", c_capim_gordura), ("espada", c_espada), ("taioba", c_taioba),
    ("mato_calcada", c_mato_calcada),
    ("maria", c_maria), ("jabuticaba", c_jabuticaba), ("goiaba", c_goiaba), ("maracuja", c_maracuja),
    ("samambaia", c_samambaia), ("costela", c_costela), ("folha_caida", c_folha_caida), ("horta", c_horta),
]


def folhas_soltas():
    """As folhas que caem das copas (FolhasCaindo): quatro sprites de uma folha
    so, em 2 x 2 — a de mangueira amarela, a parda enrolada, a verde-amarela
    miuda e a trombeta do ipe amarelo."""
    lado = 256
    out = np.zeros((lado * 2, lado * 2, 4), np.float32)
    receitas = [
        lambda t: _lamina(t, t.L * 0.2, t.L * 0.78, -0.75, t.L * 0.72, t.L * 0.14, 0, srgb((198, 156, 60)),
                          forma=(0.45, 0.8), dobra=0.35, arco=0.08, curva=0.08, nerv=0.5, n_nerv=8, borda=0.2,
                          ponta_seca=0.3),
        lambda t: _lamina(t, t.L * 0.22, t.L * 0.76, -0.8, t.L * 0.66, t.L * 0.16, 0, srgb((132, 92, 50)),
                          forma=(0.5, 0.7), dobra=0.9, arco=0.15, curva=-0.12, nerv=0.4, n_nerv=6, borda=0.25,
                          rug=0.9),
        lambda t: _lamina(t, t.L * 0.25, t.L * 0.72, -0.7, t.L * 0.58, t.L * 0.17, 0, srgb((150, 160, 62)),
                          forma=(0.45, 0.7), dobra=0.3, arco=0.06, nerv=0.45, n_nerv=6, borda=0.15),
        lambda t: t.flor(t.L * 0.5, t.L * 0.5, t.L * 0.33, 0, srgb((236, 188, 26)), petalas=5,
                         miolo=srgb((170, 110, 20)), funil=0.5, lobo=0.6, achata=0.75),
    ]
    for k, fazer in enumerate(receitas):
        t = Tela(lado * gv.SS, np.random.default_rng(9300 + k))
        fazer(t)
        c, _n, _r = t.mapas()
        y, x = (k // 2) * lado, (k % 2) * lado
        out[y:y + lado, x:x + lado] = c
    a = out[..., 3]
    out[..., :3] = gv.sangrar(out[..., :3], a)
    return out


def main() -> int:
    previa = None
    so = None
    for arg in sys.argv[1:]:
        if arg.startswith("--previa="):
            previa = Path(arg.split("=", 1)[1])
        elif arg.startswith("--so="):
            so = set(arg.split("=", 1)[1].split(","))
    lado = CEL * N
    gv.MODO = "edge"
    cor = np.zeros((lado, lado, 4), np.float32)
    nrm = np.zeros((lado, lado, 3), np.float32)
    nrm[..., 2] = 1.0
    ru = np.zeros((lado, lado, 3), np.float32)
    for k, (nome, fazer) in enumerate(CELULAS):
        if so is not None and nome not in so:
            continue
        rng = np.random.default_rng(9100 + k)
        t = Tela(CEL * gv.SS, rng)
        fazer(t)
        c, n, r = t.mapas()
        y, x = (k // N) * CEL, (k % N) * CEL
        cor[y:y + CEL, x:x + CEL] = c
        nrm[y:y + CEL, x:x + CEL] = n
        ru[y:y + CEL, x:x + CEL] = r
        print("celula %2d %-14s cobertura %.2f" % (k, nome, float(c[..., 3].mean())))
    a = cor[..., 3]
    cor[..., :3] = gv.sangrar(cor[..., :3], a)
    nrm = gv.sangrar(nrm, a)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=2, keepdims=True), 1e-6)
    ru = gv.sangrar(ru, a)

    def u8(x):
        return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)

    if so is None:
        SAIDA_HD.mkdir(parents=True, exist_ok=True)
        Image.fromarray(u8(cor), "RGBA").save(SAIDA_HD / "plantas_atlas.png", optimize=True)
        Image.fromarray(u8(nrm * 0.5 + 0.5), "RGB").save(SAIDA_HD / "plantas_atlas_n.png", optimize=True)
        Image.fromarray(u8(ru), "RGB").save(SAIDA_HD / "plantas_atlas_ru.png", optimize=True)
        # PS1: 256 px, recorte binario, 256 cores (psx-assets).
        pre = cor[..., :3] * a[..., None]
        p256 = np.asarray(Image.fromarray(u8(pre), "RGB").resize((256, 256), Image.LANCZOS), np.float32) / 255.0
        a256 = np.asarray(Image.fromarray(u8(a), "L").resize((256, 256), Image.LANCZOS), np.float32) / 255.0
        rgb = p256 / np.maximum(a256, 1e-3)[..., None]
        rgb = gv.sangrar(rgb.astype(np.float32), (a256 > 0.45).astype(np.float32))
        q = Image.fromarray(u8(rgb), "RGB").quantize(colors=255, method=Image.Quantize.MEDIANCUT).convert("RGB")
        rgba = np.dstack([np.asarray(q), np.where(a256 > 0.45, 255, 0).astype(np.uint8)])
        Image.fromarray(rgba, "RGBA").save(SAIDA_PS1 / "plantas_atlas.png", optimize=True)
        print("plantas_atlas HD", lado, "(cor, _n, _ru) e PS1 256")
        Image.fromarray(u8(folhas_soltas()), "RGBA").save(SAIDA_HD / "folhas_soltas.png", optimize=True)
        print("folhas_soltas 512")

    if previa is not None:
        previa.mkdir(parents=True, exist_ok=True)
        fundo = np.ones((lado, lado, 3), np.float32) * np.float32([0.62, 0.7, 0.8])
        luz = np.float32([-0.45, -0.55, 0.7])
        luz /= np.linalg.norm(luz)
        d = np.clip((nrm * luz).sum(axis=2), 0, 1) * 0.8 + 0.25 * ru[..., 1]
        lit = cor[..., :3] * d[..., None] * 1.3
        comp = lit * a[..., None] + fundo * (1.0 - a[..., None])
        Image.fromarray(u8(comp), "RGB").save(previa / "plantas_luz.png")
        print("previa em", previa)
    return 0


if __name__ == "__main__":
    sys.exit(main())

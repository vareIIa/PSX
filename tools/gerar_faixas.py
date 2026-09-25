"""Texturas dos romeiros enfaixados (`RostoEnfaixado`, src/render/rosto_enfaixado.gd).

A referencia e INTRO-PADRE/referencia/romeiro_enfaixado.png: a cabeca inteira
enrolada em gaze suja, sangue seco e fresco escorrendo das frestas, um olho
arregalado por uma fresta e os dentes pela outra. A forma (faixa sobre faixa,
as frestas, os dentes, o olho) e malha, montada no GDScript; aqui sai a pele de
cada peca:

    faixa_albedo.png      4096 x 2048 RGBA  a gaze, no espaco da FAIXA: u ao
    faixa_normal.png      4096 x 2048 RGB   comprido (fecha sem emenda em u, um
    faixa_rugosidade.png  4096 x 2048 L     passo de FAIXA_PASSO metros), v
                                            atravessando (0 a 1 = FAIXA_LARGURA
                                            metros, com a franja). Duas linhas:
                                            v 0-0,5 a gaze inteira, v 0,5-1 a
                                            gasta, com rasgo. Alfa: a franja
                                            solta da borda e os rasgos.
    manchas.png           2048 x 2048 RGBA  sangue e sujeira no espaco da
                                            CABECA, projecao cilindrica em volta
                                            do eixo y: u = atan(x, -z)/2pi + 0,5
                                            (0,5 e a frente), v = 0,5 - y /
                                            MANCHA_ALTURA. Desenhada para o olho
                                            aberto em +x; o shader espelha u.
                                            R sangue seco, G sangue fresco,
                                            B sujeira, A soro (o amarelo).
    olho_albedo.png       1024 x 1024 RGBA  o globo visto de frente (u,v 0,5 e a
                                            cornea, raio 0,5 o equador). A: onde
                                            o olho acende (pupila e iris).
    carne_albedo.png      1024 x 1024 RGB   a carne inchada em volta do olho e
    carne_normal.png      1024 x 1024 RGB   da boca, sem emenda.

O rosto da `MultidaoEncapuzada` (rosto_multidao.png) nao sai daqui: e a foto da
cabeca de verdade, assada depois destas texturas por
game/tests/assar_rosto_multidao.gd (ver o cabecalho dele).

Ruido de espectro (FFT): periodico por construcao, como em gerar_blunt.py. A
trama da gaze e fio a fio: urdidura ao comprido, trama atravessando, as duas
subindo e descendo uma sobre a outra, e uma segunda camada de gaze por baixo que
aparece nos furos (atadura e dobrada em varias camadas).

    python tools/gerar_faixas.py [--previa=DIR]
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "monstros" / "romeiro"

# --- medidas compartilhadas com rosto_enfaixado.gd ------------------------------
# Largura de uma linha da gaze (a faixa com a franja) e o passo de u, em metros.
FAIXA_LARGURA = 0.046
FAIXA_PASSO = 0.186
# Altura que a projecao das manchas cobre, centrada no centro da cabeca.
MANCHA_ALTURA = 0.36
# O olho aberto (+x) e a boca, no espaco da cabeca (centro da cabeca na origem,
# frente em -z). Iguais a OLHO e BOCA_* de RostoEnfaixado.
OLHO = (0.034, 0.012, -0.088)
BOCA_Y = -0.058
BOCA_MEIA = 0.043
RAIO_MEDIO = 0.095

# Resolucao de cada linha da gaze.
GH, GW = 1024, 4096


# --- utilidades -------------------------------------------------------------------

def ruido(seed, forma, beta, ax=1.0, ay=1.0, fmin=1.0, angulo=0.0):
    """Ruido 1/f^beta periodico em `forma` (linhas, colunas). `ax`/`ay` esticam a
    frequencia (ax > ay: a feicao fica comprida em X); `angulo` gira o eixo."""
    h, w = forma
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.normal(size=forma))
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    c, s = np.cos(angulo), np.sin(angulo)
    rx = fx * c + fy * s
    ry = -fx * s + fy * c
    r = np.sqrt((rx * ax) ** 2 + (ry * ay) ** 2)
    r[0, 0] = 1.0
    amp = 1.0 / np.maximum(r, fmin) ** beta
    amp[0, 0] = 0.0
    n = np.real(np.fft.ifft2(f * amp))
    n = (n - n.mean()) / (n.std() + 1e-9)
    return n.astype(np.float32)


def ruido1d(rng, linhas, n, beta, fmin=1.0):
    """`linhas` curvas de ruido 1/f periodico de `n` amostras, desvio 1."""
    f = np.fft.fft(rng.normal(size=(linhas, n)), axis=1)
    fr = np.abs(np.fft.fftfreq(n) * n)
    amp = 1.0 / np.maximum(fr, fmin) ** beta
    amp[0] = 0.0
    x = np.real(np.fft.ifft(f * amp[None, :], axis=1))
    x /= x.std(axis=1, keepdims=True) + 1e-9
    return x.astype(np.float32)


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mistura(a, b, t):
    return a + (np.float32(b) - a) * t[..., None]


def cor(*rgb):
    return np.float32(rgb)


def normal_de(h, forca, envolve_x=True, envolve_y=False):
    """Normal (OpenGL, +y para cima) do campo de altura `h` em pixel."""
    if envolve_x:
        gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    else:
        gx = np.gradient(h, axis=1)
    if envolve_y:
        gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    else:
        gy = np.gradient(h, axis=0)
    n = np.dstack([-gx * forca, gy * forca, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def u8(x):
    return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)


def salvar(nome, arr, modo):
    SAIDA.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr, modo).save(SAIDA / nome, optimize=False, compress_level=6)
    print("  ", nome, arr.shape)


# --- a gaze -------------------------------------------------------------------------

def _fios(rng, n_fios, passo, comp, onda_px, grossura, ondula_beta=1.6):
    """Centro (px) de cada fio ao longo do comprimento e a meia grossura, com o
    fio torto (onda) e mais grosso aqui e ali (o nó da linha de algodao)."""
    base = (np.arange(n_fios, dtype=np.float32) + 0.5 + rng.uniform(-0.18, 0.18, n_fios)) * passo
    onda = ruido1d(rng, n_fios, comp, ondula_beta, fmin=3.0) * onda_px
    centro = base[:, None] + onda
    gros = passo * grossura * (1.0 + 0.22 * rng.normal(size=n_fios)).clip(0.6, 1.5)
    no = 1.0 + 0.22 * ruido1d(rng, n_fios, comp, 1.2, fmin=8.0)
    return centro, gros[:, None] * no


def _perfil_fio(d, meia):
    x = np.clip(d / meia, -1.0, 1.0)
    return np.sqrt(np.clip(1.0 - x * x, 0.0, 1.0))


def trama(seed, h, w, n_urd, n_tra, grossura=0.30, sobe=0.33):
    """Uma camada de gaze tecida em tafeta: urdidura (ao longo de u) e trama
    (atravessando). Devolve altura (-1 no furo, ~0-1,3 no fio) e o quanto cada
    pixel e fio (0 no furo)."""
    rng = np.random.default_rng(seed)
    p_urd = h / n_urd
    p_tra = w / n_tra
    v = np.arange(h, dtype=np.float32)[:, None] + 0.5
    u = np.arange(w, dtype=np.float32)[None, :] + 0.5
    c_urd, g_urd = _fios(rng, n_urd, p_urd, w, 0.9, grossura)
    c_tra, g_tra = _fios(rng, n_tra, p_tra, h, 0.9, grossura)
    alt_urd = np.full((h, w), -1.0, np.float32)
    k0 = np.floor(v / p_urd).astype(np.int32)
    for dk in (-1, 0, 1):
        k = np.clip(k0 + dk, 0, n_urd - 1)[:, 0]
        c = c_urd[k, :]
        g = g_urd[k, :]
        perfil = _perfil_fio(v - c, g)
        # Tafeta: o fio de urdidura sobe e desce a cada fio de trama que cruza,
        # alternando com o vizinho.
        ondula = sobe * np.cos(np.pi * (u / p_tra - 0.5) + np.pi * k[:, None])
        a = np.where(perfil > 0.0, perfil * 0.85 + ondula * np.sqrt(perfil), -1.0)
        alt_urd = np.maximum(alt_urd, a)
    alt_tra = np.full((h, w), -1.0, np.float32)
    j0 = np.floor(u / p_tra).astype(np.int32)
    for dj in (-1, 0, 1):
        jj = j0 + dj
        jm = jj % n_tra
        c = c_tra[jm[0], :].T + ((jj - jm) // n_tra * w).astype(np.float32)
        g = g_tra[jm[0], :].T
        perfil = _perfil_fio(u - c, g)
        ondula = -sobe * np.cos(np.pi * (v / p_urd - 0.5) + np.pi * jm)
        a = np.where(perfil > 0.0, perfil * 0.85 + ondula * np.sqrt(perfil), -1.0)
        alt_tra = np.maximum(alt_tra, a)
    alt = np.maximum(alt_urd, alt_tra)
    fio = (alt > -0.5).astype(np.float32)
    return alt, fio, alt_urd, alt_tra


def gaze(seed, gasta):
    """Uma linha da gaze: `gasta` poe rasgo, mais sujeira e borda mais comida."""
    h, w = GH, GW
    rng = np.random.default_rng(seed)
    px_mm = h / (FAIXA_LARGURA * 1000.0)
    # Gaze hidrofila: ~19 fios por cm na urdidura, ~16 na trama.
    n_urd = int(round(FAIXA_LARGURA * 1000.0 / 0.53))
    n_tra = int(round(FAIXA_PASSO * 1000.0 / 0.62))
    cima, fio1, urd1, tra1 = trama(seed * 7 + 1, h, w, n_urd, n_tra)
    # A camada de baixo: a mesma gaze, deslocada meio fio e mais funda. E ela
    # que fecha os furos da de cima.
    baixo, fio2, _, _ = trama(seed * 7 + 2, h, w, n_urd, n_tra, grossura=0.34)
    baixo = np.roll(np.roll(baixo, 5, axis=0), 7, axis=1)
    fio2 = np.roll(np.roll(fio2, 5, axis=0), 7, axis=1)
    tecido = np.maximum(cima, np.where(fio2 > 0, baixo * 0.6 - 0.75, -1.4))
    profundo = (cima < -0.5) & (fio2 < 0.5)

    v = np.arange(h, dtype=np.float32)[:, None] + 0.5
    u = np.arange(w, dtype=np.float32)[None, :] + 0.5

    # A borda: nao e reta. A faixa foi cortada a tesoura e puiu.
    margem = h * 0.075
    b0 = margem + ruido1d(rng, 1, w, 1.4, fmin=4.0)[0] * px_mm * (0.35 + 0.35 * gasta) \
        + ruido1d(rng, 1, w, 0.8, fmin=40.0)[0] * px_mm * 0.12
    b1 = h - margem - ruido1d(rng, 1, w, 1.4, fmin=4.0)[0] * px_mm * (0.35 + 0.35 * gasta) \
        - ruido1d(rng, 1, w, 0.8, fmin=40.0)[0] * px_mm * 0.12
    dentro = (v > b0[None, :]) & (v < b1[None, :])
    d_borda = np.minimum(v - b0[None, :], b1[None, :] - v)  # px, negativo fora

    # A franja: fora da borda sobram fios soltos. Da trama, pontas que passam da
    # borda um tanto sorteado por fio; da urdidura, um ou outro fio inteiro que
    # descolou e corre ao lado da borda.
    n_tra_px = w / n_tra
    j = np.floor(u / n_tra_px).astype(np.int32) % n_tra
    ponta = rng.uniform(0.0, 1.0, n_tra) ** 2.6 * margem * 0.95
    ponta *= rng.uniform(0, 1, n_tra) < (0.55 + 0.25 * gasta)
    franja_tra = (-d_borda < ponta[j]) & ~dentro
    solto = ruido1d(rng, 1, w, 1.0, fmin=6.0)[0] > (0.7 - 0.4 * gasta)
    franja_urd = (~dentro) & (d_borda > -margem * 0.6) & solto[None, :]
    # So o fio que sobrou: da trama a ponta atravessada, da urdidura o fio
    # comprido. Sem isto a franja saia em blocos de tecido.
    franja = (franja_tra & (tra1 > 0.15)) | (franja_urd & (urd1 > 0.15))

    # Rasgo na gasta: dois ou tres buracos com a borda desfiada.
    rasgo = np.zeros((h, w), bool)
    if gasta > 0:
        rr = ruido(seed * 7 + 5, (h, w), 2.2, fmin=3.0)
        for _ in range(3):
            cu = rng.uniform(0, w)
            cv = rng.uniform(0.3, 0.7) * h
            ru = rng.uniform(0.012, 0.03) * w
            rv = rng.uniform(0.08, 0.16) * h
            du = (u - cu + w / 2) % w - w / 2
            e = (du / ru) ** 2 + ((v - cv) / rv) ** 2 + rr * 0.35
            rasgo |= e < 1.0
        # Na borda do rasgo sobram fios de trama atravessando.
        rasgo &= ~((ndimage.binary_erosion(rasgo, iterations=6) == 0) & (urd1 > 0.2))

    alfa = ((dentro & ~rasgo) | franja).astype(np.float32)
    # Fora da faixa inteira nao desenha nada: o alfa tambem mata o furo profundo
    # da franja (so fio).
    alfa = np.where(dentro & ~rasgo, 1.0, np.where(franja, 1.0, 0.0)).astype(np.float32)

    # Relevo em mm: o fio (~0,2 mm), as rugas da faixa esticada (compridas ao
    # longo de u, uma ou outra em diagonal) e a borda enrolada, mais alta.
    ruga = ruido(seed * 7 + 3, (h, w), 2.3, ax=5.0, ay=1.0, fmin=2.0) * 0.30
    ruga += ruido(seed * 7 + 4, (h, w), 2.0, ax=4.0, ay=1.0, fmin=3.0, angulo=0.45) * 0.14
    ruga += ruido(seed * 7 + 6, (h, w), 1.7, fmin=6.0) * 0.05
    enrolada = np.exp(-((d_borda - px_mm * 0.9) / (px_mm * 0.9)) ** 2) * 0.35
    alt_mm = tecido * 0.11 + ruga + enrolada
    # A franja fica baixa: o fio solto deita.
    alt_mm = np.where(dentro, alt_mm, cima * 0.08 - 0.15)

    # Cor. A gaze limpa e creme; o fio de cima pega luz, o furo e escuro (a
    # camada de baixo e a sombra dela).
    creme = cor(0.83, 0.79, 0.69)
    lum = np.clip((tecido + 1.4) / 2.6, 0.0, 1.0)
    base = np.broadcast_to(creme, (h, w, 3)) * (0.50 + 0.50 * lum)[..., None]
    base = np.where(profundo[..., None], base * 0.55, base)
    # Cada fio de algodao tem o seu tom.
    base *= (1.0 + ruido(seed * 7 + 8, (h, w), 0.6, ax=6.0, ay=1.0, fmin=40.0) * 0.035)[..., None]
    # Sujeira: encarde nos vales das rugas, nos furos e em manchas grandes.
    encarde = suave(-0.6, 1.8, ruido(seed * 7 + 9, (h, w), 2.4, fmin=1.5)) * (0.45 + 0.3 * gasta)
    encarde += suave(0.0, -0.6, ruga) * 0.2
    encarde += profundo * 0.2
    encarde = np.clip(encarde, 0.0, 1.0)
    base = mistura(base, cor(0.44, 0.37, 0.26), encarde * 0.75)
    # Soro seco: mancha amarela com a borda mais escura (a linha da mare onde o
    # liquido parou de secar). E o que faz a atadura parecer usada.
    soro_n = ruido(seed * 7 + 10, (h, w), 2.6, fmin=2.0)
    soro_n = soro_n + 0.6 * ruido(seed * 7 + 13, (h, w), 1.4, fmin=8.0)
    soro = suave(1.5, 2.1, soro_n)
    mare = suave(1.45, 1.6, soro_n) * suave(1.9, 1.6, soro_n)
    base = mistura(base, cor(0.76, 0.64, 0.40), soro * 0.35)
    base = mistura(base, cor(0.52, 0.40, 0.22), mare * 0.40)
    # Pinta: poeira e respingo miudo.
    pinta = suave(2.9, 3.6, ruido(seed * 7 + 11, (h, w), 0.3, fmin=1.0))
    base = mistura(base, cor(0.25, 0.17, 0.10), pinta * 0.7)
    # A franja e mais escura e mais suja que a faixa.
    base = np.where(dentro[..., None], base, base * 0.78)

    rug = 0.86 + 0.06 * ruido(seed * 7 + 12, (h, w), 1.2, fmin=4.0) - soro * 0.12 - lum * 0.05
    return np.clip(base, 0, 1), alt_mm, np.clip(rug, 0.3, 1.0), alfa, px_mm


def faixas():
    print("gaze")
    linhas = [gaze(3, 0.0), gaze(11, 1.0)]
    albedo = np.concatenate([l[0] for l in linhas], axis=0)
    alfa = np.concatenate([l[3] for l in linhas], axis=0)
    rug = np.concatenate([l[2] for l in linhas], axis=0)
    px_mm = linhas[0][4]
    normais = []
    for l in linhas:
        # Altura em pixel: a normal sai a da geometria de verdade.
        normais.append(normal_de(l[1] * px_mm, 0.55, envolve_x=True, envolve_y=False))
    nrm = np.concatenate(normais, axis=0)
    rgba = np.dstack([u8(albedo), u8(alfa)])
    salvar("faixa_albedo.png", rgba, "RGBA")
    salvar("faixa_normal.png", u8(nrm * 0.5 + 0.5), "RGB")
    salvar("faixa_rugosidade.png", u8(rug), "L")
    return albedo, alfa


# --- as manchas da cabeca -------------------------------------------------------

MH = MW = 2048
MM_U = 2 * np.pi * RAIO_MEDIO * 1000.0 / MW  # mm por pixel em u
MM_V = MANCHA_ALTURA * 1000.0 / MH  # mm por pixel em v


def cabeca_para_uv(x, y, z):
    u = np.arctan2(x, -z) / (2 * np.pi) + 0.5
    v = 0.5 - y / MANCHA_ALTURA
    return u * MW, v * MH


def _borrao(rng, forma_px, cu, cv, raio_mm, torto, seed):
    """Mascara de uma mancha: circulo torcido por ruido, em px, com borda mole."""
    h, w = forma_px
    rx = raio_mm / MM_U
    ry = raio_mm / MM_V
    x0, x1 = int(cu - rx * 2.2), int(cu + rx * 2.2) + 1
    y0, y1 = max(0, int(cv - ry * 2.2)), min(h, int(cv + ry * 2.2) + 1)
    if y1 <= y0:
        return None
    ys = np.arange(y0, y1, dtype=np.float32)[:, None]
    xs = np.arange(x0, x1, dtype=np.float32)[None, :]
    d = np.sqrt(((xs - cu) / rx) ** 2 + ((ys - cv) / ry) ** 2)
    rloc = np.random.default_rng(seed)
    ang = np.arctan2((ys - cv) / ry, (xs - cu) / rx)
    borda = 1.0
    for k in range(2, 9):
        borda = borda + torto / k * np.sin(ang * k + rloc.uniform(0, 6.3))
    m = suave(1.0, 0.85, d / borda)
    return (y0, y1, x0, x1, m)


def _somar(canal, bloco, peso=1.0, maximo=False):
    y0, y1, x0, x1, m = bloco
    w = canal.shape[1]
    cols = np.arange(x0, x1) % w
    if maximo:
        canal[y0:y1][:, cols] = np.maximum(canal[y0:y1][:, cols], m * peso)
    else:
        canal[y0:y1][:, cols] += m * peso


def _escorrer(draw, rng, cu, cv, comp_mm, larg_mm, lateral=0.0):
    """Um fio de sangue que desce da fresta: anda para baixo em passos de meio
    mm, torce de leve, afina, engrossa onde empoca e termina numa gota."""
    x, y = cu, cv
    w0 = larg_mm
    passos = int(comp_mm / 0.5)
    dx = lateral
    for i in range(passos):
        t = i / max(passos - 1, 1)
        dx = dx * 0.93 + rng.normal(0.0, 0.07)
        x += dx * 0.5 / MM_U
        y += 0.5 / MM_V
        larg = w0 * (1.0 - 0.45 * t) * (1.0 + 0.25 * np.sin(i * 0.21 + cu))
        if rng.uniform() < 0.012:
            larg *= 1.6
        rx = max(larg / 2 / MM_U, 0.6)
        ry = max(larg / 2 / MM_V, 0.6)
        for off in (-MW, 0, MW):
            draw.ellipse([x + off - rx, y - ry, x + off + rx, y + ry], fill=255)
    # A gota no fim.
    rx = w0 * 0.85 / MM_U
    ry = w0 * 1.1 / MM_V
    for off in (-MW, 0, MW):
        draw.ellipse([x + off - rx, y - ry * 0.6, x + off + rx, y + ry * 1.4], fill=255)
    return x, y


def manchas():
    print("manchas")
    rng = np.random.default_rng(71)
    seco = np.zeros((MH, MW), np.float32)
    soro = np.zeros((MH, MW), np.float32)
    ox, oy, oz = OLHO
    eu, ev = cabeca_para_uv(ox, oy, oz)
    cu_, cv_ = cabeca_para_uv(-ox, oy, oz)  # o olho tapado
    mu_c, mv = cabeca_para_uv(0.0, BOCA_Y, -0.085)
    meia_u = np.arctan2(BOCA_MEIA, 0.085) / (2 * np.pi) * MW

    # O olho tapado sangra atraves da faixa: a mancha grande, redonda, com a
    # linha da mare escura, e o miolo ainda molhado.
    b = _borrao(rng, (MH, MW), cu_, cv_, 21.0, 0.16, 5)
    _somar(seco, b, 0.95, True)
    b2 = _borrao(rng, (MH, MW), cu_ + 2, cv_ + 25, 30.0, 0.22, 6)
    _somar(seco, b2, 0.45, True)
    # A fresta do olho aberto: a gaze em volta encharcada.
    _somar(seco, _borrao(rng, (MH, MW), eu, ev + 6 / MM_V, 24.0, 0.2, 7), 0.8, True)
    # A boca: embebida em volta, mais embaixo (escorre).
    for k in range(5):
        du = rng.uniform(-1, 1) * meia_u
        _somar(seco, _borrao(rng, (MH, MW), mu_c + du, mv + rng.uniform(2, 12) / MM_V,
            rng.uniform(9, 17), 0.25, 20 + k), 0.75, True)
    # Manchas velhas: testa, cranio, bochecha, nuca.
    for k in range(9):
        u0 = rng.uniform(0, MW)
        v0 = rng.uniform(0.12, 0.85) * MH
        _somar(seco, _borrao(rng, (MH, MW), u0, v0, rng.uniform(4, 16), 0.55, 40 + k),
            rng.uniform(0.15, 0.45), True)
    # Escorridos secos: do olho tapado, da boca, e da testa (de quando sangrou
    # por cima).
    img_seco = Image.new("L", (MW, MH), 0)
    ds = ImageDraw.Draw(img_seco)
    for k in range(4):
        _escorrer(ds, rng, cu_ + rng.uniform(-14, 14) / MM_U, cv_ + 14 / MM_V,
            rng.uniform(35, 80), rng.uniform(2.0, 4.0))
    for k in range(6):
        _escorrer(ds, rng, mu_c + rng.uniform(-1, 1) * meia_u, mv + 8 / MM_V,
            rng.uniform(20, 60), rng.uniform(1.6, 3.4))
    for k in range(5):
        _escorrer(ds, rng, rng.uniform(0.3, 0.7) * MW, rng.uniform(0.1, 0.3) * MH,
            rng.uniform(20, 70), rng.uniform(1.2, 2.6))
    seco = np.maximum(seco, np.asarray(img_seco, np.float32) / 255.0 * 0.85)
    # Respingo: pontinhos.
    for k in range(120):
        u0 = rng.uniform(0, MW)
        v0 = rng.uniform(0.1, 0.9) * MH
        _somar(seco, _borrao(rng, (MH, MW), u0, v0, rng.uniform(0.4, 1.8), 0.2, 100 + k),
            rng.uniform(0.4, 0.9), True)
    # A mare: a borda de toda mancha seca e mais escura que o miolo.
    lisa = ndimage.gaussian_filter(seco, 3.0)
    mare = np.clip(lisa * 4.0, 0, 1) * np.clip((1.0 - lisa) * 3.0, 0, 1)
    seco = np.clip(seco * 0.8 + mare * 0.35, 0.0, 1.0)
    seco *= 0.75 + 0.25 * suave(-1.0, 1.0, ruido(72, (MH, MW), 1.8, fmin=4.0))

    # Sangue fresco: escorre das frestas agora.
    img_f = Image.new("L", (MW, MH), 0)
    df = ImageDraw.Draw(img_f)
    # Do olho aberto: da palpebra de baixo (a borda da faixa) pela bochecha.
    for k in range(3):
        _escorrer(df, rng, eu + rng.uniform(-12, 12) / MM_U, ev + 13 / MM_V,
            rng.uniform(55, 115), rng.uniform(2.6, 4.2), lateral=rng.uniform(-0.1, 0.1))
    # Da boca: do labio de baixo e dos cantos, pelo queixo.
    for k in range(5):
        _escorrer(df, rng, mu_c + rng.uniform(-0.95, 0.95) * meia_u, mv + 7 / MM_V,
            rng.uniform(30, 85), rng.uniform(2.0, 4.0))
    # Do olho tapado, atravessando a faixa.
    for k in range(2):
        _escorrer(df, rng, cu_ + rng.uniform(-8, 8) / MM_U, cv_ + 16 / MM_V,
            rng.uniform(40, 90), rng.uniform(2.0, 3.0))
    fresco = np.asarray(img_f, np.float32) / 255.0
    # Na boca da fresta o sangue empoca.
    poca = np.zeros_like(fresco)
    _somar(poca, _borrao(rng, (MH, MW), eu, ev + 12 / MM_V, 11.0, 0.3, 200), 1.0, True)
    _somar(poca, _borrao(rng, (MH, MW), mu_c, mv + 6 / MM_V, 13.0, 0.3, 201), 0.9, True)
    fresco = np.maximum(fresco, poca * 0.9)
    fresco = ndimage.gaussian_filter(fresco, 0.8)

    # Sujeira: barro da mata, mais embaixo (queixo) e numa mancha de mao que
    # arrastou pela bochecha do lado tapado — quatro dedos.
    suj = suave(-0.4, 2.0, ruido(73, (MH, MW), 2.2, fmin=2.0)) * 0.6
    vv = (np.arange(MH, dtype=np.float32)[:, None] + 0.5) / MH
    suj += suave(0.55, 0.8, vv) * 0.35
    img_m = Image.new("L", (MW, MH), 0)
    dm = ImageDraw.Draw(img_m)
    for k in range(4):
        x = cu_ - 30 / MM_U + k * 9 / MM_U
        y = cv_ - 10 / MM_V + k * 3 / MM_V
        for i in range(90):
            t = i / 89
            rx = (3.2 - 1.5 * t) / MM_U
            ry = (3.2 - 1.5 * t) / MM_V
            dm.ellipse([x - rx, y - ry, x + rx, y + ry], fill=int(255 * (1 - 0.6 * t)))
            x -= 0.35 / MM_U
            y += 0.8 / MM_V
    mao = ndimage.gaussian_filter(np.asarray(img_m, np.float32) / 255.0, 2.0)
    suj = np.clip(suj + mao * 0.8, 0.0, 1.0)
    # Soro amarelo: em volta das frestas e em nuvens.
    soro += suave(0.8, 1.8, ruido(74, (MH, MW), 2.4, fmin=2.0)) * 0.7
    _somar(soro, _borrao(rng, (MH, MW), eu, ev, 36.0, 0.25, 300), 0.6, True)
    _somar(soro, _borrao(rng, (MH, MW), mu_c, mv, 30.0, 0.25, 301), 0.5, True)
    soro = np.clip(soro, 0, 1)
    rgba = np.dstack([u8(seco), u8(fresco), u8(suj), u8(soro)])
    salvar("manchas.png", rgba, "RGBA")
    return rgba


# --- o olho ---------------------------------------------------------------------

def olho():
    print("olho")
    n = 1024
    rng = np.random.default_rng(81)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    x = (x + 0.5) / n - 0.5
    y = (y + 0.5) / n - 0.5
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    # Esclera: branco sujo, amarelando e avermelhando para a borda, que e onde
    # ela fica irritada (injetada).
    esc = np.broadcast_to(cor(0.86, 0.80, 0.70), (n, n, 3)).copy()
    esc = mistura(esc, cor(0.82, 0.64, 0.55), suave(0.22, 0.44, r) * 0.7)
    esc = mistura(esc, cor(0.62, 0.22, 0.18), suave(0.40, 0.5, r) * 0.8)
    esc *= (1.0 + ruido(82, (n, n), 1.6, fmin=4.0) * 0.04)[..., None]
    # Vasos: saem da borda e correm para a iris, ramificando e afinando.
    img = Image.new("L", (n * 2, n * 2), 0)
    d = ImageDraw.Draw(img)
    for k in range(55):
        a = rng.uniform(0, 2 * np.pi)
        rr = 0.5
        larg = rng.uniform(2.5, 6.0)
        pilha = [(a, rr, larg, 0)]
        while pilha:
            a, rr, larg, nivel = pilha.pop()
            passos = rng.integers(20, 60)
            for i in range(passos):
                x0 = (0.5 + rr * np.cos(a)) * n * 2
                y0 = (0.5 + rr * np.sin(a)) * n * 2
                a += rng.normal(0, 0.035)
                rr -= rng.uniform(0.002, 0.006)
                x1 = (0.5 + rr * np.cos(a)) * n * 2
                y1 = (0.5 + rr * np.sin(a)) * n * 2
                d.line([x0, y0, x1, y1], fill=int(255 * min(1.0, 0.45 + larg / 6)),
                    width=max(1, int(larg)))
                larg *= 0.985
                if rr < 0.2 or larg < 0.8:
                    break
                if nivel < 3 and rng.uniform() < 0.06:
                    pilha.append((a + rng.choice([-1, 1]) * rng.uniform(0.15, 0.4), rr,
                        larg * 0.7, nivel + 1))
    vaso = np.asarray(img.resize((n, n), Image.LANCZOS), np.float32) / 255.0
    vaso = np.clip(vaso * 1.3, 0, 1)
    esc = mistura(esc, cor(0.55, 0.05, 0.04), vaso * 0.9)
    # Duas manchas de derrame debaixo da conjuntiva.
    for k in range(1):
        a = rng.uniform(0, 2 * np.pi)
        cx, cy = 0.5 + 0.40 * np.cos(a), 0.5 + 0.40 * np.sin(a)
        dd = np.sqrt((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2)
        esc = mistura(esc, cor(0.45, 0.03, 0.03), suave(0.10, 0.04, dd) * 0.8)
    # Iris pequena e palida (leitosa), com fibra radial, colarete e o anel
    # escuro da borda. Pupila miuda.
    ri = 0.165
    fibra = ruido(83, (n, n), 1.0, fmin=10.0)
    # Fibra radial: amostra o ruido em coordenada polar.
    pa = ((ang / (2 * np.pi) + 0.5) * n).astype(np.int32) % n
    pr = np.clip((r / ri * n * 0.12).astype(np.int32), 0, n - 1)
    radial = fibra[pr, pa]
    iris = np.broadcast_to(cor(0.50, 0.52, 0.47), (n, n, 3)).copy()
    iris *= (1.0 + radial * 0.10)[..., None]
    iris = mistura(iris, cor(0.42, 0.38, 0.33), suave(0.5, 0.62, r / ri) * suave(0.72, 0.62, r / ri) * 0.35)
    iris = mistura(iris, cor(0.10, 0.08, 0.07), suave(0.82, 1.0, r / ri))
    pupila = 0.058 * (1.0 + 0.06 * np.sin(ang * 3.0 + 1.0))
    iris = mistura(iris, cor(0.015, 0.01, 0.01), suave(pupila + 0.004, pupila - 0.004, r))
    # O vermelho em volta da iris (o limbo injetado).
    esc = mistura(esc, cor(0.60, 0.10, 0.08), suave(0.26, ri, r) * 0.5)
    alb = np.where((r < ri + 0.004)[..., None], mistura(iris, esc, suave(ri - 0.004, ri + 0.004, r)), esc)
    brilho = suave(ri + 0.01, 0.0, r) * (0.55 + 0.45 * suave(pupila + 0.02, pupila, r))
    rgba = np.dstack([u8(np.clip(alb, 0, 1)), u8(brilho)])
    salvar("olho_albedo.png", rgba, "RGBA")


# --- a carne ---------------------------------------------------------------------

def carne():
    print("carne")
    n = 1024
    grande = ruido(91, (n, n), 2.6, fmin=2.0)
    medio = ruido(92, (n, n), 1.8, fmin=6.0)
    # Rugas: cristas do ruido (valor absoluto) — dobras de pele inchada.
    crista = 1.0 - np.abs(ruido(93, (n, n), 2.0, fmin=5.0))
    crista = np.clip(crista, 0, 1) ** 4
    poro = ruido(94, (n, n), 0.4, fmin=1.0)
    alb = np.broadcast_to(cor(0.52, 0.12, 0.09), (n, n, 3)).copy()
    alb = mistura(alb, cor(0.70, 0.30, 0.20), suave(0.2, 1.8, grande) * 0.55)
    alb = mistura(alb, cor(0.28, 0.03, 0.03), suave(0.3, 0.9, crista) * 0.8)
    alb = mistura(alb, cor(0.36, 0.07, 0.10), suave(0.5, 2.0, medio) * 0.4)
    alb *= (1.0 + poro * 0.05)[..., None]
    capilar = np.clip(1.0 - np.abs(ruido(95, (n, n), 1.5, fmin=12.0)) * 6.0, 0, 1) ** 3
    alb = mistura(alb, cor(0.45, 0.02, 0.05), capilar * 0.6)
    alt = grande * 6.0 + medio * 2.0 - crista * 5.0 + poro * 0.4
    nrm = normal_de(alt, 0.35, envolve_x=True, envolve_y=True)
    salvar("carne_albedo.png", u8(np.clip(alb, 0, 1)), "RGB")
    salvar("carne_normal.png", u8(nrm * 0.5 + 0.5), "RGB")


def main():
    previa = None
    for a in sys.argv[1:]:
        if a.startswith("--previa="):
            previa = Path(a.split("=", 1)[1])
    alb, _ = faixas()
    m = manchas()
    olho()
    carne()
    if previa is not None:
        previa.mkdir(parents=True, exist_ok=True)
        for nome in ("faixa_albedo", "faixa_normal", "manchas", "olho_albedo", "carne_albedo"):
            im = Image.open(SAIDA / (nome + ".png"))
            im.save(previa / (nome + ".png"))


if __name__ == "__main__":
    main()

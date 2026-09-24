"""Acabamento da estufa: piso, parede, teto e a pintura de parede de cada andar.

Ate aqui o chao e as paredes da estufa eram duas celulas de 32 px do atlas da
casa repetidas metro a metro — o piso lia como camuflagem e a manta das paredes
como chiado. Uma sala de cultivo montada de verdade tem acabamento de galpao:
piso de epoxi com flocos, bloco de concreto pintado com barra escura embaixo,
laje aparente no teto e a sinalizacao pintada a stencil em tudo.

Quatro texturas, cada uma em duas fidelidades (PS1 256/512 px com filtro ponto;
MODERNO 1024/2048 px com relevo e rugosidade — ver TexturasHD):

    estufa_piso     epoxi claro com flocos de tres cores, casca de laranja e
                    marca de bota. Periodo de 2 m. Neutro de proposito: a
                    faixa de cultivo e o corredor sao a MESMA textura com tinta
                    de vertice diferente (AcabamentoEstufa).
    estufa_parede   bloco de concreto 40 x 20 pintado de tinta acetinada, junta
                    frisada, poro de bloco e a trilha do rolo. Periodo 2 x 2 m
                    (cinco blocos por dez fiadas, amarracao corrida). Quase
                    branco: a barra verde embaixo e a mesma textura tingida.
    estufa_teto     laje moldada em compensado: a marca da forma a cada metro,
                    a rebarba da emenda e a mancha de agua. Periodo 2 m.
    estufa_pintura  atlas de stencil com alfa: os numeros dos andares, o nome
                    da variedade de cada um, a folha, a seta e os avisos. Branco
                    — a cor e da tinta de vertice, que e a da variedade.

O mapa do atlas de stencil (em unidades de 1024) e repetido em
game/src/world/acabamento_estufa.gd. Mudou um, mude o outro.

    python tools/gerar_estufa_acabamento.py [--previa=DIR]
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
HD = RAIZ / "game" / "assets" / "textures_hd"
PS1 = RAIZ / "game" / "assets" / "textures"
FONTES = Path("C:/Windows/Fonts")


# --- ferramentas --------------------------------------------------------------

def ruido(n, seed, beta, ax=1.0, ay=1.0, fmin=1.0):
    """Ruido 1/f^beta periodico de lado `n` (fecha sem emenda nos dois eixos)."""
    rng = np.random.default_rng(seed)
    w = rng.normal(size=(n, n))
    f = np.fft.fft2(w)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    r = np.sqrt((fx * ax) ** 2 + (fy * ay) ** 2)
    r[0, 0] = 1.0
    amp = 1.0 / np.maximum(r, fmin) ** beta
    amp[0, 0] = 0.0
    out = np.real(np.fft.ifft2(f * amp))
    out = (out - out.mean()) / (out.std() + 1e-9)
    return out.astype(np.float32)


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normal_de(h, forca):
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nn = np.dstack([-gx * forca, gy * forca, np.ones_like(h)])
    nn /= np.linalg.norm(nn, axis=2, keepdims=True)
    return nn


def u8(x):
    return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)


def gravar_hd(nome, cor, h, forca, rug, ao):
    Image.fromarray(u8(cor), "RGB").save(HD / f"{nome}.png")
    nn = normal_de(h, forca)
    Image.fromarray(u8(nn * 0.5 + 0.5), "RGB").save(HD / f"{nome}_n.png")
    ru = np.dstack([rug, ao, np.zeros_like(rug)])
    Image.fromarray(u8(ru), "RGB").save(HD / f"{nome}_ru.png")


def gravar_ps1(nome, cor, contraste=1.25):
    """O PS1 le a cor sem relevo: o que o mapa de normal fazia (a junta, a
    borda do floco) tem de estar pintado, e um pouco mais forte, senao a
    quantizacao de 5 bits come."""
    m = cor.reshape(-1, 3).mean(axis=0)
    c = np.clip((cor - m) * contraste + m, 0.0, 1.0)
    Image.fromarray(u8(c), "RGB").save(PS1 / f"{nome}.png")


def carimbar(img_l, desenhar, n):
    """Desenha com envoltorio: a mesma forma repetida nos oito vizinhos, para a
    peca que passa da borda voltar pelo outro lado (ladrilho sem emenda)."""
    d = ImageDraw.Draw(img_l)
    for oy in (-n, 0, n):
        for ox in (-n, 0, n):
            desenhar(d, ox, oy)


# --- piso: epoxi com flocos ---------------------------------------------------

FLOCOS = [
    ((0.17, 0.17, 0.18), 0.30),   # grafite
    ((0.50, 0.50, 0.49), 0.28),   # cinza
    ((0.93, 0.91, 0.86), 0.30),   # creme
    ((0.44, 0.52, 0.42), 0.12),   # salvia: a unica cor que diz "estufa"
]


def piso(n, escala_floco):
    """`escala_floco` e o raio do floco em pixel. No HD o floco tem o tamanho
    real (6 a 12 mm); no PS1 ele cresce para sobreviver ao filtro ponto."""
    rng = np.random.default_rng(1207)
    base = 0.80 + 0.016 * ruido(n, 1, 2.2, fmin=2.0) + 0.007 * ruido(n, 2, 1.0)
    cor = np.dstack([base * 0.985, base * 0.99, base * 0.975])
    h = 0.05 * ruido(n, 3, 1.3, fmin=24.0 * n / 1024.0)   # casca de laranja
    rug = 0.26 + 0.05 * ruido(n, 4, 1.8, fmin=3.0)
    ao = np.ones((n, n), np.float32)

    # Os flocos, uma camada por cor. Cada camada e uma mascara desenhada com
    # envoltorio; a ordem de desenho sai da ordem das camadas, e e aleatoria o
    # bastante porque as quatro se sobrepoem pouco.
    area = n * n
    cobertura = 0.27
    r_medio = escala_floco * 1.1
    total = int(cobertura * area / (math.pi * r_medio * r_medio))
    for (c, frac) in FLOCOS:
        m = Image.new("L", (n, n), 0)
        qtd = int(total * frac)
        pts = []
        for _ in range(qtd):
            x, y = rng.uniform(0, n), rng.uniform(0, n)
            r = escala_floco * rng.uniform(0.55, 1.6)
            lados = rng.integers(4, 8)
            a0 = rng.uniform(0, math.tau)
            poli = []
            for k in range(lados):
                a = a0 + math.tau * k / lados + rng.uniform(-0.35, 0.35)
                rr = r * rng.uniform(0.55, 1.15)
                poli.append((x + math.cos(a) * rr, y + math.sin(a) * rr * rng.uniform(0.6, 1.0)))
            pts.append(poli)

        def desenhar(d, ox, oy, pts=pts):
            for poli in pts:
                d.polygon([(px + ox, py + oy) for (px, py) in poli], fill=255)
        carimbar(m, desenhar, n)
        mk = np.asarray(m, np.float32) / 255.0
        # Floco nao e chapado: cada um tem um tom proprio, e o mesmo ruido da
        # base passa por baixo com metade da forca.
        tom = 1.0 + 0.06 * ruido(n, int(c[0] * 1000) + 5, 0.4)
        for k in range(3):
            cor[..., k] = cor[..., k] * (1.0 - mk) + (c[k] * tom) * mk
        h += mk * 0.35
        rug = rug * (1.0 - mk) + 0.33 * mk

    # Marca de bota e de roda de carrinho: arco fino, escuro e mais aspero. Pouca,
    # espalhada: e o que faz o piso ter sido PISADO.
    marca = Image.new("L", (n, n), 0)
    arcos = []
    for _ in range(46):
        cx, cy = rng.uniform(0, n), rng.uniform(0, n)
        raio = rng.uniform(0.04, 0.16) * n
        a0 = rng.uniform(0, 360)
        arcos.append((cx, cy, raio, a0, a0 + rng.uniform(12, 50),
                      max(1, int(rng.uniform(0.6, 2.2) * n / 1024.0 * 2.0))))

    def desenhar_arcos(d, ox, oy):
        for (cx, cy, raio, a0, a1, larg) in arcos:
            d.arc((cx - raio + ox, cy - raio + oy, cx + raio + ox, cy + raio + oy),
                  a0, a1, fill=255, width=larg)
    carimbar(marca, desenhar_arcos, n)
    mm = np.asarray(marca.filter(ImageFilter.GaussianBlur(n / 1024.0)), np.float32) / 255.0
    mm *= 0.55 + 0.45 * suave(-0.5, 1.2, ruido(n, 9, 1.5))
    cor *= (1.0 - 0.10 * mm)[..., None]
    rug = rug + 0.30 * mm

    # Manchas de uso: onde se passa mais o epoxi fica fosco e um pouco mais
    # escuro. Mancha grande e fraca; e ela que tira a cara de "piso de catalogo".
    uso = suave(0.6, 2.2, ruido(n, 12, 2.4, fmin=2.0))
    cor *= (1.0 - 0.05 * uso)[..., None]
    rug = np.clip(rug + 0.18 * uso, 0.0, 1.0)
    ao = ao - 0.04 * uso
    return np.clip(cor, 0, 1), h, np.clip(rug, 0, 1), np.clip(ao, 0, 1)


# --- parede: bloco de concreto pintado ------------------------------------------

def parede(n, junta_px):
    """Cinco blocos por fiada, dez fiadas, amarracao corrida: 2 x 2 m."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    bw = n / 5.0
    bh = n / 10.0
    fiada = np.floor(yy / bh)
    desloca = (fiada % 2) * bw * 0.5
    u = np.mod(xx + desloca, bw)
    v = np.mod(yy, bh)
    borda = np.minimum(np.minimum(u, bw - u), np.minimum(v, bh - v))
    # Junta frisada: meia cana funda no meio, e o bloco arredonda na quina.
    meia = junta_px * 0.5
    junta = 1.0 - suave(meia * 0.6, meia * 1.35, borda)
    quina = suave(meia, meia + junta_px * 1.2, borda)

    # Um tom por bloco: a tinta e a mesma, a absorcao do bloco nao.
    idx_bloco = (np.floor((xx + desloca) / bw) % 5) + fiada * 5
    rng = np.random.default_rng(404)
    tons = rng.normal(0.0, 1.0, 64).astype(np.float32)
    tom = tons[(idx_bloco.astype(np.int32)) % 64]

    # O poro do bloco: a tinta tampa quase tudo, mas nao o furo fundo.
    fino = ruido(n, 21, 0.6)
    poro = suave(2.15, 2.9, -fino)
    # A trilha do rolo: ruido esticado na vertical, que e para onde se passa.
    rolo = ruido(n, 22, 1.1, ax=1.0, ay=0.35, fmin=6.0 * n / 1024.0)
    mancha = ruido(n, 23, 2.3, fmin=2.0)

    base = 0.905 + 0.012 * tom + 0.010 * mancha + 0.006 * rolo
    base = base - 0.20 * poro
    base = base * (1.0 - 0.10 * junta)
    cor = np.dstack([base * 0.995, base, base * 0.975])

    h = quina * (0.55 + 0.02 * rolo) - 0.25 * poro + 0.012 * fino
    h = h - 0.35 * junta
    rug = 0.40 + 0.04 * rolo + 0.35 * poro + 0.12 * junta
    ao = 1.0 - 0.32 * junta - 0.30 * poro
    return (np.clip(cor, 0, 1), h.astype(np.float32),
            np.clip(rug, 0, 1).astype(np.float32), np.clip(ao, 0, 1).astype(np.float32))


# --- teto: laje moldada em compensado ---------------------------------------------

def teto(n, emenda_px):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    # Forma de 1 x 2 m: emenda a cada metro em X e a cada dois em Y.
    passo = n / 2.0
    dx = np.minimum(np.mod(xx, passo), passo - np.mod(xx, passo))
    dy = np.minimum(yy, n - yy)
    emenda = np.maximum(1.0 - suave(0.0, emenda_px, dx), 1.0 - suave(0.0, emenda_px, dy))
    # A veia da madeira da forma ficou no concreto: estria comprida em X.
    veio = ruido(n, 31, 1.4, ax=0.18, ay=1.0, fmin=3.0)
    mancha = ruido(n, 32, 2.2, fmin=2.0)
    # Agua que escorreu pela emenda e secou: halo amarelado so perto dela.
    agua = suave(0.8, 2.2, ruido(n, 33, 2.0, fmin=3.0)) * (1.0 - suave(0.0, n * 0.05, np.minimum(dx, dy)))
    base = 0.84 + 0.018 * veio + 0.02 * mancha - 0.10 * emenda
    cor = np.dstack([base, base * 0.995, base * 0.97])
    cor[..., 2] -= 0.07 * agua
    cor[..., 0] -= 0.02 * agua
    h = 0.06 * veio + 0.4 * emenda
    rug = 0.84 + 0.05 * mancha
    ao = 1.0 - 0.15 * emenda
    return (np.clip(cor, 0, 1), h.astype(np.float32),
            np.clip(rug, 0, 1).astype(np.float32), np.clip(ao, 0, 1).astype(np.float32))


# --- stencil ------------------------------------------------------------------

# Mapa do atlas em unidades de 1024. Espelho em acabamento_estufa.gd.
DIGITO = {d: (128 * (d - 1), 0, 128, 256) for d in range(1, 9)}
DIGITO[9] = (0, 256, 128, 256)
DIGITO[10] = (128, 256, 256, 256)
FOLHA = (384, 256, 256, 256)
SETA = (640, 256, 256, 128)
ALERTA = (896, 256, 128, 128)
ELEVADOR = (640, 384, 352, 128)
# Tinta cheia, sem spray: a faixa da parede e a demarcacao do piso param a UV
# no meio daqui.
SOLIDO = (992, 384, 32, 128)
NOMES = [
    "LAVOURA", "MORCEGA", "BONSAI DO JOTA", "SACA-ROLHA", "GIRAFA", "POMPOM",
    "CHORONA", "GAMBAZONA", "VAGALUME", "SUPER QUARTO", "PROIBIDO FUMAR",
    "AREA DE CULTIVO", "MANTENHA LIVRE", "LAVE AS MAOS", "SO FUNCIONARIOS",
    "NAO PISE NA PLANTA",
]


def rect_nome(k):
    return (512 * (k % 2), 512 + 64 * (k // 2), 512, 64)


def fonte(tam, estilo="Bold Condensed"):
    f = ImageFont.truetype(str(FONTES / "bahnschrift.ttf"), tam)
    f.set_variation_by_name(estilo)
    return f


def texto_na_caixa(d, caixa, texto, s, margem=0.1, estilo="Bold Condensed"):
    x, y, w, h = [v * s for v in caixa]
    mx, my = w * margem, h * margem
    tam = int(h * 1.4)
    while tam > 6:
        f = fonte(tam, estilo)
        l, t, r, b = d.textbbox((0, 0), texto, font=f)
        if r - l <= w - 2 * mx and b - t <= h - 2 * my:
            break
        tam -= 2
    l, t, r, b = d.textbbox((0, 0), texto, font=f)
    d.text((x + (w - (r - l)) * 0.5 - l, y + (h - (b - t)) * 0.5 - t), texto, font=f, fill=255)


def ponte_de_stencil(m, caixa, s, larg):
    """O corte do molde: a faixa fina que segura o miolo da letra. E o que faz
    o numero ser PINTADO com molde, e nao impresso."""
    x, y, w, h = [v * s for v in caixa]
    d = ImageDraw.Draw(m)
    cx = x + w * 0.5
    d.rectangle((cx - larg * 0.5, y + h * 0.22, cx + larg * 0.5, y + h * 0.30), fill=0)
    d.rectangle((cx - larg * 0.5, y + h * 0.70, cx + larg * 0.5, y + h * 0.78), fill=0)


def folha(d, caixa, s):
    x, y, w, h = [v * s for v in caixa]
    cx, base = x + w * 0.5, y + h * 0.80
    R = h * 0.62
    for ang, comp in zip([-100, -66, -33, 0, 33, 66, 100],
                         [0.40, 0.64, 0.86, 1.0, 0.86, 0.64, 0.40]):
        a = math.radians(ang)
        dirx, diry = math.sin(a), -math.cos(a)
        px, py = -diry, dirx
        L = R * comp
        W = L * 0.15
        lado_a, lado_b = [], []
        passos = 28
        for k in range(passos + 1):
            t = k / passos
            meia = W * math.sin(math.pi * min(1.0, t * 1.08)) ** 0.75
            # Serrilhado: o dente aponta para a ponta.
            if 0.08 < t < 0.95:
                meia *= 1.0 + (0.22 if k % 2 == 0 else -0.05)
            cxk, cyk = cx + dirx * L * t, base + diry * L * t
            lado_a.append((cxk + px * meia, cyk + py * meia))
            lado_b.append((cxk - px * meia, cyk - py * meia))
        d.polygon(lado_a + lado_b[::-1], fill=255)
    d.rectangle((cx - w * 0.018, base, cx + w * 0.018, y + h * 0.97), fill=255)


def seta(d, caixa, s):
    x, y, w, h = [v * s for v in caixa]
    # Seta para a direita, cheia: corpo e cabeca.
    cy = y + h * 0.5
    d.rectangle((x + w * 0.08, cy - h * 0.16, x + w * 0.62, cy + h * 0.16), fill=255)
    d.polygon([(x + w * 0.58, y + h * 0.1), (x + w * 0.92, cy), (x + w * 0.58, y + h * 0.9)], fill=255)


def alerta(d, caixa, s):
    x, y, w, h = [v * s for v in caixa]
    m = w * 0.08
    tri = [(x + w * 0.5, y + m), (x + w - m, y + h - m), (x + m, y + h - m)]
    d.polygon(tri, fill=255)
    interno = [(x + w * 0.5, y + m + h * 0.2), (x + w - m - w * 0.14, y + h - m - h * 0.07),
               (x + m + w * 0.14, y + h - m - h * 0.07)]
    d.polygon(interno, fill=0)
    d.rectangle((x + w * 0.46, y + h * 0.4, x + w * 0.54, y + h * 0.7), fill=255)
    d.rectangle((x + w * 0.46, y + h * 0.75, x + w * 0.54, y + h * 0.82), fill=255)


def pintura(s):
    """`s` = pixels por unidade do mapa (2 no HD de 2048)."""
    n = int(1024 * s)
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    for dig, caixa in DIGITO.items():
        texto_na_caixa(d, caixa, str(dig), s, margem=0.06)
        if dig in (8, 9, 10):
            ponte_de_stencil(m, caixa, s, 5 * s)
    folha(d, FOLHA, s)
    seta(d, SETA, s)
    alerta(d, ALERTA, s)
    texto_na_caixa(d, ELEVADOR, "ELEVADOR", s, margem=0.12)
    for k, nome in enumerate(NOMES):
        texto_na_caixa(d, rect_nome(k), nome, s, margem=0.12)

    # Spray: a borda abre um pouco e vira pontilhado, e um halo de respingo fino
    # cai em volta — o que o molde deixa passar.
    a = np.asarray(m.filter(ImageFilter.GaussianBlur(1.2 * s)), np.float32) / 255.0
    grao = ruido(n, 51, 0.2) if n <= 2048 else np.zeros((n, n), np.float32)
    alfa = suave(0.35, 0.65, a + 0.09 * grao)
    halo = np.asarray(m.filter(ImageFilter.GaussianBlur(5.0 * s)), np.float32) / 255.0
    respingo = (grao > 1.9).astype(np.float32) * suave(0.05, 0.3, halo) * (alfa < 0.5)
    alfa = np.maximum(alfa, respingo)
    # A tinta nao cobre por igual: o miolo tem falha onde o spray passou rapido.
    # Fraca: a primeira versao comia letra inteira ("VAGA_UME").
    falha = suave(2.1, 2.8, ruido(n, 52, 1.6, fmin=8.0))
    alfa = alfa * (1.0 - 0.4 * falha)
    x, y, w, h = [int(v * s) for v in SOLIDO]
    alfa[y:y + h, x:x + w] = 1.0
    return alfa


# --- saida --------------------------------------------------------------------

def main():
    previa = None
    for arg in sys.argv[1:]:
        if arg.startswith("--previa="):
            previa = Path(arg.split("=", 1)[1])
            previa.mkdir(parents=True, exist_ok=True)

    cor, h, rug, ao = piso(1024, 3.2)
    gravar_hd("estufa_piso", cor, h, 3.0, rug, ao)
    c1, _, _, _ = piso(256, 1.25)
    gravar_ps1("estufa_piso", c1, 1.15)
    if previa:
        Image.fromarray(u8(cor)).save(previa / "piso.png")

    cor, h, rug, ao = parede(1024, 5.5)
    gravar_hd("estufa_parede", cor, h, 6.0, rug, ao)
    c1, _, _, a1 = parede(256, 2.2)
    gravar_ps1("estufa_parede", c1 * (0.75 + 0.25 * a1)[..., None], 1.2)
    if previa:
        Image.fromarray(u8(cor)).save(previa / "parede.png")

    cor, h, rug, ao = teto(1024, 4.0)
    gravar_hd("estufa_teto", cor, h, 3.0, rug, ao)
    c1, _, _, _ = teto(256, 1.6)
    gravar_ps1("estufa_teto", c1, 1.2)

    for s, destino in ((2.0, HD / "estufa_pintura.png"), (0.5, PS1 / "estufa_pintura.png")):
        alfa = pintura(s) if s >= 1.0 else None
        if alfa is None:
            # O PS1 sai do HD reduzido, com alfa binario: filtro ponto e corte.
            grande = pintura(2.0)
            img = Image.fromarray(u8(grande), "L").resize((512, 512), Image.BOX)
            alfa = (np.asarray(img, np.float32) / 255.0 > 0.45).astype(np.float32)
        n = alfa.shape[0]
        rgba = np.dstack([np.ones((n, n, 3), np.float32), alfa])
        Image.fromarray(u8(rgba), "RGBA").save(destino)
        if previa and s >= 1.0:
            fundo = np.dstack([np.full((n, n), 0.2)] * 3)
            prev = fundo * (1 - alfa[..., None]) + alfa[..., None]
            Image.fromarray(u8(prev)).resize((1024, 1024)).save(previa / "pintura.png")
    print("ok")


if __name__ == "__main__":
    main()

"""A sacola de colheita de Jota e Helmer: saco de rafia branco, impresso.

E o saco de rafia de qualquer deposito do Brasil — fita de polipropileno
trancada, costura de linha no fundo e na lateral, e a impressao de uma cor so
em verde: COLHEITA, a folha, CASA DA FUMACA e o "PESO LIQUIDO: MUITO", que e a
piada que o saco conta sozinho quando esta do tamanho de uma pessoa.

A textura veste o saco INTEIRO (SacolaDeColheita): U da uma volta, V vai do
fundo a boca. Por isso ela e 2:1 e tem uma impressao so, na frente (U = 0,25),
com a costura lateral em U = 0 e o fundo sujo de chao em V baixo. O saco cresce
e a impressao cresce junto — e um saco inflado, e e engracado assim.

    game/assets/textures_hd/estufa_sacola(.png, _n.png, _ru.png)  2048 x 1024
    game/assets/textures/estufa_sacola.png                        256 x 128

    python tools/gerar_estufa_sacola.py [--previa=DIR]
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

VERDE = np.array([0.16, 0.42, 0.22], np.float32)


def ruido(h, w, seed, beta, fmin=1.0):
    """Ruido 1/f^beta periodico (h x w)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.normal(size=(h, w)))
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    amp = 1.0 / np.maximum(r, fmin) ** beta
    amp[0, 0] = 0.0
    out = np.real(np.fft.ifft2(f * amp))
    return ((out - out.mean()) / (out.std() + 1e-9)).astype(np.float32)


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def u8(x):
    return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)


def fonte(tam, estilo="Bold Condensed"):
    f = ImageFont.truetype(str(FONTES / "bahnschrift.ttf"), tam)
    f.set_variation_by_name(estilo)
    return f


def texto(d, cx, cy, s, tam, estilo="Bold Condensed"):
    f = fonte(tam, estilo)
    l, t, r, b = d.textbbox((0, 0), s, font=f)
    d.text((cx - (r - l) * 0.5 - l, cy - (b - t) * 0.5 - t), s, font=f, fill=255)


def folha(d, cx, base, R):
    for ang, comp in zip([-100, -66, -33, 0, 33, 66, 100],
                         [0.40, 0.64, 0.86, 1.0, 0.86, 0.64, 0.40]):
        a = math.radians(ang)
        dx, dy = math.sin(a), -math.cos(a)
        px, py = -dy, dx
        L = R * comp
        W = L * 0.15
        la, lb = [], []
        for k in range(29):
            t = k / 28
            meia = W * math.sin(math.pi * min(1.0, t * 1.08)) ** 0.75
            if 0.08 < t < 0.95:
                meia *= 1.0 + (0.22 if k % 2 == 0 else -0.05)
            x, y = cx + dx * L * t, base + dy * L * t
            la.append((x + px * meia, y + py * meia))
            lb.append((x - px * meia, y - py * meia))
        d.polygon(la + lb[::-1], fill=255)
    d.rectangle((cx - R * 0.03, base, cx + R * 0.03, base + R * 0.3), fill=255)


def impressao(w, h):
    """A mascara da tinta verde, em (h, w). A frente e U = 0,25."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    cx = w * 0.25
    # Duas faixas em volta, como todo saco de rafia.
    for v0, v1 in ((0.235, 0.255), (0.795, 0.812)):
        d.rectangle((0, h * (1 - v1), w, h * (1 - v0)), fill=255)
    texto(d, cx, h * (1 - 0.70), "COLHEITA", int(h * 0.105))
    folha(d, cx, h * (1 - 0.40), h * 0.2)
    texto(d, cx, h * (1 - 0.335), "CASA DA FUMACA", int(h * 0.05))
    texto(d, cx, h * (1 - 0.29), "PESO LIQUIDO: MUITO", int(h * 0.028), "SemiBold Condensed")
    # O lote carimbado de lado, torto.
    lote = Image.new("L", (int(w * 0.12), int(h * 0.05)), 0)
    dl = ImageDraw.Draw(lote)
    texto(dl, lote.width * 0.5, lote.height * 0.5, "LOTE 420", int(lote.height * 0.8))
    lote = lote.rotate(8, expand=True)
    m.paste(255, (int(w * 0.36), int(h * (1 - 0.56))), lote)
    return np.asarray(m, np.float32) / 255.0


def gerar(w, h, fita, tintas=None, costura_lateral=True, semente=0):
    """`tintas`: [(mascara h x w de 0 a 1, cor rgb)], na ordem de impressao. Sem
    elas, a impressao da sacola (COLHEITA, verde). Quem usa com tintas proprias
    e o gerador dos sacos rotulados (gerar_estufa_sacos_rotulados.py)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # A trama: fita horizontal e vertical, uma por cima e outra por baixo.
    cx = np.floor(xx / fita)
    cy = np.floor(yy / fita)
    fx = (xx / fita) % 1.0
    fy = (yy / fita) % 1.0
    por_cima = ((cx + cy) % 2) == 0
    # Cada fita e abaulada no meio e afunda na borda.
    perfil_h = np.sin(np.pi * fy) ** 0.6
    perfil_v = np.sin(np.pi * fx) ** 0.6
    h_trama = np.where(por_cima, 0.55 + 0.45 * perfil_h, 0.55 + 0.45 * perfil_v)
    brilho_fita = np.where(por_cima, perfil_h, perfil_v)

    base = 0.86 + 0.025 * ruido(h, w, 1 + semente, 1.8, fmin=3.0)
    base = base * (0.93 + 0.07 * brilho_fita)
    cor = np.dstack([base * 0.985, base * 0.98, base * 0.945])

    # A tinta: meio falhada onde a fita afunda (a impressao pega no alto da
    # trama).
    if tintas is None:
        tintas = [(impressao(w, h), VERDE)]
    pega = suave(0.25, 0.75, h_trama + 0.15 * ruido(h, w, 2 + semente, 0.3))
    tinta = np.zeros((h, w), np.float32)
    for mascara, cor_tinta in tintas:
        m = np.asarray(Image.fromarray(u8(mascara)).filter(ImageFilter.GaussianBlur(w / 2048.0)),
                       np.float32) / 255.0
        m = m * (0.55 + 0.45 * pega)
        for k in range(3):
            cor[..., k] = cor[..., k] * (1.0 - m) + float(cor_tinta[k]) * m * (0.9 + 0.1 * base)
        tinta = np.maximum(tinta, m)

    # Costura lateral (U = 0) e do fundo: pontos de linha escura.
    costura = np.zeros((h, w), np.float32)
    passo = max(3, int(w / 160))
    larg = max(1, int(w / 700))
    for y0 in range(0, h, passo * 2) if costura_lateral else []:
        costura[y0:y0 + passo, :larg * 2] = 1.0
        costura[y0:y0 + passo, w - larg * 2:] = 1.0
    for x0 in range(0, w, passo * 2):
        costura[h - int(h * 0.03) - larg:h - int(h * 0.03) + larg, x0:x0 + passo] = 1.0
    cor *= (1.0 - 0.35 * costura)[..., None]

    # Sujo: o fundo arrasta no chao da estufa (terra), e respingo verde de seiva
    # onde a planta encostou.
    v = 1.0 - yy / h
    terra = suave(0.22, 0.0, v) * (0.55 + 0.45 * suave(-0.8, 1.2, ruido(h, w, 3, 1.6, fmin=4.0)))
    cor = cor * (1.0 - 0.45 * terra[..., None]) + np.array([0.32, 0.24, 0.16]) * 0.45 * terra[..., None]
    seiva = suave(1.9, 2.6, ruido(h, w, 4, 1.9, fmin=6.0)) * suave(0.35, 0.95, v)
    cor = cor * (1.0 - 0.3 * seiva[..., None]) + np.array([0.36, 0.5, 0.22]) * 0.3 * seiva[..., None]

    altura = h_trama * 0.6 + costura * 0.3 + tinta * 0.05
    rug = 0.52 + 0.18 * (1.0 - brilho_fita) + 0.2 * terra - 0.08 * tinta
    ao = 0.82 + 0.18 * h_trama - 0.2 * costura
    return np.clip(cor, 0, 1), altura.astype(np.float32), np.clip(rug, 0, 1), np.clip(ao, 0, 1)


def normal_de(hm, forca):
    gx = (np.roll(hm, -1, axis=1) - np.roll(hm, 1, axis=1)) * 0.5
    gy = (np.roll(hm, -1, axis=0) - np.roll(hm, 1, axis=0)) * 0.5
    n = np.dstack([-gx * forca, gy * forca, np.ones_like(hm)])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def main():
    previa = None
    for a in sys.argv[1:]:
        if a.startswith("--previa="):
            previa = Path(a.split("=", 1)[1])
            previa.mkdir(parents=True, exist_ok=True)
    cor, alt, rug, ao = gerar(2048, 1024, 6.0)
    Image.fromarray(u8(cor), "RGB").save(HD / "estufa_sacola.png")
    Image.fromarray(u8(normal_de(alt, 2.5) * 0.5 + 0.5), "RGB").save(HD / "estufa_sacola_n.png")
    Image.fromarray(u8(np.dstack([rug, ao, np.zeros_like(rug)])), "RGB").save(HD / "estufa_sacola_ru.png")
    # O PS1 sai da mesma cor reduzida: a trama vira grao, a impressao fica.
    Image.fromarray(u8(cor), "RGB").resize((256, 128), Image.BOX).save(PS1 / "estufa_sacola.png")
    if previa:
        Image.fromarray(u8(cor)).resize((1024, 512), Image.LANCZOS).save(previa / "sacola.png")
        Image.fromarray(u8(cor[:512, 256:768])).save(previa / "sacola_zoom.png")
    print("ok")


if __name__ == "__main__":
    main()

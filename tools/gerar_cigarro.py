"""Textura do cigarro da abertura: um Marlboro branco, de filtro de cortica.

O cigarro antigo era o bastao do `Adereco`: um paralelepipedo com um retalho
bege do casa_atlas, que de perto (e no POV, a doze centimetros do olho) lia
como um bloco amarelo aceso. O `Cigarro` (src/render/cigarro.gd) e a malha
redonda da `Blunt` com as medidas de um king size, e esta e a pele dele, no
MESMO desenho de atlas da blunt, para a malha servir aos dois:

    v 0,000 - 0,625   CORPO    U ao comprido (0 na boca do filtro, 1 na ponta de
                               um cigarro inteiro de 84 mm), V em volta.
                               u < 0,3214: o papel do filtro, cortica (laranja
                               queimado com pinta marrom) e o friso dourado junto
                               da emenda. Depois: papel branco com a costura
                               ao comprido, a trama fina do papel, o fumo
                               sombreando por dentro e a marca impressa perto do
                               filtro.
    v 0,625 - 0,8125  CINZA    cinza de cigarro: cinza-clara em camadas, mais
                               fina e mais branca que a da blunt.
    v 0,8125 - 1      BOCA     (u 0 - 0,1875) a boca do filtro: acetato branco
                               de fibra, com o anel do papel de cortica em volta.
                      BRASA    (u 0,25 - 1) a mesma da blunt.

Saem em game/assets/textures_hd/ (cigarro, cigarro_n, cigarro_ru) e o atlas de
128 px do PS1 em game/assets/textures/cigarro.png.

    python tools/gerar_cigarro.py [--previa=DIR]
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import gerar_blunt as gb

L = gb.L
V_CORPO = gb.V_FOLHA
V_CINZA = gb.V_CINZA
U_BOCA = gb.U_PITEIRA
U_BRASA0 = gb.U_BRASA0

# Medidas do cigarro, em mm (as mesmas de Cigarro.gd).
COMPRIMENTO = 84.0
FILTRO = 27.0
RAIO = 3.9
U_FILTRO = FILTRO / COMPRIMENTO

ruido, suave, mistura, cor, u8 = gb.ruido, gb.suave, gb.mistura, gb.cor, gb.u8


def marca(largura, altura, mm_larg, mm_alt):
    """A marca impressa, deitada ao comprido do cigarro. Desenhada num quadro na
    proporcao em milimetros e depois espremida para o atlas, que e
    anisotropico: 1 mm ao comprido sao 12 px, e em volta sao 26."""
    w = largura * 8
    h = int(w * mm_alt / mm_larg)
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    fonte = None
    for nome in ("georgiab.ttf", "timesbd.ttf", "arialbd.ttf"):
        try:
            fonte = ImageFont.truetype("C:/Windows/Fonts/" + nome, int(h * 0.78))
            break
        except OSError:
            continue
    if fonte is None:
        fonte = ImageFont.load_default()
    texto = "Marlboro"
    caixa = d.textbbox((0, 0), texto, font=fonte)
    tw, th = caixa[2] - caixa[0], caixa[3] - caixa[1]
    fator = min(w * 0.98 / tw, 1.0)
    if fator < 1.0:
        fonte = ImageFont.truetype(fonte.path, int(h * 0.78 * fator)) \
            if hasattr(fonte, "path") else fonte
        caixa = d.textbbox((0, 0), texto, font=fonte)
        tw, th = caixa[2] - caixa[0], caixa[3] - caixa[1]
    d.text(((w - tw) * 0.5 - caixa[0], (h - th) * 0.5 - caixa[1]), texto, fill=255, font=fonte)
    img = img.resize((largura, altura), Image.LANCZOS)
    return np.asarray(img, np.float32) / 255.0


def corpo():
    h, w = V_CORPO, L
    v = (np.arange(h, dtype=np.float32)[:, None] + 0.5) / h
    u = (np.arange(w, dtype=np.float32)[None, :] + 0.5) / w
    uu = np.broadcast_to(u, (h, w))
    vv = np.broadcast_to(v, (h, w))
    mm_u = uu * COMPRIMENTO

    # --- papel branco -------------------------------------------------------
    papel = np.broadcast_to(cor(0.945, 0.943, 0.925), (h, w, 3)).copy()
    # O fumo por dentro: o papel e fino e deixa passar a sombra quente dele, em
    # manchas compridas ao longo do eixo.
    fumo = ruido(51, (h, w), 2.2, ax=2.5, ay=1.0, fmin=3.0)
    papel = mistura(papel, cor(0.90, 0.875, 0.80), suave(-0.4, 1.8, fumo) * 0.55)
    # A trama do papel: listras finissimas em volta (papel vergê).
    trama = np.sin(mm_u * 2.0 * np.pi * 1.45) * 0.5 + 0.5
    papel *= (1.0 - trama[..., None] * 0.018)
    fibra = ruido(52, (h, w), 0.8, fmin=40.0)
    papel *= (1.0 + fibra[..., None] * 0.012)
    # A costura: a aba de papel colada por cima, ao comprido, num ponto da volta.
    dv = np.abs(((vv - 0.62) + 0.5) % 1.0 - 0.5) * (2.0 * np.pi * RAIO)  # mm
    aba = suave(0.55, 0.15, dv)
    papel = mistura(papel, cor(0.92, 0.915, 0.89), aba * 0.45)
    borda_aba = suave(0.10, 0.0, np.abs(dv - 0.45)) * (vv > 0.62)
    papel = mistura(papel, cor(0.84, 0.83, 0.80), borda_aba * 0.35)

    # A marca, a 4 mm da emenda, uma vez na volta.
    m_larg, m_alt = int(11.5 * 1024 / COMPRIMENTO), int(2.1 * V_CORPO / (2 * np.pi * RAIO))
    m = marca(m_larg, m_alt, 11.5, 2.1)
    x0 = int((FILTRO + 3.5) / COMPRIMENTO * w)
    y0 = int(0.22 * h)
    tinta = np.zeros((h, w), np.float32)
    tinta[y0:y0 + m_alt, x0:x0 + m_larg] = m
    papel = mistura(papel, cor(0.16, 0.12, 0.11), tinta * 0.85)
    # O telhadinho vermelho antes da marca.
    tx = x0 - int(2.4 / COMPRIMENTO * w)
    ty = y0 + m_alt // 2
    teto = np.zeros((h, w), np.float32)
    for k in range(int(1.6 / COMPRIMENTO * w)):
        alto = int(m_alt * 0.42 * (1.0 - abs(k / (1.6 / COMPRIMENTO * w) * 2 - 1)))
        teto[ty - alto:ty - alto + max(3, m_alt // 7), tx + k] = 1.0
    papel = mistura(papel, cor(0.70, 0.08, 0.10), teto * 0.9)

    # --- o filtro: papel de cortica -----------------------------------------
    cortica = np.broadcast_to(cor(0.80, 0.52, 0.25), (h, w, 3)).copy()
    grande = ruido(61, (h, w), 2.0, fmin=4.0)
    cortica = mistura(cortica, cor(0.86, 0.60, 0.31), suave(-1.0, 1.4, grande) * 0.5)
    # A pinta da cortica: manchas pequenas e irregulares, marrom, bem densas.
    pinta = ruido(62, (h, w), 0.9, ax=1.0, ay=2.1, fmin=18.0)
    pinta2 = ruido(63, (h, w), 0.7, ax=1.0, ay=2.1, fmin=30.0)
    escura = suave(0.55, 1.35, pinta) * 0.75 + suave(1.2, 2.0, pinta2) * 0.35
    cortica = mistura(cortica, cor(0.50, 0.27, 0.10), np.clip(escura, 0, 1))
    clara = suave(1.3, 2.1, -pinta2)
    cortica = mistura(cortica, cor(0.93, 0.74, 0.47), clara * 0.5)
    # O friso dourado, 1,6 mm antes da emenda, e a emenda com o papel.
    d_emenda = FILTRO - mm_u
    friso = suave(0.28, 0.08, np.abs(d_emenda - 1.6))
    cortica = mistura(cortica, cor(0.86, 0.71, 0.36), friso * 0.9)

    filtro = uu < U_FILTRO
    base = np.where(filtro[..., None], cortica, papel)
    # A borda do papel de cortica faz uma sombrinha no papel branco.
    base = mistura(base, cor(0.70, 0.66, 0.60), suave(0.35, 0.0, mm_u - FILTRO) * (~filtro) * 0.55)

    altura = np.where(filtro, escura * 0.25 + grande * 0.04, fibra * 0.05 + trama * 0.06 + aba * 0.4)
    rug = np.where(filtro, 0.55 - friso * 0.25 + escura * 0.08, 0.86 - aba * 0.05)
    ao = np.where(filtro, 1.0 - escura * 0.12, 1.0 - borda_aba * 0.2)
    return np.clip(base, 0, 1), altura.astype(np.float32), rug.astype(np.float32), \
        ao.astype(np.float32)


def cinza():
    """Cinza de cigarro: papel e fumo queimados em camadas finas, cinza-clara,
    com o fio escuro de cada anel e o carvao so no primeiro milimetro (a cinza
    do cigarro tem 1 cm, e a regiao inteira de U cobre 3: o carvao da blunt, que
    vai ate 0,16, pintava a cinza toda de preto)."""
    h, w = V_CINZA, L
    u = (np.arange(w, dtype=np.float32)[None, :] + 0.5) / w
    torto = ruido(81, (h, w), 2.4, fmin=2.0)
    anel = np.sin((u * 40.0 + torto * 0.05) * np.pi * 2.0) * 0.5 + 0.5
    anel = anel ** 4
    mancha = ruido(82, (h, w), 1.8, fmin=8.0)
    base = mistura(np.broadcast_to(cor(0.64, 0.635, 0.62), (h, w, 3)).copy(),
        cor(0.84, 0.835, 0.82), suave(-0.9, 1.1, mancha))
    base = mistura(base, cor(0.36, 0.35, 0.34), anel * 0.5)
    rac = ruido(83, (h, w), 1.5, fmin=12.0)
    fenda = np.clip(1.0 - np.abs(rac) * 12.0, 0.0, 1.0) ** 2
    base = mistura(base, cor(0.22, 0.21, 0.20), fenda * 0.6)
    base = mistura(base, cor(0.10, 0.09, 0.09), suave(0.035, 0.0, u) * 0.9)
    altura = anel * 0.3 + mancha * 0.08 - fenda * 0.6
    rug = np.full((h, w), 0.97, np.float32)
    ao = 1.0 - fenda * 0.4
    return np.clip(base, 0, 1), altura, rug, ao


def boca():
    n = U_BOCA
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = cy = (n - 1) * 0.5
    dx, dy = (x - cx) / (n * 0.5), (y - cy) / (n * 0.5)
    r = np.sqrt(dx * dx + dy * dy)
    # Acetato: fibra branca amassada, com pontinho de sombra.
    fibra = ruido(71, (n, n), 0.6, fmin=10.0)
    fibra2 = ruido(72, (n, n), 1.2, fmin=4.0)
    base = mistura(np.broadcast_to(cor(0.93, 0.915, 0.86), (n, n, 3)).copy(),
        cor(0.78, 0.76, 0.70), suave(0.6, 1.8, fibra) * 0.6)
    base *= (1.0 + fibra2[..., None] * 0.03)
    # O papel de cortica dando a volta na borda, e o fio escuro da borda.
    anel = suave(0.90, 0.94, r)
    base = mistura(base, cor(0.74, 0.47, 0.22), anel)
    base = mistura(base, cor(0.20, 0.14, 0.10), suave(0.975, 1.0, r))
    altura = -suave(0.6, 1.8, fibra) * 0.4 + anel * 0.3
    rug = 0.95 - anel * 0.3
    ao = 1.0 - suave(0.6, 1.8, fibra) * 0.25
    return np.clip(base, 0, 1), altura, rug, ao


def atlas():
    cor_ = np.zeros((L, L, 3), np.float32)
    alt = np.zeros((L, L), np.float32)
    rug = np.ones((L, L), np.float32)
    ao = np.ones((L, L), np.float32)

    def por(regiao, y0, x0):
        c, a, r, o = regiao
        h, w = a.shape
        cor_[y0:y0 + h, x0:x0 + w] = c
        alt[y0:y0 + h, x0:x0 + w] = a
        rug[y0:y0 + h, x0:x0 + w] = r
        ao[y0:y0 + h, x0:x0 + w] = o

    por(corpo(), 0, 0)
    por(cinza(), V_CORPO, 0)
    por(boca(), V_CORPO + V_CINZA, 0)
    por(gb.brasa(), V_CORPO + V_CINZA, U_BRASA0)
    n = np.zeros((L, L, 3), np.float32)
    n[..., 2] = 1.0
    for (y0, y1, x0, x1, forca) in ((0, V_CORPO, 0, L, 1.2),
            (V_CORPO, V_CORPO + V_CINZA, 0, L, 2.0),
            (V_CORPO + V_CINZA, L, 0, U_BOCA, 1.6),
            (V_CORPO + V_CINZA, L, U_BRASA0, L, 1.5)):
        n[y0:y1, x0:x1] = gb.normal_de(alt[y0:y1, x0:x1], forca)
    return cor_, n, np.dstack([rug, ao, np.zeros_like(rug)])


def main() -> int:
    previa = None
    for arg in sys.argv[1:]:
        if arg.startswith("--previa="):
            previa = Path(arg.split("=", 1)[1])
    c, n, ru = atlas()
    Image.fromarray(u8(c), "RGB").save(gb.HD / "cigarro.png", optimize=True)
    Image.fromarray(u8(n * 0.5 + 0.5), "RGB").save(gb.HD / "cigarro_n.png", optimize=True)
    Image.fromarray(u8(ru), "RGB").save(gb.HD / "cigarro_ru.png", optimize=True)
    p = Image.fromarray(u8(c), "RGB").resize((128, 128), Image.LANCZOS)
    p.quantize(colors=64, method=Image.Quantize.MEDIANCUT).convert("RGB").save(
        gb.PS1 / "cigarro.png", optimize=True)
    print("cigarro media", (c.reshape(-1, 3).mean(axis=0) * 255).round(1))
    if previa is not None:
        previa.mkdir(parents=True, exist_ok=True)
        Image.fromarray(u8(c), "RGB").save(previa / "cigarro_cor.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())

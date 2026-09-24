"""Os sacos costurados do deposito da estufa, impressos por variedade.

A pilha de sacolas (DepositoDaEstufa) era de sacos de rafia todos iguais, com a
mesma impressao da sacola de colheita. Um deposito de verdade tem saco de
produto: costurado em cima, cheio ate a orelha e impresso com o que tem dentro.
Aqui cada variedade tem a sua cara, em duas tintas, como impressao de saco de
feira:

    faixa na cor da variedade em cima e embaixo
    CASA DA FUMACA pequeno
    o emblema da variedade, desenhado — a Morcega pendurada de cabeca para
    baixo, o bonsai no vaso, o saca-rolha, a girafa, o pompom com laco, o
    salgueiro chorando, o gamba com a cauda e o vagalume aceso
    o NOME grande, e a frase dela
    ANDAR n na caixa escura, e o PESO LIQUIDO: MUITO

O atlas tem 4 x 3 celulas de 512 x 682 (no HD de 2048): as nove frentes (na
ordem dos andares, 1 a 9), o verso, e rafia lisa (lados, dentro da boca). O
mapa esta repetido em DepositoDaEstufa (CELULA_*). A trama e a sujeira sao as
da sacola (gerar_estufa_sacola.gerar), com outras tintas.

    game/assets/textures_hd/estufa_sacos(.png, _n.png, _ru.png)   2048 x 2048
    game/assets/textures/estufa_sacos.png                          512 x 512

    python tools/gerar_estufa_sacos_rotulados.py [--previa=DIR]
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gerar_estufa_sacola as sacola  # noqa: E402

HD = sacola.HD
PS1 = sacola.PS1
N = 2048
CW = 512
CH = 682

TINTA_ESCURA = (0.13, 0.22, 0.17)

# Na ordem dos andares (Variedades.DO_ANDAR). Cor como em Variedades.DADOS.
VARIEDADES = [
    ("comum", "MACONHA", "A DE SEMPRE", (0.42, 0.62, 0.26)),
    ("morcega", "MORCEGA", "CRESCE DE CABECA PRA BAIXO", (0.55, 0.42, 0.62)),
    ("bonsai", "BONSAI DO JOTA", "PEQUENA MAS BRAVA", (0.78, 0.52, 0.30)),
    ("saca_rolha", "SACA-ROLHA", "ENROLADA POR NATUREZA", (0.30, 0.68, 0.64)),
    ("girafa", "GIRAFA", "ALTA DEMAIS", (0.92, 0.74, 0.28)),
    ("pompom", "POMPOM", "FOFA E PERIGOSA", (0.92, 0.46, 0.62)),
    ("chorona", "CHORONA", "CHORA MAS DA", (0.40, 0.50, 0.80)),
    ("gambazona", "GAMBAZONA", "CHEIRO FORTE, SEM DESCULPA", (0.62, 0.78, 0.22)),
    ("vagalume", "VAGALUME", "ACENDE NO ESCURO", (0.36, 0.92, 0.86)),
]


def celula(k):
    col, lin = k % 4, k // 4
    return col * CW, lin * CH


# --- desenho ------------------------------------------------------------------

def texto_caber(d, cx, cy, s, larg, alt, estilo="Bold Condensed", fill=255):
    tam = int(alt * 1.4)
    while tam > 6:
        f = sacola.fonte(tam, estilo)
        l, t, r, b = d.textbbox((0, 0), s, font=f)
        if r - l <= larg and b - t <= alt:
            break
        tam -= 2
    l, t, r, b = d.textbbox((0, 0), s, font=f)
    d.text((cx - (r - l) * 0.5 - l, cy - (b - t) * 0.5 - t), s, font=f, fill=fill)


def emblema(d, v, cx, cy, s):
    """O desenho da variedade em (cx, cy), cabendo num quadrado de lado ~s."""
    P = lambda x, y: (cx + x * s, cy + y * s)  # noqa: E731
    if v == "comum":
        sacola.folha(d, cx, cy + 0.42 * s, 0.82 * s)
    elif v == "morcega":
        # Pendurada de cabeca para baixo num galho.
        d.rectangle([P(-0.5, -0.5), P(0.5, -0.44)], fill=255)
        for x in (-0.06, 0.06):
            d.line([P(x, -0.44), P(x * 0.8, -0.3)], fill=255, width=int(0.035 * s))
        d.ellipse([P(-0.11, -0.32), P(0.11, 0.14)], fill=255)
        d.ellipse([P(-0.1, 0.08), P(0.1, 0.3)], fill=255)
        for lado in (-1, 1):
            d.polygon([P(lado * 0.03, 0.26), P(lado * 0.1, 0.4), P(lado * 0.1, 0.22)], fill=255)
            # A asa: borda de cima reta ate a ponta, e a de baixo em tres
            # vieiras voltando ao corpo.
            pts = [P(lado * 0.08, -0.26), P(lado * 0.52, -0.3), P(lado * 0.58, -0.1)]
            for k in range(1, 31):
                t = k / 30
                x = 0.58 + (0.1 - 0.58) * t
                y = -0.1 + (0.12 + 0.1) * t
                y -= 0.08 * math.sin(math.pi * ((t * 3) % 1.0))
                pts.append(P(lado * x, y))
            d.polygon(pts, fill=255)
        # Os olhos, vazados.
        for lado in (-1, 1):
            d.ellipse([P(lado * 0.045 - 0.02, 0.17), P(lado * 0.045 + 0.02, 0.21)], fill=0)
    elif v == "bonsai":
        d.polygon([P(-0.34, 0.36), P(0.34, 0.36), P(0.26, 0.56), P(-0.26, 0.56)], fill=255)
        d.rectangle([P(-0.4, 0.32), P(0.4, 0.38)], fill=255)
        tronco = [P(0.02, 0.34), P(-0.12, 0.18), P(0.06, 0.02), P(-0.02, -0.12)]
        d.line(tronco, fill=255, width=int(0.1 * s), joint="curve")
        d.line([P(0.04, 0.05), P(0.26, -0.02)], fill=255, width=int(0.06 * s))
        for (x, y, r) in [(-0.26, -0.12, 0.17), (0.08, -0.3, 0.2), (0.3, -0.1, 0.15),
                          (-0.06, -0.12, 0.14), (0.34, -0.26, 0.11), (-0.3, -0.3, 0.12)]:
            d.ellipse([P(x - r, y - r * 0.8), P(x + r, y + r * 0.8)], fill=255)
    elif v == "saca_rolha":
        d.rounded_rectangle([P(-0.36, -0.52), P(0.36, -0.4)], radius=int(0.06 * s), fill=255)
        d.rectangle([P(-0.035, -0.42), P(0.035, -0.26)], fill=255)
        pts = []
        for k in range(121):
            t = k / 120
            pts.append(P(0.2 * math.sin(t * math.pi * 7.0), -0.28 + 0.8 * t))
        d.line(pts, fill=255, width=int(0.075 * s), joint="curve")
        d.polygon([P(-0.03, 0.5), P(0.03, 0.5), P(0.0, 0.58)], fill=255)
    elif v == "girafa":
        d.polygon([P(-0.14, 0.58), P(0.12, 0.58), P(0.16, -0.22), P(0.0, -0.26)], fill=255)
        d.ellipse([P(-0.06, -0.44), P(0.36, -0.24)], fill=255)
        for x in (0.04, 0.13):
            d.line([P(x, -0.4), P(x - 0.02, -0.54)], fill=255, width=int(0.035 * s))
            d.ellipse([P(x - 0.05, -0.59), P(x + 0.01, -0.53)], fill=255)
        d.polygon([P(-0.02, -0.36), P(-0.16, -0.44), P(-0.04, -0.3)], fill=255)
        # As manchas, vazadas no pescoco.
        for (x, y, r) in [(0.0, 0.4, 0.05), (0.06, 0.2, 0.045), (-0.02, 0.02, 0.04),
                          (0.08, -0.12, 0.035), (-0.06, 0.28, 0.035)]:
            d.ellipse([P(x - r, y - r * 1.2), P(x + r, y + r * 1.2)], fill=0)
        d.ellipse([P(0.18, -0.38), P(0.22, -0.34)], fill=0)
    elif v == "pompom":
        d.rectangle([P(-0.025, 0.12), P(0.025, 0.6)], fill=255)
        for k in range(28):
            a = 2 * math.pi * k / 28
            x, y = 0.28 * math.cos(a), -0.14 + 0.28 * math.sin(a)
            d.ellipse([P(x - 0.075, y - 0.075), P(x + 0.075, y + 0.075)], fill=255)
        d.ellipse([P(-0.3, -0.44), P(0.3, 0.16)], fill=255)
        for lado in (-1, 1):
            d.polygon([P(0.0, 0.2), P(lado * 0.18, 0.12), P(lado * 0.16, 0.3)], fill=255)
    elif v == "chorona":
        d.polygon([P(-0.05, 0.58), P(0.07, 0.58), P(0.04, -0.2), P(-0.02, -0.2)], fill=255)
        d.chord([P(-0.42, -0.5), P(0.42, -0.02)], 180, 360, fill=255)
        for k in range(11):
            x0 = -0.38 + 0.076 * k
            pts = [P(x0, -0.28)]
            for j in range(1, 13):
                t = j / 12
                pts.append(P(x0 * (1.0 + 0.3 * t), -0.28 + 0.66 * t))
            d.line(pts, fill=255, width=int(0.03 * s))
        # A lagrima.
        gota = [P(0.44, 0.02)]
        for k in range(17):
            a = math.pi * (0.1 + 0.8 * k / 16)
            gota.append(P(0.44 + 0.06 * math.cos(a + math.pi * 0.5) * -1.0,
                          0.16 + 0.06 * math.sin(a + math.pi * 0.5)))
        d.polygon(gota, fill=255)
    elif v == "gambazona":
        # O gamba de lado, olhando para a esquerda, com a cauda de pluma em pe.
        d.ellipse([P(-0.36, 0.02), P(0.2, 0.44)], fill=255)
        d.ellipse([P(-0.56, 0.06), P(-0.26, 0.34)], fill=255)
        d.polygon([P(-0.52, 0.22), P(-0.68, 0.28), P(-0.52, 0.3)], fill=255)
        d.polygon([P(-0.46, 0.1), P(-0.42, -0.02), P(-0.36, 0.1)], fill=255)
        for x in (-0.26, -0.12, 0.02, 0.12):
            d.rectangle([P(x - 0.035, 0.38), P(x + 0.035, 0.52)], fill=255)
        # A cauda: uma pluma so, gorda, subindo de tras e caindo para a frente.
        for (x, y, r) in [(0.18, 0.12, 0.17), (0.3, -0.06, 0.2), (0.3, -0.28, 0.21),
                          (0.16, -0.42, 0.19), (0.0, -0.44, 0.14), (0.24, -0.16, 0.2)]:
            d.ellipse([P(x - r, y - r), P(x + r, y + r)], fill=255)
        # A listra, larga e continua, da testa ao fim da cauda.
        d.line([P(-0.42, 0.1), P(-0.2, 0.05), P(0.06, 0.06), P(0.22, 0.0), P(0.3, -0.18),
                P(0.24, -0.36), P(0.08, -0.44)], fill=0, width=int(0.075 * s), joint="curve")
        d.ellipse([P(-0.47, 0.14), P(-0.43, 0.18)], fill=0)
        # O cheiro, em tres ondas.
        for k in range(3):
            x0 = 0.44 + 0.07 * k
            pts = [P(x0 + 0.03 * math.sin(j * 1.3), -0.5 + 0.06 * j) for j in range(9)]
            d.line(pts, fill=255, width=int(0.025 * s))
    elif v == "vagalume":
        # O vagalume de lado: cabeca, torax, as duas asas vazadas e o abdome
        # aceso, com os raios da luz.
        d.ellipse([P(-0.5, -0.02), P(-0.34, 0.14)], fill=255)
        d.ellipse([P(-0.38, -0.06), P(-0.08, 0.16)], fill=255)
        for lado, dx in ((-1, 0.0), (1, 0.1)):
            d.line([P(-0.46, 0.0), P(-0.58, -0.14 - 0.05 * lado), P(-0.52, -0.26 - 0.05 * lado)],
                   fill=255, width=int(0.022 * s), joint="curve")
        for (x0, y0, x1, y1) in [(-0.3, -0.42, 0.06, -0.06), (-0.16, -0.36, 0.26, -0.04)]:
            d.ellipse([P(x0, y0), P(x1, y1)], fill=255)
            d.ellipse([P(x0 + 0.035, y0 + 0.035), P(x1 - 0.035, y1 - 0.035)], fill=0)
        d.ellipse([P(-0.12, -0.04), P(0.16, 0.16)], fill=255)
        d.ellipse([P(0.1, -0.08), P(0.42, 0.24)], fill=255)
        for k in range(12):
            a = 2 * math.pi * k / 12
            d.line([P(0.26 + 0.22 * math.cos(a), 0.08 + 0.22 * math.sin(a)),
                    P(0.26 + 0.33 * math.cos(a), 0.08 + 0.33 * math.sin(a))],
                   fill=255, width=int(0.028 * s))
        for x in (-0.3, -0.18, -0.06):
            d.line([P(x, 0.14), P(x - 0.04, 0.28)], fill=255, width=int(0.02 * s))


def frente(k):
    """As duas mascaras (cor da variedade, tinta escura) da frente `k`."""
    v, nome, frase, cor = VARIEDADES[k]
    cor_m = Image.new("L", (CW, CH), 0)
    esc_m = Image.new("L", (CW, CH), 0)
    dc = ImageDraw.Draw(cor_m)
    de = ImageDraw.Draw(esc_m)
    # Faixas.
    dc.rectangle([0, CH * 0.035, CW, CH * 0.075], fill=255)
    dc.rectangle([0, CH * 0.905, CW, CH * 0.945], fill=255)
    de.rectangle([0, CH * 0.083, CW, CH * 0.088], fill=255)
    de.rectangle([0, CH * 0.892, CW, CH * 0.897], fill=255)
    texto_caber(de, CW * 0.5, CH * 0.125, "CASA DA FUMACA", CW * 0.5, CH * 0.03)
    emblema(dc, v, CW * 0.5, CH * 0.35, CH * 0.36)
    texto_caber(de, CW * 0.5, CH * 0.6, nome, CW * 0.82, CH * 0.095)
    texto_caber(de, CW * 0.5, CH * 0.672, frase, CW * 0.72, CH * 0.03, "SemiBold Condensed")
    # A caixa do andar, vazada.
    x0, x1, y0, y1 = CW * 0.3, CW * 0.7, CH * 0.72, CH * 0.8
    de.rounded_rectangle([x0, y0, x1, y1], radius=int(CH * 0.015), fill=255)
    texto_caber(de, CW * 0.5, (y0 + y1) * 0.5, "ANDAR %d" % (k + 1), (x1 - x0) * 0.8,
                (y1 - y0) * 0.62, fill=0)
    texto_caber(de, CW * 0.5, CH * 0.845, "PESO LIQUIDO: MUITO", CW * 0.5, CH * 0.026,
                "SemiBold Condensed")
    escura = np.array(TINTA_ESCURA, np.float32)
    tinta = np.array(cor, np.float32) * 0.86
    return [(np.asarray(cor_m, np.float32) / 255.0, tinta),
            (np.asarray(esc_m, np.float32) / 255.0, escura)]


def verso():
    m = Image.new("L", (CW, CH), 0)
    d = ImageDraw.Draw(m)
    for y0 in (0.04, 0.9):
        d.rectangle([0, CH * y0, CW, CH * (y0 + 0.02)], fill=255)
    texto_caber(d, CW * 0.5, CH * 0.3, "COLHEITA", CW * 0.6, CH * 0.08)
    texto_caber(d, CW * 0.5, CH * 0.39, "DA CASA", CW * 0.4, CH * 0.05)
    d.polygon([(CW * 0.5, CH * 0.5), (CW * 0.42, CH * 0.6), (CW * 0.47, CH * 0.6),
               (CW * 0.47, CH * 0.7), (CW * 0.53, CH * 0.7), (CW * 0.53, CH * 0.6),
               (CW * 0.58, CH * 0.6)], fill=255)
    texto_caber(d, CW * 0.5, CH * 0.76, "ESTE LADO PRA CIMA", CW * 0.6, CH * 0.035)
    texto_caber(d, CW * 0.5, CH * 0.82, "LOTE 420", CW * 0.3, CH * 0.03)
    return [(np.asarray(m, np.float32) / 255.0, np.array(TINTA_ESCURA, np.float32))]


def main():
    previa = None
    for a in sys.argv[1:]:
        if a.startswith("--previa="):
            previa = Path(a.split("=", 1)[1])
            previa.mkdir(parents=True, exist_ok=True)
    cor = np.zeros((N, N, 3), np.float32)
    alt = np.zeros((N, N), np.float32)
    rug = np.ones((N, N), np.float32)
    ao = np.ones((N, N), np.float32)
    for k in range(12):
        if k < len(VARIEDADES):
            tintas = frente(k)
        elif k == 9:
            tintas = verso()
        else:
            tintas = [(np.zeros((CH, CW), np.float32), np.zeros(3, np.float32))]
        c, h, r, o = sacola.gerar(CW, CH, 6.0, tintas, costura_lateral=False, semente=k * 7)
        x, y = celula(k)
        hh = min(CH, N - y)
        cor[y:y + hh, x:x + CW] = c[:hh]
        alt[y:y + hh, x:x + CW] = h[:hh]
        rug[y:y + hh, x:x + CW] = r[:hh]
        ao[y:y + hh, x:x + CW] = o[:hh]
    # A ultima linha de celulas tem 2 px a mais que CH * 3: repete a ultima.
    if 3 * CH < N:
        cor[3 * CH:] = cor[3 * CH - 1]
        alt[3 * CH:] = alt[3 * CH - 1]
        rug[3 * CH:] = rug[3 * CH - 1]
        ao[3 * CH:] = ao[3 * CH - 1]
    Image.fromarray(sacola.u8(cor), "RGB").save(HD / "estufa_sacos.png")
    Image.fromarray(sacola.u8(sacola.normal_de(alt, 2.5) * 0.5 + 0.5), "RGB").save(
        HD / "estufa_sacos_n.png")
    Image.fromarray(sacola.u8(np.dstack([rug, ao, np.zeros_like(rug)])), "RGB").save(
        HD / "estufa_sacos_ru.png")
    Image.fromarray(sacola.u8(cor), "RGB").resize((512, 512), Image.BOX).save(
        PS1 / "estufa_sacos.png")
    if previa:
        Image.fromarray(sacola.u8(cor)).resize((1024, 1024), Image.LANCZOS).save(
            previa / "sacos.png")
    print("ok")


if __name__ == "__main__":
    main()

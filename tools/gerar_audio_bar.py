#!/usr/bin/env python3
"""Sons do bar vivo: o brinde, a garrafa e o pires pousando no balcao.

Mesmo formato dos outros geradores (ART-BIBLE secao 11): 22.050 Hz, mono, 16
bits, sintese sem amostra de terceiro. So escreve os proprios arquivos.

- `copo_brinde`: dois copos americanos batendo. Vidro e inarmonico: tres modos
  agudos que nao sao multiplos um do outro, decaimento de um quarto de segundo,
  e o segundo copo meio tom abaixo e dez milissegundos depois.
- `garrafa_balcao`: a 600 pousando na formica: o baque grave do fundo grosso e
  um anel curto do vidro.
- `pires_balcao`: o pires de louca no balcao: estalo seco, um quique e o anel
  da borda.

    python tools/gerar_audio_bar.py
"""

import wave
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 22050

rng = np.random.default_rng(1998)


def gravar(nome, x, ganho=0.9):
    pico = float(np.max(np.abs(x))) or 1.0
    y = np.clip(x / pico * ganho, -1.0, 1.0)
    dados = (y * 32767.0).astype("<i2")
    SAIDA.mkdir(parents=True, exist_ok=True)
    with wave.open(str(SAIDA / f"{nome}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(f"{nome}.wav  {len(x) / SR:.2f} s")


def t_de(seg):
    return np.arange(int(seg * SR)) / SR


def modo(t, freq, tau, fase=0.0):
    return np.sin(2.0 * np.pi * freq * t + fase) * np.exp(-t / tau)


def ruido_curto(n, tau_s):
    t = np.arange(n) / SR
    return rng.standard_normal(n) * np.exp(-t / tau_s)


def por(base, som, em_s):
    i = int(em_s * SR)
    fim = min(len(base), i + len(som))
    base[i:fim] += som[: fim - i]


def copo(t, afina, forca):
    # Copo americano: modos de sino de vidro grosso (as razoes 1 : 1,55 : 2,31
    # sao as de um cilindro de parede espessa, medidas no espectro de um copo).
    f0 = 2150.0 * afina
    x = (modo(t, f0, 0.26) * 1.0 + modo(t, f0 * 1.55, 0.17, 0.7) * 0.55
         + modo(t, f0 * 2.31, 0.09, 1.9) * 0.35 + modo(t, f0 * 3.05, 0.05, 0.4) * 0.2)
    # O estalo do contato, antes do anel.
    x[: 60] += rng.standard_normal(60) * np.exp(-np.arange(60) / 12.0) * 0.8
    return x * forca


def copo_brinde():
    t = t_de(0.7)
    x = np.zeros_like(t)
    por(x, copo(t, 1.0, 1.0), 0.0)
    por(x, copo(t, 0.94, 0.8), 0.011)
    # Um toque leve de volta, como sempre acontece.
    por(x, copo(t, 0.97, 0.18), 0.09)
    gravar("copo_brinde", x, 0.8)


def garrafa_balcao():
    t = t_de(0.45)
    baque = modo(t, 165.0, 0.035) * 1.0 + modo(t, 310.0, 0.02, 0.5) * 0.5
    anel = modo(t, 1180.0, 0.07, 0.3) * 0.22 + modo(t, 2870.0, 0.03, 1.1) * 0.1
    x = baque + anel
    x[: 90] += ruido_curto(90, 0.0015) * 0.6
    # A formica por baixo: um grave curtinho de madeira.
    x += modo(t, 95.0, 0.05, 0.2) * 0.35
    gravar("garrafa_balcao", x, 0.75)


def pires_balcao():
    t = t_de(0.5)
    x = np.zeros_like(t)
    batida = modo(t, 1750.0, 0.05) * 0.6 + modo(t, 3900.0, 0.02, 0.9) * 0.35 \
        + modo(t, 240.0, 0.025, 0.2) * 0.5
    batida[: 70] += ruido_curto(70, 0.001) * 0.9
    por(x, batida, 0.0)
    por(x, batida * 0.3, 0.055)
    x += modo(t, 2620.0, 0.16, 0.6) * 0.12
    gravar("pires_balcao", x, 0.7)


def main():
    copo_brinde()
    garrafa_balcao()
    pires_balcao()


if __name__ == "__main__":
    main()

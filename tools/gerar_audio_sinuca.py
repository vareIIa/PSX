#!/usr/bin/env python3
"""Sons da sinuca do bar: bola com bola, tabela, cacapa e a ponta do taco.

Mesmo formato dos outros geradores (ART-BIBLE secao 11): 22.050 Hz, mono, 16
bits, sintese sem amostra de terceiro. So escreve os proprios arquivos.

- `sinuca_bola`: o estalo seco de resina fenolica. Dois modos agudos (a bola e
  dura e pequena) com decaimento de milissegundos, e quase nada de grave.
- `sinuca_tabela`: a borracha abafando: um baque grave curto, a madeira da
  tabua por baixo e o pano chiando.
- `sinuca_cacapa`: a bola caindo no copo de couro: o baque, dois quiques
  dentro e o rolar ate parar.
- `sinuca_taco`: o "toc" da sola de couro na bola, mais o corpo do taco.

    python tools/gerar_audio_sinuca.py
"""

import wave
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 22050

rng = np.random.default_rng(5150)


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


def passa_baixa(x, corte):
    a = np.exp(-2.0 * np.pi * corte / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def bola():
    t = t_de(0.09)
    x = (modo(t, 3150.0, 0.006) * 1.0 + modo(t, 4870.0, 0.004, 0.7) * 0.6
         + modo(t, 2210.0, 0.009, 1.3) * 0.35 + modo(t, 7300.0, 0.002) * 0.25)
    # O contato: um pulso de ruido de meio milissegundo abre o estalo.
    clique = rng.normal(0.0, 1.0, len(t)) * np.exp(-t / 0.0006)
    return x + clique * 0.5


def tabela():
    t = t_de(0.18)
    grave = modo(t, 165.0, 0.03) * 1.0 + modo(t, 95.0, 0.045, 0.4) * 0.6
    madeira = modo(t, 610.0, 0.012, 0.9) * 0.35
    pano = passa_baixa(rng.normal(0.0, 1.0, len(t)), 1800.0) * np.exp(-t / 0.018) * 0.8
    ataque = np.minimum(1.0, t / 0.002)
    return (grave + madeira + pano) * ataque


def cacapa():
    t = t_de(0.62)
    x = np.zeros_like(t)
    # Baque no couro e dois quiques menores.
    for inicio, forca in ((0.0, 1.0), (0.085, 0.45), (0.15, 0.22)):
        tt = np.clip(t - inicio, 0.0, None)
        env = (t >= inicio).astype(float)
        x += env * forca * (modo(tt, 128.0, 0.035) + modo(tt, 340.0, 0.015, 0.5) * 0.5
                            + modo(tt, 1900.0, 0.004) * 0.25)
    # Rolando no fundo do copo: ruido grave com o "tremido" da bola girando.
    tt = np.clip(t - 0.17, 0.0, None)
    rolar = passa_baixa(rng.normal(0.0, 1.0, len(t)), 700.0)
    rolar *= (t >= 0.17) * np.exp(-tt / 0.14) * (0.6 + 0.4 * np.sin(2 * np.pi * 26.0 * tt))
    return x + rolar * 1.4


def taco():
    t = t_de(0.12)
    toc = modo(t, 1780.0, 0.007) * 1.0 + modo(t, 2650.0, 0.005, 0.3) * 0.5
    corpo = modo(t, 880.0, 0.02, 1.1) * 0.35 + modo(t, 220.0, 0.03) * 0.3
    couro = passa_baixa(rng.normal(0.0, 1.0, len(t)), 3000.0) * np.exp(-t / 0.0015) * 0.7
    return toc + corpo + couro


def main():
    gravar("sinuca_bola", bola(), 0.85)
    gravar("sinuca_tabela", tabela(), 0.8)
    gravar("sinuca_cacapa", cacapa(), 0.85)
    gravar("sinuca_taco", taco(), 0.8)


if __name__ == "__main__":
    main()

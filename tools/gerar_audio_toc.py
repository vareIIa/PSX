#!/usr/bin/env python3
"""O toc-toc-toc do padre no vidro da janela do motorista.

Tres variantes (`toc_vidro_1` a `toc_vidro_3`) de um no de dedo batendo no
vidro lateral de um carro: a cena toca as tres em sequencia, com espacamento
de mao humana (`AberturaEstrada._toc_toc_toc`).

O que faz um toc de vidro de porta, e nao de mesa nem de janela de casa:

- o ataque e curto e seco: o no do dedo e osso com pouca pele, um pulso de
  2 ms e um estalinho agudo por cima;
- o corpo e grave: a lamina temperada presa no canal da porta vibra inteira
  nos primeiros modos (150 a 450 Hz), e a porta oca por baixo da um "tum"
  surdo perto dos 100 Hz;
- os modos altos do vidro (1 a 3 kHz) existem, mas morrem em milissegundos:
  a borracha do canal abafa. Se durarem, vira copo.

A 44.100 Hz, como os outros sons de vidro da cena (`gerar_audio_cabecada.py`):
o estalo do ataque vive acima de 11 kHz.

    python tools/gerar_audio_toc.py
"""

import wave
from pathlib import Path

import numpy as np
from scipy import signal

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 44100


def gravar(nome: str, x: np.ndarray, ganho: float = 0.9) -> None:
    pico = float(np.max(np.abs(x))) or 1.0
    y = np.clip(x / pico * ganho, -1.0, 1.0)
    dados = (y * 32767.0).astype("<i2")
    SAIDA.mkdir(parents=True, exist_ok=True)
    with wave.open(str(SAIDA / f"{nome}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(f"{nome:14s} {len(y) / SR:5.2f} s")


def toc(semente: int, afina: float, forca: float) -> np.ndarray:
    rng = np.random.default_rng(semente)
    dur = 0.32
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # O pulso do no do dedo: meio seno de ~2 ms, a forca que excita os modos.
    larg = 0.0021 * rng.uniform(0.9, 1.1)
    pulso = np.where(t < larg, np.sin(np.pi * t / larg), 0.0)
    # Os modos da lamina no canal da porta: frequencia (Hz), amplitude e quanto
    # dura (s, constante de queda). Os graves sao o corpo; os agudos morrem logo.
    modos = [
        (152.0, 1.00, 0.050),
        (231.0, 0.85, 0.040),
        (338.0, 0.62, 0.036),
        (457.0, 0.40, 0.028),
        (742.0, 0.42, 0.016),
        (1180.0, 0.34, 0.010),
        (1930.0, 0.24, 0.006),
        (3050.0, 0.14, 0.004),
    ]
    for f, a, tau in modos:
        f *= afina * rng.uniform(0.985, 1.015)
        fase = rng.uniform(0.0, 2.0 * np.pi)
        x += a * np.sin(2.0 * np.pi * f * t + fase) * np.exp(-t / (tau * rng.uniform(0.9, 1.1)))
    # O modo so comeca quando o dedo encosta: sobe no tempo do pulso.
    x *= np.clip(t / larg, 0.0, 1.0) ** 0.5
    # O "tum" da porta oca por baixo: grave, surdo, curtissimo.
    tum_f = 96.0 * afina * rng.uniform(0.95, 1.05)
    x += 0.5 * np.sin(2.0 * np.pi * tum_f * t) * np.exp(-t / 0.032) * np.clip(t / 0.003, 0.0, 1.0)
    # O estalo do osso no vidro: ruido agudo de 3 ms.
    estalo = rng.standard_normal(n) * np.exp(-t / 0.0028)
    b, a = signal.butter(2, 2600.0 / (SR * 0.5), "highpass")
    x += 1.8 * signal.lfilter(b, a, estalo)
    # O pulso em si, filtrado: o baque seco do contato.
    b, a = signal.butter(2, 1800.0 / (SR * 0.5), "lowpass")
    x += 1.4 * signal.lfilter(b, a, pulso)
    # A borracha do canal abafa o que sobra acima de 6 kHz.
    b, a = signal.butter(2, 6500.0 / (SR * 0.5), "lowpass")
    x = signal.lfilter(b, a, x)
    # Sem estalo no fim do arquivo.
    x *= np.clip((dur - t) / 0.03, 0.0, 1.0)
    return x * forca


def main() -> None:
    # Tres toques de uma mao so: o segundo um nada mais forte, o terceiro um nada
    # mais grave (o dedo encosta mais, a lamina e a mesma).
    gravar("toc_vidro_1", toc(71, 1.00, 1.0), 0.88)
    gravar("toc_vidro_2", toc(72, 1.02, 1.0), 0.92)
    gravar("toc_vidro_3", toc(73, 0.97, 1.0), 0.9)


if __name__ == "__main__":
    main()

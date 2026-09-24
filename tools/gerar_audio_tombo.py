#!/usr/bin/env python3
"""Sons do tombo: corpo batendo no chao e carro batendo em gente.

Separado de `gerar_audio.py` de proposito: aquele gera o banco inteiro e muda
com frequencia por outras frentes; este so escreve os arquivos dele, e rodar um
nao reescreve o do outro. Mesmo formato (ART-BIBLE secao 11): 22.050 Hz, mono,
16 bits, sintese sem amostra de terceiro.

O que faz um baque de corpo ler como corpo, e nao como caixa caindo
------------------------------------------------------------------
- o grave e CURTO e sem tom: 70-110 Hz com queda em 80 ms. Caixa de papelao
  ressoa; carne abafa.
- a roupa: um chiado largo de 60 ms logo depois do grave, o pano raspando;
- o asfalto: dois ou tres estalos de cascalho, aleatorios, bem baixos.

    python tools/gerar_audio_tombo.py
"""

import wave
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 22050

rng = np.random.default_rng(2026)


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
    print(f"{nome:22s} {len(y) / SR:5.2f} s")


def passa_banda(x: np.ndarray, baixo: float, alto: float) -> np.ndarray:
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    f[(freqs < baixo) | (freqs > alto)] = 0.0
    return np.fft.irfft(f, len(x))


def queda(n: int, tempo: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.exp(-t / tempo)


def grave(dur: float, f0: float, tempo: float) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    # O tom desce um pouco: o corpo "afunda" no impacto.
    fase = 2 * np.pi * np.cumsum(f0 * (1.0 - 0.35 * t / dur)) / SR
    corpo = np.sin(fase) + 0.4 * passa_banda(rng.standard_normal(n), 40, 220)
    return corpo * queda(n, tempo)


def baque(variacao: int) -> np.ndarray:
    dur = 0.42
    n = int(SR * dur)
    x = grave(dur, 78 + 14 * variacao, 0.07 + 0.01 * variacao) * 1.0
    # Roupa raspando: chiado largo, 60 ms, logo depois do grave.
    pano = passa_banda(rng.standard_normal(n), 700, 4200) * queda(n, 0.045)
    atraso = int(SR * 0.012)
    x[atraso:] += 0.35 * pano[: n - atraso]
    # Cascalho: estalos curtos e baixos.
    for _ in range(2 + variacao):
        i = int(rng.uniform(0.02, 0.25) * SR)
        m = int(SR * 0.008)
        estalo = passa_banda(rng.standard_normal(m), 2500, 8000) * queda(m, 0.002)
        x[i : i + m] += 0.18 * estalo
    return x


def atropelo() -> np.ndarray:
    dur = 0.55
    n = int(SR * dur)
    # O grave do corpo contra o para-choque, mais cheio que o baque no chao.
    x = grave(dur, 64, 0.11) * 1.2
    # Plastico do para-choque estalando.
    m = int(SR * 0.05)
    plastico = passa_banda(rng.standard_normal(m), 1400, 5200) * queda(m, 0.012)
    x[:m] += 0.55 * plastico
    # Chapa do capo: um ressoar metalico baixo e curto.
    t = np.arange(n) / SR
    chapa = (np.sin(2 * np.pi * 410 * t) * 0.5 + np.sin(2 * np.pi * 637 * t) * 0.3) * queda(n, 0.06)
    i = int(SR * 0.03)
    x[i:] += 0.22 * chapa[: n - i]
    return x


def arrasto() -> np.ndarray:
    dur = 0.6
    n = int(SR * dur)
    t = np.arange(n) / SR
    # Roupa e pele raspando no asfalto, perdendo forca.
    x = passa_banda(rng.standard_normal(n), 300, 2600)
    env = np.minimum(1.0, t / 0.03) * np.exp(-t / 0.22)
    tremor = 0.7 + 0.3 * np.sin(2 * np.pi * 23 * t)
    return x * env * tremor


def main() -> int:
    for k in range(3):
        gravar(f"baque_corpo_{k + 1}", baque(k), 0.85)
    gravar("atropelo_pancada", atropelo(), 0.95)
    gravar("arrasto_corpo", arrasto(), 0.6)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

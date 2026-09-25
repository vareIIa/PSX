#!/usr/bin/env python3
"""Sons do cigarro da abertura: a tragada, o sopro, o peteleco e a bituca.

Separado de `gerar_audio.py` pelo mesmo motivo do susto e do tombo: este so
escreve os proprios arquivos. Mesmo formato (ART-BIBLE secao 11): 22.050 Hz,
mono, 16 bits, sintese sem amostra de terceiro.

- `cigarro_traga`: o papel e o fumo crepitando na puxada — estalinhos finos
  que engrossam com a forca da puxada — e o ar entrando baixinho por baixo.
- `cigarro_sopra`: o ar saindo pelos labios entreabertos: ruido com um
  formante de boca, ataque rapido e cauda comprida.
- `cigarro_peteleco`: o estalo seco do dedo na bituca.
- `bituca_chao`: a bituca batendo no asfalto e as faiscas se espalhando.

    python tools/gerar_audio_cigarro.py
"""

import wave
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 22050

rng = np.random.default_rng(8412)


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
    print(f"{nome}.wav  {len(x) / SR:.2f} s")


def passa_baixa(x: np.ndarray, corte: float) -> np.ndarray:
    a = np.exp(-2.0 * np.pi * corte / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def passa_alta(x: np.ndarray, corte: float) -> np.ndarray:
    return x - passa_baixa(x, corte)


def ressoa(x: np.ndarray, freq: float, q: float) -> np.ndarray:
    """Filtro ressonante de dois polos (formante)."""
    w = 2.0 * np.pi * freq / SR
    r = np.exp(-w / (2.0 * q))
    b1, b2 = 2.0 * r * np.cos(w), -r * r
    y = np.zeros_like(x)
    for i in range(len(x)):
        y[i] = x[i] + b1 * (y[i - 1] if i > 0 else 0.0) + b2 * (y[i - 2] if i > 1 else 0.0)
    return y


def envelope(n: int, ataque: float, solta: float) -> np.ndarray:
    t = np.arange(n) / SR
    dur = n / SR
    e = np.clip(t / ataque, 0.0, 1.0) * np.clip((dur - t) / solta, 0.0, 1.0)
    return e * e * (3.0 - 2.0 * e)


def estalos(n: int, taxa: np.ndarray, brilho: float) -> np.ndarray:
    """Estalinhos de Poisson com taxa por amostra (por segundo)."""
    x = np.zeros(n, np.float32)
    p = taxa / SR
    onde = np.nonzero(rng.random(n) < p)[0]
    for i in onde:
        comp = int(SR * rng.uniform(0.0008, 0.004))
        if i + comp >= n:
            continue
        k = np.arange(comp)
        pulso = rng.normal(size=comp) * np.exp(-k / (comp * 0.25))
        x[i:i + comp] += pulso * rng.uniform(0.3, 1.0)
    return passa_alta(x, brilho)


def traga() -> np.ndarray:
    dur = 1.5
    n = int(SR * dur)
    t = np.arange(n) / SR
    forca = np.clip(t / 0.25, 0, 1) * np.clip((dur - t) / 0.35, 0, 1)
    forca = forca * forca * (3.0 - 2.0 * forca)
    crepita = estalos(n, 20.0 + 140.0 * forca, 1800.0) * (0.35 + 0.65 * forca)
    # Fritura continua embaixo dos estalos: papel queimando.
    frita = passa_alta(rng.normal(size=n).astype(np.float32), 3000.0) * 0.05 * forca
    ar = passa_baixa(rng.normal(size=n).astype(np.float32), 900.0) * 0.5 * forca
    return crepita + frita + ar


def sopra() -> np.ndarray:
    dur = 2.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    ruido = rng.normal(size=n).astype(np.float32)
    boca = ressoa(passa_baixa(ruido, 2600.0), 820.0, 2.2) * 0.25 \
        + passa_baixa(ruido, 1400.0) * 0.6
    e = np.clip(t / 0.08, 0, 1) * np.exp(-np.maximum(t - 0.25, 0.0) / 0.55)
    return boca * e


def peteleco() -> np.ndarray:
    n = int(SR * 0.12)
    k = np.arange(n)
    clique = rng.normal(size=n) * np.exp(-k / (SR * 0.004))
    corpo = np.sin(2 * np.pi * 1650.0 * k / SR) * np.exp(-k / (SR * 0.012)) * 0.6
    return passa_alta((clique + corpo).astype(np.float32), 600.0)


def bituca() -> np.ndarray:
    n = int(SR * 0.5)
    k = np.arange(n)
    toque = rng.normal(size=n) * np.exp(-k / (SR * 0.006)) * 0.9
    quique = np.zeros(n)
    d = int(SR * 0.14)
    quique[d:] = rng.normal(size=n - d) * np.exp(-(k[d:] - d) / (SR * 0.004)) * 0.35
    taxa = 260.0 * np.exp(-k / (SR * 0.12))
    faisca = estalos(n, taxa, 3500.0) * 0.5
    return passa_alta((toque + quique).astype(np.float32), 900.0) + faisca


def main() -> None:
    gravar("cigarro_traga", traga(), 0.8)
    gravar("cigarro_sopra", sopra(), 0.75)
    gravar("cigarro_peteleco", peteleco(), 0.7)
    gravar("bituca_chao", bituca(), 0.6)


if __name__ == "__main__":
    main()

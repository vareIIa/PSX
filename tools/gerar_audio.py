#!/usr/bin/env python3
"""Gera o banco de sons do jogo por sintese.

O artigo de referencia e explicito: o que faz o Silent Hill assustar e o som, nao
a imagem. Chiado de radio, sirene, passo, chuva. Quase tudo isso e ruido filtrado
com envelope, que da para sintetizar sem gravar nada e sem depender de banco de
som de terceiro.

Formato do ART-BIBLE secao 11: 22.050 Hz, mono, 16 bits.

    python tools/gerar_audio.py
"""

import struct
import wave
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 22050

rng = np.random.default_rng(1995)


def gravar(nome: str, x: np.ndarray, ganho: float = 0.9) -> None:
    pico = float(np.max(np.abs(x))) or 1.0
    y = np.clip(x / pico * ganho, -1.0, 1.0)
    dados = (y * 32767.0).astype("<i2")
    SAIDA.mkdir(parents=True, exist_ok=True)
    caminho = SAIDA / f"{nome}.wav"
    with wave.open(str(caminho), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(f"{nome:22s} {len(y) / SR:5.2f} s")


def ruido(dur: float) -> np.ndarray:
    return rng.standard_normal(int(SR * dur))


def passa_banda(x: np.ndarray, baixo: float, alto: float) -> np.ndarray:
    """Filtro por FFT. Nao e o mais eficiente, mas e exato e cabe em cinco
    linhas, o que importa mais num script que roda uma vez."""
    espectro = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    espectro[(freqs < baixo) | (freqs > alto)] = 0.0
    return np.fft.irfft(espectro, n=len(x))


def envelope(n: int, ataque: float, decaimento: float) -> np.ndarray:
    a = max(1, int(n * ataque))
    d = max(1, n - a)
    return np.concatenate([
        np.linspace(0.0, 1.0, a),
        np.exp(-np.linspace(0.0, 6.0, d)) ** decaimento,
    ])[:n]


def emenda_para_loop(x: np.ndarray, ms: float = 60.0) -> np.ndarray:
    """Cruza o fim com o comeco para o loop nao estalar."""
    n = int(SR * ms / 1000.0)
    if n * 2 >= len(x):
        return x
    rampa = np.linspace(0.0, 1.0, n)
    y = x.copy()
    y[:n] = x[:n] * rampa + x[-n:] * (1.0 - rampa)
    return y[:-n]


# --- radio ------------------------------------------------------------------

def estatica() -> None:
    """Chiado de radio. ART-BIBLE secao 11 manda passa-banda de 300 Hz a 3 kHz,
    que e exatamente a faixa de um alto-falante ruim de radio portatil."""
    x = passa_banda(ruido(4.0), 300.0, 3000.0)
    # Ondulacao lenta de amplitude: chiado plano soa como ruido de fita, nao
    # como radio fora de estacao.
    t = np.arange(len(x)) / SR
    x *= 1.0 + 0.35 * np.sin(2 * np.pi * 0.7 * t) + 0.2 * np.sin(2 * np.pi * 2.3 * t)
    gravar("estatica", emenda_para_loop(x))


def interferencia() -> None:
    """Estalos e picos. Entra por cima do chiado quando o inimigo chega perto."""
    n = int(SR * 3.0)
    x = passa_banda(rng.standard_normal(n), 800.0, 5000.0) * 0.25
    for _ in range(26):
        i = rng.integers(0, n - 900)
        comp = int(rng.integers(120, 800))
        x[i:i + comp] += passa_banda(rng.standard_normal(comp), 1200.0, 6000.0) \
            * envelope(comp, 0.02, 1.4) * rng.uniform(0.8, 2.2)
    gravar("interferencia", emenda_para_loop(x))


# --- ambiente ---------------------------------------------------------------

def chuva() -> None:
    x = passa_banda(ruido(6.0), 700.0, 8000.0)
    t = np.arange(len(x)) / SR
    x *= 1.0 + 0.18 * np.sin(2 * np.pi * 0.23 * t)
    gravar("chuva_loop", emenda_para_loop(x, 200.0), 0.7)


def vento() -> None:
    x = passa_banda(ruido(8.0), 60.0, 700.0)
    t = np.arange(len(x)) / SR
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * t + 1.2)
    gravar("vento_loop", emenda_para_loop(x, 300.0), 0.6)


def zumbido() -> None:
    """Drone grave de tensao. Duas ondas quase na mesma frequencia batendo uma
    contra a outra: e o batimento que da a sensacao de desconforto."""
    t = np.arange(int(SR * 8.0)) / SR
    x = (np.sin(2 * np.pi * 47.0 * t) + np.sin(2 * np.pi * 48.7 * t) * 0.8
         + np.sin(2 * np.pi * 94.0 * t) * 0.25)
    x += passa_banda(rng.standard_normal(len(t)), 40.0, 220.0) * 0.12
    gravar("zumbido_loop", emenda_para_loop(x, 250.0), 0.55)


def sirene() -> None:
    """A sirene do Silent Hill. Varredura lenta, com uma segunda voz desafinada
    por cima: afinada demais soa como alarme de fabrica, nao como aviso."""
    dur = 9.0
    t = np.arange(int(SR * dur)) / SR
    base = 300.0 + 210.0 * np.sin(2 * np.pi * 0.16 * t - np.pi / 2)
    fase = 2 * np.pi * np.cumsum(base) / SR
    x = np.sin(fase) + 0.55 * np.sin(fase * 1.007 + 0.6) + 0.3 * np.sin(fase * 2.0)
    env = np.clip(np.minimum(t / 1.5, (dur - t) / 2.0), 0.0, 1.0)
    gravar("sirene", x * env)


# --- passos -----------------------------------------------------------------

def passos() -> None:
    perfis = {
        "concreto": (240.0, 2600.0, 0.11, 1.5),
        "madeira": (150.0, 1500.0, 0.16, 1.0),
        "metal": (400.0, 6000.0, 0.20, 0.7),
        "terra": (120.0, 900.0, 0.13, 1.9),
    }
    for nome, (baixo, alto, dur, dec) in perfis.items():
        for k in range(4):
            n = int(SR * dur * rng.uniform(0.85, 1.15))
            x = passa_banda(rng.standard_normal(n), baixo * rng.uniform(0.9, 1.1),
                            alto * rng.uniform(0.85, 1.15))
            x *= envelope(n, 0.01, dec)
            gravar(f"passo_{nome}_{k + 1}", x, 0.75)


# --- interface e objetos ----------------------------------------------------

def diversos() -> None:
    # Clique seco de menu
    n = int(SR * 0.05)
    gravar("clique", passa_banda(rng.standard_normal(n), 1400.0, 6000.0)
           * envelope(n, 0.005, 2.5), 0.6)

    # Pegar item: dois estalos curtos, como papel e metal juntos
    n = int(SR * 0.22)
    x = passa_banda(rng.standard_normal(n), 600.0, 5000.0) * envelope(n, 0.01, 1.6)
    i = int(SR * 0.07)
    x[i:] += (passa_banda(rng.standard_normal(n - i), 1800.0, 8000.0)
              * envelope(n - i, 0.01, 2.2) * 0.7)
    gravar("pegar", x, 0.7)

    # Porta velha: rangido por modulacao lenta de ruido de banda estreita
    n = int(SR * 1.3)
    t = np.arange(n) / SR
    base = passa_banda(rng.standard_normal(n), 300.0, 1800.0)
    x = base * (0.35 + 0.65 * np.abs(np.sin(2 * np.pi * 5.5 * t + np.sin(t * 3.0))))
    x *= np.clip(np.minimum(t / 0.1, (1.3 - t) / 0.4), 0.0, 1.0)
    gravar("porta_abre", x, 0.65)

    # Lanterna: clique de interruptor
    n = int(SR * 0.09)
    x = passa_banda(rng.standard_normal(n), 900.0, 4500.0) * envelope(n, 0.004, 3.0)
    gravar("interruptor", x, 0.65)

    # Tiro: estouro grave com cauda
    n = int(SR * 0.55)
    x = (passa_banda(rng.standard_normal(n), 60.0, 900.0) * envelope(n, 0.002, 1.2) * 1.6
         + passa_banda(rng.standard_normal(n), 1000.0, 9000.0) * envelope(n, 0.001, 3.5))
    gravar("tiro", x)

    # Respiracao ofegante, para folego no fim
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    x = passa_banda(rng.standard_normal(n), 200.0, 1600.0)
    x *= np.abs(np.sin(2 * np.pi * 1.1 * t)) ** 2
    gravar("ofegante", x, 0.5)

    # Trinco: o estalo curto de maçaneta antes de a folha girar. Existe para a
    # porta ter dois tempos. Folha que sai girando sozinha nao tem peso; folha
    # que estala e so depois cede parece ter alguem empurrando.
    n = int(SR * 0.14)
    x = passa_banda(rng.standard_normal(n), 1200.0, 7000.0) * envelope(n, 0.002, 4.0)
    i = int(SR * 0.045)
    x[i:] += (passa_banda(rng.standard_normal(n - i), 400.0, 2600.0)
              * envelope(n - i, 0.003, 3.0) * 0.8)
    gravar("porta_trinco", x, 0.6)

    # Porta trancada: a maçaneta bate no fim do curso duas vezes e para. Grave e
    # sem cauda, o oposto do rangido: a porta nao vai abrir e o som diz isso.
    n = int(SR * 0.5)
    x = np.zeros(n)
    for atraso in (0.0, 0.16):
        i = int(SR * atraso)
        m = n - i
        x[i:] += (passa_banda(rng.standard_normal(m), 180.0, 1400.0)
                  * envelope(m, 0.002, 9.0))
    gravar("porta_trava", x, 0.7)

    # Porta automatica de loja: motorzinho subindo, o corre do trilho e o toque
    # no fim do curso. Tres tempos, como a porta de dobradica, so que rapido.
    n = int(SR * 0.62)
    t = np.arange(n) / SR
    motor = passa_banda(rng.standard_normal(n), 240.0, 900.0)
    motor *= np.clip(np.minimum(t / 0.06, (0.52 - t) / 0.12), 0.0, 1.0)
    # A frequencia do trilho sobe e cai junto com o movimento.
    trilho = passa_banda(rng.standard_normal(n), 1600.0, 6000.0)
    trilho *= np.clip(np.sin(np.pi * np.clip(t / 0.52, 0, 1)), 0, 1) ** 2 * 0.5
    x = motor + trilho
    i = int(SR * 0.5)
    x[i:] += (passa_banda(rng.standard_normal(n - i), 150.0, 1200.0)
              * envelope(n - i, 0.002, 7.0) * 0.9)
    gravar("porta_desliza", x, 0.6)


def main() -> int:
    estatica()
    interferencia()
    chuva()
    vento()
    zumbido()
    sirene()
    passos()
    diversos()
    n = len(list(SAIDA.glob("*.wav")))
    print(f"\n{n} sons em {SAIDA.relative_to(RAIZ)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Tres batidas de no dos dedos numa porta de madeira: game/assets/audio/porta_bate.wav

    python tools/gerar_batida_porta.py

Sintese, e nao gravacao, pelo mesmo motivo do resto de tools/gerar_audio.py: o
som e do jogo e nao tem dono. Cada batida e um baque grave (a folha inteira
vibrando, 120-150 Hz caindo) com o estalo do no do dedo na madeira (ruido
filtrado em 1,5-3 kHz, 12 ms), e o conjunto passa por tres reflexoes curtas de
um corredor de casa. Ritmo de quem bate: toc... toc-toc.
"""
import math
import random
import struct
import wave
from pathlib import Path

TAXA = 22050
DURACAO = 1.3
BATIDAS = [0.05, 0.36, 0.55]
RAIZ = Path(__file__).resolve().parent.parent


def main() -> None:
    random.seed(7)
    n = int(TAXA * DURACAO)
    s = [0.0] * n
    for k, t0 in enumerate(BATIDAS):
        forca = 1.0 if k != 1 else 0.85
        i0 = int(t0 * TAXA)
        fase = 0.0
        ruido_f = 0.0
        for i in range(int(0.16 * TAXA)):
            t = i / TAXA
            f = 150.0 - 40.0 * min(t / 0.05, 1.0)
            fase += 2.0 * math.pi * f / TAXA
            baque = math.sin(fase) * math.exp(-t / 0.035)
            # Estalo: ruido passado por um passa-banda tosco (derivada do
            # passa-baixa), so nos primeiros milissegundos.
            r = random.uniform(-1.0, 1.0)
            ruido_f += (r - ruido_f) * 0.55
            estalo = (r - ruido_f) * math.exp(-t / 0.012)
            if i0 + i < n:
                s[i0 + i] += forca * (0.75 * baque + 0.45 * estalo)
    # Corredor: tres reflexoes curtas.
    saida = s[:]
    for atraso, ganho in [(0.019, 0.28), (0.034, 0.18), (0.061, 0.10)]:
        d = int(atraso * TAXA)
        for i in range(d, n):
            saida[i] += s[i - d] * ganho
    pico = max(abs(v) for v in saida) or 1.0
    destino = RAIZ / "game/assets/audio/porta_bate.wav"
    with wave.open(str(destino), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(b"".join(struct.pack("<h", int(v / pico * 0.85 * 32767)) for v in saida))
    print(destino.relative_to(RAIZ))


if __name__ == "__main__":
    main()

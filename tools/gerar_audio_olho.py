#!/usr/bin/env python3
"""O olho do padre caindo no celular do colo (rodada 3 da janela).

Usa as pecas de `gerar_audio_cabecada.py` (mesma taxa, mesmos filtros) e so
escreve os proprios arquivos:

- `olho_no_celular`: o globo mole batendo na tela de vidro do aparelho — um
  baque surdo e curto (carne, nao bola), o estalo fino do vidro por baixo, o
  chape molhado do sangue espirrando, e depois o globo rolando uns
  centimetros no proprio sangue (um chiado grudento que para) e dois pingos.

    python tools/gerar_audio_olho.py
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar_audio_cabecada import (SR, banda, envelope, estalos, gravar, janela,  # noqa: E402
                                  molhado, passa_baixa, pos, ruido)


def olho_no_celular() -> np.ndarray:
    dur = 1.3
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # O baque: um grave curto que cai de tom (o globo achata e volta).
    m = int(SR * 0.09)
    tt = np.arange(m) / SR
    f = 260.0 * np.exp(-tt / 0.03) + 120.0
    baque = np.sin(2 * np.pi * np.cumsum(f) / SR) * envelope(m, 0.0015, 0.028)
    baque += banda(ruido(m), 150, 900) * envelope(m, 0.001, 0.015) * 0.5
    pos(x, baque, 0.0, 1.0)
    # O vidro por baixo: um tique seco, pequeno (e um telefone, nao a janela).
    k = int(SR * 0.02)
    tique = banda(ruido(k), 3500, 9000) * envelope(k, 0.0002, 0.0025)
    pos(x, tique, 0.001, 0.45)
    # O chape: o sangue espirrando da carne esmagada.
    pos(x, molhado(int(SR * 0.3), 1.0), 0.004, 1.1)
    # O globo rolando no sangue: estalinhos grudentos, rareando, que param.
    rola = estalos(int(SR * 0.5), 26, 0.42, 600, 4500, 707) * 0.5
    rola += banda(ruido(len(rola)), 300, 1800) * envelope(len(rola), 0.02, 0.12) * 0.12
    pos(x, rola, 0.07, 1.0)
    # Dois pingos no vidro.
    for t0, f0, g in [(0.62, 1400.0, 0.35), (0.95, 1150.0, 0.25)]:
        p = int(SR * 0.05)
        tp = np.arange(p) / SR
        plic = np.sin(2 * np.pi * f0 * tp * (1 + 3.0 * tp)) * envelope(p, 0.0005, 0.007)
        plic += banda(ruido(p), 1500, 6000) * envelope(p, 0.0003, 0.003) * 0.4
        pos(x, plic, t0, g)
    x = passa_baixa(x, 12000, 2)
    return x * janela(n, 0.003) * np.clip(1.0 - (t - 1.1) / 0.2, 0.0, 1.0)


SONS = {
    "olho_no_celular": olho_no_celular,
}


def main() -> int:
    nomes = sys.argv[1:] or list(SONS)
    for nome in nomes:
        gravar(nome, SONS[nome]())
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Casca HD de arvore e caule de bananeira (PLANO_FLORA_AAA, rodada 2).

A `casca` (tronco e galho de toda arvore, estipe de palmeira) nao tinha conjunto
HD: no MODERNO o tronco roliço da arvore por esqueleto mostrava a textura de
256 px do PS1 esticada, com o degrau do filtro ponto. E a bananeira, o mamoeiro
e o bambu tinham so a casca parda para o caule verde — tinta de vertice nao passa
de 1 e nao faz marrom virar verde.

Ruido de espectro (FFT), que e periodico por construcao: o ladrilho fecha sem
emenda nos dois eixos. O eixo V da imagem e o comprimento do tronco (o _tubo da
ArvoreEsqueleto poe o V ao longo da espinha, em metros).

    casca   placas alongadas separadas por fissuras fundas, liquen cinza-verde no
            alto das placas. Media de cor casada com a casca de 256 (a tinta de
            especie multiplica por cima: o ipe cinza, a jaqueira escura).
    caule   o pseudocaule da bananeira: verde com estria fina ao comprido, as
            manchas pardas e a bainha seca descolando em faixa.

Saem em game/assets/textures_hd/ (cor, _n, _ru) e o caule de 128 px do PS1 em
game/assets/textures/caule.png.

    python tools/gerar_casca_hd.py [--previa=DIR]
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
HD = RAIZ / "game" / "assets" / "textures_hd"
PS1 = RAIZ / "game" / "assets" / "textures"
L = 1024


def ruido(seed, beta, ax=1.0, ay=1.0, fmin=1.0):
    """Ruido 1/f^beta periodico. `ax`, `ay` esticam a frequencia (ay > ax: a
    feicao fica comprida em Y)."""
    rng = np.random.default_rng(seed)
    w = rng.normal(size=(L, L))
    f = np.fft.fft2(w)
    fy = np.fft.fftfreq(L)[:, None] * L
    fx = np.fft.fftfreq(L)[None, :] * L
    r = np.sqrt((fx * ax) ** 2 + (fy * ay) ** 2)
    r[0, 0] = 1.0
    amp = 1.0 / np.maximum(r, fmin) ** beta
    amp[0, 0] = 0.0
    n = np.real(np.fft.ifft2(f * amp))
    n = (n - n.mean()) / (n.std() + 1e-9)
    return n.astype(np.float32)


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normal_de(h, forca):
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    n = np.dstack([-gx * forca, gy * forca, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def u8(x):
    return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)


def casar_media(cor, alvo):
    m = cor.reshape(-1, 3).mean(axis=0)
    return np.clip(cor * (np.float32(alvo) / np.maximum(m, 1e-4)), 0.0, 1.0)


def casca():
    # Placas: ruido esticado em Y (a fissura corre ao comprido), dobrado em
    # crista: 1 - |n| e alto no meio da placa e cai na fissura.
    placa = ruido(11, 2.3, ax=1.0, ay=4.5, fmin=3.0)
    placa2 = ruido(12, 2.0, ax=1.0, ay=2.5, fmin=8.0)
    campo = placa + placa2 * 0.35
    # A fissura e onde o campo cruza o zero: linha fina e continua ao comprido.
    dist = np.abs(campo)
    fissura = 1.0 - suave(0.0, 0.22, dist)
    crista = suave(0.05, 0.9, dist)
    fino = ruido(13, 1.3, ax=1.0, ay=2.5, fmin=40.0)
    meio = ruido(18, 1.8, ax=1.0, ay=3.0, fmin=12.0)
    h = 0.65 * suave(0.0, 0.3, dist) + 0.18 * crista + 0.06 * meio + 0.025 * fino
    # A segunda familia de fissura, mais fina e rasa, que parte a placa grande.
    campo2 = ruido(19, 2.1, ax=1.0, ay=5.0, fmin=9.0)
    fissura2 = 1.0 - suave(0.0, 0.14, np.abs(campo2))
    h -= 0.35 * fissura2 * (1.0 - fissura)
    fissura = np.maximum(fissura, fissura2 * 0.7)
    # Rachadura atravessada, curta, nas placas.
    trav = ruido(14, 1.6, ax=5.0, ay=1.0, fmin=16.0)
    h -= 0.12 * suave(1.8, 2.5, trav) * (1.0 - fissura)
    liquen = suave(0.9, 1.6, ruido(15, 1.6, fmin=4.0)) * suave(0.4, 0.8, crista)
    musgo = suave(1.2, 2.0, ruido(16, 1.5, ax=1.0, ay=2.0, fmin=3.0)) * fissura
    tom = ruido(17, 1.8, fmin=2.0)
    claro = np.float32([0.47, 0.42, 0.36])
    escuro = np.float32([0.16, 0.13, 0.11])
    cor = escuro + (claro - escuro) * suave(0.05, 0.8, h)[..., None]
    cor *= (1.0 + 0.1 * tom)[..., None]
    cor *= (1.0 + 0.05 * fino + 0.06 * meio)[..., None]
    cor = cor + (np.float32([0.56, 0.57, 0.5]) - cor) * (liquen * 0.55)[..., None]
    cor = cor + (np.float32([0.2, 0.26, 0.12]) - cor) * (musgo * 0.5)[..., None]
    cor = casar_media(cor, (75.4 / 255.0, 68.8 / 255.0, 58.0 / 255.0))
    n = normal_de(h, 9.0)
    rug = 0.84 + 0.12 * fissura - 0.08 * liquen
    ao = 0.4 + 0.6 * suave(0.0, 0.6, h)
    ru = np.dstack([rug, ao, np.zeros_like(h)])
    return cor, n, ru


def caule():
    estria = ruido(21, 1.1, ax=1.0, ay=24.0, fmin=30.0)
    faixa = ruido(22, 1.6, ax=1.0, ay=10.0, fmin=3.0)
    mancha = ruido(23, 1.7, ax=1.0, ay=1.6, fmin=6.0)
    pinta = ruido(24, 1.2, ax=1.0, ay=1.3, fmin=30.0)
    verde = np.float32([0.44, 0.54, 0.26])
    verde2 = np.float32([0.58, 0.64, 0.34])
    cor = verde + (verde2 - verde) * suave(-1.0, 1.0, estria)[..., None]
    # Bainha seca descolando: faixa parda ao comprido.
    seca = suave(0.8, 1.3, faixa)
    cor = cor + (np.float32([0.46, 0.36, 0.24]) - cor) * (seca * 0.85)[..., None]
    # Mancha parda e pinta preta do caule velho.
    cor = cor + (np.float32([0.34, 0.28, 0.18]) - cor) * (suave(1.0, 1.8, mancha) * 0.7)[..., None]
    cor = cor + (np.float32([0.1, 0.09, 0.06]) - cor) * (suave(2.0, 2.6, pinta) * 0.8)[..., None]
    h = estria * 0.04 + seca * 0.25 + suave(1.0, 1.8, mancha) * 0.05
    n = normal_de(h, 6.0)
    rug = 0.55 + 0.35 * seca
    ao = 0.8 + 0.2 * suave(-1.0, 1.0, estria) - 0.2 * seca * (faixa > 1.25)
    ru = np.dstack([rug, np.clip(ao, 0.0, 1.0), np.full_like(h, 0.3)])
    return cor, n, ru


def main() -> int:
    previa = None
    for arg in sys.argv[1:]:
        if arg.startswith("--previa="):
            previa = Path(arg.split("=", 1)[1])
    for nome, fazer in (("casca", casca), ("caule", caule)):
        cor, n, ru = fazer()
        Image.fromarray(u8(cor), "RGB").save(HD / f"{nome}.png", optimize=True)
        Image.fromarray(u8(n * 0.5 + 0.5), "RGB").save(HD / f"{nome}_n.png", optimize=True)
        Image.fromarray(u8(ru), "RGB").save(HD / f"{nome}_ru.png", optimize=True)
        print(nome, "media", (cor.reshape(-1, 3).mean(axis=0) * 255).round(1))
        if nome == "caule":
            p = Image.fromarray(u8(cor), "RGB").resize((128, 128), Image.LANCZOS)
            p.quantize(colors=64, method=Image.Quantize.MEDIANCUT).save(PS1 / "caule.png", optimize=True)
        if previa is not None:
            previa.mkdir(parents=True, exist_ok=True)
            luz = np.float32([-0.5, 0.4, 0.75])
            luz /= np.linalg.norm(luz)
            d = np.clip((n * luz).sum(axis=2), 0, 1) * ru[..., 1]
            Image.fromarray(u8(np.clip(cor * (0.35 + 0.9 * d[..., None]), 0, 1)), "RGB").save(previa / f"{nome}_luz.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Quartzito (pedra Sao Tome) HD: a pedra do muro de beira da estrada da abertura.

Sao Thome das Letras e a terra do quartzito em laje: muro de pedra seca, calcada,
casa inteira de pedra. O muro baixo da estrada era uma fileira de caixas de
tabua escura, e a noite lia como blocos pretos boiando na beira. Aqui a textura
da laje, para o muro de pedra empilhada (KitEstrada.muro_baixo):

    creme, rosado, cinza e ocre em manchas largas; a laminacao em listras finas
    ao comprido (o eixo X da imagem, que o muro poe ao longo da laje); pontinhos
    de mica que brilham (rugosidade mais baixa); liquen cinza-esverdeado, negro e
    alaranjado em crosta; musgo escuro embaixo.

Ruido de espectro (FFT), periodico por construcao: ladrilha sem emenda.
Saem game/assets/textures_hd/quartzito{,_n,_ru}.png e o de 256 px do PS1 em
game/assets/textures/quartzito.png.

    python tools/gerar_quartzito_hd.py [--previa=DIR]
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
    """Ruido 1/f^beta periodico. `ax` grande: a feicao fica comprida em X."""
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


def mistura(cor, alvo, peso):
    return cor + (np.float32(alvo) - cor) * peso[..., None]


def quartzito():
    creme = np.float32([0.74, 0.69, 0.6])
    rosa = np.float32([0.72, 0.6, 0.55])
    cinza = np.float32([0.6, 0.6, 0.58])
    ocre = np.float32([0.72, 0.6, 0.42])
    m1 = ruido(31, 2.2, ax=3.0, ay=1.0, fmin=2.0)
    m2 = ruido(32, 2.0, ax=2.5, ay=1.0, fmin=3.0)
    m3 = ruido(33, 1.9, fmin=3.0)
    cor = np.broadcast_to(creme, (L, L, 3)).copy()
    cor = mistura(cor, rosa, suave(-0.2, 1.4, m1) * 0.55)
    cor = mistura(cor, cinza, suave(0.4, 1.6, m2) * 0.45)
    cor = mistura(cor, ocre, suave(0.9, 2.0, m3) * 0.4)
    # Laminacao: listras finas ao comprido, umas mais escuras (a junta da laje).
    lam = ruido(34, 1.4, ax=14.0, ay=1.0, fmin=20.0)
    lam2 = ruido(35, 1.8, ax=10.0, ay=1.0, fmin=6.0)
    junta = 1.0 - suave(0.0, 0.12, np.abs(lam2))
    cor *= (1.0 + 0.06 * lam)[..., None]
    cor *= (1.0 - 0.28 * junta)[..., None]
    # Grao e mica.
    grao = ruido(36, 0.6, fmin=100.0)
    cor *= (1.0 + 0.05 * grao)[..., None]
    mica = suave(2.6, 3.2, ruido(37, 0.2, fmin=200.0))
    cor = mistura(cor, [0.92, 0.9, 0.86], mica * 0.6)
    # Liquen em crosta: cinza-esverdeado, negro, alaranjado.
    l1 = suave(0.9, 1.5, ruido(38, 2.0, fmin=6.0)) * suave(0.0, 0.8, ruido(39, 1.2, fmin=30.0) + 0.6)
    l2 = suave(1.4, 2.0, ruido(40, 2.1, fmin=8.0))
    l3 = suave(1.8, 2.3, ruido(41, 2.2, fmin=10.0))
    cor = mistura(cor, [0.58, 0.6, 0.53], l1 * 0.5)
    cor = mistura(cor, [0.22, 0.22, 0.2], l2 * 0.45)
    cor = mistura(cor, [0.74, 0.54, 0.26], l3 * 0.45)
    # Musgo escuro, mais embaixo da laje (o V alto da imagem).
    musgo = suave(1.3, 2.1, ruido(42, 1.7, ax=1.5, fmin=4.0))
    cor = mistura(cor, [0.2, 0.25, 0.12], musgo * 0.7)
    # Relevo: degraus de laminacao, a junta funda, a crosta de liquen alta.
    h = 0.35 * suave(-1.5, 1.5, lam2) + 0.08 * lam + 0.04 * grao - 0.4 * junta
    h += 0.1 * ruido(43, 2.0, fmin=4.0) + 0.05 * (l1 + l2) + 0.08 * musgo
    n = normal_de(h, 7.0)
    rug = 0.82 - 0.35 * mica + 0.08 * junta - 0.05 * l1
    ao = np.clip(0.55 + 0.45 * suave(-0.8, 0.8, h - h.mean()), 0.0, 1.0)
    ru = np.dstack([np.clip(rug, 0.0, 1.0), ao, np.zeros_like(h)])
    return np.clip(cor, 0.0, 1.0), n, ru


def main() -> int:
    previa = None
    for arg in sys.argv[1:]:
        if arg.startswith("--previa="):
            previa = Path(arg.split("=", 1)[1])
    cor, n, ru = quartzito()
    Image.fromarray(u8(cor), "RGB").save(HD / "quartzito.png", optimize=True)
    Image.fromarray(u8(n * 0.5 + 0.5), "RGB").save(HD / "quartzito_n.png", optimize=True)
    Image.fromarray(u8(ru), "RGB").save(HD / "quartzito_ru.png", optimize=True)
    p = Image.fromarray(u8(cor), "RGB").resize((256, 256), Image.LANCZOS)
    p.quantize(colors=64, method=Image.Quantize.MEDIANCUT).save(PS1 / "quartzito.png", optimize=True)
    print("quartzito media", (cor.reshape(-1, 3).mean(axis=0) * 255).round(1))
    if previa is not None:
        previa.mkdir(parents=True, exist_ok=True)
        luz = np.float32([-0.5, 0.4, 0.75])
        luz /= np.linalg.norm(luz)
        d = np.clip((n * luz).sum(axis=2), 0, 1) * ru[..., 1]
        Image.fromarray(u8(np.clip(cor * (0.35 + 0.9 * d[..., None]), 0, 1)), "RGB").save(
            previa / "quartzito_luz.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())

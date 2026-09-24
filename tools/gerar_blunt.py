"""Textura da blunt da casa da fumaca: folha de tabaco, cinza, piteira e brasa.

O baseado antigo era um bastao de 13 x 1,3 x 1,3 cm com a celula de papel do
casa_atlas: a um palmo da camera, um palito bege. A `Blunt` (src/render/blunt.gd)
e um cilindro enrolado de verdade, e esta e a pele dele, num atlas so:

    v 0,000 - 0,625   FOLHA    a folha de tabaco que enrola tudo. U ao comprido
                               (0 na piteira, 1 na ponta de uma blunt inteira de
                               12 cm), V em volta (fecha sem emenda em V).
                               Nervuras em diagonal, a costura em espiral com a
                               borda da folha de cima levantada, manchas de cura.
    v 0,625 - 0,8125  CINZA    a cinza que cresce na ponta: aneis claros em
                               camadas, rachadura escura, pontinho de carvao.
                               U ao comprido (0 junto da brasa), V em volta.
    v 0,8125 - 1      PITEIRA  (u 0 - 0,1875) o disco da boca: papelao enrolado
                               em espiral dentro do anel de folha.
                      BRASA    (u 0,25 - 1) o anel que queima: carvao preto com
                               rachadura incandescente. U em volta (fecha sem
                               emenda em U), V atravessando o anel. O material da
                               brasa multiplica a emissao por esta cor, entao o
                               que e preto aqui nao acende nem na tragada.

Ruido de espectro (FFT): periodico por construcao, como em gerar_casca_hd.py.

Saem em game/assets/textures_hd/ (blunt, blunt_n, blunt_ru) e o atlas de 128 px
do PS1 em game/assets/textures/blunt.png.

    python tools/gerar_blunt.py [--previa=DIR]
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
# Linhas de cada regiao, em pixel da folha de 1024. Mesmas fracoes de Blunt.gd.
V_FOLHA = 640
V_CINZA = 192
V_BAIXO = L - V_FOLHA - V_CINZA  # 192
U_PITEIRA = 192
U_BRASA0 = 256


def ruido(seed, forma, beta, ax=1.0, ay=1.0, fmin=1.0, angulo=0.0):
    """Ruido 1/f^beta periodico em `forma` (linhas, colunas). `ax`/`ay` esticam a
    frequencia (ay > ax: a feicao fica comprida em Y); `angulo` gira o eixo."""
    h, w = forma
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.normal(size=forma))
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    c, s = np.cos(angulo), np.sin(angulo)
    rx = fx * c + fy * s
    ry = -fx * s + fy * c
    r = np.sqrt((rx * ax) ** 2 + (ry * ay) ** 2)
    r[0, 0] = 1.0
    amp = 1.0 / np.maximum(r, fmin) ** beta
    amp[0, 0] = 0.0
    n = np.real(np.fft.ifft2(f * amp))
    n = (n - n.mean()) / (n.std() + 1e-9)
    return n.astype(np.float32)


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mistura(a, b, t):
    return a + (np.float32(b) - a) * t[..., None]


def cor(*rgb):
    return np.float32(rgb)


def normal_de(h, forca):
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    n = np.dstack([-gx * forca, gy * forca, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def u8(x):
    return np.clip(x * 255.0 + 0.5, 0, 255).astype(np.uint8)


def folha():
    h, w = V_FOLHA, L
    v = (np.arange(h, dtype=np.float32)[:, None] + 0.5) / h
    u = (np.arange(w, dtype=np.float32)[None, :] + 0.5) / w
    # Curada em manchas grandes: do chocolate ao caramelo.
    mancha = ruido(3, (h, w), 2.6, fmin=2.0)
    grande = ruido(4, (h, w), 3.2, fmin=1.0)
    base = mistura(np.broadcast_to(cor(0.25, 0.145, 0.075), (h, w, 3)).copy(),
        cor(0.44, 0.27, 0.13), suave(-1.2, 1.4, mancha * 0.7 + grande * 0.5))
    # Nervura: crista fina de ruido esticado em diagonal. A folha e enrolada em
    # espiral, entao a nervura corre torta em relacao ao eixo.
    nerv = ruido(7, (h, w), 1.6, ax=1.0, ay=7.0, fmin=6.0, angulo=0.55)
    crista = np.clip(1.0 - np.abs(nerv) * 2.2, 0.0, 1.0) ** 3
    fina = ruido(8, (h, w), 1.3, ax=1.0, ay=10.0, fmin=20.0, angulo=0.55)
    crista2 = np.clip(1.0 - np.abs(fina) * 3.0, 0.0, 1.0) ** 4
    veia = np.clip(crista * 0.85 + crista2 * 0.45, 0.0, 1.0)
    base = mistura(base, cor(0.62, 0.43, 0.24), veia * 0.55)
    # Fibra fininha ao comprido da nervura, que e o que da o brilho de folha.
    fibra = ruido(9, (h, w), 0.9, ax=1.0, ay=14.0, fmin=60.0, angulo=0.55)
    base *= (1.0 + fibra[..., None] * 0.045)
    # A costura: a borda da folha de cima dando uma volta e um terco no
    # comprimento. De um lado a borda levanta (clara), do outro ela faz sombra.
    voltas = 1.35
    fase = (v - u * voltas) % 1.0
    d = np.minimum(fase, 1.0 - fase) * h  # distancia em pixel ate a costura
    lado = np.where(fase < 0.5, 1.0, -1.0)
    borda = suave(9.0, 0.0, d)
    base = mistura(base, cor(0.18, 0.10, 0.05), borda * (lado < 0) * 0.75)
    base = mistura(base, cor(0.55, 0.36, 0.19), suave(14.0, 2.0, d) * (lado > 0) * 0.35)
    # Pintinha escura: resina e o po da propria folha.
    pinta = ruido(12, (h, w), 0.2, fmin=1.0)
    base *= (1.0 - suave(2.6, 3.4, pinta)[..., None] * 0.45)
    # A boca: os tres primeiros milimetros sao mais escuros (umidade da boca).
    base *= (1.0 - suave(0.035, 0.0, u)[..., None] * 0.35)
    altura = crista * 0.55 + crista2 * 0.25 + mancha * 0.05 \
        + np.where(lado > 0, suave(9.0, 0.0, d), 0.0) * 0.9
    rug = 0.58 + 0.12 * suave(-1.5, 1.5, mancha) - veia * 0.1
    ao = 1.0 - borda * (lado < 0) * 0.45
    return np.clip(base, 0, 1), altura, rug, ao


def cinza():
    h, w = V_CINZA, L
    u = (np.arange(w, dtype=np.float32)[None, :] + 0.5) / w
    # Aneis em camadas atravessando o eixo: a cinza de blunt cai em escamas.
    torto = ruido(21, (h, w), 2.4, fmin=2.0)
    anel = np.sin((u * 14.0 + torto * 0.06) * np.pi * 2.0) * 0.5 + 0.5
    anel = anel ** 3
    # Escama: manchas redondas, e nao estria — estria esticada le como metal.
    escama = ruido(22, (h, w), 1.9, fmin=10.0)
    base = mistura(np.broadcast_to(cor(0.62, 0.61, 0.59), (h, w, 3)).copy(),
        cor(0.86, 0.85, 0.82), suave(-0.8, 1.0, escama))
    base = mistura(base, cor(0.40, 0.39, 0.37), anel * 0.55)
    camada = escama
    # Rachadura escura.
    rac = ruido(23, (h, w), 1.5, fmin=10.0)
    fenda = np.clip(1.0 - np.abs(rac) * 9.0, 0.0, 1.0) ** 2
    base = mistura(base, cor(0.16, 0.15, 0.14), fenda * 0.8)
    # Carvao: a cinza nova, junto da brasa, ainda e escura.
    base = mistura(base, cor(0.12, 0.11, 0.10), suave(0.16, 0.0, u) * 0.85)
    pinta = ruido(24, (h, w), 0.1)
    base = mistura(base, cor(0.07, 0.06, 0.06), suave(3.3, 3.9, pinta) * 0.8)
    altura = anel * 0.35 + camada * 0.1 - fenda * 0.8
    rug = np.full((h, w), 0.96, np.float32)
    ao = 1.0 - fenda * 0.5
    return np.clip(base, 0, 1), altura, rug, ao


def piteira():
    n = U_PITEIRA
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = cy = (n - 1) * 0.5
    dx, dy = (x - cx) / (n * 0.5), (y - cy) / (n * 0.5)
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    # Papelao enrolado: espiral de Arquimedes de quatro voltas.
    voltas = 4.0
    fase = (r * voltas - ang / (2.0 * np.pi)) % 1.0
    vao = suave(0.12, 0.0, np.minimum(fase, 1.0 - fase))
    papel = mistura(np.broadcast_to(cor(0.83, 0.76, 0.60), (n, n, 3)).copy(),
        cor(0.26, 0.20, 0.14), vao * 0.9)
    papel *= (1.0 + ruido(31, (n, n), 1.2, fmin=6.0)[..., None] * 0.04)
    # O anel de folha em volta do papelao.
    anel = suave(0.70, 0.78, r)
    base = mistura(papel, cor(0.27, 0.16, 0.08), anel)
    base = mistura(base, cor(0.03, 0.02, 0.02), suave(0.97, 1.0, r))
    altura = -vao * 0.6 + anel * 0.4
    rug = 0.9 - anel * 0.25
    ao = 1.0 - vao * 0.4
    return np.clip(base, 0, 1), altura, rug, ao


def brasa():
    h, w = V_BAIXO, L - U_BRASA0
    v = (np.arange(h, dtype=np.float32)[:, None] + 0.5) / h
    # Rede de rachadura incandescente sobre carvao. Periodica em U, que e a volta.
    rede = ruido(41, (h, w), 1.7, fmin=5.0)
    rede2 = ruido(42, (h, w), 1.3, fmin=14.0)
    quente = np.clip(1.0 - np.abs(rede) * 1.6, 0.0, 1.0) ** 2
    quente = np.maximum(quente, np.clip(1.0 - np.abs(rede2) * 2.4, 0.0, 1.0) ** 3 * 0.8)
    # O miolo do anel queima mais que as bordas; a borda de fora (v=1) ja e cinza.
    miolo = np.exp(-((v - 0.45) / 0.30) ** 2)
    calor = np.clip(quente * (0.35 + 0.65 * miolo) + miolo * 0.22, 0.0, 1.0)
    carvao = np.broadcast_to(cor(0.05, 0.04, 0.035), (h, w, 3)).copy()
    base = mistura(carvao, cor(0.85, 0.22, 0.03), suave(0.08, 0.55, calor))
    base = mistura(base, cor(1.0, 0.62, 0.20), suave(0.5, 0.95, calor))
    base = mistura(base, cor(1.0, 0.90, 0.62), suave(0.85, 1.0, calor) * 0.8)
    altura = -quente * 0.5
    rug = np.full((h, w), 0.85, np.float32)
    ao = np.ones((h, w), np.float32)
    return np.clip(base, 0, 1), altura, rug, ao


def atlas():
    cor_ = np.zeros((L, L, 3), np.float32)
    alt = np.zeros((L, L), np.float32)
    rug = np.ones((L, L), np.float32)
    ao = np.ones((L, L), np.float32)

    def por(regiao, y0, x0):
        c, a, r, o = regiao
        h, w = a.shape
        cor_[y0:y0 + h, x0:x0 + w] = c
        alt[y0:y0 + h, x0:x0 + w] = a
        rug[y0:y0 + h, x0:x0 + w] = r
        ao[y0:y0 + h, x0:x0 + w] = o

    por(folha(), 0, 0)
    por(cinza(), V_FOLHA, 0)
    por(piteira(), V_FOLHA + V_CINZA, 0)
    por(brasa(), V_FOLHA + V_CINZA, U_BRASA0)
    # O normal sai por regiao para a costura de uma nao vazar na outra.
    n = np.zeros((L, L, 3), np.float32)
    n[..., 2] = 1.0
    for (y0, y1, x0, x1, forca) in ((0, V_FOLHA, 0, L, 2.2),
            (V_FOLHA, V_FOLHA + V_CINZA, 0, L, 2.8),
            (V_FOLHA + V_CINZA, L, 0, U_PITEIRA, 2.0),
            (V_FOLHA + V_CINZA, L, U_BRASA0, L, 1.5)):
        n[y0:y1, x0:x1] = normal_de(alt[y0:y1, x0:x1], forca)
    return cor_, n, np.dstack([rug, ao, np.zeros_like(rug)])


def main() -> int:
    previa = None
    for arg in sys.argv[1:]:
        if arg.startswith("--previa="):
            previa = Path(arg.split("=", 1)[1])
    c, n, ru = atlas()
    Image.fromarray(u8(c), "RGB").save(HD / "blunt.png", optimize=True)
    Image.fromarray(u8(n * 0.5 + 0.5), "RGB").save(HD / "blunt_n.png", optimize=True)
    Image.fromarray(u8(ru), "RGB").save(HD / "blunt_ru.png", optimize=True)
    p = Image.fromarray(u8(c), "RGB").resize((128, 128), Image.LANCZOS)
    p.quantize(colors=64, method=Image.Quantize.MEDIANCUT).convert("RGB").save(
        PS1 / "blunt.png", optimize=True)
    print("blunt media", (c.reshape(-1, 3).mean(axis=0) * 255).round(1))
    if previa is not None:
        previa.mkdir(parents=True, exist_ok=True)
        luz = np.float32([-0.5, 0.4, 0.75])
        luz /= np.linalg.norm(luz)
        d = np.clip((n * luz).sum(axis=2), 0, 1) * ru[..., 1]
        Image.fromarray(u8(np.clip(c * (0.35 + 0.9 * d[..., None]), 0, 1)), "RGB").save(
            previa / "blunt_luz.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())

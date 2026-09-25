#!/usr/bin/env python3
"""Atlas das bolas de sinuca: 16 celulas (4 x 4), uma por bola, 0 a 15.

Cada celula e a textura EQUIRRETANGULAR da esfera, no contrato de UV do
SphereMesh do Godot: u da a volta (0 a 1), v vai do polo de cima (0) ao de
baixo (1). O numero e o circulo branco sao desenhados na ESFERA e projetados
de volta: para cada pixel da celula, o ponto da esfera que ele representa;
dentro do circulo, o pixel pega a letra no plano tangente ao centro do
circulo. Desenhar o circulo direto na textura sairia um ovo esticado nos
polos e um numero espremido.

- 0: a branca, com dois pontinhos vermelhos opostos (mostram o efeito girando);
- 1 a 7: lisas; 8: preta; 9 a 15: listradas (faixa de 35 graus para cada lado
  do equador), as mesmas cores das lisas.

Saida: game/assets/textures/bar_sinuca_bolas.png (128 px por celula, PS1) e
game/assets/textures_hd/bar_sinuca_bolas.png (512 px, MODERNO), o conjunto HD
achado pelo nome (TexturasHD).

    python tools/gerar_bolas_sinuca.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
PS1 = RAIZ / "game" / "assets" / "textures" / "bar_sinuca_bolas.png"
HD = RAIZ / "game" / "assets" / "textures_hd" / "bar_sinuca_bolas.png"

# As mesmas de MesaSinuca.CORES.
CORES = ["f4f0e4", "f2c21a", "1f4fb4", "d0281e", "5a2a8a", "f07a1a", "1e7a3c",
         "7a1e22", "141414"]
MARFIM = np.array([243, 239, 228], dtype=np.float32)
TINTA = np.array([24, 22, 20], dtype=np.float32)
VERMELHO = np.array([200, 30, 28], dtype=np.float32)

ALFA_CIRCULO = np.radians(30.0)
FAIXA = np.radians(35.0)

FONTES = [r"C:\Windows\Fonts\bahnschrift.ttf", r"C:\Windows\Fonts\arialbd.ttf"]


def hexa(c):
    return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def glifo(n, lado=256):
    """O numero, branco sobre preto, num quadrado: mascara de 0 a 1."""
    im = Image.new("L", (lado, lado), 0)
    d = ImageDraw.Draw(im)
    fonte = None
    for f in FONTES:
        if Path(f).exists():
            fonte = ImageFont.truetype(f, int(lado * (0.62 if n < 10 else 0.5)))
            break
    if fonte is None:
        fonte = ImageFont.load_default()
    texto = str(n)
    caixa = d.textbbox((0, 0), texto, font=fonte)
    w, h = caixa[2] - caixa[0], caixa[3] - caixa[1]
    d.text(((lado - w) / 2 - caixa[0], (lado - h) / 2 - caixa[1]), texto, 255, font=fonte)
    if n in (6, 9):
        # O traco embaixo que separa o 6 do 9 numa bola que gira.
        d.rectangle([lado * 0.36, lado * 0.8, lado * 0.64, lado * 0.85], fill=255)
    return np.asarray(im, dtype=np.float32) / 255.0


def celula(n, lado):
    v, u = np.mgrid[0:lado, 0:lado].astype(np.float32)
    u = (u + 0.5) / lado
    v = (v + 0.5) / lado
    lon = u * 2.0 * np.pi
    lat = np.pi / 2.0 - v * np.pi
    # Ponto da esfera (x, y para cima, z) no contrato do SphereMesh.
    px = np.cos(lat) * np.sin(lon)
    py = np.sin(lat)
    pz = np.cos(lat) * np.cos(lon)
    cor = hexa(CORES[n if n <= 8 else n - 8])
    img = np.empty((lado, lado, 3), dtype=np.float32)
    if n == 0:
        img[:] = MARFIM
    elif n <= 8:
        img[:] = cor
    else:
        img[:] = MARFIM
        faixa = np.abs(lat) < FAIXA
        img[faixa] = cor

    if n == 0:
        # Dois pontos vermelhos opostos no equador.
        for lon0 in (np.pi / 2.0, 3.0 * np.pi / 2.0):
            c = np.array([np.sin(lon0), 0.0, np.cos(lon0)])
            ang = np.arccos(np.clip(px * c[0] + py * c[1] + pz * c[2], -1, 1))
            img[ang < np.radians(9.0)] = VERMELHO
        return img

    g = glifo(n)
    gl = g.shape[0]
    for lon0 in (np.pi / 2.0, 3.0 * np.pi / 2.0):
        c = np.array([np.sin(lon0), 0.0, np.cos(lon0)])
        leste = np.array([np.cos(lon0), 0.0, -np.sin(lon0)])
        norte = np.array([0.0, 1.0, 0.0])
        dot = px * c[0] + py * c[1] + pz * c[2]
        ang = np.arccos(np.clip(dot, -1, 1))
        dentro = ang < ALFA_CIRCULO
        # Borda do circulo com um pixel de suavidade.
        img[dentro] = MARFIM
        # Plano tangente: coordenadas em unidades do raio do circulo.
        tx = (px * leste[0] + py * leste[1] + pz * leste[2]) / np.sin(ALFA_CIRCULO)
        ty = (px * norte[0] + py * norte[1] + pz * norte[2]) / np.sin(ALFA_CIRCULO)
        gx = np.clip(((tx * 0.78 + 1.0) * 0.5 * gl).astype(int), 0, gl - 1)
        gy = np.clip(((1.0 - (ty * 0.78 + 1.0) * 0.5) * gl).astype(int), 0, gl - 1)
        tinta = g[gy, gx] * dentro * (dot > 0)
        img = img * (1.0 - tinta[..., None]) + TINTA * tinta[..., None]
    return img


def atlas(lado):
    out = np.zeros((lado * 4, lado * 4, 3), dtype=np.float32)
    for n in range(16):
        cx, cy = n % 4, n // 4
        out[cy * lado:(cy + 1) * lado, cx * lado:(cx + 1) * lado] = celula(n, lado)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def main():
    grande = atlas(512)
    HD.parent.mkdir(parents=True, exist_ok=True)
    grande.save(HD)
    # O do PS1 sai do grande reduzido, e nao desenhado a 128: o numero a 128 px
    # desenhado direto perde o traco; reduzido, vira mancha legivel.
    grande.resize((512, 512), Image.LANCZOS).save(PS1)
    print(PS1, HD)


if __name__ == "__main__":
    main()

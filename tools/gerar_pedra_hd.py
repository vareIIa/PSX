#!/usr/bin/env python3
"""Embasamento de pedra: a alvenaria de pedra de mao das casas de ladeira de Minas.

    python tools/gerar_pedra_hd.py
    godot --headless --path game --import
    python tools/importar_hd.py
    godot --headless --path game --import

Por que existe
--------------
O embasamento da ladeira (Relevo.embasamento, a capa dele, o miolo de quadra)
usava o calcamento da praca (`pedra_parque`) de pe, com a repeticao de 2,1 m: a
pedra de piso virava bloco de 1 m e a parede de 3 m do lado baixo da ladeira lia
como Lego (PLANO_BAR_E_CIDADE_AAA, C5). O porao de casa de morro mineira e pedra
de mao — gnaisse e granito cinza, uma ou outra com mancha de ferro — assentada
com argamassa de cal, junta funda e irregular.

Como e montada
--------------
- Voronoi TOROIDAL (a textura repete sem costura) de 5 x 6 pontos sorteados numa
  grade, esticado na horizontal: pedra de 25 a 45 cm numa repeticao de 1,6 m
  (`uv_tile` 0,78 no material).
- A junta e a faixa onde a segunda distancia chega perto da primeira; a pedra e
  abaulada (altura pela distancia a junta) com ruido de lasca.
- Cor por pedra: cinza azulado de gnaisse, cinza quente, ocre de ferro (1 em 5) e
  uma escura; salpico de granito por dentro. Argamassa de cal encardida.
- `_n` do relevo; `_ru` com rugosidade em R e oclusao em G (a junta escurece),
  como o `psx_surface_pixel` le.
- PS1: 256 px com o contraste do resto (`_salvar_ps1`).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
DIR_PS1 = RAIZ / "game" / "assets" / "textures"
DIR_HD = RAIZ / "game" / "assets" / "textures_hd"
LADO = 1024
SEMENTE = 20260924
NOME = "pedra_embasamento"

# Pontos da grade (colunas x fiadas) e o esticamento horizontal da distancia.
COLUNAS = 5
FIADAS = 6
ESTICA_X = 0.8
# Largura da junta, na unidade da textura (1 = uma repeticao de 1,6 m).
JUNTA = 0.014
# Peso por pedra (diagrama ponderado): umas maiores, outras de calco.
PESO_MAX = 0.035
# Distorcao da grade: a aresta da pedra ondula em vez de ser reta.
TORCE = 0.022

PALETA = [
    (0.52, 0.51, 0.49),  # gnaisse cinza
    (0.47, 0.47, 0.47),  # gnaisse frio
    (0.55, 0.52, 0.47),  # granito quente
    (0.46, 0.44, 0.41),  # cinza sujo
    (0.55, 0.48, 0.40),  # mancha de ferro, gasta
    (0.37, 0.36, 0.34),  # pedra escura
]
PESOS = [0.26, 0.2, 0.2, 0.14, 0.1, 0.1]
ARGAMASSA = (0.52, 0.5, 0.46)


def ruido(rng: np.random.Generator, lado: int, escala: int) -> np.ndarray:
    """Ruido suave que repete: grade pequena periodica, ampliada com wrap."""
    pequeno = rng.random((escala, escala))
    grande = np.tile(pequeno, (3, 3))
    img = Image.fromarray((grande * 255).astype(np.uint8)).resize(
        (lado * 3, lado * 3), Image.BICUBIC)
    arr = np.asarray(img, dtype=np.float64) / 255.0
    return arr[lado:lado * 2, lado:lado * 2]


def voronoi(rng: np.random.Generator, lado: int):
    """F1, F2 e o indice da pedra mais perta, em toro."""
    pontos = []
    for j in range(FIADAS):
        # Fiada desencontrada meia pedra, como se assenta.
        desloca = 0.5 if j % 2 else 0.0
        for i in range(COLUNAS):
            x = (i + desloca + rng.uniform(-0.3, 0.3)) / COLUNAS
            y = (j + 0.5 + rng.uniform(-0.28, 0.28)) / FIADAS
            pontos.append((x % 1.0, y % 1.0))
    u = np.linspace(0.0, 1.0, lado, endpoint=False, dtype=np.float32)
    gx, gy = np.meshgrid(u, u)
    gx = (gx + (ruido(rng, lado, 14) - 0.5) * TORCE * 2.0 + (ruido(rng, lado, 40) - 0.5) * TORCE) % 1.0
    gy = (gy + (ruido(rng, lado, 14) - 0.5) * TORCE * 2.0 + (ruido(rng, lado, 40) - 0.5) * TORCE) % 1.0
    pesos = rng.uniform(0.0, PESO_MAX, size=len(pontos))
    f1 = np.full((lado, lado), 9.0, np.float32)
    f2 = np.full((lado, lado), 9.0, np.float32)
    idx = np.zeros((lado, lado), np.int32)
    for k, (px, py) in enumerate(pontos):
        dx = np.abs(gx - px)
        dx = np.minimum(dx, 1.0 - dx) * ESTICA_X
        dy = np.abs(gy - py)
        dy = np.minimum(dy, 1.0 - dy)
        d = np.sqrt(dx * dx + dy * dy) - pesos[k]
        menor = d < f1
        f2 = np.where(menor, f1, np.minimum(f2, d))
        idx = np.where(menor, k, idx)
        f1 = np.where(menor, d, f1)
    return f1, f2, idx, len(pontos), np.array(pontos), gx, gy


def main() -> int:
    rng = np.random.default_rng(SEMENTE)
    f1, f2, idx, n, centros, gx, gy = voronoi(rng, LADO)
    borda = (f2 - f1)
    # Junta irregular: a largura varia ao longo dela.
    varia = 0.6 + 0.8 * ruido(rng, LADO, 24)
    junta = borda < JUNTA * varia
    # Abaulado: sobe da junta ao miolo, e satura.
    miolo = np.clip((borda - JUNTA * varia) / 0.05, 0.0, 1.0)
    abaulado = np.sqrt(miolo)
    lasca = ruido(rng, LADO, 64) * 0.5 + ruido(rng, LADO, 160) * 0.3
    altura = np.where(junta, 0.05 * ruido(rng, LADO, 200), 0.55 + 0.35 * abaulado + 0.2 * lasca)

    # Cor por pedra.
    escolha = rng.choice(len(PALETA), size=n, p=PESOS)
    brilho = rng.uniform(0.9, 1.1, size=n)
    base = np.array([PALETA[c] for c in escolha]) * brilho[:, None]
    cor = base[idx]
    salpico = ruido(rng, LADO, 380)
    cor = cor * (0.86 + 0.26 * salpico[..., None])
    cor = cor * (0.9 + 0.12 * ruido(rng, LADO, 40)[..., None])
    # Borda da pedra um pouco mais escura: a aresta gasta pega sujeira.
    cor = cor * (0.8 + 0.2 * abaulado[..., None])
    # Cada pedra pega luz de um lado: a face lascada nunca e plana.
    ang = rng.uniform(0.0, 6.283, size=n)
    cx = centros[:, 0][idx]
    cy = centros[:, 1][idx]
    ddx = (gx - cx + 0.5) % 1.0 - 0.5
    ddy = (gy - cy + 0.5) % 1.0 - 0.5
    face = (ddx * np.cos(ang)[idx] + ddy * np.sin(ang)[idx]) * 6.0
    cor = cor * (1.0 + np.clip(face, -0.18, 0.18)[..., None])
    arg = np.array(ARGAMASSA) * (0.82 + 0.3 * ruido(rng, LADO, 260))[..., None]
    arg = arg * (0.9 + 0.1 * ruido(rng, LADO, 30))[..., None]
    cor = np.where(junta[..., None], arg, cor)

    oclusao = np.where(junta, 0.55, 0.78 + 0.22 * abaulado)
    rugosidade = np.where(junta, 0.97, 0.8 + 0.12 * lasca)

    DIR_HD.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(cor * 255.0, 0, 255).astype(np.uint8), "RGB").save(
        DIR_HD / (NOME + ".jpg"), quality=94)
    dy, dx = np.gradient(altura.astype(np.float64) * 6.0)
    nrm = np.dstack([-dx, dy, np.ones_like(altura)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255.0).astype(np.uint8), "RGB").save(
        DIR_HD / (NOME + "_n.jpg"), quality=95)
    ru = np.dstack([rugosidade, oclusao, np.zeros_like(rugosidade)])
    Image.fromarray(np.clip(ru * 255.0, 0, 255).astype(np.uint8), "RGB").save(
        DIR_HD / (NOME + "_ru.png"))

    # PS1: 256 px, contraste um pouco maior, a oclusao ja na cor (sem relevo la).
    ps1 = cor * oclusao[..., None] / 0.85
    pequeno = Image.fromarray(np.clip(ps1 * 255.0, 0, 255).astype(np.uint8), "RGB")
    pequeno = pequeno.resize((256, 256), Image.BOX)
    arr = np.asarray(pequeno, dtype=np.float64) / 255.0
    arr = np.clip((arr - 0.5) * 1.2 + 0.5, 0.0, 1.0)
    Image.fromarray((arr * 255).astype(np.uint8), "RGB").save(DIR_PS1 / (NOME + ".png"))
    print("ok", NOME)
    return 0


if __name__ == "__main__":
    sys.exit(main())

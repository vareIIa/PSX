#!/usr/bin/env python3
"""Telha ceramica, porta de madeira e toldo de lona, em 1024 px.

    python tools/gerar_fachada_hd.py
    godot --headless --path game --import
    python tools/importar_hd.py
    godot --headless --path game --import

Por que geradas, e nao baixadas
-------------------------------
O conjunto HD da Fase 3 vem do ambientCG, que tem otimo concreto e otimo tijolo
e nao tem telha colonial brasileira, porta de madeira de casa de rua nem lona
listrada de toldo de padaria. Estas tres sao o que faz a rua parecer do interior
de Minas em vez de "cidade generica de tijolo" — e sao desenho, nao foto.

A telha tambem ganha uma versao de 256 px para o PS1 STYLE: ela e material NOVO
(`mat_telha`), e antes o telhado usava a textura de REBOCO. O resto ja tinha
PS1 e so ganha o conjunto de 1024.

Como cada uma e montada
-----------------------
- **telha**: capa e canal, meia-cana alternada, com fiada nova a cada 33 cm e a
  sombra da sobreposicao. Cor terracota variando telha a telha, com limo na
  parte de baixo de algumas — telhado limpo demais le como cenario.
- **porta**: prancha vertical com dois painis rebaixados, no MESMO desenho da
  textura de 128 px do PS1, para o mesmo vao ler igual nos dois presets.
- **toldo**: lona listrada na mesma cadencia da de 256 px, com a trama do
  tecido no relevo e a poeira que junta na dobra de baixo.

O mapa `_ru` empacota rugosidade em R e oclusao em G, que e o que o
`psx_surface_pixel` le (ver o bloco do conjunto HD la).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
DIR_PS1 = RAIZ / "game" / "assets" / "textures"
DIR_HD = RAIZ / "game" / "assets" / "textures_hd"
LADO = 1024
SEMENTE = 20260917


def salvar_cor(nome: str, rgb: np.ndarray, hd: bool = True) -> None:
    img = Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8), "RGB")
    if hd:
        img.save(DIR_HD / (nome + ".jpg"), quality=94)
    else:
        img.save(DIR_PS1 / (nome + ".png"))


def salvar_normal(nome: str, altura: np.ndarray, forca: float = 1.0) -> None:
    """Mapa de normal a partir do campo de altura, em metros de textura."""
    dy, dx = np.gradient(altura.astype(np.float64))
    n = np.dstack([-dx * forca, dy * forca, np.ones_like(altura)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    img = Image.fromarray(((n * 0.5 + 0.5) * 255.0).astype(np.uint8), "RGB")
    img.save(DIR_HD / (nome + "_n.jpg"), quality=95)


def salvar_ru(nome: str, rugosidade: np.ndarray, oclusao: np.ndarray) -> None:
    rgb = np.dstack([rugosidade, oclusao, np.zeros_like(rugosidade)])
    img = Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8), "RGB")
    img.save(DIR_HD / (nome + "_ru.png"))


def ruido(rng: np.random.Generator, lado: int, escala: int) -> np.ndarray:
    """Ruido suave, por interpolacao de uma grade pequena."""
    pequeno = rng.random((escala, escala))
    img = Image.fromarray((pequeno * 255).astype(np.uint8)).resize(
        (lado, lado), Image.BICUBIC)
    return np.asarray(img, dtype=np.float64) / 255.0


def ruido_esticado(rng: np.random.Generator, lado: int, nx: int, ny: int) -> np.ndarray:
    """Ruido mais fino num eixo que no outro: veio de madeira e fibra de lona."""
    pequeno = rng.random((ny, nx))
    img = Image.fromarray((pequeno * 255).astype(np.uint8)).resize(
        (lado, lado), Image.BICUBIC)
    return np.asarray(img, dtype=np.float64) / 255.0


def grade(lado: int):
    u = np.linspace(0.0, 1.0, lado, endpoint=False)
    return np.meshgrid(u, u)


# --------------------------------------------------------------------- telha

def telha(rng: np.random.Generator) -> None:
    lado = LADO
    u, v = grade(lado)
    # A UV do jogo anda 0,5 por metro: uma volta da textura sao 2 m. Doze
    # telhas em 2 m dao 16 cm de largura, que e a telha colonial de verdade.
    colunas = 12.0
    fiadas = 6.0
    cu = u * colunas
    cv = v * fiadas
    col = np.floor(cu)
    fiada = np.floor(cv)
    dentro_u = cu - col
    dentro_v = cv - fiada

    # Meia-cana: capa (convexa) e canal (concava) alternados.
    capa = (col.astype(int) % 2) == 0
    perfil = np.where(capa,
                      np.sqrt(np.clip(1.0 - (dentro_u * 2.0 - 1.0) ** 2, 0.0, 1.0)),
                      -0.75 * np.sqrt(np.clip(1.0 - (dentro_u * 2.0 - 1.0) ** 2, 0.0, 1.0)))
    # A fiada de baixo cavalga a de cima: degrau e sombra no encontro.
    degrau = np.clip((0.12 - dentro_v) / 0.12, 0.0, 1.0)
    altura = perfil * 6.0 + degrau * 4.0

    # Cor: terracota variando por telha, com fiada mais clara aqui e ali.
    chave = (col * 7.0 + fiada * 13.0)
    variacao = (np.sin(chave * 1.7) * 0.5 + 0.5)
    base = np.dstack([
        0.42 + 0.20 * variacao,
        0.20 + 0.10 * variacao,
        0.13 + 0.06 * variacao,
    ])
    manchas = ruido(rng, lado, 64)
    # Limo: verde acinzentado na parte de baixo da telha e nos cantos.
    limo = np.clip((dentro_v - 0.45) * 1.6, 0.0, 1.0) * np.clip(manchas * 1.6 - 0.45, 0.0, 1.0)
    verde = np.dstack([np.full_like(u, 0.26), np.full_like(u, 0.30), np.full_like(u, 0.20)])
    cor = base * (1.0 - limo[..., None]) + verde * limo[..., None]
    # Sombra do encaixe e do vale entre uma telha e outra.
    sombra = 1.0 - 0.45 * degrau - 0.30 * np.clip(-perfil, 0.0, 1.0)
    cor *= sombra[..., None]
    cor *= (0.9 + 0.2 * ruido(rng, lado, 256))[..., None]

    salvar_cor("telha", cor)
    salvar_normal("telha", altura, 1.6)
    rug = 0.62 + 0.18 * manchas - 0.12 * limo
    oc = np.clip(0.55 + 0.45 * (1.0 - degrau) - 0.25 * np.clip(-perfil, 0.0, 1.0), 0.0, 1.0)
    salvar_ru("telha", np.clip(rug, 0.0, 1.0), oc)

    # PS1: 256 px, contraste um pouco maior, como o `baixar_texturas` faz.
    pequeno = Image.fromarray(np.clip(cor * 255.0, 0, 255).astype(np.uint8), "RGB")
    pequeno = pequeno.resize((256, 256), Image.BOX)
    arr = np.asarray(pequeno, dtype=np.float64) / 255.0
    arr = np.clip((arr - 0.5) * 1.2 + 0.5, 0.0, 1.0)
    Image.fromarray((arr * 255).astype(np.uint8), "RGB").save(DIR_PS1 / "telha.png")


# --------------------------------------------------------------------- porta

def porta(rng: np.random.Generator) -> None:
    lado = LADO
    u, v = grade(lado)
    # Dois painis rebaixados, no lugar em que a textura do PS1 os tem.
    def painel(v0, v1):
        dentro = (u > 0.14) & (u < 0.86) & (v > v0) & (v < v1)
        borda = ((u > 0.11) & (u < 0.89) & (v > v0 - 0.03) & (v < v1 + 0.03)) & ~dentro
        return dentro, borda

    p1, b1 = painel(0.10, 0.42)
    p2, b2 = painel(0.55, 0.88)
    rebaixo = (p1 | p2)
    moldura = (b1 | b2)

    # Veio da madeira: linhas verticais tortas.
    # O ruido que torce o veio e esticado NO VERTICAL: com ruido quadrado, as
    # linhas fecham em volta de si mesmas e a porta vira mapa topografico.
    veio = np.sin((u * 26.0 + ruido_esticado(rng, lado, 40, 5) * 2.2) * np.pi * 2.0)
    veio_fino = np.sin((u * 90.0 + ruido_esticado(rng, lado, 80, 8) * 3.0) * np.pi * 2.0)
    madeira = 0.5 + 0.32 * veio + 0.18 * veio_fino
    base = np.dstack([
        0.34 + 0.10 * madeira,
        0.21 + 0.07 * madeira,
        0.11 + 0.04 * madeira,
    ])
    cor = base * np.where(rebaixo, 0.86, 1.0)[..., None]
    cor *= np.where(moldura, 0.7, 1.0)[..., None]
    # Pe da porta encardido: e onde a chuva bate e o pe chuta.
    encardido = np.clip((v - 0.86) * 5.0, 0.0, 1.0) * 0.5
    cor *= (1.0 - 0.45 * encardido)[..., None]

    altura = np.where(rebaixo, -3.0, 0.0) + np.where(moldura, 2.0, 0.0)
    altura = altura + veio * 0.35
    salvar_cor("porta", cor)
    salvar_normal("porta", altura, 1.2)
    rug = 0.45 + 0.12 * madeira + 0.25 * encardido
    oc = np.clip(1.0 - 0.35 * rebaixo.astype(float) - 0.2 * encardido, 0.0, 1.0)
    salvar_ru("porta", np.clip(rug, 0.0, 1.0), oc)


# --------------------------------------------------------------------- toldo

def toldo(rng: np.random.Generator) -> None:
    lado = LADO
    u, v = grade(lado)
    # Dezesseis faixas, a mesma cadencia da textura de 256 px do PS1.
    faixa = np.floor(u * 16.0).astype(int)
    clara = (faixa % 2) == 0
    base = np.where(clara, 0.88, 0.62)
    # Trama do tecido: fio na horizontal e na vertical, bem fino.
    trama = (np.sin(u * lado / 3.0 * np.pi) * 0.5 + 0.5) * 0.06 \
        + (np.sin(v * lado / 3.0 * np.pi) * 0.5 + 0.5) * 0.06
    cinza = base * (0.94 + trama) * (0.95 + 0.1 * ruido(rng, lado, 128))
    # Poeira e agua na barra de baixo.
    sujo = np.clip((v - 0.78) * 4.0, 0.0, 1.0)
    cor = np.dstack([cinza, cinza * 0.985, cinza * 0.96])
    cor *= (1.0 - 0.3 * sujo)[..., None]

    altura = (trama - 0.06) * 6.0 + np.where(clara, 0.0, -0.5)
    salvar_cor("toldo", cor)
    salvar_normal("toldo", altura, 0.8)
    rug = np.clip(0.72 + 0.1 * ruido(rng, lado, 64) + 0.15 * sujo, 0.0, 1.0)
    oc = np.clip(1.0 - 0.25 * sujo, 0.0, 1.0)
    salvar_ru("toldo", rug, oc)


def main() -> int:
    if not DIR_HD.is_dir():
        print("nao achei %s" % DIR_HD, file=sys.stderr)
        return 1
    rng = np.random.default_rng(SEMENTE)
    telha(rng)
    porta(rng)
    toldo(rng)
    print("telha (256 e 1024), porta e toldo (1024) em %s" % DIR_HD)
    print("Agora: godot --headless --path game --import, "
          "python tools/importar_hd.py, e --import de novo")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

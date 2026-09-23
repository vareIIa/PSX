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
- **telha**: capa e canal (TelhadoVivo, PLANO_CASAS_AAA F6): doze colunas em 2 m,
  capa nas pares, canal continuo, fiada de 40 cm com a sombra da sobreposicao e a
  capa desencontrada meia peca. Cor por peca sorteada (a versao antiga alternava
  fiada a fiada e virava xadrez do mirante), limo mais no canal.
- **telha_francesa**: a Marselha do sobrado ecletico, oito colunas em 2 m com o
  encaixe, os dois frisos e o cabeco.
  Com argumentos, gera so as pedidas: `python tools/gerar_fachada_hd.py telha
  telha_francesa` (sem eles, porta e toldo tambem saem, com outro ruido).
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

def _salvar_ps1(nome: str, cor: np.ndarray) -> None:
    """PS1: 256 px, contraste um pouco maior, como o `baixar_texturas` faz."""
    pequeno = Image.fromarray(np.clip(cor * 255.0, 0, 255).astype(np.uint8), "RGB")
    pequeno = pequeno.resize((256, 256), Image.BOX)
    arr = np.asarray(pequeno, dtype=np.float64) / 255.0
    arr = np.clip((arr - 0.5) * 1.2 + 0.5, 0.0, 1.0)
    Image.fromarray((arr * 255).astype(np.uint8), "RGB").save(DIR_PS1 / (nome + ".png"))


def _por_peca(rng: np.random.Generator, col: np.ndarray, fiada: np.ndarray,
              n_col: int, n_fiada: int) -> np.ndarray:
    """Um numero de 0 a 1 por peca, sem padrao: a tabela e sorteada, e nao uma
    conta de coluna e fiada (o seno da versao antiga alternava fiada a fiada e o
    telhado virava xadrez visto do mirante)."""
    tabela = rng.random((n_fiada, n_col))
    return tabela[fiada.astype(int) % n_fiada, col.astype(int) % n_col]


def telha(rng: np.random.Generator) -> None:
    """Capa e canal (PLANO_CASAS_AAA.md, F6).

    A UV do jogo anda 0,5 por metro: uma volta da textura sao 2 m. Doze colunas
    em 2 m (16,7 cm), capa nas pares, que e o que o TelhadoVivo usa para pousar a
    onda de perto em cima da mesma coluna. Cinco fiadas em 2 m: peca de 48 cm
    com 8 de sobreposicao. A v da textura desce da cumeeira para o beiral.

    O canal corre continuo de cima a baixo (a agua escorre por ele), e a capa
    cavalga as duas pecas de canal vizinhas. A sombra da sobreposicao fica logo
    abaixo da ponta da peca de cima; a ponta, um fio mais claro."""
    lado = LADO
    u, v = grade(lado)
    n_col, n_fiada = 12, 5
    cu = u * n_col
    cv = v * n_fiada
    col = np.floor(cu)
    fiada = np.floor(cv)
    dentro_u = cu - col
    dentro_v = cv - fiada
    capa = (col.astype(int) % 2) == 0
    # A capa desencontra meia peca da fiada do canal: a junta de uma nao cai
    # na junta da outra.
    cv_capa = cv + 0.5
    fiada_capa = np.floor(cv_capa)
    dentro_capa = cv_capa - fiada_capa
    dv = np.where(capa, dentro_capa, dentro_v)
    peca_fiada = np.where(capa, fiada_capa, fiada)

    meia_cana = np.sqrt(np.clip(1.0 - (dentro_u * 2.0 - 1.0) ** 2, 0.0, 1.0))
    # A capa afina para cima (a telha colonial e conica): o gomo encolhe perto
    # da ponta de cima da peca.
    largura_capa = 0.82 + 0.18 * dv
    cana_capa = np.sqrt(np.clip(1.0 - ((dentro_u * 2.0 - 1.0) / largura_capa) ** 2, 0.0, 1.0))
    perfil = np.where(capa, cana_capa, -0.8 * meia_cana)
    # Sobreposicao: a peca de cima termina sobre a de baixo. Logo abaixo da ponta,
    # sombra; na propria ponta, a espessura do barro.
    sombra_junta = np.clip((0.14 - dv) / 0.14, 0.0, 1.0)
    ponta = np.clip(1.0 - np.abs(dv - 0.985) / 0.03, 0.0, 1.0)
    altura = perfil * 6.0 + sombra_junta * 2.5 - ponta * 1.5

    # Cor por peca: terracota do mais claro ao mais queimado, sem padrao.
    var_peca = _por_peca(rng, col, peca_fiada, n_col, n_fiada + 1)
    var_coluna = _por_peca(rng, col, np.zeros_like(col), n_col, 1)
    variacao = 0.65 * var_peca + 0.35 * var_coluna
    base = np.dstack([
        0.47 + 0.17 * variacao,
        0.22 + 0.09 * variacao,
        0.13 + 0.05 * variacao,
    ])
    manchas = ruido(rng, lado, 64)
    fino = ruido(rng, lado, 256)
    # Limo: verde acinzentado na metade de baixo da peca e mais no canal, onde a
    # agua para.
    limo = np.clip((dv - 0.5) * 1.8, 0.0, 1.0) * np.clip(manchas * 1.7 - 0.5, 0.0, 1.0)
    limo = np.clip(limo * np.where(capa, 0.35, 0.65), 0.0, 1.0)
    verde = np.dstack([np.full_like(u, 0.28), np.full_like(u, 0.31), np.full_like(u, 0.21)])
    cor = base * (1.0 - limo[..., None]) + verde * limo[..., None]
    # Luz do gomo: a capa clareia no alto e escurece na borda; o canal e escuro.
    luz = np.where(capa, 0.8 + 0.26 * cana_capa, 0.66 + 0.12 * (1.0 - meia_cana))
    sombra = luz * (1.0 - 0.42 * sombra_junta) + 0.12 * ponta
    cor *= sombra[..., None]
    cor *= (0.92 + 0.16 * fino)[..., None]

    salvar_cor("telha", cor)
    salvar_normal("telha", altura, 1.6)
    rug = 0.62 + 0.18 * manchas - 0.12 * limo
    oc = np.clip(0.55 + 0.45 * (1.0 - sombra_junta) - 0.3 * np.clip(-perfil, 0.0, 1.0), 0.0, 1.0)
    salvar_ru("telha", np.clip(rug, 0.0, 1.0), oc)
    _salvar_ps1("telha", cor)


def telha_francesa(rng: np.random.Generator) -> None:
    """Telha francesa (Marselha): a do sobrado ecletico e da casa dos anos 50.

    Oito colunas em 2 m (25 cm de peca) e cinco fiadas (40 cm), alinhadas em
    coluna, sem desencontro. Cada peca tem o encaixe saliente de um lado, os
    dois frisos no meio e o cabeco de cima; a cor e mais uniforme que a da
    capa-e-canal, laranja de forno industrial."""
    lado = LADO
    u, v = grade(lado)
    n_col, n_fiada = 8, 5
    cu = u * n_col
    cv = v * n_fiada
    col = np.floor(cu)
    fiada = np.floor(cv)
    du = cu - col
    dv = cv - fiada
    # Encaixe: a aba lateral que cobre a peca vizinha, lisa e alta.
    aba = np.clip(1.0 - np.abs(du - 0.06) / 0.07, 0.0, 1.0)
    # Os dois frisos do meio (canais rasos) e a lomba entre eles.
    frisos = np.clip(1.0 - np.abs(du - 0.42) / 0.05, 0.0, 1.0) \
        + np.clip(1.0 - np.abs(du - 0.66) / 0.05, 0.0, 1.0)
    lomba = np.clip(1.0 - np.abs(du - 0.54) / 0.1, 0.0, 1.0)
    corpo = np.sin(np.clip(du, 0.0, 1.0) * np.pi) * 0.4
    sombra_junta = np.clip((0.12 - dv) / 0.12, 0.0, 1.0)
    cabeco = np.clip(1.0 - np.abs(dv - 0.96) / 0.04, 0.0, 1.0)
    altura = corpo * 3.0 + aba * 3.0 - frisos * 1.8 + lomba * 1.0 + sombra_junta * 2.0 \
        - cabeco * 1.2

    var_peca = _por_peca(rng, col, fiada, n_col, n_fiada)
    base = np.dstack([
        0.60 + 0.08 * var_peca,
        0.29 + 0.05 * var_peca,
        0.17 + 0.03 * var_peca,
    ])
    manchas = ruido(rng, lado, 64)
    fino = ruido(rng, lado, 256)
    fuligem = np.clip((dv - 0.55) * 1.6, 0.0, 1.0) * np.clip(manchas * 1.6 - 0.6, 0.0, 1.0)
    cinza = np.dstack([np.full_like(u, 0.3), np.full_like(u, 0.28), np.full_like(u, 0.25)])
    cor = base * (1.0 - fuligem[..., None] * 0.7) + cinza * (fuligem[..., None] * 0.7)
    luz = 0.8 + 0.25 * corpo + 0.1 * aba - 0.22 * frisos
    cor *= (luz * (1.0 - 0.45 * sombra_junta) + 0.1 * cabeco)[..., None]
    cor *= (0.94 + 0.12 * fino)[..., None]

    salvar_cor("telha_francesa", cor)
    salvar_normal("telha_francesa", altura, 1.4)
    rug = 0.5 + 0.2 * manchas + 0.1 * fuligem
    oc = np.clip(0.6 + 0.4 * (1.0 - sombra_junta) - 0.25 * frisos, 0.0, 1.0)
    salvar_ru("telha_francesa", np.clip(rug, 0.0, 1.0), oc)
    _salvar_ps1("telha_francesa", cor)


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
    so = [a for a in sys.argv[1:] if not a.startswith("-")]
    if not so or "telha" in so:
        telha(rng)
    if not so or "telha_francesa" in so:
        telha_francesa(np.random.default_rng(SEMENTE + 1))
    if not so or "porta" in so:
        porta(rng)
    if not so or "toldo" in so:
        toldo(rng)
    print("telha e telha_francesa (256 e 1024), porta e toldo (1024) em %s" % DIR_HD)
    print("Agora: godot --headless --path game --import, "
          "python tools/importar_hd.py, e --import de novo")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

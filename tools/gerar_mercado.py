#!/usr/bin/env python3
"""Texturas da loja de conveniencia.

Sao imagens, nao superficies: cada uma cobre um painel inteiro uma vez so, via
PSXMesh.placa_dados. Por isso nao precisam fechar nas bordas como reboco ou
asfalto precisam.

A aposta e a de sempre no PS1: a malha da prateleira e uma caixa, e quem faz a
loja parecer cheia e a textura pregada na frente dela. Modelar produto por
produto custaria mil triangulos por gondola e, a 480x270 com dither por cima,
nao ficaria melhor que uma imagem bem feita.

    python tools/gerar_mercado.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "textures"
FONTES = Path("C:/Windows/Fonts")

LADO = 256
rng = np.random.default_rng(7411)

## Nome inventado. Nao usa marca real: a referencia e o formato da loja, a faixa
## de tres cores e a luz branca, nao o logotipo de ninguem.
NOME_LOJA = "HIKARI"

## As tres cores da faixa. E o codigo visual de loja de conveniencia japonesa, e
## le como tal a trinta metros na nevoa, que e onde ela precisa funcionar.
LARANJA = (226, 122, 38)
VERDE = (58, 140, 84)
VERMELHO = (198, 58, 52)


def salvar(nome: str, img: Image.Image, cores: int = 64) -> None:
    SAIDA.mkdir(parents=True, exist_ok=True)
    metodo = Image.FASTOCTREE if img.mode == "RGBA" else Image.MEDIANCUT
    img.quantize(colors=cores, method=metodo).save(SAIDA / f"{nome}.png", "PNG",
                                                   optimize=True)
    print(f"{nome:24s} {img.width}x{img.height}")


def fonte(arquivo: str, tamanho: int) -> ImageFont.FreeTypeFont:
    caminho = FONTES / arquivo
    if caminho.exists():
        return ImageFont.truetype(str(caminho), tamanho)
    return ImageFont.load_default()


def grao(img: Image.Image, forca: float = 7.0) -> Image.Image:
    """Ruido fino por cima. Superficie chapada denuncia textura gerada."""
    a = np.asarray(img.convert("RGB"), dtype=np.float64)
    a += rng.normal(0.0, forca, a.shape)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


# --- prateleira -------------------------------------------------------------

def prateleira(variante: int) -> None:
    """Frente de gondola: quatro niveis de produto sobre estrutura clara.

    O que faz ler como prateleira, e nao como listra colorida:

      - a sombra sob cada nivel, que separa um do outro
      - produtos de largura irregular, em blocos da mesma cor repetidos, porque
        loja arruma varias unidades do mesmo item lado a lado
      - a faixa clara da borda da prateleira, onde fica a etiqueta de preco
    """
    paletas = [
        # secos e salgadinho: quente e saturado
        ["#c8452f", "#d98b2b", "#e0c24a", "#8a9a3c", "#c96a9a", "#d2d0c4"],
        # bebida e laticinio: frio e claro
        ["#3f7fb8", "#6fb2cf", "#e2e6e4", "#b8d6c2", "#2f5f8a", "#d8c98a"],
        # enlatado e conveniencia: terroso
        ["#8a6a3a", "#a8863f", "#6a7a4a", "#c2a76a", "#7a4a38", "#cfc4a0"],
    ]
    cores = paletas[variante % len(paletas)]
    im = Image.new("RGB", (LADO, LADO), (206, 204, 196))
    d = ImageDraw.Draw(im)

    niveis = 4
    h = LADO // niveis
    for n in range(niveis):
        topo = n * h
        # Fundo do vao, escuro: e o que da profundidade ao nicho.
        d.rectangle((0, topo, LADO, topo + h), fill=(74, 74, 70))

        # Produtos. Largura sorteada, e cada largura se repete de 2 a 5 vezes.
        y0 = topo + int(h * 0.16)
        y1 = topo + int(h * 0.86)
        x = 0
        while x < LADO:
            larg = int(rng.integers(9, 26))
            repete = int(rng.integers(2, 6))
            cor = cores[int(rng.integers(0, len(cores)))]
            rgb = tuple(int(cor.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
            alto = int(rng.integers(0, 5))
            for _ in range(repete):
                if x >= LADO:
                    break
                d.rectangle((x, y0 + alto, x + larg - 2, y1), fill=rgb)
                # Faixa do rotulo, mais clara, na altura dos olhos do produto.
                faixa = tuple(min(255, c + 58) for c in rgb)
                d.rectangle((x, y0 + alto + (y1 - y0) // 3,
                             x + larg - 2, y0 + alto + (y1 - y0) // 3 + 4),
                            fill=faixa)
                # Sombra na lateral direita, que separa uma unidade da outra.
                d.line([(x + larg - 2, y0 + alto), (x + larg - 2, y1)],
                       fill=tuple(int(c * 0.55) for c in rgb))
                x += larg
            x += 1

        # Tampo da prateleira e a etiqueta de preco corrida.
        d.rectangle((0, y1, LADO, y1 + 5), fill=(228, 226, 216))
        d.rectangle((0, y1 + 5, LADO, y1 + 7), fill=(120, 118, 110))
        for ex in range(3, LADO, 34):
            d.rectangle((ex, y1 + 1, ex + 16, y1 + 4), fill=(250, 250, 244))
        # Sombra logo abaixo, projetada no nivel de baixo.
        d.rectangle((0, y1 + 7, LADO, y1 + 12), fill=(52, 52, 50))

    salvar(f"mercado_prateleira_{variante}", grao(im, 5.0))


# --- geladeira --------------------------------------------------------------

def geladeira() -> None:
    """Porta de camara fria: vidro com bebida atras, moldura e puxador.

    A luz vem de dentro, entao o material e emissivo e a textura ja e clara. O
    reflexo diagonal e o unico detalhe que diz que existe vidro ali; sem ele a
    porta le como nicho aberto.
    """
    im = Image.new("RGB", (LADO, LADO), (24, 30, 34))
    d = ImageDraw.Draw(im)

    # Interior iluminado.
    d.rectangle((10, 10, LADO - 11, LADO - 11), fill=(196, 214, 218))

    # Quatro prateleiras de garrafa e lata, em fileira cerrada.
    cores = ["#3f6f9a", "#5f9a5f", "#c2c8cc", "#a8452f", "#d8c05a", "#7a5a3a"]
    for n in range(4):
        topo = 16 + n * 58
        d.rectangle((12, topo, LADO - 13, topo + 50), fill=(150, 172, 178))
        x = 14
        while x < LADO - 16:
            larg = int(rng.integers(10, 17))
            cor = cores[int(rng.integers(0, len(cores)))]
            rgb = tuple(int(cor.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
            for _ in range(int(rng.integers(2, 5))):
                if x >= LADO - 16:
                    break
                d.rectangle((x, topo + 6, x + larg - 2, topo + 48), fill=rgb)
                # Brilho vertical no corpo da garrafa.
                d.line([(x + 2, topo + 8), (x + 2, topo + 46)],
                       fill=tuple(min(255, c + 70) for c in rgb))
                d.rectangle((x, topo + 20, x + larg - 2, topo + 27),
                            fill=tuple(min(255, c + 40) for c in rgb))
                x += larg
            x += 1
        d.rectangle((12, topo + 50, LADO - 13, topo + 54), fill=(214, 228, 230))

    # Moldura da porta.
    d.rectangle((0, 0, LADO - 1, LADO - 1), outline=(96, 104, 108), width=10)
    d.rectangle((10, 10, LADO - 11, LADO - 11), outline=(58, 66, 70), width=2)
    # Puxador vertical.
    d.rectangle((LADO - 30, 60, LADO - 22, LADO - 60), fill=(176, 182, 186))

    # Reflexo diagonal do vidro.
    reflexo = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    rd = ImageDraw.Draw(reflexo)
    rd.polygon([(30, LADO), (110, LADO), (200, 0), (120, 0)],
               fill=(255, 255, 255, 26))
    im = Image.alpha_composite(im.convert("RGBA"), reflexo).convert("RGB")

    salvar("mercado_geladeira", grao(im, 4.0))


# --- letreiro ---------------------------------------------------------------

def letreiro() -> None:
    """Placa da loja: nome sobre branco e a faixa de tres cores embaixo.

    E o objeto mais importante da fachada. Na nevoa densa o jogador ve a mancha
    de cor muito antes de ler o nome, e e a mancha que diz que ali tem uma porta
    que abre.
    """
    largura, altura = 256, 96
    im = Image.new("RGB", (largura, altura), (238, 238, 232))
    d = ImageDraw.Draw(im)

    f = fonte("arialbd.ttf", 44)
    caixa = d.textbbox((0, 0), NOME_LOJA, font=f)
    d.text(((largura - (caixa[2] - caixa[0])) // 2 - caixa[0], 6), NOME_LOJA,
           font=f, fill=(38, 42, 48))

    pequena = fonte("arialbd.ttf", 15)
    d.text((largura - 46, 12), "24H", font=pequena, fill=VERMELHO)

    # Faixa tricolor, o codigo visual da loja de conveniencia.
    faixa = altura - 30
    for i, cor in enumerate((LARANJA, VERDE, VERMELHO)):
        d.rectangle((0, faixa + i * 10, largura, faixa + i * 10 + 10), fill=cor)

    salvar("mercado_letreiro", grao(im, 3.0), 32)


# --- piso e teto ------------------------------------------------------------

def secao() -> None:
    """Placa de corredor pendurada no teto.

    Nao leva o nome da loja: dentro da loja o nome ja e sabido, e repeti-lo em
    cada corredor e o erro que faz o cenario parecer montado com as pecas que
    havia. Leva uma tarja de cor e blocos escuros que leem como palavra a
    distancia, que e como toda sinalizacao de corredor le num quadro de 480x270.
    """
    largura, altura = 256, 64
    im = Image.new("RGB", (largura, altura), (240, 240, 236))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, largura, 12), fill=(70, 74, 78))
    d.rectangle((0, altura - 6, largura, altura), fill=(70, 74, 78))

    # Blocos de "texto", larguras irregulares com espaco de palavra no meio.
    x = 26
    palavras = [(5, 3), (4, 3), (6, 3)]
    for blocos, _ in palavras:
        for _ in range(blocos):
            larg = int(rng.integers(9, 17))
            d.rectangle((x, 24, x + larg, 44), fill=(52, 56, 60))
            x += larg + 5
        x += 14
    salvar("mercado_secao", grao(im, 3.0), 16)


def piso() -> None:
    """Vinilico branco encardido, com rejunte e manchas de trafego.

    Piso de loja de conveniencia e quase branco, e e ele que devolve a luz das
    lampadas para o teto. Encardido, nao limpo: a sujeira no rejunte e o que
    tira o brilho de catalogo.
    """
    a = np.full((LADO, LADO, 3), 214.0)
    a += rng.normal(0.0, 5.0, a.shape)

    # Manchas largas de trafego.
    for _ in range(14):
        cx, cy = rng.integers(0, LADO, 2)
        r = int(rng.integers(18, 52))
        yy, xx = np.mgrid[0:LADO, 0:LADO]
        m = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2.0 * r * r)))
        a -= m[..., None] * rng.uniform(6.0, 20.0)

    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    # Rejunte de ladrilho de 64 px, mais escuro pela sujeira acumulada.
    for k in range(0, LADO, 64):
        d.line([(k, 0), (k, LADO)], fill=(178, 176, 168), width=2)
        d.line([(0, k), (LADO, k)], fill=(178, 176, 168), width=2)
    salvar("mercado_piso", im)


def teto() -> None:
    """Forro de placa branca com a grade de perfil metalico."""
    a = np.full((LADO, LADO, 3), 226.0)
    a += rng.normal(0.0, 4.0, a.shape)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    for k in range(0, LADO, 128):
        d.line([(k, 0), (k, LADO)], fill=(196, 196, 190), width=3)
        d.line([(0, k), (LADO, k)], fill=(196, 196, 190), width=3)
    # Furinhos do forro acustico.
    for _ in range(900):
        x, y = rng.integers(0, LADO, 2)
        d.point((int(x), int(y)), fill=(202, 202, 196))
    salvar("mercado_teto", im, 32)


def main() -> int:
    for v in range(3):
        prateleira(v)
    geladeira()
    letreiro()
    secao()
    piso()
    teto()
    print("\ntexturas do mercado prontas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Icones do minimapa e do mapa de pausa.

Regra unica que decide tudo aqui: o icone tem 11 pixels uteis numa tela de
480x270. Nao existe desenho bonito nesse tamanho, existe desenho LEGIVEL. Cada
um destes e uma silhueta que se distingue das outras seis a um relance, e nada
alem disso:

    mercado   caixa larga com toldo em cima      (unica com dente serrilhado)
    casa      quadrado com telhado de duas aguas (unica com bico)
    predio    retangulo alto com janelas         (unico alto e vazado)
    parque    copa redonda sobre tronco          (unico organico)
    telefone  fone deitado                       (unico diagonal)
    porta     retangulo estreito com macaneta    (unico com ponto lateral)
    jogador   seta cheia                         (unica sem contorno)
    norte     agulha com N                       (unica com letra)

Tudo em tinta escura sobre transparente, para pousar no papel do mapa e no
cartao do minimapa sem precisar de duas versoes.

    python tools/gerar_icones.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "ui"

LADO = 16
TINTA = (38, 28, 20, 255)
MIOLO = (232, 226, 206, 255)
DESTAQUE = (150, 46, 34, 255)


VERDE = (74, 128, 62, 255)


def novo() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def salvar(nome: str, im: Image.Image, cores: int = 16) -> None:
    SAIDA.mkdir(parents=True, exist_ok=True)
    im.quantize(colors=cores, method=Image.FASTOCTREE).save(
        SAIDA / f"icone_{nome}.png", "PNG", optimize=True)
    print(f"icone_{nome:10s} {im.width}x{im.height}")


def mercado() -> None:
    im, d = novo()
    d.rectangle((2, 6, 13, 13), fill=MIOLO, outline=TINTA)
    # Toldo serrilhado: e o unico dente do conjunto, e e por ele que a loja se
    # reconhece antes de o olho registrar o resto.
    d.rectangle((1, 3, 14, 6), fill=DESTAQUE, outline=TINTA)
    for x in range(1, 15, 3):
        d.point((x, 7), fill=TINTA)
        d.point((x + 1, 7), fill=TINTA)
    d.rectangle((6, 9, 9, 13), fill=TINTA)
    salvar("mercado", im)


def casa() -> None:
    im, d = novo()
    d.polygon([(8, 2), (14, 8), (2, 8)], fill=MIOLO, outline=TINTA)
    d.rectangle((3, 8, 13, 14), fill=MIOLO, outline=TINTA)
    d.rectangle((6, 10, 9, 14), fill=TINTA)
    salvar("casa", im)


def casa_verde() -> None:
    """A casa da fumaca.

    Mesma silhueta da casa comum — bico de telhado, corpo quadrado, porta — e
    isso e proposital: no mapa ela precisa ler primeiro como CASA, porque e o
    que ela e. O que muda e o miolo, que sai verde em vez de bege.

    Verde e nao vermelho porque o vermelho ja e a seta do jogador, e o mapa tem
    exatamente uma cor de destaque. Duas, e nenhuma destaca.
    """
    im, d = novo()
    d.polygon([(8, 2), (14, 8), (2, 8)], fill=VERDE, outline=TINTA)
    d.rectangle((3, 8, 13, 14), fill=VERDE, outline=TINTA)
    d.rectangle((6, 10, 9, 14), fill=TINTA)
    # Duas linhas claras saindo do telhado: e a fumaca, e e o que diferencia
    # esta casa da outra num relance, antes de o olho registrar a cor.
    d.point((10, 4), fill=MIOLO)
    d.point((11, 2), fill=MIOLO)
    d.point((12, 4), fill=MIOLO)
    salvar("casa_verde", im)


def predio() -> None:
    im, d = novo()
    d.rectangle((4, 1, 12, 14), fill=MIOLO, outline=TINTA)
    for y in range(3, 12, 3):
        for x in (6, 9):
            d.rectangle((x, y, x + 1, y + 1), fill=TINTA)
    salvar("predio", im)


def parque() -> None:
    im, d = novo()
    d.rectangle((7, 8, 9, 15), fill=TINTA)
    # Copa cheia, nao contornada. Vazada, ela virava uma lupa; o unico icone
    # organico do conjunto tem de ser uma mancha macica para nao ser confundido.
    d.ellipse((1, 1, 14, 11), fill=TINTA)
    d.ellipse((4, 3, 8, 6), fill=(96, 82, 60, 255))
    salvar("parque", im)


def telefone() -> None:
    im, d = novo()
    # Fone na diagonal. A diagonal e a assinatura: nenhum outro icone tem.
    d.line([(3, 12), (12, 3)], fill=TINTA, width=3)
    d.ellipse((1, 9, 6, 14), fill=MIOLO, outline=TINTA)
    d.ellipse((9, 1, 14, 6), fill=MIOLO, outline=TINTA)
    salvar("telefone", im)


def porta() -> None:
    im, d = novo()
    d.rectangle((5, 2, 11, 14), fill=MIOLO, outline=TINTA)
    d.rectangle((9, 8, 10, 9), fill=TINTA)
    salvar("porta", im)


def jogador() -> None:
    im, d = novo()
    # Seta cheia, sem contorno e na cor de destaque: e a unica coisa do mapa que
    # se mexe, e tem de ser achada sem procurar.
    d.polygon([(8, 0), (15, 15), (8, 11), (1, 15)], fill=TINTA)
    d.polygon([(8, 2), (13, 13), (8, 9), (3, 13)], fill=DESTAQUE)
    salvar("jogador", im)


def norte() -> None:
    im, d = novo()
    d.polygon([(8, 0), (11, 7), (8, 5), (5, 7)], fill=TINTA)
    d.line([(5, 15), (5, 9)], fill=TINTA)
    d.line([(5, 9), (10, 15)], fill=TINTA)
    d.line([(10, 15), (10, 9)], fill=TINTA)
    salvar("norte", im)


def main() -> int:
    mercado()
    casa()
    casa_verde()
    predio()
    parque()
    telefone()
    porta()
    jogador()
    norte()
    print("\n9 icones de mapa")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

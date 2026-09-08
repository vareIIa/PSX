#!/usr/bin/env python3
"""Atlas da estrada de terra: a cabine do carro e o mato da beira.

Dois arquivos, e nao dez
------------------------
A cena da estrada precisa de um painel de carro inteiro (chapa, vinil, vidro,
mostrador, volante, difusor, radio) e de uma dezena de plantas de beira de
estrada. Isso seriam vinte texturas de 128 no caminho preguicoso. Aqui sao dois
atlas de 256x256 em celulas de 32, na mesma grade que `Carroceria.uv` ja usa —
o que permite montar tudo com `AtlasKit`, sem escrever mapeamento de UV a mao.

    painel_atlas.png   cabine: vinil, chapa, mostrador, volante, radio
    mato_atlas.png     beira: capim, samambaia, folha larga, moita seca

Por que as chapas sao quase brancas
-----------------------------------
Mesma razao do atlas do carro: o shader multiplica ALBEDO por COLOR (a cor de
vertice), e uma celula ja pintada multiplicaria duas vezes — o capo verde da
print sairia preto. A celula carrega SO o que a cor nao carrega: a nervura, o
brilho da quina, a poeira da estrada. O verde entra por tint.

Por que o mostrador nao tem numero escrito
------------------------------------------
Porque nao cabe. O painel inteiro ocupa uns sessenta pixels de largura na tela
de 480x270, e o mostrador uns vinte: um "40" desenhado ali sao tres pixels de
tinta que viram ruido cinza depois do dither. O que le como mostrador nessa
escala e o ANEL DE TRACOS, e e o que esta desenhado. A leitura numerica da
velocidade e trabalho do HUD, que tem fonte de verdade.

    python tools/gerar_estrada.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
TEXTURAS = RAIZ / "game" / "assets" / "textures"

CELULA = 32
GRADE = 8
LADO = CELULA * GRADE


def colar(im: Image.Image, c: Image.Image, col: int, lin: int) -> None:
    im.paste(c, (col * CELULA, lin * CELULA))


def celula(cor: tuple[int, int, int], alfa: int = 255) -> Image.Image:
    return Image.new("RGBA", (CELULA, CELULA), cor + (alfa,))


def ruido(base: Image.Image, rng: random.Random, n: int,
          cor: tuple[int, int, int], alfa: int = 40) -> None:
    """Sujeira, sempre em camada propria.

    ImageDraw SUBSTITUI o pixel, alfa incluso, em vez de compor: pintar com
    alfa 40 direto sobre a chapa abre um buraco de alfa 40 e a peca fica
    transparente. Foi assim que a carcaca do celular ficou vazada (ver o
    cabecalho de gerar_carro.py); a camada separada e a correcao.
    """
    marcas = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    d = ImageDraw.Draw(marcas)
    for _ in range(n):
        d.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                fill=cor + (alfa,))
    base.alpha_composite(marcas)


# ---------------------------------------------------------------------------
# painel_atlas.png — a cabine
# ---------------------------------------------------------------------------

# Vinil de painel de carro dos anos 80: quase preto, com o granulado grosso que
# o material tinha. O granulado nao e enfeite — e a unica coisa que separa
# "painel" de "retangulo preto" numa tela desta resolucao.
VINIL = (58, 52, 48)
VINIL_CLARO = (82, 74, 68)
CHAPA = (232, 230, 226)
CHAPA_SOMBRA = (196, 194, 190)
CHAPA_BRILHO = (250, 250, 248)


def vinil(rng: random.Random, cor: tuple[int, int, int],
          linhas: bool = False) -> Image.Image:
    c = celula(cor)
    ruido(c, rng, 90, tuple(max(0, v - 22) for v in cor), 150)
    ruido(c, rng, 40, tuple(min(255, v + 26) for v in cor), 90)
    if linhas:
        d = ImageDraw.Draw(c)
        for y in range(0, CELULA, 8):
            d.line((0, y, CELULA, y),
                   fill=tuple(max(0, v - 14) for v in cor) + (255,))
    return c


def cabine_superficies(im: Image.Image, rng: random.Random) -> None:
    """Linha 0: as superficies grandes da cabine."""
    # 0 painel: o vinil escuro do corpo do painel.
    colar(im, vinil(rng, VINIL), 0, 0)

    # 1 quebra-sol e topo do painel: mesmo vinil, um tom acima. O topo pega a
    # luz do para-brisa e sem essa diferenca a cabine vira um bloco chapado.
    colar(im, vinil(rng, VINIL_CLARO), 1, 0)

    # 2 capo: duas nervuras longitudinais. E a celula que ocupa um quarto da
    # tela na cena inteira, entao ela leva a poeira da estrada tambem.
    c = celula(CHAPA)
    ruido(c, rng, 24, CHAPA_SOMBRA, 60)
    d = ImageDraw.Draw(c)
    for x in (9, 22):
        d.line((x, 0, x, CELULA), fill=CHAPA_SOMBRA + (255,))
        d.line((x + 1, 0, x + 1, CELULA), fill=CHAPA_BRILHO + (255,))
    poeira = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    dp = ImageDraw.Draw(poeira)
    for _ in range(30):
        x = rng.randrange(CELULA)
        y = rng.randrange(CELULA)
        dp.point((x, y), fill=(196, 176, 148, rng.randrange(30, 90)))
    c.alpha_composite(poeira)
    colar(im, c, 2, 0)

    # 3 forro de porta: vinil com a costura horizontal no meio.
    c = vinil(rng, (66, 58, 52))
    d = ImageDraw.Draw(c)
    d.line((0, 13, CELULA, 13), fill=(40, 35, 31, 255))
    d.line((0, 14, CELULA, 14), fill=(94, 84, 76, 255))
    colar(im, c, 3, 0)

    # 4 carpete do assoalho e do tunel. Mais fosco e mais sujo que o painel:
    # e o que fica embaixo do pe de quem entra com barro.
    c = celula((46, 41, 36))
    ruido(c, rng, 150, (30, 27, 24), 190)
    ruido(c, rng, 60, (74, 66, 58), 120)
    colar(im, c, 4, 0)

    # 5 forro do teto e da coluna: claro, quase creme encardido.
    c = celula((150, 142, 126))
    ruido(c, rng, 70, (124, 116, 102), 120)
    colar(im, c, 5, 0)

    # 6 madeira do console. Um carro de interior de 1990 tinha o aplique falso.
    c = celula((110, 78, 48))
    d = ImageDraw.Draw(c)
    for _ in range(14):
        y = rng.randrange(CELULA)
        d.line((0, y, CELULA, y + rng.randrange(-1, 2)),
               fill=(84, 58, 34, 255))
    ruido(c, rng, 40, (138, 100, 62), 110)
    colar(im, c, 6, 0)

    # 7 borracha: friso do para-brisa, palheta do limpador, pedal.
    c = celula((34, 32, 30))
    ruido(c, rng, 60, (52, 50, 46), 120)
    colar(im, c, 7, 0)


def cabine_instrumentos(im: Image.Image, rng: random.Random) -> None:
    """Linha 1: o que tem mostrador, botao ou veneziana."""
    fundo = (26, 24, 22)

    def mostrador(inicio: float, fim: float, tracos: int,
                  marca: tuple[int, int, int] = (222, 216, 200)) -> Image.Image:
        """Anel de tracos num arco. E o que le como instrumento a 480x270."""
        c = celula(fundo)
        ruido(c, rng, 30, (44, 40, 36), 120)
        d = ImageDraw.Draw(c)
        centro = (CELULA / 2.0, CELULA / 2.0 + 3.0)
        for i in range(tracos):
            t = i / float(tracos - 1)
            ang = math.radians(inicio + (fim - inicio) * t)
            grande = i % 2 == 0
            r0 = 9.0 if grande else 11.0
            r1 = 14.0
            largura = 2 if grande else 1
            d.line((centro[0] + math.cos(ang) * r0,
                    centro[1] - math.sin(ang) * r0,
                    centro[0] + math.cos(ang) * r1,
                    centro[1] - math.sin(ang) * r1),
                   fill=marca + (255,), width=largura)
        return c

    # 0 velocimetro: arco largo, de 210 a -30 graus, nove tracos grandes.
    colar(im, mostrador(210.0, -30.0, 17), 0, 1)
    # 1 combustivel e 2 temperatura: arcos curtos, meia dezena de tracos.
    colar(im, mostrador(170.0, 100.0, 5), 1, 1)
    colar(im, mostrador(80.0, 10.0, 5, (216, 176, 150)), 2, 1)

    # 3 moldura do painel de instrumentos: preto fosco em volta dos mostradores.
    c = celula((20, 19, 18))
    ruido(c, rng, 50, (36, 34, 32), 140)
    colar(im, c, 3, 1)

    # 4 difusor de ar: venezianas horizontais. O vao entre elas e escuro de
    # verdade, e nao cinza — e o unico furo real que a cabine tem.
    c = celula((44, 40, 37))
    d = ImageDraw.Draw(c)
    for y in range(3, CELULA - 2, 5):
        d.rectangle((2, y, CELULA - 3, y + 2), fill=(12, 11, 10, 255))
        d.line((2, y + 3, CELULA - 3, y + 3), fill=(96, 90, 84, 255))
    colar(im, c, 4, 1)

    # 5 radio: dial claro em cima, dois botoes redondos embaixo.
    c = celula((38, 35, 33))
    d = ImageDraw.Draw(c)
    d.rectangle((4, 6, CELULA - 5, 14), fill=(122, 124, 108, 255))
    for x in range(6, CELULA - 6, 4):
        d.line((x, 8, x, 12), fill=(64, 66, 56, 255))
    d.line((17, 6, 17, 14), fill=(198, 92, 60, 255))
    for cx in (10, 22):
        d.ellipse((cx - 4, 19, cx + 4, 27), fill=(20, 19, 18, 255))
        d.ellipse((cx - 2, 21, cx + 2, 25), fill=(88, 84, 78, 255))
    colar(im, c, 5, 1)

    # 6 porta-luvas: a tampa e a linha do fecho.
    c = vinil(rng, (52, 47, 43))
    d = ImageDraw.Draw(c)
    d.line((0, 2, CELULA, 2), fill=(30, 27, 25, 255))
    d.rectangle((20, 12, 27, 16), fill=(96, 92, 86, 255))
    colar(im, c, 6, 1)

    # 7 metal escovado: haste do cambio, aro do difusor, manivela do vidro.
    c = celula((132, 130, 126))
    d = ImageDraw.Draw(c)
    for x in range(0, CELULA, 3):
        d.line((x, 0, x, CELULA), fill=(108, 106, 102, 255))
    ruido(c, rng, 30, (168, 166, 162), 120)
    colar(im, c, 7, 1)


def cabine_volante(im: Image.Image, rng: random.Random) -> None:
    """Linha 2: volante, espelho e o que sobra."""
    # 0 aro do volante: plastico marrom com o vinco de dedo por baixo.
    c = celula((96, 72, 52))
    d = ImageDraw.Draw(c)
    for y in range(0, CELULA, 6):
        d.line((0, y, CELULA, y), fill=(72, 52, 36, 255))
    ruido(c, rng, 50, (124, 96, 70), 120)
    colar(im, c, 0, 2)

    # 1 cubo do volante: a tampa da buzina, com o retangulo do emblema.
    c = celula((40, 36, 33))
    d = ImageDraw.Draw(c)
    d.rectangle((8, 12, CELULA - 9, 20), fill=(24, 22, 20, 255))
    d.rectangle((12, 15, CELULA - 13, 17), fill=(140, 134, 122, 255))
    ruido(c, rng, 40, (58, 52, 48), 110)
    colar(im, c, 1, 2)

    # 2 raio do volante: metal pintado, mais claro no meio.
    c = celula((86, 82, 78))
    d = ImageDraw.Draw(c)
    d.line((0, 14, CELULA, 14), fill=(126, 122, 116, 255))
    d.line((0, 18, CELULA, 18), fill=(58, 55, 52, 255))
    colar(im, c, 2, 2)

    # 3 espelho retrovisor: vidro escuro com o reflexo do ceu na diagonal.
    c = celula((52, 54, 58))
    d = ImageDraw.Draw(c)
    d.polygon([(0, CELULA), (CELULA, 0), (CELULA, 10), (10, CELULA)],
              fill=(96, 92, 96, 255))
    colar(im, c, 3, 2)

    # 4 chapa suja: a soleira e o para-lama vistos pela janela lateral.
    c = celula(CHAPA)
    ruido(c, rng, 80, (150, 132, 108), 150)
    d = ImageDraw.Draw(c)
    d.rectangle((0, CELULA - 7, CELULA, CELULA), fill=(126, 108, 86, 190))
    colar(im, c, 4, 2)

    # 5 vidro lateral: quase nada. Existe para a janela do motorista nao ser um
    # buraco quadrado no forro da porta quando a camera olha de lado.
    c = celula((150, 156, 162), 96)
    d = ImageDraw.Draw(c)
    d.line((0, CELULA - 4, CELULA, CELULA - 10), fill=(198, 202, 206, 120))
    colar(im, c, 5, 2)

    # 6 tapete de borracha do assoalho, com o relevo em losango.
    c = celula((38, 36, 34))
    d = ImageDraw.Draw(c)
    for y in range(0, CELULA, 6):
        for x in range(0, CELULA, 6):
            d.point((x + (3 if (y // 6) % 2 else 0), y), fill=(60, 57, 54, 255))
    colar(im, c, 6, 2)

    # 7 poeira: a pelicula clara que cobre tudo que e horizontal num carro de
    # estrada de terra. Vai por cima do painel, com alfa, e nao no lugar dele.
    c = celula((188, 168, 138), 0)
    poeira = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
    dp = ImageDraw.Draw(poeira)
    for _ in range(180):
        dp.point((rng.randrange(CELULA), rng.randrange(CELULA)),
                 fill=(200, 180, 150, rng.randrange(40, 130)))
    c.alpha_composite(poeira)
    colar(im, c, 7, 2)


def cabine_luzes(im: Image.Image) -> None:
    """Linha 3: o que acende. Vai no material emissivo, nao no fosco."""
    # 0 luz de painel: o ambar do fundo de instrumento aceso.
    c = celula((198, 138, 62))
    d = ImageDraw.Draw(c)
    d.rectangle((4, 4, CELULA - 5, CELULA - 5), fill=(226, 168, 88, 255))
    colar(im, c, 0, 3)
    # 1 agulha do velocimetro: laranja-vermelho, a unica coisa que se move.
    colar(im, celula((214, 84, 52)), 1, 3)
    # 2 luz-espia vermelha (bateria, oleo).
    colar(im, celula((198, 62, 48)), 2, 3)
    # 3 luz-espia verde (seta).
    colar(im, celula((110, 190, 96)), 3, 3)


# ---------------------------------------------------------------------------
# mato_atlas.png — a beira da estrada
# ---------------------------------------------------------------------------

# Verdes de mata de fim de tarde: rebaixados e puxados para o oliva. Verde de
# meio-dia numa cena de sol baixo le como plastico.
VERDE_ALTO = (104, 122, 70)
VERDE_BAIXO = (62, 78, 46)
SECO = (138, 118, 72)


def _tufo(d: ImageDraw.ImageDraw, rng: random.Random, n: int,
          cor_base: tuple[int, int, int], cor_topo: tuple[int, int, int],
          altura: tuple[int, int], curva: float = 3.0) -> None:
    """Um leque de folhas saindo do mesmo pe, na base da celula."""
    for _ in range(n):
        pe = rng.randrange(4, CELULA - 4)
        alt = rng.randrange(*altura)
        desvio = rng.uniform(-curva, curva)
        largura = rng.choice((1, 1, 2))
        pontos = []
        for k in range(5):
            t = k / 4.0
            pontos.append((pe + desvio * t * t * (1.0 if rng.random() > 0.5 else -1.0),
                           CELULA - 1 - alt * t))
        for k in range(len(pontos) - 1):
            t = k / float(len(pontos) - 1)
            cor = tuple(int(a + (b - a) * t) for a, b in zip(cor_base, cor_topo))
            d.line((pontos[k][0], pontos[k][1], pontos[k + 1][0], pontos[k + 1][1]),
                   fill=cor + (255,), width=largura)


def mato(im: Image.Image, rng: random.Random) -> None:
    """Linha 0: as plantas de pe, recortadas no alfa."""
    def vazia() -> tuple[Image.Image, ImageDraw.ImageDraw]:
        c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
        return c, ImageDraw.Draw(c)

    # 0 capim alto verde: o que forra a beira inteira.
    c, d = vazia()
    _tufo(d, rng, 26, VERDE_BAIXO, VERDE_ALTO, (16, 30))
    colar(im, c, 0, 0)

    # 1 capim seco: um em cada quatro tufos. E o que diz que e fim de estacao.
    c, d = vazia()
    _tufo(d, rng, 22, (96, 84, 52), SECO, (14, 28))
    colar(im, c, 1, 0)

    # 2 samambaia: fronde aberta, folhas curtas saindo de uma haste.
    c, d = vazia()
    for _ in range(5):
        pe = rng.randrange(6, CELULA - 6)
        alt = rng.randrange(18, 28)
        inclina = rng.uniform(-6.0, 6.0)
        for k in range(alt):
            t = k / float(alt)
            x = pe + inclina * t * t
            y = CELULA - 1 - k
            cor = tuple(int(a + (b - a) * t)
                        for a, b in zip(VERDE_BAIXO, VERDE_ALTO))
            braco = int((1.0 - t) * 5.0) + 1
            d.line((x - braco, y + 1, x + braco, y + 1), fill=cor + (255,))
    colar(im, c, 2, 0)

    # 3 folha larga: taioba de beira de estrada. Duas ou tres palmas grandes,
    # que e o que quebra a textura de capim quando o carro passa perto.
    c, d = vazia()
    for _ in range(3):
        cx = rng.randrange(8, CELULA - 8)
        cy = rng.randrange(10, 22)
        rx = rng.randrange(6, 11)
        ry = rng.randrange(7, 12)
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry),
                  fill=VERDE_BAIXO + (255,))
        d.ellipse((cx - rx + 2, cy - ry + 2, cx + rx - 3, cy + ry - 3),
                  fill=VERDE_ALTO + (255,))
        d.line((cx, cy + ry, cx, CELULA), fill=(70, 74, 44, 255))
    colar(im, c, 3, 0)

    # 4 moita densa e baixa: o rodape do mato, onde o capim encontra a terra.
    c, d = vazia()
    _tufo(d, rng, 40, (44, 56, 34), VERDE_BAIXO, (6, 14), 2.0)
    colar(im, c, 4, 0)

    # 5 galho seco com folha: o arbusto morto que sempre tem numa beira.
    c, d = vazia()
    for _ in range(4):
        pe = rng.randrange(6, CELULA - 6)
        topo = rng.randrange(14, 26)
        d.line((pe, CELULA - 1, pe + rng.randrange(-5, 6), CELULA - 1 - topo),
               fill=(92, 76, 56, 255))
    _tufo(d, rng, 8, (104, 88, 58), (146, 128, 84), (8, 18))
    colar(im, c, 5, 0)

    # 6 moita com flor branca: uma mancha clara a cada tantos metros. E o que
    # o farol pega primeiro e o que mais aparece na hora do sol baixo.
    c, d = vazia()
    _tufo(d, rng, 18, VERDE_BAIXO, VERDE_ALTO, (10, 20))
    for _ in range(14):
        x = rng.randrange(3, CELULA - 3)
        y = rng.randrange(6, CELULA - 10)
        d.point((x, y), fill=(226, 220, 196, 255))
        d.point((x + 1, y), fill=(198, 192, 168, 255))
    colar(im, c, 6, 0)

    # 7 capim ralo: metade da densidade do 0, para a beira nao ser um tapete.
    c, d = vazia()
    _tufo(d, rng, 12, VERDE_BAIXO, VERDE_ALTO, (12, 24))
    colar(im, c, 7, 0)


def chao_de_mata(im: Image.Image, rng: random.Random) -> None:
    """Linha 1: superficies deitadas. Opacas, sem recorte."""
    # 0 folhico: o tapete de folha seca embaixo das arvores.
    c = celula((84, 68, 46))
    d = ImageDraw.Draw(c)
    for _ in range(120):
        x = rng.randrange(CELULA)
        y = rng.randrange(CELULA)
        cor = rng.choice([(104, 84, 54), (68, 56, 38), (120, 96, 60),
                          (58, 62, 40)])
        d.line((x, y, x + rng.randrange(1, 4), y + rng.randrange(0, 2)),
               fill=cor + (255,))
    colar(im, c, 0, 1)

    # 1 barro batido do leito: a terra vermelha compactada da trilha do pneu.
    c = celula((132, 96, 68))
    ruido(c, rng, 200, (112, 78, 54), 170)
    ruido(c, rng, 90, (156, 120, 88), 140)
    d = ImageDraw.Draw(c)
    for _ in range(10):
        y = rng.randrange(CELULA)
        d.line((0, y, CELULA, y + rng.randrange(-1, 2)),
               fill=(120, 86, 60, 200))
    colar(im, c, 1, 1)

    # 2 cascalho solto: o que fica no meio da estrada, entre as duas trilhas.
    c = celula((118, 100, 78))
    ruido(c, rng, 260, (92, 78, 60), 190)
    d = ImageDraw.Draw(c)
    for _ in range(40):
        x = rng.randrange(CELULA)
        y = rng.randrange(CELULA)
        d.point((x, y), fill=(168, 156, 136, 230))
    colar(im, c, 2, 1)

    # 3 poca seca: a mancha escura de barro que ficou da ultima chuva.
    c = celula((96, 74, 56))
    ruido(c, rng, 200, (78, 60, 44), 190)
    colar(im, c, 3, 1)


def main() -> int:
    TEXTURAS.mkdir(parents=True, exist_ok=True)

    rng = random.Random(20260908)
    painel = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    cabine_superficies(painel, rng)
    cabine_instrumentos(painel, rng)
    cabine_volante(painel, rng)
    cabine_luzes(painel)
    destino = TEXTURAS / "painel_atlas.png"
    painel.save(destino)
    print(f"gravado {destino.relative_to(RAIZ)}  {LADO}x{LADO}")

    rng = random.Random(20260909)
    beira = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    mato(beira, rng)
    chao_de_mata(beira, rng)
    destino = TEXTURAS / "mato_atlas.png"
    beira.save(destino)
    print(f"gravado {destino.relative_to(RAIZ)}  {LADO}x{LADO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

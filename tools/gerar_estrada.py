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


## Deslocamentos para desenhar uma peca nove vezes, uma por vizinho.
##
## E o que faz a celula FECHAR nas bordas. Uma pedra desenhada a dois pixels da
## borda direita sai cortada ao meio; desenhando a mesma pedra tambem em
## x - 32, a metade que faltava aparece na borda esquerda e as duas se
## encontram quando a textura repete. Sem isto, chao de mata repetido a cada
## metro e meio mostra uma grade de costuras — o defeito que mais denuncia
## textura gerada, e o que o ART-BIBLE cobra quando diz "tem que fechar nas
## bordas".
VIZINHOS = [(dx, dy) for dx in (-CELULA, 0, CELULA)
            for dy in (-CELULA, 0, CELULA)]


def em_ladrilho(desenhar) -> None:
    """Chama `desenhar(dx, dy)` nas nove posicoes. Ver `VIZINHOS`."""
    for dx, dy in VIZINHOS:
        desenhar(dx, dy)


def _pedra(d: ImageDraw.ImageDraw, x: float, y: float, r: float,
           cor: tuple[int, int, int], luz: int = 26) -> None:
    """Um seixo: corpo, topo iluminado e sombra apoiada no chao.

    Tres tons e o minimo para uma pedra de tres pixels parecer volume em vez de
    mancha. Com um tom so, cascalho vira ruido salgado — que era exatamente o
    que a celula antiga fazia, com `d.point` de uma cor.
    """
    escura = tuple(max(0, v - luz) for v in cor)
    clara = tuple(min(255, v + luz) for v in cor)
    em_ladrilho(lambda dx, dy: d.ellipse(
        (x - r + dx, y - r * 0.8 + dy, x + r + dx, y + r + dy),
        fill=escura + (255,)))
    em_ladrilho(lambda dx, dy: d.ellipse(
        (x - r + dx, y - r * 0.8 + dy, x + r * 0.7 + dx, y + r * 0.4 + dy),
        fill=cor + (255,)))
    if r >= 1.6:
        em_ladrilho(lambda dx, dy: d.point(
            (x - r * 0.3 + dx, y - r * 0.4 + dy), fill=clara + (255,)))


def _mancha(c: Image.Image, rng: random.Random, x: float, y: float, r: float,
            cor: tuple[int, int, int], alfa: int) -> None:
    """Mancha de umidade: poligono irregular translucido, em camada propria.

    Poligono de lados sorteados, e nao elipse: elipse le como bolha e a
    repeticao de bolhas iguais vira estampa de bolinha. O que o olho aceita
    como "terra mais umida ali" e contorno quebrado.
    """
    camada = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    lados = rng.randrange(6, 10)
    pontos = []
    for k in range(lados):
        a = math.tau * k / lados
        raio = r * rng.uniform(0.6, 1.25)
        pontos.append((x + math.cos(a) * raio, y + math.sin(a) * raio * 0.8))
    em_ladrilho(lambda dx, dy: d.polygon(
        [(px + dx, py + dy) for px, py in pontos], fill=cor + (alfa,)))
    c.alpha_composite(camada)


def _folha_caida(d: ImageDraw.ImageDraw, rng: random.Random, x: float,
                 y: float, cor: tuple[int, int, int]) -> None:
    """Uma folha seca deitada: losango achatado com nervura mais clara."""
    comp = rng.uniform(2.5, 5.0)
    larg = comp * rng.uniform(0.35, 0.6)
    a = rng.uniform(0.0, math.pi)
    ca, sa = math.cos(a), math.sin(a)
    pontos = [(comp, 0.0), (0.0, larg), (-comp, 0.0), (0.0, -larg)]
    girados = [(x + px * ca - py * sa, y + px * sa + py * ca)
               for px, py in pontos]
    em_ladrilho(lambda dx, dy: d.polygon(
        [(px + dx, py + dy) for px, py in girados], fill=cor + (255,)))
    nervura = tuple(min(255, v + 22) for v in cor)
    em_ladrilho(lambda dx, dy: d.line(
        (x - comp * ca + dx, y - comp * sa + dy,
         x + comp * ca + dx, y + comp * sa + dy), fill=nervura + (255,)))


def _tufo(d: ImageDraw.ImageDraw, rng: random.Random, n: int,
          cor_base: tuple[int, int, int], cor_topo: tuple[int, int, int],
          altura: tuple[int, int], curva: float = 3.0) -> None:
    """Um leque de folhas saindo do mesmo pe, na base da celula.

    A folha AFINA para a ponta e ganha luz no ultimo terco. Capim de largura
    constante e do mesmo tom de baixo a cima le como arame esticado; o que faz
    ler como capim e a ponta ser mais fina e mais clara que o pe.

    A curva tambem passou a ter um lado por folha, em vez de sortear o sentido
    a cada segmento: sorteando por segmento a folha serpenteia, e capim nao
    serpenteia — ele verga para um lado so, que e o lado de onde vem o vento.
    """
    ponta = tuple(min(255, int(v * 1.18)) for v in cor_topo)
    for _ in range(n):
        pe = rng.randrange(2, CELULA - 2)
        alt = rng.randrange(*altura)
        lado = 1.0 if rng.random() > 0.5 else -1.0
        desvio = rng.uniform(0.5, curva) * lado
        grossa = rng.random() < 0.35
        pontos = []
        for k in range(6):
            t = k / 5.0
            pontos.append((pe + desvio * t * t, CELULA - 1 - alt * t))
        for k in range(len(pontos) - 1):
            t = k / float(len(pontos) - 1)
            alvo = ponta if t > 0.66 else cor_topo
            cor = tuple(int(a + (b - a) * t) for a, b in zip(cor_base, alvo))
            largura = 2 if (grossa and t < 0.5) else 1
            em_ladrilho(
                lambda dx, dy, k=k, cor=cor, largura=largura: d.line(
                    (pontos[k][0] + dx, pontos[k][1] + dy,
                     pontos[k + 1][0] + dx, pontos[k + 1][1] + dy),
                    fill=cor + (255,), width=largura))


def mato(im: Image.Image, rng: random.Random) -> None:
    """Linha 0: as plantas de pe, recortadas no alfa."""
    def vazia() -> tuple[Image.Image, ImageDraw.ImageDraw]:
        c = Image.new("RGBA", (CELULA, CELULA), (0, 0, 0, 0))
        return c, ImageDraw.Draw(c)

    # 0 capim alto verde: o que forra a beira inteira. Duas passadas — a de
    # baixo curta e escura — porque capim de verdade tem base fechada; com uma
    # passada so, o pe do tufo fica vazado e a moita flutua.
    c, d = vazia()
    _tufo(d, rng, 34, VERDE_BAIXO, VERDE_ALTO, (16, 31))
    _tufo(d, rng, 8, (52, 66, 40), (86, 102, 60), (10, 20), 2.0)
    colar(im, c, 0, 0)

    # 1 capim seco: um em cada quatro tufos. E o que diz que e fim de estacao.
    c, d = vazia()
    _tufo(d, rng, 28, (96, 84, 52), SECO, (14, 29))
    # Pendao de semente na ponta: e o que da o dourado do capim de beira, e o
    # unico detalhe da celula que sobrevive inteiro a distancia.
    for _ in range(7):
        x = rng.randrange(4, CELULA - 4)
        y = rng.randrange(3, 14)
        for k in range(rng.randrange(3, 6)):
            em_ladrilho(lambda dx, dy, k=k, x=x, y=y: d.point(
                (x + rng.randrange(-1, 2) + dx, y + k + dy),
                fill=(176, 156, 104, 255)))
    colar(im, c, 1, 0)

    # 2 samambaia: fronde com foliolos PAREADOS, que e o que a separa de capim.
    # Os foliolos encurtam para a ponta e a raque aparece no meio deles. Era
    # uma linha horizontal por altura, o que desenha espinha de peixe.
    c, d = vazia()
    for _ in range(4):
        pe = rng.randrange(7, CELULA - 7)
        alt = rng.randrange(19, 29)
        inclina = rng.uniform(-7.0, 7.0)
        raque = []
        for k in range(alt):
            t = k / float(alt)
            raque.append((pe + inclina * t * t, CELULA - 1 - k))
        for k in range(0, alt, 2):
            t = k / float(alt)
            x, y = raque[k]
            braco = (1.0 - t) * 6.0 + 0.8
            queda = braco * 0.35
            cor = tuple(int(a + (b - a) * t)
                        for a, b in zip(VERDE_BAIXO, VERDE_ALTO))
            for s in (-1.0, 1.0):
                em_ladrilho(
                    lambda dx, dy, x=x, y=y, braco=braco, queda=queda,
                    cor=cor, s=s: d.line(
                        (x + dx, y + dy, x + braco * s + dx, y + queda + dy),
                        fill=cor + (255,)))
        for k in range(len(raque) - 1):
            em_ladrilho(lambda dx, dy, k=k: d.line(
                (raque[k][0] + dx, raque[k][1] + dy,
                 raque[k + 1][0] + dx, raque[k + 1][1] + dy),
                fill=(58, 70, 40, 255)))
    colar(im, c, 2, 0)

    # 3 folha larga: taioba de beira de estrada.
    #
    # Era uma elipse clara dentro de uma escura, o que nesta escala le como
    # PIRULITO: um circulo em cima de um pau. Folha de verdade tem bico e tem
    # nervura, e sao esses dois que dizem "folha" em doze pixels. O contorno
    # sai de um seno, entao a folha e mais larga no meio e fecha nas pontas.
    c, d = vazia()
    for _ in range(4):
        cx = rng.randrange(7, CELULA - 7)
        base_y = rng.randrange(20, CELULA - 2)
        comp = rng.randrange(9, 15)
        larg = rng.randrange(4, 7)
        a = rng.uniform(-1.1, 1.1) - math.pi / 2.0
        ca, sa = math.cos(a), math.sin(a)

        def leva(px, py, cx=cx, base_y=base_y, ca=ca, sa=sa):
            return (cx + px * ca - py * sa, base_y + px * sa + py * ca)

        contorno = [leva(0.0, 0.0)]
        for k in range(1, 7):
            t = k / 6.0
            contorno.append(leva(comp * t, larg * math.sin(math.pi * t) * 0.9))
        contorno.append(leva(comp, 0.0))
        for k in range(6, 0, -1):
            t = k / 6.0
            contorno.append(leva(comp * t, -larg * math.sin(math.pi * t) * 0.9))
        em_ladrilho(lambda dx, dy, contorno=contorno: d.polygon(
            [(px + dx, py + dy) for px, py in contorno],
            fill=VERDE_BAIXO + (255,)))
        # Metade de cima mais clara: a luz nao bate igual nos dois lados da
        # nervura, e e esse degrau que da a dobra da folha.
        meia = contorno[:8]
        em_ladrilho(lambda dx, dy, meia=meia: d.polygon(
            [(px + dx, py + dy) for px, py in meia], fill=VERDE_ALTO + (255,)))
        p0, p1 = leva(0.0, 0.0), leva(comp, 0.0)
        em_ladrilho(lambda dx, dy, p0=p0, p1=p1: d.line(
            (p0[0] + dx, p0[1] + dy, p1[0] + dx, p1[1] + dy),
            fill=(140, 156, 96, 255)))
        em_ladrilho(lambda dx, dy, p0=p0, cx=cx: d.line(
            (p0[0] + dx, p0[1] + dy, cx + dx, CELULA + dy),
            fill=(72, 82, 48, 255)))
    colar(im, c, 3, 0)

    # 4 moita densa e baixa: o rodape do mato, onde o capim encontra a terra.
    # Leva bolinha de folha por cima do capim curto: moita nao e so haste, e
    # massa, e a massa e o que aparece quando o farol bate rasante.
    c, d = vazia()
    _tufo(d, rng, 46, (44, 56, 34), VERDE_BAIXO, (6, 15), 2.0)
    for _ in range(22):
        x = rng.randrange(2, CELULA - 2)
        y = rng.randrange(CELULA - 13, CELULA - 1)
        r = rng.uniform(1.2, 2.6)
        cor = rng.choice([(56, 70, 40), (72, 88, 50), (46, 58, 34)])
        em_ladrilho(lambda dx, dy, x=x, y=y, r=r, cor=cor: d.ellipse(
            (x - r + dx, y - r * 0.7 + dy, x + r + dx, y + r * 0.7 + dy),
            fill=cor + (255,)))
    colar(im, c, 4, 0)

    # 5 galho seco com folha: o arbusto morto que sempre tem numa beira.
    # Cada galho ganhou forquilha: galho sem ramificacao le como vareta
    # espetada no chao, que e o que ele era.
    c, d = vazia()
    for _ in range(5):
        pe = rng.randrange(5, CELULA - 5)
        topo = rng.randrange(15, 27)
        ponta_x = pe + rng.randrange(-6, 7)
        em_ladrilho(lambda dx, dy, pe=pe, topo=topo, ponta_x=ponta_x: d.line(
            (pe + dx, CELULA - 1 + dy, ponta_x + dx, CELULA - 1 - topo + dy),
            fill=(92, 76, 56, 255)))
        for _ in range(2):
            t = rng.uniform(0.35, 0.8)
            bx = pe + (ponta_x - pe) * t
            by = CELULA - 1 - topo * t
            fx = bx + rng.randrange(-5, 6)
            fy = by - rng.randrange(3, 8)
            em_ladrilho(lambda dx, dy, bx=bx, by=by, fx=fx, fy=fy: d.line(
                (bx + dx, by + dy, fx + dx, fy + dy), fill=(104, 86, 62, 255)))
    _tufo(d, rng, 9, (104, 88, 58), (146, 128, 84), (8, 18))
    colar(im, c, 5, 0)

    # 6 moita com flor branca: uma mancha clara a cada tantos metros. E o que
    # o farol pega primeiro e o que mais aparece na hora do sol baixo.
    #
    # Cinco petalas em volta de um miolo, e nao dois pixels soltos: nesta
    # escala e a forma de estrela que le como flor. Dois pixels leem como
    # sujeira no dither, e era o que estava la.
    c, d = vazia()
    _tufo(d, rng, 22, VERDE_BAIXO, VERDE_ALTO, (10, 21))
    for _ in range(11):
        x = rng.randrange(3, CELULA - 3)
        y = rng.randrange(5, CELULA - 11)
        for a in range(5):
            ang = math.tau * a / 5.0
            em_ladrilho(lambda dx, dy, x=x, y=y, ang=ang: d.point(
                (x + math.cos(ang) * 1.4 + dx, y + math.sin(ang) * 1.4 + dy),
                fill=(228, 224, 204, 255)))
        em_ladrilho(lambda dx, dy, x=x, y=y: d.point(
            (x + dx, y + dy), fill=(214, 186, 118, 255)))
    colar(im, c, 6, 0)

    # 7 capim ralo: metade da densidade do 0, para a beira nao ser um tapete.
    c, d = vazia()
    _tufo(d, rng, 15, VERDE_BAIXO, VERDE_ALTO, (12, 25))
    colar(im, c, 7, 0)


def chao_de_mata(im: Image.Image, rng: random.Random) -> None:
    """Linha 1: superficies deitadas. Opacas, sem recorte.

    As quatro fecham nas bordas (ver `VIZINHOS`) e as quatro sao construidas na
    mesma ordem: mancha grande primeiro, grao depois, peca solida por ultimo.
    Invertendo a ordem, a mancha translucida lava por cima do seixo e o chao
    volta a ser ruido chapado.

    Ordem tambem e o que separa "terra" de "granulado": ruido sozinho, em
    qualquer densidade, le como chiado de TV. O que da leitura de chao e ter
    tres escalas ao mesmo tempo — mancha de metro, torrao de palmo, grao de
    milimetro — porque e assim que o olho mede distancia numa superficie.
    """
    # 0 folhico: o tapete de folha seca embaixo das arvores.
    #
    # Feito de FOLHAS, e nao de riscos. Eram tracinhos de um a quatro pixels,
    # que a distancia viram granulado uniforme — a mesma coisa que ruido. Uma
    # folha tem contorno e nervura, e e o contorno que sobrevive ao dither.
    c = celula((80, 66, 46))
    for _ in range(9):
        _mancha(c, rng, rng.randrange(CELULA), rng.randrange(CELULA),
                rng.uniform(4.0, 9.0),
                rng.choice([(62, 54, 38), (96, 80, 52)]), 90)
    d = ImageDraw.Draw(c)
    for _ in range(46):
        _folha_caida(d, rng, rng.randrange(CELULA), rng.randrange(CELULA),
                     rng.choice([(108, 88, 54), (72, 60, 40), (126, 100, 60),
                                 (60, 66, 42), (94, 74, 46)]))
    for _ in range(10):
        x, y = rng.randrange(CELULA), rng.randrange(CELULA)
        fx, fy = x + rng.randrange(-4, 5), y + rng.randrange(-3, 4)
        em_ladrilho(lambda dx, dy, x=x, y=y, fx=fx, fy=fy: d.line(
            (x + dx, y + dy, fx + dx, fy + dy), fill=(64, 52, 34, 255)))
    colar(im, c, 0, 1)

    # 1 barro batido do leito: a terra vermelha compactada da trilha do pneu.
    #
    # Esta era a pior celula da folha inteira: dez linhas de borda a borda com
    # um pixel de variacao, o que desenha TABUA, nao terra. Numa estrada de
    # terra nao existe nada que atravesse a pista de um lado ao outro — o que
    # existe e torrao, seixo e a marca curta do pneu, e nenhuma delas e
    # continua. A regra que ficou: nesta celula, nenhum traco pode ser mais
    # comprido que um terco da largura.
    #
    # As feicoes sao GRANDES, e isso e a licao cara desta celula. A primeira
    # versao com torrao de um a dois pixels e grao fino ficou linda ampliada e
    # sumiu por completo no jogo: numa tela de 480x270, com a celula esticada
    # num quad de um metro e o dither de quinze bits por cima, detalhe de tres
    # por cento da celula vira exatamente o mesmo chiado que o dither ja
    # produz. O que sobrevive a minificacao e o que ocupa um QUINTO da celula.
    # Por isso a mancha ganhou alfa alto e o torrao ganhou raio de ate cinco.
    c = celula((128, 94, 66))
    for _ in range(9):
        _mancha(c, rng, rng.randrange(CELULA), rng.randrange(CELULA),
                rng.uniform(7.0, 14.0),
                rng.choice([(96, 66, 44), (152, 118, 84), (84, 58, 40)]), 190)
    ruido(c, rng, 190, (110, 78, 54), 150)
    ruido(c, rng, 110, (152, 118, 86), 120)
    d = ImageDraw.Draw(c)
    # Torrao: terra batida racha em placas, e a placa tem borda clara.
    for _ in range(20):
        _pedra(d, rng.randrange(CELULA), rng.randrange(CELULA),
               rng.uniform(2.0, 5.0),
               rng.choice([(146, 110, 78), (106, 76, 52), (162, 128, 92)]), 30)
    # Risco de pneu: curto e no sentido da marcha.
    for _ in range(12):
        x, y = rng.randrange(CELULA), rng.randrange(CELULA)
        comp = rng.randrange(5, 12)
        desvio = rng.randrange(-1, 2)
        cor = rng.choice([(98, 68, 46), (158, 124, 90)])
        em_ladrilho(
            lambda dx, dy, x=x, y=y, comp=comp, desvio=desvio, cor=cor: d.line(
                (x + dx, y + dy, x + desvio + dx, y + comp + dy),
                fill=cor + (255,), width=2))
    colar(im, c, 1, 1)

    # 2 cascalho solto: o que fica no meio da estrada, entre as duas trilhas.
    # Seixo com volume (ver `_pedra`) em quatro tamanhos, e nao ponto de uma
    # cor: cascalho e definido pela variedade de tamanho, nao pela densidade.
    c = celula((114, 98, 76))
    for _ in range(7):
        _mancha(c, rng, rng.randrange(CELULA), rng.randrange(CELULA),
                rng.uniform(4.0, 8.0), (94, 80, 62), 100)
    d = ImageDraw.Draw(c)
    for _ in range(64):
        _pedra(d, rng.randrange(CELULA), rng.randrange(CELULA),
               rng.uniform(0.9, 2.8),
               rng.choice([(150, 138, 118), (120, 106, 86), (168, 156, 134),
                           (104, 92, 74)]))
    ruido(c, rng, 120, (92, 80, 62), 110)
    colar(im, c, 2, 1)

    # 3 poca: barro MOLHADO, e nao barro escuro.
    #
    # A diferenca entre "escuro" e "molhado" e o brilho: agua parada devolve o
    # ceu numa listra clara e horizontal. Sem essa listra a celula so le como
    # mancha suja, que e o que ela era — e como ela fica no meio do leito, no
    # cone do farol, era a mancha suja que aparecia mais.
    c = celula((92, 72, 54))
    for _ in range(6):
        _mancha(c, rng, rng.randrange(CELULA), rng.randrange(CELULA),
                rng.uniform(5.0, 11.0), (62, 50, 38), 130)
    ruido(c, rng, 170, (74, 58, 42), 170)
    d = ImageDraw.Draw(c)
    # Borda de barro seco em volta da agua.
    for _ in range(18):
        _pedra(d, rng.randrange(CELULA), rng.randrange(CELULA),
               rng.uniform(0.9, 2.0), (104, 82, 60), 16)
    # O reflexo vai em camada propria e translucida: pintado direto, ele
    # apagaria o seixo em vez de molhar.
    # Quebrado em pedacos curtos de alfa baixo, e nao em nove riscos iguais de
    # alfa alto: reflexo de agua parada e picado pela ondulacao, e um traco
    # continuo e claro le como arranhao na textura, nao como brilho.
    reflexo = Image.new("RGBA", c.size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(reflexo)
    for _ in range(14):
        x, y = rng.randrange(CELULA), rng.randrange(CELULA)
        for k in range(rng.randrange(2, 5)):
            comp = rng.randrange(2, 5)
            px = x + k * (comp + rng.randrange(1, 3))
            alfa = rng.randrange(38, 78)
            em_ladrilho(lambda dx, dy, px=px, y=y, comp=comp, alfa=alfa:
                        dr.line((px + dx, y + dy, px + comp + dx, y + dy),
                                fill=(146, 154, 152, alfa)))
    c.alpha_composite(reflexo)
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

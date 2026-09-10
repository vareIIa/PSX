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


# --- fundos da loja ---------------------------------------------------------
#
# Tudo daqui para baixo veste o BLOCO DE SERVICO: garagem, corredor, banheiro e
# copa dos funcionarios. A regra e a mesma da frente da loja — a malha e caixa
# lisa e quem conta a historia e a imagem pregada nela —, mas o vocabulario
# muda de proposito.
#
# O salao e branco, alto e sem uma sombra. Os fundos sao o contrario: verde de
# repartilcao, concreto encardido, papelao e fita. A troca acontece na travessia
# de UMA porta, e e ela que faz o jogador entender que passou para o lado de
# dentro do lugar, onde a loja para de ser vitrine e vira trabalho.


def portao() -> None:
    """Folha do portao de enrolar da garagem, vista de frente.

    Laminas horizontais de 20 px com um pequeno degrade em cada uma: e o degrade
    que faz a chapa ler como dobrada em vez de listrada. A sujeira sobe do chao,
    porque e por baixo que entra a agua da rua.
    """
    a = np.zeros((LADO, LADO, 3))
    base = np.array([132.0, 136.0, 130.0])
    for y in range(LADO):
        # Perfil da lamina: clara em cima, escura embaixo, com o vinco no meio.
        t = (y % 20) / 19.0
        vinco = 1.0 - abs(t - 0.5) * 2.0
        a[y] = base * (0.78 + 0.34 * vinco)
        if y % 20 in (0, 19):
            a[y] *= 0.62

    # Encardido subindo do rodape. So no terco de baixo: portao de rua enferruja
    # de baixo para cima, e sujeira uniforme le como textura errada, nao como
    # portao velho.
    for y in range(LADO):
        sobe = max(0.0, (y - LADO * 0.66) / (LADO * 0.34))
        a[y] = a[y] * (1.0 - 0.3 * sobe) + np.array([88.0, 74.0, 58.0]) * 0.3 * sobe

    a += rng.normal(0.0, 6.0, a.shape)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    # Guias laterais, onde a folha corre.
    for x in (3, LADO - 6):
        d.rectangle([x, 0, x + 3, LADO], fill=(96, 99, 96))
    # Pichacao apagada: dois riscos escuros e sem forma. Um grafite legivel
    # puxaria o olho para um detalhe que nao tem nada a dizer.
    for _ in range(3):
        x0, y0 = int(rng.integers(30, 200)), int(rng.integers(120, 210))
        d.line([(x0, y0), (x0 + int(rng.integers(24, 70)), y0 + int(rng.integers(-18, 18)))],
               fill=(72, 66, 74), width=int(rng.integers(3, 7)))
    salvar("mercado_portao", im, 32)


def azulejo() -> None:
    """Parede de banheiro: ladrilho branco de 15 cm com rejunte encardido.

    O rejunte e o assunto da imagem, e nao o ladrilho. Banheiro de loja e branco
    demais para ter textura propria; o que conta que ele e usado por trinta
    pessoas por noite sao as linhas entre as pecas, escuras de umidade.
    """
    a = np.full((LADO, LADO, 3), 222.0)
    a += rng.normal(0.0, 3.5, a.shape)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    passo = 32
    for k in range(0, LADO + 1, passo):
        d.line([(k, 0), (k, LADO)], fill=(176, 180, 176), width=2)
        d.line([(0, k), (LADO, k)], fill=(176, 180, 176), width=2)
    # Manchas de umidade nos cantos de algumas pecas.
    for _ in range(70):
        cx = int(rng.integers(0, LADO // passo)) * passo
        cy = int(rng.integers(0, LADO // passo)) * passo
        d.ellipse([cx - 4, cy - 4, cx + 5, cy + 5], fill=(158, 164, 154))
    # Uma peca trincada. Uma so: a segunda vira padrao e o olho para de ver.
    d.line([(96, 64), (104, 82), (99, 96)], fill=(168, 170, 164), width=1)
    salvar("mercado_azulejo", grao(im, 3.0), 32)


def papelao() -> None:
    """Frente de caixa de papelao fechada com fita.

    Veste as pilhas da garagem e do deposito. A fita e o carimbo sao o que
    separam "caixa" de "cubo marrom": sao os dois unicos detalhes que o olho
    procura para saber que aquilo e mercadoria esperando para subir na
    prateleira.
    """
    a = np.full((LADO, LADO, 3), 168.0)
    a *= np.array([1.0, 0.86, 0.66])
    a += rng.normal(0.0, 7.0, a.shape)
    # Fibra do papelao: risco horizontal fraco.
    for y in range(0, LADO, 3):
        a[y] *= 0.97
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)

    # Aba central e a fita por cima dela.
    d.line([(0, LADO // 2), (LADO, LADO // 2)], fill=(140, 116, 86), width=3)
    d.rectangle([0, LADO // 2 - 9, LADO, LADO // 2 + 9], fill=(196, 184, 152))
    d.rectangle([0, LADO // 2 - 9, LADO, LADO // 2 - 8], fill=(150, 140, 116))
    d.rectangle([0, LADO // 2 + 8, LADO, LADO // 2 + 9], fill=(150, 140, 116))

    f = fonte("arialbd.ttf", 30)
    d.text((22, 40), NOME_LOJA, font=f, fill=(96, 74, 52))
    fp = fonte("arial.ttf", 18)
    d.text((22, 78), "NAO EMPILHAR", font=fp, fill=(112, 88, 62))
    # Setas de "este lado para cima", em stencil.
    for i in range(2):
        x = 178 + i * 34
        d.polygon([(x, 60), (x + 12, 42), (x + 24, 60)], outline=(104, 80, 56), width=3)
        d.line([(x + 12, 60), (x + 12, 88)], fill=(104, 80, 56), width=4)
    d.rectangle([20, 170, 150, 216], outline=(120, 96, 68), width=3)
    d.text((30, 182), "LOTE 1198", font=fp, fill=(120, 96, 68))
    salvar("mercado_papelao", grao(im, 4.0), 32)


def avisos() -> None:
    """Quadro de cortica da copa, com os papeis que ficam pregados nele.

    E o unico lugar do bloco de servico onde alguem escreveu alguma coisa a mao.
    O texto nao e legivel a 480x270 e nao precisa ser: o que se le e a mancha
    branca de papel sobre a mancha marrom de cortica, e isso ja diz que aquele
    comodo pertence a alguem que trabalha ali todo dia.
    """
    a = np.full((LADO, LADO, 3), 1.0) * np.array([176.0, 138.0, 92.0])
    a += rng.normal(0.0, 10.0, a.shape)
    # Granulado grosso da cortica.
    for _ in range(2600):
        x, y = rng.integers(0, LADO, 2)
        a[y, x] *= rng.uniform(0.78, 1.16)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, LADO - 1, LADO - 1], outline=(112, 84, 54), width=8)

    fp = fonte("arial.ttf", 11)
    papeis = [
        (28, 30, 72, 92, (232, 230, 214), "ESCALA"),
        (116, 24, 84, 62, (238, 232, 180), "TROCA"),
        (36, 146, 96, 68, (228, 226, 212), "ENTREGA"),
        (154, 108, 74, 96, (236, 228, 206), "AVISO"),
    ]
    for x, y, w, h, cor, titulo in papeis:
        incl = int(rng.integers(-2, 3))
        d.rectangle([x, y + incl, x + w, y + h + incl], fill=cor)
        d.rectangle([x, y + incl, x + w, y + h + incl], outline=(150, 140, 122), width=1)
        d.text((x + 6, y + incl + 5), titulo, font=fp, fill=(72, 68, 60))
        # Linhas de escrita: risco cinza, que a 128 px vira texto.
        for k in range(4):
            ly = y + incl + 24 + k * 9
            if ly < y + h + incl - 6:
                d.line([(x + 6, ly), (x + w - int(rng.integers(8, 26)), ly)],
                       fill=(146, 142, 132), width=1)
        # Percevejo.
        d.ellipse([x + w // 2 - 3, y + incl - 2, x + w // 2 + 3, y + incl + 4],
                  fill=(188, 62, 54))
    salvar("mercado_avisos", grao(im, 3.0), 32)


def estoque() -> None:
    """Frente de estante de deposito: caixa e engradado em quatro niveis.

    E a irma da prateleira do salao e trabalha igual — uma imagem cobre a
    estante inteira. A diferenca e que aqui nada esta alinhado: caixa torta,
    altura desigual, engradado de cor errada. Deposito arrumado como gondola
    seria o mesmo comodo duas vezes.
    """
    a = np.full((LADO, LADO, 3), 58.0)
    im = Image.fromarray(a.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)

    caixas = [(158, 126, 88), (146, 112, 76), (172, 140, 100), (120, 96, 68)]
    engradados = [(64, 96, 132), (146, 60, 52), (58, 110, 76), (156, 138, 54)]
    niveis = 4
    alt = LADO // niveis
    for n in range(niveis):
        y0 = n * alt
        # Travessa da estante.
        d.rectangle([0, y0, LADO, y0 + 5], fill=(92, 96, 92))
        x = int(rng.integers(2, 10))
        while x < LADO - 12:
            larg = int(rng.integers(34, 66))
            altura = int(rng.integers(alt - 26, alt - 8))
            topo = y0 + alt - altura
            engradado = rng.random() < 0.34
            cor = (engradados if engradado else caixas)[int(rng.integers(0, 4))]
            d.rectangle([x, topo, x + larg, y0 + alt - 2], fill=cor)
            d.rectangle([x, topo, x + larg, y0 + alt - 2],
                        outline=tuple(int(c * 0.7) for c in cor), width=2)
            if engradado:
                # Vazado do engradado plastico.
                for k in range(3):
                    yy = topo + 8 + k * ((altura - 12) // 3)
                    d.line([(x + 5, yy), (x + larg - 5, yy)],
                           fill=tuple(int(c * 0.62) for c in cor), width=3)
            else:
                # Fita da caixa fechada.
                d.line([(x + larg // 2, topo), (x + larg // 2, y0 + alt - 2)],
                       fill=(198, 186, 154), width=3)
            x += larg + int(rng.integers(2, 9))
    salvar("mercado_estoque", grao(im, 5.0), 48)


def terminal() -> None:
    """A tela do computador do balcao, vista de dentro do mundo.

    E o cartaz do sistema: a mesma janela azul que a consulta abre em tela
    cheia, congelada, para o monitor nao ser um retangulo preto quando o jogador
    ainda esta a tres metros dele. Chegar perto e apertar E troca esta imagem
    pela tela de verdade, que le o registro.

    A cor e a de fosforo de tubo, e nao a de LCD: azul lavado, com as linhas de
    varredura ja pintadas na textura porque a 480x270 o monitor tem trinta
    pixels de altura e nao ha onde desenha-las por cima.
    """
    a = np.full((LADO, LADO, 3), 1.0) * np.array([46.0, 82.0, 126.0])
    im = Image.fromarray(a.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)

    # Moldura da janela do sistema, cinza de 1998.
    d.rectangle([12, 18, LADO - 13, LADO - 34], fill=(196, 198, 190))
    d.rectangle([12, 18, LADO - 13, 40], fill=(58, 76, 132))
    ft = fonte("arialbd.ttf", 14)
    d.text((20, 22), "CADASTRO NACIONAL", font=ft, fill=(232, 236, 244))
    d.rectangle([LADO - 36, 22, LADO - 20, 36], fill=(198, 74, 66))

    # Corpo azul da ficha.
    d.rectangle([22, 48, LADO - 23, LADO - 46], fill=(108, 158, 210))
    d.rectangle([32, 58, LADO - 33, 82], fill=(238, 242, 246))
    fp = fonte("arial.ttf", 13)
    d.text((40, 63), "CPF ___.___.___-__", font=fp, fill=(120, 126, 132))

    # Retangulo da foto e as linhas de dado ao lado.
    d.rectangle([34, 94, 86, 160], fill=(150, 160, 170), outline=(60, 90, 130), width=2)
    fn = fonte("arialbd.ttf", 16)
    d.text((98, 96), "SEM CONSULTA", font=fn, fill=(240, 244, 250))
    for k in range(4):
        d.line([(98, 124 + k * 13), (LADO - 44, 124 + k * 13)], fill=(150, 190, 226), width=3)
    d.text((34, 172), "AGUARDANDO CPF", font=fp, fill=(232, 240, 248))

    # Barra de tarefas.
    d.rectangle([0, LADO - 26, LADO, LADO], fill=(190, 192, 186))
    d.rectangle([6, LADO - 21, 68, LADO - 5], fill=(214, 216, 210), outline=(120, 122, 118))
    d.text((12, LADO - 19), "INICIAR", font=fp, fill=(48, 48, 48))

    # Varredura e brilho de tubo, pintados na imagem.
    a = np.asarray(im, dtype=np.float64)
    a[::2] *= 0.86
    yy, xx = np.mgrid[0:LADO, 0:LADO]
    vinheta = 1.0 - 0.35 * (((xx - LADO / 2) / (LADO / 2)) ** 2
                            + ((yy - LADO / 2) / (LADO / 2)) ** 2)
    a *= vinheta[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    salvar("mercado_terminal", grao(im, 3.0), 48)


def vidro() -> None:
    """Painel da vitrine: vidro aceso com cartaz colado.

    Serve aos dois lados. De dentro e a luz da loja voltando do vidro — o
    interior vive dois mil metros acima da cidade, entao transparente mostraria
    o vazio. De fora e o que faz a loja ler como loja e nao como porta de aco:
    cartaz de cor, reflexo diagonal e a faixa 24H.

    Nao reusa o teto tingido de ciano. Aquilo virava ladrilho de forro na
    fachada, e a loja lia como porta de enrolar fechada.
    """
    a = np.zeros((LADO, LADO, 3))
    for y in range(LADO):
        t = y / float(LADO - 1)
        # Mais claro em cima: e o forro da loja refletido. Mais sujo embaixo,
        # onde a calcada encosta e a mao do cliente encosta.
        a[y] = np.array([198.0, 214.0, 220.0]) * (1.0 - 0.22 * t) + np.array(
            [168.0, 176.0, 172.0]) * (0.22 * t)

    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)

    # Tres cartazes. Sao eles que, da rua, separam vitrine de porta de aco:
    # cor saturada atras de vidro, no tamanho em que um cartaz de loja existe.
    cartazes = [
        (18, 36, 92, 168, LARANJA, (238, 214, 186)),
        (102, 28, 176, 158, VERDE, (214, 232, 210)),
        (186, 44, 238, 176, VERMELHO, (236, 196, 190)),
    ]
    fp = fonte("arialbd.ttf", 18)
    for x0, y0, x1, y1, fundo, papel in cartazes:
        d.rectangle([x0, y0, x1, y1], fill=fundo)
        d.rectangle([x0 + 6, y0 + 8, x1 - 6, y1 - 10], fill=papel)
        # Blocos de "texto": a 480x270 ninguem le letra em cartaz de vitrine,
        # le o ritmo de barra escura sobre papel claro.
        yy = y0 + 18
        while yy < y1 - 22:
            d.rectangle([x0 + 12, yy, x1 - 14, yy + 5], fill=fundo)
            yy += 12

    # Faixa 24H no rodape do vidro. E a unica palavra que a loja precisa
    # gritar da calcada, e cabe em oito pixels de altura.
    d.rectangle([0, LADO - 38, LADO, LADO - 8], fill=(38, 42, 48))
    d.text((LADO // 2 - 28, LADO - 34), "24H", font=fp, fill=(238, 236, 228))
    d.rectangle([0, LADO - 8, LADO, LADO], fill=VERMELHO)

    # Montante fino nas bordas, o aluminio que recorta o painel.
    d.rectangle([0, 0, 6, LADO], fill=(176, 180, 178))
    d.rectangle([LADO - 7, 0, LADO, LADO], fill=(176, 180, 178))
    d.rectangle([0, 0, LADO, 8], fill=(164, 168, 166))

    # Reflexo diagonal. Sem ele o painel le como parede pintada de claro.
    reflexo = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    rd = ImageDraw.Draw(reflexo)
    rd.polygon([(20, LADO), (90, LADO), (180, 0), (110, 0)],
               fill=(255, 255, 255, 38))
    im = Image.alpha_composite(im.convert("RGBA"), reflexo).convert("RGB")
    salvar("mercado_vidro", grao(im, 3.0), 48)


def main() -> int:
    for v in range(3):
        prateleira(v)
    geladeira()
    letreiro()
    secao()
    piso()
    teto()
    vidro()
    portao()
    azulejo()
    papelao()
    avisos()
    estoque()
    terminal()
    print("\ntexturas do mercado prontas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

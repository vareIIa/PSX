#!/usr/bin/env python3
"""Texturas, icone e som do Bar do Ze.

Imagens de painel (letreiro, toldo, cervejeira, vao) e superficies que repetem
(piso, parede, teto, ladrilho, formica, plastico). Paleta curta, 256 px.

Nao chama gerar_materiais.py: aquele script apaga .tres fora da tabela. Os
materiais do bar sao escritos aqui, e as linhas correspondentes vao tambem
na tabela para um regen futuro nao orfa-los.

    python tools/gerar_bar.py
"""

from pathlib import Path
import struct
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
TEXTURAS = RAIZ / "game" / "assets" / "textures"
MATERIAIS = RAIZ / "game" / "resources" / "materials"
UI = RAIZ / "game" / "assets" / "ui"
AUDIO = RAIZ / "game" / "assets" / "audio"
FONTES = Path("C:/Windows/Fonts")

LADO = 256
SR = 22050
rng = np.random.default_rng(8801)

NOME = "BAR DO SEU ZÉ"
CHAMADA = "PETISCOS  *  CERVEJA GELADA  *  PASTEL"

AMARELO = (212, 176, 58)
AMARELO_SUJO = (196, 156, 42)
VERMELHO = (196, 50, 46)
FORMICA = (110, 74, 48)
CIMENTO = (154, 154, 148)


def salvar(nome: str, img: Image.Image, cores: int = 48) -> None:
    TEXTURAS.mkdir(parents=True, exist_ok=True)
    metodo = Image.FASTOCTREE if img.mode == "RGBA" else Image.MEDIANCUT
    img.quantize(colors=cores, method=metodo).save(
        TEXTURAS / f"{nome}.png", "PNG", optimize=True)
    print(f"{nome:24s} {img.width}x{img.height}")


def fonte(arquivo: str, tamanho: int) -> ImageFont.FreeTypeFont:
    caminho = FONTES / arquivo
    if caminho.exists():
        return ImageFont.truetype(str(caminho), tamanho)
    return ImageFont.load_default()


def grao(img: Image.Image, forca: float = 7.0) -> Image.Image:
    a = np.asarray(img.convert("RGB"), dtype=np.float64)
    a += rng.normal(0.0, forca, a.shape)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def rgb(hex_cor: str) -> tuple[int, int, int]:
    h = hex_cor.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


# --- superficies ------------------------------------------------------------

def piso() -> None:
    """Cimento queimado de boteco: cinza, mancha de trafego, sem rejunte fino."""
    a = np.full((LADO, LADO, 3), 158.0)
    a += rng.normal(0.0, 7.0, a.shape)
    yy, xx = np.mgrid[0:LADO, 0:LADO]
    for _ in range(18):
        cx, cy = rng.integers(0, LADO, 2)
        r = int(rng.integers(16, 70))
        m = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2.0 * r * r)))
        a -= m[..., None] * rng.uniform(8.0, 22.0)
    # Riscos de arrasto de cadeira.
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    for _ in range(9):
        y = int(rng.integers(10, LADO - 10))
        d.line([(0, y), (LADO, y + int(rng.integers(-4, 5)))],
               fill=(120, 120, 116), width=1)
    salvar("bar_piso", grao(im, 5.0), 32)


def ladrilho() -> None:
    """Faixa da soleira: ladrilho 8x8, ocre e preto. E o tapete do boteco."""
    im = Image.new("RGB", (LADO, LADO), (40, 36, 32))
    d = ImageDraw.Draw(im)
    cel = LADO // 8
    claras = [(196, 148, 52), (180, 132, 44), (168, 120, 40)]
    escuras = [(36, 32, 28), (48, 42, 36), (28, 26, 24)]
    for gy in range(8):
        for gx in range(8):
            cor = claras[(gx + gy) % 3] if (gx + gy) % 2 == 0 else escuras[(gx + gy) % 3]
            x0, y0 = gx * cel, gy * cel
            d.rectangle((x0 + 1, y0 + 1, x0 + cel - 2, y0 + cel - 2), fill=cor)
    salvar("bar_ladrilho", grao(im, 4.0), 24)


def parede() -> None:
    """Reboco amarelo sujo, a parede de todo bar de cidade pequena."""
    a = np.full((LADO, LADO, 3), (198.0, 168.0, 72.0))
    a += rng.normal(0.0, 6.0, a.shape)
    yy, xx = np.mgrid[0:LADO, 0:LADO]
    for _ in range(12):
        cx, cy = rng.integers(0, LADO, 2)
        r = int(rng.integers(20, 80))
        m = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2.0 * r * r)))
        a += m[..., None] * np.array([rng.uniform(-18, 10),
                                      rng.uniform(-22, 8),
                                      rng.uniform(-28, 4)])
    # Descascado perto do rodape (faixa inferior mais escura).
    a[int(LADO * 0.82):, :, :] *= 0.86
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    for _ in range(7):
        x = int(rng.integers(8, LADO - 20))
        y = int(rng.integers(LADO * 0.7, LADO - 8))
        d.ellipse((x, y, x + int(rng.integers(8, 22)), y + int(rng.integers(6, 14))),
                  fill=(150, 128, 64))
    salvar("bar_parede", grao(im, 5.0), 40)


def teto() -> None:
    """Forro de laje encardido, mancha de umidade no canto."""
    a = np.full((LADO, LADO, 3), (210.0, 198.0, 176.0))
    a += rng.normal(0.0, 5.0, a.shape)
    yy, xx = np.mgrid[0:LADO, 0:LADO]
    m = np.exp(-(((xx - 40) ** 2 + (yy - 30) ** 2) / (2.0 * 70 * 70)))
    a -= m[..., None] * np.array([40.0, 28.0, 10.0])
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    salvar("bar_teto", grao(im, 4.0), 24)


def formica() -> None:
    """Tampo de balcao: formica marrom com pintas claras."""
    a = np.full((LADO, LADO, 3), (118.0, 78.0, 50.0))
    a += rng.normal(0.0, 6.0, a.shape)
    for _ in range(900):
        x, y = int(rng.integers(0, LADO)), int(rng.integers(0, LADO))
        a[y, x] = (168, 140, 110) if rng.random() < 0.5 else (70, 46, 30)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    salvar("bar_formica", grao(im, 3.0), 24)


def plastico() -> None:
    """Plastico de mesa e cadeira monobloco: amarelo grosso, nao liso."""
    a = np.full((LADO, LADO, 3), (226.0, 198.0, 58.0))
    a += rng.normal(0.0, 4.0, a.shape)
    yy, xx = np.mgrid[0:LADO, 0:LADO]
    a += (8.0 * np.sin(xx / 7.0) + 5.0 * np.sin(yy / 11.0))[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    salvar("bar_plastico", grao(im, 3.0), 20)


def xadrez() -> None:
    """Toalha xadrez vermelho e branco. Uma mesa com isso le como boteco."""
    im = Image.new("RGB", (LADO, LADO), (236, 228, 214))
    d = ImageDraw.Draw(im)
    cel = LADO // 8
    for gy in range(8):
        for gx in range(8):
            if (gx + gy) % 2 == 0:
                d.rectangle((gx * cel, gy * cel, (gx + 1) * cel - 1, (gy + 1) * cel - 1),
                            fill=(180, 42, 42))
    salvar("bar_xadrez", grao(im, 3.0), 12)


# --- paineis ----------------------------------------------------------------

def _caber(d: ImageDraw.ImageDraw, texto: str, largura: int, altura: int,
           arquivo: str = "arialbd.ttf") -> ImageFont.FreeTypeFont:
    """Maior corpo que ainda cabe na caixa. O nome cresceu de BAR DO ZE para
    BAR DO SEU ZE: com corpo fixo as duas ultimas letras saiam da placa."""
    corpo = altura
    while corpo > 8:
        f = fonte(arquivo, corpo)
        caixa = d.textbbox((0, 0), texto, font=f)
        if caixa[2] - caixa[0] <= largura and caixa[3] - caixa[1] <= altura:
            return f
        corpo -= 2
    return fonte(arquivo, 8)


def _centrar(d: ImageDraw.ImageDraw, texto: str, f: ImageFont.FreeTypeFont,
             largura: int, altura: int, cor: tuple[int, int, int],
             dy: int = 0) -> None:
    caixa = d.textbbox((0, 0), texto, font=f)
    tw, th = caixa[2] - caixa[0], caixa[3] - caixa[1]
    d.text(((largura - tw) // 2 - caixa[0],
            (altura - th) // 2 - caixa[1] + dy), texto, font=f, fill=cor)


def letreiro() -> None:
    """BAR DO SEU ZE em faixa amarelo/vermelho. Puxa o olho na nevoa.

    512 de largura porque a placa e 5,4 m por 0,95 m na fachada: na proporcao
    antiga o nome comprido virava um borrao de dois pixels por letra a 480x270.
    """
    largura, altura = 512, 112
    im = Image.new("RGB", (largura, altura), AMARELO)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, largura, 11), fill=VERMELHO)
    d.rectangle((0, altura - 15, largura, altura), fill=VERMELHO)
    f = _caber(d, NOME, largura - 48, altura - 46)
    # Sombra dura de placa pintada a mao, um pixel para baixo e para a direita.
    _centrar(d, NOME, f, largura, altura, (150, 112, 28), dy=1)
    _centrar(d, NOME, f, largura, altura, (28, 22, 18))
    salvar("bar_letreiro", grao(im, 3.0), 24)


def faixa() -> None:
    """Faixa de chamada sob o letreiro. De longe e so uma barra vermelha; de
    perto diz o que o bar vende, que e o que uma fachada de boteco faz."""
    largura, altura = 512, 56
    im = Image.new("RGB", (largura, altura), VERMELHO)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, largura, 4), fill=(120, 28, 24))
    d.rectangle((0, altura - 5, largura, altura), fill=(120, 28, 24))
    f = _caber(d, CHAMADA, largura - 24, altura - 22)
    _centrar(d, CHAMADA, f, largura, altura, (248, 232, 180))
    salvar("bar_faixa", grao(im, 3.0), 12)


def azulejo() -> None:
    """Barra de azulejo branco com cercadura verde. Boteco de Minas tem isso
    ate a meia altura: e o que separa a sujeira do reboco amarelo."""
    im = Image.new("RGB", (LADO, LADO), (214, 210, 196))
    d = ImageDraw.Draw(im)
    cel = LADO // 4
    for gy in range(4):
        for gx in range(4):
            x0, y0 = gx * cel, gy * cel
            tom = 232 - int(rng.integers(0, 14))
            d.rectangle((x0 + 3, y0 + 3, x0 + cel - 4, y0 + cel - 4),
                        fill=(tom, tom - 4, tom - 16))
    # Cercadura verde na altura do meio, como o azulejo antigo de padaria.
    d.rectangle((0, cel * 2 - 9, LADO, cel * 2 + 9), fill=(58, 116, 78))
    d.line([(0, cel * 2 - 9), (LADO, cel * 2 - 9)], fill=(30, 70, 46), width=2)
    d.line([(0, cel * 2 + 9), (LADO, cel * 2 + 9)], fill=(30, 70, 46), width=2)
    salvar("bar_azulejo", grao(im, 4.0), 20)


def feltro() -> None:
    """Pano da sinuca. Verde puido, com o desenho das cacapas ja gasto."""
    a = np.full((LADO, LADO, 3), (38.0, 96.0, 62.0))
    a += rng.normal(0.0, 5.0, a.shape)
    yy, xx = np.mgrid[0:LADO, 0:LADO]
    for _ in range(10):
        cx, cy = rng.integers(0, LADO, 2)
        r = int(rng.integers(14, 50))
        m = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2.0 * r * r)))
        a += m[..., None] * rng.uniform(-14.0, 10.0)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    salvar("bar_feltro", grao(im, 4.0), 12)


def cardapio() -> None:
    """Lousa de preco atras do balcao. Preco inventado, em giz torto."""
    im = Image.new("RGB", (LADO, LADO), (34, 38, 36))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, LADO - 1, LADO - 1), outline=(96, 68, 40), width=10)
    titulo = fonte("arialbd.ttf", 30)
    _centrar(d, "HOJE TEM", titulo, LADO, 64, (238, 236, 220))
    linhas = [("PASTEL", "8"), ("TORRESMO", "12"), ("LINGUICA", "14"),
              ("CERVEJA", "7"), ("CAFE", "3")]
    f = fonte("arial.ttf", 24)
    y = 78
    for nome, preco in linhas:
        d.text((26, y), nome, font=f, fill=(226, 224, 206))
        d.text((LADO - 58, y), preco, font=f, fill=(232, 208, 128))
        y += 32
    salvar("bar_cardapio", grao(im, 4.0), 16)


def placa_fiado() -> None:
    """A piada que toda parede de boteco tem. Sem ela o salao e so amarelo."""
    largura, altura = 256, 128
    im = Image.new("RGB", (largura, altura), (234, 226, 202))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, largura - 1, altura - 1), outline=VERMELHO, width=8)
    f = _caber(d, "FIADO SÓ", largura - 40, 44)
    _centrar(d, "FIADO SÓ", f, largura, 68, (40, 30, 24))
    _centrar(d, "AMANHÃ", f, largura, altura + 52, (176, 40, 36))
    salvar("bar_placa", grao(im, 3.0), 12)


def salgados() -> None:
    """Vitrine de salgado no balcao: bandeja de inox e bolinha dourada.

    Emissiva fraca no material — a vitrine de bar e iluminada por dentro, e
    na nevoa e o segundo ponto claro depois do letreiro.
    """
    im = Image.new("RGB", (LADO, LADO), (176, 180, 182))
    d = ImageDraw.Draw(im)
    for n in range(3):
        topo = 18 + n * 80
        d.rectangle((14, topo, LADO - 15, topo + 60), fill=(198, 200, 200))
        d.rectangle((14, topo + 52, LADO - 15, topo + 60), fill=(150, 152, 154))
        x = 24
        while x < LADO - 40:
            larg = int(rng.integers(22, 34))
            cor = (int(rng.integers(196, 226)), int(rng.integers(150, 180)), 72)
            d.ellipse((x, topo + 12, x + larg, topo + 52), fill=cor)
            d.ellipse((x + 6, topo + 18, x + larg - 10, topo + 30),
                      fill=tuple(min(255, c + 26) for c in cor))
            x += larg + 5
    # Vidro: dois riscos largos e so. Uma diagonal a cada cinco pixels virava
    # uma grade branca, e da calcada a vitrine lia como janela de banheiro.
    for k in (30, 150):
        d.line([(k, 0), (k + 110, LADO)], fill=(228, 234, 236), width=6)
    # Escurecer as bordas: vitrine acesa por dentro tem o centro claro e o
    # caixilho escuro. Chapada de ponta a ponta ela lia como lampada.
    yy, xx = np.mgrid[0:LADO, 0:LADO]
    r = np.maximum(np.abs(xx - LADO / 2), np.abs(yy - LADO / 2)) / (LADO / 2)
    a = np.asarray(im, dtype=np.float64) * (1.0 - 0.55 * r ** 3)[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    salvar("bar_salgados", grao(im, 3.0), 32)


def toldo() -> None:
    """Listras amarelo e vermelho, o toldo de bar brasileiro. Nao e marca."""
    im = Image.new("RGB", (LADO, LADO), AMARELO)
    d = ImageDraw.Draw(im)
    faixa = LADO // 8
    for i in range(8):
        if i % 2 == 0:
            d.rectangle((i * faixa, 0, (i + 1) * faixa - 1, LADO), fill=VERMELHO)
        else:
            d.rectangle((i * faixa, 0, (i + 1) * faixa - 1, LADO), fill=AMARELO)
    # Costura entre listras.
    for i in range(1, 8):
        d.line([(i * faixa, 0), (i * faixa, LADO)], fill=(80, 24, 20), width=1)
    salvar("bar_toldo", grao(im, 3.0), 12)


def cervejeira() -> None:
    """Porta de vidro com latas atras. Cores inventadas, sem logo de marca."""
    im = Image.new("RGB", (LADO, LADO), (18, 22, 26))
    d = ImageDraw.Draw(im)
    d.rectangle((8, 8, LADO - 9, LADO - 9), fill=(170, 196, 198))
    cores = ["#c45a2a", "#d8c05a", "#3f6f4a", "#8a3a32", "#d8d4c8", "#5a6a8a"]
    for n in range(4):
        topo = 14 + n * 58
        d.rectangle((12, topo, LADO - 13, topo + 50), fill=(140, 168, 172))
        x = 16
        while x < LADO - 20:
            larg = int(rng.integers(11, 18))
            cor = rgb(cores[int(rng.integers(0, len(cores)))])
            d.rectangle((x, topo + 8, x + larg - 2, topo + 46), fill=cor)
            d.rectangle((x + 2, topo + 14, x + larg - 4, topo + 20),
                        fill=tuple(min(255, c + 40) for c in cor))
            x += larg + 1
        d.rectangle((12, topo + 46, LADO - 13, topo + 50), fill=(210, 220, 222))
    # Moldura e puxador.
    d.rectangle((0, 0, LADO - 1, LADO - 1), outline=(36, 40, 42), width=8)
    d.rectangle((LADO - 22, 70, LADO - 12, 170), fill=(70, 74, 76))
    # Reflexo diagonal: sem ele a porta le como nicho aberto.
    for k in range(-40, LADO, 3):
        d.line([(k, 0), (k + 90, LADO)], fill=(220, 230, 232))
    salvar("bar_cervejeira", grao(im, 4.0), 40)


def vao() -> None:
    """O vao aberto visto da rua: buraco preto, vazamento amarelo no topo.

    Nao e folha de enrolar fechada. Folha fechada seria chapa cinza com
    nervura; isto e escuridao de salao, que e o que um bar aberto e.
    """
    im = Image.new("RGB", (LADO, LADO), (12, 10, 8))
    d = ImageDraw.Draw(im)
    # Vazamento da lampada de dentro, faixa quente no alto — e o que faz o
    # vao ler como aberto, nao como porta de enrolar fechada.
    for y in range(0, 52):
        t = 1.0 - y / 52.0
        cor = (int(140 * t + 12), int(90 * t + 10), int(28 * t + 8))
        d.line([(0, y), (LADO, y)], fill=cor)
    # Sugestao de mesa la dentro, so silhueta.
    d.ellipse((70, 170, 186, 210), fill=(28, 22, 14))
    d.rectangle((118, 150, 138, 190), fill=(24, 18, 12))
    salvar("bar_vao", grao(im, 4.0), 16)


def rua_noite() -> None:
    """O vao visto de DENTRO do salao: a calcada a noite, nao um tapume.

    O painel de fora (bar_vao) e escuridao com vazamento quente no alto, que e
    o que um bar aberto parece da rua. De dentro, o mesmo desenho lia como
    porta de enrolar fechada — e o bar existe justamente para nao ter isso.
    Aqui o claro fica EMBAIXO (a calcada que a lampada do toldo acende) e o
    escuro em cima (a rua e a fachada do outro lado).
    """
    im = Image.new("RGB", (LADO, LADO), (16, 16, 22))
    d = ImageDraw.Draw(im)
    # Predio do outro lado da rua, com duas janelas acesas.
    d.rectangle((0, 0, LADO, 96), fill=(26, 24, 28))
    for x, y in ((38, 30), (150, 18), (196, 54)):
        d.rectangle((x, y, x + 16, y + 22), fill=(96, 78, 44))
    # Halo de poste de sodio, ao fundo.
    for r in range(46, 0, -2):
        t_ = r / 46.0
        d.ellipse((104 - r, 76 - r, 104 + r, 76 + r),
                  fill=(int(26 + 70 * (1 - t_)), int(24 + 48 * (1 - t_)),
                        int(28 + 16 * (1 - t_))))
    # Asfalto e meio-fio.
    d.rectangle((0, 96, LADO, 168), fill=(30, 30, 32))
    d.rectangle((0, 162, LADO, 174), fill=(58, 56, 52))
    # Calcada acesa pela lampada do toldo: e a faixa clara que diz "tem rua ali".
    for y in range(174, LADO):
        f = (y - 174) / float(LADO - 174)
        d.line([(0, y), (LADO, y)],
               fill=(int(72 + 64 * f), int(60 + 50 * f), int(40 + 26 * f)))
    # Silhueta de mesa e duas cadeiras da calcada, contra a faixa clara.
    d.rectangle((58, 150, 116, 158), fill=(22, 20, 18))
    d.rectangle((84, 156, 90, 208), fill=(22, 20, 18))
    for x in (44, 126):
        d.rectangle((x, 166, x + 24, 172), fill=(26, 22, 18))
        d.rectangle((x + 4, 170, x + 10, 204), fill=(26, 22, 18))
        d.rectangle((x + 16, 156, x + 22, 172), fill=(26, 22, 18))
    d.rectangle((186, 140, 236, 208), fill=(24, 22, 22))
    salvar("bar_rua_noite", grao(im, 4.0), 32)


def cartaz() -> None:
    """Cartaz de partida. Campo verde, manchas de jogador, sem clube real."""
    im = Image.new("RGB", (LADO, LADO), (28, 78, 42))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, LADO, 36), fill=(196, 50, 46))
    f = fonte("arialbd.ttf", 22)
    d.text((28, 6), "DOMINGO 16H", font=f, fill=(248, 236, 180))
    d.rectangle((18, 48, LADO - 19, LADO - 19), outline=(236, 236, 220), width=3)
    d.ellipse((LADO // 2 - 28, 130, LADO // 2 + 28, 186), outline=(236, 236, 220), width=2)
    d.line([(LADO // 2, 48), (LADO // 2, LADO - 19)], fill=(236, 236, 220), width=2)
    d.rectangle((18, 48, 70, 110), outline=(236, 236, 220), width=2)
    d.rectangle((LADO - 71, LADO - 82, LADO - 19, LADO - 19), outline=(236, 236, 220), width=2)
    for _ in range(14):
        x, y = int(rng.integers(24, LADO - 24)), int(rng.integers(56, LADO - 28))
        cor = (232, 210, 70) if rng.random() < 0.5 else (40, 70, 160)
        d.ellipse((x, y, x + 7, y + 9), fill=cor)
    salvar("bar_cartaz", grao(im, 4.0), 24)


# --- icone GPS --------------------------------------------------------------

def icone() -> None:
    """Caneca: a unica silhueta com alca. 16 px, igual aos outros do mapa."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    tinta = (38, 28, 20, 255)
    miolo = (232, 226, 206, 255)
    amarelo = (212, 176, 58, 255)
    d.rectangle((3, 5, 11, 14), fill=amarelo, outline=tinta)
    d.rectangle((3, 3, 11, 6), fill=miolo, outline=tinta)
    d.arc((10, 6, 15, 13), 270, 90, fill=tinta, width=1)
    d.point((14, 9), fill=tinta)
    d.point((14, 10), fill=tinta)
    UI.mkdir(parents=True, exist_ok=True)
    im.quantize(colors=8, method=Image.FASTOCTREE).save(
        UI / "icone_bar.png", "PNG", optimize=True)
    print(f"{'icone_bar':24s} 16x16")


# --- som --------------------------------------------------------------------

def estadio() -> None:
    """Multidao de estadio, loop curto. Nao e musica licenciada."""
    n = int(SR * 6.0)
    x = rng.standard_normal(n)
    espectro = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    espectro[(freqs < 180.0) | (freqs > 2800.0)] = 0.0
    x = np.fft.irfft(espectro, n=n)
    t = np.arange(n) / SR
    # Inchaco lento, numero inteiro de ciclos no buffer para o loop nao pulsar.
    x *= 0.55 + 0.25 * np.sin(2.0 * np.pi * (2.0 / 6.0) * t)
    # Dois "gol" — inchaco curto, nao um grito reconhecivel.
    for centro, larg, ganho in ((1.4, 0.35, 0.8), (4.1, 0.4, 1.0)):
        env = np.exp(-0.5 * ((t - centro) / larg) ** 2)
        x += rng.standard_normal(n) * env * ganho * 0.35
    # Emenda.
    m = int(SR * 0.05)
    rampa = np.linspace(0.0, 1.0, m)
    y = x.copy()
    y[:m] = x[:m] * rampa + x[-m:] * (1.0 - rampa)
    y = y[:-m]
    pico = float(np.max(np.abs(y))) or 1.0
    dados = (np.clip(y / pico * 0.72, -1.0, 1.0) * 32767.0).astype("<i2")
    AUDIO.mkdir(parents=True, exist_ok=True)
    caminho = AUDIO / "bar_estadio_loop.wav"
    with wave.open(str(caminho), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(f"{'bar_estadio_loop':24s} {len(y) / SR:5.2f} s")


# --- materiais --------------------------------------------------------------

MODELO = '''[gd_resource type="ShaderMaterial" load_steps=3 format=3]

[ext_resource type="Shader" path="res://shaders/psx_surface.gdshader" id="1_shader"]
[ext_resource type="Texture2D" path="res://assets/textures/{tex}.png" id="2_tex"]

[resource]
resource_name = "mat_{nome}"
shader = ExtResource("1_shader")
shader_parameter/albedo_tex = ExtResource("2_tex")
shader_parameter/tint = Color(1, 1, 1, 1)
shader_parameter/uv_tile = Vector2({tile}, {tile})
shader_parameter/snap_resolution = Vector2(240, 135)
shader_parameter/use_snap = {snap}
shader_parameter/use_affine = true
shader_parameter/alpha_cutoff = 0
shader_parameter/emission_color = Color({emis}, 1)
shader_parameter/emission_energy = {energia}
shader_parameter/vento_forca = 0
shader_parameter/vento_velocidade = 1
'''

# nome, textura, uv_tile, snap, emissao, energia
MATS = [
    ("bar_piso",       "bar_piso",       "0.7", "true",  "0, 0, 0",           "0"),
    ("bar_ladrilho",   "bar_ladrilho",   "0.9", "true",  "0, 0, 0",           "0"),
    ("bar_parede",     "bar_parede",     "0.6", "true",  "0, 0, 0",           "0"),
    ("bar_teto",       "bar_teto",       "0.5", "true",  "0, 0, 0",           "0"),
    ("bar_formica",    "bar_formica",    "1",   "true",  "0, 0, 0",           "0"),
    ("bar_mesa",       "bar_plastico",   "1",   "false", "0, 0, 0",           "0"),
    ("bar_cadeira",    "bar_plastico",   "1",   "false", "0, 0, 0",           "0"),
    ("bar_xadrez",     "bar_xadrez",     "1",   "false", "0, 0, 0",           "0"),
    ("bar_letreiro",   "bar_letreiro",   "1",   "false", "1, 0.92, 0.45",     "2.6"),
    ("bar_toldo",      "bar_toldo",      "1",   "false", "0.9, 0.35, 0.22",   "0.45"),
    ("bar_cervejeira", "bar_cervejeira", "1",   "false", "0.7, 0.84, 1",      "0.85"),
    ("bar_vao",        "bar_vao",        "1",   "false", "0.55, 0.32, 0.12",  "0.55"),
    ("bar_rua_noite",  "bar_rua_noite",  "1",   "false", "0.5, 0.4, 0.26",    "0.5"),
    ("bar_cartaz",     "bar_cartaz",     "1",   "false", "0.4, 0.55, 0.3",    "0.35"),
    ("bar_faixa",      "bar_faixa",      "1",   "false", "1, 0.5, 0.28",      "1.4"),
    ("bar_azulejo",    "bar_azulejo",    "1.4", "true",  "0, 0, 0",           "0"),
    ("bar_feltro",     "bar_feltro",     "1.6", "true",  "0, 0, 0",           "0"),
    ("bar_cardapio",   "bar_cardapio",   "1",   "false", "0.9, 0.86, 0.7",    "0.3"),
    ("bar_placa",      "bar_placa",      "1",   "false", "0.9, 0.86, 0.7",    "0.25"),
    ("bar_salgados",   "bar_salgados",   "1",   "false", "1, 0.82, 0.5",      "0.45"),
]


def materiais() -> None:
    MATERIAIS.mkdir(parents=True, exist_ok=True)
    for nome, tex, tile, snap, emis, energia in MATS:
        (MATERIAIS / f"mat_{nome}.tres").write_text(
            MODELO.format(nome=nome, tex=tex, tile=tile, snap=snap,
                          emis=emis, energia=energia),
            encoding="utf-8")
        print(f"mat_{nome:18s} <- {tex}.png")


def main() -> int:
    piso()
    ladrilho()
    parede()
    teto()
    formica()
    plastico()
    xadrez()
    azulejo()
    feltro()
    letreiro()
    faixa()
    cardapio()
    placa_fiado()
    salgados()
    toldo()
    cervejeira()
    vao()
    rua_noite()
    cartaz()
    icone()
    estadio()
    materiais()
    print("\nbar: texturas, icone, som e materiais")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Texturas de parque e de variacao de fachada.

Duas familias, com regras diferentes:

  superficie   grama, casca, areia, pedra, agua. Repetem no mundo, entao TEM de
               fechar nas bordas.
  imagem       toldo e placa de parque. Cobrem o painel uma vez so, via
               PSXMesh.placa_dados, e nao precisam fechar.

Ruido nao basta para folha
--------------------------
A primeira versao da folhagem era fbm com contraste alto. Na tela virou o que o
teste apontou: um quadrado grande de mancha verde. O motivo e que ruido nao tem
FORMA — ampliado, ele so fica mais borrado, e a copa perde a unica coisa que a
faz ler como copa, que e o aglomerado de folha com buraco entre um e outro.

Aqui a folha e desenhada: centenas de elipses giradas em tres camadas de tom,
com a de cima mais clara. Desenho em textura que repete tem o problema da
emenda, e a saida e `wrap_colar`, que cola cada peca nove vezes, uma no quadro e
oito fora dele; o que sai por uma borda entra pela oposta.

E ha duas versoes da mesma folha:

  folhagem          opaca, para o nucleo da copa. Nunca deixa ver atraves.
  folhagem_recorte  com alfa, para os blocos de fora. O recorte come o canto do
                    bloco e a copa deixa de ter silhueta de caixa — que era a
                    outra metade da queixa.

    python tools/gerar_cidade.py
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "textures"
SAIDA_HD = RAIZ / "game" / "assets" / "textures_hd"
FONTES = Path("C:/Windows/Fonts")

## 256 px, o teto do ART-BIBLE secao 6. A 128 nao cabia folha: com quatro
## repeticoes por face de copa, cada aglomerado ficava com 32 px e virava mancha.
LADO = 256
rng = np.random.default_rng(3307)

## Multiplicador de resolucao, ligado por `--escala=N`.
##
## Com 1 escreve a textura do PS1 em `textures/`, quantizada, como sempre.
## Acima de 1 escreve o conjunto do MODERNO em `textures_hd/`, sem quantizar,
## e REFAZ o desenho maior: o raio de cada aglomerado de folha e a quantidade
## deles acompanham a escala, entao a folha continua com o mesmo tamanho em
## METROS e o que muda e quantos pixels a descrevem. Ampliar a de 256 nao
## acrescentaria detalhe nenhum, so pixel inventado, e o criterio A8 do
## PLANO_AAA_4K mede detalhe por metro.
ESCALA = 1


def destino() -> Path:
    return SAIDA if ESCALA == 1 else SAIDA_HD


def salvar(nome: str, img: Image.Image, cores: int = 64) -> None:
    destino().mkdir(parents=True, exist_ok=True)
    if ESCALA == 1:
        metodo = Image.FASTOCTREE if img.mode == "RGBA" else Image.MEDIANCUT
        img = img.quantize(colors=cores, method=metodo)
    img.save(destino() / f"{nome}.png", "PNG", optimize=True)
    marca = "" if ESCALA == 1 else "  (HD)"
    print(f"{nome:24s} {img.width}x{img.height}  {img.mode}{marca}")


def wrap_colar(base: Image.Image, peca: Image.Image, cx: int, cy: int) -> None:
    """Cola `peca` centrada em (cx, cy), repetindo nas oito copias vizinhas.

    E o unico jeito honesto de por forma reconhecivel numa textura que repete.
    Ruido fecha sozinho; desenho nao fecha, e a emenda aparece como uma linha
    reta no meio da copa."""
    ox = cx - peca.width // 2
    oy = cy - peca.height // 2
    for dx in (-LADO, 0, LADO):
        for dy in (-LADO, 0, LADO):
            base.alpha_composite(peca, (ox + dx, oy + dy))


def fbm(lado: int, oitavas: int = 5, persist: float = 0.55) -> np.ndarray:
    """Ruido fractal que fecha nas bordas."""
    out = np.zeros((lado, lado), dtype=np.float64)
    amp, total = 1.0, 0.0
    for o in range(oitavas):
        res = 2 ** (o + 1)
        if res > lado:
            break
        baixo = rng.random((res, res))
        # Repete a grade antes de ampliar e recorta o miolo: a borda esquerda
        # continua a direita sem emenda.
        grade = np.tile(baixo, (2, 2))
        img = Image.fromarray((grade * 255).astype(np.uint8)).resize(
            (lado * 2, lado * 2), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64)[:lado, :lado] / 255.0 * amp
        total += amp
        amp *= persist
    return out / max(total, 1e-6)


def norm(a: np.ndarray) -> np.ndarray:
    lo, hi = a.min(), a.max()
    return (a - lo) / max(hi - lo, 1e-6)


def rampa(m: np.ndarray, escuro: str, claro: str) -> np.ndarray:
    d = np.array([int(escuro.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    c = np.array([int(claro.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    x = m[..., None]
    return d * (1.0 - x) + c * x


def hexa(c: str) -> tuple[int, int, int]:
    return tuple(int(c.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))


def rgb(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def fonte(arquivo: str, tamanho: int) -> ImageFont.FreeTypeFont:
    caminho = FONTES / arquivo
    if caminho.exists():
        return ImageFont.truetype(str(caminho), tamanho)
    return ImageFont.load_default()


# --- folhagem ---------------------------------------------------------------

## Tres camadas de tom, do fundo para a frente. Sao os tons que dao volume: a
## copa iluminada por cima e escura por dentro, e sem essa ordem ela vira um
## recorte chapado.
CAMADAS_FOLHA = [
    ("#26301c", 130, 13, 26),
    ("#3c4a2a", 110, 10, 21),
    ("#55663a", 90, 8, 17),
    ("#6d7f4a", 55, 6, 13),
]


def _aglomerado(cor: tuple[int, int, int], raio: int) -> Image.Image:
    """Um punhado de folhas: uma elipse maior e tres pequenas em volta.

    Uma elipse sozinha le como bolha. Sao as pequenas encostadas na grande que
    dao o contorno recortado que o olho reconhece como folha."""
    lado = raio * 2 + 8
    peca = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    d = ImageDraw.Draw(peca)
    c = lado / 2
    d.ellipse((c - raio, c - raio * 0.62, c + raio, c + raio * 0.62),
              fill=cor + (255,))
    for _ in range(3):
        a = float(rng.random()) * math.tau
        r = raio * float(rng.uniform(0.34, 0.58))
        px = c + math.cos(a) * raio * 0.72
        py = c + math.sin(a) * raio * 0.48
        d.ellipse((px - r, py - r * 0.7, px + r, py + r * 0.7), fill=cor + (255,))
    return peca.rotate(float(rng.uniform(0, 180)), expand=True,
                       resample=Image.NEAREST)


def _folhas(com_alfa: bool) -> Image.Image:
    fundo = (0, 0, 0, 0) if com_alfa else hexa("#1b2314") + (255,)
    base = Image.new("RGBA", (LADO, LADO), fundo)
    for indice, (cor_hex, n, r0, r1) in enumerate(CAMADAS_FOLHA):
        cor = hexa(cor_hex)
        # A versao recortada pula a camada de fundo e leva menos da metade do
        # resto. Com a camada de fundo ela fechava 92% da area e o recorte nao
        # aparecia — voltava o quadrado que o teste apontou. O alvo e tres
        # quartos: cheio o bastante para nao ver o ceu pelo meio da copa, vazado
        # o bastante para comer o canto do bloco.
        if com_alfa and indice == 0:
            continue
        # A quantidade NAO muda com a escala; so o raio.
        #
        # Escalando os dois, a area coberta cresce com ESCALA^4 contra ESCALA^2
        # da textura: medido, a cobertura do recorte foi de 75% para 100% e a
        # copa deixou de ser vazada — exatamente o defeito que o comentario
        # abaixo existe para evitar. Mesma quantidade de aglomerados, cada um
        # com o mesmo tamanho em METROS, e a textura com quatro vezes mais
        # pixels para descrever cada um.
        quantos = int(n * (0.9 if com_alfa else 1.0))
        for _ in range(quantos):
            raio = int(rng.integers(r0, r1) * ESCALA)
            variacao = int(rng.integers(-14, 15))
            tom = tuple(max(0, min(255, v + variacao)) for v in cor)
            wrap_colar(base, _aglomerado(tom, raio),
                       int(rng.integers(0, LADO)), int(rng.integers(0, LADO)))
    return base


def folhagem() -> None:
    """Massa de folha opaca, para o nucleo da copa."""
    im = _folhas(False)
    arr = np.asarray(im.convert("RGB"), dtype=np.float64)
    # Ruido fino por cima: a folha desenhada sozinha fica limpa demais para uma
    # textura que vai aparecer a dois metros da camera.
    arr += rng.normal(0.0, 5.0, arr.shape)
    # Pontos de luz atravessando a copa.
    # O furo de luz na copa tambem e por area, e nao por pixel.
    limiar = 1.0 - (1.0 - 0.994) / float(ESCALA * ESCALA)
    luz = rng.random((LADO, LADO)) > limiar
    arr[luz] = np.array([146, 158, 106])
    salvar("folhagem", rgb(arr))


def folhagem_recorte() -> None:
    """A mesma folha com alfa, para os blocos de fora da copa.

    A cobertura fica perto de tres quartos. Menos que isso e a copa fica rala e
    da para ver o ceu pelo meio dela; mais e o recorte deixa de aparecer e volta
    o quadrado."""
    im = _folhas(True)
    arr = np.asarray(im, dtype=np.float64)
    arr[..., :3] += rng.normal(0.0, 5.0, arr[..., :3].shape)
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    cobertura = float((np.asarray(im)[..., 3] > 128).mean())
    print(f"{'folhagem_recorte':24s} cobertura {cobertura:.0%}")
    salvar("folhagem_recorte", im, 48)


# --- superficies do parque --------------------------------------------------

def grama() -> None:
    """Capim de madrugada: escuro, com tufos e nenhum verde vivo.

    Verde saturado aqui destruiria a cena inteira. A rua e sodio alaranjado sobre
    cinza; um gramado brilhante puxaria mais o olho que a loja acesa, que e o
    unico ponto de luz que deveria puxar.
    """
    fino = norm(fbm(LADO, 7, 0.78))
    tufos = norm(fbm(LADO, 3, 0.45))
    m = np.clip(fino * 0.62 + tufos * 0.38, 0, 1) * 0.62 + 0.14
    arr = rampa(m, "#232b1c", "#5b6b40")

    # Fios de capim desenhados, curtos e inclinados. Sao eles que fazem a grama
    # parar de ler como feltro quando o jogador olha para baixo.
    fios = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    df = ImageDraw.Draw(fios)
    for _ in range(620):
        x = int(rng.integers(0, LADO))
        y = int(rng.integers(0, LADO))
        h = int(rng.integers(3, 8))
        incl = int(rng.integers(-2, 3))
        # Tom baixo: fio claro demais vira sal grosso espalhado no gramado, que
        # foi o defeito da primeira tentativa.
        tom = int(rng.integers(46, 92))
        df.line([(x, y), (x + incl, y - h)], fill=(tom, tom + 16, tom - 26, 255))
    arr = np.asarray(Image.alpha_composite(
        rgb(arr).convert("RGBA"), fios).convert("RGB"), dtype=np.float64)

    falhas = norm(fbm(LADO, 2, 0.4)) > 0.79
    arr[falhas] = arr[falhas] * 0.55 + np.array([74, 62, 46]) * 0.45
    salvar("grama", rgb(arr))


def casca() -> None:
    """Casca de tronco: sulco vertical, cinza esverdeado."""
    y = np.arange(LADO)[:, None].repeat(LADO, 1)
    x = np.arange(LADO)[None, :].repeat(LADO, 0)
    desloc = (norm(fbm(LADO, 4, 0.6)) * 22.0).astype(np.int32)
    coluna = ((x + desloc) % LADO)
    sulco = np.sin(coluna / LADO * np.pi * 26.0) * 0.5 + 0.5
    fibra = norm(fbm(LADO, 7, 0.72))
    m = np.clip(sulco * 0.42 + fibra * 0.58, 0, 1) * 0.62 + 0.16
    arr = rampa(m, "#2a251d", "#7d7264")
    # Placa de casca solta: uma faixa larga rebaixada, e nao uma linha. A linha
    # fina saia como contorno desenhado e a casca lia como compensado.
    placas = norm(fbm(LADO, 3, 0.5))
    arr *= (0.82 + 0.18 * np.clip((placas - 0.35) * 3.0, 0.0, 1.0))[..., None]
    musgo = (norm(fbm(LADO, 5, 0.6)) > 0.68) & (sulco < 0.35)
    arr[musgo] = arr[musgo] * 0.6 + np.array([62, 78, 52]) * 0.4
    salvar("casca", rgb(arr))


def areia() -> None:
    """Areia batida de quadra, com pedrinha e sulco de pe arrastado."""
    m = np.clip(norm(fbm(LADO, 8, 0.82)) * 0.34 + 0.5, 0, 1)
    arr = rampa(m, "#6f6250", "#b6a486")
    # Sombra larga de pe arrastado. A faixa estreita da primeira versao saia
    # como curva de nivel de mapa topografico.
    sulcos = norm(fbm(LADO, 4, 0.55))
    arr *= (0.9 + 0.1 * np.clip((sulcos - 0.4) * 2.5, 0.0, 1.0))[..., None]
    pedras = rng.random((LADO, LADO)) > 0.994
    arr[pedras] = np.array([148, 140, 126])
    salvar("areia", rgb(arr))


def pedra_parque() -> None:
    """Calcamento de praca: placas irregulares, junta funda e desgaste.

    A versao anterior era uma grade de quatro por quatro com tom sorteado, e
    lida como ladrilho de banheiro. O que faz calcada de praca e a irregularidade
    da placa, a junta escura com sujeira acumulada e o canto lascado — e o tom
    diferente placa a placa, que sugere altura sem custar geometria."""
    im = Image.new("RGB", (LADO, LADO), (58, 56, 50))
    d = ImageDraw.Draw(im)

    # Fileiras de altura variavel, cada uma com placas de largura variavel e
    # deslocamento proprio. Nenhuma junta atravessa a textura inteira.
    y = 0
    fileira = 0
    while y < LADO:
        alt = int(rng.integers(38, 62))
        x = -int(rng.integers(0, 40))
        while x < LADO:
            larg = int(rng.integers(40, 78))
            tom = int(rng.integers(112, 158))
            # Duas placas escuras a cada punhado: e a "altura diferente" lida de
            # cima, onde o que muda com o degrau e a sombra, nao a forma.
            if rng.random() < 0.22:
                tom = int(tom * 0.76)
            cor = (tom, tom - 3, tom - 12)
            for dx in (-LADO, 0, LADO):
                d.rectangle((x + dx + 2, y + 2, x + dx + larg - 2, y + alt - 2),
                            fill=cor)
                # Canto lascado, num canto sorteado da placa.
                if rng.random() < 0.35:
                    cx = x + dx + (2 if rng.random() < 0.5 else larg - 9)
                    cy = y + (2 if rng.random() < 0.5 else alt - 9)
                    d.rectangle((cx, cy, cx + 7, cy + 7), fill=(66, 63, 56))
            x += larg
        y += alt
        fileira += 1

    arr = np.asarray(im, dtype=np.float64)
    # Sujeira de chuva acumulada, e musgo na junta.
    sujeira = norm(fbm(LADO, 5, 0.62))[..., None]
    arr *= 0.7 + sujeira * 0.4
    junta = np.asarray(im, dtype=np.float64).mean(axis=2) < 80
    musgo = junta & (norm(fbm(LADO, 6, 0.7)) > 0.55)
    arr[musgo] = arr[musgo] * 0.7 + np.array([54, 66, 44]) * 0.3
    arr += rng.normal(0.0, 4.0, arr.shape)
    salvar("pedra_parque", rgb(arr))


def agua() -> None:
    """Agua parada de chafariz. Escura, com reflexo quebrado e folha boiando."""
    onda = norm(fbm(LADO, 4, 0.5))
    fino = norm(fbm(LADO, 8, 0.86))
    m = np.clip(onda * 0.7 + fino * 0.3, 0, 1) * 0.5 + 0.12
    arr = rampa(m, "#182028", "#4e6672")
    brilho = (fino > 0.8) & (onda > 0.55)
    arr[brilho] = np.array([132, 152, 160])
    folhas = rng.random((LADO, LADO)) > 0.997
    arr[folhas] = np.array([70, 74, 48])
    salvar("agua", rgb(arr))


# --- imagens ----------------------------------------------------------------

def toldo() -> None:
    """Lona de toldo listrada. A cor vem do vertice; aqui so a listra e o tecido."""
    im = Image.new("RGB", (LADO, LADO), (236, 232, 224))
    d = ImageDraw.Draw(im)
    for i in range(0, LADO, 32):
        d.rectangle((i, 0, i + 15, LADO), fill=(178, 172, 162))
    arr = np.asarray(im, dtype=np.float64)
    trama = norm(fbm(LADO, 8, 0.86))[..., None]
    arr *= 0.86 + trama * 0.24
    queda = np.linspace(1.0, 0.78, LADO)[:, None, None]
    arr *= queda
    salvar("toldo", rgb(arr))


def placa_parque() -> None:
    """Placa de parque: chapa esmaltada escura com moldura clara.

    Sem o nome escrito: o nome muda por parque e vem do gerador. O que a textura
    entrega e o objeto placa — a chapa, a moldura e o desgaste."""
    w, h = 128, 54
    im = Image.new("RGB", (w, h), (38, 56, 44))
    d = ImageDraw.Draw(im)
    d.rectangle((2, 2, w - 3, h - 3), outline=(206, 202, 186), width=2)
    f = fonte("segoeuib.ttf", 15)
    texto = "PARQUE"
    caixa = d.textbbox((0, 0), texto, font=f)
    d.text(((w - caixa[2]) // 2, (h - caixa[3]) // 2 - 2), texto,
           font=f, fill=(224, 220, 204))
    arr = np.asarray(im, dtype=np.float64)
    arr += rng.normal(0.0, 6.0, arr.shape)
    for x in (14, w - 16):
        arr[10:h - 6, x - 1:x + 2] *= 0.62
    salvar("placa_parque", rgb(arr), 32)


def main() -> int:
    global ESCALA, LADO
    for arg in sys.argv[1:]:
        if arg.startswith("--escala="):
            ESCALA = max(1, int(arg.split("=", 1)[1]))
            LADO = 256 * ESCALA
    if ESCALA > 1:
        # So a folhagem por enquanto: das nove, e a unica que cobre area
        # grande da cidade (627 m2 medidos por tests/medir_texel.gd,
        # contra 13 da casca e 3 da maquina de venda). As outras tem
        # constante de desenho propria e escalariam uma a uma, sem ganho
        # que pague o risco de mexer na arte.
        folhagem()
        folhagem_recorte()
        print("\n2 texturas de folhagem no conjunto HD")
        return 0
    grama()
    folhagem()
    folhagem_recorte()
    casca()
    areia()
    pedra_parque()
    agua()
    toldo()
    placa_parque()
    print("\n9 texturas de cidade e parque")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

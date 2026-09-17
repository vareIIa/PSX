#!/usr/bin/env python3
"""Texturas dos decalques de rua do MODERNO: oleo, pichacao e sujeira.

    python tools/gerar_decalques.py
    godot --headless --path game --import
    python tools/importar_hd.py
    godot --headless --path game --import      (de novo: mipmap e compressao)

Criterio A17 do PLANO_AAA_4K. Quem usa: `src/world/decalques_rua.gd`.

Por que um script, e nao textura gerada no jogo
-----------------------------------------------
As pocas geram a textura no `_ready`, e aquilo ja custou um engasgo medido (ver
o comentario de `N_TEX` em `pocas.gd`): 64 px e o teto do que o GDScript
desenha sem soluco. Uma pichacao precisa de 512 px para a tinta ter borda de
spray e escorrido — oito vezes o trabalho. Aqui ela nasce uma vez, em disco,
e o jogo so carrega.

E a semente e fixa: a mesma pichacao na mesma parede em toda maquina.

O que cada familia desenha
--------------------------
- **oleo**: mancha escura irregular, com a pelicula de arco-iris na borda — e
  ela que diz "oleo" e nao "sombra" quando a rua esta molhada.
- **pichacao**: dois ou tres tracos grossos de spray, contorno de outra cor,
  respingo em volta e escorrido para BAIXO (a textura e projetada com o v
  crescendo para o chao).
- **sujeira**: encardido que sobe do pe da parede e riscos de agua que descem
  do alto, os dois marrom-acinzentados.

A rugosidade de cada familia vai num `_orm` proprio (R oclusao, G rugosidade,
B metal), no formato que o `Decal` do Godot le.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
DIR = RAIZ / "game" / "assets" / "textures_hd"
SEMENTE = 20260916

# Tinta de spray que se ve em muro de cidade: saturada, poucas cores.
TINTAS = [
    (206, 36, 40),    # vermelho
    (22, 22, 26),     # preto
    (232, 228, 214),  # branco sujo
    (34, 92, 190),    # azul
    (236, 186, 30),   # amarelo
    (40, 150, 70),    # verde
    (214, 70, 160),   # rosa
]


def _ruido(lado_x, lado_y, escala, rng):
    """Ruido de valor suave: grade aleatoria ampliada com interpolacao."""
    gx = max(2, int(lado_x / escala) + 2)
    gy = max(2, int(lado_y / escala) + 2)
    grade = rng.random((gy, gx)).astype(np.float32)
    img = Image.fromarray((grade * 255).astype(np.uint8))
    img = img.resize((lado_x, lado_y), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


def _fbm(lado_x, lado_y, rng, escala=64.0, oitavas=4):
    soma = np.zeros((lado_y, lado_x), np.float32)
    peso = 0.5
    total = 0.0
    for _ in range(oitavas):
        soma += _ruido(lado_x, lado_y, escala, rng) * peso
        total += peso
        escala /= 2.0
        peso *= 0.5
    return soma / total


def _salvar(nome, rgba):
    img = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")
    img.save(DIR / nome)
    print(f"  {nome} {img.width}x{img.height}")


def _orm(nome, rugosidade_alfa, rug_dentro, rug_fora):
    """ORM do decal: G e a rugosidade, o alfa diz onde o decal escreve."""
    lado_y, lado_x = rugosidade_alfa.shape
    rgba = np.zeros((lado_y, lado_x, 4), np.float32)
    rgba[..., 0] = 255.0
    rgba[..., 1] = (rug_fora + (rug_dentro - rug_fora) * rugosidade_alfa) * 255.0
    rgba[..., 2] = 0.0
    rgba[..., 3] = rugosidade_alfa * 255.0
    _salvar(nome, rgba)


# ------------------------------------------------------------------- oleo

def oleo(nome, rng):
    n = 256
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = n / 2 + rng.uniform(-12, 12)
    cy = n / 2 + rng.uniform(-12, 12)
    # Forma: uma poca principal e tres ou quatro respingos colados, cada um uma
    # elipse torta. Soma de campos, e nao uniao de circulos, para as bordas se
    # fundirem como liquido.
    campo = np.zeros((n, n), np.float32)
    for i in range(rng.integers(4, 7)):
        principal = i == 0
        ox = cx + (0.0 if principal else rng.uniform(-62, 62))
        oy = cy + (0.0 if principal else rng.uniform(-62, 62))
        rx = rng.uniform(70, 100) if principal else rng.uniform(26, 48)
        ry = rx * rng.uniform(0.55, 0.95)
        ang = rng.uniform(0, math.pi)
        dx = (x - ox) * math.cos(ang) + (y - oy) * math.sin(ang)
        dy = -(x - ox) * math.sin(ang) + (y - oy) * math.cos(ang)
        campo += np.exp(-((dx / rx) ** 2 + (dy / ry) ** 2) * 2.0)
    campo += (_fbm(n, n, rng, 40.0) - 0.5) * 0.6
    # Oleo e fino na borda e grosso no meio: a borda e quase transparente e o
    # miolo escurece. Uma mancha de alfa chapado le como BURACO no asfalto —
    # foi o que a primeira folha de conferencia mostrou.
    espessura = np.clip((campo - 0.28) / 0.9, 0.0, 1.0)
    alfa = np.clip(espessura * 1.6, 0.0, 1.0) * (0.35 + 0.45 * espessura)

    # Pelicula de arco-iris onde o oleo e FINO — e la que a interferencia
    # aparece numa rua molhada. O matiz corre com a espessura.
    fino = np.clip(1.0 - np.abs(espessura - 0.18) / 0.16, 0.0, 1.0)
    matiz = (espessura * 4.0 + _fbm(n, n, rng, 24.0) * 1.5) % 1.0
    film = np.stack([
        0.5 + 0.5 * np.cos(2 * math.pi * (matiz + 0.0)),
        0.5 + 0.5 * np.cos(2 * math.pi * (matiz + 0.33)),
        0.5 + 0.5 * np.cos(2 * math.pi * (matiz + 0.67)),
    ], axis=-1)
    base = np.array([20.0, 17.0, 14.0], np.float32)
    cor = base + film * fino[..., None] * 95.0
    rgba = np.zeros((n, n, 4), np.float32)
    rgba[..., :3] = cor
    rgba[..., 3] = np.maximum(alfa, fino * 0.45) * 255.0
    _salvar(nome + ".png", rgba)
    # Oleo e LISO: e ele que faz o asfalto molhado brilhar diferente ali.
    _orm(nome + "_orm.png", np.clip(espessura * 2.0, 0.0, 1.0), 0.12, 0.8)


# --------------------------------------------------------------- pichacao

def _curva(pontos, passos=40):
    """Catmull-Rom pelos pontos de controle."""
    saida = []
    p = [pontos[0]] + pontos + [pontos[-1]]
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(passos):
            t = k / passos
            t2, t3 = t * t, t * t * t
            saida.append(tuple(
                0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t
                       + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                       + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)
                for j in range(2)))
    saida.append(pontos[-1])
    return saida


def pichacao(nome, rng):
    w, h = 512, 256
    tinta = TINTAS[rng.integers(len(TINTAS))]
    contorno = TINTAS[rng.integers(len(TINTAS))]
    while contorno == tinta:
        contorno = TINTAS[rng.integers(len(TINTAS))]

    # Tracos: dois ou tres gestos da esquerda para a direita, cada um uma curva
    # que sobe e desce como letra cursiva. E o que um "tag" e: assinatura rapida.
    tracos = []
    for i in range(rng.integers(2, 4)):
        y0 = h * rng.uniform(0.3, 0.7)
        xs = np.linspace(w * rng.uniform(0.06, 0.2), w * rng.uniform(0.8, 0.94),
                         rng.integers(5, 9))
        pts = [(float(xx), float(y0 + rng.uniform(-60, 60))) for xx in xs]
        tracos.append(_curva(pts, 24))

    def pintar(largura, cor):
        camada = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(camada)
        for t in tracos:
            d.line(t, fill=255, width=largura, joint="curve")
            for (px, py) in t[::6]:
                r = largura / 2
                d.ellipse((px - r, py - r, px + r, py + r), fill=255)
        return camada

    grosso = int(rng.uniform(16, 26))
    fora = pintar(grosso + 12, contorno).filter(ImageFilter.GaussianBlur(2.2))
    dentro = pintar(grosso, tinta).filter(ImageFilter.GaussianBlur(1.4))

    # Escorrido: a tinta de spray em excesso desce. Poucos, finos, longos.
    escorre = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(escorre)
    for t in tracos:
        for (px, py) in t[:: rng.integers(18, 30)]:
            if rng.random() < 0.55:
                comp = rng.uniform(18, 70)
                d.line((px, py, px + rng.uniform(-1.5, 1.5), py + comp),
                       fill=200, width=int(rng.uniform(2, 4)))
    escorre = escorre.filter(ImageFilter.GaussianBlur(0.8))

    # Respingo: o bico do spray solta gotas em volta do traco.
    respingo = np.zeros((h, w), np.float32)
    for t in tracos:
        for (px, py) in t[::3]:
            for _ in range(3):
                ex = int(px + rng.normal(0, grosso * 0.9))
                ey = int(py + rng.normal(0, grosso * 0.9))
                if 0 <= ex < w and 0 <= ey < h:
                    respingo[ey, ex] = rng.uniform(0.3, 0.8)

    a_fora = np.asarray(fora).astype(np.float32) / 255.0
    a_dentro = np.maximum(np.asarray(dentro).astype(np.float32) / 255.0,
                          np.asarray(escorre).astype(np.float32) / 255.0)
    # Tinta velha: falhada onde o muro e aspero.
    falha = np.clip((_fbm(w, h, rng, 40.0) - 0.28) * 2.2, 0.0, 1.0)
    a_dentro *= 0.55 + 0.45 * falha
    a_fora *= 0.55 + 0.45 * falha

    cor = np.zeros((h, w, 3), np.float32)
    cor[:] = contorno
    mistura = np.clip(a_dentro * 1.4, 0.0, 1.0)[..., None]
    cor = cor * (1.0 - mistura) + np.array(tinta, np.float32) * mistura
    alfa = np.clip(np.maximum(a_fora, a_dentro) + respingo * 0.6, 0.0, 1.0)

    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., :3] = cor
    rgba[..., 3] = alfa * 245.0
    _salvar(nome + ".png", rgba)
    # Tinta acrilica fecha o poro do reboco: um pouco mais lisa que o muro.
    _orm(nome + "_orm.png", alfa, 0.55, 0.9)


# ---------------------------------------------------------------- sujeira

def sujeira(nome, rng):
    w, h = 256, 256
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    v = y / (h - 1)                      # 0 no alto, 1 no chao
    # Encardido do pe: respingo de chuva e poeira de rua, subindo meio metro.
    pe = np.clip((v - 0.45) / 0.55, 0.0, 1.0) ** 1.6
    pe *= 0.55 + 0.45 * _fbm(w, h, rng, 36.0)
    # Riscos de agua: descem do alto em colunas finas e somem no meio.
    riscos = np.zeros((h, w), np.float32)
    for _ in range(rng.integers(5, 10)):
        cx = rng.uniform(10, w - 10)
        largura = rng.uniform(3, 9)
        fim = rng.uniform(0.35, 0.85)
        col = np.exp(-((x - cx) / largura) ** 2)
        riscos += col * np.clip(1.0 - v / fim, 0.0, 1.0) * rng.uniform(0.3, 0.7)
    riscos *= 0.6 + 0.4 * _fbm(w, h, rng, 20.0)
    # Bordas laterais somem: a mancha nao pode terminar numa linha vertical.
    lado = np.clip(np.minimum(x, w - 1 - x) / 40.0, 0.0, 1.0)
    alfa = np.clip(pe + riscos, 0.0, 1.0) * lado

    cor = np.zeros((h, w, 3), np.float32)
    cor[:] = (58, 50, 40)
    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., :3] = cor
    rgba[..., 3] = alfa * 200.0
    _salvar(nome + ".png", rgba)
    _orm(nome + "_orm.png", alfa, 0.95, 0.9)


# ---------------------------------------------------------- sujeira de lente

def _salvar_hdr(caminho, rgb):
    """Radiance RGBE com RLE por canal, sem repeticoes (so trechos literais).

    HDR e nao PNG porque o mapa passa de 1,0: a poeira ACENDE o glow. PNG corta
    em 1,0, e a versao anterior, uma `ImageTexture` RGB8, cortava igual e em
    silencio — a poeira que o codigo pedia nunca existiu.
    """
    altura, largura, _ = rgb.shape
    v = rgb.max(axis=2)
    m, e = np.frexp(v)
    escala = np.where(v > 1e-32, m * 256.0 / np.maximum(v, 1e-32), 0.0)
    rgbe = np.zeros((altura, largura, 4), np.uint8)
    for c in range(3):
        rgbe[..., c] = np.clip(rgb[..., c] * escala, 0, 255).astype(np.uint8)
    rgbe[..., 3] = np.where(v > 1e-32, e + 128, 0).astype(np.uint8)
    saida = bytearray()
    saida += b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n"
    saida += f"-Y {altura} +X {largura}\n".encode()
    for y in range(altura):
        saida += bytes([2, 2, (largura >> 8) & 0xFF, largura & 0xFF])
        for c in range(4):
            canal = rgbe[y, :, c].tobytes()
            i = 0
            while i < largura:
                n = min(128, largura - i)
                saida += bytes([n]) + canal[i:i + n]
                i += n
    Path(caminho).write_bytes(bytes(saida))


def sujeira_de_lente(nome, rng):
    """O vidro sujo da camera: multiplica o glow (Environment.glow_map).

    Neutro e 1,0. Tres familias de marca: gordura (veu largo e fraco que come
    luz), poeira (pontos que ESPALHAM, e por isso passam de 1) e riscos (o vidro
    tem direcao, e e o risco que alonga a estrela do farol).

    A primeira versao era gerada no `_ready` da lente, com `set_pixel`: quase
    trezentas mil chamadas de GDScript no primeiro quadro. Aqui ela custa zero.
    """
    n = 256
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    campo = np.ones((n, n), np.float32)

    def borrao(cx, cy, r, forca):
        d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
        return np.clip(1.0 - d, 0.0, 1.0) ** 2 * forca

    # Gordura: veu LARGO e fraco. Discos pequenos e fortes viraram bolhas no
    # ceu noturno, porque a noite o glow cobre o quadro inteiro.
    for _ in range(6):
        campo -= borrao(rng.uniform(0, n), rng.uniform(0, n),
                        rng.uniform(60, 110), rng.uniform(0.04, 0.09))
    for _ in range(220):
        campo += borrao(rng.uniform(0, n), rng.uniform(0, n),
                        rng.uniform(1.2, 4.0), rng.uniform(0.25, 0.9))
    for _ in range(6):
        a = rng.uniform(0, 2 * math.pi)
        px, py = rng.uniform(0, n), rng.uniform(0, n)
        comp = rng.uniform(30, 110)
        t = 0.0
        while t < comp:
            campo += borrao(px + math.cos(a) * t, py + math.sin(a) * t,
                            rng.uniform(1.0, 2.2), 0.35)
            t += 1.5
    campo = np.clip(campo, 0.0, 2.0)
    rgb = np.repeat(campo[..., None], 3, axis=2)
    _salvar_hdr(DIR / (nome + ".hdr"), rgb)
    print(f"  {nome}.hdr {n}x{n} (neutro 1,0; de {campo.min():.2f} a {campo.max():.2f})")


def main() -> int:
    if not DIR.is_dir():
        print(f"{DIR} nao existe; rode tools/texturas_hd.py antes")
        return 1
    rng = np.random.default_rng(SEMENTE)
    print("oleo:")
    for s in "ab":
        oleo(f"decalque_oleo_{s}", rng)
    print("pichacao:")
    for s in "abcd":
        pichacao(f"decalque_pichacao_{s}", rng)
    print("sujeira:")
    for s in "ab":
        sujeira(f"decalque_sujeira_{s}", rng)
    print("lente:")
    sujeira_de_lente("lente_sujeira", np.random.default_rng(SEMENTE + 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())

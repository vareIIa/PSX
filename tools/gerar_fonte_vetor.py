#!/usr/bin/env python3
"""A mesma letra de bitmap, vetorizada pelo contorno dos pixels (PLANO_AAA_4K, A28).

    python tools/gerar_fonte_vetor.py
    godot --headless --path game --import
    python tools/gerar_fonte_vetor.py --importar   (liga o MSDF no .import)
    godot --headless --path game --import

Por que esta fonte existe
-------------------------
O HUD e desenhado numa caixa de 480x270 e multiplicado ate a janela. O atlas da
fonte e magnificado com filtro linear, entao no MODERNO o texto nao tem UM pixel
com a cor do texto: medido em `tests/bancada_fonte.gd`, uma haste de 1 px da
`psx_pequena` sai como um monte de 8 px com pico 0,87 em 1080p. Em 480x270 isso
nunca apareceu porque la a escala e 1.

O conserto NAO e trocar o filtro para ponto: com ponto, a mesma haste sai com
2 px numa letra e 3 na seguinte quando a escala e quebrada (1280x720 da 2,667) —
a queixa que ja estava escrita no `estilo_visual.gd`. O conserto e a letra virar
CONTORNO, e o motor resolver a borda na resolucao da tela (MSDF). Ai a haste tem
sempre 2,667 px, com um pixel de meio-tom de cada lado, em qualquer escala.

Por que vetorizar o bitmap em vez de usar a Arial de novo
---------------------------------------------------------
Porque a metrica tem de ser IDENTICA. Todo painel deste jogo tem `Vector2`
escrito a mao em cima de larguras medidas com `UiEstilo.largura`. A Arial
dinamica em 11 px nao da os mesmos avancos que a Arial limiarizada em 11 px
(o `gerar_fonte.py` arredonda cada avanco para inteiro) — e uma fonte que ande
1 px por palavra arruma o texto e desarruma a tela inteira.

Vetorizando o PROPRIO bitmap, o avanco e o mesmo inteiro, a altura de linha e a
mesma, e o desenho e o mesmo — so que agora com borda resolvida. O PS1 STYLE
continua com o .fnt de sempre; quem troca e o `EstiloVisual`, so no MODERNO.

Como o contorno sai do pixel
----------------------------
Marcha de aresta: toda aresta de pixel aceso que faz divisa com pixel apagado
entra num grafo, sempre no mesmo sentido de giro, e as arestas se encadeiam em
lacos fechados. Buraco (o miolo do O) sai com giro contrario sozinho, que e o
que a regra de preenchimento nao-nulo do TrueType espera. Ponto colinear e
descartado no fim: um M de 8x8 vira 20 pontos em vez de 60.

A unidade e 64 por pixel, e a em tem `tamanho * 64` unidades. Assim todo ponto e
inteiro, sem arredondamento pelo caminho, e pedir a fonte no tamanho nativo da
exatamente 1 px por pixel do desenho original.
"""

import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
DIR = RAIZ / "game" / "assets" / "fontes"
FONTES = ["psx_pequena", "psx_media", "psx_titulo", "psx_mono"]

## Unidades de fonte por pixel do desenho. 64 e o denominador que o FreeType ja
## usa por dentro; com ele todo ponto sai inteiro.
UNIDADE = 64

## Ajuste do gerador de MSDF. `msdf_size` e o tamanho em que o campo de
## distancia e desenhado, e `msdf_pixel_range` o alcance da distancia guardada.
##
## Perto de 128, e nao dos padroes 48 e 8, por causa da haste de 1 px: numa em de
## 18 px desenhada em 48, a haste tem 2,7 px e o alcance de 8 px atravessa a
## haste inteira — os dois lados brigam pelo mesmo pixel e a letra derrete. Em
## 128 a mesma haste tem 7,1 px e o alcance de 4 cabe com folga dos dois lados.
##
## MULTIPLO do tamanho nativo, e nao 128 cravado: o motor mede o avanco no
## tamanho do campo e reescala para o tamanho pedido. Com 128 sobre uma em de 11,
## cada avanco volta com 0,016 px a mais, e a frase inteira sai 1 px mais larga
## que a mesma frase no .fnt. Com 132 (12 x 11) a volta e exata.
MSDF_ALVO = 128
MSDF_ALCANCE = 4


def msdf_tamanho(nativo: int) -> int:
    return max(1, int(round(MSDF_ALVO / float(nativo)))) * nativo


def ler_fnt(caminho: Path) -> dict:
    """Le o .fnt do AngelCode que o `gerar_fonte.py` escreve."""
    dados = {"chars": [], "size": 0, "base": 0, "lineHeight": 0}
    for linha in caminho.read_text(encoding="utf-8").splitlines():
        campos = dict(re.findall(r"(\w+)=(-?\d+)", linha))
        if linha.startswith("info "):
            dados["size"] = int(campos["size"])
        elif linha.startswith("common "):
            dados["base"] = int(campos["base"])
            dados["lineHeight"] = int(campos["lineHeight"])
        elif linha.startswith("char "):
            dados["chars"].append({k: int(v) for k, v in campos.items()})
    return dados


def lacos(ink: np.ndarray) -> list:
    """Contornos fechados do conjunto de pixels acesos, em coordenadas de grade.

    Sentido: horario com o y para BAIXO (o da imagem), que vira anti-horario
    quando o y e invertido para o y-para-cima da fonte. Buraco sai ao contrario
    por construcao, porque a divisa dele e percorrida do outro lado.
    """
    alt, larg = ink.shape
    arestas = {}

    def por(a, b):
        arestas.setdefault(a, []).append(b)

    for y in range(alt):
        for x in range(larg):
            if not ink[y, x]:
                continue
            if y == 0 or not ink[y - 1, x]:
                por((x, y), (x + 1, y))
            if x + 1 >= larg or not ink[y, x + 1]:
                por((x + 1, y), (x + 1, y + 1))
            if y + 1 >= alt or not ink[y + 1, x]:
                por((x + 1, y + 1), (x, y + 1))
            if x == 0 or not ink[y, x - 1]:
                por((x, y + 1), (x, y))

    saida = []
    while arestas:
        inicio = next(iter(arestas))
        laco = [inicio]
        atual = inicio
        while True:
            seguintes = arestas.get(atual)
            if not seguintes:
                break
            prox = seguintes.pop()
            if not seguintes:
                del arestas[atual]
            if prox == inicio:
                break
            laco.append(prox)
            atual = prox
        if len(laco) >= 3:
            saida.append(laco)
    return saida


def sem_colinear(laco: list) -> list:
    """Tira o ponto do meio de todo trecho reto."""
    n = len(laco)
    saida = []
    for i in range(n):
        a = laco[i - 1]
        b = laco[i]
        c = laco[(i + 1) % n]
        if (b[0] - a[0]) * (c[1] - b[1]) != (b[1] - a[1]) * (c[0] - b[0]):
            saida.append(b)
    return saida if len(saida) >= 3 else laco


def contornos(ink: np.ndarray, ox: int, oy: int, base: int) -> list:
    """Contornos em unidades de fonte, y para cima e origem na linha de base."""
    saida = []
    for laco in lacos(ink):
        laco = sem_colinear(laco)
        # Inverte o y e, com ele, o sentido de giro — TrueType quer o contorno
        # de fora no horario com o y para cima. Por isso o `reversed`.
        pontos = [((ox + px) * UNIDADE, (base - oy - py) * UNIDADE)
                  for px, py in laco]
        saida.append(list(reversed(pontos)))
    return saida


def construir(nome: str) -> int:
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen

    fnt = ler_fnt(DIR / (nome + ".fnt"))
    atlas = np.asarray(Image.open(DIR / (nome + ".png")).convert("RGBA"))
    alfa = atlas[:, :, 3] > 127

    tamanho = fnt["size"]
    base = fnt["base"]
    em = tamanho * UNIDADE

    ordem = [".notdef"]
    glifos = {}
    avancos = {}
    mapa = {}
    pen = TTGlyphPen(None)
    glifos[".notdef"] = pen.glyph()
    avancos[".notdef"] = (tamanho * UNIDADE // 2, 0)

    for c in fnt["chars"]:
        ponto = c["id"]
        gnome = "uni%04X" % ponto
        if gnome in glifos:
            continue
        recorte = alfa[c["y"]:c["y"] + c["height"], c["x"]:c["x"] + c["width"]]
        pen = TTGlyphPen(None)
        esquerda = 0
        if recorte.any():
            cs = contornos(recorte, c["xoffset"], c["yoffset"], base)
            for laco in cs:
                pen.moveTo(laco[0])
                for p in laco[1:]:
                    pen.lineTo(p)
                pen.closePath()
            esquerda = min(p[0] for laco in cs for p in laco)
        ordem.append(gnome)
        glifos[gnome] = pen.glyph()
        avancos[gnome] = (c["xadvance"] * UNIDADE, esquerda)
        mapa[ponto] = gnome

    subida = base * UNIDADE
    descida = (fnt["lineHeight"] - base) * UNIDADE

    fb = FontBuilder(em, isTTF=True)
    fb.setupGlyphOrder(ordem)
    fb.setupCharacterMap(mapa)
    fb.setupGlyf(glifos)
    fb.setupHorizontalMetrics(avancos)
    fb.setupHorizontalHeader(ascent=subida, descent=-descida, lineGap=0)
    fb.setupNameTable({
        "familyName": nome + " vetor",
        "styleName": "Regular",
        "psName": nome + "Vetor",
        "version": "1.0",
    })
    fb.setupOS2(sTypoAscender=subida, sTypoDescender=-descida, sTypoLineGap=0,
                usWinAscent=subida, usWinDescent=descida,
                sCapHeight=subida, achVendID="PSX ")
    fb.setupPost(keepGlyphNames=False)
    fb.font["head"].unitsPerEm = em
    fb.save(str(DIR / (nome + "_v.ttf")))
    return len(mapa)


## O Godot escreve o .import com os padroes na primeira importacao; este passo
## troca os tres campos que importam e deixa o resto como o motor pos.
##
## `hinting=0` porque o hinting mexe no contorno para encaixar na grade de
## pixel — que e exatamente o oposto do que se quer aqui: o contorno JA e a
## grade de pixel, e qualquer ajuste o tira do lugar.
IMPORTACAO = {
    "multichannel_signed_distance_field": "true",
    "msdf_pixel_range": str(MSDF_ALCANCE),
    "hinting": "0",
    "force_autohinter": "false",
    "generate_mipmaps": "false",
    # Avanco em pixel inteiro, como no bitmap. Com posicionamento por subpixel
    # ligado, o avanco de cada glifo vira fracao e a frase inteira anda 1 px em
    # relacao a mesma frase no .fnt — e a medida de largura que todo painel usa
    # deixaria de bater.
    "subpixel_positioning": "0",
    "keep_rounding_remainders": "false",
}


def ligar_msdf() -> int:
    mexidos = 0
    for nome in FONTES:
        p = DIR / (nome + "_v.ttf.import")
        if not p.exists():
            print("sem .import para %s: rode o --import do Godot antes" % nome,
                  file=sys.stderr)
            return 1
        texto = p.read_text(encoding="utf-8")
        nativo = ler_fnt(DIR / (nome + ".fnt"))["size"]
        campos = dict(IMPORTACAO, msdf_size=str(msdf_tamanho(nativo)))
        for chave, valor in campos.items():
            novo, n = re.subn(r"(?m)^%s=.*$" % chave, "%s=%s" % (chave, valor), texto)
            if n == 0:
                novo = texto.rstrip("\n") + "\n%s=%s\n" % (chave, valor)
            texto = novo
        p.write_text(texto, encoding="utf-8", newline="\n")
        mexidos += 1
    print("MSDF ligado em %d .import (alcance %d, tamanho %s)"
          % (mexidos, MSDF_ALCANCE,
             ", ".join("%s %d" % (n, msdf_tamanho(ler_fnt(DIR / (n + ".fnt"))["size"]))
                       for n in FONTES)))
    print("Agora: godot --headless --path game --import")
    return 0


def main() -> int:
    if "--importar" in sys.argv[1:]:
        return ligar_msdf()
    for nome in FONTES:
        if not (DIR / (nome + ".fnt")).exists():
            print("%-14s sem .fnt" % nome, file=sys.stderr)
            continue
        n = construir(nome)
        tam = (DIR / (nome + "_v.ttf")).stat().st_size
        print("%-14s %3d glifos  %5.1f KB  -> %s_v.ttf" % (nome, n, tam / 1024.0, nome))
    print("\nAgora: godot --headless --path game --import, "
          "python tools/gerar_fonte_vetor.py --importar, e --import de novo")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

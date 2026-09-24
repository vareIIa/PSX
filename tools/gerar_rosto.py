#!/usr/bin/env python3
"""Folha de rosto: boca, sobrancelha e olhos de cada cara em cada estado.

O rosto do jogo e UMA celula de 32 px pintada na frente da cabeca-caixa. Para a
boca mexer na fala e a cara ter expressao sem trocar a cabeca (ela continua
caixa: memoria "cabeca-caixa-e-estilo"), cada pedaco que mexe ganha um recorte
pequeno, colado por cima da cara no mesmo lugar, com o desenho do estado novo —
o mesmo truque da palpebra, e o do Metal Gear Solid no PS1.

Por que o gerador e nao um sobreposto generico
-----------------------------------------------
As caras da rua sao sorteadas: olho em y 13-15, boca de 4 a 6 px, batom ou nao,
barba por fazer (`gerar_npc.rosto`). Um desenho de boca aberta generico cairia no
lugar errado e na cor errada em metade delas. Aqui cada recorte sai da PROPRIA
cara: o gerador desenha a cara duas vezes, com e sem o pedaco (`PULAR`), e a
diferenca diz onde o pedaco esta e de que cor ele e. O estado novo e desenhado
em cima da cara SEM o pedaco, com as cores dele.

Estados (o neutro e a propria cara e nao entra na folha)
---------------------------------------------------------
    boca:          ENTREABERTA ABERTA REDONDA SORRISO TRISTE CERRADA
    sobrancelha:   ERGUIDA FRANZIDA CAIDA            (cada lado a parte)
    olho:          FECHADO SEMICERRADO ARREGALADO OLHA_ESQ OLHA_DIR

Saida
-----
    game/assets/textures/rosto_atlas.png      256x256, blocos de 128x13 por cara
    game/assets/textures_hd/rosto_atlas.png   o mesmo em 4x (Scale2x duas vezes)
    game/src/systems/rosto_meta.gd            onde cada recorte fica na cara e
                                              na folha (gerado, nao editar)

    python tools/gerar_rosto.py
"""

from collections import Counter
from pathlib import Path

from PIL import Image

import gerar_npc
import gerar_npc_criacao
import gerar_npc_hd

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "game" / "assets" / "textures" / "rosto_atlas.png"
DESTINO_HD = RAIZ / "game" / "assets" / "textures_hd" / "rosto_atlas.png"
META = RAIZ / "game" / "src" / "systems" / "rosto_meta.gd"

LADO_ATLAS = 256
BLOCO = (128, 13)

BOCAS = ["ENTREABERTA", "ABERTA", "REDONDA", "SORRISO", "TRISTE", "CERRADA"]
SOBRANCELHAS = ["ERGUIDA", "FRANZIDA", "CAIDA"]
OLHOS = ["FECHADO", "SEMICERRADO", "ARREGALADO", "OLHA_ESQ", "OLHA_DIR"]

# Tamanho de cada recorte, em pixels da celula.
TAM_BOCA = (10, 7)
TAM_SOBR = (10, 5)
TAM_OLHO = (10, 6)

INTERIOR = (64, 30, 30, 255)
BRANCO = (246, 242, 236, 255)


# --- as caras -----------------------------------------------------------------

def caras():
    """(chave, funcao) de cada uma das 34 caras. A chave e a celula do atlas de
    gente (coluna, linha), que e como o Corpo acha a cara que usa."""
    saida = []
    for i in range(8):
        saida.append(((i, gerar_npc.LINHA_ROSTO_M), lambda i=i: gerar_npc.rosto(i, False)))
        saida.append(((i, gerar_npc.LINHA_ROSTO_F), lambda i=i: gerar_npc.rosto(i, True)))
        saida.append(((i, gerar_npc_criacao.LINHA_ESTUDIO_M),
                      lambda i=i: gerar_npc_criacao.rosto_estudio(i, False)))
        saida.append(((i, gerar_npc_criacao.LINHA_ESTUDIO_F),
                      lambda i=i: gerar_npc_criacao.rosto_estudio(i, True)))
    saida.append(((gerar_npc.ELENCO_ROSTO_HELMER, gerar_npc.LINHA_ELENCO), gerar_npc.rosto_helmer))
    saida.append(((gerar_npc.ELENCO_ROSTO_JOTA, gerar_npc.LINHA_ELENCO), gerar_npc.rosto_jota))
    return saida


def desenhar(funcao, pular: set) -> Image.Image:
    gerar_npc.PULAR = set(pular)
    gerar_npc_criacao.PULAR = set(pular)
    try:
        return funcao().convert("RGBA")
    finally:
        gerar_npc.PULAR = set()
        gerar_npc_criacao.PULAR = set()


def mascara(cheia: Image.Image, sem: Image.Image) -> dict:
    """Pixels que o pedaco pintou: {(x, y): cor}."""
    a, b = cheia.load(), sem.load()
    saida = {}
    for y in range(32):
        for x in range(32):
            if a[x, y] != b[x, y]:
                saida[(x, y)] = a[x, y]
    return saida


def lado(px: dict, esquerdo: bool) -> dict:
    return {p: c for p, c in px.items() if (p[0] < 16) == esquerdo}


def caixa(px: dict):
    xs = [p[0] for p in px]
    ys = [p[1] for p in px]
    return min(xs), min(ys), max(xs), max(ys)


def recorte(sem: Image.Image, cx: int, y0: int, tam) -> tuple:
    """Origem (x, y) do recorte de tamanho `tam` centrado em `cx`, dentro da
    celula, e a imagem da cara SEM o pedaco naquela janela."""
    x0 = max(0, min(32 - tam[0], cx - tam[0] // 2))
    y0 = max(0, min(32 - tam[1], y0))
    return (x0, y0), sem.crop((x0, y0, x0 + tam[0], y0 + tam[1]))


def pintar(img: Image.Image, origem, pixels: dict) -> None:
    """Pinta pixels da celula (coordenada da cara) na janela `img`."""
    im = img.load()
    w, h = img.size
    for (x, y), c in pixels.items():
        lx, ly = x - origem[0], y - origem[1]
        if 0 <= lx < w and 0 <= ly < h:
            im[lx, ly] = c


def escuro(c, k=0.72):
    return (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)


# --- boca -----------------------------------------------------------------------

def bocas(cheia, sem, px):
    x0, y0, x1, y1 = caixa(px)
    cx = (x0 + x1 + 1) // 2
    origem, fundo = recorte(sem, cx, y0 - 2, TAM_BOCA)
    linhas = sorted({p[1] for p in px})
    # A linha principal e a de mais pixels: e o labio de cima nas caras de
    # estudio e a boca inteira nas da rua.
    por_linha = Counter(p[1] for p in px)
    principal = max(por_linha, key=lambda y: (por_linha[y], -y))
    cor_sup = Counter(c for p, c in px.items() if p[1] == principal).most_common(1)[0][0]
    abaixo = [y for y in linhas if y > principal]
    cor_inf = Counter(c for p, c in px.items() if p[1] == (abaixo[0] if abaixo else principal)).most_common(1)[0][0]
    xa = min(p[0] for p in px if p[1] == principal)
    xb = max(p[0] for p in px if p[1] == principal)

    def base():
        return fundo.copy()

    def abrir(folga: int):
        img = base()
        # Tudo acima da linha principal (inclusive) fica; o resto desce `folga`.
        de_cima = {p: c for p, c in px.items() if p[1] <= principal}
        de_baixo = {(p[0], p[1] + folga): c for p, c in px.items() if p[1] > principal}
        pintar(img, origem, de_cima)
        interior = {(x, principal + 1 + k): INTERIOR
                    for k in range(folga) for x in range(xa + 1, xb)}
        pintar(img, origem, interior)
        if not de_baixo:
            # Boca de um risco so (rua): o labio de baixo nasce da cor dele.
            de_baixo = {(x, principal + folga + 1): cor_inf for x in range(xa + 1, xb)}
        pintar(img, origem, de_baixo)
        return img

    saida = {}
    saida["ENTREABERTA"] = abrir(1)
    saida["ABERTA"] = abrir(2)
    # Redonda: o/u. Estreita no meio, aro de labio, escuro dentro.
    img = base()
    m = (xa + xb) // 2
    anel = {(m - 1, principal): cor_sup, (m, principal): cor_sup, (m + 1, principal): cor_sup,
            (m - 2, principal + 1): cor_sup, (m + 2, principal + 1): cor_sup,
            (m - 2, principal + 2): cor_inf, (m + 2, principal + 2): cor_inf,
            (m - 1, principal + 3): cor_inf, (m, principal + 3): cor_inf, (m + 1, principal + 3): cor_inf}
    miolo = {(x, y): INTERIOR for x in range(m - 1, m + 2) for y in (principal + 1, principal + 2)}
    pintar(img, origem, miolo)
    pintar(img, origem, anel)
    saida["REDONDA"] = img
    # Sorriso e triste: a linha principal inteira, os cantos para cima ou para
    # baixo (os cantos originais saem, senao a boca curva vira onda).
    corpo_linha = {p: c for p, c in px.items() if p[1] >= principal}
    img = base()
    pintar(img, origem, corpo_linha)
    pintar(img, origem, {(xa - 1, principal - 1): cor_sup, (xb + 1, principal - 1): cor_sup,
                         (xa, principal): cor_sup, (xb, principal): cor_sup})
    saida["SORRISO"] = img
    img = base()
    pintar(img, origem, {p: c for p, c in px.items() if p[1] <= principal})
    pintar(img, origem, {(xa - 1, principal + 1): cor_sup, (xb + 1, principal + 1): cor_sup})
    saida["TRISTE"] = img
    # Cerrada: mais curta e mais escura, labio de baixo sumido.
    img = base()
    pintar(img, origem, {(x, principal): escuro(cor_sup) for x in range(xa + 1, xb)})
    saida["CERRADA"] = img
    return origem, saida


# --- sobrancelhas ------------------------------------------------------------------

def sobrancelhas(cheia, sem, px, esquerda: bool):
    x0, y0, x1, y1 = caixa(px)
    cx = (x0 + x1 + 1) // 2
    origem, fundo = recorte(sem, cx, y0 - 1, TAM_SOBR)
    # O lado de dentro (perto do nariz) e o que da a expressao.
    dentro_x = x1 if esquerda else x0
    fora_x = x0 if esquerda else x1
    largura = max(1, abs(dentro_x - fora_x))

    def deslocar(f):
        img = fundo.copy()
        novos = {}
        for (x, y), c in px.items():
            t = abs(x - dentro_x) / largura
            novos[(x, y + f(t))] = c
        pintar(img, origem, novos)
        return img

    return origem, {
        "ERGUIDA": deslocar(lambda t: -1),
        # Raiva: o lado de dentro desce.
        "FRANZIDA": deslocar(lambda t: 1 if t < 0.5 else 0),
        # Tristeza: o lado de dentro sobe, o de fora cai.
        "CAIDA": deslocar(lambda t: -1 if t < 0.4 else (1 if t > 0.75 else 0)),
    }


# --- olhos -------------------------------------------------------------------------

def olhos(cheia, sem, px, esquerda: bool):
    x0, y0, x1, y1 = caixa(px)
    cx = (x0 + x1 + 1) // 2
    origem, fundo = recorte(sem, cx, y0 - 1, TAM_OLHO)
    brancos = {p for p, c in px.items() if c == BRANCO}
    if not brancos:
        # Nenhum pixel branco exato: o mais claro faz as vezes de branco.
        mais_claro = max(px.values(), key=lambda c: sum(c[:3]))
        brancos = {p for p, c in px.items() if c == mais_claro}
    by0 = min(p[1] for p in brancos)
    by1 = max(p[1] for p in brancos)
    bx0 = min(p[0] for p in brancos)
    bx1 = max(p[0] for p in brancos)
    palpebra = min(px.values(), key=lambda c: sum(c[:3]))
    miolo = {p: c for p, c in px.items() if by0 <= p[1] <= by1 and bx0 <= p[0] <= bx1}
    pupila = {p: c for p, c in miolo.items() if p not in brancos}

    saida = {}
    # Fechado: a palpebra vira um traco na linha de baixo do branco.
    img = fundo.copy()
    pintar(img, origem, {p: c for p, c in px.items() if p[1] > by1})
    pintar(img, origem, {(x, by1): palpebra for x in range(bx0, bx1 + 1)})
    saida["FECHADO"] = img
    # Semicerrado: a linha de cima do branco vira palpebra.
    img = fundo.copy()
    pintar(img, origem, px)
    pintar(img, origem, {(x, by0): palpebra for x in range(bx0, bx1 + 1)})
    saida["SEMICERRADO"] = img
    # Arregalado: tudo o que esta acima do branco sobe um pixel, e o buraco que
    # abre e branco.
    img = fundo.copy()
    acima = {(p[0], p[1] - 1): c for p, c in px.items() if p[1] < by0}
    pintar(img, origem, {p: c for p, c in px.items() if p[1] >= by0})
    pintar(img, origem, {(x, by0 - 1): BRANCO for x in range(bx0, bx1 + 1)})
    pintar(img, origem, acima)
    saida["ARREGALADO"] = img
    # Olhar de lado: a pupila anda um pixel dentro do branco.
    for nome, passo in (("OLHA_ESQ", -1), ("OLHA_DIR", 1)):
        img = fundo.copy()
        pintar(img, origem, px)
        pintar(img, origem, {p: BRANCO for p in pupila})
        movida = {}
        for (x, y), c in pupila.items():
            nx = min(bx1, max(bx0, x + passo))
            movida[(nx, y)] = c
        pintar(img, origem, movida)
        saida[nome] = img
    return origem, saida


# --- folha -------------------------------------------------------------------------

def gerar() -> None:
    folha = Image.new("RGBA", (LADO_ATLAS, LADO_ATLAS), (0, 0, 0, 0))
    meta = []
    for n, (chave, funcao) in enumerate(caras()):
        cheia = desenhar(funcao, set())
        sem = {k: desenhar(funcao, {k}) for k in ("boca", "olhos", "sobrancelhas")}
        m_boca = mascara(cheia, sem["boca"])
        m_olho = mascara(cheia, sem["olhos"])
        m_sobr = mascara(cheia, sem["sobrancelhas"])
        bx = (n % 2) * BLOCO[0]
        by = (n // 2) * BLOCO[1]
        item = {"chave": chave, "bloco": (bx, by)}

        o, estados = bocas(cheia, sem["boca"], m_boca)
        item["boca"] = o
        for k, nome in enumerate(BOCAS):
            folha.paste(estados[nome], (bx + k * TAM_BOCA[0], by))
        for s_i, esquerda in enumerate((True, False)):
            o, estados = sobrancelhas(cheia, sem["sobrancelhas"], lado(m_sobr, esquerda), esquerda)
            item["sobr_%s" % ("e" if esquerda else "d")] = o
            base_x = bx + len(BOCAS) * TAM_BOCA[0] + s_i * len(SOBRANCELHAS) * TAM_SOBR[0]
            for k, nome in enumerate(SOBRANCELHAS):
                folha.paste(estados[nome], (base_x + k * TAM_SOBR[0], by))
        for o_i, esquerda in enumerate((True, False)):
            o, estados = olhos(cheia, sem["olhos"], lado(m_olho, esquerda), esquerda)
            item["olho_%s" % ("e" if esquerda else "d")] = o
            base_x = bx + o_i * len(OLHOS) * TAM_OLHO[0]
            for k, nome in enumerate(OLHOS):
                folha.paste(estados[nome], (base_x + k * TAM_OLHO[0], by + TAM_BOCA[1]))
        meta.append(item)

    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    folha.save(DESTINO, "PNG", optimize=True)
    print("rosto_atlas          %dx%d  %d caras" % (LADO_ATLAS, LADO_ATLAS, len(meta)))
    _hd(folha)
    _meta(meta)


def _hd(folha: Image.Image) -> None:
    """4x por Scale2x duas vezes, recorte por recorte (a borda de um nao puxa a
    cor do vizinho), como o atlas de gente (`gerar_npc_hd`)."""
    w, h = folha.size
    hd = Image.new("RGBA", (w * 4, h * 4), (0, 0, 0, 0))
    for n in range((LADO_ATLAS // BLOCO[1]) * 2):
        bx = (n % 2) * BLOCO[0]
        by = (n // 2) * BLOCO[1]
        pecas = [(bx + k * TAM_BOCA[0], by, TAM_BOCA) for k in range(len(BOCAS))]
        base = bx + len(BOCAS) * TAM_BOCA[0]
        pecas += [(base + k * TAM_SOBR[0], by, TAM_SOBR) for k in range(2 * len(SOBRANCELHAS))]
        pecas += [(bx + k * TAM_OLHO[0], by + TAM_BOCA[1], TAM_OLHO) for k in range(2 * len(OLHOS))]
        for x, y, (tw, th) in pecas:
            if y + th > h:
                continue
            cel = folha.crop((x, y, x + tw, y + th))
            if cel.getbbox() is None:
                continue
            px = [[cel.getpixel((i, j)) for i in range(tw)] for j in range(th)]
            px = gerar_npc_hd.scale2x(px, tw, th)
            px = gerar_npc_hd.scale2x(px, tw * 2, th * 2)
            img = Image.new("RGBA", (tw * 4, th * 4))
            img.putdata([c for linha in px for c in linha])
            hd.paste(img, (x * 4, y * 4))
    DESTINO_HD.parent.mkdir(parents=True, exist_ok=True)
    hd.save(DESTINO_HD, "PNG", optimize=True)
    print("rosto_atlas hd       %dx%d" % hd.size)


def _meta(meta: list) -> None:
    linhas = [
        "## GERADO por tools/gerar_rosto.py — nao editar a mao.",
        "##",
        "## Onde cada recorte da cara (boca, sobrancelhas, olhos) fica na celula de",
        "## 32 px de cada rosto, e onde o bloco daquele rosto comeca em",
        "## `rosto_atlas.png`. A chave e a celula do rosto no atlas de gente,",
        "## Vector2i(coluna, linha). Ver `Rosto`.",
        "class_name RostoMeta",
        "extends RefCounted",
        "",
        "const ATLAS := \"res://assets/textures/rosto_atlas.png\"",
        "const LADO_ATLAS := %d" % LADO_ATLAS,
        "const TAM_BOCA := Vector2i(%d, %d)" % TAM_BOCA,
        "const TAM_SOBR := Vector2i(%d, %d)" % TAM_SOBR,
        "const TAM_OLHO := Vector2i(%d, %d)" % TAM_OLHO,
        "const BOCAS: Array[StringName] = [%s]" % ", ".join('&"%s"' % b for b in BOCAS),
        "const SOBRANCELHAS: Array[StringName] = [%s]" % ", ".join('&"%s"' % b for b in SOBRANCELHAS),
        "const OLHOS: Array[StringName] = [%s]" % ", ".join('&"%s"' % b for b in OLHOS),
        "",
        "## Vector2i(coluna, linha) -> {bloco, boca, sobr_e, sobr_d, olho_e, olho_d},",
        "## cada um Vector2i em pixels (bloco na folha; os outros na celula da cara).",
        "const CARAS := {",
    ]
    for m in meta:
        partes = ", ".join('"%s": Vector2i(%d, %d)' % (k, m[k][0], m[k][1])
                           for k in ("bloco", "boca", "sobr_e", "sobr_d", "olho_e", "olho_d"))
        linhas.append("\tVector2i(%d, %d): {%s}," % (m["chave"][0], m["chave"][1], partes))
    linhas.append("}")
    META.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    print("rosto_meta.gd        %d caras" % len(meta))


if __name__ == "__main__":
    gerar()

#!/usr/bin/env python3
"""Capas reais de disco brasileiro e de jogo de PS2 para a casa da fumaca.

    python tools/baixar_capas.py

Decisao do PLANO_CASA_FUMACA_V2 (secao 10): "capas reais da internet". A fonte
e a imagem principal do artigo da Wikipedia (en, e pt quando o en nao tem),
pela API `pageimages` com `pilicense=any` — a capa de disco e de jogo e
imagem de uso restrito, e sem esse parametro a API so devolve imagem livre.

NOTA DE DIREITO AUTORAL: capa de disco e de jogo tem dono. Isto serve ao build
pessoal; um build distribuido troca o atlas por parodias (ver o plano, 4.3).

O que sai
---------
    game/assets/textures_hd/capas.jpg   2048 px, o MODERNO le este (TexturasHD)
    game/assets/textures/capas.png      512 px, 256 cores, o PS1 STYLE
    game/src/world/capas_atlas.gd       quantas capas ha e onde cada uma esta

Grade: metade de cima, discos em celulas de 256 x 256 (8 por linha); metade de
baixo, caixas de PS2 em 180 x 256 (11 por linha), proporcao da caixa de DVD
(13,5 x 19 cm). A borda de cada celula repete o pixel da beira em 3 px: com
mipmap, a capa vizinha nao vaza para dentro desta.
"""
import io
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
CACHE = RAIZ / ".tools" / "cache_capas"
UA = {"User-Agent": "psx-game-dev/1.0 (asset pipeline; personal build)"}

LADO = 2048
CEL_DISCO = (256, 256)
DISCOS_POR_LINHA = 8
CEL_JOGO = (180, 256)
JOGOS_POR_LINHA = 11
Y_JOGOS = 1024
GUARDA = 3

# (arquivo, titulo no en.wikipedia, titulo no pt.wikipedia)
DISCOS = [
    ("sobrevivendo_no_inferno", "Sobrevivendo no Inferno", "Sobrevivendo no Inferno"),
    ("nada_como_um_dia", "Nada Como um Dia Após o Outro Dia", "Nada como um Dia após o Outro Dia"),
    ("raio_x_do_brasil", "Raio X do Brasil", "Raio X do Brasil"),
    ("usuario", "Usuário (album)", "Usuário (álbum)"),
    ("sagaz_homem_fumaca", "A Invasão do Sagaz Homem Fumaça", "A Invasão do Sagaz Homem Fumaça"),
    ("rap_e_compromisso", "Rap É Compromisso", "Rap É Compromisso"),
    ("da_lama_ao_caos", "Da Lama ao Caos", "Da Lama ao Caos"),
    ("afrociberdelia", "Afrociberdelia", "Afrociberdelia"),
    ("roots", "Roots (Sepultura album)", "Roots (álbum de Sepultura)"),
    ("chaos_ad", "Chaos A.D.", "Chaos A.D."),
    ("cabeca_dinossauro", "Cabeça Dinossauro", "Cabeça Dinossauro"),
    ("transpiracao_continua", "Transpiração Contínua Prolongada", "Transpiração Contínua Prolongada"),
    ("tamo_ai_na_atividade", "Tamo Aí na Atividade", "Tamo Aí na Atividade"),
    ("procura_da_batida_perfeita", "À Procura da Batida Perfeita", "À Procura da Batida Perfeita"),
    ("lado_b_lado_a", "Lado B Lado A", "Lado B Lado A"),
    ("racional", "Racional, Vol. 1", "Tim Maia Racional, Vol. 1"),
    ("africa_brasil", "África Brasil", "África Brasil"),
    ("os_mutantes", "Os Mutantes (album)", "Os Mutantes (álbum)"),
    ("raimundos", "Raimundos (album)", "Raimundos (álbum)"),
    ("cartola_1976", "Cartola (1976 album)", "Cartola (álbum de 1976)"),
    ("traficando_informacao", "Traficando Informação", "Traficando Informação"),
    ("samba_esporte_fino", "Samba Esporte Fino", "Samba Esporte Fino"),
    ("admiravel_chip_novo", "Admirável Chip Novo", "Admirável Chip Novo"),
    ("chegou_a_hora", "Chegou a Hora de Recomeçar", "Chegou a Hora de Recomeçar"),
    ("dois_legiao", "Dois (Legião Urbana album)", "Dois (álbum de Legião Urbana)"),
    ("eu_nao_sou_santo", "Eu Não Sou Santo", "Eu Não Sou Santo"),
    ("acabou_chorare", "Acabou Chorare", "Acabou Chorare"),
    ("clube_da_esquina", "Clube da Esquina (album)", "Clube da Esquina (álbum)"),
    ("tropicalia", "Tropicália: ou Panis et Circencis", "Tropicália ou Panis et Circencis"),
    ("krig_ha_bandolo", "Krig-ha, Bandolo!", "Krig-ha, Bandolo!"),
    ("selvagem", "Selvagem?", "Selvagem?"),
]

JOGOS = [
    ("gta_san_andreas", "Grand Theft Auto: San Andreas", ""),
    ("gta_vice_city", "Grand Theft Auto: Vice City", ""),
    ("gta_iii", "Grand Theft Auto III", ""),
    ("pes6", "Pro Evolution Soccer 6", ""),
    ("pes5", "Pro Evolution Soccer 5", ""),
    ("nfs_underground_2", "Need for Speed: Underground 2", ""),
    ("nfs_most_wanted", "Need for Speed: Most Wanted (2005 video game)", ""),
    ("thps3", "Tony Hawk's Pro Skater 3", ""),
    ("god_of_war", "God of War (2005 video game)", ""),
    ("guitar_hero", "Guitar Hero (video game)", ""),
    ("resident_evil_4", "Resident Evil 4", ""),
    ("shadow_of_the_colossus", "Shadow of the Colossus", ""),
    ("silent_hill_2", "Silent Hill 2", ""),
    ("bully", "Bully (video game)", ""),
    ("mgs3", "Metal Gear Solid 3: Snake Eater", ""),
    ("gran_turismo_4", "Gran Turismo 4", ""),
    ("burnout_3", "Burnout 3: Takedown", ""),
    ("kingdom_hearts_2", "Kingdom Hearts II", ""),
    ("dmc3", "Devil May Cry 3: Dragon's Awakening", ""),
    ("tekken_5", "Tekken 5", ""),
    ("shaolin_monks", "Mortal Kombat: Shaolin Monks", ""),
    ("budokai_tenkaichi_3", "Dragon Ball Z: Budokai Tenkaichi 3", ""),
    ("midnight_club_3", "Midnight Club 3: Dub Edition", ""),
    ("the_warriors", "The Warriors (video game)", ""),
    ("final_fantasy_x", "Final Fantasy X", ""),
    ("fifa_street", "FIFA Street (2005 video game)", ""),
    ("smackdown_2006", "WWE SmackDown! vs. Raw 2006", ""),
    ("crash_nitro_kart", "Crash Nitro Kart", ""),
]

# CD-R de camelo, escrito a caneta: a cara do PS2 destravado no Brasil.
PIRATAS = [
    ("pirata_bomba_patch", ["BOMBA", "PATCH", "2009"], (30, 60, 200)),
    ("pirata_gta_rio", ["GTA", "RIO DE", "JANEIRO"], (20, 20, 20)),
    ("pirata_winning", ["WINNING", "ELEVEN 10", "narr. BR"], (190, 20, 30)),
    ("pirata_mix", ["MIX", "JOGOS", "15 em 1"], (20, 120, 40)),
]


def _pedir(url: str) -> bytes:
    """GET com espera: a Wikipedia devolve 429 a quem pede depressa."""
    espera = 4.0
    for _ in range(6):
        req = urllib.request.Request(url, headers=UA)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            depois = e.headers.get("Retry-After")
            time.sleep(float(depois) if depois and depois.isdigit() else espera)
            espera *= 2.0
    raise RuntimeError("429 insistente")


def resolver(lang: str, titulos: list[str]) -> dict[str, str]:
    """Titulo pedido -> url da imagem principal. Um pedido por lote de 40."""
    saida: dict[str, str] = {}
    for i in range(0, len(titulos), 40):
        lote = [t for t in titulos[i:i + 40] if t]
        q = urllib.parse.urlencode({
            "action": "query", "titles": "|".join(lote), "prop": "pageimages",
            "piprop": "original", "pilicense": "any", "format": "json",
            "redirects": 1,
        })
        dados = json.loads(_pedir(f"https://{lang}.wikipedia.org/w/api.php?{q}"))
        consulta = dados.get("query", {})
        # O titulo pedido pode ter sido normalizado e depois redirecionado.
        volta: dict[str, str] = {t: t for t in lote}
        for chave in ("normalized", "redirects"):
            for par in consulta.get(chave, []):
                for orig, pedido in list(volta.items()):
                    if orig == par["from"]:
                        volta[par["to"]] = pedido
        for pagina in consulta.get("pages", {}).values():
            url = pagina.get("original", {}).get("source")
            pedido = volta.get(pagina.get("title", ""))
            if url and pedido:
                saida[pedido] = url.split("?")[0]
        time.sleep(1.0)
    return saida


_URLS: dict[str, str] = {}


def preparar(lista: list[tuple]) -> None:
    faltam = [x for x in lista if not (CACHE / f"{x[0]}.img").exists()]
    if not faltam:
        return
    en = resolver("en", [x[1] for x in faltam])
    pt = resolver("pt", [x[2] for x in faltam if x[1] not in en and x[2]])
    for nome, t_en, t_pt in faltam:
        url = en.get(t_en) or pt.get(t_pt)
        if url:
            _URLS[nome] = url


def baixar(nome: str, en: str, pt: str) -> Image.Image | None:
    CACHE.mkdir(parents=True, exist_ok=True)
    local = CACHE / f"{nome}.img"
    if not local.exists():
        url = _URLS.get(nome)
        if not url or url.lower().endswith(".svg"):
            print(f"  {nome}: sem imagem")
            return None
        try:
            local.write_bytes(_pedir(url))
        except Exception as e:  # noqa: BLE001
            print(f"  {nome}: falhou {e}")
            return None
        time.sleep(1.5)
    try:
        return Image.open(io.BytesIO(local.read_bytes())).convert("RGB")
    except Exception as e:  # noqa: BLE001
        print(f"  {nome}: imagem ilegivel {e}")
        return None


def encaixar(img: Image.Image, cel: tuple[int, int]) -> Image.Image:
    """Recorta ao centro na proporcao da celula e reduz."""
    w, h = img.size
    alvo = cel[0] / cel[1]
    if w / h > alvo:
        nw = round(h * alvo)
        img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = round(w / alvo)
        img = img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return img.resize(cel, Image.LANCZOS)


def colar(atlas: Image.Image, img: Image.Image, x: int, y: int) -> None:
    """Cola com guarda: a beira do desenho repetida para fora da celula util."""
    w, h = img.size
    miolo = img.resize((w - GUARDA * 2, h - GUARDA * 2), Image.LANCZOS)
    borda = miolo.resize((w, h), Image.NEAREST)
    atlas.paste(borda, (x, y))
    atlas.paste(miolo, (x + GUARDA, y + GUARDA))


def pirata(linhas: list[str], tinta: tuple[int, int, int]) -> Image.Image:
    """Encarte de papel sulfite dobrado, escrito a caneta de CD."""
    w, h = 360, 512
    img = Image.new("RGB", (w, h), (236, 234, 226))
    d = ImageDraw.Draw(img)
    try:
        fonte = ImageFont.truetype("C:/Windows/Fonts/segoepr.ttf", 64)
    except OSError:
        fonte = ImageFont.load_default()
    y = 110
    for k, linha in enumerate(linhas):
        caixa = d.textbbox((0, 0), linha, font=fonte)
        # Caneta nao sai do papel: a linha longa encolhe ate caber.
        tam = 64
        while caixa[2] - caixa[0] > w - 40 and tam > 30:
            tam -= 4
            fonte_k = ImageFont.truetype("C:/Windows/Fonts/segoepr.ttf", tam)
            caixa = d.textbbox((0, 0), linha, font=fonte_k)
        fonte_k = ImageFont.truetype("C:/Windows/Fonts/segoepr.ttf", tam)
        x = (w - (caixa[2] - caixa[0])) // 2 + (k % 2) * 8 - 4
        d.text((x, y), linha, fill=tinta, font=fonte_k)
        y += 92
    # O disco por baixo do papel fino: um circulo que aparece de leve.
    d.ellipse((40, 196, w - 40, 196 + (w - 80)), outline=(210, 208, 200), width=3)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    return img


def main() -> int:
    atlas = Image.new("RGB", (LADO, LADO), (18, 18, 20))
    discos: list[str] = []
    jogos: list[str] = []
    CACHE.mkdir(parents=True, exist_ok=True)
    preparar(DISCOS)
    preparar(JOGOS)

    for nome, en, pt in DISCOS:
        img = baixar(nome, en, pt)
        if img is None:
            continue
        k = len(discos)
        colar(atlas, encaixar(img, CEL_DISCO),
              (k % DISCOS_POR_LINHA) * CEL_DISCO[0], (k // DISCOS_POR_LINHA) * CEL_DISCO[1])
        discos.append(nome)
        print(f"  disco {k:2d} {nome}")

    for nome, en, pt in JOGOS:
        img = baixar(nome, en, pt)
        if img is None:
            continue
        k = len(jogos)
        colar(atlas, encaixar(img, CEL_JOGO),
              (k % JOGOS_POR_LINHA) * CEL_JOGO[0], Y_JOGOS + (k // JOGOS_POR_LINHA) * CEL_JOGO[1])
        jogos.append(nome)
        print(f"  jogo  {k:2d} {nome}")
    piratas_ini = len(jogos)
    for nome, linhas, tinta in PIRATAS:
        k = len(jogos)
        colar(atlas, encaixar(pirata(linhas, tinta), CEL_JOGO),
              (k % JOGOS_POR_LINHA) * CEL_JOGO[0], Y_JOGOS + (k // JOGOS_POR_LINHA) * CEL_JOGO[1])
        jogos.append(nome)
        print(f"  jogo  {k:2d} {nome}")

    hd = RAIZ / "game/assets/textures_hd/capas.jpg"
    atlas.save(hd, "JPEG", quality=92)
    ps1 = atlas.resize((512, 512), Image.LANCZOS).quantize(256).convert("RGB")
    ps1.save(RAIZ / "game/assets/textures/capas.png", optimize=True)

    gd = RAIZ / "game/src/world/capas_atlas.gd"
    gd.write_text(
        "## Gerado por tools/baixar_capas.py. Nao editar a mao.\n"
        "##\n"
        "## Onde cada capa esta no atlas `capas` (textures/capas.png no PS1,\n"
        "## textures_hd/capas.jpg no MODERNO). UV de 0 a 1, origem no canto de cima.\n"
        "class_name CapasAtlas\n"
        "extends RefCounted\n\n"
        f"const LADO := {LADO}.0\n"
        f"const DISCOS: PackedStringArray = {json.dumps(discos)}\n"
        f"const JOGOS: PackedStringArray = {json.dumps(jogos)}\n"
        f"## A partir daqui, em JOGOS, sao encartes de CD-R pirata.\n"
        f"const PRIMEIRO_PIRATA := {piratas_ini}\n\n\n"
        "static func disco(k: int) -> Rect2:\n"
        f"\tk = posmod(k, DISCOS.size())\n"
        f"\tvar x := float(k % {DISCOS_POR_LINHA}) * {CEL_DISCO[0]}.0 + {GUARDA}.0\n"
        f"\tvar y := float(k / {DISCOS_POR_LINHA}) * {CEL_DISCO[1]}.0 + {GUARDA}.0\n"
        f"\treturn Rect2(x / LADO, y / LADO, {CEL_DISCO[0] - GUARDA * 2}.0 / LADO, {CEL_DISCO[1] - GUARDA * 2}.0 / LADO)\n\n\n"
        "static func jogo(k: int) -> Rect2:\n"
        f"\tk = posmod(k, JOGOS.size())\n"
        f"\tvar x := float(k % {JOGOS_POR_LINHA}) * {CEL_JOGO[0]}.0 + {GUARDA}.0\n"
        f"\tvar y := {Y_JOGOS}.0 + float(k / {JOGOS_POR_LINHA}) * {CEL_JOGO[1]}.0 + {GUARDA}.0\n"
        f"\treturn Rect2(x / LADO, y / LADO, {CEL_JOGO[0] - GUARDA * 2}.0 / LADO, {CEL_JOGO[1] - GUARDA * 2}.0 / LADO)\n",
        encoding="utf-8", newline="\n")
    print(f"{len(discos)} discos, {len(jogos)} jogos ({len(PIRATAS)} piratas)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

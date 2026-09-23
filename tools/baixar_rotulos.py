#!/usr/bin/env python3
"""Rotulos reais das marcas brasileiras de 1998 para os produtos do mercado.

    python tools/baixar_rotulos.py              marcas reais (build pessoal)
    python tools/baixar_rotulos.py --pastiche   marcas inventadas (build distribuido)

Decisao D4 do PLANO_MERCADO_AAA: "reais, em pasta trocavel". Mesmo molde do
`baixar_capas.py`: o logo de cada marca vem do Wikimedia Commons (arquivo fixo
na tabela LOGOS, escolhido a olho numa folha de contato), fica em cache em
`.tools/cache_rotulos`, e a embalagem inteira e composta aqui — cor, faixa,
liquido na garrafa, tampa, descricao, peso e codigo de barras — porque foto de
produto nao se encaixa numa malha de oito lados e logo sozinho nao e rotulo.

NOTA DE DIREITO AUTORAL: logo e marca tem dono. Isto serve ao build pessoal; o
build distribuido roda com --pastiche, que troca cada marca por uma inventada
sem mudar mais nada — nem o codigo do jogo, que so conhece o atlas.

O que sai
---------
    game/assets/textures_hd/rotulos.jpg          2048 px, o MODERNO le este
    game/assets/textures/rotulos.png             512 px, 256 cores, o PS1 STYLE
    game/src/world/mercado/rotulos_atlas.gd      onde cada rotulo e etiqueta esta

Grade: metade de cima, rotulos em celulas de 128 x 128 (16 por linha); metade de
baixo, etiquetas de preco em 128 x 56. A celula segue o contrato de UV de
`game/src/world/mercado/produto_malhas.gd`: tira de cima (15%) e o topo, o resto
e a volta do produto de cima para baixo, frente na metade esquerda.

O preco da etiqueta e LIDO de `catalogo_mercado.gd`, e nao escrito aqui: a
etiqueta tem de dizer o mesmo numero que o caixa cobra.
"""
import hashlib
import io
import json
import math
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
CACHE = RAIZ / ".tools" / "cache_rotulos"
CATALOGO = RAIZ / "game/src/world/mercado/catalogo_mercado.gd"
UA = {"User-Agent": "psx-game-dev/1.0 (asset pipeline; personal build)"}

LADO = 2048
CEL = 128
POR_LINHA = 16
Y_ETIQUETAS = 1024
CEL_ETIQUETA = (128, 56)
GUARDA = 2
# Desenha a 4x e reduz: letra de 8 px sai legivel so assim.
ESCALA = 4
W = CEL * ESCALA
TOPO = round(0.15 * W)

FONTES = "C:/Windows/Fonts/"

# Perfis de revolucao de produto_malhas.gd (altura, raio). A arte pinta o
# liquido, o ombro e a tampa nas alturas em que a malha os tem.
PERFIL_PET = {"corpo": (0.05, 0.62), "ombro": (0.62, 0.88), "tampa": (0.88, 1.0)}
PERFIL_GARRAFA = {"corpo": (0.03, 0.56), "ombro": (0.56, 0.78), "gargalo": (0.78, 0.95),
                  "tampa": (0.95, 1.0)}
PERFIL_FRASCO = {"corpo": (0.04, 0.76), "ombro": (0.76, 0.9), "tampa": (0.9, 1.0)}
PERFIL_POTE = {"corpo": (0.06, 0.88), "tampa": (0.88, 1.0)}

# --- logos -------------------------------------------------------------------
# chave -> arquivo do Commons. Escolhidos a olho numa folha de contato (a busca
# devolve logo de 2020 antes do de 1998; aqui fica o de epoca quando existe).
# Sem prefixo: arquivo do Wikimedia Commons. "pt|" ou "en|": arquivo local da
# Wikipedia daquela lingua — e onde mora o logo de uso restrito, que o Commons
# nao aceita (o mesmo caso das capas de disco).
LOGOS: dict[str, str] = {
    "coca": "File:Coca-Cola logo.svg",
    "guarana": "File:Guarana-antarctica 2020.svg",
    "fanta": "File:Fanta logo (2009).svg",
    "sprite": "File:Sprite 2022.svg",
    "pepsi": "File:Pepsi bi (1991).svg",
    "brahma": "File:Brahma Logo.svg",
    "skol": "File:Skol logo 2015.svg",
    "schin": "File:Schincariol.svg",
    "bohemia": "File:Cerveja Bohemia logo.png",
    "gatorade": "File:Gatorade logo before 2009.png",
    "catupiry": "File:Catupiry logo.png",
    "parmalat": "File:Parmalat logo 2.png",
    "nissin": "File:Nissin Logo.svg",
    "maizena": "File:Maizena logo.png",
    "melitta": "File:Logo Melitta (Marke).svg",
    "toddy": "File:Toddy brand logo.png",
    "nabisco": "File:Nabisco logo.svg",
    "ruffles": "File:Ruffles brand logo.png",
    "doritos": "File:Logo Doritos.png",
    "lacta": "File:Logo Lacta 2021.svg",
    "garoto": "File:Logo de Chocolates Garoto.png",
    "baton": "File:Garoto Baton chocolate logo.png",
    "trident": "File:Trident Gum logo.png",
    "bubbaloo": "File:Bubbaloo logo.svg",
    "mentos": "File:Mentos logo.svg",
    "colgate": "File:Colgate logo red.svg",
    "lux": "File:Lux logo.jpg",
    "rexona": "File:Rexona logo 2015.svg",
    "gillette": "File:Gillette logo.svg",
    "always": "File:Always logo.png",
    "bombril": "File:Logotipo da Bombril.svg",
    "veja": "File:Veja limpeza.png",
    "baygon": "File:Baygonlogo.png",
    "bic": "File:Bic logo.svg",
    "duracell": "File:Duracell logo.svg",
    "bandaid": "File:Band-Aid logo.svg",
    "bayer": "File:Logo Bayer.svg",
    "marlboro": "File:Marlboro Logo.svg",
    "hollywood": "File:Hollywood 1980.jpg",
    "charm": "File:Embalagem-charm-special-blend-6008.jpg",
    "serenata": "File:Serenata de Amor19.png",
    "nestle": "File:Nestlé textlogo.svg",
    "cheetos": "File:Cheetos logo.svg",
    "camil": "pt|File:Logotipo_da_Camil_Alimentos.svg",
    "elmachips": "pt|File:Elma_Chips_logo.png",
    "hellmanns": "pt|File:Hellmanns_logo_1.jpg",
    "kaiser": "pt|File:Logotipo_da_Kaiser.svg",
    "kibon": "pt|File:Kibon.svg",
    "negresco": "pt|File:Negresco_2023_Logo.svg",
    "nescau": "pt|File:Logotipo_Oficial_do_Nescau.png",
    "trakinas": "pt|File:Trakinas.png",
    "dolly": "pt|File:Logotipo_da_Dolly_Refrigerantes.svg",
    "free": "pt|File:Free-ultima-embalagem.jpg",
}

# chave -> nome inventado, para o --pastiche.
PASTICHE = {
    "coca": "Cola-Rica", "guarana": "Guaraná Tupã", "fanta": "Fantasia", "sprite": "Limonix",
    "kuat": "Kiari", "pepsi": "Pepsol", "antarctica": "Antártida", "sukita": "Laranjinha",
    "dolly": "Dudy", "brahma": "Bramante", "skol": "Escol", "kaiser": "Kaizer",
    "schin": "Chincaria", "bohemia": "Boêmia", "crystal": "Cristalina", "minalba": "Minerva",
    "gatorade": "Isotron", "maguary": "Maguari", "tang": "Tangue", "kisuco": "Ki-Refresco",
}

# --- a arte de cada produto ----------------------------------------------------
# logo: chave de LOGOS (ou None); marca: texto do logo quando nao ha logo;
# fonte: 'impact' | 'script' | 'serif' | 'bold'; tinta: cor do logo quando
# recolorido ('orig' mantem as cores do arquivo); bg, bg2: fundo e faixa;
# fg: texto; sub: linha de baixo; faixa: (y0, y1) do rotulo em altura 0..1;
# liquido/vidro: cor do que se ve pelo plastico ou vidro; tampa: cor da tampa.
A = dict  # abreviacao da tabela

ARTE = {
    # refrigerante
    "coca_lata": A(logo="coca", marca="Coca-Cola", fonte="script", tinta="#ffffff", bg="#d8121b", onda="#ffffff", sub="350ml"),
    "coca_2l": A(logo="coca", marca="Coca-Cola", fonte="script", tinta="#ffffff", bg="#d8121b", onda="#ffffff", faixa=(0.3, 0.52), liquido="#2b1208", vidro="#c9d4d0", tampa="#c8101a", sub="2 LITROS"),
    "guarana_lata": A(logo="guarana", marca="Guaraná", fonte="script", tinta="#ffffff", bg="#0b7a3b", bg2="#d62a1f", sub="ANTARCTICA  350ml"),
    "guarana_2l": A(logo="guarana", marca="Guaraná", fonte="script", tinta="#ffffff", bg="#0b7a3b", bg2="#d62a1f", faixa=(0.3, 0.53), liquido="#6e4a10", vidro="#2f7a3e", tampa="#0b6e33", sub="ANTARCTICA  2 LITROS"),
    "fanta_lata": A(logo="fanta", marca="Fanta", fonte="impact", tinta="orig", bg="#f47b20", bg2="#1b3f8f", sub="LARANJA  350ml"),
    "fanta_2l": A(logo="fanta", marca="Fanta", fonte="impact", tinta="orig", bg="#f47b20", bg2="#1b3f8f", faixa=(0.3, 0.53), liquido="#f07a10", vidro="#d8dcd4", tampa="#1b3f8f", sub="LARANJA 2L"),
    "sprite_lata": A(logo="sprite", marca="Sprite", fonte="impact", tinta="#ffffff", bg="#0a8a3b", bg2="#1c4ea0", sub="LIMÃO  350ml"),
    "kuat_2l": A(logo="kuat", marca="Kuat", fonte="impact", tinta="orig", bg="#1b7a2e", bg2="#f2c417", faixa=(0.3, 0.53), liquido="#6e4a10", vidro="#2f7a3e", tampa="#1b7a2e", sub="GUARANÁ 2L"),
    "pepsi_lata": A(logo="pepsi", marca="PEPSI", fonte="impact", tinta="orig", placa="#ffffff", bg="#0b3c8c", bg2="#d8121b", sub="350ml"),
    "pepsi_2l": A(logo="pepsi", marca="PEPSI", fonte="impact", tinta="orig", placa="#ffffff", bg="#0b3c8c", bg2="#d8121b", faixa=(0.3, 0.52), liquido="#2b1208", vidro="#c9d4d0", tampa="#0b3c8c", sub="2 LITROS"),
    "soda_lata": A(logo=None, marca="Soda", fonte="script", tinta="#1b6e2a", bg="#c8e04a", bg2="#ffffff", sub="LIMONADA  ANTARCTICA"),
    "sukita_2l": A(logo="sukita", marca="Sukita", fonte="impact", tinta="#1c3f99", bg="#f58a1f", bg2="#ffffff", faixa=(0.3, 0.53), liquido="#f07a10", vidro="#d8dcd4", tampa="#f58a1f", sub="LARANJA 2L"),
    "dolly_2l": A(logo="dolly", marca="Dolly", fonte="impact", tinta="orig", bg="#f5d20f", bg2="#d62a1f", faixa=(0.3, 0.53), liquido="#6e4a10", vidro="#2f7a3e", tampa="#d62a1f", sub="GUARANÁ 2L"),
    # cerveja
    "brahma_lata": A(logo="brahma", marca="Brahma", fonte="script", tinta="#ffffff", bg="#c4161c", bg2="#f3e7c8", sub="CHOPP  350ml"),
    "skol_lata": A(logo="skol", marca="SKOL", fonte="impact", tinta="orig", bg="#f2f0e8", bg2="#1c3f99", sub="PILSEN  350ml"),
    "antarctica_lata": A(logo="antarctica", marca="Antarctica", fonte="serif", tinta="orig", bg="#f2f0e8", bg2="#1b3f8f", sub="PILSEN  350ml"),
    "kaiser_lata": A(logo="kaiser", marca="Kaiser", fonte="serif", tinta="orig", bg="#1d6b3a", bg2="#f2f0e8", sub="350ml"),
    "schin_lata": A(logo="schin", marca="Schincariol", fonte="serif", tinta="orig", bg="#f2f0e8", bg2="#c01b22", sub="PILSEN  350ml"),
    "bohemia_lata": A(logo="bohemia", marca="Bohemia", fonte="serif", tinta="orig", bg="#e8d8a4", bg2="#1c2b55", sub="350ml"),
    "brahma_600": A(logo="brahma", marca="Brahma", fonte="script", tinta="#ffffff", bg="#c4161c", faixa=(0.16, 0.46), liquido="#5a2e0a", vidro="#4a2a0c", tampa="#c9a44a", gargalo="#c4161c", sub="CHOPP 600ml"),
    # agua, suco
    "agua_crystal": A(logo="crystal", marca="Crystal", fonte="serif", tinta="#1b56a8", bg="#ffffff", bg2="#5ab0e8", faixa=(0.3, 0.5), liquido="#d8ecf4", vidro="#e4eef2", tampa="#1b56a8", sub="ÁGUA MINERAL 500ml"),
    "agua_minalba": A(logo="minalba", marca="Minalba", fonte="serif", tinta="#1b56a8", bg="#ffffff", bg2="#1b56a8", faixa=(0.3, 0.5), liquido="#d8ecf4", vidro="#e4eef2", tampa="#f2f2f2", sub="ÁGUA MINERAL 1,5L"),
    "gatorade": A(logo="gatorade", marca="Gatorade", fonte="impact", tinta="orig", bg="#1a1a1a", bg2="#f58220", faixa=(0.3, 0.55), liquido="#b8e03a", vidro="#dfe8d0", tampa="#2fa84a", sub="LIMÃO 473ml"),
    "maguary": A(logo="maguary", marca="Maguary", fonte="bold", tinta="#1b6e2a", bg="#f5d20f", bg2="#1b6e2a", faixa=(0.15, 0.48), liquido="#f0b818", vidro="#e8e4c8", tampa="#e8e8e8", gargalo="#f5d20f", sub="MARACUJÁ 500ml"),
    "tang": A(logo="tang", marca="Tang", fonte="impact", tinta="#1c3f99", bg="#f27a1a", bg2="#ffd23a", sub="LARANJA  faz 1 litro", fruta="#f58a1f"),
    "kisuco": A(logo="kisuco", marca="Ki-Suco", fonte="impact", tinta="#ffffff", bg="#6a2a8a", bg2="#f5d20f", sub="UVA", fruta="#4a1a6a"),
    # laticinio
    "danone": A(logo="danone", marca="Danone", fonte="bold", tinta="orig", bg="#ffffff", bg2="#e8487a", sub="MORANGO 200g", tampa="#e8487a", fruta="#d8202a"),
    "danoninho": A(logo=None, marca="Danoninho", fonte="impact", tinta="#e8487a", bg="#fde6ef", bg2="#f5d20f", sub="MORANGO", tampa="#e8487a"),
    "yakult": A(logo="yakult", marca="Yakult", fonte="bold", tinta="#d8101a", bg="#f4f0e8", bg2="#d8101a", tampa="#d8101a", sub="80g"),
    "catupiry": A(logo="catupiry", marca="Catupiry", fonte="script", tinta="#1c3f99", bg="#ffffff", bg2="#1c3f99", tampa="#1c3f99", sub="REQUEIJÃO 250g"),
    "qualy": A(logo="qualy", marca="Qualy", fonte="impact", tinta="#1c3f99", bg="#f7d417", bg2="#1c3f99", tampa="#f7d417", sub="MARGARINA 500g"),
    "doriana": A(logo="doriana", marca="Doriana", fonte="script", tinta="#c8101a", bg="#ffffff", bg2="#c8101a", tampa="#f5e6a0", sub="CREMOSA 250g"),
    "parmalat": A(logo="parmalat", marca="Parmalat", fonte="bold", tinta="orig", bg="#ffffff", bg2="#1c4ea0", sub="LEITE LONGA VIDA 1L", vaca=True),
    # mercearia
    "arroz": A(logo="tiojoao", marca="Tio João", fonte="serif", tinta="#c8101a", bg="#ffffff", bg2="#1b7a2e", sub="ARROZ TIPO 1  1kg", grao="#f4efe0"),
    "feijao": A(logo="camil", marca="Camil", fonte="bold", tinta="orig", bg="#f4f0e8", bg2="#1c3f99", sub="FEIJÃO CARIOCA 1kg", grao="#a8743a"),
    "acucar": A(logo="uniao", marca="União", fonte="serif", tinta="orig", bg="#ffffff", bg2="#1c3f99", sub="AÇÚCAR REFINADO 1kg"),
    "sal": A(logo="cisne", marca="Cisne", fonte="serif", tinta="#1c3f99", bg="#ffffff", bg2="#5ab0e8", sub="SAL REFINADO 1kg"),
    "miojo": A(logo="nissin", marca="NISSIN", fonte="impact", tinta="orig", bg="#f39a1e", bg2="#d62a1f", sub="MIOJO LÁMEN  GALINHA", prato="#f4d8a0"),
    "espaguete": A(logo="adria", marca="Adria", fonte="script", tinta="#ffffff", bg="#1d4fa0", bg2="#f5d20f", sub="ESPAGUETE 500g", grao="#f2d27a"),
    "pomarola": A(logo=None, marca="Pomarola", fonte="script", tinta="#ffffff", bg="#c8201e", bg2="#2a8a3a", sub="MOLHO DE TOMATE", fruta="#e0301e"),
    "elefante": A(logo="elefante", marca="Elefante", fonte="impact", tinta="#ffffff", bg="#c21d1a", bg2="#f5d20f", sub="EXTRATO DE TOMATE"),
    "hellmanns": A(logo="hellmanns", marca="Hellmann's", fonte="serif", tinta="orig", bg="#f6f3ea", bg2="#1c3f99", tampa="#1c3f99", sub="MAIONESE 500g"),
    "oleo": A(logo="liza", marca="Liza", fonte="impact", tinta="#1c3f99", bg="#f7d417", bg2="#1c3f99", faixa=(0.25, 0.55), liquido="#e8b820", vidro="#efe8c0", tampa="#f7d417", sub="ÓLEO DE SOJA 900ml"),
    "sardinha": A(logo="coqueiro", marca="Coqueiro", fonte="serif", tinta="#1c3f99", bg="#f2c418", bg2="#1c3f99", sub="SARDINHAS EM ÓLEO"),
    "maizena": A(logo="maizena", marca="Maizena", fonte="impact", tinta="orig", bg="#f2cf1a", bg2="#d62a1f", sub="AMIDO DE MILHO 500g"),
    # matinal
    "cafe_pilao": A(logo="pilao", marca="Pilão", fonte="impact", tinta="orig", bg="#c8141c", bg2="#f5d20f", sub="CAFÉ TORRADO E MOÍDO 500g"),
    "cafe_melitta": A(logo="melitta", marca="Melitta", fonte="bold", tinta="orig", bg="#8a1a22", bg2="#f5d20f", sub="CAFÉ 500g"),
    "nescau": A(logo="nescau", marca="NESCAU", fonte="impact", tinta="orig", bg="#f5c800", bg2="#6a2a14", tampa="#f5c800", sub="400g"),
    "toddy": A(logo="toddy", marca="Toddy", fonte="impact", tinta="orig", bg="#c8141c", bg2="#f4f0e8", tampa="#c8141c", sub="400g"),
    "ninho": A(logo="ninho", marca="NINHO", fonte="impact", tinta="orig", bg="#f0e6c8", bg2="#1d4f9c", tampa="#1d4f9c", sub="LEITE EM PÓ 400g"),
    # biscoito
    "trakinas": A(logo="trakinas", marca="Trakinas", fonte="impact", tinta="orig", bg="#1c3f9a", bg2="#f5d20f", sub="CHOCOLATE", biscoito="#5a2a14"),
    "passatempo": A(logo="passatempo", marca="Passatempo", fonte="impact", tinta="orig", bg="#1f4fa8", bg2="#d62a1f", sub="RECHEADO", biscoito="#c88a40"),
    "negresco": A(logo="negresco", marca="Negresco", fonte="impact", tinta="orig", bg="#1a1f3a", bg2="#ffffff", sub="RECHEADO", biscoito="#2a1a14"),
    "bono": A(logo="bono", marca="Bono", fonte="impact", tinta="orig", bg="#6a2a14", bg2="#d62a1f", sub="CHOCOLATE 200g", biscoito="#6a3a1a"),
    "club_social": A(logo="clubsocial", marca="Club Social", fonte="bold", tinta="orig", bg="#1b3d8f", bg2="#d62a1f", sub="ORIGINAL"),
    "piraque": A(logo="piraque", marca="Piraquê", fonte="bold", tinta="#ffffff", bg="#d01c20", bg2="#ffffff", sub="CREAM CRACKER"),
    "wafer": A(logo="bauducco", marca="Bauducco", fonte="serif", tinta="orig", bg="#5a2a14", bg2="#1c3f99", sub="WAFER CHOCOLATE"),
    # salgadinho
    "ruffles": A(logo="ruffles", marca="Ruffles", fonte="impact", tinta="orig", bg="#1f3f9f", bg2="#c0c4cc", sub="ORIGINAL", chips="#f2c84a"),
    "cheetos": A(logo="cheetos", marca="Cheetos", fonte="impact", tinta="orig", bg="#f58220", bg2="#f5d20f", sub="REQUEIJÃO", chips="#f58a1f"),
    "fandangos": A(logo="fandangos", marca="Fandangos", fonte="impact", tinta="#d62a1f", bg="#f5d20f", bg2="#2a8a3a", sub="PRESUNTO", chips="#f2c84a"),
    "doritos": A(logo="doritos", marca="Doritos", fonte="impact", tinta="orig", bg="#d0201c", bg2="#1a1a1a", sub="QUEIJO NACHO", chips="#f5a020"),
    "amendoim": A(logo="dori", marca="Dori", fonte="impact", tinta="#ffffff", bg="#d62a1f", bg2="#f5d20f", sub="AMENDOIM JAPONÊS", grao="#d89040"),
    # doce
    "diamante_negro": A(logo="diamantenegro", marca="Diamante Negro", fonte="serif", tinta="#e8e8f0", bg="#1a1414", bg2="#8a1a22", sub="LACTA"),
    "laka": A(logo="laka", marca="Laka", fonte="serif", tinta="#1c3f99", bg="#f2efe6", bg2="#1c3f99", sub="LACTA  CHOCOLATE BRANCO"),
    "lacta_ao_leite": A(logo="lacta", marca="Lacta", fonte="serif", tinta="orig", bg="#3f2a7a", bg2="#f2efe6", sub="AO LEITE 180g"),
    "classic": A(logo="nestle", marca="Nestlé", fonte="serif", tinta="orig", bg="#b01820", bg2="#f2efe6", sub="CLASSIC AO LEITE"),
    "garoto_ao_leite": A(logo="garoto", marca="Garoto", fonte="impact", tinta="orig", bg="#1b3f8f", bg2="#f5d20f", sub="AO LEITE 150g"),
    "bombons_garoto": A(logo="garoto", marca="Garoto", fonte="impact", tinta="orig", bg="#f5c518", bg2="#d62a1f", sub="BOMBONS SORTIDOS 400g", bombons=True),
    "bis": A(logo="bis", marca="BIS", fonte="impact", tinta="#ffffff", bg="#1a3f99", bg2="#f5d20f", sub="LACTA"),
    "sonho_de_valsa": A(logo="sonhodevalsa", marca="Sonho de Valsa", fonte="script", tinta="#f5d27a", bg="#e8487a", bg2="#f5d27a", sub=""),
    "baton": A(logo="baton", marca="Baton", fonte="impact", tinta="#f5d20f", bg="#d01c20", bg2="#1c3f99", sub="GAROTO"),
    "prestigio": A(logo="prestigio", marca="Prestígio", fonte="serif", tinta="#ffffff", bg="#2140a0", bg2="#f2efe6", sub="NESTLÉ"),
    "chokito": A(logo="chokito", marca="Chokito", fonte="impact", tinta="#f5d20f", bg="#d0301c", bg2="#6a2a14", sub="NESTLÉ"),
    "serenata": A(logo="serenata", marca="Serenata", fonte="script", tinta="orig", bg="#c8101c", bg2="#f5d27a", sub="do amor"),
    # bala
    "halls": A(logo="halls", marca="HALLS", fonte="impact", tinta="#ffffff", bg="#0c2a6a", bg2="#1a1a1a", sub="EXTRA FORTE"),
    "trident": A(logo="trident", marca="Trident", fonte="bold", tinta="#ffffff", bg="#1c8a3a", bg2="#ffffff", sub="HORTELÃ"),
    "bubbaloo": A(logo="bubbaloo", marca="Bubbaloo", fonte="impact", tinta="#ffffff", bg="#e0408a", bg2="#f5d20f", sub="MORANGO"),
    "mentos": A(logo="mentos", marca="Mentos", fonte="impact", tinta="orig", bg="#1b56a8", bg2="#e8e8f0", sub="MENTA"),
    # padaria
    "pao_pullman": A(logo="pullman", marca="Pullman", fonte="impact", tinta="#d62a1f", bg="#f5d20f", bg2="#d62a1f", faixa=(0.3, 0.75), grao="#d8a860", sub="PÃO DE FORMA 500g"),
    "bisnaguinha": A(logo="sevenboys", marca="Seven Boys", fonte="impact", tinta="#ffffff", bg="#d62a1f", bg2="#f5d20f", faixa=(0.35, 0.7), grao="#c88a40", sub="BISNAGUINHA"),
    "panetone": A(logo="bauducco", marca="Bauducco", fonte="serif", tinta="orig", bg="#1c3f94", bg2="#c9a44a", sub="PANETONE 500g", estrelas=True),
    # higiene
    "colgate": A(logo="colgate", marca="Colgate", fonte="bold", tinta="#ffffff", bg="#d4151c", bg2="#ffffff", sub="CREME DENTAL 90g"),
    "sorriso": A(logo="sorriso", marca="Sorriso", fonte="impact", tinta="#d62a1f", bg="#ffffff", bg2="#1c3f99", sub="CREME DENTAL 90g"),
    "lux": A(logo="lux", marca="LUX", fonte="serif", tinta="#c9a44a", bg="#e8b0d0", bg2="#c9a44a", sub="SABONETE"),
    "protex": A(logo="protex", marca="Protex", fonte="bold", tinta="#ffffff", bg="#1c8a4a", bg2="#ffffff", sub="ANTIBACTERIANO"),
    "seda": A(logo="seda", marca="Seda", fonte="script", tinta="#ffffff", bg="#e070a0", bg2="#ffffff", tampa="#ffffff", sub="SHAMPOO 350ml"),
    "neutrox": A(logo="neutrox", marca="Neutrox", fonte="impact", tinta="#1c3f99", bg="#f5d020", bg2="#2a8a3a", tampa="#2a8a3a", sub="CONDICIONADOR"),
    "rexona": A(logo="rexona", marca="Rexona", fonte="bold", tinta="#1c3f94", bg="#f2f2f4", bg2="#1c3f94", sub="AEROSSOL"),
    "papel_neve": A(logo="neve", marca="Neve", fonte="script", tinta="#1c3f99", bg="#f4f6fa", bg2="#e8487a", sub="PAPEL HIGIÊNICO 4 ROLOS", rolos=True),
    "prestobarba": A(logo="gillette", marca="Gillette", fonte="bold", tinta="orig", bg="#1c4fa0", bg2="#f58220", sub="PRESTOBARBA"),
    "always": A(logo="always", marca="Always", fonte="bold", tinta="#ffffff", bg="#2a8ac8", bg2="#3aa872", sub="8 UNIDADES"),
    "pampers": A(logo="pampers", marca="Pampers", fonte="bold", tinta="orig", bg="#3aa872", bg2="#ffffff", sub="FRALDA  M"),
    # limpeza
    "detergente": A(logo="ype", marca="Ypê", fonte="impact", tinta="orig", bg="#ffffff", bg2="#1b7a2e", faixa=(0.2, 0.6), liquido="#f0d020", vidro="#f4ecc0", tampa="#f0d020", sub="DETERGENTE NEUTRO"),
    "omo": A(logo="omo", marca="OMO", fonte="impact", tinta="orig", bg="#1d3f99", bg2="#d62a1f", sub="MULTIAÇÃO 1kg"),
    "qboa": A(logo="qboa", marca="Qboa", fonte="impact", tinta="#1c3f99", bg="#ffffff", bg2="#d62a1f", tampa="#1c3f99", sub="ÁGUA SANITÁRIA 1L"),
    "bombril": A(logo="bombril", marca="Bombril", fonte="impact", tinta="#ffffff", bg="#d0201c", bg2="#f5d20f", sub="1001 UTILIDADES"),
    "veja": A(logo="veja", marca="Veja", fonte="impact", tinta="#d62a1f", bg="#ffffff", bg2="#2a8a3a", tampa="#d62a1f", sub="MULTIUSO 500ml"),
    "pinho_sol": A(logo="pinhosol", marca="Pinho Sol", fonte="bold", tinta="#ffffff", bg="#2a7a2a", bg2="#f5d20f", faixa=(0.2, 0.6), liquido="#8a6a1a", vidro="#c8c8a0", tampa="#2a7a2a", sub="DESINFETANTE"),
    "sabao_barra": A(logo="minerva", marca="Minerva", fonte="impact", tinta="#ffffff", bg="#1c4fa0", bg2="#f5d20f", sub="SABÃO EM BARRA 5un"),
    "baygon": A(logo="baygon", marca="Baygon", fonte="impact", tinta="#ffffff", bg="#c8101c", bg2="#1a1a1a", sub="MATA TUDO"),
    "esponja": A(logo="scotchbrite", marca="Scotch-Brite", fonte="bold", tinta="#ffffff", bg="#d62a1f", bg2="#2a8a3a", sub="ESPONJA"),
    # utilidade, farmacia
    "fosforo": A(logo="fiatlux", marca="Fiat Lux", fonte="impact", tinta="#1c3f99", bg="#f5c518", bg2="#d62a1f", sub="FÓSFOROS"),
    "isqueiro": A(logo="bic", marca="BIC", fonte="impact", tinta="#ffffff", bg="#d0201c", bg2="#1a1a1a", sub=""),
    "pilha_rayovac": A(logo="rayovac", marca="Rayovac", fonte="impact", tinta="orig", bg="#1c3f94", bg2="#f58220", sub="AA  2 PILHAS"),
    "pilha_duracell": A(logo="duracell", marca="Duracell", fonte="impact", tinta="orig", bg="#1a1a1a", bg2="#b87333", sub="AA  2 PILHAS"),
    "bandaid": A(logo="bandaid", marca="BAND-AID", fonte="impact", tinta="orig", bg="#ffffff", bg2="#d62a1f", sub="CURATIVOS 10un"),
    "aspirina": A(logo="bayer", marca="Aspirina", fonte="bold", tinta="#1a8a4a", bg="#ffffff", bg2="#1a8a4a", sub="500mg  BAYER"),
    "engov": A(logo="engov", marca="Engov", fonte="impact", tinta="#ffffff", bg="#d62a1f", bg2="#ffffff", sub="6 COMPRIMIDOS"),
    "sonrisal": A(logo="sonrisal", marca="Sonrisal", fonte="impact", tinta="#f5d20f", bg="#1c4fa0", bg2="#ffffff", sub="EFERVESCENTE"),
    # destilado
    "cachaca_51": A(logo="51", marca="51", fonte="impact", tinta="#d62a1f", bg="#f4f0e4", faixa=(0.12, 0.44), liquido="#e8eee8", vidro="#cfe0d4", tampa="#d62a1f", gargalo="#d62a1f", sub="UMA BOA IDEIA"),
    "velho_barreiro": A(logo="velhobarreiro", marca="Velho Barreiro", fonte="serif", tinta="#d62a1f", bg="#f4ecd0", faixa=(0.12, 0.44), liquido="#e8eee8", vidro="#cfe0d4", tampa="#d62a1f", gargalo="#c9a44a", sub="CACHAÇA"),
    "catuaba": A(logo="catuaba", marca="Catuaba", fonte="script", tinta="#f5d20f", bg="#6a1a2a", faixa=(0.12, 0.46), liquido="#3a0a14", vidro="#2a0a10", tampa="#c9a44a", gargalo="#f5d20f", sub="SELVAGEM"),
    "dreher": A(logo="dreher", marca="Dreher", fonte="serif", tinta="#d62a1f", bg="#f5d27a", faixa=(0.12, 0.44), liquido="#b8701a", vidro="#a86a20", tampa="#d62a1f", gargalo="#d62a1f", sub="CONHAQUE"),
    "orloff": A(logo="orloff", marca="Orloff", fonte="serif", tinta="#1c3f99", bg="#ffffff", bg2="#d62a1f", faixa=(0.12, 0.46), liquido="#eef2f2", vidro="#dfe8e8", tampa="#d62a1f", gargalo="#d62a1f", sub="VODKA"),
    # cigarro
    "hollywood": A(logo="hollywood", foto=True, marca="Hollywood", fonte="script", tinta="#1c3f99", bg="#ffffff", bg2="#d62a1f", sub="AO SUCESSO", maco="topo"),
    "free": A(logo="free", foto=True, marca="FREE", fonte="impact", tinta="#1c3f99", bg="#ffffff", bg2="#5ab0e8", sub="", maco="faixa"),
    "derby": A(logo=None, marca="Derby", fonte="serif", tinta="#ffffff", bg="#1c3f8f", bg2="#d62a1f", sub="", maco="faixa"),
    "marlboro": A(logo="marlboro", marca="Marlboro", fonte="serif", tinta="orig", bg="#ffffff", bg2="#d0141c", sub="", maco="nenhum"),
    "carlton": A(logo=None, marca="Carlton", fonte="serif", tinta="#1c3f99", bg="#f4f4f6", bg2="#8a9ab8", sub="", maco="topo"),
    "minister": A(logo=None, marca="Minister", fonte="serif", tinta="#ffffff", bg="#1c4f9f", bg2="#ffffff", sub="", maco="topo"),
    "charm": A(logo="charm", foto=True, marca="Charm", fonte="script", tinta="#c9a44a", bg="#f4ece0", bg2="#7a1a2a", sub="", maco="faixa"),
}

FORMAS = ["LATA", "PET", "GARRAFA", "CAIXA", "PACOTE", "POTE", "BARRA", "MACO", "FRASCO"]


# --- catalogo ------------------------------------------------------------------

def ler_catalogo() -> list[dict]:
    """id, curto, preco e forma de cada linha de catalogo_mercado.gd."""
    linha = re.compile(r'^\t\{"id": &"(\w+)", "curto": "([^"]*)", "preco": (\d+),.*"forma": Forma\.(\w+),')
    saida = []
    for t in CATALOGO.read_text(encoding="utf-8").splitlines():
        m = linha.match(t)
        if m:
            saida.append({"id": m[1], "curto": m[2], "preco": int(m[3]), "forma": m[4]})
    # Toda linha que parece produto tem de casar: uma que escapa vira produto
    # sem rotulo nem etiqueta, e isso so apareceria na prateleira.
    candidatas = [t for t in CATALOGO.read_text(encoding="utf-8").splitlines()
                  if t.startswith('	{"id": &"')]
    if not saida or len(candidatas) != len(saida):
        raise SystemExit(f"catalogo_mercado.gd: {len(candidatas)} linhas de produto, "
                         f"{len(saida)} no formato esperado")
    return saida


# --- rede -----------------------------------------------------------------------

def _pedir(url: str) -> bytes:
    espera = 4.0
    for _ in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            time.sleep(espera)
            espera *= 2.0
    raise RuntimeError("429 insistente")


def logo(chave: str, bruto: bool = False) -> Image.Image | None:
    """O logo em RGBA, do cache ou do Commons (renderizado a 600 px)."""
    arquivo = LOGOS.get(chave)
    if not arquivo:
        return None
    CACHE.mkdir(parents=True, exist_ok=True)
    local = CACHE / (chave + "_" + hashlib.md5(arquivo.encode()).hexdigest()[:8] + ".png")
    if not local.exists():
        host = "commons.wikimedia.org"
        titulo = arquivo
        if "|" in arquivo:
            lang, titulo = arquivo.split("|", 1)
            host = f"{lang}.wikipedia.org"
        # Miniatura PNG pela API, e nao o original: e o que a Wikimedia pede de
        # quem baixa em lote, e o SVG sai rasterizado de graca.
        q = urllib.parse.urlencode({"action": "query", "titles": titulo, "prop": "imageinfo",
                                    "iiprop": "url", "iiurlwidth": 600, "format": "json"})
        try:
            dados = json.loads(_pedir(f"https://{host}/w/api.php?" + q))
            pagina = next(iter(dados["query"]["pages"].values()))
            url = pagina["imageinfo"][0].get("thumburl") or pagina["imageinfo"][0]["url"]
            local.write_bytes(_pedir(url))
            time.sleep(3.0)
        except Exception as e:  # noqa: BLE001
            print(f"  logo {chave}: falhou {e}")
            return None
    img = Image.open(local).convert("RGBA")
    if bruto:
        return img
    # Logo em JPG vem sem transparencia: o fundo quase branco vira alfa.
    if img.getextrema()[3][0] == 255:
        cinza = img.convert("L")
        alfa = cinza.point(lambda v: 0 if v > 238 else 255)
        img.putalpha(alfa)
    caixa = img.getbbox()
    return img.crop(caixa) if caixa else None


# --- desenho --------------------------------------------------------------------

def cor(h: str | None, padrao=(128, 128, 128)):
    if not h:
        return padrao
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def fonte(nome: str, tam: int) -> ImageFont.FreeTypeFont:
    arq = {"impact": "impact.ttf", "script": "segoescb.ttf", "serif": "georgiab.ttf",
           "bold": "arialbd.ttf", "narrow": "bahnschrift.ttf", "texto": "arialbd.ttf"}[nome]
    return ImageFont.truetype(FONTES + arq, tam)


def linha_y(h: float) -> int:
    """Altura do produto (0 embaixo, 1 em cima) -> linha de pixel da celula."""
    return round(TOPO + (1.0 - h) * (W - TOPO))


def escrever_caixa(img: Image.Image, texto: str, fonte_nome: str, caixa, tinta, sombra=None):
    """Texto centrado que cabe em `caixa` (x0, y0, x1, y1), encolhendo."""
    if not texto:
        return
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = caixa
    tam = int((y1 - y0) * 0.95)
    while tam > 6:
        f = fonte(fonte_nome, tam)
        b = d.textbbox((0, 0), texto, font=f)
        if b[2] - b[0] <= (x1 - x0) and b[3] - b[1] <= (y1 - y0):
            break
        tam -= 2
    f = fonte(fonte_nome, tam)
    b = d.textbbox((0, 0), texto, font=f)
    x = (x0 + x1 - (b[2] - b[0])) // 2 - b[0]
    y = (y0 + y1 - (b[3] - b[1])) // 2 - b[1]
    if sombra is not None:
        d.text((x + 3, y + 3), texto, font=f, fill=sombra)
    d.text((x, y), texto, font=f, fill=tinta)


def por_logo(img: Image.Image, a: dict, caixa, pastiche: bool):
    x0, y0, x1, y1 = caixa
    lg = None if pastiche else logo(a.get("logo") or "")
    if lg is None:
        nome = a["marca"]
        if pastiche:
            nome = PASTICHE.get(a.get("logo") or "", "Marca " + a["marca"][:1])
        escrever_caixa(img, nome, a.get("fonte", "bold"), caixa, cor(a.get("tinta")) if a.get("tinta") != "orig" else (255, 255, 255),
                       sombra=(0, 0, 0, 90))
        return
    if a.get("placa"):
        # Placa clara atras do logo: o azul do logo da Pepsi some no azul da lata.
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((x0 - 6, y0 - 6, x1 + 6, y1 + 6), radius=18, fill=cor(a["placa"]))
    if a.get("tinta") and a["tinta"] != "orig":
        solido = Image.new("RGBA", lg.size, cor(a["tinta"]) + (255,))
        solido.putalpha(lg.getchannel("A"))
        lg = solido
    w, h = lg.size
    k = min((x1 - x0) / w, (y1 - y0) / h)
    lg = lg.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
    img.alpha_composite(lg, ((x0 + x1 - lg.width) // 2, (y0 + y1 - lg.height) // 2))


def codigo_de_barras(d: ImageDraw.ImageDraw, x, y, w, h, semente: int):
    d.rectangle((x - 4, y - 4, x + w + 4, y + h + 4), fill=(250, 250, 250))
    r = semente
    xx = x
    while xx < x + w:
        r = (r * 1103515245 + 12345) & 0x7FFFFFFF
        larg = 2 + (r >> 8) % 5
        if (r >> 4) & 1:
            d.rectangle((xx, y, xx + larg - 1, y + h), fill=(20, 20, 20))
        xx += larg


def costas(img: Image.Image, a: dict, y0: int, y1: int, semente: int, pastiche: bool):
    """A metade de tras: logo pequeno, tabela nutricional e codigo de barras."""
    d = ImageDraw.Draw(img)
    x0, x1 = W // 2, W
    bg2 = cor(a.get("bg2"), cor(a.get("bg")))
    # A lateral (u 0,5 a 0,625 e 0,875 a 1 nas caixas) leva a faixa de cor.
    d.rectangle((x0, y0, x0 + W // 8, y1), fill=bg2)
    d.rectangle((W - W // 8, y0, x1, y1), fill=bg2)
    meio0, meio1 = x0 + W // 8 + 8, W - W // 8 - 8
    alto = y1 - y0
    por_logo(img, a, (meio0 + 10, y0 + int(alto * 0.08), meio1 - 10, y0 + int(alto * 0.3)), pastiche)
    # Tabela: um quadro claro com linhas.
    ty0 = y0 + int(alto * 0.36)
    ty1 = y0 + int(alto * 0.66)
    d.rectangle((meio0 + 8, ty0, meio1 - 8, ty1), fill=(246, 244, 236), outline=(40, 40, 40), width=2)
    for k in range(5):
        yy = ty0 + 10 + k * max(6, (ty1 - ty0 - 20) // 5)
        d.line((meio0 + 16, yy, meio1 - 16, yy), fill=(90, 90, 90), width=2)
    codigo_de_barras(d, meio0 + 20, y0 + int(alto * 0.74), meio1 - meio0 - 40, int(alto * 0.16), semente)


def compor(pid: str, forma: str, a: dict, pastiche: bool) -> Image.Image:
    img = Image.new("RGBA", (W, W), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    bg = cor(a.get("bg"))
    bg2 = cor(a.get("bg2"), bg)
    semente = int(hashlib.md5(pid.encode()).hexdigest()[:8], 16)
    tampa = cor(a.get("tampa"), bg)

    # --- o corpo, conforme a forma ---
    faixa = a.get("faixa")
    transparente = "liquido" in a
    if transparente:
        vidro = cor(a.get("vidro"), (200, 210, 205))
        liq = cor(a["liquido"])
        perfil = {"PET": PERFIL_PET, "GARRAFA": PERFIL_GARRAFA, "FRASCO": PERFIL_FRASCO}.get(forma, PERFIL_PET)
        # O ar em cima do liquido, o liquido embaixo; o vidro tinge os dois.
        mistura = tuple((l * 3 + v) // 4 for l, v in zip(liq, vidro))
        d.rectangle((0, TOPO, W, W), fill=vidro)
        nivel = perfil["ombro"][0] + (perfil["ombro"][1] - perfil["ombro"][0]) * 0.35
        d.rectangle((0, linha_y(nivel), W, W), fill=mistura)
        # Reflexo vertical do vidro: e o que faz plastico ler como plastico.
        for x, alfa in ((W * 0.14, 90), (W * 0.2, 50)):
            d.rectangle((int(x), TOPO, int(x) + W // 40, W), fill=tuple(min(255, c + alfa) for c in mistura))
        yt0, yt1 = perfil["tampa"]
        d.rectangle((0, linha_y(yt1), W, linha_y(yt0)), fill=tampa)
        if "gargalo" in a and "gargalo" in perfil:
            g0, g1 = perfil["gargalo"]
            d.rectangle((0, linha_y(g1 - 0.02), W, linha_y(g0 + 0.06)), fill=cor(a["gargalo"]))
        y0, y1 = (linha_y(faixa[1]), linha_y(faixa[0])) if faixa else (linha_y(0.55), linha_y(0.2))
        d.rectangle((0, y0, W, y1), fill=bg)
        d.rectangle((0, y1 - (y1 - y0) // 7, W, y1), fill=bg2)
    elif forma in ("POTE",):
        d.rectangle((0, TOPO, W, W), fill=bg)
        y_t = linha_y(PERFIL_POTE["tampa"][0])
        d.rectangle((0, TOPO, W, y_t), fill=tampa)
        d.rectangle((0, W - (W - y_t) // 6, W, W), fill=bg2)
        y0, y1 = y_t, W
    elif forma == "LATA":
        d.rectangle((0, TOPO, W, W), fill=bg)
        # Borda de aluminio em cima e embaixo, como a lata tem.
        d.rectangle((0, TOPO, W, linha_y(0.93)), fill=(196, 198, 200))
        d.rectangle((0, linha_y(0.05), W, W), fill=(176, 178, 180))
        y0, y1 = linha_y(0.93), linha_y(0.05)
        if a.get("onda"):
            pts = [(x, int(y0 + (y1 - y0) * (0.72 + 0.08 * math.sin(x / W * 12.5))))
                   for x in range(0, W + 1, 8)]
            d.line(pts, fill=cor(a["onda"]), width=W // 36)
        if a.get("bg2") and not a.get("onda"):
            d.rectangle((0, y1 - (y1 - y0) // 6, W, y1 - (y1 - y0) // 10), fill=bg2)
            d.rectangle((0, y0 + (y1 - y0) // 10, W, y0 + (y1 - y0) // 6), fill=bg2)
        # O brilho do aluminio, dois riscos verticais.
        for x, alfa in ((W * 0.12, 70), (W * 0.36, 40)):
            base = img.crop((int(x), y0, int(x) + W // 36, y1))
            claro = Image.new("RGBA", base.size, (255, 255, 255, alfa))
            base.alpha_composite(claro)
            img.paste(base, (int(x), y0))
    elif forma == "PACOTE":
        d.rectangle((0, TOPO, W, W), fill=bg)
        # Costura serrilhada em cima e embaixo.
        for yy0, yy1 in ((linha_y(1.0), linha_y(0.9)), (linha_y(0.06), W)):
            d.rectangle((0, yy0, W, yy1), fill=bg2)
            for x in range(0, W, 12):
                d.line((x, yy0, x + 6, yy1), fill=tuple(max(0, c - 40) for c in bg2), width=2)
        y0, y1 = linha_y(0.9), linha_y(0.06)
        if faixa:
            # Pacote transparente com faixa: pao, feijao, macarrao a mostra.
            grao = cor(a.get("grao"), bg)
            d.rectangle((0, y0, W, y1), fill=grao)
            rr = semente
            for _ in range(900):
                rr = (rr * 1103515245 + 12345) & 0x7FFFFFFF
                x = rr % W
                y = y0 + (rr >> 12) % max(1, (y1 - y0))
                t = 30 - (rr >> 20) % 60
                d.ellipse((x, y, x + 10, y + 7), fill=tuple(max(0, min(255, c + t)) for c in grao))
            fy0, fy1 = linha_y(faixa[1]), linha_y(faixa[0])
            d.rectangle((0, fy0, W, fy1), fill=bg)
            d.rectangle((0, fy1 - (fy1 - fy0) // 6, W, fy1), fill=bg2)
            y0, y1 = fy0, fy1
    else:  # CAIXA, BARRA, MACO, FRASCO sem liquido
        d.rectangle((0, TOPO, W, W), fill=bg)
        y0, y1 = TOPO, W
        if forma == "FRASCO":
            y_t = linha_y(PERFIL_FRASCO["tampa"][0])
            d.rectangle((0, TOPO, W, y_t), fill=tampa)
            d.rectangle((0, y_t, W, linha_y(PERFIL_FRASCO["ombro"][0])), fill=bg)
            y0 = linha_y(PERFIL_FRASCO["ombro"][0])
        if forma == "MACO":
            estilo = a.get("maco", "faixa")
            if estilo == "chevron":
                # O telhado vermelho do Marlboro.
                meio = W // 4
                topo_ch = TOPO
                base_ch = TOPO + int((W - TOPO) * 0.55)
                d.polygon([(0, topo_ch), (W // 2, topo_ch), (W // 2, base_ch), (meio, base_ch - (W - TOPO) // 5), (0, base_ch)], fill=bg2)
                d.rectangle((W // 2, topo_ch, W, base_ch - (W - TOPO) // 10), fill=bg2)
            elif estilo == "topo":
                d.rectangle((0, TOPO, W, TOPO + (W - TOPO) // 4), fill=bg2)
            else:
                meio = TOPO + (W - TOPO) // 2
                d.rectangle((0, meio - (W - TOPO) // 10, W, meio + (W - TOPO) // 10), fill=bg2)
        elif a.get("bg2"):
            d.rectangle((0, y1 - (y1 - y0) // 7, W, y1), fill=bg2)
            d.rectangle((0, y0, W, y0 + (y1 - y0) // 14), fill=bg2)

    # --- ilustracao da frente ---
    fx0, fx1 = 0, W // 2
    alto = y1 - y0
    ilus = None
    for chave in ("fruta", "chips", "biscoito", "prato"):
        if chave in a:
            ilus = cor(a[chave])
    if ilus is not None and forma != "LATA":
        cx, cy = (fx0 + fx1) // 2, y0 + int(alto * 0.72)
        rr = semente
        for k in range(5):
            rr = (rr * 1103515245 + 12345) & 0x7FFFFFFF
            ox = (rr % 120) - 60
            oy = ((rr >> 8) % 40) - 20
            raio = 26 + (rr >> 16) % 14
            d.ellipse((cx + ox - raio, cy + oy - raio * 0.7, cx + ox + raio, cy + oy + raio * 0.7), fill=ilus,
                      outline=tuple(max(0, c - 60) for c in ilus), width=3)
    if a.get("bombons"):
        for k in range(6):
            cx = fx0 + 40 + (k % 3) * 80
            cy = y0 + int(alto * 0.62) + (k // 3) * 60
            d.ellipse((cx - 26, cy - 22, cx + 26, cy + 22), fill=[(200, 30, 40), (240, 200, 60), (60, 90, 170)][k % 3])
    if a.get("estrelas"):
        for k in range(9):
            cx = (k * 97 + 31) % W
            cy = y0 + (k * 53) % max(1, alto)
            d.regular_polygon((cx, cy, 10), 5, fill=cor(a.get("bg2")))
    if a.get("vaca"):
        d.rectangle((fx0 + 40, y0 + int(alto * 0.62), fx1 - 40, y0 + int(alto * 0.88)), fill=(90, 150, 60))
    if a.get("rolos"):
        for k in range(2):
            cx = fx0 + 80 + k * 100
            cy = y0 + int(alto * 0.68)
            d.ellipse((cx - 40, cy - 40, cx + 40, cy + 40), fill=(250, 250, 252), outline=(180, 180, 190), width=4)
            d.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), fill=(200, 180, 150))

    # --- logo, descricao ---
    foto = None if pastiche or not a.get("foto") else logo(a.get("logo") or "", bruto=True)
    if foto is not None:
        # A frente do maco e a propria foto da embalagem, recortada na
        # proporcao da face.
        alvo = (fx1 - fx0) / (y1 - y0)
        w, h = foto.size
        if w / h > alvo:
            nw = int(h * alvo)
            foto = foto.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
        else:
            nh = int(w / alvo)
            foto = foto.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        img.paste(foto.convert("RGB").resize((fx1 - fx0, y1 - y0), Image.LANCZOS), (fx0, y0))
        caixa_logo = (0, 0, 0, 0)
    elif forma == "MACO" and a.get("maco") == "nenhum":
        caixa_logo = (fx0 + 6, y0 + int(alto * 0.08), fx1 - 6, y0 + int(alto * 0.92))
    elif forma == "MACO":
        caixa_logo = (fx0 + 14, y0 + int(alto * 0.5), fx1 - 14, y0 + int(alto * 0.72))
    elif ilus is not None or a.get("bombons") or a.get("vaca") or a.get("rolos"):
        caixa_logo = (fx0 + 14, y0 + int(alto * 0.1), fx1 - 14, y0 + int(alto * 0.42))
    else:
        caixa_logo = (fx0 + 14, y0 + int(alto * 0.18), fx1 - 14, y0 + int(alto * 0.6))
    if foto is None:
        por_logo(img, a, caixa_logo, pastiche)
    fg = (255, 255, 255) if sum(bg) < 380 else (25, 25, 30)
    sub = a.get("sub", "")
    if sub and foto is None:
        sy = caixa_logo[3] + int(alto * 0.03)
        escrever_caixa(img, sub, "texto", (fx0 + 16, sy, fx1 - 16, sy + max(20, int(alto * 0.1))), fg)
    if forma == "MACO":
        # 1998: a advertencia ainda era frase de rodape, sem foto.
        d2 = ImageDraw.Draw(img)
        escrever_caixa(img, "O MINISTÉRIO DA SAÚDE ADVERTE:", "texto", (W // 2 + 20, y0 + int(alto * 0.35), W - 20, y0 + int(alto * 0.42)), (20, 20, 20))
        escrever_caixa(img, "FUMAR É PREJUDICIAL À SAÚDE", "texto", (W // 2 + 20, y0 + int(alto * 0.44), W - 20, y0 + int(alto * 0.51)), (20, 20, 20))
        d2.rectangle((W // 2 + 12, y0 + int(alto * 0.32), W - 12, y0 + int(alto * 0.54)), outline=(20, 20, 20), width=3)
    else:
        costas(img, a, y0, y1, semente, pastiche)

    # --- topo ---
    if forma == "LATA":
        d.rectangle((0, 0, W // 2, TOPO), fill=(200, 202, 204))
        d.ellipse((W // 4 - 30, TOPO // 2 - 14, W // 4 + 50, TOPO // 2 + 14), outline=(150, 150, 154), width=6)
    elif forma in ("PET", "GARRAFA", "FRASCO", "POTE") or transparente:
        d.rectangle((0, 0, W // 2, TOPO), fill=tampa)
        if forma == "POTE":
            por_logo(img, a, (W // 8, 6, W * 3 // 8, TOPO - 6), pastiche)
    else:
        d.rectangle((0, 0, W // 2, TOPO), fill=bg2 if forma == "PACOTE" else bg)
    d.rectangle((W // 2, 0, W, TOPO), fill=bg)
    return img.convert("RGB")


def etiqueta(p: dict) -> Image.Image:
    """Etiqueta amarela de gondola: nome curto, preco grande, codigo embaixo."""
    w, h = CEL_ETIQUETA[0] * ESCALA, CEL_ETIQUETA[1] * ESCALA
    img = Image.new("RGBA", (w, h), (246, 214, 26, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), outline=(40, 30, 0), width=4)
    escrever_caixa(img, p["curto"], "texto", (14, 8, w - 14, int(h * 0.3)), (20, 20, 20))
    reais, cent = divmod(p["preco"], 100)
    escrever_caixa(img, "R$", "texto", (14, int(h * 0.42), int(w * 0.2), int(h * 0.62)), (20, 20, 20))
    escrever_caixa(img, f"{reais},{cent:02d}", "impact", (int(w * 0.2), int(h * 0.3), int(w * 0.8), int(h * 0.95)), (20, 20, 20))
    codigo_de_barras(d, int(w * 0.82), int(h * 0.45), int(w * 0.14), int(h * 0.4),
                     int(hashlib.md5(p["id"].encode()).hexdigest()[:8], 16))
    return img.convert("RGB")


def colar(atlas: Image.Image, img: Image.Image, x: int, y: int, cel) -> None:
    """Reduz para a celula e cola com guarda (a beira repetida para fora)."""
    img = img.resize(cel, Image.LANCZOS)
    w, h = cel
    miolo = img.resize((w - GUARDA * 2, h - GUARDA * 2), Image.LANCZOS)
    borda = miolo.resize((w, h), Image.NEAREST)
    atlas.paste(borda, (x, y))
    atlas.paste(miolo, (x + GUARDA, y + GUARDA))


def main() -> int:
    pastiche = "--pastiche" in sys.argv
    produtos = ler_catalogo()
    faltam = [p["id"] for p in produtos if p["id"] not in ARTE]
    if faltam:
        raise SystemExit(f"sem arte na tabela ARTE: {faltam}")
    if len(produtos) > POR_LINHA * (Y_ETIQUETAS // CEL):
        raise SystemExit("atlas cheio de rotulos")

    atlas = Image.new("RGB", (LADO, LADO), (18, 18, 20))
    ids = []
    for k, p in enumerate(produtos):
        img = compor(p["id"], p["forma"], ARTE[p["id"]], pastiche)
        colar(atlas, img, (k % POR_LINHA) * CEL, (k // POR_LINHA) * CEL, (CEL, CEL))
        eti = etiqueta(p)
        por_linha_e = LADO // CEL_ETIQUETA[0]
        colar(atlas, eti, (k % por_linha_e) * CEL_ETIQUETA[0],
              Y_ETIQUETAS + (k // por_linha_e) * CEL_ETIQUETA[1], CEL_ETIQUETA)
        ids.append(p["id"])
    print(f"{len(ids)} rotulos e etiquetas ({'pastiche' if pastiche else 'marcas reais'})")

    hd = RAIZ / "game/assets/textures_hd/rotulos.jpg"
    atlas.save(hd, "JPEG", quality=92)
    ps1 = atlas.resize((512, 512), Image.LANCZOS).quantize(256).convert("RGB")
    ps1.save(RAIZ / "game/assets/textures/rotulos.png", optimize=True)

    por_linha_e = LADO // CEL_ETIQUETA[0]
    gd = RAIZ / "game/src/world/mercado/rotulos_atlas.gd"
    gd.write_text(
        "## Gerado por tools/baixar_rotulos.py. Nao editar a mao.\n"
        "##\n"
        "## Onde cada rotulo e cada etiqueta de preco esta no atlas `rotulos`\n"
        "## (textures/rotulos.png no PS1, textures_hd/rotulos.jpg no MODERNO). UV de 0\n"
        "## a 1, origem no canto de cima. Produto que nao esta aqui cai na celula 0.\n"
        "class_name RotulosAtlas\n"
        "extends RefCounted\n\n"
        f"const LADO := {LADO}.0\n"
        f"const PASTICHE := {'true' if pastiche else 'false'}\n"
        f"const IDS: PackedStringArray = {json.dumps(ids)}\n\n"
        "static var _indice: Dictionary = {}\n\n\n"
        "static func _k(id: StringName) -> int:\n"
        "\tif _indice.is_empty():\n"
        "\t\tfor i in IDS.size():\n"
        "\t\t\t_indice[StringName(IDS[i])] = i\n"
        "\treturn int(_indice.get(id, 0))\n\n\n"
        "static func celula(id: StringName) -> Rect2:\n"
        "\tvar k := _k(id)\n"
        f"\tvar x := float(k % {POR_LINHA}) * {CEL}.0 + {GUARDA}.0\n"
        f"\tvar y := float(k / {POR_LINHA}) * {CEL}.0 + {GUARDA}.0\n"
        f"\treturn Rect2(x / LADO, y / LADO, {CEL - GUARDA * 2}.0 / LADO, {CEL - GUARDA * 2}.0 / LADO)\n\n\n"
        "static func etiqueta(id: StringName) -> Rect2:\n"
        "\tvar k := _k(id)\n"
        f"\tvar x := float(k % {por_linha_e}) * {CEL_ETIQUETA[0]}.0 + {GUARDA}.0\n"
        f"\tvar y := {Y_ETIQUETAS}.0 + float(k / {por_linha_e}) * {CEL_ETIQUETA[1]}.0 + {GUARDA}.0\n"
        f"\treturn Rect2(x / LADO, y / LADO, {CEL_ETIQUETA[0] - GUARDA * 2}.0 / LADO, {CEL_ETIQUETA[1] - GUARDA * 2}.0 / LADO)\n",
        encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

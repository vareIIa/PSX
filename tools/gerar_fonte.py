#!/usr/bin/env python3
"""Gera fontes bitmap sem antialiasing, no formato AngelCode que o Godot le.

O ART-BIBLE secao 6 e explicito: texto suave numa tela de 480x270 destroi a
ilusao mais rapido que qualquer outra coisa. Fonte de sistema renderizada pelo
motor sai com antialiasing e meio-tom; aqui cada glifo e limiarizado para preto
ou branco e empacotado num atlas, entao o texto tem exatamente a mesma dureza de
pixel do resto da imagem.

    python tools/gerar_fonte.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "fontes"
FONTES_SISTEMA = Path("C:/Windows/Fonts")

# Latim basico mais o que o portugues usa. Sem isso "coração" vira "cora??o".
GLIFOS = (
    " !\"#$%&'()*+,-./0123456789:;<=>?@"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
    "abcdefghijklmnopqrstuvwxyz{|}~"
    "ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ"
    "áàâãäéèêëíìîïóòôõöúùûüçñ°º·…—“”‘’"
)

# nome de saida -> (arquivo do sistema, tamanho, limiar)
#
# O limiar controla a espessura: mais baixo engorda a letra. Ajustado por
# tamanho porque o mesmo valor deixa a fonte pequena rala e a grande borrada.
PERFIS = {
    "psx_pequena": ("arial.ttf", 11, 120),
    "psx_media": ("arial.ttf", 14, 128),
    "psx_titulo": ("arialbd.ttf", 18, 132),
    "psx_mono": ("consola.ttf", 12, 122),
}


def renderizar(caminho_ttf: Path, tamanho: int, limiar: int) -> tuple[Image.Image, list, int, int]:
    fonte = ImageFont.truetype(str(caminho_ttf), tamanho)
    ascent, descent = fonte.getmetrics()
    altura_linha = ascent + descent

    glifos = []
    for ch in GLIFOS:
        caixa = fonte.getbbox(ch)
        avanco = int(round(fonte.getlength(ch)))
        larg = max(1, caixa[2] - caixa[0]) if caixa else 1
        alt = max(1, caixa[3] - caixa[1]) if caixa else 1
        glifos.append({"ch": ch, "w": larg, "h": alt,
                       "ox": caixa[0], "oy": caixa[1], "av": avanco})

    # Empacota em linhas de largura fixa. Atlas quadrado seria mais elegante e
    # nao vale a complexidade para 200 glifos.
    largura = 256
    x, y, linha_alt = 0, 0, 0
    for g in glifos:
        if x + g["w"] + 1 > largura:
            x, y = 0, y + linha_alt + 1
            linha_alt = 0
        g["x"], g["y"] = x, y
        x += g["w"] + 1
        linha_alt = max(linha_alt, g["h"])
    altura = y + linha_alt + 1

    atlas = Image.new("L", (largura, altura), 0)
    for g in glifos:
        if g["ch"] == " ":
            continue
        celula = Image.new("L", (g["w"] + 4, g["h"] + 4), 0)
        ImageDraw.Draw(celula).text((2 - g["ox"], 2 - g["oy"]), g["ch"], fill=255, font=fonte)
        # Limiar duro: e o passo que tira o meio-tom e deixa a letra com borda
        # de pixel, igual ao resto do contrato.
        celula = celula.point(lambda v: 255 if v >= limiar else 0)
        atlas.paste(celula.crop((2, 2, 2 + g["w"], 2 + g["h"])), (g["x"], g["y"]))

    rgba = Image.new("RGBA", atlas.size, (255, 255, 255, 0))
    rgba.putalpha(atlas)
    return rgba, glifos, ascent, altura_linha


def escrever_fnt(nome: str, glifos: list, ascent: int, altura_linha: int,
                 tam_atlas: tuple[int, int], tamanho: int) -> None:
    linhas = [
        f'info face="{nome}" size={tamanho} bold=0 italic=0 charset="" unicode=1 '
        f"stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1",
        f"common lineHeight={altura_linha} base={ascent} "
        f"scaleW={tam_atlas[0]} scaleH={tam_atlas[1]} pages=1 packed=0",
        f'page id=0 file="{nome}.png"',
        f"chars count={len(glifos)}",
    ]
    for g in glifos:
        linhas.append(
            f"char id={ord(g['ch'])} x={g['x']} y={g['y']} width={g['w']} height={g['h']} "
            f"xoffset={g['ox']} yoffset={g['oy']} xadvance={g['av']} page=0 chnl=15")
    (SAIDA / f"{nome}.fnt").write_text("\n".join(linhas) + "\n", encoding="utf-8")


def main() -> int:
    SAIDA.mkdir(parents=True, exist_ok=True)
    for nome, (arquivo, tamanho, limiar) in PERFIS.items():
        ttf = FONTES_SISTEMA / arquivo
        if not ttf.exists():
            print(f"{nome:16s} fonte de sistema ausente: {arquivo}")
            continue
        atlas, glifos, ascent, altura = renderizar(ttf, tamanho, limiar)
        atlas.save(SAIDA / f"{nome}.png", "PNG", optimize=True)
        escrever_fnt(nome, glifos, ascent, altura, atlas.size, tamanho)
        print(f"{nome:16s} {arquivo:14s} {tamanho:2d}px  "
              f"atlas {atlas.width}x{atlas.height}  {len(glifos)} glifos")

    print(f"\n{len(list(SAIDA.glob('*.fnt')))} fontes bitmap")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

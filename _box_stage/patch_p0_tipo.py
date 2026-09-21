# -*- coding: utf-8 -*-
from pathlib import Path
import re

UI = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui")
PR = UI / "prancha_inventario.gd"
MS = UI / "menu_sistema.gd"

def sub1(t, old, new, name):
    if old not in t:
        raise SystemExit(f"FAIL {name}: not found\n---\n{old[:120]}")
    return t.replace(old, new, 1)

def patch_prancha(t: str) -> str:
    t = sub1(t,
        "const FAIXA := Rect2(12.0, 32.0, 456.0, 60.0)\nconst ICONE := 42.0\nconst ICONE_VITRINE := 52.0\n",
        "const FAIXA := Rect2(12.0, 28.0, 456.0, 32.0)  ## SPEC_POLISH §3.1 Y 28–60\nconst ICONE := 28.0\nconst ICONE_VITRINE := 36.0\n",
        "faixa/icone")

    t = sub1(t,
        "\tUiEstilo.aplicar_re7(l, tamanho, peso)\n\tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF\n",
        "\tUiEstilo.aplicar_re7(l, tamanho, peso)\n"
        "\t# SPEC_POLISH — line-height / tracking por papel (RE7_LINE_*).\n"
        "\tvar lh := UiEstilo.RE7_LINE_BODY\n"
        "\tvar track := 0\n"
        "\tif tamanho >= UiEstilo.RE7_SIZE_DISPLAY:\n"
        "\t\tlh = UiEstilo.RE7_LINE_DISPLAY\n"
        "\t\ttrack = 1\n"
        "\telif tamanho >= UiEstilo.RE7_SIZE_TITLE:\n"
        "\t\tlh = UiEstilo.RE7_LINE_TITLE\n"
        "\t\ttrack = 1\n"
        "\telif tamanho <= UiEstilo.RE7_SIZE_MICRO:\n"
        "\t\tlh = UiEstilo.RE7_LINE_MICRO\n"
        "\t\ttrack = 1\n"
        "\tl.add_theme_constant_override(&\"line_spacing\", maxi(0, lh - tamanho))\n"
        "\tif track != 0:\n"
        "\t\tl.add_theme_constant_override(&\"letter_spacing\", track)\n"
        "\tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF\n",
        "rotulo metrics")

    t = sub1(t,
        "\tvar pedacos := [\n"
        "\t\tRect2(118.0, 22.0, 68.0, 22.0), Rect2(178.0, 19.0, 76.0, 24.0),\n"
        "\t\tRect2(246.0, 23.0, 72.0, 21.0), Rect2(308.0, 20.0, 62.0, 22.0),\n"
        "\t]\n"
        "\tvar giros := [-2.5, 1.2, -0.8, 2.0]\n"
        "\tfor i in pedacos.size():\n"
        "\t\t_imagem(\"ui_fita\", pedacos[i], TextureRect.STRETCH_SCALE, giros[i])\n"
        "\t_rotulo(\"INVENTÁRIO\", Rect2(140.0, 22.0, 200.0, 22.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, false, null, 600)\n",
        "\tvar pedacos := [\n"
        "\t\tRect2(118.0, 10.0, 68.0, 22.0), Rect2(178.0, 8.0, 76.0, 24.0),\n"
        "\t\tRect2(246.0, 11.0, 72.0, 21.0), Rect2(308.0, 9.0, 62.0, 22.0),\n"
        "\t]\n"
        "\tvar giros := [-2.5, 1.2, -0.8, 2.0]\n"
        "\tfor i in pedacos.size():\n"
        "\t\t_imagem(\"ui_fita\", pedacos[i], TextureRect.STRETCH_SCALE, giros[i])\n"
        "\t# DISPLAY only here — baseline ~20 (SPEC_POLISH §3.1 / §4)\n"
        "\t_rotulo(\"INVENTÁRIO\", Rect2(140.0, 8.0, 200.0, 24.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, false, null, 600)\n",
        "titulo")

    t = t.replace("FAIXA.size.y * 0.42", "FAIXA.size.y * 0.5")

    t = sub1(t,
        "\tvar origem := Vector2(14.0, 102.0)\n"
        "\tvar tamanho := Vector2(196.0, 120.0)\n"
        "\tvar g := _grupo(Rect2(origem, tamanho), -2.0)\n"
        "\t_sombra(Rect2(Vector2.ZERO, tamanho), 0.28, g)\n"
        "\t_imagem(\"ui_papel\", Rect2(Vector2.ZERO, tamanho), TextureRect.STRETCH_TILE, 0.0, g)\n"
        "\t# Cantos de fita prendendo o papel na mesa, como na referencia.\n"
        "\t_imagem(\"ui_fita\", Rect2(-4.0, -4.0, 40.0, 13.0), TextureRect.STRETCH_SCALE, -8.0, g)\n"
        "\t_imagem(\"ui_fita\", Rect2(160.0, 104.0, 36.0, 12.0), TextureRect.STRETCH_SCALE, 7.0, g)\n"
        "\n"
        "\t_imagem(\"ui_fita\", Rect2(36.0, 8.0, 126.0, 18.0), TextureRect.STRETCH_SCALE, 1.2, g)\n"
        "\t_titulo = _rotulo(\"\", Rect2(12.0, 8.0, 172.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, false, g, 500)\n"
        "\t_sublinhado = _imagem(\"ui_sublinhado\", Rect2(44.0, 26.0, 110.0, 5.0),\n"
        "\t\tTextureRect.STRETCH_SCALE, 0.0, g)\n"
        "\n"
        "\t# Fonte pequena: a media corta a descricao longa no meio da altura do papel.\n"
        "\t_descricao = _rotulo(\"\", Rect2(10.0, 34.0, 176.0, 78.0), UiEstilo.RE7_SIZE_BODY, TINTA_FRACA,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, true, g)\n",
        "\t# SPEC_POLISH §3.2 IDENTIDADE — 156×118 @ (14,128), pad ~10, rot −1.5°\n"
        "\tvar origem := Vector2(14.0, 128.0)\n"
        "\tvar tamanho := Vector2(156.0, 118.0)\n"
        "\tvar g := _grupo(Rect2(origem, tamanho), -1.5)\n"
        "\tg.name = \"PainelIdentidade\"\n"
        "\t_sombra(Rect2(Vector2.ZERO, tamanho), 0.28, g)\n"
        "\t_imagem(\"ui_papel\", Rect2(Vector2.ZERO, tamanho), TextureRect.STRETCH_TILE, 0.0, g)\n"
        "\t_imagem(\"ui_fita\", Rect2(-4.0, -4.0, 40.0, 13.0), TextureRect.STRETCH_SCALE, -8.0, g)\n"
        "\t_imagem(\"ui_fita\", Rect2(120.0, 102.0, 36.0, 12.0), TextureRect.STRETCH_SCALE, 7.0, g)\n"
        "\n"
        "\tvar pad := float(UiEstilo.RE7_PAD_PANEL)\n"
        "\t_imagem(\"ui_fita\", Rect2(pad + 10.0, pad, 116.0, 18.0), TextureRect.STRETCH_SCALE, 1.2, g)\n"
        "\t_titulo = _rotulo(\"\", Rect2(pad, pad, 156.0 - pad * 2.0, float(UiEstilo.RE7_LINE_TITLE)), UiEstilo.RE7_SIZE_TITLE, TINTA,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, false, g, 500)\n"
        "\t_sublinhado = _imagem(\"ui_sublinhado\", Rect2(pad + 18.0, pad + 18.0, 100.0, 5.0),\n"
        "\t\tTextureRect.STRETCH_SCALE, 0.0, g)\n"
        "\n"
        "\t# BODY lh 14, máx ~4 linhas (SPEC §3.2) — não reduzir font.\n"
        "\t_descricao = _rotulo(\"\", Rect2(pad, pad + 26.0, 156.0 - pad * 2.0, 56.0), UiEstilo.RE7_SIZE_BODY, TINTA_FRACA,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, true, g)\n",
        "painel identidade")

    t = sub1(t,
        "\tvar origem := Vector2(200.0, 102.0)\n"
        "\tvar tamanho := Vector2(164.0, 114.0)\n"
        "\tvar g := _grupo(Rect2(origem, tamanho), 1.5)\n",
        "\t# STATUS — alinhado à banda IDENTIDADE; gap ≥20 até polaroid\n"
        "\tvar origem := Vector2(184.0, 128.0)\n"
        "\tvar tamanho := Vector2(164.0, 114.0)\n"
        "\tvar g := _grupo(Rect2(origem, tamanho), 1.5)\n"
        "\tg.name = \"CartaoStatus\"\n",
        "cartao pos")

    t = sub1(t,
        "\t_estado = _rotulo(\"BEM\", Rect2(16.0, 78.0, 132.0, 26.0), UiEstilo.RE7_SIZE_DISPLAY,\n"
        "\t\tColor(\"a6f07a\"), HORIZONTAL_ALIGNMENT_CENTER, false, g, 600)\n",
        "\t# TITLE not DISPLAY — hierarchy: só INVENTÁRIO é DISPLAY (SPEC §2)\n"
        "\t_estado = _rotulo(\"BEM\", Rect2(16.0, 78.0, 132.0, 26.0), UiEstilo.RE7_SIZE_TITLE,\n"
        "\t\tColor(\"a6f07a\"), HORIZONTAL_ALIGNMENT_CENTER, false, g, 600)\n",
        "estado title")

    t = sub1(t,
        "\tvar origem := Vector2(368.0, 98.0)\n"
        "\tvar tamanho := Vector2(94.0, 118.0)\n"
        "\tvar g := _grupo(Rect2(origem, tamanho), 4.0)\n",
        "\t# SPEC_POLISH §3.3 polaroid 100×116 @ (366,120), +1.2°\n"
        "\tvar origem := Vector2(366.0, 120.0)\n"
        "\tvar tamanho := Vector2(100.0, 116.0)\n"
        "\tvar g := _grupo(Rect2(origem, tamanho), 1.2)\n"
        "\tg.name = \"Polaroid\"\n",
        "polaroid")

    t = sub1(t,
        "\t_imagem(\"ui_retrato\", Rect2(8.0, 16.0, 78.0, 72.0), TextureRect.STRETCH_SCALE, 0.0, g)\n",
        "\t_imagem(\"ui_retrato\", Rect2(6.0, 14.0, 88.0, 88.0), TextureRect.STRETCH_SCALE, 0.0, g)\n",
        "retrato rect")
    t = sub1(t,
        "\t_foto.position = Vector2(8.0, 16.0)\n\t_foto.size = Vector2(78.0, 72.0)\n",
        "\t_foto.position = Vector2(6.0, 14.0)\n\t_foto.size = Vector2(88.0, 88.0)\n",
        "foto size")
    t = sub1(t,
        "\t_imagem(\"ui_polaroid\", Rect2(2.0, 10.0, 90.0, 100.0), TextureRect.STRETCH_SCALE, 0.0, g)\n",
        "\t_imagem(\"ui_polaroid\", Rect2(0.0, 8.0, 100.0, 108.0), TextureRect.STRETCH_SCALE, 0.0, g)\n",
        "polaroid frame")

    t = sub1(t,
        "\t_aba_usar = _imagem(\"ui_aba\", Rect2(20.0, 220.0, 96.0, 28.0),\n"
        "\t\tTextureRect.STRETCH_SCALE, -2.0)\n"
        "\t_lbl_usar = _rotulo(\"USAR\", Rect2(20.0, 220.0, 96.0, 28.0), UiEstilo.RE7_SIZE_TITLE, TINTA_USAR,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, false, null, 500)\n"
        "\n"
        "\t_aba_examinar = _imagem(\"ui_aba\", Rect2(122.0, 222.0, 112.0, 28.0),\n"
        "\t\tTextureRect.STRETCH_SCALE, 1.5)\n"
        "\t_lbl_examinar = _rotulo(\"EXAMINAR\", Rect2(122.0, 222.0, 112.0, 28.0), UiEstilo.RE7_SIZE_TITLE, TINTA,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, false, null, 500)\n"
        "\n"
        "\tvar dica := _rotulo(\"[A/D] item  [E][Q]  [W] sistema  [ESC] fechar\",\n"
        "\t\tRect2(248.0, 242.0, 220.0, 14.0), UiEstilo.RE7_SIZE_MICRO, Color(0.94, 0.9, 0.8),\n"
        "\t\tHORIZONTAL_ALIGNMENT_RIGHT)\n",
        "\t# Ações + micro hints — banda y 246–260 (SPEC §4)\n"
        "\t_aba_usar = _imagem(\"ui_aba\", Rect2(20.0, 248.0, 62.0, 16.0),\n"
        "\t\tTextureRect.STRETCH_SCALE, -2.0)\n"
        "\t_lbl_usar = _rotulo(\"USAR\", Rect2(20.0, 246.0, 62.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA_USAR,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, false, null, 500)\n"
        "\n"
        "\t_aba_examinar = _imagem(\"ui_aba\", Rect2(88.0, 248.0, 70.0, 16.0),\n"
        "\t\tTextureRect.STRETCH_SCALE, 1.5)\n"
        "\t_lbl_examinar = _rotulo(\"EXAMINAR\", Rect2(88.0, 246.0, 70.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA,\n"
        "\t\tHORIZONTAL_ALIGNMENT_CENTER, false, null, 500)\n"
        "\n"
        "\tvar dica := _rotulo(\"[A/D] item  [E][Q]  [W] sistema  [ESC] fechar\",\n"
        "\t\tRect2(168.0, 248.0, 300.0, 12.0), UiEstilo.RE7_SIZE_MICRO, Color(0.94, 0.9, 0.8),\n"
        "\t\tHORIZONTAL_ALIGNMENT_RIGHT)\n",
        "abas/hints")

    if re.search(r"psx_\w+\.fnt", t):
        raise SystemExit("BLOCKER psx fnt in prancha")
    return t


def patch_menu(t: str) -> str:
    t = sub1(t,
        "const FOLHA_X := 144.0\nconst FOLHA_Y := 44.0\nconst FOLHA_L := 192.0\nconst PAD := 12.0\nconst VAO := 2.0\n",
        "const FOLHA_X := 138.0  ## (480-204)/2 — SPEC_POLISH §3.5 modal 204×152\n"
        "const FOLHA_Y := 55.0\n"
        "const FOLHA_L := 204.0\n"
        "const PAD := UiEstilo.RE7_PAD_MODAL\n"
        "const VAO := UiEstilo.RE7_ROW_GAP\n",
        "folha consts")

    t = sub1(t,
        "\t_linha = _fonte.get_height(_tam_body)\n"
        "\t_hit_linha = maxf(_linha, UiEstilo.HIT_LINHA_MIN)\n",
        "\t_linha = float(UiEstilo.RE7_LINE_BODY)\n"
        "\t# SPEC_POLISH §3.5 — row h 16 / gap RE7_ROW_GAP\n"
        "\t_hit_linha = maxf(float(UiEstilo.RE7_ROW), UiEstilo.HIT_LINHA_MIN)\n",
        "row metrics")

    # Title block uses TITLE line height
    t = sub1(t,
        "\tvar y := folha.position.y + PAD + _linha\n",
        "\tvar y := folha.position.y + PAD + float(UiEstilo.RE7_LINE_TITLE)\n",
        "draw title y")

    if "var h := PAD + _linha + 4.0 + 1.0 + 3.0 + 1.0 + _linha + VAO" in t:
        t = sub1(t,
            "\tvar h := PAD + _linha + 4.0 + 1.0 + 3.0 + 1.0 + _linha + VAO\n",
            "\tvar h := PAD + float(UiEstilo.RE7_LINE_TITLE) + 4.0 + 1.0 + 3.0 + 1.0 + _linha + VAO\n",
            "altura header")
    elif "var h := PAD + _linha + 4.0 + 1.0 + 3.0 + 1.0 + _linha + VAO" not in t:
        # try the form from earlier read of _altura
        alt = "\tvar h := PAD + _linha + 4.0 + 1.0 + 3.0 + 1.0 + _linha + VAO\n"
        # also Portuguese variant with different spacing from first menu read:
        # `var h := PAD + _linha + 4.0 + 1.0 + 3.0 + 1.0 + _linha + VAO`
        pass

    # _ys_linhas header
    if "folha.position.y + PAD + _linha + 4.0 + 3.0 + _linha + VAO" in t:
        t = sub1(t,
            "\tvar y := folha.position.y + PAD + _linha + 4.0 + 3.0 + _linha + VAO\n",
            "\tvar y := folha.position.y + PAD + float(UiEstilo.RE7_LINE_TITLE) + 4.0 + 3.0 + _linha + VAO\n",
            "ys header")

    # Footer micro pad bottom 8
    if "folha.end.y - PAD + 3.0" in t:
        t = t.replace(
            "folha.end.y - PAD + 3.0",
            "folha.end.y - 8.0",
            1,
        )

    if re.search(r"psx_\w+\.fnt", t):
        raise SystemExit("BLOCKER psx fnt in menu")
    return t


def main():
    pr = PR.read_text(encoding="utf-8")
    ms = MS.read_text(encoding="utf-8")
    pr2 = patch_prancha(pr)
    ms2 = patch_menu(ms)
    PR.write_text(pr2, encoding="utf-8", newline="\n")
    MS.write_text(ms2, encoding="utf-8", newline="\n")
    print("OK prancha delta", len(pr2)-len(pr))
    print("OK menu delta", len(ms2)-len(ms))
    for n, x in [("prancha", pr2), ("menu", ms2)]:
        print(n, "psx_fnt", re.findall(r"psx_\w+\.fnt", x) or "none")
        print(n, "RE7_", len(re.findall(r"UiEstilo\.RE7_", x)))

if __name__ == "__main__":
    main()

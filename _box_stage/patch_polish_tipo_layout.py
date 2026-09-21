# -*- coding: utf-8 -*-
"""P0 polish tipo/layout — prancha_inventario + menu_sistema only (consume UiEstilo)."""
from pathlib import Path
import re

ROOT = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui")
PRANCHA = ROOT / "prancha_inventario.gd"
MENU = ROOT / "menu_sistema.gd"


def must_replace(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"MISSING ({label}): {old[:80]!r}")
    return text.replace(old, new, 1)


def patch_prancha(t: str) -> str:
    # --- FAIXA Y band 28–60 (spec §3.1) ---
    t = must_replace(
        t,
        "const FAIXA := Rect2(12.0, 32.0, 456.0, 60.0)",
        "const FAIXA := Rect2(12.0, 28.0, 456.0, 32.0)",
        "FAIXA band",
    )
    # Icon size closer to slot 28 without killing scrapbook (was 42)
    if "const ICONE := 42.0" in t:
        t = must_replace(t, "const ICONE := 42.0", "const ICONE := 28.0", "ICONE")
    if "const ICONE_VITRINE := 52.0" in t:
        t = must_replace(t, "const ICONE_VITRINE := 52.0", "const ICONE_VITRINE := 36.0", "ICONE_VITRINE")
    # Alternate naming from other revisions
    if "const ICON := 42.0" in t:
        t = must_replace(t, "const ICON := 42.0", "const ICON := 28.0", "ICON")

    # --- _rotulo: line_spacing + letter_spacing from RE7_LINE_* / hierarchy ---
    # Find aplicar_re7 call block and enhance after it.
    old_rotulo_tail = None
    for cand in [
        """\tUiEstilo.aplicar_re7(l, tamanho, peso)
\tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
\tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t(pai if pai != null else _raiz).add_child(l)
\tl.position = r.position
\tl.size = r.size
\treturn l""",
        """\tUiEstilo.aplicar_re7(l, tamanho, peso)
\tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
\tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t(pai if pai != null else _raiz).add_child(l)
\tl.position = r.position
\tl.size = r.size
\treturn l""",
    ]:
        if cand in t:
            old_rotulo_tail = cand
            break
    # More flexible: regex insert after aplicar_re7
    if "RE7_LINE_BODY" not in t or "_line_spacing_re7" not in t:
        m = re.search(
            r"(UiEstilo\.aplicar_re7\([^\n]+\)\n)",
            t,
        )
        if not m:
            raise SystemExit("MISSING aplicar_re7 in prancha _rotulo")
        insert = m.group(1) + (
            "\t# SPEC_POLISH_TIPO_LAYOUT_RE7 — line-height / tracking por papel.\n"
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
            "\tvar extra := maxi(0, lh - tamanho)\n"
            "\tl.add_theme_constant_override(&\"line_spacing\", extra)\n"
            "\tif track != 0:\n"
            "\t\tl.add_theme_constant_override(&\"letter_spacing\", track)\n"
        )
        t = t[: m.start()] + insert + t[m.end() :]

    # --- Title band: baseline ~20, DISPLAY ---
    for old, new, lab in [
        (
            '_rotulo("INVENTÁRIO", Rect2(140.0, 22.0, 200.0, 22.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,',
            '_rotulo("INVENTÁRIO", Rect2(140.0, 8.0, 200.0, 22.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,',
            "title INVENTARIO accent",
        ),
        (
            '_rotulo("INVENTARIO", Rect2(140.0, 22.0, 200.0, 22.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,',
            '_rotulo("INVENTARIO", Rect2(140.0, 8.0, 200.0, 22.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,',
            "title INVENTARIO ascii",
        ),
        (
            '_rotulo("INVENTÁRIO", Rect2(140.0, 22.0, 200.0, 22.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,\n\t\tHORIZONTAL_ALIGNMENT_CENTER, false, null, 600)',
            '_rotulo("INVENTÁRIO", Rect2(140.0, 8.0, 200.0, 24.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,\n\t\tHORIZONTAL_ALIGNMENT_CENTER, false, null, 600)',
            "title full",
        ),
    ]:
        if old in t:
            t = must_replace(t, old, new, lab)
            break

    # Tape scraps under title — nudge toward y~8–24 band
    if "Rect2(118.0, 22.0, 68.0, 22.0)" in t:
        t = must_replace(
            t,
            "Rect2(118.0, 22.0, 68.0, 22.0), Rect2(178.0, 19.0, 76.0, 24.0),\n\t\tRect2(246.0, 23.0, 72.0, 21.0), Rect2(308.0, 20.0, 62.0, 22.0),",
            "Rect2(118.0, 10.0, 68.0, 22.0), Rect2(178.0, 8.0, 76.0, 24.0),\n\t\tRect2(246.0, 11.0, 72.0, 21.0), Rect2(308.0, 9.0, 62.0, 22.0),",
            "title tapes",
        )

    # --- Painel IDENTIDADE 156×118 @ (14,128), pad interno ---
    # Handle both Portuguese and possible variants
    painel_patterns = [
        (
            """\tvar origem := Vector2(14.0, 102.0)
\tvar tamanho := Vector2(196.0, 120.0)
\tvar g := _grupo(Rect2(origem, tamanho), -2.0)""",
            """\t# SPEC_POLISH §3.2 IDENTIDADE — 156×118 @ (14,128), rot −1.5°
\tvar origem := Vector2(14.0, 128.0)
\tvar tamanho := Vector2(156.0, 118.0)
\tvar g := _grupo(Rect2(origem, tamanho), -1.5)
\tg.name = \"PainelIdentidade\"""",
        ),
        (
            """\tvar origem := Vector2(14.0, 102.0)
\tvar tamanho := Vector2(196.0, 120.0)
\tvar g := _grupo(Rect2(origem, tamanho), -2.0)""",
            None,  # duplicate
        ),
    ]
    if "Vector2(14.0, 102.0)" in t and "Vector2(196.0, 120.0)" in t:
        t = must_replace(
            t,
            "\tvar origem := Vector2(14.0, 102.0)\n\tvar tamanho := Vector2(196.0, 120.0)\n\tvar g := _grupo(Rect2(origem, tamanho), -2.0)",
            "\t# SPEC_POLISH §3.2 IDENTIDADE — 156×118 @ (14,128)\n\tvar origem := Vector2(14.0, 128.0)\n\tvar tamanho := Vector2(156.0, 118.0)\n\tvar g := _grupo(Rect2(origem, tamanho), -1.5)\n\tg.name = \"PainelIdentidade\"",
            "painel identidade",
        )
        # Internal pads: title/body rects for 156 width, pad ~10
        if "Rect2(12.0, 8.0, 172.0, 18.0)" in t:
            t = must_replace(
                t,
                "_titulo = _rotulo(\"\", Rect2(12.0, 8.0, 172.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA,",
                "_titulo = _rotulo(\"\", Rect2(10.0, 10.0, 136.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA,",
                "titulo item",
            )
        if "Rect2(36.0, 8.0, 126.0, 18.0)" in t:
            t = must_replace(
                t,
                '_imagem("ui_fita", Rect2(36.0, 8.0, 126.0, 18.0), TextureRect.STRETCH_SCALE, 1.2, g)',
                '_imagem("ui_fita", Rect2(20.0, 10.0, 116.0, 18.0), TextureRect.STRETCH_SCALE, 1.2, g)',
                "fita titulo",
            )
        if "Rect2(44.0, 26.0, 110.0, 5.0)" in t:
            t = must_replace(
                t,
                '_sublinhado = _imagem("ui_sublinhado", Rect2(44.0, 26.0, 110.0, 5.0),',
                '_sublinhado = _imagem("ui_sublinhado", Rect2(28.0, 28.0, 100.0, 5.0),',
                "sublinhado",
            )
        if "Rect2(10.0, 34.0, 176.0, 78.0)" in t:
            t = must_replace(
                t,
                "_descricao = _rotulo(\"\", Rect2(10.0, 34.0, 176.0, 78.0), UiEstilo.RE7_SIZE_BODY, TINTA_FRACA,",
                "_descricao = _rotulo(\"\", Rect2(10.0, 34.0, 136.0, 56.0), UiEstilo.RE7_SIZE_BODY, TINTA_FRACA,",
                "descricao body",
            )
        if "Rect2(160.0, 104.0, 36.0, 12.0)" in t:
            t = must_replace(
                t,
                '_imagem("ui_fita", Rect2(160.0, 104.0, 36.0, 12.0), TextureRect.STRETCH_SCALE, 7.0, g)',
                '_imagem("ui_fita", Rect2(120.0, 102.0, 36.0, 12.0), TextureRect.STRETCH_SCALE, 7.0, g)',
                "fita canto painel",
            )

    # --- Cartão STATUS: keep scrapbook but don't steal DISPLAY; use TITLE ---
    if "UiEstilo.RE7_SIZE_DISPLAY,\n\t\tColor(\"a6f07a\")" in t or 'UiEstilo.RE7_SIZE_DISPLAY,\n\t\tColor("a6f07a")' in t:
        t = t.replace(
            "UiEstilo.RE7_SIZE_DISPLAY,\n\t\tColor(\"a6f07a\")",
            "UiEstilo.RE7_SIZE_TITLE,\n\t\tColor(\"a6f07a\")",
            1,
        )
        t = t.replace(
            'UiEstilo.RE7_SIZE_DISPLAY,\n\t\tColor("a6f07a")',
            'UiEstilo.RE7_SIZE_TITLE,\n\t\tColor("a6f07a")',
            1,
        )
    # Also: `_estado = _rotulo("BEM", ... RE7_SIZE_DISPLAY`
    t2 = re.sub(
        r'(_estado = _rotulo\("BEM", Rect2\([^)]+\), )UiEstilo\.RE7_SIZE_DISPLAY',
        r"\1UiEstilo.RE7_SIZE_TITLE",
        t,
        count=1,
    )
    t = t2

    # Move cartão down with identidade band if still at y=102
    if "Vector2(200.0, 102.0)" in t:
        t = must_replace(
            t,
            "\tvar origem := Vector2(200.0, 102.0)\n\tvar tamanho := Vector2(164.0, 114.0)\n\tvar g := _grupo(Rect2(origem, tamanho), 1.5)",
            "\t# STATUS card — entre IDENTIDADE e polaroid; y alinhado à banda 120+\n\tvar origem := Vector2(184.0, 128.0)\n\tvar tamanho := Vector2(164.0, 114.0)\n\tvar g := _grupo(Rect2(origem, tamanho), 1.5)\n\tg.name = \"CartaoStatus\"",
            "cartao status pos",
        )

    # --- Polaroid 100×116 @ (366,120) ---
    if "Vector2(368.0, 98.0)" in t:
        t = must_replace(
            t,
            "\tvar origem := Vector2(368.0, 98.0)\n\tvar tamanho := Vector2(94.0, 118.0)\n\tvar g := _grupo(Rect2(origem, tamanho), 4.0)",
            "\t# SPEC_POLISH §3.3 polaroid 100×116 @ (366,120), rot +1.2°\n\tvar origem := Vector2(366.0, 120.0)\n\tvar tamanho := Vector2(100.0, 116.0)\n\tvar g := _grupo(Rect2(origem, tamanho), 1.2)\n\tg.name = \"Polaroid\"",
            "polaroid",
        )
        # Scale inner photo a bit for new frame
        if "Rect2(8.0, 16.0, 78.0, 72.0)" in t:
            t = t.replace(
                '_imagem("ui_retrato", Rect2(8.0, 16.0, 78.0, 72.0), TextureRect.STRETCH_SCALE, 0.0, g)',
                '_imagem("ui_retrato", Rect2(6.0, 14.0, 88.0, 88.0), TextureRect.STRETCH_SCALE, 0.0, g)',
                1,
            )
            t = t.replace(
                "\t_foto.position = Vector2(8.0, 16.0)\n\t_foto.size = Vector2(78.0, 72.0)",
                "\t_foto.position = Vector2(6.0, 14.0)\n\t_foto.size = Vector2(88.0, 88.0)",
                1,
            )
            t = t.replace(
                '_imagem("ui_polaroid", Rect2(2.0, 10.0, 90.0, 100.0), TextureRect.STRETCH_SCALE, 0.0, g)',
                '_imagem("ui_polaroid", Rect2(0.0, 8.0, 100.0, 108.0), TextureRect.STRETCH_SCALE, 0.0, g)',
                1,
            )

    # --- Action tabs + micro hints: bottom safe (hints y≤260) ---
    if "Rect2(20.0, 220.0, 96.0, 28.0)" in t:
        t = must_replace(
            t,
            '_aba_usar = _imagem("ui_aba", Rect2(20.0, 220.0, 96.0, 28.0),\n\t\tTextureRect.STRETCH_SCALE, -2.0)\n\t_lbl_usar = _rotulo("USAR", Rect2(20.0, 220.0, 96.0, 28.0), UiEstilo.RE7_SIZE_TITLE, TINTA_USAR,',
            '_aba_usar = _imagem("ui_aba", Rect2(20.0, 248.0, 62.0, 16.0),\n\t\tTextureRect.STRETCH_SCALE, -2.0)\n\t_lbl_usar = _rotulo("USAR", Rect2(20.0, 246.0, 62.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA_USAR,',
            "aba usar",
        )
    if "Rect2(122.0, 222.0, 112.0, 28.0)" in t:
        t = must_replace(
            t,
            '_aba_examinar = _imagem("ui_aba", Rect2(122.0, 222.0, 112.0, 28.0),\n\t\tTextureRect.STRETCH_SCALE, 1.5)\n\t_lbl_examinar = _rotulo("EXAMINAR", Rect2(122.0, 222.0, 112.0, 28.0), UiEstilo.RE7_SIZE_TITLE, TINTA,',
            '_aba_examinar = _imagem("ui_aba", Rect2(88.0, 248.0, 62.0, 16.0),\n\t\tTextureRect.STRETCH_SCALE, 1.5)\n\t_lbl_examinar = _rotulo("EXAMINAR", Rect2(88.0, 246.0, 62.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA,',
            "aba examinar",
        )
    if "Rect2(248.0, 242.0, 220.0, 14.0)" in t:
        t = must_replace(
            t,
            "Rect2(248.0, 242.0, 220.0, 14.0), UiEstilo.RE7_SIZE_MICRO, Color(0.94, 0.9, 0.8),",
            "Rect2(160.0, 248.0, 308.0, 12.0), UiEstilo.RE7_SIZE_MICRO, Color(0.94, 0.9, 0.8),",
            "dica micro",
        )

    # Slot cy: center in 28–60 band (FAIXA h=32 → 0.5)
    if "FAIXA.size.y * 0.42" in t:
        t = t.replace("FAIXA.size.y * 0.42", "FAIXA.size.y * 0.5")

    # Count badge positions relative to smaller icons — leave as relative offsets

    if "psx_" in t and ".fnt" in t:
        # Only flag direct loads
        if re.search(r'psx_\w+\.fnt', t):
            raise SystemExit("BLOCKER: residual psx_*.fnt in prancha")
    return t


def patch_menu(t: str) -> str:
    # Modal 204×152 centered: x=(480-204)/2=138, y≈(270-152)/2-4≈55
    t = must_replace(t, "const FOLHA_X := 144.0", "const FOLHA_X := 138.0", "FOLHA_X")
    t = must_replace(t, "const FOLHA_Y := 44.0", "const FOLHA_Y := 55.0", "FOLHA_Y")
    t = must_replace(t, "const FOLHA_L := 192.0", "const FOLHA_L := 204.0", "FOLHA_L")
    # PAD already 12 — bind to token if hardcoded
    if "const PAD := 12.0" in t:
        t = must_replace(
            t,
            "const PAD := 12.0",
            "const PAD := UiEstilo.RE7_PAD_MODAL",
            "PAD modal",
        )
    if "const VAO := 2.0" in t:
        t = must_replace(
            t,
            "const VAO := 2.0",
            "const VAO := UiEstilo.RE7_ROW_GAP",
            "VAO",
        )

    # Hit row = RE7_ROW (16)
    old_hit = "\t_linha = _fonte.get_height(_tam_body)\n\t_hit_linha = maxf(_linha, UiEstilo.HIT_LINHA_MIN)"
    new_hit = (
        "\t_linha = float(UiEstilo.RE7_LINE_BODY)\n"
        "\t# SPEC_POLISH §3.5 — row h 16, gap 2\n"
        "\t_hit_linha = maxf(float(UiEstilo.RE7_ROW), UiEstilo.HIT_LINHA_MIN)"
    )
    if old_hit in t:
        t = must_replace(t, old_hit, new_hit, "hit linha")
    else:
        # try alternate
        alt = "\t_linha = _fonte.get_height(_tam_body)\n\t_hit_linha = maxf(_linha, UiEstilo.HIT_LINHA_MIN)"
        if alt in t:
            t = must_replace(t, alt, new_hit, "hit linha alt")

    # Title draw uses _tam_title already — ensure weight hierarchy: title font 500
    # Increase title block breathing: after title, +4 already; bump title baseline spacing
    old_title_block = "\tvar y := folha.position.y + PAD + _linha\n"
    # Prefer title line height for title baseline
    if "folha.position.y + PAD + _linha" in t and "RE7_LINE_TITLE" not in t:
        t = t.replace(
            "\tvar y := folha.position.y + PAD + _linha\n",
            "\tvar y := folha.position.y + PAD + float(UiEstilo.RE7_LINE_TITLE)\n",
            1,
        )
        # Also _altura / _ys_linhas header uses _linha — update header reserve
        t = t.replace(
            "\tvar h := PAD + _linha + 4.0 + 1.0 + 3.0 + 1.0 + _linha + VAO\n",
            "\tvar h := PAD + float(UiEstilo.RE7_LINE_TITLE) + 4.0 + 1.0 + 3.0 + 1.0 + _linha + VAO\n",
            1,
        )
        t = t.replace(
            "\tvar y := folha.position.y + PAD + _linha + 4.0 + 3.0 + _linha + VAO\n",
            "\tvar y := folha.position.y + PAD + float(UiEstilo.RE7_LINE_TITLE) + 4.0 + 3.0 + _linha + VAO\n",
            1,
        )

    # Footer micro: pad bottom 8
    if "folha.end.y - PAD + 3.0" in t:
        t = t.replace(
            "Vector2(folha.position.x + PAD, folha.end.y - PAD + 3.0), dc, _tam_micro)",
            "Vector2(folha.position.x + PAD, folha.end.y - 8.0), dc, _tam_micro)",
            1,
        )

    if re.search(r"psx_\w+\.fnt", t):
        raise SystemExit("BLOCKER: residual psx_*.fnt in menu_sistema")
    return t


def main() -> None:
    pr = PRANCHA.read_text(encoding="utf-8")
    mn = MENU.read_text(encoding="utf-8")
    pr2 = patch_prancha(pr)
    mn2 = patch_menu(mn)
    PRANCHA.write_text(pr2, encoding="utf-8", newline="\n")
    MENU.write_text(mn2, encoding="utf-8", newline="\n")
    print("patched", PRANCHA.name, "delta", len(pr2) - len(pr))
    print("patched", MENU.name, "delta", len(mn2) - len(mn))
    # Sanity
    for label, text in [("prancha", pr2), ("menu", mn2)]:
        bad = re.findall(r"psx_\w+\.fnt", text)
        print(label, "psx_fnt", bad or "none")
        print(label, "RE7 refs", len(re.findall(r"UiEstilo\.RE7_", text)))


if __name__ == "__main__":
    main()

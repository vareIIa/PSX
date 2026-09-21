from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\menu_sistema.gd")
text = path.read_text(encoding="utf-8")
orig = text

def must_replace(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f"FAIL: {label}")
    text = text.replace(old, new, 1)
    print("OK", label)

# --- state vars ---
if "_stagger_t" not in text:
    must_replace(
        "var _tween_folha: Tween\nvar _tween_foco: Tween\nvar _tween_pagina: Tween\nvar _input_travado: bool = false",
        "var _tween_folha: Tween\nvar _tween_foco: Tween\nvar _tween_pagina: Tween\nvar _input_travado: bool = false\n## Relogio do stagger de linhas no open (SPEC_MOTION / ADDENDUM RE).\nvar _stagger_t: float = 99.0\nvar _aba_pressed: bool = false",
        "state",
    )

# --- open reset ---
if "_stagger_t = 0.0" not in text:
    must_replace(
        "func _animar_abrir() -> void:\n\t_matar(_tween_folha)\n\t_folha_alfa = 0.0\n\t_folha_dy = 8.0\n\t_conteudo_alfa = 1.0\n\t_foco_alfa = 1.0\n\t_input_travado = true",
        "func _animar_abrir() -> void:\n\t_matar(_tween_folha)\n\t_folha_alfa = 0.0\n\t_folha_dy = 8.0\n\t_conteudo_alfa = 1.0\n\t_foco_alfa = 1.0\n\t_stagger_t = 0.0\n\t_input_travado = true",
        "open-reset",
    )

# --- process ---
if "func _process(delta: float) -> void:" not in text:
    must_replace(
        "# --- motion -----------------------------------------------------------------",
        "func _process(delta: float) -> void:\n\tif not aberto:\n\t\treturn\n\t# Cascata de linhas: 35 ms/linha, teto no open (SPEC_MOTION).\n\tif _stagger_t < 4.0:\n\t\t_stagger_t += delta\n\t\tqueue_redraw()\n\n\n# --- motion -----------------------------------------------------------------",
        "process",
    )

# --- sheet draw elevate ---
old_draw = """\tdraw_rect(Rect2(Vector2.ZERO, UiEstilo.TELA), Color(0.02, 0.02, 0.03, 0.55 * alfa))

\tvar sombra := Color(UiEstilo.PAPEL_SOMBRA)
\tsombra.a *= alfa
\tdraw_rect(Rect2(folha.position + Vector2(2.0, 2.0), folha.size), sombra)
\tvar papel := UiEstilo.PAPEL
\tpapel.a = alfa
\tdraw_rect(folha, papel)
\tvar borda := UiEstilo.TINTA
\tborda.a = alfa
\tdraw_rect(folha, borda, false, UiEstilo.PAPEL_BORDA)"""

new_draw = """\t# Scrim tinta (nunca blur/glass) — ADDENDUM RE.
\tdraw_rect(Rect2(Vector2.ZERO, UiEstilo.TELA), Color(0.02, 0.02, 0.03, 0.55 * alfa))

\t# Sombra em camadas (peso RE) — offsets duros, sem blur.
\tfor off_a in [[3.0, 3.0, 0.22], [2.0, 2.0, 0.35], [1.0, 1.0, 0.20]]:
\t\tvar sombra := Color(0.05, 0.04, 0.03, float(off_a[2]) * alfa)
\t\tdraw_rect(Rect2(folha.position + Vector2(float(off_a[0]), float(off_a[1])), folha.size), sombra)
\tvar papel := UiEstilo.PAPEL
\tpapel.a = alfa
\tdraw_rect(folha, papel)
\t# Inset highlight (skeuomorph leve) — 1 px topo/esquerda.
\tvar luz := Color(1.0, 0.98, 0.90, 0.22 * alfa)
\tdraw_rect(Rect2(folha.position.x + 1.0, folha.position.y + 1.0, folha.size.x - 2.0, 1.0), luz)
\tdraw_rect(Rect2(folha.position.x + 1.0, folha.position.y + 1.0, 1.0, folha.size.y - 2.0), luz)
\tvar borda := UiEstilo.TINTA
\tborda.a = alfa
\tdraw_rect(folha, borda, false, UiEstilo.PAPEL_BORDA)"""

must_replace(old_draw, new_draw, "sheet-draw")

# --- stagger in item loop ---
old_loop = """\tfor i in _itens.size():
\t\tvar item := _itens[i]
\t\tvar ativo := i == _sel
\t\tvar vivo := bool(item.get(\"vivo\", true))
\t\tvar destrutivo := bool(item.get(\"destrutivo\", false))
\t\tvar cor := UiEstilo.TINTA
\t\tif ativo:
\t\t\tcor = UiEstilo.DESTAQUE
\t\telif destrutivo:
\t\t\tcor = UiEstilo.DESTAQUE
\t\telif not vivo:
\t\t\tcor = Color(0.55, 0.50, 0.42)
\t\tcor.a = ca"""

new_loop = """\tfor i in _itens.size():
\t\tvar item := _itens[i]
\t\tvar ativo := i == _sel
\t\tvar vivo := bool(item.get(\"vivo\", true))
\t\tvar destrutivo := bool(item.get(\"destrutivo\", false))
\t\t# Stagger RE: linha i entra apos i*35ms; CONTINUAR (0) no frame util.
\t\tvar linha_a := clampf((_stagger_t - float(i) * 0.035) / 0.08, 0.0, 1.0)
\t\tvar ca_l := ca * linha_a
\t\tvar cor := UiEstilo.TINTA
\t\tif ativo:
\t\t\tcor = UiEstilo.DESTAQUE
\t\telif destrutivo:
\t\t\tcor = UiEstilo.DESTAQUE
\t\telif not vivo:
\t\t\tcor = Color(0.55, 0.50, 0.42)
\t\tcor.a = ca_l"""

must_replace(old_loop, new_loop, "item-loop")

old_stain = """\t\tif ativo:
\t\t\tvar stain_a := (0.10 if destrutivo else 0.08) * _foco_alfa * ca
\t\t\tdraw_rect(Rect2(folha.position.x + PAD - 4.0, y - _hit_linha + 3.0,
\t\t\t\tfolha.size.x - PAD * 2.0 + 8.0, _hit_linha), Color(0.0, 0.0, 0.0, stain_a))
\t\t\t# Barra esquerda 2x10 DESTAQUE.
\t\t\tvar barra_cor := UiEstilo.DESTAQUE
\t\t\tbarra_cor.a = ca * _foco_alfa
\t\t\tvar by := y - _hit_linha + 3.0 + (_hit_linha - 10.0) * 0.5
\t\t\tdraw_rect(Rect2(folha.position.x + 4.0, by, 2.0, 10.0), barra_cor)
\t\t\t_texto(\">\", Vector2(folha.position.x + PAD - 7.0, y), cor)"""

new_stain = """\t\tif ativo:
\t\t\tvar stain_a := (0.10 if destrutivo else 0.08) * _foco_alfa * ca_l
\t\t\tdraw_rect(Rect2(folha.position.x + PAD - 4.0, y - _hit_linha + 3.0,
\t\t\t\tfolha.size.x - PAD * 2.0 + 8.0, _hit_linha), Color(0.0, 0.0, 0.0, stain_a))
\t\t\t# Barra esquerda 2x10 DESTAQUE + stain + `>` (focus rico RE).
\t\t\tvar barra_cor := UiEstilo.DESTAQUE
\t\t\tbarra_cor.a = ca_l * _foco_alfa
\t\t\tvar by := y - _hit_linha + 3.0 + (_hit_linha - 10.0) * 0.5
\t\t\tdraw_rect(Rect2(folha.position.x + 4.0, by, 2.0, 10.0), barra_cor)
\t\t\t_texto(\">\", Vector2(folha.position.x + PAD - 7.0, y + (1.0 - linha_a) * 3.0), cor)"""

must_replace(old_stain, new_stain, "stain")

old_label = """\t\tvar rotulo := String(item[\"rotulo\"])
\t\t_texto(rotulo, Vector2(folha.position.x + PAD, y), cor)"""

new_label = """\t\tvar rotulo := String(item[\"rotulo\"])
\t\tvar y_l := y + (1.0 - linha_a) * 3.0
\t\t_texto(rotulo, Vector2(folha.position.x + PAD, y_l), cor)"""

must_replace(old_label, new_label, "label")

# value / chevron alpha
if "ccor.a = ca\n" in text:
    text = text.replace("ccor.a = ca\n", "ccor.a = ca_l\n", 1)
    print("OK chevron-a")
if "vc.a = ca\n" in text:
    text = text.replace("vc.a = ca\n", "vc.a = ca_l\n", 1)
    print("OK value-a")

# --- aba pressed ---
old_aba = """func _ao_aba_input(evento: InputEvent) -> void:
\tif evento is InputEventMouseButton:
\t\tvar mb := evento as InputEventMouseButton
\t\tif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
\t\t\taccept_event()
\t\t\tif aberto:
\t\t\t\tfechar()
\t\t\telse:
\t\t\t\tabrir()"""

new_aba = """func _ao_aba_input(evento: InputEvent) -> void:
\tif evento is InputEventMouseButton:
\t\tvar mb := evento as InputEventMouseButton
\t\tif mb.button_index == MOUSE_BUTTON_LEFT:
\t\t\tif mb.pressed:
\t\t\t\t_aba_pressed = true
\t\t\t\tif _aba != null:
\t\t\t\t\t_aba.queue_redraw()
\t\t\t\taccept_event()
\t\t\telse:
\t\t\t\tif _aba_pressed:
\t\t\t\t\t_aba_pressed = false
\t\t\t\t\tif _aba != null:
\t\t\t\t\t\t_aba.queue_redraw()
\t\t\t\t\taccept_event()
\t\t\t\t\tif aberto:
\t\t\t\t\t\tfechar()
\t\t\t\t\telse:
\t\t\t\t\t\tabrir()"""

must_replace(old_aba, new_aba, "aba-input")

old_chip = """\tvar fill := UiEstilo.PAPEL_ABERTO if aberto else UiEstilo.PAPEL
\t_aba.draw_rect(placa, fill)
\tvar borda := UiEstilo.DESTAQUE if (_aba_hover and not aberto) else UiEstilo.TINTA
\t_aba.draw_rect(placa, borda, false, 1.0)
\tvar cor := UiEstilo.DESTAQUE if aberto else UiEstilo.TINTA"""

new_chip = """\tvar fill := UiEstilo.PAPEL_ABERTO if aberto else UiEstilo.PAPEL
\tif _aba_pressed:
\t\tfill = Color(fill.r * 0.92, fill.g * 0.92, fill.b * 0.92, fill.a)
\t_aba.draw_rect(placa, fill)
\tvar borda := UiEstilo.DESTAQUE if ((_aba_hover or _aba_pressed) and not aberto) else UiEstilo.TINTA
\t_aba.draw_rect(placa, borda, false, 1.0)
\tvar cor := UiEstilo.DESTAQUE if aberto else UiEstilo.TINTA"""

must_replace(old_chip, new_chip, "chip")

# abrir_em snap
old_ae = """\t_folha_alfa = 1.0
\t_folha_dy = 0.0
\t_conteudo_alfa = 1.0
\t_foco_alfa = 1.0
\t_input_travado = false"""
new_ae = """\t_folha_alfa = 1.0
\t_folha_dy = 0.0
\t_conteudo_alfa = 1.0
\t_foco_alfa = 1.0
\t_stagger_t = 99.0
\t_input_travado = false"""
if old_ae in text:
    text = text.replace(old_ae, new_ae, 1)
    print("OK abrir_em")
else:
    print("SKIP abrir_em")

if text == orig:
    print("NO CHANGES")
else:
    path.write_text(text, encoding="utf-8")
    print("WROTE", path, "lines", len(text.splitlines()))

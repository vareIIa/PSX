from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\prancha_inventario.gd")
text = path.read_text(encoding="utf-8")
orig = text

# 1) Add vars after _sistema
needle = "var _sistema: MenuSistema\n"
insert_vars = """var _sistema: MenuSistema

## Onda 3 wire: inspeção orbitável + vitals (no lugar de BEM / status polaroid).
var _inspect: Control = null
var _vitals: Control = null
"""
if "var _inspect: Control" not in text:
    if needle not in text:
        raise SystemExit("sistema var not found")
    text = text.replace(needle, insert_vars, 1)

# 2) Call wire mount at end of _montar after sistema setup — find after _sistema = MenuSistema
# Look for block that adds sistema and connect signals; append after _montar_abas is too early.
# Better: after `_sistema = MenuSistema.new()` block ends. Find unique marker near end of _montar.
marker = "\t_sistema = MenuSistema.new()\n"
if "\t_montar_onda3_wire()" not in text:
    # Find the line after sistema is fully added — search for pediu_ connections or end of _montar
    idx = text.find(marker)
    if idx < 0:
        raise SystemExit("sistema new not found")
    # Find next blank-line-separated function after _montar's sistema wiring
    # Insert call just before the closing of _montar: after sistema child add and signal connects
    # Prefer insert after `_montar_abas()` call in _montar
    m2 = "\t_montar_abas()\n"
    if m2 not in text:
        raise SystemExit("montar_abas call not found")
    text = text.replace(m2, "\t_montar_abas()\n\t_montar_onda3_wire()\n", 1)

# 3) Insert _montar_onda3_wire function before _montar_vitrine or after _montar_abas function
wire_fn = '''
func _montar_onda3_wire() -> void:
	## Wire Onda 3 (GO PO1): BEM/status → VitalsMonitor; EXAMINAR → ItemInspectViewport.
	## Preserva scrapbook, fonte_re7 e overlay. Sem cutover grid.
	if _estado != null:
		_estado.visible = false
	# Polaroid miolo (foto): vitals diegéticos no lugar do status/BEM.
	if _foto != null:
		_foto.visible = false
	var vitals_rect := Rect2(374.0, 136.0, 78.0, 72.0)
	_vitals = Re7Onda3Wire.mount_vitals(_raiz, vitals_rect)
	if _vitals != null:
		_vitals.z_index = 6
		_vitals.scale = Vector2(1.15, 1.15)
	# Inspect overlay (só no examine).
	var inspect_rect := Rect2(170.0, 55.0, 140.0, 150.0)
	_inspect = Re7Onda3Wire.mount_inspect(_raiz, inspect_rect)
	if _inspect != null:
		_inspect.visible = false
		_inspect.z_index = 25
		_inspect.mouse_filter = Control.MOUSE_FILTER_STOP


'''

if "func _montar_onda3_wire()" not in text:
    anchor = "func _montar_vitrine() -> void:"
    if anchor not in text:
        # try alternate name
        anchor = "func _montar_vitrine() -> void:"
    if "func _montar_vitrine()" in text:
        text = text.replace("func _montar_vitrine() -> void:", wire_fn + "func _montar_vitrine() -> void:", 1)
    elif "func _montar_vitrine() -> void:" in text:
        text = text.replace("func _montar_vitrine() -> void:", wire_fn + "func _montar_vitrine() -> void:", 1)
    else:
        # find any vitrine mount
        for name in ["func _montar_vitrine() -> void:", "func _montar_vitrine() -> void:"]:
            pass
        if "func _montar_vitrine()" in text:
            text = text.replace("func _montar_vitrine() -> void:", wire_fn + "func _montar_vitrine() -> void:", 1)
        else:
            # dump nearby
            i = text.find("vitrine")
            raise SystemExit("vitrine func not found near " + text[i:i+80])

# Fix if wrong function name used - check file for actual name
if "func _montar_onda3_wire()" not in text:
    raise SystemExit("wire fn insert failed")

# 4) Patch _examinar to sync inspect
old_exam = """\t_examinando = not _examinando\n\tAudioDirector.tocar_ui(&\"clique\", -10.0)\n\t_atualizar()\n"""
new_exam = """\t_examinando = not _examinando\n\tAudioDirector.tocar_ui(&\"clique\", -10.0)\n\t_sincronizar_inspect()\n\t_atualizar()\n"""
# Try alternate audio name
if old_exam not in text:
    old_exam = """\t_examinando = not _examinando\n\tAudioDirector.play_ui(&\"clique\", -10.0)\n\t_atualizar()\n"""
    new_exam = """\t_examinando = not _examinando\n\tAudioDirector.play_ui(&\"clique\", -10.0)\n\t_sincronizar_inspect()\n\t_atualizar()\n"""
if old_exam not in text:
    # softer match
    import re
    text2, n = re.subn(
        r"(\t_examinando = not _examinando\n\tAudioDirector\.[^\n]+\n)\t_atualizar\(\)\n",
        r"\1\t_sincronizar_inspect()\n\t_atualizar()\n",
        text,
        count=1,
    )
    if n != 1:
        raise SystemExit("examinar patch failed")
    text = text2
else:
    text = text.replace(old_exam, new_exam, 1)

# 5) Add _sincronizar_inspect before _atualizar
sync_fn = '''
func _sincronizar_inspect() -> void:
	if _inspect == null:
		return
	if not _examinando:
		_inspect.visible = false
		if _inspect.has_method("exit"):
			_inspect.call("exit")
		return
	var sel: Dictionary = Inventario.espacos[_selecionado]
	if sel.is_empty():
		_inspect.visible = false
		if _inspect.has_method("exit"):
			_inspect.call("exit")
		return
	var item: Item = sel["item"]
	_ligar_vitrine(false)
	_inspect.visible = true
	if _inspect.has_method("enter"):
		_inspect.call("enter")
	if _inspect.has_method("set_item"):
		_inspect.call("set_item", item.id)


'''

if "func _sincronizar_inspect()" not in text:
    if "func _atualizar() -> void:" not in text:
        raise SystemExit("atualizar not found")
    text = text.replace("func _atualizar() -> void:", sync_fn + "func _atualizar() -> void:", 1)

# 6) Patch _atualizar vitrine + estado
# Replace the sel branch to respect _examinando
old_sel = """\tif sel.is_empty():\n\t\t_ligar_vitrine(false)\n\t\t_titulo.text = \"\"\n\t\t_sublinhado.visible = false\n\t\t_descricao.text = \"Nada aqui.\"\n\telse:\n\t\tvar item: Item = sel[\"item\"]\n\t\t_mostrar_vitrine(item.id, Vector2(cx, cy))\n\t\t_titulo.text = item.nome.to_upper()\n\t\t_sublinhado.visible = true\n\t\t_descricao.text = (\"%s\\nQuantidade: %d\" % [item.rotulo_tipo(), int(sel[\"qtd\"])]) \\\n\t\t\tif _examinando else item.descricao\n\n\t_estado.text = Inventario.estado()\n\t_estado.add_theme_color_override(&\"font_color\", Inventario.cor_do_estado())\n"""

new_sel = """\tif sel.is_empty():\n\t\t_ligar_vitrine(false)\n\t\tif _inspect != null and _inspect.visible:\n\t\t\t_inspect.visible = false\n\t\t\tif _inspect.has_method(\"exit\"):\n\t\t\t\t_inspect.call(\"exit\")\n\t\t_titulo.text = \"\"\n\t\t_sublinhado.visible = false\n\t\t_descricao.text = \"Nada aqui.\"\n\telse:\n\t\tvar item: Item = sel[\"item\"]\n\t\tif _examinando:\n\t\t\t_ligar_vitrine(false)\n\t\t\t_sincronizar_inspect()\n\t\telse:\n\t\t\tif _inspect != null and _inspect.visible:\n\t\t\t\t_inspect.visible = false\n\t\t\t\tif _inspect.has_method(\"exit\"):\n\t\t\t\t\t_inspect.call(\"exit\")\n\t\t\t_mostrar_vitrine(item.id, Vector2(cx, cy))\n\t\t_titulo.text = item.nome.to_upper()\n\t\t_sublinhado.visible = true\n\t\t_descricao.text = (\"%s\\nQuantidade: %d\" % [item.rotulo_tipo(), int(sel[\"qtd\"])]) \\\n\t\t\tif _examinando else item.descricao\n\n\t# Status: VitalsMonitor (Onda 3). Label BEM fica oculto.\n\tif _vitals != null and _vitals.has_method(\"refresh\"):\n\t\t_vitals.call(\"refresh\")\n\telif _estado != null and _estado.visible:\n\t\t_estado.text = Inventario.estado()\n\t\t_estado.add_theme_color_override(&\"font_color\", Inventario.cor_do_estado())\n"""

if old_sel not in text:
    # Try with Inventario vs Inventario naming - already Inventario
    # Debug: find _estado.text
    i = text.find("_estado.text")
    print("NEAR ESTADO:", repr(text[i-200:i+200]))
    raise SystemExit("sel block not found")
text = text.replace(old_sel, new_sel, 1)

# 7) On fechar, exit inspect
old_close = "\t_ligar_vitrine(false)\n\t_ligar_retrato(false)\n"
new_close = "\t_ligar_vitrine(false)\n\t_ligar_retrato(false)\n\tif _inspect != null:\n\t\t_inspect.visible = false\n\t\tif _inspect.has_method(\"exit\"):\n\t\t\t_inspect.call(\"exit\")\n\t_examinando = false\n"
if old_close not in text:
    # alternate names
    for a,b in [
        ("\t_ligar_vitrine(false)\n\t_ligar_retrato(false)\n", new_close),
    ]:
        pass
    i = text.find("_ligar_vitrine(false)")
    print("NEAR CLOSE:", repr(text[i:i+120]))
    # try _ligar_retrato
    if "\t_ligar_vitrine(false)\n\t_ligar_retrato(false)\n" in text:
        text = text.replace("\t_ligar_vitrine(false)\n\t_ligar_retrato(false)\n", new_close, 1)
    else:
        raise SystemExit("close patch failed")
else:
    text = text.replace(old_close, new_close, 1)

# 8) Skip live retrato when vitals wired — in abrir don't need change; _process still looks at corpo
# Hide retrato update when foto hidden: in _process guard already on corpo

if text == orig:
    raise SystemExit("no changes?")
path.write_text(text, encoding="utf-8")
print("PATCHED", path)
print("inspect var", "var _inspect" in text)
print("montar_onda3", "func _montar_onda3_wire" in text)
print("sincronizar", "func _sincronizar_inspect" in text)

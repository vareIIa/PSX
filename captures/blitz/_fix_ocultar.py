from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\carro.gd")
t = p.read_text(encoding="utf-8")
if "func _ocultar_motorista_visual" in t:
    print("def exists")
else:
    helper = '''

## Some / mostra malha do motorista (quando desce na blitz). Sem mesh dedicada
## de motorista, apaga a cabine/vidro se existir; senao e no-op visual.
func _ocultar_motorista_visual(esconder: bool) -> void:
	var cab := get_node_or_null("Cabine")
	if cab != null:
		cab.visible = not esconder


'''
    anchor = "func _teto_de_velocidade() -> float:"
    if anchor not in t:
        raise SystemExit("anchor missing")
    t = t.replace(anchor, helper + anchor, 1)
    p.write_text(t, encoding="utf-8")
    print("def added")

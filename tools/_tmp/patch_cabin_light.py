from pathlib import Path
p = Path(r"game/src/world/carro_cena.gd")
t = p.read_text(encoding="utf-8")
# Add cabin fill light after farois mount, and turn it on with acender_farois
if "_luz_cabine" not in t:
    t = t.replace("var _facho: MeshInstance3D\n", "var _facho: MeshInstance3D\nvar _luz_cabine: OmniLight3D\n", 1)
    old = '''	_facho.visible = false
	add_child(_facho)


func acender_farois(aceso: bool = true) -> void:
	farois_acesos = aceso
	if _farol != null:
		_farol.visible = aceso
	if _facho != null:
		_facho.visible = aceso
'''
    new = '''	_facho.visible = false
	add_child(_facho)

	# Fill fraco na cabine: sem ele o painel some na noite (refs mostram vinil).
	_luz_cabine = OmniLight3D.new()
	_luz_cabine.name = "LuzCabine"
	_luz_cabine.position = Vector3(-0.2, 1.15, -0.15)
	_luz_cabine.omni_range = 2.4
	_luz_cabine.light_energy = 0.55
	_luz_cabine.light_color = Color(1.0, 0.92, 0.82)
	_luz_cabine.shadow_enabled = false
	_luz_cabine.visible = false
	add_child(_luz_cabine)


func acender_farois(aceso: bool = true) -> void:
	farois_acesos = aceso
	if _farol != null:
		_farol.visible = aceso
	if _facho != null:
		_facho.visible = aceso
	if _luz_cabine != null:
		_luz_cabine.visible = aceso
'''
    if old not in t:
        raise SystemExit("farois block missing for fill")
    t = t.replace(old, new, 1)
    p.write_text(t, encoding="utf-8")
    print("cabin fill added")
else:
    print("already has cabin fill")

# Slightly lower eye pitch in abertura for more dashboard in frame
p2 = Path(r"game/src/levels/abertura_estrada.gd")
t2 = p2.read_text(encoding="utf-8")
t2 = t2.replace("const DENTRO_PITCH := -1.5", "const DENTRO_PITCH := -3.5", 1)
# Also bump FOV a bit closer to ref framing
t2 = t2.replace("const DENTRO_FOV := 66.0", "const DENTRO_FOV := 70.0", 1)
p2.write_text(t2, encoding="utf-8")
print("pitch/fov tuned")

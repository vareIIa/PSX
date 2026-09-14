# -*- coding: utf-8 -*-
from pathlib import Path

cri = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
cab = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\cabine_fundo_criacao.gd")
t = cri.read_text(encoding="utf-8")

def rep(old, new, label):
    global t
    if old not in t:
        raise SystemExit("MISSING " + label)
    t = t.replace(old, new, 1)
    print("ok", label)

# After portrait texture: 2D neck bridge (reliable vs BoneAttachment)
rep(
'''	draw_rect(RETRATO.grow(2.0), TINTA)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), RETRATO, false)
	# Cantoneiras do retrato 3x4 (passaporte).
''',
'''	draw_rect(RETRATO.grow(2.0), TINTA)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), RETRATO, false)
	_tapar_vao_pescoco_retrato()
	# Cantoneiras do retrato 3x4 (passaporte).
''',
"call_tapar")

# Add helper near pescoco 3D helper
rep(
'''## So no retrato da carteira: o Corpo tem ~4 cm entre topo do tronco (y≈1,38)
## e a caixa da nuca (y≈1,425). Na rua some; no 3x4 vira "cabeca flutuando".
## Preenche localmente no osso da cabeca — nao mexe no Corpo global.
func _preencher_pescoco_retrato(apar: Dictionary) -> void:
''',
'''## Overlay 2D no 3x4: pinta pele+colarinho sobre o vão cabeça/tronco.
## Mais confiavel que malha 3D extra (BoneAttachment + balanco mole).
func _tapar_vao_pescoco_retrato() -> void:
	var apar := aparencia_atual()
	var pele := Aparencia.pele_na_tela(apar)
	var camisa: Color = (apar["casaco_cor"] if bool(apar.get("casaco", false))
		else apar["camisa_cor"])
	var cx := RETRATO.position.x + RETRATO.size.x * 0.5
	# Faixa do vão no crop atual da CameraRetrato (~55–70% da altura).
	var y0 := RETRATO.position.y + RETRATO.size.y * 0.52
	draw_rect(Rect2(cx - 16.0, y0, 32.0, 12.0), pele)
	draw_rect(Rect2(cx - 12.0, y0 + 2.0, 24.0, 8.0), pele.darkened(0.08))
	draw_rect(Rect2(cx - 34.0, y0 + 10.0, 68.0, 16.0), camisa)
	draw_rect(Rect2(cx - 30.0, y0 + 12.0, 60.0, 6.0), camisa.lightened(0.08))


## So no retrato da carteira: o Corpo tem ~4 cm entre topo do tronco (y≈1,38)
## e a caixa da nuca (y≈1,425). Na rua some; no 3x4 vira "cabeca flutuando".
## Preenche localmente no osso da cabeca — nao mexe no Corpo global.
func _preencher_pescoco_retrato(apar: Dictionary) -> void:
''',
"tapar_helper")

# Tone down global modulate (was blowing window)
rep(
'''		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA),
			false, Color(1.85, 1.68, 1.48, 1.0))
''',
'''		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA),
			false, Color(1.35, 1.28, 1.18, 1.0))
''',
"modulate_tone")

cri.write_text(t, encoding="utf-8")
print("criacao written")

c = cab.read_text(encoding="utf-8")
# Tone adjustment + add key light at eye
c = c.replace("env.adjustment_brightness = 1.35", "env.adjustment_brightness = 1.12")
old_luz = '''func _montar_luzes() -> void:
	var fill := OmniLight3D.new()
	fill.name = "LuzCabine"
	fill.position = Vector3(-0.2, 1.15, -0.15)
	fill.omni_range = 3.0
	fill.light_energy = 2.1
	fill.light_color = Color(1.0, 0.94, 0.86)
	fill.shadow_enabled = false
	_pivot.add_child(fill)
'''
new_luz = '''func _montar_luzes() -> void:
	var fill := OmniLight3D.new()
	fill.name = "LuzCabine"
	fill.position = Vector3(-0.2, 1.15, -0.15)
	fill.omni_range = 3.0
	fill.light_energy = 1.6
	fill.light_color = Color(1.0, 0.94, 0.86)
	fill.shadow_enabled = false
	_pivot.add_child(fill)

	# Key perto do olho: ilumina volante/painel sem estourar o para-brisa.
	var key := OmniLight3D.new()
	key.name = "LuzOlho"
	key.omni_range = 1.6
	key.light_energy = 2.4
	key.light_color = Color(1.0, 0.96, 0.90)
	key.shadow_enabled = false
	_pivot.add_child(key)
	# Posicao depois da cabine existir — ajustada em _montar_camera.
'''
if old_luz not in c:
    raise SystemExit("luzes missing")
c = c.replace(old_luz, new_luz, 1)

old_cam = '''func _montar_camera() -> void:
	camera = Camera3D.new()
	camera.name = "CameraFP"
	camera.current = true
	camera.fov = FOV
	camera.near = 0.06
	camera.far = 40.0
	# Trava no olho da cabine; pitch fixo (sem mouse / sem HUD).
	camera.position = cabine.olho()
	camera.rotation = Vector3(PITCH_OLHO, 0.0, 0.0)
	_pivot.add_child(camera)
'''
new_cam = '''func _montar_camera() -> void:
	camera = Camera3D.new()
	camera.name = "CameraFP"
	camera.current = true
	camera.fov = FOV
	camera.near = 0.06
	camera.far = 40.0
	# Trava no olho da cabine; pitch fixo (sem mouse / sem HUD).
	camera.position = cabine.olho()
	camera.rotation = Vector3(PITCH_OLHO, 0.0, 0.0)
	_pivot.add_child(camera)
	var key := _pivot.get_node_or_null("LuzOlho") as OmniLight3D
	if key != null:
		key.position = cabine.olho() + Vector3(0.08, -0.12, -0.22)
'''
if old_cam not in c:
    raise SystemExit("camera missing")
c = c.replace(old_cam, new_cam, 1)
# Reduce sun so window less blown
c = c.replace("sol.light_energy = 1.35", "sol.light_energy = 0.7")
cab.write_text(c, encoding="utf-8")
print("cabine written")

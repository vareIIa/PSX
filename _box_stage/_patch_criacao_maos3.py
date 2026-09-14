# -*- coding: utf-8 -*-
from pathlib import Path

cri = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
cab = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\cabine_fundo_criacao.gd")
t = cri.read_text(encoding="utf-8")

old = '''	# Abaixo do osso da cabeca (y local negativo) ate o ombro.
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.12 * esc, 0.14)
	mi.mesh = box
	mi.position = Vector3(0.0, -0.055 * esc, -0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Aparencia.pele_na_tela(apar)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(mi)
	# Colarinho sob o pescoco (cor da camisa) — fecha o vão contra o peito.
	var colo := MeshInstance3D.new()
	var box_c := BoxMesh.new()
	box_c.size = Vector3(0.22, 0.06 * esc, 0.16)
	colo.mesh = box_c
	colo.position = Vector3(0.0, -0.115 * esc, -0.01)
'''
new = '''	# Abaixo do osso da cabeca (y local negativo) ate o ombro — bloco alto
	# o bastante para cobrir o vão mesmo com o balanco mole do pescoco.
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.17, 0.18 * esc, 0.15)
	mi.mesh = box
	mi.position = Vector3(0.0, -0.07 * esc, -0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Aparencia.pele_na_tela(apar)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(mi)
	# Colarinho/ombro sob o pescoco (cor da camisa) — fecha contra o peito.
	var colo := MeshInstance3D.new()
	var box_c := BoxMesh.new()
	box_c.size = Vector3(0.30, 0.14 * esc, 0.20)
	colo.mesh = box_c
	colo.position = Vector3(0.0, -0.175 * esc, -0.02)
'''
if old not in t:
    raise SystemExit("neck block missing")
t = t.replace(old, new, 1)

# Camera: look slightly lower / closer so peito sobe e o vão some do crop
old_c = '''	camera.fov = 26.0
	camera.near = 0.05
	camera.position = Vector3(0.0, 1.38, -1.62)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.36, 0.0), Vector3.UP)
'''
new_c = '''	camera.fov = 25.0
	camera.near = 0.05
	camera.position = Vector3(0.0, 1.34, -1.48)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.34, 0.0), Vector3.UP)
'''
if old_c not in t:
    raise SystemExit("camera block missing")
t = t.replace(old_c, new_c, 1)

# Even brighter cabin modulate
t = t.replace(
    "false, Color(1.55, 1.42, 1.28, 1.0))",
    "false, Color(1.85, 1.68, 1.48, 1.0))",
)
cri.write_text(t, encoding="utf-8")
print("criacao ok")

c = cab.read_text(encoding="utf-8")
# Add adjustment brightness to environment
old_e = '''	env.ambient_light_energy = 1.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
'''
new_e = '''	env.ambient_light_energy = 1.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.35
	env.adjustment_contrast = 1.05
	we.environment = env
'''
if old_e not in c:
    raise SystemExit("env block missing:\n" + c[c.find("ambient_light_energy"):c.find("ambient_light_energy")+200])
cab.write_text(c.replace(old_e, new_e, 1), encoding="utf-8")
print("cabine ok")

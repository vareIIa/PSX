# -*- coding: utf-8 -*-
from pathlib import Path

CRIACAO = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
CABINE = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\cabine_fundo_criacao.gd")
MENU = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\menu.gd")

text = CRIACAO.read_text(encoding="utf-8")

def must_replace(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f"MISSING: {label}")
    text = text.replace(old, new, 1)
    print("ok:", label)

# Cabin draw: brighten texture + almost no veil
must_replace(
'''	if _cabine_viewport != null:
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA), false)
		# Veu bem leve: a cabine precisa ler (volante/painel) sem lavar o papel.
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.05, 0.05))
''',
'''	if _cabine_viewport != null:
		# Modulate sobe exposicao: a cabine live chega escura demais atras do
		# papel (e a vinheta do Menu ainda come um pouco). Sem lavar o documento.
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA),
			false, Color(1.55, 1.42, 1.28, 1.0))
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.01, 0.02, 0.03, 0.02))
''',
"veil2")

# Neck fill via BoneAttachment on cabeca
must_replace(
'''## So no retrato da carteira: o Corpo tem ~4 cm entre topo do tronco (y≈1,38)
## e a caixa da nuca (y≈1,425). Na rua some; no 3x4 vira "cabeca flutuando".
## Preenche localmente — nao mexe no Corpo global.
func _preencher_pescoco_retrato(apar: Dictionary) -> void:
	if _corpo == null:
		return
	var velho := _corpo.get_node_or_null("PescocoRetrato")
	if velho != null:
		velho.queue_free()
	var esc := float(apar.get("altura", 1.72)) / 1.72
	var mi := MeshInstance3D.new()
	mi.name = "PescocoRetrato"
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.075 * esc, 0.13)
	mi.mesh = box
	mi.position = Vector3(0.0, 1.405 * esc, 0.01)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Aparencia.pele_na_tela(apar)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corpo.add_child(mi)
''',
'''## So no retrato da carteira: o Corpo tem ~4 cm entre topo do tronco (y≈1,38)
## e a caixa da nuca (y≈1,425). Na rua some; no 3x4 vira "cabeca flutuando".
## Preenche localmente no osso da cabeca — nao mexe no Corpo global.
func _preencher_pescoco_retrato(apar: Dictionary) -> void:
	if _corpo == null:
		return
	var sk := _corpo.esqueleto()
	if sk == null:
		return
	var velho := sk.get_node_or_null("PescocoRetrato")
	if velho != null:
		velho.queue_free()
	var esc := float(apar.get("altura", 1.72)) / 1.72
	var att := BoneAttachment3D.new()
	att.name = "PescocoRetrato"
	att.bone_name = "cabeca"
	sk.add_child(att)
	# Abaixo do osso da cabeca (y local negativo) ate o ombro.
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
	var mat_c := StandardMaterial3D.new()
	var camisa: Color = (apar["casaco_cor"] if bool(apar.get("casaco", false))
		else apar["camisa_cor"])
	mat_c.albedo_color = camisa
	mat_c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	colo.material_override = mat_c
	colo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(colo)
''',
"pescoco2")

# Hands: longer reach, fuller palm — replace finger/palm section via whole function again
# Find and tweak finger length constants in place
must_replace(
'''		var base_x := TELA.x * 0.5 + lado * 158.0
		var punho_x := TELA.x * 0.5 + lado * 96.0
		var base := Vector2(base_x, TELA.y + 28.0) + balanco
		var punho := Vector2(punho_x, 214.0) + balanco
''',
'''		var base_x := TELA.x * 0.5 + lado * 162.0
		var punho_x := TELA.x * 0.5 + lado * 92.0
		var base := Vector2(base_x, TELA.y + 30.0) + balanco
		var punho := Vector2(punho_x, 208.0) + balanco
''',
"braco_geom")

must_replace(
'''		# 3. Palma — mais larga e longa (menos "toco").
		var mao_base := cuff_topo + eixo * 1.0
		var palma_centro := mao_base + eixo * 14.0
		_poly4(
			mao_base - perp * 18.0,
			mao_base + perp * 18.0,
			palma_centro + perp * 19.0 + eixo * 6.0,
			palma_centro - perp * 17.0 + eixo * 6.0,
			tom_medio)
''',
'''		# 3. Palma — larga, sobe por cima da borda do documento.
		var mao_base := cuff_topo + eixo * 1.0
		var palma_centro := mao_base + eixo * 16.0
		_poly4(
			mao_base - perp * 20.0,
			mao_base + perp * 20.0,
			palma_centro + perp * 21.0 + eixo * 8.0,
			palma_centro - perp * 19.0 + eixo * 8.0,
			tom_medio)
''',
"palma2")

must_replace(
'''		# 4. Dedos longos na borda inferior do documento.
		for i in 4:
			var offset_dedo := (float(i) - 1.5) * 7.2
			var d_origem := palma_centro + perp * (offset_dedo) + eixo * 4.0
			var d_ponta := d_origem + eixo * 20.0 - perp * (1.5 * lado)
			var d_larg := 3.6
''',
'''		# 4. Dedos longos na borda inferior do documento.
		for i in 4:
			var offset_dedo := (float(i) - 1.5) * 7.8
			var d_origem := palma_centro + perp * (offset_dedo) + eixo * 5.0
			var d_ponta := d_origem + eixo * 26.0 - perp * (1.2 * lado)
			var d_larg := 4.0
''',
"dedos2")

must_replace(
'''		var pol_base := palma_centro - perp * (8.0 * lado) - eixo * 1.0
		var pol_junta := pol_base + Vector2(-lado * 16.0, -12.0)
		var pol_ponta := pol_junta + Vector2(-lado * 13.0, -8.0)
		var p_larg := 5.5
''',
'''		var pol_base := palma_centro - perp * (9.0 * lado) - eixo * 1.0
		var pol_junta := pol_base + Vector2(-lado * 18.0, -14.0)
		var pol_ponta := pol_junta + Vector2(-lado * 15.0, -9.0)
		var p_larg := 6.0
''',
"polegar2")

CRIACAO.write_text(text, encoding="utf-8")
print("criacao updated")

# Cabine lights even brighter
cab = CABINE.read_text(encoding="utf-8")
cab = cab.replace("fill.light_energy = 1.45", "fill.light_energy = 2.1")
cab = cab.replace("dash.light_energy = 0.85", "dash.light_energy = 1.35")
cab = cab.replace("sol.light_energy = 0.95", "sol.light_energy = 1.35")
cab = cab.replace("env.ambient_light_energy = 1.05", "env.ambient_light_energy = 1.45")
cab = cab.replace("env.background_color = Color(0.28, 0.32, 0.34)",
                  "env.background_color = Color(0.34, 0.38, 0.40)")
cab = cab.replace("env.ambient_light_color = Color(0.48, 0.46, 0.42)",
                  "env.ambient_light_color = Color(0.58, 0.55, 0.50)")
CABINE.write_text(cab, encoding="utf-8")
print("cabine updated")

# Menu: hide UI vignette on APARENCIA so cabin reads (criação-related compose)
menu = MENU.read_text(encoding="utf-8")
old_v = '''	if _vinheta_ui != null:
		_vinheta_ui.visible = not vivo
'''
new_v = '''	if _vinheta_ui != null:
		# Aparencia traz a cabine 3D atras da carteira — vinheta comia o volante.
		_vinheta_ui.visible = (not vivo) and qual != Painel.APARENCIA
'''
if old_v not in menu:
    raise SystemExit("menu vinheta block missing")
MENU.write_text(menu.replace(old_v, new_v, 1), encoding="utf-8")
print("menu vinheta updated")
print("DONE")

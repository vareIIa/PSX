# -*- coding: utf-8 -*-
"""Patch criacao.gd + cabine_fundo_criacao.gd: maos, veil, print02, pescoco."""
from pathlib import Path

CRIACAO = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
CABINE = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\cabine_fundo_criacao.gd")

text = CRIACAO.read_text(encoding="utf-8")
orig = text

def must_replace(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f"MISSING: {label}\n--- snippet ---\n{old[:200]}")
    text = text.replace(old, new, 1)
    print("ok:", label)

# --- 1) Lighter veil so volante/painel read ---
must_replace(
'''	if _cabine_viewport != null:
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.04, 0.16))
''',
'''	if _cabine_viewport != null:
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA), false)
		# Veu bem leve: a cabine precisa ler (volante/painel) sem lavar o papel.
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.05, 0.05))
''',
"veil")

# --- 2) Passport cover: thicker blue rim + page grid hint ---
must_replace(
'''	var local := Rect2(-DOC.size * 0.5, DOC.size)
	# Capa azul sob o papel (print02): filete inferior/laterais.
	draw_rect(Rect2(local.position + Vector2(-3.0, 4.0),
		Vector2(local.size.x + 6.0, local.size.y + 6.0)), CAPA)
	draw_rect(Rect2(local.position + Vector2(3.0, 5.0), local.size),
		Color(0.02, 0.03, 0.02, 0.5))
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	draw_rect(local.grow(-3.0), Color(0.92, 0.89, 0.80, 0.22), false, 1.0)
	draw_rect(local, TINTA_FRACA, false, 1.0)
	# Vinco do meio: e o que faz duas paginas em vez de um cartaz.
	draw_rect(Rect2(-1.0, local.position.y + 6.0, 2.0, local.size.y - 12.0), VINCO)
''',
'''	var local := Rect2(-DOC.size * 0.5, DOC.size)
	# Capa azul do passaporte (print02): filete mais largo, como capa dura.
	draw_rect(Rect2(local.position + Vector2(-5.0, 3.0),
		Vector2(local.size.x + 10.0, local.size.y + 9.0)), CAPA)
	draw_rect(Rect2(local.position + Vector2(-4.0, 4.0),
		Vector2(local.size.x + 8.0, local.size.y + 7.0)), CAPA.lightened(0.08))
	draw_rect(Rect2(local.position + Vector2(3.0, 5.0), local.size),
		Color(0.02, 0.03, 0.02, 0.5))
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	# Grade miuda de pagina (affordance passaporte) — so nas margens.
	var grade := Color(0.70, 0.66, 0.55, 0.18)
	for gx in range(1, 8):
		var gx_x := local.position.x + 8.0 + float(gx) * (local.size.x - 16.0) / 8.0
		draw_line(Vector2(gx_x, local.position.y + 8.0),
			Vector2(gx_x, local.end.y - 8.0), grade, 1.0)
	for gy in range(1, 5):
		var gy_y := local.position.y + 10.0 + float(gy) * (local.size.y - 20.0) / 5.0
		draw_line(Vector2(local.position.x + 8.0, gy_y),
			Vector2(local.end.x - 8.0, gy_y), grade, 1.0)
	draw_rect(local.grow(-3.0), Color(0.92, 0.89, 0.80, 0.28), false, 1.0)
	draw_rect(local.grow(-6.0), Color(CAPA.r, CAPA.g, CAPA.b, 0.22), false, 1.0)
	draw_rect(local, TINTA_FRACA, false, 1.0)
	# Vinco do meio: e o que faz duas paginas em vez de um cartaz.
	draw_rect(Rect2(-1.0, local.position.y + 6.0, 2.0, local.size.y - 12.0), VINCO)
''',
"papel_passport")

# --- 3) Replace _desenhar_bracos entirely (valid quads + fuller hands) ---
old_bracos_start = text.find("func _desenhar_bracos() -> void:")
old_bracos_end = text.find("func _desenhar_pagina_esquerda() -> void:")
if old_bracos_start < 0 or old_bracos_end < 0:
    raise SystemExit("bracos anchors missing")
new_bracos = r'''func _desenhar_bracos() -> void:
	var a := aparencia_atual()
	var pele := Aparencia.pele_na_tela(a)
	var manga: Color = (a["casaco_cor"] if bool(a.get("casaco", false))
		else a["camisa_cor"])
	var tom_sombra := pele.darkened(0.26)
	var tom_medio := pele.darkened(0.12)
	var tom_luz := pele.lightened(0.10)
	var manga_sombra := manga.darkened(0.32)
	var manga_dobra := manga.lightened(0.12)

	var balanco := Vector2(sin(_relogio * 1.05) * 1.0, cos(_relogio * 0.85) * 0.7)
	for lado: float in [-1.0, 1.0]:
		# Geometria do antebraco e punho
		var base_x := TELA.x * 0.5 + lado * 158.0
		var punho_x := TELA.x * 0.5 + lado * 96.0
		var base := Vector2(base_x, TELA.y + 28.0) + balanco
		var punho := Vector2(punho_x, 214.0) + balanco
		var eixo := (punho - base).normalized()
		var perp := Vector2(-eixo.y, eixo.x)
		# Lateral externa: +perp no braco esquerdo, -perp no direito.
		var ext := -1.0 if lado > 0.0 else 1.0

		# 1. Antebraco — quad convexo em ordem de contorno (sem bowtie).
		_poly4(base + perp * 28.0, base - perp * 28.0,
			punho - perp * 18.0, punho + perp * 18.0, manga)
		# Sombra na faixa externa (outer→inner→inner→outer).
		_poly4(
			base + perp * (ext * 28.0),
			base + perp * (ext * 10.0),
			punho + perp * (ext * 6.0),
			punho + perp * (ext * 18.0),
			manga_sombra)

		# 2. Punho / cuff
		var cuff_topo := punho + eixo * 9.0
		_poly4(punho - perp * 20.0, punho + perp * 20.0,
			cuff_topo + perp * 19.0, cuff_topo - perp * 19.0, manga_dobra)
		draw_line(punho - perp * 19.0, punho + perp * 19.0, manga_sombra, 1.5)

		# 3. Palma — mais larga e longa (menos "toco").
		var mao_base := cuff_topo + eixo * 1.0
		var palma_centro := mao_base + eixo * 14.0
		_poly4(
			mao_base - perp * 18.0,
			mao_base + perp * 18.0,
			palma_centro + perp * 19.0 + eixo * 6.0,
			palma_centro - perp * 17.0 + eixo * 6.0,
			tom_medio)
		# Eminencia tenar (volume na base do polegar).
		_poly4(
			mao_base - perp * (14.0 * ext),
			mao_base - perp * (4.0 * ext),
			palma_centro - perp * (6.0 * ext) + eixo * 2.0,
			palma_centro - perp * (16.0 * ext) + eixo * 2.0,
			tom_sombra.lightened(0.08))

		# 4. Dedos longos na borda inferior do documento.
		for i in 4:
			var offset_dedo := (float(i) - 1.5) * 7.2
			var d_origem := palma_centro + perp * (offset_dedo) + eixo * 4.0
			var d_ponta := d_origem + eixo * 20.0 - perp * (1.5 * lado)
			var d_larg := 3.6
			_poly4(
				d_origem - perp * d_larg,
				d_origem + perp * d_larg,
				d_ponta + perp * (d_larg - 0.8),
				d_ponta - perp * (d_larg - 0.8),
				pele if i % 2 == 0 else tom_medio)
			draw_line(d_ponta - perp * 2.0, d_ponta + perp * 2.0, tom_sombra, 1.0)

		# 5. Polegar sobre a margem do cartao.
		var pol_base := palma_centro - perp * (8.0 * lado) - eixo * 1.0
		var pol_junta := pol_base + Vector2(-lado * 16.0, -12.0)
		var pol_ponta := pol_junta + Vector2(-lado * 13.0, -8.0)
		var p_larg := 5.5
		_poly4(
			pol_base + perp * p_larg, pol_base - perp * p_larg,
			pol_junta - perp * (p_larg + 0.5), pol_junta + perp * (p_larg + 0.5),
			tom_medio)
		_poly4(
			pol_junta + perp * (p_larg + 0.5), pol_junta - perp * (p_larg + 0.5),
			pol_ponta - perp * (p_larg - 1.0), pol_ponta + perp * (p_larg - 1.0),
			pele)
		draw_line(pol_junta - Vector2(0.0, 3.0), pol_ponta - Vector2(0.0, 2.0),
			tom_luz, 1.2)
		var unha_pos := pol_ponta + Vector2(lado * 2.0, 0.0)
		_poly4(
			unha_pos + Vector2(-2.0, -2.0), unha_pos + Vector2(2.0, -2.0),
			unha_pos + Vector2(1.5, 2.0), unha_pos + Vector2(-1.5, 2.0),
			tom_luz.lightened(0.15))
		draw_line(pol_ponta + Vector2(-lado * 2.0, 4.0), pol_junta + Vector2(0.0, 5.0),
			Color(0.05, 0.08, 0.05, 0.5), 1.5)


## Quad convexo como dois triangulos. Evita "Invalid polygon data, triangulation
## failed" do draw_colored_polygon em quads com winding/ordem ambigua.
func _poly4(a: Vector2, b: Vector2, c: Vector2, d: Vector2, cor: Color) -> void:
	# Descarta degenerados (area ~0) antes de pedir triangulacao ao motor.
	if absf((b - a).cross(c - a)) < 0.35 and absf((c - a).cross(d - a)) < 0.35:
		return
	draw_colored_polygon(PackedVector2Array([a, b, c]), cor)
	draw_colored_polygon(PackedVector2Array([a, c, d]), cor)


'''
text = text[:old_bracos_start] + new_bracos + text[old_bracos_end:]
print("ok: bracos+_poly4")

# --- 4) Left page: passport header + portrait frame corners ---
must_replace(
'''func _desenhar_pagina_esquerda() -> void:
	if _brasao != null:
		draw_texture_rect(_brasao, Rect2(PAGINA_ESQ.position.x + 4.0, 26.0,
			18.0, 18.0), false)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 33.0), "CARTEIRA DE", TINTA_FRACA)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 46.0), "IDENTIDADE", TINTA,
		_fonte_media)

	draw_rect(RETRATO.grow(2.0), TINTA)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), RETRATO, false)
''',
'''func _desenhar_pagina_esquerda() -> void:
	if _brasao != null:
		draw_texture_rect(_brasao, Rect2(PAGINA_ESQ.position.x + 4.0, 26.0,
			18.0, 18.0), false)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 28.0), "REP. FED. DO BRASIL",
		Color(CAPA.r, CAPA.g, CAPA.b, 0.85), _fonte)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 39.0), "CARTEIRA DE", TINTA_FRACA)
	_texto(Vector2(PAGINA_ESQ.position.x + 26.0, 50.0), "IDENTIDADE", TINTA,
		_fonte_media)

	draw_rect(RETRATO.grow(2.0), TINTA)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), RETRATO, false)
	# Cantoneiras do retrato 3x4 (passaporte).
	var c := RETRATO
	var k := 7.0
	var ck := Color(CAPA.r, CAPA.g, CAPA.b, 0.75)
	draw_line(c.position, c.position + Vector2(k, 0.0), ck, 1.5)
	draw_line(c.position, c.position + Vector2(0.0, k), ck, 1.5)
	draw_line(Vector2(c.end.x, c.position.y), Vector2(c.end.x - k, c.position.y), ck, 1.5)
	draw_line(Vector2(c.end.x, c.position.y), Vector2(c.end.x, c.position.y + k), ck, 1.5)
	draw_line(Vector2(c.position.x, c.end.y), Vector2(c.position.x + k, c.end.y), ck, 1.5)
	draw_line(Vector2(c.position.x, c.end.y), Vector2(c.position.x, c.end.y - k), ck, 1.5)
	draw_line(c.end, c.end - Vector2(k, 0.0), ck, 1.5)
	draw_line(c.end, c.end - Vector2(0.0, k), ck, 1.5)
''',
"pagina_esq")

# --- 5) Option cells: stronger grid affordance (inner hatch on unselected) ---
must_replace(
'''	# Celula do atlas: mostra o desenho de verdade, e nao um numero.
	var quantos := int(campo["quantos"])
	var atual_i := int(_ajustes.get(chave, 0)) % quantos
	var linha := _linha_do_atlas(chave)
	var passo_cel := largura / float(quantos)
	for k in quantos:
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0, 20.0)
		draw_rect(r, Color(0.80, 0.78, 0.68, 0.55))
		if _atlas != null:
			draw_texture_rect_region(_atlas, r.grow(-1.0), Rect2(
				float(k * Aparencia.CELULA), float(linha * Aparencia.CELULA),
				float(Aparencia.CELULA), float(Aparencia.CELULA)))
		var sel := k == atual_i
		var hov := ativo and k == _hover_celula
		if sel:
			draw_rect(r.grow(1.0), CELULA_SEL, false, 2.0)
			if ativo:
				draw_rect(r.grow(2.0), DESTAQUE, false, 1.0)
		elif hov:
			draw_rect(r.grow(1.0), DESTAQUE, false, 1.0)
''',
'''	# Celula do atlas: mostra o desenho de verdade, e nao um numero.
	var quantos := int(campo["quantos"])
	var atual_i := int(_ajustes.get(chave, 0)) % quantos
	var linha := _linha_do_atlas(chave)
	var passo_cel := largura / float(quantos)
	for k in quantos:
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0, 20.0)
		draw_rect(r, Color(0.80, 0.78, 0.68, 0.55))
		# Grade interna leve (print02: celula clicavel).
		draw_rect(r.grow(-2.0), Color(0.55, 0.52, 0.42, 0.20), false, 1.0)
		if _atlas != null:
			draw_texture_rect_region(_atlas, r.grow(-1.0), Rect2(
				float(k * Aparencia.CELULA), float(linha * Aparencia.CELULA),
				float(Aparencia.CELULA), float(Aparencia.CELULA)))
		var sel := k == atual_i
		var hov := ativo and k == _hover_celula
		if sel:
			draw_rect(r.grow(1.0), CELULA_SEL, false, 2.0)
			if ativo:
				draw_rect(r.grow(2.0), DESTAQUE, false, 1.0)
		elif hov:
			draw_rect(r.grow(1.0), DESTAQUE, false, 1.0)
''',
"celulas_grid")

# --- 6) Neck gap: criação-local filler + camera crop tweak ---
must_replace(
'''	var camera := Camera3D.new()
	camera.fov = 24.0
	camera.near = 0.05
	camera.position = Vector3(0.0, 1.42, -1.75)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.40, 0.0), Vector3.UP)
	camera.current = true
''',
'''	var camera := Camera3D.new()
	camera.name = "CameraRetrato"
	# FOV um pouco mais aberto + look um pouco abaixo: ombro sobe no quadro e
	# o vão pescoco (Corpo) fica menos evidente no crop 3x4.
	camera.fov = 26.0
	camera.near = 0.05
	camera.position = Vector3(0.0, 1.38, -1.62)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.36, 0.0), Vector3.UP)
	camera.current = true
''',
"camera_retrato")

must_replace(
'''func _refazer_corpo() -> void:
	if _corpo != null:
		_corpo.queue_free()
	_corpo = Corpo.new()
	_viewport.add_child(_corpo)
	_corpo.montar(aparencia_atual())
	_corpo.rotation.y = _giro
	_corpo.animar(0.0, 0.016)
''',
'''func _refazer_corpo() -> void:
	if _corpo != null:
		_corpo.queue_free()
	_corpo = Corpo.new()
	_viewport.add_child(_corpo)
	var apar := aparencia_atual()
	_corpo.montar(apar)
	_corpo.rotation.y = _giro
	_corpo.animar(0.0, 0.016)
	_preencher_pescoco_retrato(apar)
''',
"refazer_corpo")

# Insert neck helper before _desenhar_bracos comment block or after aparencia_atual
must_replace(
'''## Publica: a verificacao le a aparencia montada sem abrir a tela.
func aparencia_atual() -> Dictionary:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	return Aparencia.com_ajustes(Aparencia.de_ficha(ficha), _ajustes)
''',
'''## Publica: a verificacao le a aparencia montada sem abrir a tela.
func aparencia_atual() -> Dictionary:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	return Aparencia.com_ajustes(Aparencia.de_ficha(ficha), _ajustes)


## So no retrato da carteira: o Corpo tem ~4 cm entre topo do tronco (y≈1,38)
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
"pescoco_helper")

if text == orig:
    raise SystemExit("no changes applied to criacao.gd")
CRIACAO.write_text(text, encoding="utf-8")
print("wrote criacao.gd", len(text))

# --- cabine exposure ---
cab = CABINE.read_text(encoding="utf-8")
cab_orig = cab

def cab_rep(old, new, label):
    global cab
    if old not in cab:
        raise SystemExit(f"CABINE MISSING: {label}")
    cab = cab.replace(old, new, 1)
    print("ok cabine:", label)

cab_rep("const FOV := 68.0", "const FOV := 62.0", "fov")
cab_rep("const PITCH_OLHO := -0.38", "const PITCH_OLHO := -0.30", "pitch")
cab_rep(
'''	fill.omni_range = 2.6
	fill.light_energy = 0.72
	fill.light_color = Color(1.0, 0.92, 0.82)
''',
'''	fill.omni_range = 3.0
	fill.light_energy = 1.45
	fill.light_color = Color(1.0, 0.94, 0.86)
''',
"fill")
cab_rep(
'''	dash.omni_range = 1.4
	dash.light_energy = 0.35
	dash.light_color = Color(0.95, 0.75, 0.45)
''',
'''	dash.omni_range = 1.8
	dash.light_energy = 0.85
	dash.light_color = Color(1.0, 0.82, 0.55)
''',
"dash")
cab_rep(
'''	sol.light_energy = 0.45
	sol.light_color = Color(0.85, 0.90, 1.0)
''',
'''	sol.light_energy = 0.95
	sol.light_color = Color(0.90, 0.93, 1.0)
''',
"sol")
cab_rep(
'''	env.background_color = Color(0.22, 0.26, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.34, 0.32)
	env.ambient_light_energy = 0.55
''',
'''	env.background_color = Color(0.28, 0.32, 0.34)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.46, 0.42)
	env.ambient_light_energy = 1.05
''',
"ambient")

CABINE.write_text(cab, encoding="utf-8")
print("wrote cabine_fundo_criacao.gd")
print("DONE")

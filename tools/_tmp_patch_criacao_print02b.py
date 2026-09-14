# -*- coding: utf-8 -*-
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
text = path.read_text(encoding="utf-8")
orig = text

def must_replace(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f"MISSING: {label}")
    text = text.replace(old, new, 1)
    print("ok:", label)

# Colors / passport paper
must_replace(
'''const TINTA := Color("22301f")
const TINTA_FRACA := Color("5c6b52")
const PAPEL := Color("e3e9d6")
const VINCO := Color("b9c3aa")
const DESTAQUE := Color("8a2f1f")
''',
'''const TINTA := Color("22301f")
const TINTA_FRACA := Color("5c6b52")
const PAPEL := Color("ebe6d4")
const VINCO := Color("c4bba8")
const DESTAQUE := Color("8a2f1f")
## Capa azul do passaporte (print02) — filete sob o papel.
const CAPA := Color("2c4570")
const CELULA_SEL := Color("f4f1e6")
''',
"colors")

# Harden cabin load: ALWAYS on scene + print + PNG via ResourceLoader
must_replace(
'''func _carregar_cabine() -> void:
	# Preferencia: PackedScene 3D (piloto FP). Fallback: PNG estatico.
	if ResourceLoader.exists(CABINE_CENA):
		var packed := load(CABINE_CENA) as PackedScene
		if packed != null:
			_cabine_viewport = SubViewport.new()
			_cabine_viewport.name = "CabineFundo"
			_cabine_viewport.size = Vector2i(int(TELA.x), int(TELA.y))
			_cabine_viewport.own_world_3d = true
			_cabine_viewport.transparent_bg = false
			_cabine_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_cabine_viewport.msaa_3d = Viewport.MSAA_DISABLED
			_cabine_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_cabine_viewport)
			var cena := packed.instantiate()
			_cabine_viewport.add_child(cena)
			return

	var candidatos: PackedStringArray = [
''',
'''func _carregar_cabine() -> void:
	# Preferencia: PackedScene 3D (piloto FP). Fallback: PNG estatico.
	# Menu pausa a arvore em APARENCIA — SubViewport + cena em ALWAYS para o
	# micro-idle da cabine continuar (ver CabineFundoCriacao._process).
	if ResourceLoader.exists(CABINE_CENA):
		var packed := load(CABINE_CENA) as PackedScene
		if packed != null:
			_cabine_viewport = SubViewport.new()
			_cabine_viewport.name = "CabineFundo"
			_cabine_viewport.size = Vector2i(int(TELA.x), int(TELA.y))
			_cabine_viewport.own_world_3d = true
			_cabine_viewport.transparent_bg = false
			_cabine_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_cabine_viewport.msaa_3d = Viewport.MSAA_DISABLED
			_cabine_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_cabine_viewport)
			var cena := packed.instantiate()
			cena.process_mode = Node.PROCESS_MODE_ALWAYS
			_cabine_viewport.add_child(cena)
			print("[criacao] cabine live: %s" % CABINE_CENA)
			return

	# Interim Texture2D (+ mascara LOCAL/HORA no _draw).
	if ResourceLoader.exists(UI % "criacao_cabine"):
		_cabine = load(UI % "criacao_cabine") as Texture2D
		if _cabine != null:
			print("[criacao] cabine fallback PNG (asset)")
			return

	var candidatos: PackedStringArray = [
''',
"carregar_cabine")

# Lighter veil on live cabine
must_replace(
'''	if _cabine_viewport != null:
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
	elif _cabine != null:
''',
'''	if _cabine_viewport != null:
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.04, 0.16))
	elif _cabine != null:
''',
"veil")

# Paper: blue cover lip
must_replace(
'''	var local := Rect2(-DOC.size * 0.5, DOC.size)
	draw_rect(Rect2(local.position + Vector2(3.0, 5.0), local.size),
		Color(0.02, 0.03, 0.02, 0.5))
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	draw_rect(local, TINTA_FRACA, false, 1.0)
	# Vinco do meio: e o que faz duas paginas em vez de um cartaz.
	draw_rect(Rect2(-1.0, local.position.y + 6.0, 2.0, local.size.y - 12.0), VINCO)
''',
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
"papel")

# Tabs raised
must_replace(
'''func _desenhar_abas() -> void:
	for i in ABAS.size():
		var r := _rect_aba(i)
		var ativa := i == _aba
		var hover := i == _hover_aba
		draw_rect(r, Color(0.83, 0.86, 0.76) if ativa else Color(0.73, 0.77, 0.67))
		var borda := DESTAQUE if (ativa and _linha == LINHA_ABAS) or hover else TINTA_FRACA
		draw_rect(r, borda, false, 2.0 if hover else 1.0)
		_icone_da_aba(String(ABAS[i]["icone"]), r.get_center(),
			TINTA if ativa or hover else TINTA_FRACA)



''',
'''func _desenhar_abas() -> void:
	for i in ABAS.size():
		var r := _rect_aba(i)
		var ativa := i == _aba
		var hover := i == _hover_aba
		# Aba ativa sobe 2px (print02 raised tab). Hit-area permanece em _rect_aba.
		var visual := r
		if ativa:
			visual = Rect2(r.position.x, r.position.y - 2.0, r.size.x, r.size.y + 2.0)
			draw_rect(Rect2(visual.position + Vector2(1.0, 2.0), visual.size),
				Color(0.15, 0.12, 0.08, 0.28))
		var fill := (Color(0.93, 0.90, 0.80) if ativa
			else (Color(0.82, 0.80, 0.70) if hover else Color(0.74, 0.72, 0.62)))
		draw_rect(visual, fill)
		var borda := CELULA_SEL if ativa else (DESTAQUE if hover else TINTA_FRACA)
		draw_rect(visual, borda, false, 2.0 if ativa or hover else 1.0)
		if ativa and _linha == LINHA_ABAS:
			draw_rect(visual, DESTAQUE, false, 1.0)
		_icone_da_aba(String(ABAS[i]["icone"]), visual.get_center(),
			TINTA if ativa or hover else TINTA_FRACA)


''',
"abas")

# Campos spacing
must_replace(
'''func _desenhar_campos() -> void:
	var x := PAGINA_DIR.position.x
	var y := 96.0
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		var ativo := _linha == i + 1
		if ativo:
			draw_rect(Rect2(x - 3.0, y - 3.0, PAGINA_DIR.size.x - 6.0, 34.0),
				Color(0.79, 0.83, 0.72, 0.85))
		_texto(Vector2(x, y + 8.0), String(campo["rotulo"]),
			DESTAQUE if ativo else TINTA_FRACA)
		_desenhar_escolha(campo, Vector2(x, y + 12.0), ativo)
		y += 38.0
''',
'''func _desenhar_campos() -> void:
	var x := PAGINA_DIR.position.x
	var y := 98.0
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		var ativo := _linha == i + 1
		if ativo:
			draw_rect(Rect2(x - 3.0, y - 3.0, PAGINA_DIR.size.x - 6.0, 36.0),
				Color(0.86, 0.84, 0.74, 0.72))
		_texto(Vector2(x, y + 8.0), String(campo["rotulo"]),
			DESTAQUE if ativo else TINTA_FRACA)
		_desenhar_escolha(campo, Vector2(x, y + 12.0), ativo)
		y += 40.0
''',
"campos")

# Option cell affordances
must_replace(
'''	if tipo == "lista":
		var itens: Array = campo["itens"]
		var indice := int(_ajustes.get(chave, 0)) % itens.size()
		var passo := largura / float(itens.size())
		for k in itens.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 2.0, passo - 2.0, 15.0)
			draw_rect(r, Color(0.87, 0.89, 0.80) if k == indice
				else Color(0.75, 0.78, 0.69))
			draw_rect(r, DESTAQUE if (k == indice and ativo) else TINTA_FRACA,
				false, 1.0)
			_texto(Vector2(r.position.x, r.position.y + 11.0),
				String(itens[k]).substr(0, 4), TINTA, _fonte,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return

	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var atual: Color = _ajustes.get(chave, cores[0])
		var passo := largura / float(maxi(1, cores.size()))
		for k in cores.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 3.0,
				maxf(4.0, passo - 1.0), 13.0)
			draw_rect(r, cores[k])
			if cores[k].is_equal_approx(atual):
				draw_rect(r.grow(1.0), DESTAQUE if ativo else TINTA, false, 1.0)
		return

	# Celula do atlas: mostra o desenho de verdade, e nao um numero.
	var quantos := int(campo["quantos"])
	var atual_i := int(_ajustes.get(chave, 0)) % quantos
	var linha := _linha_do_atlas(chave)
	var passo_cel := largura / float(quantos)
	for k in quantos:
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0, 18.0)
		if _atlas != null:
			draw_texture_rect_region(_atlas, r, Rect2(
				float(k * Aparencia.CELULA), float(linha * Aparencia.CELULA),
				float(Aparencia.CELULA), float(Aparencia.CELULA)))
		if k == atual_i:
			draw_rect(r.grow(1.0), DESTAQUE if ativo else TINTA, false, 1.0)
''',
'''	if tipo == "lista":
		var itens: Array = campo["itens"]
		var indice := int(_ajustes.get(chave, 0)) % itens.size()
		var passo := largura / float(itens.size())
		for k in itens.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 2.0, passo - 2.0, 16.0)
			var sel := k == indice
			var hov := ativo and k == _hover_celula
			draw_rect(r, Color(0.90, 0.88, 0.78) if sel
				else (Color(0.84, 0.82, 0.72) if hov else Color(0.76, 0.74, 0.64)))
			var borda := CELULA_SEL if sel else (DESTAQUE if hov else TINTA_FRACA)
			draw_rect(r.grow(1.0 if sel else 0.0), borda, false, 2.0 if sel else 1.0)
			_texto(Vector2(r.position.x, r.position.y + 12.0),
				String(itens[k]).substr(0, 4), TINTA, _fonte,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return

	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var atual: Color = _ajustes.get(chave, cores[0])
		var passo := largura / float(maxi(1, cores.size()))
		for k in cores.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 3.0,
				maxf(4.0, passo - 1.0), 14.0)
			draw_rect(r, cores[k])
			var sel := cores[k].is_equal_approx(atual)
			var hov := ativo and k == _hover_celula
			if sel:
				draw_rect(r.grow(1.5), CELULA_SEL, false, 2.0)
				if ativo:
					draw_rect(r.grow(2.5), DESTAQUE, false, 1.0)
			elif hov:
				draw_rect(r.grow(1.0), DESTAQUE, false, 1.0)
		return

	# Celula do atlas: mostra o desenho de verdade, e nao um numero.
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
"escolha")

# Visto prominence
must_replace(
'''## O visto de aceite, no canto de cima da pagina — o mesmo lugar da referencia.
func _desenhar_visto() -> void:
	var pronto := _linha == campos_da_aba().size() + 1
	var caixa := _rect_visto()
	draw_rect(caixa, Color(0.88, 0.9, 0.82))
	draw_rect(caixa, DESTAQUE if pronto or _hover_visto else TINTA_FRACA, false,
		2.0 if _hover_visto else 1.0)
	var c := caixa.get_center()
	var cor := DESTAQUE if pronto else TINTA
	draw_line(c + Vector2(-5.0, 0.0), c + Vector2(-1.0, 4.0), cor, 2.0)
	draw_line(c + Vector2(-1.0, 4.0), c + Vector2(5.0, -5.0), cor, 2.0)
	if pronto:
		_texto(Vector2(PAGINA_DIR.end.x - 92.0, 40.0), "PRONTO", DESTAQUE)
''',
'''## O visto de aceite, no canto de cima da pagina — o mesmo lugar da referencia.
func _desenhar_visto() -> void:
	var pronto := _linha == campos_da_aba().size() + 1
	var caixa := _rect_visto()
	draw_rect(Rect2(caixa.position + Vector2(1.0, 2.0), caixa.size),
		Color(0.12, 0.10, 0.08, 0.35))
	var fill := Color(0.94, 0.92, 0.84)
	if pronto:
		var pulso := 0.04 + 0.04 * sin(_relogio * 3.2)
		fill = Color(0.96, 0.90 + pulso, 0.78)
	draw_rect(caixa, fill)
	var borda := DESTAQUE if pronto or _hover_visto else TINTA_FRACA
	draw_rect(caixa, borda, false, 2.0 if (pronto or _hover_visto) else 1.5)
	var c := caixa.get_center()
	var cor := DESTAQUE if pronto or _hover_visto else TINTA
	draw_line(c + Vector2(-6.0, 0.0), c + Vector2(-1.0, 5.0), cor, 2.4)
	draw_line(c + Vector2(-1.0, 5.0), c + Vector2(7.0, -6.0), cor, 2.4)
	if pronto or _hover_visto:
		_texto(Vector2(PAGINA_DIR.end.x - 98.0, 42.0), "PRONTO", DESTAQUE)
''',
"visto")

# Hit rects sync
must_replace(
'''func _rect_aba(i: int) -> Rect2:
	return Rect2(PAGINA_DIR.position.x + float(i) * 29.0, 68.0, 28.0, 19.0)


func _rect_visto() -> Rect2:
	return Rect2(PAGINA_DIR.end.x - 26.0, 26.0, 18.0, 18.0)


func _origem_campo(indice_campo: int) -> Vector2:
	return Vector2(PAGINA_DIR.position.x, 96.0 + float(indice_campo) * 38.0 + 12.0)
''',
'''func _rect_aba(i: int) -> Rect2:
	return Rect2(PAGINA_DIR.position.x + float(i) * 29.0, 68.0, 27.0, 20.0)


func _rect_visto() -> Rect2:
	return Rect2(PAGINA_DIR.end.x - 30.0, 24.0, 22.0, 22.0)


func _origem_campo(indice_campo: int) -> Vector2:
	return Vector2(PAGINA_DIR.position.x, 98.0 + float(indice_campo) * 40.0 + 12.0)
''',
"rects")

must_replace(
'''	if tipo == "lista":
		var itens: Array = campo["itens"]
		var passo := largura / float(itens.size())
		for k in itens.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 2.0, passo - 2.0, 15.0)
			if r.has_point(pos):
				return k
		return -1
	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var passo := largura / float(maxi(1, cores.size()))
		for k in cores.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 3.0,
				maxf(4.0, passo - 1.0), 13.0)
			if r.has_point(pos):
				return k
		return -1
	var quantos := int(campo["quantos"])
	var passo_cel := largura / float(quantos)
	for k in quantos:
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0, 18.0)
		if r.has_point(pos):
			return k
''',
'''	if tipo == "lista":
		var itens: Array = campo["itens"]
		var passo := largura / float(itens.size())
		for k in itens.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 2.0, passo - 2.0, 16.0)
			if r.has_point(pos):
				return k
		return -1
	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var passo := largura / float(maxi(1, cores.size()))
		for k in cores.size():
			var r := Rect2(em.x + float(k) * passo, em.y + 3.0,
				maxf(4.0, passo - 1.0), 14.0)
			if r.has_point(pos):
				return k
		return -1
	var quantos := int(campo["quantos"])
	var passo_cel := largura / float(quantos)
	for k in quantos:
		var r := Rect2(em.x + float(k) * passo_cel, em.y, passo_cel - 2.0, 20.0)
		if r.has_point(pos):
			return k
''',
"hit_sizes")

if text == orig:
    raise SystemExit("no changes")
path.write_text(text, encoding="utf-8")
print("DONE lines", len(text.splitlines()))

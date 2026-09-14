# -*- coding: utf-8 -*-
"""Incremental print02 polish + cabine SubViewport hook for criacao.gd."""
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
text = path.read_text(encoding="utf-8")
orig = text

# --- 1) Colors + paper toward passport cream / blue cover lip ---
old = '''const TINTA := Color("22301f")
const TINTA_FRACA := Color("5c6b52")
const PAPEL := Color("e3e9d6")
const VINCO := Color("b9c3aa")
const DESTAQUE := Color("8a2f1f")
'''
new = '''const TINTA := Color("22301f")
const TINTA_FRACA := Color("5c6b52")
const PAPEL := Color("ebe6d4")
const VINCO := Color("c4bba8")
const DESTAQUE := Color("8a2f1f")
## Borda/capa azul do passaporte (print02): filete sob o papel.
const CAPA := Color("2c4570")
const CELULA_SEL := Color("f4f1e6")
'''
if old not in text:
    raise SystemExit("colors block missing")
text = text.replace(old, new, 1)

# --- 2) State vars for live cabin SubViewport ---
old = '''## Fundo de cabine (capture) atras da carteira: evita o preto morto.
var _cabine: Texture2D
var _hover_aba: int = -1
var _hover_celula: int = -1
var _hover_visto: bool = false
'''
new = '''## Fundo de cabine: PackedScene live (SubViewport) ou Texture2D interim.
## Motorista entrega cabine_fundo_criacao.tscn; ate la cai no PNG.
const CABINE_CENA_CANDIDATAS: PackedStringArray = [
	"res://scenes/cabine_fundo_criacao.tscn",
	"res://scenes/ui/cabine_fundo_criacao.tscn",
	"res://scenes/estrada/cabine_fundo_criacao.tscn",
	"res://scenes/estrada_velha/cabine_fundo_criacao.tscn",
	"res://src/world/cabine_fundo_criacao.tscn",
	"res://assets/scenes/cabine_fundo_criacao.tscn",
	"res://cabine_fundo_criacao.tscn",
]
var _cabine: Texture2D
var _cabine_vp: SubViewport
var _cabine_live: bool = false
var _cabine_cena_path: String = ""
var _hover_aba: int = -1
var _hover_celula: int = -1
var _hover_visto: bool = false
'''
if old not in text:
    raise SystemExit("cabine state vars missing")
text = text.replace(old, new, 1)

# --- 3) Visibility: toggle BOTH viewports ---
old = '''## Liga o retrato so enquanto a carteira esta aberta. Ver _montar_retrato.
func _notification(o_que: int) -> void:
	if o_que != NOTIFICATION_VISIBILITY_CHANGED or _viewport == null:
		return
	_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
		if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)
'''
new = '''## Liga retrato + cabine live so enquanto a carteira esta aberta.
func _notification(o_que: int) -> void:
	if o_que != NOTIFICATION_VISIBILITY_CHANGED:
		return
	var ligado := is_visible_in_tree()
	var modo := (SubViewport.UPDATE_ALWAYS if ligado
		else SubViewport.UPDATE_DISABLED)
	if _viewport != null:
		_viewport.render_target_update_mode = modo
	if _cabine_vp != null:
		_cabine_vp.render_target_update_mode = modo
'''
if old not in text:
    raise SystemExit("notification block missing")
text = text.replace(old, new, 1)

# --- 4) _draw background: live VP or PNG + LOCAL/HORA mask only on PNG ---
old = '''func _draw() -> void:
	# Cabine / interior atras da carteira (capture), nao preto morto. Overlay
	# mais leve para o papel continuar em foco sem apagar o ambiente.
	if _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
		# Esconde LOCAL:/HORA: bakeados no PNG da cabine (canto inf-dir).
		draw_rect(Rect2(275.0, 205.0, 205.0, 55.0), Color(0.02, 0.03, 0.02, 0.98))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.42))
'''
new = '''func _draw() -> void:
	# Cabine atras da carteira: SubViewport live se a cena existir, senao PNG.
	# Veu leve mantem o papel em foco sem apagar o ambiente (print02).
	if _cabine_live and _cabine_vp != null:
		draw_texture_rect(_cabine_vp.get_texture(), Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.04, 0.18))
	elif _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
		# Esconde LOCAL:/HORA: bakeados no PNG da cabine (canto inf-dir).
		# Cena live nao traz HUD — mascara so no interim Texture2D.
		draw_rect(Rect2(275.0, 205.0, 205.0, 55.0), Color(0.02, 0.03, 0.02, 0.98))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.42))
'''
if old not in text:
    raise SystemExit("_draw cabine block missing")
text = text.replace(old, new, 1)

# --- 5) Paper: blue cover lip + cream fill (passport feel) ---
old = '''func _desenhar_papel() -> void:
	# Micro-balanco: documento vivo na mao, sem atrapalhar leitura.
	var osc := Vector2(sin(_relogio * 1.05) * 1.1, cos(_relogio * 0.85) * 0.9)
	var ang := INCLINACAO + sin(_relogio * 0.95) * 0.45
	draw_set_transform(DOC.position + osc + DOC.size * 0.5, deg_to_rad(ang),
		Vector2.ONE)
	var local := Rect2(-DOC.size * 0.5, DOC.size)
	draw_rect(Rect2(local.position + Vector2(3.0, 5.0), local.size),
		Color(0.02, 0.03, 0.02, 0.5))
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	draw_rect(local, TINTA_FRACA, false, 1.0)
	# Vinco do meio: e o que faz duas paginas em vez de um cartaz.
	draw_rect(Rect2(-1.0, local.position.y + 6.0, 2.0, local.size.y - 12.0), VINCO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
'''
new = '''func _desenhar_papel() -> void:
	# Micro-balanco: documento vivo na mao, sem atrapalhar leitura.
	var osc := Vector2(sin(_relogio * 1.05) * 1.1, cos(_relogio * 0.85) * 0.9)
	var ang := INCLINACAO + sin(_relogio * 0.95) * 0.45
	draw_set_transform(DOC.position + osc + DOC.size * 0.5, deg_to_rad(ang),
		Vector2.ONE)
	var local := Rect2(-DOC.size * 0.5, DOC.size)
	# Capa azul sob o papel (print02): filete inferior/laterais.
	draw_rect(Rect2(local.position + Vector2(-3.0, 4.0),
		Vector2(local.size.x + 6.0, local.size.y + 6.0)), CAPA)
	draw_rect(Rect2(local.position + Vector2(3.0, 5.0), local.size),
		Color(0.02, 0.03, 0.02, 0.5))
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	# Filete interno creme — affordance de pagina de passaporte.
	draw_rect(local.grow(-3.0), Color(0.92, 0.89, 0.80, 0.22), false, 1.0)
	draw_rect(local, TINTA_FRACA, false, 1.0)
	# Vinco do meio: e o que faz duas paginas em vez de um cartaz.
	draw_rect(Rect2(-1.0, local.position.y + 6.0, 2.0, local.size.y - 12.0), VINCO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
'''
if old not in text:
    raise SystemExit("papel block missing")
text = text.replace(old, new, 1)

# --- 6) Tabs: raised active, clearer inactive (print02 clickable feel) ---
old = '''func _desenhar_abas() -> void:
	for i in ABAS.size():
		var r := _rect_aba(i)
		var ativa := i == _aba
		var hover := i == _hover_aba
		draw_rect(r, Color(0.83, 0.86, 0.76) if ativa else Color(0.73, 0.77, 0.67))
		var borda := DESTAQUE if (ativa and _linha == LINHA_ABAS) or hover else TINTA_FRACA
		draw_rect(r, borda, false, 2.0 if hover else 1.0)
		_icone_da_aba(String(ABAS[i]["icone"]), r.get_center(),
			TINTA if ativa or hover else TINTA_FRACA)
'''
new = '''func _desenhar_abas() -> void:
	for i in ABAS.size():
		var r := _rect_aba(i)
		var ativa := i == _aba
		var hover := i == _hover_aba
		# Aba ativa sobe 2px (print02: tab raised). Hit-area fica no _rect_aba.
		var visual := r
		if ativa:
			visual = Rect2(r.position.x, r.position.y - 2.0, r.size.x, r.size.y + 2.0)
			draw_rect(Rect2(visual.position + Vector2(1.0, 2.0), visual.size),
				Color(0.15, 0.12, 0.08, 0.28))
		var fill := (Color(0.93, 0.90, 0.80) if ativa
			else (Color(0.82, 0.80, 0.70) if hover else Color(0.74, 0.72, 0.62)))
		draw_rect(visual, fill)
		var borda := CELULA_SEL if ativa else (DESTAQUE if hover else TINTA_FRACA)
		var esp := 2.0 if ativa or hover else 1.0
		draw_rect(visual, borda, false, esp)
		if ativa and _linha == LINHA_ABAS:
			draw_rect(visual, DESTAQUE, false, 1.0)
		_icone_da_aba(String(ABAS[i]["icone"]), visual.get_center(),
			TINTA if ativa or hover else TINTA_FRACA)
'''
if old not in text:
    raise SystemExit("abas block missing")
text = text.replace(old, new, 1)

# --- 7) Option cells: thicker selection ring + hover affordance ---
old = '''	if tipo == "lista":
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
'''
new = '''	if tipo == "lista":
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
'''
if old not in text:
    raise SystemExit("escolha cells block missing")
text = text.replace(old, new, 1)

# --- 8) Confirm check more prominent ---
old = '''## O visto de aceite, no canto de cima da pagina — o mesmo lugar da referencia.
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
'''
new = '''## O visto de aceite, no canto de cima da pagina — o mesmo lugar da referencia.
func _desenhar_visto() -> void:
	var pronto := _linha == campos_da_aba().size() + 1
	var caixa := _rect_visto()
	# Sombra + fill creme; pulso leve quando em foco (print02 check prominence).
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
'''
if old not in text:
    raise SystemExit("visto block missing")
text = text.replace(old, new, 1)

# --- 9) Larger visto hit + slightly roomier aba spacing ---
old = '''func _rect_aba(i: int) -> Rect2:
	return Rect2(PAGINA_DIR.position.x + float(i) * 29.0, 68.0, 28.0, 19.0)


func _rect_visto() -> Rect2:
	return Rect2(PAGINA_DIR.end.x - 26.0, 26.0, 18.0, 18.0)


func _origem_campo(indice_campo: int) -> Vector2:
	return Vector2(PAGINA_DIR.position.x, 96.0 + float(indice_campo) * 38.0 + 12.0)
'''
new = '''func _rect_aba(i: int) -> Rect2:
	# 1px de folga entre abas — grid clicavel mais legivel (print02).
	return Rect2(PAGINA_DIR.position.x + float(i) * 29.0, 68.0, 27.0, 20.0)


func _rect_visto() -> Rect2:
	return Rect2(PAGINA_DIR.end.x - 30.0, 24.0, 22.0, 22.0)


func _origem_campo(indice_campo: int) -> Vector2:
	# Mais ar entre abas e grade de opcoes.
	return Vector2(PAGINA_DIR.position.x, 98.0 + float(indice_campo) * 40.0 + 12.0)
'''
if old not in text:
    raise SystemExit("rect helpers missing")
text = text.replace(old, new, 1)

# Sync _desenhar_campos Y with _origem_campo
old = '''func _desenhar_campos() -> void:
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
'''
new = '''func _desenhar_campos() -> void:
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
'''
if old not in text:
    raise SystemExit("desenhar_campos missing")
text = text.replace(old, new, 1)

# Sync cell hit sizes with draw (lista/atlas heights)
old = '''	if tipo == "lista":
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
'''
new = '''	if tipo == "lista":
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
'''
if old not in text:
    raise SystemExit("indice_celula hit sizes missing")
text = text.replace(old, new, 1)

# --- 10) Replace _carregar_cabine with live VP hook + PNG fallback ---
old = '''func _carregar_cabine() -> void:
	# PNG via Image.load. Caminhos absolutos do repo + asset local.
	var candidatos: PackedStringArray = [
		"C:/Users/Administrator/Documents/Codes/Games/PSX/game/assets/ui/criacao_cabine.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_cabine_flag.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_01.png",
	]
	var raiz := ProjectSettings.globalize_path("res://")
	candidatos.append(raiz + "assets/ui/criacao_cabine.png")
	candidatos.append(raiz + "../captures/estrada_velha/cabine/fp_cabine_flag.png")
	for caminho: String in candidatos:
		var limpo := caminho.replace("\\\\", "/")
		while limpo.contains("/../"):
			# resolve um nivel: foo/bar/../x -> foo/x
			var i := limpo.find("/../")
			var esq := limpo.substr(0, i)
			var barra := esq.rfind("/")
			if barra < 0:
				break
			limpo = esq.substr(0, barra) + limpo.substr(i + 3)
		if not FileAccess.file_exists(limpo):
			continue
		var img := Image.new()
		if img.load(limpo) != OK:
			continue
		_cabine = ImageTexture.create_from_image(img)
		return
'''
# Note: in the file backslashes are single in the source as "\\"? Looking at the read output:
# "var limpo := caminho.replace("\\", "/")" - in the actual file it's `replace("\\", "/")` which is one backslash escaped in GDScript string.

old = '''func _carregar_cabine() -> void:
	# PNG via Image.load. Caminhos absolutos do repo + asset local.
	var candidatos: PackedStringArray = [
		"C:/Users/Administrator/Documents/Codes/Games/PSX/game/assets/ui/criacao_cabine.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_cabine_flag.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_01.png",
	]
	var raiz := ProjectSettings.globalize_path("res://")
	candidatos.append(raiz + "assets/ui/criacao_cabine.png")
	candidatos.append(raiz + "../captures/estrada_velha/cabine/fp_cabine_flag.png")
	for caminho: String in candidatos:
		var limpo := caminho.replace("\\", "/")
		while limpo.contains("/../"):
			# resolve um nivel: foo/bar/../x -> foo/x
			var i := limpo.find("/../")
			var esq := limpo.substr(0, i)
			var barra := esq.rfind("/")
			if barra < 0:
				break
			limpo = esq.substr(0, barra) + limpo.substr(i + 3)
		if not FileAccess.file_exists(limpo):
			continue
		var img := Image.new()
		if img.load(limpo) != OK:
			continue
		_cabine = ImageTexture.create_from_image(img)
		return
'''

new = '''func _carregar_cabine() -> void:
	# 1) PackedScene live (Motorista). 2) Texture2D interim + mascara LOCAL/HORA.
	if _tentar_cabine_live():
		return
	_carregar_cabine_png()


## Instancia cabine_fundo_criacao.tscn num SubViewport proprio.
## process_mode ALWAYS: o menu pausa a arvore em APARENCIA; a cabine precisa
## continuar o micro-idle. own_world_3d: sem nevoa/cidade atras do menu.
## UPDATE_ALWAYS so enquanto visivel — ver _notification.
func _tentar_cabine_live() -> bool:
	var path := _achar_cabine_cena()
	if path.is_empty():
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	_cabine_vp = SubViewport.new()
	_cabine_vp.name = "CabineFundo"
	_cabine_vp.size = Vector2i(int(TELA.x), int(TELA.y))
	_cabine_vp.own_world_3d = true
	_cabine_vp.transparent_bg = false
	_cabine_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_cabine_vp.msaa_3d = Viewport.MSAA_DISABLED
	_cabine_vp.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_cabine_vp)
	var cena := packed.instantiate()
	if cena == null:
		_cabine_vp.queue_free()
		_cabine_vp = null
		return false
	cena.process_mode = Node.PROCESS_MODE_ALWAYS
	_cabine_vp.add_child(cena)
	_cabine_live = true
	_cabine_cena_path = path
	print("[criacao] cabine live: %s" % path)
	return true


func _achar_cabine_cena() -> String:
	for path: String in CABINE_CENA_CANDIDATAS:
		if ResourceLoader.exists(path):
			return path
	# Busca rasa em res://scenes e res://src por se o arquivo mudar de pasta.
	for pasta: String in ["res://scenes", "res://src", "res://assets"]:
		var achado := _buscar_cena_cabine(pasta)
		if not achado.is_empty():
			return achado
	return ""


func _buscar_cena_cabine(pasta: String) -> String:
	var dir := DirAccess.open(pasta)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var nome := dir.get_next()
	while nome != "":
		if nome.begins_with("."):
			nome = dir.get_next()
			continue
		var full := pasta.path_join(nome)
		if dir.current_is_dir():
			var sub := _buscar_cena_cabine(full)
			if not sub.is_empty():
				dir.list_dir_end()
				return sub
		elif nome == "cabine_fundo_criacao.tscn":
			dir.list_dir_end()
			return full
		nome = dir.get_next()
	dir.list_dir_end()
	return ""


func _carregar_cabine_png() -> void:
	_cabine_live = false
	_cabine_cena_path = ""
	# Preferencia: asset importado; fallback Image.load em captures.
	if ResourceLoader.exists(UI % "criacao_cabine"):
		_cabine = load(UI % "criacao_cabine") as Texture2D
		if _cabine != null:
			return
	var candidatos: PackedStringArray = [
		"C:/Users/Administrator/Documents/Codes/Games/PSX/game/assets/ui/criacao_cabine.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_cabine_flag.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_01.png",
	]
	var raiz := ProjectSettings.globalize_path("res://")
	candidatos.append(raiz + "assets/ui/criacao_cabine.png")
	candidatos.append(raiz + "../captures/estrada_velha/cabine/fp_cabine_flag.png")
	for caminho: String in candidatos:
		var limpo := caminho.replace("\\", "/")
		while limpo.contains("/../"):
			var i := limpo.find("/../")
			var esq := limpo.substr(0, i)
			var barra := esq.rfind("/")
			if barra < 0:
				break
			limpo = esq.substr(0, barra) + limpo.substr(i + 3)
		if not FileAccess.file_exists(limpo):
			continue
		var img := Image.new()
		if img.load(limpo) != OK:
			continue
		_cabine = ImageTexture.create_from_image(img)
		return
'''

if old not in text:
    raise SystemExit("carregar_cabine block missing")
text = text.replace(old, new, 1)

# Footer hint: keep keyboard + click
old = '''	_texto(Vector2(0.0, 262.0),
		"[clique] abas/opcoes   [A/D] escolher   [W/S] campo   [E] ok   [ESC] voltar",
		Color(0.86, 0.83, 0.72), _fonte, HORIZONTAL_ALIGNMENT_CENTER, TELA.x)
'''
new = '''	_texto(Vector2(0.0, 262.0),
		"[clique] abas/opcoes   [A/D] escolher   [W/S] campo   [E] ok   [ESC] voltar",
		Color(0.88, 0.85, 0.74), _fonte, HORIZONTAL_ALIGNMENT_CENTER, TELA.x)
'''
if old not in text:
    raise SystemExit("footer hint missing")
text = text.replace(old, new, 1)

if text == orig:
    raise SystemExit("no changes applied")
path.write_text(text, encoding="utf-8")
print("patched ok, lines=", len(text.splitlines()))

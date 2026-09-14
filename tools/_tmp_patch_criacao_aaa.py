# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
text = path.read_text(encoding="utf-8")

# --- 1) Add state vars after BOTAO_CONFIRMAR ---
old_vars = """var _arrastando_chave: StringName = &\"\"
var _arrastando_campo: Dictionary = {}
const BOTAO_VOLTAR := Rect2(64.0, 252.0, 110.0, 15.0)
const BOTAO_CONFIRMAR := Rect2(306.0, 252.0, 110.0, 15.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_atlas = load(ATLAS) as Texture2D
"""

new_vars = """var _arrastando_chave: StringName = &\"\"
var _arrastando_campo: Dictionary = {}
const BOTAO_VOLTAR := Rect2(64.0, 252.0, 110.0, 15.0)
const BOTAO_CONFIRMAR := Rect2(306.0, 252.0, 110.0, 15.0)
## Fundo de cabine (capture) atras da carteira — evita o preto morto.
var _cabine: Texture2D
var _hover_aba: int = -1
var _hover_celula: int = -1
var _hover_visto: bool = false


func _ready() -> void:
	# Menu pausa a arvore nos paineis de papel; este Control precisa continuar
	# recebendo mouse e _process (balanco + hover) mesmo assim.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_carregar_cabine()
	_atlas = load(ATLAS) as Texture2D
"""

if old_vars not in text:
    raise SystemExit("anchor vars/_ready not found")
text = text.replace(old_vars, new_vars, 1)

# --- 2) Replace _draw overlay + footer ---
old_draw = """func _draw() -> void:
	# Escurece o mundo atras. O documento e uma coisa que se traz para perto do
	# rosto, e o que esta atras dele sai de foco.
	draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.68))

	_desenhar_papel()
	_desenhar_pagina_esquerda()
	_desenhar_pagina_direita()
	_desenhar_zona()
	# As maos por ULTIMO: os dedos passam por cima da borda de baixo do
	# documento, que e o que faz o papel parecer segurado em vez de colado na
	# tela. Desenhadas antes, elas sumiam inteiras atras dele.
	_desenhar_bracos()

	_texto(Vector2(0.0, 262.0),
		\"[A/D] escolher   [W/S] campo   [E] confirmar   [ESC] voltar\",
		Color(0.86, 0.83, 0.72), _fonte, HORIZONTAL_ALIGNMENT_CENTER, TELA.x)
"""

new_draw = """func _draw() -> void:
	# Cabine / interior atras da carteira (capture), nao preto morto. Overlay
	# mais leve para o papel continuar em foco sem apagar o ambiente.
	if _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false,
			Color(0.62, 0.64, 0.60, 1.0))
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.38))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.55))

	_desenhar_papel()
	_desenhar_pagina_esquerda()
	_desenhar_pagina_direita()
	_desenhar_zona()
	# As maos por ULTIMO: os dedos passam por cima da borda de baixo do
	# documento, que e o que faz o papel parecer segurado em vez de colado na
	# tela. Desenhadas antes, elas sumiam inteiras atras dele.
	_desenhar_bracos()

	_texto(Vector2(0.0, 262.0),
		\"[clique] abas/opcoes   [A/D] escolher   [W/S] campo   [E] ok   [ESC] voltar\",
		Color(0.86, 0.83, 0.72), _fonte, HORIZONTAL_ALIGNMENT_CENTER, TELA.x)
"""

if old_draw not in text:
    raise SystemExit("anchor _draw not found")
text = text.replace(old_draw, new_draw, 1)

# --- 3) Micro-motion on paper ---
old_papel = """func _desenhar_papel() -> void:
	draw_set_transform(DOC.position + DOC.size * 0.5, deg_to_rad(INCLINACAO),
		Vector2.ONE)
"""

new_papel = """func _desenhar_papel() -> void:
	# Micro-balanco: documento vivo na mao, sem atrapalhar leitura.
	var osc := Vector2(sin(_relogio * 1.05) * 1.1, cos(_relogio * 0.85) * 0.9)
	var ang := INCLINACAO + sin(_relogio * 0.95) * 0.45
	draw_set_transform(DOC.position + osc + DOC.size * 0.5, deg_to_rad(ang),
		Vector2.ONE)
"""

if old_papel not in text:
    raise SystemExit("anchor _desenhar_papel not found")
text = text.replace(old_papel, new_papel, 1)

# --- 4) Hands sway ---
old_bracos = """	for lado: float in [-1.0, 1.0]:
		# Geometria do antebraço e punho
		var base_x := TELA.x * 0.5 + lado * 154.0
		var punho_x := TELA.x * 0.5 + lado * 98.0
		var base := Vector2(base_x, TELA.y + 26.0)
		var punho := Vector2(punho_x, 218.0)
"""

new_bracos = """	var balanco := Vector2(sin(_relogio * 1.05) * 1.0, cos(_relogio * 0.85) * 0.7)
	for lado: float in [-1.0, 1.0]:
		# Geometria do antebraço e punho
		var base_x := TELA.x * 0.5 + lado * 154.0
		var punho_x := TELA.x * 0.5 + lado * 98.0
		var base := Vector2(base_x, TELA.y + 26.0) + balanco
		var punho := Vector2(punho_x, 218.0) + balanco
"""

if old_bracos not in text:
    raise SystemExit("anchor _desenhar_bracos not found")
text = text.replace(old_bracos, new_bracos, 1)

# --- 5) Tab hover highlight ---
old_abas = """func _desenhar_abas() -> void:
	var x := PAGINA_DIR.position.x
	var largura := 28.0
	for i in ABAS.size():
		var r := Rect2(x + float(i) * (largura + 1.0), 68.0, largura, 19.0)
		var ativa := i == _aba
		draw_rect(r, Color(0.83, 0.86, 0.76) if ativa else Color(0.73, 0.77, 0.67))
		draw_rect(r, DESTAQUE if (ativa and _linha == LINHA_ABAS) else TINTA_FRACA,
			false, 1.0)
		_icone_da_aba(String(ABAS[i][\"icone\"]), r.get_center(),
			TINTA if ativa else TINTA_FRACA)
"""

new_abas = """func _desenhar_abas() -> void:
	var x := PAGINA_DIR.position.x
	var largura := 28.0
	for i in ABAS.size():
		var r := _rect_aba(i)
		var ativa := i == _aba
		var hover := i == _hover_aba
		draw_rect(r, Color(0.83, 0.86, 0.76) if ativa else Color(0.73, 0.77, 0.67))
		var borda := DESTAQUE if (ativa and _linha == LINHA_ABAS) or hover else TINTA_FRACA
		draw_rect(r, borda, false, 2.0 if hover else 1.0)
		_icone_da_aba(String(ABAS[i][\"icone\"]), r.get_center(),
			TINTA if ativa or hover else TINTA_FRACA)
"""

if old_abas not in text:
    raise SystemExit("anchor _desenhar_abas not found")
text = text.replace(old_abas, new_abas, 1)

# --- 6) Visto hover ---
old_visto = """func _desenhar_visto() -> void:
	var pronto := _linha == campos_da_aba().size() + 1
	var caixa := Rect2(PAGINA_DIR.end.x - 26.0, 26.0, 18.0, 18.0)
	draw_rect(caixa, Color(0.88, 0.9, 0.82))
	draw_rect(caixa, DESTAQUE if pronto else TINTA_FRACA, false, 1.0)
"""

new_visto = """func _desenhar_visto() -> void:
	var pronto := _linha == campos_da_aba().size() + 1
	var caixa := _rect_visto()
	draw_rect(caixa, Color(0.88, 0.9, 0.82))
	draw_rect(caixa, DESTAQUE if pronto or _hover_visto else TINTA_FRACA, false,
		2.0 if _hover_visto else 1.0)
"""

if old_visto not in text:
    raise SystemExit("anchor _desenhar_visto not found")
text = text.replace(old_visto, new_visto, 1)

# --- 7) abrir() optional CLI aba ---
old_abrir = """func abrir() -> void:
	_ajustes = RegistroCivil.ajustes_do_jogador()
	_aba = 0
	_linha = LINHA_ABAS
	_refazer_corpo()
"""

new_abrir = """func abrir() -> void:
	_ajustes = RegistroCivil.ajustes_do_jogador()
	_aba = 0
	_linha = LINHA_ABAS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(\"--criacao-aba=\"):
			ir_para_aba(a.trim_prefix(\"--criacao-aba=\"))
	_refazer_corpo()
"""

if old_abrir not in text:
    raise SystemExit("anchor abrir not found")
text = text.replace(old_abrir, new_abrir, 1)

# --- 8) Append mouse + helpers before end (after navegar) ---
mouse_block = r'''

# --- mouse / hit-areas ------------------------------------------------------

## Converte coordenada local do Control para o espaco logico 480x270 (TELA).
## Com stretch viewport o size costuma ja ser TELA; a conta cobre letterbox/escala.
func _para_tela(local: Vector2) -> Vector2:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return local
	return Vector2(local.x * TELA.x / s.x, local.y * TELA.y / s.y)


func _rect_aba(i: int) -> Rect2:
	return Rect2(PAGINA_DIR.position.x + float(i) * 29.0, 68.0, 28.0, 19.0)


func _rect_visto() -> Rect2:
	return Rect2(PAGINA_DIR.end.x - 26.0, 26.0, 18.0, 18.0)


func _origem_campo(indice_campo: int) -> Vector2:
	return Vector2(PAGINA_DIR.position.x, 96.0 + float(indice_campo) * 38.0 + 12.0)


func _carregar_cabine() -> void:
	# Preferencia: asset importado. Fallback: PNG de aceite em captures/.
	const ASSET := "res://assets/ui/criacao_cabine.png"
	if ResourceLoader.exists(ASSET):
		_cabine = load(ASSET) as Texture2D
		return
	var raiz_jogo := ProjectSettings.globalize_path("res://").rstrip("/\\")
	var raiz_repo := raiz_jogo.get_base_dir()
	var candidatos: PackedStringArray = [
		raiz_repo.path_join("captures/estrada_velha/cabine/fp_cabine_flag.png"),
		raiz_repo.path_join("captures/estrada_velha/cabine/fp_01.png"),
		raiz_repo.path_join("captures/estrada_velha/cabine/fp_chao_03.png"),
	]
	for caminho: String in candidatos:
		if not FileAccess.file_exists(caminho):
			continue
		var img := Image.new()
		if img.load(caminho) != OK:
			continue
		_cabine = ImageTexture.create_from_image(img)
		return


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var pos := _para_tela(mb.position)
			if mb.pressed:
				if _clicar_em(pos):
					accept_event()
			else:
				if _arrastando_chave != &"":
					_arrastando_chave = &""
					_arrastando_campo = {}
					accept_event()
		return
	if evento is InputEventMouseMotion:
		var mm := evento as InputEventMouseMotion
		var pos := _para_tela(mm.position)
		if _arrastando_chave != &"" and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_arrastar_faixa(pos)
			accept_event()
		_atualizar_hover(pos)


func _atualizar_hover(pos: Vector2) -> void:
	var aba_antes := _hover_aba
	var cel_antes := _hover_celula
	var visto_antes := _hover_visto
	_hover_aba = -1
	_hover_celula = -1
	_hover_visto = _rect_visto().has_point(pos)
	for i in ABAS.size():
		if _rect_aba(i).has_point(pos):
			_hover_aba = i
			break
	if _hover_aba < 0 and not _hover_visto:
		for i in campos_da_aba().size():
			var campo := _campo(campos_da_aba()[i])
			var idx := _indice_celula_em(campo, _origem_campo(i), pos)
			if idx >= 0:
				_hover_celula = idx
				break
	if aba_antes != _hover_aba or cel_antes != _hover_celula or visto_antes != _hover_visto:
		queue_redraw()
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if _hover_aba >= 0 or _hover_celula >= 0 or _hover_visto
		else Control.CURSOR_ARROW)


func _clicar_em(pos: Vector2) -> bool:
	if _rect_visto().has_point(pos):
		_linha = campos_da_aba().size() + 1
		AudioDirector.tocar_ui(&"clique", -16.0)
		queue_redraw()
		confirmar()
		return true
	for i in ABAS.size():
		if _rect_aba(i).has_point(pos):
			_aba = i
			_linha = LINHA_ABAS
			AudioDirector.tocar_ui(&"clique", -20.0)
			queue_redraw()
			return true
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		if _aplicar_clique_campo(campo, _origem_campo(i), pos, i):
			return true
	return false


func _indice_celula_em(campo: Dictionary, em: Vector2, pos: Vector2) -> int:
	var chave: StringName = campo["chave"]
	var tipo := String(campo["tipo"])
	var largura := PAGINA_DIR.size.x - 12.0
	if tipo == "faixa":
		var barra := Rect2(em.x, em.y + 2.0, largura - 50.0, 14.0)
		return 0 if barra.has_point(pos) else -1
	if tipo == "lista":
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
	return -1


func _aplicar_clique_campo(campo: Dictionary, em: Vector2, pos: Vector2,
		indice_linha: int) -> bool:
	var chave: StringName = campo["chave"]
	var tipo := String(campo["tipo"])
	var largura := PAGINA_DIR.size.x - 12.0
	var idx := _indice_celula_em(campo, em, pos)
	if idx < 0:
		return false
	_linha = indice_linha + 1
	match tipo:
		"faixa":
			_arrastando_chave = chave
			_arrastando_campo = campo
			_arrastar_faixa(pos)
			AudioDirector.tocar_ui(&"clique", -18.0)
			return true
		"lista":
			_ajustes[chave] = idx
		"cor":
			var cores := Aparencia.paleta(String(campo["paleta"]))
			_ajustes[chave] = cores[idx]
		_:
			_ajustes[chave] = idx
	AudioDirector.tocar_ui(&"clique", -18.0)
	_refazer_corpo()
	queue_redraw()
	return true


func _arrastar_faixa(pos: Vector2) -> void:
	if _arrastando_chave == &"" or _arrastando_campo.is_empty():
		return
	var campo := _arrastando_campo
	var chave: StringName = _arrastando_chave
	var minimo := float(campo["minimo"])
	var maximo := float(campo["maximo"])
	# Descobre a origem Y pelo indice atual do campo na aba.
	var em := Vector2(PAGINA_DIR.position.x, 108.0)
	for i in campos_da_aba().size():
		if campos_da_aba()[i] == chave:
			em = _origem_campo(i)
			break
	var largura := PAGINA_DIR.size.x - 12.0
	var barra := Rect2(em.x, em.y + 6.0, largura - 50.0, 6.0)
	var t := clampf((pos.x - barra.position.x) / maxf(1.0, barra.size.x), 0.0, 1.0)
	_ajustes[chave] = lerpf(minimo, maximo, t)
	_refazer_corpo()
	queue_redraw()
'''

if "func _gui_input(evento: InputEvent) -> void:" in text:
    raise SystemExit("gui_input already present")
if not text.rstrip().endswith("queue_redraw()"):
    # navegar ends with queue_redraw()
    pass
text = text.rstrip() + "\n" + mouse_block
if not text.endswith("\n"):
    text += "\n"

path.write_text(text, encoding="utf-8")
print("OK patched", path)
print("lines", len(text.splitlines()))

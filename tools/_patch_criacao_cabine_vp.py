# -*- coding: utf-8 -*-
from pathlib import Path

p = Path("game/src/ui/criacao.gd")
t = p.read_text(encoding="utf-8")

old_vars = """## Fundo de cabine (capture) atras da carteira: evita o preto morto.
var _cabine: Texture2D
var _hover_aba: int = -1
"""
new_vars = """## Fundo de cabine atras da carteira: PackedScene 3D (preferido) ou PNG.
const CABINE_CENA := \"res://scenes/player/cabine_fundo_criacao.tscn\"
var _cabine: Texture2D
var _cabine_viewport: SubViewport
var _hover_aba: int = -1
"""
if old_vars not in t:
    raise SystemExit("vars block missing")
t = t.replace(old_vars, new_vars, 1)

old_notif = """## Liga o retrato so enquanto a carteira esta aberta. Ver _montar_retrato.
func _notification(o_que: int) -> void:
	if o_que != NOTIFICATION_VISIBILITY_CHANGED or _viewport == null:
		return
	_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
		if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)
"""
new_notif = """## Liga retrato e fundo de cabine so enquanto a carteira esta aberta.
func _notification(o_que: int) -> void:
	if o_que != NOTIFICATION_VISIBILITY_CHANGED:
		return
	var modo := (SubViewport.UPDATE_ALWAYS
		if is_visible_in_tree() else SubViewport.UPDATE_DISABLED)
	if _viewport != null:
		_viewport.render_target_update_mode = modo
	if _cabine_viewport != null:
		_cabine_viewport.render_target_update_mode = modo
"""
if old_notif not in t:
    raise SystemExit("notif block missing")
t = t.replace(old_notif, new_notif, 1)

old_draw = """	# Cabine / interior atras da carteira (capture), nao preto morto. Overlay
	# mais leve para o papel continuar em foco sem apagar o ambiente.
	if _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
		# Esconde LOCAL:/HORA: bakeados no PNG da cabine (canto inf-dir).
		draw_rect(Rect2(275.0, 205.0, 205.0, 55.0), Color(0.02, 0.03, 0.02, 0.98))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.42))
"""
new_draw = """	# Cabine / interior atras da carteira. Preferencia: SubViewport 3D vivo
	# (sem HUD/LOCAL/HORA). Fallback: PNG estatico + mascara do canto.
	if _cabine_viewport != null:
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
	elif _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
		# Esconde LOCAL:/HORA: bakeados no PNG da cabine (canto inf-dir).
		draw_rect(Rect2(275.0, 205.0, 205.0, 55.0), Color(0.02, 0.03, 0.02, 0.98))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.42))
"""
if old_draw not in t:
    raise SystemExit("draw block missing")
t = t.replace(old_draw, new_draw, 1)

old_load = """func _carregar_cabine() -> void:
	# PNG via Image.load. Caminhos absolutos do repo + asset local.
	var candidatos: PackedStringArray = [
		\"C:/Users/Administrator/Documents/Codes/Games/PSX/game/assets/ui/criacao_cabine.png\",
		\"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_cabine_flag.png\",
		\"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_01.png\",
	]
	var raiz := ProjectSettings.globalize_path(\"res://\")
	candidatos.append(raiz + \"assets/ui/criacao_cabine.png\")
	candidatos.append(raiz + \"../captures/estrada_velha/cabine/fp_cabine_flag.png\")
	for caminho: String in candidatos:
		var limpo := caminho.replace(\"\\\\\", \"/\")
		while limpo.contains(\"/../\"):
			# resolve um nivel: foo/bar/../x -> foo/x
			var i := limpo.find(\"/../\")
			var esq := limpo.substr(0, i)
			var barra := esq.rfind(\"/\")
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
"""

new_load = """func _carregar_cabine() -> void:
	# Preferencia: PackedScene 3D (piloto FP). Fallback: PNG estatico.
	if ResourceLoader.exists(CABINE_CENA):
		var packed := load(CABINE_CENA) as PackedScene
		if packed != null:
			_cabine_viewport = SubViewport.new()
			_cabine_viewport.name = \"CabineFundo\"
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
		\"C:/Users/Administrator/Documents/Codes/Games/PSX/game/assets/ui/criacao_cabine.png\",
		\"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_cabine_flag.png\",
		\"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_01.png\",
	]
	var raiz := ProjectSettings.globalize_path(\"res://\")
	candidatos.append(raiz + \"assets/ui/criacao_cabine.png\")
	candidatos.append(raiz + \"../captures/estrada_velha/cabine/fp_cabine_flag.png\")
	for caminho: String in candidatos:
		var limpo := caminho.replace(\"\\\\\", \"/\")
		while limpo.contains(\"/../\"):
			# resolve um nivel: foo/bar/../x -> foo/x
			var i := limpo.find(\"/../\")
			var esq := limpo.substr(0, i)
			var barra := esq.rfind(\"/\")
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
"""

if old_load not in t:
    # show nearby for debug
    i = t.find("func _carregar_cabine")
    print(repr(t[i:i+400]))
    raise SystemExit("load block missing")
t = t.replace(old_load, new_load, 1)

p.write_text(t, encoding="utf-8")
print("criacao.gd patched")

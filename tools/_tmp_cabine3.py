from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
t = p.read_text(encoding="utf-8")
start = t.find("func _carregar_cabine()")
end = t.find("func _gui_input")
new = r'''func _carregar_cabine() -> void:
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
# Fix replace backslash in GDScript: write via chr to avoid escape hell in source
# Actually in the string above I used .replace("\\", "/") which in a raw python
# string r'''...''' becomes .replace("\\", "/") in file = GDScript one backslash. Good.
t = t[:start] + new + t[end:]
# Brighten cabin draw
t = t.replace(
'''	if _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false,
			Color(0.62, 0.64, 0.60, 1.0))
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.38))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.55))
''',
'''	if _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false,
			Color(0.85, 0.86, 0.82, 1.0))
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.28))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.45))
''')
p.write_text(t, encoding="utf-8")
print("updated cabine + draw")
# verify GDScript replace line
for line in t.splitlines():
    if 'replace(' in line and 'limpo' in line:
        print(repr(line))

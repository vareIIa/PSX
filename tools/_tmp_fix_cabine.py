from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
t = p.read_text(encoding="utf-8")
old = '''func _carregar_cabine() -> void:
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
'''
new = '''func _carregar_cabine() -> void:
	# Carrega PNG via Image (sem depender de .import). Asset local e captures/.
	var raiz_jogo := ProjectSettings.globalize_path("res://").rstrip("/\\")
	var raiz_repo := raiz_jogo.get_base_dir()
	var candidatos: PackedStringArray = [
		raiz_jogo.path_join("assets/ui/criacao_cabine.png"),
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
'''
if old not in t:
    raise SystemExit('carregar block not found')
p.write_text(t.replace(old, new, 1), encoding='utf-8')
print('carregar fixed')

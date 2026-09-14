from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
t = p.read_text(encoding="utf-8")
start = t.find("func _carregar_cabine()")
end = t.find("func _gui_input")
if start < 0 or end < 0:
    raise SystemExit(f"markers {start} {end}")
new = '''func _carregar_cabine() -> void:
	# PNG via Image.load (sem .import). Asset local e captures/estrada_velha/cabine/.
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
t = t[:start] + new + t[end:]
p.write_text(t, encoding="utf-8")
print("cabine loader replaced")

# Minimal compile unblock in abertura (other-agent dirt). Not _plano_da_praca.
a = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
at = a.read_text(encoding="utf-8")
old = "\tfor lado in [-1.0, 1.0]:\n\t\tvar x := 0.11 * lado\n"
newa = "\tfor lado: float in [-1.0, 1.0]:\n\t\tvar x := 0.11 * lado\n"
if old not in at:
    idx = at.find("for lado in [-1.0, 1.0]:")
    print("abertura idx", idx, repr(at[idx:idx+60]))
else:
    a.write_text(at.replace(old, newa, 1), encoding="utf-8")
    print("abertura infer fixed")

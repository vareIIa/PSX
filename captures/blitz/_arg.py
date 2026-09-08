from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
t = p.read_text(encoding="utf-8")
old = '''	# Captura da blitz: semeia, espera nascer, teleporta a camera para o funil.
	if OS.get_cmdline_user_args().has("--olhar-blitz"):
		await _olhar_blitz()'''
new = '''	# Captura da blitz: semeia, espera nascer, teleporta a camera para o funil.
	var _quer_blitz := false
	for _a: String in OS.get_cmdline_user_args():
		if _a == "--olhar-blitz" or _a.begins_with("--olhar-blitz="):
			_quer_blitz = true
			break
	if _quer_blitz:
		await _olhar_blitz()'''
if old not in t:
    raise SystemExit("check block missing")
t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("arg check fixed")

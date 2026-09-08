from pathlib import Path

# Fix Blitz.efeito to include blitz ref
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\blitz.gd")
t = p.read_text(encoding="utf-8")
old = '''	var out := {
		"parar": parar,
		"teto": float(info["teto"]),
		"faixa": faixa,
		"eixo": b.trecho.z,
		"mira": info["mira"],
		"fase": -1,
		"ocultar_motorista": false,
	}'''
new = '''	var out := {
		"blitz": b,
		"parar": parar,
		"teto": float(info["teto"]),
		"faixa": faixa,
		"eixo": b.trecho.z,
		"mira": info["mira"],
		"fase": -1,
		"ocultar_motorista": false,
	}'''
if old not in t:
    raise SystemExit("efeito out missing")
t = t.replace(old, new, 1)

# Fix velocity check - Carro has _velocidade; use safer access
t = t.replace(
    "if absf(carro.get(\"_velocidade\")) > 0.55:",
    "if absf(float(carro.get(\"_velocidade\"))) > 0.55:",
)
p.write_text(t, encoding="utf-8")
print("blitz efeito ok")

# Ensure ocultar helper exists
cp = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\carro.gd")
ct = cp.read_text(encoding="utf-8")
print("has ocultar", "_ocultar_motorista_visual" in ct)
print("has blitz_parado", "blitz_parado" in ct)

# Add --olhar-blitz to cidade.gd after --ir-para block
cid = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
c = cid.read_text(encoding="utf-8")
if "--olhar-blitz" not in c:
    marker = '''	# Vista de cima, so para inspecao.'''
    insert = '''	# Captura da blitz: semeia, espera nascer, teleporta a camera para o funil.
	if OS.get_cmdline_user_args().has("--olhar-blitz"):
		await _olhar_blitz()

	# Vista de cima, so para inspecao.'''
    if marker not in c:
        raise SystemExit("cidade marker missing")
    c = c.replace(marker, insert, 1)
    # Add the function near other helpers - before _camera_de_cima or at end before last funcs
    fn = '''
## Semeia uma blitz e teleporta o jogador para enquadra-la (capturas AAA).
func _olhar_blitz() -> void:
	BlitzManager.semear()
	var t0 := float(Time.get_ticks_msec()) / 1000.0
	var qual: Blitz = null
	while qual == null:
		var vivas := BlitzManager.lista()
		if not vivas.is_empty():
			qual = vivas[0]
			break
		if float(Time.get_ticks_msec()) / 1000.0 - t0 > 5.0:
			push_warning("[cidade] --olhar-blitz: nenhuma blitz nasceu")
			return
		await get_tree().process_frame
	# Espera chunks/carros estabilizarem um pouco.
	await get_tree().create_timer(0.6).timeout
	var alvo := qual.ponto_de_parada()
	# Camera no acostamento olhando o funil.
	var de := alvo + qual.global_transform.basis * Vector3(6.5, 4.2, 4.0)
	_player.global_position = de
	if _player.has_method("olhar_para"):
		_player.call("olhar_para", alvo + Vector3.UP * 0.8)
	print("[cidade] blitz em %.1f,%.1f,%.1f" % [alvo.x, alvo.y, alvo.z])


'''
    if "func _camera_de_cima" in c:
        c = c.replace("func _camera_de_cima", fn + "func _camera_de_cima", 1)
    else:
        c += "\n" + fn
    cid.write_text(c, encoding="utf-8")
    print("cidade --olhar-blitz ok")
else:
    print("cidade already has olhar-blitz")

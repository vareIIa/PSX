from pathlib import Path

# Force avenida always
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\blitz_manager.gd")
t = p.read_text(encoding="utf-8")
old = """	# Prefere avenida (acostamento largo). Em semear aceita rua se nao houver.
	var via := (MalhaUrbana.via_x(de.x) if tr.z == 0 else MalhaUrbana.via_z(de.y))
	if via != MalhaUrbana.Via.AVENIDA and not _semear:
		return false
	if via == MalhaUrbana.Via.VIELA:
		return false"""
new = """	# So avenida: acostamento largo e faixa interna para desvio limpo.
	var via := (MalhaUrbana.via_x(de.x) if tr.z == 0 else MalhaUrbana.via_z(de.y))
	if via != MalhaUrbana.Via.AVENIDA:
		return false"""
if old not in t:
    raise SystemExit("candidato avenida block missing")
t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("avenida only")

# Better camera for --olhar-blitz
cid = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
c = cid.read_text(encoding="utf-8")
old_f = """## Semeia uma blitz e teleporta o jogador para enquadra-la (capturas AAA).
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
	print("[cidade] blitz em %.1f,%.1f,%.1f" % [alvo.x, alvo.y, alvo.z])"""

new_f = """## Semeia uma blitz e teleporta o jogador para enquadra-la (capturas AAA).
##
## Args opcionais:
##   --olhar-blitz=perto|funil|cima|desvio|insp  (padrao: perto)
func _olhar_blitz() -> void:
	BlitzManager.semear()
	var t0 := float(Time.get_ticks_msec()) / 1000.0
	var qual: Blitz = null
	while qual == null:
		var vivas := BlitzManager.lista()
		if not vivas.is_empty():
			qual = vivas[0]
			break
		if float(Time.get_ticks_msec()) / 1000.0 - t0 > 6.0:
			push_warning("[cidade] --olhar-blitz: nenhuma blitz nasceu")
			return
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	var modo := "perto"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--olhar-blitz=") and arg.length() > 13:
			modo = arg.trim_prefix("--olhar-blitz=")
	var alvo := qual.ponto_de_parada()
	var b := qual.global_transform.basis
	var cam := alvo
	var olhar := alvo + Vector3.UP * 1.0
	match modo:
		"funil":
			# Olha o funil de cones de frente (vindo do fluxo).
			cam = alvo + b * Vector3(1.5, 2.4, 12.0)
			olhar = alvo + b * Vector3(0.0, 0.6, -2.0)
		"cima":
			cam = alvo + Vector3(0.0, 22.0, 0.0) + b * Vector3(2.0, 0.0, 2.0)
			olhar = alvo
		"desvio":
			cam = alvo + b * Vector3(-5.0, 3.0, 6.0)
			olhar = alvo + b * Vector3(-2.0, 0.5, 0.0)
		"insp":
			cam = alvo + b * Vector3(4.5, 2.2, 3.0)
			olhar = alvo + b * Vector3(0.8, 1.0, 0.0)
		_:
			# Perto: viatura + acostamento + zebrado.
			cam = alvo + b * Vector3(5.5, 2.8, 5.5)
			olhar = alvo + b * Vector3(1.2, 0.5, -1.0)
	_player.global_position = Vector3(cam.x, maxf(cam.y, 1.2), cam.z)
	if _player.has_method("olhar_para"):
		_player.call("olhar_para", olhar)
	print("[cidade] blitz modo=%s em %.1f,%.1f,%.1f cam=%.1f,%.1f,%.1f"
		% [modo, alvo.x, alvo.y, alvo.z, cam.x, cam.y, cam.z])"""

if old_f not in c:
    raise SystemExit("olhar_blitz func missing for replace")
c = c.replace(old_f, new_f, 1)
# Also allow --olhar-blitz= in titulo skip (begins_with shot already; add begins_with olhar-blitz)
old_skip = '''		if a in ["--pular-menu", "--ver-abertura", "--olhar-blitz"]:
			return false'''
new_skip = '''		if a in ["--pular-menu", "--ver-abertura", "--olhar-blitz"] or a.begins_with("--olhar-blitz="):
			return false'''
if old_skip in c:
    c = c.replace(old_skip, new_skip, 1)
cid.write_text(c, encoding="utf-8")
print("camera modes ok")

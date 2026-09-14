# -*- coding: utf-8 -*-
"""Reaplica FP acordar completo no abertura.gd atual (pos-reset)."""
from pathlib import Path

p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
# backup
bak = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\captures\praca_matriz\cine\_abertura_before_fp_reapply.gd")
bak.parent.mkdir(parents=True, exist_ok=True)
bak.write_text(t, encoding="utf-8")

# --- 1) consts: replace ACORDA block between markers ---
c0 = t.find("# --- plano da praca ---------------------------------------------------------")
c1 = t.find("## Ate onde procurar o parque, em chunks.")
if c0 < 0 or c1 < 0:
    raise SystemExit(f"const markers {c0} {c1}")
new_consts = """# --- plano da praca ---------------------------------------------------------
## Acordar FP Praça da Matriz (ref 01). Cinema AAA PSX STYLE.
const PRACA_ALTURA := Vector2(4.6, 3.2)
const PRACA_FRENTE := Vector2(3.0, 10.0)
const PRACA_OLHAR := Vector2(19.0, 21.0)
const PRACA_FOV := Vector2(64.0, 58.0)
const PRACA_DURACAO := 15.5
const ACORDA_ALTURA := Vector2(0.16, 1.62)
const ACORDA_CABECA := 1.28
const ACORDA_OLHAR_ALTURA := Vector2(0.03, 1.40)
const ACORDA_OLHAR_PERTO := 0.20
const ACORDA_OLHAR_LONGE := 18.0
const ACORDA_LADO := 1.95
const DEITADO_GIRO := 0.7
const DEITADO_ALTURA := 0.18
const ACORDA_FOV := Vector2(72.0, 58.0)
const ACORDA_DURACAO := 9.0
const ACORDA_ANTES := 3.4
const ACORDA_SUBIDA := 2.2

"""
# keep PRACA_* if already in section — new_consts includes them
# Strip old section carefully: from c0 to c1 may include PRACA_* already
t = t[:c0] + new_consts + t[c1:]

# --- 2) PRACA_RAIO ---
t = t.replace("const PRACA_RAIO := 6", "const PRACA_RAIO := 14", 1)

# --- 3) spawn pin after var origem ---
old_o = "\tvar origem := _nasceu_em\n\tfor _k in ESPERA_CHAO:"
if old_o not in t:
    raise SystemExit("origem loop missing")
new_o = """\tvar origem := _nasceu_em
\t# Pin Cleiton cluster Matriz ~272,-48. Sul no anel de lampioes.
\tconst PIN_MATRIZ := Vector3(272.0, 0.0, -48.0)
\tvar matriz := _praca_mais_perto(PIN_MATRIZ)
\tif matriz == Vector3.INF:
\t\tmatriz = PIN_MATRIZ
\torigem = Vector3(matriz.x - 5.0, origem.y, matriz.z + 13.0)
\t_jogador.global_position = origem + Vector3.UP * 0.5
\tvar para_m := Vector3(matriz.x - origem.x, 0.0, (matriz.z - 6.0) - origem.z)
\tif para_m.length_squared() > 0.01:
\t\t_jogador.rotation.y = atan2(-para_m.x, -para_m.z)
\t_jogador.zerar_velocidade()
\t_nasceu_em = origem
\tfor _k in 90:
\t\tawait get_tree().physics_frame
\tfor _k in ESPERA_CHAO:"""
t = t.replace(old_o, new_o, 1)

# --- 4) LIVRE + mostrar corpo ---
old_d = """\t\tfigura.postura(Corpo.Postura.ENCOSTADO)
\t\t_montar_maos(figura)
\t\t_deitar(figura, true)"""
new_d = """\t\tfigura.postura(Corpo.Postura.LIVRE)
\t\t_montar_maos(figura)
\t\t_deitar(figura, true)
\t\t_jogador.mostrar_corpo(true)"""
if old_d not in t:
    raise SystemExit("deitar block missing")
t = t.replace(old_d, new_d, 1)

# --- 5) replace entire _plano_da_praca ---
p0 = t.find("## De cima, na direcao do parque em que ele acordou.")
if p0 < 0:
    p0 = t.find("func _plano_da_praca(pose: Dictionary) -> void:")
    # back up to prior ##
    p0 = t.rfind("\n## ", 0, p0) + 1
p1 = t.find("## Ha vista livre entre estes dois pontos?")
if p0 < 0 or p1 < 0:
    raise SystemExit(f"plano markers {p0} {p1}")

new_plano = r'''## Acordar FP no chao da praca (ref 01) — calca+bota, camera sobe com ele.
##
## E o primeiro plano do jogo. Nao quebra a emenda Estrada→Abertura (Bob).
func _ponto_osso(figura: Corpo, osso: int) -> Vector3:
	var sk := figura.esqueleto()
	if sk == null:
		return figura.global_position
	return (sk.global_transform * sk.get_bone_global_pose(osso)).origin


func _plano_da_praca(pose: Dictionary) -> void:
	var onde: Vector3 = pose["onde"]
	var eixo: Vector3 = pose["eixo"]
	var figura := _jogador.figura()

	var praca := _praca_mais_perto(onde)
	if praca == Vector3.INF:
		praca = Vector3(272.0, 0.0, -48.0)
	var frente_praca := Vector3(praca.x - onde.x, 0.0, (praca.z - 5.0) - onde.z)
	if frente_praca.length_squared() < 0.01:
		frente_praca = -eixo if eixo.length_squared() > 0.01 else Vector3(0.0, 0.0, -1.0)
	frente_praca = frente_praca.normalized()

	var cam_de: Vector3
	var olhar_de: Vector3
	if figura != null:
		var p_cabeca := _ponto_osso(figura, Corpo.Osso.CABECA)
		var p_pes := (
			_ponto_osso(figura, Corpo.Osso.CANELA_E)
			+ _ponto_osso(figura, Corpo.Osso.CANELA_D)) * 0.5
		cam_de = p_cabeca - frente_praca * 0.55 + Vector3.UP * 0.22
		olhar_de = p_pes + frente_praca * 0.55 + Vector3.UP * 0.04
	else:
		cam_de = onde + eixo * ACORDA_CABECA + Vector3.UP * ACORDA_ALTURA.x
		olhar_de = onde - eixo * 0.2 + Vector3.UP * 0.05

	var cam_ate := onde + Vector3.UP * ACORDA_ALTURA.y
	var olhar_ate := onde + frente_praca * ACORDA_OLHAR_LONGE + Vector3.UP * ACORDA_OLHAR_ALTURA.y

	var t0 := Time.get_ticks_msec()
	Cinema.mover(
		cam_de, cam_ate, olhar_de, olhar_ate,
		ACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

	# Lampiao quente a esquerda (ref 01) — reforca o apoio na nevoa densa.
	if _apoio != null and is_instance_valid(_apoio):
		var lado_luz := frente_praca.cross(Vector3.UP).normalized()
		_apoio.global_position = (
			onde - lado_luz * 2.8 + Vector3.UP * 3.4 + frente_praca * 0.5)
		_apoio.light_color = Color("ffb45a")
		_apoio.light_energy = 5.5
		_apoio.omni_range = 9.0

	if _hud != null:
		_hud.visible = true
	await Cinema.clarear(2.2)
	Cinema.legenda(FALAS["acorda"], 2.2)
	await _capturar_plano("01_acordar_chao")
	await get_tree().create_timer(ACORDA_ANTES).timeout

	if figura != null:
		_levantar(figura, ACORDA_SUBIDA)
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	var falta := maxf(0.0, maxf(ACORDA_DURACAO - elapsed, ACORDA_SUBIDA))
	await get_tree().create_timer(falta).timeout

	await _capturar_plano("01_acordar_pe")
	for chave: String in ["praca_1", "praca_2", "praca_3", "praca_4", "praca_5"]:
		Cinema.legenda(FALAS[chave], 3.6)
		await get_tree().create_timer(3.9).timeout
	if _hud != null:
		_hud.visible = false


'''
t = t[:p0] + new_plano + t[p1:]

# --- 6) _praca_mais_perto → Traco.PRACA only ---
old_fn = """static func _praca_mais_perto(de: Vector3) -> Vector3:
\tvar aqui := Vector2i(floori(de.x / Mapa.TAM), floori(de.z / Mapa.TAM))
\tvar melhor := Vector3.INF
\tvar melhor_d := INF
\tfor cz in range(aqui.y - PRACA_RAIO, aqui.y + PRACA_RAIO + 1):
\t\tfor cx in range(aqui.x - PRACA_RAIO, aqui.x + PRACA_RAIO + 1):
\t\t\tvar q := MalhaUrbana.quadra_de(cx, cz)
\t\t\tif int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
\t\t\t\tcontinue
\t\t\tvar c: Vector3 = MalhaUrbana.centro_da_quadra(q)
\t\t\tvar d := Vector2(c.x - de.x, c.z - de.z).length()
\t\t\tif d < melhor_d:
\t\t\t\tmelhor_d = d
\t\t\t\tmelhor = c
\treturn melhor"""

new_fn = """static func _praca_mais_perto(de: Vector3) -> Vector3:
\tvar aqui := Vector2i(floori(de.x / Mapa.TAM), floori(de.z / Mapa.TAM))
\tvar melhor := Vector3.INF
\tvar melhor_d := INF
\tfor cz in range(aqui.y - PRACA_RAIO, aqui.y + PRACA_RAIO + 1):
\t\tfor cx in range(aqui.x - PRACA_RAIO, aqui.x + PRACA_RAIO + 1):
\t\t\tvar q := MalhaUrbana.quadra_de(cx, cz)
\t\t\tif int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
\t\t\t\tcontinue
\t\t\tvar plano := ParqueBuilder.planta(q)
\t\t\tif int(plano["traco"]) != ParqueBuilder.Traco.PRACA:
\t\t\t\tcontinue
\t\t\tvar local: Vector2 = plano["centro"]
\t\t\tvar c := Vector3(
\t\t\t\tfloat(q["x0"]) * Mapa.TAM + local.x,
\t\t\t\t0.0,
\t\t\t\tfloat(q["z0"]) * Mapa.TAM + local.y)
\t\t\tvar d := Vector2(c.x - de.x, c.z - de.z).length()
\t\t\tif d < melhor_d:
\t\t\t\tmelhor_d = d
\t\t\t\tmelhor = c
\treturn melhor"""
if old_fn not in t:
    raise SystemExit("praca_mais_perto missing")
t = t.replace(old_fn, new_fn, 1)

# --- 7) capture dual path + ver-praca gate ---
old_cap = """func _capturar_plano(nome: String) -> void:
\tif not OS.get_cmdline_user_args().has(\"--ver-abertura\"):
\t\treturn"""
old_cap = old_cap.replace('\\"', '"')
if old_cap in t:
    t = t.replace(old_cap, """func _capturar_plano(nome: String) -> void:
\tvar args := OS.get_cmdline_user_args()
\tif not (args.has(\"--ver-abertura\") or args.has(\"--ver-praca\")):
\t\treturn""".replace('\\"', '"'), 1)

needle = '\tprint("[abertura] captura %s (%dx%d)" % [abs_path, image.get_width(), image.get_height()])'
if "praca_matriz" not in t.split("func _capturar_plano")[1][:800]:
    extra = needle + """
\tif nome.begins_with("01_acordar") or nome.begins_with("praca_"):
\t\tvar game_dir := ProjectSettings.globalize_path("res://").rstrip("/\\\\")
\t\tvar cine_dir := game_dir.path_join("..").path_join("captures").path_join("praca_matriz").path_join("cine")
\t\tDirAccess.make_dir_recursive_absolute(cine_dir)
\t\tvar cine := cine_dir.path_join("%s.png" % nome)
\t\tvar err2 := image.save_png(cine)
\t\tif err2 == OK:
\t\t\tprint("[abertura] cine %s" % cine)"""
    if needle not in t:
        raise SystemExit("capture print missing")
    t = t.replace(needle, extra, 1)

# --- 8) ensure early quit after praca for --ver-praca ---
if "praca capturada - encerrando" not in t:
    old_e = "\tawait _plano_da_praca(pose)\n\tawait _plano_da_avenida(pose)"
    new_e = """\tawait _plano_da_praca(pose)
\tif OS.get_cmdline_user_args().has("--ver-praca"):
\t\tprint("[abertura] praca capturada - encerrando")
\t\tawait get_tree().create_timer(0.35).timeout
\t\tget_tree().quit()
\t\treturn
\tawait _plano_da_avenida(pose)"""
    if old_e not in t:
        raise SystemExit("executar hook missing")
    t = t.replace(old_e, new_e, 1)

p.write_text(t, encoding="utf-8")
# also save recovered version
Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\captures\praca_matriz\cine\_abertura_fp_reapplied.gd").write_text(t, encoding="utf-8")
print("OK full reapply")
print("PIN", "PIN_MATRIZ" in t)
print("ponto_osso", "_ponto_osso" in t)
print("01_acordar", "01_acordar_chao" in t)

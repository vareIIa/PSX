from pathlib import Path
src = Path(r"game/src/levels/abertura_estrada.gd")
t = src.read_text(encoding="utf-8")

# 1) climates after PRESET
needle = 'const PRESET := "res://resources/fog/fog_estrada.tres"\n'
insert = needle + '''## Climas da Estrada Velha (refs). `--estrada-clima=` escolhe.
const CLIMAS_ESTRADA := {
	"entardecer": "res://resources/fog/fog_estrada.tres",
	"noite": "res://resources/fog/fog_estrada_noite.tres",
	"amanhecer": "res://resources/fog/fog_estrada_amanhecer.tres",
	"dia": "res://resources/fog/fog_estrada_dia.tres",
}

'''
if "CLIMAS_ESTRADA" not in t:
    if needle not in t: raise SystemExit("PRESET missing")
    t = t.replace(needle, insert, 1)

t = t.replace(
    "enum Plano { NENHUM, PASSAGEM, AEREA, RASANTE, DENTRO, SAIDA }",
    "enum Plano { NENHUM, PASSAGEM, AEREA, RASANTE, DENTRO, SAIDA, CHASE }",
    1,
)

needle = "var _far_anterior: float = 600.0\n"
insert = needle + '''## Modo jogavel (TASK AAA): WASD + V 1P/3P. Cutscene continua o default.
var _jogavel: bool = false
## True = chase 3P; false = cabine 1P (default).
var _terceira: bool = false

'''
if "_jogavel" not in t:
    if needle not in t: raise SystemExit("far_anterior missing")
    t = t.replace(needle, insert, 1)

# 2) early branches in executar
old = '''	_cam.near = 0.08
	set_process(true)

	await _plano_passagem()
'''
new = '''	_cam.near = 0.08
	set_process(true)

	if _quer_jogavel():
		await _correr_jogavel()
		_desmontar()
		terminou.emit()
		queue_free()
		return

	var plano_cap := _plano_captura()
	if plano_cap != Plano.NENHUM:
		await _segurar_captura(plano_cap)
		_desmontar()
		terminou.emit()
		queue_free()
		return

	await _plano_passagem()
'''
if "_quer_jogavel" not in t:
    if old not in t: raise SystemExit("executar near missing")
    t = t.replace(old, new, 1)

# 3) fog force + farois + clima on estrada
old = '''	if _fog != null:
		_fog.forcar(PRESET)
'''
new = '''	if _fog != null:
		_fog.forcar(_caminho_clima())
	_ligar_farois_se_noite()
	if _estrada != null:
		_estrada.clima_id = _clima_id()
'''
if "_caminho_clima" not in t.split("func _montar_mundo")[1][:800]:
    if old not in t: raise SystemExit("fog forcar missing")
    t = t.replace(old, new, 1)

# 4) CHASE in camera match — before `_:`
old = '''		Plano.SAIDA:
			var p := EstradaBuilder.ponto_em(_ancora)
			var l := EstradaBuilder.lado_em(_ancora)
			_enquadrar(p + l * 1.6 + Vector3.UP * SAIDA_ALTURA,
				carro + Vector3.UP * 0.9, SAIDA_FOV)
		_:
			pass
'''
new = '''		Plano.SAIDA:
			var p := EstradaBuilder.ponto_em(_ancora)
			var l := EstradaBuilder.lado_em(_ancora)
			_enquadrar(p + l * 1.6 + Vector3.UP * SAIDA_ALTURA,
				carro + Vector3.UP * 0.9, SAIDA_FOV)
		Plano.CHASE:
			# 3a pessoa atras do hatch (ref 03): recuo baixo, farois na pista.
			var de_chase := carro - dir * 7.4 + Vector3.UP * 2.1 + lado * 0.35
			_enquadrar(de_chase, carro + dir * 6.0 + Vector3.UP * 0.7, 58.0)
		_:
			pass
'''
if "Plano.CHASE:" not in t:
    if old not in t: raise SystemExit("SAIDA match missing")
    t = t.replace(old, new, 1)

# 5) HUD on during DENTRO already — also leave as is for cutscene.
# Ensure _plano_dentro keeps HUD; for jogavel we handle separately.

# 6) Append helpers
if "func _correr_jogavel" not in t:
    t = t.rstrip() + '''


# --- captura / clima / jogavel (TASK AAA) ------------------------------------

func _flag_estrada_qualquer() -> bool:
	var args := OS.get_cmdline_user_args()
	return (args.has("--ver-estrada")
		or args.has("--ver-estrada-cabine")
		or args.has("--ver-estrada-jogavel"))


func _quer_jogavel() -> bool:
	var args := OS.get_cmdline_user_args()
	# Flag preferida do contrato com Renatin / CaptureTool.
	if args.has("--ver-estrada-cabine") or args.has("--ver-estrada-jogavel"):
		return true
	for arg: String in args:
		if arg == "--estrada-modo=jogavel" or arg == "--estrada-modo=playable":
			return true
	return false


func _clima_id() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--estrada-clima="):
			return arg.trim_prefix("--estrada-clima=")
	# Padrao das refs de horror: noite com farois.
	if _flag_estrada_qualquer():
		return "noite"
	return "entardecer"


func _caminho_clima() -> String:
	var id := _clima_id()
	if CLIMAS_ESTRADA.has(id):
		return String(CLIMAS_ESTRADA[id])
	return PRESET


func _plano_captura() -> Plano:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--estrada-plano="):
			continue
		match arg.trim_prefix("--estrada-plano="):
			"passagem":
				return Plano.PASSAGEM
			"aerea":
				return Plano.AEREA
			"rasante":
				return Plano.RASANTE
			"dentro", "fp", "cabine":
				return Plano.DENTRO
			"saida":
				return Plano.SAIDA
			"chase", "tp":
				return Plano.CHASE
	# --ver-estrada sem plano: segura FP cabine (ref 01). Jogavel nao passa aqui.
	if OS.get_cmdline_user_args().has("--ver-estrada") and not _quer_jogavel():
		return Plano.DENTRO
	return Plano.NENHUM


## Segura um plano ate o CaptureTool matar o processo (--shot-quit).
func _segurar_captura(plano: Plano) -> void:
	_carro.distancia = 120.0
	_estrada.atualizar(_carro.distancia)
	_carro.assentar()
	_ancora = _carro.distancia + PASSAGEM_ADIANTE
	_comecar(plano, 9999.0)
	# HUD camera-agnostic: ligado em 1P e 3P.
	if plano in [Plano.DENTRO, Plano.CHASE] and _hud != null:
		_hud.visible = true
		_hud.definir_local("ESTRADA VELHA")
		_hud.definir_hora("22:43")
		_hud.definir_vida(4, 10)
		_hud.definir_lanterna(true)
	if plano == Plano.CHASE:
		_terceira = true
		if _carro != null:
			_carro.mostrar_cabine(false)
	await Cinema.clarear(0.35)
	await get_tree().create_timer(120.0).timeout


func _ligar_farois_se_noite() -> void:
	if _clima_id() not in ["noite", "amanhecer"]:
		return
	if _carro == null:
		return
	_carro.acender_farois(true)


## Cabine jogavel: default 1P, V alterna chase 3P. HUD sempre visivel.
func _correr_jogavel() -> void:
	_jogavel = true
	_terceira = false
	_carro.jogavel = true
	_carro.distancia = 80.0
	_carro.velocidade = 42.0
	_estrada.atualizar(_carro.distancia)
	_carro.assentar()
	_carro.mostrar_cabine(true)
	_comecar(Plano.DENTRO, 9999.0)
	if _hud != null:
		_hud.visible = true
		_hud.definir_local("ESTRADA VELHA")
		_hud.definir_hora("22:43")
		_hud.definir_vida(4, 10)
		_hud.definir_lanterna(true)
	await Cinema.clarear(0.4)
	await get_tree().create_timer(180.0).timeout


func _unhandled_input(event: InputEvent) -> void:
	if not _jogavel:
		return
	if event.is_action_pressed("alternar_camera"):
		_alternar_camera_jogavel()
		get_viewport().set_input_as_handled()


func _alternar_camera_jogavel() -> void:
	_terceira = not _terceira
	if _terceira:
		_plano = Plano.CHASE
		if _carro != null:
			_carro.mostrar_cabine(false)
	else:
		_plano = Plano.DENTRO
		if _carro != null:
			_carro.mostrar_cabine(true)
	if _hud != null:
		_hud.visible = true
	_mover_camera(0.0)
'''

src.write_text(t, encoding="utf-8")
print("ok lines", t.count("\n")+1)

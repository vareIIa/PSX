from pathlib import Path
src = Path(r"game/src/levels/abertura_estrada.gd")
t = src.read_text(encoding="utf-8")

# Add playable state vars near other vars
a = '''var _far_anterior: float = 600.0


func executar(cena: Node3D) -> void:'''
b = '''var _far_anterior: float = 600.0
## Modo jogavel (TASK AAA): WASD + V 1P/3P. Cutscene continua o default.
var _jogavel: bool = false
## True = chase 3P; false = cabine 1P (default).
var _terceira: bool = false


func executar(cena: Node3D) -> void:'''
if a not in t: raise SystemExit("vars block missing")
t = t.replace(a,b,1)

# After capture early-return, also support playable
a = '''	var plano_cap := _plano_captura()
	if plano_cap != Plano.NENHUM:
		await _segurar_captura(plano_cap)
		_desmontar()
		terminou.emit()
		queue_free()
		return

	await _plano_passagem()'''
b = '''	if _quer_jogavel():
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

	await _plano_passagem()'''
if a not in t: raise SystemExit("executar branch missing")
t = t.replace(a,b,1)

# Farois via CarroCena API
a = '''func _ligar_farois_se_noite() -> void:
	if _clima_id() not in ["noite", "amanhecer"]:
		return
	if _carro == null:
		return
	# Farol unico largo (mesmo contrato do Carro de rua) — mapa/clima, nao cabine.
	var farol := SpotLight3D.new()
	farol.name = "FarolEstrada"
	farol.position = Vector3(0.0, 0.62, -1.7)
	farol.rotation.x = deg_to_rad(-9.0)
	farol.spot_range = 28.0
	farol.spot_angle = 36.0
	farol.spot_angle_attenuation = 0.85
	farol.light_energy = 4.2 if _clima_id() == "noite" else 1.6
	farol.light_color = Color(1.0, 0.92, 0.78)
	farol.shadow_enabled = false
	_carro.add_child(farol)'''
b = '''func _ligar_farois_se_noite() -> void:
	if _clima_id() not in ["noite", "amanhecer"]:
		return
	if _carro == null:
		return
	_carro.acender_farois(true)'''
# May have encoding differences on em-dash — try flexible
if a not in t:
    # fuzzy: replace from func to end by finding markers
    start = t.find("func _ligar_farois_se_noite()")
    if start < 0: raise SystemExit("farois func missing")
    # find next func or EOF
    end = t.find("\nfunc ", start + 5)
    if end < 0:
        end = len(t)
    else:
        # include nothing of next func; keep leading newline handled
        pass
    t = t[:start] + b + "\n" + t[end:]
else:
    t = t.replace(a,b,1)

# Update clima/plano flags for cabine
a = '''	# Padrao das refs de horror: noite com farois.
	if OS.get_cmdline_user_args().has("--ver-estrada"):
		return "noite"
	return "entardecer"'''
b = '''	# Padrao das refs de horror: noite com farois.
	if _flag_estrada_qualquer():
		return "noite"
	return "entardecer"'''
if a not in t: raise SystemExit("clima default missing")
t = t.replace(a,b,1)

a = '''	# Com --ver-estrada sem plano, segura FP cabine (ref 01).
	if OS.get_cmdline_user_args().has("--ver-estrada"):
		return Plano.DENTRO
	return Plano.NENHUM'''
b = '''	# Com --ver-estrada / --ver-estrada-cabine sem plano, segura FP cabine (ref 01).
	# O modo jogavel (--ver-estrada-cabine) nao passa por aqui: ver `_quer_jogavel`.
	if OS.get_cmdline_user_args().has("--ver-estrada") and not _quer_jogavel():
		return Plano.DENTRO
	return Plano.NENHUM'''
if a not in t: raise SystemExit("plano default missing")
t = t.replace(a,b,1)

# HUD visible for DENTRO and CHASE in capture hold
a = '''	_comecar(plano, 9999.0)
	if plano == Plano.DENTRO and _hud != null:
		_hud.visible = true
	await Cinema.clarear(0.35)'''
b = '''	_comecar(plano, 9999.0)
	# HUD camera-agnostic: ligado em 1P e 3P enquanto se dirige / captura.
	if plano in [Plano.DENTRO, Plano.CHASE] and _hud != null:
		_hud.visible = true
		_hud.definir_local("ESTRADA VELHA")
		_hud.definir_hora("22:43")
	if plano == Plano.CHASE:
		_terceira = true
		if _carro != null:
			_carro.mostrar_cabine(false)
	await Cinema.clarear(0.35)'''
if a not in t: raise SystemExit("segurar hud missing")
t = t.replace(a,b,1)

# Also show HUD in cutscene DENTRO (already does) — and for chase if ever used
# Update _plano_dentro stays as is.

# Append playable helpers at end
extra = '''

# --- jogavel / flags AAA ----------------------------------------------------

func _flag_estrada_qualquer() -> bool:
	var args := OS.get_cmdline_user_args()
	return (args.has("--ver-estrada")
		or args.has("--ver-estrada-cabine")
		or args.has("--ver-estrada-jogavel"))


func _quer_jogavel() -> bool:
	var args := OS.get_cmdline_user_args()
	# Flag preferida do contrato Renatin/AAA.
	if args.has("--ver-estrada-cabine") or args.has("--ver-estrada-jogavel"):
		return true
	for arg: String in args:
		if arg == "--estrada-modo=jogavel" or arg == "--estrada-modo=playable":
			return true
	return false


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
	# Fica vivo ate CaptureTool (--shot-quit) ou 3 min de smoke manual.
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
	# HUD permanece visivel nos dois modos (contrato Renatin).
	if _hud != null:
		_hud.visible = true
	_mover_camera(0.0)
'''

if "func _correr_jogavel" not in t:
    t = t.rstrip() + "\n" + extra

src.write_text(t, encoding="utf-8")
print("abertura patched", len(t))

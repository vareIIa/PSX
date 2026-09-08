from pathlib import Path
p = Path(r"game/src/levels/abertura_estrada.gd")
text = p.read_text(encoding="utf-8")

old = "\t_hud = HudEstrada.new()\n\t_hud.name = \"HudEstrada\"\n\t_cena.add_child(_hud)\n\t_hud.visible = false"
new = """\t_hud = HudEstrada.new()
\t_hud.name = \"HudEstrada\"
\t_cena.add_child(_hud)
\t_hud.visible = false
\t# Look da print: LOCAL/HORA/vida parcial/lanterna acesa. O nivel pode
\t# sobrescrever depois; estes sao os defaults da abertura.
\t_hud.definir_local(\"ESTRADA VELHA\")
\t_hud.definir_hora(\"22:43\")
\t_hud.definir_vida(4, 10)
\t_hud.definir_lanterna(true)"""
if old not in text:
    raise SystemExit("HUD block not found")
text = text.replace(old, new, 1)

old_exec = """func executar(cena: Node3D) -> void:
\t_cena = cena
\tCinema.fechar_de_imediato()
\tCinema.iniciar(true)
\t_montar_mundo()

\t_cam = Cinema.assumir()
\t_far_anterior = _cam.far
\t_cam.far = 260.0
\t_cam.near = 0.08
\tset_process(true)

\tawait _plano_passagem()
\tawait _plano_aerea()
\tawait _plano_rasante()
\tawait _plano_dentro()
\tawait _plano_saida()

\t_desmontar()
\tterminou.emit()
\tqueue_free()"""

new_exec = """func executar(cena: Node3D) -> void:
\t_cena = cena
\tCinema.fechar_de_imediato()
\tCinema.iniciar(true)
\t_montar_mundo()

\t_cam = Cinema.assumir()
\t_far_anterior = _cam.far
\t_cam.far = 260.0
\t_cam.near = 0.08
\tset_process(true)

\t# Caminho de captura do HUD: pula planos 1-3 e 5 e fica no de dentro,
\t# onde a lanterna/vida/LOCAL/HORA aparecem. Quem fotografa e o CaptureTool.
\tvar so_cabine := OS.get_cmdline_user_args().has(\"--ver-hud-estrada\")
\tif so_cabine:
\t\tawait _plano_dentro()
\t\t# Segura a cabine aberta para o --shot-frame alcancar o HUD visivel.
\t\tawait _esperar(30.0)
\t\t_desmontar()
\t\tterminou.emit()
\t\tqueue_free()
\t\treturn

\tawait _plano_passagem()
\tawait _plano_aerea()
\tawait _plano_rasante()
\tawait _plano_dentro()
\tawait _plano_saida()

\t_desmontar()
\tterminou.emit()
\tqueue_free()"""

if old_exec not in text:
    raise SystemExit("executar block not found")
text = text.replace(old_exec, new_exec, 1)

old_dentro = """func _plano_dentro() -> void:
\t_comecar(Plano.DENTRO, DENTRO_DURACAO)
\t# O HUD sobe ANTES de a cortina abrir. Ele aparecendo depois leria como
\t# interface entrando na tela, e o que se quer e que ele ja estivesse la.
\t_hud.visible = true
\tawait Cinema.clarear(0.7)"""

new_dentro = """func _plano_dentro() -> void:
\t_aplicar_overrides_hud()
\tvar dur := DENTRO_DURACAO
\tif OS.get_cmdline_user_args().has(\"--ver-hud-estrada\"):
\t\tdur = maxf(dur, 60.0)
\t_comecar(Plano.DENTRO, dur)
\t# O HUD sobe ANTES de a cortina abrir. Ele aparecendo depois leria como
\t# interface entrando na tela, e o que se quer e que ele ja estivesse la.
\t_hud.visible = true
\tawait Cinema.clarear(0.7)"""

if old_dentro not in text:
    raise SystemExit("plano_dentro block not found")
text = text.replace(old_dentro, new_dentro, 1)

helper = '''
## Overrides de captura / debug: --hora=HH:MM e --vida=N (0..10).
func _aplicar_overrides_hud() -> void:
\tif _hud == null:
\t\treturn
\tfor arg: String in OS.get_cmdline_user_args():
\t\tif arg.begins_with("--hora="):
\t\t\t_hud.definir_hora(arg.trim_prefix("--hora="))
\t\telif arg.begins_with("--vida="):
\t\t\t_hud.definir_vida(int(arg.trim_prefix("--vida=")), 10)
\t\telif arg == "--lanterna-off":
\t\t\t_hud.definir_lanterna(false)


'''

marker = "# --- montagem ---------------------------------------------------------------\n"
if marker not in text:
    raise SystemExit("montagem marker not found")
if "_aplicar_overrides_hud" not in text:
    text = text.replace(marker, helper + marker, 1)

p.write_text(text, encoding="utf-8")
print("abertura_estrada.gd patched ok")

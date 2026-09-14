from pathlib import Path
p = Path(r"game/src/levels/abertura_estrada.gd")
t = p.read_text(encoding="utf-8")
# After hardcoded defaults in _segurar_captura, apply overrides
old = """\tif plano in [Plano.DENTRO, Plano.CHASE] and _hud != null:
\t\t_hud.visible = true
\t\t_hud.definir_local(\"ESTRADA VELHA\")
\t\t_hud.definir_hora(\"22:43\")
\t\t_hud.definir_vida(4, 10)
\t\t_hud.definir_lanterna(true)"""
new = """\tif plano in [Plano.DENTRO, Plano.CHASE] and _hud != null:
\t\t_hud.visible = true
\t\t_hud.definir_local(\"ESTRADA VELHA\")
\t\t_hud.definir_hora(\"22:43\")
\t\t_hud.definir_vida(4, 10)
\t\t_hud.definir_lanterna(true)
\t\t_aplicar_overrides_hud()"""
if old not in t:
    raise SystemExit("segurar block not found")
if "_aplicar_overrides_hud()" not in t[t.find("func _segurar_captura"):t.find("func _segurar_captura")+600]:
    t = t.replace(old, new, 1)
    print("segurar: overrides after defaults")
else:
    print("segurar: already has overrides")

# Same for _correr_jogavel
old2 = """\tif _hud != null:
\t\t_hud.visible = true
\t\t_hud.definir_local(\"ESTRADA VELHA\")
\t\t_hud.definir_hora(\"22:43\")
\t\t_hud.definir_vida(4, 10)
\t\t_hud.definir_lanterna(true)
\tawait Cinema.clarear(0.4)"""
new2 = """\tif _hud != null:
\t\t_hud.visible = true
\t\t_hud.definir_local(\"ESTRADA VELHA\")
\t\t_hud.definir_hora(\"22:43\")
\t\t_hud.definir_vida(4, 10)
\t\t_hud.definir_lanterna(true)
\t\t_aplicar_overrides_hud()
\tawait Cinema.clarear(0.4)"""
if old2 in t and t.count("_aplicar_overrides_hud()") < 3:
    t = t.replace(old2, new2, 1)
    print("jogavel: overrides after defaults")
p.write_text(t, encoding="utf-8", newline="\n")
print("overrides count", t.count("_aplicar_overrides_hud()"))

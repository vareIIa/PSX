from pathlib import Path

ROOT = Path(".")

# --- 1) cidade.gd: --ver-estrada capture hook ---
cidade = ROOT / "game/src/levels/cidade.gd"
text = cidade.read_text(encoding="utf-8")

old_ab = """\tif OS.get_cmdline_user_args().has(\"--ver-abertura\"):\n\t\t_rodar_abertura()"""
new_ab = """\tif OS.get_cmdline_user_args().has(\"--ver-abertura\"):\n\t\t_rodar_abertura()\n\tif OS.get_cmdline_user_args().has(\"--ver-estrada\"):\n\t\t_rodar_estrada()"""
if old_ab not in text:
    raise SystemExit("cidade: --ver-abertura block not found")
if "--ver-estrada" not in text:
    text = text.replace(old_ab, new_ab, 1)

old_title = """\t\tif a in [\"--pular-menu\", \"--ver-abertura\"]:\n\t\t\treturn false"""
new_title = """\t\tif a in [\"--pular-menu\", \"--ver-abertura\", \"--ver-estrada\"]:\n\t\t\treturn false"""
if old_title in text:
    text = text.replace(old_title, new_title, 1)

rodar = '''
## Caminho de captura / inspecao da Estrada Velha (mapa).
## Bob (cinematica) emenda NOVO JOGO -> estrada -> abertura via `_rodar_abertura`.
## Este gancho e so para CaptureTool / AAA do mapa sem passar pelo menu.
func _rodar_estrada() -> void:
\tvar estrada := AberturaEstrada.new()
\tadd_child(estrada)
\testrada.executar(self)
'''

if "func _rodar_estrada()" not in text:
    anchor = "func _rodar_abertura() -> void:"
    if anchor not in text:
        raise SystemExit("cidade: _rodar_abertura not found")
    text = text.replace(anchor, rodar + "\n" + anchor, 1)

cidade.write_text(text, encoding="utf-8", newline="\n")
print("patched cidade.gd")

# --- 2) abertura_estrada.gd: climate + capture hold ---
ab = ROOT / "game/src/levels/abertura_estrada.gd"
at = ab.read_text(encoding="utf-8")

# Replace PRESET const with climate map + helpers after const PRESET
if "CLIMAS_ESTRADA" not in at:
    old_p = 'const PRESET := "res://resources/fog/fog_estrada.tres"'
    new_p = '''const PRESET := "res://resources/fog/fog_estrada.tres"
## Tres estados de clima da Estrada Velha (refs). `--estrada-clima=` escolhe.
const CLIMAS_ESTRADA := {
\t"entardecer": "res://resources/fog/fog_estrada.tres",
\t"noite": "res://resources/fog/fog_estrada_noite.tres",
\t"amanhecer": "res://resources/fog/fog_estrada_amanhecer.tres",
\t"dia": "res://resources/fog/fog_estrada_dia.tres",
}'''
    if old_p not in at:
        raise SystemExit("abertura: PRESET not found")
    at = at.replace(old_p, new_p, 1)

# Extend enum with CHASE and CAPTURA hold
if "CHASE" not in at:
    at = at.replace(
        "enum Plano { NENHUM, PASSAGEM, AEREA, RASANTE, DENTRO, SAIDA }",
        "enum Plano { NENHUM, PASSAGEM, AEREA, RASANTE, DENTRO, SAIDA, CHASE }",
        1,
    )

# Patch executar to support capture hold
old_exec_tail = '''\tawait _plano_passagem()\n\tawait _plano_aerea()\n\tawait _plano_rasante()\n\tawait _plano_dentro()\n\tawait _plano_saida()\n\n\t_desmontar()\n\tterminou.emit()\n\tqueue_free()'''

new_exec_tail = '''\tvar plano_cap := _plano_captura()\n\tif plano_cap != Plano.NENHUM:\n\t\tawait _segurar_captura(plano_cap)\n\t\t_desmontar()\n\t\tterminou.emit()\n\t\tqueue_free()\n\t\treturn\n\n\tawait _plano_passagem()\n\tawait _plano_aerea()\n\tawait _plano_rasante()\n\tawait _plano_dentro()\n\tawait _plano_saida()\n\n\t_desmontar()\n\tterminou.emit()\n\tqueue_free()'''

if "_segurar_captura" not in at:
    if old_exec_tail not in at:
        raise SystemExit("abertura: exec tail not found")
    at = at.replace(old_exec_tail, new_exec_tail, 1)

# Patch fog forcar to use climate
old_fog = '''\tif _fog != null:\n\t\t_fog.forcar(PRESET)'''
new_fog = '''\tif _fog != null:\n\t\t_fog.forcar(_caminho_clima())\n\t_ligar_farois_se_noite()\n\tif _estrada != null:\n\t\t_estrada.clima_id = _clima_id()'''
if "_caminho_clima" not in at:
    if old_fog not in at:
        raise SystemExit("abertura: fog forcar not found")
    at = at.replace(old_fog, new_fog, 1)

# Add CHASE camera in match + helpers before end of file
helpers = '''

# --- captura / clima --------------------------------------------------------

func _clima_id() -> String:
\tfor arg: String in OS.get_cmdline_user_args():
\t\tif arg.begins_with("--estrada-clima="):
\t\t\treturn arg.trim_prefix("--estrada-clima=")
\t# Padrao das refs de horror: noite com farois.
\tif OS.get_cmdline_user_args().has("--ver-estrada"):
\t\treturn "noite"
\treturn "entardecer"


func _caminho_clima() -> String:
\tvar id := _clima_id()
\tif CLIMAS_ESTRADA.has(id):
\t\treturn String(CLIMAS_ESTRADA[id])
\treturn PRESET


func _plano_captura() -> Plano:
\tfor arg: String in OS.get_cmdline_user_args():
\t\tif not arg.begins_with("--estrada-plano="):
\t\t\tcontinue
\t\tmatch arg.trim_prefix("--estrada-plano="):
\t\t\t"passagem":
\t\t\t\treturn Plano.PASSAGEM
\t\t\t"aerea":
\t\t\t\treturn Plano.AEREA
\t\t\t"rasante":
\t\t\t\treturn Plano.RASANTE
\t\t\t"dentro", "fp", "cabine":
\t\t\t\treturn Plano.DENTRO
\t\t\t"saida":
\t\t\t\treturn Plano.SAIDA
\t\t\t"chase", "tp":
\t\t\t\treturn Plano.CHASE
\t# Com --ver-estrada sem plano, segura FP cabine (ref 01).
\tif OS.get_cmdline_user_args().has("--ver-estrada"):
\t\treturn Plano.DENTRO
\treturn Plano.NENHUM


## Segura um plano ate o CaptureTool matar o processo (--shot-quit).
func _segurar_captura(plano: Plano) -> void:
\t# Avanca o carro para um trecho com mata montada (nao o metro zero).
\t_carro.distancia = 120.0
\t_estrada.atualizar(_carro.distancia)
\t_carro.assentar()
\t_ancora = _carro.distancia + PASSAGEM_ADIANTE
\t_comecar(plano, 9999.0)
\tif plano == Plano.DENTRO and _hud != null:
\t\t_hud.visible = true
\tawait Cinema.clarear(0.35)
\t# Fica vivo: CaptureTool tira o PNG e quita.
\tawait get_tree().create_timer(120.0).timeout


func _ligar_farois_se_noite() -> void:
\tif _clima_id() not in ["noite", "amanhecer"]:
\t\treturn
\tif _carro == null:
\t\treturn
\t# Farol unico largo (mesmo contrato do Carro de rua) — mapa/clima, nao cabine.
\tvar farol := SpotLight3D.new()
\tfarol.name = "FarolEstrada"
\tfarol.position = Vector3(0.0, 0.62, -1.7)
\tfarol.rotation.x = deg_to_rad(-9.0)
\tfarol.spot_range = 28.0
\tfarol.spot_angle = 36.0
\tfarol.spot_angle_attenuation = 0.85
\tfarol.light_energy = 4.2 if _clima_id() == "noite" else 1.6
\tfarol.light_color = Color(1.0, 0.92, 0.78)
\tfarol.shadow_enabled = false
\t_carro.add_child(farol)
'''

if "func _segurar_captura" not in at:
    at = at.rstrip() + "\n" + helpers

# Add CHASE branch in _mover_camera match
old_saida = '''\t\tPlano.SAIDA:\n\t\t\tvar p := EstradaBuilder.ponto_em(_ancora)\n\t\t\tvar l := EstradaBuilder.lado_em(_ancora)\n\t\t\t_enquadrar(p + l * 1.6 + Vector3.UP * SAIDA_ALTURA,\n\t\t\t\tcarro + Vector3.UP * 0.9, SAIDA_FOV)'''
new_saida = '''\t\tPlano.SAIDA:\n\t\t\tvar p := EstradaBuilder.ponto_em(_ancora)\n\t\t\tvar l := EstradaBuilder.lado_em(_ancora)\n\t\t\t_enquadrar(p + l * 1.6 + Vector3.UP * SAIDA_ALTURA,\n\t\t\t\tcarro + Vector3.UP * 0.9, SAIDA_FOV)\n\t\tPlano.CHASE:\n\t\t\t# 3a pessoa atras do hatch (ref 03): recuo baixo, farois na pista.\n\t\t\tvar de_chase := carro - dir * 7.4 + Vector3.UP * 2.1 + lado * 0.35\n\t\t\t_enquadrar(de_chase, carro + dir * 6.0 + Vector3.UP * 0.7, 58.0)'''
if "Plano.CHASE:" not in at:
    if old_saida not in at:
        raise SystemExit("abertura: SAIDA match not found")
    at = at.replace(old_saida, new_saida, 1)

ab.write_text(at, encoding="utf-8", newline="\n")
print("patched abertura_estrada.gd")
print("done phase A")

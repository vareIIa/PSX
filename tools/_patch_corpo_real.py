# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# 1) Lock yaw north — skip praca_alvo reorient
old_yaw = """\t# Virar pra praca antes de deitar: pes apontam pro miolo (coreto), cabeca
\t# pra fora — assim o FP olhando -eixo enquadra a praca alem das pernas.
\tvar praca_alvo := _praca_mais_perto(onde)
\tif praca_alvo != Vector3.INF:
\t\tvar para := Vector3(praca_alvo.x - onde.x, 0.0, praca_alvo.z - onde.z)
\t\tif para.length_squared() > 1.0:
\t\t\t# Em pe, frente do jogador = (-sin y, 0, -cos y). Olhar pra praca.
\t\t\t_jogador.rotation.y = atan2(-para.x, -para.z)
"""
# emdash may vary — find by unique lines
a = t.find("Virar pra praca antes de deitar")
if a < 0:
    raise SystemExit("yaw block missing")
start = t.rfind("\n", 0, a) + 1
# find end after atan2 block
b = t.find("_jogador.rotation.y = atan2(-para.x, -para.z)", a)
if b < 0:
    raise SystemExit("atan2 missing")
end = t.find("\n", b) + 1
new_yaw = (
	"\t# Pin Cleiton/Jota: yaw travado norte (lampiao SW a esquerda).\n"
	"\t# Nao reorientar pro centroid do parque — isso puxava o olhar e\n"
	"\t# invertia L/R vs ref 01.\n"
	"\t_jogador.rotation.y = 0.0\n"
)
t = t[:start] + new_yaw + t[end:]

# 2) Restore bone camera + show real Corpo (no hide, no FP props on capture)
# Replace camera block from alvo_look through olhar_ate
i = t.find("var alvo_look := Vector3(272.0, 0.0, -58.0)")
if i < 0:
    i = t.find("var alvo_look := Vector3(272.0, 0.0, -66.0)")
if i < 0:
    raise SystemExit("alvo_look missing")
j = t.find("var t0 := Time.get_ticks_msec()", i)
new_cam = """\tvar alvo_look := Vector3(272.0, 0.0, -58.0)
\tvar frente_praca := Vector3(alvo_look.x - onde.x, 0.0, alvo_look.z - onde.z)
\tif frente_praca.length_squared() < 0.01:
\t\tfrente_praca = Vector3(0.0, 0.0, -1.0)
\tfrente_praca = frente_praca.normalized()

\t# Camera pelos OSSOS: cabeca -> meio das canelas. Corpo real no FOV
\t# (calca+bota do atlas) — props FP so liam como laje.
\tvar cam_de: Vector3
\tvar olhar_de: Vector3
\tif figura != null:
\t\tvar p_cabeca := _ponto_osso(figura, Corpo.Osso.CABECA)
\t\tvar p_pe_e := _ponto_osso(figura, Corpo.Osso.CANELA_E)
\t\tvar p_pe_d := _ponto_osso(figura, Corpo.Osso.CANELA_D)
\t\tvar p_pes := (p_pe_e + p_pe_d) * 0.5
\t\tcam_de = p_cabeca - frente_praca * 0.55 + Vector3.UP * 0.18
\t\t# Mira entre as botas, levemente alem — pernas no terco baixo, praca alem.
\t\tolhar_de = Vector3(p_pes.x, onde.y + 0.05, p_pes.z) + frente_praca * 0.70
\telse:
\t\tcam_de = Vector3(onde.x, onde.y + 0.22, onde.z)
\t\tolhar_de = Vector3(onde.x, onde.y + 0.05, onde.z) + frente_praca * 2.2
\tvar cam_ate := Vector3(onde.x, onde.y + ACORDA_ALTURA.y, onde.z)
\tvar olhar_ate := Vector3(onde.x, onde.y + 1.15, onde.z) + frente_praca * ACORDA_OLHAR_LONGE

"""
t = t[:i] + new_cam + t[j:]

# 3) Replace hide+montar flow with show corpo, no props
# Remove mostrar_corpo(false) and montar before capture; ensure show true
old_hide = "\t_jogador.mostrar_corpo(false)\n"
# only in _plano_da_praca — find after apoio block near 01_acordar
k = t.find("# Lampiao quente a ESQUERDA")
if k < 0:
    raise SystemExit("lamp block missing")
# from after apoio through capture setup
m = t.find("_jogador.mostrar_corpo(false)", k)
if m < 0:
    # maybe already removed
    print("no hide after lamp — ok?")
else:
    # replace block until after montar/clarear setup
    # Find the section
    pass

# Simpler: replace known sequence
seq_a = "\t_jogador.mostrar_corpo(false)\n\t_montar_pernas_fp(Cinema.assumir())\n"
seq_b = "\t_jogador.mostrar_corpo(false)\n"
if seq_a in t[k:k+800]:
    t = t[:k] + t[k:].replace(seq_a, "\t_jogador.mostrar_corpo(true)\n", 1)
elif "\t_jogador.mostrar_corpo(false)\n" in t[k:k+500]:
    t = t[:k] + t[k:].replace("\t_jogador.mostrar_corpo(false)\n", "\t_jogador.mostrar_corpo(true)\n", 1)

# Remove montar before capture if present
needle = 'await Cinema.clarear(2.2)\n\t_montar_pernas_fp(Cinema.assumir())\n\tCinema.legenda'
repl = 'await Cinema.clarear(2.2)\n\tCinema.legenda'
if needle in t:
    t = t.replace(needle, repl, 1)

# Remove limpar_pernas before levantar (harmless but clean) — keep as no-op ok
# Change limpar + show before levantar to just show
old_up = "\t_limpar_pernas_fp()\n\t_jogador.mostrar_corpo(true)\n"
if old_up in t:
    t = t.replace(old_up, "\t_limpar_pernas_fp()\n\t_jogador.mostrar_corpo(true)\n", 1)  # keep

p.write_text(t, encoding="utf-8", newline="\n")
print("OK corpo real + bone cam + yaw norte")

# Strengthen knee bend in corpo.gd
c = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\corpo.gd")
ct = c.read_text(encoding="utf-8")
old_pose = """\t_girar(Osso.COXA_E, -0.95, 0.0, 0.12)
\t_girar(Osso.CANELA_E, 1.45)
\t_girar(Osso.COXA_D, -0.85, 0.0, -0.12)
\t_girar(Osso.CANELA_D, 1.35)
"""
new_pose = """\t_girar(Osso.COXA_E, -1.15, 0.0, 0.18)
\t_girar(Osso.CANELA_E, 1.55)
\t_girar(Osso.COXA_D, -1.05, 0.0, -0.18)
\t_girar(Osso.CANELA_D, 1.48)
"""
if old_pose not in ct:
    raise SystemExit("pose block missing")
c.write_text(ct.replace(old_pose, new_pose), encoding="utf-8", newline="\n")
print("OK pose joelhos")

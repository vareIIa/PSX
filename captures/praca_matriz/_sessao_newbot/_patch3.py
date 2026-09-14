from pathlib import Path

# --- kit_parque: stronger tower + windows + gable ---
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
t = p.read_text(encoding="utf-8")
start = t.index("static func igreja_matriz")
end = t.index("static func poste_lanterna")
body = t[start:end]

# Pull tower closer to nave (was too far left / eaten)
old_t = "var torre := centro + lado * -(largura * 0.42 + 1.15) - frente * 0.35"
new_t = "var torre := centro + lado * -(largura * 0.42 + 0.55) - frente * 0.15"
if old_t not in body:
    raise SystemExit("torre line missing: " + repr(old_t))
body = body.replace(old_t, new_t, 1)

# Taller tower for silhouette
body = body.replace("var torre_h := 8.4", "var torre_h := 9.8", 1)

# Window size bump
body = body.replace(
    "jan, Vector3(1.05, 1.35, 0.12), Color(\"101010\"), giro,",
    "jan, Vector3(1.25, 1.55, 0.14), Color(\"0a0a0a\"), giro,",
    1,
)

# Bigger roof cross
body = body.replace(
    "cruz_c, Vector3(0.14, 0.85, 0.14), trim, giro,",
    "cruz_c, Vector3(0.22, 1.15, 0.22), Color(\"2a2218\"), giro,",
    1,
)
body = body.replace(
    "cruz_c + Vector3(0.0, 0.18, 0.0), Vector3(0.55, 0.14, 0.14), trim, giro,",
    "cruz_c + Vector3(0.0, 0.22, 0.0), Vector3(0.85, 0.22, 0.22), Color(\"2a2218\"), giro,",
    1,
)

t = t[:start] + body + t[end:]
p.write_text(t, encoding="utf-8", newline="\n")
print("kit tower/windows updated")

# --- parque_builder: soft door lamps (facho was blowing white bloom into fog) ---
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
tb = pb.read_text(encoding="utf-8")
# Only the door-lantern block uses energia 10.5 after our patch
old = '''\t\tprops.append({
\t\t\t"tipo": "lampada",
\t\t\t"pos": luz_p,
\t\t\t"padrao": Lampada.Padrao.ESTAVEL,
\t\t\t"semente": sem + indice * 97,
\t\t\t"cor": Color("ffe8b0"), "energia": 10.5, "alcance": 14.0,
\t\t\t"facho": true,
\t\t})'''
new = '''\t\tprops.append({
\t\t\t"tipo": "lampada",
\t\t\t"pos": luz_p,
\t\t\t"padrao": Lampada.Padrao.ESTAVEL,
\t\t\t"semente": sem + indice * 97,
\t\t\t# Omni sem facho: o cone no denso virava bloom branco e comia a fachada.
\t\t\t"cor": Color("ffe0a8"), "energia": 6.5, "alcance": 11.0,
\t\t\t"facho": false,
\t\t})'''
if old not in tb:
    raise SystemExit("door lamp block missing")
tb = tb.replace(old, new, 1)
pb.write_text(tb, encoding="utf-8", newline="\n")
print("door lamps softened")

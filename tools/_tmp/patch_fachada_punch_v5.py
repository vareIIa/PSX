# -*- coding: utf-8 -*-
"""v5: janela_acesa rim (kit PSX trick) + church nudge closer for fog=denso."""
from pathlib import Path

kit = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
t = kit.read_text(encoding="utf-8")

# After the white ombreira box, inject janela_acesa punch rim + cross glow.
# Marker: the big ombreira box we already punched.
marker = '''\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 0.08, 0.0), Vector3(3.25, 4.15, 0.58), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Jambas laterais extras (pilastras) — espessura em X que o 480 resolve.'''

insert = '''\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 0.08, 0.0), Vector3(3.25, 4.15, 0.58), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Rim emissivo via janela_acesa — mesmo truque do globo do poste: sobra no denso
\t# onde albedo tingido lava. Nao e sistema novo; e o material ja usado no kit.
\tKitModular.caixa(sup, &"janela_acesa",
\t\tporta_c + frente * 0.22 + Vector3(0.0, 0.08, 0.0),
\t\tVector3(3.35, 4.25, 0.1), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Jambas laterais extras (pilastras) — espessura em X que o 480 resolve.'''

assert marker in t, "ombreira marker missing"
t = t.replace(marker, insert, 1)

# Bright cross: add janela_acesa face in front of clara cruz
old_cruz_tail = '''\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tcruz_c + Vector3(0.0, 0.55, 0.0), Vector3(1.85, 0.38, 0.38), cruz_clara, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Contorno escuro atras (1 px de leitura no 480 quando o claro lava).
\tKitModular.caixa_cor(sup, &"metal",
\t\tcruz_c + frente * -0.08, Vector3(0.5, 2.5, 0.2), trim, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''

new_cruz_tail = '''\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tcruz_c + Vector3(0.0, 0.55, 0.0), Vector3(1.85, 0.38, 0.38), cruz_clara, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Face emissiva na cruz (poste/lamp trick) — le no denso a 10 m.
\tKitModular.caixa(sup, &"janela_acesa",
\t\tcruz_c + frente * 0.18, Vector3(0.48, 2.45, 0.08), giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa(sup, &"janela_acesa",
\t\tcruz_c + frente * 0.18 + Vector3(0.0, 0.55, 0.0),
\t\tVector3(1.95, 0.42, 0.08), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Contorno escuro atras (1 px de leitura no 480 quando o claro lava).
\tKitModular.caixa_cor(sup, &"metal",
\t\tcruz_c + frente * -0.08, Vector3(0.5, 2.5, 0.2), trim, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''

assert old_cruz_tail in t, "cruz tail missing"
t = t.replace(old_cruz_tail, new_cruz_tail, 1)

# Also punch quoin fronts with a thin dark metal edge toward camera for silhueta break
old_quoin = '''\t\t\tKitModular.caixa_cor(sup, &"tijolo",
\t\t\t\tcentro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.14)
\t\t\t\t\t+ Vector3(0.0, yk, 0.0),
\t\t\t\tVector3(1.15, alt_q, 0.78), cor_q, giro,
\t\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''
new_quoin = '''\t\t\tKitModular.caixa_cor(sup, &"tijolo",
\t\t\t\tcentro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.14)
\t\t\t\t\t+ Vector3(0.0, yk, 0.0),
\t\t\t\tVector3(1.15, alt_q, 0.78), cor_q, giro,
\t\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t\t\t# Face escura no quoin (quebra a silhueta lavada).
\t\t\tKitModular.caixa_cor(sup, &"metal",
\t\t\t\tcentro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.52)
\t\t\t\t\t+ Vector3(0.0, yk, 0.0),
\t\t\t\tVector3(1.05, alt_q * 0.92, 0.1), trim if (k % 2) == 1 else Color("2a2018"), giro,
\t\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''
assert old_quoin in t, "quoin missing"
t = t.replace(old_quoin, new_quoin, 1)

kit.write_text(t, encoding="utf-8")
print("kit v5 OK")

p = pb.read_text(encoding="utf-8")
# Nudge church 1.5m south (toward pin) so facade ~9m instead of ~10.5m under denso.
old = "var igreja := Vector2(centro_q.x, centro_q.y - 4.5) + desloc"
new = "var igreja := Vector2(centro_q.x, centro_q.y - 3.0) + desloc"
assert old in p, "igreja line missing: " + repr([line for line in p.splitlines() if 'igreja :=' in line][:3])
p = p.replace(old, new, 1)
# Update comment distances if present
p = p.replace(
    "igreja = centro + (0, -4.5) -> ~ (271, -54.75) // fachada ~10.5 m, limpa no FOV",
    "igreja = centro + (0, -3.0) -> ~ (271, -53.25) // fachada ~9 m sob denso (Cine2)",
    1,
)
pb.write_text(p, encoding="utf-8")
print("builder church nudge OK")
assert "janela_acesa" in kit.read_text(encoding="utf-8")
print("done")

# -*- coding: utf-8 -*-
"""v6: freestanding portal ombreira toward camera + deeper black door recess."""
from pathlib import Path

kit = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
t = kit.read_text(encoding="utf-8")

# Replace the whole door/ombreira/arco/travessa block with portal-forward version.
start = t.find("\t# Porta em arco: ombreira clara + folha escura + arco em degraus.")
end = t.find("\tfor sx: float in [-1.0, 1.0]:\n\t\tKitModular.caixa_cor(sup, &\"janela_apagada\",")
assert start > 0 and end > start, (start, end)

new_door = r'''	# Porta em arco: PORTAL freestanding +1.4 m a frente da nave.
	# No fog=denso a 480x270 o albedo na parede some; o marco mais perto do
	# pin (menos nevoa) + buraco preto atras e o que ainda le. janela_acesa
	# no rim = mesmo truque do globo do poste_lanterna.
	var porta_parede := centro + frente * (fundura * 0.5 + 0.06) + Vector3(0.0, 1.85, 0.0)
	var porta_c := porta_parede + frente * 1.4
	# Folha preta ENCAIXADA na parede (fundo do portal).
	KitModular.caixa_cor(sup, &"porta", porta_parede, Vector3(2.6, 4.0, 0.35), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"porta",
		porta_parede + Vector3(0.0, 1.9, 0.0), Vector3(2.4, 0.9, 0.3), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Portal / ombreira — branco grosso, protruso, jambas.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 0.1, 0.0), Vector3(3.6, 4.5, 0.7), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			porta_c + lado * (1.65 * sx) + Vector3(0.0, 0.05, 0.0),
			Vector3(0.65, 4.4, 0.95), ombreira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Vao interno do portal (preto) — o buraco que o 480 resolve.
	KitModular.caixa_cor(sup, &"porta",
		porta_c + frente * -0.15, Vector3(2.35, 3.85, 0.55), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Arco em degraus no portal.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.15, 0.1), Vector3(2.9, 0.55, 0.55), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.55, 0.1), Vector3(2.2, 0.42, 0.55), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.88, 0.1), Vector3(1.35, 0.35, 0.55), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Rim emissivo (kit trick do poste).
	KitModular.caixa(sup, &"janela_acesa",
		porta_c + frente * 0.38 + Vector3(0.0, 0.1, 0.0),
		Vector3(3.7, 4.6, 0.12), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"janela_acesa",
		porta_c + frente * 0.38 + Vector3(0.0, 2.4, 0.0),
		Vector3(2.6, 0.5, 0.12), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Travessa.
	KitModular.caixa_cor(sup, &"metal",
		porta_parede + Vector3(0.0, 0.0, 0.2), Vector3(0.14, 3.6, 0.1), Color("1a1a18"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

'''

t = t[:start] + new_door + t[end:]
kit.write_text(t, encoding="utf-8")
print("kit v6 portal OK")

# Nudge church another 1.5m south + add two lanternas flanking door
p = pb.read_text(encoding="utf-8")
old = "var igreja := Vector2(centro_q.x, centro_q.y - 3.0) + desloc"
new = "var igreja := Vector2(centro_q.x, centro_q.y - 1.5) + desloc"
assert old in p, "igreja line"
p = p.replace(old, new, 1)
p = p.replace(
    "igreja = centro + (0, -3.0) -> ~ (271, -53.25) // fachada ~9 m sob denso (Cine2)",
    "igreja = centro + (0, -1.5) -> ~ (271, -51.75) // fachada ~7.5 m + portal +1.4 m",
    1,
)
# Update proibido igreja rect
p = p.replace(
    "Rect2(centro.x - 8.0, centro.y - 4.5 - 5.0, 16.0, 12.0),",
    "Rect2(centro.x - 8.0, centro.y - 1.5 - 6.0, 16.0, 14.0),",
    1,
)

# Add two lanternas flanking church door (south face), after igreja spawn
anchor = """\tif _neste_chunk(igreja):
\t\tKitParque.igreja_matriz(sup, colisao,
\t\t\tVector3(igreja.x, y, igreja.y), 0.0)
"""
# Actually lamps go in mobiliario via props — add to _mobiliario_praca_matriz postes list
# Church door ~ igreja + (0, + fundura/2) in local = south. With igreja at centro+(0,-1.5),
# facade ~ centro.y -1.5 + 4.2 = centro.y + 2.7... wait fundura is Z extent.
# frente +Z: facade at igreja.y + fundura*0.5 = (centro.y-1.5)+4.2 = centro.y+2.7
# That would put facade SOUTH of centro — pin at -40 looking north toward church at -51.75.
# mundo: centro ~ -50.25, igreja z = -50.25-1.5 = -51.75
# facade at igreja + fundura*0.5 in +Z = -51.75+4.2 = -47.55
# portal +1.4 = -46.15
# pin -40, look -51. Distance to portal ~6.15m. Good!

# Add flanking lamps just south of facade
old_postes = """\tpostes.append(Vector2(centro.x - 7.0, centro.y - 8.0))
\tpostes.append(Vector2(centro.x + 7.0, centro.y - 8.0))"""
new_postes = """\t# Lanternas flanqueando a porta (sul da fachada) — iluminam ombreira no denso.
\tpostes.append(Vector2(centro.x - 3.2, centro.y - 1.5 + 5.6))
\tpostes.append(Vector2(centro.x + 3.2, centro.y - 1.5 + 5.6))
\tpostes.append(Vector2(centro.x - 7.0, centro.y - 8.0))
\tpostes.append(Vector2(centro.x + 7.0, centro.y - 8.0))"""
assert old_postes in p
p = p.replace(old_postes, new_postes, 1)

# Boost energy for those — actually all postes use same energia 5.4. Bump slightly.
p = p.replace(
    '"cor": Color("ffd078"), "energia": 5.4, "alcance": 14.0,',
    '"cor": Color("ffe0a0"), "energia": 7.2, "alcance": 16.0,',
    1,
)

pb.write_text(p, encoding="utf-8")
print("builder v6 OK")
print("done")

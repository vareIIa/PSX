# -*- coding: utf-8 -*-
"""v8: ombreira as hollow frame (not solid slab)."""
from pathlib import Path
kit = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
t = kit.read_text(encoding="utf-8")

start = t.find("\t# Porta em arco: PORTAL freestanding +1.4 m a frente da nave.")
end = t.find("\tfor sx: float in [-1.0, 1.0]:\n\t\tKitModular.caixa_cor(sup, &\"janela_apagada\",")
assert start > 0 and end > start, (start, end)

new_door = r'''	# Porta em arco: PORTAL freestanding +1.4 m a frente da nave.
	# Marco OCO (jambas+lintel+soleira) + buraco preto — slab cheio tapava a
	# porta. Rim janela_acesa = truque do poste_lanterna, so na borda.
	var porta_parede := centro + frente * (fundura * 0.5 + 0.06) + Vector3(0.0, 1.85, 0.0)
	var porta_c := porta_parede + frente * 1.4
	# Folha preta na parede (fundo).
	KitModular.caixa_cor(sup, &"porta", porta_parede, Vector3(2.7, 4.1, 0.4), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"porta",
		porta_parede + Vector3(0.0, 1.95, 0.0), Vector3(2.5, 1.0, 0.35), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Buraco preto no plano do portal (le como vao).
	KitModular.caixa_cor(sup, &"porta",
		porta_c + frente * -0.05, Vector3(2.4, 3.9, 0.35), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Ombreira OCA: jambas + lintel + soleira (branco).
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			porta_c + lado * (1.55 * sx) + Vector3(0.0, 0.05, 0.0),
			Vector3(0.7, 4.5, 0.85), ombreira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.2, 0.0), Vector3(3.5, 0.55, 0.85), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)  # lintel
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, -1.95, 0.0), Vector3(3.5, 0.4, 0.85), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)  # soleira
	# Arco em degraus no lintel.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.55, 0.05), Vector3(2.6, 0.4, 0.7), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.85, 0.05), Vector3(1.7, 0.32, 0.7), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 3.1, 0.05), Vector3(1.0, 0.28, 0.7), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Rim emissivo oco (poste trick).
	var rim_z := porta_c + frente * 0.45
	KitModular.caixa(sup, &"janela_acesa",
		rim_z + Vector3(0.0, 2.2, 0.0), Vector3(3.6, 0.3, 0.14), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"janela_acesa",
		rim_z + Vector3(0.0, -1.95, 0.0), Vector3(3.6, 0.24, 0.14), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa(sup, &"janela_acesa",
			rim_z + lado * (1.7 * sx) + Vector3(0.0, 0.1, 0.0),
			Vector3(0.3, 4.4, 0.14), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Travessa na folha.
	KitModular.caixa_cor(sup, &"metal",
		porta_parede + Vector3(0.0, 0.0, 0.22), Vector3(0.14, 3.7, 0.1), Color("1a1a18"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

'''

t = t[:start] + new_door + t[end:]
kit.write_text(t, encoding="utf-8")
print("v8 hollow ombreira OK")
assert "Ombreira OCA" in kit.read_text(encoding="utf-8")

from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")

# Insert arched outer faces after the fender caixas / chrome block, before cabin.
# Find the marker: "# Cabine alinhada ao _vidros"
marker = "\t# Cabine alinhada ao _vidros (P0)."
if marker not in text:
    raise SystemExit("cabin marker missing")

arch = r'''	# Arco lateral dos para-lamas (3 placas inclinadas = semicirculo PSX).
	# Sem isso o lado le como caixa com mancha marrom; com isso o perfil sobe
	# e desce sobre a roda como nas refs.
	for s: float in [1.0, -1.0]:
		var sx2 := s * (larg * 0.54 + 0.01)
		var basis_lado := Basis(Vector3.UP, s * PI * 0.5)
		for z_arco: float in [comp * 0.28, -comp * 0.28]:
			# Base vertical do arco.
			_face(dados, Vector2(0.36, altura_casco * 0.50),
				Transform3D(basis_lado, Vector3(sx2, ASSOALHO + altura_casco * 0.40, z_arco)),
				cor, suja)
			# Ombro superior inclinado para fora (bulbo).
			_face(dados, Vector2(0.30, altura_casco * 0.28),
				Transform3D(basis_lado * Basis(Vector3.RIGHT, -0.55),
					Vector3(sx2 + s * 0.02, ASSOALHO + altura_casco * 0.72, z_arco)),
				cor, suja)
			# Tampo do arco (quase horizontal).
			_face(dados, Vector2(0.28, 0.18),
				Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
					Vector3(s * (larg * 0.52), ASSOALHO + altura_casco * 0.92, z_arco)),
				cor, C_CAPO)

'''

text = text.replace(marker, arch + marker, 1)
path.write_text(text, encoding="utf-8")
print("arch faces added", path.stat().st_size)

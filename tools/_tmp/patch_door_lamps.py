# -*- coding: utf-8 -*-
from pathlib import Path
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
p = pb.read_text(encoding="utf-8")

# Place door-flank lamps AFTER the proibido loop, dedicated, so they always spawn.
old = """\tfor p0: Vector2 in postes:
\t\tif _dentro_de(proibido, p0):
\t\t\tcontinue
\t\tvar local := p0 + desloc
\t\tif not _neste_chunk(local):
\t\t\tcontinue
\t\tindice += 1
\t\tvar luz := KitParque.poste_lanterna(sup, colisao,
\t\t\tVector3(local.x, KitModular.ALTURA_MEIO_FIO, local.y))
\t\tprops.append({
\t\t\t"tipo": "lampada",
\t\t\t"pos": luz,
\t\t\t"padrao": Lampada.Padrao.ESTAVEL,
\t\t\t"semente": sem + indice * 97,
\t\t\t"cor": Color("ffe0a0"), "energia": 7.2, "alcance": 16.0,
\t\t\t"facho": true,
\t\t})
"""

# Remove the door-flank from postes list (they hit proibido) and spawn dedicated after loop
p2 = p.replace(
"""\t# Lanternas flanqueando a porta (sul da fachada) — iluminam ombreira no denso.
\tpostes.append(Vector2(centro.x - 3.2, centro.y - 1.5 + 5.6))
\tpostes.append(Vector2(centro.x + 3.2, centro.y - 1.5 + 5.6))
\tpostes.append(Vector2(centro.x - 7.0, centro.y - 8.0))
""",
"""\tpostes.append(Vector2(centro.x - 7.0, centro.y - 8.0))
""")
assert p2 != p, "postes list replace failed"
p = p2

# Insert dedicated door lamps after the postes for-loop's first bank spawn block —
# find the banco section start and prepend door lamps before bancos.
marker = "\t\t# Banco perto do poste, virado para o centro."
door_lamps = """\t# Lanternas da porta: fora do teste proibido (ficam na zona da igreja de proposito).
\tfor sx: float in [-1.0, 1.0]:
\t\tvar pd := Vector2(centro.x + 3.4 * sx, centro.y - 1.5 + 5.8)
\t\tvar ld := pd + desloc
\t\tif not _neste_chunk(ld):
\t\t\tcontinue
\t\tindice += 1
\t\tvar luz_p := KitParque.poste_lanterna(sup, colisao,
\t\t\tVector3(ld.x, KitModular.ALTURA_MEIO_FIO, ld.y))
\t\tprops.append({
\t\t\t"tipo": "lampada",
\t\t\t"pos": luz_p,
\t\t\t"padrao": Lampada.Padrao.ESTAVEL,
\t\t\t"semente": sem + indice * 97,
\t\t\t"cor": Color("ffe8b0"), "energia": 8.5, "alcance": 12.0,
\t\t\t"facho": true,
\t\t})

"""
# Actually insert AFTER the for p0 loop entirely. Find unique end of loop via banco comment first occurrence inside loop - better: after all postes processed.

# Simpler: insert right before "# Banco perto" is wrong (inside loop). Insert after the for loop.
# Find the for loop end by looking at structure after postes for-loop.

idx = p.find("\tfor p0: Vector2 in postes:")
assert idx > 0
# Find next function-level comment after this for — the banco is inside. Look for end of for by indentation of next top-level in function.
# After loop there's no explicit end; banco is inside. Read file structure...

# Actually looking at original: banco is INSIDE the for p0 loop. So after the whole for loop comes more code or end of func.
# Search for end of function _mobiliario_praca_matriz

end_fn = p.find("\nstatic func ", p.find("static func _mobiliario_praca_matriz"))
# Insert door lamps just before end of this function (before last content)
# Find last occurrence of KitParque.banco in this function and insert after the for loop.

# Easiest reliable patch: append door lamp block right after postes array is built and BEFORE the for loop, with its own for that ignores proibido.
insert_at = p.find("\tfor p0: Vector2 in postes:")
assert insert_at > 0
block = """\t# Lanternas da porta (ignoram proibido — iluminam ombreira no denso).
\tfor sx: float in [-1.0, 1.0]:
\t\tvar pd := Vector2(centro.x + 3.4 * sx, centro.y - 1.5 + 5.8)
\t\tvar ld := pd + desloc
\t\tif not _neste_chunk(ld):
\t\t\tcontinue
\t\tindice += 1
\t\tvar luz_p := KitParque.poste_lanterna(sup, colisao,
\t\t\tVector3(ld.x, KitModular.ALTURA_MEIO_FIO, ld.y))
\t\tprops.append({
\t\t\t"tipo": "lampada",
\t\t\t"pos": luz_p,
\t\t\t"padrao": Lampada.Padrao.ESTAVEL,
\t\t\t"semente": sem + indice * 97,
\t\t\t"cor": Color("ffe8b0"), "energia": 8.5, "alcance": 12.0,
\t\t\t"facho": true,
\t\t})
"""
p = p[:insert_at] + block + p[insert_at:]
pb.write_text(p, encoding="utf-8")
assert "Lanternas da porta" in pb.read_text(encoding="utf-8")
print("door lamps fixed OK")

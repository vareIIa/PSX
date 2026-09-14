from pathlib import Path

path = Path(r"game/src/world/kit_parque.gd")
text = path.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)

backup = Path(r"captures/praca_matriz/_sessao_praca_visual/kit_parque_coreto_before_newbot.gdfrag")
backup.write_text("".join(lines[858:997]), encoding="utf-8")

start = None
end = None
for i, line in enumerate(lines):
    if start is None and i >= 940 and line.startswith("\t# Telhado octogonal"):
        start = i
    if start is not None and (
        's": centro + Vector3(0.0, y_piso * 0.5, 0.0)})' in line
        or (line.strip().startswith("colisao.append") and "y_piso" in line and i > start)
    ):
        end = i
        break

if start is None or end is None:
    raise SystemExit(f"span not found start={start} end={end}")

new_block = """\t# Telhado octogonal (ref 01/03): 8 TRIANGULOS apex->beiral, SEM caixa inclinada.
\t# Caixa_livre com espessura no perfil lia V/borboleta (aresta fina = vale).
\t# Face aparece do LADO OPOSTO ao cross: winding com cross.y < 0, normal = -cross
\t# (pra luz olhar pra cima). Borda = so angulo — mesma formula em vizinhos.
\tvar y_beiral := y_piso + alt_pilar + 0.08
\tvar eave_r := raio * 1.28
\tvar roof_h := 3.25
\tvar apex := centro + Vector3(0.0, y_beiral + roof_h, 0.0)
\t# Beiral + forro: volume sob a agua, fora da silhueta /\\ .
\tKitModular.caixa_cor(sup, &\"teto\", centro + Vector3(0.0, y_beiral + 0.02, 0.0),
\t\tVector3(eave_r * 2.12, 0.14, eave_r * 2.12), telha_escura, PI / 8.0,
\t\tPSXMesh.FACE_TODAS, 1.35)
\tKitModular.caixa_cor(sup, &\"tabua\", centro + Vector3(0.0, y_beiral - 0.08, 0.0),
\t\tVector3(raio * 1.7, 0.1, raio * 1.7), madeira, PI / 8.0,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tif not sup.has(&\"teto\"):
\t\tsup[&\"teto\"] = PSXMesh.dados_vazios()
\tvar teto_dados: Dictionary = sup[&\"teto\"]
\tfor i in 8:
\t\tvar ang0 := TAU * float(i) / 8.0 + PI / 8.0
\t\tvar ang1 := TAU * float(i + 1) / 8.0 + PI / 8.0
\t\tvar p0 := Vector3(centro.x + cos(ang0) * eave_r, y_beiral,
\t\t\tcentro.z + sin(ang0) * eave_r)
\t\tvar p1 := Vector3(centro.x + cos(ang1) * eave_r, y_beiral,
\t\t\tcentro.z + sin(ang1) * eave_r)
\t\t# Queremos face de cima: cross (a-apex)x(b-apex) com y < 0, normal = -cross.
\t\tvar a := p0
\t\tvar b := p1
\t\tvar cruz := (a - apex).cross(b - apex)
\t\tif cruz.y > 0.0:
\t\t\ta = p1
\t\t\tb = p0
\t\t\tcruz = (a - apex).cross(b - apex)
\t\tif cruz.length_squared() < 1e-8:
\t\t\tcontinue
\t\tvar n_luz := (-cruz).normalized()
\t\tvar cor_face := telha if (i % 2) == 0 else telha_escura
\t\tvar fonte := PSXMesh.dados_vazios()
\t\tvar fv: PackedVector3Array = fonte[\"v\"]
\t\tvar fn: PackedVector3Array = fonte[\"n\"]
\t\tvar fuv: PackedVector2Array = fonte[\"uv\"]
\t\tvar fc: PackedColorArray = fonte[\"c\"]
\t\tvar fi: PackedInt32Array = fonte[\"i\"]
\t\tfv.append(apex)
\t\tfv.append(a)
\t\tfv.append(b)
\t\tfn.append(n_luz)
\t\tfn.append(n_luz)
\t\tfn.append(n_luz)
\t\tfuv.append(Vector2(0.5, 0.0))
\t\tfuv.append(Vector2(0.0, 1.0))
\t\tfuv.append(Vector2(1.0, 1.0))
\t\tfc.append(cor_face)
\t\tfc.append(cor_face)
\t\tfc.append(cor_face)
\t\tfi.append(0)
\t\tfi.append(1)
\t\tfi.append(2)
\t\tfonte[\"v\"] = fv
\t\tfonte[\"n\"] = fn
\t\tfonte[\"uv\"] = fuv
\t\tfonte[\"c\"] = fc
\t\tfonte[\"i\"] = fi
\t\tPSXMesh.acumular(teto_dados, fonte, Transform3D.IDENTITY)
\t# Pico curto — fecha a ponta sem engolir as aguas.
\tKitModular.caixa_cor(sup, &\"teto\",
\t\tcentro + Vector3(0.0, y_beiral + roof_h - 0.05, 0.0),
\t\tVector3(0.35, 0.4, 0.35), telha, PI / 8.0,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Lanterna sob o teto (ref 03 — ponto amarelo no centro).
\tKitModular.caixa_cor(sup, &\"metal\",
\t\tcentro + Vector3(0.0, y_beiral + 0.45, 0.0),
\t\tVector3(0.14, 0.22, 0.14), Color(\"e8c040\"), 0.0,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)

\tcolisao.append({\"tamanho\": Vector3(raio * 2.1, y_piso + 0.2, raio * 2.1),
\t\t\"pos\": centro + Vector3(0.0, y_piso * 0.5, 0.0)})
""".splitlines(keepends=True)

hdr_start = None
for i in range(850, 870):
    if lines[i].startswith("## Coreto octogonal"):
        hdr_start = i
        break
if hdr_start is not None:
    hdr_end = hdr_start
    while hdr_end < len(lines) and not lines[hdr_end].startswith("static func coreto"):
        hdr_end += 1
    new_hdr = [
        "## Coreto octogonal da praca: base de pedra, escada, oito pilares de madeira,\n",
        "## guarda-corpo e telhado de telha. E o marco central da Praca da Matriz.\n",
        "##\n",
        "## Telhado = 8 triangulos (apex -> beiral). Caixa inclinada lia V/borboleta\n",
        "## no perfil; face sem espessura fecha a silhueta /\\ das refs 01/03.\n",
        "## A escada de pedra com peitoril faz a base ler como podium.\n",
    ]
    lines = lines[:hdr_start] + new_hdr + lines[hdr_end:]
    delta = len(new_hdr) - (hdr_end - hdr_start)
    start += delta
    end += delta

new_lines = lines[:start] + new_block + lines[end + 1:]
path.write_text("".join(new_lines), encoding="utf-8")
print(f"Replaced lines {start+1}-{end+1} with {len(new_block)} lines")

out = path.read_text(encoding="utf-8").splitlines()
bad = [(i + 1, l) for i, l in enumerate(out) if 's": centro + Vector3(0.0, y_piso' in l]
print("corrupt remnants:", bad)
for i, line in enumerate(out):
    if "static func coreto(" in line:
        print("coreto at", i + 1)
    if "static func igreja_matriz(" in line:
        print("igreja at", i + 1)
        for j in range(max(0, i - 12), i):
            print(f"{j+1}|{out[j]}")
        break

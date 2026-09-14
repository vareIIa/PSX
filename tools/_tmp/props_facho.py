from pathlib import Path

# Pull house into headlight cone + add guaranteed props at capture s
eb = Path(r"game\src\world\estrada_builder.gd")
t = eb.read_text(encoding="utf-8")

# Closer house
old = """\t\tvar d := KitEstrada.MEIA_PISTA + 3.4
\t\tvar base := ponto_em(s) + lado_em(s) * d
\t\tbase.y += altura_lateral(d)
\t\tvar giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
\t\tKitEstrada.casa_beira(sup, base, giro, rng)"""

new = """\t\tvar d := KitEstrada.MEIA_PISTA + 1.85
\t\tvar base := ponto_em(s) + lado_em(s) * d
\t\tbase.y += altura_lateral(d)
\t\tvar giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
\t\tKitEstrada.casa_beira(sup, base, giro, rng)"""

if old not in t:
    print("house block miss")
else:
    t = t.replace(old, new)
    print("house closer")

# Capture-distance house: s0+10 -> s0+8 for ancora
t2 = t.replace(
    "var s := s0 + (10.0 if ancora_captura else rng.randf_range(4.0, TRECHO - 6.0))",
    "var s := s0 + (8.0 if ancora_captura else rng.randf_range(4.0, TRECHO - 6.0))",
)
if t2 == t:
    print("s offset unchanged or miss")
else:
    t = t2
    print("s offset 8")

# Add guarantee method after spawn_olhos
if "func garantir_props_facho" not in t:
    extra = r'''

## Garante casa + cerca + muro no cone do farol na distancia de captura.
## Nao depende de RNG do trecho: o facho sempre tem sujeito (ref 04).
func garantir_props_facho(s_carro: float) -> void:
	var velho := get_node_or_null("PropsFacho")
	if velho != null:
		velho.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(semente * 17 + int(s_carro) * 31)
	var sup: Dictionary = {}
	var s := s_carro + 11.0
	# Casa a direita, rente a beira.
	var d_casa := KitEstrada.MEIA_PISTA + 1.7
	var base := ponto_em(s) + lado_em(s) * d_casa
	base.y += altura_lateral(d_casa)
	var giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
	KitEstrada.casa_beira(sup, base, giro, rng)
	# Cerca a direita, logo a frente.
	var d_c := (KitEstrada.MEIA_PISTA + 1.35)
	var a := ponto_em(s - 2.0) + lado_em(s - 2.0) * d_c
	var b := ponto_em(s + 10.0) + lado_em(s + 10.0) * d_c
	a.y += altura_lateral(d_c)
	b.y += altura_lateral(d_c)
	KitEstrada.cerca(sup, a, b, rng)
	# Muro baixo a esquerda.
	var d_m := -(KitEstrada.MEIA_PISTA + 0.95)
	var m0 := ponto_em(s - 1.0) + lado_em(s - 1.0) * d_m
	var m1 := ponto_em(s + 7.0) + lado_em(s + 7.0) * d_m
	m0.y += altura_lateral(absf(d_m))
	m1.y += altura_lateral(absf(d_m))
	KitEstrada.muro_baixo(sup, m0, m1, rng)
	# Cipós sobre a pista no cone.
	for i in 3:
		var sc := s_carro + 4.0 + float(i) * 3.5
		var lado := 1.0 if i % 2 == 0 else -1.0
		var ancora := ponto_em(sc) + lado_em(sc) * (lado * 4.2)
		ancora.y += altura_lateral(4.2) + 4.5
		var sobre := ponto_em(sc) + Vector3(0.0, 3.2, 0.0)
		KitEstrada.cipo(sup, ancora, sobre, rng)
	# Brush densificado no pe da casa.
	for i in 10:
		var sb := s_carro + rng.randf_range(3.0, 16.0)
		var lado := 1.0 if rng.randf() < 0.55 else -1.0
		var d := rng.randf_range(KitEstrada.MEIA_PISTA - 0.2, KitEstrada.MEIA_PISTA + 1.4)
		var p := ponto_em(sb) + lado_em(sb) * (d * lado)
		p.y += altura_lateral(d)
		KitEstrada.tufo(sup, p,
			[KitEstrada.C_CAPIM, KitEstrada.C_SAMAMBAIA, KitEstrada.C_MOITA_BAIXA,
				KitEstrada.C_FOLHA_LARGA][rng.randi() % 4],
			rng.randf_range(0.7, 1.45), rng.randf_range(0.0, TAU),
			Color(0.85, 0.9, 0.7))
	var no := Node3D.new()
	no.name = "PropsFacho"
	var tris := 0
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mi)
		tris += PSXMesh.dados_triangulos(d)
	no.set_meta(&"triangulos", tris)
	triangulos += tris
	add_child(no)
'''
    t = t.rstrip() + "\n" + extra + "\n"
    print("added garantir_props_facho")

eb.write_text(t, encoding="utf-8")

# Hook in abertura capture hold
ab = Path(r"game\src\levels\abertura_estrada.gd")
a = ab.read_text(encoding="utf-8")
needle = '''\tif _clima_id() == "noite":
\t\t_estrada.spawn_olhos_nevoa(_carro.distancia, 24.0)
'''
ins = '''\tif _clima_id() == "noite":
\t\t_estrada.spawn_olhos_nevoa(_carro.distancia, 24.0)
\t\t_estrada.garantir_props_facho(_carro.distancia)
'''
if needle not in a:
    print("abertura needle miss")
elif "garantir_props_facho" in a:
    print("abertura already hooked")
else:
    ab.write_text(a.replace(needle, ins), encoding="utf-8")
    print("abertura hooked")

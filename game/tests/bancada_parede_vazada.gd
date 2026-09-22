## Bancada da ParedeVazada: a fachada com vao de verdade nao pode ter fresta.
##
##   godot --headless --path game --script res://tests/bancada_parede_vazada.gd
##
## Tres reguas, nas quatro direcoes de fachada (nas impares com faixas):
##   1. Raio: de 6 m na frente, em angulos de ate 75 graus, contra pontos da
##      fachada (parede e vaos). Todo raio tem de bater num triangulo VISIVEL
##      (de frente para quem olha) antes de passar 0,6 m atras do plano. Com a
##      tampa ligada, nem pelo vao se ve o vazio.
##   2. Junta em T: nenhum vertice da malha cai no meio da aresta de outro
##      triangulo. E a fresta de um pixel que pisca o limbo.
##   3. Controle positivo: sem um triangulo de parede, a regua 1 tem de acusar.
extends SceneTree

var _falhas: Array[String] = []


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var PV: GDScript = load("res://src/world/parede_vazada.gd")
	var total_tris := 0
	for direcao in 4:
		var sup := {}
		var base := Vector3(3.0, 0.0, -2.0)
		var vaos := [
			{"rect": Rect2(-3.2, 0.0, 1.1, 2.3)},                  # porta
			{"rect": Rect2(-1.4, 1.0, 1.2, 1.5), "prof": 0.3},     # janela funda
			{"rect": Rect2(0.6, 0.9, 1.3, 1.9), "arco": 0.35},     # arco abatido
			{"rect": Rect2(2.4, 1.1, 0.9, 1.2), "prof": 0.12},
			{"rect": Rect2(-1.0, 4.0, 2.0, 1.6), "arco": 0.3},     # segundo andar
			{"rect": Rect2(1.9, 4.1, 1.0, 1.4)},
		]
		# Nas direcoes impares, com banda: barrado pintado e andar de tijolo.
		var faixas := [] if direcao % 2 == 0 else [
			{"y0": 0.0, "y1": 0.95, "cor": Color(0.5, 0.45, 0.4)},
			{"y0": 3.0, "y1": 6.0, "cor": Color.WHITE, "material": &"tijolo"}]
		var quadros: Array = PV.erguer(sup, &"reboco", base, 8.0, 6.0, direcao,
			Color(0.9, 0.85, 0.7), vaos, faixas)
		_conferir(quadros.size() == vaos.size(),
			"direcao %d: %d de %d vaos voltaram" % [direcao, quadros.size(), vaos.size()])
		var tris := _triangulos(sup)
		total_tris += tris.size() / 3
		var normal := KitModular._normal(direcao)
		var lateral := KitModular._lateral(direcao)
		var furos := _varrer(tris, base, normal, lateral, 8.0, 6.0, direcao)
		_conferir(furos == 0, "direcao %d: %d raios passaram para o vazio" % [direcao, furos])
		var juntas := _juntas_em_t(sup)
		_conferir(juntas == 0, "direcao %d: %d juntas em T" % [direcao, juntas])
		if direcao == 0:
			# Controle: tira o primeiro triangulo de parede (canto de baixo).
			var sem := tris.slice(3)
			var furos_controle := _varrer(sem, base, normal, lateral, 8.0, 6.0, direcao)
			_conferir(furos_controle > 0,
				"controle positivo: sem um triangulo a regua nao viu furo")
			print("[parede_vazada] controle: %d raios pelo furo montado" % furos_controle)
	print("[parede_vazada] %d triangulos por fachada de 8x6 m com 6 vaos" % (total_tris / 4))
	if _falhas.is_empty():
		print("OK — parede vazada sem fresta nas 4 direcoes")
	else:
		print("FALHOU")
		for f in _falhas:
			print("  x ", f)
	quit(0 if _falhas.is_empty() else 1)


func _conferir(ok: bool, msg: String) -> void:
	if not ok:
		_falhas.append(msg)


## Todos os triangulos de todos os materiais, em mundo: [a, b, c, a, b, c...].
func _triangulos(sup: Dictionary) -> Array[Vector3]:
	var saida: Array[Vector3] = []
	for mat: StringName in sup:
		var v: PackedVector3Array = sup[mat]["v"]
		var idx: PackedInt32Array = sup[mat]["i"]
		for k in idx.size():
			saida.append(v[idx[k]])
	return saida


func _varrer(tris: Array[Vector3], base: Vector3, normal: Vector3, lateral: Vector3,
		largura: float, altura: float, _direcao: int) -> int:
	var furos := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for amostra in 1500:
		var alvo := base + lateral * rng.randf_range(-largura * 0.5 + 0.02, largura * 0.5 - 0.02) \
			+ Vector3(0.0, rng.randf_range(0.02, altura - 0.02), 0.0)
		var ang_h := rng.randf_range(-1.3, 1.3)
		var ang_v := rng.randf_range(-0.9, 0.9)
		var dir_fora := (normal * cos(ang_h) + lateral * sin(ang_h)) * cos(ang_v) \
			+ Vector3.UP * sin(ang_v)
		var origem := alvo + dir_fora.normalized() * 6.0
		var dir := (alvo - origem).normalized()
		# Ate onde o raio vai: 0,6 m atras do plano da fachada.
		var d_plano := (alvo - origem).length()
		var alcance := d_plano + 0.6 / maxf(-dir.dot(normal), 0.05)
		var melhor := INF
		var visivel := false
		for k in range(0, tris.size(), 3):
			var t := _raio_triangulo(origem, dir, tris[k], tris[k + 1], tris[k + 2])
			if t <= 0.0 or t >= melhor:
				continue
			# Face visivel: do lado oposto ao produto vetorial. A de costas o
			# cull_back descarta e o olho ve o que esta atras dela — entao ela
			# nao conta, como no desenho.
			var n_vis := -(tris[k + 1] - tris[k]).cross(tris[k + 2] - tris[k])
			if n_vis.dot(dir) < 0.0:
				melhor = t
				visivel = true
		if melhor > alcance or not visivel:
			furos += 1
			if OS.get_cmdline_user_args().has("--detalhe") and tris.size() % 3 == 0 and furos <= 6:
				print("  furo: alvo %s de %s (%s)" % [alvo, origem, "atras" if not visivel else "vazio"])
	return furos


## Moller-Trumbore, dos dois lados, com a aresta incluida.
func _raio_triangulo(o: Vector3, d: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var e1 := b - a
	var e2 := c - a
	var p := d.cross(e2)
	var det := e1.dot(p)
	if absf(det) < 1e-12:
		return -1.0
	var inv := 1.0 / det
	var s := o - a
	var u := s.dot(p) * inv
	if u < -1e-6 or u > 1.0 + 1e-6:
		return -1.0
	var q := s.cross(e1)
	var v := d.dot(q) * inv
	if v < -1e-6 or u + v > 1.0 + 1e-6:
		return -1.0
	return e2.dot(q) * inv


## Vertice de qualquer material caindo estritamente dentro de uma aresta.
func _juntas_em_t(sup: Dictionary) -> int:
	var pontos: Array[Vector3] = []
	var arestas: Array = []
	for mat: StringName in sup:
		var v: PackedVector3Array = sup[mat]["v"]
		var idx: PackedInt32Array = sup[mat]["i"]
		for k in range(0, idx.size(), 3):
			for e in 3:
				arestas.append([v[idx[k + e]], v[idx[k + (e + 1) % 3]]])
		for p in v:
			pontos.append(p)
	var unicos := {}
	for p in pontos:
		unicos[Vector3i(roundi(p.x * 4096.0), roundi(p.y * 4096.0), roundi(p.z * 4096.0))] = p
	var juntas := 0
	for ar: Array in arestas:
		var a: Vector3 = ar[0]
		var b: Vector3 = ar[1]
		var ab := b - a
		var l2 := ab.length_squared()
		if l2 < 1e-8:
			continue
		for chave: Vector3i in unicos:
			var p: Vector3 = unicos[chave]
			var t := (p - a).dot(ab) / l2
			if t <= 0.001 or t >= 0.999:
				continue
			if (a + ab * t).distance_to(p) < 0.0005:
				juntas += 1
				if OS.get_cmdline_user_args().has("--detalhe"):
					print("  junta: ponto %s na aresta %s -> %s" % [p, a, b])
	return juntas

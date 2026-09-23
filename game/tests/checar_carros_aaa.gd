## Fase 1 e 2 do PLANO_CARROS_AAA: vidro de verdade, gente dentro, material por peca.
##
##     godot --headless --path game --script res://tests/checar_carros_aaa.gd
##
## Para os sete modelos, cobra:
##
##   A1  a malha `corpo` tem duas superficies: lataria (mat_carro) e vidro
##       (mat_carro_vidro), e a segunda so tem vertice de classe VIDRO
##   A2  atras do centro de cada abertura NAO ha lataria: um segmento que
##       atravessa o vidro de um lado ao outro nao toca a superficie 0, e toca a 1
##   A3  todo vertice do interior esta dentro do casco (largura e teto)
##   A4  a lataria tem pintura, cromo, plastico e espelho; nenhum vidro ficou nela
##   A5  os dois materiais nascem no psx_surface: o PS1 STYLE nao muda
##   A6  o casco pintado pelo cache (base preta + diferenca da branca) e o
##       MESMO casco montado direto na tinta, vertice a vertice
##
## Cada regua tem controle positivo: um caso montado para FALHAR, que precisa
## falhar. Sem isso "OK" pode querer dizer so que a regua nao enxerga.
extends SceneTree

const FOLGA_CASCO := 0.006


func _initialize() -> void:
	var falhas := 0
	falhas += _controles()
	falhas += _materiais()
	falhas += _tinta_do_cache()
	for modelo: int in Carroceria.Modelo.values():
		falhas += _checar(modelo)
	print("")
	if falhas == 0:
		print("=== OK: vidro com vao, interior contido, material por peca ===")
	else:
		print("=== FALHOU: %d criterio(s) ===" % falhas)
	quit(1 if falhas > 0 else 0)


func _controles() -> int:
	var falhas := 0
	var m := Carroceria.montar(Carroceria.Modelo.MAREA, Color.WHITE, 3)
	var corpo := m["corpo"] as ArrayMesh
	var casco := _triangulos(corpo, 0)
	# A2 controle: 35 cm abaixo do centro da janela da porta e chapa de porta.
	for a: Dictionary in m["aberturas"]:
		if a["tipo"] == &"parabrisa":
			continue
		var c: Vector3 = a["centro"] + Vector3(0.0, -0.35, 0.0)
		if not _cruza(casco, c, a["normal"]):
			print("[controle] A2 nao viu a porta abaixo de %s" % a["tipo"])
			falhas += 1
		break
	# A3 controle: um ponto 5 cm por fora da lateral tem de sair.
	var info: Dictionary = m["perfil_cabine"]
	var p := Vector3(_meia(info, 0.0, 0.8) + 0.05, 0.8, 0.0)
	if _dentro(info, p):
		print("[controle] A3 aceitou ponto fora do casco")
		falhas += 1
	print("[controle] %s" % ("ok" if falhas == 0 else "FALHOU"))
	return falhas


func _tinta_do_cache() -> int:
	var falhas := 0
	var pior := 0.0
	for modelo: int in [Carroceria.Modelo.SEDA, Carroceria.Modelo.PICAPE]:
		for k: int in [2, 5, 10]:
			var cor: Color = Carroceria.TINTAS[k]
			var direto: Dictionary = Carroceria._casco_em_dados(modelo, cor, false,
				true, true)
			var base: Dictionary = Carroceria._casco_base(modelo, false, true, true)
			for parte: String in ["lataria", "vidro"]:
				var a: PackedColorArray = (direto[parte] as Dictionary)["c"]
				var b: PackedColorArray = Carroceria._tingir(base[parte], cor)["c"]
				if a.size() != b.size():
					print("[A6] %s: %s com %d vertices direto e %d do cache"
						% [Carroceria.Modelo.keys()[modelo], parte, a.size(), b.size()])
					falhas += 1
					continue
				for q in a.size():
					pior = maxf(pior, maxf(absf(a[q].r - b[q].r),
						maxf(absf(a[q].g - b[q].g), absf(a[q].b - b[q].b))))
	if pior > 0.002:
		print("[A6] cor do cache difere da montagem direta em %.4f" % pior)
		falhas += 1
	print("[A6] %s (maior diferenca %.5f)" % ["ok" if falhas == 0 else "FALHOU", pior])
	return falhas


func _materiais() -> int:
	var falhas := 0
	for caminho: String in [Carroceria.MATERIAL, Carroceria.MATERIAL_VIDRO]:
		var mat := load(caminho) as ShaderMaterial
		var sh := "" if mat == null or mat.shader == null else mat.shader.resource_path
		if sh != "res://shaders/psx_surface.gdshader":
			print("[A5] %s nasce em %s" % [caminho, sh])
			falhas += 1
	print("[A5] %s" % ("ok" if falhas == 0 else "FALHOU"))
	return falhas


func _checar(modelo: int) -> int:
	var falhas := 0
	var m := Carroceria.montar(modelo, Carroceria.TINTAS[2], 11)
	var corpo := m["corpo"] as ArrayMesh
	var nome: String = Carroceria.Modelo.keys()[modelo]

	# A1
	if corpo.get_surface_count() != 2:
		print("[A1] %s: %d superficies" % [nome, corpo.get_surface_count()])
		return 1
	var m0 := corpo.surface_get_material(0)
	var m1 := corpo.surface_get_material(1)
	if m0 == null or m0.resource_path != Carroceria.MATERIAL \
			or m1 == null or m1.resource_path != Carroceria.MATERIAL_VIDRO:
		print("[A1] %s: materiais trocados" % nome)
		falhas += 1
	var classes0 := _classes(corpo, 0)
	var classes1 := _classes(corpo, 1)
	for c: int in classes1:
		if c != Carroceria.Classe.VIDRO:
			print("[A1] %s: vidro com classe %d" % [nome, c])
			falhas += 1

	# A2
	var casco := _triangulos(corpo, 0)
	var vidro := _triangulos(corpo, 1)
	var vaos := 0
	for a: Dictionary in m["aberturas"]:
		var c: Vector3 = a["centro"]
		var n: Vector3 = a["normal"]
		if _cruza(casco, c, n):
			print("[A2] %s: chapa atras de %s lado %d" % [nome, a["tipo"], a["lado"]])
			falhas += 1
		elif not _cruza(vidro, c, n):
			print("[A2] %s: sem vidro em %s lado %d" % [nome, a["tipo"], a["lado"]])
			falhas += 1
		else:
			vaos += 1

	# A3
	var info: Dictionary = m["perfil_cabine"]
	var interior := m["interior"] as ArrayMesh
	var fora := 0
	var pior := 0.0
	for s in interior.get_surface_count():
		for p: Vector3 in interior.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if not _dentro(info, p):
				fora += 1
				pior = maxf(pior, absf(p.x) - _meia(info, p.z, p.y))
	if fora > 0:
		print("[A3] %s: %d vertices do interior fora do casco (pior %.3f m)"
			% [nome, fora, pior])
		falhas += 1

	# A4
	for c: int in [Carroceria.Classe.PINTURA, Carroceria.Classe.CROMO,
			Carroceria.Classe.PLASTICO, Carroceria.Classe.ESPELHO]:
		if not classes0.has(c):
			print("[A4] %s: lataria sem classe %s" % [nome, Carroceria.Classe.keys()[c]])
			falhas += 1
	if classes0.has(Carroceria.Classe.VIDRO):
		print("[A4] %s: vidro ficou na lataria (%d vertices)"
			% [nome, int(classes0[Carroceria.Classe.VIDRO])])
		falhas += 1

	print("[%s] %s  vaos %d | tris lataria %d, vidro %d, interior %d | %s"
		% ["ok" if falhas == 0 else "FALHOU", nome.rpad(6), vaos,
			casco.size(), vidro.size(), _triangulos(interior, 0).size(),
			_resumo(classes0)])
	return falhas


## Contagem de vertices por classe numa superficie.
func _classes(malha: ArrayMesh, s: int) -> Dictionary:
	var out := {}
	var uv2: PackedVector2Array = malha.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV2]
	for u: Vector2 in uv2:
		var c := roundi(u.x)
		out[c] = int(out.get(c, 0)) + 1
	return out


func _resumo(classes: Dictionary) -> String:
	var partes: Array[String] = []
	for c: int in classes:
		partes.append("%s %d" % [String(Carroceria.Classe.keys()[c]).to_lower(),
			int(classes[c])])
	return ", ".join(partes)


func _triangulos(malha: ArrayMesh, s: int) -> Array:
	var out: Array = []
	if s >= malha.get_surface_count():
		return out
	var arr := malha.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		out.append([v[idx[t]], v[idx[t + 1]], v[idx[t + 2]]])
	return out


## O segmento de 15 cm para cada lado do ponto, ao longo da normal, toca algum
## triangulo?
func _cruza(tris: Array, c: Vector3, n: Vector3) -> bool:
	var a := c + n.normalized() * 0.15
	var b := c - n.normalized() * 0.15
	for t: Array in tris:
		if Geometry3D.segment_intersects_triangle(a, b, t[0], t[1], t[2]) != null:
			return true
	return false


func _meia(info: Dictionary, z: float, y: float) -> float:
	var e: Vector3 = info.get("escala", Vector3.ONE)
	return CarroceriaVarrida.x_casco_fino(info["perfil"], info["ombro"],
		-z / e.z, y / e.y) * e.x


func _dentro(info: Dictionary, p: Vector3) -> bool:
	var e: Vector3 = info.get("escala", Vector3.ONE)
	var est := CarroceriaVarrida.estacao(info["perfil"], -p.z / e.z)
	var topo := float(est[CarroceriaVarrida.TOPO]) * e.y
	var fundo := float(est[CarroceriaVarrida.BOT]) * e.y
	if p.y > topo - FOLGA_CASCO or p.y < fundo:
		return false
	return absf(p.x) <= _meia(info, p.z, p.y) - FOLGA_CASCO

## Bancada da JanelaViva: todo estado de janela fecha o vao inteiro.
##
##   godot --headless --path game --script res://tests/bancada_janela_viva.gd
##
## Monta uma fachada de 9 x 6 m com quatro janelas (terreo e primeiro andar) em
## cada estado — aberta com comodo, entreaberta, fechada, de correr aberta,
## basculante, com arco — nas quatro direcoes, e dispara raios de todo angulo.
## Todo raio tem de bater num triangulo VISIVEL antes de passar 4 m atras do
## plano (o fundo do comodo mais folga). Controle positivo: sem a parede do
## fundo de um comodo, os raios que entram pela janela aberta passam.
## Imprime tambem os triangulos por janela de cada estado.
extends SceneTree

var _falhas: Array[String] = []
var PV: GDScript
var JV: GDScript


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	PV = load("res://src/world/parede_vazada.gd")
	JV = load("res://src/world/janela_viva.gd")
	var casos := [
		{"nome": "colonial aberta", "estilo": &"colonial", "abertura": 2, "modelo": &"folhas", "arco": 0.3},
		{"nome": "colonial fechada", "estilo": &"colonial", "abertura": 0, "modelo": &"folhas", "folhas_fechadas": true},
		{"nome": "veneziana entreaberta", "estilo": &"ecletico", "abertura": 1, "modelo": &"veneziana"},
		{"nome": "correr aberta", "estilo": &"moderno", "abertura": 2, "modelo": &"correr", "grade": 2},
		{"nome": "basculante", "estilo": &"popular", "abertura": 1, "modelo": &"basculante", "grade": 1},
		{"nome": "cozinha aberta", "estilo": &"colonial", "abertura": 2, "modelo": &"folhas", "comodo": &"cozinha"},
		{"nome": "quarto aberto", "estilo": &"moderno", "abertura": 2, "modelo": &"veneziana", "comodo": &"quarto"},
	]
	for caso: Dictionary in casos:
		var tris_janela := 0
		for direcao in 4:
			var sup := {}
			var base := Vector3(-3.0, 0.0, 5.0)
			var montadas := _fachada(sup, base, direcao, caso, false)
			var tris := _triangulos(sup)
			if direcao == 0:
				tris_janela = (tris.size() / 3 - _tris_so_parede(base, direcao, caso)) / montadas
			var furos := _varrer(tris, base, direcao)
			_conferir(furos == 0, "%s, direcao %d: %d raios para o vazio" % [caso["nome"], direcao, furos])
		print("[janela_viva] %-22s %4d triangulos por janela" % [caso["nome"], tris_janela])
	# Controle positivo: a mesma fachada aberta, sem a parede do fundo do comodo.
	var sup_c := {}
	var caso_c: Dictionary = casos[0]
	_fachada(sup_c, Vector3(-3.0, 0.0, 5.0), 0, caso_c, true)
	var furos_c := _varrer(_triangulos(sup_c), Vector3(-3.0, 0.0, 5.0), 0)
	_conferir(furos_c > 0, "controle positivo: sem o fundo do comodo a regua nao viu furo")
	print("[janela_viva] controle: %d raios pelo comodo sem fundo" % furos_c)
	if _falhas.is_empty():
		print("OK — janela viva fecha o vao em todo estado e direcao")
	else:
		print("FALHOU")
		for f in _falhas:
			print("  x ", f)
	quit(0 if _falhas.is_empty() else 1)


## Quatro janelas no estado do caso. Devolve quantas foram montadas.
func _fachada(sup: Dictionary, base: Vector3, direcao: int, caso: Dictionary,
		sem_fundo: bool) -> int:
	var rects := [Rect2(-3.6, 1.0, 1.1, 1.5), Rect2(-0.6, 1.0, 1.2, 1.6),
		Rect2(2.2, 1.1, 1.0, 1.4), Rect2(-0.6, 4.0, 1.2, 1.5)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var estados: Array[Dictionary] = []
	var vaos: Array = []
	var casa := {}
	for k in rects.size():
		var e: Dictionary = JV.sortear(rng, caso["estilo"], &"zelosa", 0 if k < 3 else 1, k % 2 == 0, casa)
		for chave in ["abertura", "modelo", "folhas_fechadas", "grade", "comodo"]:
			if caso.has(chave):
				e[chave] = caso[chave]
		estados.append(e)
		vaos.append({"rect": rects[k], "prof": JV.profundidade(caso["estilo"]),
			"arco": float(caso.get("arco", 0.0)), "tampa": JV.precisa_tampa(e)})
	var quadros: Array = PV.erguer(sup, &"reboco", base, 9.0, 6.0, direcao,
		Color(0.9, 0.85, 0.7), vaos)
	for k in quadros.size():
		JV.preencher(sup, quadros[k], estados[k], Vector2(0.9, 0.9))
	if sem_fundo:
		# Tira a parede do fundo do primeiro comodo: o maior plano de reboco
		# virado para a rua, atras do plano da fachada.
		_tirar_fundo(sup, base, direcao)
	return quadros.size()


func _tris_so_parede(base: Vector3, direcao: int, caso: Dictionary) -> int:
	var sup := {}
	var vaos: Array = []
	for r: Rect2 in [Rect2(-3.6, 1.0, 1.1, 1.5), Rect2(-0.6, 1.0, 1.2, 1.6),
			Rect2(2.2, 1.1, 1.0, 1.4), Rect2(-0.6, 4.0, 1.2, 1.5)]:
		vaos.append({"rect": r, "prof": JV.profundidade(caso["estilo"]),
			"arco": float(caso.get("arco", 0.0)), "tampa": false})
	PV.erguer(sup, &"reboco", base, 9.0, 6.0, direcao, Color.WHITE, vaos)
	return _triangulos(sup).size() / 3


func _tirar_fundo(sup: Dictionary, base: Vector3, direcao: int) -> void:
	# Em todo material: a parede do fundo do comodo e `interior` ou
	# `interior_aceso`, e a regua nao pode depender de qual.
	var normal := KitModular._normal(direcao)
	for mat: StringName in sup:
		var d: Dictionary = sup[mat]
		var v: PackedVector3Array = d["v"]
		var idx: PackedInt32Array = d["i"]
		var saida := PackedInt32Array()
		for k in range(0, idx.size(), 3):
			var a := v[idx[k]]
			var b := v[idx[k + 1]]
			var c := v[idx[k + 2]]
			var n_vis := -(b - a).cross(c - a).normalized()
			var fundo := (base - a).dot(normal)
			# Plano virado para a rua, mais de 1 m atras da fachada: fundo de comodo.
			if n_vis.dot(normal) > 0.9 and fundo > 1.0:
				continue
			saida.append_array([idx[k], idx[k + 1], idx[k + 2]])
		d["i"] = saida


func _conferir(ok: bool, msg: String) -> void:
	if not ok:
		_falhas.append(msg)


func _triangulos(sup: Dictionary) -> Array[Vector3]:
	var saida: Array[Vector3] = []
	for mat: StringName in sup:
		var v: PackedVector3Array = sup[mat]["v"]
		var idx: PackedInt32Array = sup[mat]["i"]
		for k in idx.size():
			saida.append(v[idx[k]])
	return saida


func _varrer(tris: Array[Vector3], base: Vector3, direcao: int) -> int:
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var furos := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# Metade dos alvos dentro dos vaos, que e onde a janela pode falhar.
	var alvos_vao := [Vector2(-3.05, 1.75), Vector2(0.0, 1.8), Vector2(2.7, 1.8),
		Vector2(0.0, 4.75)]
	for amostra in 900:
		var x: float
		var y: float
		if amostra % 2 == 0:
			var c: Vector2 = alvos_vao[(amostra / 2) % alvos_vao.size()]
			x = c.x + rng.randf_range(-0.5, 0.5)
			y = c.y + rng.randf_range(-0.7, 0.7)
		else:
			x = rng.randf_range(-4.48, 4.48)
			y = rng.randf_range(0.02, 5.98)
		var alvo := base + lateral * x + Vector3(0.0, y, 0.0)
		var ang_h := rng.randf_range(-1.2, 1.2)
		var ang_v := rng.randf_range(-0.8, 0.8)
		var dir_fora := (normal * cos(ang_h) + lateral * sin(ang_h)) * cos(ang_v) \
			+ Vector3.UP * sin(ang_v)
		var origem := alvo + dir_fora.normalized() * 6.0
		var dir := (alvo - origem).normalized()
		var alcance := (alvo - origem).length() + 4.0 / maxf(-dir.dot(normal), 0.05)
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
			if OS.get_cmdline_user_args().has("--detalhe") and furos <= 4:
				print("  furo em x=%.2f y=%.2f (%s)" % [x, y, "avesso" if melhor < alcance else "vazio"])
	return furos


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

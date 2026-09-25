## A arvore por esqueleto gasta do rng de quem planta o MESMO que a de caixa
## (PLANO_FLORA_AAA, etapa 2). Se nao gastar, tudo o que o chunk sorteia depois
## da arvore muda de lugar.
##
##     godot --headless --path game --script res://tests/teste_arvore_sorteio.gd
extends SceneTree


func _init() -> void:
	# No `--script` as `static var` da ArvoreEsqueleto nao sao inicializadas
	# (ficam falsas): a copa fina e a variedade entram aqui como no jogo, senao o
	# teste nao cobre o sorteio delas (rodada 3).
	ArvoreEsqueleto.copa_fina = true
	ArvoreEsqueleto.variedade = true
	ArvoreEsqueleto.palmeira_antiga = false
	Vegetacao.ativo = true
	var falhas := 0
	for especie: StringName in Vegetacao.ESPECIES:
		for semente in [1, 77, 4242, 90001]:
			for porte in [0.2, 0.7, 1.0]:
				var a := RandomNumberGenerator.new()
				a.seed = semente
				var b := RandomNumberGenerator.new()
				b.seed = semente
				var col_a: Array[Dictionary] = []
				var col_b: Array[Dictionary] = []
				ArvoreEsqueleto.ativo = false
				var ra := Vegetacao.arvore({}, col_a, Vector3(3, 0, 5), especie, porte, a)
				ArvoreEsqueleto.ativo = true
				var sup := {}
				var rb := Vegetacao.arvore(sup, col_b, Vector3(3, 0, 5), especie, porte, b)
				if a.state != b.state or not is_equal_approx(ra, rb) or col_a.size() != col_b.size():
					falhas += 1
					print("FALHA %s semente %d porte %.1f: estado %d x %d, raio %.3f x %.3f" % [
						especie, semente, porte, a.state, b.state, ra, rb])
	# A do parque (KitParque.arvore): mesmo sorteio, mesmo raio, mesma colisao.
	for semente in [3, 91, 5150, 70007]:
		for porte in [0.1, 0.5, 0.9]:
			for seca in [false, true]:
				var a := RandomNumberGenerator.new()
				a.seed = semente
				var b := RandomNumberGenerator.new()
				b.seed = semente
				var col_a: Array[Dictionary] = []
				var col_b: Array[Dictionary] = []
				ArvoreEsqueleto.ativo = false
				var ra := KitParque.arvore({}, col_a, Vector3(1, 0, 2), porte, a, seca)
				ArvoreEsqueleto.ativo = true
				var rb := KitParque.arvore({}, col_b, Vector3(1, 0, 2), porte, b, seca)
				if a.state != b.state or not is_equal_approx(ra, rb) or col_a != col_b:
					falhas += 1
					print("FALHA parque semente %d porte %.1f: estado %d x %d, raio %.3f x %.3f" % [
						semente, porte, a.state, b.state, ra, rb])
	# As palmeiras: a da rua (Vegetacao) e a da praca (KitParque).
	for semente in [8, 404, 9999]:
		for tipo in 3:
			var a := RandomNumberGenerator.new()
			a.seed = semente
			var b := RandomNumberGenerator.new()
			b.seed = semente
			var col_a: Array[Dictionary] = []
			var col_b: Array[Dictionary] = []
			for lado in 2:
				ArvoreEsqueleto.ativo = lado == 1
				var rr := a if lado == 0 else b
				var cc := col_a if lado == 0 else col_b
				if tipo == 2:
					KitParque.palmeira({}, cc, Vector3(4, 0, 1), 12.0, rr)
				else:
					Vegetacao.palmeira({}, cc, Vector3(4, 0, 1), tipo == 0, rr)
			if a.state != b.state or (tipo == 2 and col_a != col_b):
				falhas += 1
				print("FALHA palmeira %d semente %d: estado %d x %d" % [tipo, semente, a.state, b.state])
	# O pinheiro do parque (rodada 3: tuia e araucaria por esqueleto).
	for semente in [5, 606, 70707]:
		for porte in [0.0, 0.5, 1.0]:
			var a := RandomNumberGenerator.new()
			a.seed = semente
			var b := RandomNumberGenerator.new()
			b.seed = semente
			var col_a: Array[Dictionary] = []
			var col_b: Array[Dictionary] = []
			ArvoreEsqueleto.ativo = false
			var ra := KitParque.pinheiro({}, col_a, Vector3(3, 0, 3), porte, a)
			ArvoreEsqueleto.ativo = true
			var rb := KitParque.pinheiro({}, col_b, Vector3(3, 0, 3), porte, b)
			if a.state != b.state or not is_equal_approx(ra, rb) or col_a != col_b:
				falhas += 1
				print("FALHA pinheiro semente %d porte %.1f: estado %d x %d" % [semente, porte,
					a.state, b.state])
	# Arbusto e sebe do parque.
	for semente in [12, 345, 6789]:
		var a := RandomNumberGenerator.new()
		a.seed = semente
		var b := RandomNumberGenerator.new()
		b.seed = semente
		var col_a: Array[Dictionary] = []
		var col_b: Array[Dictionary] = []
		for lado in 2:
			ArvoreEsqueleto.ativo = lado == 1
			var rr := a if lado == 0 else b
			var cc := col_a if lado == 0 else col_b
			KitParque.arbusto({}, Vector3(2, 0, 2), 1.1, rr)
			KitParque.sebe({}, cc, Vector3(0, 0, 0), Vector3(9.5, 0, 3.0), rr)
		if a.state != b.state or col_a != col_b:
			falhas += 1
			print("FALHA arbusto/sebe semente %d: estado %d x %d" % [semente, a.state, b.state])
	# A arvore da mata da estrada.
	for semente in [21, 2222, 31337]:
		for porte in [0.1, 0.6, 1.0]:
			var a := RandomNumberGenerator.new()
			a.seed = semente
			var b := RandomNumberGenerator.new()
			b.seed = semente
			ArvoreEsqueleto.ativo = false
			var ra := KitEstrada.arvore({}, Vector3(5, 0, 5), porte, a, semente % 2 == 0)
			ra += KitEstrada.conifera({}, Vector3(9, 0, 5), porte, a, 0.1 + porte * 0.15)
			ArvoreEsqueleto.ativo = true
			var rb := KitEstrada.arvore({}, Vector3(5, 0, 5), porte, b, semente % 2 == 0)
			rb += KitEstrada.conifera({}, Vector3(9, 0, 5), porte, b, 0.1 + porte * 0.15)
			if a.state != b.state or not is_equal_approx(ra, rb):
				falhas += 1
				print("FALHA mata semente %d: estado %d x %d" % [semente, a.state, b.state])
	# Bananeira e bambu em 3D (Plantas, rodada 2).
	for semente in [3, 777, 40404]:
		var a := RandomNumberGenerator.new()
		a.seed = semente
		var b := RandomNumberGenerator.new()
		b.seed = semente
		ArvoreEsqueleto.ativo = false
		Vegetacao.bananeira({}, Vector3(2, 0, 3), a)
		Vegetacao.bambu({}, Vector3(6, 0, 3), a)
		ArvoreEsqueleto.ativo = true
		Vegetacao.bananeira({}, Vector3(2, 0, 3), b)
		Vegetacao.bambu({}, Vector3(6, 0, 3), b)
		if a.state != b.state:
			falhas += 1
			print("FALHA bananeira/bambu semente %d: estado %d x %d" % [semente, a.state, b.state])
	for esp: StringName in [&"oiti", &"mangueira"]:
		for semente in 4:
			var c := RandomNumberGenerator.new()
			c.seed = semente * 31 + 7
			var s2 := {}
			Vegetacao.arvore(s2, [] as Array[Dictionary], Vector3(semente, 0, 1), esp, 0.5, c)
			var t2 := 0
			for k: StringName in s2:
				t2 += (s2[k]["i"] as PackedInt32Array).size() / 3
			print("  %s variedade %d: %d triangulos %s" % [esp, semente, t2, str(s2.keys())])
	for semente in 2:
		var c := RandomNumberGenerator.new()
		c.seed = semente
		var s3 := {}
		Vegetacao.bananeira(s3, Vector3.ZERO, c)
		Vegetacao.bambu(s3, Vector3(5, 0, 0), c)
		Plantas.mamoeiro(s3, Vector3(9, 0, 0), c)
		var t3 := 0
		for k: StringName in s3:
			t3 += (s3[k]["i"] as PackedInt32Array).size() / 3
		print("  bananeira+bambu+mamoeiro: %d triangulos" % t3)
	var sup := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	Vegetacao.arvore(sup, [] as Array[Dictionary], Vector3.ZERO, &"mangueira", 0.7, rng)
	var tris := 0
	for k: StringName in sup:
		tris += (sup[k]["i"] as PackedInt32Array).size() / 3
		print("  %s: %d triangulos" % [k, (sup[k]["i"] as PackedInt32Array).size() / 3])
	print("mangueira 0,7: %d triangulos" % tris)
	print("teste_arvore_sorteio: %s" % ("PASSA" if falhas == 0 else "%d FALHAS" % falhas))
	quit(0 if falhas == 0 else 1)

## Amassado: o criterio A20 do PLANO_AAA_4K.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_batida.gd
##     --saida=DIR grava a foto do carro amassado
##
## Bancada e nao rua: na cidade o carro batido depende de onde o transito
## estava, e o criterio tem de bater sempre no mesmo muro, na mesma velocidade.
## (Memoria: "bancada offline para o que a rua nao deixa medir".)
##
## Duas batidas, cada uma num carro novo:
##
##   FRENTE  sedan a 15 m/s contra um muro. Mede se a batida foi forte (>= 0,6),
##           se a chapa entrou (>= 3 cm) e se entrou SO na frente — a traseira
##           tem de ficar onde estava. Um amassado que mexe o carro inteiro e
##           um carro derretendo, nao um carro batido.
##   LADO    o mesmo carro deslizando de lado contra o muro, com o jogador
##           dentro. E a batida que poe a cabine a prova: a porta entra, e o
##           forro da porta tem de entrar junto. A medida e a do OLHO: raios
##           saindo de onde fica a cabeca do motorista, apontados para a regiao
##           amassada, e em cada um a pergunta e quem ele acerta primeiro, forro
##           ou lataria. Se a chapa atravessasse o forro, a lataria de fora
##           apareceria dentro do carro — o defeito que o `checar_cabine_contida`
##           existe para impedir.
##
##           Por raio, e nao por vizinho mais proximo: a primeira versao comparava
##           cada ponto do forro com o ponto de chapa mais perto, a ate 15 cm, e
##           media o gradiente do amassado entre os dois em vez de medir se um
##           passou do outro. A chapa tem poucos vertices; o que o olho ve e o
##           TRIANGULO entre eles. (Memoria: "sonda por raio nomeia o buraco".)
##
##   TOMAR    o jogador toma o volante de um carro da IA andando a 40 km/h, em
##           campo aberto. NAO pode haver batida: a primeira captura do painel
##           novo mostrou o motor afogado e o carro parado logo depois de a
##           rotina de captura tomar um carro em movimento.
##
##   CONTROLE a mesma batida, aplicada so na LATARIA de um carro novo. Tem de
##           furar. E o que prova que a sonda enxerga o defeito: sem ele, uma
##           sonda cega passaria em qualquer carro. Medido na primeira rodada: 58
##           raios em 151 com a lataria sozinha, contra 7 com a cabine junto.
extends SceneTree

const FOLGA_CABINE := 0.02
const VEL_FRENTE := 15.0
const VEL_LADO := 11.0

## O `Carro` vem por `load`, e nao por nome de classe: ele depende de autoloads
## (`Conversa`, `Settings`), e um script de SceneTree e compilado ANTES de eles
## existirem — com o tipo escrito aqui, a bancada nem carregava.
var _carro_script: GDScript
var _saida := ""
var _passou := 0
var _total := 0
var _forcas: Array[float] = []


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_medir()


func _medir() -> void:
	await process_frame
	await process_frame
	_carro_script = load("res://src/world/carro.gd") as GDScript
	print("\n=== A20: amassado ===\n")
	if not OS.get_cmdline_user_args().has("--so-tomar"):
		await _frente()
		var batida := await _lado()
		await _controle(batida)
	await _tomar_andando()
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


func _mundo(muro_em: Vector3, muro_tam: Vector3) -> Node3D:
	var mundo := Node3D.new()
	root.add_child(mundo)
	mundo.add_child(_caixa(Vector3(0.0, -0.5, 0.0), Vector3(200.0, 1.0, 200.0)))
	mundo.add_child(_caixa(muro_em, muro_tam))
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	mundo.add_child(sol)
	return mundo


func _caixa(onde: Vector3, tam: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.position = onde
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tam
	forma.shape = caixa
	corpo.add_child(forma)
	return corpo


func _carro(mundo: Node3D) -> VehicleBody3D:
	var c: VehicleBody3D = _carro_script.new()
	c.set(&"modelo", 0)  # Carroceria.Modelo.SEDA
	c.set(&"semente", 3)
	c.set(&"motorista", 0)  # Carro.Motorista.NINGUEM
	mundo.add_child(c)
	c.connect(&"bateu", func(f: float) -> void: _forcas.append(f))
	return c


## Tomar o volante de um carro andando nao e bater.
##
## Dois jeitos de a regua de batida mentir nesse instante, um caso para cada:
##
##   ENCOSTADO  o carro da IA anda por transformada e o corpo rigido fica com
##              velocidade zero; `assumir` poe a velocidade de uma vez, e a regua
##              mede QUEDA entre dois quadros. Hoje isso nao acusa nada porque o
##              monitor de contato so liga dentro de `assumir`, e o primeiro
##              quadro ainda nao tem contato relatado — conferido tirando e
##              pondo uma linha que alinhava a velocidade anterior: a medida nao
##              mudou, e a linha saiu. O caso fica de guarda, encostado num muro
##              como numa rua estreita, para o dia em que o monitor ligar antes.
##   NA ORIGEM  quem estava ao volante desce e vira pedestre. O corpo dele nascia
##              na origem do pai antes de ir para o lado do carro, e um carro em
##              cima dessa origem era arremessado.
func _tomar_andando() -> void:
	for caso: String in ["encostado", "na origem"]:
		var mundo := _mundo(Vector3(0.0, 1.0, -150.0), Vector3(4.0, 2.0, 1.0))
		var c := _carro(mundo)
		var x := 0.0 if caso == "na origem" else 20.0
		var largura := float((c.get(&"_medidas") as Dictionary)["largura"])
		if caso == "encostado":
			# Meio centimetro dentro do muro: contato garantido, e empurrao que
			# nao passa de um tranco.
			mundo.add_child(_caixa(Vector3(x - largura * 0.5 - 0.495, 1.0, 0.0),
				Vector3(1.0, 2.0, 60.0)))
		# Com a origem NO CHAO, como o transito o deixa: `Carro._dirigir_ia`
		# escreve a altura do raio de chao direto na origem do corpo congelado.
		c.call(&"pousar", Vector3(x, 0.0, 0.0), 0.0)
		for _q in 3:
			await physics_frame
		# Carro da IA a 40 km/h, congelado como o transito o deixa. Tudo no mesmo
		# quadro: sem rota nesta bancada, um passo de `_dirigir_ia` nao teria
		# para onde ir.
		c.set(&"motorista", 1)  # Carro.Motorista.IA
		# Com ficha do registro, como o transito faz: quem desce vira pedestre.
		var registro := root.get_node_or_null(^"/root/RegistroCivil")
		if registro != null:
			c.set(&"ficha", registro.call(&"identidade",
				registro.call(&"id_de_transeunte", 4321)))
		c.set(&"ligado", true)
		c.call(&"_congelar", true)
		c.set(&"_velocidade", 11.0)
		_forcas.clear()
		c.call(&"assumir", Node3D.new())
		var lateral := 0.0
		for _q in 60:
			await physics_frame
			lateral = maxf(lateral, absf(c.linear_velocity.dot(c.global_basis.x)))
		await _esperar_amassado(c)
		var batidas := (c.call(&"amassado").get(&"batidas") as Array).size()
		var kmh := absf(float(c.call(&"velocidade"))) * 3.6
		_conta("A20 tomar o volante nao e batida (%s)" % caso,
			_forcas.is_empty() and bool(c.get(&"ligado")) and batidas == 0
				and kmh > 20.0 and lateral < 3.0,
			"tomado a 40 km/h: %d batida(s) %s, motor %s, %d amassado(s), pico de %.1f m/s de lado, %.0f km/h um segundo depois"
				% [_forcas.size(), str(_forcas),
					"ligado" if bool(c.get(&"ligado")) else "AFOGADO", batidas,
					lateral, kmh])
		for n: Node in mundo.get_children():
			n.queue_free()
		mundo.queue_free()
		await process_frame
		await physics_frame


## Posicoes dos vertices de uma malha, no espaco do carro, uma lista por
## superficie.
##
## Por superficie, e nao concatenado: a lataria tem duas (chapa e vidro,
## PLANO_CARROS_AAA F1), e o amassado ANEXA os vertices da subdivisao no fim da
## superficie que ele dividiu. Concatenado, o vidro inteiro andava de indice e a
## comparacao antes/depois media vertice contra vertice diferente — "a traseira
## andou 324 cm". Por superficie, o indice antigo continua sendo o mesmo ponto.
static func _vertices(carro: Node3D, m: MeshInstance3D) -> Array:
	var saida: Array = []
	var mesh := m.mesh as ArrayMesh
	if mesh == null:
		return saida
	var x := carro.global_transform.affine_inverse() * m.global_transform
	for s in mesh.get_surface_count():
		var v: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		var lista := PackedVector3Array()
		for p in v:
			lista.append(x * p)
		saida.append(lista)
	return saida


## Os pares [antes, depois] do mesmo vertice, superficie por superficie.
static func _pares(antes: Array, depois: Array) -> Array:
	var out: Array = []
	for s in mini(antes.size(), depois.size()):
		var a: PackedVector3Array = antes[s]
		var d: PackedVector3Array = depois[s]
		for k in mini(a.size(), d.size()):
			out.append([a[k], d[k]])
	return out


## Vertices no espaco da propria malha.
static func _locais(m: MeshInstance3D) -> PackedVector3Array:
	var saida := PackedVector3Array()
	var mesh := m.mesh as ArrayMesh
	if mesh == null:
		return saida
	for s in mesh.get_surface_count():
		saida.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return saida


## Triangulos de varias malhas, no espaco do carro, em trincas seguidas.
static func _triangulos(carro: Node3D, malhas: Array) -> PackedVector3Array:
	var saida := PackedVector3Array()
	for m: MeshInstance3D in malhas:
		var mesh := m.mesh as ArrayMesh
		if mesh == null:
			continue
		var x := carro.global_transform.affine_inverse() * m.global_transform
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx = a[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				for i: int in idx:
					saida.append(x * v[i])
			else:
				for q in v:
					saida.append(x * q)
	return saida


## A caixa em volta dos pontos amassados, com folga: so triangulo dentro dela
## entra na conta, senao a sonda leva minutos.
static func _regiao(pontos: PackedVector3Array) -> AABB:
	if pontos.is_empty():
		return AABB()
	var caixa := AABB(pontos[0], Vector3.ZERO)
	for q in pontos:
		caixa = caixa.expand(q)
	return caixa.grow(0.25)


## Quantos raios acertam a lataria ANTES do forro.
static func _furos(olho: Vector3, dirs: PackedVector3Array, lataria: PackedVector3Array,
		forro: PackedVector3Array, regiao: AABB) -> int:
	var lat := _filtrar(lataria, regiao)
	var cab := _filtrar(forro, regiao)
	var n := 0
	for d in dirs:
		var t_lat := _primeiro(olho, d, lat)
		if t_lat == INF:
			continue
		if t_lat < _primeiro(olho, d, cab) - 0.002:
			n += 1
	return n


static func _filtrar(tri: PackedVector3Array, regiao: AABB) -> PackedVector3Array:
	var saida := PackedVector3Array()
	for t in range(0, tri.size() - 2, 3):
		if regiao.has_point(tri[t]) or regiao.has_point(tri[t + 1]) 				or regiao.has_point(tri[t + 2]):
			saida.append(tri[t])
			saida.append(tri[t + 1])
			saida.append(tri[t + 2])
	return saida


static func _primeiro(de: Vector3, dir: Vector3, tri: PackedVector3Array) -> float:
	var melhor := INF
	for t in range(0, tri.size() - 2, 3):
		var bate = Geometry3D.ray_intersects_triangle(de, dir, tri[t], tri[t + 1], tri[t + 2])
		if bate != null:
			melhor = minf(melhor, de.distance_to(bate as Vector3))
	return melhor


## A cabeca do motorista, no espaco do carro.
static func _olho(c: Node3D) -> Vector3:
	var cab := c.get_node_or_null(^"CabineDoJogador/Cabine") as Node3D
	if cab == null or not cab.has_method(&"olho"):
		return Vector3(-0.35, 1.1, 0.0)
	var local: Vector3 = cab.call(&"olho")
	return c.global_transform.affine_inverse() * (cab.global_transform * local)


func _lataria(c: Node) -> MeshInstance3D:
	return c.get_node_or_null(^"Lataria") as MeshInstance3D


func _cabine(c: Node) -> Array[MeshInstance3D]:
	var saida: Array[MeshInstance3D] = []
	var cab := c.get_node_or_null(^"CabineDoJogador")
	if cab == null:
		return saida
	for no: Node in cab.find_children("*", "MeshInstance3D", true, false):
		saida.append(no as MeshInstance3D)
	return saida


## Empurra o carro na velocidade pedida e espera a batida.
func _lancar(c: VehicleBody3D, vel: Vector3) -> float:
	_forcas.clear()
	await physics_frame
	var rid := c.get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, vel)
	c.linear_velocity = vel
	for _q in 180:
		await physics_frame
		if not _forcas.is_empty():
			break
	# Espera o carro assentar depois da pancada.
	for _q in 30:
		await physics_frame
	await _esperar_amassado(c)
	var maior := 0.0
	for f in _forcas:
		maior = maxf(maior, f)
	return maior


## O amassado roda numa thread e chega alguns quadros depois da pancada.
func _esperar_amassado(c: Node) -> void:
	var a: RefCounted = c.call(&"amassado")
	for _q in 240:
		if not bool(a.call(&"ocupado")):
			break
		await process_frame
	await process_frame


func _frente() -> void:
	var mundo := _mundo(Vector3(0.0, 1.0, -9.0), Vector3(12.0, 2.0, 1.0))
	var c := _carro(mundo)
	c.call(&"pousar", Vector3(0.0, 0.8, 0.0), 0.0)
	await physics_frame
	c.call(&"assumir", Node3D.new())
	await physics_frame
	var lat := _lataria(c)
	var antes := _vertices(c, lat)
	if _saida != "":
		await _fotografar(mundo, c, Vector3(-1.9, 1.0, -3.3), "batida_frente_antes")
	var forca := await _lancar(c, Vector3(0.0, 0.0, -VEL_FRENTE))
	var depois := _vertices(c, lat)
	var comp: float = lat.mesh.get_aabb().size.z
	var frente := 0.0
	var tras := 0.0
	for par: Array in _pares(antes, depois):
		var a: Vector3 = par[0]
		var d := a.distance_to(par[1])
		if a.z < -comp * 0.25:
			frente = maxf(frente, d)
		elif a.z > comp * 0.25:
			tras = maxf(tras, d)
	_conta("A20 batida forte", forca >= 0.6,
		"a %.0f m/s contra o muro, a batida sai com forca %.2f" % [VEL_FRENTE, forca])
	_conta("A20 a frente entrou", frente >= 0.03,
		"a chapa da frente entrou %.1f cm (pedido: 3)" % (frente * 100.0))
	_conta("A20 so a frente", tras <= 0.005,
		"a traseira andou %.2f cm" % (tras * 100.0))
	var custo := float(c.call(&"custo_amassado_ms"))
	var atraso := float(c.call(&"atraso_amassado_ms"))
	# O quadro principal so sobe a malha pronta: acima de 8 ms isso vira engasgo,
	# e o engasgo cai exatamente no momento que o jogador mais sente. E o
	# amassado tem de aparecer enquanto a batida ainda esta acontecendo.
	_conta("A20 custo", custo <= 8.0 and atraso <= 400.0,
		"o quadro principal pagou %.1f ms; o amassado chegou %.0f ms depois da pancada"
			% [custo, atraso])
	if _saida != "":
		await _fotografar(mundo, c, Vector3(-1.9, 1.0, -3.3), "batida_frente")
	mundo.queue_free()
	await process_frame


func _lado() -> Array:
	var mundo := _mundo(Vector3(4.5, 1.0, 0.0), Vector3(1.0, 2.0, 12.0))
	var c := _carro(mundo)
	c.call(&"pousar", Vector3(0.0, 0.8, 0.0), 0.0)
	await physics_frame
	c.call(&"assumir", Node3D.new())
	await physics_frame
	var lat := _lataria(c)
	var pecas := _cabine(c)
	if pecas.is_empty():
		_conta("A20 cabine contida", false, "o carro assumido nao montou cabine")
		mundo.queue_free()
		return []
	var olho := _olho(c)
	var tri_lat_antes := _triangulos(c, [lat])
	var tri_cab_antes := _triangulos(c, pecas)
	var lat_antes := _vertices(c, lat)
	var forca := await _lancar(c, Vector3(VEL_LADO, 0.0, 0.0))
	var lat_depois := _vertices(c, lat)
	var porta := 0.0
	var alvos := PackedVector3Array()
	for par: Array in _pares(lat_antes, lat_depois):
		var d := (par[1] as Vector3).distance_to(par[0])
		porta = maxf(porta, d)
		if d > 0.005:
			alvos.append(par[0])
	_conta("A20 batida de lado", forca >= 0.4 and porta >= 0.02,
		"de lado a %.0f m/s: forca %.2f, a porta entrou %.1f cm"
			% [VEL_LADO, forca, porta * 100.0])
	var tri_lat_depois := _triangulos(c, [lat])
	var tri_cab_depois := _triangulos(c, pecas)
	# Os mesmos raios antes e depois: do olho para cada ponto de chapa que andou,
	# e para o meio de cada par vizinho deles (a chapa e o triangulo, nao o
	# vertice).
	var dirs := PackedVector3Array()
	for k in alvos.size():
		dirs.append((alvos[k] - olho).normalized())
		if k > 0:
			dirs.append(((alvos[k] + alvos[k - 1]) * 0.5 - olho).normalized())
	var regiao := _regiao(alvos)
	var furou_antes := _furos(olho, dirs, tri_lat_antes, tri_cab_antes, regiao)
	var furou_depois := _furos(olho, dirs, tri_lat_depois, tri_cab_depois, regiao)
	var novos := furou_depois - furou_antes
	_conta("A20 cabine contida", dirs.size() > 0 and novos <= maxi(1, dirs.size() / 200),
		"de %d raios do olho para o amassado, a lataria aparece na frente do forro em %d antes e %d depois"
			% [dirs.size(), furou_antes, furou_depois])
	var cab_depois: Array[PackedVector3Array] = []
	for m in pecas:
		cab_depois.append(_locais(m))
	# A cabine desmontada e montada de novo tem de voltar AMASSADA.
	c.call(&"devolver")
	await physics_frame
	c.call(&"assumir", Node3D.new())
	await physics_frame
	await _esperar_amassado(c)
	# A comparacao e com a cabine AMASSADA de antes de descer, e nao com o campo:
	# perguntar ao campo se um ponto esta na regiao do amassado responderia sim
	# mesmo para uma cabine lisa, porque a regiao e a mesma.
	var nova := _cabine(c)
	var diferenca := 0.0
	var iguais := nova.size() == cab_depois.size()
	if iguais:
		for i in nova.size():
			# No espaco da PECA: volante e ponteiro giram, e no espaco do carro
			# eles mudariam de lugar sem ninguem ter batido em nada.
			var v := _locais(nova[i])
			if v.size() != cab_depois[i].size():
				iguais = false
				break
			for k in v.size():
				diferenca = maxf(diferenca, v[k].distance_to(cab_depois[i][k]))
	_conta("A20 cabine remontada", iguais and diferenca <= 0.001,
		"a cabine montada de novo fica a %.2f mm da amassada (%d pecas)"
			% [diferenca * 1000.0, nova.size()] if iguais
		else "a cabine nova nao tem as mesmas pecas da de antes")
	if _saida != "":
		await _fotografar(mundo, c, Vector3(2.4, 1.2, 2.2), "batida_lado")
	var feita: Array = []
	var lista: Array = (c.call(&"amassado").batidas as Array)
	if not lista.is_empty():
		feita = (lista[0] as Array).duplicate()
		feita.append(furou_antes)
		feita.append(dirs)
		feita.append(regiao)
	mundo.queue_free()
	await process_frame
	return feita


## A mesma batida, so na lataria. A sonda TEM de acusar.
func _controle(batida: Array) -> void:
	if batida.size() < 7:
		_conta("A20 a sonda enxerga", false, "sem batida de lado para repetir")
		return
	var mundo := _mundo(Vector3(40.0, 1.0, 40.0), Vector3(1.0, 1.0, 1.0))
	var c := _carro(mundo)
	c.call(&"pousar", Vector3(0.0, 0.8, 0.0), 0.0)
	await physics_frame
	c.call(&"assumir", Node3D.new())
	await physics_frame
	var lat := _lataria(c)
	var pecas := _cabine(c)
	var olho := _olho(c)
	var dirs: PackedVector3Array = batida[5]
	var regiao: AABB = batida[6]
	var antes := _furos(olho, dirs, _triangulos(c, [lat]), _triangulos(c, pecas), regiao)
	var so_lataria: Array[MeshInstance3D] = [lat]
	# Forca 1: a profundidade maxima, que e a que a batida de lado chegou perto.
	(c.call(&"amassado") as RefCounted).call(&"bater_so", so_lataria,
		batida[0] as Vector3, batida[1] as Vector3, 1.0)
	await _esperar_amassado(c)
	var depois := _furos(olho, dirs, _triangulos(c, [lat]), _triangulos(c, pecas), regiao)
	_conta("A20 a sonda enxerga", depois - antes > maxi(3, dirs.size() / 20),
		"amassando so a lataria, ela aparece na frente do forro em %d raios (eram %d)"
			% [depois, antes])
	mundo.queue_free()
	await process_frame


func _fotografar(mundo: Node3D, c: Node3D, de: Vector3, nome: String) -> void:
	if mundo.get_node_or_null(^"Ambiente") == null:
		var amb := WorldEnvironment.new()
		amb.name = "Ambiente"
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.32, 0.34, 0.37)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.64, 0.7)
		env.ambient_light_energy = 0.7
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		amb.environment = env
		mundo.add_child(amb)
	var cam := Camera3D.new()
	cam.fov = 45.0
	mundo.add_child(cam)
	# Pelo rumo do carro: ele pode ter girado na pancada.
	cam.global_position = c.global_transform * de
	cam.look_at(c.global_transform * Vector3(0.0, 0.55, 0.0))
	cam.current = true
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_saida, nome])
	cam.queue_free()

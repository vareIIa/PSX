## O miolo da quadra grande: o chunk sem rua nenhuma, atras de todos os quintais.
##
## Por que existe
## -------------
## Era ChunkBuilder._anexos: duas a quatro caixas de concreto liso, sem porta,
## janela nem telhado, sorteadas uma por cima da outra (33 pares sobrepostos em 26
## chunks, o pior cobrindo 89% do menor), e assentadas no morro vertice a vertice
## (o topo de 64 dos 77 galpoes entortava mais de 30 cm, o pior 3,8 m). Da
## calcada quase nao se ve; do mirante e do beco, era o paredao cinza no meio do
## mar de telha (PLANO_CASAS_AAA.md, F4 e F6).
##
## Miolo de quadra de cidade do interior e o fundo dos quintais que cresceu: a
## edicula de aluguel, o galpao do depositio da loja da frente, o galinheiro, o
## pomar de mangueira e jabuticabeira, a horta, o capim.
##
## Como e montado
## --------------
## Depois do chao assentado (ChunkBuilder._quadra), com altura absoluta: cada
## construcao e rigida, na altura do canto mais alto da pegada, com embasamento de
## pedra ate o mais baixo. O telhado e o do TelhadoVivo (quatro aguas quando
## cabe, empena nas duas pontas quando nao). Nada se sobrepoe: a pegada de cada
## uma reserva 2,5 m em volta.
class_name MioloVivo
extends RefCounted

## Tipos de construcao e peso no sorteio.
const TIPOS := {&"edicula": 0.4, &"galpao": 0.35, &"galinheiro": 0.25}
const PEDRA := Relevo.COR_EMBASAMENTO


static func construir(sup: Dictionary, colisao: Array[Dictionary], quadra: Dictionary,
		lim: Rect2, cx: int, cz: int) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = (cx * 73856093) ^ (cz * 19349663) ^ 0x3110
	var ob := Obra.new()
	var ocupados: Array[Rect2] = []
	var tinta: Color = quadra.get("tinta", Color("d8d2c6"))
	var area := lim.grow(-1.5)
	for k in r.randi_range(1, 3):
		var tipo := FachadaViva._sortear_peso(r, TIPOS)
		var tam: Vector2
		match tipo:
			&"edicula":
				tam = Vector2(r.randf_range(4.2, 6.5), r.randf_range(3.6, 5.0))
			&"galpao":
				tam = Vector2(r.randf_range(6.0, 10.0), r.randf_range(5.0, 7.5))
			_:
				tam = Vector2(r.randf_range(3.0, 4.5), r.randf_range(2.4, 3.2))
		var direcao := r.randi() % 4
		# Casa virada para Z ocupa (larg, fundo) em (x, z); para X, o contrario.
		var planta := tam if direcao % 2 == 0 else Vector2(tam.y, tam.x)
		var lugar := Rect2()
		for _tentativa in 14:
			var p := Vector2(r.randf_range(area.position.x, maxf(area.position.x, area.end.x - planta.x)),
				r.randf_range(area.position.y, maxf(area.position.y, area.end.y - planta.y)))
			var cand := Rect2(p, planta)
			if not area.encloses(cand):
				continue
			var livre := true
			for o: Rect2 in ocupados:
				if o.grow(2.5).intersects(cand):
					livre = false
					break
			if livre:
				lugar = cand
				break
		if lugar.size == Vector2.ZERO:
			continue
		ocupados.append(lugar)
		match tipo:
			&"edicula":
				_edicula(sup, ob, colisao, lugar, direcao, tinta, r, cx, cz)
			&"galpao":
				_galpao(sup, ob, colisao, lugar, direcao, tinta, r, cx, cz)
			_:
				_galinheiro(ob, colisao, lugar, direcao, r, cx, cz)
	_pomar(sup, ob, lim, ocupados, r, cx, cz)
	ob.despejar(sup)
	return 1


## A altura do chao (Relevo) em cada canto da pegada: (mais alto, mais baixo).
static func _chao(cx: int, cz: int, lugar: Rect2) -> Vector2:
	var alto := -INF
	var baixo := INF
	for p: Vector2 in [lugar.position, Vector2(lugar.end.x, lugar.position.y), lugar.end,
			Vector2(lugar.position.x, lugar.end.y), lugar.get_center()]:
		var y := Relevo.local(cx, cz, Vector3(p.x, 0.0, p.y))
		alto = maxf(alto, y)
		baixo = minf(baixo, y)
	return Vector2(alto, baixo)


## Paredes (caixa sem tampa), embasamento de pedra na ladeira, colisao, e o
## telhado do TelhadoVivo. Devolve (chao da construcao, normal da frente).
static func _casca(sup: Dictionary, ob: Obra, colisao: Array[Dictionary], lugar: Rect2,
		direcao: int, altura: float, material: StringName, cor: Color, telha: StringName,
		beiral: float, quatro_aguas: bool, r: RandomNumberGenerator, cx: int, cz: int) -> float:
	var chao := _chao(cx, cz, lugar)
	var y0 := chao.x + 0.12
	var normal := KitModular._normal(direcao)
	var centro := Vector3(lugar.get_center().x, 0.0, lugar.get_center().y)
	var giro := atan2(normal.x, normal.z)
	# A caixa desce ate o chao mais baixo; a faixa de pedra cobre o degrau.
	var pe := chao.y - 0.2
	ob.caixa(material, centro + Vector3(0.0, (pe + y0 + altura) * 0.5, 0.0),
		Vector3(lugar.size.x, y0 + altura - pe, lugar.size.y), cor, 0.0,
		PSXMesh.FACE_TODAS & ~(PSXMesh.FACE_TOPO | PSXMesh.FACE_BASE))
	if y0 - chao.y > 0.2:
		ob.caixa(&"pedra_embasamento", centro + Vector3(0.0, (pe + y0) * 0.5, 0.0),
			Vector3(lugar.size.x + 0.06, y0 - pe, lugar.size.y + 0.06), PEDRA, 0.0,
			PSXMesh.FACE_TODAS & ~(PSXMesh.FACE_TOPO | PSXMesh.FACE_BASE))
	colisao.append({"tamanho": Vector3(lugar.size.x, y0 + altura - pe, lugar.size.y),
		"pos": centro + Vector3(0.0, (pe + y0 + altura) * 0.5, 0.0)})
	# O telhado. A caixa inteira e a "massa" do TelhadoVivo: ele poe a fachada
	# AVANCO_FACHADA a frente do meio, entao o topo recua meio avanco.
	var fundura := absf(lugar.size.x * normal.x) + absf(lugar.size.y * normal.z)
	var larg := absf(lugar.size.x * normal.z) + absf(lugar.size.y * normal.x)
	var plano := {"estilo": &"popular", "morador": &"familia", "andares": 1,
		"cor_corpo": cor if material == &"reboco" else Color("b8a898"),
		"telhado": TelhadoVivo.simples(telha, beiral, r.randi()),
		"quinas": [-1.0, 1.0] if quatro_aguas and larg >= fundura + 1.0 else []}
	var topo := centro - normal * (ChunkBuilder.AVANCO_FACHADA * 0.5) + Vector3(0.0, y0 + altura, 0.0)
	var tam := Vector3(lugar.size.x, 0.0, lugar.size.y) - normal.abs() * ChunkBuilder.AVANCO_FACHADA
	TelhadoVivo.montar(sup, plano, topo, tam, direcao)
	return y0


## Edicula de aluguel: reboco pintado ou tijolo, porta e janela na frente.
static func _edicula(sup: Dictionary, ob: Obra, colisao: Array[Dictionary], lugar: Rect2,
		direcao: int, tinta: Color, r: RandomNumberGenerator, cx: int, cz: int) -> void:
	var tijolo := r.randf() < 0.35
	var cor := FachadaViva.PAREDES[&"popular"][r.randi() % 6] as Color
	cor = cor.lerp(tinta, 0.25)
	var y0 := _casca(sup, ob, colisao, lugar, direcao, 2.8, &"tijolo" if tijolo else &"reboco",
		Color.WHITE if tijolo else cor, &"capa_canal" if r.randf() < 0.6 else &"francesa",
		0.4, r.randf() < 0.5, r, cx, cz)
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)
	var fundura := absf(lugar.size.x * normal.x) + absf(lugar.size.y * normal.z)
	var larg := absf(lugar.size.x * normal.z) + absf(lugar.size.y * normal.x)
	var frente := Vector3(lugar.get_center().x, y0, lugar.get_center().y) + normal * (fundura * 0.5 + 0.012)
	var x_porta := r.randf_range(-larg * 0.3, larg * 0.3)
	ob.placa(&"porta", frente + lateral * x_porta + Vector3(0.0, 1.0, 0.0), Vector2(0.8, 2.0), giro,
		Color.WHITE.lerp(Color("6a7a8a"), r.randf()))
	var x_jan := x_porta + (1.3 if x_porta < 0.0 else -1.3)
	if absf(x_jan) < larg * 0.5 - 0.6:
		ob.placa(&"janela_apagada", frente + lateral * x_jan + Vector3(0.0, 1.55, 0.0),
			Vector2(0.9, 0.9), giro)
	# Degrau de cimento na porta.
	ob.caixa(&"concreto", frente + lateral * x_porta + normal * 0.2 + Vector3(0.0, -0.06, 0.0),
		Vector3(1.1, 0.12, 0.4), Color(0.7, 0.69, 0.66), giro)


## Galpao de fundo: tijolo ou reboco cru, portao de tabua de duas folhas, e a
## telha de fibrocimento ou de barro.
static func _galpao(sup: Dictionary, ob: Obra, colisao: Array[Dictionary], lugar: Rect2,
		direcao: int, tinta: Color, r: RandomNumberGenerator, cx: int, cz: int) -> void:
	var tijolo := r.randf() < 0.5
	var cor := Color("cbc6be").lerp(tinta, 0.2)
	var y0 := _casca(sup, ob, colisao, lugar, direcao, r.randf_range(3.2, 4.2),
		&"tijolo" if tijolo else &"reboco", Color.WHITE if tijolo else cor,
		&"fibrocimento" if r.randf() < 0.55 else &"capa_canal", 0.35, false, r, cx, cz)
	var normal := KitModular._normal(direcao)
	var giro := atan2(normal.x, normal.z)
	var fundura := absf(lugar.size.x * normal.x) + absf(lugar.size.y * normal.z)
	var frente := Vector3(lugar.get_center().x, y0, lugar.get_center().y) + normal * (fundura * 0.5 + 0.012)
	ob.placa(&"tabua", frente + Vector3(0.0, 1.3, 0.0), Vector2(2.6, 2.6), giro,
		Color("7a5a3a").lerp(Color("4a6a5a"), r.randf() * 0.6))
	ob.caixa(&"tabua", frente + normal * 0.03 + Vector3(0.0, 1.3, 0.0), Vector3(0.06, 2.6, 0.04),
		Color("3a2a1a"), giro)


## Galinheiro: mureta de tijolo, pilares de madeira e meia-agua de fibrocimento.
static func _galinheiro(ob: Obra, colisao: Array[Dictionary], lugar: Rect2, direcao: int,
		r: RandomNumberGenerator, cx: int, cz: int) -> void:
	var chao := _chao(cx, cz, lugar)
	var y0 := chao.x + 0.05
	var centro := Vector3(lugar.get_center().x, 0.0, lugar.get_center().y)
	var mureta := 0.9
	var pe := chao.y - 0.15
	for lado: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var meio := centro + Vector3(lado.x * (lugar.size.x * 0.5 - 0.06), 0.0,
			lado.y * (lugar.size.y * 0.5 - 0.06))
		var tam := Vector3(0.12 if lado.x != 0.0 else lugar.size.x, y0 + mureta - pe,
			0.12 if lado.y != 0.0 else lugar.size.y)
		ob.caixa(&"tijolo", meio + Vector3(0.0, (pe + y0 + mureta) * 0.5, 0.0), tam, Color.WHITE)
	colisao.append({"tamanho": Vector3(lugar.size.x, y0 + mureta - pe, lugar.size.y),
		"pos": centro + Vector3(0.0, (pe + y0 + mureta) * 0.5, 0.0)})
	# Pilares nos quatro cantos e a meia-agua caindo para um lado.
	var alto := 2.1
	var cai := 0.35
	var sx := lugar.size.x * 0.5 - 0.1
	var sz := lugar.size.y * 0.5 - 0.1
	for c: Vector2 in [Vector2(-sx, -sz), Vector2(sx, -sz), Vector2(sx, sz), Vector2(-sx, sz)]:
		var h := alto + (cai if c.y < 0.0 else 0.0)
		ob.caixa(&"tabua", centro + Vector3(c.x, y0 + h * 0.5, c.y), Vector3(0.1, h, 0.1),
			Color("6a4a30"))
	var tom := TelhadoVivo.FIBRO.darkened(r.randf_range(0.0, 0.25))
	var a := centro + Vector3(-sx - 0.25, y0 + alto + cai + 0.05, -sz - 0.25)
	var b := centro + Vector3(sx + 0.25, y0 + alto + cai + 0.05, -sz - 0.25)
	var c2 := centro + Vector3(sx + 0.25, y0 + alto + 0.05, sz + 0.25)
	var d := centro + Vector3(-sx - 0.25, y0 + alto + 0.05, sz + 0.25)
	var n := (b - a).cross(d - a).normalized()
	if n.y < 0.0:
		n = -n
	ob.quadra(&"metal_ondulado", a, b, c2, d, n, (d - a).normalized(), a, tom)
	ob.quadra(&"metal_ondulado", a, b, c2, d, -n, (d - a).normalized(), a, tom.darkened(0.3))


## Pomar e horta nos vaos: mangueira, jabuticabeira, abacateiro, e os canteiros
## de tijolo com a verdura; capim em tufo por cima da terra.
static func _pomar(sup: Dictionary, ob: Obra, lim: Rect2, ocupados: Array[Rect2],
		r: RandomNumberGenerator, cx: int, cz: int) -> void:
	var area := lim.grow(-3.0)
	var arvores := 0
	for _tentativa in 16:
		if arvores >= (r.randi_range(3, 6) if Vegetacao.ativo else r.randi_range(2, 5)):
			break
		var p := Vector2(r.randf_range(area.position.x, area.end.x),
			r.randf_range(area.position.y, area.end.y))
		var livre := true
		for o: Rect2 in ocupados:
			if o.grow(3.0).has_point(p):
				livre = false
				break
		if not livre:
			continue
		ocupados.append(Rect2(p - Vector2(1.5, 1.5), Vector2(3.0, 3.0)))
		var arvore_rng := RandomNumberGenerator.new()
		arvore_rng.seed = r.randi()
		var descartavel: Array[Dictionary] = []
		var y := Relevo.local(cx, cz, Vector3(p.x, 0.0, p.y))
		var porte := r.randf_range(0.25, 0.7)
		if Vegetacao.ativo:
			# A arvore de quintal de Minas (Vegetacao): a mangueira que passa do
			# telhado, o abacateiro, a jaqueira, o ipe; e no canto, a touceira de
			# bananeira, o coqueiro ou o bambu.
			var sorte := arvore_rng.randf()
			var chao := Vector3(p.x, y, p.y)
			if sorte < 0.62:
				Vegetacao.arvore(sup, descartavel, chao, Vegetacao.especie_de_quintal(arvore_rng),
					porte + 0.25, arvore_rng)
			elif sorte < 0.82:
				Vegetacao.bananeira(sup, chao, arvore_rng)
			elif sorte < 0.93:
				Vegetacao.palmeira(sup, descartavel, chao, false, arvore_rng)
			else:
				Vegetacao.bambu(sup, chao, arvore_rng)
		else:
			KitParque.arvore(sup, descartavel, Vector3(p.x, y, p.y), porte, arvore_rng)
		arvores += 1
	# Canteiros de horta: tijolo em pe em volta da terra e a verdura em cartao.
	if r.randf() < 0.6:
		for _tentativa in 8:
			var p := Vector2(r.randf_range(area.position.x, area.end.x - 3.0),
				r.randf_range(area.position.y, area.end.y - 1.2))
			var canteiro := Rect2(p, Vector2(3.0, 1.1))
			var livre := true
			for o: Rect2 in ocupados:
				if o.grow(1.0).intersects(canteiro):
					livre = false
					break
			if not livre:
				continue
			ocupados.append(canteiro)
			for k in r.randi_range(2, 3):
				var c := canteiro.get_center() + Vector2(0.0, (float(k) - 1.0) * 1.4)
				var y := Relevo.local(cx, cz, Vector3(c.x, 0.0, c.y))
				ob.caixa(&"tijolo", Vector3(c.x, y + 0.1, c.y), Vector3(3.0, 0.26, 1.0), Color.WHITE)
				ob.caixa(&"terra", Vector3(c.x, y + 0.235, c.y), Vector3(2.84, 0.01, 0.84),
					Color(0.5, 0.4, 0.3), 0.0, PSXMesh.FACE_TOPO)
				for f in 6:
					var t := Transform3D(Basis(Vector3.UP, r.randf() * PI),
						Vector3(c.x + (float(f) - 2.5) * 0.45, y + 0.42, c.y))
					ob.cartao(JanelaViva._p(&"folhagem_recorte"), Vector2(0.4, 0.4), t,
						Carroceria.uv(Vector2i(0, 0)), Color(0.55, 0.85, 0.45), 1)
			break
	# Capim em tufo pela terra, perto: da janela do beco e do mirante ele some.
	for k in 26:
		var p := Vector2(r.randf_range(lim.position.x + 1.0, lim.end.x - 1.0),
			r.randf_range(lim.position.y + 1.0, lim.end.y - 1.0))
		var dentro := false
		for o: Rect2 in ocupados:
			if o.grow(0.3).has_point(p):
				dentro = true
				break
		if dentro:
			continue
		var y := Relevo.local(cx, cz, Vector3(p.x, 0.0, p.y))
		var t := Transform3D(Basis(Vector3.UP, r.randf() * PI), Vector3(p.x, y + 0.22, p.y))
		ob.cartao(JanelaViva._p(&"flor"), Vector2(0.7, 0.45), t, Carroceria.uv(Vector2i(4, 0)),
			Color(0.8, 0.95, 0.65), 1)

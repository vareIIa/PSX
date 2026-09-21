## O relevo da cidade: a ladeira.
##
## Por que existe
## -------------
## Cidade de Minas nao e plana. A rua sobe para a igreja, desce para o corrego,
## e a fileira de casas acompanha em degraus — uma casa meio metro acima da
## vizinha, o embasamento de pedra aparecendo do lado de baixo. Uma cidade
## inteira no mesmo plano le como maquete, por mais que a rua tenha T e o predio
## tenha telha.
##
## Como e feito
## ------------
## Funcao pura da coordenada, como a malha: `altura(x, z)` e a interpolacao
## bilinear de alturas nos NOS da grade (os cantos dos chunks). Bilinear e nao
## suave de proposito: ao longo de uma linha de rua ela e linear, entao a rua
## sobe reta entre duas esquinas, e o ponto de marcha interpolado pelo pedestre
## (Rotas) cai exatamente no chao.
##
## A altura dos nos vem dos morros (Morros): o morro da matriz com a praca no
## topo em y = 0, os outros morros e os vales entre eles. Por cima disso entram
## o aterro da avenida (`_aterrada`) e dois nivelamentos, porque ha lugar que
## tem de ser plano no meio do morro:
##
##   parque     o parque inteiro vira patamar na altura media do terreno dele
##              (e os parques que dividem um no se nivelam juntos); a rua em volta
##              desce ou sobe ate o terreno em ALCANCE_PARQUE nos. O ParqueBuilder
##              monta tudo plano e o chunk ergue inteiro. O grupo que contem a
##              Praca da Matriz fica em y = 0: e cenario de cutscene com camera
##              cravada em coordenada de mundo.
##   patamar    o chunk onde se entra andando (bar, casa da fumaca): os quatro
##              cantos tomam a media deles.
##
## Quem usa
## --------
## O chao (rua, calcada, meio-fio, marcacao) e deformado vertice a vertice
## (`deformar`). O que tem de ficar em pe — predio, muro, poste, placa — sobe
## RIGIDO pela altura do proprio ponto (`erguer`), senao a janela entortava com
## a rua. A colisao do chao vira um mapa de alturas (`mapa_de_colisao`).
class_name Relevo
extends RefCounted

const TAM := MalhaUrbana.TAM
## Ate onde o nivel de um parque puxa o chao em volta, em nos.
const ALCANCE_PARQUE := 5
## Quantos parques encostados (que dividem no) se nivelam juntos, no maximo.
const GRUPO_MAXIMO := 6
## Um chunk da Praca da Matriz. O grupo de parque que o contem fica em y = 0.
const CHUNK_PRACA := Vector2i(8, -2)
## Meia janela do aterro da avenida, em nos (`_aterrada`).
const JANELA_AVENIDA := 3
## Mapa de colisao do chao: um ponto a cada meio metro, bordas inclusas. Meio
## metro e o degrau do meio-fio virando rampa curta, como a caixa de rampa
## fazia no chao plano; um metro deixava o carro subir na calcada sem sentir.
const PASSO_MAPA := 0.5
const LADO_MAPA := 65
## Caixa de colisao mais baixa que isto e laje de chao (a laje de 32 m, a
## calcada, a rampa do meio-fio, o piso do beco): com relevo quem faz o papel
## dela e o mapa de alturas.
const LAJE := 0.45
## Altura minima de canto de chunk para ele contar como inclinado.
const QUASE_ZERO := 0.002
## Quanto o embasamento do lote desce abaixo do chao, no minimo, e a cor dele:
## pedra escurecida, que e o que o morro mostra por baixo da casa. Na encosta
## forte ele desce mais (`embasamento`, parametro `fundo_pedra`).
const EMBASAMENTO := 1.8
const COR_EMBASAMENTO := Color(0.62, 0.6, 0.56)

## Chave de bancada: desligado, a cidade volta a ser plana. O jogo nunca mexe.
static var ativo := true

static var _cache: Dictionary = {}
## No -> altura com o parque nivelado, antes do patamar. O patamar pede os
## quatro cantos do chunk dele, e cada canto e pedido por quatro chunks.
static var _niveladas: Dictionary = {}
## Id de quadra de parque -> nivel do grupo dela.
static var _niveis: Dictionary = {}
## Chunk -> e parque. O nivelamento pergunta isto 64 vezes por no, e montar a
## quadra inteira para cada pergunta custava meio milissegundo por no.
static var _parques: Dictionary = {}
## Chunk -> tem patamar. Cada chunk e perguntado pelos quatro nos dele.
static var _patamares: Dictionary = {}
static var _trava := Mutex.new()


# --- consulta ---------------------------------------------------------------

## Altura do chao no ponto (x, z) do mundo, em metros.
static func altura(x: float, z: float) -> float:
	if not ativo:
		return 0.0
	var fx := x / TAM
	var fz := z / TAM
	var i := floori(fx)
	var j := floori(fz)
	var tx := fx - float(i)
	var tz := fz - float(j)
	var h00 := no(i, j)
	var h10 := no(i + 1, j)
	var h01 := no(i, j + 1)
	var h11 := no(i + 1, j + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Altura num ponto LOCAL do chunk (cx, cz).
static func local(cx: int, cz: int, p: Vector3) -> float:
	return altura(float(cx) * TAM + p.x, float(cz) * TAM + p.z)


## O chunk esta no plano em y = 0? Entao ele segue o caminho antigo, intocado:
## chao de caixas, nada deformado, nada erguido. E a Praca da Matriz inteira, e
## a cutscene continua com as coordenadas dela.
static func plano(cx: int, cz: int) -> bool:
	if not ativo:
		return true
	return absf(no(cx, cz)) < QUASE_ZERO and absf(no(cx + 1, cz)) < QUASE_ZERO \
		and absf(no(cx, cz + 1)) < QUASE_ZERO and absf(no(cx + 1, cz + 1)) < QUASE_ZERO


## Altura do no de grade (i, j), o canto do chunk (i, j).
static func no(i: int, j: int) -> float:
	var chave := Vector2i(i, j)
	_trava.lock()
	var achada: Variant = _cache.get(chave)
	_trava.unlock()
	if achada != null:
		return float(achada)
	var h := _aterrada(i, j)
	_trava.lock()
	if _cache.size() > 20000:
		_cache.clear()
	_cache[chave] = h
	_trava.unlock()
	return h


# --- o chunk ----------------------------------------------------------------

## Quantos vertices cada material do chunk ja tem. E a marca de onde comeca o
## que for emitido depois — ver `deformar` e `erguer`.
static func marcar(sup: Dictionary) -> Dictionary:
	var m := {}
	for mat: StringName in sup:
		m[mat] = (sup[mat]["v"] as PackedVector3Array).size()
	return m


## O chao emitido desde a marca segue o relevo, vertice a vertice.
static func deformar(sup: Dictionary, marca: Dictionary, cx: int, cz: int) -> void:
	if not ativo:
		return
	var ox := float(cx) * TAM
	var oz := float(cz) * TAM
	# Dentro do chunk a bilinear e dos quatro cantos dele: conta local, sem ir ao
	# cache para cada vertice. Fora (a mobilia do cruzamento em coordenada
	# negativa, a copa que passa da borda), a conta geral.
	var h00 := no(cx, cz)
	var h10 := no(cx + 1, cz)
	var h01 := no(cx, cz + 1)
	var h11 := no(cx + 1, cz + 1)
	for mat: StringName in sup:
		var v: PackedVector3Array = sup[mat]["v"]
		var de := int(marca.get(mat, 0))
		for k in range(de, v.size()):
			var p := v[k]
			if p.x >= 0.0 and p.x <= TAM and p.z >= 0.0 and p.z <= TAM:
				var tx := p.x / TAM
				var tz := p.z / TAM
				p.y += lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)
			else:
				p.y += altura(ox + p.x, oz + p.z)
			v[k] = p
		sup[mat]["v"] = v


## Tudo o que foi emitido desde a marca — malha, colisao e props — sobe `dy`,
## rigido. E o predio, o muro, o poste: coisa que fica em pe no nivel dele.
static func erguer(sup: Dictionary, marca: Dictionary, colisao: Array[Dictionary],
		c0: int, props: Array[Dictionary], p0: int, dy: float) -> void:
	if not ativo or absf(dy) < 0.0005:
		return
	for mat: StringName in sup:
		var v: PackedVector3Array = sup[mat]["v"]
		var de := int(marca.get(mat, 0))
		for k in range(de, v.size()):
			v[k] = v[k] + Vector3(0.0, dy, 0.0)
		sup[mat]["v"] = v
	for k in range(c0, colisao.size()):
		if colisao[k].has("pos"):
			colisao[k]["pos"] = Vector3(colisao[k]["pos"]) + Vector3(0.0, dy, 0.0)
	for k in range(p0, props.size()):
		_erguer_prop(props[k], dy)


## Um prop sobe `dy`: a posicao, a soleira do morador, a rota de quem anda
## pelo lugar (frequentador do bar, convidado da praca) e a planta quando ele
## monta um interior. Sao as chaves de posicao que os builders de chunk usam.
static func _erguer_prop(p: Dictionary, dy: float) -> void:
	var sobe := Vector3(0.0, dy, 0.0)
	for chave: String in ["pos", "soleira"]:
		if p.has(chave) and p[chave] is Vector3:
			p[chave] = Vector3(p[chave]) + sobe
	if p.has("pontos"):
		var rota: Variant = p["pontos"]
		if rota is PackedVector3Array:
			var nova := PackedVector3Array(rota)
			for k in nova.size():
				nova[k] += sobe
			p["pontos"] = nova
		elif rota is Array:
			# `duplicate` guarda a tipagem: quem le espera Array[Vector3].
			var nova: Array = (rota as Array).duplicate()
			for k in nova.size():
				if nova[k] is Vector3:
					nova[k] = Vector3(nova[k]) + sobe
			p["pontos"] = nova
	if p.has("planta"):
		var t: Transform3D = p["planta"]
		t.origin.y += dy
		p["planta"] = t


## Assenta no relevo o que foi emitido desde a marca e que acompanha o chao:
## o chao da rua, o muro de quintal, o beco, a vila, o baldio, o galpao do
## miolo. A malha vai vertice a vertice, entao nada flutua nem enterra (parede
## vertical continua vertical: o topo e o pe dela tem o mesmo x e z). A laje de
## colisao sai, porque o mapa de alturas ja e o chao dela; a caixa alta sobe e
## estica para baixo ate o ponto mais baixo do chao sob ela. O prop sobe pela
## altura do proprio ponto.
static func assentar(sup: Dictionary, marca: Dictionary, colisao: Array[Dictionary],
		c0: int, props: Array[Dictionary], p0: int, cx: int, cz: int) -> void:
	if not ativo:
		return
	deformar(sup, marca, cx, cz)
	var k := colisao.size() - 1
	while k >= c0:
		var c: Dictionary = colisao[k]
		if c.has("tamanho"):
			if Vector3(c["tamanho"]).y <= LAJE:
				colisao.remove_at(k)
			else:
				_assentar_caixa(c, cx, cz)
		k -= 1
	for n in range(p0, props.size()):
		if props[n].has("pos"):
			_erguer_prop(props[n], local(cx, cz, props[n]["pos"]))


## Uma caixa alta sobre o chao inclinado: o topo sobe pela altura do centro, o
## pe desce ate o canto mais baixo. Caixa girada (muro de lote) so sobe.
static func _assentar_caixa(c: Dictionary, cx: int, cz: int) -> void:
	var p: Vector3 = c["pos"]
	var t: Vector3 = c["tamanho"]
	var no_meio := local(cx, cz, p)
	if c.has("giro"):
		c["pos"] = p + Vector3(0.0, no_meio, 0.0)
		return
	var mais_baixo := no_meio
	for canto: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		mais_baixo = minf(mais_baixo, local(cx, cz,
			p + Vector3(canto.x * t.x * 0.5, 0.0, canto.y * t.z * 0.5)))
	var topo := p.y + t.y * 0.5 + no_meio
	var pe := p.y - t.y * 0.5 + mais_baixo
	c["tamanho"] = Vector3(t.x, topo - pe, t.z)
	c["pos"] = Vector3(p.x, (topo + pe) * 0.5, p.z)


## Um trecho de dentro de um lote rigido que, na verdade, acompanha o chao: o
## jardim da casa recuada, a guia rebaixada na frente do portao. O lote inteiro
## ja subiu `dy` (`erguer`); o trecho devolve o `dy` e sobe pelo chao de cada
## vertice. A colisao dele segue a regra de `assentar`.
static func reassentar(sup: Dictionary, de: Dictionary, ate: Dictionary,
		colisao: Array[Dictionary], c_de: int, c_ate: int, cx: int, cz: int,
		dy: float) -> void:
	if not ativo:
		return
	for mat: StringName in ate:
		if not sup.has(mat):
			continue
		var v: PackedVector3Array = sup[mat]["v"]
		for k in range(int(de.get(mat, 0)), int(ate[mat])):
			var p := v[k]
			p.y += local(cx, cz, p) - dy
			v[k] = p
		sup[mat]["v"] = v
	var k := c_ate - 1
	while k >= c_de:
		var c: Dictionary = colisao[k]
		if c.has("tamanho"):
			c["pos"] = Vector3(c["pos"]) - Vector3(0.0, dy, 0.0)
			if Vector3(c["tamanho"]).y <= LAJE:
				colisao.remove_at(k)
			else:
				_assentar_caixa(c, cx, cz)
		k -= 1


## O embasamento de pedra sob um lote que sobe rigido: do topo da calcada ate
## EMBASAMENTO abaixo do chao, com a frente quatro centimetros a frente da
## fachada. No lado de cima da ladeira ele fica enterrado; no de baixo e a
## faixa de pedra entre a calcada e a parede, que e como a casa de morro fica
## em pe. Emitido ANTES de `erguer`, junto com o lote.
##
## `frente` e o meio da linha da fachada, no chao; `fundo`, a profundidade;
## `avanco`, quanto a fachada fica a frente dessa linha.
static func embasamento(sup: Dictionary, frente: Vector3, normal: Vector3,
		larg: float, fundo: float, avanco_fachada: float,
		fundo_pedra: float = EMBASAMENTO) -> void:
	var h := KitModular.ALTURA_MEIO_FIO
	var avanco := avanco_fachada + 0.1
	# Tres centimetros para fora nos lados e no fundo: rente, as faces dele e as
	# da massa do predio disputavam o mesmo pixel nos 16 cm de baixo.
	var prof := fundo + avanco + 0.03
	var largo := larg + 0.06
	var centro := frente + normal * (avanco - prof * 0.5) \
		+ Vector3(0.0, (h - fundo_pedra) * 0.5, 0.0)
	var tam := Vector3(largo, h + fundo_pedra, prof) if absf(normal.z) > 0.5 \
		else Vector3(prof, h + fundo_pedra, largo)
	KitModular.caixa_cor(sup, &"pedra_parque", centro, tam, COR_EMBASAMENTO, 0.0,
		PSXMesh.FACE_TODAS & ~(PSXMesh.FACE_TOPO | PSXMesh.FACE_BASE), 4.0)


## As caixas de colisao emitidas desde `c0`, cada uma pela altura do proprio
## centro. Para o que e deformado vertice a vertice (muro de quintal, entulho):
## a caixa nao entorta, entao sobe pelo meio.
static func erguer_caixas(colisao: Array[Dictionary], c0: int, cx: int, cz: int) -> void:
	if not ativo:
		return
	for k in range(c0, colisao.size()):
		if colisao[k].has("pos"):
			var p: Vector3 = colisao[k]["pos"]
			colisao[k]["pos"] = p + Vector3(0.0, local(cx, cz, p), 0.0)


## O mapa de alturas da colisao do chao do chunk: o asfalto na altura do
## relevo, a calcada e a quadra dezesseis centimetros acima. O degrau do
## meio-fio vira rampa de meio metro sozinho, entre um ponto e o seguinte — que
## e o que as caixas de rampa faziam a mao no chao plano.
##
## Dentro de parque o mapa desce: o chao de la e colisao propria do
## ParqueBuilder (e o lago e um buraco nele). Nos retangulos de `rebaixar` —
## o salao do bar, a casa da fumaca, onde se entra andando — ele desce tambem:
## o piso de la e plano e rigido, e o chao inclinado atravessaria o salao pelo
## lado de cima da ladeira.
##
## O Godot so aceita mapa de um ponto por unidade, entao o mapa sai com os
## pontos a um metro e a forma encolhe pela metade (`escala`), com as alturas
## dobradas para compensar.
static func mapa_de_colisao(cx: int, cz: int, bordas: Dictionary, lim: Rect2,
		parque: bool, rebaixar: Array[Rect2] = []) -> Dictionary:
	var px0 := MalhaUrbana.meia_asfalto(bordas["x0"])
	var px1 := MalhaUrbana.meia_asfalto(bordas["x1"])
	var pz0 := MalhaUrbana.meia_asfalto(bordas["z0"])
	var pz1 := MalhaUrbana.meia_asfalto(bordas["z1"])
	var h := KitModular.ALTURA_MEIO_FIO
	var dados := PackedFloat32Array()
	dados.resize(LADO_MAPA * LADO_MAPA)
	for iz in LADO_MAPA:
		for ix in LADO_MAPA:
			var x := float(ix) * PASSO_MAPA
			var z := float(iz) * PASSO_MAPA
			var asfalto := (px0 > 0.05 and x <= px0) or (px1 > 0.05 and x >= TAM - px1) \
				or (pz0 > 0.05 and z <= pz0) or (pz1 > 0.05 and z >= TAM - pz1)
			var y := local(cx, cz, Vector3(x, 0.0, z))
			if not asfalto:
				y += h
				if parque and lim.grow(-0.5).has_point(Vector2(x, z)):
					y -= 3.0
				for r: Rect2 in rebaixar:
					if r.grow(-0.1).has_point(Vector2(x, z)):
						y -= 2.0
						break
			dados[iz * LADO_MAPA + ix] = y / PASSO_MAPA
	return {"altura": dados, "lado": LADO_MAPA, "escala": PASSO_MAPA,
		"pos": Vector3(TAM * 0.5, 0.0, TAM * 0.5)}


# --- ruido e mascara ----------------------------------------------------------

## Altura do terreno no no, antes de qualquer nivelamento.
static func _terreno(i: int, j: int) -> float:
	return Morros.bruto(i, j)


## Altura do no com o parque nivelado, antes do aterro da avenida e do patamar.
##
## O no que encosta em parque fica no nivel dele. Ate ALCANCE_PARQUE nos de
## distancia o chao vai do nivel do parque ao terreno: e a rua em volta da
## praca que sobe ou desce ate o bairro.
##
## Todos os parques do alcance entram, com peso, e nao so o mais perto. Com o
## mais perto, dois nos vizinhos que viam parques diferentes pegavam niveis
## diferentes, e a avenida entre dois parques chegava a 42% num chunk so.
static func _nivelada(i: int, j: int) -> float:
	var chave := Vector2i(i, j)
	_trava.lock()
	var achada: Variant = _niveladas.get(chave)
	_trava.unlock()
	if achada != null:
		return float(achada)
	var terreno := _terreno(i, j)
	# Por nivel (um por grupo de parque, um por patamar): a maior influencia de
	# qualquer chunk dele.
	var influencia := {}
	var colado := false
	var colado_parque := false
	var nivel_colado := 0.0
	for dj in range(-ALCANCE_PARQUE - 1, ALCANCE_PARQUE + 1):
		for di in range(-ALCANCE_PARQUE - 1, ALCANCE_PARQUE + 1):
			var c := Vector2i(i + di, j + dj)
			var parque := _eh_parque(c)
			if not parque and not tem_patamar(c.x, c.y):
				continue
			# Distancia do no ate o quadrado de cantos do chunk c, em nos.
			var dx := maxi(0, maxi(c.x - i, i - (c.x + 1)))
			var dz := maxi(0, maxi(c.y - j, j - (c.y + 1)))
			var d := Vector2(float(dx), float(dz)).length()
			if d > float(ALCANCE_PARQUE):
				continue
			var nivel := _nivel_do_parque(c) if parque else _nivel_do_patamar(c)
			# O no colado fica no nivel da zona. Parque manda mais que patamar:
			# o parque inteiro tem de ser plano.
			if d == 0.0 and (parque and not colado_parque
					or not parque and not colado):
				colado_parque = colado_parque or parque
				colado = true
				nivel_colado = nivel
			var a := 1.0 - smoothstep(0.0, float(ALCANCE_PARQUE), d)
			if a > float(influencia.get(nivel, 0.0)):
				influencia[nivel] = a
	var h := terreno
	if colado:
		h = nivel_colado
	elif not influencia.is_empty():
		# O terreno pesa o quanto NENHUM parque o puxa; entre os parques, o
		# mais perto pesa muito mais (quarta potencia), sem salto entre nos.
		var livre := 1.0
		var soma := 0.0
		var pesos := 0.0
		for nivel: float in influencia:
			var a: float = influencia[nivel]
			livre *= 1.0 - a
			var w := a * a * a * a
			soma += nivel * w
			pesos += w
		h = lerpf(soma / pesos, terreno, livre)
	_trava.lock()
	if _niveladas.size() > 20000:
		_niveladas.clear()
	_niveladas[chave] = h
	_trava.unlock()
	return h


## O nivel do parque do chunk `c`: a media do terreno em todos os nos do grupo
## de parques encostados a ele. O grupo que contem a Praca da Matriz fica em 0.
##
## Grupo, e nao a quadra sozinha: dois parques separados por uma rua dividem os
## nos da rua, e cada um no seu nivel deixaria a rua com um degrau no meio. O
## grupo e o mesmo visto de qualquer membro (e a componente inteira, ate
## GRUPO_MAXIMO quadras), entao o nivel sai igual para todos eles.
static func _nivel_do_parque(c: Vector2i) -> float:
	var q := MalhaUrbana.quadra_de(c.x, c.y)
	var id: Variant = q["id"]
	_trava.lock()
	var achado: Variant = _niveis.get(id)
	_trava.unlock()
	if achado != null:
		return float(achado)
	var grupo: Array[Dictionary] = [q]
	var ids := {id: true}
	var k := 0
	while k < grupo.size() and grupo.size() < GRUPO_MAXIMO:
		var g := grupo[k]
		k += 1
		# O anel de chunks em volta da quadra: parque ali divide no com ela.
		for cz in range(int(g["z0"]) - 1, int(g["z1"]) + 1):
			for cx in range(int(g["x0"]) - 1, int(g["x1"]) + 1):
				if not _eh_parque(Vector2i(cx, cz)):
					continue
				var vizinha := MalhaUrbana.quadra_de(cx, cz)
				if ids.has(vizinha["id"]):
					continue
				ids[vizinha["id"]] = true
				grupo.append(vizinha)
	var nivel := 0.0
	var praca := false
	var soma := 0.0
	var n := 0
	for g: Dictionary in grupo:
		if CHUNK_PRACA.x >= int(g["x0"]) and CHUNK_PRACA.x < int(g["x1"]) \
				and CHUNK_PRACA.y >= int(g["z0"]) and CHUNK_PRACA.y < int(g["z1"]):
			praca = true
		for nj in range(int(g["z0"]), int(g["z1"]) + 1):
			for ni in range(int(g["x0"]), int(g["x1"]) + 1):
				soma += _terreno(ni, nj)
				n += 1
	if not praca and n > 0:
		nivel = soma / float(n)
	_trava.lock()
	if _niveis.size() > 4000:
		_niveis.clear()
	for g: Dictionary in grupo:
		_niveis[g["id"]] = nivel
	_trava.unlock()
	return nivel


## O nivel do chunk de patamar `c`: a media do terreno nos quatro cantos, ou o
## nivel do parque quando algum canto encosta num. O parque manda nos nos dele;
## sem herdar o nivel, o patamar ao lado de uma praca saia com um canto 1,5 m
## fora e o salao do bar ganhava degrau de novo. Le o terreno BRUTO: a altura
## nivelada dos cantos depende deste nivel.
static func _nivel_do_patamar(c: Vector2i) -> float:
	var soma := 0.0
	for canto: Vector2i in [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]:
		for vizinho: Vector2i in [canto + Vector2i(-1, -1), canto + Vector2i(0, -1),
				canto + Vector2i(-1, 0), canto]:
			if _eh_parque(vizinho):
				return _nivel_do_parque(vizinho)
		soma += _terreno(canto.x, canto.y)
	return soma * 0.25


## A altura do no com a avenida aterrada: nos de avenida tomam a media ao longo
## da propria linha (das duas, no cruzamento de duas avenidas), em janela
## triangular de JANELA_AVENIDA nos para cada lado. E a rua principal cortada no
## morro: sobe devagar, e quem fica ingreme e a travessa. Sem isto a avenida
## chegava a 32% no morro puro. Vem DEPOIS do parque para espalhar pela
## avenida a borda do patamar dele; o no que encosta em parque nao se mexe.
static func _aterrada(i: int, j: int) -> float:
	var em_x := MalhaUrbana.via_x(i) == MalhaUrbana.Via.AVENIDA
	var em_z := MalhaUrbana.via_z(j) == MalhaUrbana.Via.AVENIDA
	if (not em_x and not em_z) or _no_de_zona(i, j):
		return _nivelada(i, j)
	var soma := 0.0
	var peso := 0.0
	for k in range(-JANELA_AVENIDA, JANELA_AVENIDA + 1):
		var w := float(JANELA_AVENIDA + 1 - absi(k))
		if em_x:
			soma += _nivelada(i, j + k) * w
			peso += w
		if em_z:
			soma += _nivelada(i + k, j) * w
			peso += w
	return soma / peso


## O chunk de patamar que encosta neste no, se houver. Dois patamares vizinhos
## disputam o no do meio: fica o primeiro na ordem, e o outro sai quase plano.
static func _patamar(i: int, j: int) -> Variant:
	for c: Vector2i in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1),
			Vector2i(i - 1, j), Vector2i(i, j)]:
		if tem_patamar(c.x, c.y):
			return c
	return null


## O chunk tem lugar onde se entra andando? O bar e a casa da fumaca no mundo.
##
## O ChunkBuilder vem por carga tardia, e nao pelo nome. Citado pelo nome ele
## entra na compilacao deste script, e a cadeia dele (KitFumaca, os moveis, a
## televisao) chega a autoload. No `--script` o autoload ainda nao existe
## quando o script compila: a compilacao falhava e as variaveis estaticas daqui
## — a trava e o cache — ficavam nulas, com a cidade inteira plana.
static func tem_patamar(cx: int, cz: int) -> bool:
	var chave := Vector2i(cx, cz)
	_trava.lock()
	var achado: Variant = _patamares.get(chave)
	_trava.unlock()
	if achado != null:
		return bool(achado)
	var construtor: GDScript = load("res://src/world/chunk_builder.gd")
	var porta: Dictionary = construtor._porta_do_chunk(cx, cz,
		MalhaUrbana.quadra_de(cx, cz))
	var tem: bool = porta.get("interior", &"") == &"bar" or bool(porta.get("mundo", false))
	_trava.lock()
	if _patamares.size() > 40000:
		_patamares.clear()
	_patamares[chave] = tem
	_trava.unlock()
	return tem


## Ruido de valor em [-1, 1], suave. Morros usa para o miudo da encosta.
static func _valor(x: float, z: float, sal: int) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - float(ix)
	var fz := z - float(iz)
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sz := fz * fz * (3.0 - 2.0 * fz)
	var v00 := _aleatorio(ix, iz, sal)
	var v10 := _aleatorio(ix + 1, iz, sal)
	var v01 := _aleatorio(ix, iz + 1, sal)
	var v11 := _aleatorio(ix + 1, iz + 1, sal)
	return lerpf(lerpf(v00, v10, sx), lerpf(v01, v11, sx), sz)


static func _aleatorio(i: int, j: int, sal: int) -> float:
	return float(MalhaUrbana._ruido(i, j, 9001 + sal) % 20001) / 10000.0 - 1.0


## O no encosta em algum chunk de parque?
static func _no_de_parque(i: int, j: int) -> bool:
	for c: Vector2i in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1),
			Vector2i(i - 1, j), Vector2i(i, j)]:
		if _eh_parque(c):
			return true
	return false


## O no encosta em zona plana — parque ou patamar? O aterro da avenida nao mexe
## nele, senao a zona deixava de ser plana.
static func _no_de_zona(i: int, j: int) -> bool:
	for c: Vector2i in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1),
			Vector2i(i - 1, j), Vector2i(i, j)]:
		if _eh_parque(c) or tem_patamar(c.x, c.y):
			return true
	return false


static func _eh_parque(c: Vector2i) -> bool:
	_trava.lock()
	var achado: Variant = _parques.get(c)
	_trava.unlock()
	if achado != null:
		return bool(achado)
	var parque := int(MalhaUrbana.quadra_de(c.x, c.y)["uso"]) == MalhaUrbana.Uso.PARQUE
	_trava.lock()
	if _parques.size() > 40000:
		_parques.clear()
	_parques[c] = parque
	_trava.unlock()
	return parque

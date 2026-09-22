## O mirante: o parque no alto de um morro, e o terraco de onde se ve a cidade.
##
## Por que existe
## -------------
## Cidade de morro e cidade de vista. Sobe-se a ladeira para chegar no adro, no
## cruzeiro, no largo do alto, e de la se ve o casario descendo e a serra atras.
## O parque do alto do morro era igual ao do fundo do vale: gradil, cruz de
## caminho, banco virado para dentro. Nada dizia "chegou, olhe".
##
## O que um mirante tem
## --------------------
## Um parque e mirante quando o patamar dele (Relevo) e o alto do morro (nada do
## terreno ate RAIO nos em volta sobe mais que FOLGA acima dele) ou quando ele
## esta na encosta com vista: o chao para fora de uma das bordas desce
## QUEDA_ENCOSTA. A Praca da Matriz fica de fora (tem cena propria). O parque de
## traco PRACA e mirante (a nevoa abre) mas nao ganha terraco: ja tem igreja e
## casario na borda, e o adro dele e o mirante.
##
## Nos outros, na meia borda do parque com a maior queda para fora, o gradil da
## lugar a um terraco de pedra:
##
##     peitoril caiado com capa de pedra e pilastra a cada ~3 m, no lugar do gradil
##     piso de lajota de pedra, um pouco acima do calcamento dos caminhos
##     cruzeiro de madeira no pedestal de pedra, na ponta do canto, de frente
##       para a cidade: e a silhueta que se ve de baixo e diz onde fica o alto
##     bancos virados para FORA, para a vista
##     a luneta publica no meio do peitoril (Luneta: [E] para olhar)
##     lanterna de praca e placa com o nome
##
## E o no Mirante (runtime) abre a nevoa enquanto o jogador esta no parque.
##
## Como o ParqueBuilder, cada chunk percorre o terraco INTEIRO e desenha so o que
## cai dentro dele; todo sorteio e funcao pura do indice da peca.
##
## Coordenadas: metros da quadra, origem no canto (x0, z0), como `ParqueBuilder`.
## `desloc` traduz para o chunk.
class_name MiranteBuilder
extends RefCounted

const TAM := KitModular.CHUNK
## O parque e mirante no alto do morro (nenhum no do terreno ate RAIO nos dele
## sobe mais que FOLGA acima do patamar) ou na encosta, quando o chao para fora
## de uma das bordas desce QUEDA_ENCOSTA na media (a mesma medida do terraco).
## So o topo dava dois mirantes em 81 x 81 chunks.
const RAIO := 4
const FOLGA := 3.0
const QUEDA_ENCOSTA := 5.5
## A meia borda so vira terraco se o chao la fora desce ao menos isto, na media
## de tres pontos (30, 60 e 100 m para fora). Abaixo disso a "vista" e o telhado
## do vizinho. Borda que da para quadra edificada vale menos (PESO_EDIFICADA):
## a primeira fileira de casas e o que fecha a vista.
const QUEDA_MINIMA := 4.0
const PESO_EDIFICADA := 0.7
## Terraco: comprimento ao longo da borda e fundo para dentro do parque. O fundo
## para antes do anel de caminhada (5 m).
const COMPRIMENTO_MAXIMO := 24.0
const COMPRIMENTO_MINIMO := 13.0
const FUNDO := 4.2
## Folga do terraco ate o canto do parque e ate o vao do portao (a placa do
## parque fica 0,9 m alem do pilar do portao).
const RECUO_CANTO := 2.0
const RECUO_PORTAO := 3.2
## O terraco e ELEVADO: um bastiao de pedra sobre o parque. No chao do parque a
## primeira fileira de casas do outro lado da rua fechava a vista inteira (foto
## medida: sobrado de dois andares a 14 m, no mesmo nivel); ALTURA poe o olho a
## uns 4 m do chao, por cima do telhado terreo.
const ALTURA := 2.4
## A base do bastiao: a altura da colisao do parque (a calcada).
const BASE := KitModular.ALTURA_MEIO_FIO
## Escadaria de acesso, do lado do portao, dentro da faixa do terraco: espelho,
## piso e o patamar de chegada no chao.
const ESPELHO := 0.16
const PISADA := 0.3
const PATAMAR_BAIXO := 0.6
const COR_ARRIMO := Color(0.64, 0.6, 0.53)
const COR_PISO_ESCADA := Color(0.78, 0.76, 0.72)
## Lajota de 1,4 m: de quartzito, como o piso de adro. Com 1,15 o terraco
## sozinho passava de cem lajotas por chunk.
const LAJOTA := 1.4
const TOM_LAJOTA := Vector2(0.52, 0.64)
## Peitoril: muro caiado ate PEITORIL (KitParque.muro_caiado, com a capa de pedra
## por cima), pilastra a cada PASSO_PILASTRA.
const PEITORIL := 0.86
const MURO := KitParque.MURO_E
const PASSO_PILASTRA := 3.0
const PILASTRA := Vector3(0.46, 1.08, 0.46)
## Luneta publica: pintada de verde, com ocular de latao.
const COR_LUNETA := Color("2f5a4c")
const COR_LATAO := Color("a88a52")
const ALTURA_LUNETA := 1.26
## Nome de alto de cidade mineira. Sem acento: a fonte do Label3D nao tem.
const NOMES: Array[String] = ["MIRANTE DO CRUZEIRO", "ALTO DA BOA VISTA",
	"MIRANTE DA SERRA", "ALTO DA CRUZ", "ALTO DO ROSARIO", "MIRANTE DAS PEDRAS",
	"ALTO DE SANTANA", "MIRANTE DO VALE"]

static var _mirantes: Dictionary = {}
static var _terracos: Dictionary = {}
static var _trava := Mutex.new()


# --- consulta ---------------------------------------------------------------

## A quadra e mirante? Parque no alto do morro, fora a Praca da Matriz.
static func e_mirante(q: Dictionary) -> bool:
	if not Relevo.ativo or int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
		return false
	var id: Variant = q["id"]
	_trava.lock()
	var achado: Variant = _mirantes.get(id)
	_trava.unlock()
	if achado != null:
		return bool(achado)
	var sim := _medir_mirante(q)
	_trava.lock()
	if _mirantes.size() > 4000:
		_mirantes.clear()
	_mirantes[id] = sim
	_trava.unlock()
	return sim


static func _medir_mirante(q: Dictionary) -> bool:
	var x0 := int(q["x0"])
	var z0 := int(q["z0"])
	var x1 := int(q["x1"])
	var z1 := int(q["z1"])
	if Relevo.CHUNK_PRACA.x >= x0 and Relevo.CHUNK_PRACA.x < x1 \
			and Relevo.CHUNK_PRACA.y >= z0 and Relevo.CHUNK_PRACA.y < z1:
		return false
	var nivel := Relevo.no(x0, z0)
	if _queda_da_quadra(q, nivel) >= QUEDA_ENCOSTA:
		return true
	for j in range(z0 - RAIO, z1 + RAIO + 1):
		for i in range(x0 - RAIO, x1 + RAIO + 1):
			if Morros.bruto(i, j) > nivel + FOLGA:
				return false
	return true


## A maior queda para fora da quadra, pelo meio de cada uma das oito meias
## bordas (a conta do terraco, na borda da quadra em vez da do parque: a planta
## do parque pergunta pelo mirante, e perguntar pela planta aqui dava volta).
static func _queda_da_quadra(q: Dictionary, nivel: float) -> float:
	var r := Rect2(float(int(q["x0"])) * TAM, float(int(q["z0"])) * TAM,
		float(int(q["x1"]) - int(q["x0"])) * TAM, float(int(q["z1"]) - int(q["z0"])) * TAM)
	var melhor := 0.0
	var foras: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for lado in 4:
		for f: float in [0.25, 0.75]:
			var meio: Vector2
			match lado:
				0: meio = Vector2(lerpf(r.position.x, r.end.x, f), r.position.y)
				1: meio = Vector2(lerpf(r.position.x, r.end.x, f), r.end.y)
				2: meio = Vector2(r.position.x, lerpf(r.position.y, r.end.y, f))
				_: meio = Vector2(r.end.x, lerpf(r.position.y, r.end.y, f))
			var queda := 0.0
			for d: float in [30.0, 60.0, 100.0]:
				var p := meio + foras[lado] * d
				queda += nivel - Relevo.altura(p.x, p.y)
			melhor = maxf(melhor, queda / 3.0)
	return melhor


## O nome do mirante, para a placa, o mapa e a faixa de estado.
static func nome(q: Dictionary) -> String:
	# Ruido da quadra, e nao a semente dividida: a semente dos parques caia
	# metade no mesmo nome.
	return NOMES[MalhaUrbana._ruido(int(q["x0"]), int(q["z0"]), 6143) % NOMES.size()]


## O terraco do parque, ou vazio se ele nao tem. Em metros da quadra:
##
##     "a", "b"   pontas da borda de fora (a linha do gradil), de a para b
##     "fora"     normal da borda, para fora do parque
##     "rect"     o terraco inteiro (borda + FUNDO para dentro)
##     "giro"     giro de quem olha para fora (KitParque.banco, cruzeiro)
##     "queda"    quanto o chao desce la fora, em metros (medida da escolha)
##     "lado"     a borda do parque: 0 z minimo, 1 z maximo, 2 x minimo, 3 x maximo
static func terraco(quadra: Dictionary, plano: Dictionary) -> Dictionary:
	if int(plano["traco"]) == ParqueBuilder.Traco.PRACA or not e_mirante(quadra):
		return {}
	var id: Variant = quadra["id"]
	_trava.lock()
	var achado: Variant = _terracos.get(id)
	_trava.unlock()
	if achado != null:
		return achado
	var t := _escolher_terraco(quadra, plano)
	_trava.lock()
	if _terracos.size() > 4000:
		_terracos.clear()
	_terracos[id] = t
	_trava.unlock()
	return t


static func _escolher_terraco(quadra: Dictionary, plano: Dictionary) -> Dictionary:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var origem := Vector2(float(int(quadra["x0"])) * TAM, float(int(quadra["z0"])) * TAM)
	var nivel := Relevo.no(int(quadra["x0"]), int(quadra["z0"]))
	var vao := ParqueBuilder.LARGURA_CAMINHO * 1.6
	var melhor := {}
	var melhor_queda := -QUEDA_MINIMA
	# O que o terraco nao pode cobrir: os caminhos (o cerco do campo e do
	# parquinho passa a menos de FUNDO da borda em parque estreito) e o miolo.
	var ocupado: Array[Rect2] = []
	for faixa: Rect2 in ParqueBuilder.faixas_de_caminho(plano):
		if faixa.size.x > 0.0 and faixa.size.y > 0.0:
			ocupado.append(faixa)
	var miolo := ParqueBuilder._miolo_cercado(plano)
	if miolo.size.x > 0.0:
		ocupado.append(miolo.grow(ParqueBuilder.LARGURA_CAMINHO))
	# [ponto inicial da borda, direcao ao longo, normal para fora, comprimento,
	# onde fica o portao ao longo dela]
	var bordas := [
		[area.position, Vector2.RIGHT, Vector2.UP, area.size.x, centro.x - area.position.x],
		[Vector2(area.position.x, area.end.y), Vector2.RIGHT, Vector2.DOWN, area.size.x,
			centro.x - area.position.x],
		[area.position, Vector2.DOWN, Vector2.LEFT, area.size.y, centro.y - area.position.y],
		[Vector2(area.end.x, area.position.y), Vector2.DOWN, Vector2.RIGHT, area.size.y,
			centro.y - area.position.y],
	]
	for lado in bordas.size():
		var b: Array = bordas[lado]
		var inicio: Vector2 = b[0]
		var ao_longo: Vector2 = b[1]
		var fora: Vector2 = b[2]
		var comp: float = b[3]
		var portao: float = b[4]
		for metade: Vector2 in [Vector2(RECUO_CANTO, portao - vao * 0.5 - RECUO_PORTAO),
				Vector2(portao + vao * 0.5 + RECUO_PORTAO, comp - RECUO_CANTO)]:
			var livre := metade.y - metade.x
			if livre < COMPRIMENTO_MINIMO:
				continue
			var L := minf(COMPRIMENTO_MAXIMO, livre)
			var s0 := (metade.x + metade.y - L) * 0.5
			var a := inicio + ao_longo * s0
			var bb := inicio + ao_longo * (s0 + L)
			var meio := (a + bb) * 0.5
			var queda := 0.0
			for d: float in [30.0, 60.0, 100.0]:
				var p := origem + meio + fora * d
				queda += Relevo.altura(p.x, p.y) - nivel
			queda /= 3.0
			var defronte := origem + meio + fora * 14.0
			var frente := MalhaUrbana.quadra_de(floori(defronte.x / TAM), floori(defronte.y / TAM))
			if int(frente["uso"]) == MalhaUrbana.Uso.EDIFICADO:
				queda *= PESO_EDIFICADA
			var dentro := -fora * FUNDO
			var r := Rect2(a, Vector2.ZERO).expand(bb).expand(a + dentro).expand(bb + dentro)
			var livre_de_tudo := true
			for o: Rect2 in ocupado:
				if r.intersects(o):
					livre_de_tudo = false
			if livre_de_tudo and queda < melhor_queda:
				melhor_queda = queda
				# O canto do parque fica do lado de `inicio` na primeira metade e do
				# lado do fim na segunda: a ponta do canto leva o cruzeiro, a do
				# portao leva a escada.
				var canto_no_inicio := metade.x < portao
				melhor = {"a": a, "b": bb, "fora": fora, "rect": r,
					"ponta": a if canto_no_inicio else bb,
					"longe": bb if canto_no_inicio else a,
					"giro": atan2(fora.x, fora.y), "queda": -queda, "lado": lado}
	return melhor


## Onde o parque nao planta nem mobilia: o terraco e uma folga em volta.
static func zona(quadra: Dictionary, plano: Dictionary, folga: float) -> Rect2:
	var t := terraco(quadra, plano)
	if t.is_empty():
		return Rect2()
	return (t["rect"] as Rect2).grow(folga)




# --- montagem ---------------------------------------------------------------

## Monta o terraco do mirante que cai no chunk (cx, cz). Chamado pelo
## ParqueBuilder depois do parque, nos mesmos acumuladores.
##
## Na faixa do terraco (comprimento L ao longo da borda, FUNDO para dentro), da
## ponta do canto para a do portao:
##
##     [0, s_topo]      o bastiao: muro de arrimo de pedra com barrado e cimalha,
##                      piso de lajota em cima, peitoril caiado nos tres lados
##                      abertos, cruzeiro na ponta, luneta e bancos
##     [s_topo, L]      a escadaria de acesso descendo para o lado do portao,
##                      entre dois guarda-corpos inclinados, e o patamar no chao
static func construir(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], quadra: Dictionary, plano: Dictionary,
		desloc: Vector2) -> void:
	var t := terraco(quadra, plano)
	if t.is_empty():
		return
	var ponta: Vector2 = t["ponta"]
	var longe: Vector2 = t["longe"]
	var giro: float = t["giro"]
	var L := (longe - ponta).length()
	# O referencial do terraco: s ao longo (do canto para o portao), t para
	# dentro do parque, em coordenada local do chunk.
	var f := {"o": ponta + desloc, "e": (longe - ponta) / L, "d": -(t["fora"] as Vector2)}
	var sem := int(plano["semente"]) ^ 0x5a17
	var degraus := ceili(ALTURA / ESPELHO)
	var corrida := float(degraus) * PISADA
	var s_topo := L - PATAMAR_BAIXO - corrida
	var topo := BASE + ALTURA

	_bastiao(sup, colisao, f, s_topo)
	_piso(sup, _retangulo(f, 0.0, s_topo, 0.0, FUNDO), topo + 0.012, sem)
	_peitoris(sup, colisao, f, s_topo, topo)
	_escada(sup, colisao, f, s_topo, degraus, corrida, sem)
	_piso(sup, _retangulo(f, s_topo + corrida, L, MURO, FUNDO - MURO), BASE + 0.012, sem + 1)
	_guardas(sup, colisao, f, s_topo, corrida)

	# Em cima: o cruzeiro na ponta do canto, de frente para a cidade; a luneta
	# no peitoril de fora; os bancos virados para a vista.
	var y := topo + 0.012
	var cruz := _ponto(f, 2.0, FUNDO * 0.5, y)
	if _meu(cruz):
		KitParque.cruzeiro(sup, colisao, cruz, giro)
	var s_luneta := maxf(4.2, s_topo * 0.55)
	var luneta := _ponto(f, s_luneta, MURO + 0.42, y)
	if _meu(luneta):
		_luneta(sup, colisao, luneta, giro)
		props.append({"tipo": "luneta", "pos": luneta, "giro": giro})
	for vao: Vector2 in [Vector2(3.4, s_luneta - 0.7), Vector2(s_luneta + 0.7, s_topo - 0.8)]:
		if vao.y - vao.x < 2.2:
			continue
		var banco := _ponto(f, (vao.x + vao.y) * 0.5, 2.35, y)
		if _meu(banco):
			KitParque.banco(sup, colisao, banco, giro,
				ParqueBuilder._ale(sem, roundi(vao.x * 10.0), 7) * 0.5)
	# A lanterna no canto de dentro, na chegada da escada: e a luz de quem sobe.
	var poste := _ponto(f, s_topo - 0.55, FUNDO - MURO - 0.45, y)
	if _meu(poste):
		var luz := KitParque.poste_lanterna(sup, colisao, poste)
		props.append({
			"tipo": "lampada", "pos": luz,
			"padrao": Lampada.Padrao.ESTAVEL,
			"semente": sem + 31,
			"cor": Color("ffd9a0"), "energia": 2.4, "alcance": 11.0,
			"facho": true,
		})
	# A placa com o nome no muro de pedra, virada para o parque, como a placa de
	# inauguracao de toda obra da prefeitura.
	var placa := _ponto(f, minf(s_topo * 0.5, s_topo - 2.0), FUNDO + 0.03, BASE + 1.35)
	if _meu(placa):
		_placa(sup, props, placa, giro + PI, nome(quadra))


## Ponto do referencial do terraco, em coordenada local do chunk.
static func _ponto(f: Dictionary, s: float, t: float, y: float) -> Vector3:
	var p: Vector2 = (f["o"] as Vector2) + (f["e"] as Vector2) * s + (f["d"] as Vector2) * t
	return Vector3(p.x, y, p.y)


## O retangulo [s0, s1] x [t0, t1] do terraco, em coordenada do chunk. As bordas
## do parque correm nos eixos, entao ele e alinhado.
static func _retangulo(f: Dictionary, s0: float, s1: float, t0: float, t1: float) -> Rect2:
	var a := _ponto(f, s0, t0, 0.0)
	var b := _ponto(f, s1, t1, 0.0)
	return Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z))


## Giro em Y que leva o +Z local para o sentido do terraco (s crescente).
static func _giro_e(f: Dictionary) -> float:
	var e: Vector2 = f["e"]
	return atan2(e.x, e.y)


static func _meu(p: Vector3) -> bool:
	return ParqueBuilder._neste_chunk(Vector2(p.x, p.z))


## O corpo do bastiao, em trechos de PASSO_PILASTRA: pedra ate o topo, barrado
## escuro no pe e cimalha na borda de cima. Cada trecho sai no chunk do meio
## dele, com a colisao que e o chao de cima.
static func _bastiao(sup: Dictionary, colisao: Array[Dictionary], f: Dictionary,
		s_topo: float) -> void:
	var g := _giro_e(f)
	var fundo_pedra := BASE - 0.4
	var topo := BASE + ALTURA
	var n := maxi(1, ceili(s_topo / PASSO_PILASTRA))
	var passo := s_topo / float(n)
	var escuro := COR_ARRIMO.lerp(Color("3e3a33"), 0.4)
	var claro := KitParque.RINCHEIRA
	for i in n:
		var s0 := passo * float(i)
		var centro := _ponto(f, s0 + passo * 0.5, FUNDO * 0.5, 0.0)
		if not _meu(centro):
			continue
		# Pontas: so a do canto tem face; a do outro lado encosta no trecho
		# vizinho ou fica dentro da escada.
		var faces := PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ
		if i == 0:
			faces |= PSXMesh.FACE_TRAS
		var h := topo - fundo_pedra
		KitModular.caixa_cor(sup, &"pedra_parque", centro + Vector3(0.0, fundo_pedra + h * 0.5, 0.0),
			Vector3(FUNDO, h, passo), COR_ARRIMO, g, faces, 2.0)
		# O barrado sem topo: dele so aparecem os 2 cm de ressalto, e o que se ve
		# pela fresta e a face do muro logo atras.
		KitModular.caixa_cor(sup, &"pedra_parque", centro + Vector3(0.0, BASE + 0.15, 0.0),
			Vector3(FUNDO + 0.04, 0.5, passo + (0.02 if i == 0 else 0.0)), escuro, g,
			faces, 2.0)
		KitModular.caixa_cor(sup, &"reboco", centro + Vector3(0.0, topo - 0.06, 0.0),
			Vector3(FUNDO + 0.16, 0.12, passo + (0.08 if i == 0 else 0.0)), claro, g,
			faces | PSXMesh.FACE_TOPO | PSXMesh.FACE_BASE, 2.0)
		colisao.append({"tamanho": Vector3(FUNDO, topo - fundo_pedra, passo),
			"pos": centro + Vector3(0.0, (topo + fundo_pedra) * 0.5, 0.0),
			"giro": Vector3(0.0, g, 0.0)})


## Lajotas de pedra, em grade de LAJOTA com tom sorteado por lajota, cortadas
## pela borda do chunk (KitParque.piso). Por baixo, o rejunte escuro.
static func _piso(sup: Dictionary, r: Rect2, y: float, sem: int) -> void:
	if r.size.x < 0.05 or r.size.y < 0.05:
		return
	var chunk := Rect2(0.0, 0.0, TAM, TAM)
	if not r.intersects(chunk):
		return
	var nx := maxi(1, roundi(r.size.x / LAJOTA))
	var nz := maxi(1, roundi(r.size.y / LAJOTA))
	var px := r.size.x / float(nx)
	var pz := r.size.y / float(nz)
	for iz in nz:
		for ix in nx:
			var laje := Rect2(r.position.x + px * float(ix), r.position.y + pz * float(iz),
				px, pz)
			if not laje.intersects(chunk):
				continue
			var chave := iz * 256 + ix
			var tom := lerpf(TOM_LAJOTA.x, TOM_LAJOTA.y, ParqueBuilder._ale(sem, chave, 3))
			KitParque.piso(sup, &"pedra_parque", laje.grow(-0.012),
				y + lerpf(-0.004, 0.004, ParqueBuilder._ale(sem, chave, 4)),
				Color(tom, tom * 0.985, tom * 0.95))
	KitParque.piso(sup, &"pedra_parque", r, y - 0.01, Color(0.3, 0.29, 0.27))


## Peitoril caiado nos tres lados abertos do bastiao, com pilastra nas quinas,
## nas emendas do lado de fora e nas duas cabeceiras da escada.
static func _peitoris(sup: Dictionary, colisao: Array[Dictionary], f: Dictionary,
		s_topo: float, topo: float) -> void:
	var meio := MURO * 0.5
	var n := maxi(1, ceili(s_topo / PASSO_PILASTRA))
	var passo := s_topo / float(n)
	var g := _giro_e(f)
	# Fora: trecho a trecho, com pilastra em cada emenda.
	for i in n:
		_muro(sup, colisao, _ponto(f, passo * float(i), meio, topo),
			_ponto(f, passo * float(i + 1), meio, topo))
	for i in n + 1:
		var p := _ponto(f, passo * float(i), meio, topo)
		if _meu(p):
			_pilastra(sup, colisao, p, g, i == 0 or i == n)
	# A ponta do canto e o lado de dentro, com pilastra so nas pontas.
	_muro(sup, colisao, _ponto(f, meio, meio, topo), _ponto(f, meio, FUNDO - meio, topo))
	_muro(sup, colisao, _ponto(f, 0.0, FUNDO - meio, topo),
		_ponto(f, s_topo, FUNDO - meio, topo))
	for p: Vector3 in [_ponto(f, meio, FUNDO - meio, topo), _ponto(f, s_topo, FUNDO - meio, topo)]:
		if _meu(p):
			_pilastra(sup, colisao, p, g)


## Um muro caiado de `a` a `b`, no chunk do meio dele.
static func _muro(sup: Dictionary, colisao: Array[Dictionary], a: Vector3, b: Vector3) -> void:
	if _meu((a + b) * 0.5):
		KitParque.muro_caiado(sup, colisao, a, b, PEITORIL)


## `pinhao` so nas pilastras de quina e de cabeceira: nas do meio do peitoril ele
## vira serrilhado e custa 10 triangulos cada.
static func _pilastra(sup: Dictionary, colisao: Array[Dictionary], pe: Vector3,
		giro: float, pinhao := true) -> void:
	KitModular.caixa_cor(sup, &"reboco", pe + Vector3(0.0, PILASTRA.y * 0.5, 0.0),
		PILASTRA, KitParque.CAIACAO_MURO, giro, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 2.0)
	# Capitel de pedra e o pinhao em cima.
	KitModular.caixa_cor(sup, &"reboco", pe + Vector3(0.0, PILASTRA.y + 0.05, 0.0),
		Vector3(PILASTRA.x + 0.1, 0.1, PILASTRA.z + 0.1), KitParque.RINCHEIRA, giro,
		PSXMesh.FACE_TODAS, 2.0)
	if pinhao:
		KitModular.caixa_cor(sup, &"reboco", pe + Vector3(0.0, PILASTRA.y + 0.2, 0.0),
			Vector3(0.2, 0.2, 0.2), KitParque.RINCHEIRA, giro + PI * 0.25,
			PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 2.0)
	colisao.append({"tamanho": PILASTRA, "pos": pe + Vector3(0.0, PILASTRA.y * 0.5, 0.0),
		"giro": Vector3(0.0, giro, 0.0)})


## A escadaria: piso, espelho e bocel por degrau, e a colisao como uma rampa na
## linha dos bocels (o CharacterBody3D nao sobe degrau).
static func _escada(sup: Dictionary, colisao: Array[Dictionary], f: Dictionary,
		s_topo: float, degraus: int, corrida: float, sem: int) -> void:
	var topo := BASE + ALTURA
	var espelho := ALTURA / float(degraus)
	var t0 := MURO
	var t1 := FUNDO - MURO
	var e2: Vector2 = f["e"]
	var e := Vector3(e2.x, 0.0, e2.y)
	var bocel := EscadariaBuilder.BOCEL
	var meio := _ponto(f, s_topo + corrida * 0.5, (t0 + t1) * 0.5, 0.0)
	if _meu(meio):
		for k in degraus:
			var s := s_topo + PISADA * float(k)
			var y_cima := topo - espelho * float(k)
			var y_baixo := y_cima - espelho
			var tom := lerpf(0.9, 1.06, ParqueBuilder._ale(sem, k, 11))
			var cor_piso := Color(COR_PISO_ESCADA.r * tom, COR_PISO_ESCADA.g * tom,
				COR_PISO_ESCADA.b * tom)
			var cor_espelho := Color(EscadariaBuilder.COR_ESPELHO.r * tom,
				EscadariaBuilder.COR_ESPELHO.g * tom, EscadariaBuilder.COR_ESPELHO.b * tom)
			# O espelho k, virado para o portao (s crescente, onde fica o chao).
			EscadariaBuilder.quad(sup, EscadariaBuilder.MATERIAL,
				_ponto(f, s, t0, y_baixo), _ponto(f, s, t1, y_baixo),
				_ponto(f, s, t1, y_cima), _ponto(f, s, t0, y_cima), e, cor_espelho)
			# Bocel da pedra de cima (no k = 0, a borda do piso do bastiao).
			var b0 := _ponto(f, s, t0, y_cima)
			var b1 := _ponto(f, s, t1, y_cima)
			EscadariaBuilder.quad(sup, EscadariaBuilder.MATERIAL, b0, b1,
				b1 + e * bocel.x, b0 + e * bocel.x, Vector3.UP, EscadariaBuilder.COR_BOCEL)
			EscadariaBuilder.quad(sup, EscadariaBuilder.MATERIAL,
				b0 + e * bocel.x - Vector3(0.0, bocel.y, 0.0),
				b1 + e * bocel.x - Vector3(0.0, bocel.y, 0.0),
				b1 + e * bocel.x, b0 + e * bocel.x, e, EscadariaBuilder.COR_BOCEL)
			if k == degraus - 1:
				break
			EscadariaBuilder.quad(sup, EscadariaBuilder.MATERIAL,
				_ponto(f, s, t0, y_baixo), _ponto(f, s + PISADA, t0, y_baixo),
				_ponto(f, s + PISADA, t1, y_baixo), _ponto(f, s, t1, y_baixo),
				Vector3.UP, cor_piso)
	# A rampa de colisao, do bocel de cima ao pe do ultimo degrau.
	var comp := Vector2(corrida, ALTURA).length()
	var incl := atan2(ALTURA, corrida)
	var giro := Vector3(incl, _giro_e(f), 0.0)
	var linha := _ponto(f, s_topo + corrida * 0.5, (t0 + t1) * 0.5, (topo + BASE) * 0.5)
	if _meu(linha):
		colisao.append({"tamanho": Vector3(t1 - t0, 0.3, comp),
			"pos": linha - Basis.from_euler(giro).y * 0.15, "giro": giro})


## Os dois guarda-corpos da escada: muro inclinado, pedra embaixo da linha dos
## degraus e caiado em cima, com capa de pedra acompanhando a inclinacao e
## pilastra no pe. A colisao e uma caixa inclinada da mesma altura.
static func _guardas(sup: Dictionary, colisao: Array[Dictionary], f: Dictionary,
		s_topo: float, corrida: float) -> void:
	var topo := BASE + ALTURA
	var s1 := s_topo + corrida
	var chao := BASE - 0.3
	var d2: Vector2 = f["d"]
	var d := Vector3(d2.x, 0.0, d2.y)
	var incl := atan2(ALTURA, corrida)
	var giro := Vector3(incl, _giro_e(f), 0.0)
	var comp := Vector2(corrida, ALTURA).length()
	for lado: Vector2 in [Vector2(0.0, MURO), Vector2(FUNDO - MURO, FUNDO)]:
		var meio_t := (lado.x + lado.y) * 0.5
		var centro := _ponto(f, s_topo + corrida * 0.5, meio_t, 0.0)
		if not _meu(centro):
			continue
		# As duas faces compridas de cada muro, cada uma virada para o seu lado:
		# pedra do chao ate a linha dos bocels, cal da linha ate o peitoril.
		for face: Array in [[lado.x, -d], [lado.y, d]]:
			var tt: float = face[0]
			var n: Vector3 = face[1]
			EscadariaBuilder.quad(sup, &"pedra_parque",
				_ponto(f, s_topo, tt, chao), _ponto(f, s1, tt, chao),
				_ponto(f, s1, tt, BASE), _ponto(f, s_topo, tt, topo), n, COR_ARRIMO)
			EscadariaBuilder.quad(sup, &"reboco",
				_ponto(f, s_topo, tt, topo), _ponto(f, s1, tt, BASE),
				_ponto(f, s1, tt, BASE + PEITORIL), _ponto(f, s_topo, tt, topo + PEITORIL), n,
				KitParque.CAIACAO_MURO)
		# Capa de pedra inclinada, mais larga que o muro.
		var capa := _ponto(f, s_topo + corrida * 0.5, meio_t,
			(topo + BASE) * 0.5 + PEITORIL + 0.05)
		if not sup.has(&"reboco"):
			sup[&"reboco"] = PSXMesh.dados_vazios()
		PSXMesh.acumular_tingido(sup[&"reboco"],
			PSXMesh.box_dados(Vector3(MURO + 0.12, 0.1, comp + 0.1), 0.8, 2.0, Color.WHITE,
				PSXMesh.FACE_TODAS),
			Transform3D(Basis.from_euler(giro), capa), KitParque.RINCHEIRA)
		var pe := _ponto(f, s1, meio_t, BASE)
		if _meu(pe):
			_pilastra(sup, colisao, pe, _giro_e(f))
		colisao.append({"tamanho": Vector3(MURO, PEITORIL + 0.4, comp),
			"pos": _ponto(f, s_topo + corrida * 0.5, meio_t,
				(topo + BASE) * 0.5 + (PEITORIL + 0.4) * 0.5 - 0.2), "giro": giro})


## A luneta de moeda da prefeitura: coluna, garfo, cabeca com os dois tubos,
## ocular de latao, pala e o cofre da ficha. Olha para `giro` (o +Z local),
## inclinada 6 graus para baixo, que e como luneta de morro fica largada.
static func _luneta(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var cor := COR_LUNETA
	var escuro := cor.darkened(0.35)
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var corpo := Basis(Vector3.UP, giro)
	_caixa(sup, base + Vector3(0.0, 0.03, 0.0), Vector3(0.4, 0.06, 0.4), corpo, escuro)
	_caixa(sup, base + Vector3(0.0, 0.08, 0.0), Vector3(0.22, 0.06, 0.22), corpo, cor)
	_caixa(sup, base + Vector3(0.0, 0.58, 0.0), Vector3(0.11, 1.0, 0.11), corpo, cor)
	_caixa(sup, base + Vector3(0.0, 1.1, 0.0), Vector3(0.26, 0.05, 0.12), corpo, escuro)
	var inclina := Basis(lado, deg_to_rad(6.0))
	var cabeca := inclina * corpo
	var centro := base + Vector3(0.0, ALTURA_LUNETA, 0.0)
	_caixa(sup, centro, Vector3(0.26, 0.18, 0.3), cabeca, cor)
	_caixa(sup, centro + inclina * Vector3(0.0, -0.14, 0.0), Vector3(0.12, 0.1, 0.1),
		cabeca, escuro)
	_caixa(sup, centro + inclina * (Vector3(0.0, 0.1, 0.0) - frente * 0.1),
		Vector3(0.28, 0.025, 0.12), cabeca, escuro)
	for s: float in [-1.0, 1.0]:
		_caixa(sup, centro + inclina * (lado * 0.068 * s + frente * 0.19),
			Vector3(0.11, 0.11, 0.1), cabeca, escuro)
		_caixa(sup, centro + inclina * (lado * 0.06 * s - frente * 0.185 + Vector3(0.0, 0.02, 0.0)),
			Vector3(0.055, 0.055, 0.07), cabeca, COR_LATAO)
	colisao.append({"tamanho": Vector3(0.34, ALTURA_LUNETA + 0.14, 0.34),
		"pos": base + Vector3(0.0, (ALTURA_LUNETA + 0.14) * 0.5, 0.0),
		"giro": Vector3(0.0, giro, 0.0)})


static func _caixa(sup: Dictionary, centro: Vector3, tamanho: Vector3,
		base: Basis, cor: Color) -> void:
	if not sup.has(&"metal"):
		sup[&"metal"] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[&"metal"],
		PSXMesh.box_dados(tamanho, 0.8, 4.0, Color.WHITE, PSXMesh.FACE_TODAS),
		Transform3D(base, centro), cor)


## Placa de ferro com o nome, presa no muro de pedra; o texto e um Label3D
## (prop `placa_rua`), como o nome da rua na esquina.
static func _placa(sup: Dictionary, props: Array[Dictionary], centro: Vector3,
		giro: float, texto: String) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var corpo := Basis(Vector3.UP, giro)
	_caixa(sup, centro, Vector3(2.1, 0.62, 0.04), corpo, Color("1f2a24"))
	_caixa(sup, centro + frente * 0.012, Vector3(2.0, 0.52, 0.04), corpo, Color("d9d2bd"))
	_caixa(sup, centro + frente * 0.022, Vector3(1.94, 0.46, 0.04), corpo, Color("2c4a3a"))
	props.append({"tipo": "placa_rua", "texto": texto + "\nPREFEITURA MUNICIPAL",
		"pos": centro + frente * 0.05, "giro": giro})

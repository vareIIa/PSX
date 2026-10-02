## Onde ficam os lugares da Missao 1.
##
## A igreja e fixa: a Praca da Matriz e ancorada a mao (`Tracado._ancora`,
## `ParqueBuilder.planta_matriz`, `KitParque.igreja_matriz`), e o jogador
## acorda no pino (270, -40) com a cabeca para ela. A casa da fumaca e sorteio
## do gerador, e a vaga na calcada depende da rua que estiver ali. Tudo e
## estatico e responde sem chunk carregado: o Berg precisa estacionar na igreja
## antes de ela existir na tela.
##
## Por que a igreja sai da planta e nao de constante
## -------------------------------------------------
## A base tinha a ancora medida a mao (`cidade.gd` IGREJA_ANCORA). Ela esta
## certa hoje, e deixa de estar no primeiro ajuste de recuo de calcada: a praca
## e centrada na AREA util da quadra, e a area encolhe com a calcada. Aqui a
## conta e a mesma que o ChunkBuilder faz para desenhar a capela — quadra da
## malha, `ParqueBuilder.planta`, `planta_matriz` —, entao o Berg para onde a
## escadaria esta, e nao onde ela estava.
class_name Lugares
extends RefCounted

## Um chunk qualquer da quadra da Praca da Matriz (x 7..10, z -3..0). Ver
## `Tracado._ancora` e `MalhaUrbana.REGIAO_DA_PRACA`.
const CHUNK_DA_MATRIZ := Vector2i(8, -2)

## Sobra da base: a medida a mao, que o teste `m1_d` confere contra a planta.
const IGREJA_ANCORA := Vector3(270.9, 0.0, -59.1)
const IGREJA_FACHADA_Z := -53.1

## Do centro da capela ate a soleira da porta, ao longo da frente. Mesmo numero
## de `KitParque.igreja_matriz` (fundura 12 / 2 + 0,08).
const SOLEIRA := 6.08
## Do centro da capela ate o pe da escadaria: soleira, quatro pisadas de 38 cm
## e o espelho de baixo. Medido pelo teste com raio de cima.
const PE_DA_ESCADA := 7.75
## Quanto o carro do Berg entra torto na calcada, em radianos. O da viatura da
## blitz: o bico vira para dentro, a traseira fica no asfalto.
const TORTO := 0.21
## Carro de passeio: meia bitola e meio comprimento. O Marea tem 1,70 x 4,39;
## o que importa aqui e a pegada para a checagem de calcada livre.
const MEIA_PEGADA := Vector2(0.85, 2.2)
## Quanto acima do asfalto conta como "tem algo em pe" (arvore, banco, poste).
## O mesmo limite de `Blitz._pegada_livre`.
const ALGO_EM_PE := 0.35


## A casa da fumaca mais proxima: {mundo, chunk, semente, nome}.
static func casa_fumaca_mais_perto(de: Vector3) -> Dictionary:
	return Missoes.casa_mais_perto(de)


## A igreja da Praca da Matriz. Chaves:
##   mundo: Vector3       a porta principal, no topo da escadaria (piso do plinto)
##   frente: Vector3      onde o jogador para, no pe da escadaria, olhando a porta
##   giro: float          para onde a fachada olha (rad, eixo Y; 0 = +Z, sul)
##   vaga: Transform3D    onde o carro do Berg estaciona, duas rodas na calcada
##                        da avenida do sul, no eixo do portao, bico para a capela
##   area: Rect2          retangulo do adro e do largo em XZ, onde o Berg vaga
##   pino: Vector3        onde o jogador acordou (o "foi ali" da Cena 7)
##   centro: Vector3      o centro da capela no chao da praca
##   nome: String
static func igreja() -> Dictionary:
	var centro := centro_da_igreja()
	var y_chao := KitParque.Y_CALCAMENTO
	var porta := igreja_porta()
	var pe := Vector3(centro.x, y_chao, centro.z + PE_DA_ESCADA + 1.2)
	# A vaga: na calcada da avenida que fecha a quadra pelo sul, no eixo da
	# capela. O portao sul do casario abre nesse eixo, entao do carro se ve a
	# escadaria pela rua de pedra, e o Berg anda em linha reta ate ela.
	var q := quadra_da_matriz()
	var sul := float(int(q["z1"])) * MalhaUrbana.TAM
	var vaga := vaga_na_calcada(Vector3(centro.x, 0.0, sul - 1.0), porta)
	# O adro (muro da frente a 12 m do centro, 40 m de largura) mais o largo ate
	# o casario sul: e por onde o Berg anda, fuma e olha a torre.
	var area := Rect2(centro.x - 14.0, centro.z + SOLEIRA + 0.5, 28.0, 26.0)
	return {
		"mundo": porta,
		"frente": pe,
		"giro": 0.0,
		"vaga": vaga,
		"area": area,
		"pino": Vector3(270.0, y_chao, -40.0),
		"centro": centro,
		"nome": "IGREJA MATRIZ",
	}


## A quadra da Praca da Matriz (`MalhaUrbana.quadra_de`).
static func quadra_da_matriz() -> Dictionary:
	return MalhaUrbana.quadra_de(CHUNK_DA_MATRIZ.x, CHUNK_DA_MATRIZ.y)


## A porta da capela, no topo da escadaria. Atalho de `igreja()["mundo"]` para
## quem pergunta muito (o GPS varre centenas de chunks).
static func igreja_porta() -> Vector3:
	return centro_da_igreja() + Vector3(0.0, KitParque.IGREJA_PLINTO, SOLEIRA)


## O centro da capela, no chao da praca. A mesma conta do ChunkBuilder.
static func centro_da_igreja() -> Vector3:
	var q := quadra_da_matriz()
	if int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
		return Vector3(IGREJA_ANCORA.x, KitParque.Y_CALCAMENTO, IGREJA_ANCORA.z)
	var plano := ParqueBuilder.planta(q)
	var pl := ParqueBuilder.planta_matriz(plano["centro"])
	var local: Vector2 = pl["igreja"]
	return Vector3(float(int(q["x0"])) * MalhaUrbana.TAM + local.x,
		KitParque.Y_CALCAMENTO, float(int(q["z0"])) * MalhaUrbana.TAM + local.y)


## Vaga com as duas rodas do lado da calcada em cima dela, perto de um ponto (o
## padrao da viatura da blitz, `Blitz._montar_viatura` e `_pegada_livre`).
##
## Acha a via mais perto de `perto_de` entre as quatro bordas do chunk, poe o
## carro paralelo ao meio-fio com a bitola de dentro sobre a calcada e o bico
## virado TORTO para ela. `frente_para` escolhe para que lado da rua o capo
## aponta. A origem e o centro do carro no chao, -Z da base e a frente.
##
## Com a cena carregada, confere a calcada com raios de cima como a blitz faz:
## se ha arvore da guia, banco ou orelhao na pegada, escorrega ao longo do
## meio-fio ate achar lugar (ate 12 m para cada lado). Sem cena, devolve a vaga
## calculada — quem estaciona depois assenta nas rodas.
static func vaga_na_calcada(perto_de: Vector3, frente_para: Vector3 = Vector3.INF) -> Transform3D:
	var meio_fio := _meio_fio_mais_perto(perto_de)
	if meio_fio.is_empty():
		return Transform3D(Basis(Vector3.UP, _giro_para(perto_de, frente_para)), perto_de)
	var ao_longo: Vector3 = meio_fio["ao_longo"]
	var para_calcada: Vector3 = meio_fio["para_calcada"]
	var linha: Vector3 = meio_fio["ponto"]
	# Sentido do capo: o da rua que mais aponta para `frente_para`.
	var frente := ao_longo
	if frente_para != Vector3.INF:
		var d := frente_para - perto_de
		if Vector2(d.x, d.z).dot(Vector2(ao_longo.x, ao_longo.z)) < 0.0:
			frente = -ao_longo
	# O bico vira para a calcada: gira da rua para dentro.
	var bico := (frente * cos(TORTO) + para_calcada * sin(TORTO)).normalized()
	var giro := atan2(-bico.x, -bico.z)
	# Centro do carro: a bitola de dentro 40 cm para la do meio-fio, a de fora no
	# asfalto. O carro torto poe o eixo da frente mais para dentro que o de tras.
	var centro := linha - para_calcada * (MEIA_PEGADA.x - 0.4)
	centro.y = KitModular.ALTURA_MEIO_FIO * 0.5
	var arvore := Engine.get_main_loop() as SceneTree
	var espaco: PhysicsDirectSpaceState3D = null
	if arvore != null and arvore.root != null and arvore.root.world_3d != null:
		espaco = arvore.root.world_3d.direct_space_state
	if espaco != null:
		for k in 9:
			# 0, +3, -3, +6, -6 ...
			var passo := float(floori((k + 1) * 0.5)) * 3.0 * (1.0 if k % 2 == 1 else -1.0)
			var tentativa := centro + ao_longo * passo
			if _pegada_livre(espaco, tentativa, giro):
				centro = tentativa
				break
	return Transform3D(Basis(Vector3.UP, giro), centro)


static func _giro_para(de: Vector3, para: Vector3) -> float:
	if para == Vector3.INF:
		return 0.0
	var d := para - de
	return atan2(-d.x, -d.z)


## O meio-fio mais perto de um ponto: {ponto, ao_longo, para_calcada, via}.
## Vazio se o chunk nao tem rua em volta (miolo de quadra grande).
static func _meio_fio_mais_perto(p: Vector3) -> Dictionary:
	var t := MalhaUrbana.TAM
	var cx := floori(p.x / t)
	var cz := floori(p.z / t)
	var melhor := {}
	var melhor_d := INF
	for borda in 4:
		var em_x := borda < 2
		var linha := float(cx + (borda % 2)) * t if em_x else float(cz + (borda % 2)) * t
		var via: MalhaUrbana.Via = MalhaUrbana.via_x_em(cx + borda % 2, cz) if em_x \
			else MalhaUrbana.via_z_em(cz + borda % 2, cx)
		if via == MalhaUrbana.Via.NENHUMA:
			continue
		var coord := p.x if em_x else p.z
		var lado := 1.0 if coord >= linha else -1.0
		var curb := linha + lado * MalhaUrbana.meia_asfalto(via)
		var d := absf(coord - curb)
		if d >= melhor_d:
			continue
		melhor_d = d
		var ponto := Vector3(curb, 0.0, p.z) if em_x else Vector3(p.x, 0.0, curb)
		melhor = {
			"ponto": ponto,
			"ao_longo": Vector3.BACK if em_x else Vector3.RIGHT,
			"para_calcada": Vector3(lado, 0.0, 0.0) if em_x else Vector3(0.0, 0.0, lado),
			"via": via,
		}
	return melhor


## A pegada esta livre? Raios de cima numa grade de 5 x 9, como a blitz: nada
## mais de ALGO_EM_PE acima do mais baixo da pegada (o asfalto).
static func _pegada_livre(espaco: PhysicsDirectSpaceState3D, centro: Vector3, giro: float) -> bool:
	var base := Basis(Vector3.UP, giro)
	var mais_baixo := INF
	var mais_alto := -INF
	var algum := false
	for ix in 5:
		for iz in 9:
			var l := Vector3(lerpf(-MEIA_PEGADA.x, MEIA_PEGADA.x, ix / 4.0), 0.0,
				lerpf(-MEIA_PEGADA.y, MEIA_PEGADA.y, iz / 8.0))
			var g := centro + base * l
			var q := PhysicsRayQueryParameters3D.create(g + Vector3.UP * 4.0,
				g + Vector3.DOWN * 2.0)
			var achado := espaco.intersect_ray(q)
			if achado.is_empty():
				continue
			var col: Object = achado.get("collider")
			# Carro e gente saem da frente; nao contam como calcada ocupada.
			if col is Carro or col is CharacterBody3D:
				continue
			algum = true
			var h := (achado["position"] as Vector3).y
			mais_baixo = minf(mais_baixo, h)
			mais_alto = maxf(mais_alto, h)
	return not algum or mais_alto - mais_baixo <= ALGO_EM_PE

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
## Funcao pura da coordenada, como a malha: `altura(x, z)` interpola as alturas
## nos NOS da grade (os cantos dos chunks) com Hermite bicubico, de tangente
## monotonica (`_tangente`).
##
## Era bilinear, e a bilinear quebra a pista. A rua corre EM CIMA da linha de
## nos, na emenda de dois chunks: de um lado da emenda o chao inclinava de um
## jeito, do outro de outro, e a pista dobrava em V no eixo (medido: 43% dos
## pontos de rua com mais de 4% de diferenca, ate 44%). Na esquina o declive
## trocava de uma vez, e o topo da ladeira virava quina (p95 13%, ate 50%). O
## Hermite e liso atravessando a emenda e arredonda o topo e o fundo da ladeira
## numa curva vertical.
##
## A tangente monotonica e o que deixa o resto como era: ela nunca passa da
## altura dos nos (nao faz lombada nem cova entre duas esquinas), e e zero em
## no de topo, de fundo e em todo no cujo vizinho esta no mesmo nivel. Entao a
## celula de quatro cantos iguais continua plana, exatamente: a Praca da
## Matriz em y = 0, o parque, o patamar do bar.
##
## Quem anda (pedestre, rota) nao interpola entre pontos: pergunta a altura de
## cada ponto aqui, ou resolve por raio.
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
## O mesmo para o patamar (bar, casa, mercado no mundo). E um chunk so, e com o
## mercado sao 166 em 52 x 52 chunks: com o alcance do parque eles achatavam a
## cidade (mediana da viela de 3,2% para 1,8%).
const ALCANCE_PATAMAR := 3
## Declive maximo entre um no cravado numa zona plana (parque, patamar) e o no de
## avenida ou o patamar que encosta nele. Dois nos cravados vizinhos em niveis
## diferentes juntavam o desnivel de uma quadra inteira num trecho so (40%).
const DECLIVE_JUNTO_A_ZONA := 0.28
## As plantas que fazem do chunk um patamar (`tem_patamar`).
const PLANTAS_DE_PATAMAR: Array[StringName] = [&"bar", &"casa_fumaca"]
## Teto de seguranca do grupo de parques encostados (que dividem no), que se
## nivelam juntos. O grupo tem de ser a componente INTEIRA: com teto de 6 o
## grupo visto de cada membro saia diferente (a busca comeca nele), o nivel
## dependia de quem o chunk perguntava primeiro, e numa componente de 7 quadras
## a fileira da borda saia 1,64 m torta. A maior medida em 120 x 120 chunks
## tem 11 quadras.
const GRUPO_MAXIMO := 64
## Um chunk da Praca da Matriz. O grupo de parque que o contem fica em y = 0.
const CHUNK_PRACA := Vector2i(8, -2)
## Meia janela do aterro da avenida, em nos (`_aterrada`).
const JANELA_AVENIDA := 3
## Quanto a pista da serpentina fica acima do chao (SerpentinaBuilder.PISO_RUA).
const SERPENTINA_PISO := 0.05
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

## Chave de bancada: desligado, a cidade volta a ser plana. O jogo nunca mexe;
## `--sem-relevo` na linha de comando desliga desde o primeiro quadro, para
## medir a mesma coisa em par, com e sem morro.
static var ativo := not OS.get_cmdline_user_args().has("--sem-relevo")

static var _cache: Dictionary = {}
## No -> altura com o parque nivelado, antes do patamar. O patamar pede os
## quatro cantos do chunk dele, e cada canto e pedido por quatro chunks.
static var _niveladas: Dictionary = {}
## Id de quadra de parque -> nivel do grupo dela.
static var _niveis: Dictionary = {}
## Chunk de patamar -> nivel do grupo dele (`_nivel_do_patamar`).
static var _niveis_patamar: Dictionary = {}
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
	return avaliar(celula(i, j), fx - float(i), fz - float(j))


## O que a celula de chunk (i, j) precisa para ser avaliada: as alturas dos
## quatro cantos e as tangentes deles em x e em z, em metros por no. Quem avalia
## muitos pontos no mesmo chunk (o chao, o mapa de colisao) pede uma vez.
static func celula(i: int, j: int) -> PackedFloat32Array:
	var c := PackedFloat32Array()
	c.resize(12)
	var k := 0
	for n: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1),
			Vector2i(i + 1, j + 1)]:
		c[k] = no(n.x, n.y)
		c[k + 4] = _tangente(no(n.x - 1, n.y), c[k], no(n.x + 1, n.y))
		c[k + 8] = _tangente(no(n.x, n.y - 1), c[k], no(n.x, n.y + 1))
		k += 1
	return c


## A altura dentro da celula, em (u, v) de 0 a 1: Hermite bicubico sem torcao.
## Na borda da celula ele e o Hermite de uma dimensao da linha de nos, que o
## vizinho tambem ve igual, e a derivada atravessando a borda e a mesma dos dois
## lados: nao ha dobra na emenda.
static func avaliar(c: PackedFloat32Array, u: float, v: float) -> float:
	var u2 := u * u
	var v2 := v * v
	var a0 := 2.0 * u2 * u - 3.0 * u2 + 1.0
	var a1 := 1.0 - a0
	var b0 := 2.0 * v2 * v - 3.0 * v2 + 1.0
	var b1 := 1.0 - b0
	var ta0 := u2 * u - 2.0 * u2 + u
	var ta1 := u2 * u - u2
	var tb0 := v2 * v - 2.0 * v2 + v
	var tb1 := v2 * v - v2
	return (c[0] * a0 + c[1] * a1 + c[4] * ta0 + c[5] * ta1) * b0 \
		+ (c[2] * a0 + c[3] * a1 + c[6] * ta0 + c[7] * ta1) * b1 \
		+ (c[8] * a0 + c[9] * a1) * tb0 + (c[10] * a0 + c[11] * a1) * tb1


## Tangente no no do meio, dados os vizinhos antes e depois na linha: a media
## harmonica dos dois declives (Fritsch-Butland). Zero no topo e no fundo (os
## declives trocam de sinal) e junto de trecho plano, e nunca mais que o dobro
## do declive menor: a curva nao passa da altura dos nos.
static func _tangente(antes: float, meio: float, depois: float) -> float:
	var d0 := meio - antes
	var d1 := depois - meio
	if d0 * d1 <= 0.0:
		return 0.0
	return 2.0 * d0 * d1 / (d0 + d1)


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
	# Dentro do chunk a celula e uma so: conta local, sem ir ao cache para cada
	# vertice. Fora (a mobilia do cruzamento em coordenada negativa, a copa que
	# passa da borda), a conta geral.
	var cel := celula(cx, cz)
	for mat: StringName in sup:
		var v: PackedVector3Array = sup[mat]["v"]
		var de := int(marca.get(mat, 0))
		for k in range(de, v.size()):
			var p := v[k]
			if p.x >= 0.0 and p.x <= TAM and p.z >= 0.0 and p.z <= TAM:
				p.y += avaliar(cel, p.x / TAM, p.z / TAM)
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
		fundo_pedra: float = EMBASAMENTO, colisao: Array[Dictionary] = []) -> void:
	# A colisao do embasamento: sem ela, do lado de baixo da ladeira o vao entre
	# o chao e a caixa do predio (que comeca na soleira) era passagem para
	# dentro do lote — pedra desenhada que o corpo atravessava. Fica atras da
	# linha da fachada (nao avanca na calcada) e desce fundo; a altura minima e
	# a de parede, para quem varre o quarteirao contar como fechado.
	var fundo_col := maxf(fundo_pedra, 2.2)
	var centro_col := frente - normal * (fundo * 0.5) + Vector3(0.0, -fundo_col * 0.5, 0.0)
	colisao.append({"tamanho": Vector3(larg, fundo_col, fundo) if absf(normal.z) > 0.5
			else Vector3(fundo, fundo_col, larg),
		"pos": centro_col})
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
		parque: bool, rebaixar: Array[Rect2] = [],
		rua_curva: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	var px0 := MalhaUrbana.meia_asfalto(bordas["x0"])
	var px1 := MalhaUrbana.meia_asfalto(bordas["x1"])
	var pz0 := MalhaUrbana.meia_asfalto(bordas["z0"])
	var pz1 := MalhaUrbana.meia_asfalto(bordas["z1"])
	var h := KitModular.ALTURA_MEIO_FIO
	var dados := PackedFloat32Array()
	dados.resize(LADO_MAPA * LADO_MAPA)
	var cel := celula(cx, cz)
	for iz in LADO_MAPA:
		for ix in LADO_MAPA:
			var x := float(ix) * PASSO_MAPA
			var z := float(iz) * PASSO_MAPA
			var asfalto := (px0 > 0.05 and x <= px0) or (px1 > 0.05 and x >= TAM - px1) \
				or (pz0 > 0.05 and z <= pz0) or (pz1 > 0.05 and z >= TAM - pz1)
			var y := avaliar(cel, x / TAM, z / TAM) if ativo else 0.0
			if not asfalto and not rua_curva.is_empty() \
					and lim.has_point(Vector2(x, z)):
				# Celula de encosta (Serpentina): a pista em curva, a calcada dela
				# e o pasto em volta, cada um na altura em que e desenhado
				# (SerpentinaBuilder).
				var d := _distancia_a_linha(rua_curva, Vector2(x, z))
				if d < Serpentina.MEIA_PISTA:
					y += SERPENTINA_PISO
				elif d < Serpentina.MEIA_PISTA + Serpentina.CALCADA:
					y += SERPENTINA_PISO + h
				else:
					y += 0.02
			elif not asfalto:
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


## Distancia do ponto ate a linha (pontos em sequencia; Vector2.INF quebra a
## linha em trechos que nao se ligam).
static func _distancia_a_linha(linha: PackedVector2Array, p: Vector2) -> float:
	var melhor := INF
	for k in range(1, linha.size()):
		var a := linha[k - 1]
		var b := linha[k]
		if a == Vector2.INF or b == Vector2.INF:
			continue
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		melhor = minf(melhor, p.distance_to(a + ab * t))
	return melhor


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
			var alcance := float(ALCANCE_PARQUE if parque else ALCANCE_PATAMAR)
			if d > alcance:
				continue
			var nivel := _nivel_do_parque(c) if parque else _nivel_do_patamar(c)
			# O no colado fica no nivel da zona. Parque manda mais que patamar:
			# o parque inteiro tem de ser plano.
			if d == 0.0 and (parque and not colado_parque
					or not parque and not colado):
				colado_parque = colado_parque or parque
				colado = true
				nivel_colado = nivel
			var a := 1.0 - smoothstep(0.0, alcance, d)
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


## O nivel do chunk de patamar `c`: o do GRUPO de patamares que dividem no com
## ele (os oito vizinhos, recursivamente), a media do terreno em todos os cantos
## do grupo, ou o nivel do parque quando algum canto encosta num. O parque manda
## nos nos dele; sem herdar o nivel, o patamar ao lado de uma praca saia com um
## canto 1,5 m fora e o salao do bar ganhava degrau de novo. Le o terreno BRUTO:
## a altura nivelada dos cantos depende deste nivel.
##
## Grupo, e nao o chunk sozinho: a porta de loja cai em diagonal (ChunkBuilder.
## _porta_do_chunk), e com o mercado no mundo os patamares passaram de 41 para 166
## em 52 x 52 chunks, 84 deles encostados num vizinho. Cada um no seu nivel, o no
## do canto ficava com o primeiro e o outro saia torto — 47 tortos, ate 5,9 m.
## O grupo e a componente inteira (a maior medida tem 5 chunks), igual visto de
## qualquer membro.
static func _nivel_do_patamar(c: Vector2i) -> float:
	_trava.lock()
	var achado: Variant = _niveis_patamar.get(c)
	_trava.unlock()
	if achado != null:
		return float(achado)
	var grupo: Array[Vector2i] = [c]
	var no_grupo := {c: true}
	var k := 0
	while k < grupo.size() and grupo.size() < GRUPO_MAXIMO:
		var g := grupo[k]
		k += 1
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var v := g + Vector2i(dx, dz)
				if not no_grupo.has(v) and tem_patamar(v.x, v.y):
					no_grupo[v] = true
					grupo.append(v)
	# Ordem canonica: o parque que manda e o do primeiro canto na mesma ordem
	# para qualquer membro.
	grupo.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var cantos := {}
	for g: Vector2i in grupo:
		for canto: Vector2i in [g, g + Vector2i(1, 0), g + Vector2i(0, 1), g + Vector2i(1, 1)]:
			cantos[canto] = true
	var nivel := NAN
	for g: Vector2i in grupo:
		for canto: Vector2i in [g, g + Vector2i(1, 0), g + Vector2i(0, 1), g + Vector2i(1, 1)]:
			for vizinho: Vector2i in [canto + Vector2i(-1, -1), canto + Vector2i(0, -1),
					canto + Vector2i(-1, 0), canto]:
				if is_nan(nivel) and _eh_parque(vizinho):
					nivel = _nivel_do_parque(vizinho)
	var sem_parque := is_nan(nivel)
	if is_nan(nivel):
		# O canto que cai numa avenida vale o que o aterro dela daria ao no
		# (`_aterro_bruto`), e nao o chao cru: o no do patamar fica cravado, e
		# cravado no chao cru ele juntava o desnivel da avenida inteira no trecho
		# seguinte (40% num lugar em que a avenida aterrada tem 20).
		var soma := 0.0
		for canto: Vector2i in cantos:
			soma += _aterro_bruto(canto.x, canto.y)
		nivel = soma / float(cantos.size())
	if sem_parque:
		# Parque a um trecho do grupo (a dois chunks): o nivel dele manda, e o
		# patamar fica a no maximo DECLIVE_JUNTO_A_ZONA dele — aterro ou corte
		# onde o morro nao deixa.
		var folga := DECLIVE_JUNTO_A_ZONA * TAM
		for g: Vector2i in grupo:
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					var v := g + Vector2i(dx, dz)
					if _eh_parque(v):
						var p := _nivel_do_parque(v)
						nivel = clampf(nivel, p - folga, p + folga)
	_trava.lock()
	if _niveis_patamar.size() > 20000:
		_niveis_patamar.clear()
	for g: Vector2i in grupo:
		_niveis_patamar[g] = nivel
	_trava.unlock()
	return nivel


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
	var h := soma / peso
	# O no cravado numa zona (parque, patamar) ali adiante na linha nao se mexe:
	# a media sozinha deixava o desnivel dele todo no trecho colado nele. A
	# avenida fica a no maximo DECLIVE_JUNTO_A_ZONA dele, por trecho de distancia.
	for k in range(1, JANELA_AVENIDA + 1):
		for s: int in [-1, 1]:
			for eixo: Vector2i in ([Vector2i(0, 1)] if em_x else []) + ([Vector2i(1, 0)] if em_z else []):
				var n := Vector2i(i, j) + eixo * (k * s)
				if _no_de_zona(n.x, n.y):
					var z := _nivelada(n.x, n.y)
					var folga := DECLIVE_JUNTO_A_ZONA * TAM * float(k)
					h = clampf(h, z - folga, z + folga)
	return h


## O terreno do no como o aterro da avenida o veria: a media triangular do
## terreno BRUTO ao longo da linha (das duas, no cruzamento de avenidas), a mesma
## janela de `_aterrada`. Fora da avenida, o terreno. Serve ao nivel do patamar,
## que nao pode ler o nivelado (o nivelado depende dele).
static func _aterro_bruto(i: int, j: int) -> float:
	var em_x := MalhaUrbana.via_x(i) == MalhaUrbana.Via.AVENIDA
	var em_z := MalhaUrbana.via_z(j) == MalhaUrbana.Via.AVENIDA
	if not em_x and not em_z:
		return _terreno(i, j)
	var soma := 0.0
	var peso := 0.0
	for k in range(-JANELA_AVENIDA, JANELA_AVENIDA + 1):
		var w := float(JANELA_AVENIDA + 1 - absi(k))
		if em_x:
			soma += _terreno(i, j + k) * w
			peso += w
		if em_z:
			soma += _terreno(i + k, j) * w
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


## O chunk tem lugar onde se entra andando e que pede o chao plano? O bar (o
## salao abre inteiro para a calcada) e a casa da fumaca no mundo.
##
## Lista, e nao "toda porta no mundo": o mercado tambem entra andando, mas o lote
## dele sobe rigido pela altura da porta (ChunkBuilder._erguer_lote), como o de
## qualquer casa de morro, e o verificar_mercado passava assim. Pela regra antiga
## ele virou patamar sem ninguem pedir: 110 mercados em 52 x 52 chunks, a cidade
## achatada e a avenida a 40% entre dois patamares.
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
	# O bar e patamar sempre; a casa, quando o lote dela cabe e ela existe atras
	# da porta ("mundo") — senao a porta teleporta e nao ha salao nenhum ali.
	var planta := StringName(porta.get("interior", &""))
	var mundo := bool(porta.get("mundo", false))
	var tem: bool = planta == &"bar" or (PLANTAS_DE_PATAMAR.has(planta) and mundo)
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

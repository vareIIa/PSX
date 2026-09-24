## O que a serpentina (Serpentina) poe em cada chunk da celula de encosta: a
## rua em curva, a calcada e o meio-fio, as casas de frente para a curva, o
## pasto e o mato entre as voltas e os postes.
##
## Quando roda
## -----------
## Depois de o chunk ter o chao assentado no morro (ChunkBuilder.construir):
## tudo aqui sai com a altura absoluta do Relevo, ponto a ponto, e deformar de
## novo levaria a rua duas vezes para cima.
##
## Quem e dono de cada pedaco
## --------------------------
## A rua e amostrada no mundo (Serpentina.caminho), e cada quadrilatero dela e
## do chunk que tem o MEIO dele. O vizinho desenha o seguinte com os mesmos
## pontos de mundo, entao a emenda nao abre. A casa e do chunk que tem a frente
## dela, mesmo que o fundo passe para o outro lado da borda.
class_name SerpentinaBuilder
extends RefCounted

const TAM := MalhaUrbana.TAM
const PISO_RUA := 0.05
const MEIO_FIO := KitModular.ALTURA_MEIO_FIO
const SAIA := KitModular.SAIA_MEIO_FIO
const COR_RUA := Color(0.82, 0.8, 0.76)
const COR_CALCADA := Color(0.86, 0.84, 0.8)
## O pasto da encosta, dourado de capim seco: a segunda foto de referencia.
const COR_PASTO := Color(0.78, 0.7, 0.44)
## Poste a cada tanto de rua, e no maximo um por chunk (quatro luzes por chunk:
## o poste da grade ja pode ter gastado uma).
const PASSO_POSTE := 40.0
## Espaco entre dois pontos candidatos do mato e da arvore.
const GRADE_MATO := 3.2


## O vao na fileira da avenida por onde a serpentina entra, na face `face` do
## chunk: {"de", "ate", "serpentina"} no eixo da face, ou vazio. Vai para
## `_fileira` no lugar do beco.
static func vao_na_face(cx: int, cz: int, face: Dictionary) -> Dictionary:
	var dados := Serpentina.do_chunk(cx, cz)
	if dados.is_empty():
		return {}
	var origem := Vector2(float(cx) * TAM, float(cz) * TAM)
	var canto: Vector3 = face["canto"]
	var eixo: Vector3 = face["eixo"]
	var normal := KitModular._normal(int(face["direcao"]))
	var meia := Serpentina.MEIA_PISTA + Serpentina.CALCADA + 0.2
	for entrada: Dictionary in dados["entradas"]:
		var p: Vector2 = Vector2(entrada["ponto"]) - origem
		var local := Vector3(p.x, 0.0, p.y) - canto
		# Perto da linha da fachada desta face, e entrando por ela. Perto, e nao
		# em cima: a quadra pode ter recuo extra (MalhaUrbana, "recuo_extra", ate
		# 2,6 m) e a Serpentina nao sabe dele. A entrada corre reta e
		# perpendicular a fachada por ENTRADA metros, entao o ponto ao longo da
		# face e o mesmo em qualquer uma das linhas.
		if absf(local.dot(normal)) > 4.0:
			continue
		var dentro: Vector2 = entrada["para_dentro"]
		if Vector3(dentro.x, 0.0, dentro.y).dot(normal) > -0.5:
			continue
		var t := local.dot(eixo)
		if t < -meia or t > float(face["comprimento"]) + meia:
			continue
		return {"de": clampf(t - meia, 0.0, float(face["comprimento"])),
			"ate": clampf(t + meia, 0.0, float(face["comprimento"])),
			"serpentina": true}
	return {}


## O caminho da serpentina que passa por perto do chunk, em coordenada local.
## Para a colisao do chao (Relevo.mapa_de_colisao).
static func caminho_local(cx: int, cz: int) -> PackedVector2Array:
	var dados := Serpentina.do_chunk(cx, cz)
	var saida := PackedVector2Array()
	if dados.is_empty():
		return saida
	var origem := Vector2(float(cx) * TAM, float(cz) * TAM)
	var perto := Rect2(origem, Vector2(TAM, TAM)).grow(Serpentina.MEIA_PISTA
		+ Serpentina.CALCADA + Serpentina.PASSO * 2.0)
	var cam: PackedVector2Array = dados["caminho"]
	for k in cam.size():
		var dentro := perto.has_point(cam[k]) \
			or (k > 0 and perto.has_point(cam[k - 1])) \
			or (k + 1 < cam.size() and perto.has_point(cam[k + 1]))
		if dentro:
			saida.append(cam[k] - origem)
		elif saida.size() > 0 and saida[saida.size() - 1] != Vector2.INF:
			# Quebra: dois trechos do caminho que passam pelo chunk nao se ligam.
			saida.append(Vector2.INF)
	return saida


## A serpentina neste chunk.
static func construir(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], cx: int, cz: int, quadra: Dictionary,
		interior: bool) -> void:
	var dados := Serpentina.do_chunk(cx, cz)
	if dados.is_empty():
		return
	var origem := Vector2(float(cx) * TAM, float(cz) * TAM)
	var chunk := Rect2(origem, Vector2(TAM, TAM))
	var cam: PackedVector2Array = dados["caminho"]
	_rua(sup, cam, chunk, cx, cz)
	_postes(sup, props, cam, chunk, cx, cz)
	var celula: Vector2i = dados["celula"]
	for entrada: Dictionary in dados["entradas"]:
		if chunk.has_point(entrada["ponto"]):
			_placa(sup, props, entrada, NomesDeRua.nome_serpentina(celula.x, celula.y),
				cx, cz)
	var casas: Array = dados["casas"]
	for casa: Dictionary in casas:
		if chunk.has_point(casa["frente"]):
			_casa(sup, colisao, casa, quadra, cx, cz)
	_pasto(sup, colisao, cam, casas, dados["retangulo"], chunk, cx, cz, interior)


# --- rua ----------------------------------------------------------------------

static func _rua(sup: Dictionary, cam: PackedVector2Array, chunk: Rect2,
		cx: int, cz: int) -> void:
	var n := cam.size()
	var meia := Serpentina.MEIA_PISTA
	var fora := meia + Serpentina.CALCADA
	for k in range(0, n - 1):
		var a := cam[k]
		var b := cam[k + 1]
		if not chunk.has_point((a + b) * 0.5):
			continue
		var na := _normal(cam, k)
		var nb := _normal(cam, k + 1)
		# Pista.
		_faixa(sup, &"paralelepipedo", a, b, na, nb, -meia, meia, PISO_RUA, PISO_RUA,
			COR_RUA, cx, cz)
		# Calcada dos dois lados, com o meio-fio (e a saia debaixo da pista) e a
		# face de fora, que desce ate o chao do pasto.
		for lado: float in [1.0, -1.0]:
			var de := meia * lado
			var ate := fora * lado
			_faixa(sup, &"calcada", a, b, na, nb, minf(de, ate), maxf(de, ate),
				PISO_RUA + MEIO_FIO, PISO_RUA + MEIO_FIO, COR_CALCADA, cx, cz)
			_parede(sup, &"meio_fio", a, b, na, nb, de, PISO_RUA - SAIA,
				PISO_RUA + MEIO_FIO, -lado, cx, cz)
			_parede(sup, &"meio_fio", a, b, na, nb, ate, -0.06,
				PISO_RUA + MEIO_FIO, lado, cx, cz)


## A normal do caminho no ponto k, no plano: a esquerda de quem anda.
static func _normal(cam: PackedVector2Array, k: int) -> Vector2:
	var a := cam[maxi(k - 1, 0)]
	var b := cam[mini(k + 1, cam.size() - 1)]
	var t := (b - a).normalized()
	return Vector2(-t.y, t.x)


## A planta pousada pelo ponto MAIS BAIXO do pe dela, e nao pelo centro.
##
## O tufo de cartao cruzado tem a borda de baixo reta; pousado pelo centro
## numa encosta de 30 %, o lado de baixo boiava um palmo sobre o capim e o
## de cima enterrava (V7 do PLANO_FLORA_AAA). Pelo mais baixo dos cinco
## pontos do pe, o lado de cima enterra um pouco — que e como planta
## nasce em barranco — e nenhum boia. Nao sorteia nada.
static func _no_chao_pe(p: Vector2, cx: int, cz: int, raio: float) -> Vector3:
	var base := _no_chao(p, cx, cz, 0.0)
	for d: Vector2 in [Vector2(raio, 0.0), Vector2(-raio, 0.0), Vector2(0.0, raio),
			Vector2(0.0, -raio)]:
		base.y = minf(base.y, Relevo.altura(p.x + d.x, p.y + d.y))
	return base


## Ponto do mundo a `lado` metros do caminho, na altura do chao mais `acima`,
## em coordenada local do chunk.
static func _no_chao(p: Vector2, cx: int, cz: int, acima: float) -> Vector3:
	return Vector3(p.x - float(cx) * TAM, Relevo.altura(p.x, p.y) + acima,
		p.y - float(cz) * TAM)


## Uma faixa horizontal entre `de` e `ate` metros do eixo, de a ate b.
static func _faixa(sup: Dictionary, material: StringName, a: Vector2, b: Vector2,
		na: Vector2, nb: Vector2, de: float, ate: float, acima_a: float, acima_b: float,
		cor: Color, cx: int, cz: int) -> void:
	EscadariaBuilder.quad(sup, material,
		_no_chao(a + na * de, cx, cz, acima_a), _no_chao(a + na * ate, cx, cz, acima_a),
		_no_chao(b + nb * ate, cx, cz, acima_b), _no_chao(b + nb * de, cx, cz, acima_b),
		Vector3.UP, cor)


## Uma face vertical na linha a `lado` metros do eixo, de `baixo` a `alto` acima
## do chao, olhando para o lado de `olha` (+1 esquerda do caminho, -1 direita).
static func _parede(sup: Dictionary, material: StringName, a: Vector2, b: Vector2,
		na: Vector2, nb: Vector2, lado: float, baixo: float, alto: float, olha: float,
		cx: int, cz: int) -> void:
	var pa := a + na * lado
	var pb := b + nb * lado
	var normal := ((na + nb) * 0.5).normalized() * olha
	EscadariaBuilder.quad(sup, material,
		_no_chao(pa, cx, cz, baixo), _no_chao(pb, cx, cz, baixo),
		_no_chao(pb, cx, cz, alto), _no_chao(pa, cx, cz, alto),
		Vector3(normal.x, 0.0, normal.y), Color.WHITE)


## Poste de sodio a cada PASSO_POSTE metros, na calcada de fora da curva, com o
## braco sobre a pista. Um por chunk.
static func _postes(sup: Dictionary, props: Array[Dictionary], cam: PackedVector2Array,
		chunk: Rect2, cx: int, cz: int) -> void:
	var cada := int(PASSO_POSTE / Serpentina.PASSO)
	var k := cada / 2
	while k < cam.size() - 1:
		var p := cam[k]
		if chunk.has_point(p):
			var n := _normal(cam, k)
			var lado := 1.0 if k % (cada * 2) < cada else -1.0
			var pe := p + n * lado * (Serpentina.MEIA_PISTA + Serpentina.CALCADA - 0.35)
			var base := _no_chao(pe, cx, cz, PISO_RUA + MEIO_FIO)
			var braco := Vector3(-n.x * lado, 0.0, -n.y * lado)
			KitRede.poste_de_luz(sup, base, braco)
			props.append({
				"tipo": "lampada",
				"pos": base + braco * 1.4 + Vector3(0.0, 6.35, 0.0),
				"padrao": Lampada.Padrao.ESTAVEL,
				"semente": 7101 + cx * 137 + cz * 911,
			})
			return
		k += cada


## A placa azul com o nome da ladeira na boca dela, na calcada da direita de
## quem entra, rente a fachada — como a placa de esquina da grade
## (NomesDeRua.placas).
static func _placa(sup: Dictionary, props: Array[Dictionary], entrada: Dictionary,
		nome: String, cx: int, cz: int) -> void:
	var dentro: Vector2 = entrada["para_dentro"]
	var direita := Vector2(-dentro.y, dentro.x)
	var pe_mundo: Vector2 = Vector2(entrada["ponto"]) + dentro * 1.2 \
		+ direita * (Serpentina.MEIA_PISTA + Serpentina.CALCADA - 0.35)
	var base := _no_chao(pe_mundo, cx, cz, PISO_RUA + MEIO_FIO)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 1.5, 0.0),
		Vector3(0.07, 3.0, 0.07), Color("5a5e60"), 0.0, PSXMesh.FACE_TODAS, 8.0)
	# A placa corre ao longo da rua, lida de quem vem pela avenida.
	NomesDeRua._placa(sup, props, base + Vector3(0.0, 2.85, 0.0), nome,
		absf(dentro.y) > absf(dentro.x))


# --- casas --------------------------------------------------------------------

## Uma casa de frente para a curva.
##
## Montada no espaco dela — fachada na linha z = 0 olhando para +Z, como o kit
## sabe fazer — e girada para o chunk (PSXMesh.acumular). A casa sobe rigida
## pela altura do chao na frente dela; por baixo, o embasamento desce ate o
## canto mais baixo do lote, e vira porao quando passa de um andar.
static func _casa(sup: Dictionary, colisao: Array[Dictionary], casa: Dictionary,
		quadra: Dictionary, cx: int, cz: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(casa["semente"])
	var frente: Vector2 = casa["frente"]
	var olha: Vector2 = casa["olha"]
	var larg: float = casa["largura"]
	var andares: int = casa["andares"]
	var fundo := Serpentina.FUNDO_CASA
	var altura := float(andares) * KitModular.ALTURA_ANDAR
	var tinta: Color = MalhaUrbana.CORES_CASA[rng.randi() % MalhaUrbana.CORES_CASA.size()]
	var prob_janela := float(quadra.get("janela", 0.4))

	var giro := atan2(olha.x, olha.y)
	# O piso da casa no nivel da calcada: a soleira rente a ela.
	var chao := Relevo.altura(frente.x, frente.y) + PISO_RUA + MEIO_FIO
	var xf := Transform3D(Basis(Vector3.UP, giro),
		Vector3(frente.x - float(cx) * TAM, chao, frente.y - float(cz) * TAM))
	var lado := Vector2(-olha.y, olha.x)
	# O canto mais baixo do lote, no espaco da casa.
	var mais_baixo := 0.0
	for c: Vector2 in [Vector2(-0.5, 0.0), Vector2(0.5, 0.0), Vector2(-0.5, 1.0),
			Vector2(0.5, 1.0)]:
		var w := frente + lado * (c.x * larg) - olha * (c.y * fundo)
		mais_baixo = minf(mais_baixo, Relevo.altura(w.x, w.y) - chao)

	var local := {}
	# A casa da grade (FachadaViva, TelhadoVivo, FundosVivos): o kit antigo daqui
	# tinha a lateral em concreto chumbo, a empena do telhado em reboco claro
	# (o topo de outra cor que o corpo) e a porta da cozinha pendurada a um
	# metro do quintal, sem degrau.
	var plano := FachadaViva.planejar(rng, quadra, larg, andares, tinta)
	if int(plano["andares"]) != andares:
		andares = int(plano["andares"])
		altura = float(andares) * KitModular.ALTURA_ANDAR
	plano["fundura"] = fundo
	# Casa solta nao encosta em vizinha: tres em cinco tem telhado de quatro
	# aguas; as outras mostram a empena, na cor do corpo (TelhadoVivo).
	plano["quinas"] = [-1.0, 1.0] if rng.randf() < 0.6 else []
	var cor_corpo: Color = plano.get("cor_corpo", tinta)
	# A massa: lados e topo. A frente some atras da fachada e o fundo e a
	# parede de FundosVivos.fundo.
	KitModular.caixa_cor(local, plano.get("mat_corpo", &"reboco"),
		Vector3(0.0, altura * 0.5, -fundo * 0.5 + ChunkBuilder.AVANCO_FACHADA * 0.5),
		Vector3(larg, altura, fundo + ChunkBuilder.AVANCO_FACHADA), cor_corpo, 0.0,
		PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ | PSXMesh.FACE_TOPO)
	var info := {}
	FachadaViva.residencia(local, Vector3(0.0, 0.0, ChunkBuilder.AVANCO_FACHADA), larg,
		andares, 0, plano, prob_janela, NAN, false, [], info)
	FachadaViva.coroar(local, plano, Vector3(0.0, altura, -fundo * 0.5),
		Vector3(larg, 0.0, fundo), 0, rng)
	# O quintal atras desce com o morro: a porta da cozinha ganha a escadinha ate
	# o chao dele (FundosVivos._degrau), medido pelo giro da casa.
	FundosVivos.fundo(local, Vector3.ZERO, larg, andares, 0, plano, prob_janela, info,
		cx, cz, chao, false, xf)
	_empenas(local, larg, fundo, andares, rng, prob_janela)
	var fundo_pedra := 0.0
	if mais_baixo < -0.01:
		fundo_pedra = maxf(Relevo.EMBASAMENTO, -mais_baixo + 0.8)
		Relevo.embasamento(local, Vector3.ZERO, Vector3(0.0, 0.0, 1.0), larg, fundo,
			ChunkBuilder.AVANCO_FACHADA, fundo_pedra)
		var porta_fundo: Vector3 = info.get("porta_fundo", Vector3(INF, 0.0, 0.0))
		_porao(local, xf, cx, cz, larg, fundo, chao, porta_fundo.x)
	for mat: StringName in local:
		if not sup.has(mat):
			sup[mat] = PSXMesh.dados_vazios()
		PSXMesh.acumular(sup[mat], local[mat], xf)

	# Colisao: a massa e o embasamento, girados com a casa.
	var giro3 := Vector3(0.0, giro, 0.0)
	colisao.append({"tamanho": Vector3(larg, altura, fundo),
		"pos": xf * Vector3(0.0, altura * 0.5, -fundo * 0.5), "giro": giro3})
	if fundo_pedra > 0.0:
		var alto_col := maxf(fundo_pedra, 2.2)
		colisao.append({"tamanho": Vector3(larg, alto_col, fundo),
			"pos": xf * Vector3(0.0, -alto_col * 0.5, -fundo * 0.5), "giro": giro3})


## As duas empenas da casa solta, com janela em todo andar.
##
## Casa de serpentina nao encosta em outra: de quem sobe a curva, a lateral e
## vista inteira, e sem janela ela era um paredao liso do tamanho da casa. No
## terreo a janela e a da frente (KitFachada._janela_terrea: vidro, moldura,
## peitoril e grade); em cima, vidro, moldura e peitoril em placa, sem grade.
## Custo: uns 60 triangulos por casa de dois andares.
static func _empenas(local: Dictionary, larg: float, fundo: float, andares: int,
		rng: RandomNumberGenerator, prob_janela: float) -> void:
	var n := maxi(1, int((fundo - 1.6) / 3.4))
	var passo := (fundo - 1.0) / float(n)
	for direcao: int in [1, 3]:
		var giro := PI * 0.5 * float(direcao)
		var lateral := KitModular._lateral(direcao)
		var normal := KitModular._normal(direcao)
		var x := larg * 0.5 * normal.x
		for andar in andares:
			for k in n:
				var meio := Vector3(x, float(andar) * KitModular.ALTURA_ANDAR,
					-0.5 - passo * (float(k) + 0.5))
				if andar == 0:
					KitFachada._janela_terrea(local, meio, passo, direcao, giro, lateral,
						normal, rng, prob_janela)
					continue
				var y := meio + Vector3(0.0, 1.45, 0.0)
				KitModular.parede(local, &"janela_acesa" if rng.randf() < prob_janela
					else &"janela_apagada", y + normal * 0.055, Vector2(1.1, 1.25), direcao)
				KitModular.parede(local, &"concreto", y + normal * 0.02,
					Vector2(1.32, 1.45), direcao, KitFachada.PEDRA.darkened(0.1))
				# Peitoril em placa, como o dos andares da frente (KitFachada._andares):
				# ninguem olha o peitoril do segundo andar de baixo.
				KitModular.parede(local, &"concreto", y + normal * 0.03 - Vector3(0.0, 0.72, 0.0),
					Vector2(1.46, 0.12), direcao, KitFachada.PEDRA)


## O porao da casa pendurada na curva: quando o chao atras dela desce mais que
## um andar (ChunkBuilder.PORAO_MINIMO), o embasamento vira o andar de baixo, com
## a porta rente ao quintal e as janelinhas. O mesmo que o ChunkBuilder._porao
## faz na grade, no espaco da casa girada. A porta da cozinha la em cima desce
## pela escadinha de FundosVivos; `x_cozinha` e onde ela esta, e nada do porao
## vai atras dela.
static func _porao(local: Dictionary, xf: Transform3D, cx: int, cz: int, larg: float,
		fundo: float, chao: float, x_cozinha: float) -> void:
	var z := -(fundo + 0.06)
	var origem := Vector3(float(cx) * TAM, 0.0, float(cz) * TAM)
	var meio := xf * Vector3(0.0, 0.0, z) + origem
	if Relevo.altura(meio.x, meio.z) - chao > -ChunkBuilder.PORAO_MINIMO:
		return
	var n := maxi(1, int(larg / 3.0))
	var passo := larg / float(n)
	# A porta do porao no vao mais longe da escadinha da cozinha.
	var k_porta := 0 if x_cozinha > 0.0 else n - 1
	for k in n:
		var off := (float(k) - float(n - 1) * 0.5) * passo
		if absf(off - x_cozinha) < 1.6:
			continue
		var w := xf * Vector3(off, 0.0, z) + origem
		var no_chao := Relevo.altura(w.x, w.z) - chao
		if k == k_porta:
			KitModular.parede(local, &"porta", Vector3(off, no_chao + 1.05, z),
				Vector2(0.9, 2.1), 2)
		elif -no_chao > 1.6:
			KitModular.parede(local, &"janela_apagada", Vector3(off, no_chao + 1.5, z),
				Vector2(0.9, 0.7), 2)


# --- pasto --------------------------------------------------------------------

## O pasto dourado, o mato e a arvore entre as voltas da serpentina.
##
## So no miolo da celula (fora da faixa da fileira e dos quintais da avenida),
## longe da pista e das casas. O chao de baixo e o plano do quarteirao, pintado
## de pasto por quem monta a quadra (ChunkBuilder._quadra).
##
## Com a Vegetacao: capao de mata onde o ruido de 16 m diz grota (a mata junta,
## nao sai salpicada), mangueira, abacateiro e ipe soltos no pasto, bananeira e
## touceira de coloniao no meio do capim.
static func _pasto(sup: Dictionary, colisao: Array[Dictionary], cam: PackedVector2Array,
		casas: Array, celula: Rect2, chunk: Rect2, cx: int, cz: int, _interior: bool) -> void:
	var ob := Obra.new()
	var miolo := celula.grow(-Serpentina.BORDA + 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = MalhaUrbana._ruido(cx, cz, 6613)
	var livre := Serpentina.MEIA_PISTA + Serpentina.CALCADA + 1.2
	var passos := int(TAM / GRADE_MATO)
	for iz in passos:
		for ix in passos:
			var p := chunk.position + Vector2(float(ix) + rng.randf(), float(iz) + rng.randf()) \
				* GRADE_MATO
			var sorte := rng.randf()
			var tamanho := rng.randf_range(0.7, 1.4)
			var giro := rng.randf_range(0.0, TAU)
			if not miolo.has_point(p):
				continue
			if Serpentina.distancia(cam, p) < livre:
				continue
			if _perto_de_casa(p, casas, 1.6):
				continue
			# Pelo pe inteiro, e nao pelo centro (V7 do PLANO_FLORA_AAA).
			var base := _no_chao_pe(p, cx, cz, tamanho * 0.55)
			if Vegetacao.ativo:
				_planta(sup, ob, colisao, cam, casas, p, base, sorte, tamanho, giro, livre, rng)
			elif sorte < 0.035:
				# Eucalipto: o que a encosta de Minas tem de mais alto.
				KitEstrada.arvore(sup, base, rng.randf_range(0.3, 1.0), rng)
			elif sorte < 0.6:
				var celula_atlas := KitEstrada.C_CAPIM_SECO if rng.randf() < 0.6 \
					else KitEstrada.C_CAPIM
				KitEstrada.tufo(sup, base, celula_atlas, tamanho, giro,
					Color(1.0, 0.94, 0.72))
	ob.despejar(sup)


## Um ponto do pasto com a Vegetacao (ver `_pasto`).
static func _planta(sup: Dictionary, ob: Obra, colisao: Array[Dictionary],
		cam: PackedVector2Array, casas: Array, p: Vector2, base: Vector3, sorte: float,
		tamanho: float, giro: float, livre: float, rng: RandomNumberGenerator) -> void:
	var grota := MalhaUrbana._ruido(floori(p.x / 16.0), floori(p.y / 16.0), 6617) % 100 < 32
	var longe := Serpentina.distancia(cam, p) > livre + 3.5 and not _perto_de_casa(p, casas, 4.0)
	if grota and longe and sorte < 0.3:
		# A mata afunda meio metro: o pe do capao nao pousa no pasto.
		Vegetacao.mata(ob, base - Vector3(0.0, 0.5, 0.0), rng.randf_range(7.0, 11.0), rng)
	elif longe and sorte < 0.045:
		var especie: StringName = [&"mangueira", &"abacateiro", &"ipe_amarelo", &"jaqueira",
			&"ipe_rosa", &"mangueira"][rng.randi() % 6]
		Vegetacao.arvore(sup, colisao, base, especie, rng.randf_range(0.3, 1.0), rng)
	elif sorte < 0.065:
		Vegetacao.bananeira(sup, base, rng)
	elif sorte < 0.14:
		Vegetacao.touceira(ob, base, rng.randf_range(1.1, 1.8), rng)
	elif sorte < 0.6:
		var celula_atlas := KitEstrada.C_CAPIM_SECO if rng.randf() < 0.6 else KitEstrada.C_CAPIM
		KitEstrada.tufo(sup, base, celula_atlas, tamanho, giro, Color(1.0, 0.94, 0.72))


static func _perto_de_casa(p: Vector2, casas: Array, folga: float) -> bool:
	for casa: Dictionary in casas:
		var frente: Vector2 = casa["frente"]
		var olha: Vector2 = casa["olha"]
		var rel := p - frente
		var ao_lado := rel.dot(Vector2(-olha.y, olha.x))
		var para_tras := -rel.dot(olha)
		if absf(ao_lado) < float(casa["largura"]) * 0.5 + folga \
				and para_tras > -folga and para_tras < Serpentina.FUNDO_CASA + folga:
			return true
	return false

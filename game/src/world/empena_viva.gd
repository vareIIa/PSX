## A parede cega entre vizinhos de altura diferente: a empena que fica a vista.
##
## Por que existe
## -------------
## Na fileira cada lote sobe com a propria altura (andares, remate, e na ladeira a
## propria base), e a lateral do mais alto aparece por cima do vizinho: 60% dos
## pares, 23 mil m2 no levantamento da F4. Era a caixa da massa, reboco liso na
## cor da casa, de cima a baixo, no mesmo tom da fachada. Parede de divisa de
## verdade nunca e assim: ela nunca foi pensada para ser vista.
##
## Empena de cidade do interior mineiro:
##   - reboco encardido, com o escorrido da chuva descendo do topo e a mancha logo
##     acima do telhado do vizinho, onde a agua respinga;
##   - tijolo sem reboco (a autoconstrucao e o predio nunca rebocaram a divisa);
##   - o rufo de chapa onde o telhado do vizinho encosta;
##   - o anuncio pintado ha trinta anos, descascando;
##   - hera subindo, cano de PVC descendo.
## Na casa recuada o vizinho mostra ate a lateral do terreo, junto do jardim.
##
## Como e montado
## --------------
## Depois de todas as fileiras (ChunkBuilder._quadra, antes do quintal), com altura
## absoluta. Para cada par de lotes encostados na mesma face, a regiao da lateral
## de cada um que o outro NAO cobre: do perfil de cima do vizinho (telhado, empena
## de duas aguas, platibanda, laje) ate o perfil de cima do dono. Essa regiao ganha
## uma pele 1,5 cm para fora, em grade de 0,6 x 1 m, com a mancha na cor do
## vertice. Onde o vizinho existe, a pele fica dentro do volume dele e some.
##
## Custo: centenas de triangulos por empena, so onde ha empena. `--sem-empena` desliga.
class_name EmpenaViva
extends RefCounted

static var ativo := not OS.get_cmdline_user_args().has("--sem-empena")
## Bancada: com `registrar`, cada empena anota onde ficou (coordenada do chunk).
static var registrar := false
static var registro: Array[Dictionary] = []

const PASSO_S := 0.6
const PASSO_Y := 1.0
## A pele fica fora da parede da massa (e dentro do volume do vizinho).
const AFASTA := 0.015
const MIN_ALTO := 0.3
const SUJO := Color(0.5, 0.5, 0.44)
## Reboco cru de cimento: a divisa que ninguem pintou.
const CRU := Color("bcb5a8")
const TIJOLO := Color(0.93, 0.9, 0.88)
## A sarjeta transparente em volta de cada painel do atlas de anuncios (16 px de 1024).
const SARJETA := 16.0 / 1024.0


static func construir(sup: Dictionary, faces: Array[Dictionary], lotes: Array[Dictionary],
		cx: int, cz: int) -> void:
	if not ativo:
		return
	var ob := Obra.new()
	for face: Dictionary in faces:
		var da_face: Array[Dictionary] = []
		for l: Dictionary in lotes:
			if l["face"] == face and l.has("plano") and l.has("dy"):
				da_face.append(l)
		da_face.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["de"]) < float(b["de"]))
		for k in da_face.size() - 1:
			var a: Dictionary = da_face[k]
			var b: Dictionary = da_face[k + 1]
			var t := float(a["ate"])
			if absf(t - float(b["de"])) > 0.05:
				continue
			# A lateral de cada um, virada para o outro.
			_lado(ob, face, a, b, t, 1.0, cx, cz)
			_lado(ob, face, b, a, t, -1.0, cx, cz)
	ob.despejar(sup)


## Onde a massa do lote comeca, em `s` a partir da linha da face (a fachada fica
## AVANCO_FACHADA a frente da massa recuada).
static func _frente(plano: Dictionary) -> float:
	return float(plano.get("recuo_real", 0.0)) - ChunkBuilder.AVANCO_FACHADA


## Altura absoluta do topo da lateral do lote na profundidade `s` (da linha da
## face). Para o dono vale a parede de verdade; para o vizinho, um limite de
## baixo basta (onde ele e mais alto, a pele fica dentro dele).
static func _topo(lote: Dictionary, s: float) -> float:
	var plano: Dictionary = lote["plano"]
	var dy := float(lote["dy"])
	var altura := int(plano.get("andares", 1)) * KitModular.ALTURA_ANDAR
	var sf := _frente(plano)
	var fundo := ChunkBuilder.PROF_PREDIO - sf
	var sl := clampf(s - sf, 0.0, fundo)
	var remate: StringName = plano.get("remate", &"laje")
	var t: Dictionary = plano.get("telhado", {})
	var forma: StringName = t.get("forma", &"")
	var mureta := 1.0 if remate == &"platibanda" else 0.5
	match forma:
		&"aparente":
			var c := float(t["caimento"])
			return dy + TelhadoVivo._y_parede(plano, altura, c) + minf(sl, fundo - sl) * c
		&"escondido":
			var c := float(t["caimento"])
			var s0 := ChunkBuilder.AVANCO_FACHADA + 0.18
			var s1 := fundo - 0.18
			var y_pe := altura + mureta - 0.14 - TelhadoVivo.ESPESSURA
			var agua := y_pe + maxf(0.0, minf(sl - s0, s1 - sl)) * c
			return dy + maxf(altura + mureta + 0.06, agua)
		&"meia_agua":
			return dy + altura + mureta + 0.06
		&"laje_coberta":
			return dy + altura + 0.36
	if plano.has("industria"):
		return dy + altura + (0.4 if remate == &"platibanda" else 0.0)
	match remate:
		&"platibanda", &"platibanda_baixa":
			return dy + altura + mureta + 0.06
		&"laje":
			return dy + altura + 0.36
		&"beiral":
			return dy + altura + 0.44
	return dy + altura


## Pontos de quebra do perfil de cima de um lote (a cumeeira da empena e onde a
## agua escondida passa da mureta), para a grade nao cortar o bico.
static func _quebras(lote: Dictionary) -> Array[float]:
	var plano: Dictionary = lote["plano"]
	var sf := _frente(plano)
	var fundo := ChunkBuilder.PROF_PREDIO - sf
	var saida: Array[float] = [sf, sf + fundo * 0.5]
	return saida


## A pele da lateral de `dono` virada para `vizinho`, no plano t da divisa;
## `sentido` e para que lado do eixo da face o vizinho fica.
static func _lado(ob: Obra, face: Dictionary, dono: Dictionary, vizinho: Dictionary,
		t: float, sentido: float, _cx: int, _cz: int) -> void:
	var pd: Dictionary = dono["plano"]
	var pv: Dictionary = vizinho["plano"]
	# Do lado da quina nao ha divisa (a lateral e fachada, FundosVivos).
	var s0d := _frente(pd)
	var s0v := _frente(pv)
	var fim := ChunkBuilder.PROF_PREDIO
	var base := float(dono["dy"])
	var ss: Array[float] = [s0d, fim]
	if s0v > s0d + 0.02 and s0v < fim:
		ss.append(s0v)
	for q: float in _quebras(dono) + _quebras(vizinho):
		if q > s0d + 0.02 and q < fim - 0.02:
			ss.append(q)
	var n := maxi(1, ceili((fim - s0d) / PASSO_S))
	for k in range(1, n):
		ss.append(lerpf(s0d, fim, float(k) / float(n)))
	ss.sort()
	var cols: Array[Vector3] = []   # (s, baixo, alto)
	var alto_max := 0.0
	for s: float in ss:
		if not cols.is_empty() and s - cols[-1].x < 0.01:
			continue
		var cima := _topo(dono, s)
		var baixo := base
		if s >= s0v - 0.001:
			baixo = maxf(base, _topo(vizinho, s))
		if cima < baixo:
			cima = baixo
		cols.append(Vector3(s, baixo, cima))
		alto_max = maxf(alto_max, cima - baixo)
	if alto_max < MIN_ALTO:
		return

	var r := RandomNumberGenerator.new()
	r.seed = int(pd.get("semente", 0)) ^ (0x3e9a if sentido > 0.0 else 0x71c5)
	var estilo: StringName = pd.get("estilo", &"popular")
	var morador: StringName = pd.get("morador", &"familia")
	var tipo: StringName = pd.get("tipo", &"")
	var chance_tijolo := 0.12
	match estilo:
		&"popular":
			chance_tijolo = 0.55
		&"predio":
			chance_tijolo = 0.5
		&"moderno":
			chance_tijolo = 0.18
		&"colonial":
			chance_tijolo = 0.04
	if pd.has("industria"):
		chance_tijolo = 0.35
	var tijolo := r.randf() < chance_tijolo
	var material: StringName = &"tijolo" if tijolo else pd.get("mat_corpo", &"reboco")
	var cor_base: Color = TIJOLO if tijolo else pd.get("cor_corpo", Color("d8d2c6"))
	if not tijolo:
		# A divisa ou ficou no reboco cru de cimento, ou tem a tinta da frente
		# desbotada (so a fachada ganha demao nova).
		if r.randf() < 0.45:
			cor_base = CRU.lerp(Color("a9a296"), r.randf())
		else:
			cor_base = cor_base.lerp(Color("b4ada0"), r.randf_range(0.2, 0.45))
	var sujeira := r.randf_range(0.05, 0.14)
	if morador == &"abandonada":
		sujeira += 0.12

	var eixo: Vector3 = face["eixo"]
	var fora := eixo * sentido
	var linhas := clampi(ceili(alto_max / PASSO_Y), 1, 10)
	var m := ob.malha(material)
	var colunas: Array[PackedInt32Array] = []
	var vizinho_telhado: bool = (pv.get("telhado", {}) as Dictionary).get("forma", &"") in [&"aparente", &"escondido"]
	for c: Vector3 in cols:
		var s := c.x
		var sobre_vizinho := s >= s0v - 0.001
		# Escorrido: cada coluna com a sua lavagem, forte perto do topo.
		var lava := clampf(r.randf_range(-0.1, 0.6), 0.0, 0.6)
		var desce := r.randf_range(1.2, 3.2)
		var ids := PackedInt32Array()
		for k in linhas + 1:
			var y := lerpf(c.y, c.z, float(k) / float(linhas))
			var p := FundosBuilder._ponto(face, t, s) + Vector3(0.0, y, 0.0) + fora * AFASTA
			var do_topo := c.z - y
			var do_pe := y - c.y
			# Mofo em bolha: um punhado de vertices mais escuros que os vizinhos.
			var mancha := sujeira + lava * (1.0 - smoothstep(0.0, desce, do_topo)) 				+ (r.randf_range(0.1, 0.22) if r.randf() < 0.12 else 0.0)
			if sobre_vizinho and c.y > base + 0.2:
				# O respingo e o limo logo acima do telhado do vizinho.
				mancha += 0.24 * (1.0 - smoothstep(0.0, 0.7, do_pe))
			else:
				# A umidade subindo do chao.
				mancha += 0.2 * (1.0 - smoothstep(0.0, 0.9, do_pe))
			var cor := cor_base.lerp(cor_base * SUJO, clampf(mancha, 0.0, 0.65))
			cor.a = 1.0
			var uv := Vector2(s * sentido, -y) * 0.5
			ids.append(m.vertice(p, fora, uv, Vector2.ZERO, cor))
		colunas.append(ids)
	for i in cols.size() - 1:
		if cols[i].z - cols[i].y < 0.02 and cols[i + 1].z - cols[i + 1].y < 0.02:
			continue
		var a: PackedInt32Array = colunas[i]
		var b: PackedInt32Array = colunas[i + 1]
		for k in linhas:
			m.quad(a[k], b[k], b[k + 1], a[k + 1], fora)

	# Rufo de chapa na linha do telhado do vizinho.
	if vizinho_telhado:
		var chapa := ob.malha(&"metal_pintado")
		var cor_rufo := Color("8e908a").darkened(r.randf() * 0.2)
		for i in cols.size() - 1:
			var c0 := cols[i]
			var c1 := cols[i + 1]
			if c0.x < s0v - 0.001 or c0.z - c0.y < 0.05 or c1.z - c1.y < 0.05:
				continue
			var q0 := FundosBuilder._ponto(face, t, c0.x) + fora * (AFASTA + 0.012)
			var q1 := FundosBuilder._ponto(face, t, c1.x) + fora * (AFASTA + 0.012)
			var i0 := chapa.vertice(q0 + Vector3(0.0, c0.y - 0.03, 0.0), fora, Vector2.ZERO, Vector2.ZERO, cor_rufo)
			var i1 := chapa.vertice(q1 + Vector3(0.0, c1.y - 0.03, 0.0), fora, Vector2.ZERO, Vector2.ZERO, cor_rufo)
			var i2 := chapa.vertice(q1 + Vector3(0.0, c1.y + 0.11, 0.0), fora, Vector2.ZERO, Vector2.ZERO, cor_rufo)
			var i3 := chapa.vertice(q0 + Vector3(0.0, c0.y + 0.11, 0.0), fora, Vector2.ZERO, Vector2.ZERO, cor_rufo)
			chapa.quad(i0, i1, i2, i3, fora)

	# Anuncio pintado: o maior retangulo livre de 4 m ou mais.
	var chance_anuncio := 0.1
	if tipo == &"sobrado" or tipo == &"loja" or tipo == &"predio" or pd.has("industria"):
		chance_anuncio = 0.26
	var com_anuncio := false
	if r.randf() < chance_anuncio:
		com_anuncio = _anuncio(ob, face, t, fora, cols, r)
	# Cano de PVC descendo do topo.
	if r.randf() < 0.22:
		var i := r.randi_range(1, maxi(1, cols.size() - 2))
		var c := cols[i]
		if c.z - c.y > 1.2:
			var p := FundosBuilder._ponto(face, t, c.x) + fora * (AFASTA + 0.05)
			ob.caixa(&"metal_pintado", p + Vector3(0.0, (c.y + c.z) * 0.5, 0.0),
				Vector3(0.075, c.z - c.y, 0.075), Color("dcdad2"))
	# Hera subindo de um canto.
	if r.randf() < (0.3 if morador == &"abandonada" else 0.1):
		var i := r.randi_range(0, cols.size() - 1)
		var c := cols[i]
		var sobe := minf(c.z - c.y, r.randf_range(1.5, 4.0))
		var base_folha := Basis(fora.cross(Vector3.UP).normalized(), Vector3.UP, fora)
		for k in int(sobe * 5.0):
			var p := FundosBuilder._ponto(face, t, c.x + r.randf_range(-0.7, 0.7)) \
				+ Vector3(0.0, c.y + r.randf() * sobe, 0.0) + fora * r.randf_range(0.04, 0.14)
			var tt := Transform3D(base_folha * Basis(Vector3.BACK, r.randf_range(-0.6, 0.6)), p)
			JanelaViva.folhagem(ob, Vector2(0.5, 0.45), tt, Color(0.48, 0.66, 0.4))

	if registrar:
		var meio := FundosBuilder._ponto(face, t, (s0d + fim) * 0.5)
		registro.append({"meio": meio + Vector3(0.0, (base + alto_max) * 0.5, 0.0),
			"fora": fora, "alto": alto_max, "tijolo": tijolo, "estilo": estilo,
			"anuncio": com_anuncio, "base": base})


## O anuncio pintado no maior trecho em que cabe um painel de 2:1 de 4 a 5 m.
static func _anuncio(ob: Obra, face: Dictionary, t: float, fora: Vector3,
		cols: Array[Vector3], r: RandomNumberGenerator) -> bool:
	var melhor := Vector4.ZERO  # (s0, s1, y0, y1)
	for i in cols.size():
		var y_baixo := -INF
		var y_alto := INF
		for j in range(i, cols.size()):
			y_baixo = maxf(y_baixo, cols[j].y)
			y_alto = minf(y_alto, cols[j].z)
			var larg := cols[j].x - cols[i].x
			var livre := y_alto - y_baixo
			if livre < 2.4:
				break
			if larg >= 4.0 and larg * livre > (melhor.y - melhor.x) * (melhor.w - melhor.z):
				melhor = Vector4(cols[i].x, cols[j].x, y_baixo, y_alto)
	var larg := minf(melhor.y - melhor.x - 0.4, 5.0)
	if larg < 3.6:
		return false
	var alto := larg * 0.5
	var y0 := melhor.z + 0.5
	if y0 + alto > melhor.w - 0.3:
		alto = melhor.w - 0.3 - y0
		larg = alto * 2.0
		if larg < 3.2:
			return false
	var s_meio := (melhor.x + melhor.y) * 0.5
	var centro := FundosBuilder._ponto(face, t, s_meio) + Vector3(0.0, y0 + alto * 0.5, 0.0) \
		+ fora * (AFASTA + 0.008)
	var direita := Vector3.UP.cross(fora).normalized()
	var celula := r.randi() % 8
	# A celula recuada pela sarjeta transparente do atlas (tools/gerar_letreiros.py).
	var uv := Rect2(float(celula % 2) * 0.5 + SARJETA, float(celula / 2) * 0.25 + SARJETA,
		0.5 - SARJETA * 2.0, 0.25 - SARJETA * 2.0)
	ob.cartao(&"anuncio_empena", Vector2(larg, alto), Transform3D(Basis(direita, Vector3.UP, fora),
		centro), uv, Color(1.0, 1.0, 1.0).darkened(r.randf() * 0.15))
	return true

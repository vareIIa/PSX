## As corredoras: as gotas grandes que descem o vidro, simuladas na CPU.
##
## Por que na CPU, e por que nao um seno
## -------------------------------------
## O que havia era `deslize(t) = t + 0,30 sin(6,28 t) + 0,10 sin(12,6 t)`: uma
## coluna de gotas rolando para baixo num ritmo fixo. Isso da o para-e-escorrega
## de graca, e de graca da tambem o defeito: todas as colunas fazem a MESMA
## coisa, a gota nao sabe que o carro freou, nao sabe que o vidro esta inclinado
## a 60 graus nem que ha vento, e nao deixa rastro porque nao existe fora do
## quadro em que e desenhada.
##
## Aqui cada gota tem massa, posicao e velocidade em METROS no plano do vidro. O
## para-e-escorrega sai da ADESAO: a gota so anda quando a forca tangencial
## passa do limite que a massa dela aguenta. Parada, ela engorda com a agua em
## volta ate destravar; andando, perde massa no rastro ate travar de novo. Nao
## ha seno nenhum, e o ritmo e diferente em cada gota porque a massa e.
##
## As forcas, todas projetadas no plano do vidro:
##
##   peso     sempre para +v (que e morro abaixo por construcao do painel)
##   vento    o ar relativo ao carro, com v^2: no para-brisa SOBE a rampa e abre
##            para as bordas; na lateral deita para tras
##   inercia  a aceleracao do carro: freada empurra a agua para a base do
##            para-brisa, arrancada para o alto, curva para o lado
##
## O rastro vai para o mapa de agua (`AguaVidro`): a faixa por onde a gota
## passou perde cobertura e ganha filme. E o que faz o risco vertical continuar
## visivel depois de a gota ja ter descido.
class_name AguaCorredoras
extends Node3D

const SHADER := "res://shaders/psx_gota_corredora.gdshader"

## Teto de gotas: por vidro e no total. O total tem de caber no vetor de
## trilhas de `psx_agua_sim.gdshader`.
const POR_VIDRO := 24
const TOTAL := 48

const G := 9.81
## Amortecimento da velocidade, por segundo. Agua em vidro e um escoamento
## dominado por atrito, e nao um projetil: sem isto a gota acelera ate sair do
## vidro em dois quadros.
##
## O numero sai da VELOCIDADE FINAL, que e o que se pode conferir: com 7,0 a
## gota grande do para-brisa estabilizava em 0,67 m/s e atravessava o vidro
## inteiro em 0,8 s — chuva de verdade escorre entre 0,1 e 0,5 m/s. Com 14,0 ela
## fica em 0,34 m/s, que e uma gota grande de para-brisa inclinado. Medido na
## bancada (`tests/bancada_agua_vidro.gd`).
const ARRASTO := 14.0
## Forca de adesao a massa 1, em m/s^2. Dividida pela massa: gota grande
## descola, gota pequena fica. E o unico lugar de onde sai o para-e-escorrega.
const ADESAO := 2.8
## Coeficiente do vento, em m/s^2 por (m/s)^2 de ar relativo. A 60 km/h isso da
## cerca de 9,7 m/s^2 no plano — na mesma ordem do peso, que e o ponto em que o
## para-brisa inverte o sentido da agua.
const VENTO := 0.035
## Quanto o ar abre a agua do para-brisa para as bordas.
const ESPALHA := 0.40

const MASSA_NOVA := Vector2(0.30, 0.85)
const MASSA_MIN := 0.22
const MASSA_MAX := 2.60
## Ganho de massa por segundo parada, com cobertura 1.
const CRESCE := 0.85
## Perda de massa por metro andado, e ganho por metro com cobertura 1.
const PERDE := 1.30
const ENGOLE := 2.40

## Raio desenhado, em metros, para massa 1. A gota real tem 1 a 3 mm e some em
## 480x270; 6 a 14 mm de diametro e o tamanho estilizado que le como gota.
const RAIO := 0.0055

## Quantas gotas nascem por segundo, por metro quadrado de vidro, com chuva 1.
const NASCEM := 2.2

## Meia largura do rastro, em metros.
const RASTRO := 0.006

var _mmi: MultiMeshInstance3D
var _mm: MultiMesh
var _paineis: Array = []
var _rects: Array[Rect2] = []
## Cada gota: painel, p (m), vel (m/s), massa, ultimo (m).
var _gotas: Array[Dictionary] = []
## As trincas do vidro (`trincar`): por onde a agua corre depois da batida.
## Cada uma: painel, centro (m no painel), as radiais (direcao no painel e
## comprimento ja andado, m) e o miolo.
var _trincas: Array[Dictionary] = []
## A gota a menos que isto de uma radial entra nela (m), e a forca que a puxa
## para dentro do fio (m/s^2 por m).
const TRINCA_PEGA := 0.009
const TRINCA_PUXA := 180.0
## Duas gotas que se encostam viram uma: a distancia, em fracao da soma dos
## raios, em que a de cima e engolida pela de baixo.
const JUNTA := 0.8
var _por_vidro: PackedInt32Array = PackedInt32Array()
var _rng := RandomNumberGenerator.new()


func montar(paineis: Array, rects: Array[Rect2], semente: int = 20260916) -> void:
	_paineis = paineis
	_rects = rects
	_rng.seed = semente
	_por_vidro.resize(paineis.size())
	_por_vidro.fill(0)
	if not ResourceLoader.exists(SHADER):
		push_error("AguaCorredoras: shader ausente em %s" % SHADER)
		return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	# A optica de cada gota — raio, alongamento e brilho — viaja no custom.
	# `INSTANCE_CUSTOM` so existe em `vertex()`: lido no `fragment()` da
	# "Unknown identifier" e o shader inteiro nao compila (medido no spike F).
	_mm.use_custom_data = true
	_mm.mesh = _quadrinho()
	_mm.instance_count = TOTAL
	_mm.visible_instance_count = 0

	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER) as Shader
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Corredoras"
	_mmi.multimesh = _mm
	_mmi.material_override = mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)


## O material das gotas, para quem precisa apontar o mapa de agua nele.
func material() -> ShaderMaterial:
	return _mmi.material_override as ShaderMaterial if _mmi != null else null


## Um passo. Devolve os segmentos de rastro deste quadro, em UV do mapa.
##
## `vel_local` e `acel_local` sao a velocidade e a aceleracao do carro NO
## ESPACO DO CARRO — a mesma API para o carro da cena e para o da cidade, que e
## o que evita dois caminhos de entrada com dois sinais trocados.
func passo(chuva: float, cobertura: PackedFloat32Array, vel_local: Vector3,
		acel_local: Vector3, setor: Dictionary, delta: float) -> PackedVector4Array:
	var trilhas := PackedVector4Array()
	if _mm == null or _paineis.is_empty():
		return trilhas
	_nascer(chuva, cobertura, delta)

	var vivas: Array[Dictionary] = []
	var k := 0
	for g: Dictionary in _gotas:
		var i: int = g["painel"]
		var painel: Dictionary = _paineis[i]
		var tam: Vector2 = painel["tam"]
		var cob: float = cobertura[i] if i < cobertura.size() else 0.0
		g["ultimo"] = g["p"]

		var f := _forcas(painel, g["p"], vel_local, acel_local)
		if not _trincas.is_empty():
			f = _pelas_trincas(i, g["p"], f)
		var vel: Vector2 = g["vel"]
		var massa: float = g["massa"]
		var limite := ADESAO / maxf(massa, 0.05)
		var andando := vel.length() > 0.004 or f.length() > limite
		if andando:
			# A adesao nao some quando a gota anda: ela vira atrito, contra o
			# movimento. Sem isso a gota destravada nunca mais para.
			var freio := vel.normalized() * limite if vel.length() > 1e-4 			else f.normalized() * limite
			vel += (f - freio) * delta
			vel *= maxf(0.0, 1.0 - ARRASTO * delta)
		else:
			vel = Vector2.ZERO
		g["vel"] = vel
		var antes: Vector2 = g["p"]
		var p: Vector2 = antes + vel * delta
		g["p"] = p

		var andou := antes.distance_to(p)
		if andou > 1e-5:
			# Andando ela raspa o vidro: perde no rastro e engole o que acha.
			massa += (ENGOLE * cob - PERDE) * andou
		else:
			massa += CRESCE * cob * delta
		g["massa"] = clampf(massa, 0.0, MASSA_MAX)

		if _levada_pela_palheta(g, setor, i):
			continue
		if massa < MASSA_MIN or p.y > tam.y or p.y < -0.03 			or p.x < -0.05 or p.x > tam.x + 0.05:
			continue
		vivas.append(g)
		if andou > 1e-4 and trilhas.size() < TOTAL:
			trilhas.append(_segmento(i, antes, p))
		if k < TOTAL:
			_desenhar(k, painel, g)
			k += 1
	_juntar(vivas)
	_gotas = vivas
	_por_vidro.fill(0)
	for g: Dictionary in _gotas:
		_por_vidro[int(g["painel"])] += 1
	_mm.visible_instance_count = k
	return trilhas


## Duas gotas que se encostam viram uma: a de baixo (a que ja desceu mais)
## engole a de cima, com a massa das duas e a velocidade media pela massa. E o
## que faz dois filetes se juntarem num so e a gota grande nascer do caminho, e
## nao do ceu. N^2 por vidro, com o teto de `TOTAL` gotas no carro inteiro.
func _juntar(gotas: Array[Dictionary]) -> void:
	var k := 0
	while k < gotas.size():
		var a: Dictionary = gotas[k]
		var ra := RAIO * sqrt(maxf(float(a["massa"]), 0.01))
		var j := k + 1
		var engoliu := false
		while j < gotas.size():
			var b: Dictionary = gotas[j]
			if int(b["painel"]) != int(a["painel"]):
				j += 1
				continue
			var rb := RAIO * sqrt(maxf(float(b["massa"]), 0.01))
			var pa: Vector2 = a["p"]
			var pb: Vector2 = b["p"]
			if pa.distance_to(pb) > (ra + rb) * JUNTA:
				j += 1
				continue
			var fica := a if pa.y >= pb.y else b
			var some := b if is_same(fica, a) else a
			var ma := float(fica["massa"])
			var mb := float(some["massa"])
			fica["vel"] = ((fica["vel"] as Vector2) * ma + (some["vel"] as Vector2) * mb) \
				/ maxf(ma + mb, 0.001)
			fica["massa"] = minf(ma + mb, MASSA_MAX)
			if is_same(some, a):
				gotas.remove_at(k)
				engoliu = true
				break
			gotas.remove_at(j)
			ra = RAIO * sqrt(maxf(float(a["massa"]), 0.01))
		if not engoliu:
			k += 1


## A trinca de `TrincaDeVidro` passa a valer para a agua: a gota que chega num
## fio entra nele e desce por ele, e na teia do miolo ela empoca.
##
## `radiais` e a lista de (direcao em metros no espaco do carro, ja com o
## comprimento andado) saindo de `centro` (espaco do carro), no plano do vidro.
func trincar(tipo: StringName, lado: int, centro: Vector3,
		radiais: PackedVector3Array, miolo: float) -> void:
	for i in _paineis.size():
		var pn: Dictionary = _paineis[i]
		if pn["tipo"] != tipo or (tipo != &"parabrisa" and int(pn["lado"]) != lado):
			continue
		var o: Vector3 = pn["origem"]
		var eu: Vector3 = pn["u"]
		var ev: Vector3 = pn["v"]
		var c := Vector2((centro - o).dot(eu), (centro - o).dot(ev))
		var rs: Array[Vector3] = []
		for r: Vector3 in radiais:
			var d := Vector2(r.dot(eu), r.dot(ev))
			var l := d.length()
			if l > 0.005:
				rs.append(Vector3(d.x / l, d.y / l, l))
		_trincas.append({"painel": i, "c": c, "radiais": rs, "miolo": miolo})
		return


func _pelas_trincas(painel: int, p: Vector2, f: Vector2) -> Vector2:
	for t: Dictionary in _trincas:
		if int(t["painel"]) != painel:
			continue
		var d: Vector2 = p - (t["c"] as Vector2)
		if d.length() < float(t["miolo"]):
			# No miolo esfarelado a agua empoca: o vidro partido segura.
			return f * 0.25
		for r: Vector3 in t["radiais"]:
			var dir := Vector2(r.x, r.y)
			var ao_longo := d.dot(dir)
			if ao_longo < 0.0 or ao_longo > r.z:
				continue
			var fora := d - dir * ao_longo
			if fora.length() > TRINCA_PEGA:
				continue
			# Dentro do fio: a forca so vale ao longo dele, morro abaixo, e o fio
			# puxa a gota para o meio.
			var desce := dir if dir.y >= 0.0 else -dir
			var ao := maxf(f.dot(desce), f.length() * 0.35)
			return desce * ao - fora * TRINCA_PUXA
	return f


## Peso, vento e inercia, projetados no plano do vidro. Em m/s^2.
func _forcas(painel: Dictionary, p: Vector2, vel_local: Vector3,
		acel_local: Vector3) -> Vector2:
	var n: Vector3 = painel["normal"]
	var eu: Vector3 = painel["u"]
	var ev: Vector3 = painel["v"]
	var tam: Vector2 = painel["tam"]

	# Peso: `v` ja e a projecao da vertical no plano, entao o que sobra do peso
	# e `g * sin(inclinacao)` — no vidro deitado a agua quase nao desce, no
	# vidro em pe ela desce inteira, sem um "se" por tipo de janela.
	var f := Vector2(0.0, G * sqrt(maxf(0.0, 1.0 - n.y * n.y)))

	# Vento: o ar relativo ao carro e o oposto da velocidade dele.
	var ar := -vel_local
	var v2 := ar.length_squared()
	if v2 > 0.01:
		var no_plano := ar - n * ar.dot(n)
		var dir := Vector2(no_plano.dot(eu), no_plano.dot(ev))
		if dir.length_squared() > 1e-8:
			f += dir.normalized() * (VENTO * v2)
		# E o ar tambem ABRE a agua para as bordas, porque escapa pelos lados
		# do capo. So no para-brisa: e la que ele bate de frente.
		if absf(n.x) < 0.5:
			var meio := tam.x * 0.5
			var lado := signf(p.x - meio)
			f.x += lado * ESPALHA * VENTO * v2 * minf(1.0,
				absf(p.x - meio) / maxf(meio, 0.01))

	# Inercia: no referencial do carro, frear empurra tudo para a frente.
	var pseudo := -acel_local
	var pp := pseudo - n * pseudo.dot(n)
	f += Vector2(pp.dot(eu), pp.dot(ev))
	return f


## A palheta arrasta a gota que encontra. Devolve true se ela foi levada.
func _levada_pela_palheta(g: Dictionary, setor: Dictionary, painel: int) -> bool:
	if setor.is_empty() or not setor.get("ativo", false):
		return false
	if int(setor["painel"]) != painel:
		return false
	var raios: Vector2 = setor["raios"]
	var meia: float = setor.get("palheta", 0.035)
	for pivo: Vector2 in [setor["pivo_a"], setor["pivo_b"]]:
		var d: Vector2 = (g["p"] as Vector2) - pivo
		var r := d.length()
		if r < raios.x or r > raios.y:
			continue
		var ang := atan2(d.x, -d.y)
		var lo: float = minf(setor["ang_de"], setor["ang_ate"]) - meia
		var hi: float = maxf(setor["ang_de"], setor["ang_ate"]) + meia
		if ang >= lo and ang <= hi:
			return true
	return false


## Gotas novas, por chuva e por area. Nascem em cima: e de la que a agua desce.
func _nascer(chuva: float, cobertura: PackedFloat32Array, delta: float) -> void:
	if chuva <= 0.01 or _gotas.size() >= TOTAL:
		return
	for i in _paineis.size():
		if _por_vidro[i] >= POR_VIDRO or _gotas.size() >= TOTAL:
			continue
		var painel: Dictionary = _paineis[i]
		var tam: Vector2 = painel["tam"]
		var cob: float = cobertura[i] if i < cobertura.size() else 0.0
		var exposicao: float = painel.get("exposicao", 1.0)
		# So nasce corredora onde ja ha agua parada: uma gota grande e agua
		# pequena que se juntou, e nao agua que apareceu grande.
		var taxa := NASCEM * chuva * exposicao * tam.x * tam.y * cob * delta
		if _rng.randf() >= taxa:
			continue
		_gotas.append({
			"painel": i,
			"p": Vector2(_rng.randf_range(0.04, maxf(0.05, tam.x - 0.04)),
				_rng.randf_range(0.0, tam.y * 0.35)),
			"vel": Vector2.ZERO,
			"massa": _rng.randf_range(MASSA_NOVA.x, MASSA_NOVA.y),
			"ultimo": Vector2.ZERO,
		})
		(_gotas[_gotas.size() - 1] as Dictionary)["ultimo"] = _gotas[_gotas.size() - 1]["p"]
		_por_vidro[i] += 1


## Um segmento de rastro, em UV do mapa.
func _segmento(i: int, de: Vector2, ate: Vector2) -> Vector4:
	var painel: Dictionary = _paineis[i]
	var tam: Vector2 = painel["tam"]
	var r: Rect2 = _rects[i]
	var a := r.position + Vector2(de.x / maxf(tam.x, 1e-4),
		de.y / maxf(tam.y, 1e-4)) * r.size
	var b := r.position + Vector2(ate.x / maxf(tam.x, 1e-4),
		ate.y / maxf(tam.y, 1e-4)) * r.size
	return Vector4(a.x, a.y, b.x, b.y)


## Poe a gota `k` no lugar dela, no plano do vidro.
func _desenhar(k: int, painel: Dictionary, g: Dictionary) -> void:
	var origem: Vector3 = painel["origem"]
	var eu: Vector3 = painel["u"]
	var ev: Vector3 = painel["v"]
	var n: Vector3 = painel["normal"]
	var p: Vector2 = g["p"]
	var massa: float = g["massa"]
	var raio := RAIO * sqrt(maxf(massa, 0.01))
	# Lagrima: a gota que anda se estica no sentido em que anda.
	var vel: Vector2 = g["vel"]
	var alonga := clampf(1.0 + vel.length() * 1.6, 1.0, 3.2)
	# Meio milimetro para DENTRO: o vidro desenha sem escrever profundidade, e
	# sem essa folga a gota briga com ele pelo mesmo pixel.
	var centro := origem + eu * p.x + ev * p.y - n * 0.001
	var base := Basis(eu * raio * 2.0, -ev * raio * 2.0 * alonga, -n)
	_mm.set_instance_transform(k, Transform3D(base, centro))
	_mm.set_instance_custom_data(k, Color(raio, alonga,
		clampf(vel.length() * 2.0, 0.0, 1.0), 1.0))


## O quadrinho da gota, de -0,5 a 0,5 nos dois eixos.
func _quadrinho() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cantos := [Vector3(-0.5, -0.5, 0.0), Vector3(0.5, -0.5, 0.0),
		Vector3(0.5, 0.5, 0.0), Vector3(-0.5, 0.5, 0.0)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.BACK)
		st.set_uv(uvs[i])
		st.add_vertex(cantos[i])
	return st.commit()


## Quantas gotas estao vivas. Para a bancada e para o orcamento.
func quantas() -> int:
	return _gotas.size()


## As gotas cruas, para a bancada offline medir fisica sem desenhar nada.
func estado() -> Array[Dictionary]:
	return _gotas


## Poe uma gota na mao, para a bancada.
func semear(painel: int, p: Vector2, massa: float) -> void:
	_gotas.append({"painel": painel, "p": p, "vel": Vector2.ZERO,
		"massa": massa, "ultimo": p})
	if painel < _por_vidro.size():
		_por_vidro[painel] += 1

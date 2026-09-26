## As corredoras: as gotas grandes que descem o vidro, simuladas na CPU — e a
## REACAO da agua do carro inteiro (pancada, balanco, borrifo e sangue).
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
## volta ate destravar; andando, perde massa no rastro ate travar de novo.
##
## As forcas, todas projetadas no plano do vidro:
##
##   peso     a gravidade no referencial do CARRO: com o carro torto (batido,
##            balancando) ela tomba junto
##   vento    o ar relativo ao carro, com v^2
##   inercia  a aceleracao do ponto do vidro: a do carro (freada, arrancada,
##            curva) mais a do GIRO da carroceria nas molas — o tranco de uma
##            pancada chega aqui como o solavanco que solta a gota parada
##
## A reacao (25/09/2026)
## ---------------------
## Este no entra no grupo `agua_no_vidro` (`CercoNoCarro.GRUPO_AGUA`): toda
## cabecada e toda mao espalmada chama `impacto(ponto, normal, forca)`. No ponto:
##
##   ONDA     um anel corre na pelicula (`psx_vidro_agua`, `onda_*`);
##   CAI      o mapa derruba a gota em volta e espalha a lamina (`AguaVidro.bater`);
##   SOLTA    as corredoras perto sao empurradas e ganham agua, e nascem outras
##            no anel da pancada, que descem deixando o rastro limpo;
##   BORRIFO  gotinhas saltam do vidro para fora, riscos acesos pelo fogo;
##   SANGUE   a marca de sangue perto da pancada (`SangueNoVidro`) mistura na
##            agua: o rosa desce em filetes, e a corredora que passa por ela
##            leva o fio rosa junto.
##
## E o balanco: cada vidro tem uma mola (`sacode`) que a aceleracao transitoria
## do ponto do vidro excita. A gota parada TREME com o carro, e acima de
## `SOLTA_SACUDIDA` ela se solta e corre.
##
## Nada disso cria recurso no quadro da pancada: o borrifo sao instancias da
## mesma MultiMesh das corredoras, criada no `montar`.
class_name AguaCorredoras
extends Node3D

const SHADER := "res://shaders/psx_gota_corredora.gdshader"
const SHADER_ANTIGO := "res://shaders/psx_gota_corredora_antiga.gdshader"
## O grupo das pancadas no vidro. O mesmo nome de `CercoNoCarro.GRUPO_AGUA`.
const GRUPO := &"agua_no_vidro"

## Teto de gotas: por vidro e no total. O total tem de caber no vetor de
## trilhas de `psx_agua_mapa.gdshader` (48 no antigo).
const POR_VIDRO := 24
const TOTAL := 64
const TOTAL_ANTIGO := 48
## Gotas de borrifo no ar ao mesmo tempo.
const BORRIFO := 96

const G := 9.81
## Amortecimento da velocidade, por segundo. Ver a bancada
## (`tests/bancada_agua_vidro.gd`): com 14 a gota grande do para-brisa fica em
## 0,34 m/s.
const ARRASTO := 14.0
## Forca de adesao a massa 1, em m/s^2. Dividida pela massa.
const ADESAO := 2.8
const VENTO := 0.035
const ESPALHA := 0.40

const MASSA_NOVA := Vector2(0.30, 0.85)
const MASSA_MIN := 0.22
const MASSA_MAX := 2.60
const CRESCE := 0.85
const PERDE := 1.30
const ENGOLE := 2.40

## Raio desenhado, em metros, para massa 1. A fisica (junta, rastro) usa este.
const RAIO := 0.0055
## O raio que o MODERNO desenha. Os 5,5 mm eram o tamanho estilizado que le a
## 480x270; em 4K a corredora de 1,5 cm de largura lia como conta de colar.
const RAIO_DESENHO := 0.0036

const NASCEM := 2.2

const RASTRO := 0.006

## --- A pancada ---
## Raio (m) em que a gota parada cai, na forca 1.
const RAIO_PANCADA := 0.12
## Ate onde a pancada empurra as corredoras (m).
const ALCANCE_PANCADA := 0.26
## Corredoras que a pancada solta e gotas de borrifo, na forca 1.
const SOLTA_PANCADA := 13
const BORRIFO_PANCADA := 44
## Quantas ondas vivem ao mesmo tempo (o vetor do shader).
const MAX_ONDAS := 4

## --- O balanco ---
## A mola da agua parada: frequencia (Hz), amortecimento, ganho (m por m/s^2 de
## solavanco, ja dividido por w0^2 na conta) e o maximo (m).
const BALANCO_HZ := 7.5
const BALANCO_AMORTECE := 0.22
const BALANCO_MAX := 0.0028
## Solavanco (m/s^2, a parte transitoria da aceleracao no plano) acima do qual a
## gota parada se solta.
const SOLTA_SACUDIDA := 2.5

var _mmi: MultiMeshInstance3D
var _mm: MultiMesh
var _paineis: Array = []
var _rects: Array[Rect2] = []
## Cada gota: painel, p (m), vel (m/s), massa, ultimo (m), rosa (0 a 1).
var _gotas: Array[Dictionary] = []
var _trincas: Array[Dictionary] = []
const TRINCA_PEGA := 0.009
const TRINCA_PUXA := 180.0
const JUNTA := 0.8
var _por_vidro: PackedInt32Array = PackedInt32Array()
var _rng := RandomNumberGenerator.new()

var _antiga := false
var _teto := TOTAL
## O vidro e o mapa, irmaos na cabine (achados no `montar`).
var _vidro_mat: ShaderMaterial
var _mapa: AguaVidro
## O relogio da agua: o mesmo das ondas no shader.
var _agora := 0.0
var _ondas_a := PackedVector4Array()
var _ondas_b := PackedVector4Array()
var _onda_i := 0
## Por vidro: o balanco (x, v), a forca lenta (para tirar o que e constante) e
## o tremor.
var _bal_x := PackedVector2Array()
var _bal_v := PackedVector2Array()
var _f_lenta := PackedVector2Array()
var _tremor := PackedFloat32Array()
var _sacode := PackedVector4Array()
## O giro da carroceria, medido da propria transformada.
var _base_antes := Basis()
var _giro_ok := false
var _w := Vector3.ZERO
var _alfa := Vector3.ZERO
var _g_local := Vector3(0.0, -G, 0.0)
var _pivo := Vector3.ZERO
## O borrifo: p e v no espaco da cabine, raio, vida, idade.
var _borrifo: Array[Dictionary] = []
## As marcas de sangue nos vidros: painel, m, raio, base, extra.
var _fontes: Array[Dictionary] = []
var _ler_marcas_t := 0.0
## A ultima pancada: marcas que aparecem logo depois perto dela ja nascem
## misturadas (o golpe no sangue vem no mesmo instante que o da agua).
var _ultima := {}
## `--agua-log`: cada pancada no log, com o vidro que ela achou.
var _log: bool = OS.get_cmdline_user_args().has("--agua-log")


func montar(paineis: Array, rects: Array[Rect2], semente: int = 20260916) -> void:
	_paineis = paineis
	_rects = rects
	_rng.seed = semente
	_antiga = AguaVidro.antiga()
	_teto = TOTAL_ANTIGO if _antiga else TOTAL
	_por_vidro.resize(paineis.size())
	_por_vidro.fill(0)
	var caminho := SHADER_ANTIGO if _antiga else SHADER
	if not ResourceLoader.exists(caminho):
		push_error("AguaCorredoras: shader ausente em %s" % caminho)
		return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	# A optica de cada gota — raio, alongamento e brilho — viaja no custom.
	_mm.use_custom_data = true
	_mm.mesh = _quadrinho()
	_mm.instance_count = _teto if _antiga else _teto + BORRIFO + 1
	_mm.visible_instance_count = 0

	var mat := ShaderMaterial.new()
	mat.shader = load(caminho) as Shader
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Corredoras"
	_mmi.multimesh = _mm
	if not _antiga:
		# Depois do vidro (0) e do sangue de fora (1): a corredora que desce pela
		# marca tem de aparecer por cima dela, com o rosa que levou.
		mat.render_priority = 2
	_mmi.material_override = mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)
	if _antiga:
		return

	var n := paineis.size()
	_bal_x.resize(n)
	_bal_v.resize(n)
	_f_lenta.resize(n)
	_tremor.resize(n)
	_sacode.resize(n)
	_bal_x.fill(Vector2.ZERO)
	_bal_v.fill(Vector2.ZERO)
	_f_lenta.fill(Vector2.ZERO)
	_tremor.fill(0.0)
	_sacode.fill(Vector4.ZERO)
	_ondas_a.resize(MAX_ONDAS)
	_ondas_b.resize(MAX_ONDAS)
	_ondas_a.fill(Vector4(0.0, 0.0, -100.0, 0.0))
	_ondas_b.fill(Vector4(-1.0, 0.0, 0.0, 0.0))
	add_to_group(GRUPO)
	_achar_irmaos()


## O vidro e o mapa desta cabine. A cabine monta os dois ANTES das corredoras
## (`CarroCabine._montar_agua`), entao aqui eles ja existem.
func _achar_irmaos() -> void:
	var pai := get_parent()
	if pai == null:
		return
	for no: Node in pai.get_children():
		if no is AguaVidro and _mapa == null:
			_mapa = no as AguaVidro
		elif no is MeshInstance3D and _vidro_mat == null:
			var mat := (no as MeshInstance3D).material_override as ShaderMaterial
			if mat != null and mat.shader != null \
					and mat.shader.resource_path == VidroCabine.SHADER:
				_vidro_mat = mat
	if _vidro_mat == null:
		return
	var rects := PackedVector4Array()
	for r: Rect2 in _rects:
		rects.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	_vidro_mat.set_shader_parameter(&"n_paineis", rects.size())
	if not rects.is_empty():
		_vidro_mat.set_shader_parameter(&"painel_rect", rects)
	var rosa := _mapa.textura_rosa() if _mapa != null else null
	_vidro_mat.set_shader_parameter(&"usa_rosa", rosa != null)
	if rosa != null:
		_vidro_mat.set_shader_parameter(&"mapa_rosa", rosa)
	_enviar_vidro()


## O material das gotas, para quem precisa apontar o mapa de agua nele.
func material() -> ShaderMaterial:
	return _mmi.material_override as ShaderMaterial if _mmi != null else null


## Um passo. Devolve os segmentos de rastro deste quadro, em UV do mapa.
##
## `vel_local` e `acel_local` sao a velocidade e a aceleracao do carro NO
## ESPACO DO CARRO. O giro da carroceria (o balanco nas molas) nao vem nelas: e
## medido aqui, da transformada.
func passo(chuva: float, cobertura: PackedFloat32Array, vel_local: Vector3,
		acel_local: Vector3, setor: Dictionary, delta: float) -> PackedVector4Array:
	var trilhas := PackedVector4Array()
	if _mm == null or _paineis.is_empty():
		return trilhas
	if not _antiga:
		_agora += delta
		_medir_giro(delta)
		_sacudir(acel_local, cobertura, delta)
		_ler_marcas(delta)
	_nascer(chuva, cobertura, delta)

	var rosa_trilhas := PackedFloat32Array()
	var vivas: Array[Dictionary] = []
	var k := 0
	for g: Dictionary in _gotas:
		var i: int = g["painel"]
		var painel: Dictionary = _paineis[i]
		var tam: Vector2 = painel["tam"]
		var cob: float = cobertura[i] if i < cobertura.size() else 0.0
		g["ultimo"] = g["p"]

		var f := _forcas_antigas(painel, g["p"], vel_local, acel_local) if _antiga \
			else _forcas(painel, g["p"], vel_local, acel_local)
		if not _trincas.is_empty():
			f = _pelas_trincas(i, g["p"], f)
		var vel: Vector2 = g["vel"]
		var massa: float = g["massa"]
		var limite := ADESAO / maxf(massa, 0.05)
		var andando := vel.length() > 0.004 or f.length() > limite
		if andando:
			# A adesao nao some quando a gota anda: ela vira atrito, contra o
			# movimento. Sem isso a gota destravada nunca mais para.
			var freio := vel.normalized() * limite if vel.length() > 1e-4 \
				else f.normalized() * limite
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
			massa += (ENGOLE * cob - PERDE) * andou
		else:
			massa += CRESCE * cob * delta
		g["massa"] = clampf(massa, 0.0, MASSA_MAX)
		if not _antiga:
			_pegar_sangue(g, i, andou)

		if _levada_pela_palheta(g, setor, i):
			continue
		if massa < MASSA_MIN or p.y > tam.y or p.y < -0.03 \
				or p.x < -0.05 or p.x > tam.x + 0.05:
			continue
		vivas.append(g)
		if andou > 1e-4 and trilhas.size() < _teto:
			trilhas.append(_segmento(i, antes, p))
			rosa_trilhas.append(float(g.get("rosa", 0.0)))
		if k < _teto:
			_desenhar(k, painel, g)
			k += 1
	_juntar(vivas)
	_gotas = vivas
	_por_vidro.fill(0)
	for g: Dictionary in _gotas:
		_por_vidro[int(g["painel"])] += 1
	if not _antiga:
		k = _mover_borrifo(delta, k)
		k = _sentinela(k)
		_enviar_vidro()
		if _mapa != null:
			_mapa.rosa_das_trilhas(rosa_trilhas)
			_mapa.fontes_de_sangue(_fontes_do_quadro(delta))
	_mm.visible_instance_count = k
	return trilhas


## Duas gotas que se encostam viram uma: a de baixo engole a de cima.
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
			fica["rosa"] = maxf(float(fica.get("rosa", 0.0)), float(some.get("rosa", 0.0)))
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
			return f * 0.25
		for r: Vector3 in t["radiais"]:
			var dir := Vector2(r.x, r.y)
			var ao_longo := d.dot(dir)
			if ao_longo < 0.0 or ao_longo > r.z:
				continue
			var fora := d - dir * ao_longo
			if fora.length() > TRINCA_PEGA:
				continue
			var desce := dir if dir.y >= 0.0 else -dir
			var ao := maxf(f.dot(desce), f.length() * 0.35)
			return desce * ao - fora * TRINCA_PUXA
	return f


## Peso, vento e inercia, projetados no plano do vidro. Em m/s^2.
##
## O peso e a gravidade vista do carro (tomba com ele), e a inercia e a do
## PONTO do vidro: a do carro mais o giro da carroceria em volta do pivo.
func _forcas(painel: Dictionary, p: Vector2, vel_local: Vector3,
		acel_local: Vector3) -> Vector2:
	var n: Vector3 = painel["normal"]
	var eu: Vector3 = painel["u"]
	var ev: Vector3 = painel["v"]
	var tam: Vector2 = painel["tam"]
	var ponto: Vector3 = (painel["origem"] as Vector3) + eu * p.x + ev * p.y
	var pseudo := _g_local - _acel_do_ponto(ponto, acel_local)
	var f := Vector2(pseudo.dot(eu), pseudo.dot(ev))
	f += _vento(n, eu, ev, tam, p, vel_local)
	return f


## A aceleracao de um ponto da cabine: a do carro, mais a do giro.
func _acel_do_ponto(ponto: Vector3, acel_local: Vector3) -> Vector3:
	var r := ponto - _pivo
	return acel_local + _alfa.cross(r) + _w.cross(_w.cross(r))


func _vento(n: Vector3, eu: Vector3, ev: Vector3, tam: Vector2, p: Vector2,
		vel_local: Vector3) -> Vector2:
	var f := Vector2.ZERO
	var ar := -vel_local
	var v2 := ar.length_squared()
	if v2 > 0.01:
		var no_plano := ar - n * ar.dot(n)
		var dir := Vector2(no_plano.dot(eu), no_plano.dot(ev))
		if dir.length_squared() > 1e-8:
			f += dir.normalized() * (VENTO * v2)
		if absf(n.x) < 0.5:
			var meio := tam.x * 0.5
			var lado := signf(p.x - meio)
			f.x += lado * ESPALHA * VENTO * v2 * minf(1.0,
				absf(p.x - meio) / maxf(meio, 0.01))
	return f


## As forcas de antes da reacao (`--agua-antiga`), identicas.
func _forcas_antigas(painel: Dictionary, p: Vector2, vel_local: Vector3,
		acel_local: Vector3) -> Vector2:
	var n: Vector3 = painel["normal"]
	var eu: Vector3 = painel["u"]
	var ev: Vector3 = painel["v"]
	var tam: Vector2 = painel["tam"]
	var f := Vector2(0.0, G * sqrt(maxf(0.0, 1.0 - n.y * n.y)))
	f += _vento(n, eu, ev, tam, p, vel_local)
	var pseudo := -acel_local
	var pp := pseudo - n * pseudo.dot(n)
	f += Vector2(pp.dot(eu), pp.dot(ev))
	return f


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
	if chuva <= 0.01 or _gotas.size() >= _teto:
		return
	for i in _paineis.size():
		if _por_vidro[i] >= POR_VIDRO or _gotas.size() >= _teto:
			continue
		var painel: Dictionary = _paineis[i]
		var tam: Vector2 = painel["tam"]
		var cob: float = cobertura[i] if i < cobertura.size() else 0.0
		var exposicao: float = painel.get("exposicao", 1.0)
		var taxa := NASCEM * chuva * exposicao * tam.x * tam.y * cob * delta
		if _rng.randf() >= taxa:
			continue
		var p := Vector2(_rng.randf_range(0.04, maxf(0.05, tam.x - 0.04)),
			_rng.randf_range(0.0, tam.y * 0.35))
		_gotas.append({"painel": i, "p": p, "vel": Vector2.ZERO,
			"massa": _rng.randf_range(MASSA_NOVA.x, MASSA_NOVA.y), "ultimo": p,
			"rosa": 0.0})
		_por_vidro[i] += 1


func _segmento(i: int, de: Vector2, ate: Vector2) -> Vector4:
	var a := _uv(i, de)
	var b := _uv(i, ate)
	return Vector4(a.x, a.y, b.x, b.y)


## Um ponto do vidro `i` (m) em UV do mapa.
func _uv(i: int, m: Vector2) -> Vector2:
	var tam: Vector2 = _paineis[i]["tam"]
	var r: Rect2 = _rects[i] if i < _rects.size() else Rect2(0, 0, 1, 1)
	return r.position + Vector2(m.x / maxf(tam.x, 1e-4), m.y / maxf(tam.y, 1e-4)) * r.size


func _desenhar(k: int, painel: Dictionary, g: Dictionary) -> void:
	var origem: Vector3 = painel["origem"]
	var eu: Vector3 = painel["u"]
	var ev: Vector3 = painel["v"]
	var n: Vector3 = painel["normal"]
	var p: Vector2 = g["p"]
	var massa: float = g["massa"]
	var raio := (RAIO if _antiga else RAIO_DESENHO) * sqrt(maxf(massa, 0.01))
	var vel: Vector2 = g["vel"]
	var alonga := clampf(1.0 + vel.length() * 1.6, 1.0, 3.2)
	var centro := origem + eu * p.x + ev * p.y - n * 0.001
	var base := Basis(eu * raio * 2.0, -ev * raio * 2.0 * alonga, -n)
	_mm.set_instance_transform(k, Transform3D(base, centro))
	var a := 1.0 if _antiga else 1.0 + clampf(float(g.get("rosa", 0.0)), 0.0, 0.999)
	_mm.set_instance_custom_data(k, Color(raio, alonga,
		clampf(vel.length() * 2.0, 0.0, 1.0), a))


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
	st.generate_tangents()
	return st.commit()


func quantas() -> int:
	return _gotas.size()


func estado() -> Array[Dictionary]:
	return _gotas


func semear(painel: int, p: Vector2, massa: float) -> void:
	_gotas.append({"painel": painel, "p": p, "vel": Vector2.ZERO,
		"massa": massa, "ultimo": p, "rosa": 0.0})
	if painel < _por_vidro.size():
		_por_vidro[painel] += 1


# --- a reacao ---------------------------------------------------------------

## Uma pancada no vidro (cabecada, mao espalmada). `ponto_mundo` e onde bateu,
## `normal_mundo` a normal do vidro (so para escolher o vidro certo quando dois
## estao perto), `forca` de 0 a 1. Chamada pelo grupo `agua_no_vidro`.
##
## Nao cria nada: escreve em vetores que ja existem.
func impacto(ponto_mundo: Vector3, normal_mundo: Vector3, forca: float) -> void:
	if _antiga or _paineis.is_empty() or not is_inside_tree():
		return
	forca = clampf(forca, 0.0, 1.0)
	if forca <= 0.001:
		return
	var p := to_local(ponto_mundo)
	var n_local := Vector3.ZERO
	if normal_mundo.length_squared() > 0.25:
		n_local = (global_basis.inverse() * normal_mundo).normalized()
	var qual := -1
	var m := Vector2.ZERO
	var melhor := 0.16
	for i in _paineis.size():
		var pn: Dictionary = _paineis[i]
		var nn: Vector3 = pn["normal"]
		if n_local != Vector3.ZERO and absf(n_local.dot(nn)) < 0.5:
			continue
		var d: Vector3 = p - (pn["origem"] as Vector3)
		var dist := absf(d.dot(nn))
		var mm := Vector2(d.dot(pn["u"]), d.dot(pn["v"]))
		var tam: Vector2 = pn["tam"]
		if mm.x < -0.08 or mm.y < -0.08 or mm.x > tam.x + 0.08 or mm.y > tam.y + 0.08:
			continue
		if dist < melhor:
			melhor = dist
			qual = i
			m = mm.clamp(Vector2.ZERO, tam)
	if qual < 0:
		return
	# A onda na pelicula.
	_ondas_a[_onda_i] = Vector4(m.x, m.y, _agora, forca)
	_ondas_b[_onda_i] = Vector4(float(qual), 0.0, 0.0, 0.0)
	_onda_i = (_onda_i + 1) % MAX_ONDAS
	# O mapa: a gota cai em volta e vira lamina.
	if _mapa != null:
		_mapa.bater(_uv(qual, m), RAIO_PANCADA * (0.40 + 0.75 * forca), forca)
	# O vidro inteiro treme.
	_tremor[qual] = maxf(_tremor[qual], forca)
	_empurrar(qual, m, forca)
	_soltar(qual, m, forca)
	_borrifar(qual, m, forca)
	# O sangue que ja esta perto mistura; o que chegar agora tambem.
	for f: Dictionary in _fontes:
		if int(f["painel"]) == qual and (f["m"] as Vector2).distance_to(m) < 0.32:
			f["extra"] = maxf(float(f["extra"]), forca)
	_ultima = {"painel": qual, "m": m, "forca": forca, "t": _agora}
	_ler_marcas_t = 0.0
	if _log:
		print("[agua] pancada %.2f no vidro %d (%s) em (%.2f, %.2f) m, a %.3f m do plano; %d corredoras, %d borrifo" % [
			forca, qual, str(_paineis[qual]["tipo"]), m.x, m.y, melhor, _gotas.size(), _borrifo.size()])


## As corredoras perto da pancada saltam para fora do ponto e ganham a agua
## que caiu: vao descer.
func _empurrar(qual: int, m: Vector2, forca: float) -> void:
	for g: Dictionary in _gotas:
		if int(g["painel"]) != qual:
			continue
		var d: Vector2 = (g["p"] as Vector2) - m
		var r := d.length()
		if r > ALCANCE_PANCADA:
			continue
		var perto := 1.0 - r / ALCANCE_PANCADA
		var dir := d / r if r > 1e-4 else Vector2(0.0, 1.0)
		g["vel"] = (g["vel"] as Vector2) + (dir * 0.55 + Vector2(0.0, 0.2)) * forca * perto
		g["massa"] = minf(float(g["massa"]) + 0.6 * forca * perto, MASSA_MAX)


## A pancada solta a agua parada em volta: nascem corredoras no anel dela,
## mais embaixo do que em cima (o peso), ja correndo para fora.
func _soltar(qual: int, m: Vector2, forca: float) -> void:
	var tam: Vector2 = _paineis[qual]["tam"]
	var quantas_ := int(round(float(SOLTA_PANCADA) * forca * _rng.randf_range(0.65, 1.0)))
	for _k in quantas_:
		if _gotas.size() >= _teto:
			# Cheio: sai a corredora mais leve, e nao a da pancada.
			_gotas.remove_at(_mais_leve())
		var ang := _rng.randf_range(-PI, PI)
		# Metade de baixo pesa mais: sin > 0 e para baixo (+v).
		if _rng.randf() < 0.45:
			ang = absf(ang)
		var raio := RAIO_PANCADA * forca * _rng.randf_range(0.55, 1.35)
		var dir := Vector2(cos(ang), sin(ang))
		var p := (m + dir * raio).clamp(Vector2(0.01, 0.0), tam - Vector2(0.01, 0.01))
		_gotas.append({"painel": qual, "p": p,
			"vel": dir * _rng.randf_range(0.10, 0.35) * forca + Vector2(0.0, 0.08),
			"massa": _rng.randf_range(0.9, 1.9), "ultimo": p, "rosa": 0.0})
		_por_vidro[qual] += 1


func _mais_leve() -> int:
	var qual := 0
	var menor := INF
	for i in _gotas.size():
		var mm := float(_gotas[i]["massa"])
		if mm < menor:
			menor = mm
			qual = i
	return qual


## Gotinhas que saltam do vidro para FORA com a pancada. Voam, caem e somem
## em meio segundo; de dentro elas so aparecem onde pegam luz.
func _borrifar(qual: int, m: Vector2, forca: float) -> void:
	var pn: Dictionary = _paineis[qual]
	var o: Vector3 = pn["origem"]
	var eu: Vector3 = pn["u"]
	var ev: Vector3 = pn["v"]
	var n: Vector3 = pn["normal"]
	var quantas_ := int(round(float(BORRIFO_PANCADA) * forca * _rng.randf_range(0.7, 1.0)))
	for _k in quantas_:
		if _borrifo.size() >= BORRIFO:
			_borrifo.pop_front()
		var ang := _rng.randf_range(-PI, PI)
		var dir2 := Vector2(cos(ang), sin(ang))
		var raio_saida := _rng.randf_range(0.015, 0.11) * (0.5 + 0.5 * forca)
		var q := m + dir2 * raio_saida
		var ponto := o + eu * q.x + ev * q.y + n * 0.004
		var lado := (eu * dir2.x + ev * dir2.y).normalized()
		var v := n * _rng.randf_range(0.5, 2.6) * forca \
			+ lado * _rng.randf_range(0.3, 1.9) * forca \
			+ Vector3.UP * _rng.randf_range(0.0, 0.7) * forca
		_borrifo.append({"p": ponto, "v": v,
			"raio": _rng.randf_range(0.0007, 0.0024),
			"vida": _rng.randf_range(0.18, 0.55), "idade": 0.0})


## Move o borrifo e desenha a partir da instancia `k`. Devolve o proximo `k`.
func _mover_borrifo(delta: float, k: int) -> int:
	if _borrifo.is_empty():
		return k
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var olho := to_local(cam.global_position) if cam != null else Vector3(0.0, 1.2, 0.0)
	var vivos: Array[Dictionary] = []
	for b: Dictionary in _borrifo:
		b["idade"] = float(b["idade"]) + delta
		if float(b["idade"]) >= float(b["vida"]):
			continue
		var v: Vector3 = b["v"]
		v += _g_local * delta
		v *= exp(-1.4 * delta)
		b["v"] = v
		b["p"] = (b["p"] as Vector3) + v * delta
		vivos.append(b)
		if k >= _mm.instance_count - 1:
			continue
		var p: Vector3 = b["p"]
		var para_olho := olho - p
		if para_olho.length_squared() < 1e-6:
			continue
		para_olho = para_olho.normalized()
		var v_tela := v - para_olho * v.dot(para_olho)
		var raio: float = b["raio"]
		# O risco: quanto a gota anda em 1/60 s, visto da lente.
		var comp := maxf(raio * 2.0, v_tela.length() / 60.0)
		var eixo_y := v_tela.normalized() if v_tela.length() > 1e-4 \
			else para_olho.cross(Vector3.RIGHT).normalized()
		var eixo_x := eixo_y.cross(para_olho).normalized()
		var vida := float(b["idade"]) / float(b["vida"])
		var some := clampf((1.0 - vida) * 1.6, 0.0, 0.998)
		_mm.set_instance_transform(k, Transform3D(
			Basis(eixo_x * raio * 2.0, eixo_y * comp, para_olho), p))
		_mm.set_instance_custom_data(k, Color(raio, comp / (raio * 2.0), 0.0, some))
		k += 1
	_borrifo = vivos
	return k


## Uma instancia sempre desenhada e sempre descartada no fragmento: o material
## das gotas compila no primeiro quadro em que a cabine aparece (debaixo do
## preto do aquecimento), e nao na primeira pancada.
func _sentinela(k: int) -> int:
	if k >= _mm.instance_count or _paineis.is_empty():
		return k
	var pn: Dictionary = _paineis[0]
	var c: Vector3 = (pn["origem"] as Vector3) + (pn["u"] as Vector3) * (pn["tam"] as Vector2).x * 0.5 \
		+ (pn["v"] as Vector3) * (pn["tam"] as Vector2).y * 0.5 - (pn["normal"] as Vector3) * 0.001
	var n: Vector3 = pn["normal"]
	var eu: Vector3 = pn["u"]
	var ev: Vector3 = pn["v"]
	_mm.set_instance_transform(k, Transform3D(Basis(eu * 0.01, -ev * 0.01, -n), c))
	_mm.set_instance_custom_data(k, Color(0.005, 1.0, 0.0, 0.0))
	return k + 1


## O giro da carroceria: velocidade e aceleracao angular, medidas da basis de
## um quadro para o outro. So a ROTACAO: a posicao do carro esta a quatro mil
## metros do zero, e a segunda derivada dela em float erra metros por segundo
## ao quadrado.
func _medir_giro(delta: float) -> void:
	var b := global_basis.orthonormalized()
	_g_local = b.inverse() * Vector3(0.0, -G, 0.0)
	var carro := get_parent().get_parent() as Node3D if get_parent() != null else null
	_pivo = to_local(carro.global_position) if carro != null else Vector3.ZERO
	if not _giro_ok or delta <= 0.0:
		_base_antes = b
		_giro_ok = true
		return
	var q := (_base_antes.inverse() * b).get_rotation_quaternion()
	var ang := q.get_angle()
	var eixo := q.get_axis() if ang > 1e-7 else Vector3.ZERO
	if ang > PI:
		ang = TAU - ang
		eixo = -eixo
	var w := Vector3.ZERO
	if ang < 0.5:
		w = eixo * (ang / delta)
	_alfa = ((w - _w) / delta).limit_length(80.0)
	_w = w.limit_length(6.0)
	_base_antes = b


## O balanco da agua parada, uma mola por vidro, e a gota que o solavanco solta.
func _sacudir(acel_local: Vector3, cobertura: PackedFloat32Array, delta: float) -> void:
	if delta <= 0.0:
		return
	var w0 := TAU * BALANCO_HZ
	var passos := maxi(1, ceili(delta * w0 / 0.35))
	var h := delta / float(passos)
	for i in _paineis.size():
		var pn: Dictionary = _paineis[i]
		var eu: Vector3 = pn["u"]
		var ev: Vector3 = pn["v"]
		var tam: Vector2 = pn["tam"]
		var centro: Vector3 = (pn["origem"] as Vector3) + eu * tam.x * 0.5 + ev * tam.y * 0.5
		var pseudo := _g_local - _acel_do_ponto(centro, acel_local)
		var f2 := Vector2(pseudo.dot(eu), pseudo.dot(ev))
		var lenta := _f_lenta[i]
		lenta = lenta.lerp(f2, 1.0 - exp(-delta / 0.35))
		_f_lenta[i] = lenta
		var solavanco := f2 - lenta
		var x := _bal_x[i]
		var v := _bal_v[i]
		for _s in passos:
			var a := solavanco - x * w0 * w0 - v * 2.0 * BALANCO_AMORTECE * w0
			v += a * h
			x += v * h
		x = x.limit_length(BALANCO_MAX)
		_bal_x[i] = x
		_bal_v[i] = v
		var forte := solavanco.length()
		_tremor[i] = maxf(_tremor[i] * exp(-delta * 4.5),
			clampf((forte - 0.8) / 9.0, 0.0, 1.0))
		_sacode[i] = Vector4(x.x, x.y, _tremor[i], 0.0)
		# O solavanco forte solta a gota parada: ela corre para onde ele empurra.
		if forte > SOLTA_SACUDIDA:
			var cob: float = cobertura[i] if i < cobertura.size() else 0.0
			var taxa := (forte - SOLTA_SACUDIDA) * 1.2 * cob * tam.x * tam.y * delta * 30.0
			var soltas := int(taxa) + (1 if _rng.randf() < fmod(taxa, 1.0) else 0)
			for _k in mini(soltas, 3):
				if _gotas.size() >= _teto or _por_vidro[i] >= POR_VIDRO + 6:
					break
				var p := Vector2(_rng.randf_range(0.03, tam.x - 0.03),
					_rng.randf_range(0.02, tam.y * 0.8))
				_gotas.append({"painel": i, "p": p,
					"vel": solavanco.normalized() * 0.12, "massa": _rng.randf_range(0.8, 1.6),
					"ultimo": p, "rosa": 0.0})
				_por_vidro[i] += 1


## As marcas de sangue dos vidros desta cabine (`SangueNoVidro`, filhas dela),
## lidas a cada 0,2 s: e delas que o rosa nasce.
func _ler_marcas(delta: float) -> void:
	_ler_marcas_t -= delta
	if _ler_marcas_t > 0.0:
		return
	_ler_marcas_t = 0.2
	var pai := get_parent()
	if pai == null:
		return
	var novas: Array[Dictionary] = []
	for no: Node in pai.get_children():
		var s := no as SangueNoVidro
		if s == null or not s.visible:
			continue
		for mk: Vector4 in s.marcas_no_carro():
			var pt := Vector3(mk.x, mk.y, mk.z)
			for i in _paineis.size():
				var pn: Dictionary = _paineis[i]
				var d: Vector3 = pt - (pn["origem"] as Vector3)
				if absf(d.dot(pn["normal"])) > 0.06:
					continue
				var mm := Vector2(d.dot(pn["u"]), d.dot(pn["v"]))
				var tam: Vector2 = pn["tam"]
				if mm.x < -0.05 or mm.y < -0.05 or mm.x > tam.x + 0.05 or mm.y > tam.y + 0.05:
					continue
				var extra := 0.0
				for velha: Dictionary in _fontes:
					if int(velha["painel"]) == i and (velha["m"] as Vector2).distance_to(mm) < 0.03:
						extra = float(velha["extra"])
						break
				if not _ultima.is_empty() and int(_ultima["painel"]) == i \
						and _agora - float(_ultima["t"]) < 0.6 \
						and (_ultima["m"] as Vector2).distance_to(mm) < 0.32:
					extra = maxf(extra, float(_ultima["forca"]))
				novas.append({"painel": i, "m": mm,
					"raio": clampf(mk.w * 0.75, 0.025, 0.12), "extra": extra})
				break
	_fontes = novas


## As fontes deste quadro, para o mapa: o sangue que a chuva lava sempre um
## pouco, mais o que a pancada acabou de misturar.
func _fontes_do_quadro(delta: float) -> PackedVector4Array:
	var out := PackedVector4Array()
	for f: Dictionary in _fontes:
		f["extra"] = float(f["extra"]) * exp(-delta / 2.2)
		var uv := _uv(int(f["painel"]), f["m"])
		out.append(Vector4(uv.x, uv.y, float(f["raio"]),
			clampf(0.22 + 0.78 * float(f["extra"]), 0.0, 1.0)))
		if out.size() >= AguaVidro.MAX_SANGUE:
			break
	return out


## A corredora que passa por uma marca leva o sangue; andando, ele se dilui.
func _pegar_sangue(g: Dictionary, painel: int, andou: float) -> void:
	var rosa := float(g.get("rosa", 0.0)) * exp(-andou / 0.45)
	var p: Vector2 = g["p"]
	for f: Dictionary in _fontes:
		if int(f["painel"]) != painel:
			continue
		if (f["m"] as Vector2).distance_to(p) < float(f["raio"]) * 1.3:
			rosa = maxf(rosa, 0.45 + 0.5 * float(f["extra"]))
	g["rosa"] = rosa


## O que o shader do vidro precisa saber deste quadro.
func _enviar_vidro() -> void:
	if _vidro_mat == null:
		return
	_vidro_mat.set_shader_parameter(&"agora", _agora)
	_vidro_mat.set_shader_parameter(&"onda_a", _ondas_a)
	_vidro_mat.set_shader_parameter(&"onda_b", _ondas_b)
	if not _sacode.is_empty():
		_vidro_mat.set_shader_parameter(&"sacode", _sacode)

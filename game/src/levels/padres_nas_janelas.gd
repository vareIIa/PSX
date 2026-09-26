## Os outros padres da cena da janela: a cabeca de criatura nos romeiros que a
## lente ve atras do principal, e um deles na janela do passageiro batendo a
## testa no vidro enquanto o principal bate na do motorista.
##
## Por que existe
## --------------
## Com o principal sozinho destruindo a cara no vidro, os outros eram figurantes
## de faixa parados na mata: a cena era um homem so. Quando a lente escapa para
## o lado no meio das cabecadas, tem de haver outro fazendo o mesmo — outro
## ritmo, outra pose, o vidro dele trincando e sujando de sangue. Mas so o
## vidro do principal estoura: o do passageiro fica, rachado.
##
## Como funciona
## -------------
## `montar` troca o rosto de faixa dos romeiros da meia-lua pela
## `CabecaDoPadre` (o mesmo rosto do principal; so este arquivo veste, a
## `MonstroDaEstrada` continua como era) e leva um deles para fora da porta do
## passageiro, curvado como o principal. A pose de cabecada e a mesma
## `CabecadaDoPadre`; quem pede cada golpe e a cena (`golpe`), com antecipacao,
## bote e forca proprios. No contato: sangue e trinca no vidro dele, o dano da
## cara subindo de 1 a 2, um baque abafado. O olho dele nao sai.
class_name PadresNasJanelas
extends Node

## Qual romeiro vai para a janela do passageiro: o 3 esta longe, atras, e nao
## e dos que piscam (a cena esconde um em cada tres por uns quadros).
const QUAL := 3
## A testa encostada e a testa descansando longe do vidro (m).
const PERTO := 0.08
const AMASSA := 0.012
## A testa de repouso acima do meio do vidro (m).
const SOBRE_O_MEIO := 0.12
## O dano da cara dele a cada golpe (do primeiro ao quarto em diante).
const DANO := [1.0, 1.35, 1.7, 2.0]
## As maos espalmadas no vidro, dos dois lados da cara: (para a frente do
## carro, acima do ponto da testa) em m, no plano da janela. Na altura da
## bochecha, uma mais alta que a outra: acima da cabeca elas liam como quem se
## rende.
const MAOS := [Vector2(0.27, -0.07), Vector2(-0.25, -0.02)]
## O fogo do capo batendo na cara dele pela frente do carro: a luz (quente,
## fraca, curta) e o quanto ela treme.
const LUZ_FOGO := Color(1.0, 0.55, 0.28)
const LUZ_ENERGIA := 0.9
const LUZ_ALCANCE := 1.1
const LUZ_TREME := 0.35
## O quanto os dedos abrem para fora do eixo, e o tempo da subida.
const MAO_ABRE := 0.28
const MAO_SOBE := 0.55

var _cena: Node
var _carro: Node3D
var _cabine: Node3D
var _a: Dictionary
var _corpo: Corpo
var _cab: CabecaDoPadre
var _pose: CabecadaDoPadre
var _sangue: SangueNoVidro
var _trinca: TrincaDeVidro
var _golpes := 0
var _meio_y := 0.0
var _tw: Tween
## As duas maos no vidro (`BracoVivo`, espaco da cabine), e onde cada uma
## espalma.
var _maos: Array[BracoVivo] = []
var _no_vidro: Array[Dictionary] = []
var _luz: OmniLight3D
var _t := 0.0


## Veste a `CabecaDoPadre` em `c` no lugar do rosto que ele tinha (a faixa).
## Devolve a cabeca, ou null se nao deu (e o rosto velho continua).
static func vestir_cabeca(c: Corpo) -> CabecaDoPadre:
	if c == null or c.get_meta(&"rosto", null) is CabecaDoPadre:
		return c.get_meta(&"rosto", null) as CabecaDoPadre if c != null else null
	var capuz := c.get_meta(&"capuz", null) as CapuzMacabro
	var velho := c.get_meta(&"rosto", null) as Node3D
	var cab := CabecaDoPadre.vestir(c, capuz)
	if cab == null:
		return null
	if velho != null and is_instance_valid(velho):
		velho.visible = false
	if capuz != null:
		capuz.abrir_para_rosto(cab)
	c.set_meta(&"rosto", cab)
	return cab


## Monta os padres da janela: as cabecas nos `romeiros` e o do passageiro na
## abertura `a` (a janela da frente do lado +1, espaco da cabine).
static func montar(cena: Node, carro: Node3D, romeiros: Array, cam: Camera3D,
		a: Dictionary) -> PadresNasJanelas:
	for c: Corpo in romeiros:
		vestir_cabeca(c)
	var p := PadresNasJanelas.new()
	p.name = "PadresNasJanelas"
	# Depois do laco da cena (que anima os corpos): a pose de cabecada vai por
	# cima.
	p.process_priority = 100
	cena.add_child(p)
	if romeiros.size() > QUAL and carro != null and not a.is_empty():
		p._na_janela(carro, romeiros[QUAL] as Corpo, cam, a)
	return p


func _na_janela(carro: Node3D, c: Corpo, cam: Camera3D, a: Dictionary) -> void:
	_carro = carro
	_cabine = carro.get("cabine") as Node3D
	_a = a
	_corpo = c
	_cab = c.get_meta(&"rosto", null) as CabecaDoPadre
	if _cabine == null or _cab == null:
		_corpo = null
		return
	if c.get_parent() != carro:
		c.get_parent().remove_child(c)
		carro.add_child(c)
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	var centro: Vector3 = a["centro"]
	var n_carro := (carro.global_basis.inverse() * (_cabine.global_basis * n)).normalized()
	var c_carro := carro.to_local(_cabine.to_global(centro))
	_meio_y = c_carro.y
	var fora := Vector3(n_carro.x, 0.0, n_carro.z).normalized()
	# Do lado de fora da porta, como o principal do outro lado (0,63 m do
	# vidro), e um palmo mais para tras: nao e o espelho dele.
	c.position = Vector3(c_carro.x, 0.0, c_carro.z) + fora * 0.63 + Vector3(0.0, 0.0, 0.08)
	c.basis = Basis.looking_at(-fora, Vector3.UP)
	# Parado: sem alvo para andar.
	c.set_meta(&"rapidez", 0.0)
	# Em pe e curvado: e mais baixo que o principal, e agachado a testa batia
	# rente ao peitoril, com a cabeca escondida pela porta.
	c.agachado = false
	c.inclinacao = Vector2(0.04, 0.24)
	c.agarrar = Vector3.INF
	c.olhar_lateral(0.1, -0.8)
	var tique := c.get_meta(&"tique", null) as TiqueMacabro
	if tique != null:
		tique.modo = TiqueMacabro.Modo.JANELA
	for _i in 30:
		c.animar(0.0, 0.05)
	var o_vidro := carro.to_local(_cabine.to_global(centro + n * SangueNoVidro.PARA_FORA))
	_pose = CabecadaDoPadre.new(c, _cab, cam, o_vidro, n_carro)
	# A altura: em pe a testa dele fica ~56 cm acima do meio do vidro, e no
	# bote (tronco e queixo) ela desce uns 20 cm. O corpo desce o que faltar
	# para a testa de repouso ficar `SOBRE_O_MEIO` acima do meio do vidro: o
	# golpe cai no meio dele (as pernas ficam atras da porta).
	c.position.y += (c_carro.y + SOBRE_O_MEIO) - _pose.testa_no_carro().y
	_pose = CabecadaDoPadre.new(c, _cab, cam, o_vidro, n_carro)
	var capuz := c.get_meta(&"capuz", null) as CapuzMacabro
	if capuz != null:
		_pose.prender_pano(capuz.pano)
		capuz.sorriso = 0.7
	_pose.distancia = _pose.distancia_agora()
	_pose.encara = 0.45
	var chega := create_tween()
	chega.tween_property(_pose, "distancia", PERTO, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_sangue = SangueNoVidro.na_abertura(a, 9.0)
	if _sangue != null:
		_cabine.add_child(_sangue)
		_sangue.visible = false
	c.visible = true
	_maos_no_vidro()
	_acender_o_fogo(n_carro)


## Onde esta a cara dele (mundo), para a lente olhar; INF se nao ha ninguem.
func rosto() -> Vector3:
	if _corpo == null or _pose == null:
		return Vector3.INF
	return _pose.testa() + Vector3.DOWN * 0.08


## Um golpe: `recua` s de antecipacao (a cabeca para tras, `longe` m do
## vidro), `bote` s ate o vidro, e o contato com `forca` 0 a 1. O contato
## acontece `recua + bote` s depois da chamada.
func golpe(recua: float, bote: float, longe: float, forca: float) -> void:
	if _pose == null:
		return
	# Um golpe de cada vez: o descolar do anterior brigava com o bote deste.
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var t := create_tween().set_parallel(true)
	_tw = t
	t.tween_property(_pose, "recua", 1.0, recua).set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(_pose, "bote", 0.0, recua * 0.6)
	t.tween_property(_pose, "distancia", PERTO + longe, recua).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(recua).timeout
	if _pose == null:
		return
	if _tw != t:
		return
	var b := create_tween().set_parallel(true)
	_tw = b
	b.tween_property(_pose, "distancia", -AMASSA, bote).set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	b.tween_property(_pose, "recua", 0.0, bote).set_ease(Tween.EASE_IN)
	b.tween_property(_pose, "bote", 1.0, bote).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(bote).timeout
	# O quadro em que a pose chega no vidro (`aplicar` roda depois da cena).
	await get_tree().process_frame
	await get_tree().process_frame
	if _tw != b:
		return
	_bater(forca)
	await get_tree().create_timer(0.16).timeout
	if _pose == null or _tw != b:
		return
	var d := create_tween().set_parallel(true)
	_tw = d
	d.tween_property(_pose, "distancia", PERTO, 0.3).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)
	d.tween_property(_pose, "bote", 0.2, 0.3)


func _bater(forca: float) -> void:
	var ponto := _cabine.to_local(_carro.to_global(_pose.ponto_no_vidro()))
	print("[outros] golpe %d: testa a %.2f m de altura (meio do vidro %.2f), a %.3f m dele" % [
		_golpes, _pose.testa_no_carro().y, _meio_y, _pose.distancia_agora()])
	# Sem encostar (o golpe curto nao chega), so o baque: sangue e trinca so
	# onde a testa tocou.
	if _pose.distancia_agora() > 0.04:
		return
	var n: Vector3 = (_a["normal"] as Vector3).normalized()
	# A agua do vidro (quem estiver no grupo): ver `CercoNoCarro.GRUPO_AGUA`.
	get_tree().call_group(CercoNoCarro.GRUPO_AGUA, &"impacto", _cabine.to_global(ponto),
		(_cabine.global_basis * n).normalized(), clampf(forca, 0.0, 1.0))
	if _sangue != null:
		_sangue.visible = true
		_sangue.golpe(ponto, forca, 1.0 + 0.12 * float(_golpes))
	# A trinca e de dentro do vidro, por cima do sangue. Ela cresce, mas este
	# vidro nao estoura: so o do principal.
	if _trinca == null:
		_trinca = TrincaDeVidro.na_abertura(_a, ponto - n * 0.024, 23.0)
		if _trinca != null:
			_cabine.add_child(_trinca)
			_trinca.ajustar(&"miolo", 0.03)
			_trinca.ajustar(&"alcance", 0.14)
			_trinca.material_override.render_priority = 2
	if _trinca != null:
		_trinca.ajustar(&"alcance", minf(0.14 + 0.1 * float(_golpes), 0.5))
		_trinca.crescer(minf(0.5 + 0.15 * float(_golpes), 0.95), 0.06)
	var dano: float = DANO[mini(_golpes, DANO.size() - 1)]
	var de := _cab.dano()
	var cab := _cab
	create_tween().tween_method(func(v: float) -> void: cab.por_dano(v), de, dano, 0.045)
	_cab.por_sangue(minf(0.2 + 0.2 * float(_golpes), 0.7))
	_golpes += 1
	_maos_no_golpe(forca)
	if _cena != null and _cena.has_method(&"_som"):
		_cena.call(&"_som", &"cabecada_vidro_1", -13.0 + 2.0 * forca, 0.92)
	if _carro != null and _carro.has_method(&"pancada"):
		_carro.call(&"pancada", 0.015 * forca, 0.12 * forca)


func _process(delta: float) -> void:
	if _pose != null and _corpo != null and is_instance_valid(_corpo) and _corpo.visible:
		_pose.aplicar()
		_maos_no_quadro(delta)
		_tremer_o_fogo(delta)


## A cara dele do lado de fora do carona nao pega luz nenhuma: o fogo esta no
## capo, na frente, e o painel e do lado do motorista. Esta e o rebote do fogo
## vindo da frente do carro, curta (so a cara e as maos), tremendo com ele.
func _acender_o_fogo(n_carro: Vector3) -> void:
	_luz = OmniLight3D.new()
	_luz.name = "FogoNaCara"
	_luz.light_color = LUZ_FOGO
	_luz.light_energy = LUZ_ENERGIA
	_luz.omni_range = LUZ_ALCANCE
	_luz.omni_attenuation = 1.6
	_luz.shadow_enabled = false
	_carro.add_child(_luz)
	# Um palmo para fora do vidro e meio metro para a frente do carro (-Z), na
	# altura da testa.
	var testa := _pose.testa_no_carro()
	_luz.position = testa + n_carro * 0.35 + Vector3(0.0, 0.05, -0.55)


func _tremer_o_fogo(delta: float) -> void:
	if _luz == null:
		return
	_t += delta
	var r := sin(_t * 17.0) * 0.5 + sin(_t * 7.3 + 1.7) * 0.3 + sin(_t * 31.0 + 0.4) * 0.2
	_luz.light_energy = LUZ_ENERGIA * (1.0 + LUZ_TREME * r)


## As maos dele sobem do escuro e espalmam no vidro, dos dois lados da cara, a
## palma no plano da janela e os dedos abertos. O braco de esqueleto (a mao do
## `Corpo` e rigida no antebraco, nao deita a palma) se apaga; quem aparece sao
## os `BracoVivo`, com o ombro no do esqueleto a cada quadro.
func _maos_no_vidro() -> void:
	var esq := _corpo.esqueleto()
	if esq == null:
		return
	for nome: String in ["BracoPodreE", "BracoPodreD"]:
		var bp := esq.get_node_or_null(nome) as Node3D
		if bp != null:
			bp.visible = false
	var n: Vector3 = (_a["normal"] as Vector3).normalized()
	var pts: PackedVector3Array = _a["pontos"]
	var cima := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
	var frente := pts[0] - pts[1]
	frente = (frente - n * n.dot(frente)).normalized()
	var centro: Vector3 = _a["centro"]
	var testa := _cabine.to_local(_carro.to_global(_pose.ponto_no_vidro()))
	# Ele olha para dentro (-n): a direita dele e (-n) x cima.
	var direita_dele := (-n).cross(Vector3.UP).normalized()
	for k in MAOS.size():
		var m: Vector2 = MAOS[k]
		var direita := (frente * m.x).dot(direita_dele) > 0.0
		var b := BracoVivo.criar("MaoCarona%d" % k, direita, BracosPodres.PELE,
			BracosPodres.MANGA, true)
		MaosPodres.vestir(b)
		b.layers = 1
		b.dedos_vivos = 1.3
		_cabine.add_child(b)
		var lado := signf(m.x)
		# No plano do vidro, do lado de fora (a palma encosta, o dorso para fora).
		var onde := testa + frente * m.x + cima * m.y
		onde += n * (0.013 - n.dot(onde - centro))
		var d := (cima + frente * lado * MAO_ABRE).normalized()
		var baixo := BracoVivo.pega(onde + n * 0.3 - cima * 0.5, d, n, &"relaxada")
		var perto := BracoVivo.pega(onde + n * 0.05 - cima * 0.03, d, n, &"aberta")
		var pousa := BracoVivo.pega(onde, d, n, &"apoio")
		_maos.append(b)
		_no_vidro.append(pousa)
		b.pular(baixo)
		_mao_no_quadro(b, k, 0.0)
		b.visible = true
		b.ir(perto, MAO_SOBE * (0.8 + 0.3 * float(k)), n * 0.1, 0.3)
		_assentar(b, k, pousa, MAO_SOBE * (0.8 + 0.3 * float(k)))


func _assentar(b: BracoVivo, k: int, pousa: Dictionary, depois: float) -> void:
	await get_tree().create_timer(depois).timeout
	if not is_instance_valid(b):
		return
	b.ir(pousa, 0.12)
	await get_tree().create_timer(0.1).timeout
	if _cena != null and _cena.has_method(&"_som"):
		_cena.call(&"_som", &"mao_pousa_vidro", -15.0 + 2.0 * float(k), 0.95)
	var n: Vector3 = (_a["normal"] as Vector3).normalized()
	get_tree().call_group(CercoNoCarro.GRUPO_AGUA, &"impacto",
		_cabine.to_global(pousa["o"] as Vector3), (_cabine.global_basis * n).normalized(), 0.3)
	var aperta := pousa.duplicate()
	aperta["pose"] = MaoPosada.pose(&"apoio_forca")
	b.ir(aperta, 0.3)


func _maos_no_quadro(delta: float) -> void:
	for k in _maos.size():
		_mao_no_quadro(_maos[k], k, delta)


## O ombro do braco vivo no do esqueleto (o corpo vai e volta nas cabecadas e o
## cotovelo dobra de novo entre ele e a mao presa), os cotovelos para baixo e
## para fora.
func _mao_no_quadro(b: BracoVivo, k: int, delta: float) -> void:
	if not is_instance_valid(b):
		return
	var esq := _corpo.esqueleto()
	var n: Vector3 = (_a["normal"] as Vector3).normalized()
	var ombros := [Corpo.Osso.BRACO_E, Corpo.Osso.BRACO_D]
	var o0 := _cabine.to_local(esq.global_transform * esq.get_bone_global_pose(ombros[0]).origin)
	var o1 := _cabine.to_local(esq.global_transform * esq.get_bone_global_pose(ombros[1]).origin)
	# O ombro mais perto da mao.
	var alvo: Vector3 = (_no_vidro[k]["o"] as Vector3) if k < _no_vidro.size() else o0
	b.ombro = o0 if o0.distance_to(alvo) < o1.distance_to(alvo) else o1
	var lado := signf((MAOS[k] as Vector2).x)
	var pts: PackedVector3Array = _a["pontos"]
	var frente := (pts[0] - pts[1]).normalized()
	b.polo = (Vector3.DOWN * 0.6 + frente * lado * 0.7 + n * 0.3).normalized()
	b.tremor = 0.3
	b.passo(delta)


## O golpe passa pelas maos: elas apertam o vidro e escorregam um nada.
func _maos_no_golpe(forca: float) -> void:
	for k in _maos.size():
		var b := _maos[k]
		if not is_instance_valid(b) or k >= _no_vidro.size():
			continue
		var n: Vector3 = (_a["normal"] as Vector3).normalized()
		var cima := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
		var q := (_no_vidro[k] as Dictionary).duplicate()
		q["o"] = (q["o"] as Vector3) - cima * 0.008 * forca
		q["pose"] = MaoPosada.pose(&"apoio_forca")
		_no_vidro[k] = q
		b.ir(q, 0.08)


func _enter_tree() -> void:
	_cena = get_parent()

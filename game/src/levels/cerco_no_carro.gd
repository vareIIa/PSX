## Os encapuzados subindo no carro enquanto o "?" escreve, e o do capo que
## bate a testa no para-brisa junto com o padre da janela.
##
## Onde entra
## ----------
## A `AberturaEstrada` carrega este arquivo pelo caminho e so avisa os momentos
## (`montar`, `aquecer`, `comecar`, `mensagem`, `congelar`, `cabecada`,
## `desligar`) e pergunta onde esta o rosto do capo (`rosto_no_capo`). A lente e
## dela: daqui so sai o pedido de um relance, quando o capo afunda com o peso.
##
## Quem sobe
## ---------
## Tres dos romeiros que ja existem (os do fundo da mata; os cinco primeiros
## vao para a meia-lua da janela), cada um com o seu `EscaladorDoCarro`:
##
## - o do CAPO: vem da frente, pela quina do motorista (a da direita abracou a
##   arvore). As maos batem na borda do capo, a cabeca sobe devagar por cima do
##   nariz, e ele puxa o corpo: um joelho, o outro, e rasteja pelo fogo ate o
##   pe do para-brisa. Ali ele se encolhe como bicho, os cotovelos para cima, a
##   cabeca esticada para o vidro, olhando o motorista. E ele que bate a testa.
## - o do TETO na frente: sobe pelo para-lama do carona, sobe o PARA-BRISA de
##   quatro (as palmas no vidro, a barriga rente) e passa para o teto. La em cima
##   ele bate as palmas no teto, e no fim fica agachado na beira da frente, uma
##   mao agarrada na borda de cima do vidro — os dedos aparecendo por dentro.
## - o do TETO atras: sobe pela tampa do porta-malas e pelo vidro de tras, e da
##   joelhada e palmada no teto. Ninguem ve: o carro balanca e o teto troveja.
##
## O peso
## ------
## Quem esta em cima do carro pesa nele. Cada um tem o quanto do peso esta no
## carro (0 no chao, 1 todo) e onde, e a soma vira torque nas molas de arfar e
## rolar (`CarroCena.pancada`, um pouco por quadro: e uma forca, e nao um
## tranco). O capo afunda o nariz; o do teto deita o carro para o lado dele.
## Cada apoio que chega (a mao, o joelho) e um tranco a mais, com o som dele.
##
## A cabecada
## ----------
## A testa bate no ponto certo do vidro no tempo que o roteiro pede
## (`cabecada(golpe, ate_o_impacto)`): o corpo recua devagar, segura, e cai de
## uma vez, sem frear, ate a testa encostar no plano do vidro — a pose do
## contato e ajustada ate a testa cair nele. No contato: o som na testa, uma
## teia nova no laminado (`TrincaDeVidro`, recortada em volta do ponto: o
## laminado nao estoura, afunda e faz teia), o sangue (`SangueNoVidro`), e o
## carro sacode. O rosto fica colado, escorrega um palmo e deixa o rastro.
class_name CercoNoCarro
extends Node

## Quais romeiros sobem (indices em `_romeiros`). Os cinco primeiros sao da
## janela. O capo e o mais alto dos de tipo 0 (1,90 m).
const ROMEIRO_CAPO := 10
const ROMEIRO_TETO := 7
const ROMEIRO_TRAS := 13
## O centro do capo na largura (m, espaco do carro): na frente do motorista.
const CAPO_X := -0.36
## Onde ele sobe (o meio dele na largura, na frente do carro).
const SUBIDA_X := -0.42
## Quanto do peso de um homem vira torque nas molas (rad/s^2 por metro de
## braco de alavanca). Medido contra o que um adulto faz num carro de passeio:
## meio grau de nariz no capo, meio grau de lado na beira do teto.
const TORQUE_ARFAR := 0.85
const TORQUE_ROLAR := 1.9
## A pancada de um apoio chegando, por unidade de forca (rad/s).
const TRANCO_ARFAR := 0.34
const TRANCO_ROLAR := 0.30
## O som dos apoios: volume (dB) com forca 0 e 1.
const APOIO_DB := Vector2(-16.0, -1.0)
## A cabecada: quanto a testa entra atras do plano do vidro no contato (o pano
## do capuz entre os dois), a pancada nas molas e o volume.
const TESTA_NO_VIDRO := 0.013
const CABECADA_TRANCO := Vector2(-0.55, 0.22)
const CABECADA_DB := [-3.0, 0.0, 2.0, 3.0, 4.0]
## Onde a testa bate, por golpe (fracao da largura do motorista para o carona
## em x, altura do vidro em y). Cada golpe um pouco mais baixo: ele escorrega.
const PONTOS_DA_TESTA := [Vector2(-0.34, 1.13), Vector2(-0.31, 1.115),
	Vector2(-0.37, 1.10), Vector2(-0.33, 1.085), Vector2(-0.35, 1.07)]
## A teia de cada golpe: alcance (m) e miolo (m) do laminado.
const TEIA := [Vector2(0.20, 0.05), Vector2(0.28, 0.06), Vector2(0.34, 0.07),
	Vector2(0.38, 0.075), Vector2(0.40, 0.08)]
## O relance que o capo pede quando afunda com o peso: ida, fica, volta (s),
## o quanto a lente vai e o campo dela.
const RELANCE := [0.15, 0.5, 0.35, 0.9, 46.0]
## Quando ele pede, na pista do capo: o joelho subindo na borda, o nariz
## afundando.
const RELANCE_EM := 2.3

var _ab: Node
var _carro: CarroCena
var _cabine: Node3D
var _capo: EscaladorDoCarro
var _teto: EscaladorDoCarro
var _tras: EscaladorDoCarro
var _todos: Array[EscaladorDoCarro] = []
## Quanto do peso de cada um esta no carro (0 a 1), por escalador.
var _peso: Dictionary = {}
var _comecou: bool = false
var _congelado: bool = false
var _desligado: bool = false
var _sangue: SangueNoVidro
var _teias: Array[TrincaDeVidro] = []
var _tocando: Array[AudioStreamPlayer3D] = []
var _relogio: float = 0.0
var _rosto_suave := Vector3.INF
var _mensagens: int = 0
var _total_mensagens: int = 7
## Chao plano (a bancada): a altura do chao no espaco do carro. NAN = a estrada.
var _chao_plano: float = NAN
## `--cerco-sonda`: o quanto os apoios entram na lataria, por segundo.
var _sonda: bool = OS.get_cmdline_user_args().has("--cerco-sonda")
var _sonda_t: float = 0.0
var _sonda_pior: Dictionary = {}
## O fim da subida do capo (s na pista dele): dali ele esta no pe do vidro.
var _capo_chega: float = 0.0
## Golpes ja dados na cabecada.
var _golpes: int = 0


func _ready() -> void:
	# Antes da abertura no quadro: o corpo ja esta posto quando ela mira a lente
	# no rosto dele.
	process_priority = -5


# --- ganchos ----------------------------------------------------------------

func montar(abertura: Node) -> void:
	_ab = abertura
	_carro = abertura.get(&"_carro") as CarroCena
	if _carro == null:
		return
	_cabine = _carro.cabine
	var romeiros: Array = abertura.get(&"_romeiros")
	if romeiros == null or romeiros.size() <= maxi(ROMEIRO_CAPO, maxi(ROMEIRO_TETO, ROMEIRO_TRAS)):
		push_warning("[cerco] romeiros de menos: %s" % [romeiros.size() if romeiros != null else 0])
		return
	_capo = _escalador(romeiros[ROMEIRO_CAPO], 0, "capo")
	_teto = _escalador(romeiros[ROMEIRO_TETO], 1, "teto")
	_tras = _escalador(romeiros[ROMEIRO_TRAS], 2, "tras")
	# O sangue e as teias do para-brisa ja nascem aqui, apagados: os pontos da
	# testa sao os da pose, conhecidos antes.
	var a := _parabrisa()
	if not a.is_empty() and _cabine != null:
		_sangue = SangueNoVidro.na_abertura(a, 5.0)
		if _sangue != null:
			_sangue.name = "SangueDoCapo"
			_cabine.add_child(_sangue)
		for g in PONTOS_DA_TESTA.size():
			var p := _ponto_no_parabrisa(PONTOS_DA_TESTA[g])
			var teia := TEIA[mini(g, TEIA.size() - 1)] as Vector2
			var tr := TrincaDeVidro.na_abertura(_recorte_do_vidro(a, p, teia.x * 1.25 + teia.y),
				p, 61.0 + float(g) * 13.0)
			if tr == null:
				_teias.append(null)
				continue
			tr.name = "TeiaDoCapo%d" % g
			_cabine.add_child(tr)
			tr.ajustar(&"alcance", teia.x)
			tr.ajustar(&"miolo", teia.y)
			tr.ajustar(&"forca_fio", 0.85)
			tr.visible = false
			_teias.append(tr)


func aquecer(ligar: bool, onde: Vector3) -> void:
	if _carro == null:
		return
	if _sangue != null:
		_sangue.aquecer(ligar, onde)
	for tr: TrincaDeVidro in _teias:
		if tr == null:
			continue
		tr.visible = ligar
		tr.por_cresce(0.002 if ligar else 0.0)


func comecar() -> void:
	if _carro == null or _capo == null or _comecou:
		return
	_comecou = true
	for e: EscaladorDoCarro in _todos:
		var c := e.corpo
		if c.get_parent() != _carro:
			c.get_parent().remove_child(c)
			_carro.add_child(c)
		c.set_meta(&"cerco", true)
		c.dominado = true
		# A treva de volume dele encheria o para-brisa de preto: so a fumaca.
		for f: Node in c.get_children():
			if f is FogVolume:
				(f as FogVolume).visible = false
		var capuz := c.get_meta(&"capuz", null) as CapuzMacabro
		if capuz != null and capuz.pano != null and not OS.get_cmdline_user_args().has("--cerco-batina"):
			# A batina de pano deita no piso do pano, que e um plano so: em cima do
			# carro ela passava da borda do capo e do teto como um lencol duro no ar.
			# Quem veste a perna aqui e o sobretudo do `Corpo`, que dobra com ela.
			for pc: PanoGPU.PecaDePano in capuz.pano.pecas:
				if pc.nome == "Batina" and pc.instancia != null:
					pc.instancia.visible = false
		if capuz != null:
			capuz.olhos = 2.2
			capuz.olhos_tamanho = 1.5
			capuz.sorriso = 0.0
	_pista_do_capo()
	_pista_do_teto()
	_pista_de_tras()
	for e: EscaladorDoCarro in _todos:
		e.ativo = true
		e.resolver()
		if _ab != null and _ab.has_method(&"_mostrar"):
			_ab.call(&"_mostrar", e.corpo)
		else:
			e.corpo.visible = true
		var aura := e.corpo.get_meta(&"aura", null) as AuraNegra
		if aura != null:
			# A fumaca dele atras dele, e rala: na frente do rosto ela tapava o vidro.
			aura.position = Vector3(0.0, e.corpo.altura() * 0.3, 0.35)
	print("[cerco] comecou: capo, teto e tras subindo (capo chega em %.2f s)" % _capo_chega)


func mensagem(i: int, total: int) -> void:
	_mensagens = i + 1
	_total_mensagens = total
	if _capo == null or not _comecou or _congelado:
		return
	# A ultima ("Olha pra mim.") chega uns 0,6 s antes do aparelho morrer: ele
	# tem de estar no vidro ate la. Se a pista esta atrasada, ela corre.
	var falta := _total_mensagens - _mensagens
	var sobra := 0.6 + float(falta) * 0.75
	for e: EscaladorDoCarro in _todos:
		var alvo := _capo_chega if e == _capo else e.fim()
		var precisa := alvo - e.t
		if precisa > sobra:
			e.ritmo = clampf(precisa / sobra, 1.0, 2.2)


func congelar() -> void:
	_congelado = true
	for e: EscaladorDoCarro in _todos:
		e.parado = true
	for p: AudioStreamPlayer3D in _tocando:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	_tocando.clear()
	if _sangue != null:
		_sangue.parado = true
	print("[cerco] congelou: capo t=%.2f de %.2f" % [_capo.t if _capo != null else -1.0, _capo_chega])


func cabecada(golpe: int, ate_o_impacto: float) -> void:
	if _capo == null or _desligado:
		return
	if not _comecou:
		comecar()
	var e := _capo
	# Se ele ainda nao chegou no vidro, chega agora: a pista pula para o pe do
	# para-brisa (ninguem ve: e a primeira cabecada, fora do quadro).
	if e.t < _capo_chega:
		e.t = _capo_chega
	e.parado = false
	e.ritmo = 1.0
	if _sangue != null:
		_sangue.parado = false
	_golpes = golpe + 1
	_pista_da_cabecada(golpe, maxf(ate_o_impacto, 0.05))


func rosto_no_capo() -> Vector3:
	if _capo == null or _carro == null or not _comecou:
		return Vector3.INF
	var r := _carro.global_transform * _capo.rosto()
	return _rosto_suave if _rosto_suave.is_finite() else r


func desligar() -> void:
	_desligado = true
	for e: EscaladorDoCarro in _todos:
		e.ativo = false
		e.corpo.visible = false
	for p: AudioStreamPlayer3D in _tocando:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	_tocando.clear()


## Os lugares do cerco sonoro da abertura (`BATIDA_LUGARES`) que ja tem corpo
## aqui: o capo, o para-brisa e o teto batem pelos corpos, no tempo deles.
func lugar_ocupado(onde: Vector3) -> bool:
	if not _comecou or _desligado:
		return false
	# O teto, o para-brisa e o capo (y alto ou na frente).
	return onde.y > 1.3 or onde.z < -0.8


## A bancada: chao plano nesta altura (espaco do carro), sem a estrada.
func usar_chao_plano(y: float) -> void:
	_chao_plano = y


# --- o quadro ---------------------------------------------------------------

func _process(delta: float) -> void:
	if not _comecou or _desligado or _carro == null:
		return
	_relogio += delta
	for e: EscaladorDoCarro in _todos:
		e.avancar(delta)
	_pesar(delta)
	var r := _carro.global_transform * _capo.rosto()
	if not _rosto_suave.is_finite():
		_rosto_suave = r
	# Sem o tremor da cabeca: a lente que mira no rosto nao pode tremer junto.
	_rosto_suave = _rosto_suave.lerp(r, 1.0 - exp(-delta * 14.0))
	if _sonda:
		_sondar(delta)


## O peso de quem esta em cima: torque nas molas, um pouco por quadro.
func _pesar(delta: float) -> void:
	if _congelado and _capo.parado:
		# Parado, o peso ja assentou nas molas; o torque continua (e ele que
		# segura o nariz baixo), sem tremer.
		pass
	var arfar := 0.0
	var rolar := 0.0
	for e: EscaladorDoCarro in _todos:
		var w: float = _peso.get(e, 0.0)
		if w <= 0.0 or e.ultimo.is_empty():
			continue
		var q: Vector3 = e.ultimo["quadril"]
		# Nariz em -Z: peso na frente (z negativo) mergulha o nariz (arfar
		# negativo). Peso a direita (+X) deita a direita (rolar positivo).
		arfar += w * q.z * TORQUE_ARFAR
		rolar += w * q.x * TORQUE_ROLAR
	if absf(arfar) + absf(rolar) > 0.0:
		_carro.pancada(arfar * delta, rolar * delta)


## Um apoio chegou na lataria: o som dele ali e o tranco.
func _ao_apoiar(e: EscaladorDoCarro, membro: int, onde: Vector3, apoio: int, forca: float) -> void:
	if _congelado or _desligado or forca <= 0.0:
		return
	var vidro := _no_vidro(onde)
	var nome: StringName
	var db := lerpf(APOIO_DB.x, APOIO_DB.y, forca)
	var afina := randf_range(0.9, 1.08)
	match apoio:
		EscaladorDoCarro.Apoio.JOELHO:
			nome = StringName("passo_metal_%d" % randi_range(1, 4)) if not vidro \
				else &"mao_pousa_vidro"
			afina *= 0.72
			db += 2.0
		EscaladorDoCarro.Apoio.PE:
			nome = StringName("passo_metal_%d" % randi_range(1, 4))
			afina *= 0.85
		_:
			if vidro:
				nome = StringName("mao_vidro_%d" % randi_range(1, 2))
			else:
				nome = StringName("mao_lataria_%d" % randi_range(1, 4))
	# O teto: de dentro, a chapa grande e um tambor.
	if onde.y > 1.3 and not vidro:
		afina *= 0.78
		db += 3.0
	_tocar(nome, onde, db, afina)
	var arm := (onde.z if absf(onde.z) > 0.3 else 0.0)
	_carro.pancada(TRANCO_ARFAR * forca * arm * 0.6, TRANCO_ROLAR * forca * onde.x * 0.8)


func _tocar(nome: StringName, onde: Vector3, db: float, afina: float = 1.0) -> AudioStreamPlayer3D:
	var st := AudioDirector.stream(nome)
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = afina
	p.unit_size = 3.0
	p.max_db = 6.0
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_carro.add_child(p)
	p.position = onde
	p.play()
	_tocando.append(p)
	p.finished.connect(func() -> void:
		_tocando.erase(p)
		p.queue_free())
	AudioDirector.registrar(nome, db, "cerco_corpo")
	return p


func _estalar(e: EscaladorDoCarro, forca: float) -> void:
	if _ab != null and _ab.has_method(&"_estalar"):
		_ab.call(&"_estalar", e.corpo, forca, true)


# --- a lataria --------------------------------------------------------------
## O topo do carro, no espaco dele, medido na malha do Marea
## (`tests/_tmp_sonda_lataria.tscn`, a altura do topo por x e z): o capo quase
## plano caindo no nariz, o para-brisa e o vidro de tras pelos planos das
## aberturas, o teto abaulado nas bordas e a tampa do porta-malas. Mais o
## amassado da batida, lido do proprio `Amassado` do carro.
const CAPO_Z := [[-2.10, 0.83], [-2.05, 0.855], [-2.0, 0.87], [-1.9, 0.88], [-1.8, 0.89],
	[-1.5, 0.90], [-1.2, 0.915], [-1.0, 0.92], [-0.87, 0.925]]
const TETO_Z := [[-0.46, 1.31], [-0.4, 1.32], [-0.3, 1.34], [-0.2, 1.36], [-0.1, 1.38],
	[0.0, 1.39], [0.7, 1.385], [0.8, 1.37], [0.9, 1.36], [1.0, 1.349]]
const TAMPA_Z := [[1.414, 1.03], [1.5, 1.01], [1.8, 1.0], [2.0, 0.97], [2.1, 0.91]]


## A altura do topo do carro em (x, z), espaco do carro.
func topo(x: float, z: float) -> float:
	var sz := float(_carro.medidas().get("comprimento", 4.36)) / 4.36
	var zz := z / sz
	var y: float
	var pb := _plano(&"parabrisa")
	var vg := _plano(&"vigia")
	if zz < -0.874:
		y = _tabela(CAPO_Z, zz)
		# A quina do para-lama cai.
		y -= smoothstep(0.70, 0.84, absf(x)) * 0.045
	elif zz < -0.459 and not pb.is_empty():
		y = _no_plano(pb, x, z)
	elif zz < 0.998:
		y = _tabela(TETO_Z, zz)
		y -= smoothstep(0.60, 0.72, absf(x)) * 0.05
	elif zz < 1.414 and not vg.is_empty():
		y = _no_plano(vg, x, z)
	else:
		y = _tabela(TAMPA_Z, zz)
	var am: Variant = _carro.get(&"_amassado")
	if am != null and zz < -0.8:
		y += ((am as Object).call(&"deslocamento", Vector3(x, y, z)) as Vector3).y
	return y


func no_topo(x: float, z: float, acima: float = 0.0) -> Vector3:
	return Vector3(x, topo(x, z) + acima, z)


func _no_vidro(p: Vector3) -> bool:
	var sz := float(_carro.medidas().get("comprimento", 4.36)) / 4.36
	var zz := p.z / sz
	return (zz > -0.9 and zz < -0.44 and absf(p.x) < 0.74) \
		or (zz > 0.98 and zz < 1.43 and absf(p.x) < 0.7)


static func _tabela(t: Array, z: float) -> float:
	if z <= float(t[0][0]):
		return float(t[0][1])
	for i in range(1, t.size()):
		if z <= float(t[i][0]):
			var k := (z - float(t[i - 1][0])) / (float(t[i][0]) - float(t[i - 1][0]))
			return lerpf(float(t[i - 1][1]), float(t[i][1]), k)
	return float(t[t.size() - 1][1])


func _plano(tipo: StringName) -> Dictionary:
	for a: Dictionary in _carro.medidas().get("aberturas", []):
		if a["tipo"] == tipo:
			return a
	return {}


static func _no_plano(a: Dictionary, _x: float, z: float) -> float:
	var c: Vector3 = a["centro"]
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	if absf(n.y) < 1e-3:
		return c.y
	return c.y - n.z / n.y * (z - c.z)


func _parabrisa() -> Dictionary:
	return _plano(&"parabrisa")


## O ponto do para-brisa em (x, y), espaco do carro.
func _ponto_no_parabrisa(xy: Vector2) -> Vector3:
	var a := _parabrisa()
	if a.is_empty():
		return Vector3(xy.x, xy.y, -0.7)
	var c: Vector3 = a["centro"]
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	# n.y (y - c.y) + n.z (z - c.z) = 0
	var z := c.z - n.y / n.z * (xy.y - c.y) if absf(n.z) > 1e-3 else c.z
	return Vector3(xy.x, xy.y, z)


## A abertura `a` recortada num disco de `raio` em volta de `p`: a teia so e
## desenhada ali (a lamina da trinca le a tela de tras, e a do para-brisa
## inteiro custava o vidro todo por teia).
func _recorte_do_vidro(a: Dictionary, p: Vector3, raio: float) -> Dictionary:
	var contorno: PackedVector3Array = a.get("contorno", a.get("pontos", PackedVector3Array()))
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	var v := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
	var u := v.cross(n).normalized()
	var o := contorno[0]
	var poli := PackedVector2Array()
	for q: Vector3 in contorno:
		poli.append(Vector2((q - o).dot(u), (q - o).dot(v)))
	var centro := Vector2((p - o).dot(u), (p - o).dot(v))
	var disco := PackedVector2Array()
	for k in 20:
		var ang := float(k) / 20.0 * TAU
		disco.append(centro + Vector2(cos(ang), sin(ang)) * raio)
	var corte := Geometry2D.intersect_polygons(poli, disco)
	if corte.is_empty():
		return a
	var saida := PackedVector3Array()
	for q2: Vector2 in corte[0]:
		saida.append(o + u * q2.x + v * q2.y)
	var b := a.duplicate()
	b["contorno"] = saida
	return b


## A altura do chao em `p` (espaco do carro): a estrada e o barranco onde o
## carro parou, como a roda le (`CarroCena._contatos`).
func chao(p: Vector3) -> float:
	if not is_nan(_chao_plano):
		return _chao_plano
	var w := _carro.transform * p
	var s0 := _carro.distancia
	var dir := EstradaBuilder.direcao_em(s0)
	var s := s0 + (w - EstradaBuilder.ponto_em(s0)).dot(dir)
	var eixo := EstradaBuilder.ponto_em(s)
	var d := (w - eixo).dot(EstradaBuilder.lado_em(s))
	var y := eixo.y + KitEstrada.altura_da_pista(eixo, d) + EstradaBuilder.altura_lateral(d)
	return (_carro.transform.affine_inverse() * Vector3(w.x, y, w.z)).y


# --- o elenco ---------------------------------------------------------------

func _escalador(c: Corpo, semente: int, nome: String) -> EscaladorDoCarro:
	var e := EscaladorDoCarro.new(c, semente, nome)
	e.ao_apoiar = func(m: int, onde: Vector3, apoio: int, forca: float) -> void:
		_ao_apoiar(e, m, onde, apoio, forca)
	e.ao_estalar = func(forca: float) -> void: _estalar(e, forca)
	_todos.append(e)
	_peso[e] = 0.0
	return e


## O ponto que o olhar deles procura: a cabeca do motorista (a lente).
func _motorista() -> Vector3:
	var cam := _ab.get(&"_cam") as Camera3D if _ab != null else null
	if cam != null and is_instance_valid(cam) and cam.is_inside_tree():
		return _carro.global_transform.affine_inverse() * cam.global_position
	if _cabine != null and _cabine.has_method(&"olho"):
		return (_cabine.call(&"olho") as Vector3) + Vector3(0.0, 0.0, 0.2)
	return Vector3(-0.4, 1.16, 0.12)


## Muda o quanto do peso de `e` esta no carro, em `dur` segundos da pista.
func _pesa(e: EscaladorDoCarro, em: float, w: float, dur: float) -> void:
	e.evento(em, func() -> void:
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: _peso[e] = v, float(_peso.get(e, 0.0)), w,
			maxf(dur, 0.01)).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE))


# --- as pistas --------------------------------------------------------------
# Tempos em segundos desde `comecar`. O aparelho morre uns seis segundos
# depois (as sete mensagens do "?"): tudo que tem de ser visto acontece antes.

## O do capo. Frente dele para +Z (para dentro do carro): `frente` PI.
func _pista_do_capo() -> void:
	var e := _capo
	var s := e.corpo.altura() / Corpo.ALTURA_REF
	var x0 := SUBIDA_X
	var olho := func() -> Vector3: return _motorista()
	var eye: Vector3 = olho.call()
	var chao_frente := chao(Vector3(x0, 0.0, -2.6))
	# 0: agachado na frente do para-choque, abaixo da linha do capo (de dentro
	# nao se ve), as maos no chao.
	e.chave(0.0, {"quadril": Vector3(x0, chao_frente + 0.52 * s, -2.62), "frente": PI,
		"pelve": Vector3(-0.55, 0.0, 0.0), "tronco": Vector3(-0.35, 0.0, 0.0),
		"cabeca": Vector3(-0.3, 0.0, 0.2), "olha": eye, "olha_peso": 0.3,
		"piso": chao_frente})
	e.pousar(EscaladorDoCarro.PE_E, Vector3(x0 + 0.16, chao_frente, -2.55),
		EscaladorDoCarro.Apoio.PE)
	e.pousar(EscaladorDoCarro.PE_D, Vector3(x0 - 0.16, chao_frente, -2.62),
		EscaladorDoCarro.Apoio.PE)
	# 1: as maos batem na borda do capo, uma e depois a outra. A mao direita dele
	# fica do lado do motorista (-X): ele olha para dentro do carro.
	var mao_d1 := no_topo(x0 - 0.23, -1.97, 0.008)
	var mao_e1 := no_topo(x0 + 0.25, -1.99, 0.008)
	e.passo(EscaladorDoCarro.MAO_D, 0.28, 0.52, mao_d1, EscaladorDoCarro.Apoio.PONTA,
		Vector3(0.0, 0.22, -0.05), Vector3(-0.6, -0.4, -0.5), 0.55)
	e.passo(EscaladorDoCarro.MAO_E, 0.55, 0.78, mao_e1, EscaladorDoCarro.Apoio.PONTA,
		Vector3(0.0, 0.22, -0.05), Vector3(0.6, -0.4, -0.5), 0.5)
	e.chave(0.55, {"quadril": Vector3(x0, chao_frente + 0.60 * s, -2.58),
		"tronco": Vector3(-0.55, 0.0, 0.0), "cabeca": Vector3(-0.15, 0.0, 0.1),
		"olha_peso": 0.5}, &"sai")
	_pesa(e, 0.5, 0.12, 0.3)
	# 2: sobe devagar. A cabeca aparece por cima do nariz, no fogo, olhando.
	e.chave(1.05, {"quadril": Vector3(x0, chao_frente + 0.78 * s, -2.64),
		"tronco": Vector3(-0.35, 0.0, 0.0), "pelve": Vector3(-0.45, 0.0, 0.0),
		"olha_peso": 0.9, "cabeca": Vector3.ZERO}, &"suave")
	e.chave(1.75, {"quadril": Vector3(x0, chao_frente + 0.90 * s, -2.62),
		"tronco": Vector3(-0.5, 0.0, 0.0), "pelve": Vector3(-0.55, 0.0, 0.0),
		"olha_peso": 1.0}, &"suave")
	_pesa(e, 1.1, 0.25, 0.6)
	# Para. O pescoco estala para o lado olhando o motorista.
	e.evento(1.8, func() -> void: e.estalar_cabeca(Vector3(0.05, 0.1, 0.9)))
	# 3: o puxao. As maos andam para cima do capo, o peito deita no nariz, o
	# joelho direito sobe na borda.
	var mao_d2 := no_topo(x0 - 0.26, -1.74, 0.008)
	var mao_e2 := no_topo(x0 + 0.27, -1.70, 0.008)
	e.passo(EscaladorDoCarro.MAO_D, 1.95, 2.18, mao_d2, EscaladorDoCarro.Apoio.PONTA,
		Vector3(0.0, 0.12, 0.0), Vector3(-0.7, 0.5, 0.2), 0.7)
	e.passo(EscaladorDoCarro.MAO_E, 2.12, 2.34, mao_e2, EscaladorDoCarro.Apoio.PONTA,
		Vector3(0.0, 0.12, 0.0), Vector3(0.7, 0.5, 0.2), 0.6)
	e.chave(2.3, {"quadril": Vector3(x0, chao_frente + 1.02 * s, -2.36),
		"tronco": Vector3(-0.95, 0.0, 0.0), "pelve": Vector3(-0.75, 0.0, 0.0),
		"cabeca": Vector3(0.25, 0.0, 0.0)}, &"puxa")
	var joelho_d1 := no_topo(x0 - 0.13, -2.02)
	e.passo(EscaladorDoCarro.PE_D, 2.25, 2.55, joelho_d1, EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.25, -0.1), Vector3(0.0, -0.2, 1.0), 1.0)
	_pesa(e, 2.3, 0.7, 0.3)
	e.evento(RELANCE_EM, _pedir_relance)
	e.chave(2.7, {"quadril": Vector3(x0, 0.0, -2.2), "piso": topo(x0, -2.0),
		"tronco": Vector3(-0.9, 0.0, 0.05), "pelve": Vector3(-0.7, 0.0, 0.0),
		"cabeca": Vector3(0.1, 0.0, 0.0)}, &"puxa")
	# 4: o outro joelho. De quatro no capo.
	var joelho_e1 := no_topo(x0 + 0.13, -1.98)
	e.passo(EscaladorDoCarro.PE_E, 2.72, 3.0, joelho_e1, EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.22, -0.05), Vector3(0.0, -0.2, 1.0), 0.9)
	_pesa(e, 2.75, 1.0, 0.35)
	e.chave(3.05, {"quadril": Vector3(x0, 0.0, -2.12), "tronco": Vector3(-0.85, 0.0, 0.0),
		"pelve": Vector3(-0.85, 0.0, 0.0), "cabeca": Vector3(0.35, 0.0, 0.0)}, &"suave")
	# Para de novo, de quatro, a cabeca levantada: olha.
	e.evento(3.1, func() -> void: e.estalar_cabeca(Vector3(0.15, -0.35, -0.3)))
	# 5: rasteja pelo fogo ate o vidro. Aranha: a mao vai, para, o joelho vem.
	var zs := [[-1.46, -1.84], [-1.18, -1.52], [-0.97, -1.25], [-0.965, -1.07]]
	var tt := 3.25
	for i in zs.size():
		var zm: float = zs[i][0]
		var zj: float = zs[i][1]
		var ultimo := i == zs.size() - 1
		var abre := 0.27 if not ultimo else 0.30
		var dm := 0.2 + 0.05 * float(i % 2)
		e.passo(EscaladorDoCarro.MAO_D, tt, tt + dm, no_topo(CAPO_X - abre - 0.02, zm, 0.008),
			EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.1, 0.0), Vector3(-0.8, 0.7, 0.1), 0.35)
		e.passo(EscaladorDoCarro.MAO_E, tt + 0.16, tt + 0.16 + dm, no_topo(CAPO_X + abre, zm - 0.03, 0.008),
			EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.1, 0.0), Vector3(0.8, 0.7, 0.1), 0.3)
		var jx := 0.18 if ultimo else 0.13
		e.passo(EscaladorDoCarro.PE_E, tt + 0.28, tt + 0.52, no_topo(CAPO_X + jx, zj),
			EscaladorDoCarro.Apoio.JOELHO, Vector3(0.0, 0.07, 0.0), Vector3(0.3, -0.1, 1.0), 0.45)
		e.passo(EscaladorDoCarro.PE_D, tt + 0.36, tt + 0.62, no_topo(CAPO_X - jx, zj - 0.02),
			EscaladorDoCarro.Apoio.JOELHO, Vector3(0.0, 0.07, 0.0), Vector3(-0.3, -0.1, 1.0), 0.45)
		var zq := zj - 0.40
		e.chave(tt + 0.55, {"quadril": Vector3(lerpf(x0, CAPO_X, float(i + 1) / zs.size()), 0.0, zq),
			"piso": topo(CAPO_X, zj), "tronco": Vector3(-0.85 + 0.04 * float(i), 0.0,
			0.06 * (1.0 if i % 2 == 0 else -1.0)), "pelve": Vector3(-0.95, 0.0, 0.0),
			"cabeca": Vector3(0.4, 0.0, 0.0)}, &"puxa")
		# A pausa: fica, respira, e vai de novo.
		tt += 0.62 + (0.18 if i == 1 else 0.05)
	# 6: encolhe no pe do vidro, os cotovelos para cima, a cabeca esticada para o
	# vidro olhando o motorista. E aqui que ele fica.
	var perto := _pose_no_vidro()
	e.chave(tt + 0.35, perto, &"suave")
	_capo_chega = tt + 0.35
	e.evento(_capo_chega + 0.05, func() -> void:
		e.segurar_cabeca(Vector3(0.06, 0.0, 0.42), 1.4))


## O carro afunda com o peso no nariz: o motorista ergue os olhos do celular.
## O olhar cai entre o do capo e o que sobe o vidro, para os dois caberem.
func _pedir_relance() -> void:
	if _ab == null or not _ab.has_method(&"relance") or _congelado:
		return
	_ab.call(&"relance", _ponto_do_relance, float(RELANCE[0]), float(RELANCE[1]),
		float(RELANCE[2]), float(RELANCE[3]), float(RELANCE[4]))


func _ponto_do_relance() -> Vector3:
	if _capo == null or _carro == null:
		return Vector3.INF
	var a := _capo.rosto()
	var b := _teto.rosto() if _teto != null else a
	return _carro.global_transform * a.lerp(b, 0.3)


## A pose em que o do capo espera no pe do para-brisa, encolhido, olhando.
func _pose_no_vidro() -> Dictionary:
	return {"quadril": Vector3(CAPO_X, 0.0, -1.44), "piso": topo(CAPO_X, -1.1),
		"tronco": Vector3(-0.72, 0.0, 0.0), "pelve": Vector3(-0.98, 0.0, 0.0),
		"cabeca": Vector3(0.0, 0.0, 0.0), "olha": _motorista(), "olha_peso": 1.0}


## O do teto na frente: sobe pelo para-lama do carona e pelo para-brisa.
func _pista_do_teto() -> void:
	var e := _teto
	var s := e.corpo.altura() / Corpo.ALTURA_REF
	var chao_lado := chao(Vector3(1.3, 0.0, -1.2))
	var eye := _motorista()
	# 0: em pe do lado do para-lama do carona, virado para o carro (-X).
	e.chave(0.0, {"quadril": Vector3(1.32, chao_lado + 0.9 * s, -1.2), "frente": PI * 0.5,
		"pelve": Vector3.ZERO, "tronco": Vector3(-0.1, 0.0, 0.0), "olha": eye,
		"olha_peso": 0.4, "piso": chao_lado})
	e.pousar(EscaladorDoCarro.PE_E, Vector3(1.34, chao_lado, -1.05), EscaladorDoCarro.Apoio.PE)
	e.pousar(EscaladorDoCarro.PE_D, Vector3(1.3, chao_lado, -1.38), EscaladorDoCarro.Apoio.PE)
	# 1: as maos na quina do capo e na do para-brisa. Com a frente em -X, a mao
	# esquerda dele fica para tras (+Z).
	e.passo(EscaladorDoCarro.MAO_E, 0.12, 0.34, no_topo(0.7, -0.98, 0.008),
		EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.2, 0.0), Vector3(0.3, -0.5, 0.7), 0.45)
	e.passo(EscaladorDoCarro.MAO_D, 0.3, 0.5, no_topo(0.68, -1.45, 0.008),
		EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.2, 0.0), Vector3(0.3, -0.5, -0.7), 0.45)
	e.chave(0.5, {"quadril": Vector3(1.22, chao_lado + 0.78 * s, -1.2),
		"tronco": Vector3(-0.6, 0.0, 0.0), "pelve": Vector3(-0.3, 0.0, 0.0)}, &"sai")
	_pesa(e, 0.4, 0.2, 0.3)
	# 2: o joelho direito no para-lama, o puxao, o outro joelho.
	e.passo(EscaladorDoCarro.PE_D, 0.62, 0.9, no_topo(0.72, -1.3), EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.3, 0.0), Vector3(-1.0, -0.2, 0.0), 0.9)
	e.chave(0.95, {"quadril": Vector3(0.98, 0.0, -1.22), "piso": topo(0.6, -1.25),
		"tronco": Vector3(-0.95, 0.0, 0.0), "pelve": Vector3(-0.8, 0.0, 0.0)}, &"puxa")
	_pesa(e, 0.85, 0.75, 0.3)
	e.passo(EscaladorDoCarro.PE_E, 1.0, 1.28, no_topo(0.66, -1.02), EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.25, 0.0), Vector3(-1.0, -0.2, 0.0), 0.7)
	_pesa(e, 1.1, 1.0, 0.3)
	# 3: vira para o para-brisa (frente PI) e sobe o vidro de quatro. As palmas
	# no vidro vao na frente, os joelhos vem pelo capo e depois pelo vidro.
	e.chave(1.45, {"quadril": Vector3(0.62, 0.0, -1.3), "frente": PI,
		"tronco": Vector3(-0.8, 0.0, 0.0), "pelve": Vector3(-0.9, 0.0, 0.0),
		"cabeca": Vector3(0.3, 0.0, 0.0), "olha": eye, "olha_peso": 0.6}, &"estalo")
	var degraus := [[-0.8, -1.12, 1.45], [-0.66, -0.95, 1.92], [-0.53, -0.8, 2.4],
		[-0.40, -0.66, 2.88]]
	for i in degraus.size():
		var zm: float = degraus[i][0]
		var zj: float = degraus[i][1]
		var t0: float = degraus[i][2]
		var em_cima := zm > -0.46
		var mao_d := no_topo(0.32, zm, 0.01)
		var mao_e := no_topo(0.62, zm - 0.04, 0.01)
		e.passo(EscaladorDoCarro.MAO_D, t0, t0 + 0.2, mao_d, EscaladorDoCarro.Apoio.PONTA,
			Vector3(0.0, 0.08, 0.0), Vector3(-0.8, 0.6, 0.0), 0.35)
		e.passo(EscaladorDoCarro.MAO_E, t0 + 0.12, t0 + 0.32, mao_e, EscaladorDoCarro.Apoio.PONTA,
			Vector3(0.0, 0.08, 0.0), Vector3(0.8, 0.6, 0.0), 0.3)
		e.passo(EscaladorDoCarro.PE_D, t0 + 0.2, t0 + 0.42, no_topo(0.40, zj), EscaladorDoCarro.Apoio.JOELHO,
			Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.3, 1.0), 0.35)
		e.passo(EscaladorDoCarro.PE_E, t0 + 0.26, t0 + 0.46, no_topo(0.58, zj - 0.03),
			EscaladorDoCarro.Apoio.JOELHO, Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.3, 1.0), 0.35)
		var zq := zj - 0.36
		e.chave(t0 + 0.45, {"quadril": Vector3(0.48, 0.0, zq), "piso": topo(0.48, zj) - 0.02,
			"tronco": Vector3(-0.5 - 0.05 * float(i), 0.0, 0.0),
			"pelve": Vector3(-0.55 - 0.08 * float(i), 0.0, 0.0),
			"cabeca": Vector3(0.5 if not em_cima else 0.2, 0.0, 0.0)}, &"puxa")
	# 4: por cima da borda, no teto. As maos no teto, os joelhos na borda.
	e.passo(EscaladorDoCarro.MAO_D, 3.4, 3.62, no_topo(0.28, -0.12, 0.01), EscaladorDoCarro.Apoio.PONTA,
		Vector3(0.0, 0.12, 0.0), Vector3(-0.8, 0.6, 0.0), 0.55)
	e.passo(EscaladorDoCarro.MAO_E, 3.5, 3.72, no_topo(0.58, -0.15, 0.01), EscaladorDoCarro.Apoio.PONTA,
		Vector3(0.0, 0.12, 0.0), Vector3(0.8, 0.6, 0.0), 0.5)
	e.passo(EscaladorDoCarro.PE_D, 3.7, 3.98, no_topo(0.36, -0.42), EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.3, 1.0), 0.7)
	e.passo(EscaladorDoCarro.PE_E, 3.82, 4.08, no_topo(0.56, -0.43), EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.3, 1.0), 0.6)
	e.chave(4.05, {"quadril": Vector3(0.46, 0.0, -0.78), "piso": topo(0.46, -0.35) - 0.02,
		"tronco": Vector3(-0.9, 0.0, 0.0), "pelve": Vector3(-0.85, 0.0, 0.0),
		"cabeca": Vector3(0.2, 0.0, 0.0), "olha_peso": 0.0}, &"puxa")
	# 5: ajoelhado no teto, vira para a frente (frente 0) e bate as palmas no
	# teto: tres vezes, cada vez mais forte.
	e.chave(4.4, {"quadril": Vector3(0.28, 0.0, 0.1), "frente": 0.0, "piso": topo(0.3, 0.1),
		"tronco": Vector3(-0.25, 0.0, 0.0), "pelve": Vector3(-0.2, 0.0, 0.0),
		"cabeca": Vector3(-0.35, 0.0, 0.0)}, &"estalo")
	e.passo(EscaladorDoCarro.PE_D, 4.3, 4.55, no_topo(0.40, 0.3), EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.12, 0.0), Vector3(0.0, 0.0, -1.0), 0.5)
	e.passo(EscaladorDoCarro.PE_E, 4.36, 4.62, no_topo(0.16, 0.32), EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.12, 0.0), Vector3(0.0, 0.0, -1.0), 0.5)
	var bate := [4.75, 5.15, 5.45]
	for i in bate.size():
		var tb: float = bate[i]
		var forca := 0.7 + 0.15 * float(i)
		# Ergue os bracos e desce as duas palmas juntas na chapa.
		e.passo(EscaladorDoCarro.MAO_D, tb - 0.2, tb, no_topo(0.46, -0.16, 0.01),
			EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.42, 0.0), Vector3(0.8, 0.4, 0.0), forca)
		e.passo(EscaladorDoCarro.MAO_E, tb - 0.2, tb + 0.02, no_topo(0.1, -0.14, 0.01),
			EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.42, 0.0), Vector3(-0.8, 0.4, 0.0), forca)
		e.chave(tb - 0.12, {"tronco": Vector3(0.1, 0.0, 0.0), "cabeca": Vector3(0.3, 0.0, 0.0)},
			&"sai")
		e.chave(tb, {"tronco": Vector3(-0.55, 0.0, 0.0), "cabeca": Vector3(-0.5, 0.0, 0.0)},
			&"entra")
		e.evento(tb, func() -> void:
			var onde := no_topo(0.28, -0.15)
			_tocar(&"mao_lataria_2", onde, 2.0 + 2.0 * float(i), 0.62)
			_carro.pancada(0.05, 0.55 * forca))
	# 6: agachado na beira da frente do teto, a mao direita agarrada na borda de
	# cima do para-brisa: os dedos por dentro do vidro.
	e.chave(5.8, {"quadril": Vector3(0.18, 0.0, -0.02), "piso": topo(0.2, -0.1),
		"tronco": Vector3(-0.95, 0.0, 0.0), "pelve": Vector3(-0.6, 0.0, 0.0),
		"cabeca": Vector3(0.45, 0.0, 0.0), "olha": eye, "olha_peso": 0.7}, &"suave")
	e.passo(EscaladorDoCarro.MAO_D, 5.65, 5.9, no_topo(0.02, -0.475, 0.012),
		EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.15, 0.0), Vector3(0.5, 0.8, 0.0), 0.3)
	e.passo(EscaladorDoCarro.MAO_E, 5.7, 5.95, no_topo(0.42, -0.33, 0.01),
		EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.15, 0.0), Vector3(-0.5, 0.8, 0.0), 0.2)


## O de tras: pela tampa do porta-malas e pelo vidro de tras ate o teto.
func _pista_de_tras() -> void:
	var e := _tras
	var s := e.corpo.altura() / Corpo.ALTURA_REF
	var chao_tras := chao(Vector3(-0.1, 0.0, 2.6))
	e.chave(0.0, {"quadril": Vector3(-0.1, chao_tras + 0.9 * s, 2.62), "frente": 0.0,
		"tronco": Vector3(-0.2, 0.0, 0.0), "piso": chao_tras})
	e.pousar(EscaladorDoCarro.PE_E, Vector3(-0.26, chao_tras, 2.6), EscaladorDoCarro.Apoio.PE)
	e.pousar(EscaladorDoCarro.PE_D, Vector3(0.06, chao_tras, 2.66), EscaladorDoCarro.Apoio.PE)
	e.passo(EscaladorDoCarro.MAO_E, 1.1, 1.3, no_topo(-0.34, 1.85, 0.008), EscaladorDoCarro.Apoio.PONTA,
		Vector3(0.0, 0.2, 0.0), Vector3(-0.6, -0.4, 0.5), 0.5)
	e.passo(EscaladorDoCarro.MAO_D, 1.2, 1.4, no_topo(0.14, 1.82, 0.008), EscaladorDoCarro.Apoio.PONTA,
		Vector3(0.0, 0.2, 0.0), Vector3(0.6, -0.4, 0.5), 0.5)
	e.chave(1.4, {"quadril": Vector3(-0.1, chao_tras + 0.8 * s, 2.55),
		"tronco": Vector3(-0.8, 0.0, 0.0), "pelve": Vector3(-0.4, 0.0, 0.0)}, &"sai")
	_pesa(e, 1.3, 0.2, 0.3)
	e.passo(EscaladorDoCarro.PE_D, 1.55, 1.85, no_topo(0.04, 2.02), EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.3, 0.0), Vector3(0.0, -0.2, -1.0), 0.9)
	e.chave(1.9, {"quadril": Vector3(-0.1, 0.0, 2.35), "piso": topo(-0.1, 1.9),
		"tronco": Vector3(-0.9, 0.0, 0.0), "pelve": Vector3(-0.8, 0.0, 0.0)}, &"puxa")
	_pesa(e, 1.8, 0.8, 0.3)
	e.passo(EscaladorDoCarro.PE_E, 1.95, 2.2, no_topo(-0.26, 1.98), EscaladorDoCarro.Apoio.JOELHO,
		Vector3(0.0, 0.25, 0.0), Vector3(0.0, -0.2, -1.0), 0.7)
	_pesa(e, 2.1, 1.0, 0.3)
	var degraus := [[1.35, 1.72, 2.4], [1.02, 1.42, 2.85], [0.62, 1.05, 3.35]]
	for i in degraus.size():
		var zm: float = degraus[i][0]
		var zj: float = degraus[i][1]
		var t0: float = degraus[i][2]
		e.passo(EscaladorDoCarro.MAO_E, t0, t0 + 0.22, no_topo(-0.36, zm, 0.01),
			EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.1, 0.0), Vector3(-0.8, 0.6, 0.0), 0.4)
		e.passo(EscaladorDoCarro.MAO_D, t0 + 0.1, t0 + 0.32, no_topo(0.14, zm + 0.03, 0.01),
			EscaladorDoCarro.Apoio.PONTA, Vector3(0.0, 0.1, 0.0), Vector3(0.8, 0.6, 0.0), 0.4)
		e.passo(EscaladorDoCarro.PE_E, t0 + 0.2, t0 + 0.44, no_topo(-0.24, zj),
			EscaladorDoCarro.Apoio.JOELHO, Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.3, -1.0), 0.45)
		e.passo(EscaladorDoCarro.PE_D, t0 + 0.26, t0 + 0.5, no_topo(0.02, zj + 0.02),
			EscaladorDoCarro.Apoio.JOELHO, Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.3, -1.0), 0.45)
		e.chave(t0 + 0.48, {"quadril": Vector3(-0.1, 0.0, zj + 0.38), "piso": topo(-0.1, zj) - 0.02,
			"tronco": Vector3(-0.6, 0.0, 0.0), "pelve": Vector3(-0.7, 0.0, 0.0)}, &"puxa")
	# Ajoelhado no teto de tras: murros na chapa.
	for tb: float in [4.15, 4.62, 5.05, 5.4]:
		var mao := EscaladorDoCarro.MAO_D if int(tb * 10.0) % 2 == 0 else EscaladorDoCarro.MAO_E
		var x := 0.12 if mao == EscaladorDoCarro.MAO_D else -0.32
		e.passo(mao, tb - 0.2, tb, no_topo(x, 0.35, 0.01), EscaladorDoCarro.Apoio.PUNHO,
			Vector3(0.0, 0.45, 0.0), Vector3(0.0, 0.3, 1.0), 0.9)
		e.evento(tb, func() -> void:
			_tocar(&"mao_lataria_4", no_topo(x, 0.35), 3.0, 0.55)
			_carro.pancada(0.12, 0.08 * signf(x)))


## A cabecada `golpe` com o impacto em `ate` segundos: recua, segura, cai.
func _pista_da_cabecada(golpe: int, ate: float) -> void:
	var e := _capo
	var agora := e.continuar_de_agora()
	var base := _pose_no_vidro()
	var alvo: Vector2 = PONTOS_DA_TESTA[mini(golpe, PONTOS_DA_TESTA.size() - 1)]
	var ponto := _ponto_no_parabrisa(alvo)
	var golpe_dur := minf(0.12, ate)
	var t_bate := agora + ate
	e.soltar_cabeca()
	if ate > golpe_dur + 0.12:
		# O recuo: o tronco sobe e vai para tras, a cabeca joga para tras. Devagar,
		# e depois segura um instante la em cima.
		var recua := ate - golpe_dur
		var sobe := base.duplicate()
		sobe["quadril"] = (base["quadril"] as Vector3) + Vector3(0.0, 0.0, -0.14)
		sobe["tronco"] = Vector3(-0.2, 0.0, 0.0)
		sobe["pelve"] = Vector3(-0.8, 0.0, 0.0)
		sobe["cabeca"] = Vector3(0.45, 0.0, 0.15 * (1.0 if golpe % 2 == 0 else -1.0))
		sobe["olha_peso"] = 0.35
		e.chave(agora + recua * 0.78, sobe, &"puxa")
		e.chave(agora + recua, sobe, &"linear")
	# O contato: a testa no plano do vidro, o queixo recolhido (a testa na frente).
	var bate := base.duplicate()
	bate["tronco"] = Vector3(-0.98, 0.0, 0.0)
	bate["pelve"] = Vector3(-1.0, 0.0, 0.0)
	bate["cabeca"] = Vector3(-0.42, 0.0, 0.0)
	bate["olha"] = ponto + Vector3(0.0, -0.25, 0.3)
	bate["olha_peso"] = 1.0
	bate["quadril"] = (base["quadril"] as Vector3) + Vector3(0.0, 0.0, 0.06)
	e.chave(t_bate, bate, &"entra")
	# Ajusta o quadril ate a testa cair no ponto do vidro (duas voltas bastam).
	for volta in 3:
		var testa := _testa_em(e, t_bate)
		var falta := ponto - testa.origin
		# So o que falta ao longo da normal do vidro e no plano dele; o quadril
		# leva o corpo junto.
		bate["quadril"] = (bate["quadril"] as Vector3) + falta
		e.trocar_ultima_chave(bate)
	var testa_final := _testa_em(e, t_bate)
	var n := (_parabrisa().get("normal", Vector3(0, 0.75, -0.66)) as Vector3).normalized()
	var fundo := n.dot(testa_final.origin - ponto)
	print("[cerco] cabecada %d em %.2f s: testa a %.1f mm do vidro" % [golpe, ate, fundo * 1000.0])
	# O repique: volta dois dedos e cai de novo, e o rosto fica colado, descendo.
	var repica := bate.duplicate()
	repica["quadril"] = (bate["quadril"] as Vector3) + n * 0.035
	repica["cabeca"] = Vector3(-0.2, 0.0, 0.2)
	e.chave(t_bate + 0.07, repica, &"sai")
	var cola := bate.duplicate()
	cola["quadril"] = (bate["quadril"] as Vector3) - n * 0.004
	e.chave(t_bate + 0.15, cola, &"entra")
	var desce := cola.duplicate()
	var escorre := Vector3(0.0, -0.055, -0.055 * n.y / maxf(absf(n.z), 0.1))
	desce["quadril"] = (cola["quadril"] as Vector3) + escorre
	desce["cabeca"] = Vector3(-0.3, 0.0, 0.45 * (1.0 if golpe % 2 == 0 else -1.0))
	e.chave(t_bate + 0.9, desce, &"suave")
	e.evento(t_bate, func() -> void:
		# Colado no vidro o tique so treme: um estalo grande tiraria a cara dali.
		e.tique = 0.3
		_contato_da_testa(golpe, ponto, n))
	e.evento(t_bate + 0.16, func() -> void:
		if _sangue != null:
			_sangue.arrastar(ponto, ponto + escorre * 0.9, 0.75))


## A testa de `e` em `tt` (espaco do carro), sem mexer no relogio.
func _testa_em(e: EscaladorDoCarro, tt: float) -> Transform3D:
	var antes := e.t
	e.t = tt
	e.resolver()
	var tf := e.testa()
	e.t = antes
	e.resolver()
	return tf


## A testa bateu: o som, a teia, o sangue e o tranco.
func _contato_da_testa(golpe: int, ponto: Vector3, n: Vector3) -> void:
	var forca := clampf(0.7 + 0.12 * float(golpe), 0.0, 1.0)
	var nome := StringName("cabecada_vidro_%d" % mini(golpe + 1, 3))
	if AudioDirector.stream(nome) == null:
		nome = &"tapa_vidro"
	_tocar(nome, ponto + n * 0.05, float(CABECADA_DB[mini(golpe, CABECADA_DB.size() - 1)]),
		randf_range(0.94, 1.02))
	_tocar(&"vidro_trinca", ponto, -8.0 + 3.0 * float(golpe), 0.7 + 0.05 * float(golpe))
	_carro.pancada(CABECADA_TRANCO.x * forca, CABECADA_TRANCO.y * forca * signf(ponto.x))
	if golpe < _teias.size() and _teias[golpe] != null:
		var tr := _teias[golpe]
		tr.visible = true
		var tw := create_tween()
		tw.tween_method(tr.por_cresce, 0.0, 0.62, 0.09).set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_EXPO)
		tw.tween_method(tr.por_cresce, 0.62, 0.9, 1.6).set_ease(Tween.EASE_IN_OUT) \
			.set_trans(Tween.TRANS_SINE)
	# As teias de antes andam mais um pouco com a pancada.
	for g in mini(golpe, _teias.size()):
		if _teias[g] != null:
			_teias[g].crescer(1.0, 0.25)
	if _sangue != null:
		_sangue.golpe(ponto, forca)
	_estalar(_capo, 0.9)


# --- a sonda ----------------------------------------------------------------

## `--cerco-sonda`: o quanto os pontos que tocam (ponta dos dedos, joelho,
## bico) entraram na lataria, o pior de cada um por segundo.
func _sondar(delta: float) -> void:
	for e: EscaladorDoCarro in _todos:
		var pontas := e.pontas()
		for m in pontas.size():
			for p: Vector3 in pontas[m]:
				if absf(p.x) > 0.8 or p.z < -2.15 or p.z > 2.15:
					continue
				var fundo := topo(p.x, p.z) - p.y
				var chave := "%s/%d" % [e.nome, m]
				if fundo > float(_sonda_pior.get(chave, -1.0)):
					_sonda_pior[chave] = fundo
	_sonda_t += delta
	if _sonda_t >= 1.0:
		_sonda_t = 0.0
		var linha := ""
		for chave: String in _sonda_pior:
			if float(_sonda_pior[chave]) > 0.005:
				linha += " %s=%.1fcm" % [chave, float(_sonda_pior[chave]) * 100.0]
		print("[cerco-sonda] t=%.1f dentro:%s" % [_relogio, linha if not linha.is_empty() else " nada"])
		_sonda_pior.clear()

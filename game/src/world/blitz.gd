## Uma blitz montada na pista: funil de cones, viatura no acostamento,
## oficiais e coreografia de fiscalizacao (frear, inspecionar, estacionar,
## motorista a pe, liberar).
##
## Convencao local: -Z aponta na direcao do fluxo (Basis.looking_at); +Z local
## e montante (carros chegam pelo +Z). +X aponta para o meio-fio da faixa de
## fora. O BlitzManager posiciona e gira este no no mundo.
class_name Blitz
extends Node3D

const COMPRIMENTO_FUNIL := 18.0
const LARGURA_INSPCAO := 2.2
## Chance percentual de um carro ser selecionado para parar (deterministico).
const CHANCE_PARAR := 22
const GIROFLEX_PERIODO := 0.28

## Fases da inspecao cinematica (um carro por vez).
enum Fase {
	OCIOSA,
	FREANDO,
	OFICIAL_ANDANDO,
	NA_JANELA,
	ESTACIONANDO,
	MOTORISTA_DESCE,
	CONVERSA,
	MOTORISTA_SOBE,
	LIBERADO,
}

## Identidade estavel desta blitz (semente de spawn).
var id_blitz: int = 0
## Trecho de via onde esta plantada.
var trecho := Vector4i.ZERO
var de := Vector2i.ZERO
var para := Vector2i.ZERO

var _t: float = 0.0
var _giroflex: Node3D
var _ponto_parada := Vector3.ZERO
var _faixa_inspcao: int = 0
var _via: int = MalhaUrbana.Via.AVENIDA
## Distancia local +X do centro da faixa 0 ate o centro do acostamento.
var _x_acost: float = 2.4
## Borda do meio-fio em +X local (fim do asfalto).
var _x_meio_fio: float = 3.3

var _fase: int = Fase.OCIOSA
var _fase_t: float = 0.0
var _carro_insp: Carro = null
var _oficial: Corpo = null
var _oficial_posto := Vector3.ZERO
var _motorista: Corpo = null
var _semente_insp: int = 0


## Consulta usada pela IA do Carro. Devolve dicionario vazio ou:
##   parar  bool   — frear ate zero no funil
##   teto   float  — teto de velocidade m/s
##   faixa  int    — faixa sugerida (-1 = nao muda)
##   eixo   int    — eixo da via da blitz
##   mira   Vector3 — ponto de mira (parado ou desvio)
##   fase   int    — Fase da inspecao se este carro e o inspecionado
##   ocultar_motorista bool — carro sem motorista a pe
static func efeito(carro: Carro) -> Dictionary:
	if carro == null or not is_instance_valid(carro):
		return {}
	var info := BlitzManager.consulta(carro.global_position, carro.trecho, carro.semente)
	if info.is_empty():
		return {}
	var b: Blitz = info["blitz"]
	var parar: bool = bool(info["parar"])
	# Quem nao para muda para a faixa de dentro (1) se a via tiver.
	var faixa := -1
	if not parar:
		var via := (MalhaUrbana.via_x(b.de.x) if b.trecho.z == 0
			else MalhaUrbana.via_z(b.de.y))
		if Vias.faixas(via) > 1:
			faixa = 1
	var out := {
		"blitz": b,
		"parar": parar,
		"teto": float(info["teto"]),
		"faixa": faixa,
		"eixo": b.trecho.z,
		"mira": info["mira"],
		"fase": -1,
		"ocultar_motorista": false,
	}
	# Coreografia: se este carro e o da inspecao, a blitz manda.
	if b._carro_insp == carro and b._fase != Fase.OCIOSA:
		out["fase"] = b._fase
		out["parar"] = true
		out["mira"] = b._mira_inspecao(carro)
		out["teto"] = b._teto_inspecao()
		out["ocultar_motorista"] = b._fase in [
			Fase.MOTORISTA_DESCE, Fase.CONVERSA, Fase.MOTORISTA_SOBE]
	return out


func montar(semente: int, t: Dictionary) -> void:
	id_blitz = semente
	trecho = t["trecho"]
	de = t["de"]
	para = t["para"]
	_faixa_inspcao = 0  # faixa de fora (meio-fio), onde a blitz funila
	_via = (MalhaUrbana.via_x(de.x) if trecho.z == 0 else MalhaUrbana.via_z(de.y))
	_calcular_acostamento()
	_montar_zebrado()
	_montar_cones()
	_montar_placas()
	_montar_bollard()
	_montar_viatura(semente)
	_montar_oficiais(semente)
	_montar_encostados(semente)
	# Ponto de parada: meio do funil, na faixa de inspecao (x~0).
	_ponto_parada = Vector3(0.0, 0.0, COMPRIMENTO_FUNIL * 0.55)
	set_process(true)


## Centro do acostamento e meio-fio em +X local, a partir da geometria da via.
## Origem da blitz = centro da faixa 0; meio-fio fica a (meia_asfalto - offset_faixa0).
func _calcular_acostamento() -> void:
	var meia := MalhaUrbana.meia_pista(_via)
	var est := MalhaUrbana.largura_estacionamento(_via)
	var n := maxi(1, Vias.faixas(_via))
	var largura_faixa := meia / float(n)
	# Distancia do centro da faixa 0 ate a borda do rolamento (inicio do acost).
	var ate_borda_pista := largura_faixa * 0.5
	_x_meio_fio = ate_borda_pista + est
	# Centro do estacionamento; viatura fica um pouco alem (2 rodas no meio-fio).
	_x_acost = ate_borda_pista + est * 0.42


func _process(delta: float) -> void:
	_t += delta
	_tick_giroflex()
	_tick_inspecao(delta)


func _tick_giroflex() -> void:
	if _giroflex == null:
		return
	var fase := int(floor(_t / GIROFLEX_PERIODO)) % 2
	var r: OmniLight3D = _giroflex.get_node_or_null("R") as OmniLight3D
	var b: OmniLight3D = _giroflex.get_node_or_null("B") as OmniLight3D
	if r != null:
		r.light_energy = 4.2 if fase == 0 else 0.15
	if b != null:
		b.light_energy = 4.2 if fase == 1 else 0.15


## O carro nesta posicao/trecho esta dentro da zona de influencia?
func influencia(pos_mundo: Vector3, trecho_carro: Vector4i) -> bool:
	if trecho_carro.z != trecho.z or trecho_carro.w != trecho.w:
		return false
	var local := to_local(pos_mundo)
	if local.z < -4.0 or local.z > COMPRIMENTO_FUNIL + 8.0:
		return false
	if absf(local.x) > 7.5:
		return false
	return true


## Este carro deve parar no funil? Deterministico por (blitz, semente do carro).
func selecionado_para_parar(semente_carro: int) -> bool:
	var h := absi(id_blitz * 2654435761 ^ semente_carro * 40503) % 100
	return h < CHANCE_PARAR


## Ponto mundial onde o selecionado deve frear.
func ponto_de_parada() -> Vector3:
	return to_global(_ponto_parada)


## Mira lateral para quem NAO para: a frente na faixa interna (sem orbitar).
func mira_desvio(pos_mundo: Vector3) -> Vector3:
	var local := to_local(pos_mundo)
	# Alvo sempre a FRENTE (z menor que o carro que vem pelo +Z indo a -Z...
	# Carros andam no sentido -Z local. Chegam com z alto, saem com z baixo.
	# Mira a frente = z um pouco menor que o atual, na faixa interna (-X).
	var z_frente := local.z - 8.0
	var alvo := Vector3(-2.4, 0.0, z_frente)
	return to_global(alvo)


## Teto de velocidade sugerido na zona (m/s).
func teto_na_zona(pos_mundo: Vector3, deve_parar: bool) -> float:
	var local := to_local(pos_mundo)
	if deve_parar:
		var d := local.distance_to(_ponto_parada)
		if d < 3.5:
			return 0.0
		if local.z < _ponto_parada.z + 1.0 and local.z > _ponto_parada.z - 6.0:
			# Passou ou esta no ponto: parado (fluxo -Z: z diminui).
			if local.z <= _ponto_parada.z + 0.8:
				return 0.0
		return 3.5
	# Quem desvia passa lento pelo funil.
	if local.z > 0.0 and local.z < COMPRIMENTO_FUNIL:
		return 5.0
	return 8.0


## BlitzManager chama a cada consulta: tenta puxar um carro parado para a FSM.
func tentar_iniciar_inspecao(carro: Carro, deve_parar: bool) -> void:
	if not deve_parar or carro == null:
		return
	if _fase != Fase.OCIOSA:
		return
	if _carro_insp != null and is_instance_valid(_carro_insp):
		return
	var local := to_local(carro.global_position)
	if local.distance_to(_ponto_parada) > 4.0:
		return
	# Quase parado.
	if absf(float(carro.get("_velocidade"))) > 0.55:
		return
	_carro_insp = carro
	_semente_insp = carro.semente
	_fase = Fase.FREANDO
	_fase_t = 0.0


func _mira_inspecao(carro: Carro) -> Vector3:
	match _fase:
		Fase.FREANDO, Fase.OFICIAL_ANDANDO, Fase.NA_JANELA:
			# Olhar para frente, nao para o ponto (evita spinning).
			var frente := -global_transform.basis.z
			return carro.global_position + frente * 4.0
		Fase.ESTACIONANDO:
			return to_global(Vector3(_x_acost, 0.0, COMPRIMENTO_FUNIL * 0.78))
		Fase.MOTORISTA_DESCE, Fase.CONVERSA, Fase.MOTORISTA_SOBE:
			return carro.global_position - global_transform.basis.z * 2.0
		Fase.LIBERADO:
			return carro.global_position - global_transform.basis.z * 10.0
		_:
			return ponto_de_parada()


func _teto_inspecao() -> float:
	match _fase:
		Fase.FREANDO, Fase.OFICIAL_ANDANDO, Fase.NA_JANELA:
			return 0.0
		Fase.ESTACIONANDO:
			return 2.8
		Fase.MOTORISTA_DESCE, Fase.CONVERSA, Fase.MOTORISTA_SOBE:
			return 0.0
		Fase.LIBERADO:
			return 6.0
		_:
			return 0.0


func _tick_inspecao(delta: float) -> void:
	if _fase == Fase.OCIOSA:
		return
	_fase_t += delta
	if _carro_insp == null or not is_instance_valid(_carro_insp):
		_abortar_inspecao()
		return

	match _fase:
		Fase.FREANDO:
			if _fase_t > 1.2:
				_fase = Fase.OFICIAL_ANDANDO
				_fase_t = 0.0
		Fase.OFICIAL_ANDANDO:
			_mover_oficial_ate_janela(delta)
			if _fase_t > 2.8:
				_fase = Fase.NA_JANELA
				_fase_t = 0.0
				if _oficial != null:
					_oficial.animar(0.0, delta)
		Fase.NA_JANELA:
			if _oficial != null:
				_oficial.animar(0.0, delta)
				# Olha para o carro.
				var para := _carro_insp.global_position - _oficial.global_position
				para.y = 0.0
				if para.length() > 0.1:
					_oficial.rotation.y = atan2(-para.x, -para.z)
			if _fase_t > 2.4:
				_fase = Fase.ESTACIONANDO
				_fase_t = 0.0
				_devolver_oficial_ao_posto()
		Fase.ESTACIONANDO:
			_devolver_oficial_ao_posto()
			var alvo := to_global(Vector3(_x_acost, 0.0, COMPRIMENTO_FUNIL * 0.78))
			if _carro_insp.global_position.distance_to(alvo) < 2.2 or _fase_t > 5.0:
				_fase = Fase.MOTORISTA_DESCE
				_fase_t = 0.0
				_spawn_motorista()
		Fase.MOTORISTA_DESCE:
			_animar_motorista_desce(delta)
			if _fase_t > 1.6:
				_fase = Fase.CONVERSA
				_fase_t = 0.0
				_posicionar_conversa()
		Fase.CONVERSA:
			if _motorista != null:
				_motorista.animar(0.0, delta)
			if _oficial != null:
				_oficial.animar(0.0, delta)
			if _fase_t > 3.2:
				_fase = Fase.MOTORISTA_SOBE
				_fase_t = 0.0
		Fase.MOTORISTA_SOBE:
			_animar_motorista_sobe(delta)
			if _fase_t > 1.4:
				_fase = Fase.LIBERADO
				_fase_t = 0.0
				_limpar_motorista()
		Fase.LIBERADO:
			if _fase_t > 2.5:
				_carro_insp = null
				_fase = Fase.OCIOSA
				_fase_t = 0.0


func _mover_oficial_ate_janela(delta: float) -> void:
	if _oficial == null or _carro_insp == null:
		return
	# Janela do motorista: lado do meio-fio (+X local), ao lado do carro.
	var local_carro := to_local(_carro_insp.global_position)
	var alvo_local := Vector3(local_carro.x + 1.35, 0.0, local_carro.z + 0.4)
	var alvo := to_global(alvo_local)
	var pos := _oficial.global_position
	var para := alvo - pos
	para.y = 0.0
	var dist := para.length()
	if dist < 0.08:
		_oficial.animar(0.0, delta)
		return
	var passo := minf(1.55 * delta, dist)
	_oficial.global_position = pos + para.normalized() * passo
	_oficial.rotation.y = atan2(-para.x, -para.z)
	_oficial.animar(1.55, delta)


func _devolver_oficial_ao_posto() -> void:
	if _oficial == null:
		return
	_oficial.position = _oficial_posto
	_oficial.rotation.y = PI


func _spawn_motorista() -> void:
	_limpar_motorista()
	if _carro_insp == null:
		return
	_motorista = Corpo.new()
	_motorista.name = "MotoristaInsp"
	var ficha := {
		"id": absi(_semente_insp * 17),
		"sexo": &"M" if (_semente_insp % 2) == 0 else &"F",
		"idade": 22 + absi(_semente_insp) % 40,
	}
	_motorista.montar(Aparencia.de_ficha(ficha))
	var local_c := to_local(_carro_insp.global_position)
	_motorista.position = Vector3(local_c.x + 1.1, 0.0, local_c.z)
	add_child(_motorista)


func _animar_motorista_desce(delta: float) -> void:
	if _motorista == null or _carro_insp == null:
		return
	var local_c := to_local(_carro_insp.global_position)
	var alvo := to_global(Vector3(_x_acost - 0.3, 0.0, local_c.z + 1.2))
	# Oficial ja no posto do acostamento: motorista anda ate ele.
	if _oficial != null:
		alvo = _oficial.global_position + (-global_transform.basis.x) * 0.9
	var para := alvo - _motorista.global_position
	para.y = 0.0
	if para.length() > 0.1:
		_motorista.global_position += para.normalized() * minf(1.4 * delta, para.length())
		_motorista.rotation.y = atan2(-para.x, -para.z)
		_motorista.animar(1.4, delta)
	else:
		_motorista.animar(0.0, delta)


func _posicionar_conversa() -> void:
	if _motorista == null or _oficial == null:
		return
	var meio := (_oficial.global_position + _motorista.global_position) * 0.5
	var para_o := meio - _oficial.global_position
	para_o.y = 0.0
	if para_o.length() > 0.05:
		_oficial.rotation.y = atan2(-para_o.x, -para_o.z)
	var para_m := meio - _motorista.global_position
	para_m.y = 0.0
	if para_m.length() > 0.05:
		_motorista.rotation.y = atan2(-para_m.x, -para_m.z)
	_oficial.falar(true)
	_motorista.falar(true)


func _animar_motorista_sobe(delta: float) -> void:
	if _motorista == null or _carro_insp == null:
		return
	if _oficial != null:
		_oficial.falar(false)
	_motorista.falar(false)
	var alvo := _carro_insp.global_position + global_transform.basis.x * 1.0
	var para := alvo - _motorista.global_position
	para.y = 0.0
	if para.length() > 0.15:
		_motorista.global_position += para.normalized() * minf(1.5 * delta, para.length())
		_motorista.rotation.y = atan2(-para.x, -para.z)
		_motorista.animar(1.5, delta)
	else:
		_motorista.animar(0.0, delta)


func _limpar_motorista() -> void:
	if _motorista != null and is_instance_valid(_motorista):
		_motorista.queue_free()
	_motorista = null


func _abortar_inspecao() -> void:
	_limpar_motorista()
	_devolver_oficial_ao_posto()
	_carro_insp = null
	_fase = Fase.OCIOSA
	_fase_t = 0.0


func _colisao_caixa(centro: Vector3, tamanho: Vector3) -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tamanho
	shape.shape = box
	corpo.add_child(shape)
	corpo.position = centro
	add_child(corpo)


func _montar_zebrado() -> void:
	# Pintura local do acostamento ao longo do funil (reforca a da malha).
	var raiz := KitBlitz.zebrado_acostamento(COMPRIMENTO_FUNIL + 6.0, 2.0)
	raiz.position = Vector3(_x_acost - 0.15, 0.02, COMPRIMENTO_FUNIL * 0.35)
	add_child(raiz)


func _montar_cones() -> void:
	var n := 7
	for i in n:
		var t := float(i) / float(n - 1)
		var z := 1.5 + t * (COMPRIMENTO_FUNIL - 3.0)
		# Fecha o funil na faixa de inspecao (perto de x=0), abrindo para -X.
		var x := lerpf(-2.6, 0.7, t)
		var c := KitBlitz.cone_transito()
		c.position = Vector3(x, 0.68, z)
		add_child(c)
		_colisao_caixa(Vector3(x, 0.35, z), Vector3(0.4, 0.7, 0.4))
	# Fileira no acostamento (nao atravessar).
	for i in 4:
		var c2 := KitBlitz.cone_transito()
		var z2 := 4.0 + float(i) * 3.5
		c2.position = Vector3(_x_meio_fio - 0.25, 0.68, z2)
		add_child(c2)
		_colisao_caixa(Vector3(_x_meio_fio - 0.25, 0.35, z2), Vector3(0.4, 0.7, 0.4))


func _montar_placas() -> void:
	for z: float in [2.0, 10.0]:
		var p := KitBlitz.placa()
		p.position = Vector3(1.4, 0.0, z)
		add_child(p)


func _montar_bollard() -> void:
	var b := KitBlitz.bollard()
	b.position = Vector3(_x_meio_fio + 0.15, 0.0, 3.0)
	add_child(b)


func _montar_viatura(semente: int) -> void:
	var viatura := Node3D.new()
	viatura.name = "Viatura"
	var medidas := Carroceria.montar(Carroceria.Modelo.SEDA, Color(0.92, 0.92, 0.94), semente)
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"]
	lataria.material_override = load(Carroceria.MATERIAL)
	lataria.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viatura.add_child(lataria)
	var luzes := MeshInstance3D.new()
	luzes.mesh = medidas["luzes"]
	luzes.material_override = load(Carroceria.MATERIAL_LUZ)
	luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viatura.add_child(luzes)
	# ~2 rodas no meio-fio: centro no acostamento, levemente alem, inclinada.
	viatura.position = Vector3(_x_acost + 0.15, 0.08, COMPRIMENTO_FUNIL * 0.35)
	viatura.rotation.y = PI + 0.18  # contra o fluxo, levemente de viés
	viatura.rotation.z = -0.06  # tombada para o meio-fio (Blitz real)
	add_child(viatura)
	_colisao_caixa(viatura.position + Vector3(0.0, 0.7, 0.0), Vector3(1.8, 1.4, 4.4))
	_giroflex = KitBlitz.giroflex()
	_giroflex.position = Vector3(0.0, float(medidas["altura"]) + 0.05, 0.0)
	viatura.add_child(_giroflex)


func _montar_oficiais(semente: int) -> void:
	_oficial_posto = Vector3(0.55, 0.0, COMPRIMENTO_FUNIL * 0.55)
	var postos: Array[Vector3] = [
		_oficial_posto,
		Vector3(_x_acost - 0.3, 0.0, COMPRIMENTO_FUNIL * 0.4),
		Vector3(_x_acost + 0.2, 0.0, COMPRIMENTO_FUNIL * 0.62),
	]
	for i in postos.size():
		var corp := Corpo.new()
		corp.name = "Oficial_%d" % i
		corp.montar(_aparencia_pm(semente + i * 97))
		corp.position = postos[i]
		corp.rotation.y = PI if i == 0 else -PI * 0.5
		add_child(corp)
		if i == 0:
			_oficial = corp


func _montar_encostados(semente: int) -> void:
	for i in 2:
		var seed_c := semente + 500 + i * 131
		var modelo: Carroceria.Modelo = (
			Carroceria.Modelo.HATCH if i == 0 else Carroceria.Modelo.SEDA)
		var tinta: Color = Carroceria.TINTAS[absi(seed_c * 7919) % Carroceria.TINTAS.size()]
		var medidas := Carroceria.montar(modelo, tinta, seed_c)
		var no := Node3D.new()
		no.name = "Encostado_%d" % i
		var lataria := MeshInstance3D.new()
		lataria.mesh = medidas["corpo"]
		lataria.material_override = load(Carroceria.MATERIAL)
		lataria.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(lataria)
		var luzes := MeshInstance3D.new()
		luzes.mesh = medidas["luzes"]
		luzes.material_override = load(Carroceria.MATERIAL_LUZ)
		luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(luzes)
		# No acostamento, nao na calcada.
		no.position = Vector3(_x_acost - 0.05, 0.05,
			COMPRIMENTO_FUNIL * 0.72 + float(i) * 5.2)
		no.rotation.y = PI * 0.06 * (1 if i == 0 else -1)
		add_child(no)
		_colisao_caixa(no.position + Vector3(0.0, 0.7, 0.0), Vector3(1.7, 1.3, 4.0))


## Uniforme PM legivel em escala PSX: calca cinza, colete neon, bone branco.
static func _aparencia_pm(semente: int) -> Dictionary:
	var base := Aparencia.de_ficha({
		"id": absi(semente),
		"sexo": &"M",
		"idade": 28 + absi(semente) % 20,
	})
	base["casaco"] = true
	base["casaco_cor"] = Color(0.78, 0.92, 0.12)
	base["casaco_cel"] = 0
	base["camisa_cor"] = Color(0.45, 0.48, 0.5)
	base["calca_cor"] = Color(0.4, 0.42, 0.45)
	base["chapeu"] = true
	base["chapeu_cor"] = Color(0.95, 0.95, 0.93)
	base["chapeu_tipo"] = 1
	base["sapato_cor"] = Color(0.12, 0.12, 0.12)
	return base

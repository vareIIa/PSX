## O tombo de quem nao e pedestre: o PM da blitz, o cliente do iWeed, o
## convidado da festa. A mesma fisica do `Pedestre` (ver `Equilibrio` e
## `BonecoDePano`) num componente que se pendura em qualquer `Corpo`:
##
## - carro rapido derruba (boneco de pano, perfil de sedan, tranco no carro);
## - carro devagar e esbarrao do jogador correndo fazem tropecar;
## - de pe de novo, a pessoa sente onde bateu (mao no lugar, ou manca) e reage
##   com raiva — quem apanha de carro parado na blitz nao agradece.
##
## Quem anda o corpo e o `dono` (o no que tem a posicao da pessoa). Se o dono e
## o proprio Corpo, o passo do tropeco e dado aqui; se e um CharacterBody3D com
## laco proprio (o convidado), o dono pede `passo(delta)` e anda com ele.
## Enquanto `ocupado()`, o dono nao move nem anima a pose por cima.
class_name TomboDeCorpo
extends Node

signal caiu()
signal levantou(onde: Vector3, rumo: float)

const MASSA := 70.0
const CARRO_EMPURRA := 3.4
const PARA_CHOQUE := 0.5
const ESBARRAO_MINIMO := 1.3
const ESPERA := 0.8
const CONTATO := 0.62

var corpo: Corpo
var dono: Node3D
var sentir_esbarrao := true
## A capsula da pessoa (se ela tem uma), desligada enquanto esta no chao.
var colisao: CollisionObject3D
## Carros que encostam sem empurrar (recebe o carro, devolve true): o PM na
## janela fica a dez centimetros da lataria, e o carro liberado arrancando nao
## e atropelo. Batida rapida continua derrubando.
var poupar: Callable

var _equilibrio: Equilibrio
var _boneco: BonecoDePano
var _desde := 9.0
var _de_onde := Vector3.ZERO
var _jogador: CharacterBody3D
var _camada_antes := 0
var _t_manca := 0.0
var _rapidez := 0.0


## Pendura o tombo em `quem`. `dono` e quem tem a posicao (padrao: o proprio
## corpo).
static func ligar(quem: Corpo, dono_: Node3D = null, esbarrao := true) -> TomboDeCorpo:
	var t := TomboDeCorpo.new()
	t.name = "TomboDeCorpo"
	t.corpo = quem
	t.dono = dono_ if dono_ != null else quem
	t.sentir_esbarrao = esbarrao
	for filho in quem.get_children():
		if filho is CollisionObject3D:
			t.colisao = filho
	t.dono.add_child(t)
	return t


## O tombo pendurado neste corpo, se houver.
static func de(quem: Corpo) -> TomboDeCorpo:
	if quem == null or not is_instance_valid(quem):
		return null
	var dono_ := quem if quem.has_node(^"TomboDeCorpo") else quem.get_parent()
	return dono_.get_node_or_null(^"TomboDeCorpo") as TomboDeCorpo if dono_ != null else null


## Rapidez do passo de tropeco agora, para o `animar` do dono.
func rapidez() -> float:
	return _rapidez


func caido() -> bool:
	return _boneco != null


func tropecando() -> bool:
	return _equilibrio != null


## Caido ou tropecando: o dono nao anda nem gira a pessoa.
func ocupado() -> bool:
	return caido() or tropecando()


## O passo do tropeco (m/s no plano) para um dono que anda sozinho.
func passo(delta: float) -> Vector3:
	if _equilibrio == null:
		return Vector3.ZERO
	var pe := _equilibrio.passo(delta)
	_rapidez = Vector2(pe.x, pe.z).length()
	_desenhar()
	if _equilibrio.caiu():
		var v := _equilibrio.velocidade_3d() + pe
		_equilibrio = null
		derrubar(v, Vector3.ZERO, 0.35)
		return Vector3.ZERO
	if not _equilibrio.ativo():
		_equilibrio = null
		_rapidez = 0.0
		_desenhar()
		_encarar(_de_onde)
		corpo.reagir(ReacaoCorpo.REACAO_XINGA)
	return Vector3(pe.x, 0.0, pe.z)


func _physics_process(delta: float) -> void:
	if corpo == null or not is_instance_valid(corpo) or dono == null:
		return
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	_desde += delta
	if _t_manca > 0.0:
		_t_manca -= delta
		corpo.mancando = minf(corpo.mancando, clampf(_t_manca / 4.0, 0.0, 1.0))
	if _boneco != null:
		return
	if not corpo.is_visible_in_tree():
		return
	var bate := Atropelo.quem_bate(get_tree(), dono.global_position, Vector3.ZERO, 0.28, delta)
	if not bate.is_empty():
		_ser_atingido(bate["carro"], bate["rel"], bate["vc"])
	elif sentir_esbarrao:
		_sentir_esbarrao()
	# Dono que nao anda sozinho: o passo e dado aqui mesmo.
	if _equilibrio != null and not dono is CharacterBody3D:
		dono.global_position += passo(delta) * delta


func empurrar(dv: Vector3, de_onde: Vector3) -> void:
	if _boneco != null:
		return
	dv.y = 0.0
	if _equilibrio == null:
		_equilibrio = Equilibrio.new(corpo.altura())
	_equilibrio.empurrar(dv)
	_de_onde = de_onde


func derrubar(vel: Vector3, golpe: Vector3, pancada: float) -> void:
	if _boneco != null:
		return
	_equilibrio = null
	corpo.inclinacao = Vector2.ZERO
	corpo.debater = 0.0
	corpo.rumo_passo = 0.0
	corpo.reagir(0)
	if colisao != null:
		_camada_antes = colisao.collision_layer
		colisao.collision_layer = 0
	var ignorar: Array = []
	if colisao != null:
		ignorar.append(colisao)
	_boneco = BonecoDePano.derrubar(corpo, vel, golpe, PARA_CHOQUE, pancada, ignorar)
	_boneco.levantou.connect(_ao_levantar, CONNECT_ONE_SHOT)
	caiu.emit()


func _ser_atingido(carro: Node3D, rel: Vector3, vc: Vector3) -> void:
	_de_onde = carro.global_position
	var v := rel.length()
	var audio := get_node_or_null(^"/root/AudioDirector")
	if v < CARRO_EMPURRA:
		if poupar.is_valid() and bool(poupar.call(carro)):
			return
		if _desde < ESPERA:
			return
		_desde = 0.0
		vc.y = 0.0
		empurrar(vc * 0.9, carro.global_position)
		if audio != null:
			audio.call(&"tocar", &"baque_corpo_2", dono.global_position + Vector3.UP * 0.6, -10.0, 0.9)
		return
	derrubar(Vector3.ZERO, Atropelo.golpe(rel), Atropelo.pancada(v))
	if _boneco != null:
		LatariaParaCorpo.criar(carro, Atropelo.caixa_do_carro(carro), _boneco.pecas())
	Atropelo.tranco_no_carro(carro, rel, MASSA)
	if audio != null:
		audio.call(&"tocar", &"atropelo_pancada", dono.global_position + Vector3.UP * 0.6,
			linear_to_db(clampf(v / 10.0, 0.4, 1.3)), randf_range(0.9, 1.08))


## O jogador correndo de encontro (a mesma conta do `Pedestre`).
func _sentir_esbarrao() -> void:
	if _desde < ESPERA or _jogador == null:
		return
	var para_mim := dono.global_position - _jogador.global_position
	para_mim.y = 0.0
	var d := para_mim.length()
	if d > CONTATO + 0.06 or d < 0.01:
		return
	var normal := para_mim / d
	var dele := Vector3(_jogador.velocity.x, 0.0, _jogador.velocity.z).dot(normal)
	if dele < ESBARRAO_MINIMO:
		return
	_desde = 0.0
	var dv := normal * dele * (78.0 / (78.0 + MASSA)) * 0.75
	dv += Vector3(_jogador.velocity.x, 0.0, _jogador.velocity.z) * 0.06
	empurrar(dv, _jogador.global_position)
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call(&"tocar", &"baque_corpo_1", dono.global_position + Vector3.UP, -14.0, 1.25)


## Inclinacao, bracos e passo do tropeco no Corpo.
func _desenhar() -> void:
	if _equilibrio == null:
		corpo.inclinacao = Vector2.ZERO
		corpo.debater = 0.0
		corpo.rumo_passo = 0.0
		return
	var giro := dono.global_rotation.y
	corpo.inclinacao = _equilibrio.inclinacao_local(giro)
	corpo.debater = _equilibrio.debater()
	if _equilibrio.dando_passo():
		corpo.rumo_passo = _equilibrio.rumo_do_passo(giro)


func _encarar(ponto: Vector3) -> void:
	var d := ponto - dono.global_position
	d.y = 0.0
	if d.length_squared() > 0.01:
		dono.global_rotation.y = atan2(-d.x, -d.z)


func _ao_levantar(onde: Vector3, rumo: float) -> void:
	var dor: Dictionary = _boneco.onde_doi() if is_instance_valid(_boneco) else {}
	_boneco = null
	if colisao != null:
		colisao.collision_layer = _camada_antes
	# O Corpo voltou para o dono com transform zerado: se o dono e ele mesmo,
	# e aqui que ele vai para onde levantou.
	dono.global_position = onde
	dono.global_rotation.y = rumo
	if dono != corpo:
		corpo.transform = Transform3D.IDENTITY
	_encarar(_de_onde)
	if not dor.is_empty() and String(dor["parte"]).begins_with("perna"):
		corpo.perna_ruim = -1 if dor["parte"] == &"perna_e" else 1
		corpo.mancando = clampf(float(dor["forca"]) / 9.0, 0.45, 1.0)
		_t_manca = 14.0
	elif not dor.is_empty():
		match dor["parte"]:
			&"cabeca":
				corpo.reagir(ReacaoCorpo.REACAO_DOR_CABECA)
			&"tronco":
				corpo.reagir(ReacaoCorpo.REACAO_DOR_COSTAS)
			_:
				corpo.reagir(ReacaoCorpo.REACAO_DOR_BRACO)
	else:
		corpo.reagir(ReacaoCorpo.REACAO_XINGA)
	levantou.emit(onde, rumo)

## O celular na mao de quem esta dirigindo.
##
## A ideia
## -------
## Mexer no telefone ao volante e possivel, e e perigoso, e o jogo tem de fazer
## o jogador SENTIR as duas coisas sem dizer nenhuma. Nada de aviso na tela, nada
## de carro que trava sozinho. O que muda e o que um motorista de verdade perde:
##   - a vista: a camera vai para dentro da cabine (a de perseguicao veria a rua
##     inteira, e isso e trapaca), a cabeca baixa ate o aparelho no colo, a
##     lente fecha e o olho foca a 30 cm — a rua vira borrao no alto do quadro;
##   - uma mao: a direita sai do aro para segurar o telefone;
##   - o tempo de reacao: o carro continua andando com o que o pe e a mao
##     esquerda mandam (WASD / analogico), mas quem ve o que vem pela frente e a
##     buzina do carro da frente, e nao o jogador;
##   - o telefone, na batida: um tranco forte arranca o aparelho da mao.
## `C` (LB) larga o telefone no colo e os olhos voltam para a rua depressa — o
## movimento de quem levou um susto —, e a vista que o jogador usava volta.
##
## Nao mexe em `Carro` nem em `CabineDoJogador`: le o que eles ja expoem (a
## cabine do carro do jogador, a camera de dentro, o pivo do volante, o olhar
## livre do jogador) e devolve tudo como encontrou.
class_name AoVolante
extends RefCounted

## Para onde a cabeca vira (rad, no olhar livre `OlharAoVolante`): baixa uns 12
## graus e vira um nada para a direita. Com 21 graus a rua saia inteira do
## quadro; com 12 ela fica no terco de cima, borrada — vista mal, que e o ponto.
const ARFAGEM := -0.21
const GUINADA := -0.06
## A lente de quem le no colo. A de dentro da cabine e 74 graus.
const FOV := 56.0
## A luz da tela dentro da cabine (fracao da de fora).
const LUZ := 0.35
## O foco do olho no aparelho: onde a rua comeca a borrar (m), quanto a borda
## demora, e o tamanho do borrao.
const FOCO := 0.9
const FOCO_TRANSICAO := 2.2
const FOCO_FORCA := 0.12
## A vigia do que vem pela frente: a partir de que velocidade (m/s), quanto
## tempo de estrada ela olha (s) e de quanto em quanto tempo o mesmo carro pode
## buzinar de novo.
const VIGIA_VEL := 3.0
const VIGIA_TEMPO := 1.7
const BUZINA_INTERVALO := 2.8
## Batida que arranca o telefone da mao (a forca do sinal `bateu`, 0 a 1).
const SUSTO := 0.22
## O carregador de isqueiro no console, a partir do olho do motorista, no
## espaco do carro (x para o meio do carro); e o fio dele ate o aparelho.
const ISQUEIRO := Vector3(0.36, -0.50, -0.46)
const FIO := 1.0

var carro: Node3D
var cabine: Node3D
var camera: Camera3D

var _jogador: Node
var _vista_antes: int = -1
var _mao_no_aro: Node3D
var _vigia_t: float = 0.0
var _buzinou: Dictionary = {}
var _foco_era: bool = false
var _isqueiro: Node3D
var _fio: CaboFisico


## A cabine do carro do jogador, se ele esta dirigindo um. Nulo a pe, de
## bicicleta ou num carro sem cabine (`--sem-cabine-jogador`).
static func achar(jogador: Node) -> AoVolante:
	if jogador == null or not jogador.has_method(&"carro"):
		return null
	var c := jogador.call(&"carro") as Node3D
	if c == null or not is_instance_valid(c):
		return null
	var cab := c.get(&"_cabine_jogador") as Node3D
	if cab == null or not is_instance_valid(cab):
		return null
	var cam := cab.get(&"_camera") as Camera3D
	if cam == null or not cam.is_inside_tree():
		return null
	var v := AoVolante.new()
	v._jogador = jogador
	v.carro = c
	v.cabine = cab
	v.camera = cam
	return v


func valido() -> bool:
	return is_instance_valid(carro) and is_instance_valid(cabine) and is_instance_valid(camera) \
		and camera.is_inside_tree()


## O telefone subiu: vista de dentro, e a mao direita sai do aro. O fio do
## carregador de isqueiro vai do console ate o conector de baixo de `fone`.
func pegar(fone: Node3D = null) -> void:
	_vista_antes = int(cabine.get(&"vista"))
	if _vista_antes != CabineDoJogador.Vista.DENTRO:
		cabine.call(&"_ir_para", CabineDoJogador.Vista.DENTRO)
	var carro_cabine := cabine.get(&"cabine") as Node
	if carro_cabine != null and carro_cabine.has_method(&"pivo_do_volante"):
		var pivo := carro_cabine.call(&"pivo_do_volante") as Node3D
		if pivo != null:
			_mao_no_aro = pivo.get_node_or_null(^"MaoDireita") as Node3D
	if _mao_no_aro != null:
		_mao_no_aro.visible = false
	if carro.has_signal(&"bateu") and not carro.is_connected(&"bateu", _ao_bater):
		carro.connect(&"bateu", _ao_bater)
	_foco_era = Lente.profundidade_ligada()
	# O desfoque de movimento reprojeta a tela como se tudo fosse cenario: o
	# aparelho a 25 cm da lente, que anda COM a camera, saia arrastado como a rua.
	# Com o telefone na mao o obturador fecha; o olho esta no vidro, e o borrao
	# da rua fica por conta do foco.
	Lente.travar_desfoque(0.0)
	if fone != null:
		_montar_fio(carro_cabine as Node3D, fone)


## O carregador de isqueiro (um cilindro preto com o anel de luz azul, como os
## de posto) e o fio branco dele. O fio e simulado no espaco da cabine: a
## freada o joga para a frente, a curva para o lado.
func _montar_fio(carro_cabine: Node3D, fone: Node3D) -> void:
	if carro_cabine == null or not carro_cabine.has_method(&"olho"):
		return
	var olho: Vector3 = carro_cabine.call(&"olho")
	var lado := float(carro_cabine.call(&"lado_do_motorista")) if carro_cabine.has_method(
		&"lado_do_motorista") else olho.x
	_isqueiro = Node3D.new()
	_isqueiro.name = "Isqueiro"
	carro_cabine.add_child(_isqueiro)
	# Para o meio do carro a partir do lado do motorista.
	var dentro := -signf(lado) if absf(lado) > 0.01 else 1.0
	_isqueiro.position = olho + Vector3(ISQUEIRO.x * dentro, ISQUEIRO.y, ISQUEIRO.z)
	_isqueiro.rotation = Vector3(deg_to_rad(-25.0), 0.0, 0.0)
	var corpo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.011
	cil.bottom_radius = 0.012
	cil.height = 0.045
	cil.radial_segments = 14
	corpo.mesh = cil
	var preto := StandardMaterial3D.new()
	preto.albedo_color = Color("1b1b1d")
	preto.roughness = 0.5
	corpo.material_override = preto
	corpo.rotation.x = PI * 0.5
	_isqueiro.add_child(corpo)
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.008
	toro.outer_radius = 0.0105
	anel.mesh = toro
	var azul := StandardMaterial3D.new()
	azul.albedo_color = Color("2a6cff")
	azul.emission_enabled = true
	azul.emission = Color("2a6cff")
	azul.emission_energy_multiplier = 1.4
	anel.material_override = azul
	anel.rotation.x = PI * 0.5
	anel.position = Vector3(0.0, 0.0, 0.023)
	_isqueiro.add_child(anel)
	_fio = CaboFisico.new()
	_fio.comprimento = FIO
	_fio.referencia = carro_cabine
	_fio.ponta_a = _isqueiro
	_fio.local_a = Vector3(0.0, 0.0, 0.026)
	_fio.saida_a = Vector3.BACK
	_fio.ponta_b = fone
	_fio.local_b = Vector3(0.0, -IphoneDeJogo.TAMANHO.y * 0.5 - 0.004, 0.0)
	_fio.saida_b = Vector3.DOWN
	carro_cabine.add_child(_fio)
	_fio.recomecar()


## A cabeca vai e volta do aparelho com `k` (0 na rua, 1 no telefone).
func passo(k: float, delta: float) -> void:
	if not valido():
		return
	var o := _jogador.get(&"olhar") as RefCounted if &"olhar" in _jogador else null
	if o != null:
		o.set(&"guinada", GUINADA * k)
		o.set(&"arfagem", ARFAGEM * k)
		# Movimento nulo: zera o relogio da volta ao centro, que puxaria os olhos
		# para a rua no meio da mensagem.
		o.call(&"mover", Vector2.ZERO, 0.0)
	# A cabine ja escreveu a lente dela neste quadro; aqui ela fecha por cima.
	camera.fov = lerpf(camera.fov, FOV, k)
	_focar(k)
	_vigiar(delta)


## O olho foca no vidro: a rua borra de longe para perto conforme ele desce.
func _focar(k: float) -> void:
	if _foco_era:
		return
	var a := Lente.atributos()
	if a == null:
		return
	if k <= 0.02:
		a.dof_blur_far_enabled = false
		return
	a.dof_blur_near_enabled = false
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = lerpf(40.0, FOCO, k)
	a.dof_blur_far_transition = lerpf(20.0, FOCO_TRANSICAO, k)
	a.dof_blur_amount = FOCO_FORCA * k


## O que vem pela frente. Quem ve e o motorista do carro da frente, e a buzina
## dele e o unico aviso — o mesmo que a rua da de verdade.
func _vigiar(delta: float) -> void:
	_vigia_t += delta
	for c: Variant in _buzinou.keys():
		_buzinou[c] = float(_buzinou[c]) - delta
	if _vigia_t < 0.12:
		return
	_vigia_t = 0.0
	var corpo := carro as RigidBody3D
	if corpo == null:
		return
	var v := corpo.linear_velocity
	var frente := -corpo.global_transform.basis.z
	var vel := v.dot(frente)
	if vel < VIGIA_VEL:
		return
	var de := corpo.global_position + Vector3.UP * 0.7 + frente * 2.3
	var ate := de + frente * clampf(vel * VIGIA_TEMPO, 6.0, 45.0)
	var q := PhysicsRayQueryParameters3D.create(de, ate)
	q.exclude = [corpo.get_rid()]
	var r := corpo.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	var outro := r["collider"] as Node
	while outro != null and not outro.has_method(&"buzinar"):
		outro = outro.get_parent()
	if outro == null or outro == carro:
		return
	var id := outro.get_instance_id()
	if float(_buzinou.get(id, 0.0)) > 0.0:
		return
	_buzinou[id] = BUZINA_INTERVALO
	outro.call(&"buzinar")


## Um tranco forte arranca o telefone da mao: a direita volta para o aro no
## susto e o aparelho vai para o colo.
func _ao_bater(forca: float) -> void:
	if forca < SUSTO or not Celular.ativo:
		return
	Celular.vibrar(0.2)
	Celular.fechar()


## O telefone voltou para o colo: tudo como estava.
func devolver() -> void:
	Lente.travar_desfoque(-1.0)
	for no: Node in [_fio, _isqueiro]:
		if no != null and is_instance_valid(no):
			no.queue_free()
	_fio = null
	_isqueiro = null
	if not _foco_era:
		Lente.sem_foco()
	if is_instance_valid(_mao_no_aro):
		_mao_no_aro.visible = true
	if is_instance_valid(carro) and carro.is_connected(&"bateu", _ao_bater):
		carro.disconnect(&"bateu", _ao_bater)
	if is_instance_valid(cabine) and _vista_antes >= 0 and _vista_antes != CabineDoJogador.Vista.DENTRO:
		cabine.call(&"_ir_para", _vista_antes)
	var o := _jogador.get(&"olhar") as RefCounted if is_instance_valid(_jogador) and &"olhar" in _jogador \
		else null
	if o != null:
		o.call(&"zerar")

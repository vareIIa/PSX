## Peca solta da blitz: cone, placa, boneco inflavel.
##
## Era malha com uma caixa estatica em volta. O carro do jogador batia num cone
## de plastico como num pilar de concreto, e a placa e o boneco nao tinham
## colisao nenhuma: o carro atravessava. Agora e corpo rigido leve que nasce
## DORMINDO — nao custa passo de fisica parado — e acorda com o primeiro
## encosto.
##
## Camada propria (bit 5). Os raios da IA do transito (`_altura_do_chao`,
## `_medir_obstaculo`) usam mascara 1: um cone caido na pista nao vira chao para
## o carro da rua pular, nem obstaculo para ele frear. A mascara da peca inclui
## a camada 1, entao o chao, o carro do jogador e o proprio jogador a pe a
## tocam, e ela toca as outras pecas (um cone derruba o do lado).
##
## O carro da rua e corpo congelado movido por transformada, e corpo congelado
## nao passa velocidade a ninguem. Quem empurra a peca nesse caso e `Blitz`,
## com `empurrar`.
class_name PecaBlitz
extends RigidBody3D

const CAMADA := 1 << 4
## Intervalo minimo entre dois empurroes do mesmo carro.
const ESPERA_EMPURRAO := 0.35
## Derrubada = saiu do lugar ou tombou. Nao e velocidade: assentar 2 cm no
## chao passa de 0,4 m/s num quadro e nao derrubou nada.
const SAIU_DO_LUGAR := 0.25
const TOMBOU := 0.85

## Saiu do lugar alguma vez, e quem tirou: o nome do carro que empurrou, ou
## "fisica" quando foi contato de corpo (o carro do jogador, outra peca, o
## chao). E o que o teste le para dizer QUEM derrubou.
var derrubada := false
var causa := ""
## Todo corpo que a peca tocou acordada. O contato que a acorda pode acabar no
## mesmo quadro; so o do quadro da queda dizia "o chao".
var _tocou: Dictionary = {}
var _origem := Vector3.ZERO
## Raio da peca no chao, para o teste de contato com o carro da rua.
var raio := 0.2
var _desde_empurrao := 1.0


## `visual` e a malha ja montada com a base em y = 0. `tamanho` e a caixa de
## colisao, apoiada no chao. `centro_y` desce o centro de massa: cone e placa
## tem o peso na base, e com o centro no meio da caixa tombam sozinhos.
static func criar(nome: String, visual: Node3D, tamanho: Vector3, massa: float,
		centro_y: float) -> PecaBlitz:
	var p := PecaBlitz.new()
	p.name = nome
	p.mass = massa
	p.raio = maxf(tamanho.x, tamanho.z) * 0.5
	p.collision_layer = CAMADA
	p.collision_mask = 1 | CAMADA
	p.can_sleep = true
	p.sleeping = true
	# Carro a 60 km/h anda 28 cm num passo de fisica: um cone de 40 cm seria
	# atravessado sem contato.
	p.continuous_cd = true
	# Dois contatos bastam para dizer QUEM encostou (ver `causa`).
	p.contact_monitor = true
	p.max_contacts_reported = 2
	p.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	p.center_of_mass = Vector3(0.0, centro_y, 0.0)
	var atrito := PhysicsMaterial.new()
	atrito.friction = 0.9
	atrito.bounce = 0.2
	p.physics_material_override = atrito
	# Resistencia de rolagem de cone de borracha no asfalto: sem ela o cone
	# rolava como bola, 15 a 30 m depois da mesma pancada.
	p.angular_damp = 1.5
	p.linear_damp = 0.3
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	forma.position = Vector3(0.0, tamanho.y * 0.5, 0.0)
	p.add_child(forma)
	p.add_child(visual)
	return p


## Nasce acordada, 2 cm acima do chao, e assenta sozinha antes de dormir.
func assentar() -> void:
	_origem = global_position
	sleeping = false


func _physics_process(delta: float) -> void:
	_desde_empurrao += delta
	if derrubada or sleeping:
		return
	for corpo: Node in get_colliding_bodies():
		_tocou[String(corpo.name)] = true
	var fora := Vector2(global_position.x - _origem.x, global_position.z - _origem.z).length()
	if fora > SAIU_DO_LUGAR or global_transform.basis.y.dot(Vector3.UP) < TOMBOU:
		derrubada = true
		causa = "fisica(%s)" % ",".join(PackedStringArray(_tocou.keys()))


## Pancada de um carro que nao tem fisica propria. `vel` e a velocidade do carro
## em m/s, `onde` o centro dele. A peca sai para a frente do carro, para o lado
## de fora dele e um pouco para cima — arremessada, e nao arrastada.
func empurrar(vel: Vector3, onde: Vector3, quem: String = "") -> void:
	if _desde_empurrao < ESPERA_EMPURRAO:
		return
	_desde_empurrao = 0.0
	var fora := global_position - onde
	fora.y = 0.0
	fora = fora.normalized() if fora.length() > 0.01 else Vector3.ZERO
	var rapidez := vel.length()
	# Fracao da velocidade do carro que a peca leva. Com 1,15 o cone de um carro
	# a 50 km/h voava 34 m (teste_blitz); um cone de verdade para a 6-15 m.
	var impulso := (vel * 0.7 + fora * rapidez * 0.3
		+ Vector3.UP * rapidez * 0.25) * mass
	sleeping = false
	apply_impulse(impulso, Vector3(0.0, 0.25, 0.0))
	apply_torque_impulse(Vector3(fora.z, 0.0, -fora.x) * rapidez * mass * 0.08)
	if not derrubada:
		causa = quem
	derrubada = true

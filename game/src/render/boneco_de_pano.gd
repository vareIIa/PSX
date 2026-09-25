## O corpo que cai: onze pecas rigidas presas por juntas, no lugar dos ossos.
##
## O que se quer e o GTA IV: quem leva um carro rola por cima do capo, estende a
## mao para amortecer o chao, encolhe rolando, fica no chao gemendo e levanta
## sozinho. O IV fez isso com o Euphoria, da NaturalMotion — e a ideia que
## importa dele nao e o motor, e o "ragdoll com vontade": o corpo e fisica pura
## (inercia, juntas, gravidade, chao), mas cada junta tem um pouco de musculo
## puxando para uma pose que o comportamento escolhe. Com musculo zero e boneco
## de pano; com musculo inteiro e animacao. O meio e gente caindo.
##
## Como e feito aqui
## -----------------
## - Uma RigidBody3D por osso do Corpo (os onze de pose; saia e barriga seguem
##   com a mola propria do Corpo). A peca nasce com a MESMA base do osso, so a
##   forma e deslocada para o meio do segmento. Assim a rotacao relativa entre
##   duas pecas e literalmente a rotacao local do osso, e escrever de volta no
##   esqueleto e uma conta de base, sem tabela de correcao.
## - Juntas Generic6DOFJoint3D com limite anatomico por eixo. As juntas sao
##   criadas com o corpo em REPOUSO (todas as bases iguais a do quadril), e so
##   depois as pecas vao para a pose de agora: o angulo zero da junta e o do
##   repouso, e os limites leem na mesma convencao de `Corpo._girar` (coxa
##   positiva e perna para a frente, canela negativa e joelho dobrando).
## - O musculo e "soft keying" (o que o proprio Jolt recomenda para ragdoll
##   animado): a cada passo de fisica, a velocidade angular da peca e puxada uma
##   fracao para a que levaria a junta ate o angulo alvo. Uma fracao, e nao
##   tudo: a peca continua batendo, rolando e sendo empurrada.
##
## Os comportamentos (nomes do Euphoria entre parenteses)
## ------------------------------------------------------
## - VOANDO: amortecer (catchFall) — os bracos vao para o lado em que o corpo
##   cai; caindo de costas, o queixo encolhe (protege a cabeca).
## - ROLANDO: encolher (rollUp) — rodando rapido, bracos em volta da cabeca e
##   joelhos no peito.
## - PANCADA: o musculo some por um instante quando o corpo bate forte no chao.
##   E o que da peso: o corpo que chega no chao ja "tentando" le como dublê.
## - CHAO: contorcer (writhe / injuredOnGround) — joelho sobe e desce, uma mao
##   vai ao lugar que doi, a cabeca levanta e cai. Quem apanhou muito fica mole
##   (desacordado) antes.
## - LEVANTANDO: a fisica sai e entra uma sequencia de poses-chave, de bruços ou
##   de costas, que parte da pose em que o corpo parou.
##
## Travado em quinze passos por segundo no PS1 STYLE, como tudo que mexe osso
## neste jogo; no MODERNO, liso.
class_name BonecoDePano
extends Node3D

## A pessoa terminou de levantar. Quem e dono do corpo muda de lugar AGORA para
## `onde` e `rumo` — o corpo ja esta de pe ali.
signal levantou(onde: Vector3, rumo: float)

enum Fase { VOANDO, CHAO, LEVANTANDO, FIM }

const O := Corpo.Osso

## Camada das pecas. Separada do mundo (1) para que o jogador e o pedestre, que
## so olham a camada 1, nao tropecem num braco estendido; as pecas continuam
## olhando a camada 1 (chao, parede, carro) e as outras pecas.
const CAMADA := 1 << 5

const PARTES: Array[int] = [O.QUADRIL, O.TORSO, O.CABECA, O.BRACO_E, O.ANTEBRACO_E,
	O.BRACO_D, O.ANTEBRACO_D, O.COXA_E, O.CANELA_E, O.COXA_D, O.CANELA_D]

## Fracao da massa por peca (tabelas de antropometria, Dempster, arredondadas
## para onze pecas; a mao vai com o antebraco e o pe com a canela).
const MASSA := {
	O.QUADRIL: 0.15, O.TORSO: 0.35, O.CABECA: 0.08,
	O.BRACO_E: 0.028, O.ANTEBRACO_E: 0.024, O.BRACO_D: 0.028, O.ANTEBRACO_D: 0.024,
	O.COXA_E: 0.10, O.CANELA_E: 0.06, O.COXA_D: 0.10, O.CANELA_D: 0.06,
}

## Limites de junta em radianos, [x-, x+, y-, y+, z-, z+], na convencao de
## `Corpo._girar` (rotacao local do osso filho em relacao ao pai).
## x: coxa/braco positivo vai para a frente; tronco e cabeca positivos vao para
## tras; canela so dobra para tras (negativo), antebraco so para dentro
## (positivo). z: lado esquerdo abre com z negativo, o direito com positivo.
## O eixo do meio (y, a torcao) fica curto: e o eixo que a decomposicao XYZ da
## junta nao aguenta perto de noventa graus.
const LIMITES := {
	O.TORSO: [-0.95, 0.40, -0.55, 0.55, -0.45, 0.45],
	O.CABECA: [-0.75, 0.65, -1.0, 1.0, -0.5, 0.5],
	O.BRACO_E: [-1.1, 2.7, -0.8, 0.8, -2.3, 0.35],
	O.BRACO_D: [-1.1, 2.7, -0.8, 0.8, -0.35, 2.3],
	O.ANTEBRACO_E: [-0.02, 2.5, -0.6, 0.6, -0.05, 0.05],
	O.ANTEBRACO_D: [-0.02, 2.5, -0.6, 0.6, -0.05, 0.05],
	O.COXA_E: [-0.55, 2.0, -0.55, 0.55, -0.9, 0.25],
	O.COXA_D: [-0.55, 2.0, -0.55, 0.55, -0.25, 0.9],
	O.CANELA_E: [-2.45, 0.02, -0.08, 0.08, -0.06, 0.06],
	O.CANELA_D: [-2.45, 0.02, -0.08, 0.08, -0.06, 0.06],
}

## Ganho do musculo: com forca 1 a junta fecharia o erro em 1/GANHO segundos.
const GANHO := 14.0
## Parado quando nenhuma peca passa disto (m/s e rad/s) por TEMPO_ASSENTAR.
const PARADO_LINEAR := 0.35
const PARADO_ANGULAR := 1.4
const TEMPO_ASSENTAR := 0.45
## Teto de tempo no ar e rolando. Corpo que nao assenta (preso em cima de um
## carro que anda, enroscado num portao) levanta assim mesmo.
const TEMPO_MAXIMO := 9.0

## Duracao da mistura da ultima pose da fisica para a primeira pose-chave.
const MISTURA := 0.35

## Liga o musculo. Existe para a regua isolar a fisica pura do comportamento.
static var musculo_ligado := true

var corpo: Corpo
var fase: Fase = Fase.VOANDO
## Quao feia foi a pancada, de 0 a 1. Decide quanto tempo fica mole e gemendo.
var gravidade: float = 0.5
## Levanta sozinho quando assenta. Desligado, fica no chao ate `encerrar` — e o
## jogador que desmaiou: quem acorda o corpo e o `Desmaio`, no orelhao.
var levantar_sozinho: bool = true

var _pecas := {}
var _massa_total := 70.0
var _t := 0.0
var _t_fase := 0.0
var _t_quieto := 0.0
var _mole := 0.0
var _gemer := 0.0
var _semente := 0.0
var _passo_escrito := -1
var _altura_chao := 0.0
var _vel_pelve_ant := Vector3.ZERO
## Maior pancada sentida (queda de velocidade do tronco num passo), em m/s.
var _maior_pancada := 0.0
var _desde_som := 1.0
var _arrastou := false
## Teto de velocidade das pecas (m/s): o golpe mais uma folga. Ver `_segurar`.
var _teto := 14.0
## Onde doeu: a maior pancada que cada peca levou encostada em alguma coisa
## (m/s perdidos num passo), e a velocidade de cada peca no passo anterior.
## Decide a mao que vai ao lugar e a perna que manca depois (`onde_doi`).
var _dor := {}
var _vel_ant := {}
## A cara do tombo (ver `_cara`): o que esta sendo mostrado e o tempo de careta
## que uma pancada ainda segura.
var _t_careta := 0.0

# Levantar: poses-chave, tempo e a pose de partida capturada da fisica.
var _chaves: Array = []
var _partida := {}
var _t_levantar := 0.0
var _de_brucos := false
var _folga_de_pe := Vector3.ZERO


## Derruba `corpo`. `vel` e a velocidade que o corpo inteiro tinha (andando,
## sentado num carro); `golpe` e a velocidade que a pancada da, aplicada cheia
## abaixo de `altura_golpe` (metros do chao) e caindo ate um terco na cabeca —
## o para-choque leva as canelas, o tronco fica para tras e o corpo gira por
## cima do capo. `ignorar` sao corpos com que as pecas nao colidem (a capsula
## do proprio dono, que ja deveria estar desligada, e o assento de onde saiu).
static func derrubar(alvo: Corpo, vel: Vector3, golpe: Vector3 = Vector3.ZERO,
		altura_golpe: float = 0.5, pancada: float = 0.5,
		ignorar: Array = []) -> BonecoDePano:
	var b := BonecoDePano.new()
	b.name = "BonecoDePano"
	b.corpo = alvo
	b.gravidade = clampf(pancada, 0.0, 1.0)
	b.top_level = true
	alvo.get_parent().add_child(b)
	b.global_transform = Transform3D.IDENTITY
	b._montar(vel, golpe, altura_golpe, ignorar)
	return b


func _montar(vel: Vector3, golpe: Vector3, altura_golpe: float, ignorar: Array) -> void:
	var sk := corpo.esqueleto()
	var mundo_sk := sk.global_transform
	var a := corpo.aparencia()
	var g := Anatomia.gordura(a)
	var s := corpo.altura() / Corpo.ALTURA_REF
	_massa_total = 72.0 * s * s * (0.78 + 0.5 * g)
	_semente = float(absi(corpo.get_instance_id()) % 997) * 0.37
	var chao_ref := corpo.global_position.y

	# 1. Repouso preso ao quadril de agora: e nele que as juntas nascem.
	var quadril_agora := mundo_sk * sk.get_bone_global_pose(O.QUADRIL)
	var quadril_rest := sk.get_bone_global_rest(O.QUADRIL)
	var base_rest := quadril_agora * quadril_rest.affine_inverse()
	for osso in PARTES:
		var p := RigidBody3D.new()
		p.name = sk.get_bone_name(osso)
		p.collision_layer = CAMADA
		p.collision_mask = 1 | CAMADA
		p.mass = _massa_total * float(MASSA[osso])
		p.continuous_cd = true
		p.can_sleep = false
		p.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		p.linear_damp = 0.04
		p.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		p.angular_damp = 1.2 if osso != O.TORSO and osso != O.QUADRIL else 2.0
		var mat := PhysicsMaterial.new()
		mat.friction = 0.85
		mat.bounce = 0.04
		p.physics_material_override = mat
		p.contact_monitor = true
		p.max_contacts_reported = 2
		_formas(p, osso, a, s)
		# A pose entra ANTES da arvore: o boneco e `top_level` na identidade, entao
		# a local e a do mundo. Posta depois, cada peca nascia na origem do mundo
		# e o primeiro passo de fisica pagava a viagem (o mesmo do pedestre, ver
		# `Multidao._criar`).
		var pose := Transform3D(base_rest.basis, base_rest * sk.get_bone_global_rest(osso).origin)
		p.transform = pose
		add_child(p)
		p.global_transform = pose
		_pecas[osso] = p
	for osso in PARTES:
		for outro: Node in ignorar:
			if outro is PhysicsBody3D:
				(_pecas[osso] as RigidBody3D).add_collision_exception_with(outro)
	_excecoes()

	# 2. Juntas, com as pecas ainda em repouso.
	for osso in PARTES:
		var pai := sk.get_bone_parent(osso)
		if pai < 0:
			continue
		var j := Generic6DOFJoint3D.new()
		j.name = "Junta_%s" % sk.get_bone_name(osso)
		add_child(j)
		j.global_transform = (_pecas[osso] as RigidBody3D).global_transform
		var lim: Array = LIMITES[osso]
		for eixo in 3:
			var lo := float(lim[eixo * 2])
			var hi := float(lim[eixo * 2 + 1])
			_param(j, eixo, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lo)
			_param(j, eixo, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, hi)
			_param(j, eixo, Generic6DOFJoint3D.PARAM_ANGULAR_LIMIT_SOFTNESS, 0.9)
			_param(j, eixo, Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING, 1.0)
			_param(j, eixo, Generic6DOFJoint3D.PARAM_ANGULAR_ERP, 0.6)
			# A parte linear fica com a PinJoint3D de baixo.
			_flag(j, eixo, Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, false)
		# FILHO em A e pai em B, ao contrario do que parece natural. O Godot
		# Physics mede o angulo da junta como B relativo a A invertido (a base
		# de A vista de B): com o pai em A, uma sonda de junta unica mostrou
		# limite [0, 1] segurando o filho em [-1, 0], e com dois eixos juntos o
		# ombro saia do limite inteiro (-2,97 rad), porque a inversa de uma
		# rotacao composta nao e a mesma rotacao com os sinais trocados. Com o
		# filho em A, o angulo medido e o do filho no pai: o de `Corpo._girar`.
		j.node_a = j.get_path_to(_pecas[osso])
		j.node_b = j.get_path_to(_pecas[pai])
		# O encaixe (a posicao) vai numa PinJoint3D a parte. A parte linear da
		# 6DOF do Godot Physics e mole: com ela a regua media o joelho a 10 cm
		# da coxa com o corpo parado no chao, e o antebraco a 45 cm do cotovelo
		# com o musculo puxando. O pino e o vinculo mais duro que o motor tem.
		var pino := PinJoint3D.new()
		pino.name = "Pino_%s" % sk.get_bone_name(osso)
		add_child(pino)
		pino.global_transform = (_pecas[osso] as RigidBody3D).global_transform
		pino.set_param(PinJoint3D.PARAM_BIAS, 0.6)
		pino.set_param(PinJoint3D.PARAM_DAMPING, 1.0)
		pino.node_a = pino.get_path_to(_pecas[osso])
		pino.node_b = pino.get_path_to(_pecas[pai])

	# 3. Agora sim, cada peca vai para a pose em que o corpo estava.
	for osso in PARTES:
		var p: RigidBody3D = _pecas[osso]
		p.global_transform = mundo_sk * sk.get_bone_global_pose(osso)
		var altura := p.global_position.y - chao_ref
		# O golpe cheio embaixo, um terco na cabeca: e a diferenca que gira o
		# corpo por cima do capo, em vez de empurra-lo inteiro como um armario.
		# Gradiente suave: degrau de velocidade entre duas pecas vizinhas e a
		# junta que abre (a regua viu 47 cm no joelho com smoothstep curto).
		var k := lerpf(1.0, 0.45, clampf((altura - altura_golpe * 0.4)
			/ maxf(0.1, corpo.altura() - altura_golpe * 0.4), 0.0, 1.0))
		p.linear_velocity = vel + golpe * k
		if golpe.length() > 0.5:
			# Uma pitada de giro em volta do eixo de lado do golpe: sem ela o
			# tombo sai perfeitamente plano, e gente nunca cai plana.
			var lado := golpe.normalized().cross(Vector3.UP)
			p.angular_velocity = lado * golpe.length() * 0.35 \
				+ Vector3(0.0, sin(_semente) * 1.5, 0.0)

	# O para-choque pega primeiro a perna do lado do carro: e ela que doi.
	if golpe.length() > 2.0:
		var vem := -golpe.normalized()
		var pelve := (_pecas[O.QUADRIL] as RigidBody3D).global_position
		var perna := O.CANELA_E
		if ((_pecas[O.CANELA_D] as RigidBody3D).global_position - pelve).dot(vem) \
				> ((_pecas[O.CANELA_E] as RigidBody3D).global_position - pelve).dot(vem):
			perna = O.CANELA_D
		_dor[perna] = golpe.length() * 0.8

	corpo.dominado = true
	corpo.top_level = true
	_altura_chao = chao_ref
	_teto = maxf(14.0, (vel + golpe).length() * 1.5)
	_vel_pelve_ant = (_pecas[O.TORSO] as RigidBody3D).linear_velocity
	_escrever(true)


static func _flag(j: Generic6DOFJoint3D, eixo: int, f: int, v: bool) -> void:
	match eixo:
		0:
			j.set_flag_x(f, v)
		1:
			j.set_flag_y(f, v)
		_:
			j.set_flag_z(f, v)


static func _param(j: Generic6DOFJoint3D, eixo: int, p: int, v: float) -> void:
	match eixo:
		0:
			j.set_param_x(p, v)
		1:
			j.set_param_y(p, v)
		_:
			j.set_param_z(p, v)


## A forma de cada peca, em coordenada do osso: a origem e a junta de cima e o
## segmento desce (ou sobe, no tronco e na cabeca) ao longo de y.
func _formas(p: RigidBody3D, osso: int, a: Dictionary, s: float) -> void:
	var g := Anatomia.gordura(a)
	var perfil := corpo.perfil()
	var mq := Anatomia.meio_quadril(a)
	match osso:
		O.QUADRIL:
			var m := Anatomia.medida(perfil, 0.9)
			_caixa(p, Vector3(m.x * 2.0, 0.2 * s, m.y + m.z),
				Vector3(0.0, -0.03 * s, (m.z - m.y) * 0.5))
		O.TORSO:
			var m := Anatomia.medida(perfil, 1.12)
			var ombro := Anatomia.medida(perfil, 1.3)
			_caixa(p, Vector3(maxf(m.x, ombro.x) * 1.9, 0.46 * s, m.y + m.z),
				Vector3(0.0, 0.24 * s, (m.z - m.y) * 0.5))
		O.CABECA:
			_caixa(p, Vector3(0.22, 0.3 * s, 0.24), Vector3(0.0, 0.16 * s, 0.0))
		O.BRACO_E, O.BRACO_D:
			_capsula(p, 0.048 + 0.03 * g, (Corpo.Y_OMBRO - Corpo.Y_COTOVELO) * s)
		O.ANTEBRACO_E, O.ANTEBRACO_D:
			# Ate a ponta dos dedos: a mao e o que encosta no chao primeiro.
			_capsula(p, 0.042 + 0.02 * g, (Corpo.Y_COTOVELO - 0.68) * s)
		O.COXA_E, O.COXA_D:
			_capsula(p, minf(Anatomia.raio_coxa(a), mq * 0.95),
				(Corpo.Y_QUADRIL - Corpo.Y_JOELHO) * s)
		O.CANELA_E, O.CANELA_D:
			_capsula(p, 0.055 + 0.015 * g, (Corpo.Y_JOELHO - 0.06) * s)
			# O pe: caixa rasa para a frente. Sem ele a canela rola no chao
			# como um lapis, e o corpo deitado nunca para.
			# Curto: sem tornozelo, pe comprido de bruços crava o bico no chao e
			# o chao empurra a canela para dentro da coxa (a regua mediu 12 cm).
			_caixa(p, Vector3(0.09, 0.06, 0.15),
				Vector3(0.0, -(Corpo.Y_JOELHO - 0.03) * s, -0.035))


func _caixa(p: RigidBody3D, tamanho: Vector3, centro: Vector3) -> void:
	var f := CollisionShape3D.new()
	var c := BoxShape3D.new()
	c.size = tamanho
	f.shape = c
	f.position = centro
	p.add_child(f)


func _capsula(p: RigidBody3D, raio: float, comprimento: float) -> void:
	var f := CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = raio
	c.height = maxf(comprimento, raio * 2.0 + 0.01)
	f.shape = c
	f.position = Vector3(0.0, -comprimento * 0.5, 0.0)
	p.add_child(f)


## Pecas que se tocam de nascenca e nao podem se empurrar: o braco encosta no
## tronco (e no gordo o tronco e mais largo que o ombro), as coxas encostam uma
## na outra e no tronco. Colidindo, elas explodem no primeiro passo.
func _excecoes() -> void:
	var pares := [
		[O.BRACO_E, O.TORSO], [O.BRACO_D, O.TORSO], [O.BRACO_E, O.QUADRIL],
		[O.BRACO_D, O.QUADRIL], [O.ANTEBRACO_E, O.QUADRIL], [O.ANTEBRACO_D, O.QUADRIL],
		[O.ANTEBRACO_E, O.TORSO], [O.ANTEBRACO_D, O.TORSO],
		[O.COXA_E, O.COXA_D], [O.COXA_E, O.TORSO], [O.COXA_D, O.TORSO],
		[O.CABECA, O.BRACO_E], [O.CABECA, O.BRACO_D],
		[O.ANTEBRACO_E, O.COXA_E], [O.ANTEBRACO_D, O.COXA_D],
	]
	for par: Array in pares:
		(_pecas[par[0]] as RigidBody3D).add_collision_exception_with(_pecas[par[1]])


# --- simulacao --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if corpo == null or not is_instance_valid(corpo):
		queue_free()
		return
	_t += delta
	_t_fase += delta
	match fase:
		Fase.VOANDO, Fase.CHAO:
			_segurar()
			_sentir(delta)
			# `_sentir` pode ter comecado o levantar, e ai as pecas ja se foram.
			if fase != Fase.LEVANTANDO:
				_musculos(delta)
				_cara(delta)
		Fase.LEVANTANDO:
			_t_levantar += delta


func _process(_delta: float) -> void:
	if corpo == null or not is_instance_valid(corpo):
		return
	match fase:
		Fase.VOANDO, Fase.CHAO:
			_escrever(false)
		Fase.LEVANTANDO:
			_animar_levantar()


## Pancada, pouso e assentamento.
func _sentir(delta: float) -> void:
	var tronco: RigidBody3D = _pecas[O.TORSO]
	var v := tronco.linear_velocity
	var perda := (_vel_pelve_ant - v).length()
	_vel_pelve_ant = v
	# Pancada: velocidade perdida num passo, descontada a gravidade que o passo
	# acrescenta sozinho. Acima de 3 m/s, e chao ou parede batendo no corpo.
	_desde_som += delta
	if perda > 3.0 and _tocando():
		_maior_pancada = maxf(_maior_pancada, perda)
		_t_careta = clampf(perda / 8.0, 0.4, 1.2)
		if _desde_som > 0.22:
			_desde_som = 0.0
			_soar(&"baque_corpo_%d" % (1 + int(_semente * 7.0 + _t * 3.0) % 3),
				linear_to_db(clampf(perda / 7.0, 0.25, 1.2)))
	# Arrastando no chao: o tronco escorrega de lado depressa, encostado.
	if not _arrastou and fase == Fase.CHAO and Vector2(v.x, v.z).length() > 2.2 \
			and tronco.get_contact_count() > 0:
		_arrastou = true
		_soar(&"arrasto_corpo", -6.0)
		_mole = maxf(_mole, clampf(0.25 + perda * 0.06, 0.25, 1.1))
		if fase == Fase.VOANDO:
			fase = Fase.CHAO
			_t_fase = 0.0
			gravidade = clampf(maxf(gravidade, perda / 12.0), 0.0, 1.0)
			_gemer = lerpf(1.0, 3.0, gravidade)
	_mole = maxf(0.0, _mole - delta)
	_anotar_dor()

	# Assentado e o TRONCO parado. Braco e perna mexem de proposito no chao
	# (contorcer), e contando com eles ninguem assentava: a pessoa so levantava
	# pelo teto de tempo, doze segundos depois do atropelo.
	var parado := true
	for osso: int in [O.QUADRIL, O.TORSO]:
		var p: RigidBody3D = _pecas[osso]
		if p.linear_velocity.length() > PARADO_LINEAR \
				or p.angular_velocity.length() > PARADO_ANGULAR:
			parado = false
			break
	if fase == Fase.VOANDO and parado and _t > 0.6:
		fase = Fase.CHAO
		_t_fase = 0.0
		_gemer = lerpf(0.8, 2.2, gravidade)
	_t_quieto = _t_quieto + delta if parado else 0.0

	# Desacordado: o tempo de gemer so comeca a contar depois do tempo mole.
	var desacordado := _tempo_desacordado()
	var pronto := fase == Fase.CHAO and _t_quieto > TEMPO_ASSENTAR \
		and _t_fase > desacordado + _gemer
	if levantar_sozinho and (pronto or _t > TEMPO_MAXIMO + desacordado):
		_comecar_levantar()


## Cada peca que perde velocidade de uma vez encostada em alguma coisa bateu.
## A cabeca pesa mais: bater a cabeca doi mais que bater o ombro.
const PESO_DOR := {O.CABECA: 1.6, O.TORSO: 1.0, O.QUADRIL: 1.0}


func _anotar_dor() -> void:
	for osso in PARTES:
		var p: RigidBody3D = _pecas[osso]
		var v := p.linear_velocity
		var ant: Vector3 = _vel_ant.get(osso, v)
		_vel_ant[osso] = v
		var perda := (ant - v).length()
		if perda > 3.0 and p.get_contact_count() > 0:
			_dor[osso] = maxf(float(_dor.get(osso, 0.0)),
				perda * float(PESO_DOR.get(osso, 0.8)))


## A cara no tombo, escrita no `Rosto` como reacao curta renovada a cada passo
## (ela se desfaz sozinha quando o tombo acaba): susto no primeiro instante,
## medo no ar, careta de dor em cada pancada e no chao gemendo, olho fechado
## desacordado. Sem isso a pessoa voa por cima do capo com cara de fila de
## banco — e a cara e o que se ve primeiro de perto.
func _cara(delta: float) -> void:
	var r := corpo.rosto
	if r == null or not r.valido():
		return
	_t_careta = maxf(0.0, _t_careta - delta)
	var quer := Rosto.Expressao.DOR
	if fase == Fase.CHAO and _t_fase < _tempo_desacordado():
		quer = Rosto.Expressao.DESACORDADO
	elif _t_careta > 0.0:
		quer = Rosto.Expressao.DOR
	elif fase == Fase.VOANDO:
		quer = Rosto.Expressao.SURPRESA if _t < 0.15 else Rosto.Expressao.MEDO
	r.reagir(quer, 0.3)


func _soar(nome: StringName, volume_db: float) -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call(&"tocar", nome, (_pecas[O.TORSO] as RigidBody3D).global_position,
			volume_db, randf_range(0.9, 1.1))


## Quanto tempo fica mole no chao antes de comecar a gemer. So pancada feia
## apaga (acima de 3/4 da escala), e no maximo tres segundos: no GTA IV quem e
## atropelado levanta em tres a seis segundos, e mais que isso le como morto.
func _tempo_desacordado() -> float:
	return lerpf(0.0, 3.0, smoothstep(0.75, 1.0, gravidade))


## Rede de seguranca: nenhuma peca passa do teto. Membro prensado entre a
## lataria que para e o chao e cuspido pelo motor de contato — a regua viu um
## antebraco a 31 m/s num atropelo a 40 km/h, uma vez em quatro. Todo ragdoll de
## jogo tem esse teto; sem ele, uma vez a cada tanto alguem sai voando pela rua.
##
## E a junta que abriu demais volta ao encaixe. O pino segura 3 cm no pior
## impacto; o que passa de ENCAIXE e membro prensado entre carro e chao, e
## nenhuma quantidade de iteracao do motor desfaz isso no mesmo quadro.
const ENCAIXE := 0.08


func _segurar() -> void:
	var sk := corpo.esqueleto()
	for osso in PARTES:
		var p: RigidBody3D = _pecas[osso]
		if p.linear_velocity.length() > _teto:
			p.linear_velocity = p.linear_velocity.limit_length(_teto)
		if p.angular_velocity.length() > 28.0:
			p.angular_velocity = p.angular_velocity.limit_length(28.0)
		var pai := sk.get_bone_parent(osso)
		if pai < 0:
			continue
		var pp: RigidBody3D = _pecas[pai]
		var encaixe := pp.global_transform * sk.get_bone_rest(osso).origin
		if encaixe.distance_to(p.global_position) > ENCAIXE:
			p.global_position = encaixe
			p.linear_velocity = p.linear_velocity.lerp(pp.linear_velocity, 0.5)


func _tocando() -> bool:
	for osso in PARTES:
		if (_pecas[osso] as RigidBody3D).get_contact_count() > 0:
			return true
	return false


# --- musculo ----------------------------------------------------------------

## Escolhe a pose alvo e a forca de cada junta, e puxa.
func _musculos(_delta: float) -> void:
	var tronco: RigidBody3D = _pecas[O.TORSO]
	var forca := 0.0
	var alvo := {}
	var desacordado := fase == Fase.CHAO and _t_fase < _tempo_desacordado()
	if fase == Fase.VOANDO:
		var giro := tronco.angular_velocity.length()
		if giro > 6.0:
			alvo = _pose_encolher()
			forca = 0.22
		else:
			alvo = _pose_amortecer(tronco)
			forca = 0.2
	elif not desacordado:
		alvo = _pose_contorcer()
		forca = 0.1
	forca *= clampf(1.0 - _mole, 0.0, 1.0)
	if forca <= 0.001 or not musculo_ligado:
		return
	for osso: int in alvo:
		var pai := corpo.esqueleto().get_bone_parent(osso)
		_puxar(_pecas[osso], osso, _pecas[pai], alvo[osso], forca)


## Soft keying: a velocidade angular vai uma fracao do caminho ate a que fecha
## o erro da junta em 1/GANHO segundos. A reacao volta ao pai na proporcao das
## massas, para o corpo nao "nadar" no ar com os proprios bracos.
func _puxar(parte: RigidBody3D, osso: int, pai: RigidBody3D, euler: Vector3,
		forca: float) -> void:
	# O alvo fica DENTRO do limite, com folga: musculo empurrando contra o
	# batente injeta energia a cada passo e a junta cede (a regua viu 45 cm).
	var lim: Array = LIMITES[osso]
	var alvo_euler := Vector3(
		clampf(euler.x, float(lim[0]) + 0.05, float(lim[1]) - 0.05),
		clampf(euler.y, float(lim[2]) + 0.05, float(lim[3]) - 0.05),
		clampf(euler.z, float(lim[4]) + 0.02, float(lim[5]) - 0.02))
	var desejada := pai.global_basis * Basis.from_euler(alvo_euler, EULER_ORDER_XYZ)
	var erro := (desejada * parte.global_basis.inverse()).orthonormalized().get_rotation_quaternion()
	if erro.w < 0.0:
		erro = -erro
	var angulo := 2.0 * acos(clampf(erro.w, -1.0, 1.0))
	if angulo < 0.001:
		return
	var eixo := Vector3(erro.x, erro.y, erro.z).normalized()
	var alvo := pai.angular_velocity + eixo * angulo * GANHO
	var dv := ((alvo - parte.angular_velocity) * forca).limit_length(6.0)
	# So giro: somar a velocidade linear do giro em volta da junta (dv x r)
	# parecia o certo, e a regua mediu a junta abrindo o dobro. O pino ja
	# arrasta o centro da peca junto.
	parte.angular_velocity += dv
	pai.angular_velocity -= dv * clampf(parte.mass / pai.mass, 0.0, 1.0) * 0.5


## Caindo: os bracos vao para o lado em que o chao esta vindo.
func _pose_amortecer(tronco: RigidBody3D) -> Dictionary:
	var frente := -tronco.global_basis.z
	var lado := tronco.global_basis.x
	var d := {}
	if frente.y < -0.25:
		# De cara: bracos a frente, cotovelo quase reto — as maos chegam antes.
		d[O.BRACO_E] = Vector3(1.45, 0.0, -0.25)
		d[O.BRACO_D] = Vector3(1.45, 0.0, 0.25)
		d[O.ANTEBRACO_E] = Vector3(0.3, 0.0, 0.0)
		d[O.ANTEBRACO_D] = Vector3(0.3, 0.0, 0.0)
		d[O.CABECA] = Vector3(0.45, 0.0, 0.0)
	elif frente.y > 0.25:
		# De costas: bracos para tras e para fora, queixo no peito.
		d[O.BRACO_E] = Vector3(-0.7, 0.0, -0.75)
		d[O.BRACO_D] = Vector3(-0.7, 0.0, 0.75)
		d[O.ANTEBRACO_E] = Vector3(0.2, 0.0, 0.0)
		d[O.ANTEBRACO_D] = Vector3(0.2, 0.0, 0.0)
		d[O.CABECA] = Vector3(-0.6, 0.0, 0.0)
		d[O.TORSO] = Vector3(-0.35, 0.0, 0.0)
	else:
		# De lado: o braco de baixo abre para o chao, o de cima fica no corpo.
		var cai_esquerda := lado.y > 0.0
		d[O.BRACO_E] = Vector3(0.4, 0.0, -1.5 if cai_esquerda else -0.2)
		d[O.BRACO_D] = Vector3(0.4, 0.0, 0.2 if cai_esquerda else 1.5)
		d[O.ANTEBRACO_E] = Vector3(0.25, 0.0, 0.0)
		d[O.ANTEBRACO_D] = Vector3(0.25, 0.0, 0.0)
		d[O.CABECA] = Vector3(0.0, 0.0, -0.35 if cai_esquerda else 0.35)
	d[O.COXA_E] = Vector3(0.35, 0.0, -0.08)
	d[O.COXA_D] = Vector3(0.25, 0.0, 0.08)
	d[O.CANELA_E] = Vector3(-0.6, 0.0, 0.0)
	d[O.CANELA_D] = Vector3(-0.45, 0.0, 0.0)
	return d


## Rolando: bola.
func _pose_encolher() -> Dictionary:
	return {
		O.BRACO_E: Vector3(2.2, 0.0, -0.35), O.BRACO_D: Vector3(2.2, 0.0, 0.35),
		O.ANTEBRACO_E: Vector3(2.2, 0.0, 0.0), O.ANTEBRACO_D: Vector3(2.2, 0.0, 0.0),
		O.CABECA: Vector3(-0.55, 0.0, 0.0), O.TORSO: Vector3(-0.6, 0.0, 0.0),
		O.COXA_E: Vector3(1.4, 0.0, -0.1), O.COXA_D: Vector3(1.3, 0.0, 0.1),
		O.CANELA_E: Vector3(-1.9, 0.0, 0.0), O.CANELA_D: Vector3(-1.8, 0.0, 0.0),
	}


## No chao, doendo. Lento e fora de compasso: um joelho sobe, o outro nao; uma
## mao vai a barriga, a outra fica. O seno de cada membro tem periodo proprio
## sorteado pela pessoa, senao o chao inteiro geme no mesmo ritmo.
func _pose_contorcer() -> Dictionary:
	var t := _t_fase + _semente
	var j1 := 0.5 + 0.5 * sin(t * 1.3)
	var j2 := 0.5 + 0.5 * sin(t * 0.9 + 2.0)
	var mao := 0.5 + 0.5 * sin(t * 0.7 + 1.0)
	var mao_na_barriga := int(_semente * 10.0) % 2 == 0
	var d := {
		O.COXA_E: Vector3(0.9 * j1, 0.0, -0.1), O.CANELA_E: Vector3(-1.5 * j1, 0.0, 0.0),
		O.COXA_D: Vector3(0.6 * j2, 0.0, 0.1), O.CANELA_D: Vector3(-1.1 * j2, 0.0, 0.0),
		O.CABECA: Vector3(-0.35 * mao, 0.2 * sin(t * 0.5), 0.0),
	}
	if mao_na_barriga:
		d[O.BRACO_D] = Vector3(0.7, 0.0, 0.15)
		d[O.ANTEBRACO_D] = Vector3(1.6 + 0.3 * mao, 0.0, 0.0)
		d[O.BRACO_E] = Vector3(0.3 * j2, 0.0, -0.5)
	else:
		# Mao na cabeca.
		d[O.BRACO_E] = Vector3(1.9, 0.0, -0.2)
		d[O.ANTEBRACO_E] = Vector3(2.0 + 0.2 * mao, 0.0, 0.0)
		d[O.BRACO_D] = Vector3(0.3 * j1, 0.0, 0.5)
	return d


# --- pose de volta no esqueleto ----------------------------------------------

## Copia as pecas para os ossos. O no do Corpo vai para baixo do quadril, no
## chao, e fica em pe (so o rumo): quem mede distancia, toca voz ou decide LOD
## pelo no continua achando a pessoa onde ela caiu.
func _escrever(forcar: bool) -> void:
	if not forcar and not Corpo._luz_por_pixel():
		var passo := int(Time.get_ticks_msec() * Corpo.POSES_POR_CICLO / 1000.0)
		if passo == _passo_escrito:
			return
		_passo_escrito = passo
	var pelve: RigidBody3D = _pecas[O.QUADRIL]
	var onde := pelve.global_position
	corpo.global_transform = Transform3D(Basis(Vector3.UP, corpo.global_rotation.y),
		Vector3(onde.x, _altura_chao, onde.z))
	var inv := corpo.esqueleto().global_transform.affine_inverse()
	var sk := corpo.esqueleto()
	var modelo := {}
	for osso in PARTES:
		modelo[osso] = inv * (_pecas[osso] as RigidBody3D).global_transform
	for osso in PARTES:
		var m: Transform3D = modelo[osso]
		var pai := sk.get_bone_parent(osso)
		if pai < 0:
			sk.set_bone_pose_position(osso, m.origin)
			sk.set_bone_pose_rotation(osso, m.basis.orthonormalized().get_rotation_quaternion())
		else:
			var mp: Transform3D = modelo[pai]
			var local := (mp.basis.inverse() * m.basis).orthonormalized()
			sk.set_bone_pose_rotation(osso, local.get_rotation_quaternion())
	_altura_chao = _chao_embaixo(onde, _altura_chao)


func _chao_embaixo(de: Vector3, padrao: float) -> float:
	if not is_inside_tree():
		return padrao
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(de + Vector3.UP * 0.5, de + Vector3.DOWN * 3.0, 1)
	var achado := espaco.intersect_ray(q)
	if achado.is_empty():
		return padrao
	return (achado["position"] as Vector3).y


# --- levantar ---------------------------------------------------------------

## A fisica sai. O corpo fica de pe no rumo certo: de bruços, a cabeca aponta
## para a frente do corpo (ele empurra o chao e sobe para onde olhava); de
## costas, os pes apontam para a frente (senta, dobra os joelhos e levanta na
## direcao dos pes).
func _comecar_levantar() -> void:
	var tronco: RigidBody3D = _pecas[O.TORSO]
	var pelve: RigidBody3D = _pecas[O.QUADRIL]
	var frente := -tronco.global_basis.z
	_de_brucos = frente.y < 0.0
	var cabeca := tronco.global_basis.y
	cabeca.y = 0.0
	if cabeca.length_squared() < 0.0001:
		cabeca = -corpo.global_basis.z
	cabeca = cabeca.normalized()
	var olha := cabeca if _de_brucos else -cabeca
	var rumo := atan2(-olha.x, -olha.z)
	var onde := pelve.global_position
	_altura_chao = _chao_embaixo(onde, _altura_chao)
	# O no vai para onde a pessoa vai ficar de pe, e nao para baixo do quadril:
	# o quadril deitado da primeira chave tem de cair em cima do da fisica.
	var giro := Basis(Vector3.UP, rumo)
	var deitado := LevantarDoChao.quadril_deitado(_de_brucos, corpo)
	deitado.y = 0.0
	onde -= giro * deitado
	onde.y = _altura_chao
	# Onde vai ficar de pe tem de caber uma pessoa: caido encostado no carro que
	# o derrubou, ou no muro, levantar ali poe a capsula dentro da lataria e o
	# motor empurra os dois. Procura o lugar livre mais perto; o corpo desliza
	# ate la durante o levantar (ver `_folga_de_pe`).
	var livre := _lugar_livre(onde)
	_folga_de_pe = livre - onde
	onde = livre
	corpo.global_transform = Transform3D(giro, onde)

	# A pose de partida, ja no referencial novo do corpo.
	var sk := corpo.esqueleto()
	var inv := sk.global_transform.affine_inverse()
	var modelo := {}
	for osso in PARTES:
		modelo[osso] = inv * (_pecas[osso] as RigidBody3D).global_transform
	_partida = {}
	# A pose de partida no referencial NOVO ja inclui a folga: o corpo fica onde
	# estava e escorrega ate o lugar livre junto com a mistura.
	for osso in PARTES:
		var m: Transform3D = modelo[osso]
		var pai := sk.get_bone_parent(osso)
		if pai < 0:
			_partida[osso] = m.basis.orthonormalized().get_rotation_quaternion()
			_partida[-1] = m.origin
		else:
			var mp: Transform3D = modelo[pai]
			_partida[osso] = (mp.basis.inverse() * m.basis).orthonormalized().get_rotation_quaternion()

	for osso in PARTES:
		(_pecas[osso] as RigidBody3D).queue_free()
	for filho in get_children():
		if filho is Joint3D:
			filho.queue_free()
	_pecas.clear()
	_chaves = LevantarDoChao.chaves(_de_brucos, corpo)
	_t_levantar = 0.0
	# Levanta fazendo careta: o esforco e a dor, ate o meio do caminho.
	if corpo.rosto != null:
		corpo.rosto.reagir(Rosto.Expressao.DOR,
			(MISTURA + LevantarDoChao.duracao(_chaves)) * 0.55)
	fase = Fase.LEVANTANDO
	_t_fase = 0.0
	_animar_levantar()


## O ponto livre mais perto de `onde` para uma pessoa em pe (capsula de 0,3 m
## de raio): o proprio, ou o primeiro de tres aneis de oito direcoes.
func _lugar_livre(onde: Vector3) -> Vector3:
	if not is_inside_tree():
		return onde
	var espaco := get_world_3d().direct_space_state
	var forma := CapsuleShape3D.new()
	forma.radius = 0.3
	forma.height = 1.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = 1
	var fora: Array[RID] = []
	var dono := corpo.get_parent() as CollisionObject3D
	if dono != null:
		fora.append(dono.get_rid())
	q.exclude = fora
	for raio: float in [0.0, 0.45, 0.9, 1.4]:
		for k in (1 if raio == 0.0 else 8):
			var d := Vector3(cos(k * TAU / 8.0), 0.0, sin(k * TAU / 8.0)) * raio
			# A capsula comeca 35 cm acima do chao: a guia e o degrau passam.
			q.transform = Transform3D(Basis(), onde + d + Vector3.UP * 0.95)
			if espaco.intersect_shape(q, 1).is_empty():
				return onde + d
	return onde


func _animar_levantar() -> void:
	var t := _t_levantar
	if not Corpo._luz_por_pixel():
		t = floorf(t * Corpo.POSES_POR_CICLO) / Corpo.POSES_POR_CICLO
	var total := MISTURA + LevantarDoChao.duracao(_chaves)
	if t >= total:
		_terminar()
		return
	# O caminho ate o lugar livre (`_lugar_livre`) e feito ao longo do levantar
	# inteiro, e nao na mistura: arrastado em 0,35 s o corpo patinava no chao.
	var resto := corpo.global_basis.inverse() * -_folga_de_pe
	var falta := 1.0 - smoothstep(0.0, total, t)
	var pose: Dictionary
	if t < MISTURA:
		var k := smoothstep(0.0, 1.0, t / MISTURA)
		var chave := LevantarDoChao.pose_em(_chaves, 0.0, corpo)
		chave[-1] = (chave[-1] as Vector3) + resto * falta
		pose = LevantarDoChao.misturar(_partida, chave, k)
	else:
		pose = LevantarDoChao.pose_em(_chaves, t - MISTURA, corpo)
		pose[-1] = (pose[-1] as Vector3) + resto * falta
	LevantarDoChao.aplicar(corpo, pose)


func _terminar() -> void:
	fase = Fase.FIM
	var onde := corpo.global_position
	var rumo := corpo.global_rotation.y
	corpo.top_level = false
	corpo.transform = Transform3D.IDENTITY
	corpo.dominado = false
	levantou.emit(onde, rumo)
	queue_free()


## Encerra na hora, sem levantar: o dono vai sumir (a multidao recolheu a
## pessoa) ou precisa do corpo de volta de pe ja.
func encerrar() -> void:
	if corpo != null and is_instance_valid(corpo):
		corpo.top_level = false
		corpo.transform = Transform3D.IDENTITY
		corpo.dominado = false
	fase = Fase.FIM
	queue_free()


## Onde esta o quadril agora, para o dono seguir o corpo caido.
func onde_esta() -> Vector3:
	if _pecas.has(O.QUADRIL):
		return (_pecas[O.QUADRIL] as RigidBody3D).global_position
	return corpo.global_position if corpo != null else global_position


func pecas() -> Array:
	return _pecas.values()


func peca(osso: int) -> RigidBody3D:
	return _pecas.get(osso) as RigidBody3D


func maior_pancada() -> float:
	return _maior_pancada


func de_brucos() -> bool:
	return _de_brucos


## No chao, acordado e ainda sem levantar: e quando a pessoa geme.
func gemendo() -> bool:
	return fase == Fase.CHAO and _t_fase >= _tempo_desacordado()


func desacordado() -> bool:
	return fase == Fase.CHAO and _t_fase < _tempo_desacordado()


## Onde mais doeu, e quanto (m/s da maior pancada ali): {parte, forca}.
## `parte` e uma de &"cabeca", &"tronco", &"braco_e", &"braco_d", &"perna_e",
## &"perna_d"; vazio quando nada bateu de verdade.
func onde_doi() -> Dictionary:
	var partes := {
		O.CABECA: &"cabeca", O.TORSO: &"tronco", O.QUADRIL: &"tronco",
		O.BRACO_E: &"braco_e", O.ANTEBRACO_E: &"braco_e",
		O.BRACO_D: &"braco_d", O.ANTEBRACO_D: &"braco_d",
		O.COXA_E: &"perna_e", O.CANELA_E: &"perna_e",
		O.COXA_D: &"perna_d", O.CANELA_D: &"perna_d",
	}
	var soma := {}
	for osso: int in _dor:
		var nome: StringName = partes[osso]
		soma[nome] = maxf(float(soma.get(nome, 0.0)), float(_dor[osso]))
	var melhor := &""
	var forca := 3.5
	for nome: StringName in soma:
		if float(soma[nome]) > forca:
			forca = float(soma[nome])
			melhor = nome
	if melhor == &"":
		return {}
	return {"parte": melhor, "forca": forca}

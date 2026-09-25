## A camera e o que se dirige andam a cada quadro DESENHADO, e nao a cada passo
## de fisica (PLANO_DESEMPENHO_E_HORIZONTE, Fase 1).
##
## O defeito
## ---------
## O carro e um `VehicleBody3D` e o jogador ao volante e levado ao assento no
## `_physics_process`: os dois so mudam de lugar 60 vezes por segundo. A tela
## desenha 150 ou mais. Medido em 24/09/2026 (`tests/bancada_fps_dirigir.gd`),
## a 70 km/h a camera ficava PARADA em 15 a 35% dos quadros e, no seguinte,
## saltava o passo inteiro (passo por quadro de 0 a 2x o esperado). O desfoque
## de movimento reprojeta por quadro desenhado, entao acendia so no quadro do
## salto: o borrao piscava junto com o tranco. Era o "lag com motion blur".
##
## A regra
## -------
## A interpolacao de fisica do motor (FTI) e ligada na arvore, mas a RAIZ fica
## desligada: nada no jogo muda de comportamento por isso. So interpola quem
## pede, e so pede quem e movido no passo de fisica:
##
##   `ligar_corpo`   o corpo fisico (carro, bicicleta) interpola; todos os filhos
##                   dele ficam DESLIGADOS. Filho desligado de pai interpolado
##                   segue o pai interpolado com o proprio `transform` do quadro
##                   corrente — medido: sem atraso, no mesmo quadro desenhado. Um
##                   filho LIGADO mexido em `_process` (olhar livre, limpador,
##                   ponteiro do painel) sairia com passo irregular e atrasado.
##   `ligar`         o jogador ao volante: o corpo e o pivo interpolam (os dois
##                   sao escritos no `_physics_process` do `Player`); a camera e
##                   o corpo de terceira pessoa ficam presos, desligados.
##
## O que muda para quem LE posicao
## -------------------------------
## `global_transform` continua sendo a do passo de fisica. Quem desenha alguma
## coisa em cima do quadro — o desfoque reprojetando, o marcador da HUD
## projetando um ponto, a cabine apontando a camera — tem de ler a posicao
## INTERPOLADA, senao o que desenha escorrega ate um passo por quadro em relacao
## a imagem. Para isso existem `global`, `projetar` e `atras`: com a interpolacao
## desligada devolvem exatamente o que `Camera3D`/`Node3D` devolveriam.
##
## `--sem-suavidade` desliga tudo isto: e o par da bancada (a mesma build, com e
## sem), porque a maquina muda de estado ao longo do dia e medida contra numero
## anotado nao vale.
##
## Teleporte
## ---------
## Quem poe um corpo interpolado em outro lugar chama `teleporte` depois, senao
## ele cruza o caminho num quadro. No gerado no mesmo quadro em que entra na
## arvore nao precisa (medido: nasce no lugar).
class_name Suavidade
extends RefCounted


## Liga a interpolacao na arvore com a raiz desligada. Idempotente.
static func _preparar(arvore: SceneTree) -> bool:
	if arvore == null:
		return false
	if OS.get_cmdline_user_args().has("--sem-suavidade"):
		return false
	if arvore.physics_interpolation:
		return true
	arvore.root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arvore.physics_interpolation = true
	return true


## Um corpo movido pela fisica, com tudo que esta pendurado nele preso a ele.
##
## Chame no `_ready` do corpo. Filho que entrar depois (a cabine do jogador, a
## fala do motorista) tambem nasce preso.
static func ligar_corpo(corpo: Node3D) -> void:
	if corpo == null or not corpo.is_inside_tree():
		return
	if not _preparar(corpo.get_tree()):
		return
	corpo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	for filho: Node in corpo.get_children():
		filho.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not corpo.has_meta(&"suavidade_presos"):
		corpo.set_meta(&"suavidade_presos", true)
		corpo.child_entered_tree.connect(func(filho: Node) -> void:
			filho.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF)
	corpo.reset_physics_interpolation()


## Um no que interpola enquanto algo o move na fisica (o jogador ao volante), com
## `presos` desligados. `desligar` o devolve ao que era.
static func ligar(no: Node3D, presos: Array[Node]) -> void:
	if no == null or not no.is_inside_tree():
		return
	if not _preparar(no.get_tree()):
		return
	for p: Node in presos:
		if p != null:
			p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	no.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	no.reset_physics_interpolation()


static func desligar(no: Node3D) -> void:
	if no == null:
		return
	no.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	if no.is_inside_tree():
		no.reset_physics_interpolation()


## Depois de pôr um corpo interpolado em outro lugar.
static func teleporte(no: Node) -> void:
	if no != null and no.is_inside_tree() and no.is_physics_interpolated_and_enabled():
		no.reset_physics_interpolation()


## A transformacao global como ela sai NA TELA neste quadro.
static func global(no: Node3D) -> Transform3D:
	if no == null:
		return Transform3D.IDENTITY
	if not no.is_inside_tree():
		return no.global_transform
	return no.get_global_transform_interpolated()


## A transformacao da lente como ela sai na tela: a global interpolada mais os
## deslocamentos da `Camera3D` (mesma conta de `Camera3D.get_camera_transform`).
static func lente(cam: Camera3D) -> Transform3D:
	var t := global(cam)
	if cam.h_offset != 0.0 or cam.v_offset != 0.0:
		t.origin += t.basis.x * cam.h_offset + t.basis.y * cam.v_offset
	return t


## `Camera3D.unproject_position`, pela lente interpolada.
static func projetar(cam: Camera3D, ponto: Vector3) -> Vector2:
	var tela := cam.get_viewport().get_visible_rect().size
	var local := lente(cam).affine_inverse() * ponto
	var v: Vector4 = cam.get_camera_projection() * Vector4(local.x, local.y, local.z, 1.0)
	if is_zero_approx(v.w):
		return Vector2.ZERO
	return Vector2((v.x / v.w * 0.5 + 0.5) * tela.x, (-v.y / v.w * 0.5 + 0.5) * tela.y)


## `Camera3D.is_position_behind`, pela lente interpolada.
static func atras(cam: Camera3D, ponto: Vector3) -> bool:
	var t := global(cam)
	var olho := -t.basis.z.normalized()
	return olho.dot(ponto - t.origin) < cam.near

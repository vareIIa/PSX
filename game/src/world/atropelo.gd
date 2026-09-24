## Carro contra gente: quem esta sendo atingido, por quem e a que velocidade.
##
## Dividido entre o `Pedestre` e o `TomboDoJogador` — a conta e a mesma, e duas
## copias dela divergiriam no primeiro ajuste (a primeira coisa que mudou aqui
## foi o empurrao passar a usar a velocidade do carro, e nao a relativa).
##
## A caixa do carro e a propria forma de colisao dele, crescida pelo raio da
## pessoa, e o teste olha tambem onde ela estara dois quadros a frente: a IA
## escreve a posicao do carro direto (corpo congelado) e o do jogador chega a
## 20 m/s; esperar o contato do motor seria descobrir a batida um quadro depois
## de a capsula ter feito o carro bater num poste.
class_name Atropelo
extends RefCounted

## A que distancia comeca a olhar (m).
const RAIO := 7.0
const ALTURA_PESSOA := 1.8
## Rastro dos carros congelados: a IA escreve a posicao e o motor nao sabe a
## velocidade. Um registro por carro para todos que perguntam, atualizado uma
## vez por quadro de fisica.
static var _rastro := {}


## O carro que esta atingindo quem esta em `pos` (com velocidade `vel` e raio
## `raio`), ou vazio. Devolve {carro, rel (velocidade do carro menos a da
## pessoa, no plano), vc (velocidade do carro)}.
static func quem_bate(arvore: SceneTree, pos: Vector3, vel: Vector3, raio: float,
		delta: float, excluir: Node = null) -> Dictionary:
	for n: Node in arvore.get_nodes_in_group(&"carro"):
		var carro := n as Node3D
		if carro == null or not is_instance_valid(carro) or carro == excluir:
			continue
		var perto := carro.global_position - pos
		if perto.length_squared() > RAIO * RAIO:
			continue
		var caixa := caixa_do_carro(carro)
		if caixa.size == Vector3.ZERO:
			continue
		var vc := velocidade_do_carro(carro)
		var rel := vc - vel
		rel.y = 0.0
		if rel.length() < 0.6:
			continue
		var inv := carro.global_transform.affine_inverse()
		var meia := caixa.size * 0.5 + Vector3(raio, 0.0, raio)
		var centro := caixa.position + caixa.size * 0.5
		var dentro := false
		for olhar: float in [0.0, delta * 2.0]:
			# O pe da pessoa, no referencial do carro. A altura conta como faixa
			# (do pe a cabeca contra a caixa inteira), e nao como um ponto: na
			# ladeira, e com o jogador empurrado para cima do para-choque, um
			# ponto a 60 cm saia da caixa e o carro levava a pessoa junto sem
			# ninguem cair.
			var p := inv * (pos + rel * -olhar)
			if absf(p.x - centro.x) < meia.x and absf(p.z - centro.z) < meia.z \
					and p.y < caixa.end.y + 0.2 and p.y + ALTURA_PESSOA > caixa.position.y - 0.1:
				dentro = true
				break
		# So conta se o carro vem PARA a pessoa.
		if dentro and rel.dot(-perto) > 0.0:
			return {"carro": carro, "rel": rel, "vc": vc}
	return {}


## A forma de colisao do carro no referencial dele (a primeira caixa entre os
## filhos), guardada no proprio carro: ela nao muda depois de montada.
static func caixa_do_carro(carro: Node3D) -> AABB:
	if carro.has_meta(&"_caixa_atropelo"):
		return carro.get_meta(&"_caixa_atropelo")
	var saida := AABB()
	for filho in carro.get_children():
		var f := filho as CollisionShape3D
		if f != null and f.shape is BoxShape3D:
			var t := (f.shape as BoxShape3D).size
			saida = AABB(f.position - t * 0.5, t)
			break
	carro.set_meta(&"_caixa_atropelo", saida)
	return saida


## A velocidade do carro no mundo. O do jogador tem fisica; o da IA e escrito
## por posicao (congelado), e a velocidade sai de onde ele estava no quadro
## anterior.
static func velocidade_do_carro(carro: Node3D) -> Vector3:
	var corpo := carro as RigidBody3D
	if corpo != null and not corpo.freeze:
		return corpo.linear_velocity
	var id := carro.get_instance_id()
	var quadro := Engine.get_physics_frames()
	var r: Array = _rastro.get(id, [])
	if r.is_empty():
		_rastro[id] = [quadro, carro.global_position, Vector3.ZERO]
		return Vector3.ZERO
	if int(r[0]) == quadro:
		return r[2]
	var dt := float(quadro - int(r[0])) / float(Engine.physics_ticks_per_second)
	var v := (carro.global_position - (r[1] as Vector3)) / maxf(dt, 0.001)
	if v.length() > 60.0:
		# Teletransporte (o carro foi plantado noutro lugar), nao velocidade.
		v = Vector3.ZERO
	_rastro[id] = [quadro, carro.global_position, v]
	return v


## Golpe de atropelo: o para-choque leva as canelas na velocidade do carro, e o
## capo levanta o resto um pouco — a componente para cima e o que joga o corpo
## em cima do capo em vez de na frente das rodas.
static func golpe(rel: Vector3) -> Vector3:
	return rel + Vector3.UP * minf(rel.length() * 0.22, 3.5)


## Quao feia foi a pancada, de 0 a 1, pela rapidez relativa (m/s).
static func pancada(v: float) -> float:
	return clampf(v / 14.0, 0.3, 1.0)


## O carro sente o corpo: setenta quilos contra uma tonelada, um tranco pequeno
## — sem ele o atropelo passa pelo volante como se fosse vento.
static func tranco_no_carro(carro: Node3D, rel: Vector3, massa: float) -> void:
	var rigido := carro as RigidBody3D
	if rigido != null and not rigido.freeze:
		rigido.apply_central_impulse(-rel.normalized() * massa * rel.length() * 0.35)

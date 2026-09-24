## A lataria que o corpo atropelado sente: capo, para-brisa, teto, porta-malas.
##
## A colisao do `Carro` e UMA caixa da soleira ao teto (`Carro._montar_colisao`)
## — certa para o carro bater em muro, errada para gente: de frente ela e uma
## parede andando, e quem e atropelado a 40 km/h vai empurrado na frente do
## para-choque em vez de subir no capo, bater no para-brisa e rolar por cima do
## teto, que e a imagem do atropelo no GTA IV.
##
## Aqui o carro ganha, SO PARA AS PECAS DO BONECO, um perfil de sedan em quatro
## caixas, num AnimatableBody3D que segue o carro quadro a quadro (e passa a
## velocidade dele no contato, como corpo cinematico faz). As pecas deixam de
## colidir com a caixa do carro enquanto este perfil existe. Some sozinho quando
## o corpo sai de perto, ou em TEMPO.
##
## Proporcoes de sedan medidas na propria Carroceria de caixa: capo a 52% da
## altura, 30% do comprimento; para-brisa ate 45%; porta-malas nos ultimos 22%.
class_name LatariaParaCorpo
extends AnimatableBody3D

const TEMPO := 6.0

var carro: Node3D
var _t := 0.0


## Cria o perfil do `carro` e tira a caixa dele do caminho das `pecas`.
static func criar(alvo: Node3D, caixa: AABB, pecas: Array) -> LatariaParaCorpo:
	var l := LatariaParaCorpo.new()
	l.name = "LatariaParaCorpo"
	l.carro = alvo
	l.collision_layer = BonecoDePano.CAMADA
	l.collision_mask = 0
	l.sync_to_physics = true
	l.top_level = true
	# A transformada entra ANTES da arvore. Posta depois, o corpo nascia na
	# origem do mundo e "teleportava" ate o carro no primeiro quadro; corpo
	# cinematico passa essa velocidade no contato, e a regua viu o atropelado
	# sair a 73 m/s para tras e cair a 82 m dali.
	l.transform = alvo.global_transform
	l._montar(caixa)
	alvo.add_child(l)
	for p: Node in pecas:
		var peca := p as RigidBody3D
		if peca != null and alvo is PhysicsBody3D:
			peca.add_collision_exception_with(alvo)
	l.tree_exiting.connect(func() -> void:
		if not is_instance_valid(alvo) or not alvo is PhysicsBody3D:
			return
		for p: Variant in pecas:
			# Checa ANTES de tipar: atribuir peca ja liberada a variavel tipada e
			# erro de script (as pecas somem quando a pessoa comeca a levantar).
			if is_instance_valid(p):
				(p as RigidBody3D).remove_collision_exception_with(alvo))
	return l


func _montar(caixa: AABB) -> void:
	var w := caixa.size.x
	var h := caixa.size.y
	var comp := caixa.size.z
	var y0 := caixa.position.y
	var z0 := caixa.position.z
	var x0 := caixa.position.x + w * 0.5
	var capo_h := h * 0.52
	var capo_fim := comp * 0.30
	var teto_ini := comp * 0.45
	var mala_ini := comp * 0.78
	# Frente e -Z: a caixa comeca em z0 (a frente) e vai ate z0 + comp.
	_caixa(Vector3(w, capo_h, capo_fim), Vector3(x0, y0 + capo_h * 0.5, z0 + capo_fim * 0.5))
	_caixa(Vector3(w, h, mala_ini - teto_ini), Vector3(x0, y0 + h * 0.5,
		z0 + (teto_ini + mala_ini) * 0.5))
	_caixa(Vector3(w, h * 0.62, comp - mala_ini), Vector3(x0, y0 + h * 0.31,
		z0 + (mala_ini + comp) * 0.5))
	# Para-brisa: placa inclinada do fim do capo ao comeco do teto.
	var de := Vector3(0.0, y0 + capo_h, z0 + capo_fim)
	var ate := Vector3(0.0, y0 + h, z0 + teto_ini)
	var meio := (de + ate) * 0.5
	var inclinacao := atan2(ate.y - de.y, ate.z - de.z)
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(w * 0.96, 0.12, de.distance_to(ate) + 0.1)
	f.shape = b
	f.transform = Transform3D(Basis(Vector3.RIGHT, -inclinacao), Vector3(x0, meio.y - 0.06, meio.z))
	add_child(f)
	# O vao embaixo do para-brisa, para o corpo nao entrar por baixo da placa.
	_caixa(Vector3(w, h - capo_h - 0.1, (teto_ini - capo_fim) * 0.6),
		Vector3(x0, y0 + capo_h + (h - capo_h - 0.1) * 0.5, z0 + teto_ini - (teto_ini - capo_fim) * 0.3))


func _caixa(tamanho: Vector3, centro: Vector3) -> void:
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tamanho
	f.shape = b
	f.position = centro
	add_child(f)


func _physics_process(delta: float) -> void:
	_t += delta
	if carro == null or not is_instance_valid(carro) or _t > TEMPO:
		queue_free()
		return
	global_transform = carro.global_transform

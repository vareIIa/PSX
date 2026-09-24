## Quem pediu pelo iWeed, esperando no ponto de encontro.
##
## E uma pessoa de verdade do registro civil — a mesma ficha, o mesmo rosto que
## o portal e o Trampo mostram —, parada no orelhao ou na porta do bar entre as
## horas combinadas. O jogador chega, aperta [E], e a troca acontece em maos: o
## item sai do inventario, o dinheiro entra, a pessoa fuma ali mesmo e o efeito
## da Super, quando e Super, acontece na frente de quem entregou.
##
## Nao e um Pedestre: nao anda pela cidade, nao entra na multidao e nao some
## quando a camera vira. Espera. Tem `ficha` e `velocity` com os mesmos nomes do
## Pedestre so para a cena da equipe (EntregasDaSuper.encenar) servir aos dois.
class_name ClienteIWeed
extends Node3D

const MATERIAL_LUZ := "res://resources/materials/mat_estufa_luz.tres"
const VERDE := Color(0.45, 1.0, 0.6)

var ficha: Dictionary = {}
var velocity := Vector3.ZERO
var pedido := -1

var _corpo: Corpo
var _interativo: Interativo
var _marcador: Node3D
var _corpo_fisico: StaticBody3D
var _ocupado := false
var _saindo := false
var _alvo := Vector3.INF
var _t := 0.0
var _chao_ok := false
var _giro_alvo := 0.0


## `onde` e o ponto do iWeed (a altura dele pode ser a do chunk, nao a do chao
## com relevo); o chao de verdade vem de um raio assim que houver colisao.
func preparar(f: Dictionary, n: int, onde: Vector3, do_jogador: bool,
		_chegando: bool) -> void:
	ficha = f
	pedido = n
	global_position = onde
	_corpo = Corpo.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	_corpo.montar(f.get("aparencia", {}))
	# O jeito da pessoa: como anda, fica parada e mexe as maos (ver `Jeito`).
	_corpo.jeito = Jeito.de(f)
	_giro_alvo = randf() * TAU
	rotation.y = _giro_alvo

	_corpo_fisico = StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.28
	capsula.height = 1.7
	forma.shape = capsula
	forma.position = Vector3(0.0, 0.85, 0.0)
	_corpo_fisico.add_child(forma)
	add_child(_corpo_fisico)
	# Carro e esbarrao derrubam o cliente como a qualquer pedestre.
	var tombo := TomboDeCorpo.ligar(_corpo, self)
	tombo.colisao = _corpo_fisico

	if do_jogador:
		_interativo = Interativo.new()
		_interativo.name = "Entregar"
		var p := IWeed.pedido(n)
		_interativo.rotulo = "Entregar %dx %s (%s)" % [int(p.get("qtd", 1)),
			IWeed.nome_do_produto(String(p.get("produto", ""))).capitalize(),
			Dinheiro.formatar(int(p.get("preco", 0)))]
		var area := CollisionShape3D.new()
		var cil := CylinderShape3D.new()
		cil.radius = 0.55
		cil.height = 1.9
		area.shape = cil
		area.position = Vector3(0.0, 0.95, 0.0)
		_interativo.add_child(area)
		add_child(_interativo)
		_interativo.acionado.connect(_ao_acionar)
		_montar_marcador()
	_assentar()


## Losango verde aceso acima da cabeca, girando. Diz "e este aqui" de longe, na
## nevoa, sem precisar de seta de HUD apontando para uma pessoa.
##
## Octaedro de verdade, com material proprio sem nevoa. A primeira versao usava
## duas placas do atlas com o material de luz da estufa: a nevoa as lavava de
## branco e a cinco metros o losango era um risco claro que ninguem via.
func _montar_marcador() -> void:
	_marcador = Node3D.new()
	_marcador.name = "Marcador"
	add_child(_marcador)
	_marcador.position = Vector3(0.0, 2.3, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _octaedro(0.13, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = VERDE
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marcador.add_child(mi)
	# Contorno escuro um pouco maior, por tras: sem ele o verde some contra o
	# ceu claro da nevoa de dia.
	var borda := MeshInstance3D.new()
	borda.mesh = _octaedro(0.16, 0.245)
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.albedo_color = Color(0.03, 0.12, 0.06)
	mb.disable_fog = true
	mb.cull_mode = BaseMaterial3D.CULL_FRONT
	borda.material_override = mb
	borda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marcador.add_child(borda)


static func _octaedro(raio: float, meia_altura: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cima := Vector3(0.0, meia_altura, 0.0)
	var baixo := Vector3(0.0, -meia_altura, 0.0)
	var anel: Array[Vector3] = [Vector3(raio, 0, 0), Vector3(0, 0, raio),
		Vector3(-raio, 0, 0), Vector3(0, 0, -raio)]
	for k in 4:
		var a := anel[k]
		var b := anel[(k + 1) % 4]
		st.add_vertex(cima)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(baixo)
		st.add_vertex(b)
		st.add_vertex(a)
	st.generate_normals()
	return st.commit()


## Pousa no chao com um raio de cima para baixo. O ponto do iWeed vem com a
## altura do chunk, e com o relevo dos morros isso pode estar metros acima ou
## abaixo da calcada.
func _assentar() -> void:
	var espaco := get_world_3d().direct_space_state if is_inside_tree() else null
	if espaco == null:
		return
	var de := global_position + Vector3(0.0, 40.0, 0.0)
	var ate := global_position - Vector3(0.0, 40.0, 0.0)
	var q := PhysicsRayQueryParameters3D.create(de, ate, 1)
	q.exclude = [_corpo_fisico.get_rid()]
	var hit := espaco.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y
		_chao_ok = true


func _process(delta: float) -> void:
	_t += delta
	if not _chao_ok and fmod(_t, 0.5) < delta:
		_assentar()
	if _marcador != null:
		_marcador.rotation.y += delta * 1.6
		_marcador.position.y = 2.25 + sin(_t * 2.2) * 0.06
	# Em cena, quem mexe no corpo e a cena (EntregasDaSuper anima os dois).
	if _ocupado and not _saindo:
		return
	var tombo := TomboDeCorpo.de(_corpo)
	if tombo != null and tombo.ocupado():
		_corpo.animar(tombo.rapidez(), delta)
		return
	var rapidez := 0.0
	if _saindo and _alvo != Vector3.INF:
		var d := _alvo - global_position
		d.y = 0.0
		if d.length() < 0.2:
			queue_free()
			return
		velocity = d.normalized() * 1.3
		global_position += velocity * delta
		_giro_alvo = atan2(-d.x, -d.z)
		rapidez = 1.3
	elif not _ocupado:
		# Esperando: vira para o jogador quando ele chega perto, e olha em volta
		# de vez em quando, como quem espera alguem que esta atrasado.
		var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
		if jogador != null:
			var d := jogador.global_position - global_position
			d.y = 0.0
			if d.length() < 7.0:
				_giro_alvo = atan2(-d.x, -d.z)
		if fmod(_t, 5.0) < delta and _corpo != null:
			_corpo.olhar_lateral(randf_range(-0.6, 0.6))
	rotation.y = lerp_angle(rotation.y, _giro_alvo, 1.0 - exp(-delta * 5.0))
	if _corpo != null:
		_corpo.animar(rapidez, delta)


func _ao_acionar(_quem: Node) -> void:
	if _ocupado or _saindo:
		return
	var iw := IWeed.instancia()
	if iw != null:
		iw.entregue_pelo_jogador(pedido, self)


func _nome() -> String:
	return IWeed.nome_curto(int(ficha.get("id", 0))).to_upper()


## Diz a linha com voz e gesto pela `Fala`, e devolve quanto ela dura. Antes
## era legenda muda e o corpo gesticulando um tempo fixo, fosse a linha de duas
## palavras ou de vinte.
func _falar(fala: String) -> float:
	var f := get_node_or_null(^"Fala") as Fala
	if f == null:
		f = Fala.new()
		f.name = "Fala"
		add_child(f)
		var voz := Voz.new()
		voz.name = "Voz"
		add_child(voz)
		voz.configurar(ficha)
		voz.position = Vector3(0.0, _corpo.altura_da_boca() if _corpo != null else 1.5, 0.0)
		f.voz = voz
		if _corpo != null:
			var corpos: Array[Corpo] = [_corpo]
			f.corpos = corpos
			f.rosto = _corpo.rosto
		f.cadencia = float(Personalidade.de(int(ficha.get("personalidade", 0)))["cadencia"])
	return f.dizer(fala)


## Faltou mercadoria. A pessoa reclama e continua esperando.
func reclamar(fala: String) -> void:
	Cinema.fala("%s: %s" % [_nome(), fala])
	AudioDirector.tocar_ui(&"celular_erro", -12.0)
	_falar(fala)


## A troca em maos. Devolve quando a pessoa terminou de falar.
func receber(fala: String, _produto: String) -> void:
	_ocupado = true
	if _interativo != null:
		_interativo.habilitado = false
		_interativo.queue_free()
		_interativo = null
	if _marcador != null:
		_marcador.queue_free()
		_marcador = null
	AudioDirector.tocar(&"pegar", global_position + Vector3(0.0, 1.0, 0.0), -4.0)
	Cinema.fala("%s: %s" % [_nome(), fala])
	var dura := maxf(1.2, _falar(fala))
	var t := 0.0
	while t < dura and is_instance_valid(_corpo):
		var delta := get_process_delta_time()
		t += delta
		_corpo.animar(0.0, delta)
		await get_tree().process_frame
	if is_instance_valid(_corpo):
		_corpo.falar(false)


## Vai embora a pe, para longe do jogador, e some. Quem explodiu ou voou ja nao
## esta visivel: some na hora.
func ir_embora() -> void:
	if _saindo:
		return
	_saindo = true
	_ocupado = true
	if _interativo != null:
		_interativo.queue_free()
		_interativo = null
	if _marcador != null:
		_marcador.queue_free()
		_marcador = null
	if not visible:
		queue_free()
		return
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var longe := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if jogador != null:
		longe = global_position - jogador.global_position
	longe.y = 0.0
	if longe.length() < 0.1:
		longe = Vector3.FORWARD
	_alvo = global_position + longe.normalized() * 16.0
	if _corpo != null:
		_corpo.postura(Corpo.Postura.LIVRE)
		_corpo.olhar_lateral(0.0)
	# Rede de seguranca: parede no caminho nao deixa ninguem parado para sempre.
	get_tree().create_timer(14.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


## A cena da equipe vai comecar: daqui em diante o corpo e dela.
func ocupar() -> void:
	_ocupado = true


func esperando() -> bool:
	return not _ocupado and not _saindo

## Uma tomada de parede dos interiores, e o carregador do iPhone ligado nela.
##
## O que se faz aqui
## -----------------
## Tudo pela mesma tecla, conforme o estado:
##   - tomada vazia, com o carregador na bolsa: [E] liga o cubo branco nela;
##   - carregador ligado: [E] pluga o iPhone. O fio (`CaboFisico`, 2 m, o de 30
##     pinos) vai do cubo ate o bolso do personagem — ou ate o aparelho, quando
##     ele esta na mao: o fio pende do conector de baixo e balanca com a mao;
##   - plugado: [E] deixa o iPhone deitado no chao, carregando. Sem ele no bolso
##     o `C` nao tira nada; [E] de novo o pega;
##   - andar para longe com ele plugado estica o fio, e o plugue salta do
##     aparelho (e o conector mais fraco da corrente, como na vida). O plugue
##     fica caido no chao, na ponta do fio: [E] nele guarda o carregador.
## Sair do interior leva tudo junto: o carregador volta para a bolsa e o
## aparelho para o bolso.
##
## A tomada e a 2P+T brasileira (NBR 14136), a 30 cm do chao: o espelho branco
## de 4x2, o rebaixo redondo e os tres furos.
class_name Tomada
extends Interativo

## Espelho: largura, altura, espessura (m).
const ESPELHO := Vector3(0.056, 0.100, 0.006)
const REBAIXO_R := 0.020
## O cubo do carregador (o de 5 W da Apple tem 28 mm).
const CUBO := 0.028
## O fio. O original da Apple tem 1 m, e do bolso (a 93 cm do chao) ate uma
## tomada baixa ele so alcanca com o personagem encostado na parede; 2 m e o fio
## de reposicao de camelo, e o que deixa usar o aparelho de pe ao lado dela.
const FIO := 2.0
## A partir de quanto alem do comprimento o plugue salta do aparelho.
const ESTICA := 1.05
## Onde o aparelho fica no chao, a partir da tomada (m, para dentro do comodo).
const NO_CHAO := 0.42
## O bolso da calca, no espaco do jogador (os pes na origem).
const BOLSO := Vector3(0.17, 0.93, -0.02)

enum Estado { VAZIA, LIGADO, PLUGADO, POUSADO }

var estado: Estado = Estado.VAZIA

var _cubo: Node3D
var _cabo: CaboFisico
var _plugue: MeshInstance3D
var _bolso: Node3D
var _pousado: IphoneDeJogo
var _solto: Interativo
var _mat_branco: StandardMaterial3D
## Quando o aparelho foi plugado (ms): o fio leva um instante para assentar.
var _plugou_em: int = 0


## Uma tomada a partir do prop do interior: `pos` na face da parede, `giro` para
## onde ela olha (a tomada olha para +Z antes do giro).
static func criar(prop: Dictionary) -> Tomada:
	var t := Tomada.new()
	t.name = "Tomada"
	t.position = prop["pos"]
	t.rotation.y = float(prop.get("giro", 0.0))
	t._montar()
	return t


func _montar() -> void:
	_mat_branco = StandardMaterial3D.new()
	_mat_branco.albedo_color = Color("f3f2ec")
	_mat_branco.roughness = 0.42
	var bege := StandardMaterial3D.new()
	bege.albedo_color = Color("e4dfd0")
	bege.roughness = 0.6
	var furo := StandardMaterial3D.new()
	furo.albedo_color = Color("1c1a18")
	furo.roughness = 1.0
	_caixa(self, ESPELHO, Vector3(0.0, 0.0, ESPELHO.z * 0.5), _mat_branco)
	var reb := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = REBAIXO_R
	cil.bottom_radius = REBAIXO_R
	cil.height = 0.004
	cil.radial_segments = 24
	reb.mesh = cil
	reb.material_override = bege
	reb.rotation.x = PI * 0.5
	reb.position = Vector3(0.0, 0.0, ESPELHO.z + 0.0005)
	add_child(reb)
	# Os tres furos: fase e neutro lado a lado, e o terra acima, no meio.
	for f: Vector2 in [Vector2(-0.0095, -0.003), Vector2(0.0095, -0.003), Vector2(0.0, 0.009)]:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0022
		c.bottom_radius = 0.0022
		c.height = 0.0012
		c.radial_segments = 10
		mi.mesh = c
		mi.material_override = furo
		mi.rotation.x = PI * 0.5
		mi.position = Vector3(f.x, f.y, ESPELHO.z + 0.0025)
		add_child(mi)
	# A area de acionar: na frente da tomada, larga, descendo ate o chao — quem
	# olha para o fio ou para o aparelho no chao tambem acha a tomada.
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.5, 0.45, 0.6)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.08, 0.3)
	add_child(forma)


static func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	pai.add_child(mi)
	return mi


# --- o que a tecla faz ----------------------------------------------------------

func rotulo_atual() -> String:
	match estado:
		Estado.VAZIA:
			return "Ligar o carregador" if Inventario.tem(&"carregador") else "Tomada"
		Estado.LIGADO:
			return "Plugar o iPhone" if not Celular.longe else "Tomada"
		Estado.PLUGADO:
			return "Deixar o iPhone carregando"
		Estado.POUSADO:
			return "Pegar o iPhone"
	return ""


func interagir(quem: Node) -> void:
	if not habilitado:
		return
	match estado:
		Estado.VAZIA:
			if Inventario.tem(&"carregador") and Inventario.remover(&"carregador", 1):
				_ligar_cubo()
				AudioDirector.tocar_ui(&"clique", -10.0, 0.7)
		Estado.LIGADO:
			if not Celular.longe:
				_plugar(quem as Node3D)
		Estado.PLUGADO:
			_pousar()
		Estado.POUSADO:
			_pegar(quem as Node3D)
	acionado.emit(quem)


## O cubo entra na tomada, e o fio cai dele ate o chao, com o plugue na ponta.
func _ligar_cubo() -> void:
	estado = Estado.LIGADO
	_cubo = Node3D.new()
	_cubo.name = "Carregador"
	add_child(_cubo)
	_cubo.position = Vector3(0.0, 0.0, ESPELHO.z + CUBO * 0.5 + 0.001)
	_caixa(_cubo, Vector3(CUBO, CUBO, CUBO), Vector3.ZERO, _mat_branco)
	# A porta USB na face de baixo, e o plugue USB do fio nela.
	_caixa(_cubo, Vector3(0.012, 0.004, 0.009), Vector3(0.0, -CUBO * 0.5 - 0.002, 0.004), _mat_branco)
	_cabo = CaboFisico.new()
	_cabo.comprimento = FIO
	_cabo.ponta_a = _cubo
	_cabo.local_a = Vector3(0.0, -CUBO * 0.5 - 0.005, 0.004)
	_cabo.saida_a = Vector3.DOWN
	_cabo.chao = _chao()
	_cabo.deita_para = global_transform.basis.z
	# A parede da tomada: o fio desce rente a ela, e nao por dentro.
	var n := global_transform.basis.z.normalized()
	_cabo.paredes = [Plane(n, global_position)]
	add_child(_cabo)
	_cabo.recomecar()
	_cabo.esticou.connect(_ao_esticar)
	_plugue = _caixa(self, Vector3(0.021, 0.016, 0.0058), Vector3.ZERO, _mat_branco)
	_plugue.top_level = true
	_plugue_solto(true)


## O plugue de 30 pinos solto no fim do fio, e a area para guarda-lo.
func _plugue_solto(sim: bool) -> void:
	if sim and _solto == null:
		_solto = PlugueSolto.new()
		_solto.tomada = self
		var forma := CollisionShape3D.new()
		var esfera := SphereShape3D.new()
		esfera.radius = 0.14
		forma.shape = esfera
		_solto.add_child(forma)
		add_child(_solto)
		_solto.top_level = true
	elif not sim and _solto != null:
		_solto.queue_free()
		_solto = null


## O iPhone no fio: a ponta vai para o bolso (ou para a mao, se ele subir).
func _plugar(jogador: Node3D) -> void:
	if jogador == null:
		return
	estado = Estado.PLUGADO
	_bolso = Node3D.new()
	_bolso.name = "BolsoDoFio"
	jogador.add_child(_bolso)
	_bolso.position = BOLSO
	_plugue_solto(false)
	_cabo.ponta_b = _bolso
	_cabo.local_b = Vector3.ZERO
	_cabo.saida_b = Vector3.UP
	_plugou_em = Time.get_ticks_msec()
	Celular.conectar(self)


## Deixa o aparelho deitado no chao, na frente da tomada, com a tela para cima.
func _pousar() -> void:
	if Celular.ativo:
		Celular.fechar()
	estado = Estado.POUSADO
	_pousado = IphoneDeJogo.new()
	_pousado.name = "IphoneCarregando"
	add_child(_pousado)
	_pousado.top_level = true
	var frente := global_transform.basis.z.normalized()
	var p := global_position + frente * NO_CHAO
	p.y = _chao() + IphoneDeJogo.TAMANHO.z * 0.5 + 0.001
	# Deitado, com o conector virado para a tomada.
	var y := frente
	var z := Vector3.UP
	_pousado.global_transform = Transform3D(Basis(y.cross(z).normalized(), y, z), p)
	_pousado.brilho(0.0)
	_liberar_bolso()
	_cabo.ponta_b = _pousado
	_cabo.local_b = Vector3(0.0, -IphoneDeJogo.TAMANHO.y * 0.5 - 0.004, 0.0)
	_cabo.saida_b = Vector3.DOWN
	Celular.longe = true
	AudioDirector.tocar_ui(&"clique", -16.0, 0.9)


func _pegar(jogador: Node3D) -> void:
	if _pousado != null:
		_pousado.queue_free()
		_pousado = null
	Celular.longe = false
	_plugar(jogador)
	AudioDirector.tocar_ui(&"clique", -16.0, 1.1)


## O piso do comodo, no mundo: o interior mora dois mil metros acima da cidade,
## e a tomada fica sempre a `PontosDeTomada.ALTURA` dele.
func _chao() -> float:
	return global_position.y - PontosDeTomada.ALTURA


func _liberar_bolso() -> void:
	if _bolso != null and is_instance_valid(_bolso):
		_bolso.queue_free()
	_bolso = null


## Esticou alem do fio: o plugue salta do aparelho e cai.
func _ao_esticar(tensao: float) -> void:
	if estado != Estado.PLUGADO or tensao < ESTICA or Time.get_ticks_msec() - _plugou_em < 500:
		return
	_desplugar()
	AudioDirector.tocar_ui(&"clique", -6.0, 0.6)
	Celular.vibrar(0.1)


func _desplugar() -> void:
	estado = Estado.LIGADO
	_liberar_bolso()
	_cabo.ponta_b = null
	_plugue_solto(true)
	Celular.desconectar(self)


## Pelo plugue caido: puxa o cubo da tomada e guarda tudo na bolsa.
func guardar_carregador() -> void:
	if estado != Estado.LIGADO:
		return
	if Inventario.adicionar(&"carregador", 1) > 0:
		return
	_desmontar_cubo()
	AudioDirector.tocar_ui(&"clique", -10.0, 0.8)


func _desmontar_cubo() -> void:
	_plugue_solto(false)
	for no: Node in [_cubo, _cabo, _plugue]:
		if no != null and is_instance_valid(no):
			no.queue_free()
	_cubo = null
	_cabo = null
	_plugue = null
	estado = Estado.VAZIA


func _process(_delta: float) -> void:
	if _cabo == null:
		return
	# Com o aparelho na mao, o fio sai do conector dele; no bolso, do bolso.
	if estado == Estado.PLUGADO:
		var fone := Celular.fone_na_mao()
		if fone != null:
			_cabo.ponta_b = fone
			_cabo.local_b = Vector3(0.0, -IphoneDeJogo.TAMANHO.y * 0.5 - 0.004, 0.0)
			_cabo.saida_b = Vector3.DOWN
		elif _bolso != null:
			_cabo.ponta_b = _bolso
			_cabo.local_b = Vector3.ZERO
			_cabo.saida_b = Vector3.UP
	# O plugue de 30 pinos na ponta do fio, na direcao dele.
	if _plugue != null:
		var d := _cabo.direcao_b()
		var p := _cabo.ponto_b() + d * 0.008
		var lado := d.cross(Vector3.UP)
		if lado.length_squared() < 1e-4:
			lado = Vector3.RIGHT
		lado = lado.normalized()
		_plugue.global_transform = Transform3D(Basis(lado, d, lado.cross(d).normalized()), p)
		if _solto != null:
			_solto.global_position = p


## Saindo do interior: o carregador volta para a bolsa, o aparelho para o bolso.
func _exit_tree() -> void:
	if estado == Estado.PLUGADO or estado == Estado.POUSADO:
		Celular.desconectar(self)
	if estado == Estado.POUSADO:
		Celular.longe = false
	if estado != Estado.VAZIA:
		Inventario.adicionar(&"carregador", 1)
	_liberar_bolso()


## O plugue caido no chao, na ponta do fio.
class PlugueSolto:
	extends Interativo
	var tomada: Tomada

	func rotulo_atual() -> String:
		return "Guardar o carregador"

	func interagir(quem: Node) -> void:
		if tomada != null and is_instance_valid(tomada):
			tomada.guardar_carregador()
		acionado.emit(quem)

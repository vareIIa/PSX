## O padre na janela do motorista batendo a cabeca no vidro: a camada de pose
## que vai por cima do `Corpo` e do `TiqueMacabro` a cada quadro.
##
## Por que existe
## --------------
## O `Corpo` sabe ficar curvado na janela e o tique sabe estalar o pescoco, mas
## nenhum dos dois sabe onde o vidro esta. Uma cabecada que para um palmo antes
## do vidro, ou que o atravessa, acaba com a cena: o sangue tem de nascer
## exatamente onde a testa encostou.
##
## Como funciona
## -------------
## A cena anima quatro numeros (com tween), e esta camada os transforma em pose:
##
##   encara     0 a 1: a cabeca gira ate a cara apontar para a lente
##   recua      0 a 1: a antecipacao — tronco e cabeca para tras, o queixo sobe
##   bote       0 a 1: o golpe — tronco para a frente, o queixo recolhido
##   distancia  metros da TESTA ao vidro (para fora); INF deixa o corpo onde esta
##
## e `tombo`, a cabeca deitada de lado (rad), que o sorriso usa.
##
## A distancia e quem manda no corpo: depois de girar tronco e cabeca, a testa
## e medida no esqueleto, e o corpo inteiro anda na normal do vidro o que
## faltar para ela ficar a `distancia` pedida. Com a distancia chegando a zero
## no fim do golpe, a testa encosta no vidro no quadro certo, qualquer que seja
## o giro — e o giro pode ser o que o golpe pedir.
##
## O queixo recolhido nao e estilo: o nariz da criatura fica 2,3 cm a frente da
## testa (`tools/gerar_padre.py`); so com a cabeca inclinada mais de ~23 graus
## para a frente e a testa quem chega primeiro.
class_name CabecadaDoPadre
extends RefCounted

## A testa no espaco da malha da cabeca (`CabecaDoPadre`, rosto para -Z): o
## osso da fronte, acima das sobrancelhas. Medida na malha: a frente da pele
## em y = 0,05 esta em z = -0,086.
const TESTA := Vector3(0.0, 0.052, -0.088)
## Giro do queixo (rad, no osso da cabeca: + sobe e vai para tras) na
## antecipacao e no golpe, e do tronco.
const QUEIXO_RECUA := 0.38
const QUEIXO_BOTE := -0.48
const TRONCO_RECUA := 0.20
const TRONCO_BOTE := -0.16
## O quanto o pescoco gira no maximo para a cara achar a lente (rad): com a
## cabeca ja dentro da cabine, o giro inteiro torcia o pescoco do avesso.
const ENCARA_MAX := 0.95
## O vidro, para o pano: uma esfera deste raio (m) do lado de dentro, com a
## superficie no plano do vidro. O pano so sabe colidir com capsula; a meio
## metro do centro da janela a esfera sai do plano 9 mm, e o capuz nunca
## chega tao longe.
const VIDRO_RAIO := 14.0
const LONGE := Vector3(0.0, -1000.0, 0.0)

var encara: float = 0.0
var recua: float = 0.0
var bote: float = 0.0
var distancia: float = INF
var tombo: float = 0.0
## A testa colada escorregando no vidro, para baixo (m): o arrasto do sangue.
var escorrega: float = 0.0
## Enquanto o vidro existe, o capuz de pano bate nele e para (`prender_pano`).
var vidro_existe: bool = true

var _c: Corpo
var _cab: Node3D
var _cam: Camera3D
## O plano do vidro no espaco do pai do corpo (o carro): um ponto e a normal
## para fora.
var _o := Vector3.ZERO
var _n := Vector3.LEFT
var _base := Vector3.ZERO
var _desloca := 0.0
var _pano: PanoGPU
var _col := -1


func _init(corpo: Corpo, rosto: Node3D, cam: Camera3D, vidro_o: Vector3,
		vidro_n: Vector3) -> void:
	_c = corpo
	_cab = rosto
	_cam = cam
	_o = vidro_o
	_n = vidro_n.normalized()
	_base = corpo.position


## O capuz de pano passa a colidir com o vidro. Com a cabeca inclinada para o
## golpe, a borda de cima dele fica 2,6 cm a frente da testa: sem isto ela
## entrava na cabine em cada cabecada e tapava a cara.
func prender_pano(pano: PanoGPU) -> void:
	if pano == null:
		return
	_pano = pano
	_col = pano.colisor(Corpo.Osso.QUADRIL, LONGE, LONGE, 0.001)


## A testa no mundo, com a pose que o esqueleto tem agora.
func testa() -> Vector3:
	var esq := _c.esqueleto()
	if esq == null or _cab == null:
		return _c.global_position + Vector3.UP * 1.6
	var osso := esq.get_bone_global_pose(Corpo.Osso.CABECA).orthonormalized()
	return esq.global_transform * (osso * (_cab.transform * TESTA))


## A testa no espaco do pai (o carro), e a distancia dela ao vidro.
func testa_no_carro() -> Vector3:
	var pai := _c.get_parent() as Node3D
	return pai.to_local(testa()) if pai != null else testa()


func distancia_agora() -> float:
	return (testa_no_carro() - _o).dot(_n)


## Chamado depois de `Corpo.animar` e de `TiqueMacabro.passo`.
func aplicar() -> void:
	var esq := _c.esqueleto()
	if esq == null:
		return
	var skel_inv := esq.global_transform.affine_inverse()
	# O tronco primeiro: a cabeca vem nele.
	var x_tronco := TRONCO_RECUA * recua + TRONCO_BOTE * bote
	if absf(x_tronco) > 1e-4:
		var q := esq.get_bone_pose_rotation(Corpo.Osso.TORSO)
		esq.set_bone_pose_rotation(Corpo.Osso.TORSO,
			q * Basis.from_euler(Vector3(x_tronco, 0.0, 0.0)).get_rotation_quaternion())
	# A cara para a lente: o giro mais curto da frente da cabeca ate a direcao
	# da lente, levado para o espaco do osso.
	var qc := esq.get_bone_pose_rotation(Corpo.Osso.CABECA)
	if encara > 0.001 and _cam != null:
		var g := esq.get_bone_global_pose(Corpo.Osso.CABECA).orthonormalized()
		var centro := g * (_cab.transform * Vector3(0.0, 0.0, -0.02)) if _cab != null \
			else g.origin
		var frente := (g.basis * Vector3.FORWARD).normalized()
		var para := (skel_inv * _cam.global_position - centro).normalized()
		if frente.dot(para) < 0.9999:
			var giro := Quaternion(frente, para)
			var ang := giro.get_angle()
			var peso := clampf(encara, 0.0, 1.0)
			if ang > ENCARA_MAX:
				peso *= ENCARA_MAX / ang
			giro = Quaternion.IDENTITY.slerp(giro, peso)
			var local := g.basis.get_rotation_quaternion().inverse() * giro \
				* g.basis.get_rotation_quaternion()
			qc = qc * local
	var x_cab := QUEIXO_RECUA * recua + QUEIXO_BOTE * bote
	if absf(x_cab) > 1e-4 or absf(tombo) > 1e-4:
		qc = qc * Basis.from_euler(Vector3(x_cab, 0.0, tombo)).get_rotation_quaternion()
	esq.set_bone_pose_rotation(Corpo.Osso.CABECA, qc)
	# E o corpo inteiro na normal do vidro, ate a testa ficar onde a cena pediu.
	if distancia != INF and is_finite(distancia):
		var falta := distancia - distancia_agora()
		_desloca += falta
		_c.position = _base + _n * _desloca + Vector3.DOWN * escorrega
	_vidro_no_pano()


func _vidro_no_pano() -> void:
	if _pano == null or _col < 0 or not is_instance_valid(_pano):
		return
	if not vidro_existe:
		_pano.mover_colisor(_col, LONGE, LONGE, 0.001)
		return
	var esq := _c.esqueleto()
	var pai := _c.get_parent() as Node3D
	if esq == null or pai == null:
		return
	var t := esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.QUADRIL)
	t = Transform3D(t.basis.orthonormalized(), t.origin)
	var n_mundo := (pai.global_basis * _n).normalized()
	var centro := pai.to_global(_o) - n_mundo * VIDRO_RAIO
	var local := t.affine_inverse() * centro
	_pano.mover_colisor(_col, local, local, VIDRO_RAIO)


## A normal do vidro (para fora), no espaco do carro.
func normal() -> Vector3:
	return _n


## O ponto do vidro (espaco do carro) na frente de `local`, um ponto da malha
## da cabeca (o nariz, a boca), com a pose de agora.
func no_vidro(local: Vector3) -> Vector3:
	var esq := _c.esqueleto()
	var pai := _c.get_parent() as Node3D
	if esq == null or _cab == null or pai == null:
		return ponto_no_vidro()
	var osso := esq.get_bone_global_pose(Corpo.Osso.CABECA).orthonormalized()
	var t := pai.to_local(esq.global_transform * (osso * (_cab.transform * local)))
	return t - _n * (t - _o).dot(_n)


## O ponto do vidro (espaco do carro) debaixo da testa agora: onde o sangue e a
## trinca nascem.
func ponto_no_vidro() -> Vector3:
	var t := testa_no_carro()
	return t - _n * (t - _o).dot(_n)

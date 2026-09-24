## Um cabo de verdade: o fio branco de 30 pinos do iPhone, com peso, folga e
## inercia.
##
## Como funciona
## -------------
## Uma corda de Verlet: `SEGMENTOS` + 1 pontos, cada um lembrando onde estava no
## quadro anterior (a velocidade e a diferenca), a gravidade puxando, um nada de
## atrito do ar, e a cada passo algumas voltas de "cada vizinho a um segmento de
## distancia". As duas pontas sao presas ao que as segura (`ponta_a`, `ponta_b`)
## e saem na direcao do plugue (`saida_a`, `saida_b`), para o fio nao dobrar em
## quina rente ao conector. O chao (`chao`) e um plano: o fio deita nele em vez
## de atravessar.
##
## No carro o fio vive no espaco da cabine (`referencia`): simulado no mundo, a
## 50 km/h cada ponto seria arrastado meio metro por quadro e o atrito do ar o
## esticaria para tras como bandeira. No espaco do carro ele so sente o que o
## passageiro sente — a freada joga para a frente, a curva para o lado —, que e
## a aceleracao da cabine, somada a gravidade com o sinal trocado.
##
## Desenho: um tubo de seis lados refeito a cada quadro (45 x 6 vertices: nada),
## branco-gelo com brilho de plastico, sem nevoa (a um palmo da lente a nevoa
## o lavava de cinza, como a mao do celular — ver a memoria do viewmodel).
class_name CaboFisico
extends MeshInstance3D

const SEGMENTOS := 44
const LADOS := 6
## Raio do fio (m): o de 30 pinos tem 3 mm.
const RAIO := 0.0015
const GRAVIDADE := 9.8
## Quanto da velocidade sobra por passo de 1/60 s (atrito do ar e do proprio
## fio, que e duro e nao chicoteia).
const AMORTECE := 0.965
## Voltas de restricao por passo: menos que isso e o fio estica como elastico.
const VOLTAS := 14
## Quanto a direcao da saida do plugue manda nos dois primeiros segmentos.
const RIGIDEZ_DA_PONTA := 0.6
## O fio resiste a dobrar: um ponto nao chega mais perto que esta fracao de dois
## segmentos do ponto dois adiante. Sem isso a sobra do fio no chao se enrugava
## em zigue-zague; puxar cada ponto para o meio dos vizinhos (a primeira
## tentativa) encurtava o fio e enrugava mais — fio duro faz laco, nao ruga.
const DOBRA_MINIMA := 0.9

signal esticou(tensao: float)

## Comprimento do fio (m).
var comprimento: float = 1.0
## Quem segura cada ponta (nulo = ponta solta, caindo).
var ponta_a: Node3D
var ponta_b: Node3D
## O ponto da ponta e a direcao em que o fio sai dele, no espaco de quem segura.
var local_a := Vector3.ZERO
var local_b := Vector3.ZERO
var saida_a := Vector3.DOWN
var saida_b := Vector3.DOWN
## O espaco em que o fio e simulado (o carro); nulo = o mundo.
var referencia: Node3D
## Altura do chao no espaco da simulacao (-INF = sem chao).
var chao: float = -INF
## Paredes (planos no espaco da simulacao, normal para o lado livre): o fio fica
## do lado de ca delas.
var paredes: Array[Plane] = []
## Para onde o fio solto deita no chao quando nasce (sem ponta B).
var deita_para := Vector3.FORWARD
## Os pontos do fio agora e no passo anterior, no espaco da simulacao.
var _p := PackedVector3Array()
var _q := PackedVector3Array()
var _ref_vel_antes := Vector3.INF
var _ref_pos_antes := Vector3.INF
var _mat: StandardMaterial3D
var _acumulado: float = 0.0


func _init() -> void:
	name = "Cabo"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("eeeeec")
	_mat.roughness = 0.38
	_mat.metallic_specular = 0.6
	_mat.set(&"disable_fog", true)
	material_override = _mat
	top_level = true


func _ready() -> void:
	global_transform = Transform3D.IDENTITY
	recomecar()


## Estende o fio reto entre as pontas (ou pendurado da ponta A), parado.
func recomecar() -> void:
	_p.resize(SEGMENTOS + 1)
	_q.resize(SEGMENTOS + 1)
	var a := _ponta(ponta_a, local_a)
	var b := _ponta(ponta_b, local_b)
	if a == Vector3.INF:
		a = Vector3.ZERO
	if b == Vector3.INF:
		# Solto: desce da ponta A ate o chao e deita nele, para o lado pedido.
		var seg := comprimento / float(SEGMENTOS)
		var deita := Vector3(deita_para.x, 0.0, deita_para.z).normalized()
		if deita.length_squared() < 0.5:
			deita = Vector3.FORWARD
		var p := a
		for i in SEGMENTOS + 1:
			_p[i] = p
			_q[i] = p
			if chao > -INF and p.y - seg > chao + RAIO:
				p += Vector3.DOWN * seg
			else:
				if chao > -INF:
					p.y = chao + RAIO
				p += deita * seg
		_ref_vel_antes = Vector3.INF
		_ref_pos_antes = Vector3.INF
		return
	# Com folga: o meio desce o que o comprimento sobra da reta.
	var sobra := maxf(0.0, comprimento - a.distance_to(b))
	for i in SEGMENTOS + 1:
		var t := float(i) / float(SEGMENTOS)
		var p := a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * sobra * 0.45
		if chao > -INF:
			p.y = maxf(p.y, chao + RAIO)
		_p[i] = p
		_q[i] = p
	_ref_vel_antes = Vector3.INF
	_ref_pos_antes = Vector3.INF


## Onde a ponta esta no espaco da simulacao.
func _ponta(no: Node3D, local: Vector3) -> Vector3:
	if no == null or not is_instance_valid(no) or not no.is_inside_tree():
		return Vector3.INF
	var g := no.global_transform * local
	return referencia.global_transform.affine_inverse() * g if _ref_ok() else g


func _saida(no: Node3D, dir: Vector3) -> Vector3:
	var g := no.global_transform.basis * dir
	return (referencia.global_transform.basis.inverse() * g).normalized() if _ref_ok() else g.normalized()


func _ref_ok() -> bool:
	return referencia != null and is_instance_valid(referencia) and referencia.is_inside_tree()


## A tensao de agora: a distancia entre as pontas sobre o comprimento (acima de
## 1 o fio esta esticado alem do que tem).
func tensao() -> float:
	var a := _ponta(ponta_a, local_a)
	var b := _ponta(ponta_b, local_b)
	if a == Vector3.INF or b == Vector3.INF:
		return 0.0
	return a.distance_to(b) / maxf(comprimento, 0.01)


func _process(delta: float) -> void:
	if _p.size() != SEGMENTOS + 1:
		recomecar()
	# Passo fixo de 1/120 s: o fio e leve e duro, e passo grande o faz tremer.
	_acumulado = minf(_acumulado + delta, 0.05)
	var g := _gravidade_aparente(delta)
	while _acumulado >= 1.0 / 120.0:
		_passo(1.0 / 120.0, g)
		_acumulado -= 1.0 / 120.0
	_desenhar()
	var t := tensao()
	if t > 1.0:
		esticou.emit(t)


## A gravidade, e no carro a aceleracao dele com o sinal trocado (o fio "fica
## para tras" quando o carro arranca), no espaco da simulacao.
func _gravidade_aparente(delta: float) -> Vector3:
	var g := Vector3.DOWN * GRAVIDADE
	if not _ref_ok():
		return g
	var xf := referencia.global_transform
	var pos := xf.origin
	var ac := Vector3.ZERO
	if _ref_pos_antes.is_finite() and delta > 0.0:
		var vel := (pos - _ref_pos_antes) / delta
		if _ref_vel_antes.is_finite():
			ac = ((vel - _ref_vel_antes) / delta).limit_length(25.0)
		_ref_vel_antes = vel
	_ref_pos_antes = pos
	return xf.basis.inverse() * (g - ac)


func _passo(dt: float, g: Vector3) -> void:
	var n := SEGMENTOS + 1
	var a := _ponta(ponta_a, local_a)
	var b := _ponta(ponta_b, local_b)
	var amortece := pow(AMORTECE, dt * 60.0)
	for i in n:
		var p := _p[i]
		var v := (p - _q[i]) * amortece
		_q[i] = p
		_p[i] = p + v + g * dt * dt
	var seg := comprimento / float(SEGMENTOS)
	var da := _saida(ponta_a, saida_a) if a != Vector3.INF else Vector3.ZERO
	var db := _saida(ponta_b, saida_b) if b != Vector3.INF else Vector3.ZERO
	for _volta in VOLTAS:
		if a != Vector3.INF:
			_p[0] = a
			# O fio sai reto do plugue: o segundo ponto puxado para a saida.
			_p[1] = _p[1].lerp(a + da * seg, RIGIDEZ_DA_PONTA)
		if b != Vector3.INF:
			_p[n - 1] = b
			_p[n - 2] = _p[n - 2].lerp(b + db * seg, RIGIDEZ_DA_PONTA)
		for i in n - 1:
			var d := _p[i + 1] - _p[i]
			var l := d.length()
			if l < 1e-6:
				continue
			var corr := d * (1.0 - seg / l) * 0.5
			var fixa_i := (i == 0 and a != Vector3.INF)
			var fixa_j := (i + 1 == n - 1 and b != Vector3.INF)
			if fixa_i and not fixa_j:
				_p[i + 1] -= corr * 2.0
			elif fixa_j and not fixa_i:
				_p[i] += corr * 2.0
			elif not fixa_i and not fixa_j:
				_p[i] += corr
				_p[i + 1] -= corr
		var minimo := seg * 2.0 * DOBRA_MINIMA
		for i in n - 2:
			var d2 := _p[i + 2] - _p[i]
			var l2 := d2.length()
			if l2 >= minimo or l2 < 1e-6:
				continue
			var empurra := d2 * ((minimo - l2) / l2) * 0.25
			var fixa_i := (i == 0 and a != Vector3.INF)
			var fixa_j := (i + 2 == n - 1 and b != Vector3.INF)
			if not fixa_i:
				_p[i] -= empurra
			if not fixa_j:
				_p[i + 2] += empurra
		for parede: Plane in paredes:
			for i in n:
				var d := parede.distance_to(_p[i]) - RAIO
				if d < 0.0:
					_p[i] -= parede.normal * d
		if chao > -INF:
			for i in n:
				var p := _p[i]
				if p.y < chao + RAIO:
					# Elemento de array empacotado e copia: `_p[i].y = ...` nao
					# escreve nada.
					p.y = chao + RAIO
					_p[i] = p
					# Encostou: nao quica (a velocidade para baixo some) e quase nao
					# escorrega (o atrito come a de lado).
					var q := _q[i].lerp(p, 0.35)
					q.y = p.y
					_q[i] = q


func _desenhar() -> void:
	var xf := referencia.global_transform if _ref_ok() else Transform3D.IDENTITY
	var n := _p.size()
	if n < 2:
		return
	var verts := PackedVector3Array()
	var normais := PackedVector3Array()
	var indices := PackedInt32Array()
	var antes := Vector3.UP
	for i in n:
		var p := xf * _p[i]
		var t := (xf * _p[mini(i + 1, n - 1)] - xf * _p[maxi(i - 1, 0)]).normalized()
		if t.length_squared() < 0.5:
			t = Vector3.DOWN
		# Referencial que gira pouco de um anel para o outro (transporte paralelo):
		# com um "para cima" fixo o tubo torcia onde o fio fica vertical.
		var lado := antes.cross(t)
		if lado.length_squared() < 1e-6:
			lado = t.cross(Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.FORWARD)
		lado = lado.normalized()
		var cima := t.cross(lado).normalized()
		antes = cima
		for k in LADOS:
			var ang := TAU * float(k) / float(LADOS)
			var nrm := lado * cos(ang) + cima * sin(ang)
			verts.append(p + nrm * RAIO)
			normais.append(nrm)
	for i in n - 1:
		for k in LADOS:
			var a0 := i * LADOS + k
			var a1 := i * LADOS + (k + 1) % LADOS
			var b0 := a0 + LADOS
			var b1 := a1 + LADOS
			indices.append(a0)
			indices.append(b0)
			indices.append(a1)
			indices.append(a1)
			indices.append(b0)
			indices.append(b1)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normais
	arr[Mesh.ARRAY_INDEX] = indices
	var m := mesh as ArrayMesh
	if m == null:
		m = ArrayMesh.new()
		mesh = m
	m.clear_surfaces()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _mat)


## Onde a ponta B esta agora (mundo): quem solta o fio pousa o plugue ali.
func ponto_b() -> Vector3:
	if _p.is_empty():
		return global_position
	var xf := referencia.global_transform if _ref_ok() else Transform3D.IDENTITY
	return xf * _p[_p.size() - 1]


## Direcao do ultimo segmento (mundo), para o plugue solto acompanhar o fio.
func direcao_b() -> Vector3:
	var n := _p.size()
	if n < 2:
		return Vector3.DOWN
	var xf := referencia.global_transform if _ref_ok() else Transform3D.IDENTITY
	return (xf.basis * (_p[n - 1] - _p[n - 2])).normalized()

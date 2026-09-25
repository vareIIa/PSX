## O sangue de quem bate a cabeca num vidro do carro, visto de dentro
## (`sangue_vidro.gdshader`).
##
## A lamina e o PROPRIO contorno da janela (`Carroceria.montar` -> `aberturas`),
## como a da `TrincaDeVidro`, so que do lado de FORA: o sangue esta onde a testa
## bateu, e a agua e a trinca do vidro ficam entre ele e o motorista. A UV e em
## metros no plano do vidro, com +y para cima.
##
## Cada `golpe` carimba uma celula do atlas assado (`tools/gerar_sangue_vidro.py`:
## marca da testa craquelada, respingo, escorridos) no ponto da testa, e o
## escorrido desce sozinho a partir dali. `arrastar` e o rosto escorregando no
## vidro. Ate seis marcas por vidro.
class_name SangueNoVidro
extends MeshInstance3D

const SHADER := "res://shaders/sangue_vidro.gdshader"
const ATLAS := "res://assets/monstros/sangue/vidro_sangue.png"
## Quanto para fora do vidro a lamina fica (m): o decalque de vidro da lataria
## mora no plano da abertura.
const PARA_FORA := 0.0025
## A celula do atlas cobre isto de vidro (m), e o arrasto dela desce isto.
const CELULA := 0.40
const ARRASTO := 0.12
## O tempo de escorrer: o progresso e 1 - exp(-t / ESCORRE). A frente de um
## filete de 20 cm anda 10 cm no primeiro segundo e meio e leva uns seis para
## parar.
const ESCORRE := 4.0
## A fracao do progresso que o arrasto em si ocupa (o resto e o escorrido
## que sai do fim dele) — a do gerador.
const FIM_DO_ARRASTO := 0.25
const MAXIMO := 8

var _mat: ShaderMaterial
var _o := Vector3.ZERO
var _u := Vector3.RIGHT
var _v := Vector3.UP
var _n := Vector3.BACK
## Por marca: [u, v, variante, giro, escala, forca, idade (s), arrasto (s, 0 se
## nao e)].
var _marcas: Array = []
## O escorrer para (a cena congelada), mas o sangue fica.
var parado: bool = false
var _aquecendo: bool = false
var _quebrado: bool = false
var _xf_antes := Transform3D.IDENTITY


## Monta a lamina na abertura `a` (espaco do carro). Filha da cabine, como a
## trinca.
static func na_abertura(a: Dictionary, semente: float = 3.0) -> SangueNoVidro:
	var contorno: PackedVector3Array = a.get("contorno", a.get("pontos", PackedVector3Array()))
	var n: Vector3 = a.get("normal", Vector3.ZERO)
	if contorno.size() < 3 or n.length_squared() < 0.5:
		return null
	var s := SangueNoVidro.new()
	s.name = "Sangue_%s" % String(a.get("tipo", &"vidro"))
	s._montar(contorno, n.normalized(), semente)
	return s


func _montar(contorno: PackedVector3Array, n: Vector3, _semente: float) -> void:
	var v := (Vector3.UP - n * n.dot(Vector3.UP))
	if v.length_squared() < 1e-4:
		v = Vector3.FORWARD - n * n.dot(Vector3.FORWARD)
	v = v.normalized()
	var u := v.cross(n).normalized()
	var o := contorno[0]
	var pts2 := PackedVector2Array()
	for p: Vector3 in contorno:
		pts2.append(Vector2((p - o).dot(u), (p - o).dot(v)))
	var tris := Geometry2D.triangulate_polygon(pts2)
	if tris.is_empty():
		pts2.reverse()
		contorno = contorno.duplicate()
		contorno.reverse()
		tris = Geometry2D.triangulate_polygon(pts2)
	var vs := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in tris:
		vs.append(contorno[i] + n * PARA_FORA)
		uvs.append(pts2[i])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_o = o
	_u = u
	_v = v
	_n = n
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER) as Shader
	_mat.set_shader_parameter(&"atlas", load(ATLAS))
	_mat.set_shader_parameter(&"celula", CELULA)
	# Depois do vidro da cabine, que tambem redesenha a tela de tras: se ele
	# viesse depois, apagava o sangue.
	_mat.render_priority = 1
	material_override = _mat
	_escrever()


## Onde `p` (espaco do pai, o do carro) cai no plano da lamina, em metros.
func no_vidro(p: Vector3) -> Vector2:
	return Vector2((p - _o).dot(_u), (p - _o).dot(_v))


## Um golpe de testa em `onde` (espaco do carro, projetado no vidro), com
## `forca` de 0 a 1. A variante do atlas sai da forca: o primeiro golpe fraco,
## o terceiro pesado.
func golpe(onde: Vector3, forca: float, escala: float = 1.0) -> void:
	var var_ := 0 if forca < 0.66 else (1 if forca < 0.9 else 2)
	_somar([no_vidro(onde), var_, randf_range(-0.12, 0.12),
		randf_range(0.9, 1.1) * lerpf(0.85, 1.1, forca) * escala, forca, 0.0, 0.0])


## O rosto escorregando no vidro de `de` ate `ate` (espaco do carro) em
## `duracao` segundos: um borrao de riscos que desce, e dele os escorridos.
func arrastar(de: Vector3, ate: Vector3, duracao: float) -> void:
	var a := no_vidro(de)
	var b := no_vidro(ate)
	var d := b - a
	var comp := maxf(d.length(), 0.01)
	# A celula desce em -v: o giro leva o "para baixo" dela a direcao do
	# arrasto.
	var giro := Vector2(0.0, -1.0).angle_to(d / comp) if comp > 0.011 else 0.0
	_somar([a, 3, giro, clampf(comp / ARRASTO, 0.6, 1.5), 1.0, 0.0, maxf(duracao, 0.05)])


func _somar(m: Array) -> void:
	if _marcas.size() >= MAXIMO:
		_marcas.pop_front()
	_marcas.append(m)
	_escrever()


func limpar() -> void:
	_marcas.clear()
	_escrever()


## Onde estao as marcas agora (espaco do pai, o carro), com o tamanho de cada
## uma (m) em w: quem quebra o vidro solta as gotas e os coagulos dali.
func marcas_no_carro() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for m: Array in _marcas:
		var uv: Vector2 = m[0]
		var p := _o + _u * uv.x + _v * uv.y + _n * PARA_FORA
		out.append(Vector4(p.x, p.y, p.z, CELULA * float(m[3]) * 0.3))
	return out


## O vidro estourou: o sangue que estava nele cai junto com os cacos (as gotas
## sao da cena, a partir de `marcas_no_carro`), e a lamina morre no mesmo
## quadro. Esconder so nao bastava: o `_process` redesenhava as marcas no
## quadro seguinte, e o respingo ficava parado no ar onde o vidro era.
func quebrar() -> void:
	_quebrado = true
	_marcas.clear()
	visible = false
	set_process(false)
	queue_free()


## A lamina aparece na frente da lente, em `onde` (mundo), com uma marca de
## mentira, para o pipeline dela compilar sob a camera que vai desenhar
## (`aquecer(false)` volta tudo).
func aquecer(ligar: bool, onde: Vector3 = Vector3.INF) -> void:
	if ligar and not _aquecendo:
		_aquecendo = true
		_xf_antes = transform
		if onde.is_finite():
			var centro := _o + _u * 0.2 + _v * 0.2
			global_position = onde - global_basis * centro
		_marcas.append([Vector2(0.2, 0.25), 1, 0.0, 1.0, 1.0, 3.0, 0.0])
		visible = true
		_escrever()
	elif not ligar and _aquecendo:
		_aquecendo = false
		transform = _xf_antes
		_marcas.pop_back()
		_escrever()


func _process(delta: float) -> void:
	if _marcas.is_empty() or parado:
		return
	for m: Array in _marcas:
		m[5] = float(m[5]) + delta
	_escrever()


func _escrever() -> void:
	if _mat == null:
		return
	if _quebrado:
		visible = false
		return
	var ga := PackedVector4Array()
	var gb := PackedVector4Array()
	for m: Array in _marcas:
		var uv: Vector2 = m[0]
		var idade: float = m[5]
		var arrasto: float = m[6]
		var prog: float
		if arrasto > 0.0:
			# O arrasto anda junto com o rosto; depois dele, o escorrido.
			if idade < arrasto:
				prog = FIM_DO_ARRASTO * idade / arrasto
			else:
				prog = FIM_DO_ARRASTO + (1.0 - FIM_DO_ARRASTO) \
					* (1.0 - exp(-(idade - arrasto) / ESCORRE))
		else:
			prog = 1.0 - exp(-idade / ESCORRE)
		ga.append(Vector4(uv.x, uv.y, float(m[1]), float(m[2])))
		gb.append(Vector4(float(m[3]), float(m[4]), prog, 0.0))
	while ga.size() < MAXIMO:
		ga.append(Vector4.ZERO)
		gb.append(Vector4.ZERO)
	_mat.set_shader_parameter(&"golpes_a", ga)
	_mat.set_shader_parameter(&"golpes_b", gb)
	_mat.set_shader_parameter(&"n_golpes", _marcas.size())
	visible = not _marcas.is_empty()


## Qualquer parametro do shader: `luz`, `brilho`, `corpo_forca`, `lente`,
## `absorcao`.
func ajustar(nome: StringName, valor: Variant) -> void:
	if _mat != null:
		_mat.set_shader_parameter(nome, valor)

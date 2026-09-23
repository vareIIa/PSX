## A frente de uma prateleira, como alvo da tecla de interagir.
##
## PLANO_MERCADO_AAA, 4.4. Uma area por PRODUTO seriam tres mil corpos. Uma por
## FACE, e a conta resolve o resto: o raio da camera contra o plano da face vira
## (ao longo, altura), a altura escolhe o nivel e a coluna mais proxima dentro
## dele leva a mira — aderente, porque doze centimetros de lata a um metro e
## meio sao tres pixels, e exigir tres pixels e defeito, nao dificuldade.
##
## O jogador nao sabe de nada disso: ele acha um `Interativo` com o raio de
## sempre, le `rotulo_atual()` a cada quadro e chama `interagir`. A face refaz a
## conta com a camera nas duas chamadas, e por isso o rotulo e o gesto sempre
## falam da mesma lata.
class_name FaceDePrateleira
extends Interativo

var loja: PrateleiraViva
var face: int = -1


static func criar(dona: PrateleiraViva, f: Dictionary) -> FaceDePrateleira:
	var a := FaceDePrateleira.new()
	a.loja = dona
	a.face = int(f["id"])
	a.name = "Face%d" % a.face
	var comp: float = f["comprimento"]
	var niveis: Array[float] = f["niveis"]
	var y0: float = niveis[0] - 0.06
	var alto: float = float(f["teto"]) - y0
	var eixo: Vector3 = f["eixo"]
	var normal: Vector3 = f["normal"]
	# Seis centimetros de espessura, a frente da face: o raio acha a area antes
	# da colisao da gondola, e a porta da geladeira aberta nao a atravessa.
	a.position = Vector3(f["origem"]) + eixo * (comp * 0.5) + Vector3.UP * (y0 + alto * 0.5) \
		+ normal * 0.04
	a.basis = Planograma.base_de(f)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(comp, alto, 0.08)
	forma.shape = caixa
	a.add_child(forma)
	return a


func rotulo_atual() -> String:
	if loja == null or not habilitado:
		return ""
	return loja.rotulo_na_face(face, _ponto())


func interagir(quem: Node) -> void:
	if loja == null or not habilitado:
		return
	loja.acionar_na_face(face, _ponto(), quem)
	acionado.emit(quem)


## Onde o olho do jogador cruza o plano da face, em coordenada da PLANTA.
func _ponto() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null or loja == null:
		return Vector3.INF
	var f: Dictionary = loja.faces[face]
	var para_planta := loja.global_transform.affine_inverse()
	var o := para_planta * cam.global_position
	var d := (para_planta.basis * -cam.global_basis.z).normalized()
	var n: Vector3 = f["normal"]
	var den := d.dot(n)
	if absf(den) < 0.0001:
		return Vector3.INF
	var t := (Vector3(f["origem"]) - o).dot(n) / den
	if t < 0.0:
		return Vector3.INF
	return o + d * t

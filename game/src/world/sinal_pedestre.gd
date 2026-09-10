## A cara acesa de um sinal de pedestre, e a regra que ela obedece.
##
## Mesma divisao do Semaforo: o mastro e a caixa apagada moram na malha do chunk
## (KitModular.sinal_pedestre) e nao custam chamada de desenho; aqui fica so o
## icone que acende — o bonequinho que anda ou o que fica parado.
##
## A regra e pura e mora no Semaforo: `Semaforo.estado_pedestre(cruzamento,
## eixo_conflito, tempo)`. Um pedestre que chega a esquina antes de o chunk do
## cruzamento existir ja sabe se pode atravessar, e recarregar a partida no meio
## da faixa devolve a mesma fase. Nada disto entra no save.
class_name SinalPedestre
extends Node3D

const MAT_ANDA := "res://resources/materials/mat_sinal_anda.tres"
const MAT_PARA := "res://resources/materials/mat_sinal_para.tres"

## Casa com KitModular.sinal_pedestre: a caixa apagada fica nesta altura.
const ALTURA := 2.3
## Lado do quadrado aceso. Casa com a janela apagada da caixa.
const LADO := 0.26
## Deslocamento do icone a partir do centro da caixa, para ele passar na frente
## da janela apagada em vez de brigar com ela pelo mesmo pixel.
const SAIDA := 0.12

@export var cruzamento := Vector2i.ZERO
## Eixo de carro cuja fila cruza esta travessia. Quem anda so tem ANDA enquanto
## esse eixo esta no vermelho.
@export var eixo_conflito: int = 0
## Giro do mastro, para o icone encarar quem espera na calcada.
@export var giro: float = 0.0

var _anda: MeshInstance3D
var _para: MeshInstance3D
var _atual: int = -1
var _pisca_t: float = 0.0


func _ready() -> void:
	rotation.y = giro
	_montar()
	set_process(true)


func _montar() -> void:
	_anda = _face(load(MAT_ANDA))
	_para = _face(load(MAT_PARA))
	# Sem Omni: o teto e quatro luzes dinamicas por chunk (skill psx-city) e o
	# cruzamento ja gasta duas com o semaforo de carro. O icone e emissivo e
	# fica na altura do olho, perto o bastante para ler sem holofote.
	_aplicar(Semaforo.estado_pedestre(cruzamento.x, cruzamento.y, eixo_conflito,
		Semaforo.agora()))


## Um par de quads — um para cada lado da caixa — com o icone dado.
func _face(mat: Resource) -> MeshInstance3D:
	var dados := PSXMesh.dados_vazios()
	# A altura entra na POSICAO do no, e nao no vertice: o icone muda de escala
	# com a distancia (ver _escalar) e altura embutida no vertice subiria junto,
	# tirando o bonequinho de dentro da caixa.
	for lado: float in [1.0, -1.0]:
		PSXMesh.acumular(dados, PSXMesh.placa_dados(Vector2(LADO, LADO), 1.0),
			Transform3D(Basis(Vector3.UP, 0.0 if lado > 0.0 else PI),
				Vector3(0.0, 0.0, SAIDA * lado)))
	var mi := MeshInstance3D.new()
	mi.position.y = ALTURA - 0.12
	mi.name = "Anda" if mat.resource_path == MAT_ANDA else "Pare"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = (mat as ShaderMaterial).duplicate() as ShaderMaterial
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	Semaforo.avancar(delta)
	var novo := Semaforo.estado_pedestre(cruzamento.x, cruzamento.y,
		eixo_conflito, Semaforo.agora())
	if novo != _atual:
		_aplicar(novo)
	if _atual == Semaforo.Travessia.PARE_PISCA:
		_pisca_t += delta
		_para.visible = fmod(_pisca_t, 0.7) < 0.36
	_escalar()


## Mantem o bonequinho acima do tamanho minimo de tela, pela mesma conta e pela
## mesma razao da lente do semaforo de carro (ver Semaforo.LENTE_PX_MINIMO).
##
## Aqui importa tanto quanto la: quem decide atravessar decide de longe, olhando
## para a outra esquina — e a outra esquina de uma avenida esta a quinze metros,
## onde um icone de 0,26 m ja e um pixel e meio.
func _escalar() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam == null:
		return
	var alt_px := vp.get_visible_rect().size.y
	if alt_px < 1.0:
		return
	var d := cam.global_position.distance_to(global_position)
	var altura_m := 2.0 * d * tan(deg_to_rad(cam.fov) * 0.5)
	var minimo := altura_m * (Semaforo.LENTE_PX_MINIMO / alt_px)
	var e := clampf(minimo / LADO, 1.0, Semaforo.LENTE_ESCALA_MAX)
	var escala := Vector3(e, e, 1.0)
	_anda.scale = escala
	_para.scale = escala


func _aplicar(novo: int) -> void:
	_atual = novo
	_pisca_t = 0.0
	var anda := novo == Semaforo.Travessia.ANDA
	_anda.visible = anda
	_para.visible = not anda

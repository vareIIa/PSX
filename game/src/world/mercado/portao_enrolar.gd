## O portao de aco da garagem da loja que existe na rua. Sobe de verdade.
##
## Antes ele era um desenho fechado na calcada, e o de dentro, acionado,
## teleportava o jogador para a frente dele. Agora e UM portao: a folha e do
## predio (existe com o chunk, fechada, vista da rua), e quem manda nela e a
## botoeira da parede da garagem (BotoeiraPortao). Aberto, da calcada se ve a
## garagem, e da garagem se sai andando para a calcada.
##
## A folha sobe para dentro da parede, e nao enrola: a partir da verga ela passa
## por tras do tambor e da fachada, e por dentro por tras do reboco e do forro.
## Nenhum ponto de vista ve o que acontece acima da verga, e o que se ve abaixo
## dela — a borda de baixo subindo, as laminas correndo — e o portao de enrolar.
##
## Lento, como o de verdade: seis segundos de motor e corrente. E o tempo que faz
## abrir o portao ser uma decisao, e o que o caminhao das tres (F6) espera na
## calcada.
class_name PortaoEnrolar
extends Node3D

const DURACAO := 6.0
## Quanto ele fica aberto sem ninguem perto antes de alguem da loja baixar. A
## loja nao deixa a garagem escancarada, e um portao aberto no chunk de uma loja
## que ja foi desmontada mostraria um buraco no lugar da garagem.
const LONGE := 30.0
const PACIENCIA := 8.0

@export var largura: float = KitMercado.LARGURA_PORTAO
@export var altura: float = KitMercado.ALTURA_PORTAO
@export var semente: int = 0

signal parou(aberto: bool)

var _folha: AnimatableBody3D
var _motor: AudioStreamPlayer3D
var _s: float = 0.0
var _alvo: float = 0.0
var _sozinho_ha: float = 0.0


func _ready() -> void:
	add_to_group(&"portao_enrolar")
	_montar()


func _montar() -> void:
	var camadas := 1 | InteriorNoMundo.CAMADA
	_folha = AnimatableBody3D.new()
	_folha.name = "Folha"
	_folha.sync_to_physics = true
	add_child(_folha)

	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(largura, altura, 0.06)
	forma.shape = caixa
	forma.position = Vector3(0.0, altura * 0.5, 0.0)
	_folha.add_child(forma)

	# A chapa ondulada, com a imagem das laminas dos dois lados.
	var chapa: Dictionary = {}
	for giro: float in [0.0, PI]:
		KitModular.placa(chapa, &"mercado_portao",
			Vector3(0.0, altura * 0.5, 0.03 if giro == 0.0 else -0.03),
			Vector2(largura, altura), giro, Color.WHITE, KitMercado.SUBDIVISAO_PAINEL)
	_malha(&"mercado_portao", chapa, camadas)
	# A regua de baixo, mais grossa, com a alca e o ferrolho: e por ela que o
	# olho acompanha a subida.
	var regua: Dictionary = {}
	KitModular.caixa_cor(regua, &"metal", Vector3(0.0, 0.05, 0.0),
		Vector3(largura - 0.02, 0.1, 0.09), Color("7d807a"))
	for z: float in [0.06, -0.06]:
		KitModular.caixa_cor(regua, &"metal", Vector3(0.0, 0.32, z),
			Vector3(0.22, 0.04, 0.04), Color("5c5f5b"))
	KitModular.caixa_cor(regua, &"metal", Vector3(largura * 0.32, 0.18, 0.055),
		Vector3(0.12, 0.05, 0.03), Color("4d4f4c"))
	_malha(&"metal", regua, camadas)

	_motor = AudioStreamPlayer3D.new()
	_motor.name = "Motor"
	_motor.stream = AudioDirector.em_loop(&"portao_motor")
	_motor.bus = &"SFX"
	_motor.unit_size = 4.0
	_motor.max_distance = 40.0
	_motor.volume_db = -6.0
	_motor.position = Vector3(0.0, altura + 0.2, 0.0)
	add_child(_motor)


func _malha(nome: StringName, sup: Dictionary, camadas: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = String(nome)
	mi.mesh = PSXMesh.dados_para_mesh(sup[nome])
	mi.material_override = load("res://resources/materials/mat_%s.tres" % nome)
	mi.layers = camadas
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_folha.add_child(mi)


# --- controle -----------------------------------------------------------------

## Subindo ou aberto.
func abrindo() -> bool:
	return _alvo > 0.5


func em_movimento() -> bool:
	return not is_equal_approx(_s, _alvo)


## De 0 (fechado) a 1 (aberto).
func abertura() -> float:
	return _s


## A botoeira: sobe, ou desce. No meio do curso, inverte — o motor de portao
## de verdade para e volta, e segurar o jogador esperando o fim do curso para
## poder baixar de novo seria o botao nao obedecer.
func alternar() -> void:
	if _alvo > 0.5:
		fechar()
	else:
		abrir()


func abrir() -> void:
	if _alvo >= 1.0:
		return
	_alvo = 1.0
	_arrancar()


func fechar() -> void:
	if _alvo <= 0.0:
		return
	_alvo = 0.0
	_arrancar()


func _arrancar() -> void:
	AudioDirector.tocar(&"porta_trava", global_position + Vector3(0.0, altura, 0.0), -10.0)
	if _motor.stream != null and not _motor.playing:
		_motor.play()


func _physics_process(delta: float) -> void:
	if em_movimento():
		_s = move_toward(_s, _alvo, delta / DURACAO)
		_folha.position.y = altura * _s
		if not em_movimento():
			_motor.stop()
			AudioDirector.tocar(&"porta_trava", global_position
				+ Vector3(0.0, 0.3 if _alvo < 0.5 else altura, 0.0), -4.0)
			parou.emit(_alvo > 0.5)
	_vigiar(delta)


## Ninguem por perto e o portao aberto: alguem da loja baixa.
func _vigiar(delta: float) -> void:
	if _alvo < 0.5:
		_sozinho_ha = 0.0
		return
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var longe := jogador == null or \
		jogador.global_position.distance_to(global_position) > LONGE
	_sozinho_ha = _sozinho_ha + delta if longe else 0.0
	if _sozinho_ha > PACIENCIA:
		fechar()


## Forca um estado, sem animar. So para captura e teste.
func forcar(aberto: bool) -> void:
	_s = 1.0 if aberto else 0.0
	_alvo = _s
	_folha.position.y = altura * _s

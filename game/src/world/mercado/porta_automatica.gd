## A porta automatica da loja que existe na rua. Nao tem botao.
##
## PLANO_MERCADO_AAA §3.5. A porta de antes era uma area com [E] que abria,
## tocava o motor e teleportava. Porta de loja de conveniencia nao se aciona: ela
## VE quem chega. Aqui ela ve dos dois lados, abre para o jogador e para o
## freguês, segura aberta enquanto houver alguem no vao, fecha sozinha depois e
## reabre se alguem entra enquanto ela fecha.
##
## As folhas tem corpo. Fechada, ela e parede — da calcada nao se entra pelo
## vidro, e de dentro nao se sai sem ela abrir. O corpo e um AnimatableBody que
## anda no passo da fisica, e por isso empurra quem estiver no caminho em vez de
## aparecer dentro dele.
##
## O dim-dom
## ---------
## Toca quando alguem CRUZA a folha para dentro, e nao quando a porta abre: gente
## passando rente a vitrine abre a porta sem entrar, e um sino a cada passante
## deixaria de dizer alguma coisa. Ouvido do deposito, ele e informacao de jogo:
## alguem entrou na loja.
##
## Eixos: +Z local aponta para a rua (o giro da fachada), as folhas correm em X.
class_name PortaAutomatica
extends Node3D

## O volume que o sensor ve, de cada lado do plano da folha: largura ao longo da
## fachada, altura e alcance para fora. Um passo e meio para fora: quem anda na
## calcada rente a vitrine passa por fora dele; quem vira para a porta entra.
const SENSOR := Vector3(2.3, 2.2, 1.45)
## Por dentro o alcance e maior: quem vem do caixa com a sacola na mao nao pode
## esbarrar no vidro esperando o sensor acordar.
const SENSOR_DENTRO := 1.7

## Tempos, em segundos. Abrir e rapido e sai suave; fechar e mais lento; e fica
## aberta um tanto depois do ultimo, que e o que evita a porta mastigando a
## sacola de quem sai.
const ABRE := 0.62
const FECHA := 1.0
const SEGURA := 1.6
## Quanto cada folha corre: a largura dela menos o que fica sobreposto ao vidro
## fixo, onde ela some por tras do montante.
const CURSO := Porta.FOLHA_LARGURA - 0.05

## A que distancia se procura quem pode estar chegando. So quem esta mais perto
## que isso entra na conta de volume.
const ATENCAO := 5.0

signal alguem_entrou(quem: Node3D)
signal alguem_saiu(quem: Node3D)

@export var semente: int = 0

var _folhas: Array[AnimatableBody3D] = []
var _s: float = 0.0
var _alvo: float = 0.0
var _vazia_ha: float = 99.0
var _lado: Dictionary = {}
var _tique: int = 0


func _ready() -> void:
	add_to_group(&"porta_automatica")
	_montar()


# --- montagem -----------------------------------------------------------------

func _montar() -> void:
	var vidro := load("res://resources/materials/mat_vitrine_loja.tres") as Material
	var metal := load("res://resources/materials/mat_metal.tres") as Material
	var camadas := 1 | InteriorNoMundo.CAMADA
	var larg := Porta.FOLHA_LARGURA
	var alto := Porta.FOLHA_ALTURA

	for k in 2:
		var lado := -1.0 if k == 0 else 1.0
		var folha := AnimatableBody3D.new()
		folha.name = "Folha%s" % ("E" if k == 0 else "D")
		folha.sync_to_physics = true
		folha.position = Vector3(lado * larg * 0.5, 0.0, 0.0)
		add_child(folha)

		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(larg, alto, 0.05)
		forma.shape = caixa
		forma.position = Vector3(0.0, alto * 0.5, 0.0)
		folha.add_child(forma)

		# Vidro e caixilho. O montante do encontro das duas folhas e mais largo
		# que os outros: e a linha vertical que faz o vao ler como porta que abre
		# no meio.
		var aluminio: Dictionary = {}
		var encontro := -lado * (larg * 0.5 - 0.035)
		var fora := lado * (larg * 0.5 - 0.02)
		KitModular.caixa_cor(aluminio, &"metal", Vector3(encontro, alto * 0.5, 0.0),
			Vector3(0.07, alto, 0.06), KitMercado.ALUMINIO)
		KitModular.caixa_cor(aluminio, &"metal", Vector3(fora, alto * 0.5, 0.0),
			Vector3(0.04, alto, 0.05), KitMercado.ALUMINIO)
		for y: float in [0.05, alto - 0.03]:
			KitModular.caixa_cor(aluminio, &"metal", Vector3(0.0, y, 0.0),
				Vector3(larg, 0.1 if y < 1.0 else 0.06, 0.055), KitMercado.ALUMINIO)
		# A faixa jateada na altura do peito, a que a norma pede para ninguem
		# andar contra o vidro. Dos dois lados.
		for z: float in [0.028, -0.028]:
			KitModular.caixa_cor(aluminio, &"metal", Vector3(0.0, 1.05, z),
				Vector3(larg - 0.12, 0.07, 0.003), Color("d6dcdc"))
		_malha(folha, &"metal", aluminio, metal, camadas)

		# Virado para a rua, como o vidro da vitrine: o shader sabe de que lado
		# esta quem olha pela face que ve (psx_vitrine).
		var painel: Dictionary = {}
		KitModular.placa(painel, &"vitrine_loja", Vector3(0.0, alto * 0.5 + 0.02, 0.0),
			Vector2(larg - 0.1, alto - 0.14), 0.0, Color.WHITE, KitMercado.SUBDIVISAO_PAINEL)
		_malha(folha, &"vitrine_loja", painel, vidro, camadas)
		_folhas.append(folha)


func _malha(pai: Node3D, nome: StringName, sup: Dictionary, material: Material,
		camadas: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = String(nome)
	mi.mesh = PSXMesh.dados_para_mesh(sup[nome])
	mi.material_override = material
	mi.layers = camadas
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)


# --- sensor -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# O volume a 20 Hz basta: meio passo de atraso nao se ve. As folhas andam em
	# todo quadro de fisica.
	_tique += 1
	if _tique % 3 == 0:
		_olhar(delta * 3.0)
	_mover(delta)


func _olhar(dt: float) -> void:
	var alguem := false
	var bloqueando := false
	var vistos: Dictionary = {}
	for corpo: Node3D in _candidatos():
		var p := to_local(corpo.global_position)
		if absf(p.x) > SENSOR.x * 0.5 or p.y < -0.8 or p.y > SENSOR.y:
			continue
		var id := corpo.get_instance_id()
		vistos[id] = true
		var lado := signf(p.z) if absf(p.z) > 0.08 else float(_lado.get(id, 0.0))
		var antes := float(_lado.get(id, lado))
		if antes > 0.0 and lado < 0.0:
			_entrou(corpo)
		elif antes < 0.0 and lado > 0.0:
			alguem_saiu.emit(corpo)
		_lado[id] = lado
		if p.z > -SENSOR_DENTRO and p.z < SENSOR.z:
			alguem = true
		# No vao, entre as duas faixas de trilho: a folha nao fecha em cima de
		# ninguem, nem que o sensor pisque.
		if absf(p.z) < 0.45 and absf(p.x) < Porta.FOLHA_LARGURA + 0.2:
			bloqueando = true
	for id: Variant in _lado.keys():
		if not vistos.has(id):
			_lado.erase(id)

	if alguem or bloqueando:
		_vazia_ha = 0.0
		if _alvo < 1.0:
			_abrir()
	else:
		_vazia_ha += dt
		if _vazia_ha >= SEGURA and _alvo > 0.0:
			_fechar()


## Quem a porta enxerga: o jogador e a gente que usa a loja. Pedestre de
## calcada nao — ele passa, nao entra, e um sensor que abrisse para cada um
## faria a porta bater o dia inteiro.
func _candidatos() -> Array[Node3D]:
	var saida: Array[Node3D] = []
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null and _perto(jogador):
		saida.append(jogador)
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Node3D
		if c != null and c.is_inside_tree() and c.can_process() and _perto(c):
			saida.append(c)
	return saida


func _perto(n: Node3D) -> bool:
	var d := n.global_position - global_position
	return absf(d.x) < ATENCAO and absf(d.z) < ATENCAO and absf(d.y) < 3.0


func _entrou(corpo: Node3D) -> void:
	AudioDirector.tocar(&"loja_dimdom", global_position + global_basis.z * -1.2
		+ Vector3(0.0, 2.3, 0.0), -7.0)
	alguem_entrou.emit(corpo)


# --- movimento ----------------------------------------------------------------

func _abrir() -> void:
	# Motor so quando a porta estava parada fechada ou fechando: reabrir no meio
	# do curso nao repete o arranque do motor, so inverte.
	if _alvo <= 0.0:
		AudioDirector.tocar(&"porta_desliza", global_position + Vector3(0.0, 2.3, 0.0),
			-9.0, 1.0)
	_alvo = 1.0


func _fechar() -> void:
	_alvo = 0.0
	AudioDirector.tocar(&"porta_desliza", global_position + Vector3(0.0, 2.3, 0.0),
		-11.0, 0.72)


func _mover(delta: float) -> void:
	if is_equal_approx(_s, _alvo):
		return
	var passo := delta / (ABRE if _alvo > _s else FECHA)
	_s = move_toward(_s, _alvo, passo)
	# Curva em S: arranca devagar, corre, e assenta. Na reabertura a posicao e
	# continua; so o sentido troca.
	var d := CURSO * smoothstep(0.0, 1.0, _s)
	var larg := Porta.FOLHA_LARGURA
	_folhas[0].position.x = -larg * 0.5 - d
	_folhas[1].position.x = larg * 0.5 + d


## Quanto a porta esta aberta, de 0 a 1. Para quem mede (TesteMercado) e para o
## freguês, que espera o vao abrir antes de andar.
func abertura() -> float:
	return smoothstep(0.0, 1.0, _s)


## Forca um estado, sem animar. So para captura e teste.
func forcar(aberta: bool) -> void:
	_s = 1.0 if aberta else 0.0
	_alvo = _s
	_vazia_ha = 0.0 if aberta else 99.0
	_mover(0.0)
	var d := CURSO * _s
	_folhas[0].position.x = -Porta.FOLHA_LARGURA * 0.5 - d
	_folhas[1].position.x = Porta.FOLHA_LARGURA * 0.5 + d

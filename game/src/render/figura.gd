## Figura humana em caixas, com ciclo de passo procedural.
##
## Nao usa esqueleto nem animacao gravada, e nao e preguica: o ART-BIBLE limita a
## 24 ossos e manda animar a 15 quadros por segundo com interpolacao discreta.
## Um ciclo procedural quantizado da exatamente isso, cabe em um arquivo e nao
## depende de ferramenta de fora do projeto.
##
## O truque que faz parecer da epoca e a quantizacao. Movimento suave le como
## motor moderno; travar a pose em quinze posicoes por ciclo devolve o passo
## duro que o PS1 tinha por limitacao de memoria de animacao.
##
## A hierarquia existe so onde o giro precisa de pivo: braco gira no ombro e
## perna gira no quadril, entao cada um e um Node3D com a caixa pendurada
## abaixo. Torso e cabeca sao caixas soltas.
class_name Figura
extends Node3D

## Poses distintas por ciclo de caminhada. ART-BIBLE secao 10.
const POSES_POR_CICLO := 15.0
## Ciclos de perna por metro andado. Passo humano da uns 0,75 m.
const CICLOS_POR_METRO := 0.62

const AMPLITUDE_PERNA := 0.62
const AMPLITUDE_BRACO := 0.48
const BALANCO_TORSO := 0.035
const INCLINACAO_MAX := 0.16

## Perfil de montagem. Cada entrada e {nome, tamanho, pos, cor, pivo}.
## `pivo` diz se a peca ganha um no de rotacao acima dela.
const HUMANO := [
	{"nome": "Torso", "tam": Vector3(0.40, 0.58, 0.22), "pos": Vector3(0.0, 1.16, 0.0),
		"cor": "cfc7a8", "pivo": false},
	{"nome": "Cabeca", "tam": Vector3(0.20, 0.22, 0.20), "pos": Vector3(0.0, 1.57, 0.0),
		"cor": "c9a98c", "pivo": false},
	{"nome": "BracoE", "tam": Vector3(0.11, 0.52, 0.13), "pos": Vector3(-0.25, 1.42, 0.0),
		"cor": "c9a98c", "pivo": true},
	{"nome": "BracoD", "tam": Vector3(0.11, 0.52, 0.13), "pos": Vector3(0.25, 1.42, 0.0),
		"cor": "c9a98c", "pivo": true},
	{"nome": "PernaE", "tam": Vector3(0.15, 0.86, 0.17), "pos": Vector3(-0.10, 0.87, 0.0),
		"cor": "4a5468", "pivo": true},
	{"nome": "PernaD", "tam": Vector3(0.15, 0.86, 0.17), "pos": Vector3(0.10, 0.87, 0.0),
		"cor": "4a5468", "pivo": true},
]

## Variante do inimigo: mais alto, mais estreito, cabeca baixa e a frente.
const CRIATURA := [
	{"nome": "Torso", "tam": Vector3(0.38, 0.72, 0.24), "pos": Vector3(0.0, 1.16, 0.0),
		"cor": "6b6355", "pivo": false},
	{"nome": "Cabeca", "tam": Vector3(0.19, 0.21, 0.20), "pos": Vector3(0.0, 1.50, 0.08),
		"cor": "8a7f6d", "pivo": false},
	{"nome": "BracoE", "tam": Vector3(0.10, 0.66, 0.11), "pos": Vector3(-0.26, 1.43, 0.02),
		"cor": "6b6355", "pivo": true},
	{"nome": "BracoD", "tam": Vector3(0.10, 0.66, 0.11), "pos": Vector3(0.26, 1.43, 0.02),
		"cor": "6b6355", "pivo": true},
	{"nome": "PernaE", "tam": Vector3(0.13, 0.80, 0.15), "pos": Vector3(-0.10, 0.80, 0.0),
		"cor": "4a4438", "pivo": true},
	{"nome": "PernaD", "tam": Vector3(0.13, 0.80, 0.15), "pos": Vector3(0.10, 0.80, 0.0),
		"cor": "4a4438", "pivo": true},
]

## O vulto da beira da estrada. Nao e personagem: e recorte.
##
## Alto, magro e de uma cor so, quase preta. Uma figura na beira de uma estrada
## de terra a noite nao tem detalhe nenhum — o farol passa raspando e o que
## sobra e um buraco escuro em pe contra a nevoa clara. Dar a ele roupa, pele e
## rosto o transformaria em pedestre, e pedestre nao assusta.
##
## Todas as pecas na MESMA cor de proposito: com dois tons ele ganha volume, e
## volume le como "pessoa parada ali". Um tom so le como "aquilo nao devia estar
## ali". A print de referencia mostra exatamente isso, uma mancha sem interior.
const VULTO := [
	{"nome": "Torso", "tam": Vector3(0.36, 0.70, 0.22), "pos": Vector3(0.0, 1.22, 0.0),
		"cor": "14161a", "pivo": false},
	{"nome": "Cabeca", "tam": Vector3(0.19, 0.23, 0.19), "pos": Vector3(0.0, 1.69, 0.0),
		"cor": "14161a", "pivo": false},
	{"nome": "BracoE", "tam": Vector3(0.10, 0.62, 0.11), "pos": Vector3(-0.24, 1.50, 0.0),
		"cor": "14161a", "pivo": true},
	{"nome": "BracoD", "tam": Vector3(0.10, 0.62, 0.11), "pos": Vector3(0.24, 1.50, 0.0),
		"cor": "14161a", "pivo": true},
	{"nome": "PernaE", "tam": Vector3(0.13, 0.88, 0.15), "pos": Vector3(-0.09, 0.88, 0.0),
		"cor": "14161a", "pivo": true},
	{"nome": "PernaD", "tam": Vector3(0.13, 0.88, 0.15), "pos": Vector3(0.09, 0.88, 0.0),
		"cor": "14161a", "pivo": true},
]

## Variante do morador: mais baixo e mais largo que o jogador, ombro caido.
## Silhueta de gente velha, que le a distancia sem precisar de rosto.
##
## Roupa escura de proposito. A parede da sala e clara e iluminada, entao roupa
## clara fazia a figura ficar mais brilhante que o fundo e ler como coluna. Com
## o casaco escuro ele recorta contra a parede, que e o que a encenacao de
## entrada precisa: primeiro a silhueta, depois a pessoa.
const MORADOR := [
	{"nome": "Torso", "tam": Vector3(0.44, 0.54, 0.26), "pos": Vector3(0.0, 1.06, 0.0),
		"cor": "463f33", "pivo": false},
	{"nome": "Cabeca", "tam": Vector3(0.21, 0.23, 0.21), "pos": Vector3(0.0, 1.45, 0.0),
		"cor": "c2a488", "pivo": false},
	{"nome": "BracoE", "tam": Vector3(0.12, 0.48, 0.14), "pos": Vector3(-0.27, 1.28, 0.0),
		"cor": "463f33", "pivo": true},
	{"nome": "BracoD", "tam": Vector3(0.12, 0.48, 0.14), "pos": Vector3(0.27, 1.28, 0.0),
		"cor": "463f33", "pivo": true},
	{"nome": "PernaE", "tam": Vector3(0.16, 0.80, 0.18), "pos": Vector3(-0.11, 0.80, 0.0),
		"cor": "2e3138", "pivo": true},
	{"nome": "PernaD", "tam": Vector3(0.16, 0.80, 0.18), "pos": Vector3(0.11, 0.80, 0.0),
		"cor": "2e3138", "pivo": true},
]

@export var material_caminho: String = "res://resources/materials/mat_personagem.tres"

## Assimetria do passo, de 0 a 1. Zero anda normal, alto manca. A criatura usa
## valor alto: perna que arrasta assusta antes de o jogador saber por que.
@export_range(0.0, 1.0, 0.05) var manqueira: float = 0.0

## Multiplicador da cadencia. A criatura anda mais devagar que o jogador mesmo
## na mesma velocidade, o que a faz parecer pesada.
@export_range(0.3, 2.0, 0.05) var cadencia: float = 1.0

var _pivos: Dictionary[StringName, Node3D] = {}
var _torso: MeshInstance3D
var _cabeca: MeshInstance3D
var _fase: float = 0.0
var _t_parado: float = 0.0
var _altura_torso: float = 0.0
var _triangulos: int = 0


func montar(perfil: Array) -> void:
	var material := load(material_caminho) as ShaderMaterial

	for parte: Dictionary in perfil:
		var nome := StringName(parte["nome"])
		var tam: Vector3 = parte["tam"]
		var pos: Vector3 = parte["pos"]
		var cor := Color(parte["cor"])

		var mi := MeshInstance3D.new()
		mi.name = String(nome)
		mi.mesh = PSXMesh.box(tam, 1.6, PSXMesh.MAX_QUAD_M, cor)
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_triangulos += PSXMesh.triangle_count(mi.mesh)

		if bool(parte["pivo"]):
			# O pivo fica no topo da peca, que e onde ombro e quadril ficam. Sem
			# isso o membro gira pelo meio e o pe atravessa o corpo.
			var pivo := Node3D.new()
			pivo.name = String(nome) + "Pivo"
			pivo.position = pos
			add_child(pivo)
			mi.position = Vector3(0.0, -tam.y * 0.5, 0.0)
			pivo.add_child(mi)
			_pivos[nome] = pivo
		else:
			mi.position = pos
			add_child(mi)
			if nome == &"Torso":
				_torso = mi
				_altura_torso = pos.y
			elif nome == &"Cabeca":
				_cabeca = mi


func triangulos() -> int:
	return _triangulos


## Avanca o ciclo. `rapidez` em m/s, `no_chao` desliga o passo no ar.
func animar(rapidez: float, delta: float, no_chao: bool = true) -> void:
	if rapidez > 0.15 and no_chao:
		_fase += rapidez * delta * CICLOS_POR_METRO * TAU * cadencia
		_t_parado = 0.0
		_pose_andando(rapidez)
	else:
		_t_parado += delta
		_pose_parado()


## Trava um angulo na grade de POSES_POR_CICLO passos por volta.
##
## E a quantizacao que da o passo duro do PS1. Sem ela o mesmo ciclo le como
## animacao moderna interpolada, por mais certa que esteja a pose.
func _travar(fase: float) -> float:
	return floor(fase / TAU * POSES_POR_CICLO) / POSES_POR_CICLO * TAU


func _pose_andando(rapidez: float) -> void:
	var f := _travar(_fase)
	# A escala cresce com a velocidade ate correr, e ai satura: braco girando
	# mais que meia volta le como erro, nao como pressa.
	var escala := clampf(rapidez / 2.4, 0.45, 1.35)

	var esq := sin(f)
	var dir := sin(f + PI)
	# A manqueira encurta um lado do passo, entao o corpo cai sempre para o
	# mesmo pe.
	var f_esq := 1.0 - manqueira * 0.55
	var f_dir := 1.0 + manqueira * 0.25

	_girar(&"PernaE", esq * AMPLITUDE_PERNA * escala * f_esq)
	_girar(&"PernaD", dir * AMPLITUDE_PERNA * escala * f_dir)
	# Braco oposto a perna do mesmo lado. E o detalhe que separa "anda" de
	# "desliza com as pernas mexendo".
	_girar(&"BracoE", dir * AMPLITUDE_BRACO * escala, manqueira * 0.2)
	_girar(&"BracoD", esq * AMPLITUDE_BRACO * escala, -manqueira * 0.2)

	if _torso != null:
		# Sobe duas vezes por ciclo, uma a cada passo.
		_torso.position.y = _altura_torso + absf(sin(f)) * BALANCO_TORSO * escala
		_torso.rotation.x = -INCLINACAO_MAX * clampf(rapidez / 4.6, 0.0, 1.0)
		_torso.rotation.z = cos(f) * 0.03 * escala
	if _cabeca != null:
		# A cabeca compensa parte da inclinacao: olhar para o chao correndo e
		# leitura de personagem cansado, nao de personagem andando.
		_cabeca.rotation.x = INCLINACAO_MAX * 0.6 * clampf(rapidez / 4.6, 0.0, 1.0)


func _pose_parado() -> void:
	# Respiracao lenta, tambem travada. Parado com pose congelada le como
	# manequim, e manequim so assusta quando e de proposito.
	var f := _travar(_t_parado * 1.1)
	var r := sin(f) * 0.5 + 0.5

	_girar(&"PernaE", 0.0)
	_girar(&"PernaD", 0.0)
	_girar(&"BracoE", 0.04 + r * 0.02, manqueira * 0.2)
	_girar(&"BracoD", 0.04 + r * 0.02, -manqueira * 0.2)

	if _torso != null:
		_torso.position.y = _altura_torso + r * 0.008
		_torso.rotation.x = move_toward(_torso.rotation.x, 0.0, 0.02)
		_torso.rotation.z = move_toward(_torso.rotation.z, 0.0, 0.02)
	if _cabeca != null:
		_cabeca.rotation.x = move_toward(_cabeca.rotation.x, 0.0, 0.02)


## Vira a cabeca para o lado, em passos. `angulo` em radianos, limitado ao que um
## pescoco faz sem o corpo acompanhar.
##
## Quantizado como o resto: cabeca seguindo o jogador continuamente le como
## camera de vigilancia moderna. Em passos ela le como pose, que e o que o PS1
## tinha, e de quebra fica mais perturbador.
const LIMITE_PESCOCO := 1.05
const PASSOS_PESCOCO := 7.0

func olhar_lateral(angulo: float) -> void:
	if _cabeca == null:
		return
	var preso := clampf(angulo, -LIMITE_PESCOCO, LIMITE_PESCOCO)
	var passo := LIMITE_PESCOCO / PASSOS_PESCOCO
	_cabeca.rotation.y = roundf(preso / passo) * passo
	# O torso acompanha um terco, senao a cabeca parece solta no lugar.
	if _torso != null:
		_torso.rotation.y = _cabeca.rotation.y * 0.34


func _girar(nome: StringName, angulo_x: float, angulo_z: float = 0.0) -> void:
	var pivo: Node3D = _pivos.get(nome)
	if pivo == null:
		return
	pivo.rotation.x = angulo_x
	pivo.rotation.z = angulo_z

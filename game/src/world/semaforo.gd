## O poste de sinal do cruzamento, e a regra que ele obedece.
##
## A regra nao mora no no. `estado()` e uma funcao pura de (cruzamento, eixo,
## tempo): qualquer carro, em qualquer chunk, com o poste montado ou nao, chega
## a mesma resposta sem consultar ninguem. O poste e so a cara dela.
##
## Isso importa mais do que parece. O carro que vem de longe precisa saber se
## vai ter de parar ANTES de o chunk do cruzamento existir — senao ele chega em
## cima da faixa, o poste aparece vermelho e o carro freia dentro do meio do
## cruzamento. Com a fase sendo conta, nao ha "antes": o sinal de um cruzamento
## a duzentos metros tem cor agora e sempre teve.
##
## E, pelo mesmo motivo, nada disto entra no save. Recarregar uma partida no
## meio de um cruzamento devolve o mesmo amarelo que estava la.
class_name Semaforo
extends Node3D

enum Luz { VERMELHO, AMARELO, VERDE }

## O que uma cara de sinal de pedestre mostra. PARE_PISCA e o vermelho piscando
## do fim da travessia: ainda da para terminar de atravessar, nao da para
## comecar. (Nome nao e `Pedestre` porque ja existe uma classe com esse nome.)
enum Travessia { PARE, ANDA, PARE_PISCA }

## Aviso de fim de travessia: os ultimos segundos do vermelho do eixo que
## conflita com o pedestre entram como PARE piscando.
const PED_AVISO_S := 4.0

## Duracao de cada fase, em segundos. Somadas dao o ciclo.
const VERDE_S := 11.0
const AMARELO_S := 2.0
## Vermelho geral entre uma fase e a outra. Um segundo — nao e realismo, e o que
## impede um carro que entrou no fim do amarelo de encontrar quem arrancou no
## verde novo bem no meio do cruzamento.
const ENTRE_S := 1.0

const CICLO := (VERDE_S + AMARELO_S + ENTRE_S) * 2.0

## Altura da cabeca do sinal e altura do mastro.
const ALTURA := 3.1
const RAIO_MASTRO := 0.07

const MATERIAL_LUZ := "res://resources/materials/mat_semaforo_luz.tres"

## Cores das tres lampadas. Sao as da rua a sodio, e nao as de um semaforo real:
## saturadas demais elas destoam de tudo o que esta em volta.
const CORES: Array[Color] = [
	Color(1.0, 0.22, 0.16),
	Color(1.0, 0.72, 0.16),
	Color(0.32, 1.0, 0.42),
]

@export var cruzamento := Vector2i.ZERO
## Que eixo de transito este poste comanda: 0 para quem anda em Z, 1 para quem
## anda em X. Um cruzamento tem os dois, em postes separados e opostos.
@export var eixo: int = 0
## Giro do mastro, para a cabeca olhar para quem vem.
@export var giro: float = 0.0
## Cria a Omni de halo. Num cruzamento de quatro esquinas so dois postes a
## ganham — um por eixo, ja que os dois de um eixo mostram a mesma cor — para
## nao estourar o teto de quatro luzes por chunk da skill psx-city.
@export var com_halo: bool = true

## So a lente acesa mora aqui; o resto do poste esta no mesh do chunk.
var _lente: MeshInstance3D
var _halo: OmniLight3D
var _atual: Luz = Luz.VERMELHO


# --- a regra ----------------------------------------------------------------

## Defasagem deste cruzamento dentro do ciclo.
##
## Sem ela a cidade inteira abre e fecha junto, o que le como cenario e nao como
## cidade: de uma esquina se veem tres cruzamentos, e os tres piscando em uniao
## denunciam a formula na primeira olhada.
static func defasagem(i: int, j: int) -> float:
	var h := absi(i * 73856093 + j * 19349663) % 1000
	return float(h) / 1000.0 * CICLO


## Que cor o eixo `eixo` ve no cruzamento (i, j) no instante `t`.
static func estado(i: int, j: int, eixo_do_carro: int, t: float) -> Luz:
	if not Vias.existe_cruzamento(i, j):
		return Luz.VERDE
	var fase := fposmod(t + defasagem(i, j), CICLO)
	# A primeira metade do ciclo e do eixo 0; a segunda, do eixo 1.
	var meia := CICLO * 0.5
	var minha := fase if eixo_do_carro == 0 else fase - meia
	if minha < 0.0:
		minha += CICLO
	if minha >= meia:
		return Luz.VERMELHO
	if minha < VERDE_S:
		return Luz.VERDE
	if minha < VERDE_S + AMARELO_S:
		return Luz.AMARELO
	return Luz.VERMELHO


## Fase deste eixo dentro do ciclo, ja resolvida a metade que e dele. 0 e o
## instante em que ele abre para o verde.
static func _minha_fase(i: int, j: int, eixo_do_carro: int, t: float) -> float:
	var fase := fposmod(t + defasagem(i, j), CICLO)
	var meia := CICLO * 0.5
	var minha := fase if eixo_do_carro == 0 else fase - meia
	if minha < 0.0:
		minha += CICLO
	return minha


## Segundos ate este eixo abrir para o verde. Zero enquanto ja esta em verde.
static func ate_o_verde(i: int, j: int, eixo_do_carro: int, t: float) -> float:
	var minha := _minha_fase(i, j, eixo_do_carro, t)
	if minha < VERDE_S:
		return 0.0
	return CICLO - minha


## O que a cara do sinal de pedestre mostra. `eixo_conflito` e o eixo de carro
## cuja fila cruza a travessia: quem anda so tem ANDA enquanto esse eixo esta no
## vermelho, e ainda sobra tempo. Pura, como estado(): nao depende de haver
## poste montado.
static func estado_pedestre(i: int, j: int, eixo_conflito: int, t: float) -> Travessia:
	if not Vias.existe_cruzamento(i, j):
		return Travessia.ANDA
	if estado(i, j, eixo_conflito, t) != Luz.VERMELHO:
		return Travessia.PARE
	var restante := ate_o_verde(i, j, eixo_conflito, t)
	if restante > 0.0 and restante <= PED_AVISO_S:
		return Travessia.PARE_PISCA
	return Travessia.ANDA


## Ha sinal neste cruzamento?
##
## So onde as duas vias sao dirigiveis. Cruzamento de rua com viela nao ganha
## poste: la vale a preferencia de quem esta na via maior, que e o que o carro
## faz sozinho ao nao encontrar sinal e olhar se ha alguem na frente.
static func tem_sinal(i: int, j: int) -> bool:
	return Vias.existe_cruzamento(i, j)


## O relogio que todo mundo le. Tempo de jogo, nao de sistema: pausar o jogo
## para o transito junto, que e o que se espera ao abrir o inventario.
##
## Acumulado por `avancar(delta)` a partir de `_process` (que o tree.paused
## congela). `Time.get_ticks_msec` ignorava a pausa e o sinal continuava
## ciclando com o inventario aberto.
static var _agora: float = 0.0
static var _frame_tick: int = -1

static func agora() -> float:
	return _agora


## Avanca o relogio uma vez por quadro. Varios postes e o Transito podem chamar;
## o guarda de frame evita multiplicar o delta.
static func avancar(delta: float) -> void:
	var f := Engine.get_process_frames()
	if f == _frame_tick:
		return
	_frame_tick = f
	_agora += delta


# --- a lente acesa ----------------------------------------------------------

## Este no e SO a lente que acende.
##
## O mastro, a cabeca e as tres lentes apagadas ja estao fundidos na superficie
## do chunk (KitModular.semaforo) e nao custam chamada de desenho nenhuma. O que
## sobrou aqui e um par de quads — um para cada sentido de aproximacao — que
## muda de altura e de cor conforme a fase.
##
## Trocar de fase, portanto, e mover um no e escrever duas cores. Nao ha nada
## para acender nem para apagar, e nao ha material por lampada.
func _ready() -> void:
	rotation.y = giro
	_montar()
	set_process(true)


func _montar() -> void:
	var dados := PSXMesh.dados_vazios()
	for lado: float in [1.0, -1.0]:
		PSXMesh.acumular(dados, PSXMesh.placa_dados(Vector2(0.19, 0.19), 1.0),
			Transform3D(Basis(Vector3.UP, 0.0 if lado > 0.0 else PI),
				Vector3(0.0, 0.0, 0.138 * lado)))
	_lente = MeshInstance3D.new()
	_lente.name = "Lente"
	_lente.mesh = PSXMesh.dados_para_mesh(dados)
	_lente.material_override = (load(MATERIAL_LUZ) as ShaderMaterial).duplicate() as ShaderMaterial
	_lente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lente)

	# Halo noturno: a emissao da lente sozinha some na nevoa a trinta metros.
	# Uma Omni fraca na cor da fase faz o sinal continuar legivel sem virar
	# holofote — orcamento de uma luz por poste, sem sombra.
	if com_halo:
		_halo = OmniLight3D.new()
		_halo.name = "Halo"
		_halo.omni_range = 4.2
		_halo.omni_attenuation = 1.4
		_halo.light_energy = 1.8
		_halo.shadow_enabled = false
		_lente.add_child(_halo)

	_aplicar(estado(cruzamento.x, cruzamento.y, eixo, agora()))


func _process(delta: float) -> void:
	avancar(delta)
	var novo := estado(cruzamento.x, cruzamento.y, eixo, agora())
	if novo != _atual:
		_aplicar(novo)


func _aplicar(novo: Luz) -> void:
	_atual = novo
	# A ordem das lentes na caixa e vermelho, amarelo, verde de cima para baixo,
	# e o enum vai na mesma ordem: o indice e o proprio valor.
	_lente.position.y = ALTURA - 0.18 - float(int(novo)) * 0.24
	var mat := _lente.material_override as ShaderMaterial
	if mat == null:
		return
	var cor: Color = CORES[int(novo)]
	mat.set_shader_parameter("tint", cor)
	mat.set_shader_parameter("emission_color", cor)
	# Um pouco mais alto que antes: a lente precisa furar a nevoa sodica.
	mat.set_shader_parameter("emission_energy", 4.2)
	if _halo != null:
		_halo.light_color = cor
		_halo.light_energy = (2.4 if novo == Luz.VERMELHO
			else (2.0 if novo == Luz.AMARELO else 1.7))

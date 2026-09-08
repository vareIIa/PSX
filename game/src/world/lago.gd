## O volume de agua do lago. Nao desenha nada: diz onde molha.
##
## Por que e um registro estatico e nao uma Area3D
## -----------------------------------------------
## A pergunta que o jogador faz e "estou dentro da agua e a que profundidade?",
## sessenta vezes por segundo. Uma Area3D responde a primeira metade — e so
## depois do proximo passo de fisica, o que atrasa o mergulho em um quadro — e
## nao responde a segunda: `overlaps_body` nao devolve quanto do corpo esta
## submerso, e e a submersao que decide se o jogador anda, nada ou se afoga.
##
## Um lago e uma caixa alinhada aos eixos. Testar um ponto contra ela sao seis
## comparacoes, e ha no maximo dois ou tres lagos carregados de uma vez. Isso e
## mais barato que a consulta de fisica e ainda responde no mesmo quadro.
class_name Lago
extends Node3D

## Todos os lagos com chunk carregado. Estatico e limpo no _exit_tree — o
## streaming descarrega chunk a qualquer momento e um lago fantasma na lista
## faria o jogador nadar no seco.
static var _ativos: Array[Lago] = []

## Meia-medida da caixa d'agua, em metros.
var meia: Vector3 = Vector3(10.0, 1.0, 10.0)
var semente: int = 0

var _som: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"lago")
	_ativos.append(self)
	_montar_som()


func _exit_tree() -> void:
	_ativos.erase(self)


## O barulho da agua. Um emissor no centro, com alcance grande: o lago inteiro
## e uma fonte so, e e o que se quer — agua parada nao tem ponto de origem.
func _montar_som() -> void:
	if not AudioDirector.tem(&"lago_loop"):
		return
	_som = AudioStreamPlayer3D.new()
	_som.stream = AudioDirector.stream(&"lago_loop")
	_som.volume_db = -17.0
	_som.unit_size = maxf(meia.x, meia.z) * 1.4
	_som.max_distance = maxf(meia.x, meia.z) + 34.0
	_som.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_som)
	_som.play()


## Superficie da agua em `p`, ou NAN se `p` esta fora de qualquer lago.
##
## A caixa e testada so no plano: em Y o teste e "abaixo da lamina e acima do
## fundo", e o fundo tem folga de meio metro para o jogador que entra pulando
## do deque nao atravessar a agua num quadro.
static func superficie_em(p: Vector3) -> float:
	for l in _ativos:
		var c := l.global_position
		if absf(p.x - c.x) > l.meia.x or absf(p.z - c.z) > l.meia.z:
			continue
		if p.y > c.y + 0.6 or p.y < c.y - l.meia.y * 2.0 - 0.5:
			continue
		return c.y
	return NAN


## Ha agua em `p`? Atalho para quem so quer o sim ou nao.
static func molhado(p: Vector3) -> bool:
	return not is_nan(superficie_em(p))

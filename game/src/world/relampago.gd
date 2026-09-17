## O relampago do temporal: o clarao, e o trovao que chega depois dele.
##
## Por que os dois moram no mesmo no
## ---------------------------------
## Porque o que faz um relampago ser um relampago nao e o clarao nem o estouro:
## e o INTERVALO entre os dois. Luz anda trezentos mil quilometros por segundo e
## som anda trezentos e quarenta e tres metros; a conta que toda crianca do
## interior sabe fazer — contar os segundos e dividir por tres — e a unica coisa
## que da tamanho ao ceu numa cena de chuva. Separados em dois lugares, o atraso
## viraria um numero que alguem esqueceria de ajustar, e o raio passaria a cair
## sempre em cima do carro.
##
## O clarao e uma LUZ, e nao um filtro de tela
## -------------------------------------------
## Um retangulo branco por cima da imagem clareia tudo por igual: a mata que
## esta a cem metros e a folha que esta a um palmo da lente recebem a mesma
## coisa, e o resultado le como corte para branco. Uma direcional de verdade
## recorta a mata contra o fundo, acende o capo do carro e deixa a sombra onde
## ela estava — que e o que um relampago faz.
##
## Duas piscadas, e nao uma
## ------------------------
## Raio real quase nunca tem um lampejo so: sao varios retornos pelo mesmo canal
## ionizado, em poucas dezenas de milissegundos. O olho nao conta quantos foram,
## mas reconhece na hora quando ha um so — fica com cara de flash de camera.
class_name Relampago
extends Node3D

const SOM_PERTO := &"trovao_perto"
const SOM_LONGE := &"trovao_longe"

## Velocidade do som, em metros por segundo. E ela que vira o atraso.
const SOM_M_POR_S := 343.0

## Acima desta distancia o trovao ja perdeu o estalo e sobrou so o ronco.
const KM_LONGE := 2.2

## O desenho da piscada: pares de (instante, energia) em segundos desde o
## disparo. O envelope inteiro dura menos de meio segundo.
##
## Os numeros sao curtos de proposito. Um clarao de um segundo nao e relampago,
## e holofote: o que o olho guarda de um raio e a imagem que ficou na retina
## DEPOIS, e para isso o estimulo tem de ser mais curto do que o tempo que ele
## leva para entender o que viu.
const PISCADAS: Array = [
	[0.00, 0.0], [0.015, 1.0], [0.06, 0.12], [0.09, 0.80],
	[0.15, 0.22], [0.19, 0.42], [0.33, 0.0],
]

## Energia da direcional no pico.
##
## Alta o bastante para vencer um dia encoberto, e nao mais. Em 7,5 o quadro
## inteiro estourava: a nevoa de profundidade tambem recebe luz direcional, entao
## o clarao nao acendia a mata contra o fundo — acendia o fundo junto, e o que
## sobrava era um corte para branco com uma legenda ilegivel por cima. Um raio a
## um quilometro e meio clareia a noite; ele nao apaga o que esta em quadro.
const ENERGIA := 4.2
## Cor do clarao. Azul-esbranquicado, que e a cor de um arco eletrico e o oposto
## do sol quente do preset de poente.
const COR := Color(0.86, 0.91, 1.0)

signal relampejou(distancia_km: float)

var _luz: DirectionalLight3D
var _ceu_mat: ShaderMaterial
var _t: float = -1.0
## O ultimo valor de clarao escrito, de 0 a 1.
var _clarao: float = 0.0
## Onde cai o proximo, para o som saber com que atraso vir.
var _km: float = 1.0


## O ceu que deve piscar junto. Sem ele o clarao acende a mata e deixa o fundo
## intacto, e o fundo e metade do quadro no plano de cima.
func acompanhar_ceu(mat: ShaderMaterial) -> void:
	_ceu_mat = mat


func _ready() -> void:
	# Ver o grupo `nuvens` em `Nuvens`: e assim que o `DiretorCeu` descobre que
	# esta cena ja tem temporal proprio e nao monta um segundo.
	add_to_group(&"relampago")
	_luz = DirectionalLight3D.new()
	_luz.name = "Clarao"
	# De cima e de frente, quase a pino: um raio ilumina de onde ele esta, que e
	# no alto, e nao do azimute do sol. Vindo de raso, ele viraria um segundo
	# poente e brigaria com a luz do preset.
	_luz.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	_luz.light_color = COR
	_luz.light_energy = 0.0
	_luz.visible = false
	# Sem sombra: a sombra de uma luz que dura dois quadros custa o mapa inteiro
	# para aparecer em dois quadros, e o `DiretorSombra` tem orcamento de duas.
	_luz.shadow_enabled = false
	add_child(_luz)
	set_process(false)


## Dispara um relampago que caiu a `km` quilometros.
##
## O trovao nao e tocado aqui: ele e AGENDADO. A `km` vira segundos de espera, e
## e por isso que um raio a quatro quilometros estoura doze segundos depois, ja
## no plano seguinte — que e o que faz a tempestade existir fora do quadro.
func disparar(km: float) -> void:
	_km = maxf(0.05, km)
	_t = 0.0
	_luz.visible = true
	set_process(true)
	relampejou.emit(_km)
	_agendar_trovao(_km)


func _agendar_trovao(km: float) -> void:
	var espera := km * 1000.0 / SOM_M_POR_S
	var som := SOM_PERTO if km < KM_LONGE else SOM_LONGE
	# Mais longe, mais grave e mais fraco. O ar come o agudo antes do grave, e
	# baixar a afinacao junto com o volume e o jeito barato e certo de dizer
	# distancia com uma amostra so.
	var volume := lerpf(-4.0, -17.0, clampf(km / 6.0, 0.0, 1.0))
	var afinacao := lerpf(1.0, 0.78, clampf(km / 6.0, 0.0, 1.0))
	var arvore := get_tree()
	if arvore == null:
		return
	await arvore.create_timer(espera).timeout
	if not is_inside_tree():
		return
	# Sem posicao: trovao nao tem lugar no quadro, ele vem de todo o ceu. Tocado
	# em 3D, ele ganharia um ponto de origem e o jogador viraria a cabeca para
	# procurar de onde veio.
	AudioDirector.tocar_ui(som, volume, afinacao)


func _process(delta: float) -> void:
	_t += delta
	var e := _energia_em(_t)
	if e <= 0.0 and _t > float(PISCADAS[PISCADAS.size() - 1][0]):
		_luz.light_energy = 0.0
		_luz.visible = false
		_escrever_ceu(0.0)
		set_process(false)
		return
	_luz.light_energy = e * ENERGIA
	_escrever_ceu(e)


## Escreve o clarao onde o ceu puder le-lo.
##
## Sao DOIS destinos e eles nao sao redundantes. O material da estrada recebe o
## valor direto, porque ele e um `ShaderMaterial` unico que alguem entregou aqui.
## A cidade nao tem um material de ceu: ela tem cento e vinte quads de nuvem
## nascidos de um sistema de particulas, e nenhum dono que os liste. Para eles o
## caminho e o uniforme global — uma escrita alcanca todos, e qualquer shader
## futuro que queira piscar junto so precisa declarar `psx_relampago`.
func _escrever_ceu(f: float) -> void:
	if _ceu_mat != null:
		_ceu_mat.set_shader_parameter(&"flash", f)
	RenderingServer.global_shader_parameter_set(&"psx_relampago", f)
	_clarao = f


## Quanto o clarao esta aceso agora, de 0 a 1. E o mesmo valor que o ceu le.
##
## Existe porque `global_shader_parameter_get` e so de editor: fora dele o motor
## recusa e devolve lixo. Quem precisa saber — a bancada do ceu — pergunta aqui.
func clarao() -> float:
	return _clarao


## Interpola a tabela de piscadas. Linear de proposito: um relampago nao tem
## curva suave, ele tem degraus, e suavizar o envelope apaga justamente o
## tremular que faz ele ler como descarga eletrica em vez de lampada.
static func _energia_em(t: float) -> float:
	if t < 0.0:
		return 0.0
	for i in range(PISCADAS.size() - 1):
		var a: Array = PISCADAS[i]
		var b: Array = PISCADAS[i + 1]
		if t >= float(a[0]) and t < float(b[0]):
			var k := (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), k)
	return 0.0

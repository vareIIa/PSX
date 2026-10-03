## A lampada pelada do porao, pendurada pelo fio, que balanca.
##
## Existe para a cena do porao (missao 1, cena 2): quem esbarra nela — o Jota
## de cabeca baixa debaixo do forro, ou a propria cutscene — poe a sala inteira
## para oscilar, porque a luz vai junto e as sombras dos dois varrem a parede.
## E o unico movimento de luz do jogo que nao e defeito de lampada (ver
## Lampada), e por isso e uma classe separada e nao um quinto Padrao.
##
## O pendulo e fisico de proposito: periodo de verdade para o comprimento do fio
## (2*pi*sqrt(L/g)) e amortecimento calibrado para assentar em ~4 s. Um vai e
## vem senoidal de periodo fixo le como animacao; o fio curto balancando rapido
## e parando aos poucos le como objeto.
##
## So processa enquanto mexe: parada, nao custa nada por quadro.
class_name LampadaPendular
extends Node3D

const MATERIAL := "res://resources/materials/mat_estufa.tres"
const MATERIAL_LUZ := "res://resources/materials/mat_estufa_luz.tres"

## Gravidade do pendulo. A mesma do mundo; nao vale ler do ProjectSettings a
## cada chute para uma constante que nunca muda.
const G := 9.8
## Amplitude de um chute de forca 1, em graus (pedido do roteiro, cena 2).
const AMPLITUDE_GRAUS := 25.0
## Tempo ate assentar. A amplitude cai de exp(-k*t); com k = ln(100)/4 ela chega
## a 1% em quatro segundos, que e quando o olho para de ver o movimento.
const ASSENTA_EM := 4.0
## Abaixo disto (rad e rad/s) o pendulo esta parado e o processo desliga.
const REPOUSO_ANG := 0.003
const REPOUSO_VEL := 0.01

## Do ponto de fixacao no forro ao centro do bulbo, em metros.
@export var comprimento: float = 0.4
@export var cor: Color = Color("ffd9a0")
@export_range(0.0, 12.0, 0.1) var energia: float = 1.6
@export_range(0.5, 40.0, 0.5) var alcance: float = 5.0

signal parou()

var _pivo: Node3D
var _luz: OmniLight3D
## O angulo como vetor de rotacao horizontal (eixo * radianos) e a velocidade
## angular no mesmo formato. Vetor e nao dois escalares: o chute pode vir de
## qualquer direcao, e chutes somados de lados diferentes viram elipse, que e o
## que um fio de verdade faz.
var _ang: Vector3 = Vector3.ZERO
var _vel: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"lampada_porao")
	_montar()
	set_process(false)


func _montar() -> void:
	_pivo = Node3D.new()
	_pivo.name = "Pivo"
	add_child(_pivo)

	# Fio e bocal numa malha so, no material da estufa: e o mesmo atlas, e uma
	# peca a mais nao vale uma chamada de desenho a mais.
	var sup: Dictionary = {}
	var fio := maxf(comprimento - 0.1, 0.02)
	AtlasKit.caixa(sup, &"m", Vector3(0.0, -fio * 0.5, 0.0),
		Vector3(0.012, fio, 0.012), EstufaBuilder.C_MANGUEIRA, Color(0.2, 0.2, 0.2))
	AtlasKit.caixa(sup, &"m", Vector3(0.0, -comprimento + 0.07, 0.0),
		Vector3(0.045, 0.06, 0.045), EstufaBuilder.C_REFLETOR, Color(0.35, 0.33, 0.3))
	var corpo := MeshInstance3D.new()
	corpo.name = "Fio"
	corpo.mesh = PSXMesh.dados_para_mesh(sup[&"m"])
	corpo.material_override = load(MATERIAL) as Material
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivo.add_child(corpo)

	# O bulbo: a lente acesa da estufa, tingida da cor da luz. Caixa e nao
	# esfera — a 15 bits e 240 linhas, oito centimetros de vidro sao quatro
	# pixels, e uma esfera so gastaria triangulo.
	var sup_b: Dictionary = {}
	AtlasKit.caixa(sup_b, &"b", Vector3(0.0, -comprimento, 0.0),
		Vector3(0.07, 0.09, 0.07), EstufaBuilder.C_LENTE, cor.lightened(0.3))
	var bulbo := MeshInstance3D.new()
	bulbo.name = "Bulbo"
	bulbo.mesh = PSXMesh.dados_para_mesh(sup_b[&"b"])
	bulbo.material_override = load(MATERIAL_LUZ) as Material
	bulbo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivo.add_child(bulbo)

	# A fonte vai no pivo, logo abaixo do bulbo: balanca junto, e e isso que
	# faz a sombra varrer a parede.
	_luz = OmniLight3D.new()
	_luz.name = "Fonte"
	_luz.position = Vector3(0.0, -comprimento - 0.06, 0.0)
	_luz.light_color = cor
	_luz.light_energy = energia
	_luz.omni_range = alcance
	_luz.omni_attenuation = 1.1
	# Mesmo contrato da Lampada: nasce sem sombra e concorre a ela pelo
	# DiretorSombra. Aqui e a sombra que conta a historia do balanco.
	_luz.shadow_enabled = false
	_luz.add_to_group(DiretorSombra.GRUPO)
	_luz.light_cull_mask &= ~InteriorNoMundo.CAMADA
	_pivo.add_child(_luz)


## Da um empurrao no pendulo. `direcao` e horizontal, para onde o bulbo sai;
## `forca` 1 leva a uns 25 graus. Chute com ele ja balancando soma.
func balancar(forca: float = 1.0, direcao: Vector3 = Vector3.RIGHT) -> void:
	var d := Vector3(direcao.x, 0.0, direcao.z)
	if d.length_squared() < 0.0001:
		d = Vector3.RIGHT
	d = d.normalized()
	# O eixo de giro que leva o bulbo (em -Y) para `d`: (-Y) x d.
	var eixo := Vector3.DOWN.cross(d).normalized()
	# Velocidade inicial = amplitude * omega: parte do repouso e chega na
	# amplitude pedida no primeiro quarto de periodo. O fator exp compensa o
	# que o amortecimento come nesse quarto (sem ele o pico saia com 17 graus).
	var w := _omega()
	var k := log(100.0) / ASSENTA_EM
	_vel += eixo * deg_to_rad(AMPLITUDE_GRAUS) * forca * w * exp(k * PI / (2.0 * w))
	set_process(true)


func balancando() -> bool:
	return is_processing()


func _omega() -> float:
	return sqrt(G / maxf(comprimento, 0.05))


func _process(delta: float) -> void:
	# Teto no passo: um engasgo de quadro nao pode fazer o pendulo explodir.
	var dt := minf(delta, 1.0 / 30.0)
	var w := _omega()
	var k := log(100.0) / ASSENTA_EM
	var th := _ang.length()
	# sin(th)/th: pendulo de verdade, e nao a aproximacao de angulo pequeno —
	# a 25 graus a diferenca no periodo ja aparece.
	var restaura := (sin(th) / th) if th > 0.0001 else 1.0
	var acc := -_ang * (w * w * restaura) - _vel * (2.0 * k)
	# Euler semi-implicito: estavel para este omega no passo de 1/30.
	_vel += acc * dt
	_ang += _vel * dt
	_aplicar()
	if _ang.length() < REPOUSO_ANG and _vel.length() < REPOUSO_VEL:
		_ang = Vector3.ZERO
		_vel = Vector3.ZERO
		_aplicar()
		set_process(false)
		parou.emit()


func _aplicar() -> void:
	var th := _ang.length()
	_pivo.basis = Basis(_ang / th, th) if th > 0.00001 else Basis.IDENTITY

## A luz que alguem PENDUROU: fita de LED, pisca-pisca, luz negra.
##
## Por que isto nao e uma Lampada
## -------------------------------
## A Lampada e luz de arquitetura: um ponto, uma cor, um alcance. O que faz a
## casa da fumaca ler como casa de gente de vinte anos e a luz que nao veio com
## a casa — a fita colada atras da TV, o fio de natal que ficou o ano inteiro na
## parede, a lampada roxa no quarto. Essas luzes tem FORMA (a fonte e uma linha,
## nao um ponto) e tem TEMPO (a fita troca de cor, o pisca corre). Um OmniLight
## sozinho nao desenha nenhuma das duas.
##
## Aqui a fonte visivel e a malha acesa ao longo de `caminho` — emissiva em HDR,
## entao o glow do MODERNO pega nela — e a luz que ela joga no comodo e UM
## OmniLight no meio do caminho, que acompanha a cor. Uma luz por fita, e nao uma
## por lampadinha: sao doze metros de fio e o orcamento e de luz de sala.
class_name LuzDeFesta
extends Node3D

enum Modo {
	## Fita de LED: linha continua que passeia pelo circulo de cores devagar.
	FITA,
	## Pisca-pisca: lampadinhas quentes que acendem em duas fases alternadas.
	PISCA,
	## Luz negra: tubo roxo parado. Pinta de violeta o que toca.
	NEGRA,
}

@export var modo: Modo = Modo.FITA
## Pontos do fio, em coordenada local. Dois ou mais.
@export var caminho: PackedVector3Array = PackedVector3Array()
@export var cor: Color = Color.WHITE
@export var energia: float = 1.0
@export var alcance: float = 3.0
## Para onde fica o comodo, visto da parede em que o fio esta colado. A luz sai
## 12 cm para esse lado: rente a parede, o halo nela e a fonte que se ve.
@export var fora: Vector3 = Vector3.ZERO

## Segundos para a fita dar a volta no circulo de cores. Lento: fita que troca de
## cor depressa le como boate, e isto e uma sala.
const CICLO_FITA := 26.0
## Periodo do pisca e quanto ele apaga no vale. Nunca a zero: lampadinha de
## natal barata esmaece, nao apaga.
const PERIODO_PISCA := 1.6
const VALE_PISCA := 0.28
## Brilho da malha acesa. Acima de 1 para o glow do MODERNO morder.
const BRILHO := 2.6

var _luz: OmniLight3D
var _mats: Array[StandardMaterial3D] = []
var _t := 0.0


func _ready() -> void:
	if caminho.size() < 2:
		return
	match modo:
		Modo.FITA, Modo.NEGRA:
			_montar_fita()
		Modo.PISCA:
			_montar_pisca()
	_luz = OmniLight3D.new()
	_luz.name = "Luz"
	# A luz fica rente a parede, a frente da fita: o halo na parede e a fonte.
	_luz.position = _meio() + fora * 0.12
	_luz.omni_range = alcance
	_luz.omni_attenuation = 1.4
	_luz.light_energy = energia
	_luz.light_color = cor
	_luz.light_specular = 0.25
	_luz.shadow_enabled = false
	add_child(_luz)
	_t = fmod(absf(global_position.x * 1.7 + global_position.z * 3.1), CICLO_FITA)
	set_process(modo != Modo.NEGRA)
	_aplicar(0.0)


func _process(delta: float) -> void:
	_t += delta
	_aplicar(_t)


func _aplicar(t: float) -> void:
	match modo:
		Modo.FITA:
			var c := Color.from_hsv(fposmod(t / CICLO_FITA + cor.h, 1.0), 0.85, 1.0)
			_mats[0].albedo_color = c * BRILHO
			_luz.light_color = c
		Modo.PISCA:
			var fase := t * TAU / PERIODO_PISCA
			var a := lerpf(VALE_PISCA, 1.0, 0.5 + 0.5 * sin(fase))
			var b := lerpf(VALE_PISCA, 1.0, 0.5 - 0.5 * sin(fase))
			_mats[0].albedo_color = cor * (BRILHO * a)
			_mats[1].albedo_color = cor * (BRILHO * b)
			_luz.light_energy = energia * (0.8 + 0.2 * (a + b) * 0.5)
		Modo.NEGRA:
			_mats[0].albedo_color = cor * BRILHO


func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = cor
	m.disable_receive_shadows = true
	_mats.append(m)
	return m


func _montar_fita() -> void:
	var grossura := 0.018 if modo == Modo.FITA else 0.032
	var d := PSXMesh.dados_vazios()
	for k in caminho.size() - 1:
		_segmento(d, caminho[k], caminho[k + 1], grossura)
	var mi := MeshInstance3D.new()
	mi.name = "Fio"
	mi.mesh = PSXMesh.dados_para_mesh(d)
	mi.material_override = _material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Lampadinha a cada 16 cm, alternando entre as duas fases, com o fio escuro
## passando por todas.
func _montar_pisca() -> void:
	var fases: Array[Dictionary] = [PSXMesh.dados_vazios(), PSXMesh.dados_vazios()]
	var fio := PSXMesh.dados_vazios()
	var n := 0
	for k in caminho.size() - 1:
		var a := caminho[k]
		var b := caminho[k + 1]
		_segmento(fio, a, b, 0.006)
		var passos := maxi(1, int(a.distance_to(b) / 0.16))
		for i in passos:
			var p := a.lerp(b, float(i) / float(passos))
			# Pendurada: o bulbo cai um dedo abaixo do fio.
			var bulbo := PSXMesh.box_dados(Vector3(0.022, 0.034, 0.022), 100.0)
			PSXMesh.acumular(fases[n % 2], bulbo,
				Transform3D(Basis(), p + Vector3(0.0, -0.022, 0.0)))
			n += 1
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.name = "Fase%d" % k
		mi.mesh = PSXMesh.dados_para_mesh(fases[k])
		mi.material_override = _material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var mf := MeshInstance3D.new()
	mf.name = "Fio"
	mf.mesh = PSXMesh.dados_para_mesh(fio)
	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = Color(0.05, 0.06, 0.05)
	mf.material_override = escuro
	mf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mf)


static func _segmento(d: Dictionary, a: Vector3, b: Vector3, grossura: float) -> void:
	var v := b - a
	var comp := v.length()
	if comp < 0.001:
		return
	var y := v / comp
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	var caixa := PSXMesh.box_dados(Vector3(grossura, comp + grossura, grossura), 100.0)
	PSXMesh.acumular(d, caixa, Transform3D(Basis(x, y, z), (a + b) * 0.5))


func _meio() -> Vector3:
	var soma := Vector3.ZERO
	for p: Vector3 in caminho:
		soma += p
	return soma / float(caminho.size())

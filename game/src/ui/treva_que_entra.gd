## A treva que entra no carro: da borda do quadro para dentro, em fiapos, ate so
## sobrar o telefone aceso no meio.
##
## Por que existe
## --------------
## A aura negra dos padres entra pela fresta da porta (`AuraNegra` na cabine),
## mas fumaca em 3D so enche o que a lente ve de perto. O que conta a historia
## e a PROPORCAO: com o telefone no tapete, o carro inteiro ja escureceu em volta
## dele. Isto e a metade que a lente nao alcanca — a treva fechando pelas bordas,
## com a textura de fumaca da aura, respirando.
##
## `cobre` vai de 0 (nada) a 1 (so um buraco em volta de `centro`).
class_name TrevaQueEntra
extends CanvasLayer

const SHADER := """
shader_type canvas_item;

uniform float cobre : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centro = vec2(0.5, 0.5);
uniform float aspecto = 1.777;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		s += a * ruido(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 d = (UV - centro) * vec2(aspecto, 1.0);
	float r = length(d);
	float t = TIME;
	// Fiapos: ruido em coordenada polar, correndo para dentro.
	float ang = atan(d.y, d.x);
	float fio = fbm(vec2(ang * 2.2 + 3.0, r * 2.6 - t * 0.35));
	float nuvem = fbm(UV * vec2(aspecto, 1.0) * 3.0 + vec2(t * 0.05, -t * 0.08));
	float livre = mix(1.25, 0.16, cobre) + sin(t * 1.3) * 0.012 * cobre;
	float x = r - livre + (fio - 0.5) * 0.55 + (nuvem - 0.5) * 0.25;
	float escuro = smoothstep(-0.02, 0.22, x);
	COLOR = vec4(0.012, 0.0, 0.006, escuro * 0.97 * smoothstep(0.0, 0.05, cobre));
}
"""

var cobre: float = 0.0:
	set(v):
		cobre = clampf(v, 0.0, 1.0)
		if _mat != null:
			_mat.set_shader_parameter("cobre", cobre)
			_tela.visible = cobre > 0.001

var _mat: ShaderMaterial
var _tela: ColorRect


func _init() -> void:
	name = "TrevaQueEntra"
	# Por cima do 3D e das barras do cinema nao: embaixo do branco do susto.
	layer = 60


func _ready() -> void:
	var s := Shader.new()
	s.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = s
	_tela = ColorRect.new()
	_tela.material = _mat
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.visible = false
	add_child(_tela)
	# Tamanho na mao: FULL_RECT debaixo de CanvasLayer fica 0 x 0.
	get_viewport().size_changed.connect(_medir)
	_medir()


## Onde fica o buraco, em fracao da tela.
func centrar(onde: Vector2) -> void:
	if _mat != null:
		_mat.set_shader_parameter("centro", onde)


func _medir() -> void:
	var tam := get_viewport().get_visible_rect().size
	_tela.position = Vector2.ZERO
	_tela.size = tam
	_mat.set_shader_parameter("aspecto", tam.x / maxf(tam.y, 1.0))

## A palpebra de quem acorda, desenhada na lente: duas bordas em arco que se
## fecham sobre a imagem, o desfoque de quem ainda nao acertou o olho e a luz
## avermelhada que atravessa a pele com o olho fechado.
##
## Por que nao e a cortina do `Cinema`
## -----------------------------------
## A cortina e um preto chapado que sobe e desce em alfa: serve para corte. Olho
## abrindo nao e corte. A palpebra de cima desce mais que a de baixo sobe, a
## fenda e mais estreita nas pontas, a borda e macia (os cilios), e enquanto o
## olho nao acerta o foco a imagem vem borrada e dobrada. Fechada, ela nao e
## preta: e o vermelho-escuro da luz do poste passando pela pele.
##
## Fica abaixo da tarja do `Cinema` (145) e acima do mundo: a tarja e moldura do
## filme, a palpebra e o olho de dentro dele. O grao e o pontilhado do
## pos-processo (150) passam por cima dela como passam por cima de tudo.
class_name PalpebraDaLente
extends CanvasLayer

const SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
// 0 fechado, 1 aberto de todo (a fenda passa das bordas da tela).
uniform float abertura : hint_range(0.0, 1.0) = 1.0;
// Desfoque de quem nao acertou o olho, em niveis de mip.
uniform float borrao = 0.0;
// Imagem dobrada (os dois olhos sem convergir), em fracao da largura.
uniform float duplo = 0.0;
uniform float aspecto = 1.7778;
// A luz que atravessa a palpebra fechada.
uniform vec3 cor_pele = vec3(0.16, 0.035, 0.02);
uniform float luz_pele = 0.35;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 cor = textureLod(tela, uv, borrao).rgb;
	if (duplo > 0.0) {
		vec3 outra = textureLod(tela, uv + vec2(duplo, duplo * 0.25), borrao).rgb;
		cor = mix(cor, outra, 0.42);
	}
	// A fenda: meia altura no centro, estreitando nas pontas como um olho. A
	// palpebra de cima faz quase todo o trabalho: o centro da fenda desce
	// enquanto ela fecha.
	float a = clamp(abertura, 0.0, 1.0);
	float x = (uv.x - 0.5) * aspecto;
	float largura = mix(0.35, 2.2, a);
	float meia = mix(0.0, 0.95, pow(a, 0.85)) * sqrt(max(0.0, 1.0 - (x * x) / (largura * largura)));
	float centro = 0.5 + (1.0 - a) * 0.07;
	float dy = uv.y - centro;
	// A de cima pesa mais: a borda dela e um pouco mais baixa que a de baixo.
	float borda = dy < 0.0 ? meia * 0.92 : meia;
	float macio = mix(0.035, 0.012, a) + borrao * 0.004;
	float dentro = 1.0 - smoothstep(borda - macio, borda + macio, abs(dy));
	// Sombra dos cilios logo dentro da borda.
	float cilio = smoothstep(borda - macio * 6.0, borda - macio, abs(dy)) * 0.55;
	vec3 aberto = cor * (1.0 - cilio * (1.0 - a * 0.6));
	vec3 fechado = cor_pele * luz_pele + cor * 0.03;
	COLOR = vec4(mix(fechado, aberto, dentro), 1.0);
}
"""

var abertura: float = 1.0:
	set(v):
		abertura = v
		_atualizar()
var borrao: float = 0.0:
	set(v):
		borrao = v
		_atualizar()
var duplo: float = 0.0:
	set(v):
		duplo = v
		_atualizar()

var _tela: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	name = "PalpebraDaLente"
	layer = 144


func _ready() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_tela = ColorRect.new()
	_tela.name = "Olho"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.material = _mat
	# Tamanho explicito: FULL_RECT sob CanvasLayer mede 0x0. O shader le a tela
	# por SCREEN_UV, entao sobrar retangulo nao muda nada.
	_tela.position = Vector2.ZERO
	_tela.size = Vector2(8192.0, 8192.0)
	add_child(_tela)
	_atualizar()


## Fecha de estalo, sem animacao: e como a cena comeca.
func fechar_de_imediato() -> void:
	abertura = 0.0


## Leva a palpebra a `alvo` em `duracao`. Abrir desacelera no fim (o olho
## pesado); fechar acelera (a palpebra cai).
func ir(alvo: float, duracao: float) -> void:
	var t := create_tween()
	if alvo > abertura:
		t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "abertura", alvo, maxf(duracao, 0.01))
	await t.finished


## Uma piscada: fecha, segura, abre ate onde estava (ou ate `ate`).
func piscar(fecha: float, segura: float, abre: float, ate: float = -1.0) -> void:
	var volta := abertura if ate < 0.0 else ate
	await ir(0.0, fecha)
	if segura > 0.0:
		await get_tree().create_timer(segura).timeout
	await ir(volta, abre)


## O olho acertando o foco: borrao e imagem dupla somem juntos.
func focar(borrao_alvo: float, duplo_alvo: float, duracao: float) -> void:
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "borrao", borrao_alvo, duracao)
	t.tween_property(self, "duplo", duplo_alvo, duracao)
	await t.finished


func _atualizar() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter(&"abertura", abertura)
	_mat.set_shader_parameter(&"borrao", borrao)
	_mat.set_shader_parameter(&"duplo", duplo)
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect().size
		if r.y > 0.0:
			_mat.set_shader_parameter(&"aspecto", r.x / r.y)
	# Aberto, focado e sem dobra, o olho nao desenha nada: a copia da tela
	# custa um quadro inteiro, e nao ha o que pagar.
	_tela.visible = abertura < 0.999 or borrao > 0.001 or duplo > 0.0001

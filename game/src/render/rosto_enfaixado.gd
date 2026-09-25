## O rosto dos outros padres (romeiros, vigias, os da janela) debaixo do capuz:
## a cabeca enfaixada da referencia `INTRO-PADRE/referencia/romeiro_enfaixado.png`
## — gaze suja e sangrada em volta da cabeca inteira, um olho arregalado e
## vermelho aparecendo por uma fresta, dentes pela outra, pontas soltas.
##
## Parte 4 do `INTRO-PADRE/PLANO_MONSTROS.md`.
##
## A forma e malha, nao textura
## ----------------------------
## Uma esfera com a foto de uma atadura le como bola pintada: a luz passa lisa
## por cima, a silhueta e redonda, e a fresta do olho e um desenho. Aqui cada
## volta de atadura e uma FAIXA de malha de verdade, com espessura, borda que
## enrola e franja de fio solto, deitada sobre um cranio (nao sobre uma bola:
## testa, nariz, macas, queixada estreita, queixo). As faixas sao faixas de
## latitude em volta de eixos tortos — a volta que a mao da quando enrola — e a
## de cima fica um milimetro acima da de baixo, entao o relevo faixa sobre faixa,
## a sombra de uma na outra e a silhueta encaroçada saem da propria geometria.
##
## As frestas nao sao recortes: sao o espaco que sobra entre duas faixas. O olho
## aparece na lente que a faixa de cima (A), a de baixo (B) e a da tempora (E)
## deixam; os dentes, no rasgo entre a faixa de cima da boca (C) e a de baixo
## (D), que se encontram nos cantos e sobem um pouco (o sorriso). Debaixo das
## faixas ha o cranio: gaze na camada de baixo, e carne inchada e viva onde a
## fresta deixa ver. O olho e um globo (esclera injetada, iris palida, pupila
## miuda) que salta para fora da orbita e segue a lente; os dentes, um a um,
## tortos, faltando, alguns de ponta.
##
## Pele (`tools/gerar_faixas.py`, saida em `assets/monstros/romeiro/`): a gaze
## fio a fio em 4K (albedo com a franja no alfa, normal e rugosidade), no espaco
## de cada faixa; o sangue (seco e fresco), o barro e o soro numa projecao
## cilindrica no espaco da CABECA, para que um escorrido atravesse faixa por
## faixa e desca da fresta como desceria de verdade.
##
## Pontas soltas
## -------------
## Duas faixas terminam soltas (no queixo e na queixada) e a ponta continua numa
## fita de Verlet, simulada aqui: presa na cabeca, com gravidade, arrasto, vento
## e colisao com a cabeca e o peito. Quando o `TiqueMacabro` estala o pescoco a
## ponta chicoteia e assenta. A fita e desenhada no shader a partir dos pontos
## (uma chamada por quadro, nenhuma malha refeita), e so simula perto da lente.
##
## Custo: a malha de cada variante (lado do olho x desenho das faixas) e montada
## uma vez e dividida por todos; o material e um so, e o que muda por figura
## (queixo, espelho das manchas, brilho do olho) sao uniformes de instancia.
class_name RostoEnfaixado
extends Node3D

# --- medidas compartilhadas com tools/gerar_faixas.py -----------------------------
## Largura de uma faixa (com a franja) e o passo da textura ao longo dela (m).
const FAIXA_LARGURA := 0.046
const FAIXA_PASSO := 0.186
## Altura que a projecao das manchas cobre, centrada no centro da cabeca.
const MANCHA_ALTURA := 0.36
## O olho aberto (em +x; o outro lado espelha) e a boca, no espaco da cabeca:
## centro da cabeca na origem, frente em -z.
const OLHO := Vector3(0.034, 0.012, -0.088)
const BOCA_Y := -0.058
const BOCA_MEIA := 0.043

# --- o cranio ----------------------------------------------------------------------
## Meia largura, meia altura ate o topo, meia profundidade ate a testa. Ate o
## queixo e ate a nuca e mais.
const CRANIO := Vector3(0.075, 0.104, 0.094)
const QUEIXO_Y := 0.120
const NUCA_Z := 0.104
## A frente e mais chata que uma elipse (o rosto e um plano que dobra nas
## tempora): superelipse no plano xz.
const EXPOENTE_FRENTE := 2.7
## O cocuruto e largo, nao ponta de ovo: superelipse tambem em y, em cima.
const EXPOENTE_TOPO := 2.6
## Quanto o centro da cabeca sobe sobre o rosto do `Corpo`: a caixa dele deixa o
## queixo dentro da gola da murca, e a boca e o que a fresta de baixo mostra.
const SOBE := 0.018

# --- as faixas ---------------------------------------------------------------------
## Distancia da primeira faixa ao cranio, e quanto cada volta sobe sobre a
## anterior. A espessura e o miolo da faixa; a borda enrola e a franja deita.
const SOBRE_CRANIO := 0.0022
const POR_CAMADA := 0.00085
const ESPESSURA := 0.0016
## Onde acaba o tecido e comeca a franja, em fracao da meia largura (o mesmo
## 0,075 de margem de gerar_faixas.py).
const BORDA_SOLIDA := 0.85
## Comprimento de cada passo da faixa: fino na frente, largo atras (o capuz tapa).
const PASSO_FRENTE := 0.005
const PASSO_ATRAS := 0.011
## A fresta do olho: quanto a borda de A fica acima do olho e a de B abaixo, e o
## quanto a da tempora (E) fica para fora dele.
const FRESTA_OLHO := Vector3(0.0135, 0.0125, 0.024)
## A fresta da boca: meia altura no meio.
const FRESTA_BOCA := 0.0088

# --- olho, dentes, queixo ------------------------------------------------------------
const OLHO_RAIO := 0.0125
## Quanto o globo passa da superficie lisa do rosto: arregalado.
const OLHO_SALTA := 0.0045
## Quanto o olho segue a lente, e ate que distancia.
const OLHO_SEGUE := 0.45
const OLHO_SEGUE_ATE := 9.0
## O brilho vermelho de dentro do olho (a forca que o capuz pede vezes isto), e
## o quad de longe: o globo de 2,5 cm vira um pixel a 20 m, e sao os olhos que
## atravessam a nevoa. Ele nasce entre PERTO e LONGE e cresce com a distancia.
const OLHO_BRILHO := 0.55
const BRILHO_QUAD := 0.030
const BRILHO_PERTO := 1.6
const BRILHO_LONGE := 3.4
## A dobradica do queixo (no espaco da cabeca) e o angulo com a boca em repouso
## e aberta de todo.
const DOBRADICA := Vector3(0.0, -0.030, 0.018)
const QUEIXO_REPOUSO := 0.02
const QUEIXO_ABERTO := 0.34

# --- pontas soltas ---------------------------------------------------------------------
const PONTA_PONTOS := 9
const PONTA_SEGMENTO := 0.024
const PONTA_LARGURA := 0.027
const GRAVIDADE := Vector3(0.0, -9.8, 0.0)
## Fracao da velocidade que sobra por passo de 1/60 s (o ar e a gaze molhada).
const PONTA_AMORTECE := 0.955
const PONTA_VENTO := 0.9
## Acima desta distancia da lente a ponta nao simula: fica onde esta.
const SIMULA_ATE := 9.0
## A cabeca, para a ponta nao entrar nela: elipsoide em volta das faixas.
const CABECA_COLIDE := Vector3(0.090, 0.125, 0.112)
const PASSO_FISICA := 1.0 / 90.0

const VARIANTES := 4

const FAIXA_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform sampler2D gaze_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gaze_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gaze_rug : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D manchas : filter_linear_mipmap, repeat_enable;
uniform sampler2D carne_alb : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D carne_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float altura_mancha = 0.36;
uniform vec3 dobradica = vec3(0.0, -0.03, 0.018);
instance uniform float queixo = 0.02;
instance uniform float espelho = 1.0;
instance uniform float fresco = 1.0;
instance uniform float sujo = 1.0;

varying vec3 repouso;

void vertex() {
	repouso = VERTEX;
	// COLOR.g: o quanto o vertice vai com o queixo.
	float a = -queixo * COLOR.g;
	if (a != 0.0) {
		float c = cos(a);
		float s = sin(a);
		vec3 p = VERTEX - dobradica;
		VERTEX = dobradica + vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
		NORMAL = vec3(NORMAL.x, NORMAL.y * c - NORMAL.z * s, NORMAL.y * s + NORMAL.z * c);
		TANGENT = vec3(TANGENT.x, TANGENT.y * c - TANGENT.z * s, TANGENT.y * s + TANGENT.z * c);
		BINORMAL = vec3(BINORMAL.x, BINORMAL.y * c - BINORMAL.z * s, BINORMAL.y * s + BINORMAL.z * c);
	}
}

void fragment() {
	bool cranio = UV2.x > 0.5;
	vec4 g = texture(gaze_alb, UV);
	if (!cranio) {
		ALPHA = g.a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	vec3 alb = g.rgb;
	float rug = texture(gaze_rug, UV).r;
	vec3 nm = texture(gaze_nrm, UV).rgb;
	// A camada de baixo, que so aparece entre as faixas, esta na sombra delas.
	float ao = COLOR.b;
	// A carne (so no cranio): o olho e a boca que as frestas mostram.
	float carne = cranio ? COLOR.r : 0.0;
	if (carne > 0.0) {
		vec2 cuv = repouso.xy * 11.0;
		vec3 c = texture(carne_alb, cuv).rgb;
		alb = mix(alb, c, carne);
		nm = mix(nm, texture(carne_nrm, cuv).rgb, carne);
		rug = mix(rug, 0.42, carne);
	}
	// O sangue, o barro e o soro: no espaco da cabeca, em volta do eixo y.
	vec2 muv = vec2(atan(repouso.x * espelho, -repouso.z) / 6.2831853 + 0.5,
		0.5 - repouso.y / altura_mancha);
	vec4 m = texture(manchas, muv);
	float lum = dot(g.rgb, vec3(0.33));
	float suj = m.b * sujo;
	alb *= mix(vec3(1.0), vec3(0.28, 0.20, 0.12), suj * 0.85);
	alb = mix(alb, vec3(0.50, 0.30, 0.08) * (0.6 + 0.5 * lum), m.a * 0.35 * (1.0 - carne));
	// Seco: marrom, entra na trama (escurece mais no fio fundo).
	float seco = m.r;
	alb = mix(alb, vec3(0.085, 0.017, 0.008) * (0.55 + 0.6 * lum), seco * 0.92);
	rug = mix(rug, 0.62, seco * 0.6);
	// Fresco: vermelho, molhado, brilha.
	float fr = clamp(m.g * fresco, 0.0, 1.0);
	alb = mix(alb, vec3(0.13, 0.004, 0.003), fr * 0.95);
	rug = mix(rug, 0.22, fr);
	// O fundo da boca: nada volta dele.
	float fundo = cranio ? COLOR.a : 0.0;
	alb = mix(alb, vec3(0.02, 0.003, 0.002), fundo);
	ao *= 1.0 - fundo * 0.8;
	// O fundo nao brilha: o farol fazia um espelho dentro da boca.
	rug = mix(rug, 0.7, fundo);
	fr *= 1.0 - fundo;
	ALBEDO = alb * mix(1.0, ao, 0.55);
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
	ROUGHNESS = rug;
	SPECULAR = mix(0.35, 0.6, fr + carne * 0.5) * (1.0 - fundo * 0.85);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = mix(1.0, 0.4, fr);
	// Gaze fina deixa passar luz: o contraluz do farol acende a borda.
	BACKLIGHT = alb * 0.18 * (1.0 - carne);
}
"""

const OLHO_SHADER := """
shader_type spatial;
render_mode cull_back;

uniform sampler2D olho_tex : source_color, filter_linear_mipmap_anisotropic;
instance uniform float brilho = 0.0;

varying vec3 local;

void vertex() {
	local = normalize(VERTEX);
	// A cornea: a frente do globo abaulada.
	float c = smoothstep(0.86, 1.0, -local.z);
	VERTEX += local * c * 0.0009;
}

void fragment() {
	vec2 uv = vec2(0.5 + local.x * 0.5, 0.5 - local.y * 0.5);
	vec4 t = texture(olho_tex, uv);
	ALBEDO = t.rgb;
	ROUGHNESS = 0.07;
	SPECULAR = 0.65;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.04;
	// O olho acende por dentro (a pupila e a iris), vermelho — de longe. De
	// perto e um olho: o brilho vira um alvo pintado.
	float d = length(VERTEX);
	EMISSION = vec3(1.0, 0.06, 0.02) * t.a * t.a * brilho * smoothstep(1.2, 3.0, d);
}
"""

const BRILHO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform float perto = 1.6;
uniform float longe = 3.4;
instance uniform float forca = 1.0;
instance uniform float escala = 1.0;

void vertex() {
	// Billboard. Perto nao existe (o globo de verdade responde); da distancia
	// PERTO a LONGE ele nasce, e dai cresce com a distancia para nao sumir
	// entre dois quadros.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float d = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
	VERTEX *= max(1.0, d / longe) * escala * smoothstep(perto, longe, d);
}

void fragment() {
	// Opaco, e nao somado: o vidro da janela refrata a copia da tela feita antes
	// dos transparentes (ver CapuzMacabro.OLHO_SHADER).
	float r = length(UV * 2.0 - 1.0);
	if (r > 0.34) {
		discard;
	}
	float nucleo = smoothstep(0.34, 0.0, r);
	vec3 cor = mix(vec3(1.0, 0.05, 0.012), vec3(1.0, 0.5, 0.3), nucleo * nucleo);
	ALBEDO = cor * (0.6 + nucleo * 3.4) * forca;
}
"""

const PONTA_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D gaze_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gaze_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gaze_rug : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Os pontos de cada fita (PONTA_PONTOS por fita, no mundo) e o lado (a
// direcao que atravessa a fita) em cada um.
uniform vec3 pontos[32];
uniform vec3 lados[32];
uniform int por_fita = 9;
uniform float largura = 0.032;
uniform vec4 sangue = vec4(0.0);

varying float ao_longo;

vec3 catmull(vec3 a, vec3 b, vec3 c, vec3 d, float t) {
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t
		+ (-a + 3.0 * b - 3.0 * c + d) * t * t * t);
}

void vertex() {
	// UV2.x: a fita e o ponto (fita * por_fita + indice, fracionario); UV2.y: o
	// lado (-1 a 1).
	int fita = int(floor(UV2.x / float(por_fita) + 0.001));
	float fi = UV2.x - float(fita * por_fita);
	int base = fita * por_fita;
	int n = por_fita - 1;
	int i1 = clamp(int(floor(fi)), 0, n - 1);
	float t = fi - float(i1);
	int i0 = max(i1 - 1, 0);
	int i2 = min(i1 + 1, n);
	int i3 = min(i1 + 2, n);
	vec3 p = catmull(pontos[base + i0], pontos[base + i1], pontos[base + i2], pontos[base + i3], t);
	vec3 lado = normalize(mix(lados[base + i1], lados[base + i2], t));
	vec3 tan = normalize(pontos[base + i2] - pontos[base + i1]);
	ao_longo = fi / float(n);
	// Afina e amassa para a ponta: a gaze solta embola.
	float w = largura * mix(1.0, 0.62, ao_longo) * 0.5;
	NORMAL = normalize(cross(tan, lado));
	// Amassada: a gaze solta nao fica lisa, dobra ao comprido.
	float amassa = sin(fi * 2.3 + UV2.y * 1.7) * 0.0022 + sin(fi * 5.1 - UV2.y * 2.9) * 0.0012;
	VERTEX = p + lado * w * UV2.y + NORMAL * amassa * (0.4 + ao_longo);
	TANGENT = tan;
	BINORMAL = lado;
}

void fragment() {
	vec4 g = texture(gaze_alb, UV);
	// A ponta rasgada: corte torto nos ultimos centimetros.
	float corte = 0.94 - 0.06 * sin(UV.y * 71.0) - 0.03 * sin(UV.y * 173.0 + 1.0);
	ALPHA = g.a * step(ao_longo, corte);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 alb = g.rgb;
	float lum = dot(alb, vec3(0.33));
	alb *= mix(vec3(1.0), vec3(0.28, 0.20, 0.12), 0.12 + 0.28 * ao_longo);
	alb = mix(alb, vec3(0.085, 0.017, 0.008) * (0.55 + 0.6 * lum), sangue.x * smoothstep(0.1, 0.8, ao_longo));
	alb = mix(alb, vec3(0.13, 0.004, 0.003), sangue.y * smoothstep(0.55, 1.0, ao_longo));
	ALBEDO = alb;
	ROUGHNESS = mix(max(texture(gaze_rug, UV).r, 0.8), 0.2, sangue.y * smoothstep(0.35, 1.0, ao_longo));
	SPECULAR = 0.25;
	NORMAL_MAP = texture(gaze_nrm, UV).rgb;
	BACKLIGHT = alb * 0.3;
}
"""

const PASTA := "res://assets/monstros/romeiro/"

## A malha de cada variante: {faixas: ArrayMesh, dentes_cima, dentes_baixo,
## olho: Vector3 (centro do globo), pontas: Array de {pos, tangente, lado}}.
static var _variantes: Dictionary = {}
static var _mat_faixa: ShaderMaterial
static var _mat_olho: ShaderMaterial
static var _mat_dente: StandardMaterial3D
static var _shader_brilho: Shader
static var _mat_brilho: ShaderMaterial
static var _shader_ponta: Shader
static var _malha_olho: SphereMesh
static var _malha_brilho: QuadMesh

var _cabeca: MeshInstance3D
var _queixo: Node3D
var _globo: MeshInstance3D
var _brilho: MeshInstance3D
var _fitas: MeshInstance3D
var _mat_fitas: ShaderMaterial
var _corpo: Corpo
var _olho_centro := Vector3.ZERO
var _olho_repouso := Basis.IDENTITY
## Por fita: pontos atuais e anteriores (mundo), a ancora (cabeca) e o lado.
var _ancoras: Array[Dictionary] = []
var _pos := PackedVector3Array()
var _ant := PackedVector3Array()
var _lados := PackedVector3Array()
var _acumulado := 0.0
var _t := 0.0
var _semente := 0
var _peito_raio := Vector3(0.27, 0.30, 0.22)
var _peito_centro := Vector3.ZERO


## Poe o rosto em `c`, debaixo de `capuz`. `semente` varia faixa, sangue e qual
## olho aparece. Null se ainda nao ha rosto.
static func vestir(c: Corpo, _capuz: CapuzMacabro, semente: int) -> RostoEnfaixado:
	var no := MonstroDaEstrada.no_da_cabeca(c, "Faixas")
	if no == null:
		return null
	var r := RostoEnfaixado.new()
	r.name = "RostoEnfaixado"
	r._corpo = c
	r._semente = semente
	no.add_child(r)
	# O centro da cabeca: a altura do rosto do `Corpo`, no meio da caixa em z.
	r.position = Vector3(0.0, c.plano_do_rosto().origin.y + SOBE, 0.0)
	var esq := c.esqueleto()
	if esq != null:
		var y_cab := esq.get_bone_global_rest(Corpo.Osso.CABECA).origin.y
		var y_tor := esq.get_bone_global_rest(Corpo.Osso.TORSO).origin.y
		# O peito como a murca do capuz o veste (CapuzMacabro._montar_murca), no
		# espaco do osso do torso: e nele que a ponta solta deita.
		r._peito_centro = Vector3(0.0, y_cab - y_tor - 0.26, -0.02)
	r._montar(semente)
	return r


## O cranio enfaixado (sem o pescoco) no espaco do pai, que e o do osso da
## cabeca: e nele que o capuz de pano se ajusta (`CapuzMacabro`). Medido do
## `_superficie` com as faixas por cima (~6 mm) e o nariz.
func elipsoide() -> AABB:
	var de := Vector3(-CRANIO.x - 0.007, -QUEIXO_Y - 0.004, -CRANIO.z - 0.019)
	var ate := Vector3(CRANIO.x + 0.007, CRANIO.y + 0.007, NUCA_Z + 0.007)
	return AABB(position + de, ate - de)


## 0 a boca no repouso, 1 aberta de todo.
func por_sorriso(v: float) -> void:
	var a := lerpf(QUEIXO_REPOUSO, QUEIXO_ABERTO, clampf(v, 0.0, 1.0))
	if _cabeca != null:
		_cabeca.set_instance_shader_parameter(&"queixo", a)
	if _queixo != null:
		_queixo.basis = Basis(Vector3.RIGHT, -a)


## `forca` e o brilho que o capuz pede para os olhos (0 apagados); `tamanho` o
## quanto crescem atras do vidro embacado.
func por_olhos(forca: float, tamanho: float) -> void:
	if _globo != null:
		_globo.set_instance_shader_parameter(&"brilho", forca * OLHO_BRILHO)
	if _brilho != null:
		_brilho.visible = forca > 0.01
		_brilho.set_instance_shader_parameter(&"forca", forca)
		_brilho.set_instance_shader_parameter(&"escala", tamanho)


# --- montagem --------------------------------------------------------------------------

func _montar(semente: int) -> void:
	var qual := posmod(semente, VARIANTES)
	var v := _variante(qual)
	var sx: float = v["lado"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 51 + semente * 7919

	_cabeca = MeshInstance3D.new()
	_cabeca.name = "Faixas"
	_cabeca.mesh = v["faixas"]
	_cabeca.material_override = _material_faixa()
	add_child(_cabeca)
	_cabeca.set_instance_shader_parameter(&"espelho", sx)
	_cabeca.set_instance_shader_parameter(&"fresco", rng.randf_range(0.65, 1.0))
	_cabeca.set_instance_shader_parameter(&"sujo", rng.randf_range(0.6, 1.1))

	var dentes := MeshInstance3D.new()
	dentes.name = "DentesDeCima"
	dentes.mesh = v["dentes_cima"]
	dentes.material_override = _material_dente()
	dentes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dentes)
	_queixo = Node3D.new()
	_queixo.name = "Queixo"
	add_child(_queixo)
	_queixo.position = DOBRADICA
	var baixo := MeshInstance3D.new()
	baixo.name = "DentesDeBaixo"
	baixo.mesh = v["dentes_baixo"]
	baixo.material_override = _material_dente()
	baixo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_queixo.add_child(baixo)
	baixo.position = -DOBRADICA

	_olho_centro = v["olho"]
	_globo = MeshInstance3D.new()
	_globo.name = "Olho"
	_globo.mesh = _malha_do_olho()
	_globo.material_override = _material_olho()
	_globo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_globo)
	_globo.position = _olho_centro
	# Um tico para fora e para baixo: o olho arregalado nao olha reto.
	_olho_repouso = Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.02),
		sx * rng.randf_range(0.02, 0.12), 0.0))
	_globo.basis = _olho_repouso

	_brilho = MeshInstance3D.new()
	_brilho.name = "BrilhoDoOlho"
	_brilho.mesh = _malha_do_brilho()
	_brilho.material_override = _material_brilho()
	_brilho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_brilho)
	_brilho.position = _olho_centro + Vector3(0.0, 0.0, -OLHO_RAIO - 0.002)

	_montar_pontas(v["pontas"], rng)
	por_sorriso(0.0)
	por_olhos(1.0, 1.0)


static func _variante(qual: int) -> Dictionary:
	if _variantes.has(qual):
		return _variantes[qual]
	var sx := 1.0 if qual % 2 == 0 else -1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001 + (qual / 2) * 131
	var faixas := _desenhar(sx, rng)
	for p in _frestas(sx):
		for k in faixas.size():
			var dist := _ate_a_borda(faixas[k], p.normalized())
			if dist < -0.002:
				print("[rosto_enfaixado] variante %d: faixa %d tapa %s (%.1f mm)" % [qual, k, p, dist * 1000.0])
	var pontas: Array = []
	var malha := _malha_da_cabeca(faixas, sx, pontas)
	var olho_d := _olho_lado(sx).normalized()
	var olho := _superficie(olho_d, true, sx) + olho_d * (OLHO_SALTA - OLHO_RAIO)
	var dentes := _malha_dos_dentes(sx, rng)
	var v := {"lado": sx, "faixas": malha, "olho": olho, "pontas": pontas,
		"dentes_cima": dentes[0], "dentes_baixo": dentes[1]}
	_variantes[qual] = v
	return v


static func _olho_lado(sx: float) -> Vector3:
	return Vector3(OLHO.x * sx, OLHO.y, OLHO.z)


# --- o cranio ---------------------------------------------------------------------------

static func _suave(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _g(x: float) -> float:
	return exp(-x * x)


## O ponto do cranio na direcao `d` (unitaria, do centro da cabeca). `liso` e a
## superficie onde as faixas deitam: a gaze esticada passa por cima da orbita e
## da boca; sem `liso` vem a carne, com a orbita funda, a boca aberta para dentro
## e o inchaco em volta do olho que a fresta mostra.
static func _superficie(d: Vector3, liso: bool, sx: float) -> Vector3:
	var b := CRANIO.y if d.y > 0.0 else QUEIXO_Y
	var cz := CRANIO.z if d.z < 0.0 else NUCA_Z
	var p := EXPOENTE_FRENTE if d.z < 0.0 else 2.0
	var qy := EXPOENTE_TOPO if d.y > 0.0 else 2.0
	var xz := pow(pow(absf(d.x) / CRANIO.x, p) + pow(absf(d.z) / cz, p), qy / p)
	var r := pow(xz + pow(absf(d.y) / b, qy), -1.0 / qy)
	var q := d * r
	# A queixada estreita para baixo.
	q.x *= lerpf(1.0, 0.76, _suave(-0.02, -0.115, q.y))
	var frente := _suave(-0.03, -0.075, q.z)
	var rel := 0.0
	# Nariz, sobrancelha, macas, queixo.
	rel += 0.012 * _g(q.x / 0.0105) * _g((q.y + 0.024) / 0.017) * frente
	rel += 0.0045 * _g((q.y - 0.034) / 0.011) * _suave(0.062, 0.03, absf(q.x)) * frente
	rel += 0.004 * _g((absf(q.x) - 0.045) / 0.014) * _g((q.y + 0.014) / 0.014) * frente
	rel += 0.007 * _g(q.x / 0.022) * _g((q.y + 0.103) / 0.015) * frente
	if liso:
		# A gaze cede um pouco na orbita tapada e na boca.
		rel -= 0.002 * _g((q.x + OLHO.x * sx) / 0.013) * _g((q.y - OLHO.y) / 0.013) * frente
	else:
		for lado: float in [-1.0, 1.0]:
			var e := Vector2(q.x - lado * OLHO.x, q.y - OLHO.y).length()
			rel -= 0.011 * _g(e / 0.0125) * frente
			if lado == sx:
				# A carne inchada em volta do olho aberto, vermelha na fresta.
				rel += 0.0045 * _g((e - 0.019) / 0.007) * frente
		var bx := q.x / BOCA_MEIA
		var by := (q.y - BOCA_Y) / 0.013
		rel -= 0.017 * exp(-(bx * bx * bx * bx + by * by)) * frente
		# Os labios: rolo de carne em volta do rasgo.
		rel += 0.0012 * _g((absf(by) - 1.05) / 0.45) * exp(-bx * bx * bx * bx) * frente
	return q + d * rel


# --- as faixas: desenho ---------------------------------------------------------------

## Uma faixa: latitude `lat0` em volta do eixo `n`, da longitude `s0` a `s1`
## (volta inteira se cobre TAU). `camada` ordena (maior fica por cima), `linha`
## e a linha da textura (0 inteira, 1 gasta). A longitude 0 e a frente.
static func _faixa(n: Vector3, lat0: float, camada: int, linha: int,
		rng: RandomNumberGenerator, s0: float = -PI, s1: float = PI) -> Dictionary:
	n = n.normalized()
	var ref := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.UP
	var e1 := (ref - n * n.dot(ref)).normalized()
	var e2 := n.cross(e1)
	var ondas: Array = []
	for k in 3:
		ondas.append(Vector3(rng.randf_range(0.015, 0.035) / float(k + 1),
			float(rng.randi_range(2, 5) + k * 2), rng.randf_range(0.0, TAU)))
	return {"n": n, "e1": e1, "e2": e2, "lat0": lat0, "camada": camada, "linha": linha,
		"s0": s0, "s1": s1, "ondas": ondas, "boca": 0.0, "u0": rng.randf(),
		"ruga": rng.randf_range(0.0, TAU), "ponta": false}


static func _lat(f: Dictionary, s: float) -> float:
	var lat: float = f["lat0"]
	for o: Vector3 in f["ondas"]:
		lat += o.x * sin(o.y * s + o.z)
	var boca: float = f["boca"]
	if boca != 0.0:
		# As faixas da boca: fora do rasgo elas se fecham uma sobre a outra, e
		# dentro os cantos sobem (o sorriso). s ~ angulo a partir da frente.
		var canto := asin(BOCA_MEIA / 0.09)
		var a := absf(s)
		lat += boca * 0.0115 / 0.09 * _suave(canto * 0.7, canto * 1.15, a)
		lat += 0.0055 / 0.09 * pow(minf(a / canto, 1.2), 2.0)
	return lat


static func _dir(f: Dictionary, s: float, lat: float) -> Vector3:
	var e1: Vector3 = f["e1"]
	var e2: Vector3 = f["e2"]
	var n: Vector3 = f["n"]
	return (e1 * cos(s) + e2 * sin(s)) * cos(lat) + n * sin(lat)


static func _longitude(f: Dictionary, d: Vector3) -> float:
	return atan2(d.dot(f["e2"]), d.dot(f["e1"]))


static func _no_arco(f: Dictionary, s: float) -> bool:
	var s0: float = f["s0"]
	var s1: float = f["s1"]
	if s1 - s0 >= TAU - 0.001:
		return true
	return fposmod(s - s0, TAU) <= s1 - s0


## Distancia (m, na superficie) de `d` ate a borda do tecido da faixa `f`;
## negativa dentro dela. INF fora do arco.
static func _ate_a_borda(f: Dictionary, d: Vector3) -> float:
	var s := _longitude(f, d)
	if not _no_arco(f, s):
		return INF
	var lat := asin(clampf(d.dot(f["n"]), -1.0, 1.0))
	var meia := BORDA_SOLIDA * FAIXA_LARGURA * 0.5 / 0.095
	return (absf(lat - _lat(f, s)) - meia) * 0.095


## Poe a borda de baixo (`de_cima` true: a faixa fica acima do ponto) ou a de
## cima da faixa passando em `alvo`.
static func _pela_borda(f: Dictionary, alvo: Vector3, de_cima: bool, sx: float) -> void:
	var d := alvo.normalized()
	var s := _longitude(f, d)
	var lat_alvo := asin(clampf(d.dot(f["n"]), -1.0, 1.0))
	var r := _superficie(d, true, sx).length()
	var meia := BORDA_SOLIDA * FAIXA_LARGURA * 0.5 / r
	f["lat0"] = 0.0
	var desvio := _lat(f, s)
	f["lat0"] = lat_alvo - desvio + (meia if de_cima else -meia)


## Pontos que nenhuma faixa pode tapar: a lente do olho e o rasgo da boca.
static func _frestas(sx: float) -> Array[Vector3]:
	var o := _olho_lado(sx)
	var pts: Array[Vector3] = [o, o + Vector3(0.0, 0.009, 0.0), o + Vector3(0.0, -0.008, 0.0),
		o + Vector3(sx * 0.012, 0.0, 0.0), o + Vector3(-sx * 0.012, 0.0, 0.0)]
	for k in 7:
		var x := lerpf(-0.8, 0.8, float(k) / 6.0) * BOCA_MEIA
		pts.append(Vector3(x, BOCA_Y + 0.0055 * pow(x / BOCA_MEIA, 2.0), -0.085))
	return pts


static func _tapa(f: Dictionary, sx: float) -> Vector3:
	for p in _frestas(sx):
		if _ate_a_borda(f, p.normalized()) < 0.002:
			return p
	return Vector3.ZERO


## Afasta a faixa das frestas mexendo na latitude: foge do primeiro ponto que
## tapa (se ele esta acima do meio dela, ela desce) e segue para o mesmo lado
## ate largar todos — trocar de lado a cada ponto a deixava presa. Se para
## aquele lado nao ha saida, tenta o outro; se nenhum, a faixa vira um arco so
## pela nuca (o capuz tapa as pontas).
static func _desobstruir(f: Dictionary, sx: float) -> void:
	var p := _tapa(f, sx)
	if p == Vector3.ZERO:
		return
	var d := p.normalized()
	var lat := asin(clampf(d.dot(f["n"]), -1.0, 1.0))
	var sinal := 1.0 if lat >= _lat(f, _longitude(f, d)) else -1.0
	var lat0: float = f["lat0"]
	for tentativa in 2:
		f["lat0"] = lat0
		for _i in 45:
			f["lat0"] = float(f["lat0"]) - sinal * 0.008
			if _tapa(f, sx) == Vector3.ZERO:
				return
		sinal = -sinal
	f["lat0"] = lat0
	f["s0"] = 1.3
	f["s1"] = TAU - 1.3


## As faixas de uma variante, de baixo para cima. `sx` e o lado do olho aberto.
static func _desenhar(sx: float, rng: RandomNumberGenerator) -> Array:
	var fs: Array = []
	var olho := _olho_lado(sx)
	var tapado := Vector3(-olho.x, olho.y, olho.z)
	var frente_boca := Vector3(0.0, BOCA_Y, -0.085)
	var jit := func(a: float) -> float: return a + rng.randf_range(-0.06, 0.06)

	# 0-1: as voltas de baixo, que so aparecem entre as outras: a do queixo ao
	# alto da cabeca (na frente das orelhas) e uma pela nuca.
	var f := _faixa(Vector3.BACK.rotated(Vector3.RIGHT, jit.call(0.32)), 0.05, 0, 1, rng)
	fs.append(f)
	f = _faixa(Vector3.UP.rotated(Vector3.RIGHT, jit.call(0.5)), 0.15, 1, 0, rng, 1.9, TAU - 1.9)
	fs.append(f)
	# 2-3: duas diagonais pelo cocuruto, que descem na tempora.
	f = _faixa(Vector3.UP.rotated(Vector3.BACK, sx * jit.call(0.95)).rotated(Vector3.RIGHT, 0.15),
		0.42, 2, 0, rng)
	_desobstruir(f, sx)
	fs.append(f)
	f = _faixa(Vector3.UP.rotated(Vector3.BACK, -sx * jit.call(0.75)).rotated(Vector3.RIGHT, -0.25),
		0.50, 3, 1, rng)
	_desobstruir(f, sx)
	fs.append(f)
	# 4: a testa, mais baixa na frente.
	f = _faixa(Vector3.UP.rotated(Vector3.RIGHT, jit.call(-0.30)).rotated(Vector3.BACK, sx * 0.08),
		0.0, 4, 0, rng)
	_pela_borda(f, Vector3(0.0, OLHO.y + 0.036, -0.09), true, sx)
	_desobstruir(f, sx)
	fs.append(f)
	# 5: a volta do queixo, embaixo da boca, subindo pela nuca.
	f = _faixa(Vector3.UP.rotated(Vector3.RIGHT, jit.call(0.62)), 0.0, 5, 1, rng)
	_pela_borda(f, Vector3(0.0, BOCA_Y - 0.030, -0.08), false, sx)
	_desobstruir(f, sx)
	fs.append(f)
	# 6-7: D (embaixo da boca) e C (em cima): o rasgo dos dentes.
	f = _faixa(Vector3.UP.rotated(Vector3.BACK, -sx * 0.05).rotated(Vector3.RIGHT, 0.12),
		0.0, 6, 0, rng)
	f["boca"] = 1.0
	_pela_borda(f, frente_boca + Vector3(0.0, -FRESTA_BOCA, 0.0), false, sx)
	fs.append(f)
	f = _faixa(Vector3.UP.rotated(Vector3.BACK, sx * 0.03).rotated(Vector3.RIGHT, -0.08),
		0.0, 7, 1, rng)
	f["boca"] = -1.0
	_pela_borda(f, frente_boca + Vector3(0.0, FRESTA_BOCA, 0.0), true, sx)
	fs.append(f)
	# 8-9: B (embaixo do olho, subindo para o outro lado e tapando o outro olho)
	# e A (em cima, descendo para o outro lado). As duas se cruzam no nariz.
	f = _faixa(Vector3.UP.rotated(Vector3.BACK, -sx * jit.call(0.34)), 0.0, 8, 0, rng)
	_pela_borda(f, olho + Vector3(0.0, -FRESTA_OLHO.y, 0.0), false, sx)
	fs.append(f)
	f = _faixa(Vector3.UP.rotated(Vector3.BACK, sx * jit.call(0.30)), 0.0, 9, 0, rng)
	_pela_borda(f, olho + Vector3(0.0, FRESTA_OLHO.x, 0.0), true, sx)
	fs.append(f)
	# 10: E, a da tempora, quase em pe: fecha a lente do olho por fora.
	f = _faixa(Vector3(sx, 0.0, 0.0).rotated(Vector3.BACK, sx * jit.call(0.22)), 0.0, 10, 1, rng)
	_pela_borda(f, olho + Vector3(sx * FRESTA_OLHO.z, 0.0, 0.0), true, sx)
	_desobstruir(f, sx)
	fs.append(f)
	# 11: F, em diagonal por cima do olho tapado (a mancha grande de sangue).
	# Inclinada ate o rasgo da boca ficar livre.
	for k in 12:
		var inclina := -sx * (0.25 + 0.05 * float(k))
		f = _faixa(Vector3(-sx, 0.0, 0.0).rotated(Vector3.BACK, inclina), 0.0, 11, 0, rng)
		var d := tapado.normalized()
		f["lat0"] = 0.0
		f["lat0"] = asin(clampf(d.dot(f["n"]), -1.0, 1.0)) - _lat(f, _longitude(f, d))
		var livre := true
		for p in _frestas(sx):
			if _ate_a_borda(f, p.normalized()) < 0.002:
				livre = false
		if livre:
			break
	_desobstruir(f, sx)
	fs.append(f)
	# 12: a volta do queixo que termina solta embaixo do queixo (ponta 1).
	f = _faixa(Vector3.UP.rotated(Vector3.RIGHT, -0.55).rotated(Vector3.BACK, sx * 0.1), 0.0, 12, 1,
		rng)
	_pela_borda(f, Vector3(0.0, BOCA_Y - 0.036, -0.075), false, sx)
	var fim := -sx * 0.9
	f["s0"] = fim - 3.9 if sx > 0.0 else fim
	f["s1"] = fim if sx > 0.0 else fim + 3.9
	f["ponta"] = true
	f["ponta_em"] = 1 if sx > 0.0 else 0
	_desobstruir(f, sx)
	fs.append(f)
	# 13: uma que desce pela queixada do lado tapado e fica solta (ponta 2).
	f = _faixa(Vector3.UP.rotated(Vector3.BACK, sx * 0.55).rotated(Vector3.RIGHT, 0.3), 0.0, 13, 0,
		rng)
	_pela_borda(f, Vector3(-sx * 0.058, BOCA_Y - 0.004, -0.06), false, sx)
	var fim2 := sx * 1.1
	f["s0"] = fim2 if sx > 0.0 else fim2 - 3.6
	f["s1"] = fim2 + 3.6 if sx > 0.0 else fim2
	f["ponta"] = true
	f["ponta_em"] = 0 if sx > 0.0 else 1
	_desobstruir(f, sx)
	fs.append(f)
	return fs


# --- as faixas: malha -------------------------------------------------------------------

## Perfil atravessando a faixa (t de -1 a 1): o miolo cheio, a borda enrolada,
## e a franja que deita na camada de baixo.
static func _perfil(t: float) -> float:
	var a := absf(t)
	if a <= BORDA_SOLIDA:
		return 1.0 + 0.35 * _g((a - 0.78) / 0.06) - 0.1 * a
	return lerpf(0.9, -1.4, _suave(BORDA_SOLIDA, 1.0, a))


const _ATRAVESSA := [-1.0, -0.93, -0.86, -0.75, -0.4, 0.0, 0.4, 0.75, 0.86, 0.93, 1.0]


static func _malha_da_cabeca(faixas: Array, sx: float, pontas: Array) -> ArrayMesh:
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cor := PackedColorArray()
	var idx := PackedInt32Array()
	_montar_cranio(faixas, sx, pos, uv, uv2, cor, idx)
	for f: Dictionary in faixas:
		_montar_faixa(f, faixas, sx, pos, uv, uv2, cor, idx, pontas)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = cor
	arr[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	st.generate_tangents()
	# Niveis de detalhe: de longe a cabeca ocupa um punhado de pixels, e sao
	# dezessete delas na cena.
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


## O peso do queixo num ponto do espaco da cabeca: tudo abaixo do rasgo da
## boca, na frente; nada da orelha para tras.
static func _peso_queixo(p: Vector3) -> float:
	return _suave(BOCA_Y + 0.002, BOCA_Y - 0.010, p.y) * _suave(0.03, -0.035, p.z)


## A sombra de uma faixa por cima: `d` logo fora da borda de uma faixa de camada
## maior que `camada` escurece. Nas costas nao conta (o capuz tapa).
static func _oclusao(d: Vector3, faixas: Array, camada: int) -> float:
	if d.z > 0.0:
		return 1.0
	var ao := 1.0
	for g: Dictionary in faixas:
		if int(g["camada"]) <= camada:
			continue
		var dist := _ate_a_borda(g, d)
		if dist < 0.0065 and dist > -0.004:
			ao *= lerpf(0.42, 1.0, _suave(-0.001, 0.0065, dist))
	return ao


static func _montar_cranio(faixas: Array, sx: float, pos: PackedVector3Array,
		uv: PackedVector2Array, uv2: PackedVector2Array, cor: PackedColorArray,
		idx: PackedInt32Array) -> void:
	# Grade de longitude e latitude, mais densa na frente e na altura do rosto.
	var nl := 100
	var na := 70
	var inicio := pos.size()
	var olho := _olho_lado(sx)
	for j in na + 1:
		var w := float(j) / float(na) * 2.0 - 1.0
		var lat := signf(w) * pow(absf(w), 1.45) * PI * 0.5
		for i in nl + 1:
			var wu := float(i) / float(nl) * 2.0 - 1.0
			var lon := signf(wu) * pow(absf(wu), 1.7) * PI
			var d := Vector3(sin(lon) * cos(lat), sin(lat), -cos(lon) * cos(lat))
			var p := _superficie(d, false, sx)
			pos.append(p)
			uv.append(Vector2(lon * 0.095 / FAIXA_PASSO, 0.1 + fposmod(lat * 0.095 / 0.03, 1.0) * 0.3))
			uv2.append(Vector2(1.0, 0.0))
			# Carne: a lente do olho aberto e o rasgo da boca.
			var e := Vector2(p.x - olho.x, p.y - olho.y).length()
			var frente := _suave(-0.04, -0.07, p.z)
			var carne := _suave(0.034, 0.024, e)
			var bx := p.x / (BOCA_MEIA * 1.15)
			var by := (p.y - BOCA_Y) / 0.020
			carne = maxf(carne, _suave(1.0, 0.7, bx * bx * bx * bx + by * by))
			carne *= frente
			var bf := (p.y - BOCA_Y) / 0.0075
			var fundo := _suave(1.0, 0.45, (p.x / BOCA_MEIA) * (p.x / BOCA_MEIA) + bf * bf) * frente
			var ao := 0.5
			if frente > 0.0 and carne > 0.0:
				ao = _oclusao(d, faixas, -1) * lerpf(0.75, 1.0, _suave(0.012, 0.03, e))
			cor.append(Color(carne, _peso_queixo(p), ao, fundo))
	for j in na:
		for i in nl:
			var a := inicio + j * (nl + 1) + i
			var b := a + 1
			var c := a + nl + 1
			var d2 := c + 1
			idx.append_array([a, b, c, b, d2, c])


static func _montar_faixa(f: Dictionary, faixas: Array, sx: float, pos: PackedVector3Array,
		uv: PackedVector2Array, uv2: PackedVector2Array, cor: PackedColorArray,
		idx: PackedInt32Array, pontas: Array) -> void:
	var s0: float = f["s0"]
	var s1: float = f["s1"]
	var camada: int = f["camada"]
	var linha: int = f["linha"]
	var base_off := SOBRE_CRANIO + float(camada) * POR_CAMADA
	# As longitudes: passo curto na frente, longo atras.
	var ss: PackedFloat32Array = [s0]
	var s := s0
	while s < s1:
		var d := _dir(f, s, _lat(f, s))
		var passo := PASSO_FRENTE if d.z < -0.02 else PASSO_ATRAS
		s = minf(s + passo / 0.095, s1)
		ss.append(s)
	var fechada := s1 - s0 >= TAU - 0.001
	var inicio := pos.size()
	var n_t := _ATRAVESSA.size()
	var comprimento := 0.0
	var anterior := Vector3.ZERO
	for i in ss.size():
		s = ss[i]
		var lat := _lat(f, s)
		var centro := _dir(f, s, lat)
		var r := _superficie(centro, true, sx).length()
		var meia := FAIXA_LARGURA * 0.5 / r
		var pc := _superficie(centro, true, sx)
		if i > 0:
			comprimento += pc.distance_to(anterior)
		anterior = pc
		for t: float in _ATRAVESSA:
			var d := _dir(f, s, lat + t * meia)
			var p := _superficie(d, true, sx)
			# Rugas atravessando: a gaze esticada franze em diagonal.
			var ruga := 0.00045 * sin(comprimento / 0.013 + t * 1.3 + float(f["ruga"])) \
				* (1.0 - t * t) + 0.0003 * sin(comprimento / 0.0051 + t * 2.1)
			var off := maxf(base_off + _perfil(t) * ESPESSURA + ruga, 0.0006)
			p += d * off
			pos.append(p)
			uv.append(Vector2(comprimento / FAIXA_PASSO + float(f["u0"]),
				float(linha) * 0.5 + 0.004 + (t + 1.0) * 0.5 * 0.492))
			uv2.append(Vector2(0.0, 0.0))
			var ao := _oclusao(d, faixas, camada)
			if absf(t) > BORDA_SOLIDA:
				ao *= 0.8
			cor.append(Color(0.0, _peso_queixo(p), ao, 0.0))
	var n_s := ss.size()
	for i in n_s - 1:
		for k in n_t - 1:
			var a := inicio + i * n_t + k
			var b := a + 1
			var c := a + n_t
			var d2 := c + 1
			idx.append_array([a, b, c, b, d2, c])
	if fechada:
		# A volta inteira: costura o fim no comeco (a posicao bate, o u nao, e
		# a emenda fica na nuca).
		pass
	if bool(f.get("ponta", false)):
		var ponta_em: int = f.get("ponta_em", 1)
		var sp := s1 if ponta_em == 1 else s0
		var lat := _lat(f, sp)
		var dc := _dir(f, sp, lat)
		var ds := 0.01 * (1.0 if ponta_em == 1 else -1.0)
		var dn := _dir(f, sp + ds, _lat(f, sp + ds))
		var p0 := _superficie(dc, true, sx) + dc * (base_off + ESPESSURA)
		var p1 := _superficie(dn, true, sx) + dn * (base_off + ESPESSURA)
		var lado := (_dir(f, sp, lat + 0.1) - _dir(f, sp, lat - 0.1)).normalized()
		# A ponta descola e pende: sai um pouco ao longo da faixa, mais para
		# baixo e para fora. Ao longo so, ela atravessava a boca.
		var sai := ((p1 - p0).normalized() * 0.45 + Vector3.DOWN + dc * 0.35).normalized()
		pontas.append({"pos": p0, "tangente": sai, "lado": lado,
			"u": comprimento / FAIXA_PASSO + float(f["u0"]) if ponta_em == 1 else float(f["u0"]),
			"linha": linha})


# --- dentes ------------------------------------------------------------------------------

static func _malha_dos_dentes(sx: float, rng: RandomNumberGenerator) -> Array:
	var cima := SurfaceTool.new()
	cima.begin(Mesh.PRIMITIVE_TRIANGLES)
	var baixo := SurfaceTool.new()
	baixo.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fila in 2:
		var st := cima if fila == 0 else baixo
		var x := -BOCA_MEIA * 0.93 + rng.randf_range(0.0, 0.002)
		while x < BOCA_MEIA * 0.93:
			var larg := rng.randf_range(0.0048, 0.0068)
			var falta := rng.randf() < 0.09
			if not falta:
				var curva := 0.0055 * pow(x / BOCA_MEIA, 2.0)
				var y_raiz := BOCA_Y + curva + (0.0125 if fila == 0 else -0.0125)
				var d := Vector3(x, y_raiz, -0.09).normalized()
				var sup := _superficie(d, true, sx)
				var dentro := sup - d * (0.0036 + (0.0012 if fila == 1 else 0.0))
				var comp := rng.randf_range(0.012, 0.0165)
				var ponta := rng.randf() < 0.4
				if rng.randf() < 0.12:
					comp *= 1.35
					ponta = true
				if rng.randf() < 0.1:
					comp *= 0.6
				var desce := Vector3.DOWN if fila == 0 else Vector3.UP
				# Torto: cada um para um lado.
				var giro := Basis(Vector3.BACK, rng.randf_range(-0.28, 0.28)) \
					* Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.25) * (1.0 if fila == 0 else -1.0))
				var frente := Vector3(d.x, 0.0, d.z).normalized()
				_dente(st, dentro, giro * desce, frente, larg, comp, ponta, rng)
			x += larg + rng.randf_range(0.0002, 0.0011)
	cima.generate_normals()
	baixo.generate_normals()
	return [cima.commit(), baixo.commit()]


## Um dente: da raiz (na gengiva) a ponta, secao oval de `larg` por 60% dela;
## afina para uma ponta ou fica rombudo. Cor: marrom na raiz, amarelo no meio.
static func _dente(st: SurfaceTool, raiz: Vector3, eixo: Vector3, frente: Vector3, larg: float,
		comp: float, ponta: bool, rng: RandomNumberGenerator) -> void:
	var lado := eixo.cross(frente).normalized()
	var fr := lado.cross(eixo).normalized()
	var aneis := [[0.0, 1.0], [0.35, 1.08], [0.7, 0.92], [0.9, 0.55 if ponta else 0.8],
		[1.0, 0.08 if ponta else 0.45]]
	var lados := 8
	var tom := rng.randf_range(0.8, 1.05)
	var sujo := rng.randf() < 0.2
	var pontos: Array = []
	var cores: Array = []
	for a: Array in aneis:
		var h: float = a[0]
		var w: float = a[1]
		var anel: Array[Vector3] = []
		for k in lados:
			var ang := float(k) / float(lados) * TAU
			anel.append(raiz + eixo * (h * comp) + lado * cos(ang) * larg * 0.5 * w
				+ fr * sin(ang) * larg * 0.32 * w)
		pontos.append(anel)
		var c := Color(0.36, 0.22, 0.12).lerp(Color(0.84, 0.77, 0.58), _suave(0.0, 0.45, h))
		c = c.lerp(Color(0.86, 0.80, 0.66), _suave(0.6, 1.0, h))
		if sujo:
			c = c.lerp(Color(0.45, 0.33, 0.18), 0.55)
		cores.append(c * tom)
	for i in pontos.size() - 1:
		var a0: Array[Vector3] = pontos[i]
		var a1: Array[Vector3] = pontos[i + 1]
		for k in lados:
			var k1 := (k + 1) % lados
			for v: Array in [[a0[k], cores[i]], [a1[k], cores[i + 1]], [a1[k1], cores[i + 1]],
					[a0[k], cores[i]], [a1[k1], cores[i + 1]], [a0[k1], cores[i]]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	var fim: Array[Vector3] = pontos[pontos.size() - 1]
	var tip := raiz + eixo * comp * (1.03 if ponta else 1.0)
	for k in lados:
		st.set_color(cores[cores.size() - 1])
		st.add_vertex(fim[k])
		st.add_vertex(tip)
		st.add_vertex(fim[(k + 1) % lados])


# --- pontas soltas ------------------------------------------------------------------------

func _montar_pontas(defs: Array, rng: RandomNumberGenerator) -> void:
	if defs.is_empty():
		return
	var n := PONTA_PONTOS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sub := 3
	for k in defs.size():
		var def: Dictionary = defs[k]
		var u0: float = def["u"]
		var linha: int = def["linha"]
		var linhas := (n - 1) * sub
		for i in linhas + 1:
			var fi := float(i) / float(sub)
			for lado: float in [-1.0, 1.0]:
				st.set_uv(Vector2(u0 + fi * PONTA_SEGMENTO / FAIXA_PASSO,
					float(linha) * 0.5 + 0.004 + (lado + 1.0) * 0.5 * 0.492))
				st.set_uv2(Vector2(float(k * n) + fi, lado))
				st.add_vertex(Vector3.ZERO)
		for i in linhas:
			var a := i * 2
			st.add_index(k * (linhas + 1) * 2 + a)
			st.add_index(k * (linhas + 1) * 2 + a + 2)
			st.add_index(k * (linhas + 1) * 2 + a + 1)
			st.add_index(k * (linhas + 1) * 2 + a + 1)
			st.add_index(k * (linhas + 1) * 2 + a + 2)
			st.add_index(k * (linhas + 1) * 2 + a + 3)
		# Na cabeca: a ancora e o primeiro passo ao longo da faixa.
		_ancoras.append({"a": def["pos"], "b": (def["pos"] as Vector3)
			+ (def["tangente"] as Vector3) * PONTA_SEGMENTO * 0.6, "lado": def["lado"]})
	_fitas = MeshInstance3D.new()
	_fitas.name = "PontasSoltas"
	_fitas.mesh = st.commit()
	_fitas.top_level = true
	_mat_fitas = ShaderMaterial.new()
	_mat_fitas.shader = _shader_da_ponta()
	_mat_fitas.set_shader_parameter(&"gaze_alb", load(PASTA + "faixa_albedo.png"))
	_mat_fitas.set_shader_parameter(&"gaze_nrm", load(PASTA + "faixa_normal.png"))
	_mat_fitas.set_shader_parameter(&"gaze_rug", load(PASTA + "faixa_rugosidade.png"))
	_mat_fitas.set_shader_parameter(&"por_fita", n)
	_mat_fitas.set_shader_parameter(&"largura", PONTA_LARGURA)
	_mat_fitas.set_shader_parameter(&"sangue", Vector4(rng.randf_range(0.05, 0.35),
		rng.randf_range(0.0, 0.8), 0.0, 0.0))
	_fitas.material_override = _mat_fitas
	add_child(_fitas)
	_fitas.global_transform = Transform3D.IDENTITY
	_pos.resize(defs.size() * n)
	_ant.resize(defs.size() * n)
	_lados.resize(defs.size() * n)
	_assentar()


## Poe as fitas em repouso: pendendo da ancora, e simula um segundo parado. A
## fita que nasce reta e cai no primeiro quadro chicoteia sem motivo.
func _assentar() -> void:
	if not is_inside_tree():
		return
	var xf := global_transform
	var n := PONTA_PONTOS
	for k in _ancoras.size():
		var an: Dictionary = _ancoras[k]
		var a := xf * (an["a"] as Vector3)
		var b := xf * (an["b"] as Vector3)
		for i in n:
			var p := a if i == 0 else (b + Vector3.DOWN * PONTA_SEGMENTO * float(i - 1))
			_pos[k * n + i] = p
			_ant[k * n + i] = p
	for _i in 90:
		_simular(PASSO_FISICA, xf)
	_desenhar_fitas(xf)


func _ready() -> void:
	if not _ancoras.is_empty():
		_assentar()


func _process(delta: float) -> void:
	_t += delta
	if not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var xf := global_transform
	var dist := cam.global_position.distance_to(xf.origin)
	_seguir_com_o_olho(cam, xf, dist)
	if _ancoras.is_empty() or dist > SIMULA_ATE:
		return
	_acumulado = minf(_acumulado + delta, PASSO_FISICA * 4.0)
	while _acumulado >= PASSO_FISICA:
		_acumulado -= PASSO_FISICA
		_simular(PASSO_FISICA, xf)
	_desenhar_fitas(xf)


## O olho segue a lente, ate onde a orbita deixa.
func _seguir_com_o_olho(cam: Camera3D, xf: Transform3D, dist: float) -> void:
	if _globo == null or dist > OLHO_SEGUE_ATE:
		return
	var alvo := (xf.affine_inverse() * cam.global_position) - _olho_centro
	var frente := _olho_repouso * Vector3.FORWARD
	var para := alvo.normalized()
	var ang := frente.angle_to(para)
	if ang > OLHO_SEGUE:
		para = frente.slerp(para, OLHO_SEGUE / ang)
	var alvo_basis := Basis.looking_at(para, Vector3.UP)
	_globo.basis = _globo.basis.orthonormalized().slerp(alvo_basis, 0.35)


func _simular(dt: float, xf: Transform3D) -> void:
	var n := PONTA_PONTOS
	var inv := xf.affine_inverse()
	var amortece := pow(PONTA_AMORTECE, dt * 60.0)
	var vento := Vector3(sin(_t * 1.7 + float(_semente)) + 0.5 * sin(_t * 4.3),
		0.0, cos(_t * 1.3 + float(_semente) * 0.7)) * PONTA_VENTO
	var peito := Transform3D.IDENTITY
	var tem_peito := false
	if _corpo != null:
		var esq := _corpo.esqueleto()
		if esq != null:
			peito = esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.TORSO)
			tem_peito = true
	var peito_inv := peito.affine_inverse()
	for k in _ancoras.size():
		var an: Dictionary = _ancoras[k]
		var o := k * n
		_pos[o] = xf * (an["a"] as Vector3)
		_pos[o + 1] = xf * (an["b"] as Vector3)
		_ant[o] = _pos[o]
		_ant[o + 1] = _pos[o + 1]
		for i in range(2, n):
			var p := _pos[o + i]
			var v := (p - _ant[o + i]) * amortece
			_ant[o + i] = p
			var livre := float(i) / float(n - 1)
			_pos[o + i] = p + v + (GRAVIDADE + vento * livre) * dt * dt
		for it in 2:
			for i in range(2, n):
				var a := _pos[o + i - 1]
				var b := _pos[o + i]
				var dd := b - a
				var l := dd.length()
				if l > 0.00001:
					_pos[o + i] = a + dd * (PONTA_SEGMENTO / l)
				# Nao dobra em cima de si: distancia minima ao ponto dois atras
				# (ver memoria fio-duro-faz-laco).
				var c := _pos[o + i - 2]
				var dc := _pos[o + i] - c
				var lc := dc.length()
				if lc < PONTA_SEGMENTO * 1.2 and lc > 0.00001:
					_pos[o + i] = c + dc * (PONTA_SEGMENTO * 1.2 / lc)
				if it == 0:
					continue
				# Colisao (so na ultima volta): a cabeca e o peito.
				var q := inv * _pos[o + i]
				var eq := Vector3(q.x / CABECA_COLIDE.x, q.y / CABECA_COLIDE.y,
					q.z / CABECA_COLIDE.z)
				var el0 := eq.length()
				if el0 < 1.0 and el0 > 0.00001:
					_pos[o + i] = xf * (q / el0)
				if tem_peito:
					var pp := peito_inv * _pos[o + i] - _peito_centro
					var e := Vector3(pp.x / _peito_raio.x, pp.y / _peito_raio.y, pp.z / _peito_raio.z)
					var el := e.length()
					if el < 1.0 and el > 0.00001:
						_pos[o + i] = peito * (_peito_centro + pp / el)


func _desenhar_fitas(xf: Transform3D) -> void:
	var n := PONTA_PONTOS
	for k in _ancoras.size():
		var an: Dictionary = _ancoras[k]
		var lado := (xf.basis * (an["lado"] as Vector3)).normalized()
		for i in n:
			var o := k * n + i
			var tan: Vector3
			if i < n - 1:
				tan = (_pos[o + 1] - _pos[o]).normalized()
			else:
				tan = (_pos[o] - _pos[o - 1]).normalized()
			# Transporte paralelo: o lado segue perpendicular a fita.
			lado = (lado - tan * lado.dot(tan)).normalized()
			_lados[o] = lado
	# O uniforme e de 32: o que sobra vai zerado.
	var pts := _pos.duplicate()
	var lds := _lados.duplicate()
	pts.resize(32)
	lds.resize(32)
	_mat_fitas.set_shader_parameter(&"pontos", pts)
	_mat_fitas.set_shader_parameter(&"lados", lds)
	var caixa := AABB(_pos[0], Vector3.ZERO)
	for p in _pos:
		caixa = caixa.expand(p)
	_fitas.custom_aabb = caixa.grow(PONTA_LARGURA)


# --- materiais e malhas compartilhados ---------------------------------------------------

static func _material_faixa() -> ShaderMaterial:
	if _mat_faixa == null:
		var sh := Shader.new()
		sh.code = FAIXA_SHADER
		_mat_faixa = ShaderMaterial.new()
		_mat_faixa.shader = sh
		_mat_faixa.set_shader_parameter(&"gaze_alb", load(PASTA + "faixa_albedo.png"))
		_mat_faixa.set_shader_parameter(&"gaze_nrm", load(PASTA + "faixa_normal.png"))
		_mat_faixa.set_shader_parameter(&"gaze_rug", load(PASTA + "faixa_rugosidade.png"))
		_mat_faixa.set_shader_parameter(&"manchas", load(PASTA + "manchas.png"))
		_mat_faixa.set_shader_parameter(&"carne_alb", load(PASTA + "carne_albedo.png"))
		_mat_faixa.set_shader_parameter(&"carne_nrm", load(PASTA + "carne_normal.png"))
		_mat_faixa.set_shader_parameter(&"altura_mancha", MANCHA_ALTURA)
		_mat_faixa.set_shader_parameter(&"dobradica", DOBRADICA)
	return _mat_faixa


static func _material_olho() -> ShaderMaterial:
	if _mat_olho == null:
		var sh := Shader.new()
		sh.code = OLHO_SHADER
		_mat_olho = ShaderMaterial.new()
		_mat_olho.shader = sh
		_mat_olho.set_shader_parameter(&"olho_tex", load(PASTA + "olho_albedo.png"))
	return _mat_olho


static func _material_dente() -> StandardMaterial3D:
	if _mat_dente == null:
		_mat_dente = StandardMaterial3D.new()
		_mat_dente.vertex_color_use_as_albedo = true
		_mat_dente.vertex_color_is_srgb = true
		_mat_dente.roughness = 0.32
		_mat_dente.metallic_specular = 0.55
		# A fila de baixo nasce de ponta para cima e o anel sai do avesso.
		_mat_dente.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat_dente


static func _material_brilho() -> ShaderMaterial:
	if _mat_brilho == null:
		_shader_brilho = Shader.new()
		_shader_brilho.code = BRILHO_SHADER
		_mat_brilho = ShaderMaterial.new()
		_mat_brilho.shader = _shader_brilho
		_mat_brilho.set_shader_parameter(&"perto", BRILHO_PERTO)
		_mat_brilho.set_shader_parameter(&"longe", BRILHO_LONGE)
	return _mat_brilho


static func _shader_da_ponta() -> Shader:
	if _shader_ponta == null:
		_shader_ponta = Shader.new()
		_shader_ponta.code = PONTA_SHADER
	return _shader_ponta


static func _malha_do_olho() -> SphereMesh:
	if _malha_olho == null:
		_malha_olho = SphereMesh.new()
		_malha_olho.radius = OLHO_RAIO
		_malha_olho.height = OLHO_RAIO * 2.0
		_malha_olho.radial_segments = 40
		_malha_olho.rings = 24
	return _malha_olho


static func _malha_do_brilho() -> QuadMesh:
	if _malha_brilho == null:
		_malha_brilho = QuadMesh.new()
		_malha_brilho.size = Vector2(BRILHO_QUAD, BRILHO_QUAD)
	return _malha_brilho

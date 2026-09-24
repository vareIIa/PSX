## Os materiais do interior do carro: plastico granulado, metal acetinado,
## tinta impressa retroiluminada, lente de mostrador, visor do toca-fitas e
## tecido.
##
## Por que materiais proprios, e nao o mat_painel
## ----------------------------------------------
## O mat_painel e o `psx_surface` com o painel_atlas: luz por vertice, sem
## brilho, e a textura da peca pintada numa celula. Serve para a casca, que e
## parede. Para o que a mao toca — o painel, o botao, o pomo do cambio — o que
## diz o que a peca e e o BRILHO: o granulado do plastico injetado, o verniz do
## pomo, o metal do aro do mostrador. Mesmo caminho do `VolanteEsportivo`.
##
## A cor mora no VERTICE, em sRGB (o shader converte): a mesma malha pinta o
## painel de cima escuro e o de baixo mais claro sem trocar de material. O alfa
## do vertice diz o acabamento — ver cada shader.
##
## Cada cabine ganha as SUAS instancias (so o Shader e compartilhado), porque o
## painel de uma acende quando o farol liga e o da outra nao.
class_name CabineMateriais
extends RefCounted

## A luz de preenchimento que o painel inteiro tem (ver `mat_painel`: emissao
## 0,54/0,46/0,40 a 0,34). Sem ela o interior novo sai mais escuro que a casca
## em volta dele, e a emenda entre os dois aparece.
const PREENCHE := Vector3(0.18, 0.16, 0.14)
## A cor da retroiluminacao dos mostradores. Ambar: e a do Marea e a do Uno, e
## e a luz que deixa a cabine a noite com cara de sala acesa.
const LUZ_PAINEL := Color(1.0, 0.44, 0.09)

const _FUNCOES := """
float h13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x),
			mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x),
			mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Distancia ao ponto mais proximo de uma nuvem de pontos (Worley F1): o
// granulado em "pedrinha" do plastico de painel e do couro.
float celula(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	float d = 8.0;
	for (int a = -1; a <= 1; a++)
	for (int b = -1; b <= 1; b++)
	for (int c = -1; c <= 1; c++) {
		vec3 g = vec3(float(a), float(b), float(c));
		vec3 o = vec3(h13(i + g), h13(i + g + 17.1), h13(i + g + 41.7));
		vec3 r = g + o - f;
		d = min(d, dot(r, r));
	}
	return sqrt(d);
}

vec3 linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// Relevo por derivada de tela: nao precisa de tangente, e a malha da cabine nao
// tem (ver a memoria "mapa de normal comprimido so tem dois canais").
vec3 relevo(vec3 vertex, vec3 normal, float alt) {
	vec3 dpdx = dFdx(vertex);
	vec3 dpdy = dFdy(vertex);
	vec3 r1 = cross(dpdy, normal);
	vec3 r2 = cross(normal, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(alt) * r1 + dFdy(alt) * r2);
	return normalize(abs(det) * normal - grad);
}
"""

## Plastico de painel. Alfa do vertice: 1 e o granulado fosco de painel, 0 e o
## liso de verniz (pomo, tecla, lente de lanterna). Entre os dois, o acetinado.
const PLASTICO := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 preenche = vec3(0.18, 0.16, 0.14);
// Tamanho do grao, em celulas por metro: 1100 da pedrinhas de ~0,9 mm.
uniform float grao = 1100.0;
// Quanto do po assenta no que olha para cima.
uniform float poeira = 1.0;

varying vec3 p_obj;
varying vec3 n_mundo;

%s

void vertex() {
	p_obj = VERTEX;
	n_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = linear(COLOR.rgb);
	float fosco = COLOR.a;
	float px = length(fwidth(p_obj));
	float fino = clamp(1.0 - px * grao * 0.55, 0.0, 1.0);
	float w = celula(p_obj * grao);
	float pedra = 1.0 - smoothstep(0.15, 0.95, w);
	float alt = pedra * fino * fosco;
	// Variacao larga, de peca injetada que desbotou no sol de um lado.
	float largo = ruido(p_obj * 9.0);
	base *= 0.94 + 0.12 * largo;
	base *= 1.0 + (pedra - 0.5) * 0.10 * fino * fosco;
	// Po: nas faces de cima, fosco e claro, mais nas dobras (ruido baixo).
	float cima = smoothstep(0.55, 0.95, n_mundo.y);
	// A cor do po e LINEAR e baixa: num plastico de 0,01 linear, um po claro
	// de verdade (0,3) a 10% multiplicava a peca por quatro e virava mancha.
	float po = cima * smoothstep(0.45, 0.95, ruido(p_obj * 22.0 + 3.1)) * 0.30 * poeira;
	base = mix(base, base * 1.5 + vec3(0.0022, 0.0020, 0.0017), po);
	ALBEDO = base;
	ROUGHNESS = clamp(mix(0.22, 0.74, fosco) - pedra * 0.10 * fosco * fino + po * 0.3, 0.05, 1.0);
	SPECULAR = mix(0.55, 0.38, fosco);
	NORMAL = relevo(VERTEX, NORMAL, alt * 0.00018);
	EMISSION = base * preenche;
}
"""

## Metal: cromado e aluminio. Alfa do vertice e a aspereza (0 espelho, 1
## acetinado). Cromo so reflete o escuro da cabine e sai preto: a camada de
## "anodizado" espalha um pouco de luz como tinta, igual ao raio do volante.
const METAL := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 preenche = vec3(0.18, 0.16, 0.14);
varying vec3 p_obj;

%s

void vertex() {
	p_obj = VERTEX;
}

void fragment() {
	vec3 base = linear(COLOR.rgb);
	float px = length(fwidth(p_obj));
	float fino = clamp(1.0 - px * 1500.0, 0.0, 1.0);
	float risco = ruido(vec3(p_obj.x * 4000.0, p_obj.y * 60.0, p_obj.z * 4000.0));
	ALBEDO = base * (1.0 + (risco - 0.5) * 0.12 * fino);
	METALLIC = 0.72;
	ROUGHNESS = mix(0.10, 0.36, COLOR.a) + (risco - 0.5) * 0.06 * fino;
	SPECULAR = 0.5;
	EMISSION = base * preenche * 0.45;
}
"""

## Tinta impressa da folha `ImpressosCabine`. A cor do vertice e o fundo da
## peca; o alfa do vertice e quanto a tinta clara ACENDE com o painel (1 no
## mostrador, 0,35 na tecla, 0 no que nao tem luz atras). UV2.x >= 0 marca uma
## luz-espia, e o numero dela escolhe a cor e o estado.
const IMPRESSO := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D folha : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 preenche = vec3(0.18, 0.16, 0.14);
uniform vec3 luz : source_color = vec3(1.0, 0.52, 0.16);
// 0 com o farol apagado, 1 com ele aceso.
uniform float aceso = 0.0;
uniform float espias[8];

varying vec3 p_obj;

%s

const vec3 COR_ESPIA[8] = vec3[](
	vec3(0.15, 1.0, 0.25), vec3(0.15, 1.0, 0.25), vec3(0.15, 0.40, 1.0),
	vec3(1.0, 0.10, 0.06), vec3(1.0, 0.10, 0.06), vec3(1.0, 0.10, 0.06),
	vec3(1.0, 0.10, 0.06), vec3(1.0, 0.55, 0.05));

void vertex() {
	p_obj = VERTEX;
}

void fragment() {
	vec4 t = texture(folha, UV);
	vec3 fundo = linear(COLOR.rgb);
	vec3 tinta = t.rgb;
	float cob = t.a;
	float lum = max(tinta.r, max(tinta.g, tinta.b));
	float sat = lum - min(tinta.r, min(tinta.g, tinta.b));
	vec3 alb;
	vec3 em = vec3(0.0);
	if (UV2.x >= 0.0) {
		int k = clamp(int(UV2.x + 0.5), 0, 7);
		float on = espias[k];
		vec3 cor = COR_ESPIA[k];
		// Apagada, a luz-espia e o icone escuro atras do filtro colorido.
		alb = mix(fundo, mix(cor * 0.018, cor * 0.5, on), cob);
		em = cor * cob * on * 2.6;
	} else {
		// Acesa, a tinta branca e o filtro ambar com luz atras: o branco da
		// tinta some e fica a cor da lampada. Sem isso o numero saia creme.
		float brilha = aceso * COLOR.a;
		alb = mix(fundo, tinta * (1.0 - 0.75 * brilha), cob);
		// A tinta branca acende na cor do painel; a vermelha, vermelha.
		vec3 acende = mix(luz * lum, tinta, clamp(sat * 2.5, 0.0, 1.0));
		em = acende * cob * smoothstep(0.25, 0.8, lum) * brilha * 2.2;
	}
	ALBEDO = alb;
	ROUGHNESS = 0.55;
	SPECULAR = 0.4;
	EMISSION = em + alb * preenche;
}
"""

## A lente dos mostradores: vidro quase invisivel que so aparece no reflexo.
const LENTE := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	// Aspera o bastante para o reflexo virar degrade: lisa, ela espelhava a
	// borda do para-brisa como uma faixa dura atravessando os dois mostradores.
	ALBEDO = vec3(0.02, 0.022, 0.025);
	ROUGHNESS = 0.38;
	SPECULAR = 0.18;
	ALPHA = 0.02 + f * 0.12;
}
"""

## O visor do toca-fitas: sete segmentos de VFD, com os apagados aparecendo de
## leve atras do vidro fume, como nos de verdade. `segs[k]` e a mascara da
## celula k (bit 0 = a ... bit 6 = g); `pontos.x` e a celula depois da qual o
## ponto decimal acende (-1 nenhum), `pontos.y` o dois-pontos do relogio.
const VISOR := """
shader_type spatial;
render_mode cull_back, unshaded;

uniform int segs[5];
uniform vec2 pontos = vec2(-1.0, 0.0);
uniform vec3 cor : source_color = vec3(1.0, 0.55, 0.12);
uniform float brilho = 1.0;

float capsula(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float segmento(vec2 q, int s) {
	float w = 0.56;
	float g = 0.07;
	vec2 tl = vec2(0.0, 1.0), tr = vec2(w, 1.0);
	vec2 ml = vec2(0.0, 0.5), mr = vec2(w, 0.5);
	vec2 bl = vec2(0.0, 0.0), br = vec2(w, 0.0);
	vec2 a = tl, b = tr;
	if (s == 1) { a = tr; b = mr; }
	else if (s == 2) { a = mr; b = br; }
	else if (s == 3) { a = bl; b = br; }
	else if (s == 4) { a = ml; b = bl; }
	else if (s == 5) { a = tl; b = ml; }
	else if (s == 6) { a = ml; b = mr; }
	vec2 d = normalize(b - a);
	return capsula(q, a + d * g, b - d * g, 0.045);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	// Cinco celulas na faixa do meio do visor, em italico de VFD.
	float largura = 0.172;
	vec2 origem = vec2(0.075, 0.2);
	float altura = 0.6;
	float aceso_px = 0.0;
	float fantasma = 0.0;
	float aa = fwidth(uv.x) * 1.5 / largura;
	for (int k = 0; k < 5; k++) {
		vec2 q = (uv - origem - vec2(largura * float(k), 0.0)) / vec2(largura, altura);
		q.x -= q.y * 0.10;
		q.x *= 1.35;
		for (int s = 0; s < 7; s++) {
			float d = segmento(q, s);
			float m = 1.0 - smoothstep(-aa, aa, d);
			if (((segs[k] >> s) & 1) == 1) {
				aceso_px = max(aceso_px, m);
			} else {
				fantasma = max(fantasma, m);
			}
		}
		if (float(k) == pontos.x) {
			float d = length(q - vec2(0.68, 0.03)) - 0.085;
			aceso_px = max(aceso_px, 1.0 - smoothstep(-aa, aa, d));
		}
		if (k == 2 && pontos.y > 0.5) {
			for (int j = 0; j < 2; j++) {
				float d = length(q - vec2(-0.2, 0.3 + 0.4 * float(j))) - 0.06;
				aceso_px = max(aceso_px, 1.0 - smoothstep(-aa, aa, d));
			}
		}
	}
	vec3 fundo = vec3(0.012, 0.014, 0.013);
	vec3 c = fundo + cor * fantasma * 0.035 + cor * aceso_px * brilho * 1.6;
	// O brilho mole do fosforo em volta do segmento aceso.
	ALBEDO = c;
}
"""

## Tecido de banco: veludo cotele de carro dos anos 90. UV em metros; o alfa do
## vertice e a largura da listra (0 liso).
const TECIDO := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 preenche = vec3(0.18, 0.16, 0.14);
varying vec3 p_obj;

%s

void vertex() {
	p_obj = VERTEX;
}

void fragment() {
	vec3 base = linear(COLOR.rgb);
	float px = length(fwidth(p_obj));
	float fino = clamp(1.0 - px * 700.0, 0.0, 1.0);
	// Trama: dois fios cruzados de 1,2 mm, e o pelo do veludo por cima.
	vec3 q = p_obj * 820.0;
	float trama = (sin(q.x + q.y * 0.3) * sin(q.z + q.y * 0.7)) * 0.5 + 0.5;
	float pelo = ruido(p_obj * 3000.0);
	float h = (trama * 0.6 + pelo * 0.4) * fino;
	base *= 0.88 + h * 0.2 + (ruido(p_obj * 14.0) - 0.5) * 0.08;
	// A listra fina do miolo, correndo ao longo do banco (em x constante): o
	// alfa do vertice diz se a peca e miolo listrado (1) ou aba lisa (0).
	float fx = fract(p_obj.x * 46.0);
	float dl = min(fx, 1.0 - fx);
	float aa = clamp(fwidth(p_obj.x * 46.0), 0.001, 0.5);
	float listra = (1.0 - smoothstep(0.025, 0.025 + aa * 1.5, dl)) * COLOR.a;
	listra *= clamp(1.0 - aa * 3.0, 0.0, 1.0);
	base = mix(base, base * vec3(1.35, 1.28, 1.18), listra * 0.45);
	ALBEDO = base;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	// O brilho de raspao do veludo.
	RIM = 0.45;
	RIM_TINT = 0.6;
	NORMAL = relevo(VERTEX, NORMAL, h * 0.00025);
	EMISSION = base * preenche;
}
"""

## Madeira falsa envernizada: o friso que datava todo carro "luxo" dos anos 90.
## O veio corre em X (ao longo do friso), com os poros finos e o verniz por
## cima. A cor do vertice e o tom claro da madeira.
const MADEIRA := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 preenche = vec3(0.18, 0.16, 0.14);
varying vec3 p_obj;

%s

void vertex() {
	p_obj = VERTEX;
}

void fragment() {
	vec3 base = linear(COLOR.rgb);
	vec3 q = p_obj;
	float torto = ruido(q * vec3(4.0, 30.0, 30.0)) * 2.2 + ruido(q * vec3(11.0, 70.0, 70.0)) * 0.6;
	float r = length(q.yz * vec2(1.0, 0.45) * 110.0) + q.x * 6.0 + torto * 1.6;
	float anel = fract(r);
	float veio = smoothstep(0.0, 0.18, anel) * (1.0 - smoothstep(0.45, 1.0, anel));
	float px = length(fwidth(q));
	float fino = clamp(1.0 - px * 900.0, 0.0, 1.0);
	float poro = ruido(q * vec3(60.0, 2200.0, 2200.0));
	vec3 escuro = base * vec3(0.58, 0.50, 0.44);
	vec3 c = mix(escuro, base, veio * 0.55 + 0.45 * mix(0.5, poro, fino));
	c *= 0.9 + 0.2 * ruido(q * 7.0);
	ALBEDO = c;
	ROUGHNESS = 0.32;
	SPECULAR = 0.5;
	CLEARCOAT = 0.9;
	CLEARCOAT_ROUGHNESS = 0.12;
	EMISSION = c * preenche;
}
"""

static var _shaders: Dictionary = {}
static var _folha: Texture2D


static func _shader(nome: StringName, codigo: String) -> Shader:
	if _shaders.has(nome):
		return _shaders[nome]
	var sh := Shader.new()
	sh.code = codigo.replace("%s", _FUNCOES) if codigo.contains("%s") else codigo
	_shaders[nome] = sh
	return sh


static func _material(nome: StringName, codigo: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(nome, codigo)
	if codigo.contains("preenche"):
		m.set_shader_parameter(&"preenche", PREENCHE)
	return m


static func plastico() -> ShaderMaterial:
	return _material(&"plastico", PLASTICO)


static func metal() -> ShaderMaterial:
	return _material(&"metal", METAL)


static func impresso() -> ShaderMaterial:
	var m := _material(&"impresso", IMPRESSO)
	if _folha == null and ResourceLoader.exists(ImpressosCabine.FOLHA):
		_folha = load(ImpressosCabine.FOLHA) as Texture2D
	m.set_shader_parameter(&"folha", _folha)
	m.set_shader_parameter(&"luz", LUZ_PAINEL)
	var zero := PackedFloat32Array()
	zero.resize(8)
	m.set_shader_parameter(&"espias", zero)
	return m


static func lente() -> ShaderMaterial:
	return _material(&"lente", LENTE)


static func visor() -> ShaderMaterial:
	var m := _material(&"visor", VISOR)
	m.set_shader_parameter(&"segs", PackedInt32Array([0, 0, 0, 0, 0]))
	return m


static func madeira() -> ShaderMaterial:
	return _material(&"madeira", MADEIRA)


static func tecido() -> ShaderMaterial:
	return _material(&"tecido", TECIDO)

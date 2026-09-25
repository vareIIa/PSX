## As maos e os bracos do padre: finos, compridos, podres.
##
## Por que existe
## --------------
## As maos do padre na janela e na agarrada eram as do jogador (`BracoVivo`):
## gordas, lisas, cor de pessego, com a unha rosada bem feita. Massinha. A
## referencia (`INTRO-PADRE/referencia/padre_principal_*`) e uma coisa magra e
## morta: dedo comprido e ossudo, a pele branca-acinzentada craquelada da
## cabeca, veia roxa, unha comprida e escura com terra embaixo.
##
## O que ha aqui
## -------------
## - `FORMA`: os multiplicadores que a `MaoModelada` usa enquanto monta estas
##   maos (so estas: as do jogador continuam as mesmas). Dedo 28% mais
##   comprido, tudo mais fino, a unha em garra.
## - O material: a mesma pele 4K da cabeca (`CabecaDoPadre.MAPA`), presa na
##   malha pela coordenada de pele do tubo (volta x comprimento, sem costura e
##   sem nadar quando o braco se refaz a cada quadro), e a manga no pano 4K das
##   batinas (`PanoGPU.MAPA`), molhada e rasgada.
class_name MaosPodres
extends RefCounted

## magro: raio de dedo, palma e braco. longo: comprimento das falanges.
## garra: comprimento da unha. palma: largura da palma. osso: a falange no meio
## (o no fica, a carne some). nos: o calombo do no. n_palma: a secao da palma
## (2 e elipse; a de gente, 2,3, lia como bloco ao lado do dedo fino).
const FORMA := {"magro": 0.70, "longo": 1.30, "garra": 2.3, "palma": 0.74,
	"osso": 0.78, "nos": 2.5, "n_palma": 2.0}

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec2 uv_pele = vec2(0.0);
uniform sampler2D pele_mapa : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pele_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pano_mapa : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pano_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Metros por repeticao: a pele como na cabeca, o pano como nas batinas.
uniform float tile_pele = 0.15;
uniform float tile_pano = 0.40;
uniform vec3 pele : source_color = vec3(0.70, 0.69, 0.66);
uniform vec3 mancha_quente : source_color = vec3(0.60, 0.48, 0.44);
uniform vec3 mancha_fria : source_color = vec3(0.52, 0.56, 0.58);
uniform vec3 veia : source_color = vec3(0.30, 0.28, 0.42);
uniform vec3 racha : source_color = vec3(0.16, 0.08, 0.07);
uniform vec3 necrose : source_color = vec3(0.14, 0.11, 0.10);
uniform vec3 unha_cor : source_color = vec3(0.22, 0.17, 0.10);
uniform vec3 terra : source_color = vec3(0.05, 0.035, 0.025);
uniform vec3 pano_cor : source_color = vec3(0.075, 0.066, 0.058);
uniform float relevo = 1.5;

// A pele presa na malha (ver `MaoModelada._tubo`): volta em UV2.x, metros ao
// longo em UV2.y, raio local no alfa da cor.
varying float volta;
varying float ao_longo;
varying float dorso;
varying float raio;
varying float unha;
varying vec2 unha_st;

void vertex() {
	float phi = UV2.x * TAU;
	raio = COLOR.a * 0.07;
	volta = UV2.x;
	ao_longo = UV2.y;
	dorso = sin(phi);
	unha = step(1.5, UV2.x);
	unha_st = vec2(UV2.x - 2.0, UV2.y);
}

vec3 normal_de(sampler2D t, vec2 uv, float k) {
	vec2 xy = (texture(t, uv).xy * 2.0 - 1.0) * k;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}

void fragment() {
	bool e_pele = distance(UV, uv_pele) < 0.004;
	// Coordenada de superficie em metros: a volta do tubo pelo raio, e o
	// comprimento. Sem costura na volta (a textura e tileavel e a volta cabe
	// num numero inteiro de tiles so por acaso: a costura cai no lado de
	// dentro do dedo, que a camera nao ve).
	vec2 sm = vec2(volta * TAU * max(raio, 0.004), ao_longo);
	// Tangente para o mapa de normal: pela derivada de tela da coordenada.
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec2 dux = dFdx(sm);
	vec2 duy = dFdy(sm);
	vec3 t = normalize(dpx * duy.y - dpy * dux.y + 1e-7);
	vec3 b = normalize(cross(NORMAL, t));
	t = cross(b, NORMAL);
	float det = dux.x * duy.y - dux.y * duy.x;
	b *= sign(det);
	if (unha > 0.5) {
		// Unha de garra: grossa, amarelo-marrom, rachada ao comprido e com
		// terra na borda livre e no sulco.
		float s = unha_st.x;
		float u = unha_st.y;
		vec4 m = texture(pele_mapa, vec2(s * 0.02, u * 0.06) / tile_pele * 3.0);
		vec3 c = unha_cor * (0.7 + 0.5 * m.b);
		float estria = texture(pele_mapa, vec2(s * 0.004, u * 0.05) / tile_pele).a;
		c *= 0.8 + 0.4 * estria;
		float livre = smoothstep(0.55, 0.95, u);
		c = mix(c, terra, livre * 0.8);
		float canto = smoothstep(0.7, 1.0, abs(s - 0.5) * 2.0) + (1.0 - smoothstep(0.0, 0.2, u));
		c = mix(c, terra, clamp(canto, 0.0, 1.0) * 0.7);
		ALBEDO = c;
		ROUGHNESS = mix(0.35, 0.8, livre);
		SPECULAR = 0.4;
	} else if (e_pele) {
		vec2 uv = sm / tile_pele;
		vec4 m = texture(pele_mapa, uv);
		vec3 tn = normal_de(pele_n, uv, relevo);
		NORMAL = normalize(t * tn.x + b * tn.y + NORMAL * tn.z);
		float sulco = smoothstep(0.50, 0.22, m.r);
		vec3 c = pele;
		c = mix(c, mancha_quente, smoothstep(0.50, 0.85, m.b) * 0.55);
		c = mix(c, mancha_fria, smoothstep(0.45, 0.15, m.b) * 0.5);
		// A veia morta corre no dorso da mao e do antebraco, onde o tubo e grosso.
		float grosso = smoothstep(0.010, 0.022, raio);
		c = mix(c, veia, m.g * grosso * smoothstep(-0.3, 0.6, dorso) * (1.0 - sulco) * 0.9);
		// No dedo fino a carne ja morreu: a ponta escurece, os nos avermelham
		// e a terra entra na ruga.
		float dedo = 1.0 - smoothstep(0.007, 0.012, raio);
		c = mix(c, necrose, dedo * smoothstep(0.35, 0.9, m.b + 0.25) * 0.55);
		c = mix(c, racha, sulco * (0.75 + 0.2 * dedo));
		// O lado de dentro (palma) e mais sujo: arrastou no barro.
		c = mix(c, terra * 3.0, smoothstep(0.0, -0.8, dorso) * 0.35);
		ALBEDO = c;
		ROUGHNESS = clamp(0.52 + sulco * 0.3 + (m.a - 0.5) * 0.2, 0.35, 0.9);
		SPECULAR = 0.42;
		// Pele morta: quase nada de sangue por baixo.
		SSS_STRENGTH = 0.12;
		AO = 1.0 - sulco * 0.5;
	} else {
		// A manga: la de batina encharcada, a mesma das batinas.
		vec2 uv = sm / tile_pano;
		vec4 m = texture(pano_mapa, uv);
		vec3 tn = normal_de(pano_n, uv, 1.0);
		NORMAL = normalize(t * tn.x + b * tn.y + NORMAL * tn.z);
		vec3 c = pano_cor * (0.62 + 0.62 * m.g) * (0.45 + 0.75 * m.r);
		c = mix(c, pano_cor * 1.25, m.b * 0.45) * 0.6;
		ALBEDO = c;
		ROUGHNESS = mix(0.9, 0.6, m.r);
		SPECULAR = 0.35;
		AO = 0.55 + 0.45 * m.r;
	}
}
"""

static var _material: ShaderMaterial


## Poe a forma e o material podres num `BracoVivo` (o do padre).
static func vestir(b: BracoVivo) -> void:
	if OS.get_cmdline_user_args().has("--maos-de-gente"):
		return
	b.forma = FORMA
	b.material_override = material()


static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	var sh := Shader.new()
	sh.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = sh
	var base := BracoVivo.material()
	_material.set_shader_parameter(&"atlas", base.get_shader_parameter(&"atlas"))
	_material.set_shader_parameter(&"uv_pele", base.get_shader_parameter(&"uv_pele"))
	_material.set_shader_parameter(&"pele_mapa", load(CabecaDoPadre.MAPA))
	_material.set_shader_parameter(&"pele_n", load(CabecaDoPadre.MAPA_N))
	_material.set_shader_parameter(&"pano_mapa", load(PanoGPU.MAPA))
	_material.set_shader_parameter(&"pano_n", load(PanoGPU.MAPA_N))
	return _material

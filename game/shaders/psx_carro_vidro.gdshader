// Vidro de carro visto de FORA, no MODERNO (PLANO_CARROS_AAA, F1).
//
// Era uma placa opaca da cor `VIDRO` colada sobre a lataria, e nenhum motorista
// aparecia de fora — nem NPC, nem o amigo da abertura co-op. Agora o casco tem
// vao atras do vidro e este shader deixa ver o que ha dentro.
//
// De frente o vidro de carro e bem transparente; de esguelha ele vira espelho
// (Fresnel), e e isso que faz um vidro ler como vidro e nao como buraco. A cor
// de vertice (`VIDRO` / `VIDRO_FRENTE` dos modulos) vira o tom do filme: o vidro
// lateral, mais escuro na tabela, sai mais fechado que o para-brisa.
//
// Uma face so, virada para fora (cull_back): de dentro da cabine do jogador o
// vidro que vale e o `psx_vidro_agua`, com a agua escorrendo.
//
// O PS1 STYLE nao passa por aqui: la o mat_carro_vidro continua no psx_surface,
// opaco como sempre foi.

shader_type spatial;
render_mode blend_mix, diffuse_burley, specular_schlick_ggx, cull_back, depth_draw_opaque;

#include "res://shaders/psx_chuva.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);
uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;
uniform bool use_affine = true;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.0;
uniform float vento_forca : hint_range(0.0, 1.0) = 0.0;
uniform float vento_velocidade : hint_range(0.0, 6.0) = 1.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform float rugosidade : hint_range(0.0, 1.0) = 0.88;
uniform float brilho : hint_range(0.0, 1.0) = 0.12;
uniform float molha : hint_range(0.0, 1.0) = 1.0;
uniform float rugosidade_molhada : hint_range(0.0, 1.0) = 0.12;
uniform float gotas : hint_range(0.0, 1.0) = 0.0;
uniform float roupa : hint_range(0.0, 1.0) = 0.0;
instance uniform float abrigo : hint_range(0.0, 1.0) = 0.0;
// A trinca (PLANO_CARROS_AAA, F8): xyz e o ponto da pancada no espaco do carro,
// w a forca de 0 a 1. Escrita pelo `Carro._trincar`; zero e vidro inteiro.
instance uniform vec4 trinca = vec4(0.0);

global uniform float psx_molhado;
global uniform float psx_chuva;

// Opacidade de frente, nos dois extremos do tom da tabela. O para-brisa
// (VIDRO_FRENTE, mais claro) deixa passar mais; o lateral fecha um pouco.
const float ALFA_CLARO = 0.30;
const float ALFA_ESCURO = 0.46;
// Quanto do tom de vertice vira cor do filme. Vidro nao tem cor propria forte:
// quem aparece nele e o reflexo e o que esta atras.
const float TOM = 0.45;

varying vec3 pos_local;
varying vec3 normal_local;


void vertex() {
	pos_local = VERTEX;
	normal_local = NORMAL;
}


void fragment() {
	vec3 tom = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	float escuro = 1.0 - smoothstep(0.18, 0.30, dot(COLOR.rgb, vec3(0.333)));
	float alfa = mix(ALFA_CLARO, ALFA_ESCURO, escuro);

	float rug = 0.035;
	float cobertura = gotas * (1.0 - abrigo)
		* clamp(max(psx_chuva * 3.0, psx_molhado * 1.15), 0.0, 1.0);
	if (cobertura > 0.01) {
		vec4 g = gotas_na_chapa(pos_local, normal_local, cobertura);
		if (g.w > 0.0) {
			vec3 desvio = (VIEW_MATRIX * (MODEL_MATRIX * vec4(g.xyz, 0.0))).xyz;
			NORMAL = normalize(NORMAL + desvio * g.w * 2.0);
			// A gota junta luz e fica mais visivel que o vidro em volta.
			alfa = mix(alfa, 0.75, g.w * 0.6);
		}
	}

	// Vidro trincado: raios saindo do ponto da pancada, aneis em volta dele e
	// o miolo esbranquicado onde o vidro virou teia. Cada fio de trinca e uma
	// face de quebra que devolve luz, entao ele acende claro e fica opaco.
	float fio = 0.0;
	if (trinca.w > 0.0) {
		vec3 d = pos_local - trinca.xyz;
		vec3 n = normalize(normal_local);
		vec3 u = normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
		vec3 w = cross(n, u);
		vec2 p = vec2(dot(d, u), dot(d, w));
		float r = length(p);
		float alcance = mix(0.12, 0.55, trinca.w);
		if (r < alcance) {
			float a = atan(p.y, p.x);
			// Raios: treze, tortos, cada um com o proprio comprimento. A largura
			// e em metros (1,5 a 4 mm: a 4 m um pixel vale uns 4 mm), e nao em angulo: fio de trinca tem a mesma
			// grossura perto e longe do centro.
			float torto = a * 13.0 / 6.2831853 + sin(r * 23.0 + a * 2.0) * 0.35;
			float qual = floor(torto);
			float comprimento = alcance * (0.45 + 0.55 * fract(sin(qual * 12.9898) * 43758.5453));
			float d_raio = abs(fract(torto) - 0.5) * 6.2831853 / 13.0 * r;
			float raio = (1.0 - smoothstep(0.0015, 0.004, d_raio))
				* (1.0 - smoothstep(comprimento * 0.7, comprimento, r));
			// Aneis: tres, ondulados e quebrados em pedacos.
			float anel = 0.0;
			for (int k = 0; k < 3; k++) {
				float fk = float(k);
				float rk = alcance * (0.16 + 0.24 * fk) * (1.0 + 0.08 * sin(a * 5.0 + fk * 1.7));
				float pedaco = step(0.35, fract(sin(floor(a * 7.0 / 6.2831853 + fk) * 78.233) * 43758.5453));
				anel = max(anel, (1.0 - smoothstep(0.0015, 0.004, abs(r - rk))) * pedaco);
			}
			// Miolo: a teia, onde nao se ve mais atraves.
			float teia = 1.0 - smoothstep(alcance * 0.04, alcance * 0.08, r);
			fio = clamp(max(max(raio, anel * 0.85), teia) * trinca.w, 0.0, 1.0);
		}
	}

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(tom * TOM, vec3(0.75, 0.78, 0.80), fio);
	ALPHA = clamp(max(alfa + fresnel * 0.55, fio * 0.9), 0.0, 0.97);
	METALLIC = 0.0;
	ROUGHNESS = mix(rug, 0.45, fio);
	SPECULAR = 0.55;
}

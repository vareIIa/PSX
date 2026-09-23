// Lataria do MODERNO (PLANO_CARROS_AAA, F2).
//
// O carro inteiro era um material so no psx_surface_pixel: METALLIC 0 e uma
// rugosidade para pintura, cromo, vidro e pneu. Aqui cada vertice diz do que e
// feito pela UV2.x, gravada na montagem (`Carroceria.Classe`):
//
//   0 pintura   verniz (clearcoat) por cima da tinta, casca de laranja leve
//   1 cromo     metal, quase espelho
//   2 plastico  acetinado
//   3 borracha  fosca
//   4 fundo     assoalho e cava de roda
//   5 vidro     so aparece quando alguem forca este material no vidro
//   6 espelho   retrovisor
//   7 forro     banco do interior
//
// A UV2.y e a sujeira: barro que subiu da rua. Onde ha barro nao ha verniz.
//
// cull_disabled: a face de TRAS do casco vira o forro de dentro. Com o vidro
// transparente, o olho que entra pela janela via a rua do outro lado — o carro
// era uma casca oca.
//
// O PS1 STYLE nao passa por aqui: la o mat_carro continua no psx_surface.
// Os nomes de uniform repetem os do psx_surface de proposito, para a troca de
// shader da EstiloVisual preservar o que o material ja tinha.

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://shaders/psx_chuva.gdshaderinc"

// Linear, e nao ponto: em 4K a celula de 32 px da grade e da placa vira escada.
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
// Pintura metalica deste carro (PLANO_CARROS_AAA, F7), escrita pelo `Carro`
// por semente: 0 e a tinta solida de sempre, 1 e metalica, com floco de
// aluminio debaixo do verniz.
instance uniform float metalico : hint_range(0.0, 1.0) = 0.0;

global uniform bool psx_snap;
global uniform bool psx_affine;
global uniform float psx_snap_escala;
global uniform float psx_molhado;
global uniform float psx_chuva;

// A tinta NAO le o atlas (PLANO_CARROS_AAA, F6). As celulas de pintura sao
// desenho de PS1 — linha de porta, pingo de ferrugem, risco de capo — e a
// celula se repete em cada painel do casco. Com um terco dela na tinta, o
// MODERNO saia com os mesmos rabiscos espalhados pela lataria inteira, e o
// jogador reportou: "carros estao cheios de rabiscos". Porta e vinco viraram
// geometria; o que sobra de carro usado e procedural e segue a sujeira, que
// sobe do chao (UV2.y).
//
// Barro seco e ferrugem, ja em linear.
const vec3 BARRO_LIN = vec3(0.150, 0.098, 0.052);
const vec3 FERRUGEM_LIN = vec3(0.180, 0.060, 0.020);
// O preenchimento generico do mat_carro (emissao fraca) existia para o carro nao
// sumir na nevoa do PS1. Com luz por pixel ele achata o volume; fica um resto.
const float EMISSAO_RESTO = 0.35;

varying vec2 uv_affine;
varying float w_affine;
varying float face_cima;
varying vec3 pos_local;
varying vec3 normal_local;
varying flat int classe;
varying float sujeira;


float ruido3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = i.x + i.y * 57.0 + i.z * 113.0;
	float a = fract(sin(n) * 43758.5453);
	float b = fract(sin(n + 1.0) * 43758.5453);
	float c = fract(sin(n + 57.0) * 43758.5453);
	float d = fract(sin(n + 58.0) * 43758.5453);
	float e = fract(sin(n + 113.0) * 43758.5453);
	float g = fract(sin(n + 114.0) * 43758.5453);
	float h = fract(sin(n + 170.0) * 43758.5453);
	float k = fract(sin(n + 171.0) * 43758.5453);
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
		mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}


void vertex() {
	classe = int(UV2.x + 0.5);
	sujeira = UV2.y;
	face_cima = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	pos_local = VERTEX;
	normal_local = NORMAL;

	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (use_snap && psx_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		vec2 grade = snap_resolution * psx_snap_escala;
		ndc.xy = floor(ndc.xy * grade) / grade;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;
	w_affine = clip.w;
	uv_affine = UV * uv_tile * clip.w;
}


void fragment() {
	vec2 uv = (use_affine && psx_affine) ? (uv_affine / w_affine) : (UV * uv_tile);
	vec3 texel = texture(albedo_tex, uv).rgb * tint.rgb;
	// A cor de vertice foi escolhida como sRGB (`TINTAS`, `CROMO`...), mas o
	// motor a entrega crua. Usada como linear, o vermelho 0,62 virava salmao e
	// todo o transito saia desbotado. A textura ja vem linear pelo source_color.
	vec3 cor = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));

	vec3 base;
	float rug;
	float metal = 0.0;
	float esp = 0.5;
	float verniz = 0.0;
	float verniz_rug = 0.08;
	bool de_fora = FRONT_FACING;

	if (!de_fora && classe != 7) {
		// O avesso do casco: forro de porta, carpete e teto por dentro. Um tom
		// so, escuro e fosco — de fora ele so aparece atras do vidro.
		base = vec3(0.045, 0.040, 0.036);
		rug = 0.92;
		esp = 0.2;
	} else if (classe == 0) {
		// Tinta desbotada em manchas largas: nenhum carro de quinze anos tem a
		// mesma cor no teto e na porta.
		float desbotado = ruido3(pos_local * 1.7) - 0.5;
		base = cor * (1.0 + desbotado * 0.06);
		// O barro nao e um degrade liso: ele respinga em manchas, mais baixo e
		// mais grosso perto do chao.
		float mancha = ruido3(pos_local * 9.0) * 0.65 + ruido3(pos_local * 31.0) * 0.35;
		float barro = smoothstep(0.10, 0.75, sujeira) * smoothstep(0.30, 0.62, mancha);
		base = mix(base, BARRO_LIN, barro * 0.72);
		// Ferrugem so onde o barro mora ha anos: embaixo, em pingos.
		float ferro = smoothstep(0.55, 0.95, sujeira)
			* smoothstep(0.66, 0.74, ruido3(pos_local * 14.0 + 5.3));
		base = mix(base, FERRUGEM_LIN, ferro * 0.85);
		rug = mix(0.30, 0.86, max(barro, ferro));
		verniz = (1.0 - smoothstep(0.05, 0.6, sujeira)) * (1.0 - ferro);
		verniz_rug = mix(0.04, 0.35, sujeira);
		// Casca de laranja: o verniz de fabrica nunca e um espelho plano. So se
		// ve no reflexo, que e onde ela existe num carro de verdade.
		vec3 p = pos_local * 55.0;
		vec3 g = vec3(ruido3(p), ruido3(p + 17.3), ruido3(p + 31.1)) - 0.5;
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * (MODEL_MATRIX * vec4(g, 0.0))).xyz * 0.022);
		// Metalica: a base vira metal pela metade e o floco de aluminio, um
		// ruido fino demais para o olho separar, acende em pontos quando o sol
		// bate no angulo dele. O verniz continua por cima, liso.
		if (metalico > 0.0) {
			vec3 f = pos_local * 700.0;
			vec3 floco = vec3(ruido3(f), ruido3(f + 5.1), ruido3(f + 9.7)) - 0.5;
			vec3 floco_v = (VIEW_MATRIX * (MODEL_MATRIX * vec4(floco, 0.0))).xyz;
			NORMAL = normalize(NORMAL + floco_v * 0.16 * metalico * (1.0 - barro));
			metal = 0.55 * metalico * (1.0 - max(barro, ferro));
			rug = mix(rug, rug * 0.7, metalico);
		}
	} else if (classe == 1) {
		// A cor do cromo no vertice ja vem com a sombra de montagem (0,7 a 1,14
		// do CROMO); ela vira so a forca do metal, nao um cinza pintado.
		float l = dot(COLOR.rgb, vec3(0.333));
		base = vec3(0.90, 0.90, 0.92) * clamp(l / 0.70, 0.55, 1.15);
		metal = 1.0;
		rug = 0.14;
	} else if (classe == 2) {
		base = cor * texel;
		rug = 0.55;
		esp = 0.40;
	} else if (classe == 3) {
		base = cor * texel;
		rug = 0.86;
		esp = 0.30;
	} else if (classe == 4) {
		base = cor * texel;
		rug = 0.92;
		esp = 0.20;
	} else if (classe == 5) {
		base = cor * 0.55;
		rug = 0.04;
		esp = 0.60;
	} else if (classe == 6) {
		base = vec3(0.82);
		metal = 1.0;
		rug = 0.03;
	} else {
		// Courvin: fosco com um lustro de uso.
		base = cor;
		rug = 0.60;
		esp = 0.35;
	}

	// Molhado: so a face exterior que olha para cima, como no resto da rua.
	float exterior = (de_fora && classe != 7) ? 1.0 : 0.0;
	float molhado = psx_molhado * molha * (1.0 - abrigo) * exterior
		* smoothstep(0.30, 0.75, face_cima);
	base *= mix(1.0, 0.72, molhado);
	rug = mix(rug, min(rug, rugosidade_molhada), molhado);

	if (gotas > 0.0 && exterior > 0.0 && classe <= 2) {
		float cobertura = gotas * (1.0 - abrigo)
			* clamp(max(psx_chuva * 3.0, psx_molhado * 1.15), 0.0, 1.0);
		if (cobertura > 0.01) {
			vec4 g = gotas_na_chapa(pos_local, normal_local, cobertura);
			if (g.w > 0.0) {
				vec3 desvio = (VIEW_MATRIX * (MODEL_MATRIX * vec4(g.xyz, 0.0))).xyz;
				NORMAL = normalize(NORMAL + desvio * g.w * 1.6);
				base *= mix(1.0, 0.85, g.w);
				rug = mix(rug, 0.03, g.w);
				verniz_rug = mix(verniz_rug, 0.02, g.w);
			}
		}
		float bate = psx_chuva * gotas * smoothstep(0.6, 0.9, normalize(normal_local).y);
		if (bate > 0.01) {
			vec2 onda = aneis_de_chuva(pos_local.xz * 7.0, TIME * 1.6);
			vec3 d2 = (VIEW_MATRIX * (MODEL_MATRIX * vec4(onda.x, 0.0, onda.y, 0.0))).xyz;
			NORMAL = normalize(NORMAL + d2 * bate * 0.7);
		}
	}

	ALBEDO = base;
	METALLIC = metal;
	ROUGHNESS = rug;
	SPECULAR = esp;
	CLEARCOAT = verniz;
	CLEARCOAT_ROUGHNESS = verniz_rug;
	if (emission_energy > 0.0 && exterior > 0.0) {
		EMISSION = emission_color.rgb * base * emission_energy * EMISSAO_RESTO * (1.0 - metal);
	}
}

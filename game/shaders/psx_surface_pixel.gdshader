// Superficie MODERNA — a variante por pixel do psx_surface.
//
// Por que existe um segundo arquivo em vez de um uniform
// ------------------------------------------------------
// `vertex_lighting` e `shadows_disabled` sao `render_mode`: o compilador resolve
// os dois e nao ha como virar nenhum deles com uniform. Entao o preset de estilo
// troca `material.shader` entre este arquivo e o psx_surface.
//
// TODO uniform daqui tem nome identico ao do psx_surface, de proposito. E isso
// que faz a troca preservar os 106 materiais sem reconfigurar nenhum: o Godot
// reaproveita por nome o que ja estava setado. Se um nome divergir, aquele
// material perde o valor e volta ao padrao na hora de trocar de estilo.
//
// O que muda em relacao ao psx_surface:
//   - luz por PIXEL, nao por vertice
//   - recebe sombra projetada (sem `shadows_disabled`)
//   - tem specular, com rugosidade controlavel — e o que da para onde ir quando
//     a superficie molhar
//
// O que NAO muda, e nao deve mudar: filtro de textura ponto, geometria low-poly,
// snap e UV afim disponiveis. E o mesmo jogo com luz melhor, nao outro jogo.

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_tile = vec2(1.0, 1.0);

uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;
uniform bool use_affine = true;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.0;

// Ver psx_surface: o global so sabe DESLIGAR, quem liga e o material.
global uniform bool psx_snap;
global uniform bool psx_affine;
global uniform float psx_snap_escala;

uniform float vento_forca : hint_range(0.0, 1.0) = 0.0;
uniform float vento_velocidade : hint_range(0.0, 6.0) = 1.0;
const vec2 VENTO_DIR = vec2(0.82, 0.57);

uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

// Exclusivos desta variante. Nao existem no psx_surface porque la o specular e
// desligado por render_mode; ao voltar para PS1 STYLE eles sao simplesmente
// ignorados, e ao voltar para MODERNO reaparecem com estes padroes.
//
// 0.88 e fosco de rua: reboco, asfalto seco, concreto. Quem precisa brilhar
// (vidro, metal, carroceria, e mais tarde tudo que estiver molhado) baixa isto
// no proprio material.
uniform float rugosidade : hint_range(0.0, 1.0) = 0.88;
uniform float brilho : hint_range(0.0, 1.0) = 0.12;

// --- molhado -----------------------------------------------------------------
// Quanto o mundo esta molhado, escrito pelo Clima. Global porque toda superficie
// de rua responde, inclusive a que o streaming ainda nem carregou.
//
// So existe nesta variante. O psx_surface tem `specular_disabled`: la nao havia
// para onde o reflexo ir, e o PS1 STYLE continua sendo a build de antes.
global uniform float psx_molhado;

// Quanto ESTE material responde. Marquise, teto e interior marcam 0 — a chuva
// nao alcanca. O padrao e 1 porque a maioria esmagadora das superficies do jogo
// e rua a ceu aberto.
uniform float molha : hint_range(0.0, 1.0) = 1.0;

// Quao espelhada ESTA superficie fica encharcada.
//
// Asfalto e calcada viram lamina e refletem quase limpo; grama, terra e areia
// ABSORVEM — escurecem bastante e refletem pouco. Sem esta separacao o gramado
// vira um lago de mercurio, que foi exatamente o que a primeira captura mostrou.
uniform float rugosidade_molhada : hint_range(0.0, 1.0) = 0.12;

// Esta caindo chuva agora. Separado do molhado de proposito: a rua continua
// molhada minutos depois que a chuva para, mas o anel de impacto tem de parar
// junto com a ultima gota. Confundir os dois deixa a poca fervendo no dia
// seguinte.
global uniform float psx_chuva;

varying vec2 uv_affine;
varying float w_affine;
/// Componente Y da normal em MUNDO. Sai do vertice porque no fragmento a NORMAL
/// ja esta em espaco de visao, e "para cima" ali muda quando a camera gira.
varying float face_cima;
/// Posicao em mundo. O anel de impacto e ancorado no MUNDO, e nao na UV: preso a
/// UV ele escorregaria junto com a textura e nasceria repetido em cada peca da
/// malha, delatando a grade do chunk.
varying vec3 pos_mundo;


float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

/// Aneis de impacto de gota, em espaco de mundo.
///
/// Uma celula, uma gota. Cada celula dispara na sua propria fase, entao as gotas
/// nao caem todas no mesmo instante — que e o defeito que faz chuva procedural
/// parecer um pulso de radar.
///
/// Quatro celulas vizinhas, e nao nove: o anel morre bem antes de alcancar a
/// borda da celula, entao as cinco de fora nao contribuem com nada e custariam
/// mais da metade do orcamento do efeito.
///
/// A escala de entrada importa mais que qualquer constante daqui. Em 1,35 a
/// celula tinha 74 cm e o anel chegava a 68 cm de diametro — uma pedra caindo
/// no lago, nao chuva. Em 4,2 a celula tem 24 cm e o anel para em 11 cm, que e
/// o tamanho de uma gota batendo em poca.
vec2 aneis_de_chuva(vec2 p, float t) {
	vec2 soma = vec2(0.0);
	vec2 base = floor(p);
	for (int i = 0; i < 4; i++) {
		vec2 c = base + vec2(float(i & 1), float(i >> 1));
		float h = hash21(c);
		// Fase propria por celula. O `h` entra somado ao tempo, entao a gota
		// desta celula cai num momento que nenhuma vizinha repete.
		float fase = fract(t * 1.1 + h);
		vec2 centro = c + vec2(hash21(c + 17.3), hash21(c + 31.7));
		vec2 d = p - centro;
		float dist = length(d) + 1e-5;
		// O anel expande e desaparece. `vida` ao quadrado faz ele sumir
		// rapido no fim, como agua de verdade: o ultimo terco do raio quase
		// nao se ve.
		float raio = fase * 0.46;
		float anel = smoothstep(0.055, 0.0, abs(dist - raio));
		float vida = 1.0 - fase;
		soma += (d / dist) * anel * vida * vida;
	}
	return soma;
}

void vertex() {
	if (vento_forca > 0.0) {
		vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float fase = mundo.x * 0.31 + mundo.z * 0.23;
		float balanco = sin(TIME * vento_velocidade + fase)
			+ 0.45 * sin(TIME * vento_velocidade * 1.73 + fase * 1.31);
		float rajada = 0.65 + 0.35 * sin(TIME * 0.21 + mundo.x * 0.02);
		vec2 desvio = VENTO_DIR * (balanco * rajada * vento_forca * COLOR.a);
		VERTEX.x += desvio.x;
		VERTEX.z += desvio.y;
		VERTEX.y -= length(desvio) * 0.25;
	}

	face_cima = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

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
	vec4 texel = texture(albedo_tex, uv) * tint;
	ALBEDO = texel.rgb * COLOR.rgb;

	if (alpha_cutoff > 0.0) {
		ALPHA = texel.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	}

	if (emission_energy > 0.0) {
		EMISSION = emission_color.rgb * texel.rgb * COLOR.rgb * emission_energy;
	}

	// Molhado. So o que aponta para cima: agua escorre da parede e fica no chao,
	// entao a face vertical continua fosca enquanto a horizontal espelha. Sai de
	// graca da normal, sem mascara pintada e sem segunda textura.
	//
	// O degrau comeca em 0,30 e nao em 0: uma rampa a partir do zero deixaria a
	// parede levemente brilhante, e "tudo um pouco molhado" le como verniz, nao
	// como chuva.
	float molhado = psx_molhado * molha * smoothstep(0.30, 0.75, face_cima);

	// Escurecer e o efeito mais barato e o mais convincente, e e fisica de
	// verdade: a lamina de agua prende a luz em reflexoes internas e devolve
	// menos ao olho. Asfalto molhado nao brilha mais que o seco — ele fica mais
	// ESCURO, e e o reflexo que aparece por cima.
	ALBEDO *= mix(1.0, 0.52, molhado);

	// A rugosidade e quem acende o reflexo: com 0,88 o asfalto seco espalha a
	// luz e engole qualquer reflexo; com 0,12 a lamina devolve o poste inteiro.
	// E o mesmo numero que faz o SSR ter o que mostrar.
	// Anel de impacto. So na lamina molhada e so enquanto cai chuva; a
	// perturbacao entra na NORMAL, e nao no albedo, porque o que se ve de um anel
	// de agua nao e uma marca clara, e o reflexo TORTO. Escrito no albedo ele
	// viraria um desenho de giz.
	//
	// A onda e montada em MUNDO e convertida para espaco de visao pela VIEW_MATRIX,
	// que e onde a NORMAL vive no fragmento.
	float bate = psx_chuva * molhado;
	if (bate > 0.01) {
		vec2 onda = aneis_de_chuva(pos_mundo.xz * 4.2, TIME);
		vec3 desvio = (VIEW_MATRIX * vec4(onda.x, 0.0, onda.y, 0.0)).xyz;
		NORMAL = normalize(NORMAL + desvio * bate * 0.85);
	}

	ROUGHNESS = mix(rugosidade, rugosidade_molhada, molhado);
	METALLIC = 0.0;
	// O realce acompanha a rugosidade: superficie que nao espelha tambem nao
	// ganha specular, senao a grama molhada fica com brilho de plastico.
	SPECULAR = mix(brilho, mix(0.55, brilho, rugosidade_molhada), molhado);
}

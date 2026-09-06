// Facho de luz como geometria somada. O jeito que o PS1 fazia.
//
// O ART-BIBLE secao 8 proibe nevoa volumetrica com raymarch, e a proibicao segue
// valendo. Isto nao e raymarch: e um tronco de cone translucido somado por cima
// da cena, com o degrade na cor de vertice. Silent Hill e Resident Evil faziam
// exatamente assim, e por isso o facho aparece facetado em vez de suave.
//
// A intensidade sobe com a densidade da nevoa, porque e a nevoa que da o que
// iluminar. Com nevoa desligada o facho quase some, que e o correto.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

// Multiplicador global. A cor de cada lampada vem da cor de vertice do cone,
// senao o material compartilhado faria todos os postes terem a mesma cor.
uniform vec4 cor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensidade : hint_range(0.0, 4.0) = 1.0;

// Modulada pelo script da lampada. E instance uniform para cada poste piscar no
// seu proprio ritmo sem duplicar material.
instance uniform float piscar = 1.0;

// O facho some de longe: somar geometria brilhante no fundo da rua entrega o
// truque e polui o horizonte.
uniform float fade_inicio = 12.0;
uniform float fade_fim = 26.0;

// Fatia de perto, para a camera nao entrar dentro de um bloco de luz solido.
uniform float fade_perto = 1.2;

uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

varying float v_alpha;
varying float v_dist;
varying vec3 v_cor;
varying vec3 v_normal_view;
varying vec3 v_pos_view;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// O facho tem que tremer junto com o cenario. Sem snap ele desliza sobre a
	// geometria e denuncia que e um objeto separado.
	if (use_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		ndc.xy = floor(ndc.xy * snap_resolution) / snap_resolution;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;

	v_alpha = COLOR.a;
	v_cor = COLOR.rgb;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_pos_view = pv;
	v_dist = length(pv);
	v_normal_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float a = v_alpha * intensidade * piscar;

	// Suaviza a silhueta: de raspao o cone some, de frente ele aparece inteiro.
	float encaramento = abs(dot(normalize(v_normal_view), normalize(-v_pos_view)));
	a *= smoothstep(0.0, 0.5, encaramento);

	a *= 1.0 - smoothstep(fade_inicio, fade_fim, v_dist);
	a *= smoothstep(0.0, fade_perto, v_dist);

	// Dither na transparencia. O PS1 nao tinha alfa por pixel de verdade: ele
	// alternava pixels num padrao ordenado, e e isso que da o facho granulado
	// em vez de um degrade limpo de motor moderno.
	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	a += (BAYER[idx] / 16.0 - 0.5) * 0.12;

	ALBEDO = cor.rgb * v_cor;
	ALPHA = clamp(a, 0.0, 1.0);
}

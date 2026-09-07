// Nuvem. Quad grande semitransparente, com dither ordenado.
//
// Nuvens no PS1 eram quads gigantes movendo devagar. Sem textura procedural:
// a forma vem de quads com alpha dithered que dao a aparencia de massa de ar.
// A cor muda por preset para nuvens brancas de dia e nuvens escuras a noite.
//
// Cada particula e uma nuvem individual. O sistema de particulas do CeuDiurno
// dispoe-as horizontalmente numa area larga sobre a camera.

shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

uniform vec4 cor_nuvem : source_color = vec4(0.85, 0.87, 0.90, 1.0);
uniform float opacidade : hint_range(0.0, 1.0) = 0.55;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

// Billboard. Sem isto o quad da particula fica preso ao eixo Z do mundo e some
// de perfil assim que o jogador vira a cabeca: so o que estivesse exatamente a
// frente chegava a ser desenhado. A escala da particula e preservada a mao,
// porque a matriz de billboard a descartaria.
void vertex() {
	mat4 orientada = mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * orientada * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	// Forma eliptica: nuvem mais larga que alta.
	vec2 centro = UV - vec2(0.5);
	centro.x *= 0.55;  // alarga horizontalmente
	float dist = length(centro) * 2.0;

	// Borda difusa: nuvem nao tem contorno rigido.
	float forma = 1.0 - smoothstep(0.35, 1.0, dist);

	// Variacao de densidade interna para nao parecer plastico.
	float densidade = 0.6 + UV.x * 0.25 + UV.y * 0.15;

	float a = forma * densidade * opacidade * COLOR.a;

	// Dither — consistencia visual com o resto dos efeitos.
	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	a += (BAYER[idx] / 16.0 - 0.5) * 0.15;

	ALBEDO = cor_nuvem.rgb * COLOR.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}

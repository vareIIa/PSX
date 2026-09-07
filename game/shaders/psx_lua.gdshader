// Disco da lua. Quad esferizado com dither, estilo PS1.
//
// A lua nao e uma textura fotografica: e um circulo branco-amarelado com leve
// variacao de tom, coerente com o look de arte PS1 do projeto. O dither
// ordenado mantém a consistencia visual com o resto dos efeitos.
//
// E renderizado como quad colado ao ceu — sem perspectiva real — porque o PS1
// nao tinha skybox esferizado. A distorcao nao e bug, e estetica.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

uniform vec4 cor_lua : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float intensidade : hint_range(0.0, 2.0) = 0.85;
// Quanto da borda e suavizada. Valor alto da halo difuso; baixo da disco solido.
uniform float suavidade : hint_range(0.0, 1.0) = 0.18;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	vec2 centro = UV - vec2(0.5);
	float dist = length(centro) * 2.0;

	// Disco com borda suave.
	float forma = 1.0 - smoothstep(1.0 - suavidade, 1.0, dist);

	// Leve variacao de brilho para nao parecer completamente plana.
	float var_tom = 0.82 + UV.x * 0.12 + UV.y * 0.06;

	float a = forma * intensidade * var_tom;

	// Dither ordenado.
	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	a += (BAYER[idx] / 16.0 - 0.5) * 0.12;

	ALBEDO = cor_lua.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}

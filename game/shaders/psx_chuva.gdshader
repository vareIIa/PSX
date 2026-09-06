// Risco de chuva. Quad esticado na vertical, com alfa em dither.
//
// A chuva da referencia noturna aparece como risco claro contra o escuro, nao
// como gota redonda. O quad e alto e fino de proposito, e o alfa cai para as
// pontas para o risco ter cabeca e cauda em vez de ser um retangulo.
//
// Alfa em dither ordenado pela mesma razao do facho de luz: o PS1 nao tinha
// transparencia por pixel, ele alternava pixels num padrao fixo. Sem isso a
// chuva fica lisa demais e destoa do resto da imagem.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

uniform vec4 cor : source_color = vec4(0.72, 0.78, 0.85, 1.0);
uniform float intensidade : hint_range(0.0, 3.0) = 1.0;

// Cai perto da camera para o risco nao virar uma parede de linhas na cara, e
// longe dela porque a nevoa ja engoliu tudo la atras.
uniform float perto = 0.6;
uniform float longe = 22.0;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

varying float v_dist;

void vertex() {
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	// Cabeca e cauda do risco. UV.y vai de 0 no topo a 1 na base.
	float ao_longo = 1.0 - abs(UV.y * 2.0 - 1.0);
	float atravessado = 1.0 - abs(UV.x * 2.0 - 1.0);

	float a = ao_longo * atravessado * intensidade * COLOR.a;
	a *= smoothstep(0.0, perto, v_dist);
	a *= 1.0 - smoothstep(longe * 0.6, longe, v_dist);

	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	a += (BAYER[idx] / 16.0 - 0.5) * 0.16;

	ALBEDO = cor.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}

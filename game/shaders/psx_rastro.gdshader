// Rastro de condensacao do jato (CeuVivo): a fita branca que o aviao deixa no
// ceu azul, fina logo atras dele, alargando e sumindo com a idade. A cor e o
// alfa vem por vertice (o CPU monta a fita a cada quadro); aqui so o ar.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix, shadows_disabled;

uniform vec3 fundo : source_color = vec3(0.53, 0.72, 0.92);
uniform float ar = 0.15;

void fragment() {
	ALBEDO = mix(COLOR.rgb, fundo, ar);
	ALPHA = COLOR.a;
}

// Estrelas no ceu noturno. Ponto dithered, estilo PS1.
//
// Cada estrela e um quad minusculo. A cor branca-azulada e a opacidade variam
// por ruido para simular a diferenca de magnitude das estrelas reais. O dither
// ordenado impede o antialiasing suave que denunciaria que sao pixels modernos.
//
// As estrelas ficam sempre no mesmo angulo da camera porque o skybox do PS1
// nao existia: era cor solida. Aqui simulamos um ceu de pontos presos a
// rotacao da camera — quem olha para cima ve estrelas, quem olha para frente
// ve o horizonte escuro.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

uniform float brilho : hint_range(0.0, 3.0) = 0.9;
uniform vec4 cor_base : source_color = vec4(0.85, 0.90, 1.0, 1.0);

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
	// Forma circular: distancia ao centro do quad.
	vec2 centro = UV - vec2(0.5);
	float dist = length(centro) * 2.0;
	float forma = 1.0 - smoothstep(0.0, 0.85, dist);

	// Variacao de brilho por instancia (passada via COLOR da particula).
	float intensidade = brilho * COLOR.a * forma;

	// Dither ordenado 4x4 — mesmo padrao do facho de luz e da chuva.
	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	intensidade += (BAYER[idx] / 16.0 - 0.5) * 0.25;

	ALBEDO = cor_base.rgb * COLOR.rgb;
	ALPHA = clamp(intensidade, 0.0, 1.0);
}

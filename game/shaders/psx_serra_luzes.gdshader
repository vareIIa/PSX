// O que acende na serra (SerraDaCidade): a torre de TV no alto, as luzes de
// sitio pelos morros, a cidadezinha vizinha e o carro descendo a estrada no pe
// da serra. E a noite que conta que ha gente morando alem da cidade.
//
// Tipo por vertice (UV.x):
//   0  torre     o mastro. De dia um risco escuro no ceu; a noite some.
//   1  sitio     luz fixa, com um tremor de ar. So a noite.
//   2  pisca     balizamento vermelho da torre: acende e apaga, dia e noite.
//   3  farol     carro na estrada: o vertice gira em torno do eixo Y.
// UV.y e a fase; UV2 = (voltas por segundo do carro, largura do trecho em rad).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix, shadows_disabled;

uniform float noite = 0.0;
uniform float vista = 1.0;
uniform vec3 fundo : source_color = vec3(0.53, 0.72, 0.92);
// Quanto do fundo cobre a torre (esta na crista de longe).
uniform float ar_torre = 0.3;

varying float v_tipo;
varying float v_fase;
varying float v_brilho;
varying vec4 v_cor;

void vertex() {
	v_tipo = UV.x;
	v_fase = UV.y;
	v_cor = COLOR;
	v_brilho = 1.0;
	if (UV.x > 2.5) {
		// O carro percorre um trecho da estrada e some na curva: a posicao sai
		// do relogio, entao o CPU nao toca a malha.
		float k = fract(TIME * UV2.x + UV.y);
		float a = (k - 0.5) * UV2.y;
		float c = cos(a);
		float s = sin(a);
		VERTEX = vec3(c * VERTEX.x + s * VERTEX.z, VERTEX.y, -s * VERTEX.x + c * VERTEX.z);
		v_brilho = sin(3.14159 * k);
		// Metade do tempo a estrada esta vazia.
		v_brilho *= step(0.5, fract(TIME * UV2.x * 0.5 + UV.y * 0.5 + 0.25));
	}
}

void fragment() {
	float a = 0.0;
	vec3 cor = v_cor.rgb;
	if (v_tipo < 0.5) {
		// Mastro: silhueta de dia, afogada no ar como a crista em que esta.
		cor = mix(cor, fundo, ar_torre);
		a = vista * (1.0 - noite);
	} else if (v_tipo < 1.5) {
		float tremor = 0.8 + 0.2 * sin(TIME * (2.0 + v_fase * 5.0) + v_fase * 40.0);
		a = noite * vista * tremor;
	} else if (v_tipo < 2.5) {
		// Balizamento: um segundo aceso, um apagado, fora de fase entre si.
		float ciclo = fract(TIME * 0.5 + v_fase);
		a = step(ciclo, 0.5) * vista * mix(0.55, 1.0, noite);
	} else {
		a = noite * vista * v_brilho;
	}
	if (a < 0.01) {
		discard;
	}
	ALBEDO = cor;
	ALPHA = clamp(a, 0.0, 1.0);
}

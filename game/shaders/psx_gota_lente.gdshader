// Uma gota de chuva na LENTE da camera (criterio A18 do PLANO_AAA_4K).
//
// Desenhada em 2D, por cima da imagem pronta e por baixo do HUD. Nao e placa em
// 3D presa a camera: o TAA reprojeta pelo fundo e arrastaria a gota como
// fantasma a cada giro. Aqui ela e o que e — um objeto grudado no vidro, que nao
// se move quando o mundo se move.
//
// Cada gota e um retangulo so do tamanho dela, entao o custo e o da area das
// gotas, e nao o da tela inteira vezes o numero de gotas.
//
// A cor do retangulo carrega os parametros: `r` e a semente da forma, `g` o
// quanto ela esta escorrendo, `a` a forca (nascer e secar).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
// Nivel de mipmap lido dentro da gota: o quanto ela esta fora de foco.
uniform float lod_desfoque : hint_range(0.0, 6.0) = 3.4;
const float ALONGA = 1.45;

void fragment() {
	float semente = COLOR.r;
	float escorre = COLOR.g;
	float forca = COLOR.a;

	// O retangulo e ALONGA vezes mais alto que largo (ver `GotasLente`): a
	// gota ocupa o topo e a cauda desce pelo resto.
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y * 2.0 * ALONGA - 1.0);
	// Contorno irregular: agua na lente nao e circulo de compasso.
	float ang = atan(p.y, p.x);
	float torto = 1.0 + 0.07 * sin(ang * 3.0 + semente * 40.0)
		+ 0.04 * sin(ang * 5.0 + semente * 91.0);
	// Pesa para baixo: a gota que escorre tem cauda.
	vec2 q = p;
	q.y *= mix(1.0, q.y > 0.0 ? 0.7 : 1.15, escorre);
	float r = length(q) / torto;
	float cobre = smoothstep(1.0, 0.82, r);
	if (cobre <= 0.001) {
		discard;
	}
	// Cupula: a inclinacao cresce para a borda, e com ela o desvio. O miolo
	// mostra o mundo quase no lugar, a borda mostra o mundo de longe e
	// invertido — a lente convergente que toda gota e.
	float r2 = clamp(r * r, 0.0, 1.0);
	float altura = sqrt(1.0 - r2);
	vec2 desvio = -q * (1.25 - altura) * 0.9;
	// Raio da gota em UV de tela: a UV do retangulo anda 1/tamanho por pixel.
	vec2 raio_uv = vec2(0.5 / max(fwidth(UV.x), 1e-5)) * SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV + desvio * raio_uv * 2.6;
	// A gota esta fora de foco: a lente foca no mundo, a centimetros do vidro
	// nao ha nitidez nenhuma.
	vec3 c = textureLod(tela, uv, lod_desfoque).rgb;
	// Borda escura (a luz sai pelo lado) e um realce pequeno no alto.
	// A primeira versao tinha aro escuro de 38% e realce de 0,18: saiu bolha
	// de sabao. Gota na lente e mancha, quase sem contorno.
	c *= mix(0.8, 1.02, smoothstep(0.0, 0.5, altura));
	float realce = smoothstep(0.25, 0.0, length(p - vec2(-0.3, -0.4)));
	c += vec3(realce * 0.06);
	COLOR = vec4(c, cobre * forca);
}

// Uma gota corredora: lente, brilho e cauda.
//
// A gota nao e uma mancha clara colada no vidro — e uma LENTE. O que o olho
// reconhece como agua e o mundo atras dela aparecendo invertido e comprimido,
// e nao um ponto branco. Por isso aqui o relevo e uma calota: a normal dela sai
// da derivada da altura, vai para o espaco de visao pela tangente, e desloca a
// amostra da tela.
//
// A forma vem do `INSTANCE_CUSTOM`, que a CPU escreve por instancia:
//
//   r  raio em metros        (para o brilho saber o tamanho da gota)
//   g  alongamento           (a gota que anda vira lagrima)
//   b  quanto ela esta correndo, 0 a 1
//
// `INSTANCE_CUSTOM` so existe em `vertex()` — lido no `fragment()` da "Unknown
// identifier" e o shader inteiro deixa de compilar, sem uma linha dizendo por
// que (medido no spike F da Fase 0). Ele viaja por varying.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear;

// A profundidade do que ja foi desenhado. A tela amostrada tem TUDO que e
// opaco, inclusive o que fica entre o olho e o vidro (o volante, as maos, o
// celular): a gota perto da borda deles refratava o aro amarelo e saia como
// um chuvisco de pontos dourados no para-brisa. O que esta na frente do vidro
// nao esta atras da gota, e ali a amostra volta para o ponto sem desvio.
uniform sampler2D prof : hint_depth_texture, repeat_disable, filter_nearest;

bool na_frente_do_vidro(vec2 uv, float z_vidro, mat4 inv_proj) {
	float d = texture(prof, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.z / v.w > z_vidro + 0.002;
}

// Estilo em vigor (MODERNO liga). Ver `EstiloVisual`.
global uniform bool psx_facho_suave;

uniform vec4 cor : source_color = vec4(0.80, 0.85, 0.90, 1.0);
// Quanto a gota desloca o mundo atras dela, em fracao do TAMANHO DELA.
//
// Nao em fracao de tela: uma gota de 1 cm que desloca 7,5% da tela mostra o que
// esta a vinte gotas de distancia, e o resultado le como mancha preta e nao
// como agua. Meia gota e o que uma lente convexa desse tamanho faz.
uniform float refracao : hint_range(0.0, 1.5) = 0.55;

varying vec3 forma;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);


void vertex() {
	forma = INSTANCE_CUSTOM.rgb;
}


void fragment() {
	// UV de -1 a 1, com o eixo Y ja esticado pelo alongamento da instancia.
	vec2 d = UV * 2.0 - 1.0;
	// A cauda: a gota que corre e mais fina em cima (de onde ela veio) e mais
	// cheia embaixo. `d.y > 0` e o lado de baixo do quadrinho.
	float corre = forma.z;
	float estreita = 1.0 + corre * 1.1 * clamp(-d.y, 0.0, 1.0);
	vec2 dd = vec2(d.x * estreita, d.y);
	float r = length(dd);
	if (r > 1.0) {
		discard;
	}

	// Calota: a altura da gota sobre o vidro, normalizada.
	float h = sqrt(max(0.0, 1.0 - r * r));
	// z pequeno = lente forte: a gota inverte e comprime o que esta atras dela.
	vec3 nb = normalize(vec3(-dd * (1.0 - h), 0.85));
	vec3 n_visao = normalize(TANGENT * nb.x + BINORMAL * nb.y + NORMAL * nb.z);
	// Quanta tela a gota inteira ocupa AQUI. Com a derivada, o deslocamento
	// acompanha a gota de perto e de longe sem um uniform por distancia.
	float tela_da_gota = length(fwidth(SCREEN_UV)) / max(length(fwidth(UV)), 1e-6);
	vec2 desvio = -n_visao.xy * refracao * tela_da_gota;
	bool moderno = psx_facho_suave;
	if (!moderno) {
		// PS1: o mundo refratado anda em passo de pixel da grade de 480x270.
		desvio = floor(desvio * vec2(480.0, 270.0)) / vec2(480.0, 270.0);
	}
	if (na_frente_do_vidro(SCREEN_UV + desvio, VERTEX.z, INV_PROJECTION_MATRIX)) {
		desvio = vec2(0.0);
	}
	vec3 mundo = texture(tela, clamp(SCREEN_UV + desvio, vec2(0.001),
		vec2(0.999))).rgb;

	// O brilho que a gota devolve. E ele, e nao o que ela deixa passar, que faz
	// a agua ser visivel contra mata escura a noite.
	float brilho = pow(clamp(h * 0.35 + n_visao.y * 0.55, 0.0, 1.0), 3.0);
	vec3 c = mundo + cor.rgb * brilho * 0.65;

	float a = smoothstep(1.0, 0.72, r);
	if (!moderno) {
		// Pontilhado MULTIPLICADO, nunca somado: somado, metade do padrao pinta
		// alfa onde nao ha gota e a lataria ganha um veu.
		int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
		a *= 1.0 + (BAYER[idx] / 16.0 - 0.5) * 0.45;
	}
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
}

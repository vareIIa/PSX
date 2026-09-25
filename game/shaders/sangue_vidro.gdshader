// Sangue no vidro do carro, do lado de fora: a testa do padre batendo na
// janela (e a do capo, no para-brisa).
//
// A lamina e o contorno da janela (`SangueNoVidro`), com UV em METROS no plano
// do vidro e +y para cima, como a da trinca. Cada golpe carimba uma celula do
// atlas assado (`tools/gerar_sangue_vidro.py`) no ponto da testa:
//   R espessura, G tempo de chegada do escorrido, B diluicao, A cobertura.
// O escorrido aparece onde G <= progresso do golpe: a frente desce sozinha,
// rapido no comeco e freando.
//
// Sangue nao e tinta: e um filtro. Contra o fogo e o farol la fora ele acende
// vermelho fundo; grosso, fica quase preto; fino e aguado pela chuva, rosado.
// Por isso a cor vem da imagem de tras (a tela) passada pela transmissao, e
// nao de um albedo. Por cima, o brilho molhado: a gota gorda e a conta na
// ponta do escorrido pegam a luz como lente.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D atlas : filter_linear_mipmap_anisotropic, repeat_disable;

// Metros de vidro por celula do atlas (a do gerador, 0,40 m).
uniform float celula = 0.40;
// Onde fica o impacto dentro da celula (a do gerador).
uniform vec2 ancora = vec2(0.5, 0.26);
// Por golpe: a = (u, v, variante, giro), b = (escala, forca, progresso, 0).
uniform vec4 golpes_a[8];
uniform vec4 golpes_b[8];
uniform int n_golpes = 0;
// Absorcao do sangue por metro de espessura "cheia", por canal: o vermelho
// passa, o verde e o azul morrem.
uniform vec3 absorcao = vec3(1.1, 7.5, 8.5);
// A luz que acende o sangue por reflexo: a do painel (vermelha) e a do fogo.
uniform vec4 luz : source_color = vec4(1.0, 0.45, 0.25, 1.0);
uniform float brilho = 1.0;
// A cor do sangue que a luz de dentro (o painel) devolve, e quanto.
uniform vec3 corpo : source_color = vec3(0.30, 0.012, 0.010);
uniform float corpo_forca = 0.35;
// Desvio da imagem de tras pela gota (lente).
uniform float lente = 0.018;

vec2 girar(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Uma amostra do atlas na celula `var`, com as derivadas de fora do laco.
vec4 amostra(vec2 cuv, float var, vec2 dx, vec2 dy) {
	vec2 canto = vec2(mod(var, 2.0), floor(var / 2.0));
	return textureGrad(atlas, (clamp(cuv, 0.002, 0.998) + canto) * 0.5, dx, dy);
}

void fragment() {
	float esp = 0.0;
	float cob = 0.0;
	float dil = 0.0;
	vec2 grad = vec2(0.0);
	float frente = 0.0;
	vec2 duv_x = dFdx(UV);
	vec2 duv_y = dFdy(UV);
	for (int i = 0; i < 8; i++) {
		if (i >= n_golpes) {
			break;
		}
		vec4 a = golpes_a[i];
		vec4 b = golpes_b[i];
		float tam = celula * b.x;
		vec2 c = girar(UV - a.xy, -a.w) / tam;
		vec2 cuv = vec2(ancora.x + c.x, ancora.y - c.y);
		if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) {
			continue;
		}
		vec2 dx = vec2(girar(duv_x, -a.w).x, -girar(duv_x, -a.w).y) / tam * 0.5;
		vec2 dy = vec2(girar(duv_y, -a.w).x, -girar(duv_y, -a.w).y) / tam * 0.5;
		vec4 s = amostra(cuv, a.z, dx, dy);
		if (s.a < 0.004) {
			continue;
		}
		// O escorrido so existe ate onde a frente ja desceu; e a frente e mais
		// gorda (a conta que vai empurrando o resto).
		float prog = b.z;
		float chegou = smoothstep(prog + 0.004, prog - 0.004, s.g);
		if (s.g > 0.02) {
			chegou *= step(0.0005, prog);
		}
		float na_frente = smoothstep(0.035, 0.0, prog - s.g) * step(s.g, prog) * step(0.02, s.g);
		float k = s.a * chegou;
		if (k < 0.004) {
			continue;
		}
		float e = s.r * (1.0 + na_frente * 0.6) * mix(0.75, 1.1, b.y);
		// A inclinacao da camada, para a luz e para a lente: duas amostras ao
		// lado, a meio milimetro.
		float passo = 0.0006 / tam;
		float ex = amostra(cuv + vec2(passo, 0.0), a.z, dx, dy).r;
		float ey = amostra(cuv + vec2(0.0, passo), a.z, dx, dy).r;
		vec2 g = vec2(ex - s.r, -(ey - s.r)) / 0.0006;
		g = girar(g, a.w);
		esp = max(esp, e);
		cob = max(cob, k);
		dil = max(dil, s.b * k);
		grad += g * k;
		frente = max(frente, na_frente * k);
	}
	if (cob < 0.004) {
		discard;
	}
	// A camada tem ~0,4 mm onde e mais grossa; o gradiente vira normal torta.
	vec2 inclina = grad * 0.00035;
	float lente_k = clamp(length(inclina), 0.0, 1.0);
	vec2 desvio = -inclina * lente;
	vec3 atras = textureLod(tela, SCREEN_UV + desvio, 0.0).rgb;
	// Transmissao: Beer-Lambert na espessura, aguado pela chuva onde dilui.
	float cheio = esp * mix(1.0, 0.35, dil);
	vec3 passa = exp(-absorcao * cheio * 1.8);
	vec3 cor = atras * passa;
	// A luz de dentro batendo na camada e voltando vermelha.
	cor += corpo * corpo_forca * (0.35 + cheio) * luz.rgb;
	// Brilho molhado: a borda de cada gota e a conta pegam a luz, em lasca.
	float borda = pow(lente_k, 0.8);
	float lasca = pow(clamp(0.5 + dot(normalize(inclina + 1e-6), vec2(0.62, 0.78)) * 0.5, 0.0, 1.0), 8.0);
	cor += luz.rgb * brilho * (lasca * borda * 0.55 + frente * 0.08 + borda * 0.04);
	ALBEDO = cor;
	ALPHA = clamp(cob, 0.0, 1.0);
}

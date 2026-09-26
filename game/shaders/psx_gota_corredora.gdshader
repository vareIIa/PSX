// Uma gota corredora (e o borrifo da pancada): lente, luz e cauda.
//
// A gota nao e mancha clara colada no vidro — e uma LENTE: o mundo atras dela
// aparece invertido e encolhido (`lente_k`, a mesma conta de
// `psx_vidro_agua`), e as luzes de verdade acendem nela pelo `light()` — o fogo
// do capo, focado pela gota, e a luz vermelha do painel refletida na calota.
// A versao anterior esta em `psx_gota_corredora_antiga.gdshader`.
//
// A forma vem do `INSTANCE_CUSTOM`, que a CPU escreve por instancia:
//
//   r  raio em metros
//   g  alongamento           (a gota que anda vira lagrima; o borrifo, risco)
//   b  quanto ela esta correndo, 0 a 1
//   a  >= 1: corredora, com o sangue que ela carrega em a - 1 (0 a 1)
//      <  1: gota de BORRIFO no ar, com a opacidade em a (0 esconde)
//
// `INSTANCE_CUSTOM` so existe em `vertex()` (lido no `fragment()` o shader nao
// compila, sem dizer por que). Ele viaja por varying.
shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled,
	ambient_light_disabled, fog_disabled;

uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear_mipmap;
// A lente so pode mostrar o que esta ATRAS do vidro. A tela tem tudo o que e
// opaco, inclusive o que fica do lado de dentro (o volante, as maos, o forro, a
// coluna, o painel): o ponto amostrado e reconstruido da profundidade e testado
// contra o PLANO do vidro. Testar so a profundidade (como antes) deixava passar
// o forro e a coluna perto da borda, que ficam mais longe que o vidro no eixo da
// lente mas do lado de dentro dele: a gota do canto saia preta.
uniform sampler2D prof : hint_depth_texture, repeat_disable, filter_nearest;

bool atras_do_vidro(vec2 uv, vec3 ponto_vidro, vec3 n_vidro, mat4 inv_proj) {
	float d = texture(prof, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	vec3 p = v.xyz / v.w;
	// `n_vidro` aponta para o olho: atras e o lado negativo.
	return dot(p - ponto_vidro, n_vidro) < -0.004;
}

global uniform bool psx_facho_suave;

// Quantas vezes o raio da gota ela enxerga para o lado oposto (> 1 inverte).
uniform float lente_k : hint_range(1.0, 6.0) = 2.6;
uniform float borda_escura : hint_range(0.0, 1.0) = 0.08;
uniform float brilho_luz : hint_range(0.0, 8.0) = 1.8;
uniform float dureza_reflexo : hint_range(8.0, 1024.0) = 200.0;
uniform float dureza_foco : hint_range(8.0, 2048.0) = 420.0;
uniform float limiar_brilho : hint_range(0.0, 2.0) = 0.45;
uniform float brilho_fundo : hint_range(0.0, 6.0) = 1.4;
// Compatibilidade com quem ainda escreve o parametro antigo.
uniform vec4 cor : source_color = vec4(0.80, 0.85, 0.90, 1.0);
uniform float refracao : hint_range(0.0, 1.5) = 0.55;

// A janela que estourou (ver `psx_vidro_agua`).
uniform vec3 buraco_min = vec3(0.0);
uniform vec3 buraco_max = vec3(-1.0);
uniform mat4 mundo_para_carro = mat4(1.0);
varying vec3 no_carro;

varying vec4 forma;
varying float v_brilho;
varying float v_lente;
varying vec3 v_normal_vidro;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);


void vertex() {
	forma = INSTANCE_CUSTOM;
	no_carro = (mundo_para_carro * (MODEL_MATRIX * vec4(VERTEX, 1.0))).xyz;
}


void fragment() {
	if (all(greaterThan(no_carro, buraco_min)) && all(lessThan(no_carro, buraco_max))) {
		discard;
	}
	bool borrifo = forma.a < 0.999;
	if (borrifo && forma.a <= 0.002) {
		discard;
	}
	// UV de -1 a 1.
	vec2 d = UV * 2.0 - 1.0;
	float corre = forma.z;
	vec2 dd;
	if (borrifo) {
		// O risco da gota voando: capsula ao longo do quadrinho.
		float comprido = max(forma.y, 1.0);
		vec2 p = vec2(d.x, d.y * comprido);
		p.y = sign(p.y) * max(abs(p.y) - (comprido - 1.0), 0.0);
		dd = p;
	} else {
		// A cauda: a gota que corre e mais fina em cima (de onde veio) e mais
		// cheia embaixo. `d.y > 0` e o lado de baixo do quadrinho.
		float estreita = 1.0 + corre * 1.1 * clamp(-d.y, 0.0, 1.0);
		dd = vec2(d.x * estreita, d.y);
	}
	float r = length(dd);
	if (r > 1.0) {
		discard;
	}
	float rho = r;
	float h = sqrt(max(0.0, 1.0 - rho * rho));
	float incl = rho * 2.0 / sqrt(max(0.08, 1.0 - rho * rho * 0.82));
	vec2 dir = dd / max(r, 1e-5);
	vec3 nb = normalize(vec3(-dir * incl, 1.0));
	vec3 n_visao = normalize(TANGENT * nb.x + BINORMAL * nb.y + NORMAL * nb.z);

	// A lente: a amostra sai do centro para o lado oposto, em unidades do
	// quadrinho, levadas para a tela pela jacobiana do UV.
	vec2 dux = dFdx(UV);
	vec2 duy = dFdy(UV);
	float det = dux.x * duy.y - duy.x * dux.y;
	det = (abs(det) < 1e-14) ? 1e-14 : det;
	mat2 uv_px = mat2(vec2(duy.y, -dux.y), vec2(-duy.x, dux.x)) / det;
	// `d` vai de -1 a 1 no quadrinho: o deslocamento em UV e metade dele.
	vec2 d_uv = (UV - 0.5);
	// O borrifo e pequeno demais para ter imagem: sem lente.
	float k = borrifo ? 0.0 : lente_k;
	vec2 desvio = (uv_px * (-d_uv * k * (1.0 + 0.55 * rho * rho))) / VIEWPORT_SIZE;
	float tam = length(desvio);
	if (tam > 0.06) {
		desvio *= 0.06 / tam;
	}
	bool moderno = psx_facho_suave;
	if (!moderno) {
		desvio = floor(desvio * vec2(480.0, 270.0)) / vec2(480.0, 270.0);
	}
	vec3 n_olho = NORMAL * (dot(NORMAL, -VERTEX) < 0.0 ? -1.0 : 1.0);
	if (!atras_do_vidro(SCREEN_UV + desvio, VERTEX, n_olho, INV_PROJECTION_MATRIX)) {
		desvio *= 0.4;
		if (!atras_do_vidro(SCREEN_UV + desvio, VERTEX, n_olho, INV_PROJECTION_MATRIX)) {
			desvio *= 0.0;
		}
	}
	vec3 mundo = textureLod(tela, clamp(SCREEN_UV + desvio, vec2(0.001),
		vec2(0.999)), moderno ? 0.6 : 0.0).rgb;
	float luz = dot(mundo, vec3(0.2126, 0.7152, 0.0722));
	vec3 c = mundo + mundo * max(0.0, luz - limiar_brilho) * brilho_fundo * (1.0 - 0.6 * rho);
	c *= 1.0 - borda_escura * smoothstep(0.75, 1.0, rho);
	// O sangue que a corredora carrega de uma marca.
	float rosa = borrifo ? 0.0 : clamp(forma.a - 1.0, 0.0, 1.0);
	// Diluido: filtra de rosa, nao pinta de vinho. Com 0,85 a corredora que
	// passava pela marca virava conta de bronze escura (captura de 25/09).
	c *= mix(vec3(1.0), vec3(1.0, 0.45, 0.40), rosa * 0.55);
	c += vec3(0.22, 0.03, 0.02) * rosa * (0.02 + luz * 0.25);

	float aa = fwidth(r) * 1.2;
	float a = smoothstep(1.0, 1.0 - max(aa, 0.08), r);
	// A corredora e agua, e nao conta: um nada do vidro de tras passa por ela.
	a *= borrifo ? 1.0 : 0.9;
	if (borrifo) {
		// O borrifo quase nao desvia nada e so aparece onde pega luz: a gotinha
		// espalha um pouco do fundo claro, mais no miolo.
		// Alfa baixo e cor acima do fundo: a gotinha nunca escurece o que
		// esta atras dela (o risco saia preto na frente da cara).
		a *= forma.a * 0.35;
		c = mundo * (1.12 + 0.5 * h) + mundo * luz * 0.8 * h;
	}
	if (!moderno) {
		int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
		a *= 1.0 + (BAYER[idx] / 16.0 - 0.5) * 0.45;
	}
	a = clamp(a, 0.0, 1.0);

	v_brilho = borrifo ? forma.a * 1.6 : a;
	v_lente = borrifo ? 1.6 : 1.1;
	v_normal_vidro = NORMAL;
	NORMAL = n_visao;
	ALBEDO = vec3(0.0);
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	EMISSION = c * a;
	ALPHA = a;
}


void light() {
	if (v_brilho > 0.001) {
		vec3 n = NORMAL;
		float lado = dot(v_normal_vidro, LIGHT);
		vec3 cor_luz = LIGHT_COLOR * ATTENUATION;
		float brilho = 0.0;
		if (lado > 0.0) {
			vec3 h = normalize(VIEW + LIGHT);
			float nh = max(dot(n, h), 0.0);
			float fresnel = 0.04 + 0.96 * pow(1.0 - max(dot(VIEW, h), 0.0), 5.0);
			brilho = pow(nh, dureza_reflexo) * (dureza_reflexo + 8.0) * 0.04 * fresnel * 6.0;
		} else {
			vec3 sai = normalize(-VIEW + (n - v_normal_vidro) * v_lente);
			float foco = max(dot(sai, LIGHT), 0.0);
			brilho = pow(foco, dureza_foco) * (dureza_foco + 8.0) * 0.012;
		}
		SPECULAR_LIGHT += cor_luz * brilho * brilho_luz * v_brilho;
	}
}

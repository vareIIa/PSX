// O sangue diluido na agua do vidro: um segundo mapa, com memoria, do mesmo
// tamanho e com os mesmos retangulos do mapa de agua (`AguaVidro`).
//
// Por que um mapa a parte: o alfa do mapa de agua nao volta pela copia do
// quadro anterior (`hint_screen_texture` le 1 no canal A; medido em 25/09/2026),
// e os tres canais dele ja tem dono.
//
//   R  quanto sangue a agua deste ponto carrega (0 a 1)
//
// Nasce nas marcas de sangue do vidro (`SangueNoVidro`, lidas pela CPU em
// `AguaCorredoras`), mais forte logo depois de uma pancada perto delas; desce em
// FILETES — cada coluna do vidro no seu passo, a mesma conta do filme em
// `psx_agua_mapa` —; a corredora que passou por uma marca deixa o fio rosa no
// rastro; a chuva e a palheta lavam.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D anterior : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D anterior_liso : hint_screen_texture, repeat_disable, filter_linear;
// O mapa de agua: e a agua que carrega o sangue (seco, ele nao desce).
uniform sampler2D mapa : repeat_disable, filter_linear;

const int MAX_PAINEIS = 10;
const int MAX_TRILHAS = 64;
const int MAX_SANGUE = 8;

uniform float dt = 0.016;
uniform float chuva : hint_range(0.0, 1.0) = 0.0;
uniform float tpm = 200.0;
uniform vec2 tamanho_mapa = vec2(512.0, 256.0);
uniform int n_paineis = 0;
uniform vec4 painel_rect[MAX_PAINEIS];
uniform vec4 painel_dados[MAX_PAINEIS];

uniform int n_trilhas = 0;
uniform vec4 trilha[MAX_TRILHAS];
uniform float trilha_rosa[MAX_TRILHAS];
uniform float trilha_larg = 0.006;

// As marcas: (u, v no mapa, raio em metros, forca).
uniform int n_sangue = 0;
uniform vec4 sangue[MAX_SANGUE];

// Segundos para o rosa se diluir na chuva, e a velocidade do filete mais
// rapido (m/s).
uniform float tempo_rosa = 14.0;
uniform float rosa_vel = 0.09;

// O setor que a palheta varreu neste quadro (ver `psx_agua_mapa`).
uniform int limpador_painel = -1;
uniform vec2 pivo_a = vec2(0.0);
uniform vec2 pivo_b = vec2(0.0);
uniform vec2 raios = vec2(0.10, 0.55);
uniform float ang_de = 0.0;
uniform float ang_ate = 0.0;
uniform float palheta = 0.035;
uniform float limpador_ativo : hint_range(0.0, 1.0) = 0.0;


float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}


float ruido1(float x, float s) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash21(vec2(i, s)), hash21(vec2(i + 1.0, s)), f);
}


float dist_segmento(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float l2 = dot(ab, ab);
	float t = (l2 > 1e-6) ? clamp(dot(p - a, ab) / l2, 0.0, 1.0) : 0.0;
	return distance(p, a + ab * t);
}


float varrido(vec2 m, vec2 pivo) {
	vec2 d = m - pivo;
	float r = length(d);
	if (r < raios.x || r > raios.y) {
		return 0.0;
	}
	float ang = atan(d.x, -d.y);
	float lo = min(ang_de, ang_ate) - palheta;
	float hi = max(ang_de, ang_ate) + palheta;
	return (ang < lo || ang > hi) ? 0.0 : 1.0;
}


void fragment() {
	float rosa = texture(anterior, SCREEN_UV).r;
	int qual = -1;
	vec2 m = vec2(0.0);
	vec4 dados = vec4(0.0);
	for (int i = 0; i < MAX_PAINEIS; i++) {
		if (i >= n_paineis) {
			break;
		}
		vec4 r = painel_rect[i];
		vec2 f = (UV - r.xy) / r.zw;
		if (f.x >= 0.0 && f.x <= 1.0 && f.y >= 0.0 && f.y <= 1.0) {
			qual = i;
			dados = painel_dados[i];
			m = f * dados.xy;
			break;
		}
	}
	if (qual < 0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 agua = texture(mapa, UV).rgb;
		float molhado = clamp(agua.g * 1.5 + agua.r * 0.6, 0.0, 1.0);
		// O filete: as colunas por onde o sangue corre (as mesmas do filme).
		float coluna = ruido1(m.x * 95.0, float(qual) * 7.3 + 1.0);
		float coluna2 = ruido1(m.x * 260.0, float(qual) * 3.1 + 5.0);
		float filete = smoothstep(0.50, 0.86, coluna * 0.75 + coluna2 * 0.25);
		float vel = rosa_vel * (0.05 + 0.95 * filete) * (0.3 + 0.7 * molhado);
		float torto = (ruido1(m.y * 40.0, m.x * 3.0 + 9.0) - 0.5) * 0.35;
		vec2 passo_uv = vec2(torto, 1.0) * vel * dt * tpm / tamanho_mapa;
		vec2 f_acima = (UV - passo_uv - painel_rect[qual].xy) / painel_rect[qual].zw;
		rosa = (f_acima.y >= 0.0) ? texture(anterior_liso, SCREEN_UV - passo_uv).r : 0.0;
		// A chuva lava; o filete dura mais que o lencol.
		rosa *= exp(-dt * (1.0 + chuva * 0.8) / max(tempo_rosa * (0.45 + filete), 0.1));

		vec2 px = UV * tamanho_mapa;
		for (int i = 0; i < MAX_SANGUE; i++) {
			if (i >= n_sangue) {
				break;
			}
			vec4 s = sangue[i];
			vec2 d_m = (px - s.xy * tamanho_mapa) / tpm;
			// A marca escorre por baixo: a fonte e mais comprida para baixo.
			d_m.y *= (d_m.y > 0.0) ? 0.55 : 1.4;
			float marca = 1.0 - smoothstep(s.z * 0.35, s.z, length(d_m));
			rosa = max(rosa, marca * s.w * (0.25 + 0.75 * filete) * molhado);
		}

		float larg_px = max(1.0, trilha_larg * tpm);
		for (int i = 0; i < MAX_TRILHAS; i++) {
			if (i >= n_trilhas) {
				break;
			}
			if (trilha_rosa[i] <= 0.01) {
				continue;
			}
			vec4 t = trilha[i];
			float d = dist_segmento(px, t.xy * tamanho_mapa, t.zw * tamanho_mapa);
			rosa = max(rosa, smoothstep(larg_px, larg_px * 0.35, d) * trilha_rosa[i]);
		}

		if (limpador_ativo > 0.5 && qual == limpador_painel && dados.w > 0.5) {
			rosa *= 1.0 - 0.85 * max(varrido(m, pivo_a), varrido(m, pivo_b));
		}
		COLOR = vec4(clamp(rosa, 0.0, 1.0), 0.0, 0.0, 1.0);
	}
}

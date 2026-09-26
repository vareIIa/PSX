// O mapa de agua: um passo de simulacao por quadro, num viewport que nao limpa.
//
// E o `psx_agua_sim.gdshader` (que continua la para `--agua-antiga`) com o que a
// agua precisa para REAGIR:
//
//   R  cobertura de gota parada    sobe com a chuva, desce com o limpador, com o
//                                  rastro da corredora, com a secagem e com a
//                                  PANCADA, que derruba a gota em volta dela
//   G  filme                       rastro, residuo da palheta e a lamina que a
//                                  pancada espalha; escorre morro abaixo
//   B  embacado                    do lado de DENTRO; so o desembacador o toca
//
// O sangue diluido mora num segundo mapa (`psx_agua_rosa.gdshader`): o alfa
// deste nao volta pelo `hint_screen_texture` (medido em 25/09/2026: escrito 0,01
// por quadro, lido de volta sempre 1).
//
// Precisao: o viewport nasce com `use_hdr_2d` (o passo de 0,0005 some inteiro no
// RGBA8; medido em 16/09/2026).
shader_type canvas_item;
render_mode blend_disabled, unshaded;

// O proprio quadro anterior, via BackBufferCopy. O linear serve ao que ANDA
// (o filme descendo): meio texel por quadro nao cabe no `nearest`.
uniform sampler2D anterior : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D anterior_liso : hint_screen_texture, repeat_disable, filter_linear;

const int MAX_PAINEIS = 10;
const int MAX_TRILHAS = 64;
const int MAX_EVENTOS = 4;

uniform float dt = 0.016;
uniform float chuva : hint_range(0.0, 1.0) = 0.0;
uniform float vento : hint_range(0.0, 1.0) = 0.0;
uniform float umidade : hint_range(0.0, 1.0) = 0.0;
uniform float desembacador : hint_range(0.0, 1.0) = 0.0;

uniform float tpm = 200.0;
uniform vec2 tamanho_mapa = vec2(512.0, 256.0);

uniform int n_paineis = 0;
uniform vec4 painel_rect[MAX_PAINEIS];
uniform vec4 painel_dados[MAX_PAINEIS];

uniform int limpador_painel = -1;
uniform vec2 pivo_a = vec2(0.0);
uniform vec2 pivo_b = vec2(0.0);
uniform vec2 raios = vec2(0.10, 0.55);
uniform float ang_de = 0.0;
uniform float ang_ate = 0.0;
uniform float palheta = 0.035;
uniform float limpador_ativo : hint_range(0.0, 1.0) = 0.0;

uniform int n_trilhas = 0;
uniform vec4 trilha[MAX_TRILHAS];
uniform float trilha_larg = 0.006;

uniform float tempo_encher = 5.0;
uniform float tempo_secar = 45.0;
uniform float tempo_filme = 2.2;
uniform float tempo_embacar = 12.0;

// As pancadas DESTE quadro: (u, v no mapa, raio em metros, forca). Vivem um
// passo so: `AguaVidro.passo` zera no seguinte.
uniform int n_eventos = 0;
uniform vec4 evento[MAX_EVENTOS];
// Velocidade do filete mais rapido, em m/s.
uniform float filete_vel = 0.085;


float dist_segmento(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float l2 = dot(ab, ab);
	float t = (l2 > 1e-6) ? clamp(dot(p - a, ab) / l2, 0.0, 1.0) : 0.0;
	return distance(p, a + ab * t);
}


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


float varrido(vec2 m, vec2 pivo) {
	vec2 d = m - pivo;
	float r = length(d);
	if (r < raios.x || r > raios.y) {
		return 0.0;
	}
	float ang = atan(d.x, -d.y);
	float lo = min(ang_de, ang_ate) - palheta;
	float hi = max(ang_de, ang_ate) + palheta;
	if (ang < lo || ang > hi) {
		return 0.0;
	}
	return smoothstep(raios.x, raios.x + 0.02, r)
		* smoothstep(raios.y, raios.y - 0.02, r);
}


void fragment() {
	vec4 mapa = texture(anterior, SCREEN_UV);
	float cob = mapa.r;
	float filme = mapa.g;
	float embaca = mapa.b;

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
		// 1. A chuva enche; 2. seca.
		float entra = chuva * dados.z * (1.0 + 0.9 * vento) / max(tempo_encher, 0.05);
		cob += entra * dt;
		cob -= dt * (1.0 - chuva * dados.z) * (1.0 + vento) / max(tempo_secar, 0.05);

		// O filme ESCORRE: cada coluna do vidro tem o seu passo (filete rapido,
		// filete parado), e o texel pega o que estava acima dele.
		float coluna = ruido1(m.x * 95.0, float(qual) * 7.3 + 1.0);
		float coluna2 = ruido1(m.x * 260.0, float(qual) * 3.1 + 5.0);
		float filete = smoothstep(0.50, 0.86, coluna * 0.75 + coluna2 * 0.25);
		float molhado = clamp(filme * 1.5 + cob * 0.6, 0.0, 1.0);
		float vel = filete_vel * (0.06 + 0.94 * filete) * (0.35 + 0.65 * molhado);
		// Sinuoso: o fio desvia um nada para o lado conforme desce.
		float torto = (ruido1(m.y * 40.0, m.x * 3.0 + 9.0) - 0.5) * 0.35;
		vec2 passo_uv = vec2(torto, 1.0) * vel * dt * tpm / tamanho_mapa;
		vec4 acima = texture(anterior_liso, SCREEN_UV - passo_uv);
		// So o que esta dentro do mesmo vidro desce: acima da borda e calha.
		vec2 f_acima = (UV - passo_uv - painel_rect[qual].xy) / painel_rect[qual].zw;
		if (f_acima.y >= 0.0) {
			filme = mix(filme, acima.g, 0.7 * filete);
		}
		filme -= dt / max(tempo_filme, 0.05);

		// 3. O limpador.
		if (limpador_ativo > 0.5 && qual == limpador_painel && dados.w > 0.5) {
			float s = max(varrido(m, pivo_a), varrido(m, pivo_b));
			if (s > 0.0) {
				cob = mix(cob, cob * 0.04, s);
				filme = max(filme, s * mix(0.25, 0.75, cob));
			}
		}

		vec2 px = UV * tamanho_mapa;

		// 4. A pancada: a gota em volta cai (o vidro sacudiu), a agua vira lamina
		// num anel irregular, e abaixo dela o lencol escorre.
		for (int i = 0; i < MAX_EVENTOS; i++) {
			if (i >= n_eventos) {
				break;
			}
			vec4 e = evento[i];
			vec2 d_m = (px - e.xy * tamanho_mapa) / tpm;
			float r = length(d_m);
			float ang = atan(d_m.y, d_m.x);
			float torto_e = 0.70 + 0.55 * ruido1(ang * 3.2 + 20.0, e.x * 97.0 + e.y * 13.0);
			float raio = e.z * torto_e;
			float cai = (1.0 - smoothstep(raio * 0.45, raio, r)) * e.w;
			// Abaixo do ponto a agua derrubada desce: uma lingua mais comprida.
			float abaixo = step(0.0, d_m.y) * (1.0 - smoothstep(raio * 0.3, raio * 0.9,
				abs(d_m.x))) * (1.0 - smoothstep(raio * 1.2, raio * 3.2, d_m.y)) * e.w;
			cai = max(cai, abaixo * 0.75 * filete);
			cob = mix(cob, cob * 0.06, clamp(cai, 0.0, 1.0));
			float anel = smoothstep(raio * 1.7, raio * 0.9, r) * (1.0 - cai * 0.4);
			filme = max(filme, clamp((cai * 0.95 + anel * 0.55) * e.w, 0.0, 1.0));
		}

		// 5. O rastro da corredora: come a agua por onde passa e deixa a faixa
		// molhada.
		float larg_px = max(1.0, trilha_larg * tpm);
		for (int i = 0; i < MAX_TRILHAS; i++) {
			if (i >= n_trilhas) {
				break;
			}
			vec4 t = trilha[i];
			float d = dist_segmento(px, t.xy * tamanho_mapa, t.zw * tamanho_mapa);
			float f = smoothstep(larg_px, larg_px * 0.35, d);
			if (f > 0.0) {
				cob = mix(cob, cob * 0.12, f);
				filme = max(filme, f * 0.8);
			}
		}

		// 6. Embacado, do lado de dentro (ver `psx_agua_sim`).
		embaca += (umidade - embaca) * dt / max(tempo_embacar, 0.05);
		if (dados.w > 0.5 && desembacador > 0.0) {
			float x = (m.x / max(dados.x, 0.01) - 0.5) * 2.0;
			float d = 1.0 - clamp(m.y / max(dados.y, 0.01), 0.0, 1.0);
			float alcance = desembacador * (0.30 + 0.70 * (1.0 - x * x));
			float forca = 1.0 - smoothstep(alcance * 0.65, alcance, d);
			embaca -= forca * dt * 0.8;
		}

		COLOR = vec4(clamp(cob, 0.0, 1.0), clamp(filme, 0.0, 1.0),
			clamp(embaca, 0.0, 1.0), 1.0);
	}
}

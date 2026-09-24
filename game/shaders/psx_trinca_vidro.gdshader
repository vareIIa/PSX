// A trinca de um vidro de carro, desenhada por cima dele, por dentro.
//
// Uma lamina colada meio centimetro para dentro do vidro (a malha e o
// proprio contorno da janela, ver `TrincaDeVidro`), com UV em METROS no plano
// dele. O desenho e todo procedural e cresce com `cresce` (0 a 1): as trincas
// radiais saem do ponto de impacto uma atras da outra, cada uma com o seu
// atraso, e a teia de aneis liga uma radial a vizinha so depois que as duas
// passaram daquele raio — e assim que vidro temperado e laminado quebram,
// e e o que faz a trinca ANDAR em vez de aparecer.
//
// O que se ve em cada fio:
//   - refracao: a imagem atras do vidro anda para os lados perto do fio (o
//     vidro partido nao esta mais no mesmo plano dos dois lados);
//   - o fio em si: uma linha clara e fina, mais grossa perto do impacto;
//   - brilho: cada caco tem uma normal um pouco torta, e o caco que pega a luz
//     (o farol, o fogo) acende inteiro, em lasca;
//   - agua: a chuva do vidro entra no fio e desce por ele, um filete que escorre
//     pela trinca e para nas junções.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;

// Onde o vidro levou a pancada, em metros no plano da lamina.
uniform vec2 impacto = vec2(0.0);
// 0 nada, 1 a trinca inteira.
uniform float cresce : hint_range(0.0, 1.0) = 0.0;
// Ate onde a trinca chega, em metros, com `cresce` 1.
uniform float alcance = 0.55;
// Quantas trincas radiais, e a semente. O angulo, o comprimento (fracao do
// alcance) e o atraso de cada radial vem de fora (`TrincaDeVidro`): a agua do
// vidro (`AguaCorredoras`) corre pelos MESMOS fios, e sorteio de GPU nao bate
// com o da CPU.
uniform float radiais = 23.0;
uniform float semente = 7.0;
uniform float angulos[32];
uniform float comprimentos[32];
uniform float atrasos[32];
// O miolo estilhacado em volta do impacto, em metros.
uniform float miolo = 0.045;
// A cor da luz que pega nos cacos (o farol, o fogo) e quanto.
uniform vec4 luz : source_color = vec4(1.0, 0.85, 0.7, 1.0);
uniform float brilho = 0.6;
// A agua escorrendo pelas trincas (0 seco).
uniform float agua = 0.8;
// Opacidade das linhas.
uniform float forca_fio = 0.75;

float h1(float n) { return fract(sin(n * 12.9898 + semente * 78.233) * 43758.5453); }
vec2 h2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))) + semente;
	return fract(sin(p) * 43758.5453);
}

// Distancia ao segmento ab.
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float t = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
	return length(pa - ba * t);
}

// O angulo da radial `k`, torto: nenhuma trinca e reta nem igualmente espacada.
float ang(float k) {
	return angulos[int(k)];
}

// O ponto da radial `k` a raio `r`: anda torta, com dois zigue-zagues.
vec2 ponto_radial(float k, float r) {
	float a = ang(k) + sin(r * 31.0 + k * 1.7) * 0.035 + sin(r * 9.0 + k) * 0.05
		+ (h1(k + 3.0) - 0.5) * r * 0.25;
	return vec2(cos(a), sin(a)) * r;
}

// Quanto a radial `k` ja andou (m): cada uma parte com atraso e tem o proprio
// comprimento, e as de indice par sao as longas.
float andou(float k) {
	float atraso = atrasos[int(k)];
	float c = clamp((cresce - atraso) / (1.0 - atraso), 0.0, 1.0);
	c = 1.0 - (1.0 - c) * (1.0 - c);
	return alcance * comprimentos[int(k)] * c;
}

void fragment() {
	vec2 p = UV - impacto;
	float r = length(p);
	float a = atan(p.y, p.x);
	if (a < 0.0) a += TAU;

	// A radial deste setor e as duas vizinhas: basta olhar tres.
	float k0 = floor(a / TAU * radiais);
	float d_fio = 1e3;
	float d_anel = 1e3;
	for (int i = -1; i <= 1; i++) {
		float k = mod(k0 + float(i) + radiais, radiais);
		float lim = andou(k);
		// A radial como polilinha de 8 trechos ate onde ja andou.
		vec2 ant = ponto_radial(k, miolo * 0.5);
		for (int j = 1; j <= 8; j++) {
			float rr = mix(miolo * 0.5, lim, float(j) / 8.0);
			vec2 q = ponto_radial(k, rr);
			d_fio = min(d_fio, seg(p, ant, q) / mix(1.0, 0.45, clamp(rr / alcance, 0.0, 1.0)));
			ant = q;
		}
		// A teia: cordas entre a radial k e a k+1 a raios sorteados. So existe
		// onde as duas ja chegaram.
		float k2 = mod(k + 1.0, radiais);
		float lim2 = min(lim, andou(k2));
		for (int j = 0; j < 4; j++) {
			float rr = miolo + (0.03 + float(j) * 0.07 + h1(k * 3.0 + float(j)) * 0.05);
			if (rr < lim2 && h1(k * 7.0 + float(j)) < 0.72) {
				vec2 a1 = ponto_radial(k, rr);
				vec2 a2 = ponto_radial(k2, rr * mix(0.85, 1.15, h1(k + float(j) * 2.0)));
				d_anel = min(d_anel, seg(p, a1, a2));
			}
		}
	}

	// O miolo: cacos miudos (celulas de Voronoi) com a borda clara.
	float d_caco = 1e3;
	vec2 id_caco = vec2(0.0);
	if (r < miolo * 1.6 && cresce > 0.02) {
		vec2 g = p / 0.012;
		vec2 gi = floor(g);
		float m1 = 1e3, m2 = 1e3;
		for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec2 c = gi + vec2(float(x), float(y));
			vec2 o = c + h2(c);
			float d = length(g - o);
			if (d < m1) { m2 = m1; m1 = d; id_caco = c; } else if (d < m2) { m2 = d; }
		}
		d_caco = (m2 - m1) * 0.012 * 0.5 / smoothstep(miolo * 1.6, 0.0, r);
	}

	// Fio de vidro partido e fino: um pixel, e mais nada, em qualquer distancia.
	// A espessura em metros so conta perto do impacto, onde o vidro esfarelou.
	float px = fwidth(r);
	float fio = smoothstep(px * 1.1, 0.0, d_fio - 0.00008);
	float anel = smoothstep(px * 0.9, 0.0, d_anel) * 0.7;
	float caco = smoothstep(px * 0.9, 0.0, d_caco) * 0.8;
	float linha = max(max(fio, anel), caco);

	// O caco em que o pixel esta: por setor e por anel. Normal torta dele.
	float anel_id = floor((r - miolo) / 0.075);
	float cid = k0 * 13.0 + anel_id * 7.0 + id_caco.x * 3.0 + id_caco.y;
	vec2 torto = (vec2(h1(cid), h1(cid + 1.7)) - 0.5) * step(0.001, cresce)
		* step(r, alcance * cresce * 1.05 + miolo);
	// Refracao: perto do fio a imagem desliza; dentro do caco, um pouco.
	vec2 desvia = torto * 0.004 + torto * 0.02 * max(fio, anel);
	vec3 atras = textureLod(tela, SCREEN_UV + desvia, 0.0).rgb;
	vec3 base = textureLod(tela, SCREEN_UV, 0.0).rgb;

	// Brilho: o caco cuja normal torta aponta para a luz acende em lasca.
	float lasca_luz = pow(clamp(0.5 + dot(torto, vec2(0.7, 0.7)) * 1.6, 0.0, 1.0), 6.0);
	lasca_luz *= brilho * step(0.001, length(torto));
	// Agua: um filete descendo por dentro do fio. A lamina e montada com +y
	// para CIMA, entao escorrer e a fase andando com y crescendo no tempo.
	float escorre = 0.0;
	if (agua > 0.0) {
		float fase = fract(UV.y * 5.0 + TIME * 0.35 + h1(k0) );
		escorre = smoothstep(0.0, 0.08, fase) * smoothstep(0.35, 0.1, fase)
			* fio * agua;
	}

	vec3 cor = mix(base, atras, clamp(length(torto) * 4.0, 0.0, 1.0));
	cor += luz.rgb * lasca_luz * 0.18;
	// O fio nao e tinta branca: e a borda do vidro partido, que devolve a luz
	// que ja passa ali (mais clara que o que esta atras) e acende quando pega
	// luz de frente. Em fundo escuro ele e um risco cinza-claro, nao um raio.
	vec3 cor_fio = atras * 1.35 + vec3(0.16, 0.17, 0.19) + luz.rgb * lasca_luz * 0.6 * brilho;
	cor = mix(cor, cor_fio, linha * forca_fio);
	cor += vec3(0.35, 0.38, 0.42) * escorre;
	ALBEDO = cor;
	float mostra = step(0.001, cresce) * smoothstep(alcance * 1.1 + miolo, alcance * 0.6, r);
	// So o fio e o brilho do caco pesam: um veu no caco inteiro redesenhava a
	// tela de antes da agua do vidro por cima dela, e cada caco virava uma
	// placa cinza de borda reta.
	ALPHA = clamp(mostra * (linha * 0.85 + lasca_luz * 0.06), 0.0, 1.0);
}

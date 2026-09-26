// A agua NO vidro, em metros, com memoria, com luz e com reacao.
//
// O defeito que esta versao tira (25/09/2026)
// -------------------------------------------
// A anterior (guardada em `psx_vidro_agua_antiga.gdshader`, `--agua-antiga`)
// lia como PLASTICO-BOLHA: tres grades de gotas redondas, uma gota por celula,
// todas as celulas acesas com a cobertura cheia; cada gota com anel escuro e um
// brilho azulado somado por cima. O vidro inteiro virava um tapete uniforme de
// bolinhas cinzentas que tapava a cara dos padres.
//
// O que o olho reconhece como chuva em vidro, a noite
// ---------------------------------------------------
//   DISTRIBUICAO  muita microgota, pouca gota grande, e as grandes em cacho:
//                 um campo de densidade (ruido de 16 e 6 cm) decide onde o vidro
//                 esta encharcado e onde esta quase seco. Quatro camadas de
//                 0,3 a 10 mm, cada uma numa grade girada, com o raio sorteado
//                 puxado para o pequeno; a grande e um borrao de dois lobos.
//   LENTE         a gota nao e mancha: e uma lente que mostra o mundo de tras
//                 INVERTIDO e encolhido. A amostra da tela sai do centro da gota
//                 para o lado oposto (`lente_k`), convertida de metros de vidro
//                 para pixels pela jacobiana da propria placa.
//   LUZ           o shader deixou de ser `unshaded`: `light()` acende em cada
//                 gota o ponto do fogo do capo e da luz vermelha do painel. Luz
//                 atras do vidro vira o brilho que a gota FOCA (transmissao);
//                 luz do lado de dentro vira reflexo na calota.
//   PELICULA      a lamina fina (rastro, palheta, pancada) entorta pouco o mundo.
//   SEM CONTORNO  o escurecimento da borda existe so onde a gota tem pixel para
//                 ele, e e fraco: a borda de uma gota de verdade acende com a luz
//                 muito mais do que escurece.
//
// A reacao (`AguaCorredoras.impacto`)
// -----------------------------------
//   ONDA      cada pancada abre um anel que corre na pelicula (`impacto_*`),
//             entorta o mundo e empurra as gotas que ele atravessa;
//   TREMOR    as gotas perto da pancada tremem, e todas balancam com a
//             carroceria (`sacode[painel]`, uma mola por vidro na CPU);
//   ROSA      o segundo mapa e o sangue diluido que escorre das marcas.
//
// O que vem da malha (`VidroCabine`)
// ----------------------------------
//   UV     posicao no mapa de agua        UV2  metros no plano, `v` morro abaixo
//   COLOR  r = limpador, g = tipo, (b,a) = tamanho do vidro / ESCALA_TAM
shader_type spatial;
render_mode blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled,
	ambient_light_disabled, fog_disabled;

// O mundo atras do vidro: so o que e opaco. Com mipmap: o nivel alto e o
// desfoque do embacado e o halo que a agua espalha em volta da luz forte.
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

// O mapa de agua: R cobertura, G filme, B embacado. Ver `AguaVidro`.
uniform sampler2D mapa : repeat_disable, filter_linear;
uniform bool usa_mapa = false;
// O sangue diluido na agua (R), no segundo mapa (`psx_agua_rosa`).
uniform sampler2D mapa_rosa : repeat_disable, filter_linear;
uniform bool usa_rosa = false;
// Cobertura de reserva, para quem desenha o vidro sem mapa (vitrine, teste).
uniform float cobertura : hint_range(0.0, 1.0) = 0.0;

// Estilo em vigor (MODERNO liga). Ver `EstiloVisual`.
global uniform bool psx_facho_suave;

// Esta caindo chuva AGORA, de 0 a 1. O vidro ja molhado nao seca com ela: quem
// guarda a agua e o mapa.
uniform float intensidade : hint_range(0.0, 1.0) = 0.0;
// Quanto o ar empurra a agua, de 0 a 1 — escrito da velocidade do carro.
uniform float vento : hint_range(0.0, 1.0) = 0.0;

// Tom do embacado (frio: e o ceu encoberto que o vapor devolve).
uniform vec4 cor : source_color = vec4(0.80, 0.85, 0.90, 1.0);
// Embacado minimo, mesmo com o mapa zerado.
uniform float embacado : hint_range(0.0, 1.0) = 0.06;
// Quanto o vidro LIMPO aparece. O reflexo de nada que diz que ha vidro ali.
uniform float vidro_seco : hint_range(0.0, 0.3) = 0.02;

// --- As gotas -----------------------------------------------------------------
//
// Lente: quantas vezes o raio da gota ela "enxerga" para o lado oposto. Com 1 a
// gota nao desvia nada; acima de 1 a imagem inverte, e o miolo mostra, de cabeca
// para baixo, um pedaco do mundo `lente_k` vezes maior que ela.
uniform float lente_k : hint_range(1.0, 6.0) = 3.1;
// Tamanho de todas as camadas (1 = 0,3 a 10 mm de diametro).
uniform float gota_escala : hint_range(0.3, 3.0) = 1.0;
// Quanto do vidro cheio vira gota: multiplica a probabilidade de cada celula.
uniform float densidade : hint_range(0.0, 2.0) = 1.0;
// Escurecimento da borda (reflexao interna). Fraco de proposito: ver o cabecalho.
uniform float borda_escura : hint_range(0.0, 1.0) = 0.28;
// Separacao de cor na lente, em fracao do desvio.
uniform float dispersao : hint_range(0.0, 0.2) = 0.035;
// Brilho das luzes nas gotas (`light()`): reflexo e transmissao.
uniform float brilho_luz : hint_range(0.0, 8.0) = 1.6;
uniform float dureza_reflexo : hint_range(8.0, 1024.0) = 220.0;
uniform float dureza_foco : hint_range(8.0, 2048.0) = 480.0;
// Luz forte atras da gota a acende: a gota junta a luz do fundo.
uniform float limiar_brilho : hint_range(0.0, 2.0) = 0.45;
uniform float brilho_fundo : hint_range(0.0, 6.0) = 1.4;
// Halo: a microgota espalha a luz forte do fundo pelo vidro em volta dela.
uniform float halo : hint_range(0.0, 2.0) = 0.3;

// PS1: a lente velha, em metros de vidro, e a escala de gota por estilo.
uniform float refracao : hint_range(0.0, 0.05) = 0.010;

// --- Fase 5: optica (sujeira, leque, embacado) ---------------------------------

uniform float sujeira : hint_range(0.0, 0.5) = 0.16;
uniform vec4 cor_sujeira : source_color = vec4(0.46, 0.43, 0.37, 1.0);
uniform bool tem_leque = false;
uniform vec2 leque_a = vec2(0.0);
uniform vec2 leque_b = vec2(0.0);
uniform vec2 leque_raios = vec2(0.10, 0.50);
uniform vec2 leque_angulos = vec2(-1.0, 1.0);
// Raio do desfoque do embacado com o vidro embacado de todo, em pixels da grade
// de 270 linhas (convertido para a tela de verdade).
uniform float desfoque_px : hint_range(0.0, 8.0) = 3.5;
uniform float borda_max : hint_range(0.0, 0.5) = 0.12;
// Quanto do embacado vira veu por cima da agua (o resto e so desfoque).
uniform float nevoa_forca : hint_range(0.0, 1.0) = 0.72;

// 0 desligado, 1 mapa cru, 2 cobertura, 3 filme, 4 embacado, 5 sujeira, 6 rosa,
// 7 gotas (a mascara). Ver `--dbg-agua`.
uniform int depurar = 0;
// A janela que estourou: a caixa (espaco do carro) onde o vidro nao existe
// mais. `buraco_max` abaixo de `buraco_min` e caixa vazia.
uniform vec3 buraco_min = vec3(0.0);
uniform vec3 buraco_max = vec3(-1.0);

// --- A reacao (escrito por `AguaCorredoras`) ------------------------------------

const int MAX_PAINEIS = 10;
const int MAX_ONDAS = 4;
// O relogio da agua (s): o mesmo das pancadas, e nao `TIME`, que na rodada de
// captura anda no relogio de parede.
uniform float agora = 0.0;
uniform int n_paineis = 0;
// O retangulo de cada vidro no mapa: e por ele que o vertice sabe de que vidro
// e, para ler a onda e o balanco certos.
uniform vec4 painel_rect[MAX_PAINEIS];
// Por vidro: deslocamento da agua pelo balanco (m) em xy, tremor (0 a 1) em z.
uniform vec4 sacode[MAX_PAINEIS];
// As pancadas recentes: (u, v em metros, instante, forca) e (vidro, 0, 0, 0).
uniform vec4 onda_a[MAX_ONDAS];
uniform vec4 onda_b[MAX_ONDAS];
// A frente da onda anda isto (m/s) e ela morre com esta constante (1/s).
uniform float onda_vel = 0.85;
uniform float onda_some = 3.2;

varying vec3 no_carro;
varying vec2 metros;
varying vec2 uv_mapa;
varying vec2 tam_vidro;
varying float tem_limpador;
varying float tipo;
varying flat int painel;

// Do fragmento para a luz.
varying float v_brilho;
varying float v_lente;
varying vec3 v_normal_vidro;

const float ESCALA_TAM = 8.0;
// No PS1 STYLE a gota e desenhada 2,5 vezes maior (a 480x270 a gota de 1 cm
// tem 2,5 px). Ver a versao antiga para a medida.
const float ESCALA_GOTA_PS1 = 2.5;
const float ALTURA_BASE = 270.0;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);


float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}


// Ruido de valor, suave.
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}


void vertex() {
	no_carro = VERTEX;
	metros = UV2;
	uv_mapa = UV;
	tem_limpador = COLOR.r;
	tipo = COLOR.g;
	tam_vidro = COLOR.ba * ESCALA_TAM;
	painel = -1;
	for (int i = 0; i < MAX_PAINEIS; i++) {
		if (i >= n_paineis) {
			break;
		}
		vec4 r = painel_rect[i];
		vec2 f = (UV - r.xy) / max(r.zw, vec2(1e-6));
		if (f.x > -0.02 && f.y > -0.02 && f.x < 1.02 && f.y < 1.02) {
			painel = i;
			break;
		}
	}
}


// Uniao macia de duas distancias, e o peso de cada uma (para a normal).
float uniao(float a, float b, float k, out float peso_a) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	peso_a = h;
	return mix(b, a, h) - k * h * (1.0 - h);
}


// Uma camada de gotas paradas.
//
// `lado` e a celula (m), `giro` o angulo da grade, `prob` a chance de a celula
// ter gota, `faixa` o raio minimo e maximo em fracao da celula, `lobulo` a chance
// de a gota ser um borrao de dois lobos. `mexe` e o deslocamento do balanco (m) e
// `treme` o tremor da pancada.
//
// Devolve, por inout, a gota que ganha este ponto (a mais alta aqui): cobertura,
// o vetor do centro ate o ponto (m), o raio (m) e a altura. O que e pequeno
// demais para ter pixel vira `fina` (a nevoa de microgota), e nao grao.
void camada(vec2 m, float lado, float giro, float semente, float prob, vec2 faixa,
		float lobulo, vec2 mexe, float treme, float px_m, float cheio,
		inout float cobre, inout vec2 centro_ate, inout float raio_g,
		inout float alto, inout float fina, inout float perto_de_grande,
		inout float curva) {
	float cg = cos(giro);
	float sg = sin(giro);
	mat2 gira = mat2(vec2(cg, sg), vec2(-sg, cg));
	vec2 q = (gira * m) / lado + vec2(semente * 7.13, semente * 3.71);
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float h0 = hash21(id + semente * 1.7);
	if (h0 < prob) {
		float s = hash21(id * 1.37 + semente * 3.1);
		// Puxado para o pequeno: s^2 poe metade das gotas no quarto de baixo da
		// faixa. A gota cresce com a cobertura: ela e agua que se juntou.
		float raio = mix(faixa.x, faixa.y, s * s) * mix(0.62, 1.0, cheio);
		// Quanto a celula balanca: a gota grande sente, a pequena a tensao
		// superficial segura.
		float pesa = smoothstep(0.0012, 0.004, raio * lado);
		vec2 balanco = (gira * mexe) / lado * pesa;
		float fase = hash21(id + 41.3) * 6.2831;
		balanco += vec2(sin(agora * 83.0 + fase), cos(agora * 71.0 + fase * 1.3))
			* treme * raio * 0.22 * (0.4 + pesa);
		vec2 j = (vec2(hash21(id + 11.1), hash21(id + 23.7)) - 0.5) * 2.0
			* max(0.0, 0.5 - raio * 1.45);
		vec2 d = f - j - balanco;
		// O peso achata a grande: mais cheia embaixo (+v, que na grade girada e
		// o `gira` de (0, 1)).
		vec2 baixo = gira * vec2(0.0, 1.0);
		float ao_baixo = dot(d, baixo);
		vec2 dp = d + baixo * ao_baixo * ((ao_baixo > 0.0) ? 0.18 : -0.10) * pesa;
		float sdf = length(dp) - raio;
		vec2 dir = dp / max(length(dp), 1e-5);
		float r_ef = raio;
		if (lobulo > 0.0 && hash21(id + 31.3) < lobulo) {
			float a2 = hash21(id + 57.1) * 6.2831;
			vec2 c2 = vec2(cos(a2), sin(a2)) * raio * 0.72;
			float r2 = raio * mix(0.50, 0.80, hash21(id + 63.9));
			vec2 d2 = dp - c2;
			float peso;
			sdf = uniao(sdf, length(d2) - r2, raio * 0.45, peso);
			dir = normalize(mix(d2 / max(length(d2), 1e-5), dir, peso) + vec2(1e-5));
			r_ef = raio * 1.08;
		}
		float sdf_m = sdf * lado;
		float r_m = r_ef * lado;
		float aa = 0.75 / max(px_m, 1.0);
		float c = smoothstep(aa, -aa, sdf_m);
		// O que a gota grande seca em volta dela: a microgota ali foi engolida.
		perto_de_grande = max(perto_de_grande,
			smoothstep(r_m * 1.9, r_m * 1.05, sdf_m + r_m) * step(0.0025, r_m));
		if (c > 0.0) {
			float r_px = r_m * px_m;
			// Menor que pixel e meio: sem lente (seria grao), vira nevoa fina.
			float lente = smoothstep(0.8, 2.2, r_px);
			fina += c * (1.0 - lente);
			c *= lente;
			float rho = clamp(1.0 + sdf / max(r_ef, 1e-5), 0.0, 1.0);
			float h = r_m * sqrt(max(0.0, 1.0 - rho * rho));
			if (c > 0.0 && h * c >= alto) {
				alto = h * c;
				cobre = max(cobre, c);
				// O vetor do centro da lente ate o ponto, de volta aos metros
				// sem giro.
				centro_ate = (transpose(gira) * dir) * rho * r_m;
				raio_g = r_m;
				// Cada gota com o seu angulo de contato: o ponto de luz nao cai
				// no mesmo lugar em todas.
				curva = mix(0.65, 1.35, hash21(id + 77.7));
			} else {
				cobre = max(cobre, c);
			}
		}
	}
}


// Quanto da sujeira existe aqui, de 0 a 1, em METROS.
float poeira(vec2 m) {
	float grande = ruido(m * 9.0 + vec2(3.7, 1.1));
	float grao = ruido(m * 40.0);
	float escorrido = ruido(vec2(m.x * 55.0, m.y * 6.0) + vec2(11.0, 0.0));
	return clamp(grande * 0.55 + grao * 0.25 + escorrido * 0.35 - 0.25, 0.0, 1.0);
}


float no_leque(vec2 m, vec2 pivo) {
	vec2 d = m - pivo;
	float r = length(d);
	float raio = smoothstep(leque_raios.x - 0.01, leque_raios.x + 0.02, r)
		* smoothstep(leque_raios.y + 0.012, leque_raios.y - 0.03, r);
	float ang = atan(d.x, -d.y) + (ruido(vec2(r * 30.0, 4.0)) - 0.5) * 0.05;
	float dentro = smoothstep(leque_angulos.x - 0.04, leque_angulos.x + 0.03, ang)
		* smoothstep(leque_angulos.y + 0.04, leque_angulos.y - 0.03, ang);
	return raio * dentro;
}


void fragment() {
	if (all(greaterThan(no_carro, buraco_min)) && all(lessThan(no_carro, buraco_max))) {
		discard;
	}
	vec2 m = metros;
	bool moderno = psx_facho_suave;
	// A janela lateral nao tem palheta nem vento de frente: a agua junta em gota
	// maior. E ela e vista de mais longe (a do carona a 1,3 m): com a gota do
	// para-brisa ela virava so nevoa de microgota (captura de 25/09, 39 s).
	bool lateral = tipo > 0.25 && tipo < 0.75;
	float escala = gota_escala * (moderno ? 1.0 : ESCALA_GOTA_PS1) * (lateral ? 1.3 : 1.0);

	// O estado deste ponto do vidro.
	vec4 estado = vec4(cobertura, 0.0, embacado, 0.0);
	if (usa_mapa) {
		estado = texture(mapa, uv_mapa);
	}
	float cob = clamp(estado.r, 0.0, 1.0);
	float filme = clamp(estado.g, 0.0, 1.0);
	float embaca = clamp(max(estado.b, embacado), 0.0, 1.0);
	float rosa = usa_rosa ? clamp(texture(mapa_rosa, uv_mapa).r, 0.0, 1.0) : 0.0;

	// Metros de vidro -> pixels, pela jacobiana da placa. O vidro inclinado a
	// 60 graus encolhe a gota num eixo so: um fator escalar faria a lente de um
	// para-brisa deitado mirar errado.
	vec2 dmx = dFdx(m);
	vec2 dmy = dFdy(m);
	float det = dmx.x * dmy.y - dmy.x * dmx.y;
	det = (abs(det) < 1e-14) ? 1e-14 : det;
	mat2 m_px = mat2(vec2(dmy.y, -dmx.y), vec2(-dmy.x, dmx.x)) / det;
	float px_m = inversesqrt(abs(det));

	// --- A reacao: onda das pancadas, tremor e balanco -------------------------
	vec2 mexe = vec2(0.0);
	float treme = 0.0;
	vec2 onda_inclina = vec2(0.0);
	float onda_crista = 0.0;
	// A agua jogada no instante da pancada: lamina revolta em volta do ponto.
	float revolta = 0.0;
	if (painel >= 0) {
		vec4 sc = sacode[painel];
		mexe = sc.xy;
		treme = sc.z;
		for (int i = 0; i < MAX_ONDAS; i++) {
			vec4 oa = onda_a[i];
			if (int(onda_b[i].x + 0.5) != painel || oa.w <= 0.0) {
				continue;
			}
			float t = agora - oa.z;
			if (t < 0.0 || t > 2.5) {
				continue;
			}
			vec2 d = m - oa.xy;
			float r = length(d);
			vec2 dir = d / max(r, 1e-4);
			float amp = oa.w * exp(-t * onda_some);
			// A frente anda e alarga; atras dela a pelicula ainda oscila.
			float frente = onda_vel * t;
			float largura = 0.012 + 0.05 * t;
			float x = r - frente;
			float env = exp(-x * x / (largura * largura));
			float lambda = 0.016 + 0.012 * t;
			float fase = x * 6.2831 / lambda;
			float incl = amp * env * (cos(fase) - 0.6 * x / largura * sin(fase));
			onda_inclina += dir * incl * 0.55;
			onda_crista = max(onda_crista, amp * env);
			// A onda empurra a gota que ela atravessa e a solta de volta.
			mexe += dir * amp * env * sin(fase) * 0.0022;
			// Perto da pancada a agua treme de verdade.
			treme = max(treme, oa.w * exp(-t * 5.0) * exp(-r / 0.10));
			float r_revolta = 0.05 + 0.10 * oa.w + 0.25 * t;
			revolta = max(revolta, oa.w * exp(-t * 7.0)
				* (1.0 - smoothstep(r_revolta * 0.4, r_revolta, r)));
		}
	}

	// --- As gotas paradas --------------------------------------------------------
	//
	// O campo de densidade: onde o vidro esta encharcado e onde esta quase seco.
	// Duas escalas (16 e 6 cm), e uma terceira (2 cm) so para a gota grande
	// fazer cacho.
	float n1 = ruido(m * 6.2 + vec2(1.3, 7.7));
	float n2 = ruido(m * 17.0 + vec2(5.1, 2.9));
	float n3 = ruido(m * 47.0 + vec2(9.4, 4.2));
	float campo = clamp(0.52 + 1.05 * (n1 - 0.5) + 0.55 * (n2 - 0.5), 0.0, 1.0);
	// A cobertura enche primeiro de micro, depois de pequena, e so com o vidro
	// cheio aparece a grande.
	float cheio = smoothstep(0.0, 1.0, cob);
	float d_fina = densidade * mix(0.40, 0.92, campo) * smoothstep(0.02, 0.35, cob);
	float d_peq = densidade * mix(0.18, 0.72, campo) * smoothstep(0.10, 0.60, cob);
	float d_med = densidade * smoothstep(0.30, 0.85, campo) * (lateral ? 0.72 : 0.55)
		* smoothstep(0.30, 0.80, cob);
	float d_grd = densidade * smoothstep(0.50, 0.92, campo * 0.72 + n3 * 0.28) * 0.60
		* smoothstep(0.55, 0.95, cob);

	float cobre = 0.0;
	vec2 centro_ate = vec2(0.0);
	float raio_g = 0.001;
	float alto = 0.0;
	float fina = 0.0;
	float seco_perto = 0.0;
	float curva = 1.0;
	if (cob > 0.01) {
		vec2 mg = m / escala;
		float pxg = px_m * escala;
		// Grande primeiro: ela decide onde a pequena foi engolida.
		camada(mg, 0.0150, 0.61, 1.0, d_grd, vec2(0.17, 0.31), 0.55, mexe / escala,
			treme, pxg, cheio, cobre, centro_ate, raio_g, alto, fina, seco_perto, curva);
		camada(mg, 0.0062, 1.37, 2.0, d_med, vec2(0.15, 0.38), 0.25, mexe / escala,
			treme, pxg, cheio, cobre, centro_ate, raio_g, alto, fina, seco_perto, curva);
		float engolida = 1.0 - 0.85 * seco_perto;
		camada(mg, 0.0027, 2.21, 3.0, d_peq * engolida, vec2(0.12, 0.38), 0.0,
			mexe / escala * 0.4, treme, pxg, cheio, cobre, centro_ate, raio_g, alto,
			fina, seco_perto, curva);
		if (moderno) {
			camada(mg, 0.0011, 0.93, 4.0, d_fina * engolida, vec2(0.14, 0.36), 0.0,
				vec2(0.0), treme * 0.5, pxg, cheio, cobre, centro_ate, raio_g, alto,
				fina, seco_perto, curva);
		}
		raio_g *= escala;
		centro_ate *= escala;
	}
	fina = clamp(fina, 0.0, 1.0);
	// A nevoa de microgota: o que sobra do vidro molhado entre as gotas.
	float nevoa_agua = clamp(fina * 0.8 + cheio * campo * 0.18, 0.0, 1.0);

	// --- A normal da agua --------------------------------------------------------
	float rho = clamp(length(centro_ate) / max(raio_g, 1e-5), 0.0, 1.0);
	vec2 dir_g = centro_ate / max(length(centro_ate), 1e-6);
	// Calota com angulo de contato de ~65 graus: a inclinacao vai a 2,1 na borda.
	float incl_gota = rho * 2.1 * curva / sqrt(max(0.08, 1.0 - rho * rho * 0.82));
	// O filme ondula correndo morro abaixo: a lamina que a palheta e a corredora
	// deixam, e a que a pancada espalha.
	vec2 filme_incl = vec2(
		ruido(vec2(m.x * 70.0, m.y * 22.0 - TIME * 1.6)) - 0.5,
		ruido(vec2(m.x * 31.0 + 4.0, m.y * 55.0 - TIME * 2.3)) - 0.5) * 0.9;
	vec2 revolto = vec2(
		ruido(m * 160.0 + vec2(agora * 9.0, 0.0)) - 0.5,
		ruido(m * 160.0 + vec2(3.3, agora * 11.0)) - 0.5) * 3.0;
	vec2 inclina = dir_g * incl_gota * cobre
		+ filme_incl * filme * (1.0 - cobre)
		+ onda_inclina
		+ revolto * revolta * (1.0 - cobre);
	// No espaco do vidro, com z para o OLHO: a normal que vai para `light()`.
	vec3 nb = normalize(vec3(-inclina, 1.0));
	vec3 n_visao = normalize(TANGENT * nb.x + BINORMAL * nb.y + NORMAL * nb.z);

	// --- O desvio da tela ----------------------------------------------------------
	// A lente: a amostra sai do centro da gota para o lado oposto, `lente_k`
	// vezes, e mais na borda (onde a calota e mais inclinada).
	float k_lente = lente_k * mix(1.15, 0.85, smoothstep(0.001, 0.005, raio_g));
	vec2 desvio_m = -centro_ate * k_lente * (1.0 + 0.55 * rho * rho) * cobre;
	// Pelicula e onda: poucos milimetros.
	desvio_m += -(filme_incl * filme * (1.0 - cobre) * 0.0035 + onda_inclina * 0.0030
		+ revolto * revolta * (1.0 - cobre) * 0.006);
	vec2 desvio = (m_px * desvio_m) / VIEWPORT_SIZE;
	// A refracao some na borda do vidro: perto dela a lente amostraria a coluna
	// e o forro, que a camera ve mas o vidro de verdade nao.
	vec2 borda = abs(m / max(tam_vidro, vec2(0.01)) - 0.5) * 2.0;
	float canto = smoothstep(0.45, 1.0, max(borda.x, borda.y));
	desvio *= 1.0 - smoothstep(0.93, 0.998, max(borda.x, borda.y));
	float tam_desvio = length(desvio);
	if (tam_desvio > 0.07) {
		desvio *= 0.07 / tam_desvio;
	}
	if (!moderno) {
		desvio = floor(desvio * vec2(480.0, 270.0)) / vec2(480.0, 270.0);
	}
	// O vidro visto de frente ou de costas: a normal que olha para a lente.
	vec3 n_olho = NORMAL * (dot(NORMAL, -VERTEX) < 0.0 ? -1.0 : 1.0);
	if (!atras_do_vidro(SCREEN_UV + desvio * (1.0 + dispersao), VERTEX, n_olho,
			INV_PROJECTION_MATRIX)) {
		// Meio caminho ainda cabe atras do vidro? Senao, sem desvio.
		desvio *= 0.4;
		if (!atras_do_vidro(SCREEN_UV + desvio * (1.0 + dispersao), VERTEX, n_olho,
				INV_PROJECTION_MATRIX)) {
			desvio *= 0.0;
		}
	}
	vec2 uv_visto = clamp(SCREEN_UV + desvio, vec2(0.001), vec2(0.999));

	// A imagem na gota e um pouco mole: a lente de verdade nao esta no foco do
	// olho que olha a estrada.
	float r_px_g = raio_g * px_m;
	float lod_gota = moderno ? clamp(log2(max(r_px_g, 1.0)) * 0.45 - 1.2, 0.0, 1.8) : 0.0;
	vec3 mundo = textureLod(tela, uv_visto, lod_gota * cobre).rgb;
	if (moderno && cobre > 0.01 && dispersao > 0.0) {
		vec2 uv_r = clamp(SCREEN_UV + desvio * (1.0 - dispersao), vec2(0.001), vec2(0.999));
		vec2 uv_b = clamp(SCREEN_UV + desvio * (1.0 + dispersao), vec2(0.001), vec2(0.999));
		mundo = vec3(textureLod(tela, uv_r, lod_gota).r, mundo.g,
			textureLod(tela, uv_b, lod_gota).b);
	}

	// --- A cor da agua -------------------------------------------------------------
	vec3 agua = mundo;
	// A gota junta a luz forte de tras: acende, e nao so deixa passar.
	float luz = dot(mundo, vec3(0.2126, 0.7152, 0.0722));
	agua += mundo * max(0.0, luz - limiar_brilho) * brilho_fundo * cobre
		* (1.0 - 0.6 * rho);
	// Reflexao interna na borda: so onde a gota tem pixel para isso.
	float tem_borda = smoothstep(5.0, 14.0, r_px_g);
	agua *= 1.0 - borda_escura * smoothstep(0.78, 1.0, rho) * cobre * tem_borda;
	// O sangue diluido: a agua passa a filtrar o mundo de vermelho, e a lamina
	// rosada espalha um pouco da luz que a atravessa.
	float tinge = clamp(rosa * 1.25, 0.0, 1.0);
	agua *= mix(vec3(1.0), vec3(1.0, 0.40, 0.36), tinge * 0.7);
	agua += vec3(0.24, 0.02, 0.02) * tinge * (0.02 + luz * 0.3);

	// Alfa da agua: a gota cobre de verdade; a pelicula, a onda e o rosa, pouco.
	float a_agua = cobre * 0.97;
	a_agua = max(a_agua, filme * 0.42);
	a_agua = max(a_agua, clamp(onda_crista * 1.6, 0.0, 0.5));
	a_agua = max(a_agua, revolta * 0.7);
	a_agua = max(a_agua, tinge * 0.62);

	// Nevoa de microgota e halo: a luz forte de tras se espalha no vidro molhado.
	vec3 fundo_mole = textureLod(tela, SCREEN_UV, 3.2).rgb;
	vec3 fundo_halo = textureLod(tela, SCREEN_UV, 5.5).rgb;
	float luz_halo = dot(fundo_halo, vec3(0.2126, 0.7152, 0.0722));
	vec3 nevoa_cor = fundo_mole * 1.02
		+ fundo_halo * max(0.0, luz_halo - 0.12) * halo * 2.0;
	float a_nevoa = moderno ? nevoa_agua * 0.14 : 0.0;
	nevoa_cor *= mix(vec3(1.0), vec3(1.0, 0.45, 0.4), tinge * 0.5);

	// Composicao pre-multiplicada: agua, nevoa por cima dos vaos, sujeira, e o
	// embacado do lado de dentro.
	vec3 c = agua * a_agua;
	float a = a_agua;
	c = nevoa_cor * a_nevoa * (1.0 - a) + c;
	a = a + a_nevoa * (1.0 - a);

	float leque = 0.0;
	if (tem_leque && tem_limpador > 0.5) {
		leque = max(no_leque(m, leque_a), no_leque(m, leque_b));
	}
	float suja = sujeira * poeira(m) * (1.0 - 0.85 * leque);
	suja *= 1.0 - 0.35 * cheio;
	vec3 cor_suja = cor_sujeira.rgb * mix(0.6, 1.0, clamp(luz + 0.3, 0.0, 1.0))
		* (0.35 + 0.65 * fundo_mole / max(vec3(0.05), vec3(luz)));
	c = cor_suja * suja + c * (1.0 - suja);
	a = suja + a * (1.0 - suja);

	// O embacado e de DENTRO e a gota de fora: ele desfoca a gota, mas nao a
	// apaga. Com o vidro lateral no equilibrio (0,45) e alfa cheio, a janela do
	// carona saia leitosa e sem agua nenhuma (captura de 25/09, 39 s).
	float nevoa = clamp(embaca * (1.0 + borda_max * canto), 0.0, 1.0) * nevoa_forca;
	float raio_desfoque = desfoque_px * (VIEWPORT_SIZE.y / ALTURA_BASE)
		* smoothstep(0.0, 0.6, embaca);
	vec3 fosco = textureLod(tela, uv_visto, log2(max(raio_desfoque, 1.0)) + 0.5).rgb;
	fosco = mix(fosco, cor.rgb * 0.55, 0.22);
	c = fosco * nevoa + c * (1.0 - nevoa);
	a = nevoa + a * (1.0 - nevoa);

	float a_seco = vidro_seco * (1.0 + borda_max * canto);
	c = textureLod(tela, SCREEN_UV, 0.0).rgb * 1.04 * a_seco * (1.0 - a) + c;
	a = a + a_seco * (1.0 - a);

	if (!moderno) {
		int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
		float pontilha = 1.0 + (BAYER[idx] / 16.0 - 0.5) * 0.45;
		c *= pontilha;
		a *= pontilha;
	}

	// A luz: `light()` le quanto este ponto brilha e o quanto ele e lente.
	// A gota de um pixel nao tem ponto de luz: tem grao. So acende a gota com
	// corpo, e a microgota contribui pouco.
	float com_corpo = smoothstep(1.4, 4.0, r_px_g);
	v_brilho = clamp(cobre * com_corpo + filme * 0.18 * (1.0 - cobre) + onda_crista * 0.8
		+ revolta * 0.3 + fina * 0.05, 0.0, 1.0) * (1.0 - nevoa * 0.45);
	v_lente = 1.1 * cobre + 0.25 * filme;
	v_normal_vidro = NORMAL;
	NORMAL = n_visao;

	ALBEDO = vec3(0.0);
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	EMISSION = c;
	ALPHA = clamp(a, 0.0, 1.0);

	if (depurar > 0) {
		vec3 dbg = vec3(0.0);
		if (depurar == 1) {
			dbg = estado.rgb;
		} else if (depurar == 2) {
			dbg = vec3(cob);
		} else if (depurar == 3) {
			dbg = vec3(filme);
		} else if (depurar == 4) {
			dbg = vec3(embaca);
		} else if (depurar == 5) {
			dbg = vec3(suja / max(sujeira, 0.001));
		} else if (depurar == 6) {
			dbg = vec3(rosa);
		} else {
			dbg = vec3(cobre, fina, filme);
		}
		EMISSION = dbg;
		ALPHA = 1.0;
		v_brilho = 0.0;
	}
}


// O brilho das luzes na agua. Nada de difuso: a agua nao tem cor propria.
//
//   luz do lado de DENTRO (o painel, a luz vermelha): reflexo na calota;
//   luz do lado de FORA (o fogo do capo): o raio do olho atravessa a gota, sai
//   desviado pela lente, e onde ele aponta para a luz a gota mostra o ponto
//   aceso — e o foco, que faz cada gota do para-brisa carregar um fogo.
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

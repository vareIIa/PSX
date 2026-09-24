// A serra do horizonte da cidade (SerraDaCidade): o que cobre o morro.
//
// A malha so traz a forma — cinco cristas em anel, presas a camera — e a
// normal de cada encosta. O resto sai daqui, por fragmento, porque a
// quilometros de distancia o que se le de um morro de Minas e a COBERTURA:
// pasto claro no alto, mata escura descendo pela grota, o risco vermelho de
// uma estrada de terra, um talhao de eucalipto, e na serra de tras a rocha
// aflorando no topo. Com cor de vertice (uma por grau) nada disso cabia.
//
// Abaixo do horizonte e o VALE: a parede do anel e lida como chao plano visto
// de cima (`ALTURA_VALE`), e o chao vira colcha de pasto com a mata ciliar do
// corrego, encolhendo em perspectiva ate sumir na bruma do pe da serra.
//
// Depois vem o ar: cada crista mais longe mais afogada na cor do fundo, e a
// sombra de nuvem que anda devagar por cima do morro e do vale.
//
// Escreve profundidade: o anel mora a 300-316 m, alem de tudo o que a cidade
// desenha e antes das estrelas, e e a profundidade que tapa a estrela atras do
// morro (ver SerraDaCidade).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

// Cor do fundo e da bruma do vale, as mesmas do preset (sRGB -> linear).
uniform vec3 fundo : source_color = vec3(0.53, 0.72, 0.92);
uniform vec3 bruma : source_color = vec3(0.56, 0.6, 0.55);
// O lado do sol ganha um pouco da cor dele no ar (espalhamento para a frente).
uniform vec3 cor_sol : source_color = vec3(1.0, 0.94, 0.77);
uniform vec3 rumo_sol = vec3(0.0, 0.6, 0.8);
// 0 com nevoa fechada (a serra some na cor do fundo), 1 com vista aberta.
uniform float vista = 1.0;
// O mesmo para o chao do vale, que e mais rigido: chao alem da nevoa nao existe.
// O morro fica como silhueta na bruma; o vale some junto com a cidade.
uniform float vista_vale = 1.0;
// Luz do dia sobre o morro: ambiente e sol. A noite os dois quase zeram.
uniform float luz_ambiente = 0.5;
uniform float luz_sol = 0.75;
// 1 a noite: a cor do chao perde a saturacao (luz de lua nao tem verde).
uniform float noite = 0.0;
// Quanto do fundo cobre cada crista, de perto (0) a de longe (4).
uniform float ar_perto = 0.22;
uniform float ar_longe = 0.72;
// Sombra de nuvem: forca e deslocamento do vento.
uniform float sombra_nuvem = 0.25;
uniform vec2 vento = vec2(0.0);
// 1 no MODERNO, menos no PS1: menos grao, a franja de copa mais grossa.
uniform float detalhe = 1.0;
// A linha do horizonte na coordenada `marca` (ver SerraDaCidade).
uniform float no_horizonte = 0.65;

uniform vec3 pasto : source_color = vec3(0.6, 0.62, 0.36);
uniform vec3 pasto_verde : source_color = vec3(0.42, 0.55, 0.28);
uniform vec3 mata : source_color = vec3(0.16, 0.27, 0.15);
uniform vec3 eucalipto : source_color = vec3(0.2, 0.3, 0.26);
uniform vec3 terra : source_color = vec3(0.66, 0.36, 0.23);
uniform vec3 campo : source_color = vec3(0.52, 0.5, 0.37);
uniform vec3 rocha : source_color = vec3(0.6, 0.59, 0.56);

// Altura de onde se olha o vale, em metros: a do mirante sobre a varzea.
const float ALTURA_VALE = 60.0;
// Distancia (m) em que o chao do vale ja tem o ar da crista de perto.
const float VALE_LONGE = 3200.0;

varying vec3 v_local;
varying vec3 v_normal;
varying float v_crista;
varying float v_marca;
varying float v_franja;

void vertex() {
	v_local = VERTEX;
	v_normal = NORMAL;
	v_crista = UV.x;
	v_marca = UV.y;
	v_franja = UV2.x;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * ruido(p);
		p = p * 2.03 + vec3(17.1, 5.3, 11.7);
		a *= 0.5;
	}
	return s / 0.9375;
}

// A copa das arvores na linha do cume: 0 = sem arvore, 1 = copa inteira. A
// franja da malha sobe um palmo acima do cume, e o que passa desta altura some.
float copa(vec3 p) {
	float grossa = mix(1.8, 1.0, detalhe);
	return ruido(p * 0.95 / grossa) * 0.65 + ruido(p * 2.3 / grossa) * 0.35;
}

// Altura (0..1) do morrote do vale, em metros no plano.
float morrote(vec2 q) {
	return ruido(vec3(q * 0.0035, 0.5)) * 0.65 + ruido(vec3(q * 0.009, 8.5)) * 0.35;
}

// O chao do vale, em metros no plano: colcha de pastos de donos diferentes,
// a mata ciliar seguindo o corrego e uma lavoura de terra arada aqui e ali.
vec3 vale(vec2 q, float dist) {
	// Cercas tortas: a grade dos pastos entortada por ruido largo.
	vec2 torta = q + vec2(fbm(vec3(q * 0.004, 1.0)), fbm(vec3(q * 0.004, 7.0))) * 160.0;
	vec2 cel = floor(torta / vec2(140.0, 95.0));
	float h = hash3(vec3(cel, 3.0));
	vec3 c = h < 0.42 ? pasto : (h < 0.72 ? pasto_verde : (h < 0.86 ? mata
		: (h < 0.94 ? mix(terra, pasto, 0.45) : eucalipto)));
	float corrego = abs(fbm(vec3(q * 0.0022, 4.0)) - 0.5);
	c = mix(c, mata, 1.0 - smoothstep(0.018, 0.04, corrego));
	// Longe, a colcha vira media: o pixel ja cobre varios pastos.
	vec3 media = (pasto + pasto_verde + mata * 0.6) / 2.6;
	return mix(c, media, smoothstep(900.0, 2800.0, dist));
}

void fragment() {
	float crista = v_crista;
	float perto = 1.0 - clamp(crista / 4.0, 0.0, 1.0);
	// Altura dentro do morro: 0 na linha do horizonte, 1 no cume da coluna.
	float t = clamp((v_marca - no_horizonte) / (1.0 - no_horizonte), 0.0, 1.0);
	vec3 p = v_local + vec3(crista * 71.0, 0.0, crista * 37.0);
	vec3 dir = normalize(v_local);
	float grao = mix(0.5, 1.0, detalhe);
	vec3 cor;

	if (v_local.y < 0.0) {
		// O vale: o raio da camera descendo ate um chao plano ALTURA_VALE abaixo.
		float desce = max(-dir.y, 0.0015);
		float dist = min(ALTURA_VALE / desce, 20000.0);
		vec2 q = normalize(dir.xz) * dist;
		vec3 chao = vale(q, dist);
		chao *= 1.0 + (ruido(vec3(q * 0.05, 2.0)) - 0.5) * 0.25 * grao
			* (1.0 - smoothstep(600.0, 1800.0, dist));
		float nuvem = smoothstep(0.45, 0.7, fbm(vec3(q.x + vento.x * 8.0, 0.0, q.y + vento.y * 8.0) * 0.0016));
		// Minas nao tem varzea plana: o chao do vale ondula em morrote. A
		// ondulacao so existe na luz (encosta clara, encosta na sombra).
		float e = 40.0;
		float h0 = morrote(q);
		vec3 nrm = normalize(vec3(h0 - morrote(q + vec2(e, 0.0)), e * 0.012,
			h0 - morrote(q + vec2(0.0, e))));
		float sol = max(dot(nrm, rumo_sol), 0.0) * (1.0 - nuvem * sombra_nuvem * 3.0);
		// A grota do morrote e mais verde: e onde a mata e o corrego ficam.
		chao = mix(chao, mata, smoothstep(0.45, 0.3, h0) * 0.5 * (1.0 - smoothstep(1500.0, 3000.0, dist)));
		// A noite a colcha quase some: lua nao separa pasto de mata.
		vec3 media_noite = (pasto + pasto_verde + mata) / 3.0;
		chao = mix(chao, media_noite, noite * 0.75);
		chao = mix(chao, vec3(dot(chao, vec3(0.3, 0.55, 0.15))) * vec3(0.75, 0.85, 1.0), noite * 0.85);
		cor = chao * (luz_ambiente + luz_sol * sol);
		// Ar pela distancia: no fundo do vale, o mesmo da crista de perto.
		float ar = ar_perto * (1.0 - exp(-dist / (VALE_LONGE * 0.45)));
		ar = 1.0 - (1.0 - ar) * vista_vale;
		cor = mix(cor, bruma, ar);
		ALBEDO = cor;
	} else {
		// O que cobre o morro. A mata mora na grota (baixo) e no morro de tras;
		// o pasto no alto. O limiar anda com ruido largo: cada morro tem o seu.
		float largo = fbm(p * 0.03);
		float mata_k = smoothstep(0.48, 0.58, largo + (0.42 - t) * 0.32 + (1.0 - perto) * 0.12);
		vec3 chao = mix(pasto, pasto_verde, smoothstep(0.35, 0.65, fbm(p * 0.018 + 3.1)));
		// Talhao de eucalipto: bloco de borda reta, so nas cristas de perto.
		vec2 lote = floor(v_local.xz / 26.0 + vec2(crista * 3.0, 0.0));
		float talhao = step(hash3(vec3(lote, crista)), 0.07) * step(0.15, t) * step(t, 0.8)
			* step(crista, 2.5);
		chao = mix(chao, mata, mata_k);
		chao = mix(chao, eucalipto, talhao * (1.0 - mata_k));
		// Terra vermelha: a estrada de terra que corta a encosta em diagonal e
		// a vocoroca aberta no pasto. So onde nao e mata, e so em trechos.
		float linha = abs(ruido(vec3(v_local.x * 0.03, v_local.y * 0.035, v_local.z * 0.03) + crista * 5.0) - 0.5);
		float trecho = smoothstep(0.55, 0.65, ruido(p * 0.02 + 11.0));
		float estrada = (1.0 - smoothstep(0.01, 0.022, linha)) * trecho * step(0.06, t) * step(t, 0.9);
		float vocoroca = smoothstep(0.8, 0.86, fbm(p * 0.06 + 9.0)) * (1.0 - t * 0.6);
		chao = mix(chao, terra, max(estrada * 0.8, vocoroca) * (1.0 - mata_k) * step(crista, 2.5));
		// A serra de tras e campo rupestre: capim ralo e rocha no alto.
		float longe = smoothstep(2.5, 3.5, crista);
		chao = mix(chao, mix(campo, mata, mata_k * 0.7), longe);
		float aflora = smoothstep(0.55, 0.9, t) * smoothstep(0.5, 0.75, fbm(p * 0.07 + 5.0));
		chao = mix(chao, rocha, aflora * longe);
		// Grao: a copa da mata e o capim nao sao cor chapada.
		chao *= 1.0 + (ruido(p * 0.8) - 0.5) * 0.35 * grao * (0.5 + mata_k);
		chao = mix(chao, vec3(dot(chao, vec3(0.3, 0.55, 0.15))) * vec3(0.75, 0.85, 1.0), noite * 0.85);

		// Luz: a normal da encosta (da malha) contra o sol, mais o ambiente. A
		// grota fica um pouco mais escura que o alto do morro.
		float sol = max(dot(normalize(v_normal), rumo_sol), 0.0);
		float nuvem = smoothstep(0.45, 0.7, fbm(vec3(v_local.x + vento.x, 0.0, v_local.z + vento.y) * 0.012));
		sol *= 1.0 - nuvem * sombra_nuvem * 3.0;
		float luz = luz_ambiente * (0.8 + 0.2 * t) + luz_sol * sol;
		cor = chao * luz;

		// O ar: a crista de longe mais afogada; no pe dela, a bruma do vale.
		float ar = mix(ar_perto, ar_longe, 1.0 - perto);
		// Com nevoa o pe do morro afunda na bruma do vale (que ja sumiu), em
		// vez de cortar seco na linha do horizonte.
		float ar_pe = 1.0 - (1.0 - ar) * vista_vale;
		ar = 1.0 - (1.0 - ar) * vista;
		ar = mix(max(ar, ar_pe), ar, smoothstep(0.0, 0.45, t));
		vec3 ceu = mix(fundo, mix(fundo, cor_sol, 0.25),
			pow(max(dot(dir, normalize(vec3(rumo_sol.x, 0.0, rumo_sol.z) + 1e-4)), 0.0), 4.0) * luz_sol);
		vec3 atm = mix(bruma, ceu, smoothstep(0.0, 0.8, t));
		cor = mix(cor, atm, ar);

		// Franja de copa acima do cume. Pasto no alto nao tem franja.
		if (v_franja > 0.001) {
			float c = copa(p) * smoothstep(0.35, 0.65, mata_k + talhao + longe * 0.4);
			if (v_franja > c) {
				discard;
			}
		}
		ALBEDO = cor;
	}
}

// A agua NO vidro — no vidro de verdade, em metros, e agora com MEMORIA.
//
// O que este shader substitui
// ---------------------------
// `psx_parabrisa.gdshader` desenhava a agua numa placa presa a LENTE, 60 cm a
// frente do olho. Tres coisas vinham de graca com esse erro, e as tres eram
// defeito: a agua aparecia onde nao havia vidro (21 a 47% do quadro, medido); a
// gota saia redonda num vidro inclinado a 60 graus; e o limpador nao limpava
// LUGAR nenhum — um unico `acumulo` multiplicava a agua do vidro inteiro e a
// cada passada tudo apagava e reacendia junto.
//
// O que mudou na Fase 4
// ---------------------
// A agua deixou de ser um uniform e virou uma TEXTURA: `AguaVidro` mantem um
// mapa que persiste entre quadros, com cobertura no R, filme no G e embacado no
// B. Com isso caiu daqui o leque analitico — inverter `k(t) = 0,5 - 0,5 cos(pi
// t)` para descobrir ha quanto tempo a palheta passou num angulo. Era um truque
// bonito e funcionava, mas so funciona para uma coisa que se REPETE. Rastro de
// corredora nao se repete, residuo de borracha nao se repete, e sujeira menos
// ainda. Agora quem apaga a agua no setor varrido e o passo de simulacao, e
// aqui so se LE o que ha em cada ponto.
//
// O que continua vindo da malha (`VidroCabine`)
// ---------------------------------------------
//   UV     posicao no mapa de agua
//   UV2    posicao em METROS no plano, com `v` morro abaixo
//   COLOR  r = tem limpador, g = tipo, (b,a) = tamanho do vidro / ESCALA_TAM
//
// Disso sai o que o olho reconhece:
//
//   TAMANHO   a gota tem 6 a 14 mm em qualquer janela, porque a grade e metrica
//             e nao normalizada pela placa;
//   GRAVIDADE escorre sempre para +v, seja o vidro inclinado ou em pe;
//   VENTO     no para-brisa o ar vence o peso e a agua SOBE abrindo para as
//             bordas; na janela lateral ela deita para tras (+u e a traseira);
//   LIMPADOR  onde a palheta passou a cobertura e zero, e a agua volta GOTA A
//             GOTA, por limiar sorteado de celula — sem uma linha de `TIME`
//             comum, que e o que matava o "pisca".
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// O mundo atras do vidro. No Compatibility vem so com o que e opaco — que e
// exatamente o que a agua tem de refratar.
uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear;

// O mapa de agua: R cobertura, G filme, B embacado. Ver `AguaVidro`.
uniform sampler2D mapa : repeat_disable, filter_linear;
uniform bool usa_mapa = false;
// Cobertura de reserva, para quem desenha o vidro sem mapa (vitrine, teste).
uniform float cobertura : hint_range(0.0, 1.0) = 0.0;

// Estilo em vigor (MODERNO liga). Ver `EstiloVisual`.
global uniform bool psx_facho_suave;

// Esta caindo chuva AGORA, de 0 a 1. Zero nao apaga o vidro: apaga a agua.
uniform float intensidade : hint_range(0.0, 1.0) = 0.0;
// Quanto o ar empurra a agua, de 0 a 1 — escrito da velocidade do carro.
uniform float vento : hint_range(0.0, 1.0) = 0.0;

// Tom do brilho e do embacado. Frio: e o ceu encoberto que a agua devolve.
uniform vec4 cor : source_color = vec4(0.80, 0.85, 0.90, 1.0);
// Embacado minimo, mesmo com o mapa zerado.
uniform float embacado : hint_range(0.0, 1.0) = 0.06;
// Quanto a gota desloca o mundo atras dela, em METROS de vidro.
//
// Era fracao de TELA, e 0,055 de tela sao 26 pixels em 480x270 — enquanto a
// gota de 9 mm ocupa uns quatro. A gota mostrava o que estava a seis gotas de
// distancia, que no para-brisa e o forro escuro do teto ou o painel: na captura
// da cutscene as gotas sairam pretas, como respingo de lama, e nao como agua.
//
// Em metros o numero tem sentido fisico — uma lente de 9 mm desloca o fundo por
// uns poucos milimetros — e vale igual de perto, de longe e em qualquer
// resolucao, porque a conversao para tela e medida no proprio fragmento.
uniform float refracao : hint_range(0.0, 0.05) = 0.010;
// Presenca do vidro LIMPO: o reflexo de nada que diz que ha vidro ali.
uniform float vidro_seco : hint_range(0.0, 0.3) = 0.035;
// Tamanho das gotas paradas, em metros (diametro medio das tres escalas).
uniform float gota_grande = 0.014;
uniform float gota_media = 0.009;
uniform float gota_fina = 0.005;

// 0 desligado, 1 mapa cru, 2 cobertura, 3 filme, 4 embacado. Ver `--dbg-agua`.
uniform int depurar = 0;

varying vec2 metros;
varying vec2 uv_mapa;
varying vec2 tam_vidro;
varying float tem_limpador;
varying float tipo;

const float ESCALA_TAM = 8.0;

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


// A descida: para, escorrega, para. Continua e monotona — nunca volta e nunca
// salta.
//
// Isto ficou APENAS para o fio fino que corre entre as gotas paradas. As gotas
// grandes que descem sao `AguaCorredoras`, simuladas na CPU com massa e
// adesao, e la o para-e-escorrega sai da fisica e nao de dois senos.
float deslize(float t) {
	return t + 0.30 * sin(t * 6.2831) + 0.10 * sin(t * 12.566 + 1.3);
}


void vertex() {
	metros = UV2;
	uv_mapa = UV;
	tem_limpador = COLOR.r;
	tipo = COLOR.g;
	tam_vidro = COLOR.ba * ESCALA_TAM;
}


// Uma gota como LENTE: mascara e relevo. O relevo e uma calota; a normal dela
// sai da derivada, e e ela que desloca o mundo atras.
void gota(vec2 d, float raio, out float mascara, out vec2 inclina) {
	float r = length(d);
	mascara = smoothstep(raio, raio * 0.55, r);
	float h = sqrt(max(0.0, raio * raio - r * r)) / max(raio, 1e-4);
	inclina = (r > 1e-5) ? -(d / r) * (1.0 - h) * mascara : vec2(0.0);
}


// As gotas paradas de UMA escala. Elas nao nascem no tempo: nascem quando a
// COBERTURA passa do limiar sorteado da celula. Depois de a palheta limpar, a
// agua volta gota a gota, em ordem aleatoria, sem uma linha de tempo comum —
// que e o que mata o "pisca" e o que cumpre o criterio C5 por construcao.
void goticulas(vec2 m, float lado, float cob, inout float mascara,
		inout vec2 inclina) {
	vec2 p = m / lado;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float limiar = hash21(id * 1.7 + 3.1);
	if (cob <= limiar * 0.92) {
		return;
	}
	float crescer = smoothstep(limiar * 0.92, min(1.0, limiar * 0.92 + 0.22), cob);
	vec2 centro = (vec2(hash21(id + 5.3), hash21(id + 9.1)) - 0.5) * 0.5;
	float raio = (0.20 + 0.16 * hash21(id + 2.2)) * crescer;
	float mm;
	vec2 ii;
	gota(f - centro, raio, mm, ii);
	if (mm > mascara) {
		mascara = mm;
	}
	inclina += ii * 1.4;
}


// O fio fino que corre no sentido do fluxo, entre as gotas paradas.
//
// A coluna INTEIRA rola: e isso que leva o fio de uma celula para a outra sem
// salto, e o motivo de nao haver renascimento no alto do vidro.
void fio(vec2 m, vec2 fluxo, float cob, float t, inout float mascara,
		inout vec2 inclina, inout float filme) {
	vec2 e1 = fluxo;
	vec2 e2 = vec2(-fluxo.y, fluxo.x);
	// Largura da coluna, em metros. Com 7,5 cm a gota saia com 3 cm de
	// diametro — mancha, e nao gota. Chuva de verdade escorre em fio de 1 cm.
	float largura = 0.030;
	vec2 p = vec2(dot(m, e2) / largura, dot(m, e1) / largura);
	float coluna = floor(p.x);
	float h = hash21(vec2(coluna, 11.0));
	if (h > 0.10 + 0.55 * cob) {
		return;
	}
	float velocidade = 0.6 + 1.5 * h;
	p.y -= deslize(t * velocidade * 0.25 + h * 13.0);
	vec2 id = vec2(coluna, floor(p.y));
	vec2 f = fract(p) - vec2(0.5, 0.5);
	float h2 = hash21(id + 4.4);
	float raio = 0.22 + 0.12 * h2;
	// Lagrima: mais comprida do lado em que ela pesa.
	vec2 d = f;
	d.y *= (d.y > 0.0) ? 0.75 : 1.35;
	float mm;
	vec2 ii;
	gota(d, raio, mm, ii);
	if (mm > mascara) {
		mascara = mm;
	}
	inclina += ii * 1.6;
	// O rastro: um filme fino ATRAS da gota (do lado de onde ela veio).
	float atras = smoothstep(0.0, 0.08, -f.y);
	filme = max(filme, smoothstep(0.16, 0.0, abs(f.x)) * atras * 0.7);
}


void fragment() {
	vec2 m = metros;

	// O estado deste ponto do vidro. Com mapa, ele vem de la — inclusive o
	// buraco que a palheta acabou de abrir e a faixa que a corredora raspou.
	vec3 estado = vec3(cobertura, 0.0, embacado);
	if (usa_mapa) {
		estado = texture(mapa, uv_mapa).rgb;
	}
	float cob = clamp(estado.r, 0.0, 1.0);
	float filme_mapa = clamp(estado.g, 0.0, 1.0);
	float embaca = clamp(max(estado.b, embacado), 0.0, 1.0);

	// Para onde a agua corre neste vidro.
	//   para-brisa  desce parada; com vento SOBE e abre para as bordas
	//   lateral     desce; com vento deita para a traseira (+u)
	//   vigia       desce
	vec2 fluxo = vec2(0.0, 1.0);
	if (tipo < 0.25) {
		float lado = (m.x > tam_vidro.x * 0.5) ? 1.0 : -1.0;
		fluxo = normalize(mix(vec2(0.0, 1.0), vec2(lado * 0.55, -1.0),
			smoothstep(0.30, 0.85, vento)));
	} else if (tipo < 0.75) {
		fluxo = normalize(vec2(vento * 2.2, 1.0));
	}

	float mascara = 0.0;
	vec2 inclina = vec2(0.0);
	float filme = filme_mapa;
	if (cob > 0.001) {
		fio(m, fluxo, cob, TIME, mascara, inclina, filme);
		goticulas(m, gota_grande, cob, mascara, inclina);
		goticulas(m * 1.31 + vec2(7.3, 1.9), gota_media, cob * 0.92, mascara,
			inclina);
		goticulas(m * 2.17 + vec2(3.1, 5.7), gota_fina, cob * 0.80, mascara,
			inclina);
	}
	// O filme do mapa nao depende de a chuva ESTAR caindo: e o vidro molhado
	// que sobra depois da passada, e ele seca no seu tempo.
	float agua = max(max(mascara, filme * 0.55) * intensidade, filme_mapa * 0.35);

	// A normal da agua vai para o espaco de VISAO pela tangente: e assim que o
	// relevo da gota vira deslocamento na tela.
	// z pequeno = lente forte: a gota inverte e comprime o que esta atras dela,
	// que e o que o olho reconhece como agua e nao como mancha clara.
	vec3 nb = normalize(vec3(inclina.x, inclina.y, 0.85));
	vec3 n_visao = normalize(TANGENT * nb.x + BINORMAL * nb.y + NORMAL * nb.z);
	// Quanta tela vale um metro de vidro AQUI. A derivada faz a conta sozinha:
	// perto o vidro ocupa muita tela por metro, longe pouca, e a gota desloca
	// sempre os mesmos milimetros.
	float por_metro = length(fwidth(SCREEN_UV))
		/ max(length(fwidth(metros)), 1e-6);
	vec2 desvio = -n_visao.xy * refracao * por_metro * (mascara + filme * 0.25);
	bool moderno = psx_facho_suave;
	if (!moderno) {
		// PS1: o mundo refratado anda em passo de pixel da grade de 480x270.
		desvio = floor(desvio * vec2(480.0, 270.0)) / vec2(480.0, 270.0);
	}
	vec3 mundo = texture(tela, clamp(SCREEN_UV + desvio, vec2(0.001),
		vec2(0.999))).rgb;

	// Embacado, do lado de dentro: quatro amostras deslocadas, clareadas. Ele
	// nao some onde a gota passa — gota e agua de FORA.
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 fosco = (texture(tela, SCREEN_UV + vec2(px.x, px.y) * 2.5).rgb
		+ texture(tela, SCREEN_UV + vec2(-px.x, px.y) * 2.5).rgb
		+ texture(tela, SCREEN_UV + vec2(px.x, -px.y) * 2.5).rgb
		+ texture(tela, SCREEN_UV + vec2(-px.x, -px.y) * 2.5).rgb) * 0.25;
	fosco = mix(fosco, cor.rgb * 0.55, 0.22);
	// A borda sai dos METROS e do tamanho do vidro, porque a UV agora mora no
	// mapa de agua e nao na placa.
	vec2 borda = abs(m / max(tam_vidro, vec2(0.01)) - 0.5) * 2.0;
	float canto = smoothstep(0.45, 1.0, max(borda.x, borda.y));
	float nevoa = embaca * mix(0.6, 1.3, canto);

	vec3 c = mix(mundo, fosco, nevoa);
	// O brilho que a gota devolve: e ele, e nao o que ela deixa passar, que faz
	// agua ser visivel contra mata escura a noite.
	float brilho = pow(clamp(nb.z * 0.28 + n_visao.y * 0.6, 0.0, 1.0), 3.0);
	c += cor.rgb * brilho * mascara * 0.5;

	float a = max(agua, nevoa);
	// O vidro limpo continua existindo: sem nada no vao, a janela volta a ler
	// como buraco na lataria.
	a = max(a, vidro_seco * mix(0.7, 1.5, canto));
	if (!moderno) {
		// Pontilhado MULTIPLICADO, nunca somado: somado, metade do padrao pinta
		// alfa onde nao ha agua e vira veu leitoso no quadro inteiro.
		int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
		a *= 1.0 + (BAYER[idx] / 16.0 - 0.5) * 0.45;
	}

	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);

	// `--dbg-agua`: o canal do mapa em cor chapada, por cima de tudo. Vem no
	// fim e nao no comeco porque `return` no `fragment()` nao existe na
	// linguagem de shader do Godot.
	if (depurar > 0) {
		if (depurar == 1) {
			ALBEDO = estado;
		} else if (depurar == 2) {
			ALBEDO = vec3(cob);
		} else if (depurar == 3) {
			ALBEDO = vec3(filme_mapa);
		} else {
			ALBEDO = vec3(embaca);
		}
		ALPHA = 1.0;
	}
}

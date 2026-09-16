// A agua NO vidro — agora no vidro de verdade, e em metros.
//
// O que este shader substitui
// ---------------------------
// `psx_parabrisa.gdshader` desenhava a agua numa placa presa a LENTE, 60 cm a
// frente do olho. Tres coisas vinham de graca com esse erro, e as tres eram
// defeito:
//
//   * a agua aparecia onde nao havia vidro — 21 a 47% do quadro, medido;
//   * a gota saia redonda num vidro inclinado a 60 graus, porque a placa era
//     perpendicular a camera;
//   * o limpador nao limpava LUGAR nenhum: um unico `acumulo` multiplicava a
//     agua do vidro inteiro, e a cada passada tudo apagava e reacendia junto.
//     Medido: o para-brisa ia de limpo a cheio em 0,13 s, com 11,1% dos pixels
//     mudando mais de 12 niveis entre dois quadros.
//
// Aqui a agua mora na malha do vidro (`VidroCabine`), que traz em UV2 a posicao
// em METROS no plano, com `v` apontando morro abaixo. Disso sai tudo:
//
//   TAMANHO   a gota tem 6 a 14 mm em qualquer janela, porque a grade e metrica
//             e nao normalizada pela placa;
//   GRAVIDADE escorre sempre para +v, seja o vidro inclinado ou em pe;
//   VENTO     no para-brisa o ar vence o peso e a agua SOBE abrindo para as
//             bordas; na janela lateral ela deita para tras (+u e a traseira);
//   LIMPADOR  a agua volta em funcao do TEMPO DESDE QUE A PALHETA PASSOU naquele
//             angulo, e nao de um numero global. Atras da palheta o vidro esta
//             limpo; na ponta do leque, onde ela passou ha mais tempo, a agua ja
//             voltou. E o leque que o olho reconhece.
//
// O tempo desde a passada e resolvido em forma fechada: a palheta anda por
// `k(t) = 0,5 - 0,5 cos(pi t)`, que e monotona em cada meia passada, entao o
// instante em que ela cruzou um angulo qualquer se acha invertendo o cosseno —
// sem guardar estado, sem textura de historico. A Fase 4 troca isto por um mapa
// de agua que tambem lembra trilha de gota e sujeira; ate la, isto ja da o leque
// no lugar certo.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// O mundo atras do vidro. No Compatibility vem so com o que e opaco — que e
// exatamente o que a agua tem de refratar.
uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear;

// Estilo em vigor (MODERNO liga). Ver `EstiloVisual`.
global uniform bool psx_facho_suave;

// Esta caindo chuva AGORA, de 0 a 1. Zero nao apaga o vidro: apaga a agua.
uniform float intensidade : hint_range(0.0, 1.0) = 0.0;
// Quanta agua ja juntou no vidro, de 0 a 1. Sobe com a chuva e desce com o
// limpador e com a secagem. Quem move e o script.
uniform float cobertura : hint_range(0.0, 1.0) = 0.0;
// Quanto o ar empurra a agua, de 0 a 1 — escrito da velocidade do carro.
uniform float vento : hint_range(0.0, 1.0) = 0.0;

// Tom do brilho e do embacado. Frio: e o ceu encoberto que a agua devolve.
uniform vec4 cor : source_color = vec4(0.80, 0.85, 0.90, 1.0);
// Embacado do lado de DENTRO. Nem a gota nem o limpador o limpam — quem limpa e
// o desembacador, e isso e da Fase 5.
uniform float embacado : hint_range(0.0, 1.0) = 0.11;
// Quanto a gota desloca o mundo atras dela, em fracao de tela.
uniform float refracao : hint_range(0.0, 0.3) = 0.055;
// Presenca do vidro LIMPO: o reflexo de nada que diz que ha vidro ali.
uniform float vidro_seco : hint_range(0.0, 0.3) = 0.035;
// Tamanho das gotas paradas, em metros (diametro medio das tres escalas).
uniform float gota_grande = 0.014;
uniform float gota_media = 0.009;
uniform float gota_fina = 0.005;

// --- limpador, em metros do para-brisa --------------------------------------
// Pivo, raio de dentro e de fora da palheta, curso em radianos, e a fase 0..2
// (0..1 ida, 1..2 volta). `passada` e quantos segundos leva uma ida.
uniform vec2 pivo = vec2(0.0, 0.0);
uniform vec2 pivo2 = vec2(0.0, 0.0);
uniform vec2 raios = vec2(0.10, 0.55);
uniform float ang_repouso = 0.35;
uniform float ang_curso = 1.55;
uniform float fase = 0.0;
uniform float passada = 0.55;
uniform float limpador_ligado : hint_range(0.0, 1.0) = 0.0;
// Segundos ate a agua voltar ao cheio depois da passada.
uniform float tempo_encher = 2.4;
// Meia largura da palheta, em radianos.
uniform float palheta = 0.05;

uniform float depurar = 0.0;

varying vec2 metros;
varying float tem_limpador;
varying float tipo;

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


// A descida: para, escorrega, para. Continua e monotona — a gota nunca volta e
// nunca salta. Foi o unico acerto do shader anterior e continua valendo.
float deslize(float t) {
	return t + 0.30 * sin(t * 6.2831) + 0.10 * sin(t * 12.566 + 1.3);
}


void vertex() {
	metros = UV2;
	tem_limpador = COLOR.r;
	tipo = COLOR.g;
}


// Quanto tempo faz, em segundos, que a palheta passou por este ponto.
//
// Devolve um numero grande onde ela nunca passa (fora do leque), que e o mesmo
// que dizer "ha muito tempo": ali a agua esta cheia.
float tempo_de_um(vec2 m, vec2 centro) {
	vec2 d = m - centro;
	float r = length(d);
	if (r < raios.x || r > raios.y) {
		return 1000.0;
	}
	// Angulo medido do repouso, normalizado pelo curso: 0 no repouso, 1 no fim.
	float ang = atan(d.x, -d.y) - ang_repouso;
	float k = ang / ang_curso;
	if (k < -0.02 || k > 1.02) {
		return 1000.0;
	}
	k = clamp(k, 0.0, 1.0);
	// A palheta cruza este angulo duas vezes por ciclo: subindo em t1 e
	// voltando em t2 = 2 - t1, com k(t) = 0,5 - 0,5 cos(pi t).
	float t1 = acos(clamp(1.0 - 2.0 * k, -1.0, 1.0)) / 3.14159265;
	float t2 = 2.0 - t1;
	float dt;
	if (fase >= t2) {
		dt = fase - t2;
	} else if (fase >= t1) {
		dt = fase - t1;
	} else {
		// Ainda nao chegou nesta ida: a ultima vez foi na volta do ciclo passado.
		dt = fase + 2.0 - t2;
	}
	// A propria palheta: o risco de vidro limpo que acompanha a borracha.
	float largura = smoothstep(palheta, 0.0, abs(fase - t1) * 0.5)
		+ smoothstep(palheta, 0.0, abs(fase - t2) * 0.5);
	return max(0.0, dt * passada - largura * 0.35);
}


// As DUAS palhetas limpam: vale a que passou por ultimo.
float tempo_desde_passada(vec2 m) {
	if (tem_limpador < 0.5 || limpador_ligado < 0.5) {
		return 1000.0;
	}
	return min(tempo_de_um(m, pivo), tempo_de_um(m, pivo2));
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
// que e o que mata o "pisca".
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


// As corredoras e o rastro delas, no sentido do fluxo.
//
// A coluna INTEIRA rola: e isso que leva a gota de uma celula para a outra sem
// salto, e o motivo de nao haver renascimento no alto do vidro.
void corredoras(vec2 m, vec2 fluxo, float cob, float t, inout float mascara,
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
	float cob = clamp(cobertura, 0.0, 1.0);

	// O limpador some com a agua onde passou, e ela volta com o tempo.
	float desde = tempo_desde_passada(m);
	cob *= clamp(desde / max(tempo_encher, 0.05), 0.0, 1.0);

	// Para onde a agua corre neste vidro.
	//   para-brisa  desce parada; com vento SOBE e abre para as bordas
	//   lateral     desce; com vento deita para a traseira (+u)
	//   vigia       desce
	vec2 fluxo = vec2(0.0, 1.0);
	if (tipo < 0.25) {
		float lado = (m.x > 0.0) ? 1.0 : -1.0;
		fluxo = normalize(mix(vec2(0.0, 1.0), vec2(lado * 0.55, -1.0),
			smoothstep(0.30, 0.85, vento)));
	} else if (tipo < 0.75) {
		fluxo = normalize(vec2(vento * 2.2, 1.0));
	}

	float mascara = 0.0;
	vec2 inclina = vec2(0.0);
	float filme = 0.0;
	if (cob > 0.001) {
		corredoras(m, fluxo, cob, TIME, mascara, inclina, filme);
		goticulas(m, gota_grande, cob, mascara, inclina);
		goticulas(m * 1.31 + vec2(7.3, 1.9), gota_media, cob * 0.92, mascara,
			inclina);
		goticulas(m * 2.17 + vec2(3.1, 5.7), gota_fina, cob * 0.80, mascara,
			inclina);
	}
	float agua = max(mascara, filme * 0.55) * intensidade;

	// A normal da agua vai para o espaco de VISAO pela tangente: e assim que o
	// relevo da gota vira deslocamento na tela.
	// z pequeno = lente forte: a gota inverte e comprime o que esta atras dela,
	// que e o que o olho reconhece como agua e nao como mancha clara.
	vec3 nb = normalize(vec3(inclina.x, inclina.y, 0.85));
	vec3 n_visao = normalize(TANGENT * nb.x + BINORMAL * nb.y + NORMAL * nb.z);
	vec2 desvio = -n_visao.xy * refracao * (mascara + filme * 0.25);
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
	vec2 borda = abs(UV - 0.5) * 2.0;
	float canto = smoothstep(0.45, 1.0, max(borda.x, borda.y));
	float nevoa = embacado * mix(0.6, 1.3, canto) * intensidade;

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
	if (depurar > 0.5) {
		// Mapa de cobertura em cor chapada: e assim que se ve o leque do
		// limpador sem o resto da agua por cima.
		ALBEDO = vec3(cob, clamp(desde / 3.0, 0.0, 1.0), mascara);
		ALPHA = 1.0;
	}
}

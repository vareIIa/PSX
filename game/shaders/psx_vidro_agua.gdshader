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
// Quanto a gota desloca o mundo atras dela, em METROS de vidro. No MODERNO o
// valor usado e `refracao_moderno`: ver la.
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

// --- MODERNO: o que o Vulkan paga e o PS1 nao tinha ---------------------------
//
// O PS1 STYLE e um preset, e nao o teto do jogo. No MODERNO a tela e 1280x720
// ou mais, a tela amostrada e HDR, e a gota pode ser o que ela e numa camera de
// verdade: uma lente forte, com cor separada na borda e um ponto de luz em cima.
//
// Lente: 2,2 cm. Com 1 cm a gota de 7 mm deslocava uns 3 px e mal entortava o
// mundo; a lente convexa de verdade mostra, invertida, uma area varias vezes
// maior que ela. O risco que a Fase 4 corrigiu (26 px numa gota de 4, gota
// preta) nao volta: o deslocamento agora e metrico e some na borda do vidro.
uniform float refracao_moderno : hint_range(0.0, 0.08) = 0.022;
// Separacao de cor na borda da gota, em fracao do deslocamento.
uniform float dispersao : hint_range(0.0, 0.2) = 0.06;
// Realce especular: o ponto de luz que o ceu faz no alto de cada gota.
uniform float especular : hint_range(0.0, 3.0) = 0.9;
uniform float especular_dureza : hint_range(4.0, 256.0) = 48.0;
// A quarta escala: microgotas de 2,5 mm entre as grandes. A 480x270 elas somem;
// a 1280x720 sao a garoa fina que enche o vidro entre duas gotas grandes.
uniform float gota_micro = 0.0026;
// Presenca do vidro LIMPO: o reflexo de nada que diz que ha vidro ali.
uniform float vidro_seco : hint_range(0.0, 0.3) = 0.035;
// Tamanho das gotas paradas, em metros (diametro medio das tres escalas).
uniform float gota_grande = 0.014;
uniform float gota_media = 0.009;
uniform float gota_fina = 0.005;

// --- Fase 5: optica ---------------------------------------------------------

// Sujeira: poeira, marca de chuva seca, resina. E ela, mais que a agua, que faz
// o limpador ler de LONGE: o leque limpo e um desenho que o olho reconhece em
// qualquer para-brisa velho, e ele so existe porque o resto do vidro e sujo.
uniform float sujeira : hint_range(0.0, 0.5) = 0.16;
uniform vec4 cor_sujeira : source_color = vec4(0.46, 0.43, 0.37, 1.0);
// O leque das palhetas, FIXO: o desenho de anos de passada, e nao a passada de
// agora (essa mora no mapa). Pivos e raios em metros do para-brisa; angulos em
// radianos a partir da vertical do vidro, ja com a meia largura da borracha.
uniform bool tem_leque = false;
uniform vec2 leque_a = vec2(0.0);
uniform vec2 leque_b = vec2(0.0);
uniform vec2 leque_raios = vec2(0.10, 0.50);
uniform vec2 leque_angulos = vec2(-1.0, 1.0);

// Brilho que o FUNDO acende na gota: o poste, o farol que vem, o ceu no
// relampago. A gota e lente — ela junta a luz clara que esta atras dela — e e
// isso, e nao um brilho pintado por cima, que faz a agua do vidro acender
// quando passa um carro. Acima do limiar de luminancia o excesso vira brilho.
uniform float limiar_brilho : hint_range(0.0, 1.0) = 0.55;
uniform float brilho_fundo : hint_range(0.0, 6.0) = 2.2;

// Raio do desfoque do embacado com o vidro embacado de todo, em pixels da tela.
// `textureLod` na tela nao desfoca em nenhum dos dois renderizadores (spike G
// da Fase 0): o desfoque sao oito amostras de verdade.
uniform float desfoque_px : hint_range(0.0, 8.0) = 3.5;

// Quanto a borda do vidro pode ser mais embacada/marcada que o meio. Era 45%
// (0,6 a 1,3 de multiplicador): a janela saia com moldura de nevoa desenhada.
uniform float borda_max : hint_range(0.0, 0.5) = 0.12;

// 0 desligado, 1 mapa cru, 2 cobertura, 3 filme, 4 embacado, 5 sujeira.
// Ver `--dbg-agua`.
uniform int depurar = 0;

varying vec2 metros;
varying vec2 uv_mapa;
varying vec2 tam_vidro;
varying float tem_limpador;
varying float tipo;

const float ESCALA_TAM = 8.0;

// No PS1 STYLE a gota e desenhada 2,5 vezes maior (e 6 vezes mais rara).
//
// Medido em 16/09/2026 na bancada optica: a 480x270, com o para-brisa a 60-90
// cm do olho, uma gota de 1 cm ocupa uns 2,5 pixels. A gota grande (6 a 10 mm)
// saia com 1,3 a 2,4 px — menor que o anel escuro que faz ela ler como gota —,
// e o vidro inteiro virava GRAO. O PS1 desenhava chuva grossa por isso mesmo.
// A escala e fixa por estilo, e nao medida no pixel: tamanho que depende da
// derivada muda ao longo do vidro, e a grade de gotas entortaria.
const float ESCALA_GOTA_PS1 = 2.5;

// O desfoque e escrito em pixels da grade de 480x270 e convertido para a tela de
// verdade. Em pixels absolutos, no MODERNO a 1280x720 ele saia 2,7 vezes mais
// fraco que o desenhado.
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


// Uma gota como LENTE: mascara, relevo e borda. O relevo e uma calota; a
// normal dela sai da derivada, e e ela que desloca o mundo atras. A BORDA e o
// anel onde a luz entra rasante e reflete por dentro: na gota de verdade ele e
// escuro, e e esse contorno fino — mais que o miolo — que faz a gota ler como
// gota e nao como mancha.
void gota(vec2 d, float raio, out float mascara, out vec2 inclina,
		out float borda) {
	float r = length(d);
	mascara = smoothstep(raio, raio * 0.55, r);
	float h = sqrt(max(0.0, raio * raio - r * r)) / max(raio, 1e-4);
	inclina = (r > 1e-5) ? -(d / r) * (1.0 - h) * mascara : vec2(0.0);
	borda = smoothstep(raio * 0.40, raio * 0.85, r) * mascara;
}


// As gotas paradas de UMA escala. Elas nao nascem no tempo: nascem quando a
// COBERTURA passa do limiar sorteado da celula. Depois de a palheta limpar, a
// agua volta gota a gota, em ordem aleatoria, sem uma linha de tempo comum —
// que e o que mata o "pisca" e o que cumpre o criterio C5 por construcao.
void goticulas(vec2 m, float lado, float cob, float achata, float px_lado,
		inout float mascara, inout vec2 inclina, inout float borda) {
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
	// A gota grande o peso achata: mais cheia embaixo (morro abaixo, +v) e
	// mais fina em cima. A pequena a tensao superficial segura redonda.
	vec2 d = f - centro;
	d.y *= (d.y > 0.0) ? mix(1.0, 0.78, achata) : mix(1.0, 1.18, achata);
	float mm;
	vec2 ii;
	float bb;
	gota(d, raio, mm, ii, bb);
	if (mm > mascara) {
		mascara = mm;
	}
	// O anel so existe onde a gota tem pixel para ele. Numa gota de dois
	// pixels o miolo claro some e sobra so o anel: na captura do MODERNO as
	// gotas pequenas viravam PONTOS ESCUROS, como sujeira, e nao agua.
	borda = max(borda, bb * smoothstep(1.5, 3.5, raio * px_lado));
	inclina += ii * 1.4;
}


// O fio fino que corre no sentido do fluxo, entre as gotas paradas.
//
// A coluna INTEIRA rola: e isso que leva o fio de uma celula para a outra sem
// salto, e o motivo de nao haver renascimento no alto do vidro.
void fio(vec2 m, vec2 fluxo, float cob, float t, inout float mascara,
		inout vec2 inclina, inout float filme, inout float borda) {
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
	float bb;
	gota(d, raio, mm, ii, bb);
	if (mm > mascara) {
		mascara = mm;
	}
	borda = max(borda, bb);
	inclina += ii * 1.6;
	// O rastro: um filme fino ATRAS da gota (do lado de onde ela veio).
	float atras = smoothstep(0.0, 0.08, -f.y);
	filme = max(filme, smoothstep(0.16, 0.0, abs(f.x)) * atras * 0.7);
}


// Ruido de valor, suave. Para a sujeira, que nao pode ter a grade da gota.
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}


// Quanto da sujeira existe aqui, de 0 a 1, em METROS: mancha grande de 11 cm,
// grao de 2,5 cm e escorrido vertical de chuva seca.
float poeira(vec2 m) {
	float grande = ruido(m * 9.0 + vec2(3.7, 1.1));
	float grao = ruido(m * 40.0);
	float escorrido = ruido(vec2(m.x * 55.0, m.y * 6.0) + vec2(11.0, 0.0));
	return clamp(grande * 0.55 + grao * 0.25 + escorrido * 0.35 - 0.25, 0.0, 1.0);
}


// Este ponto esta no leque de UMA palheta? Borda macia, e a borda do angulo
// ondulada: um leque de compasso perfeito le como desenho, e nao como anos de
// borracha gasta.
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


// Desfoque de oito amostras em volta de `uv`, com raio em pixels.
vec3 desfocar(sampler2D tex, vec2 uv, float raio_px, vec2 px) {
	vec3 soma = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398 + 0.39;
		// Metade das amostras no raio inteiro, metade na metade: um anel so
		// deixa um fantasma nitido do mundo no meio.
		float k = (i % 2 == 0) ? 1.0 : 0.5;
		vec2 o = vec2(cos(ang), sin(ang)) * raio_px * k * px;
		soma += texture(tex, clamp(uv + o, vec2(0.001), vec2(0.999))).rgb;
	}
	return soma / 8.0;
}


void fragment() {
	vec2 m = metros;
	bool moderno = psx_facho_suave;
	float escala_gota = moderno ? 1.0 : ESCALA_GOTA_PS1;

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
	float anel = 0.0;
	// Pixels por metro de vidro, AQUI. Serve para decidir o que e pequeno demais
	// para ter contorno.
	float px_por_metro = 1.0 / max(length(fwidth(metros)) * 0.7071, 1e-6);
	if (cob > 0.001) {
		// Escala por estilo: coordenada dividida, e o tempo do fio tambem, para
		// a agua nao correr 2,5 vezes mais rapido no PS1.
		vec2 mg = m / escala_gota;
		fio(mg, fluxo, cob, TIME / escala_gota, mascara, inclina, filme, anel);
		// So a escala grande achata: e a unica com peso para isso.
		// `px_lado`: quantos pixels tem uma celula de cada escala. A escala
		// da coordenada entra nele — a celula de 1,4 cm no PS1 mede 3,5 cm.
		float px_m = px_por_metro * escala_gota;
		goticulas(mg, gota_grande, cob, 1.0, gota_grande * px_m,
			mascara, inclina, anel);
		goticulas(mg * 1.31 + vec2(7.3, 1.9), gota_media, cob * 0.92, 0.3,
			gota_media * px_m / 1.31, mascara, inclina, anel);
		goticulas(mg * 2.17 + vec2(3.1, 5.7), gota_fina, cob * 0.80, 0.0,
			gota_fina * px_m / 2.17, mascara, inclina, anel);
		if (moderno) {
			// Sem anel: a microgota e pequena demais para ter contorno, e o anel
			// a transformava em grao escuro.
			float anel_micro = 0.0;
			goticulas(m * 1.73 + vec2(5.9, 2.3), gota_micro, cob * 0.95, 0.0,
				gota_micro * px_por_metro / 1.73, mascara, inclina, anel_micro);
		}
	}
	// O filme ondula correndo morro abaixo: e a lamina fina que a palheta deixa
	// e a corredora arrasta, e ela so aparece porque entorta um pouco o mundo.
	float onda = sin(m.y * 90.0 - TIME * 6.0 + sin(m.x * 37.0) * 2.0)
		+ sin(m.y * 47.0 - TIME * 3.7 + m.x * 21.0);
	inclina += vec2(onda * 0.18, 0.0) * filme_mapa;

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
	// A borda sai dos METROS e do tamanho do vidro, porque a UV agora mora no
	// mapa de agua e nao na placa.
	vec2 borda = abs(m / max(tam_vidro, vec2(0.01)) - 0.5) * 2.0;
	float canto = smoothstep(0.45, 1.0, max(borda.x, borda.y));

	float forca_lente = moderno ? refracao_moderno : refracao;
	vec2 desvio = -n_visao.xy * forca_lente * por_metro * escala_gota
		* (mascara + filme * 0.25 + filme_mapa * 0.35);
	// A refracao some na borda do vidro. A tela so tem o que a camera ve, e
	// perto da borda o que ela ve alem do vidro e a coluna e o forro: a gota do
	// canto amostrava o teto e saia escura, quando a lente de verdade mostraria
	// o ceu que a camera nao alcanca.
	desvio *= 1.0 - smoothstep(0.78, 0.98, max(borda.x, borda.y));
	if (!moderno) {
		// PS1: o mundo refratado anda em passo de pixel da grade de 480x270.
		desvio = floor(desvio * vec2(480.0, 270.0)) / vec2(480.0, 270.0);
	}
	vec2 uv_visto = clamp(SCREEN_UV + desvio, vec2(0.001), vec2(0.999));
	vec3 mundo = texture(tela, uv_visto).rgb;
	if (moderno && dispersao > 0.0) {
		// Dispersao: o vermelho desvia menos que o azul. Tres amostras, so onde
		// ha lente — no vidro seco o desvio e zero e as tres coincidem.
		vec2 uv_r = clamp(SCREEN_UV + desvio * (1.0 - dispersao), vec2(0.001), vec2(0.999));
		vec2 uv_b = clamp(SCREEN_UV + desvio * (1.0 + dispersao), vec2(0.001), vec2(0.999));
		mundo = vec3(texture(tela, uv_r).r, mundo.g, texture(tela, uv_b).b);
	}
	float nevoa = clamp(embaca * (1.0 + borda_max * canto), 0.0, 1.0);

	// Embacado, do lado de dentro, com DESFOQUE: oito amostras num raio que
	// cresce com o embacado. Ele nao some onde a gota passa — gota e agua de
	// FORA —, e por isso a amostra sai do ponto JA refratado: atras de vidro
	// embacado a gota vira mancha mole, e nao lente nitida.
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float raio_desfoque = desfoque_px * (VIEWPORT_SIZE.y / ALTURA_BASE)
		* smoothstep(0.0, 0.6, embaca);
	vec3 fosco = desfocar(tela, uv_visto, max(raio_desfoque, 1.0), px);
	fosco = mix(fosco, cor.rgb * 0.55, 0.22);
	vec3 c = mix(mundo, fosco, nevoa);
	// A gota perde o contorno no embacado.
	anel *= 1.0 - nevoa;

	// O brilho que a gota devolve: e ele, e nao o que ela deixa passar, que faz
	// agua ser visivel contra mata escura a noite.
	float brilho = pow(clamp(nb.z * 0.28 + n_visao.y * 0.6, 0.0, 1.0), 3.0);
	c += cor.rgb * brilho * mascara * 0.5;
	if (moderno) {
		// Realce especular de verdade: a luz do ceu (de cima, no espaco do
		// mundo) refletida pela calota da gota na direcao do olho. E o ponto
		// branco no alto de cada gota que qualquer foto de para-brisa molhado
		// tem, e que um brilho difuso nao imita.
		vec3 v = normalize(-VERTEX);
		vec3 luz_ceu = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.25, 0.0)).xyz);
		vec3 meio = normalize(v + luz_ceu);
		float spec = pow(max(dot(n_visao, meio), 0.0), especular_dureza);
		// So na calota: sem isso o vidro plano inteiro acende no angulo certo.
		float calota = mascara * clamp(1.0 - nb.z, 0.0, 1.0) * 6.0;
		c += cor.rgb * spec * especular * clamp(calota, 0.0, 1.0) * intensidade;
		// Fresnel no anel: a borda da gota reflete o ceu, e nao so escurece.
		c += cor.rgb * 0.18 * anel * pow(1.0 - max(dot(n_visao, v), 0.0), 2.0);
	}
	// O anel escuro da gota. 0,22, e nao mais: com 0,30 e o anel de toda gota
	// visivel, o vidro lia sujo antes de ler molhado.
	c *= 1.0 - 0.22 * anel * intensidade;
	// A luz forte atras da gota a acende. Ver `limiar_brilho`.
	float luz = dot(mundo, vec3(0.299, 0.587, 0.114));
	float acende = max(0.0, luz - limiar_brilho) * brilho_fundo;
	float onde_acende = clamp(mascara * intensidade + filme_mapa * 0.4, 0.0, 1.0);
	c += mundo * acende * onde_acende;

	// Sujeira: por cima de tudo, do lado de fora, e mais fraca onde as palhetas
	// passam ha anos. Ela nao depende da chuva: o vidro sujo e sujo no sol.
	float leque = 0.0;
	if (tem_leque && tem_limpador > 0.5) {
		leque = max(no_leque(m, leque_a), no_leque(m, leque_b));
	}
	float suja = sujeira * poeira(m) * (1.0 - 0.85 * leque);
	// Molhada, a poeira escurece e fica menos opaca: a agua a assenta.
	suja *= 1.0 - 0.35 * clamp(cob * intensidade, 0.0, 1.0);
	c = mix(c, cor_sujeira.rgb * mix(0.6, 1.0, luz + 0.3), suja);

	float a = max(agua, nevoa);
	a = max(a, acende * onde_acende);
	a = max(a, suja);
	// O vidro limpo continua existindo: sem nada no vao, a janela volta a ler
	// como buraco na lataria.
	a = max(a, vidro_seco * (1.0 + borda_max * canto));
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
		} else if (depurar == 4) {
			ALBEDO = vec3(embaca);
		} else {
			ALBEDO = vec3(suja / max(sujeira, 0.001));
		}
		ALPHA = 1.0;
	}
}

// A agua NO vidro, vista de dentro do carro — para-brisa e janelas laterais.
//
// Por que isto existe
// -------------------
// A chuva da cena e um volume de particulas em volta da camera: ela cai, bate no
// chao e respinga. Nada disso acontece a trinta centimetros da lente, e e
// exatamente ali que a chuva aparece para quem esta dirigindo. Sem esta camada o
// plano de dentro do carro mostra um temporal la fora e um vidro perfeitamente
// limpo entre ele e o motorista — que le como se nao houvesse vidro nenhum.
//
// Por que foi reescrito (16/09/2026)
// ----------------------------------
// O jogador descreveu a versao anterior com precisao: "agua no vidro e uma foto
// piscando". O codigo tinha as quatro causas escritas:
//
//   1. a gota descia em QUATRO SALTOS (`floor(queda * 4.0) / 4.0`) — ela nao
//      escorria, ela teleportava entre quatro lugares;
//   2. a descida era `fract(TIME * ...)`, entao ao chegar embaixo a gota
//      RENASCIA em cima no mesmo quadro;
//   3. nao havia refracao: a gota era um anel da cor `cor` pintado a 42% de alfa
//      — tinta cinza em forma de rosquinha, e nao agua. O comentario dizia que
//      "nao ha textura de tela para amostrar", e ha: o Compatibility entrega
//      `hint_screen_texture` com tudo que e opaco, que e exatamente o mundo
//      atras do vidro;
//   4. o dither ordenado multiplicava o alfa em padrao fixo de tela, e com a
//      camera balancando na lombada o padrao cintilava sobre a gota.
//
// Medido antes de reescrever, no plano de dentro com chuva: 9,19% do vidro
// mudava entre dois quadros seguidos e 0,206% dava SALTO de mais de 60 niveis.
//
// Como e feita agora
// ------------------
// Tres camadas, todas continuas no tempo — nada nasce nem some num quadro so:
//
//   GOTICULAS  grade densa de gotas pequenas que CRESCEM e EVAPORAM devagar,
//              cada uma com a propria fase. E a agua parada que cobre o vidro.
//   CORREDORAS grade de colunas; cada celula tem uma gota grande que desce
//              deslizando — para, escorrega, para — numa curva continua, e a
//              coluna inteira rola junto, entao a gota passa de celula em
//              celula sem salto. Ela deixa um RASTRO: um fio limpo acima dela
//              com gotinhas residuais, que e o que o olho reconhece como agua
//              escorrendo em vidro.
//   EMBACADO   fora das gotas o vidro e levemente fosco (quatro amostras
//              deslocadas da tela, clareadas). Dentro da gota e do rastro, o
//              fosco some — a agua LIMPA o vidro por onde passa.
//
// Cada gota e uma LENTE: o que se ve dentro dela e a tela deslocada para o lado
// oposto do centro, ou seja o mundo invertido e comprimido. Um brilho no alto e
// uma borda escura embaixo fecham a leitura de volume.
//
// No PS1 STYLE (`psx_facho_suave` desligado) o deslocamento e quantizado em
// passos de pixel e o alfa volta a ser pontilhado — mas o MOVIMENTO continua
// continuo: o salto nao era o contrato de estetica, era o defeito.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled;

// O mundo atras do vidro. No Compatibility vem so com o que e opaco — estrada,
// mata, capo, painel — que e exatamente o que a agua tem de refratar.
uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear;

// Estilo em vigor (MODERNO liga). Ver `EstiloVisual`.
global uniform bool psx_facho_suave;

// Quanto a chuva esta apertando, de 0 a 1. Zero apaga a camada inteira.
uniform float intensidade : hint_range(0.0, 1.0) = 0.0;

// Quanta agua ja juntou desde a ultima passada do limpador, de 0 a 1. Quem move
// e o script, junto com a palheta que o jogador VE varrendo.
uniform float acumulo : hint_range(0.0, 1.0) = 1.0;

// Tom do brilho e do fosco. Frio: e o ceu encoberto que a agua devolve.
uniform vec4 cor : source_color = vec4(0.80, 0.85, 0.90, 1.0);

// Colunas de gotas corredoras na horizontal da placa. As goticulas usam o dobro.
uniform float celulas = 54.0;

// Quanto o ar empurra a agua, de 0 a 1 — escrito a partir da velocidade do carro.
// No para-brisa, a partir da metade a gota passa a SUBIR. Na janela lateral ela
// deita para tras.
uniform float vento : hint_range(0.0, 1.0) = 0.0;

// O rastro em meia lua que a palheta deixa.
uniform float rastro : hint_range(0.0, 1.0) = 0.14;

// 0 = para-brisa (tem limpador, vento sobe a gota). 1 = janela lateral (sem
// limpador, vento deita a gota para tras).
uniform float lateral : hint_range(0.0, 1.0) = 0.0;
// Para que lado da UV fica a traseira do carro na janela lateral: +1 ou -1.
uniform float sentido_traseira = 1.0;

// Altura / largura da placa. 1,06 / 1,78 no para-brisa.
uniform float proporcao = 0.6;

// Quanto a gota desloca o mundo atras dela, em fracao da tela.
uniform float refracao : hint_range(0.0, 0.2) = 0.02;
// Presenca do vidro lateral SECO. A janela lateral nao pode sumir quando para de
// chover: sem nada no vao, ela volta a ler como buraco na lataria. Um fosco leve
// que engrossa nos cantos e o bastante para o olho entender que ha vidro ali.
uniform float depurar_tela = 0.0;
uniform float vidro_seco : hint_range(0.0, 0.3) = 0.09;

// Quanto o vidro fica fosco onde nao ha agua escorrendo.
uniform float embacado : hint_range(0.0, 1.0) = 0.42;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// A curva de descida: para, escorrega, para. Continua e monotona — a gota nunca
// volta e nunca salta. `t` cresce sem limite; o resultado tambem.
float deslize(float t) {
	return t + 0.32 * sin(t * 6.2831) + 0.12 * sin(t * 12.566 + 1.3);
}

// Ruido de valor, baixa frequencia: o embacado nao e uniforme num vidro de
// verdade — ele junta nos cantos e onde o ar do desembacador nao chega.
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Uma gota como LENTE: mascara, deslocamento, brilho e borda.
//
// O que torna agua visivel a noite nao e o que ela deixa passar — escuro
// refratado sobre escuro quase nao muda nada. E o que ela DEVOLVE: um ponto de
// brilho no alto (a luz do painel, do farol, do ceu) e uma borda mais escura
// onde o vidro curva. Sao esses dois que o olho le como gota.
void lente(vec2 d, float raio, out float mascara, out vec2 desloc,
		out float brilho, out float borda) {
	float r = length(d);
	mascara = smoothstep(raio, raio * 0.55, r);
	// Deslocamento cresce para a borda: e ali que a lente curva mais.
	desloc = -d / max(raio, 0.0001) * mascara;
	brilho = smoothstep(raio * 0.30, 0.0,
		length(d - vec2(-0.28, -0.34) * raio)) * mascara;
	borda = smoothstep(raio * 0.55, raio * 0.95, r) * mascara;
}

// Goticulas paradas: a agua que nasce e evapora no vidro.
void goticulas(vec2 uv, vec2 aspecto, float t, out float mascara,
		out vec2 desloc, out float brilho, out float borda) {
	mascara = 0.0; desloc = vec2(0.0); brilho = 0.0; borda = 0.0;
	vec2 grade = aspecto * celulas * 1.9;
	vec2 p = uv * grade;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash21(id);
	if (h > 0.66) {
		return;
	}
	vec2 centro = (vec2(hash21(id + 3.1), hash21(id + 7.9)) - 0.5) * 0.55;
	// Nasce e evapora: um seno lento com fase propria, cortado embaixo. A gota
	// cresce de nada, fica, e encolhe ate nada — sem quadro de aparecer.
	float vida = sin(t * (0.16 + 0.22 * hash21(id + 1.7)) + h * 40.0);
	vida = smoothstep(-0.2, 0.8, vida);
	float raio = (0.12 + 0.24 * hash21(id + 5.3)) * vida;
	lente(f - centro, raio, mascara, desloc, brilho, borda);
}

// Corredoras: a gota grande que escorre, e o rastro que ela deixa.
void corredoras(vec2 uv, vec2 aspecto, float t, float sentido,
		out float gota, out float fio, out vec2 desloc,
		out float brilho, out float borda) {
	gota = 0.0; fio = 0.0; desloc = vec2(0.0); brilho = 0.0; borda = 0.0;
	vec2 grade = vec2(celulas * 0.34, celulas * 0.34 * aspecto.y / aspecto.x * 0.55);
	vec2 p = uv * grade;
	float coluna = floor(p.x);
	float hc = hash11(coluna + 11.0);
	// A coluna inteira rola: e isso que leva a gota de uma celula para a outra
	// sem salto. Cada coluna tem o proprio passo, entao nao ha fileira marchando.
	float velocidade = 0.35 + 0.65 * hc;
	// SUBTRAI: a UV do quad cresce para BAIXO, entao somar o deslocamento faria o
	// desenho subir. Com `sentido` positivo a agua desce.
	p.y -= deslize(t * velocidade * 0.22 + hc * 13.0) * sentido;
	vec2 id = floor(p);
	vec2 f = fract(p);
	float h = hash21(id);
	if (h > 0.62) {
		return;
	}
	// Dentro da celula a gota tambem balanca, com a propria fase — agua em
	// vidro nunca desce em linha reta.
	float x = 0.5 + (hash21(id + 2.3) - 0.5) * 0.5
		+ 0.05 * sin(f.y * 9.0 + h * 20.0);
	float y = 0.5 + 0.18 * sin(t * (0.6 + h) + h * 30.0);
	vec2 d = (f - vec2(x, y)) * vec2(grade.y / grade.x * 1.6, 1.0);
	// Lagrima: mais comprida do lado em que ela pesa.
	d.y *= mix(1.25, 0.78, step(0.0, d.y * sentido));
	float raio = 0.11 + 0.08 * hash21(id + 4.4);
	lente(d, raio, gota, desloc, brilho, borda);

	// O RASTRO, atras da gota: acima quando ela desce, abaixo quando o vento a
	// faz subir. E um filme de agua — fino, com o proprio desvio lateral — e nao
	// so um fio "limpo": sem refracao ele nao aparece contra a noite.
	float atras = smoothstep(0.0, 0.05, (y - f.y) * sentido);
	float largura = 0.045 * (1.0 - 0.5 * smoothstep(0.0, 1.0, abs(y - f.y)));
	float dx = f.x - x;
	float filme = smoothstep(largura, 0.0, abs(dx)) * atras
		* smoothstep(1.0, 0.1, abs(y - f.y));
	fio = filme;
	desloc.x += -sign(dx) * filme * 0.35;
	// Gotinhas residuais no fio: a agua que a corredora deixou para tras.
	float passo_res = f.y * 8.0 + h * 3.0;
	float residuo = fract(passo_res);
	float existe = step(0.35, hash11(floor(passo_res) + h * 50.0));
	float m; vec2 dd; float bb; float kk;
	lente(vec2(dx * 7.0, (residuo - 0.5)) * 0.35, 0.09 * existe, m, dd, bb, kk);
	m *= atras * smoothstep(1.0, 0.0, abs(y - f.y));
	gota = max(gota, m * 0.8);
	desloc += dd * m * 0.6;
	brilho = max(brilho, bb * m);
}

void fragment() {
	// O para-brisa seco some inteiro (ele e so a agua). A janela lateral seca
	// continua existindo — ver `vidro_seco`.
	if (intensidade <= 0.001 && lateral < 0.5) {
		ALPHA = 0.0;
	} else {
		vec2 uv = UV;
		// Proporcao da placa (altura / largura): sem ela as gotas saem ovais
		// numa placa larga. Quem escreve e o script, que sabe o tamanho do quad.
		vec2 aspecto = vec2(1.0, proporcao);

		// Na janela lateral o vento deita a agua para a traseira: gira a UV.
		float inclina = lateral * vento * 0.9 * sentido_traseira;
		vec2 cuv = uv - 0.5;
		uv = vec2(cuv.x * cos(inclina) - cuv.y * sin(inclina),
			cuv.x * sin(inclina) + cuv.y * cos(inclina)) + 0.5;

		// Sentido da descida. No para-brisa o ar vence o peso a partir da metade
		// e a gota sobe; na lateral ela sempre desce (quem deita e o giro acima).
		float sentido = mix(mix(1.0, -1.25, smoothstep(0.35, 0.8, vento)), 1.0, lateral);
		float t = TIME;

		float g_m; vec2 g_d; float g_b; float g_k;
		goticulas(uv, aspecto, t, g_m, g_d, g_b, g_k);
		float c1_g; float c1_f; vec2 c1_d; float c1_b; float c1_k;
		corredoras(uv, aspecto, t, sentido, c1_g, c1_f, c1_d, c1_b, c1_k);
		float c2_g; float c2_f; vec2 c2_d; float c2_b; float c2_k;
		corredoras(uv * 1.37 + 0.21, aspecto, t * 1.13 + 7.0, sentido,
			c2_g, c2_f, c2_d, c2_b, c2_k);

		// O limpador leva a agua; o que sobra cresce de volta com `acumulo`. Na
		// lateral nao ha limpador.
		float junta = mix(acumulo, 1.0, lateral);
		float agua = max(g_m, max(c1_g, c2_g * 0.85)) * junta;
		float fio = max(c1_f, c2_f * 0.85) * junta;
		float limpo = max(agua, fio);
		vec2 desloc = (g_d * 0.7 + c1_d + c2_d * 0.85) * junta;
		float brilho = max(g_b * 0.8, max(c1_b, c2_b)) * junta;
		float borda = max(g_k, max(c1_k, c2_k)) * junta;

		bool moderno = psx_facho_suave;
		// Tamanho do pixel pelo VIEWPORT, e nao por `textureSize(tela)`: a copia de
		// tela do Compatibility nao responde o proprio tamanho de forma confiavel,
		// e um pixel medido errado mandava as quatro amostras do fosco para fora
		// da tela — onde `repeat_disable` as prende na BORDA, que e o ceu claro.
		// A janela lateral saia como uma parede cinza-clara, media 120 onde a
		// mata escura media 50.
		vec2 px = 1.0 / VIEWPORT_SIZE;
		vec2 desvio = desloc * refracao;
		if (!moderno) {
			// PS1: o mundo refratado anda em passo de pixel da grade de 480x270.
			desvio = floor(desvio * vec2(480.0, 270.0)) / vec2(480.0, 270.0);
		}
		vec2 suv = SCREEN_UV + desvio;
		vec3 mundo = texture(tela, clamp(suv, vec2(0.001), vec2(0.999))).rgb;

		// O fosco: quatro amostras deslocadas, clareadas pelo tom do ceu. Ele
		// NAO vale dentro da agua nem do rastro — a gota limpa o vidro.
		vec2 o = px * 2.5;
		vec3 fosco = (texture(tela, SCREEN_UV + vec2(o.x, o.y)).rgb
			+ texture(tela, SCREEN_UV + vec2(-o.x, o.y)).rgb
			+ texture(tela, SCREEN_UV + vec2(o.x, -o.y)).rgb
			+ texture(tela, SCREEN_UV + vec2(-o.x, -o.y)).rgb) * 0.25;
		fosco = mix(fosco, cor.rgb * 0.55, 0.22);
		// Embacado em manchas: mais nos cantos, menos no meio, e com ruido lento.
		vec2 borda_placa = abs(UV - 0.5) * 2.0;
		float canto = smoothstep(0.35, 1.0, max(borda_placa.x, borda_placa.y));
		float manchas = ruido(UV * vec2(4.0, 4.0 / proporcao) + t * 0.02);
		float nevoa = embacado * mix(0.55, 1.15, manchas) * mix(0.8, 1.25, canto)
			* (1.0 - smoothstep(0.0, 0.5, limpo)) * mix(0.55, 1.0, junta);

		vec3 c = mix(fosco, mundo, smoothstep(0.0, 0.45, max(agua, fio)));
		// O brilho soma a luz que a gota devolve; a borda escurece a curva.
		c += cor.rgb * brilho * 0.85;
		c *= 1.0 - borda * 0.45;

		// A meia lua da palheta: nasce com o vidro limpo e some quando a agua
		// volta a cobrir tudo. So no para-brisa.
		float arco = (1.0 - lateral) * smoothstep(0.5, 0.0, acumulo) * rastro
			* smoothstep(0.0, 0.35, abs(fract(UV.y * 5.0) - 0.5));
		c = mix(c, fosco, arco * 0.5);

		float a = max(smoothstep(0.0, 0.3, max(agua, fio * 0.8)), nevoa);
		a = max(a, arco * 0.3);
		a *= intensidade;
		if (lateral > 0.5) {
			float presenca = vidro_seco * mix(0.6, 1.4, canto);
			if (a < presenca) {
				c = mix(c, fosco, 1.0 - a / max(presenca, 0.001));
				a = presenca;
			}
		}

		if (!moderno) {
			// Pontilhado MULTIPLICADO, nunca somado: somado, metade do padrao
			// pinta alfa onde nao ha agua e vira veu leitoso no quadro inteiro.
			int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
			a *= 1.0 + (BAYER[idx] / 16.0 - 0.5) * 0.45;
		}

		ALBEDO = c;
		ALPHA = clamp(a, 0.0, 1.0);
		if (depurar_tela > 0.5) {
			ALBEDO = texture(tela, SCREEN_UV).rgb;
			ALPHA = 1.0;
		}
	}
}

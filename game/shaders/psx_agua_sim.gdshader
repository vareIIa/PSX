// O mapa de agua: um passo de simulacao por quadro, num viewport que nao limpa.
//
// Por que a agua precisa de memoria
// ---------------------------------
// Ate a Fase 3 a agua do vidro era UM numero por carro: `cobertura`. Com um
// numero so, tudo o que acontece no vidro acontece no vidro INTEIRO. O leque do
// limpador precisou ser resolvido em forma fechada, invertendo o cosseno da
// manivela, porque nao havia onde guardar "aqui ja passou". E o que nao cabe em
// forma fechada simplesmente nao existia: a corredora descia e nao deixava
// rastro, a palheta nao deixava residuo, e sujeira — o leque fosco que todo
// para-brisa velho tem — nao tinha onde morar.
//
// Aqui o estado e uma TEXTURA. O viewport roda com `CLEAR_MODE_NEVER`, um
// `BackBufferCopy` copia o quadro anterior antes deste desenhar, e este shader
// le esse quadro e escreve o proximo. Tres canais:
//
//   R  cobertura de gota parada    sobe com a chuva, desce com o limpador,
//                                  com a trilha da corredora e com a secagem
//   G  filme                       o rastro da corredora e o residuo que a
//                                  borracha deixa no fim da passada
//   B  embacado                    do lado de DENTRO; nem gota nem limpador o
//                                  tocam, so o desembacador
//
// Precisao — medido, nao estimado (16/09/2026)
// -------------------------------------------
// Um passo de 0,0005 por quadro (0,13 do degrau de 1/255) some INTEIRO no
// RGBA8: vinte quadros somaram 0,0000 nos dois renderizadores. Arredondamento
// estocastico, que parecia a saida elegante, entregou 0,0039 de 0,0100 no
// Forward+ e nada no Compatibility. Com `use_hdr_2d` o mesmo passo soma 0,0098
// de 0,0100 nos dois. Por isso o viewport nasce com `use_hdr_2d = true`, e nao
// com ruido.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

// O proprio quadro anterior, via BackBufferCopy.
uniform sampler2D anterior : hint_screen_texture, repeat_disable, filter_nearest;

const int MAX_PAINEIS = 10;
const int MAX_TRILHAS = 48;

uniform float dt = 0.016;
// Esta caindo chuva agora, de 0 a 1.
uniform float chuva : hint_range(0.0, 1.0) = 0.0;
// Quanto o ar empurra a agua, de 0 a 1 — vem da velocidade do carro.
uniform float vento : hint_range(0.0, 1.0) = 0.0;
// Umidade de dentro, que embaca, e o desembacador, que abre.
uniform float umidade : hint_range(0.0, 1.0) = 0.0;
uniform float desembacador : hint_range(0.0, 1.0) = 0.0;

// Texels por metro. Um so para o mapa inteiro: e o que faz a gota ter o mesmo
// tamanho no para-brisa e no quebra-vento.
uniform float tpm = 200.0;
uniform vec2 tamanho_mapa = vec2(512.0, 256.0);

// Retangulo de cada vidro no mapa, em UV, e os dados dele:
// (largura_m, altura_m, exposicao a chuva, tem limpador).
uniform int n_paineis = 0;
uniform vec4 painel_rect[MAX_PAINEIS];
uniform vec4 painel_dados[MAX_PAINEIS];

// O setor varrido NESTE quadro: do angulo de antes ao de agora. E a diferenca
// que limpa, e nao a posicao — e por isso que o criterio C6 (">= 90% dos texels
// que perdem agua estao dentro do setor varrido nesse quadro") e uma pergunta
// com resposta, e nao uma esperanca.
uniform int limpador_painel = -1;
uniform vec2 pivo_a = vec2(0.0);
uniform vec2 pivo_b = vec2(0.0);
uniform vec2 raios = vec2(0.10, 0.55);
uniform float ang_de = 0.0;
uniform float ang_ate = 0.0;
uniform float palheta = 0.035;
uniform float limpador_ativo : hint_range(0.0, 1.0) = 0.0;

// Rastro das corredoras: segmentos em UV do mapa, ponta a ponta.
uniform int n_trilhas = 0;
uniform vec4 trilha[MAX_TRILHAS];
// Meia largura do rastro, em metros.
uniform float trilha_larg = 0.006;

// Segundos, com chuva cheia e exposicao cheia, para o vidro encher de gota.
uniform float tempo_encher = 5.0;
// Segundos para secar sem chuva.
uniform float tempo_secar = 45.0;
// Segundos para o filme escorrer e sumir.
uniform float tempo_filme = 2.2;
// Segundos para o embacado chegar perto do equilibrio.
uniform float tempo_embacar = 12.0;


// Distancia de um ponto a um segmento, tudo em texels.
float dist_segmento(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float l2 = dot(ab, ab);
	float t = (l2 > 1e-6) ? clamp(dot(p - a, ab) / l2, 0.0, 1.0) : 0.0;
	return distance(p, a + ab * t);
}


// O ponto caiu dentro do setor varrido neste quadro?
//
// O angulo e medido do eixo que sobe o vidro, igual ao do `Limpador`. O setor
// cresce meia palheta para cada lado: a borracha tem largura, e sem ela a
// passada deixa listras de agua entre um quadro e o outro quando o limpador
// esta na velocidade 2.
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
	// Borda macia so na ponta do raio: a agua nao acaba num degrau de texel.
	return smoothstep(raios.x, raios.x + 0.02, r)
		* smoothstep(raios.y, raios.y - 0.02, r);
}


void fragment() {
	vec3 mapa = texture(anterior, SCREEN_UV).rgb;
	float cob = mapa.r;
	float filme = mapa.g;
	float embaca = mapa.b;

	// Em que vidro este texel caiu. Fora de todos, o mapa fica preto: e a
	// calha entre os retangulos, e ninguem a le.
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
	// `return` no `fragment()` nao existe na linguagem de shader do Godot: o
	// resto do passo fica dentro do `if`, e fora dele o texel e a calha entre
	// os retangulos, que ninguem le.
	if (qual < 0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {

		// 1. A chuva enche. Quanto, depende de quanto o vidro ve o ceu e a frente:
		// e a `exposicao`, calculada no script a partir da normal do vidro e da
		// velocidade do carro. O para-brisa a 80 km/h recebe muito mais agua por
		// segundo que o vigia parado, e e isso que faz o motorista acelerar o
		// limpador na estrada e nao na cidade.
		float entra = chuva * dados.z * (1.0 + 0.9 * vento) / max(tempo_encher, 0.05);
		cob += entra * dt;

		// 2. Seca. Devagar, e mais depressa com vento.
		cob -= dt * (1.0 - chuva * dados.z) * (1.0 + vento) / max(tempo_secar, 0.05);
		filme -= dt / max(tempo_filme, 0.05);

		// 3. O limpador. Onde a borracha passou NESTE quadro a gota some e fica o
		// filme: o vidro nao fica seco atras da palheta, fica lavado.
		if (limpador_ativo > 0.5 && qual == limpador_painel && dados.w > 0.5) {
			float s = max(varrido(m, pivo_a), varrido(m, pivo_b));
			if (s > 0.0) {
				cob = mix(cob, cob * 0.04, s);
				filme = max(filme, s * mix(0.25, 0.75, cob));
			}
		}

		// 4. O rastro da corredora: ela come a agua por onde passa e deixa a faixa
		// molhada. E o que faz o risco vertical continuar visivel depois de a gota
		// ja ter descido — sem isto, a corredora e um ponto andando num vidro que
		// nao a conhece.
		vec2 px = UV * tamanho_mapa;
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

		// 5. Embacado, do lado de dentro. Independente: nem a gota nem a palheta o
		// tocam. Quem abre e o desembacador, num leque que sobe da base.
		//
		// Vai para um EQUILIBRIO, e nao numa rampa. Integrado sem teto —
		// `embaca += umidade * dt * 0.25` — ele chega a 1,0 em vinte e cinco
		// segundos de chuva, e ai o para-brisa vira uma parede leitosa: nem a
		// estrada nem as proprias gotas aparecem. Foi o que a primeira medida da
		// Fase 4 mostrou, e o mapa denunciou na hora (canal B chapado em 255).
		// Vidro embaca ate a umidade de dentro e a de fora se acertarem, e para.
		embaca += (umidade - embaca) * dt / max(tempo_embacar, 0.05);
		// O desembacador so existe no para-brisa (o unico vidro com limpador),
		// e abre no LEQUE classico: sai das grelhas na base, sobe mais no meio
		// que nas pontas. `d` e a distancia a base, de 0 (embaixo) a 1 (no
		// alto); a parabola diz ate onde o ar quente chega em cada coluna, e o
		// alcance cresce com a forca do ventilador.
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

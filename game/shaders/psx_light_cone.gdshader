// Facho de luz como geometria somada. O jeito que o PS1 fazia.
//
// O ART-BIBLE secao 8 proibe nevoa volumetrica com raymarch, e a proibicao segue
// valendo. Isto nao e raymarch: e um tronco de cone translucido somado por cima
// da cena, com o degrade na cor de vertice. Silent Hill e Resident Evil faziam
// exatamente assim, e por isso o facho aparece facetado em vez de suave.
//
// A intensidade sobe com a densidade da nevoa, porque e a nevoa que da o que
// iluminar. Com nevoa desligada o facho quase some, que e o correto.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting;

// Multiplicador global. A cor de cada lampada vem da cor de vertice do cone,
// senao o material compartilhado faria todos os postes terem a mesma cor.
uniform vec4 cor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensidade : hint_range(0.0, 4.0) = 1.0;

// Modulada pelo script da lampada. E instance uniform para cada poste piscar no
// seu proprio ritmo sem duplicar material.
instance uniform float piscar = 1.0;

// O facho some de longe: somar geometria brilhante no fundo da rua entrega o
// truque e polui o horizonte.
uniform float fade_inicio = 12.0;
uniform float fade_fim = 26.0;

// Fatia de perto, para a camera nao entrar dentro de um bloco de luz solido.
uniform float fade_perto = 1.2;

uniform vec2 snap_resolution = vec2(240.0, 135.0);
uniform bool use_snap = true;

// MODERNO liga as tres correcoes abaixo; PS1 STYLE deixa o cone como o console
// fazia. E `global uniform` pelo mesmo motivo de `psx_snap`: uma escrita do
// EstiloVisual alcanca o facho de todo poste e de todo carro da cidade.
global uniform bool psx_facho_suave;

// Quanta chuva esta caindo agora, de 0 a 1. Escrito pelo Clima.
//
// O facho de um farol na chuva nao e um cone liso: ele e um cone com AGUA
// dentro, e a agua e o que torna o cone visivel em primeiro lugar. Sem isto, a
// unica coisa da cena que atravessa o facho e a propria chuva desenhada por
// fora dele, e o feixe fica com a superficie lisa de um volume de nevoa parado
// enquanto tudo em volta esta sendo furado por gota.
global uniform float psx_chuva;


// A profundidade do que ja foi desenhado. No Godot 4.7 o `DEPTH_TEXTURE`
// embutido deixou de existir e virou uniforme com hint; sem `filter_nearest` a
// leitura sai interpolada entre pixels de profundidades muito diferentes, o que
// inventa uma borda fantasma na silhueta de quem esta na frente do facho.
uniform sampler2D tex_profundidade : hint_depth_texture, repeat_disable, filter_nearest;

// Quanto o facho some ao encostar no cenario, em metros.
//
// Esta e a correcao que mais muda a imagem. O cone e translucido mas o TESTE DE
// PROFUNDIDADE nao: onde o tronco de cone atravessa o asfalto, o poligono e
// cortado a faca e sobra uma reta atravessando a tela. Foi isso que leu como
// "chapa de vidro fosco" — a borda reta nao pertence a luz nenhuma, e a linha
// de corte da GEOMETRIA do cone.
//
// Um metro e meio: menos que isso ainda deixa a reta visivel de perto, mais que
// isso apaga o facho inteiro quando ele corre rente ao chao, que e o caso do
// farol de carro.
const float FUNDIR_CENARIO = 2.5;

// Teto do facho no MODERNO, como fracao do que o PS1 STYLE desenha.
//
// O cone era somado a 0,55 de alfa vezes 0,66 de `facho_forca` — e com
// `cull_disabled` as DUAS paredes do tubo somam, entao o pixel no meio do facho
// recebia cerca de 0,73 de branco somado sobre uma rua quase preta. Isso nao e
// luz no ar, e tinta branca por cima da cena: o predio atras do facho sumia.
const float TETO_MODERNO = 0.95;

// Onde o facho desaparece porque a camera entrou nele.
//
// A aproximacao de corda so vale olhando o tubo DE FORA. De dentro ela e falsa
// em toda parte: a parede oposta fica de frente para a camera, a corda vale
// quase 1 em todo pixel dela, e o resultado e um cobertor cinza cobrindo a tela
// inteira. Foi o que apareceu quando o cone passou a apontar direito — nao um
// defeito novo, um defeito que estava escondido atras do outro.
//
// O modelo de verdade tambem concorda: quem esta DENTRO do facho nao ve facho
// nenhum, ve a fonte estourada de luz na cara. Esse brilho ja existe, e o halo
// do glow. Aqui basta parar de desenhar por cima dele.
//
// Medido em raios do cone: 1,0 e exatamente a parede. Some de vez a 0,85 e
// aparece inteiro a 1,6 — a faixa e larga para um carro que cruza a calcada nao
// acender o proprio facho de um quadro para o outro.
const float DENTRO_SOME = 0.85;
const float DENTRO_CHEIO = 1.6;

// A quantos metros da fonte o ar aceso cai a metade.
//
// O alfa do cone ja caia com o quadrado, mas NORMALIZADO pelo comprimento da
// malha: metade do caminho e metade do caminho tanto num facho de 6 m quanto
// num de 1 m. Foi isso que deixou o poste com um triangulo de seis metros de
// altura e tres de raio atravessado na tela — um cone daquele tamanho e um
// holofote de estadio, nao uma luminaria de rua, e ele ficava igualmente forte
// do topo ate quase o chao.
//
// Em METROS o mesmo numero serve aos dois: o facho curto do farol continua
// inteiro no trecho em que existe, e o cone longo do poste vira um halo em
// volta da lampada que se desmancha antes de chegar na calcada — que e o que se
// ve numa rua de verdade debaixo de chuva.
const float MEIA_LUZ = 4.5;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

varying float v_alpha;
/// Distancia da camera ao eixo do facho, medida em raios do cone na altura dela.
/// Abaixo de 1 a camera esta dentro. Ver DENTRO_SOME.
varying float v_dentro;
/// Distancia em metros deste ponto ate a fonte. O cone nasce na origem da malha.
varying float v_da_fonte;
varying float v_dist;
varying vec3 v_cor;
varying vec3 v_normal_view;
varying vec3 v_pos_view;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// O facho tem que tremer junto com o cenario. Sem snap ele desliza sobre a
	// geometria e denuncia que e um objeto separado.
	if (use_snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		ndc.xy = floor(ndc.xy * snap_resolution) / snap_resolution;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;

	v_alpha = COLOR.a;
	v_cor = COLOR.rgb;

	// Onde a camera esta em relacao a este cone, no espaco do proprio cone.
	//
	// As medidas saem da MALHA, e nao de uniformes que o script teria de manter
	// em dia: o cone cresce em -Y a partir da fonte, e a UV.y de cada vertice ja
	// e a fracao percorrida. Dividir uma pela outra devolve a altura, e o raio
	// do vertice dividido pela mesma fracao devolve a abertura. Assim a lampada
	// do poste e o farol do carro — cones de tamanhos bem diferentes — usam o
	// mesmo material sem passar um numero sequer.
	v_da_fonte = length(VERTEX);

	vec3 cam_obj = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX[3]).xyz;
	float altura = (UV.y > 0.004) ? (-VERTEX.y / UV.y) : 1.0;
	float ao_longo = -cam_obj.y;
	float u = clamp(ao_longo / max(altura, 0.001), 0.0, 1.0);
	float raio_local = (UV.y > 0.004)
		? length(VERTEX.xz) * max(u, 0.02) / UV.y
		: 0.001;
	v_dentro = length(cam_obj.xz) / max(raio_local, 0.001);
	// Atras da fonte, ou passado o fim do cone, a camera esta fora aconteca o
	// que acontecer com o raio — e la o facho aparece inteiro. E o caso de quem
	// dirige: o farol nasce na frente da camera e o motorista ve o proprio facho
	// na chuva, que e justamente o que se quer.
	if (ao_longo < -0.35 || ao_longo > altura + 1.0) {
		v_dentro = 99.0;
	}
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_pos_view = pv;
	v_dist = length(pv);
	v_normal_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float a = v_alpha * intensidade * piscar;

	// Quanta luz ha na frente deste pixel.
	//
	// O termo e a CORDA: para um tubo visto de lado, a espessura de ar acesa
	// atravessada pelo raio de visao vale exatamente |dot(N, V)| — cheia no meio
	// do tubo, zero na silhueta. O termo ja estava certo; o que o estragava era
	// o `smoothstep(0.0, 0.5, ...)` em volta dele, que SATURA: tudo acima da
	// metade virava 1,0, e o facho ganhava um platô chapado com borda dura em
	// vez de um nucleo brilhante que se desmancha para fora.
	float encaramento = abs(dot(normalize(v_normal_view), normalize(-v_pos_view)));
	if (psx_facho_suave) {
		// Ao quadrado: cai mais rapido na borda que no meio, que e o que da
		// nucleo ao facho. Linear le como tubo de neon, nao como ar aceso.
		a *= encaramento * encaramento;
		a *= TETO_MODERNO;
		a *= smoothstep(DENTRO_SOME, DENTRO_CHEIO, v_dentro);
		// Queda em metros, e nao em fracao do cone. Ver MEIA_LUZ.
		float meia = MEIA_LUZ * MEIA_LUZ;
		a *= meia / (meia + v_da_fonte * v_da_fonte);
	} else {
		a *= smoothstep(0.0, 0.5, encaramento);
	}

	a *= 1.0 - smoothstep(fade_inicio, fade_fim, v_dist);
	a *= smoothstep(0.0, fade_perto, v_dist);

	// Onde o facho encosta no mundo, ele se apaga em vez de ser cortado.
	//
	// Le a profundidade do que ja foi desenhado e compara com a deste pixel. O
	// cone nao escreve profundidade (`depth_draw_never`), entao o que esta no
	// buffer e o cenario solido: asfalto, meio-fio, lataria. Quanto mais perto o
	// facho chega dele, mais transparente fica — e a reta que denunciava o
	// poligono simplesmente deixa de existir.
	if (psx_facho_suave) {
		float bruto = texture(tex_profundidade, SCREEN_UV).x;
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, bruto);
		vec4 vista = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		float cena = -(vista.z / vista.w);
		a *= smoothstep(0.0, FUNDIR_CENARIO, cena + v_pos_view.z);
	}

	// Dither na transparencia. O PS1 nao tinha alfa por pixel de verdade: ele
	// alternava pixels num padrao ordenado, e e isso que da o facho granulado
	// em vez de um degrade limpo de motor moderno.
	//
	// MULTIPLICA, e nao soma. Somado ele nao respeitava o zero: com `a` em 0 o
	// termo ainda entregava ate +0,06 de alfa, e 0,06 de branco SOMADO sobre uma
	// rua noturna aparece. O resultado era um fantasma pontilhado do tronco de
	// cone — chapado, do tamanho da malha inteira, sem borda e sem degrade,
	// imune a distancia, a corda e a qualquer desvanecimento — deitado por cima
	// da cena. Era ele, e nao a luz, o que o jogador via como vidro fosco.
	//
	// Como fator o grao continua onde o facho existe e some junto com ele, que e
	// o que o dither do console fazia: ele granulava a transparencia, nao criava
	// transparencia onde nao havia nenhuma.
	// A chuva DENTRO do feixe.
	//
	// Riscos que descem atravessando o cone, ancorados na posicao de VISTA e nao
	// na UV da malha: presos a UV eles girariam junto com o cone e a chuva
	// pareceria presa ao carro. O padrao e grosseiro de proposito — duas senoides
	// e um degrau, sem textura — porque a esta escala uma gota tem um pixel e
	// meio, e o que o olho le nao e a gota: e a INTERRUPCAO do feixe.
	//
	// Multiplica o alfa em vez de somar brilho: agua atravessando luz nao acende
	// nada, ela tira luz de um lugar e poe em outro. Somado, o facho ganhava
	// riscos brancos por cima e virava um chuveiro aceso.
	if (psx_chuva > 0.01) {
		vec2 gota = v_pos_view.xy * 7.0;
		// MAIS, e nao menos. `gota` esta em espaco de VISTA, onde +Y e para
		// cima na tela. Com menos, um risco fixo do padrao satisfaz
		// 7*y - 9*t = c, ou seja y = (c + 9t)/7, que CRESCE com o tempo: a
		// chuva dentro do feixe subia. E o que o jogador via como "parece
		// que sobe algo pela luz".
		gota.y += TIME * 9.0;
		float risco = fract(sin(dot(floor(gota), vec2(12.99, 78.23))) * 43758.5);
		float faixa = step(0.72, risco) * (1.0 - fract(gota.y));
		a *= 1.0 - faixa * psx_chuva * 0.45;
	}

	int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
	a *= 1.0 + (BAYER[idx] / 16.0 - 0.5) * 0.24;

	ALBEDO = cor.rgb * v_cor;
	ALPHA = clamp(a, 0.0, 1.0);
}

## O iPhone 4S da abertura, modelado: e nele que o jogador le a desculpa sendo
## apagada, e e ele que cai no assoalho aceso.
##
## Por que existe
## --------------
## O aparelho era uma caixa preta com um quad em cima. Na leitura ele enche meio
## quadro, e tres coisas o denunciavam: a quina viva (o 4S tem canto de quase
## nove milimetros), o vidro claro (a luz da propria tela, a um palmo, acendia o
## preto de azul, e a nevoa da cabine o lavava de cinza) e a falta de tudo que
## faz um iPhone ser um iPhone — a fresta do alto-falante, a camera, o botao
## home com o quadradinho, a banda de aco com as frestas da antena.
##
## O que ha aqui
## -------------
## A banda de aco e um perfil levado em volta do contorno de canto arredondado:
## o lado reto de ponta a ponta da espessura, um chanfro polido de meio
## milimetro em cada borda e um friso chato que abraca o vidro. Os dois vidros
## sao tampas rentes a ela. Tudo o que e furo, fresta ou tinta (grades, conector,
## parafusos, a gaveta do chip, o alto-falante com a tela de metal, o botao
## home, as cameras e o flash) e desenhado no shader, por distancia com sinal no
## espaco do aparelho: sai nitido a qualquer distancia da lente e nao custa
## textura nenhuma. Os botoes que saltam da banda (volume, silencio, liga) sao
## malha de verdade, com o mesmo chanfro.
##
## Por que o aco tem um estudio falso
## ----------------------------------
## Aco polido nao tem cor: ele e o que reflete. Na cabine as onze da noite nao
## ha o que refletir, e a banda saia como um fio escuro tingido pela luz vermelha
## do painel. O shader reflete, entao, um estudio de fotografia de produto
## inventado (caixa de luz em cima, duas tiras estreitas dos lados, o horizonte),
## preso a CAMERA: o vetor refletido em espaco de vista passa por ele e entra
## como emissao. E por isso que o chanfro risca de claro quando o aparelho gira.
## O pico fica perto de 1 de proposito, abaixo do limiar do glow (1,25): e prata
## polida, nao lampada.
##
## Tudo do aparelho mora na camada `CAMADA`, que a luz da tela nao alcanca: ela
## pinta a mao, o queixo e o tapete, e nao o vidro de onde sai.
class_name Iphone4S
extends Node3D

## 58,6 x 115,2 x 9,3 mm, e o raio do canto visto de frente.
const TAMANHO := Vector3(0.0586, 0.1152, 0.0093)
const RAIO_CANTO := 0.0088
## A tela: 49,9 x 74,9 mm no aparelho de verdade. Aqui 146 x 219 da grade do app
## (`TelaDoCelular.ALTO`), na mesma escala.
const TELA := Vector2(0.0494, 0.0741)
## Centro do alto-falante e do botao home, em y a partir do centro.
const Y_ALTO_FALANTE := 0.0478
const Y_BOTAO := -0.0478
const RAIO_BOTAO := 0.0056
## Camada de render que a luz da tela nao ilumina.
const CAMADA := 1 << 18
## A tela acesa nao e branca de verdade: na cabine as onze da noite ela estouraria.
const TELA_CHEIA := 0.86
## A luz da tela: fria, curta. E ela que pinta a mao e, no chao, o tapete.
const LUZ_COR := Color(0.62, 0.82, 1.0)
const LUZ_ALCANCE := 0.75
const LUZ_FORCA := 0.9
## A luz dos bracos: expoente da queda (a da tela usa o padrao do Godot, 1) e o
## ganho que a iguala a da tela na leitura — medido na bancada
## (`bancada_braco_chao --so-leitura`, media do polegar: 202 com a luz da tela,
## 202 com esta). A dois dedos ela fica duas vezes e meia menos estourada.
const LUZ_MAO_QUEDA := 0.5
const LUZ_MAO_GANHO := 2.5

# --- a banda -----------------------------------------------------------------
## O chanfro polido de cada borda da banda, a 45 graus. E ele que risca de luz
## em volta do vidro; abaixo de meio milimetro ele some em 1080p.
const CHANFRO := 0.00055
## O friso chato entre o chanfro e o vidro.
const FRISO := 0.00012
## Passos por canto do contorno: com 12 o erro da silhueta fica em 0,02 mm, abaixo
## do pixel mesmo com o aparelho enchendo o quadro em 4K.
const PASSOS_CANTO := 12
## O aco: cor (a refletancia do inox, meio fria), aspereza e o quanto o estudio
## falso aparece nele.
const ACO_COR := Color(0.80, 0.81, 0.83)
const ACO_ASPEREZA := 0.14
const ACO_ESTUDIO := 1.0
## O vidro: quanto o estudio aparece na capa de vidro (ja multiplicado pelo
## Fresnel, 4% de frente) e nas pecas de baixo dela (tela do alto-falante, lente).
const VIDRO_CAPA := 0.3
const VIDRO_PECAS := 1.0
## A quina do vidro arredonda nos ultimos 0,3 mm antes do aco.
const VIDRO_QUINA := 0.0003

# --- o que ha na banda (metros, no espaco do aparelho) ------------------------
## As quatro frestas da antena do 4S: nos lados compridos, perto dos cantos.
const FRESTA_Y := 0.0463
const FRESTA := 0.0010
## Base: o conector de 30 pinos, os parafusos pentalobe e as duas grades.
const DOCA_MEIA := Vector2(0.0106, 0.00135)
const DOCA_RAIO := 0.0011
const PARAFUSO_X := 0.01235
const PARAFUSO_REBAIXO := 0.00078
const PARAFUSO_CABECA := 0.00064
const GRADE_X0 := 0.0142
const GRADE_PASSO := 0.00098
const GRADE_FURO := 0.00032
const GRADE_FILEIRA := 0.00046
const GRADE_N := 6
## Topo: o fone de 3,5 mm, o microfone de ruido e o liga/desliga.
const FONE_X := -0.0165
const FONE_R := 0.0019
const MIC_X := -0.0123
const MIC_R := 0.00032
const LIGA_X := 0.0148
const LIGA := Vector3(0.0094, 0.0023, 0.00065)
## Esquerda: a chave de silencio e os dois volumes redondos.
const CHAVE_Y := 0.0405
const CHAVE_FURO := Vector2(0.0020, 0.00145)
const CHAVE := Vector3(0.0036, 0.00125, 0.0009)
const VOLUME_Y: Array[float] = [0.0270, 0.0165]
const VOLUME_R := 0.0024
const VOLUME_ALTURA := 0.00075
## Direita: a gaveta do micro-SIM e o furo do alfinete.
const SIM_Y := 0.004
const SIM_MEIA := Vector2(0.0078, 0.00155)
const SIM_FURO_Y := 0.0100
const SIM_FURO_R := 0.00045

# --- o que ha nos vidros ------------------------------------------------------
## A fresta do alto-falante: 11,2 x 1,6 mm, com a tela de metal 0,6 mm abaixo.
const FALANTE_MEIA := Vector2(0.0056, 0.0008)
const FALANTE_PROF := 0.0006
const MALHA_PASSO := 0.00028
## Raio do furo da malha, em fracao do passo.
const MALHA_FURO := 0.30
## A camera da frente, a esquerda do alto-falante.
const CAMERA_FRENTE := Vector2(-0.0118, 0.0478)
const CAMERA_FRENTE_R := 0.00125
## O botao home: folga entre ele e o vidro, e o bisel do furo.
const BOTAO_FOLGA := 0.00008
const BOTAO_BISEL := 0.00024
## O quadradinho: meia caixa, canto e meia espessura do traco.
const ICONE := Vector3(0.00195, 0.0007, 0.00013)
## As costas: a camera no canto de cima (a esquerda de quem olha as costas) e o
## flash ao lado dela.
const CAMERA_TRAS := Vector2(0.0209, 0.0492)
const CAMERA_TRAS_R := 0.00305
const CAMERA_TRAS_ANEL := 0.00042
const CAMERA_TRAS_LENTE := 0.0016
const FLASH := Vector2(0.0104, 0.0492)
const FLASH_R := 0.00145

## A tela acesa. A textura do app tem 1168 x 1752 e, na leitura, cabe em uns 450
## pixels de altura: lida com filtro linear e sem mipmap (a textura de um
## `SubViewport` nao tem), cada traco de letra de um pixel caia entre duas
## amostras e acendia e apagava com o balanco da mao — a tela "piscava" e nao
## se lia. Aqui cada pixel faz a media de oito amostras espalhadas pelo pedaco
## da textura que ele cobre (a pegada do pixel, pelas derivadas), que e o que um
## mipmap com filtro anisotropico faria. Sem nevoa: a nevoa da cabine lavava a
## tela de cinza e as letras sumiam.
const TELA_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, depth_draw_opaque;

uniform sampler2D tela : source_color, hint_default_white, filter_linear, repeat_disable;
uniform vec4 cor : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// A tela dando pau, de 0 (sa) a 1 (morrendo): faixas rasgadas e deslocadas, as
// cores separando, blocos trocados de lugar, chuvisco, a varredura descendo, e
// a tela apagando e estourando em branco. Em 0 o caminho e o de sempre.
uniform float pane : hint_range(0.0, 1.0) = 0.0;

float h11(float n) { return fract(sin(n * 91.3458) * 47453.5453); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// Grade rodada de oito pontos dentro do quadrado do pixel.
vec3 amostra(vec2 uv, vec2 dx, vec2 dy) {
	vec2 o[8] = vec2[8](vec2(-0.375, -0.125), vec2(-0.125, 0.375), vec2(0.125, -0.375),
		vec2(0.375, 0.125), vec2(-0.25, -0.4375), vec2(0.4375, -0.25), vec2(0.25, 0.4375),
		vec2(-0.4375, 0.25));
	vec3 c = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		c += texture(tela, uv + dx * o[i].x + dy * o[i].y).rgb;
	}
	return c * 0.125;
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec3 c;
	if (pane <= 0.001) {
		c = amostra(UV, dx, dy);
	} else {
		vec2 uv = UV;
		// O sorteio anda a 24 quadros por segundo, como um sinal de video.
		float quadro = floor(TIME * 24.0);
		// Faixas: a tela rasga em tiras horizontais que escorregam de lado.
		float faixa_h = mix(0.09, 0.022, h11(quadro * 0.37));
		float faixa = floor(uv.y / faixa_h);
		float rasga = step(h21(vec2(faixa, quadro)), pane * 0.55);
		uv.x += (h21(vec2(faixa * 1.7, quadro + 3.0)) - 0.5) * 0.24 * pane * rasga;
		// De vez em quando a imagem rola para cima, como TV sem sincronia.
		float rola = step(h11(floor(TIME * 3.0)), pane * pane * 0.45);
		uv.y = fract(uv.y + rola * fract(TIME * 1.7) * 0.4);
		// Blocos corrompidos: um pedaco de outro lugar da tela.
		vec2 bloco = floor(uv * vec2(9.0, 15.0));
		float bh = h21(bloco + quadro * 0.13);
		if (bh < pane * 0.14) {
			uv = fract(uv + vec2(h21(bloco + 5.0), h21(bloco + 9.0)) * 0.5);
		}
		// As cores separando: vermelho para um lado, azul para o outro.
		float k = 0.003 + 0.02 * pane * (0.4 + rasga);
		vec3 base = amostra(uv, dx, dy);
		float r = texture(tela, clamp(uv + vec2(k, 0.0), 0.0, 1.0)).r;
		float b = texture(tela, clamp(uv - vec2(k, 0.0), 0.0, 1.0)).b;
		c = vec3(mix(base.r, r, min(1.0, pane * 1.6)), base.g, mix(base.b, b, min(1.0, pane * 1.6)));
		// Blocos de cor de compressao quebrada.
		if (bh < pane * 0.05) {
			c = mix(c, vec3(h21(bloco), 0.12, h21(bloco + 2.0)), 0.65);
		}
		// Chuvisco, mais forte nas faixas rasgadas.
		float chuv = h21(floor(UV * vec2(146.0, 219.0) * 1.5) + fract(TIME * 13.0) * 100.0);
		c = mix(c, vec3(chuv), pane * 0.22 * (0.3 + rasga));
		// A varredura escura descendo.
		float linha = smoothstep(0.025, 0.0, abs(fract(UV.y - TIME * 0.9) - 0.5)) * pane;
		c *= 1.0 - linha * 0.6;
		// Apaga, e estoura.
		float pisca = h11(floor(TIME * 18.0) + 7.0);
		if (pisca < pane * 0.2) {
			c *= 0.05;
		} else if (pisca > 1.0 - pane * 0.06) {
			c = mix(c, vec3(1.0), 0.7);
		}
	}
	ALBEDO = c * cor.rgb;
}
"""

const BRILHO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform float forca = 0.035;
// Meia caixa e canto da lamina: o quad e reto, o vidro nao, e sem o recorte a
// quina do reflexo saltava para fora do aparelho.
uniform vec2 meia = vec2(0.028, 0.056);
uniform float raio = 0.007;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * meia;
	vec2 q = abs(p) - meia + vec2(raio);
	float dc = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - raio;
	float dentro = 1.0 - smoothstep(-length(fwidth(p)), 0.0, dc);
	// O reflexo do 4S: a metade de cima e da direita mais clara, cortada em
	// diagonal, e o corte corre quando o aparelho gira contra a luz.
	float corre = VIEW.x * 0.8 + VIEW.y * 0.5;
	float d = UV.x * 0.9 + (1.0 - UV.y) * 0.75 + corre;
	float faixa = smoothstep(0.98, 1.10, d) * (1.0 - smoothstep(1.3, 1.65, d));
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = vec3(0.82, 0.88, 1.0) * (faixa * forca + borda * 0.12) * dentro;
}
"""

## O que o aco e o vidro dividem: a distancia a retangulo arredondado e o estudio.
const COMUM := """
uniform float estudio_forca = 1.0;

float sd_ret(vec2 p, vec2 meia, float r) {
	vec2 q = abs(p) - meia + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Para fora do contorno, por diferenca central.
vec2 grad_ret(vec2 p, vec2 meia, float r) {
	float e = 0.00001;
	vec2 g = vec2(sd_ret(p + vec2(e, 0.0), meia, r) - sd_ret(p - vec2(e, 0.0), meia, r),
		sd_ret(p + vec2(0.0, e), meia, r) - sd_ret(p - vec2(0.0, e), meia, r));
	return g / max(length(g), 1e-9);
}

// Uma caixa de luz retangular do estudio, na direcao `eixo`.
float caixa(vec3 r, vec3 eixo, vec3 cima, vec2 meia, float suave) {
	float w = dot(r, eixo);
	if (w <= 0.0) {
		return 0.0;
	}
	vec3 lado = normalize(cross(cima, eixo));
	vec3 alto = cross(eixo, lado);
	vec2 q = abs(vec2(dot(r, lado), dot(r, alto))) / w;
	vec2 k = vec2(1.0) - smoothstep(meia - vec2(suave), meia + vec2(suave), q);
	return k.x * k.y;
}

// O estudio de fotografia de produto, preso a camera: `r` e o raio refletido em
// espaco de vista (x para a direita, y para cima, z de volta para a lente).
vec3 estudio(vec3 r) {
	r = normalize(r);
	// Ceu cinza claro, chao cinza de estudio e, entre os dois, a linha escura do
	// horizonte: e o contraste dela que le como cromado.
	float y = r.y;
	vec3 ceu = mix(vec3(0.26, 0.27, 0.29), vec3(0.42, 0.43, 0.46), smoothstep(0.0, 0.9, y));
	vec3 chao = mix(vec3(0.17, 0.17, 0.18), vec3(0.30, 0.30, 0.31), smoothstep(0.0, 0.9, -y));
	vec3 c = mix(chao, ceu, smoothstep(-0.02, 0.02, y));
	// A sala tem paredes: a luz do fundo varia em volta, e a perspectiva faz
	// essa variacao correr ao longo do lado reto da banda.
	float az = atan(r.x, -r.z);
	c *= 0.65 + 0.55 * smoothstep(-0.7, 0.7, sin(az * 2.0 + 0.5));
	float h = y / 0.07;
	c *= 1.0 - 0.85 * exp(-h * h);
	c += vec3(0.95, 0.97, 1.0) * caixa(r, normalize(vec3(0.0, 1.0, 0.3)),
		vec3(0.0, 0.0, -1.0), vec2(1.1, 0.45), 0.18);
	c += vec3(1.0) * caixa(r, normalize(vec3(-1.0, 0.2, 0.05)), vec3(0.0, 1.0, 0.0),
		vec2(0.09, 1.2), 0.035);
	c += vec3(0.8) * caixa(r, normalize(vec3(1.0, 0.25, -0.1)), vec3(0.0, 1.0, 0.0),
		vec2(0.07, 1.2), 0.03);
	c += vec3(0.16) * caixa(r, normalize(vec3(0.25, 0.35, 1.0)), vec3(0.0, 1.0, 0.0),
		vec2(0.9, 0.6), 0.4);
	// Duas janelas grandes e macias atras do aparelho: e o que o lado reto da
	// banda reflete quando a lente o ve de raspao, e a perspectiva as faz
	// correr ao longo dele em degrade, em vez de um cinza chapado.
	c += vec3(0.55, 0.56, 0.58) * caixa(r, normalize(vec3(-0.55, 0.05, -1.0)),
		vec3(0.0, 1.0, 0.0), vec2(0.35, 0.8), 0.3);
	c += vec3(0.30, 0.30, 0.31) * caixa(r, normalize(vec3(0.7, -0.1, -1.0)),
		vec3(0.0, 1.0, 0.0), vec2(0.25, 0.8), 0.25);
	return c;
}
"""

const ACO_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, fog_disabled;

uniform vec3 cor : source_color = vec3(0.8, 0.81, 0.83);
uniform float aspereza = 0.14;
// A banda desenha furos e frestas; os botoes nao.
uniform bool detalhes = true;
// Botao de volume: 1 gravado +, 2 gravado -.
uniform int sinal = 0;

const vec2 MEIA = {MEIA};
const float FRESTA_Y = {FRESTA_Y};
const float FRESTA = {FRESTA};
const vec2 DOCA_MEIA = {DOCA_MEIA};
const float DOCA_RAIO = {DOCA_RAIO};
const float PARAF_X = {PARAFUSO_X};
const float PARAF_REBAIXO = {PARAFUSO_REBAIXO};
const float PARAF_CABECA = {PARAFUSO_CABECA};
const float GRADE_X0 = {GRADE_X0};
const float GRADE_PASSO = {GRADE_PASSO};
const float GRADE_FURO = {GRADE_FURO};
const float GRADE_FILEIRA = {GRADE_FILEIRA};
const float GRADE_N = {GRADE_N};
const float FONE_X = {FONE_X};
const float FONE_R = {FONE_R};
const float MIC_X = {MIC_X};
const float MIC_R = {MIC_R};
const float LIGA_X = {LIGA_X};
const vec2 LIGA_FURO = {LIGA_FURO};
const float CHAVE_Y = {CHAVE_Y};
const vec2 CHAVE_FURO = {CHAVE_FURO};
const float VOL1_Y = {VOL1_Y};
const float VOL2_Y = {VOL2_Y};
const float VOL_FURO = {VOL_FURO};
const float SIM_Y = {SIM_Y};
const vec2 SIM_MEIA = {SIM_MEIA};
const float SIM_FURO_Y = {SIM_FURO_Y};
const float SIM_FURO_R = {SIM_FURO_R};

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec3 v_cam;

struct Furo {
	float escuro;
	float parede;
	float lingua;
	vec2 incl;
};

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	v_cam = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
}

// Um furo usinado: a boca com bisel (a normal cai para dentro) e o poco escuro,
// com a parede do lado de la aparecendo pela paralaxe (`desl` e quanto o fundo
// anda por metro de profundidade).
void buraco(vec2 p, vec2 meia, float raio, float bisel, float prof, vec2 desl, float aa,
		inout Furo f) {
	float d = sd_ret(p, meia, raio);
	if (d > bisel + 2.0 * aa) {
		return;
	}
	float dentro = 1.0 - smoothstep(-aa, aa, d);
	float fundo = 1.0 - smoothstep(-aa, aa, sd_ret(p + desl * prof, meia, raio));
	f.escuro = max(f.escuro, dentro);
	f.parede = max(f.parede, dentro * (1.0 - fundo));
	float kb = smoothstep(-aa, aa, d) * (1.0 - smoothstep(bisel - aa, bisel + aa, d));
	if (kb > 0.0) {
		float t = clamp(1.0 - d / bisel, 0.0, 1.0);
		f.incl = mix(f.incl, -grad_ret(p, meia, raio) * tan(t * 0.95), kb);
	}
}

// O pentalobe: cabeca abaulada num rebaixo, com a estrela de cinco lobos.
void parafuso(vec2 p, vec2 desl, float aa, inout Furo f) {
	float r = length(p);
	if (r > PARAF_REBAIXO + 3.0 * aa) {
		return;
	}
	buraco(p, vec2(PARAF_REBAIXO), PARAF_REBAIXO, 0.00005, 0.0004, desl, aa, f);
	float cab = 1.0 - smoothstep(PARAF_CABECA - aa, PARAF_CABECA + aa, r);
	f.escuro *= 1.0 - cab;
	f.parede *= 1.0 - cab;
	vec2 radial = p / max(r, 1e-8);
	f.incl = mix(f.incl, radial * (r / PARAF_CABECA) * 0.5, cab);
	float th = atan(p.y, p.x);
	float estrela = r - PARAF_CABECA * (0.34 + 0.11 * cos(5.0 * th));
	f.escuro = max(f.escuro, (1.0 - smoothstep(-aa, aa, estrela)) * cab);
}

void base(vec2 q, vec2 desl, float aa, inout Furo f) {
	buraco(q, DOCA_MEIA, DOCA_RAIO, 0.00018, 0.0025, desl, aa, f);
	// A lingua de plastico do conector, um milimetro para dentro.
	vec2 ql = q + desl * 0.0011;
	float lingua = 1.0 - smoothstep(-aa, aa,
		sd_ret(ql, vec2(DOCA_MEIA.x - 0.0006, 0.00036), 0.0002));
	float boca = 1.0 - smoothstep(-aa, aa, sd_ret(q, DOCA_MEIA, DOCA_RAIO));
	f.lingua = max(f.lingua, lingua * boca);
	vec2 espelho = vec2(sign(q.x), 1.0);
	vec2 dm = desl * espelho;
	parafuso(vec2(abs(q.x) - PARAF_X, q.y), dm, aa, f);
	// As grades: duas fileiras desencontradas de furos, dos dois lados.
	float ax = abs(q.x);
	for (int fil = 0; fil < 2; fil++) {
		float x0 = GRADE_X0 + float(fil) * GRADE_PASSO * 0.5;
		float z0 = fil == 0 ? GRADE_FILEIRA : -GRADE_FILEIRA;
		float i = clamp(floor((ax - x0) / GRADE_PASSO + 0.5), 0.0, GRADE_N - 1.0);
		vec2 c = vec2(x0 + i * GRADE_PASSO, z0);
		buraco(vec2(ax, q.y) - c, vec2(GRADE_FURO), GRADE_FURO, 0.00006, 0.0007, dm, aa, f);
	}
}

void topo(vec2 q, vec2 desl, float aa, inout Furo f) {
	buraco(q - vec2(FONE_X, 0.0), vec2(FONE_R), FONE_R, 0.00028, 0.006, desl, aa, f);
	buraco(q - vec2(MIC_X, 0.0), vec2(MIC_R), MIC_R, 0.00005, 0.0006, desl, aa, f);
	buraco(q - vec2(LIGA_X, 0.0), LIGA_FURO, LIGA_FURO.y, 0.00012, 0.0012, desl, aa, f);
}

void esquerda(vec2 q, vec2 desl, float aa, inout Furo f) {
	buraco(q - vec2(CHAVE_Y, 0.0), CHAVE_FURO, 0.0005, 0.00012, 0.0012, desl, aa, f);
	buraco(q - vec2(VOL1_Y, 0.0), vec2(VOL_FURO), VOL_FURO, 0.00012, 0.0012, desl, aa, f);
	buraco(q - vec2(VOL2_Y, 0.0), vec2(VOL_FURO), VOL_FURO, 0.00012, 0.0012, desl, aa, f);
}

void direita(vec2 q, vec2 desl, float aa, inout Furo f) {
	// A gaveta e rente: o que aparece e a costura em volta dela.
	float d = sd_ret(q - vec2(SIM_Y, 0.0), SIM_MEIA, SIM_MEIA.y);
	float costura = 1.0 - smoothstep(0.00005 - aa, 0.00005 + aa, abs(d));
	f.escuro = max(f.escuro, costura * 0.9);
	buraco(q - vec2(SIM_FURO_Y, 0.0), vec2(SIM_FURO_R), SIM_FURO_R, 0.00008, 0.0012, desl,
		aa, f);
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 vd = normalize(v_cam - v_pos);
	Furo f = Furo(0.0, 0.0, 0.0, vec2(0.0));
	float plastico = 0.0;
	vec3 ta = vec3(1.0, 0.0, 0.0);
	vec3 tb = vec3(0.0, 0.0, 1.0);
	float aa = max(length(fwidth(v_pos)), 1e-8) * 0.6;
	if (detalhes) {
		if (abs(v_pos.x) > MEIA.x - 0.0012) {
			float dy = abs(abs(v_pos.y) - FRESTA_Y) - FRESTA * 0.5;
			plastico = 1.0 - smoothstep(-aa, aa, dy);
		}
		int face = 0;
		vec2 q = v_pos.xz;
		if (n.y < -0.995) {
			face = 1;
		} else if (n.y > 0.995) {
			face = 2;
		} else if (abs(n.x) > 0.995) {
			face = n.x < 0.0 ? 3 : 4;
			q = v_pos.yz;
			ta = vec3(0.0, 1.0, 0.0);
		}
		if (face > 0) {
			float vn = max(dot(vd, n), 0.08);
			vec2 desl = -vec2(dot(vd, ta), dot(vd, tb)) / vn;
			if (face == 1) {
				base(q, desl, aa, f);
			} else if (face == 2) {
				topo(q, desl, aa, f);
			} else if (face == 3) {
				esquerda(q, desl, aa, f);
			} else {
				direita(q, desl, aa, f);
			}
		}
	} else if (sinal > 0 && n.z > 0.9) {
		// O + e o - gravados no topo do volume.
		vec2 p = v_pos.xy;
		float k = 1.0 - smoothstep(-aa, aa, max(abs(p.x) - 0.00008, abs(p.y) - 0.00058));
		if (sinal == 1) {
			k = max(k, 1.0 - smoothstep(-aa, aa, max(abs(p.y) - 0.00008, abs(p.x) - 0.00058)));
		}
		f.escuro = k * 0.8;
		f.parede = k;
	}
	vec3 nd = normalize(n + ta * f.incl.x + tb * f.incl.y);
	vec3 nv = normalize(mat3(VIEW_MATRIX) * (mat3(MODEL_MATRIX) * nd));
	NORMAL = nv;
	vec3 env = estudio(reflect(-VIEW, nv)) * estudio_forca;
	float esc = clamp(f.escuro, 0.0, 1.0);
	vec3 aco = cor * env;
	vec3 poco = cor * env * 0.10 * f.parede + vec3(0.05, 0.05, 0.055) * f.lingua * estudio_forca;
	vec3 plast = env * 0.05;
	ALBEDO = mix(mix(cor, vec3(0.025), plastico), vec3(0.01), esc);
	METALLIC = (1.0 - plastico) * (1.0 - esc);
	ROUGHNESS = mix(mix(aspereza, 0.35, plastico), 0.6, esc);
	EMISSION = mix(mix(aco, plast, plastico), poco, esc);
}
"""

const VIDRO_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, fog_disabled;

// A tampa de tras usa o mesmo shader, com a camera e o flash.
uniform bool traseira = false;
// O estudio na capa de vidro (ja com Fresnel) e nas pecas de baixo dela.
uniform float capa_forca = 1.6;

const vec2 VIDRO_MEIA = {VIDRO_MEIA};
const vec2 TELA_MEIA = {TELA_MEIA};
const float VIDRO_RAIO = {VIDRO_RAIO};
const float VIDRO_QUINA = {VIDRO_QUINA};
const vec2 FALANTE_C = {FALANTE_C};
const vec2 FALANTE_MEIA = {FALANTE_MEIA};
const float FALANTE_PROF = {FALANTE_PROF};
const float MALHA_PASSO = {MALHA_PASSO};
const float MALHA_FURO = {MALHA_FURO};
const vec2 CAMF_C = {CAMF_C};
const float CAMF_R = {CAMF_R};
const vec2 BOTAO_C = {BOTAO_C};
const float BOTAO_R = {BOTAO_R};
const float BOTAO_FOLGA = {BOTAO_FOLGA};
const float BOTAO_BISEL = {BOTAO_BISEL};
const vec3 ICONE = {ICONE};
const vec2 CAMT_C = {CAMT_C};
const float CAMT_R = {CAMT_R};
const float CAMT_ANEL = {CAMT_ANEL};
const float CAMT_LENTE = {CAMT_LENTE};
const vec2 FLASH_C = {FLASH_C};
const float FLASH_R = {FLASH_R};

varying vec3 v_pos;
varying vec3 v_cam;

// Duas camadas: a capa de vidro (Fresnel de 4%, a normal so muda nas quinas e
// nos biseis dos furos) e a peca de baixo dela, que tem refletancia propria.
// Onde o vidro e furado (alto-falante, botao, camera de tras) `coberto` e 0.
struct Vidro {
	vec3 albedo;
	vec3 f0;
	float metal;
	float rough;
	vec2 incl;
	vec2 incl_capa;
	float coberto;
};

void vertex() {
	v_pos = VERTEX;
	v_cam = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
}

// O bisel de um furo no vidro: a normal da capa cai para dentro.
void bisel(vec2 p, vec2 meia, float raio, float larg, float ang, float aa, inout Vidro v) {
	float d = sd_ret(p, meia, raio);
	float k = smoothstep(-aa, aa, d) * (1.0 - smoothstep(larg - aa, larg + aa, d));
	if (k > 0.0) {
		float t = clamp(1.0 - d / larg, 0.0, 1.0);
		v.incl_capa = mix(v.incl_capa, -grad_ret(p, meia, raio) * tan(t * ang), k);
	}
}

// A fresta do alto-falante e a tela de metal no fundo dela.
void alto_falante(vec2 p, vec2 desl, float aa, inout Vidro v) {
	vec2 pa = p - FALANTE_C;
	float d = sd_ret(pa, FALANTE_MEIA, FALANTE_MEIA.y);
	if (d > 0.0003) {
		return;
	}
	bisel(pa, FALANTE_MEIA, FALANTE_MEIA.y, 0.00014, 0.9, aa, v);
	float dentro = 1.0 - smoothstep(-aa, aa, d);
	if (dentro <= 0.0) {
		return;
	}
	vec2 pf = pa + desl * FALANTE_PROF;
	float df = sd_ret(pf, FALANTE_MEIA, FALANTE_MEIA.y);
	float tela = 1.0 - smoothstep(-aa, aa, df);
	// A parede da fresta sombreia a malha junto dela: e o que da fundo ao furo.
	float sombra = mix(0.3, 1.0, smoothstep(0.0, 0.0004, -df));
	// Furos redondos numa grade a 45 graus. Quando o passo cai abaixo de uns
	// tres pixels a grade vira a media dela, e nao moire.
	vec2 g = vec2(pf.x + pf.y, pf.x - pf.y) * (0.70710678 / MALHA_PASSO);
	vec2 cel = fract(g) - 0.5;
	float px = MALHA_PASSO / max(aa, 1e-8);
	float nitido = smoothstep(1.5, 3.5, px);
	float borda = clamp(0.7 / px, 0.03, 0.5);
	float furo = 1.0 - smoothstep(MALHA_FURO - borda, MALHA_FURO + borda, length(cel));
	float fio = mix(0.5, 1.0 - furo, nitido);
	vec2 bump = vec2(cel.x + cel.y, cel.x - cel.y) * 0.70710678 * 1.3 * nitido * (1.0 - furo);
	vec3 malha = vec3(0.30, 0.31, 0.33) * fio * sombra;
	v.albedo = mix(v.albedo, mix(vec3(0.015), malha, tela), dentro);
	v.f0 = mix(v.f0, mix(vec3(0.02), malha, tela), dentro);
	v.metal = mix(v.metal, tela * fio, dentro);
	v.rough = mix(v.rough, mix(0.5, 0.4, tela), dentro);
	v.incl = mix(v.incl, bump * tela, dentro);
	v.coberto *= 1.0 - dentro;
}

// A camera da frente, debaixo do vidro.
void camera_frente(vec2 p, float aa, inout Vidro v) {
	vec2 pc = p - CAMF_C;
	float r = length(pc);
	if (r > CAMF_R + 0.0003) {
		return;
	}
	vec2 radial = pc / max(r, 1e-8);
	float k = 1.0 - smoothstep(CAMF_R - aa, CAMF_R + aa, r);
	float lr = CAMF_R * 0.62;
	float lente = 1.0 - smoothstep(lr - aa, lr + aa, r);
	float pupila = 1.0 - smoothstep(CAMF_R * 0.22 - aa, CAMF_R * 0.22 + aa, r);
	float anel = 1.0 - smoothstep(0.00005, 0.00005 + 2.0 * aa, abs(r - CAMF_R * 0.84));
	vec3 f0 = mix(vec3(0.05), mix(vec3(0.15, 0.12, 0.30), vec3(0.04, 0.05, 0.08), pupila), lente);
	f0 = mix(f0, vec3(0.35), anel * (1.0 - lente));
	v.albedo = mix(v.albedo, mix(vec3(0.02, 0.021, 0.028), vec3(0.004), lente), k);
	v.f0 = mix(v.f0, f0, k);
	v.incl = mix(v.incl, radial * (r / lr) * 0.6 * lente, k);
	v.rough = mix(v.rough, 0.05, k);
}

// O botao home: o bisel do furo no vidro, a folga, a concha e o quadradinho.
void botao(vec2 p, float aa, inout Vidro v) {
	vec2 ph = p - BOTAO_C;
	float r = length(ph);
	float r_furo = BOTAO_R + BOTAO_FOLGA;
	if (r > r_furo + BOTAO_BISEL + 2.0 * aa) {
		return;
	}
	vec2 radial = ph / max(r, 1e-8);
	float d = r - r_furo;
	float kb = smoothstep(-aa, aa, d) * (1.0 - smoothstep(BOTAO_BISEL - aa, BOTAO_BISEL + aa, d));
	float tb = clamp(1.0 - d / BOTAO_BISEL, 0.0, 1.0);
	v.incl_capa = mix(v.incl_capa, -radial * tan(tb * 0.9), kb);
	float furo = 1.0 - smoothstep(-aa, aa, d);
	v.albedo = mix(v.albedo, vec3(0.0), furo);
	v.f0 = mix(v.f0, vec3(0.0), furo);
	v.coberto *= 1.0 - furo;
	float bot = 1.0 - smoothstep(BOTAO_R - aa, BOTAO_R + aa, r);
	if (bot <= 0.0) {
		return;
	}
	// A concha: a normal vira para o centro, mais na borda; o aro arredondado
	// do botao vira para fora e pega um fio de luz.
	float u = r / BOTAO_R;
	vec2 inc = -radial * u * 0.30;
	inc = mix(inc, radial * 1.2, smoothstep(0.90, 1.0, u));
	float di = sd_ret(ph, vec2(ICONE.x), ICONE.y);
	float icone = 1.0 - smoothstep(ICONE.z - aa, ICONE.z + aa, abs(di));
	v.albedo = mix(v.albedo, mix(vec3(0.012, 0.012, 0.014), vec3(0.50, 0.50, 0.52), icone), bot);
	v.f0 = mix(v.f0, vec3(mix(0.045, 0.02, icone)), bot);
	v.rough = mix(v.rough, mix(0.10, 0.6, icone), bot);
	v.incl = mix(v.incl, inc * (1.0 - icone), bot);
}

// A camera de tras: anel de aco abaulado, o poco preto com os sulcos e a lente.
void camera_tras(vec2 p, float aa, inout Vidro v) {
	vec2 pc = p - CAMT_C;
	float r = length(pc);
	if (r > CAMT_R + 0.0003) {
		return;
	}
	vec2 radial = pc / max(r, 1e-8);
	float ext = 1.0 - smoothstep(CAMT_R - aa, CAMT_R + aa, r);
	float r_in = CAMT_R - CAMT_ANEL;
	float anel = ext * smoothstep(r_in - aa, r_in + aa, r);
	float u = clamp((r - r_in) / CAMT_ANEL, 0.0, 1.0);
	vec2 inc_anel = radial * (u * 2.0 - 1.0) * 1.1;
	float lente = 1.0 - smoothstep(CAMT_LENTE - aa, CAMT_LENTE + aa, r);
	float pupila = 1.0 - smoothstep(CAMT_LENTE * 0.35 - aa, CAMT_LENTE * 0.35 + aa, r);
	float px = 0.00018 / max(aa, 1e-8);
	float sulcos = mix(0.5, 0.5 + 0.5 * cos(r / 0.00018 * 6.2831853), smoothstep(1.5, 3.0, px));
	vec3 f0 = mix(vec3(0.03 + 0.03 * sulcos),
		mix(vec3(0.16, 0.22, 0.40), vec3(0.05, 0.05, 0.08), pupila), lente);
	vec3 aco = vec3(0.62, 0.63, 0.65);
	vec2 inc = radial * (r / CAMT_LENTE) * 0.6 * lente;
	v.albedo = mix(v.albedo, mix(vec3(0.008), aco, anel), ext);
	v.f0 = mix(v.f0, mix(f0, aco, anel), ext);
	v.metal = mix(v.metal, anel, ext);
	v.incl = mix(v.incl, mix(inc, inc_anel, anel), ext);
	v.rough = mix(v.rough, mix(0.04, 0.12, anel), ext);
	v.coberto *= 1.0 - ext;
}

// O flash: o difusor amarelado com os aneis da lente de Fresnel.
void flash(vec2 p, float aa, inout Vidro v) {
	vec2 pf = p - FLASH_C;
	float r = length(pf);
	if (r > FLASH_R + 0.0002) {
		return;
	}
	float k = 1.0 - smoothstep(FLASH_R - aa, FLASH_R + aa, r);
	float borda = smoothstep(FLASH_R * 0.8 - aa, FLASH_R * 0.8 + aa, r);
	float px = 0.00016 / max(aa, 1e-8);
	float aneis = mix(0.5, 0.5 + 0.5 * cos(r / 0.00016 * 6.2831853), smoothstep(1.5, 3.0, px));
	vec3 difusor = vec3(0.60, 0.56, 0.42) * (0.8 + 0.2 * aneis);
	v.albedo = mix(v.albedo, mix(difusor, vec3(0.02), borda), k);
	v.f0 = mix(v.f0, vec3(0.04), k);
	v.rough = mix(v.rough, mix(0.2, 0.1, borda), k);
	v.coberto *= 1.0 - k;
}

void fragment() {
	vec2 p = v_pos.xy;
	// Onde esta a tela o vidro da frente nao se desenha: ele fica dois decimos
	// de milimetro atras do quadro dela, e na estrada, a centenas de metros da
	// origem, o erro de float das transformacoes e dessa ordem — num quadro em
	// cada centena e pouco o vidro preto ganhava a profundidade e apagava a tela
	// inteira.
	if (!traseira && abs(p.x) < TELA_MEIA.x && abs(p.y) < TELA_MEIA.y) {
		discard;
	}
	float aa = max(length(fwidth(p)), 1e-8) * 0.6;
	vec3 n = vec3(0.0, 0.0, traseira ? -1.0 : 1.0);
	vec3 vd = normalize(v_cam - v_pos);
	vec2 desl = -vd.xy / max(dot(vd, n), 0.08);
	Vidro v = Vidro(vec3(0.006, 0.006, 0.008), vec3(0.0), 0.0, 0.05, vec2(0.0), vec2(0.0), 1.0);
	// A quina lapidada: o vidro arredonda antes de encontrar o aco.
	float db = sd_ret(p, VIDRO_MEIA, VIDRO_RAIO);
	float kq = smoothstep(-VIDRO_QUINA, 0.0, db);
	v.incl_capa += grad_ret(p, VIDRO_MEIA, VIDRO_RAIO) * tan(kq * kq * 0.8);
	if (traseira) {
		camera_tras(p, aa, v);
		flash(p, aa, v);
	} else {
		alto_falante(p, desl, aa, v);
		camera_frente(p, aa, v);
		botao(p, aa, v);
	}
	mat3 para_vista = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX);
	vec3 nc = normalize(para_vista * normalize(n + vec3(v.incl_capa, 0.0)));
	vec3 ns = normalize(para_vista * normalize(n + vec3(v.incl, 0.0)));
	float fc = 0.04 + 0.96 * pow(1.0 - clamp(dot(nc, VIEW), 0.0, 1.0), 5.0);
	float tem = step(0.001, max(v.f0.r, max(v.f0.g, v.f0.b)));
	vec3 fs = v.f0 + (vec3(1.0) - v.f0) * pow(1.0 - clamp(dot(ns, VIEW), 0.0, 1.0), 5.0) * tem;
	NORMAL = normalize(mix(ns, nc, v.coberto));
	ALBEDO = v.albedo;
	METALLIC = v.metal;
	ROUGHNESS = mix(v.rough, 0.05, v.coberto);
	EMISSION = estudio(reflect(-VIEW, nc)) * fc * v.coberto * capa_forca
		+ estudio(reflect(-VIEW, ns)) * fs * (1.0 - 0.04 * v.coberto) * estudio_forca;
}
"""

var tela_mat: ShaderMaterial
var luz: OmniLight3D
## A mesma luz, so para os bracos de primeira pessoa (`BracoVivo.CAMADA`), com
## queda suave: igual a da tela a um palmo, e dez vezes menos estourada a dois
## dedos.
var luz_da_mao: OmniLight3D
var _brilho: float = 0.0
var _abafa: float = 1.0

static var _shader_brilho: Shader
static var _shader_aco: Shader
static var _shader_vidro: Shader


func _init() -> void:
	name = "Celular"
	_montar()
	set_process(false)


## A tela dando pau, de 0 a 1 (ver `pane` no `TELA_SHADER`). A luz que a tela
## joga nas maos pisca junto: apaga quando a tela apaga, estoura quando ela
## estoura.
var pane_forca: float = 0.0


func pane(k: float) -> void:
	pane_forca = clampf(k, 0.0, 1.0)
	tela_mat.set_shader_parameter(&"pane", pane_forca)
	set_process(pane_forca > 0.0)
	if pane_forca <= 0.0:
		brilho(_brilho)


func _process(_delta: float) -> void:
	var h := randf()
	var k := 1.0
	if h < pane_forca * 0.2:
		k = 0.05
	elif h > 1.0 - pane_forca * 0.06:
		k = 1.8
	luz.light_energy = LUZ_FORCA * _brilho * k
	if luz_da_mao != null:
		luz_da_mao.light_energy = LUZ_FORCA * LUZ_MAO_GANHO * _brilho * _abafa * k


## Liga a tela a uma textura (a do `TelaDoCelular`).
func ligar(textura: Texture2D) -> void:
	tela_mat.set_shader_parameter(&"tela", textura)


## 0 apagada (vidro preto), 1 acesa.
func brilho(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	var v := lerpf(0.0, TELA_CHEIA, k)
	tela_mat.set_shader_parameter(&"cor", Color(v, v, v))
	luz.light_energy = LUZ_FORCA * k
	_brilho = k
	abafar_mao(_abafa)


func brilho_atual() -> float:
	return _brilho


## Quanto da luz dos bracos fica (0 a 1): quem sabe onde o braco esta (a cena
## do motorista) abafa quando o antebraco passa rente a luz.
func abafar_mao(f: float) -> void:
	_abafa = clampf(f, 0.0, 1.0)
	if luz_da_mao != null:
		luz_da_mao.light_energy = LUZ_FORCA * LUZ_MAO_GANHO * _brilho * _abafa


## Um ponto da tela, em coordenada do aparelho: `uv` de (0, 0) no canto de cima
## a esquerda a (1, 1) no de baixo a direita.
static func ponto_da_tela(uv: Vector2) -> Vector3:
	return Vector3((uv.x - 0.5) * TELA.x, (0.5 - uv.y) * TELA.y, TAMANHO.z * 0.5)


func _montar() -> void:
	var zt := TAMANHO.z * 0.5
	var borda := CHANFRO + FRISO
	# A banda: friso, chanfro, o lado reto, chanfro e friso, da frente para tras.
	var perfil := PackedVector2Array([Vector2(borda, zt), Vector2(CHANFRO, zt),
		Vector2(0.0, zt - CHANFRO), Vector2(0.0, -zt + CHANFRO), Vector2(CHANFRO, -zt),
		Vector2(borda, -zt)])
	_malha(_loft(TAMANHO.x, TAMANHO.y, RAIO_CANTO, perfil, false), _aco(true, 0),
		Vector3.ZERO).name = "Banda"
	# Os vidros, rentes ao friso.
	_malha(_tampa(TAMANHO.x, TAMANHO.y, RAIO_CANTO, borda, zt, true), _vidro(false),
		Vector3.ZERO).name = "VidroFrente"
	_malha(_tampa(TAMANHO.x, TAMANHO.y, RAIO_CANTO, borda, -zt, false), _vidro(true),
		Vector3.ZERO).name = "VidroTras"
	_botoes()

	# A tela: um quad um fio a frente do vidro, com a textura do app.
	var tela := MeshInstance3D.new()
	tela.name = "Tela"
	var q := QuadMesh.new()
	q.size = TELA
	tela.mesh = q
	var sh := Shader.new()
	sh.code = TELA_SHADER
	tela_mat = ShaderMaterial.new()
	tela_mat.shader = sh
	tela_mat.set_shader_parameter(&"cor", Color.BLACK)
	tela.material_override = tela_mat
	tela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tela.layers = CAMADA
	add_child(tela)
	tela.position = Vector3(0.0, 0.0, zt + 0.0002)

	# O brilho do vidro, por cima de tudo.
	if _shader_brilho == null:
		_shader_brilho = Shader.new()
		_shader_brilho.code = BRILHO_SHADER
	var reflexo := ShaderMaterial.new()
	reflexo.shader = _shader_brilho
	var lamina := MeshInstance3D.new()
	lamina.name = "Reflexo"
	var ql := QuadMesh.new()
	ql.size = Vector2(TAMANHO.x - 2.0 * borda - 0.002, TAMANHO.y - 2.0 * borda - 0.002)
	reflexo.set_shader_parameter(&"meia", ql.size * 0.5)
	reflexo.set_shader_parameter(&"raio", RAIO_CANTO - borda - 0.001)
	lamina.mesh = ql
	lamina.material_override = reflexo
	lamina.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamina.layers = CAMADA
	add_child(lamina)
	lamina.position = Vector3(0.0, 0.0, zt + 0.0005)

	luz = OmniLight3D.new()
	luz.name = "LuzDaTela"
	luz.light_color = LUZ_COR
	luz.omni_range = LUZ_ALCANCE
	luz.light_energy = 0.0
	luz.shadow_enabled = false
	luz.light_cull_mask = 0xFFFFF & ~CAMADA & ~BracoVivo.CAMADA
	add_child(luz)
	# Um palmo a frente do vidro: colada nele, a luz virava um ponto estourado
	# no proprio aparelho.
	luz.position = Vector3(0.0, 0.0, 0.16)
	luz_da_mao = OmniLight3D.new()
	luz_da_mao.name = "LuzDaTelaNaMao"
	luz_da_mao.light_color = LUZ_COR
	luz_da_mao.omni_range = LUZ_ALCANCE
	luz_da_mao.omni_attenuation = LUZ_MAO_QUEDA
	luz_da_mao.light_energy = 0.0
	luz_da_mao.shadow_enabled = false
	luz_da_mao.light_volumetric_fog_energy = 0.0
	luz_da_mao.light_cull_mask = BracoVivo.CAMADA
	add_child(luz_da_mao)
	luz_da_mao.position = luz.position


## Os botoes que saltam da banda, de aco com o mesmo chanfro: a chave de
## silencio e os dois volumes redondos na esquerda, o liga/desliga em cima a
## direita. O furo em volta de cada um e o shader da banda que desenha.
func _botoes() -> void:
	var x_esq := -TAMANHO.x * 0.5
	# Na esquerda: x local ao longo do comprimento, y ao longo da espessura, z
	# para fora da banda.
	var b_esq := Basis(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(-1.0, 0.0, 0.0))
	var chave := _pastilha(CHAVE.x, CHAVE.y, 0.00035, CHAVE.z, 0.00015)
	# A chave na posicao de tocar: encostada do lado da tela.
	_malha(chave, _aco(false, 0), Vector3(x_esq, CHAVE_Y, 0.0006)).basis = b_esq
	for i in VOLUME_Y.size():
		var vol := _pastilha(VOLUME_R * 2.0, VOLUME_R * 2.0, VOLUME_R, VOLUME_ALTURA, 0.00022)
		_malha(vol, _aco(false, 1 + i), Vector3(x_esq, VOLUME_Y[i], 0.0)).basis = b_esq
	# Em cima: x local ao longo da largura.
	var b_topo := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
	var liga := _pastilha(LIGA.x, LIGA.y, LIGA.y * 0.5, LIGA.z, 0.0002)
	_malha(liga, _aco(false, 0), Vector3(LIGA_X, TAMANHO.y * 0.5, 0.0)).basis = b_topo


func _aco(detalhes: bool, sinal: int) -> ShaderMaterial:
	if _shader_aco == null:
		_shader_aco = Shader.new()
		_shader_aco.code = _com_comum(ACO_SHADER).format(_constantes())
	var m := ShaderMaterial.new()
	m.shader = _shader_aco
	m.set_shader_parameter(&"cor", ACO_COR)
	m.set_shader_parameter(&"aspereza", ACO_ASPEREZA)
	m.set_shader_parameter(&"estudio_forca", ACO_ESTUDIO)
	m.set_shader_parameter(&"detalhes", detalhes)
	m.set_shader_parameter(&"sinal", sinal)
	return m


func _vidro(traseira: bool) -> ShaderMaterial:
	if _shader_vidro == null:
		_shader_vidro = Shader.new()
		_shader_vidro.code = _com_comum(VIDRO_SHADER).format(_constantes())
	var m := ShaderMaterial.new()
	m.shader = _shader_vidro
	m.set_shader_parameter(&"traseira", traseira)
	m.set_shader_parameter(&"capa_forca", VIDRO_CAPA)
	m.set_shader_parameter(&"estudio_forca", VIDRO_PECAS)
	return m


## Poe o trecho comum logo depois das declaracoes de uniform do shader, antes da
## primeira constante: as funcoes dele usam so o que vem nele mesmo.
static func _com_comum(codigo: String) -> String:
	var i := codigo.find("\nconst ")
	return codigo.substr(0, i) + "\n" + COMUM + codigo.substr(i)


## As medidas do GDScript, escritas como constantes GLSL.
static func _constantes() -> Dictionary:
	var borda := CHANFRO + FRISO
	return {
		"MEIA": _v2(Vector2(TAMANHO.x, TAMANHO.y) * 0.5),
		"FRESTA_Y": _f(FRESTA_Y), "FRESTA": _f(FRESTA),
		"DOCA_MEIA": _v2(DOCA_MEIA), "DOCA_RAIO": _f(DOCA_RAIO),
		"PARAFUSO_X": _f(PARAFUSO_X), "PARAFUSO_REBAIXO": _f(PARAFUSO_REBAIXO),
		"PARAFUSO_CABECA": _f(PARAFUSO_CABECA),
		"GRADE_X0": _f(GRADE_X0), "GRADE_PASSO": _f(GRADE_PASSO),
		"GRADE_FURO": _f(GRADE_FURO), "GRADE_FILEIRA": _f(GRADE_FILEIRA),
		"GRADE_N": _f(float(GRADE_N)),
		"FONE_X": _f(FONE_X), "FONE_R": _f(FONE_R), "MIC_X": _f(MIC_X), "MIC_R": _f(MIC_R),
		"LIGA_X": _f(LIGA_X),
		"LIGA_FURO": _v2(Vector2(LIGA.x * 0.5 + 0.00015, LIGA.y * 0.5 + 0.00015)),
		"CHAVE_Y": _f(CHAVE_Y), "CHAVE_FURO": _v2(CHAVE_FURO),
		"VOL1_Y": _f(VOLUME_Y[0]), "VOL2_Y": _f(VOLUME_Y[1]),
		"VOL_FURO": _f(VOLUME_R + 0.00015),
		"SIM_Y": _f(SIM_Y), "SIM_MEIA": _v2(SIM_MEIA), "SIM_FURO_Y": _f(SIM_FURO_Y),
		"SIM_FURO_R": _f(SIM_FURO_R),
		"VIDRO_MEIA": _v2(Vector2(TAMANHO.x, TAMANHO.y) * 0.5 - Vector2(borda, borda)),
		# Um quinto de milimetro para dentro: na beira os dois se sobrepoem e
		# nao abre fresta.
		"TELA_MEIA": _v2(TELA * 0.5 - Vector2(0.0002, 0.0002)),
		"VIDRO_RAIO": _f(RAIO_CANTO - borda), "VIDRO_QUINA": _f(VIDRO_QUINA),
		"FALANTE_C": _v2(Vector2(0.0, Y_ALTO_FALANTE)), "FALANTE_MEIA": _v2(FALANTE_MEIA),
		"FALANTE_PROF": _f(FALANTE_PROF), "MALHA_PASSO": _f(MALHA_PASSO),
		"MALHA_FURO": _f(MALHA_FURO),
		"CAMF_C": _v2(CAMERA_FRENTE), "CAMF_R": _f(CAMERA_FRENTE_R),
		"BOTAO_C": _v2(Vector2(0.0, Y_BOTAO)), "BOTAO_R": _f(RAIO_BOTAO),
		"BOTAO_FOLGA": _f(BOTAO_FOLGA), "BOTAO_BISEL": _f(BOTAO_BISEL),
		"ICONE": "vec3(%s, %s, %s)" % [_f(ICONE.x), _f(ICONE.y), _f(ICONE.z)],
		"CAMT_C": _v2(CAMERA_TRAS), "CAMT_R": _f(CAMERA_TRAS_R),
		"CAMT_ANEL": _f(CAMERA_TRAS_ANEL), "CAMT_LENTE": _f(CAMERA_TRAS_LENTE),
		"FLASH_C": _v2(FLASH), "FLASH_R": _f(FLASH_R),
	}


static func _f(v: float) -> String:
	return "%.7f" % v


static func _v2(v: Vector2) -> String:
	return "vec2(%s, %s)" % [_f(v.x), _f(v.y)]


func _malha(m: Mesh, mat: Material, onde: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.layers = CAMADA
	add_child(mi)
	mi.position = onde
	return mi


# --- geometria --------------------------------------------------------------

## O contorno de um retangulo de canto arredondado, no sentido anti-horario
## visto de +Z, comecando no canto de cima a direita. Cada ponto vem como centro
## do canto e direcao para fora: o contorno recuado de `k` e `centro + dir * (r -
## k)`, e a normal do lado e a propria direcao, exata, sem media de arestas.
static func _contorno(w: float, h: float, r: float, passos: int) -> Array[PackedVector2Array]:
	var centros := PackedVector2Array()
	var dirs := PackedVector2Array()
	var cantos := [Vector2(w * 0.5 - r, h * 0.5 - r), Vector2(-w * 0.5 + r, h * 0.5 - r),
		Vector2(-w * 0.5 + r, -h * 0.5 + r), Vector2(w * 0.5 - r, -h * 0.5 + r)]
	for i in 4:
		for k in passos + 1:
			var a := (float(i) + float(k) / float(passos)) * PI * 0.5
			var c: Vector2 = cantos[i]
			var d := Vector2(cos(a), sin(a))
			# Num circulo os lados retos tem comprimento zero: o ponto repetido
			# so faria triangulo degenerado.
			if centros.size() > 0:
				var ultimo := centros[-1] + dirs[-1] * r
				if ultimo.distance_to(c + d * r) < 1e-7:
					continue
			centros.append(c)
			dirs.append(d)
	if centros.size() > 1 and (centros[-1] + dirs[-1] * r).distance_to(centros[0] + dirs[0] * r) < 1e-7:
		centros.resize(centros.size() - 1)
		dirs.resize(dirs.size() - 1)
	return [centros, dirs]


## O perfil `perfil` (recuo a partir do contorno, z) levado em volta do contorno
## de canto arredondado. Cada trecho do perfil tem normal propria (quina viva
## entre o lado e o chanfro: e ela que desenha o risco de luz). Com `tampa`, o
## primeiro ponto do perfil fecha numa face de frente (+Z).
##
## O Godot desenha a face cujos vertices giram no sentido HORARIO para quem a
## olha: com o contorno anti-horario visto de +Z e o perfil correndo da frente
## para tras, o quad vai a0, b0, b1 e a0, b1, a1; a tampa da frente vai centro,
## b, a.
static func _loft(w: float, h: float, r: float, perfil: PackedVector2Array,
		tampa: bool) -> ArrayMesh:
	var c := _contorno(w, h, r, PASSOS_CANTO)
	var centros := c[0]
	var dirs := c[1]
	var n := centros.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in perfil.size() - 1:
		var p0 := perfil[j]
		var p1 := perfil[j + 1]
		# A normal do trecho no plano (raio, z): o perfil anda (d_raio, dz), e a
		# normal para fora e (-dz, d_raio).
		var t := Vector2(p0.x - p1.x, p1.y - p0.y).normalized()
		var nr := -t.y
		var nz := t.x
		for i in n:
			var i2 := (i + 1) % n
			var na := Vector3(dirs[i].x * nr, dirs[i].y * nr, nz)
			var nb := Vector3(dirs[i2].x * nr, dirs[i2].y * nr, nz)
			var a0 := _ponto(centros[i], dirs[i], r - p0.x, p0.y)
			var b0 := _ponto(centros[i2], dirs[i2], r - p0.x, p0.y)
			var a1 := _ponto(centros[i], dirs[i], r - p1.x, p1.y)
			var b1 := _ponto(centros[i2], dirs[i2], r - p1.x, p1.y)
			for v: Array in [[a0, na], [b0, nb], [b1, nb], [a0, na], [b1, nb], [a1, na]]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	if tampa:
		_leque(st, centros, dirs, r - perfil[0].x, perfil[0].y, true)
	return st.commit()


## So a tampa: a face chata de canto arredondado, recuada `recuo` do contorno.
static func _tampa(w: float, h: float, r: float, recuo: float, z: float,
		frente: bool) -> ArrayMesh:
	var c := _contorno(w, h, r, PASSOS_CANTO)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_leque(st, c[0], c[1], r - recuo, z, frente)
	return st.commit()


static func _leque(st: SurfaceTool, centros: PackedVector2Array, dirs: PackedVector2Array,
		raio: float, z: float, frente: bool) -> void:
	var n := centros.size()
	var nrm := Vector3.BACK if frente else Vector3.FORWARD
	for i in n:
		var a := _ponto(centros[i], dirs[i], raio, z)
		var b := _ponto(centros[(i + 1) % n], dirs[(i + 1) % n], raio, z)
		st.set_normal(nrm)
		st.add_vertex(Vector3(0.0, 0.0, z))
		st.set_normal(nrm)
		st.add_vertex(b if frente else a)
		st.set_normal(nrm)
		st.add_vertex(a if frente else b)


static func _ponto(centro: Vector2, dir: Vector2, raio: float, z: float) -> Vector3:
	var p := centro + dir * raio
	return Vector3(p.x, p.y, z)


## Um botao de aco: pastilha de canto arredondado `w` x `h` que salta `altura`
## da banda, com chanfro na borda de cima. A base entra meio milimetro na banda,
## para nao abrir fresta onde a banda curva.
static func _pastilha(w: float, h: float, r: float, altura: float, chanfro: float) -> ArrayMesh:
	var perfil := PackedVector2Array([Vector2(chanfro, altura), Vector2(0.0, altura - chanfro),
		Vector2(0.0, -0.0005)])
	return _loft(w, h, r, perfil, true)

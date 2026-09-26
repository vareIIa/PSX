## A multidao de encapuzados: centenas deles, espalhados na mata ate onde a
## nevoa deixa ver, e mais densa em volta de onde o carro para.
##
## Por que existe
## --------------
## Quatorze figuras em volta da batida e tres na beira da estrada liam como um
## grupo — gente que estava ali. O medo que a cena pede e outro: que a mata
## inteira esta cheia deles, que cada tronco tem um atras, que os pontos
## vermelhos continuam no escuro depois do alcance do farol. Isso sao centenas,
## e centenas de `Corpo` (esqueleto, capuz, aura) nao cabem no quadro.
##
## A versao anterior estalava o pescoco e os bracos de todos, o tempo todo, e um
## em cada tres piscava (sumia e voltava): na tela era ruido e flicker, e nao
## medo. O medo aqui vem do corpo que anda errado e do olhar fixo.
##
## Como e feita
## ------------
## Um `MultiMesh` de uma figura so — batina que arrasta, murca curta nos ombros,
## manga larga, o antebraco nu saindo dela e a mao grande de dedos compridos
## pendurada ate perto do joelho, capuz de ponta com a cara dentro — e TUDO que
## ela faz sai do shader, sem uma linha por figura no processador:
##
##   - o andar: lento e pesado, de quem arrasta uma perna. A cada ciclo a perna
##     boa passa depressa e o quadril afunda do lado da ruim; depois a ruim vem
##     arrastada, devagar, e a barra da batina vai junto com ela. O tronco
##     curvado torce e os ombros rolam; a cabeca pesada, meio tombada, balanca
##     atrasada; os bracos pendem a prumo e vao em pendulo, o antebraco e a mao
##     cada vez mais atrasados, como peso morto. O avanco e aos trancos (rapido
##     no passo bom, quase parado no arrasto). Cada figura tem ritmo e fase
##     proprios;
##   - os eventos, raros e lentos, poucos ao mesmo tempo: uma para, ergue a
##     cabeca para a lente e fica olhando enquanto uma das maos abre os dedos e
##     fecha de novo (`PARA_*`); outra, a certa altura da cena, sente um estalo
##     no pescoco e entorta a cabeca devagar ate quase noventa graus, e fica
##     assim (INSTANCE_CUSTOM.z). Esse estalo e o unico osso que a multidao faz
##     soar (`_estalos`), e so de perto;
##   - andam quando nao sao olhados: a caminhada conta por setor em volta do
##     alvo (`anda_setor`), mais depressa no setor que a lente nao ve e quase
##     parada no que ela ve. A cada vez que a lente volta, estao mais perto — e
##     nada salta, porque o tempo de cada setor so acelera fora do quadro.
##
## Os olhos sao outro `MultiMesh`, de pontos em billboard, que refazem a mesma
## conta do corpo para ficar na cara, e esmaecem com a distancia em vez de sumir
## na nevoa (`some`): e o que faz a multidao parecer infinita. Nao piscam: o
## olhar e fixo.
##
## O rosto
## -------
## Dentro do capuz fica a cabeca da criatura (`CabecaDoPadre`, a mesma do padre
## principal), sem a malha dela: e uma calota oval com a FOTO da cabeca de
## verdade, assada de frente por tests/assar_rosto_multidao.gd em quatro
## variacoes (boca, sangue, a cara amassada) num atlas, com o mapa de normal ao
## lado: o farol e o fogo iluminam a cara como se fosse a malha. Cada figura
## sorteia a variacao e espelha a foto ao acaso.
##
## INSTANCE_CUSTOM: x semente (0-1), y rapidez (m/s), z hora do pescoco
## quebrado (segundos de `relogio`; 0 nunca), w o quanto e curvado (0-1). A
## figura olha para -Z, como o `Corpo`.
class_name MultidaoEncapuzada
extends Node3D

## As medidas da figura, em metros, para uma altura de 1,90.
const PESCOCO := Vector3(0.0, 1.50, 0.0)
const OMBRO := Vector3(0.215, 1.41, 0.0)
const COTOVELO := Vector3(0.245, 1.10, 0.012)
const PUNHO := Vector3(0.262, 0.785, -0.008)
## A manga larga acaba nesta fracao do antebraco (do cotovelo ao punho).
const MANGA_ATE := 0.42
## A mao: da junta do punho ate os nos dos dedos, e a meia espessura (x) e a
## meia largura (z) da palma no punho e nos nos.
const PALMA := 0.13
const PALMA_PUNHO := Vector2(0.015, 0.024)
const PALMA_NOS := Vector2(0.015, 0.052)
## Os dedos, da frente (-z) para tras: [z na palma, comprimento, raio da base].
## Compridos de proposito: a garra pendurada chega perto do joelho.
const DEDOS := [[-0.037, 0.172, 0.0115], [-0.013, 0.192, 0.012], [0.012, 0.180, 0.0115],
	[0.035, 0.146, 0.0102]]
## O polegar: comprimento e raio da base.
const POLEGAR := [0.118, 0.0128]
const CINTURA := 0.92
## O rosto: o centro da calota e da foto (1,5 cm abaixo do centro da cabeca, em
## 1,655: `assar_rosto_multidao.CENTRO_Y`), meia largura, meia altura e fundura
## da calota (do alto do cranio ao queixo com a queixada caida), e o lado do
## quadrado de cada foto (igual a assar_rosto_multidao.RETRATO).
const ROSTO_CENTRO := Vector3(0.0, 1.640, -0.012)
const ROSTO_MEIO := Vector3(0.079, 0.132, 0.092)
const ROSTO_LADO := 0.28
## As fotos da cabeca da criatura (2x2 variacoes) e o mapa de normal delas.
const ROSTO_FOTO := "res://assets/monstros/padre/multidao_rosto.png"
const ROSTO_NORMAL := "res://assets/monstros/padre/multidao_rosto_n.png"
## O olho da criatura na calota (`CabecaDoPadre.OLHO`, do centro da cabeca), um
## fio na frente da superficie para o ponto nao entrar na cara.
const OLHO := Vector3(0.031, 1.659, -0.101)
## O pano (cor de vertice, linear; alfa 0 = pano) e a pele (alfa 1): a mesma
## cera cinza das `MaosPodres`; a ponta do dedo e a unha escurecem.
const PANO := Color(0.028, 0.025, 0.023, 0.0)
const PELE := Color(0.40, 0.39, 0.355, 1.0)
const UNHA := Color(0.07, 0.05, 0.03, 1.0)
## O olho: tamanho do quad e a distancia a partir da qual ele cresce; de perto
## a foto ja mostra o olho de verdade, e o ponto so acende de `OLHO_DE` a
## `OLHO_ATE` (como o `CabecaDoPadre.LONGE_*`).
const OLHO_QUAD := 0.026
const OLHO_PERTO := 3.5
const OLHO_DE := 3.0
const OLHO_ATE := 7.0
## Os setores em volta do alvo em que a caminhada conta separado, e quanto o
## tempo de cada um anda por segundo com a lente olhando e sem ela olhando.
const SETORES := 12
const SETOR_RAIO := 16.0
const ANDA_VISTO := 0.45
const ANDA_ESCONDIDO := 2.2
## A margem alem da borda do quadro (rad) em que o setor ainda conta como visto,
## e a faixa em que passa de visto a escondido.
const SETOR_MARGEM := 0.08
const SETOR_FAIXA := 0.40
## Quem quebra o pescoco na cena: a fracao das figuras e de quando a quando.
const QUEBRA_CHANCE := 0.15
const QUEBRA_DE := 3.0
const QUEBRA_ATE := 40.0
## O estalo dessa quebra: so ate esta distancia da lente, e nunca dois em menos
## deste intervalo (a multidao nao pode virar o "PA PA PA" do tique antigo).
const ESTALO_ALCANCE := 14.0
const ESTALO_ENTRE := 3.5
const ESTALO_DB := -6.0
## A multidao sai em fatias (setores em volta do alvo), cada uma com a sua
## caixa: com uma caixa so, as centenas de figuras entravam inteiras no pre-passe,
## no passe opaco e na sombra do farol mesmo atras da lente.
const FATIAS := 12
## Onde eles param (m do alvo), mais um sorteio por figura: de 3 a 10 m e a
## roda dos padres de corpo inteiro.
const PARADA := 10.5
const PARADA_VARIA := 4.0

## A conta da figura (caminhada, eventos, pose), igual nos dois shaders (corpo
## e olhos): o olho fica na cara porque passa pela mesma pose que ela.
const COMUM := """
uniform vec3 alvo = vec3(0.0);
// O centro dos setores da caminhada: o alvo de quando nasceram, fixo (o alvo
// muda um pouco na batida, e o setor de cada um nao pode mudar junto).
uniform vec3 centro = vec3(0.0);
uniform vec3 lente = vec3(0.0, 1.2, 0.0);
uniform float parada = 10.5;
uniform float parada_varia = 4.0;
uniform float tique = 1.0;
uniform float aparece = 1.0;
// A bancada forca a parada (erguer a cabeca para a lente, abrir a mao) para
// julgar de perto; na estrada fica em 0.
uniform float forca_parada = 0.0;
// Segundos de cena desde que a multidao nasceu: o relogio dos pescocos.
uniform float relogio = 0.0;
// Segundos de caminhada de cada setor em volta do alvo (o 0 em +X, subindo o
// angulo de X para Z). Fora da lente eles contam mais depressa.
uniform float anda_setor[12];
uniform vec3 pescoco;
uniform vec3 ombro;
uniform vec3 cotovelo;
uniform vec3 punho;
uniform float nos_y;
uniform float cintura;

const float VOLTA = 6.2831853;
// As paradas: uma chance por janela de PARA_CADA segundos de caminhada, de
// PARA_MIN a PARA_MAX segundos, entrando e saindo em PARA_RAMPA.
const float PARA_CADA = 16.0;
const float PARA_CHANCE = 0.18;
const float PARA_MIN = 4.5;
const float PARA_MAX = 8.0;
const float PARA_RAMPA = 0.9;
// O tranco do avanco: a velocidade vai de (1 - TRANCO) a (1 + TRANCO) no ciclo.
const float TRANCO = 0.62;

float h11(float n) { return fract(sin(n * 127.1 + 11.3) * 43758.5453); }
float sinal(float n) { return h11(n) < 0.5 ? -1.0 : 1.0; }

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}
mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}
mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}
// YXZ, como o Basis.from_euler do Godot.
mat3 giro(vec3 e) { return rot_y(e.y) * rot_x(e.x) * rot_z(e.z); }

// Uma rotacao em volta de `p` por cima da transformacao (M, o) que ja havia.
void compor(inout mat3 M, inout vec3 o, mat3 R, vec3 p) {
	M = R * M;
	o = R * (o - p) + p;
}

// Um pulso suave em volta da fase `c` (com a volta do ciclo), meia largura `w`.
float pulso(float f, float c, float w) {
	float d = fract(f - c + 0.5) - 0.5;
	float k = clamp(1.0 - d * d / (w * w), 0.0, 1.0);
	return k * k;
}

// A integral da rampa suave (smoothstep de 0 a 1) de 0 a x: quanto tempo a
// parada ja comeu da caminhada, sem tranco na entrada nem na saida.
float rampa_int(float x) {
	x = max(x, 0.0);
	return x < 1.0 ? x * x * x - 0.5 * x * x * x * x : x - 0.5;
}

struct Fig {
	float s;
	float ruim;
	float fase;
	float anda;
	float olha;
	float mao;
	float lado_mao;
	float quebra;
	float estalo;
	float lado_q;
	float curva;
	float resp;
	float rumo;
	vec3 desloca;
	vec3 para_lente;
};

// Os segundos de caminhada no angulo em que a figura esta (entre dois setores).
float tempo_de_andar(vec3 origem) {
	vec2 d = origem.xz - centro.xz;
	float u = fract(atan(d.y, d.x) / VOLTA + 1.0) * 12.0;
	int i0 = int(floor(u)) % 12;
	int i1 = (i0 + 1) % 12;
	return mix(anda_setor[i0], anda_setor[i1], fract(u));
}

Fig figura(vec4 dado, mat4 modelo) {
	Fig f;
	float s = dado.x;
	f.s = s;
	f.ruim = sinal(s * 3.7 + 0.2);
	vec3 origem = modelo[3].xyz;
	mat3 m3 = mat3(modelo);
	float escala = length(m3[1]);
	float a = tempo_de_andar(origem);
	// As paradas ja passadas (a pausa) e a de agora (o peso).
	float pausa = 0.0;
	float peso = 0.0;
	float na_parada = 0.0;
	float dura = 1.0;
	int n = min(int(a / PARA_CADA) + 1, 16);
	for (int k = 0; k < 16; k++) {
		if (k >= n) {
			break;
		}
		float fk = float(k);
		if (h11(s * 61.7 + fk * 3.97) > PARA_CHANCE) {
			continue;
		}
		float d = mix(PARA_MIN, PARA_MAX, h11(s * 17.3 + fk * 1.31));
		float ini = fk * PARA_CADA + h11(s * 29.1 + fk * 7.7) * (PARA_CADA - d);
		float fim = ini + d;
		pausa += PARA_RAMPA * (rampa_int((a - ini) / PARA_RAMPA)
			- rampa_int((a - fim + PARA_RAMPA) / PARA_RAMPA));
		float w = smoothstep(ini, ini + PARA_RAMPA, a) * (1.0 - smoothstep(fim - PARA_RAMPA, fim, a));
		if (w > peso) {
			peso = w;
			na_parada = a - ini;
			dura = d;
		}
	}
	float ae = a - pausa;
	// O ciclo de dois passos (s) e a fase de partida: ninguem em passo com
	// ninguem.
	float ciclo = mix(2.2, 3.3, h11(s * 23.9));
	float f0 = h11(s * 37.3);
	f.fase = fract(ae / ciclo + f0);
	float v = dado.y;
	float dist = v * (ae + TRANCO * ciclo / VOLTA
		* (sin(VOLTA * (ae / ciclo + f0 - 0.17)) - sin(VOLTA * (f0 - 0.17))));
	vec3 para = alvo - origem;
	para.y = 0.0;
	float d0 = length(para);
	vec3 dir = d0 > 0.001 ? para / d0 : -m3[2] / escala;
	float falta = max(0.0, d0 - (parada + h11(s * 11.9) * parada_varia));
	// Chega macio: o ultimo trecho desacelera (min suave).
	float hk = max(0.8 - abs(dist - falta), 0.0) / 0.8;
	float dc = max(min(dist, falta) - hk * hk * 0.2, 0.0);
	f.desloca = dir * dc;
	f.anda = clamp((falta - dist) / 0.8, 0.0, 1.0) * (1.0 - peso) * step(0.01, v);
	// Vira para onde anda: o alvo muda depois que eles nascem.
	vec3 dl = transpose(m3) * dir;
	f.rumo = d0 > 0.001 ? atan(-dl.x, -dl.z) : 0.0;
	// A parada: ergue a cabeca para a lente e fica; uma mao abre e fecha.
	float parado = step(0.001, peso) * tique;
	f.olha = smoothstep(0.5, 2.1, na_parada) * (1.0 - smoothstep(dura - 1.4, dura - 0.1, na_parada))
		* parado;
	f.mao = smoothstep(1.7, 2.9, na_parada) * (1.0 - smoothstep(dura - 2.3, dura - 1.0, na_parada))
		* parado;
	f.lado_mao = sinal(s * 5.3 + floor(a / PARA_CADA));
	f.olha = max(f.olha, forca_parada);
	f.mao = max(f.mao, forca_parada);
	f.anda *= 1.0 - forca_parada;
	// O pescoco quebrado: um estalo curto e depois a cabeca entorta devagar.
	float q = dado.z;
	f.estalo = q > 0.0 ? clamp((relogio - q) / 0.12, 0.0, 1.0) * tique : 0.0;
	f.quebra = q > 0.0 ? smoothstep(q + 0.15, q + 3.8, relogio) * tique : 0.0;
	f.lado_q = sinal(s * 8.1 + 0.4);
	f.curva = 0.16 + 0.46 * dado.w + 0.08 * h11(s * 6.6);
	f.resp = sin(TIME * mix(1.1, 1.6, h11(s * 4.4)) + s * 40.0);
	// A lente, vista da figura (no espaco dela, antes do rumo).
	vec3 cab = origem + f.desloca + vec3(0.0, 1.6 * escala, 0.0);
	vec3 pl = normalize(transpose(m3) * (lente - cab));
	f.para_lente = rot_y(-f.rumo) * pl;
	return f;
}

// A cabeca (euler YXZ em volta do pescoco).
vec3 cabeca(Fig f) {
	float s = f.s;
	// Pesada, tombada de lado e um pouco caida, mas a cara continua para a
	// frente: o pescoco desfaz quase toda a curva do tronco, e ela olha por
	// baixo do capuz. Caida de todo, da lente so se via o alto do capuz.
	float pitch = f.curva * 0.8 - mix(0.04, 0.24, h11(s * 13.1));
	float roll = sinal(s * 9.3) * mix(0.12, 0.42, h11(s * 5.9));
	float yaw = sinal(s * 2.2) * 0.14 * h11(s * 3.3);
	// O andar: balanca atrasada, de lado a cada ciclo e para baixo a cada passo.
	roll += f.anda * 0.13 * sin(VOLTA * (f.fase - 0.27)) * f.ruim;
	pitch += f.anda * 0.07 * sin(2.0 * VOLTA * (f.fase - 0.12)) + 0.02 * f.resp;
	// Parado, ergue a cabeca para a lente (e desfaz a curva do tronco).
	float yl = clamp(atan(-f.para_lente.x, -f.para_lente.z), -1.1, 1.1);
	float pl = asin(clamp(f.para_lente.y, -1.0, 1.0)) + f.curva;
	pitch = mix(pitch, pl, f.olha);
	yaw = mix(yaw, yl, f.olha);
	roll = mix(roll, roll * 0.45, f.olha);
	// O pescoco quebrado: o estalo curto, e depois quase noventa graus.
	roll = mix(roll, f.lado_q * 1.38, f.quebra) + f.lado_q * 0.22 * f.estalo * (1.0 - f.quebra);
	pitch -= 0.16 * f.quebra * (1.0 - f.olha);
	return vec3(pitch, yaw, roll);
}

// O quadril que afunda do lado da perna ruim, o tronco que torce e os ombros
// que rolam: [afunda, tomba, torce, ombros].
vec4 quadril(Fig f) {
	float pr = pulso(f.fase, 0.17, 0.22);
	float pb = pulso(f.fase, 0.67, 0.30);
	return vec4(f.anda * (0.08 * pr + 0.015 * pb),
		f.anda * (0.13 * pr - 0.04 * pb),
		f.anda * 0.15 * sin(VOLTA * (f.fase - 0.6)) * f.ruim,
		f.anda * 0.10 * sin(VOLTA * (f.fase - 0.32)) * f.ruim);
}

// A fase do pe no ciclo, torta: o passo bom leva 35% do ciclo, o arrasto o
// resto (0 a 0,5 no passo, 0,5 a 1 no arrasto).
float fase_do_pe(float f) {
	return f < 0.35 ? f / 0.35 * 0.5 : 0.5 + (f - 0.35) / 0.65 * 0.5;
}

// As pernas debaixo da batina: o pano da frente vai com o joelho da perna boa
// (que levanta) e a barra do lado ruim arrasta no chao.
vec3 pernas(Fig f, vec3 v) {
	if (v.y > 1.0 || f.anda <= 0.0) {
		return vec3(0.0);
	}
	float fw = fase_do_pe(f.fase);
	float zb = 0.21 * cos(VOLTA * fw);
	float zr = -0.13 * cos(VOLTA * fw) + 0.03;
	float ergue = f.fase < 0.35 ? sin(3.14159 * f.fase / 0.35) : 0.0;
	float wy = 1.0 - smoothstep(0.3, 1.0, v.y);
	float wb = smoothstep(-0.06, 0.14, -v.x * f.ruim);
	float wr = smoothstep(-0.06, 0.14, v.x * f.ruim);
	float frente = smoothstep(0.05, -0.15, v.z);
	return vec3(0.0, ergue * wb * frente * 0.06 * wy, (zb * wb + zr * wr) * 0.6 * wy) * f.anda;
}

// O braco `l` (-1 esquerdo, +1 direito): euler do ombro, a dobra do cotovelo e
// do punho (rad, para a frente) e o fechar dos dedos (rad na ponta).
void braco(Fig f, float l, out vec3 e_ombro, out float cot, out float pul, out float dedos) {
	float s = f.s;
	// Peso morto: o braco quase nao balanca por conta propria (o do lado ruim
	// menos ainda); o que o mexe e o tranco do corpo, e a mao vem atrasada.
	float amp = l * f.ruim > 0.0 ? 0.045 : 0.10;
	float ph = VOLTA * (f.fase + (l > 0.0 ? 0.0 : 0.5));
	vec4 q = quadril(f);
	// A prumo mesmo com o tronco curvado (um fio para a frente) e parado
	// quando o quadril tomba: peso morto.
	e_ombro = vec3(f.curva * 1.05 + 0.04 + f.anda * amp * sin(ph - 0.9) + 0.025 * f.resp,
		0.0, l * (0.07 + 0.05 * h11(s * 7.1 + l)) + q.y * f.ruim * 0.9);
	cot = 0.07 + 0.06 * h11(s * 3.9 + l) + f.anda * amp * 0.9 * sin(ph - 1.7);
	pul = 0.05 + f.anda * amp * 1.0 * sin(ph - 2.5);
	float garra = mix(0.30, 0.62, h11(s * 9.9 + l));
	float abre = f.mao * step(0.0, l * f.lado_mao);
	dedos = mix(garra, -0.16, abre);
}

// Do repouso a pose de agora, no espaco da figura (a caminhada fica de fora):
// v' = M v + o. `parte`: 0 corpo, 1 cabeca, 2 e 3 os bracos; `sub` no braco:
// 0 braco, 1 antebraco, 2 mao, 3 dedo (w: 0 no no, 1 na ponta).
void pose(Fig f, float parte, float sub, float w, vec3 v, out mat3 M, out vec3 o) {
	M = mat3(1.0);
	o = vec3(0.0);
	float kc = 1.0;
	float kt = 1.0;
	if (parte > 0.5 && parte < 1.5) {
		compor(M, o, giro(cabeca(f)), pescoco);
	} else if (parte > 1.5) {
		float l = parte < 2.5 ? -1.0 : 1.0;
		vec3 eo;
		float cot;
		float pul;
		float dd;
		braco(f, l, eo, cot, pul, dd);
		if (sub > 2.5) {
			// O dedo fecha para a palma (que olha para dentro), mais na ponta.
			compor(M, o, rot_z(-l * dd * 1.7 * w), vec3(punho.x * l, nos_y, 0.0));
		}
		if (sub > 1.5) {
			compor(M, o, rot_x(pul), vec3(punho.x * l, punho.y, punho.z));
		}
		if (sub > 0.5) {
			compor(M, o, rot_x(cot), vec3(cotovelo.x * l, cotovelo.y, cotovelo.z));
		}
		compor(M, o, giro(eo), vec3(ombro.x * l, ombro.y, ombro.z));
	} else {
		kc = smoothstep(cintura, cintura + 0.35, v.y);
		kt = smoothstep(cintura - 0.1, 1.4, v.y);
		o += pernas(f, v);
	}
	vec4 q = quadril(f);
	vec3 cin = vec3(0.0, cintura, 0.0);
	// O tronco torce e os ombros rolam em volta da espinha; depois a curva na
	// cintura; o peito sobe e desce com a respiracao.
	compor(M, o, rot_y(q.z * kt) * rot_z(q.w * kt), cin);
	// No apoio da perna ruim o tronco cai um pouco mais para a frente.
	float cai = 0.07 * pulso(f.fase, 0.2, 0.2) * f.anda;
	compor(M, o, rot_x(-(f.curva + cai) * kc), cin);
	o.y += 0.006 * f.resp * kt;
	// O quadril: tomba para o lado da perna ruim, em volta do pe dela, e afunda.
	compor(M, o, rot_z(-f.ruim * q.y), vec3(f.ruim * 0.1, 0.0, 0.0));
	o += vec3(f.ruim * 0.045 * q.y / 0.13, -q.x, 0.0);
	compor(M, o, rot_y(f.rumo), vec3(0.0));
}
"""

const CORPO_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

%s
uniform sampler2D rosto : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D rosto_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D pele_mapa : filter_linear_mipmap, repeat_enable;
uniform vec3 pele : source_color = vec3(0.70, 0.69, 0.66);
uniform vec3 mancha_quente : source_color = vec3(0.60, 0.48, 0.44);
uniform vec3 mancha_fria : source_color = vec3(0.52, 0.56, 0.58);
uniform vec3 veia : source_color = vec3(0.30, 0.28, 0.42);
uniform vec3 racha : source_color = vec3(0.16, 0.08, 0.07);
uniform vec3 necrose : source_color = vec3(0.14, 0.11, 0.10);
uniform vec3 barro : source_color = vec3(0.16, 0.12, 0.085);
// Alem disto (m) da lente os quatro dedos dao lugar a garra de longe (um gomo
// so, afinando ate a ponta): dedo de 2 cm vira menos de dois pixels, e os
// triangulos finos de centenas de maos custavam 0,2 a 0,3 ms de placa a 4K.
uniform float dedo_some = 18.0;

varying float semente;
varying vec3 p_rep;
varying float material;
varying float no_dedo;

void vertex() {
	float s = INSTANCE_CUSTOM.x;
	semente = s;
	p_rep = VERTEX;
	material = COLOR.a;
	float parte = UV2.x;
	float sub = floor(UV2.y + 0.001);
	float w = fract(UV2.y + 0.001) / 0.9;
	no_dedo = sub > 2.5 && sub < 4.5 ? w : 0.0;
	if (aparece < 0.5) {
		VERTEX = vec3(0.0);
	} else {
		Fig f = figura(INSTANCE_CUSTOM, MODEL_MATRIX);
		vec3 v = VERTEX;
		if (sub > 2.5 && sub < 4.5) {
			// Um ponto so da figura decide: a mao troca inteira, nunca meia.
			float longe = length((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 1.0)).xyz);
			bool some = sub < 3.5 ? longe > dedo_some : longe <= dedo_some;
			if (some) {
				v = vec3(sign(v.x) * punho.x, nos_y + 0.01, punho.z);
			}
		}
		mat3 M;
		vec3 o;
		pose(f, parte, sub, w, v, M, o);
		VERTEX = M * v + o;
		if (UV2.y > 5.5) {
			// A calota: a normal e a da foto (assada de frente).
			NORMAL = M * vec3(0.0, 0.0, -1.0);
			TANGENT = M * vec3(-1.0, 0.0, 0.0);
			BINORMAL = M * vec3(0.0, 1.0, 0.0);
		} else {
			NORMAL = M * NORMAL;
			TANGENT = M * vec3(1.0, 0.0, 0.0);
			BINORMAL = M * vec3(0.0, 1.0, 0.0);
		}
		mat3 m3 = mat3(MODEL_MATRIX);
		VERTEX += transpose(m3) * f.desloca / dot(m3[1], m3[1]);
	}
}

void fragment() {
	float tom = 0.8 + 0.45 * h11(semente * 5.1);
	if (UV2.y > 5.5) {
		// A cara: uma das quatro fotos, espelhada ao acaso.
		vec2 uv = clamp(UV, 0.0, 1.0);
		float esp = h11(semente * 3.1 + 0.7) < 0.5 ? -1.0 : 1.0;
		if (esp < 0.0) {
			uv.x = 1.0 - uv.x;
		}
		float cel = floor(h11(semente * 7.7 + 0.3) * 3.999);
		vec2 auv = (vec2(mod(cel, 2.0), floor(cel / 2.0)) + uv) * 0.5;
		vec4 c = texture(rosto, auv);
		vec2 nxy = texture(rosto_n, auv).rg * 2.0 - 1.0;
		nxy.x *= esp;
		vec3 nb = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.0)));
		vec3 nv = normalize(TANGENT * nb.x + BINORMAL * nb.y + NORMAL * nb.z);
		NORMAL = normalize(mix(NORMAL, nv, c.a));
		ALBEDO = mix(vec3(0.004), c.rgb, c.a);
		ROUGHNESS = 0.55;
		SPECULAR = 0.4;
	} else if (material > 0.75) {
		// A pele: a cera craquelada das `MaosPodres`, sem a normal (de 10 m
		// a racha e menor que o pixel; o tom da mancha e da veia nao). Uma
		// leitura so, na diagonal do espaco da figura em repouso: presa na
		// pele, e o braco pendurado nao estica em listras.
		vec4 m = texture(pele_mapa, vec2(p_rep.x + p_rep.z, p_rep.y) / 0.15);
		float sulco = smoothstep(0.50, 0.22, m.r);
		vec3 c = pele;
		c = mix(c, mancha_quente, smoothstep(0.50, 0.85, m.b) * 0.55);
		c = mix(c, mancha_fria, smoothstep(0.45, 0.15, m.b) * 0.5);
		c = mix(c, veia, m.g * (1.0 - sulco) * 0.7 * (1.0 - no_dedo));
		c = mix(c, necrose, smoothstep(0.2, 0.9, no_dedo) * 0.7);
		c = mix(c, racha, sulco * 0.75);
		ALBEDO = c * COLOR.rgb / vec3(0.40, 0.39, 0.355);
		ROUGHNESS = clamp(0.52 + sulco * 0.3, 0.35, 0.9);
		SPECULAR = 0.42;
	} else {
		// O pano, com barro subindo da barra (em lingua, nao em linha). Sem a
		// textura das batinas: a 10 m a trama e menor que o pixel, e as duas
		// leituras por pixel pesavam no passe opaco.
		vec3 c = COLOR.rgb * tom;
		float lama = 1.0 - smoothstep(0.02, 0.36,
			p_rep.y + 0.06 * sin(p_rep.x * 23.0 + p_rep.z * 17.0 + semente * 40.0));
		c = mix(c, barro * 0.6, lama * 0.5);
		ALBEDO = c;
		ROUGHNESS = mix(0.9, 0.55, lama);
		SPECULAR = 0.2;
	}
}
"""

const OLHO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

%s
uniform vec3 olho;
uniform float quad = 0.026;
uniform float perto = 3.5;
uniform float de = 3.0;
uniform float ate = 7.0;
uniform float forca = 1.3;
uniform float some = 20.0;

varying float brilho;

void vertex() {
	Fig f = figura(INSTANCE_CUSTOM, MODEL_MATRIX);
	// UV2.x: o lado do olho (-1 ou +1).
	vec3 c = vec3(olho.x * UV2.x, olho.y, olho.z);
	mat3 M;
	vec3 o;
	pose(f, 1.0, 0.0, 0.0, c, M, o);
	c = M * c + o;
	vec3 mundo = (MODEL_MATRIX * vec4(c, 1.0)).xyz + f.desloca;
	vec3 v = (VIEW_MATRIX * vec4(mundo, 1.0)).xyz;
	float d = -v.z;
	// Cresce com a distancia so ate um ponto: longe o par de olhos tem de
	// encolher, senao a mata inteira vira um varal de lampadas. De perto a foto
	// ja tem o olho: o ponto apaga.
	float tam = quad * clamp(d / perto, 1.0, 3.2) * smoothstep(de, ate, d);
	if (aparece < 0.5) {
		tam = 0.0;
	}
	v.xy += VERTEX.xy * tam;
	POSITION = PROJECTION_MATRIX * vec4(v, 1.0);
	brilho = forca * (0.12 + 0.88 * exp(-d / some));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	if (r > 0.34) {
		discard;
	}
	float nucleo = smoothstep(0.34, 0.0, r);
	vec3 cor = mix(vec3(1.0, 0.05, 0.012), vec3(1.0, 0.5, 0.3), nucleo * nucleo);
	ALBEDO = cor * (0.6 + nucleo * 3.4) * brilho;
}
"""

## Os corpos, uma fatia por setor em volta do alvo (`FATIAS`), e os olhos.
var _corpos: Array[MultiMeshInstance3D] = []
var _olhos: MultiMeshInstance3D
var _mats: Array[ShaderMaterial] = []
## Por figura: onde nasceu (no espaco deste no), rapidez, hora do pescoco
## quebrado.
var _origens := PackedVector3Array()
var _rapidez := PackedFloat32Array()
var _quebras := PackedFloat32Array()
var _alvo := Vector3.ZERO
var _centro := Vector3.ZERO
var _centro_fixo := false
var _parada := PARADA
var _relogio := 0.0
var _anda := PackedFloat32Array()
var _ultimo_estalo := -100.0
## Quem quebra o pescoco, em ordem de hora ([hora, indice]), e o proximo dela.
var _fila_quebras: Array = []
var _prox_quebra := 0

static var _malha: ArrayMesh
## As texturas ficam presas aqui: a multidao de aquecimento (`_aquecer_na_lente`)
## e jogada fora, e sem dono o motor as descarregava; o quadro em que a de
## verdade nasce lia de novo 11 MB do disco.
static var _tex_rosto: Texture2D
static var _tex_rosto_n: Texture2D
static var _tex_pele: Texture2D
static var _malha_olhos: ArrayMesh
static var _shader_corpo: Shader
static var _shader_olho: Shader


## Monta a multidao com uma figura por item de `figuras`: dicionarios com
## `pos` (Vector3, o pe no chao, global), `olha` (Vector3, para onde a frente
## aponta, global), `altura` (m), `rapidez` (m/s), `curvado` (0-1) e, opcional,
## `quebra` (segundos de cena em que o pescoco quebra; 0 nunca — sem a chave,
## sorteia).
static func criar(figuras: Array) -> MultidaoEncapuzada:
	var m := MultidaoEncapuzada.new()
	m.name = "Multidao"
	m._montar(figuras)
	return m


## O carro, para onde todos andam (global). Chamado todo quadro por quem conhece
## o carro. O primeiro fixa o centro dos setores da caminhada.
func mirar(alvo: Vector3) -> void:
	_alvo = alvo
	_uniforme(&"alvo", alvo)
	if not _centro_fixo:
		_centro_fixo = true
		_centro = alvo
		_uniforme(&"centro", alvo)


## A que distancia do alvo eles param (m), mais o sorteio de cada um (de 0 a
## `varia` m).
func parar_a(metros: float, varia: float = PARADA_VARIA) -> void:
	_parada = metros
	_uniforme(&"parada", metros)
	_uniforme(&"parada_varia", varia)


## Quantos segundos de caminhada ja se passaram, em todos os setores (sem a
## conta da lente; `passo` faz a conta).
func andar(segundos: float) -> void:
	_anda.fill(segundos)
	_uniforme(&"anda_setor", _anda)


## Um quadro: o relogio dos pescocos, a caminhada de cada setor (depressa onde
## a lente nao ve, quase parada onde ve) e o estalo de quem quebra perto.
func passo(delta: float) -> void:
	_relogio += delta
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var ver := _visto_por_setor(cam)
	for k in SETORES:
		_anda[k] += delta * lerpf(ANDA_ESCONDIDO, ANDA_VISTO, ver[k])
	_uniforme(&"anda_setor", _anda)
	_uniforme(&"relogio", _relogio)
	if cam != null:
		_uniforme(&"lente", cam.global_position)
		_estalos(cam)


## Poe o relogio dos pescocos e a caminhada de todos os setores num instante
## (a bancada pula para o meio da cena).
func pular_para(relogio: float, andado: float) -> void:
	_relogio = relogio
	_prox_quebra = 0
	while _prox_quebra < _fila_quebras.size() and float(_fila_quebras[_prox_quebra][0]) <= relogio:
		_prox_quebra += 1
	_uniforme(&"relogio", relogio)
	andar(andado)


func aparecer(sim: bool) -> void:
	visible = sim
	_uniforme(&"aparece", 1.0 if sim else 0.0)


## A forca dos eventos (parar e olhar, o pescoco): 0 desliga.
func tique(k: float) -> void:
	_uniforme(&"tique", k)


## Todos parados olhando a lente, com a mao aberta (0 a 1): so para a bancada.
func forcar_parada(k: float) -> void:
	_uniforme(&"forca_parada", k)


## Quantas figuras, e quantas delas quebram o pescoco na cena.
func contagem() -> Vector2i:
	var q := 0
	for x in _quebras:
		if x > 0.0:
			q += 1
	return Vector2i(_origens.size(), q)


func _uniforme(nome: StringName, valor: Variant) -> void:
	for mat: ShaderMaterial in _mats:
		mat.set_shader_parameter(nome, valor)


## O quanto a lente ve cada setor (0 a 1): o ponto do setor a `SETOR_RAIO` do
## centro, dentro do quadro (com margem) e na frente da lente. Na vertical
## tambem: com a lente baixa no telefone, a mata nao esta no quadro.
func _visto_por_setor(cam: Camera3D) -> PackedFloat32Array:
	var ver := PackedFloat32Array()
	ver.resize(SETORES)
	if cam == null:
		ver.fill(1.0)
		return ver
	var vp := get_viewport().get_visible_rect().size
	var aspecto := vp.x / maxf(vp.y, 1.0)
	var meio_v := deg_to_rad(cam.fov) * 0.5
	var meio := atan(tan(meio_v) * aspecto)
	var inv := cam.global_transform.affine_inverse()
	for k in SETORES:
		var a := float(k) / float(SETORES) * TAU
		var p := _centro + Vector3(cos(a), 0.0, sin(a)) * SETOR_RAIO + Vector3.UP * 1.4
		var l := inv * p
		if l.z >= -0.1:
			ver[k] = 0.0
			continue
		var ang := atan(absf(l.x) / -l.z)
		var ang_v := atan(absf(l.y) / -l.z)
		ver[k] = (1.0 - smoothstep(meio + SETOR_MARGEM, meio + SETOR_MARGEM + SETOR_FAIXA, ang)) 			* (1.0 - smoothstep(meio_v + SETOR_MARGEM, meio_v + SETOR_MARGEM + SETOR_FAIXA, ang_v))
	return ver


## Os segundos de caminhada no angulo de `origem`, como o shader conta.
func _tempo_de_andar(origem: Vector3) -> float:
	var d := Vector2(origem.x - _centro.x, origem.z - _centro.z)
	var u := fposmod(atan2(d.y, d.x) / TAU, 1.0) * float(SETORES)
	var i0 := floori(u) % SETORES
	return lerpf(_anda[i0], _anda[(i0 + 1) % SETORES], u - floorf(u))


## O estalo de osso de quem quebra o pescoco neste quadro, se for perto da
## lente. Onde a figura esta sai da caminhada sem os trancos nem as paradas:
## para o ouvido basta.
func _estalos(cam: Camera3D) -> void:
	while _prox_quebra < _fila_quebras.size():
		var q: float = _fila_quebras[_prox_quebra][0]
		if q > _relogio:
			return
		var i: int = _fila_quebras[_prox_quebra][1]
		_prox_quebra += 1
		if _relogio - _ultimo_estalo < ESTALO_ENTRE or _relogio - q > 0.2:
			continue
		# A origem guardada e a do no; o alvo e a lente sao do mundo.
		var o := global_transform * _origens[i]
		var para := _alvo - o
		para.y = 0.0
		var anda := minf(_rapidez[i] * _tempo_de_andar(o), maxf(0.0, para.length() - _parada))
		var onde := o + para.normalized() * anda + Vector3.UP * 1.6
		if onde.distance_to(cam.global_position) > ESTALO_ALCANCE:
			continue
		_tocar_estalo(onde)


func _tocar_estalo(onde: Vector3) -> void:
	var nome := StringName("estalo_osso_%d" % randi_range(1, 4))
	var st := AudioDirector.stream(nome)
	if st == null:
		return
	_ultimo_estalo = _relogio
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = ESTALO_DB
	p.pitch_scale = randf_range(0.8, 1.05)
	p.unit_size = 2.5
	p.max_db = 3.0
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p)
	p.global_position = onde
	p.play()
	p.finished.connect(p.queue_free)
	AudioDirector.registrar(nome, p.volume_db, "estalo multidao")


func _montar(figuras: Array) -> void:
	if _malha == null:
		_malha = _figura()
		_malha_olhos = _par_de_olhos()
		_shader_corpo = Shader.new()
		_shader_corpo.code = CORPO_SHADER % COMUM
		_shader_olho = Shader.new()
		_shader_olho.code = OLHO_SHADER % COMUM
		_tex_rosto = load(ROSTO_FOTO) as Texture2D
		_tex_rosto_n = load(ROSTO_NORMAL) as Texture2D
		_tex_pele = load(CabecaDoPadre.MAPA) as Texture2D
	_anda.resize(SETORES)
	_anda.fill(0.0)
	# O centro das fatias: para onde eles olham ao nascer (o alvo de entao), no
	# espaco deste no. O dos setores (global) vem no primeiro `mirar`.
	var centro := Vector3.ZERO
	if not figuras.is_empty():
		var f0: Dictionary = figuras[0]
		centro = f0.get("olha", f0["pos"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4410 + figuras.size()
	var xfs: Array[Transform3D] = []
	var dados: Array[Color] = []
	var fatias: Array = []
	for k in FATIAS:
		fatias.append([])
	for i in figuras.size():
		var f: Dictionary = figuras[i]
		var pos: Vector3 = f["pos"]
		var olha: Vector3 = f.get("olha", pos + Vector3.FORWARD)
		var frente := olha - pos
		frente.y = 0.0
		var base := Basis.looking_at(frente.normalized() if frente.length_squared() > 0.0001
			else Vector3.FORWARD, Vector3.UP)
		base = base.scaled(Vector3.ONE * (float(f.get("altura", 1.9)) / 1.9))
		xfs.append(Transform3D(base, pos))
		var sorteio := rng.randf()
		var quebra := rng.randf_range(QUEBRA_DE, QUEBRA_ATE) if sorteio < QUEBRA_CHANCE else 0.0
		quebra = float(f.get("quebra", quebra))
		var rapidez := float(f.get("rapidez", 0.3))
		dados.append(Color(fmod(float(i) * 0.6180339 + 0.137, 1.0), rapidez, quebra,
			float(f.get("curvado", 0.0))))
		_origens.append(pos)
		_rapidez.append(rapidez)
		_quebras.append(quebra)
		if quebra > 0.0:
			_fila_quebras.append([quebra, i])
		var d := pos - centro
		var k := floori(fposmod(atan2(d.z, d.x) / TAU, 1.0) * float(FATIAS)) % FATIAS
		(fatias[k] as Array).append(i)
	_fila_quebras.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var mc := ShaderMaterial.new()
	mc.shader = _shader_corpo
	mc.set_shader_parameter(&"rosto", _tex_rosto)
	mc.set_shader_parameter(&"rosto_n", _tex_rosto_n)
	mc.set_shader_parameter(&"pele_mapa", _tex_pele)
	_mats.append(mc)
	var tudo := AABB()
	var primeira := true
	for k in FATIAS:
		var quem: Array = fatias[k]
		if quem.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _malha
		mm.instance_count = quem.size()
		# A caixa: onde nascem e ate onde a caminhada os leva (a parada, com
		# folga para o alvo que ainda muda um pouco depois da batida).
		var caixa := AABB()
		for j in quem.size():
			var i: int = quem[j]
			mm.set_instance_transform(j, xfs[i])
			mm.set_instance_custom_data(j, dados[i])
			var pos := xfs[i].origin
			var fim := centro + (pos - centro).normalized() * PARADA * 0.7
			fim.y = pos.y
			caixa = AABB(pos, Vector3.ZERO) if j == 0 else caixa.expand(pos)
			caixa = caixa.expand(fim)
		caixa = caixa.grow(4.0)
		caixa.size.y += 2.5
		var mi := MultiMeshInstance3D.new()
		mi.name = "Corpos%d" % k
		mi.multimesh = mm
		mi.material_override = mc
		mi.custom_aabb = caixa
		mi.extra_cull_margin = 1.0
		add_child(mi)
		_corpos.append(mi)
		tudo = caixa if primeira else tudo.merge(caixa)
		primeira = false
	var olhos_mm := MultiMesh.new()
	olhos_mm.transform_format = MultiMesh.TRANSFORM_3D
	olhos_mm.use_custom_data = true
	olhos_mm.mesh = _malha_olhos
	olhos_mm.instance_count = figuras.size()
	for i in figuras.size():
		olhos_mm.set_instance_transform(i, xfs[i])
		olhos_mm.set_instance_custom_data(i, dados[i])
	_olhos = MultiMeshInstance3D.new()
	_olhos.name = "Olhos"
	_olhos.multimesh = olhos_mm
	var mo := ShaderMaterial.new()
	mo.shader = _shader_olho
	mo.set_shader_parameter(&"olho", OLHO)
	mo.set_shader_parameter(&"quad", OLHO_QUAD)
	mo.set_shader_parameter(&"perto", OLHO_PERTO)
	mo.set_shader_parameter(&"de", OLHO_DE)
	mo.set_shader_parameter(&"ate", OLHO_ATE)
	_olhos.material_override = mo
	_olhos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_olhos.custom_aabb = tudo
	_olhos.extra_cull_margin = 1.0
	_mats.append(mo)
	add_child(_olhos)
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter(&"pescoco", PESCOCO)
		m.set_shader_parameter(&"ombro", OMBRO)
		m.set_shader_parameter(&"cotovelo", COTOVELO)
		m.set_shader_parameter(&"punho", PUNHO)
		m.set_shader_parameter(&"nos_y", PUNHO.y - PALMA)
		m.set_shader_parameter(&"cintura", CINTURA)
		m.set_shader_parameter(&"parada", _parada)
		m.set_shader_parameter(&"parada_varia", PARADA_VARIA)
		m.set_shader_parameter(&"anda_setor", _anda)


# --- a figura ---------------------------------------------------------------

## A batina, a murca, os bracos com as maos e o capuz com a cara, numa malha so.
## UV2.x marca a parte (0 corpo, 1 cabeca, 2 braco esquerdo, 3 direito) e UV2.y
## o pedaco dela (no braco: 0 braco, 1 antebraco, 2 mao, 3 dedo e 4 a garra de
## longe, os dois mais 0,9 x a fracao do comprimento; 6 a calota da cara).
## COLOR.a: 0 pano, 1 pele.
static func _figura() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1077
	# A batina: da barra (larga, com dobras, arrastando atras) ao pescoco.
	var batina := []
	for anel: Array in [[0.0, 0.40, 0.38, 0.10], [0.06, 0.37, 0.33, 0.06],
			[0.45, 0.31, 0.25, 0.02], [0.92, 0.25, 0.18, 0.0], [1.12, 0.25, 0.18, 0.0],
			[1.30, 0.265, 0.17, 0.0], [1.43, 0.22, 0.15, 0.0], [1.50, 0.08, 0.08, 0.0]]:
		batina.append(_anel(float(anel[0]), float(anel[1]), float(anel[2]), float(anel[3]),
			16, 0.035 if float(anel[0]) < 0.5 else 0.0, rng))
	_costurar(st, batina, PANO, 0.0, false, true)
	# A murca: capa curta sobre os ombros. Acaba acima do cotovelo: comprida,
	# ela escondia os bracos.
	var murca := [_anel(1.49, 0.12, 0.11, 0.0, 16, 0.0, rng),
		_anel(1.42, 0.28, 0.20, 0.0, 16, 0.0, rng),
		_anel(1.27, 0.315, 0.235, 0.01, 16, 0.015, rng)]
	_costurar(st, murca, PANO * 1.1, 0.0, false, false)
	for lado: float in [-1.0, 1.0]:
		_braco(st, lado)
	# O capuz: da boca (na frente) ate a ponta atras, que sobe.
	var capuz := []
	var cy := 1.665
	for k in 8:
		var u := float(k) / 7.0
		var z := lerpf(-0.125, 0.19, u)
		var larg := lerpf(0.125, 0.155, sin(u * PI * 0.8)) * (1.0 - pow(u, 5.0) * 0.9)
		var alto := lerpf(0.165, 0.19, sin(u * PI * 0.7)) * (1.0 - pow(u, 5.0) * 0.85)
		var sobe := pow(u, 3.0) * 0.08
		var pts := PackedVector3Array()
		for j in 14:
			var a := float(j) / 14.0 * TAU
			pts.append(Vector3(cos(a) * larg, cy + sobe + sin(a) * alto, z))
		capuz.append(pts)
	_costurar_z(st, capuz, PANO * 0.9, 1.0)
	# O fundo do capuz: preto, atras da borda do rosto.
	var fundo := PackedVector3Array()
	for j in 14:
		var a := float(j) / 14.0 * TAU
		fundo.append(Vector3(cos(a) * 0.118, cy + sin(a) * 0.158, -0.022))
	_leque(st, fundo, Vector3(0.0, cy, -0.017), Color(0.0, 0.0, 0.0, 0.0), Vector2(1.0, 0.0))
	_rosto(st)
	st.index()
	st.generate_normals()
	return st.commit()


## O braco de um lado, pendurado: a manga larga do ombro ate o meio do
## antebraco, o antebraco nu e fino saindo dela, a palma e os dedos compridos.
## A palma olha para dentro (para a coxa) e o polegar para a frente.
static func _braco(st: SurfaceTool, lado: float) -> void:
	var parte := 2.0 if lado < 0.0 else 3.0
	var o := Vector3(OMBRO.x * lado, OMBRO.y, OMBRO.z)
	var c := Vector3(COTOVELO.x * lado, COTOVELO.y, COTOVELO.z)
	var p := Vector3(PUNHO.x * lado, PUNHO.y, PUNHO.z)
	var boca := c.lerp(p, MANGA_ATE)
	var manga := PANO * 1.05
	# A manga: o braco (0) ate o cotovelo, e o antebraco (1) dali ate a boca,
	# que abre em sino.
	_tubo(st, [o + Vector3(0.0, 0.03, 0.0), c], [Vector2(0.07, 0.07), Vector2(0.08, 0.08)],
		manga, parte, 0.0, 8, true, false)
	_tubo(st, [c, c.lerp(boca, 0.5), boca], [Vector2(0.08, 0.08), Vector2(0.088, 0.088),
		Vector2(0.105, 0.105)], manga, parte, 1.0, 8, false, false)
	# O antebraco nu, fino e ossudo, de dentro da manga ate o punho.
	var pele := Color(PELE.r * 0.9, PELE.g * 0.88, PELE.b * 0.86, 1.0)
	_tubo(st, [c.lerp(p, 0.25), c.lerp(p, 0.7), p], [Vector2(0.029, 0.029), Vector2(0.024, 0.023),
		Vector2(0.018, 0.02)], pele, parte, 1.0, 6, false, false)
	# A palma: achatada em x (espessura), larga em z, do punho aos nos.
	var nos := p + Vector3(0.0, -PALMA, 0.0)
	_tubo(st, [p + Vector3(0.0, 0.006, 0.0), p.lerp(nos, 0.45), nos], [PALMA_PUNHO,
		Vector2(0.017, 0.045), PALMA_NOS], PELE, parte, 2.0, 8, false, true)
	# Os dedos: quatro tubos de tres falanges, com o no grosso, abrindo em leque.
	for d: Array in DEDOS:
		var z := float(d[0])
		var base := nos + Vector3(-lado * 0.002, 0.012, z)
		var rumo := Vector3(0.0, -1.0, z * 1.4).normalized()
		_dedo(st, base, rumo, float(d[1]), float(d[2]), parte)
	# O polegar: sai do lado de dentro, perto do punho, para a frente e para
	# baixo.
	var base_p := p + Vector3(-lado * 0.012, -0.035, -0.03)
	var rumo_p := Vector3(-lado * 0.25, -0.8, -0.5).normalized()
	_dedo(st, base_p, rumo_p, float(POLEGAR[0]), float(POLEGAR[1]), parte)
	# A garra de longe (sub 4): os quatro dedos num gomo so, largo nos nos e
	# fino na ponta, do comprimento medio deles. O shader mostra ela ou os dedos.
	var comp := 0.0
	for d: Array in DEDOS:
		comp += float(d[1]) / float(DEDOS.size())
	var fr := [0.0, 0.5, 0.92, 1.0]
	var meia := [Vector2(0.014, 0.046), Vector2(0.011, 0.030), Vector2(0.006, 0.012),
		Vector2(0.002, 0.003)]
	var aneis: Array = []
	for k in fr.size():
		var centro := nos + Vector3(-lado * 0.002, 0.012 - comp * float(fr[k]), 0.0)
		var r: Vector2 = meia[k]
		var anel := PackedVector3Array()
		for j in 4:
			var a := float(j) / 4.0 * TAU + PI * 0.25
			anel.append(centro + Vector3(cos(a) * r.x, 0.0, sin(a) * r.y))
		aneis.append(anel)
	for k in aneis.size() - 1:
		var a0: PackedVector3Array = aneis[k]
		var a1: PackedVector3Array = aneis[k + 1]
		var c0 := PELE.lerp(UNHA, smoothstep(0.8, 1.0, float(fr[k])))
		var c1 := PELE.lerp(UNHA, smoothstep(0.8, 1.0, float(fr[k + 1])))
		var s0 := 4.0 + 0.9 * minf(float(fr[k]), 0.999)
		var s1 := 4.0 + 0.9 * minf(float(fr[k + 1]), 0.999)
		for j in 4:
			var j1 := (j + 1) % 4
			_vert(st, a0[j], c0, parte, s0)
			_vert(st, a1[j], c1, parte, s1)
			_vert(st, a0[j1], c0, parte, s0)
			_vert(st, a0[j1], c0, parte, s0)
			_vert(st, a1[j], c1, parte, s1)
			_vert(st, a1[j1], c1, parte, s1)


## Um dedo de `base` para `rumo`: o no do meio, a ponta afinando na unha escura.
## Quatro lados e dois gomos: a 10 m o dedo tem dois pixels, e cada triangulo a
## mais sai centenas de vezes. UV2.y = 3 + 0,9 x fracao.
static func _dedo(st: SurfaceTool, base: Vector3, rumo: Vector3, comp: float, r: float,
		parte: float) -> void:
	var fr := [0.0, 0.5, 0.92]
	var raio := [1.0, 0.9, 0.55]
	var u := rumo.cross(Vector3.FORWARD)
	if u.length_squared() < 0.01:
		u = rumo.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := rumo.cross(u).normalized()
	var lados := 4
	var aneis: Array = []
	var cores: Array = []
	var subs: Array = []
	for k in fr.size():
		var centro := base + rumo * comp * float(fr[k])
		var anel := PackedVector3Array()
		for j in lados:
			var a := float(j) / float(lados) * TAU
			anel.append(centro + (u * cos(a) + v * sin(a)) * r * float(raio[k]))
		aneis.append(anel)
		cores.append(PELE.lerp(UNHA, smoothstep(0.8, 1.0, float(fr[k]))))
		subs.append(3.0 + 0.9 * minf(float(fr[k]), 0.999))
	for k in aneis.size() - 1:
		var a: PackedVector3Array = aneis[k]
		var b: PackedVector3Array = aneis[k + 1]
		for j in lados:
			var j1 := (j + 1) % lados
			_vert(st, a[j], cores[k], parte, subs[k])
			_vert(st, b[j], cores[k + 1], parte, subs[k + 1])
			_vert(st, a[j1], cores[k], parte, subs[k])
			_vert(st, a[j1], cores[k], parte, subs[k])
			_vert(st, b[j], cores[k + 1], parte, subs[k + 1])
			_vert(st, b[j1], cores[k + 1], parte, subs[k + 1])
	# A ponta: a garra.
	var ultimo: PackedVector3Array = aneis[aneis.size() - 1]
	var ponta := base + rumo * (comp + r * 0.4)
	for j in lados:
		_vert(st, ultimo[j], UNHA, parte, 3.0 + 0.9 * 0.999)
		_vert(st, ponta, UNHA, parte, 3.0 + 0.9 * 0.999)
		_vert(st, ultimo[(j + 1) % lados], UNHA, parte, 3.0 + 0.9 * 0.999)


## O rosto: meia elipsoide de frente (a calota), com a foto da cabeca projetada
## de frente (u = 0,5 - x / lado, como a camera do assado a ve).
static func _rosto(st: SurfaceTool) -> void:
	# Poucos vertices: cada um roda a conta da figura em centenas delas.
	var aneis := 4
	var lados := 12
	var pts: Array = []
	for i in aneis + 1:
		var th := float(i) / float(aneis) * deg_to_rad(82.0)
		var anel := PackedVector3Array()
		for j in lados:
			var ph := float(j) / float(lados) * TAU
			anel.append(ROSTO_CENTRO + Vector3(sin(th) * cos(ph) * ROSTO_MEIO.x,
				sin(th) * sin(ph) * ROSTO_MEIO.y, -cos(th) * ROSTO_MEIO.z))
		pts.append(anel)
	for i in aneis:
		var a: PackedVector3Array = pts[i]
		var b: PackedVector3Array = pts[i + 1]
		for j in lados:
			var j1 := (j + 1) % lados
			# Horario visto de frente: a calota e frente para a lente, e a normal
			# que o shader poe (a da foto) nao e virada pelo lado de tras.
			for p: Vector3 in [a[j], b[j], a[j1], a[j1], b[j], b[j1]]:
				st.set_color(Color(1.0, 1.0, 1.0, 0.0))
				st.set_uv(Vector2(0.5 - (p.x - ROSTO_CENTRO.x) / ROSTO_LADO,
					0.5 - (p.y - ROSTO_CENTRO.y) / ROSTO_LADO))
				st.set_uv2(Vector2(1.0, 6.0))
				st.add_vertex(p)


## O par de quads dos olhos (UV2.x o lado): o shader poe cada um na cara.
static func _par_de_olhos() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cantos := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for lado: float in [-1.0, 1.0]:
		for k: int in [0, 2, 1, 0, 3, 2]:
			var c: Vector2 = cantos[k]
			st.set_uv(c * 0.5 + Vector2(0.5, 0.5))
			st.set_uv2(Vector2(lado, 0.0))
			st.add_vertex(Vector3(c.x, c.y, 0.0))
	return st.commit()


## Um anel de superelipse na altura `y`, meia largura `rx`, meia profundidade
## `rz`, com a barra deslocada `atras` para +z (o arrasto) e dobras.
static func _anel(y: float, rx: float, rz: float, atras: float, lados: int,
		dobra: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var fase := rng.randf() * TAU
	for j in lados:
		var a := float(j) / float(lados) * TAU
		var c := cos(a)
		var s := sin(a)
		var r := 1.0 + dobra * sin(a * 7.0 + fase) / maxf(rx, 0.01)
		var z := s * rz * r + (atras if s > 0.0 else 0.0) * s
		pts.append(Vector3(c * rx * r, y, z))
	return pts


## Costura aneis empilhados em y. `fecha_topo` tampa o ultimo anel num ponto.
static func _costurar(st: SurfaceTool, aneis: Array, cor: Color, parte: float,
		fecha_base: bool, fecha_topo: bool) -> void:
	var n: int = (aneis[0] as PackedVector3Array).size()
	for i in aneis.size() - 1:
		var a: PackedVector3Array = aneis[i]
		var b: PackedVector3Array = aneis[i + 1]
		for j in n:
			var j1 := (j + 1) % n
			_tri(st, a[j], b[j], a[j1], cor, parte)
			_tri(st, a[j1], b[j], b[j1], cor, parte)
	if fecha_topo:
		var ultimo: PackedVector3Array = aneis[aneis.size() - 1]
		var centro := Vector3(0.0, ultimo[0].y + 0.01, 0.0)
		for j in n:
			_tri(st, ultimo[j], centro, ultimo[(j + 1) % n], cor, parte)
	if fecha_base:
		var primeiro: PackedVector3Array = aneis[0]
		var centro := Vector3(0.0, primeiro[0].y, 0.0)
		for j in n:
			_tri(st, primeiro[(j + 1) % n], centro, primeiro[j], cor, parte)


## Costura aneis empilhados em z (o capuz), e fecha o de tras numa ponta.
static func _costurar_z(st: SurfaceTool, aneis: Array, cor: Color, parte: float) -> void:
	var n: int = (aneis[0] as PackedVector3Array).size()
	for i in aneis.size() - 1:
		var a: PackedVector3Array = aneis[i]
		var b: PackedVector3Array = aneis[i + 1]
		for j in n:
			var j1 := (j + 1) % n
			_tri(st, a[j], a[j1], b[j], cor, parte)
			_tri(st, a[j1], b[j1], b[j], cor, parte)
	var ultimo: PackedVector3Array = aneis[aneis.size() - 1]
	var c := Vector3.ZERO
	for p in ultimo:
		c += p
	c /= float(ultimo.size())
	c.z += 0.03
	for j in n:
		_tri(st, ultimo[j], ultimo[(j + 1) % n], c, cor, parte)


## Um leque do `centro` ate a `borda`. `inverte` troca o giro (a frente do
## triangulo, que a normal gerada segue).
static func _leque(st: SurfaceTool, borda: PackedVector3Array, centro: Vector3, cor: Color,
		uv2: Vector2, inverte: bool = false) -> void:
	for j in borda.size():
		var a := borda[j]
		var b := borda[(j + 1) % borda.size()]
		for p: Vector3 in ([centro, b, a] if inverte else [centro, a, b]):
			_vert(st, p, cor, uv2.x, uv2.y)


## Um tubo pelos pontos `pts`, com a meia secao `rs` (x ao longo de u, y de v)
## em cada um: u sai do eixo cruzado com -Z (no braco pendurado, o x), v do eixo
## cruzado com u (o z). `sub` vai em UV2.y. Tampa a ponta e a base se pedido.
static func _tubo(st: SurfaceTool, pts: Array, rs: Array, cor: Color, parte: float,
		sub: float, lados: int, tampa_base: bool, tampa_ponta: bool) -> void:
	var eixo := ((pts[pts.size() - 1] as Vector3) - (pts[0] as Vector3)).normalized()
	var u := eixo.cross(Vector3.FORWARD).normalized()
	var v := eixo.cross(u).normalized()
	var aneis: Array = []
	for k in pts.size():
		var r: Vector2 = rs[k]
		var anel := PackedVector3Array()
		for j in lados:
			var a := float(j) / float(lados) * TAU
			anel.append((pts[k] as Vector3) + u * cos(a) * r.x + v * sin(a) * r.y)
		aneis.append(anel)
	for k in aneis.size() - 1:
		var a: PackedVector3Array = aneis[k]
		var b: PackedVector3Array = aneis[k + 1]
		for j in lados:
			var j1 := (j + 1) % lados
			for p: Vector3 in [a[j], b[j], a[j1], a[j1], b[j], b[j1]]:
				_vert(st, p, cor, parte, sub)
	# A tampa da ponta gira ao contrario da da base: as duas com a normal para
	# fora, como o tubo (senao a normal media da borda cancela).
	if tampa_ponta:
		_leque(st, aneis[aneis.size() - 1], (pts[pts.size() - 1] as Vector3) + eixo * 0.008,
			cor, Vector2(parte, sub), true)
	if tampa_base:
		_leque(st, aneis[0], (pts[0] as Vector3) - eixo * 0.008, cor, Vector2(parte, sub))


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, cor: Color,
		parte: float) -> void:
	for p: Vector3 in [a, b, c]:
		_vert(st, p, cor, parte, 0.0)


static func _vert(st: SurfaceTool, p: Vector3, cor: Color, parte: float, sub: float) -> void:
	st.set_color(cor)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2(parte, sub))
	st.add_vertex(p)

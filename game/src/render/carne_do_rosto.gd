## A carne do rosto do padre principal: o que na cara dele e mole, e mexe.
##
## Por que existe
## --------------
## A `CabecaDoPadre` era um casco: girava a queixada e afundava o osso no golpe,
## e nada mais. Na cabecada a cara chegava no vidro, parava e voltava como um
## manequim de vitrine. Carne de verdade esmaga no vidro e espalha, atrasa
## quando a cabeca acelera e bate para a frente quando ela para, balanca depois,
## franze e repuxa com o musculo, cora onde apanhou.
##
## Como funciona
## -------------
## Tudo e deformacao no `vertex()` da pele, sem tocar na malha nem ler vertice
## no processador: este no so guarda estado (molas, canais de musculo, o vidro)
## e escreve 64 floats de uniforme por quadro no material. O peso de cada coisa
## sai da posicao de REPOUSO do vertice (o `p_obj` do shader), com elipsoides
## nas medidas de `tools/gerar_padre.py`: vale para qualquer malha da mesma
## cabeca (a da boca nova tambem), sem indice nem atributo novo.
##
## No shader, na ordem do `vertex()`:
##   1. `carne_repouso`: musculos, inercia, onda do golpe e tremor, no espaco de
##      repouso; a normal sai por diferenca finita do mesmo campo;
##   2. a queixada e o amassado que ja existiam;
##   3. `carne_no_vidro`: por ultimo, o que passa do plano do vidro fica nele, e
##      a carne mole em volta avanca, gruda e espalha para os lados.
## E no fim do `fragment()` (`carne_luz`): a ruga onde o musculo comprime, o
## rubor e o hematoma onde bateu, a pele branca onde prensa, a translucidez da
## carne fina, o brilho de suor e oleosidade.
##
## So o principal liga (`no_vidro`, que a `CabecaDoPadre` recebe em
## `lascas_no_vidro`); a bancada liga com `vidro_de_teste`. Os outros padres
## pagam um desvio no shader e nada mais. `--rosto-duro` nao monta o no (A/B).
class_name CarneDoRosto
extends Node

## O include de vertice (`#CARNE`, depois de `#AMASSO` no `PELE_SHADER`).
const VERTICE := """
// --- A carne do rosto (`CarneDoRosto`, carne_do_rosto.gd) ---
// Zero ate o no ligar (`carne_liga.x`): os outros padres pagam o desvio.
// carne_liga: x liga, y suor, zw tremor (m). carne_reg: o deslocamento de cada
// regiao mole (m, malha). carne_musc: 12 canais de musculo. carne_vidro: a
// normal do vidro (malha, para o lado dele) e o d do plano; xyz 0 sem vidro.
// carne_prensa: x pressao, y amplitude da onda (m), z tremor (m), w a folga
// (m) que a carne fecha ate o vidro (a cena para a cabeca a um fio dele). carne_onda:
// onde bateu (malha) e ha quantos segundos. carne_hema: centro e quanto.
uniform vec4 carne_liga = vec4(0.0);
uniform vec4 carne_reg[7];
uniform vec4 carne_musc[3];
uniform vec4 carne_vidro = vec4(0.0);
uniform vec4 carne_prensa = vec4(0.0);
uniform vec4 carne_onda = vec4(0.0, 0.0, 0.0, 100.0);
uniform vec4 carne_hema[2];

varying vec3 carne_n0;
varying vec3 carne_n1;
varying vec4 carne_k;

// O passo da diferenca finita da normal (m).
const float C_EPS = 0.0012;
// A onda do golpe: velocidade (m/s), comprimento (m) e quanto dura (s). Da
// ~11 Hz: devagar o bastante para 60 quadros por segundo a verem andar.
const float C_ONDA_VEL = 0.45;
const float C_ONDA_LAMBDA = 0.040;
const float C_ONDA_TAU = 0.20;
// O vidro: quanto a carne mole avanca com a pressao 1 (m), ate que distancia
// do vidro ela e puxada (m), e quanto do que passa espalha para o lado.
const float C_AVANCO = 0.006;
const float C_FAIXA = 0.014;
const float C_ESPALHA = 1.2;

float c_bolha(vec3 p, vec3 c, vec3 r) {
	vec3 q = (p - c) / r;
	float k = max(1.0 - dot(q, q), 0.0);
	return k * k;
}

// Em volta da fenda, na curva da boca (a de tools/gerar_padre.py).
vec3 c_na_boca(vec3 p) {
	vec3 q = p - vec3(0.0, -0.060, -0.094);
	q.y -= 11.0 * min(q.x * q.x, 0.0009);
	return q;
}

float c_labio(vec3 p) {
	return c_bolha(c_na_boca(p), vec3(0.0), vec3(0.040, 0.019, 0.024));
}

// A maciez: 0,15 a pele no osso (testa, cranio, maca, ponte do nariz), 1 a
// carne mole (bochecha, labio, papada).
float c_maciez(vec3 p) {
	vec3 m = vec3(abs(p.x), p.y, p.z);
	float s = 0.15;
	s = max(s, c_bolha(m, vec3(0.045, -0.045, -0.056), vec3(0.030, 0.034, 0.036)));
	s = max(s, c_bolha(p, vec3(0.0, -0.060, -0.096), vec3(0.046, 0.030, 0.026)));
	s = max(s, 0.8 * c_bolha(p, vec3(0.0, -0.031, -0.106), vec3(0.024, 0.017, 0.018)));
	s = max(s, 0.55 * c_bolha(p, vec3(0.0, -0.098, -0.084), vec3(0.030, 0.022, 0.022)));
	s = max(s, 0.9 * c_bolha(p, vec3(0.0, -0.118, -0.050), vec3(0.058, 0.030, 0.055)));
	s = max(s, 0.5 * c_bolha(m, vec3(0.020, -0.160, -0.010), vec3(0.060, 0.060, 0.050)));
	return s;
}

// O deslocamento da carne (m, repouso) no ponto de repouso p, de normal n.
vec3 c_desloca(vec3 p, vec3 n) {
	vec3 m = vec3(abs(p.x), p.y, p.z);
	float sx = p.x < 0.0 ? -1.0 : 1.0;
	vec3 d = vec3(0.0);
	// A inercia: cada regiao mole com a sua mola.
	d += carne_reg[0].xyz * c_bolha(p, vec3(-0.046, -0.046, -0.058), vec3(0.034, 0.036, 0.036));
	d += carne_reg[1].xyz * c_bolha(p, vec3(0.046, -0.046, -0.058), vec3(0.034, 0.036, 0.036));
	d += carne_reg[2].xyz * c_bolha(p, vec3(0.0, -0.049, -0.098), vec3(0.044, 0.016, 0.026));
	d += carne_reg[3].xyz * c_bolha(p, vec3(0.0, -0.077, -0.094), vec3(0.044, 0.026, 0.028));
	d += carne_reg[4].xyz * c_bolha(p, vec3(0.0, -0.116, -0.048), vec3(0.060, 0.036, 0.062));
	d += carne_reg[5].xyz * c_bolha(p, vec3(0.0, -0.031, -0.106), vec3(0.024, 0.020, 0.020));
	d += carne_reg[6].xyz * c_bolha(p, vec3(0.0, 0.036, -0.078), vec3(0.075, 0.050, 0.050));
	vec4 ma = carne_musc[0];
	vec4 mb = carne_musc[1];
	vec4 mc = carne_musc[2];
	vec3 q = c_na_boca(p);
	float lab = c_bolha(q, vec3(0.0), vec3(0.040, 0.019, 0.024));
	// Frontal: a sobrancelha sobe, a testa vem atras.
	float w_sob = c_bolha(m, vec3(0.026, 0.024, -0.086), vec3(0.042, 0.016, 0.030));
	float w_tes = c_bolha(p, vec3(0.0, 0.050, -0.078), vec3(0.060, 0.030, 0.040));
	d.y += ma.x * (0.0050 * w_sob + 0.0020 * w_tes);
	// Corrugador e procero: o meio da sobrancelha desce e junta.
	float w_cor = c_bolha(m, vec3(0.014, 0.022, -0.089), vec3(0.020, 0.013, 0.022));
	float w_pro = c_bolha(p, vec3(0.0, 0.010, -0.092), vec3(0.010, 0.012, 0.016));
	d += ma.y * (w_cor * vec3(-sx * 0.0036, -0.0028, -0.0008) + w_pro * vec3(0.0, -0.0018, 0.0));
	// Rosnado (elevador do labio e da asa do nariz): o labio de cima e a asa
	// sobem, a bochecha do lado do nariz estufa.
	float w_lsup = c_bolha(m, vec3(0.012, -0.047, -0.099), vec3(0.020, 0.012, 0.022));
	float w_asa = c_bolha(m, vec3(0.0105, -0.034, -0.099), vec3(0.010, 0.010, 0.013));
	float w_nl = c_bolha(m, vec3(0.022, -0.036, -0.090), vec3(0.013, 0.016, 0.020));
	d += ma.z * (w_lsup * vec3(sx * 0.0005, 0.0030, -0.0008)
		+ w_asa * vec3(sx * 0.0010, 0.0026, -0.0004) + w_nl * vec3(sx * 0.0006, 0.0026, -0.0020));
	// Zigomatico (o esquerdo em x < 0): o canto sobe e abre, a bochecha sobe.
	float zg = p.x < 0.0 ? ma.w : mb.x;
	float w_can = c_bolha(m, vec3(0.031, -0.050, -0.090), vec3(0.016, 0.014, 0.022));
	float w_boc = c_bolha(m, vec3(0.040, -0.030, -0.072), vec3(0.022, 0.020, 0.026));
	d += zg * (w_can * vec3(sx * 0.0026, 0.0036, -0.0010) + w_boc * vec3(sx * 0.0010, 0.0036, -0.0026));
	// Orbicular: o bico (O) junta e empurra para fora; o aperto (M) fecha.
	d += mb.y * (lab * vec3(-p.x * 0.09, -q.y * 0.10, -0.0026) + w_boc * vec3(-sx * 0.0015, 0.0, 0.0));
	d += mb.z * lab * vec3(0.0, -q.y * 0.10, -0.0008);
	// Depressor: o canto e o labio de baixo descem e viram para fora.
	float w_dep = c_bolha(m, vec3(0.030, -0.060, -0.088), vec3(0.016, 0.018, 0.022));
	float w_linf = c_bolha(p, vec3(0.0, -0.071, -0.097), vec3(0.030, 0.010, 0.020));
	d += mb.w * (w_dep * vec3(sx * 0.0012, -0.0036, -0.0006) + w_linf * vec3(0.0, -0.0018, -0.0018));
	// Mentual: o queixo sobe e empurra o labio de baixo.
	float w_qx = c_bolha(p, vec3(0.0, -0.098, -0.086), vec3(0.022, 0.017, 0.020));
	d += mc.x * (w_qx * vec3(0.0, 0.0032, -0.0018) + w_linf * vec3(0.0, 0.0010, -0.0016));
	// Platisma: as cordas do pescoco saltam e o canto e puxado para baixo.
	float w_pes = c_bolha(m, vec3(0.028, -0.150, -0.012), vec3(0.042, 0.060, 0.045));
	float c1 = (m.x - 0.022) / 0.0045;
	float c2 = (m.x - 0.040) / 0.0055;
	float corda = exp(-c1 * c1) + 0.6 * exp(-c2 * c2);
	d += mc.y * (n * (0.0022 * corda * w_pes) + w_dep * vec3(sx * 0.0014, -0.0018, 0.0));
	// As narinas abrem; a respiracao enche a papada e o pescoco.
	d += mc.z * w_asa * vec3(sx * 0.0016, 0.0004, -0.0003);
	float w_pap = c_bolha(p, vec3(0.0, -0.118, -0.040), vec3(0.060, 0.040, 0.060));
	d += mc.w * (n * (0.0010 * w_pap) + vec3(0.0, 0.0005, 0.0) * w_pes);
	// O tremor fino, so na carne mole.
	float mac = c_maciez(p);
	float mole = max(mac - 0.2, 0.0);
	vec3 tr = vec3(carne_liga.z, carne_liga.w, carne_prensa.z);
	d += mole * (tr * cos(dot(p, vec3(60.0, 80.0, 20.0))) + tr.yzx * sin(dot(p, vec3(-70.0, 50.0, 30.0))));
	// A onda do golpe: um anel que sai de onde bateu, pela pele.
	float t = carne_onda.w;
	if (t < 1.2 && carne_prensa.y > 0.0) {
		float r = length(p - carne_onda.xyz);
		float fr = C_ONDA_VEL * t;
		float chegou = 1.0 - smoothstep(fr - 0.004, fr + 0.004, r);
		float h = sin(6.2832 * (fr - r) / C_ONDA_LAMBDA) * chegou * exp(-t / C_ONDA_TAU) * exp(-r / 0.06);
		d += n * (h * carne_prensa.y * (0.4 + 0.6 * mac));
	}
	// O labio nao entra na boca (os dentes estao la): anda em x/y e para fora,
	// ate 3 mm.
	d.z = mix(d.z, min(d.z, 0.0), lab);
	float ld = length(d);
	d *= mix(1.0, min(1.0, 0.003 / max(ld, 1e-6)), lab);
	return d;
}

// Musculo, inercia, onda e tremor no repouso; `nrm` vira a normal deformada.
vec3 carne_repouso(vec3 p, vec3 n, inout vec3 nrm) {
	if (carne_liga.x < 0.5) {
		return p;
	}
	vec3 d0 = c_desloca(p, n);
	if (dot(d0, d0) < 1e-14) {
		return p;
	}
	vec3 t1 = normalize(cross(n, abs(n.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 t2 = cross(n, t1);
	vec3 e1 = t1 * C_EPS + c_desloca(p + t1 * C_EPS, n) - d0;
	vec3 e2 = t2 * C_EPS + c_desloca(p + t2 * C_EPS, n) - d0;
	nrm = normalize(cross(e1, e2));
	return p + d0;
}

// O vidro: `e` o quanto passou dele (o que espalha), `puxa` o quanto a carne
// foi puxada ate ele.
vec3 c_esmaga(vec3 v, float mac, float lab, out float e, out float puxa) {
	vec3 pn = carne_vidro.xyz;
	float g = dot(v, pn) - carne_vidro.w;
	// A carne perto do vidro avanca `alcance`: a folga que a cabeca deixou e
	// o que a pressao empurra (a mole mais). Mais longe, cada vez menos.
	float alcance = carne_prensa.w + carne_prensa.x * C_AVANCO * (0.3 + 0.7 * mac);
	float sh = alcance * (1.0 - smoothstep(max(alcance, 0.0), max(alcance, 0.0) + C_FAIXA, g));
	float ge = g - sh;
	e = max(-ge, 0.0);
	float mov = g - max(ge, 0.0);
	mov = max(mov, -mix(0.05, 0.003, lab));
	puxa = max(mov, 0.0);
	vec3 r = v - carne_onda.xyz;
	vec3 rt = r - pn * dot(r, pn);
	float lr = length(rt);
	vec3 lado = rt / max(lr, 1e-5) * smoothstep(0.0, 0.008, lr);
	return v - pn * mov + lado * (min(e, 0.012) * C_ESPALHA * (0.15 + 0.85 * mac));
}

// Por ultimo no vertex(): o esmagamento no vidro. `n0` e a normal de repouso
// com a queixada (para o fragment girar a dele ate a deformada).
vec3 carne_no_vidro(vec3 v, inout vec3 nrm, vec3 p, vec3 n, float queixada, out vec3 n0,
		out vec4 k) {
	n0 = girar_x(n, -abre * giro_max * queixada);
	k = vec4(0.0);
	if (carne_liga.x < 0.5) {
		n0 = nrm;
		return v;
	}
	float mac = c_maciez(p);
	k.y = mac;
	vec3 pn = carne_vidro.xyz;
	float longe = C_FAIXA + C_EPS * 2.0 + carne_prensa.w + max(carne_prensa.x, 0.0) * C_AVANCO;
	if (dot(pn, pn) < 0.5 || dot(v, pn) - carne_vidro.w > longe) {
		return v;
	}
	float lab = c_labio(p);
	vec3 t1 = normalize(cross(nrm, abs(nrm.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 t2 = cross(nrm, t1);
	float e0;
	float pu0;
	float e_;
	float pu_;
	vec3 v0 = c_esmaga(v, mac, lab, e0, pu0);
	vec3 v1 = c_esmaga(v + t1 * C_EPS, mac, lab, e_, pu_);
	vec3 v2 = c_esmaga(v + t2 * C_EPS, mac, lab, e_, pu_);
	vec3 nn = cross(v1 - v0, v2 - v0);
	if (dot(nn, nn) > 1e-14) {
		nrm = normalize(nn);
	}
	k.x = smoothstep(0.0, 0.0015, e0);
	k.z = e0;
	k.w = pu0;
	return v0;
}
"""

## O include de fragment (`#CARNE_LUZ`, antes do `fragment()` do `PELE_SHADER`).
const LUZ := """
// A ruga: um sulco fino (gaussiana de largura s, na fracao do periodo).
// Devolve dh/du (m por m de u) e soma o fundo em `sulco`.
float c_sulco(float fi, float amp, float s, float periodo, inout float sulco) {
	float f = fract(fi) - 0.5;
	float gr = exp(-f * f / (2.0 * s * s));
	sulco += gr * amp / 0.00025;
	return amp * gr * f / (s * s) / periodo;
}

// No fim do fragment(): a ruga, o rubor e o hematoma, a pele prensada, a
// translucidez e o suor, por cima de tudo. `ferida` (o gore e o sangue) fica
// como esta.
void carne_luz(vec3 p, vec3 n0, vec3 n1, vec4 k, float ferida, mat4 vm, mat4 mm,
		inout vec3 alb, inout vec3 nrm, inout float rug, inout float sss) {
	if (carne_liga.x < 0.5) {
		return;
	}
	vec3 m = vec3(abs(p.x), p.y, p.z);
	float sx = p.x < 0.0 ? -1.0 : 1.0;
	float viva = 1.0 - clamp(ferida, 0.0, 1.0);
	vec4 ma = carne_musc[0];
	vec4 mb = carne_musc[1];
	vec4 mc = carne_musc[2];
	// G: o gradiente da altura das rugas (malha); sulco: o fundo delas.
	vec3 G = vec3(0.0);
	float sulco = 0.0;
	// Testa (frontal): linhas deitadas, cada uma do seu comprimento.
	float w = c_bolha(p, vec3(0.0, 0.048, -0.080), vec3(0.058, 0.028, 0.045)) * ma.x;
	if (w > 0.001) {
		float u = p.y + 0.0025 * sin(p.x * 70.0 + 1.3) + 0.0010 * sin(p.x * 190.0);
		float i = floor(u / 0.0058);
		float hi = h3(vec3(i, 7.1, 3.3));
		float comp = 0.022 + 0.03 * hi;
		float amp = 0.00045 * (0.6 + 0.8 * hi)
			* (1.0 - smoothstep(comp - 0.012, comp, abs(p.x + (hi - 0.5) * 0.012)));
		float s0 = 0.0;
		float dh = c_sulco(u / 0.0058, amp, 0.13, 0.0058, s0);
		G += w * dh * vec3(0.0025 * 70.0 * cos(p.x * 70.0 + 1.3) + 0.0010 * 190.0 * cos(p.x * 190.0), 1.0, 0.0);
		sulco += w * s0;
	}
	// Entre os olhos (corrugador): dois riscos em pe de cada lado.
	w = c_bolha(p, vec3(0.0, 0.019, -0.090), vec3(0.016, 0.016, 0.025)) * ma.y;
	if (w > 0.001) {
		float xw = m.x + 0.0005 * sin(p.y * 420.0);
		float f1 = (xw - 0.0036) / 0.0009;
		float f2 = (xw - 0.0078) / 0.0011;
		float g1 = exp(-f1 * f1);
		float g2 = exp(-f2 * f2) * 0.7;
		float vy = smoothstep(0.004, 0.012, p.y) * (1.0 - smoothstep(0.024, 0.034, p.y));
		float dh = 0.00048 * (2.0 * f1 * g1 / 0.0009 + 2.0 * f2 * g2 / 0.0011);
		G += w * vy * dh * vec3(sx, 0.0, 0.0);
		sulco += w * vy * (g1 + g2);
	}
	// O nariz franzido (rosnado): riscos inclinados do lado da ponte.
	w = c_bolha(m, vec3(0.009, 0.001, -0.090), vec3(0.008, 0.010, 0.020)) * ma.z;
	if (w > 0.001) {
		vec2 perp = vec2(0.83, 0.55);
		float u = m.x * perp.x + p.y * perp.y + 0.0004 * sin(p.y * 900.0);
		float s0 = 0.0;
		float dh = c_sulco(u / 0.0026, 0.00028, 0.12, 0.0026, s0);
		G += w * dh * vec3(sx * perp.x, perp.y, 0.0);
		sulco += w * s0;
	}
	// O sulco do nariz a boca: fundo com o zigomatico e o rosnado, a bochecha
	// estufando do lado de fora.
	float zg = p.x < 0.0 ? ma.w : mb.x;
	float znl = max(ma.z, zg * 0.9);
	if (znl > 0.01 && m.x < 0.05 && p.y < -0.025 && p.y > -0.075) {
		vec2 A = vec2(0.0145, -0.036);
		vec2 B = vec2(0.037, -0.067);
		vec2 ab = B - A;
		vec2 q = vec2(m.x, p.y);
		float tt = clamp(dot(q - A, ab) / dot(ab, ab), 0.0, 1.0);
		vec2 dv = q - (A + ab * tt);
		vec2 pe = normalize(vec2(-ab.y, ab.x));
		float sd = dot(dv, pe);
		float ao_longo = smoothstep(0.0, 0.15, tt) * (1.0 - smoothstep(0.75, 1.0, tt))
			* (1.0 - smoothstep(0.004, 0.012, length(dv)));
		float amp = 0.0009 * znl * ao_longo;
		float a1 = sd / 0.0012;
		float a2 = (sd - 0.0035) / 0.003;
		float e1 = exp(-a1 * a1);
		float e2 = exp(-a2 * a2);
		float dh = amp * (2.0 * a1 * e1 / 0.0012 - 0.8 * 2.0 * a2 * e2 / 0.003);
		G += dh * vec3(pe.x * sx, pe.y, 0.0);
		sulco += e1 * znl * ao_longo;
	}
	// Pe de galinha (zigomatico forte): riscos em leque do canto do olho.
	float zo = smoothstep(0.35, 0.9, zg);
	if (zo > 0.001) {
		vec2 q = vec2(m.x - 0.045, p.y - 0.002);
		float r = length(q);
		float ang = atan(q.y, q.x);
		float wf = zo * smoothstep(0.004, 0.008, r) * (1.0 - smoothstep(0.013, 0.02, r))
			* (1.0 - smoothstep(0.45, 0.75, abs(ang)));
		if (wf > 0.001) {
			float s0 = 0.0;
			float dh = c_sulco(ang / 0.2 + 0.5, 0.00026, 0.15, 0.2, s0);
			vec2 ga = vec2(-q.y, q.x) / max(r * r, 1e-8);
			G += wf * dh * vec3(ga.x * sx, ga.y, 0.0);
			sulco += wf * s0;
		}
	}
	// O queixo do mentual: a casca de laranja.
	w = c_bolha(p, vec3(0.0, -0.098, -0.086), vec3(0.020, 0.015, 0.022)) * mc.x;
	if (w > 0.001) {
		float e = 0.0004;
		float h0 = vruido(p * 700.0);
		float hx = vruido((p + vec3(e, 0.0, 0.0)) * 700.0);
		float hy = vruido((p + vec3(0.0, e, 0.0)) * 700.0);
		G += w * -0.00034 * vec3(hx - h0, hy - h0, 0.0) / e;
		sulco += w * smoothstep(0.55, 0.85, h0) * 0.6;
	}
	// A normal: da de repouso ate a deformada (e com a ruga), o mesmo giro
	// sobre a que a pele ja tem (a racha, o poro, a ferida).
	vec3 gt = G - n1 * dot(G, n1);
	vec3 n1w = normalize(n1 - gt * viva);
	vec3 a0 = normalize((vm * (mm * vec4(n0, 0.0))).xyz);
	vec3 a1 = normalize((vm * (mm * vec4(n1w, 0.0))).xyz);
	vec3 cr = cross(a0, a1);
	float dd = dot(a0, a1);
	if (dd > -0.9) {
		nrm = normalize(nrm + cross(cr, nrm) + cross(cr, cross(cr, nrm)) / (1.0 + dd));
	}
	// O fundo da ruga, mais escuro.
	alb *= 1.0 - clamp(sulco, 0.0, 1.0) * 0.26 * viva;
	// Onde bateu: o rubor largo logo, o hematoma roxo no meio crescendo, os
	// pontinhos de sangue pisado em volta.
	for (int i = 0; i < 2; i++) {
		vec4 hm = carne_hema[i];
		// Longe do golpe nada muda: o ruido so onde ha rubor.
		if (hm.w <= 0.001 || length(p - hm.xyz) > 0.07) {
			continue;
		}
		float nz = vruido(p * 260.0 + float(i) * 7.0);
		float dist = length(p - hm.xyz) + (nz - 0.5) * 0.010;
		float rub = clamp(hm.w * 1.6, 0.0, 1.0) * (1.0 - smoothstep(0.012, 0.055, dist));
		float hem = smoothstep(0.5, 2.6, hm.w) * (1.0 - smoothstep(0.005, 0.020 + 0.004 * hm.w, dist));
		float pet = smoothstep(0.80, 0.9, vruido(p * 1400.0 + float(i) * 3.0))
			* (1.0 - smoothstep(0.012, 0.036, dist)) * smoothstep(0.3, 1.2, hm.w);
		alb *= mix(vec3(1.0), vec3(1.0, 0.62, 0.58), rub * 0.75 * viva);
		alb *= mix(vec3(1.0), vec3(0.50, 0.30, 0.44), hem * 0.85 * viva);
		alb *= mix(vec3(1.0), vec3(0.62, 0.24, 0.24), pet * 0.7 * viva);
	}
	// Prensada no vidro, a pele fica branca (o sangue sai); a borda, que
	// recebe o sangue, cora.
	float prensa = k.x;
	float borda = smoothstep(0.0, 0.002, k.w) * (1.0 - prensa);
	alb *= mix(vec3(1.0), vec3(1.10, 1.05, 0.95), prensa * 0.75 * viva);
	alb *= mix(vec3(1.0), vec3(1.0, 0.80, 0.76), borda * 0.5 * viva);
	// A carne fina e mole deixa a luz entrar: a orelha, a asa do nariz, o
	// labio. Prensada, nao.
	float fina = max(c_bolha(m, vec3(0.074, -0.004, 0.012), vec3(0.016, 0.032, 0.022)),
		max(c_bolha(m, vec3(0.0105, -0.034, -0.099), vec3(0.012, 0.010, 0.013)), c_labio(p)));
	sss += (0.14 * fina + 0.07 * k.y) * viva * (1.0 - prensa);
	// O brilho: a zona T oleosa, o suor que sobe com o esforco, em manchas.
	float tz = max(c_bolha(p, vec3(0.0, 0.045, -0.080), vec3(0.042, 0.030, 0.050)),
		max(c_bolha(p, vec3(0.0, -0.020, -0.105), vec3(0.014, 0.032, 0.020)),
		c_bolha(p, vec3(0.0, -0.098, -0.086), vec3(0.018, 0.014, 0.020))));
	float oleo = (0.4 * tz + carne_liga.y * 0.6) * smoothstep(0.35, 0.75, vruido(p * 140.0 + 11.0));
	rug = mix(rug, rug * 0.72, clamp(oleo, 0.0, 1.0) * viva);
}
"""

## As regioes moles (as de `carne_reg` no shader, na mesma ordem): [centro
## (malha, m), mola (Hz), amortecimento (fracao do critico), ganho (m/s de
## carne por m/s que a cabeca muda), limite (m)].
## O labio de baixo e o queixo mole balancam 0,5 s depois do golpe (5 Hz, 0,10:
## a 0,5 s sobra 20%); o nariz e a testa, no osso, quase nada.
const REGIOES := [
	[Vector3(-0.046, -0.046, -0.058), 5.5, 0.13, 0.06, 0.008],
	[Vector3(0.046, -0.046, -0.058), 5.5, 0.13, 0.06, 0.008],
	[Vector3(0.0, -0.049, -0.098), 8.0, 0.15, 0.05, 0.003],
	[Vector3(0.0, -0.077, -0.094), 5.0, 0.10, 0.04, 0.005],
	[Vector3(0.0, -0.116, -0.048), 4.0, 0.15, 0.05, 0.008],
	[Vector3(0.0, -0.031, -0.106), 12.0, 0.20, 0.04, 0.0025],
	[Vector3(0.0, 0.036, -0.078), 16.0, 0.28, 0.025, 0.0012],
]
## Os canais de musculo (a ordem de `carne_musc`).
enum M { FRONTAL, CORRUGADOR, ROSNADO, ZIGO_E, ZIGO_D, ORBICULAR, APERTO, DEPRESSOR,
	MENTUAL, PLATISMA, NARINA, RESPIRA }
## Quanto o musculo leva para contrair e para soltar (s).
const MUSCULO_SOBE := 0.05
const MUSCULO_DESCE := 0.16
## A velocidade da cabeca que o processador aceita (m/s): acima e teleporte.
const VEL_MAX := 14.0
## O toque: a folga (m, malha) em que a carne alcanca o vidro, e ate onde ela
## gruda descolando (a pele sai do vidro devagar).
const CONTATO := 0.006
const GRUDA := 0.009
## A cena para a testa a um fio do vidro (a pele fica ~4 mm antes dele): a
## carne fecha essa folga, ate isto (m, malha), enquanto prensa.
const FECHA_MAX := 0.006
## A pressao no vidro: por m/s do golpe, o maximo, a que fica com a cara
## colada, e a mola dela (Hz, fracao do critico). Solta, ela passa do zero (a
## carne volta e treme).
const PRENSA_POR_VEL := 0.2
const PRENSA_MAX := 1.2
const PRENSA_SEGURA := 0.4
const PRENSA_HZ := 9.0
const PRENSA_AMORTECE := 0.35
## A onda: amplitude (m) por m/s do golpe, e o maximo.
const ONDA_POR_VEL := 0.0004
const ONDA_MAX := 0.0025
## O tremor fino da carne (m) em repouso e no esforco inteiro.
const TREMOR := Vector2(0.00004, 0.00012)
## Abaixo disto (m/s) o toque nao e golpe: se o dano sobe junto, a medida falhou.
const GOLPE_MIN := 4.0
## Abaixo disto (m/s) a cara so encosta: pressao de colada, sem onda nem dor.
const ENCOSTA := 1.2
## Mais que isto num quadro (m) e teleporte da cena, nao movimento.
const TELEPORTE := 0.3
## Nos primeiros segundos ligada (s), toque nenhum e golpe.
const ARRUMA := 0.5
## A testa (malha): onde o hematoma nasce quando o golpe nao passou pelo vidro.
const TESTA := Vector3(0.0, 0.052, -0.088)

# SONDAS-INICIO (tools/gerar_mapa_carne.py, 664 pontos)
const SONDAS := [
	Vector3(-0.0805, -0.0080, 0.0038), Vector3(-0.0802, -0.0063, 0.0225), Vector3(-0.0801, 0.0005, 0.0021),
	Vector3(-0.0641, -0.0165, -0.0489), Vector3(-0.0640, -0.0165, -0.0472), Vector3(-0.0644, -0.0188, -0.0217),
	Vector3(-0.0648, -0.0182, -0.0064), Vector3(-0.0697, -0.0233, 0.0072), Vector3(-0.0723, -0.0216, 0.0225),
	Vector3(-0.0644, -0.0097, -0.0642), Vector3(-0.0660, -0.0097, -0.0557), Vector3(-0.0644, -0.0114, -0.0458),
	Vector3(-0.0651, -0.0080, -0.0200), Vector3(-0.0712, -0.0080, -0.0028), Vector3(-0.0790, -0.0080, 0.0072),
	Vector3(-0.0712, -0.0097, 0.0271), Vector3(-0.0650, -0.0046, 0.0361), Vector3(-0.0644, 0.0022, -0.0168),
	Vector3(-0.0674, 0.0073, -0.0047), Vector3(-0.0795, 0.0090, 0.0072), Vector3(-0.0747, 0.0090, 0.0259),
	Vector3(-0.0683, 0.0073, 0.0361), Vector3(-0.0665, 0.0243, -0.0081), Vector3(-0.0729, 0.0216, 0.0089),
	Vector3(-0.0701, 0.0226, 0.0242), Vector3(-0.0690, 0.0243, 0.0361), Vector3(-0.0644, 0.0409, -0.0183),
	Vector3(-0.0674, 0.0396, -0.0081), Vector3(-0.0700, 0.0396, 0.0072), Vector3(-0.0695, 0.0398, 0.0242),
	Vector3(-0.0671, 0.0396, 0.0361), Vector3(-0.0644, 0.0515, -0.0174), Vector3(-0.0661, 0.0543, -0.0064),
	Vector3(-0.0667, 0.0566, 0.0072), Vector3(-0.0661, 0.0555, 0.0242), Vector3(-0.0650, 0.0515, 0.0361),
	Vector3(-0.0644, 0.0640, 0.0140), Vector3(-0.0498, -0.1015, 0.0106), Vector3(-0.0491, -0.0981, 0.0174),
	Vector3(-0.0491, -0.0811, -0.0345), Vector3(-0.0508, -0.0833, -0.0234), Vector3(-0.0525, -0.0850, -0.0081),
	Vector3(-0.0527, -0.0879, 0.0072), Vector3(-0.0525, -0.0862, 0.0227), Vector3(-0.0491, -0.0692, -0.0492),
	Vector3(-0.0528, -0.0726, -0.0404), Vector3(-0.0577, -0.0726, -0.0251), Vector3(-0.0595, -0.0726, -0.0081),
	Vector3(-0.0585, -0.0709, 0.0072), Vector3(-0.0576, -0.0726, 0.0257), Vector3(-0.0525, -0.0692, 0.0344),
	Vector3(-0.0491, -0.0624, -0.0481), Vector3(-0.0556, -0.0556, -0.0404), Vector3(-0.0611, -0.0556, -0.0251),
	Vector3(-0.0631, -0.0556, -0.0081), Vector3(-0.0610, -0.0556, 0.0077), Vector3(-0.0616, -0.0556, 0.0242),
	Vector3(-0.0576, -0.0573, 0.0362), Vector3(-0.0499, -0.0335, -0.0489), Vector3(-0.0562, -0.0403, -0.0421),
	Vector3(-0.0627, -0.0403, -0.0245), Vector3(-0.0633, -0.0403, -0.0081), Vector3(-0.0612, -0.0403, 0.0072),
	Vector3(-0.0596, -0.0403, 0.0242), Vector3(-0.0563, -0.0403, 0.0361), Vector3(-0.0542, -0.0176, -0.0693),
	Vector3(-0.0559, -0.0227, -0.0540), Vector3(-0.0609, -0.0250, -0.0404), Vector3(-0.0637, -0.0267, -0.0251),
	Vector3(-0.0631, -0.0267, -0.0081), Vector3(-0.0621, -0.0250, 0.0089), Vector3(-0.0600, -0.0250, 0.0242),
	Vector3(-0.0576, -0.0236, 0.0361), Vector3(-0.0576, -0.0075, -0.0744), Vector3(-0.0633, -0.0029, -0.0574),
	Vector3(-0.0621, -0.0063, -0.0404), Vector3(-0.0627, -0.0063, -0.0276), Vector3(-0.0627, -0.0148, 0.0276),
	Vector3(-0.0627, -0.0114, 0.0370), Vector3(-0.0525, 0.0073, -0.0664), Vector3(-0.0563, 0.0073, -0.0557),
	Vector3(-0.0581, 0.0073, -0.0404), Vector3(-0.0610, 0.0090, -0.0241), Vector3(-0.0635, 0.0124, -0.0149),
	Vector3(-0.0491, 0.0226, -0.0806), Vector3(-0.0559, 0.0243, -0.0735), Vector3(-0.0537, 0.0243, -0.0557),
	Vector3(-0.0568, 0.0243, -0.0404), Vector3(-0.0609, 0.0243, -0.0234), Vector3(-0.0632, 0.0209, -0.0149),
	Vector3(-0.0508, 0.0345, -0.0695), Vector3(-0.0498, 0.0379, -0.0540), Vector3(-0.0561, 0.0396, -0.0404),
	Vector3(-0.0622, 0.0396, -0.0251), Vector3(-0.0495, 0.0532, -0.0506), Vector3(-0.0552, 0.0566, -0.0404),
	Vector3(-0.0613, 0.0566, -0.0251), Vector3(-0.0627, 0.0617, -0.0103), Vector3(-0.0640, 0.0634, 0.0021),
	Vector3(-0.0628, 0.0634, 0.0293), Vector3(-0.0619, 0.0600, 0.0395), Vector3(-0.0560, 0.0634, 0.0565),
	Vector3(-0.0508, 0.0617, 0.0680), Vector3(-0.0508, 0.0685, -0.0380), Vector3(-0.0544, 0.0719, -0.0251),
	Vector3(-0.0581, 0.0719, -0.0081), Vector3(-0.0604, 0.0719, 0.0072), Vector3(-0.0602, 0.0719, 0.0242),
	Vector3(-0.0573, 0.0719, 0.0395), Vector3(-0.0525, 0.0715, 0.0548), Vector3(-0.0491, 0.0664, 0.0667),
	Vector3(-0.0491, 0.0819, -0.0200), Vector3(-0.0513, 0.0838, -0.0081), Vector3(-0.0523, 0.0855, 0.0089),
	Vector3(-0.0514, 0.0855, 0.0242), Vector3(-0.0508, 0.0834, 0.0378), Vector3(-0.0491, 0.0804, 0.0486),
	Vector3(-0.0326, -0.1644, -0.0166), Vector3(-0.0337, -0.1644, -0.0115), Vector3(-0.0321, -0.1542, -0.0173),
	Vector3(-0.0361, -0.1525, -0.0115), Vector3(-0.0372, -0.1355, -0.0100), Vector3(-0.0418, -0.1287, 0.0072),
	Vector3(-0.0403, -0.1287, 0.0242), Vector3(-0.0391, -0.1287, 0.0361), Vector3(-0.0389, -0.1202, -0.0066),
	Vector3(-0.0445, -0.1202, 0.0089), Vector3(-0.0409, -0.1202, 0.0242), Vector3(-0.0392, -0.1202, 0.0361),
	Vector3(-0.0338, -0.0967, -0.0200), Vector3(-0.0377, -0.1032, -0.0064), Vector3(-0.0477, -0.1066, 0.0055),
	Vector3(-0.0425, -0.1032, 0.0242), Vector3(-0.0385, -0.1032, 0.0361), Vector3(-0.0338, -0.0819, -0.0659),
	Vector3(-0.0372, -0.0856, -0.0540), Vector3(-0.0393, -0.0879, -0.0404), Vector3(-0.0406, -0.0904, -0.0251),
	Vector3(-0.0440, -0.0925, -0.0081), Vector3(-0.0474, -0.0947, 0.0018), Vector3(-0.0457, -0.0900, 0.0276),
	Vector3(-0.0406, -0.0879, 0.0353), Vector3(-0.0326, -0.0671, -0.0814), Vector3(-0.0354, -0.0711, -0.0751),
	Vector3(-0.0440, -0.0726, -0.0566), Vector3(-0.0473, -0.0777, -0.0455), Vector3(-0.0440, -0.0743, 0.0374),
	Vector3(-0.0331, -0.0537, -0.0969), Vector3(-0.0352, -0.0552, -0.0884), Vector3(-0.0338, -0.0569, -0.0748),
	Vector3(-0.0389, -0.0556, -0.0553), Vector3(-0.0470, -0.0522, -0.0472), Vector3(-0.0474, -0.0624, 0.0398),
	Vector3(-0.0326, -0.0472, -0.0966), Vector3(-0.0348, -0.0437, -0.0889), Vector3(-0.0332, -0.0437, -0.0765),
	Vector3(-0.0381, -0.0403, -0.0540), Vector3(-0.0470, -0.0437, -0.0472), Vector3(-0.0358, -0.0233, -0.0863),
	Vector3(-0.0406, -0.0238, -0.0727), Vector3(-0.0423, -0.0280, -0.0574), Vector3(-0.0376, -0.0131, -0.0829),
	Vector3(-0.0406, -0.0093, -0.0710), Vector3(-0.0355, -0.0029, -0.0615), Vector3(-0.0457, 0.0107, -0.0652),
	Vector3(-0.0389, 0.0083, -0.0608), Vector3(-0.0389, 0.0260, -0.0834), Vector3(-0.0389, 0.0208, -0.0727),
	Vector3(-0.0321, 0.0175, -0.0637), Vector3(-0.0338, 0.0335, -0.0812), Vector3(-0.0389, 0.0388, -0.0727),
	Vector3(-0.0457, 0.0430, -0.0593), Vector3(-0.0355, 0.0548, -0.0659), Vector3(-0.0433, 0.0566, -0.0574),
	Vector3(-0.0474, 0.0634, -0.0479), Vector3(-0.0443, 0.0634, 0.0752), Vector3(-0.0367, 0.0617, 0.0837),
	Vector3(-0.0321, 0.0641, -0.0642), Vector3(-0.0372, 0.0707, -0.0540), Vector3(-0.0440, 0.0746, -0.0421),
	Vector3(-0.0473, 0.0787, -0.0302), Vector3(-0.0457, 0.0770, 0.0600), Vector3(-0.0406, 0.0719, 0.0734),
	Vector3(-0.0346, 0.0685, 0.0820), Vector3(-0.0321, 0.0804, -0.0489), Vector3(-0.0372, 0.0848, -0.0387),
	Vector3(-0.0415, 0.0889, -0.0251), Vector3(-0.0445, 0.0923, -0.0098), Vector3(-0.0458, 0.0940, 0.0072),
	Vector3(-0.0457, 0.0931, 0.0242), Vector3(-0.0440, 0.0906, 0.0409), Vector3(-0.0389, 0.0880, 0.0548),
	Vector3(-0.0353, 0.0821, 0.0684), Vector3(-0.0338, 0.0975, -0.0200), Vector3(-0.0355, 0.1003, -0.0081),
	Vector3(-0.0382, 0.1008, 0.0072), Vector3(-0.0375, 0.1008, 0.0242), Vector3(-0.0348, 0.0991, 0.0378),
	Vector3(-0.0321, 0.0974, 0.0485), Vector3(-0.0197, -0.2001, -0.0353), Vector3(-0.0225, -0.2001, -0.0234),
	Vector3(-0.0185, -0.1967, -0.0068), Vector3(-0.0185, -0.1899, -0.0330), Vector3(-0.0270, -0.1831, -0.0270),
	Vector3(-0.0241, -0.1848, -0.0098), Vector3(-0.0253, -0.1678, -0.0242), Vector3(-0.0309, -0.1729, -0.0098),
	Vector3(-0.0236, -0.1525, -0.0191), Vector3(-0.0185, -0.1474, -0.0154), Vector3(-0.0270, -0.1440, -0.0166),
	Vector3(-0.0236, -0.1355, -0.0133), Vector3(-0.0173, -0.1151, -0.0166), Vector3(-0.0236, -0.1200, -0.0115),
	Vector3(-0.0189, -0.1015, -0.0710), Vector3(-0.0203, -0.0998, -0.0557), Vector3(-0.0228, -0.0998, -0.0404),
	Vector3(-0.0245, -0.1032, -0.0234), Vector3(-0.0270, -0.1083, -0.0127), Vector3(-0.0178, -0.0828, -0.0815),
	Vector3(-0.0222, -0.0851, -0.0759), Vector3(-0.0270, -0.0930, -0.0573), Vector3(-0.0303, -0.0947, -0.0438),
	Vector3(-0.0217, -0.0686, -0.0999), Vector3(-0.0240, -0.0719, -0.0880), Vector3(-0.0292, -0.0777, -0.0774),
	Vector3(-0.0287, -0.0590, -0.0965), Vector3(-0.0296, -0.0582, -0.0880), Vector3(-0.0241, -0.0522, -0.0778),
	Vector3(-0.0319, -0.0488, -0.0625), Vector3(-0.0236, -0.0429, -0.1007), Vector3(-0.0202, -0.0480, -0.0931),
	Vector3(-0.0310, -0.0437, -0.0693), Vector3(-0.0317, -0.0437, -0.0625), Vector3(-0.0202, -0.0250, -0.0993),
	Vector3(-0.0286, -0.0233, -0.0931), Vector3(-0.0183, -0.0148, -0.0965), Vector3(-0.0236, -0.0076, -0.0880),
	Vector3(-0.0219, -0.0097, -0.0706), Vector3(-0.0253, -0.0029, -0.0614), Vector3(-0.0168, 0.0124, -0.0863),
	Vector3(-0.0170, 0.0124, -0.0676), Vector3(-0.0236, 0.0073, -0.0602), Vector3(-0.0236, 0.0243, -0.0879),
	Vector3(-0.0236, 0.0201, -0.0710), Vector3(-0.0304, 0.0162, -0.0625), Vector3(-0.0219, 0.0362, -0.0839),
	Vector3(-0.0253, 0.0430, -0.0772), Vector3(-0.0244, 0.0566, -0.0727), Vector3(-0.0253, 0.0617, 0.0931),
	Vector3(-0.0168, 0.0617, 0.0969), Vector3(-0.0219, 0.0685, -0.0671), Vector3(-0.0253, 0.0753, -0.0599),
	Vector3(-0.0304, 0.0790, 0.0786), Vector3(-0.0236, 0.0719, 0.0884), Vector3(-0.0219, 0.0841, -0.0540),
	Vector3(-0.0253, 0.0918, -0.0421), Vector3(-0.0304, 0.0957, -0.0302), Vector3(-0.0278, 0.0940, 0.0599),
	Vector3(-0.0236, 0.0889, 0.0718), Vector3(-0.0202, 0.0819, 0.0820), Vector3(-0.0202, 0.0986, -0.0353),
	Vector3(-0.0236, 0.1022, -0.0234), Vector3(-0.0236, 0.1072, -0.0081), Vector3(-0.0253, 0.1091, 0.0072),
	Vector3(-0.0253, 0.1084, 0.0242), Vector3(-0.0236, 0.1059, 0.0395), Vector3(-0.0219, 0.1003, 0.0548),
	Vector3(-0.0168, 0.0968, 0.0650), Vector3(-0.0168, 0.1126, 0.0106), Vector3(-0.0168, 0.1127, 0.0208),
	Vector3(-0.0117, -0.2001, -0.0365), Vector3(-0.0088, -0.2001, -0.0234), Vector3(-0.0083, -0.2001, -0.0110),
	Vector3(-0.0151, -0.1916, -0.0333), Vector3(-0.0114, -0.1848, -0.0251), Vector3(-0.0066, -0.1848, -0.0126),
	Vector3(-0.0134, -0.1695, -0.0190), Vector3(-0.0066, -0.1678, -0.0135), Vector3(-0.0066, -0.1491, -0.0164),
	Vector3(-0.0100, -0.1542, -0.0143), Vector3(-0.0066, -0.1355, -0.0187), Vector3(-0.0139, -0.1355, -0.0149),
	Vector3(-0.0015, -0.1123, -0.0710), Vector3(-0.0066, -0.1185, -0.0189), Vector3(-0.0134, -0.1236, -0.0145),
	Vector3(-0.0066, -0.0998, -0.0866), Vector3(-0.0106, -0.1100, -0.0727), Vector3(-0.0083, -0.1076, -0.0557),
	Vector3(-0.0084, -0.1049, -0.0404), Vector3(-0.0100, -0.1096, -0.0268), Vector3(-0.0083, -0.0875, -0.0852),
	Vector3(-0.0087, -0.0737, -0.1016), Vector3(-0.0100, -0.0770, -0.0927), Vector3(-0.0062, -0.0512, -0.1024),
	Vector3(-0.0079, -0.0501, -0.0897), Vector3(-0.0155, -0.0485, -0.0795), Vector3(-0.0032, -0.0350, -0.1135),
	Vector3(-0.0087, -0.0420, -0.1068), Vector3(-0.0142, -0.0472, -0.0905), Vector3(-0.0049, -0.0284, -0.1141),
	Vector3(-0.0100, -0.0219, -0.1067), Vector3(-0.0082, -0.0097, -0.0999), Vector3(-0.0141, -0.0029, -0.0931),
	Vector3(-0.0134, -0.0029, -0.0740), Vector3(-0.0032, 0.0007, -0.0965), Vector3(-0.0100, 0.0073, -0.0910),
	Vector3(-0.0125, 0.0073, -0.0727), Vector3(-0.0087, 0.0243, -0.0914), Vector3(-0.0083, 0.0396, -0.0863),
	Vector3(-0.0151, 0.0477, -0.0795), Vector3(-0.0049, 0.0485, -0.0812), Vector3(-0.0083, 0.0566, -0.0769),
	Vector3(-0.0083, 0.0621, 0.0990), Vector3(-0.0083, 0.0719, -0.0690), Vector3(-0.0134, 0.0787, -0.0630),
	Vector3(-0.0089, 0.0736, 0.0922), Vector3(-0.0066, 0.0660, 0.0973), Vector3(-0.0030, 0.0804, -0.0642),
	Vector3(-0.0083, 0.0889, -0.0561), Vector3(-0.0100, 0.0957, -0.0460), Vector3(-0.0083, 0.0923, 0.0739),
	Vector3(-0.0083, 0.0836, 0.0837), Vector3(-0.0083, 0.1008, -0.0393), Vector3(-0.0083, 0.1079, -0.0251),
	Vector3(-0.0100, 0.1109, -0.0098), Vector3(-0.0151, 0.1118, 0.0004), Vector3(-0.0151, 0.1113, 0.0310),
	Vector3(-0.0100, 0.1100, 0.0412), Vector3(-0.0087, 0.1042, 0.0565), Vector3(-0.0083, 0.0980, 0.0667),
	Vector3(-0.0066, 0.1130, -0.0047), Vector3(-0.0083, 0.1145, 0.0072), Vector3(-0.0083, 0.1140, 0.0242),
	Vector3(-0.0049, 0.1126, 0.0327), Vector3(0.0115, -0.2001, -0.0370), Vector3(0.0083, -0.2001, -0.0234),
	Vector3(0.0087, -0.1984, -0.0105), Vector3(0.0138, -0.1897, -0.0336), Vector3(0.0102, -0.1831, -0.0251),
	Vector3(0.0070, -0.1848, -0.0123), Vector3(0.0127, -0.1695, -0.0200), Vector3(0.0053, -0.1678, -0.0137),
	Vector3(0.0070, -0.1498, -0.0166), Vector3(0.0087, -0.1542, -0.0147), Vector3(0.0070, -0.1372, -0.0192),
	Vector3(0.0139, -0.1355, -0.0149), Vector3(0.0019, -0.1122, -0.0693), Vector3(0.0070, -0.1181, -0.0183),
	Vector3(0.0138, -0.1236, -0.0144), Vector3(0.0070, -0.0998, -0.0876), Vector3(0.0098, -0.1100, -0.0727),
	Vector3(0.0087, -0.1081, -0.0557), Vector3(0.0087, -0.1053, -0.0404), Vector3(0.0087, -0.1092, -0.0268),
	Vector3(0.0083, -0.0875, -0.0856), Vector3(0.0083, -0.0755, -0.1011), Vector3(0.0100, -0.0789, -0.0935),
	Vector3(0.0078, -0.0528, -0.1033), Vector3(0.0087, -0.0519, -0.0914), Vector3(0.0019, -0.0347, -0.1135),
	Vector3(0.0085, -0.0424, -0.1066), Vector3(0.0036, -0.0284, -0.1139), Vector3(0.0101, -0.0233, -0.1067),
	Vector3(0.0070, -0.0080, -0.1005), Vector3(0.0155, -0.0012, -0.0933), Vector3(0.0145, -0.0029, -0.0744),
	Vector3(0.0036, 0.0019, -0.0965), Vector3(0.0104, 0.0073, -0.0920), Vector3(0.0125, 0.0073, -0.0727),
	Vector3(0.0087, 0.0252, -0.0914), Vector3(0.0070, 0.0396, -0.0853), Vector3(0.0147, 0.0464, -0.0795),
	Vector3(0.0036, 0.0481, -0.0809), Vector3(0.0087, 0.0566, -0.0765), Vector3(0.0087, 0.0617, 0.0990),
	Vector3(0.0087, 0.0719, -0.0692), Vector3(0.0155, 0.0787, -0.0632), Vector3(0.0087, 0.0737, 0.0922),
	Vector3(0.0053, 0.0660, 0.0973), Vector3(0.0028, 0.0804, -0.0642), Vector3(0.0087, 0.0889, -0.0559),
	Vector3(0.0104, 0.0954, -0.0472), Vector3(0.0087, 0.0923, 0.0747), Vector3(0.0070, 0.0842, 0.0837),
	Vector3(0.0070, 0.1008, -0.0394), Vector3(0.0087, 0.1069, -0.0251), Vector3(0.0104, 0.1110, -0.0106),
	Vector3(0.0138, 0.1113, 0.0293), Vector3(0.0087, 0.1099, 0.0395), Vector3(0.0087, 0.1042, 0.0557),
	Vector3(0.0070, 0.0985, 0.0667), Vector3(0.0053, 0.1133, -0.0047), Vector3(0.0087, 0.1147, 0.0072),
	Vector3(0.0070, 0.1139, 0.0242), Vector3(0.0019, 0.1126, 0.0327), Vector3(0.0200, -0.2001, -0.0353),
	Vector3(0.0231, -0.2001, -0.0234), Vector3(0.0189, -0.1967, -0.0067), Vector3(0.0189, -0.1888, -0.0336),
	Vector3(0.0274, -0.1831, -0.0261), Vector3(0.0223, -0.1841, -0.0115), Vector3(0.0257, -0.1678, -0.0243),
	Vector3(0.0297, -0.1712, -0.0098), Vector3(0.0240, -0.1525, -0.0190), Vector3(0.0206, -0.1457, -0.0158),
	Vector3(0.0240, -0.1372, -0.0137), Vector3(0.0172, -0.1134, -0.0165), Vector3(0.0240, -0.1202, -0.0106),
	Vector3(0.0163, -0.0964, -0.0812), Vector3(0.0197, -0.1015, -0.0710), Vector3(0.0201, -0.0998, -0.0557),
	Vector3(0.0231, -0.0998, -0.0404), Vector3(0.0240, -0.1043, -0.0234), Vector3(0.0274, -0.1083, -0.0126),
	Vector3(0.0182, -0.0841, -0.0813), Vector3(0.0232, -0.0853, -0.0760), Vector3(0.0274, -0.0925, -0.0557),
	Vector3(0.0301, -0.0947, -0.0421), Vector3(0.0232, -0.0699, -0.0994), Vector3(0.0246, -0.0723, -0.0884),
	Vector3(0.0295, -0.0771, -0.0770), Vector3(0.0253, -0.0532, -0.0995), Vector3(0.0257, -0.0538, -0.0884),
	Vector3(0.0236, -0.0556, -0.0791), Vector3(0.0318, -0.0488, -0.0625), Vector3(0.0240, -0.0429, -0.1006),
	Vector3(0.0315, -0.0420, -0.0954), Vector3(0.0312, -0.0420, -0.0676), Vector3(0.0314, -0.0437, -0.0625),
	Vector3(0.0223, -0.0250, -0.0995), Vector3(0.0291, -0.0216, -0.0947), Vector3(0.0189, -0.0131, -0.0971),
	Vector3(0.0251, -0.0063, -0.0880), Vector3(0.0223, -0.0097, -0.0704), Vector3(0.0274, -0.0029, -0.0614),
	Vector3(0.0172, 0.0102, -0.0863), Vector3(0.0172, 0.0124, -0.0665), Vector3(0.0240, 0.0073, -0.0603),
	Vector3(0.0240, 0.0243, -0.0879), Vector3(0.0240, 0.0208, -0.0727), Vector3(0.0308, 0.0175, -0.0636),
	Vector3(0.0223, 0.0362, -0.0834), Vector3(0.0257, 0.0430, -0.0769), Vector3(0.0240, 0.0566, -0.0719),
	Vector3(0.0240, 0.0634, 0.0922), Vector3(0.0172, 0.0617, 0.0964), Vector3(0.0223, 0.0685, -0.0667),
	Vector3(0.0258, 0.0753, -0.0608), Vector3(0.0306, 0.0787, 0.0786), Vector3(0.0240, 0.0719, 0.0874),
	Vector3(0.0223, 0.0854, -0.0540), Vector3(0.0259, 0.0923, -0.0421), Vector3(0.0308, 0.0957, -0.0310),
	Vector3(0.0274, 0.0940, 0.0613), Vector3(0.0240, 0.0889, 0.0718), Vector3(0.0206, 0.0821, 0.0810),
	Vector3(0.0206, 0.0981, -0.0370), Vector3(0.0240, 0.1025, -0.0246), Vector3(0.0240, 0.1073, -0.0081),
	Vector3(0.0257, 0.1093, 0.0072), Vector3(0.0240, 0.1093, 0.0242), Vector3(0.0240, 0.1050, 0.0395),
	Vector3(0.0223, 0.1005, 0.0548), Vector3(0.0172, 0.0967, 0.0650), Vector3(0.0189, 0.1127, 0.0092),
	Vector3(0.0172, 0.1127, 0.0179), Vector3(0.0325, -0.1627, -0.0169), Vector3(0.0338, -0.1627, -0.0115),
	Vector3(0.0325, -0.1559, -0.0170), Vector3(0.0354, -0.1525, -0.0115), Vector3(0.0359, -0.1355, -0.0097),
	Vector3(0.0405, -0.1287, 0.0089), Vector3(0.0400, -0.1287, 0.0242), Vector3(0.0388, -0.1287, 0.0361),
	Vector3(0.0388, -0.1202, -0.0064), Vector3(0.0438, -0.1202, 0.0089), Vector3(0.0400, -0.1202, 0.0242),
	Vector3(0.0383, -0.1202, 0.0361), Vector3(0.0342, -0.0973, -0.0217), Vector3(0.0393, -0.1032, -0.0064),
	Vector3(0.0478, -0.1082, 0.0055), Vector3(0.0427, -0.1048, 0.0242), Vector3(0.0373, -0.1032, 0.0361),
	Vector3(0.0330, -0.0828, -0.0659), Vector3(0.0368, -0.0845, -0.0557), Vector3(0.0393, -0.0876, -0.0404),
	Vector3(0.0410, -0.0909, -0.0251), Vector3(0.0444, -0.0925, -0.0098), Vector3(0.0453, -0.0896, 0.0293),
	Vector3(0.0393, -0.0862, 0.0359), Vector3(0.0326, -0.0662, -0.0817), Vector3(0.0347, -0.0705, -0.0744),
	Vector3(0.0443, -0.0726, -0.0557), Vector3(0.0468, -0.0777, -0.0455), Vector3(0.0444, -0.0726, 0.0363),
	Vector3(0.0338, -0.0548, -0.0981), Vector3(0.0360, -0.0565, -0.0884), Vector3(0.0356, -0.0560, -0.0748),
	Vector3(0.0393, -0.0561, -0.0540), Vector3(0.0471, -0.0522, -0.0472), Vector3(0.0468, -0.0624, 0.0395),
	Vector3(0.0322, -0.0476, -0.0963), Vector3(0.0359, -0.0437, -0.0893), Vector3(0.0339, -0.0437, -0.0761),
	Vector3(0.0376, -0.0386, -0.0531), Vector3(0.0477, -0.0437, -0.0472), Vector3(0.0363, -0.0233, -0.0880),
	Vector3(0.0393, -0.0233, -0.0718), Vector3(0.0420, -0.0267, -0.0574), Vector3(0.0376, -0.0131, -0.0833),
	Vector3(0.0410, -0.0097, -0.0714), Vector3(0.0376, -0.0029, -0.0616), Vector3(0.0461, 0.0107, -0.0653),
	Vector3(0.0376, 0.0073, -0.0599), Vector3(0.0393, 0.0260, -0.0826), Vector3(0.0393, 0.0209, -0.0727),
	Vector3(0.0325, 0.0175, -0.0635), Vector3(0.0342, 0.0330, -0.0812), Vector3(0.0393, 0.0386, -0.0710),
	Vector3(0.0448, 0.0430, -0.0608), Vector3(0.0359, 0.0534, -0.0659), Vector3(0.0425, 0.0566, -0.0574),
	Vector3(0.0477, 0.0634, -0.0472), Vector3(0.0444, 0.0626, 0.0752), Vector3(0.0359, 0.0625, 0.0837),
	Vector3(0.0376, 0.0710, -0.0540), Vector3(0.0444, 0.0744, -0.0421), Vector3(0.0478, 0.0779, -0.0302),
	Vector3(0.0461, 0.0767, 0.0599), Vector3(0.0410, 0.0719, 0.0732), Vector3(0.0342, 0.0683, 0.0820),
	Vector3(0.0342, 0.0804, -0.0493), Vector3(0.0369, 0.0855, -0.0387), Vector3(0.0410, 0.0889, -0.0251),
	Vector3(0.0444, 0.0923, -0.0082), Vector3(0.0461, 0.0934, 0.0072), Vector3(0.0461, 0.0928, 0.0242),
	Vector3(0.0436, 0.0906, 0.0412), Vector3(0.0398, 0.0872, 0.0565), Vector3(0.0351, 0.0838, 0.0684),
	Vector3(0.0342, 0.0980, -0.0200), Vector3(0.0359, 0.1002, -0.0081), Vector3(0.0376, 0.1021, 0.0072),
	Vector3(0.0376, 0.1016, 0.0242), Vector3(0.0359, 0.0991, 0.0388), Vector3(0.0325, 0.0974, 0.0497),
	Vector3(0.0500, -0.1015, 0.0089), Vector3(0.0499, -0.0981, 0.0191), Vector3(0.0495, -0.0811, -0.0340),
	Vector3(0.0512, -0.0840, -0.0234), Vector3(0.0516, -0.0862, -0.0081), Vector3(0.0539, -0.0879, 0.0072),
	Vector3(0.0529, -0.0879, 0.0230), Vector3(0.0484, -0.0675, -0.0489), Vector3(0.0529, -0.0716, -0.0404),
	Vector3(0.0580, -0.0726, -0.0243), Vector3(0.0592, -0.0726, -0.0081), Vector3(0.0588, -0.0726, 0.0072),
	Vector3(0.0574, -0.0726, 0.0259), Vector3(0.0512, -0.0689, 0.0344), Vector3(0.0480, -0.0624, -0.0489),
	Vector3(0.0552, -0.0556, -0.0421), Vector3(0.0614, -0.0556, -0.0243), Vector3(0.0630, -0.0556, -0.0081),
	Vector3(0.0603, -0.0556, 0.0072), Vector3(0.0610, -0.0556, 0.0242), Vector3(0.0578, -0.0573, 0.0361),
	Vector3(0.0495, -0.0335, -0.0484), Vector3(0.0563, -0.0401, -0.0421), Vector3(0.0623, -0.0403, -0.0251),
	Vector3(0.0634, -0.0403, -0.0081), Vector3(0.0608, -0.0403, 0.0089), Vector3(0.0590, -0.0403, 0.0242),
	Vector3(0.0562, -0.0403, 0.0361), Vector3(0.0546, -0.0174, -0.0693), Vector3(0.0563, -0.0211, -0.0540),
	Vector3(0.0600, -0.0250, -0.0421), Vector3(0.0635, -0.0250, -0.0268), Vector3(0.0634, -0.0284, -0.0081),
	Vector3(0.0626, -0.0284, 0.0089), Vector3(0.0597, -0.0250, 0.0245), Vector3(0.0563, -0.0244, 0.0361),
	Vector3(0.0592, -0.0080, -0.0744), Vector3(0.0632, -0.0029, -0.0557), Vector3(0.0627, -0.0080, -0.0404),
	Vector3(0.0621, -0.0063, -0.0285), Vector3(0.0627, -0.0131, 0.0293), Vector3(0.0621, -0.0097, 0.0361),
	Vector3(0.0529, 0.0056, -0.0670), Vector3(0.0562, 0.0073, -0.0557), Vector3(0.0580, 0.0078, -0.0404),
	Vector3(0.0602, 0.0090, -0.0251), Vector3(0.0495, 0.0226, -0.0804), Vector3(0.0563, 0.0243, -0.0731),
	Vector3(0.0538, 0.0243, -0.0557), Vector3(0.0568, 0.0243, -0.0404), Vector3(0.0602, 0.0243, -0.0234),
	Vector3(0.0637, 0.0226, -0.0149), Vector3(0.0512, 0.0338, -0.0693), Vector3(0.0512, 0.0391, -0.0540),
	Vector3(0.0570, 0.0396, -0.0404), Vector3(0.0613, 0.0396, -0.0251), Vector3(0.0502, 0.0515, -0.0506),
	Vector3(0.0548, 0.0566, -0.0404), Vector3(0.0615, 0.0566, -0.0251), Vector3(0.0631, 0.0618, -0.0098),
	Vector3(0.0632, 0.0634, 0.0310), Vector3(0.0621, 0.0617, 0.0395), Vector3(0.0564, 0.0634, 0.0565),
	Vector3(0.0512, 0.0617, 0.0675), Vector3(0.0510, 0.0685, -0.0370), Vector3(0.0547, 0.0719, -0.0251),
	Vector3(0.0591, 0.0719, -0.0081), Vector3(0.0600, 0.0736, 0.0072), Vector3(0.0606, 0.0719, 0.0242),
	Vector3(0.0580, 0.0719, 0.0396), Vector3(0.0529, 0.0705, 0.0548), Vector3(0.0495, 0.0668, 0.0659),
	Vector3(0.0495, 0.0821, -0.0194), Vector3(0.0517, 0.0838, -0.0081), Vector3(0.0524, 0.0855, 0.0089),
	Vector3(0.0521, 0.0855, 0.0242), Vector3(0.0512, 0.0830, 0.0395), Vector3(0.0495, 0.0804, 0.0483),
	Vector3(0.0645, -0.0199, -0.0200), Vector3(0.0656, -0.0182, -0.0047), Vector3(0.0699, -0.0267, 0.0065),
	Vector3(0.0716, -0.0233, 0.0227), Vector3(0.0648, -0.0097, -0.0655), Vector3(0.0657, -0.0097, -0.0557),
	Vector3(0.0646, -0.0114, -0.0472), Vector3(0.0650, -0.0080, -0.0200), Vector3(0.0699, -0.0080, -0.0044),
	Vector3(0.0793, -0.0063, 0.0106), Vector3(0.0712, -0.0080, 0.0276), Vector3(0.0648, -0.0029, 0.0351),
	Vector3(0.0645, 0.0039, -0.0166), Vector3(0.0692, 0.0073, -0.0064), Vector3(0.0798, 0.0090, 0.0021),
	Vector3(0.0733, 0.0090, 0.0262), Vector3(0.0670, 0.0073, 0.0361), Vector3(0.0674, 0.0243, -0.0081),
	Vector3(0.0733, 0.0239, 0.0089), Vector3(0.0710, 0.0226, 0.0225), Vector3(0.0681, 0.0243, 0.0361),
	Vector3(0.0644, 0.0396, -0.0166), Vector3(0.0676, 0.0396, -0.0081), Vector3(0.0704, 0.0396, 0.0089),
	Vector3(0.0694, 0.0396, 0.0242), Vector3(0.0668, 0.0396, 0.0361), Vector3(0.0646, 0.0515, -0.0166),
	Vector3(0.0656, 0.0549, -0.0081), Vector3(0.0669, 0.0566, 0.0072), Vector3(0.0669, 0.0566, 0.0242),
	Vector3(0.0654, 0.0532, 0.0361), Vector3(0.0644, 0.0651, 0.0106), Vector3(0.0642, 0.0651, 0.0191),
	Vector3(0.0813, -0.0216, 0.0106), Vector3(0.0811, -0.0199, 0.0191), Vector3(0.0808, -0.0097, 0.0055),
	Vector3(0.0811, -0.0080, 0.0208), Vector3(0.0811, 0.0073, 0.0072), Vector3(0.0809, 0.0073, 0.0208),
	Vector3(0.0801, 0.0170, 0.0123),
]
## A caixa das sondas: longe dela, nem se olha o vidro.
const CAIXA_SONDAS := AABB(Vector3(-0.0805, -0.2001, -0.1141), Vector3(0.1618, 0.3148, 0.2131))
# SONDAS-FIM

## Quanto o sorriso da cena pede (`CabecaDoPadre.por_sorriso`).
var sorriso: float = 0.0
## A antecipacao e o golpe (0 a 1). Com a `CabecadaDoPadre` vem dela; na
## bancada, quem anima escreve aqui.
var golpe_recua: float = 0.0
var golpe_bote: float = 0.0

static var _sondas := PackedVector3Array()

var _cab: CabecaDoPadre
var _mat: ShaderMaterial
var _carro: Node3D
var _cabecada: CabecadaDoPadre
var _teste_o := Vector3.ZERO
var _teste_n := Vector3.ZERO
var _ligada := false
var _log := OS.get_cmdline_user_args().has("--carne-log")
# O custo no log so com `--carne-log` ou `--medir-quadros`.
var _log_cpu := _log or OS.get_cmdline_user_args().has("--medir-quadros")
var _t := 0.0
var _rng := RandomNumberGenerator.new()
# A cabeca no quadro anterior (mundo) e a escala do tempo de entao.
var _xf_ant := Transform3D.IDENTITY
var _tem_ant := false
var _ts_ant := 1.0
# Se este quadro mediu a cabeca (fora da troca de escala do tempo).
var _medido := false
var _v_cab := Vector3.ZERO
var _w_cab := Vector3.ZERO
# As molas das regioes: velocidade do ponto no mundo, deslocamento e
# velocidade da carne (malha).
var _v_pts := PackedVector3Array()
var _u := PackedVector3Array()
var _du := PackedVector3Array()
var _canais := PackedFloat32Array()
# O vidro no espaco da malha ((n, d); n zero sem vidro), a pressao nele.
var _plano := Vector4.ZERO
var _prensa := 0.0
var _prensa_v := 0.0
var _prensa_alvo := 0.0
var _fecha := 0.0
var _tocando := false
var _g_ant := INF
# A folga da ultima conta menos o que a cabeca pode ter andado desde entao (m,
# malha): um piso para a folga de agora.
var _folga_marg := -1.0
var _vel_aprox := 0.0
var _centro := Vector3.ZERO
var _t_impacto := -100.0
var _v_impacto := 0.0
# Quadros sem toque depois de um teleporte.
var _sem_toque := 0
# O custo no processador (us): soma e maximo, para o `--carne-log`.
var _cpu_soma := 0
var _cpu_max := 0
var _cpu_n := 0
var _onda_c := Vector3.ZERO
var _onda_t := 100.0
var _onda_a := 0.0
# Os hematomas: [centro, quanto agora, quanto vai ser].
var _hema: Array = [[Vector3.ZERO, 0.0, 0.0], [Vector3.ZERO, 0.0, 0.0]]
# A dor do golpe: forca, ha quanto tempo, e os repuxoes marcados.
var _dor := 0.0
var _t_dor := 100.0
var _repuxos: Array = []
var _dano := 0.0
var _esforco := 0.25
var _fase_resp := 0.0
var _fases := Vector3.ZERO
var _tique_em := 2.0
var _t_tique := 100.0
var _tique_amp := 0.0


## O no da carne em `cab` (a pele e `mat`), desligado ate receber um vidro.
## Null com `--rosto-duro`.
static func montar(cab: CabecaDoPadre, mat: ShaderMaterial) -> CarneDoRosto:
	if OS.get_cmdline_user_args().has("--rosto-duro"):
		return null
	var c := CarneDoRosto.new()
	c.name = "Carne"
	c._cab = cab
	c._mat = mat
	cab.add_child(c)
	return c


func _ready() -> void:
	# O Godot liga o processo de quem tem _process no ready: desligada, a
	# carne nao gasta nada.
	set_process(_ligada)


## A carne de uma `CabecaDoPadre` (null se ela nao tem).
static func de(cab: Node) -> CarneDoRosto:
	if cab == null:
		return null
	for f: Node in cab.get_children():
		if f is CarneDoRosto:
			return f as CarneDoRosto
	return null


## O vidro da cena (`CabecaDoPadre.lascas_no_vidro`): liga a carne. So o
## principal recebe.
func no_vidro(carro: Node3D, cab: CabecadaDoPadre) -> void:
	_carro = carro
	_cabecada = cab
	_ligar()


## Bancada: um vidro no mundo (um ponto dele e a normal para o lado da cara),
## sem `CabecadaDoPadre`. `n` zero tira o vidro (a carne continua ligada).
func vidro_de_teste(o: Vector3, n: Vector3) -> void:
	_teste_o = o
	_teste_n = n.normalized() if n != Vector3.ZERO else Vector3.ZERO
	_ligar()


## A cara destruida sobe de nivel (`CabecaDoPadre.por_dano`, animado de g a g+1):
## no meio do salto e a dor do golpe. Sem toque no vidro (o vidro ja nao
## existe), o hematoma nasce na testa.
func por_dano(nivel: float) -> void:
	var antes := _dano
	_dano = nivel
	if not _ligada:
		return
	if floorf(nivel - 0.5) > floorf(antes - 0.5):
		# O golpe da cena: a dor e o hematoma sao dele (um encostao no vidro
		# no tique do pescoco faz carne, nao careta).
		var recente := _t - _t_impacto < 0.3
		if recente and _v_impacto < GOLPE_MIN:
			# O toque veio num quadro so (captura lenta, quadro de 0,1 s): a
			# velocidade nao se mediu, mas o dano diz que foi golpe.
			_reforcar(GOLPE_MIN + 1.5 * floorf(nivel - 0.5))
		if recente:
			_hematoma(_onda_c, lerpf(0.7, 1.2, clampf(_v_impacto / 8.0, 0.0, 1.0)))
		else:
			_hematoma(TESTA, 0.7)
		_doer(1.0)


func _ligar() -> void:
	if _ligada:
		return
	_ligada = true
	_rng.seed = 1977
	_u.resize(REGIOES.size())
	_du.resize(REGIOES.size())
	_v_pts.resize(REGIOES.size())
	_canais.resize(12)
	_tem_ant = false
	set_process(true)


func _process(delta: float) -> void:
	if not _ligada or _mat == null or _cab == null or delta <= 0.0:
		return
	var dt := delta
	_t += dt
	var t0 := Time.get_ticks_usec()
	var xf := _cab.global_transform
	_cinematica(xf, dt)
	_molas(dt)
	_toque(xf, dt)
	_musculos(dt)
	_enviar()
	var gasto := Time.get_ticks_usec() - t0
	_cpu_soma += gasto
	_cpu_max = maxi(_cpu_max, gasto)
	_cpu_n += 1
	if _cpu_n >= 600 and _log_cpu:
		print("[carne] cpu %d us por quadro (max %d) em %d quadros" % [_cpu_soma / _cpu_n,
			_cpu_max, _cpu_n])
	if _cpu_n >= 600:
		_cpu_soma = 0
		_cpu_max = 0
		_cpu_n = 0
	if _log:
		print("[carne] t=%.3f dt=%.4f folga=%.4f prensa=%.2f toca=%s v=%.2f u_lab=%.4f canais=%s" % [
			_t, dt, _g_ant, _prensa, _tocando, _v_cab.length(), _u[3].length(), _canais])


## A aceleracao da cabeca, quadro a quadro, vira pontape nas molas: a carne
## fica para tras quando ela acelera e vai para a frente quando ela para.
func _cinematica(xf: Transform3D, dt: float) -> void:
	var s := absf(xf.basis.get_scale().x)
	var rot := xf.basis.orthonormalized()
	# No quadro em que a escala do tempo muda (o hit stop), o passo que a cena
	# deu nao e deste delta: nao se mede.
	var medir := _tem_ant and is_equal_approx(Engine.time_scale, _ts_ant) and dt > 1e-5
	if medir and (xf.origin.distance_to(_xf_ant.origin) > TELEPORTE
			or xf.origin.distance_to(_xf_ant.origin) / dt > VEL_MAX * 2.0):
		# A cena pos o corpo noutro lugar: nem pontape nas molas, nem golpe.
		medir = false
		_sem_toque = 2
		_vel_aprox = 0.0
		for i in REGIOES.size():
			_v_pts[i] = Vector3.ZERO
	if medir:
		var v := ((xf.origin - _xf_ant.origin) / dt).limit_length(VEL_MAX)
		var q := (rot * _xf_ant.basis.orthonormalized().inverse()).get_rotation_quaternion()
		var w := Vector3.ZERO
		var ang := q.get_angle()
		if ang > 1e-6:
			w = q.get_axis() * (ang / dt)
		_v_cab = v
		_w_cab = w
		var para_malha := rot.transposed()
		for i in REGIOES.size():
			var r: Array = REGIOES[i]
			var braco := xf.basis * (r[0] as Vector3)
			var vp := (v + w.cross(braco)).limit_length(VEL_MAX)
			var dv := (vp - _v_pts[i]).limit_length(VEL_MAX)
			_v_pts[i] = vp
			_du[i] -= para_malha * dv / maxf(s, 1e-3) * float(r[3])
	elif not _tem_ant:
		for i in REGIOES.size():
			_v_pts[i] = Vector3.ZERO
	_medido = medir
	_xf_ant = xf
	_ts_ant = Engine.time_scale
	_tem_ant = true


## As molas de cada regiao, pela solucao exata do oscilador amortecido: estavel
## com qualquer delta (o hit stop e o quadro de 50 ms).
func _molas(dt: float) -> void:
	for i in REGIOES.size():
		var r: Array = REGIOES[i]
		var ab := CarneDoRosto._mola(_u[i], _du[i], TAU * float(r[1]), float(r[2]), dt)
		_u[i] = ab[0]
		_du[i] = ab[1]


static func _mola(x: Vector3, v: Vector3, w: float, z: float, dt: float) -> Array:
	var wd := w * sqrt(1.0 - z * z)
	var e := exp(-z * w * dt)
	var c := cos(wd * dt)
	var sn := sin(wd * dt)
	var x2 := (x * c + (v + x * (z * w)) * (sn / wd)) * e
	var v2 := (v * c - (x * (w * w) + v * (z * w)) * (sn / wd)) * e
	return [x2, v2]


static func _mola1(x: float, v: float, alvo: float, w: float, z: float, dt: float) -> Vector2:
	var ab := CarneDoRosto._mola(Vector3(x - alvo, 0.0, 0.0), Vector3(v, 0.0, 0.0), w, z, dt)
	return Vector2((ab[0] as Vector3).x + alvo, (ab[1] as Vector3).x)


## O vidro no espaco da malha agora ((n, d), n para o lado da cara), ou zero.
func _vidro_agora(xf: Transform3D) -> Vector4:
	var o := Vector3.ZERO
	var n := Vector3.ZERO
	if _cabecada != null:
		if not DentesDoPadre.vidro_inteiro(_cabecada) or _carro == null or not is_instance_valid(_carro):
			return Vector4.ZERO
		o = _carro.global_transform * _cabecada.ponto_no_vidro()
		n = (_carro.global_basis * _cabecada.normal()).normalized()
	elif _teste_n != Vector3.ZERO:
		o = _teste_o
		n = _teste_n
	else:
		return Vector4.ZERO
	var ol := xf.affine_inverse() * o
	var nl := (xf.basis.transposed() * n).normalized()
	return Vector4(nl.x, nl.y, nl.z, nl.dot(ol))


## A menor folga (m, malha) da cara ao plano, pelas sondas; guarda em
## `_centro` o ponto da pele que encosta (a media das que estao a 4 mm dela).
func _folga(n: Vector3, d: float) -> float:
	if _folga_marg > 0.015:
		return _folga_marg
	var g := _folga_sondas(n, d)
	_folga_marg = g
	return g


func _folga_sondas(n: Vector3, d: float) -> float:
	var c := CAIXA_SONDAS.get_center()
	var h := CAIXA_SONDAS.size * 0.5
	var longe := n.dot(c) - d - (absf(n.x) * h.x + absf(n.y) * h.y + absf(n.z) * h.z)
	if longe > 0.02 or SONDAS.is_empty():
		return maxf(longe, 0.02)
	if _sondas.is_empty():
		_sondas = PackedVector3Array(SONDAS)
	var gs := PackedFloat32Array()
	gs.resize(_sondas.size())
	var gmin := INF
	for i in _sondas.size():
		var g := n.dot(_sondas[i]) - d
		gs[i] = g
		gmin = minf(gmin, g)
	# O amassado do osso (`AMASSOS`) recua a cara: so nas que estao perto.
	var gmin2 := INF
	for i in _sondas.size():
		if gs[i] < gmin + 0.015:
			var z := _cab.recuo_em(_sondas[i])
			if z > 0.0:
				gs[i] = n.dot(_sondas[i] + Vector3(0.0, 0.0, z)) - d
		gmin2 = minf(gmin2, gs[i])
	var soma := Vector3.ZERO
	var peso := 0.0
	for i in _sondas.size():
		var k := gmin2 + 0.004 - gs[i]
		if k > 0.0:
			soma += _sondas[i] * k
			peso += k
	if peso > 0.0:
		_centro = soma / peso
	return gmin2


## O vidro: o toque (a pressao salta, a onda sai, o hematoma nasce), a cara
## colada, o descolar grudado, e o vidro que some (a carne volta).
func _toque(xf: Transform3D, dt: float) -> void:
	var pl := _vidro_agora(xf)
	if pl == Vector4.ZERO:
		# Sem vidro (estourou, ou a bancada tirou): o ultimo plano fica preso a
		# cabeca e a carne volta na mola; depois ele sai.
		if _tocando:
			_tocando = false
			_soltar()
		_prensa_alvo = 0.0
		_passo_prensa(dt)
		if absf(_prensa) < 0.005 and absf(_prensa_v) < 0.05:
			_plano = Vector4.ZERO
		_g_ant = INF
		return
	# O quanto a cara pode ter chegado perto desde a ultima conta: o vidro
	# andou (d, n) ou a cabeca girou.
	if _plano != Vector4.ZERO and _folga_marg > 0.0:
		var giro := Vector3(_plano.x, _plano.y, _plano.z).distance_to(Vector3(pl.x, pl.y, pl.z))
		_folga_marg -= absf(pl.w - _plano.w) + giro * 0.25
	else:
		_folga_marg = -1.0
	_plano = pl
	var n := Vector3(pl.x, pl.y, pl.z)
	var g := _folga(n, pl.w)
	# A velocidade com que a cara chega, medida antes do toque e fora do hit
	# stop: pela folga e pela cabeca.
	if dt > 0.002 and _medido:
		# O ponto da cara que vai encostar (a testa, antes do primeiro toque):
		# a cabeca anda e gira no bote.
		var alvo := _centro if _centro != Vector3.ZERO else TESTA
		var vp := _v_cab + _w_cab.cross(xf.basis * alvo)
		var n_w := Vector3.ZERO
		if _cabecada != null and _carro != null:
			n_w = (_carro.global_basis * _cabecada.normal()).normalized()
		elif _teste_n != Vector3.ZERO:
			n_w = _teste_n
		_vel_aprox = maxf(_vel_aprox * exp(-dt / 0.1), -vp.dot(n_w))
	if _sem_toque > 0:
		_sem_toque -= 1
		_g_ant = g
		_passo_prensa(dt)
		return
	if not _tocando and g <= CONTATO:
		_tocando = true
		# Logo que liga, a cena ainda esta pondo o padre na janela (um quadro
		# longo leva o nariz ao vidro a 11 m/s): encosta, nao bate.
		_impacto(clampf(_vel_aprox, 0.0, VEL_MAX) if _t > ARRUMA else 0.0)
	elif _tocando and g > GRUDA:
		_tocando = false
		_soltar()
	_prensa_alvo = 0.0
	if _tocando:
		# Colada, empurrando: quanto mais a cara passa do vidro, mais prensa.
		_prensa_alvo = PRENSA_SEGURA + clampf(-g / 0.004, 0.0, 1.0) * 0.2
		_onda_c = _centro
		_fecha = clampf(g, 0.0, FECHA_MAX)
	_g_ant = g
	# No quadro do toque a pressao e a onda nascem inteiras: o hit stop vem
	# logo depois e congela o que este quadro mostrar.
	if _t_impacto != _t:
		_passo_prensa(dt)


func _passo_prensa(dt: float) -> void:
	var pv := CarneDoRosto._mola1(_prensa, _prensa_v, _prensa_alvo, TAU * PRENSA_HZ,
		PRENSA_AMORTECE, dt)
	_prensa = clampf(pv.x, -0.3, PRENSA_MAX)
	_prensa_v = pv.y
	_onda_t += dt
	for h: Array in _hema:
		# O rubor vem logo, o hematoma vai crescendo (segundos).
		h[1] = lerpf(float(h[1]), float(h[2]), 1.0 - exp(-dt / 1.6))


func _impacto(v: float) -> void:
	if v < ENCOSTA:
		_prensa = maxf(_prensa, PRENSA_SEGURA)
		print("[carne] encosta %.2f m/s em %s" % [v, _centro])
		return
	_t_impacto = _t
	_v_impacto = v
	var k := clampf(v / 6.0, 0.15, 1.0)
	_prensa = clampf(v * PRENSA_POR_VEL, 0.3, PRENSA_MAX)
	_prensa_v = 0.0
	_onda_c = _centro
	_onda_t = 0.0
	_onda_a = clampf(v * ONDA_POR_VEL, 0.0003, ONDA_MAX)
	_esforco = minf(1.0, _esforco + 0.3 * k)
	_vel_aprox = 0.0
	print("[carne] toque %.2f m/s: prensa %.2f, onda %.2f mm, em %s" % [v, _prensa,
		_onda_a * 1000.0, _centro])


## O golpe que o toque mediu fraco: a pressao e a onda sobem ao que `v`
## daria, sem reiniciar a onda.
func _reforcar(v: float) -> void:
	_v_impacto = v
	_prensa = maxf(_prensa, clampf(v * PRENSA_POR_VEL, 0.3, PRENSA_MAX))
	_onda_a = maxf(_onda_a, clampf(v * ONDA_POR_VEL, 0.0003, ONDA_MAX))
	for i in REGIOES.size():
		_du[i] += Vector3(_plano.x, _plano.y, _plano.z) * (-0.02 * v * float((REGIOES[i] as Array)[3]) / 0.05)
	print("[carne] golpe reforcado a %.1f m/s" % v)


## A cara sai do vidro: a carne que estava grudada solta e treme.
func _soltar() -> void:
	var n := Vector3(_plano.x, _plano.y, _plano.z)
	for i in REGIOES.size():
		var r: Array = REGIOES[i]
		var perto := 1.0 - smoothstep(0.02, 0.07, (r[0] as Vector3).distance_to(_centro))
		_du[i] += n * (0.05 * perto * clampf(_prensa + 0.3, 0.0, 1.0))
	print("[carne] descola: prensa %.2f" % _prensa)


func _hematoma(c: Vector3, quanto: float) -> void:
	var livre := -1
	for i in _hema.size():
		var h: Array = _hema[i]
		if float(h[2]) > 0.0 and (h[0] as Vector3).distance_to(c) < 0.03:
			h[2] = minf(float(h[2]) + quanto, 3.0)
			return
		if livre < 0 and float(h[2]) <= 0.0:
			livre = i
	if livre < 0:
		livre = 0 if float(_hema[0][2]) < float(_hema[1][2]) else 1
	_hema[livre] = [c, 0.0, quanto]


func _doer(forca: float) -> void:
	if _t_dor < 0.25:
		return
	_t_dor = 0.0
	_dor = forca
	_repuxos.clear()
	for i in 3:
		_repuxos.append(Vector2(_rng.randf_range(0.18, 0.95), _rng.randf_range(0.4, 0.8)))


## Um repuxao: sobe em 70 ms, some em ~0,2 s. Liso: tique que pisca le como
## defeito de imagem.
static func _pulso(x: float) -> float:
	if x < 0.0:
		return 0.0
	return smoothstep(0.0, 0.07, x) * exp(-maxf(x - 0.07, 0.0) / 0.2)


## Os canais de musculo: o que o sorriso, a fala, o golpe, a dor, a respiracao
## e o tique pedem, cada canal com o seu tempo de contrair e de soltar.
func _musculos(dt: float) -> void:
	var alvo := PackedFloat32Array()
	alvo.resize(12)
	# O sorriso torto: o esquerdo puxa mais; largo, vira rosnado e o pescoco
	# tensiona.
	var sr := sorriso
	alvo[M.ZIGO_E] = smoothstep(0.1, 1.0, sr) * 0.95
	alvo[M.ZIGO_D] = smoothstep(0.1, 1.0, sr) * 0.6
	alvo[M.ROSNADO] = smoothstep(0.55, 1.25, sr) * 0.55
	alvo[M.PLATISMA] = smoothstep(0.95, 1.3, sr) * 0.35
	# A fala: os visemas da cabeca.
	var vis: Variant = _cab.get(&"_visema")
	if vis is Dictionary:
		var dv: Dictionary = vis
		var va := float(dv.get(&"A", 0.0))
		var vo := float(dv.get(&"O", 0.0))
		var vm := float(dv.get(&"M", 0.0))
		alvo[M.ORBICULAR] += vo
		alvo[M.APERTO] += vm
		alvo[M.MENTUAL] += vm * 0.5
		alvo[M.DEPRESSOR] += va * 0.45
		alvo[M.FRONTAL] += va * 0.15
	# O golpe: a antecipacao e o bote tensionam tudo e franzem.
	if _cabecada != null:
		golpe_recua = _cabecada.recua
		golpe_bote = _cabecada.bote
	var tensao := clampf(maxf(golpe_recua, golpe_bote), 0.0, 1.0)
	alvo[M.FRONTAL] *= 1.0 - tensao
	alvo[M.CORRUGADOR] += 0.95 * tensao
	alvo[M.ROSNADO] += 0.75 * tensao
	alvo[M.PLATISMA] += 0.85 * tensao
	alvo[M.MENTUAL] += 0.35 * tensao
	alvo[M.NARINA] += 0.6 * clampf(golpe_recua, 0.0, 1.0)
	# Depois: o susto (a testa sobe) e a careta de dor, com repuxoes.
	_t_dor += dt
	var susto := _dor * smoothstep(0.0, 0.05, _t_dor) * exp(-maxf(_t_dor - 0.05, 0.0) / 0.18)
	var dor := _dor * smoothstep(0.03, 0.15, _t_dor) * exp(-maxf(_t_dor - 0.15, 0.0) / 0.9)
	var repuxo := 0.0
	for r: Vector2 in _repuxos:
		repuxo += r.y * _pulso(_t_dor - r.x) * _dor
	alvo[M.FRONTAL] += 0.8 * susto
	alvo[M.CORRUGADOR] += 0.8 * dor
	alvo[M.DEPRESSOR] += 0.7 * dor
	alvo[M.PLATISMA] += 0.7 * dor + 0.4 * repuxo
	alvo[M.ZIGO_E] += 0.45 * repuxo
	alvo[M.ZIGO_D] += 0.15 * repuxo
	alvo[M.MENTUAL] += 0.5 * dor
	alvo[M.NARINA] += 0.5 * dor
	alvo[M.ROSNADO] += 0.3 * dor
	# A respiracao: mais funda e mais rapida com o esforco, pelo nariz.
	_esforco = maxf(0.25, _esforco - dt / 20.0)
	_fase_resp = fmod(_fase_resp + dt * TAU * lerpf(0.3, 0.62, _esforco), TAU)
	var resp := sin(_fase_resp)
	alvo[M.RESPIRA] = resp * lerpf(0.3, 1.0, _esforco)
	alvo[M.NARINA] += maxf(resp, 0.0) * lerpf(0.35, 0.9, _esforco)
	# O tique: parado depois dos golpes, um repuxao de um lado de vez em quando.
	if tensao < 0.1 and dor < 0.15 and _esforco > 0.45:
		_tique_em -= dt
		if _tique_em <= 0.0:
			_t_tique = 0.0
			_tique_amp = _rng.randf_range(0.35, 0.6)
			_tique_em = _rng.randf_range(1.3, 3.0)
	_t_tique += dt
	var tique := _tique_amp * CarneDoRosto._pulso(_t_tique)
	alvo[M.ZIGO_E] += 0.55 * tique
	alvo[M.NARINA] += 0.3 * tique
	alvo[M.CORRUGADOR] += 0.2 * tique
	for i in 12:
		var a := clampf(alvo[i], -1.0, 1.2)
		var tau := MUSCULO_SOBE if absf(a) > absf(_canais[i]) else MUSCULO_DESCE
		_canais[i] = lerpf(_canais[i], a, 1.0 - exp(-dt / tau))
	# O tremor fino: tres senos de periodo proprio por eixo, nunca um degrau.
	_fases = Vector3(fmod(_fases.x + dt * TAU * 5.3, TAU), fmod(_fases.y + dt * TAU * 7.1, TAU),
		fmod(_fases.z + dt * TAU * 6.2, TAU))


func _enviar() -> void:
	var reg := PackedVector4Array()
	for i in REGIOES.size():
		var lim := float((REGIOES[i] as Array)[4])
		var u := _u[i]
		u = u / sqrt(1.0 + u.length_squared() / (lim * lim))
		reg.append(Vector4(u.x, u.y, u.z, 0.0))
	var c := _canais
	var mus := PackedVector4Array([Vector4(c[0], c[1], c[2], c[3]), Vector4(c[4], c[5], c[6], c[7]),
		Vector4(c[8], c[9], c[10], c[11])])
	var tr := lerpf(TREMOR.x, TREMOR.y, _esforco)
	var trem := Vector3(sin(_fases.x) * 0.6 + sin(_fases.y * 2.0 + 1.0) * 0.4,
		sin(_fases.y) * 0.6 + sin(_fases.z * 2.0 + 2.0) * 0.4,
		sin(_fases.z) * 0.6 + sin(_fases.x * 2.0 + 0.5) * 0.4) * tr
	var hema := PackedVector4Array()
	for h: Array in _hema:
		var hc: Vector3 = h[0]
		hema.append(Vector4(hc.x, hc.y, hc.z, float(h[1])))
	var suor := clampf((_esforco - 0.25) * 1.2, 0.0, 0.8)
	_mat.set_shader_parameter(&"carne_liga", Vector4(1.0, suor, trem.x, trem.y))
	_mat.set_shader_parameter(&"carne_reg", reg)
	_mat.set_shader_parameter(&"carne_musc", mus)
	_mat.set_shader_parameter(&"carne_vidro", _plano)
	var fecha := _fecha * clampf(_prensa / 0.35, 0.0, 1.0)
	_mat.set_shader_parameter(&"carne_prensa", Vector4(_prensa, _onda_a, trem.z, fecha))
	_mat.set_shader_parameter(&"carne_onda", Vector4(_onda_c.x, _onda_c.y, _onda_c.z, _onda_t))
	_mat.set_shader_parameter(&"carne_hema", hema)

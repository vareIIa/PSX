// Nuvem. Um quad por porcao de massa de ar, de duas maneiras.
//
// PS1 STYLE (`usa_volume = false`)
// -------------------------------
// Quad grande semitransparente, com dither ordenado. Nuvens no PS1 eram quads
// gigantes movendo devagar: sem textura procedural, a forma vem do alpha
// dithered. E este caminho e CONTRATO — nenhuma fase do MODERNO pode mexer
// nele (criterio A2).
//
// MODERNO (`usa_volume = true`) — criterio A16
// --------------------------------------------
// O mesmo quad vira a JANELA de uma esfera de ar. O pixel lanca um raio, corta
// a esfera analiticamente e caminha por dentro dela somando densidade de ruido
// 3D. Cada passo pergunta quanta nuvem existe entre ele e o sol, e escurece na
// mesma conta de Beer que a nevoa usa.
//
// E isso, e nao textura melhor, que e "volume": a nuvem fica CLARA EM CIMA e
// escura embaixo, a silhueta deixa de ser uma elipse e a massa ganha dentro. Um
// billboard pintado nao tem como ter as duas coisas — a luz dele nao depende de
// onde o sol esta.
//
// O relampago acende por DENTRO
// -----------------------------
// `psx_relampago` e global e vale de 0 a 1 durante o clarao. Ele entra como
// emissao multiplicada pela densidade, ou seja, a parte grossa da nuvem acende
// mais — que e o que se ve num temporal de verdade, onde a descarga esta dentro
// da massa e nao na frente dela.

shader_type spatial;
// `fog_disabled`: nuvem e CEU, e a nevoa de profundidade nao sabe disso. A
// camada fica a 70 m de altura e a nevoa da cidade termina em 60 m (noite de
// chuva) ou 130 m (dia nublado): com ela ligada, toda nuvem saia 100% nevoa, da
// cor exata do fundo — a camada inteira existia, custava, e nao aparecia. A
// bruma do ceu vem de `neblina_do_ceu`, logo abaixo.
//
// Nenhuma cena do PS1 STYLE instancia `Nuvens` hoje (quem cria a camada e o
// `DiretorCeu`, so no MODERNO); o caminho chapado continua aqui para quando
// alguma instanciar.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, vertex_lighting, fog_disabled;

uniform vec4 cor_nuvem : source_color = vec4(0.85, 0.87, 0.90, 1.0);
uniform float opacidade : hint_range(0.0, 1.0) = 0.55;

// ------------------------------------------------------------------ MODERNO
uniform bool usa_volume = false;
// Direcao PARA o sol (ou para a lua), em mundo. Quem escreve e o `Nuvens`, que
// pergunta ao `FogController` qual luz direcional esta em vigor.
uniform vec3 rumo_do_sol = vec3(0.35, 0.86, 0.37);
uniform vec4 cor_do_sol : source_color = vec4(1.0, 0.97, 0.92, 1.0);
// Quantos passos dentro da esfera. Seis: o ruido e de duas oitavas e a esfera
// tem poucos metros de travessia, entao passo a mais so repete a amostra
// anterior. Medido na bancada do ceu antes de virar constante.
uniform int passos : hint_range(2, 16) = 6;
// Extincao por metro de nuvem. E ela que decide se a massa e algodao ou fumaca.
uniform float extincao : hint_range(0.05, 1.5) = 0.42;
// Escala do ruido, em ciclos por metro. Baixa: nuvem tem estrutura de dezenas
// de metros, e ruido fino de perto vira granulado de televisao.
uniform float escala_ruido : hint_range(0.01, 0.5) = 0.075;
// Quanto da esfera e ar vazio. Sobe o limiar e a nuvem esfarela nas bordas.
uniform float corte : hint_range(0.0, 0.9) = 0.34;
// Deriva do ruido, em metros. O `Nuvens` soma o vento aqui, senao a forma fica
// colada ao mundo e a nuvem anda sem se transformar.
uniform vec3 deriva = vec3(0.0);
// A luz que chega POR BAIXO. De dia e o ceu devolvido pelo chao; a noite e a
// cidade: nuvem sobre cidade acesa a sodio e laranja por baixo, e e so por essa
// luz que ela aparece. Sem isto a barriga e preta, que e o erro classico.
//
// A primeira versao usava a cor AMBIENTE do preset, esverdeada na noite de
// chuva por desenho da nevoa, e a camada saiu como discos verdes no ceu.
uniform vec4 cor_do_ceu : source_color = vec4(0.42, 0.47, 0.58, 1.0);
// Quanto a massa e achatada: 1,0 e bola, 0,42 e o estratocumulo que cobre ceu
// de cidade. Com bola, a silhueta de cada quad lia como um disco.
uniform float achatamento : hint_range(0.2, 1.0) = 0.42;
// Cor e brilho do clarao dentro da massa.
//
// Cor PROPRIA, e nao a do sol. A primeira versao somava o clarao sobre
// `cor_do_sol` — e a noite quem esta no lugar do sol e a lua, com energia 0,06.
// Medido na bancada do ceu: o raio acendia a nuvem noturna em 0,009 de
// luminancia, vinte vezes menos que de dia, justamente no unico clima em que
// ha relampago. A cor e a mesma do `Relampago.COR`.
uniform vec4 cor_do_relampago : source_color = vec4(0.86, 0.91, 1.0, 1.0);
// 1,4: o clarao ilumina a massa e deixa ver o dentro dela. Em 3,2 a nuvem
// virava um disco branco chapado, que e a cara de um holofote, nao de um raio.
uniform float forca_do_relampago : hint_range(0.0, 8.0) = 1.4;

// Quanto o clima esconde o ceu, de 0 a 1. Escrito pelo `Nuvens` a partir do
// fim da nevoa do preset. E a bruma que a nevoa de profundidade fazia, so que
// medida em ALTURA no ceu e nao em metros: perto do horizonte a nuvem some no
// fundo, no alto ela aparece.
uniform float neblina_do_ceu : hint_range(0.0, 1.0) = 0.3;

global uniform float psx_relampago;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

varying vec3 centro_mundo;
varying float raio_mundo;

// Billboard. Sem isto o quad da particula fica preso ao eixo Z do mundo e some
// de perfil assim que o jogador vira a cabeca: so o que estivesse exatamente a
// frente chegava a ser desenhado. A escala da particula e preservada a mao,
// porque a matriz de billboard a descartaria.
void vertex() {
	centro_mundo = MODEL_MATRIX[3].xyz;
	// O quad tem lado 1,0 e a escala vem do material de processo, entao a
	// metade do lado e o raio da esfera que ele representa.
	raio_mundo = length(MODEL_MATRIX[0].xyz) * 0.5;

	mat4 orientada = mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * orientada * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

// Ruido de valor 3D. Hash inteiro e interpolacao suave: nao ha textura de ruido
// no projeto e carregar uma so para isto seria um asset a mais para manter.
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// Duas oitavas. A terceira custa um terco do passe e some atras do proprio
// borrao da massa — medido subindo e descendo a contagem na bancada do ceu.
float massa(vec3 p) {
	return ruido(p) * 0.65 + ruido(p * 2.17 + 19.3) * 0.35;
}

// O ponto no espaco em que o elipsoide vira esfera unitaria.
vec3 achatado(vec3 p) {
	vec3 o = (p - centro_mundo) / max(raio_mundo, 0.001);
	o.y /= achatamento;
	return o;
}

// Quanta nuvem ha neste ponto, de 0 a 1. Zero fora do elipsoide.
float densidade_em(vec3 p) {
	vec3 o = achatado(p);
	float r = length(o);
	if (r >= 1.0) {
		return 0.0;
	}
	// Borda ROIDA pelo ruido, e nao so macia: o ruido pesa desde o meio do raio,
	// entao a silhueta sai com dentes e buracos. Borda que depende so do raio e
	// um disco com o contorno borrado, e disco foi o que a rua mostrou.
	float borda = 1.0 - smoothstep(0.15, 1.0, r);
	float d = massa((p + deriva) * escala_ruido);
	// A base da nuvem e mais reta que o topo: e onde o ar condensa.
	float base = smoothstep(-0.95, -0.55, o.y);
	return max(d * borda * base - corte, 0.0) / max(1.0 - corte, 0.001);
}

// Distancia daqui ate a casca da esfera no rumo do sol. E a espessura de nuvem
// que a luz atravessa para chegar neste ponto — a conta que faz o topo ficar
// claro e a barriga escura sem um segundo raio de marcha.
float caminho_ate_o_sol(vec3 p) {
	vec3 escala = vec3(1.0, 1.0 / achatamento, 1.0) / max(raio_mundo, 0.001);
	vec3 oc = (p - centro_mundo) * escala;
	vec3 rs = rumo_do_sol * escala;
	float a = dot(rs, rs);
	float b = dot(oc, rs);
	float c = dot(oc, oc) - 1.0;
	float disc = b * b - a * c;
	if (disc <= 0.0) {
		return 0.0;
	}
	return max((-b + sqrt(disc)) / a, 0.0);
}

// A esfera de ar do MODERNO. Devolve a cor em `cor` e a cobertura no retorno;
// cobertura zero quer dizer "descarte".
//
// Fora do `fragment()` porque o Godot proibe `return` dentro dele, e o raio que
// nao corta a esfera precisa sair cedo.
float esfera_de_ar(vec3 mundo, vec3 olho, vec2 pixel, float tempo, out vec3 cor) {
	cor = vec3(0.0);
	vec3 rd = normalize(mundo - olho);

	// Corte analitico raio/elipsoide: no espaco achatado ele e uma esfera
	// unitaria. O quad e so a janela; quem tem forma e o volume atras dele.
	vec3 escala = vec3(1.0, 1.0 / achatamento, 1.0) / max(raio_mundo, 0.001);
	vec3 oc = (olho - centro_mundo) * escala;
	vec3 rs = rd * escala;
	float a = dot(rs, rs);
	float b = dot(oc, rs);
	float c = dot(oc, oc) - 1.0;
	float disc = b * b - a * c;
	if (disc <= 0.0) {
		return 0.0;
	}
	float raiz = sqrt(disc);
	float t0 = max((-b - raiz) / a, 0.0);
	float t1 = (-b + raiz) / a;
	if (t1 <= t0) {
		return 0.0;
	}

	float passo = (t1 - t0) / float(passos);
	// Desloca a primeira amostra por pixel. Sem isto os seis passos desenham
	// seis cascas concentricas visiveis — o artefato de banda que todo raymarch
	// curto tem.
	//
	// Ruido de gradiente intercalado que ANDA a cada quadro, e nao o Bayer
	// parado do PS1: o Bayer 4x4 fixo virou listras verticais na foto da
	// bancada, porque o TAA nao funde o que nao muda. Ruido que anda ele funde.
	float quadro = mod(floor(tempo * 60.0), 64.0);
	vec2 q = pixel + quadro * 5.588238;
	float salto = fract(52.9829189 * fract(dot(q, vec2(0.06711056, 0.00583715))));

	vec3 luz_sol = cor_do_sol.rgb;
	vec3 luz_ceu = cor_do_ceu.rgb;
	float transmissao = 1.0;

	for (int i = 0; i < passos; i++) {
		float t = t0 + (float(i) + salto) * passo;
		vec3 p = olho + rd * t;
		float d = densidade_em(p);
		if (d <= 0.001) {
			continue;
		}
		float dens = d * extincao * passo;
		// Beer: quanto de sol sobrou depois de atravessar a nuvem ate aqui.
		//
		// O caminho e medido ate a CASCA da esfera, mas boa parte dela e ar
		// vazio (o `corte` esfarela a massa). O 0,25 e a densidade media que a
		// luz encontra no caminho; com o 0,55 da primeira versao, o topo de uma
		// nuvem de dia saia cinza como a barriga.
		float sombra = exp(-caminho_ate_o_sol(p) * extincao * 0.25);
		// O ceu entra por baixo e nao depende do sol; e ele que impede a
		// barriga de virar carvao.
		vec3 luz = luz_sol * sombra + luz_ceu * 0.45;
		// O clarao nasce DENTRO: multiplicado pela densidade, a parte grossa
		// acende mais que a franja.
		luz += cor_do_relampago.rgb * psx_relampago * forca_do_relampago * d;
		cor += transmissao * dens * luz;
		transmissao *= exp(-dens);
		if (transmissao < 0.01) {
			break;
		}
	}
	return 1.0 - transmissao;
}

void fragment() {
	if (usa_volume) {
		// -------- MODERNO: a esfera de ar. --------
		vec3 mundo = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 olho = INV_VIEW_MATRIX[3].xyz;
		vec3 acumulado;
		float cobertura = esfera_de_ar(mundo, olho, FRAGCOORD.xy, TIME, acumulado);
		vec3 rumo = normalize(mundo - olho);
		// So o fim do ceu some: abaixo de uns onze graus a nuvem esta atras da
		// cidade que a nevoa ja engoliu. Acima disso quem manda e o clima.
		float perto_do_horizonte = 1.0 - smoothstep(0.0, 0.2, rumo.y);
		float bruma = mix(neblina_do_ceu, 1.0, perto_do_horizonte);
		float alfa = clamp(cobertura * opacidade * COLOR.a * (1.0 - bruma), 0.0, 1.0);
		if (alfa <= 0.003) {
			discard;
		}
		// A cor acumulada ja vem multiplicada pela cobertura; dividir pela
		// cobertura devolve a cor "pura" que o blend_mix espera.
		ALBEDO = (acumulado / max(cobertura, 0.001)) * cor_nuvem.rgb * COLOR.rgb;
		ALPHA = alfa;
	} else {
		// -------- PS1 STYLE: o quad chapado de sempre, intocado. --------
		vec2 centro = UV - vec2(0.5);
		centro.x *= 0.55;  // alarga horizontalmente
		float dist = length(centro) * 2.0;
		float forma = 1.0 - smoothstep(0.35, 1.0, dist);
		float densidade = 0.6 + UV.x * 0.25 + UV.y * 0.15;
		float a = forma * densidade * opacidade * COLOR.a;
		int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
		a += (BAYER[idx] / 16.0 - 0.5) * 0.15;
		ALBEDO = cor_nuvem.rgb * COLOR.rgb;
		ALPHA = clamp(a, 0.0, 1.0);
	}
}

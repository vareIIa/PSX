## A cabeca do padre principal debaixo do capuz: a criatura das referencias em
## `INTRO-PADRE/referencia/padre_principal_*` — calvo, pele branca craquelada
## com veias mortas, olhos redondos arregalados em olheira funda, boca aberta
## escura e torta com dentes.
##
## Por que existe
## --------------
## Debaixo do capuz o padre era um buraco preto com dois pontos vermelhos e um
## sorriso desenhado num quad. De longe, no farol, servia; na janela, a meio
## metro da lente, lia como emoji. O medo que a cena pede e o de uma cara: uma
## cara quase de gente, com o que ha de errado nela a vista.
##
## Como e feita
## ------------
## A forma vem de `tools/gerar_padre.py` (campo de distancia esculpido e
## marching cubes, em `assets/monstros/padre/cabeca.glb`): a pele e a boca
## (dentes e gengiva). O que e de LUGAR — olheira, labio, goela, oclusao, o peso
## da queixada, onde a veia aparece — vem na malha, por vertice. O que e de
## DETALHE — a racha, a veia, a mancha, o poro — vem de duas texturas 4K
## tileaveis (`pele_mapa`, `pele_n`) amostradas em triplanar no espaco do
## objeto, a 0,06 mm por texel: a meio metro, em 4K, a racha continua nitida.
##
## A boca abre girando a queixada no shader (pele e dentes pela mesma conta,
## `QUEIXADA`), em volta da articulacao na frente da orelha: o que `sorriso` do
## capuz pedia de um quad agora e osso.
##
## Os olhos sao dois globos de verdade, sem palpebra. De longe, onde um olho de
## 2,5 cm vira menos de um pixel na nevoa, um ponto vermelho em billboard
## acende no lugar da pupila (`OLHO_LONGE`) e some quando a lente chega perto:
## o farol continua vendo os dois pontos, a janela ve o olho.
class_name CabecaDoPadre
extends Node3D

const CENA := "res://assets/monstros/padre/cabeca.glb"
const MAPA := "res://assets/monstros/padre/pele_mapa.png"
const MAPA_N := "res://assets/monstros/padre/pele_n.png"
## O sangue da testa aberta (`por_sangue`) e a cara destruida (`por_dano`), de
## `tools/gerar_sangue_vidro.py`.
const SANGUE := "res://assets/monstros/sangue/rosto_sangue.png"
const GORE := "res://assets/monstros/sangue/rosto_gore.png"
## Os amassados das cabecadas, na malha da cabeca (rosto para -Z, +z entra no
## cranio): [centro, raio, fundo (m) depois de cada golpe 0..3].
##   o nariz cede no primeiro e afunda no cranio no segundo
##   a testa (onde bate) vira cratera
##   o meio da cara cede inteiro no terceiro
##   a orbita esquerda (o olho sai) e a ponte ate o maxilar
const AMASSOS := [
	[Vector3(0.0, -0.022, -0.106), 0.030, [0.0, 0.009, 0.028, 0.042]],
	[Vector3(0.0, 0.050, -0.088), 0.040, [0.0, 0.003, 0.010, 0.024]],
	[Vector3(0.0, -0.006, -0.100), 0.056, [0.0, 0.0, 0.004, 0.019]],
	[Vector3(-0.031, 0.004, -0.070), 0.026, [0.0, 0.0, 0.0, 0.013]],
	[Vector3(0.015, -0.050, -0.090), 0.030, [0.0, 0.0, 0.003, 0.015]],
]
## Medidas da malha (as de `tools/gerar_padre.py`, pessoa de 1,72 m): o olho, o
## raio do globo, o pivo da queixada. A malha tem a origem no centro da caixa de
## cabeca do `Corpo` e o rosto para -Z.
const OLHO := Vector3(0.031, 0.004, -0.0590)
const OLHO_R := 0.0125
const PIVO := Vector3(0.0, -0.018, 0.030)
## A altura da caixa de cabeca do `Corpo` na pessoa de referencia: a razao da
## `tamanho_do_rosto` por ela e a escala da cabeca.
const CAIXA_ALTURA := 0.245
## Quanto a queixada gira com a boca aberta de todo (rad).
const GIRO_QUEIXADA := 0.55
## O olho vesgo: cada um para um lado, um fio (rad).
const OLHO_DIVERGE := 0.05
## O olho e o do HumanShaders (MatMADNESS, MIT: `res://HumanShaders/`): esclera,
## iris com parallax e a cornea molhada. Ele espera UV de frente (o centro da
## UV e a pupila, a borda e o fundo do olho): `_globo` monta a esfera assim.
const OLHO_SHADER_HS := "res://HumanShaders/eye_shader.gdshader"
const OLHO_TEX := "res://HumanShaders/Resources/Eye/"
## O tamanho da iris no globo (maior, iris menor) e o tom dela: a do padre e
## clara e apagada.
const OLHO_IRIS_ESCALA := 3.5
const OLHO_IRIS_TOM := Color(0.95, 0.95, 0.9)
## A esclera do olho arrancado: tingida de sangue.
const OLHO_ARRANCADO_TOM := Color(0.86, 0.62, 0.58)
## O ponto de longe: tamanho do quad e de que distancia comeca a aparecer.
const LONGE_QUAD := 0.030
const LONGE_DE := 2.6
const LONGE_ATE := 6.0

## A rotacao da queixada, igual para a pele e para os dentes.
const QUEIXADA := """
uniform float abre = 0.0;
uniform vec3 pivo = vec3(0.0, -0.018, 0.030);
uniform float giro_max = 0.34;

vec3 girar_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, c * v.y - s * v.z, s * v.y + c * v.z);
}
"""

## Os amassados das cabecadas (`por_dano`), iguais para a pele e para os
## dentes: o osso cedendo para dentro do cranio (+z) em volta de cada centro.
const AMASSO := """
uniform vec4 amassos[6];
uniform float fundos[6];
uniform int n_amassos = 0;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// Osso partido nao cede liso: o amassado anda em placas de ~6 mm, cada uma um
// pouco mais ou menos funda, e o entorno e puxado para o buraco.
vec3 amassar(vec3 v, out float esmaga) {
	vec3 d = vec3(0.0);
	esmaga = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= n_amassos) {
			break;
		}
		float f = fundos[i];
		vec4 a = amassos[i];
		float k = 1.0 - smoothstep(0.0, a.w, length(v - a.xyz));
		if (f <= 0.0 || k <= 0.0) {
			continue;
		}
		k = k * k * (3.0 - 2.0 * k);
		k *= 0.78 + 0.44 * h3(floor(v * 165.0));
		d.z += f * k;
		d.xy -= (v.xy - a.xy) * k * f * 3.0;
		esmaga = max(esmaga, k * clamp(f / 0.02, 0.0, 1.0));
	}
	return v + d;
}
"""

const PELE_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

#QUEIXADA

uniform sampler2D mapa : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mapa_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Metros por repeticao da textura (o tile de 4096 do gerador).
uniform float tile = 0.15;
uniform float relevo = 1.6;
uniform vec3 pele : source_color = vec3(0.75, 0.74, 0.71);
uniform vec3 mancha_quente : source_color = vec3(0.64, 0.53, 0.49);
uniform vec3 mancha_fria : source_color = vec3(0.58, 0.63, 0.62);
uniform vec3 veia : source_color = vec3(0.33, 0.32, 0.46);
uniform vec3 racha : source_color = vec3(0.13, 0.11, 0.10);
uniform vec3 olheira_fundo : source_color = vec3(0.035, 0.018, 0.016);
uniform vec3 olheira_borda : source_color = vec3(0.30, 0.17, 0.16);
uniform vec3 labio : source_color = vec3(0.10, 0.045, 0.042);
uniform vec3 goela : source_color = vec3(0.035, 0.010, 0.010);
// A testa aberta nas cabecadas (`por_sangue`): o mapa de
// `tools/gerar_sangue_vidro.py` projetado de frente (x -0,09..0,09 m, y 0,11..
// -0,25 m), R espessura, G tempo de chegada, B o rasgo, A cobertura. `sangue`
// e ate onde o escorrido ja desceu (0 nada).
uniform sampler2D sangue_mapa : filter_linear_mipmap_anisotropic, repeat_disable;
uniform float sangue = 0.0;
uniform vec3 sangue_cor : source_color = vec3(0.24, 0.012, 0.010);
// A cara sendo destruida (`por_dano`): 0 inteira, 1, 2, 3 depois de cada
// golpe. O mapa (mesma projecao do sangue): R corte de vidro em V, G em que
// golpe ele abre, B onde a pele arranca, A onde o osso aparece.
uniform sampler2D gore_mapa : filter_linear_mipmap_anisotropic, repeat_disable;
uniform float dano = 0.0;
// O olho esquerdo saiu (0 a 1): a orbita vira buraco.
uniform float orbita_vazia = 0.0;
uniform vec3 orbita_c = vec3(-0.031, 0.004, -0.059);
uniform vec3 carne : source_color = vec3(0.66, 0.11, 0.085);
uniform vec3 carne_funda : source_color = vec3(0.34, 0.035, 0.03);
uniform vec3 gordura : source_color = vec3(0.90, 0.76, 0.52);
uniform vec3 osso_cor : source_color = vec3(0.80, 0.72, 0.60);
uniform vec3 coagulo : source_color = vec3(0.17, 0.012, 0.01);

#AMASSO

varying vec3 p_obj;
varying vec3 n_obj;
varying vec4 marca;
varying vec2 extra;
varying float esmago;

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
	marca = COLOR;
	extra = UV;
	float a = -abre * giro_max * UV.x;
	VERTEX = pivo + girar_x(VERTEX - pivo, a);
	NORMAL = girar_x(NORMAL, a);
	float e;
	VERTEX = amassar(VERTEX, e);
	esmago = e;
}

vec3 tn(vec2 uv, float k) {
	vec2 xy = texture(mapa_n, uv).xy * 2.0 - 1.0;
	xy *= relevo * k;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}

// Ruido de valor 3D no espaco do objeto: a carne tem desenho proprio. Antes a
// ferida tirava o desenho da racha da pele, e o musculo saia riscado de raio.
float vruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	return vruido(p) * 0.55 + vruido(p * 2.03 + 17.1) * 0.3 + vruido(p * 4.1 + 3.7) * 0.15;
}

// A fibra do musculo debaixo da pele, na frente da cara (x, y do objeto): o
// frontal sobe na testa, o orbicular roda em volta do olho, o zigomatico desce
// do pomulo para a boca.
vec2 fibra_dir(vec2 p) {
	float sx = p.x < 0.0 ? -1.0 : 1.0;
	vec2 d = normalize(vec2(sx * 0.7, 1.0));
	vec2 ro = p - vec2(sx * 0.031, 0.004);
	float lo = length(ro);
	vec2 orb = vec2(-ro.y, ro.x) / max(lo, 1e-4);
	d = mix(d, orb, 1.0 - smoothstep(0.014, 0.026, lo));
	d = mix(d, vec2(0.0, 1.0), smoothstep(0.022, 0.04, p.y));
	return normalize(d);
}

// A racha do osso partido: a distancia a borda da celula (Worley F2 - F1) em
// placas de ~4 mm. A linha tem ~0,7 mm: mais fina, a 0,4 m em 4K ela
// serrilhava em pontilhado de costura.
float racha_do_osso(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 c = vec3(float(x), float(y), float(z));
				vec3 o = vec3(h3(i + c), h3(i + c + 31.7), h3(i + c + 71.3));
				float d = length(c + o - f);
				if (d < f1) {
					f2 = f1;
					f1 = d;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return 1.0 - smoothstep(0.0, 0.17, f2 - f1);
}

void fragment() {
	vec3 n = normalize(n_obj);
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 sn = sign(n);
	vec2 ux = vec2(p_obj.z * -sn.x, p_obj.y) / tile;
	vec2 uy = vec2(p_obj.x * sn.y, p_obj.z) / tile;
	vec2 uz = vec2(p_obj.x * sn.z, p_obj.y) / tile;
	vec4 m = texture(mapa, ux) * bw.x + texture(mapa, uy) * bw.y + texture(mapa, uz) * bw.z;

	// Normal em triplanar (whiteout): cada plano soma a sua inclinacao a
	// normal da malha.
	// Dentro da boca e na borda do olho nao ha racha: e mucosa.
	float liso = 1.0 - max(marca.a, smoothstep(0.7, 1.0, marca.g));
	vec3 tx = tn(ux, liso);
	vec3 ty = tn(uy, liso);
	vec3 tz = tn(uz, liso);
	tx.x *= -sn.x;
	ty.x *= sn.y;
	tz.x *= sn.z;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 np = normalize(tx.zyx * bw.x + ty.xzy * bw.y + tz.xyz * bw.z);
	// Da normal perturbada a de repouso ha um giro; o mesmo giro sobre a normal
	// que o vertice girou (a queixada).
	float a = -abre * giro_max * extra.x;
	np = girar_x(np, a);
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(np, 0.0))).xyz);

	float altura = m.r;
	float sulco = smoothstep(0.50, 0.22, altura);
	float borda = smoothstep(0.62, 0.80, altura);
	float olh = marca.r;
	float lab = marca.g;
	float ao = marca.b;
	float goe = marca.a;

	vec3 cor = pele;
	cor = mix(cor, mancha_quente, smoothstep(0.50, 0.85, m.b) * 0.55);
	cor = mix(cor, mancha_fria, smoothstep(0.45, 0.15, m.b) * 0.45);
	// A veia morta: por baixo da pele, some onde a racha abre.
	cor = mix(cor, veia, m.g * extra.y * 0.8 * (1.0 - sulco));
	// A placa que descasca pega um tom mais claro na borda; o sulco, a sujeira.
	cor *= 1.0 + borda * 0.06;
	cor = mix(cor, racha, sulco * 0.88);
	// Olheira: o fundo quase preto junto do olho, o aro avermelhado em volta.
	cor = mix(cor, olheira_borda, smoothstep(0.02, 0.4, olh) * 0.75);
	cor = mix(cor, olheira_fundo, smoothstep(0.30, 0.85, olh));
	cor = mix(cor, labio, lab * 0.92);
	cor = mix(cor, goela, goe);
	// Sujeira nas dobras: onde a luz do ceu nao chega, tambem nao chega a agua.
	cor = mix(cor, racha, (1.0 - ao) * 0.45 + smoothstep(0.3, 0.9, m.b) * 0.12);
	// O sangue: so na frente (a projecao estica nos lados), e entrando nos
	// sulcos da racha antes de cobrir a placa.
	// Tudo que e da cara vem pela mesma projecao de frente; fora dela, nada.
	vec2 fuv = vec2((p_obj.x + 0.09) / 0.18, (0.11 - p_obj.y) / 0.36);
	float na_cara = step(0.0, fuv.x) * step(fuv.x, 1.0) * step(0.0, fuv.y) * step(fuv.y, 1.0);
	float frente = smoothstep(0.05, 0.4, -n.z) * na_cara;
	// O amassado sozinho ja escurece: sangue pisado debaixo da pele.
	cor = mix(cor, cor * vec3(0.66, 0.30, 0.28), clamp(esmago * 1.3, 0.0, 0.85));
	// `alto` e o relevo por cima da malha (m), que vira normal pelas derivadas
	// de tela: o sangue tem volume, a ferida tem fundo e beira.
	float alto = 0.0;
	// O desenho da carne: manchas de ~6 mm e grao de ~1,5 mm.
	float n1 = fbm3(p_obj * 170.0);
	float n2 = vruido(p_obj * 650.0);
	float sk = 0.0;
	float sk_grosso = 0.0;
	if (sangue > 0.0) {
		vec4 s = texture(sangue_mapa, clamp(fuv, 0.0, 1.0));
		float chega = smoothstep(sangue + 0.012, sangue - 0.012, s.g);
		sk = s.a * chega * smoothstep(0.1, 0.45, -n.z) * na_cara;
		sk = clamp(sk * (1.0 + sulco * 0.6), 0.0, 1.0);
		sk_grosso = sk * s.r;
		// Fino, o sangue e vermelho vivo; grosso, e quase preto e coagula na
		// borda do filete.
		vec3 filme = mix(sangue_cor * 1.35, coagulo, smoothstep(0.25, 0.9, s.r));
		cor = mix(cor, filme, sk);
		// O filete e um cordao: sobe da pele e engorda onde junta.
		alto += sk * (0.00012 + s.r * 0.00055);
		// O rasgo da testa: carne aberta e funda.
		float rt = s.b * smoothstep(0.0, 0.05, sangue) * na_cara;
		cor = mix(cor, carne_funda * 0.55, rt);
		alto -= rt * 0.0014;
	}
	// A ferida: a pele arrancada vira para fora (derme clara e inchada na
	// beira), por dentro a gordura amarela e o musculo em feixes na direcao da
	// fibra, sangue vivo empocado e coagulo; o osso partido em placas no fundo
	// da cratera; os talhos de vidro em V.
	float gore = 0.0;
	float rug_g = 0.5;
	float spec_g = 0.22;
	float orb_k = 0.0;
	if (dano > 0.0) {
		vec4 g = texture(gore_mapa, clamp(fuv, 0.0, 1.0));
		float lim_r = mix(1.12, 0.30, clamp(dano / 3.0, 0.0, 1.0));
		float r = g.b + esmago * 0.45 + (n1 - 0.5) * 0.30 + (n2 - 0.5) * 0.05;
		float rasgo = smoothstep(lim_r, lim_r + 0.02, r) * frente;
		float labio_f = smoothstep(lim_r - 0.03, lim_r, r) * (1.0 - rasgo) * frente;
		float fundo = clamp((r - lim_r) / 0.25, 0.0, 1.0);
		float gord = rasgo * (1.0 - smoothstep(0.0, 0.16, fundo + (n2 - 0.5) * 0.12))
			* (0.35 + 0.65 * smoothstep(0.35, 0.65, n1));
		vec2 fd = fibra_dir(p_obj.xy);
		float ao_longo = dot(p_obj.xy, fd);
		float atraves = dot(p_obj.xy, vec2(-fd.y, fd.x));
		float feixe = vruido(vec3(atraves * 1100.0, ao_longo * 80.0, p_obj.z * 400.0));
		float fio = vruido(vec3(atraves * 3200.0, ao_longo * 180.0, p_obj.z * 900.0));
		float estria = feixe * 0.65 + fio * 0.35;
		// So o feixe (~1 mm) vira relevo: o fio de 0,3 mm e 2 px a 0,4 m em 4K,
		// e como normal ele serrilhava em faisca dourada.
		vec3 musculo = mix(carne_funda, carne, smoothstep(0.15, 0.85, estria) * 0.75 + n1 * 0.25);
		musculo = mix(musculo, carne_funda * 0.8, clamp(esmago * 0.6, 0.0, 0.6));
		float poca = smoothstep(0.58, 0.74, fbm3(p_obj * 90.0 + 5.0) + fundo * 0.12) * rasgo;
		float coag = smoothstep(0.64, 0.8, n1 + esmago * 0.15) * rasgo * (1.0 - poca);
		musculo = mix(musculo, sangue_cor * 1.2, poca * 0.85);
		musculo = mix(musculo, coagulo, coag * 0.85);
		float lim_o = mix(1.4, 0.42, clamp((dano - 1.0) / 2.0, 0.0, 1.0));
		float ro = g.a + esmago * 0.25 + (n1 - 0.5) * 0.45 + (n2 - 0.5) * 0.1;
		float osso_k = smoothstep(lim_o, lim_o + 0.04, ro) * rasgo;
		float periosteo = smoothstep(lim_o - 0.1, lim_o, ro) * (1.0 - osso_k) * rasgo;
		float racha_o = 0.0;
		if (osso_k > 0.0) {
			// Nem toda placa se solta: a racha so onde o osso partiu.
			racha_o = racha_do_osso(p_obj * 240.0) * smoothstep(0.4, 0.62, vruido(p_obj * 120.0 + 9.0));
		}
		vec3 osso_v = mix(osso_cor, osso_cor * vec3(0.8, 0.66, 0.56), n2);
		// O osso nunca aparece limpo: o sangue fica na porosidade dele.
		osso_v = mix(osso_v, sangue_cor * 1.3, smoothstep(0.35, 0.75, n1) * 0.7);
		osso_v = mix(osso_v, osso_v * vec3(0.72, 0.5, 0.45), smoothstep(0.3, 0.7, n2) * 0.5);
		osso_v = mix(osso_v, coagulo * 0.6, racha_o * 0.9);
		float abre_corte = step(g.g, dano / 3.0 + 0.01);
		float talho = smoothstep(0.55, 0.78, g.r) * abre_corte * frente;
		float beira = smoothstep(0.04, 0.55, g.r) * (1.0 - talho) * abre_corte * frente;
		vec3 labio_cor = mix(vec3(0.70, 0.48, 0.44), vec3(0.45, 0.10, 0.08),
			smoothstep(0.4, 1.0, labio_f));
		cor = mix(cor, labio_cor, labio_f * 0.9);
		cor = mix(cor, musculo, rasgo);
		cor = mix(cor, mix(gordura, gordura * vec3(0.92, 0.72, 0.58), n2), gord * 0.85);
		cor = mix(cor, carne_funda * 0.7, periosteo);
		cor = mix(cor, osso_v, osso_k);
		cor = mix(cor, vec3(0.42, 0.08, 0.07), beira * 0.6);
		cor = mix(cor, carne_funda * 0.5, talho);
		gore = max(max(rasgo, talho), labio_f * 0.6);
		alto += labio_f * 0.0003 + periosteo * 0.0002
			+ rasgo * (-0.0012 + 0.0004 * n1 + 0.00012 * feixe + gord * 0.0004
				+ coag * 0.0004 - poca * 0.0002)
			- osso_k * (0.0012 + racha_o * 0.0004)
			- g.r * abre_corte * frente * 0.0022 + beira * 0.00035;
		rug_g = mix(mix(0.5, 0.58, gord), 0.32, poca);
		rug_g = mix(rug_g, 0.42, coag);
		rug_g = mix(rug_g, 0.74, osso_k);
		rug_g = mix(rug_g, 0.56, labio_f * (1.0 - rasgo));
		spec_g = mix(mix(0.22, 0.34, poca), 0.15, osso_k);
	}
	// A orbita vazia: o olho saiu, fica o buraco fundo, musculo rasgado e
	// sangue empocado.
	if (orbita_vazia > 0.0) {
		float d_orb = length((p_obj - orbita_c) * vec3(1.0, 1.15, 0.6));
		float cav = (1.0 - smoothstep(0.009, 0.017, d_orb)) * orbita_vazia;
		vec3 fundo_orb = mix(coagulo, carne_funda, n1);
		fundo_orb = mix(fundo_orb, carne * 0.85, smoothstep(0.006, 0.015, d_orb) * n2);
		cor = mix(cor, fundo_orb, cav);
		gore = max(gore, cav);
		// O buraco ja e fundo na malha: relevo por cima inclinava a normal
		// para o fogo, e a orbita virava uma tigela rosa brilhante. La dentro
		// a luz mal chega.
		rug_g = mix(rug_g, 0.55, cav);
		spec_g = mix(spec_g, 0.08, cav);
		orb_k = cav;
	}
	ALBEDO = cor * mix(mix(0.30, 0.65, gore), 1.0, ao);

	// Na ferida a racha da pele nao existe mais: a normal volta a da malha.
	vec3 n_malha = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(girar_x(n, a), 0.0))).xyz);
	NORMAL = normalize(mix(NORMAL, n_malha, gore));
	// O osso amassado quebra a superficie em placas: ali a normal e a da propria
	// face deformada. E o relevo da ferida por cima (Mikkelsen, derivadas).
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec3 nf = normalize(cross(dpx, dpy));
	if (dot(nf, VIEW) < 0.0) {
		nf = -nf;
	}
	// So debaixo da pele: dentro da ferida a placa lisa espelhava o ceu em
	// cinza-azul.
	NORMAL = normalize(mix(NORMAL, nf, smoothstep(0.15, 0.6, esmago) * 0.45 * (1.0 - gore)));
	vec3 r1 = cross(dpy, NORMAL);
	vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dFdx(alto) * r1 + dFdy(alto) * r2);
	vec3 nb = abs(det) * NORMAL - grad;
	if (dot(nb, nb) > 1e-30) {
		NORMAL = normalize(nb);
	}

	float molhado = max(smoothstep(0.6, 0.95, olh), max(lab, goe));
	ROUGHNESS = mix(mix(mix(0.52, 0.86, sulco), 0.22, molhado), 0.5, goe);
	// O sangue escorrido brilha, mas largo: com rugosidade baixa ele espelhava
	// o ceu da noite e ficava azul-preto.
	ROUGHNESS = mix(ROUGHNESS, mix(0.36, 0.3, sk_grosso), sk);
	// Carne crua e fosca e umida: brilho largo e fraco, sem verniz. Com
	// clearcoat e rugosidade baixa a ferida espelhava o ceu (preta-azulada) e
	// a fibra virava purpurina.
	ROUGHNESS = mix(ROUGHNESS, rug_g, gore);
	// Dentro da boca o brilho de mucosa virava vinil preto: a goela so brilha
	// de leve.
	SPECULAR = mix(mix(0.45, 0.25, sulco) * ao * (1.0 - goe * 0.7), 0.32, sk);
	SPECULAR = mix(SPECULAR, spec_g, gore);
	SSS_STRENGTH = 0.22 * (1.0 - sulco) * (1.0 - goe) + gore * 0.45;
	AO = ao * (1.0 - orb_k * 0.75);
	AO_LIGHT_AFFECT = mix(0.4, 0.85, orb_k);
}
"""

const BOCA_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

#QUEIXADA

uniform vec3 dente : source_color = vec3(0.80, 0.74, 0.58);
uniform vec3 dente_podre : source_color = vec3(0.34, 0.24, 0.14);
uniform vec3 gengiva : source_color = vec3(0.32, 0.09, 0.09);
uniform float dano = 0.0;

#AMASSO

varying vec4 marca;
varying float esmago;

void vertex() {
	marca = COLOR;
	float a = -abre * giro_max * UV.x;
	VERTEX = pivo + girar_x(VERTEX - pivo, a);
	NORMAL = girar_x(NORMAL, a);
	float e;
	VERTEX = amassar(VERTEX, e);
	esmago = e;
}

void fragment() {
	float g = marca.r;
	float podre = marca.g;
	float ao = marca.b;
	vec3 cor = mix(dente, dente_podre, smoothstep(0.35, 1.0, podre));
	cor = mix(cor, gengiva, g);
	// Os dentes no sangue da boca, mais a cada golpe; os do amassado, quebrados
	// para dentro e escuros.
	cor = mix(cor, vec3(0.26, 0.025, 0.02), clamp(dano / 3.0, 0.0, 1.0) * (0.45 + 0.4 * podre));
	cor = mix(cor, vec3(0.06, 0.005, 0.005), clamp(esmago * 1.5, 0.0, 1.0));
	ALBEDO = cor * mix(0.12, 1.0, ao * ao);
	ROUGHNESS = mix(mix(0.38, 0.20, g), 0.1, clamp(dano / 3.0, 0.0, 1.0));
	SPECULAR = 0.5 * ao;
	AO = ao;
}
"""

const OLHO_LONGE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform float forca = 1.0;
uniform float perto = 3.5;
uniform float escala = 1.0;
uniform float de = 2.6;
uniform float ate = 6.0;
varying float some;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float d = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
	some = smoothstep(de, ate, d);
	VERTEX *= max(1.0, d / perto) * escala * some;
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	if (r > 0.34 || some < 0.01) {
		discard;
	}
	float nucleo = smoothstep(0.34, 0.0, r);
	vec3 cor = mix(vec3(1.0, 0.05, 0.012), vec3(1.0, 0.5, 0.3), nucleo * nucleo);
	ALBEDO = cor * (0.6 + nucleo * 3.4) * forca;
}
"""

static var _malha_pele: Mesh
static var _malha_boca: Mesh
static var _malha_globo: ArrayMesh
static var _shaders: Dictionary = {}

var _mat_pele: ShaderMaterial
var _mat_boca: ShaderMaterial
var _mat_longe: ShaderMaterial
var _mat_olho_e: ShaderMaterial
var _olhos: Array[MeshInstance3D] = []
var _dano: float = 0.0


## Poe a cabeca em `c`, debaixo de `capuz`. Null se a malha nao existe (rode
## `python tools/gerar_padre.py` e `--import`).
static func vestir(c: Corpo, _capuz: CapuzMacabro) -> CabecaDoPadre:
	# A/B de desempenho: `--sem-cabeca-padre` volta ao buraco do capuz.
	if OS.get_cmdline_user_args().has("--sem-cabeca-padre"):
		return null
	if not _carregar():
		push_warning("CabecaDoPadre: %s nao carrega" % CENA)
		return null
	var no := MonstroDaEstrada.no_da_cabeca(c, "CabecaDoPadre")
	if no == null:
		return null
	var cab := CabecaDoPadre.new()
	cab.name = "Cabeca"
	no.add_child(cab)
	cab.position = Vector3(0.0, c.plano_do_rosto().origin.y, 0.0)
	cab.scale = Vector3.ONE * (c.tamanho_do_rosto().y / CAIXA_ALTURA)
	cab._montar()
	return cab


## O cranio (sem o pescoco) no espaco do pai, que e o do osso da cabeca: e
## nele que o capuz se ajusta (`CapuzMacabro.vestir_pano`). Medido na malha de
## tools/gerar_padre.py.
func elipsoide() -> AABB:
	var e := Vector3(0.082, 0.116, 0.112) * scale.x
	var c := position + Vector3(0.0, 0.0, -0.003) * scale.x
	return AABB(c - e, e * 2.0)


## 0 a boca no repouso (ja aberta, torta), 1 a queixada caida de todo.
func por_sorriso(v: float) -> void:
	for m: ShaderMaterial in [_mat_pele, _mat_boca]:
		if m != null:
			m.set_shader_parameter(&"abre", clampf(v, 0.0, 1.0))


## A testa aberta nas cabecadas: `progresso` e ate onde o sangue ja desceu
## pela cara (0 nada, 0,3 ja na orbita, 1 pingando do queixo).
func por_sangue(progresso: float) -> void:
	if _mat_pele == null:
		return
	_mat_pele.set_shader_parameter(&"sangue", progresso)


## A cara sendo destruida: `nivel` 0 inteira, 1, 2 e 3 depois de cada golpe
## (continuo: a cena anima o salto no quadro do impacto). Amassa o osso na
## malha (pele e dentes), abre os cortes, arranca a pele, mostra o osso. Os
## olhos que ainda estao na orbita vao para tras com ela.
func por_dano(nivel: float) -> void:
	_dano = clampf(nivel, 0.0, 3.0)
	var i0 := mini(floori(_dano), 2)
	var f := _dano - float(i0)
	var cs := PackedVector4Array()
	var fs := PackedFloat32Array()
	for a: Array in AMASSOS:
		var c: Vector3 = a[0]
		var t: Array = a[2]
		cs.append(Vector4(c.x, c.y, c.z, float(a[1])))
		fs.append(lerpf(float(t[i0]), float(t[i0 + 1]), f))
	while cs.size() < 6:
		cs.append(Vector4.ZERO)
		fs.append(0.0)
	for m: ShaderMaterial in [_mat_pele, _mat_boca]:
		if m != null:
			m.set_shader_parameter(&"amassos", cs)
			m.set_shader_parameter(&"fundos", fs)
			m.set_shader_parameter(&"n_amassos", AMASSOS.size())
			m.set_shader_parameter(&"dano", _dano)
	for i in _olhos.size():
		var o := _olhos[i]
		if o == null or not is_instance_valid(o) or o.get_parent() != self:
			continue
		var base := Vector3(OLHO.x * (-1.0 if i == 0 else 1.0), OLHO.y, OLHO.z)
		o.position = base + Vector3(0.0, 0.0, _amasso_em(base, cs, fs))


## Quanto o amassado empurra o ponto `p` para dentro (m), sem as placas.
static func _amasso_em(p: Vector3, cs: PackedVector4Array, fs: PackedFloat32Array) -> float:
	var z := 0.0
	for i in cs.size():
		var c := cs[i]
		if fs[i] <= 0.0 or c.w <= 0.0:
			continue
		var k := 1.0 - smoothstep(0.0, c.w, p.distance_to(Vector3(c.x, c.y, c.z)))
		z += fs[i] * k * k * (3.0 - 2.0 * k)
	return z


func dano() -> float:
	return _dano


## O olho esquerdo dele (o globo, filho desta cabeca ate alguem o soltar).
func olho_esquerdo() -> MeshInstance3D:
	return _olhos[0] if not _olhos.is_empty() else null


## O olho esquerdo saiu da orbita: a orbita vira buraco (0 a 1) e o globo
## mostra o fundo ensanguentado.
func por_orbita_vazia(v: float) -> void:
	if _mat_pele != null:
		_mat_pele.set_shader_parameter(&"orbita_vazia", clampf(v, 0.0, 1.0))
	if _mat_olho_e != null:
		_mat_olho_e.set_shader_parameter(&"sclera_albedo",
			Color.WHITE.lerp(OLHO_ARRANCADO_TOM, clampf(v, 0.0, 1.0)))


## `forca` e o brilho que o capuz pede (0 apagados): acende o ponto de longe.
## `tamanho` cresce o ponto atras do vidro embacado.
func por_olhos(forca: float, tamanho: float) -> void:
	if _mat_longe != null:
		_mat_longe.set_shader_parameter(&"forca", forca)
		_mat_longe.set_shader_parameter(&"escala", tamanho)


static func _carregar() -> bool:
	if _malha_pele != null:
		return true
	var cena := load(CENA) as PackedScene
	if cena == null:
		return false
	var raiz := cena.instantiate()
	for mi: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if String(mi.name).begins_with("Pele"):
			_malha_pele = m
		elif String(mi.name).begins_with("Boca"):
			_malha_boca = m
	raiz.free()
	return _malha_pele != null and _malha_boca != null


## O globo com a UV que o shader de olho espera: azimutal a partir da pupila
## (o polo +Y), o centro da UV na pupila e a borda no fundo do olho. As linhas
## dos polos tem um vertice por coluna, cada um com o angulo da sua coluna: com
## um vertice so, o fundo do olho puxava a iris para tras.
static func _globo() -> ArrayMesh:
	if _malha_globo != null:
		return _malha_globo
	var aneis := 48
	var lados := 64
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in aneis + 1:
		var th := PI * float(i) / float(aneis)
		for j in lados + 1:
			var ph := TAU * float(j) / float(lados)
			var q := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			st.set_normal(q)
			st.set_uv(Vector2(0.5, 0.5) + Vector2(cos(ph), sin(ph)) * (th / PI) * 0.5)
			st.add_vertex(q * OLHO_R)
	for i in aneis:
		for j in lados:
			var a := i * (lados + 1) + j
			var b := a + lados + 1
			# Horario visto de fora: a frente do Godot.
			for v: int in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(v)
	st.generate_tangents()
	_malha_globo = st.commit()
	return _malha_globo


static func _material_do_olho() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(OLHO_SHADER_HS) as Shader
	m.set_shader_parameter(&"sclera_albedo_texture", load(OLHO_TEX + "eye_sclera_diff.png"))
	m.set_shader_parameter(&"iris_albedo_texture", load(OLHO_TEX + "eye_iris_diff.png"))
	m.set_shader_parameter(&"sclera_normal_texture", load(OLHO_TEX + "eye_sclera_nrm.png"))
	m.set_shader_parameter(&"iris_normal_texture", load(OLHO_TEX + "eye_iris_nrm.png"))
	m.set_shader_parameter(&"texture_heightmap", load(OLHO_TEX + "eye_iris_parallax.png"))
	m.set_shader_parameter(&"sclera_albedo", Color.WHITE)
	m.set_shader_parameter(&"iris_albedo", OLHO_IRIS_TOM)
	m.set_shader_parameter(&"normal_strength", 1.0)
	m.set_shader_parameter(&"iris_scale", OLHO_IRIS_ESCALA)
	m.set_shader_parameter(&"roughness", 0.08)
	m.set_shader_parameter(&"specular", 0.5)
	m.set_shader_parameter(&"heightmap_scale", 31.8)
	m.set_shader_parameter(&"heightmap_flip", Vector2(1.0, 1.0))
	m.set_shader_parameter(&"subsurface_scattering_strength", 0.4)
	m.set_shader_parameter(&"uv1_scale", Vector3.ONE)
	m.set_shader_parameter(&"uv1_offset", Vector3.ZERO)
	return m


static func _shader(nome: StringName, codigo: String) -> Shader:
	if not _shaders.has(nome):
		var s := Shader.new()
		s.code = codigo.replace("#QUEIXADA", QUEIXADA).replace("#AMASSO", AMASSO)
		_shaders[nome] = s
	return _shaders[nome]


func _montar() -> void:
	_mat_pele = ShaderMaterial.new()
	_mat_pele.shader = _shader(&"pele", PELE_SHADER)
	_mat_pele.set_shader_parameter(&"mapa", load(MAPA))
	_mat_pele.set_shader_parameter(&"mapa_n", load(MAPA_N))
	if ResourceLoader.exists(SANGUE):
		_mat_pele.set_shader_parameter(&"sangue_mapa", load(SANGUE))
	if ResourceLoader.exists(GORE):
		_mat_pele.set_shader_parameter(&"gore_mapa", load(GORE))
	_mat_pele.set_shader_parameter(&"pivo", PIVO)
	_mat_pele.set_shader_parameter(&"giro_max", GIRO_QUEIXADA)
	var pele := MeshInstance3D.new()
	pele.name = "Pele"
	pele.mesh = _malha_pele
	pele.material_override = _mat_pele
	add_child(pele)

	_mat_boca = ShaderMaterial.new()
	_mat_boca.shader = _shader(&"boca", BOCA_SHADER)
	_mat_boca.set_shader_parameter(&"pivo", PIVO)
	_mat_boca.set_shader_parameter(&"giro_max", GIRO_QUEIXADA)
	var boca := MeshInstance3D.new()
	boca.name = "Boca"
	boca.mesh = _malha_boca
	boca.material_override = _mat_boca
	# Dentro da boca a sombra do proprio dente e ruido; a oclusao ja escurece.
	boca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(boca)

	var globo := _globo()
	var mat_olho := _material_do_olho()
	_mat_longe = ShaderMaterial.new()
	_mat_longe.shader = _shader(&"longe", OLHO_LONGE_SHADER)
	_mat_longe.set_shader_parameter(&"de", LONGE_DE)
	_mat_longe.set_shader_parameter(&"ate", LONGE_ATE)
	var quad := QuadMesh.new()
	quad.size = Vector2(LONGE_QUAD, LONGE_QUAD)
	for lado: float in [-1.0, 1.0]:
		var olho := MeshInstance3D.new()
		olho.name = "Olho" + ("E" if lado < 0.0 else "D")
		olho.mesh = globo
		olho.material_override = mat_olho
		if lado < 0.0:
			# O esquerdo tem material proprio: e ele que sai da orbita.
			_mat_olho_e = mat_olho.duplicate() as ShaderMaterial
			olho.material_override = _mat_olho_e
		_olhos.append(olho)
		olho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(olho)
		olho.position = Vector3(OLHO.x * lado, OLHO.y, OLHO.z)
		# O polo de cima da esfera (o centro da pupila) para a frente, e cada
		# olho um fio para fora: o olhar que nao converge em nada.
		olho.rotation = Vector3(-PI * 0.5, OLHO_DIVERGE * lado, 0.0)
		var longe := MeshInstance3D.new()
		longe.name = "Longe" + ("E" if lado < 0.0 else "D")
		longe.mesh = quad
		longe.material_override = _mat_longe
		longe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(longe)
		longe.position = Vector3(OLHO.x * lado, OLHO.y, OLHO.z - OLHO_R - 0.002)

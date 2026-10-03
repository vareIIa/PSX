## A batina AAA dos padres da estrada: capuz, murca e batina com capa, a malha
## do gerador (50 mil triangulos, texturas PBR de 4K), presa no pano de verdade
## (`PanoGPU`).
##
## Por que existe
## --------------
## O pano procedural (`CapuzMacabro.vestir_pano`) pesa e balanca, mas e liso:
## tubos de la com rugas de shader. A batina do gerador tem dobra, rasgo,
## barra roida, cordao, sangue e a murca solta sobre os ombros — mas e uma
## estatua, curvada para a frente e com a capa soprada para tras. O pedido e
## as duas coisas: a roupa de verdade, com fisica solta de pano leve.
##
## Como funciona
## -------------
## `tools/blender_batina` prepara tudo fora do jogo:
## - `r_limpar` tira a cruz e a fita de metal (o crucifixo novo tem corrente com
##   fisica propria) e as mangas (cada padre traz o braco com a manga dele);
## - `r_endireitar` poe a batina em pe, na pessoa de referencia de 1,72 m;
## - `r_grades` ajusta as tres grades do pano na malha (capuz, murca, batina) e
##   pendura murca e batina sob gravidade: e esse o repouso que a fisica segue;
## - `r_ligar` prende cada vertice na grade mais perto (duas, onde as camadas
##   se juntam), pela coordenada de grade e um desvio no referencial local.
## Aqui as tres grades entram no `PanoGPU` como pecas sem malha propria, e a
## batina e UMA malha que o shader poe em cima delas: no vertice, a superficie
## Catmull-Rom das particulas (posicao e as duas derivadas, 16 leituras), o
## referencial dali e o desvio. A malha anda, dobra e balanca com o pano, e a
## sombra vem junto.
##
## `--batina-velha` volta ao pano procedural (A/B).
class_name BatinaAAA
extends RefCounted

const PASTA := "res://assets/monstros/padre/batina_aaa/"
const MALHA := PASTA + "batina_aaa_malha.res"
const GRADES := PASTA + "batina_aaa_grades.json"
const COR := PASTA + "batina_aaa_cor.png"
const NORMAL := PASTA + "batina_aaa_normal.png"
const MR := PASTA + "batina_aaa_mr.png"
## A oclusao assada no repouso, com o corpo e a cabeca dentro (`r_ao.py`).
const AO := PASTA + "batina_aaa_ao.png"
## O quadrado de pano que os tampos repetem (`r_limpar`: origem e lado na UV).
const REMENDO := PASTA + "batina_aaa_remendo.json"
## A caixa de corte, em volta do tronco (a malha anda pela textura).
const CAIXA := AABB(Vector3(-1.2, -1.3, -1.4), Vector3(2.4, 2.4, 2.8))

## --- A cabeca dos OUTROS padres (`vestir(..., cabeca)`) ---
## So quem nao e o padre principal: o do capo, o do carona, os romeiros e a
## roda (a `CabecaDeFundo`). O principal (o da janela, que quebra o vidro) fica
## como e: o shader, o compute e a grade dele sao os de sempre.
##
## Por que: o do capo rasteja deitado de barriga olhando o motorista, com a
## cabeca girada 80 a 104 graus em relacao ao tronco (a `SondaDoCapuz`, 25,7 a
## 31 s). A barra do capuz (linhas 0 a 3) seguia o tronco, a passagem para a
## cabeca (linhas 4 a 7) era a media das duas posicoes — com 90 graus de giro
## ela corta a cabeca de lado a lado na altura da boca —, e a murca e a batina,
## presas nas costas, ficavam dentro da nuca. Medido no desenho: 70 a 111 mm de
## pano dentro da cabeca, e na tela uma mascara preta na metade de baixo da cara.
##
## O campo de distancia com sinal da pele da `CabecaDeFundo`
## (`tools/gerar_sdf_cabeca.py`, metros da pessoa de 1,72 m, rosto para -z).
const CABECA_SDF := PASTA + "batina_aaa_cabeca_fundo_sdf.res"
## Quanto a grade fica da pele alem da espessura da peca (m, `PanoGPU.cabeca_folga`).
const CABECA_FOLGA := 0.005
## O peso da cabeca nas linhas de baixo do capuz dos outros (a linha 0, a barra
## presa, fica no tronco; da `CAPUZ_NA_CABECA.size()` em diante, cabeca
## inteira). O capuz anda com a cabeca como capuz de verdade, e a passagem para
## o tronco fica no pescoco, curta.
const CAPUZ_NA_CABECA := [0.0, 0.45, 0.85]
## A protecao da cabeca desliga com a distancia da lente (m): de `LONGE_DE` a
## `LONGE_ATE` ela esmaece (sem estalo), e dali para longe nao custa nada.
const LONGE_DE := 7.0
const LONGE_ATE := 10.0

const SHADER := """
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, depth_draw_opaque;

// As particulas de cada peca (capuz, murca, batina e as duas mangas), do
// `PanoGPU`.
uniform sampler2D pos0 : filter_nearest, repeat_disable;
uniform sampler2D pos1 : filter_nearest, repeat_disable;
uniform sampler2D pos2 : filter_nearest, repeat_disable;
uniform sampler2D pos3 : filter_nearest, repeat_disable;
uniform sampler2D pos4 : filter_nearest, repeat_disable;
uniform ivec2 grade0 = ivec2(2, 2);
uniform ivec2 grade1 = ivec2(2, 2);
uniform ivec2 grade2 = ivec2(2, 2);
uniform ivec2 grade3 = ivec2(2, 2);
uniform ivec2 grade4 = ivec2(2, 2);
// A escala da pessoa: o desvio da malha foi medido na de 1,72 m.
uniform float escala = 1.0;
// A franja da manga (o desvio que pende alem da grade, para a barra) so pende
// onde a manga desce: com o braco erguido ela recolhe na barra em vez de ficar
// em pe como labareda. 0 desliga (a batina no corpo); a `MangaDoPadre` liga.
uniform float franja_cai = 0.0;
// A manga do braco vivo: a linha da grade da boca dela. O avesso escurece da
// boca para dentro (a mao sai do escuro). Negativo desliga.
uniform float boca_linha = -1.0;
// Onde o desvio recolhe: a area da grade de agora sobre a da ligacao (de x,
// todo recolhido, a y, inteiro).
const vec2 AMASSA = vec2(0.12, 0.40);
uniform sampler2D cor_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
// glTF: rugosidade no verde, metal no azul.
uniform sampler2D mr_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float normal_forca = 1.0;
// A oclusao assada (`r_ao.py`): o fundo do capuz, as dobras e o que fica entre
// o pano e o corpo. Sem ela o fundo do capuz via o ceu inteiro e o pano quase
// preto refletia o ambiente como vinil.
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float ao_forca = 1.0;
// Quanto a oclusao escurece tambem a luz direta (o farol entra pela boca do
// capuz, mas o fundo dele e as dobras fundas ficam no escuro).
uniform float ao_luz = 0.6;
// Os tampos dos buracos (a fita do peito, as costuras): U >= 2 e a coordenada
// plana deles; ali o pano e um quadrado limpo do atlas repetido em espelho.
// COLOR traz a diferenca de cor para a borda (rgb = 0,5 + dif / 2) e a AO (a).
uniform vec2 remendo_origem = vec2(0.0);
uniform float remendo_lado = 0.0;
// A trama de la por cima (o mapa de 4K do pano, `PanoGPU.MAPA_N`, 40 cm por
// tile): a textura do gerador tem uns 3 px por centimetro e, a um palmo da
// janela, o pano virava borrao liso. `trama_escala` leva a UV do gerador ao
// tile (a densidade dela, medida no `r_ligar`, e a escala da pessoa).
uniform sampler2D trama_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trama_mapa : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float trama_escala = 0.0;
uniform float trama_forca = 0.7;
uniform float rim_forca = 0.22;
uniform float chao = 0.0;
uniform float lama_altura = 0.40;
uniform vec3 cor_lama : source_color = vec3(0.16, 0.12, 0.085);
uniform float molhado : hint_range(0.0, 1.0) = 0.35;
// Depuracao (`--batina-grade`): pinta a celula da grade de cada vertice, um
// xadrez por peca (capuz vermelho, murca verde, batina azul).
uniform bool ver_grade = false;
// Depuracao (`--batina-ver=ao|rug|lado`): pinta o valor como emissao.
uniform int ver = 0;

varying vec3 v_mundo;
varying vec3 v_grade;

vec4 pesos(float t) {
	float t2 = t * t;
	float t3 = t2 * t;
	return vec4(-0.5 * t3 + t2 - 0.5 * t, 1.5 * t3 - 2.5 * t2 + 1.0,
		-1.5 * t3 + 2.0 * t2 + 0.5 * t, 0.5 * t3 - 0.5 * t2);
}

vec4 dpesos(float t) {
	float t2 = t * t;
	return vec4(-1.5 * t2 + 2.0 * t - 0.5, 4.5 * t2 - 5.0 * t,
		-4.5 * t2 + 4.0 * t + 0.5, 1.5 * t2 - t);
}

// Catmull-Rom nas particulas: linhas presas nas pontas, colunas em volta. A
// mesma conta de `r_ligar.avaliar`, com as derivadas pelos pesos derivados.
void superficie(sampler2D t, ivec2 gr, vec2 g, out vec3 p, out vec3 du, out vec3 dv) {
	float gx = mod(g.x, float(gr.x));
	float gy = clamp(g.y, 0.0, float(gr.y - 1));
	ivec2 b = ivec2(floor(vec2(gx, gy)));
	vec2 f = vec2(gx, gy) - vec2(b);
	vec4 wx = pesos(f.x);
	vec4 wy = pesos(f.y);
	vec4 dx = dpesos(f.x);
	vec4 dy = dpesos(f.y);
	p = vec3(0.0);
	du = vec3(0.0);
	dv = vec3(0.0);
	for (int j = 0; j < 4; j++) {
		int lin = clamp(b.y + j - 1, 0, gr.y - 1);
		vec3 l = vec3(0.0);
		vec3 ld = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			int col = ((b.x + i - 1) % gr.x + gr.x) % gr.x;
			vec3 q = texelFetch(t, ivec2(col, lin), 0).xyz;
			l += q * wx[i];
			ld += q * dx[i];
		}
		p += l * wy[j];
		du += ld * wy[j];
		dv += l * dy[j];
	}
}

// `area0`: |dS/dgx x dS/dgy| da grade na ligacao (0 = sem conta). Onde o pano
// amassa (a area cai a uma fracao dela), o referencial gira na dobra e o
// desvio viraria espeto: ele recolhe e o vertice deita na superficie.
vec3 ponto(int id, vec2 g, vec3 o, float area0, out vec3 T, out vec3 B, out vec3 N, out float recolhe) {
	vec3 p;
	vec3 du;
	vec3 dv;
	if (id == 0) {
		superficie(pos0, grade0, g, p, du, dv);
	} else if (id == 1) {
		superficie(pos1, grade1, g, p, du, dv);
	} else if (id == 2) {
		superficie(pos2, grade2, g, p, du, dv);
	} else if (id == 3) {
		superficie(pos3, grade3, g, p, du, dv);
	} else {
		superficie(pos4, grade4, g, p, du, dv);
	}
	vec3 cr = cross(du, dv);
	N = normalize(cr + vec3(0.0, 1e-12, 0.0));
	T = normalize(du - N * dot(N, du) + vec3(1e-12, 0.0, 0.0));
	B = cross(N, T);
	recolhe = 1.0;
	if (area0 > 0.0) {
		recolhe = smoothstep(AMASSA.x, AMASSA.y, length(cr) / (area0 * escala * escala));
	}
	float oy = o.y;
	if (franja_cai > 0.0 && oy > 0.0) {
		oy *= mix(1.0, smoothstep(-0.3, 0.6, -B.y), franja_cai);
	}
	return p + (T * o.x + B * oy + N * o.z) * escala * recolhe;
}

void vertex() {
	vec3 T;
	vec3 B;
	vec3 N;
	float recolhe;
	vec3 p = ponto(int(CUSTOM0.w + 0.5), UV2, CUSTOM0.xyz, CUSTOM2.w, T, B, N, recolhe);
	if (CUSTOM1.z > 0.0) {
		vec3 T2;
		vec3 B2;
		vec3 N2;
		float r2;
		vec3 p2 = ponto(int(CUSTOM1.w + 0.5), CUSTOM1.xy, CUSTOM2.xyz, 0.0, T2, B2, N2, r2);
		p = mix(p, p2, CUSTOM1.z);
	}
	// O sinal da bitangente vem da entrada (cross(N, T) * TANGENT.w).
	float sinal = dot(BINORMAL, cross(NORMAL, TANGENT)) < 0.0 ? -1.0 : 1.0;
	vec3 n = NORMAL;
	vec3 tg = TANGENT;
	VERTEX = p;
	v_grade = vec3(UV2, CUSTOM0.w);
	// Onde o desvio recolheu (amassado), o vertice deita na grade: a normal vai
	// com ela, e nao com a dobra desenhada que sumiu.
	NORMAL = normalize(mix(N, T * n.x + B * n.y + N * n.z, recolhe));
	TANGENT = normalize(T * tg.x + B * tg.y + N * tg.z);
	BINORMAL = normalize(cross(NORMAL, TANGENT)) * sinal;
	v_mundo = p;
}

void fragment() {
	bool remendo = UV.x > 1.5 && remendo_lado > 0.0;
	vec2 uv = UV;
	vec2 vira = vec2(0.0);
	if (remendo) {
		vec2 m = mod((UV - vec2(2.0, 0.0)) / remendo_lado, 2.0);
		vira = step(1.0, m);
		uv = remendo_origem + mix(m, 2.0 - m, vira) * remendo_lado;
	}
	// A pegada do filtro vem da UV continua (no espelho a de `uv` vira de sinal).
	vec2 ddx = dFdx(UV);
	vec2 ddy = dFdy(UV);
	vec3 c = textureGrad(cor_tex, uv, ddx, ddy).rgb;
	if (remendo) {
		c = max(c + (COLOR.rgb - 0.5) * 2.0, vec3(0.0));
	}
	float rug = textureGrad(mr_tex, uv, ddx, ddy).g;
	// Barro da estrada subindo pela barra.
	float alto = v_mundo.y - chao;
	float lama = 1.0 - smoothstep(0.02, lama_altura, alto);
	c = mix(c, cor_lama, lama * 0.55);
	float mol = clamp(molhado + lama * 0.35, 0.0, 1.0);
	// Molhado escurece a la e baixa um pouco a rugosidade.
	c *= mix(1.0, 0.72, mol);
	if (!FRONT_FACING) {
		// O avesso: forro, onde a luz quase nao entra.
		c *= 0.45;
		if (boca_linha > 0.0) {
			c *= mix(1.0, 0.08, smoothstep(0.0, 2.5, boca_linha - v_grade.y));
		}
	}
	if (ver_grade) {
		float xadrez = mod(floor(v_grade.x) + floor(v_grade.y), 2.0);
		vec3 base = v_grade.z < 0.5 ? vec3(0.9, 0.2, 0.15) : (v_grade.z < 1.5 ? vec3(0.2, 0.8, 0.25)
			: (v_grade.z < 2.5 ? vec3(0.2, 0.35, 0.95) : (v_grade.z < 3.5 ? vec3(0.95, 0.8, 0.1) : vec3(0.8, 0.2, 0.9))));
		c = base * (0.35 + 0.65 * xadrez);
	}
	ALBEDO = c;
	ROUGHNESS = clamp(mix(rug, 0.62, mol * 0.4), 0.35, 1.0);
	METALLIC = 0.0;
	SPECULAR = mix(0.2, 0.35, mol);
	if (ver > 0) {
		float val = ver == 1 ? (remendo ? COLOR.a : texture(ao_tex, UV).r) : (ver == 2 ? rug : (FRONT_FACING ? 1.0 : 0.0));
		ALBEDO = vec3(0.0);
		EMISSION = vec3(val);
	}
	vec3 nm = textureGrad(normal_tex, uv, ddx, ddy).rgb;
	// A copia espelhada inverte o relevo naquele eixo.
	nm.xy = mix(nm.xy, 1.0 - nm.xy, vira);
	if (trama_escala > 0.0) {
		// Mistura "whiteout" das duas normais (as duas no espaco da UV). O Z do
		// mapa comprimido (dois canais) nao se le: reconstroi.
		vec2 ut = (remendo ? UV - vec2(2.0, 0.0) : UV) * trama_escala;
		vec2 a = nm.xy * 2.0 - 1.0;
		vec2 b = (texture(trama_n, ut).xy * 2.0 - 1.0) * trama_forca;
		vec3 n1 = vec3(a, sqrt(max(1.0 - dot(a, a), 0.0)));
		vec3 n2 = vec3(b, sqrt(max(1.0 - dot(b, b), 0.0)));
		vec3 nn = normalize(vec3(n1.xy + n2.xy, n1.z * n2.z));
		nm = vec3(nn.xy * 0.5 + 0.5, 1.0);
		// O vao entre os fios fica no escuro e o fio de cima, claro (a altura
		// media do mapa e 0,55: a cor media do pano nao muda).
		float fio = texture(trama_mapa, ut).r;
		ALBEDO *= 1.0 + (fio - 0.55) * 1.2 * trama_forca * (ver_grade || ver > 0 ? 0.0 : 1.0);
	}
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_forca;
	AO = mix(1.0, remendo ? COLOR.a : texture(ao_tex, UV).r, ao_forca);
	AO_LIGHT_AFFECT = ao_luz;
	// A penugem da la pega luz de raspao.
	// So do lado de fora: no avesso (o fundo do capuz, em angulo rasante) a
	// penugem acendia em faixas claras, de plastico.
	RIM = FRONT_FACING ? rim_forca * (1.0 - mol * 0.6) : 0.0;
	RIM_TINT = 0.7;
}
"""

## O que o shader dos outros ganha (`_com_cabeca`): pedacos postos no `SHADER`
## por ancoras de texto. O do principal nao muda um caractere.
const CABECA_UNIFORMES := """
// A cabeca de quem veste (so os outros padres, `BatinaAAA.CABECA_SDF`): o
// campo de distancia da pele (metros da pessoa de 1,72 m, rosto para -z), do
// mundo para o espaco dela, a escala (a menor dos tres eixos: a cabeca de
// fundo e esticada) e a forca (0 desliga; esmaece com a distancia). A queixada
// gira `queixada` rad em volta de `queixada_pivo` (a da `CabecaDoPadre`).
uniform sampler3D cabeca_sdf : filter_linear, repeat_disable;
uniform mat4 cabeca_inv = mat4(0.0);
uniform vec3 sdf_min = vec3(0.0);
uniform vec3 sdf_tam = vec3(1.0);
uniform float cabeca_escala = 0.0;
uniform float cabeca_forca = 0.0;
uniform float queixada = 0.0;
uniform vec3 queixada_pivo = vec3(0.0, -0.018, 0.030);
// Perto da cabeca (a menos de CAB_FAIXA m da pele) o pano e empurrado para fora
// e comprimido contra ela, sem nunca passar de CAB_FOLGA m (a parede de dentro
// e a de fora na mesma ordem: nada vira do avesso).
const float CAB_FAIXA = 0.022;
const float CAB_FOLGA = 0.006;
// A boca do capuz fica aberta: nenhum pano na frente da cara (a elipse
// JANELA em x e y no espaco da cabeca, centrada em JANELA_Y, da frente dela, a
// menos de JANELA_PERTO m da pele). A borda do capuz de pe fica fora dela.
const vec2 JANELA = vec2(0.066, 0.090);
const float JANELA_Y = -0.02;
const float JANELA_PERTO = 0.035;
"""
const CABECA_FUNCOES := """
float cab_sdf(vec3 q) {
	return texture(cabeca_sdf, (q - sdf_min) / sdf_tam).r;
}

// A distancia a pele (no espaco da cabeca), com a queixada aberta: o minimo
// da cabeca parada e da girada (so na metade de baixo).
float cab_dist(vec3 q) {
	float d = cab_sdf(q);
	if (queixada > 0.0 && q.y < queixada_pivo.y + 0.03) {
		vec3 r = q - queixada_pivo;
		float c = cos(queixada);
		float s = sin(queixada);
		d = min(d, cab_sdf(queixada_pivo + vec3(r.x, c * r.y - s * r.z, s * r.y + c * r.z)));
	}
	return d;
}

vec3 cab_grad(vec3 q) {
	float e = 0.004;
	return vec3(cab_dist(q + vec3(e, 0.0, 0.0)) - cab_dist(q - vec3(e, 0.0, 0.0)),
		cab_dist(q + vec3(0.0, e, 0.0)) - cab_dist(q - vec3(0.0, e, 0.0)),
		cab_dist(q + vec3(0.0, 0.0, e)) - cab_dist(q - vec3(0.0, 0.0, e)));
}

// O vertice `p` (mundo) fora da cabeca, e a normal `nn` deitando nela onde o
// pano encosta. A grade colide com a pele (`PanoGPU`), mas o desenho e a grade
// mais o desvio de cada vertice: o desvio e que entrava.
vec3 fora_da_cabeca(vec3 p, inout vec3 nn) {
	if (cabeca_forca <= 0.0 || cabeca_escala <= 0.0) {
		return p;
	}
	vec3 q = (cabeca_inv * vec4(p, 1.0)).xyz;
	vec3 uvw = (q - sdf_min) / sdf_tam;
	if (any(lessThan(uvw, vec3(0.01))) || any(greaterThan(uvw, vec3(0.99)))) {
		return p;
	}
	float d = cab_dist(q) * cabeca_escala;
	if (d >= CAB_FAIXA) {
		return p;
	}
	vec3 gw = normalize(transpose(mat3(cabeca_inv)) * cab_grad(q) + vec3(0.0, 1e-9, 0.0));
	float u = CAB_FAIXA - d;
	float rm = CAB_FAIXA - CAB_FOLGA;
	float fica = rm * (1.0 - exp(-u / rm));
	p += gw * (u - fica) * cabeca_forca;
	// Comprimido contra a cabeca, o pano deita nela: a normal vai junto (a do
	// lado de fora olha para fora, a de dentro para a pele).
	float deita = (1.0 - exp(-u / rm)) * cabeca_forca;
	nn = normalize(mix(nn, gw * sign(dot(nn, gw) + 1e-4), deita * 0.8));
	// Onde o campo dobra (a boca aberta, a queixada girada) o primeiro
	// empurrao nao basta: mais um, so ate a folga.
	q = (cabeca_inv * vec4(p, 1.0)).xyz;
	float d2 = cab_dist(q) * cabeca_escala;
	if (d2 < CAB_FOLGA) {
		vec3 g2 = normalize(transpose(mat3(cabeca_inv)) * cab_grad(q) + vec3(0.0, 1e-9, 0.0));
		p += g2 * (CAB_FOLGA - d2) * cabeca_forca;
	}
	return p;
}
"""
## A boca do capuz aberta, no comeco do `fragment()`: o do capo, deitado de
## barriga com a cabeca virada para o motorista, encosta a cara no ombro (o
## pescoco gira ate 104 graus), e a murca e a barra do capuz, que o empurrao
## tira de dentro da cabeca, deitavam na frente da cara. Quem cobre a cara,
## colado nela, nao e desenhado. A borda ondula de leve em volta da cara (no
## espaco da cabeca: parada nela, sem pisca), como a boca de um capuz, e nao
## um oval de compasso; lisa, sem serrilhado.
##
## E o que sobrou dentro da cabeca tambem nao: o empurrao tira cada vertice,
## mas um triangulo esticado (a barra do capuz entre o ombro e a cabeca girada
## 100 graus) passa por dentro dela com os tres vertices fora. Ali ele nunca e
## visto (a pele esta na frente), a nao ser pela boca aberta.
const CABECA_JANELA := """
	if (cabeca_forca > 0.5 && cabeca_escala > 0.0) {
		vec3 qj = (cabeca_inv * vec4(v_mundo, 1.0)).xyz;
		vec3 uvj = (qj - sdf_min) / sdf_tam;
		if (all(greaterThan(uvj, vec3(0.0))) && all(lessThan(uvj, vec3(1.0)))) {
			float dj = cab_dist(qj) * cabeca_escala;
			if (dj < 0.0) {
				discard;
			}
			vec2 rj = vec2(qj.x / JANELA.x, (qj.y - JANELA_Y) / JANELA.y);
			float ej = length(rj);
			if (qj.z < -0.02 && ej < 1.08 && dj < JANELA_PERTO) {
				float aj = atan(rj.y, rj.x);
				if (ej < 1.0 + 0.045 * sin(aj * 5.0 + 1.3) + 0.025 * sin(aj * 11.0 + 0.4)) {
					discard;
				}
			}
		}
	}
"""
const CABECA_ANCORA_FRAG := "void fragment() {\n"
## As ancoras no `SHADER` e o que entra no lugar delas (`_com_cabeca`).
const CABECA_ANCORA_UNIF := "uniform int ver = 0;\n"
const CABECA_ANCORA_FUNC := "void vertex() {\n"
const CABECA_ANCORA_VERT := "\tVERTEX = p;\n\tv_grade = vec3(UV2, CUSTOM0.w);\n"
const CABECA_ANCORA_NORM := "\tNORMAL = normalize(mix(N, T * n.x + B * n.y + N * n.z, recolhe));\n"
const CABECA_ANCORA_TANG := "\tTANGENT = normalize(T * tg.x + B * tg.y + N * tg.z);\n"
const CABECA_VERT := "\tvec3 nn_c = normalize(mix(N, T * n.x + B * n.y + N * n.z, recolhe));\n" \
	+ "\tp = fora_da_cabeca(p, nn_c);\n" + CABECA_ANCORA_VERT
const CABECA_NORM := "\tNORMAL = nn_c;\n"
const CABECA_TANG := CABECA_ANCORA_TANG \
	+ "\tTANGENT = normalize(TANGENT - NORMAL * dot(NORMAL, TANGENT) + vec3(1e-6, 0.0, 0.0));\n"

## Liga a batina AAA em quem veste pelo `CapuzMacabro.vestir_pano`.
static var ligada := true

static var _malha: Mesh
static var _grades: Array = []
static var _shader: Shader
static var _cor: Texture2D
static var _normal: Texture2D
static var _mr: Texture2D
static var _ao: Texture2D
static var _remendo: Dictionary = {}
static var _tentou := false
## O shader dos outros padres (o `SHADER` com a cabeca, `_com_cabeca`), o campo
## da cabeca de fundo (a textura 3D e a imagem em fatias, para o `PanoGPU`) e a
## caixa dele no espaco da cabeca. Montados na primeira vez que alguem pede.
static var _shader_cabeca: Shader
static var _sdf: ImageTexture3D
static var _sdf_img: Image
static var _sdf_min := Vector3.ZERO
static var _sdf_tam := Vector3.ONE
static var _sdf_tentou := false
## O material de quem some: todo vertice no mesmo ponto, fora da tela (nenhum
## triangulo tem area, nem na sombra).
static var _sumido: ShaderMaterial


## Se a batina AAA vale para quem vai vestir agora (carrega na primeira vez).
static func usar() -> bool:
	if not ligada or OS.get_cmdline_user_args().has("--batina-velha"):
		return false
	return _carregar()


static func _carregar() -> bool:
	if _malha != null:
		return true
	if _tentou:
		return false
	_tentou = true
	if not ResourceLoader.exists(MALHA) or not ResourceLoader.exists(GRADES):
		push_warning("BatinaAAA: sem %s ou %s" % [MALHA, GRADES])
		return false
	var js := load(GRADES) as JSON
	if js == null or not (js.data is Dictionary):
		return false
	_grades = js.data["pecas"]
	_malha = load(MALHA) as Mesh
	_cor = load(COR) as Texture2D
	_normal = load(NORMAL) as Texture2D
	_mr = load(MR) as Texture2D
	_ao = load(AO) as Texture2D if ResourceLoader.exists(AO) else null
	if ResourceLoader.exists(REMENDO):
		var rj := load(REMENDO) as JSON
		if rj != null and rj.data is Dictionary:
			_remendo = rj.data
	_shader = Shader.new()
	_shader.code = VidroCortaPano.costurar(SHADER)
	return _malha != null


## Se os outros padres (os que nao sao o principal) ganham a cabeca que o pano
## nao atravessa: o campo carregou e nao veio `--batina-outros-velha` (o A/B:
## tudo como antes).
static func usar_cabeca() -> bool:
	if OS.get_cmdline_user_args().has("--batina-outros-velha") or not _carregar():
		return false
	if not _sdf_tentou:
		_sdf_tentou = true
		_carregar_sdf()
	return _sdf != null and _shader_cabeca != null


## As fatias do campo de distancia (empilhadas numa imagem, ver
## `tests/gerar_sdf_cabeca.gd`) viram a textura 3D; e o shader dos outros.
static func _carregar_sdf() -> void:
	if not ResourceLoader.exists(CABECA_SDF):
		push_warning("BatinaAAA: sem %s" % CABECA_SDF)
		return
	var img := load(CABECA_SDF) as Image
	if img == null or not img.has_meta(&"fatias"):
		return
	var nz := int(img.get_meta(&"fatias"))
	var nx := img.get_width()
	var ny := img.get_height() / nz
	var fatias: Array[Image] = []
	for k in nz:
		fatias.append(img.get_region(Rect2i(0, k * ny, nx, ny)))
	_sdf = ImageTexture3D.new()
	if _sdf.create(img.get_format(), nx, ny, nz, false, fatias) != OK:
		_sdf = null
		return
	_sdf_min = img.get_meta(&"minimo")
	_sdf_tam = img.get_meta(&"tamanho")
	_sdf_img = img
	var codigo := _com_cabeca(SHADER)
	if codigo.is_empty():
		_sdf = null
		return
	_shader_cabeca = Shader.new()
	_shader_cabeca.code = VidroCortaPano.costurar(codigo)


## O `SHADER` com a cabeca (`CABECA_UNIFORMES`, `CABECA_FUNCOES` e o empurrao
## no fim do `vertex()`). Vazio se alguma ancora nao esta la (o shader mudou):
## melhor sem a protecao que um shader quebrado.
static func _com_cabeca(base: String) -> String:
	var c := base.replace("\r\n", "\n")
	for par: Array in [[CABECA_ANCORA_UNIF, CABECA_ANCORA_UNIF + CABECA_UNIFORMES],
			[CABECA_ANCORA_FUNC, CABECA_FUNCOES + "\n" + CABECA_ANCORA_FUNC],
			[CABECA_ANCORA_VERT, CABECA_VERT], [CABECA_ANCORA_NORM, CABECA_NORM],
			[CABECA_ANCORA_TANG, CABECA_TANG],
			[CABECA_ANCORA_FRAG, CABECA_ANCORA_FRAG + CABECA_JANELA]]:
		if c.count(String(par[0])) != 1:
			push_error("BatinaAAA: a ancora %s nao e unica no shader" % String(par[0]).strip_edges())
			return ""
		c = c.replace(String(par[0]), String(par[1]))
	return c


## A frente da roupa desenhada no repouso, para o crucifixo (`peito`): medida
## uma vez, na pessoa de 1,72 m (`_medir_frente`).
static var _frente_do_pano: Dictionary = {}


## Onde o crucifixo encosta, no espaco do esqueleto (pessoa na escala `s`):
## - `pescoco_e`/`pescoco_d`: os lados do pescoco, na base dele, rente a pele.
##   A corrente da a volta na nuca por baixo do capuz (atras e dos lados ela
##   nao aparece e nao se simula) e sai dali;
## - `ancora_e`/`ancora_d`: onde cada lado passa por cima da gola, no fundo do
##   decote, logo abaixo do queixo. Do pescoco ate ali a corrente vai esticada
##   pelo peso da cruz; dali para baixo ela e solta, sempre por cima da roupa.
##   A murca de IA sobe dos lados ate a queixada: por cima da beira dela nos
##   lados, a corrente passava na altura da boca;
## - `argola`: onde a cruz pendura, no meio do peito, por cima da murca;
## - `frente`: a frente da roupa DESENHADA no repouso que vai com o tronco
##   (murca, batina e a barra do capuz), uma grade em x e y com o z mais a
##   frente da malha em cada celula, ja adiantado da folga (`_medir_frente`). E
##   ali que a corrente e a cruz deitam. Com capsulas na grade do pano (a de
##   antes), o pano desenhado ficava por fora da corrente e ela sumia por dentro
##   da roupa, picotada;
## - `frente_cabeca`: a mesma grade do capuz que vai com a cabeca, no espaco do
##   osso da cabeca. Com a cabeca baixa (a janela), a boca do capuz desce na
##   frente do peito e cobria a corrente logo abaixo do queixo.
## O pescoco e do esqueleto e a frente e a da malha: nada depende da boca do
## capuz.
static func peito(s: float) -> Dictionary:
	# O lado do pescoco (pessoa de 1,72 m, no espaco do esqueleto), na base dele,
	# rente a pele. Medido na malha da cabeca (`cabeca.glb`): o pescoco tem
	# |x| <= 0,044 e z de -0,03 a 0,07, e a queixada, em x = 0,05, desce ate
	# y = 1,476. Logo abaixo da queixada (1,47), a cabeca que gira para a lente
	# passava a queixada por cima da ancora e a corrente saia de dentro dela.
	const PESCOCO_LADO := Vector3(0.045, 1.44, -0.02)
	# Onde a corrente passa a gola (x, y): no fundo do decote, logo abaixo do
	# queixo (o queixo desce ate 1,476 e fica 8 cm atras da frente da gola). Na
	# beira de cima da gola (y 1,49), de frente, a corrente saia do canto da
	# boca.
	const GOLA := Vector2(0.03, 1.465)
	# A argola no meio do peito (y) e o quanto ela e a gola ficam por cima da
	# frente (m).
	const ARGOLA_Y := 1.34
	const ACIMA := 0.008
	const ACIMA_GOLA := 0.004
	if not _carregar() or _grades.size() < 2:
		return {}
	if _frente_do_pano.is_empty():
		_frente_do_pano = _medir_frente()
	var escalar := func(f: Dictionary) -> Dictionary:
		var z: PackedFloat32Array = f["z"]
		var zs := PackedFloat32Array()
		zs.resize(z.size())
		for i in z.size():
			zs[i] = z[i] * s if is_finite(z[i]) else INF
		return {"x0": float(f["x0"]) * s, "y0": float(f["y0"]) * s, "passo": float(f["passo"]) * s,
			"nx": int(f["nx"]), "ny": int(f["ny"]), "z": zs}
	var frente: Dictionary = escalar.call(_frente_do_pano["tronco"])
	var frente_cabeca: Dictionary = escalar.call(_frente_do_pano["cabeca"])
	var na_frente := func(x: float, y: float) -> float:
		return frente_em(frente, x * s, y * s)
	var zg: float = na_frente.call(GOLA.x, GOLA.y)
	var za: float = na_frente.call(0.0, ARGOLA_Y)
	var gola := Vector3(GOLA.x * s, GOLA.y * s, (zg if is_finite(zg) else -0.16 * s) - ACIMA_GOLA * s)
	var argola := Vector3(0.0, ARGOLA_Y * s, (za if is_finite(za) else -0.27 * s) - ACIMA * s)
	var pescoco := PESCOCO_LADO * s
	return {"pescoco_d": pescoco, "pescoco_e": Vector3(-pescoco.x, pescoco.y, pescoco.z),
		"ancora_d": gola, "ancora_e": Vector3(-gola.x, gola.y, gola.z),
		"argola": argola, "frente": frente, "frente_cabeca": frente_cabeca}


## A frente da roupa em (x, y) (a grade de `peito`: `frente`), interpolada; INF
## fora dela ou onde nao ha roupa (o decote aberto, em volta do queixo).
static func frente_em(f: Dictionary, x: float, y: float) -> float:
	var passo: float = f["passo"]
	var nx: int = f["nx"]
	var ny: int = f["ny"]
	var gx := (x - float(f["x0"])) / passo - 0.5
	var gy := (y - float(f["y0"])) / passo - 0.5
	var ix := int(floor(gx))
	var iy := int(floor(gy))
	if ix < 0 or iy < 0 or ix >= nx - 1 or iy >= ny - 1:
		return INF
	var z: PackedFloat32Array = f["z"]
	var a := z[iy * nx + ix]
	var b := z[iy * nx + ix + 1]
	var c := z[(iy + 1) * nx + ix]
	var d := z[(iy + 1) * nx + ix + 1]
	if not (is_finite(a) and is_finite(b) and is_finite(c) and is_finite(d)):
		# Na beira do decote: a celula mais a frente das que existem (sem
		# inventar roupa no buraco).
		var m := INF
		for v in [a, b, c, d]:
			m = minf(m, v)
		return m
	var fx := gx - float(ix)
	var fy := gy - float(iy)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Mede a frente da roupa na malha do repouso (a mesma que o shader poe em cima
## das grades): por celula de `PASSO`, o z mais a frente dos triangulos do
## capuz, da murca e da batina (rasterizados no plano x, y: a malha da frente e
## rala, e so os vertices deixavam buracos no peito por onde a corrente entrava),
## adiantado da folga inteira da particula que cada vertice segue e de `MARGEM`.
## A particula nao sai mais que a folga do repouso no osso do torso (na frente
## da murca, de 0,4 a 7 cm), e debrucado (a janela) o pano pende para a frente
## ate ela; a margem e o desvio do shader girando com o pano. O decote aberto
## em volta do queixo fica sem roupa (INF). O vertice que segue mais a cabeca
## que o tronco (o capuz de cima da barra) vai para a grade `cabeca`, no espaco
## do osso da cabeca (a origem dele e a base do pescoco, `Corpo.Y_PESCOCO`).
static func _medir_frente() -> Dictionary:
	const PASSO := 0.015
	const MARGEM := 0.01
	# As duas grades: [x0, y0, nx, ny, origem]; o z de cada uma em `z0` (o
	# tronco) e `z1` (a cabeca), soltos: um array empacotado dentro de um Array e
	# copia, e escrever nele copiava a grade inteira a cada vertice.
	var grades := [
		[-0.26, 0.90, 35, 42, Vector3.ZERO],
		[-0.20, -0.06, 27, 24, Vector3(0.0, Corpo.Y_PESCOCO, 0.0)],
	]
	var z0 := PackedFloat32Array()
	z0.resize(35 * 42)
	z0.fill(INF)
	var z1 := PackedFloat32Array()
	z1.resize(27 * 24)
	z1.fill(INF)
	var sups: Dictionary = _malha.get_meta(&"superficie_de", {})
	var quais := {}
	for k: Variant in sups:
		var gi := int(k)
		if gi < _grades.size() and String((_grades[gi] as Dictionary).get("tipo", "")) != "manga":
			quais[int(sups[k])] = true
	for sup: int in quais:
		var arr := _malha.surface_get_arrays(sup)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var c0: Variant = arr[Mesh.ARRAY_CUSTOM0]
		var uv2: Variant = arr[Mesh.ARRAY_TEX_UV2]
		var tem := c0 is PackedFloat32Array and uv2 is PackedVector2Array \
			and (c0 as PackedFloat32Array).size() == v.size() * 4
		# Por vertice: o z ja com a folga e a margem (INF atras do corpo) e de
		# qual grade ele e (0 tronco, 1 cabeca).
		var zl := PackedFloat32Array()
		zl.resize(v.size())
		var qual := PackedByteArray()
		qual.resize(v.size())
		for i in v.size():
			var p := v[i]
			if p.z > 0.05:
				zl[i] = INF
				continue
			var folga := 0.0
			var cabeca := 0.0
			if tem:
				var id := int((c0 as PackedFloat32Array)[i * 4 + 3] + 0.5)
				if id >= 0 and id < _grades.size():
					var g: Dictionary = _grades[id]
					var w := int(g["w"])
					var gg: Vector2 = (uv2 as PackedVector2Array)[i]
					var o := clampi(roundi(gg.y), 0, int(g["h"]) - 1) * w + posmod(roundi(gg.x), w)
					folga = float((g["folga"] as Array)[o])
					var pb := float((g["peso_b"] as Array)[o])
					if int((g["osso_b"] as Array)[o]) == Corpo.Osso.CABECA:
						cabeca += pb
					if int((g["osso_a"] as Array)[o]) == Corpo.Osso.CABECA:
						cabeca += 1.0 - pb
			zl[i] = p.z - folga - MARGEM
			qual[i] = 1 if cabeca >= 0.5 else 0
			var gr: Array = grades[qual[i]]
			var q: Vector3 = p - (gr[4] as Vector3)
			var cx := int(floor((q.x - float(gr[0])) / PASSO))
			var cy := int(floor((q.y - float(gr[1])) / PASSO))
			var nx: int = gr[2]
			if cx >= 0 and cy >= 0 and cx < nx and cy < int(gr[3]):
				var k := cy * nx + cx
				if qual[i] == 0:
					z0[k] = minf(z0[k], zl[i])
				else:
					z1[k] = minf(z1[k], zl[i])
		for t in range(0, ids.size(), 3):
			var i0 := ids[t]
			var i1 := ids[t + 1]
			var i2 := ids[t + 2]
			if not (is_finite(zl[i0]) and is_finite(zl[i1]) and is_finite(zl[i2])):
				continue
			if qual[i0] != qual[i1] or qual[i0] != qual[i2]:
				continue
			var gr: Array = grades[qual[i0]]
			var x0g: float = gr[0]
			var y0g: float = gr[1]
			var nx: int = gr[2]
			var ny: int = gr[3]
			var org: Vector3 = gr[4]
			var a := Vector2(v[i0].x - org.x, v[i0].y - org.y)
			var b := Vector2(v[i1].x - org.x, v[i1].y - org.y)
			var c := Vector2(v[i2].x - org.x, v[i2].y - org.y)
			var x0 := maxi(int(floor((minf(a.x, minf(b.x, c.x)) - x0g) / PASSO - 0.5)), 0)
			var x1 := mini(int(ceil((maxf(a.x, maxf(b.x, c.x)) - x0g) / PASSO - 0.5)), nx - 1)
			var y0 := maxi(int(floor((minf(a.y, minf(b.y, c.y)) - y0g) / PASSO - 0.5)), 0)
			var y1 := mini(int(ceil((maxf(a.y, maxf(b.y, c.y)) - y0g) / PASSO - 0.5)), ny - 1)
			if x0 > x1 or y0 > y1:
				continue
			var den := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
			if absf(den) < 1e-10:
				continue
			var da_cabeca := qual[i0] == 1
			for cy in range(y0, y1 + 1):
				var py := y0g + (float(cy) + 0.5) * PASSO
				for cx in range(x0, x1 + 1):
					var px := x0g + (float(cx) + 0.5) * PASSO
					var w0 := ((b.y - c.y) * (px - c.x) + (c.x - b.x) * (py - c.y)) / den
					var w1 := ((c.y - a.y) * (px - c.x) + (a.x - c.x) * (py - c.y)) / den
					var w2 := 1.0 - w0 - w1
					if w0 < -1e-4 or w1 < -1e-4 or w2 < -1e-4:
						continue
					var k := cy * nx + cx
					var zv := zl[i0] * w0 + zl[i1] * w1 + zl[i2] * w2
					if da_cabeca:
						z1[k] = minf(z1[k], zv)
					else:
						z0[k] = minf(z0[k], zv)
	var saida := {}
	for gi in 2:
		var gr: Array = grades[gi]
		var nx: int = gr[2]
		var ny: int = gr[3]
		var z: PackedFloat32Array = z0 if gi == 0 else z1
		# Os buracos que sobraram com cinco ou mais vizinhas com roupa.
		var cheio := z.duplicate()
		for cy in ny:
			for cx in nx:
				if is_finite(z[cy * nx + cx]):
					continue
				var m := INF
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var x := cx + dx
						var y := cy + dy
						if x < 0 or y < 0 or x >= nx or y >= ny or (dx == 0 and dy == 0):
							continue
						var vz := z[y * nx + x]
						if is_finite(vz):
							m = minf(m, vz)
							n += 1
				if n >= 5:
					cheio[cy * nx + cx] = m
		saida["tronco" if gi == 0 else "cabeca"] = {"x0": gr[0], "y0": gr[1], "passo": PASSO,
			"nx": nx, "ny": ny, "z": cheio}
	return saida


## Os colisores (indices) que a peca `tipo` nao ve. A batina fica entre o
## tronco e o braco de cima; a manga ve so o braco do lado dela (e nao o
## tronco, que a empurrava para fora do braco na axila).
static func _nao_ve(tipo: String, nome: String, papeis: Dictionary) -> Array:
	var fora: Array = []
	if papeis.is_empty():
		return fora
	if tipo == "batina":
		for ch: StringName in [&"braco_e", &"braco_d"]:
			if papeis.has(ch):
				fora.append(int(papeis[ch]))
	elif tipo == "manga":
		var lado := "_e" if nome.ends_with("E") else "_d"
		for ch: StringName in papeis:
			if not String(ch).ends_with(lado):
				fora.append(int(papeis[ch]))
	return fora


## Veste em `pano` (com os colisores ja postos) as pecas e a malha, na escala
## `s` da pessoa (altura / `Corpo.ALTURA_REF`). `papeis` sao os colisores do
## `CorpoAAA` ({papel: indice}): a batina nao ve o braco de cima (passa entre ele
## e o tronco), e a manga so ve o braco dela. Devolve a malha.
##
## `cabeca`: so nos padres que NAO sao o principal (a `CabecaDeFundo`, com a
## malha no no e o rosto para -z), e so se `usar_cabeca()`. O pano passa a nao
## entrar nela: a fisica colide com a pele (`PanoGPU.cabeca`), o desenho e
## empurrado para fora no shader (`CABECA_FUNCOES`) e o capuz anda com a cabeca
## (`CAPUZ_NA_CABECA`, com a passagem pelo arco do pescoco). Sem `cabeca`, nada
## muda.
static func vestir(pano: PanoGPU, s: float, papeis: Dictionary = {},
		cabeca: Node3D = null) -> MeshInstance3D:
	var com_cabeca := cabeca != null and usar_cabeca()
	var mat := material(s, true, com_cabeca)
	if com_cabeca:
		pano.cabeca = cabeca
		pano.cabeca_campo = _sdf_img
		pano.cabeca_min = _sdf_min
		pano.cabeca_tam = _sdf_tam
		# A grade e o meio da parede: a de dentro fica ~meia espessura mais perto
		# da pele. Meio centimetro a mais alem da espessura.
		pano.cabeca_folga = CABECA_FOLGA * s
		mat.set_shader_parameter(&"cabeca_sdf", _sdf)
		mat.set_shader_parameter(&"sdf_min", _sdf_min)
		mat.set_shader_parameter(&"sdf_tam", _sdf_tam)
	for k in _grades.size():
		var g: Dictionary = _grades[k]
		var w := int(g["w"])
		var h := int(g["h"])
		var n := w * h
		var rep := PackedVector3Array()
		rep.resize(n)
		var r: Array = g["repouso"]
		for i in n:
			var p: Array = r[i]
			rep[i] = Vector3(p[0], p[1], p[2]) * s
		var fo := PackedFloat32Array(g["folga"])
		var dura := OS.get_cmdline_user_args().has("--batina-dura")
		for i in n:
			fo[i] *= 0.0 if dura else s
		var opcoes: Dictionary = (g["opcoes"] as Dictionary).duplicate()
		opcoes["sem_malha"] = true
		opcoes["espessura"] = float(opcoes.get("espessura", 0.012)) * s
		opcoes["sem_colisor"] = _nao_ve(String(g.get("tipo", "")), String(g["nome"]), papeis)
		var pb := PackedFloat32Array(g["peso_b"])
		var capuz := com_cabeca and String(g.get("tipo", "")) == "capuz"
		if capuz:
			# O capuz anda com a cabeca: da linha 1 em diante o peso dela sobe
			# (nunca desce), e a barra presa fica no tronco.
			for i in n:
				var j := i / w
				var alvo := float(CAPUZ_NA_CABECA[j]) if j < CAPUZ_NA_CABECA.size() else 1.0
				pb[i] = maxf(pb[i], alvo)
			# E a passagem do tronco para a cabeca vai pelo arco do pescoco, e
			# nao pela reta entre as duas posicoes (com 90 graus de giro a reta
			# passa por dentro da cabeca).
			opcoes["arco_no_osso_b"] = true
		var pc := pano.adicionar(String(g["nome"]), w, h, bool(g["periodico"]), rep,
			PackedInt32Array(g["osso_a"]), PackedInt32Array(g["osso_b"]),
			pb, fo, PackedFloat32Array(g["puxa"]),
			PackedByteArray(g["preso"]), PackedByteArray(g["existe"]),
			PackedInt32Array(g["ancora"]), opcoes)
		pano.ligar_textura(pc, mat, StringName("pos%d" % k))
		mat.set_shader_parameter(StringName("grade%d" % k), Vector2i(w, h))
	var mi := MeshInstance3D.new()
	mi.name = "BatinaAAA"
	mi.mesh = _malha
	# O material vai por superficie (o `material_override` venceria o da peca
	# escondida).
	for i in _malha.get_surface_count():
		mi.set_surface_override_material(i, mat)
	mi.custom_aabb = AABB(CAIXA.position * s, CAIXA.size * s)
	pano.acompanhar(mi, mat)
	# O que some, peca a peca (`esconde`):
	# - a manga do braco que a cena troca pelo `BracoVivo`/`BracoDoPadre`;
	# - sem o `CorpoAAA`, as duas mangas (o corpo de caixa leva os
	#   `BracosPodres`, com a manga deles);
	# - com `--cerco-sem-batina`, a batina de quem sobe no carro (meta `cerco`).
	#   O `CercoNoCarro` apagava a batina procedural (dura no plano do piso, um
	#   lencol no ar em cima do capo); a AAA deita no capo e cai pela frente
	#   dele como pano, e escondida deixava o corpo nu deitado no capo.
	# Cada peca e uma superficie da malha (`gerar_batina_aaa`): some pelo
	# material da superficie, triangulo inteiro. Escondendo por vertice, o
	# triangulo da divisa esticava ate o vertice sumido (uma coluna de pano dura
	# ate o chao nos que sobem no carro).
	var vigia := VigiaDaBatina.new()
	vigia.esqueleto = pano.esqueleto
	vigia.malha = mi
	vigia.material = mat
	var sups: Dictionary = _malha.get_meta(&"superficie_de", {})
	for k: Variant in sups:
		vigia.superficie[int(k)] = int(sups[k])
	for k in _grades.size():
		var g: Dictionary = _grades[k]
		var tipo := String(g.get("tipo", ""))
		if tipo == "manga":
			if papeis.is_empty():
				vigia.fixo |= 1 << k
			else:
				vigia.mangas.append([k, int((g["osso_a"] as Array)[0])])
		elif tipo == "batina":
			vigia.batina = k
	vigia.aplicar(vigia.fixo)
	if com_cabeca:
		# A cabeca deste quadro no shader: depois de quem anima (a pose que vai
		# ser desenhada).
		vigia.cabeca = cabeca
		vigia.process_priority = 1000
	mi.add_child(vigia)
	return mi


## O material da batina na escala `s` da pessoa, sem as posicoes das pecas:
## quem desenha liga a textura de cada grade (`pos0`..`pos4`, `grade0`..). E
## tambem o da manga do braco vivo (`MangaDoPadre`), que e a manga desta batina:
## ela passa `registrar` falso e se registra no `VidroCortaPano` como braco (o
## vidro que estourou nao corta a manga que entra por ele).
static func material(s: float, registrar := true, com_cabeca := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader_cabeca if com_cabeca and _shader_cabeca != null else _shader
	if registrar:
		VidroCortaPano.registrar(mat)
	mat.set_shader_parameter(&"cor_tex", _cor)
	mat.set_shader_parameter(&"normal_tex", _normal)
	mat.set_shader_parameter(&"mr_tex", _mr)
	var upm := float(_malha.get_meta(&"uv_por_metro", 0.0))
	if upm > 0.0 and not OS.get_cmdline_user_args().has("--batina-sem-trama"):
		mat.set_shader_parameter(&"trama_n", load(PanoGPU.MAPA_N))
		mat.set_shader_parameter(&"trama_mapa", load(PanoGPU.MAPA))
		mat.set_shader_parameter(&"trama_escala", s / (upm * PanoGPU.TILE_M))
	if not _remendo.is_empty() and not OS.get_cmdline_user_args().has("--batina-sem-remendo"):
		var o: Array = _remendo["origem"]
		mat.set_shader_parameter(&"remendo_origem", Vector2(o[0], o[1]))
		mat.set_shader_parameter(&"remendo_lado", float(_remendo["lado"]))
	if _ao != null and not OS.get_cmdline_user_args().has("--batina-sem-ao"):
		mat.set_shader_parameter(&"ao_tex", _ao)
	else:
		mat.set_shader_parameter(&"ao_forca", 0.0)
	mat.set_shader_parameter(&"escala", s)
	mat.set_shader_parameter(&"ver_grade", OS.get_cmdline_user_args().has("--batina-grade"))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--batina-ver="):
			mat.set_shader_parameter(&"ver", ["", "ao", "rug", "lado"].find(arg.trim_prefix("--batina-ver=")))
	if OS.get_cmdline_user_args().has("--batina-sem-rim"):
		mat.set_shader_parameter(&"rim_forca", 0.0)
	if OS.get_cmdline_user_args().has("--batina-sem-relevo"):
		mat.set_shader_parameter(&"normal_forca", 0.0)
	return mat


## A transformacao da `cabeca` no mundo pela pose do osso em que ela esta
## pendurada (um `BoneAttachment3D` do `esqueleto`), e nao pelo anexo: ele so
## segue o osso depois de quem pergunta. Sem anexo, a global dela.
static func cabeca_no_mundo(cabeca: Node3D, esqueleto: Skeleton3D) -> Transform3D:
	var cadeia := Transform3D()
	var no: Node = cabeca
	while no != null and not (no is BoneAttachment3D):
		cadeia = (no as Node3D).transform * cadeia
		no = no.get_parent()
	if no != null and esqueleto != null and (no as BoneAttachment3D).get_skeleton() == esqueleto:
		return esqueleto.global_transform * esqueleto.get_bone_global_pose(
			(no as BoneAttachment3D).bone_idx) * cadeia
	return cabeca.global_transform


static func sumido() -> ShaderMaterial:
	if _sumido == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\n" \
			+ "void vertex() { POSITION = vec4(0.0, 0.0, 2.0, 1.0); }\nvoid fragment() { discard; }\n"
		_sumido = ShaderMaterial.new()
		_sumido.shader = sh
	return _sumido


## Some com a manga do braco trocado (e, com `--cerco-sem-batina`, com a
## batina de quem sobe no carro).
class VigiaDaBatina:
	extends Node
	var esqueleto: Skeleton3D
	## [[grade, osso do braco], ...]
	var mangas: Array = []
	## A grade da batina (-1 sem).
	var batina := -1
	## O que some sempre (bit por grade).
	var fixo := 0
	var malha: MeshInstance3D
	var material: ShaderMaterial
	## {grade: superficie da malha}
	var superficie := {}
	var _mascara := -1
	var _sem_batina := OS.get_cmdline_user_args().has("--cerco-sem-batina")
	## A cabeca que o pano nao atravessa (so os outros padres, `vestir`), ou null.
	var cabeca: Node3D

	func _process(_delta: float) -> void:
		if esqueleto == null or not is_instance_valid(esqueleto):
			return
		if cabeca != null:
			_seguir_cabeca()
		var m := fixo
		var corpo := esqueleto.get_parent()
		if batina >= 0 and corpo != null and corpo.has_meta(&"cerco") and _sem_batina:
			m |= 1 << batina
		for par: Array in mangas:
			# O braco some pela escala do osso (a janela do padre) ou pelo no
			# `BracoPodreE`/`D` apagado (o cerco e a janela do carona, ver
			# `CorpoAAA`).
			var proc := esqueleto.get_node_or_null(
				"BracoPodreE" if int(par[1]) == Corpo.Osso.BRACO_E else "BracoPodreD") as Node3D
			if esqueleto.get_bone_pose_scale(int(par[1])).x < 0.05 					or (proc != null and not proc.visible):
				m |= 1 << int(par[0])
		if m != _mascara:
			aplicar(m)

	## A cabeca deste quadro no shader: do mundo para o espaco dela, pela pose do
	## osso (o `BoneAttachment3D` so segue o osso depois), a menor escala, a
	## queixada aberta e a forca pela distancia da lente.
	func _seguir_cabeca() -> void:
		if not is_instance_valid(cabeca) or not cabeca.is_visible_in_tree():
			material.set_shader_parameter(&"cabeca_forca", 0.0)
			return
		var t := BatinaAAA.cabeca_no_mundo(cabeca, esqueleto)
		var cam := get_viewport().get_camera_3d()
		var forca := 1.0
		if cam != null:
			forca = 1.0 - smoothstep(BatinaAAA.LONGE_DE, BatinaAAA.LONGE_ATE,
				cam.global_position.distance_to(t.origin))
		material.set_shader_parameter(&"cabeca_forca", forca)
		if forca <= 0.0:
			return
		var sc := t.basis.get_scale()
		material.set_shader_parameter(&"cabeca_inv", Projection(t.affine_inverse()))
		material.set_shader_parameter(&"cabeca_escala", minf(sc.x, minf(sc.y, sc.z)))
		var q := 0.0
		var pele := cabeca.get_node_or_null(^"Pele") as MeshInstance3D
		var pm := pele.material_override as ShaderMaterial if pele != null else null
		if pm != null:
			var abre: Variant = pm.get_shader_parameter(&"abre")
			var giro: Variant = pm.get_shader_parameter(&"giro_max")
			if abre != null and giro != null:
				q = maxf(float(abre) * float(giro), 0.0)
			var pv: Variant = pm.get_shader_parameter(&"pivo")
			if pv is Vector3:
				material.set_shader_parameter(&"queixada_pivo", pv)
		material.set_shader_parameter(&"queixada", q)

	## Some com as pecas dos bits de `m` (e volta com as outras).
	func aplicar(m: int) -> void:
		_mascara = m
		var some := {}
		for k: int in superficie:
			var sup := int(superficie[k])
			some[sup] = bool(some.get(sup, false)) or ((m >> k) & 1) != 0
		for sup: int in some:
			malha.set_surface_override_material(sup, BatinaAAA.sumido() if some[sup] else material)

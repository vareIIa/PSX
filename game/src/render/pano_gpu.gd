## Pano de verdade para o corpo: capuz, murca e batina que caem, balancam,
## batem no corpo e deitam no chao. Simulado na placa de video.
##
## Por que existe
## --------------
## O capuz dos encapuzados era um tubo de aneis rigido, a murca e a batina
## cones fixos no osso: nada pesava, nada balancava, e na agarrada a lente
## entrava no pano. Pano com fisica em GDScript custa dezenas de milissegundos
## (mil particulas, doze ligacoes cada, dezenas de iteracoes); na placa de
## video custa quase nada.
##
## Como funciona
## -------------
## Cada peca e uma grade de particulas W x H (ate 1024), fechada em tubo nas
## colunas se `periodico`. Um compute shader, um grupo por peca, integra por
## Verlet em subpassos e resolve as ligacoes (eixo, diagonal e dobra) por Jacobi
## na memoria compartilhada. Depois, por particula:
## - a ancora de alcance (LRA): nao se afasta da particula presa mais do que o
##   comprimento do pano entre as duas, o que impede o pano de esticar;
## - a folga: nao se afasta mais que `folga` metros do lugar que o osso manda
##   (o repouso esfolado). E o que da forma ao capuz sem deixa-lo duro;
## - as colisoes: capsulas presas nos ossos, a lente da camera e o chao.
##
## O resultado vai para duas imagens (posicao e normal) que o shader de vertice
## le: a malha e so a grade com as coordenadas de grade no UV2, subdividida e
## alisada por Catmull-Rom no vertice.
##
## Sem RenderingDevice (Compatibility), nao ha simulacao: o pano segue o
## repouso esfolado, calculado na CPU.
class_name PanoGPU
extends Node3D

const MAX_PARTICULAS := 1024
const OSSOS := 12
const COLISORES := 24
## O quadro por personagem: os ossos de agora e do quadro anterior, as capsulas
## e quatro vec4 (geral, vento, lente, conta).
## As capsulas vao de agora e do quadro anterior: nos subpassos elas andam
## interpoladas, como o repouso. Pulando o quadro inteiro no primeiro subpasso,
## o estalo do pescoco (a cabeca desce um palmo em poucos quadros) passava a
## cabeca por baixo da murca, que ficava por cima dela.
const QUADRO_FLOATS := OSSOS * 16 * 2 + COLISORES * 16 + 16
## Floats por particula no buffer fixo (sete vec4, ver `Fixo` no shader).
const FIXO_FLOATS := 28
## Quantas vezes a malha desenhada subdivide a celula da grade.
const SUBDIVIDE := 2
## Metros de pano que o tile de 4K cobre (ver tools/gerar_pano.py).
const TILE_M := 0.40
const SUBPASSOS := 6
const ITERACOES := 6
const GRAVIDADE := 9.8
## Maior passo de tempo simulado de uma vez: engasgo nao arremessa o pano.
const DT_MAX := 1.0 / 30.0
## Longe assim da camera o pano para de simular (fica no ultimo quadro).
const LONGE := 32.0
## Andou mais que isto num quadro: e teleporte, o pano volta ao repouso.
const TELEPORTE := 1.5
const MAPA := "res://assets/monstros/pano/pano_mapa.png"
const MAPA_N := "res://assets/monstros/pano/pano_n.png"

const COMPUTE := """
#version 450
#define GRUPO 256
#define POR 4
#define MAXN 1024
#define OSSOS 12
#define COLS 24

layout(local_size_x = GRUPO, local_size_y = 1, local_size_z = 1) in;

struct Fixo {
	vec4 ra;      // repouso no osso a (xyz), w = osso a
	vec4 rb;      // repouso no osso b (xyz), w = osso b
	vec4 par;     // x peso de b, y folga, z puxa (1/s), w massa inversa
	vec4 l_eixo;  // comprimentos: direita, esquerda, baixo, cima (<= 0 sem ligacao)
	vec4 l_diag;  // dir-baixo, esq-baixo, dir-cima, esq-cima
	vec4 l_dobra; // dir2, esq2, baixo2, cima2
	vec4 lra;     // x ancora (-1 sem), y comprimento ate ela, z livre, w existe
};

layout(set = 0, binding = 0, std430) restrict buffer Estado { vec4 v[]; } estado;
layout(set = 0, binding = 1, std430) restrict readonly buffer Fixos { Fixo f[]; } fixos;
layout(set = 0, binding = 2, std430) restrict readonly buffer Quadro {
	mat4 osso[OSSOS];
	mat4 osso_antes[OSSOS];
	vec4 col_a[COLS];
	vec4 col_b[COLS];
	vec4 col_a0[COLS];
	vec4 col_b0[COLS];
	vec4 geral;   // dt, gravidade, chao, tempo
	vec4 vento;   // xyz, rajada
	vec4 lente;   // xyz, raio (0 sem)
	vec4 conta;   // colisores, reiniciar, subpassos, iteracoes
} q;
layout(set = 0, binding = 3, rgba32f) uniform restrict writeonly image2D img_pos;
layout(set = 0, binding = 4, rgba16f) uniform restrict writeonly image2D img_nor;

layout(push_constant, std430) uniform Params {
	ivec4 grade;  // W, H, periodico, sinal da normal
	vec4 pano;    // amortecimento (1/s), espessura (m), atrito, rigidez de dobra
	vec4 extra;   // aerodinamica, cisalhamento, compressao da dobra, colisores de fora
} pc;

shared vec4 sp[MAXN];

int W;
int H;
int N;

int vizinho(int x, int y, int dx, int dy) {
	int nx = x + dx;
	int ny = y + dy;
	if (ny < 0 || ny >= H) {
		return -1;
	}
	if (nx < 0 || nx >= W) {
		if (pc.grade.z == 0) {
			return -1;
		}
		nx = (nx + W) % W;
	}
	return ny * W + nx;
}

vec3 alvo(int i, float t) {
	Fixo fx = fixos.f[i];
	int a = int(fx.ra.w);
	int b = int(fx.rb.w);
	vec3 a1 = (q.osso[a] * vec4(fx.ra.xyz, 1.0)).xyz;
	vec3 b1 = (q.osso[b] * vec4(fx.rb.xyz, 1.0)).xyz;
	vec3 a0 = (q.osso_antes[a] * vec4(fx.ra.xyz, 1.0)).xyz;
	vec3 b0 = (q.osso_antes[b] * vec4(fx.rb.xyz, 1.0)).xyz;
	return mix(mix(a0, b0, fx.par.x), mix(a1, b1, fx.par.x), t);
}

vec3 ponto(int j, vec3 falta) {
	return (j >= 0 && sp[j].w >= 0.0) ? sp[j].xyz : falta;
}

vec3 normal_em(int x, int y) {
	vec3 p = sp[y * W + x].xyz;
	vec3 pr = ponto(vizinho(x, y, 1, 0), p);
	vec3 pl = ponto(vizinho(x, y, -1, 0), p);
	vec3 pd = ponto(vizinho(x, y, 0, 1), p);
	vec3 pu = ponto(vizinho(x, y, 0, -1), p);
	vec3 n = cross(pr - pl, pd - pu) * float(pc.grade.w);
	float l2 = dot(n, n);
	return l2 > 1e-14 ? n * inversesqrt(l2) : vec3(0.0, 1.0, 0.0);
}

vec2 oct(vec3 n) {
	n /= abs(n.x) + abs(n.y) + abs(n.z);
	vec2 r = n.xy;
	if (n.z < 0.0) {
		r = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
	}
	return r;
}

// Quanto o pano esta apertado ao longo de u e de v (0 = no comprimento de
// repouso, 0,3 = sobrando 30%): e o que vira ruga no fragmento.
vec2 aperto(int i, int x, int y, vec3 p) {
	Fixo fx = fixos.f[i];
	vec3 pr = ponto(vizinho(x, y, 1, 0), p);
	vec3 pl = ponto(vizinho(x, y, -1, 0), p);
	vec3 pd = ponto(vizinho(x, y, 0, 1), p);
	vec3 pu = ponto(vizinho(x, y, 0, -1), p);
	float lu = max(fx.l_eixo.x, 0.0) + max(fx.l_eixo.y, 0.0);
	float lv = max(fx.l_eixo.z, 0.0) + max(fx.l_eixo.w, 0.0);
	float cu = lu > 0.0 ? 1.0 - length(pr - pl) / lu : 0.0;
	float cv = lv > 0.0 ? 1.0 - length(pd - pu) / lv : 0.0;
	return clamp(vec2(cu, cv), vec2(0.0), vec2(1.0));
}

void liga(inout vec3 soma, inout float n, vec3 p, float wi, int j, float L, float k,
		float comp) {
	if (j < 0 || L <= 0.0) {
		return;
	}
	vec4 o = sp[j];
	if (o.w < 0.0) {
		return;
	}
	float ws = wi + o.w;
	if (ws <= 0.0) {
		return;
	}
	vec3 d = o.xyz - p;
	float dist = length(d);
	if (dist < 1e-7) {
		return;
	}
	float c = dist - L;
	// Pano nao resiste a ser apertado: dobra. So a dobra tem compressao mole.
	if (c < 0.0) {
		c *= comp;
	}
	soma += d * (k * c / dist * wi / ws);
	n += 1.0;
}

vec3 empurra_capsula(vec3 p, inout vec3 pv, vec3 a, vec3 b, float r, float atrito) {
	vec3 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-9), 0.0, 1.0);
	vec3 c = a + ab * t;
	vec3 d = p - c;
	float l = length(d);
	if (l >= r) {
		return p;
	}
	vec3 nn = l > 1e-6 ? d / l : vec3(0.0, 1.0, 0.0);
	vec3 np = c + nn * r;
	// Atrito: o pano que encosta nao escorrega livre pelo corpo.
	vec3 mov = np - pv;
	pv += (mov - nn * dot(mov, nn)) * atrito;
	return np;
}

void main() {
	W = pc.grade.x;
	H = pc.grade.y;
	N = W * H;
	int t = int(gl_LocalInvocationIndex);
	bool reinicia = q.conta.y > 0.5;
	int sub = int(q.conta.z);
	int its = int(q.conta.w);
	float h = q.geral.x / float(sub);

	vec3 p[POR];
	vec3 pv[POR];
	vec3 np[POR];
	float wi[POR];
	for (int k = 0; k < POR; k++) {
		int i = t + k * GRUPO;
		wi[k] = -1.0;
		p[k] = vec3(0.0);
		pv[k] = vec3(0.0);
		np[k] = vec3(0.0);
		if (i < N) {
			Fixo fx = fixos.f[i];
			wi[k] = fx.lra.w > 0.5 ? fx.par.w : -1.0;
			if (reinicia) {
				p[k] = alvo(i, 1.0);
				pv[k] = p[k];
			} else {
				p[k] = estado.v[i].xyz;
				pv[k] = estado.v[N + i].xyz;
			}
			sp[i] = vec4(p[k], wi[k]);
		}
	}
	memoryBarrierShared();
	barrier();

	for (int s = 0; s < sub; s++) {
		float fr = float(s + 1) / float(sub);
		// Integra: Verlet com amortecimento, gravidade, o ar contra a face do
		// pano e a memoria da forma (puxa de leve para o repouso).
		for (int k = 0; k < POR; k++) {
			int i = t + k * GRUPO;
			if (i >= N) {
				continue;
			}
			vec3 tg = alvo(i, fr);
			if (wi[k] < 0.0) {
				// Buraco na grade (a boca do capuz): segue o repouso, para o
				// alisamento do vertice ter vizinho.
				np[k] = tg;
				pv[k] = tg;
			} else if (wi[k] == 0.0) {
				np[k] = tg;
				pv[k] = p[k];
			} else {
				vec3 vel = (p[k] - pv[k]) * max(0.0, 1.0 - pc.pano.x * h);
				vec3 nrm = normal_em(i % W, i / W);
				float raj = 1.0 + q.vento.w * sin(q.geral.w * 1.3 + dot(p[k], vec3(1.7, 0.9, 2.3)));
				vec3 rel = q.vento.xyz * raj - vel / h;
				vec3 acc = vec3(0.0, -q.geral.y, 0.0) + nrm * dot(nrm, rel) * pc.extra.x;
				np[k] = p[k] + vel + acc * h * h;
				np[k] += (tg - np[k]) * min(1.0, fixos.f[i].par.z * h);
				pv[k] = p[k];
			}
		}
		memoryBarrierShared();
		barrier();
		for (int k = 0; k < POR; k++) {
			int i = t + k * GRUPO;
			if (i < N) {
				p[k] = np[k];
				sp[i].xyz = p[k];
			}
		}
		memoryBarrierShared();
		barrier();

		for (int it = 0; it < its; it++) {
			for (int k = 0; k < POR; k++) {
				int i = t + k * GRUPO;
				if (i >= N || wi[k] <= 0.0) {
					continue;
				}
				Fixo fx = fixos.f[i];
				int x = i % W;
				int y = i / W;
				vec3 soma = vec3(0.0);
				float n = 0.0;
				liga(soma, n, p[k], wi[k], vizinho(x, y, 1, 0), fx.l_eixo.x, 1.0, 1.0);
				liga(soma, n, p[k], wi[k], vizinho(x, y, -1, 0), fx.l_eixo.y, 1.0, 1.0);
				liga(soma, n, p[k], wi[k], vizinho(x, y, 0, 1), fx.l_eixo.z, 1.0, 1.0);
				liga(soma, n, p[k], wi[k], vizinho(x, y, 0, -1), fx.l_eixo.w, 1.0, 1.0);
				liga(soma, n, p[k], wi[k], vizinho(x, y, 1, 1), fx.l_diag.x, pc.extra.y, 1.0);
				liga(soma, n, p[k], wi[k], vizinho(x, y, -1, 1), fx.l_diag.y, pc.extra.y, 1.0);
				liga(soma, n, p[k], wi[k], vizinho(x, y, 1, -1), fx.l_diag.z, pc.extra.y, 1.0);
				liga(soma, n, p[k], wi[k], vizinho(x, y, -1, -1), fx.l_diag.w, pc.extra.y, 1.0);
				liga(soma, n, p[k], wi[k], vizinho(x, y, 2, 0), fx.l_dobra.x, pc.pano.w, pc.extra.z);
				liga(soma, n, p[k], wi[k], vizinho(x, y, -2, 0), fx.l_dobra.y, pc.pano.w, pc.extra.z);
				liga(soma, n, p[k], wi[k], vizinho(x, y, 0, 2), fx.l_dobra.z, pc.pano.w, pc.extra.z);
				liga(soma, n, p[k], wi[k], vizinho(x, y, 0, -2), fx.l_dobra.w, pc.pano.w, pc.extra.z);
				// Jacobi com sobre-relaxamento (Macklin 2014): media das
				// correcoes, vezes 1,5.
				np[k] = p[k] + soma * (1.5 / max(n, 1.0));
			}
			memoryBarrierShared();
			barrier();
			for (int k = 0; k < POR; k++) {
				int i = t + k * GRUPO;
				if (i < N && wi[k] > 0.0) {
					p[k] = np[k];
					sp[i].xyz = p[k];
				}
			}
			memoryBarrierShared();
			barrier();
		}

		// Ancora, folga, colisoes, lente e chao.
		for (int k = 0; k < POR; k++) {
			int i = t + k * GRUPO;
			if (i >= N || wi[k] <= 0.0) {
				continue;
			}
			Fixo fx = fixos.f[i];
			int an = int(fx.lra.x);
			if (an >= 0) {
				vec3 a = sp[an].xyz;
				vec3 d = p[k] - a;
				float l = length(d);
				float g = fx.lra.y * 1.03;
				if (l > g) {
					p[k] = a + d * (g / l);
				}
			}
			vec3 tg = alvo(i, fr);
			vec3 d = p[k] - tg;
			float l = length(d);
			if (l > fx.par.y) {
				p[k] = tg + d * (fx.par.y / l);
			}
			int nc = int(q.conta.x);
			// Os colisores que esta peca nao ve (bit c ligado): a batina passa
			// entre o tronco e o braco sem que o braco a empurre para dentro.
			int fora_mask = int(pc.extra.w + 0.5);
			for (int c = 0; c < nc; c++) {
				if (((fora_mask >> c) & 1) != 0) {
					continue;
				}
				p[k] = empurra_capsula(p[k], pv[k], mix(q.col_a0[c].xyz, q.col_a[c].xyz, fr),
					mix(q.col_b0[c].xyz, q.col_b[c].xyz, fr), q.col_a[c].w + pc.pano.y, pc.pano.z);
			}
			if (q.lente.w > 0.0) {
				p[k] = empurra_capsula(p[k], pv[k], q.lente.xyz, q.lente.xyz, q.lente.w, 0.0);
			}
			float ch = q.geral.z + pc.pano.y;
			if (p[k].y < ch) {
				p[k].y = ch;
				// No barro o pano gruda: quase nao escorrega.
				vec3 mov = p[k] - pv[k];
				pv[k].xz += mov.xz * 0.85;
			}
		}
		memoryBarrierShared();
		barrier();
		for (int k = 0; k < POR; k++) {
			int i = t + k * GRUPO;
			if (i < N && wi[k] > 0.0) {
				sp[i].xyz = p[k];
			}
		}
		memoryBarrierShared();
		barrier();
	}

	for (int k = 0; k < POR; k++) {
		int i = t + k * GRUPO;
		if (i >= N) {
			continue;
		}
		estado.v[i] = vec4(p[k], 0.0);
		estado.v[N + i] = vec4(pv[k], 0.0);
		ivec2 c = ivec2(i % W, i / W);
		imageStore(img_pos, c, vec4(p[k], 1.0));
		imageStore(img_nor, c, vec4(oct(normal_em(c.x, c.y)), aperto(i, c.x, c.y, p[k])));
	}
}
"""

const PANO_SHADER := """
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, depth_draw_opaque;

uniform sampler2D posicoes : filter_nearest, repeat_disable;
uniform sampler2D normais : filter_nearest, repeat_disable;
uniform ivec3 grade = ivec3(2, 2, 0);
uniform sampler2D mapa : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mapa_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 cor_pano : source_color = vec3(0.075, 0.066, 0.058);
uniform vec3 cor_lama : source_color = vec3(0.20, 0.15, 0.10);
uniform vec3 cor_forro : source_color = vec3(0.05, 0.035, 0.03);
uniform float chao = 0.0;
uniform float lama_altura = 0.35;
uniform float molhado : hint_range(0.0, 1.0) = 0.55;
uniform float relevo = 1.0;
uniform float buracos : hint_range(0.0, 1.0) = 0.5;
uniform float desfiado = 0.018;
// A boca do capuz, cortada por fragmento (e nao por celula da grade, que fazia
// escada): oval em (angulo, v), x = meia largura em radianos, y = centro em v,
// z = meia altura em v, w = 1 liga.
uniform vec4 boca = vec4(1.0, 0.5, 0.2, 0.0);

varying vec3 v_mundo;
varying float v_borda;
varying vec2 v_aperto;
uniform float rugas = 1.0;

vec3 pega(ivec2 q) {
	if (grade.z != 0) {
		q.x = (q.x % grade.x + grade.x) % grade.x;
	} else {
		q.x = clamp(q.x, 0, grade.x - 1);
	}
	q.y = clamp(q.y, 0, grade.y - 1);
	return texelFetch(posicoes, q, 0).xyz;
}

vec3 desoct(vec2 e) {
	vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
	float t = max(-n.z, 0.0);
	n.x += n.x >= 0.0 ? -t : t;
	n.y += n.y >= 0.0 ? -t : t;
	return normalize(n);
}

vec4 pega_n(ivec2 q) {
	if (grade.z != 0) {
		q.x = (q.x % grade.x + grade.x) % grade.x;
	} else {
		q.x = clamp(q.x, 0, grade.x - 1);
	}
	q.y = clamp(q.y, 0, grade.y - 1);
	vec4 t = texelFetch(normais, q, 0);
	return vec4(desoct(t.xy), 0.0);
}

vec2 pega_aperto(ivec2 q) {
	if (grade.z != 0) {
		q.x = (q.x % grade.x + grade.x) % grade.x;
	} else {
		q.x = clamp(q.x, 0, grade.x - 1);
	}
	q.y = clamp(q.y, 0, grade.y - 1);
	return texelFetch(normais, q, 0).zw;
}

vec4 pesos(float t) {
	float t2 = t * t;
	float t3 = t2 * t;
	return vec4(-0.5 * t3 + t2 - 0.5 * t, 1.5 * t3 - 2.5 * t2 + 1.0,
		-1.5 * t3 + 2.0 * t2 + 0.5 * t, 0.5 * t3 - 0.5 * t2);
}

vec3 catmull(vec2 g) {
	ivec2 b = ivec2(floor(g));
	vec2 f = g - vec2(b);
	vec4 wx = pesos(f.x);
	vec4 wy = pesos(f.y);
	vec3 r = vec3(0.0);
	for (int j = 0; j < 4; j++) {
		vec3 linha = pega(b + ivec2(-1, j - 1)) * wx.x + pega(b + ivec2(0, j - 1)) * wx.y
			+ pega(b + ivec2(1, j - 1)) * wx.z + pega(b + ivec2(2, j - 1)) * wx.w;
		r += linha * wy[j];
	}
	return r;
}

void vertex() {
	vec2 g = UV2;
	vec3 p = catmull(g);
	ivec2 b = ivec2(floor(g));
	vec2 f = g - vec2(b);
	vec3 n = mix(mix(pega_n(b).xyz, pega_n(b + ivec2(1, 0)).xyz, f.x),
		mix(pega_n(b + ivec2(0, 1)).xyz, pega_n(b + ivec2(1, 1)).xyz, f.x), f.y);
	v_aperto = mix(mix(pega_aperto(b), pega_aperto(b + ivec2(1, 0)), f.x),
		mix(pega_aperto(b + ivec2(0, 1)), pega_aperto(b + ivec2(1, 1)), f.x), f.y);
	n = normalize(n + vec3(0.0, 1e-6, 0.0));
	vec3 du = catmull(g + vec2(0.3, 0.0)) - catmull(g - vec2(0.3, 0.0));
	vec3 dv = catmull(g + vec2(0.0, 0.3)) - catmull(g - vec2(0.0, 0.3));
	vec3 tg = normalize(du - n * dot(n, du) + vec3(1e-6, 0.0, 0.0));
	VERTEX = p;
	NORMAL = n;
	TANGENT = tg;
	BINORMAL = normalize(cross(n, tg)) * sign(dot(cross(n, tg), dv) + 1e-9);
	v_mundo = p;
	v_borda = CUSTOM0.x;
}

void fragment() {
	vec4 m = texture(mapa, UV);
	// Variacao grande: o mesmo mapa em escala de metro, girado, para o desgaste
	// e a sujeira nao repetirem com o tile.
	vec2 uv_l = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * UV * 0.23;
	vec4 ml = texture(mapa, uv_l);
	// Furos de traca e a barra desfiada.
	float furo = m.a * smoothstep(0.35, 0.65, ml.b + buracos * 0.5 - 0.25);
	float fio = m.g * 0.6 + m.r * 0.4;
	float bainha = 1.0;
	if (boca.w > 0.5) {
		float a = (UV2.x / float(grade.x)) * 6.2831853;
		a = a > 3.14159265 ? a - 6.2831853 : a;
		float bu = a / boca.x;
		float bv = (UV2.y / float(grade.y - 1) - boca.y) / boca.z;
		float e = sqrt(bu * bu + bv * bv);
		// Borda roida: a la desfia em fios, a traca comeu.
		if (e < 1.0 + (fio - 0.5) * 0.05) {
			discard;
		}
		// A bainha dobrada: um dedo de pano mais grosso e mais escuro.
		bainha = smoothstep(1.0, 1.10, e);
	}
	if (furo > 0.5 || v_borda < desfiado * (0.25 + 1.1 * fio)) {
		discard;
	}
	float h = m.r;
	vec3 cor = cor_pano * (0.62 + 0.62 * m.g) * (0.45 + 0.75 * h);
	// Feltro: a la gasta desbota e perde o contraste da trama.
	cor = mix(cor, cor_pano * 1.25, m.b * 0.45);
	// Barro e agua da estrada subindo pela barra.
	float alto = v_mundo.y - chao;
	float lama = (1.0 - smoothstep(0.02, lama_altura * (0.5 + ml.g), alto)) * (0.55 + 0.45 * ml.r);
	cor = mix(cor, cor_lama * (0.5 + 0.5 * h), lama * 0.75);
	float mol = clamp(molhado + lama * 0.4 + (1.0 - smoothstep(0.0, 0.6, alto)) * 0.3, 0.0, 1.0);
	// Molhado: escurece (a agua enche o vao da fibra) e ganha brilho baixo.
	cor *= mix(1.0, 0.55, mol);
	if (!FRONT_FACING) {
		// O forro de dentro do capuz: a luz quase nao entra.
		cor = cor_forro * (0.6 + 0.4 * h);
	}
	cor *= mix(0.55, 1.0, bainha);
	ALBEDO = cor;
	ROUGHNESS = mix(0.95, 0.58, mol * (0.5 + 0.5 * h));
	SPECULAR = mix(0.25, 0.45, mol);
	// Rugas: onde o pano sobra ele franze, em dobras perpendiculares ao aperto
	// (a grade da fisica, de 3 a 4 cm, nao chega a dobrar sozinha). A fase
	// anda com o mapa grande: nenhuma dobra e reta nem repete.
	vec2 um = UV * 0.40;
	float fase_u = ml.g * 9.0 + ml.r * 3.0;
	float fase_v = ml.r * 9.0 + ml.g * 3.0;
	float lu = 0.034 + 0.018 * ml.b;
	float lv = 0.030 + 0.016 * ml.g;
	float au = clamp(v_aperto.x * 5.0, 0.0, 1.0) * rugas;
	float av = clamp(v_aperto.y * 5.0, 0.0, 1.0) * rugas;
	float su = sin(um.x / lu * 6.2831853 + fase_u);
	float sv = sin(um.y / lv * 6.2831853 + fase_v);
	vec2 inclina = vec2(cos(um.x / lu * 6.2831853 + fase_u) * au * 0.9,
		cos(um.y / lv * 6.2831853 + fase_v) * av * 0.9);
	vec3 nt = texture(mapa_n, UV).xyz * 2.0 - 1.0;
	nt = normalize(vec3(nt.xy + inclina, nt.z));
	NORMAL_MAP = nt * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = relevo;
	// A penugem pega luz de raspao: o contorno da la acende um fio.
	RIM = 0.35 * (1.0 - mol * 0.6);
	RIM_TINT = 0.7;
	// O fundo da ruga nao ve o ceu.
	AO = (0.55 + 0.45 * h) * (1.0 - 0.35 * au * (0.5 - 0.5 * su)) * (1.0 - 0.35 * av * (0.5 - 0.5 * sv));
	AO_LIGHT_AFFECT = 0.25;
}
"""


## Uma peca de pano: a grade, o material, e os recursos na placa.
class PecaDePano:
	var nome: String
	var w: int
	var h: int
	var periodico: bool
	var n: int
	var fixo: PackedFloat32Array
	var instancia: MeshInstance3D
	var material: ShaderMaterial
	var params: PackedByteArray
	var sinal: int = 1
	var material_boca := Vector4.ZERO
	var estado_rid: RID
	var fixo_rid: RID
	var pos_rid: RID
	var nor_rid: RID
	var conjunto_rid: RID
	var tex_pos: Texture2DRD
	var tex_nor: Texture2DRD
	## Sem placa: as imagens que a CPU enche com o repouso esfolado.
	var img_pos: Image
	var img_nor: Image
	var itex_pos: ImageTexture
	var itex_nor: ImageTexture
	## Peca sem malha propria (`sem_malha`): quem desenha e outra malha, que le
	## as posicoes pelos materiais ligados (`ligar_textura`).
	var sem_malha := false
	## [ShaderMaterial, parametro] que recebem a textura de posicoes.
	var ligacoes: Array = []


var esqueleto: Skeleton3D
var pecas: Array[PecaDePano] = []
## Vento no mundo (m/s) e a rajada (0 a 1).
var vento := Vector3(0.6, 0.0, 0.3)
var rajada := 0.5
## A lente empurra o pano (a janela, a agarrada): raio em metros, 0 desliga.
var raio_da_lente := 0.11

var _colisores: Array = []   # [osso, a local, b local, raio]
## Malhas de fora que andam com o tronco (caixa de corte) e recebem o chao:
## [MeshInstance3D, ShaderMaterial] (`acompanhar`).
var _acompanham: Array = []
var _ossos_antes: Array[Transform3D] = []
var _col_antes := PackedVector3Array()
var _quadro: PackedFloat32Array
var _quadro_rid: RID
var _reiniciar := true
var _tempo := 0.0
var _ultima_origem := Vector3.INF
var _rd: RenderingDevice

static var _shader_rid: RID
static var _pipeline_rid: RID
static var _usuarios := 0
static var _avisou := false
static var _shader_pano: Shader
static var _mapa: Texture2D
static var _mapa_n: Texture2D


func _init() -> void:
	name = "PanoGPU"
	# Depois de quem anima o corpo: le a pose ja deste quadro.
	process_priority = 100
	_quadro.resize(QUADRO_FLOATS)
	_rd = RenderingServer.get_rendering_device()
	# Depuracao: o pano no repouso esfolado, sem fisica (o caminho da CPU).
	if OS.get_cmdline_user_args().has("--pano-parado"):
		_rd = null


## Uma capsula de colisao presa ao osso `osso`, de `a` a `b` (no espaco do
## osso, sem escala) com `raio`.
func colisor(osso: int, a: Vector3, b: Vector3, raio: float) -> int:
	if _colisores.size() < COLISORES:
		_colisores.append([osso, a, b, raio])
		return _colisores.size() - 1
	return -1


## Os colisores postos ate aqui: [osso, a, b, raio] no espaco do osso (quem
## mais bate no corpo do padre usa os mesmos: a `CruzNoPeito`).
func colisores() -> Array:
	return _colisores


## Move o colisor `i` (o que `colisor` devolveu) quadro a quadro: o vidro da
## janela, que nao e osso nenhum, entra assim (`CabecadaDoPadre`).
func mover_colisor(i: int, a: Vector3, b: Vector3, raio: float) -> void:
	if i >= 0 and i < _colisores.size():
		_colisores[i][1] = a
		_colisores[i][2] = b
		_colisores[i][3] = raio


## Acrescenta uma peca. `repouso` sao as W*H posicoes no espaco do esqueleto,
## no repouso, linha a linha. Por particula: `osso_a`, `osso_b` e `peso_b`
## (esfola em dois ossos), `folga` (metros), `puxa` (1/s), `preso` (1 = fixo
## no osso) e `existe` (0 = buraco na grade). `ancora` e o indice da particula
## presa que segura esta pelo comprimento do pano (-1 sem).
## `opcoes`: amortecimento, espessura, atrito, dobra, aerodinamica, cisalha,
## compressao, e o que for uniforme do material (cor_pano, molhado, ...).
func adicionar(nome: String, w: int, h: int, periodico: bool, repouso: PackedVector3Array,
		osso_a: PackedInt32Array, osso_b: PackedInt32Array, peso_b: PackedFloat32Array,
		folga: PackedFloat32Array, puxa: PackedFloat32Array, preso: PackedByteArray,
		existe: PackedByteArray, ancora: PackedInt32Array, opcoes: Dictionary = {}) -> PecaDePano:
	var n := w * h
	assert(n <= MAX_PARTICULAS and repouso.size() == n)
	var pc := PecaDePano.new()
	pc.nome = nome
	pc.w = w
	pc.h = h
	pc.periodico = periodico
	pc.n = n
	pc.fixo.resize(n * FIXO_FLOATS)

	var idx := func(x: int, y: int) -> int:
		if y < 0 or y >= h:
			return -1
		if x < 0 or x >= w:
			if not periodico:
				return -1
			x = posmod(x, w)
		return y * w + x
	var comp := func(i: int, dx: int, dy: int) -> float:
		var x := i % w
		var y := i / w
		var j: int = idx.call(x + dx, y + dy)
		if j < 0 or existe[i] == 0 or existe[j] == 0:
			return 0.0
		return repouso[i].distance_to(repouso[j])

	for i in n:
		var o := i * FIXO_FLOATS
		var ba := osso_a[i]
		var bb := osso_b[i]
		var ra := esqueleto.get_bone_global_rest(ba).affine_inverse() * repouso[i]
		var rb := esqueleto.get_bone_global_rest(bb).affine_inverse() * repouso[i]
		var v := [ra.x, ra.y, ra.z, float(ba), rb.x, rb.y, rb.z, float(bb),
			peso_b[i], folga[i], puxa[i], 0.0 if preso[i] != 0 else 1.0,
			comp.call(i, 1, 0), comp.call(i, -1, 0), comp.call(i, 0, 1), comp.call(i, 0, -1),
			comp.call(i, 1, 1), comp.call(i, -1, 1), comp.call(i, 1, -1), comp.call(i, -1, -1),
			comp.call(i, 2, 0), comp.call(i, -2, 0), comp.call(i, 0, 2), comp.call(i, 0, -2),
			float(ancora[i]),
			repouso[i].distance_to(repouso[ancora[i]]) if ancora[i] >= 0 else 0.0,
			0.0, float(existe[i])]
		for k in FIXO_FLOATS:
			pc.fixo[o + k] = v[k]

	# O sinal da normal: para fora do centro da peca.
	var centro := Vector3.ZERO
	for p in repouso:
		centro += p
	centro /= float(n)
	var amostra := (h / 2) * w + w / 4
	var dx := repouso[idx.call(amostra % w + 1, amostra / w)] - repouso[idx.call(amostra % w - 1, amostra / w)] \
		if periodico else repouso[amostra + 1] - repouso[amostra - 1]
	var dy := repouso[amostra + w] - repouso[amostra - w]
	pc.sinal = 1 if dx.cross(dy).dot(repouso[amostra] - centro) >= 0.0 else -1

	pc.params = PackedByteArray()
	pc.params.resize(48)
	pc.params.encode_s32(0, w)
	pc.params.encode_s32(4, h)
	pc.params.encode_s32(8, 1 if periodico else 0)
	pc.params.encode_s32(12, pc.sinal)
	var pf := [float(opcoes.get("amortecimento", 1.4)), float(opcoes.get("espessura", 0.008)),
		float(opcoes.get("atrito", 0.35)), float(opcoes.get("dobra", 0.25)),
		float(opcoes.get("aerodinamica", 0.9)), float(opcoes.get("cisalha", 0.6)),
		float(opcoes.get("compressao", 0.15)), float(_mascara(opcoes.get("sem_colisor", [])))]
	for k in 8:
		pc.params.encode_float(16 + k * 4, pf[k])
	if opcoes.has("boca"):
		pc.material_boca = opcoes["boca"]

	pc.set_meta(&"barra", opcoes.get("barra", []))
	pc.sem_malha = bool(opcoes.get("sem_malha", false))
	if not pc.sem_malha:
		_montar_malha(pc, repouso, existe)
	pecas.append(pc)
	for chave: String in opcoes:
		if pc.material != null and chave in ["cor_pano", "cor_lama", "cor_forro", "molhado",
				"relevo", "buracos", "desfiado", "lama_altura"]:
			pc.material.set_shader_parameter(chave, opcoes[chave])
	return pc


## Os indices de colisor que a peca nao ve, em bits (cabe no float do push
## constant: 24 colisores).
static func _mascara(indices: Array) -> int:
	var m := 0
	for i: int in indices:
		if i >= 0 and i < COLISORES:
			m |= 1 << i
	return m


## `material` le as posicoes da peca `pc` pelo parametro `parametro` (a
## `BatinaAAA`, que desenha em cima de pecas sem malha).
func ligar_textura(pc: PecaDePano, material: ShaderMaterial, parametro: StringName) -> void:
	pc.ligacoes.append([material, parametro])
	var t: Texture2D = pc.tex_pos if pc.tex_pos != null else pc.itex_pos
	if t != null:
		material.set_shader_parameter(parametro, t)


## `mi` anda com o tronco (a caixa de corte: os vertices vem da textura) e o
## `material` recebe a altura do chao, como as malhas das pecas.
func acompanhar(mi: MeshInstance3D, material: ShaderMaterial) -> void:
	mi.top_level = true
	add_child(mi)
	_acompanham.append([mi, material])


## A malha: a grade subdividida, com a coordenada de grade no UV2, o pano em
## metros no UV e a distancia ate a borda livre (a barra, a boca do capuz) no
## CUSTOM0.
func _montar_malha(pc: PecaDePano, repouso: PackedVector3Array, existe: PackedByteArray) -> void:
	var w := pc.w
	var h := pc.h
	var colunas := w if pc.periodico else w - 1
	# Comprimento de pano ao longo da linha e da coluna, no repouso.
	var u_len := PackedFloat32Array()
	u_len.resize((colunas + 1) * h)
	var v_len := PackedFloat32Array()
	v_len.resize((colunas + 1) * h)
	for y in h:
		var acc := 0.0
		for x in colunas + 1:
			if x > 0:
				acc += repouso[y * w + (x - 1) % w].distance_to(repouso[y * w + x % w])
			u_len[y * (colunas + 1) + x] = acc
	for x in colunas + 1:
		var acc := 0.0
		for y in h:
			if y > 0:
				acc += repouso[(y - 1) * w + x % w].distance_to(repouso[y * w + x % w])
			v_len[y * (colunas + 1) + x] = acc
	# Distancia ate a borda livre (a boca do capuz, a barra), pelo pano:
	# zero na particula de borda e relaxada pela grade em varreduras, com o
	# comprimento de repouso de cada ligacao. O(n), e nao O(n^2).
	var borda := PackedFloat32Array()
	borda.resize(w * h)
	var barra: Array = pc.get_meta(&"barra") if pc.has_meta(&"barra") else []
	for i in w * h:
		borda[i] = 9.0
		if existe[i] == 0:
			continue
		var x := i % w
		var y := i / w
		if y in barra:
			borda[i] = 0.0
			continue
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := posmod(x + d.x, w) if pc.periodico else x + d.x
			var ny := y + d.y
			if ny >= 0 and ny < h and nx >= 0 and nx < w and existe[ny * w + nx] == 0:
				borda[i] = 0.0
	for _rodada in 3:
		for i in w * h:
			_relaxar(borda, repouso, pc, i)
		for k in w * h:
			_relaxar(borda, repouso, pc, w * h - 1 - k)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_R_FLOAT)
	var s := SUBDIVIDE
	var larg := colunas * s + 1
	var alt := (h - 1) * s + 1
	for gy in alt:
		for gx in larg:
			var fx := float(gx) / float(s)
			var fy := float(gy) / float(s)
			var x0 := mini(int(fx), colunas - 1)
			var y0 := mini(int(fy), h - 2)
			var tx := fx - x0
			var ty := fy - y0
			var l := colunas + 1
			var ul := lerpf(lerpf(u_len[y0 * l + x0], u_len[y0 * l + x0 + 1], tx),
				lerpf(u_len[(y0 + 1) * l + x0], u_len[(y0 + 1) * l + x0 + 1], tx), ty)
			var vl := lerpf(lerpf(v_len[y0 * l + x0], v_len[y0 * l + x0 + 1], tx),
				lerpf(v_len[(y0 + 1) * l + x0], v_len[(y0 + 1) * l + x0 + 1], tx), ty)
			var b00 := borda[y0 * w + x0 % w]
			var b10 := borda[y0 * w + (x0 + 1) % w]
			var b01 := borda[(y0 + 1) * w + x0 % w]
			var b11 := borda[(y0 + 1) * w + (x0 + 1) % w]
			var bd := lerpf(lerpf(b00, b10, tx), lerpf(b01, b11, tx), ty)
			st.set_uv(Vector2(ul, vl) / TILE_M)
			st.set_uv2(Vector2(fx, fy))
			st.set_custom(0, Color(bd, 0.0, 0.0, 0.0))
			st.add_vertex(Vector3.ZERO)
	for gy in alt - 1:
		for gx in larg - 1:
			# A celula de grade em que este quadradinho cai: so desenha se as
			# quatro particulas existem.
			var cx := gx / s
			var cy := gy / s
			var ok := true
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				if existe[(cy + d.y) * w + (cx + d.x) % w] == 0:
					ok = false
			if not ok:
				continue
			var a := gy * larg + gx
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + larg)
			st.add_index(a + 1)
			st.add_index(a + larg + 1)
			st.add_index(a + larg)
	var malha := st.commit()
	# Os vertices vem da textura, em coordenada de mundo: a caixa e a do corpo.
	malha.custom_aabb = AABB(Vector3(-1.8, -1.6, -1.8), Vector3(3.6, 3.4, 3.6))
	var mi := MeshInstance3D.new()
	mi.name = pc.nome
	mi.mesh = malha
	mi.top_level = true
	if _shader_pano == null:
		_shader_pano = Shader.new()
		_shader_pano.code = PANO_SHADER
		_mapa = load(MAPA) as Texture2D
		_mapa_n = load(MAPA_N) as Texture2D
	pc.material = ShaderMaterial.new()
	pc.material.shader = _shader_pano
	pc.material.set_shader_parameter("grade", Vector3i(w, h, 1 if pc.periodico else 0))
	pc.material.set_shader_parameter("mapa", _mapa)
	pc.material.set_shader_parameter("mapa_n", _mapa_n)
	pc.material.set_shader_parameter("boca", pc.material_boca)
	mi.material_override = pc.material
	pc.instancia = mi
	add_child(mi)


static func _relaxar(borda: PackedFloat32Array, repouso: PackedVector3Array, pc: PecaDePano,
		i: int) -> void:
	var x := i % pc.w
	var y := i / pc.w
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := posmod(x + d.x, pc.w) if pc.periodico else x + d.x
		var ny := y + d.y
		if ny < 0 or ny >= pc.h or nx < 0 or nx >= pc.w:
			continue
		var j := ny * pc.w + nx
		var c := borda[j] + repouso[i].distance_to(repouso[j])
		if c < borda[i]:
			borda[i] = c


func _ready() -> void:
	if esqueleto == null:
		return
	_ossos_antes.resize(OSSOS)
	for i in OSSOS:
		_ossos_antes[i] = _osso(i)
	if _rd != null:
		RenderingServer.call_on_render_thread(_criar_na_placa)
	else:
		for pc in pecas:
			pc.img_pos = Image.create_empty(pc.w, pc.h, false, Image.FORMAT_RGBAF)
			pc.img_nor = Image.create_empty(pc.w, pc.h, false, Image.FORMAT_RGBAF)
			pc.itex_pos = ImageTexture.create_from_image(pc.img_pos)
			pc.itex_nor = ImageTexture.create_from_image(pc.img_nor)
			if pc.material != null:
				pc.material.set_shader_parameter("posicoes", pc.itex_pos)
				pc.material.set_shader_parameter("normais", pc.itex_nor)
			for l: Array in pc.ligacoes:
				(l[0] as ShaderMaterial).set_shader_parameter(l[1], pc.itex_pos)


func _criar_na_placa() -> void:
	if not _pipeline_rid.is_valid():
		var src := RDShaderSource.new()
		src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		src.source_compute = COMPUTE
		var spirv := _rd.shader_compile_spirv_from_source(src)
		if spirv.compile_error_compute != "":
			push_error("PanoGPU: " + spirv.compile_error_compute)
			return
		_shader_rid = _rd.shader_create_from_spirv(spirv, "PanoGPU")
		_pipeline_rid = _rd.compute_pipeline_create(_shader_rid)
	_usuarios += 1
	var qb := _quadro.to_byte_array()
	_quadro_rid = _rd.storage_buffer_create(qb.size(), qb)
	for pc in pecas:
		var est := PackedFloat32Array()
		est.resize(pc.n * 8)
		var eb := est.to_byte_array()
		pc.estado_rid = _rd.storage_buffer_create(eb.size(), eb)
		var fb := pc.fixo.to_byte_array()
		pc.fixo_rid = _rd.storage_buffer_create(fb.size(), fb)
		pc.pos_rid = _imagem(pc.w, pc.h, RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)
		pc.nor_rid = _imagem(pc.w, pc.h, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		var us: Array[RDUniform] = []
		for b: Array in [[0, pc.estado_rid, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER],
				[1, pc.fixo_rid, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER],
				[2, _quadro_rid, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER],
				[3, pc.pos_rid, RenderingDevice.UNIFORM_TYPE_IMAGE],
				[4, pc.nor_rid, RenderingDevice.UNIFORM_TYPE_IMAGE]]:
			var u := RDUniform.new()
			u.binding = int(b[0])
			u.uniform_type = int(b[2])
			u.add_id(b[1])
			us.append(u)
		pc.conjunto_rid = _rd.uniform_set_create(us, _shader_rid, 0)


func _imagem(w: int, h: int, formato: int) -> RID:
	var tf := RDTextureFormat.new()
	tf.format = formato
	tf.width = w
	tf.height = h
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	return _rd.texture_create(tf, RDTextureView.new(), [])


## So na morte do no, e nao ao sair da arvore: a abertura tira o padre da cena
## e o poe de volta (na janela), e `_ready` nao roda de novo. Liberar no
## `_exit_tree` matava o pano dali em diante.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_liberar_tudo()


func _liberar_tudo() -> void:
	for pc in pecas:
		if pc.tex_pos != null:
			pc.tex_pos.texture_rd_rid = RID()
			pc.tex_nor.texture_rd_rid = RID()
	if _rd != null and _quadro_rid.is_valid():
		RenderingServer.call_on_render_thread(_liberar.bind(_rids()))
		_quadro_rid = RID()


func _rids() -> Array[RID]:
	var r: Array[RID] = []
	for pc in pecas:
		r.append_array([pc.conjunto_rid, pc.estado_rid, pc.fixo_rid, pc.pos_rid, pc.nor_rid])
		pc.conjunto_rid = RID()
	r.append(_quadro_rid)
	return r


static func _liberar(rids: Array[RID]) -> void:
	var rd := RenderingServer.get_rendering_device()
	# O conjunto de uniformes vai antes dos buffers de que depende.
	for r in rids:
		if r.is_valid():
			rd.free_rid(r)
	_usuarios -= 1
	if _usuarios <= 0 and _pipeline_rid.is_valid():
		rd.free_rid(_pipeline_rid)
		rd.free_rid(_shader_rid)
		_pipeline_rid = RID()
		_shader_rid = RID()


## O osso `i` no mundo, sem escala (a cabeca esta encolhida a 0,001, ver
## `MonstroDaEstrada`).
func _osso(i: int) -> Transform3D:
	var t := esqueleto.global_transform * esqueleto.get_bone_global_pose(i)
	return Transform3D(t.basis.orthonormalized(), t.origin)


## Reposiciona tudo no repouso no proximo quadro (depois de teleporte).
func reiniciar() -> void:
	_reiniciar = true


func _process(delta: float) -> void:
	if esqueleto == null or pecas.is_empty():
		return
	var corpo := get_parent() as Node3D
	if corpo != null and not corpo.is_visible_in_tree():
		_reiniciar = true
		return
	var origem := esqueleto.global_transform.origin
	# A caixa de corte vai com o tronco, e nao com a raiz: na janela a pose
	# leva o corpo inteiro para longe dos pes.
	var tronco := _osso(1).origin
	for pc in pecas:
		if pc.instancia != null:
			pc.instancia.global_transform = Transform3D(Basis(), tronco)
			pc.material.set_shader_parameter("chao", origem.y)
	for a: Array in _acompanham:
		(a[0] as Node3D).global_transform = Transform3D(Basis(), tronco)
		(a[1] as ShaderMaterial).set_shader_parameter("chao", origem.y)
	if _ultima_origem != Vector3.INF and origem.distance_to(_ultima_origem) > TELEPORTE:
		_reiniciar = true
	_ultima_origem = origem
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to(origem) > LONGE and not _reiniciar:
		return
	var dt := minf(delta, DT_MAX)
	if dt <= 0.0:
		return
	_tempo += dt

	if _rd == null:
		_seguir_repouso_na_cpu()
		return
	if not _quadro_rid.is_valid() or not pecas[0].conjunto_rid.is_valid():
		return
	for pc in pecas:
		if pc.tex_pos == null:
			pc.tex_pos = Texture2DRD.new()
			pc.tex_pos.texture_rd_rid = pc.pos_rid
			pc.tex_nor = Texture2DRD.new()
			pc.tex_nor.texture_rd_rid = pc.nor_rid
			if pc.material != null:
				pc.material.set_shader_parameter("posicoes", pc.tex_pos)
				pc.material.set_shader_parameter("normais", pc.tex_nor)
			for l: Array in pc.ligacoes:
				(l[0] as ShaderMaterial).set_shader_parameter(l[1], pc.tex_pos)

	var q := _quadro
	var reiniciando := _reiniciar or _col_antes.size() != _colisores.size() * 2
	for i in OSSOS:
		var agora := _osso(i)
		var antes := agora if _reiniciar else _ossos_antes[i]
		_por_matriz(q, i * 16, agora)
		_por_matriz(q, (OSSOS + i) * 16, antes)
		_ossos_antes[i] = agora
	var base := OSSOS * 32
	_col_antes.resize(_colisores.size() * 2)
	for c in COLISORES:
		var o := base + c * 4
		var ob := base + COLISORES * 4 + c * 4
		var o0 := base + COLISORES * 8 + c * 4
		var ob0 := base + COLISORES * 12 + c * 4
		if c < _colisores.size():
			var col: Array = _colisores[c]
			var t := _osso(int(col[0]))
			var a: Vector3 = t * (col[1] as Vector3)
			var b: Vector3 = t * (col[2] as Vector3)
			var a0 := a if reiniciando else _col_antes[c * 2]
			var b0 := b if reiniciando else _col_antes[c * 2 + 1]
			_col_antes[c * 2] = a
			_col_antes[c * 2 + 1] = b
			for par: Array in [[o, a, float(col[3])], [ob, b, 0.0], [o0, a0, 0.0], [ob0, b0, 0.0]]:
				var i0: int = par[0]
				var v: Vector3 = par[1]
				q[i0] = v.x
				q[i0 + 1] = v.y
				q[i0 + 2] = v.z
				q[i0 + 3] = float(par[2])
	var g := base + COLISORES * 16
	q[g] = dt
	q[g + 1] = GRAVIDADE
	q[g + 2] = origem.y
	q[g + 3] = _tempo
	q[g + 4] = vento.x
	q[g + 5] = vento.y
	q[g + 6] = vento.z
	q[g + 7] = rajada
	if cam != null and raio_da_lente > 0.0:
		var cp := cam.global_position
		q[g + 8] = cp.x
		q[g + 9] = cp.y
		q[g + 10] = cp.z
		q[g + 11] = raio_da_lente
	else:
		q[g + 11] = 0.0
	q[g + 12] = float(_colisores.size())
	q[g + 13] = 1.0 if _reiniciar else 0.0
	q[g + 14] = float(SUBPASSOS)
	q[g + 15] = float(ITERACOES)
	_reiniciar = false
	RenderingServer.call_on_render_thread(_simular.bind(q.to_byte_array()))


func _simular(bytes: PackedByteArray) -> void:
	if not _quadro_rid.is_valid():
		return
	_rd.buffer_update(_quadro_rid, 0, bytes.size(), bytes)
	var cl := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _pipeline_rid)
	for pc in pecas:
		_rd.compute_list_bind_uniform_set(cl, pc.conjunto_rid, 0)
		_rd.compute_list_set_push_constant(cl, pc.params, pc.params.size())
		_rd.compute_list_dispatch(cl, 1, 1, 1)
	_rd.compute_list_end()
	if not _avisou:
		_avisou = true
		print("[PanoGPU] simulando %d pecas na placa" % pecas.size())


static func _por_matriz(q: PackedFloat32Array, o: int, t: Transform3D) -> void:
	# mat4 do GLSL e por coluna.
	var b := t.basis
	q[o] = b.x.x
	q[o + 1] = b.x.y
	q[o + 2] = b.x.z
	q[o + 3] = 0.0
	q[o + 4] = b.y.x
	q[o + 5] = b.y.y
	q[o + 6] = b.y.z
	q[o + 7] = 0.0
	q[o + 8] = b.z.x
	q[o + 9] = b.z.y
	q[o + 10] = b.z.z
	q[o + 11] = 0.0
	q[o + 12] = t.origin.x
	q[o + 13] = t.origin.y
	q[o + 14] = t.origin.z
	q[o + 15] = 1.0


## Sem placa: o pano no repouso esfolado, sem fisica. Normal por diferenca.
func _seguir_repouso_na_cpu() -> void:
	var ossos: Array[Transform3D] = []
	for i in OSSOS:
		ossos.append(_osso(i))
	for pc in pecas:
		var pos := PackedVector3Array()
		pos.resize(pc.n)
		for i in pc.n:
			var o := i * FIXO_FLOATS
			var a := ossos[int(pc.fixo[o + 3])] * Vector3(pc.fixo[o], pc.fixo[o + 1], pc.fixo[o + 2])
			var b := ossos[int(pc.fixo[o + 7])] * Vector3(pc.fixo[o + 4], pc.fixo[o + 5], pc.fixo[o + 6])
			pos[i] = a.lerp(b, pc.fixo[o + 8])
		for i in pc.n:
			var x := i % pc.w
			var y := i / pc.w
			var xr := posmod(x + 1, pc.w) if pc.periodico else mini(x + 1, pc.w - 1)
			var xl := posmod(x - 1, pc.w) if pc.periodico else maxi(x - 1, 0)
			var du := pos[y * pc.w + xr] - pos[y * pc.w + xl]
			var dv := pos[mini(y + 1, pc.h - 1) * pc.w + x] - pos[maxi(y - 1, 0) * pc.w + x]
			var nn := (du.cross(dv) * float(pc.sinal)).normalized()
			pc.img_pos.set_pixel(x, y, Color(pos[i].x, pos[i].y, pos[i].z, 1.0))
			var e := _oct(nn)
			pc.img_nor.set_pixel(x, y, Color(e.x, e.y, 0.0, 0.0))
		pc.itex_pos.update(pc.img_pos)
		pc.itex_nor.update(pc.img_nor)


## A normal em octaedro (o shader do pano le assim; ver `oct` no compute).
static func _oct(n: Vector3) -> Vector2:
	n /= absf(n.x) + absf(n.y) + absf(n.z)
	if n.z >= 0.0:
		return Vector2(n.x, n.y)
	return Vector2((1.0 - absf(n.y)) * (1.0 if n.x >= 0.0 else -1.0),
		(1.0 - absf(n.x)) * (1.0 if n.y >= 0.0 else -1.0))

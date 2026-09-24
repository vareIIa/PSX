## A treva que entra no carro: fumaca preta de verdade, em volume.
##
## Por que existe
## --------------
## A primeira treva era de particulas (discos pretos com ruido, em billboard) e
## um recorte 2D nas bordas da tela. A meio metro da lente as duas coisas se
## denunciam: o disco e um disco, gira no lugar e corta reto no banco; o
## recorte e desenho na frente do vidro, e nao ar dentro do carro. Fumaca e
## volume — tem fundo, se enrola, fica mais densa rente ao tapete, engole o que
## esta atras e deixa passar o que esta perto.
##
## Como e feita
## ------------
## Uma caixa do tamanho da cabine, desenhada pelas faces de DENTRO (a lente
## esta dentro dela), e um raio por pixel que anda da lente ate a primeira
## coisa opaca (o mapa de profundidade) ou a parede da caixa. Em cada passo a
## densidade sai de ruido 3D fractal torcido por outro ruido (as volutas) que
## anda com o tempo, e e recortada por uma frente que nasce em `origem` e
## avanca com `cobre`: a fumaca entra pela fresta, rente ao chao (`teto` sobe
## depois), e cobre o carro. A luz da tela do telefone (`luz_*`) acende a borda
## da fumaca de azul frio, o resto e preto que tapa.
##
## Tres coisas nao podem sumir nela: a lente (`olho_livre` abre um vazio em
## volta da camera), o telefone caido (`fone`, `fone_raio`: a tela tem de ser
## lida) e a borda da caixa (que sairia como um plano reto).
##
## Tudo em coordenada deste no, que nao pode ter escala.
class_name FumacaNegra
extends MeshInstance3D

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled,
	cull_front, shadows_disabled, fog_disabled;

uniform sampler2D profundidade : hint_depth_texture, filter_nearest;
uniform vec3 meia = vec3(0.8, 0.6, 1.2);
uniform vec3 origem = vec3(0.7, -0.5, 0.0);
uniform float alcance = 2.4;
uniform float cobre : hint_range(0.0, 1.0) = 0.0;
uniform float teto = -0.2;
uniform float densidade = 16.0;
uniform float limiar = 0.6;
uniform float escala = 3.2;
uniform vec3 corre = vec3(-0.10, 0.035, 0.05);
uniform vec3 fone = vec3(100.0);
uniform float fone_raio = 0.055;
// O raio da poca de luz em volta do telefone e o quanto a fumaca ralea nela.
uniform float poca = 0.5;
uniform float poca_rala = 0.2;
uniform float olho_livre = 0.32;
uniform vec3 luz_pos = vec3(100.0);
uniform vec3 luz_cor = vec3(0.35, 0.55, 1.0);
uniform float luz_forca = 0.0;
uniform vec3 luz2_pos = vec3(100.0);
uniform vec3 luz2_cor = vec3(1.0, 0.12, 0.06);
uniform float luz2_forca = 0.0;
uniform vec3 ambiente = vec3(0.004, 0.0045, 0.006);
// Quanto da luz a fumaca devolve: pouco. Preta e o que ela e; a luz so acende
// a borda de quem esta perto da tela.
uniform float espalha = 0.28;
// Com o raio recortado so no trecho que passa pela fumaca (ver `fragment`),
// ate trinta passos dao mais amostra DENTRO dela do que os 44 de antes davam
// espalhados pela cabine. E nao mais que um a cada `passo_min` metros: no chao,
// com a lente dentro dela, o trecho e curto, e trinta passos em 20 cm eram
// placa gasta sem nada novo para ver.
uniform int passos = 30;
uniform int passos_min = 8;
uniform float passo_min = 0.035;

varying vec3 local;
varying vec3 olho_local;

void vertex() {
	local = VERTEX;
	olho_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

// Ruido de valor numa leitura so. A `rede` tem um valor sorteado por celula
// (REDE^3 celulas, quatro canais independentes), e o filtro linear do hardware
// interpola entre as oito celulas vizinhas no ponto ja remapeado pela curva
// suave: sai o mesmo ruido de antes, que custava oito sorteios e sete misturas
// por chamada. Era o custo inteiro da fumaca: com a lente dentro dela, no chao,
// cada pixel em 4K fazia 30 passos de oito ruidos, 14,6 ms de placa.
uniform sampler3D rede : filter_linear, repeat_enable;
const float REDE = 32.0;

vec4 ruido4(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return textureLod(rede, (i + f + 0.5) / REDE, 0.0);
}

float ruido(vec3 x) {
	return ruido4(x).r;
}

// Quatro oitavas: a quinta pesava 1/32 e nao aparecia, e custava um quinto do
// fractal em cada passo de cada pixel.
float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * ruido(p);
		p = p * 2.02 + vec3(1.7, -3.1, 2.3);
		a *= 0.5;
	}
	return s;
}

// Entrada e saida do raio na caixa (em t), ou t0 > t1 se nao corta.
vec2 caixa(vec3 ro, vec3 rd) {
	vec3 inv = 1.0 / rd;
	vec3 a = (-meia - ro) * inv;
	vec3 b = (meia - ro) * inv;
	vec3 mn = min(a, b);
	vec3 mx = max(a, b);
	return vec2(max(max(mn.x, mn.y), mn.z), min(min(mx.x, mx.y), mx.z));
}

// O quanto as volutas empurram a frente (x 0,55) e o topo (y 0,35), no maximo:
// o ruido vai de -0,5 a 0,5.
const float EMPURRA_FRENTE = 0.28;
const float EMPURRA_TOPO = 0.18;

float densidade_em(vec3 p, float t) {
	// Fora da frente ou acima do topo, mesmo com a voluta mais funda, nao ha
	// fumaca: sai antes dos ruidos, que sao o custo inteiro do passo.
	float d0 = length((p - origem) * vec3(1.0, 1.7, 1.0));
	float frente = cobre * alcance;
	if (d0 - EMPURRA_FRENTE > frente + 0.05 || p.y - EMPURRA_TOPO > teto + 0.22) {
		return 0.0;
	}
	// A borda da caixa esmaece: sem isto a fumaca corta num plano reto.
	vec3 dentro = meia - abs(p);
	float borda = smoothstep(0.0, 0.12, min(min(dentro.x, dentro.y), dentro.z));
	// As volutas: um ruido grosso torce o ponto antes do ruido fino.
	// Uma leitura para os tres eixos: cada um num canal proprio da rede.
	vec3 w = ruido4(p * 1.25 + vec3(0.04, 0.11, -0.05) * t).gba - 0.5;
	// A frente: nasce na fresta e avanca rente ao chao (achatada em y).
	float mascara = 1.0 - smoothstep(frente - 0.40, frente + 0.05, d0 + w.x * 0.55);
	float alto = 1.0 - smoothstep(teto - 0.20, teto + 0.22, p.y + w.y * 0.35);
	float m = mascara * alto * borda;
	if (m <= 0.001) {
		return 0.0;
	}
	vec3 q = p + w * 0.62;
	// O fractal de valor tem pouco contraste (fica quase todo em 0,4-0,6): sem
	// esticar, a fumaca saia um veu liso, e fumaca e fio e buraco. Por cima, as
	// cristas de um ruido mais largo sao os fiapos que se enrolam.
	float n = fbm(q * escala + corre * t * escala);
	n = clamp((n - 0.5) * 3.2 + 0.5, 0.0, 1.0);
	float r = 1.0 - abs(ruido(q * escala * 0.55 - corre * t * 2.0) * 2.0 - 1.0);
	n = n * 0.72 + r * r * 0.42;
	float d = smoothstep(limiar, limiar + 0.26, n) * densidade * m;
	// O telefone e a lente ficam livres.
	// Em volta do telefone ela ralea, e no aparelho some: o telefone e a mao
	// ficam numa poca de luz, e a treva fecha em volta.
	float df = length(p - fone);
	d *= smoothstep(fone_raio, fone_raio * 2.6, df) * mix(poca_rala, 1.0, smoothstep(0.12, poca, df));
	d *= smoothstep(olho_livre * 0.45, olho_livre, length(p - olho_local));
	return d;
}

void fragment() {
	vec3 ro = olho_local;
	vec3 rd = normalize(local - olho_local);
	vec2 tt = caixa(ro, rd);
	float t0 = max(tt.x, 0.02);
	float t1 = tt.y;
	// Ate a primeira coisa opaca.
	float z = texture(profundidade, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	t1 = min(t1, length(v.xyz / v.w));
	// E so onde pode haver fumaca: abaixo do topo dela (rente ao chao, quase o
	// tempo todo) e dentro do elipsoide da frente que avanca. Os passos vao todos
	// para o trecho do raio que passa pela fumaca; antes eles se espalhavam pela
	// cabine inteira, e a 4K era o que mais custava depois da batida.
	float topo = teto + 0.22 + EMPURRA_TOPO;
	if (abs(rd.y) > 1e-4) {
		float ty = (topo - ro.y) / rd.y;
		if (ro.y > topo) {
			if (rd.y >= 0.0) { discard; }
			t0 = max(t0, ty);
		} else if (rd.y > 0.0) {
			t1 = min(t1, ty);
		}
	} else if (ro.y > topo) {
		discard;
	}
	vec3 s = vec3(1.0, 1.7, 1.0);
	vec3 qo = (ro - origem) * s;
	vec3 qd = rd * s;
	float raio = cobre * alcance + 0.05 + EMPURRA_FRENTE;
	float qa = dot(qd, qd);
	float qb = dot(qo, qd);
	float qc = dot(qo, qo) - raio * raio;
	float disc = qb * qb - qa * qc;
	if (disc <= 0.0) {
		discard;
	}
	float sq = sqrt(disc);
	t0 = max(t0, (-qb - sq) / qa);
	t1 = min(t1, (-qb + sq) / qa);
	if (t1 <= t0) {
		discard;
	}
	int n = clamp(int(ceil((t1 - t0) / passo_min)), passos_min, passos);
	float dt = (t1 - t0) / float(n);
	// Deslocamento por pixel (ruido de gradiente intercalado): troca as faixas
	// do passo fixo por grao fino.
	float j = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float t = t0 + dt * j;
	float transm = 1.0;
	vec3 cor = vec3(0.0);
	for (int i = 0; i < n; i++) {
		vec3 p = ro + rd * t;
		float d = densidade_em(p, TIME);
		if (d > 0.0) {
			float a = exp(-d * dt);
			float dl = length(p - luz_pos);
			float dl2 = length(p - luz2_pos);
			vec3 luz = (luz_cor * luz_forca / (1.0 + dl * dl * 90.0)
				+ luz2_cor * luz2_forca / (1.0 + dl2 * dl2 * 40.0)) * espalha + ambiente;
			cor += transm * (1.0 - a) * luz;
			transm *= a;
			if (transm < 0.01) {
				break;
			}
		}
		t += dt;
	}
	ALBEDO = cor;
	ALPHA = 1.0 - transm;
}
"""

## O quanto a fumaca ja entrou (0 nada, 1 o carro todo).
var cobre: float = 0.0:
	set(v):
		cobre = clampf(v, 0.0, 1.0)
		_uniforme(&"cobre", cobre)
		visible = cobre > 0.001
## A altura do topo da fumaca, em y deste no.
var teto: float = -0.2:
	set(v):
		teto = v
		_uniforme(&"teto", teto)

var _mat: ShaderMaterial
static var _shader: Shader
static var _rede: ImageTexture3D

## Lado da rede de sorteios do ruido, em celulas (o `REDE` do shader).
const REDE := 32
## A mesma rede em toda execucao: a fumaca nao muda de desenho de uma para outra.
const SEMENTE_DA_REDE := 7331


## Uma fumaca na caixa de meia medida `meia` centrada neste no, nascendo em
## `origem` (coordenada deste no) e alcancando `alcance` metros com `cobre` 1.
static func criar(meia: Vector3, origem: Vector3, alcance: float) -> FumacaNegra:
	var f := FumacaNegra.new()
	f.name = "FumacaNegra"
	var caixa := BoxMesh.new()
	caixa.size = meia * 2.0
	f.mesh = caixa
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_rede = _criar_rede()
	f._mat = ShaderMaterial.new()
	f._mat.shader = _shader
	f._mat.set_shader_parameter(&"rede", _rede)
	# Depois dos vidros: o vidro refrata a copia opaca da tela, e desenhado por
	# cima apagaria a fumaca que esta entre ele e a lente.
	f._mat.render_priority = 20
	f.material_override = f._mat
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	f.extra_cull_margin = 2.0
	f._mat.set_shader_parameter(&"meia", meia)
	f._mat.set_shader_parameter(&"origem", origem)
	f._mat.set_shader_parameter(&"alcance", alcance)
	f.cobre = 0.0
	return f


## Um valor sorteado por celula e por canal, bytes crus (sem curva de cor).
static func _criar_rede() -> ImageTexture3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE_DA_REDE
	var fatias: Array[Image] = []
	for z in REDE:
		var bytes := PackedByteArray()
		bytes.resize(REDE * REDE * 4)
		for i in REDE * REDE:
			bytes.encode_u32(i * 4, rng.randi())
		fatias.append(Image.create_from_data(REDE, REDE, false, Image.FORMAT_RGBA8, bytes))
	var t := ImageTexture3D.new()
	t.create(Image.FORMAT_RGBA8, REDE, REDE, REDE, false, fatias)
	return t


## Onde fica o telefone (global): a fumaca abre em volta dele e a tela a acende.
func seguir_fone(global: Vector3, forca: float) -> void:
	var p := global_transform.affine_inverse() * global
	_mat.set_shader_parameter(&"fone", p)
	_mat.set_shader_parameter(&"luz_pos", p + Vector3.UP * 0.05)
	_mat.set_shader_parameter(&"luz_forca", forca)


## A segunda luz (a vermelha do painel), em coordenada global.
func luz_vermelha(global: Vector3, forca: float) -> void:
	_mat.set_shader_parameter(&"luz2_pos", global_transform.affine_inverse() * global)
	_mat.set_shader_parameter(&"luz2_forca", forca)


func ajustar(nome: StringName, valor: Variant) -> void:
	_mat.set_shader_parameter(nome, valor)


func _uniforme(nome: StringName, valor: Variant) -> void:
	if _mat != null:
		_mat.set_shader_parameter(nome, valor)

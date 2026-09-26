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
	return p + (T * o.x + B * o.y + N * o.z) * escala * recolhe;
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
	_shader.code = SHADER
	return _malha != null


## Onde o crucifixo encosta, no espaco do esqueleto (pessoa na escala `s`): a
## frente da murca no repouso. `ancora_e`/`ancora_d` na gola (a linha presa da
## murca, a ~27 graus da frente de cada lado), `argola` onde a cruz pendura (a
## frente da murca no meio do peito) e `capsulas` ([a, b, raio]) deitadas na
## frente da murca, de cima a baixo: e nelas que a corrente e a cruz batem.
static func peito(s: float) -> Dictionary:
	if not _carregar() or _grades.size() < 2:
		return {}
	var g: Dictionary = _grades[1]
	var w := int(g["w"])
	var r: Array = g["repouso"]
	var pega := func(j: int, i: int) -> Vector3:
		var p: Array = r[j * w + posmod(i, w)]
		return Vector3(p[0], p[1], p[2]) * s
	var col := roundi(float(w) * 0.075)
	var capsulas: Array = []
	var raio := 0.10 * s
	# A frente de cada linha e a mediana das colunas do meio (+-25 graus): no
	# meio da murca ha o vao da fita que saiu (mais fundo) e as abas pendem para
	# a frente (a mais saliente deixava a cruz boiando no ar).
	var k := roundi(float(w) * 0.07)
	var frentes: Array[Vector3] = []
	for j: int in range(int(g["h"])):
		var zs: Array[float] = []
		for i in range(-k, k + 1):
			zs.append((pega.call(j, i) as Vector3).z)
		zs.sort()
		var f: Vector3 = pega.call(j, 0)
		frentes.append(Vector3(f.x, f.y, zs[zs.size() / 2]))
	# As ancoras em espelho (a murca de IA nao e simetrica e a corrente e) e um
	# pouco para fora do pano: a corrente sai de cima da gola.
	var d: Vector3 = pega.call(0, col)
	var e: Vector3 = pega.call(0, -col)
	var meio := Vector3((absf(d.x) + absf(e.x)) * 0.5, (d.y + e.y) * 0.5, (d.z + e.z) * 0.5)
	var fora := Vector3(meio.x, 0.0, meio.z).normalized() * 0.015 * s
	# As linhas de cima da frente passam pela beira do capuz (a grade da murca
	# acha a boca dele, 15 a 30 cm na frente do pescoco): a capsula de cima sai
	# do meio entre a gola e a linha 4, e as outras das linhas 4, 7 e 10.
	var topo := (Vector3(0.0, meio.y, meio.z) + frentes[4]) * 0.5
	for f: Vector3 in [topo, frentes[4], frentes[7], frentes[10]]:
		var j := frentes.find(f)
		var lado: Vector3 = pega.call(j if j >= 0 else 4, roundi(float(w) * 0.125))
		var meia := absf(lado.x) * 0.9
		var zc := f.z + raio
		capsulas.append([Vector3(-meia, f.y, zc), Vector3(meia, f.y, zc), raio])
	return {"ancora_d": meio + fora, "ancora_e": Vector3(-meio.x, meio.y, meio.z) + Vector3(-fora.x, 0.0, fora.z),
		"argola": frentes[7] + Vector3(0.0, 0.0, -0.012 * s),
		"capsulas": capsulas}


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
static func vestir(pano: PanoGPU, s: float, papeis: Dictionary = {}) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = _shader
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
		var pc := pano.adicionar(String(g["nome"]), w, h, bool(g["periodico"]), rep,
			PackedInt32Array(g["osso_a"]), PackedInt32Array(g["osso_b"]),
			PackedFloat32Array(g["peso_b"]), fo, PackedFloat32Array(g["puxa"]),
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
	# - em quem sobe no carro (meta `cerco`), a batina: o piso do pano e um
	#   plano so, e em cima do capo ela ficava dura no ar. O `CercoNoCarro`
	#   apagava a malha da peca "Batina" pelo nome, e aqui ela nao tem malha
	#   propria. `--cerco-batina` deixa, como la.
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
	mi.add_child(vigia)
	return mi


static func sumido() -> ShaderMaterial:
	if _sumido == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;
render_mode unshaded, cull_disabled;
" 			+ "void vertex() { POSITION = vec4(0.0, 0.0, 2.0, 1.0); }
void fragment() { discard; }
"
		_sumido = ShaderMaterial.new()
		_sumido.shader = sh
	return _sumido


## Some com a manga do braco trocado e com a batina de quem sobe no carro.
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
	var _com_batina := OS.get_cmdline_user_args().has("--cerco-batina")

	func _process(_delta: float) -> void:
		if esqueleto == null or not is_instance_valid(esqueleto):
			return
		var m := fixo
		var corpo := esqueleto.get_parent()
		if batina >= 0 and corpo != null and corpo.has_meta(&"cerco") and not _com_batina:
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

	## Some com as pecas dos bits de `m` (e volta com as outras).
	func aplicar(m: int) -> void:
		_mascara = m
		var some := {}
		for k: int in superficie:
			var sup := int(superficie[k])
			some[sup] = bool(some.get(sup, false)) or ((m >> k) & 1) != 0
		for sup: int in some:
			malha.set_surface_override_material(sup, BatinaAAA.sumido() if some[sup] else material)

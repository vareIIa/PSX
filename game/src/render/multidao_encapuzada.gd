## A multidao de encapuzados: centenas deles, espalhados na mata ate onde a
## nevoa deixa ver.
##
## Por que existe
## --------------
## Quatorze figuras em volta da batida e tres na beira da estrada liam como um
## grupo — gente que estava ali. O medo que a cena pede e outro: que a mata
## inteira esta cheia deles, que cada tronco tem um atras, que os pontos
## vermelhos continuam no escuro depois do alcance do farol. Isso sao centenas,
## e centenas de `Corpo` (esqueleto, capuz, aura) nao cabem no quadro.
##
## Como e feita
## ------------
## Um `MultiMesh` de uma figura so — batina que arrasta, murca nos ombros,
## bracos compridos com a mao de cera, capuz de ponta com o buraco preto — e
## TUDO que ela faz sai do shader, sem uma linha por quadro no processador:
##
##   - o pescoco estala de pose em pose (quebrado de lado, caido, jogado para
##     tras, girado demais, de ponta-cabeca, reto encarando), num ritmo que cada
##     um sorteia, com o repique do estalo e o tremor fino por cima;
##   - os bracos sobem e caem em trancos, cada um no seu tempo;
##   - um em cada tres pisca: some por um instante e volta;
##   - todos andam devagar para `alvo` (o carro) desde que `anda` comecou a
##     contar, e param a `parada` metros dele.
##
## Os olhos sao outro `MultiMesh`, de pontos em billboard, que refazem a mesma
## conta do pescoco para ficar na cara quando ela estala, e esmaecem com a
## distancia em vez de sumir na nevoa (`some`): e o que faz a multidao parecer
## infinita.
##
## INSTANCE_CUSTOM: x semente (0-1), y rapidez (m/s), z pisca (0 ou 1), w o
## quanto e curvado (0-1). A figura olha para -Z, como o `Corpo`.
class_name MultidaoEncapuzada
extends Node3D

## As medidas da figura, em metros, para uma altura de 1,90.
const PESCOCO := Vector3(0.0, 1.50, 0.0)
const OMBRO := Vector3(0.235, 1.41, 0.0)
const OLHO := Vector3(0.031, 1.665, -0.092)
const CINTURA := 0.92
const PANO := Color(0.028, 0.025, 0.023)
const PELE := Color(0.29, 0.27, 0.25)
## O olho: tamanho do quad e a distancia a partir da qual ele cresce.
const OLHO_QUAD := 0.026
const OLHO_PERTO := 3.5

## A conta do pescoco, dos bracos, da piscada e da caminhada, igual nos dois
## shaders (corpo e olhos).
const COMUM := """
uniform vec3 alvo = vec3(0.0);
uniform float anda = 0.0;
uniform float parada = 2.4;
uniform float tique = 1.0;
uniform float aparece = 1.0;

float h11(float n) { return fract(sin(n * 127.1 + 11.3) * 43758.5453); }
float sinal(float n) { return h11(n) < 0.5 ? -1.0 : 1.0; }

mat3 giro(vec3 e) {
	// YXZ, como o Basis.from_euler do Godot.
	float cx = cos(e.x); float sx = sin(e.x);
	float cy = cos(e.y); float sy = sin(e.y);
	float cz = cos(e.z); float sz = sin(e.z);
	mat3 rx = mat3(vec3(1, 0, 0), vec3(0, cx, sx), vec3(0, -sx, cx));
	mat3 ry = mat3(vec3(cy, 0, -sy), vec3(0, 1, 0), vec3(sy, 0, cy));
	mat3 rz = mat3(vec3(cz, sz, 0), vec3(-sz, cz, 0), vec3(0, 0, 1));
	return ry * rx * rz;
}

vec3 pose_da_cabeca(float s, float i) {
	float q = h11(s * 13.1 + i * 7.31);
	float a = sinal(s * 5.7 + i * 3.1);
	float b = sinal(s * 9.3 + i * 1.7);
	float k = 0.8 + 0.35 * h11(s * 3.3 + i * 5.9);
	if (q < 0.30) return vec3(0.10, 0.18 * a, 1.30 * b) * k;
	if (q < 0.43) return vec3(-1.05, 0.25 * a, 0.30 * b) * k;
	if (q < 0.53) return vec3(1.05, 0.15 * a, 0.35 * b) * k;
	if (q < 0.70) return vec3(0.05, 2.0 * a, 0.25 * b) * k;
	if (q < 0.76) return vec3(0.25, 0.35 * a, 2.45 * b) * k;
	return vec3(0.0, 0.1 * a, 0.08 * b);
}

vec3 pose_do_braco(float s, float i, float lado) {
	float q = h11(s * 17.9 + i * 4.13 + lado * 2.0);
	float a = sinal(s * 2.9 + i * 6.1 + lado);
	float k = 0.8 + 0.3 * h11(s * 8.1 + i * 2.3 + lado);
	if (q < 0.34) return vec3(0.04, 0.0, 0.0);
	if (q < 0.52) return vec3(1.45, 0.0, 0.10 * lado) * k;
	if (q < 0.66) return vec3(0.30, 0.0, 1.25 * lado) * k;
	if (q < 0.78) return vec3(-0.55, 1.2 * a, 0.15 * lado) * k;
	if (q < 0.88) return vec3(2.55, 0.0, 0.30 * lado) * k;
	return vec3(0.20, 2.5 * a, 0.30 * lado) * k;
}

// Pose estalada: entre duas poses sorteadas, o estalo nos primeiros
// milissegundos do intervalo, com repique. O intervalo nao e regular.
vec3 estalando(float s, float t, float ritmo, float qual, float lado) {
	float u = t * ritmo + 0.35 * sin(t * ritmo * 0.7 + s * 9.0) + s * 50.0 + lado * 3.7;
	float i = floor(u);
	float f = fract(u) / ritmo;
	vec3 a;
	vec3 b;
	if (qual < 0.5) {
		a = pose_da_cabeca(s, i - 1.0);
		b = pose_da_cabeca(s, i);
	} else {
		a = pose_do_braco(s, i - 1.0, lado);
		b = pose_do_braco(s, i, lado);
	}
	float k = 1.0 - exp(-f * 90.0) * cos(f * 110.0);
	return mix(a, b, k);
}

vec3 tremor(float s, float t, float amp) {
	return vec3(sin(t * 41.0 + s * 20.0) + 0.5 * sin(t * 19.3 + s * 3.0),
		sin(t * 37.0 + s * 31.0) + 0.5 * sin(t * 23.7 + s),
		sin(t * 47.0 + s * 13.0) + 0.5 * sin(t * 29.1 + s * 7.0)) * amp * 0.67;
}

vec3 cabeca_agora(float s, float t) {
	float ritmo = mix(1.1, 3.2, h11(s * 91.0));
	return (estalando(s, t, ritmo, 0.0, 0.0) + tremor(s, t, 0.035)) * tique;
}

vec3 braco_agora(float s, float t, float lado) {
	float ritmo = mix(1.4, 3.8, h11(s * 71.0 + lado));
	return (estalando(s, t, ritmo, 1.0, lado) + tremor(s + lado, t, 0.025)) * tique;
}

bool piscando(float s, float t, float pisca) {
	if (aparece < 0.5) return true;
	if (pisca < 0.5) return false;
	float u = t * mix(1.2, 2.2, h11(s * 43.0)) + s * 30.0;
	return h11(floor(u) + s * 7.0) < 0.22;
}

// Onde a caminhada ja levou a figura, no espaco do mundo.
vec3 caminhada(vec3 origem, float rapidez) {
	vec3 para = alvo - origem;
	para.y = 0.0;
	float d = length(para);
	if (d < 0.001) return vec3(0.0);
	return para / d * min(rapidez * anda, max(0.0, d - parada));
}

// Curvado: o que esta acima da cintura tomba para a frente em volta dela.
vec3 curvar(vec3 v, float c, float cintura) {
	if (v.y <= cintura) return v;
	float k = smoothstep(cintura, cintura + 0.35, v.y);
	vec3 p = vec3(0.0, cintura, 0.0);
	return p + giro(vec3(-c * 0.55 * k, 0.0, 0.0)) * (v - p);
}
"""

const CORPO_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

%s
uniform vec3 pescoco;
uniform vec3 ombro;
uniform float cintura;

varying float semente;

void vertex() {
	float s = INSTANCE_CUSTOM.x;
	semente = s;
	float t = TIME;
	if (piscando(s, t, INSTANCE_CUSTOM.z)) {
		VERTEX = vec3(0.0);
	} else {
		// UV2.x: 0 corpo, 1 cabeca, 2 braco esquerdo, 3 braco direito.
		float parte = UV2.x;
		if (parte > 0.5 && parte < 1.5) {
			mat3 r = giro(cabeca_agora(s, t));
			VERTEX = pescoco + r * (VERTEX - pescoco);
			NORMAL = r * NORMAL;
		} else if (parte > 1.5) {
			float lado = parte < 2.5 ? -1.0 : 1.0;
			vec3 piv = vec3(ombro.x * lado, ombro.y, ombro.z);
			mat3 r = giro(braco_agora(s, t, lado));
			VERTEX = piv + r * (VERTEX - piv);
			NORMAL = r * NORMAL;
		}
		VERTEX = curvar(VERTEX, INSTANCE_CUSTOM.w, cintura);
		// O andar: um balanco torto de quem arrasta o pe.
		float passo = t * 1.9 + s * 6.28;
		float alto = clamp(VERTEX.y / 1.9, 0.0, 1.0);
		VERTEX.x += sin(passo) * 0.035 * alto * step(0.01, INSTANCE_CUSTOM.y);
		mat3 m = mat3(MODEL_MATRIX);
		VERTEX += inverse(m) * caminhada(MODEL_MATRIX[3].xyz, INSTANCE_CUSTOM.y);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb * (0.8 + 0.45 * h11(semente * 5.1));
	ROUGHNESS = 0.93;
	SPECULAR = 0.18;
}
"""

const OLHO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

%s
uniform vec3 pescoco;
uniform vec3 olho;
uniform float cintura;
uniform float lado = 1.0;
uniform float quad = 0.036;
uniform float perto = 3.5;
uniform float forca = 1.3;
uniform float some = 20.0;

varying float brilho;

void vertex() {
	float s = INSTANCE_CUSTOM.x;
	float t = TIME;
	vec3 c = vec3(olho.x * lado, olho.y, olho.z);
	c = pescoco + giro(cabeca_agora(s, t)) * (c - pescoco);
	c = curvar(c, INSTANCE_CUSTOM.w, cintura);
	vec3 mundo = (MODEL_MATRIX * vec4(c, 1.0)).xyz + caminhada(MODEL_MATRIX[3].xyz, INSTANCE_CUSTOM.y);
	vec3 v = (VIEW_MATRIX * vec4(mundo, 1.0)).xyz;
	float d = -v.z;
	// Cresce com a distancia so ate um ponto: longe o par de olhos tem de
	// encolher, senao a mata inteira vira um varal de lampadas.
	float tam = quad * clamp(d / perto, 1.0, 3.2);
	// Os olhos tambem fecham, de vez em quando, os dois juntos.
	bool fechado = h11(floor(t * 1.3 + s * 40.0) + s) < 0.12;
	if (piscando(s, t, INSTANCE_CUSTOM.z) || fechado) {
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

var _corpos: MultiMeshInstance3D
var _olhos: Array[MultiMeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []

static var _malha: ArrayMesh
static var _shader_corpo: Shader
static var _shader_olho: Shader


## Monta a multidao com uma figura por item de `figuras`: dicionarios com
## `pos` (Vector3, o pe no chao, global), `olha` (Vector3, para onde a frente
## aponta, global), `altura` (m), `rapidez` (m/s), `pisca` (bool) e `curvado`
## (0-1).
static func criar(figuras: Array) -> MultidaoEncapuzada:
	var m := MultidaoEncapuzada.new()
	m.name = "Multidao"
	m._montar(figuras)
	return m


## O carro, para onde todos andam. Chamado todo quadro por quem conhece o carro.
func mirar(alvo: Vector3) -> void:
	_uniforme(&"alvo", alvo)


## Quantos segundos de caminhada ja se passaram.
func andar(segundos: float) -> void:
	_uniforme(&"anda", segundos)


func aparecer(sim: bool) -> void:
	visible = sim
	_uniforme(&"aparece", 1.0 if sim else 0.0)


func tique(k: float) -> void:
	_uniforme(&"tique", k)


func _uniforme(nome: StringName, valor: Variant) -> void:
	for mat: ShaderMaterial in _mats:
		mat.set_shader_parameter(nome, valor)


func _montar(figuras: Array) -> void:
	if _malha == null:
		_malha = _figura()
		_shader_corpo = Shader.new()
		_shader_corpo.code = CORPO_SHADER % COMUM
		_shader_olho = Shader.new()
		_shader_olho.code = OLHO_SHADER % COMUM
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _malha
	mm.instance_count = figuras.size()
	var olhos_mm := MultiMesh.new()
	olhos_mm.transform_format = MultiMesh.TRANSFORM_3D
	olhos_mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	olhos_mm.mesh = q
	olhos_mm.instance_count = figuras.size()
	var caixa := AABB()
	for i in figuras.size():
		var f: Dictionary = figuras[i]
		var pos: Vector3 = f["pos"]
		var olha: Vector3 = f.get("olha", pos + Vector3.FORWARD)
		var frente := olha - pos
		frente.y = 0.0
		var base := Basis.looking_at(frente.normalized() if frente.length_squared() > 0.0001
			else Vector3.FORWARD, Vector3.UP)
		base = base.scaled(Vector3.ONE * (float(f.get("altura", 1.9)) / 1.9))
		var xf := Transform3D(base, pos)
		var dados := Color(fmod(float(i) * 0.6180339 + 0.137, 1.0), float(f.get("rapidez", 0.3)),
			1.0 if bool(f.get("pisca", false)) else 0.0, float(f.get("curvado", 0.0)))
		mm.set_instance_transform(i, xf)
		mm.set_instance_custom_data(i, dados)
		olhos_mm.set_instance_transform(i, xf)
		olhos_mm.set_instance_custom_data(i, dados)
		caixa = AABB(pos, Vector3.ZERO) if i == 0 else caixa.expand(pos)
	caixa = caixa.grow(12.0)
	caixa.size.y += 6.0
	_corpos = MultiMeshInstance3D.new()
	_corpos.name = "Corpos"
	_corpos.multimesh = mm
	var mc := ShaderMaterial.new()
	mc.shader = _shader_corpo
	mc.set_shader_parameter(&"pescoco", PESCOCO)
	mc.set_shader_parameter(&"ombro", OMBRO)
	mc.set_shader_parameter(&"cintura", CINTURA)
	_corpos.material_override = mc
	_mats.append(mc)
	add_child(_corpos)
	for lado: float in [-1.0, 1.0]:
		var o := MultiMeshInstance3D.new()
		o.name = "Olhos"
		o.multimesh = olhos_mm
		var mo := ShaderMaterial.new()
		mo.shader = _shader_olho
		mo.set_shader_parameter(&"pescoco", PESCOCO)
		mo.set_shader_parameter(&"olho", OLHO)
		mo.set_shader_parameter(&"cintura", CINTURA)
		mo.set_shader_parameter(&"lado", lado)
		mo.set_shader_parameter(&"quad", OLHO_QUAD)
		mo.set_shader_parameter(&"perto", OLHO_PERTO)
		o.material_override = mo
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mats.append(mo)
		_olhos.append(o)
		add_child(o)
	# O MultiMesh mede a caixa pelas posicoes paradas; a caminhada e os bracos
	# levantados saem dela, e sem folga a figura da ponta some ao andar.
	for mi: GeometryInstance3D in [_corpos, _olhos[0], _olhos[1]]:
		mi.custom_aabb = caixa
		mi.extra_cull_margin = 4.0


# --- a figura ---------------------------------------------------------------

## A batina, a murca, os bracos e o capuz, numa malha so. UV2.x marca a parte
## (0 corpo, 1 cabeca, 2 braco esquerdo, 3 direito), que o shader gira.
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
	# A murca: capa curta sobre os ombros.
	var murca := [_anel(1.49, 0.12, 0.11, 0.0, 16, 0.0, rng),
		_anel(1.42, 0.29, 0.21, 0.0, 16, 0.0, rng),
		_anel(1.20, 0.35, 0.27, 0.01, 16, 0.02, rng)]
	_costurar(st, murca, PANO * 1.1, 0.0, false, false)
	# Os bracos: manga larga do ombro ao punho, e a mao de cera.
	for lado: float in [-1.0, 1.0]:
		var parte := 2.0 if lado < 0.0 else 3.0
		var o := Vector3(OMBRO.x * lado, OMBRO.y, OMBRO.z)
		var punho := Vector3((OMBRO.x + 0.05) * lado, 0.84, -0.07)
		_manga(st, o, punho, 0.07, 0.095, PANO * 1.05, parte)
		var ponta := punho + Vector3(0.012 * lado, -0.19, -0.02)
		_manga(st, punho + Vector3(0.0, 0.03, 0.0), ponta, 0.035, 0.022, PELE, parte)
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
	# O fundo do capuz: preto, um palmo para dentro da boca.
	var fundo := PackedVector3Array()
	for j in 14:
		var a := float(j) / 14.0 * TAU
		fundo.append(Vector3(cos(a) * 0.118, cy + sin(a) * 0.158, -0.07))
	_leque(st, fundo, Vector3(0.0, cy, -0.065), Color.BLACK, 1.0)
	st.index()
	st.generate_normals()
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


static func _leque(st: SurfaceTool, borda: PackedVector3Array, centro: Vector3, cor: Color,
		parte: float) -> void:
	for j in borda.size():
		_tri(st, centro, borda[j], borda[(j + 1) % borda.size()], cor, parte)


## Um tubo conico de `de` a `ate`, de raio `r0` a `r1`, fechado nas pontas.
static func _manga(st: SurfaceTool, de: Vector3, ate: Vector3, r0: float, r1: float,
		cor: Color, parte: float) -> void:
	var eixo := (ate - de).normalized()
	var u := eixo.cross(Vector3.FORWARD).normalized()
	var v := eixo.cross(u).normalized()
	var lados := 8
	var aneis := []
	for k in 3:
		var t := float(k) / 2.0
		var c := de.lerp(ate, t)
		var r := lerpf(r0, r1, t)
		var pts := PackedVector3Array()
		for j in lados:
			var a := float(j) / float(lados) * TAU
			pts.append(c + (u * cos(a) + v * sin(a)) * r)
		aneis.append(pts)
	for i in 2:
		var a: PackedVector3Array = aneis[i]
		var b: PackedVector3Array = aneis[i + 1]
		for j in lados:
			var j1 := (j + 1) % lados
			_tri(st, a[j], b[j], a[j1], cor, parte)
			_tri(st, a[j1], b[j], b[j1], cor, parte)
	_leque(st, aneis[2], ate + eixo * 0.01, cor, parte)
	_leque(st, aneis[0], de - eixo * 0.01, cor, parte)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, cor: Color,
		parte: float) -> void:
	for p: Vector3 in [a, b, c]:
		st.set_color(cor)
		st.set_uv2(Vector2(parte, 0.0))
		st.add_vertex(p)

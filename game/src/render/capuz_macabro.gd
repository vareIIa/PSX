## O capuz preto dos padres da estrada: pano sobre a cabeca, nenhum rosto — so
## o fundo escuro, dois pontos vermelhos e um sorriso que vai abrindo.
##
## Por que existe
## --------------
## O padre da abertura tinha rosto: cera, barba, testa franzida. Na luz do
## farol, a vinte metros, lia como um senhor na estrada; na janela, como um tio
## assustado. O medo aqui e o que NAO se ve. O capuz fecha a cabeca inteira, a
## boca do capuz e um buraco, e de dentro dele so saem os olhos — dois pontos
## vermelhos que atravessam a nevoa — e, quando ele olha para a janela, um
## sorriso de dentes que abre mais do que uma boca abre.
##
## Os olhos e a boca nao sao desenho
## ---------------------------------
## A primeira versao pintava os dois: halo vermelho do tamanho de um pires e um
## sorriso de dentes brancos em linha, aceso sozinho no escuro. Lia como emoji.
## Agora o olho e so um nucleo pequeno, mais quente que o branco, e quem faz o
## halo e o glow da tela; de longe os dois nucleos viram um ponto so, e ele nao
## encolhe abaixo de um pixel (o quad cresce com a distancia). Os olhos acendem
## uma luz vermelha curta dentro do capuz, e e ELA que mostra a boca: dentes
## tortos, amarelos, faltando, a gengiva molhada brilhando — iluminados, e nao
## pintados. Longe da luz, a boca some no preto.
##
## O que ha aqui
## -------------
## No osso da CABECA: o capuz (um tubo de aneis que fecha atras em ponta, como
## capuz de monge), o fundo escuro, os olhos, a luz e a boca. No TORSO: a murca
## que cai sobre os ombros e a cruz no peito. No QUADRIL, se pedida: a batina que
## desce ate o chao e arrasta atras.
##
## `sorriso` vai de 0 (a boca fechada, uma fresta de dentes) a 1 (a queixada
## caida). `olhos` e o brilho dos pontos, 0 apagados.
class_name CapuzMacabro
extends Node3D

const PANO := Color(0.030, 0.027, 0.025)
## Meia largura e meia altura da boca do capuz, e quanto o fundo fica atras do
## rosto: raso, o buraco le como mascara.
const BOCA := Vector2(0.150, 0.195)
const FUNDO := 0.09
## Onde o capuz fecha atras (z), e quanto a ponta sobe.
const NUCA := 0.23
const PONTA_SOBE := 0.07
## Os olhos: distancia entre eles, altura sobre o centro do rosto, tamanho do
## quad e a distancia a partir da qual ele cresce para nao sumir.
const OLHOS_ENTRE := 0.062
const OLHOS_Y := 0.030
const OLHO_QUAD := 0.034
const OLHO_PERTO := 3.5
## A luz que os olhos fazem dentro do capuz.
const LUZ_OLHOS := 0.16
const LUZ_OLHOS_ALCANCE := 0.24
## A boca: largura e altura do quad, e onde ela fica.
const BOCA_SORRISO := Vector2(0.19, 0.17)
const SORRISO_Y := -0.072

const OLHO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform float forca = 1.0;
uniform float perto = 3.5;
uniform float escala = 1.0;

void vertex() {
	// Billboard, e o quad cresce com a distancia: longe, o olho ocupa sempre o
	// mesmo punhado de pixels e nao some entre dois quadros.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float d = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
	VERTEX *= max(1.0, d / perto) * escala;
}

void fragment() {
	// Opaco, e nao somado: o vidro da janela refrata a copia da tela feita
	// ANTES dos transparentes, e um olho somado sumia atras dele. O halo e o
	// glow da tela, que pega o que passa do branco.
	float r = length(UV * 2.0 - 1.0);
	if (r > 0.34) {
		discard;
	}
	float nucleo = smoothstep(0.34, 0.0, r);
	vec3 cor = mix(vec3(1.0, 0.05, 0.012), vec3(1.0, 0.5, 0.3), nucleo * nucleo);
	ALBEDO = cor * (0.6 + nucleo * 3.4) * forca;
}
"""

const BOCA_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float abre : hint_range(0.0, 1.0) = 0.0;

float h1(float x) {
	return fract(sin(x * 91.7 + 3.1) * 43758.5);
}

float ruido(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(h1(i), h1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float larg = mix(0.58, 0.96, abre);
	float ax = abs(p.x) / larg;
	// A borda da boca treme: nenhum labio e uma curva de compasso.
	float treme = (ruido(p.x * 9.0 + 4.0) - 0.5) * 0.10;
	if (ax > 1.0 + treme * 0.5) {
		discard;
	}
	float u = min(ax * ax, 1.0);
	// Os cantos sobem e ficam: e a queixada que cai, comprida, por baixo de um
	// sorriso que nao desmancha.
	float meio = 0.18 + 0.42 * u + 0.06 * p.x * abre;
	float h = mix(0.07, 1.55, abre * abre) * pow(1.0 - u, 0.8) + 0.01;
	float cima = meio + h * 0.10 + treme;
	float baixo = meio - h * 0.90 - treme * 0.6;
	if (p.y > cima + 0.02 || p.y < baixo - 0.02) {
		discard;
	}
	// Dentes: a fronteira entre eles e torta, a altura de cada um e sorteada, e
	// alguns faltam.
	float n = mix(9.0, 13.0, abre);
	float fila = p.x * n * 0.5 / larg + 0.5 + 0.22 * sin(p.x * 23.0);
	float qual = floor(fila);
	float f = fract(fila);
	float sorte = h1(qual * 1.37);
	bool falta = sorte < 0.14;
	float ponta = 1.0 - abs(f - 0.5) * 2.0;
	// Um ou outro dente comprido, de ponta: nao e dentadura de gente.
	float longo = h1(qual + 7.0) > 0.8 ? 1.7 : (0.45 + 0.4 * h1(qual + 7.0));
	float alto = min(h * 0.40, 0.36) * longo * pow(ponta, 0.6);
	bool em_cima = p.y > cima - alto;
	bool em_baixo = p.y < baixo + alto * 0.85;
	bool fresta = f < 0.10 || f > 0.92;
	vec3 cor;
	float aspero;
	float brilho = 0.6;
	if ((em_cima || em_baixo) && !fresta && !falta) {
		float raiz = em_cima ? (p.y - (cima - alto)) / alto
			: ((baixo + alto * 0.85) - p.y) / (alto * 0.85);
		vec3 dente = mix(vec3(0.46, 0.40, 0.26), vec3(0.30, 0.23, 0.12), h1(qual + 2.0));
		cor = dente * mix(1.0, 0.35, clamp(raiz, 0.0, 1.0));
		// Um fio de osso proprio: debaixo de luz vermelha, dente sem isto e
		// gengiva.
		EMISSION = dente * 0.05 * mix(1.0, 0.3, clamp(raiz, 0.0, 1.0));
		aspero = 0.32;
	} else if (em_cima || em_baixo) {
		// Gengiva e o buraco do dente que falta: escuro e molhado.
		cor = vec3(0.06, 0.008, 0.006);
		aspero = 0.15;
	} else {
		// A garganta: nada volta dela, nem o reflexo.
		cor = vec3(0.0);
		aspero = 1.0;
		brilho = 0.0;
	}
	// Perto da borda tudo afunda no preto do capuz: nao ha contorno.
	float fim = smoothstep(1.0, 0.72, ax) * smoothstep(0.0, 0.03, cima + 0.02 - p.y)
		* smoothstep(0.0, 0.03, p.y - (baixo - 0.02));
	ALBEDO = cor * fim;
	EMISSION *= fim;
	ROUGHNESS = aspero;
	SPECULAR = brilho * fim;
}
"""

var sorriso: float = 0.0:
	set(v):
		sorriso = clampf(v, 0.0, 1.0)
		if _mat_boca != null:
			_mat_boca.set_shader_parameter("abre", sorriso)
var olhos: float = 1.0:
	set(v):
		olhos = maxf(v, 0.0)
		_pintar_olhos()
## Tamanho dos olhos (1 e o normal). Atras do vidro embacado da janela o
## desfoque do vidro come um ponto de um centimetro; maior e mais quente, ele
## atravessa como uma mancha vermelha acesa.
var olhos_tamanho: float = 1.0:
	set(v):
		olhos_tamanho = maxf(v, 0.1)
		if _mat_olho != null:
			_mat_olho.set_shader_parameter("escala", olhos_tamanho)

var _mat_boca: ShaderMaterial
var _mat_olho: ShaderMaterial
var _luz: OmniLight3D
var _olhos_nos: Array[MeshInstance3D] = []

static var _shader_boca: Shader
static var _shader_olho: Shader
static var _mat_pano: StandardMaterial3D


## Veste o capuz em `c`, ja montado. `semente` varia as dobras do pano,
## `largura` escala a murca com os ombros (1 e o ombro medio de 42 cm) e
## `batina_ao_chao` poe a saia que arrasta.
static func vestir(c: Corpo, semente: int = 0, largura: float = 1.0,
		batina_ao_chao: bool = false) -> CapuzMacabro:
	var esq := c.esqueleto()
	if esq == null:
		return null
	var capuz := CapuzMacabro.new()
	capuz.name = "Capuz"
	var preso := BoneAttachment3D.new()
	preso.name = "NaCabeca"
	preso.bone_idx = Corpo.Osso.CABECA
	esq.add_child(preso)
	preso.add_child(capuz)
	var rosto := c.plano_do_rosto()
	capuz._montar_cabeca(rosto.origin.y, -rosto.origin.z, semente)
	var no_torso := BoneAttachment3D.new()
	no_torso.name = "NoTorso"
	no_torso.bone_idx = Corpo.Osso.TORSO
	esq.add_child(no_torso)
	var y_cabeca := esq.get_bone_global_rest(Corpo.Osso.CABECA).origin.y
	var y_torso := esq.get_bone_global_rest(Corpo.Osso.TORSO).origin.y
	capuz._montar_murca(no_torso, y_cabeca - y_torso, largura, semente)
	if batina_ao_chao:
		var no_quadril := BoneAttachment3D.new()
		no_quadril.name = "NoQuadril"
		no_quadril.bone_idx = Corpo.Osso.QUADRIL
		esq.add_child(no_quadril)
		var y_quadril := esq.get_bone_global_rest(Corpo.Osso.QUADRIL).origin.y
		capuz._montar_batina(no_quadril, y_quadril, largura, semente)
	return capuz


func _montar_cabeca(yc: float, meia_prof: float, semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + semente * 13
	var z_boca := -(meia_prof + FUNDO)
	# O capuz: aneis de superelipse da boca ate a nuca. A boca e aberta; atras
	# o tubo fecha num ponto que sobe, a ponta do capuz de monge.
	var aneis := 10
	var lados := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pontos: Array = []
	for i in aneis:
		var t := float(i) / float(aneis - 1)
		var z := lerpf(z_boca, NUCA, t)
		var fecha := sqrt(maxf(0.0, 1.0 - pow(t, 4.0)))
		var rx := BOCA.x * fecha * (1.0 + 0.10 * sin(t * PI))
		var ry := BOCA.y * fecha * (1.0 + 0.07 * sin(t * PI))
		var cy := yc + 0.012 + PONTA_SOBE * pow(t, 3.0)
		var anel: Array[Vector3] = []
		for k in lados:
			var se := _superelipse(float(k) / float(lados) * TAU)
			var sy := se.y / BOCA.y
			var p := Vector3(se.x / BOCA.x * rx, cy + sy * ry, z)
			# A aba da frente cai sobre a testa e as laterais fecham um pouco:
			# o pano pende, nao e uma moldura.
			if i == 0:
				if sy > 0.3:
					p.y -= 0.03 * sy
					p.z -= 0.018 * sy
				p.x *= 0.93
			elif i < aneis - 1:
				p += Vector3(rng.randf_range(-0.007, 0.007), rng.randf_range(-0.007, 0.007),
					rng.randf_range(-0.005, 0.005))
			anel.append(p)
		pontos.append(anel)
	for i in aneis - 1:
		var a0: Array[Vector3] = pontos[i]
		var a1: Array[Vector3] = pontos[i + 1]
		for k in lados:
			var k1 := (k + 1) % lados
			_tri(st, a0[k], a1[k], a1[k1])
			_tri(st, a0[k], a1[k1], a0[k1])
	st.generate_normals()
	var pano := MeshInstance3D.new()
	pano.name = "Pano"
	pano.mesh = st.commit()
	pano.material_override = _pano()
	add_child(pano)

	# O fundo: preto, fosco, bem atras da boca do capuz. Tapa o rosto do `Corpo`
	# inteiro. Com o contorno da boca, e nao um retangulo: a quina de um quad
	# furava o pano dois dedos atras da boca.
	var fundo := MeshInstance3D.new()
	fundo.name = "Fundo"
	var leque := SurfaceTool.new()
	leque.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in lados:
		var a0 := float(k) / float(lados) * TAU
		var a1 := float(k + 1) / float(lados) * TAU
		_tri(leque, Vector3.ZERO, _superelipse(a0) * 0.97, _superelipse(a1) * 0.97)
	fundo.mesh = leque.commit()
	var preto := StandardMaterial3D.new()
	preto.albedo_color = Color(0.004, 0.003, 0.003)
	preto.roughness = 1.0
	preto.cull_mode = BaseMaterial3D.CULL_DISABLED
	fundo.material_override = preto
	fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fundo)
	fundo.position = Vector3(0.0, yc + 0.012, z_boca + 0.05)

	# Os olhos.
	if _shader_olho == null:
		_shader_olho = Shader.new()
		_shader_olho.code = OLHO_SHADER
	_mat_olho = ShaderMaterial.new()
	_mat_olho.shader = _shader_olho
	_mat_olho.set_shader_parameter("perto", OLHO_PERTO)
	var z_olho := z_boca + 0.042
	for lado: float in [-1.0, 1.0]:
		var olho := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(OLHO_QUAD, OLHO_QUAD)
		olho.mesh = q
		olho.material_override = _mat_olho
		olho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(olho)
		# Um olho um fio mais alto que o outro: simetria perfeita le como
		# brinquedo.
		olho.position = Vector3(lado * OLHOS_ENTRE * 0.5,
			yc + OLHOS_Y + (0.004 if lado > 0.0 else 0.0), z_olho)
		_olhos_nos.append(olho)
	# A luz dos olhos: vermelha, curta, sem sombra. Pega a borda de dentro do
	# capuz e os dentes; o resto continua preto.
	_luz = OmniLight3D.new()
	_luz.name = "LuzDosOlhos"
	_luz.light_color = Color(1.0, 0.12, 0.05)
	_luz.omni_range = LUZ_OLHOS_ALCANCE
	_luz.omni_attenuation = 1.6
	_luz.shadow_enabled = false
	add_child(_luz)
	# Dentro da boca do capuz, e nao na frente: de fora ela pintava a murca.
	_luz.position = Vector3(0.0, yc - 0.02, z_olho - 0.006)
	_pintar_olhos()

	# A boca.
	if _shader_boca == null:
		_shader_boca = Shader.new()
		_shader_boca.code = BOCA_SHADER
	_mat_boca = ShaderMaterial.new()
	_mat_boca.shader = _shader_boca
	_mat_boca.set_shader_parameter("abre", sorriso)
	var boca := MeshInstance3D.new()
	boca.name = "Boca"
	var qs := QuadMesh.new()
	qs.size = BOCA_SORRISO
	boca.mesh = qs
	boca.material_override = _mat_boca
	boca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(boca)
	boca.position = Vector3(0.0, yc + SORRISO_Y, z_olho + 0.004)
	boca.rotation.y = PI


## A murca: o pano que desce do pescoco e cobre os ombros, e a cruz no peito.
func _montar_murca(no_torso: Node3D, y_pescoco: float, largura: float,
		semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9103 + semente * 29
	var aneis := [
		# y relativo ao pescoco, meia largura, meia profundidade, z do centro
		[0.05, 0.12, 0.12, 0.0],
		[-0.06, 0.23, 0.19, -0.02],
		[-0.19, 0.30, 0.23, -0.02],
		[-0.36, 0.32, 0.24, -0.02],
	]
	var lados := 22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pontos: Array = []
	for i in aneis.size():
		var an: Array = aneis[i]
		# O colarinho nao cresce com o ombro; a barra cresce inteira.
		var escala := lerpf(1.0, largura, clampf(float(i) / 2.0, 0.0, 1.0))
		var anel: Array[Vector3] = []
		for k in lados:
			var a := float(k) / float(lados) * TAU
			var r := 1.0
			# A barra: dobras fundas, como pano pesado caindo.
			if i == aneis.size() - 1:
				r += 0.07 * sin(a * 7.0 + float(semente)) + rng.randf_range(-0.03, 0.03)
			var p := Vector3(cos(a) * float(an[1]) * r * escala, y_pescoco + float(an[0]),
				float(an[3]) + sin(a) * float(an[2]) * r * escala)
			if i == aneis.size() - 1:
				p.y += rng.randf_range(-0.03, 0.02)
			anel.append(p)
		pontos.append(anel)
	_costurar(st, pontos, lados)
	var murca := MeshInstance3D.new()
	murca.name = "Murca"
	murca.mesh = st.commit()
	murca.material_override = _pano()
	no_torso.add_child(murca)

	# A cruz: madeira escura num cordao, sobre o peito.
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.20, 0.13, 0.08)
	madeira.roughness = 0.7
	var y_cruz := y_pescoco - 0.46
	var z_cruz := -0.235 * largura
	for peca: Array in [[Vector3(0.020, 0.15, 0.013), Vector3.ZERO],
			[Vector3(0.085, 0.020, 0.013), Vector3(0.0, 0.032, 0.0)]]:
		var mi := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = peca[0]
		mi.mesh = caixa
		mi.material_override = madeira
		no_torso.add_child(mi)
		mi.position = Vector3(0.0, y_cruz, z_cruz) + (peca[1] as Vector3)
		mi.rotation.x = -0.08


## A batina ate o chao: da cintura desce abrindo, e a barra deita no barro e
## arrasta um palmo atras. Esconde as pernas — ninguem ve o padre andar.
func _montar_batina(no_quadril: Node3D, y_quadril: float, largura: float,
		semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5501 + semente * 17
	var l := lerpf(1.0, largura, 0.7)
	var aneis := [
		# y do chao (fracao do quadril), meia largura, meia profundidade, z, dobra
		[1.18, 0.20, 0.15, 0.0, 0.0],
		[1.0, 0.23, 0.18, 0.0, 0.01],
		[0.55, 0.28, 0.24, 0.01, 0.03],
		[0.20, 0.33, 0.30, 0.03, 0.05],
		[0.03, 0.37, 0.35, 0.05, 0.07],
	]
	var lados := 26
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pontos: Array = []
	for an: Array in aneis:
		var anel: Array[Vector3] = []
		for k in lados:
			var a := float(k) / float(lados) * TAU
			var r := 1.0 + float(an[4]) * sin(a * 8.0 + float(semente) * 0.7)
			anel.append(Vector3(cos(a) * float(an[1]) * l * r,
				y_quadril * float(an[0]) - y_quadril,
				float(an[3]) + sin(a) * float(an[2]) * l * r))
		pontos.append(anel)
	# A cauda: a barra deitada no chao, mais comprida atras (+z).
	var cauda: Array[Vector3] = []
	for k in lados:
		var a := float(k) / float(lados) * TAU
		var atras := maxf(0.0, sin(a))
		var r := 1.12 + 0.06 * rng.randf()
		cauda.append(Vector3(cos(a) * 0.37 * l * r, 0.006 - y_quadril,
			0.05 + sin(a) * 0.35 * l * r + atras * atras * 0.22))
	pontos.append(cauda)
	_costurar(st, pontos, lados)
	var batina := MeshInstance3D.new()
	batina.name = "Batina"
	batina.mesh = st.commit()
	batina.material_override = _pano()
	no_quadril.add_child(batina)


## Liga os aneis em fila numa malha lisa.
static func _costurar(st: SurfaceTool, pontos: Array, lados: int) -> void:
	for i in pontos.size() - 1:
		var a0: Array[Vector3] = pontos[i]
		var a1: Array[Vector3] = pontos[i + 1]
		for k in lados:
			var k1 := (k + 1) % lados
			_tri(st, a0[k], a1[k1], a1[k])
			_tri(st, a0[k], a0[k1], a1[k1])
	st.generate_normals()


func _pintar_olhos() -> void:
	if _mat_olho == null:
		return
	_mat_olho.set_shader_parameter("forca", olhos)
	for o in _olhos_nos:
		o.visible = olhos > 0.01
	if _luz != null:
		_luz.light_energy = LUZ_OLHOS * olhos
		_luz.visible = olhos > 0.01


static func _pano() -> StandardMaterial3D:
	if _mat_pano == null:
		_mat_pano = StandardMaterial3D.new()
		_mat_pano.albedo_color = PANO
		_mat_pano.roughness = 1.0
		_mat_pano.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat_pano


## Um ponto da boca do capuz no angulo `a`: superelipse, mais quadrada que um
## circulo, como pano sobre a cabeca de caixa.
static func _superelipse(a: float) -> Vector3:
	var ca := cos(a)
	var sa := sin(a)
	return Vector3(signf(ca) * pow(absf(ca), 0.8) * BOCA.x,
		signf(sa) * pow(absf(sa), 0.8) * BOCA.y, 0.0)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

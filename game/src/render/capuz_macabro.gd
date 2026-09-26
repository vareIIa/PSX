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
## No osso da CABECA: o fundo escuro, os olhos, a luz e a boca (so quando nao ha
## rosto de verdade debaixo). O pano (capuz, murca e batina) e de verdade: pesa,
## balanca, bate no corpo e deita no chao (`PanoGPU`, ver `vestir_pano`). No
## TORSO, a cruz no peito.
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
## Os de fundo com os bracos de fora (meta `bracos_de_fora`, `BracosPodres`):
## quanto a barra da murca sobe nos lados (m na pessoa de 1,72), a folga da
## batina alem do quadril nos lados (na coxa, no joelho e na barra), e os
## colisores da manga larga (raio) e da mao (raio, comprimento).
const MURCA_LADO_SOBE := 0.17
const BATINA_DE_FORA := Vector3(0.07, 0.10, 0.18)
const MANGA_DE_FORA := 0.075
## A altura do cos da batina de fundo (m, pessoa de 1,72): acima do cinto.
const BATINA_COS_DE_FORA := 1.10
const MAO_DE_FORA := Vector2(0.05, 0.22)

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
		if rosto != null:
			rosto.call(&"por_sorriso", sorriso)
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
		if rosto != null:
			rosto.call(&"por_olhos", olhos, olhos_tamanho)

## O rosto de verdade debaixo do capuz (`CabecaDoPadre`, `RostoEnfaixado`), ou
## null. Com ele o capuz deixa de desenhar o buraco preto, os dois pontos e o
## sorriso de quad, e repassa `sorriso` e `olhos` para ele: quem anima a cena
## continua escrevendo no capuz. Ver `abrir_para_rosto`.
var rosto: Node3D

## O pano simulado (capuz, murca e batina), ou null antes de `vestir_pano`.
var pano: PanoGPU

var _largura := 1.0
var _semente := 0
var _batina := true
var _mat_boca: ShaderMaterial
var _mat_olho: ShaderMaterial
var _luz: OmniLight3D
var _olhos_nos: Array[MeshInstance3D] = []

static var _shader_boca: Shader
static var _shader_olho: Shader


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
	capuz._largura = largura
	capuz._semente = semente
	capuz._batina = batina_ao_chao
	return capuz


func _montar_cabeca(yc: float, meia_prof: float, _semente_: int) -> void:
	var z_boca := -(meia_prof + FUNDO)
	var lados := 18
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


## Veste o pano de verdade: capuz, murca e batina simulados (`PanoGPU`), na
## medida do corpo e da cabeca que ficou debaixo (`rosto`, ou a caixa do
## `Corpo`). Chame depois de `abrir_para_rosto`, se houver rosto.
##
## As tres pecas sao tubos de particulas (colunas em volta do eixo vertical,
## linhas de cima para baixo ou de baixo para cima):
## - o capuz nasce nos ombros, abraca o pescoco, tem a boca aberta na frente do
##   rosto e fecha atras numa ponta de capuz de monge que balanca;
## - a murca desce do colarinho, cobre os ombros e cai sobre os bracos;
## - a batina desce da cintura ate o chao e arrasta atras.
## Cada particula tem um lugar no osso (o repouso) e uma folga em volta dele:
## pouca no cranio, muita na barra. O que da o peso e o balanco e a fisica.
##
## Nos de fundo (meta `bracos_de_fora` no `Corpo`) os bracos aparecem: a murca
## abre nos lados, a batina e justa nos lados, e os colisores do braco seguem a
## manga larga e o antebraco comprido dos `BracosPodres`.
func vestir_pano(c: Corpo) -> void:
	var esq := c.esqueleto()
	if esq == null or pano != null:
		return
	pano = PanoGPU.new()
	pano.esqueleto = esq
	var s := c.altura() / Corpo.ALTURA_REF
	var y_cab := esq.get_bone_global_rest(Corpo.Osso.CABECA).origin.y
	var y_tor := esq.get_bone_global_rest(Corpo.Osso.TORSO).origin.y
	var y_qua := esq.get_bone_global_rest(Corpo.Osso.QUADRIL).origin.y
	var y_omb := esq.get_bone_global_rest(Corpo.Osso.BRACO_E).origin.y
	var mo := absf(esq.get_bone_global_rest(Corpo.Osso.BRACO_E).origin.x)
	var mq := absf(esq.get_bone_global_rest(Corpo.Osso.COXA_E).origin.x)
	var perfil := c.perfil()
	# O sobretudo do `Corpo` engrossa o tronco uns dois centimetros.
	var casaco := 0.025
	var peito := _perfil_em(perfil, 1.26) + Vector3.ONE * casaco
	var barriga := _perfil_em(perfil, 1.10) + Vector3.ONE * casaco
	var cintura := _perfil_em(perfil, 0.95) + Vector3.ONE * casaco
	var cab := _elipsoide_da_cabeca(c)
	var cc := cab.get_center()
	var ce := cab.size * 0.5

	# --- colisores ---
	var r_cab := minf(ce.x, ce.z)
	pano.colisor(Corpo.Osso.CABECA, cc - Vector3(0.0, ce.y - r_cab, 0.0) * 0.6,
		cc + Vector3(0.0, ce.y - r_cab, 0.0) * 0.6, r_cab * 1.02)
	pano.colisor(Corpo.Osso.CABECA, cc + Vector3(0.0, ce.y * 0.2, ce.z * 0.35),
		cc + Vector3(0.0, ce.y * 0.2, ce.z * 0.35), r_cab * 0.85)
	pano.colisor(Corpo.Osso.CABECA, Vector3(0.0, -0.02, 0.0),
		Vector3(0.0, cc.y - ce.y * 0.8, cc.z * 0.5), 0.055 * s)
	# O corpo AAA (`CorpoAAA`) debaixo da batina AAA: as capsulas medidas nele,
	# no lugar das do corpo de caixa e dos `BracosPodres`.
	if BatinaAAA.usar() and CorpoAAA.vestir(c) != null:
		BatinaAAA.vestir(pano, s, CorpoAAA.colisores(pano, c))
		c.add_child(pano)
		CruzNoPeito.vestir(c, s, pano.colisores(), BatinaAAA.peito(s))
		return
	for par: Array in [[1.24, peito], [1.08, barriga]]:
		var y := float(par[0]) * s - y_tor
		var m: Vector3 = par[1]
		var d := maxf(m.y, m.z)
		var zc := (m.z - m.y) * 0.5
		var lx := maxf(m.x - d, 0.01)
		pano.colisor(Corpo.Osso.TORSO, Vector3(-lx, y, zc), Vector3(lx, y, zc), d)
	var yq := 0.93 * s - y_qua
	var dq := maxf(cintura.y, cintura.z)
	pano.colisor(Corpo.Osso.QUADRIL, Vector3(-maxf(cintura.x - dq, 0.01), yq, 0.0),
		Vector3(maxf(cintura.x - dq, 0.01), yq, 0.0), dq)
	var braco := (Corpo.Y_COTOVELO - Corpo.Y_OMBRO) * s
	var antebraco := (Corpo.Y_PUNHO - Corpo.Y_COTOVELO) * s
	var coxa := (Corpo.Y_JOELHO - Corpo.Y_QUADRIL) * s
	var canela := (Corpo.Y_TORNOZELO - Corpo.Y_JOELHO) * s
	# Os bracos de fora (`BracosPodres`, meta `bracos_de_fora`): a manga larga e
	# mais grossa que o braco de caixa, e o antebraco sai do corpo e passa do
	# punho, com a mao grande na ponta. Os colisores seguem a malha: a murca
	# assenta na manga, e a batina fica por dentro da mao, e nao por fora.
	var fora := bool(c.get_meta(&"bracos_de_fora", false))
	for par: Array in [[Corpo.Osso.BRACO_E, Corpo.Osso.ANTEBRACO_E, Corpo.Osso.COXA_E,
			Corpo.Osso.CANELA_E, -1.0], [Corpo.Osso.BRACO_D, Corpo.Osso.ANTEBRACO_D,
			Corpo.Osso.COXA_D, Corpo.Osso.CANELA_D, 1.0]]:
		if fora:
			var lado := float(par[4])
			var ante := BracosPodres.antebraco_de_fora(lado, s)
			pano.colisor(int(par[0]), Vector3.ZERO, Vector3(0.0, braco, 0.0), MANGA_DE_FORA * s)
			pano.colisor(int(par[1]), Vector3.ZERO, ante, MAO_DE_FORA.x * s)
			pano.colisor(int(par[1]), ante, ante + BracosPodres.mao_de_fora(lado)
				* MAO_DE_FORA.y * s, MAO_DE_FORA.x * s)
		else:
			pano.colisor(int(par[0]), Vector3.ZERO, Vector3(0.0, braco, 0.0), 0.065 * s)
			pano.colisor(int(par[1]), Vector3.ZERO, Vector3(0.0, antebraco, 0.0), 0.055 * s)
		pano.colisor(int(par[2]), Vector3.ZERO, Vector3(0.0, coxa, 0.0), 0.10 * s)
		pano.colisor(int(par[3]), Vector3.ZERO, Vector3(0.0, canela, 0.0), 0.075 * s)

	# A batina AAA (`BatinaAAA`): a malha do gerador presa em tres grades
	# ajustadas nela, no lugar do capuz, da murca e da batina de tubo. A cruz de
	# madeira sai junto: o crucifixo novo tem corrente com fisica propria.
	if BatinaAAA.usar():
		BatinaAAA.vestir(pano, s)
		c.add_child(pano)
		CruzNoPeito.vestir(c, s, pano.colisores(), BatinaAAA.peito(s))
		return

	# --- capuz ---
	# Aneis-chave (v, y, raio x, raio z, centro z), no espaco do osso da
	# cabeca: dos ombros ao pescoco, do queixo ao alto do cranio, e a ponta que
	# cai atras.
	var ys := y_omb - y_cab
	# _perfil_em da (largura, fundo da frente, fundo de tras).
	var dp := maxf(peito.y, peito.z)
	var fundo_ombro := dp + 0.03
	var chaves := [
		# A barra do capuz deita na rampa do ombro, por cima da murca (as duas
		# pecas nao colidem entre si: o capuz segue a forma dela, 1,5 cm acima).
		[0.00, ys - 0.03, mo + 0.09, fundo_ombro + 0.035, 0.0],
		[0.11, ys + 0.065, mo * 0.74 + 0.02, fundo_ombro + 0.01, 0.005],
		[0.22, 0.03, 0.125 * s, 0.12 * s, cc.z * 0.5 + 0.01],
		[0.34, cc.y - ce.y * 0.85, ce.x + 0.05, ce.z + 0.05, cc.z + 0.01],
		[0.52, cc.y - ce.y * 0.1, ce.x + 0.042, ce.z + 0.045, cc.z + 0.012],
		[0.68, cc.y + ce.y * 0.5, ce.x + 0.036, ce.z + 0.04, cc.z + 0.016],
		[0.80, cc.y + ce.y * 0.93 + 0.022, (ce.x + 0.02) * 0.64, (ce.z + 0.03) * 0.74, cc.z + 0.035],
		[0.90, cc.y + ce.y * 0.97 + 0.03, 0.05, 0.055, cc.z + ce.z * 0.55 + 0.035],
		[1.00, cc.y + ce.y * 0.62, 0.006, 0.006, cc.z + ce.z + 0.11],
	]
	var cw := 32
	var ch := 24
	# O pano sobra: dobras soltas no pescoco e na nuca, que a fisica cai.
	var forma_c := func(v: float, a: float, p: Vector3) -> Vector3:
		var dobra := 0.010 * sin(a * 5.0 + float(_semente)) * (1.0 - absf(v - 0.25) * 3.0)
		return p + Vector3(sin(a), 0.0, -cos(a)) * maxf(dobra, 0.0)
	var hood := _tubo(cw, ch, chaves, forma_c)
	var v_pesc := 0.22
	var j_pesc := roundi(v_pesc * float(ch - 1))
	var rest_cab := esq.get_bone_global_rest(Corpo.Osso.CABECA)
	var n := cw * ch
	var ra := PackedVector3Array()
	var oa := PackedInt32Array()
	var ob := PackedInt32Array()
	var pb := PackedFloat32Array()
	var fo := PackedFloat32Array()
	var pu := PackedFloat32Array()
	var pr := PackedByteArray()
	var ex := PackedByteArray()
	var an := PackedInt32Array()
	ra.resize(n)
	oa.resize(n)
	ob.resize(n)
	pb.resize(n)
	fo.resize(n)
	pu.resize(n)
	pr.resize(n)
	ex.resize(n)
	an.resize(n)
	for j in ch:
		var v := float(j) / float(ch - 1)
		for i in cw:
			var k := j * cw + i
			var a := wrapf(float(i) / float(cw) * TAU, -PI, PI)
			ra[k] = rest_cab * hood[k]
			oa[k] = Corpo.Osso.TORSO
			ob[k] = Corpo.Osso.CABECA
			# Do pescoco ate o queixo o capuz passa do torso para a cabeca: o
			# pescoco gira sem rasgar o pano. Do pescoco para baixo e so torso:
			# no estalo do tique (a cabeca quase do avesso) a barra do capuz,
			# arrastada pela cabeca, atravessava a murca pela frente.
			pb[k] = smoothstep(0.22, 0.38, v)
			# A boca do capuz: um oval na frente, do queixo a testa.
			var bu := a / 0.95
			var bv := (v - 0.52) / 0.20
			# Bem dentro da boca a particula nao simula (segue o repouso); a
			# borda de verdade e cortada no fragmento, lisa.
			ex[k] = 0 if bu * bu + bv * bv < 0.35 else 1
			var perto_da_boca := bu * bu + bv * bv < 1.9
			if v < v_pesc:
				fo[k] = lerpf(0.06, 0.02, v / v_pesc)
			elif v <= 0.80:
				fo[k] = 0.03 if v < 0.36 else (0.022 if perto_da_boca else 0.012)
			else:
				fo[k] = lerpf(0.02, 0.09, (v - 0.80) / 0.20)
			pu[k] = 0.8 if v > 0.85 else 3.0
			pr[k] = 1 if j == j_pesc else 0
			an[k] = j_pesc * cw + i if v <= 0.40 else -1
	var hp := pano.adicionar("Pano", cw, ch, true, ra, oa, ob, pb, fo, pu, pr, ex, an, {
		"espessura": 0.018, "amortecimento": 2.0, "dobra": 0.35, "barra": [0],
		"molhado": 0.5, "buracos": 0.35, "desfiado": 0.012,
		"boca": Vector4(0.95, 0.52, 0.20, 1.0)})
	hp.instancia.name = "Pano"

	# --- murca ---
	var mw := 40
	var mh := 12
	var y_col := y_cab + 0.02
	var chaves_m := [
		[0.0, y_col + 0.03, 0.105 * s, 0.10 * s, 0.005],
		[0.2, y_omb + 0.055, mo * 0.72, dp + 0.035, 0.0],
		[0.4, y_omb - 0.01, mo + 0.075, dp + 0.05, 0.0],
		[0.7, y_omb - 0.16 * s, mo + 0.085, dp + 0.055, 0.0],
		[1.0, y_omb - 0.32 * s, mo + 0.09 * _largura, dp + 0.06, 0.0],
	]
	# Pano sobrando na barra: a volta da barra e maior que a do corpo, e o que
	# sobra vira dobra (a fisica assenta; a forma so da o comeco). A barra
	# nao e reta: pano velho ceder desigual.
	var sem := float(_semente)
	# Nos de fundo a murca abre nos lados: na frente e atras ela desce ate a
	# cintura, como era, e nos lados a barra sobe ate o meio do braco de cima.
	# Dali para baixo quem aparece e a manga e o antebraco. Ate a cintura em
	# volta toda ela escondia os dois.
	var sobe := MURCA_LADO_SOBE * s if fora else 0.0
	var forma_m := func(v: float, a: float, p: Vector3) -> Vector3:
		var onda := 0.6 * sin(a * 11.0 + sem * 1.3) + 0.4 * sin(a * 4.7 + sem * 2.1)
		var dobra := 0.045 * pow(v, 1.5) * (0.55 + 0.45 * onda)
		var q := p + Vector3(sin(a), 0.0, -cos(a)) * dobra
		q.y -= 0.035 * v * v * (0.5 + 0.5 * sin(a * 3.1 + sem * 0.9))
		# So nos lados: com a subida larga (seno ao quadrado) o pano da frente,
		# preso nos vizinhos mais curtos, subia junto e mostrava a fivela.
		q.y += sobe * pow(absf(sin(a)), 4.0) * smoothstep(0.4, 1.0, v)
		return q
	var mur := _tubo(mw, mh, chaves_m, forma_m)
	_peca_tubo(esq, "Murca", mw, mh, mur, Corpo.Osso.TORSO, Corpo.Osso.TORSO,
		[0.004, 0.02, 0.06, 0.14, 0.22], [2.0, 1.2, 0.6, 0.3, 0.2],
		{"espessura": 0.010, "dobra": 0.30, "barra": [mh - 1], "molhado": 0.55,
		"buracos": 0.4})

	# --- batina ---
	if _batina:
		var bw := 40
		var bh := 25
		var y_cin := 1.02 * s
		var cos_ := cintura
		if fora:
			# Com a murca aberta nos lados, o cos da batina sobe acima do cinto do
			# sobretudo: a fivela clara (`Vestuario`, 1,065 m) aparecia no vao.
			y_cin = BATINA_COS_DE_FORA * s
			cos_ = barriga
		var chaves_b := [
			[0.0, y_cin, cos_.x + 0.03, maxf(cos_.y, cos_.z) + 0.03, 0.0],
			[0.15, 0.86 * s, mq + 0.14 * _largura, maxf(cintura.y, cintura.z) + 0.07, 0.01],
			[0.50, 0.46 * s, mq + 0.19 * _largura, maxf(cintura.y, cintura.z) + 0.12, 0.02],
			[1.00, 0.015, mq + 0.25 * _largura, maxf(cintura.y, cintura.z) + 0.19, 0.04],
		]
		if fora:
			# Justa nos lados ate o joelho (a mao pendurada passa por fora) e
			# abrindo so na barra; o fundo (frente e tras) fica o mesmo.
			var b: Vector3 = BATINA_DE_FORA
			chaves_b[1][2] = mq + b.x * _largura
			chaves_b[2][2] = mq + b.y * _largura
			chaves_b[3][2] = mq + b.z * _largura
		var forma_b := func(v: float, a: float, p: Vector3) -> Vector3:
			var onda := 0.6 * sin(a * 9.0 + sem * 0.7) + 0.4 * sin(a * 4.1 + sem * 1.9)
			var dobra := 0.06 * pow(v, 1.2) * (0.55 + 0.45 * onda)
			var q := p + Vector3(sin(a), 0.0, -cos(a)) * dobra
			# A cauda: atras a barra e mais comprida e deita no barro.
			var atras := maxf(0.0, -cos(a))
			var cauda := smoothstep(0.82, 1.0, v) * atras * atras * 0.24
			q.z += cauda
			q.y = maxf(q.y - cauda * 0.1, 0.012)
			return q
		var bat := _tubo(bw, bh, chaves_b, forma_b)
		_peca_tubo(esq, "Batina", bw, bh, bat, Corpo.Osso.QUADRIL, Corpo.Osso.QUADRIL,
			[0.004, 0.03, 0.10, 0.22, 0.30], [2.5, 1.2, 0.5, 0.3, 0.25],
			{"espessura": 0.012, "dobra": 0.25, "barra": [bh - 1], "molhado": 0.7,
			"buracos": 0.5, "lama_altura": 0.45})

	c.add_child(pano)

	# A cruz: madeira escura num cordao, sobre o peito, por fora da murca.
	var no_torso := BoneAttachment3D.new()
	no_torso.name = "NoTorso"
	no_torso.bone_idx = Corpo.Osso.TORSO
	esq.add_child(no_torso)
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.20, 0.13, 0.08)
	madeira.roughness = 0.7
	var y_cruz := y_omb - 0.20 * s - y_tor
	var z_cruz := -(dp + 0.10)
	for peca: Array in [[Vector3(0.020, 0.15, 0.013), Vector3.ZERO],
			[Vector3(0.085, 0.020, 0.013), Vector3(0.0, 0.032, 0.0)]]:
		var mi := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = peca[0]
		mi.mesh = caixa
		mi.material_override = madeira
		no_torso.add_child(mi)
		mi.position = Vector3(0.0, y_cruz, z_cruz) + (peca[1] as Vector3)
		mi.rotation.x = -0.12


## Os pontos de um tubo W x H: cada linha e uma elipse horizontal interpolada
## (Catmull-Rom) entre os aneis-chave [v, y, raio x, raio z, centro z].
## `forma(v, a, p)` mexe em cada ponto (dobra, cauda). A coluna 0 e a frente
## (-Z) e o angulo cresce para +X.
static func _tubo(w: int, h: int, chaves: Array, forma: Callable) -> PackedVector3Array:
	var saida := PackedVector3Array()
	saida.resize(w * h)
	for j in h:
		var v := float(j) / float(h - 1)
		var anel := _chave_em(chaves, v)
		for i in w:
			var a := float(i) / float(w) * TAU
			var p := Vector3(sin(a) * anel[1], anel[0], anel[3] - cos(a) * anel[2])
			saida[j * w + i] = forma.call(v, wrapf(a, -PI, PI), p)
	return saida


## [y, raio x, raio z, centro z] em `v`, por Catmull-Rom entre as chaves.
static func _chave_em(chaves: Array, v: float) -> Array:
	var k := 0
	while k < chaves.size() - 2 and v > float(chaves[k + 1][0]):
		k += 1
	var v0 := float(chaves[k][0])
	var v1 := float(chaves[k + 1][0])
	var t := clampf((v - v0) / maxf(v1 - v0, 1e-6), 0.0, 1.0)
	var r := []
	for c in range(1, 5):
		var p1 := float(chaves[k][c])
		var p2 := float(chaves[k + 1][c])
		var p0 := float(chaves[maxi(k - 1, 0)][c]) if k > 0 else p1 - (p2 - p1)
		var p3 := float(chaves[k + 2][c]) if k + 2 < chaves.size() else p2 + (p2 - p1)
		var t2 := t * t
		var t3 := t2 * t
		r.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
			+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	return r


## Uma peca de tubo presa pela primeira linha a `osso`, com folga e puxa por
## linha interpolados das tabelas (de cima para baixo).
func _peca_tubo(_esq: Skeleton3D, nome: String, w: int, h: int, pontos: PackedVector3Array,
		osso_a: int, osso_b: int, folgas: Array, puxas: Array, opcoes: Dictionary) -> void:
	var n := w * h
	var oa := PackedInt32Array()
	var ob := PackedInt32Array()
	var pb := PackedFloat32Array()
	var fo := PackedFloat32Array()
	var pu := PackedFloat32Array()
	var pr := PackedByteArray()
	var ex := PackedByteArray()
	var an := PackedInt32Array()
	oa.resize(n)
	ob.resize(n)
	pb.resize(n)
	fo.resize(n)
	pu.resize(n)
	pr.resize(n)
	ex.resize(n)
	an.resize(n)
	for j in h:
		var v := float(j) / float(h - 1)
		var f := v * float(folgas.size() - 1)
		var k0 := mini(int(f), folgas.size() - 2)
		var t := f - float(k0)
		for i in w:
			var k := j * w + i
			oa[k] = osso_a
			ob[k] = osso_b
			pb[k] = 0.0
			fo[k] = lerpf(float(folgas[k0]), float(folgas[k0 + 1]), t)
			pu[k] = lerpf(float(puxas[k0]), float(puxas[k0 + 1]), t)
			pr[k] = 1 if j == 0 else 0
			ex[k] = 1
			an[k] = i
	pano.adicionar(nome, w, h, true, pontos, oa, ob, pb, fo, pu, pr, ex, an, opcoes)


## [largura, fundo da frente, fundo de tras] do tronco na altura `y` (em
## unidades da pessoa de 1,72 m), interpolado no perfil do `Corpo`.
static func _perfil_em(perfil: Array, y: float) -> Vector3:
	if perfil.is_empty():
		return Vector3(0.16, 0.11, 0.11)
	var anterior: Array = perfil[0]
	for anel: Array in perfil:
		if float(anel[0]) >= y:
			var t := clampf((y - float(anterior[0])) / maxf(float(anel[0]) - float(anterior[0]), 1e-6), 0.0, 1.0)
			return Vector3(lerpf(float(anterior[1]), float(anel[1]), t),
				lerpf(float(anterior[2]), float(anel[2]), t), lerpf(float(anterior[3]), float(anel[3]), t))
		anterior = anel
	return Vector3(float(anterior[1]), float(anterior[2]), float(anterior[3]))


## O cranio debaixo do capuz, no espaco do osso da cabeca: o do rosto, se ele
## sabe (`elipsoide()`), ou a caixa do `Corpo`.
func _elipsoide_da_cabeca(c: Corpo) -> AABB:
	if rosto != null and rosto.has_method(&"elipsoide"):
		return rosto.call(&"elipsoide")
	var f := c.plano_do_rosto()
	var t := c.tamanho_do_rosto()
	return AABB(Vector3(-t.x * 0.5, f.origin.y - t.y * 0.5, -0.111), Vector3(t.x, t.y, 0.222))


## Tira o fundo preto, os pontos, a luz e a boca de quad, e passa a repassar
## `sorriso` e `olhos` para `r`, que precisa ter `por_sorriso(v)` e
## `por_olhos(forca, tamanho)`.
func abrir_para_rosto(r: Node3D) -> void:
	rosto = r
	for nome: String in ["Fundo", "Boca", "LuzDosOlhos"]:
		var n := get_node_or_null(nome) as Node3D
		if n != null:
			n.visible = false
	for o in _olhos_nos:
		o.queue_free()
	_olhos_nos.clear()
	if _luz != null:
		_luz.queue_free()
		_luz = null
	_mat_olho = null
	_mat_boca = null
	r.call(&"por_sorriso", sorriso)
	r.call(&"por_olhos", olhos, olhos_tamanho)


func _pintar_olhos() -> void:
	if rosto != null:
		rosto.call(&"por_olhos", olhos, olhos_tamanho)
	if _mat_olho == null:
		return
	_mat_olho.set_shader_parameter("forca", olhos)
	for o in _olhos_nos:
		o.visible = olhos > 0.01
	if _luz != null:
		_luz.light_energy = LUZ_OLHOS * olhos
		_luz.visible = olhos > 0.01


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

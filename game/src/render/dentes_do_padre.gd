## A boca de dentro do padre: os 24 dentes, a gengiva, a lingua e a poca de
## sangue no chao da boca. Os dentes quebram, um a um, a cada cabecada.
##
## Por que existe
## --------------
## A boca de dentro era a do Vitruvian: dentes de 68 vertices que liam como
## plastico, a fileira de baixo escondida atras de uma lingua enorme e lisa, e
## nada quebrava. O pedido (`INTRO-PADRE/PLANO_BOCA_SANGUE.md`, Parte 1) e a boca
## de verdade, com os dentes se quebrando em cada golpe ate ele chegar na lente
## com varios quebrados, sangrando.
##
## Como funciona
## -------------
## A malha vem de `tools/gerar_boca_padre.py` (`boca_padre.glb`). Todos os dentes
## estao numa malha so, com todas as versoes de cada um (inteiro, lascado, toco):
## o estado de cada dente e um uniforme, e a versao que nao vale colapsa no vertex
## shader. Uma chamada de desenho para os 24, e a quebra nao monta malha nenhuma.
##
## A fileira de baixo, a gengiva de baixo, a lingua e a poca giram com a queixada
## pela mesma conta da pele (`CabecaDoPadre.QUEIXADA`); os amassados do rosto
## (`AMASSO`) empurram os dentes junto com a cara.
##
## A quebra e roteirizada (`QUEBRA_POR_GOLPE`) e disparada quando o dano da cara
## cruza o inteiro: quem chama e o `CabecaDoPadre.por_dano`, que a cena ja anima
## no quadro de cada golpe. O que quebra sai voando (`Lasca_*` do glb, o mesmo
## material): bate no vidro por fora, escorrega e as vezes gruda no sangue; com o
## vidro estourado, cai.
##
## So quebra quem pede (`quebra_dentes`): o principal liga ao receber o vidro
## (`lascas_no_vidro`); o do capo e o do carona ficam com os dentes inteiros.
class_name DentesDoPadre
extends Node3D

const CENA := "res://assets/monstros/padre/boca/boca_padre.glb"
const ESMALTE := "res://assets/monstros/padre/boca/esmalte_mapa.png"
const GENGIVA := "res://assets/monstros/padre/boca/gengiva_mapa.png"
const LINGUA := "res://assets/monstros/padre/boca/lingua_mapa.png"

## A quebra de cada golpe (1, 2, 3): [numero FDI, estado]. O estado: 1 lascado,
## 2 partido (fica o toco), 3 arrancado (fica o alveolo). O lado e o do padre (o
## 1x e o 4x sao a direita dele).
##   golpe 1: o central esquerdo lasca, o lateral direito parte;
##   golpe 2: o central direito parte, o esquerdo vira toco, um incisivo de
##            baixo sai inteiro e o canino esquerdo lasca;
##   golpe 3: o lateral esquerdo sai, o canino direito e o pre-molar partem, o
##            lateral de baixo parte e o canino de baixo lasca.
const QUEBRA_POR_GOLPE := [
	[[21, 1], [12, 2]],
	[[11, 2], [21, 2], [31, 3], [23, 1]],
	[[22, 3], [13, 2], [42, 2], [33, 1], [14, 2]],
]
## O sangue que a quebra deixa no dente e nos vizinhos (0 a 1).
const SANGUE_QUEBRADO := 0.78
const SANGUE_VIZINHO := 0.55
## A poca no chao da boca: o nivel (y na malha da cabeca) seca e cheia (dano 3).
const POCA_SECA := -0.0800
const POCA_CHEIA := -0.0695
## As pecas que voam: velocidade de saida (m/s), giro (rad/s), vida (s), o
## quique e o atrito no vidro, a chance de grudar no sangue e o quanto ela
## escorrega grudada (m/s).
const PECA_SAI := Vector2(0.35, 0.8)
const PECA_GIRA := Vector2(10.0, 28.0)
const PECA_VIDA := 4.0
const PECA_QUIQUE := 0.22
const PECA_ATRITO := 5.0
const PECA_GRUDA := 0.45
const PECA_ESCORRE := Vector2(0.004, 0.018)
const GRAVIDADE := 9.8
## Quantas pecas voam ao mesmo tempo, no maximo.
const PECAS_MAX := 24
## A lasca grudada no vidro (pedido do usuario, 26/09): nos golpes 1 e 2 a
## primeira peca de cada golpe gruda no sangue do vidro ja no primeiro toque,
## um pouco maior, e cacos de esmalte grudam em volta (quantos por golpe, a
## escala deles e a da peca grudada).
const CACOS := [3, 4]
const CACO_ESCALA := Vector2(0.9, 1.3)
const GRUDADA_ESCALA := 1.3
## O dente que sai no golpe 3 fica pendurado pela gengiva (`DentePendurado`),
## e nao voa (numero FDI).
const PENDURADO := 22
## Onde o fio de gengiva prende no dente pendurado: tanto acima do colo, na raiz
## (m). No colo: o dente meio arrancado, pendendo um palmo de unha abaixo dos
## vizinhos com a coroa a mostra. Preso perto do apice ele caia ate a fileira de
## baixo e o fio sumia no fundo da boca.
const RAIZ_PRESA := 0.0

const DENTES_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

#QUEIXADA
#AMASSO

// A versao de cada dente que aparece (0 inteiro, 1 lascado, 2 toco, -1 nenhuma) e
// o sangue que a quebra deixou nele.
uniform float versao_de[24];
uniform float sangue_d[24];
uniform float dano = 0.0;
uniform sampler2D esmalte : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 esmalte_cor : source_color = vec3(0.80, 0.73, 0.57);
uniform vec3 colo_cor : source_color = vec3(0.47, 0.33, 0.17);
uniform vec3 borda_cor : source_color = vec3(0.60, 0.63, 0.66);
uniform vec3 tartaro_cor : source_color = vec3(0.44, 0.37, 0.22);
uniform vec3 dentina_cor : source_color = vec3(0.80, 0.66, 0.43);
uniform vec3 polpa_cor : source_color = vec3(0.45, 0.035, 0.03);
uniform vec3 sangue_cor : source_color = vec3(0.56, 0.05, 0.04);
uniform vec3 coagulo_cor : source_color = vec3(0.24, 0.02, 0.018);
// A peca solta: quanto sangue ela leva.
instance uniform float sangue_peca = 0.0;

varying vec4 v_cor;
varying vec2 v_uv2;
varying flat int v_id;

float hd(float x) {
	return fract(sin(x * 91.345) * 47453.5453);
}

void vertex() {
	v_cor = COLOR;
	v_uv2 = UV2;
	v_id = int(UV.y + 0.5);
	if (UV2.x < 8.5) {
		if (abs(UV2.x - versao_de[v_id]) > 0.5) {
			// A versao que nao vale some: o triangulo vira ponto.
			VERTEX = vec3(0.0);
		} else {
			float a = -abre * giro_max * UV.x;
			VERTEX = pivo + girar_x(VERTEX - pivo, a);
			NORMAL = girar_x(NORMAL, a);
			float e;
			VERTEX = amassar(VERTEX, e);
		}
	}
}

void fragment() {
	int id = v_id;
	float quebra = v_cor.r;
	float fundo = v_cor.g;
	float ao = v_cor.b;
	float colo = v_cor.a;
	float tom = hd(float(id) + 3.0);
	// A textura corre no dente: x e a volta, y o comprido.
	vec4 m = texture(esmalte, vec2(v_uv2.y + tom, colo * 0.8 + tom * 3.1));

	// O esmalte de gente morta: marfim sujo, marrom no colo, a borda translucida
	// e acinzentada, a mancha, a trinca e o tartaro na linha da gengiva.
	vec3 c = esmalte_cor * mix(0.86, 1.06, tom);
	c = mix(c, colo_cor, smoothstep(0.3, 1.0, colo) * (0.5 + 0.35 * tom));
	c = mix(c, borda_cor * c * 1.35, smoothstep(0.28, 0.0, colo) * 0.6);
	c = mix(c, colo_cor * 0.75, smoothstep(0.55, 0.85, m.b) * (0.35 + 0.3 * tom));
	c = mix(c, colo_cor * 0.4, m.r * 0.65);
	float tartaro = smoothstep(0.8, 0.96, colo) * smoothstep(0.35, 0.7, m.b + tom * 0.3);
	c = mix(c, tartaro_cor, tartaro * 0.8);
	float rug = mix(0.17, 0.3, m.a) + tartaro * 0.4 + m.r * 0.1;

	// A quebra: o anel de esmalte, a dentina, a polpa viva no meio.
	float polpa = smoothstep(0.8, 0.95, fundo) * quebra;
	vec3 q = mix(vec3(0.86, 0.84, 0.79), dentina_cor, smoothstep(0.1, 0.33, fundo));
	q *= mix(0.82, 1.05, m.a);
	q = mix(q, polpa_cor, polpa);
	c = mix(c, q, quebra);
	rug = mix(rug, mix(0.6, 0.25, polpa), quebra);

	// O sangue: primeiro no colo, no vao entre os dentes e na face da quebra; com
	// mais, cobre a coroa. Fino e vermelho, grosso e quase preto.
	float s = max(max(sangue_d[id], sangue_peca), dano / 3.0 * 0.35);
	float onde = colo * 0.55 + (1.0 - ao) * 0.9 + quebra * 0.7 + (m.b - 0.5) * 0.5 + (m.a - 0.5) * 0.25;
	float lim = 1.3 - s * 1.4;
	float cobre = smoothstep(lim - 0.06, lim + 0.04, onde);
	float grosso = smoothstep(lim + 0.05, lim + 0.6, onde);
	cobre = max(cobre, polpa);
	vec3 filme = mix(sangue_cor, coagulo_cor, grosso * 0.85);
	c = mix(c, filme, cobre);
	rug = mix(rug, mix(0.14, 0.32, grosso), cobre);

	ALBEDO = c * mix(0.3, 1.0, ao);
	ROUGHNESS = clamp(rug, 0.05, 1.0);
	SPECULAR = mix(0.5, 0.42, cobre);
	AO = ao;
	AO_LIGHT_AFFECT = 0.7;
	// A borda fina deixa a luz atravessar.
	SSS_STRENGTH = smoothstep(0.35, 0.0, colo) * 0.25 * (1.0 - cobre);
}
"""

const GENGIVA_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

#QUEIXADA
#AMASSO

// O estado de cada dente (3: saiu, o alveolo fica) e o sangue da quebra.
uniform float estado_d[24];
uniform float sangue_d[24];
uniform float dano = 0.0;
uniform sampler2D mapa : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 0.014;
uniform vec3 gengiva_cor : source_color = vec3(0.62, 0.39, 0.40);
uniform vec3 margem_cor : source_color = vec3(0.47, 0.16, 0.19);
uniform vec3 rasgo_cor : source_color = vec3(0.80, 0.60, 0.55);
uniform vec3 sangue_cor : source_color = vec3(0.56, 0.05, 0.04);
uniform vec3 coagulo_cor : source_color = vec3(0.2, 0.015, 0.013);

varying vec4 v_cor;
varying vec2 v_uv2;
varying flat int v_id;
varying vec3 v_obj;
varying vec3 v_n;

void vertex() {
	v_cor = COLOR;
	v_uv2 = UV2;
	v_id = int(UV.y + 0.5);
	v_obj = VERTEX;
	v_n = NORMAL;
	float a = -abre * giro_max * UV.x;
	VERTEX = pivo + girar_x(VERTEX - pivo, a);
	NORMAL = girar_x(NORMAL, a);
	float e;
	VERTEX = amassar(VERTEX, e);
}

void fragment() {
	vec3 n = normalize(v_n);
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec4 m = texture(mapa, v_obj.zy / tile) * bw.x + texture(mapa, v_obj.xz / tile) * bw.y
		+ texture(mapa, v_obj.xy / tile) * bw.z;
	float crista = v_cor.r;
	float papila = v_cor.g;
	float ao = v_cor.b;
	float r = v_uv2.x;
	float perto = v_uv2.y;
	vec3 c = mix(gengiva_cor, margem_cor, crista * 0.65 + papila * 0.25);
	c *= mix(0.84, 1.08, m.r);
	c = mix(c, margem_cor * 0.6, m.g * 0.5);
	c = mix(c, c * vec3(0.82, 0.72, 0.78), smoothstep(0.4, 0.8, m.b) * 0.5);
	// O alveolo: o dente saiu, fica o buraco cheio de sangue e a beira rasgada.
	float saiu = step(2.5, estado_d[v_id]);
	float buraco = saiu * (1.0 - smoothstep(0.82, 1.0, r)) * smoothstep(0.3, 0.7, perto);
	float rasgo = saiu * smoothstep(0.78, 1.0, r) * (1.0 - smoothstep(1.0, 1.45, r))
		* smoothstep(0.2, 0.6, perto);
	c = mix(c, rasgo_cor, rasgo * 0.65);
	// O sangue em volta do dente quebrado, e no geral com o dano.
	float s = max(sangue_d[v_id], dano / 3.0 * 0.6);
	float onde = crista * 0.8 + (1.0 - ao) * 0.6 + (m.b - 0.5) * 0.5 + (1.0 - smoothstep(0.8, 1.6, r)) * 0.4;
	float lim = 1.35 - s * 1.35;
	float cobre = smoothstep(lim - 0.05, lim + 0.05, onde);
	c = mix(c, mix(sangue_cor, coagulo_cor, smoothstep(lim, lim + 0.5, onde) * 0.8), cobre);
	// O alveolo: sangue fundo, escuro no meio e vivo na beira.
	c = mix(c, mix(sangue_cor * 0.7, coagulo_cor * 0.6, smoothstep(0.75, 0.2, r)), buraco);
	ALBEDO = c * mix(0.35, 1.0, ao);
	ROUGHNESS = mix(mix(0.4, 0.3, crista), 0.12, max(cobre, buraco));
	SPECULAR = 0.42;
	AO = ao;
	AO_LIGHT_AFFECT = 0.7;
	SSS_STRENGTH = 0.3 * (1.0 - max(cobre, buraco));
}
"""

const LINGUA_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

#QUEIXADA
#AMASSO

uniform vec3 lingua = vec3(0.0);
uniform float dano = 0.0;
uniform sampler2D mapa : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 lingua_cor : source_color = vec3(0.64, 0.30, 0.32);
uniform vec3 saburra_cor : source_color = vec3(0.66, 0.60, 0.56);
uniform vec3 sangue_cor : source_color = vec3(0.56, 0.05, 0.04);
uniform vec3 coagulo_cor : source_color = vec3(0.22, 0.018, 0.015);

varying vec4 v_cor;
varying vec3 v_obj;
varying float v_ponta;

void vertex() {
	v_cor = COLOR;
	v_obj = VERTEX;
	v_ponta = UV.y;
	VERTEX += lingua * UV.y;
	float a = -abre * giro_max * UV.x;
	VERTEX = pivo + girar_x(VERTEX - pivo, a);
	NORMAL = girar_x(NORMAL, a);
	float e;
	VERTEX = amassar(VERTEX, e);
}

void fragment() {
	// De cima, no espaco da cabeca: na UV da esfera o polo ficava no meio do
	// dorso e a textura fazia aneis em volta dele.
	vec4 m = texture(mapa, v_obj.xz / 0.06);
	float ao = v_cor.b;
	vec3 c = lingua_cor * mix(0.78, 1.12, m.r);
	// A saburra de morto: o dorso coberto de branco-acinzentado, menos na ponta.
	c = mix(c, saburra_cor, smoothstep(0.42, 0.72, m.b) * 0.35 * (1.0 - v_ponta * 0.7));
	c = mix(c, lingua_cor * vec3(1.35, 0.9, 0.9), m.g * 0.5);
	// O sangue que desce da boca empoca na lingua, da ponta para tras.
	float s = dano / 3.0;
	// Com a boca sangrando o sangue desce pela lingua toda, da ponta para tras.
	float onde = v_ponta * 0.6 + (1.0 - ao) * 0.3 + 0.35 + (m.b - 0.5) * 0.4;
	float lim = 1.6 - s * 1.5;
	float cobre = smoothstep(lim - 0.05, lim + 0.05, onde) * step(0.01, s);
	c = mix(c, mix(sangue_cor, coagulo_cor, smoothstep(lim, lim + 0.5, onde) * 0.8), cobre);
	ALBEDO = c * mix(0.55, 1.0, ao);
	ROUGHNESS = mix(mix(0.5, 0.36, m.r), 0.14, cobre);
	SPECULAR = 0.38;
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	SSS_STRENGTH = 0.3;
}
"""

const POCA_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#QUEIXADA

// O nivel da poca (y na malha da cabeca).
uniform float nivel = -0.08;
uniform vec3 sangue_cor : source_color = vec3(0.10, 0.004, 0.004);

varying float v_dentro;
varying vec3 v_obj;

void vertex() {
	v_dentro = COLOR.r;
	VERTEX.y = nivel + sin(TIME * 2.3 + VERTEX.x * 900.0) * 0.00012;
	v_obj = VERTEX;
	float a = -abre * giro_max * UV.x;
	VERTEX = pivo + girar_x(VERTEX - pivo, a);
	NORMAL = girar_x(NORMAL, a);
}

void fragment() {
	if (v_dentro < 0.5) {
		discard;
	}
	ALBEDO = sangue_cor;
	ROUGHNESS = 0.07;
	SPECULAR = 0.5;
	// A superficie treme: a respiracao, o golpe.
	vec2 o = vec2(sin(TIME * 3.1 + v_obj.z * 1300.0), cos(TIME * 2.7 + v_obj.x * 1500.0)) * 0.05;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(o.x, 0.0, o.y, 0.0)).xyz);
}
"""

static var _malhas: Dictionary = {}
static var _carregou := false
static var _id_por_fdi: Dictionary = {}

## Liga a quebra dos dentes (o principal liga ao receber o vidro).
var quebra_dentes := false

var _cab: CabecaDoPadre
var _mat_dentes: ShaderMaterial
var _mat_gengiva: ShaderMaterial
var _mat_lingua: ShaderMaterial
var _mat_poca: ShaderMaterial
var _estado := PackedFloat32Array()
var _versao := PackedFloat32Array()
var _sangue := PackedFloat32Array()
var _golpes := 0
var _abre := 0.0
var _voando: Array[Dictionary] = []
var _pendurado: DentePendurado
var _livres: Array[MeshInstance3D] = []
## O vidro em que as pecas batem: o carro e a cabecada (que sabe o plano e se o
## vidro ainda existe).
var _carro: Node3D
var _cabecada: CabecadaDoPadre
var _rng := RandomNumberGenerator.new()


## A boca nova existe (e nao foi desligada com `--boca-velha`).
static func disponivel() -> bool:
	if OS.get_cmdline_user_args().has("--boca-velha"):
		return false
	return _carregar()


static func _carregar() -> bool:
	if _carregou:
		return not _malhas.is_empty()
	_carregou = true
	var cena := load(CENA) as PackedScene
	if cena == null:
		push_warning("DentesDoPadre: %s nao carrega (rode tools/gerar_boca_padre.py)" % CENA)
		return false
	var raiz := cena.instantiate()
	for mi: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		_malhas[String(mi.name)] = (mi as MeshInstance3D).mesh
	raiz.free()
	for d: Dictionary in BocaPadreDados.DENTES:
		_id_por_fdi[int(d["fdi"])] = int(d["id"])
	return _malhas.has("Dentes")


## Monta a boca nova dentro de `cab` (no espaco da malha da cabeca).
static func montar(cab: CabecaDoPadre) -> DentesDoPadre:
	if not _carregar():
		return null
	var d := DentesDoPadre.new()
	d.name = "BocaNova"
	d._cab = cab
	cab.add_child(d)
	d._montar()
	return d


func _montar() -> void:
	_rng.seed = 6173
	_estado.resize(24)
	_versao.resize(24)
	_sangue.resize(24)
	for i in 24:
		_estado[i] = 0.0
		_versao[i] = 0.0
		_sangue[i] = 0.0
	_mat_dentes = _material(&"dentes", DENTES_SHADER)
	_mat_dentes.set_shader_parameter(&"esmalte", load(ESMALTE))
	_mat_gengiva = _material(&"gengiva", GENGIVA_SHADER)
	_mat_gengiva.set_shader_parameter(&"mapa", load(GENGIVA))
	_mat_lingua = _material(&"lingua", LINGUA_SHADER)
	_mat_lingua.set_shader_parameter(&"mapa", load(LINGUA))
	_mat_poca = _material(&"poca", POCA_SHADER)
	_mat_poca.set_shader_parameter(&"nivel", POCA_SECA)
	for par: Array in [["Dentes", _mat_dentes], ["Gengiva", _mat_gengiva], ["Lingua", _mat_lingua],
			["Poca", _mat_poca]]:
		var mi := MeshInstance3D.new()
		mi.name = par[0]
		mi.mesh = _malhas.get(par[0])
		mi.material_override = par[1]
		# Dentro da boca a sombra do proprio dente e ruido; a oclusao ja escurece.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# As pecas que voam, prontas: o mesmo material e o mesmo formato da malha
	# dos dentes, sem pipeline novo no golpe.
	for i in PECAS_MAX:
		var p := MeshInstance3D.new()
		p.name = "Peca%d" % i
		p.top_level = true
		p.visible = false
		p.material_override = _mat_dentes
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_livres.append(p)
	_enviar_estado()
	set_process(false)


func _material(nome: StringName, codigo: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CabecaDoPadre._shader(StringName("boca_nova_" + nome), codigo)
	m.set_shader_parameter(&"pivo", CabecaDoPadre.PIVO)
	m.set_shader_parameter(&"giro_max", CabecaDoPadre.GIRO_QUEIXADA)
	return m


## A queixada: a mesma abertura da pele.
func abrir(abre: float) -> void:
	_abre = abre
	for m: ShaderMaterial in [_mat_dentes, _mat_gengiva, _mat_lingua, _mat_poca]:
		m.set_shader_parameter(&"abre", abre)


## A ponta da lingua (m), a mola do `CabecaDoPadre._process`.
func por_lingua(v: Vector3) -> void:
	_mat_lingua.set_shader_parameter(&"lingua", v)


## O dano da cara (0..3) e os amassados de agora. Quando o dano cruza o inteiro,
## os dentes daquele golpe quebram.
func por_dano(nivel: float, cs: PackedVector4Array, fs: PackedFloat32Array) -> void:
	for m: ShaderMaterial in [_mat_dentes, _mat_gengiva, _mat_lingua]:
		m.set_shader_parameter(&"amassos", cs)
		m.set_shader_parameter(&"fundos", fs)
		m.set_shader_parameter(&"n_amassos", mini(cs.size(), 6))
		m.set_shader_parameter(&"dano", nivel)
	_mat_poca.set_shader_parameter(&"nivel", lerpf(POCA_SECA, POCA_CHEIA,
		clampf(nivel / 3.0, 0.0, 1.0)))
	if nivel < 0.5 and _golpes > 0:
		reiniciar()
	if not quebra_dentes:
		return
	var k := mini(floori(nivel + 0.0001), QUEBRA_POR_GOLPE.size())
	while _golpes < k:
		_quebrar(_golpes)
		_golpes += 1


## Todos inteiros de novo (a bancada volta ao dano 0).
func reiniciar() -> void:
	_golpes = 0
	for i in 24:
		_estado[i] = 0.0
		_versao[i] = 0.0
		_sangue[i] = 0.0
	for p: Dictionary in _voando:
		_recolher(p["no"])
	_voando.clear()
	if _pendurado != null and is_instance_valid(_pendurado):
		_pendurado.queue_free()
	_pendurado = null
	_enviar_estado()


## Quantos dentes estao quebrados agora (lascado, partido ou fora).
func quebrados() -> int:
	var n := 0
	for e: float in _estado:
		if e > 0.5:
			n += 1
	return n


## O estado de um dente pelo numero FDI (0 inteiro .. 3 fora).
func estado_de(fdi: int) -> int:
	return int(_estado[_id_por_fdi.get(fdi, 0)])


## O vidro ainda esta inteiro? Depois do estouro o padre fica fora do carro e o
## `vidro_existe` da cabecada segue ligado (o capuz ainda bate no plano); quem
## diz que o vidro sumiu e o `vidro_inteiro` (desligado no `abrir_buraco`).
## Sem ele (a cabecada de antes), vale o `vidro_existe`.
static func vidro_inteiro(cab: CabecadaDoPadre) -> bool:
	if cab == null:
		return false
	var v: Variant = cab.get(&"vidro_inteiro")
	return bool(v) if v != null else cab.vidro_existe


## O vidro em que as pecas batem, e a quebra ligada.
func no_vidro(carro: Node3D, cab: CabecadaDoPadre) -> void:
	_carro = carro
	_cabecada = cab
	quebra_dentes = true


func _quebrar(g: int) -> void:
	var soltas := 0
	var com_vidro := not _vidro().is_empty()
	for par: Array in QUEBRA_POR_GOLPE[g]:
		var id: int = _id_por_fdi.get(int(par[0]), -1)
		if id < 0:
			continue
		var de := int(_estado[id])
		var para := int(par[1])
		if para <= de:
			continue
		var peca := &""
		match [de, para]:
			[0, 1]:
				peca = &"canto"
			[0, 2]:
				peca = &"coroa0"
			[1, 2]:
				peca = &"coroa1"
			[0, 3]:
				peca = &"inteiro"
		_estado[id] = float(para)
		_versao[id] = float(para) if para < 3 else -1.0
		_sangue[id] = SANGUE_QUEBRADO
		for viz: int in [id - 1, id + 1, (id + 12) % 24]:
			if viz >= 0 and viz < 24 and ((viz < 12) == (id < 12) or viz == (id + 12) % 24):
				_sangue[viz] = maxf(_sangue[viz], SANGUE_VIZINHO)
		if para == 3 and int(par[0]) == PENDURADO and _pendurar(id):
			continue
		# A primeira de cada um dos dois primeiros golpes gruda no vidro.
		var gruda := com_vidro and g < CACOS.size() and soltas == 0
		if peca != &"" and _soltar(id, peca, GRUDADA_ESCALA if gruda else 1.0, gruda):
			soltas += 1
	if com_vidro and g < CACOS.size():
		_cacos(int(CACOS[g]))
	_enviar_estado()
	_som(StringName("dente_quebra_%d" % (g + 1)), -5.0 + 2.5 * float(g))
	print("[dentes] golpe %d: %d quebrados, %d pecas no ar" % [g + 1, quebrados(), soltas])


## Um som da boca (`tools/gerar_audio_cabecada.py`), com um fio de acaso no tom.
func _som(nome: StringName, db: float) -> void:
	if not is_inside_tree():
		return
	var st := AudioDirector.stream(nome)
	if st == null:
		push_warning("[dentes] som ausente: %s" % nome)
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.93, 1.07)
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _enviar_estado() -> void:
	_mat_dentes.set_shader_parameter(&"versao_de", _versao)
	_mat_dentes.set_shader_parameter(&"sangue_d", _sangue)
	_mat_gengiva.set_shader_parameter(&"estado_d", _estado)
	_mat_gengiva.set_shader_parameter(&"sangue_d", _sangue)


## Cacos de esmalte grudando no vidro em volta da boca: lascas de canto de
## dentes quaisquer, menores, jogadas da boca contra o vidro.
func _cacos(n: int) -> void:
	var boca := _cab.global_transform * Vector3(0.0, -0.058, -0.095)
	var ids: Array[int] = []
	for d: Dictionary in BocaPadreDados.DENTES:
		if (d["pecas"] as Dictionary).has(&"canto"):
			ids.append(int(d["id"]))
	for k in n:
		if ids.is_empty():
			return
		var id: int = ids[_rng.randi() % ids.size()]
		var onde := boca + _cab.global_basis * Vector3(_rng.randf_range(-0.012, 0.012),
			_rng.randf_range(-0.006, 0.004), 0.0)
		_soltar(id, &"canto", _rng.randf_range(CACO_ESCALA.x, CACO_ESCALA.y), true, onde)


## O dente `id` sai e fica pendurado pela gengiva.
func _pendurar(id: int) -> bool:
	var malha: Mesh = _malhas.get("Lasca_%d_inteiro" % id)
	var info: Dictionary = BocaPadreDados.DENTES[id]
	var pecas: Dictionary = info["pecas"]
	if malha == null or not pecas.has(&"inteiro") or _livres.is_empty() or not is_inside_tree():
		return false
	var mi: MeshInstance3D = _livres.pop_back()
	mi.mesh = malha
	var centro: Vector3 = (pecas[&"inteiro"] as Array)[0]
	var a := -_abre * CabecaDoPadre.GIRO_QUEIXADA * float(info["arcada"])
	var giro := Basis(Vector3.RIGHT, a)
	mi.global_transform = _cab.global_transform * Transform3D(giro,
		CabecaDoPadre.PIVO + giro * (centro - CabecaDoPadre.PIVO))
	mi.visible = true
	mi.set_instance_shader_parameter(&"sangue_peca", 0.42)
	var colo: Vector3 = info["centro"]
	var fora: Vector3 = info["fora"]
	var eixo: Vector3 = info["eixo"]
	var frente := -_cab.global_basis.z.normalized()
	var na_raiz := colo - eixo * RAIZ_PRESA
	_pendurado = DentePendurado.new()
	add_child(_pendurado)
	_pendurado.soltar(_cab, mi, colo + fora * 0.0008, na_raiz - centro, eixo,
		frente * 0.3 + Vector3.DOWN * 0.15)
	return true


func _soltar(id: int, qual: StringName, escala: float = 1.0, gruda_ja: bool = false,
		onde: Vector3 = Vector3.INF) -> bool:
	var malha: Mesh = _malhas.get("Lasca_%d_%s" % [id, qual])
	var info: Dictionary = BocaPadreDados.DENTES[id]
	var pecas: Dictionary = info["pecas"]
	if malha == null or not pecas.has(qual) or _livres.is_empty() or not is_inside_tree():
		return false
	var mi: MeshInstance3D = _livres.pop_back()
	mi.mesh = malha
	# O centro da peca na malha da cabeca, com a queixada de agora se for de baixo.
	var centro: Vector3 = (pecas[qual] as Array)[0]
	var a := -_abre * CabecaDoPadre.GIRO_QUEIXADA * float(info["arcada"])
	var giro := Basis(Vector3.RIGHT, a)
	var local := CabecaDoPadre.PIVO + giro * (centro - CabecaDoPadre.PIVO)
	mi.global_transform = _cab.global_transform * Transform3D(giro, local)
	if onde != Vector3.INF:
		# Um caco solto: onde a cena pediu, virado a esmo.
		var b := Basis.from_euler(Vector3(_rng.randf_range(-PI, PI), _rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI))) * mi.global_basis
		mi.global_transform = Transform3D(b, onde)
	if escala != 1.0:
		mi.global_transform = Transform3D(mi.global_basis * Basis.from_scale(Vector3.ONE * escala), mi.global_position)
	mi.visible = true
	# A grudada leva menos sangue: o esmalte branco no sangue do vidro e o que se ve.
	mi.set_instance_shader_parameter(&"sangue_peca", _rng.randf_range(0.2, 0.4) if gruda_ja
		else _rng.randf_range(0.3, 0.75))
	# Sai da boca para a frente da cara (-Z da cabeca) e para fora do dente, com
	# um tanto de acaso, e girando.
	var frente := -_cab.global_basis.z.normalized()
	var fora := (_cab.global_basis * (info["fora"] as Vector3)).normalized()
	var acaso := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	var v := (frente * 0.7 + fora * 0.35 + Vector3.DOWN * 0.25 + acaso * 0.35).normalized() \
		* _rng.randf_range(PECA_SAI.x, PECA_SAI.y)
	var w := acaso.normalized() * _rng.randf_range(PECA_GIRA.x, PECA_GIRA.y) \
		if acaso.length() > 0.01 else Vector3.UP * PECA_GIRA.x
	var vol := float((pecas[qual] as Array)[1])
	var raio := pow(3.0 * vol / (4.0 * PI), 1.0 / 3.0) * 0.001 * _cab.global_basis.get_scale().x * escala
	var ja_grudada := false
	if gruda_ja:
		# A cara esta colada no vidro no golpe: a lasca fica no sangue do vidro
		# bem na frente da boca, e dali escorrega. Voando, ela caia antes de
		# encostar e grudava na borda de baixo do quadro, fora da lente.
		var vd := _vidro()
		if not vd.is_empty():
			var o: Vector3 = vd[0]
			var n: Vector3 = vd[1]
			var pp := mi.global_position
			mi.global_position = pp - n * ((pp - o).dot(n) - raio)
			v = Vector3.ZERO
			w = Vector3.ZERO
			ja_grudada = true
			_som(&"dente_cai", -18.0)
	_voando.append({"no": mi, "v": v, "w": w, "t": 0.0, "r": raio, "grudada": ja_grudada,
		"gruda": gruda_ja or _rng.randf() < PECA_GRUDA, "gruda_ja": gruda_ja,
		"escorre": _rng.randf_range(PECA_ESCORRE.x, PECA_ESCORRE.y), "toques": 0})
	set_process(true)
	return true


func _recolher(mi: MeshInstance3D) -> void:
	mi.visible = false
	mi.mesh = null
	if not _livres.has(mi):
		_livres.append(mi)


## O plano do vidro no mundo: [ponto, normal para fora], ou vazio sem vidro.
func _vidro() -> Array:
	if _cabecada == null or _carro == null or not is_instance_valid(_carro) or not vidro_inteiro(_cabecada):
		return []
	var o := _carro.to_global(_cabecada.ponto_no_vidro())
	var n := (_carro.global_basis * _cabecada.normal()).normalized()
	return [o, n]


func _process(delta: float) -> void:
	if _voando.is_empty():
		set_process(false)
		return
	if delta <= 0.0:
		return
	var vidro := _vidro()
	var fim: Array[Dictionary] = []
	for p: Dictionary in _voando:
		var mi: MeshInstance3D = p["no"]
		p["t"] = float(p["t"]) + delta
		var v: Vector3 = p["v"]
		var pos := mi.global_position
		var r: float = p["r"]
		if bool(p["grudada"]):
			if vidro.is_empty():
				# O vidro estourou: ela cai com ele, e ainda se ve cair.
				p["grudada"] = false
				p["t"] = minf(float(p["t"]), PECA_VIDA - 1.2)
			else:
				# Grudada no sangue do vidro, escorregando devagar e parando.
				v = Vector3.DOWN * float(p["escorre"])
				p["escorre"] = maxf(0.0, float(p["escorre"]) - delta * 0.006)
				pos += v * delta
				mi.global_position = pos
				continue
		v += Vector3.DOWN * GRAVIDADE * delta
		v *= exp(-0.8 * delta)
		pos += v * delta
		if not vidro.is_empty():
			var o: Vector3 = vidro[0]
			var n: Vector3 = vidro[1]
			var d := (pos - o).dot(n) - r
			if d < 0.0:
				pos -= n * d
				var vn := v.dot(n)
				if vn < 0.0:
					var vt := v - n * vn
					p["toques"] = int(p["toques"]) + 1
					if int(p["toques"]) == 1 and vn < -0.15:
						_som(&"dente_cai", -16.0 + 6.0 * clampf(-vn, 0.0, 1.0))
					if bool(p["gruda"]) and ((bool(p["gruda_ja"]) and int(p["toques"]) >= 1)
							or (int(p["toques"]) >= 2 and vt.length() < 0.4)):
						p["grudada"] = true
						p["w"] = Vector3.ZERO
						var cam := get_viewport().get_camera_3d()
						print("[dentes] lasca grudou no vidro: %.1f mm, a %.2f m da lente, tela %s" % [
							float(p["r"]) * 2000.0, cam.global_position.distance_to(pos) if cam else -1.0,
							cam.unproject_position(pos) if cam else Vector2.ZERO])
					v = vt * maxf(0.0, 1.0 - PECA_ATRITO * delta) - n * vn * PECA_QUIQUE
					p["w"] = (p["w"] as Vector3) * 0.6
		p["v"] = v
		var w: Vector3 = p["w"]
		var b := mi.global_basis
		if w.length() > 0.001:
			b = Basis(w.normalized(), w.length() * delta) * b
		mi.global_transform = Transform3D(b, pos)
		if float(p["t"]) > PECA_VIDA:
			fim.append(p)
	for p: Dictionary in fim:
		_recolher(p["no"])
		_voando.erase(p)

## O braco AAA do padre principal: o braco esculpido (manga rasgada, faixas,
## antebraco podre e a mao em garra) no lugar dos tubos do `BracoVivo`.
##
## Por que existe
## --------------
## O `BracoVivo` com `MaosPodres` e uma malha de tubos refeita a cada quadro:
## serve para qualquer pose, mas a 4 cm da lente e uma luva de cera. O usuario
## trouxe um braco esculpido por IA (manga, faixas com pontas soltas, a mao com
## unhas pretas) e pediu esqueleto, fisica e os dois bracos do padre com ele.
##
## Como funciona
## -------------
## O modelo foi riggado no Blender (`tools/blender_braco_padre/`): 43 ossos,
## braco -> antebraco -> antebraco_giro -> mao -> dedos (metacarpo e tres
## falanges; o polegar com tres), e sete cadeias de pano (a manga e as faixas).
## O esquerdo e o direito espelhado no Blender, com os mesmos nomes de osso.
##
## E um `BracoVivo`: a cena continua falando so de pegada (`ir`, `alvo`,
## `pular`, `pega`, `levar`), ombro e polo, e continua guardando a mao num
## `Array[BracoVivo]`. Muda so o `refazer`: em vez de montar malha, poe os
## ossos.
##   - A mao sai da pegada: o `o` e o meio da face da PALMA na linha dos nos,
##     `d` do punho para os nos, `dorso` a normal das costas, como na
##     `MaoPosada`. O punho sai dali.
##   - O cotovelo e um IK de dois ossos entre o ombro e o punho, dobrando para
##     `polo`. Alvo alem do alcance: o braco sai da manga (o ombro anda na
##     direcao da mao), e nao estica o osso.
##   - O giro do pulso se divide: metade no `antebraco_giro`, que leva a metade
##     de baixo do antebraco, e o resto na mao. Sem isso o pulso torcia como
##     papel de bala.
##   - Os dedos seguem a pose da `MaoPosada` ([mcp, pip, dip, abre] e o
##     polegar), descontada a dobra que o modelo ja tem (a `relaxada` e o
##     repouso dele). Por cima, os dedos vivos da `MaoPosada.viva` e a inercia:
##     a mao que acelera deixa os dedos para tras, com mola.
##   - O pano (a manga e as pontas das faixas) e um `SpringBoneSimulator3D`:
##     cai com a gravidade, balanca com o carro e nao entra no braco (capsulas
##     no braco e no antebraco).
##
## O material e proprio (`_material`): as texturas do modelo mais os dois
## parametros por instancia que a cena ja usa nas maos do padre, `sangue` (o do
## vidro, na palma e nas polpas) e `perto_da_lente` (o escuro da mao colada na
## cara). A cena os poe neste no; o `refazer` os passa para a pele.
class_name BracoDoPadre
extends BracoVivo

const CENA_D := "res://assets/monstros/padre/mao_aaa/braco_padre_aaa_d.glb"
const CENA_E := "res://assets/monstros/padre/mao_aaa/braco_padre_aaa_e.glb"
## O modelo e comprido (0,87 m do ombro ao punho, a mao 24 cm): a escala o leva
## para perto do alcance do padre de dois metros, e a mao continua grande.
const ESCALA := 0.75
## Meia espessura da palma na linha dos nos (m, no modelo): as juntas ficam no
## miolo, e o `o` da pegada e a face da palma.
const MEIA_PALMA := 0.017
## Quanto o braco pode sair da manga quando o alvo passa do alcance (m, no
## mundo). Alem disso a mao para no alcance.
const SAI_DA_MANGA := 0.14
## O giro do pulso que o antebraco aceita (graus), e a parte dele que vai para
## o `antebraco_giro`.
const GIRO_MAX := 130.0
const GIRO_NO_ANTEBRACO := 0.5
const DEDOS := ["indicador", "medio", "anelar", "minimo"]
## A pose que o modelo tem parado: a pose pedida e medida contra ela.
const REPOUSO := &"relaxada"
## O pano: rigidez, arrasto, gravidade (m/s^2) e raio das juntas (m, modelo).
const PANO_RIGIDEZ := 0.8
const PANO_ARRASTO := 0.5
const PANO_GRAVIDADE := 3.0
const PANO_RAIO := 0.008
## As capsulas que o pano nao atravessa: raio do braco e do antebraco (m, modelo).
const BRACO_RAIO := 0.03
## A inercia dos dedos: graus de dobra por m/s^2 de aceleracao da mao contra o
## dorso, a mola e o amortecimento, e o limite (graus).
const DEDOS_INERCIA := 1.4
const DEDOS_MOLA := 160.0
const DEDOS_AMORTECE := 18.0
const DEDOS_INERCIA_MAX := 22.0
## A cor do sangue do vidro (a mesma das `MaosPodres`).
const SANGUE_COR := Color(0.2, 0.018, 0.012)

const SHADER := """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D cor_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
// glTF: rugosidade no verde, metal no azul.
uniform sampler2D mr_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 sangue_cor : source_color = vec3(0.2, 0.018, 0.012);
uniform float normal_forca = 1.0;
// Por mao (`set_instance_shader_parameter`, passados pelo `BracoDoPadre`).
instance uniform float sangue = 0.0;
instance uniform float perto_da_lente = 0.0;
// O dorso da mao no espaco do modelo, posto a cada quadro: a palma e o lado
// contrario, e e nela que o sangue do vidro pega.
instance uniform vec3 dorso_modelo = vec3(1.0, 0.0, 0.0);

varying float palma;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	palma = smoothstep(0.25, -0.7, dot(NORMAL, normalize(dorso_modelo)));
}

void fragment() {
	vec3 c = texture(cor_tex, UV).rgb;
	vec4 mr = texture(mr_tex, UV);
	float rug = mr.g;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_forca;
	SPECULAR = 0.4;
	if (sangue > 0.0) {
		float n = ruido(UV * 38.0) * 0.6 + ruido(UV * 97.0 + 3.1) * 0.4;
		// Em manchas: a palma que apertou o vidro pega mais, mas nunca inteira.
		float k = smoothstep(0.66, 0.86, n * 0.8 + palma * 0.32) * sangue;
		c = mix(c, sangue_cor * (0.7 + 0.6 * n) * mix(1.0, 0.6, palma), k);
		rug = mix(rug, mix(0.3, 0.55, palma), k);
	}
	float escuro = mix(1.0, 0.1 + 0.9 * smoothstep(0.015, 0.12, length(VERTEX)), perto_da_lente);
	ALBEDO = c * escuro;
	SPECULAR *= escuro;
	ROUGHNESS = clamp(rug, 0.2, 1.0);
	METALLIC = 0.0;
	SSS_STRENGTH = 0.1;
}
"""

static var _mat: ShaderMaterial
static var _cenas: Dictionary = {}
## Os bracos ja montados e desenhados uma vez (`aquecer`), esperando o `novo`.
## Montar na hora da janela custava um quadro de 620 ms: o glb, as texturas e o
## pipeline da pele com esqueleto compilando no quadro em que a mao aparece.
static var _prontos: Array[BracoDoPadre] = []

var _modelo: Node3D
var _esq: Skeleton3D
var _pele_mi: MeshInstance3D
var _pano: SpringBoneSimulator3D
## O esqueleto no espaco do modelo (fixo, lido uma vez).
var _esq_no_modelo := Transform3D.IDENTITY
## Ossos por nome.
var _o: Dictionary = {}
## Repouso global (espaco do esqueleto) de cada osso.
var _rg: Array[Transform3D] = []
## A mao de repouso: face da palma na linha dos nos, do punho para os nos, o
## dorso e o lado do polegar (espaco do esqueleto).
var _o_rep := Vector3.ZERO
var _d_rep := Vector3.ZERO
var _dorso_rep := Vector3.ZERO
var _lado_rep := Vector3.ZERO
var _dobra_rep := Vector3.ZERO
var _l1: float = 0.0
var _l2: float = 0.0
var _giro_no_antebraco: float = 0.0
## Por osso de dedo: eixo de dobra e eixo de abrir no espaco local do osso, e a
## dobra de repouso (graus).
var _eixo_dobra: Dictionary = {}
var _eixo_abre: Dictionary = {}
var _dobra_de_repouso: Dictionary = {}
var _pose_repouso: Dictionary = {}
## A inercia dos dedos (graus e graus/s) e a mao nos dois ultimos quadros.
var _inercia: float = 0.0
var _inercia_v: float = 0.0
var _punho_ant := Vector3.INF
var _vel_ant := Vector3.ZERO
var _ultimo_t: float = -1.0


## Um braco do padre (o direito ou o esquerdo), escondido, na camada das maos
## de primeira pessoa, sem pai. `nome` como o do `BracoVivo`. Se o `aquecer`
## ja montou um desse lado, e ele.
static func novo(nome: String, e_direita: bool) -> BracoDoPadre:
	for k in _prontos.size():
		var p := _prontos[k]
		if is_instance_valid(p) and p.direita == e_direita:
			_prontos.remove_at(k)
			if p.get_parent() != null:
				p.get_parent().remove_child(p)
			p.name = nome
			p.visible = false
			p.layers = CAMADA
			p.pegada = {}
			if p._pano != null:
				p._pano.reset()
			return p
	return _montado(nome, e_direita)


## Monta os dois bracos debaixo do preto e os desenha na frente da lente
## (`onde`, global, dentro do quadro e atras do chao), para o glb, as texturas
## e o pipeline da pele ficarem prontos antes da janela. `ligar` falso esconde;
## eles ficam guardados (vivos: o pipeline sai do cache quando o ultimo dono
## morre) ate o `novo`.
static func aquecer(ligar: bool, pai: Node3D, onde: Vector3) -> void:
	if ligar:
		for lado: bool in [false, true]:
			var ja := false
			for p: BracoDoPadre in _prontos:
				if is_instance_valid(p) and p.direita == lado:
					ja = true
			if ja:
				continue
			var b := _montado("BracoPronto%s" % ("D" if lado else "E"), lado)
			pai.add_child(b)
			_prontos.append(b)
	for k in _prontos.size():
		var b := _prontos[k]
		if not is_instance_valid(b) or b.get_parent() != pai:
			continue
		b.visible = ligar
		# nas duas camadas: a do mundo (as luzes dele) e a das maos
		b.layers = 1 | CAMADA
		if ligar:
			var aqui := pai.to_local(onde) + Vector3(0.5 * float(k), 0.0, 0.0)
			b.ombro = aqui + Vector3(0.0, 0.5, 0.0)
			b.pular(BracoVivo.pega(aqui, Vector3.UP, Vector3.BACK, &"relaxada"))
			b.passo(0.0)


static func _montado(nome: String, e_direita: bool) -> BracoDoPadre:
	var b := BracoDoPadre.new()
	b.name = nome
	b.direita = e_direita
	b._semente = 3.7 if e_direita else 0.0
	# Quem mede a mao sem a malha (o agarrao conta a folga dos dedos na lente
	# com a `MaoPosada`) mede a de dedos longos.
	b.forma = MaosPodres.FORMA
	b.layers = CAMADA
	b.visible = false
	b._montar()
	return b


static func _cena(direita_: bool) -> PackedScene:
	var caminho := CENA_D if direita_ else CENA_E
	if not _cenas.has(caminho):
		_cenas[caminho] = load(caminho) as PackedScene
	return _cenas[caminho]


## O material da pele (os dois bracos dividem: as texturas sao as do direito).
static func material_aaa() -> ShaderMaterial:
	if _mat != null:
		return _mat
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter(&"sangue_cor", SANGUE_COR)
	var ps := _cena(true)
	if ps != null:
		var r := ps.instantiate()
		var mis := r.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			var m := (mis[0] as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
			if m != null:
				_mat.set_shader_parameter(&"cor_tex", m.albedo_texture)
				_mat.set_shader_parameter(&"normal_tex", m.normal_texture)
				_mat.set_shader_parameter(&"mr_tex", m.roughness_texture)
		r.free()
	return _mat


func _montar() -> void:
	var ps := _cena(direita)
	if ps == null:
		push_error("BracoDoPadre: sem a cena do braco")
		return
	_modelo = ps.instantiate() as Node3D
	_modelo.name = "Modelo"
	add_child(_modelo)
	_esq = _modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_pele_mi = _modelo.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_pele_mi.material_override = material_aaa()
	_pele_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var t := Transform3D.IDENTITY
	var n: Node = _esq
	while n != _modelo:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	_esq_no_modelo = t
	for i in _esq.get_bone_count():
		_o[_esq.get_bone_name(i)] = i
		_rg.append(_esq.get_bone_global_rest(i))
	_ler_repouso()
	_montar_pano()


func _p(nome: String) -> Vector3:
	return _rg[int(_o[nome])].origin


func _ler_repouso() -> void:
	var ombro_ := _p("braco")
	var cot := _p("antebraco")
	var pun := _p("mao")
	_l1 = ombro_.distance_to(cot)
	_l2 = cot.distance_to(pun)
	_giro_no_antebraco = cot.distance_to(_p("antebraco_giro"))
	var k := Vector3.ZERO
	for d: String in DEDOS:
		k += _p(d + "_1")
	k /= float(DEDOS.size())
	_d_rep = (k - pun).normalized()
	# O lado do polegar sai da linha dos nos (do minimo ao indicador); o dorso,
	# dele e de `d`, com a mao de cada lado.
	var lado := (_p("indicador_1") - _p("minimo_1"))
	lado = (lado - _d_rep * lado.dot(_d_rep)).normalized()
	_lado_rep = lado
	_dorso_rep = (_d_rep.cross(lado) * (1.0 if direita else -1.0)).normalized()
	_o_rep = k - _dorso_rep * MEIA_PALMA
	# A dobra do cotovelo: o antebraco vai para o lado do polegar (a pegada
	# neutra, de martelo).
	var yb := (cot - ombro_).normalized()
	_dobra_rep = yb.cross(lado).normalized()
	_pose_repouso = MaoPosada.pose(REPOUSO)
	# Os eixos de cada osso de dedo: dobrar e girar em volta do eixo que e
	# perpendicular ao osso e ao dorso; abrir e girar em volta do dorso.
	var nomes: Array[String] = []
	for d: String in DEDOS:
		for j in [1, 2, 3]:
			nomes.append("%s_%d" % [d, j])
	for j in [1, 2, 3]:
		nomes.append("polegar_%d" % j)
	for nome: String in nomes:
		var i: int = _o[nome]
		var pai := _esq.get_bone_parent(i)
		var dir := _dir_osso(i)
		var dorso := _dorso_rep
		if nome.begins_with("polegar"):
			# a unha do polegar olha para o dorso e para fora dele
			dorso = (_dorso_rep + _lado_rep * 0.8).normalized()
		var eixo := dir.cross(dorso).normalized()
		var inv := _rg[i].basis.inverse()
		_eixo_dobra[i] = (inv * eixo).normalized()
		_eixo_abre[i] = (inv * dorso).normalized()
		var dir_pai := _dir_osso(pai)
		_dobra_de_repouso[i] = -rad_to_deg(dir_pai.signed_angle_to(dir, eixo))


## A direcao do osso no repouso: do inicio dele ao inicio do filho (o de mesmo
## prefixo), ou o Y do osso.
func _dir_osso(i: int) -> Vector3:
	var filhos := _esq.get_bone_children(i)
	for f: int in filhos:
		var nf := _esq.get_bone_name(f)
		if not (nf.begins_with("faixa") or nf.begins_with("manga")):
			if _esq.get_bone_name(i) == "mao" and not nf.begins_with("medio"):
				continue
			return (_rg[f].origin - _rg[i].origin).normalized()
	return _rg[i].basis.y.normalized()


func _montar_pano() -> void:
	if OS.get_cmdline_user_args().has("--braco-sem-pano"):
		return
	var cadeias: Dictionary = {}
	for nome: String in _o.keys():
		if nome.begins_with("manga_") or nome.begins_with("faixa_"):
			var base := nome.substr(0, nome.rfind("_"))
			var n := int(nome.substr(nome.rfind("_") + 1))
			cadeias[base] = maxi(int(cadeias.get(base, 0)), n)
	if cadeias.is_empty():
		return
	_pano = SpringBoneSimulator3D.new()
	_pano.name = "Pano"
	_esq.add_child(_pano)
	_pano.setting_count = cadeias.size()
	var k := 0
	for base: String in cadeias.keys():
		var n: int = cadeias[base]
		_pano.set_root_bone_name(k, base + "_1")
		_pano.set_end_bone_name(k, "%s_%d" % [base, n])
		_pano.set_extend_end_bone(k, true)
		var ult: int = _o["%s_%d" % [base, n]]
		var pen: int = _o["%s_%d" % [base, maxi(n - 1, 1)]]
		_pano.set_end_bone_length(k, maxf(_rg[ult].origin.distance_to(_rg[pen].origin), 0.02))
		_pano.set_stiffness(k, PANO_RIGIDEZ)
		_pano.set_drag(k, PANO_ARRASTO)
		_pano.set_gravity(k, PANO_GRAVIDADE)
		_pano.set_gravity_direction(k, Vector3.DOWN)
		_pano.set_radius(k, PANO_RAIO)
		_pano.set_enable_all_child_collisions(k, true)
		k += 1
	for par: Array in [["braco", "antebraco"], ["antebraco", "mao"]]:
		var a: int = _o[par[0]]
		var b: int = _o[par[1]]
		var cap := SpringBoneCollisionCapsule3D.new()
		cap.bone_name = par[0]
		cap.radius = BRACO_RAIO
		var comp := _rg[a].origin.distance_to(_rg[b].origin)
		cap.height = comp + BRACO_RAIO * 2.0
		var dir_local := (_rg[a].basis.inverse() * (_rg[b].origin - _rg[a].origin)).normalized()
		cap.rotation_offset = Quaternion(Vector3.UP, dir_local)
		cap.position_offset = dir_local * comp * 0.5
		_pano.add_child(cap)


## Monta a pose: nao ha malha a refazer, so ossos.
func refazer() -> void:
	if pegada.is_empty() or _esq == null:
		return
	var agora := _t
	var dt := agora - _ultimo_t if _ultimo_t >= 0.0 else 0.0
	_ultimo_t = agora
	var treme := Vector3(sin(_t * 83.0) + 0.5 * sin(_t * 37.0),
		sin(_t * 71.0 + 1.3) + 0.5 * sin(_t * 29.0),
		sin(_t * 97.0 + 2.1)) * TREMOR * tremor
	var o_bv: Vector3 = (pegada["o"] as Vector3) + treme
	# O modelo: so escala, e o ombro do esqueleto no `ombro` da cena.
	var s := ESCALA
	var ombro_sk := _p("braco")
	var base := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
	var no_esq := base * _esq_no_modelo
	_modelo.transform = Transform3D(base.basis, ombro - no_esq.basis * ombro_sk
		- (_esq_no_modelo.origin * s))
	var tx := _modelo.transform * _esq_no_modelo
	var inv := tx.affine_inverse()
	# A mao, no espaco do esqueleto.
	var o := inv * o_bv
	var d := (inv.basis * (pegada["d"] as Vector3)).normalized()
	var dorso := (inv.basis * (pegada["dorso"] as Vector3))
	dorso = (dorso - d * dorso.dot(d)).normalized()
	var r_mao := _referencial(d, dorso) * _referencial(_d_rep, _dorso_rep).inverse()
	var mao_rg := _rg[int(_o["mao"])]
	var punho := o + r_mao * (mao_rg.origin - _o_rep)
	# O cotovelo (IK de dois ossos), com o braco saindo da manga se precisar.
	var alcance := (_l1 + _l2) * 0.995
	var sh := ombro_sk
	var para := punho - sh
	if para.length() > alcance:
		var sai := minf(para.length() - alcance, SAI_DA_MANGA / s)
		sh = ombro_sk + para.normalized() * sai
		para = punho - sh
		if para.length() > alcance:
			punho = sh + para.normalized() * alcance
			para = punho - sh
			o = punho - r_mao * (mao_rg.origin - _o_rep)
	var polo_sk := (inv.basis * polo).normalized()
	var cot := _cotovelo(sh, punho, polo_sk)
	var yb := (cot - sh).normalized()
	var ya := (punho - cot).normalized()
	var dobra := yb.cross(ya)
	if dobra.length() < 1e-3:
		dobra = yb.cross(-(polo_sk - yb * polo_sk.dot(yb)))
	dobra = dobra.normalized()
	var yb_rep := (_p("antebraco") - ombro_sk).normalized()
	var ya_rep := (_p("mao") - _p("antebraco")).normalized()
	var r_braco := _referencial(yb, dobra) * _referencial(yb_rep, _dobra_rep).inverse()
	var r_ante := _referencial(ya, dobra) * _referencial(ya_rep, _dobra_rep).inverse()
	# O giro do pulso: do dorso que o antebraco levaria ao dorso da mao.
	var dorso_ante := r_ante * _dorso_rep
	var a1 := dorso_ante - ya * dorso_ante.dot(ya)
	var a2 := dorso - ya * dorso.dot(ya)
	var giro := 0.0
	if a1.length() > 1e-4 and a2.length() > 1e-4:
		giro = clampf(a1.signed_angle_to(a2, ya), -deg_to_rad(GIRO_MAX), deg_to_rad(GIRO_MAX))
	var r_giro := Basis(ya, giro * GIRO_NO_ANTEBRACO) * r_ante
	var globais := {}
	globais[_o["braco"]] = Transform3D(r_braco * _rg[int(_o["braco"])].basis, sh)
	globais[_o["antebraco"]] = Transform3D(r_ante * _rg[int(_o["antebraco"])].basis, cot)
	globais[_o["antebraco_giro"]] = Transform3D(r_giro * _rg[int(_o["antebraco_giro"])].basis,
		cot + ya * _giro_no_antebraco)
	globais[_o["mao"]] = Transform3D(r_mao * mao_rg.basis, cot + ya * _l2)
	for nome: String in ["braco", "antebraco", "antebraco_giro", "mao"]:
		var i: int = _o[nome]
		var pai := _esq.get_bone_parent(i)
		var g: Transform3D = globais[i]
		var local := g if pai < 0 else (globais[pai] as Transform3D).affine_inverse() * g
		_esq.set_bone_pose_position(i, local.origin)
		_esq.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
	# A inercia: a mao que acelera contra o dorso deixa os dedos para tras.
	if dt > 0.0 and _punho_ant != Vector3.INF:
		var vel := (punho - _punho_ant) * s / dt
		var acel := (vel - _vel_ant) / dt
		_vel_ant = vel
		var empurra := clampf(acel.dot(dorso) * DEDOS_INERCIA, -DEDOS_INERCIA_MAX, DEDOS_INERCIA_MAX)
		_inercia_v += (-DEDOS_MOLA * _inercia - DEDOS_AMORTECE * _inercia_v + empurra * DEDOS_MOLA) * dt
		_inercia = clampf(_inercia + _inercia_v * dt, -DEDOS_INERCIA_MAX, DEDOS_INERCIA_MAX)
	_punho_ant = punho
	var p := MaoPosada.viva(pegada["pose"], _t,
		(DEDOS_VIVOS + DEDOS_COM_MEDO * clampf(tremor, 0.0, 1.5)) * dedos_vivos, _semente)
	_por_dedos(p)
	# O que a cena mede e a pele: devolve no espaco da cena.
	punho_montado = tx * punho
	cotovelo_montado = tx * cot
	_pele_mi.layers = layers
	for nome_p: StringName in [&"sangue", &"perto_da_lente"]:
		var v: Variant = get_instance_shader_parameter(nome_p)
		if v != null:
			_pele_mi.set_instance_shader_parameter(nome_p, v)
	_pele_mi.set_instance_shader_parameter(&"dorso_modelo", dorso)


## Os dedos na pose `p` (`MaoPosada`), descontado o repouso do modelo.
func _por_dedos(p: Dictionary) -> void:
	var rep: Array = _pose_repouso["dedos"]
	for k in DEDOS.size():
		var alvo: Array = p["dedos"][k]
		var r: Array = rep[k]
		for j in 3:
			var i: int = _o["%s_%d" % [DEDOS[k], j + 1]]
			var dobra := float(alvo[j]) - float(_dobra_de_repouso[i])
			if j == 0:
				dobra += _inercia
			var q := Quaternion(_eixo_dobra[i], -deg_to_rad(dobra))
			if j == 0:
				var abre := (float(alvo[3]) - float(r[3])) * _mao_lado()
				q = q * Quaternion(_eixo_abre[i], deg_to_rad(abre))
			_esq.set_bone_pose_rotation(i, _esq.get_bone_rest(i).basis.get_rotation_quaternion() * q)
	# O polegar: [radial, palmar, giro, mcp, ip], contra o repouso.
	var pa: Array = p["polegar"]
	var pr: Array = _pose_repouso["polegar"]
	var i1: int = _o["polegar_1"]
	var q1 := Quaternion(_eixo_abre[i1], deg_to_rad(float(pa[0]) - float(pr[0])) * _mao_lado()) \
		* Quaternion(_eixo_dobra[i1], -deg_to_rad(float(pa[1]) - float(pr[1])))
	var eixo_proprio := (_rg[i1].basis.inverse() * _dir_osso(i1)).normalized()
	q1 = q1 * Quaternion(eixo_proprio, deg_to_rad(float(pa[2]) - float(pr[2])))
	_esq.set_bone_pose_rotation(i1, _esq.get_bone_rest(i1).basis.get_rotation_quaternion() * q1)
	for j in [2, 3]:
		var i: int = _o["polegar_%d" % j]
		var dobra := float(pa[j + 1]) - float(pr[j + 1])
		_esq.set_bone_pose_rotation(i, _esq.get_bone_rest(i).basis.get_rotation_quaternion()
			* Quaternion(_eixo_dobra[i], -deg_to_rad(dobra)))


## +1 na mao direita, -1 na esquerda: abrir para o polegar e girar em volta do
## dorso trocam de sentido no espelho.
func _mao_lado() -> float:
	return 1.0 if direita else -1.0


## O cotovelo de dois ossos entre `a` (ombro) e `c` (punho), dobrando para `polo_`.
func _cotovelo(a: Vector3, c: Vector3, polo_: Vector3) -> Vector3:
	var v := c - a
	var dist := clampf(v.length(), 1e-4, _l1 + _l2 - 1e-4)
	var dir := v.normalized()
	var cos_a := clampf((_l1 * _l1 + dist * dist - _l2 * _l2) / (2.0 * _l1 * dist), -1.0, 1.0)
	var proj := _l1 * cos_a
	var h := sqrt(maxf(_l1 * _l1 - proj * proj, 0.0))
	var lado := polo_ - dir * polo_.dot(dir)
	if lado.length() < 1e-4:
		lado = dir.cross(Vector3.RIGHT)
	return a + dir * proj + lado.normalized() * h


## O referencial de (`a` ao longo, `b` de lado): colunas `a`, `b`, `a x b`.
static func _referencial(a: Vector3, b: Vector3) -> Basis:
	var x := a.normalized()
	var y := (b - x * b.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


## O corpo dos padres da estrada debaixo da batina AAA: o corpo do gerador
## (50 mil triangulos, texturas PBR de 4K), sem a cabeca, pesado nos ossos do
## `Corpo` — no lugar do corpo de caixa e dos `BracosPodres`.
##
## Por que existe
## --------------
## A batina AAA pendia de um corpo de caixa com bracos de manequim saindo por
## baixo da murca: de longe, um saco com uma cabeca em cima; de perto, a manga
## fina e preta do braco nao era a da batina. O usuario trouxe um corpo inteiro
## e pediu: cortar a cabeca, usar a que temos (`CabecaDoPadre`), e vestir a
## roupa nesse corpo.
##
## Como funciona
## -------------
## `tools/blender_corpo/k_corpo.py` prepara a malha fora do jogo: pesa a pele
## por calor num esqueleto com os ossos do `Corpo` postos nas juntas do corpo
## (em pose T), leva cada osso para a junta do `Corpo` de 1,72 m (o braco desce,
## estica ou encolhe; os giros por quaternio duplo e o ombro limpo por Corrective
## Smooth), afina o pescoco ate caber no da cabeca e corta dentro dela. Mede ali
## as capsulas do pano (tronco, bracos, maos, pernas).
##
## Aqui o corpo entra como uma malha de pele (`Skin`) no esqueleto do `Corpo`:
## quem ja escreve pose nos ossos — o andar, o tique, a janela, o cerco — leva o
## corpo junto. Uma ligacao por osso, na ordem (o indice em ARRAY_BONES e o do
## osso). Para outra altura, cada osso leva a malha do repouso de referencia
## para o seu, na escala da pessoa.
##
## O corpo de caixa some pela pele: a `Skin` dele e duplicada so neste corpo e
## esmaga cada vertice num ponto (ver [[sumir-parte-do-corpo-pela-pele]]). O
## osso da cabeca continua encolhido (`MonstroDaEstrada.no_da_cabeca`): a ligacao
## dele desfaz a escala, e o pescoco nao some junto. O braco que o padre
## principal troca na janela (escala quase zero no osso) some junto, como devia.
##
## Por baixo da batina ele veste uma tunica escura (tronco, pescoco, braco de
## cima, coxa; pintada pelo peso dos ossos): o que se ve pela gola, por baixo
## da murca e pela boca da manga le como pano. A pele fica no antebraco, na mao,
## na canela e no pe.
##
## `--corpo-velho` volta ao corpo de caixa com os `BracosPodres` (A/B).
class_name CorpoAAA
extends RefCounted

const PASTA := "res://assets/monstros/padre/corpo_aaa/"
const MALHA := PASTA + "corpo_aaa_malha.res"
const COR := PASTA + "corpo_aaa_cor.png"
const NORMAL := PASTA + "corpo_aaa_normal.png"
const MR := PASTA + "corpo_aaa_mr.png"
## A oclusao assada no repouso, com a batina e a cabeca em volta
## (`tools/blender_corpo/k_ao.py`).
const AO := PASTA + "corpo_aaa_ao.png"

const SHADER := """
shader_type spatial;

uniform sampler2D cor_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
// glTF: rugosidade no verde, metal no azul.
uniform sampler2D mr_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
// A pele da cabeca (`CabecaDoPadre`) e mais branca e mais fria que a do gerador.
uniform vec3 tom : source_color = vec3(0.80, 0.79, 0.78);
uniform vec3 cor_lama : source_color = vec3(0.14, 0.105, 0.075);
// A tunica escura por baixo da batina (la gasta, quase a cor do forro).
uniform vec3 cor_tunica : source_color = vec3(0.045, 0.038, 0.032);
// A oclusao com a roupa em volta: o pescoco dentro do capuz (na janela ele era
// um toco cinza aceso pelo farol entre o queixo e a murca), a axila, o braco
// dentro da manga.
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float ao_forca = 1.0;
uniform float ao_luz = 0.7;

void fragment() {
	// COLOR.r: o barro dos pes, assado pela altura no repouso; COLOR.g: a
	// tunica (tronco, pescoco, braco de cima, coxa).
	float lama = COLOR.r;
	float tunica = smoothstep(0.35, 0.75, COLOR.g);
	vec3 c = texture(cor_tex, UV).rgb * tom;
	c = mix(c, cor_lama, lama * 0.75);
	c = mix(c, cor_tunica, tunica);
	ALBEDO = c;
	ROUGHNESS = mix(mix(texture(mr_tex, UV).g, 0.92, lama), 0.95, tunica);
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = mix(1.0, 0.35, tunica);
	AO = mix(1.0, texture(ao_tex, UV).r, ao_forca);
	AO_LIGHT_AFFECT = ao_luz;
}
"""

## Os papeis dos colisores medidos no corpo, na ordem em que o gerador grava:
## por lado (e, d) braco, antebraco, mao, coxa, canela; depois peito, barriga e
## quadril.
const PAPEIS := [
	&"braco_e", &"antebraco_e", &"mao_e", &"coxa_e", &"canela_e",
	&"braco_d", &"antebraco_d", &"mao_d", &"coxa_d", &"canela_d",
	&"peito", &"barriga", &"quadril",
]

## Os dedos (formas do `k_dedos`, por lado): `abre` 0 a garra fechada, 1 a mao
## aberta, `REPOUSO` a mao solta (a relaxada, assada na malha). O contrato dos
## `BracosPodres`: meta `dedos`, `Callable(lado, abre)`, lado -1 o esquerdo.
const REPOUSO := 0.35
## O principal parado leva a mao meio em garra (como a manga comprida dele
## levava nos `BracosPodres`).
const ABRE_PRINCIPAL := 0.14
## Os de fundo tem o antebraco e a mao maiores (em volta do cotovelo): a
## silhueta de bracos compridos e maos grandes que os `BracosPodres` davam.
const MAO_FUNDO := 1.25
## Quem sobe no carro (meta `cerco`) volta a mao ao tamanho de gente, que a
## escalada espera (`EscaladorDoCarro`), neste tempo (s).
const CURTO_TEMPO := 0.6

static var _malha: Mesh
static var _material: ShaderMaterial
static var _tentou := false


## Se o corpo AAA vale para quem vai vestir agora (carrega na primeira vez).
static func usar() -> bool:
	if OS.get_cmdline_user_args().has("--corpo-velho"):
		return false
	return _carregar()


static func _carregar() -> bool:
	if _malha != null:
		return true
	if _tentou:
		return false
	_tentou = true
	if not ResourceLoader.exists(MALHA):
		push_warning("CorpoAAA: sem %s" % MALHA)
		return false
	_malha = load(MALHA) as Mesh
	if _malha == null:
		return false
	var sh := Shader.new()
	sh.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = sh
	_material.set_shader_parameter(&"cor_tex", load(COR))
	_material.set_shader_parameter(&"normal_tex", load(NORMAL))
	_material.set_shader_parameter(&"mr_tex", load(MR))
	if ResourceLoader.exists(AO) and not OS.get_cmdline_user_args().has("--corpo-sem-ao"):
		_material.set_shader_parameter(&"ao_tex", load(AO))
	else:
		_material.set_shader_parameter(&"ao_forca", 0.0)
	return true


## Veste o corpo em `c` (ja montado; a cabeca, se houver, ja encolhida). Some
## com o corpo de caixa e deixa o meta `corpo_aaa` (a malha). Devolve a malha.
static func vestir(c: Corpo) -> MeshInstance3D:
	if not usar():
		return null
	var esq := c.esqueleto()
	if esq == null:
		return null
	var ja := c.get_meta(&"corpo_aaa") as MeshInstance3D if c.has_meta(&"corpo_aaa") else null
	if ja != null and is_instance_valid(ja) and ja.get_parent() == esq:
		return ja
	var k := c.altura() / float(_malha.get_meta(&"altura_ref", Corpo.ALTURA_REF))
	var rep: PackedVector3Array = _malha.get_meta(&"repouso", PackedVector3Array())
	var fundo := bool(c.get_meta(&"bracos_de_fora", false))
	var skin := Skin.new()
	for o in esq.get_bone_count():
		var r := esq.get_bone_global_rest(o)
		var ref := rep[o] if o < rep.size() else r.origin / k
		# M(v) = origem do osso + k (v - origem de referencia): a malha do
		# repouso de referencia no repouso desta pessoa.
		var m := Transform3D(Basis.from_scale(Vector3.ONE * k), r.origin - ref * k)
		var bind := r.affine_inverse() * m
		var sc := esq.get_bone_pose_scale(o)
		if o == Corpo.Osso.CABECA and sc.x > 0.0 and absf(sc.x - 1.0) > 1e-6:
			# O osso da cabeca esta encolhido (a caixa sumiu por ele): a
			# ligacao desfaz a escala, e o pescoco fica do tamanho certo.
			bind = Transform3D(Basis.from_scale(Vector3.ONE / sc), Vector3.ZERO) * bind
		skin.add_bind(o, bind)
	var pele := esq.get_node_or_null("Pele") as MeshInstance3D
	_esconder_caixa(esq)
	var mi := MeshInstance3D.new()
	mi.name = "CorpoAAA"
	mi.mesh = _malha
	mi.skin = skin
	mi.material_override = _material
	if pele != null:
		mi.layers = pele.layers
	esq.add_child(mi)
	mi.skeleton = NodePath("..")
	c.set_meta(&"corpo_aaa", mi)
	# Os dedos: a chamada que o andar (`AndarMacabro`, o evento dos dedos) e a
	# bancada fazem.
	var ref: WeakRef = weakref(mi)
	var dedos := func(lado: float, abre: float) -> void:
		CorpoAAA._por_dedos(ref.get_ref() as MeshInstance3D, lado, abre)
	c.set_meta(&"dedos", dedos)
	for lado: float in [-1.0, 1.0]:
		_por_dedos(mi, lado, REPOUSO if fundo else ABRE_PRINCIPAL)
	# Quem troca a mao pelo `BracoVivo` (o cerco, a janela do carona) apaga o
	# braco pelo nome do no (`BracoPodreE`/`BracoPodreD`, o contrato dos
	# `BracosPodres`): os dois nos ficam aqui, vazios, e apagar um some com o
	# braco do corpo daquele lado (a manga vai junto, `BatinaAAA`).
	var binds: Array[Transform3D] = []
	for i in skin.get_bind_count():
		binds.append(skin.get_bind_pose(i))
	if fundo:
		# A mao grande dos de fundo; o cerco a devolve ao tamanho de gente.
		_por_mao(skin, binds, esq, MAO_FUNDO)
		var conferir := func() -> void:
			CorpoAAA._conferir_cerco(c, skin, binds, esq)
		c.tree_entered.connect(func() -> void: conferir.call_deferred())
	for lado: String in ["E", "D"]:
		var proc := Node3D.new()
		proc.name = "BracoPodre" + lado
		esq.add_child(proc)
		proc.visibility_changed.connect(_braco_visivel.bind(skin, binds, lado, proc))
	return mi


## Os pesos das formas de `lado` para `abre` (0 garra, `REPOUSO` solta, 1
## aberta).
static func _por_dedos(mi: MeshInstance3D, lado: float, abre: float) -> void:
	if mi == null or not is_instance_valid(mi):
		return
	var s := "_e" if lado < 0.0 else "_d"
	var g := mi.find_blend_shape_by_name(StringName("garra" + s))
	var ab := mi.find_blend_shape_by_name(StringName("aberta" + s))
	if g < 0 or ab < 0:
		return
	var a := clampf(abre, 0.0, 1.0)
	mi.set_blend_shape_value(g, (REPOUSO - a) / REPOUSO if a < REPOUSO else 0.0)
	mi.set_blend_shape_value(ab, (a - REPOUSO) / (1.0 - REPOUSO) if a > REPOUSO else 0.0)


## O antebraco e a mao dos dois lados na escala `f`, em volta do cotovelo (a
## origem do osso: no espaco dele, a escala e na frente da ligacao), por cima
## das ligacoes `binds` do vestir. O lado apagado (no procurador) fica.
static func _por_mao(skin: Skin, binds: Array[Transform3D], esq: Skeleton3D, f: float) -> void:
	skin.set_meta(&"mao", f)
	for o: int in [Corpo.Osso.ANTEBRACO_E, Corpo.Osso.ANTEBRACO_D]:
		var proc := esq.get_node_or_null(
			"BracoPodreE" if o == Corpo.Osso.ANTEBRACO_E else "BracoPodreD") as Node3D
		if o >= binds.size() or (proc != null and not proc.visible):
			continue
		skin.set_bind_pose(o, Transform3D(Basis.from_scale(Vector3.ONE * f), Vector3.ZERO) * binds[o])


## Quem entrou no cerco (meta `cerco`) volta a mao ao tamanho de gente.
static func _conferir_cerco(c: Object, skin: Skin, binds: Array[Transform3D], esq: Skeleton3D) -> void:
	# `Object`, e nao `Corpo`: a chamada e adiada, e o corpo pode ter sido liberado.
	if not is_instance_valid(c) or not c.has_meta(&"cerco") or not is_instance_valid(esq) 			or c.has_meta(&"mao_curta"):
		return
	c.set_meta(&"mao_curta", true)
	(c as Node).create_tween().tween_method(func(f: float) -> void:
		if is_instance_valid(esq):
			CorpoAAA._por_mao(skin, binds, esq, f), MAO_FUNDO, 1.0, CURTO_TEMPO) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## O braco do corpo do lado `lado` some (ligacoes esmagadas) ou volta, pelo no
## procurador `proc`.
static func _braco_visivel(skin: Skin, binds: Array[Transform3D], lado: String, proc: Node3D) -> void:
	if not is_instance_valid(proc):
		return
	var ossos := [Corpo.Osso.BRACO_E, Corpo.Osso.ANTEBRACO_E] if lado == "E" 		else [Corpo.Osso.BRACO_D, Corpo.Osso.ANTEBRACO_D]
	var mao := float(skin.get_meta(&"mao", 1.0))
	for o: int in ossos:
		var volta := binds[o]
		if o == Corpo.Osso.ANTEBRACO_E or o == Corpo.Osso.ANTEBRACO_D:
			volta = Transform3D(Basis.from_scale(Vector3.ONE * mao), Vector3.ZERO) * binds[o]
		skin.set_bind_pose(o, volta if proc.visible
			else Transform3D(Basis.from_scale(Vector3.ONE * 1e-4), Vector3.ZERO))


## Tem o corpo AAA vestido (e nao o de caixa com os `BracosPodres`).
static func vestido(c: Node) -> bool:
	if not c.has_meta(&"corpo_aaa"):
		return false
	var mi := c.get_meta(&"corpo_aaa") as MeshInstance3D
	return mi != null and is_instance_valid(mi) and mi.is_inside_tree()


## Poe em `pano` as capsulas medidas no corpo, na escala da pessoa, e devolve
## {papel: indice do colisor} (ver `PAPEIS`).
static func colisores(pano: PanoGPU, c: Corpo) -> Dictionary:
	var out := {}
	if not _carregar():
		return out
	var esq := c.esqueleto()
	var k := c.altura() / float(_malha.get_meta(&"altura_ref", Corpo.ALTURA_REF))
	var rep: PackedVector3Array = _malha.get_meta(&"repouso", PackedVector3Array())
	var cols: Array = _malha.get_meta(&"colisores", [])
	for i in cols.size():
		var col: Array = cols[i]
		var o := int(col[0])
		var r := esq.get_bone_global_rest(o)
		var inv := Transform3D(r.basis.orthonormalized(), r.origin).affine_inverse()
		var a: Vector3 = r.origin + ((col[1] as Vector3) - rep[o]) * k
		var b: Vector3 = r.origin + ((col[2] as Vector3) - rep[o]) * k
		var idx := pano.colisor(o, inv * a, inv * b, float(col[3]) * k)
		if i < PAPEIS.size() and idx >= 0:
			out[PAPEIS[i]] = idx
	return out


## A pele de caixa (e a barba e a palpebra dela) deste corpo esmaga cada
## vertice num ponto: a `Skin` e da variante e dividida, a copia vai so aqui, e
## o proximo `montar` poe a da variante de volta.
static func _esconder_caixa(esq: Skeleton3D) -> void:
	var some: Skin = null
	for f: Node in esq.get_children():
		var mi := f as MeshInstance3D
		if mi == null or mi.skin == null or not (String(mi.name) in ["Pele", "Recorte", "Palpebra"]):
			continue
		if some == null:
			some = mi.skin.duplicate() as Skin
			for i in some.get_bind_count():
				some.set_bind_pose(i, Transform3D(Basis.from_scale(Vector3.ONE * 1e-4), Vector3.ZERO))
		mi.skin = some

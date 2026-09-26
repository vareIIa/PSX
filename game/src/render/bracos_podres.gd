## Os bracos dos encapuzados da estrada: antebraco fino e podre saindo de uma
## manga larga, e a mao comprida e grande — no lugar do tubo de caixa e da luva
## do `Corpo`.
##
## Por que existe
## --------------
## O padre principal ganhou bracos de verdade na janela (`BracoVivo` com
## `MaosPodres`), mas so ele e so ali. Os outros continuavam com o braco do
## `Corpo`: um tubo preto de caixa e uma mao em cone cor de cera. A primeira
## troca (manga comprida ate o punho e a mao do tamanho da de gente) ficava
## dentro do pano: a murca cobria o braco e a batina larga engolia a mao. De 5
## a 15 m, no farol e no fogo, o romeiro era uma coluna de batina. O pedido e
## "os bracos reais com as grandes maos": a silhueta tem de ler bracos
## compridos e maos enormes.
##
## Como funciona
## -------------
## A malha e montada UMA vez por altura de corpo, no repouso do esqueleto, com
## as mesmas pecas da mao de primeira pessoa (`MaoPosada` e `MaoModelada` na
## `MaosPodres.FORMA`), e cada vertice ganha peso nos ossos do braco e do
## antebraco. Dai em diante quem move e o esqueleto: o andar, o tique, a
## escalada, o agarrar — tudo o que ja escreve pose nos ossos do `Corpo` leva o
## braco junto, sem refazer malha por quadro.
##
## Nos de fundo (meta `bracos_de_fora` no `Corpo`, que a `MonstroDaEstrada` poe
## em todos menos no principal):
## - o antebraco sai do corpo (`ABRE`) e passa do punho do `Corpo` (`ESTICA`),
##   de pele, fino;
## - a mao e 1,3 vezes a do principal (`MAO`), pendurada de costas para a frente
##   (`PRONA`): quem olha ve a largura dela e os dedos compridos ate perto do
##   joelho, e nao o fio da mao de lado;
## - a manga larga cobre o braco de cima e abre em sino logo abaixo do cotovelo,
##   com o forro escuro por dentro.
## O principal fica com a manga comprida e a mao de antes (ele troca de braco
## na janela, e o `BracoVivo` foi afinado para ela).
##
## Os dedos vivos
## --------------
## A malha leva tres formas (blend shapes) assadas das poses da `MaoPosada`:
## `garra` (os dedos fechados em garra), `aberta` (esticados e espalhados) e
## `curto` (o braco e a mao do tamanho de gente, ver abaixo). O `vestir` deixa
## no `Corpo` o meta `dedos`, uma `Callable(lado: float, abre: float)`:
## `lado` -1 o esquerdo e +1 o direito, `abre` 0 a garra fechada, 1 a mao
## aberta, `REPOUSO` (0,35) a mao solta, ja posta no vestir. A chamada so escreve
## dois pesos de forma, e pode ser feita todo quadro:
##
##     var dedos := c.get_meta(&"dedos", Callable()) as Callable
##     if dedos.is_valid():
##         dedos.call(-1.0, 0.1)   # a esquerda fecha em garra
##
## Se o braco sumiu (o `BracoVivo` do cerco o esconde pelo nome, ou ele foi
## liberado), a chamada nao faz nada.
##
## O cerco
## -------
## Quem sobe no carro (meta `cerco`) apoia pela ponta dos dedos, na conta do
## `EscaladorDoCarro` (`MAO_ATE_A_PONTA`, a mao de gente). Quando o corpo entra
## no carro, a forma `curto` sobe em `CURTO_TEMPO`: o antebraco volta ao osso e
## a mao ao tamanho que a escalada espera.
##
## As caixas somem sem mexer na escala dos ossos (o padre na janela ja usa a
## escala para sumir com o braco inteiro, e a malha nova sumiria junto): a pele
## de ossos DESTE corpo e duplicada, e as ligacoes do braco e do antebraco
## passam a esmagar os seus vertices num ponto dentro da junta.
class_name BracosPodres
extends RefCounted

## A garra da mao do principal (a manga comprida): o quanto da pose relaxada
## vai para a garra.
const GARRA := 0.6
## A mao de fundo: quanto maior que a do principal na janela.
const MAO := 1.3
## Quanto o antebraco de fundo passa do punho do `Corpo` (m, pessoa de 1,72).
const ESTICA := 0.07
## O antebraco de fundo sai do corpo (rad): a mao pendurada fica do lado de
## fora da batina.
const ABRE := 0.14
## O dorso da mao de fundo, de "para fora" (0) a "para a frente" (PI/2).
const PRONA := 0.85
## A mao de fundo dobra um fio no pulso, para dentro (rad): peso morto.
const PULSO := 0.10
## Os dedos no repouso: 0 garra fechada, 1 mao aberta.
const REPOUSO := 0.35
## A menor dobra de um no nas poses assadas (graus): ver `_pose_dos_dedos`.
const DOBRA_MINIMA := 6.0
## Onde a mao passa do tamanho do antebraco para o dela, ao longo da mao, em
## volta do punho (m): de antes do pulso ate o calcanhar da mao.
const PULSO_CRESCE := Vector2(-0.10, 0.05)
## O trecho do antebraco (m do punho para o cotovelo) que vira osso e tendao.
const ANTEBRACO_OSSO := Vector2(0.015, 0.34)
## A manga larga: meios eixos (largura, fundo) no ombro, no cotovelo e na boca
## do sino, e quanto a boca fica abaixo do cotovelo, ao longo do antebraco.
const MANGA_OMBRO := Vector2(0.060, 0.055)
const MANGA_COTOVELO := Vector2(0.070, 0.064)
const MANGA_BOCA := Vector2(0.104, 0.094)
const MANGA_ABAIXO := 0.11
const MANGA_LADOS := 16
## Meia faixa (m) em volta do cotovelo em que o peso passa do braco para o
## antebraco, e a faixa do alto do ombro que vai um pouco com o tronco.
const DOBRA := 0.045
const OMBRO_NO_TRONCO := 0.05
const TRONCO_NO_ALTO := 0.35
## As cores de vertice (a pele e a manga): as mesmas das maos do padre.
const PELE := Color("6c6f68")
const MANGA := Color("1c1a18")
## A escala que esmaga as caixas do braco dentro da junta.
const SUMIDO := 1e-4
## As formas da malha de fundo, na ordem.
const FORMAS := [&"garra", &"aberta", &"curto"]
## Quanto a forma `curto` leva para subir quando o corpo entra no cerco (s).
const CURTO_TEMPO := 0.6

## Quanto a pele do braco de fundo escurece sobre a da cabeca.
const PELE_ESCURECE := 0.18

## As malhas ja montadas, por altura (cm), ombro e lado.
static var _malhas: Dictionary = {}
## Os materiais de fundo, por tom de pele.
static var _materiais: Dictionary = {}


## Troca os bracos de caixa de `c` (ja montado) pelos podres. `--bracos-de-caixa`
## desliga (A/B).
static func vestir(c: Corpo) -> void:
	if c == null or OS.get_cmdline_user_args().has("--bracos-de-caixa"):
		return
	# Com o corpo AAA (`CorpoAAA`) os bracos sao os dele, dentro das mangas da
	# batina AAA.
	if CorpoAAA.vestido(c):
		return
	var esq := c.esqueleto()
	if esq == null or esq.get_node_or_null("BracoPodreE") != null:
		return
	var pele := esq.get_node_or_null("Pele") as MeshInstance3D
	if pele == null or pele.skin == null:
		return
	var fora := bool(c.get_meta(&"bracos_de_fora", false))
	_sumir_com_as_caixas(pele)
	var skin := _pele_do_braco(esq)
	var nos: Array[MeshInstance3D] = []
	for lado: float in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.name = "BracoPodre" + ("E" if lado < 0.0 else "D")
		mi.mesh = _malha_de_fora(esq, lado) if fora else _malha(esq, lado)
		mi.skin = skin
		mi.material_override = _material_de_fora(c) if fora else MaosPodres.material()
		mi.layers = pele.layers
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		esq.add_child(mi)
		mi.skeleton = NodePath("..")
		nos.append(mi)
	if not fora:
		return
	var e: WeakRef = weakref(nos[0])
	var d: WeakRef = weakref(nos[1])
	var dedos := func(lado: float, abre: float) -> void:
		var mi := (e if lado < 0.0 else d).get_ref() as MeshInstance3D
		if mi != null:
			BracosPodres._por_dedos(mi, abre)
	c.set_meta(&"dedos", dedos)
	for mi in nos:
		_por_dedos(mi, REPOUSO)
	# O cerco poe o meta depois de levar o corpo para dentro do carro: confere
	# no fim do quadro em que ele entra de novo na arvore.
	var conferir := func() -> void:
		BracosPodres._conferir_cerco(c, e, d)
	c.tree_entered.connect(func() -> void: conferir.call_deferred())


## A pele dos bracos de fundo: o material das maos do padre (`MaosPodres`) no
## tom da cabeca de cada um (`CabecaDeFundo.TONS`), um fio mais escuro e mais
## sujo (o braco pegou barro e chuva). Um material por tom, dividido por todos.
static func _material_de_fora(c: Corpo) -> ShaderMaterial:
	var cab := c.get_meta(&"rosto", null) as CabecaDeFundo
	var tom := cab.tom() if cab != null else 0
	if _materiais.has(tom):
		return _materiais[tom]
	var m := MaosPodres.material().duplicate() as ShaderMaterial
	var t: Array = CabecaDeFundo.TONS[tom]
	m.set_shader_parameter(&"pele", (t[0] as Color).darkened(PELE_ESCURECE))
	m.set_shader_parameter(&"mancha_quente", (t[1] as Color).darkened(PELE_ESCURECE))
	m.set_shader_parameter(&"mancha_fria", (t[2] as Color).darkened(PELE_ESCURECE))
	m.set_shader_parameter(&"veia", t[3])
	m.set_shader_parameter(&"racha", (t[4] as Color).darkened(0.2))
	m.set_shader_parameter(&"relevo", float(t[9]) * 1.1)
	m.set_shader_parameter(&"tile_pele", float(t[8]))
	_materiais[tom] = m
	return m


## O antebraco de fundo no repouso, do cotovelo ao punho, no espaco do osso do
## antebraco de um corpo de escala `s` (altura / 1,72): para quem poe colisor
## nele (o pano da batina).
static func antebraco_de_fora(lado: float, s: float) -> Vector3:
	return Vector3(lado * sin(ABRE), -cos(ABRE), 0.0) \
		* ((Corpo.Y_COTOVELO - Corpo.Y_PUNHO + ESTICA) * s)


## A direcao da mao de fundo pendurada (do punho aos dedos), no mesmo espaco.
static func mao_de_fora(lado: float) -> Vector3:
	return Vector3(lado * sin(ABRE), -cos(ABRE), 0.0).rotated(Vector3.BACK, -lado * PULSO)


## Os pesos das formas `garra` e `aberta` para `abre` (0 garra, 1 aberta).
static func _por_dedos(mi: MeshInstance3D, abre: float) -> void:
	if mi.get_blend_shape_count() < 2:
		return
	var a := clampf(abre, 0.0, 1.0)
	mi.set_blend_shape_value(0, (REPOUSO - a) / REPOUSO if a < REPOUSO else 0.0)
	mi.set_blend_shape_value(1, (a - REPOUSO) / (1.0 - REPOUSO) if a > REPOUSO else 0.0)


## Se `c` entrou no cerco, os bracos voltam ao tamanho que a escalada espera.
static func _conferir_cerco(c: Object, e: WeakRef, d: WeakRef) -> void:
	# `Object`, e nao `Corpo`: a chamada e adiada, e o corpo pode ter sido liberado.
	if not is_instance_valid(c) or not c.has_meta(&"cerco"):
		return
	for w: WeakRef in [e, d]:
		var mi := w.get_ref() as MeshInstance3D
		if mi == null or not mi.is_inside_tree() or mi.get_blend_shape_count() < 3 \
				or mi.has_meta(&"curto"):
			continue
		mi.set_meta(&"curto", true)
		print("[bracos_podres] %s no cerco: %s volta ao tamanho da escalada" % [
			(c as Node).name, mi.name])
		mi.create_tween().tween_property(mi, "blend_shapes/curto", 1.0, CURTO_TEMPO) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## As caixas do braco e do antebraco (e a mao, que e do antebraco) esmagadas
## num ponto dentro da junta: a pele de ossos da variante e de todos que a
## usam, entao este corpo leva a sua copia.
static func _sumir_com_as_caixas(pele: MeshInstance3D) -> void:
	var s := pele.skin.duplicate() as Skin
	var sumir := [Corpo.Osso.BRACO_E, Corpo.Osso.ANTEBRACO_E, Corpo.Osso.BRACO_D,
		Corpo.Osso.ANTEBRACO_D]
	for i in s.get_bind_count():
		if s.get_bind_bone(i) in sumir:
			s.set_bind_pose(i, Transform3D(Basis.from_scale(Vector3.ONE * SUMIDO), Vector3.ZERO))
	pele.skin = s


## A pele de ossos da malha nova, com o repouso que o esqueleto tem. Uma
## ligacao por osso e na ordem deles: o indice de osso gravado no vertice e o
## da ligacao, e assim ele e tambem o do osso (`Corpo.Osso`).
static func _pele_do_braco(esq: Skeleton3D) -> Skin:
	var s := Skin.new()
	for o in esq.get_bone_count():
		s.add_bind(o, esq.get_bone_global_rest(o).affine_inverse())
	return s


# --- o principal: manga comprida, mao de gente ------------------------------

static func _malha(esq: Skeleton3D, lado: float) -> ArrayMesh:
	var braco := Corpo.Osso.BRACO_E if lado < 0.0 else Corpo.Osso.BRACO_D
	var ante := Corpo.Osso.ANTEBRACO_E if lado < 0.0 else Corpo.Osso.ANTEBRACO_D
	var ombro := esq.get_bone_global_rest(braco).origin
	var cotovelo := esq.get_bone_global_rest(ante).origin
	var chave := "%d_%d_%d" % [roundi(ombro.y * 100.0), roundi(absf(ombro.x) * 100.0),
		int(lado)]
	if _malhas.has(chave):
		return _malhas[chave]
	# O punho do `Corpo` (`Corpo.Y_PUNHO`, na mesma escala do ombro).
	var escala := ombro.y / Corpo.Y_OMBRO
	var punho := Vector3(ombro.x, Corpo.Y_PUNHO * escala, 0.0)
	# Pendurado: os dedos para baixo, a palma para dentro (o polegar para a
	# frente, -Z), as costas da mao para fora.
	var d := Vector3.DOWN
	var dorso := Vector3(lado, 0.0, 0.0)
	var o := punho - MaoPosada.punho_de(Vector3.ZERO, d, dorso)
	var pose := MaoPosada.misturar(MaoPosada.pose(&"relaxada"), MaoPosada.pose(&"garra"),
		GARRA)
	var dados := PSXMesh.dados_vazios()
	MaoModelada.forma = MaosPodres.FORMA
	var b := MaoPosada.montar(dados, o, d, dorso, pose, lado > 0.0, cotovelo, PELE, MANGA,
		true)
	var pu: Vector3 = b["punho"]
	var fim := pu + (b["eixo"] as Vector3) * clampf(cotovelo.distance_to(pu), 0.10,
		MaoModelada.ANTEBRACO)
	MaoModelada.braco_de_cima(dados, fim, ombro, PELE, MANGA, true)
	MaoModelada.forma = {}
	_pesar(dados, braco, ante, ombro, cotovelo)
	var m := PSXMesh.dados_para_mesh(dados)
	_malhas[chave] = m
	return m


# --- os de fundo: manga larga, antebraco de fora, mao grande ----------------

static func _malha_de_fora(esq: Skeleton3D, lado: float) -> ArrayMesh:
	var braco := Corpo.Osso.BRACO_E if lado < 0.0 else Corpo.Osso.BRACO_D
	var ante := Corpo.Osso.ANTEBRACO_E if lado < 0.0 else Corpo.Osso.ANTEBRACO_D
	var ombro := esq.get_bone_global_rest(braco).origin
	var cotovelo := esq.get_bone_global_rest(ante).origin
	var chave := "fora_%d_%d_%d" % [roundi(ombro.y * 100.0), roundi(absf(ombro.x) * 100.0),
		int(lado)]
	if _malhas.has(chave):
		return _malhas[chave]
	var base := _dados_de_fora(ombro, cotovelo, lado, REPOUSO, false)
	var formas := [_dados_de_fora(ombro, cotovelo, lado, 0.0, false),
		_dados_de_fora(ombro, cotovelo, lado, 1.0, false),
		_dados_de_fora(ombro, cotovelo, lado, REPOUSO, true)]
	var n := (base["v"] as PackedVector3Array).size()
	for f: Dictionary in formas:
		if (f["v"] as PackedVector3Array).size() != n:
			push_warning("BracosPodres: forma com %d vertices, a base tem %d; sem formas"
				% [(f["v"] as PackedVector3Array).size(), n])
			formas = []
			break
	_pesar(base, braco, ante, ombro, cotovelo)
	var m := _com_formas(base, formas)
	_malhas[chave] = m
	return m


## A malha do braco de fundo com os dedos em `abre` (0 garra, 1 aberta), ou,
## `curto`, com o antebraco no osso e a mao do tamanho da do principal.
static func _dados_de_fora(ombro: Vector3, cotovelo: Vector3, lado: float, abre: float,
		curto: bool) -> Dictionary:
	var escala := ombro.y / Corpo.Y_OMBRO
	var punho_corpo := Vector3(ombro.x, Corpo.Y_PUNHO * escala, 0.0)
	var angulo := 0.0 if curto else ABRE
	var eixo := Vector3(lado * sin(angulo), -cos(angulo), 0.0)
	var punho := cotovelo + eixo * (cotovelo.distance_to(punho_corpo)
		+ (0.0 if curto else ESTICA * escala))
	# A mao: segue o antebraco com o pulso dobrado para dentro, e o dorso gira
	# de "para fora" para "para a frente" (-Z): a palma olha para tras.
	var d := eixo.rotated(Vector3.BACK, -lado * PULSO)
	var fora_d := Vector3(-d.y, d.x, 0.0) * lado
	var dorso := (fora_d * cos(PRONA) + Vector3.FORWARD * sin(PRONA)).normalized()
	var o := punho - MaoPosada.punho_de(Vector3.ZERO, d, dorso)
	var mao := PSXMesh.dados_vazios()
	MaoModelada.forma = MaosPodres.FORMA
	var b := MaoPosada.montar(mao, o, d, dorso, _pose_dos_dedos(abre), lado > 0.0, cotovelo,
		PELE, MANGA, false)
	MaoModelada.forma = {}
	var pu: Vector3 = b["punho"]
	var mexidos := PackedByteArray()
	mexidos.resize((mao["v"] as PackedVector3Array).size())
	_crescer_mao(mao, pu, d, 1.0 if curto else MAO, mexidos)
	_antebraco_ossudo(mao, pu, eixo, fora_d, lado, mexidos)
	_refazer_normais(mao, mexidos)
	var dados := PSXMesh.dados_vazios()
	PSXMesh.acumular(dados, mao, Transform3D.IDENTITY)
	_manga_larga(dados, ombro, cotovelo, eixo, lado)
	return dados


## A pose dos dedos: da garra (0) a mao solta (`REPOUSO`) e dai a aberta (1).
static func _pose_dos_dedos(abre: float) -> Dictionary:
	var garra := MaoPosada.pose(&"garra")
	var solta := MaoPosada.misturar(MaoPosada.pose(&"relaxada"), garra, 0.45)
	var aberta := MaoPosada.misturar(MaoPosada.pose(&"aberta"), MaoPosada.pose(&"estica"), 0.5)
	var p := MaoPosada.misturar(garra, solta, abre / REPOUSO) if abre <= REPOUSO \
		else MaoPosada.misturar(solta, aberta, (abre - REPOUSO) / (1.0 - REPOUSO))
	# Todo no com pelo menos `DOBRA_MINIMA`: abaixo de 4 graus a `MaoModelada`
	# troca o arco do no (tres aneis) por um anel so, e a malha de uma pose deixa
	# de ter os vertices da outra (as formas precisam da mesma contagem).
	var dedos := []
	for dd: Array in p["dedos"]:
		dedos.append([_longe_do_zero(float(dd[0])), _longe_do_zero(float(dd[1])),
			_longe_do_zero(float(dd[2])), float(dd[3])])
	var pol: Array = (p["polegar"] as Array).duplicate()
	pol[3] = _longe_do_zero(float(pol[3]))
	pol[4] = _longe_do_zero(float(pol[4]))
	return {"dedos": dedos, "polegar": pol}


static func _longe_do_zero(graus: float) -> float:
	if absf(graus) >= DOBRA_MINIMA:
		return graus
	return DOBRA_MINIMA if graus >= 0.0 else -DOBRA_MINIMA


## A mao cresce `s` vezes em volta do punho `pu`; o antebraco nao. A passagem e
## lisa no pulso. A pele presa na malha (metros ao longo em UV2.y, raio no alfa
## da cor) cresce junto: a racha fica do mesmo tamanho na mao grande.
static func _crescer_mao(dados: Dictionary, pu: Vector3, d: Vector3, s: float,
		mexidos: PackedByteArray) -> void:
	if is_equal_approx(s, 1.0):
		return
	var vs: PackedVector3Array = dados["v"]
	var uv2: PackedVector2Array = dados["uv2"]
	var cor: PackedColorArray = dados["c"]
	for i in vs.size():
		var k := smoothstep(PULSO_CRESCE.x, PULSO_CRESCE.y, (vs[i] - pu).dot(d))
		var f := lerpf(1.0, s, k)
		if k > 0.0 and k < 1.0:
			mexidos[i] = 1
		vs[i] = pu + (vs[i] - pu) * f
		if i < uv2.size():
			uv2[i].y *= f
		if i < cor.size():
			cor[i].a = minf(cor[i].a * f, 1.0)
	dados["v"] = vs
	dados["uv2"] = uv2
	dados["c"] = cor


## O antebraco de pele era um cano liso: afina no pulso, com o calombo da ulna
## do lado de fora, os tendoes em sulco no terco de baixo e a carne seca e
## desigual pelo resto. `pu` e o punho, `eixo` do cotovelo para o punho, `fora`
## o lado de fora (a volta comeca nele).
static func _antebraco_ossudo(dados: Dictionary, pu: Vector3, eixo: Vector3, fora: Vector3,
		lado: float, mexidos: PackedByteArray) -> void:
	var vs: PackedVector3Array = dados["v"]
	var e1 := (fora - eixo * fora.dot(eixo)).normalized()
	var e2 := eixo.cross(e1)
	for i in vs.size():
		var s := (vs[i] - pu).dot(-eixo)
		if s < ANTEBRACO_OSSO.x or s > ANTEBRACO_OSSO.y:
			continue
		var c := pu - eixo * s
		var r := vs[i] - c
		if r.length() > 0.07:
			continue
		var phi := atan2(r.dot(e2) * lado, r.dot(e1))
		var entra := smoothstep(ANTEBRACO_OSSO.x, ANTEBRACO_OSSO.x + 0.035, s)
		var k := lerpf(0.92, 1.07, smoothstep(0.03, 0.24, s))
		k += 0.07 * sin(4.0 * phi + 0.9) * smoothstep(0.03, 0.08, s) \
			* (1.0 - smoothstep(0.17, 0.25, s))
		k += 0.05 * sin(2.0 * phi + s * 21.0 + lado) * smoothstep(0.03, 0.10, s)
		k += 0.24 * exp(-pow((s - 0.05) / 0.018, 2.0)) * pow(maxf(cos(phi - 0.6), 0.0), 3.0)
		vs[i] = c + r * lerpf(1.0, k, entra)
		mexidos[i] = 1
	dados["v"] = vs


## A normal dos vertices `mexidos`, refeita das faces vizinhas (a regra do
## projeto: a face aparece do lado oposto ao produto vetorial, ver
## `MaoModelada._tubo`). A costura do tubo (o mesmo ponto duas vezes) soma as
## duas metades, como o `_tubo` faz.
static func _refazer_normais(dados: Dictionary, mexidos: PackedByteArray) -> void:
	var vs: PackedVector3Array = dados["v"]
	var ns: PackedVector3Array = dados["n"]
	var idx: PackedInt32Array = dados["i"]
	var soma := PackedVector3Array()
	soma.resize(vs.size())
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		var i1 := idx[t + 1]
		var i2 := idx[t + 2]
		if mexidos[i0] == 0 and mexidos[i1] == 0 and mexidos[i2] == 0:
			continue
		var fn := (vs[i1] - vs[i0]).cross(vs[i2] - vs[i0])
		soma[i0] -= fn
		soma[i1] -= fn
		soma[i2] -= fn
	var costura := {}
	for i in vs.size():
		if mexidos[i] == 0:
			continue
		var chave := Vector3i((vs[i] * 1e5).round())
		if costura.has(chave):
			var j: int = costura[chave]
			var tot := soma[i] + soma[j]
			soma[i] = tot
			soma[j] = tot
		else:
			costura[chave] = i
	for i in vs.size():
		if mexidos[i] != 0 and soma[i].length_squared() > 1e-20:
			ns[i] = soma[i].normalized()
	dados["n"] = ns


## A manga larga: do ombro ao cotovelo pelo braco de cima, e dai em sino ao
## longo do antebraco ate `MANGA_ABAIXO`; a bainha enrola e o forro volta por
## dentro (o tubo segue, e a volta vira a face para dentro).
static func _manga_larga(dados: Dictionary, ombro: Vector3, cotovelo: Vector3,
		eixo: Vector3, lado: float) -> void:
	var v := Vector3.FORWARD
	var topo := ombro + Vector3.UP * 0.03
	var aneis := []
	for k in 4:
		var t := float(k) / 3.0
		var r := MANGA_OMBRO.lerp(MANGA_COTOVELO, t)
		var a := MaoModelada._anel_braco(topo.lerp(cotovelo, t), Vector3.DOWN, v, r.x, r.y,
			MANGA, 1.0)
		a["ruga"] = 0.025 + 0.015 * t
		a["fase"] = 1.7 * float(k) + lado
		aneis.append(a)
	for t: float in [0.35, 0.7, 1.0]:
		var r := MANGA_COTOVELO.lerp(MANGA_BOCA, t * t * 0.4 + t * 0.6)
		var a := MaoModelada._anel_braco(cotovelo + eixo * MANGA_ABAIXO * t, eixo, v, r.x,
			r.y, MANGA, 1.0)
		# O pano pesa na boca: as dobras fundas descem ate a bainha.
		a["ruga"] = 0.04 + 0.035 * t
		a["fase"] = 2.3 * t + lado * 0.7
		aneis.append(a)
	# A bainha enrolada e o forro, voltando por dentro.
	var forro := [
		[MANGA_ABAIXO + 0.006, MANGA_BOCA - Vector2(0.004, 0.004), eixo],
		[MANGA_ABAIXO - 0.004, MANGA_BOCA - Vector2(0.010, 0.010), eixo],
		[MANGA_ABAIXO * 0.4, MANGA_COTOVELO - Vector2(0.012, 0.012), eixo],
	]
	for f: Array in forro:
		var r: Vector2 = f[1]
		var a := MaoModelada._anel_braco(cotovelo + eixo * float(f[0]), f[2], v, r.x, r.y,
			MANGA, 1.0)
		a["ruga"] = 0.06
		a["fase"] = 2.3 + lado * 0.7
		aneis.append(a)
	var fim := MaoModelada._anel_braco(cotovelo + Vector3.UP * 0.08, Vector3.DOWN, v,
		MANGA_COTOVELO.x - 0.016, MANGA_COTOVELO.y - 0.016, MANGA, 1.0)
	aneis.append(fim)
	var m := PSXMesh.dados_vazios()
	MaoModelada._tubo(m, aneis, MANGA_LADOS, MaoModelada._uv_liso(Aparencia.PECA_MANGA, 0.30),
		-1.0, -1.0)
	PSXMesh.acumular(dados, m, Transform3D.IDENTITY)


## A malha com a pele de ossos e as formas (posicao e normal de cada uma, na
## mesma ordem de vertices da base).
static func _com_formas(base: Dictionary, formas: Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = base["v"]
	arrays[Mesh.ARRAY_NORMAL] = base["n"]
	arrays[Mesh.ARRAY_TEX_UV] = base["uv"]
	arrays[Mesh.ARRAY_TEX_UV2] = base["uv2"]
	arrays[Mesh.ARRAY_COLOR] = base["c"]
	arrays[Mesh.ARRAY_INDEX] = base["i"]
	arrays[Mesh.ARRAY_BONES] = base["b"]
	arrays[Mesh.ARRAY_WEIGHTS] = base["w"]
	var m := ArrayMesh.new()
	m.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	var alvos := []
	for k in formas.size():
		m.add_blend_shape(FORMAS[k])
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = (formas[k] as Dictionary)["v"]
		a[Mesh.ARRAY_NORMAL] = (formas[k] as Dictionary)["n"]
		alvos.append(a)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, alvos)
	return m


## O peso de cada vertice: o antebraco abaixo do cotovelo, o braco acima,
## misturados na dobra; o alto do ombro vai um pouco com o tronco.
static func _pesar(dados: Dictionary, braco: int, ante: int, ombro: Vector3,
		cotovelo: Vector3) -> void:
	var vs: PackedVector3Array = dados["v"]
	var ossos := PackedInt32Array()
	var pesos := PackedFloat32Array()
	ossos.resize(vs.size() * 4)
	pesos.resize(vs.size() * 4)
	for i in vs.size():
		var y := vs[i].y
		var no_braco := smoothstep(cotovelo.y - DOBRA, cotovelo.y + DOBRA, y)
		var no_tronco := smoothstep(ombro.y - OMBRO_NO_TRONCO, ombro.y, y) * TRONCO_NO_ALTO
		var k := i * 4
		ossos[k] = ante
		ossos[k + 1] = braco
		ossos[k + 2] = Corpo.Osso.TORSO
		ossos[k + 3] = 0
		pesos[k] = 1.0 - no_braco
		pesos[k + 1] = no_braco * (1.0 - no_tronco)
		pesos[k + 2] = no_braco * no_tronco
		pesos[k + 3] = 0.0
	dados["b"] = ossos
	dados["w"] = pesos

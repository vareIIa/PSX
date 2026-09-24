## Uma mao de primeira pessoa em POSE: palma com um referencial, e cada dedo
## com a sua dobra.
##
## Por que existe
## --------------
## A `MaoModelada` so sabe fechar em volta de um tubo. Serve para o aro do
## volante, e para mais nada: o celular na leitura era "um tubo na quina do
## aparelho" (a mao fechava como punho num cabo e os dedos atravessavam o
## vidro), a mao no chao era "um tubo largo" (uma garra de luva virada para
## cima), e a mao no banco era uma garra tambem. Mao de gente faz outras
## coisas: espalma no assento para empurrar o corpo, abre os dedos indo buscar,
## fecha por cima de um aparelho chato, e segura o telefone com os dedos por
## tras e o polegar no vidro.
##
## Como e montada
## --------------
## Com as mesmas pecas da `MaoModelada` — a palma em superelipse, os dedos de
## tres falanges com o no em arco, o polegar com a eminencia tenar, o antebraco
## com o pulso em curva e a manga — mas cada dedo sai do no da base pela POSE,
## e nao tangente a um tubo:
##
##     dedos    [mcp, pip, dip, abre] por dedo, em graus: dobra de cada no
##              (positivo fecha para a palma, negativo estica para tras) e o
##              quanto o dedo abre para o lado do polegar;
##     polegar  [radial, palmar, giro, mcp, ip]: o metacarpo sai da palma para
##              o lado (radial) e para a frente dela (palmar), gira em volta de
##              si (0 a unha olha para o lado, 90 olha para o dorso) e dobra nos
##              dois nos.
##
## O referencial da mao e (`o`, `d`, `dorso`): `o` o meio da face da PALMA na
## linha dos nos, `d` do punho para os nos, `dorso` a normal das costas da mao.
## O polegar fica do lado `dorso x d` na mao direita, e do outro na esquerda.
class_name MaoPosada
extends RefCounted

## Onde o no da base de cada dedo fica acima da face da palma.
const NO_DA_BASE := 0.0145
## O metacarpo do polegar, da base (dentro da tenar) ao no do meio.
const POLEGAR_META := 0.044
## Quanto cada dedo abre por natureza, do indicador ao minimo (graus): os
## quatro nunca saem paralelos, nem com a mao fechada.
const ABRE_NATURAL := [3.0, 0.0, -3.5, -8.0]

## As poses. Os dedos do indicador ao minimo.
const POSES := {
	# Solta, pendurada: todo no um pouco dobrado, o minimo mais.
	&"relaxada": {"dedos": [[18, 30, 14, 2], [22, 34, 16, 0], [26, 38, 18, -2], [30, 42, 20, -4]],
		"polegar": [38, 32, 28, 12, 14]},
	# Aberta indo buscar: os dedos esticados e espalhados, o polegar longe.
	&"aberta": {"dedos": [[6, 8, 4, 9], [4, 8, 4, 2], [6, 10, 5, -5], [10, 12, 6, -12]],
		"polegar": [58, 26, 34, 4, 8]},
	# Esticada ao maximo atras de alguma coisa: os dedos passam da reta.
	&"estica": {"dedos": [[-8, 4, 2, 12], [-6, 3, 2, 3], [-4, 5, 3, -6], [-2, 7, 4, -15]],
		"polegar": [64, 22, 36, 0, 4]},
	# Espalmada no assento, empurrando o corpo: a palma inteira no estofado,
	# os dedos abertos e a ponta deles enterrando.
	&"apoio": {"dedos": [[4, 10, 8, 10], [3, 9, 8, 2], [4, 10, 8, -6], [6, 12, 9, -13]],
		"polegar": [56, 8, 18, 4, 6]},
	# Empurrando o assento com o peso do corpo: o no da base passa da reta, as
	# pontas enterram, os dedos abrem mais.
	&"apoio_forca": {"dedos": [[-10, 16, 18, 13], [-9, 15, 18, 3], [-8, 16, 18, -8], [-6, 18, 18, -17]],
		"polegar": [62, 4, 16, 0, 10]},
	# O indicador apontado (o dedo que vai encostar no vidro), os outros
	# recolhidos.
	&"aponta": {"dedos": [[6, 12, 6, 2], [52, 84, 40, 0], [60, 88, 40, -2], [66, 86, 36, -5]],
		"polegar": [26, 40, 64, 22, 30]},
	# Arranhando o ar: os dedos em garra, fechando so nos dois nos de cima.
	&"garra": {"dedos": [[14, 62, 42, 7], [12, 66, 44, 1], [14, 66, 42, -4], [18, 62, 38, -10]],
		"polegar": [50, 36, 44, 16, 26]},
	# Fechando em cima de um aparelho chato no chao: os dedos passam por cima e
	# dobram na borda de la; o polegar na borda de ca.
	&"pegar": {"dedos": [[26, 58, 30, 4], [24, 62, 32, 0], [26, 62, 30, -3], [30, 58, 26, -7]],
		"polegar": [30, 44, 62, 18, 16]},
	# Pinca por cima da borda de um aparelho de pe: os dedos descem pelas costas
	# dele, o polegar desce pelo vidro.
	# A dobra e quase toda no no da base: os dedos deitam retos nas costas.
	# O polegar sai da base da mao, na frente do aparelho, e desce reto ate o
	# vidro.
	&"pinca": {"dedos": [[90, 4, 2, 2], [90, 4, 2, 0], [90, 4, 2, -2], [90, 4, 2, -4]],
		"polegar": [0, 68, -90, 10, 8]},
	# Punho fechado de medo.
	&"punho": {"dedos": [[80, 95, 50, 0], [84, 98, 52, 0], [86, 98, 50, 0], [88, 94, 46, 0]],
		"polegar": [22, 40, 70, 30, 34]},
	# O celular na leitura, cada dedo num lugar, como numa mao de verdade: o
	# indicador deitado nas costas do aparelho (nao aparece), o medio e o anelar
	# correndo por tras e dobrando SO na quina — da frente se ve a ponta deles
	# na moldura —, o minimo por baixo, de apoio; o polegar por cima do vidro.
	# Com os quatro dobrando juntos (a primeira versao), as pontas passavam da
	# quina e viravam quatro bolas de pele em cima dos baloes da conversa.
	&"celular": {"dedos": [[0, 8, 4, 3], [4, 92, 32, 0], [6, 94, 32, -2], [30, 64, 22, -4]],
		"polegar": [40, 62, -90, 55, 18]},
	# O polegar descendo numa tecla.
	&"celular_toca": {"dedos": [[0, 8, 4, 3], [4, 92, 32, 0], [6, 94, 32, -2], [30, 64, 22, -4]],
		"polegar": [40, 68, -90, 66, 26]},
}


static func pose(nome: StringName) -> Dictionary:
	return POSES.get(nome, POSES[&"relaxada"])


## Mistura duas poses (0 = `a`, 1 = `b`).
static func misturar(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	var dedos := []
	for i in 4:
		var da: Array = a["dedos"][i]
		var db: Array = b["dedos"][i]
		var f := []
		for j in 4:
			f.append(lerpf(float(da[j]), float(db[j]), k))
		dedos.append(f)
	var pol := []
	for j in 5:
		pol.append(lerpf(float(a["polegar"][j]), float(b["polegar"][j]), k))
	return {"dedos": dedos, "polegar": pol}


## A pose com cada no mexido um pouco, dedo a dedo: `t` o tempo, `forca` em
## graus. E o que tira a mao de manequim — nenhum dedo de gente fica parado.
static func viva(p: Dictionary, t: float, forca: float, semente: float = 0.0) -> Dictionary:
	if forca <= 0.0:
		return p
	var dedos := []
	for i in 4:
		var d: Array = p["dedos"][i]
		var fi := float(i) * 1.93 + semente
		var mexe := (sin(t * 3.1 + fi) + 0.6 * sin(t * 7.3 + fi * 2.1) + 0.35 * sin(t * 17.0 + fi * 3.7)) \
			* forca
		dedos.append([float(d[0]) + mexe * 0.5, float(d[1]) + mexe, float(d[2]) + mexe * 0.6,
			float(d[3]) + sin(t * 2.3 + fi) * forca * 0.3])
	var pol: Array = (p["polegar"] as Array).duplicate()
	pol[3] = float(pol[3]) + sin(t * 2.7 + semente) * forca * 0.8
	pol[4] = float(pol[4]) + sin(t * 5.9 + semente + 1.0) * forca
	return {"dedos": dedos, "polegar": pol}


## O lado do polegar.
static func lado(d: Vector3, dorso: Vector3, direita: bool) -> Vector3:
	return dorso.cross(d).normalized() * (1.0 if direita else -1.0)


## Onde fica o punho (o centro do pulso) de uma mao neste referencial: e dali
## que o braco resolve o cotovelo.
static func punho_de(o: Vector3, d: Vector3, dorso: Vector3) -> Vector3:
	var calc: Array = MaoModelada.PALMA[0]
	return o + d.normalized() * (float(calc[0]) - 0.014) \
		+ dorso.normalized() * float(calc[2]) * 0.5


## Um ponto no referencial da mao: x para o polegar, y para o dorso, z no
## sentido dos dedos. Para quem prende coisas nela (o celular).
static func referencial(o: Vector3, d: Vector3, dorso: Vector3, direita: bool) -> Transform3D:
	var dd := d.normalized()
	var ds := (dorso - dd * dorso.dot(dd)).normalized()
	return Transform3D(Basis(lado(dd, ds, direita), ds, dd), o)


## O esqueleto da mao em pose, sem malha: e dele que a malha sai (`montar`), e
## e nele que o `AjusteDaMao` mede onde cada polpa encosta. Devolve o `q` da
## `MaoModelada`, o lado do polegar (`ld`) e o dorso (`ds`), e, por dedo e para o
## polegar, as juntas (da base a ponta) e o dorso de cada falange.
static func esqueleto(o: Vector3, d: Vector3, dorso: Vector3, p: Dictionary,
		direita: bool) -> Dictionary:
	var dd := d.normalized()
	var ds := (dorso - dd * dorso.dot(dd)).normalized()
	var ld := lado(dd, ds, direita)
	# O `q` da `MaoModelada`: a origem fica `AVANCO` antes da linha dos nos.
	var q := {"o": o - dd * MaoModelada.AVANCO, "d": dd, "dorso": ds, "tubo": ld}
	var dedos := []
	var pd: Array = p["dedos"]
	for i in 4:
		var dedo: Dictionary = MaoModelada.DEDOS[i]
		var pose_d: Array = pd[i]
		var base := MaoModelada._na_palma(q, ld, float(dedo["s"]), float(dedo["x"]),
			NO_DA_BASE)
		var abre := deg_to_rad(float(pose_d[3]) + float(ABRE_NATURAL[i]))
		var dir0 := (dd * cos(abre) + ld * sin(abre)).normalized()
		var juntas: Array[Vector3] = [base]
		var dorsos: Array[Vector3] = []
		var ang := 0.0
		var p0 := base
		var falanges: Array = dedo["f"]
		for k in 3:
			ang += deg_to_rad(float(pose_d[k]))
			var dir := dir0 * cos(ang) - ds * sin(ang)
			dorsos.append((ds * cos(ang) + dir0 * sin(ang)).normalized())
			p0 = p0 + dir * float(falanges[k])
			juntas.append(p0)
		dedos.append({"juntas": juntas, "dorsos": dorsos})

	var pol: Array = p["polegar"]
	var base_p := MaoModelada._na_palma(q, ld, MaoModelada.POLEGAR_BASE.x,
		MaoModelada.POLEGAR_BASE.y, MaoModelada.POLEGAR_BASE.z)
	var rad := deg_to_rad(float(pol[0]))
	var pal := deg_to_rad(float(pol[1]))
	var giro := deg_to_rad(float(pol[2]))
	var t0 := (dd * cos(rad) + ld * sin(rad)).normalized()
	var t_dir := (t0 * cos(pal) - ds * sin(pal)).normalized()
	# A unha: com giro 0 ela olha para o lado de fora da mao; o giro a roda em
	# volta do proprio polegar (com o polegar ao longo da mao, 90 e o dorso).
	# Dobrar leva o dedo para o lado da polpa. Girando so entre o lado e o
	# dorso (a primeira versao), o polegar que sai para a frente da palma so
	# dobrava para cima, e nunca deitava por cima do vidro do celular.
	var t_dorso := (ld - t_dir * ld.dot(t_dir)).normalized()
	t_dorso = t_dorso.rotated(t_dir, giro * (1.0 if direita else -1.0)).normalized()
	var juntas_p: Array[Vector3] = [base_p]
	var dorsos_p: Array[Vector3] = [t_dorso]
	var no_p := base_p + t_dir * POLEGAR_META
	juntas_p.append(no_p)
	var ang_p := 0.0
	var pp := no_p
	for k in 2:
		ang_p += deg_to_rad(float(pol[3 + k]))
		var dir := t_dir * cos(ang_p) - t_dorso * sin(ang_p)
		dorsos_p.append((t_dorso * cos(ang_p) + t_dir * sin(ang_p)).normalized())
		pp = pp + dir * float(MaoModelada.POLEGAR_F[k])
		juntas_p.append(pp)
	return {"q": q, "ld": ld, "ds": ds, "dd": dd, "dedos": dedos,
		"polegar": {"juntas": juntas_p, "dorsos": dorsos_p}}


## Meia largura de cada falange do dedo `i` (0 a 3; 4 e o polegar), da base a
## ponta: a malha usa estes raios, e o ajuste tambem.
static func raios_do_dedo(i: int) -> Array:
	if i == 4:
		var r_p := MaoModelada.POLEGAR_R
		return [MaoModelada.POLEGAR_TENAR, r_p * 1.04, r_p * 0.96, r_p * 0.88]
	var r: float = MaoModelada.DEDOS[i]["r"]
	var raios := []
	for f: float in MaoModelada.DEDO_AFINA:
		raios.append(r * f)
	return raios


## A polpa do dedo `i` (4 e o polegar) no esqueleto `e`: o ponto da ponta que
## encosta nas coisas, e o dorso dela (a unha olha para ele).
static func polpa(e: Dictionary, i: int) -> Dictionary:
	var dedo: Dictionary = e["polegar"] if i == 4 else e["dedos"][i]
	var juntas: Array[Vector3] = dedo["juntas"]
	var dorsos: Array[Vector3] = dedo["dorsos"]
	var n := juntas.size() - 1
	var dir := (juntas[n] - juntas[n - 1]).normalized()
	var dorso: Vector3 = dorsos[dorsos.size() - 1]
	var rp: float = raios_do_dedo(i)[3]
	var centro := juntas[n] - dir * rp
	return {"p": centro - dorso * rp * MaoModelada.DEDO_ACHATA, "dorso": dorso,
		"centro": centro, "dir": dir}


## Monta a mao e o antebraco em `dados`. Devolve `punho` e `eixo` (para onde o
## antebraco aponta), como a `MaoModelada.segurando`.
static func montar(dados: Dictionary, o: Vector3, d: Vector3, dorso: Vector3,
		p: Dictionary, direita: bool, cotovelo: Vector3, pele: Color, manga: Color,
		manga_longa: bool) -> Dictionary:
	var m := PSXMesh.dados_vazios()
	var e := esqueleto(o, d, dorso, p, direita)
	var dd: Vector3 = e["dd"]
	var ds: Vector3 = e["ds"]
	var ld: Vector3 = e["ld"]
	var q: Dictionary = e["q"]
	var uv_pele := MaoModelada._uv_liso(Aparencia.PECA_MAO, 0.14)
	var uv_pano := MaoModelada._uv_liso(Aparencia.PECA_MANGA, 0.30)
	var cores := MaoModelada._tons(pele)

	MaoModelada._palma(m, q, ld, 0.0, cores, uv_pele)

	for i in 4:
		var dedo: Dictionary = e["dedos"][i]
		MaoModelada._corrente(m, dedo["juntas"], dedo["dorsos"], raios_do_dedo(i), cores,
			uv_pele, dd, ds)

	var pol: Dictionary = e["polegar"]
	MaoModelada._corrente(m, pol["juntas"], pol["dorsos"], raios_do_dedo(4), cores, uv_pele,
		Vector3.ZERO, Vector3.ZERO)
	var no_indicador: Vector3 = (e["dedos"][0]["juntas"] as Array[Vector3])[0]
	_membrana(m, (pol["juntas"] as Array[Vector3])[1], no_indicador, ds, cores, uv_pele)

	var braco := MaoModelada._antebraco(m, q, ld, 0.0, cotovelo, manga, manga_longa,
		cores, uv_pele, uv_pano)
	PSXMesh.acumular(dados, m, Transform3D.IDENTITY)
	return braco


## A pele entre o polegar e o indicador: uma cinta chata do no do meio do
## polegar a base do indicador. Sem ela o vao entre os dois abria uma fresta
## escura na forquilha.
static func _membrana(m: Dictionary, no_polegar: Vector3, no_indicador: Vector3,
		dorso: Vector3, cores: Dictionary, uv: Vector2) -> void:
	var eixo := no_indicador - no_polegar
	if eixo.length() < 0.005:
		return
	var a := eixo.normalized()
	var aneis := []
	for t: float in [0.0, 0.5, 1.0]:
		var largo := 1.0 + 0.3 * sin(PI * t)
		aneis.append({"c": no_polegar + eixo * t + dorso * 0.002 * sin(PI * t), "a": a,
			"v": dorso, "ru": 0.0105 * largo, "rv": 0.0065, "cor": cores["dorso"],
			"cor_palma": cores["palma"]})
	MaoModelada._tubo(m, aneis, MaoModelada.LADOS_DEDO, uv, 0.003, 0.003)

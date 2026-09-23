## O telhado da casa de Minas: telha de verdade, beiral, cumeeira e o que mora em cima.
##
## Por que existe
## -------------
## O levantamento da F4 (PLANO_CASAS_AAA.md, F6) achou uma cidade de laje: so 8,7%
## dos lotes terminavam em telha, e o telhado que havia (KitPredio.telhado) era uma
## laje de 10 cm a 22% de caimento com a textura em xadrez, beira e cumeeira retas,
## sem forro, com a cachorrada solta 7 a 15 cm abaixo da agua. Do mirante, o anel
## comercial da praca lia como cidade mediterranea.
##
## Cidade do interior mineiro e mar de telha: capa-e-canal de barro no casario,
## telha francesa no sobrado e na casa dos anos 50, fibrocimento no puxadinho e na
## laje da autoconstrucao, e a platibanda da rua comercial ESCONDENDO um telhado
## (ela e fachada, nao cobertura).
##
## Como e montado
## --------------
## A agua e um plano que passa rente ao topo da parede e desce ate a ponta do
## beiral. Em dois niveis:
##   - a agua plana, subdividida, com a textura de telha (capa e canal pintados),
##     sempre desenhada: e o que se ve de longe e no mirante;
##   - de perto (balde "@perto", ChunkManager.ALCANCE_PERTO), a capa-e-canal com o
##     perfil de verdade, pousada sobre a plana e alinhada com as colunas da
##     textura: a beira sai recortada, e o sol raspa o gomo.
## Quatro aguas na quina (a agua no lugar da empena, do lado da rua transversal),
## com o espigao coberto de capa como a cumeeira. Debaixo do beiral, forro de
## tabuado, forro liso ou a telha va com a cachorrada presa na agua; na casa de
## quem tem posse, a beira-seveira caiada ("sem eira nem beira" e a casa pobre).
##
## Custo: a agua plana sai na casa das dezenas de triangulos por agua; a ondulada,
## so no balde @perto, nas centenas. Medido em PLANO_CASAS_AAA.md.
##
## O sorteio daqui usa um gerador proprio, semeado pela semente do plano: gastar
## o gerador do chunk mudaria todos os lotes seguintes da fileira.
class_name TelhadoVivo
extends RefCounted

const ANDAR := KitModular.ALTURA_ANDAR
## Espessura da telha plana sobre a face de baixo da agua.
const ESPESSURA := 0.05
## A fiada de linhas da agua plana (a UV afim do PS1 pede subdivisao).
const PASSO_PLANO := 2.0
## A fiada de linhas da ondulada ao longo da queda.
const PASSO_ONDA := 1.6
## Raio da capa da cumeeira e do espigao.
const RAIO_CAPA := 0.12
## O que o beiral tem de passar por cima: a cimalha sai 20 cm da fachada.
const CIMALHA := Vector2(0.2, 0.03)
## Distancia entre cachorros (caibro a caibro).
const PASSO_CACHORRO := 0.42

## Telha: caimento (subida por metro), perfil da onda (fracao do periodo, altura
## acima da agua plana) e material. O periodo casa com as colunas da textura: a
## UV anda 0,5 por metro e a textura tem 12 colunas em 2 m, capa nas pares; seis
## pares de capa e canal em 2 m dao 1/3 m por periodo.
const TELHAS := {
	&"capa_canal": {"caimento": 0.40, "periodo": 1.0 / 3.0, "material": &"telha",
		"perfil": [Vector2(0.0, 0.035), Vector2(0.25, 0.075), Vector2(0.5, 0.035),
			Vector2(0.75, 0.004)]},
	&"francesa": {"caimento": 0.35, "periodo": 0.25, "material": &"telha_francesa",
		"perfil": [Vector2(0.0, 0.03), Vector2(0.18, 0.042), Vector2(0.36, 0.03),
			Vector2(0.68, 0.006)]},
	&"fibrocimento": {"caimento": 0.15, "periodo": 0.0, "material": &"metal_ondulado",
		"perfil": []},
}
## Barro novo, queimado, velho e o do limo: a tinta multiplica a textura.
const TONS: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.93, 0.86, 0.82),
	Color(0.82, 0.8, 0.76), Color(0.74, 0.72, 0.68)]
const LIMO := Color(0.62, 0.66, 0.5)
const FIBRO := Color("c9c5ba")
const ARGAMASSA := Color("d9d4c8")
const MADEIRA := Color("4a3424")
## Forro de tabuado pintado: o branco, o azul e o verde das janelas coloniais.
const FORROS: Array[Color] = [Color("f0ece2"), Color("9fb7c9"), Color("a9c3a4"),
	Color("e7dcc0")]


# --- plano -------------------------------------------------------------------

## Decide o telhado da casa depois de FachadaViva.planejar ou ComercioVivo.planejar
## (que ja sortearam estilo, morador e remate). Grava `plano["telhado"]`, e pode
## trocar o remate da autoconstrucao (laje coberta) e da platibanda (telhado
## escondido atras dela).
static func planejar(plano: Dictionary) -> void:
	if not ativo:
		return
	var r := RandomNumberGenerator.new()
	r.seed = int(plano.get("semente", 0)) ^ 0x7e1ad0
	var estilo: StringName = plano.get("estilo", &"popular")
	var morador: StringName = plano.get("morador", &"familia")
	var remate: StringName = plano.get("remate", &"laje")
	var tipo: StringName = plano.get("tipo", &"")
	var t := {}
	match remate:
		&"telhado":
			t["forma"] = &"aparente"
			if estilo == &"colonial":
				t["telha"] = &"capa_canal"
			else:
				t["telha"] = &"capa_canal" if r.randf() < 0.3 else &"francesa"
		&"platibanda", &"platibanda_baixa":
			# A platibanda e fachada: atras dela ha telhado, e so o predio alto e a
			# loja nova tem laje de verdade.
			var chance := 0.72
			if tipo == &"predio":
				chance = 0.3 if int(plano.get("andares", 3)) <= 3 else 0.0
			if r.randf() >= chance:
				return
			t["forma"] = &"escondido"
			if r.randf() < 0.38:
				t["forma"] = &"meia_agua"
				t["telha"] = &"fibrocimento"
			else:
				t["telha"] = &"francesa" if r.randf() < 0.75 else &"capa_canal"
		&"laje":
			if estilo != &"popular" or r.randf() >= 0.5:
				return
			t["forma"] = &"laje_coberta"
			t["telha"] = &"fibrocimento"
		_:
			return
	var telha: Dictionary = TELHAS[t["telha"]]
	t["caimento"] = float(telha["caimento"]) * r.randf_range(0.92, 1.08)
	if t["forma"] == &"meia_agua" or t["forma"] == &"laje_coberta":
		t["caimento"] = 0.1
	# Beiral: o colonial avanca 60 cm, com cachorrada ou com a beira-seveira; o
	# moderno 70, com forro liso.
	t["beiral"] = 0.0
	t["cachorrada"] = false
	t["fiadas"] = 0
	t["forro"] = &"liso"
	if t["forma"] == &"aparente":
		if estilo == &"colonial":
			if r.randf() < 0.55:
				t["cachorrada"] = true
				t["beiral"] = 0.62
				t["forro"] = &"va"
			else:
				# Eira, beira e tribeira: quem tem posse leva as fiadas; a casa
				# fechada e a abandonada ficam sem.
				t["fiadas"] = 0 if morador == &"fechada" or morador == &"abandonada" \
					else (3 if morador == &"zelosa" or morador == &"idoso" else 2)
				t["beiral"] = 0.42 if int(t["fiadas"]) > 0 else 0.5
				t["forro"] = &"tabuado"
		else:
			t["beiral"] = 0.7
			t["forro"] = &"liso"
	t["cor_forro"] = FORROS[r.randi() % FORROS.size()]
	var tom: Color = TONS[r.randi() % TONS.size()]
	# Uma casa nunca tem a telha da vizinha: trocada ano passado, ou vinte anos de limo.
	t["tom"] = tom.lerp(Color.WHITE, r.randf_range(0.0, 0.4))
	t["limo"] = r.randf_range(0.15, 0.6)
	if morador == &"abandonada":
		t["limo"] = 0.95
		t["tom"] = TONS[3]
	t["semente"] = r.randi()
	plano["telhado"] = t


## Chave de bancada: `--sem-telhado-vivo` volta ao KitPredio.telhado.
static var ativo := not OS.get_cmdline_user_args().has("--sem-telhado-vivo")


## Telhado aparente para quem nao tem fachada viva (edicula e galpao do miolo,
## MioloVivo): telha, beiral e semente. Sem cachorrada nem fiada.
static func simples(telha: StringName, beiral: float, semente: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	var t := {"forma": &"aparente", "telha": telha, "beiral": beiral,
		"cachorrada": false, "fiadas": 0, "forro": &"tabuado",
		"cor_forro": FORROS[r.randi() % FORROS.size()]}
	t["caimento"] = float(TELHAS[telha]["caimento"]) * r.randf_range(0.92, 1.08)
	var tom: Color = TONS[r.randi() % TONS.size()]
	t["tom"] = tom.lerp(Color.WHITE, r.randf_range(0.0, 0.3))
	t["limo"] = r.randf_range(0.3, 0.8)
	t["semente"] = r.randi()
	return t


## Bancada: com `registrar`, cada telhado aparente anota onde ficou (coordenada do
## chunk) em `registro`, para a captura achar a pose.
static var registrar := false
static var registro: Array[Dictionary] = []


## A casa tem telhado desta classe?
static func tem(plano: Dictionary) -> bool:
	return plano.has("telhado")


# --- geometria comum -----------------------------------------------------------

## O referencial da casa: `x` ao longo da fachada (lateral), `s` para dentro a
## partir do plano da fachada, `y` absoluto.
class Referencial extends RefCounted:
	var origem: Vector3
	var lateral: Vector3
	var dentro: Vector3

	func p(x: float, s: float, y: float) -> Vector3:
		return origem + lateral * x + dentro * s + Vector3(0.0, y, 0.0)


static func _quadro(topo: Vector3, tamanho: Vector3, direcao: int) -> Array:
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var fundura := absf(tamanho.x * normal.x) + absf(tamanho.z * normal.z)
	var larg := absf(tamanho.x * lateral.x) + absf(tamanho.z * lateral.z)
	var q := Referencial.new()
	q.lateral = lateral
	q.dentro = -normal
	q.origem = Vector3(topo.x, 0.0, topo.z) + normal * (fundura * 0.5 + ChunkBuilder.AVANCO_FACHADA)
	return [q, larg, fundura + ChunkBuilder.AVANCO_FACHADA]


## Altura do perfil da onda na fracao `f` do periodo (linear entre os pontos).
static func _onda(perfil: Array, f: float) -> float:
	var n := perfil.size()
	for k in n:
		var a: Vector2 = perfil[k]
		var b: Vector2 = perfil[(k + 1) % n]
		var bx := b.x if k + 1 < n else 1.0
		if f >= a.x and f <= bx:
			return lerpf(a.y, b.y, (f - a.x) / maxf(bx - a.x, 1e-5))
	return (perfil[0] as Vector2).y


## Uma agua: a face que desce do cume ate o beiral de comprimento `lu`, vista no
## plano dela. `o` e o canto esquerdo da ponta do beiral (na face de baixo),
## `eu` corre ao longo do beiral, `ev_h` e o horizontal morro acima (para dentro
## da casa). O topo da agua, em distancia horizontal do beiral, e
## min(y_cume, u se espigao a esquerda, lu - u se espigao a direita): a quatro
## aguas de caimento igual poe o espigao a 45 graus em planta.
##
## `perfil` vazio sai a agua plana; com perfil, a ondulada, `ESPESSURA` acima.
static func _agua(ob: Obra, material: StringName, o: Vector3, eu: Vector3, ev_h: Vector3,
		lu: float, y_cume: float, esp_e: bool, esp_d: bool, caimento: float,
		perfil: Array, periodo: float, tom: Color, limo: float, fibro: bool) -> void:
	if lu < 0.05 or y_cume < 0.05:
		return
	var sobe := ev_h + Vector3(0.0, caimento, 0.0)
	var normal := eu.cross(sobe).normalized()
	if normal.y < 0.0:
		normal = -normal
	var fator_queda := sobe.length()
	var ondulada := not perfil.is_empty()
	# Colunas: os pontos do perfil, as pontas e as dobras do espigao.
	var us := PackedFloat32Array()
	if ondulada:
		var k := 0
		while true:
			var base_u := float(k) * periodo
			if base_u > lu:
				break
			for pt: Vector2 in perfil:
				var u := base_u + pt.x * periodo
				if u > 0.0 and u < lu:
					us.append(u)
			k += 1
	else:
		var n := maxi(1, ceili(lu / PASSO_PLANO))
		for k in range(1, n):
			us.append(lu * float(k) / float(n))
	us.append(0.0)
	us.append(lu)
	if esp_e and y_cume < lu:
		us.append(y_cume)
	if esp_d and y_cume < lu:
		us.append(lu - y_cume)
	us.sort()
	var limpo := PackedFloat32Array()
	for u: float in us:
		if limpo.is_empty() or u - limpo[limpo.size() - 1] > 0.002:
			limpo.append(u)
	us = limpo
	var linhas := maxi(1, ceili(y_cume * fator_queda / (PASSO_ONDA if ondulada else PASSO_PLANO)))
	var m := ob.malha(material)
	var col_ids: Array[PackedInt32Array] = []
	var v_total := y_cume * fator_queda
	for u: float in us:
		var topo := y_cume
		if esp_e:
			topo = minf(topo, u)
		if esp_d:
			topo = minf(topo, lu - u)
		topo = maxf(topo, 0.0)
		var h := 0.0
		var nv := normal
		if ondulada:
			var f := fposmod(u / periodo, 1.0)
			h = _onda(perfil, f)
			var d := 0.02 / periodo
			var inclina := (_onda(perfil, fposmod(f + d, 1.0)) - _onda(perfil, fposmod(f - d, 1.0))) \
				/ (0.04)
			nv = (normal - eu * inclina).normalized()
		var ids := PackedInt32Array()
		for k in linhas + 1:
			var y := topo * float(k) / float(linhas)
			var p := o + eu * u + ev_h * y + Vector3(0.0, y * caimento, 0.0) \
				+ normal * (ESPESSURA + h)
			var v_m := y * fator_queda
			# UV: u ao longo do beiral; v desce da cumeeira (a sombra da fiada fica
			# logo abaixo do encontro). O fibrocimento tem o gomo em v: gira.
			var uv := Vector2(u, v_total - v_m) * 0.5
			if fibro:
				uv = Vector2(v_total - v_m, u) * 0.5
			var f_beiral := 1.0 - y / y_cume
			var cor := tom.lerp(tom * LIMO, limo * smoothstep(0.4, 1.0, f_beiral))
			cor.a = 1.0
			ids.append(m.vertice(p, nv, uv, Vector2(u / lu, f_beiral), cor))
		col_ids.append(ids)
	for c in us.size() - 1:
		var a: PackedInt32Array = col_ids[c]
		var b: PackedInt32Array = col_ids[c + 1]
		for k in linhas:
			m.quad(a[k], b[k], b[k + 1], a[k + 1], normal)


## Capa corrida (cumeeira ou espigao) de `a` a `b`: meio octogono de telha com a
## argamassa dos dois lados descendo ate a agua. `lado` e o horizontal para um
## dos lados da capa (perpendicular a ela); `queda` quanto a agua desce por metro
## para os lados.
static func _capa(ob: Obra, material: StringName, a: Vector3, b: Vector3, lado: Vector3,
		queda: float, tom: Color, fechar_a: bool, fechar_b: bool) -> void:
	var eixo := (b - a)
	var comp := eixo.length()
	if comp < 0.05:
		return
	eixo /= comp
	var cima := lado.cross(eixo).normalized()
	if cima.y < 0.0:
		cima = -cima
	var r := RAIO_CAPA
	var secao: Array[Vector2] = []
	for k in 5:
		var ang := PI * float(k) / 4.0
		secao.append(Vector2(-cos(ang) * r, sin(ang) * r))
	var m := ob.malha(material)
	var cor := tom.darkened(0.08)
	for k in 4:
		var p0 := secao[k]
		var p1 := secao[k + 1]
		var n := (lado * ((p0.x + p1.x) * 0.5) + cima * ((p0.y + p1.y) * 0.5)).normalized()
		var off0 := lado * p0.x + cima * p0.y
		var off1 := lado * p1.x + cima * p1.y
		var n0 := (lado * p0.x + cima * p0.y).normalized()
		var n1 := (lado * p1.x + cima * p1.y).normalized()
		var u0 := float(k) * r * 0.5
		var u1 := float(k + 1) * r * 0.5
		var i0 := m.vertice(a + off0, n0, Vector2(0.0, u0), Vector2.ZERO, cor)
		var i1 := m.vertice(b + off0, n0, Vector2(comp * 0.5, u0), Vector2.ZERO, cor)
		var i2 := m.vertice(b + off1, n1, Vector2(comp * 0.5, u1), Vector2.ZERO, cor)
		var i3 := m.vertice(a + off1, n1, Vector2(0.0, u1), Vector2.ZERO, cor)
		m.quad(i0, i1, i2, i3, n)
	# Argamassa: do pe da capa ate a agua, dos dois lados.
	var arg := ob.malha(&"reboco")
	for s: float in [-1.0, 1.0]:
		var pe := lado * (s * r) + cima * 0.0
		var fora := lado * (s * (r + 0.05)) - Vector3(0.0, (r + 0.05) * queda + 0.03, 0.0)
		var n := (cima + lado * s * 0.6).normalized()
		var i0 := arg.vertice(a + pe, n, Vector2(0.0, 0.0), Vector2.ZERO, ARGAMASSA)
		var i1 := arg.vertice(b + pe, n, Vector2(comp * 0.5, 0.0), Vector2.ZERO, ARGAMASSA)
		var i2 := arg.vertice(b + fora, n, Vector2(comp * 0.5, 0.05), Vector2.ZERO, ARGAMASSA)
		var i3 := arg.vertice(a + fora, n, Vector2(0.0, 0.05), Vector2.ZERO, ARGAMASSA)
		arg.quad(i0, i1, i2, i3, n)
	# A boca da capa na ponta que fica a vista, cheia de argamassa encardida (a
	# caiada pura, vista de baixo no espigao, lia como caco solto).
	var boca := ARGAMASSA.lerp(tom * Color(0.7, 0.55, 0.45), 0.45)
	for ponta: Array in [[a, -eixo, fechar_a], [b, eixo, fechar_b]]:
		if not bool(ponta[2]):
			continue
		var c: Vector3 = ponta[0]
		var n: Vector3 = ponta[1]
		var ic := arg.vertice(c, n, Vector2.ZERO, Vector2.ZERO, boca)
		for k in 4:
			var i0 := arg.vertice(c + lado * secao[k].x + cima * secao[k].y, n, Vector2.ZERO,
				Vector2.ZERO, boca)
			var i1 := arg.vertice(c + lado * secao[k + 1].x + cima * secao[k + 1].y, n,
				Vector2.ZERO, Vector2.ZERO, boca)
			arg.tri(ic, i0, i1, n)


## Capa argamassada do oitao: caixa de 8 cm ao longo da beira inclinada, de `de`
## (ponta do beiral) a `ate` (cumeeira), com o pe na face de baixo da agua e o
## topo 2 cm acima da capa mais alta da ondulada. Fica 4,5 cm para dentro da
## divisa, e a do vizinho, do lado dele: as duas nunca se sobrepoem.
static func _capa_oitao(ob: Obra, de: Vector3, ate: Vector3, lateral: Vector3,
		cor: Color) -> void:
	var dir := ate - de
	var comp := dir.length()
	if comp < 0.05:
		return
	dir /= comp
	var cima := dir.cross(lateral).normalized()
	if cima.y < 0.0:
		cima = -cima
	const ALTO := ESPESSURA + 0.14
	ob.livre(&"reboco", (de + ate) * 0.5 + cima * (ALTO * 0.5), Vector3(0.08, ALTO, comp + 0.04),
		Basis(lateral, cima, dir), cor)


## Quad qualquer virado para `normal`, com UV em metro ao longo de `eixo_u`.
static func _quad(ob: Obra, material: StringName, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, normal: Vector3, eixo_u: Vector3, cor: Color) -> void:
	ob.quadra(material, a, b, c, d, normal, eixo_u, a, cor)


# --- telhado aparente ----------------------------------------------------------

## O telhado da casa: aparente (duas aguas, ou com agua no lugar da empena na
## quina), escondido atras da platibanda, meia-agua escondida, ou a laje coberta
## de fibrocimento. `topo` e o meio da massa no topo da parede (ChunkBuilder).
static func montar(sup: Dictionary, plano: Dictionary, topo: Vector3, tamanho: Vector3,
		direcao: int) -> void:
	var t: Dictionary = plano["telhado"]
	var ob := Obra.new()
	match t["forma"]:
		&"aparente":
			_aparente(ob, plano, t, topo, tamanho, direcao)
		&"escondido":
			_escondido(ob, plano, t, topo, tamanho, direcao)
		&"meia_agua":
			_meia_agua_escondida(ob, plano, t, topo, tamanho, direcao)
		&"laje_coberta":
			_laje_coberta(ob, plano, t, topo, tamanho, direcao)
	ob.despejar(sup)


## Altura da face de baixo da agua no plano da fachada: rente ao topo da parede,
## ou acima da cimalha (que sai 20 cm) quando a fachada tem uma.
static func _y_parede(plano: Dictionary, altura: float, caimento: float) -> float:
	var estilo: StringName = plano.get("estilo", &"popular")
	var t: Dictionary = plano["telhado"]
	var y := altura + 0.02
	if estilo == &"colonial" or estilo == &"ecletico" or estilo == &"moderno":
		y = altura + CIMALHA.y + CIMALHA.x * caimento
	if bool(t.get("cachorrada", false)):
		# O cachorro tem 10 cm e passa por cima da cimalha.
		y += 0.1
	return y


## A ponta do beiral de tras: quanto sai da parede e a altura da face de baixo
## ali. Para a calha da FundosVivos e para o puxadinho caber debaixo dele. Vazio
## quando a casa nao tem beiral atras.
static func beiral_de_tras(plano: Dictionary) -> Dictionary:
	if not plano.has("telhado"):
		return {}
	var t: Dictionary = plano["telhado"]
	if t["forma"] != &"aparente":
		return {}
	var altura := int(plano.get("andares", 1)) * ANDAR
	var c := float(t["caimento"])
	var a := float(t["beiral"])
	return {"sai": a, "y": _y_parede(plano, altura, c) - a * c}


static func _aparente(ob: Obra, plano: Dictionary, t: Dictionary,
		topo: Vector3, tamanho: Vector3, direcao: int) -> void:
	var qq := _quadro(topo, tamanho, direcao)
	var q: Referencial = qq[0]
	var larg: float = qq[1]
	var fundo: float = qq[2]
	var altura := topo.y
	var c := float(t["caimento"])
	var a := float(t["beiral"])
	var y_w := _y_parede(plano, altura, c)
	var telha: Dictionary = TELHAS[t["telha"]]
	var mat: StringName = telha["material"]
	var perfil: Array = telha["perfil"]
	var periodo := float(telha["periodo"])
	var tom: Color = t["tom"]
	var limo := float(t["limo"])
	var cor_corpo: Color = plano.get("cor_corpo", Color("d8d2c6"))
	# Agua no lugar da empena do lado da rua transversal (a quina).
	var quinas: Array = plano.get("quinas", [])
	var esp_e := quinas.has(-1.0) or quinas.has(-1)
	var esp_d := quinas.has(1.0) or quinas.has(1)
	var meia := larg * 0.5
	# O retangulo do beiral em planta: frente em s = -a, fundo em s = fundo + a;
	# dos lados rente a divisa, ou com beiral onde a agua vira a quina.
	var x_e := -meia - (a if esp_e else 0.0)
	var x_d := meia + (a if esp_d else 0.0)
	var dy := fundo + 2.0 * a
	var y_cume := dy * 0.5
	var lu := x_d - x_e
	# Com as duas quinas e a casa estreita, o espigao passaria do cume: vira duas
	# aguas (nunca chega aqui na fileira, so na casa de quina dos dois lados).
	if esp_e and esp_d and lu < dy:
		esp_e = false
		esp_d = false
		x_e = -meia
		x_d = meia
		lu = larg
	var y_beiral := y_w - a * c
	if registrar:
		registro.append({"centro": q.p(0.0, fundo * 0.5, altura), "frente": q.p(0.0, 0.0, altura),
			"quina": esp_e or esp_d, "estilo": plano.get("estilo", &""), "telha": t["telha"],
			"cachorrada": t["cachorrada"], "fiadas": t["fiadas"]})
	var cor_frente := tom
	var cor_fundo := tom.darkened(0.06)
	# Frente e fundo.
	for lado: float in [1.0, -1.0]:
		var ev_h := q.dentro * lado
		var eu := q.lateral * lado
		var o: Vector3
		if lado > 0.0:
			o = q.p(x_e, -a, y_beiral)
		else:
			o = q.p(x_d, fundo + a, y_beiral)
		var e1 := esp_e if lado > 0.0 else esp_d
		var e2 := esp_d if lado > 0.0 else esp_e
		var tom_agua := cor_frente if lado > 0.0 else cor_fundo
		_agua(ob, mat, o, eu, ev_h, lu, y_cume, e1, e2, c, [], 0.0, tom_agua, limo,
			t["telha"] == &"fibrocimento")
		if not perfil.is_empty():
			_agua(ob, JanelaViva._p(mat), o, eu, ev_h, lu, y_cume, e1, e2, c, perfil, periodo,
				tom_agua, limo, false)
	# As aguas da quina. A da esquerda nasce no canto da frente e corre para o
	# fundo; a da direita, o contrario.
	for s: float in [-1.0, 1.0]:
		var tem_esp := esp_e if s < 0.0 else esp_d
		if not tem_esp:
			continue
		var ev_h := -q.lateral * s
		var eu := -q.dentro * s
		var x0 := x_e if s < 0.0 else x_d
		var o := q.p(x0, -a if s < 0.0 else fundo + a, y_beiral)
		_agua(ob, mat, o, eu, ev_h, dy, y_cume, true, true, c, [], 0.0, tom.darkened(0.03),
			limo, t["telha"] == &"fibrocimento")
		if not perfil.is_empty():
			_agua(ob, JanelaViva._p(mat), o, eu, ev_h, dy, y_cume, true, true, c, perfil,
				periodo, tom.darkened(0.03), limo, false)

	# Cumeeira e espigoes.
	var y_capa := y_beiral + y_cume * c + ESPESSURA + 0.05
	var s_cume := fundo * 0.5
	var cx_e := x_e + (y_cume if esp_e else 0.0)
	var cx_d := x_d - (y_cume if esp_d else 0.0)
	# As pontas sempre fechadas: aberta no encontro com o espigao, quem olha de
	# baixo via por dentro do prisma a argamassa do outro lado, em cacos brancos.
	_capa(ob, mat, q.p(cx_e, s_cume, y_capa), q.p(cx_d, s_cume, y_capa), q.dentro, c, tom,
		true, true)
	for s: float in [-1.0, 1.0]:
		var tem_esp := esp_e if s < 0.0 else esp_d
		if not tem_esp:
			continue
		var x0 := x_e if s < 0.0 else x_d
		var xc := cx_e if s < 0.0 else cx_d
		for f: float in [-1.0, 1.0]:
			var s0 := -a if f < 0.0 else fundo + a
			var canto := q.p(x0, s0, y_beiral + ESPESSURA + 0.05)
			var cume := q.p(xc, s_cume, y_capa)
			var lado := (cume - canto).cross(Vector3.UP).normalized()
			_capa(ob, mat, canto, cume, lado, c * 0.7, tom, true, true)

	# Empena: o triangulo de parede do lado sem agua, do topo da parede ate a
	# face de baixo da agua. E a parede da divisa; na quina ela nao existe.
	for s: float in [-1.0, 1.0]:
		var tem_esp := esp_e if s < 0.0 else esp_d
		if tem_esp:
			continue
		var x := meia * s
		var pts := PackedVector3Array([q.p(x, 0.0, altura), q.p(x, 0.0, y_w),
			q.p(x, fundo * 0.5, y_w + fundo * 0.5 * c), q.p(x, fundo, y_w), q.p(x, fundo, altura)])
		ob.leque(&"reboco", pts, q.lateral * s, q.dentro, q.p(x, 0.0, altura + 2.0),
			cor_corpo.lerp(Color("c9c1b2"), 0.2))
		# A capa do oitao: a argamassa que fecha a ponta das fiadas, da ponta do
		# beiral ate a cumeeira, na frente e atras. Caixa, e nao fita: com o vizinho
		# um palmo mais baixo (cada lote sobe rigido na ladeira) a fita de uma face
		# so aparecia em cacos por cima do telhado dele.
		for f: float in [-1.0, 1.0]:
			var s0 := -a if f < 0.0 else fundo + a
			_capa_oitao(ob, q.p(x - s * 0.045, s0, y_beiral - 0.03),
				q.p(x - s * 0.045, s_cume, y_beiral + y_cume * c - 0.03), q.lateral,
				ARGAMASSA.lerp(cor_corpo, 0.3))

	# Frechal: da parede ate a face de baixo da agua, na frente, atras e na quina.
	# Comeca rente ao topo da parede, que e do mesmo plano: sobrepor os dois dava
	# faixa piscando.
	var cor_frechal := cor_corpo.darkened(0.04)
	if y_w > altura + 0.005:
		for f: float in [-1.0, 1.0]:
			var s0 := 0.0 if f < 0.0 else fundo
			var n := -q.dentro if f < 0.0 else q.dentro
			_quad(ob, &"reboco", q.p(-meia, s0, altura), q.p(meia, s0, altura),
				q.p(meia, s0, y_w), q.p(-meia, s0, y_w), n, q.lateral, cor_frechal)
		for s: float in [-1.0, 1.0]:
			var tem_esp := esp_e if s < 0.0 else esp_d
			if not tem_esp:
				continue
			var x := meia * s
			_quad(ob, &"reboco", q.p(x, 0.0, altura), q.p(x, fundo, altura),
				q.p(x, fundo, y_w), q.p(x, 0.0, y_w), q.lateral * s, q.dentro, cor_frechal)

	# Beiral: forro por baixo, testeira na ponta, cachorrada ou beira-seveira.
	_beirais(ob, plano, t, q, meia, fundo, a, c, y_w, esp_e, esp_d)
	# O que mora em cima: chamine, antena, caixa d'agua, aquecedor, lona, mato.
	_em_cima(ob, plano, t, q, meia, fundo, a, c, y_w, esp_e, esp_d)


## O que se ve debaixo do beiral, nos lados com agua.
static func _beirais(ob: Obra, plano: Dictionary, t: Dictionary, q: Referencial,
		meia: float, fundo: float, a: float, c: float, y_w: float, esp_e: bool,
		esp_d: bool) -> void:
	if a < 0.05:
		return
	var forro: StringName = t["forro"]
	var mat_forro := &"reboco"
	var cor_forro: Color = t["cor_forro"]
	if forro == &"va":
		mat_forro = &"tabua"
		cor_forro = Color("6a5240")
	elif forro == &"tabuado":
		mat_forro = &"tabua"
	var cor_testeira := MADEIRA if forro == &"va" else cor_forro.darkened(0.08)
	# Cada lado: (canto esquerdo e direito na parede, os mesmos na ponta, para fora,
	# ao longo, e se da para a rua). O fundo nao leva cachorrada: ninguem ve.
	var lados: Array = []
	var xe_p := -meia - (a if esp_e else 0.0)
	var xd_p := meia + (a if esp_d else 0.0)
	lados.append([q.p(-meia, 0.0, 0.0), q.p(meia, 0.0, 0.0), q.p(xe_p, -a, 0.0),
		q.p(xd_p, -a, 0.0), -q.dentro, q.lateral, true])
	lados.append([q.p(meia, fundo, 0.0), q.p(-meia, fundo, 0.0), q.p(xd_p, fundo + a, 0.0),
		q.p(xe_p, fundo + a, 0.0), q.dentro, -q.lateral, false])
	if esp_e:
		lados.append([q.p(-meia, fundo, 0.0), q.p(-meia, 0.0, 0.0), q.p(-meia - a, fundo + a, 0.0),
			q.p(-meia - a, -a, 0.0), -q.lateral, -q.dentro, true])
	if esp_d:
		lados.append([q.p(meia, 0.0, 0.0), q.p(meia, fundo, 0.0), q.p(meia + a, -a, 0.0),
			q.p(meia + a, fundo + a, 0.0), q.lateral, q.dentro, true])
	var y_b := y_w - a * c
	var up_w := Vector3(0.0, y_w, 0.0)
	var up_b := Vector3(0.0, y_b, 0.0)
	var fiadas := int(t.get("fiadas", 0))
	for l: Array in lados:
		var w0: Vector3 = l[0] + up_w
		var w1: Vector3 = l[1] + up_w
		var p0: Vector3 = l[2] + up_b
		var p1: Vector3 = l[3] + up_b
		var fora: Vector3 = l[4]
		var ao_longo: Vector3 = l[5]
		var da_rua: bool = l[6]
		var baixo := (-(fora * c) - Vector3.UP).normalized()
		# O forro, na inclinacao da agua (o caibro).
		_quad(ob, mat_forro, w0, w1, p1, p0, baixo, ao_longo, cor_forro)
		# A testeira: a tabua da ponta, do forro ate a telha.
		var alto := Vector3(0.0, ESPESSURA + 0.02, 0.0)
		_quad(ob, &"tabua", p0 - Vector3(0.0, 0.05, 0.0), p1 - Vector3(0.0, 0.05, 0.0),
			p1 + alto, p0 + alto, fora, ao_longo, cor_testeira)
		var comp := w0.distance_to(w1)
		# Reto para fora e morro abaixo: na quina o canto do forro e diagonal, o
		# caibro nao.
		var desce := (fora - Vector3(0.0, c, 0.0)).normalized()
		var ate_ponta := fora * a - Vector3(0.0, a * c, 0.0)
		if bool(t.get("cachorrada", false)) and da_rua:
			# Caibro a caibro, presos na face de baixo da agua, da parede ate 3 cm da
			# ponta. Sao os cachorros do colonial.
			var n := maxi(1, int(comp / PASSO_CACHORRO))
			var base := Basis(ao_longo, -baixo, desce)
			var len_c := ate_ponta.length() - 0.03
			for k in n:
				var f := (float(k) + 0.5) / float(n)
				var na_parede := w0.lerp(w1, f)
				var meio := na_parede + desce * (len_c * 0.5) + baixo * 0.05
				ob.livre(JanelaViva._p(&"tabua"), meio, Vector3(0.07, 0.1, len_c), base,
					MADEIRA, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TOPO)
		elif fiadas > 0 and da_rua:
			# Beira-seveira: as fiadas de telha em argamassa caiada sob a ponta, cada
			# uma recuando 10 cm, que e o que fazia a casa ter "eira e beira". A
			# primeira fica 2 cm atras da testeira (no mesmo plano, piscaria).
			var cal: Color = plano.get("cercadura", Color("f4f0e6"))
			var meio_parede: Vector3 = (Vector3(l[0]) + Vector3(l[1])) * 0.5
			for k in fiadas:
				var frente_k := a - 0.02 - 0.1 * float(k)
				var y := y_b - 0.05 - 0.07 * float(k) - 0.035
				var meio: Vector3 = meio_parede + fora * (frente_k - 0.07) + Vector3(0.0, y, 0.0)
				var larg_k := comp + 0.02 * float(fiadas - k)
				ob.livre(JanelaViva._p(&"reboco"), meio, Vector3(larg_k, 0.07, 0.14),
					Basis(ao_longo, Vector3.UP, fora), cal.darkened(0.03 * float(k)))
				# A boca das telhas na testa da fiada, uma faixa de barro fina.
				ob.plano(JanelaViva._p(&"telha"), meio + fora * 0.075, Vector2(larg_k, 0.035),
					fora, ao_longo, Color(0.85, 0.72, 0.62))


# --- o que mora em cima ---------------------------------------------------------

## Chamine do fogao a lenha, antena pelo morador, caixa d'agua castelinho,
## aquecedor solar, remendo de telha nova, lona azul com pedra, mato na calha.
## So no miolo das aguas (longe do espigao da quina), para nada furar a beira.
static func _em_cima(ob: Obra, plano: Dictionary, t: Dictionary, q: Referencial,
		meia: float, fundo: float, a: float, c: float, y_w: float, esp_e: bool,
		esp_d: bool) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(t["semente"]) ^ 0x51c0
	var estilo: StringName = plano.get("estilo", &"popular")
	var morador: StringName = plano.get("morador", &"familia")
	var cor_corpo: Color = plano.get("cor_corpo", Color("d8d2c6"))
	# Faixa de x onde a agua e inteira (sem espigao).
	var x0 := -meia + (fundo * 0.5 + a if esp_e else 0.4)
	var x1 := meia - (fundo * 0.5 + a if esp_d else 0.4)
	if x1 - x0 < 1.2:
		return
	var y_cume := y_w + fundo * 0.5 * c + ESPESSURA + 0.05
	# Altura da telha (em cima da onda) no ponto `s` para dentro da fachada.
	var y_telha := func(s: float) -> float:
		var d := s if s <= fundo * 0.5 else fundo - s
		return y_w + d * c + ESPESSURA + 0.05
	var abandonada := morador == &"abandonada"
	var livre := [x0 + 0.3, x1 - 0.3]
	var usados: Array[float] = []
	var sortear_x := func(folga: float) -> float:
		for _tentativa in 6:
			var x := r.randf_range(float(livre[0]), float(livre[1]))
			var ok := true
			for u: float in usados:
				if absf(u - x) < folga:
					ok = false
			if ok:
				usados.append(x)
				return x
		return NAN

	# Chamine do fogao a lenha: na agua de tras, perto da cozinha.
	var chance_chamine := 0.4 if estilo == &"colonial" else 0.18
	if morador == &"idoso":
		chance_chamine += 0.2
	if r.randf() < chance_chamine:
		var x: float = sortear_x.call(1.2)
		if is_finite(x):
			var s := fundo - r.randf_range(0.9, 1.5)
			var pe: float = y_telha.call(s) - 0.35
			var topo := y_cume + r.randf_range(0.3, 0.65)
			var tijolo := r.randf() < 0.6
			var base := Basis(q.lateral, Vector3.UP, -q.dentro)
			ob.livre(&"tijolo" if tijolo else &"reboco", q.p(x, s, (pe + topo) * 0.5),
				Vector3(0.44, topo - pe, 0.44), base,
				Color.WHITE if tijolo else cor_corpo.darkened(0.1))
			# A boca preta de fuligem e o chapeu de concreto em dois calcos.
			ob.livre(&"concreto", q.p(x, s, topo + 0.005), Vector3(0.3, 0.01, 0.3), base,
				Color(0.12, 0.11, 0.1))
			for lado: float in [-1.0, 1.0]:
				ob.livre(&"tijolo", q.p(x + lado * 0.17, s, topo + 0.06), Vector3(0.1, 0.12, 0.3),
					base, Color.WHITE)
			ob.livre(&"concreto", q.p(x, s, topo + 0.14), Vector3(0.58, 0.05, 0.58), base,
				Color(0.62, 0.6, 0.56))

	# Antena: espinha-de-peixe no cano galvanizado (idoso, familia), mini
	# parabolica (jovem), parabolica de tela na casa grande.
	var sorte := r.randf()
	if not abandonada and sorte < 0.55:
		var x: float = sortear_x.call(1.0)
		if is_finite(x):
			var s := fundo * 0.5 + r.randf_range(-0.2, 0.2)
			var base := Basis(Vector3.UP, r.randf_range(0.0, PI))
			if morador == &"jovem" or sorte < 0.12:
				# Mini parabolica na parede da frente, num suporte em L abaixo do
				# beiral: e onde a TV por assinatura poe. Atras da cumeeira ela so
				# aparecia em cacos, cortada pelo telhado.
				var lado := -1.0 if r.randf() < 0.5 else 1.0
				var xp := lado * (meia - 0.55)
				var alto_p := y_w - a * c - 0.45
				var na_parede := q.p(xp, 0.0, alto_p)
				var fora := -q.dentro
				ob.caixa(&"metal", na_parede + fora * 0.2, Vector3(0.035, 0.035, 0.4), Color("6e6a62"),
					atan2(fora.x, fora.z))
				ob.caixa(&"metal", na_parede + fora * 0.38 + Vector3(0.0, 0.12, 0.0),
					Vector3(0.035, 0.26, 0.035), Color("6e6a62"))
				_prato(ob, na_parede + fora * 0.42 + Vector3(0.0, 0.34, 0.0), 0.3,
					fora + q.lateral * (lado * 0.3), Color("aeb2b6"))
			elif sorte < 0.2 and fundo > 6.0:
				# Parabolica de tela de 1,8 m na agua de tras, cinza de aluminio.
				var sp := fundo - 1.6
				var p: Vector3 = q.p(x, sp, y_telha.call(sp))
				for k in 3:
					var ang := TAU * float(k) / 3.0
					ob.caixa(&"metal", p + Vector3(cos(ang) * 0.35, 0.45, sin(ang) * 0.35),
						Vector3(0.04, 0.9, 0.04), Color("5a5a56"))
				_prato(ob, p + Vector3(0.0, 1.1, 0.0), 0.9, -q.dentro * 0.4 + q.lateral * 0.2,
					Color("8e918c"))
			else:
				# Espinha-de-peixe: mastro de 2,5 m saindo da cumeeira, gancheira e
				# as varetas.
				var p := q.p(x, s, y_cume)
				var alto := r.randf_range(1.8, 2.8)
				ob.caixa(&"metal", p + Vector3(0.0, alto * 0.5, 0.0), Vector3(0.035, alto, 0.035),
					Color("7a7872"))
				var comp := r.randf_range(1.0, 1.5)
				var giro := r.randf_range(0.0, PI)
				var eixo := Vector3(cos(giro), 0.0, sin(giro))
				var topo := p + Vector3(0.0, alto - 0.1, 0.0)
				ob.livre(&"metal", topo, Vector3(comp, 0.025, 0.025),
					Basis(eixo, Vector3.UP, eixo.cross(Vector3.UP)), Color("8a8882"))
				var n := 6
				for k in n:
					var f := float(k) / float(n - 1) - 0.5
					var larg := lerpf(0.9, 0.45, float(k) / float(n - 1))
					ob.livre(&"metal", topo + eixo * (f * comp), Vector3(0.018, 0.018, larg),
						Basis(eixo, Vector3.UP, eixo.cross(Vector3.UP)), Color("8a8882"))

	# Caixa d'agua castelinho: alvenaria furando a agua de tras junto da cumeeira.
	if not abandonada and (estilo == &"colonial" or estilo == &"moderno") and r.randf() < 0.22:
		var x: float = sortear_x.call(1.8)
		if is_finite(x):
			var s := fundo * 0.5 + 1.0
			var pe: float = y_telha.call(s) - 0.5
			var topo := y_cume + r.randf_range(0.6, 1.0)
			var base := Basis(q.lateral, Vector3.UP, -q.dentro)
			ob.livre(&"reboco", q.p(x, s, (pe + topo) * 0.5), Vector3(1.3, topo - pe, 1.2), base,
				cor_corpo)
			ob.livre(&"concreto", q.p(x, s, topo + 0.04), Vector3(1.46, 0.08, 1.36), base,
				Color(0.7, 0.68, 0.64))

	# Aquecedor solar na agua que olha mais para o norte (-Z): casa reformada.
	if not abandonada and estilo == &"moderno" and r.randf() < 0.25:
		var x: float = sortear_x.call(2.4)
		if is_finite(x):
			var frente_norte := (-q.dentro).dot(Vector3.FORWARD) >= 0.0
			var sai := -q.dentro if frente_norte else q.dentro
			var s := fundo * 0.25 if frente_norte else fundo * 0.75
			var sobe := (-sai + Vector3(0.0, c, 0.0)).normalized()
			var n := sai * c + Vector3.UP
			n = n.normalized()
			for k in 2:
				var xx := x + (float(k) - 0.5) * 1.05
				var p: Vector3 = q.p(xx, s, y_telha.call(s)) + n * 0.07
				ob.livre(&"metal_pintado", p, Vector3(1.0, 0.05, 1.9),
					Basis(q.lateral, n, q.lateral.cross(n)), Color(0.12, 0.14, 0.2))
			# O boiler deitado, acima dos coletores.
			var sb := s + (0.9 if frente_norte else -0.9)
			var pb: Vector3 = q.p(x, sb, y_telha.call(sb)) + Vector3(0.0, 0.35, 0.0)
			ob.livre(&"metal_pintado", pb, Vector3(1.5, 0.42, 0.42),
				Basis(q.lateral, Vector3.UP, -q.dentro), Color(0.82, 0.82, 0.8))

	# Casa pobre e abandonada: lona azul amarrada e pedra segurando telha.
	var pobre := abandonada or morador == &"fechada" or estilo == &"popular"
	if pobre and r.randf() < (0.6 if abandonada else 0.25):
		var x: float = sortear_x.call(1.6)
		if is_finite(x):
			var s := r.randf_range(0.8, fundo * 0.5 - 0.8)
			var n := (-q.dentro * c + Vector3.UP).normalized()
			var p: Vector3 = q.p(x, s, y_telha.call(s)) + n * 0.03
			ob.livre(JanelaViva._p(&"metal_pintado"), p, Vector3(r.randf_range(1.4, 2.2), 0.02,
				r.randf_range(1.2, 1.8)), Basis(q.lateral, n, q.lateral.cross(n)),
				Color("2f5fa8").darkened(r.randf() * 0.2))
			for k in 4:
				var pp: Vector3 = p + q.lateral * r.randf_range(-0.8, 0.8) \
					+ q.dentro * r.randf_range(-0.5, 0.5) + n * 0.06
				ob.caixa(JanelaViva._p(&"concreto"), pp, Vector3(0.2, 0.1, 0.14),
					Color(0.6, 0.58, 0.55), r.randf() * PI)
	if abandonada:
		# Mato na calha: tufo de capim e samambaia na beira da frente.
		var n := int((x1 - x0) / 0.9)
		for k in n:
			if r.randf() < 0.45:
				continue
			var x := lerpf(x0, x1, (float(k) + 0.5) / float(n))
			var p := q.p(x, -a + 0.1, y_w - a * c + 0.1 + ESPESSURA)
			var tt := Transform3D(Basis(Vector3.UP, r.randf() * PI), p + Vector3(0.0, 0.14, 0.0))
			ob.cartao(JanelaViva._p(&"flor"), Vector2(0.45, 0.32), tt,
				Carroceria.uv(Vector2i(4, 0)), Color(0.85, 1.0, 0.75), 1)


## Prato de antena: disco raso em leque, virado para `olhar`, com o braco do LNB.
static func _prato(ob: Obra, centro: Vector3, raio: float, olhar: Vector3, cor: Color) -> void:
	var n := (olhar.normalized() + Vector3.UP * 0.35).normalized()
	var u := n.cross(Vector3.UP).normalized()
	if u.length_squared() < 0.01:
		u = Vector3.RIGHT
	var v := u.cross(n).normalized()
	var pontos := PackedVector3Array()
	var tras := PackedVector3Array()
	const LADOS := 10
	for k in LADOS:
		var ang := TAU * float(k) / float(LADOS)
		var borda := centro + (u * cos(ang) + v * sin(ang)) * raio
		pontos.append(borda)
	var fundo := centro - n * (raio * 0.18)
	var m := ob.malha(&"metal_pintado")
	var ic := m.vertice(fundo, n, Vector2(0.5, 0.5), Vector2.ZERO, cor)
	var it := m.vertice(fundo, -n, Vector2(0.5, 0.5), Vector2.ZERO, cor.darkened(0.25))
	for k in LADOS:
		var a := pontos[k]
		var b := pontos[(k + 1) % LADOS]
		var ia := m.vertice(a, n, Vector2.ZERO, Vector2.ZERO, cor)
		var ib := m.vertice(b, n, Vector2.ZERO, Vector2.ZERO, cor)
		m.tri(ic, ia, ib, n)
		var ja := m.vertice(a, -n, Vector2.ZERO, Vector2.ZERO, cor.darkened(0.25))
		var jb := m.vertice(b, -n, Vector2.ZERO, Vector2.ZERO, cor.darkened(0.25))
		m.tri(it, jb, ja, -n)
	# O braco do LNB.
	var ponta := centro + n * (raio * 0.7)
	ob.livre(&"metal", (centro + ponta) * 0.5, Vector3(0.025, 0.025, raio * 0.7),
		Basis(u, v, n), Color("5a5a56"))
	ob.caixa(&"metal_pintado", ponta, Vector3(0.08, 0.08, 0.1), Color(0.3, 0.3, 0.3))


# --- escondido, meia-agua e laje coberta --------------------------------------

## Atras da platibanda: duas aguas da mureta da frente a de tras. A cumeeira passa
## da platibanda em quase toda casa (e o que se ve do outro lado da rua e do
## mirante), e dos lados a empena sobe acima dela.
static func _escondido(ob: Obra, plano: Dictionary, t: Dictionary, topo: Vector3,
		tamanho: Vector3, direcao: int) -> void:
	var qq := _quadro(topo, tamanho, direcao)
	var q: Referencial = qq[0]
	var larg: float = qq[1]
	var fundo: float = qq[2]
	var altura := topo.y
	var c := float(t["caimento"])
	var alto_mureta := 1.0 if plano.get("remate", &"") == &"platibanda" else 0.5
	var telha: Dictionary = TELHAS[t["telha"]]
	var mat: StringName = telha["material"]
	var tom: Color = t["tom"]
	var limo := float(t["limo"])
	var cor_corpo: Color = plano.get("cor_corpo", Color("d8d2c6"))
	# Da face de dentro da mureta (18 cm) da frente ate a de tras.
	var s0 := ChunkBuilder.AVANCO_FACHADA + 0.18
	var s1 := fundo - 0.18
	var dy := s1 - s0
	var y_cume := dy * 0.5
	var y_pe := altura + alto_mureta - 0.14
	var meia := larg * 0.5 - 0.02
	for lado: float in [1.0, -1.0]:
		var o := q.p(-meia * lado, s0 if lado > 0.0 else s1, y_pe - ESPESSURA)
		_agua(ob, mat, o, q.lateral * lado, q.dentro * lado, meia * 2.0, y_cume, false, false,
			c, [], 0.0, tom if lado > 0.0 else tom.darkened(0.06), limo,
			t["telha"] == &"fibrocimento")
	var y_capa := y_pe + y_cume * c + 0.05
	_capa(ob, mat, q.p(-meia, s0 + y_cume, y_capa), q.p(meia, s0 + y_cume, y_capa), q.dentro,
		c, tom, true, true)
	# A empena acima da mureta dos lados, recuada 2 cm da face de fora dela.
	var y_mureta := altura + alto_mureta
	var y_cume_baixo := y_pe - ESPESSURA + y_cume * c
	if y_cume_baixo <= y_mureta + 0.02:
		return
	var sobra := (y_cume_baixo - y_mureta) / c
	for s: float in [-1.0, 1.0]:
		var x := meia * s
		var pts := PackedVector3Array([q.p(x, s0 + y_cume - sobra, y_mureta),
			q.p(x, s0 + y_cume, y_cume_baixo), q.p(x, s0 + y_cume + sobra, y_mureta)])
		ob.leque(&"reboco", pts, q.lateral * s, q.dentro, q.p(x, 0.0, altura + 2.0),
			cor_corpo.lerp(Color("c9c1b2"), 0.2))
		for f: float in [-1.0, 1.0]:
			_capa_oitao(ob, q.p(x - s * 0.045, s0 + y_cume + f * sobra, y_mureta),
				q.p(x - s * 0.045, s0 + y_cume, y_cume_baixo), q.lateral,
				ARGAMASSA.lerp(cor_corpo, 0.3))


## Meia-agua de fibrocimento atras da platibanda: da frente, rente ao chapim, ate a
## mureta de tras. E o telhado da loja, visto de cima.
static func _meia_agua_escondida(ob: Obra, plano: Dictionary, t: Dictionary, topo: Vector3,
		tamanho: Vector3, direcao: int) -> void:
	var qq := _quadro(topo, tamanho, direcao)
	var q: Referencial = qq[0]
	var larg: float = qq[1]
	var fundo: float = qq[2]
	var altura := topo.y
	var alto_mureta := 1.0 if plano.get("remate", &"") == &"platibanda" else 0.5
	var s0 := ChunkBuilder.AVANCO_FACHADA + 0.18
	var s1 := fundo - 0.18
	var y_alto := altura + alto_mureta - 0.16
	var y_baixo := altura + 0.12
	var c := (y_alto - y_baixo) / maxf(s1 - s0, 0.5)
	var meia := larg * 0.5 - 0.18
	var tom := FIBRO.lerp(LIMO * FIBRO, float(t["limo"]) * 0.6)
	# A agua desce para o fundo: o beiral dela e o de tras.
	var o := q.p(meia, s1, y_baixo)
	_agua(ob, &"metal_ondulado", o, -q.lateral, -q.dentro, meia * 2.0, s1 - s0, false, false,
		c, [], 0.0, tom, 0.0, true)


## Laje da autoconstrucao coberta de fibrocimento: pilaretes de tijolo nas quinas e
## no meio, e a meia-agua caindo para o fundo, meio metro acima da laje.
static func _laje_coberta(ob: Obra, plano: Dictionary, t: Dictionary, topo: Vector3,
		tamanho: Vector3, direcao: int) -> void:
	var qq := _quadro(topo, tamanho, direcao)
	var q: Referencial = qq[0]
	var larg: float = qq[1]
	var fundo: float = qq[2]
	var altura := topo.y
	var r := RandomNumberGenerator.new()
	r.seed = int(t["semente"])
	var y_frente := altura + r.randf_range(1.35, 1.7)
	var y_tras := y_frente - fundo * 0.1
	var meia := larg * 0.5 - 0.15
	var s0 := ChunkBuilder.AVANCO_FACHADA + 0.12
	var s1 := fundo - 0.12
	# Pilaretes: tijolo cru, nas quinas e a cada ~3 m.
	var n := maxi(1, int(round(larg / 3.0)))
	for k in n + 1:
		var x := -meia + (meia * 2.0) * float(k) / float(n)
		for s: float in [s0, s1]:
			var y_top := lerpf(y_frente, y_tras, (s - s0) / (s1 - s0)) - 0.03
			var h := y_top - altura
			ob.livre(&"tijolo", q.p(x, s, altura + h * 0.5), Vector3(0.24, h, 0.24),
				Basis(q.lateral, Vector3.UP, -q.dentro), Color.WHITE)
	# A viga de madeira da frente e a de tras.
	for s: float in [s0, s1]:
		var y_v := lerpf(y_frente, y_tras, (s - s0) / (s1 - s0)) - 0.03
		ob.livre(&"tabua", q.p(0.0, s, y_v - 0.05), Vector3(meia * 2.0 + 0.24, 0.1, 0.1),
			Basis(q.lateral, Vector3.UP, -q.dentro), Color("5e4630"))
	var tom := FIBRO.darkened(r.randf_range(0.0, 0.2))
	if r.randf() < 0.35:
		tom = tom.lerp(Color("8f9a7a"), 0.35)
	var c := (y_frente - y_tras) / (s1 - s0)
	var sai := 0.3
	var o := q.p(meia + 0.2, s1 + sai, y_tras - sai * c - ESPESSURA)
	_agua(ob, &"metal_ondulado", o, -q.lateral, -q.dentro, meia * 2.0 + 0.4,
		s1 - s0 + sai * 2.0, false, false, c, [], 0.0, tom, 0.0, true)
	# A face de baixo da chapa, vista da rua: a mesma chapa, virada.
	var baixo_e := q.p(-meia - 0.2, s0 - sai, y_frente + sai * c - 0.01)
	var baixo_d := q.p(meia + 0.2, s0 - sai, y_frente + sai * c - 0.01)
	var fundo_e := q.p(-meia - 0.2, s1 + sai, y_tras - sai * c - 0.01)
	var fundo_d := q.p(meia + 0.2, s1 + sai, y_tras - sai * c - 0.01)
	ob.quadra(&"metal_ondulado", baixo_e, baixo_d, fundo_d, fundo_e,
		(Vector3.DOWN - q.dentro * c).normalized(), q.dentro, baixo_e, tom.darkened(0.25))

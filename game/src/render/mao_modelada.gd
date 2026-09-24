## A mao do motorista fechada em volta do aro do volante, modelada.
##
## Por que existe
## --------------
## A mao era uma caixa de 7,6 x 9,2 cm com quatro riscos de dedo pintados na
## celula do atlas, e o antebraco outra caixa. Na cena da estrada, a meio metro
## da lente, isso passava de raspao; no carro da cidade a camera fica no olho do
## suporte, vinte centimetros mais perto, e as duas caixas bege viraram o assunto
## do quadro. No MODERNO, com luz por pixel, cada face chapada ainda acendia
## inteira de uma vez e denunciava a caixa de longe.
##
## O que ha aqui
## -------------
## Palma, quatro dedos de tres falanges, polegar, punho e antebraco — de pele,
## ou de manga com a bainha do punho. Cada peca e um tubo de aneis: secoes em
## elipse (superelipse, na palma) costuradas em fila, com a normal suave somada
## das faces vizinhas. Nao ha desenho na textura: a UV aponta para um texel liso
## de pele (ou de pano) da celula do atlas, e o que conta que aquilo e uma mao e
## a FORMA e a cor de vertice — palma mais clara, no do dedo mais corado, unha
## mais clara.
##
## Como os dedos fecham
## --------------------
## A corrente de falanges e resolvida no plano da secao do tubo. Cada falange
## sai do no anterior TANGENTE a um circulo de raio "tubo + quase meio dedo", no
## sentido em que a mao fecha: e o que um dedo de verdade faz, encostar a polpa
## e dobrar no proximo no. As dobras saem sozinhas e saem na faixa da pegada de
## forca de mao de gente — ~45 graus no no da base, ~90 no do meio (a bancada
## imprime) — e continuam certas se o aro engrossar. Um angulo fixo por no so
## serviria para uma grossura de tubo.
##
## Como o no dobra
## ---------------
## Cada no e um ARCO, e nao uma quina: tres secoes girando em volta de um centro
## que fica do lado de dentro da dobra, a um raio de dedo da linha do osso. A
## primeira versao punha um anel antes, um na bissetriz e um depois, e com os 98
## graus do polegar os aneis de dentro se cruzavam — a prega virava uma lamina
## de triangulos do avesso espetando para fora da mao. No arco o lado de dentro
## fecha num ponto (a prega) e o de fora faz a curva do no.
##
## A mao e montada sobre um `Callable` que devolve o eixo do tubo num ponto dele
## (ver `segurando`), e nao sobre um cilindro reto: o aro da cabine e um
## poligono, e cada dedo pergunta onde o tubo esta no lugar DELE.
##
## Orcamento: ver `tests/bancada_maos.gd`, que conta as duas maos com as duas
## mangas contra o teto de 1500 triangulos por mao.
class_name MaoModelada
extends RefCounted

## Lados de cada secao. Oito no dedo e o menor numero que ainda le redondo a
## trinta centimetros da lente com luz por pixel: com seis a quina do contorno
## aparecia no dorso de cada falange.
## Doze, e nao oito: a um palmo da lente, em 4K, a silhueta de oito lados da
## ponta do dedo era um octogono que se via.
const LADOS_DEDO := 12
const LADOS_PALMA := 16
## O antebraco de pele usa `LADOS_PALMA`: ele nasce da palma e precisa da mesma
## volta de vertices para a costura do pulso nao serrilhar. A manga, que
## comeca solta, tem os seus.
const LADOS_MANGA := 12
## O raio que o alfa da cor de vertice guarda como 1 (ver `_tubo`).
const RAIO_NA_COR := 0.07

## Giro da mao em volta do tubo, em graus. Zero poe o dorso virado para FORA do
## aro e os dedos apontando para o painel; positivo gira o dorso para o
## motorista. Quem dirige com a mao no aro ve o DORSO dela — a fileira dos nos
## por cima do tubo e o polegar fechando por dentro.
##
## Era 35: do olho, que fica no meio do volante, o dorso da mao nas "nove"
## ficava de lado para a lente (a normal dele e a direcao do olho davam 0,07), e
## o que se via era a borda do polegar, uma luva lisa. Com 55 o dorso vira para
## o motorista (0,4) e os nos aparecem; com 70 o punho ja passava na frente da
## metade de baixo do aro.
const GIRO := 55.0

## Os quatro dedos, do indicador ao minimo, em metros.
##   `s`  onde o dedo fica ao longo do tubo, contado do meio da mao para o lado
##        do polegar. Dedo encostado no vizinho: numa mao fechada nao passa luz
##        entre eles;
##   `x`  quanto o no da base avanca (+) ou recua (-) no sentido dos dedos. O do
##        minimo fica quase um centimetro atras: e o arco dos nos de uma mao
##        fechada, e sem ele o punho le como luva de desenho animado;
##   `f`  as tres falanges, da base para a ponta (a ultima conta a ponta
##        redonda);
##   `r`  meia largura do dedo na base.
## Adulto: 19 cm do punho a ponta do medio (9,6 de palma e 9,8 de dedo) e 8,3
## cm de largura da palma nos nos.
const DEDOS := [
	{"s": 0.0305, "x": -0.002, "f": [0.044, 0.025, 0.020], "r": 0.0098},
	{"s": 0.0105, "x": 0.002, "f": [0.048, 0.029, 0.021], "r": 0.0100},
	{"s": -0.0092, "x": -0.001, "f": [0.044, 0.028, 0.020], "r": 0.0094},
	{"s": -0.0270, "x": -0.009, "f": [0.035, 0.021, 0.018], "r": 0.0083},
]
## Altura do no da base acima do eixo do tubo, alem do raio dele: e o que poe
## os nos uns tres milimetros acima do dorso da palma, como numa mao fechada.
const NO_DA_BASE := 0.0145
## Quanto a linha dos nos fica alem do eixo do tubo, no sentido dos dedos. O aro
## assenta na prega da palma, na base dos dedos, e nao embaixo dos nos: com os
## nos em cima do eixo (a primeira versao) o no da base dobrava so 40 graus e,
## vistos do dorso, os dedos saiam retos como os de uma luva vazia.
const AVANCO := 0.012
## Achatamento do dedo: a secao e mais larga que alta.
const DEDO_ACHATA := 0.86
## A unha (ver `_unha`): quanto da falange da ponta ela cobre, contado da ponta;
## onde a borda livre termina na meia esfera da ponta (fracao do raio); a meia
## largura (fracao do raio do dedo); quanto o meio sobe e a borda afunda na
## pele (m); e a grade dela.
const UNHA_COMP := 0.66
const UNHA_FIM := 0.62
const UNHA_LARGO := 0.72
const UNHA_ALTA := 0.00045
const UNHA_FUNDA := 0.0002
const UNHA_LADOS := 8
const UNHA_PASSOS := 6
## Quanto escurecem os lados de cada dedo, onde ele encosta no vizinho. E a
## sombra de contato que a luz do jogo nao faz (nao ha oclusao entre pecas da
## mesma malha), e sem ela os quatro dedos fechados liam como uma luva lisa na
## pele clara do jogador — a separacao entre eles sumia na primeira captura.
const FRESTA := 0.22
## Afinamento da base para a ponta, por junta.
const DEDO_AFINA := [1.0, 0.93, 0.87, 0.82]
## Quanto a ultima falange dobra ALEM da tangente. So a tangente deixava a
## ponta do dedo reta, apontando para fora do tubo; a falange da ponta de uma
## mao que segura dobra mais e enfia a unha na pegada. So dobra enquanto a ponta
## nao entra no tubo — o minimo, curto, entrava 2,5 mm.
const DOBRA_DA_PONTA := 30.0
## O circulo em que os dedos encostam: tubo mais esta fracao do meio dedo. Menos
## que um: a polpa aperta o aro, e um dedo que so tangencia fica com fresta de
## luz por baixo em toda quina.
const APERTO := 0.85

## O polegar. `POLEGAR_S` e o lugar dele ao longo do tubo: do lado do indicador,
## encostado nele, que e onde o polegar fecha num cabo. `POLEGAR_BASE` e a
## articulacao da base (s, x, altura sobre a face da palma), dentro da eminencia
## tenar, perto do punho. `POLEGAR_NO_GRAUS` e onde, em volta do tubo, fica o no
## do meio: 90 e o dorso, 180 e o lado do punho — o polegar desce pela face do
## aro que olha para o motorista e fecha por baixo, contra os dedos.
##
## Era 128: o no no alto do tubo obrigava a primeira falange a descer quase
## na vertical, e o no do meio dobrava 98 graus (a mao de gente dobra ali 50 a
## 60). Em 162 a dobra fica em ~50.
const POLEGAR_S := 0.043
const POLEGAR_BASE := Vector3(0.017, -0.075, 0.012)
## Meio diametro do metacarpo do polegar na base. Com a base a 2,4 cm do meio da
## palma e 1,5 de raio, o cone saia meio centimetro pela borda da mao e a boca
## aberta dele aparecia como um chifre branco na base do polegar.
const POLEGAR_TENAR := 0.0145
const POLEGAR_NO_GRAUS := 162.0
const POLEGAR_F := [0.032, 0.027]
const POLEGAR_R := 0.0106
## Quanto do caminho da base do polegar, na palma obliqua, o resto dele segue
## ao longo do tubo (ver `obliquar`).
const POLEGAR_SEGUE := 0.5
## O maior tubo em que o polegar fecha (ver `_polegar`).
const POLEGAR_TUBO_MAX := 0.05

## A palma, do punho aos nos: x (no sentido dos dedos, zero no no do medio),
## largura, espessura e o centro ao longo do tubo. Trapezio: 5,8 cm no punho,
## 8,3 nos nos; mais grossa no calcanhar da mao e fina na borda dos nos.
const PALMA := [
	[-0.096, 0.058, 0.028, -0.002],
	[-0.082, 0.064, 0.030, -0.001],
	[-0.060, 0.073, 0.029, 0.0],
	[-0.035, 0.080, 0.027, 0.001],
	[-0.012, 0.083, 0.025, 0.001],
	[0.004, 0.074, 0.019, 0.001],
]
## Superelipse da secao da palma: 2 seria elipse. Com 2,6 a palma lia como uma
## almofada quadrada vista do dorso; 2,3 ainda tem a quina da borda da mao.
const PALMA_N := 2.3

## O antebraco, do punho ao cotovelo: nunca passa disto, mesmo que o cotovelo
## esteja mais longe (ele sai do quadro antes).
const ANTEBRACO := 0.26
## O tubo continua reto este tanto depois do fim do antebraco, no lugar do
## braco de cima. Com o cotovelo a um antebraco da mao (e subindo junto com ela
## quando o volante gira) a ponta do braco entrava no quadro na guinada: um
## toco de manga cortado na borda da janela. Reto, ele sai do quadro antes de
## terminar; na posicao normal ele passa por baixo e por tras da lente.
const ALEM_DO_COTOVELO := 0.22
## O punho: meia largura e meia espessura. Estreito e achatado, e da mesma
## espessura do calcanhar da mao — um centimetro a mais e o antebraco comecava
## num degrau acima do dorso.
const PUNHO := Vector2(0.028, 0.0160)
## Raio da curva do pulso: o punho nao dobra em quina.
const PUNHO_CURVA := 0.03
## Secoes do antebraco de pele: distancia do punho, meia largura, meia
## espessura. A barriga do musculo fica a um terco do caminho.
const BRACO := [
	[0.06, 0.031, 0.023],
	[0.11, 0.034, 0.027],
	[0.17, 0.037, 0.030],
]
## A manga comprida: a bainha comeca a tres centimetros do punho e o pano fica
## folgado, um centimetro alem do braco em cada lado.
const MANGA_BAINHA := 0.030
const MANGA := [
	[0.07, 0.042, 0.036],
	[0.14, 0.045, 0.039],
	[0.20, 0.046, 0.041],
]


## Monta a mao que segura um tubo e junta em `dados`.
##
## `no_tubo(s)` devolve o eixo do tubo a `s` metros do meio da pegada, medidos
## ao longo dele: a origem no eixo, e a base com x para FORA (o lado onde ficam
## os nos dos dedos), y ao longo do tubo e z para o lado do punho (o motorista).
## A base tem de ser direita — x cruzado com y da z —, que e o que faz a ordem
## dos vertices sair do lado certo nas duas maos.
##
## `raio_tubo` e o raio em que a pegada encosta. `direita` diz qual mao: a
## direita tem o polegar para +y, a esquerda para -y. `cotovelo` e para onde o
## antebraco aponta, no mesmo espaco.
##
## Com `dados` de `PSXMesh.dados_com_ossos()` a malha sai com dois ossos: 0 e
## a mao, 1 e o antebraco, girando em volta do punho. O pulso e pesado entre os
## dois, para quem gira o osso 1 dobrar o pulso em vez de quebrar a malha.
## Devolve `punho` (onde o osso 1 gira) e `eixo` (para onde o antebraco aponta
## na montagem).
static func segurando(dados: Dictionary, no_tubo: Callable, raio_tubo: float,
		direita: bool, cotovelo: Vector3, pele: Color, manga: Color,
		manga_longa: bool, giro_graus: float = GIRO,
		obliquo_graus: float = 0.0) -> Dictionary:
	var com_ossos := dados.has("b")
	var m := PSXMesh.dados_com_ossos() if com_ossos else PSXMesh.dados_vazios()
	var sinal := 1.0 if direita else -1.0
	var giro := deg_to_rad(giro_graus)
	var uv_pele := _uv_liso(Aparencia.PECA_MAO, 0.14)
	var uv_pano := _uv_liso(Aparencia.PECA_MANGA, 0.30)
	var cores := _tons(pele)

	var q0 := _eixos(no_tubo.call(0.0), giro)
	var q := obliquar(q0, sinal, deg_to_rad(obliquo_graus))
	var lado_s: Vector3 = q["tubo"] * sinal
	# A face da palma encosta no tubo, apertando dois milimetros.
	var face := raio_tubo - 0.002

	_palma(m, q, lado_s, face, cores, uv_pele)
	var no_indicador := Vector3.ZERO
	for dedo: Dictionary in DEDOS:
		# O no da base e um ponto da PALMA (que pode estar obliqua ao tubo); o dedo
		# fecha no plano da secao do tubo que passa por ele.
		var base := _na_palma(q, lado_s, dedo["s"], dedo["x"], raio_tubo + NO_DA_BASE)
		var s_tubo := (base - (q0["o"] as Vector3)).dot(q0["tubo"])
		var qd := _eixos(no_tubo.call(s_tubo), giro)
		var rel := base - (qd["o"] as Vector3)
		var r: float = dedo["r"]
		var raios := []
		for f: float in DEDO_AFINA:
			raios.append(r * f)
		var juntas := _fechar(Vector2(rel.dot(qd["d"]), rel.dot(qd["dorso"])),
			dedo["f"], raio_tubo + r * APERTO, true, deg_to_rad(DOBRA_DA_PONTA),
			raio_tubo + float(raios[3]) * 0.8)
		var p3: Array[Vector3] = []
		var dorsos: Array[Vector3] = []
		for k in juntas.size():
			p3.append(_no_plano(qd, juntas[k]))
		for k in juntas.size() - 1:
			dorsos.append(_dir_plano(qd, _fora(juntas[k + 1] - juntas[k], true)))
		# O dedo entra pelo metacarpo, que corre no sentido da palma.
		_corrente(m, p3, dorsos, raios, cores, uv_pele, q["d"], q["dorso"])
		if no_indicador == Vector3.ZERO:
			no_indicador = p3[0]
	# Na palma obliqua a base do polegar vai com o calcanhar da mao para o lado
	# do minimo; o polegar acompanha metade, para o metacarpo nao esticar.
	var lado0: Vector3 = (q0["tubo"] as Vector3) * sinal
	var anda := (_na_palma(q, lado_s, POLEGAR_BASE.x, POLEGAR_BASE.y, face)
		- _na_palma(q0, lado0, POLEGAR_BASE.x, POLEGAR_BASE.y, face)).dot(q0["tubo"])
	var no_polegar := _polegar(m, q, lado_s, no_tubo, sinal, raio_tubo, face,
		giro, cores, uv_pele, anda * POLEGAR_SEGUE)
	_membrana(m, no_polegar, no_indicador, q, lado_s, cores, uv_pele)
	var braco := _antebraco(m, q, lado_s, face, cotovelo, manga, manga_longa,
		cores, uv_pele, uv_pano)

	PSXMesh.acumular(dados, m, Transform3D.IDENTITY)
	if com_ossos:
		# `acumular` nao conhece osso; o indice do osso nao muda com a juncao.
		var b: PackedInt32Array = dados["b"]
		var w: PackedFloat32Array = dados["w"]
		b.append_array(m["b"])
		w.append_array(m["w"])
		dados["b"] = b
		dados["w"] = w
	return braco


## O braco de cima, do `cotovelo` ao `ombro`, e junta em `dados`: o mesmo tubo
## de pano amarrotado (ou de pele) do antebraco, comecando tres centimetros
## antes do cotovelo para cobrir a boca da manga de `segurando`.
##
## Para quem mostra o braco inteiro: o motorista debrucado no banco do carona
## ve os proprios bracos saindo de baixo da lente, e uma caixa ali lia como
## caixa.
static func braco_de_cima(dados: Dictionary, cotovelo: Vector3, ombro: Vector3,
		pele: Color, manga: Color, manga_longa: bool) -> void:
	var eixo := ombro - cotovelo
	var comp := eixo.length()
	if comp < 0.01:
		return
	eixo /= comp
	var dorso := eixo.cross(Vector3.UP if absf(eixo.y) < 0.95 else Vector3.FORWARD)
	var cor := manga if manga_longa else _tons(pele)["punho"] as Color
	var uv := _uv_liso(Aparencia.PECA_MANGA, 0.30) if manga_longa \
		else _uv_liso(Aparencia.PECA_MAO, 0.14)
	var aneis := []
	for k in 5:
		var t := float(k) / 4.0
		var r := lerpf(0.046, 0.057, t)
		var anel := _anel_braco(cotovelo + eixo * lerpf(-0.03, comp, t), eixo,
			dorso.normalized(), r, r * 0.9, cor, 1.0)
		if manga_longa:
			anel["ruga"] = 0.035
			anel["fase"] = 1.7 * float(k)
		aneis.append(anel)
	var m := PSXMesh.dados_vazios()
	_tubo(m, aneis, LADOS_MANGA, uv, -1.0, 0.02)
	PSXMesh.acumular(dados, m, Transform3D.IDENTITY)


# --- pecas ------------------------------------------------------------------

## Palma: superelipse ao longo dos dedos, do calcanhar aos nos, fechada nas duas
## pontas. O dorso levemente abaulado (`bojo`) e a palma mais clara.
static func _palma(m: Dictionary, q: Dictionary, lado_s: Vector3, face: float,
		cores: Dictionary, uv: Vector2) -> void:
	var aneis := []
	for p: Array in PALMA:
		var esp: float = p[2]
		aneis.append({
			"c": _na_palma(q, lado_s, p[3], p[0], face + esp * 0.5),
			"a": q["d"], "v": q["dorso"],
			"ru": float(p[1]) * 0.5, "rv": esp * 0.5, "n": PALMA_N,
			"bojo": 0.2, "cor": cores["dorso"], "cor_palma": cores["palma"],
			# A borda da mao escurece um pouco: com a pele clara e a emissao do
			# material de gente, o dorso inteiro saia de um branco so e a mao
			# lia como luva.
			"fresta": 0.10,
		})
	_tubo(m, aneis, LADOS_PALMA, uv, 0.006, 0.004)


## O polegar: metacarpo grosso saindo de dentro da palma (e ele que faz a
## eminencia tenar), e duas falanges fechando pelo lado do punho, em sentido
## contrario ao dos dedos. Passa pela face do aro que olha para o motorista.
static func _polegar(m: Dictionary, q: Dictionary, lado_s: Vector3,
		no_tubo: Callable, sinal: float, raio_tubo: float, face: float,
		giro: float, cores: Dictionary, uv: Vector2, anda: float = 0.0) -> Vector3:
	var qp := _eixos(no_tubo.call(POLEGAR_S * sinal + anda), giro)
	var r := POLEGAR_R
	var ang := deg_to_rad(POLEGAR_NO_GRAUS)
	# Num tubo largo (a garra que chega por cima, com os dedos quase esticados)
	# o polegar nao da a volta nele: fecha num tubo proprio, pequeno, logo
	# embaixo da palma. Dando a volta no tubo de trinta centimetros ele descia
	# ate o chao como uma perna de pau.
	var rt := minf(raio_tubo, POLEGAR_TUBO_MAX)
	var sobe := Vector2(0.0, raio_tubo - rt)
	var no_meio := Vector2(cos(ang), sin(ang)) * (rt + r * APERTO + 0.004)
	var juntas := _fechar(no_meio, POLEGAR_F, rt + r * APERTO, false,
		deg_to_rad(DOBRA_DA_PONTA), rt + r * 0.88 * 0.8)
	for k in juntas.size():
		juntas[k] = (juntas[k] as Vector2) + sobe
	var base := _na_palma(q, lado_s, POLEGAR_BASE.x, POLEGAR_BASE.y,
		face + POLEGAR_BASE.z)
	var p3: Array[Vector3] = [base]
	for k in juntas.size():
		p3.append(_no_plano(qp, juntas[k]))
	var dorsos: Array[Vector3] = []
	# O metacarpo nao esta no plano da secao. O "dorso" dele e o da primeira
	# falange girado de volta pela dobra do no. Projetar direto nao serve: com a
	# falange descendo quase a 90 graus do metacarpo, o dorso dela fica paralelo
	# a ele, a projecao some, e o anel torcia sobre si mesmo — uma lamina branca
	# espetando da base do polegar.
	var dorso_f1 := _dir_plano(qp, _fora(juntas[1] - juntas[0], false))
	var meta := (p3[1] - p3[0]).normalized()
	var f1 := (p3[2] - p3[1]).normalized()
	var dobra_mp := meta.angle_to(f1)
	var dorso_meta := dorso_f1
	if dobra_mp > 0.001:
		dorso_meta = dorso_f1.rotated(meta.cross(f1).normalized(), -dobra_mp)
	dorsos.append(dorso_meta)
	for k in juntas.size() - 1:
		dorsos.append(_dir_plano(qp, _fora(juntas[k + 1] - juntas[k], false)))
	_corrente(m, p3, dorsos, [POLEGAR_TENAR, r * 1.04, r * 0.96, r * 0.88], cores, uv,
		Vector3.ZERO, Vector3.ZERO)
	return p3[1]


## A pele entre o polegar e o indicador.
##
## Sem ela, do olho do motorista, o vao entre o no do indicador (em cima do
## tubo) e o do polegar (na face de ca) abria uma fresta escura em forma de
## meia-lua na base do polegar — o aro aparecendo atraves da mao. E uma cinta
## chata do no do polegar ao do indicador, passando por cima do tubo: fina no
## sentido de quem olha o tubo de frente (`v` sai do eixo dele) e larga ao
## longo dele, que e como a pele da forquilha abraca um cabo. Um tubo redondo
## no lugar dela lia como um sexto dedo espetado.
static func _membrana(m: Dictionary, no_polegar: Vector3, no_indicador: Vector3,
		q: Dictionary, lado_s: Vector3, cores: Dictionary, uv: Vector2) -> void:
	var eixo := no_indicador - no_polegar
	if eixo.length() < 0.005:
		return
	var a := eixo.normalized()
	var o: Vector3 = q["o"]
	var aneis := []
	for t: float in [0.0, 0.5, 1.0]:
		var c := no_polegar + eixo * t
		var no_eixo := o + lado_s * (c - o).dot(lado_s)
		var fora := (c - no_eixo).normalized()
		var largo := 1.0 + 0.25 * sin(PI * t)
		aneis.append({"c": c, "a": a, "v": fora, "ru": 0.0105 * largo,
			"rv": 0.006, "cor": cores["dorso"], "cor_palma": cores["dorso"]})
	_tubo(m, aneis, LADOS_DEDO, uv, 0.003, 0.003)


## Antebraco do punho ao cotovelo.
##
## Ele COMECA como a palma: o primeiro anel fica dentro dela, dois milimetros
## menor, e o segundo por cima do calcanhar da mao, milimetro e meio maior, com
## a mesma superelipse. Dai o pulso dobra em arco ate o elipse do punho e o
## braco aponta para o cotovelo. A primeira versao comecava direto no elipse do
## punho: um tubo redondo enfiado numa almofada chata, e a borda das duas
## pecas fazia um serrote na silhueta do pulso.
##
## Com manga comprida a pele vai so ate dentro da bainha, e a manga e um tubo
## de pano folgado com a boca virada para a mao: a borda de dentro e escura,
## que e a sombra do punho dentro do pano.
static func _antebraco(m: Dictionary, q: Dictionary, lado_s: Vector3,
		face: float, cotovelo: Vector3, manga: Color,
		manga_longa: bool, cores: Dictionary, uv_pele: Vector2,
		uv_pano: Vector2) -> Dictionary:
	var calc: Array = PALMA[0]
	var dentro: Array = PALMA[1]
	var volta: Vector3 = -(q["d"] as Vector3)
	var tom_braco: Color = cores["punho"]
	var meio_calc := face + float(calc[2]) * 0.5
	# O pulso dobra um centimetro e meio alem do calcanhar da mao.
	var punho := _na_palma(q, lado_s, calc[3], float(calc[0]) - 0.014, meio_calc)
	var alvo := cotovelo - punho
	var eixo := alvo.normalized() if alvo.length() > 0.001 else volta

	# O "dorso" dos aneis de pele e o da palma, girando com o pulso: com o
	# mesmo numero de lados e o mesmo dorso, os vertices do antebraco caem na
	# mesma volta dos da palma, e a costura entre os dois e um anel liso. Com a
	# base de cada peca tirada de um eixo diferente (a primeira versao), as duas
	# voltas se cruzavam em ziguezague no pulso.
	var dorso: Vector3 = q["dorso"]
	var a_dentro := _anel_braco(_na_palma(q, lado_s, dentro[3], dentro[0],
		face + float(dentro[2]) * 0.5), volta, dorso,
		float(dentro[1]) * 0.5 - 0.002, float(dentro[2]) * 0.5 - 0.002, tom_braco)
	var a_calc := _anel_braco(_na_palma(q, lado_s, calc[3], calc[0], meio_calc),
		volta, dorso, float(calc[1]) * 0.5 + 0.0015,
		float(calc[2]) * 0.5 + 0.0015, tom_braco)
	for de_palma: Dictionary in [a_dentro, a_calc]:
		de_palma["n"] = PALMA_N
		de_palma["bojo"] = 0.2
	var aneis := [a_dentro, a_calc]
	var curva := _arco(punho, volta, eixo, PUNHO_CURVA, 0.012, 0.05, 3)
	var inicio: Vector3 = curva[curva.size() - 1]["c"]
	var dorso_braco := dorso
	for i in curva.size():
		var c: Dictionary = curva[i]
		var t := float(i + 1) / float(curva.size())
		var giro_c: float = c["giro"]
		dorso_braco = dorso.rotated(c["k"], giro_c) if giro_c != 0.0 else dorso
		var anel := _anel_braco(c["c"], c["a"], dorso_braco,
			lerpf(float(a_calc["ru"]), PUNHO.x, t), lerpf(float(a_calc["rv"]), PUNHO.y, t),
			tom_braco)
		anel["n"] = lerpf(PALMA_N, 2.0, t)
		anel["bojo"] = lerpf(0.2, 0.0, t)
		# O pulso passa da mao para o antebraco ao longo da curva.
		anel["osso"] = 0.15 + 0.325 * float(i)
		aneis.append(anel)
	var ossos := {"punho": punho, "eixo": eixo}
	# O braco segue do fim da curva; `comp` conta do punho, como as tabelas.
	var comp := clampf(alvo.length(), 0.10, ANTEBRACO)
	var ja := inicio.distance_to(punho)
	var trecho := func(d: float) -> Vector3:
		return inicio + eixo * maxf(d - ja, 0.004)

	if manga_longa:
		aneis.append(_anel_braco(trecho.call(0.06), eixo, dorso_braco, 0.031, 0.022,
			tom_braco, 1.0))
		_tubo(m, aneis, LADOS_PALMA, uv_pele, -1.0, 0.01)

		var sombra := manga.darkened(0.55)
		# A boca da manga: a borda de dentro (escura), a de fora, e um anel
		# quatro milimetros adiante que faz a bainha dobrada. Sem ele a normal da
		# borda era a media da boca com a do cano, e a bainha lia como um corte.
		# O pano segue o dorso do braco: o lado de baixo (`cor_palma`) escurece
		# nas duas maos, e nao em cima numa e embaixo na outra.
		var v_pano := dorso_braco
		var pano := [
			_anel_braco(trecho.call(MANGA_BAINHA + 0.012), eixo, v_pano,
				0.0325, 0.0245, sombra, 1.0),
			_anel_braco(trecho.call(MANGA_BAINHA), eixo, v_pano, 0.039, 0.032,
				manga, 1.0),
			_anel_braco(trecho.call(MANGA_BAINHA + 0.004), eixo, v_pano, 0.0395,
				0.0325, manga, 1.0),
		]
		var k := 0
		for s: Array in MANGA:
			var a := _anel_braco(trecho.call(minf(float(s[0]), comp)), eixo,
				v_pano, s[1], s[2], manga, 1.0)
			# Pano amarrotado: tres dobras em volta, girando de uma secao para a
			# outra, mais fundas perto do punho, onde a manga embola.
			a["ruga"] = 0.05 - 0.01 * float(k)
			a["fase"] = 1.9 * float(k)
			pano.append(a)
			k += 1
		pano.append(_anel_braco(trecho.call(comp), eixo, v_pano, 0.045, 0.041,
			manga, 1.0))
		pano.append(_anel_braco(trecho.call(comp + ALEM_DO_COTOVELO), eixo, v_pano,
			0.047, 0.043, manga, 1.0))
		_tubo(m, pano, LADOS_MANGA, uv_pano, -1.0, 0.02)
		return ossos

	for s: Array in BRACO:
		aneis.append(_anel_braco(trecho.call(minf(float(s[0]), comp)), eixo,
			dorso_braco, s[1], s[2], tom_braco, 1.0))
	aneis.append(_anel_braco(trecho.call(comp), eixo, dorso_braco, 0.036, 0.031,
		tom_braco, 1.0))
	aneis.append(_anel_braco(trecho.call(comp + ALEM_DO_COTOVELO), eixo, dorso_braco,
		0.040, 0.035, tom_braco, 1.0))
	_tubo(m, aneis, LADOS_PALMA, uv_pele, -1.0, 0.02)
	return ossos


## Secao do antebraco. `v` e o lado do "dorso" da secao; a largura (`ru`) fica
## na perpendicular a ele — do lado do polegar para o do minimo, como a do
## punho de verdade.
static func _anel_braco(c: Vector3, a: Vector3, v: Vector3, ru: float,
		rv: float, cor: Color, osso: float = 0.0) -> Dictionary:
	# O lado de baixo do braco um pouco mais escuro: e o volume que a luz de
	# cima da cabine daria e a emissao do material apaga.
	return {"c": c, "a": a, "v": v, "ru": ru, "rv": rv, "cor": cor,
		"cor_palma": cor.darkened(0.12), "osso": osso}


## Um dedo (ou o polegar) a partir das juntas: base, nos em arco, ponta.
##
## `entrada`/`dorso_entrada`: o sentido e o dorso do osso que chega na primeira
## junta (o metacarpo, para os dedos). Com eles o no da base tambem e um arco, e
## o dedo sai da palma como o calombo do no; sem eles (o polegar, que nasce
## dentro da palma) a corrente comeca reta.
##
## O anel do meio de cada arco cresce para o dorso (o osso aparecendo na pele
## esticada) e leva a cor do no. A ponta e meia esfera, e a unha e uma casca
## propria por cima dela (`_unha`).
static func _corrente(m: Dictionary, juntas: Array[Vector3],
		dorsos: Array[Vector3], raios: Array, cores: Dictionary, uv: Vector2,
		entrada: Vector3, dorso_entrada: Vector3) -> void:
	var n := juntas.size() - 1
	var dirs: Array[Vector3] = []
	var comps: Array[float] = []
	for k in n:
		dirs.append((juntas[k + 1] - juntas[k]).normalized())
		comps.append(juntas[k].distance_to(juntas[k + 1]))
	var aneis := []
	var r0: float = raios[0]
	if entrada != Vector3.ZERO:
		# Um anel dentro da palma, no sentido do metacarpo, e o arco do no. Ele
		# fecha (ver a tampa no fim): o indicador fica na borda da palma, que ali
		# e mais estreita que a fileira dos nos, e visto do lado do polegar a boca
		# aberta do tubo aparecia como um toco cortado com uma lasca na silhueta.
		aneis.append(_anel_dedo(juntas[0] - entrada * 0.014, entrada,
			dorso_entrada, r0 * 0.96, cores["dorso"], cores))
		# O no da base nao cresce com a dobra: ele ja sai da palma acima do
		# dorso, e com o calombo da dobra somado a fileira dos nos virava quatro
		# chifres pontudos na borda da mao.
		_arco_do_no(aneis, juntas[0], entrada, dirs[0], dorso_entrada, r0,
			0.014, comps[0] * 0.4, cores, 0.05, 0.0)
	else:
		aneis.append(_anel_dedo(juntas[0], dirs[0], dorsos[0], r0, cores["dorso"],
			cores))
		var meio := _anel_dedo(juntas[0] + dirs[0] * comps[0] * 0.45, dirs[0],
			dorsos[0], lerpf(r0, float(raios[1]), 0.35), cores["dorso"], cores)
		aneis.append(meio)
	for k in range(1, n):
		var folga_fim := comps[k] * (0.4 if k < n - 1 else 0.3)
		_arco_do_no(aneis, juntas[k], dirs[k - 1], dirs[k], dorsos[k - 1],
			float(raios[k]), comps[k - 1] * 0.4, folga_fim, cores, 0.08)
	# A ponta: meia esfera depois do ultimo arco.
	var rp: float = raios[n]
	var d_fim := dirs[n - 1]
	var v_fim := dorsos[n - 1]
	var centro := juntas[n] - d_fim * rp
	aneis.append(_anel_dedo(centro, d_fim, v_fim, rp, cores["dorso"], cores))
	# A meia esfera em tres aneis (a 25, 45 e 62 graus do fim) e nao num so: com
	# um anel so a ponta era um cone truncado, e de perto a quina aparecia.
	for q: Vector2 in [Vector2(0.42, 0.907), Vector2(0.71, 0.70), Vector2(0.88, 0.47)]:
		aneis.append(_anel_dedo(centro + d_fim * rp * q.x, d_fim, v_fim, rp * q.y,
			cores["dorso"], cores))
	# A base do dedo fica enterrada na palma e pode ficar aberta; a do polegar
	# e a eminencia tenar, que encosta na borda da palma, e fecha.
	_tubo(m, aneis, LADOS_DEDO, uv, r0 * (0.5 if entrada == Vector3.ZERO else 0.6),
		rp * 0.12)
	_unha(m, centro, d_fim, v_fim, rp, float(raios[n - 1]), comps[n - 1],
		cores["dorso"], uv)


## A unha: uma casca fina assentada no dorso da falange da ponta, da cuticula
## ate um pouco antes da ponta, curva como o dedo em baixo dela.
##
## Antes a unha era so a cor de vertice do dorso da ponta, um tom mais claro, e
## a mao no volante e no celular lia como mao sem unha. Aqui ela tem volume (a
## borda afunda na pele, o meio fica meio milimetro acima) e o shader da pele
## (`BracoVivo`) a reconhece pela UV2 (x >= 2: a fracao da largura, e y a do
## comprimento, 0 na cuticula) e pinta leito, lunula e borda livre, com o
## brilho da queratina.
static func _unha(m: Dictionary, centro: Vector3, a: Vector3, v: Vector3,
		rp: float, r_no: float, comp: float, cor: Color, uv: Vector2) -> void:
	var u := v.cross(a).normalized()
	var w := a.cross(u)
	var z0 := rp - comp * UNHA_COMP
	var z1 := rp * UNHA_FIM
	var largo := rp * UNHA_LARGO
	var verts: PackedVector3Array = m["v"]
	var nrm: PackedVector3Array = m["n"]
	var uvs: PackedVector2Array = m["uv"]
	var uv2: PackedVector2Array = m.get("uv2", PackedVector2Array())
	var cores: PackedColorArray = m["c"]
	var idx: PackedInt32Array = m["i"]
	var com_ossos := m.has("b")
	var ossos: PackedInt32Array = m.get("b", PackedInt32Array())
	var pesos: PackedFloat32Array = m.get("w", PackedFloat32Array())
	if uv2.size() != verts.size():
		uv2.resize(verts.size())
	var c := cor
	c.a = 0.0
	var base := verts.size()
	var colunas := UNHA_LADOS + 1
	# Uma fileira a mais no fim: a espessura da borda livre, descendo ate a pele.
	for k in UNHA_PASSOS + 2:
		var t := minf(float(k) / float(UNHA_PASSOS), 1.0)
		for j in colunas:
			var sg := -1.0 + 2.0 * float(j) / float(UNHA_LADOS)
			# A cuticula e um U (os cantos comecam mais para a ponta) e a borda
			# livre e um arco para fora.
			var z := lerpf(z0 + rp * 0.30 * sg * sg, z1 - rp * 0.22 * sg * sg, t)
			var x := sg * largo
			var afunda := maxf(smoothstep(0.7, 1.0, absf(sg)),
				1.0 - smoothstep(0.0, 0.2, t))
			var alto := lerpf(UNHA_ALTA, -UNHA_FUNDA, afunda)
			if k > UNHA_PASSOS:
				z += 0.0002
				alto = -UNHA_FUNDA - 0.0001
			var p := _na_ponta(centro, a, u, w, rp, r_no, comp, z, x)
			var tz := _na_ponta(centro, a, u, w, rp, r_no, comp, z + 0.0003, x) 				- _na_ponta(centro, a, u, w, rp, r_no, comp, z - 0.0003, x)
			var tx := _na_ponta(centro, a, u, w, rp, r_no, comp, z, x + 0.0003) 				- _na_ponta(centro, a, u, w, rp, r_no, comp, z, x - 0.0003)
			var nn := tz.cross(tx).normalized()
			if nn.dot(p - (centro + a * z)) < 0.0:
				nn = -nn
			verts.append(p + nn * alto)
			nrm.append(nn)
			uvs.append(uv)
			uv2.append(Vector2(2.0 + (sg + 1.0) * 0.5, t))
			cores.append(c)
			if com_ossos:
				ossos.append_array([0, 1, 0, 0])
				pesos.append_array([1.0, 0.0, 0.0, 0.0])
	# A face aparece do lado oposto ao produto vetorial (ver `_tubo`).
	for k in UNHA_PASSOS + 1:
		for j in UNHA_LADOS:
			var p00 := base + k * colunas + j
			var p01 := p00 + 1
			var p10 := p00 + colunas
			var p11 := p10 + 1
			for tri: Array in [[p00, p10, p01], [p01, p10, p11]]:
				var i0: int = tri[0]
				var i1: int = tri[1]
				var i2: int = tri[2]
				var fn := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
				if fn.dot(nrm[i0] + nrm[i1] + nrm[i2]) > 0.0:
					idx.append_array([i0, i2, i1])
				else:
					idx.append_array([i0, i1, i2])
	m["v"] = verts
	m["n"] = nrm
	m["uv"] = uvs
	m["uv2"] = uv2
	m["c"] = cores
	m["i"] = idx
	if com_ossos:
		m["b"] = ossos
		m["w"] = pesos


## Um ponto da pele do dorso da ponta do dedo: `z` ao longo do dedo contado do
## centro da meia esfera da ponta, `x` de lado. Na falange o raio vai do da
## ponta ao do no; na meia esfera, fecha como ela (ver `_corrente`).
static func _na_ponta(centro: Vector3, a: Vector3, u: Vector3, w: Vector3,
		rp: float, r_no: float, comp: float, z: float, x: float) -> Vector3:
	var rx: float
	if z >= 0.0:
		rx = rp * sqrt(maxf(0.0, 1.0 - (z / rp) * (z / rp)))
	else:
		rx = lerpf(rp, r_no * 0.97, clampf(-z / maxf(comp - rp, 0.001), 0.0, 1.0))
	rx = maxf(rx, 0.0005)
	var xx := clampf(x, -rx * 0.97, rx * 0.97)
	var y := rx * DEDO_ACHATA * sqrt(1.0 - (xx / rx) * (xx / rx))
	return centro + a * z + u * xx + w * y


## Os tres aneis do arco de um no. `bojo_base` e o calombo do osso no anel do
## meio; ele cresce `cresce` por radiano de dobra, porque a pele estica por
## cima da quina.
static func _arco_do_no(aneis: Array, junta: Vector3, a0: Vector3, a1: Vector3,
		v0: Vector3, r: float, folga0: float, folga1: float, cores: Dictionary,
		bojo_base: float, cresce: float = 0.15) -> void:
	# O centro da curva fica a quase um raio de dedo da linha do osso: o lado de
	# dentro fecha ate a prega e nunca cruza o anel vizinho.
	var curva := _arco(junta, a0, a1, r * 0.95, folga0, folga1, 3)
	var beta := a0.angle_to(a1)
	for i in curva.size():
		var c: Dictionary = curva[i]
		var giro: float = c["giro"]
		var v: Vector3 = v0.rotated(c["k"], giro) if giro != 0.0 else v0
		var meio := i == 1 or curva.size() == 1
		var anel := _anel_dedo(c["c"], c["a"], v, r * (1.0 if meio else 0.97),
			cores["no"] if meio else cores["dorso"], cores)
		if meio:
			anel["bojo"] = minf(bojo_base + cresce * beta, 0.35)
			anel["vinco"] = 0.10
		aneis.append(anel)


static func _anel_dedo(c: Vector3, a: Vector3, v: Vector3, r: float, cor: Color,
		cores: Dictionary) -> Dictionary:
	return {"c": c, "a": a, "v": v, "ru": r, "rv": r * DEDO_ACHATA, "cor": cor,
		"cor_palma": cores["palma"], "cor_unha": cores["unha"], "fresta": FRESTA}


## Amostras do arco que arredonda a quina `junta` entre os sentidos `a0` e `a1`:
## `n` pontos, cada um com centro `c`, sentido `a`, e o giro (`k`, `giro`) que
## leva `a0` ate ali — quem monta o anel gira o proprio "dorso" com ele.
##
## `raio` e o raio da curva; ele encolhe se a curva nao couber nas `folga0`/
## `folga1` que as pecas vizinhas deixam. Dobra quase nula devolve um ponto so.
static func _arco(junta: Vector3, a0: Vector3, a1: Vector3, raio: float,
		folga0: float, folga1: float, n: int) -> Array:
	var beta := a0.angle_to(a1)
	if beta < deg_to_rad(4.0):
		return [{"c": junta, "a": (a0 + a1).normalized(), "k": Vector3.UP,
			"giro": 0.0}]
	var k := a0.cross(a1).normalized()
	var tg := tan(beta * 0.5)
	var recuo := minf(raio * tg, minf(folga0, folga1))
	var r_eff := recuo / tg
	var t0 := junta - a0 * recuo
	var dentro := (a1 - a0 * a0.dot(a1)).normalized()
	var centro := t0 + dentro * r_eff
	var saida := []
	for i in n:
		var t := float(i) / float(n - 1)
		saida.append({"c": centro + (t0 - centro).rotated(k, beta * t),
			"a": a0.rotated(k, beta * t), "k": k, "giro": beta * t})
	return saida


# --- corrente de falanges ---------------------------------------------------

## Fecha uma corrente de falanges em volta de um circulo de raio `c` centrado na
## origem do plano da secao. `horario`: do dorso (+y) para a frente (+x) e dai
## para a palma, que e o sentido dos dedos; o polegar fecha ao contrario.
##
## Cada falange sai tangente ao circulo. A ultima dobra ate `extra` alem da
## tangente, enquanto a ponta ficar a `c_ponta` do eixo ou mais.
static func _fechar(inicio: Vector2, falanges: Array, c: float, horario: bool,
		extra: float, c_ponta: float) -> PackedVector2Array:
	var pts := PackedVector2Array([inicio])
	var p := inicio
	for k in falanges.size():
		var dist := p.length()
		var ang := p.angle()
		var comp: float = falanges[k]
		var dir: Vector2
		if dist <= c + 0.0005:
			dir = Vector2(sin(ang), -cos(ang)) if horario \
				else Vector2(-sin(ang), cos(ang))
		else:
			var abre := acos(c / dist)
			var ang_t := ang - abre if horario else ang + abre
			dir = (Vector2(cos(ang_t), sin(ang_t)) * c - p).normalized()
		if k == falanges.size() - 1:
			var e := extra
			for _tentativa in 5:
				var d2 := dir.rotated(-e if horario else e)
				if (p + d2 * comp).length() >= c_ponta:
					dir = d2
					break
				e *= 0.5
		p += dir * comp
		pts.append(p)
	return pts


## O lado de fora (o dorso) de uma falange que anda em `dir` em volta do tubo.
static func _fora(dir: Vector2, horario: bool) -> Vector2:
	var d := dir.normalized()
	return Vector2(-d.y, d.x) if horario else Vector2(d.y, -d.x)


# --- bases ------------------------------------------------------------------

## Os eixos da pegada num ponto do tubo, com o giro da mao aplicado: `d` e o
## sentido dos dedos (do punho para os nos), `dorso` o lado do dorso, `tubo` ao
## longo do tubo, `o` o eixo.
static func _eixos(t: Transform3D, giro: float) -> Dictionary:
	var fora := t.basis.x.normalized()
	var tubo := t.basis.y.normalized()
	var perto := t.basis.z.normalized()
	return {
		"o": t.origin,
		"d": fora * sin(giro) - perto * cos(giro),
		"dorso": fora * cos(giro) + perto * sin(giro),
		"tubo": tubo,
	}


## A palma obliqua ao tubo: `d` (punho para os nos) e o tubo giram juntos em
## volta do dorso, `angulo` radianos, o punho indo para o lado do minimo.
##
## O aro nao cruza a palma de quem dirige em angulo reto: ele corre da base do
## indicador ao calcanhar da mao do lado do minimo, e e isso que deixa o pulso
## reto com o cotovelo embaixo e atras da mao. Com o tubo sempre de traves o
## antebraco que ia para o cotovelo saia de lado da mao, dobrado num gancho.
## Os dedos continuam fechando em volta do tubo, cada um no seu lugar dele.
##
## O giro e em volta do no do INDICADOR, que e onde o cabo apoia: girando em
## volta do eixo do tubo, o no do indicador avancava um centimetro em volta do
## aro, a primeira falange descia quase de ponta e o arco do no dobrava sobre
## si mesmo num espinho na silhueta.
static func obliquar(q: Dictionary, sinal: float, angulo: float) -> Dictionary:
	if absf(angulo) < 1e-5:
		return q
	var d: Vector3 = q["d"]
	var lado: Vector3 = (q["tubo"] as Vector3) * sinal
	var d2 := d * cos(angulo) + lado * sin(angulo)
	var lado2 := lado * cos(angulo) - d * sin(angulo)
	var indicador: Dictionary = DEDOS[0]
	var xi := float(indicador["x"]) + AVANCO
	var si: float = indicador["s"]
	var apoio := (q["o"] as Vector3) + d * xi + lado * si
	return {"o": apoio - d2 * xi - lado2 * si, "d": d2, "dorso": q["dorso"],
		"tubo": lado2 * sinal}


## Um ponto do plano da secao (x no sentido dos dedos, y para o dorso).
static func _no_plano(q: Dictionary, p: Vector2) -> Vector3:
	return (q["o"] as Vector3) + (q["d"] as Vector3) * p.x \
		+ (q["dorso"] as Vector3) * p.y


static func _dir_plano(q: Dictionary, d: Vector2) -> Vector3:
	return ((q["d"] as Vector3) * d.x + (q["dorso"] as Vector3) * d.y).normalized()


## Um ponto da palma: `s` ao longo do tubo (para o polegar), `x` no sentido dos
## dedos contado da linha dos nos (`AVANCO` alem do eixo), `y` para o dorso.
static func _na_palma(q: Dictionary, lado_s: Vector3, s: float, x: float,
		y: float) -> Vector3:
	return (q["o"] as Vector3) + lado_s * s + (q["d"] as Vector3) * (x + AVANCO) \
		+ (q["dorso"] as Vector3) * y


# --- cor e UV ---------------------------------------------------------------

## Os tons da mao a partir da pele da ficha. Todos pequenos: a pele e um TINT
## sobre a celula quase branca do atlas, e a diferenca que aparece e a de uma
## mao de verdade — palma mais clara e rosada, no do dedo mais corado, unha
## clara —, nao a de uma mao pintada.
static func _tons(pele: Color) -> Dictionary:
	return {
		"dorso": pele,
		"palma": pele.lerp(Color(1.0, 0.86, 0.80), 0.22),
		"no": Color(pele.r * 0.96, pele.g * 0.89, pele.b * 0.87),
		"unha": pele.lerp(Color(1.0, 0.91, 0.88), 0.45),
		"punho": Color(pele.r * 0.97, pele.g * 0.95, pele.b * 0.94),
	}


## Um texel LISO da celula dada: a celula da mao tem riscos de dedo desenhados
## no terco de baixo, que numa mao modelada viriam listras soltas pela pele.
## `v` e a altura dentro da celula (0 em cima).
static func _uv_liso(coluna: int, v: float) -> Vector2:
	var cel := Aparencia.uv_da_celula(coluna, Aparencia.LINHA_PECAS)
	return cel.position + Vector2(0.5, v) * cel.size


# --- malha ------------------------------------------------------------------

## Costura uma fila de aneis num tubo, com normal suave.
##
## Cada anel: `c` centro, `a` sentido do tubo, `v` o lado do "dorso" (so a
## direcao; e ortogonalizada contra `a`), `ru`/`rv` os meios eixos da secao
## (largura e espessura), e opcionais `n` (expoente da superelipse), `bojo`
## (quanto o dorso cresce), `vinco` (quanto a palma encolhe), `ruga`/`fase`
## (pano amarrotado), `cor`, `cor_palma`, `unha`/`cor_unha`, `fresta` (quanto
## escurecem os dois lados da largura), `osso` (peso do osso 1, o antebraco,
## quando a malha tem esqueleto).
##
## `tampa_ini`/`tampa_fim`: distancia do polo que fecha a ponta, ao longo de
## `a`; negativo deixa aberto (a ponta que fica enterrada em outra peca).
##
## A ordem dos vertices segue a regra do projeto — a face aparece do lado
## OPOSTO ao produto vetorial da volta (ver `CarroceriaVarrida.quad`): o anel
## gira de `u` para `v` em torno de `a`, e o triangulo (anel k, anel k+1, anel k
## vizinho) tem o produto para DENTRO. A normal somada e o oposto dele.
static func _tubo(m: Dictionary, aneis: Array, lados: int, uv: Vector2,
		tampa_ini: float, tampa_fim: float) -> void:
	var v: PackedVector3Array = m["v"]
	var nrm: PackedVector3Array = m["n"]
	var uvs: PackedVector2Array = m["uv"]
	var uv2: PackedVector2Array = m.get("uv2", PackedVector2Array())
	var cor: PackedColorArray = m["c"]
	var idx: PackedInt32Array = m["i"]
	var com_ossos := m.has("b")
	var ossos: PackedInt32Array = m.get("b", PackedInt32Array())
	var pesos: PackedFloat32Array = m.get("w", PackedFloat32Array())
	var base := v.size()
	if uv2.size() != base:
		uv2.resize(base)
	# A pele do shader de primeira pessoa (`BracoVivo`) precisa de coordenada
	# PRESA a pele, e nao ao espaco: a malha e refeita a cada quadro enquanto a
	# mao anda, e um ruido no espaco escorreria pela mao. Cada volta tem um
	# vertice a mais (a costura repetida, com u = 1), UV2 leva (volta, metros ao
	# longo do tubo) e o alfa da cor leva o raio local — o shader monta dai um
	# ponto 3D sem costura (cos, sin, comprimento) em metros. Quem usa o
	# material do povo de caixa ignora os dois.
	var lv := lados + 1
	var ao_longo := float(base % 101) * 0.173
	var centro_antes: Vector3 = (aneis[0] as Dictionary)["c"]
	for anel: Dictionary in aneis:
		var a := (anel["a"] as Vector3).normalized()
		var u := (anel["v"] as Vector3).cross(a).normalized()
		var w := a.cross(u)
		var centro: Vector3 = anel["c"]
		ao_longo += centro.distance_to(centro_antes)
		centro_antes = centro
		var ru: float = anel["ru"]
		var rv: float = anel["rv"]
		var e := 2.0 / float(anel.get("n", 2.0))
		var bojo: float = anel.get("bojo", 0.0)
		var vinco: float = anel.get("vinco", 0.0)
		var ruga: float = anel.get("ruga", 0.0)
		var fase: float = anel.get("fase", 0.0)
		var c_base: Color = anel["cor"]
		var c_palma: Color = anel.get("cor_palma", c_base)
		var unha: float = anel.get("unha", 0.0)
		var c_unha: Color = anel.get("cor_unha", c_base)
		var fresta: float = anel.get("fresta", 0.0)
		var osso: float = anel.get("osso", 0.0)
		var raio_medio := clampf((ru + rv) * 0.5 / RAIO_NA_COR, 0.0, 1.0)
		for j in lv:
			var phi := TAU * float(j) / float(lados)
			var co := cos(phi)
			var si := sin(phi)
			var x := ru * signf(co) * pow(absf(co), e)
			var y := rv * signf(si) * pow(absf(si), e)
			if si > 0.0:
				y *= 1.0 + bojo * si
			else:
				y *= 1.0 + vinco * si
			var dobra := sin(3.0 * phi + fase)
			var k := 1.0 + ruga * dobra
			v.append(centro + (u * x + w * y) * k)
			nrm.append(Vector3.ZERO)
			uvs.append(uv)
			uv2.append(Vector2(float(j) / float(lados), ao_longo))
			var cv := c_base.lerp(c_palma, clampf((-si - 0.15) / 0.6, 0.0, 1.0))
			if unha > 0.0:
				cv = cv.lerp(c_unha, unha * smoothstep(0.55, 0.95, si))
			if ruga > 0.0:
				cv = cv.darkened(ruga * 3.0 * maxf(0.0, -dobra))
			if fresta > 0.0:
				cv = cv.darkened(fresta * smoothstep(0.55, 1.0, absf(co)))
			cv.a = raio_medio
			cor.append(cv)
			if com_ossos:
				ossos.append_array([0, 1, 0, 0])
				pesos.append_array([1.0 - osso, osso, 0.0, 0.0])
	var polo_ini := -1
	var polo_fim := -1
	if tampa_ini >= 0.0:
		var p: Dictionary = aneis[0]
		polo_ini = v.size()
		v.append((p["c"] as Vector3) - (p["a"] as Vector3).normalized() * tampa_ini)
		nrm.append(Vector3.ZERO)
		uvs.append(uv)
		uv2.append(Vector2(0.25, float(uv2[base].y) - tampa_ini))
		var c0: Color = p.get("cor_palma", p["cor"])
		c0.a = 0.0
		cor.append(c0)
		if com_ossos:
			var o0: float = p.get("osso", 0.0)
			ossos.append_array([0, 1, 0, 0])
			pesos.append_array([1.0 - o0, o0, 0.0, 0.0])
	if tampa_fim >= 0.0:
		var p: Dictionary = aneis[aneis.size() - 1]
		polo_fim = v.size()
		v.append((p["c"] as Vector3) + (p["a"] as Vector3).normalized() * tampa_fim)
		nrm.append(Vector3.ZERO)
		uvs.append(uv)
		uv2.append(Vector2(0.25, ao_longo + tampa_fim))
		var c1: Color = p["cor"]
		c1.a = 0.0
		cor.append(c1)
		if com_ossos:
			var o1: float = p.get("osso", 0.0)
			ossos.append_array([0, 1, 0, 0])
			pesos.append_array([1.0 - o1, o1, 0.0, 0.0])

	var ini := idx.size()
	for k in aneis.size() - 1:
		for j in lados:
			var p00 := base + k * lv + j
			var p01 := p00 + 1
			var p10 := p00 + lv
			var p11 := p01 + lv
			idx.append_array([p00, p10, p01, p01, p10, p11])
	if polo_ini >= 0:
		for j in lados:
			idx.append_array([polo_ini, base + j, base + j + 1])
	if polo_fim >= 0:
		var ult := base + (aneis.size() - 1) * lv
		for j in lados:
			idx.append_array([ult + j, polo_fim, ult + j + 1])

	# Normal suave: soma das faces vizinhas, pesada pela area (o produto
	# vetorial ja vem pesado). O produto aponta para dentro; a normal e o oposto.
	for t in range(ini, idx.size(), 3):
		var i0 := idx[t]
		var i1 := idx[t + 1]
		var i2 := idx[t + 2]
		var fn := (v[i1] - v[i0]).cross(v[i2] - v[i0])
		nrm[i0] -= fn
		nrm[i1] -= fn
		nrm[i2] -= fn
	# A costura: o primeiro e o ultimo vertice de cada volta sao o mesmo ponto,
	# e cada um so somou as faces de um lado. Somados, a volta fecha lisa.
	for k in aneis.size():
		var a0 := base + k * lv
		var a1 := a0 + lados
		var soma := nrm[a0] + nrm[a1]
		nrm[a0] = soma
		nrm[a1] = soma
	for k in range(base, v.size()):
		var nn := nrm[k]
		nrm[k] = nn.normalized() if nn.length_squared() > 1e-18 else Vector3.UP

	m["v"] = v
	m["n"] = nrm
	m["uv"] = uvs
	m["uv2"] = uv2
	m["c"] = cor
	m["i"] = idx
	if com_ossos:
		m["b"] = ossos
		m["w"] = pesos

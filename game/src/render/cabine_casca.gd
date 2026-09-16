## A casca interna do carro: o mesmo casco da lataria, por dentro.
##
## Por que isto existe
## -------------------
## A lataria e uma casca de faces viradas para FORA, desenhada com `cull_back`.
## Do banco do motorista ela simplesmente nao existe: onde o interior nao
## desenhar nada, o que aparece e a rua atravessando a porta. Medido em
## 16/09/2026 por `tests/medir_cabine_cobertura.gd`, de 15,6% a 44,7% do quadro
## era isso — inclusive o buraco que o jogador reportou, na porta do motorista.
##
## A cabine antiga tentava tapar esses lugares com PECAS: uma placa de forro
## aqui, uma caixa de coluna ali, cada uma com medida chutada. Tapar buraco com
## peca solta e uma corrida que nao acaba: cada carro novo, cada angulo novo,
## abre outro.
##
## Esta classe faz o contrario. Ela toma o PERFIL que desenhou a lataria e gera a
## superficie de dentro dele — recuada tres centimetros, virada para o olho, com
## os vaos de janela RECORTADOS. O que sobra e uma cabine fechada por
## construcao: todo raio que sai do olho ou bate em interior, ou sai por um
## vidro. Carro novo com perfil novo nasce fechado sem uma linha aqui.
##
## Espaco de coordenadas
## ---------------------
## A conta toda acontece no espaco do MODULO (+Z na frente, antes da escala),
## que e onde `PERFIL` e os vaos vivem, e cada ponto emitido passa por `_f`, que
## aplica a escala do modelo e a meia volta de `Carroceria.montar`. Misturar os
## dois espacos no meio da geometria e o jeito mais barato de montar um interior
## de cabeca para baixo.
class_name CabineCasca
extends RefCounted

## Quanto a casca recua para dentro da chapa, e quanto o forro do teto desce.
##
## Tres centimetros e a espessura de porta de carro. Menos que isso e o interior
## briga com a lataria pelo mesmo pixel em 3P; mais, e a cabine encolhe e o
## cotovelo do motorista fica dentro da porta.
const RECUO := 0.030
## O forro do teto desce o MESMO tanto que a moldura do para-brisa recua. Os
## dois numeros tem de ser iguais: com o forro 2,8 cm abaixo e a moldura 1,2 cm,
## o encontro entre eles vira um degrau de 1,6 cm, e o raio que passa por esse
## degrau sai pelo teto. Era o ultimo buraco do Fusca e da picape.
const RECUO_TETO := 0.012
## Moldura de para-brisa e vigia: fica quase encostada na chapa, porque ela E o
## acabamento da chapa vista por dentro.
const RECUO_MOLDURA := 0.012

## Subdivisao da casca, em metros e em fracao de secao. Tem de ser fina o
## bastante para a UV afim do psx_surface nao escorregar (ver
## `Carroceria.PASSO_PAINEL`) e grossa o bastante para nao inflar o orcamento.
const PASSO_Z := 0.32
const PASSO_T := 0.26

## Onde a parede lateral comeca, em `t` de secao. Bem abaixo da cintura: a
## parede tem de passar POR BAIXO do assoalho, senao sobra uma fresta entre
## parede e piso — e fresta, aqui, e a rua aparecendo.
const T_PISO := -0.75

## Altura do assoalho acima da linha de baixo do casco, em metros de modulo.
##
## Por que o interior nao pode ser raso
## ------------------------------------
## A cabine nasceu com o "piso" na altura do CAPO, porque o casco da lataria e
## macico ate ali e a face de cima dele servia de chao. Isso faz do interior uma
## caixa de 45 cm: no Marea a linha da janela fica a 3,5 cm desse chao, e numa
## porta de 3,5 cm nao cabe maçaneta, nem manivela, nem apoio de braco — foi
## exatamente isso que o jogador viu faltando.
##
## Nada obriga o interior a parar ali: a face de cima do casco e desenhada com
## `cull_back`, entao de dentro ela nao existe e o volume de baixo esta livre.
## Com o assoalho dez centimetros acima da linha de baixo do casco, o Marea fica
## com 89 cm do chao ao olho — que e a medida de um carro de verdade — e a porta
## passa a ter 60 cm de altura.
const ASSOALHO := 0.10

## Quanto a revelacao de vao passa do vao, em metros de z e em fracao de secao.
const SOBRA_Z := 0.022
const SOBRA_T := 0.045

## Celulas do painel_atlas usadas pela casca.
const C_PORTA := Vector2i(3, 0)
const C_FORRO := Vector2i(5, 0)
const C_CARPETE := Vector2i(4, 0)
const C_VINIL := Vector2i(0, 0)


## Monta a casca dentro de `sup`, no material `material`.
##
## `info` vem de `Carroceria.perfil_cabine()`, `ficha` de `CabineFicha.de()` e
## `olho` e onde a camera do motorista fica, em espaco FINAL — as faces usam o
## olho para decidir para que lado aparecem, em vez de deduzir giro na mao. Ver
## a memoria do projeto "giro de face aponta ao contrario".
##
## Devolve os limites que o resto do interior precisa: o assoalho, o z da frente
## e do fundo e a altura do teto.
static func montar(sup: Dictionary, material: StringName, info: Dictionary,
		ficha: Dictionary, olho: Vector3) -> Dictionary:
	var perfil: Array = info["perfil"]
	var ombro: Vector2 = info["ombro"]
	var escala: Vector3 = info["escala"]
	var vaos: Array = info["vaos"]
	var dados := _dados(sup, material)

	var z_frente: float = perfil[int(info["seg_p"])][0]
	var z_tras := _z_fundo(perfil, int(info["seg_v"]))
	var y_piso := _y_assoalho(perfil, z_frente, z_tras)
	var olho_mod := Vector3(-olho.x / escala.x, olho.y / escala.y,
		-olho.z / escala.z)

	_paredes(dados, perfil, ombro, vaos, z_frente, z_tras, escala, ficha,
		olho_mod)
	_revelacoes(dados, perfil, ombro, vaos, float(info["folga_vidro"]), escala,
		ficha, olho_mod)
	_teto(dados, perfil, int(info["seg_p"]), int(info["seg_v"]), escala, ficha,
		olho_mod)
	_cantoneira(dados, perfil, z_frente, z_tras, escala, ficha, olho_mod)
	_molduras(dados, perfil, info, escala, ficha, olho_mod)
	_piso(dados, perfil, ombro, z_frente, z_tras, y_piso, escala, ficha,
		olho_mod, _cortes_de_vao(vaos))
	_tampa(dados, perfil, ombro, z_tras, y_piso, escala, ficha, olho_mod, C_FORRO)
	_tampa(dados, perfil, ombro, z_frente, y_piso, escala, ficha, olho_mod,
		C_VINIL)

	return {
		"piso": y_piso * escala.y,
		"z_frente": -z_frente * escala.z,
		"z_tras": -z_tras * escala.z,
		"y_teto_frente": _est(perfil, z_frente)[CarroceriaVarrida.TOPO] * escala.y,
		"y_teto_tras": _est(perfil, z_tras)[CarroceriaVarrida.TOPO] * escala.y,
	}


## Onde fica o assoalho deste carro, em metros e em espaco FINAL.
##
## Publica porque quem posiciona o olho do motorista precisa dela ANTES de a
## casca existir: a altura de quem dirige se mede do chao do carro, e nao da
## linha do capo.
static func assoalho(info: Dictionary) -> float:
	var perfil: Array = info["perfil"]
	var escala: Vector3 = info["escala"]
	var z_frente: float = perfil[int(info["seg_p"])][0]
	return _y_assoalho(perfil, z_frente, _z_fundo(perfil, int(info["seg_v"]))) \
		* escala.y


## Onde a parede da casca esta, em X e em espaco FINAL, para uma altura e um Z.
##
## Quem pendura coisa na parede — forro de porta, maçaneta, banco — tem de
## perguntar aqui, e nao usar a meia largura do carro: a secao AFINA para baixo,
## e um alto-falante colocado pela largura da linha da janela atravessa a porta
## por fora. `lado` e o sinal do X final (-1 esquerda, +1 direita).
static func parede_x(info: Dictionary, y: float, z: float, lado: float) -> float:
	var escala: Vector3 = info["escala"]
	var w := CarroceriaVarrida.x_casco_fino(info["perfil"], info["ombro"],
		-z / escala.z, y / escala.y) - RECUO
	return lado * maxf(0.05, w) * escala.x


## Altura do assoalho, em metros de modulo: a linha de baixo do casco no meio da
## cabine, mais `ASSOALHO`.
static func _y_assoalho(perfil: Array, z_frente: float, z_tras: float) -> float:
	var e := _est(perfil, (z_frente + z_tras) * 0.5)
	return e[CarroceriaVarrida.BOT] + ASSOALHO


# --- pecas ------------------------------------------------------------------

## As duas paredes, da frente do para-brisa ao fundo da cabine, com os vaos
## recortados.
##
## A grade nasce das BORDAS dos vaos: toda aresta de janela entra como linha da
## grade, entao nenhuma celula fica metade dentro e metade fora de um vao, e o
## recorte sai exato sem cortar poligono no meio.
static func _paredes(dados: Dictionary, perfil: Array, ombro: Vector2,
		vaos: Array, z_frente: float, z_tras: float, escala: Vector3,
		ficha: Dictionary, olho: Vector3) -> void:
	var cortes_z: Array[float] = []
	var cortes_t: Array[float] = []
	for v: Array in vaos:
		cortes_z.append(float(v[0]))
		cortes_z.append(float(v[1]))
		cortes_t.append(float(v[2]))
		cortes_t.append(float(v[3]))
	cortes_z.append_array(_estacoes(perfil, z_tras, z_frente))
	var gz := _grade(z_tras, z_frente, cortes_z, PASSO_Z)
	var gt := _grade(T_PISO, 1.0, cortes_t, PASSO_T)

	for s: float in [1.0, -1.0]:
		for i in gz.size() - 1:
			for j in gt.size() - 1:
				var zm := (gz[i] + gz[i + 1]) * 0.5
				var tm := (gt[j] + gt[j + 1]) * 0.5
				if _dentro_de_vao(vaos, zm, tm):
					continue
				# Forro de porta abaixo da linha da janela, forro de teto acima:
				# sao materiais diferentes num carro de verdade, e a troca de
				# celula e o que faz a lateral ler como porta e nao como parede.
				var e_porta := tm < _base_das_janelas(vaos)
				var cor: Color = ficha["porta"] if e_porta else ficha["forro"]
				var cel := C_PORTA if e_porta else C_FORRO
				_quad(dados,
					_p(perfil, ombro, gz[i], gt[j], s, escala),
					_p(perfil, ombro, gz[i + 1], gt[j], s, escala),
					_p(perfil, ombro, gz[i + 1], gt[j + 1], s, escala),
					_p(perfil, ombro, gz[i], gt[j + 1], s, escala),
					cel, cor, _olhar(perfil, ombro, zm, tm, s, escala, olho))


## A espessura do vao: as quatro faces que ligam a casca ao vidro.
##
## Sem elas sobra uma fresta de quase cinco centimetros em volta de cada janela —
## a casca esta 3 cm para dentro da chapa e o vidro 1,2 cm para fora dela — e em
## angulo rasante o olho enxerga a mata por essa fresta. E o mesmo defeito do
## buraco, so que fino e por isso mais dificil de ver na captura.
static func _revelacoes(dados: Dictionary, perfil: Array, ombro: Vector2,
		vaos: Array, folga: float, escala: Vector3, ficha: Dictionary,
		olho: Vector3) -> void:
	for s: float in [1.0, -1.0]:
		for v: Array in vaos:
			var z0 := float(v[0])
			var z1 := float(v[1])
			var t0 := float(v[2])
			var t1 := float(v[3])
			# Cada aresta do vao vira uma tira: dentro (casca) -> fora (vidro).
			#
			# As tiras passam do vao nos dois sentidos (`SOBRA_*`), entao elas se
			# cruzam nos cantos e entram um pouco na parede. Sem essa sobra, o
			# raio que corre RENTE ao plano do vao passa entre a tira e a parede
			# e sai pela coluna: era a fresta de 0,3% que sobrava no Fusca e na
			# picape, na borda do quebra-vento.
			var a0 := minf(z0, z1) - SOBRA_Z
			var a1 := maxf(z0, z1) + SOBRA_Z
			var b0 := t0 - SOBRA_T
			var b1 := t1 + SOBRA_T
			for aresta: Array in [
					[a0, t0, a1, t0], [a0, t1, a1, t1],
					[z0, b0, z0, b1], [z1, b0, z1, b1]]:
				# A tira e SUBDIVIDIDA, e nao um quad so.
				#
				# A parede e curva e a tira e reta: encostadas, as duas divergem
				# alguns milimetros no meio, e essa fresta em T e por onde o raio
				# rasante sai — era o que sobrava ao virar a cabeca (0,3 a 2,4%
				# do quadro nas poses laterais). Seguindo a mesma curva, com os
				# mesmos passos, as duas fecham.
				var passos := maxi(2, ceili(maxf(
					absf(float(aresta[2]) - float(aresta[0])) / PASSO_Z,
					absf(float(aresta[3]) - float(aresta[1])) / PASSO_T)))
				for k in passos:
					var f0 := float(k) / float(passos)
					var f1 := float(k + 1) / float(passos)
					var za0 := lerpf(aresta[0], aresta[2], f0)
					var ta0 := lerpf(aresta[1], aresta[3], f0)
					var za1 := lerpf(aresta[0], aresta[2], f1)
					var ta1 := lerpf(aresta[1], aresta[3], f1)
					var a_in := _p(perfil, ombro, za0, ta0, s, escala)
					var b_in := _p(perfil, ombro, za1, ta1, s, escala)
					# Para alcançar o VIDRO, a tira tem de desfazer o recuo da
					# casca E ainda sair a folga do vidro: `-(RECUO + folga)`.
					# Com apenas `-folga` ela parava 1,8 cm DENTRO da chapa.
					var a_out := _p(perfil, ombro, za0, ta0, s, escala,
						-(RECUO + folga))
					var b_out := _p(perfil, ombro, za1, ta1, s, escala,
						-(RECUO + folga))
					_quad(dados, a_in, b_in, b_out, a_out, C_VINIL,
						ficha["moldura"],
						_olhar(perfil, ombro, (za0 + za1) * 0.5,
							(ta0 + ta1) * 0.5, s, escala, olho))


## O forro do teto, do topo do para-brisa ao topo do vigia.
##
## Vai ate a LARGURA CHEIA da lataria, e nao ate a parede recuada: assim ele
## passa por cima da quina de cima da parede e nao sobra fresta no encontro dos
## dois. Um centimetro de sobreposicao aqui vale mais do que qualquer ajuste
## fino depois.
static func _teto(dados: Dictionary, perfil: Array, seg_p: int, seg_v: int,
		escala: Vector3, ficha: Dictionary, olho: Vector3) -> void:
	var za: float = perfil[mini(seg_p + 1, perfil.size() - 1)][0]
	var zb: float = perfil[clampi(seg_v, 0, perfil.size() - 1)][0]
	if za <= zb:
		return
	# O degrau nas duas juntas: a moldura do vidro recua pela NORMAL da rampa e
	# o forro desce pela vertical, entao mesmo com o mesmo recuo sobra um
	# milimetro de fresta na emenda. Uma tira em cada ponta fecha.
	for z: float in [za, zb]:
		var e := _est(perfil, z)
		var w: float = e[CarroceriaVarrida.W_TOPO]
		var y: float = e[CarroceriaVarrida.TOPO]
		_quad(dados,
			_f(Vector3(-w, y, z), escala), _f(Vector3(w, y, z), escala),
			_f(Vector3(w, y - RECUO_TETO * 2.0, z), escala),
			_f(Vector3(-w, y - RECUO_TETO * 2.0, z), escala),
			C_FORRO, ficha["teto"],
			_olhar_ponto(Vector3(0.0, y - RECUO_TETO, z), escala, olho))

	var gz := _grade(zb, za, _estacoes(perfil, zb, za), PASSO_Z)
	var gu := _grade(-1.0, 1.0, [], 0.5)
	for i in gz.size() - 1:
		for j in gu.size() - 1:
			var p00 := _pt(perfil, gz[i], gu[j], escala)
			var p10 := _pt(perfil, gz[i + 1], gu[j], escala)
			var p11 := _pt(perfil, gz[i + 1], gu[j + 1], escala)
			var p01 := _pt(perfil, gz[i], gu[j + 1], escala)
			var centro := (p00 + p10 + p11 + p01) * 0.25
			_quad(dados, p00, p10, p11, p01, C_FORRO, ficha["teto"],
				_f(olho, escala) - centro)


## A moldura do para-brisa e do vigia: a faixa de chapa entre a borda do vao e o
## vidro, que a lataria recua em 10% e ninguem cobria por dentro.
##
## No Marea sao 17 cm de chapa acima do vidro — e eram 19 mil pixels de mata
## aparecendo por cima do para-brisa, o maior buraco unico do carro.
static func _molduras(dados: Dictionary, perfil: Array, info: Dictionary,
		escala: Vector3, ficha: Dictionary, olho: Vector3) -> void:
	var recuo: float = info["recuo_frontal"]
	for k: int in [int(info["seg_p"]), int(info["seg_v"])]:
		if k < 0 or k + 1 >= perfil.size():
			continue
		var za: float = perfil[k][0]
		var zb: float = perfil[k + 1][0]
		var ea: Array = (perfil[k] as Array).slice(1)
		var eb: Array = (perfil[k + 1] as Array).slice(1)
		var q := [
			Vector3(-ea[CarroceriaVarrida.W_TOPO], ea[CarroceriaVarrida.TOPO], za),
			Vector3(ea[CarroceriaVarrida.W_TOPO], ea[CarroceriaVarrida.TOPO], za),
			Vector3(eb[CarroceriaVarrida.W_TOPO], eb[CarroceriaVarrida.TOPO], zb),
			Vector3(-eb[CarroceriaVarrida.W_TOPO], eb[CarroceriaVarrida.TOPO], zb),
		]
		var dentro := CarroceriaVarrida.inset(q[0], q[1], q[2], q[3], recuo)
		var normal := CarroceriaVarrida.normal_placa(q[0], q[1], q[3])
		# A moldura desce em Y, e nao pela normal da rampa. Pela normal, a do
		# VIGIA andava para tras junto com o recuo, e atras o teto ja esta mais
		# baixo: a quina de cima saia 2,5 cm por fora da chapa no sedan, no hatch
		# e na picape. Descer na vertical, a partir de um ponto que esta NA
		# superficie, e sempre para dentro.
		var n := Vector3(0.0, RECUO_MOLDURA, 0.0)
		# O vidro fica colado por FORA da chapa e a moldura por dentro: entre a
		# borda de dentro da moldura e a borda do vidro ha um degrau de dois
		# centimetros. Em angulo rasante o olho entra por esse degrau e acha a
		# chapa — era o que sobrava do buraco do Marea depois da casca (0,31%
		# do quadro, na diagonal da coluna A).
		var g := normal * float(info.get("folga_frontal", 0.010))
		for i in 4:
			var j := (i + 1) % 4
			var a := _f(q[i] - n, escala)
			var b := _f(q[j] - n, escala)
			var c := _f(dentro[j] - n, escala)
			var d := _f(dentro[i] - n, escala)
			var centro := (a + b + c + d) * 0.25
			_quad(dados, a, b, c, d, C_FORRO, ficha["moldura"],
				_f(olho, escala) - centro)
			# A espessura do vao, da moldura ate o vidro.
			var e1 := _f(dentro[i] + g, escala)
			var e2 := _f(dentro[j] + g, escala)
			_quad(dados, d, c, e2, e1, C_VINIL, ficha["moldura"],
				_f(olho, escala) - (c + d + e1 + e2) * 0.25)


## O assoalho, do para-brisa ao fundo.
static func _piso(dados: Dictionary, perfil: Array, ombro: Vector2,
		z_frente: float, z_tras: float, y_piso: float, escala: Vector3,
		ficha: Dictionary, olho: Vector3, cortes: Array) -> void:
	# Os MESMOS cortes da parede, e passo pela metade: a borda do assoalho
	# encosta na parede curva, e com passo grosso ela corta a curva e abre
	# fresta rente ao chao — a segunda familia de vazamento das poses laterais.
	var todos := _estacoes(perfil, z_tras, z_frente)
	todos.append_array(cortes)
	var gz := _grade(z_tras, z_frente, todos, PASSO_Z * 0.5)
	var y := y_piso
	for i in gz.size() - 1:
		var w0 := _meia_largura(perfil, ombro, gz[i], y)
		var w1 := _meia_largura(perfil, ombro, gz[i + 1], y)
		_quad(dados,
			_f(Vector3(-w0, y, gz[i]), escala), _f(Vector3(w0, y, gz[i]), escala),
			_f(Vector3(w1, y, gz[i + 1]), escala),
			_f(Vector3(-w1, y, gz[i + 1]), escala),
			C_CARPETE, ficha["piso"], Vector3.UP)


## A quina onde a parede encontra o teto.
##
## A parede para a tres centimetros da chapa e o forro do teto desce tres: entre
## os dois sobra uma quina aberta de uns tres centimetros por tres, e em angulo
## rasante o olho passa por ela e acha a coluna A do lado de fora. Na primeira
## medida da casca era exatamente isso que restava — 0,31% do quadro no Marea,
## uma lasca diagonal na borda do para-brisa.
##
## A tira fica 3 mm abaixo da linha do teto: coplanar com a chapa ela brigaria
## pelo mesmo pixel com o teto visto de fora.
static func _cantoneira(dados: Dictionary, perfil: Array, z_frente: float,
		z_tras: float, escala: Vector3, ficha: Dictionary,
		olho: Vector3) -> void:
	# Passo pela METADE: na rampa do para-brisa a linha do teto sobe 38 cm em
	# 44, e com o passo cheio a corda da tira afunda um centimetro abaixo da
	# quina — que e fresta de sobra para o raio rasante.
	var gz := _grade(z_tras, z_frente, _estacoes(perfil, z_tras, z_frente),
		PASSO_Z * 0.5)
	for s: float in [1.0, -1.0]:
		for i in gz.size() - 1:
			var ea := _est(perfil, gz[i])
			var eb := _est(perfil, gz[i + 1])
			var wa: float = ea[CarroceriaVarrida.W_TOPO]
			var wb: float = eb[CarroceriaVarrida.W_TOPO]
			var ya: float = ea[CarroceriaVarrida.TOPO]
			var yb: float = eb[CarroceriaVarrida.TOPO]
			# A aresta de fora desce ate o plano do forro, para os tres — parede,
			# cantoneira e forro — se encontrarem na mesma linha.
			# A aresta de dentro nasce EXATAMENTE onde a parede termina. Tres
			# milimetros de folga aqui foi o que fez a primeira cantoneira nao
			# mudar nada: sobrava uma fresta de 3 mm e o raio passava por ela.
			# So a aresta de FORA desce, para nao brigar com o teto visto de
			# fora pelo mesmo pixel.
			_quad(dados,
				_f(Vector3(s * (wa - RECUO), ya, gz[i]), escala),
				_f(Vector3(s * (wb - RECUO), yb, gz[i + 1]), escala),
				# A aresta de fora passa 4 mm da chapa: menos que a colagem do
				# vidro (1,2 cm), entao ela continua escondida de fora, e o
				# suficiente para o raio rasante nao achar a fresta.
				_f(Vector3(s * (wb + 0.004), yb - RECUO_TETO, gz[i + 1]), escala),
				_f(Vector3(s * (wa + 0.004), ya - RECUO_TETO, gz[i]), escala),
				C_FORRO, ficha["teto"],
				_olhar_ponto(Vector3(s * wa, ya, gz[i]), escala, olho))


## O corta-fogo, na frente, e o fundo, atras.
##
## Sao a MESMA peca com o olhar trocado: a secao do casco preenchida num Z, do
## assoalho ate o teto. Feitas como um trapezio de quatro cantos — que foi a
## primeira tentativa — elas nao acompanham a barriga do casco, e entre a tampa
## reta e a parede curva sobra uma fresta: 0,54% do quadro no Fusca, que e o
## carro de secao mais arqueada do jogo.
static func _tampa(dados: Dictionary, perfil: Array, ombro: Vector2, z: float,
		y_piso: float, escala: Vector3, ficha: Dictionary, olho: Vector3,
		celula: Vector2i) -> void:
	var gt := _grade(T_PISO, 1.0, [], PASSO_T)
	for j in gt.size() - 1:
		var a := CarroceriaVarrida.secao(_est(perfil, z), gt[j], ombro)
		var b := CarroceriaVarrida.secao(_est(perfil, z), gt[j + 1], ombro)
		# Abaixo do assoalho nao ha o que fechar: o piso cobre.
		if b.y < y_piso:
			continue
		var ya := maxf(a.y, y_piso)
		# Na altura do assoalho a secao e mais estreita que na cintura: medir a
		# largura no y certo, e nao no t certo.
		var wa := (a.x - RECUO) if a.y >= y_piso 			else _meia_largura(perfil, ombro, z, ya)
		var wb := b.x - RECUO
		_quad(dados,
			_f(Vector3(-wa, ya, z), escala), _f(Vector3(wa, ya, z), escala),
			_f(Vector3(wb, b.y, z), escala), _f(Vector3(-wb, b.y, z), escala),
			celula, ficha["forro"],
			_olhar_ponto(Vector3(0.0, (ya + b.y) * 0.5, z), escala, olho))


# --- conta ------------------------------------------------------------------

## Onde a cabine termina atras: a base do vigia, se houver vigia.
static func _z_fundo(perfil: Array, seg_v: int) -> float:
	if seg_v >= 0 and seg_v + 1 < perfil.size():
		return perfil[seg_v + 1][0]
	return perfil[perfil.size() - 1][0]


## Ponto da parede, recuado para dentro da chapa. `recuo_extra` negativo empurra
## para FORA — e assim que a revelacao alcanca o vidro.
static func _p(perfil: Array, ombro: Vector2, z: float, t: float, s: float,
		escala: Vector3, recuo_extra: float = 0.0) -> Vector3:
	var wy := CarroceriaVarrida.secao(_est(perfil, z), t, ombro)
	return _f(Vector3(s * (wy.x - RECUO - recuo_extra), wy.y, z), escala)


## Ponto do forro do teto. `u` de -1 a 1 atravessa o carro.
static func _pt(perfil: Array, z: float, u: float, escala: Vector3) -> Vector3:
	var e := _est(perfil, z)
	return _f(Vector3(u * e[CarroceriaVarrida.W_TOPO],
		e[CarroceriaVarrida.TOPO] - RECUO_TETO, z), escala)


## Meia largura do casco numa altura dada, ja recuada.
##
## Tem de ser medida NA ALTURA em questao: com a largura da cintura, o assoalho
## saia 7 cm por fora da soleira, porque o carro afina para baixo.
static func _meia_largura(perfil: Array, ombro: Vector2, z: float,
		y: float) -> float:
	return CarroceriaVarrida.x_casco_fino(perfil, ombro, z, y) - RECUO


static func _est(perfil: Array, z: float) -> Array:
	return CarroceriaVarrida.estacao(perfil, z)


## A linha de baixo das janelas: abaixo dela e porta, acima e coluna e teto.
static func _base_das_janelas(vaos: Array) -> float:
	var t := 1.0
	for v: Array in vaos:
		t = minf(t, float(v[2]))
	return t


static func _dentro_de_vao(vaos: Array, z: float, t: float) -> bool:
	for v: Array in vaos:
		var z0: float = minf(v[0], v[1])
		var z1: float = maxf(v[0], v[1])
		if z >= z0 and z <= z1 and t >= float(v[2]) and t <= float(v[3]):
			return true
	return false


## Escala do modulo e meia volta, como em `AberturasVidro.finalizar`.
static func _f(p: Vector3, escala: Vector3) -> Vector3:
	var q := p * escala
	return Vector3(-q.x, q.y, -q.z)


## Para que lado esta face tem de aparecer: para o olho. Passar a direcao em vez
## de deduzir o giro na mao e o que impede a casca inteira de nascer virada para
## dentro da lataria — defeito que ja derrubou o Fusca, os cinco carros de caixa
## e o chao da Estrada Velha.
## Para que lado uma face num ponto qualquer tem de aparecer.
static func _olhar_ponto(centro_modulo: Vector3, escala: Vector3,
		olho: Vector3) -> Vector3:
	return _f(olho, escala) - _f(centro_modulo, escala)


static func _olhar(perfil: Array, ombro: Vector2, z: float, t: float, s: float,
		escala: Vector3, olho: Vector3) -> Vector3:
	var centro := _p(perfil, ombro, z, t, s, escala)
	return _f(olho, escala) - centro


## Os Z das estacoes do perfil dentro de um trecho.
##
## Toda grade da casca precisa deles como linha de corte: entre duas estacoes o
## casco e reto, mas ATRAVESSANDO uma estacao ele dobra, e um quad que passa por
## cima da dobra corta a quina — sai para fora da chapa onde o teto sobe. Era o
## que restava no sedan, no hatch e na picape (2 a 5 cm de peca do lado de fora).
## Os Z das bordas de vao, para quem precisa alinhar com a parede.
static func _cortes_de_vao(vaos: Array) -> Array[float]:
	var out: Array[float] = []
	for v: Array in vaos:
		out.append(float(v[0]))
		out.append(float(v[1]))
	return out


static func _estacoes(perfil: Array, lo: float, hi: float) -> Array[float]:
	var out: Array[float] = []
	for linha: Array in perfil:
		var z: float = linha[0]
		if z > minf(lo, hi) and z < maxf(lo, hi):
			out.append(z)
	return out


static func _grade(a: float, b: float, cortes: Array, passo: float) -> PackedFloat32Array:
	var lo := minf(a, b)
	var hi := maxf(a, b)
	var valores: Array[float] = [lo, hi]
	for c in cortes:
		var v := float(c)
		if v > lo + 0.001 and v < hi - 0.001:
			valores.append(v)
	valores.sort()
	var saida := PackedFloat32Array()
	for k in valores.size():
		if k > 0 and absf(valores[k] - valores[k - 1]) < 0.001:
			continue
		if k > 0:
			# Subdivide o vao entre dois cortes ate caber no passo.
			var n := maxi(1, ceili((valores[k] - valores[k - 1]) / passo))
			for j in range(1, n):
				saida.append(lerpf(valores[k - 1], valores[k], float(j) / float(n)))
		saida.append(valores[k])
	return saida


static func _dados(sup: Dictionary, material: StringName) -> Dictionary:
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	return sup[material]


static func _quad(dados: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3,
		p3: Vector3, celula: Vector2i, cor: Color, olhar: Vector3) -> void:
	if olhar.length_squared() < 1e-9:
		olhar = Vector3.UP
	CarroceriaVarrida.quad(dados, p0, p1, p2, p3, celula, cor, cor, cor, cor,
		olhar.normalized())

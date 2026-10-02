## Os gestos de cena da Missao 1: poses-chave no tempo, escritas por cima da
## pose do Corpo pela `GestoDeCarga`.
##
## Por que poses-chave, e nao angulos como o `ReacaoCorpo`
## -------------------------------------------------------
## A reacao e UMA pose que sobe, segura e desce. Os gestos do roteiro sao
## frases: tirar o papel do bolso, levantar, jogar; levar o dedo ao oculos,
## empurrar, soltar. Cada um passa por tres a seis lugares, e o que importa em
## cada lugar e onde a MAO esta — no bolso de dentro da jaqueta, na ponte do
## oculos, na macaneta. Entao a chave guarda pontos de mao (e o resto do corpo
## que a `GestoDeCarga` ja sabe mexer: agachar, dobrar, torcer, trocar o peso)
## e o IK de dois ossos do levantar leva o braco ate la. Mudar a altura da
## pessoa, ou ela estar sentada no carro, nao desmonta o gesto.
##
## Aditivo ou inteiro
## ------------------
## Quase todo gesto e ADITIVO: tronco e bracos por cima da pose de baixo, as
## pernas sao dela. E o que deixa o Berg baixar o oculos de pe, sentado ao
## volante ou andando, com a mesma tabela. So os que mexem as pernas (entrar e
## sair do carro, pegar do chao) escrevem o corpo inteiro, com os pes plantados.
##
## Travado em passos
## -----------------
## O relogio do gesto e o da `GestoDeCarga`: quinze poses por segundo no PS1
## STYLE, a grade de todo o resto. Entre uma chave e outra a passagem e suave
## nas pontas (smoothstep), porque o passo ja e duro — duro em cima de duro vira
## tranco.
class_name MovimentoDeCena
extends RefCounted

const G := Corpo.GestoCena
const CORPO := GestoDeCarga.Espaco.CORPO
const TRONCO := GestoDeCarga.Espaco.TRONCO

## Do ombro a palma com o braco quase esticado, no corpo de referencia. E onde a
## mao para quando aponta para alguma coisa longe.
const ALCANCE := 0.52
## O ombro direito no corpo de referencia (ver `Corpo._ossos_em_repouso`).
const OMBRO_D := Vector3(0.20, 1.36, 0.0)

## Duracao de cada gesto, em segundos. O roteiro cronometra fala e corte por
## isto (roteiro secao 3 a 7: C4B-02 tira o papel em 2,5 s, C4B-07 baixa o oculos
## em 2,0 s com o dolly, C3-11 bate no adesivo dentro de um plano de 5,5 s).
const DURACOES := {
	G.NENHUM: 0.0,
	G.DESENCOSTAR: 1.1,
	G.JOGAR_PAPEL: 2.0,
	G.ABRIR_PORTA: 0.9,
	G.FECHAR_PORTA: 0.9,
	G.ENTRAR_CARRO: 1.4,
	G.SAIR_CARRO: 1.4,
	G.OLHAR_PARA_TRAS: 1.6,
	G.BAIXAR_OCULOS: 1.2,
	G.SUBIR_OCULOS: 0.9,
	G.RIR: 1.6,
	G.APONTAR: 1.6,
	G.BATER_NO_VIDRO: 1.2,
	G.MAO_NO_CAPO: 2.6,
	G.MEXER_NO_RADIO: 1.8,
	G.APERTAR_VOLANTE: 1.6,
	G.EMPURRAR_NA_BANCADA: 1.4,
	G.OFERECER: 1.8,
	G.BATER_A_CABECA: 1.8,
	G.VIRAR_DEVAGAR: 2.4,
	G.PEGAR_DO_CHAO: 1.6,
}

## Os campos da `GestoDeCarga` que a chave interpola, e o resto que soma.
const CAMPOS := [&"desce", &"recua", &"dobra", &"torcao", &"tomba", &"abre",
	&"avanca", &"desliza", &"riso", &"treme", &"gira"]

var tipo: Corpo.GestoCena = G.NENHUM
var duracao := 1.0
## Segundos desde o comeco.
var t := 0.0
var aditivo := true
var espaco: GestoDeCarga.Espaco = CORPO
## Dicas de cotovelo, no referencial do tronco (as da `GestoDeCarga`).
var cotovelo_d := Vector3(0.6, -0.8, 0.2)
var cotovelo_e := Vector3(-0.6, -0.8, 0.2)
var chaves: Array[Dictionary] = []
## Ponto do mundo que o gesto toca ou aponta (a macaneta, o adesivo, o lugar
## onde o jogador acordou). INF: o ponto padrao da tabela, na frente do corpo.
var alvo := Vector3.INF
## Lado do gesto: +1 direita, -1 esquerda (para onde a porta abre, por cima de
## qual ombro se olha, de que lado do carro a mao passa).
var lado := 1.0

## Resultado da ultima avaliacao.
var cabeca := Vector3.ZERO
## Oculos: NAN quando o gesto nao mexe nele.
var oculos := NAN


static func duracao_de(g: Corpo.GestoCena) -> float:
	return float(DURACOES.get(g, 1.0))


## Monta o gesto para este corpo, agora. `sentado` muda a tabela de quem fecha a
## porta e de onde a mao vai.
static func criar(g: Corpo.GestoCena, sentado: bool, lado_: float,
		alvo_: Vector3) -> MovimentoDeCena:
	var m := MovimentoDeCena.new()
	m.tipo = g
	m.duracao = duracao_de(g)
	m.lado = 1.0 if lado_ >= 0.0 else -1.0
	m.alvo = alvo_
	m._montar(sentado)
	return m


func terminou() -> bool:
	return t >= duracao


## Avanca o relogio e devolve as marcas cruzadas neste passo (o "solta" do
## papel, o "bate" do no do dedo), para quem conduz tocar som ou soltar objeto
## no quadro certo.
func passo(delta: float) -> Array[StringName]:
	var antes := t
	t = minf(t + delta, duracao)
	var marcas: Array[StringName] = []
	for k: Dictionary in chaves:
		if not k.has("marca"):
			continue
		var tk := float(k["t"]) * duracao
		if tk > antes and tk <= t or (antes == 0.0 and tk == 0.0):
			marcas.append(StringName(k["marca"]))
	return marcas


## Escreve o instante de agora na `GestoDeCarga` do corpo.
func avaliar(carga: GestoDeCarga, corpo: Corpo) -> void:
	var passos := 60.0 if Corpo._luz_por_pixel() else 15.0
	var tq := floorf(t * passos) / passos
	var p := clampf(tq / maxf(duracao, 0.001), 0.0, 1.0)
	var i := 0
	while i < chaves.size() - 2 and p > float(chaves[i + 1]["t"]):
		i += 1
	var a: Dictionary = chaves[i]
	var b: Dictionary = chaves[mini(i + 1, chaves.size() - 1)]
	var ta := float(a["t"])
	var tb := float(b["t"])
	var u := 1.0 if tb <= ta else smoothstep(0.0, 1.0, clampf((p - ta) / (tb - ta), 0.0, 1.0))
	var s := corpo.altura() / Corpo.ALTURA_REF

	carga.aditivo = aditivo
	carga.espaco = espaco
	carga.relogio = t
	carga.cotovelo_d = cotovelo_d
	carga.cotovelo_e = cotovelo_e
	carga.peso = lerpf(float(a.get("w", 1.0)), float(b.get("w", 1.0)), u)
	var v := {}
	for c: StringName in CAMPOS:
		v[c] = lerpf(float(a.get(c, 0.0)), float(b.get(c, 0.0)), u)
	carga.desce = v[&"desce"]
	carga.recua = v[&"recua"]
	# O riso e o tremor sao balancos por cima da chave: os ombros sacudindo e a
	# mao que treme no volante. Seno do relogio travado, para cair na grade.
	carga.dobra = v[&"dobra"] + v[&"riso"] * absf(sin(tq * 19.0)) * 0.07
	carga.torcao = v[&"torcao"]
	carga.tomba = v[&"tomba"] + v[&"treme"] * sin(tq * 31.0) * 0.012 \
		+ v[&"riso"] * sin(tq * 9.5) * 0.02
	carga.abre = v[&"abre"]
	carga.avanca = v[&"avanca"]
	carga.desliza = v[&"desliza"]

	var inv := corpo.esqueleto().global_transform.affine_inverse() \
		if corpo.esqueleto() != null else Transform3D.IDENTITY
	for mao: String in ["d", "e"]:
		var pa := _ponto(a, b, mao, s, inv)
		var pb := _ponto(b, a, mao, s, inv)
		var wa := float(a.get("p" + mao, 1.0)) if a.has(mao) else 0.0
		var wb := float(b.get("p" + mao, 1.0)) if b.has(mao) else 0.0
		var w := lerpf(wa, wb, u)
		var pos := pa.lerp(pb, u) if pa.is_finite() and pb.is_finite() else Vector3.INF
		if pos.is_finite() and v[&"gira"] > 0.0:
			# Gira o chaveiro, o botao do radio: a mao descreve um circulo pequeno.
			pos += Vector3(cos(tq * 17.0), sin(tq * 17.0), 0.0) * v[&"gira"] * s
		if mao == "d":
			carga.mao_d = pos
			carga.peso_d = w
		else:
			carga.mao_e = pos
			carga.peso_e = w

	cabeca = (a.get("cab", Vector3.ZERO) as Vector3).lerp(b.get("cab", Vector3.ZERO), u)
	var oa: float = float(a["oc"]) if a.has("oc") else NAN
	var ob: float = float(b["oc"]) if b.has("oc") else oa
	if is_nan(oa):
		oa = ob
	oculos = NAN if is_nan(oa) else lerpf(oa, ob, u)


## O ponto da mao `mao` na chave `k`, no referencial do gesto. Sem mao nessa
## chave, o da chave vizinha (a mao chega e sai de onde a outra chave diz,
## enquanto o peso sobe ou desce).
func _ponto(k: Dictionary, outra: Dictionary, mao: String, s: float,
		inv: Transform3D) -> Vector3:
	var fonte := k if k.has(mao) else outra
	if not fonte.has(mao):
		return Vector3.INF
	var base: Vector3 = fonte[mao]
	if alvo.is_finite() and bool(fonte.get("aponta", false)):
		# O braco estica na direcao do alvo, do ombro ate o alcance.
		var ombro := OMBRO_D * s
		var dir := (inv * alvo - ombro)
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		return ombro + dir * ALCANCE * s
	if alvo.is_finite() and bool(fonte.get("toca", false)):
		# A mao no alvo, com o desvio da chave (recuar para bater de novo).
		var desvio: Vector3 = fonte.get("desvio", Vector3.ZERO)
		return inv * alvo + desvio * s
	if espaco == CORPO or espaco == TRONCO:
		return base * s
	return base


# --- as tabelas ---------------------------------------------------------------
#
# Pontos em metros do corpo de referencia (1,72 m), escalados pela altura. No
# CORPO o zero e o chao entre os pes, -Z e a frente e +X a direita da pessoa. No
# TRONCO o zero e a base do tronco (0,96 m de pe): o ombro fica a +0,40 e os olhos
# a +0,65. Cada chave tem `t` de 0 a 1; `w` e o quanto o gesto vale por cima da
# pose de baixo (0 nas pontas: o gesto nasce e morre dela).

func _montar(sentado: bool) -> void:
	var l := lado
	match tipo:
		G.DESENCOSTAR:
			# As duas maos empurram o paralama atras do quadril e o corpo vem
			# para a frente; a postura ja e LIVRE (ver `Corpo.fazer_gesto`) e a
			# mistura de 0,25 s tira as pernas do cruzado.
			cotovelo_d = Vector3(0.5, -0.4, 0.8)
			cotovelo_e = Vector3(-0.5, -0.4, 0.8)
			chaves = [
				{"t": 0.0, "w": 1.0, "dobra": -0.12, "d": Vector3(0.24, 0.90, 0.12),
					"e": Vector3(-0.24, 0.90, 0.12), "pd": 0.8, "pe": 0.8},
				{"t": 0.35, "w": 1.0, "dobra": 0.16, "d": Vector3(0.25, 0.93, 0.08),
					"e": Vector3(-0.25, 0.93, 0.08), "cab": Vector3(0.10, 0.0, 0.0)},
				{"t": 0.7, "w": 0.6, "dobra": 0.04, "d": Vector3(0.24, 0.88, 0.02),
					"e": Vector3(-0.24, 0.88, 0.02), "pd": 0.2, "pe": 0.2},
				{"t": 1.0, "w": 0.0},
			]
		G.JOGAR_PAPEL:
			# Bolso de dentro da jaqueta (lado esquerdo do peito), tira, levanta
			# um tico e solta com um peteleco para baixo e para a frente.
			cotovelo_d = Vector3(0.7, -0.6, -0.1)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.18, "w": 1.0, "d": Vector3(-0.05, 1.27, -0.15),
					"cab": Vector3(0.22, 0.10, 0.0)},
				{"t": 0.3, "w": 1.0, "d": Vector3(-0.04, 1.25, -0.16), "marca": &"pega",
					"cab": Vector3(0.18, 0.08, 0.0)},
				{"t": 0.46, "w": 1.0, "d": Vector3(0.17, 1.20, -0.30)},
				{"t": 0.58, "w": 1.0, "dobra": -0.03, "d": Vector3(0.25, 1.30, -0.36)},
				{"t": 0.68, "w": 1.0, "dobra": 0.10, "d": Vector3(0.22, 0.98, -0.50),
					"marca": &"solta", "cab": Vector3(0.20, 0.0, 0.0)},
				{"t": 0.82, "w": 0.8, "dobra": 0.05, "d": Vector3(0.24, 0.92, -0.42),
					"cab": Vector3(0.30, 0.0, 0.0)},
				{"t": 1.0, "w": 0.0, "cab": Vector3(0.12, 0.0, 0.0)},
			]
		G.ABRIR_PORTA:
			# A mao na macaneta, a meio metro na frente, e puxa para perto e
			# para o lado em que a porta abre (a dobradica fica do outro).
			cotovelo_d = Vector3(0.7, -0.7, 0.2)
			var mac := Vector3(0.12, 0.98, -0.44)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.35, "w": 1.0, "dobra": 0.14, "d": mac, "toca": true,
					"marca": &"agarra", "cab": Vector3(0.18, 0.0, 0.0)},
				{"t": 0.45, "w": 1.0, "dobra": 0.12, "d": mac, "toca": true,
					"marca": &"puxa"},
				{"t": 0.8, "w": 1.0, "dobra": -0.02, "torcao": 0.12 * l,
					"d": Vector3(0.14 - 0.26 * l, 1.0, -0.22)},
				{"t": 1.0, "w": 0.0},
			]
		G.FECHAR_PORTA:
			if sentado:
				# Por dentro: a mao de fora (esquerda ao volante, direita no
				# carona) vai a porta aberta e puxa. Referencial do tronco, que e o
				# que acompanha o corpo recostado no banco.
				espaco = TRONCO
				aditivo = true
				var mao := "e" if l < 0.0 else "d"
				var fora := Vector3(0.62 * l, 0.12, -0.20)
				var dentro := Vector3(0.38 * l, 0.10, -0.16)
				var k1 := {"t": 0.4, "w": 1.0, "torcao": -0.18 * l, "tomba": 0.10 * l,
					mao: fora, "cab": Vector3(0.10, -0.5 * l, 0.0)}
				var k2 := {"t": 0.72, "w": 1.0, "torcao": -0.06 * l, mao: dentro,
					"marca": &"fecha", "cab": Vector3(0.05, -0.3 * l, 0.0)}
				chaves = [{"t": 0.0, "w": 0.0}, k1, k2, {"t": 1.0, "w": 0.0}]
				if l < 0.0:
					cotovelo_e = Vector3(-0.7, -0.7, 0.3)
			else:
				# De fora, de pe: empurra a porta com a mao aberta.
				chaves = [
					{"t": 0.0, "w": 0.0},
					{"t": 0.35, "w": 1.0, "dobra": 0.06, "d": Vector3(0.18, 1.02, -0.36),
						"toca": true},
					{"t": 0.65, "w": 1.0, "dobra": 0.14, "d": Vector3(0.16, 1.02, -0.56),
						"toca": true, "desvio": Vector3(0.0, 0.0, -0.15), "marca": &"fecha"},
					{"t": 1.0, "w": 0.0},
				]
		G.ENTRAR_CARRO:
			# Abaixa e encolhe a cabeca para passar pelo vao; o Ator gira e leva o
			# corpo para o banco no mesmo relogio, e no fim o Corpo assume a
			# postura de sentado (`Corpo.sentar_como`).
			aditivo = false
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.3, "w": 1.0, "desce": 0.12, "dobra": 0.22, "torcao": 0.25 * l,
					"cab": Vector3(0.15, 0.0, 0.0)},
				{"t": 0.65, "w": 1.0, "desce": 0.38, "dobra": 0.42, "recua": 0.06,
					"e": Vector3(-0.17, 0.62, -0.26), "pe": 0.6, "marca": &"senta",
					"cab": Vector3(0.30, 0.0, 0.0)},
				{"t": 1.0, "w": 1.0, "desce": 0.45, "dobra": 0.20, "recua": 0.10,
					"e": Vector3(-0.17, 0.58, -0.26), "pe": 0.4, "cab": Vector3(0.05, 0.0, 0.0)},
			]
		G.SAIR_CARRO:
			# O contrario: nasce agachado (a mistura vem do sentado), poe o pe
			# para fora e levanta.
			aditivo = false
			chaves = [
				{"t": 0.0, "w": 1.0, "desce": 0.45, "dobra": 0.25, "recua": 0.10,
					"cab": Vector3(0.10, 0.0, 0.0)},
				{"t": 0.35, "w": 1.0, "desce": 0.40, "dobra": 0.45, "avanca": 0.16,
					"e": Vector3(-0.17, 0.60, -0.28), "pe": 0.6, "cab": Vector3(0.30, 0.0, 0.0)},
				{"t": 0.7, "w": 1.0, "desce": 0.14, "dobra": 0.18, "avanca": 0.08,
					"marca": &"de_pe", "cab": Vector3(0.10, 0.0, 0.0)},
				{"t": 1.0, "w": 0.0},
			]
		G.OLHAR_PARA_TRAS:
			# Por cima do ombro: a cabeca vai ate o limite e o tronco leva o
			# resto. `lado` +1 e o ombro direito.
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.25, "w": 1.0, "torcao": -0.55 * l, "cab": Vector3(-0.04, -0.95 * l, 0.0)},
				{"t": 0.75, "w": 1.0, "torcao": -0.55 * l, "cab": Vector3(-0.04, -0.95 * l, 0.0)},
				{"t": 1.0, "w": 0.0},
			]
		G.BAIXAR_OCULOS:
			# O indicador na ponte do oculos empurra para a ponta do nariz; o
			# queixo desce um tico, que e o "olhar por cima da armacao".
			espaco = TRONCO
			cotovelo_d = Vector3(0.45, -0.8, -0.3)
			chaves = [
				{"t": 0.0, "w": 0.0, "oc": 0.0},
				{"t": 0.35, "w": 1.0, "d": Vector3(0.02, 0.595, -0.19), "oc": 0.0,
					"cab": Vector3(0.04, 0.0, 0.0)},
				{"t": 0.65, "w": 1.0, "d": Vector3(0.02, 0.56, -0.20), "oc": 1.0,
					"marca": &"baixou", "cab": Vector3(0.12, 0.0, 0.0)},
				{"t": 1.0, "w": 0.0, "oc": 1.0, "cab": Vector3(0.10, 0.0, 0.0)},
			]
		G.SUBIR_OCULOS:
			espaco = TRONCO
			cotovelo_d = Vector3(0.45, -0.8, -0.3)
			chaves = [
				{"t": 0.0, "w": 0.0, "oc": 1.0},
				{"t": 0.35, "w": 1.0, "d": Vector3(0.02, 0.56, -0.20), "oc": 1.0,
					"cab": Vector3(0.06, 0.0, 0.0)},
				{"t": 0.65, "w": 1.0, "d": Vector3(0.02, 0.595, -0.19), "oc": 0.0,
					"marca": &"subiu", "cab": Vector3(-0.02, 0.0, 0.0)},
				{"t": 1.0, "w": 0.0, "oc": 0.0},
			]
		G.RIR:
			# Ombros sacudindo: o tronco quica para a frente em cima da pose, e a
			# cabeca vai para tras em solavanco (o `Corpo.rir` de sempre).
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.12, "w": 1.0, "riso": 1.0, "dobra": 0.04},
				{"t": 0.75, "w": 1.0, "riso": 0.6, "dobra": 0.06},
				{"t": 1.0, "w": 0.0},
			]
		G.APONTAR:
			# Braco esticado: para o alvo, se houver, senao para a frente e para
			# baixo (o lugar no calcamento, C7-03). Duas batidas do dedo no meio.
			cotovelo_d = Vector3(0.6, -0.6, 0.3)
			var ponta := Vector3(0.26, 1.18, -0.56)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.25, "w": 1.0, "d": ponta, "aponta": true, "dobra": 0.04},
				{"t": 0.4, "w": 1.0, "d": ponta + Vector3(0.0, -0.02, -0.03), "aponta": true,
					"dobra": 0.07},
				{"t": 0.55, "w": 1.0, "d": ponta, "aponta": true, "dobra": 0.04},
				{"t": 0.8, "w": 1.0, "d": ponta, "aponta": true, "dobra": 0.04},
				{"t": 1.0, "w": 0.0},
			]
		G.BATER_NO_VIDRO:
			# Duas batidas com o no do dedo: a mao vai, recua cinco centimetros e
			# volta. A marca "bate" e o clique.
			cotovelo_d = Vector3(0.7, -0.7, 0.1)
			var vidro := Vector3(0.14, 1.24, -0.44)
			var tras := Vector3(0.0, 0.03, 0.06)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.3, "w": 1.0, "d": vidro + tras, "toca": true, "desvio": tras,
					"dobra": 0.06},
				{"t": 0.45, "w": 1.0, "d": vidro, "toca": true, "marca": &"bate",
					"dobra": 0.08},
				{"t": 0.53, "w": 1.0, "d": vidro + tras, "toca": true, "desvio": tras,
					"dobra": 0.06},
				{"t": 0.62, "w": 1.0, "d": vidro, "toca": true, "marca": &"bate",
					"dobra": 0.08},
				{"t": 0.75, "w": 1.0, "d": vidro + tras, "toca": true, "desvio": tras},
				{"t": 1.0, "w": 0.0},
			]
		G.MAO_NO_CAPO:
			# Andando em volta do carro, a mao do lado do carro passa no capo. O
			# Ator move o alvo pela borda do capo a cada quadro.
			var mao := "d" if l > 0.0 else "e"
			var capo := Vector3(0.36 * l, 0.86, -0.12)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.15, "w": 1.0, mao: capo, "toca": true, "p" + mao: 0.85,
					"tomba": 0.04 * l},
				{"t": 0.85, "w": 1.0, mao: capo, "toca": true, "p" + mao: 0.85,
					"tomba": 0.04 * l},
				{"t": 1.0, "w": 0.0},
			]
		G.MEXER_NO_RADIO:
			# Sentado, a mao direita no meio do painel, gira o botao e volta.
			espaco = TRONCO
			cotovelo_d = Vector3(0.5, -0.8, 0.2)
			var radio := Vector3(0.34, 0.10, -0.44)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.3, "w": 1.0, "d": radio, "dobra": 0.10,
					"cab": Vector3(0.18, -0.30, 0.0)},
				{"t": 0.5, "w": 1.0, "d": radio, "gira": 0.012, "dobra": 0.10,
					"marca": &"clique", "cab": Vector3(0.18, -0.30, 0.0)},
				{"t": 0.75, "w": 1.0, "d": radio, "gira": 0.012, "dobra": 0.08,
					"cab": Vector3(0.05, -0.05, 0.0)},
				{"t": 1.0, "w": 0.0},
			]
		G.APERTAR_VOLANTE:
			# Tensao: as maos ficam no aro (sao da pose de dirigir), o tronco vem
			# para cima do volante, a cabeca baixa e o corpo treme.
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.2, "w": 1.0, "dobra": 0.12, "treme": 1.0, "cab": Vector3(0.10, 0.0, 0.0)},
				{"t": 0.8, "w": 1.0, "dobra": 0.14, "treme": 1.0, "cab": Vector3(0.12, 0.0, 0.0)},
				{"t": 1.0, "w": 0.0},
			]
		G.EMPURRAR_NA_BANCADA:
			# O dono empurra o pagamento pela formica: mao na bancada, desliza
			# para a frente vinte centimetros e larga.
			cotovelo_d = Vector3(0.6, -0.7, 0.3)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.3, "w": 1.0, "d": Vector3(0.10, 0.96, -0.38), "toca": true,
					"dobra": 0.18, "cab": Vector3(0.22, 0.0, 0.0)},
				{"t": 0.65, "w": 1.0, "d": Vector3(0.08, 0.96, -0.58), "toca": true,
					"desvio": Vector3(0.0, 0.0, -0.20), "dobra": 0.26, "marca": &"empurra",
					"cab": Vector3(0.18, 0.0, 0.0)},
				{"t": 1.0, "w": 0.0},
			]
		G.OFERECER:
			# Braco estendido na altura do peito, palma para cima: "toma".
			cotovelo_d = Vector3(0.5, -0.8, 0.1)
			var mao_aberta := Vector3(0.16, 1.17, -0.50)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.3, "w": 1.0, "d": mao_aberta, "toca": true, "dobra": 0.05,
					"marca": &"oferece"},
				{"t": 0.8, "w": 1.0, "d": mao_aberta + Vector3(0.0, 0.01, -0.02),
					"toca": true, "dobra": 0.06},
				{"t": 1.0, "w": 0.0},
			]
		G.BATER_A_CABECA:
			# Jota, alto, na lampada do porao (teto de 2,05 m): o tranco desce o
			# corpo e a cabeca, e a mao vai esfregar o alto da cabeca.
			espaco = TRONCO
			cotovelo_d = Vector3(0.6, 0.3, -0.4)
			var topo := Vector3(0.05, 0.80, 0.0)
			chaves = [
				{"t": 0.0, "w": 0.0, "marca": &"bate"},
				{"t": 0.08, "w": 1.0, "dobra": 0.20, "desce": 0.04,
					"cab": Vector3(0.38, 0.0, 0.10)},
				{"t": 0.2, "w": 1.0, "dobra": 0.12, "cab": Vector3(0.28, 0.0, 0.06)},
				{"t": 0.38, "w": 1.0, "dobra": 0.10, "d": topo, "cab": Vector3(0.26, 0.0, 0.0)},
				{"t": 0.75, "w": 1.0, "dobra": 0.08, "d": topo, "gira": 0.025,
					"cab": Vector3(0.20, 0.0, 0.0)},
				{"t": 1.0, "w": 0.0},
			]
		G.VIRAR_DEVAGAR:
			# Helmer: a cabeca vai na frente, devagar, e o tronco segue. Quem o
			# conduz gira o no no fim (`encarar`), quando o gesto solta.
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.45, "w": 1.0, "torcao": 0.25 * l, "cab": Vector3(0.0, 0.55 * l, 0.0)},
				{"t": 0.85, "w": 1.0, "torcao": 0.55 * l, "cab": Vector3(-0.02, 0.65 * l, 0.0)},
				{"t": 1.0, "w": 0.0},
			]
		G.PEGAR_DO_CHAO:
			# Agacha com um pe a frente, a mao vai ao chao e volta.
			aditivo = false
			cotovelo_d = Vector3(0.6, 0.2, 0.6)
			var chao := Vector3(0.12, 0.05, -0.38)
			chaves = [
				{"t": 0.0, "w": 0.0},
				{"t": 0.45, "w": 1.0, "desce": 0.46, "dobra": 0.55, "avanca": 0.20,
					"abre": 0.04, "d": chao, "toca": true, "cab": Vector3(0.35, 0.0, 0.0)},
				{"t": 0.55, "w": 1.0, "desce": 0.46, "dobra": 0.55, "avanca": 0.20,
					"abre": 0.04, "d": chao, "toca": true, "marca": &"pega",
					"cab": Vector3(0.35, 0.0, 0.0)},
				{"t": 1.0, "w": 0.0},
			]
		_:
			chaves = [{"t": 0.0, "w": 0.0}, {"t": 1.0, "w": 0.0}]

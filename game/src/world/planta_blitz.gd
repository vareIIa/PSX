## Planta da blitz: onde cada peca fica e onde a blitz cabe na rua.
##
## Funcao pura, sem autoload, para a regua `tests/checar_blitz.gd` medir sem
## montar cidade. `Blitz` e `BlitzManager` so leem daqui.
##
## Por que a planta saiu do `Blitz`
## --------------------------------
## A primeira blitz tinha 25 m de comprimento (cones a -4,4 m, carro parado a
## +20 m) e a quadra de avenida mais apertada (avenida transversal numa ponta,
## rua na outra) tem 15,1 m livres entre a linha de retencao de um cruzamento e
## a zebra do outro. Ela sempre invadia um cruzamento. E as pecas eram postas
## uma a uma, cada numero escolhido sozinho: o policial do posto ficava dentro
## do carro abordado, o segundo policial dentro da viatura, o terceiro dentro do
## carro encostado, e a linha de cones atravessava as duas faixas. Ninguem viu
## porque as capturas eram encenadas (`--blitz-demo`). Aqui cada posicao sai da
## largura real da via e a regua prova que nada encosta em nada, em nenhum dos
## momentos da blitz.
##
## Convencao local: -Z aponta na direcao do fluxo, +Z e montante (os carros
## chegam pelo +Z). +X aponta para o meio-fio. A origem e a ponta de JUSANTE,
## no eixo da faixa de fora (faixa 0); a blitz ocupa z de 0 a COMPRIMENTO.
##
##   z  13,1 +  cones               policial 0 (posto, acostamento)
##      10,4 |  corredor do         VIATURA (2 rodas na calcada)   policial 2
##       5,0 |  policial   revista                                  boneco
##       2,6 |  JANELA     CARRO ABORDADO (encostado na guia)       policial 1
##       0   +  cones
##          cones   faixa 0 fechada   acostamento   meio-fio   calcada
##          x=-1,0      x=0,85          x=2,1        x=3,3
##
## Quem nao e parado passa pela faixa de dentro (faixa 1), do outro lado da
## linha de cones. Quem e parado vem pela faixa 0, que vira o bolsao da blitz,
## encosta na guia na frente da viatura e sai pela frente, de volta a faixa 0.
##
## Historia do desenho (a regua simulou cada um com o esterco da IA)
## ------------------------------------------------------------------
## 1. Viatura no acostamento, carro encostando entre ela e a ponta: nenhuma
##    combinacao deu folga positiva com a viatura e todas paravam 4 a 7 graus
##    tortas. Dois metros de lado em quatro de frente nao e manobra de carro.
## 2. Carro parando na propria faixa 0, viatura no acostamento: funcionava, mas
##    o corredor do policial passava a 19 cm da viatura, e viatura solta
##    empurrada por capsula cinematica anda — o jogador viu o policial "saindo
##    empurrando o carro". E o carro parado no meio da faixa, longe da guia, nao
##    lia como abordagem.
## 3. (atual) Viatura com duas rodas na calcada, como a PM faz: o acostamento
##    fica livre, e o carro abordado encosta na guia como qualquer carro
##    estacionado, na frente dela. Com a viatura a 2 m do carro a manobra nao
##    fechava (0,25 m longe da guia ou raspando a viatura); a 4,2 m, fecha.
##    Sem plano B: uma versao punha a viatura no acostamento quando a calcada
##    tinha arvore, e o abordado a atravessava. Sem calcada livre, nao ha blitz.
class_name PlantaBlitz
extends RefCounted

## Metros ocupados ao longo da via, da ponta de jusante a de montante. Cabe
## nos 15,1 m da quadra de avenida mais apertada (avenida transversal numa
## ponta); duas avenidas nunca sao nos vizinhos (MalhaUrbana.PERIODO).
const COMPRIMENTO := 13.4
## Folga alem da linha de retencao (ou da zebra) em cada ponta.
const FOLGA_PONTA := 0.5
const TAM := 32.0
## Pintura do cruzamento, como o ChunkBuilder a faz (copiada: o ChunkBuilder
## nao carrega sem a cidade). A linha de retencao fica a meia largura do
## ASFALTO da transversal (estacionamento incluso) mais Vias.FOLGA_RETENCAO, e
## tem 0,28 de espessura centrada 0,14 antes; a zebra do outro lado vai ate a
## meia largura do asfalto mais recuo (0,25) e profundidade (1,5). A primeira
## conta desta planta usou a meia PISTA e a foto ao vivo mostrou os cones da
## ponta em cima da linha de retencao.
const ESPESSURA_RETENCAO := 0.14
const FIM_DA_ZEBRA := 1.75

## Centro do carro abordado, parado na baia (acostamento, na guia).
const Z_BAIA := 2.6
## Distancia da lataria do abordado ate o meio-fio. Colado, a traseira raspava
## a guia na saida: carro que sai de vaga abre a traseira para o lado dela.
const FOLGA_GUIA := 0.35
## Centro da viatura.
const Z_VIATURA := 10.4
## A viatura estaciona com a maior parte na calcada: o centro fica este tanto
## alem do meio-fio.
const VIATURA_ALEM_DO_MEIO_FIO := 0.25
## Linha de cones entre a faixa fechada e a de passagem, a cada 1,6 m. Mais
## esparsa (2,2 a 6,4 m) o bolsao lia como faixa aberta.
const Z_CONES: Array[float] = [0.3, 1.9, 3.5, 5.1, 6.7, 8.3, 9.9, 11.5]
## O abordado chega pela faixa 0 um pouco para a direita do eixo, longe dos
## cones.
const X_BOLSAO := 0.25
## A encostada: comeca quando a mira passa de Z_ENCOSTA_INI e termina na guia
## em Z_ENCOSTA_FIM. A mira aponta um pouco ALEM da guia (VIES_GUIA):
## perseguicao de ponto chega por dentro, e sem o vies o carro parava 25 cm
## longe da vaga.
const Z_ENCOSTA_INI := 11.0
const Z_ENCOSTA_FIM := 5.6
const VIES_GUIA := 0.2
## A saida da vaga: da guia de volta a faixa 0 entre estes dois z da mira.
const Z_SAI_INI := 1.0
const Z_SAI_FIM := -6.0

## Medidas das pecas, meia caixa em metros (x, y, z).
const MEIA_CONE := Vector3(0.2, 0.35, 0.2)
const MEIA_PLACA := Vector3(0.3, 0.7, 0.1)
const MEIA_BOLLARD := Vector3(0.3, 0.8, 0.2)
const MEIA_PESSOA := Vector3(0.28, 0.9, 0.28)
## Sedan (Carroceria.Modelo.SEDA: 4,30 x 1,70 x 1,42).
const MEIA_CARRO := Vector3(0.85, 0.71, 2.15)

## Lei de mira e de velocidade dos carros na blitz. O `Carro` persegue a mira
## que a blitz entrega (esterco limitado) e anda no teto dela; a regua simula o
## mesmo carro com estas mesmas funcoes.
const OLHADA_ENTRADA := 4.0
## Olhada na reta final da vaga: longa, para o carro parar alinhado.
const OLHADA_ALINHA := 4.0
const OLHADA_SAIDA := 3.0
const OLHADA_DESVIO := 8.0
const OLHADA_TARDIA := 2.5
const TETO_ENTRADA := 4.0
const TETO_SAIDA := 5.5
const TETO_DESVIO := 6.0
## Desaceleracao planejada ate a baia, m/s2. Menos que o freio da IA (8): o
## carro para suave, e o teto por distancia faz ele chegar em zero na baia.
const DESACEL_BAIA := 2.2
## Quem entra tarde na faixa 0: freia a isto ate caber a troca, e nunca abaixo
## do passo em que a IA ainda esterca.
const DESACEL_TARDIA := 5.0
const VEL_TROCA_TARDIA := 1.8
## Zona de influencia sobre os carros da IA, alem das pontas. 22 m a montante:
## com 14, quem vinha a 50 km/h pela faixa 0 nao dava tempo de passar para a
## de dentro e raspava o cone da ponta (regua: -0,14 m).
const ZONA_ANTES := 22.0
const ZONA_DEPOIS := 9.0


## Medidas transversais da via, em x local.
static func geometria(via: int) -> Dictionary:
	var meia := MalhaUrbana.meia_pista(via)
	var n := maxi(1, Vias.faixas(via))
	var largura_faixa := meia / float(n)
	var ate_borda := largura_faixa * 0.5
	var est := MalhaUrbana.largura_estacionamento(via)
	var x_meio_fio := ate_borda + est
	return {
		"largura_faixa": largura_faixa,
		# Fim da faixa 0, comeco do acostamento.
		"x_borda": ate_borda,
		"x_acost": ate_borda + est * 0.5,
		"x_meio_fio": x_meio_fio,
		# Linha entre faixa 0 e faixa 1.
		"x_divisa": -ate_borda,
		# Centro da faixa de passagem. A mira de desvio fica 15 cm para dentro
		# dele, longe dos cones.
		"x_dentro": -largura_faixa - 0.15,
		# Eixo da via: alem dele e contramao.
		"x_eixo": -ate_borda - largura_faixa * float(n - 1),
		"x_calcada_fim": x_meio_fio + MalhaUrbana.largura_calcada(via),
		# Onde para o centro do carro abordado, encostado na guia.
		"x_baia": x_meio_fio - MEIA_CARRO.x - FOLGA_GUIA,
	}


## Onde cada coisa fica, em coordenada local. Tudo sai de `geometria`.
static func planta(via: int) -> Dictionary:
	var g := geometria(via)
	var x_acost: float = g["x_acost"]
	var x_mf: float = g["x_meio_fio"]
	var x_baia: float = g["x_baia"]
	var x_cone: float = float(g["x_divisa"]) + 0.1
	var cones: Array[Vector3] = []
	for z: float in Z_CONES:
		cones.append(Vector3(x_cone, 0.0, z))
	# Janela do motorista: ele senta em -X do carro (Carroceria, banco a
	# -0,24 da largura). O policial fica do lado de fora, um palmo a frente do
	# banco, olhando para +X, na faixa fechada.
	var x_janela := x_baia - MEIA_CARRO.x - 0.38
	# Corredor por onde o policial anda ao lado do carro parado: 14 cm da
	# lataria. Mais perto, a capsula dele raspava o carro.
	var x_corredor := x_janela - 0.05
	var z_traseira := Z_BAIA + MEIA_CARRO.z
	var posto_0 := Vector3(x_acost + 0.35, 0.0, 13.1)
	var montante := 12.8
	return {
		"geo": g,
		"cones": cones,
		"placas": [Vector3(x_mf + 0.45, 0.0, 13.2), Vector3(x_mf + 0.45, 0.0, 1.2)],
		"bollard": Vector3(x_mf + 0.4, 0.0, 5.0),
		"viatura": Vector3(x_mf + VIATURA_ALEM_DO_MEIO_FIO, 0.0, Z_VIATURA),
		"baia": Vector3(x_baia, 0.0, Z_BAIA),
		"posto_0": posto_0,
		"posto_1": Vector3(x_mf + 0.9, 0.0, 3.4),
		# Do outro lado da viatura, junto aos predios.
		"posto_2": Vector3(x_mf + 2.0, 0.0, 9.8),
		"janela": Vector3(x_janela, 0.0, Z_BAIA - 0.3),
		# O motorista desce aqui, ja fora da lataria, na faixa fechada.
		"porta": Vector3(x_janela, 0.0, Z_BAIA + 0.35),
		# Revista: na faixa fechada, ao lado da traseira, frente a frente.
		"revista_oficial": Vector3(0.3, 0.0, z_traseira + 1.15),
		"revista_motorista": Vector3(0.3, 0.0, z_traseira - 0.05),
		# O motorista sai pela porta, sobe rente a lataria e para diante do
		# policial.
		"caminho_motorista": [Vector3(x_janela - 0.1, 0.0, z_traseira - 0.55),
			Vector3(0.3, 0.0, z_traseira - 0.05)],
		"caminho_motorista_volta": [Vector3(x_janela - 0.1, 0.0, z_traseira - 0.55),
			Vector3(x_janela, 0.0, Z_BAIA + 0.35)],
		# O policial da janela vai a revista pela faixa fechada, na frente do
		# motorista (ele so desce quando o policial passou da porta).
		"caminho_revista": [Vector3(0.3, 0.0, Z_BAIA - 0.1),
			Vector3(0.3, 0.0, z_traseira + 1.15)],
		# Posto -> janela: por tras da viatura, e desce pelo corredor.
		"caminho_ida": [Vector3(x_corredor, 0.0, montante),
			Vector3(x_corredor, 0.0, Z_BAIA - 0.3),
			Vector3(x_janela, 0.0, Z_BAIA - 0.3)],
		"caminho_volta": [Vector3(x_corredor, 0.0, Z_BAIA - 0.3),
			Vector3(x_corredor, 0.0, montante), posto_0],
		"caminho_volta_revista": [Vector3(x_corredor, 0.0, z_traseira + 1.15),
			Vector3(x_corredor, 0.0, montante), posto_0],
	}


## X da mira do abordado, em funcao do z da mira.
static func x_entrada(via: int, z: float) -> float:
	var alvo := float(geometria(via)["x_baia"]) + VIES_GUIA
	var t := clampf((Z_ENCOSTA_INI - z) / (Z_ENCOSTA_INI - Z_ENCOSTA_FIM), 0.0, 1.0)
	return lerpf(X_BOLSAO, alvo, smoothstep(0.0, 1.0, t))


## X da mira do liberado, em funcao do z da mira.
static func x_saida(via: int, z: float) -> float:
	var x_baia := float(geometria(via)["x_baia"])
	var t := clampf((Z_SAI_INI - z) / (Z_SAI_INI - Z_SAI_FIM), 0.0, 1.0)
	return lerpf(x_baia, 0.0, smoothstep(0.0, 1.0, t))


## Para onde o carro abordado mira na entrada, de onde ele esta (local).
static func mira_entrada(via: int, local: Vector3) -> Vector3:
	var olhada := OLHADA_ENTRADA if local.z - OLHADA_ENTRADA > Z_ENCOSTA_FIM else OLHADA_ALINHA
	var zm := local.z - olhada
	return Vector3(x_entrada(via, zm), 0.0, zm)


## Teto do carro abordado: zero na baia, e sqrt(2ad) antes dela.
static func teto_entrada(z: float) -> float:
	var d := z - Z_BAIA
	if d <= 0.15:
		return 0.0
	return minf(TETO_ENTRADA, sqrt(2.0 * DESACEL_BAIA * (d - 0.15)))


## Sai da vaga pela frente e volta a faixa 0.
static func mira_saida(via: int, local: Vector3) -> Vector3:
	var zm := local.z - OLHADA_SAIDA
	return Vector3(x_saida(via, zm), 0.0, zm)


## Quem nao foi parado: pela faixa de dentro, longe dos cones.
##
## Olhada longa e troca suave para quem vem de longe. Quem ainda esta na faixa
## 0 perto da ponta mira curto: com 8 m de olhada o angulo de troca nao passa
## de 17 graus, e 2,4 m de lado pediam 8 m de reta que ele nao tinha.
static func mira_desvio(via: int, local: Vector3) -> Vector3:
	var g := geometria(via)
	var olhada := OLHADA_DESVIO
	var na_faixa_0 := local.x > float(g["x_divisa"]) - MEIA_CARRO.x
	if na_faixa_0 and local.z < Z_CONES[Z_CONES.size() - 1] + OLHADA_DESVIO + 3.0:
		olhada = OLHADA_TARDIA
	return Vector3(float(g["x_dentro"]), 0.0, local.z - olhada)


## Passa devagar pelo bolsao e no ritmo da via fora dele. Comeca a frear 10 m
## antes da ponta: quem troca de faixa a 50 km/h raspa o primeiro cone.
##
## Quem ainda esta na faixa 0 perto da ponta (entrou tarde: virou da
## transversal de cima, ou nasceu ali) freia para caber a troca antes do
## primeiro cone — sem isto passava por cima da linha inteira (teste_blitz,
## carro plantado a 21 m e 50 km/h). Nunca ate zero: a IA parada nao esterca e
## ficaria ali para sempre.
static func teto_desvio(via: int, local: Vector3) -> float:
	var z := local.z
	if z <= -2.0 or z >= COMPRIMENTO + 10.0:
		return INF
	var teto := TETO_DESVIO
	var g := geometria(via)
	var na_faixa_0 := local.x > float(g["x_divisa"]) - MEIA_CARRO.x
	var primeiro_cone := Z_CONES[Z_CONES.size() - 1] + MEIA_CONE.z
	if na_faixa_0 and z > primeiro_cone:
		var ate := z - primeiro_cone - MEIA_CARRO.z - 0.5
		teto = minf(teto, maxf(VEL_TROCA_TARDIA, sqrt(2.0 * DESACEL_TARDIA * maxf(ate, 0.0))))
	return teto


## A posicao local esta na zona em que a blitz manda no carro da IA?
static func na_zona(via: int, local: Vector3) -> bool:
	var g := geometria(via)
	if local.z < -ZONA_DEPOIS or local.z > COMPRIMENTO + ZONA_ANTES:
		return false
	return local.x > float(g["x_eixo"]) - 0.3 and local.x < float(g["x_meio_fio"]) + 0.5


## As pecas paradas, como caixas {nome, centro, meia}, para a regua. O centro
## esta na altura do meio da peca.
static func pecas_fixas(via: int) -> Array[Dictionary]:
	var p := planta(via)
	var saida: Array[Dictionary] = []
	var i := 0
	for c: Vector3 in p["cones"]:
		saida.append({"nome": "cone_%d" % i, "centro": c + Vector3(0.0, MEIA_CONE.y, 0.0),
			"meia": MEIA_CONE})
		i += 1
	i = 0
	for c: Vector3 in p["placas"]:
		saida.append({"nome": "placa_%d" % i, "centro": c + Vector3(0.0, MEIA_PLACA.y, 0.0),
			"meia": MEIA_PLACA})
		i += 1
	saida.append({"nome": "bollard", "centro": (p["bollard"] as Vector3)
		+ Vector3(0.0, MEIA_BOLLARD.y, 0.0), "meia": MEIA_BOLLARD})
	var v: Vector3 = p["viatura"]
	saida.append({"nome": "viatura", "centro": v + Vector3(0.0, MEIA_CARRO.y, 0.0),
		"meia": MEIA_CARRO})
	for k in 3:
		saida.append({"nome": "policial_%d" % k, "centro": (p["posto_%d" % k] as Vector3)
			+ Vector3(0.0, MEIA_PESSOA.y, 0.0), "meia": MEIA_PESSOA})
	return saida


## Onde a blitz cabe no trecho `t`, perto de `ponto`.
##
## Devolve {} se nao cabe, ou {origem, dir, via, quadra, linha}. A blitz fica
## numa quadra so e encosta a ponta de jusante na folga do cruzamento de baixo:
## a posicao e uma so por quadra e por sentido, entao duas tentativas no mesmo
## trecho dao a mesma blitz.
##
## Cada ponta desconta a transversal que chega ali, qualquer que seja: rua,
## avenida ou viela. Viela nao tem transito, mas tem gente atravessando, e uma
## blitz na boca dela e cone em cima de pedestre. Sem transversal a ponta nao
## desconta nada alem da folga.
static func encaixar(t: Vector4i, de: Vector2i, ponto: Vector3) -> Dictionary:
	var eixo := t.z
	var sentido := t.w
	var linha := de.x if eixo == 0 else de.y
	var via := MalhaUrbana.via_x(linha) if eixo == 0 else MalhaUrbana.via_z(linha)
	if via != MalhaUrbana.Via.AVENIDA:
		return {}
	var s := ponto.z if eixo == 0 else ponto.x
	var k := floori(s / TAM)
	# A quadra inteira tem de ser pista dirigivel (escadaria de morro nao).
	var dirigivel := (Vias.dirigivel_x(linha, k) if eixo == 0
		else Vias.dirigivel_z(linha, k))
	if not dirigivel:
		return {}
	# Jusante e o no para onde o fluxo vai: ali a ponta respeita a linha de
	# retencao. Montante e o no de onde ele vem: ali, a zebra da saida dele.
	var lo := float(k) * TAM + _folga_no(eixo, linha, k, sentido < 0)
	var hi := float(k + 1) * TAM - _folga_no(eixo, linha, k + 1, sentido > 0)
	if hi - lo < COMPRIMENTO:
		return {}
	var s_origem := hi if sentido > 0 else lo
	var x_lateral := (Vias.linha_x(linha, sentido, 0) if eixo == 0
		else Vias.linha_z(linha, sentido, 0))
	var origem := (Vector3(x_lateral, 0.0, s_origem) if eixo == 0
		else Vector3(s_origem, 0.0, x_lateral))
	return {
		"origem": origem,
		"dir": Vias.direcao(eixo, sentido),
		"via": via,
		"quadra": k,
		"linha": linha,
	}


## Quanto a blitz precisa ficar longe do no `k` da linha `linha`: ate a linha
## de retencao (`jusante`) ou ate o fim da zebra, mais a folga.
static func folga_no(eixo: int, linha: int, k: int, jusante: bool) -> float:
	return _folga_no(eixo, linha, k, jusante)


static func _folga_no(eixo: int, linha: int, k: int, jusante: bool) -> float:
	# Transversal no no: a linha perpendicular k, de um lado ou do outro.
	var tem := false
	var asfalto := 0.0
	if eixo == 0:
		tem = (MalhaUrbana.via_z_em(k, linha) != MalhaUrbana.Via.NENHUMA
			or MalhaUrbana.via_z_em(k, linha - 1) != MalhaUrbana.Via.NENHUMA)
		asfalto = Vias.meia_asfalto_z_no(linha, k)
	else:
		tem = (MalhaUrbana.via_x_em(k, linha) != MalhaUrbana.Via.NENHUMA
			or MalhaUrbana.via_x_em(k, linha - 1) != MalhaUrbana.Via.NENHUMA)
		asfalto = Vias.meia_asfalto_x_no(k, linha)
	if not tem:
		return FOLGA_PONTA
	if jusante:
		return asfalto + Vias.FOLGA_RETENCAO + ESPESSURA_RETENCAO + FOLGA_PONTA
	return asfalto + FIM_DA_ZEBRA + FOLGA_PONTA

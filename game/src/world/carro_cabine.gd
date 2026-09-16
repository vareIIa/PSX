## O interior do carro, visto de dentro. Painel, volante, coluna, forro.
##
## Por que isto existe separado da Carroceria
## ------------------------------------------
## Porque a `Carroceria` e o carro dos NPCs, e o carro dos NPCs e visto de fora,
## sempre. Ela e um casco macico ate a linha do capo — o que e a decisao certa
## para um objeto que a nevoa mostra a trinta metros, e custa quatro chamadas de
## desenho em vez de vinte. Nao ha nada errado nela; ela so nunca precisou de
## dentro.
##
## Esta cena precisa. Entao o de fora continua sendo o carro do transito, sem
## uma linha alterada, e o de dentro nasce aqui e entra por cima.
##
## O chao da cabine e o proprio capo
## ---------------------------------
## O casco da Carroceria tem a face de cima na altura do capo, e ela atravessa o
## carro inteiro, de para-choque a para-choque. Vista de dentro, essa face E o
## capo na frente do para-brisa — com a nervura da celula `C_CAPO` e a cor de
## lataria do carro, ja iguais aos do transito. Entao a cabine nao desenha capo
## nenhum: ela se apoia nessa face, um centimetro acima, e desenha so o que
## fica de la para dentro. Um capo proprio aqui seria uma segunda chapa a um
## centimetro da primeira, brigando pelo mesmo pixel e — pior — parando de
## acompanhar a Carroceria no dia em que ela mudar.
##
## Todas as medidas saem do dicionario que `Carroceria.montar` devolve. Nenhuma
## e chutada: o para-brisa da cabine tem de ser o mesmo plano do para-brisa da
## lataria, senao o painel atravessa o vidro.
class_name CarroCabine
extends Node3D

const MAT_PAINEL := &"painel"
const MAT_LUZ := &"painel_luz"
const MAT_CARRO := &"carro"
const MAT_DIR := "res://resources/materials/mat_%s.tres"

# --- celulas do painel_atlas ------------------------------------------------

const C_VINIL := Vector2i(0, 0)
const C_VINIL_CLARO := Vector2i(1, 0)
const C_PORTA := Vector2i(3, 0)
const C_CARPETE := Vector2i(4, 0)
const C_FORRO := Vector2i(5, 0)
const C_MADEIRA := Vector2i(6, 0)
const C_BORRACHA := Vector2i(7, 0)

const C_VELOCIMETRO := Vector2i(0, 1)
const C_COMBUSTIVEL := Vector2i(1, 1)
const C_TEMPERATURA := Vector2i(2, 1)
const C_MOLDURA := Vector2i(3, 1)
const C_DIFUSOR := Vector2i(4, 1)
const C_RADIO := Vector2i(5, 1)
const C_PORTA_LUVAS := Vector2i(6, 1)
const C_METAL := Vector2i(7, 1)

const C_ARO := Vector2i(0, 2)
const C_CUBO := Vector2i(1, 2)
const C_RAIO := Vector2i(2, 2)
const C_ESPELHO := Vector2i(3, 2)

const C_LUZ_PAINEL := Vector2i(0, 3)
const C_PONTEIRO := Vector2i(1, 3)

# --- geometria da cabine ----------------------------------------------------
# Tudo em metros, no espaco do carro: -Z e a frente, +X e a direita de quem
# dirige, e a origem esta no plano em que o pneu toca o chao.

## Folga entre a face de cima do casco e o que a cabine apoia nela. Um
## centimetro: acima disso a juncao aparece como degrau na base do para-brisa,
## abaixo os dois planos disputam o mesmo pixel e o painel pisca.
const APOIO := 0.01

## Onde o motorista senta, medido do centro do carro. Volante a esquerda.
const LADO_MOTORISTA := -0.40
## Altura do olho acima do piso da cabine, e o quanto ele fica atras do painel.
##
## Estes dois numeros sao o enquadramento inteiro do plano de dentro do carro:
## eles decidem quanto capo e quanto estrada cabem na tela, e sao a primeira
## coisa a mexer quando a captura nao bate com a print de referencia.
##
## 0,31 poe o olho no terco de cima do para-brisa do Marea (0,925..1,31),
## olhando por cima do capo. Mais baixo, o capo come a estrada; mais alto,
## o forro volta a tapar o quadro.
##
## Era 0,26, e 0,26 punha o olho UM CENTIMETRO E MEIO acima da borda de cima
## do aro do volante: o aro cortava o quadro na altura da linha do horizonte e
## a estrada aparecia por dentro dele, que e a postura de quem dirige com o
## queixo no peito. Cinco centimetros resolvem os dois lados — o aro desce para
## o terco de baixo e ainda sobram doze centimetros de forro acima da cabeca.
## O cabecalho de `cabine_fundo_criacao.gd` ja citava 31 cm; era esta linha que
## estava atrasada.
const OLHO_ALTURA := 0.31
const OLHO_Z := -0.08

## Painel: onde a face vertical fica e ate onde a superficie de cima vai.
const PAINEL_Z := -0.44
const PAINEL_TOPO := 0.11
## Folga entre a quina de cima do painel e o vidro. Sem ela o painel encosta no
## para-brisa e a quina fica serrilhando contra o vidro em toda lombada.
const PAINEL_FOLGA := 0.03

## Volante: onde o centro fica, o raio do aro, a grossura e a inclinacao da
## coluna em relacao a vertical.
## A coluna desceu de 0,085 para 0,055 junto com a subida do olho: o ganho de
## enquadramento e a SOMA dos dois, e mexer so no olho aproximaria a cabeca do
## forro sem afastar o aro o bastante.
const VOLANTE := Vector3(LADO_MOTORISTA, 0.055, -0.30)
const VOLANTE_RAIO := 0.185
const VOLANTE_TUBO := 0.028
const VOLANTE_LADOS := 10
const VOLANTE_INCLINACAO := 30.0
## Quanto o volante gira, em graus, para a curva mais fechada da estrada. Um
## volante de verdade daria uma volta inteira; a esta velocidade e nesta curva,
## meia volta ja le como exagero de desenho animado.
const VOLANTE_CURSO := 48.0

## Painel de instrumentos: centro, tamanho da moldura e raio dos mostradores.
const CLUSTER_Z := -0.455
const CLUSTER_ALTURA := 0.075
const CLUSTER_LARGURA := 0.40
const CLUSTER_FUNDO := 0.115
const MOSTRADOR_GRANDE := 0.105
const MOSTRADOR_PEQUENO := 0.058

## Velocidade em que o ponteiro chega ao fim do arco. O mostrador desenhado tem
## um arco de 240 graus, como todo mostrador de carro.
const PONTEIRO_FUNDO_ESCALA := 120.0
const PONTEIRO_ARCO := 240.0
const PONTEIRO_ZERO := 210.0

## Console central e o que fica nele.
## Limpador: curso em graus a partir do repouso, e quanto tempo leva uma
## passada completa (ida OU volta), em segundos.
##
## Um limpador de verdade num aguaceiro faz uma passada a cada 0,7 s mais ou
## menos. Mais rapido vira ventilador; mais lento deixa o vidro cheio de
## agua tempo demais e o plano perde a estrada, que e a unica coisa que ele
## tem para mostrar.
const LIMPADOR_CURSO := 78.0
## Periodo da passada na garoa e no aguaceiro, em segundos.
##
## Um so numero era o que mais entregava que a chuva e o limpador eram dois
## sistemas vizinhos e nao um clima: o motorista liga o limpador porque esta
## chovendo, e mexe nele de novo quando aperta. Duas velocidades sao o
## minimo para isso existir, e sao as duas que um carro daquela idade tem.
const LIMPADOR_PASSADA := Vector2(1.45, 0.55)
## Velocidade, em km/h, em que o ar ja venceu o peso da gota no vidro.
const VIDRO_VENTO_CHEIO := 55.0
## Comprimento e grossura da palheta.
const LIMPADOR_COMP := 0.42
const LIMPADOR_GROSSURA := 0.017

## O vidro molhado: distancia da lente e tamanho da placa.
##
## Sessenta centimetros: a distancia do PARA-BRISA, e nao um palmo da lente.
##
## A trinta centimetros a placa ficava na frente do painel, que esta a trinta e
## seis — e o que aparecia na tela era gota de chuva escorrendo por cima do
## volante e dos mostradores, dentro do carro. O vidro e a peca mais LONGE do
## motorista na cabine, nao a mais perto: tudo o que e interior tem de passar na
## frente dele. A sessenta, o painel, o volante, as colunas e o retrovisor
## tapam a agua sozinhos, pelo teste de profundidade, sem mascara nenhuma.
##
## A placa continua presa a LENTE e nao ao vidro de verdade, que e uma rampa
## inclinada: assim ela nunca descobre um canto do quadro quando a camera
## balanca na lombada.
const VIDRO_DIST := 0.60
const VIDRO_TAM := Vector2(1.78, 1.06)
const VIDRO_SHADER := "res://shaders/psx_parabrisa.gdshader"

const CONSOLE_LARGURA := 0.34
const RADIO_ALTURA := 0.11

var _medidas: Dictionary = {}
var _materiais: Dictionary[StringName, ShaderMaterial] = {}
var _pivo_volante: Node3D
var _ponteiro: Node3D
## Os dois pivos de limpador e a placa de agua no vidro.
var _pivos_limpador: Array[Node3D] = []
var _vidro: MeshInstance3D
var _mat_vidro: ShaderMaterial
## As duas janelas laterais, com o mesmo shader do para-brisa. Ver
## `_montar_janelas`.
var _mats_janela: Array[ShaderMaterial] = []
## Fase da passada, de 0 a 2: 0..1 e a ida, 1..2 e a volta.
var _fase_limpador: float = 0.0
## Forca da chuva no vidro agora, de 0 a 1.
var _chuva_vidro: float = 0.0
## Quanto o ar empurra a agua para cima, de 0 a 1.
var _vento_vidro: float = 0.0
## Altura do piso visual da cabine — a face de cima do casco mais a folga.
var _piso: float = 0.79
var _teto: float = 1.38
var _z_parabrisa: float = -0.73
var _y_parabrisa: float = 0.93
var _recuo_parabrisa: float = 0.33
var _dy_parabrisa: float = 0.45


## Monta a cabine a partir das medidas que a Carroceria devolveu.
func montar(medidas: Dictionary) -> void:
	_medidas = medidas
	var comp := float(medidas["comprimento"])
	var larg := float(medidas["largura"])
	# A altura do capo e o tamanho da cabine nao vem no dicionario que a
	# Carroceria devolve, e a cabine precisa do MESMO numero que a lataria usou:
	# deduzir por aproximacao poria o painel atravessando o para-brisa. A tabela
	# de medidas e publica, entao a cabine le dela pelo modelo.
	var tabela: Dictionary = Carroceria.MEDIDAS[_modelo_de(medidas)]
	var capo := float(tabela["capo"])
	var cabine := float(tabela["cabine"])
	_teto = float(medidas["altura"])
	_piso = capo + APOIO

	# O para-brisa vem da lataria. A conta antiga (cabine * 0,5 + 6% do
	# comprimento) era da caixa chanfrada: no Marea ela punha o plano 50 cm
	# a frente do vidro de verdade, e o retrovisor interno / quebra-sol /
	# limpador saiam voando na frente do para-brisa visto de fora.
	var comp_cabine := comp * cabine
	if medidas.has("vidro_base"):
		var b: Vector2 = medidas["vidro_base"]
		var t: Vector2 = medidas["vidro_topo"]
		_z_parabrisa = b.x
		_y_parabrisa = b.y
		_recuo_parabrisa = t.x - b.x
		_dy_parabrisa = t.y - b.y
	else:
		_z_parabrisa = -(comp_cabine * 0.5 + comp * 0.06)
		_y_parabrisa = capo
		_recuo_parabrisa = (_teto - capo) * 0.55
		_dy_parabrisa = _teto - capo

	var sup: Dictionary = {}
	_piso_e_console(sup, larg)
	_painel(sup, larg)
	_instrumentos(sup)
	_laterais(sup, larg, comp_cabine)
	_teto_e_espelho(sup, larg)
	_limpadores(sup, larg)
	_materializar(sup)

	_montar_volante()
	_montar_ponteiro()
	_montar_limpadores(larg)
	_montar_vidro()
	_montar_janelas(larg, comp_cabine)


## De que modelo sao estas medidas. A Carroceria nao devolve o modelo, e a
## cabine precisa dele para ler `capo` e `cabine` da tabela — comparar pelo
## comprimento e o unico jeito que nao pede mudanca do outro lado.
static func _modelo_de(medidas: Dictionary) -> int:
	var comp := float(medidas["comprimento"])
	var melhor := int(Carroceria.Modelo.SEDA)
	var erro := 1e9
	for m: int in Carroceria.MEDIDAS:
		var tabela: Dictionary = Carroceria.MEDIDAS[m]
		var d := absf(float(tabela["c"]) - comp)
		if d < erro:
			erro = d
			melhor = m
	return melhor


## Onde a camera do motorista fica, no espaco do carro.
func olho() -> Vector3:
	return Vector3(LADO_MOTORISTA, _piso + OLHO_ALTURA, OLHO_Z)


## Altura do forro, em metros. Quem precisa pendurar coisa no teto do carro
## precisa deste numero e nao tem como deduzi-lo: a altura vem da tabela de
## medidas da Carroceria, que so a cabine consulta.
func teto() -> float:
	return _teto


## Onde o para-brisa esta na altura `y`. Serve para nada de dentro atravessar o
## vidro — o painel e o retrovisor perguntam antes de se colocar.
func z_do_vidro(y: float) -> float:
	var t := clampf((y - _y_parabrisa) / maxf(0.001, _dy_parabrisa), 0.0, 1.0)
	return _z_parabrisa + _recuo_parabrisa * t


# --- pecas ------------------------------------------------------------------

func _piso_e_console(sup: Dictionary, larg: float) -> void:
	var meia := larg * 0.5 - 0.09
	# O carpete cobre a face de cima do casco de dentro da cabine para tras. Sem
	# ele o "chao" da cabine e a chapa verde do capo, que le como carro sem
	# assoalho — e e o unico lugar onde a economia da Carroceria aparece.
	AtlasKit.face(sup, MAT_PAINEL, Vector2(meia * 2.0, 1.5),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, _piso, PAINEL_Z + 0.75)), C_CARPETE,
		Color(0.9, 0.88, 0.86))

	# Tunel central. Nao e enfeite: e o que separa o lado do motorista do lado
	# do passageiro na imagem, e sem ele a cabine le como um banco corrido de
	# van. Termina antes do painel, onde o console de radio comeca.
	AtlasKit.caixa(sup, MAT_PAINEL,
		Vector3(0.0, _piso + 0.06, PAINEL_Z + 0.55),
		Vector3(CONSOLE_LARGURA, 0.12, 1.1), C_CARPETE,
		Color(0.86, 0.84, 0.82))

	# A alavanca do cambio, saindo do tunel. Duas pecas: haste e manopla.
	AtlasKit.caixa(sup, MAT_PAINEL,
		Vector3(0.0, _piso + 0.20, PAINEL_Z + 0.34),
		Vector3(0.035, 0.17, 0.035), C_METAL, Color(0.8, 0.8, 0.82))
	AtlasKit.caixa(sup, MAT_PAINEL,
		Vector3(0.0, _piso + 0.30, PAINEL_Z + 0.34),
		Vector3(0.07, 0.07, 0.07), C_VINIL, Color(0.9, 0.88, 0.86))


func _painel(sup: Dictionary, larg: float) -> void:
	var meia := larg * 0.5 - 0.09
	var topo := _piso + PAINEL_TOPO
	# A quina da frente do painel encosta no vidro, sem atravessar.
	var z_frente := z_do_vidro(topo) + PAINEL_FOLGA

	# Superficie de cima. E a peca que pega a luz do ceu e a unica clara da
	# cabine — sem ela o painel inteiro e um bloco preto e o volante flutua.
	AtlasKit.painel_repetido(sup, MAT_PAINEL,
		Vector2(meia * 2.0, PAINEL_Z - z_frente),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, topo, (z_frente + PAINEL_Z) * 0.5)),
		C_VINIL_CLARO, 0.5, Color(0.40, 0.39, 0.37))

	# Face vertical, virada para o motorista.
	AtlasKit.painel_repetido(sup, MAT_PAINEL,
		Vector2(meia * 2.0, PAINEL_TOPO),
		Transform3D(Basis(), Vector3(0.0, _piso + PAINEL_TOPO * 0.5, PAINEL_Z)),
		C_VINIL, 0.5, Color.WHITE)

	# Difusores de ar: um na ponta esquerda, dois no meio. Sao os furos escuros
	# que quebram a faixa de vinil, e a unica coisa que da escala ao painel.
	for x: float in [-meia + 0.13, 0.10, 0.30]:
		AtlasKit.face(sup, MAT_PAINEL, Vector2(0.15, 0.048),
			Transform3D(Basis(), Vector3(x, _piso + 0.070, PAINEL_Z + 0.004)),
			C_DIFUSOR, Color.WHITE)

	# Radio e porta-luvas, do lado direito. O radio fica acima do console e o
	# porta-luvas na frente do passageiro, como em qualquer carro.
	AtlasKit.face(sup, MAT_PAINEL, Vector2(0.17, RADIO_ALTURA),
		Transform3D(Basis(), Vector3(0.0, _piso + 0.038, PAINEL_Z + 0.004)),
		C_RADIO, Color.WHITE)
	AtlasKit.face(sup, MAT_PAINEL, Vector2(0.34, 0.13),
		Transform3D(Basis(), Vector3(meia - 0.24, _piso + 0.042, PAINEL_Z + 0.004)),
		C_PORTA_LUVAS, Color.WHITE)
	# Friso de madeira falsa atravessando o painel. E o detalhe de epoca: um
	# painel liso e de qualquer decada, o aplique de madeira e dos anos oitenta.
	AtlasKit.face(sup, MAT_PAINEL, Vector2(meia * 2.0, 0.022),
		Transform3D(Basis(), Vector3(0.0, _piso + 0.100, PAINEL_Z + 0.003)),
		C_MADEIRA, Color(0.40, 0.38, 0.35))


## O painel de instrumentos, na frente do motorista.
##
## A moldura e uma caixa aberta para tras, e nao uma placa: e a aba de cima dela
## que faz o mostrador ficar na sombra, que e como se ve painel de carro de dia.
func _instrumentos(sup: Dictionary) -> void:
	var centro := Vector3(LADO_MOTORISTA, _piso + CLUSTER_ALTURA, CLUSTER_Z)

	AtlasKit.caixa(sup, MAT_PAINEL, centro + Vector3(0.0, 0.0, -0.055),
		Vector3(CLUSTER_LARGURA, CLUSTER_FUNDO, 0.11), C_MOLDURA,
		Color(0.9, 0.9, 0.9))
	# A pala. Meia sombra sobre o mostrador, e o contorno que separa o painel de
	# instrumentos do resto do painel.
	AtlasKit.caixa(sup, MAT_PAINEL,
		centro + Vector3(0.0, CLUSTER_FUNDO * 0.5 + 0.012, -0.03),
		Vector3(CLUSTER_LARGURA + 0.03, 0.025, 0.14), C_VINIL,
		Color(0.85, 0.83, 0.82))

	# Os tres mostradores, na malha emissiva: eles ACENDEM, e por isso nao
	# podem estar no mesmo material do vinil. Sem a emissao o painel de um carro
	# na hora do poente sai preto, que e verdade fisica e pessima imagem.
	AtlasKit.face(sup, MAT_LUZ,
		Vector2(MOSTRADOR_GRANDE * 2.0, MOSTRADOR_GRANDE * 2.0),
		Transform3D(Basis(), centro + Vector3(0.0, 0.0, 0.002)),
		C_VELOCIMETRO, Color.WHITE)
	AtlasKit.face(sup, MAT_LUZ,
		Vector2(MOSTRADOR_PEQUENO * 2.0, MOSTRADOR_PEQUENO * 2.0),
		Transform3D(Basis(), centro + Vector3(-0.145, -0.012, 0.002)),
		C_COMBUSTIVEL, Color.WHITE)
	AtlasKit.face(sup, MAT_LUZ,
		Vector2(MOSTRADOR_PEQUENO * 2.0, MOSTRADOR_PEQUENO * 2.0),
		Transform3D(Basis(), centro + Vector3(0.145, -0.012, 0.002)),
		C_TEMPERATURA, Color.WHITE)


## O interior e SILHUETA, e nao mobilia iluminada.
##
## Estas pecas eram vinil claro (0,78 a 0,94) porque foram calibradas olhando a
## cabine de dia. A noite, na print, o que se ve por dentro do carro e quase
## preto — o painel vertical mede (15,15,12) — e tudo que e claro aqui vira uma
## barra brilhante atravessada no meio do quadro, disputando atencao com a
## estrada, que e a unica coisa que o plano tem para mostrar.
func _laterais(sup: Dictionary, larg: float, comp_cabine: float) -> void:
	var meia := larg * 0.5 - 0.02
	var z0 := PAINEL_Z + 0.05
	var z1 := z0 + comp_cabine * 0.75

	for s: float in [-1.0, 1.0]:
		# Forro da porta, do piso ate a linha do vidro. Vira para dentro.
		AtlasKit.painel_repetido(sup, MAT_PAINEL, Vector2(z1 - z0, 0.21),
			Transform3D(Basis(Vector3.UP, -s * PI * 0.5),
				Vector3(s * meia, _piso + 0.105, (z0 + z1) * 0.5)),
			C_PORTA, 0.5, Color(0.30, 0.29, 0.28))
		# Peitoril: a faixa horizontal em cima do forro, onde o cotovelo apoia.
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(s * (meia - 0.03), _piso + 0.225, (z0 + z1) * 0.5),
			Vector3(0.07, 0.03, z1 - z0), C_VINIL, Color(0.28, 0.27, 0.26))

		# Coluna A: do canto do painel ate o teto, inclinada junto com o vidro.
		# E o que emoldura a estrada nos dois lados da imagem — sem ela o
		# para-brisa nao tem borda e a cabine perde o proprio formato.
		var pe := Vector3(s * (meia - 0.02), _piso + PAINEL_TOPO,
			z_do_vidro(_piso + PAINEL_TOPO) + 0.02)
		var topo := Vector3(s * (meia - 0.10), _teto - 0.03,
			z_do_vidro(_teto) + 0.03)
		var eixo := topo - pe
		var base := Basis.looking_at(eixo.normalized(), Vector3.UP)
		AtlasKit.caixa_livre(sup, MAT_PAINEL, (pe + topo) * 0.5,
			Vector3(0.048, 0.048, eixo.length()), base, C_FORRO,
			Color(0.27, 0.26, 0.25))

		# Caixilho do teto e coluna B: a MOLDURA da janela lateral.
		#
		# Sem os dois, a lateral do carro simplesmente nao existe de dentro. A
		# lataria e uma casca de faces viradas para FORA e o shader e `cull_back`,
		# entao do banco do motorista nao ha porta, nao ha teto e nao ha coluna
		# traseira: o que a cabine desenhava parava no peitoril, 4 cm abaixo do
		# olho, e dali para cima aparecia mata. O carro tinha lado direito (que
		# esta longe e cabe no quadro por inteiro) e nao tinha lado esquerdo, que
		# e justamente o que fica a 45 cm da lente.
		#
		# A janela continua ABERTA, e tem de continuar: janela e para ver atraves.
		# O que faltava era a borda. Com o caixilho em cima, o peitoril embaixo e
		# a coluna B atras, o vao vira uma janela; sem eles era um buraco.
		var y_caixilho := _teto - 0.035
		var z_caixilho := (topo.z + z1) * 0.5
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(s * (meia - 0.085), y_caixilho, z_caixilho),
			Vector3(0.10, 0.045, z1 - topo.z), C_FORRO,
			Color(0.25, 0.24, 0.23))

		var y_peitoril := _piso + 0.225
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(s * (meia - 0.045), (y_peitoril + y_caixilho) * 0.5, z1),
			Vector3(0.062, y_caixilho - y_peitoril, 0.072), C_FORRO,
			Color(0.26, 0.25, 0.24))

		# Painel atras da coluna B, do peitoril ao caixilho. E o que fecha o
		# quadro por tras do ombro do motorista — sem ele a cabine termina numa
		# aresta solta e da para ver a mata passando por dentro do carro quando a
		# camera balanca na lombada.
		AtlasKit.painel_repetido(sup, MAT_PAINEL,
			Vector2(comp_cabine * 0.30, y_caixilho - y_peitoril),
			Transform3D(Basis(Vector3.UP, -s * PI * 0.5),
				Vector3(s * (meia - 0.012), (y_peitoril + y_caixilho) * 0.5,
					z1 + comp_cabine * 0.15)),
			C_PORTA, 0.5, Color(0.24, 0.23, 0.22))


func _teto_e_espelho(sup: Dictionary, larg: float) -> void:
	var meia := larg * 0.5 - 0.06
	var z_frente := z_do_vidro(_teto) + 0.04
	# Forro do teto. Fica virado para baixo — e a face que aparece quando a
	# camera do plano de dentro balanca na lombada.
	AtlasKit.face(sup, MAT_PAINEL, Vector2(meia * 2.0, 1.2),
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(0.0, _teto - 0.015, z_frente + 0.6)), C_FORRO,
		Color(0.26, 0.25, 0.24))

	# Quebra-sol dos dois lados, encostados no teto.
	for s: float in [-1.0, 1.0]:
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(s * 0.28, _teto - 0.028, z_frente + 0.10),
			Vector3(0.42, 0.02, 0.16), C_FORRO, Color(0.24, 0.23, 0.22))

	# Retrovisor interno, no terco de cima do para-brisa, a direita da mira.
	# Longe o bastante da coluna A para nao sumir nela, baixo o bastante
	# para entrar no quadro (olho no terco de cima do vidro).
	var y_esp := _y_parabrisa + _dy_parabrisa * 0.78
	var z_espelho := z_do_vidro(y_esp) + 0.05
	AtlasKit.caixa(sup, MAT_PAINEL,
		Vector3(0.12, y_esp, z_espelho),
		Vector3(0.26, 0.09, 0.045), C_ESPELHO, Color(0.50, 0.51, 0.53))


## Os limpadores, deitados na base do vidro.
##
## Ficam do lado de FORA, sobre o capo, e sao a unica peca da cabine que o
## jogador ve atraves do vidro. Duas ripas de borracha em angulo — a esta
## resolucao um limpador e exatamente isso, e ele importa porque e o que diz
## que ha um vidro ali, num plano em que o vidro nao e desenhado.
func _limpadores(sup: Dictionary, larg: float) -> void:
	# Os bracos, que nao se mexem: a haste que sai do cowl ate o pino da
	# palheta. Assados na malha da cabine como antes.
	#
	# A PALHETA saiu daqui e virou no proprio, porque ela varre. Assada junto
	# com o resto da cabine ela era uma ripa parada deitada no capo, e num
	# temporal isso e pior do que nao ter limpador nenhum: o vidro esta cheio
	# de agua e o limpador, visivelmente, nao esta fazendo nada.
	var y := _y_parabrisa + 0.008
	var z := _z_parabrisa - 0.06
	for s: float in [-1.0, 1.0]:
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(s * larg * 0.18, y - 0.004, z + 0.02),
			Vector3(0.022, 0.012, 0.06), C_BORRACHA, Color(0.19, 0.19, 0.20))


## Os dois pivos de palheta, um por limpador.
##
## O pino fica no cowl, a frente da base do vidro, e a palheta sobe dali para
## dentro do quadro. Girando em torno do pino ela varre o para-brisa em leque,
## que e o movimento real — e nao um retangulo deslizando de lado, que e o que
## sai quando se anima a translacao em vez do angulo.
func _montar_limpadores(larg: float) -> void:
	_pivos_limpador.clear()
	var y := _y_parabrisa + 0.010
	var z := _z_parabrisa - 0.055
	for s: float in [-1.0, 1.0]:
		var pivo := Node3D.new()
		pivo.name = "Limpador%s" % ("E" if s < 0.0 else "D")
		pivo.position = Vector3(s * larg * 0.18, y, z)
		add_child(pivo)
		var sup: Dictionary = {}
		# A palheta nasce deitada sobre a chapa e o pivo a levanta: o angulo de
		# repouso e o proprio giro zero.
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(0.0, 0.004, -LIMPADOR_COMP * 0.5),
			Vector3(LIMPADOR_GROSSURA, 0.010, LIMPADOR_COMP),
			C_BORRACHA, Color(0.20, 0.20, 0.21))
		_materializar(sup, pivo)
		_pivos_limpador.append(pivo)
	_aplicar_limpador()


## A placa de agua entre a lente e o mundo. Ver `psx_parabrisa.gdshader`.
func _montar_vidro() -> void:
	if not ResourceLoader.exists(VIDRO_SHADER):
		push_error("CarroCabine: shader ausente em %s" % VIDRO_SHADER)
		return
	var quad := QuadMesh.new()
	quad.size = VIDRO_TAM
	_vidro = MeshInstance3D.new()
	_vidro.name = "AguaNoVidro"
	_vidro.mesh = quad
	_mat_vidro = ShaderMaterial.new()
	_mat_vidro.shader = load(VIDRO_SHADER)
	_mat_vidro.set_shader_parameter(&"intensidade", 0.0)
	_mat_vidro.set_shader_parameter(&"proporcao", VIDRO_TAM.y / VIDRO_TAM.x)
	_vidro.material_override = _mat_vidro
	_vidro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A placa fica a frente do OLHO, virada para ele. O QuadMesh nasce no plano
	# XY olhando para +Z, e a frente do carro e -Z: sem a meia volta, o que
	# ficaria virado para a camera seria o verso, que o `cull_disabled` do
	# shader ate desenha, mas com a UV espelhada — e a gota escorreria para o
	# lado errado.
	_vidro.position = olho() + Vector3(0.0, 0.0, -VIDRO_DIST)
	_vidro.rotation = Vector3(0.0, PI, 0.0)
	# Sem deslocamento de ordenacao: quem decide o que fica na frente e a
	# PROFUNDIDADE, e o painel e o volante estao honestamente na frente do vidro.
	add_child(_vidro)


## As janelas laterais: vidro de verdade no vao entre peitoril, caixilho e
## colunas.
##
## O defeito que isto conserta
## ---------------------------
## "A lateral esquerda do carro continua invisivel quando estamos dentro dele."
## `tests/medir_cabine.gd` mediu a hipotese obvia e a derrubou: as placas das
## duas laterais estao viradas para o olho (0,468 m2 de cada lado). O que o
## jogador via era outra coisa — o vao da janela, do peitoril ao caixilho e da
## coluna A a B, sem vidro NENHUM. A janela direita fica a 1,2 m da lente e le
## como janela; a esquerda fica a 40 cm, enche o canto do quadro, e um vao
## daquele tamanho sem nada nele le como "o carro nao tem lado".
##
## O caixilho, a coluna B e o peitoril (`_laterais`) ja faziam a MOLDURA. Faltava
## o que vai dentro dela. E o vidro de uma noite de chuva nao e transparente
## liso: e agua escorrendo, deitada para tras quando o carro anda, e o canto
## embacado — o mesmo `psx_parabrisa`, no modo lateral.
##
## Trapezio, e nao retangulo: a borda da frente segue a inclinacao da coluna A.
## Um retangulo com a frente na base da coluna passaria da coluna no alto e
## apareceria pelo para-brisa como uma placa solta ao lado do capo.
func _montar_janelas(larg: float, comp_cabine: float) -> void:
	if not ResourceLoader.exists(VIDRO_SHADER):
		return
	var shader := load(VIDRO_SHADER) as Shader
	var meia := larg * 0.5 - 0.02
	var y0 := _piso + 0.24
	var y1 := _teto - 0.05
	var z_tras := PAINEL_Z + 0.05 + comp_cabine * 0.75
	var z_frente_baixo := z_do_vidro(y0) + 0.03
	var z_frente_alto := z_do_vidro(y1) + 0.05
	var largura := z_tras - (z_frente_baixo + z_frente_alto) * 0.5
	for s: float in [-1.0, 1.0]:
		# Encostado por dentro da casca da lataria e por fora da moldura: e
		# onde o vidro de verdade mora, entre as duas.
		var x := s * (meia - 0.02)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3(-s, 0.0, 0.0))
		# U cresce para a TRASEIRA nos dois lados, e V para baixo: o shader le
		# `sentido_traseira = +1` e deita a agua para tras com o vento.
		var cantos := [
			[Vector3(x, y1, z_frente_alto), Vector2(0.0, 0.0)],
			[Vector3(x, y1, z_tras), Vector2(1.0, 0.0)],
			[Vector3(x, y0, z_tras), Vector2(1.0, 1.0)],
			[Vector3(x, y0, z_frente_baixo), Vector2(0.0, 1.0)],
		]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(cantos[i][1])
			st.add_vertex(cantos[i][0])
		var mi := MeshInstance3D.new()
		mi.name = "JanelaEsquerda" if s < 0.0 else "JanelaDireita"
		mi.mesh = st.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"lateral", 1.0)
		mat.set_shader_parameter(&"sentido_traseira", 1.0)
		mat.set_shader_parameter(&"proporcao", (y1 - y0) / maxf(largura, 0.01))
		# A mesma densidade de gota por metro do para-brisa: 54 colunas em
		# 1,78 m. A agua e fisica, entao o tamanho dela nao depende de quao
		# perto a lente esta.
		mat.set_shader_parameter(&"celulas", 54.0 / VIDRO_TAM.x * largura)
		mat.set_shader_parameter(&"intensidade", 0.0)
		if OS.get_cmdline_user_args().has("--dbg-tela"):
			mat.set_shader_parameter(&"depurar_tela", 1.0)
		mi.material_override = mat
		add_child(mi)
		_mats_janela.append(mat)


## Move os limpadores e a agua do vidro. Chamada pelo carro, todo quadro.
##
## `forca` e quanto esta chovendo, de 0 a 1. Zero para os limpadores no
## repouso e apaga a agua — e o estado de todo clima que nao e o temporal, e e
## por isso que esta cena continua funcionando em `--estrada-clima=dia`.
func limpar(forca: float, velocidade: float, delta: float) -> void:
	_chuva_vidro = clampf(forca, 0.0, 1.0)
	_vento_vidro = clampf(absf(velocidade) / VIDRO_VENTO_CHEIO, 0.0, 1.0)
	var passada := lerpf(LIMPADOR_PASSADA.x, LIMPADOR_PASSADA.y, _chuva_vidro)
	if _chuva_vidro <= 0.01:
		_fase_limpador = move_toward(_fase_limpador, 0.0, delta / passada)
	else:
		_fase_limpador = fmod(_fase_limpador + delta / passada, 2.0)
	_aplicar_limpador()


func _aplicar_limpador() -> void:
	# Ida e volta a partir da mesma fase. O seno em vez da rampa: a palheta
	# desacelera nas duas pontas do curso, como qualquer coisa presa a uma
	# manivela. Com rampa linear ela bate no fim do curso e volta no mesmo
	# quadro, o que le como quadro perdido.
	var t := _fase_limpador * 0.5
	var k := 0.5 - 0.5 * cos(t * TAU)
	var ang := deg_to_rad(LIMPADOR_CURSO) * k
	for i in _pivos_limpador.size():
		var pivo := _pivos_limpador[i]
		# Os dois varrem para o MESMO lado, como num carro de verdade: em
		# espelho eles se cruzariam no meio do vidro.
		pivo.rotation = Vector3(0.0, 0.0, -ang)
	if _mat_vidro == null:
		return
	_mat_vidro.set_shader_parameter(&"intensidade", _chuva_vidro)
	_mat_vidro.set_shader_parameter(&"vento", _vento_vidro)
	# A agua volta a juntar a partir do instante em que a palheta passa pelo
	# meio do vidro, e nao do comeco do curso: e la que ela limpa o que a lente
	# esta vendo. `k` vale meio nas duas travessias do meio, na ida e na volta.
	var desde := absf(k - 0.5) * 2.0
	_mat_vidro.set_shader_parameter(&"acumulo", clampf(desde, 0.08, 1.0))
	# As janelas bebem da mesma chuva e do mesmo vento. Nao tem limpador, entao
	# nao ha `acumulo` para elas: o shader ignora o valor quando `lateral` e 1.
	for m: ShaderMaterial in _mats_janela:
		m.set_shader_parameter(&"intensidade", _chuva_vidro)
		m.set_shader_parameter(&"vento", _vento_vidro)


# --- volante ----------------------------------------------------------------

## O volante, num pivo proprio para poder girar.
##
## O aro sao dez caixas em volta de um circulo, e nao um toro: a 480x270 o
## contorno de dez lados e o contorno de trinta, e o toro custaria duzentos
## triangulos a mais no objeto que fica mais perto da camera na cena inteira.
func _montar_volante() -> void:
	_pivo_volante = Node3D.new()
	_pivo_volante.name = "Volante"
	_pivo_volante.position = Vector3(VOLANTE.x, _piso + VOLANTE.y, VOLANTE.z)
	# Inclinada para tras como coluna de direcao de verdade. Sem a inclinacao o
	# volante fica em pe como o de um caminhao e a mao nao alcanca.
	_pivo_volante.rotation = Vector3(deg_to_rad(-VOLANTE_INCLINACAO), 0.0, 0.0)
	add_child(_pivo_volante)

	var sup: Dictionary = {}
	for i in VOLANTE_LADOS:
		var a := TAU * float(i) / float(VOLANTE_LADOS)
		var b := TAU * float(i + 1) / float(VOLANTE_LADOS)
		var pa := Vector3(cos(a), sin(a), 0.0) * VOLANTE_RAIO
		var pb := Vector3(cos(b), sin(b), 0.0) * VOLANTE_RAIO
		var meio := (pa + pb) * 0.5
		var eixo := pb - pa
		AtlasKit.caixa_livre(sup, MAT_PAINEL, meio,
			Vector3(VOLANTE_TUBO, VOLANTE_TUBO, eixo.length() + 0.004),
			Basis.looking_at(eixo.normalized(), Vector3.FORWARD),
			C_ARO, Color(0.30, 0.29, 0.28))

	# Tres raios, como quase todo volante da epoca: dois abertos para baixo e um
	# para cima. Quatro raios simetricos leem como volante de onibus.
	for graus: float in [200.0, 340.0, 90.0]:
		var a := deg_to_rad(graus)
		var ponta := Vector3(cos(a), sin(a), 0.0) * (VOLANTE_RAIO - 0.01)
		AtlasKit.caixa_livre(sup, MAT_PAINEL, ponta * 0.5,
			Vector3(0.022, 0.014, ponta.length()),
			Basis.looking_at(ponta.normalized(), Vector3.FORWARD),
			C_RAIO, Color(0.28, 0.28, 0.28))

	AtlasKit.caixa(sup, MAT_PAINEL, Vector3(0.0, 0.0, 0.012),
		Vector3(0.11, 0.07, 0.03), C_CUBO, Color.WHITE)

	_materializar(sup, _pivo_volante)


## O ponteiro do velocimetro. Uma agulha so, na malha que acende.
func _montar_ponteiro() -> void:
	_ponteiro = Node3D.new()
	_ponteiro.name = "Ponteiro"
	_ponteiro.position = Vector3(LADO_MOTORISTA, _piso + CLUSTER_ALTURA,
		CLUSTER_Z + 0.004)
	add_child(_ponteiro)

	var sup: Dictionary = {}
	# Desenhada ao longo de +X, saindo do centro: assim o giro em Z leva a ponta
	# para o angulo pedido, no mesmo sentido em que os tracos foram desenhados.
	AtlasKit.face(sup, MAT_LUZ,
		Vector2(MOSTRADOR_GRANDE * 0.86, 0.008),
		Transform3D(Basis(), Vector3(MOSTRADOR_GRANDE * 0.40, 0.0, 0.0)),
		C_PONTEIRO, Color.WHITE)
	_materializar(sup, _ponteiro)
	marcar(0.0)


## Poe o ponteiro na velocidade dada, em km/h.
func marcar(kmh: float) -> void:
	if _ponteiro == null:
		return
	var t := clampf(kmh / PONTEIRO_FUNDO_ESCALA, 0.0, 1.0)
	_ponteiro.rotation.z = deg_to_rad(PONTEIRO_ZERO - PONTEIRO_ARCO * t)


## Gira o volante. `curva` vai de -1 (esquerda) a 1 (direita).
func estercar(curva: float) -> void:
	if _pivo_volante == null:
		return
	_pivo_volante.rotation.z = deg_to_rad(-VOLANTE_CURSO * clampf(curva, -1.0, 1.0))


# --- montagem ---------------------------------------------------------------

func _materializar(sup: Dictionary, onde: Node3D = null) -> void:
	var pai := onde if onde != null else self
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(mi)


func _material(nome: StringName) -> ShaderMaterial:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho := MAT_DIR % nome
	if not ResourceLoader.exists(caminho):
		push_error("CarroCabine: material ausente em %s" % caminho)
		return null
	var m := load(caminho) as ShaderMaterial
	_materiais[nome] = m
	return m

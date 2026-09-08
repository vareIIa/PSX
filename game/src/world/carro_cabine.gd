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
const OLHO_ALTURA := 0.36
const OLHO_Z := 0.12

## Painel: onde a face vertical fica e ate onde a superficie de cima vai.
const PAINEL_Z := -0.44
const PAINEL_TOPO := 0.21
## Folga entre a quina de cima do painel e o vidro. Sem ela o painel encosta no
## para-brisa e a quina fica serrilhando contra o vidro em toda lombada.
const PAINEL_FOLGA := 0.03

## Volante: onde o centro fica, o raio do aro, a grossura e a inclinacao da
## coluna em relacao a vertical.
const VOLANTE := Vector3(LADO_MOTORISTA, 0.155, -0.30)
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
const CLUSTER_ALTURA := 0.155
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
const CONSOLE_LARGURA := 0.34
const RADIO_ALTURA := 0.11

var _medidas: Dictionary = {}
var _materiais: Dictionary[StringName, ShaderMaterial] = {}
var _pivo_volante: Node3D
var _ponteiro: Node3D
## Altura do piso visual da cabine — a face de cima do casco mais a folga.
var _piso: float = 0.79
var _teto: float = 1.38
var _z_parabrisa: float = -0.73
var _recuo_parabrisa: float = 0.33


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

	# O para-brisa, na mesma conta de `Carroceria._vidros`, ja com a meia volta
	# aplicada: la a frente do carro e +Z, aqui e -Z.
	var comp_cabine := comp * cabine
	_z_parabrisa = -(comp_cabine * 0.5 + comp * 0.06)
	_recuo_parabrisa = (_teto - capo) * 0.55

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


## Onde o para-brisa esta na altura `y`. Serve para nada de dentro atravessar o
## vidro — o painel e o retrovisor perguntam antes de se colocar.
func z_do_vidro(y: float) -> float:
	var capo := _piso - APOIO
	var t := clampf((y - capo) / maxf(0.001, _teto - capo), 0.0, 1.0)
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
		C_VINIL_CLARO, 0.5, Color(0.92, 0.90, 0.88))

	# Face vertical, virada para o motorista.
	AtlasKit.painel_repetido(sup, MAT_PAINEL,
		Vector2(meia * 2.0, PAINEL_TOPO),
		Transform3D(Basis(), Vector3(0.0, _piso + PAINEL_TOPO * 0.5, PAINEL_Z)),
		C_VINIL, 0.5, Color.WHITE)

	# Difusores de ar: um na ponta esquerda, dois no meio. Sao os furos escuros
	# que quebram a faixa de vinil, e a unica coisa que da escala ao painel.
	for x: float in [-meia + 0.13, 0.10, 0.30]:
		AtlasKit.face(sup, MAT_PAINEL, Vector2(0.15, 0.075),
			Transform3D(Basis(), Vector3(x, _piso + 0.145, PAINEL_Z + 0.004)),
			C_DIFUSOR, Color.WHITE)

	# Radio e porta-luvas, do lado direito. O radio fica acima do console e o
	# porta-luvas na frente do passageiro, como em qualquer carro.
	AtlasKit.face(sup, MAT_PAINEL, Vector2(0.17, RADIO_ALTURA),
		Transform3D(Basis(), Vector3(0.0, _piso + 0.075, PAINEL_Z + 0.004)),
		C_RADIO, Color.WHITE)
	AtlasKit.face(sup, MAT_PAINEL, Vector2(0.34, 0.13),
		Transform3D(Basis(), Vector3(meia - 0.24, _piso + 0.08, PAINEL_Z + 0.004)),
		C_PORTA_LUVAS, Color.WHITE)
	# Friso de madeira falsa atravessando o painel. E o detalhe de epoca: um
	# painel liso e de qualquer decada, o aplique de madeira e dos anos oitenta.
	AtlasKit.face(sup, MAT_PAINEL, Vector2(meia * 2.0, 0.022),
		Transform3D(Basis(), Vector3(0.0, _piso + 0.19, PAINEL_Z + 0.003)),
		C_MADEIRA, Color(0.9, 0.86, 0.8))


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


func _laterais(sup: Dictionary, larg: float, comp_cabine: float) -> void:
	var meia := larg * 0.5 - 0.02
	var z0 := PAINEL_Z + 0.05
	var z1 := z0 + comp_cabine * 0.75

	for s: float in [-1.0, 1.0]:
		# Forro da porta, do piso ate a linha do vidro. Vira para dentro.
		AtlasKit.painel_repetido(sup, MAT_PAINEL, Vector2(z1 - z0, 0.21),
			Transform3D(Basis(Vector3.UP, -s * PI * 0.5),
				Vector3(s * meia, _piso + 0.105, (z0 + z1) * 0.5)),
			C_PORTA, 0.5, Color(0.94, 0.92, 0.9))
		# Peitoril: a faixa horizontal em cima do forro, onde o cotovelo apoia.
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(s * (meia - 0.03), _piso + 0.225, (z0 + z1) * 0.5),
			Vector3(0.07, 0.03, z1 - z0), C_VINIL, Color(0.88, 0.86, 0.84))

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
			Vector3(0.075, 0.075, eixo.length()), base, C_FORRO,
			Color(0.78, 0.76, 0.72))


func _teto_e_espelho(sup: Dictionary, larg: float) -> void:
	var meia := larg * 0.5 - 0.06
	var z_frente := z_do_vidro(_teto) + 0.04
	# Forro do teto. Fica virado para baixo — e a face que aparece quando a
	# camera do plano de dentro balanca na lombada.
	AtlasKit.face(sup, MAT_PAINEL, Vector2(meia * 2.0, 1.2),
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(0.0, _teto - 0.015, z_frente + 0.6)), C_FORRO,
		Color(0.82, 0.80, 0.76))

	# Quebra-sol dos dois lados, encostados no teto.
	for s: float in [-1.0, 1.0]:
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(s * 0.28, _teto - 0.055, z_frente + 0.10),
			Vector3(0.42, 0.02, 0.16), C_FORRO, Color(0.86, 0.84, 0.8))

	# Retrovisor interno, pendurado no alto do vidro. O espelho olha para tras,
	# entao a celula de vidro fica na face de tras da caixa.
	var z_espelho := z_do_vidro(_teto - 0.10) + 0.05
	AtlasKit.caixa(sup, MAT_PAINEL,
		Vector3(0.0, _teto - 0.12, z_espelho),
		Vector3(0.21, 0.065, 0.035), C_ESPELHO, Color(0.9, 0.9, 0.92))


## Os limpadores, deitados na base do vidro.
##
## Ficam do lado de FORA, sobre o capo, e sao a unica peca da cabine que o
## jogador ve atraves do vidro. Duas ripas de borracha em angulo — a esta
## resolucao um limpador e exatamente isso, e ele importa porque e o que diz
## que ha um vidro ali, num plano em que o vidro nao e desenhado.
func _limpadores(sup: Dictionary, larg: float) -> void:
	var y := _piso + 0.012
	var z := _z_parabrisa - 0.05
	for s: float in [-1.0, 1.0]:
		var giro := deg_to_rad(74.0 * s)
		AtlasKit.caixa_livre(sup, MAT_PAINEL,
			Vector3(s * larg * 0.20, y, z),
			Vector3(0.02, 0.012, 0.52), Basis(Vector3.UP, giro),
			C_BORRACHA, Color(0.7, 0.7, 0.7))


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
			C_ARO, Color(0.95, 0.92, 0.9))

	# Tres raios, como quase todo volante da epoca: dois abertos para baixo e um
	# para cima. Quatro raios simetricos leem como volante de onibus.
	for graus: float in [200.0, 340.0, 90.0]:
		var a := deg_to_rad(graus)
		var ponta := Vector3(cos(a), sin(a), 0.0) * (VOLANTE_RAIO - 0.01)
		AtlasKit.caixa_livre(sup, MAT_PAINEL, ponta * 0.5,
			Vector3(0.022, 0.014, ponta.length()),
			Basis.looking_at(ponta.normalized(), Vector3.FORWARD),
			C_RAIO, Color(0.9, 0.9, 0.9))

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

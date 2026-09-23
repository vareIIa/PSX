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

## Altura do olho acima do ASSOALHO de verdade.
##
## Esta e a medida que vale desde que a cabine ganhou volume (`CabineCasca`).
## `OLHO_ALTURA` media do "piso" falso na linha do capo e fica so como rede para
## medidas antigas.
##
## Oitenta centimetros e a medida de gente sentada em carro: do carpete ao olho
## dao 75 a 85 cm em qualquer sedan. E, principalmente, e o que poe o olho ABAIXO
## do topo do para-brisa — no Marea o vidro termina em 1,30 m e o olho estava em
## 1,25, ou seja, cinco centimetros. O motorista dirigia espiando por uma fresta,
## e isso so nao aparecia porque a cabine antiga nao tinha teto para tapar o
## resto.
const OLHO_DO_ASSOALHO := 0.80

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

## Velocidade, em km/h, em que o ar ja venceu o peso da gota no vidro.
const VIDRO_VENTO_CHEIO := 55.0

## Onde o embacado de dentro se acomoda com chuva cheia, de 0 a 1.
##
## E o ALVO do canal B, e nao a taxa: o embacado vai ate ele e para. Janela
## fechada e gente respirando dentro embacam o vidro exatamente quando ele molha
## de fora, mas embacam ate um ponto — 0,30 deixa um veu que se ve e atraves do
## qual ainda se dirige. Com 0,60 numa rampa sem teto, que era o primeiro
## desenho, em vinte e cinco segundos o para-brisa fica branco e some a estrada.
const UMIDADE_CHUVA := 0.30

## Quanto o desembacador esta ligado, de 0 a 1, e quanta sujeira o vidro tem.
##
## Sao da CENA, e nao do clima: o mesmo temporal pede o ventilador no talo numa
## cena de tensao e o vidro embacando devagar numa cena parada. O padrao e o de
## quem dirige na chuva — ventilador pela metade, o leque aberto na base e o
## alto do para-brisa ainda embacado — e um carro que ninguem lava ha meses.
## Medido na captura: com 0,55 a cupula limpa ficava inteira atras do painel e
## o para-brisa visivel era so embacado; com 0,80 ela sobe ate a metade do vidro
## no meio, que e o desenho que se reconhece.
const DESEMBACADOR_PADRAO := 0.80
const SUJEIRA_PADRAO := 0.16

## Geometria e cinematica do limpador sairam daqui: sao de `Limpador`, que
## tambem sabe o MODO (desligado, intermitente, 1 e 2) e o setor varrido em cada
## quadro. O que sobrou aqui e o clima chegando de fora.

## Console central e o que fica nele.
const CONSOLE_LARGURA := 0.34
const RADIO_ALTURA := 0.11

var _medidas: Dictionary = {}
## Modelo desta cabine, lido de `medidas["modelo"]`. Ver `_modelo_de`.
var _modelo: int = Carroceria.Modelo.SEDA
## O que muda de um interior para outro. Ver `CabineFicha`.
var _ficha: Dictionary = {}
## Limites que a casca interna devolveu. Vazio quando as medidas vem de um
## dicionario antigo, sem `perfil_cabine`.
var _casca: Dictionary = {}
var _materiais: Dictionary[StringName, ShaderMaterial] = {}
var _pivo_volante: Node3D
var _ponteiro: Node3D
## A malha de vidro e o material dela.
var _vidro: MeshInstance3D
var _mat_vidro: ShaderMaterial
## Referencial de cada vidro, de `VidroCabine`. O para-brisa e o unico que o
## limpador usa.
var _paineis: Array = []
var _indice_parabrisa: int = -1
var _painel_parabrisa: Dictionary = {}
## Os tres sistemas da agua: o mapa que lembra, as gotas que correm e a palheta.
var _agua: AguaVidro
var _corredoras: AguaCorredoras
var _limpador: Limpador
var _teto_chuva: TetoChuva
## Ver `DESEMBACADOR_PADRAO`. A cena escreve aqui quando quer outro clima de
## dentro.
var desembacador: float = DESEMBACADOR_PADRAO
var sujeira: float = SUJEIRA_PADRAO:
	set(v):
		sujeira = clampf(v, 0.0, 0.5)
		if _mat_vidro != null:
			_mat_vidro.set_shader_parameter(&"sujeira", sujeira)
## Forca da chuva no vidro agora, de 0 a 1.
var _chuva_vidro: float = 0.0
## Quanto o ar empurra a agua para cima, de 0 a 1.
var _vento_vidro: float = 0.0
## Estimativa de cobertura por vidro, na CPU.
##
## O mapa de verdade mora na GPU, e le-lo de volta custa uma sincronizacao por
## quadro — o preco de um `get_image()` e alto demais para saber onde nascem as
## corredoras. Entao a CPU mantem a MESMA conta do shader, em um numero por
## vidro: nao serve para desenhar, serve para decidir quantas gotas grandes
## cabem e quanto elas engordam. Quando as duas divergem, quem manda na imagem
## e o mapa.
var _cob_cpu := PackedFloat32Array()
## Os rastros de corredora deste quadro, em UV do mapa. Guardados porque a sonda
## do criterio C6 precisa saber quais texels tinham motivo para perder agua.
var _trilhas := PackedVector4Array()
## `--dbg-agua=mapa|cobertura|filme|embacado|sujeira`: pinta o vidro com o canal do mapa
## em cor chapada, sem gota nem refracao por cima.
##
## Um mapa de agua e um sistema que so se ve pelo resultado, e resultado bonito
## esconde erro: na Fase 3 eu passei meia hora convencido de que o leque estava
## errado quando o errado era o angulo de repouso. Com o canal na tela, a
## pergunta "onde a palheta limpou" vira uma imagem.
var _dbg_agua: int = _dbg_agua_da_linha()
## Altura do piso visual da cabine — a face de cima do casco mais a folga.
var _piso: float = 0.79
## O assoalho de verdade, de `CabineCasca`. Zero enquanto nao houver casca.
var _piso_real: float = 0.0
## Onde o motorista senta NESTE carro. Ver `_lado_do_motorista`.
var _lado: float = LADO_MOTORISTA
## Centro do retrovisor interno, escrito por `_teto_e_espelho`.
var _espelho := Vector3.ZERO
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
	_modelo = int(medidas.get("modelo", _modelo_de(medidas)))
	var tabela: Dictionary = Carroceria.MEDIDAS[_modelo]
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

	_ficha = CabineFicha.de(_modelo)

	var sup: Dictionary = {}
	# A CASCA primeiro: ela e o fundo de tudo. O resto do interior — painel,
	# console, porta, banco — e detalhe colado por dentro dela. Ver
	# `CabineCasca`: antes disto a cabine tapava buraco com peca solta, e de
	# 15,6% a 44,7% do quadro continuava sendo a rua vista atraves da chapa.
	if medidas.has("perfil_cabine"):
		# O assoalho ANTES da casca: `olho()` precisa dele, e a casca precisa do
		# olho para saber para que lado cada face aparece.
		_piso_real = CabineCasca.assoalho(medidas["perfil_cabine"])
		_lado = _lado_do_motorista(medidas["perfil_cabine"])
		_casca = CabineCasca.montar(sup, MAT_PAINEL, medidas["perfil_cabine"],
			_ficha, olho())
	_piso_e_console(sup, larg)
	_painel(sup, larg)
	_instrumentos(sup)
	_laterais(sup, larg, comp_cabine)
	_teto_e_espelho(sup, larg)
	_materializar(sup)

	_montar_volante()
	_montar_ponteiro()
	_montar_agua()


## Uma abertura de vidro pelo tipo e pelo lado (-1 esquerda, +1 direita). Vem de
## `Carroceria.montar`, que a calcula da mesma tabela que desenhou o vidro de
## fora — ver `AberturasVidro`.
func _abertura(tipo: StringName, lado: int) -> Dictionary:
	for a: Dictionary in _medidas.get("aberturas", []):
		if a["tipo"] == tipo and int(a["lado"]) == lado:
			return a
	return {}


## Onde o motorista senta NESTE carro, em X.
##
## Quarenta centimetros do centro e a medida de um sedan, e era usada em todos.
## Num Fusca, que tem 1,55 m de largura, o aro do volante (37 cm de diametro)
## nascia a 61 cm do centro e ATRAVESSAVA a porta — `checar_cabine_contida`
## media seis centimetros de aro do lado de fora do carro.
##
## O lugar do motorista e o que sobra depois de caber o volante entre ele e a
## porta.
func _lado_do_motorista(info: Dictionary) -> float:
	var y := _piso_real + OLHO_DO_ASSOALHO * 0.35
	var parede := absf(CabineCasca.parede_x(info, y, VOLANTE.z, 1.0))
	var teto_x := parede - VOLANTE_RAIO - VOLANTE_TUBO - 0.02
	return -clampf(absf(LADO_MOTORISTA), 0.10, maxf(0.10, teto_x))


## De que modelo sao estas medidas, quando o dicionario nao diz.
##
## `Carroceria.montar` passou a escrever `"modelo"` (Fase 1 do
## PLANO_CHUVA_CABINE_AAA), e e de la que o numero sai. Isto aqui fica so como
## rede para dicionario antigo — montado a mao em teste, por exemplo. Comparar
## pelo comprimento empata sedan com taxi, e e por isso que nao serve de
## verdade.
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
	if _piso_real > 0.0:
		return Vector3(_lado, _piso_real + OLHO_DO_ASSOALHO, OLHO_Z)
	return Vector3(_lado, _piso + OLHO_ALTURA, OLHO_Z)


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

## Assoalho e console.
##
## O carpete que morava aqui SAIU: quem desenha o chao agora e `CabineCasca`, no
## assoalho de verdade. O carpete antigo era uma face na altura do capo, porque
## a cabine inteira era uma caixa rasa de 45 cm — e era esse chao falso que
## deixava a porta com 3,5 cm de altura, sem lugar para maçaneta nenhuma.
func _piso_e_console(sup: Dictionary, _larg: float) -> void:
	if _casca.is_empty():
		return
	CabineMoveis.console(sup, MAT_PAINEL, _ficha, float(_casca["piso"]), olho(),
		float(_casca["z_frente"]), CONSOLE_LARGURA)



func _painel(sup: Dictionary, larg: float) -> void:
	var topo := _piso + PAINEL_TOPO
	# A quina da frente do painel encosta no vidro, sem atravessar.
	var z_frente := z_do_vidro(topo) + PAINEL_FOLGA
	# A largura sai da PAREDE na altura do painel, e nao da largura do carro.
	# Com `larg * 0.5 - 0.09` o painel media 0,685 m de meia largura no Fusca,
	# cuja lateral tem 0,59 na cintura: as duas pontas atravessavam a porta e
	# apareciam de fora. `checar_cabine_contida` acusa isso em metros.
	var meia := larg * 0.5 - 0.09
	if not _casca.is_empty():
		# Medido na quina da FRENTE, que e onde o carro e mais estreito nesta
		# altura: um painel dimensionado pelo meio ainda fura a lateral la.
		var info: Dictionary = _medidas["perfil_cabine"]
		meia = minf(absf(CabineCasca.parede_x(info, topo, z_frente, 1.0)),
			absf(CabineCasca.parede_x(info, topo, PAINEL_Z, 1.0))) - 0.015

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
	var centro := Vector3(_lado, _piso + CLUSTER_ALTURA, CLUSTER_Z)

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
##
## O que ISTO fazia antes, e nao faz mais
## --------------------------------------
## Forro de porta, coluna A, caixilho, coluna B e painel atras do ombro eram
## cinco pecas soltas, cada uma com medida chutada a partir da largura do carro,
## tentando tapar o que a lataria deixava aberto. Tapar buraco com peca solta e
## uma corrida que nao acaba: no Fusca sobravam 44,7% do quadro abertos, e a
## janela da cabine chegava a cair 8% em cima de CHAPA.
##
## Quem faz a parede agora e `CabineCasca`, gerada do perfil da lataria com os
## vaos recortados. Aqui sobrou o que e DETALHE de porta — o que o olho reconhece
## como carro por dentro e nao da para deduzir de um perfil.
func _laterais(sup: Dictionary, larg: float, comp_cabine: float) -> void:
	if _casca.is_empty():
		# Dicionario de medidas antigo, sem `perfil_cabine`: sem casca, e o
		# detalhe de porta sozinho nao fecha nada. Nao ha o que desenhar.
		return
	var piso := float(_casca["piso"])
	for lado: int in [-1, 1]:
		var abertura := _abertura(&"porta_frente", lado)
		if abertura.is_empty():
			# Sem porta dianteira daquele lado (nao deveria acontecer), o forro
			# nao tem onde se apoiar.
			continue
		CabineMoveis.porta(sup, MAT_PAINEL, abertura, _ficha, piso, olho(),
			_medidas["perfil_cabine"])
	CabineMoveis.bancos(sup, MAT_PAINEL, _ficha, piso, olho(),
		float(_casca["z_tras"]), _medidas["perfil_cabine"])


## Quebra-sol e retrovisor.
##
## O forro do teto saiu daqui: ele era uma face plana na altura do teto, e o
## teto do carro nao e plano — no Marea ela atravessava a lataria na frente da
## cabine (20% do que se via de dentro era peca ALEM da chapa). Quem desenha o
## forro agora e `CabineCasca`, seguindo a curva do casco.
func _teto_e_espelho(sup: Dictionary, larg: float) -> void:
	# As duas pecas penduram na BORDA DE CIMA do para-brisa de verdade, que vem
	# da lataria. Antes saiam de `_teto` (a altura maxima do carro) e de
	# `z_do_vidro`, medidas da cabine rasa: no sedan e na perua elas iam parar
	# meio metro acima do capo, na frente do vidro, e so nao apareciam porque o
	# plano da cutscene nao olha para cima.
	var vidro := _abertura(&"parabrisa", 0)
	if vidro.is_empty():
		return
	var pontos: PackedVector3Array = vidro["pontos"]
	# Os dois cantos mais ALTOS sao a borda de cima; a media deles da o meio da
	# testeira, que e onde o retrovisor mora.
	var altos: Array[Vector3] = []
	for p: Vector3 in pontos:
		altos.append(p)
	altos.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	var meio := (altos[0] + altos[1]) * 0.5
	var meia_testeira := absf(altos[0].x - altos[1].x) * 0.5

	# Quebra-sol dos dois lados, encostados na testeira e virados para dentro.
	for s: float in [-1.0, 1.0]:
		AtlasKit.caixa(sup, MAT_PAINEL,
			Vector3(s * meia_testeira * 0.52, meio.y - 0.035, meio.z + 0.12),
			Vector3(meia_testeira * 0.80, 0.022, 0.16), C_FORRO,
			Color(0.24, 0.23, 0.22))

	# Retrovisor interno, logo abaixo da testeira e um palmo a direita da mira.
	_espelho = Vector3(0.12, meio.y - 0.085, meio.z + 0.06)
	AtlasKit.caixa(sup, MAT_PAINEL, _espelho,
		Vector3(0.26, 0.09, 0.045), C_ESPELHO, Color(0.50, 0.51, 0.53))


## Onde o retrovisor interno esta, no espaco do carro. Quem pendura alguma
## coisa nele — o santinho da cena da estrada — precisa deste ponto, e ele so
## existe depois de `montar`.
func ponto_do_espelho() -> Vector3:
	return _espelho


## O pivo do volante. O que estiver pendurado nele gira junto com a direcao —
## e o caso da mao do motorista.
func pivo_do_volante() -> Node3D:
	return _pivo_volante


## Onde o motorista senta, em X, e a altura do piso da cabine em que ele apoia
## os pes. Sao as duas medidas que quem monta um motorista precisa e nao tem
## como deduzir de fora.
func lado_do_motorista() -> float:
	return _lado


func piso_da_cabine() -> float:
	return _piso_real if _piso_real > 0.0 else _piso


## Os vidros, o mapa de agua, as corredoras e os limpadores.
##
## A ordem importa e nao e arbitraria
## ----------------------------------
## Os referenciais dos vidros vem primeiro porque o mapa de agua precisa dos
## TAMANHOS para empacotar os retangulos; o mapa vem antes da malha porque a
## malha escreve o UV do mapa em cada vertice; e o limpador vem por ultimo
## porque ele precisa do referencial do para-brisa e do indice dele no mapa.
## Fazer qualquer um desses passos fora de ordem da um vidro sem mapa ou um mapa
## sem vidro, e nenhum dos dois reclama.
##
## O que saiu daqui
## ----------------
## Uma placa de 1,78 x 1,06 m presa a 60 cm do OLHO, virada para a camera, com a
## agua desenhada nela; e mais duas placas chutadas nas janelas laterais. As
## tres desenhavam agua onde nao havia vidro — 21 a 47% do quadro — e nenhuma
## tinha a inclinacao do vidro que fingia ser.
func _montar_agua() -> void:
	var aberturas: Array = _medidas.get("aberturas", [])
	if aberturas.is_empty():
		return
	_paineis = VidroCabine.referenciais(aberturas)
	if _paineis.is_empty():
		return
	for i in _paineis.size():
		if _paineis[i]["tipo"] == &"parabrisa":
			_indice_parabrisa = i
			_painel_parabrisa = _paineis[i]
	_cob_cpu.resize(_paineis.size())
	_cob_cpu.fill(0.0)

	# O mapa. `Settings.luz_por_pixel` e o que distingue MODERNO de PS1 STYLE:
	# no PS1 a tela e metade, e um mapa mais fino que o pixel nao aparece.
	_agua = AguaVidro.new()
	_agua.name = "Agua"
	add_child(_agua)
	var rects := _agua.montar(_paineis, _estilo_ps1())

	_mat_vidro = VidroCabine.material()
	var malha := VidroCabine.montar(_paineis, rects)
	if _mat_vidro == null or malha == null:
		return
	_vidro = MeshInstance3D.new()
	_vidro.name = "Vidros"
	_vidro.mesh = malha
	_vidro.material_override = _mat_vidro
	_vidro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_vidro)
	var tex := _agua.textura()
	_mat_vidro.set_shader_parameter(&"usa_mapa", tex != null)
	if tex != null:
		_mat_vidro.set_shader_parameter(&"mapa", tex)
	if _dbg_agua > 0:
		_mat_vidro.set_shader_parameter(&"depurar", _dbg_agua)
	_mat_vidro.set_shader_parameter(&"sujeira", sujeira)

	if not rects.is_empty():
		_corredoras = AguaCorredoras.new()
		_corredoras.name = "Corredoras"
		add_child(_corredoras)
		_corredoras.montar(_paineis, rects)

	if not _painel_parabrisa.is_empty():
		_limpador = Limpador.new()
		_limpador.name = "Limpadores"
		add_child(_limpador)
		_limpador.configurar(_painel_parabrisa, _indice_parabrisa,
			_material(MAT_PAINEL))
		# O desenho que as palhetas deixam na sujeira. Ver `Limpador.leque`.
		var leque := _limpador.leque()
		if not leque.is_empty() and _mat_vidro != null:
			_mat_vidro.set_shader_parameter(&"tem_leque", true)
			_mat_vidro.set_shader_parameter(&"leque_a", leque["pivo_a"])
			_mat_vidro.set_shader_parameter(&"leque_b", leque["pivo_b"])
			_mat_vidro.set_shader_parameter(&"leque_raios", leque["raios"])
			_mat_vidro.set_shader_parameter(&"leque_angulos", leque["angulos"])

	# Onde nao chove. Ver `TetoChuva`.
	var teto := teto_da_chuva()
	if not teto.is_empty():
		_teto_chuva = TetoChuva.new()
		_teto_chuva.name = "TetoChuva"
		_teto_chuva.dono = self
		_teto_chuva.teto = teto
		add_child(_teto_chuva)


## Um quadro de clima. Chamada pelo carro, todo quadro.
##
## `chuva` e quanto esta caindo, de 0 a 1. `vel_local` e `acel_local` sao a
## velocidade e a aceleracao do carro NO ESPACO DO CARRO, em m/s e m/s^2 — a
## mesma API para o carro da cena e para o da cidade, que e o que evita dois
## caminhos de entrada com dois sinais trocados.
##
## O que esta funcao substituiu
## ----------------------------
## `limpar(forca, velocidade, delta)`, que movia UM float de cobertura e UMA
## fase de limpador. Com um float so, tudo o que acontece no vidro acontece no
## vidro inteiro; e sem a aceleracao nao ha como a freada empurrar a agua para a
## base do para-brisa, que e o criterio C8.
func atualizar_clima(chuva: float, vel_local: Vector3, acel_local: Vector3,
		delta: float) -> void:
	_chuva_vidro = clampf(chuva, 0.0, 1.0)
	_vento_vidro = clampf(vel_local.length() * 3.6 / VIDRO_VENTO_CHEIO, 0.0, 1.0)
	_mover_cobertura_cpu(delta)

	var setor := {}
	if _limpador != null:
		_limpador.atualizar(_chuva_vidro, _cobertura_parabrisa(), delta)
		setor = _limpador.setor()

	_trilhas = PackedVector4Array()
	if _corredoras != null:
		_trilhas = _corredoras.passo(_chuva_vidro, _cob_cpu, vel_local,
			acel_local, setor, delta)

	if _agua != null:
		_agua.passo({
			&"chuva": _chuva_vidro,
			&"vento": _vento_vidro,
			&"umidade": _chuva_vidro * UMIDADE_CHUVA,
			&"desembacador": desembacador,
			"limpador": setor,
			"trilhas": _trilhas,
		}, delta)

	if _mat_vidro != null:
		_mat_vidro.set_shader_parameter(&"intensidade", _chuva_vidro)
		_mat_vidro.set_shader_parameter(&"vento", _vento_vidro)
		# Reserva, para o caso de o mapa nao ter subido: sem isto o vidro
		# ficaria seco em silencio, que e o pior jeito de um sistema falhar.
		_mat_vidro.set_shader_parameter(&"cobertura", _cobertura_parabrisa())


## A mesma conta do shader de simulacao, um numero por vidro.
##
## Nao e o mapa, e nem tenta ser: e o que a CPU precisa saber para decidir onde
## nasce corredora e quanto tempo o intermitente espera. Ler o mapa de volta da
## GPU custaria uma sincronizacao por quadro.
func _mover_cobertura_cpu(delta: float) -> void:
	for i in _cob_cpu.size():
		var painel: Dictionary = _paineis[i]
		var exposicao: float = painel.get("exposicao", 1.0)
		var v := _cob_cpu[i]
		v += _chuva_vidro * exposicao * (1.0 + 0.9 * _vento_vidro) * delta \
			/ AguaVidro.TEMPO_ENCHER
		v -= delta * (1.0 - _chuva_vidro * exposicao) * (1.0 + _vento_vidro) \
			/ AguaVidro.TEMPO_SECAR
		_cob_cpu[i] = clampf(v, 0.0, 1.0)


func _cobertura_parabrisa() -> float:
	if _indice_parabrisa < 0 or _indice_parabrisa >= _cob_cpu.size():
		return 0.0
	return _cob_cpu[_indice_parabrisa]


## O volume onde nao chove, no espaco desta cabine. Ver `TetoChuva`.
##
## A caixa vai da largura do carro, do assoalho ao teto e do corta-fogo ao
## fundo da cabine; os planos sao os vidros — para-brisa, vigia e uma janela de
## cada lado —, com a normal para FORA. Vazio se a cabine nao tem casca.
func teto_da_chuva() -> Dictionary:
	if _casca.is_empty() or _paineis.is_empty():
		return {}
	var meia := float(_medidas.get("largura", 1.7)) * 0.5
	var z_a := float(_casca["z_frente"])
	var z_b := float(_casca["z_tras"])
	var caixa_min := Vector3(-meia, minf(_piso_real, _piso) - 0.05, minf(z_a, z_b))
	var caixa_max := Vector3(meia, _teto + 0.02, maxf(z_a, z_b))
	var planos := PackedVector4Array()
	var lados_vistos := {}
	for tipo: StringName in [&"parabrisa", &"vigia", &"porta_frente",
			&"quebra_vento", &"porta_tras", &"fixa_tras"]:
		for p: Dictionary in _paineis:
			if p["tipo"] != tipo:
				continue
			var n: Vector3 = p["normal"]
			var lateral := absf(n.x) > 0.5
			if lateral:
				# Uma janela por lado basta: os vidros de um lado sao quase
				# coplanares, e seis planos e o teto do shader.
				var lado := signf(n.x)
				if lados_vistos.has(lado):
					continue
				lados_vistos[lado] = true
			elif tipo != &"parabrisa" and tipo != &"vigia":
				continue
			planos.append(TetoChuva.plano(n, p["origem"]))
			if not lateral:
				break
	return {"min": caixa_min, "max": caixa_max, "planos": planos}


## O mapa de agua, para teste e para captura.
func mapa_agua() -> AguaVidro:
	return _agua


## Os limpadores, para a sonda do criterio C7.
func limpadores() -> Limpador:
	return _limpador


## O setor varrido e os rastros do ultimo quadro, para a sonda do criterio C6.
func setor_do_quadro() -> Dictionary:
	return _limpador.setor() if _limpador != null else {}


func trilhas_do_quadro() -> PackedVector4Array:
	return _trilhas


## Quantos vidros a cabine tem, e o referencial de cada um.
func paineis() -> Array:
	return _paineis


## O estilo em vigor e PS1 STYLE?
##
## Lido pelo caminho longo de proposito. Escrever `Settings.luz_por_pixel`
## impede esta classe INTEIRA de compilar em `--script`, onde nao ha autoload —
## e quando a cabine nao compila, o teste que a instancia nao quebra: ele
## devolve OK sem ter medido nada. Foi exatamente o que aconteceu na primeira
## rodada do criterio C7. Ver a memoria "teste de nivel 2 nao alcanca classe de
## tela".
static func _estilo_ps1() -> bool:
	var laco := Engine.get_main_loop() as SceneTree
	if laco == null or laco.root == null:
		return true
	var s := laco.root.get_node_or_null(^"Settings")
	if s == null:
		return true
	return not bool(s.get(&"luz_por_pixel"))


## Qual canal do mapa `--dbg-agua` pediu. Zero quando ninguem pediu.
static func _dbg_agua_da_linha() -> int:
	const CANAIS := {"mapa": 1, "cobertura": 2, "filme": 3, "embacado": 4,
		"sujeira": 5}
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--dbg-agua"):
			continue
		var nome := a.trim_prefix("--dbg-agua").trim_prefix("=")
		if nome == "":
			return 1
		if CANAIS.has(nome):
			return CANAIS[nome]
		push_warning("--dbg-agua: canal desconhecido '%s' (mapa, cobertura, filme, embacado, sujeira)" % nome)
	return 0


# --- volante ----------------------------------------------------------------

## O volante, num pivo proprio para poder girar.
##
## O aro sao dez caixas em volta de um circulo, e nao um toro: a 480x270 o
## contorno de dez lados e o contorno de trinta, e o toro custaria duzentos
## triangulos a mais no objeto que fica mais perto da camera na cena inteira.
func _montar_volante() -> void:
	_pivo_volante = Node3D.new()
	_pivo_volante.name = "Volante"
	_pivo_volante.position = Vector3(_lado, _piso + VOLANTE.y, VOLANTE.z)
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
	_ponteiro.position = Vector3(_lado, _piso + CLUSTER_ALTURA,
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

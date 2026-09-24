## O motorista da cena da estrada, visto do proprio banco.
##
## O que ha aqui
## -------------
## Tres coisas, e nenhuma delas e o corpo inteiro: a mao esquerda no aro do
## volante, a mao direita que sobe do colo com o celular no meio do plano de
## dentro, e o santinho pendurado no retrovisor balancando com a estrada. E o
## que uma pessoa sentada ao volante VE de si mesma e da cabine olhando para a
## frente — e e o que separa "camera presa num carro" de "alguem dirigindo".
##
## Por que nao e o `Corpo` inteiro sentado
## ---------------------------------------
## O rig de onze ossos ao volante mostraria coxa, joelho e barriga de caixa a
## dois palmos da lente, e o cabecalho de `abertura.gd` ja pagou para aprender
## que este boneco nao aguenta ser filmado tao de perto. Mao e antebraco sao a
## parte que aguenta — e a mesma que a primeira pessoa da cidade mostra na cena
## da bituca — e sao a unica parte que importa aqui: e nelas que estao o
## volante e o celular.
##
## A pele e a manga vem da ficha do jogador, como na mao da bituca: e a
## primeira vez que o jogo mostra um pedaco dele, e tem de ser ele.
##
## Onde mora
## ---------
## Filho da `CarroCabine`, no espaco do carro. Some junto com a cabine nos
## planos de fora (`CarroCena.mostrar_cabine`), que e o certo: de fora o
## motorista e um vulto atras do vidro, e vulto atras do vidro e trabalho da
## `Carroceria`, nao daqui.
class_name MotoristaCena
extends Node3D

## Onde a mao esquerda segura o aro, em graus a partir das tres horas, no
## sentido anti-horario: 150 e "dez horas", que e onde a mao esquerda de quem
## dirige relaxado fica.
##
## Era 150 ("dez horas"), e dali o antebraco subia pelo meio do quadro: a
## 35 cm da lente uma caixa de oito centimetros ocupa um setimo da largura da
## tela, e ela cruzava a janela da esquerda inteira. A "nove e vinte" o braco
## desce pela borda esquerda e a mao fica na altura do aro, que e onde o olho
## espera encontra-la sem ela virar assunto.
const MAO_NO_ARO_GRAUS := 172.0
## Tamanho da mao: largura (ao longo do aro), espessura (para o motorista) e
## comprimento (do no do dedo ao punho). Um pouco menor que a mao da bituca,
## que e filmada de proposito; esta e vista de esguelha.
const MAO := Vector3(0.076, 0.040, 0.092)
## Antebraco: grossura e comprimento, do punho ao cotovelo.
const ANTEBRACO_GROSSURA := 0.062
const ANTEBRACO := 0.27
## Para onde o cotovelo esquerdo cai, no espaco do carro, contado do OLHO do
## suporte: para a porta, bem para baixo e um pouco para tras. O olho da
## cutscene fica vinte centimetros atras do suporte
## (`AberturaEstrada.DENTRO_OLHO_RECUA`), entao o antebraco inteiro fica a
## frente da lente — com o cotovelo mais atras, a caixa do braco passava rente a
## lente e enchia meio quadro. Meio metro abaixo do olho e o cotovelo apoiado
## na perna, e o antebraco sai por baixo do quadro.
const COTOVELO_ESQ := Vector3(-0.24, -0.52, 0.06)
## A pegada do carro da cidade: "nove e quinze", as duas maos na altura do
## cubo.
##
## Era "oito e vinte" (212): a camera da cidade fica no olho do suporte, vinte
## centimetros mais perto do aro que a da cena da estrada, e com a mao de caixa
## na altura do cubo o antebraco enchia meia tela. Embaixo do aro so a mao
## aparecia, e mal. Com a `MaoModelada` a mao aguenta o primeiro plano: nas
## "nove e quinze" ela fica no terco de baixo do quadro olhando a rua (olhar
## -8), dorso para o motorista, e o antebraco sai pelos cantos de baixo.
##
## O cotovelo foi para fora (x -0,32, era -0,20) junto: com ele embaixo da mao o
## antebraco descia na vertical, dois pilares de pele na frente do painel; para
## fora ele vai em diagonal para o canto do quadro, como o braco de quem dirige
## com o cotovelo perto da porta.
const MAO_NA_CIDADE_GRAUS := 180.0
const COTOVELO_NA_CIDADE := Vector3(-0.32, -0.60, 0.12)

## O celular: onde a mao direita descansa com ele (fora do quadro, no colo) e
## onde ela para quando ele olha. Contados do olho do SUPORTE
## (`CarroCabine.olho`), nao do da cutscene, que fica vinte centimetros atras.
##
## A leitura e EM CIMA DO VOLANTE, na frente do cubo, e nao no colo. A primeira
## versao punha o aparelho baixo e a direita, e para alcanca-lo a cabeca descia
## quarenta e cinco graus: o quadro virava o console e o tapete, e a estrada
## sumia. Erguido na frente do cubo, o telefone TAPA a estrada — que e o gesto
## inteiro de quem escreve dirigindo, e o perigo do plano — e a cabeca so baixa
## uns doze graus. O aro passa em volta do aparelho sem encostar: o cubo esta
## em z -0,30 e o telefone dez centimetros mais perto do olho.
const CELULAR_NO_COLO := Vector3(0.30, -0.56, 0.20)
##
## Agora a vinte centimetros da lente e nao a trinta e seis: e NESTE aparelho
## que o jogador le a conversa (`TelaDoCelular`), e a tela tem de ocupar
## perto de metade da altura do quadro para as letras serem letras. Ainda na
## frente do cubo do volante, e baixo o bastante para a estrada aparecer por
## cima dele — e por cima dele que o padre aparece.
##
## E a dezenove centimetros, e nao a vinte e dois: a tres centimetros a mais a
## tela enchia so dois tercos do quadro na leitura e a conversa custava a ser
## lida.
const CELULAR_NA_LEITURA := Vector3(0.035, -0.085, 0.03)
## Quanto o celular sobe e desce, em segundos.
const CELULAR_SOBE := 0.55
const CELULAR_DESCE := 0.50

## O santinho: comprimento do cordao e tamanho da medalha.
const CORDAO := 0.11
const MEDALHA := Vector3(0.030, 0.040, 0.006)
## Amortecimento da oscilacao. Um cordao de nylon com uma medalha de lata quase
## nao amortece: balanca uns oito ciclos antes de parar.
const PENDULO_AMORTECE := 0.35
## Quanto do arfar e do rolar da carroceria chega ao ponto de pendura. O
## cordao esta preso ao carro, entao e a inclinacao do carro que o balanca
## quando a estrada nao tem curva.
const PENDULO_GANHO := 1.0

var _carro: CarroCena
var _olho := Vector3.ZERO
var _mao_direita: Node3D
var _celular: Node3D
var _pendulo: Node3D
## Angulos do pendulo (radianos) e velocidades: lateral (em X) e frontal (em Z).
var _sx: float = 0.09
var _sz: float = 0.0
var _vx: float = 0.0
var _vz: float = 0.0
var _tween_celular: Tween
var _celular_erguido: bool = false
## As maos no aro que tem antebraco a reapontar: esqueleto, pivo, indice do osso
## do antebraco, punho e eixo da montagem (no espaco do pivo) e o cotovelo (no
## espaco do carro).
var _bracos: Array[Dictionary] = []


## Monta as tres pecas dentro da cabine do carro dado. Chamar depois de o carro
## estar na arvore, porque a cabine so existe a partir do `_ready` dele.
func montar(carro: CarroCena) -> void:
	_carro = carro
	var cabine := carro.cabine
	if cabine == null:
		return
	_olho = cabine.olho()
	var ficha: Dictionary = RegistroCivil.jogador
	var aparencia: Dictionary = ficha.get("aparencia", {})
	var pele: Color = aparencia.get("pele", Color(0.78, 0.62, 0.50))
	# A mesma regra do `Corpo`, lida do mesmo lugar: regata nao tem manga, o
	# colete nao cobre o braco, e o resto como sempre foi.
	var cores := _cores_de(aparencia)
	var manga_longa: bool = cores["longa"]
	var manga: Color = cores["manga"]

	_montar_mao_esquerda(cabine, pele, manga if manga_longa else pele, manga_longa)
	_montar_mao_direita(cabine, pele, manga if manga_longa else pele, manga_longa)
	_montar_maos_do_susto(pele, manga if manga_longa else pele, manga_longa)
	_montar_pendulo(cabine)


## O motorista do carro da CIDADE: as duas maos no aro e o santinho
## (PLANO_CARROS_AAA, F11). Sem celular — quem dirige ali e o jogador, e a mao
## direita dele esta no volante, nao no colo.
##
## Chamado pela `CabineDoJogador`, que depois alimenta `atualizar` com a
## aceleracao e a inclinacao do corpo rigido: e o mesmo santinho da estrada,
## balancando com a freada e com a esquina da cidade.
func montar_na_cabine(cabine: CarroCabine) -> void:
	if cabine == null:
		return
	_olho = cabine.olho()
	var cores := _cores_do_jogador()
	var pele: Color = cores["pele"]
	var manga: Color = cores["manga"]
	var longa: bool = cores["longa"]
	# "Nove e quinze" (ver `MAO_NA_CIDADE_GRAUS`).
	_montar_mao_no_aro(cabine, MAO_NA_CIDADE_GRAUS, COTOVELO_NA_CIDADE, pele,
		manga, longa, "MaoEsquerda")
	_montar_mao_no_aro(cabine, 180.0 - MAO_NA_CIDADE_GRAUS,
		Vector3(-COTOVELO_NA_CIDADE.x, COTOVELO_NA_CIDADE.y, COTOVELO_NA_CIDADE.z),
		pele, manga, longa, "MaoDireita")
	_montar_pendulo(cabine)


## Pele e manga da ficha do jogador, com a regra do `Corpo`.
static func _cores_do_jogador() -> Dictionary:
	var ficha: Dictionary = RegistroCivil.jogador
	var aparencia: Dictionary = ficha.get("aparencia", {})
	return _cores_de(aparencia)


## Pele, manga e se a manga e comprida. Sem aparencia (ficha vazia) cai no
## cinza de sempre.
static func _cores_de(aparencia: Dictionary) -> Dictionary:
	var pele: Color = aparencia.get("pele", Color(0.78, 0.62, 0.50))
	if not aparencia.has("camisa_cor"):
		return {"pele": pele, "manga": Color(0.45, 0.47, 0.52), "longa": true}
	var longa := Aparencia.manga_longa(aparencia)
	return {"pele": pele, "manga": Aparencia.cor_da_manga(aparencia) if longa else pele,
		"longa": longa}


# --- mao esquerda, no volante -----------------------------------------------

## A mao no aro, pendurada no PIVO do volante: gira junto com a direcao, que e
## o que faz a mao parecer segurar o volante em vez de flutuar na frente dele.
func _montar_mao_esquerda(cabine: CarroCabine, pele: Color, manga: Color,
		manga_longa: bool) -> void:
	_montar_mao_no_aro(cabine, MAO_NO_ARO_GRAUS, COTOVELO_ESQ, pele, manga,
		manga_longa, "MaoEsquerda")


## Uma mao no aro, em `graus` a partir das tres horas, com o cotovelo caindo em
## `cotovelo_rel` (contado do olho do suporte, no lado do motorista).
##
## A mao e a `MaoModelada`: dedos de tres falanges fechados em volta do tubo,
## polegar pela face de ca, punho e antebraco. Era uma caixa de 7,6 cm com os
## dedos pintados, e na camera da cidade — vinte centimetros mais perto que a da
## estrada — a caixa era o que mais aparecia no quadro. Qual mao e sai do lado
## do aro: na metade da direita (cosseno positivo) e a direita.
##
## Dois ossos, num esqueleto pendurado no pivo. O da mao gira com o volante; o
## do antebraco gira no punho e, a cada quadro, volta a apontar para o cotovelo
## (ver `_process`). Com a malha inteira presa no pivo, o volante estercado
## levava o braco junto como ponteiro de relogio: com a mao nas "nove e quinze"
## e o volante no batente, o antebraco esquerdo atravessava o quadro na
## horizontal, na altura do aro.
func _montar_mao_no_aro(cabine: CarroCabine, graus: float, cotovelo_rel: Vector3,
		pele: Color, manga: Color, manga_longa: bool, nome: String) -> void:
	var pivo := cabine.pivo_do_volante()
	if pivo == null:
		return
	# O cotovelo esta no espaco do CARRO. O pivo esta inclinado, entao ele e
	# trazido para o espaco do pivo antes de o antebraco ser apontado.
	var lado := cabine.lado_do_motorista()
	var cotovelo_carro := Vector3(lado, _olho.y, _olho.z) + cotovelo_rel
	var cotovelo := pivo.transform.affine_inverse() * cotovelo_carro
	var no_aro := func(s: float) -> Transform3D:
		return _no_aro(graus + rad_to_deg(s / CarroCabine.VOLANTE_RAIO))
	var dados := PSXMesh.dados_com_ossos()
	var braco := MaoModelada.segurando(dados, no_aro, RAIO_DA_PEGADA,
		cos(deg_to_rad(graus)) > 0.0, cotovelo, pele, manga, manga_longa)
	_bracos.append(_pendurar_mao(pivo, dados, braco, nome, cotovelo_carro))


## O esqueleto de dois ossos com a malha da mao, pendurado no pivo. Devolve o
## que `_apontar_antebraco` precisa a cada quadro.
static func _pendurar_mao(pivo: Node3D, dados: Dictionary, braco: Dictionary,
		nome: String, cotovelo_carro: Vector3) -> Dictionary:
	var esqueleto := Skeleton3D.new()
	esqueleto.name = nome
	pivo.add_child(esqueleto)
	esqueleto.add_bone("mao")
	var antebraco := esqueleto.add_bone("antebraco")
	esqueleto.set_bone_rest(antebraco, Transform3D(Basis(), braco["punho"]))
	esqueleto.reset_bone_poses()
	var mi := _malha(dados, "Malha")
	# Pele de verdade, e nao a do povo de caixa: a mao no aro fica a dois
	# palmos da lente.
	mi.material_override = BracoVivo.material()
	esqueleto.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = esqueleto.create_skin_from_rest_transforms()
	return {"esqueleto": esqueleto, "pivo": pivo, "osso": antebraco,
		"punho": braco["punho"], "eixo": braco["eixo"], "cotovelo": cotovelo_carro}


func _process(delta: float) -> void:
	for b: Dictionary in _bracos:
		_apontar_antebraco(b)
	_animar_bracos(delta)
	_tremer_no_aro(delta)
	_segurar_o_celular(delta)


## Quanto do giro do volante o antebraco desfaz para voltar ao cotovelo. Um
## inteiro prendia o cotovelo no carro e, no batente (48 graus), o pulso da mao
## que sobe dobrava uns 60 graus: a mistura linear dos dois ossos esmagava o
## pulso num colarinho torcido. Com 0,7 o cotovelo acompanha um pouco a curva,
## como o de quem gira o volante sem trocar de mao.
const ANTEBRACO_SEGUE := 0.7


## O antebraco volta a apontar para o cotovelo, que fica parado no carro
## enquanto o pivo gira com a direcao. So a rotacao do osso: o comprimento do
## braco nao muda, e o pulso, pesado entre os dois ossos, dobra.
static func _apontar_antebraco(b: Dictionary) -> void:
	var esqueleto: Skeleton3D = b["esqueleto"]
	if not is_instance_valid(esqueleto) or not esqueleto.is_visible_in_tree():
		return
	var pivo: Node3D = b["pivo"]
	var punho: Vector3 = b["punho"]
	var para := pivo.transform.affine_inverse() * (b["cotovelo"] as Vector3) - punho
	if para.length_squared() < 1e-6:
		return
	var giro := Quaternion(b["eixo"] as Vector3, para.normalized())
	esqueleto.set_bone_pose_rotation(b["osso"],
		Quaternion.IDENTITY.slerp(giro, ANTEBRACO_SEGUE))


## Raio em que a mao fecha no aro. O tubo e uma caixa de secao quadrada
## (`CarroCabine.VOLANTE_TUBO`, 2,8 cm): a face fica a 1,4 cm do eixo e a quina a
## 2,0. Com 1,68 a polpa dos dedos encosta na face com um milimetro de folga e
## a quina entra quatro na carne do dedo, do lado de baixo, que a camera nao ve;
## no raio da quina a mao flutuava seis milimetros acima de cada face.
const RAIO_DA_PEGADA := 0.0168


## O eixo do tubo do aro em `graus`, com a base da pegada: x para fora do aro,
## y ao longo dele (anti-horario) e z para o motorista — x cruzado com y da z,
## como a `MaoModelada` exige.
##
## O aro da `CarroCabine` nao e um circulo: sao `VOLANTE_LADOS` caixas retas
## entre pontos do circulo, e no meio de cada uma o eixo do tubo passa
## R(1 - cos 18) = 9 mm para dentro. Nove milimetros sao meio dedo descolado do
## aro, entao a DISTANCIA segue o poligono. A DIRECAO segue o circulo: uma mao
## de oito centimetros sobre a quina entre duas caixas teria os dedos de um lado
## girados 36 graus contra os do outro, e o no de cada um sairia um centimetro
## fora da palma.
static func _no_aro(graus: float) -> Transform3D:
	var passo := TAU / float(CarroCabine.VOLANTE_LADOS)
	var a := wrapf(deg_to_rad(graus), 0.0, TAU)
	var meio := (floorf(a / passo) + 0.5) * passo
	var raio := CarroCabine.VOLANTE_RAIO * cos(passo * 0.5) / cos(a - meio)
	var fora := Vector3(cos(a), sin(a), 0.0)
	var tubo := Vector3(-sin(a), cos(a), 0.0)
	return Transform3D(Basis(fora, tubo, Vector3(0.0, 0.0, 1.0)), fora * raio)


# --- mao direita, com o celular ---------------------------------------------

func _montar_mao_direita(cabine: CarroCabine, pele: Color, manga: Color,
		manga_longa: bool) -> void:
	_mao_direita = Node3D.new()
	_mao_direita.name = "MaoDireita"
	add_child(_mao_direita)

	# O espaco do no: +Z aponta para o olho, +Y para cima. O telefone fica de pe
	# na origem com a tela em +Z. A mao que o segura e um `BracoVivo` refeito a
	# cada quadro em volta dele (ver `_segurar_o_celular`): era uma caixa de pele
	# atras do aparelho e outra de manga descendo, e a meio palmo da lente as
	# duas caixas eram o que mais aparecia debaixo da tela.
	_braco_leitura = BracoVivo.criar("BracoLeitura", _carona() > 0.0, pele, manga,
		manga_longa)
	add_child(_braco_leitura)

	_fone = Iphone4S.new()
	# A luz da tela nao acende o ar da cabine: com ela o volume de nevoa em
	# volta do aparelho virava um veu azul na frente da lente.
	if _fone.luz != null:
		_fone.luz.light_volumetric_fog_energy = 0.0
	_celular = _fone
	_mao_direita.add_child(_celular)
	# De pe, com o topo tombado vinte graus para longe do olho: o olho esta acima
	# do aparelho, e a tela tem de olhar para ele.
	_celular.position = Vector3.ZERO
	_celular.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)
	_giro_do_fone = _celular.basis
	_brilho_tela(0.0)

	_mao_direita.position = _olho + CELULAR_NO_COLO
	_apontar_para_o_olho(_mao_direita)
	_mao_direita.visible = false


## Como a mao segura o aparelho, no espaco dele (x para a direita da tela, y para
## cima, z saindo do vidro). A pegada de quem digita com uma mao so: a palma
## atras do aparelho e para a direita dele, os dedos deitados nas costas dele
## e dobrando na quina ESQUERDA — so as pontas aparecem na moldura —, e o
## polegar vindo pela quina direita para cima do vidro. A mao sai pela direita,
## embaixo, e o punho desce para o colo.
##
## A primeira versao fechava a mao num "tubo" na quina esquerda, como punho num
## cabo: os quatro dedos inteiros atravessavam a conversa pela frente.
##
## Medido na bancada (`bancada_braco_chao --varrer-leitura`): com a mao reta
## (dedos na horizontal) o polegar ficava fora do aparelho, espetado para cima;
## com a palma na diagonal o aparelho deita nela e o polegar alcanca o vidro.
const LEITURA_O := Vector3(0.004, -0.046, -0.0088)
const LEITURA_D := Vector3(-0.8, 0.6, 0.10)
const LEITURA_DORSO := Vector3(0.10, 0.0, -1.0)
## A mao viva: quanto o aparelho balanca na mao (m e graus), e a inercia dele
## com o carro (mola e amortecimento, em 1/s^2 e 1/s).
const BALANCO := 0.0032
const BALANCO_GRAUS := 1.1
const INERCIA_MOLA := 70.0
const INERCIA_AMORTECE := 9.0
const INERCIA_GANHO := 0.0022
## O polegar digitando: toques por segundo.
const TOQUES_HZ := 6.5
## O aparelho vibrando na mao: amplitude (m) e frequencia do motor.
const VIBRA_MAO := 0.0016
const VIBRA_HZ := 42.0

## A pegada da leitura de agora (as constantes acima; a bancada varre outras).
var leitura_o := LEITURA_O
var leitura_d := LEITURA_D
var leitura_dorso := LEITURA_DORSO
var leitura_pose: Dictionary = MaoPosada.pose(&"celular")
## 0 o polegar parado em cima do vidro, 1 digitando.
var digitando: float = 0.0
var _braco_leitura: BracoVivo
var _giro_do_fone := Basis()
var _inercia := Vector3.ZERO
var _inercia_v := Vector3.ZERO
var _acel := Vector3.ZERO
var _t_leitura: float = 0.0
var _vibra: float = 0.0


## A pegada da leitura, no espaco do aparelho.
func _pegada_de_leitura() -> Dictionary:
	var p := leitura_pose
	if digitando > 0.0:
		# O polegar desce e sobe, desencontrado: toque curto, volta devagar.
		var fase := fmod(_t_leitura * TOQUES_HZ, 1.0)
		var desce := pow(maxf(0.0, sin(fase * PI)), 3.0) * digitando
		p = MaoPosada.misturar(p, MaoPosada.pose(&"celular_toca"), desce)
	return BracoVivo.pega(leitura_o, leitura_d, leitura_dorso, p)


## O aparelho vibra na mao por `duracao` segundos.
func vibrar_na_mao(duracao: float = 0.35) -> void:
	_vibra = maxf(_vibra, duracao)


## A mao que segura o celular, viva: o aparelho balanca um nada na mao (quem
## segura um telefone nunca o segura parado), escorrega com a curva e a freada
## (`_inercia`, uma mola puxada pela aceleracao do carro), e a mao e o braco
## seguem o aparelho, refeitos em volta dele.
func _segurar_o_celular(delta: float) -> void:
	if _braco_leitura == null or _celular == null:
		return
	var na_mao := _mao_direita != null and _mao_direita.visible \
		and _celular.get_parent() == _mao_direita
	if not na_mao:
		_braco_leitura.visible = false
		return
	_t_leitura += delta
	var t := _t_leitura
	# A inercia: a aceleracao do carro empurra o aparelho para o lado contrario,
	# e a mao o traz de volta com uma mola amortecida.
	var dt := minf(delta, 1.0 / 30.0)
	var forca := -_acel * INERCIA_GANHO * INERCIA_MOLA
	_inercia_v += (forca - _inercia * INERCIA_MOLA - _inercia_v * INERCIA_AMORTECE) * dt
	_inercia += _inercia_v * dt
	_inercia = _inercia.limit_length(0.02)
	# O balanco da mao: tres ondas lentas desencontradas, e a respiracao.
	var b := Vector3(sin(t * 2.3) + 0.6 * sin(t * 0.83 + 1.1),
		sin(t * 1.9 + 0.7) + 0.5 * sin(t * 0.61 + 2.3) + 0.4 * sin(t * TAU * 0.23),
		sin(t * 1.4 + 2.0) * 0.5) * BALANCO * 0.6
	var g := Vector3(sin(t * 1.7 + 0.4), sin(t * 1.3 + 1.9), sin(t * 2.1 + 3.1)) \
		* deg_to_rad(BALANCO_GRAUS) * 0.6
	var vibra := Vector3.ZERO
	if _vibra > 0.0:
		_vibra -= delta
		var liga := 1.0 if fmod(_vibra, 0.18) > 0.05 else 0.35
		vibra = Vector3(sin(t * TAU * VIBRA_HZ), sin(t * TAU * VIBRA_HZ * 1.13 + 1.0), 0.0) \
			* VIBRA_MAO * liga
	_celular.position = b + vibra + _mao_direita.basis.inverse() * _inercia
	_celular.basis = _giro_do_fone * Basis.from_euler(g)
	var xf := _mao_direita.transform * _celular.transform
	_ombros()
	_braco_leitura.ombro = _ombro(true)
	_braco_leitura.polo = Vector3(_carona(), -0.9, 0.2)
	_braco_leitura.tremor = medo * 0.4
	_braco_leitura.pular(BracoVivo.levar(xf, _pegada_de_leitura()))
	_braco_leitura.visible = true
	_braco_leitura.passo(delta)


## Onde a camera da cutscene esta, no espaco do carro: o olho do suporte, vinte
## centimetros para tras (`AberturaEstrada.DENTRO_OLHO_RECUA`). A tela tem de
## olhar para ESTE ponto, e nao para o suporte: vinte centimetros a meio metro
## de distancia sao vinte graus de erro, e a tela sairia de esguelha.
const OLHO_DA_CENA := Vector3(0.0, 0.0, 0.20)


## Vira a mao — e o telefone nela — de frente para o olho, de pe.
func _apontar_para_o_olho(no: Node3D) -> void:
	var para := (_olho + OLHO_DA_CENA) - no.position
	if para.length_squared() < 0.0001:
		return
	no.basis = Basis.looking_at(para.normalized(), Vector3.UP, true)


## O celular sobe do colo ate a linha de leitura, ou volta.
##
## A tela acende ao subir e apaga ao descer. E a luz dela, verde no queixo e
## na manga, que conta que ele esta olhando o aparelho — sem ela o telefone e
## um retangulo preto na mao.
func mostrar_celular(erguer: bool) -> void:
	if _mao_direita == null or _celular_erguido == erguer:
		return
	_celular_erguido = erguer
	if _tween_celular != null and _tween_celular.is_valid():
		_tween_celular.kill()
	_mao_direita.visible = true
	var destino := _olho + (CELULAR_NA_LEITURA if erguer else CELULAR_NO_COLO)
	_tween_celular = create_tween().set_parallel(true)
	_tween_celular.set_ease(Tween.EASE_OUT if erguer else Tween.EASE_IN)
	_tween_celular.set_trans(Tween.TRANS_CUBIC)
	_tween_celular.tween_property(_mao_direita, "position", destino,
		CELULAR_SOBE if erguer else CELULAR_DESCE)
	_tween_celular.tween_method(func(_k: float) -> void:
		_apontar_para_o_olho(_mao_direita), 0.0, 1.0,
		CELULAR_SOBE if erguer else CELULAR_DESCE)
	if erguer:
		_tween_celular.tween_method(_brilho_tela, 0.0, 1.0, 0.25).set_delay(0.15)
	else:
		_tween_celular.tween_method(_brilho_tela, 1.0, 0.0, 0.3)
		_tween_celular.chain().tween_callback(func() -> void:
			_mao_direita.visible = false)


## Onde a tela do celular esta agora, em coordenada de mundo. E para onde a
## cabeca vira.
func ponto_do_celular() -> Vector3:
	if _celular == null:
		return global_position
	return _celular.global_position


## Um ponto da tela, em coordenada de mundo (`uv` como em
## `Iphone4S.ponto_da_tela`). E para onde a lente fecha na leitura.
func ponto_da_tela(uv: Vector2) -> Vector3:
	if _celular == null:
		return global_position
	return _celular.global_transform * Iphone4S.ponto_da_tela(uv)


func celular_erguido() -> bool:
	return _celular_erguido


# --- o celular no susto -----------------------------------------------------
## Onde o aparelho cai, medido do olho do motorista, no espaco da cabine. O
## banco do carona e o espelho do olho em x, uns sessenta centimetros abaixo; o
## assoalho do carona fica mais para a frente, debaixo do porta-luvas.
const BANCO_DO_CARONA := Vector3(0.0, -(OLHO_SOBRE_O_PISO - ASSENTO_TAMPO) + 0.006, 0.10)
## O olho fica 80 cm acima do assoalho (`CarroCabine.OLHO_DO_ASSOALHO`) e o tampo
## do assento a 29,5 (`CabineMoveis._banco`: caixa de 15 cm centrada a 22). O
## aparelho "no banco" ficava 58 cm abaixo do olho — sete centimetros dentro da
## espuma, na quina da frente — e a mao que ia busca-lo atravessava o assento.
const OLHO_SOBRE_O_PISO := 0.80
const ASSENTO_TAMPO := 0.295
## A borda da frente do assento, em z a partir do olho: o assento tem 48 cm e o
## centro dele fica 16 cm atras do olho.
const ASSENTO_FRENTE := -0.08
const ASSOALHO_FRENTE := -0.76
## Quanto para o lado do carona, em fracao do espelho do olho: 0,35 e o tapete
## junto do console, onde a cabeca dele alcanca debrucada.
const ASSOALHO_LADO := 0.95
## Quanto o aparelho caido tomba para tras, encostado na base do banco, em
## radianos a partir de em pe.
const ASSOALHO_TOMBO := 0.95
var _tween_susto: Tween


func _ponto_do_banco() -> Vector3:
	return Vector3(-_olho.x, _olho.y, _olho.z) + BANCO_DO_CARONA


func _ponto_do_assoalho() -> Vector3:
	var piso := _piso()
	return Vector3(-_olho.x * ASSOALHO_LADO, piso + 0.03, _olho.z + ASSOALHO_FRENTE)


## Tira o aparelho da mao e o poe solto na cabine, onde ele estava no mundo. A
## partir daqui o telefone e objeto, e nao parte da mao.
func _soltar_da_mao() -> void:
	if _celular == null or _celular.get_parent() == self:
		return
	var onde := _celular.global_transform
	_celular.get_parent().remove_child(_celular)
	add_child(_celular)
	_celular.global_transform = onde


## O golpe: a mao abre, o telefone voa e cai deitado no banco do carona, com a
## tela para cima. A mao some para baixo do quadro.
func arremessar_celular(duracao: float = 0.42) -> void:
	_soltar_da_mao()
	if _celular == null:
		return
	_celular_erguido = false
	if _tween_celular != null and _tween_celular.is_valid():
		_tween_celular.kill()
	var de := _celular.position
	var ate := _ponto_do_banco()
	var giro_de := _celular.rotation
	var giro_ate := Vector3(-PI * 0.5, 2.6, 0.0)
	_tween_susto = create_tween()
	_tween_susto.tween_method(func(k: float) -> void:
		# Arco: sobe um palmo no meio e cai. Com a curva o carro vira por
		# baixo dele, entao o arco basta para ler como objeto solto.
		var p := de.lerp(ate, k)
		p.y += sin(k * PI) * 0.12
		_celular.position = p
		_celular.rotation = giro_de.lerp(giro_ate, k), 0.0, 1.0, duracao) 		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# A mao sai de quadro no mesmo quadro: a direita foi para o volante. Uma
	# mao descendo na frente da lente no golpe tapava o padre.
	_mao_direita.visible = false
	if _braco_leitura != null:
		_braco_leitura.visible = false


## O telefone vibrando no banco: pula no lugar em dois pulsos curtos.
func vibrar_celular(duracao: float = 0.9) -> void:
	if _celular == null:
		return
	var base := _celular.position
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		var liga := 1.0 if fmod(k * duracao, 0.55) < 0.36 else 0.0
		var tremor := sin(k * duracao * TAU * 38.0) * 0.004 * liga
		_celular.position = base + Vector3(tremor, absf(tremor) * 0.5, tremor * 0.6),
		0.0, 1.0, duracao)
	t.tween_callback(func() -> void: _celular.position = base)
	# A tela acende com a mensagem chegando.
	_brilho_tela(1.0)


## A direita sai do colo e vai ao telefone no banco do carona, com o indicador
## na frente. A esquerda fica no aro: meio debrucado, o ombro esquerdo esta a
## setenta centimetros do assento do carona, e o braco (63) nao chegava — so
## esticado e torto. O apoio vem no chao (`seguir_ao_chao`), com o corpo todo
## para la. Devolve quando o dedo chega.
func alcancar_celular(duracao: float = 0.55) -> void:
	if _braco_d == null or _braco_e == null:
		return
	_ombros()
	_braco_d.pular(_pegada_no_colo())
	_braco_d.visible = true
	_braco_d.ir(_pegada_no_banco(1.0), duracao, Vector3(0.0, 0.12, 0.05), 0.4)
	_direita_em = &"banco"
	_braco_d.passo(0.0)
	await get_tree().create_timer(duracao).timeout


## A esquerda larga o aro e ESPALMA no assento do carona, e bate: e o apoio do
## corpo que vai ao chao. Chega em `duracao`, com o corpo ja descendo.
func apoiar_no_banco(duracao: float = 0.5) -> void:
	if _braco_e == null:
		return
	_ombros()
	var aro := _pegada_no_aro()
	mostrar_maos_no_volante(false)
	# A esquerda nasce exatamente onde a mao do aro estava: a troca nao se ve.
	_braco_e.pular(aro if not aro.is_empty() else _pegada_de_apoio())
	_braco_e.visible = true
	_esquerda_em = &"indo"
	# A mao chega de cima, espalmando, e bate no assento.
	_braco_e.ir(_pegada_de_apoio(), duracao, Vector3(0.0, 0.10, 0.04), 0.8)
	_braco_e.passo(0.0)
	await get_tree().create_timer(duracao).timeout
	_esquerda_em = &"apoio"
	_t_apoio = 0.0


## O dedo encosta na tela: o indicador desce ate o vidro, e volta.
func tocar_tela(duracao: float = 0.16) -> void:
	if _braco_d == null or not _braco_d.visible:
		return
	_braco_d.ir(_pegada_no_banco(0.0), duracao * 0.55)
	await get_tree().create_timer(duracao * 0.55).timeout
	_braco_d.ir(_pegada_no_banco(0.6), duracao * 0.45)
	await get_tree().create_timer(duracao * 0.45).timeout


## A direita vai atras do telefone que caiu, ate o chao do carona, e fica la
## esticada, a mao aberta a um palmo dele, puxando contra o cinto (`esforco`).
## A esquerda continua no assento: e ela que segura o corpo.
func seguir_ao_chao(duracao: float = 0.7) -> void:
	if _braco_d == null:
		return
	_direita_em = &"chao"
	_braco_d.visible = true
	_braco_d.ir(_pegada_no_chao(), duracao, Vector3(0.0, 0.07, 0.0), 0.6)
	# O apoio chega com o corpo ja la embaixo: antes o braco nao alcanca.
	get_tree().create_timer(duracao * 0.35).timeout.connect(func() -> void:
		apoiar_no_banco(duracao * 0.6))


## O ultimo empurrao: o braco de apoio empurra o assento, o corpo desce mais
## uns centimetros (quem manda na lente e a cena), e a mao alcanca o aparelho
## e fecha nele. Devolve com o telefone preso na mao.
func pegar_do_chao(duracao: float = 0.42) -> void:
	if _braco_d == null or _celular == null:
		return
	_direita_em = &"pegando"
	var pega := BracoVivo.levar(_fone_no_carro(), _pegada_de_pegar())
	# Chega aberta e fecha no fim: a pose de pegar so no ultimo terco.
	var chegando := pega.duplicate()
	chegando["pose"] = MaoPosada.misturar(MaoPosada.pose(&"estica"), pega["pose"], 0.35)
	chegando["o"] = (pega["o"] as Vector3) + Vector3.UP * 0.012
	_braco_d.ir(chegando, duracao * 0.62)
	await get_tree().create_timer(duracao * 0.62).timeout
	_braco_d.ir(pega, duracao * 0.38)
	await get_tree().create_timer(duracao * 0.38).timeout
	# Preso: dali em diante o aparelho vai onde a mao vai.
	_pega_no_fone = _pegada_de_pegar()
	_direita_em = &"segurando"


## O telefone sobe do chao ate a leitura, na mao, girando nela ate a pegada de
## quem vai ler: a palma sai de cima do vidro para tras do aparelho, e o polegar
## chega por cima. A esquerda larga o assento e sai de quadro.
func erguer_celular(duracao: float = 1.1) -> void:
	if _celular == null or _braco_d == null:
		return
	if _direita_em != &"segurando":
		_pega_no_fone = _pegada_de_pegar()
	_direita_em = &"erguendo"
	var de := _fone_no_carro()
	var ate := _fone_na_leitura()
	var pega_de := _pega_no_fone
	var pega_ate := _pegada_de_leitura()
	_esquerda_em = &"solta"
	if _braco_e != null and _braco_e.visible:
		_braco_e.ir(_pegada_no_colo_esquerdo(), duracao * 0.7, Vector3(0.0, 0.05, 0.0), 0.3)
	var q_de := de.basis.get_rotation_quaternion()
	var q_ate := ate.basis.get_rotation_quaternion()
	var t := 0.0
	while t < duracao:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / duracao, 0.0, 1.0)
		# O aparelho sobe na pinca ate a frente do rosto (ate `TROCA_DE_PEGADA`)
		# e so entao a mao o ajeita. Sai do chao depressa e freia chegando.
		var sobe := clampf(k / TROCA_DE_PEGADA, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - sobe, 2.6)
		var giro := smoothstep(0.1, 1.0, sobe)
		var p := de.origin.lerp(ate.origin, e)
		# O arco: sobe por dentro, rente ao console, e nao em linha reta
		# atravessando o painel.
		p += Vector3(-_carona() * 0.06, 0.05, 0.08) * sin(e * PI)
		var xf := Transform3D(Basis(q_de.slerp(q_ate, giro)), p)
		_celular.transform = xf
		# A troca: da pinca no alto do aparelho para a palma atras dele. A mao
		# passa POR TRAS (as costas do aparelho, -z), e nao por dentro dele: a
		# mistura reta das duas pegadas atravessava o vidro no meio do caminho.
		var troca := smoothstep(TROCA_DE_PEGADA - 0.05, 1.0, k)
		var pega := BracoVivo._misturar(pega_de, pega_ate, troca)
		pega["o"] = (pega["o"] as Vector3) + Vector3(0.0, 0.0, -TROCA_POR_TRAS) * sin(troca * PI)
		_pega_no_fone = pega
	_direita_em = &"segurando"
	# Chegou: o aparelho volta para a mao da leitura, no mesmo lugar e na mesma
	# pegada — a troca de braco nao se ve.
	_celular.get_parent().remove_child(_celular)
	_mao_direita.add_child(_celular)
	_mao_direita.position = _olho + CELULAR_NA_LEITURA
	_apontar_para_o_olho(_mao_direita)
	_celular.transform = Transform3D(_giro_do_fone, Vector3.ZERO)
	_mao_direita.visible = true
	_celular_erguido = true
	_direita_em = &""
	_braco_d.visible = false
	if _braco_e != null:
		_braco_e.visible = false
	_esquerda_em = &""
	_brilho_tela(1.0)


## O aparelho na leitura, no espaco do carro.
func _fone_na_leitura() -> Transform3D:
	var pos := _olho + CELULAR_NA_LEITURA
	var base := Basis.looking_at(((_olho + OLHO_DA_CENA) - pos).normalized(), Vector3.UP, true)
	return Transform3D(base, pos) * Transform3D(_giro_do_fone, Vector3.ZERO)


## O aparelho, onde esteja, no espaco do carro.
func _fone_no_carro() -> Transform3D:
	if _celular == null:
		return Transform3D()
	return global_transform.affine_inverse() * _celular.global_transform


## Os bracos do susto somem (a lente foi para a janela).
func soltar_bracos() -> void:
	_direita_em = &""
	_esquerda_em = &""
	for b: BracoVivo in [_braco_d, _braco_e]:
		if b != null:
			b.visible = false


## Onde a mao direita esta agora (global), para a lente.
func ponto_da_mao_direita() -> Vector3:
	if _braco_d == null or not _braco_d.visible or _braco_d.pegada.is_empty():
		return ponto_do_celular()
	return global_transform * (_braco_d.pegada["o"] as Vector3)


## O telefone escorrega do banco para o assoalho, com a tela para cima e acesa.
## A mao recua pela metade: o cinto segura o corpo.
func derrubar_celular(duracao: float = 0.38) -> void:
	if _celular == null:
		return
	var de := _celular.position
	var ate := _ponto_do_assoalho()
	# Para de pe contra a base do banco, a tela inclinada para o motorista: e
	# assim que ele a ve do banco dele. Deitado rente ao tapete a tela era um
	# risco de raspao e nada se lia.
	var para_olho := (_olho + OLHO_DA_CENA) - ate
	para_olho.y = 0.0
	var q_de := _celular.basis.get_rotation_quaternion()
	var q_ate := (Basis.looking_at(para_olho.normalized(), Vector3.UP, true)
		* Basis(Vector3.RIGHT, -ASSOALHO_TOMBO)).get_rotation_quaternion()
	ate.y += Iphone4S.TAMANHO.y * 0.5 * cos(ASSOALHO_TOMBO)
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		var p := de.lerp(ate, k)
		# Quica uma vez no tapete.
		p.y += absf(sin(k * PI * 1.6)) * 0.05 * (1.0 - k)
		_celular.position = p
		_celular.basis = Basis(q_de.slerp(q_ate, k)), 0.0, 1.0, duracao) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_brilho_tela(1.0)


## Mostra ou esconde as maos no volante. No salto da lente sobre o padre, com
## o campo a 26 graus, a mao no aro vira uma bola do tamanho do quadro.
func mostrar_maos_no_volante(visivel: bool) -> void:
	for b: Dictionary in _bracos:
		var e: Node3D = b.get("esqueleto")
		if e != null and is_instance_valid(e):
			e.visible = visivel


# --- os bracos do susto -------------------------------------------------------
## O tronco. Gira em volta do quadril para onde a cabeca foi (`debruca_olho`) e
## torce para o carona; os ombros vao com ele. Com o ombro so empurrado junto
## com a cabeca (a primeira versao), debrucado o ombro esquerdo ia parar do
## lado do carona e o braco de apoio chegava ao banco pelo lado errado, virado
## do avesso.
##
## Contados da lente (o olho da cena), com x para o carona.
const QUADRIL := Vector3(0.0, -0.45, 0.10)
const OMBRO_D := Vector3(0.19, -0.27, 0.12)
const OMBRO_E := Vector3(-0.19, -0.27, 0.12)
const TORCE_GRAUS := 24.0
## Debrucado de todo (o `DEBRUCA` da cena, em x): para medir quanto o tronco
## ja torceu.
const DEBRUCA_TODO := 0.42
## A mao de apoio no assento do carona: quanto para dentro do meio do assento
## (para o console), quanto atras da borda da frente, e quanto afunda na
## espuma — e quanto mais afunda empurrando (`apoio_forca`).
const APOIO_DENTRO := 0.15
const APOIO_RECUO := 0.075
const APOIO_AFUNDA := 0.008
const APOIO_EMPURRA := 0.014
## O quique da mao batendo no assento: quanto afunda e em quanto tempo volta.
const APOIO_QUIQUE := 0.018
const APOIO_QUIQUE_T := 0.22
## Onde a direita descansa, no colo, contado da lente: fora de quadro.
const MAO_NO_COLO := Vector3(0.27, -0.62, -0.02)
const MAO_E_NO_COLO := Vector3(-0.22, -0.64, -0.05)
## O dedo sobre a tela no banco: onde no vidro (o ENVIAR) e quanto ele fica
## acima dele antes de encostar.
const ENVIAR_UV := Vector2(0.86, 0.66)
const DEDO_ACIMA := 0.035
## O chao: onde a palma para antes do telefone (o cinto segura ali), os puxoes
## contra o cinto e a mao agarrando o ar.
const FALTA_NO_CHAO := 0.13
const PUXAO_HZ := 1.35
const PUXAO := 0.035
const AGARRA_HZ := 1.05
## A mao pegando o aparelho caido, no espaco dele: uma pinca pela borda da
## DIREITA (o lado de onde o braco vem) — a palma em cima da quina, os dedos
## descendo pelas costas, o polegar no vidro. E como se pega um telefone de pe
## encostado no banco.
##
## A primeira versao espalmava por cima do vidro, e os dedos dobravam para
## dentro do aparelho antes de chegar na borda; a segunda pegava pela borda de
## CIMA, a mais longe da lente, e o antebraco atravessava o aparelho inteiro
## rente a ela — meio quadro de braco. Pela direita o braco fica no canto.
## Os nos ficam 25 milimetros atras do meio do aparelho (o do minimo fica um
## centimetro mais para a frente que o do indicador) e o dorso
## exatamente de lado: os dedos correm retos pelas costas, com dois milimetros
## de folga (medido: `bancada_braco_chao`, `[sonda]`). Com o dorso inclinado ou
## a dobra passando de 90 graus, as pontas voltavam para a frente e
## atravessavam o aparelho.
const PEGA_CHAO_O := Vector3(Iphone4S.TAMANHO.x * 0.5 + 0.011, 0.012, -0.025)
const PEGA_CHAO_D := Vector3(0.0, 0.0, -1.0)
const PEGA_CHAO_DORSO := Vector3(1.0, 0.0, 0.0)
## Quando (fracao do erguer) a mao troca a pinca pela pegada de leitura, e
## quanto ela recua para tras do aparelho no meio da troca (m).
const TROCA_DE_PEGADA := 0.72
const TROCA_POR_TRAS := 0.045

## O quanto a lente saiu do lugar agora (no espaco do suporte, x para o carona).
## A cena escreve a cada quadro; os ombros vao junto.
var debruca_olho := Vector3.ZERO
## 0 parado, 1 fazendo forca: os puxoes, o tremor, a mao agarrando o ar.
var esforco: float = 0.0
## 0 a mao de apoio so encostada, 1 empurrando o assento com o peso do corpo.
var apoio_forca: float = 0.0
## Medo, de 0 a 1: as maos tremem.
var medo: float = 0.0
var _braco_d: BracoVivo
var _braco_e: BracoVivo
## O que a direita esta fazendo: nada, no banco, no chao, pegando, segurando o
## aparelho ou erguendo-o.
var _direita_em: StringName = &""
## E a esquerda: indo, no apoio, ou soltando.
var _esquerda_em: StringName = &""
var _t_bracos: float = 0.0
var _t_apoio: float = 1.0
## A mao no aparelho, no espaco dele, enquanto ela o segura.
var _pega_no_fone: Dictionary = {}


## Os dois bracos do susto, vazios e escondidos: sao refeitos a cada quadro
## enquanto aparecem (ver `BracoVivo`).
func _montar_maos_do_susto(pele: Color, manga: Color, manga_longa: bool) -> void:
	var carona := _carona()
	_braco_d = BracoVivo.criar("BracoDireito", carona > 0.0, pele, manga, manga_longa)
	_braco_e = BracoVivo.criar("BracoEsquerdo", carona < 0.0, pele, manga, manga_longa)
	add_child(_braco_d)
	add_child(_braco_e)


func _carona() -> float:
	return -signf(_olho.x) if absf(_olho.x) > 0.01 else 1.0


func _piso() -> float:
	if _carro != null and _carro.cabine != null:
		return _carro.cabine.piso_da_cabine()
	return _olho.y - OLHO_SOBRE_O_PISO


var _giro_tronco := Basis()
var _olho_agora := Vector3.ZERO


## O tronco e a lente de agora, com a cabeca onde a cena a pos.
func _ombros() -> void:
	var carona := _carona()
	var olho0 := _olho + OLHO_DA_CENA
	var deb := Vector3(debruca_olho.x * carona, debruca_olho.y, debruca_olho.z)
	_olho_agora = olho0 + deb
	var quadril := olho0 + QUADRIL
	var a := (olho0 - quadril).normalized()
	var b := (_olho_agora - quadril).normalized()
	var giro := Quaternion.IDENTITY
	if a.dot(b) < 0.99999:
		giro = Quaternion(a, b)
	var k := clampf(absf(debruca_olho.x) / DEBRUCA_TODO, 0.0, 1.0)
	var torce := Quaternion(Vector3.UP, -deg_to_rad(TORCE_GRAUS) * k * carona)
	_giro_tronco = Basis(giro * torce)
	if _braco_d != null:
		_braco_d.ombro = _ombro(true)
		# O cotovelo para fora e para tras, alto: o braco que atravessa a cabine
		# passa por cima do console. Com ele caido (-0,8 em y) o antebraco
		# atravessava a manopla do cambio.
		_braco_d.polo = _giro_tronco * Vector3(carona * 0.6, 0.25, 0.9)
	if _braco_e != null:
		_braco_e.ombro = _ombro(false)
		# No apoio o cotovelo vai para tras e para fora, como numa flexao.
		_braco_e.polo = _giro_tronco * Vector3(-carona * 0.7, -0.3, 0.9)


func _ombro(direito: bool) -> Vector3:
	var carona := _carona()
	var o := OMBRO_D if direito else OMBRO_E
	return _olho_agora + _giro_tronco * Vector3(o.x * carona, o.y, o.z)


func _animar_bracos(delta: float) -> void:
	if _braco_d == null or not (_braco_d.visible or _braco_e.visible):
		return
	_t_bracos += delta
	_t_apoio += delta
	_ombros()
	match _direita_em:
		&"chao":
			_braco_d.alvo(_pegada_no_chao())
		&"segurando", &"erguendo":
			if _celular != null and not _pega_no_fone.is_empty():
				_braco_d.pular(BracoVivo.levar(_fone_no_carro(), _pega_no_fone))
	if _esquerda_em == &"apoio":
		_braco_e.alvo(_pegada_de_apoio())
	_abafar_luz_no_braco()
	_braco_d.tremor = 0.35 + esforco + medo * 0.3
	_braco_e.tremor = 0.25 + esforco * 0.4 + apoio_forca * 0.5
	for b: BracoVivo in [_braco_d, _braco_e]:
		if b.visible:
			b.passo(delta)


## A luz da tela nos bracos cai quando o antebraco ou o braco passa a poucos
## centimetros dela: a um palmo ela e a luz de quem olha o celular; a dois dedos
## ela estourava a manga num borrao branco, subindo o aparelho do chao.
const ABAFA_PERTO := 0.02
const ABAFA_LONGE := 0.15
const ABAFA_MINIMO := 0.08
const ABAFA_RAIO := 0.045


func _abafar_luz_no_braco() -> void:
	if _fone == null or _fone.luz_da_mao == null or _braco_d == null or not _braco_d.visible:
		if _fone != null:
			_fone.abafar_mao(1.0)
		return
	var luz := global_transform.affine_inverse() * _fone.luz_da_mao.global_position
	var d := minf(_ate_segmento(luz, _braco_d.punho_montado, _braco_d.cotovelo_montado),
		_ate_segmento(luz, _braco_d.cotovelo_montado, _braco_d.ombro))
	# Conta da pele (ou do pano), e nao do eixo: a manga tem quatro centimetros e
	# meio de raio.
	d -= ABAFA_RAIO
	_fone.abafar_mao(lerpf(ABAFA_MINIMO, 1.0, smoothstep(ABAFA_PERTO, ABAFA_LONGE, d)))


static func _ate_segmento(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## As maos no aro, vivas: escorregam um nada no aro, e tremem com o medo.
func _tremer_no_aro(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for b: Dictionary in _bracos:
		var e: Node3D = b.get("esqueleto")
		if e == null or not is_instance_valid(e) or not e.visible:
			continue
		var fase := float(b.get("osso", 0)) * 1.7 + e.get_instance_id() % 7
		var escorrega := sin(t * 0.37 + fase) * 0.012
		var treme := (sin(t * 61.0 + fase) + 0.6 * sin(t * 43.0 + fase * 2.0)) * 0.006 * medo
		e.rotation.z = escorrega + treme


## A mao esquerda no aro, do jeito que a mao do volante esta agora: a mesma
## palma e o punho fechado no tubo.
func _pegada_no_aro() -> Dictionary:
	if _carro == null or _carro.cabine == null or _carro.cabine.pivo_do_volante() == null:
		return {}
	var pivo := _carro.cabine.pivo_do_volante()
	var xf := pivo.transform * _no_aro(MAO_NO_ARO_GRAUS)
	var giro := deg_to_rad(MaoModelada.GIRO)
	var fora := xf.basis.x.normalized()
	var perto := xf.basis.z.normalized()
	var d := fora * sin(giro) - perto * cos(giro)
	var dorso := fora * cos(giro) + perto * sin(giro)
	var o := xf.origin + d * MaoModelada.AVANCO + dorso * (RAIO_DA_PEGADA - 0.002)
	return BracoVivo.pega(o, d, dorso, &"punho")


## A esquerda espalmada no assento do carona, junto do console: os dedos para
## a frente e para fora, a palma na espuma. Bate e quica; empurrando, afunda.
func _pegada_de_apoio() -> Dictionary:
	var carona := _carona()
	var quique := 0.0
	if _t_apoio < APOIO_QUIQUE_T:
		var k := _t_apoio / APOIO_QUIQUE_T
		quique = sin(k * PI) * (1.0 - k) * APOIO_QUIQUE
	var o := Vector3(-_olho.x - carona * APOIO_DENTRO,
		_piso() + ASSENTO_TAMPO - APOIO_AFUNDA - APOIO_EMPURRA * apoio_forca - quique,
		_olho.z + ASSENTO_FRENTE + APOIO_RECUO)
	var d := Vector3(carona * 0.5, -0.04, -1.0)
	var p := MaoPosada.misturar(MaoPosada.pose(&"apoio"), MaoPosada.pose(&"apoio_forca"),
		apoio_forca)
	return BracoVivo.pega(o, d, Vector3.UP, p)


## A direita no colo, meio fechada.
func _pegada_no_colo() -> Dictionary:
	var carona := _carona()
	var c := _olho + OLHO_DA_CENA + Vector3(MAO_NO_COLO.x * carona, MAO_NO_COLO.y, MAO_NO_COLO.z)
	return BracoVivo.pega(c, Vector3(0.0, -0.3, -1.0), Vector3(carona * 0.3, 1.0, 0.0),
		&"relaxada")


## A esquerda voltando para a coxa, fora de quadro.
func _pegada_no_colo_esquerdo() -> Dictionary:
	var carona := _carona()
	var c := _olho + OLHO_DA_CENA + Vector3(MAO_E_NO_COLO.x * carona, MAO_E_NO_COLO.y,
		MAO_E_NO_COLO.z)
	return BracoVivo.pega(c, Vector3(0.0, -0.3, -1.0), Vector3(-carona * 0.3, 1.0, 0.0),
		&"relaxada")


## A direita sobre o telefone deitado no banco, o indicador apontado para o
## ENVIAR: `acima` 1 e o dedo a `DEDO_ACIMA` do vidro, 0 encostando.
func _pegada_no_banco(acima: float) -> Dictionary:
	var carona := _carona()
	var fone := _fone_no_carro()
	var alvo := fone * Iphone4S.ponto_da_tela(ENVIAR_UV)
	var n := fone.basis.z.normalized()
	# O dedo vem do ombro, inclinado para o vidro.
	var vem := alvo - _ombro(true)
	vem = (vem - n * vem.dot(n)).normalized()
	var d := (vem * cos(deg_to_rad(38.0)) - n * sin(deg_to_rad(38.0))).normalized()
	var dorso := (n - d * n.dot(d)).normalized()
	var lado := MaoPosada.lado(d, dorso, carona > 0.0)
	# A ponta do indicador fica no alvo: o no dele esta a `s` para o polegar e a
	# um dedo e meio de comprido.
	var o := alvo - lado * 0.030 - d * 0.086 - dorso * 0.004 + n * (0.004 + DEDO_ACIMA * acima)
	return BracoVivo.pega(o, d, dorso, &"aponta")


## A direita esticada atras do telefone caido: a mao aberta a um palmo dele,
## mais alta que ele, e — fazendo forca — abrindo e fechando em garra no ar e
## puxando contra o cinto.
func _pegada_no_chao() -> Dictionary:
	var fone := _fone_no_carro()
	var pega := BracoVivo.levar(fone, _pegada_de_pegar())
	var o: Vector3 = pega["o"]
	var vem := o - _ombro(true)
	vem.y = 0.0
	vem = vem.normalized()
	var t := _t_bracos
	var agarra := 0.5 + 0.5 * sin(t * TAU * AGARRA_HZ + 0.8)
	var puxa := (0.5 + 0.5 * sin(t * TAU * PUXAO_HZ)) * PUXAO * esforco
	pega["o"] = o - vem * (FALTA_NO_CHAO - puxa) + Vector3.UP * (0.035 + 0.02 * agarra * esforco)
	# A mao estica, e com forca agarra o ar: da mao esticada para a garra.
	var p := MaoPosada.misturar(MaoPosada.pose(&"estica"), MaoPosada.pose(&"garra"),
		agarra * agarra * esforco * 0.85)
	pega["pose"] = p
	# Esticada, a mao aponta mais para o aparelho que a pinca.
	var d: Vector3 = pega["d"]
	pega["d"] = (d + vem * 0.5).normalized()
	var dorso: Vector3 = pega["dorso"]
	pega["dorso"] = (dorso - (pega["d"] as Vector3) * dorso.dot(pega["d"])).normalized()
	return pega


## A pegada no aparelho caido, no espaco dele.
func _pegada_de_pegar() -> Dictionary:
	return BracoVivo.pega(PEGA_CHAO_O, PEGA_CHAO_D, PEGA_CHAO_DORSO, &"pinca")


# --- o aparelho -------------------------------------------------------------
## O aparelho e o `Iphone4S`: o telefone de vidro da viagem, e nao o de barra do
## `Adereco` (o do jogo, de 1998). E NELE que o jogador le a desculpa sendo
## apagada.
var _fone: Iphone4S
var _tela: TelaDoCelular


## Liga a tela do aparelho a um app de Mensagens: dali em diante o que o app
## desenha aparece no vidro, ao vivo.
func ligar_tela(app: AppMensagens) -> TelaDoCelular:
	if _tela != null and is_instance_valid(_tela):
		_tela.queue_free()
	_tela = TelaDoCelular.new(app)
	add_child(_tela)
	if _fone != null:
		_fone.ligar(_tela.textura())
	return _tela


func tela() -> TelaDoCelular:
	return _tela


## 0 apagada (vidro preto), 1 acesa.
func _brilho_tela(k: float) -> void:
	if _fone != null:
		_fone.brilho(k)


func esconder_mao_direita() -> void:
	if _mao_direita != null:
		_mao_direita.visible = false


# --- o santinho -------------------------------------------------------------

## Uma medalha num cordao, pendurada no retrovisor. E o objeto que mais diz
## "estrada de terra" dentro de um carro do interior, e e o unico da cabine que
## se mexe SOZINHO: balanca com a curva, com a lombada e com a freada, e nunca
## para de vez.
func _montar_pendulo(cabine: CarroCabine) -> void:
	var espelho := cabine.ponto_do_espelho()
	if espelho == Vector3.ZERO:
		return
	_pendulo = Node3D.new()
	_pendulo.name = "Santinho"
	# Pendurado na borda de baixo do espelho, um pouco para o lado do motorista.
	_pendulo.position = espelho + Vector3(-0.06, -0.045, 0.0)
	add_child(_pendulo)

	var dados := PSXMesh.dados_vazios()
	var cel := Adereco.UV_PAPEL
	# O cordao: um fio de tres milimetros, do ponto de pendura ate a medalha.
	_caixa_uv(dados, Vector3(0.003, CORDAO, 0.003),
		Transform3D(Basis(), Vector3(0.0, -CORDAO * 0.5, 0.0)), cel,
		Color(0.55, 0.50, 0.38))
	# A medalha: um retangulo vermelho-escuro com a borda dourada por tras, que
	# e o que uma estampa de santo vira a um metro de distancia.
	_caixa_uv(dados, MEDALHA + Vector3(0.006, 0.006, -0.002),
		Transform3D(Basis(), Vector3(0.0, -CORDAO - MEDALHA.y * 0.5, -0.002)), cel,
		Color(0.72, 0.58, 0.22))
	_caixa_uv(dados, MEDALHA,
		Transform3D(Basis(), Vector3(0.0, -CORDAO - MEDALHA.y * 0.5, 0.0)), cel,
		Color(0.48, 0.10, 0.10))
	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(Adereco.MATERIAL_CIGARRO) as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pendulo.add_child(mi)


## Um quadro do santinho. `acel` e a aceleracao do carro no espaco dele, em
## m/s^2; `inclinacao` e (arfar, rolar) da carroceria, em radianos.
##
## Pendulo de verdade, integrado: gravidade puxa para o prumo, a aceleracao do
## carro empurra para o lado contrario, e a inclinacao do carro desloca o prumo
## — o ponto de pendura vai junto com o teto. Duas coordenadas independentes
## (lateral e frontal) porque o balanco de curva e o de freada sao movimentos
## diferentes, e um pendulo de um eixo so faria os dois no mesmo plano.
func atualizar(acel: Vector3, inclinacao: Vector2, delta: float) -> void:
	_acel = acel
	if _pendulo == null or delta <= 0.0:
		return
	var dt := minf(delta, 1.0 / 30.0)
	const G := 9.8
	# Lateral (X): a curva. A carroceria rola para fora, e a gravidade vista de
	# dentro do carro ganha uma componente lateral igual ao seno do rolar.
	var ax := acel.x + G * sin(inclinacao.y) * PENDULO_GANHO
	var ax_total := -(G / CORDAO) * sin(_sx) - (ax / CORDAO) * cos(_sx) \
		- PENDULO_AMORTECE * _vx
	_vx += ax_total * dt
	_sx += _vx * dt
	# Frontal (Z): freada e arfar. -Z e a frente do carro; freando, a
	# aceleracao e +Z e a medalha vai para a frente.
	var az := acel.z + G * sin(inclinacao.x) * PENDULO_GANHO
	var az_total := -(G / CORDAO) * sin(_sz) - (az / CORDAO) * cos(_sz) \
		- PENDULO_AMORTECE * _vz
	_vz += az_total * dt
	_sz += _vz * dt
	_sx = clampf(_sx, -1.2, 1.2)
	_sz = clampf(_sz, -1.2, 1.2)
	# O cordao pende do ponto de pendura: girar o no em Z leva a medalha para
	# X, girar em X leva para Z.
	_pendulo.rotation = Vector3(_sz, 0.0, -_sx)


# --- malha ------------------------------------------------------------------

## Uma caixa tingida, com a celula do atlas dada nas seis faces.
static func _caixa(dados: Dictionary, tamanho: Vector3, onde: Transform3D,
		celula: Rect2, cor: Color) -> void:
	var d := PSXMesh.box_dados(tamanho, 100.0, 100.0, Color.WHITE)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = celula.position + Vector2(clampf(uvs[k].x, 0.0, 1.0),
			clampf(uvs[k].y, 0.0, 1.0)) * celula.size
	d["uv"] = uvs
	PSXMesh.acumular_tingido(dados, d, onde, cor)


## O mesmo, com um retalho de UV absoluto (o retalho opaco do atlas da casa,
## para o que nao e pele nem pano).
static func _caixa_uv(dados: Dictionary, tamanho: Vector3, onde: Transform3D,
		retalho: Rect2, cor: Color) -> void:
	_caixa(dados, tamanho, onde, retalho, cor)


static func _malha(dados: Dictionary, nome: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(Corpo.MATERIAL) as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


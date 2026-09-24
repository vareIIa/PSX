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
## Para onde o cotovelo esquerdo cai, no espaco do carro, contado da PEGADA no
## aro: quase na altura da mao, 29 cm para tras e um pouco para a porta — o
## antebraco de quem dirige com o banco perto, correndo para tras por baixo do
## quadro.
##
## Era contado do olho e ficava meio metro abaixo dele, 40 cm embaixo da mao.
## Com o aro inclinado 30 graus, "embaixo" nas nove horas e ao longo do tubo: o
## antebraco saia da mao pelo lado do minimo, 82 graus de pulso dobrado de lado
## (o maximo de gente e uns 30), e a mao lia torcida no volante. Da lente da
## cena (vinte centimetros atras do suporte) o cotovelo aqui fica 58 graus abaixo
## do olhar: o antebraco entra pelo canto de baixo e nao atravessa o quadro.
const COTOVELO_ESQ := Vector3(-0.08, 0.0, 0.29)
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
## O cotovelo, contado da pegada como o `COTOVELO_ESQ`: um pouco mais baixo e
## mais para fora, que e o braco de quem dirige com o cotovelo perto da porta.
## Contado do olho (0,6 m abaixo dele) o pulso dobrava 80 graus de lado.
const MAO_NA_CIDADE_GRAUS := 180.0
const COTOVELO_NA_CIDADE := Vector3(-0.10, -0.03, 0.28)

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
## A mao direita no aro (do golpe ao banco), e se ela esta la agora.
var _aro_direito: Dictionary = {}
var _direita_no_aro: bool = false
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
	_montar_mao_direita_no_aro(cabine, pele, manga if manga_longa else pele, manga_longa)
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


## A direita tambem vai ao aro — no golpe. O celular voa da mao e ela agarra o
## volante na guinada: com uma mao so no aro, a batida parecia de quem nao se
## assustou. Escondida ate la (ela esta segurando o telefone).
func _montar_mao_direita_no_aro(cabine: CarroCabine, pele: Color, manga: Color,
		manga_longa: bool) -> void:
	var antes := _bracos.size()
	_montar_mao_no_aro(cabine, 180.0 - MAO_NO_ARO_GRAUS,
		Vector3(absf(COTOVELO_ESQ.x) * _carona(), COTOVELO_ESQ.y, COTOVELO_ESQ.z), pele,
		manga, manga_longa, "MaoDireitaNoAro")
	if _bracos.size() > antes:
		_aro_direito = _bracos[_bracos.size() - 1]
		(_aro_direito["esqueleto"] as Node3D).visible = false


## Uma mao no aro, em `graus` a partir das tres horas, com o cotovelo caindo em
## `cotovelo_rel` (contado da pegada, no espaco do carro).
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
	var cotovelo_carro := pivo.transform * _no_aro(graus).origin + cotovelo_rel
	var cotovelo := pivo.transform.affine_inverse() * cotovelo_carro
	var no_aro := func(s: float) -> Transform3D:
		return _no_aro(graus + rad_to_deg(s / CarroCabine.VOLANTE_RAIO))
	var direita := cos(deg_to_rad(graus)) > 0.0
	var pegada := pegada_para_o_cotovelo(_no_aro(graus), cotovelo, direita)
	var dados := PSXMesh.dados_com_ossos()
	var braco := MaoModelada.segurando(dados, no_aro, RAIO_DA_PEGADA, direita,
		cotovelo, pele, manga, manga_longa, pegada.x, pegada.y)
	var b := _pendurar_mao(pivo, dados, braco, nome, cotovelo_carro)
	b["graus"] = graus
	b["giro"] = pegada.x
	b["obliquo"] = pegada.y
	_bracos.append(b)
	if OS.is_debug_build():
		print("[motorista] %s a %.0f graus: giro %.1f, palma obliqua %.1f, pulso dobra %.1f de lado" % [
			nome, graus, pegada.x, pegada.y, pegada.z])


## Como a mao pega o aro para o pulso ficar reto na direcao do cotovelo:
## (giro em volta do tubo, obliquidade da palma, o que sobra para o pulso
## dobrar de lado), em graus.
##
## O giro fixo de 55 graus virava o dorso para a lente, e com ele o PUNHO
## apontava para o cubo do volante: o antebraco saia da mao para dentro do aro
## e dobrava de volta ate o cotovelo, na porta — um gancho, a mao torcida como
## a de quem segura o volante pelo lado errado. A mao de quem dirige tem o pulso
## quase reto: o giro poe o punho no plano do cotovelo, e o que o cotovelo tem
## AO LONGO do tubo a palma absorve cruzando o aro na diagonal
## (`MaoModelada.obliquar`), ate `OBLIQUO_MAX`. O resto o pulso dobra.
static func pegada_para_o_cotovelo(no_aro: Transform3D, cotovelo: Vector3,
		direita: bool) -> Vector3:
	var e := cotovelo - no_aro.origin
	var ef := e.dot(no_aro.basis.x.normalized())
	var ep := e.dot(no_aro.basis.z.normalized())
	var giro := clampf(rad_to_deg(atan2(-ef, ep)), GIRO_MIN, GIRO_MAX)
	# O lado do polegar ao longo do tubo; o cotovelo para o lado do minimo e o
	# desvio positivo.
	var lado := no_aro.basis.y.normalized() * (1.0 if direita else -1.0)
	var desvio := rad_to_deg(atan2(-e.dot(lado), Vector2(ef, ep).length()))
	var obliquo := clampf(desvio, -OBLIQUO_MAX * 0.5, OBLIQUO_MAX)
	return Vector3(giro, obliquo, desvio - obliquo)


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
		"punho": braco["punho"], "eixo": braco["eixo"], "cotovelo": cotovelo_carro,
		"punho_carro": pivo.transform * (braco["punho"] as Vector3)}


func _process(delta: float) -> void:
	for b: Dictionary in _bracos:
		_apontar_antebraco(b)
	_animar_bracos(delta)
	_tremer_no_aro(delta)
	_segurar_o_celular(delta)
	_encostar_pele()


## Quanto a tela acesa clareia a polpa que esta a um dedo dela.
const TELA_NA_PELE := 0.35


## A pele das maos sabe onde o aparelho esta: escurece onde encosta nele e pega
## a luz da tela de perto (ver `BracoVivo.encostar_no_fone`). Sem isso a mao e
## o telefone eram duas pecas iluminadas cada uma por si, e o aparelho parecia
## colado por cima dos dedos.
func _encostar_pele() -> void:
	if _fone == null or not is_instance_valid(_fone) or not _fone.is_inside_tree():
		return
	BracoVivo.encostar_no_fone(_fone.global_transform, 1.0,
		Iphone4S.LUZ_COR * _fone._brilho * TELA_NA_PELE)


## Quanto do giro do volante o antebraco desfaz para voltar ao cotovelo. Um
## inteiro prendia o cotovelo no carro e, no batente (48 graus), o pulso da mao
## que sobe dobrava uns 60 graus: a mistura linear dos dois ossos esmagava o
## pulso num colarinho torcido. Com 0,7 o cotovelo acompanha um pouco a curva,
## como o de quem gira o volante sem trocar de mao.
const ANTEBRACO_SEGUE := 0.7
## Quanto do caminho do punho o cotovelo acompanha quando o volante gira (ver
## `_apontar_antebraco`).
const COTOVELO_SEGUE := 0.6


## O antebraco volta a apontar para o cotovelo, que fica parado no carro
## enquanto o pivo gira com a direcao. So a rotacao do osso: o comprimento do
## braco nao muda, e o pulso, pesado entre os dois ossos, dobra.
##
## O cotovelo nao fica parado: ele anda `COTOVELO_SEGUE` do que o punho andou
## no carro. Com o cotovelo a um antebraco da mao, a mao que sobe para as onze
## horas no batente mudava a direcao dele em 40 graus, e o pulso parado no carro
## dobrava num gancho — o braco de gente sobe junto, girando no ombro.
static func _apontar_antebraco(b: Dictionary) -> void:
	var esqueleto: Skeleton3D = b["esqueleto"]
	if not is_instance_valid(esqueleto) or not esqueleto.is_visible_in_tree():
		return
	var pivo: Node3D = b["pivo"]
	var punho: Vector3 = b["punho"]
	var cotovelo: Vector3 = b["cotovelo"]
	if b.has("punho_carro"):
		cotovelo += (pivo.transform * punho - (b["punho_carro"] as Vector3)) * COTOVELO_SEGUE
	var para := pivo.transform.affine_inverse() * cotovelo - punho
	if para.length_squared() < 1e-6:
		return
	var giro := Quaternion(b["eixo"] as Vector3, para.normalized())
	esqueleto.set_bone_pose_rotation(b["osso"],
		Quaternion.IDENTITY.slerp(giro, ANTEBRACO_SEGUE))


## Raio em que a mao fecha no aro. O aro e redondo (`VolanteEsportivo.TUBO`,
## 1,55 cm): 1,3 mm alem dele a polpa dos dedos encosta na camurca, e a face da
## palma (dois milimetros aquem, ver `MaoModelada.segurando`) afunda meio
## milimetro nela, que e o aperto de quem segura.
const RAIO_DA_PEGADA := VolanteEsportivo.TUBO + 0.0013
## Ate onde o giro da mao no aro vai (ver `giro_para_o_cotovelo`). Abaixo de
## -20 o dorso vira para o painel e a lente ve so a polpa dos dedos por dentro
## do aro; acima de 40 o punho ja aponta para o cubo.
const GIRO_MIN := -20.0
const GIRO_MAX := 40.0
## Quanto o aro pode cruzar a palma na diagonal. Numa pegada de martelo o cabo
## corre uns vinte graus fora do travessao da mao; mais que isso os nos do
## indicador e do minimo ficam um centimetro e meio fora da volta do tubo.
const OBLIQUO_MAX := 20.0


## O eixo do tubo do aro em `graus`, com a base da pegada: x para fora do aro,
## y ao longo dele (anti-horario) e z para o motorista — x cruzado com y da z,
## como a `MaoModelada` exige. O aro e um circulo (`VolanteEsportivo`).
static func _no_aro(graus: float) -> Transform3D:
	var a := deg_to_rad(graus)
	var fora := Vector3(cos(a), sin(a), 0.0)
	var tubo := Vector3(-sin(a), cos(a), 0.0)
	return Transform3D(Basis(fora, tubo, Vector3(0.0, 0.0, 1.0)),
		fora * CarroCabine.VOLANTE_RAIO)


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
## cima, z saindo do vidro). A pegada de quem digita com uma mao so, achada pelo
## `AjusteDaMao` a partir de `metas_da_leitura` (`bancada_celular_na_mao
## --resolver`): as pontas do indicador, do medio e do anelar na lateral
## esquerda, o minimo de prateleira embaixo, a eminencia do polegar na quina
## direita, e o polegar solto sobre o vidro.
##
## A primeira versao fechava a mao num "tubo" na quina esquerda, como punho num
## cabo: os quatro dedos inteiros atravessavam a conversa pela frente. A segunda
## tinha os angulos escritos a mao, olhando a foto de frente: de lado nenhum
## dedo encostava no aparelho, o indicador saia espetado para fora, e as pontas
## que apareciam na moldura estavam soltas na frente do vidro — o telefone
## boiava entre os dedos.
##
## Medido na bancada: as quatro polpas a menos de 2 mm de onde deviam, e um
## vertice da mao a 0,7 mm dentro do aparelho (eram 10, ate 4 mm).
const LEITURA_O := Vector3(0.0008, -0.0351, -0.0071)
const LEITURA_D := Vector3(-0.7523, 0.6528, 0.0885)
const LEITURA_DORSO := Vector3(-0.0772, 0.0461, -0.9960)
const LEITURA_POSE := {"dedos": [[-7.45, 42.63, 47.24, -18.0], [-1.91, 88.79, 64.58, -18.0],
	[3.5, 98.21, 66.23, -17.44], [23.69, 96.33, 65.65, -14.39]],
	"polegar": [2.57, 29.7, -68.6, -15.0, 53.6]}
## A mao viva: quanto o aparelho balanca na mao (m e graus), e a inercia dele
## com o carro (mola e amortecimento, em 1/s^2 e 1/s).
const BALANCO := 0.0032
const BALANCO_GRAUS := 1.1
const INERCIA_MOLA := 70.0
const INERCIA_AMORTECE := 9.0
const INERCIA_GANHO := 0.0022
## O tremor do medo, no aparelho E na mao juntos (m): tremer so a mao a fazia
## escorregar no aparelho, que ficava parado entre os dedos.
const TREMOR_NA_MAO := 0.0011
## O aparelho vibrando na mao: amplitude (m) e frequencia do motor.
const VIBRA_MAO := 0.0016
const VIBRA_HZ := 42.0

## O polegar. Onde ele descansa quando nao digita: sobre o vidro, no canto do
## teclado, a um centimetro dele — o polegar de quem le com o telefone na mao
## fica pairando, pronto.
##
## Descansa para dentro da tela, e nao no canto: a cada toque no apagar ele
## recolhe ate a quina, que e o gesto de quem apaga — com o repouso ja perto da
## tecla o polegar mal se mexia e a digitacao nao se via.
const REPOUSO_UV := Vector2(0.60, 0.78)
## O repouso depois de apagar tudo: no canto de baixo do teclado, fora do
## campo vazio.
const REPOUSO_DEPOIS_UV := Vector2(0.80, 0.95)
const REPOUSO_ALTURA := 0.012
## Quanto ele sobe entre um toque e outro (m). A 6,5 mm, na lente da cena, o
## toque era um tremor.
const TECLA_ACIMA := 0.011
## A tecla de apagar: a ultima da terceira fileira do teclado do `AppMensagens`
## (x 125,5 a 144 de 146; y 192 a 203 de 219).
const APAGAR_UV := Vector2(0.923, 0.904)
## O toque (s): chegar sobre a tecla, descer, ficar, subir. Desce depressa e
## sobe mais devagar — o dedo cai no vidro e se descola dele.
const TOQUE_VAI := 0.11
const TOQUE_DESCE := 0.055
const TOQUE_FICA := 0.05
const TOQUE_SOBE := 0.10
## Parado este tempo depois do ultimo toque, o polegar volta ao repouso.
const TOQUE_DESCANSA := 0.45
## Quanto o aparelho cede na mao quando o polegar aperta: o vidro vai para
## tras e gira em volta da mao (m e graus). E o que diz que ha forca ali.
const TOQUE_CEDE := 0.0007
const TOQUE_CEDE_GRAUS := 0.6

## O polegar encostou na tecla `uv` (e o app apaga), e soltou.
signal tecla_encostou(uv: Vector2)
signal tecla_soltou(uv: Vector2)

## Onde cada dedo ENCOSTA no aparelho na leitura (espaco dele): o que o
## `AjusteDaMao` persegue para achar a pegada. As pontas do indicador, do medio
## e do anelar na lateral esquerda, a unha para fora — de frente, so a ponta
## deles aparece na moldura, e atras dela; o minimo por baixo da base, de
## prateleira; a primeira falange do medio e do anelar deitada nas costas; o
## polegar pela direita, com a eminencia dele na quina, e a polpa sobre o vidro.
static func metas_da_leitura(polegar_em: Vector3) -> Array:
	var m := Iphone4S.TAMANHO * 0.5
	# A polpa na quina da frente, dobrando por cima dela: de frente a ponta do
	# dedo pisa na moldura preta. Com a polpa no meio da lateral as pontas
	# ficavam ao lado do aparelho, sem tocar nada que se visse.
	#
	# E na metade de baixo, na altura do teclado: com o medio no meio da
	# lateral a ponta dele tapava os baloes da conversa.
	var quina := Vector3(-0.85, 0.0, 0.5)
	var unha := Vector3(-0.75, 0.0, 0.65)
	var z := m.z * 0.4
	return [
		{"tipo": &"polpa", "dedo": 0, "p": Vector3(-m.x, 0.004, z), "face": quina,
			"n": unha, "peso_n": 0.4},
		{"tipo": &"polpa", "dedo": 1, "p": Vector3(-m.x, -0.016, z), "face": quina,
			"n": unha, "peso_n": 0.4},
		{"tipo": &"polpa", "dedo": 2, "p": Vector3(-m.x, -0.035, z), "face": quina,
			"n": unha, "peso_n": 0.4},
		{"tipo": &"polpa", "dedo": 3, "p": Vector3(-0.010, -m.y, -0.001),
			"face": Vector3(0.0, -1.0, 0.0), "n": Vector3(-0.3, -1.0, 0.0), "peso": 0.7,
			"peso_n": 0.3},
		{"tipo": &"encosta", "dedo": 0, "falange": 0, "t": 0.6, "peso": 0.4},
		{"tipo": &"encosta", "dedo": 1, "falange": 0, "t": 0.6, "peso": 0.4},
		{"tipo": &"encosta", "dedo": 2, "falange": 0, "t": 0.6, "peso": 0.4},
		{"tipo": &"encosta", "dedo": 4, "falange": 0, "t": 0.55, "peso": 0.5},
		{"tipo": &"polpa", "dedo": 4, "p": polegar_em, "n": Vector3(0.25, 0.0, 1.0),
			"peso_n": 0.5},
		{"tipo": &"rumo", "d": Vector3(-0.3, 0.6, -0.7), "peso": 0.2},
	]


## A pegada da leitura de agora (as constantes acima; a bancada varre outras).
var leitura_o := LEITURA_O
var leitura_d := LEITURA_D
var leitura_dorso := LEITURA_DORSO
var leitura_pose: Dictionary = LEITURA_POSE
var _braco_leitura: BracoVivo
var _giro_do_fone := Basis()
var _inercia := Vector3.ZERO
var _inercia_v := Vector3.ZERO
var _acel := Vector3.ZERO
var _t_leitura: float = 0.0
var _vibra: float = 0.0
## O polegar: os cinco angulos de agora, a ida entre dois (com a curva), e as
## solucoes ja achadas por lugar do vidro.
var _pol_agora: Array = []
var _pol_de: Array = []
var _pol_para: Array = []
var _pol_k: float = 1.0
var _pol_dur: float = 0.1
var _pol_curva: int = 0
var _pol_cache := {}
## Os toques pedidos ({uv, segura}), o de agora e a fase dele.
var _fila_toques: Array = []
var _toque_fase: StringName = &""
var _toque_uv := Vector2.ZERO
var _toque_t: float = 0.0
var _toque_segura: bool = false
var _segurando: bool = false
var _em_repouso: bool = true
var _cede: float = 0.0
var _cede_alvo: float = 0.0
var _repouso_uv := REPOUSO_UV


## A pegada da leitura, no espaco do aparelho: os dedos parados onde encostam,
## e o polegar onde a digitacao o levou.
func _pegada_de_leitura() -> Dictionary:
	var pol: Array = _pol_agora if not _pol_agora.is_empty() else leitura_pose["polegar"]
	return BracoVivo.pega(leitura_o, leitura_d, leitura_dorso,
		{"dedos": leitura_pose["dedos"], "polegar": pol})


## Onde a polpa do polegar descansa, no espaco do aparelho.
static func polegar_de_repouso() -> Vector3:
	return Iphone4S.ponto_da_tela(REPOUSO_UV) + Vector3(0.0, 0.0, REPOUSO_ALTURA)


## Esquece as solucoes do polegar (a pegada mudou).
func esquecer_polegar() -> void:
	_pol_cache.clear()
	_pol_agora = []


## Os angulos do polegar com a polpa a `altura` do vidro sobre `uv`: um ajuste
## so do polegar, com o resto da mao parado na pegada da leitura. Guardado.
func _polegar_em(uv: Vector2, altura: float, de: Array = []) -> Array:
	var chave := "%.3f,%.3f,%.4f" % [uv.x, uv.y, altura]
	if _pol_cache.has(chave):
		return _pol_cache[chave]
	var alvo := Iphone4S.ponto_da_tela(uv) + Vector3(0.0, 0.0, altura)
	var aj := AjusteDaMao.new(Iphone4S.TAMANHO * 0.5, Iphone4S.RAIO_CANTO, _carona() > 0.0)
	aj.metas = [{"tipo": &"polpa", "dedo": 4, "p": alvo, "n": Vector3(0.25, 0.0, 1.0),
		"peso_n": 0.5}]
	aj.so_polegar()
	var pose := {"dedos": leitura_pose["dedos"],
		"polegar": de if not de.is_empty() else leitura_pose["polegar"]}
	var p := aj.resolver({"o": leitura_o, "d": leitura_d, "dorso": leitura_dorso,
		"pose": pose}, 30)
	var pol: Array = p["pose"]["polegar"]
	_pol_cache[chave] = pol
	return pol


## O polegar da um toque na tecla `uv` (e volta a pairar).
func teclar(uv: Vector2) -> void:
	_fila_toques.append({"uv": uv, "segura": false})


## O polegar desce na tecla `uv` e fica apertando ate `soltar_tecla`.
func segurar_tecla(uv: Vector2) -> void:
	_segurando = true
	_fila_toques.append({"uv": uv, "segura": true})


func soltar_tecla() -> void:
	_segurando = false


## Troca onde o polegar paira quando nao digita (uv da tela). Depois de apagar
## tudo ele desce para o canto do teclado: pairando no repouso de sempre a
## polpa ficava bem em cima do campo vazio.
func repousar_em(uv: Vector2) -> void:
	_repouso_uv = uv
	if _em_repouso and polegar_livre() and not _pol_agora.is_empty():
		_ir_polegar(_polegar_em(uv, REPOUSO_ALTURA), 0.3, 0)


## O polegar esta parado (sem toque pedido nem em curso).
func polegar_livre() -> bool:
	return _fila_toques.is_empty() and _toque_fase == &""


## O polegar voltou a pairar no repouso, fora das teclas.
func polegar_em_repouso() -> bool:
	return polegar_livre() and _em_repouso and _pol_k >= 1.0


func _ir_polegar(para: Array, dur: float, curva: int) -> void:
	_pol_de = _pol_agora.duplicate()
	_pol_para = para
	_pol_k = 0.0
	_pol_dur = maxf(dur, 0.01)
	_pol_curva = curva


## A digitacao, um quadro: o polegar anda entre as solucoes do ajuste (pairar
## sobre a tecla, encostar nela) e avisa quando encosta e quando solta.
func _animar_polegar(delta: float) -> void:
	if _pol_agora.is_empty():
		_pol_agora = _polegar_em(REPOUSO_UV, REPOUSO_ALTURA)
		_pol_para = _pol_agora
		_pol_k = 1.0
		_em_repouso = true
	if _pol_k < 1.0:
		_pol_k = minf(1.0, _pol_k + delta / _pol_dur)
		var k := _pol_k
		match _pol_curva:
			1: k = k * k
			2: k = 1.0 - (1.0 - k) * (1.0 - k)
			_: k = k * k * (3.0 - 2.0 * k)
		var mix := []
		for j in 5:
			mix.append(lerpf(float(_pol_de[j]), float(_pol_para[j]), k))
		_pol_agora = mix
	_toque_t += delta
	var chegou := _pol_k >= 1.0
	match _toque_fase:
		&"":
			if not _fila_toques.is_empty():
				var t: Dictionary = _fila_toques.pop_front()
				_toque_uv = t["uv"]
				_toque_segura = t["segura"]
				_em_repouso = false
				_ir_polegar(_polegar_em(_toque_uv, TECLA_ACIMA), TOQUE_VAI, 0)
				_toque_fase = &"vai"
			elif not _em_repouso and _toque_t > TOQUE_DESCANSA:
				_em_repouso = true
				_ir_polegar(_polegar_em(_repouso_uv, REPOUSO_ALTURA), 0.3, 0)
		&"vai":
			if chegou:
				_ir_polegar(_polegar_em(_toque_uv, 0.0, _pol_agora), TOQUE_DESCE, 1)
				_toque_fase = &"desce"
		&"desce":
			if chegou:
				tecla_encostou.emit(_toque_uv)
				_cede_alvo = 1.0
				_toque_t = 0.0
				_toque_fase = &"segura" if _toque_segura else &"fica"
		&"fica", &"segura":
			var solta := _toque_t >= TOQUE_FICA if _toque_fase == &"fica" else not _segurando
			if solta:
				tecla_soltou.emit(_toque_uv)
				_cede_alvo = 0.0
				_ir_polegar(_polegar_em(_toque_uv, TECLA_ACIMA), TOQUE_SOBE, 2)
				_toque_fase = &"sobe"
		&"sobe":
			if chegou:
				_toque_fase = &""
				_toque_t = 0.0
	# O aparelho cede depressa e volta devagar.
	_cede = move_toward(_cede, _cede_alvo, delta * (30.0 if _cede_alvo > _cede else 9.0))


## O aparelho vibra na mao por `duracao` segundos.
func vibrar_na_mao(duracao: float = 0.35) -> void:
	_vibra = maxf(_vibra, duracao)


## A mao que segura o celular, viva: o aparelho balanca um nada na mao (quem
## segura um telefone nunca o segura parado), escorrega com a curva e a freada
## (`_inercia`, uma mola puxada pela aceleracao do carro), treme com o medo e
## cede quando o polegar aperta — e a mao e o braco vao com ele, refeitos em
## volta dele. Os dedos nao mexem sozinhos: estao encostados no aparelho, e dedo
## que se mexe em cima de uma coisa segurada parece que a solta.
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
	_animar_polegar(delta)
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
	# O medo, na mao inteira: o aparelho treme com ela.
	b += Vector3(sin(t * 83.0) + 0.5 * sin(t * 37.0), sin(t * 71.0 + 1.3) + 0.5 * sin(t * 29.0),
		sin(t * 97.0 + 2.1) * 0.5) * TREMOR_NA_MAO * medo
	var vibra := Vector3.ZERO
	if _vibra > 0.0:
		_vibra -= delta
		var liga := 1.0 if fmod(_vibra, 0.18) > 0.05 else 0.35
		vibra = Vector3(sin(t * TAU * VIBRA_HZ), sin(t * TAU * VIBRA_HZ * 1.13 + 1.0), 0.0) \
			* VIBRA_MAO * liga
	# O polegar empurra o vidro: o aparelho vai para tras e gira em volta da
	# mao, pelo lado da tecla.
	var cede := Vector3.ZERO
	var giro_cede := Basis()
	if _cede > 0.001:
		var ponto := Iphone4S.ponto_da_tela(_toque_uv)
		cede = Vector3(0.0, 0.0, -TOQUE_CEDE * _cede)
		var eixo := Vector3(-ponto.y, ponto.x, 0.0)
		if eixo.length_squared() > 1e-8:
			giro_cede = Basis(eixo.normalized(), deg_to_rad(TOQUE_CEDE_GRAUS) * _cede)
	_celular.position = b + vibra + _mao_direita.basis.inverse() * _inercia \
		+ _giro_do_fone * cede
	_celular.basis = _giro_do_fone * Basis.from_euler(g) * giro_cede
	var xf := _mao_direita.transform * _celular.transform
	_ombros()
	_braco_leitura.ombro = _ombro(true)
	_braco_leitura.polo = Vector3(_carona(), -0.9, 0.2)
	_braco_leitura.tremor = 0.0
	_braco_leitura.dedos_vivos = 0.0
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
	# A mao sai de quadro no mesmo quadro: a direita foi para o volante (e
	# aparece nele quando a lente volta do padre). Uma mao descendo na frente da
	# lente no golpe tapava o padre.
	_mao_direita.visible = false
	if _braco_leitura != null:
		_braco_leitura.visible = false
	_direita_no_aro = not _aro_direito.is_empty()


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


## A direita larga o aro e vai atras do telefone que a batida jogou no chao do
## carona; a esquerda espalma no assento dele no caminho (`seguir_ao_chao`).
## Devolve quando a mao chega la embaixo.
func alcancar_no_chao(duracao: float = 0.85) -> void:
	if _braco_d == null or _braco_e == null:
		return
	_ombros()
	_cotovelo_baixo = 0.0
	# Sai do aro, se estava nele: a mao do volante some e o braco vivo nasce
	# onde ela estava.
	var de := _pegada_no_colo()
	var desce := 0.0
	if _direita_no_aro:
		var aro := _pegada_no_aro(180.0 - MAO_NO_ARO_GRAUS)
		if not aro.is_empty():
			de = aro
			desce = duracao * 0.35
		_direita_no_aro = false
		(_aro_direito["esqueleto"] as Node3D).visible = false
	_braco_d.pular(de)
	_braco_d.visible = true
	_braco_d.passo(0.0)
	# Do aro a mao DESCE primeiro, rente ao corpo, ate o colo, e so de la vai
	# ao chao por baixo do painel. Direto do aro para o chao, o braco de cima
	# subia na frente da lente, que ja olhava para baixo: o quadro virava
	# manga (medido na rajada, aos 19,5 s).
	if desce > 0.0:
		_braco_d.ir(_pegada_no_colo(), desce, Vector3(0.0, -0.06, 0.08), 0.2)
		await get_tree().create_timer(desce).timeout
	seguir_ao_chao(duracao - desce, Vector3(0.0, -0.04, 0.03))
	await get_tree().create_timer(duracao - desce).timeout


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


## A direita vai atras do telefone que caiu, ate o chao do carona, e fica la
## esticada, a mao aberta a um palmo dele, puxando contra o cinto (`esforco`).
## A esquerda continua no assento: e ela que segura o corpo.
func seguir_ao_chao(duracao: float = 0.7, arco := Vector3(0.0, 0.07, 0.0)) -> void:
	if _braco_d == null:
		return
	_direita_em = &"chao"
	_braco_d.visible = true
	_braco_d.ir(_pegada_no_chao(), duracao, arco, 0.6)
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
	var pega_de := _pega_no_fone
	var pega_ate := _pegada_de_leitura()
	_esquerda_em = &"solta"
	if _braco_e != null and _braco_e.visible:
		_braco_e.ir(_pegada_no_colo_esquerdo(), duracao * 0.7, Vector3(0.0, 0.05, 0.0), 0.3)
	var q_de := de.basis.get_rotation_quaternion()
	var t := 0.0
	lente_ao_braco_min = INF
	while t < duracao:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / duracao, 0.0, 1.0)
		_cotovelo_baixo = smoothstep(0.0, 0.55, k)
		# A leitura e contada da lente de AGORA, que sobe junto: com ela fixa no
		# carro o caminho do chao ate o rosto passava exatamente onde a cabeca
		# debrucada estava, e o quadro virava braco.
		_ombros()
		var ate := _fone_na_leitura(_olho_agora)
		var q_ate := ate.basis.get_rotation_quaternion()
		if _braco_d.visible:
			lente_ao_braco_min = minf(lente_ao_braco_min, minf(
				_ate_segmento(_olho_agora, _braco_d.punho_montado, _braco_d.cotovelo_montado),
				_ate_segmento(_olho_agora, _braco_d.cotovelo_montado, _braco_d.ombro)))
		# Sai do chao depressa e freia chegando; o aparelho vira na mao para a
		# lente no caminho.
		var e := 1.0 - pow(1.0 - k, 2.6)
		var giro := smoothstep(0.1, 0.9, k)
		var p := de.origin.lerp(ate.origin, e)
		# O arco: sobe por dentro, rente ao console, e nao em linha reta
		# atravessando o painel.
		# Sem vir para a lente: com oito centimetros para o motorista no meio do
		# caminho o aparelho e a mao passavam rente ao rosto.
		p += Vector3(-_carona() * 0.06, 0.05, 0.0) * sin(e * PI)
		var xf := Transform3D(Basis(q_de.slerp(q_ate, giro)), p)
		_celular.transform = xf
		# A troca: da pinca no alto do aparelho para a palma atras dele. A mao
		# passa POR TRAS (as costas do aparelho, -z), e nao por dentro dele: a
		# mistura reta das duas pegadas atravessava o vidro no meio do caminho.
		var troca := smoothstep(TROCA_INICIO, TROCA_FIM, k)
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
	_cotovelo_baixo = 0.0
	_braco_d.visible = false
	if _braco_e != null:
		_braco_e.visible = false
	_esquerda_em = &""
	_brilho_tela(1.0)


## O aparelho na leitura, no espaco do carro. Com `lente`, na frente dela (a
## cabeca fora do lugar, debrucada), e nao na frente do olho parado.
func _fone_na_leitura(lente: Vector3 = Vector3.INF) -> Transform3D:
	var deb := Vector3.ZERO if lente == Vector3.INF else lente - (_olho + OLHO_DA_CENA)
	var pos := _olho + CELULAR_NA_LEITURA + deb
	var olho := _olho + OLHO_DA_CENA + deb
	var base := Basis.looking_at((olho - pos).normalized(), Vector3.UP, true)
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


## A batida: o carro para de uma vez e o telefone, solto no banco do carona,
## nao. Ele sai do assento para a frente, bate no porta-luvas, cai no vao dos
## pes girando, quica no tapete e tomba de pe contra a frente do assoalho, com a
## tela virada para o motorista — e onde ele o ve do banco dele, e onde a mao
## vai busca-lo.
##
## Sao quatro trechos com a fisica de cada um escrita a mao (voo quase reto, a
## queda com gravidade, o quique, o tombo), e nao um corpo rigido: com corpo
## rigido o aparelho pararia onde quisesse, e a cena precisa dele virado para o
## olho, legivel, no fim.
const QUEDA_ESCORREGA := 0.12
const QUEDA_BATE := 0.2
const QUEDA_CAI := 0.40
const QUEDA_QUIQUE := 0.16
const QUEDA_TOMBA := 0.22
## Onde ele bate: no TAMPO do painel, meio caminho entre o volante e o carona
## (x em fracao do espelho do olho), a um palmo do para-brisa. E o trecho que o
## motorista VE — por cima do braco direito, que segura o aro e tapa o
## porta-luvas — e dali ele volta, cai da borda e some no vao dos pes, e o que
## resta e o barulho. Medido do olho, o ponto antigo ficava cinco centimetros
## abaixo do tampo: dentro do painel, e o aparelho sumia no voo inteiro.
const QUEDA_PAINEL_X := 0.55
const QUEDA_ANTES_DO_VIDRO := 0.14
## A altura do quique (m) e quantas voltas ele da no ar ate o tapete.
const QUEDA_QUIQUE_ALTO := 0.045
const QUEDA_VOLTAS := 1.35


func cair_na_batida() -> void:
	_soltar_da_mao()
	if _celular == null:
		return
	_celular_erguido = false
	if _tween_susto != null and _tween_susto.is_valid():
		_tween_susto.kill()
	var de := _celular.position
	var fim := _ponto_do_assoalho()
	var cabine := _carro.cabine if _carro != null else null
	var topo := cabine.topo_do_painel() if cabine != null else _olho.y - 0.08
	var y_bate := topo + Iphone4S.TAMANHO.z * 0.5 + 0.004
	var z_bate := (cabine.z_do_vidro(y_bate) if cabine != null else _olho.z - 0.7) \
		+ QUEDA_ANTES_DO_VIDRO
	var bate := Vector3(-_olho.x * QUEDA_PAINEL_X, y_bate, z_bate)
	var face := CarroCabine.PAINEL_Z
	# De pe contra a frente do vao, a tela inclinada para o motorista. Deitado
	# rente ao tapete a tela era um risco de raspao e nada se lia.
	var para_olho := (_olho + OLHO_DA_CENA) - fim
	para_olho.y = 0.0
	var q_fim := (Basis.looking_at(para_olho.normalized(), Vector3.UP, true)
		* Basis(Vector3.RIGHT, -ASSOALHO_TOMBO)).get_rotation_quaternion()
	fim.y += Iphone4S.TAMANHO.y * 0.5 * cos(ASSOALHO_TOMBO)
	var q_de := _celular.basis.get_rotation_quaternion()
	# O giro no ar: em volta de um eixo torto, cambalhota para a frente com um
	# pouco de parafuso. Pousa deitado (tela para cima) no quique e so entao
	# tomba para o fim.
	var eixo := Vector3(1.0, 0.25, 0.35).normalized()
	var deitado := (Basis.looking_at(para_olho.normalized(), Vector3.UP, true)
		* Basis(Vector3.RIGHT, -PI * 0.5)).get_rotation_quaternion()
	var chao := Vector3(fim.x, _piso() + Iphone4S.TAMANHO.z * 0.5 + 0.03, fim.z + 0.06)
	# A borda do tampo do painel (o rebote para tras) e o ponto rente a face do
	# porta-luvas, ja abaixo dela: o caminho que nao atravessa o painel.
	var borda := Vector3(lerpf(bate.x, fim.x, 0.4), topo + 0.05, face + 0.05)
	var rente := Vector3(fim.x, _piso() + 0.2, face + 0.07)
	var alto := Vector3(lerpf(de.x, bate.x, 0.5), topo + 0.16, face + 0.02)
	var total := QUEDA_ESCORREGA + QUEDA_BATE + QUEDA_CAI + QUEDA_QUIQUE + QUEDA_TOMBA
	_tween_susto = create_tween()
	_tween_susto.tween_method(func(tk: float) -> void:
		var t := tk * total - QUEDA_ESCORREGA
		var p: Vector3
		var q: Quaternion
		if t < 0.0:
			# O assento afunda com o tranco e o aparelho escorrega uns dedos
			# para a frente, ainda deitado.
			var k := (t + QUEDA_ESCORREGA) / QUEDA_ESCORREGA
			p = de + Vector3(0.0, 0.0, -0.06) * k * k
			q = q_de
		elif t < QUEDA_BATE:
			# O voo: rapido, do assento ao tampo do painel, em arco por cima
			# da borda dele. Quem para e o carro; o aparelho segue com a
			# velocidade que tinha, e o banco o joga para cima no tranco.
			var k := t / QUEDA_BATE
			p = _bezier(de, alto, alto, bate, k)
			q = q_de.slerp(q_de * Quaternion(eixo, PI * 0.5), k)
		elif t < QUEDA_BATE + QUEDA_CAI:
			# A queda: o para-brisa devolve o aparelho para tras, ele passa da
			# borda do painel, cai rente a face do porta-luvas e so la embaixo
			# entra no vao dos pes. Bezier por quatro pontos, com a gravidade no
			# parametro: sai devagar e chega depressa.
			var k := (t - QUEDA_BATE) / QUEDA_CAI
			var g := k * k * (1.6 - 0.6 * k)
			p = _bezier(bate, borda, rente, chao, g)
			var q_bate := q_de * Quaternion(eixo, PI * 0.5)
			q = q_bate.slerp(deitado, k)
			q = Quaternion(eixo, sin(k * PI) * TAU * (QUEDA_VOLTAS - 1.0) * 0.5) * q
		elif t < QUEDA_BATE + QUEDA_CAI + QUEDA_QUIQUE:
			# O quique: sobe um dedo e volta, deitado.
			var k := (t - QUEDA_BATE - QUEDA_CAI) / QUEDA_QUIQUE
			p = chao + Vector3.UP * QUEDA_QUIQUE_ALTO * 4.0 * k * (1.0 - k)
			p.z = lerpf(chao.z, fim.z, k * 0.3)
			q = deitado.slerp(deitado * Quaternion(Vector3.RIGHT, -0.18), sin(k * PI))
		else:
			# O tombo: escorrega o resto e cai de pe contra a frente do vao.
			var k := minf(1.0, (t - QUEDA_BATE - QUEDA_CAI - QUEDA_QUIQUE) / QUEDA_TOMBA)
			var e := k * k * (3.0 - 2.0 * k)
			p = Vector3(chao.x, chao.y, lerpf(chao.z, fim.z, 0.3)).lerp(fim, e)
			q = deitado.slerp(q_fim, e)
		_celular.position = p
		_celular.basis = Basis(q.normalized()), 0.0, 1.0, total)
	_brilho_tela(1.0)


static func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


## O telefone parou onde caiu.
func celular_no_chao() -> bool:
	return _tween_susto == null or not _tween_susto.is_valid()


## Mostra ou esconde as maos no volante. No salto da lente sobre o padre, com
## o campo a 26 graus, a mao no aro vira uma bola do tamanho do quadro.
func mostrar_maos_no_volante(visivel: bool) -> void:
	for b: Dictionary in _bracos:
		var e: Node3D = b.get("esqueleto")
		if e != null and is_instance_valid(e):
			e.visible = visivel and (b != _aro_direito or _direita_no_aro)


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
## quanto ela recua para tras do aparelho no meio da troca (m). A troca e no
## meio da subida, com o aparelho ainda longe e andando: feita no fim (era de
## 0,67 a 1), a palma passava por cima da tela a um palmo da lente.
const TROCA_INICIO := 0.30
const TROCA_FIM := 0.80
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
## 0 o cotovelo direito alto (atravessando a cabine), 1 baixo, junto do corpo.
var _cotovelo_baixo: float = 0.0
## A menor distancia da lente ao braco direito na ultima subida (m): a bancada
## le.
var lente_ao_braco_min: float = INF


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
		# atravessava a manopla do cambio. Subindo o aparelho ate o rosto ele
		# desce para junto do corpo (`_cotovelo_baixo`): alto, o braco subia para
		# dentro da lente e o quadro virava pele.
		_braco_d.polo = _giro_tronco * Vector3(carona * 0.6, 0.25, 0.9).lerp(
			Vector3(carona, -0.9, 0.2), _cotovelo_baixo)
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
func _pegada_no_aro(graus: float = MAO_NO_ARO_GRAUS) -> Dictionary:
	if _carro == null or _carro.cabine == null or _carro.cabine.pivo_do_volante() == null:
		return {}
	var pivo := _carro.cabine.pivo_do_volante()
	var xf := pivo.transform * _no_aro(graus)
	var giro := deg_to_rad(MaoModelada.GIRO)
	var obliquo := 0.0
	for b: Dictionary in _bracos:
		if is_equal_approx(float(b.get("graus", INF)), graus):
			giro = deg_to_rad(float(b["giro"]))
			obliquo = deg_to_rad(float(b["obliquo"]))
	var q := MaoModelada.obliquar(MaoModelada._eixos(xf, giro),
		1.0 if cos(deg_to_rad(graus)) > 0.0 else -1.0, obliquo)
	var d: Vector3 = q["d"]
	var dorso: Vector3 = q["dorso"]
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


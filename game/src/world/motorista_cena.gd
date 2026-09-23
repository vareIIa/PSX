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
const CELULAR_NA_LEITURA := Vector3(0.04, -0.08, -0.16)
## Quanto a tela acende, na escala do `Adereco`. Pouco: a lente da cutscene esta
## na exposicao de noite, e mesmo com um sexto da forca o aparelho saia como um
## retangulo branco estourado no meio do volante, roubando o olho do celular do
## jogo que sobe na tela ao lado — e que e quem mostra o que esta escrito. Aqui
## ela so precisa pintar o aro e a mao de frio, que e o que diz que ha uma tela
## acesa ali.
const TELA_ACESA := 0.05
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
var _celular: Adereco
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
	# A mesma regra do `Corpo`: casaco ou camisa de numero par tem manga
	# comprida, e o antebraco e pano; senao e pele.
	var manga_longa := bool(aparencia.get("casaco", false)) \
		or int(aparencia.get("camisa", 0)) % 2 == 0
	var manga: Color = aparencia.get("casaco_cor", aparencia.get("camisa_cor",
		Color(0.45, 0.47, 0.52))) if bool(aparencia.get("casaco", false)) \
		else aparencia.get("camisa_cor", Color(0.45, 0.47, 0.52))

	_montar_mao_esquerda(cabine, pele, manga if manga_longa else pele, manga_longa)
	_montar_mao_direita(cabine, pele, manga if manga_longa else pele, manga_longa)
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
	var pele: Color = aparencia.get("pele", Color(0.78, 0.62, 0.50))
	var longa := bool(aparencia.get("casaco", false)) \
		or int(aparencia.get("camisa", 0)) % 2 == 0
	var manga: Color = aparencia.get("casaco_cor", aparencia.get("camisa_cor",
		Color(0.45, 0.47, 0.52))) if bool(aparencia.get("casaco", false)) \
		else aparencia.get("camisa_cor", Color(0.45, 0.47, 0.52))
	return {"pele": pele, "manga": manga if longa else pele, "longa": longa}


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
	esqueleto.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = esqueleto.create_skin_from_rest_transforms()
	return {"esqueleto": esqueleto, "pivo": pivo, "osso": antebraco,
		"punho": braco["punho"], "eixo": braco["eixo"], "cotovelo": cotovelo_carro}


func _process(_delta: float) -> void:
	for b: Dictionary in _bracos:
		_apontar_antebraco(b)


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
	# na origem com a tela em +Z (e a face em que o `Adereco` poe a tela), e a mao
	# o segura por tras e por baixo, do lado de -Z.
	var dados := PSXMesh.dados_vazios()
	# A mao: a palma atras do aparelho, os dedos passando pelas bordas. Vista do
	# olho ela so aparece como a moldura de pele em volta da base do telefone,
	# que e o que se ve de uma mao segurando um celular na frente do rosto.
	_caixa(dados, Vector3(MAO.x, MAO.z, MAO.y),
		Transform3D(Basis(), Vector3(0.0, -Adereco.FONE.y * 0.32,
			-Adereco.FONE.z * 0.5 - MAO.y * 0.5 + 0.004)),
		Aparencia.uv_da_celula(Aparencia.PECA_MAO, Aparencia.LINHA_PECAS), pele)
	# O antebraco sai do punho e desce para o banco: para baixo, para o motorista
	# e um pouco para a direita, que e de onde o braco direito vem.
	var punho := Vector3(0.0, -Adereco.FONE.y * 0.32 - MAO.z * 0.45, -0.03)
	var eixo := Vector3(0.22, -0.78, 0.58).normalized()
	_caixa(dados, Vector3(ANTEBRACO_GROSSURA, ANTEBRACO_GROSSURA * 0.9, ANTEBRACO),
		Transform3D(Basis.looking_at(eixo, Vector3.FORWARD),
			punho + eixo * (ANTEBRACO * 0.5)),
		Aparencia.uv_da_celula(Aparencia.PECA_MANGA if manga_longa
			else Aparencia.PECA_NUCA, Aparencia.LINHA_PECAS), manga)
	_mao_direita.add_child(_malha(dados, "Mao"))

	_celular = Adereco.new()
	_celular.name = "Celular"
	_mao_direita.add_child(_celular)
	_celular.montar(Adereco.Tipo.CELULAR)
	_celular.forca_da_tela = 0.22
	# De pe, com o topo tombado vinte graus para longe do olho: o olho esta acima
	# do aparelho, e a tela tem de olhar para ele.
	_celular.position = Vector3.ZERO
	_celular.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)
	_celular.brilho = 0.0

	_mao_direita.position = _olho + CELULAR_NO_COLO
	_apontar_para_o_olho(_mao_direita)
	_mao_direita.visible = false


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
		_tween_celular.tween_property(_celular, "brilho", TELA_ACESA, 0.25).set_delay(0.15)
	else:
		_tween_celular.tween_property(_celular, "brilho", 0.0, 0.3)
		_tween_celular.chain().tween_callback(func() -> void:
			_mao_direita.visible = false)


## Onde a tela do celular esta agora, em coordenada de mundo. E para onde a
## cabeca vira.
func ponto_do_celular() -> Vector3:
	if _celular == null:
		return global_position
	return _celular.global_position


func celular_erguido() -> bool:
	return _celular_erguido


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


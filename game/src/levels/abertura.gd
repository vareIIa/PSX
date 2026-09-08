## A abertura da partida nova. O roteiro, e nao a maquinaria.
##
## Quem faz o que
## --------------
## `Cinema` sabe desenhar tarja, legenda e mover camera, e nao sabe nada da
## historia. Este arquivo e o contrario: e so historia — onde a camera fica em
## cada plano, o que esta escrito na tela, quanto tempo cada coisa dura. Toda
## constante de enquadramento esta aqui em cima, com nome, para dar para mexer
## na cena sem ler uma linha de logica.
##
## Os planos, na ordem
## -------------------
##   1. A praca: POV olho no ceu/nevoa, depois takes externos dele ainda deitado.
##   2. A avenida principal, em dois planos (o meio dela, depois uma esquina).
##   3. A blitz na saida da cidade, se o sorteio botou uma por perto.
##   4. Dentro do mercado: o atendente e o cliente conversando no caixa.
##   5. Dentro da casa da fumaca. Gente conversando e rindo.
##   6. Ele encostado no poste com a bicicleta ao lado, mexendo no celular e
##      fumando. A camera desce do alto ate a altura dos olhos dele e funde num
##      corte com a primeira pessoa.
##   7. Primeira pessoa: a bituca na boca, o ultimo trago, a mao que tira o
##      cigarro e joga fora.
##   8. As tarjas abrem, o GPS sobe na mao e a primeira missao comeca.
##
## Por que o segundo plano entra no comodo de verdade
## --------------------------------------------------
## Porque o comodo de verdade ja existe, com oito pessoas que andam, fumam,
## conversam entre si e riem sozinhas. Montar um cenario de mentira para a cena
## cortada daria uma sala parada com figurantes de papelao, e o plano existe
## exatamente para dizer que aquela casa e cheia de gente viva. `Interiores` ja
## sabe montar e desmontar isso, e devolve o jogador para a calcada de onde ele
## saiu — que aqui e a parede em que ele esta encostado.
##
## E a casa que aparece e A DA MISSAO: a semente vem do mesmo endereco que o GPS
## vai mandar o jogador procurar daqui a um minuto. O plano nao e ilustracao, e
## o lugar.
class_name Abertura
extends Node

# --- planos da avenida ------------------------------------------------------
## A avenida principal, em dois planos: um do meio dela e outro de uma esquina.
##
## A avenida e procurada na MALHA, e nao improvisada em volta do jogador. A
## versao anterior enquadrava a partir da pose dele e dizia "essa e a rua
## principal" por cima de uma imagem do parque em que ele tinha acabado de
## acordar — a fala descrevia uma coisa e a tela mostrava outra. `MalhaUrbana`
## sabe onde as avenidas passam sem carregar nada: elas caem em toda linha de
## grade multipla de cinco, ou seja a cada 160 m.
##
## E o jogador VAI JUNTO. O ChunkManager so monta os dois aneis de chunk em
## volta do alvo do streaming, que e o corpo dele; uma camera plantada na avenida
## com o sujeito a oitenta metros fotografaria o vazio cinza. Como nestes dois
## planos o corpo esta escondido, mudar ele de lugar nao custa nada na tela e
## resolve o carregamento de uma vez.
const AVENIDA_BUSCA := 8

## Plano A: do meio da pista, correndo no sentido da avenida.
##
## Baixo e perto, e nao alto e longe. A primeira versao filmava de 7,4 m a vinte
## metros de recuo olhando trinta a frente: a captura saiu com dois postes de pe
## dentro de um retangulo cinza liso, sem chao, sem fachada e sem rua. O corte de
## desenho por distancia esta em 26 m e a nevoa fecha antes disso — tudo que o
## plano enquadrava estava do lado de la das duas coisas. Aqui a camera corre a
## quatro metros e olha quinze a frente, que e dentro do alcance: aparece o
## asfalto, o meio-fio, o cone de luz do poste e a fachada dos dois lados.
const AVENIDA_A_ALTURA := Vector2(4.6, 3.2)
const AVENIDA_A_RECUO := Vector2(14.0, 6.0)
## Para onde olha: avenida adentro, terminando mais longe do que comeca. E a
## nevoa engolindo o fundo que faz a rua parecer nao ter fim, mas ela so pode
## engolir o que primeiro apareceu.
const AVENIDA_A_OLHAR := Vector2(15.0, 24.0)
const AVENIDA_A_FOV := Vector2(66.0, 58.0)
const AVENIDA_A_DURACAO := 10.0

## Plano B: mais adiante na MESMA avenida, mais baixo e mais perto do meio-fio.
##
## Nao e a esquina seguinte. A primeira versao ia ate o cruzamento seguinte e
## abria a camera para a rua transversal, e o resultado saiu com a lente
## atravessando a cabeca do semaforo da esquina — semaforo e placa nascem
## fundidos na malha do chao do chunk (`ChunkBuilder._semaforos`, igual ao
## poste de luz), SEM caixa de colisao, entao o raio que testa "isto aqui esta
## livre?" em outros pontos deste arquivo passa direto por eles e nunca acha o
## problema. Um cruzamento e sempre terreno arriscado: alem do semaforo tem
## placa, poste dobrado, faixa de pedestre com boca-de-lobo. Meio de quarteirao
## nunca tem nada disso.
##
## Por isso este plano so avanca em METROS ao longo do proprio eixo da avenida —
## nunca cai exatamente numa linha de grade, que e onde essa mobilia toda mora.
## O corte para "mais adiante, mesma avenida" ainda cumpre o que a fala pede
## ("essa avenida nao tem fim"): e literalmente mais avenida, so que sem lente
## atravessando semaforo nenhum.
const AVENIDA_B_AVANCO := 58.0
const AVENIDA_B_ALTURA := Vector2(2.6, 1.7)
## Recuo ao longo do eixo e um desvio lateral bem pequeno — o suficiente para
## nao repetir o enquadramento centralizado do plano A, e nao mais do que isso.
##
## A primeira versao deste ajuste levava a camera quase ate o meio-fio (4,2 m
## do eixo), que era exatamente onde essa correcao tentava fugir do semaforo. A
## avenida planta arvore a cada 11 m junto da guia (`ChunkBuilder._arborizacao`)
## e a copa NAO tem colisao — so o tronco tem — entao a mesma familia de raio
## que acha predio nunca ia acusar isto. A avenida tem 9 m de pista contando os
## dois sentidos; ficar a 1,6 m do eixo e nao chegar nem na metade do caminho
## ate a arvore mais perto.
const AVENIDA_B_RECUO := Vector2(8.0, 3.5)
const AVENIDA_B_LADO := Vector2(1.6, 0.8)
const AVENIDA_B_OLHAR := Vector2(14.0, 22.0)
const AVENIDA_B_FOV := Vector2(60.0, 54.0)
const AVENIDA_B_DURACAO := 10.0

# --- plano do poste ---------------------------------------------------------
## O ultimo plano de fora: ele encostado no poste, e a camera descendo do alto
## ate a altura dos olhos dele.
##
## O plano existe para a passagem: quando a camera chega na cara do sujeito, o
## preto entra e o que abre do outro lado e a primeira pessoa DELE, no mesmo
## lugar e na mesma altura. E a unica emenda da abertura em que a camera de
## cinema e a camera do jogador coincidem, e por isso e a unica que pode fechar.
const POSTE_ALTURA := Vector2(12.5, 1.72)
const POSTE_RECUO := Vector2(4.6, 2.35)
const POSTE_OLHAR := Vector2(0.95, 1.52)
const POSTE_FOV := Vector2(66.0, 58.0)
const POSTE_DURACAO := 12.0
## A que distancia do mastro as costas dele param, e a quantos chunks procurar
## um poste.
const POSTE_ENCOSTO := 0.42
const POSTE_BUSCA := 2

## Quanto tempo esperar o pedaco de cidade novo ficar de pe depois de mudar o
## jogador de lugar, em quadros de fisica.
const ESPERA_BAIRRO := 420

# --- plano da praca ---------------------------------------------------------
## Acordar na Praca da Matriz: POV olho no ceu/nevoa, depois takes externos
## orbitando o corpo AINDA DEITADO (sem levantar, sem props FP de pernas).
## Pin 270,-40; eixo igreja ~271,-51 (Cleiton). Constantes PRACA_* / ACORDA_*
## abaixo ficam como referencia de escala; o roteiro novo monta os takes na mao.
const PRACA_ALTURA := Vector2(4.6, 3.2)
const PRACA_FRENTE := Vector2(3.0, 10.0)
const PRACA_OLHAR := Vector2(19.0, 21.0)
const PRACA_FOV := Vector2(64.0, 58.0)
const PRACA_DURACAO := 15.5
## Olho deitado -> olho em pe. Baixo o bastante pra ver as proprias pernas.
const ACORDA_ALTURA := Vector2(0.16, 1.62)
## Distancia pes->cabeca ao longo do eixo do corpo (metros).
const ACORDA_CABECA := 1.28
## Altura do alvo do olhar (chao perto dos pes -> horizonte da praca).
const ACORDA_OLHAR_ALTURA := Vector2(0.03, 1.40)
## Quao longe o olhar mira no comeco (pes) e no fim (praca adentro).
const ACORDA_OLHAR_PERTO := 0.20
const ACORDA_OLHAR_LONGE := 18.0
## Bicicleta: lado oposto ao tronco, fora do cone FP.
const ACORDA_LADO := 1.95
## Para que lado da bussola o corpo caido aponta (ajuste fino do yaw local).
const DEITADO_GIRO := 0.7
## Espessura de meio corpo deitado, em metros.
const DEITADO_ALTURA := 0.18
## FOV largo no chao (claustrofobia PSX), fecha um pouco ao levantar.
const ACORDA_FOV := Vector2(72.0, 58.0)
const ACORDA_DURACAO := 9.0
## Quanto tempo ele fica caido antes de se mexer, e quanto leva para levantar.
const ACORDA_ANTES := 3.4
const ACORDA_SUBIDA := 2.2

## Ate onde procurar o parque, em chunks.
const PRACA_RAIO := 14
## E a que distancia, em metros, ainda vale apontar a camera para ele.
##
## O parque existe no gerador a qualquer distancia, mas so existe NA TELA dentro
## do alcance da nevoa e do streaming. Apontar para um a cento e quarenta metros
## deu um plano de quinze segundos de cinza liso com legenda por cima — o
## enquadramento estava certo e nao havia nada la para enquadrar. Alem deste
## raio o plano vira o que ele ja sabia ser sem parque nenhum: a rua.
const PRACA_ALCANCE := 45.0

# --- plano da blitz ---------------------------------------------------------
## A blitz nasce a 42-70 m do jogador e nao aparece sempre. O plano espera este
## tanto por uma e segue sem ela se nao vier: uma abertura que so funciona quando
## o sorteio colabora nao e uma abertura.
const BLITZ_ESPERA_MAX := 4.0
const BLITZ_DE := Vector3(9.0, 5.2, 9.0)
const BLITZ_ATE := Vector3(6.0, 3.4, 6.0)
const BLITZ_FOV := 58.0
const BLITZ_DURACAO := 7.0

# --- plano do mercado -------------------------------------------------------
## Em coordenada de planta da loja (ver MercadoBuilder): a camera atravessa o
## salao na diagonal e desce em direcao ao caixa, onde o atendente e o cliente
## conversam.
##
## Ela passa ACIMA das prateleiras, e essa e a unica coisa que importa nestas
## seis linhas. A primeira versao corria a 1,62 m e terminava a 1,52 — a altura
## exata de uma gondola de ilha (`KitMercado.ALTURA_GONDOLA`, 1,52) e abaixo das
## de parede (1,95). O movimento estava bonito e a camera atravessava os armarios
## no meio do caminho. Agora ela comeca a 2,40 e termina a 2,20, o que passa
## folgado por cima das duas e ainda cabe sob o teto de 2,9.
const MERCADO_SEMENTE := 77451
const MERCADO_DE := Vector3(6.40, 2.40, 5.80)
const MERCADO_ATE := Vector3(3.30, 2.20, 3.20)
const MERCADO_OLHAR_DE := Vector3(1.70, 1.30, 2.25)
const MERCADO_OLHAR_ATE := Vector3(1.45, 1.15, 2.15)
const MERCADO_FOV := 62.0
const MERCADO_DURACAO := 9.5

# --- plano 2: a casa da fumaca ----------------------------------------------
## Em coordenada de planta da casa (ver CasaFumacaBuilder): a camera entra pelo
## canto da porta e vai andando para dentro, na diagonal, em direcao a TV — que
## e onde estao os dois que jogam e a maior parte da luz do comodo.
const CASA_DE := Vector3(1.55, 1.42, 2.35)
const CASA_ATE := Vector3(2.65, 1.30, 3.55)
const CASA_OLHAR_DE := Vector3(5.20, 1.15, 5.85)
const CASA_OLHAR_ATE := Vector3(4.80, 1.05, 5.95)
const CASA_FOV := 58.0
const CASA_DURACAO := 9.5
## Quanto o plano espera o comodo ficar pronto antes de desistir. A construcao
## roda em thread e leva uns poucos quadros; o teto existe para a abertura nunca
## travar para sempre por causa de um comodo que nao veio.
const CASA_ESPERA_MAX := 8.0

# --- plano 3: a bituca ------------------------------------------------------
## Onde a bituca fica no campo de visao, contado do olho. Baixo, a frente e um
## pouco a direita: e onde fica um cigarro presente no canto da boca de quem
## esta olhando para baixo.
const BITUCA_NA_BOCA := Vector3(0.038, -0.058, -0.125)
const BITUCA_GIRO := Vector3(-10.0, 95.0, 0.0)

## Tempos do ultimo trago, em segundos: espera, puxada, seguro, solta.
const TRAGO_ESPERA := 2.0
const TRAGO_PUXA := 1.3
const TRAGO_SEGURA := 0.7
const TRAGO_SOLTA := 1.5

## De onde a mao entra no quadro e onde ela para para pegar o cigarro. A entrada
## e de baixo e da direita, que e o caminho que uma mao faz.
const MAO_FORA := Vector3(0.20, -0.42, -0.20)
const MAO_NA_BOCA := Vector3(0.072, -0.086, -0.130)
const MAO_SOBE := 0.55
const MAO_DESCE := 0.42

## Onde a bituca cai, contado do jogador: a frente e um pouco para o lado.
const BITUCA_NO_CHAO := Vector3(0.45, 0.0, -0.95)
const BITUCA_QUEDA := 0.55

## Quanto a camera baixa para ver a bituca no chao, em graus.
const OLHAR_O_CHAO := -34.0

# --- textos -----------------------------------------------------------------
## Uma frase por plano, e nenhuma explica o que a imagem ja mostra.
const FALAS := {
	"acorda": "...",
	"praca_1": "Ultima coisa que eu lembro era o farol na terra.",
	"praca_2": "Ai... apagou. Tipo, do nada.",
	"praca_3": "E eu acordo no meio de uma praca.",
	"praca_4": "Cade o carro? Cade a estrada?",
	"praca_5": "Isso aqui nao e a pousada. Nem de longe.",
	"avenida_1": "Tem gente. Tem luz. Mas nao parece... normal.",
	"avenida_2": "Sem maldade, eu nao reconheco nada disso.",
	"blitz": "E tem blitz na saida. Claro que tem.",
	"mercado_1": "Tenho uns quarenta reais no bolso.",
	"mercado_2": "E to morrendo de fome.",
	"casa": "Eu sei la que tipo de gente mora nessa cidade...",
	"poste_1": "To preocupado pra saber como vou sair daqui.",
	"poste_2": "Nao era pra eu ter pegado essa estrada.",
	"poste_3": "Sao Thome, a galera, a pousada... tudo sumiu da minha cabeca.",
	"bituca": "Que saudade de casa. Quero sair daqui logo...",
}

# --- corpo ------------------------------------------------------------------
## A quanto o sujeito fica da bicicleta, ao longo da parede.
const AO_LADO_DA_BICICLETA := 1.15
## A que distancia da parede as costas dele param. Trinta centimetros e meio
## corpo: encostado de verdade, sem a caixa do tronco entrar no reboco.
const COSTAS_NA_PAREDE := 0.32

## A abertura NAO forca nevoa.
##
## A primeira versao forcava um preset leve, para a rua ficar legivel na fala
## "essa e a rua principal". O resultado foi pior que o problema: no ChunkManager
## o alcance de carga esta atrelado ao preset de nevoa, entao clarear o ar
## afastou a parede branca e mostrou a BORDA do mundo carregado — a cidade
## terminava numa linha reta no meio do quadro, com a rua cortada ao meio.
##
## Quem resolve a legibilidade e a luz de apoio aqui embaixo, que ilumina o
## sujeito sem mexer em quanto mundo existe atras dele.

## Luz de apoio no sujeito durante o primeiro plano.
##
## A cidade e noturna e iluminada a sodio, e onde ele esta encostado pode nao
## haver poste nenhum: a primeira captura deste plano saiu com o personagem
## principal como uma mancha marrom de doze pixels que nao dava para identificar
## como pessoa. `_desfile` ja resolve o mesmo problema do mesmo jeito, e pela
## mesma razao — o que e certo para a rua nao e o que deixa ver quem esta nela.
##
## Fraca, quente e sem sombra. Nao e para iluminar a rua: e para o rosto, a
## bicicleta e a fumaca sairem do preto. Some junto com o primeiro plano.
const APOIO_COR := Color("ffd9a8")
const APOIO_ENERGIA := 2.4
const APOIO_ALCANCE := 7.0
## Onde ela fica, contada do sujeito: a frente, do lado da camera e acima.
const APOIO_ONDE := Vector3(2.2, 2.6, 1.6)

## Busca de calcada: passo e alcance, em metros, e a altura a partir da qual o
## chao conta como calcada.
##
## O ponto de nascimento da cena nao e garantidamente calcada. A bicicleta e
## encostada na parede mais proxima por uma busca em leque de oito metros, e
## quando a parede mais proxima esta do outro lado da via ela para no asfalto —
## e o sujeito ia junto, encostado em nada, no meio da pista. A calcada fica
## 16 cm acima do asfalto, e essa diferenca de altura e a unica pergunta que o
## mundo gerado responde sem ambiguidade: "aqui e calcada?" vira "o chao aqui
## esta acima do meio-fio?".
const PASSO_CALCADA := 0.25
const BUSCA_CALCADA := 8.0
const NIVEL_CALCADA := KitModular.ALTURA_MEIO_FIO - 0.05

## Espera maxima pelo chao do chunk aparecer, em quadros de fisica. O mesmo
## problema da bicicleta do respawn: o ChunkManager monta em thread e nos
## primeiros quadros nao ha nem parede em que encostar nem chao para nao cair.
const ESPERA_CHAO := 300
## Quadros de fisica que a cena da ao corpo para parar de cair antes de medir
## onde ele esta.
const ASSENTAR := 120

var _jogador: Player
var _cena: Node3D
var _cigarro: Adereco
var _celular: Adereco
var _bituca: Adereco
var _mao: Node3D
var _fumaca_soprada: MeshInstance3D
## A coordenada em que a cena poe o jogador. Vem de fora porque a tela de titulo
## pode ter levado o corpo dele para dentro de um comodo no meio do caminho.
var _nasceu_em := Vector3.ZERO
var _apoio: OmniLight3D
## A bicicleta da cena. Guardada porque ela acompanha o sujeito ate o poste: a
## abertura acaba onde a partida comeca, e o enunciado e "a bicicleta ao lado
## dele".
var _bike: Bicicleta
## O ponto do plano B da avenida. O plano do poste procura o poste A PARTIR
## DAQUI, e nao do parque: o sujeito diz "essa avenida nao tem fim" e a cena
## seguinte tem de ser ele parado nela, e nao de volta no gramado onde acordou.
var _ultimo_ponto_da_avenida := Vector3.INF


## Roda a abertura inteira e some. Devolve so quando o jogador ja tem o controle.
var _hud: HudEstrada


func executar(cena: Node3D, jogador: Player, nasceu_em: Vector3) -> void:
	_cena = cena
	_jogador = jogador
	_nasceu_em = nasceu_em

	Cinema.fechar_de_imediato()
	Cinema.iniciar(true)
	_montar_hud_local()

	var pose := await _preparar_cenario()
	# A ordem nao e decorativa. Os tres primeiros planos sao de fora e podem
	# acontecer com o corpo dele posado na parede; os dois de dentro teleportam o
	# jogador para outro comodo e teriam de desmontar a pose toda vez. Fazer os
	# exteriores primeiro custa duas transicoes de interior em vez de quatro.
	await _plano_da_praca(pose)
	# Captura AAA da praca: nao precisa do resto do roteiro.
	if OS.get_cmdline_user_args().has("--ver-praca"):
		print("[abertura] praca capturada - encerrando")
		await get_tree().create_timer(0.35).timeout
		get_tree().quit()
		return
	await _plano_da_avenida(pose)
	await _plano_da_blitz(pose)
	await _plano_do_mercado(pose)
	await _plano_da_casa(pose)
	# O poste vem por ultimo entre os planos de fora porque ele nao e um plano:
	# e a emenda. A camera desce ate a cara dele, o preto entra e a primeira
	# pessoa abre no mesmo ponto — ver `_plano_do_poste`. Posto antes da blitz,
	# como a ordem da conversa sugeria, essa descida terminaria num corte para
	# dentro de um mercado e a passagem nao existiria.
	await _plano_do_poste(pose)
	await _plano_da_bituca(pose)
	await _entregar_o_jogo()
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
		_hud.queue_free()
		_hud = null
	queue_free()



## HUD compartilhado (mesmo de Estrada Velha). Valores da print da Praça.
func _montar_hud_local() -> void:
	_hud = HudEstrada.new()
	_hud.name = "HudLocal"
	_cena.add_child(_hud)
	_hud.visible = false
	_hud.definir_local("PRAÇA DA MATRIZ")
	_hud.definir_hora("23:15")
	_hud.definir_vida(4, 10)
	_hud.definir_lanterna(true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hora="):
			_hud.definir_hora(arg.trim_prefix("--hora="))
		elif arg.begins_with("--vida="):
			_hud.definir_vida(int(arg.trim_prefix("--vida=")), 10)
		elif arg.begins_with("--local="):
			_hud.definir_local(arg.trim_prefix("--local=").replace("_", " "))
		elif arg == "--lanterna-off":
			_hud.definir_lanterna(false)


# --- montagem ---------------------------------------------------------------

## Poe o sujeito encostado na parede da bicicleta, com o cigarro e o telefone
## nas maos. Devolve a pose dele, que os tres planos usam como referencia.
##
## A parede vem da BICICLETA, e nao de uma varredura nova. Ela ja foi encostada
## em alguma parede perto do respawn por `cidade.gd`, e refazer a busca aqui
## poderia achar outra: o sujeito ficaria de costas para um muro e a bicicleta
## dele estaria na esquina de tras. O enunciado da cena e "a bicicleta ao lado
## dele", e a unica forma de garantir isso e perguntar a ela onde e a parede.
func _preparar_cenario() -> Dictionary:
	var origem := _nasceu_em
	# Pin Cleiton/Jota: 270,-40 olhando norte. Lampiao SW (~265,-40) a esquerda;
	# coreto 272,-48 + igreja ao norte no reach.
	const PIN_ACORDAR := Vector3(270.0, 0.0, -40.0)
	origem = Vector3(PIN_ACORDAR.x, origem.y, PIN_ACORDAR.z)
	_jogador.global_position = origem + Vector3.UP * 0.5
	# Frente = norte (-Z): lampiao fica a esquerda no FP.
	_jogador.rotation.y = 0.0
	_jogador.zerar_velocidade()
	_nasceu_em = origem
	# Espera streaming do chunk da Matriz antes de testar chao.
	for _k in 90:
		await get_tree().physics_frame
	for _k in ESPERA_CHAO:
		await get_tree().physics_frame
		if _tem_chao(origem):
			break

	# A bicicleta nasce em paralelo, no mesmo `_ready` da cena, e espera o mesmo
	# chao que esta espera. Sem este segundo laco a abertura ganha a corrida por
	# um quadro em metade das execucoes e nao acha bicicleta nenhuma.
	var bike: Bicicleta = null
	for _k in ESPERA_CHAO:
		bike = Bicicleta.mais_perto(get_tree(), origem, 14.0)
		if bike != null:
			break
		await get_tree().physics_frame

	# O chao, e mais nada.
	#
	# A versao anterior procurava uma parede em que encostar e uma calcada em que
	# ficar de pe. Faziam sentido quando a partida comecava numa rua; no meio de
	# um parque nao ha parede nenhuma, a grama ondula, e as duas buscas devolviam
	# pontos onde nao havia chao — o sujeito nascia boiando e a bicicleta ficava
	# a quatro metros, no asfalto da rua mais proxima. Aqui ele deita onde a cena
	# mandou, e a bicicleta deita do lado dele.
	# Poe o jogador no ponto e DEIXA A FISICA ASSENTAR antes de perguntar onde ele
	# esta.
	#
	# Um raio para baixo nao serve aqui. Num parque ele acerta banco, lixeira,
	# galho e placa, e devolve a altura da coisa em que bateu: o primeiro
	# resultado desta cena foi um chao a 2,25 m, que era o assento de um banco.
	# O corpo caiu para o chao de verdade, a 0,00 m, e a camera — montada em cima
	# dos 2,25 — ficou mirando quase tres metros acima dele. Na tela o sujeito
	# projetava em y=347 numa janela de 270 px de altura, ou seja setenta e sete
	# pixels abaixo da borda de baixo.
	#
	# Deixar a fisica resolver e perguntar depois nao tem como errar: o chao e
	# onde o corpo parou.
	var frente := Vector3(-sin(_jogador.rotation.y), 0.0, -cos(_jogador.rotation.y))
	var tangente := Vector3(-frente.z, 0.0, frente.x)

	_jogador.global_position = origem + Vector3.UP * 0.5
	_jogador.zerar_velocidade()
	_jogador.mostrar_corpo(true)
	for _k in ASSENTAR:
		await get_tree().physics_frame
		if _jogador.is_on_floor():
			break
	var onde := _jogador.global_position

	# Pin Cleiton/Jota: yaw travado norte (lampiao SW a esquerda).
	_jogador.rotation.y = 0.0

	var figura := _jogador.figura()
	if figura != null:
		_montar_maos(figura)
		_deitar(figura, true)
		# Joelhos levemente dobrados: FP le calca+bota, nao caixa reta.
		figura.postura(Corpo.Postura.DEITADO_ACORDAR)
		_jogador.mostrar_corpo(true)

	# De que lado o plano vai filmar. Decidido AQUI, e nao no plano, porque a
	# bicicleta precisa saber para ir para o outro: com ela do mesmo lado, os dois
	# pneus enchiam o quadro e o sujeito caido aparecia por baixo do quadro dela.
	var eixo := _eixo_do_corpo(figura) if figura != null else frente
	var lado := eixo.cross(Vector3.UP).normalized()
	var meio := onde + eixo * 0.85
	if not _lado_livre(meio, lado):
		lado = -lado

	_bike = bike
	if bike != null:
		# Do lado oposto ao da camera, e um pouco atras da cabeca dele.
		var junto := meio - lado * AO_LADO_DA_BICICLETA + eixo * 0.6
		junto.y = _chao_em(junto)
		bike.global_position = junto
		bike.rotation.y = _jogador.rotation.y
		bike.encostar_em_parede()

	_acender_apoio(onde, frente, tangente)

	return {
		"onde": onde,
		"normal": frente,
		"tangente": tangente,
		"eixo": eixo,
		"lado": lado,
		"meio": meio,
	}


## As duas pontas do movimento de camera tem vista livre deste lado?
##
## As duas, e nao so a primeira: a camera anda durante o plano, e testar so onde
## ela comeca deixa ela terminar atras de um tronco.
func _lado_livre(meio: Vector3, lado: Vector3) -> bool:
	# So decide o lado da BICICLETA. A camera do acordar e FP na cabeca.
	var a := meio + lado * ACORDA_LADO + Vector3.UP * 0.6
	var b := meio + lado * (ACORDA_LADO * 1.15) + Vector3.UP * 1.2
	return _linha_livre(a, meio) and _linha_livre(b, meio)


## Deita o corpo no chao, ou levanta ele.
##
## Gira o CORPO inteiro, e nao os ossos.
##
## Uma pose de bone a bone para alguem deitado precisaria de quadril, tronco,
## cabeca, dois bracos e duas pernas reescritos, e ainda por cima de uma segunda
## pose intermediaria para o ato de levantar — que e um movimento de corpo
## inteiro, o mais dificil que existe num esqueleto rigido de onze ossos. Girar
## noventa graus no eixo X sobre os pes deita a pessoa por completo, de graca, e
## desfazer o giro E o ato de levantar. O que se perde e o detalhe do cotovelo
## apoiando no chao; o que se ganha e uma transicao que nao tem como quebrar.
func _deitar(figura: Corpo, deitado: bool) -> void:
	if not deitado:
		figura.basis = Basis()
		figura.position.y = 0.0
		return
	# Base montada na mao, e nao tres angulos de Euler.
	#
	# A ordem em que o motor aplica Euler (YXZ) faz "deitar e depois girar" e
	# "girar e depois deitar" darem corpos apontando para lados diferentes, e a
	# primeira versao disto deitou o sujeito para TRAS da camera: dele so entravam
	# os pes no quadro e o resto passava por fora da lente. Multiplicar as bases
	# na ordem que eu quero acaba com a duvida.
	#
	# O sinal do meio e o que decide se ele acorda de bruços ou de barriga para
	# cima. -PI/2 deita ele de CARA NO CHAO — a frente do corpo (para onde o
	# rosto olha de pe) fica apontada para baixo depois da rotacao, e e assim
	# que a primeira versao disto acordava todo mundo. +PI/2 deita de costas,
	# rosto para o ceu: e a unica das duas que faz sentido para uma cena que
	# comeca com ele acordando e levantando, e nao sufocando na grama.
	figura.basis = (Basis(Vector3.UP, DEITADO_GIRO)
		* Basis(Vector3.RIGHT, PI * 0.5)
		* Basis(Vector3.FORWARD, 0.22))
	# Sobe a espessura de meio corpo.
	#
	# O giro e em torno dos PES, que e a origem do Corpo, entao a linha do tronco
	# fica exatamente na altura do chao e metade do sujeito fica enterrada no
	# calcamento. Na tela ele projetava dentro do quadro, na horizontal, e mesmo
	# assim nao dava para ve-lo: o que estava acima da pedra era uma fatia de
	# poucos centimetros. Um corpo deitado tem uns dezoito de espessura, e e isso
	# que falta.
	figura.position.y = DEITADO_ALTURA


## Para onde o corpo aponta, dos pes para a cabeca, em coordenada de mundo.
##
## Sai da propria base do corpo, e nao de uma conta repetida no enquadramento: o
## eixo Y local de um Corpo vai do quadril para a cabeca sempre, deitado ou de
## pe, e perguntar a ele e a unica forma de a camera nao poder discordar da pose.
func _eixo_do_corpo(figura: Corpo) -> Vector3:
	var v := figura.global_transform.basis.y
	v.y = 0.0
	return v.normalized() if v.length_squared() > 0.001 else Vector3.FORWARD


## O ato de levantar, no tempo dado.
func _levantar(figura: Corpo, duracao: float) -> void:
	# Duas animacoes ao mesmo tempo, no MESMO relogio: o Node3D inteiro gira de
	# deitado a de pe (o corpo como bloco rigido) enquanto o esqueleto por
	# dentro empurra contra o chao com a mao e dobra as pernas para se erguer
	# (ver `Corpo.levantar`). Sem a segunda, a primeira sozinha e um boneco
	# tombando para cima sem mexer um musculo — que era exatamente a queixa.
	figura.levantar(duracao)

	var t := create_tween().set_parallel(true)
	# Devagar no fim: o peso do corpo esta todo na subida, e um levantar que
	# desacelera no fim le como esforco. Linear le como guindaste.
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(figura, "rotation:x", 0.0, duracao)
	t.tween_property(figura, "rotation:z", 0.0, duracao * 0.8)
	t.tween_property(figura, "rotation:y", 0.0, duracao * 0.8)
	# A espessura de deitado volta a zero junto: de pe, os pes ficam no chao.
	t.tween_property(figura, "position:y", 0.0, duracao)
	# De pe, o corpo volta ao ciclo normal de parado/andando — sem isto ele
	# congelaria na ultima pose do levantar pelos catorze segundos das falas
	# seguintes, parado feito estatua enquanto fala.
	t.chain().tween_callback(func() -> void:
		figura.postura(Corpo.Postura.LIVRE))


## O cigarro na direita e o telefone na esquerda, pendurados nos ossos.
func _montar_maos(figura: Corpo) -> void:
	var esqueleto := figura.esqueleto()
	if esqueleto == null:
		return
	_cigarro = Adereco.new()
	Adereco.pendurar_em(esqueleto, figura.osso_da_mao(), _cigarro)
	_cigarro.montar(Adereco.Tipo.CIGARRO)
	# Em diagonal, como fica entre os dedos — e nao paralelo ao chao, que le
	# como apontador de laser.
	_cigarro.basis = Basis(Vector3.UP, 0.5) * Basis(Vector3.FORWARD, 0.34)

	_celular = Adereco.new()
	Adereco.pendurar_em(esqueleto, figura.osso_da_mao_esquerda(), _celular,
		Vector3(0.0, -0.26, 0.12))
	_celular.montar(Adereco.Tipo.CELULAR)
	# A tela virada para o rosto de quem segura, e um pouco deitada: e assim que
	# um telefone fica na mao de quem esta lendo alguma coisa nele.
	_celular.rotation = Vector3(deg_to_rad(-52.0), 0.0, deg_to_rad(14.0))
	_celular.brilho = 1.0


func _acender_apoio(onde: Vector3, frente: Vector3, tangente: Vector3) -> void:
	_apoio = OmniLight3D.new()
	_apoio.name = "ApoioDaAbertura"
	_apoio.light_color = APOIO_COR
	_apoio.light_energy = APOIO_ENERGIA
	_apoio.omni_range = APOIO_ALCANCE
	# Atenuacao baixa: a luz precisa chegar inteira nos dois metros do sujeito e
	# da bicicleta, e nao virar um ponto quente na testa dele.
	_apoio.omni_attenuation = 0.7
	_apoio.shadow_enabled = false
	_cena.add_child(_apoio)
	_apoio.global_position = (onde + frente * APOIO_ONDE.x
		+ Vector3.UP * APOIO_ONDE.y + tangente * APOIO_ONDE.z)


func _apagar_apoio() -> void:
	if _apoio == null or not is_instance_valid(_apoio):
		return
	# Apaga junto com o corte, e nao de estalo: a luz sumir num quadro entrega
	# que ela existia.
	var t := create_tween()
	t.tween_property(_apoio, "light_energy", 0.0, 0.4)
	t.tween_callback(_apoio.queue_free)
	_apoio = null


func _tem_chao(onde: Vector3) -> bool:
	var espaco := _cena.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(onde.x, 20.0, onde.z), Vector3(onde.x, -5.0, onde.z), 1)
	return not espaco.intersect_ray(consulta).is_empty()


func _chao_em(onde: Vector3) -> float:
	var espaco := _cena.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(onde.x, 20.0, onde.z), Vector3(onde.x, -5.0, onde.z), 1)
	var hit := espaco.intersect_ray(consulta)
	return (hit["position"] as Vector3).y if not hit.is_empty() else onde.y


# --- interiores -------------------------------------------------------------

## Entra num comodo e espera ele ficar de pe. Falso quando ele nao veio.
##
## Os dois planos de dentro precisam da mesma coisa, e nenhum dos dois pode
## ficar pendurado: a construcao roda em thread, e uma abertura que trava numa
## tela preta porque um comodo demorou e pior que uma abertura sem aquele plano.
func _entrar_no_comodo(semente: int, tipo: StringName) -> bool:
	Interiores.entrar(semente, _jogador.global_transform, tipo, true)
	var t0 := float(Time.get_ticks_msec()) / 1000.0
	while not Interiores.dentro:
		if float(Time.get_ticks_msec()) / 1000.0 - t0 > CASA_ESPERA_MAX:
			push_warning("Abertura: %s nao ficou pronto a tempo" % tipo)
			await Cinema.corte(0.1)
			return false
		await get_tree().process_frame
	return true


## Sai do comodo e devolve o jogador a parede em que ele estava encostado.
##
## `Interiores.sair` clareia a cortina DELE, que e outra camada. A daqui continua
## fechada, e e ela que o plano seguinte abre — senao o corte mostraria a rua um
## instante antes da hora.
func _sair_do_comodo(pose: Dictionary) -> void:
	if Interiores.dentro:
		await Interiores.sair()
	_jogador.global_transform = pose_para_transform(pose, _jogador.rotation.y)
	_jogador.zerar_velocidade()


# --- plano da praca ---------------------------------------------------------

## Posicao mundo de um osso do Corpo (apos _deitar).
func _ponto_osso(figura: Corpo, osso: int) -> Vector3:
	var sk := figura.esqueleto()
	if sk == null:
		return figura.global_position
	return (sk.global_transform * sk.get_bone_global_pose(osso)).origin


## Acordar na praca: POV ceu/nevoa, depois takes externos ainda deitado.
##
## Sem _levantar, sem props FP de pernas. Corpo fica no chao (pin 270,-40).
## Cada legenda = um take novo (corte / enquadramento).

func _plano_da_praca(pose: Dictionary) -> void:
	var onde: Vector3 = pose["onde"]
	var figura := _jogador.figura()

	# Cleiton: igreja ~271,-54.75 fachada; look axis ~271,-51; coreto ~264,-46 W.
	# (eixo igreja usado so como referencia — looks miram o torso, nao o telhado)

	# Lampiao quente a SW (esquerda do pin).
	if _apoio != null and is_instance_valid(_apoio):
		_apoio.global_position = Vector3(265.0, onde.y + 3.4, -40.0)
		_apoio.light_color = Color("ffb45a")
		_apoio.light_energy = 6.0
		_apoio.omni_range = 10.0

	# --- Part A: POV olho no ceu / nevoa (sem stand-up) --------------------
	_jogador.mostrar_corpo(false)
	if figura != null:
		figura.postura(Corpo.Postura.DEITADO_ACORDAR)

	var cam_olho := Vector3(onde.x, onde.y + 0.18, onde.z)
	# Quase reto pra cima: so nevoa/ceu. Desvio minimo em Z pro look_at.
	var olhar_ceu := Vector3(onde.x, onde.y + 22.0, onde.z - 0.8)
	var olhar_esq := Vector3(onde.x - 10.0, onde.y + 16.0, onde.z - 1.5)
	var olhar_dir := Vector3(onde.x + 10.0, onde.y + 16.0, onde.z - 1.5)

	Cinema.enquadrar(cam_olho, olhar_ceu, 70.0)

	if _hud != null:
		_hud.visible = true
	await Cinema.clarear(1.8)
	Cinema.legenda(FALAS["acorda"], 1.8)
	# Abrir o olho olhando o ceu, depois varrer esquerda -> direita (ainda nevoa).
	Cinema.mover(cam_olho, cam_olho, olhar_ceu, olhar_esq, 1.0, 70.0, 68.0)
	await get_tree().create_timer(1.0).timeout
	Cinema.mover(cam_olho, cam_olho, olhar_esq, olhar_dir, 1.35, 68.0, 68.0)
	await get_tree().create_timer(0.55).timeout
	await _capturar_plano("01_acordar_ceu")
	await get_tree().create_timer(0.85).timeout

	# --- Part B: takes externos, corpo AINDA DEITADO -----------------------
	# Look no TORSO (meio), nao no telhado da igreja. Cams CURTAS: denso come
	# tudo alem de ~4 m — corpo precisa dominar FG; igreja so peeks quando da.
	await Cinema.corte(0.14)
	_jogador.mostrar_corpo(true)
	if figura != null:
		_deitar(figura, true)
		figura.postura(Corpo.Postura.DEITADO_ACORDAR)

	var meio: Vector3 = pose["meio"]
	var torso := Vector3(meio.x, onde.y + 0.38, meio.z)

	# praca_1 - 3/4 SOUTH; corpo lower-third + porta cream legivel (pos-punch).
	var c1 := Vector3(torso.x - 1.15, onde.y + 3.85, torso.z + 2.7)
	var l1 := Vector3(torso.x + 0.35, onde.y + 1.05, torso.z - 2.4)
	Cinema.enquadrar(c1, l1, 50.0)
	await Cinema.clarear(0.35)
	Cinema.legenda(FALAS["praca_1"], 3.8)
	await get_tree().create_timer(0.55).timeout
	await _capturar_plano("02_deitado_igreja")
	await get_tree().create_timer(3.3).timeout

	# praca_2 — lower 3/4 from SW, perto; look no torso; coreto west a esq.
	await Cinema.corte(0.1)
	var c2 := Vector3(torso.x - 3.2, onde.y + 3.0, torso.z + 2.4)
	var l2 := Vector3(torso.x, onde.y + 0.4, torso.z)
	Cinema.enquadrar(c2, l2, 52.0)
	await Cinema.clarear(0.28)
	Cinema.legenda(FALAS["praca_2"], 3.2)
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_2")
	await get_tree().create_timer(2.8).timeout

	# praca_3 — perfil from east, look no torso (elevado o bastante pra ler deitado).
	await Cinema.corte(0.1)
	var c3 := Vector3(torso.x + 3.0, onde.y + 2.4, torso.z + 0.4)
	var l3 := Vector3(torso.x, onde.y + 0.42, torso.z)
	Cinema.enquadrar(c3, l3, 50.0)
	await Cinema.clarear(0.28)
	Cinema.legenda(FALAS["praca_3"], 3.4)
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_3")
	await get_tree().create_timer(3.0).timeout

	# praca_4 — closer 3/4 no torso/cabeca deitado.
	await Cinema.corte(0.1)
	var c4 := Vector3(torso.x + 0.9, onde.y + 1.55, torso.z + 1.7)
	var l4 := Vector3(torso.x, onde.y + 0.42, torso.z - 0.15)
	Cinema.enquadrar(c4, l4, 46.0)
	await Cinema.clarear(0.28)
	Cinema.legenda(FALAS["praca_4"], 3.2)
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_4")
	await get_tree().create_timer(2.8).timeout

	# praca_5 - establishing south mais largo; corpo lower-third + porta/torre peek.
	# Look torso+N (eixo ~271,-51) sem absoluto que some o corpo no denso.
	await Cinema.corte(0.1)
	var c5 := Vector3(torso.x - 1.5, onde.y + 4.8, torso.z + 4.0)
	var l5 := Vector3(torso.x + 0.5, onde.y + 1.2, torso.z - 3.5)
	Cinema.enquadrar(c5, l5, 56.0)
	await Cinema.clarear(0.28)
	Cinema.legenda(FALAS["praca_5"], 3.6)
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_5")
	await get_tree().create_timer(3.2).timeout

	if _hud != null:
		_hud.visible = false

	# Proximos planos escondem/re-posam o corpo; desfaz o deitar SEM animacao
	# de levantar (nao e stand-up cinematografico).
	if figura != null:
		_deitar(figura, false)
		figura.postura(Corpo.Postura.LIVRE)




## Ha vista livre entre estes dois pontos?
func _linha_livre(de: Vector3, ate: Vector3) -> bool:
	var mundo := _cena.get_world_3d()
	if mundo == null:
		return true
	var consulta := PhysicsRayQueryParameters3D.create(de, ate, 1)
	consulta.exclude = [_jogador.get_rid()]
	return mundo.direct_space_state.intersect_ray(consulta).is_empty()


## Centro da Praca da Matriz (Traco.PRACA) mais perto, ou Vector3.INF.
##
## Nao vale qualquer parque: parquinho/bosque/lago nao tem igreja+coreto. A
## abertura do acordar so enquadra a ref 01 se o miolo for Matriz.
static func _praca_mais_perto(de: Vector3) -> Vector3:
	var aqui := Vector2i(floori(de.x / Mapa.TAM), floori(de.z / Mapa.TAM))
	var melhor := Vector3.INF
	var melhor_d := INF
	for cz in range(aqui.y - PRACA_RAIO, aqui.y + PRACA_RAIO + 1):
		for cx in range(aqui.x - PRACA_RAIO, aqui.x + PRACA_RAIO + 1):
			var q := MalhaUrbana.quadra_de(cx, cz)
			if int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
				continue
			var plano := ParqueBuilder.planta(q)
			if int(plano["traco"]) != ParqueBuilder.Traco.PRACA:
				continue
			var local: Vector2 = plano["centro"]
			var c := Vector3(
				float(q["x0"]) * Mapa.TAM + local.x,
				0.0,
				float(q["z0"]) * Mapa.TAM + local.y)
			var d := Vector2(c.x - de.x, c.z - de.z).length()
			if d < melhor_d:
				melhor_d = d
				melhor = c
	return melhor


# --- plano da blitz ---------------------------------------------------------

## A barreira policial na saida da cidade.
##
## Pede uma ao BlitzManager e espera. Ela nao vem sempre — o gerador sorteia — e
## por isso o plano sabe desistir: sem blitz, a abertura pula direto para o
## mercado em vez de mostrar um pedaco de asfalto vazio com uma legenda sobre
## policia por cima.
func _plano_da_blitz(_pose: Dictionary) -> void:
	BlitzManager.semear()
	var t0 := float(Time.get_ticks_msec()) / 1000.0
	var qual: Blitz = null
	while qual == null:
		var vivas := BlitzManager.lista()
		if not vivas.is_empty():
			qual = vivas[0]
			break
		if float(Time.get_ticks_msec()) / 1000.0 - t0 > BLITZ_ESPERA_MAX:
			return
		await get_tree().process_frame

	await Cinema.escurecer(0.4)
	var alvo := qual.ponto_de_parada()
	Cinema.mover(alvo + BLITZ_DE, alvo + BLITZ_ATE,
		alvo + Vector3.UP * 0.9, alvo + Vector3.UP * 0.9,
		BLITZ_DURACAO, BLITZ_FOV)
	await Cinema.clarear(0.5)
	Cinema.legenda(FALAS["blitz"], 4.6)
	await get_tree().create_timer(1.0).timeout
	await _capturar_plano("03_blitz")
	await get_tree().create_timer(BLITZ_DURACAO - 2.0).timeout


# --- plano do mercado -------------------------------------------------------

## A loja de conveniencia, com o atendente e o cliente conversando no caixa.
##
## O plano existe pela fala que ele carrega: quarenta reais e fome. Uma loja e o
## unico lugar da cidade em que dinheiro quer dizer alguma coisa, e mostrar duas
## pessoas conversando no balcao diz de uma vez que a cidade e habitada e que ele
## nao tem com que comprar nada ali.
func _plano_do_mercado(pose: Dictionary) -> void:
	await Cinema.escurecer(0.55)
	_apagar_apoio()
	_jogador.mostrar_corpo(false)

	if not await _entrar_no_comodo(MERCADO_SEMENTE, &"mercado"):
		return

	var d := Interiores.DESLOCAMENTO
	Cinema.mover(d + MERCADO_DE, d + MERCADO_ATE,
		d + MERCADO_OLHAR_DE, d + MERCADO_OLHAR_ATE,
		MERCADO_DURACAO, MERCADO_FOV)
	await Cinema.clarear(0.6)
	_por_os_dois_para_conversar()
	# Duas linhas curtas, e nao uma longa. A frase inteira nao cabe na largura da
	# legenda: ela quebrava em duas linhas e a segunda encostava na tarja de
	# baixo, meio comida. E a mesma regra que as falas da praca ja seguem.
	await get_tree().create_timer(0.8).timeout
	await _capturar_plano("04_mercado")
	Cinema.legenda(FALAS["mercado_1"], 3.8)
	await get_tree().create_timer(4.1).timeout
	Cinema.legenda(FALAS["mercado_2"], 3.8)
	await get_tree().create_timer(MERCADO_DURACAO - 5.2).timeout

	await Cinema.escurecer(0.5)
	await _sair_do_comodo(pose)


## Poe o atendente e o cliente conversando um com o outro.
##
## Sem isto os dois ficam parados de frente um para o outro, o que le como duas
## pessoas que acabaram de brigar. O Convidado ja sabe conversar em par — e o que
## acontece sozinho na casa da fumaca — e aqui so falta alguem apresentar os dois.
func _por_os_dois_para_conversar() -> void:
	var gente: Array[Convidado] = []
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c != null:
			gente.append(c)
	if gente.size() < 2:
		return
	gente[0].iniciar_papo(gente[1], MERCADO_DURACAO + 4.0)


# --- planos da avenida ------------------------------------------------------

## A avenida principal, em dois planos separados por um corte.
##
## O primeiro do meio da pista, correndo no sentido dela; o segundo mais adiante
## na MESMA avenida, mais baixo e mais perto do meio-fio. Sao dois porque a fala
## do segundo — "parece que essa avenida nao tem fim" — precisa que o jogador ja
## tenha visto a primeira: um corte para OUTRO pedaco da mesma avenida, igual ao
## anterior, e o que faz a frase ser verdade em vez de informacao.
func _plano_da_avenida(_pose: Dictionary) -> void:
	await Cinema.escurecer(0.4)
	_apagar_apoio()
	_jogador.mostrar_corpo(false)

	var av := _avenida_mais_perto(_jogador.global_position)
	if av.is_empty():
		return

	# --- plano A: o meio da avenida ---
	var centro: Vector3 = av["centro"]
	centro = await _levar_para(centro)
	var ao_longo: Vector3 = av["direcao"]

	Cinema.mover(
		centro - ao_longo * AVENIDA_A_RECUO.x + Vector3.UP * AVENIDA_A_ALTURA.x,
		centro - ao_longo * AVENIDA_A_RECUO.y + Vector3.UP * AVENIDA_A_ALTURA.y,
		centro + ao_longo * AVENIDA_A_OLHAR.x + Vector3.UP * 1.6,
		centro + ao_longo * AVENIDA_A_OLHAR.y + Vector3.UP * 1.6,
		AVENIDA_A_DURACAO, AVENIDA_A_FOV.x, AVENIDA_A_FOV.y)
	await Cinema.clarear(0.6)
	Cinema.legenda(FALAS["avenida_1"], 3.8)
	await get_tree().create_timer(1.2).timeout
	await _capturar_plano("02_avenida_a")
	await get_tree().create_timer(AVENIDA_A_DURACAO - 2.4).timeout

	# --- plano B: mais adiante, na mesma avenida ---
	await Cinema.escurecer(0.45)
	var alem := centro + ao_longo * AVENIDA_B_AVANCO
	alem = await _levar_para(alem)
	_ultimo_ponto_da_avenida = alem
	var atravessa := ao_longo.cross(Vector3.UP).normalized()

	Cinema.mover(
		alem - ao_longo * AVENIDA_B_RECUO.x + atravessa * AVENIDA_B_LADO.x
			+ Vector3.UP * AVENIDA_B_ALTURA.x,
		alem - ao_longo * AVENIDA_B_RECUO.y + atravessa * AVENIDA_B_LADO.y
			+ Vector3.UP * AVENIDA_B_ALTURA.y,
		alem + ao_longo * AVENIDA_B_OLHAR.x + Vector3.UP * 1.5,
		alem + ao_longo * AVENIDA_B_OLHAR.y + Vector3.UP * 1.5,
		AVENIDA_B_DURACAO, AVENIDA_B_FOV.x, AVENIDA_B_FOV.y)
	await Cinema.clarear(0.5)
	Cinema.legenda(FALAS["avenida_2"], 3.8)
	await get_tree().create_timer(1.2).timeout
	await _capturar_plano("02_avenida_b")
	await get_tree().create_timer(AVENIDA_B_DURACAO - 2.4).timeout


## Muda o jogador de lugar e espera o bairro novo ficar de pe.
##
## Devolve onde ele parou de verdade, ja com o chao medido pela fisica — e nao o
## ponto pedido. Um raio para baixo aqui erraria pelo mesmo motivo que errou no
## parque: ele acerta banco, poste e placa e devolve a altura da coisa em que
## bateu. Deixar cair e perguntar depois nao tem como discordar do mundo.
##
## O teto de espera existe para a abertura nunca ficar pendurada num pedaco de
## cidade que nao veio: passado ele, o plano roda com o que houver na tela.
func _levar_para(ponto: Vector3) -> Vector3:
	_jogador.global_position = Vector3(ponto.x, ponto.y + 1.2, ponto.z)
	_jogador.zerar_velocidade()
	var alvo := ChunkManager.coord_de(ponto)
	for _k in ESPERA_BAIRRO:
		await get_tree().physics_frame
		if _bairro_pronto(alvo) and _jogador.is_on_floor():
			break
	return _jogador.global_position


## Os nove chunks em volta ja estao montados?
##
## Os nove, e nao so o de baixo dos pes: os planos da avenida olham trinta metros
## adiante, que e um chunk inteiro alem do que o jogador esta pisando.
func _bairro_pronto(centro: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if not ChunkManager.esta_carregado(centro + Vector2i(dx, dz)):
				return false
	return true


## A avenida mais proxima, e para que lado ela corre.
##
## AVENIDA, e nao "a via mais larga por perto". A malha garante uma a cada cinco
## linhas de grade, ou seja no maximo oitenta metros de qualquer ponto, entao
## nunca ha o caso de nao achar nenhuma e ter de aceitar uma rua no lugar.
##
## Le so a malha, que e uma funcao pura da coordenada: responde com a cidade
## inteira descarregada.
static func _avenida_mais_perto(de: Vector3) -> Dictionary:
	var aqui := Vector2i(floori(de.x / MalhaUrbana.TAM), floori(de.z / MalhaUrbana.TAM))
	var melhor: Dictionary = {}
	var melhor_d := INF
	for k in range(-AVENIDA_BUSCA, AVENIDA_BUSCA + 1):
		# A via mora SOBRE a linha de grade, em x = i * 32, e nao no meio do
		# chunk: o eixo da pista e a fronteira entre dois chunks, que e onde os
		# dois desenham meia pista cada um.
		var ix := aqui.x + k
		if MalhaUrbana.via_x(ix) == MalhaUrbana.Via.AVENIDA:
			var cx := float(ix) * MalhaUrbana.TAM
			var dx := absf(cx - de.x)
			if dx < melhor_d:
				melhor_d = dx
				melhor = {"centro": Vector3(cx, de.y, de.z),
					"direcao": Vector3(0.0, 0.0, 1.0)}
		var iz := aqui.y + k
		if MalhaUrbana.via_z(iz) == MalhaUrbana.Via.AVENIDA:
			var cz := float(iz) * MalhaUrbana.TAM
			var dz := absf(cz - de.z)
			if dz < melhor_d:
				melhor_d = dz
				melhor = {"centro": Vector3(de.x, de.y, cz),
					"direcao": Vector3(1.0, 0.0, 0.0)}
	return melhor


# --- plano do poste ---------------------------------------------------------

## Ele encostado no poste, e a camera descendo do alto ate a cara dele.
##
## Este e o plano que fecha a abertura, e ele fecha porque termina exatamente
## onde a primeira pessoa comeca: a camera para a 2,35 m dele, na altura dos
## olhos, o preto entra, e o que abre do outro lado e a vista dele daquele mesmo
## ponto, com a bituca ja na boca. Nenhum outro plano da cena poderia fazer isso
## — todos os outros estao ou dentro de um comodo ou a dezenas de metros.
##
## O poste vem do gerador, e nao de uma varredura de nos. `ChunkBuilder` decide
## onde ele fica por conta pura da coordenada, e responde antes mesmo de o chunk
## existir: da para escolher o poste, mudar o jogador de lugar e so entao esperar
## o bairro montar em volta dele.
func _plano_do_poste(_pose: Dictionary) -> void:
	await Cinema.escurecer(0.5)
	_jogador.mostrar_corpo(false)

	var de := _jogador.global_position
	if _ultimo_ponto_da_avenida != Vector3.INF:
		de = _ultimo_ponto_da_avenida
	var base := _poste_mais_perto(de)
	if base == Vector3.INF:
		base = _jogador.global_position

	# De que lado do mastro ele fica. Testado, e nao deduzido: o poste fica 80 cm
	# do meio-fio e o resto da calcada esta do lado de dentro, mas de que lado e
	# "dentro" depende de qual das quatro bordas do chunk e a iluminada. Oito
	# sondagens em volta e ficar com a de chao mais alto acha a calcada sem
	# precisar saber nada disso: ela esta 16 cm acima do asfalto.
	var fora := _lado_da_calcada(base)
	var onde := base + fora * POSTE_ENCOSTO
	onde = await _levar_para(onde)

	# Encostado de costas para o mastro, olhando para a rua — que e para onde a
	# camera esta descendo.
	_jogador.rotation.y = atan2(-fora.x, -fora.z)
	_jogador.zerar_velocidade()
	_jogador.mostrar_corpo(true)
	var figura := _jogador.figura()
	if figura != null:
		figura.postura(Corpo.Postura.ENCOSTADO)
		if _cigarro == null or not is_instance_valid(_cigarro):
			_montar_maos(figura)

	# A bicicleta vem junto. A abertura acaba aqui e a partida comeca aqui: ela
	# ficar quatro planos atras, no parque, seria o jogador ganhar o controle ao
	# lado de nada.
	if _bike != null and is_instance_valid(_bike):
		var ao_lado := onde + fora.cross(Vector3.UP).normalized() * AO_LADO_DA_BICICLETA
		ao_lado.y = _chao_em(ao_lado)
		_bike.global_position = ao_lado
		_bike.rotation.y = _jogador.rotation.y
		_bike.encostar_em_parede()

	var lado := fora.cross(Vector3.UP).normalized()
	_acender_apoio(onde, fora, lado)

	# A descida. Comeca acima da altura do braco do poste (6,6 m) e termina na
	# altura dos olhos: o mastro entra no quadro por inteiro no comeco e sai por
	# cima no fim, o que da a queda uma referencia de escala. Sem ele, uma camera
	# descendo doze metros sobre uma calcada le como camera parada.
	Cinema.mover(
		onde + fora * POSTE_RECUO.x + Vector3.UP * POSTE_ALTURA.x,
		onde + fora * POSTE_RECUO.y + Vector3.UP * POSTE_ALTURA.y,
		onde + Vector3.UP * POSTE_OLHAR.x,
		onde + Vector3.UP * POSTE_OLHAR.y,
		POSTE_DURACAO, POSTE_FOV.x, POSTE_FOV.y)
	await Cinema.clarear(0.6)
	await get_tree().create_timer(1.4).timeout
	await _capturar_plano("06_poste")

	Cinema.legenda(FALAS["poste_1"], 3.8)
	await get_tree().create_timer(4.0).timeout
	Cinema.legenda(FALAS["poste_2"], 3.6)
	await get_tree().create_timer(3.8).timeout
	Cinema.legenda(FALAS["poste_3"], 4.2)
	await get_tree().create_timer(POSTE_DURACAO - 7.8).timeout

	# O preto da emenda. Mais longo que os outros cortes de proposito: e o unico
	# ponto da abertura em que a imagem troca de dono, de camera de cinema para
	# olho do jogador, e um preto curto entregaria que os dois estao no mesmo
	# lugar por um quadro de sobreposicao.
	await Cinema.escurecer(0.7)
	_jogador.mostrar_corpo(false)


## De que lado do poste esta a calcada, em direcao unitaria.
##
## A calcada fica 16 cm acima do asfalto (`KitModular.ALTURA_MEIO_FIO`), e essa
## diferenca de altura e a unica pergunta que o mundo gerado responde sem
## ambiguidade. Oito sondagens em volta do mastro, e ganha a de chao mais alto.
func _lado_da_calcada(base: Vector3) -> Vector3:
	var melhor := Vector3.FORWARD
	var melhor_y := -INF
	for k in 8:
		var a := TAU * float(k) / 8.0
		var dir := Vector3(sin(a), 0.0, cos(a))
		var y := _chao_em(base + dir * 1.1)
		if y > melhor_y:
			melhor_y = y
			melhor = dir
	return melhor


## O poste de iluminacao mais proximo, ou Vector3.INF.
##
## Sai do gerador, que decide onde cada poste fica por conta pura da coordenada.
## Procurar por no na cena so acharia os dos chunks carregados agora, e o plano
## precisa escolher o poste ANTES de mudar o jogador de lugar — que e o que faz
## o chunk dele carregar.
static func _poste_mais_perto(de: Vector3) -> Vector3:
	var aqui := Vector2i(floori(de.x / MalhaUrbana.TAM), floori(de.z / MalhaUrbana.TAM))
	var melhor := Vector3.INF
	var melhor_d := INF
	for dz in range(-POSTE_BUSCA, POSTE_BUSCA + 1):
		for dx in range(-POSTE_BUSCA, POSTE_BUSCA + 1):
			var cx := aqui.x + dx
			var cz := aqui.y + dz
			if not ChunkBuilder.tem_poste(cx, cz):
				continue
			var pos := ChunkBuilder.posicao_poste(cx, cz)
			var d := Vector2(pos.x - de.x, pos.z - de.z).length()
			if d < melhor_d:
				melhor_d = d
				melhor = pos
	return melhor


# --- plano 2 ----------------------------------------------------------------

## Dentro da casa da fumaca, com a gente que mora nela.
##
## O corpo do jogador some antes de entrar. `Interiores` teleporta quem esta no
## grupo `player` para a porta do comodo, e com o corpo visivel o sujeito
## apareceria de pe na entrada, encostado numa parede que nao existe ali,
## fumando um cigarro no meio do plano.
func _plano_da_casa(pose: Dictionary) -> void:
	await Cinema.escurecer(0.55)
	_apagar_apoio()
	_jogador.mostrar_corpo(false)

	if not await _entrar_no_comodo(_semente_da_casa(), &"casa_fumaca"):
		return

	var d := Interiores.DESLOCAMENTO
	Cinema.mover(d + CASA_DE, d + CASA_ATE, d + CASA_OLHAR_DE, d + CASA_OLHAR_ATE,
		CASA_DURACAO, CASA_FOV)
	await Cinema.clarear(0.6)
	_animar_a_sala()
	await get_tree().create_timer(1.0).timeout
	await _capturar_plano("05_casa_fumaca")
	Cinema.legenda(FALAS["casa"], 6.2)
	await get_tree().create_timer(CASA_DURACAO - 1.2).timeout

	await Cinema.escurecer(0.5)
	await _sair_do_comodo(pose)


## Uma risada logo no comeco do plano, e ela contagia as outras.
##
## Sem isto o comodo tambem funciona — os convidados conversam e riem sozinhos —
## mas o riso cai onde calhar, e num plano de oito segundos ele pode nao cair
## nenhuma vez. A cena precisa dele nos primeiros dois, que e quando a legenda
## sobre o tipo de gente que mora aqui esta na tela.
func _animar_a_sala() -> void:
	await get_tree().create_timer(1.2).timeout
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or not c.fumando:
			continue
		c.gargalhar()
		c.contagiar()
		return


## A semente da casa que a missao vai mandar procurar.
##
## Quando ainda nao ha missao — um caminho de teste, por exemplo — vale a casa
## mais proxima do respawn, que e a mesma que a missao escolheria.
func _semente_da_casa() -> int:
	if not Missoes.atual.is_empty():
		var alvo: Dictionary = Missoes.atual["alvo"]
		return int(alvo["semente"])
	var perto := Missoes.casa_mais_perto(_jogador.global_position)
	return int(perto.get("semente", 77551))




## Grava um PNG do viewport quando a abertura roda com `--ver-abertura`.
## Serve para o PO conferir cada plano sem ficar colado na janela.
func _capturar_plano(nome: String) -> void:
	var args := OS.get_cmdline_user_args()
	if not (args.has("--ver-abertura") or args.has("--ver-praca")):
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_warning("Abertura: captura %s falhou (viewport vazio)" % nome)
		return
	var abs_path := ProjectSettings.globalize_path("res://captures/abertura/%s.png" % nome)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := image.save_png(abs_path)
	if err != OK:
		push_warning("Abertura: falha ao gravar %s (erro %d)" % [abs_path, err])
		return
	print("[abertura] captura %s (%dx%d)" % [abs_path, image.get_width(), image.get_height()])
	# Task AAA praca: espelho em captures/praca_matriz/cine/ (raiz do repo).
	if (nome.begins_with("01_acordar") or nome.begins_with("02_deitado")
			or nome.begins_with("praca_")):
		var game_dir := ProjectSettings.globalize_path("res://").rstrip("/\\")
		var cine_dir := game_dir.path_join("..").path_join("captures").path_join("praca_matriz").path_join("cine")
		DirAccess.make_dir_recursive_absolute(cine_dir)
		var cine := cine_dir.path_join("%s.png" % nome)
		var err2 := image.save_png(cine)
		if err2 == OK:
			print("[abertura] cine %s" % cine)
		else:
			push_warning("Abertura: falha cine %s (erro %d)" % [cine, err2])

static func pose_para_transform(pose: Dictionary, giro: float) -> Transform3D:
	var onde: Vector3 = pose["onde"]
	return Transform3D(Basis(Vector3.UP, giro), onde)


# --- plano 3 ----------------------------------------------------------------

## Primeira pessoa: a bituca na boca, o ultimo trago e o cigarro no chao.
##
## Aqui a camera volta a ser a do jogador. Nao e economia: o plano inteiro
## depende de a imagem estar exatamente onde os olhos dele estao, porque o que
## entra no quadro — o cigarro no canto da boca, a mao subindo de baixo — esta
## pendurado no pivo da cabeca. Com uma camera solta no mundo, os dois teriam de
## ser recolocados a cada quadro para acompanhar.
func _plano_da_bituca(_pose: Dictionary) -> void:
	Cinema.devolver()
	_jogador.mostrar_corpo(false)
	_jogador.definir_pitch(deg_to_rad(-12.0))
	_jogador.definir_fov(62.0)

	# O cigarro sai da mao e vai para a boca. E o mesmo objeto: o plano anterior
	# mostrou ele aceso na mao direita, e um cigarro novo aqui seria outro.
	var pivo := _jogador.pivo()
	if _cigarro != null:
		_reparentar(_cigarro, pivo)
		_cigarro.position = BITUCA_NA_BOCA
		_cigarro.rotation = Vector3(deg_to_rad(BITUCA_GIRO.x),
			deg_to_rad(BITUCA_GIRO.y), deg_to_rad(BITUCA_GIRO.z))
		# Meio maior que o da mao. Nao e trapaca de escala por preguica: o que
		# esta a doze centimetros do olho e o cigarro visto de esguelha por quem
		# o tem na boca, e nessa distancia o olho humano o ve muito maior do que
		# a projecao de um objeto de sete centimetros. Todo jogo em primeira
		# pessoa aumenta o que esta na mao pelo mesmo motivo.
		_cigarro.scale = Vector3.ONE * 1.5
		_cigarro.brilho = 0.15
	if _celular != null:
		# O telefone volta para o bolso fora de quadro. Ele ja contou o que
		# tinha para contar no primeiro plano.
		_celular.queue_free()
		_celular = null

	await Cinema.clarear(0.7)
	await get_tree().create_timer(TRAGO_ESPERA).timeout
	await _capturar_plano("07_bituca")

	await _ultimo_trago()
	await _jogar_fora()

	Cinema.legenda(FALAS["bituca"], 5.4)
	await get_tree().create_timer(5.6).timeout


## A brasa cresce, a fumaca engrossa, e a imagem fecha um pouco junto.
##
## O campo de visao apertando dois graus e o truque inteiro. Ele nao le como
## zoom: le como alguem parando de olhar em volta por um segundo, que e o que
## acontece quando se puxa fumaca.
func _ultimo_trago() -> void:
	if _cigarro == null:
		return
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_cigarro, "brilho", 1.0, TRAGO_PUXA)
	t.tween_method(_jogador.definir_fov, 62.0, 60.0, TRAGO_PUXA)
	await t.finished
	await get_tree().create_timer(TRAGO_SEGURA).timeout

	# Solta. A brasa cai de volta ao fio baixo e a fumaca sai pela frente, que e
	# uma coluna propria: a do cigarro sobe da brasa, e esta sai da boca.
	AudioDirector.tocar_ui(&"estufa_ar", -24.0)
	_soprar()
	var t2 := create_tween().set_parallel(true)
	t2.set_ease(Tween.EASE_OUT)
	t2.tween_property(_cigarro, "brilho", 0.22, TRAGO_SOLTA)
	t2.tween_method(_jogador.definir_fov, 60.0, 62.0, TRAGO_SOLTA)
	await t2.finished


## A fumaca soprada: um par de quads cruzados que crescem a frente do rosto e
## somem. Nasce e morre dentro deste plano, entao nao vale um arquivo proprio.
func _soprar() -> void:
	var dados := PSXMesh.dados_vazios()
	for giro: float in [0.0, PI * 0.5]:
		var d := PSXMesh.placa_dados(Vector2(0.30, 0.30), 0.15,
			Color(1.0, 1.0, 1.0, 0.85))
		PSXMesh.acumular(dados, d, Transform3D(Basis(Vector3.UP, giro), Vector3.ZERO))
	_fumaca_soprada = MeshInstance3D.new()
	_fumaca_soprada.name = "FumacaSoprada"
	_fumaca_soprada.mesh = PSXMesh.dados_para_mesh(dados)
	var mat := (load(Adereco.MATERIAL_FUMACA) as ShaderMaterial).duplicate() as ShaderMaterial
	_fumaca_soprada.material_override = mat
	_fumaca_soprada.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_jogador.pivo().add_child(_fumaca_soprada)
	_fumaca_soprada.position = Vector3(0.0, -0.05, -0.42)
	_fumaca_soprada.scale = Vector3.ONE * 0.35

	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Cresce, afasta e some. As tres coisas juntas: fumaca que so cresce le como
	# explosao, e fumaca que so some le como falha de desenho.
	t.tween_property(_fumaca_soprada, "scale", Vector3.ONE * 2.1, 2.0)
	t.tween_property(_fumaca_soprada, "position:z", -1.05, 2.0)
	t.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("densidade", v), 1.4, 0.0, 2.0)
	t.chain().tween_callback(func() -> void:
		if is_instance_valid(_fumaca_soprada):
			_fumaca_soprada.queue_free())


## A mao entra no quadro, tira o cigarro da boca e joga no chao.
func _jogar_fora() -> void:
	_montar_mao_no_quadro()
	if _mao == null or _cigarro == null:
		return

	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_mao, "position", MAO_NA_BOCA, MAO_SOBE)
	await t.finished

	# A mao pega o cigarro: ele passa a ser filho dela e desce junto.
	_reparentar(_cigarro, _mao)
	_cigarro.position = Vector3(0.0, 0.012, -0.055)
	AudioDirector.tocar_ui(&"papel", -22.0)

	var t2 := create_tween()
	t2.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t2.tween_property(_mao, "position", MAO_FORA + Vector3(0.10, -0.14, 0.05),
		MAO_DESCE)
	await t2.finished

	_soltar_a_bituca()
	_mao.queue_free()
	_mao = null

	# A camera baixa para ver onde ela caiu. E o unico jeito de a jogada
	# terminar em alguma coisa: sem isto o cigarro sai de quadro e o plano
	# acaba com o jogador olhando para a rua vazia.
	var t3 := create_tween()
	t3.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t3.tween_method(_jogador.definir_pitch, deg_to_rad(-12.0),
		deg_to_rad(OLHAR_O_CHAO), 0.9)
	await t3.finished


## A bituca de verdade, no chao, apagando devagar.
##
## E outro objeto: o da mao tem sete centimetros e este tem tres. Trocar um pelo
## outro no instante em que ele sai do quadro e o que faz o cigarro parecer
## fumado — o mesmo bastao inteiro caido na calcada leria como cigarro novo
## jogado fora, que e outra personagem.
func _soltar_a_bituca() -> void:
	if _cigarro != null:
		_cigarro.queue_free()
		_cigarro = null

	_bituca = Adereco.new()
	_cena.add_child(_bituca)
	_bituca.montar(Adereco.Tipo.CIGARRO, true)
	_bituca.brilho = 0.7

	var base := _jogador.global_position
	var frente := -_jogador.global_transform.basis.z
	var lado := _jogador.global_transform.basis.x
	var chao := base + frente * -BITUCA_NO_CHAO.z + lado * BITUCA_NO_CHAO.x
	chao.y = _chao_em(chao) + Adereco.CIGARRO_GROSSURA
	_bituca.global_position = base + Vector3.UP * 1.15 + frente * 0.3
	# Deitada na calcada, atravessada. Um cigarro no chao nunca cai alinhado com
	# nada.
	_bituca.rotation = Vector3(0.0, randf() * TAU, 0.0)

	var t := create_tween()
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_bituca, "global_position", chao, BITUCA_QUEDA)
	# A brasa vai morrendo no chao. Nao apaga de vez: ela ainda esta acesa
	# quando o jogo comeca, e quem olhar para baixo nos primeiros segundos vai
	# ver o ponto laranja na calcada.
	t.parallel().tween_property(_bituca, "brilho", 0.18, 3.0)


## Antebraco e mao, no campo de visao.
##
## Sao duas caixas e a pele da ficha do jogador — a mesma cor e a mesma celula
## do atlas que o corpo dele usa. Uma mao generica aqui seria a primeira vez que
## o jogo mostraria uma parte do jogador que nao e ele.
func _montar_mao_no_quadro() -> void:
	var ficha := RegistroCivil.jogador
	var aparencia: Dictionary = ficha.get("aparencia", {})
	var pele: Color = aparencia.get("pele", Color(0.78, 0.62, 0.50))

	var dados := PSXMesh.dados_vazios()
	var cel_mao := Aparencia.uv_da_celula(Aparencia.PECA_MAO, Aparencia.LINHA_PECAS)
	var cel_pele := Aparencia.uv_da_celula(Aparencia.PECA_NUCA, Aparencia.LINHA_PECAS)
	# O antebraco entra pelo fundo do quadro, entao ele e comprido: cortado
	# curto, a mao parece flutuar sem braco quando sobe.
	_caixa(dados, Vector3(0.082, 0.082, 0.30), Vector3(0.0, -0.055, 0.16),
		cel_pele, pele)
	_caixa(dados, Vector3(0.086, 0.048, 0.105), Vector3(0.0, 0.0, -0.015),
		cel_mao, pele)

	_mao = MeshInstance3D.new()
	_mao.name = "MaoDoQuadro"
	(_mao as MeshInstance3D).mesh = PSXMesh.dados_para_mesh(dados)
	(_mao as MeshInstance3D).material_override = load(Corpo.MATERIAL) as Material
	(_mao as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_jogador.pivo().add_child(_mao)
	_mao.position = MAO_FORA
	# Inclinada, como um antebraco que sobe de baixo e nao um pistao.
	_mao.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(-13.0), deg_to_rad(9.0))


func _caixa(dados: Dictionary, tamanho: Vector3, centro: Vector3, celula: Rect2,
		cor: Color) -> void:
	var d := PSXMesh.box_dados(tamanho, 100.0, 100.0, Color.WHITE)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = celula.position + Vector2(clampf(uvs[k].x, 0.0, 1.0),
			clampf(uvs[k].y, 0.0, 1.0)) * celula.size
	d["uv"] = uvs
	PSXMesh.acumular_tingido(dados, d, Transform3D(Basis(), centro), cor)


static func _reparentar(quem: Node3D, novo_pai: Node) -> void:
	var pai := quem.get_parent()
	if pai != null:
		pai.remove_child(quem)
	novo_pai.add_child(quem)


# --- plano 4 ----------------------------------------------------------------

## As tarjas abrem, a missao comeca e o GPS sobe na mao ja no filtro certo.
##
## O aparelho abre sozinho de proposito. A primeira etapa e marcar um endereco
## num aplicativo com sete filtros e cinco escalas, e mandar o jogador descobrir
## a tecla `M` sozinho no meio de uma cidade infinita seria pedir para ele
## desistir da missao antes de comecar. Ele abre ja na categoria CASA VERDE, com
## a lista ordenada por distancia — o que sobra para o jogador e escolher e
## apertar E, que e exatamente a licao.
func _entregar_o_jogo() -> void:
	_jogador.definir_pitch(0.0)
	_jogador.liberar_fov()
	await Cinema.encerrar()

	Missoes.comecar_primeira(_jogador.global_position)
	await get_tree().create_timer(0.9).timeout
	Gps.abrir()
	Gps.filtrar_por(&"casa_fumaca")
	await get_tree().create_timer(0.8).timeout
	await _capturar_plano("08_tarjas_gps")
	if OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-praca"):
		print("[abertura] roteiro completo - encerrando captura")
		await get_tree().create_timer(0.4).timeout
		get_tree().quit()

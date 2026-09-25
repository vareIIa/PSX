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

## As chaves do acordar e do levantar (tempos e poses). Ver `ChavesDoAcordar`.
const _K := preload("res://src/render/chaves_do_acordar.gd")

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
## O fim da descida fica na altura do olho do jogador (`Player.ALTURA_OLHO`),
## que e onde a primeira pessoa abre, e mira o peito e nao a cara: mirando a
## 1,52 m, a cintura dele — o cigarro numa mao e o telefone na outra — caia na
## faixa da legenda, e o plano que existe para mostrar o sujeito fumando e
## mexendo no celular mostrava so a cabeca.
const POSTE_ALTURA := Vector2(12.5, 1.62)
const POSTE_RECUO := Vector2(4.6, 2.35)
const POSTE_OLHAR := Vector2(0.95, 1.28)
const POSTE_FOV := Vector2(66.0, 58.0)
const POSTE_DURACAO := 12.0
## A que distancia do mastro as costas dele param, e a quantos chunks procurar
## um poste.
const POSTE_ENCOSTO := 0.42
const POSTE_BUSCA := 2
## O cigarro do poste: quanto ja queimou, a semente do jeito de fumar, e em que
## segundo da descida a mao sai do repouso para a tragada funda (ver
## `_plano_do_poste`: com 3 s o sopro para o alto cai entre 8,6 e 11 s, com a
## camera chegando, e a nuvem ja se desfaz quando ela para na cara dele — com
## 4,4 s a nuvem ficava em volta da cabeca no quadro final, como uma aureola).
const POSTE_QUEIMOU := 0.42
const POSTE_FUMO_SEMENTE := 1998
const POSTE_TRAGADA_EM := 3.0

## Quanto tempo esperar o pedaco de cidade novo ficar de pe depois de mudar o
## jogador de lugar, em quadros de fisica.
const ESPERA_BAIRRO := 420

# --- plano da praca ---------------------------------------------------------
## Acordar na Praca da Matriz. Pin 270,-40; a fachada da capela fica quinze
## metros ao norte. O corpo, as poses e as maos de primeira pessoa sao do
## `AcordarNaPraca` (as chaves em `ChavesDoAcordar`, medidas pela pele em
## `tests/medir_acordar.gd`); aqui ficam o roteiro, as cameras e os tempos.
##
## Ele cai de costas com a CABECA para a igreja e os pes para o sul. Deitado
## assim, o olho que desce pelo proprio corpo ve a praca do lado de la dos pes,
## e a igreja fica atras da cabeca ate a revelacao do TAKE 5 — onde ele, ja de
## pe, esta de frente para ela.
## Onde esta a fachada da igreja, em relacao ao pin em que ele acorda.
##
## O mapa poe a igreja em ~(271, -54,75) e o pin em (270, -40) - quinze metros ao
## norte. Escrito como DESLOCAMENTO e nao como coordenada absoluta: se o pin do
## acordar mudar, o take da igreja acompanha em vez de apontar para o vazio.
const IGREJA_DA_PRACA := Vector3(1.0, 0.0, -14.75)
## Bicicleta: do lado oposto ao dos planos, a este tanto do corpo.
const ACORDA_LADO := 1.95

## --- TAKE 0: o olho ----------------------------------------------------------
##
## A camera e o olho dele, preso ao osso da cabeca: quando ele vira o rosto,
## apoia nos cotovelos ou cai de volta, a imagem vai junto, porque e o corpo que
## se mexe e nao uma camera fingindo. A caixa da cabeca e os bracos de caixa sao
## recolhidos, e no lugar dos bracos entram os `BracoVivo` da cabine do carro
## (mao com dedo, unha e pele): os mesmos que ele tinha no volante minutos
## antes.
##
## O olho abre por palpebra (`PalpebraDaLente`), e nao por fade: meio aberto,
## borrado e dobrado enquanto o branco esfria, duas piscadas pesadas, e so
## depois o foco. A mao direita sobe na frente do rosto e treme; ele olha a
## palma, os dedos abrem e fecham, a mao vira. Depois apoia nos cotovelos, as
## pernas entram no quadro, um joelho sobe — e os bracos cedem.
const OLHO_ABRE := 0.28
const OLHO_BORRAO := 4.5
const OLHO_DUPLO := 0.014

## --- TAKES 1 e 2: caido, de cima ---------------------------------------------
##
## Zenital: a camera em cima dele, com a cabeca no alto do quadro. E o unico
## angulo em que um corpo deitado de costas mostra o corpo inteiro E o rosto de
## pe — de qualquer lado, de meia altura, a cara sai de cabeca para baixo ou de
## perfil, e o corpo vira uma lamina. A igreja fica fora (esta alem da cabeca,
## e a lente olha para o chao). A camera gira devagar enquanto ele esta
## apagado, e no TAKE 2 desce sem corte ate o rosto, que e onde os olhos abrem.
## Pontos relativos ao tronco (TAKE 1) e a cabeca (TAKE 2); o alto do quadro e
## para onde a cabeca aponta.
const ZENITAL_DE: Array[Vector3] = [Vector3(0.3, 2.75, 0.2), Vector3(0.08, 2.62, 0.08)]
const ZENITAL_OLHA := Vector3(0.0, 0.0, -0.14)
const ZENITAL_FOV := 52.0
const ZENITAL_DURACAO := 4.3
const ROSTO_ATE: Array[Vector3] = [Vector3(0.12, 1.5, 0.35), Vector3(0.06, 1.0, 0.2)]
const ROSTO_OLHA := Vector3(0.0, 0.04, 0.02)
const ROSTO_FOV := 44.0
const ROSTO_DURACAO := 3.3

## --- TAKE 3: o levantar, de longe -------------------------------------------
##
## De helicoptero, e nao colada nele: pedido do usuario ("a camera nao tem que
## ficar em cima dele, ela deve ficar mais longe, distante, como camera de
## helicoptero"), com a aerea da estrada de referencia. Alta e atras dele, do
## sul, olhando para o norte: ele pequeno no meio do calcamento, a luz da igreja
## caindo nele atraves da nevoa, e a igreja no alto do quadro. Um plano so, sem
## corte, descendo e fechando devagar enquanto ele se levanta — quem assiste ve
## um homem sozinho tentando ficar de pe numa praca que o observa.
## Pontos relativos ao lugar em que ele fica de pe.
##
## A 20 m e mirando nele, a igreja (14,75 m atras) so entrava pela soleira. A
## camera fica mais longe e a mira vai para o chao entre ele e a igreja: ele no
## terco de baixo, acima da legenda, e a fachada com a porta acesa no alto.
const HELI: Array[Vector3] = [Vector3(-9.0, 12.5, 25.0), Vector3(-6.6, 10.3, 21.8),
	Vector3(-4.2, 8.2, 18.8)]
const HELI_MIRA := Vector3(0.4, 0.3, -6.0)
const HELI_FOV := Vector2(38.0, 34.0)

## --- TAKE 4: o olhar em volta ------------------------------------------------
##
## "Deveria olhar 360. Para todos os lados, inclusive passando pela frente do
## rosto dele." A camera da uma volta inteira nele, na altura do rosto, rapida
## nas costas e devagar na frente: comeca atras do ombro direito (a mao na nuca,
## onde bateu), passa pela direita enquanto ele procura para a esquerda, chega
## na frente quando ele levanta o rosto para a torre — a luz da igreja na cara
## dele, a lente um pouco abaixo do olho —, segue pela esquerda e, quando a
## respiracao calma da estrada volta pela esquerda, ele vira por cima do ombro
## esquerdo DIRETO para a lente. Nao tem ninguem ali: quem esta ali e a camera.
## A volta fecha atras dele, no mesmo eixo do TAKE 5.
##
## Mira: o meio da cabeca, um pouco abaixo. A 1 m e com a tarja do cinema, a
## caixa da cabeca mirada pela base saia com o topo cortado em meia volta.
const ORBITA_MIRA := Vector3(0.0, 0.1, 0.0)
## O quanto o olho vai na frente da cabeca, em rad do `olhar_lateral`: pequeno,
## para o pescoco interno do Corpo (dominado aqui) chegar em ~0,3 s e o olho
## voltar ao meio como numa sacada.
const OLHO_ANTES := 0.3

## --- A luz da igreja --------------------------------------------------------
##
## "Bastante nevoa e luzes da igreja iluminando nosso personagem." Um facho
## quente que sai da porta da capela, passa por cima do muro do adro e cai nele.
## Com a nevoa volumetrica o facho existe no ar entre a igreja e o corpo; com
## sombra, ele deixa no calcamento a sombra comprida do homem caido, apontando
## para longe da igreja.
const IGREJA_LUZ_COR := Color("ffc47e")
## Forte de proposito: a 16 m, com a atenuacao, sobra ~2,5 nele. E a poca que
## faz o olho achar um homem pequeno no meio da nevoa.
const IGREJA_LUZ_ENERGIA := 40.0
const IGREJA_LUZ_ALCANCE := 26.0
const IGREJA_LUZ_ABERTURA := 9.0
## Onde ela nasce, contada da fachada: no alto, na janela do coro, e nao acima
## da porta. Da porta (2,7 m) o facho raspava o chao e deitava uma mancha
## comprida que a nevoa comia; do alto ele desce pelo ar ate ele, e o cone
## aparece na nevoa inteiro.
const IGREJA_LUZ_ONDE := Vector3(0.0, 7.5, 1.0)
## Quanto o facho acende o ar (a nevoa volumetrica).
const IGREJA_LUZ_AR := 4.0

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
## A loja da RUA, e nao o comodo teleportado.
##
## O comodo teleportado e a mesma planta montada dois mil metros acima da
## cidade, e a frente dele e um painel fosco (`mercado_vidro`, quase branco): de
## dentro, a vitrine inteira saia como uma fileira de fotos brancas. A loja da
## rua tem vidro de verdade, e do outro lado dele esta a rua de verdade, na
## noite da abertura. "No game em si, no mercado de verdade, nao ta assim."
##
## A camera vem da rua, de frente para a vitrine acesa na nevoa, entra pela
## porta automatica (que abre sozinha, porque o corpo escondido dele esta no
## sensor) e vira para o caixa, onde o atendente e o cliente conversam. O ar
## muda quando a LENTE passa a porta (`_ar_da_loja`), e nao o jogador.
##
## Pontos em coordenada de planta (`MercadoBuilder`): x ao longo da fachada, z
## para dentro (a rua e z negativo), y do piso. A porta e x = CENTRO_PORTA (11);
## o balcao e x = 6,14; atendente e cliente ficam em z = 2,35.
##
## Ela termina no corredor do balcao (entre ele, em x = 6,74, e a primeira ilha,
## em x = 9,38), olhando de volta para o caixa: atendente e cliente se encaram
## ao longo de x, entao de dentro do salao, de frente para a porta, os dois
## ficam lado a lado — e atras deles o vidro e a rua escura. Terminando perto da
## porta e olhando ao longo de x, o cliente tapava o atendente. A 1,72 m ela
## passa por cima do monitor do caixa, que no nivel do olho tapava o atendente.
const MERCADO_CAMINHO: Array[Vector3] = [Vector3(13.2, 1.45, -5.0), Vector3(12.0, 1.5, -2.6),
	Vector3(11.1, 1.58, -0.6), Vector3(10.4, 1.62, 1.3), Vector3(9.1, 1.64, 2.8),
	Vector3(7.7, 1.72, 5.0)]
const MERCADO_MIRA: Array[Vector3] = [Vector3(10.5, 1.5, 2.0), Vector3(10.8, 1.45, 3.5),
	Vector3(10.2, 1.4, 4.8), Vector3(7.6, 1.38, 4.6), Vector3(6.4, 1.35, 3.0),
	Vector3(6.15, 1.3, 2.35)]
const MERCADO_FOV := Vector2(54.0, 48.0)
const MERCADO_DURACAO := 9.5
## O corpo escondido dele: sai da rua e para na calcada, dentro do sensor da
## porta (1,45 m para fora) e antes da soleira da loja (0,7 m): a porta abre e
## fica aberta, a loja fica viva, e o ar da loja nao e trocado por ele.
const MERCADO_PORTADOR_DE := Vector3(12.6, 0.0, -4.2)
const MERCADO_PORTADOR_ATE := Vector3(11.0, 0.0, -1.05)
const MERCADO_PORTADOR_TEMPO := Vector2(0.5, 3.6)
## O ar da loja da rua (o mesmo que `MercadoBuilder` da a ela).
const MERCADO_AR := "res://resources/fog/fog_mercado_rua.tres"
## Onde procurar a loja, em chunks a partir de onde ele esta, e quanto esperar
## ela montar.
const MERCADO_RAIO := 12
const MERCADO_ESPERA_MAX := 20.0

# --- plano 2: a casa da fumaca ----------------------------------------------
## Em coordenada de planta da casa (ver CasaFumacaBuilder): a camera entra pelo
## canto da porta e vai andando para dentro, na diagonal, em direcao a TV — que
## e onde estao os dois que jogam e a maior parte da luz do comodo.
## O que a primeira composicao errava, lido na captura e nao no codigo:
##
##   o quarto direito do quadro era a bancada e a estante — um bloco laranja de
##   240 px sem nada acontecendo nele, 25% da tela
##   a TV media 5% da largura, e ela e o motivo de o comodo existir
##   os dois jogadores ficavam pequenos e fora do centro, sendo o assunto
##   o centro-esquerda era vazio marrom
##
## A camera agora corre BAIXA e por DENTRO, na altura do olho de quem esta
## sentado no chao, e termina a um metro e meio do jogador sentado — com ele
## entre a lente e o tubo. E o enquadramento que a propria Televisao promete no
## cabecalho dela: "faz a silhueta de quem esta sentado na frente".
##
## O percurso passa a direita da mesa de centro (x > 3,26, que e a quina da
## caixa de colisao dela) e deixa a bancada para tras da lente, fora do quadro.
## E a camera fica FORA do eixo do facho, de proposito.
##
## A segunda tentativa correu por dentro dele — x 3,45 a 3,80, quase na linha do
## tubo — e o cone sumiu da captura inteira. Um facho e geometria somada: de
## lado ele atravessa o quadro, de dentro ele fica de perfil e nao tem o que
## mostrar. Um metro e meio para oeste resolve, e ainda poe o cone cruzando o
## espaco entre a lente e a TV, que e onde a fumaca esta.
## A lente termina a 92 cm, que e a altura do OLHO de quem esta sentado no chao
## — o mesmo sujeito que abriu esta frente de trabalho com o quadril flutuando a
## 37 cm e o pe dentro do piso. A 1,10 ele ficava acima da cabeca dele e a tarja
## de baixo cortava o corpo pela metade.
const CASA_DE := Vector3(2.30, 1.05, 3.55)
const CASA_ATE := Vector3(2.95, 0.92, 4.35)
## A mira termina NAS PESSOAS, e nao na TV atras delas.
##
## A tentativa anterior mirava em (4,75 / 6,10), tres metros e meio adiante: o
## tubo e o facho saiam bonitos e os dois jogadores viravam vulto no canto —
## num plano cuja legenda e "Eu sei la que tipo de gente mora nessa cidade".
##
## Mirando no sentado, a geometria do comodo faz o resto sozinha: ele cai no
## centro, o que esta de pe fica a 21 graus para a direita, a TV a 21 para a
## esquerda com o facho cruzando entre os dois, e a parede leste — seis metros
## de reboco vazio que comia o terco direito do quadro — sai a 35 graus do eixo,
## fora do meio-campo de 29 que o FOV de 58 enxerga.
const CASA_OLHAR_DE := Vector3(4.70, 1.00, 5.85)
const CASA_OLHAR_ATE := Vector3(4.80, 0.92, 5.30)
const CASA_FOV := 58.0
const CASA_DURACAO := 9.5
## Quanto o plano espera o comodo ficar pronto antes de desistir. A construcao
## roda em thread e leva uns poucos quadros; o teto existe para a abertura nunca
## travar para sempre por causa de um comodo que nao veio.
const CASA_ESPERA_MAX := 8.0

# --- plano 3: a bituca ------------------------------------------------------
## O ultimo cigarro, em primeira pessoa: a mao sobe com ele ate a boca, o ultimo
## trago acende a brasa, a fumaca sai, e o peteleco joga a bituca na calcada,
## onde ela quica soltando faisca e fica acesa.
##
## A mao e um `BracoVivo` (a do acordar: dedos, antebraco e braco ate o ombro)
## e o cigarro, um `Cigarro` livre entre o indicador e o medio. As poses sao no
## referencial do OLHO: -Z a frente, +X a direita, +Y para cima. Cada uma diz
## onde o cigarro passa entre os dedos (`pega`), para onde a brasa aponta
## (`eixo`) e para onde os dedos apontam (`dedos`); a mao sai dai.
const MAO_OMBRO := Vector3(0.17, -0.22, 0.06)
const MAO_POLO := Vector3(0.7, -0.7, 0.15)
## Entre um trago e outro: a mao na frente do peito, embaixo e a direita do
## quadro, o cigarro de brasa para cima e o fio subindo na frente da rua.
const POSE_DESCANSO := {"pega": Vector3(0.115, -0.105, -0.32),
	"eixo": Vector3(0.40, 0.80, -0.45), "dedos": Vector3(-0.35, 0.40, -0.85)}
## Na boca: a mao na frente dos labios, as costas para a rua e os dedos para o
## alto, e o cigarro saindo para a frente pelo vao dos dedos. A boca de verdade
## fica 37 graus abaixo do olho, fora do quadro e atras da tarja: a mao sobe um
## pouco mais que a boca e a cabeca baixa junto (`BITUCA_CABECA_BAIXA`), que e o
## que faz quem traga olhando para a frente.
const POSE_NA_BOCA := {"pega": Vector3(0.018, -0.047, -0.14),
	"eixo": Vector3(0.12, 0.62, -0.77), "dedos": Vector3(-0.86, 0.30, -0.40)}
const BITUCA_CABECA_BAIXA := -11.0
## Armando o peteleco: o braco estica para a frente e para a direita.
const POSE_PETELECO := {"pega": Vector3(0.15, -0.14, -0.38),
	"eixo": Vector3(0.25, 0.45, -0.86), "dedos": Vector3(-0.20, 0.25, -0.95)}
## Depois de jogar: a mao desce e sai do quadro por baixo.
const POSE_FORA := {"pega": Vector3(0.22, -0.55, -0.20),
	"eixo": Vector3(0.3, 0.3, -0.9), "dedos": Vector3(-0.1, -0.3, -0.95)}
## Os dedos segurando o cigarro: indicador e medio quase retos e juntos, anelar
## e minimo dobrados para dentro.
const DEDOS_CIGARRO := {"dedos": [[20, 28, 14, 2], [22, 30, 16, -1], [58, 72, 40, -4],
	[66, 74, 38, -9]], "polegar": [38, 32, 28, 12, 14]}
## Onde o vao do indicador com o medio fica, contado do meio da palma na linha
## dos nos: ao longo dos dedos e para o lado do polegar. E quanto o cigarro
## inclina do dorso para a ponta dos dedos.
const VAO_AO_LONGO := 0.03
const VAO_AO_LADO := 0.011
const INCLINA_NOS_DEDOS := 0.3

## A boca, no referencial do olho, e para onde o sopro sai.
const BOCA_NO_OLHO := Vector3(0.0, -0.08, -0.085)
const DIR_DO_SOPRO := Vector3(0.04, -0.22, -1.0)

## Tempos do plano (s): espera, a mao sobe, a puxada, a mao desce, o ar preso,
## o sopro, e armar o peteleco.
const BITUCA_ESPERA := 1.5
const BITUCA_SOBE := 0.85
const BITUCA_PUXA := 1.4
const BITUCA_DESCE := 0.7
const BITUCA_PRENDE := 0.4
const BITUCA_SOPRA := 2.3
const BITUCA_ARMA := 0.4

## O peteleco: velocidade de saida (m/s) no referencial do olho, o giro
## (rad/s) e o quanto cada quique devolve.
## Pouco mais de um metro: com tres metros por segundo a bituca caia a tres e
## meio do olho, na borda de cima do quadro, e so o fio de fumaca aparecia.
const PETELECO := Vector3(0.35, 0.9, -1.6)
const PETELECO_GIRO := 17.0
const QUIQUE := Vector2(0.28, 0.35)
## Quanto do cigarro ja queimou quando o plano abre: o poste acabou de fumar a
## metade de cima. O ultimo trago leva ate a bituca (`Cigarro.QUEIMA_BITUCA`).
const BITUCA_QUEIMOU := 0.47

## Quanto a camera baixa acompanhando o voo, em graus, e o quadro fechado em
## cima da bituca parada.
const OLHAR_O_CHAO := -40.0
const BITUCA_FOV_NO_CHAO := 20.0

# --- textos -----------------------------------------------------------------
## Uma frase por plano, e nenhuma explica o que a imagem ja mostra.
## As falas da abertura, ACENTUADAS e sem placeholder.
##
## Estavam em ASCII — "Ultima", "Cade", "nao", "Sao Thome" — como se a fonte nao
## tivesse acento. Tem: `psx_titulo.fnt` traz os 152 glifos, e o `á` mede 10x14
## contra 10x10 do `a`, ou seja o acento esta no bitmap. O HUD ja escrevia
## "PRAÇA DA MATRIZ" com cedilha na mesma tela.
##
## Tres linhas mudaram de conteudo, e nao so de acento:
##
## `praca_3` era "E eu acordo no meio de uma praca" — narrava a imagem, que e o
## que o jogador esta vendo. Agora ela e o beat de quem se levanta sem entender
## o proprio corpo, que e o take onde ela toca.
##
## `poste_3` era "Sao Thome, a galera, a pousada... tudo sumiu da minha cabeca",
## mas ele nomeia os tres corretamente na estrada e na praca, minutos antes. A
## amnesia e do TRECHO, nao das pessoas.
##
## `avenida_2` abria com "Sem maldade", que e como `dentro_1` abre. Duas vezes em
## dez linhas gasta o bordao que e a frase-chave do jogo.
##
## E `acorda` era "..." — tres pontos brancos sozinhos na tela nao sao um plano.
## O plano do olho abrindo nao precisa de legenda nenhuma.
const FALAS := {
	"praca_1": "Última coisa que eu lembro era o farol na terra.",
	"praca_2": "Aí... apagou. Tipo, do nada.",
	"praca_3": "Meu corpo tá inteiro. Então por que eu tô no chão?",
	"praca_4": "Cadê o carro? Cadê a estrada?",
	"praca_5": "Isso aqui não é a pousada. Nem de longe.",
	"avenida_1": "Tem gente. Tem luz. Mas não parece... normal.",
	"avenida_2": "Eu não reconheço nada disso. Nem o cheiro.",
	"blitz": "Blitz. A essa hora, nessa cidade.",
	"mercado_1": "Tenho uns quarenta reais no bolso.",
	"mercado_2": "E tô morrendo de fome.",
	"casa": "Eu sei lá que tipo de gente mora nessa cidade...",
	"poste_1": "Não tem sinal. Não tem placa. Não tem ninguém pra perguntar.",
	"poste_2": "Não era pra eu ter pegado essa estrada.",
	"poste_3": "Da estrada até essa praça não tem nada. Só apagado.",
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
## O cigarro no corpo dele (poste) e o da mao de primeira pessoa (bituca).
var _cigarro: Cigarro
var _celular: Adereco
var _mao: BracoVivo
var _cig_pov: Cigarro
var _baforada_pov: FumacaParticulas
## A pose da mao de primeira pessoa: de onde, para onde, o arco e os dedos.
var _pose_de: Dictionary = {}
var _pose_para: Dictionary = {}
var _pose_k: float = 1.0
var _pose_dur: float = 1.0
var _pose_arco := Vector3.ZERO
var _dedos_de: Dictionary = {}
var _dedos_para: Dictionary = {}
## O cigarro ainda esta entre os dedos (a mao o carrega a cada quadro).
var _cig_na_mao: bool = true
## A bituca voando depois do peteleco (velocidade e giro no mundo).
var _voando: bool = false
var _voo := Vector3.ZERO
var _giro_voo := Vector3.ZERO
var _quiques: int = 0
signal _bituca_pousou
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
## O FogController seguia as Settings antes de a abertura impor a noite? Para
## devolver exatamente o que havia. Ver `_impor_a_noite`.
var _seguia_settings := false
## Os moradores da praca que a abertura parou para assistir. Ver
## `_juntar_a_plateia`.
var _plateia: Array[Convidado] = []
## O corpo dele no acordar e no levantar (poses, olho, maos). Ver `AcordarNaPraca`.
var _acordar: AcordarNaPraca
## Bancada: rajada (`--praca-rajada=`), e o relogio das marcas `[praca]`.
var _rajada: RajadaDeCena
var _t0: float = 0.0
var _luz_igreja: SpotLight3D

## A plateia do acordar: quem mora na praca para, longe, e fica olhando.
##
## Os moradores andam pela praca sozinhos, e nos takes do levantar um deles
## parou exatamente entre a lente e o sujeito — o protagonista virou um vulto
## atras do ombro de um figurante, na fala "meu corpo ta inteiro, entao por que
## eu to no chao?". Tirar os moradores da praca resolveria o quadro e mataria a
## praca. Parar os moradores LONGE, do lado para onde as cameras olham, e fazer
## todos eles encararem o homem caido resolve o quadro e da a cena o que ela
## estava pedindo desde a primeira linha: ninguem vem ajudar, todo mundo olha.
##
## Raio de quem entra na plateia, e a que distancia do corpo eles ficam. O
## ponto sai da propria rota de cada morador, que e chao onde ele sabe andar.
const PLATEIA_RAIO := 32.0
const PLATEIA_PERTO := 9.0
const PLATEIA_IDEAL := 14.0


## Roda a abertura inteira e some. Devolve so quando o jogador ja tem o controle.


func executar(cena: Node3D, jogador: Player, nasceu_em: Vector3) -> void:
	_cena = cena
	_jogador = jogador
	_nasceu_em = nasceu_em

	Cinema.fechar_de_imediato()
	Cinema.iniciar(true)
	_montar_bancada()

	var pose := await _preparar_cenario()
	# A ordem nao e decorativa. Os tres primeiros planos sao de fora e podem
	# acontecer com o corpo dele posado na parede; os dois de dentro teleportam o
	# jogador para outro comodo e teriam de desmontar a pose toda vez. Fazer os
	# exteriores primeiro custa duas transicoes de interior em vez de quatro.
	# Bancada: `--abertura-desde=mercado` pula a praca, a avenida e a blitz;
	# `--abertura-desde=poste` pula tudo ate o poste (o fumo e a bituca).
	var args := OS.get_cmdline_user_args()
	if args.has("--abertura-desde=poste"):
		_impor_a_noite()
		# O corpo sai do acordar como sai no fim da praca: de pe e solto.
		if _acordar != null:
			_acordar.soltar()
		await _plano_do_poste(pose)
		if _encerrar_na_bancada(&"poste"):
			return
		await _plano_da_bituca(pose)
		await _entregar_o_jogo()
		queue_free()
		return
	if args.has("--abertura-desde=mercado"):
		_impor_a_noite()
	else:
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
	if _encerrar_na_bancada(&"casa"):
		return
	# O poste vem por ultimo entre os planos de fora porque ele nao e um plano:
	# e a emenda. A camera desce ate a cara dele, o preto entra e a primeira
	# pessoa abre no mesmo ponto — ver `_plano_do_poste`. Posto antes da blitz,
	# como a ordem da conversa sugeria, essa descida terminaria num corte para
	# dentro de um mercado e a passagem nao existiria.
	await _plano_do_poste(pose)
	await _plano_da_bituca(pose)
	await _entregar_o_jogo()
	queue_free()



## HUD compartilhado (mesmo de Estrada Velha). Valores da print da Praça.
func _preparar_cenario() -> Dictionary:
	var origem := _nasceu_em
	# Pin Cleiton/Jota: 270,-40 olhando norte. Lampiao SW (~265,-40) a esquerda;
	# coreto 272,-48 + igreja ao norte no reach.
	const PIN_ACORDAR := Vector3(270.0, 0.0, -40.0)
	# A altura do nascimento e medida do chao de onde a cena nasce (o
	# parquinho, metros abaixo da praca no morro — Relevo); o pin leva a mesma
	# folga acima do chao DELE.
	var folga := origem.y - Relevo.altura(origem.x, origem.z)
	origem = Vector3(PIN_ACORDAR.x, Relevo.altura(PIN_ACORDAR.x, PIN_ACORDAR.z) + folga,
		PIN_ACORDAR.z)
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
		_mostrar_aderecos(false)
		# Caido de costas, a cabeca para a igreja. Quem deita e o quadril, por
		# chaves com alvo de mao e pe: o no do corpo fica de pe e parado, e nada
		# boia nem gira como prancha. Ver `AcordarNaPraca`.
		_acordar = AcordarNaPraca.new()
		_acordar.name = "AcordarNaPraca"
		add_child(_acordar)
		_acordar.montar(_cena, _jogador)
		_jogador.mostrar_corpo(true)

	# De que lado o plano vai filmar. Decidido AQUI, e nao no plano, porque a
	# bicicleta precisa saber para ir para o outro: com ela do mesmo lado, os dois
	# pneus enchiam o quadro e o sujeito caido aparecia por baixo do quadro dela.
	# Dos pes para a cabeca: a cabeca esta para a frente do jogador, e o meio do
	# corpo deitado fica trinta e cinco centimetros atras de onde ele levanta.
	var eixo := frente
	var lado := eixo.cross(Vector3.UP).normalized()
	var meio := onde - eixo * 0.35
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


## O telefone na mao esquerda, pendurado no osso. O cigarro da direita e outra
## coisa: ver `_acender_o_cigarro`.
func _montar_maos(figura: Corpo) -> void:
	var esqueleto := figura.esqueleto()
	if esqueleto == null:
		return
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
	if _luz_igreja != null and is_instance_valid(_luz_igreja):
		var ti := create_tween()
		ti.tween_property(_luz_igreja, "light_energy", 0.0, 0.4)
		ti.tween_callback(_luz_igreja.queue_free)
		_luz_igreja = null
	if _apoio == null or not is_instance_valid(_apoio):
		return
	# Apaga junto com o corte, e nao de estalo: a luz sumir num quadro entrega
	# que ela existia.
	var t := create_tween()
	t.tween_property(_apoio, "light_energy", 0.0, 0.4)
	t.tween_callback(_apoio.queue_free)
	_apoio = null


## A luz da igreja no homem caido. Ver o bloco "A luz da igreja" no topo.
func _acender_igreja(onde: Vector3) -> void:
	var fachada := onde + IGREJA_DA_PRACA
	_luz_igreja = SpotLight3D.new()
	_luz_igreja.name = "LuzDaIgreja"
	_luz_igreja.light_color = IGREJA_LUZ_COR
	_luz_igreja.light_energy = IGREJA_LUZ_ENERGIA
	_luz_igreja.spot_range = IGREJA_LUZ_ALCANCE
	_luz_igreja.spot_angle = IGREJA_LUZ_ABERTURA
	_luz_igreja.spot_attenuation = 0.9
	_luz_igreja.spot_angle_attenuation = 1.6
	_luz_igreja.shadow_enabled = true
	_luz_igreja.light_volumetric_fog_energy = IGREJA_LUZ_AR
	_cena.add_child(_luz_igreja)
	_luz_igreja.global_position = Vector3(fachada.x, onde.y, fachada.z) + IGREJA_LUZ_ONDE
	_luz_igreja.look_at(onde + Vector3(0.0, 0.3, 0.3), Vector3.UP)


## O raio sai de 20 m acima do chao do morro (Relevo) e vai ate 5 m abaixo dele.
func _tem_chao(onde: Vector3) -> bool:
	var espaco := _cena.get_world_3d().direct_space_state
	var chao := Relevo.altura(onde.x, onde.z)
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(onde.x, chao + 20.0, onde.z), Vector3(onde.x, chao - 5.0, onde.z), 1)
	return not espaco.intersect_ray(consulta).is_empty()


func _chao_em(onde: Vector3) -> float:
	var espaco := _cena.get_world_3d().direct_space_state
	var chao := Relevo.altura(onde.x, onde.z)
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(onde.x, chao + 20.0, onde.z), Vector3(onde.x, chao - 5.0, onde.z), 1)
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
	# `Interiores.sair` LIBERA a nevoa — devolve o preset escolhido pelo jogador
	# para a rua, que e o certo para quem sai de uma loja no meio do jogo e o
	# errado aqui: a abertura estava na noite da praca e, depois do mercado, os
	# dois ultimos planos de rua saiam na neblina cinza-clara do padrao, com
	# cara de meio-dia — o poste e a bituca fotografados as 23:15 num dia
	# nublado. A noite volta a ser imposta a cada saida, e so e liberada de
	# verdade quando o jogo e entregue.
	_impor_a_noite()
	_jogador.global_transform = pose_para_transform(pose, _jogador.rotation.y)
	_jogador.zerar_velocidade()


## A noite da abertura, por cima do que o jogador escolheu para a rua.
##
## E o preset da Praca da Matriz, o mesmo em que ele acorda: os planos de rua
## que vem depois — avenida, blitz, poste, bituca — sao a mesma noite vista de
## outros lugares, e trocar de ar entre um plano e outro entregaria que a
## cidade e um preset e nao um lugar.
##
## Duas camadas, e nao uma. `forcar` poe a noite por cima de tudo; mas varias
## coisas da cidade chamam `liberar` por conta propria — a saida de um comodo, a
## soleira de uma loja na rua, o mirante — e cada uma delas devolveria a rua ao
## preset ESCOLHIDO pelo jogador no meio da cena. Entao a noite entra tambem
## como o preset de BASE do controller (`override_preset`, com `follow_settings`
## desligado): quem liberar no meio da abertura cai na noite, e nao na neblina
## de meio-dia. `_liberar_a_noite` desfaz as duas.
func _impor_a_noite() -> void:
	var fog := _fog_da_cena()
	if fog == null:
		return
	if fog.follow_settings:
		_seguia_settings = true
		fog.follow_settings = false
		fog.override_preset = load(_preset_da_praca()) as FogPreset
	fog.forcar(_preset_da_praca())


## A noite da abertura: a da praca (`praca_noite`) com a nevoa fechada, "bastante
## nevoa" pedido para o levantar. Comparados no mesmo plano de helicoptero:
## `praca_noite` e `estrada_noite` quase nao tem nevoa de longe; `neblina` e
## `denso` sao cinza de dia e apagam a noite; os de chuva poem gota na lente do
## helicoptero. Esta comeca em 12 m e fecha em 44 m (ele a ~20 m da lente fica
## legivel, com um quarto de nevoa; a igreja
## a ~36 m sai da nevoa como vulto) e tem cor de ar aceso pelos postes, e nao de
## escuro: nevoa escura a exposicao automatica so clareia de volta.
##
## A praca do jogo continua na `praca_noite` (`FogController.PRESET_PRACA`).
const NOITE_DA_ABERTURA := "res://resources/fog/fog_praca_nevoa.tres"


## O preset da noite da praca. Bancada: `--praca-nevoa=<nome>` troca por
## `res://resources/fog/fog_<nome>.tres`, para comparar os ares do projeto no
## mesmo plano.
static func _preset_da_praca() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--praca-nevoa="):
			var caminho := "res://resources/fog/fog_%s.tres" % a.trim_prefix("--praca-nevoa=")
			if ResourceLoader.exists(caminho):
				return caminho
			push_warning("Abertura: nevoa %s nao existe" % caminho)
	return NOITE_DA_ABERTURA


func _liberar_a_noite() -> void:
	var fog := _fog_da_cena()
	if fog == null:
		return
	if _seguia_settings:
		fog.follow_settings = true
		_seguia_settings = false
	fog.liberar()


func _fog_da_cena() -> FogController:
	var fog := _cena.get_node_or_null("Ambiente") as FogController
	if fog == null:
		fog = _cena.get_tree().get_first_node_in_group(&"fog_controller") as FogController
	return fog


# --- plano da praca ---------------------------------------------------------

## A cinematica nao tem HUD.
##
## Ela ja teve: barra de vida, icone de lanterna e o cartao LOCAL/HORA ficavam
## na tela durante os cinco takes. Duas coisas davam errado ao mesmo tempo. O
## cartao ocupa o mesmo canto que a legenda usa quando o texto e longo, e as
## cinco falas saiam escritas por cima de "LOCAL: PRAÇA DA MATRIZ" — nao se lia
## nenhuma das duas. E a barra de vida com a lanterna anuncia CONTROLE numa cena
## em que o jogador nao tem controle nenhum e o sujeito esta desmaiado no chao,
## sem lanterna na mao. HUD e da parte jogavel; aqui e cinema.
##
## O texto do lugar, se um dia fizer falta, e trabalho de cartao de abertura —
## sozinho no quadro, antes de alguem falar — e nao de HUD ligado por tras da
## legenda.
func _plano_da_praca(pose: Dictionary) -> void:
	var onde: Vector3 = pose["onde"]
	var figura := _jogador.figura()
	# Noite da Matriz: sem wash do fog_denso (cinza claro). Luz = postes.
	var fog := _cena.get_node_or_null("Ambiente") as FogController
	if fog == null:
		fog = _cena.get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		_impor_a_noite()
		print("[abertura] fog Matriz -> %s" % _preset_da_praca().get_file())

	# Lampiao quente RASANTE no corpo, e nao cinco metros a oeste.
	#
	# Ele ficava em (265, +3,4) — cinco metros de lado e tres e meio de altura,
	# ou seja luz de cima e de longe. Nos dois primeiros takes, que sao os que
	# olham o sujeito caido de perto e de baixo, o corpo media 30 contra 97 do
	# calcamento: massa preta sobre pedra clara, sem uma aresta. Silhueta assim
	# nao le como pessoa, le como buraco no chao.
	#
	# A dois metros e a um metro e meio de altura a luz RASPA o corpo deitado: o
	# ombro, o quadril e o joelho pegam o quente e o resto fica no escuro. E o
	# recorte que faz a forma virar gente. Alcance curto de proposito — e chave
	# de figura, nao iluminacao de praca.
	if _apoio != null and is_instance_valid(_apoio):
		_apoio.global_position = Vector3(onde.x + 1.9, onde.y + 1.5, onde.z + 1.3)
		_apoio.light_color = Color("ffb45a")
		# Tres e pouco, e nao seis.
		#
		# A seis o lampiao virava o assunto do quadro: o calcamento embaixo dele
		# media (58,48,31) contra os (33,25,13) da print, quase o dobro de claro
		# e muito mais quente, e a fachada da igreja chegava alaranjada. Na print
		# a luz de poste e um HALO — brilha forte no vidro e morre em dois metros
		# de chao. Quem ilumina a praca ali e a nevoa, nao a lampada.
		_apoio.light_energy = 2.6
		_apoio.omni_range = 7.0

	_acender_igreja(onde)

	# A plateia ja esta parada quando ele abre o olho: quem mora na praca viu
	# ele cair, e o primeiro plano de fora ja os encontra olhando.
	var caido := _acordar.ponto(Corpo.Osso.TORSO) if _acordar != null else onde
	_juntar_a_plateia(caido)

	# Bancada: `--praca-desde=levantar` pula o olho e os dois planos de cima;
	# `--praca-desde=olhar` pula tambem o levantar.
	var desde_olhar := OS.get_cmdline_user_args().has("--praca-desde=olhar")
	var desde_levantar := desde_olhar 		or OS.get_cmdline_user_args().has("--praca-desde=levantar")

	# --- TAKE 0: O OLHO ---------------------------------------------------
	if not desde_levantar:
		await _plano_do_olho()

	# --- TAKE 1: CAIDO, DE CIMA -------------------------------------------
	# Desmaiado de novo, olhos fechados. Ver o bloco "TAKES 1 e 2" no topo.
	var frente := -_jogador.global_basis.z
	if not desde_levantar and _acordar != null and figura != null:
		_acordar.tocar(ChavesDoAcordar.chaves_deitado(figura))
		_acordar.folego = 0.7
		if figura.rosto != null:
			figura.rosto.expressao(Rosto.Expressao.DESACORDADO)
	if not desde_levantar:
		await _planos_de_cima(figura, frente)

	# --- TAKE 3: O LEVANTAR ------------------------------------------------
	if not desde_olhar:
		await Cinema.corte(0.12)
		await _plano_do_levantar(onde, figura)
		if _encerrar_na_bancada(&"levantar"):
			return

	# --- TAKE 4: O OLHAR EM VOLTA ------------------------------------------
	await _plano_do_olhar(figura)
	if _encerrar_na_bancada(&"olhar"):
		return

	var corpo := figura.global_position if figura != null else onde
	var torso := Vector3(corpo.x, corpo.y + 0.04, corpo.z)

	# TAKE 5 - A IGREJA. A revelacao, guardada desde o TAKE 1.
	#
	# Contra-plongee da base da fachada, com a torre e a cruz entrando contra a
	# nevoa, e ele em silhueta pequena no primeiro plano. A camera fica ATRAS
	# dele: nao da para po-la entre ele e a igreja sem tirar o sujeito do quadro.
	var igreja := onde + IGREJA_DA_PRACA
	var c5 := Vector3(torso.x - 1.6, onde.y + 1.30, torso.z + 5.0)
	var l5 := Vector3(igreja.x, onde.y + 3.2, igreja.z)
	await Cinema.corte(0.1)
	Cinema.enquadrar(c5, l5, 58.0)
	await Cinema.clarear(0.28)
	await get_tree().create_timer(0.4).timeout
	Cinema.legenda(FALAS["praca_5"], 3.6)
	await _capturar_plano("praca_5")
	await get_tree().create_timer(3.2).timeout
	if figura != null:
		figura.postura(Corpo.Postura.LIVRE)
	_desfazer_a_plateia()




## TAKE 0 — o olho. Ver o bloco "TAKE 0" no topo do arquivo.
##
## Tempos pelo relogio das chaves (`ChavesDoAcordar.ACORDAR_*`), e nao por
## timer: se um quadro engasga, mao, dedo, palpebra e som continuam no mesmo
## instante do corpo.
func _plano_do_olho() -> void:
	var a := _acordar
	var figura := _jogador.figura()
	var branco := _cena.get_node_or_null("BrancoDoSusto") as BrancoDoSusto
	if a == null or figura == null:
		if branco != null:
			Cinema.clarear(0.05)
			await branco.dissolver(2.4)
		else:
			await Cinema.clarear(1.8)
		return
	await a.entrar_no_olho_aquecido()
	a.tocar(_K.chaves_acordar(figura))
	a.folego = 1.4
	a.tremor = 1.6
	var olho := a.palpebra()
	olho.abertura = OLHO_ABRE
	olho.borrao = OLHO_BORRAO
	olho.duplo = OLHO_DUPLO
	_marca("olho")
	# Vindo do susto da estrada, a tela ja esta BRANCA (`BrancoDoSusto`): o
	# branco esfria ate o cinza do ceu e o olho, meio aberto, esta embaixo.
	if branco != null:
		Cinema.clarear(0.05)
		branco.dissolver(2.4)
	else:
		Cinema.clarear(1.4)
	a.som(&"ofegante", -22.0, 0.94)

	# Duas piscadas pesadas: a primeira nao acerta o foco, a segunda quase.
	await a.ate(2.3)
	await olho.piscar(0.14, 0.34, 0.6, 0.55)
	olho.focar(2.2, 0.006, 1.2)
	await a.ate(3.2)
	await _capturar_plano("01_acordar_ceu")
	await a.ate(3.9)
	await olho.piscar(0.1, 0.12, 0.45, 0.94)
	olho.focar(0.8, 0.0, 1.1)
	a.tremor = 1.0

	# A mao sobe do chao para a frente do rosto, tremendo.
	await a.ate(_K.ACORDAR_MAO_SOBE)
	var mao := a.braco(1)
	if mao != null:
		mao.tremor = 0.9
	a.dedos(1, &"relaxada", 0.3)
	create_tween().tween_property(a, "palma_no_olho", 1.0, 1.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await a.ate(_K.ACORDAR_MAO_SOBE + 1.2)
	# O olho foca na mao: a praca atras dela vira borrao.
	Cinema.profundidade(0.42, 0.14, 0.9)
	olho.focar(0.0, 0.0, 0.8)
	await a.ate(_K.ACORDAR_MAO_NO_ROSTO)
	_marca("olho_mao")
	a.dedos(1, &"aberta", 0.7)
	await a.ate(_K.ACORDAR_MAO_NO_ROSTO + 0.8)
	await _capturar_plano("01_acordar_mao")
	# Vira a mao: o dorso. Procura sangue e nao acha.
	create_tween().tween_property(a, "vira_mao", 1.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await a.ate(_K.ACORDAR_MAO_NO_ROSTO + 1.25)
	a.dedos(1, &"garra", 0.45)
	await a.ate(_K.ACORDAR_MAO_NO_ROSTO + 1.75)
	a.dedos(1, &"aberta", 0.35)
	create_tween().tween_property(a, "vira_mao", 0.15, 0.4)

	# A mao cai. O foco volta para longe.
	await a.ate(_K.ACORDAR_MAO_CAI)
	a.dedos(1, &"relaxada", 0.4)
	create_tween().tween_property(a, "palma_no_olho", 0.0, 0.45)
	if mao != null:
		mao.tremor = 0.35
	Cinema.sem_profundidade()

	# Os cotovelos: o tronco sobe, as maos espalmam no chao e as pernas entram
	# no quadro.
	await a.ate(_K.ACORDAR_COTOVELOS)
	a.som(&"ofegante_esforco", -13.0, 0.97)
	# Os olhos terminam a descida que o pescoco nao da: ate os pes.
	create_tween().tween_property(a, "olho_giro", Vector2(-0.32, 0.0), 1.1) 		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	a.dedos(0, &"apoio", 0.5)
	a.dedos(1, &"apoio", 0.5)
	create_tween().tween_property(a, "espalma", 1.0, 0.9) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await a.ate(_K.ACORDAR_JOELHO)
	_marca("olho_pernas")
	await a.ate(_K.ACORDAR_JOELHO + 0.5)
	await _capturar_plano("01_acordar_joelhos")
	await a.ate(_K.ACORDAR_OLHA)
	# A mao esquerda aperta a pedra.
	a.dedos(0, &"apoio_forca", 0.5)

	# Os bracos cedem. Cai de costas, o olho fecha no baque.
	await a.ate(_K.ACORDAR_CAI)
	create_tween().tween_property(a, "espalma", 0.0, 0.3)
	create_tween().tween_property(a, "olho_giro", Vector2.ZERO, 0.3)
	a.dedos(0, &"relaxada", 0.3)
	a.dedos(1, &"relaxada", 0.3)
	await a.ate(_K.ACORDAR_FIM - 0.05)
	a.som(&"baque_corpo_1", -11.0, 0.82)
	a.tremor = 5.0
	await olho.ir(0.0, 0.08)
	_marca("olho_cai")
	await Cinema.corte(0.3)
	a.sair_do_olho()
	a.tremor = 1.0
	olho.abertura = 1.0
	olho.borrao = 0.0
	olho.duplo = 0.0


## TAKES 1 e 2 — caido, de cima, e a descida ate o rosto. Ver o bloco "TAKES 1 e
## 2" no topo.
func _planos_de_cima(figura: Corpo, frente: Vector3) -> void:
	if _acordar != null and figura != null:
		var tronco := _acordar.ponto(Corpo.Osso.TORSO)
		_acordar.trilho(_pontos(tronco, ZENITAL_DE), ZENITAL_DURACAO, Corpo.Osso.TORSO,
			ZENITAL_OLHA, ZENITAL_FOV, ZENITAL_FOV, 0.4, frente)
	await Cinema.clarear(0.35)
	_marca("caido")
	# A legenda entra DEPOIS do corte, nunca junto: 0,4 s de imagem limpa.
	await get_tree().create_timer(0.4).timeout
	Cinema.legenda(FALAS["praca_1"], 3.8)
	# A captura espera a legenda SUBIR (fade de 0,55 s).
	await get_tree().create_timer(0.7).timeout
	await _capturar_plano("02_deitado_igreja")
	await get_tree().create_timer(2.85).timeout

	# --- TAKE 2: O ROSTO ---------------------------------------------------
	# Sem corte: a camera desce ate a cara dele, e os olhos abrem nela.
	if _acordar != null and figura != null:
		var cabeca := _acordar.ponto(Corpo.Osso.CABECA)
		_acordar.trilho(_pontos(cabeca, ROSTO_ATE), ROSTO_DURACAO, Corpo.Osso.CABECA,
			ROSTO_OLHA, ZENITAL_FOV, ROSTO_FOV, 0.5, frente, true)
	await get_tree().create_timer(0.4).timeout
	Cinema.legenda(FALAS["praca_2"], 3.2)
	await get_tree().create_timer(0.9).timeout
	# Os olhos abrem pesados: palpebra a meio, sobrancelha caida, boca
	# entreaberta — atordoado, e nao assustado. O medo (olho arregalado) com a
	# boca aberta, de cima, lia como sorriso; ele fica para quando ele esta de
	# pe e entende onde esta.
	if figura != null and figura.rosto != null:
		figura.rosto.expressao(Rosto.Expressao.BEBADO)
	_marca("olhos_abrem")
	await get_tree().create_timer(0.5).timeout
	await _capturar_plano("praca_2")
	await get_tree().create_timer(1.6).timeout


## TAKE 3 — o levantar, de helicoptero. Ver o bloco "TAKE 3" no topo do arquivo
## e `ChavesDoAcordar.chaves_levantar`.
func _plano_do_levantar(onde: Vector3, figura: Corpo) -> void:
	var a := _acordar
	if a == null or figura == null:
		await Cinema.clarear(0.28)
		return
	var ch := _K.chaves_levantar(figura)
	var total := _K.duracao(ch)
	a.trilho(_pontos(onde, HELI), total + 0.8, Corpo.Osso.TORSO, HELI_MIRA,
		HELI_FOV.x, HELI_FOV.y, 0.5)
	a.tocar(ch)
	a.folego = 1.6
	if figura.rosto != null:
		figura.rosto.reagir(Rosto.Expressao.DOR, total * 0.6)
	await Cinema.clarear(0.5)
	_marca("levantar")
	a.som(&"ofegante_esforco", -15.0, 0.95)
	await get_tree().create_timer(0.4).timeout
	Cinema.legenda(FALAS["praca_3"], 3.4)
	await a.ate(3.2)
	await _capturar_plano("03_levantar")
	await a.ate(_K.LEVANTAR_CORTE + 1.4)
	a.som(&"ofegante_esforco", -16.0, 1.02)
	await a.ate(_K.LEVANTAR_CORTE + 2.8)
	await _capturar_plano("03b_levantar")
	await a.ate(total)
	await get_tree().create_timer(0.6).timeout
	a.parar_trilho()
	# O corpo continua dominado: o TAKE 4 comeca desta mesma pose.
	if figura.rosto != null:
		figura.rosto.expressao(Rosto.Expressao.MEDO)
	_marca("de_pe")


## TAKE 4 — o olhar em volta. Ver o bloco "TAKE 4" no topo.
##
## Tempos pelo relogio das chaves (`ChavesDoAcordar.OLHAR_*`): camera, cabeca,
## olho, som e legenda andam juntos mesmo se um quadro engasga.
func _plano_do_olhar(figura: Corpo) -> void:
	var a := _acordar
	if a == null or figura == null:
		await Cinema.clarear(0.28)
		await get_tree().create_timer(3.0).timeout
		return
	await Cinema.corte(0.1)
	a.tocar(_K.chaves_olhar(figura))
	a.folego = 1.3
	a.orbitar(_orbita_do_olhar(), Corpo.Osso.CABECA, ORBITA_MIRA)
	# Medo montado por partes: a boca "entreaberta" do MEDO, de baixo, le como
	# sorriso. Boca triste, sobrancelha erguida e olho arregalado le como pavor.
	var rosto := figura.rosto
	if rosto != null:
		rosto.expressao(Rosto.Expressao.TRISTEZA)
		rosto.micro(&"ERGUIDA", &"ARREGALADO", _K.OLHAR_FIM + 1.5)
	Cinema.clarear(0.22)
	_marca("olhar")
	a.som(&"ofegante", -21.0, 1.0)
	# O olho vai antes da cabeca: `olhar_lateral` pequeno e so o olho (o pescoco
	# do Corpo esta dominado); a cabeca e a das chaves.
	await a.ate(_K.OLHAR_MAO_CAI)
	figura.olhar_lateral(OLHO_ANTES)
	await a.ate(_K.OLHAR_MAO_CAI + 0.3)
	Cinema.legenda(FALAS["praca_4"], 3.0)
	await a.ate(_K.OLHAR_TORRE - 0.9)
	figura.olhar_lateral(0.0)
	await a.ate(_K.OLHAR_TORRE + 0.4)
	await _capturar_plano("praca_4")
	await a.ate(_K.OLHAR_TORRE_FIM)
	figura.olhar_lateral(-OLHO_ANTES)
	# A respiracao calma da estrada, de novo pela esquerda, e sem dono.
	await a.ate(_K.OLHAR_OUVE)
	a.som(&"respiracao_calma", -11.0, 0.97, BrancoDoSusto._bus_esquerda())
	await a.ate(_K.OLHAR_VIRA)
	figura.olhar_lateral(OLHO_ANTES * 1.5)
	if rosto != null:
		rosto.reagir(Rosto.Expressao.SURPRESA, 1.1)
	a.som(&"respiracao_susto", -14.0, 1.06)
	await a.ate(_K.OLHAR_VIROU + 0.3)
	await _capturar_plano("praca_4b")
	await a.ate(_K.OLHAR_VIROU + 0.85)
	figura.olhar_lateral(0.0)
	await a.ate(_K.OLHAR_FIM)
	a.parar_orbita()
	a.soltar()
	_marca("olhou")


## A volta da camera do TAKE 4, pelos tempos das chaves do olhar.
static func _orbita_do_olhar() -> Dictionary:
	var torre := _K.OLHAR_TORRE
	var torre_fim := _K.OLHAR_TORRE_FIM
	var virou := _K.OLHAR_VIROU
	var fim := _K.OLHAR_FIM
	return {
		"angulo": [Vector2(0.0, 0.25), Vector2(1.3, 0.85), Vector2(2.6, 2.0),
			Vector2(torre, 2.95), Vector2(torre_fim, 3.45), Vector2(5.5, 4.35),
			Vector2(virou, 5.25), Vector2(7.3, 5.95), Vector2(fim, 6.5)],
		"raio": [Vector2(0.0, 1.45), Vector2(2.8, 1.28), Vector2(torre, 1.12),
			Vector2(torre_fim, 1.14), Vector2(5.5, 1.25), Vector2(virou, 1.22), Vector2(fim, 1.55)],
		"altura": [Vector2(0.0, 1.56), Vector2(2.6, 1.5), Vector2(torre, 1.36),
			Vector2(torre_fim, 1.38), Vector2(virou, 1.54), Vector2(fim, 1.6)],
		"fov": [Vector2(0.0, 50.0), Vector2(torre, 43.0), Vector2(torre_fim, 42.0),
			Vector2(virou, 47.0), Vector2(fim, 50.0)],
	}


static func _pontos(base: Vector3, relativos: Array[Vector3]) -> Array[Vector3]:
	var saida: Array[Vector3] = []
	for p: Vector3 in relativos:
		saida.append(base + p)
	return saida


## Bancada da praca, pela linha de comando:
##
##   --praca-rajada=<pasta>   um quadro a cada 0,1 s de cena (`RajadaDeCena`)
##   --praca-cheio            e um a cada segundo no tamanho da janela
##   --praca-fotos=<pasta>    as fotos por plano vao para la, e NAO para as
##                            capturas versionadas do repositorio
##   --praca-branco           a praca abre do branco do susto, como na emenda
##   --praca-ate=levantar     encerra depois do levantar (ou `olhar`, depois
##                            do olhar em volta; `mercado`, `casa` e `poste`
##                            depois de cada um desses planos)
##   --abertura-desde=mercado comeca no mercado (`poste`: no poste, com o fumo
##                            e a bituca)
##   --praca-desde=levantar   pula o olho e os planos de cima (`olhar` pula
##                            tambem o levantar)
func _montar_bancada() -> void:
	_t0 = float(Time.get_ticks_msec()) / 1000.0
	_rajada = RajadaDeCena.da_linha("praca")
	if _rajada != null:
		_cena.add_child(_rajada)
	if OS.get_cmdline_user_args().has("--praca-branco") \
			and _cena.get_node_or_null("BrancoDoSusto") == null:
		var branco := BrancoDoSusto.new()
		_cena.add_child(branco)
		branco.estourar()


## Uma marca de tempo no log, no relogio da rajada: e por elas que se escolhe o
## trecho do mosaico.
func _marca(nome: String) -> void:
	var t := _rajada.t if _rajada != null else float(Time.get_ticks_msec()) / 1000.0 - _t0
	print("[praca] %s t=%.2f" % [nome, t])
	# Com `--medir`, cada trecho da praca vira uma parada do medidor de quadro.
	Medidor.marcar_parada(StringName(nome))


## Bancada: encerra aqui se a linha de comando pediu (`--praca-ate=<nome>`).
func _encerrar_na_bancada(nome: StringName) -> bool:
	if not OS.get_cmdline_user_args().has("--praca-ate=%s" % nome):
		return false
	print("[praca] bancada encerrada em %s" % nome)
	get_tree().create_timer(0.35).timeout.connect(get_tree().quit)
	return true


## Para os moradores da praca longe da lente, olhando o corpo. Ver `PLATEIA_*`.
##
## As cameras de fora ficam ao SUL do corpo (+Z) olhando para o norte, onde
## esta a igreja; a volta do TAKE 4 passa ao norte, mas a pouco mais de um metro
## dele. Entao o ponto bom para a plateia e ao norte, a uns quatorze metros:
## dentro do quadro, no fundo, e nunca entre a lente e ele.
##
## Todo `Convidado` da praca, e nao so o `MoradorPraca`: medido com
## `--debug-plateia`, quem parava a 2,6 m do corpo, do lado da camera, era um
## convidado comum da roda de conversa da praca, e nao um morador. Quem nao tem
## rota (ou cuja rota nao passa em lugar bom) ganha um ponto num arco ao norte,
## validado por raio: tem chao na altura da praca e vista livre ate o corpo.
func _juntar_a_plateia(corpo: Vector3) -> void:
	var usados: Array[Vector3] = []
	var arco: Array[Vector3] = []
	for k in 9:
		var ang := deg_to_rad(-64.0 + 16.0 * float(k))
		for dist: float in [PLATEIA_IDEAL, PLATEIA_IDEAL - 3.0, PLATEIA_IDEAL + 3.0]:
			var p := corpo + Vector3(sin(ang), 0.0, -cos(ang)) * dist
			var chao := _chao_em(p + Vector3.UP * 2.0)
			if absf(chao - corpo.y) > 1.2:
				continue
			p.y = chao
			if not _linha_livre(corpo + Vector3.UP * 1.0, p + Vector3.UP * 1.0):
				continue
			arco.append(p)
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var m := no as Convidado
		if m == null or not m.visible or m.estacionado():
			continue
		var d_agora := Vector2(m.global_position.x - corpo.x,
			m.global_position.z - corpo.z).length()
		if d_agora > PLATEIA_RAIO:
			continue
		var melhor := Vector3.INF
		var nota_melhor := -INF
		for p: Vector3 in m.pontos + arco:
			var dist := Vector2(p.x - corpo.x, p.z - corpo.z).length()
			if dist < PLATEIA_PERTO:
				continue
			# Perto do ideal, ao norte, e longe de quem ja parou ali.
			var nota := -absf(dist - PLATEIA_IDEAL) - maxf(0.0, p.z - corpo.z) * 2.5
			for u: Vector3 in usados:
				if p.distance_to(u) < 2.5:
					nota -= 20.0
			if nota > nota_melhor:
				nota_melhor = nota
				melhor = p
		if melhor == Vector3.INF:
			continue
		usados.append(melhor)
		m.estacionar(melhor, Vector3(corpo.x, melhor.y, corpo.z))
		_plateia.append(m)
	if not _plateia.is_empty():
		print("[abertura] plateia na praca: %d morador(es)" % _plateia.size())
	if OS.get_cmdline_user_args().has("--debug-plateia"):
		for no: Node in get_tree().get_nodes_in_group(&"npc"):
			var n3 := no as Node3D
			if n3 == null:
				continue
			var d := Vector2(n3.global_position.x - corpo.x, n3.global_position.z - corpo.z)
			if d.length() < 40.0:
				print("[plateia] %s classe=%s script=%s d=%.1f dz=%.1f visivel=%s" % [n3.name,
					n3.get_class(), (n3.get_script() as Script).resource_path.get_file()
					if n3.get_script() != null else "-", d.length(), d.y, n3.visible])


## Devolve a rotina de quem parou para olhar.
func _desfazer_a_plateia() -> void:
	for m: Convidado in _plateia:
		if is_instance_valid(m):
			m.liberar()
	_plateia.clear()


## Cigarro e celular aparecem ou somem das maos dele.
##
## Somem na praca: um homem que acabou de acordar desacordado no chao nao esta
## segurando um telefone aceso e um cigarro queimando — e a tela verde na mao,
## a dois metros da lente, saia como um risco luminoso atravessando o quadro do
## levantar. Voltam no poste, que e onde ele ja teve tempo de acender um.
func _mostrar_aderecos(visiveis: bool) -> void:
	for a: Node3D in [_cigarro, _celular]:
		if a != null and is_instance_valid(a):
			a.visible = visiveis


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
## nao tem com que comprar nada ali. Ver o bloco "plano do mercado" no topo.
func _plano_do_mercado(pose: Dictionary) -> void:
	await Cinema.escurecer(0.55)
	_apagar_apoio()
	_jogador.mostrar_corpo(false)

	var loja := _loja_da_rua(_jogador.global_position)
	if loja.is_empty():
		push_warning("Abertura: nenhuma loja na rua por perto; o plano do mercado sai")
		return
	var casa := await _chegar_na_loja(loja)
	if casa == null:
		push_warning("Abertura: a loja da rua nao montou a tempo; o plano do mercado sai")
		_jogador.set_physics_process(true)
		return
	var em := casa.global_transform
	_por_o_caixa_para_conversar(casa, em)

	var trilho := TrilhoDeCamera.rodar(_cena, _na_planta(em, MERCADO_CAMINHO),
		_na_planta(em, MERCADO_MIRA), MERCADO_DURACAO, MERCADO_FOV.x, MERCADO_FOV.y)
	trilho.ao_quadro = _ar_da_loja(em)
	var anda := create_tween()
	anda.tween_interval(MERCADO_PORTADOR_TEMPO.x)
	anda.tween_property(_jogador, "global_position", em * MERCADO_PORTADOR_ATE,
		MERCADO_PORTADOR_TEMPO.y - MERCADO_PORTADOR_TEMPO.x) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await Cinema.clarear(0.6)
	# Duas linhas curtas, e nao uma longa: a frase inteira quebrava em duas
	# linhas e a segunda encostava na tarja de baixo.
	await get_tree().create_timer(0.8).timeout
	await _capturar_plano("04_mercado")
	Cinema.legenda(FALAS["mercado_1"], 3.8)
	await get_tree().create_timer(4.1).timeout
	Cinema.legenda(FALAS["mercado_2"], 3.8)
	await trilho.terminou
	await _capturar_plano("04_mercado_fim")
	await get_tree().create_timer(1.0).timeout

	await Cinema.escurecer(0.5)
	trilho.queue_free()
	_jogador.global_transform = pose_para_transform(pose, _jogador.rotation.y)
	_jogador.set_physics_process(true)
	_jogador.zerar_velocidade()
	# O ar da loja sai com o preset dela; a noite volta por cima (ver
	# `_impor_a_noite`).
	_impor_a_noite()
	_encerrar_na_bancada(&"mercado")


## A loja da rua mais perto de `ponto`, anel por anel de chunks: {cx, cz,
## porta}, ou vazio. So porta de mercado com `mundo`: a que existe na rua.
func _loja_da_rua(ponto: Vector3) -> Dictionary:
	var c := ChunkManager.coord_de(ponto)
	for raio in MERCADO_RAIO + 1:
		var melhor := {}
		var perto := INF
		for cx in range(c.x - raio, c.x + raio + 1):
			for cz in range(c.y - raio, c.y + raio + 1):
				if maxi(absi(cx - c.x), absi(cz - c.y)) != raio:
					continue
				for p: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
					if p.get("tipo", &"") != &"porta" or p.get("interior", &"") != &"mercado" \
							or not bool(p.get("mundo", false)):
						continue
					var d := (Vector3(p["pos"]) + Vector3(cx * KitModular.CHUNK, 0.0,
						cz * KitModular.CHUNK)).distance_to(ponto)
					if d < perto:
						perto = d
						melhor = {"cx": cx, "cz": cz, "porta": p}
		if not melhor.is_empty():
			return melhor
	return {}


## Leva o corpo escondido dele para a rua em frente a loja, sem fisica (o chunk
## ainda nao tem chao), e espera a loja montar com todos os props.
func _chegar_na_loja(loja: Dictionary) -> InteriorNoMundo:
	var base := Vector3(float(loja["cx"]) * KitModular.CHUNK, 0.0,
		float(loja["cz"]) * KitModular.CHUNK)
	var porta: Dictionary = loja["porta"]
	var porta_mundo := Vector3(porta["pos"]) + base
	var planta: Transform3D = porta["planta"]
	var chao := porta_mundo.y - KitModular.ALTURA_MEIO_FIO
	var em := Transform3D(planta.basis, planta.origin + base + Vector3(0.0, chao, 0.0))
	_jogador.set_physics_process(false)
	_jogador.zerar_velocidade()
	_jogador.global_position = em * MERCADO_PORTADOR_DE
	var t0 := float(Time.get_ticks_msec()) / 1000.0
	while float(Time.get_ticks_msec()) / 1000.0 - t0 < MERCADO_ESPERA_MAX:
		for no: Node in get_tree().get_nodes_in_group(&"interior_mundo"):
			var casa := no as InteriorNoMundo
			if casa != null and casa.planta == &"mercado" and casa.pronta() \
					and casa.global_position.distance_to(porta_mundo) < 20.0:
				# O corpo vai para o ponto de partida da loja montada, que pode
				# diferir do anunciado pela altura do lote.
				_jogador.global_position = casa.global_transform * MERCADO_PORTADOR_DE
				print("[abertura] mercado da rua em %s, montou em %.1f s" % [
					casa.global_position.snapped(Vector3.ONE * 0.1),
					float(Time.get_ticks_msec()) / 1000.0 - t0])
				# A rua enche de uma vez, ainda no preto: a multidao repovoa em
				# volta de quem foi teleportado a um pedestre a cada 0,8 s, e cada
				# um que nasce e um quadro de 15 a 25 ms no meio do plano.
				Multidao.semear()
				await get_tree().create_timer(Multidao.INTERVALO * 3.0 + 0.1).timeout
				return casa
		await get_tree().create_timer(0.2).timeout
	return null


## Pontos de planta da loja no mundo.
static func _na_planta(em: Transform3D, pontos: Array[Vector3]) -> Array[Vector3]:
	var saida: Array[Vector3] = []
	for p: Vector3 in pontos:
		saida.append(em * p)
	return saida


## O ar muda com a LENTE atravessando a soleira da loja, e nao com o jogador:
## noite da abertura na rua, o ar da loja do lado de dentro, misturados na mesma
## faixa e no mesmo passo que a propria loja usa (`InteriorNoMundo.SOLEIRA`,
## `PASSO_PESO`). A loja misturaria com o preset escolhido pelo jogador para a
## rua, e no meio da porta a noite virava a neblina clara dele.
func _ar_da_loja(em: Transform3D) -> Callable:
	var fog := _fog_da_cena()
	var noite := load(_preset_da_praca()) as FogPreset
	var loja := load(MERCADO_AR) as FogPreset
	var inv := em.affine_inverse()
	var estado := {"peso": -1.0, "sino": false}
	return func(lente: Vector3, _e: float) -> void:
		if fog == null or noite == null or loja == null:
			return
		var z := (inv * lente).z
		var peso := smoothstep(InteriorNoMundo.SOLEIRA.x, InteriorNoMundo.SOLEIRA.y, z)
		var antes: float = estado["peso"]
		if absf(peso - antes) >= InteriorNoMundo.PASSO_PESO or (peso >= 1.0 and antes < 1.0) \
				or (peso <= 0.0 and antes > 0.0):
			estado["peso"] = peso
			fog.forcar_preset(FogPreset.misturar(noite, loja, peso))
		# O dim-dom da porta toca para quem entra: aqui, para a lente.
		if z > 0.0 and not bool(estado["sino"]):
			estado["sino"] = true
			AudioDirector.tocar(&"loja_dimdom", em * Vector3(MercadoBuilder.CENTRO_PORTA,
				2.3, 1.2), -7.0)


## Poe o atendente e o cliente da loja conversando no caixa.
##
## So a gente DESTA loja: pegar os dois primeiros `Convidado` da arvore, como o
## comodo teleportado fazia, na rua pega dois pedestres quaisquer. O cliente vai
## direto para o posto dele (`ir_ao_caixa` grava a rota de planta como posicao
## de mundo, o que so da certo no comodo sem giro).
func _por_o_caixa_para_conversar(casa: InteriorNoMundo, em: Transform3D) -> void:
	var atendente: Convidado = null
	var cliente: Convidado = null
	for no: Node in casa.find_children("*", "Convidado", true, false):
		var c := no as Convidado
		if c is AtendenteLoja:
			atendente = c
		elif c.rotina == &"compra" and cliente == null:
			cliente = c
	if cliente != null:
		cliente.estacionar(em * MercadoBuilder.POSTO_CLIENTE, em * MercadoBuilder.POSTO_ATENDENTE)
	if atendente != null and cliente != null:
		cliente.iniciar_papo(atendente, MERCADO_DURACAO + 4.0)
		atendente.iniciar_papo(cliente, MERCADO_DURACAO + 4.0)


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
	for k in ESPERA_BAIRRO:
		await get_tree().physics_frame
		# Os primeiros quadros nao valem: o `is_on_floor` ainda e o do lugar de
		# antes (o move_and_slide nao rodou aqui), e com o bairro ja montado a
		# espera saia no primeiro quadro com o corpo 1,2 m acima do chao. O
		# plano do poste enquadrava a cabeca dele na borda de baixo e terminava
		# olhando o mastro vazio.
		if k >= 4 and _bairro_pronto(alvo) and _jogador.is_on_floor():
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
	var fog := _fog_da_cena()
	if fog != null:
		print("[abertura] poste: nevoa em vigor = %s" % fog.preset_ativo())

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
	#
	# E sondado DEPOIS de o bairro montar. Antes, as oito sondas perguntavam o
	# chao de um chunk que ainda nao existia, o raio nao achava nada e todas
	# devolviam a mesma altura: ganhava a primeira direcao, e a cada execucao
	# ele ficava de costas para um lado diferente do poste.
	await _levar_para(base + Vector3(0.9, 0.0, 0.9))
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
		if _celular == null or not is_instance_valid(_celular):
			_montar_maos(figura)
		_acender_o_cigarro(figura)
		_mostrar_aderecos(true)

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
	# A tragada funda do plano: a mao sobe no meio da descida e o sopro para o
	# alto acontece com a camera chegando na cara dele. O relogio negativo e a
	# espera ate a mao sair do repouso.
	if figura != null and figura.fumo != null:
		figura.fumo.forcar(Tragada.Estilo.FUNDA, -POSTE_TRAGADA_EM)
	await Cinema.clarear(0.6)
	await get_tree().create_timer(1.4).timeout
	await _capturar_plano("06_poste")

	Cinema.legenda(FALAS["poste_1"], 3.8)
	await get_tree().create_timer(4.0).timeout
	Cinema.legenda(FALAS["poste_2"], 3.6)
	await get_tree().create_timer(3.8).timeout
	Cinema.legenda(FALAS["poste_3"], 4.2)
	await get_tree().create_timer(POSTE_DURACAO - 8.8).timeout
	await _capturar_plano("06_poste_fim")
	await get_tree().create_timer(1.0).timeout

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
	var pasta := ""
	for a: String in args:
		if a.begins_with("--praca-fotos="):
			pasta = a.trim_prefix("--praca-fotos=")
	if pasta.is_empty() and not (args.has("--ver-abertura") or args.has("--ver-praca")):
		return
	# Foto no meio da medida e o proprio engasgo: get_image + PNG em 4K sao
	# ~135 ms, e cada plano fotografado virava um pico no `--medir`.
	for a: String in args:
		if a.begins_with("--medir"):
			return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_warning("Abertura: captura %s falhou (viewport vazio)" % nome)
		return
	# Bancada: so na pasta pedida. As capturas versionadas nao sao tocadas.
	if not pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(pasta)
		image.save_png(pasta.path_join("%s.png" % nome))
		print("[abertura] captura %s" % pasta.path_join("%s.png" % nome))
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
			or nome.begins_with("praca_") or nome.begins_with("03_levantar")):
		var game_dir := ProjectSettings.globalize_path("res://").rstrip("/\\")
		var cine_dir := game_dir.path_join("..").path_join("captures").path_join("praca_matriz").path_join("cine")
		DirAccess.make_dir_recursive_absolute(cine_dir)
		var cine := cine_dir.path_join("%s.png" % nome)
		var err2 := image.save_png(cine)
		if err2 == OK:
			print("[abertura] cine %s" % cine)
		else:
			push_warning("Abertura: falha cine %s (erro %d)" % [cine, err2])
		var sessao := game_dir.path_join("..").path_join("captures").path_join("_sessao_corpo_praca")
		DirAccess.make_dir_recursive_absolute(sessao)
		var s2 := image.save_png(sessao.path_join("%s.png" % nome))
		if s2 == OK:
			print("[abertura] sessao %s" % sessao.path_join("%s.png" % nome))

static func pose_para_transform(pose: Dictionary, giro: float) -> Transform3D:
	var onde: Vector3 = pose["onde"]
	return Transform3D(Basis(Vector3.UP, giro), onde)


# --- plano 3 ----------------------------------------------------------------

## O cigarro do poste: um Marlboro no corpo, e o relogio de quem fuma.
##
## E o mesmo sistema da casa da fumaca (`Tragada` no corpo, que leva a mao aos
## labios por IK; `Blunt`, de que o `Cigarro` e filho, que mira a boca do filtro
## nos labios, acende a brasa e solta o fio e a baforada). O cigarro antigo era
## um bastao parafusado no osso, e a tragada antiga parava no peito.
func _acender_o_cigarro(figura: Corpo) -> void:
	if _cigarro != null and is_instance_valid(_cigarro):
		return
	figura.fumo = Tragada.new(POSTE_FUMO_SEMENTE)
	figura.fumo.consumido = POSTE_QUEIMOU
	figura.fumo.cinza = 0.45
	_cigarro = Cigarro.new()
	_cigarro.name = "Cigarro"
	_cena.add_child(_cigarro)
	_cigarro.montar(figura, POSTE_FUMO_SEMENTE)


## Primeira pessoa: o ultimo trago e a bituca na calcada.
##
## A camera e a do jogador, no olho dele, e a mao e o cigarro sao refeitos a
## cada quadro no referencial dela (`_process`). A primeira versao pendurava um
## bastao escalado 1,5 vezes no pivo da cabeca e subia duas caixas de pele por
## tween: um bloco amarelo aceso no canto da tela e uma luva sem dedos.
func _plano_da_bituca(_pose: Dictionary) -> void:
	Cinema.devolver()
	_jogador.mostrar_corpo(false)
	_jogador.definir_pitch(deg_to_rad(-6.0))
	_jogador.definir_fov(62.0)
	# O cigarro do poste vivia no corpo, que sumiu. O da mao continua ele: a
	# mesma marca, queimado ate onde o poste deixou.
	var figura := _jogador.figura()
	if figura != null:
		figura.fumo = null
	for a: Node3D in [_cigarro, _celular]:
		if a != null and is_instance_valid(a):
			a.queue_free()
	_cigarro = null
	_celular = null
	_montar_mao_com_cigarro()
	# Quatro quadros no preto: o material da mao compila na primeira vez que a
	# camera a desenha (ver `AcordarNaPraca.entrar_no_olho_aquecido`), e a
	# faisca da bituca tambem — seis pipelines, um quadro de 33 ms bem no
	# instante em que ela bate no chao. Uma faisca de um decimo de milimetro na
	# frente da lente paga isso aqui.
	var lente := get_viewport().get_camera_3d()
	if lente != null:
		_faiscas(lente.global_position - lente.global_basis.z * 0.6, 0.02)
	for i in 4:
		await get_tree().process_frame

	await Cinema.clarear(0.7)
	await _esperar(BITUCA_ESPERA)

	# A mao sobe, com um arco para fora do queixo, e a cabeca baixa ao encontro.
	_mover_mao(POSE_NA_BOCA, BITUCA_SOBE, Vector3(0.03, -0.035, 0.015))
	create_tween().tween_method(_jogador.definir_pitch, deg_to_rad(-6.0),
		deg_to_rad(BITUCA_CABECA_BAIXA), BITUCA_SOBE).set_trans(Tween.TRANS_SINE)
	await _esperar(BITUCA_SOBE)

	# O ultimo trago: a brasa acende e anda ate o filtro, a cinza cresce, e o
	# quadro fecha dois graus — alguem parando de olhar em volta para puxar.
	AudioDirector.tocar_ui(&"cigarro_traga", -13.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_cig_pov, "puxada", 1.0, 0.25)
	t.tween_property(_cig_pov, "consumo", Cigarro.QUEIMA_BITUCA, BITUCA_PUXA)
	t.tween_property(_cig_pov, "cinza", 0.9, BITUCA_PUXA)
	t.tween_method(_jogador.definir_fov, 62.0, 59.5, BITUCA_PUXA) \
		.set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(_cig_pov, "puxada", 0.0, 0.35)
	await _esperar(BITUCA_PUXA)

	# A mao desce com o ar preso, a cabeca volta, e o sopro sai.
	_mover_mao(POSE_DESCANSO, BITUCA_DESCE, Vector3(0.02, -0.03, 0.0))
	create_tween().tween_method(_jogador.definir_pitch, deg_to_rad(BITUCA_CABECA_BAIXA),
		deg_to_rad(-6.0), BITUCA_DESCE + 0.2).set_trans(Tween.TRANS_SINE)
	await _esperar(BITUCA_DESCE + BITUCA_PRENDE)
	_soprar()
	create_tween().tween_method(_jogador.definir_fov, 59.5, 62.0, 1.2)
	await _esperar(0.9)
	await _capturar_plano("07_bituca")
	await _esperar(BITUCA_SOPRA - 0.9)

	# O peteleco.
	_mover_mao(POSE_PETELECO, BITUCA_ARMA, Vector3.ZERO)
	await _esperar(BITUCA_ARMA)
	_petelecar()
	_mover_mao(POSE_FORA, 0.7, Vector3.ZERO, MaoPosada.pose(&"aberta"))
	await _bituca_pousou
	# O olho para na bituca: a mira vai nela e o quadro fecha, que e o que faz
	# quem fica olhando a brasa morrer no chao. Aberto em 62 graus, a dois
	# metros e meio, ela tinha 16 px de 4K — um cisco laranja no asfalto.
	# A mira vira tambem: a bituca nunca cai exatamente na frente, e so baixar
	# o olho deixava ela na borda do quadro fechado.
	var olho := get_viewport().get_camera_3d().global_position
	var meio_da_bituca := _cig_pov.global_transform * Vector3(Cigarro.FILTRO * 0.6, 0.0, 0.0)
	var ate := meio_da_bituca - olho
	var mira := -atan2(-ate.y, Vector2(ate.x, ate.z).length())
	var giro_de := _jogador.rotation.y
	var giro_ate := giro_de + angle_difference(giro_de, atan2(-ate.x, -ate.z))
	var t3 := create_tween().set_parallel(true)
	t3.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t3.tween_method(_jogador.definir_pitch, _jogador.pitch_atual(), mira, 0.9)
	t3.tween_property(_jogador, "rotation:y", giro_ate, 0.9)
	t3.tween_method(_jogador.definir_fov, 62.0, BITUCA_FOV_NO_CHAO, 1.1)
	await _esperar(1.2)
	await _capturar_plano("07_bituca_chao")

	Cinema.legenda(FALAS["bituca"], 5.4)
	await _esperar(3.0)
	# Ele levanta os olhos da bituca para a rua: e a rua que a partida entrega.
	var t2 := create_tween().set_parallel(true)
	t2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t2.tween_method(_jogador.definir_pitch, mira, deg_to_rad(-4.0), 1.6)
	t2.tween_method(_jogador.definir_fov, BITUCA_FOV_NO_CHAO, 62.0, 1.6)
	await _esperar(2.2)
	if _mao != null and is_instance_valid(_mao):
		_mao.queue_free()
	_mao = null


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


## A mao direita de primeira pessoa e o cigarro nela.
func _montar_mao_com_cigarro() -> void:
	var cores := MotoristaCena._cores_do_jogador()
	var pele: Color = cores["pele"]
	var longa: bool = cores["longa"]
	var manga: Color = cores["manga"] if longa else pele
	_mao = BracoVivo.criar("MaoDoCigarro", true, pele, manga, longa)
	# A camada do BracoVivo e das cenas de POV com camera propria, que a camera
	# do jogador nao ve. Aqui a camera e a dele: a mao vai para a do mundo.
	_mao.layers = 1
	_cena.add_child(_mao)
	_mao.visible = true
	_mao.dedos_vivos = 0.35

	_cig_pov = Cigarro.new()
	_cig_pov.name = "CigarroNaMao"
	_cena.add_child(_cig_pov)
	_cig_pov.montar(null, POSTE_FUMO_SEMENTE)
	_cig_pov.consumo = BITUCA_QUEIMOU
	_cig_pov.cinza = 0.55
	# A um ou dois centimetros dos dedos, a luz da brasa do corpo pintava a mao
	# inteira de laranja na puxada.
	_cig_pov.luz_da_brasa = 0.2

	_pose_de = POSE_DESCANSO
	_pose_para = POSE_DESCANSO
	_pose_k = 1.0
	_dedos_de = DEDOS_CIGARRO
	_dedos_para = DEDOS_CIGARRO
	_voando = false
	_cig_na_mao = true
	_mao_no_quadro(0.0)


## Leva a mao para outra pose em `duracao` segundos, com um arco (no
## referencial do olho) e, se pedido, outra pose de dedos.
func _mover_mao(para: Dictionary, duracao: float, arco: Vector3,
		dedos: Dictionary = {}) -> void:
	_pose_de = _pose_agora()
	_pose_para = para
	_pose_k = 0.0
	_pose_dur = maxf(duracao, 0.01)
	_pose_arco = arco
	_dedos_de = _dedos_agora()
	_dedos_para = dedos if not dedos.is_empty() else _dedos_para


func _e_pose() -> float:
	return _pose_k * _pose_k * (3.0 - 2.0 * _pose_k)


func _pose_agora() -> Dictionary:
	var e := _e_pose()
	var de_eixo: Vector3 = (_pose_de["eixo"] as Vector3).normalized()
	var de_dedos: Vector3 = (_pose_de["dedos"] as Vector3).normalized()
	return {"pega": (_pose_de["pega"] as Vector3).lerp(_pose_para["pega"], e)
			+ _pose_arco * sin(e * PI),
		"eixo": de_eixo.slerp((_pose_para["eixo"] as Vector3).normalized(), e),
		"dedos": de_dedos.slerp((_pose_para["dedos"] as Vector3).normalized(), e)}


func _dedos_agora() -> Dictionary:
	return MaoPosada.misturar(_dedos_de, _dedos_para, _e_pose())


## A pegada do `BracoVivo` que poe o vao dos dedos em `pega`, com o cigarro no
## `eixo` e os dedos para `dedos` (tudo ja no mundo).
static func _pegada_do_cigarro(pega: Vector3, eixo: Vector3, dedos: Vector3,
		pose: Dictionary) -> Dictionary:
	var d := dedos.normalized()
	var dorso := eixo.normalized() - d * INCLINA_NOS_DEDOS
	dorso = (dorso - d * dorso.dot(d)).normalized()
	var polegar := dorso.cross(d).normalized()
	var o := pega - d * VAO_AO_LONGO - polegar * VAO_AO_LADO
	return BracoVivo.pega(o, d, dorso, pose)


## O cigarro entre os dedos da pegada: a boca do filtro para o lado da palma, a
## brasa saindo pelas costas da mao.
static func _no_vao_dos_dedos(pg: Dictionary, pega_do_cigarro: float) -> Transform3D:
	var d: Vector3 = pg["d"]
	var dorso: Vector3 = pg["dorso"]
	var polegar := dorso.cross(d).normalized()
	var pega := (pg["o"] as Vector3) + d * VAO_AO_LONGO + polegar * VAO_AO_LADO
	var eixo := (dorso + d * INCLINA_NOS_DEDOS).normalized()
	return Transform3D(Blunt._base(eixo), pega - eixo * pega_do_cigarro)


## Refaz a mao e o cigarro no referencial do olho de agora.
func _mao_no_quadro(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var olho := cam.global_transform
	_pose_k = minf(1.0, _pose_k + delta / _pose_dur)
	var p := _pose_agora()
	var pg := _pegada_do_cigarro(olho * (p["pega"] as Vector3),
		olho.basis * (p["eixo"] as Vector3), olho.basis * (p["dedos"] as Vector3),
		_dedos_agora())
	_mao.ombro = olho * MAO_OMBRO
	_mao.polo = (olho.basis * MAO_POLO).normalized()
	_mao.pular(pg)
	_mao.passo(delta)
	if _cig_na_mao and _cig_pov != null and is_instance_valid(_cig_pov):
		_cig_pov.global_transform = _no_vao_dos_dedos(_mao.pegada, _cig_pov.pega)


func _process(delta: float) -> void:
	if _mao != null and is_instance_valid(_mao):
		_mao_no_quadro(delta)
	if _baforada_pov != null and is_instance_valid(_baforada_pov):
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var olho := cam.global_transform
			var dir := (olho.basis * DIR_DO_SOPRO).normalized()
			_baforada_pov.global_transform = Transform3D(Basis.looking_at(dir, olho.basis.y),
				olho * BOCA_NO_OLHO)
	if _voando:
		_voar(delta)


## O sopro: a baforada de perto, saindo da boca para a frente e para baixo.
func _soprar() -> void:
	AudioDirector.tocar_ui(&"cigarro_sopra", -12.0)
	var f := FumacaParticulas.new()
	f.name = "SoproDoOlho"
	f.tipo = FumacaParticulas.Tipo.BAFORADA
	f.perto = true
	f.top_level = true
	_cena.add_child(f)
	_baforada_pov = f
	_process(0.0)
	var t := create_tween()
	t.tween_property(f, "amount_ratio", 1.0, 0.12)
	t.tween_interval(0.55)
	t.tween_property(f, "amount_ratio", 0.0, 1.3).set_ease(Tween.EASE_IN)
	t.tween_interval(3.2)
	t.tween_callback(func() -> void:
		if is_instance_valid(f):
			f.queue_free())


## O peteleco: a bituca sai da mao girando, e a camera baixa atras dela.
func _petelecar() -> void:
	if _cig_pov == null or not is_instance_valid(_cig_pov):
		_bituca_pousou.emit.call_deferred()
		return
	AudioDirector.tocar_ui(&"cigarro_peteleco", -9.0)
	var olho := get_viewport().get_camera_3d().global_transform
	_voo = olho.basis * PETELECO
	var eixo := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0))
	_giro_voo = eixo.normalized() * PETELECO_GIRO
	_quiques = 0
	_cig_na_mao = false
	_voando = true
	_cig_pov.fumaca = 0.0
	create_tween().tween_method(_jogador.definir_pitch, deg_to_rad(-6.0),
		deg_to_rad(OLHAR_O_CHAO), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A bituca no ar: gravidade, giro, dois quiques com faisca, e deita.
func _voar(delta: float) -> void:
	if _cig_pov == null or not is_instance_valid(_cig_pov):
		_voando = false
		return
	var xf := _cig_pov.global_transform
	_voo.y -= 9.8 * delta
	xf.origin += _voo * delta
	if _giro_voo.length() > 0.001:
		xf.basis = Basis(_giro_voo.normalized(), _giro_voo.length() * delta) * xf.basis
	# O meio da bituca, e nao a boca do filtro, e o que encosta no chao.
	var meio := xf * Vector3(Cigarro.FILTRO * 0.6, 0.0, 0.0)
	var chao := _chao_sob(meio) + Cigarro.RAIO_CIGARRO
	if meio.y <= chao and _voo.y < 0.0:
		xf.origin.y += chao - meio.y
		_quiques += 1
		if _quiques == 1:
			AudioDirector.tocar_ui(&"bituca_chao", -11.0)
			_faiscas(meio)
		if _quiques >= 2 or absf(_voo.y) < 0.6:
			_deitar(xf)
			_cig_pov.global_transform = xf
			return
		_voo = Vector3(_voo.x * QUIQUE.y, -_voo.y * QUIQUE.x, _voo.z * QUIQUE.y)
		_giro_voo *= 0.45
	_cig_pov.global_transform = xf


## A bituca para: rola um palmo e deita atravessada, e a brasa vai morrendo
## (sem apagar: ela ainda esta acesa quando a partida comeca).
func _deitar(xf: Transform3D) -> void:
	_voando = false
	var eixo := xf.basis.x
	eixo.y = 0.0
	if eixo.length() < 0.01:
		eixo = Vector3.RIGHT
	eixo = eixo.normalized()
	var chao_xf := Transform3D(Blunt._base(eixo), xf.origin)
	var meio := chao_xf * Vector3(Cigarro.FILTRO * 0.6, 0.0, 0.0)
	chao_xf.origin.y += _chao_sob(meio) + Cigarro.RAIO_CIGARRO - meio.y
	var rola := Vector3(_voo.x, 0.0, _voo.z) * 0.09
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_cig_pov, "global_transform",
		Transform3D(chao_xf.basis, chao_xf.origin + rola), 0.35)
	# No chao a brasa ainda esta viva do ultimo trago: acende e vai morrendo,
	# e a luz dela pinta um palmo de asfalto (a um centimetro do chao, a de
	# cigarro na mao nao acenderia nada).
	_cig_pov.brasa_parada = 1.0
	_cig_pov.luz_da_brasa = 4.0
	# A cinza quebra no primeiro quique: a cara da brasa fica exposta.
	_cig_pov.cinza = 0.06
	t.tween_property(_cig_pov, "vida", 0.4, 5.0)
	t.tween_property(_cig_pov, "fumaca", 1.0, 0.6)
	print("[abertura] bituca no chao em %s (%.2f m do olho)" % [chao_xf.origin,
		chao_xf.origin.distance_to(get_viewport().get_camera_3d().global_position)])
	_bituca_pousou.emit()


## O chao logo abaixo de um ponto baixo (a bituca). O `_chao_em` vem de vinte
## metros acima e para no que achar primeiro: copa de arvore, fio, marquise — e
## a bituca pousava no ar, fora do quadro.
func _chao_sob(onde: Vector3) -> float:
	var espaco := _cena.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(onde + Vector3.UP * 0.35,
		onde + Vector3.DOWN * 3.0, 1)
	var hit := espaco.intersect_ray(consulta)
	return (hit["position"] as Vector3).y if not hit.is_empty() else _chao_em(onde)


## As faiscas da brasa batendo no chao. `escala` pequena e o aquecimento.
func _faiscas(onde: Vector3, escala: float = 1.0) -> void:
	var f := GPUParticles3D.new()
	f.name = "Faiscas"
	f.one_shot = true
	f.amount = 18
	f.lifetime = 0.55
	f.explosiveness = 0.95
	f.local_coords = false
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.7
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.scale_min = 0.5
	p.scale_max = 1.2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.9),
		Color(0.6, 0.12, 0.02, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	f.process_material = p
	var q := QuadMesh.new()
	q.size = Vector2(0.006, 0.006) * escala
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.15)
	m.emission_energy_multiplier = 3.0
	q.material = m
	f.draw_pass_1 = q
	_cena.add_child(f)
	f.global_position = onde + Vector3.UP * 0.01
	f.emitting = true
	get_tree().create_timer(1.5).timeout.connect(f.queue_free)


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
	# A rua volta a ser do jogador: o preset que ele escolheu, e o relogio da
	# cidade daqui em diante. A troca e interpolada pelo FogController, entao
	# nao ha corte de ar no mesmo quadro em que as tarjas abrem.
	_liberar_a_noite()
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

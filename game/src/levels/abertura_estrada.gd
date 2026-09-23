## A cena da estrada: o primeiro minuto do jogo, antes da cidade.
##
## Onde ela entra
## --------------
## Antes da `Abertura`. A ordem do jogo passa a ser:
##
##     titulo -> NOVO JOGO -> [estrada] -> [abertura] -> primeira missao
##
## A `Abertura` comeca com ele acordado no chao de um parque dizendo "eu tava
## indo pra Sao Thome das Letras". Esta cena e esse "tava indo": a viagem, de
## dentro do carro, na estrada de terra, com a duvida que ele carregava antes de
## acontecer o que acontece. As duas se emendam no preto — esta nao devolve o
## controle ao jogador, so entrega a tarja fechada para a seguinte.
##
## Onde ela ACONTECE
## -----------------
## Quatro mil metros acima da cidade, pelo mesmo motivo que os interiores moram
## dois mil acima: separar por espaco em vez de por cena. Trocar de arvore de
## cena aqui faria a cidade descarregar e recarregar inteira no meio da abertura
## — e a cidade e justamente o que precisa estar pronto quando esta cena acabar.
## Enquanto o carro anda, o ChunkManager monta o bairro do respawn la embaixo,
## de graca, no tempo que a cena ja ia gastar.
##
## Os planos, na ordem
## -------------------
##   1. A camera baixa na beira da estrada; o carro vem de longe e passa rente.
##   2. De cima, acima da copa, acompanhando: a estrada serpenteando na mata e o
##      poente no fundo.
##   3. Rasante ao lado do carro, arvore passando rapido no primeiro plano.
##   4. Dentro do carro: painel, volante, capo, estrada — e o HUD, que so existe
##      neste plano.
##   5. O carro se afastando, engolido pela nevoa. Preto, e entrega.
##
## A camera segue o carro a mao, e nao pelo `Cinema.mover`
## -------------------------------------------------------
## `Cinema.mover` interpola entre dois pontos FIXOS, o que e o certo para uma
## cena em que o assunto esta parado — e e o caso da abertura da cidade inteira.
## Aqui o assunto anda a dezoito metros por segundo: em nove segundos ele
## percorre cento e sessenta metros, e qualquer par de pontos fixos ou perde o
## carro no comeco ou perde no fim. Entao o enquadramento e recalculado por
## quadro a partir de onde o carro esta, que e o que uma camera de verdade em
## cima de um carro de apoio faria.
class_name AberturaEstrada
extends Node

signal terminou()

const PRESET := "res://resources/fog/fog_estrada.tres"
## Climas da Estrada Velha (refs). `--estrada-clima=` escolhe.
const CLIMAS_ESTRADA := {
	"chuva": "res://resources/fog/fog_estrada_chuva.tres",
	"noite_chuva": "res://resources/fog/fog_estrada_noite_chuva.tres",
	"entardecer": "res://resources/fog/fog_estrada.tres",
	"noite": "res://resources/fog/fog_estrada_noite.tres",
	"amanhecer": "res://resources/fog/fog_estrada_amanhecer.tres",
	"dia": "res://resources/fog/fog_estrada_dia.tres",
}

## Clima padrao da cutscene: noite de chuva.
##
## Chuva, e nao poente, porque metade do que esta montado nesta cena — a agua
## empocada na trilha, o leque das rodas, o respingo, o reflexo no leito, o
## escurecimento da terra, o limpador e a trovoada — so existe com `tem_chuva`.
## Com o ceu limpo todo esse maquinario fica no disco sem nunca aparecer.
##
## E NOITE, e nao fim de tarde, por tres motivos que apontam para o mesmo lugar.
## O relogio do jogo nasce as 22:43 e a praca em que ele acorda daqui a um
## minuto esta as 23:15 — um entardecer cinza emendado numa praca de madrugada
## nao fecha. A primeira coisa que ele diz ao acordar e "a ultima coisa que eu
## lembro era o farol na terra": o farol so desenha a terra no escuro. E as
## prints de referencia desta estrada sao todas noturnas, com o facho abrindo a
## mata — e no entardecer o facho era um estouro branco que a propria cena
## precisava abaixar (ver `FAROL_POR_CLIMA`). Fotografado nos dois climas, o
## mesmo plano rasante saiu chapado e cinza a tarde e com o barro vermelho, a
## mata escura e a lanterna acesa a noite.
const CLIMA_PADRAO := "noite_chuva"

## A tempestade, em segundos desde o comeco da cena e quilometros de
## distancia: (quando o raio cai, onde ele cai).
##
## Marcada no relogio da CENA, e nao pendurada nos planos. Uma tempestade nao
## sabe onde estao os cortes, e e justamente por nao saber que ela existe: o
## raio que cai aos seis segundos, a quatro quilometros e meio, so estoura
## treze segundos depois — no meio do plano de cima, com a camera olhando
## outra coisa. Amarrado a um plano, o trovao viraria pontuacao de montagem, e
## pontuacao de montagem e exatamente o que ele nao pode parecer.
##
## Tres, e nao dez. Trovao e evento; um a cada vinte segundos e tempestade,
## um a cada cinco e trilha sonora.
##
## O segundo caiu de 21,5 s para 26,0 s por um motivo de LEGENDA, e nao de
## meteorologia: em 21,5 o clarao batia em cima de "Sem maldade, essa estrada
## nao parece ter fim", e uma frase branca sobre um quadro estourado nao se le.
## A fala acaba aos 25,3 s.
##
##   6,0 s  a 4,5 km  → estoura aos 19,1 s, no plano aereo
##  26,0 s  a 1,4 km  → estoura aos 30,1 s, no plano rasante
##  40,0 s  a 2,9 km  → estoura aos 48,5 s, no plano da poca
const TROVOADA: Array = [[6.0, 4.5], [26.0, 1.4], [40.0, 2.9]]

## Forca do farol por clima: (energia da luz, intensidade do cone).
##
## Ver `CarroCena.ajustar_farol`. O clima que nao esta aqui fica com os
## numeros de fabrica, que sao os da noite.
const FAROL_POR_CLIMA := {
	"chuva": Vector2(2.4, 0.20),
	"amanhecer": Vector2(5.2, 0.52),
	# Noite de chuva: o farol ilumina como na noite seca, mas o cone volumetrico
	# baixa um pouco — a chuva que cai DENTRO dele ja o preenche, e com o cone
	# cheio o rasante voltava a ter a cunha branca.
	"noite_chuva": Vector2(7.5, 0.55),
}

## Nevoa so do plano aereo, na noite.
##
## O plano de dentro do carro e o plano de cima pedem alcances OPOSTOS, e as
## duas prints de referencia mostram exatamente isso: na cabine a bruma fecha
## num paredao a trinta metros, e na aerea o vale inteiro aparece com a estrada
## serpenteando ate o pe da serra. Com um preset so, ou a cabine perde o paredao
## ou a aerea vira uma tela cinza com duas copas de arvore.
##
## E trapaca, e e trapaca de cinema: quem esta assistindo nunca ve os dois
## alcances no mesmo quadro — ha um corte no preto entre eles.
## Um por clima que tenha um. Clima sem entrada aqui nao abre a nevoa no
## plano de cima, e continua com o alcance da cabine.
##
## Era UM caminho so, aplicado quando o clima fosse "noite" — e essa
## condicao era um defeito com cara de decisao. O clima da cutscene de
## verdade nao era a noite, e nele o plano aereo subia a quarenta metros
## olhando setenta a frente com a nevoa fechando em 62: a captura do plano 2
## e uma tela cinza lisa, sem estrada, sem mata e sem serra. O plano de doze
## segundos que existe para mostrar o vale nao mostrava nada, e nao dava
## erro nenhum.
const CLIMAS_AEREOS := {
	"noite": "res://resources/fog/fog_estrada_noite_aerea.tres",
	"chuva": "res://resources/fog/fog_estrada_chuva_aerea.tres",
	"noite_chuva": "res://resources/fog/fog_estrada_noite_chuva_aerea.tres",
}


## Altura em que a estrada e montada, acima da cidade. Ver o cabecalho.
##
## Nao e 2000: essa altura e dos interiores, e a `Abertura` que vem depois entra
## em dois deles. Quatro mil deixa os dois mundos sem chance de se encostarem.
const ALTURA := 4000.0

## Velocidade de cruzeiro, em km/h. Sessenta e oito e o numero da print, e e uma
## velocidade honesta para estrada de terra: acima disso o carro estaria sendo
## irresponsavel, e o sujeito desta cena nao esta com pressa nenhuma.
const CRUZEIRO := 68.0

## Onde o carro comeca. Nao e zero: o primeiro plano precisa de estrada ATRAS da
## camera para o carro chegar de algum lugar, e a camera do plano 1 fica cento e
## vinte metros a frente do ponto de partida.
const PARTIDA := 40.0

# --- plano 1: a passagem ----------------------------------------------------
## A camera fica parada na beira e o carro vem de longe. E o unico plano em que
## a camera nao acompanha nada: ela espera.
const PASSAGEM_ADIANTE := 118.0
const PASSAGEM_LADO := 5.6
const PASSAGEM_ALTURA := 1.05
const PASSAGEM_FOV := 62.0
const PASSAGEM_DURACAO := 9.0

# --- plano 2: a aerea -------------------------------------------------------
## Acima da copa. As arvores desta mata tem ate 16 m, entao 21 e 26 passam por
## cima delas com folga — a camera atravessando uma copa e o defeito classico do
## plano aereo, e ele nao da erro nenhum: so aparece como um borrao verde.
const AEREA_ALTURA := Vector2(41.0, 33.0)
## Deslocamento lateral, do comeco ao fim: a camera cruza de um lado da estrada
## para o outro durante o plano. E o movimento inteiro dele.
const AEREA_LADO := Vector2(6.0, -4.0)
const AEREA_RECUO := Vector2(25.0, 17.0)
## Para onde olha, a frente do carro. Olhar para o carro deixaria ele no meio do
## quadro o tempo todo e a estrada sairia de cena; olhando a frente, o carro
## desce para o terco de baixo e o que ocupa a tela e a estrada e o poente.
const AEREA_MIRA := Vector2(62.0, 78.0)
const AEREA_FOV := Vector2(58.0, 52.0)
const AEREA_DURACAO := 11.0

# --- plano 3: o rasante -----------------------------------------------------
## Ao lado do carro, na altura do farol. O assunto aqui e a VELOCIDADE, e ela
## nao se filma de longe: e o mato passando rente a lente que a produz.
## Lado do rasante. Fica DENTRO do leito de proposito.
##
## Era 3,1 a 4,6 — ou seja, ate um metro e meio para dentro da beira, que e onde
## `KitEstrada.beira` planta moita. Enquanto a beira era rala dava para passar;
## depois de adensar a mata, a camera atravessava moita e a imagem virava um
## retangulo preto com uma janela no meio, que e o interior de uma caixa de
## folha vista de dentro. O rasante e sobre velocidade, e velocidade se filma
## rente ao chao da pista, nao dentro do mato.
const RASANTE_LADO := Vector2(2.5, 3.0)
const RASANTE_ALTURA := Vector2(0.75, 1.15)
## Recuo do rasante. POSITIVO: a camera trilha atras do farol.
##
## Era negativo (-0,5 a -3,2), o que em `_mover_camera` vira `+ dir * recuo` —
## a camera ia parar A FRENTE do carro, dentro do cone volumetrico do farol, que
## tem doze metros de comprimento e tres de raio. Estar dentro de um volume
## aditivo com `cull_disabled` pinta meia tela de branco chapado, e era a cunha
## dura que aparecia na captura. O plano quer o carro entrando no quadro, e para
## isso a camera tem de estar atras do nariz dele.
const RASANTE_RECUO := Vector2(1.8, 4.8)
const RASANTE_MIRA := 5.0
const RASANTE_FOV := 64.0
const RASANTE_DURACAO := 7.5

# --- plano 4: dentro do carro -----------------------------------------------
## Campo de visao do plano de dentro. Mais aberto que o resto da cena de
## proposito: e o que cabe o capo inteiro, as duas colunas e a estrada no mesmo
## quadro, que e o enquadramento da print de referencia.
##
## Era 74, e 74 e campo VERTICAL (o Godot mede o fov pela altura): equivale a
## uns 108 de horizontal, que e lente de acao de capacete, e o que ela fazia
## com o aro do volante — o objeto mais perto da lente na cena inteira — era
## esticar o aro numa elipse deformada que ocupava metade do quadro. Na print
## de referencia o aro e um circulo no terco de baixo. A 66 o capo continua
## inteiro no quadro com as duas colunas, e o aro volta a ser redondo.
const DENTRO_FOV := 66.0
## Para onde a cabeca dele olha, em graus. Quem dirige olha a estrada, e nao
## o ceu; o capo do Marea e longo, entao uns graus abaixo ja deixam o leito
## ocupar o terco de baixo do para-brisa, como nas prints.
##
## -2,5, e nao os -6 de quando o para-brisa era uma placa opaca: com o vidro de
## verdade aparecendo, o painel comia metade do quadro e a estrada era uma
## fresta. Subir a mira empurra o painel para baixo da tarja e da ao leito o
## terco de baixo do vidro.
const DENTRO_PITCH := -2.5
## O plano de dentro era 23 s de 58,5 — quarenta por cento da abertura inteira
## passada dentro de um painel. E o plano mais barato de todos e o menos
## cinema: a camera nao se move em relacao ao assunto, entao o unico movimento
## na tela e a estrada entrando por um retangulo. Quinze segundos cabem duas
## falas e o celular, e continuam dizendo o que ele tem de dizer — que ha uma
## pessoa sozinha dentro daquele carro — sem virar a cena inteira.
const DENTRO_DURACAO := 15.0
## Quanto o olho sobe em relacao ao suporte de camera do carro, em metros.
##
## O suporte esta na altura de olho de alguem sentado, e nessa altura o aro do
## volante cortava o quadro no meio: na captura o aro ficava a 44% da altura da
## tela, acima da linha do horizonte, e a estrada aparecia por uma fresta entre
## o aro e o painel. Na print de referencia o aro fica no terco de baixo.
##
## Medido, e nao chutado: o olho do suporte esta em y 1,16 e z -0,08; o aro do
## volante vai ate 1,15, a 22 cm da lente; a testeira do para-brisa esta em
## 1,21, a 33 cm. Ou seja, a lente esta encostada no volante e na altura da
## testeira — num carro de verdade o olho fica a meio metro do aro e um palmo
## abaixo da testeira. Subir a lente so a enfia no forro (1,36); o que resolve
## e RECUAR vinte centimetros, que e onde um motorista senta. Dali o aro cai
## para o terco de baixo, a testeira sobe para a borda de cima e o retrovisor,
## que ficava a 58 graus da mira (fora de qualquer lente), entra no canto
## direito com o santinho pendurado.
const DENTRO_OLHO_SOBE := 0.0
const DENTRO_OLHO_RECUA := 0.20
## A cabeca nao esta parafusada no banco.
##
## Quanto do arfar e do rolar da carroceria chega ao olho (o pescoco segura o
## resto — e o reflexo que mantem o horizonte parado quando o carro balanca),
## e em que ritmo a cabeca alcanca o carro, por segundo. Metade e atrasada: a
## carroceria sobe a lombada e a cabeca chega um decimo depois, com metade da
## inclinacao. E o que faz a lombada ser sentida no banco e nao na lente.
const CABECA_SEGUE := 0.45
const CABECA_RITMO := 7.0
## Quanto a cabeca vira para dentro da curva, em graus com o volante todo
## virado. Quem dirige olha para onde vai, nao para o capo.
const OLHAR_CURVA := 7.0
## Quanto o corpo se desloca para fora na curva, em metros com o volante todo
## virado. Tres centimetros: o peso mudando de nadega.
const CORPO_NA_CURVA := 0.03
## A respiracao: amplitude em graus e ciclos por segundo. Sub-pixel de
## proposito — e para nunca haver um quadro igual ao anterior, nao para se ver.
const RESPIRA_GRAUS := 0.22
const RESPIRA_HZ := 0.23
## Quanto tempo a cabeca leva para descer ate o celular e para voltar a
## estrada, em segundos. Descer e mais rapido que voltar: a decisao de olhar e
## um impulso, e a de parar de olhar e um "deixa pra la".
const OLHAR_CELULAR_DESCE := 0.55
const OLHAR_CELULAR_VOLTA := 0.75
## Quanto tempo ele fica olhando o aparelho.
const OLHAR_CELULAR_FICA := 2.6

# --- plano da mata: o bicho -------------------------------------------------
## Alguem ve o carro passar, e nao e ninguem da estrada.
##
## O plano e uma camera baixa dentro da mata, atras de folha, acompanhando o
## carro com a cabeca. Nada e dito sobre o que esta olhando e nada aparece em
## quadro: o que faz o plano e a POSTURA da camera — a altura errada para uma
## pessoa, a lente fechada de quem fixa, a respiracao que sobe e desce, e o
## atraso com que a cabeca alcanca o carro. Um tripe na mesma marca da um
## plano de estrada bonito; isto e um bicho.
##
## Nao ha explicacao depois, e nao deve haver. A cidade que vem a seguir e o
## assunto do jogo; isto e a primeira vez que ela e olhada de fora.

## Onde ele fica, medido do eixo.
##
## 5,6 m, e o numero sai de um BOLSAO, nao de um gosto.
##
## A mata desta estrada e plantada em faixas que nao se encostam:
##
##   3,65 a 7,30   `KitEstrada.beira`, capim e samambaia de ate 1,35 m
##   6,20 em diante  `_mata`, os troncos
##   7,00 a 19,0   `_sub_bosque`, caixas de folha de 1,5 a 5,5 m
##
## Entre 3,7 e 6,2 so ha capim baixo. Com o olho a um metro e meio, e a unica
## altura e a unica distancia em que a camera esta DENTRO da mata e mesmo assim
## tem o que enquadrar — tudo o que a esconde ali e capim que ela olha por cima,
## e a folha da frente e a que a toca coloca de proposito.
##
## Ja esteve em 11,5 e em 8,6, as duas dentro do sub-bosque, e as duas deram o
## mesmo resultado por causas diferentes: em 11,5 a camera ficava acima das
## caixas de folha e via a face de cima delas (lajes cinzas); em 8,6 ficava
## dentro delas e o quadro virava uma parede verde chapada com uma fresta. Mata
## gerada nao enquadra, e insistir nela e esperar que o acaso dirija a cena.
##
## De quebra, a 5,6 m a cerca de divisa (3,72 m) passa ENTRE o bicho e a
## estrada, e o carro cruza atras dela.
const MATA_LADO := 5.6
## Altura do olho dele acima do chao da mata ali. Nao e altura de gente: e
## alta demais para alguem agachado e baixa demais para alguem em pe, e essa
## falta de resposta e metade do plano.
##
## Um metro e meio: acima do capim da beira (1,35 no maximo) e bem abaixo de
## qualquer copa. Alto demais para alguem agachado, baixo demais para alguem em
## pe — e essa falta de resposta e metade do plano.
const MATA_ALTURA := 1.5
## Quanto a frente do carro ele esta plantado. O carro tem de VIR de longe,
## passar rente e ir embora: a 68 km/h sao dezenove metros por segundo, entao
## setenta e quatro metros dao quase quatro segundos de aproximacao.
const MATA_ADIANTE := 74.0
## Lente fechada. O resto da cena anda entre 52 e 74 graus; aqui e 44 porque
## predador nao tem visao panoramica de cinema, ele FIXA — e porque a lente
## fechada empilha a chuva e a nevoa entre ele e a estrada.
const MATA_FOV := 44.0
const MATA_DURACAO := 9.0
## Respiracao: quantas vezes por segundo, e quanto sobe e desce em metros.
const MATA_FOLEGO := 0.31
const MATA_FOLEGO_SOBE := 0.055
## Quanto a cabeca alcanca o carro por segundo. Baixo de proposito: o ponto
## do plano e o ATRASO. Camera travada no carro le como camera; camera que
## persegue e chega atrasada le como cabeca virando.
const MATA_SEGUIR := 1.5
## Inclinacao da cabeca, em graus. Pequena e lenta.
const MATA_ROLAR := 2.4
## Ate onde a cabeca vira, em graus a partir do repouso.
##
## Ele NAO acompanha o carro ate o fim, e isso e de proposito duas vezes.
##
## De cinema: um bicho olhando uma coisa passar vira a cabeca ate o limite
## do pescoco e ali para, e o carro sai de quadro sozinho. Uma cabeca que
## acompanha os cento e oitenta graus inteiros e uma camera montada num
## trilho, nao um animal.
##
## E de enquadramento: a toca esta ancorada no MUNDO e nao na cabeca (e o
## que da o paralaxe que faz a folha ler como folha e nao como moldura
## colada na lente). Sem limite, aos quarenta e cinco graus de giro a copa
## da esquerda varria para o centro e o plano virava nove segundos de folha
## verde com uma legenda em cima — medido em 70% do quadro coberto.
const MATA_GIRO_MAX := 30.0

# --- plano da poca: a roda --------------------------------------------------
## A camera no chao, na beira, e o carro passando POR CIMA da agua.
##
## E o unico plano da cena em que o carro TOCA alguma coisa. Todos os outros
## sao o carro atravessando o ar: ate o rasante, que corre ao lado dele, so
## mostra velocidade. Aqui a roda entra na lamina e joga a agua na lente, que
## e a diferenca entre uma estrada molhada e um carro andando numa estrada
## molhada.

## A que distancia do eixo a camera fica, no comeco e no fim. Ela se aproxima
## devagar durante o plano — quarenta centimetros em seis segundos, que o olho
## nao le como movimento e sim como tensao.
##
## Os dois numeros ficam numa FRESTA, e a fresta e estreita: o leito acaba em
## 3,10 m do eixo, `KitEstrada.beira` planta capim de 3,65 em diante e a cerca
## de divisa corre em 3,72. Em 4,2 a camera nascia em cima da linha da cerca e
## a foto saia com um mourao de meio metro de largura atravessado no meio do
## quadro, tapando o carro. Entre 3,15 e 3,55 nao ha nada plantado.
const POCA_LADO := Vector2(3.45, 3.05)
## Altura da lente. Rente ao barro: e de baixo que uma poca tem tamanho.
const POCA_ALTURA := 0.34
## Quanto ATRAS da poca ela mira. O carro entra em quadro por ali.
##
## Atras, e nao a frente. O carro anda no sentido de `s` crescente, entao
## enquanto ele nao chegou na poca ele esta em `s` MENOR que ela: mirando
## adiante, a camera passa o plano inteiro olhando para a estrada vazia com o
## carro chegando pelas costas dela, e o unico quadro em que ele aparece e o
## de quando ja passou.
const POCA_MIRA := 13.0
## Quanto ADIANTE da poca a camera e plantada.
##
## Plantada na propria poca, o carro chega ao lado da lente no instante do
## espirro e sai pela borda do quadro: a captura pegava uma roda traseira e
## uma lanterna, e o carro que deveria estar passando por cima da agua nao
## estava em cena. Quatro metros e meio a frente poem o encontro na
## diagonal, que e onde a roda, a agua e o carro cabem os tres.
const POCA_RECUO := 4.5
const POCA_FOV := 58.0
const POCA_DURACAO := 6.0
## Em que fracao do plano a roda alcanca a agua. Antes disso e aproximacao;
## depois e o carro indo embora com a agua ainda caindo.
const POCA_ENCONTRO := 0.62

# --- plano 5: a saida -------------------------------------------------------
const SAIDA_ALTURA := 6.4
const SAIDA_RECUO := 9.0
const SAIDA_FOV := 56.0
const SAIDA_DURACAO := 6.5

## Distancia de Sao Thome no comeco da viagem, em km. So o rotulo do mapa le
## isto; nao ha destino nenhum no mundo. Serve para a viagem ter tamanho na
## cabeca de quem esta assistindo.
const FALTA_KM := 34.0

# --- textos -----------------------------------------------------------------
## Ele nao esta contando a viagem para ninguem: esta remoendo. Por isso nenhuma
## fala explica o que a imagem ja mostra, e nenhuma delas termina de fechar o
## assunto — a ultima e "ai eu peguei o carro e vim", que e uma pessoa se
## justificando sozinha dentro do proprio carro.
## As falas do trecho da estrada, ACENTUADAS.
##
## Elas eram escritas em ASCII — "Sao Thome", "nao", "ja", "Ai" — como se a
## fonte nao tivesse acento. Tem: `psx_titulo.fnt` e `psx_mono.fnt` trazem os
## 152 glifos, com á, ã, ç, é, ê, í, ó, ú e õ entre eles, e o HUD ja escrevia
## "PRAÇA DA MATRIZ" com cedilha na mesma tela. Era portugues errado impresso no
## primeiro minuto do jogo sem motivo tecnico nenhum.
const FALAS := {
	"passagem": "A gente marcou essa viagem faz uns dois meses.",
	"aerea_1": "São Thomé das Letras. Todo mundo dizia que eu tinha que conhecer.",
	"aerea_2": "Duas horas de terra depois que acaba o asfalto.",
	# A fala do plano do bicho. E a mesma que abria o plano de dentro, e ela
	# ganha com a mudanca: dita por cima de alguem que esta OLHANDO o carro, o
	# "nao parece ter fim" deixa de ser tedio de viagem e vira outra coisa. Ele
	# nao sabe o que disse.
	"mata": "Sem maldade, essa estrada não parece ter fim.",
	"rasante": "Eu que não queria vir.",
	"dentro_1": "Faz uma semana que eu acordo pensando em desmarcar.",
	"dentro_2": "Cheguei a escrever a desculpa no celular. Não mandei.",
	# O que esta na tela do celular no plano de dentro. Ver `_plano_dentro`.
	# O grupo, a ultima pergunta sem resposta, e a desculpa no campo — escrita
	# na primeira pessoa de quem nao quer ir e nao tem coragem de dizer.
	"grupo": "Bonde São Thomé",
	"grupo_hora": "Ontem 23:51",
	"desculpa": "Gente, não vou conseguir ir. Deu um problema aqui em casa, desculpa",
	"poca": "Mas a pousada já tava paga e o pessoal já tava vindo.",
	"saida": "Aí eu peguei o carro e vim.",
}

## A conversa do grupo, de cima para baixo. A ultima e a pergunta que a desculpa
## responderia. Ver `AppMensagens`.
const CONVERSA_DO_GRUPO := [
	["LUCAS", "Pousada paga, galera!!"],
	["MARI", "Sexta cedo, hein. Sem atraso"],
	["eu", "Fechou"],
	["LUCAS", "Vc vem mesmo né?"],
]

enum Plano { NENHUM, PASSAGEM, AEREA, MATA, RASANTE, DENTRO, POCA, SAIDA, CHASE }

## Fotografia por plano: multiplicadores sobre o clima em vigor.
##
## Um preset so nos sessenta e dois segundos e o que mais separa esta cena
## de cinema de verdade. Nao e sobre nevoa mais bonita: e que cada plano
## existe para mostrar uma coisa diferente e pede um ALCANCE diferente para
## mostrar. O rasante quer ver o carro e perder o resto; a cabine quer um
## paredao a trinta metros; a saida quer que o carro desapareca dentro do
## plano, e nao depois do corte.
##
## Multiplicadores, e nao numeros absolutos: assim a mesma direcao de
## fotografia vale no temporal, no poente, na noite e no amanhecer, que tem
## alcances de base muito diferentes entre si. E o plano que nao esta aqui
## fica com o clima puro, que e uma escolha e nao um esquecimento.
##
##   nevoa      multiplica fog_begin e fog_end
##   saturacao  multiplica saturation
##   tinta      multiplica grade_tint, canal a canal
##   ambiente   multiplica ambient_energy
const LUZ_POR_PLANO := {
	# A estrada existe e alguem passa por ela. Clima puro, e de proposito:
	# e contra este quadro que os outros seis sao lidos.
	Plano.PASSAGEM: {&"nevoa": 1.0, &"saturacao": 1.0},
	# Alguem esta vendo. Mais frio e mais lavado que o resto da cena — e a
	# unica troca de temperatura de cor nos sessenta e dois segundos, e ela
	# acontece justamente no plano em que quem olha nao e ninguem da
	# historia.
	Plano.MATA: {&"nevoa": 0.86, &"saturacao": 0.74,
		&"tinta": Color(0.90, 0.97, 1.05), &"ambiente": 0.86},
	# Velocidade. A nevoa ABRE um pouco: o assunto e o mato passando rente, e
	# mato passando rente precisa de mato para passar.
	Plano.RASANTE: {&"nevoa": 1.18, &"saturacao": 1.0},
	# Dentro do carro. Fecha: o para-brisa emoldura trinta metros de estrada e
	# nada mais, que e a claustrofobia do plano.
	#
	# E ESCURECE. Com o ambiente cheio o forro creme saia claro como cabine de
	# carro ao meio-dia, numa estrada de terra as onze da noite debaixo de
	# temporal; a unica luz dentro de um carro assim e a do painel, e a de fora
	# e o farol batendo na chuva. Com o ambiente a sessenta por cento o painel
	# volta a ser a fonte, o forro vira sombra, e o para-brisa passa a ser a
	# coisa mais clara do quadro — que e para onde o olho tem de ir.
	Plano.DENTRO: {&"nevoa": 0.80, &"saturacao": 0.95, &"ambiente": 0.60},
	# A roda na agua. Quase clima puro, com um tico mais de cor: e o unico
	# plano em que a terra molhada aparece de perto.
	Plano.POCA: {&"nevoa": 0.95, &"saturacao": 1.08},
	# Ele vai embora. Fecha em dois tercos para o carro ser ENGOLIDO dentro
	# do plano — sem isto ele ainda esta visivel quando a cortina fecha, e a
	# ultima imagem do primeiro minuto de jogo vira um corte, nao um adeus.
	Plano.SAIDA: {&"nevoa": 0.62, &"saturacao": 0.88,
		&"tinta": Color(0.96, 0.98, 1.02), &"ambiente": 0.94},
}

var _cena: Node3D
var _raiz: Node3D
var _estrada: EstradaBuilder
var _carro: CarroCena
var _ceu: CeuEstrada
var _pocas: PocasEstrada
var _spray: SprayEstrada
var _chuva: Chuva
var _relampago: Relampago
## Relogio da cena inteira, para a trovoada. Nao zera entre planos.
var _relogio_cena: float = 0.0
## Quantos raios da `TROVOADA` ja cairam.
var _raios: int = 0
var _hud: HudEstrada
var _fog: FogController
var _cam: Camera3D

var _plano: Plano = Plano.NENHUM
var _t: float = 0.0
var _duracao: float = 1.0
## O `delta` do quadro corrente, para quem e chamado de dentro de
## `_mover_camera` e precisa integrar no tempo.
var _delta_quadro: float = 0.0
## O motorista: maos, celular e santinho. Ver `MotoristaCena`.
var _motorista: MotoristaCena
## Estado da cabeca no plano de dentro: arfar, rolar e giro que a cabeca ja
## alcancou (radianos), e quanto ela esta virada para o celular, de 0 a 1.
var _cabeca_arfar: float = 0.0
var _cabeca_rolar: float = 0.0
var _cabeca_giro: float = 0.0
var _olhar_celular: float = 0.0
var _tween_olhar: Tween
## Estaca em que a camera parada do plano 1 esta fincada.
var _ancora: float = 0.0
## `far` que a camera cinematica tinha antes desta cena. A abertura da cidade
## depende dele — o plano do poste enxerga a rua inteira — e esta cena o troca
## por 900.
##
## Ja foi 260, com o argumento de que "nao ha nada alem da nevoa numa estrada no
## meio do mato". Isso valia enquanto a mata acabava a 32 m do eixo e a 86 m a
## frente. Agora ela vai a 95 e 259, a cupula esta a 420 e a serra a 340, e um
## `far` curto cortaria justamente o fundo que o plano de cima existe para
## mostrar — o corte aparece como um circulo de vazio em volta da camera.
var _far_anterior: float = 600.0
## Modo jogavel (TASK AAA): WASD + V 1P/3P. Cutscene continua o default.
var _jogavel: bool = false
## True = chase 3P; false = cabine 1P (default).
var _terceira: bool = false

# --- estado do plano da mata ------------------------------------------------
## Onde o olho do bicho esta fincado, em coordenada local da estrada.
var _bicho_olho := Vector3.ZERO
## O eixo transversal da toca. O bafo lateral da respiracao anda por ele.
var _bicho_lado := Vector3.RIGHT
## Para onde ele olha em repouso: o eixo da estrada. E a partir daqui que
## `MATA_GIRO_MAX` conta.
var _bicho_frente := Vector3.FORWARD
## Para onde a cabeca esta olhando AGORA, que nao e onde o carro esta: ela
## persegue e chega atrasada, e o atraso e o plano.
var _bicho_mira := Vector3.ZERO

# --- estado do plano da poca ------------------------------------------------
## A poca escolhida: (s, deslocamento lateral, meia largura, meio comprimento).
var _poca := Vector4.ZERO



func executar(cena: Node3D) -> void:
	_cena = cena
	Cinema.fechar_de_imediato()
	Cinema.iniciar(true)
	_montar_mundo()

	_cam = Cinema.assumir()
	_far_anterior = _cam.far
	_cam.far = 900.0
	_cam.near = 0.08
	set_process(true)

	if _quer_jogavel():
		await _correr_jogavel()
		_desmontar()
		terminou.emit()
		queue_free()
		return

	var plano_cap := _plano_captura()
	if plano_cap != Plano.NENHUM:
		await _segurar_captura(plano_cap)
		_desmontar()
		terminou.emit()
		queue_free()
		return

	# A ordem, e o porque dela. Sete planos, e so um deles dentro do carro:
	#
	#   passagem  a estrada existe, e alguem passa por ela
	#   aerea     onde isso fica no mundo
	#   mata      alguem esta vendo                (o plano do bicho)
	#   rasante   a velocidade
	#   dentro    quem esta dirigindo
	#   poca      o carro tocando o chao           (a roda na agua)
	#   saida     ele vai embora
	#
	# Os dois planos novos entram nos dois lugares em que a cena antiga tinha
	# um corte seco de um plano de fora para outro de fora. O de dentro encolheu
	# para treze segundos e as falas que sobraram dele foram para os planos
	# novos — nenhuma se perdeu, e nenhuma mudou de ordem.
	await _plano_passagem()
	await _plano_aerea()
	await _plano_mata()
	await _plano_rasante()
	await _plano_dentro()
	await _plano_poca()
	await _plano_saida()

	_desmontar()
	terminou.emit()
	queue_free()


# --- montagem ---------------------------------------------------------------

func _montar_mundo() -> void:
	_raiz = Node3D.new()
	_raiz.name = "MundoEstrada"
	_raiz.position = Vector3(0.0, ALTURA, 0.0)
	_cena.add_child(_raiz)

	_estrada = EstradaBuilder.new()
	_estrada.name = "Estrada"
	_raiz.add_child(_estrada)

	_carro = CarroCena.new()
	_carro.name = "Carro"
	_carro.estrada = _estrada
	_raiz.add_child(_carro)
	_carro.distancia = PARTIDA
	_carro.velocidade = CRUZEIRO
	# Monta o chao antes de a cortina abrir. Sem isto o primeiro quadro da cena
	# e o carro suspenso no vazio enquanto os cinco trechos sobem.
	_estrada.atualizar(PARTIDA)
	_carro.assentar()

	# O motorista mora DENTRO da cabine, e some com ela nos planos de fora.
	if _carro.cabine != null:
		_motorista = MotoristaCena.new()
		_motorista.name = "Motorista"
		_carro.cabine.add_child(_motorista)
		_motorista.montar(_carro)
		# Bancada: `--sem-vidro` esconde os vidros da cabine para ver o que esta
		# atras deles; `--vidro-limpo` liga o desembacador no talo e tira a
		# sujeira, para separar vidro de mundo quando o para-brisa sai cinza.
		var args := OS.get_cmdline_user_args()
		if args.has("--sem-vidro"):
			var v := _carro.cabine.get_node_or_null("Vidros") as Node3D
			if v != null:
				v.visible = false
		if args.has("--vidro-limpo"):
			_carro.cabine.desembacador = 1.0
			_carro.cabine.sujeira = 0.0
		if OS.get_cmdline_user_args().has("--debug-cabine"):
			print("[cabine] olho=%s espelho=%s pivo=%s filhos=%s"
				% [_carro.cabine.olho(), _carro.cabine.ponto_do_espelho(),
					_carro.cabine.pivo_do_volante(), _motorista.get_children()])
			var pv := _carro.cabine.pivo_do_volante()
			if pv != null:
				print("[cabine] pivo pos=%s rot=%s filhos=%s" % [pv.position, pv.rotation, pv.get_children()])

	_ceu = CeuEstrada.new()
	_ceu.name = "Ceu"
	_raiz.add_child(_ceu)

	_montar_agua()

	_hud = HudEstrada.new()
	_hud.name = "HudEstrada"
	_cena.add_child(_hud)
	_hud.visible = false

	# O clima da estrada por cima do da cidade. `liberar` no fim devolve o
	# preset do jogador, e sem essa devolucao a cidade inteira ficaria em fim de
	# tarde de outro lugar.
	_fog = _cena.get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if _fog != null:
		_fog.forcar(_caminho_clima())
	_ligar_farois_se_noite()
	if _estrada != null:
		_estrada.clima_id = _clima_id()
		if _e_noite():
			_estrada.spawn_vulto_beira(_carro.distancia if _carro else 80.0)


## A agua da cena: onde ela empoca, o que a roda levanta dela, e onde a gota
## bate quando cai.
##
## As tres coisas sao montadas aqui e nao no `EstradaBuilder` porque nenhuma
## delas e o mundo: sao a CHUVA sobre o mundo, e o mesmo mundo existe seco em
## `--estrada-clima=dia`. O builder monta estrada; esta funcao molha ela.
func _montar_agua() -> void:
	_pocas = PocasEstrada.new()
	_pocas.name = "Pocas"
	_raiz.add_child(_pocas)

	_spray = SprayEstrada.new()
	_spray.name = "Spray"
	_raiz.add_child(_spray)
	_spray.acompanhar(_carro, _carro.medidas(), _pocas)
	# A poca segue a roda, e nao o contrario. Ver `PocasEstrada.trilhas`: a
	# trilha desenhada no leito tem 2,20 m entre os centros e a bitola do Marea
	# tem 1,42, entao agua plantada no sulco desenhado passaria meio metro ao
	# lado do pneu — a cena inteira, sem um espirro.
	_pocas.trilhas = _spray.caminhos_de_roda()
	_pocas.distancia = _carro.distancia

	# A Chuva ja existe na cena da cidade e segue a camera corrente, entao ela
	# sobe com a camera ate os quatro mil metros sozinha. O que ela NAO sabe e
	# onde fica o chao daqui: o respingo dela nasce colado no zero do mundo, que
	# e o asfalto da cidade, quatro quilometros abaixo do carro.
	_chuva = _cena.get_tree().get_first_node_in_group(&"chuva") as Chuva
	if _chuva == null:
		_chuva = _cena.get_node_or_null("Chuva") as Chuva

	# Encharcado ANTES do primeiro quadro. A memoria lenta da agua leva noventa
	# segundos para molhar e a cena inteira dura pouco mais de sessenta: sem
	# isto a abertura acabaria com a estrada em dois tercos de molhado, ou seja,
	# chovendo o tempo todo sobre um chao que nunca chega a encharcar. O
	# temporal ja estava caindo muito antes de o carro entrar em quadro.
	if not _chove():
		return
	Clima.encharcar(1.0)

	_relampago = Relampago.new()
	_relampago.name = "Relampago"
	# Filho da CENA, e nao do `MundoEstrada`: a direcional do clarao ilumina por
	# direcao e nao por posicao, entao subir com o mundo nao muda nada, e quando
	# a estrada for desmontada o trovao ja agendado ainda precisa de um no vivo
	# para chegar ao fim do proprio temporizador.
	_cena.add_child(_relampago)
	if _ceu != null:
		_relampago.acompanhar_ceu(_ceu.material())


func _desmontar() -> void:
	set_process(false)
	Lente.travar_desfoque(-1.0)
	if Celular.app_atual() == &"mensagens":
		Celular.fechar()
	if _cam != null and is_instance_valid(_cam):
		_cam.far = _far_anterior
	if _fog != null and is_instance_valid(_fog):
		_fog.liberar()
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
		_hud.queue_free()
		_hud = null
	if _raiz != null and is_instance_valid(_raiz):
		_raiz.queue_free()


# --- planos -----------------------------------------------------------------

func _plano_passagem() -> void:
	_ancora = _carro.distancia + PASSAGEM_ADIANTE
	_comecar(Plano.PASSAGEM, PASSAGEM_DURACAO)
	await Cinema.clarear(0.9)
	Cinema.legenda(FALAS["passagem"], 4.2)
	await _esperar(PASSAGEM_DURACAO - 0.9)
	await Cinema.escurecer(0.4)


func _plano_aerea() -> void:
	_comecar(Plano.AEREA, AEREA_DURACAO)
	await Cinema.clarear(0.6)
	Cinema.legenda(FALAS["aerea_1"], 4.6)
	await _esperar(5.4)
	Cinema.legenda(FALAS["aerea_2"], 4.0)
	await _esperar(AEREA_DURACAO - 6.0)
	await Cinema.escurecer(0.4)


## O plano do bicho. Ver o bloco de constantes MATA_*.
func _plano_mata() -> void:
	# A toca e montada no lugar exato em que a camera vai ficar, e ANTES de a
	# cortina abrir: ela e a moldura do plano, e um quadro sem ela ja entrega
	# que a folha foi colocada.
	_ancora = _carro.distancia + MATA_ADIANTE
	_bicho_olho = EstradaBuilder.ponto_em(_ancora)
	_bicho_olho += EstradaBuilder.lado_em(_ancora) * MATA_LADO
	_bicho_olho.y += EstradaBuilder.altura_lateral(MATA_LADO) + MATA_ALTURA
	_bicho_lado = EstradaBuilder.direcao_em(_ancora)
	_bicho_mira = _carro.position + Vector3.UP * 0.8
	_bicho_frente = _repouso_do_bicho()
	if _estrada != null:
		_estrada.spawn_toca(_ancora, 1.0, MATA_LADO, MATA_ALTURA)
	_comecar(Plano.MATA, MATA_DURACAO)
	await Cinema.clarear(0.7)
	Cinema.legenda(FALAS["mata"], 4.0)
	await _esperar(MATA_DURACAO - 1.3)
	await Cinema.escurecer(0.6)
	if _estrada != null:
		var toca := _estrada.get_node_or_null("Toca")
		if toca != null:
			toca.queue_free()


## O plano da roda na poca. Ver o bloco de constantes POCA_*.
func _plano_poca() -> void:
	# A camera e plantada numa poca QUE EXISTE, e nao num ponto bonito da
	# estrada com a esperanca de haver agua. A poca e uma funcao de `s`
	# (`PocasEstrada.poca_da_celula`), entao da para perguntar onde esta a
	# proxima e ir ate la — que e a unica forma de o plano mostrar sempre o que
	# ele existe para mostrar.
	var alcance := _carro.velocidade / 3.6 * POCA_DURACAO * POCA_ENCONTRO
	_poca = _proxima_poca(_carro.distancia + alcance)
	_ancora = _poca.x
	_comecar(Plano.POCA, POCA_DURACAO)
	await Cinema.clarear(0.5)
	Cinema.legenda(FALAS["poca"], 3.6)
	await _esperar(POCA_DURACAO - 1.0)
	await Cinema.escurecer(0.5)


## A primeira poca a partir de `s_min`. Nunca devolve vazio: se as proximas
## celulas sairem secas, o laco anda ate achar uma — com 62% de chance por
## celula de sete metros, doze celulas sem agua tem probabilidade de um em dez
## milhoes, e ainda assim o limite existe para o laco nao ser infinito.
func _proxima_poca(s_min: float) -> Vector4:
	var i := floori(s_min / PocasEstrada.PASSO_S)
	for k in 24:
		var cand := _pocas.poca_da_celula(i + k)
		if cand.z > 0.0 and cand.x >= s_min:
			return cand
	# Sem agua no trecho: a camera ainda assim tem de ficar em algum lugar, e
	# o plano vira um rasante rente ao chao. Feio, mas nunca preto.
	return Vector4(s_min, _pocas.trilhas[0] if not _pocas.trilhas.is_empty() else 0.0,
		0.4, 1.2)


func _plano_rasante() -> void:
	_comecar(Plano.RASANTE, RASANTE_DURACAO)
	await Cinema.clarear(0.5)
	Cinema.legenda(FALAS["rasante"], 3.2)
	await _esperar(RASANTE_DURACAO - 0.9)
	await Cinema.escurecer(0.45)


## O plano de dentro do carro. E o unico que dura o bastante para quatro falas.
##
## Sem HUD. A barra de vida, o icone de lanterna e o cartao LOCAL/HORA ficavam
## ligados durante a cutscene: o cartao brigava com a legenda pelo mesmo canto
## da tela e a barra anunciava controle onde o jogador nao tem nenhum. O HUD e
## da parte JOGAVEL — sobe em `_modo_jogavel` e na troca de camera, e so.
##
## O celular
## ---------
## Depois da primeira fala a cabeca baixa, a mao direita ergue o aparelho na
## frente do volante — tapando a estrada — e a tela do celular do jogo sobe:
## o grupo da viagem, "vc vem mesmo ne?" sem resposta, e no campo a desculpa
## escrita, com o ENVIAR aceso. Ele segura o apagar ate o campo esvaziar,
## guarda o telefone e volta a olhar a estrada. So ENTAO vem a segunda fala —
## "cheguei a escrever a desculpa no celular. Nao mandei." —, que ja nao conta
## nada: confirma o que o jogador acabou de ver ele fazer.
##
## E a unica acao do motorista em todo o primeiro minuto de jogo, e e a que o
## resto da abertura inteira depende: ele quase nao veio.
func _plano_dentro() -> void:
	_comecar(Plano.DENTRO, DENTRO_DURACAO)
	await Cinema.clarear(0.7)
	Cinema.legenda(FALAS["dentro_1"], 4.2)
	await _esperar(4.6)
	# O olhar vai um pouco antes da mao: a decisao de olhar e o que faz a mao
	# subir, e nao o contrario.
	_olhar_o_celular(true)
	await _esperar(0.2)
	if _motorista != null:
		_motorista.mostrar_celular(true)
	await _esperar(0.45)
	var app := Celular.abrir_conversa_em_cena(FALAS["grupo"], CONVERSA_DO_GRUPO,
		FALAS["grupo_hora"], FALAS["desculpa"])
	# Tempo de ler: a pergunta, a desculpa, o cursor piscando.
	await _esperar(OLHAR_CELULAR_FICA)
	app.apagar_rascunho()
	var espera := 0.0
	while not app.rascunho_vazio() and espera < 3.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	await _esperar(0.45)
	Celular.fechar()
	_olhar_o_celular(false)
	await _esperar(0.35)
	if _motorista != null:
		_motorista.mostrar_celular(false)
	await _esperar(0.5)
	Cinema.legenda(FALAS["dentro_2"], 4.2)
	var gasto := 0.7 + 4.6 + 0.2 + 0.45 + OLHAR_CELULAR_FICA + espera + 0.45 + 0.35 + 0.5
	await _esperar(maxf(4.4, DENTRO_DURACAO - gasto))
	await Cinema.escurecer(0.5)


## Vira (ou desvira) a cabeca para o celular, no tempo de `OLHAR_CELULAR_*`.
func _olhar_o_celular(olhar: bool) -> void:
	if _tween_olhar != null and _tween_olhar.is_valid():
		_tween_olhar.kill()
	_tween_olhar = create_tween()
	_tween_olhar.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tween_olhar.tween_property(self, "_olhar_celular", 1.0 if olhar else 0.0,
		OLHAR_CELULAR_DESCE if olhar else OLHAR_CELULAR_VOLTA)


## A fotografia deste plano. Chamada por `_comecar`, antes de a cortina abrir.
##
## O plano de cima continua sendo caso a parte, e nao por capricho: ele pede um
## alcance que nenhum multiplicador alcanca. A cabine fecha em cinquenta metros
## e a aerea precisa de cento e setenta e oito — tres vezes e meia — porque dali
## se ve o vale inteiro. Isso e outro clima, e mora num `.tres` proprio.
##
## Era uma funcao que so sabia ligar e desligar a nevoa aerea, e so na noite.
## O clima da cutscene nao era a noite: o plano de doze segundos que existe
## para mostrar o vale saia como uma tela cinza lisa, sem erro nenhum no log.
func _aplicar_luz_do_plano(plano: Plano) -> void:
	if _fog == null or not is_instance_valid(_fog):
		return
	var id := _clima_id()
	if plano == Plano.AEREA and CLIMAS_AEREOS.has(id):
		_fog.forcar(String(CLIMAS_AEREOS[id]))
		return
	var mods: Dictionary = LUZ_POR_PLANO.get(plano, {})
	if mods.is_empty():
		_fog.forcar(_caminho_clima())
		return
	var base := load(_caminho_clima()) as FogPreset
	if base == null:
		return
	# DUPLICADO, sempre. Sem a copia, o primeiro plano grava o proprio ajuste
	# dentro do recurso do clima, o segundo multiplica por cima do primeiro, e
	# em sete planos a estrada acaba com um alcance de tres metros. O recurso
	# carregado e compartilhado por toda a execucao.
	var p := base.duplicate() as FogPreset
	var nevoa := float(mods.get(&"nevoa", 1.0))
	p.fog_begin *= nevoa
	p.fog_end *= nevoa
	p.saturation *= float(mods.get(&"saturacao", 1.0))
	var tinta: Color = mods.get(&"tinta", Color.WHITE)
	p.grade_tint = Color(p.grade_tint.r * tinta.r, p.grade_tint.g * tinta.g,
		p.grade_tint.b * tinta.b)
	p.ambient_energy *= float(mods.get(&"ambiente", 1.0))
	_fog.forcar_preset(p)
func _plano_saida() -> void:
	_ancora = _carro.distancia - SAIDA_RECUO
	_comecar(Plano.SAIDA, SAIDA_DURACAO)
	await Cinema.clarear(0.6)
	Cinema.legenda(FALAS["saida"], 3.6)
	await _esperar(SAIDA_DURACAO - 1.2)
	# Emenda Estrada -> Praca: esconde o HUD no COMECO do fade-to-black.
	# Se sumir so no _desmontar (depois do preto), o LOCAL: ESTRADA VELHA
	# ainda pode piscar por um quadro na troca. A cortina e o unico ponto
	# de costura — cidade._rodar_abertura ja esta no preto quando chama Abertura.
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
	await Cinema.escurecer(0.8)


func _comecar(plano: Plano, duracao: float) -> void:
	_plano = plano
	_t = 0.0
	_duracao = maxf(0.01, duracao)
	_aplicar_luz_do_plano(plano)
	# Cabine so existe para a camera de dentro. Nos planos externos ela
	# atravessava o para-brisa — espelho e limpador saiam a frente do vidro
	# e, com o snap da lataria, tremiam como um inseto preto no cowl.
	if _carro != null:
		_carro.mostrar_cabine(plano == Plano.DENTRO)
	# Sem desfoque de movimento dentro do carro.
	#
	# O desfoque da `Lente` reprojeta o quadro anterior pela camera e assume que
	# o mundo e parado: para ele, o painel e o volante — que andam JUNTO com a
	# lente a dezoito metros por segundo — sao geometria em movimento, e saem
	# borrados como se fossem a estrada. Era o painel derretido das capturas da
	# cabine. De fora o desfoque esta certo, porque de fora tudo o que anda e o
	# carro, e o carro deve borrar.
	Lente.travar_desfoque(0.0 if plano == Plano.DENTRO else -1.0)
	if plano == Plano.DENTRO:
		# A cabeca comeca alinhada com o carro, e nao vindo de onde a camera do
		# plano anterior estava.
		_cabeca_arfar = 0.0
		_cabeca_rolar = 0.0
		_cabeca_giro = 0.0
	# Um quadro de camera ANTES de a cortina abrir. Sem isto o primeiro quadro
	# visivel do plano e o enquadramento do plano anterior, e o corte aparece.
	_mover_camera(0.0)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(maxf(0.0, segundos)).timeout


# --- camera -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _carro == null or not is_instance_valid(_carro):
		return
	_carro.avancar(delta)
	_t += delta
	_delta_quadro = delta
	_relogio_cena += delta
	_atualizar_trovoada()
	_atualizar_agua()
	if _motorista != null:
		_motorista.atualizar(_carro.acel_local, _carro.inclinacao(), delta)
	if _plano == Plano.MATA:
		_seguir_com_a_cabeca(delta)
	_mover_camera(clampf(_t / _duracao, 0.0, 1.0))
	if _hud != null and _hud.visible:
		_hud.mostrar(_carro.position, _carro.rotation.y, _carro.velocidade,
			_carro.marcha(), FALTA_KM - _carro.distancia * 0.001)


## O que a agua precisa saber a cada quadro: onde o carro esta, e onde fica o
## chao debaixo da lente.
##
## A altura do chao nao e constante nesta cena e nao pode ser: a estrada tem
## lombada de ate 2,6 m de amplitude, e o plano aereo poe a camera quarenta
## metros acima dela. O respingo da chuva nasce no chao sob a CAMERA — no plano
## de cima isso e a copa da mata, e ali nao deve haver respingo nenhum, que e
## o que a distancia acaba resolvendo sozinha.
## Deixa cair o proximo raio quando chegar a hora dele. Ver `TROVOADA`.
func _atualizar_trovoada() -> void:
	if _relampago == null or not is_instance_valid(_relampago):
		return
	if _raios >= TROVOADA.size():
		return
	var proximo: Array = TROVOADA[_raios]
	if _relogio_cena < float(proximo[0]):
		return
	_raios += 1
	_relampago.disparar(float(proximo[1]))


func _atualizar_agua() -> void:
	if _pocas != null and is_instance_valid(_pocas):
		_pocas.distancia = _carro.distancia
	if _chuva == null or not is_instance_valid(_chuva) or _cam == null:
		return
	# A lataria entre a chuva e o ouvido. E o unico plano em que a camera esta
	# debaixo de alguma coisa — e treze dos sessenta e dois segundos.
	_chuva.abrigo = 1.0 if _plano == Plano.DENTRO else 0.0
	# O `s` do ponto da estrada mais proximo da camera nao tem forma fechada, e
	# nao precisa ter: a camera desta cena nunca esta longe do carro, entao o
	# `s` dele e a melhor estimativa que existe, e o erro de altura entre dois
	# pontos da estrada a vinte metros um do outro e de poucos centimetros.
	_chuva.chao_y = ALTURA + PocasEstrada.altura_do_leito(_carro.distancia, 0.0)


## A cabeca do bicho alcancando o carro.
##
## `move_toward` e nao `lerp` de propósito: `lerp` por quadro da uma
## aproximacao exponencial que nunca chega, e o que se ve e uma camera que
## amortece — movimento de tripe com mola. Uma cabeca vira a uma velocidade e
## PARA quando alcanca, e e isso que faz o plano ler como bicho e nao como
## equipamento. A velocidade cresce com a distancia porque o carro passando
## rente cruza o campo de visao muito mais rapido do que quando esta longe.
func _seguir_com_a_cabeca(delta: float) -> void:
	var alvo := _limitar_giro(_carro.position + Vector3.UP * 0.8)
	var falta := alvo - _bicho_mira
	var passo := falta.length() * MATA_SEGUIR * delta
	_bicho_mira = _bicho_mira.move_toward(alvo, maxf(passo, 0.4 * delta))


## O eixo da estrada visto da toca, no plano. E o repouso do pescoco.
func _repouso_do_bicho() -> Vector3:
	var para := EstradaBuilder.ponto_em(_ancora) - _bicho_olho
	para.y = 0.0
	if para.length_squared() < 0.0001:
		return Vector3.FORWARD
	return para.normalized()


## Trava o alvo dentro do curso do pescoco, mantendo a distancia.
##
## A altura do alvo passa INTEIRA: o limite e do giro horizontal, e nao da
## inclinacao — travar as duas faria a cabeca parar de descer quando o carro
## chega perto, que e o momento em que ela mais deveria descer.
func _limitar_giro(alvo: Vector3) -> Vector3:
	var para := alvo - _bicho_olho
	var plano := Vector3(para.x, 0.0, para.z)
	if plano.length_squared() < 0.0001:
		return alvo
	var dist := plano.length()
	var ang := _bicho_frente.signed_angle_to(plano.normalized(), Vector3.UP)
	var teto := deg_to_rad(MATA_GIRO_MAX)
	if absf(ang) <= teto:
		return alvo
	var preso := _bicho_frente.rotated(Vector3.UP, clampf(ang, -teto, teto))
	return _bicho_olho + preso * dist + Vector3(0.0, para.y, 0.0)


func _mover_camera(k: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var s := _carro.distancia
	var carro := _carro.position
	var dir := EstradaBuilder.direcao_em(s)
	var lado := EstradaBuilder.lado_em(s)

	match _plano:
		Plano.PASSAGEM:
			var p := EstradaBuilder.ponto_em(_ancora)
			var l := EstradaBuilder.lado_em(_ancora)
			_enquadrar(p + l * PASSAGEM_LADO + Vector3.UP * PASSAGEM_ALTURA,
				carro + Vector3.UP * 0.7, PASSAGEM_FOV)
		Plano.AEREA:
			var de := carro + lado * lerpf(AEREA_LADO.x, AEREA_LADO.y, k) \
				- dir * lerpf(AEREA_RECUO.x, AEREA_RECUO.y, k) \
				+ Vector3.UP * lerpf(AEREA_ALTURA.x, AEREA_ALTURA.y, k)
			var mira := EstradaBuilder.ponto_em(
				s + lerpf(AEREA_MIRA.x, AEREA_MIRA.y, k))
			_enquadrar(de, mira, lerpf(AEREA_FOV.x, AEREA_FOV.y, k))
		Plano.MATA:
			# A respiracao. Duas ondas de periodos sem razao inteira entre si, pela
			# mesma razao de sempre: uma onda so vira metronomo em dez segundos, e
			# o plano tem nove.
			var sobe := sin(_t * TAU * MATA_FOLEGO)
			var bafo := sin(_t * TAU * MATA_FOLEGO * 0.41 + 1.9)
			var de_bicho := _bicho_olho
			de_bicho.y += sobe * MATA_FOLEGO_SOBE
			# O peso passando de um lado para o outro. Tres centimetros e meio: no
			# limite do que se percebe, que e onde ele deve ficar. Mais que isso
			# vira camera na mao.
			de_bicho += _bicho_lado * (bafo * 0.035)
			_enquadrar(de_bicho, _bicho_mira, MATA_FOV,
				deg_to_rad(MATA_ROLAR) * bafo)
		Plano.POCA:
			var s_p := _poca.x + POCA_RECUO
			var sinal := signf(_poca.y) if absf(_poca.y) > 0.01 else 1.0
			var p_poca := EstradaBuilder.ponto_em(s_p)
			var l_poca := EstradaBuilder.lado_em(s_p)
			var fora := lerpf(POCA_LADO.x, POCA_LADO.y, k) * sinal
			var de_poca := p_poca + l_poca * fora
			de_poca.y += EstradaBuilder.altura_lateral(absf(fora)) + POCA_ALTURA
			# Mira A FRENTE da poca, e nao nela: o carro entra em quadro por ali e
			# vem CRESCENDO ate a agua. Mirando na propria poca, o carro aparece
			# grande de uma vez, ja em cima dela, e o plano perde a chegada.
			_enquadrar(de_poca,
				EstradaBuilder.ponto_em(s_p - POCA_MIRA) + Vector3.UP * 0.75,
				POCA_FOV)
		Plano.RASANTE:
			var de := carro + lado * lerpf(RASANTE_LADO.x, RASANTE_LADO.y, k) \
				- dir * lerpf(RASANTE_RECUO.x, RASANTE_RECUO.y, k) \
				+ Vector3.UP * lerpf(RASANTE_ALTURA.x, RASANTE_ALTURA.y, k)
			_enquadrar(de, carro + dir * RASANTE_MIRA + Vector3.UP * 0.8,
				RASANTE_FOV)
		Plano.DENTRO:
			_de_dentro()
		Plano.SAIDA:
			var p := EstradaBuilder.ponto_em(_ancora)
			var l := EstradaBuilder.lado_em(_ancora)
			_enquadrar(p + l * 1.6 + Vector3.UP * SAIDA_ALTURA,
				carro + Vector3.UP * 0.9, SAIDA_FOV)
		Plano.CHASE:
			# 3a pessoa atras do hatch (ref 03): mais perto, menos alto.
			var de_chase := carro - dir * 6.2 + Vector3.UP * 1.55 + lado * 0.2
			_enquadrar(de_chase, carro + dir * 8.0 + Vector3.UP * 0.55, 56.0)
		_:
			pass


## O plano de dentro nao "enquadra": ele HERDA a pose do suporte de camera, que
## e filho do carro e por isso ja carrega a lombada, a inclinacao da curva e o
## balanco da suspensao. Calcular esse movimento de novo aqui daria duas
## versoes dele, e elas divergiriam no primeiro ajuste.
##
## O que a cabeca poe por cima
## ---------------------------
## Herdar a pose inteira e ser uma camera parafusada no banco, e ninguem dirige
## parafusado. Quatro coisas separam uma cabeca de um suporte, e as quatro sao
## pequenas de proposito:
##
##   o pescoco segura metade do arfar e do rolar, com atraso (`CABECA_SEGUE`)
##   a cabeca vira para dentro da curva e o corpo escorrega para fora
##   a respiracao, sub-pixel
##   a virada para o celular, quando a fala pede
##
## A virada para o celular e uma interpolacao de BASE entre "olhando a estrada"
## e "olhando o aparelho", e nao um par de angulos fixos: o aparelho anda com a
## mao, e a mao esta subindo enquanto a cabeca desce.
func _de_dentro() -> void:
	var pose := _carro.suporte_camera.global_transform
	var euler := pose.basis.get_euler()
	var curva := _carro.curva_normalizada()
	# Zero no quadro sem tempo (o `assentar` de `_comecar`): a cabeca nasce
	# alinhada com o carro.
	var k := 1.0 - exp(-_delta_quadro * CABECA_RITMO) if _delta_quadro > 0.0 else 1.0
	_cabeca_arfar = lerpf(_cabeca_arfar, euler.x * CABECA_SEGUE, k)
	_cabeca_rolar = lerpf(_cabeca_rolar, euler.z * CABECA_SEGUE, k)
	_cabeca_giro = lerpf(_cabeca_giro, -curva * deg_to_rad(OLHAR_CURVA), k * 0.5)
	var respira := sin(_t * TAU * RESPIRA_HZ) * deg_to_rad(RESPIRA_GRAUS)

	var origem := pose.origin + pose.basis.y * DENTRO_OLHO_SOBE \
		+ pose.basis.z * DENTRO_OLHO_RECUA \
		- pose.basis.x * (curva * CORPO_NA_CURVA)
	if OS.get_cmdline_user_args().has("--debug-cabine") and Engine.get_process_frames() % 30 == 0:
		print("[cabine] euler=%s arfar=%.3f rolar=%.3f giro=%.3f incl=%s olhar=%.2f origem=%s"
			% [euler, _cabeca_arfar, _cabeca_rolar, _cabeca_giro, _carro.inclinacao(),
				_olhar_celular, origem])
	var estrada := Basis.from_euler(Vector3(
		_cabeca_arfar + deg_to_rad(DENTRO_PITCH) + respira,
		euler.y + _cabeca_giro,
		_cabeca_rolar))
	var base := estrada
	if _olhar_celular > 0.001 and _motorista != null:
		var alvo := _motorista.ponto_do_celular()
		if origem.distance_squared_to(alvo) > 0.0001:
			var para_o_fone := Transform3D(Basis(), origem).looking_at(alvo, pose.basis.y).basis
			base = estrada.slerp(para_o_fone, smoothstep(0.0, 1.0, _olhar_celular))
	_cam.fov = DENTRO_FOV
	_cam.global_transform = Transform3D(base, origem)


## Poe a camera num ponto olhando para outro, os dois em coordenada da estrada.
##
## A conversao para mundo acontece AQUI, e num lugar so. Todo plano trabalha em
## coordenada local da estrada — que e onde o caminho, o carro e o mapa vivem —
## e esquecer de somar os quatro mil metros num deles daria uma camera apontada
## para o chao da cidade, que e uma imagem preta sem nenhuma mensagem de erro.
## `rolagem` inclina a camera em torno do proprio eixo de visao, em radianos.
## Zero em todos os planos menos o da mata: um tripe nao roda, uma cabeca sim,
## e dois graus e meio de inclinacao acompanhando a respiracao sao a diferenca
## entre uma camera escondida no mato e um bicho escondido no mato.
func _enquadrar(de: Vector3, para: Vector3, fov: float,
		rolagem: float = 0.0) -> void:
	_cam.fov = fov
	_cam.global_position = de + Vector3(0.0, ALTURA, 0.0)
	var alvo := para + Vector3(0.0, ALTURA, 0.0)
	if _cam.global_position.distance_squared_to(alvo) < 0.0001:
		return
	_cam.look_at(alvo, Vector3.UP)
	if not is_zero_approx(rolagem):
		# Depois do `look_at`, e em torno do eixo LOCAL de visao: aplicada antes,
		# a inclinacao seria desfeita pelo proprio look_at, que reconstroi a base
		# inteira a partir do vetor para cima do mundo.
		_cam.global_basis = _cam.global_basis * Basis(Vector3.FORWARD, rolagem)


# --- captura / clima / jogavel (TASK AAA) ------------------------------------


## Overrides de captura: --hora=HH:MM, --vida=N, --lanterna-off, --local=NOME.
func _aplicar_overrides_hud() -> void:
	if _hud == null:
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hora="):
			_hud.definir_hora(arg.trim_prefix("--hora="))
		elif arg.begins_with("--vida="):
			_hud.definir_vida(int(arg.trim_prefix("--vida=")), 10)
		elif arg.begins_with("--local="):
			_hud.definir_local(arg.trim_prefix("--local=").replace("_", " "))
		elif arg == "--lanterna-off":
			_hud.definir_lanterna(false)


func _flag_estrada_qualquer() -> bool:
	var args := OS.get_cmdline_user_args()
	return (args.has("--ver-estrada")
		or args.has("--ver-estrada-cabine")
		or args.has("--ver-estrada-jogavel"))


func _quer_jogavel() -> bool:
	var args := OS.get_cmdline_user_args()
	# Flag preferida do contrato com Renatin / CaptureTool.
	if args.has("--ver-estrada-cabine") or args.has("--ver-estrada-jogavel"):
		return true
	for arg: String in args:
		if arg == "--estrada-modo=jogavel" or arg == "--estrada-modo=playable":
			return true
	return false


func _clima_id() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--estrada-clima="):
			return arg.trim_prefix("--estrada-clima=")
	# Padrao das refs de horror: noite com farois.
	if _flag_estrada_qualquer():
		return "noite"
	return CLIMA_PADRAO


func _caminho_clima() -> String:
	var id := _clima_id()
	if CLIMAS_ESTRADA.has(id):
		return String(CLIMAS_ESTRADA[id])
	return PRESET


## E noite neste clima? Vale para a seca e para a de chuva: o vulto na beira,
## os props no facho e o farol como unica luz sao coisas do escuro, nao da agua.
func _e_noite() -> bool:
	return _clima_id().begins_with("noite")


## Chove neste clima? E o que liga a agua toda: poca, leque, encharcado,
## relampago.
func _chove() -> bool:
	return _clima_id() in ["chuva", "noite_chuva"]


func _plano_captura() -> Plano:
	# `--estrada-corrida` roda a cena INTEIRA, os sete planos na ordem, e
	# devolve o controle no fim.
	#
	# Existe porque nao havia como assistir a esta cutscene sem passar pelo menu
	# e pela criacao de personagem: `--ver-estrada` congela um plano para
	# fotografar, que e o certo para conferir um enquadramento e inutil para
	# conferir o RITMO — quanto tempo cada plano dura, se a legenda cabe no
	# tempo dele, se a emenda no preto fecha. Uma cena de cinema se revisa
	# assistindo.
	if OS.get_cmdline_user_args().has("--estrada-corrida"):
		return Plano.NENHUM
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--estrada-plano="):
			continue
		match arg.trim_prefix("--estrada-plano="):
			"passagem":
				return Plano.PASSAGEM
			"aerea":
				return Plano.AEREA
			"mata", "bicho":
				return Plano.MATA
			"poca", "roda":
				return Plano.POCA
			"rasante":
				return Plano.RASANTE
			"dentro", "fp", "cabine":
				return Plano.DENTRO
			"saida":
				return Plano.SAIDA
			"chase", "tp":
				return Plano.CHASE
	# --ver-estrada sem plano: segura FP cabine (ref 01). Jogavel nao passa aqui.
	if OS.get_cmdline_user_args().has("--ver-estrada") and not _quer_jogavel():
		return Plano.DENTRO
	return Plano.NENHUM


## Segura um plano ate o CaptureTool matar o processo (--shot-quit).
func _segurar_captura(plano: Plano) -> void:
	# Carro PARADO na captura.
	#
	# Ele andava: `_process` chama `avancar` mesmo com o plano congelado, e a 68
	# km/h os cem quadros de fisica da captura sao trinta e um metros. Tudo que
	# `garantir_props_facho` promete colocar no cone do farol — a casa, a cerca,
	# o vulto — era colocado em relacao ao metro 120 e fotografado do metro 151,
	# ou seja, atras do carro. A captura mostrava um trecho generico e nao o que
	# a funcao garantiu, e duas capturas seguidas nunca eram o mesmo quadro.
	_carro.distancia = 120.0
	_carro.velocidade = 0.0
	_estrada.atualizar(_carro.distancia)
	_carro.assentar()
	if _e_noite():
		_ligar_farois_se_noite()
		_estrada.spawn_vulto_beira(_carro.distancia)
		_estrada.garantir_props_facho(_carro.distancia)
	_ancora = _carro.distancia + PASSAGEM_ADIANTE
	_montar_plano_congelado(plano)
	_comecar(plano, 9999.0)
	# HUD camera-agnostic: ligado em 1P e 3P. A cutscene de verdade apaga o
	# HUD no plano de dentro (briga com a legenda); a captura e o modo
	# jogavel precisam dele, que e o que as prints mostram.
	if plano == Plano.CHASE:
		_terceira = true
	if _hud != null and plano in [Plano.DENTRO, Plano.CHASE]:
		_hud.visible = true
		_hud.definir_local("ESTRADA VELHA")
		_hud.definir_hora("22:43")
		_hud.definir_vida(4, 10)
		_hud.definir_lanterna(true)
		_aplicar_overrides_hud()
	# `--estrada-celular`: fotografa a cabine com o telefone erguido e a
	# conversa aberta, sem esperar a cena inteira.
	if plano == Plano.DENTRO and OS.get_cmdline_user_args().has("--estrada-celular"):
		if _hud != null:
			_hud.visible = false
		_olhar_celular = 1.0
		if _motorista != null:
			_motorista.mostrar_celular(true)
		Celular.abrir_conversa_em_cena(FALAS["grupo"], CONVERSA_DO_GRUPO,
			FALAS["grupo_hora"], FALAS["desculpa"])
	await Cinema.clarear(0.35)
	await get_tree().create_timer(120.0).timeout


## Os planos que precisam de MONTAGEM, montados tambem na captura.
##
## `_segurar_captura` congela um plano sem passar pela funcao que o produz, e
## isso basta enquanto o plano e so um enquadramento — passagem, aerea,
## rasante e saida sao camera e mais nada. Os dois planos novos nao sao: o da
## mata precisa que a toca de folha exista e que o olho do bicho tenha
## posicao, e o da poca precisa saber QUAL poca. Sem esta funcao os dois caiam
## em `Vector3.ZERO`, a camera ia parar na origem da estrada olhando para a
## propria origem, e `_enquadrar` desistia do `look_at` pela guarda de
## distancia zero: a captura saia com o enquadramento do plano anterior e sem
## nenhum erro no log.
func _montar_plano_congelado(plano: Plano) -> void:
	match plano:
		Plano.MATA:
			# Mais perto que na cena (74 m): ali o carro esta CHEGANDO e a foto
			# pegaria um ponto na nevoa. Trinta metros e onde ele ja tem tamanho.
			_ancora = _carro.distancia + 30.0
			_bicho_olho = EstradaBuilder.ponto_em(_ancora)
			_bicho_olho += EstradaBuilder.lado_em(_ancora) * MATA_LADO
			_bicho_olho.y += (EstradaBuilder.altura_lateral(MATA_LADO)
				+ MATA_ALTURA)
			_bicho_lado = EstradaBuilder.direcao_em(_ancora)
			_bicho_mira = _carro.position + Vector3.UP * 0.8
			_bicho_frente = _repouso_do_bicho()
			if _estrada != null:
				_estrada.spawn_toca(_ancora, 1.0, MATA_LADO, MATA_ALTURA)
		Plano.POCA:
			_poca = _proxima_poca(_carro.distancia + 2.0)
			_ancora = _poca.x
			# O carro POR CIMA da agua, que e o que o plano existe para mostrar.
			# Com ele na marca de sempre, a poca escolhida ficaria dez metros a
			# frente e a foto sairia com a estrada vazia. Meio metro antes do
			# centro da poca: a roda dianteira ja entrou na agua e o carro ainda
			# esta vindo na direcao da lente, que e o instante do plano.
			_carro.distancia = _poca.x - 0.5
			_estrada.atualizar(_carro.distancia)
			_carro.assentar()
			_pocas.distancia = _carro.distancia
			if _spray != null:
				_spray.velocidade_forcada = CRUZEIRO
		_:
			pass

func _ligar_farois_se_noite() -> void:
	# Na chuva tambem, e pelo motivo mais banal do mundo: chovendo, se acende o
	# farol. De quebra e o que poe um cone de luz dentro da agua caindo, que e a
	# unica coisa nesta cena que mostra a chuva de LADO em vez de de frente.
	if _clima_id() not in ["noite", "noite_chuva", "amanhecer", "chuva"]:
		return
	if _carro == null:
		return
	_carro.acender_farois(true)
	var id := _clima_id()
	if FAROL_POR_CLIMA.has(id):
		var f: Vector2 = FAROL_POR_CLIMA[id]
		_carro.ajustar_farol(f.x, f.y)


## Cabine jogavel: default 1P, V alterna chase 3P. HUD sempre visivel.
func _correr_jogavel() -> void:
	_jogavel = true
	_terceira = false
	_carro.jogavel = true
	_carro.distancia = 80.0
	_carro.velocidade = 42.0
	_estrada.atualizar(_carro.distancia)
	_carro.assentar()
	_carro.mostrar_cabine(true)
	_comecar(Plano.DENTRO, 9999.0)
	if _hud != null:
		_hud.visible = true
		_hud.definir_local("ESTRADA VELHA")
		_hud.definir_hora("22:43")
		_hud.definir_vida(4, 10)
		_hud.definir_lanterna(true)
		_aplicar_overrides_hud()
	await Cinema.clarear(0.4)
	await get_tree().create_timer(180.0).timeout


func _unhandled_input(event: InputEvent) -> void:
	if not _jogavel:
		return
	if event.is_action_pressed("alternar_camera"):
		_alternar_camera_jogavel()
		get_viewport().set_input_as_handled()


func _alternar_camera_jogavel() -> void:
	_terceira = not _terceira
	if _terceira:
		_plano = Plano.CHASE
		if _carro != null:
			_carro.mostrar_cabine(false)
	else:
		_plano = Plano.DENTRO
		if _carro != null:
			_carro.mostrar_cabine(true)
	if _hud != null:
		_hud.visible = true
	_mover_camera(0.0)

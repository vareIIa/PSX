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
	# Planta a hesitacao que o susto vai cobrar: os outros foram, ele ficou.
	"passagem": "O pessoal saiu cedo. Eu fiquei enrolando.",
	# "Uma vez na vida" ganha o outro sentido depois do branco.
	"aerea_1": "São Thomé. Todo mundo diz: tem que ir uma vez na vida.",
	"aerea_2": "Duas horas de terra depois que acaba o asfalto.",
	# A fala do plano do bicho. E a mesma que abria o plano de dentro, e ela
	# ganha com a mudanca: dita por cima de alguem que esta OLHANDO o carro, o
	# "nao parece ter fim" deixa de ser tedio de viagem e vira outra coisa. Ele
	# nao sabe o que disse.
	"mata": "Sem maldade, essa estrada não parece ter fim.",
	"rasante": "Eu que não queria vir.",
	"dentro_1": "Faz uma semana que eu acordo pensando em desmarcar.",
	# O que esta na tela do celular no plano de dentro. Ver `_plano_dentro`.
	# O grupo, a ultima pergunta sem resposta, e a desculpa no campo — escrita
	# na primeira pessoa de quem nao quer ir e nao tem coragem de dizer.
	"grupo": "Bonde São Thomé",
	"grupo_hora": "Hoje 22:38",
	"desculpa": "Gente, não vou conseguir ir. Deu um problema aqui em casa, desculpa",
	# No presente: ele esta se justificando AGORA, dentro do carro.
	"poca": "A pousada tá paga. Eles já tão lá.",
	# Depois de pegar o aparelho do chao: uma conversa que ele nao abriu, de um
	# contato sem nome. A primeira coisa que chega e a desculpa que ele APAGOU,
	# palavra por palavra — alguem viu o que nunca foi mandado. Depois ele e
	# desmentido, recebido ("uma vez na vida", a fala do plano aereo, ganhando o
	# outro sentido), e fica sabendo dos amigos que ja estavam la. A porta vem
	# por ultimo, e o trinco puxa logo depois de ele ler.
	"desconhecido": "?",
	"desconhecido_hora": "Agora",
	"recado": [
		"Gente, não vou conseguir ir.",
		"Mentira.",
		"Você veio.",
		"Todo mundo vem uma vez na vida.",
		"O Lucas e a Mari já estão aqui.",
		"Abre a porta.",
	],
	# Chega depois dos dois puxoes no trinco, que nao abriu: e ela que vira a
	# cabeca dele para a janela.
	"olha": "Olha pra mim.",
}

## A conversa do grupo, de cima para baixo. A ultima e a pergunta que a desculpa
## responderia. Ver `AppMensagens`.
##
## Os dois primeiros sao de dias atras; os tres de baixo sao de hoje a noite,
## com eles ja la. Apagar a desculpa, aqui, quer dizer "decidi ir" — e e nessa
## hora que o padre aparece.
const CONVERSA_DO_GRUPO := [
	["MARI", "Sexta cedo, hein. Sem atraso"],
	["eu", "Fechou"],
	["LUCAS", "Chegamos!! Frio do cão"],
	["MARI", "Cadê vc??"],
	["LUCAS", "Vc vem mesmo né?"],
]

# --- o susto (PLANO_INTRODUCAO_AAA_PICA, Parte A) ----------------------------
## Onde o polegar para: em nada. Ele apaga a desculpa INTEIRA e nao manda
## coisa nenhuma — apagar e a decisao de ir. Nenhum balao sobe na conversa.
const TRAVA_LETRAS := 0
## Com o campo vazio e o cursor piscando, o respiro antes de o olho subir (s),
## e onde a lente mira na tela enquanto isso: o campo vazio e a pergunta do
## Lucas logo acima dele, sem resposta.
const VAZIO_RESPIRA := 0.7
const VAZIO_MIRA := Vector2(0.5, 0.68)
## Quanto a frente do carro o padre e plantado quando o campo esvazia, e a que
## distancia dele vem o golpe. A 68 km/h os 21 m entre os dois sao 1,1 s: o
## tempo de o olho subir e de ver ele crescer no farol ANTES de o personagem
## ver — o publico sabe primeiro.
const PADRE_ADIANTE := 34.0
const PADRE_T0 := 13.0
## Onde ele esta na pista: um pouco a esquerda do eixo, no meio da estrada, e
## do lado de fora da trajetoria da guinada (que vai para a direita).
const PADRE_DESVIO := -0.7
## A guinada: quanto tempo do golpe ate a arvore, onde o centro do carro esta
## na hora da batida (metros do eixo, para a direita), com que velocidade ele
## chega, e o expoente da curva do desvio — acima de um, o carro demora a sair
## da trilha e depois vai de uma vez.
const GUINADA_T := 2.13
const GUINADA_LADO := 5.6
const GUINADA_CURVA := 1.35
const VEL_NA_BATIDA := 40.0
## O salto da lente no golpe: de 66 a 28 graus em 0,12 s, e volta a 32. E o
## "foca nele" do pedido — a lente fecha no rosto que ja esta no farol.
const SOCO_FOV := 26.0
## A lente fechando na pausa, antes do golpe.
const PAUSA_FOV := 44.0
const SOCO_FOV_VOLTA := 32.0
const SOCO_TEMPO := 0.12
## O celular na mao: quanto a cabeca vai para ele (1 seria o aparelho no meio
## do quadro; menos deixa a estrada aparecendo por cima), e a lente da leitura.
const OLHAR_LEITURA := 0.9
const LEITURA_FOV := 30.0
## Na pausa a cabeca sobe um tanto: o aparelho desce para o terco de baixo e a
## estrada ocupa o resto.
const OLHAR_PAUSA := 0.34
## O aparelho no tapete: a lente fecha no telefone inteiro — o alto-falante em
## cima, o botao embaixo, a conversa no meio — com a mao chegando pela borda.
const ASSOALHO_FOV := 17.0
## O banco do carona com as duas maos chegando.
const ALCANCE_FOV := 58.0
## Onde a lente mira na tela caida: o pe da conversa — a pergunta do Lucas
## sem resposta e o campo vazio embaixo dela. Nenhum balao dele.
const ASSOALHO_MIRA := Vector2(0.5, 0.55)
## Quanto a mira puxa para a mao que chega (0 o telefone, 1 a mao).
const ASSOALHO_PUXA_MAO := 0.22
## A leitura: a lente entra no campo de texto enquanto ele apaga — com o
## teclado e o polegar no quadro. Mirando so o campo (0,58 a 19 graus) a ultima
## fileira do teclado ficava fora, e o polegar apagava fora de quadro.
const APAGAR_FOV := 23.0
const APAGAR_MIRA := Vector2(0.60, 0.76)
## Os toques no apagar antes de segurar: uma letra cada, com o intervalo depois
## de cada um (s). Hesita, e entao segura.
const APAGAR_TOQUES := [0.42, 0.36, 0.52]
const ASSOALHO_ZOOM := 2.5
## A pegada no chao e a subida do aparelho ate o rosto (s).
const PEGAR_TEMPO := 0.42
const PEGAR_FOV := 36.0
const ERGUER_TEMPO := 1.15
## O tempo de cada mensagem do "?" (`FALAS["recado"]`), em segundos: quanto o
## "digitando" fica antes dela (zero: chega sem aviso, colada na anterior) e
## quanto ela fica sozinha no pe da conversa, para ser lida. A desculpa dele
## devolvida pede o tempo mais longo: e o reconhecimento.
## Rapido: o recado inteiro em uns cinco segundos, apertando — com o dobro
## disso ele virava leitura, e o cerco la fora nao tinha pressa.
const RECADO_TEMPOS := [[0.0, 0.8], [0.45, 0.45], [0.3, 0.4], [0.0, 0.55],
	[0.4, 0.6], [0.25, 0.3]]
## "Olha pra mim.": quanto ele le antes de o aparelho morrer.
const OLHA_LE := 0.45
## O campo na leitura das mensagens, e quanto ele fecha a cada uma (graus).
const MENSAGENS_FOV := 34.0
const MENSAGENS_APERTA := 1.7
## Para onde a lente olha na tela durante as mensagens: os baloes do "?"
## sobem pela esquerda, de baixo.
const MENSAGENS_MIRA := Vector2(0.42, 0.62)
## A cabeca virando do aparelho para a janela (s).
const VIRA_TEMPO := 0.38
## O raio do mato amassado em volta do carro batido. O carro tem 4,4 m: 2,7
## cobre a cabine e um palmo de chao em volta, que e o que o carro derrubou.
const CLAREIRA_RAIO := 2.7
## Quanto tempo a cabeca fica presa no padre enquanto o carro gira por baixo.
const CABECA_PRESA := 0.55
## O segundo das figuras. Um, e nao mais: e um relance que ninguem tem certeza
## de ter visto.
const ROMEIROS_DURACAO := 1.0
const ROMEIROS_FOV := 44.0
## Quanto ele se debruca para ver o assoalho do carona, no espaco do carro.
const DEBRUCA := Vector3(0.42, -0.26, -0.36)
## No golpe ele se endireita no banco. Tres centimetros e nada para a frente:
## com treze e doze a lente entrava na testeira do teto (ver
## `DENTRO_OLHO_RECUA`). O aro nao sai do quadro subindo o olho; sai subindo a
## MIRA — o padre fica de cabeca e ombros por cima do volante.
const ERGUE := Vector3(0.0, 0.03, 0.0)
## Onde o padre fica na janela do motorista, no espaco do carro: do lado de fora
## da porta esquerda, curvado, o rosto na altura do vidro.
const PADRE_NA_JANELA := Vector3(-1.36, 0.0, -0.02)
## Luz vermelha das lampadas de bateria e oleo, que acendem com o motor morto.
## E ela que pega o rosto dele no vidro, por baixo.
const LUZ_ALERTA := Color(1.0, 0.16, 0.08)
## A forca dela acesa. Mais que isto e o braco inteiro vira vermelho: e uma
## lampada de painel, e nao um farol.
const LUZ_ALERTA_FORCA := 0.28
## Quanto ele se curva para a janela, e o pitch da cabeca (negativo e para
## cima) que traz o rosto de volta para dentro do carro.
const PADRE_JANELA_CURVA := 0.10
const PADRE_JANELA_PITCH := -0.9

enum Plano { NENHUM, PASSAGEM, AEREA, MATA, RASANTE, DENTRO, POCA, SAIDA, CHASE, ROMEIROS }

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

# --- estado do susto --------------------------------------------------------
var _padre: Corpo
var _romeiros: Array[Corpo] = []
var _branco: BrancoDoSusto
## Tempo desde o golpe na estrada; negativo enquanto nao houve golpe.
var _susto_t: float = -1.0
var _v_t0: float = 0.0
var _bateu: bool = false
## A mensagem foi mandada (o polegar encostou no ENVIAR).
## Para onde a cabeca e puxada por cima de tudo (o padre, o celular no chao, a
## janela), e quanto. `_foco_de` devolve o ponto no mundo, a cada quadro.
var _foco_de: Callable
var _foco_peso: float = 0.0
## 0 sentado, 1 debrucado sobre o assoalho do carona.
var _debruca: float = 0.0
## 0 olhando o aparelho, 1 olhando a janela: a cabeca virando.
var _vira: float = 0.0
## 0 sentado, 1 erguido no banco (o golpe).
var _ergue: float = 0.0
## Campo de visao imposto pela cena; zero e o do plano de dentro.
var _fov_cena: float = 0.0
## Tremor da camera, de 0 a 1, que decai sozinho.
var _tremor: float = 0.0
## Ofegante, de 0 a 1: o peito subindo e descendo rapido debaixo da lente.
var _ofego: float = 0.0
## O puxao do fim: 0 ele no banco, 1 a cabeca arrancada meio metro para a
## janela. So o comeco dele chega a tela — o branco corta no primeiro terco.
var _puxao: float = 0.0
var _romeiros_olho := Vector3.ZERO
var _romeiros_mira := Vector3.ZERO
var _luz_alerta: OmniLight3D
var _luz_janela: OmniLight3D
var _tocadores: Array[AudioStreamPlayer] = []
## Pasta de fotos da bancada (`--susto-fotos=`): cada beat do susto grava um
## quadro. Vazio fora da bancada.
var _pasta_fotos: String = ""
## Rajada da bancada (`--susto-rajada=<pasta>`): um quadro a cada
## `RAJADA_PASSO` segundos do plano de dentro, com o relogio da cena no nome —
## e dela que saem os mosaicos da queda, da pegada e da digitacao.
var _pasta_rajada: String = ""
var _rajada_t: float = 0.0
const RAJADA_PASSO := 0.1
const RAJADA_TAMANHO := Vector2i(640, 360)
## Com `--susto-cheio`, um quadro de cada `RAJADA_CHEIA` sai tambem no tamanho da
## janela, em `<rajada>/cheio`: e em 4K que a mao se julga, e a rajada reduzida
## esconde dedo, prega e costura.
const RAJADA_CHEIA := 10
var _rajada_cheia: bool = false
var _rajada_n: int = 0

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
	# A ordem nova (PLANO_INTRODUCAO_AAA_PICA): a poca sobe para antes do
	# rasante e a saida sai — a estrada nao termina com ele indo embora, termina
	# dentro do carro, no branco. `--estrada-desde=dentro` pula direto para o
	# susto, que e o que a bancada mede.
	if not OS.get_cmdline_user_args().has("--estrada-desde=dentro"):
		await _plano_passagem()
		await _plano_aerea()
		await _plano_mata()
		await _plano_poca()
		await _plano_rasante()
	await _plano_dentro()
	# Bancada: acabou o susto, acabou a medida. Sem isto a janela ficava no
	# branco do susto por minutos, carregando a cidade por tras dele.
	if not _pasta_fotos.is_empty() or not _pasta_rajada.is_empty():
		get_tree().quit(0)
		return

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
	_estrada.preparar_clareira()
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

	# O elenco do susto nasce aqui, escondido, debaixo do preto do comeco: sao
	# oito corpos e uns vinte milissegundos de montagem, que no meio do golpe
	# seriam um engasgo em cima do quadro mais importante da cena.
	_montar_elenco()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--susto-fotos="):
			_pasta_fotos = a.trim_prefix("--susto-fotos=")
		if a.begins_with("--susto-rajada="):
			_pasta_rajada = a.trim_prefix("--susto-rajada=")
			DirAccess.make_dir_recursive_absolute(_pasta_rajada)
		if a == "--susto-cheio":
			_rajada_cheia = true

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
		Celular.fechar_em_silencio()
	# A lataria entre a chuva e o ouvido fica na estrada: a cidade nao esta
	# dentro de carro nenhum.
	if _chuva != null and is_instance_valid(_chuva):
		_chuva.abrigo = 0.0
	# O mundo volta a soar debaixo do branco: a praca monta com o som dela.
	if _branco != null and is_instance_valid(_branco):
		_branco.devolver_mundo()
	if _cam != null and is_instance_valid(_cam):
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	if _cam != null and is_instance_valid(_cam):
		_cam.far = _far_anterior
		_cam.remove_meta(&"dentro_do_carro")
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
	Cinema.legenda(FALAS["aerea_1"], 4.96)
	await _esperar(5.6)
	Cinema.legenda(FALAS["aerea_2"], 4.0)
	await _esperar(AEREA_DURACAO - 6.2)
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


## O plano de dentro do carro, e o susto (PLANO_INTRODUCAO_AAA_PICA, Parte A).
##
## Sem HUD. O HUD e da parte JOGAVEL — sobe em `_modo_jogavel` e na troca de
## camera, e so.
##
## A espinha
## ---------
## Ele ergue o celular: o grupo da viagem, os amigos ja na pousada, "vc vem
## mesmo ne?" sem resposta, e a desculpa pronta no campo. Ele apaga — e apagar
## e decidir ir. O polegar para em "Gente, nao vou", e nessa pausa o padre ja
## esta no farol, parado no meio da pista. O publico ve antes dele.
##
## Tres golpes em sete segundos, cada um com um vacuo antes:
##
##   1  o padre na estrada   a lente salta nele; o carro vai para a mata
##      (um segundo de figuras entre as arvores, que ninguem tem certeza de ter visto)
##   2  a arvore             o para-brisa trinca, o motor morre, a luz vermelha acende
##      (a mata vazia; o celular vibra no banco; ele vai atras dele no chao)
##   3  a janela             o trinco da porta, o padre curvado no vidro, e o branco
##
## Ele apaga a desculpa inteira e nao manda nada: decidiu ir. E na hora em que
## o olho sai do campo vazio que o padre esta no farol.
func _plano_dentro() -> void:
	_branco = BrancoDoSusto.new()
	_cena.add_child(_branco)
	_montar_fumaca()
	# O farol de verdade: sombra do padre no barro, facho aceso na chuva.
	_carro.farol_de_verdade(true)
	# A lataria e lida agora, e nao na batida: ler malha trava o quadro.
	_carro.preparar_batida()
	_preaquecer_a_batida()
	_comecar(Plano.DENTRO, 60.0)
	# Um celular so: o da mao dele. A conversa e desenhada na tela do aparelho
	# 3D (`TelaDoCelular`), e a lente fecha nele o bastante para ler — com a
	# estrada ainda aparecendo por cima. O app nasce aqui, debaixo do preto: a
	# tela e as letras dele compilam no aquecimento, e nao na hora de erguer o
	# aparelho (era o engasgo de 80 ms aos 5,6 s).
	var app := AppMensagens.new()
	app.preparar(FALAS["grupo"], CONVERSA_DO_GRUPO, FALAS["grupo_hora"], FALAS["desculpa"])
	if _motorista != null:
		_motorista.ligar_tela(app)
	await _aquecer_na_lente()
	await Cinema.clarear(0.7)
	Cinema.legenda(FALAS["dentro_1"], 4.2)
	await _esperar(4.6)
	# O olhar vai um pouco antes da mao: a decisao de olhar e o que faz a mao
	# subir, e nao o contrario.
	_olhar_celular_para(OLHAR_LEITURA, OLHAR_CELULAR_DESCE)
	_fov_cena = DENTRO_FOV
	_animar(&"_fov_cena", LEITURA_FOV, 0.7, Tween.TRANS_SINE)
	await _esperar(0.2)
	if _motorista != null:
		_motorista.mostrar_celular(true)
	await _esperar(0.45)
	_marca("conversa")
	# Tempo de ler: os amigos ja la, a pergunta, a desculpa, o cursor piscando.
	await _esperar(0.7)
	_foto("01_conversa")
	await _esperar(OLHAR_CELULAR_FICA - 0.7)

	# O polegar. Apaga a desculpa inteira, ate o campo ficar vazio. A lente vai
	# entrando no campo de texto junto com o apagar: no fim so cabem a pergunta
	# do Lucas e o campo vazio, com o cursor piscando.
	#
	# E o polegar que apaga: cada vez que ele encosta no apagar some uma letra
	# (`AppMensagens.apertar_apagar`), e segurando o apagar repete e dispara. Tres
	# toques, uma hesitacao, e ele segura.
	app.travar_em(TRAVA_LETRAS)
	if _motorista != null:
		# O polegar so apaga: cada toque diz onde encostou.
		_motorista.tecla_encostou.connect(func(uv: Vector2) -> void:
			if uv == MotoristaCena.APAGAR_UV:
				app.apertar_apagar())
		_motorista.tecla_soltou.connect(func(uv: Vector2) -> void:
			if uv == MotoristaCena.APAGAR_UV:
				app.soltar_apagar())
		_foco_de = func() -> Vector3: return _motorista.ponto_da_tela(APAGAR_MIRA)
		_animar(&"_foco_peso", 0.85, 0.9)
	_animar(&"_fov_cena", APAGAR_FOV, 1.5, Tween.TRANS_SINE)
	if _motorista != null:
		for i in APAGAR_TOQUES.size():
			_motorista.teclar(MotoristaCena.APAGAR_UV)
			await _esperar(APAGAR_TOQUES[i])
			if i == 1:
				_foto("01b_toque")
		_motorista.segurar_tecla(MotoristaCena.APAGAR_UV)
	else:
		app.apagar_ate(TRAVA_LETRAS)
	var espera := 0.0
	while not app.rascunho_vazio() and espera < 6.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	if _motorista != null:
		_motorista.soltar_tecla()
	_marca("trava")
	# O campo vazio, o cursor piscando. O polegar sai de cima do teclado e
	# desce para o canto: pairando no repouso de sempre ele tampava o campo.
	# A lente vai junto para o campo vazio.
	if _motorista != null:
		_motorista.repousar_em(MotoristaCena.REPOUSO_DEPOIS_UV)
		_foco_de = func() -> Vector3: return _motorista.ponto_da_tela(VAZIO_MIRA)
	_foto("02_vazio")
	await _esperar(VAZIO_RESPIRA)
	_foto("02b_respiro")
	# Nada foi mandado. E o padre ja esta na estrada, adiante no facho.
	var s_padre := _carro.distancia + PADRE_ADIANTE
	_plantar_padre(s_padre)
	# O olho sobe do aparelho, e o aparelho fica: embaixo do quadro, o campo
	# vazio; em cima, pelo para-brisa, a estrada — e o padre saindo da nevoa
	# no facho. O publico ve antes dele.
	_olhar_celular_para(OLHAR_PAUSA, 0.7)
	_animar(&"_foco_peso", 0.0, 0.7)
	_animar(&"_fov_cena", PAUSA_FOV, 1.0, Tween.TRANS_SINE)
	var vacuo := false
	espera = 0.0
	while _carro.distancia < s_padre - PADRE_T0 and espera < 4.0:
		# O vacuo: a chuva vai sumindo nos ultimos metros. O ouvido percebe o
		# silencio antes do olho perceber o padre.
		if not vacuo and _carro.distancia >= s_padre - PADRE_T0 - 11.0:
			_vacuo(true)
			# No lugar da chuva, gente sussurrando longe.
			_som(&"sussurros", -15.0)
			vacuo = true
		if absf(_carro.distancia - (s_padre - PADRE_T0 - 4.0)) < 0.2:
			_foto("03_padre_no_farol")
		await get_tree().process_frame
		espera += get_process_delta_time()

	await _golpe_na_estrada()

	# --- GOLPE 2: a arvore. `_guiar_a_guinada` bate sozinho, no tempo dela.
	espera = 0.0
	while not _bateu and espera < 3.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	# O tranco joga a cabeca para a frente, e o olho vai atras do telefone que
	# sai do banco do carona: porta-luvas, vao dos pes, tapete. A lente so
	# acompanha a metade do caminho — e o canto do olho de quem acabou de bater.
	if _motorista != null:
		_foco_de = func() -> Vector3: return _motorista.ponto_do_celular()
		_foco_peso = 0.0
		_animar(&"_foco_peso", 0.4, 0.3, Tween.TRANS_SINE)
	await _esperar(0.22)
	_foto("07_batida")
	await _esperar(0.55)
	_foto("07b_caiu")
	# Parou. O olho volta para o para-brisa: a mata vazia no farol.
	_animar(&"_foco_peso", 0.0, 0.5, Tween.TRANS_SINE)
	await _esperar(0.2)

	# --- a calma falsa: a mata VAZIA no farol fraco, o limpador marcando o
	# tempo, e a respiracao dele.
	var folego := _som(&"ofegante", -8.0)
	await _esperar(0.5)
	_foto("08_calma")
	await _esperar(0.5)

	# --- o chao: o telefone vibra la embaixo, no vao do carona, e a tela
	# acende. A cabeca vai, a mao vai. O do farol some enquanto ninguem olha.
	for v: Corpo in _vigias:
		_esconder(v)
	# Fora da mao o teclado recolhe: no chao a tela e a conversa, com a
	# pergunta do Lucas ainda sem resposta.
	app.sem_teclado = true
	if _motorista != null:
		_motorista.vibrar_celular(0.9)
	_som(&"vibra_banco", -9.0, 0.9)
	# A mao larga o aro e desce ao colo ANTES de a cabeca virar: com a lente ja
	# apontada para o chao, o braco descendo do volante passava inteiro na frente
	# dela (medido na rajada 4K, aos 20,6 s). Ele se joga para o lado do carona
	# contra o cinto: a direita desce atras do telefone, a esquerda espalma no
	# assento do carona.
	if _motorista != null:
		_motorista.medo = 1.0
		_motorista.alcancar_no_chao(1.05)
	await _esperar(0.3)
	_foco_de = func() -> Vector3: return _motorista.ponto_do_celular()
	_animar(&"_foco_peso", 1.0, 0.35)
	_fov_cena = DENTRO_FOV
	_animar(&"_fov_cena", ALCANCE_FOV, 0.5, Tween.TRANS_SINE)
	await _esperar(0.3)
	_foto("08b_no_chao")
	_animar(&"_debruca", 0.45, 0.5)
	# A treva entra: pela fresta de baixo da porta do carona, rente ao tapete,
	# e depois sobe.
	if _fumaca != null:
		var t_f := create_tween()
		t_f.tween_property(_fumaca, "cobre", FUMACA_DEBRUCA, 1.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		t_f.tween_property(_fumaca, "cobre", FUMACA_NO_CHAO, 2.2) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_animar_fumaca(&"teto", _teto_da_fumaca(FUMACA_TETO_ALTO), 3.2)
	# Ele se debruca atras do telefone, contra o cinto: a cabeca desce com o
	# braco, o direito estica ate onde o cinto deixa, a mao abrindo, e nao
	# chega. Puxa, e puxa de novo, ofegando. A lente vai com a cabeca e fecha no
	# telefone: o braco entra pela borda de baixo, e nao enche o quadro.
	if _motorista != null:
		_foco_de = func() -> Vector3: return _motorista.ponto_da_tela(Vector2(0.5, 0.5))
	_animar(&"_foco_peso", 1.0, 0.45)
	_animar(&"_debruca", 1.0, 0.7)
	_animar(&"_fov_cena", CHAO_FOV, 0.7, Tween.TRANS_SINE)
	_animar(&"_ofego", 1.0, 0.5)
	var arfando := _som(&"ofegante_esforco", -3.0)
	# No chao a tela aproxima o pe da conversa: o "Vc vem mesmo ne?" sem
	# resposta tem de ser lido a meio metro.
	if _motorista != null and _motorista.tela() != null:
		_motorista.tela().zoom = ASSOALHO_ZOOM
	# A mao de apoio bate no assento.
	await _esperar(0.55)
	_som(&"apoio_banco", -6.0)
	if _motorista != null:
		var t_forca := create_tween()
		t_forca.tween_property(_motorista, "esforco", 1.0, 0.8)
		t_forca.parallel().tween_property(_motorista, "apoio_forca", 0.45, 0.8)
	await _esperar(0.75)
	_foto("09a_debruca")
	# A lente fecha devagar no telefone, com a mao entrando pela borda.
	if _motorista != null:
		_foco_de = func() -> Vector3:
			return _motorista.ponto_da_tela(ASSOALHO_MIRA).lerp(
				_motorista.ponto_da_mao_direita(), ASSOALHO_PUXA_MAO)
	_animar(&"_fov_cena", ASSOALHO_FOV, 1.4, Tween.TRANS_SINE)
	await _esperar(1.0)
	_foto("09_assoalho")

	# --- o empurrao: o braco de apoio afunda no assento, o corpo desce os
	# ultimos centimetros e a mao fecha no aparelho, pela borda de cima. A
	# lente abre: fechada em 17 graus, o braco que sobe para a pinca passava na
	# frente dela e o quadro virava manga.
	if _motorista != null:
		_foco_de = func() -> Vector3:
			return _motorista.ponto_do_celular().lerp(_motorista.ponto_da_mao_direita(), 0.25)
	_animar(&"_fov_cena", PEGAR_FOV, PEGAR_TEMPO * 0.8, Tween.TRANS_SINE)
	if _motorista != null:
		var t_emp := create_tween()
		t_emp.tween_property(_motorista, "apoio_forca", 1.0, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t_emp.parallel().tween_property(_motorista, "esforco", 0.0, 0.4)
		_tremor = 0.25
		_animar(&"_tremor", 0.0, 0.5)
		await _motorista.pegar_do_chao(PEGAR_TEMPO)
	_foto("09b_pegou")
	# --- sobe: o corpo volta ao banco e o aparelho vem na mao ate o rosto,
	# girando nela ate a pegada de leitura. O folego ainda solto.
	if _motorista != null:
		_foco_de = func() -> Vector3: return _motorista.ponto_da_tela(Vector2(0.5, 0.55))
		var t_solta := create_tween()
		t_solta.tween_property(_motorista, "apoio_forca", 0.0, 0.3)
	_animar(&"_debruca", 0.0, ERGUER_TEMPO, Tween.TRANS_SINE)
	_animar(&"_fov_cena", MENSAGENS_FOV, ERGUER_TEMPO, Tween.TRANS_SINE)
	_animar(&"_ofego", 0.45, ERGUER_TEMPO)
	if _motorista != null:
		await _motorista.erguer_celular(ERGUER_TEMPO)
		if _motorista.tela() != null:
			_motorista.tela().zoom = 1.0
		print("[susto] erguer: o braco passou a %.1f cm da lente" % [
			_motorista.lente_ao_braco_min * 100.0])
	_foto("09c_na_mao")
	await _fogo_pega_e_ele_olha()
	if arfando != null and is_instance_valid(arfando):
		var t_ar := create_tween()
		t_ar.tween_property(arfando, "volume_db", -14.0, 1.2)

	# --- "?": a conversa troca sozinha. Um contato sem nome, e a primeira coisa
	# que chega e a desculpa que ele apagou. Cada uma com o aparelho vibrando na
	# mao; entre elas, o "digitando".
	var us := Time.get_ticks_usec()
	var app_q := AppMensagens.new()
	app_q.preparar(FALAS["desconhecido"], [], FALAS["desconhecido_hora"], "")
	app_q.sem_teclado = true
	app_q.tique = false
	if _motorista != null:
		_motorista.ligar_tela(app_q)
	us = _custo_da_batida("app do ?", us)
	# O padre vai para a janela agora, atras da cabeca dele.
	_padre_na_janela()
	_custo_da_batida("padre na janela", us)
	# E os outros sobem no carro.
	_cerco(&"comecar")
	await _esperar(0.35)
	var recado: Array = FALAS["recado"]
	for i in recado.size():
		var tempos: Array = RECADO_TEMPOS[i]
		if float(tempos[0]) > 0.0:
			app_q.escrevendo = FALAS["desconhecido"]
			await _esperar(float(tempos[0]) * 0.6)
			if i == 1:
				_foto("09d_digitando")
			await _esperar(float(tempos[0]) * 0.4)
		_receber_do_padre(app_q, String(recado[i]), i)
		if i == 0 and _motorista != null:
			_foco_de = func() -> Vector3: return _motorista.ponto_da_tela(MENSAGENS_MIRA)
		await _esperar(float(tempos[1]) * 0.5)
		if i == 0:
			_foto("09d_recado")
		elif i == 4:
			_foto("09e_amigos")
		await _esperar(float(tempos[1]) * 0.5)

	# --- o trinco: "Abre a porta." acabou de chegar, e a porta e puxada. O som
	# vem antes da imagem, duas vezes, e nao abre.
	_som(&"porta_trinco", -1.0)
	await _esperar(0.22)
	_som(&"porta_trinco", -3.0, 0.93)
	await _esperar(0.3)
	# Nao abriu. A ultima.
	_receber_do_padre(app_q, FALAS["olha"], recado.size())
	await _esperar(OLHA_LE * 0.6)
	_foto("09g_olha")
	await _esperar(OLHA_LE * 0.4)
	# O aparelho morre na mao: um ultimo rasgo, e a tela apaga. No mesmo quadro
	# as maos la fora param todas, de uma vez. O silencio e a deixa: ele vira.
	if _motorista != null:
		_motorista.pane_no_celular(1.0)
	_som(&"celular_pane", -3.0, 0.8)
	await _esperar(CELULAR_MORRE)
	if _motorista != null:
		_motorista.apagar_celular()
	_calar_as_batidas()
	await _esperar(SILENCIO_ANTES_DE_VIRAR)
	_foto("09h_silencio")
	# O limpador para no meio do vidro, sozinho.
	if _carro.cabine != null and _carro.cabine.limpadores() != null:
		_carro.cabine.limpadores().travado = true
	# O folego dele trava.
	if folego != null and is_instance_valid(folego):
		folego.stop()
	if arfando != null and is_instance_valid(arfando):
		arfando.stop()
	_ofego = 0.0
	# Ele olha para o lado: a cabeca sai do aparelho e vira para a janela,
	# depressa, e o aparelho desce no colo.
	if _motorista != null:
		_vira = 0.0
		_foco_de = func() -> Vector3:
			return _motorista.ponto_da_tela(MENSAGENS_MIRA).lerp(_rosto_do_padre(),
				smoothstep(0.0, 1.0, _vira))
		_animar(&"_vira", 1.0, VIRA_TEMPO, Tween.TRANS_CUBIC)
		_motorista.mostrar_celular(false)
	else:
		_foco_de = _rosto_do_padre
	# A fumaca assenta abaixo do vidro: a janela e o que ele tem de ver.
	if _fumaca != null:
		_fumaca.teto = _teto_da_fumaca(FUMACA_TETO_JANELA)
	_animar(&"_fov_cena", 56.0, VIRA_TEMPO, Tween.TRANS_CUBIC)
	if _luz_janela != null:
		_luz_janela.light_energy = 1.3
	await _esperar(VIRA_TEMPO)

	# --- a janela: a mao no vidro, o sorriso, as tres cabecadas.
	await _padre_cabeceia()


## Uma mensagem do "?" chegando: o balao, o som, a vibracao na mao e a lente
## chegando um pouco mais nos baloes. `i` e a ordem dela (o som desce a cada
## uma).
func _receber_do_padre(app: AppMensagens, texto: String, i: int) -> void:
	app.receber(FALAS["desconhecido"], texto)
	_som(&"mensagem_recebida", -7.0 + float(i) * 0.6, 1.0 - float(i) * 0.015)
	_som(&"vibra_banco", -12.0)
	if _motorista != null:
		_motorista.vibrar_na_mao(0.3)
	_animar(&"_fov_cena", MENSAGENS_FOV - float(i + 1) * MENSAGENS_APERTA, 0.4,
		Tween.TRANS_SINE)
	# A cada mensagem o aparelho piora — um tranco na tela quando ela chega, e o
	# zumbido de interferencia saindo do alto-falante — e la fora batem mais.
	var j := mini(i, PANE_POR_MENSAGEM.size() - 1)
	var nivel: float = PANE_POR_MENSAGEM[j]
	if _motorista != null:
		var t := create_tween()
		t.tween_method(_motorista.pane_no_celular, minf(1.0, nivel + PANE_TRANCO), nivel,
			PANE_TRANCO_TEMPO).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_som(&"celular_pane", lerpf(-24.0, -8.0, nivel), randf_range(0.92, 1.08))
	_batidas = BATIDAS_POR_MENSAGEM[j]
	_cerco(&"mensagem", [i, (FALAS["recado"] as Array).size() + 1])


# --- o cerco: as maos batendo no carro --------------------------------------
## Enquanto o "?" escreve, a multidao chega no carro: palmas na lataria e nos
## vidros, de todos os lados menos a janela dele (ali o padre esta parado,
## sorrindo), cada vez mais e mais forte a cada mensagem. Param todas de uma vez
## quando o aparelho morre.
##
## [onde, no espaco do carro (frente em -Z, motorista em -X); e vidro?]
const BATIDA_LUGARES := [
	[Vector3(0.0, 1.44, 0.1), false], [Vector3(0.1, 1.44, -0.55), false],
	[Vector3(0.87, 1.05, -0.2), true], [Vector3(0.88, 0.72, 0.05), false],
	[Vector3(0.85, 1.02, 0.85), true], [Vector3(-0.85, 1.02, 0.9), true],
	[Vector3(0.0, 1.18, 1.55), true], [Vector3(0.0, 0.95, 2.1), false],
	[Vector3(0.05, 1.15, -1.05), true], [Vector3(0.3, 0.92, -1.75), false],
	[Vector3(-0.35, 0.92, -1.75), false], [Vector3(-0.88, 0.62, 0.55), false],
]
## A pane e as batidas, de mensagem em mensagem (a setima e o "Olha pra mim.").
const PANE_POR_MENSAGEM := [0.06, 0.14, 0.24, 0.36, 0.5, 0.66, 0.85]
const BATIDAS_POR_MENSAGEM := [0.12, 0.24, 0.38, 0.52, 0.68, 0.85, 1.0]
## O tranco na tela quando a mensagem chega: a pane pula este tanto e volta.
const PANE_TRANCO := 0.32
const PANE_TRANCO_TEMPO := 0.22
## O ultimo rasgo antes de a tela apagar, e o silencio antes de ele virar (s).
const CELULAR_MORRE := 0.16
const SILENCIO_ANTES_DE_VIRAR := 0.55
## Batidas por segundo com o cerco em 0 e em 1, e o volume (dB) de uma.
const BATIDAS_RITMO := Vector2(1.1, 10.0)
const BATIDAS_DB := Vector2(-13.0, 1.0)
var _batidas: float = 0.0
var _batida_t: float = 0.0
var _batendo: Array[AudioStreamPlayer3D] = []


func _bater_em_volta(delta: float) -> void:
	if _batidas <= 0.001 or _carro == null:
		return
	_batida_t -= delta
	if _batida_t > 0.0:
		return
	var ritmo := lerpf(BATIDAS_RITMO.x, BATIDAS_RITMO.y, _batidas * _batidas)
	_batida_t = randf_range(0.45, 1.55) / ritmo
	_uma_batida(BATIDA_LUGARES.pick_random())
	# As vezes as duas palmas, uma logo depois da outra.
	if randf() < 0.3:
		var perto: Array = BATIDA_LUGARES.pick_random()
		get_tree().create_timer(randf_range(0.05, 0.11)).timeout.connect(func() -> void:
			if _batidas > 0.001:
				_uma_batida(perto))


func _uma_batida(lugar: Array) -> void:
	var vidro: bool = lugar[1]
	var nome: StringName
	if vidro:
		nome = &"tapa_vidro" if randf() < 0.4 else StringName("mao_vidro_%d" % randi_range(1, 2))
	else:
		nome = StringName("mao_lataria_%d" % randi_range(1, 4))
	var st := AudioDirector.stream(nome)
	if st == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = lerpf(BATIDAS_DB.x, BATIDAS_DB.y, _batidas) + randf_range(-4.0, 1.0)
	p.pitch_scale = randf_range(0.88, 1.12)
	p.unit_size = 3.0
	p.max_db = 6.0
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_carro.add_child(p)
	p.position = (lugar[0] as Vector3) + Vector3(randf_range(-0.2, 0.2), randf_range(-0.08, 0.08),
		randf_range(-0.25, 0.25))
	p.play()
	_batendo.append(p)
	p.finished.connect(func() -> void:
		_batendo.erase(p)
		p.queue_free())
	AudioDirector.registrar(nome, p.volume_db, "cerco")
	# O carro sente a pancada: a lente treme um nada.
	_tremor = maxf(_tremor, lerpf(0.04, 0.22, _batidas) * (0.6 if vidro else 1.0))


## Todas param no mesmo quadro, inclusive as que ainda soavam.
func _calar_as_batidas() -> void:
	_cerco(&"congelar")
	_batidas = 0.0
	for p: AudioStreamPlayer3D in _batendo:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	_batendo.clear()


# --- os outros no carro -----------------------------------------------------
## Os encapuzados que escalam o carro e o do capo, que bate a cabeca no
## para-brisa junto com o padre (`CercoNoCarro`, arquivo proprio). Carregado
## pelo caminho: a estrada compila e roda igual sem ele. O roteiro so avisa os
## momentos (`montar`, `aquecer`, `comecar`, `mensagem`, `congelar`,
## `cabecada`, `desligar`) e pergunta onde esta o rosto do capo
## (`rosto_no_capo`), para a lente.
const CERCO_NO_CARRO := "res://src/levels/cerco_no_carro.gd"
var _cerco_carro: Node = null


func _cerco(metodo: StringName, args: Array = []) -> Variant:
	if _cerco_carro == null or not is_instance_valid(_cerco_carro) \
			or not _cerco_carro.has_method(metodo):
		return null
	return _cerco_carro.callv(metodo, args)


## O relance: por cima de tudo que a lente segue, ela escapa para `ponto` (um
## Callable que devolve a posicao em mundo; Vector3.INF = nada) em `ida`
## segundos, fica `fica` e volta em `volta`. Com `fov` > 0 a lente abre ou
## fecha junto e depois volta ao que era. Quem pede e o `CercoNoCarro` (o
## carro afundando: ele ergue os olhos do celular) e a janela (o do capo).
var _relance_de: Callable
var _relance_peso: float = 0.0
var _tween_relance: Tween


func relance(ponto: Callable, ida: float, fica: float, volta: float,
		peso: float = 1.0, fov: float = 0.0) -> void:
	if _tween_relance != null and _tween_relance.is_valid():
		_tween_relance.kill()
	_relance_de = ponto
	_tween_relance = create_tween()
	_tween_relance.tween_property(self, "_relance_peso", peso, maxf(ida, 0.01)) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if fov > 0.0:
		var fov_antes := _fov_cena
		_tween_relance.parallel().tween_property(self, "_fov_cena", fov, maxf(ida, 0.01)) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween_relance.tween_interval(maxf(fica, 0.0))
		_tween_relance.tween_property(self, "_relance_peso", 0.0, maxf(volta, 0.01)) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_tween_relance.parallel().tween_property(self, "_fov_cena", fov_antes, maxf(volta, 0.01)) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		_tween_relance.tween_interval(maxf(fica, 0.0))
		_tween_relance.tween_property(self, "_relance_peso", 0.0, maxf(volta, 0.01)) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# --- GOLPE 3: a cabeca no vidro ---------------------------------------------
## O fim. Ele esta na janela quando a cabeca do motorista chega. Poe a mao no
## vidro, devagar, os dedos primeiro. Sorri olhando para a lente: a cara vira
## ate apontar para ela, e a boca abre mais do que uma boca abre. Para. E bate
## a cabeca no vidro, tres vezes:
##
##   1. a antecipacao devagar (o tronco para tras, o queixo subindo, sem tirar
##      os olhos da lente) e o golpe de uma vez: a testa abre, e o sangue dele
##      ja fica no vidro, com a trinca em estrela debaixo;
##   2. mais forte: a cara fica colada e escorrega, arrastando o sangue, e a
##      trinca corre;
##   3. a mais funda: o temperado esfarela, a cabeca entra pelo buraco ate um
##      palmo da lente, as maos vem atras, o agarrao, o puxao, o branco.
##
## O som da cena ganha um degrau a cada uma: antes de cada golpe o ar e puxado
## (a chuva some, `_vacuo`, e o `tensao_suga` cresce) e no golpe tudo volta de
## uma vez com o grave de filme (`tensao_impacto_N`, maior a cada batida); o
## cluster grave (`tensao_drone_loop`) nasce no sorriso e sobe de volume e de
## tom em cada golpe; o coracao entra na primeira e acelera.
##
## E no capo, ao mesmo tempo, o outro (`CercoNoCarro`): a primeira dele bate
## logo atras da primeira do padre, fora de quadro — o baque da frente, o carro
## sacudindo —, e a lente escapa para o para-brisa e o ve bater de novo, perto,
## antes de voltar a janela para a segunda.
##
## A pose da cabecada e da `CabecadaDoPadre`: a cena anima encara, recua, bote e
## a distancia da testa ao vidro, e ela garante que a testa encoste no vidro no
## quadro do golpe.

## A mao vindo de baixo da janela ate encostar, e assentando (s). E quanto ela
## escorrega no vidro molhado ao assentar (m).
const MAO_SOBE := 0.6
const MAO_ASSENTA := 0.45
const MAO_ESCORREGA := 0.022
## Onde a mao encosta, NA TELA (coordenada de -1 a 1 da lente com `MAOS_FOV`),
## a partir do rosto: de lado e abaixo dele, sem tapar a cara nem o ponto em
## que a testa vai bater.
const MAO_NA_TELA := Vector2(0.62, -0.42)
## A cara virando para a lente, e o sorriso abrindo olhando para ela (s).
const ENCARA_TEMPO := 0.7
const SORRI_TEMPO := 1.8
## O quanto a cabeca deita de lado enquanto sorri (rad): menos que o estalo da
## versao das maos — com a cabeca deitada demais a testa nao vem de frente.
const SORRI_TOMBA := 0.26
## Enquanto sorri, a testa chega a isto do vidro (m).
const TESTA_PERTO := 0.075
## Parado, sorrindo, antes da primeira (s).
const PAUSA_ANTES := 0.5
## Por golpe: a antecipacao (s), quanto a testa vai para tras nela (m, alem do
## `TESTA_PERTO`), o golpe (s) e quanto a cara fica colada depois (s).
const CABECADA_RECUA := [0.52, 0.4, 0.7]
const CABECADA_LONGE := [0.13, 0.17, 0.27]
const CABECADA_BOTE := [0.085, 0.072, 0.06]
const CABECADA_COLA := [0.24, 0.22, 0.0]
const DESCOLA_TEMPO := 0.22
## A testa passa um fio do plano do vidro no golpe (m): a pele cede.
const AMASSA := 0.004
## Na segunda a cara escorrega colada e arrasta o sangue (m, para baixo).
const ARRASTO := 0.045
## Depois do estouro a testa entra na cabine isto alem do vidro (m).
const CABECA_ENTRA := 0.19
const CABECA_ENTRA_TEMPO := 0.16
## Com a cabeca dentro, antes das maos (s): o sorriso a um palmo da lente.
## Com a cabeca dentro, antes das maos (s): a cara destruida a um palmo da
## lente, olhando para ela, o olho pendurado. O sadismo e o tempo.
const CABECA_DENTRO := 2.0
## O hit stop de cada golpe (s de relogio, com o tempo do jogo quase parado).
const HIT_STOP := [0.035, 0.05, 0.075]
## Com o tempo parado, quanto anda (fracao do normal).
const HIT_STOP_ESCALA := 0.02
## O olho esquerdo saindo da orbita no estouro (m/s, na direcao da lente e
## para baixo). Ele cai com peso; a 1,1 m/s ia 11 cm por quadro de rajada e
## lia como teleporte.
const OLHO_SAI := Vector2(0.45, 0.4)
## O queixo (malha da cabeca), de onde o sangue pinga no parapeito.
const QUEIXO := Vector3(0.0, -0.155, -0.075)
## O meio da cara (malha da cabeca), entre os olhos e a boca: para onde a lente
## vai no stare.
const CARA_MEIO := Vector3(0.0, -0.03, -0.09)
## Quanto a lente segue o meio da cara no stare (1/s): devagar, para o tique
## nao virar tranco de camera.
const CARA_SEGUE := 3.0
## A ponta do nariz (malha da cabeca): a segunda marca no vidro, do nariz.
const NARIZ := Vector3(0.0, -0.02, -0.114)
## O relance para o capo, entre a primeira e a segunda (s): quanto depois da
## primeira ele sai, vai, fica e volta; o campo da lente la.
const CAPO_DEPOIS := 0.26
const CAPO_IDA := 0.19
const CAPO_FICA := 0.9
const CAPO_VOLTA := 0.22
const CAPO_FOV := 50.0
## Quanto depois do relance sair a testa do capo bate (s): a lente chega, ve
## ele puxar a cabeca para tras e bater.
const CAPO_BATE := 0.62
## Quanto depois da primeira do padre a primeira do capo bate, fora de quadro
## (s): o baque da frente logo atras do da janela.
const CAPO_PRIMEIRA_ATRAS := 0.14
## Quanto depois da segunda e da terceira do padre o capo bate de novo (s).
const CAPO_DEPOIS_DA := [0.0, 0.3, 0.12]
## Ate onde o sangue ja desceu pela cara dele depois de cada golpe
## (`CabecaDoPadre.por_sangue`), e em quanto tempo.
const SANGUE_NA_CARA := [0.34, 0.66, 1.0]
const SANGUE_DESCE := [1.6, 1.2, 2.8]
## O cluster de tensao e o coracao: volume (dB) no sorriso e depois de cada
## golpe, e a afinacao.
const DRONE_DB := [-24.0, -15.0, -10.0, -5.0]
const DRONE_TOM := [0.94, 1.0, 1.06, 1.12]
const CORACAO_DB := [-60.0, -13.0, -8.0, -4.0]
const CORACAO_TOM := [1.0, 1.0, 1.3, 1.6]
## O agarrao, na tela e em distancia da lente (m): x para o lado (a do pescoco
## do lado da frente do carro, a da cara do outro), y para cima, z a
## distancia. A 15 cm (a primeira tentativa) a mao na cara era um borrao bege
## em dois tercos do quadro, e tapava o padre entrando.
const AGARRA_PESCOCO := Vector3(0.55, -0.72, 0.34)
const AGARRA_CARA := Vector3(0.62, -0.25, 0.3)
const MAOS_ENTRAM := 0.16
const MAOS_FECHAM := 0.07
## O vidro esfarelado, inteiro no quadro, antes de desabar (s).
const VIDRO_ESFARELA := 0.07
const PUXAO_METROS := 0.55
const PUXAO_TEMPO := 0.3
## Quanto do puxao passa antes do corte. O puxao sai de uma vez — e o tranco —
## e nao acelerando: com a curva de entrada lenta, no corte ele nem tinha
## saido do lugar.
const PUXAO_CORTA := 0.32
## O motorista se encolhendo a cada batida: quanto a cabeca vai para o lado de
## dentro do carro (m).
const RECUA_METROS := 0.045
## O campo de referencia para escolher pontos NA TELA (`_na_tela`).
const MAOS_FOV := 50.0
var _maos_padre: Array[BracoVivo] = []
## O soco na lente a cada batida (graus a menos no campo) e o encolher dele
## (0 a 1). Somados por cima do enquadramento em `_mover_camera`: animar o
## proprio `_fov_cena` brigava com a lente que ainda estava chegando.
var _soco: float = 0.0
var _recua: float = 0.0
var _cabecada: CabecadaDoPadre
var _sangue_janela: SangueNoVidro
var _trinca_testa: TrincaDeVidro
var _drone: AudioStreamPlayer
var _coracao_tensao: AudioStreamPlayer
var _sangue_cara: float = 0.0
var _dano_cara: float = 0.0
var _olho_solto: OlhoSolto
var _gore: GoreDeCabecada


func _padre_cabeceia() -> void:
	var cabine := _carro.cabine
	var a := _abertura(&"porta_frente", -1)
	if cabine == null or a.is_empty() or _padre == null:
		_ao_branco()
		return
	var pts: PackedVector3Array = a["pontos"]
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	var c: Vector3 = a["centro"]
	var cima := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
	var frente := (pts[0] - pts[1])
	frente = (frente - n * n.dot(frente)).normalized()
	# O plano do vidro no espaco do carro (o pai do padre), onde a cabecada mede.
	var o_vidro := _carro.to_local(cabine.to_global(c + n * SangueNoVidro.PARA_FORA))
	var n_vidro := (_carro.global_basis.inverse() * (cabine.global_basis * n)).normalized()
	var rosto := _padre.get_meta(&"rosto", null) as Node3D
	_cabecada = CabecadaDoPadre.new(_padre, rosto, _cam, o_vidro, n_vidro)
	if _capuz_padre != null:
		_cabecada.prender_pano(_capuz_padre.pano)
	_cabecada.distancia = _cabecada.distancia_agora()
	var tique := _tique_de(_padre)
	if tique != null:
		# O tique para de sortear a cabeca: quem manda nela e a cabecada. O
		# tremor fino fica.
		tique.fixar_cabeca(Vector3.ZERO, 0.4)
	# Os bracos: os do esqueleto somem (de perto, em 4K, a mao de caixa do
	# `Corpo` e uma luva de massinha) e quem faz os dele sao os `BracoVivo`,
	# finos e podres. A 0 e a da frente do carro, como o ombro 0.
	var ombros := _ombros_do_padre(cabine)
	_esconder_bracos_do_padre()
	for k in 2:
		var lado := 1.0 if k == 0 else -1.0
		var b := BracoVivo.criar("MaoPadre%d" % k, lado < 0.0, PELE_DAS_MAOS,
			BATINAS[0], true)
		MaosPodres.vestir(b)
		cabine.add_child(b)
		b.ombro = ombros[k] if not ombros.is_empty() else c + n * 0.42 + frente * lado * 0.2
		b.polo = (Vector3.DOWN + n * 0.6).normalized()
		b.dedos_vivos = 2.0
		_maos_padre.append(b)

	# --- a cara vira para a lente, a mao sobe
	_marca("janela")
	_foto("10_janela")
	var t_enc := create_tween().set_parallel(true)
	t_enc.tween_property(_cabecada, "encara", 1.0, ENCARA_TEMPO) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t_enc.tween_property(_cabecada, "distancia", TESTA_PERTO, ENCARA_TEMPO + SORRI_TEMPO) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# A lente olha entre a cara e o ponto do vidro em que a testa vai bater: a
	# cabeca anda no quadro — vai e vem —, e nao o quadro com ela.
	var no_vidro_mundo := _carro.to_global(_cabecada.ponto_no_vidro())
	_foco_de = func() -> Vector3:
		return _rosto_do_padre().lerp(no_vidro_mundo, 0.45)
	_animar(&"_fov_cena", 42.0, ENCARA_TEMPO + SORRI_TEMPO, Tween.TRANS_SINE)
	_drone = _laco_de_tensao(&"tensao_drone_loop", -40.0)
	if _drone != null:
		_drone.pitch_scale = DRONE_TOM[0]
		create_tween().tween_property(_drone, "volume_db", DRONE_DB[0],
			ENCARA_TEMPO + SORRI_TEMPO).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	var tela_rosto := _na_tela(cabine, cabine.to_local(_rosto_do_padre()))
	var lado_tras := signf(_na_tela(cabine, cabine.to_local(_rosto_do_padre()) - frente * 0.3).x
		- tela_rosto.x)
	if lado_tras == 0.0:
		lado_tras = 1.0
	_mao_no_vidro(_maos_padre[1], cabine, tela_rosto + Vector2(lado_tras * MAO_NA_TELA.x,
		MAO_NA_TELA.y), c + n * 0.022, n, cima, frente * -1.0)
	await _esperar(0.35)

	# --- o sorriso, olhando para a lente
	if _capuz_padre != null:
		_capuz_padre.sorriso = 0.0
		_capuz_padre.olhos_tamanho = OLHOS_TAMANHO_NA_JANELA
		var t_riso := create_tween().set_parallel(true)
		t_riso.tween_property(_capuz_padre, "olhos", OLHOS_NA_JANELA, 0.25)
		t_riso.tween_property(_capuz_padre, "sorriso", 1.0, SORRI_TEMPO) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	create_tween().tween_property(_cabecada, "tombo", SORRI_TOMBA, SORRI_TEMPO) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_som(&"sorriso_abre", -5.0)
	var riso := func() -> void:
		if not _no_branco:
			_som(&"padre_riso", -9.0)
	get_tree().create_timer(SORRI_TEMPO * 0.35).timeout.connect(riso)
	await _esperar(0.45)
	_marca("mao")
	_foto("10b_mao")
	await _esperar(SORRI_TEMPO * 0.55)
	_foto("10c_sorriso")
	_medir_rosto("sorriso")
	await _esperar(SORRI_TEMPO * 0.45 + ENCARA_TEMPO - 0.8)

	# --- parado. A chuva vai sumindo: o ar e puxado para a primeira.
	_vacuo(true)
	await _esperar(PAUSA_ANTES)

	# --- as tres
	for g in 3:
		# A primeira do capo sai junto com a primeira do padre e bate logo
		# atras dela; as outras, depois da dele.
		if g == 0:
			_cerco(&"cabecada", [0, float(CABECADA_RECUA[0]) + float(CABECADA_BOTE[0])
				+ CAPO_PRIMEIRA_ATRAS])
		elif float(CAPO_DEPOIS_DA[g]) > 0.0:
			_cerco(&"cabecada", [g + 1, float(CABECADA_RECUA[g]) + float(CABECADA_BOTE[g])
				+ float(CAPO_DEPOIS_DA[g])])
		if g > 0:
			_vacuo(true)
		await _cabecada_vai(g)
		_cabecada_bate(g)
		_marca("cabecada%d" % (g + 1))
		if g == 2:
			break
		await _esperar(0.05)
		_foto("10d_cabecada%d" % (g + 1))
		_medir_rosto("cabecada%d" % (g + 1))
		var cola: float = CABECADA_COLA[g]
		if g == 1:
			# Colada, a cara escorrega e arrasta o sangue.
			var de := cabine.to_local(_carro.to_global(_cabecada.ponto_no_vidro()))
			create_tween().tween_property(_cabecada, "escorrega", ARRASTO, cola) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			if _sangue_janela != null:
				_sangue_janela.arrastar(de, de - cima * ARRASTO, cola)
		await _esperar(cola - 0.05)
		# Descola: a pele sai do vidro devagar, grudada.
		_som(&"testa_descola", -6.0 + 2.0 * g)
		var t_desc := create_tween().set_parallel(true)
		t_desc.tween_property(_cabecada, "distancia", TESTA_PERTO * 0.6, DESCOLA_TEMPO) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		t_desc.tween_property(_cabecada, "bote", 0.25, DESCOLA_TEMPO)
		if g == 0:
			# A lente escapa para o capo: o baque da frente acabou de soar, e la
			# esta o outro, de quatro no capo em chamas, batendo a testa.
			await _esperar(CAPO_DEPOIS - 0.0)
			await _relance_no_capo()
		else:
			await _esperar(DESCOLA_TEMPO + 0.08)

	# --- estoura: o temperado esfarela debaixo da testa, e ela continua.
	_marca("estoura")
	await _esperar(VIDRO_ESFARELA * 0.6)
	_foto("10g_esfarela")
	await _esperar(VIDRO_ESFARELA * 0.4)
	cabine.abrir_buraco(_caixa_da_janela(a))
	_cabecada.vidro_existe = false
	if _trinca_testa != null:
		_trinca_testa.visible = false
	# O sangue que estava no vidro cai com os cacos, e a lamina morre aqui.
	_sangue_cai_com_o_vidro(cabine, a)
	_estourar_vidro(cabine, a)
	_som(&"vidro_trinca", 2.0, 0.74)
	_som(&"zumbido_ouvido", -13.0)
	# E o olho esquerdo sai da orbita no tranco, para a lente.
	_soltar_o_olho()
	var t_entra := create_tween().set_parallel(true)
	t_entra.tween_property(_cabecada, "distancia", -CABECA_ENTRA, CABECA_ENTRA_TEMPO) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t_entra.tween_property(_cabecada, "bote", 0.0, CABECA_ENTRA_TEMPO * 1.5)
	if _capuz_padre != null:
		create_tween().tween_property(_capuz_padre, "sorriso", 1.15, CABECA_ENTRA_TEMPO * 2.0)
	_animar(&"_fov_cena", 52.0, CABECA_ENTRA_TEMPO, Tween.TRANS_SINE)
	await _esperar(CABECA_ENTRA_TEMPO)
	_foto("10h_dentro")
	_medir_rosto("dentro")
	await _encarar(CABECA_DENTRO)
	await _agarrar_e_puxar(cabine, frente, cima)


## Dois segundos parado dentro da cabine, a um palmo da lente, olhando para
## ela: a cara aberta, o olho pendurado balancando, o sangue pingando do
## queixo no parapeito. A cabeca deita devagar para o lado; a boca abre mais.
## Ele respira em cima do motorista.
func _encarar(dur: float) -> void:
	_marca("encara")
	# A lente vai para a cara: a cara destruida e o plano. O foco da cabecada
	# (entre o rosto e o ponto do vidro) fica atras da cabeca depois do
	# estouro, e o quadro dependia de onde a pose deixava o vidro.
	# O alvo e o meio da cara na malha da cabeca (entre os olhos e a boca):
	# `_rosto_do_padre` sai do osso e, com ele curvado, cai abaixo do queixo.
	# E a lente segue devagar: o tique da cabeca sacode a cara dentro do quadro,
	# e nao o quadro (seguindo o rosto na hora, a lente pulava com o tranco).
	var foco_antes := _foco_de
	var mira := {"k": 0.0, "p": Vector3.INF}
	var cara := _padre.get_meta(&"rosto", null) as Node3D
	_foco_de = func() -> Vector3:
		var r := cara.global_transform * CARA_MEIO if is_instance_valid(cara) \
			else _rosto_do_padre()
		if mira.p == Vector3.INF:
			mira.p = r
		mira.p = (mira.p as Vector3).lerp(r, 1.0 - exp(-get_process_delta_time() * CARA_SEGUE))
		r = mira.p
		return (foco_antes.call() as Vector3).lerp(r, mira.k) if foco_antes.is_valid() else r
	create_tween().tween_method(func(v: float) -> void: mira.k = v, 0.0, 1.0, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var cab := _padre.get_meta(&"rosto", null) as Node3D
	if _gore != null and cab != null:
		_gore.pingar(cab, QUEIXO)
	_som(&"sangue_pinga_loop", -10.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_cabecada, "tombo", SORRI_TOMBA + 0.3, dur) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	if _capuz_padre != null:
		t.tween_property(_capuz_padre, "sorriso", 1.2, dur * 0.8)
	_animar(&"_fov_cena", 44.0, dur, Tween.TRANS_SINE)
	# O motorista prende o ar: a lente quase nao se mexe. O sadismo e ele parado
	# olhando; a respiracao cheia balancava o quadro a 2 Hz.
	_animar(&"_ofego", 0.2, 0.5)
	get_tree().create_timer(0.35).timeout.connect(_som.bind(&"padre_riso", -6.0, 0.82))
	_foto("10h_encara_0")
	await _esperar(dur * 0.5)
	_foto("10h_encara_1")
	_medir_rosto("encara")
	await _esperar(dur * 0.5)
	_foto("10h_encara_2")


## A mao `b` subindo de baixo da janela e pousando espalmada no vidro, no ponto
## que a lente ve em `uv`: os dedos primeiro, a palma assenta e escorrega um
## nada no vidro molhado. `frente` e o lado da frente do carro NO VIDRO, para
## os dedos abrirem para fora.
func _mao_no_vidro(b: BracoVivo, cabine: Node3D, uv: Vector2, o: Vector3, n: Vector3,
		cima: Vector3, frente: Vector3) -> void:
	var onde := _da_tela_ao_plano(cabine, uv, o, n)
	var d := (cima + frente * 0.22).normalized()
	var embaixo := BracoVivo.pega(onde + n * 0.28 - cima * 0.45, d, n, &"relaxada")
	var perto := BracoVivo.pega(onde + n * 0.03 - cima * 0.02, d, n, &"aberta")
	var pousa := BracoVivo.pega(onde, d, n, &"apoio")
	var assenta := BracoVivo.pega(onde - cima * MAO_ESCORREGA, d, n, &"apoio_forca")
	b.pular(embaixo)
	b.visible = true
	b.ir(perto, MAO_SOBE, n * 0.06, 0.25)
	await _esperar(MAO_SOBE)
	b.ir(pousa, 0.12)
	await _esperar(0.08)
	_som(&"mao_pousa_vidro", -6.0)
	await _esperar(0.04)
	b.ir(assenta, MAO_ASSENTA)
	_som(&"unha_vidro", -14.0, 0.9)
	b.set_meta(&"no_vidro", assenta)


## Um golpe inteiro ate o contato: a antecipacao devagar e o bote de uma vez.
func _cabecada_vai(g: int) -> void:
	var recua: float = CABECADA_RECUA[g]
	var bote: float = CABECADA_BOTE[g]
	var longe := TESTA_PERTO + float(CABECADA_LONGE[g])
	var t := create_tween().set_parallel(true)
	t.tween_property(_cabecada, "recua", 1.0, recua) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_cabecada, "bote", 0.0, recua * 0.6)
	t.tween_property(_cabecada, "escorrega", 0.0, recua)
	t.tween_property(_cabecada, "distancia", longe, recua) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	# O ar puxado para dentro, que acaba no golpe.
	var suga := _som(&"tensao_suga", -10.0 + 3.5 * float(g))
	if suga != null:
		suga.seek(maxf(0.0, 0.55 - recua - bote))
	# Os dedos no vidro apertam: ele vai usar a mao de apoio.
	if _maos_padre.size() > 1 and _maos_padre[1].has_meta(&"no_vidro"):
		_maos_padre[1].dedos_vivos = 0.6
	await _esperar(recua)
	# O bote: acelerando ate o vidro, sem freio — quem para a cabeca e o vidro.
	var b := create_tween().set_parallel(true)
	b.tween_property(_cabecada, "distancia", -AMASSA, bote) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	b.tween_property(_cabecada, "recua", 0.0, bote).set_ease(Tween.EASE_IN)
	b.tween_property(_cabecada, "bote", 1.0, bote).set_ease(Tween.EASE_IN)
	await _esperar(bote)


## O contato: o sangue e a trinca onde a testa encostou, o som em degrau, a
## lente tomando o soco, ele se encolhendo, o carro sacudindo.
func _cabecada_bate(g: int) -> void:
	var forca: float = [0.55, 0.8, 1.0][g]
	var cabine := _carro.cabine
	var a := _abertura(&"porta_frente", -1)
	var ponto := cabine.to_local(_carro.to_global(_cabecada.ponto_no_vidro()))
	if _sangue_janela != null:
		_sangue_janela.golpe(ponto, forca, 1.15 + 0.15 * float(g))
		if g >= 1:
			# O nariz esmagado deixa a dele, embaixo da testa.
			var nariz := cabine.to_local(_carro.to_global(_cabecada.no_vidro(NARIZ)))
			_sangue_janela.golpe(nariz, forca * 0.85, 1.0)
	_cabecada_gore(g)
	if _trinca_testa == null and not a.is_empty():
		_trinca_testa = TrincaDeVidro.na_abertura(a, ponto - (a["normal"] as Vector3) * 0.024, 61.0)
		if _trinca_testa != null:
			cabine.add_child(_trinca_testa)
			_trinca_testa.ajustar(&"miolo", 0.035)
			_trinca_testa.ajustar(&"alcance", 0.16)
			# A trinca e de dentro do vidro: por cima do sangue, que e de fora.
			_trinca_testa.material_override.render_priority = 2
	if _trinca_testa != null:
		match g:
			0:
				_trinca_testa.crescer(0.55, 0.06)
			1:
				_trinca_testa.ajustar(&"alcance", 0.42)
				_trinca_testa.ajustar(&"miolo", 0.05)
				_trinca_testa.crescer(0.9, 0.07)
			2:
				_trinca_testa.ajustar(&"alcance", 0.9)
				_trinca_testa.crescer(1.0, 0.03)
				var esfarela := func(v: float) -> void: _trinca_testa.ajustar(&"esfarela", v)
				create_tween().tween_method(esfarela, 0.0, 1.0, VIDRO_ESFARELA * 0.8)
	# O som: o fisico, o golpe de filme, o mundo voltando inteiro.
	_som(StringName("cabecada_vidro_%d" % (g + 1)), -1.0 + 1.5 * float(g))
	_som(StringName("tensao_impacto_%d" % (g + 1)), -8.0 + 3.5 * float(g))
	if g == 2:
		_som(&"susto_golpe", -5.0)
	_vacuo(false)
	if _drone != null:
		var td := create_tween().set_parallel(true)
		td.tween_property(_drone, "volume_db", DRONE_DB[g + 1], 0.3)
		td.tween_property(_drone, "pitch_scale", DRONE_TOM[g + 1], 0.5)
	if _coracao_tensao == null:
		_coracao_tensao = _laco_de_tensao(&"coracao_loop", CORACAO_DB[0])
	if _coracao_tensao != null:
		var tc := create_tween().set_parallel(true)
		tc.tween_property(_coracao_tensao, "volume_db", CORACAO_DB[g + 1], 0.25)
		tc.tween_property(_coracao_tensao, "pitch_scale", CORACAO_TOM[g + 1], 0.8)
	# A lente e ele.
	_tremor = maxf(_tremor, 0.45 + 0.4 * forca)
	_soco = 3.0 + 4.5 * forca
	_animar(&"_soco", 0.0, 0.28, Tween.TRANS_SINE)
	_recua = forca
	_animar(&"_recua", 0.0, 0.65, Tween.TRANS_SINE)
	_carro.pancada(0.05 * forca, 0.32 * forca)
	# A mao de apoio espreme no vidro com o golpe, e depois solta um nada.
	if _maos_padre.size() > 1 and _maos_padre[1].has_meta(&"no_vidro"):
		_maos_padre[1].dedos_vivos = 2.0
	# A testa aberta: o sangue desce pela cara dele.
	var cab := _padre.get_meta(&"rosto", null) as CabecaDoPadre
	if cab != null:
		var de := maxf(_sangue_cara, 0.02)
		var escorre := func(v: float) -> void:
			_sangue_cara = v
			cab.por_sangue(v)
		create_tween().tween_method(escorre, de, float(SANGUE_NA_CARA[g]),
			float(SANGUE_DESCE[g])).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## A lente escapa da janela para o para-brisa: o do capo bate a testa nele,
## perto, e ela volta a tempo de ver o padre puxar a cabeca para a segunda.
func _relance_no_capo() -> void:
	var r: Variant = _cerco(&"rosto_no_capo")
	# So vira se ele ja esta no capo: na frente do motorista e abaixo do teto.
	# Com o do capo ainda escalando, a lente ia olhar o forro do teto.
	var no_capo := r is Vector3 and (r as Vector3).is_finite()
	if no_capo:
		var local := _carro.to_local(r as Vector3)
		var olho := _carro.to_local(_cam.global_position)
		no_capo = local.z < olho.z - 0.5 and local.y < olho.y + 0.15
		print("[padre] capo: rosto em %s (carro), olho em %s: %s" % [local, olho,
			"vira" if no_capo else "nao vira"])
	if not no_capo:
		await _esperar(CAPO_IDA + CAPO_FICA + CAPO_VOLTA - 0.5)
		return
	_marca("capo")
	var alvo := func() -> Vector3:
		var p: Variant = _cerco(&"rosto_no_capo")
		return p if p is Vector3 else Vector3.INF
	relance(alvo, CAPO_IDA, CAPO_FICA, CAPO_VOLTA, 1.0, CAPO_FOV)
	_cerco(&"cabecada", [1, CAPO_BATE])
	await _esperar(CAPO_IDA + CAPO_BATE * 0.5)
	_foto("10e_capo")
	await _esperar(CAPO_BATE * 0.5 + 0.06)
	_foto("10f_capo_bate")
	# A segunda do padre ja comeca enquanto a lente volta: ela chega e o ve
	# la atras, puxado, antes do golpe.
	await _esperar(CAPO_IDA + CAPO_FICA - CAPO_BATE - 0.06 - 0.12)


## As maos atravessam o buraco e vem nele: a da frente no pescoco, a outra na
## cara. O puxao, e no comeco dele, o branco.
func _agarrar_e_puxar(cabine: Node3D, frente: Vector3, cima: Vector3) -> void:
	var olho := cabine.to_local(_cam.global_position)
	var rosto := cabine.to_local(_rosto_do_padre())
	var para_janela := rosto - olho
	para_janela = (para_janela - cima * para_janela.dot(cima)).normalized()
	var tela_rosto := _na_tela(cabine, rosto)
	var lado_frente := signf(_na_tela(cabine, rosto + frente * 0.3).x - tela_rosto.x)
	if lado_frente == 0.0:
		lado_frente = 1.0
	var pescoco := _da_tela_a_distancia(cabine, Vector2(lado_frente * AGARRA_PESCOCO.x,
		AGARRA_PESCOCO.y), AGARRA_PESCOCO.z)
	var d_pescoco := (-para_janela + frente * 0.35 - cima * 0.15).normalized()
	var cara := _da_tela_a_distancia(cabine, Vector2(-lado_frente * AGARRA_CARA.x,
		AGARRA_CARA.y), AGARRA_CARA.z)
	var d_cara := (cima * 0.75 - para_janela * 0.55 - frente * 0.2).normalized()
	# A do pescoco vem de baixo da janela (estava fora de quadro); a da cara e a
	# que estava no vidro, que caiu com ele.
	var n := -para_janela
	_maos_padre[0].pular(BracoVivo.pega(pescoco + n * 0.35 - cima * 0.35, d_pescoco, cima,
		&"aberta"))
	_maos_padre[0].visible = true
	_maos_padre[0].ir(BracoVivo.pega(pescoco, d_pescoco, cima, &"garra"), MAOS_ENTRAM,
		cima * 0.05, 0.6)
	_maos_padre[1].ir(BracoVivo.pega(cara, d_cara, para_janela, &"garra"), MAOS_ENTRAM,
		cima * 0.03 - frente * 0.04, 0.8)
	_tremor = 0.8
	await _esperar(MAOS_ENTRAM * 0.7)
	_foto("10i_vem")
	_medir_rosto("vem")
	await _esperar(MAOS_ENTRAM * 0.3)
	for k in 2:
		var p := _maos_padre[k].pegada.duplicate()
		p["pose"] = MaoPosada.pose(&"punho")
		_maos_padre[k].ir(p, MAOS_FECHAM)
	_som(&"arrasto_corpo", -2.0, 1.25)
	_som(&"tapa_vidro", -4.0, 0.7)
	await _esperar(MAOS_FECHAM)
	_foto("10j_agarra")
	_medir_rosto("agarra")
	# O puxao: com toda a forca, para fora, de uma vez. E no comeco dele, o
	# branco.
	create_tween().tween_property(self, "_puxao", 1.0, PUXAO_TEMPO) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tremor = 1.0
	await _esperar(PUXAO_TEMPO * PUXAO_CORTA)
	_ao_branco()
	await _esperar(2.6)


## Um laco da cena (o cluster, o coracao) com o tocador na mao, para a cena
## subir o degrau dele; o branco corta como os outros (`_lacos`).
func _laco_de_tensao(nome: StringName, db: float) -> AudioStreamPlayer:
	if _no_branco:
		return null
	var st := AudioDirector.em_loop(nome)
	if st == null:
		push_warning("[susto] som ausente: %s" % nome)
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p)
	p.play()
	_lacos.append(p)
	AudioDirector.registrar(nome, db, "laco")
	return p


## A cara pior a cada golpe, no quadro do golpe: o dano sobe de uma vez (o
## osso cede), o esguicho sai (para fora nas duas primeiras, com o vidro
## segurando; para dentro na ultima), e o tempo para uns quadros.
func _cabecada_gore(g: int) -> void:
	var cab := _padre.get_meta(&"rosto", null) as CabecaDoPadre
	var de := _dano_cara
	_dano_cara = float(g + 1)
	if cab != null:
		var dano := func(v: float) -> void: cab.por_dano(v)
		create_tween().tween_method(dano, de, _dano_cara, 0.045) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	if _gore != null:
		var testa := _cabecada.testa()
		var n_mundo := (_carro.global_basis * _cabecada.normal()).normalized()
		var para := n_mundo * 0.55 + Vector3.DOWN * 0.35
		# No terceiro o vidro cede e o esguicho vai para dentro, caindo: mirado
		# na lente, ele enchia o stare de gota grande parada na frente da cara.
		if g == 2:
			para = -n_mundo * 0.45 + Vector3.DOWN * 0.55
		_gore.golpe(testa + n_mundo * 0.012 * (1.0 if g < 2 else -1.0), para,
			[0.4, 0.75, 1.0][g], g >= 1)
	_som(&"nariz_quebra", -6.0 + 3.0 * float(g), 1.0 - 0.06 * float(g))
	if g >= 1:
		_som(&"carne_rasga", -9.0 + 3.0 * float(g))
	_parar_o_tempo(float(HIT_STOP[g]))


## O hit stop: o jogo quase para por uns quadros, e o som continua.
func _parar_o_tempo(segundos: float) -> void:
	if _no_branco:
		return
	Engine.time_scale = HIT_STOP_ESCALA
	await get_tree().create_timer(segundos, true, false, true).timeout
	Engine.time_scale = 1.0


## O olho esquerdo sai da orbita: o globo vai para o `OlhoSolto`, a orbita
## vira buraco.
func _soltar_o_olho() -> void:
	var cab := _padre.get_meta(&"rosto", null) as CabecaDoPadre
	if cab == null or _olho_solto == null or cab.olho_esquerdo() == null:
		return
	var olho := cab.olho_esquerdo()
	var para := (_cam.global_position - olho.global_position).normalized()
	_olho_solto.soltar(cab, olho, para * OLHO_SAI.x + Vector3.DOWN * OLHO_SAI.y)
	var orbita := func(v: float) -> void: cab.por_orbita_vazia(v)
	create_tween().tween_method(orbita, 0.0, 1.0, 0.08)
	_som(&"olho_sai", -2.0)


## O vidro estourou com sangue nele: as marcas viram gotas e coagulos que caem
## com os cacos (para dentro, como os cacos), e a lamina morre no mesmo quadro.
func _sangue_cai_com_o_vidro(cabine: Node3D, a: Dictionary) -> void:
	if _sangue_janela == null or not is_instance_valid(_sangue_janela):
		_sangue_janela = null
		return
	var marcas := _sangue_janela.marcas_no_carro()
	if _gore != null and not marcas.is_empty():
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for m: Vector4 in marcas:
			var p := Vector3(m.x, m.y, m.z)
			var r := Vector3.ONE * m.w
			lo = lo.min(p - r)
			hi = hi.max(p + r)
		var n: Vector3 = (a["normal"] as Vector3).normalized()
		var centro := cabine.to_global((lo + hi) * 0.5)
		var meia := (hi - lo) * 0.5
		var olho := cabine.to_local(_cam.global_position)
		var para := cabine.global_basis * ((-n).lerp((olho - (lo + hi) * 0.5).normalized(), 0.15))
		_gore.do_vidro(centro, Vector3(maxf(meia.x, 0.01), maxf(meia.y, 0.01),
			maxf(meia.z, 0.01)), cabine.global_basis.orthonormalized(), para)
	_sangue_janela.quebrar()
	_sangue_janela = null


## A lamina do sangue na janela do motorista, feita no preaquecimento.
func _preparar_sangue() -> void:
	if _sangue_janela != null or _carro == null or _carro.cabine == null:
		return
	var a := _abertura(&"porta_frente", -1)
	if a.is_empty():
		return
	_sangue_janela = SangueNoVidro.na_abertura(a, 5.0)
	if _sangue_janela != null:
		_carro.cabine.add_child(_sangue_janela)
		_sangue_janela.visible = false
	# O olho que sai, e o sangue e a carne que voam.
	_olho_solto = OlhoSolto.new()
	_olho_solto.preparar(_raiz)
	_gore = GoreDeCabecada.new()
	_gore.preparar(_raiz)


## Bancada: a distancia da lente ao rosto do padre, no log, com a marca.
func _medir_rosto(marca: String) -> void:
	if _pasta_fotos.is_empty() or _padre == null or _cam == null:
		return
	print("[padre] %s: rosto a %.2f m da lente" % [marca,
		_cam.global_position.distance_to(_rosto_do_padre())])


## Onde `p` (espaco da cabine) cai na tela da lente de agora com o campo
## `MAOS_FOV`, de -1 a 1 (y para cima).
func _na_tela(cabine: Node3D, p: Vector3) -> Vector2:
	var tg := tan(deg_to_rad(MAOS_FOV) * 0.5)
	var r := _cam.global_transform.affine_inverse() * (cabine.global_transform * p)
	var z := minf(r.z, -0.01)
	return Vector2((r.x / -z) / (tg * _aspecto()), (r.y / -z) / tg)


## O raio da lente pelo ponto `uv` da tela, no espaco da cabine: [origem, direcao].
func _raio_da_tela(cabine: Node3D, uv: Vector2) -> Array:
	var tg := tan(deg_to_rad(MAOS_FOV) * 0.5)
	var cam := _cam.global_transform
	var d := cam.basis * Vector3(uv.x * tg * _aspecto(), uv.y * tg, -1.0)
	var inv := cabine.global_transform.affine_inverse()
	return [inv * cam.origin, (inv.basis * d).normalized()]


## O ponto do plano (`o`, `n`, espaco da cabine) que a lente ve em `uv`.
func _da_tela_ao_plano(cabine: Node3D, uv: Vector2, o: Vector3, n: Vector3) -> Vector3:
	var raio := _raio_da_tela(cabine, uv)
	var de: Vector3 = raio[0]
	var d: Vector3 = raio[1]
	var t := (o - de).dot(n) / (d.dot(n) if absf(d.dot(n)) > 1e-4 else 1e-4)
	return de + d * t


## O ponto a `dist` metros da lente, visto em `uv`.
func _da_tela_a_distancia(cabine: Node3D, uv: Vector2, dist: float) -> Vector3:
	var raio := _raio_da_tela(cabine, uv)
	return (raio[0] as Vector3) + (raio[1] as Vector3) * dist


func _aspecto() -> float:
	var vp := get_viewport().get_visible_rect().size
	return vp.x / maxf(1.0, vp.y)


## O branco ja caiu. Dali em diante nada da estrada volta: nem a imagem, nem o
## fogo no ouvido.
var _no_branco: bool = false


## O corte: o branco, no mesmo quadro que o som.
func _ao_branco() -> void:
	if _no_branco:
		return
	_no_branco = true
	_marca("branco")
	_cerco(&"desligar")
	Engine.time_scale = 1.0
	if _olho_solto != null:
		_olho_solto.desligar()
	if _gore != null:
		_gore.desligar()
	if _fumaca != null:
		_fumaca.cobre = 0.0
	_branco.tocar(&"tapa_vidro", 0.0)
	_branco.tocar(&"susto_golpe", -2.0)
	_branco.estourar()
	_foto("11_branco")
	# Com o branco ja desenhado, a estrada some inteira debaixo dele: carro,
	# padre, maos e estilhacos. O branco e quem esconde o fim, e ele nao e
	# eterno — quem o dissolve (a praca) nao pode achar o padre ainda no vidro.
	await RenderingServer.frame_post_draw
	if _raiz != null and is_instance_valid(_raiz):
		_raiz.visible = false
	for p: AudioStreamPlayer in _lacos:
		if is_instance_valid(p):
			p.stop()
	_lacos.clear()


## Os ombros do padre, no espaco da cabine: [o do lado da frente, o de tras].
func _ombros_do_padre(cabine: Node3D) -> Array:
	var sks := _padre.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return []
	var sk := sks[0] as Skeleton3D
	var out := []
	for osso: int in [Corpo.Osso.BRACO_E, Corpo.Osso.BRACO_D]:
		out.append(cabine.to_local(sk.global_transform * sk.get_bone_global_pose(osso).origin))
	# O da frente primeiro, como as maos.
	if (out[0] as Vector3).z > (out[1] as Vector3).z:
		out.reverse()
	return out


## Os bracos do `Corpo` somem (escala quase zero no osso do braco, que leva
## antebraco e mao junto): quem faz os bracos dele agora sao os `BracoVivo`.
func _esconder_bracos_do_padre() -> void:
	_padre.agarrar = Vector3.INF
	for sk: Node in _padre.find_children("*", "Skeleton3D", true, false):
		for osso: int in [Corpo.Osso.BRACO_E, Corpo.Osso.BRACO_D]:
			(sk as Skeleton3D).set_bone_pose_scale(osso, Vector3.ONE * 0.001)


## A caixa (espaco do carro) que tira o vidro da janela: o contorno dela, com
## folga para fora e para dentro.
func _caixa_da_janela(a: Dictionary) -> AABB:
	var cx: PackedVector3Array = a.get("contorno", a["pontos"])
	var caixa := AABB(cx[0], Vector3.ZERO)
	for p: Vector3 in cx:
		caixa = caixa.expand(p)
	return caixa.grow(0.03)


## O temperado desabando para dentro, no colo dele e na lente: graos de vidro
## — cascalho facetado, quase transparente, que so aparece onde pega luz (o
## fogo, a luz vermelha do painel) —, e umas lascas maiores, graos ainda
## grudados, girando mais devagar. Os cubinhos brancos opacos de antes liam
## como acucar.
##
## Os emissores nascem no preaquecimento, apagados (`_preparar_estilhacos`):
## criar o material de processo das particulas no quadro da quebra compilava o
## shader dele ali, e era o pico do trecho.
var _estilhacos: Array[GPUParticles3D] = []


func _preparar_estilhacos() -> void:
	if not _estilhacos.is_empty() or _carro == null or _carro.cabine == null:
		return
	var a := _abertura(&"porta_frente", -1)
	if a.is_empty():
		return
	var cabine := _carro.cabine
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	var caixa := _caixa_da_janela(a)
	var grao := SphereMesh.new()
	grao.radius = 0.0032
	grao.height = 0.0048
	grao.radial_segments = 5
	grao.rings = 2
	grao.material = _mat_estilhaco
	var lasca := BoxMesh.new()
	lasca.size = Vector3(0.017, 0.012, 0.0035)
	lasca.material = _mat_estilhaco
	# [malha, quantos, vida, velocidade min, max, espalha (graus), escala min, max]
	for e: Array in [[grao, 750, 1.3, 1.4, 5.2, 34.0, 0.55, 1.5],
			[lasca, 42, 1.5, 0.9, 3.2, 28.0, 0.7, 1.35]]:
		var ps := GPUParticles3D.new()
		ps.name = "Estilhacos"
		ps.amount = int(e[1])
		ps.lifetime = float(e[2])
		ps.one_shot = true
		ps.explosiveness = 0.9
		ps.local_coords = false
		ps.emitting = false
		var p := ParticleProcessMaterial.new()
		p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(0.01, caixa.size.y * 0.42, caixa.size.z * 0.42)
		p.direction = -n
		p.spread = float(e[5])
		p.initial_velocity_min = float(e[3])
		p.initial_velocity_max = float(e[4])
		p.gravity = Vector3(0.0, -9.8, 0.0)
		p.angular_velocity_min = -900.0
		p.angular_velocity_max = 900.0
		p.scale_min = float(e[6])
		p.scale_max = float(e[7])
		p.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
		ps.process_material = p
		ps.draw_pass_1 = e[0]
		ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ps.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
		cabine.add_child(ps)
		ps.position = caixa.get_center()
		_estilhacos.append(ps)


## Estoura: os graos saem da lamina toda para dentro, puxados para a cabeca
## dele — e ali que a lente esta.
func _estourar_vidro(cabine: Node3D, a: Dictionary) -> void:
	if _estilhacos.is_empty():
		_preparar_estilhacos()
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	var olho := cabine.to_local(_cam.global_position)
	for ps: GPUParticles3D in _estilhacos:
		var para_olho := (olho - ps.position).normalized()
		(ps.process_material as ParticleProcessMaterial).direction = \
			(-n).lerp(para_olho, 0.5).normalized()
		ps.visible = true
		ps.restart()
		ps.emitting = true


## GOLPE 1: o padre no farol.
func _golpe_na_estrada() -> void:
	_marca("golpe")
	_susto_t = 0.0
	_v_t0 = _carro.velocidade
	# Nenhum trovao agendado cai daqui para frente: o som desta cena agora e
	# todo escrito.
	_raios = TROVOADA.size()
	_vacuo(false)
	_plantar_batida()
	if _tween_olhar != null and _tween_olhar.is_valid():
		_tween_olhar.kill()
	_olhar_celular = 0.0
	if _motorista != null:
		_motorista.arremessar_celular()
		_motorista.mostrar_maos_no_volante(false)
	_som(&"susto_golpe", 0.0)
	_som(&"pneu_canta", -5.0)
	if _relampago != null and is_instance_valid(_relampago):
		_relampago.disparar(0.05)
	# A lente salta NELE: a cabeca crava no rosto e o campo fecha de 66 para
	# 28 graus em um decimo de segundo.
	# Mira um palmo acima do rosto: com a lente fechada o volante sobe para
	# dentro do quadro, e o rosto tem de ficar no terco de cima, livre dele.
	_foco_de = func() -> Vector3: return _rosto_do_padre() + Vector3.UP * 0.32
	_foco_peso = 0.0
	_animar(&"_foco_peso", 1.0, 0.07, Tween.TRANS_EXPO)
	_animar(&"_ergue", 1.0, 0.09, Tween.TRANS_EXPO)
	var t_fov := create_tween()
	t_fov.tween_property(self, "_fov_cena", SOCO_FOV, SOCO_TEMPO) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t_fov.tween_property(self, "_fov_cena", SOCO_FOV_VOLTA, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tremor = 0.8
	# E no mesmo instante o pescoco dele estala de lado, ate a orelha no ombro.
	await _esperar(0.05)
	var tique := _tique_de(_padre)
	if tique != null:
		_estalar(_padre, tique.estalar_cabeca(Vector3(0.12, 0.28, 1.34)))
	await _esperar(0.08)
	_foto("04_golpe")
	# A cabeca continua presa nele enquanto o carro gira: o mundo desliza atras
	# do padre. Depois ela estala para a frente e ele sai de quadro — ninguem
	# sabe para onde ele foi.
	await _esperar(CABECA_PRESA - 0.13)
	_som(&"galhos_lataria", -5.0)
	_animar(&"_foco_peso", 0.0, 0.15, Tween.TRANS_EXPO)
	_animar(&"_ergue", 0.0, 0.35, Tween.TRANS_SINE)
	_animar(&"_fov_cena", DENTRO_FOV, 0.3, Tween.TRANS_SINE)
	if _motorista != null:
		_motorista.mostrar_maos_no_volante(true)
	await _esperar(0.25)
	_foto("05_guinada")
	await _esperar(0.15)
	_esconder(_padre)
	for v: Corpo in _vigias:
		_esconder(v)
	await _plano_romeiros()
	_comecar(Plano.DENTRO, 60.0, false, true)
	_fov_cena = 0.0


## O segundo das figuras. Corte seco, sem trocar a luz, com a lente do plano da
## mata: o "bicho" que olhava o carro era gente. Dificeis de ver, de proposito —
## entre troncos e moita, contra o farol, e um clarao mudo de dois quadros.
func _plano_romeiros() -> void:
	_marca("romeiros")
	_comecar(Plano.ROMEIROS, ROMEIROS_DURACAO, false)
	for r: Corpo in _romeiros:
		_mostrar(r, _carro, ANDA_FIGURA)
	var coro := _som(&"coro_baixo", -12.0)
	await _esperar(0.4)
	if _relampago != null and is_instance_valid(_relampago):
		_relampago.disparar(0.3, false)
	await _esperar(0.06)
	_foto("06_romeiros")
	await _esperar(0.40)
	# O mais perto vira a cabeca para a lente nos ultimos quatro quadros.
	var perto := _romeiro_mais_perto()
	if perto != null:
		perto.olhar_para(_cam.global_position)
		var capuz := perto.get_meta(&"capuz") as CapuzMacabro
		if capuz != null:
			var t_riso := create_tween()
			t_riso.tween_property(capuz, "sorriso", 0.6, 0.14)
	await _esperar(0.14)
	if coro != null and is_instance_valid(coro):
		coro.stop()
	for r: Corpo in _romeiros:
		_esconder(r)


## A trajetoria da guinada, quadro a quadro, a partir do golpe. O desvio sai da
## trilha devagar e vai de uma vez; o nariz aponta para onde o carro esta indo;
## a velocidade cai na freada; e quando o tempo acaba, a arvore.
func _guiar_a_guinada(delta: float) -> void:
	_assombrar(delta)
	if _susto_t < 0.0 or _bateu:
		return
	_susto_t += delta
	var k := clampf(_susto_t / GUINADA_T, 0.0, 1.0)
	_carro.velocidade = lerpf(_v_t0, VEL_NA_BATIDA, k)
	_carro.desvio_cena = GUINADA_LADO * pow(k, GUINADA_CURVA)
	var lateral := GUINADA_LADO * GUINADA_CURVA \
		* pow(maxf(k, 0.001), GUINADA_CURVA - 1.0) / GUINADA_T
	_carro.guinada = atan2(lateral, maxf(_carro.velocidade / 3.6, 1.0))
	# Volante: tudo para a direita no susto, e o contraesterco tarde demais.
	_carro.volante_cena = lerpf(0.95, -0.35, smoothstep(0.35, 1.0, k))
	if k >= 1.0:
		_bater()


## Onde a guinada termina, calculado no golpe: a arvore e plantada ali, e as
## figuras em volta dela.
func _plantar_batida() -> void:
	var v0 := _v_t0 / 3.6
	var v1 := VEL_NA_BATIDA / 3.6
	var s_fim := _carro.distancia + (v0 + v1) * 0.5 * GUINADA_T
	var lateral := GUINADA_LADO * GUINADA_CURVA / GUINADA_T
	var giro := atan2(lateral, v1)
	var nariz := float(_carro.medidas().get("comprimento", 4.4)) * 0.5
	var s_arvore := s_fim + cos(giro) * nariz + 0.3
	var d_arvore := GUINADA_LADO + sin(giro) * nariz + 0.35
	if _estrada != null:
		_estrada.spawn_arvore_do_impacto(s_arvore, d_arvore)
	_posicionar_romeiros(s_fim)
	# A multidao anda para onde o carro vai parar, agora que se sabe onde.
	_alvo_multidao = EstradaBuilder.ponto_em(s_fim) + EstradaBuilder.lado_em(s_fim) * GUINADA_LADO
	# O que fica no farol depois da batida: oito metros a frente do capo, um
	# passo para fora da arvore, que tapa o meio do facho.
	var s_calma := s_fim + cos(giro) * CALMA_ADIANTE
	var d_calma := GUINADA_LADO + sin(giro) * CALMA_ADIANTE + CALMA_LADO
	_calma_pos = EstradaBuilder.ponto_em(s_calma) + EstradaBuilder.lado_em(s_calma) * d_calma
	_calma_pos.y += EstradaBuilder.altura_lateral(d_calma)
	_calma_olha = EstradaBuilder.ponto_em(s_fim) + EstradaBuilder.lado_em(s_fim) * GUINADA_LADO


## A fumaca que entra (`FumacaNegra`): quanto ela ja cobriu quando ele se
## debruca e quando a lente chega no telefone, e a altura do topo dela (em
## metros acima do tapete) rente ao chao, subindo, e na janela — onde ela desce
## para o vidro ficar livre.
const FUMACA_DEBRUCA := 0.5
const FUMACA_NO_CHAO := 0.95
const FUMACA_TETO_CHAO := 0.22
const FUMACA_TETO_ALTO := 0.34
const FUMACA_TETO_JANELA := 0.30
## A caixa da cabine em que ela vive, a partir do olho: metade da largura, do
## tapete ao forro, do painel ao banco de tras.
const FUMACA_MEIA_LARGURA := 0.78
const FUMACA_ALTURA := 1.22
const FUMACA_FRENTE := -1.25
const FUMACA_TRAS := 0.95
## O plano do braco no chao: o campo aberto (ve o braco inteiro) e o fechado
## (so a mao e o telefone), e a respiracao de quem faz forca.
const CHAO_FOV := 34.0
const OFEGO_HZ := 2.1
const OFEGO_ALTURA := 0.010
const OFEGO_GRAUS := 0.75
## A cabine depois da batida: o motor morreu, a luz do painel foi junto, e o ar
## pesa. Ambiente a um terco do que era, a cor lavada e fria, a nevoa mais perto.
const LUZ_DEPOIS_DA_BATIDA := {&"nevoa": 0.5, &"saturacao": 0.72,
	&"tinta": Color(0.90, 0.95, 1.06), &"ambiente": 0.26}


## A fumaca que entra no carro, montada vazia na cabine: nasce na fresta de
## baixo da porta do carona e anda rente ao tapete ate cobrir o carro.
func _montar_fumaca() -> void:
	if _carro.cabine == null:
		return
	var olho := _carro.cabine.olho()
	var piso := _carro.cabine.piso_da_cabine()
	var carona := -signf(olho.x) if absf(olho.x) > 0.01 else 1.0
	var meia := Vector3(FUMACA_MEIA_LARGURA, FUMACA_ALTURA * 0.5,
		(FUMACA_TRAS - FUMACA_FRENTE) * 0.5)
	var centro := Vector3(0.0, piso + meia.y, olho.z + (FUMACA_TRAS + FUMACA_FRENTE) * 0.5)
	var fresta := Vector3(carona * (FUMACA_MEIA_LARGURA - 0.05), piso + 0.12, olho.z - 0.45)
	_fumaca = FumacaNegra.criar(meia, fresta - centro, 2.6)
	_carro.cabine.add_child(_fumaca)
	_fumaca.position = centro
	_fumaca.teto = _teto_da_fumaca(FUMACA_TETO_CHAO)


## A altura `acima_do_tapete` no espaco da fumaca.
func _teto_da_fumaca(acima_do_tapete: float) -> float:
	return acima_do_tapete - FUMACA_ALTURA * 0.5


## A fumaca acompanha a luz: a tela do telefone e a luz vermelha do painel.
func _iluminar_fumaca() -> void:
	if _fumaca == null or not _fumaca.visible:
		return
	if _motorista != null:
		_fumaca.seguir_fone(_motorista.ponto_do_celular(), 1.0)
	if _luz_alerta != null and is_instance_valid(_luz_alerta):
		_fumaca.luz_vermelha(_luz_alerta.global_position, _luz_alerta.light_energy * 0.8)


func _animar_fumaca(prop: StringName, alvo: float, duracao: float) -> void:
	if _fumaca == null:
		return
	var t := create_tween()
	t.tween_property(_fumaca, NodePath(String(prop)), alvo, duracao) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _escurecer_depois_da_batida() -> void:
	_aplicar_mods(LUZ_DEPOIS_DA_BATIDA)


## O que espera no farol depois da batida: metros a frente do capo e para o
## lado, fora do tronco.
const CALMA_ADIANTE := 8.0
const CALMA_LADO := -1.5
## Quando ele aparece, depois do pisca do farol: o farol volta fraco e ele ja
## esta la.
const CALMA_SURGE := 0.62

var _calma_pos := Vector3.ZERO
var _calma_olha := Vector3.ZERO


## Um dos vigias vai para o farol morto, a frente do carro. Ninguem ve ele
## chegar: aparece no escuro do pisca.
func _plantar_no_farol() -> void:
	if _vigias.is_empty():
		return
	var c := _vigias[0]
	c.position = _calma_pos
	var para := _calma_olha - _calma_pos
	para.y = 0.0
	if para.length_squared() > 0.001:
		c.basis = Basis.looking_at(para.normalized(), Vector3.UP)
	_mostrar(c, _carro, ANDA_VIGIA)
	c.animar(0.0, 0.3)


func _bater() -> void:
	_bateu = true
	_marca("batida")
	var us := Time.get_ticks_usec()
	# O mato em volta do carro, amassado: sem isto o capim atravessa o piso.
	if _estrada != null:
		_estrada.abrir_clareira(_carro.global_position, CLAREIRA_RAIO)
	us = _custo_da_batida("clareira", us)
	_carro.velocidade = 0.0
	_carro.volante_cena = -0.2
	_carro.pancada(-2.4, 1.2)
	# A frente direita abraca a arvore: para-choque, quina do capo e capo.
	_carro.amassar_frente(1.0, 1.0)
	us = _custo_da_batida("amassar", us)
	_carro.desligar_motor()
	# O telefone solto no banco do carona segue em frente quando o carro para:
	# porta-luvas, vao dos pes, tapete.
	if _motorista != null:
		_motorista.cair_na_batida()
		# O aparelho batendo no porta-luvas, e depois no tapete, sem ninguem ver.
		var t_bate := MotoristaCena.QUEDA_ESCORREGA + MotoristaCena.QUEDA_BATE
		get_tree().create_timer(t_bate).timeout.connect(func() -> void:
			_som(&"apoio_banco", -13.0, 1.8))
		get_tree().create_timer(t_bate + MotoristaCena.QUEDA_CAI).timeout.connect(
			func() -> void: _som(&"apoio_banco", -16.0, 2.2))
	us = _custo_da_batida("celular", us)
	_escurecer_depois_da_batida()
	us = _custo_da_batida("escurecer", us)
	_trincar_por_dentro()
	us = _custo_da_batida("trincas", us)
	_som(&"batida_carro", 0.0)
	_som(&"vidro_trinca", -2.0)
	_som(&"motor_morre", -5.0)
	_tremor = 1.0
	_piscar_farol()
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if _luz_alerta != null and is_instance_valid(_luz_alerta):
			_luz_alerta.light_energy = LUZ_ALERTA_FORCA)
	get_tree().create_timer(CALMA_SURGE).timeout.connect(_plantar_no_farol)
	_pegar_fogo_no_motor()
	_custo_da_batida("resto", us)
	if _sonda_gpu_depois() >= 0.0:
		get_tree().create_timer(_sonda_gpu_depois()).timeout.connect(_sondar_gpu)


## --medir-quadros: quanto cada passo do quadro da batida custou (ms).
func _custo_da_batida(nome: String, desde: int) -> int:
	var agora := Time.get_ticks_usec()
	if _medir_quadros:
		print("[batida] %-10s %6.1f ms" % [nome, (agora - desde) / 1000.0])
	return agora


# --- o motor pegando fogo ---------------------------------------------------
## Onde o fogo mora, no espaco do carro: o cofre, um pouco para o lado do
## carona (foi a frente direita que abracou a arvore).
const INCENDIO_NO_CARRO := Vector3(0.15, 0.92, -1.62)
## A linha do tempo, em segundos depois da batida: o radiador chia e fumega, o
## tanque pinga, a gasolina escorre, e ela acha o escapamento quente. Cabe entre
## a batida e a janela (uns onze segundos).
const VAPOR_EM := 1.1
const PINGA_EM := 2.2
const ESCORRE_EM := 4.2
const FOGO_EM := 9.0
var _incendio: IncendioDoCapo


## O que so nasce na batida — a trinca, o incendio e os cubinhos do vidro —
## e criado aqui, no comeco do plano, apagado. Criar material novo compila o
## shader dele na CPU, no quadro em que ele nasce: era o pico de 390 ms no
## quadro da batida (`--medir-quadros`, parte "elenco").
var _shader_trinca: Shader
var _mat_estilhaco: StandardMaterial3D


## O que so aparece no susto, desenhado uma vez debaixo do preto do comeco, a
## uns metros da lente: o padre, um romeiro e um vigia (corpo, capuz, aura e a
## treva de volume), uma multidao de uma figura so, e os estilhacos. O primeiro
## desenho de cada material compila o pipeline dele no quadro em que aparece:
## era o quadro de 170 ms em que o padre e plantado (`--medir-quadros`, trecho
## "trava"). Ninguem ve: a cortina ainda esta fechada.
func _aquecer_na_lente() -> void:
	if _cam == null or _raiz == null:
		return
	# O celular aceso e o capo em chamas ficam DENTRO do quadro: a cortina tem
	# de estar fechada. No roteiro inteiro ela ja esta (o rasante escurece);
	# com `--estrada-desde=dentro` ela comecava aberta e os quatro quadros
	# apareciam.
	Cinema.fechar_de_imediato()
	# Abaixo do asfalto, oito metros a frente: dentro do quadro (e desenhado),
	# mas atras do chao (ninguem ve, nem depois que a cortina abre).
	var diante := _cam.global_transform * Vector3(0.0, -3.8, -8.0)
	var lado := _cam.global_basis.x
	var elenco: Array[Corpo] = []
	if _padre != null:
		elenco.append(_padre)
	if not _romeiros.is_empty():
		elenco.append(_romeiros[0])
	if not _vigias.is_empty():
		elenco.append(_vigias[0])
	for i in elenco.size():
		var c := elenco[i]
		c.global_position = diante + lado * (float(i) - 1.0) * 1.2
		c.visible = true
		var aura := c.get_meta(&"aura", null) as GPUParticles3D
		if aura != null:
			aura.emitting = true
	var multi := MultidaoEncapuzada.criar([{"pos": diante + lado * 2.4,
		"olha": _cam.global_position, "altura": 1.9}])
	_raiz.add_child(multi)
	multi.aparecer(true)
	var lugar_dos_estilhacos: Array[Vector3] = []
	for ps: GPUParticles3D in _estilhacos:
		lugar_dos_estilhacos.append(ps.position)
		ps.global_position = diante
		ps.restart()
		ps.emitting = true
	# As trincas da batida, com um fio de crescimento: desenhadas, e quase nada.
	for tr: TrincaDeVidro in _trincas_prontas:
		if tr != null:
			tr.visible = true
			tr.por_cresce(0.002)
	# O ar da multidao: nevoa rasteira e treva (volume de nevoa com material novo
	# compila o compute dele no primeiro quadro em que entra) e as duas revoadas,
	# que ficam prontas, apagadas: o material delas sai do cache do motor quando
	# o ultimo dono morre, e uma revoada de aquecimento jogada fora nao valia.
	var ar: Array[Node3D] = [_nuvem(NEVOA_RASTEIRA_CAIXA, Color(0.72, 0.75, 0.8),
		NEVOA_RASTEIRA, true), _nuvem(TREVA_NO_MATO_CAIXA, Color.BLACK, TREVA_NO_MATO)]
	for i in ar.size():
		_raiz.add_child(ar[i])
		ar[i].global_position = _cam.global_transform * Vector3(float(i) * 3.0, 0.0, -9.0)
	for i in 2:
		var r := _revoada(i)
		r.global_position = _cam.global_transform * Vector3(-3.0 - float(i) * 3.0, 0.0, -9.0)
		r.visible = true
		r.acender()
	# O aparelho aceso na mao, e todas as letras que a tela dele vai escrever.
	if _motorista != null:
		_motorista.aquecer_celular(true)
	# O capo pegando fogo: chama, brasa e fumaca.
	if _incendio != null:
		_incendio.aquecer(true)
	# Os do carro e o sangue no vidro, na frente da lente, onde `diante` cai.
	_cerco(&"aquecer", [true, diante])
	if _sangue_janela != null:
		_sangue_janela.aquecer(true, diante + lado * 1.2)
	if _olho_solto != null:
		_olho_solto.aquecer(true, diante - lado * 0.6)
	if _gore != null:
		_gore.aquecer(true, diante - lado * 1.0)
	for _i in 4:
		await get_tree().process_frame
	if _motorista != null:
		_motorista.aquecer_celular(false)
	if _incendio != null:
		_incendio.aquecer(false)
	_cerco(&"aquecer", [false, diante])
	if _sangue_janela != null:
		_sangue_janela.aquecer(false)
	if _olho_solto != null:
		_olho_solto.aquecer(false, diante)
	if _gore != null:
		_gore.aquecer(false, diante)
	for tr: TrincaDeVidro in _trincas_prontas:
		if tr != null:
			tr.por_cresce(0.0)
			tr.visible = false
	for c: Corpo in elenco:
		c.visible = false
		var aura := c.get_meta(&"aura", null) as GPUParticles3D
		if aura != null:
			aura.emitting = false
	multi.queue_free()
	for no: Node3D in ar:
		no.queue_free()
	for r: AuraNegra in _revoadas:
		r.emitting = false
		r.visible = false
	for i in _estilhacos.size():
		_estilhacos[i].position = lugar_dos_estilhacos[i]
		_estilhacos[i].visible = false


## As duas revoadas da multidao, criadas uma vez e guardadas apagadas.
var _revoadas: Array[AuraNegra] = []


func _revoada(i: int) -> AuraNegra:
	while _revoadas.size() <= i:
		var r := AuraNegra.revoada(REVOADA_CAIXA, REVOADA)
		r.visible = false
		_raiz.add_child(r)
		_revoadas.append(r)
	return _revoadas[i]


func _preaquecer_a_batida() -> void:
	_shader_trinca = load(TrincaDeVidro.SHADER) as Shader
	if _incendio == null and _carro != null:
		_incendio = IncendioDoCapo.new()
		_incendio.name = "Incendio"
		_carro.add_child(_incendio)
		_incendio.position = INCENDIO_NO_CARRO
	# Vidro, e nao acucar: quase transparente, verde de borda de vidro, e o
	# brilho somado inteiro (alfa pre-multiplicado) — o grao so aparece onde
	# pega luz. Com albedo claro e emissao ele era um cubo branco aceso.
	_mat_estilhaco = StandardMaterial3D.new()
	_mat_estilhaco.albedo_color = Color(0.4, 0.52, 0.5, 0.07)
	_mat_estilhaco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_estilhaco.blend_mode = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA
	_mat_estilhaco.metallic_specular = 0.6
	_mat_estilhaco.roughness = 0.06
	# Refrata o que esta atras: o grao se ve pelo desvio e pelo brilho, como
	# vidro, e nao pela cor.
	_mat_estilhaco.refraction_enabled = true
	_mat_estilhaco.refraction_scale = 0.04
	_preparar_estilhacos()
	_preparar_trincas()
	_preparar_sangue()


func _pegar_fogo_no_motor() -> void:
	if _carro == null:
		return
	if _incendio == null:
		_preaquecer_a_batida()
	await _esperar(VAPOR_EM)
	# O radiador rachado: chiado e o primeiro fio de fumaca clara no farol.
	_som_em_laco(&"vapor_chiado_loop", -30.0, -17.0, 1.5)
	_incendio.fumegar(0.4, 2.5)
	await _esperar(PINGA_EM - VAPOR_EM)
	_som_em_laco(&"gasolina_pinga_loop", -32.0, -13.0, 5.0)
	await _esperar(ESCORRE_EM - PINGA_EM)
	_som_em_laco(&"gasolina_escorre_loop", -34.0, -15.0, 3.0)
	_incendio.fumegar(0.75, 2.0)
	# O fogo pega quando a cena manda (`_fogo_pega_e_ele_olha`, com o telefone
	# ja na mao dele), e nunca depois de `FOGO_EM`.
	await _esperar(FOGO_EM - ESCORRE_EM)
	_fogo_pega()


func _fogo_pega() -> void:
	if _incendio == null or _incendio.fogo > 0.0:
		return
	# Pegou: o "vuf", a chama lambendo a borda do capo e a luz laranja dentro
	# da cabine, tremendo.
	var us := Time.get_ticks_usec()
	_som(&"fogo_pega", -7.0)
	_som_em_laco(&"fogo_loop", -26.0, -11.0, 5.0)
	_incendio.pegar_fogo(0.65, 2.5)
	_incendio.fumegar(1.0, 3.0)
	_custo_da_batida("fogo pega", us)
	_marca("fogo")
	await _esperar(4.0)
	_incendio.pegar_fogo(1.0, 4.0)


## O telefone acabou de subir: o "vuf" do fogo pegando, a luz laranja enche a
## cabine, e a cabeca da um tranco para o para-brisa — o capo pegando fogo
## atras do vidro trincado — antes de o aparelho vibrar e puxar o olho de volta.
const OLHA_O_FOGO := 1.25
const OLHA_O_FOGO_PESO := 0.8
const OLHA_O_FOGO_FOV := 52.0


func _fogo_pega_e_ele_olha() -> void:
	_fogo_pega()
	if _incendio == null:
		return
	var volta := _foco_de
	var peso := _foco_peso
	var fov := _fov_cena
	await _esperar(0.12)
	var fogo := _incendio
	_foco_de = func() -> Vector3: return fogo.global_position + Vector3.UP * 0.4
	_foco_peso = 0.0
	_animar(&"_foco_peso", OLHA_O_FOGO_PESO, 0.22, Tween.TRANS_EXPO)
	_animar(&"_fov_cena", OLHA_O_FOGO_FOV, 0.3, Tween.TRANS_SINE)
	await _esperar(OLHA_O_FOGO * 0.6)
	_foto("09f_fogo")
	await _esperar(OLHA_O_FOGO * 0.4)
	# Volta ao aparelho sem salto: larga o fogo, e so entao retoma a mira de
	# antes.
	_animar(&"_foco_peso", 0.0, 0.25, Tween.TRANS_SINE)
	_animar(&"_fov_cena", fov, 0.4, Tween.TRANS_SINE)
	await _esperar(0.25)
	_foco_de = volta
	_animar(&"_foco_peso", peso, 0.2, Tween.TRANS_SINE)


## Um som em laco, subindo de `de` a `ate` dB em `subida` segundos.
## Os lacos do incendio (vapor, gasolina, fogo): o branco corta todos.
var _lacos: Array[AudioStreamPlayer] = []


func _som_em_laco(nome: StringName, de: float, ate: float, subida: float) -> void:
	if _no_branco:
		return
	var st := AudioDirector.em_loop(nome)
	if st == null:
		push_warning("[susto] som ausente: %s" % nome)
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = de
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p)
	p.play()
	_lacos.append(p)
	AudioDirector.registrar(nome, ate, "laco")
	create_tween().tween_property(p, "volume_db", ate, subida) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## As trincas, vistas de dentro (`TrincaDeVidro`).
##
## O para-brisa leva a pancada do lado do carona, na altura do olho — onde a
## frente abracou a arvore e o galho bateu —, e trinca em teia que corre para
## os cantos em dois decimos de segundo e continua andando devagar depois, com
## o vidro assentando. A janela do carona estoura de canto: o galho que entrou
## pela quina de baixo da porta, e a teia sobe dali.
##
## A trinca antiga era um quadrado com um desenho parado colado no vidro: de
## perto, em 4K, lia como decalque — fio de largura constante, sem refracao,
## sem brilho, aparecendo inteira de uma vez.
const TRINCAS := [
	# tipo, lado, onde no vidro (fracao: x do canto 0 ao 1 — no para-brisa o 0 e o
	# lado do carona —, y da base ao topo), alcance,
	# quanto cresce na pancada, e ate onde cresce depois (em quantos segundos).
	[&"parabrisa", 0, Vector2(0.24, 0.5), 0.85, 0.7, 1.0, 3.5],
	[&"porta_frente", 1, Vector2(0.18, 0.12), 0.75, 0.55, 0.95, 5.0],
]
var _trincas: Array[TrincaDeVidro] = []


## As trincas da batida, montadas no preaquecimento e escondidas, uma por item
## de `TRINCAS` (null onde a abertura nao existe). Montar e desenhar a primeira
## no quadro da batida custava 28 ms de CPU ali (`--medir-quadros`, `[batida]`).
var _trincas_prontas: Array = []


func _preparar_trincas() -> void:
	if not _trincas_prontas.is_empty() or _carro == null or _carro.cabine == null:
		return
	var semente := 3.0
	for t: Array in TRINCAS:
		var a := _abertura(t[0], int(t[1]))
		var tr: TrincaDeVidro = null
		if not a.is_empty():
			var pts: PackedVector3Array = a["pontos"]
			# Os quatro cantos: 0 e 1 na base, 2 e 3 em cima (`AberturasVidro`).
			var f: Vector2 = t[2]
			var baixo := pts[0].lerp(pts[1], f.x)
			var cima := pts[3].lerp(pts[2], f.x)
			tr = TrincaDeVidro.na_abertura(a, baixo.lerp(cima, f.y), semente)
			if tr != null:
				_carro.cabine.add_child(tr)
				tr.ajustar(&"alcance", float(t[3]))
				tr.visible = false
		semente += 5.0
		_trincas_prontas.append(tr)


func _trincar_por_dentro() -> void:
	var cabine := _carro.cabine
	if cabine == null:
		return
	_preparar_trincas()
	for i in TRINCAS.size():
		var t: Array = TRINCAS[i]
		var tr: TrincaDeVidro = _trincas_prontas[i]
		if tr == null:
			continue
		tr.visible = true
		_trincas.append(tr)
		# Na pancada ela corre; depois o vidro assenta e ela anda devagar.
		var tw := create_tween()
		tw.tween_method(func(k: float) -> void: tr.por_cresce(k), 0.0, float(t[4]), 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_method(func(k: float) -> void: tr.por_cresce(k), float(t[4]), float(t[5]),
			float(t[6])).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		# Assentada, a trinca vira caminho para a agua que escorre no vidro.
		var tipo: StringName = t[0]
		var lado := int(t[1])
		tw.tween_callback(func() -> void: cabine.trinca_na_agua(tr, tipo, lado))


func _abertura(tipo: StringName, lado: int) -> Dictionary:
	for a: Dictionary in _carro.medidas().get("aberturas", []):
		if a["tipo"] == tipo and (tipo == &"parabrisa" or int(a["lado"]) == lado):
			return a
	return {}


## O farol pisca e volta fraco: 7,5 -> 0 -> 5 -> 0 -> 3,5.
func _piscar_farol() -> void:
	var f: Vector2 = FAROL_POR_CLIMA.get(_clima_id(), Vector2(8.0, 0.75))
	var passos := [[0.0, 0.06], [0.66, 0.05], [0.0, 0.08], [0.47, 0.0]]
	var t := create_tween()
	for p: Array in passos:
		var fr: float = p[0]
		t.tween_callback(func() -> void: _carro.ajustar_farol(f.x * fr, f.y * fr))
		t.tween_interval(maxf(0.01, float(p[1])))
	# E fica falhando: o farol da arvore morreu, o outro e mau contato.
	t.tween_callback(func() -> void: _carro.quebrar_farol(0.8))


# --- elenco -----------------------------------------------------------------

## As figuras da mata, em volta do ponto da batida: (s a partir da batida, folga,
## altura, tipo). Todas de capuz, como o padre: tipo 0 de pe, 1 curvado, 2
## crianca, 3 velho torto.
##
## O segundo numero nao e distancia do eixo: e a FOLGA, em metros, entre a
## figura e a lateral do carro quando ele passa por ali. As oito primeiras estao
## rente a trajetoria, como quem espera o carro chegar — um corredor de capuzes
## na beira da mata, que o farol vai varrendo. As outras seis estao fundas no
## mato: delas so se veem os olhos.
const FIGURAS := [
	[-15.0, 1.3, 1.82, 0], [-11.5, 2.4, 1.74, 1], [-8.5, 1.1, 1.88, 3],
	[-5.5, 1.9, 1.80, 0], [-5.1, 2.35, 1.12, 2],
	[-2.2, 1.4, 1.86, 0], [2.5, 0.9, 1.78, 3], [5.0, 2.2, 1.84, 0],
	[-13.0, 4.2, 1.82, 0], [-9.8, 5.6, 1.76, 1], [-6.8, 3.6, 1.90, 0],
	[-3.6, 4.9, 1.80, 3], [0.5, 3.5, 1.10, 2], [3.6, 4.7, 1.84, 0],
]
## Os que esperam na beira da estrada depois do padre, no fim do facho: (metros
## depois dele, lado). So os olhos passam da nevoa.
const VIGIAS := [[5.5, -4.4], [9.0, 4.8], [14.0, -5.6]]
## A batina: preto de pano velho, cada figura num tom um pouco diferente.
const BATINAS := [Color("1c1a18"), Color("211e1b"), Color("19181a"), Color("24201c"),
	Color("1e1b17")]
## Andando para o carro: rapidez (m/s) de cada grupo, e onde param.
const ANDA_VIGIA := 0.45
const ANDA_FIGURA := 0.3
const ANDA_FORA := 0.32
const PARA_DO_CARRO := 1.9
## Quanto quem pisca volta mais perto.
const PISCA_AVANCA := 0.35
## O padre: dois metros, ombro largo, corpo pesado. Os outros sao gente do
## tamanho de gente; ele nao.
const PADRE_ALTURA := 2.0
const PADRE_OMBRO := 0.56
const OMBRO_ENCAPUZADO := 0.45
## A aura negra: caixa em volta do corpo (escala pela altura) e baforadas.
const AURA_CAIXA := Vector3(1.0, 1.9, 1.0)
const AURA_PADRE := 64
const AURA_FIGURA := 30
## Os que esperam do lado de fora da janela do motorista, no espaco do carro
## (x para o lado do motorista e negativo): em meia-lua, de dois a seis metros.
const FORA_DA_JANELA := [Vector3(-3.1, 0.0, 1.3), Vector3(-4.5, 0.0, -1.5),
	Vector3(-2.7, 0.0, -3.3), Vector3(-6.0, 0.0, 0.3), Vector3(-5.2, 0.0, 3.1)]
## A pele das maos: cinza de cera. Com a pele sorteada, a luz vermelha da janela
## deixava a mao cor de salmao.
## Cinza-esverdeado de carne morta: a mao do corpo de longe, no farol, nao pode
## ler cor de gente.
const PELE_DE_CERA := Color("767a70")
## As maos que batem no vidro: a mesma cera, mais cinza e sem sangue. Com a de
## cera, sob o fogo e a luz vermelha do painel, elas saiam cor de pessego.
const PELE_DAS_MAOS := Color("6c6f68")
## O sorriso na janela: quanto tempo leva para abrir de todo, e o brilho dos
## olhos quando a lente chega nele.
const SORRISO_ABRE := 1.15
## O quanto a cabeca deita de lado enquanto o sorriso abre (rad).
const SORRISO_TOMBA := 0.62
const OLHOS_NA_JANELA := 3.2
## Atras do vidro embacado os olhos crescem, senao o desfoque do vidro os come.
const OLHOS_TAMANHO_NA_JANELA := 1.9

## A multidao (`MultidaoEncapuzada`): quantas figuras, de onde a onde da estrada
## (em metros a partir do padre), e de que distancia da pista ate onde.
const MULTIDAO := 440
const MULTIDAO_DE := -30.0
const MULTIDAO_ATE := 120.0
const MULTIDAO_PERTO := 3.6
const MULTIDAO_LONGE := 48.0
## Nenhum deles fica a menos disto um do outro, nem no caminho do carro: da
## freada ate a arvore o carro atravessa a pista e entra na mata pela direita.
const MULTIDAO_FOLGA := 1.3
const CORREDOR := Vector2(-3.0, 9.5)
## A nevoa rasteira (clara, acesa pelo farol) e as manchas de treva (pretas) no
## meio deles: densidade e tamanho de cada volume.
const NEVOA_RASTEIRA := 0.055
const NEVOA_RASTEIRA_CAIXA := Vector3(28.0, 2.4, 28.0)
const TREVA_NO_MATO := 0.5
const TREVA_NO_MATO_CAIXA := Vector3(7.5, 3.4, 7.5)
const TREVA_NO_CORPO := 0.85
## A revoada: fiapos de treva voando entre eles.
const REVOADA_CAIXA := Vector3(36.0, 2.8, 36.0)
const REVOADA := 120
## Um estalo de osso so se ouve de perto, e nunca dois no mesmo instante.
const ESTALO_ALCANCE := 28.0
const ESTALO_INTERVALO := 0.06
## A multidao estalando sozinha: so quem esta perto, e raro. Com os 440 do
## `MULTIDAO` passando pelo `TiqueMacabro` e so o intervalo de 0,06 s de
## freio, a cena tocava um osso a cada dois quadros, do padre plantado ate o
## branco — 170 estalos em 18 s, perto de 0 dB, medido com `--medir-sons`. De
## dentro do carro era um "PA PA PA" sem fim, e tirava o peso do estalo do
## padre, que e o que importa. O do roteiro (`roteiro` true) passa sempre.
const ESTALO_MULTIDAO_ALCANCE := 11.0
const ESTALO_MULTIDAO_INTERVALO := Vector2(1.1, 2.6)
const ESTALO_MULTIDAO_DB := -7.0
var _proximo_estalo_multidao: float = 0.0

## O ar das nuvens de treva e da nevoa rasteira: ruido 3D que anda com o tempo,
## esmaecendo na borda do volume. Preto absorve o farol; claro acende nele.
const NUVEM_SHADER := """
shader_type fog;

uniform float densidade = 0.5;
uniform vec3 cor : source_color = vec3(0.0);
uniform float escala = 0.32;
uniform vec3 corre = vec3(0.35, 0.06, 0.22);
uniform float rasteira = 0.0;

float h13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x),
			mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x),
			mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fog() {
	vec3 p = WORLD_POSITION * escala + corre * TIME;
	float n = ruido(p) * 0.55 + ruido(p * 2.1 + 7.3) * 0.3 + ruido(p * 4.3 - 2.1) * 0.15;
	float borda = clamp(-SDF / max(min(min(SIZE.x, SIZE.y), SIZE.z) * 0.35, 0.01), 0.0, 1.0);
	// A rasteira pesa no chao e afina para cima.
	float chao = mix(1.0, 1.0 - smoothstep(0.0, 1.0, UVW.y), rasteira);
	DENSITY = densidade * smoothstep(0.3, 0.72, n) * borda * chao;
	ALBEDO = cor;
}
"""

var _capuz_padre: CapuzMacabro
var _fumaca: FumacaNegra
var _capuzes: Array[CapuzMacabro] = []
var _vigias: Array[Corpo] = []
var _multidao: MultidaoEncapuzada
var _multidao_t: float = -1.0
## Para onde a multidao anda (no espaco da estrada): a arvore da batida.
var _alvo_multidao := Vector3.ZERO
var _t_ultimo_estalo: float = -10.0
static var _shader_nuvem: Shader


func _montar_elenco() -> void:
	if OS.get_cmdline_user_args().has("--sem-elenco"):
		return
	_padre = _encapuzado("Padre", 0, PADRE_ALTURA, 0, true)
	_padre.jeito = {"curvatura": 0.05, "cabeca": 0.14}
	_capuz_padre = _padre.get_meta(&"capuz") as CapuzMacabro
	for i in FIGURAS.size():
		var f: Array = FIGURAS[i]
		var c := _encapuzado("Romeiro%d" % i, i + 1, float(f[2]), int(f[3]))
		_romeiros.append(c)
		_capuzes.append(c.get_meta(&"capuz") as CapuzMacabro)
	for i in VIGIAS.size():
		_vigias.append(_encapuzado("Vigia%d" % i, 40 + i, 1.84 + 0.04 * float(i), 0))
	# A luz vermelha do painel, apagada ate o motor morrer, e o reflexo dela
	# que pega o rosto do lado de fora da janela.
	if _carro.cabine != null:
		_luz_alerta = OmniLight3D.new()
		_luz_alerta.name = "LuzAlerta"
		_luz_alerta.light_color = LUZ_ALERTA
		_luz_alerta.omni_range = 1.4
		_luz_alerta.light_energy = 0.0
		# Luz de dentro nao acende o ar: a nevoa volumetrica da cabine virava
		# uma nuvem vermelha na frente da lente.
		_luz_alerta.light_volumetric_fog_energy = 0.0
		_carro.cabine.add_child(_luz_alerta)
		_luz_alerta.position = _carro.cabine.olho() + Vector3(0.10, -0.36, -0.50)
	_luz_janela = OmniLight3D.new()
	_luz_janela.name = "LuzJanela"
	_luz_janela.light_color = LUZ_ALERTA.lerp(Color(1.0, 0.55, 0.4), 0.25)
	_luz_janela.omni_range = 1.2
	_luz_janela.light_energy = 0.0
	_luz_janela.light_volumetric_fog_energy = 0.0
	_carro.add_child(_luz_janela)
	_luz_janela.position = Vector3(-0.92, 0.86, -0.1)
	# Os que sobem no carro (`CercoNoCarro`).
	if ResourceLoader.exists(CERCO_NO_CARRO) and not OS.get_cmdline_user_args().has("--sem-cerco"):
		_cerco_carro = (load(CERCO_NO_CARRO) as GDScript).new() as Node
		_cerco_carro.name = "CercoNoCarro"
		_raiz.add_child(_cerco_carro)
		_cerco(&"montar", [self])


static func _lin(c: Color) -> Color:
	# O shader do corpo multiplica a cor crua: preto sRGB sairia caqui no farol.
	return c.srgb_to_linear()


## Um corpo de batina ate o chao, capuz (`CapuzMacabro`) e aura negra
## (`AuraNegra`), escondido. O capuz e a aura ficam nos metas `capuz` e `aura`.
func _encapuzado(nome: String, i: int, altura: float, tipo: int,
		grande: bool = false) -> Corpo:
	var c := Corpo.new()
	c.name = nome
	_raiz.add_child(c)
	var ombro := PADRE_OMBRO if grande else OMBRO_ENCAPUZADO
	c.montar(_aparencia_de_encapuzado(i, altura, ombro, grande))
	c.jeito = {"curvatura": [0.05, 0.16, 0.03, 0.22][tipo],
		"cabeca": [0.08, 0.20, 0.05, 0.26][tipo] + 0.02 * float(i % 3)}
	c.visible = false
	# O capuz, e debaixo dele o rosto (a criatura no padre, a faixa nos outros).
	MonstroDaEstrada.vestir(c, i, ombro / 0.42, grande)
	var aura := AuraNegra.criar(AURA_CAIXA * (altura / 1.9) * (1.25 if grande else 1.0),
		AURA_PADRE if grande else AURA_FIGURA, 1.1 if grande else 0.9)
	aura.emitting = false
	c.add_child(aura)
	# Mais para baixo que o meio: a fumaca sobe sozinha, e sem isto ela fazia
	# uma nuvem em cima da cabeca e deixava a batina limpa.
	aura.position = Vector3(0.0, altura * 0.42, 0.0)
	c.set_meta(&"aura", aura)
	# E o ar em volta dele, que come o farol: a treva de volume, alem da fumaca.
	var treva := _nuvem(Vector3(1.9, 2.7, 1.9) * (altura / 1.9) * (1.3 if grande else 1.0),
		Color.BLACK, TREVA_NO_CORPO)
	c.add_child(treva)
	treva.position = Vector3(0.0, altura * 0.5, 0.0)
	c.set_meta(&"tique", TiqueMacabro.new(c, i,
		TiqueMacabro.Modo.PADRE if grande else TiqueMacabro.Modo.FUNDO))
	return c


## Um volume de nevoa (preta ou clara) com o ar andando dentro.
func _nuvem(tamanho: Vector3, cor: Color, densidade: float, rasteira: bool = false) -> FogVolume:
	if _shader_nuvem == null:
		_shader_nuvem = Shader.new()
		_shader_nuvem.code = NUVEM_SHADER
	var v := FogVolume.new()
	v.name = "Treva" if cor.get_luminance() < 0.1 else "Nevoa"
	v.size = tamanho
	v.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX if rasteira \
		else RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var m := ShaderMaterial.new()
	m.shader = _shader_nuvem
	m.set_shader_parameter(&"densidade", densidade)
	m.set_shader_parameter(&"cor", cor)
	m.set_shader_parameter(&"rasteira", 1.0 if rasteira else 0.0)
	m.set_shader_parameter(&"escala", 0.22 if rasteira else 0.45)
	v.material = m
	return v


## Toca um osso estalando na cabeca de `c`, se ele esta perto da lente.
func _estalar(c: Corpo, forca: float, roteiro: bool = true) -> void:
	if _cam == null or _relogio_cena - _t_ultimo_estalo < ESTALO_INTERVALO:
		return
	var onde := c.global_position + Vector3.UP * c.altura_da_boca()
	var longe := onde.distance_to(_cam.global_position)
	if longe > ESTALO_ALCANCE:
		return
	if not roteiro:
		if longe > ESTALO_MULTIDAO_ALCANCE or _relogio_cena < _proximo_estalo_multidao:
			return
		_proximo_estalo_multidao = _relogio_cena + randf_range(
			ESTALO_MULTIDAO_INTERVALO.x, ESTALO_MULTIDAO_INTERVALO.y)
	var nome := StringName("estalo_osso_%d" % randi_range(1, 4))
	if forca > 0.85 and randf() < 0.3:
		nome = &"rangido_osso"
	var st := AudioDirector.stream(nome)
	if st == null:
		return
	_t_ultimo_estalo = _relogio_cena
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = lerpf(-9.0, 3.0, forca) + (0.0 if roteiro else ESTALO_MULTIDAO_DB)
	p.pitch_scale = randf_range(0.82, 1.18)
	p.unit_size = 2.5
	p.max_db = 5.0
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_raiz.add_child(p)
	p.global_position = onde
	p.play()
	p.finished.connect(p.queue_free)
	AudioDirector.registrar(nome, p.volume_db, "estalo")


## A multidao, a nevoa rasteira, as manchas de treva e a revoada, em volta do
## trecho em que o padre aparece e o carro bate. Chamado quando o padre e
## plantado: antes disso o lugar da batida nao existe.
func _espalhar_multidao(s_padre: float) -> void:
	if OS.get_cmdline_user_args().has("--sem-multidao"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 6660
	# Onde a batida vai ser, estimado daqui: o golpe e a PADRE_T0 metros dele,
	# e a guinada anda a media das duas velocidades por GUINADA_T segundos.
	var v0 := _carro.velocidade / 3.6
	var v1 := VEL_NA_BATIDA / 3.6
	var s_batida := s_padre - PADRE_T0 + (v0 + v1) * 0.5 * GUINADA_T
	_alvo_multidao = EstradaBuilder.ponto_em(s_batida) \
		+ EstradaBuilder.lado_em(s_batida) * GUINADA_LADO
	var figuras: Array = []
	var ocupado := {}
	var tentativas := 0
	while figuras.size() < MULTIDAO and tentativas < MULTIDAO * 8:
		tentativas += 1
		var s := rng.randf_range(s_padre + MULTIDAO_DE, s_padre + MULTIDAO_ATE)
		var lado := -1.0 if rng.randf() < 0.5 else 1.0
		var d := lado * lerpf(MULTIDAO_PERTO, MULTIDAO_LONGE, pow(rng.randf(), 1.5))
		# Depois da arvore a pista tambem e deles: o farol morto olha para ela.
		if s > s_batida + 10.0 and rng.randf() < 0.12:
			d = rng.randf_range(-2.6, 2.6)
		elif s > s_padre - PADRE_T0 - 6.0 and s < s_batida + 6.0 \
				and d > CORREDOR.x and d < CORREDOR.y:
			continue
		var p := EstradaBuilder.ponto_em(s) + EstradaBuilder.lado_em(s) * d
		p.y += EstradaBuilder.altura_lateral(d)
		if p.distance_to(_alvo_multidao) < 5.0:
			continue
		var celula := Vector2i(floori(p.x / MULTIDAO_FOLGA), floori(p.z / MULTIDAO_FOLGA))
		if ocupado.has(celula):
			continue
		ocupado[celula] = true
		var curvado := 0.0 if rng.randf() < 0.6 else rng.randf_range(0.2, 0.85)
		figuras.append({"pos": p, "olha": _alvo_multidao, "altura": rng.randf_range(1.72, 2.08),
			"rapidez": rng.randf_range(0.16, 0.42), "pisca": rng.randf() < 0.33,
			"curvado": curvado})
	var us := Time.get_ticks_usec()
	_multidao = MultidaoEncapuzada.criar(figuras)
	_raiz.add_child(_multidao)
	_multidao_t = 0.0
	_multidao.mirar(_raiz.global_transform * _alvo_multidao)
	# O ar: nevoa rasteira clara (o farol acende nela) e manchas de treva no
	# meio deles, que o farol nao atravessa.
	# Nenhuma caixa de nevoa rasteira cobre o lugar onde o carro para: dentro
	# da cabine ela acendia com a luz do telefone e virava um veu na lente.
	us = _custo_da_batida("multidao %d" % figuras.size(), us)
	var meia_caixa := NEVOA_RASTEIRA_CAIXA * 0.5 + Vector3.ONE * 3.0
	for s: float in [s_padre - 14.0, s_padre + 8.0, s_padre + 30.0, s_batida + 12.0]:
		for d: float in [0.0, -20.0, 20.0]:
			var onde := EstradaBuilder.ponto_em(s) + EstradaBuilder.lado_em(s) * d \
				+ Vector3.UP * (NEVOA_RASTEIRA_CAIXA.y * 0.5 - 0.3)
			var ate_o_carro := (_alvo_multidao - onde).abs()
			if ate_o_carro.x < meia_caixa.x and ate_o_carro.z < meia_caixa.z:
				continue
			var v := _nuvem(NEVOA_RASTEIRA_CAIXA, Color(0.72, 0.75, 0.8), NEVOA_RASTEIRA, true)
			_raiz.add_child(v)
			v.position = onde
	for k in 16:
		var s := rng.randf_range(s_padre - 6.0, s_batida + 30.0)
		var d := (-1.0 if k % 2 == 0 else 1.0) * rng.randf_range(4.5, 22.0)
		var v := _nuvem(TREVA_NO_MATO_CAIXA * rng.randf_range(0.8, 1.3), Color.BLACK, TREVA_NO_MATO)
		_raiz.add_child(v)
		v.position = EstradaBuilder.ponto_em(s) + EstradaBuilder.lado_em(s) * d \
			+ Vector3.UP * (EstradaBuilder.altura_lateral(d) + 1.2)
	us = _custo_da_batida("nuvens", us)
	# A revoada: onde ele esta, e onde o carro vai parar. As duas ja existem
	# (`_aquecer_na_lente`): criar aqui custava 19 ms neste quadro.
	var centros: Array[Vector3] = [EstradaBuilder.ponto_em(s_padre + 4.0), _alvo_multidao]
	for i in centros.size():
		var r := _revoada(i)
		r.position = centros[i] + Vector3.UP * 1.3
		r.visible = true
		_auras_na_fila.append(r)
	_custo_da_batida("revoada", us)


## A multidao anda para o carro, desde que apareceu.
func _andar_multidao(delta: float) -> void:
	if _multidao == null or _multidao_t < 0.0:
		return
	_multidao_t += delta
	_multidao.andar(_multidao_t)
	_multidao.mirar(_raiz.global_transform * _alvo_multidao)


## Mostra um encapuzado com a aura ja formada em volta. Dali em diante ele
## esta "em cena" (`_assombrar` cuida dele), e anda para `alvo` se houver.
func _mostrar(c: Corpo, alvo: Node3D = null, rapidez: float = 0.0) -> void:
	c.visible = true
	c.set_meta(&"em_cena", true)
	c.set_meta(&"alvo", alvo)
	c.set_meta(&"rapidez", rapidez)
	var aura := c.get_meta(&"aura", null) as AuraNegra
	if aura != null and not _auras_na_fila.has(aura):
		_auras_na_fila.append(aura)


## As auras a acender, uma por quadro. Acender roda o `preprocess` da aura
## inteira (3,2 s a 30 quadros: 96 passos de particula) num quadro so; o padre e
## os cinco da janela aparecendo juntos davam 576 passos e um quadro de 35 ms.
var _auras_na_fila: Array[AuraNegra] = []


func _acender_uma_aura() -> void:
	while not _auras_na_fila.is_empty():
		var aura: AuraNegra = _auras_na_fila.pop_front()
		if is_instance_valid(aura) and aura.is_visible_in_tree():
			aura.acender()
			return


func _esconder(c: Corpo) -> void:
	c.visible = false
	c.set_meta(&"em_cena", false)


## O que todo encapuzado em cena faz, quadro a quadro.
##
## O corpo: anda devagar para o carro (a batina arrasta, as pernas nao se veem)
## e para a um passo dele. Um em cada tres dos de fundo pisca: some por alguns
## quadros e volta um pouco mais perto.
##
## Por cima da pose, o `TiqueMacabro`: o pescoco estalando de lado, caindo,
## girando demais; os bracos subindo duros e dobrando ao contrario; o tremor
## que nunca para. Para ele valer, o corpo reescreve a pose inteira todo quadro
## (`dominado = false` derruba o cache): o tique multiplica por cima do que o
## corpo acabou de escrever, e nunca por cima dele mesmo. Cada estalo grande
## estala um osso no ouvido, se for perto.
func _assombrar(delta: float) -> void:
	_andar_multidao(delta)
	var todos: Array[Corpo] = []
	if _padre != null:
		todos.append(_padre)
	todos.append_array(_romeiros)
	todos.append_array(_vigias)
	var i := 0
	for c: Corpo in todos:
		i += 1
		if not c.get_meta(&"em_cena", false):
			continue
		# Quem esta no carro e do `CercoNoCarro`: ele anima.
		if c.get_meta(&"cerco", false):
			continue
		# Anda para o alvo, no chao em que esta, e para a um passo dele.
		var alvo := c.get_meta(&"alvo") as Node3D if c.has_meta(&"alvo") else null
		var rapidez: float = c.get_meta(&"rapidez", 0.0)
		var andando := 0.0
		if alvo != null and is_instance_valid(alvo) and rapidez > 0.0:
			var para := alvo.global_position - c.global_position
			para.y = 0.0
			if para.length() > PARA_DO_CARRO:
				c.global_position += para.normalized() * rapidez * delta
				c.global_basis = Basis.looking_at(para.normalized(), Vector3.UP)
				andando = rapidez
		# A piscada: os de fundo, um em cada tres.
		if c != _padre and i % 3 == 0:
			var t_pisca: float = c.get_meta(&"t_pisca", randf_range(0.3, 1.2)) - delta
			if c.visible and t_pisca <= 0.0:
				c.visible = false
				t_pisca = randf_range(0.05, 0.16)
			elif not c.visible and t_pisca <= 0.0:
				c.visible = true
				if alvo != null and is_instance_valid(alvo):
					var perto := alvo.global_position - c.global_position
					perto.y = 0.0
					if perto.length() > PARA_DO_CARRO + PISCA_AVANCA:
						c.global_position += perto.normalized() * PISCA_AVANCA
				t_pisca = randf_range(0.4, 1.6)
			c.set_meta(&"t_pisca", t_pisca)
		if c.visible:
			c.dominado = false
			c.animar(andando, delta)
			var tique := c.get_meta(&"tique") as TiqueMacabro if c.has_meta(&"tique") else null
			if tique != null:
				var estalo := tique.passo(delta)
				if estalo > 0.0:
					_estalar(c, estalo, c == _padre)
			if c == _padre and _cabecada != null:
				_cabecada.aplicar()


static func _aparencia_de_encapuzado(i: int, altura: float, ombro: float,
		grande: bool) -> Dictionary:
	var a := Aparencia.de_ficha({"id": 1077 + i * 37, "sexo": &"M", "idade": 60})
	var batina := _lin(BATINAS[i % BATINAS.size()])
	a["altura"] = altura
	a["ombro"] = ombro
	a["corpulencia"] = 1.28 if grande else 1.0
	a["gordura"] = 0.6 if grande else 0.1
	a["casaco"] = true
	a["casaco_tipo"] = Aparencia.CASACO_SOBRETUDO
	a["casaco_cor"] = batina
	a["camisa_estilo"] = Aparencia.CAMISA_GOLA_ALTA
	a["camisa_cor"] = batina
	a["calca_estilo"] = Aparencia.CALCA_SAIA_LONGA
	a["saia"] = false
	a["calca_cor"] = batina
	a["sapato_estilo"] = Aparencia.SAPATO_SOCIAL
	a["sapato_cor"] = _lin(Color("1a1612"))
	a["chapeu"] = false
	a["pele"] = PELE_DE_CERA
	a["calvo"] = true
	a["cabelo_comprimento"] = 0
	a["barba"] = 0
	return a


func _plantar_padre(s: float) -> void:
	var eixo := EstradaBuilder.ponto_em(s)
	var p := eixo + EstradaBuilder.lado_em(s) * PADRE_DESVIO
	p.y += KitEstrada.altura_da_pista(eixo, PADRE_DESVIO)
	_padre.position = p
	# De frente para o carro que vem: a frente do corpo (-Z) contra a estrada.
	_padre.basis = Basis.looking_at(-EstradaBuilder.direcao_em(s), Vector3.UP)
	_padre.agachado = false
	_mostrar(_padre)
	_padre.animar(0.0, 0.3)
	if _capuz_padre != null:
		_capuz_padre.sorriso = 0.0
		_capuz_padre.olhos = 1.0
	# Os outros, no fim do facho: parados na beira, olhando o carro vir.
	for i in _vigias.size():
		var v: Array = VIGIAS[i]
		var sv := s + float(v[0])
		var d := float(v[1])
		var pv := EstradaBuilder.ponto_em(sv) + EstradaBuilder.lado_em(sv) * d
		pv.y += EstradaBuilder.altura_lateral(absf(d))
		var c := _vigias[i]
		c.position = pv
		var para := EstradaBuilder.ponto_em(sv - 12.0) - pv
		para.y = 0.0
		c.basis = Basis.looking_at(para.normalized(), Vector3.UP)
		_mostrar(c, _carro, ANDA_VIGIA)
		c.animar(0.0, 0.3)
	# E atras deles, ate onde a nevoa deixa ver, os outros: centenas.
	_espalhar_multidao(s)


## O tique do encapuzado `c` (ver `TiqueMacabro`), ou null.
static func _tique_de(c: Corpo) -> TiqueMacabro:
	if c == null or not c.has_meta(&"tique"):
		return null
	return c.get_meta(&"tique") as TiqueMacabro


## O padre sai da estrada e vai para o lado de fora da porta do motorista:
## curvado, a mao no vidro, olhando para dentro.
func _padre_na_janela() -> void:
	if _padre.get_parent() != _carro:
		_padre.get_parent().remove_child(_padre)
		_carro.add_child(_padre)
	_padre.position = PADRE_NA_JANELA
	_padre.basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP)
	_padre.agachado = true
	_padre.inclinacao = Vector2(0.0, PADRE_JANELA_CURVA)
	# A mao nao: ele a poe no vidro quando a lente chega (`_padre_cabeceia`).
	_padre.agarrar = Vector3.INF
	_mostrar(_padre)
	# A treva de volume dele entraria pela porta: na janela, so a fumaca.
	for filho: Node in _padre.get_children():
		if filho is FogVolume:
			(filho as FogVolume).visible = false
	# Na janela o tique nao tira a cara do vidro, e a mao direita esta nele.
	var tique := _tique_de(_padre)
	if tique != null:
		tique.modo = TiqueMacabro.Modo.JANELA
	# O olhar vai por `olhar_lateral`, e nao `olhar_para`: este calcula os olhos
	# a 1,58 m fixos, e com ele curvado a conta manda a cabeca olhar o chao — a
	# lente via o topo da cabeca, um bloco claro sem rosto. Aqui o pitch e
	# negativo (para cima) e desfaz a curvatura do tronco: o rosto fica de
	# frente para dentro do carro.
	_padre.olhar_lateral(0.0, PADRE_JANELA_PITCH)
	for _i in 30:
		_padre.animar(0.0, 0.05)
	# E ele nao veio sozinho: em meia-lua na mata, do lado de fora, os outros.
	for i in mini(FORA_DA_JANELA.size(), _romeiros.size()):
		var c := _romeiros[i]
		if c.get_parent() != _carro:
			c.get_parent().remove_child(c)
			_carro.add_child(c)
		var onde: Vector3 = FORA_DA_JANELA[i]
		c.position = onde
		var para := Vector3(0.0, 0.0, onde.z * 0.3) - onde
		para.y = 0.0
		c.basis = Basis.looking_at(para.normalized(), Vector3.UP)
		_mostrar(c, _carro, ANDA_FORA)
		c.animar(0.0, 0.3)
		var capuz := c.get_meta(&"capuz") as CapuzMacabro
		if capuz != null:
			capuz.olhos = OLHOS_NA_JANELA * 0.8
			capuz.olhos_tamanho = OLHOS_TAMANHO_NA_JANELA * 1.3


func _rosto_do_padre() -> Vector3:
	var esq := _padre.esqueleto() if _padre != null else null
	if esq == null:
		return _padre.global_position + Vector3.UP * 1.55
	var cab := esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.CABECA)
	return cab.origin + cab.basis.y * 0.11


func _posicionar_romeiros(s_batida: float) -> void:
	var s0 := _carro.distancia
	for i in _romeiros.size():
		var f: Array = FIGURAS[i]
		var s := s_batida + float(f[0])
		# Onde o carro esta lateralmente quando passa por este `s`: o desvio da
		# guinada no instante em que ele chega ali (a velocidade cai linear,
		# entao o tempo sai de uma quadratica; a media e boa o bastante).
		var k := clampf((s - s0) / maxf(s_batida - s0, 1.0), 0.0, 1.0)
		var d := GUINADA_LADO * pow(k, GUINADA_CURVA) + 0.95 + float(f[1])
		var p := EstradaBuilder.ponto_em(s) + EstradaBuilder.lado_em(s) * d
		p.y += EstradaBuilder.altura_lateral(d)
		var c := _romeiros[i]
		c.position = p
		# Todos olham a estrada, para onde o carro vem.
		var para := EstradaBuilder.ponto_em(s - 3.0) - p
		para.y = 0.0
		if para.length_squared() > 0.001:
			c.basis = Basis.looking_at(para.normalized(), Vector3.UP)
		c.animar(0.0, 0.3)
	# A lente: do outro lado da pista, no bolsao de capim, olhando por cima do
	# carro para a borda da mata em que eles estao.
	var s_olho := s_batida - 3.0
	_romeiros_olho = EstradaBuilder.ponto_em(s_olho) \
		+ EstradaBuilder.lado_em(s_olho) * -MATA_LADO
	_romeiros_olho.y += EstradaBuilder.altura_lateral(MATA_LADO) + MATA_ALTURA
	var s_mira := s_batida + 2.0
	_romeiros_mira = EstradaBuilder.ponto_em(s_mira) + EstradaBuilder.lado_em(s_mira) * 8.0
	_romeiros_mira.y += EstradaBuilder.altura_lateral(8.0) + 1.1


func _romeiro_mais_perto() -> Corpo:
	var melhor: Corpo = null
	var dist := INF
	for r: Corpo in _romeiros:
		var d := r.global_position.distance_to(_cam.global_position)
		if d < dist:
			dist = d
			melhor = r
	return melhor


# --- utilidades do susto ----------------------------------------------------

## Anima uma variavel desta cena. Todas as da cabeca passam por aqui.
func _animar(prop: StringName, alvo: float, duracao: float,
		trans: Tween.TransitionType = Tween.TRANS_CUBIC) -> void:
	var t := create_tween()
	t.tween_property(self, NodePath(String(prop)), alvo, duracao) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(trans)


func _olhar_celular_para(alvo: float, duracao: float) -> void:
	if _tween_olhar != null and _tween_olhar.is_valid():
		_tween_olhar.kill()
	_tween_olhar = create_tween()
	_tween_olhar.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tween_olhar.tween_property(self, "_olhar_celular", alvo, duracao)


## Um som da cena, num tocador proprio no `SFX`: a piscina do AudioDirector tem
## seis vozes e descarta em silencio, e aqui cinco sons caem no mesmo quadro.
func _som(nome: StringName, volume_db: float, afinacao: float = 1.0) -> AudioStreamPlayer:
	var st := AudioDirector.stream(nome)
	if st == null:
		push_warning("[susto] som ausente: %s" % nome)
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = volume_db
	p.pitch_scale = afinacao
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	AudioDirector.registrar(nome, volume_db, "cena")
	return p


var _ambiente_db: float = 0.0
var _vacuo_ativo: bool = false
var _tween_vacuo: Tween

## O vacuo antes do golpe: a chuva e o vento somem em meio segundo. `false`
## devolve tudo de uma vez — o som voltando inteiro e metade do peso do golpe.
func _vacuo(ligar: bool) -> void:
	var i := AudioServer.get_bus_index(&"Ambiente")
	if i < 0:
		return
	if _tween_vacuo != null and _tween_vacuo.is_valid():
		_tween_vacuo.kill()
	if ligar and not _vacuo_ativo:
		_vacuo_ativo = true
		_ambiente_db = AudioServer.get_bus_volume_db(i)
		_tween_vacuo = create_tween()
		_tween_vacuo.tween_method(func(v: float) -> void:
			AudioServer.set_bus_volume_db(i, v), _ambiente_db, _ambiente_db - 20.0, 0.55)
	elif not ligar and _vacuo_ativo:
		_vacuo_ativo = false
		AudioServer.set_bus_volume_db(i, _ambiente_db)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_vacuo(false)


## Marca de tempo no log, para a bancada medir o ritmo do susto.
func _marca(nome: String) -> void:
	print("[susto] %-10s t=%.2f s=%.1f fisica=%d" % [nome, _relogio_cena,
		_carro.distancia if _carro != null else 0.0, Engine.get_physics_frames()])
	_fechar_trecho(nome)


# --- `--medir-quadros`: o custo de cada trecho da cena -----------------------
## Mede sem as capturas: `get_image` da rajada e das fotos trava o quadro e
## falsearia tudo. Por trecho (de uma marca a outra): quadros, media e pior
## tempo de quadro de verdade (relogio de parede), quantos passaram de 33 ms, e
## quanto disso foi script e fisica (a CPU). O resto e a GPU e o motor.
var _medir_quadros: bool = OS.get_cmdline_user_args().has("--medir-quadros")
var _mq_trecho: String = "inicio"
var _mq_antes: int = 0
var _mq: Dictionary = {}


## Soma o tempo desde `desde` na parte `nome` do trecho. Devolve o agora.
func _parte(nome: StringName, desde: int) -> int:
	var agora := Time.get_ticks_usec()
	if _medir_quadros:
		var partes: Dictionary = _mq_partes
		partes[nome] = float(partes.get(nome, 0.0)) + (agora - desde) / 1000.0
		var pior: Dictionary = _mq_partes_pior
		pior[nome] = maxf(float(pior.get(nome, 0.0)), (agora - desde) / 1000.0)
		_mq_quadro[nome] = float(_mq_quadro.get(nome, 0.0)) + (agora - desde) / 1000.0
	return agora


var _mq_partes: Dictionary = {}
var _mq_partes_pior: Dictionary = {}
## As partes do intervalo entre esta medida e a anterior: o que um pico custou.
var _mq_quadro: Dictionary = {}
## Acima disto (ms) o quadro sai no log como `[pico]`, com o que custou.
const PICO_MS := 20.0
var _mq_gpu_ligada: bool = false


## Os `_process` de todos os nos do quadro: um marco roda primeiro, outro por
## ultimo, e a diferenca e o tempo de script do quadro inteiro (so medindo).
class MarcoDoQuadro extends Node:
	static var _inicio := 0
	static var ultimo_ms := 0.0
	var fim := false

	func _process(_delta: float) -> void:
		if fim:
			ultimo_ms = (Time.get_ticks_usec() - _inicio) / 1000.0
		else:
			_inicio = Time.get_ticks_usec()


func _por_marcos() -> void:
	for fim in [false, true]:
		var m := MarcoDoQuadro.new()
		m.fim = fim
		m.process_priority = 100000 if fim else -100000
		m.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(m)


func _medir_quadro() -> void:
	if not _medir_quadros:
		return
	if _mq_antes == 0:
		_por_marcos()
	var agora := Time.get_ticks_usec()
	if _mq_antes > 0:
		var ms := (agora - _mq_antes) / 1000.0
		var cpu := (Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		# A GPU do quadro, medida pelo servidor: diz se o trecho e de placa.
		var vp := get_viewport().get_viewport_rid()
		if not _mq_gpu_ligada:
			RenderingServer.viewport_set_measure_render_time(vp, true)
			_mq_gpu_ligada = true
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		if _mq.is_empty():
			_mq = {"n": 0, "soma": 0.0, "pior": 0.0, "picos": 0, "cpu": 0.0, "cpu_pior": 0.0,
				"gpu": 0.0, "gpu_pior": 0.0}
		_mq["n"] += 1
		_mq["soma"] += ms
		_mq["pior"] = maxf(_mq["pior"], ms)
		_mq["cpu"] += cpu
		_mq["cpu_pior"] = maxf(_mq["cpu_pior"], cpu)
		_mq["gpu"] += gpu
		_mq["gpu_pior"] = maxf(_mq["gpu_pior"], gpu)
		if ms > 33.4:
			_mq["picos"] += 1
		if ms > PICO_MS:
			var linha := "[pico] t=%.2f %-9s %5.1f ms  cpu %5.1f  gpu %5.1f  fisica %4.1f  scripts %5.1f  render cpu %5.1f + %5.1f |" % [
				_relogio_cena, _mq_trecho, ms, cpu, gpu,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				MarcoDoQuadro.ultimo_ms, RenderingServer.get_frame_setup_time_cpu(),
				RenderingServer.viewport_get_measured_render_time_cpu(vp)]
			for nome: StringName in _mq_quadro:
				if float(_mq_quadro[nome]) >= 0.5:
					linha += " %s %.1f" % [nome, float(_mq_quadro[nome])]
			print(linha)
			_passos_do_pico = 4
		_somar_passos()
	_mq_quadro = {}
	_mq_antes = agora


## `--gpu-passos`: a GPU de cada passe do renderer (os carimbos que o proprio
## Forward+ grava a cada quadro), somada por trecho. Diz QUAL passe pesa sem
## precisar esconder nada.
var _mq_passos: bool = OS.get_cmdline_user_args().has("--gpu-passos")
var _mq_passo: Dictionary = {}
var _passos_do_pico := 0


func _somar_passos() -> void:
	if not _mq_passos:
		return
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		return
	var n := rd.get_captured_timestamps_count()
	# Nos quadros depois de um pico, os passes mais caros de cada um (o carimbo
	# e de um quadro de dois ou tres atras).
	if _passos_do_pico > 0:
		_passos_do_pico -= 1
		var caros: Array = []
		for i in n - 1:
			caros.append([(rd.get_captured_timestamp_gpu_time(i + 1)
				- rd.get_captured_timestamp_gpu_time(i)) / 1000000.0,
				rd.get_captured_timestamp_name(i)])
		caros.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var linha := "[pico]   quadro %d:" % rd.get_captured_timestamps_frame()
		for k in mini(6, caros.size()):
			linha += "  %s=%.2f" % [caros[k][1], caros[k][0]]
		print(linha)
	for i in n - 1:
		var nome := rd.get_captured_timestamp_name(i)
		var ns := float(rd.get_captured_timestamp_gpu_time(i + 1)
			- rd.get_captured_timestamp_gpu_time(i))
		_mq_passo[nome] = float(_mq_passo.get(nome, 0.0)) + ns / 1000000.0


func _fechar_trecho(proximo: String) -> void:
	if not _medir_quadros:
		return
	if not _mq.is_empty() and int(_mq["n"]) > 0:
		var n := float(_mq["n"])
		print("[quadros] %-10s n=%4d  media %6.1f ms  pior %6.1f ms  >33ms %3d  cpu media %5.1f pior %5.1f ms  gpu media %5.1f pior %5.1f ms  desenho %d  objetos %d  vram %.0f MB" % [
			_mq_trecho, int(n), _mq["soma"] / n, _mq["pior"], _mq["picos"],
			_mq["cpu"] / n, _mq["cpu_pior"], _mq["gpu"] / n, _mq["gpu_pior"],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	if not _mq_partes.is_empty() and not _mq.is_empty():
		var linha := "[quadros]   partes da cena (media/pior ms):"
		for nome: StringName in _mq_partes:
			linha += " %s %.2f/%.1f" % [nome, float(_mq_partes[nome]) / maxf(1.0,
				float(_mq.get("n", 1))), float(_mq_partes_pior.get(nome, 0.0))]
		print(linha)
	if not _mq_passo.is_empty() and not _mq.is_empty():
		var nomes: Array = _mq_passo.keys()
		nomes.sort_custom(func(a: String, b: String) -> bool:
			return float(_mq_passo[a]) > float(_mq_passo[b]))
		var linha := "[passos]   %s gpu por passe (media ms):" % _mq_trecho
		for k in mini(18, nomes.size()):
			linha += "  %s=%.2f" % [nomes[k], float(_mq_passo[nomes[k]]) / maxf(1.0,
				float(_mq.get("n", 1)))]
		print(linha)
	_mq_passo = {}
	_mq_partes = {}
	_mq_partes_pior = {}
	_mq = {}
	_mq_trecho = proximo


## Um quadro da rajada, se for a hora (so no plano de dentro).
func _rajada(delta: float) -> void:
	if _pasta_rajada.is_empty() or _plano != Plano.DENTRO:
		return
	_rajada_t -= delta
	if _rajada_t > 0.0:
		return
	_rajada_t = RAJADA_PASSO
	_gravar_rajada("r_%07.2f.png" % _relogio_cena)


## Le o quadro DEPOIS de desenhado: e o quadro que o jogador viu, e nao o
## anterior.
func _gravar_rajada(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _rajada_cheia and _rajada_n % RAJADA_CHEIA == 0:
		var pasta := _pasta_rajada.path_join("cheio")
		DirAccess.make_dir_recursive_absolute(pasta)
		img.save_png(pasta.path_join(nome))
	_rajada_n += 1
	img.resize(RAJADA_TAMANHO.x, RAJADA_TAMANHO.y, Image.INTERPOLATE_BILINEAR)
	img.save_png(_pasta_rajada.path_join(nome))
	if _vp_fora != null:
		var pasta_fora := _pasta_rajada.path_join("fora")
		DirAccess.make_dir_recursive_absolute(pasta_fora)
		_vp_fora.get_texture().get_image().save_png(pasta_fora.path_join(nome))


## `--rajada-fora`: cada quadro da rajada sai tambem de uma segunda lente, na
## quina da frente do banco do carona, alta, olhando para o console e o vao dos
## pes. De dentro da cabeca dele o banco do carona fica atras da lente no
## trecho do chao, e o braco atravessando o assento nao aparece na rajada.
var _rajada_fora: bool = OS.get_cmdline_user_args().has("--rajada-fora")
var _vp_fora: SubViewport
var _cam_fora: Camera3D


func _seguir_lente_de_fora() -> void:
	if not _rajada_fora or _carro == null or _carro.cabine == null:
		return
	if _vp_fora == null:
		_vp_fora = SubViewport.new()
		_vp_fora.name = "LenteDeFora"
		_vp_fora.size = Vector2i(960, 540)
		_vp_fora.world_3d = get_viewport().world_3d
		_vp_fora.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_vp_fora)
		_cam_fora = Camera3D.new()
		_cam_fora.fov = 80.0
		_cam_fora.near = 0.02
		_vp_fora.add_child(_cam_fora)
		_cam_fora.current = true
	var olho := _carro.cabine.olho()
	var piso := _carro.cabine.piso_da_cabine()
	var carona := -signf(olho.x) if absf(olho.x) > 0.01 else 1.0
	var de := Vector3(carona * 0.58, piso + 0.98, olho.z - 0.02)
	var para := Vector3(carona * 0.02, piso + 0.28, olho.z - 0.34)
	var cab := _carro.cabine.global_transform
	_cam_fora.global_transform = cab * Transform3D(Basis.looking_at(para - de, Vector3.UP), de)


## Grava o quadro corrente na pasta da bancada (`--susto-fotos=`). Fora da
## bancada nao faz nada. Nao se espera por ela: a cena segue no tempo dela.
func _foto(nome: String) -> void:
	if _pasta_fotos.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_pasta_fotos.path_join(nome + ".png"))


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
	_aplicar_mods(mods)


## O clima da cena com os ajustes de um plano por cima (ver `LUZ_POR_PLANO`).
func _aplicar_mods(mods: Dictionary) -> void:
	if _fog == null or not is_instance_valid(_fog):
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
	# A saida nao tem mais fala: a estrada termina dentro do carro (o susto).
	await _esperar(SAIDA_DURACAO - 1.2)
	# Emenda Estrada -> Praca: esconde o HUD no COMECO do fade-to-black.
	# Se sumir so no _desmontar (depois do preto), o LOCAL: ESTRADA VELHA
	# ainda pode piscar por um quadro na troca. A cortina e o unico ponto
	# de costura — cidade._rodar_abertura ja esta no preto quando chama Abertura.
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
	await Cinema.escurecer(0.8)


func _comecar(plano: Plano, duracao: float, trocar_luz: bool = true,
		manter_cabeca: bool = false) -> void:
	_plano = plano
	_t = 0.0
	_duracao = maxf(0.01, duracao)
	# A lente de dentro do carro nao molha: a chuva e do para-brisa.
	if _cam != null and is_instance_valid(_cam):
		_cam.set_meta(&"dentro_do_carro", plano == Plano.DENTRO)
	# No susto os cortes nao trocam a luz: trocar o preset reinicia a chuva, e
	# dois cortes num segundo seriam duas chuvas recomecando no quadro.
	if trocar_luz:
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
	if plano == Plano.DENTRO and not manter_cabeca:
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


# --- `--gpu-sem=a,b`: o que custa placa depois da batida --------------------
## Bancada do desempenho: esconde, da batida em diante, cada parte nomeada, e
## `--medir-quadros` diz quanto a GPU do trecho caiu. Partes: incendio,
## fumaca, trincas, corredoras, vidros, elenco, auras, luzes.
var _gpu_sem: PackedStringArray = PackedStringArray()


func _gpu_sem_aplicar() -> void:
	if _gpu_sem.is_empty():
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("--gpu-sem="):
				_gpu_sem = a.trim_prefix("--gpu-sem=").split(",")
		if _gpu_sem.is_empty():
			_gpu_sem = PackedStringArray(["-"])
	if _gpu_sem[0] == "-" or not _bateu:
		return
	for parte: String in _gpu_sem:
		match parte:
			"incendio":
				if _incendio != null:
					_incendio.visible = false
			"fumaca":
				# Pelas camadas: o setter de `cobre` reacende `visible` no tween.
				if _fumaca != null:
					_fumaca.layers = 0
			"trincas":
				for t: TrincaDeVidro in _trincas:
					t.visible = false
			"corredoras":
				if _carro.cabine._corredoras != null:
					_carro.cabine._corredoras.visible = false
			"vidros":
				var v := _carro.cabine.get_node_or_null("Vidros") as Node3D
				if v != null:
					v.visible = false
			"elenco":
				for c: Corpo in _romeiros + _vigias:
					c.visible = false
			"auras":
				for no: Node in _raiz.find_children("*", "GPUParticles3D", true, false):
					if no.get_parent() is Corpo:
						(no as GPUParticles3D).visible = false
			"luzes":
				for no: Node in _raiz.find_children("*", "Light3D", true, false):
					if not (no is DirectionalLight3D):
						(no as Light3D).visible = false


# --- `--sonda-gpu=S`: quem custa placa, objeto por objeto -------------------
## S segundos depois da batida a cena PARA (`Engine.time_scale` quase zero:
## lente, corpos, tweens e timers congelados; zero da NaN), e cada
## VisualInstance3D visivel e escondido sozinho por alguns quadros. O quanto a
## GPU do quadro cai e o custo dele. Imprime os maiores e fecha o jogo. Rode sem
## nenhuma captura.
func _sonda_gpu_depois() -> float:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sonda-gpu"):
			return float(a.trim_prefix("--sonda-gpu=")) if a.contains("=") else 2.0
	return -1.0


func _sondar_gpu() -> void:
	# Tempo parado, e nao arvore pausada: `_esperar` usa timers que correm na
	# pausa, e o roteiro seguia ate o branco no meio da sonda.
	Engine.time_scale = 0.0001
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var base := await _gpu_media(30)
	print("[sonda-gpu] %.2f s depois da batida: quadro %.2f ms de GPU" % [
		_sonda_gpu_depois(), base])
	_imprimir_passes()
	# Primeiro por grupo (o caminho ate o terceiro nivel: Cidade/MundoEstrada/
	# Carro, Cidade/Chunks/chunk_x...), e depois objeto por objeto dentro dos
	# grupos que custam. O menu e os retratos tem viewport proprio: ficam fora.
	var grupos: Dictionary = {}
	for no: Node in get_tree().root.find_children("*", "VisualInstance3D", true, false):
		var vi := no as VisualInstance3D
		if not vi.is_visible_in_tree() or vi.get_viewport() != get_viewport():
			continue
		var partes := str(vi.get_path()).trim_prefix("/root/").split("/")
		var chave := "/".join(partes.slice(0, mini(SONDA_GPU_NIVEL, partes.size() - 1)))
		if not grupos.has(chave):
			grupos[chave] = []
		(grupos[chave] as Array).append(vi)
	# Controle positivo: sem nada, a GPU tem de cair quase toda. Se nao cai, a
	# medida esta atrasada e o resto da lista nao vale.
	var tudo: Array = []
	for g: Array in grupos.values():
		tudo.append_array(g)
	var controle := await _custo_sem({"TUDO": tudo})
	print("[sonda-gpu] controle: sem os %d objetos, cai %.2f ms" % [tudo.size(),
		float(controle[0][0])])
	var custos := await _custo_sem(grupos)
	print("[sonda-gpu] %d grupos; os que mais custam:" % grupos.size())
	for i in mini(15, custos.size()):
		print("[sonda-gpu]   %6.2f ms  %4d objetos  %s" % [float(custos[i][0]),
			(grupos[custos[i][1]] as Array).size(), custos[i][1]])
	for i in mini(3, custos.size()):
		if float(custos[i][0]) < SONDA_GPU_PISO:
			break
		var um: Dictionary = {}
		for vi: VisualInstance3D in (grupos[custos[i][1]] as Array).slice(0, 150):
			um[str(vi.get_path()).trim_prefix("/root/")] = [vi]
		var dentro := await _custo_sem(um)
		print("[sonda-gpu] dentro de %s:" % custos[i][1])
		for j in mini(12, dentro.size()):
			var vi := (um[dentro[j][1]] as Array)[0] as VisualInstance3D
			print("[sonda-gpu]   %6.2f ms  %s  %s" % [float(dentro[j][0]), vi.get_class(),
				dentro[j][1]])
	get_tree().quit()


## Quanto nivel do caminho faz um grupo, e o custo abaixo do qual nao se abre.
const SONDA_GPU_NIVEL := 3
const SONDA_GPU_PISO := 0.3
## Quadros jogados fora antes de medir: a medida da GPU chega atrasada.
const SONDA_GPU_ATRASO := 6


## Esconde cada grupo sozinho e mede contra o antes e o depois (a linha de base
## anda). Devolve [custo ms, chave], do maior para o menor.
func _custo_sem(grupos: Dictionary) -> Array:
	var custos: Array = []
	for chave: String in grupos:
		var membros: Array = grupos[chave]
		var antes := await _gpu_media(5)
		# Pelas camadas, e nao por `visible`: a `FumacaNegra` se reacende no
		# setter de `cobre` a cada passo do tween.
		var camadas: Array[int] = []
		for vi: VisualInstance3D in membros:
			camadas.append(vi.layers)
			vi.layers = 0
		var sem := await _gpu_media(5)
		for m in membros.size():
			(membros[m] as VisualInstance3D).layers = camadas[m]
		var depois := await _gpu_media(5)
		custos.append([(antes + depois) * 0.5 - sem, chave])
	custos.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return custos


## Os passes do ultimo quadro com carimbo (so com `--gpu-profile` no motor).
func _imprimir_passes() -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null or rd.get_captured_timestamps_count() < 2:
		return
	var linha := "[sonda-gpu] passes:"
	for i in rd.get_captured_timestamps_count() - 1:
		var ms := (rd.get_captured_timestamp_gpu_time(i + 1)
			- rd.get_captured_timestamp_gpu_time(i)) / 1000000.0
		var nome := rd.get_captured_timestamp_name(i)
		# Os marcos de viewport e de grupo (">", "<", "vp_") dizem de quem e o passe.
		if ms >= 0.3 or nome.begins_with(">") or nome.begins_with("<") \
				or nome.contains("vp_") or nome.contains("Viewport"):
			linha += "  %s=%.2f" % [nome, ms]
	print(linha)


## A GPU media dos proximos `n` quadros do viewport, jogando fora os primeiros
## (`SONDA_GPU_ATRASO`: a medida chega com atraso de quadros).
func _gpu_media(n: int) -> float:
	var vp := get_viewport().get_viewport_rid()
	var soma := 0.0
	for i in n + SONDA_GPU_ATRASO:
		await RenderingServer.frame_post_draw
		if i >= SONDA_GPU_ATRASO:
			soma += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return soma / float(n)


# --- `--sonda-banco`: os bracos do susto contra os bancos -------------------
## Conta, a cada quadro depois da batida, os vertices de cada braco do motorista
## que estao dentro do assento e do encosto dos dois bancos da frente (caixas no
## espaco da cabine, do mesmo desenho de `CabineBancos`), e o mais fundo deles.
## Imprime so quando muda de estado ou fica mais fundo: e a regua do "braco
## atravessa o banco".
var _sonda_banco: bool = OS.get_cmdline_user_args().has("--sonda-banco")
var _sonda_pior: Dictionary = {}


func _caixas_dos_bancos() -> Dictionary:
	var cab := _carro.cabine
	var g: Dictionary = cab._medidas_do_interior()
	var bancos: Vector2 = g["bancos"]
	var piso: float = g["piso"]
	var olho: Vector3 = g["olho"]
	var meia := bancos.y * 0.5
	var out := {}
	for s: float in [-1.0, 1.0]:
		var nome := "carona" if signf(olho.x) != s else "motorista"
		var c := Vector3(s * bancos.x, piso, olho.z + CabineBancos.ASSENTO_Z)
		out[nome + "_assento"] = AABB(c + Vector3(-meia, 0.13, -0.235),
			Vector3(meia * 2.0, CabineBancos.TAMPO - 0.13, 0.47))
		out[nome + "_encosto"] = AABB(c + Vector3(-meia, 0.24, 0.17),
			Vector3(meia * 2.0, CabineBancos.ENCOSTO_ALTURA, 0.16))
	return out


func _sondar_banco() -> void:
	if not _sonda_banco or not _bateu or _motorista == null or _no_branco:
		return
	var caixas := _caixas_dos_bancos()
	for b: BracoVivo in [_motorista._braco_d, _motorista._braco_e]:
		if b == null or not b.visible or b.mesh == null or b.mesh.get_surface_count() == 0:
			continue
		var xf := _carro.cabine.global_transform.affine_inverse() * b.global_transform
		var vs: PackedVector3Array = b.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for nome: String in caixas:
			var cx: AABB = caixas[nome]
			var n := 0
			var fundo := 0.0
			var onde := Vector3.ZERO
			for v in vs:
				var p := xf * v
				if not cx.has_point(p):
					continue
				n += 1
				var d := minf(minf(minf(p.x - cx.position.x, cx.end.x - p.x),
					minf(p.y - cx.position.y, cx.end.y - p.y)),
					minf(p.z - cx.position.z, cx.end.z - p.z))
				if d > fundo:
					fundo = d
					onde = p
			var chave := "%s/%s" % [b.name, nome]
			var antes: float = _sonda_pior.get(chave, -1.0)
			if n > 0 and fundo > antes + 0.005:
				_sonda_pior[chave] = fundo
				print("[sonda-banco] t=%.2f %s dentro=%d fundo=%.1f cm em %s (direita=%s esquerda=%s)" % [
					_relogio_cena, chave, n, fundo * 100.0, onde,
					_motorista._direita_em, _motorista._esquerda_em])


# --- camera -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _carro == null or not is_instance_valid(_carro):
		return
	var us := Time.get_ticks_usec()
	_guiar_a_guinada(delta)
	us = _parte(&"elenco", us)
	_carro.avancar(delta)
	us = _parte(&"carro", us)
	_tremor = move_toward(_tremor, 0.0, delta * 1.4)
	_t += delta
	_delta_quadro = delta
	_relogio_cena += delta
	_medir_quadro()
	_rajada(delta)
	_sondar_banco()
	_bater_em_volta(delta)
	_acender_uma_aura()
	_gpu_sem_aplicar()
	us = Time.get_ticks_usec()
	_atualizar_trovoada()
	_atualizar_agua()
	_iluminar_fumaca()
	us = _parte(&"agua", us)
	if _cabecada != null and _maos_padre.size() == 2 and _carro.cabine != null:
		var om := _ombros_do_padre(_carro.cabine)
		if om.size() == 2:
			_maos_padre[0].ombro = om[0]
			_maos_padre[1].ombro = om[1]
	for b: BracoVivo in _maos_padre:
		if b.visible:
			b.passo(delta)
	if _motorista != null:
		_motorista.atualizar(_carro.acel_local, _carro.inclinacao(), delta)
		_motorista.debruca_olho = DEBRUCA * _debruca
	us = _parte(&"bracos", us)
	if _plano == Plano.MATA:
		_seguir_com_a_cabeca(delta)
	_mover_camera(clampf(_t / _duracao, 0.0, 1.0))
	_seguir_lente_de_fora()
	_parte(&"camera", us)
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
		Plano.ROMEIROS:
			# A mesma cabeca do plano da mata — o bicho era gente —, sem giro:
			# fixa, respirando, com a chuva entre ela e eles.
			var sobe_r := sin(_t * TAU * MATA_FOLEGO * 1.6)
			var de_r := _romeiros_olho + Vector3.UP * (sobe_r * MATA_FOLEGO_SOBE)
			_enquadrar(de_r, _romeiros_mira, ROMEIROS_FOV,
				deg_to_rad(MATA_ROLAR) * sin(_t * 2.1))
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
		- pose.basis.x * (curva * CORPO_NA_CURVA) \
		+ pose.basis * (DEBRUCA * _debruca + ERGUE * _ergue)
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
	# O que a cena puxa por cima: o padre na estrada, o celular no chao, a
	# janela. Mesma interpolacao de base do celular na mao.
	if _foco_peso > 0.001 and _foco_de.is_valid():
		var ponto: Vector3 = _foco_de.call()
		if origem.distance_squared_to(ponto) > 0.0001:
			var para_foco := Transform3D(Basis(), origem).looking_at(ponto, pose.basis.y).basis
			base = base.slerp(para_foco, clampf(_foco_peso, 0.0, 1.0))
	# O relance: um olho que escapa para outro ponto e volta (`relance`).
	if _relance_peso > 0.001 and _relance_de.is_valid():
		var ponto_r: Vector3 = _relance_de.call()
		if ponto_r.is_finite() and origem.distance_squared_to(ponto_r) > 0.0001:
			var para_r := Transform3D(Basis(), origem).looking_at(ponto_r, pose.basis.y).basis
			base = base.slerp(para_r, clampf(_relance_peso, 0.0, 1.0))
	if _tremor > 0.001:
		# Tres senos sem razao inteira: tremor que nao vira vibrador.
		var a := _tremor * _tremor * 0.045
		base = base * Basis.from_euler(Vector3(sin(_t * 53.0) * a,
			sin(_t * 47.0 + 1.3) * a, sin(_t * 61.0 + 2.1) * a * 0.6))
	if _ofego > 0.001:
		# O peito subindo e descendo rapido, e a cabeca indo junto: puxar o ar
		# levanta, soltar derruba. O cabeceio vai depois da mira, para a lente
		# nao corrigir o que a respiracao desloca.
		var o := sin(_t * TAU * OFEGO_HZ)
		var solavanco := absf(sin(_t * TAU * OFEGO_HZ * 0.5 + 0.7))
		origem += pose.basis.y * (o * OFEGO_ALTURA * _ofego)
		base = base * Basis.from_euler(Vector3(deg_to_rad(OFEGO_GRAUS) * o * _ofego,
			0.0, deg_to_rad(OFEGO_GRAUS) * 0.4 * (solavanco - 0.5) * _ofego))
	if _recua > 0.001:
		# Ele se encolhe para longe da janela a cada batida, a cabeca torcendo
		# um nada para o outro lado.
		origem += pose.basis.x * RECUA_METROS * _recua - pose.basis.y * 0.012 * _recua
		base = base * Basis.from_euler(Vector3(0.0, 0.0, -0.05 * _recua))
	if _puxao > 0.001:
		# Arrancado para a janela do motorista, e a cabeca vai torta.
		origem += -pose.basis.x * PUXAO_METROS * _puxao + pose.basis.y * 0.05 * _puxao
		base = base * Basis.from_euler(Vector3(-0.18 * _puxao, 0.0, 0.3 * _puxao))
	_cam.fov = (_fov_cena if _fov_cena > 1.0 else DENTRO_FOV) - _soco
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
	# A bancada roda o mesmo clima da abertura de verdade: a noite de chuva, com
	# relampago. Noite seca e so pedindo por --estrada-clima=noite.
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
		_olhar_celular = OLHAR_LEITURA
		_fov_cena = LEITURA_FOV
		if _motorista != null:
			var app := AppMensagens.new()
			app.preparar(FALAS["grupo"], CONVERSA_DO_GRUPO, FALAS["grupo_hora"],
				FALAS["desculpa"])
			_motorista.ligar_tela(app)
			_motorista.mostrar_celular(true)
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

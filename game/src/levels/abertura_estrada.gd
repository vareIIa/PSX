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
	# contato sem nome, e a mesma frase cinco vezes.
	"desconhecido": "?",
	"desconhecido_hora": "Agora",
	"bem_vindo": "Bem vindo",
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
## Onde o polegar para: "Gente, não vou" tem catorze letras. O resto da desculpa
## some; isto fica no campo, e e isto que o dedo manda sem querer no banco.
const TRAVA_LETRAS := 14
## Quanto a frente do carro o padre e plantado quando o polegar trava, e a que
## distancia dele vem o golpe. A 68 km/h os 21 m entre os dois sao 1,1 s: o
## tempo de ler as catorze letras e de ver ele crescer no farol ANTES de o
## personagem ver — o publico sabe primeiro.
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
## Onde a lente mira na tela caida: o balao azul e o "Entregue" embaixo dele.
const ASSOALHO_MIRA := Vector2(0.5, 0.55)
## Quanto a mira puxa para a mao que chega (0 o telefone, 1 a mao).
const ASSOALHO_PUXA_MAO := 0.22
## A leitura: a lente entra no campo de texto enquanto ele apaga.
const APAGAR_FOV := 19.0
const APAGAR_MIRA := Vector2(0.5, 0.58)
const ASSOALHO_ZOOM := 2.5
## A pegada no chao e a subida do aparelho ate o rosto (s).
const PEGAR_TEMPO := 0.42
const PEGAR_FOV := 36.0
const ERGUER_TEMPO := 1.15
## As mensagens do "?": quantas, o intervalo depois de cada uma (acelera, como
## quem manda segurando o botao), o campo na leitura delas e quanto ele fecha a
## cada uma (graus).
const BEM_VINDO_VEZES := 5
const BEM_VINDO_INTERVALO := [0.75, 0.6, 0.45, 0.32, 0.25]
const MENSAGENS_FOV := 34.0
const MENSAGENS_APERTA := 2.2
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
var _romeiros_olho := Vector3.ZERO
var _romeiros_mira := Vector3.ZERO
var _luz_alerta: OmniLight3D
var _luz_janela: OmniLight3D
var _tocadores: Array[AudioStreamPlayer] = []
## Pasta de fotos da bancada (`--susto-fotos=`): cada beat do susto grava um
## quadro. Vazio fora da bancada.
var _pasta_fotos: String = ""

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
##      (a mata vazia; o celular vibra no banco; o dedo encosta e a mensagem VAI)
##   3  a janela             o trinco da porta, o padre curvado no vidro, e o branco
##
## A mensagem que sai sem querer — "Gente, nao vou", Entregue — e o fio que a
## cidade puxa depois: ele veio, e o grupo leu que ele nao vinha.
func _plano_dentro() -> void:
	_branco = BrancoDoSusto.new()
	_cena.add_child(_branco)
	_montar_fumaca()
	# O farol de verdade: sombra do padre no barro, facho aceso na chuva.
	_carro.farol_de_verdade(true)
	_comecar(Plano.DENTRO, 60.0)
	await Cinema.clarear(0.7)
	Cinema.legenda(FALAS["dentro_1"], 4.2)
	await _esperar(4.6)
	# O olhar vai um pouco antes da mao: a decisao de olhar e o que faz a mao
	# subir, e nao o contrario.
	#
	# Um celular so: o da mao dele. A conversa e desenhada na tela do aparelho
	# 3D (`TelaDoCelular`), e a lente fecha nele o bastante para ler — com a
	# estrada ainda aparecendo por cima.
	var app := AppMensagens.new()
	app.preparar(FALAS["grupo"], CONVERSA_DO_GRUPO, FALAS["grupo_hora"], FALAS["desculpa"])
	if _motorista != null:
		_motorista.ligar_tela(app)
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

	# O polegar. Apaga ate sobrar "Gente, nao vou" — e para. A lente vai
	# entrando no campo de texto junto com o apagar: no fim so cabem a pergunta
	# do Lucas e o que sobrou da desculpa.
	app.apagar_ate(TRAVA_LETRAS)
	if _motorista != null:
		# O polegar no apagar, batendo.
		_motorista.digitando = 1.0
		_foco_de = func() -> Vector3: return _motorista.ponto_da_tela(APAGAR_MIRA)
		_animar(&"_foco_peso", 0.85, 0.9)
	_animar(&"_fov_cena", APAGAR_FOV, 1.5, Tween.TRANS_SINE)
	var espera := 0.0
	while app.letras() > TRAVA_LETRAS and espera < 5.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	var s_padre := _carro.distancia + PADRE_ADIANTE
	if _motorista != null:
		_motorista.digitando = 0.0
	_plantar_padre(s_padre)
	_marca("trava")
	_foto("02_trava")
	await _esperar(0.3)
	# O olho sobe um pouco do aparelho, e o aparelho fica: embaixo do quadro, o
	# "Gente, nao vou" com o cursor piscando; em cima, pelo para-brisa, a
	# estrada — e o padre saindo da nevoa no facho. O publico ve antes dele.
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
	await _esperar(0.22)
	_foto("07_batida")
	await _esperar(0.3)

	# --- a calma falsa: a mata VAZIA no farol fraco, o limpador marcando o
	# tempo, e a respiracao dele.
	var folego := _som(&"ofegante", -8.0)
	await _esperar(0.5)
	_foto("08_calma")
	await _esperar(0.5)

	# --- o banco: o telefone vibra, a cabeca vai, a mao vai. O do farol some
	# enquanto ninguem olha.
	for v: Corpo in _vigias:
		_esconder(v)
	if _motorista != null:
		_motorista.vibrar_celular(0.9)
	_som(&"vibra_banco", -7.0)
	_foco_de = func() -> Vector3: return _motorista.ponto_do_celular()
	_animar(&"_foco_peso", 1.0, 0.35)
	_fov_cena = DENTRO_FOV
	_animar(&"_fov_cena", ALCANCE_FOV, 0.5, Tween.TRANS_SINE)
	await _esperar(0.45)
	# Ele se joga para o banco do carona contra o cinto: a esquerda larga o aro
	# e agarra o assento, a direita sai do colo e vai ao telefone.
	_animar(&"_debruca", 0.45, 0.5)
	if _motorista != null:
		_motorista.medo = 1.0
		await _motorista.alcancar_celular(0.55)
	_foto("08b_alcance")
	# O dedo encosta no ENVIAR. O som que todo mundo conhece, no carro calado, e
	# o balao azul sobe na tela do aparelho.
	if _motorista != null:
		await _motorista.tocar_tela(0.14)
	app.enviar("Entregue")
	app.sem_teclado = true
	_som(&"mensagem_enviada", -5.0)
	_marca("enviou")
	# O telefone escorrega do banco e a mao vai atras dele. A esquerda larga o
	# aro e espalma no assento do carona: e o apoio do corpo que vai ao chao.
	if _motorista != null:
		_motorista.derrubar_celular(0.38)
		_motorista.seguir_ao_chao(0.85)
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
	# No chao a tela aproxima o pe da conversa: o balao azul e o "Entregue"
	# tem de ser lidos a meio metro.
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
	_foto("09c_na_mao")
	if arfando != null and is_instance_valid(arfando):
		var t_ar := create_tween()
		t_ar.tween_property(arfando, "volume_db", -14.0, 1.2)

	# --- "?": a conversa troca sozinha. Um contato sem nome, e cinco vezes a
	# mesma coisa, cada uma com o aparelho vibrando na mao.
	var app_q := AppMensagens.new()
	app_q.preparar(FALAS["desconhecido"], [], FALAS["desconhecido_hora"], "")
	app_q.sem_teclado = true
	app_q.tique = false
	if _motorista != null:
		_motorista.ligar_tela(app_q)
	# O padre vai para a janela agora, atras da cabeca dele.
	_padre_na_janela()
	await _esperar(0.35)
	for i in BEM_VINDO_VEZES:
		app_q.receber(FALAS["desconhecido"], FALAS["bem_vindo"])
		_som(&"mensagem_recebida", -7.0 + float(i) * 0.8, 1.0 - float(i) * 0.012)
		_som(&"vibra_banco", -12.0)
		if _motorista != null:
			_motorista.vibrar_na_mao(0.3)
		# A lente vai chegando a cada mensagem, nos baloes dele.
		_animar(&"_fov_cena", MENSAGENS_FOV - float(i + 1) * MENSAGENS_APERTA, 0.4,
			Tween.TRANS_SINE)
		if i == 0 and _motorista != null:
			_foco_de = func() -> Vector3: return _motorista.ponto_da_tela(MENSAGENS_MIRA)
		if i == 2:
			_foto("09d_bem_vindo")
		await _esperar(BEM_VINDO_INTERVALO[i])
	_foto("09e_cinco")
	await _esperar(0.6)

	# --- o trinco: o som vem antes da imagem, puxado duas vezes.
	_som(&"porta_trinco", -1.0)
	await _esperar(0.22)
	_som(&"porta_trinco", -3.0, 0.93)
	await _esperar(0.08)
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

	# --- a janela. Ele ja estava la quando a cabeca chegou: o buraco preto do
	# capuz, os dois pontos acendendo, e o sorriso abrindo devagar — mais do
	# que uma boca abre. A lente vai chegando junto, sem ninguem mandar.
	_marca("janela")
	_foto("10_janela")
	if _capuz_padre != null:
		_capuz_padre.sorriso = 0.0
		var t_riso := create_tween().set_parallel(true)
		_capuz_padre.olhos_tamanho = OLHOS_TAMANHO_NA_JANELA
		t_riso.tween_property(_capuz_padre, "olhos", OLHOS_NA_JANELA, 0.25)
		t_riso.tween_property(_capuz_padre, "sorriso", 1.0, SORRISO_ABRE) \
			.set_delay(0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	# Enquanto a boca abre, a cabeca deita devagar para o lado, tremendo — e so
	# ela se mexe devagar na cena inteira.
	var tique := _tique_de(_padre)
	if tique != null:
		tique.fixar_cabeca(Vector3(0.05, 0.0, SORRISO_TOMBA), 0.25 + SORRISO_ABRE)
	_som(&"sorriso_abre", -4.0)
	_animar(&"_fov_cena", 40.0, 0.25 + SORRISO_ABRE, Tween.TRANS_SINE)
	await _esperar(0.25 + SORRISO_ABRE * 0.6)
	_foto("10b_sorriso")
	await _esperar(SORRISO_ABRE * 0.4)
	# O bote contra o vidro: o pescoco estala para o outro lado no mesmo quadro.
	if tique != null:
		tique.soltar_cabeca()
		_estalar(_padre, tique.estalar_cabeca(Vector3(-0.1, 0.0, -SORRISO_TOMBA * 1.6)))
	var t_bote := create_tween()
	t_bote.tween_property(_padre, "position", _padre.position + Vector3(0.07, 0.01, 0.0), 0.09)
	t_bote.tween_property(_padre, "position", _padre.position + Vector3(0.14, 0.02, 0.0), 0.08)
	await _esperar(0.12)

	# --- GOLPE 3: tapa no vidro, estouro, branco. Tudo no mesmo quadro.
	_marca("branco")
	if _fumaca != null:
		_fumaca.cobre = 0.0
	_branco.tocar(&"tapa_vidro", 0.0)
	_branco.tocar(&"susto_golpe", -2.0)
	_branco.estourar()
	_foto("11_branco")
	await _esperar(2.6)


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
	# O mato em volta do carro, amassado: sem isto o capim atravessa o piso.
	if _estrada != null:
		_estrada.abrir_clareira(_carro.global_position, CLAREIRA_RAIO)
	_carro.velocidade = 0.0
	_carro.volante_cena = -0.2
	_carro.pancada(-2.4, 1.2)
	_carro.desligar_motor()
	_escurecer_depois_da_batida()
	_trincar_por_dentro()
	_som(&"batida_carro", 0.0)
	_som(&"vidro_trinca", -2.0)
	_som(&"motor_morre", -5.0)
	_tremor = 1.0
	_piscar_farol()
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if _luz_alerta != null and is_instance_valid(_luz_alerta):
			_luz_alerta.light_energy = LUZ_ALERTA_FORCA)
	get_tree().create_timer(CALMA_SURGE).timeout.connect(_plantar_no_farol)


## A trinca do para-brisa, vista de dentro.
##
## O vidro da cabine (`psx_vidro_agua`) nao sabe trincar, e o da lataria, que
## sabe, fica escondido com a cabine ligada. Em vez de mexer num shader que e
## de outra frente, a trinca e uma lamina propria colada um centimetro para
## dentro do vidro, na frente do banco do carona: onde o nariz bateu.
const TRINCA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float forca : hint_range(0.0, 1.0) = 0.0;
float h(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.6, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 27.0;
	float setor = floor((a + PI) / TAU * n);
	float eixo = (setor + 0.5 + (h(setor) - 0.5) * 0.7) / n * TAU - PI;
	float torto = sin(r * 55.0 + setor * 3.1) * 0.006 + sin(r * 17.0 + setor) * 0.01;
	float fio = smoothstep(0.0035, 0.0, abs((a - eixo) * r + torto))
		* step(r, 0.12 + h(setor + 7.0) * 0.40) * step(0.012, r);
	float anel = 0.0;
	for (int i = 0; i < 4; i++) {
		float rr = 0.04 + float(i) * 0.055 + h(setor + float(i) * 5.0) * 0.02;
		anel = max(anel, smoothstep(0.0028, 0.0, abs(r - rr)) * step(h(setor * 3.0 + float(i)), 0.62));
	}
	float teia = smoothstep(0.035, 0.0, r);
	float v = max(max(fio, anel * 0.85), teia * 0.9) * forca;
	ALBEDO = vec3(0.78, 0.82, 0.86);
	ALPHA = clamp(v * 0.8, 0.0, 1.0);
}
"""


func _trincar_por_dentro() -> void:
	var cabine := _carro.cabine
	if cabine == null:
		return
	var olho := cabine.olho()
	var y := olho.y - 0.06
	var centro := Vector3(-olho.x * 0.55, y, cabine.z_do_vidro(y) + 0.012)
	var mi := MeshInstance3D.new()
	mi.name = "Trinca"
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 0.6)
	mi.mesh = q
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TRINCA_SHADER
	mat.shader = sh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cabine.add_child(mi)
	mi.position = centro
	# Deitado como o vidro: a normal aponta para o olho do motorista.
	var para_olho := (olho + Vector3(0.0, 0.0, DENTRO_OLHO_RECUA) - centro).normalized()
	mi.basis = Basis.looking_at(-para_olho, Vector3.UP)
	# A rachadura anda: cresce em um decimo de segundo.
	var t := create_tween()
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"forca", v),
		0.0, 1.0, 0.1)


## O farol pisca e volta fraco: 7,5 -> 0 -> 5 -> 0 -> 3,5.
func _piscar_farol() -> void:
	var f: Vector2 = FAROL_POR_CLIMA.get(_clima_id(), Vector2(8.0, 0.75))
	var passos := [[0.0, 0.06], [0.66, 0.05], [0.0, 0.08], [0.47, 0.0]]
	var t := create_tween()
	for p: Array in passos:
		var fr: float = p[0]
		t.tween_callback(func() -> void: _carro.ajustar_farol(f.x * fr, f.y * fr))
		t.tween_interval(maxf(0.01, float(p[1])))


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
const PELE_DE_CERA := Color("8e867d")
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
	var capuz := CapuzMacabro.vestir(c, i, ombro / 0.42, true)
	c.set_meta(&"capuz", capuz)
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
func _estalar(c: Corpo, forca: float) -> void:
	if _cam == null or _relogio_cena - _t_ultimo_estalo < ESTALO_INTERVALO:
		return
	var onde := c.global_position + Vector3.UP * c.altura_da_boca()
	if onde.distance_to(_cam.global_position) > ESTALO_ALCANCE:
		return
	var nome := StringName("estalo_osso_%d" % randi_range(1, 4))
	if forca > 0.85 and randf() < 0.3:
		nome = &"rangido_osso"
	var st := AudioDirector.stream(nome)
	if st == null:
		return
	_t_ultimo_estalo = _relogio_cena
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = lerpf(-9.0, 3.0, forca)
	p.pitch_scale = randf_range(0.82, 1.18)
	p.unit_size = 2.5
	p.max_db = 5.0
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_raiz.add_child(p)
	p.global_position = onde
	p.play()
	p.finished.connect(p.queue_free)


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
	_multidao = MultidaoEncapuzada.criar(figuras)
	_raiz.add_child(_multidao)
	_multidao_t = 0.0
	_multidao.mirar(_raiz.global_transform * _alvo_multidao)
	# O ar: nevoa rasteira clara (o farol acende nela) e manchas de treva no
	# meio deles, que o farol nao atravessa.
	# Nenhuma caixa de nevoa rasteira cobre o lugar onde o carro para: dentro
	# da cabine ela acendia com a luz do telefone e virava um veu na lente.
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
	# A revoada: onde ele esta, e onde o carro vai parar.
	for centro: Vector3 in [EstradaBuilder.ponto_em(s_padre + 4.0), _alvo_multidao]:
		var r := AuraNegra.revoada(REVOADA_CAIXA, REVOADA)
		_raiz.add_child(r)
		r.position = centro + Vector3.UP * 1.3
		r.acender()


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
	if aura != null:
		aura.acender()


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
					_estalar(c, estalo)


func _aparencia_de_encapuzado(i: int, altura: float, ombro: float,
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
	# A mao espalmada no vidro, ao lado do rosto.
	_padre.agarrar = Vector3(0.24, 1.22, -0.52)
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
	_vacuo(false)


## Marca de tempo no log, para a bancada medir o ritmo do susto.
func _marca(nome: String) -> void:
	print("[susto] %-10s t=%.2f s=%.1f fisica=%d" % [nome, _relogio_cena,
		_carro.distancia if _carro != null else 0.0, Engine.get_physics_frames()])


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


# --- camera -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _carro == null or not is_instance_valid(_carro):
		return
	_guiar_a_guinada(delta)
	_carro.avancar(delta)
	_tremor = move_toward(_tremor, 0.0, delta * 1.4)
	_t += delta
	_delta_quadro = delta
	_relogio_cena += delta
	_atualizar_trovoada()
	_atualizar_agua()
	_iluminar_fumaca()
	if _motorista != null:
		_motorista.atualizar(_carro.acel_local, _carro.inclinacao(), delta)
		_motorista.debruca_olho = DEBRUCA * _debruca
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
	_cam.fov = _fov_cena if _fov_cena > 1.0 else DENTRO_FOV
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

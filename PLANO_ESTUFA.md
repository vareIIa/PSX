# Estufa: cultivo, profissões e a folha de pagamento

Continuação de [PLANO_CASA_FUMACA.md](PLANO_CASA_FUMACA.md). A sala da frente já
estava pronta; esta é a sala atrás da porta dos fundos, e o sistema que ela
estreia.

Referência declarada: **Schedule I** — o ciclo vaso → terra → semente → água →
tempo → colheita, e o empregado que faz esse ciclo por você a partir de um
estoque designado. Fontes consultadas:
[Botanist](https://schedule-1.fandom.com/wiki/Botanist),
[Growing a plant](https://schedule-1.fandom.com/wiki/Growing_a_plant),
[guia de botânico do GameRant](https://gamerant.com/schedule-1-how-get-use-assign-botanist/).

---

## 1. O diagnóstico

A estufa existia e era bonita: manta espelhada, duto no teto, seis luminárias,
irrigação por gotejo, varal de secagem, bancada com balança. O problema não era
o acabamento.

**Era um quadro, e não um lugar.** Dezesseis plantas prontas, sempre as mesmas,
sempre no mesmo ponto, e uma pessoa andando entre elas. Na primeira visita
impressiona; na segunda não há nada para fazer ali e nada mudou. Um cômodo assim
custa o mesmo que um cômodo vivo e vale uma visita.

Três coisas faltavam, e as três são a mesma coisa vista de ângulos diferentes:

| falta | consequência |
|---|---|
| nenhum estado | a sala não podia ficar diferente do que era |
| nenhuma ação | o jogador não tinha o que fazer lá dentro |
| nenhum trabalho | a pessoa na sala não era ninguém, só um corpo andando |

---

## 2. O que foi construído

### 2.1 A regra — `game/src/systems/plantio.gd`

Sem nó, sem malha, sem cena: só o estado e o que o faz mudar. É o equivalente de
`FalasNpc` para a estufa.

```
VAZIO     --por terra-------> TERRA
TERRA     --plantar semente-> SEMEADO
SEMEADO   --regar-----------> CRESCENDO
CRESCENDO --o tempo passa---> PRONTA      (só enquanto houver água)
PRONTA    --colher----------> TERRA, e a terra envelhece um uso
```

Três números governam tudo, e os três existem por uma razão:

- **12 minutos de relógio até madura.** O relógio corre ao dobro, então são 6
  minutos reais — o tempo do Schedule I, que não é coincidência: é o tempo em
  que um jogador aceita ficar por perto vendo.
- **8 minutos de água por rega.** Menor que o ciclo **de propósito**: uma planta
  precisa de duas regas, e é essa folga que dá trabalho ao fazendeiro. Com água
  bastando para o ciclo inteiro, regar seria um botão apertado uma vez.
- **3 colheitas por terra.** É o que impede a estufa de virar moto-perpétuo e o
  que dá ao saco de terra uma razão de existir depois da primeira vez.

O tempo é do **relógio do mundo**, e não do quadro. Cada plantação guarda o
minuto em que foi vista pela última vez e paga a diferença de uma vez só ao ser
aberta. Se o crescimento contasse quadro dentro do cômodo, sair da estufa
congelaria a plantação — e a única graça de um cultivo é voltar e encontrar
diferente.

### 2.2 O que se vê — `game/src/world/plantacao.gd`

Vinte e quatro vasos em **três malhas**, refeitas quando a imagem muda de
verdade. Um nó por vaso seriam 24 chamadas de desenho numa sala só, contra 120
no jogo inteiro (ART-BIBLE §5). Refazer custa ~500 triângulos de construção e
acontece quando alguém rega, quando alguém colhe, ou quando o crescimento anda
4% — abaixo disso não muda um pixel a 480×270.

O que a imagem conta, sem uma linha de texto:

- vaso vazio mostra o feltro escuro por dentro; com terra, mostra terra
- **terra molhada é terra mais escura** — é a única leitura de água que a sala
  tem, e sem ela "regar" seria um rótulo que não muda nada na tela
- a estaca marca o vaso semeado, que senão seria igual a um vaso só com terra
- a planta estica, abre, ganha a terceira placa cruzada no meio do ciclo e as
  cabeças floridas no fim: dá para **olhar** um vaso e dizer quanto falta

O rótulo do prompt é o tutorial inteiro. `Precisa de terra` ensina duas coisas
de uma vez: o que aquele vaso quer, e que existe terra para pegar em algum
lugar. E a estação de insumos está na mesma sala.

### 2.3 A sala — `game/src/world/estufa_builder.gd`

De 7,6 × 8,6 m para **7,6 × 12,0 m**. Seis linhas de quatro vasos no lugar de
quatro linhas de quatro.

- **estação de insumos**, canto leste: sacos de terra, caixa de sementes,
  tanque e o regador pendurado na face virada para o corredor. Os quatro no
  mesmo canto de propósito — é um *lugar*, com nome e distância, e buscar é
  parte do trabalho.
- **prateleira de nove potes** na bancada, correndo pela parede oeste. Enche com
  a colheita: é o único lugar em que o trabalho de ontem aparece hoje. Começa
  com dois potes cheios e um pela metade, porque Jota e Helmer trabalham ali
  desde antes de o jogador saber que a sala existe.
- **oito vasos nascem vazios.** É o convite. Sem vaso vazio na sala o sistema
  inteiro fica invisível.

### 2.4 Profissões — `game/src/systems/profissoes.gd`

**Fazendeiro** é a primeira, e o arquivo é um catálogo: a próxima custa uma
linha ali e nada no resto do sistema.

A opção `CONTRATAR SERVIÇOS` aparece com **qualquer pessoa de pé na cidade** —
não só na estufa. É o que faz disto um sistema da cidade e não um detalhe de um
cômodo: o jogador descobre a aba conversando com alguém na calçada e só entende
para que serve quando encontra Jota e Helmer trabalhando. Ao volante, não: quem
está sendo tirado do próprio carro por um investigador não está negociando
emprego.

O registro mora em duas metades, e cada uma responde uma pergunta:

| onde | pergunta que responde |
|---|---|
| `Vector2i(id, PESSOA)` | "o que **este** aqui faz?" — a conversa precisa |
| `FOLHA` (424244) | "quem trabalha para mim?" — a estufa precisa |

Guardar só na pessoa obrigaria a varrer cem milhões de ids. Guardar só na folha
obrigaria a varrer a folha em toda conversa da cidade.

### 2.5 Jota e Helmer

Duas pessoas da cidade com ficha civil de verdade — CPF, mãe, endereço,
identidade que abre e confere. O apelido só troca o que a fita da conversa
mostra.

A estufa tem **quatro vagas de trabalho**. As duas primeiras são deles; as
outras duas ficam vazias até o jogador contratar alguém na rua — e aí a pessoa
da rua aparece lá dentro, trabalhando ao lado dos dois, com a mesma ficha que
tinha na calçada. Quem é dispensado continua na sala, sem tarefa: demitir
alguém não apaga a pessoa, só tira o trabalho dela.

A rotina deles usa a **mesma** `Plantio.proxima_tarefa` que a simulação de
ausência usa. Uma regra, dois consumidores — que é a única forma de a estufa não
andar mais rápido quando ninguém está olhando.

Ordem de urgência: colher, matar a sede, semear, pôr terra. É a ordem em que
qualquer um que cuide de planta faz, e é ela que faz o fazendeiro parecer que
sabe o que está fazendo.

### 2.6 Quem são Helmer e Jota

Os dois deixaram de ser "duas pessoas sorteadas com apelido" e passaram a ser
**pessoas fixas**. A ficha civil continua vindo do registro — CPF, mãe,
endereço, identidade que abre e confere, como qualquer um — e só a **aparência**
é escrita à mão, em `Aparencia.ELENCO`.

O motivo é simples: o rosto sorteado põe óculos em 22% dos ids e barba em 45%,
e nenhum dos dois se escolhe. Alguém que às vezes aparece sem óculos não é a
mesma pessoa.

| | HELMER | JOTA |
|---|---|---|
| cabelo | preto **cacheado**, volumoso | castanho longo, preso em **coque** |
| óculos | aro redondo fino | aro alto (barra escura em cima) |
| pelo | bigode e cavanhaque, barba rala | bigode, queixo raspado |
| alargador | preto | **vermelho** |
| pele | média | clara, com sardas |
| altura | 1,76 m | **1,90 m** |
| tatuagem | — | espinhos pretos: pescoço, antebraço e mão |

O atlas de gente ganhou uma **nona linha** (256×288) só para isto: dois rostos,
dois perfis com o alargador e duas células de pele tatuada. Cabem oito caras com
nome ali, e hoje moram quatro células. Nenhuma geometria nova: o rosto já ia na
face −Z da cabeça, o perfil nas laterais, e a pele tatuada entra onde a pele
lisa entrava.

**Coque e cacho são geometria, não textura.** É a regra que o próprio
`_montar_cabelo` já dizia: cabelo pintado na testa não muda silhueta nenhuma, e
é a silhueta que distingue as pessoas a quinze metros de névoa.

- o **coque** são duas caixas — o novelo na nuca e a mecha que sobe até ele.
  Sem a mecha o novelo flutua atrás da cabeça preso por nada. Fica na nuca e
  não no alto do crânio porque é de **perfil** que ele aparece, e de perfil é
  como o jogador mais vê quem trabalha de lado para o corredor.
- o **cacho** são seis tufos encavalados na borda da calota, mais dois
  centímetros e meio de altura e dois de largura nela. O que conta não é cada
  tufo: é o contorno irregular que os seis deixam. Tingir de preto uma das oito
  células de cabelo da cidade não resolveria — todas são fio vertical, que é o
  desenho de cabelo liso, e liso escuro continua lendo como liso.

Medido: o corpo vai de **248 triângulos** (liso) para **272** com coque e
**332** com cacho. Os critérios `coque_e_geometria` e `cacho_e_geometria`
comparam esses números em vez de conferir a chave na tabela — se o `Corpo`
deixasse de ler `coque`, a ficha continuaria dizendo que Jota tem um e o boneco
sairia de cabelo solto.

Três detalhes que só apareceram medindo ou fotografando:

- **A altura de Jota fura a regra de propósito.** `de_ficha` mantém uma faixa
  estreita porque gente de dois metros ao lado de gente de um e meio lê como
  erro de escala. Aqui a altura **é** o traço — e ele só é o alto ao lado de
  Helmer, que é o critério `jota_mais_alto`.
- **O cabelo comia a orelha.** O cabelo comprido caía sobre a lateral inteira do
  crânio e engolia a orelha junto. Nunca tinha aparecido porque a orelha era só
  uma sombra na textura; com o alargador desenhado nela, a peça que identifica
  os dois de perfil simplesmente não existia na tela. Agora o cabelo cai **atrás**
  da orelha, e isso vale para a cidade inteira.
- **A sobrancelha sumia atrás dos óculos.** Subiu dois pixels. Sobrancelha é o
  traço que mais carrega expressão num rosto de 32 px.
- **Os cachos comiam a cara.** Na primeira versão os tufos ficavam na metade de
  baixo da calota e chegavam à linha da sobrancelha: o cacho ficava certo e o
  rosto sumia dentro dele. Agora eles coroam a calota — um rosto de 32 px não
  sobrevive a nada por cima, e são os óculos e o bigode que dizem que aquele é
  o Helmer.

A amarração id → personagem mora no `WorldState`, entra no save e é aplicada
dentro de `RegistroCivil.identidade` — e não na hora de criar o nó. É o que faz
a carteira de identidade de Jota mostrar a mesma cara do corpo na sala; o
critério `elenco_na_identidade` existe por isso.

### 2.7 A fala que lê o mundo

`COMO VAI A PLANTAÇÃO?`, só dentro da estufa. A resposta carrega o **número de
verdade**: "tem 4 pra colher agora", e há quatro. É a única fala do jogo que lê
o estado do mundo antes de falar, e por isso a única que pode estar **errada**
se o jogador não cuidar — que é o que separa informação de enfeite.

Quem não é da estufa não sabe de nada: "pergunta pros caras, eu cheguei agora".
Sem isso, contratar alguém não mudaria nada no que a pessoa diz.

### 2.8 Itens novos

`terra`, `semente_maconha`, `regador`, `maconha`. Empilham alto (20) porque o
inventário tem oito espaços, e um saco por espaço tornaria plantar quatro vasos
um exercício de ir e voltar. Tipo novo `INSUMO`, acrescentado **no fim** do enum
— os `.tres` gravam o tipo como número, e inserir no meio trocaria em silêncio a
bandagem por munição em onze arquivos já gravados.

---

## 3. Dois defeitos que já estavam no jogo

Nenhum dos dois foi introduzido aqui; os dois apareceram porque o sistema novo
passou pelo mesmo caminho.

**`Inventario.adicionar` devolve o que SOBROU, não o que entrou.** A condição
estava invertida em `Convidado._pagar_o_que_o_dono_deve`: com espaço na bolsa
ela saía antes de marcar `dono_pagou`, e o dono oferecia o mesmo bilhete em toda
conversa; com a bolsa cheia marcava como pago um bilhete que nunca entrou. Os
dois efeitos passavam pela verificação, porque ela confere se o bilhete chegou e
se a missão fechou — e as duas coisas continuavam verdadeiras.

**A folha de assuntos desenhava seis linhas.** A conta na rua fecha em cinco,
mas dentro da casa da fumaça eram **sete**, e a sétima era `VER IDENTIDADE` — a
opção que o jogo inteiro ensina o jogador a procurar. Ela simplesmente não era
desenhada, e nada avisava: o teste da casa passa porque `Conversa.escolher` acha
por chave, sem olhar a tela. A folha agora aguarda oito e **cresce para cima**
com a lista, com a base presa acima da caixa de fala.

---

## 4. Decisões que custaram uma volta

**A postura de trabalho dobra na cintura, e não agacha.** O vaso tem 46 cm e a
planta em cima; quem trabalha nessa altura se dobra — agachar poria a cabeça do
fazendeiro abaixo da boca do vaso. Também é a pose que este esqueleto faz sem
mentir: agachar exige resolver joelho e tornozelo juntos, que foi o que custou
duas rodadas na pose de sentado e acabou com o pé 8 cm dentro do chão.

**Trabalho antes de conversa.** Na primeira versão o papo vinha primeiro em
`_esperando`, e a estufa ficou com dois fazendeiros de papo furado o teste
inteiro: a chance de puxar conversa é testada a cada quadro de física e a espera
entre tarefas é curta, então os dois se encontravam antes de chegar a qualquer
vaso. Na tela aquilo parecia só dois NPCs conversando. Quando não há tarefa
nenhuma eles continuam se juntando — que é o que duas pessoas fazem num galpão
com tudo em dia.

**A sétima lâmpada.** Passa do orçamento de quatro fontes por chunk do
ART-BIBLE, e passa por uma razão medida: a sala dobrou de comprimento e ganhou
uma área de trabalho onde antes havia parede. As seis de cultivo ficam sobre as
linhas de planta e a primeira está a 4,27 m da porta — a bancada, a estação de
insumos e a prateleira caíam todas na sombra. **A captura mostrou isso antes de
eu perceber lendo:** o lugar de onde sai tudo que o jogador precisa era o único
canto escuro do cômodo.

**O ícone da maconha tem o verde por fora.** A primeira versão tinha vidro por
fora e as cabeças dentro, que é o certo no mundo e errado no ícone: o bake sai a
onze pixels úteis, o vidro é opaco no material padrão e o pote virou um cilindro
branco liso.

---

## 5. O que a verificação afirma

```
python tools/verificar_estufa.py      # 69 critérios
python tools/verificar_fumaca.py      # 26 — a sala da frente, intacta
python tools/verificar_npc.py         # 125 — o atlas cresceu; a rua não mudou
```

Quase nada desta frente cabe numa captura. Uma foto da estufa mostra plantas
bonitas em vasos, e mostraria **exatamente a mesma coisa** se regar não fizesse
nada, se a planta crescesse no vaso seco, se a terra nunca gastasse, se o estado
se perdesse ao sair pela porta, se Helmer estivesse contratado e não
trabalhasse, ou se o trabalho de quem fica nunca acontecesse. Os seis são
defeitos que um sistema de cultivo tem por padrão até alguém provar que não.

Alguns critérios e o defeito real que cada um guarda:

| critério | o que impede |
|---|---|
| `nao_cresceu_seco` | a água não querer dizer nada, e o ciclo virar decoração |
| `gastou_terra` | o saco ser infinito, e a estação de insumos não existir |
| `terra_envelhece` | a estufa virar moto-perpétuo |
| `sobreviveu_a_saida` | o trabalho do jogador sumir sem nada na tela acusar |
| `sem_fazendeiro_colheu = 0` | contratar alguém não significar nada |
| `trabalho_limitado` | contratar virar um botão de pular para o fim |
| `placar_diminuiu` | a mesma erva existir na mochila e na prateleira |
| `lista_cabe` | a opção de identidade sumir da folha sem aviso |
| `pe_abaixo_do_piso` | a pose nova enterrar o pé, como a de sentado enterrou |
| `corredor_chega_ao_fundo` | a estufa comprida existir só no arquivo |
| `elenco_na_identidade` | Jota ter uma cara na estufa e outra na carteira |
| `elenco_rostos_distintos` | dois personagens virarem um só com dois nomes |
| `elenco_depois_da_porta` | sair e voltar devolver dois desconhecidos |

Duas medidas foram feitas porque **olhar a imagem não resolvia**:

- o corredor mede **10,65 m** livres da soleira à parede do fundo. Na captura da
  entrada a sala parece ter sete metros — névoa e queda de luz encurtam qualquer
  corredor, e a imagem não distingue isso de uma parede atravessada no meio.
- o cômodo inteiro, com a plantação viva, dá **2.166 triângulos em 6 malhas**,
  contra 6.000 e 120 do ART-BIBLE.

### Capturas

```
captures/estufa/corredor.png     a entrada, por baixo do varal de secagem
captures/estufa/fundo.png        o comprimento, pela fila de luminárias
captures/estufa/insumos.png      tanque, regador, sacos de terra e sementes
captures/estufa/prateleira.png   os nove potes: dois cheios, um pela metade
captures/estufa/vazios.png       as últimas linhas, e o rótulo "Precisa de terra"
captures/estufa/fazendeiro.png   HELMER debruçado sobre a caixa de sementes
captures/estufa/elenco.png       os dois de frente: óculos, bigode e a altura
captures/estufa/elenco-perfil.png  de lado, pelo alargador vermelho do Jota
```

Comandos:

```
godot --path game -- --entrar-estufa --olhar-fundo \
  --shot=../captures/estufa/fundo.png --shot-frame=560 --shot-quit
```

Molduras disponíveis: `--olhar-canteiro`, `--olhar-fundo`, `--olhar-insumos`,
`--olhar-prateleira`, `--olhar-vazios`, `--olhar-fazendeiro`, `--olhar-elenco`,
`--olhar-elenco-perfil`.

---

## 6. O que ficou de fora

- **Aditivos** (fertilizante, PGR, acelerador). No Schedule I eles são a camada
  de otimização; aqui seriam três itens e três estados por vaso antes de o ciclo
  básico ter sido jogado por alguém.
- **Dinheiro.** Não existe no jogo, então contratar é de graça. Quando houver,
  a diária entra no catálogo de `Profissoes.LISTA` e em nenhum outro lugar.
- **Mais caras com nome.** A linha do elenco tem quatro células livres e a
  tabela `ELENCO` aceita entradas novas sem mexer em mais nada.
- **Mais de uma estufa por cidade.** A folha de pagamento é global e a plantação
  é por semente de cômodo, então já funciona — mas as quatro vagas são as
  mesmas, e dois galpões dividiriam os mesmos contratados.
- **A expansão da casa da fumaça** (Fase 5 do plano anterior: corredor+cozinha,
  escada+quarto, banheiro, laje). Não foi começada.

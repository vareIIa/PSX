# Morros de Minas — mapeamento, plano e estado (21/09/2026)

Pedido: a cidade tem de ter os morros de Minas — ruas íngremes, a igreja no alto, bairros
pendurados na encosta, serra no horizonte. Os três passos foram aceitos. Este documento é
o mapa do que existe, de como cada parte foi feita e de como ela se prova.

Referência: as duas fotos do pedido. A primeira é a cidade no vale, cercada de serras em
camadas que clareiam com a distância. A segunda é a encosta de pasto dourado com eucalipto,
e o casario descendo o morro.

## Regra de convivência

Outras sessões editam o repositório ao mesmo tempo. Todo trabalho novo mora em arquivo
novo. Arquivo compartilhado recebe só gancho mínimo e comentado, e compila a cada passo.
Nada alheio é revertido. Nenhum commit sem aval do usuário.

## Arquitetura

| Camada | Arquivo | Papel | Estado |
|---|---|---|---|
| Morro | `src/world/morros.gd` | Altura bruta do nó: morro da matriz, um morro por célula de 384 m, vale, ruído miúdo | feito |
| Chão | `src/world/relevo.gd` | Nivela parque e patamar, aterra a avenida, deforma o chão, ergue o lote, gera a colisão | feito |
| Horizonte | `src/world/serra_da_cidade.gd` | Três cristas presas à câmera, pintadas pela névoa | feito |
| Rua íngreme | `src/world/ladeira.gd` | Declive por trecho; decide escadaria | feito |
| Escadaria | `src/world/escadaria_builder.gd` | Degraus de pedra, corrimão, frades | feito |
| Rua em curva | `src/world/serpentina.gd` | Traçado, casas e vãos da célula de encosta | feito |
| Célula de encosta | `src/world/serpentina_builder.gd` | Pista, calçada, casas giradas, pasto, postes, placa | feito |
| Bairro | `MalhaUrbana.distrito_de` | Distrito pela altitude | feito |
| Mirante | `src/world/mirante_builder.gd`, `mirante.gd`, `luneta.gd` | Parque no alto ou na encosta com vista: bastião com cruzeiro e luneta, névoa que abre | feito |

Dependências sem ciclo: `Morros` e `Serpentina` só leem `MalhaUrbana` (ruído e distrito);
`Relevo` lê os dois e chama o `ChunkBuilder` só por `load()` tardio. Citar pelo nome
puxava a cadeia de autoload para a compilação no `--script`, e as estáticas do `Relevo`
ficavam nulas.

## 1. O terreno

`Relevo.altura(x, z)` é bilinear nos cantos dos chunks, então a rua sobe reta entre duas
esquinas. A altura de cada nó passa por três etapas:

1. **Morro** (`Morros.bruto`): o máximo dos morros vizinhos, em perfil de cosseno. A
   matriz tem 36 m, raio de 14 chunks e topo plano de 2,5 chunks. Os morros das células
   têm de 10 a 34 m e raio de 0,6 a 0,9 célula. Somam-se 2 m de ruído miúdo. A praça fica
   em y = 0 e a cidade inteira desce dela: **nenhuma coordenada da abertura mudou**.
2. **Zona plana** (`_nivelada`): o parque (ou o grupo de parques que dividem um nó) fica
   na média do terreno dele; o grupo da Praça da Matriz fica em zero. O grupo é a
   componente inteira de parques encostados (teto de segurança de 64 quadras): com teto de
   6 o grupo mudava conforme o parque perguntado primeiro, e numa componente de 7 quadras a
   fileira da borda saía 1,64 m torta.

   Patamar é só o chunk do **bar** e o da **casa da fumaça** que existe atrás da porta
   (`Relevo.PLANTAS_DE_PATAMAR`). O mercado também entra andando, mas o lote dele sobe rígido
   pela altura da porta, como o de qualquer casa de morro. Pela regra antiga ("toda porta no
   mundo") ele virou patamar sem ninguém pedir: 110 em 52×52 chunks, a cidade achatada, 47
   patamares tortos e a avenida a 40%. Três regras seguram o patamar:
   - O nível é o do **grupo** de patamares que dividem nó. A porta cai em diagonal, e cada um
     no seu nível deixava o nó do canto com o primeiro.
   - Ele puxa o chão só por 3 nós (`ALCANCE_PATAMAR`). O parque puxa por 5.
   - Ele fica a no máximo 28% de um parque a um trecho (`DECLIVE_JUNTO_A_ZONA`). A avenida
     também fica a no máximo 28% por trecho de um nó cravado numa zona ali adiante na linha;
     a média sozinha juntava o desnível inteiro no trecho colado nele. Bar e casa da fumaça
   (patamar) entram como parque pequeno e herdam o nível do parque quando encostam num. O
   entorno vai do nível ao terreno em 5 nós, e todos os parques do alcance entram com
   peso — pegar só o mais perto criava um degrau de 42% entre dois parques.
3. **Avenida aterrada** (`_aterrada`): média triangular de ±3 nós ao longo da linha, fora
   dos nós colados em zona plana.

O `ChunkBuilder` usa o resultado assim:

| Chunk | Caminho |
|---|---|
| Plano em zero (a praça) | Caminho antigo, byte a byte |
| Inclinado | Chão deformado vértice a vértice; lote rígido na altura da soleira com embasamento de pedra (com colisão) até o canto mais baixo; porão com porta, janelas e varanda de fundos quando o chão atrás desce mais de 2,4 m; quintal, beco, vila e baldio assentados; colisão por mapa de alturas de 0,5 m |
| Parque fora da praça | O `ParqueBuilder` monta plano e o chunk sobe inteiro pelo nível do patamar |

Declive medido em 48×48 chunks (`tests/checar_relevo.gd`):

| Via | Mediana | p95 | Máx | > 20% |
|---|---|---|---|---|
| Viela | 3,0% | 14,4% | 34,0% | 2,0% |
| Rua | 3,4% | 15,8% | 51,9% | 2,5% |
| Avenida | 3,1% | 12,7% | 28,0% | 0,5% |

A avenida só passa de 20% colada em parque de encosta.

### O que mudou para quem mede

O disco plano da origem saiu, e a origem fica ~20 m abaixo da praça. Tudo o que supunha
chão em y = 0 passou a ler o chão do morro:

| O quê | Onde |
|---|---|
| Nascimento da cena, despertar da abertura, raios de chão | `cidade.gd`, `abertura.gd` |
| Pé do poste | `ChunkBuilder.posicao_poste` |
| Ponto de interesse (porta, telefone) já no chão | `ChunkBuilder.pontos_de_interesse` |
| Esquina do pedestre e faixa do carro | `Rotas.ponto`, `Vias.ponto_de_curva` |
| Paradas da rota de captura | `rota_captura.gd` |
| Corredor fantasma | `player.gd --atravessar` |
| Testes e bancadas | `bancada_quinas`, `parque_teste`, `teste_horror`, `teste_npc`, `varrer_patio` |
| Sonda de reflexo, poça, respingo, pingo de toldo, decalque | `sondas_reflexo`, `pocas`, `chuva`, `goteiras`, `decalques_rua` |
| Pedestre começa a suavização da altura no 1º quadro de física | `pedestre.gd` |
| Carro parado sem pedal segura na rampa | `carro.gd` |
| Carro da IA e blitz inclinam com a rua; bicicleta também | `carro.gd`, `blitz_manager.gd`, `bicicleta.gd` |

Chaves de bancada:
- `--sem-relevo` desliga o morro desde o primeiro quadro. O `verificar_carro.py` usa: ele
  mede o carro, e na ladeira o mesmo táxi freava 4,6 m/s² em vez de 8,6.
- `--olhar-ladeira=x,z,mira_x,mira_z[,alto]` fotografa na altura do olho, de dia.
- `--sem-serra` compara em par.

As imagens de referência da regressão visual fora da praça precisam ser refeitas: a cidade
mudou.

## 2. O horizonte — serra

Três cristas (248, 272 e 296 m) presas à posição da câmera. A de longe é mais alta e mais
clara.

- **Sem névoa, mas pintada pela névoa:** some em névoa densa e aparece por inteiro com a
  vista aberta.
- **Abaixo do horizonte:** bruma de vale, cinza-esverdeada de dia.
- **Sem profundidade:** a cidade fica sempre na frente dela, e o borrão de movimento a
  trata como céu.
- **Distâncias:** a câmera do jogador corta em 420 m; as estrelas ficam a 320 m.
- **Cor:** o vértice é sRGB. Lido como linear, saía mais claro que o céu.
- **Ligação:** entra pelo `DiretorCeu` e se esconde no céu próprio da Estrada Velha e em
  interior.

## 3. A escadaria

Trecho de rua ou viela acima de 20% (`Ladeira`) vira escadaria de pedra. Os degraus têm
espelho de até 17 cm e acompanham a inclinação lateral. Cada degrau é uma pedra de tom
próprio, com bocel mais claro avançando 3 cm sobre o espelho. Há corrimão de ferro no eixo e
frades a 1,35 m um do outro nas duas bocas (passa gente, não passa carro). A colisão é a
rampa do mapa de alturas.

O meio-fio ao lado da escada desce um espelho inteiro abaixo do chão
(`EscadariaBuilder.SAIA`). O piso do degrau fica até meio espelho abaixo da rampa do meio-fio,
e com a saia comum (6 cm) abria uma cunha para baixo da calçada no pé de cada espelho
(`bancada_quinas`, chunk (1,−2)).

Quem mais sabe da escadaria:
- `Vias.dirigivel_x/_z`: `proxima_x/z` para no primeiro trecho não dirigível, então a
  corrida inteira sai das saídas e a IA não cai em beco.
- A pintura de faixa e a vaga somem no trecho.
- Semáforo, zebra e retenção seguem os braços de `Vias`.
- Esquina em L: quando a escada tira um braço de um T, sobram dois braços em eixos diferentes.
  Isso é curva, não cruzamento. `Vias.existe_cruzamento` pede três braços, então não há zebra,
  PARE nem retenção na curva, e o trecho até ela fica sem trânsito da IA (o jogador passa).
  São 6 esquinas em 81×81 chunks.

## 4. O bairro pela altitude

O distrito pesa a altura do morro: comércio e galpão no vale, casa na encosta, casario solto
e baldio no alto. A região da praça fica com o sorteio de sempre, porque ela só é parque
porque o distrito dela sorteou parque.

## 5. A rua em curva — célula de encosta

A cidade é uma grade, e a rua mora na borda do chunk. A serpentina convive com ela assim:

- **Qual célula:** a de 5×5 chunks entre avenidas, residencial, com desnível de 12 m ou
  mais entre dois lados opostos, em 60% dos casos. O `Tracado` não reparte essa célula: ela
  é um quarteirão só (quadra `serpentina`, sempre edificada).
- **Traçado** (`Serpentina.dados`, função pura com cache):
  - entra pela avenida de baixo e anda 20 m reto;
  - faz três pernas ao longo da encosta, com cotovelos em Catmull-Rom centrípeta;
  - sai pela avenida de cima;
  - é amostrado a cada 2 m.
- **Casas:** dos dois lados, de frente para a curva, sem encostar na pista, noutra casa ou
  na faixa da fileira da avenida. Montadas no espaço da casa com o kit de sempre (massa,
  fachada, telhado, fundos, embasamento) e giradas para o chunk (`PSXMesh.acumular`). A
  colisão é girada.
- **Entrada:** o vão na fileira da avenida sai por `SerpentinaBuilder.vao_na_face`, no
  lugar do beco da face. O muro de fundo dos quintais abre na largura dele, e as divisas
  viram as paredes do corredor.
- **O resto:**
  - pista de paralelepípedo e calçada com meio-fio;
  - pasto dourado com capim seco e eucalipto;
  - um poste de sódio por chunk;
  - placa azul com o nome ("LADEIRA DO …") na boca.
- **Integração:** o GPS dá o endereço pela curva, o mapa risca a linha e o mapa de alturas
  sabe da pista.
- **Casa solta:** as duas empenas têm janela em todo andar. O térreo usa a janela da frente
  (vidro, moldura, peitoril e grade); em cima, vidro, moldura e peitoril em placa. Quando o
  chão atrás da casa desce mais que um andar, o embasamento vira porão: porta da cozinha rente
  ao quintal, janelinhas e varanda de fundos na altura da soleira (a porta dos fundos dava
  para o vazio).
- **Custo** (81×81 chunks, 550 da célula): média de 3.238 triângulos por chunk, pior 5.552
  (teto 6.000); até 62 ms por chunk, em thread de trabalho.
- **Ainda não:** o trânsito da IA e a multidão não andam na serpentina. O jogador anda e
  dirige nela.

## 6. Mirante

**Onde** (`MiranteBuilder.e_mirante`): parque no alto do morro (nada até 4 nós em volta sobe
mais de 3 m acima do patamar) ou na encosta com vista (o chão para fora de uma borda desce
5,5 m na média de 30, 60 e 100 m). Fica de fora a Praça da Matriz. Só o topo dava 2 mirantes
em 81×81 chunks; com a encosta são 18, e 9 deles têm terraço.

**O terraço** (`MiranteBuilder.construir`, chamado pelo `ParqueBuilder`). Fica na meia borda
com a maior queda, pesando menos a borda que dá para quadra edificada. A meia borda cujo
terraço cruzaria caminho ou miolo fica de fora: no parque de campo estreito, o cerco do campo
passa a menos de 4,2 m da borda. Ocupa até 24 m entre o canto e o portão, com 4,2 m de fundo,
e para antes do anel de caminhada. No chão do parque a
primeira fileira de casas do outro lado da rua fechava a vista (foto medida: sobrado a 14 m,
no mesmo nível). Por isso o terraço é um **bastião elevado de 2,4 m**:

- muro de arrimo de cantaria com barrado escuro no pé e cimalha no topo;
- piso de lajota com rejunte;
- peitoril caiado nos três lados abertos, com pilastra, capitel e pinhão;
- **cruzeiro** na ponta do canto, de frente para a cidade: é a silhueta que se vê de baixo;
- **luneta** pública no peitoril, com bancos virados para a vista, lanterna e placa da
  prefeitura com o nome ("MIRANTE DO VALE", "ALTO DO ROSARIO"…) no muro, do lado do parque;
- **escadaria** de acesso do lado do portão (15 degraus de 16 cm com bocel), entre
  guarda-corpos inclinados, pedra embaixo e cal em cima.

A colisão é o corpo do bastião mais uma rampa na linha dos bocéis. O gradil do parque abre no
trecho do bastião, e árvore, banco e canteiro do parque ficam fora dele. O mapa, a faixa de
estado e o GPS dão o nome do mirante (`ParqueBuilder.planta`). O terraço custa uns 550
triângulos: sem o topo do barrado, que fica escondido, com lajota de 1,4 m e com pinhão só nas
pilastras de quina e de cabeceira. Todos os chunks com terraço ficam abaixo de 6.000; um parque
de coreto passava por 10 antes desse corte.

**O ar** (`Mirante`, nó da cidade). No parque mirante, um clima derivado do escolhido abre a
névoa: 2,4× (1,6× na chuva), até 150 m, com o streaming acompanhando. Ele entra pela API
pública (`forcar_preset`) e só se ninguém mais estiver forçando a névoa; se alguém forçar no
meio, ele larga sem devolver nada. O preset derivado entra de uma vez, porque chuva e nuvem
reiniciam as partículas a cada preset. O que o olho vê abrir devagar é o ar: fim e início da
névoa, densidade e comprimento do volume e a serra são interpolados no `Environment` em
3,5 s. Na saída a volta leva 2,5 s, e só no fim o preset é devolvido, nos mesmos números e sem
salto.

**A luneta** (`Luneta`, [E]). Prende o jogador atrás da ocular, em primeira pessoa, com a máscara
de duas lentes. A mira gira num arco de 80°, a roda aproxima de 26° a 6°, e [E] ou [Esc] largam.
A cabeça da luneta é malha do chunk e ficaria entre o olho e a vista, então a câmera corta a
0,9 m enquanto se olha.

## Como se mede

| Teste | O que prova |
|---|---|
| `tests/checar_relevo.gd` | Praça em zero, parque e patamar planos, declive por via |
| `tests/varrer_patio.gd` | Quarteirão fechado, com relevo; vão de beco e de serpentina contam como fechados |
| `tests/bancada_quinas.gd` | Buraco pro limbo, com relevo |
| `tests/checar_ameaca.gd` | Inimigo solto na rua desligado (`INIMIGO_NA_RUA`) |
| `tests/checar_mirante.gd -- --fog=leve` | Mirante e terraço no raio; terraço dentro do parque e fora dos caminhos, determinístico; uma luneta e uma placa; rampa do piso ao chão; orçamento; névoa abre, larga, volta e fecha num `FogController` de verdade |
| `tools/verificar_*.py` | Trânsito, cidade, NPC, streaming, bar, casa, mercado, carro |

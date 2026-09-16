# PLANO CHUVA NA CABINE AAA — interior fechado e água de verdade no vidro

> Diagnóstico medido + plano de execução para o interior dos carros e a água nos
> vidros, a partir do plano de dentro da Estrada Velha.
> Versão 1.0 — 16/09/2026 — branch `playable`

---

## 0. O que a print mostra

Dois defeitos no plano de dentro do carro, na abertura, com chuva:

1. **Buraco na lateral esquerda.** Abaixo e à frente da janela do motorista não
   há porta por dentro: nem forro, nem maçaneta. O que aparece é a mata passando
   através da lataria.
2. **A água não parece água.** "Uma foto piscando": gotas que acendem e apagam,
   e que aparecem também onde não há vidro, inclusive sobre o buraco.

Os dois têm causa comum. **A cabine não foi construída a partir do carro.** Ela
chuta onde ficam as paredes e o vidro, e a água é uma placa presa à lente, não
ao vidro. Por isso este plano não retoca o shader: ele troca a fundação e depois
a óptica.

---

## 1. Diagnóstico medido

Tudo abaixo foi lido no código e medido em 16/09/2026. A sonda nova
`game/tests/medir_cabine_cobertura.gd` dispara um raio por pixel (480×270,
FOV 74, pitch −4, o enquadramento de `AberturaEstrada._de_dentro`) a partir do
olho do motorista e classifica o que cada pixel mostra. As imagens estão em
`captures/cabine_chuva/antes/`.

### 1.1 O buraco — 15 a 43% do quadro

| Modelo | vê pelo para-brisa | **buraco** (chapa vista por dentro) | água da placa fora do para-brisa | vidro da cabine sobre chapa | vidro da lataria sem vidro na cabine | peça da cabine além da chapa |
|---|---|---|---|---|---|---|
| Marea | 17,08% | **25,53%** | 28,71% | 3,08% | 0,00% | 20,17% |
| Sedã (e táxi) | 30,13% | **15,30%** | 20,64% | 5,24% | 0,00% | 19,38% |
| Hatch | 51,03% | **17,45%** | 20,70% | 3,30% | 0,00% | 0,36% |
| Perua | 42,01% | **16,80%** | 24,61% | 7,46% | 0,00% | 3,45% |
| Picape | 28,74% | **17,16%** | 27,57% | 6,79% | 0,00% | 15,46% |
| Fusca | 17,24% | **42,65%** | 46,92% | 0,00% | 7,17% | 8,90% |

"Buraco" é o raio que sai do carro pela **chapa** sem ter tocado em nenhuma peça
do interior. A lataria usa `psx_surface` com `cull_back`, então vista por dentro
ela não existe e o que aparece é o mundo lá fora.

Onde fica o buraco do Marea, pelo ponto de saída (z do carro, y relativo ao olho):

- **Moldura superior do para-brisa**, com saída em z −0,3 a −0,4 e y +0,1, cerca
  de 19 mil pixels. O vidro da lataria é recuado 10 cm da abertura
  (`carroceria_marea.gd:191`), e o forro do teto começa em
  `z_do_vidro(teto) + 0,04` (`carro_cabine.gd:464`). Entre a borda de cima do
  vidro e a frente do forro sobra uma faixa inclinada de 17 cm de chapa.
- **Porta abaixo e à frente da janela**, com saída em z −0,4 a −0,7 e y de −0,3
  a 0,0. É o buraco da print. O forro da porta só começa em
  `PAINEL_Z + 0,05 = −0,39` (`carro_cabine.gd:397`) e vai só até 21 cm acima do
  piso. Entre o fim do painel e o começo da porta não há nada: faltam a tampa
  lateral do painel, o painel de chute e a frente do forro de porta. **A
  maçaneta, a manivela, a trava e o apoio de braço não existem em nenhum
  modelo.**
- **Coluna A.** A coluna da cabine é uma caixa de 4,8 cm
  (`carro_cabine.gd:420`), mas a coluna da lataria, somada à moldura de 10 cm e
  ao triângulo até a janela, tem 15 a 50 cm de chapa. Em volta da caixa fina
  aparece mata.

### 1.2 A água não está no vidro

A água do para-brisa é um `QuadMesh` de 1,78 × 1,06 m preso **60 cm à frente do
olho** e virado para ele (`carro_cabine.gd:166`, `:558`). Não é o para-brisa: é
uma tela entre a lente e o mundo. Ela desenha água em tudo que estiver a mais de
60 cm e não for tapado pelo teste de profundidade:

- sobre o buraco (a "água pingando no carro" da print);
- sobre a janela lateral, que já tem a própria camada de água, o que dá **duas
  águas sobrepostas** no mesmo pixel;
- sobre a moldura e a coluna.

Na tabela, a coluna "água da placa fora do para-brisa" mede isso: de 21 a 47% do
quadro recebe água num lugar onde não há vidro. Placa presa à lente também não
tem perspectiva: a gota de um para-brisa inclinado a 60° deveria sair achatada
na vertical e sai redonda.

### 1.3 O piscar — um número para o vidro inteiro

`_aplicar_limpador` escreve **um único** `acumulo` para o para-brisa todo
(`carro_cabine.gd:672-673`), e o shader multiplica toda a água por ele
(`psx_parabrisa.gdshader:266-267`). A cada passada (0,55 s no temporal) a água do
vidro inteiro cai para 8% quando a palheta cruza o meio, e volta a crescer. Isso
vale para o vidro todo, esteja a palheta onde estiver.

Medido em 4 capturas do plano de dentro (`chuva=1`), recortando o para-brisa
(`captures/cabine_chuva/antes/limpador_pisca_quadros_150_158_166_174.png`):

| Intervalo | pixels que mudam mais de 12 níveis |
|---|---|
| quadro 150 → 158 | **11,1%** (o vidro vai de limpo a cheio em 0,13 s) |
| 158 → 166 | 3,8% |
| 166 → 174 | 4,6% |

É um pulso global a cerca de 1,8 Hz: a "foto piscando".

### 1.4 O limpador não varre

A palheta é montada ao longo de −Z (`carro_cabine.gd:528-531`) e girada em torno
de Z (`carro_cabine.gd:664`), ou seja, **em torno do próprio comprimento**.
Medido com a sonda do limpador:

| Pose | ponta da palheta (x, y, z) |
|---|---|
| repouso (0°) | (±0,30, 0,94, **−1,355**) |
| meio do curso (39°) | (±0,30, 0,94, **−1,355**) |
| fim do curso (78°) | (±0,30, 0,94, **−1,355**) |

A ponta nunca sai do lugar. Ela fica deitada no capô, 42 cm à frente da base do
vidro, e só gira sobre o próprio eixo. O único "limpar" do sistema é o pulso do
item 1.3, que não tem forma nem lugar. Além disso, a lataria do Marea já desenha
dois braços de limpador na tampa (`carroceria_marea.gd:320`), então o carro tem
quatro limpadores e nenhum varre.

### 1.5 A gota não lê como água

Na sequência capturada as gotas saem como **cerejas com cabo**. As causas estão
no shader:

- a borda da lente escurece 45% (`psx_parabrisa.gdshader:308`), e sobre mata
  escura isso vira bola preta;
- o rastro é um fio com gotinhas residuais por cima da gota
  (`psx_parabrisa.gdshader:222-231`): o cabo;
- as gotas são células de uma grade de hash no quad, com a mesma densidade em
  todo lugar e vida ditada por `TIME`. Nada persiste, nada se junta, e a
  corredora não limpa as gotas paradas por onde passa;
- o embaçado some onde a gota passa (`psx_parabrisa.gdshader:302-303`). O
  embaçado fica do lado de **dentro** do vidro e a gota do lado de fora: uma não
  limpa a outra, e o limpador também não limpa o embaçado.

Com o carro parado, a janela esquerda lê como uma placa cinza opaca com pontos
pretos (`captures/cabine_chuva/antes/dentro_chuva_parado.png`).

### 1.6 O vidro da cabine não é o vidro do carro

A cabine desenha a própria janela lateral como um trapézio da coluna A até
`z_tras` (`carro_cabine.gd:586-633`). A lataria tem outra tabela de janelas
(`carroceria_marea.gd:159-164`): no Marea, a janela começa em z = −0,34 e a
cabine começa em cerca de −0,8. Resultado: vidro da cabine sobre chapa em 3 a
7,5% do quadro. No Fusca é o contrário: há 7,17% de vidro da lataria sem nenhum
vidro da cabine atrás.

Cheguei a anotar aqui que a lataria do Marea é que estaria errada, por deixar
54 cm de chapa entre o para-brisa e o quebra-vento. **Medido na Fase 1, não
está**: entre as estações z = 0,88 e z = 0,44 a superfície de cima do carro é o
próprio para-brisa, então aquela faixa é a projeção da coluna A inclinada, e a
referência (`PRINTS/CARROS/MAREA/`) combina com ela. Quem inventa vidro é a
cabine, e é ela que passa a ler as aberturas da lataria.

### 1.7 Peças da cabine além da chapa

De 0,4 a 20% do que se vê por dentro são peças da cabine que ficam **fora do
casco**. No Marea, o forro do teto fica a `teto − 0,015 = 1,375 m`, mas na frente
do teto a lataria mede 1,31 a 1,32, então o forro atravessa o teto. Hoje isso
não aparece porque a abertura esconde a cabine nos planos de fora
(`mostrar_cabine`) e o fundo do menu também (`cabine_fundo_criacao.gd:429-437`).
Vai aparecer no dia em que a cabine for para o carro da cidade em terceira
pessoa.

### 1.8 A chuva de partícula não tem teto

`psx_chuva.gdshader` só apaga o risco a menos de 0,6 m da lente
(`psx_chuva.gdshader:20`, `:42`). Não existe noção de cabine: um risco entre
0,6 m e o vidro (que fica a 0,36 a 0,8 m à frente do olho) cai **dentro** do
carro. `Chuva.abrigo` só mexe no som (`chuva.gd:428-429`).

### 1.9 Só um carro tem interior

Só o `CarroCena` (abertura e fundo da criação de personagem) monta
`CarroCabine`. O `Carro` dirigível da cidade não tem interior, e por isso a
câmera é forçada para terceira pessoa ao volante (`camera_rig.gd:37-52`). O
vidro de todos os carros vistos de fora é uma célula opaca do atlas
(`Carroceria.VIDRO`), que não reage à chuva e esconde o motorista
(`carro.gd:662`). A referência do Marea mostra vidro translúcido com bancos e
encostos visíveis.

### 1.10 O jogo mudou de renderizador

Medido em 16/09/2026, durante a Fase 0: `game/project.godot` está com
`renderer/rendering_method="forward_plus"` — **alteração ainda sem commit**, de
outra sessão. O jogo não roda mais em Compatibility por padrão.

Isso muda o terreno deste plano: SSR, decal, névoa volumétrica e refração de
tela passam a existir. Os spikes da Seção 6 foram rodados **nos dois**
renderizadores, e o sistema de água foi desenhado para não depender de nenhum
recurso exclusivo — o PS1 STYLE continua sendo uma decisão de arte, e não uma
limitação de motor.

### 1.11 Estado do repositório

- `game/shaders/psx_parabrisa.gdshader` está **untracked** e
  `game/src/world/carro_cabine.gd` está modificado sem commit. Os dois foram
  reescritos hoje às 11:42 por uma sessão paralela, e o cabeçalho do shader
  documenta essa reescrita. É o que aparece na print.
- A memória do projeto registra que um merge de sessão paralela já reverteu
  arquivos rastreados. **Antes de começar a Fase 1, o estado atual precisa estar
  commitado.**

---

## 2. O que "AAA" significa nesta frente

| AAA aqui significa | AAA aqui não significa |
|---|---|
| Todo pixel da cabine é interior ou vidro, e existe teste que prova | Mais polígono no painel |
| A água mora no vidro, tem estado e lembra onde o limpador passou | Mais camadas de ruído no shader |
| A gota obedece gravidade, vento, freada e curva | Gota animada por `TIME` |
| O limpador limpa onde passa, e só ali | Um fade no vidro inteiro |
| O mesmo sistema serve aos sete modelos e ao carro da cidade | Uma cena de cinema calibrada à mão |
| PS1 STYLE e MODERNO vêm da mesma simulação | Dois sistemas |

Referências de comportamento: o para-brisa de **Driveclub** (gotas que reagem a
aceleração, vento e limpador), a chuva no cockpit de **Gran Turismo 7** e de
**Forza Horizon 5**. Como ponto de partida procedural para as gotas paradas,
**"Heartfelt"** (Martijn Steinrucken, Shadertoy). O projeto não tem nenhuma
referência de chuva no vidro em `PRINTS/`; vale juntar duas ou três antes da
Fase 5.

---

## 3. Critérios de aceite

Cada critério tem uma medida. "Parece melhor" não fecha fase.

| # | Critério | Como mede | Hoje |
|---|---|---|---|
| C1 | **Buraco = 0,00%** nos 6 modelos, em 9 poses de cabeça (pitch −10/−4/+4 × yaw −35/0/+35) | `medir_cabine_cobertura.gd --poses` | 15,6–44,7% na pior pose |
| C2 | **Água fora do vidro = 0,00%** | sonda: a classe "placa" deixa de existir, e a água só é material dos vidros | 21–47% |
| C3 | Vidro da cabine sobre chapa = 0,00% e vidro da lataria sem vidro na cabine = 0,00% | sonda | até 7,5% |
| C4 | Nenhum vértice da cabine fora do casco | teste novo de contenção (paridade de raio contra o casco) | forro do Marea atravessa |
| C5 | **Sem piscar:** em 12 quadros seguidos com chuva=1 e limpador ligado, fora da faixa varrida naquele intervalo, ≤ 1,5% dos pixels do vidro mudam mais de 12 níveis | captura em sequência + máscara do setor | 11,1% em 8 quadros |
| C6 | **Limpa onde passa:** ≥ 90% dos texels que perdem água num quadro estão dentro do setor varrido nesse quadro | `--dbg-agua=mapa` (mapa de água em cor chapada) | pulso global |
| C7 | A ponta da palheta fica no plano do vidro (≤ 1 cm) no curso inteiro, e o leque cobre ≥ 70% da área do para-brisa vista pelo motorista | sonda do limpador | a ponta não se move |
| C8 | **Física:** parado, a corredora desce; a 60 km/h, no para-brisa ela sobe e abre para as bordas; na lateral, o rastro deita para trás (0° parado, ≥ 35° a 60 km/h); freada de 0,6 g empurra a água para a base do para-brisa; massa conservada; nenhum NaN | bancada offline | não há física |
| C9 | **A gota fica no vidro:** com a câmera girando ±6° em relação ao carro, a gota acompanha o vidro (±1 px) | 2 capturas com pitch diferente | placa presa à lente |
| C10 | PS1 STYLE cumpre C5 e C6, com refração em passo de pixel 480×270 e pontilhado **multiplicado** no alfa | mesmas medidas com `estilo=0` | — |
| C11 | **Orçamento:** no máximo +4 draw calls no plano de dentro; simulação ≤ 0,3 ms de CPU; cabine do jogador ≤ 2.500 triângulos | `--stats` | — |
| C12 | Nenhum risco de chuva dentro da cabine | captura com a cabine em cor chapada | chove dentro |
| C13 | Maçaneta, manivela, trava e apoio de braço aparecem com a cabeça virada 35° para a esquerda | captura | não existem |

A cabine do jogador é declaradamente uma **exceção** ao §10 do ART-BIBLE: é a
malha mais próxima da lente no jogo inteiro, e só existe uma por vez em alta
definição.

---

## 4. Arquitetura

```
Carroceria.montar(modelo)
 ├─ corpo, luzes, rodas ............................. (como hoje)
 └─ "aberturas"  ← MESMA tabela que desenhou o vidro de fora
        │
        ├──► CabineCasca     casca interna com as aberturas recortadas + revelações
        ├──► CabinePorta     forro, maçaneta, manivela, trava, apoio, alto-falante
        ├──► VidroCabine     UMA malha com todos os vidros, UV = mapa, UV2 = metros
        └──► AguaVidro       mapa de água persistente (SubViewport)
                 ▲  chuva, vento, aceleração, setor do limpador, trilhas
                 │
             Limpador ───────── palheta no plano do vidro, modos
             AguaCorredoras ─── gotas grandes na CPU + MultiMesh
                 │
                 ▼
        psx_vidro_agua.gdshader  (gotas paradas procedurais + filme +
                                  embaçado + refração + brilho + sujeira)
```

### 4.1 Fonte única das aberturas

`Carroceria.montar` passa a devolver `"modelo"` e `"aberturas"`: uma lista de
`{tipo, lado, poligono (espaço final do carro), normal, recuo}` para para-brisa,
janelas de porta, quebra-vento, janela fixa e vigia. Cada módulo (Marea, Fusca,
Caixa) ganha `static func aberturas(...)`, calculada **das mesmas tabelas e do
mesmo recuo** que desenham o vidro de fora (`vaos`, `SEG_PARABRISA`,
`SEG_VIGIA`, `inset 0,10`, `fora * 0,012`). Com isso o vidro de dentro não tem
como divergir do de fora. `CarroCabine._modelo_de`, que adivinha o modelo pelo
comprimento, sai.

### 4.2 Casca interna gerada do perfil

Os sete modelos já saem do mesmo motor varrido (`CarroceriaVarrida`, com
`ponto_lado` e `ponto_topo` sobre `PERFIL`). A casca interna é esse mesmo casco,
recuado 3 a 4 cm para dentro, com o giro invertido (virada para o olho) e
limitada à cabine: do corta-fogo ao encosto do banco de trás.

- As janelas são retângulos em (z, t) na tabela da lataria, então a casca é uma
  grade em (z, t) que **pula as células das aberturas**. A borda inclinada da
  coluna A vira trapézio.
- **Revelações são obrigatórias.** Entre a casca (3–4 cm para dentro) e o vidro
  (1,2 cm para fora) sobra uma fresta de ~5 cm. Sem as quatro faces que ligam a
  borda interna à borda do vidro, o olho vê a mata por essa fresta em ângulo
  rasante. O mesmo vale para a moldura do para-brisa (a faixa de 17 cm do item
  1.1).
- O teto sai de `ponto_topo`, e não de `altura − 0,015`. Com isso o forro nunca
  atravessa a lataria (C4).
- Coluna A, B e C, forro do teto e painel de chute passam a ser **recortes da
  casca**, e não caixas soltas.

### 4.3 Porta, acabamento e ficha por modelo

O forro de porta cobre a porta inteira, do painel até a coluna B e do piso ao
peitoril. Tem relevo em três faixas (baixa com alto-falante e bolsa, meio com
tecido, alta com friso) e leva:

- **maçaneta interna**: alavanca cromada numa concha escura;
- **manivela do vidro**: disco, braço e pomo, que é o certo para a época;
- **pino da trava** no peitoril, perto da coluna B;
- **apoio de braço com puxador**;
- tampa lateral do painel e retrovisor externo visto por dentro (o triângulo).

A variação entre carros vem de uma **ficha de cabine** por modelo
(`cabine_ficha.gd`):

- **Fusca**: painel de chapa na cor da lataria, velocímetro central, volante
  fino, piso de borracha, sem console.
- **Marea**: painel dos anos 90 com capelinha curva, console com rádio e
  difusores, banco de tecido.
- **Caixas**: painel reto dos anos 80.

A ficha também decide bancos (borda do banco do motorista, banco do passageiro,
banco traseiro e encostos de cabeça), cinto na coluna B, quebra-sol e retrovisor.

Novas células no `painel_atlas`, via `tools/gerar_estrada.py` (as linhas 2 a 7
têm células livres): tecido de porta com costura, grade de alto-falante, tecido
de banco, fita de cinto, cromo escovado e plástico texturizado.

### 4.4 Vidro de verdade

`VidroCabine` gera **uma malha só** com todos os vidros da cabine, a partir das
aberturas, e um material só, o que dá uma draw call.

- `UV`: o retângulo daquele vidro no mapa de água.
- `UV2`: posição **em metros** no plano do vidro, com U atravessando o vidro e V
  apontando **morro abaixo**. A gravidade é sempre +V, e o setor do limpador é um
  círculo de verdade.
- Tangentes geradas, para levar a normal da gota ao espaço de visão.

A placa presa à lente (`_montar_vidro`) e o trapézio chutado
(`_montar_janelas`) saem.

### 4.5 Mapa de água: estado que persiste

Um `SubViewport` por carro com cabine (só o do jogador), de 512×256 no MODERNO e
256×128 no PS1 STYLE. Os vidros ocupam retângulos proporcionais à área de cada
um. Canais:

| Canal | Grandeza | Sobe com | Desce com |
|---|---|---|---|
| R | **cobertura** de gotas paradas (0–1) | chuva × exposição do vidro × (1 + velocidade no para-brisa) | evaporação, **setor do limpador**, trilha da corredora |
| G | **filme** (trilha, resíduo da palheta) | trilha, fim de curso da palheta | escorrimento, evaporação |
| B | **embaçado** (lado de dentro) | umidade, chuva, janelas fechadas | desembaçador (máscara saindo das saídas de ar), janela aberta |

Atualização por **realimentação**: o `SubViewport` roda com
`render_target_clear_mode = NEVER`, e um `ColorRect` com
`psx_agua_sim.gdshader` lê o próprio quadro anterior (tela) e escreve o novo. Se
o spike reprovar isso no Compatibility, a alternativa é *ping-pong* entre dois
viewports. Todas as operações ficam num só passe, com clamp garantido, e usam os
uniforms:

- `dt`;
- taxa por vidro;
- dois setores de palheta (`pivô, r0, r1, ângulo_antes, ângulo_agora`);
- até 64 segmentos de trilha de corredora;
- máscara do desembaçador.

**Precisão — medido, não estimado (16/09).** Um passo de 0,0005 por quadro
(0,13 do degrau de 1/255) **desaparece inteiro** no RGBA8: 20 quadros somaram
0,0000 nos dois renderizadores. O arredondamento estocástico, que parecia a
saída elegante, entregou 0,0039 de 0,0100 no Forward+ e **nada** no
Compatibility — está reprovado. Com `use_hdr_2d` o mesmo passo soma 0,0098 de
0,0100 nos dois (RGBH em Forward+, RGBAF em Compatibility).

**Decisão: o viewport do mapa de água nasce com `use_hdr_2d = true`.** Onde ele
não existir, o caminho é engrossar o passo (menos quadros por atualização), e
não confiar em ruído.

### 4.6 Gotas paradas — procedurais, dirigidas pelo mapa

No `psx_vidro_agua.gdshader`, as gotas saem de uma grade de hash em **metros**
(densidade física igual em todos os vidros), em três escalas: 5, 9 e 16 mm, com a
maior achatada pela gravidade.

- Cada célula tem um limiar `τ` sorteado, e a gota **existe se a cobertura
  passar de τ**. O raio cresce com `smoothstep(τ, τ + 0,15, cobertura)`.
- Consequência: depois que a palheta passa, as gotas **reaparecem uma a uma**, em
  ordem aleatória e crescendo, sem uma linha de `TIME`. Onde a palheta passou a
  cobertura é zero e elas somem **exatamente ali**. É isso que cumpre C5 e C6
  por construção.
- Tamanho estilizado e físico: 6 a 14 mm de diâmetro. O tamanho real (1–3 mm)
  some em 480×270.

### 4.7 Corredoras — CPU + MultiMesh

`AguaCorredoras` simula até 24 gotas grandes por vidro (64 no total) em GDScript,
com massa, posição e velocidade em metros no plano do vidro.

- **Forças**:
  - gravidade projetada (sempre +V);
  - **arrasto do ar**, com o vento relativo projetado no vidro × velocidade²:
    no para-brisa sobe a rampa e abre para as bordas, na lateral deita para trás;
  - **inércia**, com a aceleração do carro projetada: freada, arrancada e curva.
- **Adesão**: a gota só anda quando a força tangencial passa do limite da massa
  dela. Parada, ela cresce com a cobertura em volta; andando, perde massa na
  trilha e engole a cobertura por onde passa. O para-e-escorrega sai disso, sem
  seno nenhum.
- **Desenho**: um `MultiMeshInstance3D` (uma draw call) de quadrinhos no plano
  do vidro, 0,5 mm para dentro, com `psx_gota_corredora.gdshader`. É uma lágrima
  alongada pela velocidade, com refração e brilho. A trilha vai para o mapa
  (G sobe, R desce).
  **`INSTANCE_CUSTOM` só existe em `vertex()`** — lido no `fragment()` dá
  "Unknown identifier" e o shader inteiro não compila. Vai por `varying`
  (medido no spike F).
- **Palheta**: a corredora dentro do setor é arrastada até a borda e solta no fim
  do curso como resíduo.

A entrada vem de uma API única, `definir_movimento(vel_local, acel_local)`:

- `CarroCena` deriva de `velocidade` e `_curva`;
- `Carro` deriva de `linear_velocity`, filtrada (ver as armadilhas de
  `VehicleBody3D` na memória do projeto).

### 4.8 Limpador de verdade

`Limpador` (novo):

- pivô no cowl, braço e palheta **no plano do para-brisa**, girando em torno da
  **normal do vidro**;
- tandem (os dois varrem para o mesmo lado), curso de ~95°, palheta cobrindo o
  raio de 0,12 a 0,55 m;
- cinemática de manivela, como hoje (desacelera nas pontas);
- **automático, sem tecla** (decisão de 16/09). O modo segue `Clima.chuva` com
  histerese, para não ficar trocando na borda:
  - sem chuva: desligado, e a palheta termina a passada e volta ao repouso;
  - garoa: intermitente, com a pausa encurtando conforme a cobertura do vidro
    sobe (3–6 s);
  - chuva: velocidade 1;
  - temporal: velocidade 2.

  Quando a chuva para, dá mais uma ou duas passadas para secar o vidro e
  desliga;
- entrega ao `AguaVidro` o setor varrido em cada quadro.

A lataria ganha a flag `com_limpadores` (como `com_vidros_frente`), para o carro
com cabine não desenhar os braços parados da tampa.

### 4.9 Embaçado por dentro

O canal B é independente da água de fora: nem a gota nem o limpador o tocam.

- Cresce com umidade e chuva; o desembaçador abre a partir da base, no leque
  parabólico clássico, com uma textura de máscara.
- A cena controla o nível: a abertura pode ter mais embaçado no plano longo.
- Onde está embaçado, **tudo** atrás sai desfocado, inclusive as gotas, que
  viram manchas moles.

### 4.10 Óptica

| Camada | Como |
|---|---|
| Lente da gota | normal do perfil hemisférico → espaço de visão → deslocamento na tela, **invertido** (a gota é lente convexa) |
| Filme | ondulação de ruído correndo ao longo de +V, refração fraca proporcional a G |
| Embaçado | desfoque de **8 amostras**: `textureLod` na tela não desfoca em nenhum dos dois renderizadores (spike G), o xadrez sai intacto no nível 4 |
| Brilho | realce pela luz dominante; **amostra clara atrás da gota acende a gota** (poste, farol, relâmpago de `relampago.gd`) |
| Borda | tom da cabine à noite e do céu de dia, no máximo 12%, e não 45% |
| Sujeira | poeira em metros no vidro, **limpa no leque das palhetas**: é o que faz o limpador ler de longe |
| PS1 STYLE | deslocamento em passo de pixel 480×270, raio em degrau de texel, alfa com Bayer **multiplicado** |

### 4.11 Chuva com teto

Com `abrigo > 0`, `psx_chuva` recebe a caixa da cabine no espaço do carro e
descarta o risco dentro dela. É uma troca de um uniform por quadro, feita por
quem já escreve `abrigo`.

### 4.12 Orçamento

| Item | Draw calls | Triângulos |
|---|---|---|
| Casca + porta + bancos (material do painel) | +1 | ~1.600 |
| Vidros da cabine (uma malha) | −2 (placa e duas janelas saem, uma entra) | ~120 |
| Corredoras (MultiMesh) | +1 | 128 |
| Limpadores (braço + palheta) | 2 (como hoje) | ~60 |
| Simulação 2D | +1 passe de 512×256 | — |
| **Total no plano de dentro** | **cerca de +1 a +3** | **≤ 2.500** |

---

## 5. Fases

Regra de convivência com as sessões paralelas: **trabalho novo em arquivo
novo**, e nos arquivos compartilhados só a ligação mínima, com edição cirúrgica.
Não mexer mais em `psx_parabrisa.gdshader`: ele é substituído, não consertado.

### Fase 0 — Linha de base e spikes · P · **FEITA em 16/09/2026**

- ✅ `game/tests/medir_cabine_cobertura.gd`, agora com `--poses` (9 poses de
  cabeça, meia resolução), e as imagens de `captures/cabine_chuva/antes/`.
- ✅ `game/tests/medir_limpador.gd`: a ponta da palheta anda **5 mm** no curso
  inteiro e fica a **48 cm** do plano do vidro, no Marea, no Fusca e no sedã.
- ✅ Estado da cabine e do shader commitado (1.11).
- ✅ `game/tests/spike_agua_compat.gd`, rodado nos **dois** renderizadores:

| Spike | Forward+ | Compatibility | Decisão |
|---|---|---|---|
| A/B persistência (`CLEAR_MODE_NEVER`) + tela no `canvas_item` | 0,3922 de 0,4000 | 0,3922 de 0,4000 | **é o caminho**: estado atravessa o quadro |
| C passo de 0,13 degrau em RGBA8 | 0,0000 | 0,0000 | some na quantização |
| C com arredondamento estocástico | 0,0039 de 0,0100 | 0,0000 | **reprovado** |
| D `use_hdr_2d` | 0,0098 de 0,0100 (RGBH) | 0,0098 (RGBAF) | **é o caminho** |
| E *ping-pong* | não cresceu | não cresceu | dispensado: A/B basta |
| F `MultiMesh` + `INSTANCE_CUSTOM` | OK (via `varying`) | OK | corredoras liberadas |
| G `textureLod` na tela (`spatial`) | sem mip | sem mip | embaçado por 8 amostras |

- ✅ Chuva dentro da cabine (C12), medida no código e na geometria: a chuva é
  uma caixa de 22 × 2 × 22 m que nasce 9 m acima da câmera e cai
  (`chuva.gd:15`, `:341`), o risco só desvanece a menos de 0,6 m da lente
  (`psx_chuva.gdshader:20`), e o para-brisa do Marea está a **0,28 m** do olho
  na perpendicular. Ou seja, existe uma faixa de risco desenhada **dentro** da
  cabine. `Chuva.abrigo` só mexe no som. Fica para a Fase 5, com o marcador de
  cor chapada.

### Fase 1 — Fonte única das aberturas · P/M · **FEITA em 16/09/2026**

- ✅ `game/src/render/aberturas_vidro.gd` (novo): a matemática das aberturas num
  lugar só — canto de janela, canto de para-brisa, escala do módulo, meia volta,
  normal para fora, área e lado.
- ✅ `aberturas()` no Marea, no Fusca e no módulo das caixas, lendo as **mesmas**
  tabelas que desenham o vidro (`VAOS_LADO`, `SEG_*`, `RECUO_FRONTAL`,
  `FOLGA_VIDRO`), que saíram de dentro das funções de desenho e viraram `const`.
- ✅ `Carroceria.montar` devolve `"modelo"` e `"aberturas"`, e aceita
  `com_limpadores` (medido: tira 4 triângulos do Marea; Fusca e caixas não têm
  palheta assada na chapa).
- ✅ `CarroCabine` lê `medidas["modelo"]`; o palpite por comprimento virou rede
  de segurança.
- ✅ `game/tests/checar_aberturas.gd`: nos 7 modelos, **todo canto de toda
  abertura cai em cima de um vértice do vidro desenhado** (folga de 1 mm), a
  normal aponta para fora e os dois lados têm o mesmo número de janelas. O teste
  começa por um auto-controle que desloca um canto 5 mm e exige que o comparador
  recuse — porque ele já deu "OK" uma vez com o módulo do Marea sem carregar.
- ✅ Sem mudança de imagem: a captura de fora antes e depois da Fase 1 difere em
  191 pixels de 921.600, dentro do ruído de duas execuções seguidas (622).
- ❌ **O "ajuste de arte do Marea" saiu do plano.** A faixa de chapa de 54 cm
  entre o para-brisa e o quebra-vento não é um painel sobrando: é a projeção da
  **coluna A inclinada** — entre as estações z = 0,88 e z = 0,44 a superfície de
  cima do carro É o para-brisa. A lataria está certa e a referência combina com
  ela. Quem inventava vidro era a cabine.

### Fase 2 — Cabine fechada · G · **FEITA em 16/09/2026**

- ✅ `game/src/render/cabine_casca.gd` (novo): a superfície de dentro do carro,
  gerada do **mesmo perfil** que desenha a lataria — paredes com os vãos
  recortados, revelação de vão, moldura de para-brisa e de vigia, cantoneira do
  encontro parede/teto, forro do teto pela curva do casco, assoalho e tampas da
  frente e do fundo.
- ✅ `game/src/render/cabine_moveis.gd` (novo): o que não se deduz de perfil —
  peitoril, **maçaneta** em concha, **manivela de vidro**, pino de trava, apoio
  de braço com puxador, alto-falante, bolsa, bancos da frente, banco corrido
  atrás, console e câmbio.
- ✅ `game/src/render/cabine_ficha.gd` (novo): o que muda entre Fusca, Marea e
  caixas (cores, se tem manivela, alto-falante, apoio, banco traseiro).
- ✅ **O interior ganhou volume.** O piso morava na linha do capô, o que dava uma
  caixa de 45 cm: no Marea a janela ficava a 3,5 cm do chão, e é por isso que não
  cabia maçaneta nenhuma. Com o assoalho 10 cm acima da linha de baixo do casco,
  a porta tem 60 cm e o olho passa a ser medido do chão (80 cm) — antes ele
  estava **cinco centímetros abaixo do topo do para-brisa**, ou seja, o motorista
  dirigia espiando por uma fresta.
- ✅ Nada é mais posicionado pela largura do carro: tudo pergunta à parede **na
  altura da peça** (`CabineCasca.parede_x`, com `x_casco_fino` por bissecção). O
  lugar do motorista deixou de ser fixo em 40 cm — no Fusca o aro do volante
  atravessava a porta.
- ✅ `Carroceria` passa a tirar o plano do para-brisa das **aberturas**: nos
  carros de caixa a conta antiga punha a base do vidro 9,5 cm acima do capô, e o
  painel encostado nela nascia atravessando a chapa.
- ✅ Testes novos: `tests/checar_cabine_contida.gd` (C4) e `tests/ver_cabine.gd`
  (vitrine do interior de qualquer modelo em qualquer ângulo — é como se
  fotografa a maçaneta, que a cutscene nunca mostra).

Medido, no plano de dentro (`medir_cabine_cobertura`):

| Modelo | buraco antes | **buraco depois** | vidro da cabine sobre chapa | peça além da chapa |
|---|---|---|---|---|
| Marea | 25,53% | **0,00%** | 0,00% (era 3,08) | 0,00% (era 20,17) |
| Sedã / táxi | 15,30% | **0,00%** | 0,00% (era 5,24) | 0,00% (era 19,38) |
| Hatch | 17,45% | **0,00%** | 0,00% | 0,00% |
| Perua | 16,80% | **0,00%** | 0,00% (era 7,46) | 0,00% |
| Picape | 17,16% | **0,00%** | 0,00% (era 6,79) | 0,00% (era 15,46) |
| Fusca | 42,65% | **0,00%** | 0,00% | 0,00% (era 8,90) |

**O que ficou para a Fase 3:**

- Na varredura de **9 poses de cabeça** o buraco cai para 0,42% a 2,37% (era
  15,6 a 44,7). O que sobra aparece ao virar a cabeça, junto das janelas
  laterais — que são exatamente as peças provisórias que a Fase 3 troca.
- `checar_cabine_contida`: Marea, perua e Fusca passam; sedã, hatch e picape
  ainda têm 6 a 10 vértices 2,5 a 5 cm fora da chapa, na quina de cima do vigia.
- A água ainda é a placa presa à lente: de 0,18% a 11% do quadro recebe água
  fora do vidro, e a placa continua sendo maior que o carro.
- O interior lê CHAPADO: a casca é grande e usa duas células de atlas esticadas.
  A leitura (tom, contraste, células novas de tecido, grade de alto-falante e
  cinto) é trabalho da Fase 5, com a cabine já fechada.

### Fase 3 — Água só no vidro · M

- Novos: `src/render/vidro_cabine.gd` e `shaders/psx_vidro_agua.gdshader` (v1,
  com um mapa constante no lugar do simulado, para a fase entrar sozinha).
- `carro_cabine.gd`: sai a placa presa à lente, sai o trapézio, entra o
  `VidroCabine`.
- Fecha **C2, C3, C9**.

### Fase 4 — Água viva e limpador de verdade · G

- Novos:
  - `src/render/agua_vidro.gd` e `shaders/psx_agua_sim.gdshader`;
  - `src/render/agua_corredoras.gd` e `shaders/psx_gota_corredora.gdshader`;
  - `src/render/limpador.gd`;
  - bancada offline `tests/bancada_agua_vidro.gd`.
- `carro_cabine.gd`: `limpar()` vira `atualizar_clima(chuva, vel_local,
  acel_local, delta)`; os limpadores antigos saem.
- `carro_cena.gd:421`: passa velocidade e aceleração.
- Flag `--dbg-agua=mapa|cobertura|filme|embacado` para mostrar o mapa em cor
  chapada.
- Fecha **C5, C6, C7, C8**.

### Fase 5 — Óptica AAA · M/G

- `psx_vidro_agua.gdshader` v2: as três escalas de gota parada, lente invertida,
  filme, embaçado com desfoque, brilho de luz forte e relâmpago, sujeira com leque
  e PS1 STYLE.
- `psx_chuva.gdshader` e `chuva.gd`: caixa da cabine (C12).
- Calibração em capturas: dia, entardecer, noite e relâmpago × parado, 40 e
  70 km/h × MODERNO e PS1 STYLE. Comparar com as referências da Seção 2.
- Fecha **C10, C11, C12**.

### Fase 6 — Todos os carros · G

- `carro.gd`: ao entrar o jogador, monta `CarroCabine`, `VidroCabine`,
  `AguaVidro` e `Limpador` sob demanda; ao sair, desmonta. Guardar referência, e
  não buscar por nome (ver a memória "get_node por nome falha").
- `camera_rig.gd`: a primeira pessoa ao volante volta a existir quando o veículo
  tem cabine; a tecla alterna perto, longe e dentro.
- Só o carro do jogador simula.
- Critérios **C1–C13 no carro da cidade**, mais uma captura em primeira pessoa a
  60 km/h na chuva, numa avenida à noite.

### Fase 7 — Extras aprovados em 16/09 · G

**7a. Vidro de fora molhado e translúcido, em todos os carros.**

- O vidro da lataria sai do atlas opaco e vira uma superfície própria
  (`com_vidro_separado`), com `psx_vidro_fora.gdshader`: transmissão escura com
  reflexo do céu por Fresnel, mais água.
- **Carro do jogador**: lê o **mesmo mapa de água** da Fase 4. De fora se vê o
  leque da palheta e as corredoras deitando para trás.
- **Trânsito**: versão procedural sem simulação, com cobertura =
  `psx_chuva` × exposição e escorrido pela velocidade do carro.
- Interior de baixo custo para os carros do trânsito (bancos, encostos, painel
  em bloco, cerca de 150 triângulos), para o motorista e os bancos aparecerem
  através do vidro como na referência do Marea.
- **Orçamento**: +1 draw call por carro (vidro), com o interior barato junto do
  corpo. Conferir o teto de 120 do ART-BIBLE §10 com o trânsito cheio.
- **Critérios**:
  - captura chase e lateral com chuva: silhueta do motorista legível;
  - leque visível no carro do jogador;
  - nenhum interior de baixo custo vazando pelo casco (reusar o teste de
    contenção da Fase 2).

**7b. Reflexo do painel no para-brisa e retrovisor interno com imagem.**

- **Reflexo**: no `psx_vidro_agua`, o pé do para-brisa amostra a tela
  espelhada em torno da linha painel-vidro. É um reflexo fraco, mais forte de
  dia e mais fraco onde há água (a água quebra o reflexo). Sem viewport extra.
- **Retrovisor**: `SubViewport` de 96×32 com uma câmera para trás, presa ao
  espelho, com `cull_mask` sem a cabine. Atualiza a cada 2 quadros e só existe
  com a câmera dentro do carro. A imagem vai para a face do espelho, espelhada
  em X.
- **Critérios**:
  - com a cabeça reta, o reflexo aparece só no terço de baixo do para-brisa e
    some com cobertura acima de 0,6;
  - o retrovisor mostra a estrada atrás (captura com um marco atrás do carro);
  - custo ≤ 0,4 ms de GPU, medido com `--stats`.

**7c. Som do limpador e das gotas.**

- Assets novos:
  - `limpador_motor_loop` (zumbido do motor);
  - `limpador_ida` e `limpador_volta` (a palheta no vidro molhado);
  - `limpador_rangido` (vidro seco, tocado quando a cobertura sob o leque está
    abaixo de 0,15);
  - `gota_vidro_*` (4 variações de tique).
- `Limpador` dispara ida e volta **no instante** em que a manivela sai de cada
  ponta, e o rangido na última passada depois que a chuva para.
- Os tiques saem da **taxa de impacto** do `AguaVidro`, com panorama pelo vidro
  onde a gota caiu, somados ao `chuva_cabine_loop` que já existe.
- Tudo passa pelo `AudioDirector`, no bus da cabine.
- **Critérios**:
  - o som da palheta cai no mesmo quadro que a inversão do curso (±1 quadro);
  - o rangido só toca com o vidro seco;
  - os tiques somem quando `Clima.chuva` vai a zero.

Dependências: 0 → 1 → (2 ∥ 3) → 4 → 5 → 6, e 7 depois da 4 (7a e 7c leem o mapa
e o limpador; 7b precisa só da Fase 3). As Fases 2 e 3 só dividem
`carro_cabine.gd`, e cada uma toca funções diferentes.

---

## 6. Riscos

| Risco | Efeito | Saída |
|---|---|---|
| ~~Realimentação de `SubViewport` não persistir~~ | — | **medido na Fase 0: persiste nos dois renderizadores** |
| `use_hdr_2d` indisponível em alguma máquina | crescimento some na quantização | engrossar o passo e atualizar o mapa a cada N quadros (o arredondamento estocástico foi medido e reprovado) |
| ~~Tela sem mip em `spatial`~~ | medido: não há mip | 8 amostras fixas, só onde há embaçado |
| Sessão paralela reverter `carro_cabine.gd` | ligação some | tudo novo em arquivo novo; ligação de poucas linhas, fácil de reaplicar |
| A casca gerada ter giro invertido | parede some sem erro (memória "giro de face") | copiar o giro de `CarroceriaVarrida.quad` e testar com a sonda antes da porta |
| Primeira execução capturar o mundo meio montado | falso defeito | rodar duas vezes e confiar na segunda |

---

## 7. Como medir

```bash
GODOT=".tools/Godot_v4.7.2-stable_win64_console.exe"

# cobertura da cabine, 6 modelos (resumo no fim; PNG por modelo em --saida)
"$GODOT" --headless --path game --script res://tests/medir_cabine_cobertura.gd -- --saida="$(pwd)/captures/cabine_chuva/depois"

# plano de dentro com chuva, carro parado, captura no quadro N
"$GODOT" --path game -- --ver-estrada --estrada-plano=dentro --estrada-clima=chuva \
  --chuva=1 --molhado=1 --shot=/caminho/dentro.png --shot-frame=150 --shot-quit

# lataria vista de fora
"$GODOT" --path game -- --ver-estrada --estrada-plano=chase --estrada-clima=dia \
  --shot=/caminho/chase.png --shot-frame=150 --shot-quit
```

`--ver-estrada` não grava nada versionado fora do `--shot`. `--ver-abertura`
grava: ver a memória "ver-abertura suja capturas alheias".

---

## 8. Ideias levantadas no mapeamento (fora do pedido)

Decisões de 16/09/2026:

| # | Ideia | Decisão |
|---|---|---|
| 1 | **Vidro de fora molhado e translúcido em todos os carros** | ✅ aprovada → Fase 7a |
| 2 | Limpador e desembaçador na mão do jogador | ❌ trocada: **o limpador é automático durante a chuva** (§4.8) |
| 3 | **Reflexo do painel no para-brisa e retrovisor interno com imagem** | ✅ aprovada → Fase 7b |
| 4 | **Som do limpador e das gotas** | ✅ aprovada → Fase 7c |
| 5 | Janela que abre pela manivela (a chuva entra, o som abre, o embaçado cai) | em aberto |
| 6 | Mãos no volante em primeira pessoa | em aberto |
| 7 | Água escorrendo do teto para o para-brisa na freada | em aberto |

---

## 9. Evidência

- `captures/cabine_chuva/antes/cobertura_<modelo>.png`:
  - cinza = cabine;
  - marrom = volante;
  - azul = para-brisa;
  - vermelho = buraco;
  - laranja = vidro da cabine sobre chapa;
  - listra amarela = placa de água fora do para-brisa.
- `captures/cabine_chuva/antes/limpador_pisca_quadros_150_158_166_174.png`: o
  pulso global e as gotas em forma de cereja.
- `captures/cabine_chuva/antes/dentro_chuva_parado.png`: a janela esquerda como
  placa cinza com pontos pretos.
- `game/tests/medir_cabine_cobertura.gd`: a sonda.

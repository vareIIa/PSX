# PLANO MENU AAA — o que foi feito, o que isso ainda não é, e o que falta

> Frente: boot, travessia do tubo, tela de título e carteira de criação.
> Versão 1.0 — 15/09/2026 — branch `playable`
> Escrito depois da entrega, a pedido: *"pense no que falei e repasse para ver se
> merece AAA"*. A seção 2 é a auditoria de 15/09, escrita antes de executar; a
> seção 3 é o que a execução do plano achou em 16/09, e a 3.1 é o placar novo.
> A resposta continua não sendo um "sim" limpo — mas as cinco coisas que faltam
> agora estão nomeadas uma a uma no fim da seção 3.1.

---

## 0. O que "AAA" significa aqui

`docs/PADROES-ENGENHARIA.md` já fixou a tese e o `PLANO_UI_AAA.md` já a traduziu
para interface: AAA neste projeto não é mais efeito, é **rigor de estúdio grande
aplicado a uma apresentação deliberadamente limitada**. Três consequências que
valem para esta frente:

| é AAA | não é AAA |
|---|---|
| a regra mora num lugar e um teste a prova | a tela está bonita na captura de hoje |
| todo número veio de uma medida | o número foi ajustado até ficar bom |
| a tela obedece o preset que o jogador escolheu | a tela tem o look que o autor escolheu |
| o defeito não tem como voltar | o defeito foi corrigido |

---

## 1. O que foi entregue, com a medida de cada coisa

### 1.1 Os três defeitos relatados eram um só

O jogador relatou: *o personagem olhava de um lado para o outro da TV*, *ficava um
loop de som de TV ao apertar START*, e *essa tela precisa da predefinição do
sistema MODERNO*. Os três saíam da mesma sobra de implementação.

`cidade.gd` carregava a **Casa da Fumaça** atrás do véu ao apertar START
(`Interiores.entrar`, com o jogador junto), sentava uma câmera diante do tubo,
varria a sala em −20°, +18° e 0°, empurrava até a TV e só então abria o título —
com o `tv_chiado` da televisão tocando em loop do começo ao fim.

Aquilo foi escrito quando o menu nascia **dentro** de uma televisão física. Desde
que boot e título passaram a abrir na Estrada Velha (UI-BIBLE 6.2), a sequência
saltava para um lugar que a tela anterior não mostrou e voltava para o primeiro.

**Saiu inteira:** o bloco de 289 linhas de `cidade.gd`, trocado por 34. O que o nível faz no START agora é
soltar o jogador; a imagem pertence ao menu, que é quem tem a cena e o shader.

### 1.2 A travessia do tubo

O menu inicial **é** uma TV chiando, então o START entra nela em vez de cortar.
Um `t` de 0 a 1 manda em tudo durante 2,4 s:

| trecho | o que acontece |
|---|---|
| 0,00 – 0,42 | o vidro empena (`plunge` no `crt_overlay.gdshader`), a imagem amplia 1,30x a partir do centro, o fósforo estoura e a chuva de estática toma a tela |
| 0,35 – 1,00 | do outro lado: o véu afrouxa da dose de boot para a de título e a lente termina de andar até o carro |

As duas metades se sobrepõem de propósito entre 0,35 e 0,42: emenda seca entre
dois movimentos lê como dois cortes.

**Um achado de shader no caminho.** A estática do evento era refém do grão de
repouso — as duas linhas do shader faziam `static_v * grain * (… + burst * …)`.
No preset MODERNO, com grão 0,10, o pico da travessia entregava 0,12 de ruído: o
instante em que o jogador atravessa o vidro **não tinha chuvisco nenhum**, e o
único jeito de ver o efeito era escolher PS1 STYLE. Grão é ambiente, burst é
acontecimento; agora somam em vez de multiplicar.

**A lente.** A primeira tentativa foi 3,4 m de recuo com FOV 52 e a captura
reprovou: o recuo é medido do centro do carro, então 3,4 m num sedã de 4,3 m
deixa a lente a um metro do para-choque — a lataria tomava metade da tela,
cortada pela borda. Vale 5,2 m com FOV 58: o carro cresce 1,7x no quadro
(1,38 de deslocamento × 1,22 de abertura) e continua inteiro.

### 1.3 O preset de imagem chega nesta tela

Boot e título eram a **única** parte do jogo que ignorava `Settings`.

| o que era | o que é |
|---|---|
| `SubViewport` cravado em 480x270 | resolução vem de `Settings.resolucao_3d` |
| véu do tubo com números fixos no código | dose interpolada por `Menu._dose_psx()` |
| `cidade.gd` reescrevia grão/scanline/vinheta/aberração ao abrir o boot | o menu não toca na preferência do jogador |

`_dose_psx()` responde pela **imagem** e não pelo rótulo — média de `dither`,
`snap`, `affine` e o inverso de `luz_por_pixel` — porque PERSONALIZADO é um
estado comum e os dois testes de igualdade responderiam "não" para ele.

**Medido**, mesma cena, mesma noite, 1920x1080:

| | estrutura (desvio da luminância a 8x reduzido) | ruído (resíduo sobre borrado) | média |
|---|---|---|---|
| antes | 28,93 | 7,73 | 49,1 |
| depois | 31,98 | **5,78** | 60,0 |

**Custo**, também medido (`--stats=60`): pior quadro 6,1 ms e 165 fps nos dois
presets; a resolução maior custa **8,8 MB** de memória (121,5 → 130,3) e
**nenhum milissegundo**. O primeiro quadro custa 148,7 ms — é a cena montando, e
a memória do projeto já registrou que primeira execução não vale captura.

### 1.4 O que o `_forcar_post_crt` realmente fazia: nada

Ele empurrava grão 0,14, scanline 0,28, vinheta 0,7 e aberração 0,9 "para imitar
um tubo". Medido: `PSXPostLayer` e a `CanvasLayer` do menu estão os **dois** na
camada 150, e o menu entra na árvore depois — o pós nunca tocou um pixel desta
tela. Ele só pintava a cidade que o fundo da estrada cobre inteira, e era o único
lugar do jogo que reescrevia a preferência de imagem do jogador para mostrar uma
tela.

### 1.5 O título parou de trocar de fonte no meio da transição

O boot mostrava serif de 42 no meio do quadro; o título mostrava `psx_titulo` de
18 noutro lugar. Na transição, a marca do jogo trocava de fonte e de posição num
corte — o jogador lê "mudou de tela", e não "a câmera andou". Agora é o mesmo
rótulo, pelo mesmo construtor, subindo por tween enquanto a lente avança.

**E o halo voltou a ser concêntrico.** Ele já tinha sido consertado uma vez, no
construtor, e o `_process` desfazia a cada quadro: `(20,74)` na letra, `(18,70)`
no halo. O teste que guardava essa regra contava ocorrências de constante — um
proxy que passou a acusar justamente o código que tornou o defeito impossível.
Foi trocado por três asserções sobre a estrutura real.

### 1.6 A lista do título

Cinco `ColorRect` chapados de alfa 0,58 não leem como cinco itens: leem como um
bloco cinza de 120 px sobre a imagem, e ele cobria 28% do quadro justamente na
faixa onde estão o carro e a estrada. Agora são gradientes que morrem nas pontas,
com realce próprio para o item escolhido — o alfa da placa continua pertencendo
ao tween de entrada, porque dois donos no mesmo valor é como o clarão de dano se
apagava sozinho.

A largura da placa era **200 px cravados** contra um texto que nunca foi medido.
Agora sai do item mais largo, medido na fonte real: **137 px**.

### 1.7 A carteira da criação

O relato era "extremamente simples e limitada"; a medida achou defeito antes de
achar simplicidade. Na aba AGASALHO, o rótulo MODELO era impresso **dez pixels
dentro** do botão SEM, e a fileira de cores caía sobre a zona de leitura.

**Causa raiz:** desenho e altura eram números independentes — cada widget com um
offset solto dentro do próprio ramo do `match`, e o passo da linha em 22, 26 ou
32 escolhidos a olho. Três campos pedem 88 px; a coluna tinha 66.

**Conserto:** a altura da linha virou `rótulo + widget + respiro`, com o widget
saindo de uma tabela por tipo, e o documento cresceu porque a conta pediu (78 a
256, com 92 px de coluna). A pior aba hoje tem **4 px de sobra**, e o teste diz
isso em voz alta a cada execução.

**De passagem:** a foto 3x4 cortava a cabeça de quem é alto. A janela mostra
0,655 m de mundo (2 × 1,48 × tan 12,5°) e a lente estava fixa em 1,34, pondo o
topo do quadro em 1,67. Agora o centro é `altura − 0,27` — distância até o alto
da cabeça, a mesma foto para 1,50 m e para 2,00 m.

### 1.8 O chiado que não acabava

Dois loops, não um. O `tv_chiado` da Casa da Fumaça morreu com a Casa. O outro é
o rádio na frequência morta do fundo do menu: esconder o fundo desliga o
`render_target_update_mode` e **não** o `AudioStreamPlayer3D`, então ele seguia
tocando atrás da partida inteira, do outro lado de um menu fechado. Imagem e som
saem juntos agora.

**Regra nova, escrita no UI-BIBLE:** nesta tela não entra loop que o menu não
desligue. Na travessia só entram one-shots, cortados por `parar_ui` no fim do pico.

### 1.9 O que ficou provado por teste

`tests/checar_hud.gd` passou de 639 para **677 asserções**:

- nenhum par de placas do título se cruza, nenhuma encosta no título nem na linha
  de teclas, todo texto cabe na própria placa;
- para as sete abas da carteira, a coluna de campos acaba antes da zona de
  leitura (imprime a pior sobra a cada execução);
- a métrica de fonte foi reescrita para a regra nova de importação: as `.fnt`
  passaram a escala **inteira**, então pedir 16 devolve 1x e pedir 18 **dobra** —
  o motivo de prender o tamanho continua, mudou o modo de falhar.

Duas classes novas existem para o teste alcançar a regra: `TituloLayout` e
`CarteiraLayout`, `RefCounted`, sem `Node` e sem autoload, no contrato de
`CartaoLayout`.

---

## 2. Repasse honesto: isto merece o selo AAA?

**Merece em parte, e a parte que falta é nomeável.** Pela tabela da seção 0:

| critério | boot/travessia | título | carteira |
|---|---|---|---|
| a regra mora num lugar | ✅ | ✅ `TituloLayout` | ✅ `CarteiraLayout` |
| um teste prova a regra | ❌ **nada testa a travessia** | ✅ 28 asserções | ✅ 9 asserções |
| todo número veio de medida | ✅ | ✅ | ✅ |
| obedece o preset do jogador | ✅ | ✅ | ⚠️ não foi verificada em PS1 |
| o defeito não tem como voltar | ⚠️ parcial | ✅ | ✅ |

### 2.1 O que eu sei que não está AAA

1. **Nenhuma captura em PS1 STYLE.** Medi tudo no preset do jogador
   (PERSONALIZADO com valores modernos, `_dose_psx() = 0`). O ramo PS1 de cada
   tabela de constante — `CRT_BOOT_PS1`, `CRT_TITULO_PS1`, a opacidade — nunca
   foi olhado numa imagem. Rodei só o custo (6,1 ms, 121,5 MB) e a validação.
   **Isto é a maior dívida da entrega**, porque o preset PS1 é a identidade do
   jogo e eu passei a sessão inteira ajustando o outro.
2. **A travessia não tem teste nenhum.** Ela é tempo + shader, e o que existe é
   uma flag de captura (`--ver-partida`) que congela num quadro escolhido a mão.
   Nada afirma que `plunge` volta a zero, que a lente termina em 1,0, ou que uma
   interrupção no meio (save carregado, bandeira de captura) não deixa a câmera
   num ponto intermediário.
3. **O menu de título não tem mouse.** As placas são `MOUSE_FILTER_IGNORE`. A
   carteira, que é a tela seguinte, tem clique e hover. Duas telas vizinhas com
   contratos de entrada diferentes é exatamente o tipo de inconsistência que o
   UI-BIBLE existe para impedir.
4. **CONTINUAR não diz por que está apagado.** Sem save ele fica em `ITEM_MORTO`
   e aceitar não faz nada — silêncio como resposta a uma ação do jogador.
5. **O título só alcança o espaço de save 0.** Há três, com resumo pronto em
   `SaveGame.resumo()`, e só o menu de sistema em jogo chega neles.
6. **A tela de OPÇÕES não foi tocada.** Ela continua no vocabulário de papel, com
   11 linhas e o passo derivado à mão, e não passou pela régua nova. O pedido era
   "AAA de ponta a ponta no menu" e ela é uma das quatro telas do menu.
7. **A carteira tem 4 px de sobra na pior aba.** O teste reprova quem estourar,
   mas o layout não tem plano B: um campo novo em AGASALHO quebra a build em vez
   de reflowar. Duas colunas, ou rolagem, é decisão de design que ninguém tomou.
8. **Nenhuma captura de referência foi versionada.** `PRINTS/` não ganhou o boot,
   a travessia, o título e a carteira novos, então a próxima sessão não tem com o
   que comparar. (E `--ver-abertura` suja capturas alheias, então isso precisa ser
   feito com flag dirigida.)

### 2.2 O que não é dívida minha, mas trava o nível 2

Três texturas de outra frente estouram o teto de 256 px do ART-BIBLE e reprovam
`run_tests.gd`: `bar_faixa.png` (512x56), `bar_letreiro.png` (512x112) e
`npc_atlas.png` (256x288). No `HEAD` as três estão dentro do orçamento — foram
ampliadas no diretório de trabalho por outra sessão. Não toquei.

---

## 3. O plano, e o que a execução dele achou

> **Executado em 16/09/2026.** Fases A, B, C e D estão feitas; a E continua
> parada de propósito, e a razão está nela. O que cada fase achou pelo caminho
> está registrado aqui — quatro das cinco descobertas só apareceram porque a fase
> foi executada com medida, e não com olho.

### Fase A — Fechar o preset PS1 ✅

Doze capturas — boot, pico, título, espaços de save e as duas páginas de opções,
nos dois presets — versionadas em `captures/menu/` com o comando exato para
refazê-las. As medidas foram para o
comentário de `CRT_BOOT_PS1`, que era onde faltavam.

**Doze** capturas, e não seis: as fases C e D mudaram as telas depois da
primeira rodada, e referência que não bate com a build é pior do que nenhuma.
A tabela completa está no README; o resumo é que PS1 STYLE tem ~50% mais ruído e
um pouco menos de forma, nas quatro telas que mostram a estrada.

| tela | preset | nativo | estrutura | ruído |
|---|---|---|---|---|
| boot | MODERNO | 1600x900 | 31,48 | 5,61 |
| boot | PS1 STYLE | 480x270 | 27,41 | 8,39 |
| título | MODERNO | 1600x900 | 28,23 | 4,77 |
| título | PS1 STYLE | 480x270 | 25,91 | 7,81 |
| pico | MODERNO | 1600x900 | 49,83 | 6,57 |
| pico | PS1 STYLE | 480x270 | 46,09 | 12,02 |

**O que a fase achou, e eu não esperava:** a primeira rodada da medição comparou
número de preset com número de preset e concluiu que o PS1 tinha *menos* ruído
que o MODERNO — o oposto do desenho. A causa: em PS1 STYLE a **janela inteira**
renderiza em 480x270 (`content_scale_mode = VIEWPORT`), então o arquivo sai com
480x270 de verdade e o ruído dele mora numa grade quatro vezes maior. Medindo
cada um na própria grade, a relação é a que tem de ser. A armadilha está escrita
no comentário e no README das capturas.

**A pergunta em aberto tinha resposta:** o burst da travessia deixou de ser
multiplicado pelo grão e passou a somar, e soma tem teto — no pico, **0,12%** dos
pixels passam de 250 em MODERNO e **0,07%** em PS1. Não satura em nenhum dos dois.

**O que não deu para fazer:** o teste de identidade (a tela de hoje contra a de
antes desta frente) não roda — o `cidade.gd` do `HEAD` não compila contra o
`kit_bar.gd` do diretório de trabalho, porque outra sessão está no meio de uma
mudança ali. `git stash` dos meus arquivos devolve uma árvore que não é nem o
antes nem o depois. Fica registrado em `captures/menu/README.md` para o dia em
que aquela frente assentar.

### Fase B — Teste para a travessia ✅

`TravessiaCurva` — `RefCounted` puro com `plunge`, `burst`, `veu` e os dois
enquadramentos da lente. `menu.gd` e `cabine_fundo_criacao.gd` passaram a ler
dela; nenhum dos dois guarda mais uma cópia do número.

17 asserções: as duas pontas nascem e morrem em zero, o pico do vidro é 1,0
no meio da janela, uma varredura de 201 pontos sem degrau e sem véu voltando
atrás, as duas metades se sobrepõem, a lente anda para um lado só, não para
dentro do carro (sobram 3,05 m até a traseira) e cresce o carro 1,68x.

**O invariante que faltava, e que a fase transformou em regra:** a lente em
repouso só tem dois valores — 0 no BOOT, 1 no TÍTULO. Antes havia **duas telas de
título**: a do `--ver-menu` abria no plano largo e a do START no plano do carro,
e uma transição interrompida deixava a câmera onde o `await` foi abandonado.
Medido depois da regra: as duas telas diferem em **1,37 de 255**.

### Fase C — Entrada: mouse e os três espaços de save ✅

- As placas viraram área clicável de verdade (`MOUSE_FILTER_STOP`, 137x22 px):
  passar o ponteiro move o cursor, clicar aciona.
- CARREGAR entrou na lista (seis itens) e abriu a página dos três espaços, com
  resumo de `SaveGame.resumo()` na nota.
- CONTINUAR passou a ir para o save **mais recente**, e não para o espaço 0.
- Item apagado responde: clique grave e uma linha dizendo por quê.

**Três defeitos que só a execução achou:**

1. **O despacho por índice.** `match _selecionado` com 0,1,2,3 embutia a ordem da
   lista em dois lugares. Com CARREGAR entrando na segunda posição, cada item
   passaria a fazer o trabalho do vizinho de cima — MAPA abriria OPÇÕES, SAIR
   fecharia o jogo a partir de OPÇÕES. Passou a despachar por nome.
2. **A nota ilegível.** Ela nasceu em `ITEM_MORTO`, pela ideia de que uma linha de
   apoio deve sumir perto da lista. Medido: **15 níveis** de contraste — mancha,
   não texto. Resposta ilegível é o mesmo silêncio com mais trabalho. Com a cor
   dos itens vivos: **140**.
3. **A cortina preta no retorno.** Voltar de uma página interna refazia o fade de
   0,85 s a partir do preto, como se o jogo recomeçasse. A cortina passou a ser
   só para quando o título aparece do nada.

**E uma correção da própria correção:** eu escrevi, aqui e no código, que embaixo
disso havia um defeito de `Tween` — a cadeia encadeava `.parallel()` em toda linha
e a única sem ele era a cortina, então com a cortina desligada ela penduraria em
nada. **Não era isso.** A instrumentação mostrou o `Tween` rodando normalmente; a
tela vazia era a minha captura, tirada 83 ms depois do clique com meio segundo de
cascata pela frente. O `set_parallel(true)` ficou porque tira uma condicional do
caminho, mas é higiene e não conserto — e o comentário no código diz isso agora.
Deixar a explicação errada teria sido pior do que não ter explicação: a próxima
pessoa herdaria uma lição falsa com aparência de medida.

**E um defeito meu, de medição, que vale mais registrado do que escondido:** a
primeira versão do clique automatizado fotografava **5 quadros** depois de clicar
— 83 ms, contra meio segundo de cascata de entrada. A tela saía vazia e a
conclusão natural, e falsa, era que o clique não tinha funcionado. Passei um bom
tempo consertando um código que estava certo. O intervalo agora é de 45 quadros e
a razão está escrita em `ANTES_CLIQUE`.

### Fase D — A folha de OPÇÕES na mesma régua ✅

`OpcoesLayout` nasceu, e a primeira asserção que ele permitiu reprovou a tela:
**treze linhas não cabem na folha**. O passo caía para 13,03 px sobre uma linha
de 13 — três centésimos de pixel de ar.

A causa raiz não era o passo, e sim a **reserva**: a conta guardava 11 px (o
`fixed_size` da `psx_pequena`) para uma linha que mede 13. Dois pixels na última
linha são exatamente o *"VOLTAR entrou 2,6 px na moldura"* que o arquivo já tinha
registrado — e que foi corrigido mexendo no passo, o que apenas adiou.

Duas colunas não resolvem (a coluna de valor sozinha precisa de 125 px para
`> NEBLINA COM CHUVA`, e duas não cabem nos 384 do papel). A folha passou a ter
**duas páginas**, IMAGEM e SOM, que é a decisão que `menu_sistema.gd` já tinha
tomado para as mesmas listas. Com dez linhas na página cheia, o passo subiu para
16 px: três pixels de ar em vez de três centésimos.

### Fase E — Reflow da carteira ⏸ *(parada de propósito)*

Quatro px de sobra na aba AGASALHO é dívida conhecida, não urgência. Quando a
oitava aba ou o quarto campo aparecer: duas colunas na página da direita, com a
altura da coluna saindo de `CarteiraLayout` como já sai a da linha. Não fazer
antes — a regra de hoje é suficiente e mais simples, e o teste avisa no dia.

---

## 3.1 O placar depois da execução

| critério | boot/travessia | título | carteira | opções |
|---|---|---|---|---|
| a regra mora num lugar | ✅ `TravessiaCurva` | ✅ `TituloLayout` | ✅ `CarteiraLayout` | ✅ `OpcoesLayout` |
| um teste prova a regra | ✅ 17 asserções | ✅ 143 (com a página de saves) | ✅ 9 | ✅ 76 |
| todo número veio de medida | ✅ | ✅ | ✅ | ✅ |
| obedece o preset do jogador | ✅ medido nos dois | ✅ medido nos dois | ⚠️ não medida em PS1 | ⚠️ não medida em PS1 |
| o defeito não tem como voltar | ✅ | ✅ | ✅ | ✅ |
| teclado, mouse e controle chegam no mesmo lugar | — | ✅ provado por clique | ✅ desde sempre | ⚠️ só teclado |

`tests/checar_hud.gd`: **806 asserções** (eram 639 antes desta frente).

### O que ainda não está AAA, depois de tudo

1. **A folha de OPÇÕES não recebe mouse.** Ela é a única tela do menu que continua
   só de teclado. Não é difícil — o que falta é decidir se uma linha de papel
   ganha área clicável ou se o mouse ajusta pelas setas desenhadas.
2. **A carteira não foi fotografada em PS1 STYLE.** Boot, título, saves e as duas
   páginas de opções foram; a carteira da criação ainda não, e ela é a tela que
   mais depende de legibilidade de fonte pequena.
3. **O teste de identidade do PS1 continua devendo** (seção Fase A), e vai
   continuar enquanto o `kit_bar` de outra frente não assentar.
4. **A cascata de entrada não tem teste.** Ela é tempo, como a travessia era, e
   foi ela que escondeu o defeito do `Tween` por um bom tempo. A curva dela cabe
   no mesmo molde de `TravessiaCurva`.
5. **Nenhum controle de joystick foi exercitado.** O código responde
   (`InputEventJoypadButton` no boot, ações do projeto na lista), mas ninguém
   apertou um botão de controle nesta frente.

## 4. Arquivos desta frente

| arquivo | o que mudou |
|---|---|
| `game/src/ui/titulo_layout.gd` | **novo** — medidas da tela de título, função pura |
| `game/src/ui/carteira_layout.gd` | **novo** — geometria da carteira e das abas |
| `game/src/ui/menu.gd` | travessia, dose por preset, resolução do fundo, título único, placas em gradiente |
| `game/src/ui/cabine_fundo_criacao.gd` | `avancar_menu` (lente), `silenciar` (o chiado), guarda de headless |
| `game/src/ui/criacao.gd` | documento maior, linha derivada do widget, foto que acompanha a altura |
| `game/src/levels/cidade.gd` | a Casa da Fumaça saiu do START: 289 linhas fora, 34 dentro |
| `game/shaders/crt_overlay.gdshader` | `plunge`, e o burst deixou de ser refém do grão |
| `game/tests/checar_hud.gd` | +38 asserções (menu e carteira), métrica de fonte reescrita |
| `game/tests/run_tests.gd` | a guarda do halo virou estrutural |
| `docs/UI-BIBLE.md` | 6.2 revisada; 6.5, 6.6 e 6.7 novas; seções reordenadas |
| `game/src/ui/travessia_curva.gd` | **novo** — as curvas do START, aritmética pura |
| `game/src/ui/opcoes_layout.gd` | **novo** — a folha de OPÇÕES, medida |
| `game/src/systems/capture_tool.gd` | `--mouse=x,y` e `--clique`: a captura agora exercita o caminho do mouse |
| `captures/menu/` | **nova** — seis referências nos dois presets, com o comando e as medidas |

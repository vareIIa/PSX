# UI BIBLE — Contrato de Interface

> O que vale para tudo que é desenhado por cima da cena: HUD, cartão, prancha,
> menu, telas de aparelho.
> Versão 1.0 — 11/09/2026

Companheiro de `ART-BIBLE.md` (renderização) e `PADROES-ENGENHARIA.md` (processo).
A regra do projeto é que todo número de estética vem de documento canônico: para
interface, o documento é este, e `game/src/ui/ui_estilo.gd` é a mesma tabela onde
o código consegue ler.

---

## 1. Tela e área segura

| medida | valor | por quê |
|---|---|---|
| resolução interna | 480 × 270 | ART-BIBLE seção 2 |
| margem de segurança | **7 px** | abaixo disso o elemento entra no raio da vinheta do pós e no arredondamento da TV |
| respiro interno de cartão (`PAD`) | **6 px** | da borda do papel até o texto |
| vão entre linhas parentes (`GAP`) | **2 px** | título e a régua que o sublinha |
| vão entre blocos (`GAP_BLOCO`) | **4 px** | objetivo × dica × rodapé; com 2 px os três leem como um parágrafo só |

Nada de HUD encosta a menos de 7 px da borda. `tests/checar_hud.gd` afirma isso.

---

## 2. Tipografia — a seção que mais custou

As quatro fontes do projeto são bitmap (`.fnt`) e todas têm
`fixed_size_scale_mode = 2`, que é **escala livre**. Um `Label` que recebe `font`
e não recebe `font_size` usa o padrão do tema, que é 16 — e a fonte é esticada ou
encolhida para caber nele.

| fonte | tamanho nativo | altura de linha | o que acontecia sem `font_size` |
|---|---|---|---|
| `psx_pequena` | **11** | **13,0 px** | esticada 1,4545× → linha de 18,9 px |
| `psx_media` | **14** | 16,0 px | esticada 1,143× |
| `psx_titulo` | **18** | 21,0 px | **encolhida** 0,889× |
| `psx_mono` | **12** | 13,0 px | esticada 1,333× |

Medido por `tests/medir_fonte.gd`. Fonte de pixel em escala não inteira é
reamostrada: a grade do glifo deixa de bater com a da tela e o texto fica mole —
e a 480×270 ampliado 4× para 1080p, a moleza é ampliada junto.

### Regra

> **Todo `Label` com fonte de bitmap prende também o tamanho.**
> Use `UiEstilo.aplicar(rotulo, fonte)`. Nunca `add_theme_font_override` sozinho.

Telas desenhadas à mão (`gps.gd`, `celular.gd`, `ficha_cadastro.gd`,
`terminal.gd`, `radio_carro.gd`, `criacao.gd`) passam o tamanho direto no
`draw_string` e sempre estiveram certas. O problema era só das telas feitas de
`Label`.

### Grade vertical

Todo rótulo empilhado anda múltiplo de `UiEstilo.altura_da_linha(fonte)`. Não se
escolhe espaçamento a olho: pergunta-se à fonte.

### Medida de largura

`UiEstilo.largura(fonte, texto)`, que chama `get_string_size` no tamanho nativo.
**Contar caractere pelo `xadvance` do `.fnt` erra** — o `spacing` do arquivo não é
aplicado do jeito que o TextServer aplica. Na primeira medição deste plano a conta
manual deu 122 px onde o motor dá 106.

---

## 3. Camadas

A ordem importa mais que os números.

| camada | quem mora lá | recebe grão/dither/vinheta |
|---|---|---|
| 100 | minimapa (`CAMADA_MAPA`) | sim |
| 101 | cartão de missão (`CAMADA_CARTAO`) | sim |
| 150 | pós-processamento PSX (`CAMADA_POS`) | — |
| 160 | só o que precisa sobreviver ao pós inteiro (`CAMADA_ACIMA_DO_POS`) | não |
| 200 | apagão da vida zero (`CAMADA_APAGAO`) | não — cobre a tela inteira, inclusive a interface |

`minimapa.gd` explica a regra: *"um mapa nítido por cima de uma cena suja
denunciaria na hora que é uma camada de interface moderna colada num jogo que
finge ser de 1999"*.

> **Mudar a camada de um elemento é mudança de contrato visual, não de gosto.**
> Exige justificativa escrita no arquivo.
>
> A camada 200 é a exceção documentada: o desmaio tem de tapar HUD, clarão e
> menu. Justificativa em `desmaio.gd`. Sem essa nota, subir de camada é bug.

### 3.1 O canto da tela não existe (medido em 12/09/2026)

Ficar na camada 100 custa a vinheta de `post_psx.gdshader`:

```glsl
col *= smoothstep(0.95, 0.95 - vignette, length(uv - 0.5) * 1.35);
```

Com o `vignette` padrão de 0,45, o fator que multiplica a cor é:

| posição na tela | fator |
|---|---|
| canto exato (0, 0) | **0,000** |
| 7 px do canto — a margem da UI | 0,019 |
| 24 px do canto | 0,202 |
| meio da borda esquerda | 0,729 |
| meio do rodapé | 0,777 |
| centro | 1,000 |

Papel de luminância 247 a 7 px do canto chega a **4**. Não existe cor que
resolva; o menu de sistema gastou três capturas culpando cor antes de a medida
nomear o culpado, e só ficou visível ao subir para a 160.

**Regra:** nenhum texto de interface na camada 100 pode ter um canto de caixa
abaixo de `UiEstilo.VINHETA_MIN` (0,45). Ou o elemento anda para dentro, ou sobe
de camada com justificativa escrita. A conta mora em `UiEstilo.vinheta()` — cópia
literal da linha do shader — e `checar_hud.gd` reprova quem desobedece.

Quem sobrevive no canto mesmo assim: o minimapa e o cartão de missão, que são
**blocos de papel grandes**. O centro deles cai em 0,61 e só a quina apaga, o que
lê como papel gasto. Uma linha de texto não tem essa folga.

### 3.2 Em papel não se desenha luz

O feixe da lanterna nasceu ocre (`c9a227`), que é a cor de luz acesa. Medido no
papel, depois da vinheta e da quantização PSX: **0x42 contra um papel de 0x5a**.
Dois níveis. Invisível.

A regra do meio é mais forte que a intenção: sobre papel, tudo é tinta. O feixe
aceso é uma marca escura; o apagado é a ausência dela; o alarme é
`UiEstilo.DESTAQUE`, que é vermelho **escuro**.

---

## 4. Tinta e papel

Mesma paleta da prancha de inventário e do mapa. Com outra, cada pedaço de HUD
vira janela de um jogo diferente dentro deste.

| nome | valor | uso |
|---|---|---|
| `TINTA` | `#2a1f16` | texto corrente, contorno de papel |
| `TINTA_FRACA` | `#6a5a44` | dica de tecla, régua, valor secundário |
| `TINTA_TITULO` | `#7a3a22` | cabeçalho de cartão |
| `DESTAQUE` | `#8a2f1f` | seleção, alerta, seta de bússola |
| `PAPEL_SOMBRA` | preto a 45% | 2 px abaixo e à direita do papel |
| `PAPEL_LUZ` | `1.24, 1.19, 1.06` | multiplica `ui_papel` |
| `PAPEL_BORDA` | 1 px em `TINTA` | contorno do papel |

### Por que papel precisa de luz E de borda

Medido em `captures/ui/f1_cartao_aberto.png`, com névoa densa:

| estado | papel | fundo | contraste |
|---|---|---|---|
| textura crua, sem borda | 153 | 124 | **29 níveis (11%)** — lê como mancha |
| com `PAPEL_LUZ` + borda de 1 px | 166 | 122 | **43 níveis**, e a borda fecha a forma |

O preenchimento sozinho não separa duas superfícies claras. Quem separa é a
borda — é o mesmo motivo de `mapa.gd` contornar cada quadra no cartão do canto.

> **Todo painel de papel sobre a cena leva `PAPEL_LUZ` e borda de 1 px.**
> Sem os dois, ele desaparece em cena clara ou em névoa.

---

## 5. Tempos

| evento | duração | por quê |
|---|---|---|
| entrada de cartão (`T_ENTRADA`) | 0,34 s | acima de 0,4 s o jogador espera a animação |
| saída (`T_SAIDA`) | 0,40 s | |
| encolher (`T_ENCOLHER`) | 0,28 s | |
| leitura antes de encolher (`T_LEITURA`) | 12 s | duas leituras tranquilas de uma linha |

---

## 6. Layout é função pura

Onde cada coisa fica **não** se decide dentro do `_ready` do nó que desenha.

`CartaoLayout.montar(fonte, dados, com_dica)` recebe textos e devolve
`{papel: Rect2, caixas: [{nome, linhas, rect, alinhamento}]}` sem tocar em `Node`,
autoload ou cena. O HUD só aplica; a verificação automatizada mede o mesmo
retorno em milissegundos, sem montar cidade nem abrir janela.

É o mesmo desenho de `MalhaUrbana`, e pelo mesmo motivo: três lugares que nunca
se falam consultam a mesma resposta.

### Regras que o layout tem de cumprir

1. Dois retângulos de conteúdo **nunca** se cruzam.
2. Todo retângulo cabe dentro do papel.
3. Nenhum retângulo tem largura ou altura zero — um degenerado passa em qualquer
   teste de colisão e ainda assim é um buraco.
4. Nenhuma linha de texto transborda a própria caixa, medida na fonte real.
5. O papel inteiro cabe na área segura.
6. Campo vazio não vira caixa vazia: não vira caixa nenhuma, e o que vem depois sobe.

`tests/checar_hud.gd` afirma as seis, contra os **piores** casos que o jogo
consegue produzir — título que não cabe, objetivo de três linhas, dica comprida,
distância em quilômetro — e não contra o caso bonito que já se sabe que funciona.

---

## 6.1 Rota no mapa

`Rota.tracar(de, para)` é função pura da malha: A* sobre os cruzamentos, sem
carregar um chunk. Avenida custa 1,0 por metro, rua 1,18, viela 1,7 — o caminho
mais curto não é o que se explica, e uma rota que corta seis vielas é impossível
de seguir.

Medido em `tests/checar_rota.gd`: **0,05 ms a 128 m, 0,20 ms a 384 m, 0,65 ms a
768 m.** Traçada uma vez na escolha do destino, não por quadro; refeita só quando
o jogador se afasta mais de **34 m** (meia quadra) do corredor.

### Desenho

Tracejado de **núcleo vermelho com halo claro**, os dois traços na mesma fase.

> O halo é claro, e não escuro. A escala de valor do mapa já gasta o escuro:
> fita de prédio é `#4b4231` e o contorno de quadra é tinta. Uma rota
> vermelho-escura com halo preto cai na mesma faixa de valor e vira mais um
> risco escuro no meio de dezenas — medido: com halo escuro, **32 pixels de rota
> distinguíveis** na página do pause; com halo claro, **173**.

| | núcleo | halo | traço/vão |
|---|---|---|---|
| cartão (82 px) | 1,4 px | +1,4 px de cada lado | 5 / 4 |
| página (306 px) | 2,2 px | +1,4 px de cada lado | 5 / 4 |

Desenhada **depois** da vela do desconhecido: a rota atravessa quadra nunca
visitada por definição — é para lá que o jogador está indo — e por baixo da vela
sumiria justamente no trecho que importa.

Atribuir `Mapa.rota` põe o traçado no cartão do canto, na página do pause e na
tela do GPS de uma vez, porque os três são a mesma classe.

---

## 6.2 Fundo do boot e do título

Boot e título abrem sobre a **Estrada Velha** — serra escura, mata dos dois
lados, asfalto sumindo na névoa e o carro parado no acostamento. É a mesma cena
que a ficha e a criação de personagem já usavam de fundo (`CabineFundoCriacao`
monta `EstradaBuilder`, `CarroCena` e `CeuEstrada` num mundo próprio), com uma
lente própria: câmera fora do carro, 1,72 m de altura, 7,2 m de recuo, pitch
−3,5°, FOV 68.

> O som já dizia isso antes da imagem. `_ambiente_da_estrada` liga folhas e vento
> e abaixa o zumbido urbano desde sempre — e a tela mostrava outro lugar.

### Regras aprendidas aqui

1. **Um `SubViewport` filho de um `Control` invisível para de renderizar.** Por
   isso o menu tem a **própria** instância da cena, filha da `CanvasLayer` e não
   de um painel — emprestar a da criação exigia manter aquele painel visível e
   transparente durante o título inteiro.
2. **Uma `Camera3D` perde `current` ao sair da árvore** e não recupera ao voltar.
   Toda troca de pai de câmera termina em `make_current()`.
3. **A cena é montada na primeira vez que é pedida**, não no `_ready`. Montar uma
   estrada com mata e serra no `_ready` do menu cobraria o preço em toda carga da
   cidade, inclusive nos `--teste-*` que nunca abrem menu.
4. **A ordem das camadas é dita por extenso**, não por aritmética de índice:
   `mata → véu → cópia do quadro → CRT → texto do painel`. A conta antiga
   empurrava o `BackBufferCopy` para antes do fundo, e a captura saiu com a
   estrada bonita e **nenhuma letra na tela**.

### Véu em gradiente, não chapado

Medido: o fundo na faixa do texto tem mediana 20 e só 3% dos pixels passam de
140. O problema não é o brilho geral — é onde estão esses 3%: na copa clara em
cima, onde o título em oxblood pousa. Então o véu escurece o terço de cima
(62%) e o de baixo (55%) e deixa o meio limpo, que é onde a estrada some na
névoa e a imagem tem o que mostrar.

### Grilos

`grilo.wav` tem 0,18 s e `loop_mode = 0`. Não é um loop: é disparado em
intervalo sorteado (0,35 a 1,6 s) com afinação sorteada (0,88 a 1,14). Dois
grilos idênticos em cadência fixa leem como sinal de aparelho, não como mata.

### O preset de imagem manda nesta tela (15/09/2026)

Boot e título eram a **única** parte do jogo que ignorava `Settings`. Três coisas
mudaram, e as três são regra agora:

1. **A resolução do fundo 3D sai de `Settings.resolucao_3d`.** O `SubViewport` da
   Estrada Velha nascia cravado em 480x270 — a caixa da *interface*, que é outra
   coisa. Numa janela de 1920x1080 no preset MODERNO, o jogo renderiza o mundo em
   1280x720 e o menu renderizava em 129.600 pixels ampliados 4x: a primeira tela
   que o jogador vê abria pior que o jogo que ela anuncia.
2. **A dose do tubo é interpolada pelo estilo.** `Menu._dose_psx()` responde pela
   IMAGEM e não pelo rótulo — média de `dither`, `snap`, `affine` e o inverso de
   `luz_por_pixel` — porque PERSONALIZADO é um estado comum e nenhum dos dois
   testes de igualdade responderia por ele. Em PS1 STYLE o véu é o que sempre
   foi; em MODERNO ele cai para a ordem de grandeza que o próprio preset usa no
   jogo (grão 0,02, vinheta 0,18). O CRT não some: ele deixa de ser o assunto.
3. **O menu não reescreve mais a preferência do jogador.** `cidade.gd` empurrava
   grão 0,14, scanline 0,28, vinheta 0,7 e aberração 0,9 ao abrir o boot. Medido:
   aquilo nunca tocou um pixel desta tela — `PSXPostLayer` e a `CanvasLayer` do
   menu estão os dois na camada 150 e o menu entra na árvore depois — e só pintava
   a cidade que o fundo da estrada já cobre inteira.

### O START atravessa o tubo, não corta para outro lugar

O menu inicial **é** uma televisão chiando. Apertar START entra nela: a lente
avança do plano largo até o carro (`CabineFundoCriacao.avancar_menu`, função pura
de 0 a 1) enquanto o vidro empena, a imagem amplia a partir do centro e o fósforo
estoura — `plunge` em `crt_overlay.gdshader`. Do outro lado, o véu afrouxa para a
dose de título e a lista entra em cascata. 2,4 s, um `t` só mandando em tudo.

| trecho | o que acontece |
|---|---|
| 0,00 – 0,42 | travessia: `plunge` sobe e volta em meio seno, `burst` no cubo dele |
| 0,35 – 1,00 | do outro lado: véu de boot → véu de título, lente termina de andar |

As duas metades **se sobrepõem** entre 0,35 e 0,42 de propósito: emenda seca
entre dois movimentos lê como dois cortes.

O que havia antes era um minuto de Casa da Fumaça — carregava o interior atrás do
véu, sentava uma câmera diante de uma TV, varria a sala em −20°, +18° e 0° e só
então abria o título. Aquilo foi escrito quando o menu nascia **dentro** de uma
televisão física; desde que boot e título abrem na Estrada Velha, a sequência
saía para um lugar que a tela anterior não mostrou e voltava para o primeiro.

> **Regra de áudio desta tela: nenhum loop que o menu não desligue.** O chiado
> reportado pelo jogador vinha de dois: o `tv_chiado` da Casa da Fumaça (morreu
> com a Casa) e o rádio na frequência morta do fundo, que continuava tocando
> depois do menu fechado — esconder o fundo desliga o `render_target_update_mode`
> e **não** o `AudioStreamPlayer3D`. Imagem e som saem juntos, por
> `CabineFundoCriacao.silenciar`. Na travessia só entram one-shots, cortados por
> `parar_ui` no fim do pico.

### O título é um só

`Menu._fazer_titulo_serif` monta halo e letra com o mesmo corpo, o mesmo lugar e
a mesma caixa — e as duas telas chamam o mesmo construtor. O boot mostrava serif
de 42 no meio do quadro e o menu mostrava `psx_titulo` de 18 noutro lugar: na
transição, a marca do jogo trocava de fonte e de posição num corte. Agora ela
**sobe** durante o travelling e o painel de título assume no mesmo pixel.

> O halo já tinha sido consertado uma vez, no construtor, e voltava a cada quadro:
> o jitter do `_process` escrevia `(20,74)` na letra e `(18,70)` no halo. Regra:
> posição de rótulo em animação sai de constante, nunca de literal.

### O empilhamento do título agora tem teste

`TituloLayout` (`RefCounted`, sem `Node` e sem autoload) é a fonte única das
medidas da tela de título, e `tests/checar_hud.gd` mede a partir dela: nenhum
par de placas se cruza, nenhuma encosta no título nem na linha de teclas, todo
texto cabe na própria placa e a largura da placa sai do item mais largo medido na
fonte real — eram 200 px cravados contra um texto que nunca foi medido.

Isto fecha a pendência que a Fase 7 do `PLANO_UI_AAA.md` deixou escrita.

### A lista do título: entrada, mouse e a nota (16/09/2026)

Quatro regras novas, e as quatro vieram de medida:

1. **O passo da lista sai do conteúdo.** `TituloLayout.passo(n)` aperta a lista
   para caber entre o subtítulo e a nota, com piso em `PASSO_MIN`. Abaixo dele a
   saída não é apertar mais: é dividir a tela. Foi o que a lista pediu quando
   CARREGAR entrou e ela passou de cinco para seis itens.
2. **A lente em repouso só tem dois valores.** BOOT é 0 (plano largo), TÍTULO é 1
   (plano do carro). Sem isso havia *duas* telas de título — a do `--ver-menu`
   abria no plano largo e a do START no plano do carro — e uma transição
   interrompida deixava a câmera parada onde o `await` foi abandonado. Medido
   depois da regra: as duas telas diferem em **1,37 de 255**, que é o grão do
   tubo e mais nada.
3. **Item apagado responde.** CONTINUAR sem save engolia a tecla: nem som, nem
   letra. Agora há um clique grave e uma nota embaixo da lista dizendo o motivo.
   A nota nasceu em `ITEM_MORTO` e a captura reprovou — **15 níveis** de
   contraste, mancha e não texto. Com a cor dos itens vivos, **140**.
4. **A lista recebe mouse.** As placas são `MOUSE_FILTER_STOP` com 137x22 px de
   área real; passar o ponteiro move o cursor (um cursor só, não dois estados
   paralelos) e clicar aciona. Provado por captura dirigida, não por argumento —
   ver as bandeiras `--mouse=` e `--clique` na seção 7.

> **`Tween`: `set_parallel(true)` uma vez, nunca `.parallel()` por linha.** A
> entrada do título encadeava `.parallel()` em toda linha, e a única sem ele era
> a cortina preta — que é condicional. Medido com instrumentação, o `Tween` roda
> assim mesmo; a construção só estava correta por acidente. Declarar o paralelo
> uma vez tira a condicional do caminho.
>
> **E a lição que custou mais tempo foi de medição, não de código:** a tela de
> título voltava vazia numa captura tirada 83 ms depois do clique, com meio
> segundo de cascata pela frente. Passei um bom tempo consertando código que
> estava certo. Captura de tela clicável espera a animação — ver `ANTES_CLIQUE`.

### CONTINUAR vai para o save mais RECENTE

Ele carregava o espaço 0 e mais nada. Com os três espaços alcançáveis pela tela
ao lado, continuar no 0 faria o botão mentir para quem gravou no 2: "continuar" é
voltar para onde se estava, e não para o primeiro arquivo. A ordenação sai do
campo `quando` de `SaveGame.resumo()`, que é
`Time.get_datetime_string_from_system` e ordena como texto.

---

## 6.3 Faixa de estado da cidade

`FaixaLayout` + `HudCidade`, camada 100, rodapé centrado.

| bloco | quando aparece |
|---|---|
| ícone de lanterna | só com lanterna na mochila; o feixe encurta com a bateria e fica `DESTAQUE` abaixo de 0,25 |
| barra de vida | só quando a vida **cai**, por `T_LEITURA`; permanente abaixo de 40 % |
| lugar | sempre; encurtado por `UiEstilo.encurtar` |
| hora | sempre |

`LARGURA_MAX` é 264 e sai da conta da seção 3.1, não do gosto: com o papel
centrado, o canto inferior do texto fica em y = 261, e a 264 de largura esse
canto cai em x = 108, onde a vinheta dá exatamente 0,45.

O prompt de ação (`[E] ...`) é um segundo papel logo acima, com 3 px de vão.
Ele morava em `$Debug/Prompt` ocupando y 236..254 enquanto a faixa ocupa
248..263 — colisão de dez pixels que ninguém viu porque os dois números moravam
em arquivos diferentes. Agora os dois saem do mesmo layout.

O clarão de dano também é da faixa, atrás do papel: gradiente girado para a
direção do golpe, calculado no **espaço do jogador**
(`basis.inverse() * (origem - pos)`), nunca em ângulo de mundo menos yaw — a
primeira versão errou o sinal e a captura mostrou o clarão no lado oposto.

> Clarões consecutivos **matam o tween anterior**. Sem isso o tween velho
> continua correndo em paralelo a partir do valor que ele guardou e apaga o
> clarão novo no quadro seguinte — o defeito aparece como "a segunda pancada não
> pisca", e custou quatro capturas.

---

## 6.4 A hora

`Relogio` (`src/systems/relogio.gd`), instância única em `WorldState.relogio`,
salva em `save_game` no campo `hora`. `RITMO` 2,0: 22:43 até as 05:00 são 188
minutos reais, e o mostrador vira de minuto a cada 30 s.

---

## 6.5 Carteira da criação de personagem

`CarteiraLayout`, mesma família de `CartaoLayout` e `TituloLayout`.

**A regra:** a altura da linha de um campo é `rótulo + widget + respiro`, e a
altura do widget sai de uma tabela por tipo — nunca de um número escolhido à mão.

| tipo | widget |
|---|---|
| `celula` | 17 px |
| `lista` | 15 px |
| `cor` | 14 px |
| `faixa` | 16 px |

**Por que a regra existe.** Desenho e altura eram números independentes: cada
widget tinha um offset solto dentro do próprio ramo do `match` e o passo da linha
era 22, 26 ou 32 escolhidos a olho. A aba AGASALHO tem três campos, e o resultado
medido na captura era o rótulo MODELO impresso **dez pixels dentro** do botão SEM
e a fileira de cores desenhada por cima da zona de leitura. As outras seis abas
não mostravam nada disso — o defeito só aparecia com a aba certa aberta.

**O documento cresceu porque a conta pediu.** Três campos pedem 88 px e a coluna
tinha 66. Apertar já tinha sido tentado (22 px é menos do que os próprios widgets
ocupam); a carteira passou a ir de 78 a 256, com 92 px de coluna. `checar_hud.gd`
afirma, para as sete abas, que a coluna acaba antes da zona de leitura — a pior
sobra hoje é 4 px, na AGASALHO.

**A foto 3x4 acompanha a altura de quem está nela.** A lente estava fixa em
y = 1,34 e a janela mostra 0,655 m de mundo (2 × 1,48 × tan 12,5°): o topo do
quadro caía em 1,67, abaixo do alto da cabeça de quem tem 1,72 m. Agora o centro
é `altura − 0,27`, ou seja distância até o topo da cabeça — a mesma foto para
1,50 m e para 2,00 m.

---

## 6.6 Folha de OPÇÕES

`OpcoesLayout`, mesma família das outras três.

**A folha tem duas páginas: IMAGEM e SOM.** Não por gosto — por aritmética. O
creme do papel mede 185 px e a lista tinha treze linhas; com a altura de linha
real da fonte, o passo caía para **13,03 px** sobre uma linha de **13 px**: três
centésimos de pixel de ar. Duas correções anteriores trataram o sintoma mexendo
no passo (*"a décima terceira linha caiu 19 px fora do papel"*, *"VOLTAR entrou
2,6 px na moldura"*); a folha estava acima da capacidade desde que o som entrou
nela.

Duas colunas não resolvem: medido, a coluna de valor sozinha precisa de 125 px
para `> NEBLINA COM CHUVA`, e duas delas não cabem nos 384 px do papel. Paginar
resolve, e a decisão já existia — `menu_sistema.gd` pagina as **mesmas** listas
em IMAGEM e SOM desde a Fase 4. A troca é uma linha da própria lista (`SOM >` /
`< IMAGEM`), e não uma aba: a folha já navega com W/S e uma aba pediria outra
tecla para decorar.

| | linhas | passo |
|---|---|---|
| IMAGEM | 8 ajustes + `SOM >` + VOLTAR = 10 | 16,0 px |
| SOM | 4 volumes + `< IMAGEM` + VOLTAR = 6 | 16,0 px |

> **A reserva da última linha é a ALTURA DE LINHA, não o `fixed_size`.** A conta
> reservava 11 px (o tamanho nativo da `psx_pequena`) para uma linha que mede 13.
> Dois pixels na última linha são exatamente a moldura invadida. `checar_hud.gd`
> compara `OpcoesLayout.LINHA` com a altura real da fonte para as duas nunca mais
> divergirem em silêncio.

---

## 6.7 A travessia do tubo tem curva, e a curva tem teste

`TravessiaCurva` — `plunge`, `burst`, `veu` e os dois enquadramentos da lente,
como aritmética pura. Curva com degrau não dá erro: dá uma tela que fica com o
vidro empenado para sempre, ou uma câmera parada no meio do caminho.

`checar_hud.gd` afirma que as duas pontas nascem e morrem em zero, que o pico do
vidro é 1,0 no meio da janela, que o véu nunca volta atrás numa varredura de 201
pontos, que as duas metades **se sobrepõem** (o véu começa com o vidro ainda
empenado), que a lente anda para um lado só e que ela não para dentro do carro —
sobram 3,05 m entre a lente e a traseira, e o carro cresce 1,68x no quadro.

---

## 7. Verificação

```bash
# métrica das fontes — roda quando a importação de fonte mudar
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game \
  --script res://tests/medir_fonte.gd

# layout do HUD — roda a cada mudança de UI
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game \
  --script res://tests/checar_hud.gd

# captura do cartão nos três estados
.tools/Godot_v4.7.2-stable_win64_console.exe --path game -- \
  --ver-missao --shot=../captures/ui/f1_aberto.png --shot-frame=130 --shot-quit
```

Flags de captura da interface: `--ver-faixa` (faixa de estado),
`--ver-faixa=ferido` / `=grave` (barra de vida e clarão direcional),
`--hora=HH:MM` e `--prompt=TEXTO` (acompanham a faixa), `--ver-missao` (etapa nova),
`--ver-missao=tira` (depois de encolher), `--ver-missao=longo` (piores casos),
`--com-rota` (traça rota até a casa da fumaça; combina com `--ver-mapa` e
`--ver-gps`), `--ver-boot` e `--ver-menu` (as duas telas sobre a mata),
`--ver-carregar` (os três espaços de save), `--ver-opcoes` e `--ver-opcoes=som`
(as duas páginas da folha), `--mouse=x,y` e `--clique` (põem o ponteiro numa
coordenada **de interface** e clicam 50 e 45 quadros antes da captura — é o único
jeito de provar que uma tela clicável responde ao clique, e o intervalo existe
porque a cascata de entrada leva meio segundo: fotografar logo depois do clique
mede a animação, e não o resultado),
`--ver-partida` (aperta START por código e congela do outro lado da travessia;
substituiu `--ver-tv-reveal` e `--ver-tv-close`, que fotografavam um tubo de TV
que a tela não mostra mais), `--ver-aparencia --criacao-aba=AGASALHO` (a aba mais
cheia da carteira, que é a que decide a altura do documento) e `--noite=` para
fixar o humor da mata, sem o qual a captura sorteia e não compara com nada.

> `--com-rota` **abre o aparelho** antes de filtrar. A varredura de lugares roda
> em `Gps.abrir()`, e sem ela a lista está vazia, o filtro não acha nada e a rota
> sai vazia em silêncio — foi assim que a primeira captura desta frente saiu com
> o mapa sem traçado e pareceu bug de desenho.

---

## 8. Definição de pronto, em UI

As cinco de `PADROES-ENGENHARIA.md`, mais:

6. **Nenhum retângulo de UI cruza outro** — provado por `checar_hud.gd`, não por olhar.
7. Todo `Label` de fonte bitmap passou por `UiEstilo.aplicar`.
8. Todo número novo cita a seção deste documento no comentário.
9. **Nenhum canto de texto na camada 100 abaixo de `VINHETA_MIN`** — provado por
   `checar_hud.gd`, não por captura.

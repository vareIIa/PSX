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
`--ver-gps`), `--ver-boot` e `--ver-menu` (as duas telas sobre a mata).

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

# TASK — Praça da Matriz v2: a capela azul no meio do gramado

Documento de trabalho da **Praça da Matriz** (quadra `x 7..10 / z -3..0`). Serve
a quem continuar: diz o que as fotos pedem, o que já está no código e medido, o
que falta e como provar que ficou pronto.

Jogo: Godot 4.7.2, 480×270 PSX, `vertex_lighting`. O renderer foi trocado para
Forward+ por outra sessão, e as capturas agora saem em 1280×720. Branch
`playable`. Código em português, `class_name`, tipado, constante no topo com o
**porquê** escrito.
Godot: `.tools/Godot_v4.7.2-stable_win64_console.exe --path game`.

---

## Prompt para colar numa sessão nova

> Continue a Praça da Matriz do jogo PSX (Godot 4.7.2). Leia inteiro o
> `PROMPT_IGREJA_MATRIZ.md` na raiz antes de tocar em qualquer arquivo. As fotos
> de referência estão mapeadas no §2 e em `PRINTS/ref_igreja_azul/README.md`.
> O estado medido está no §4.
>
> Faça a fase **[B | C | D | E | F | G]** do §6, e só ela.
>
> Regras que não se negociam:
> - Outras sessões trabalham no mesmo repositório. Veja no §0 quem é dono de
>   quê, e avise antes de editar arquivo alheio.
> - Meça com `--olhar-igreja`, nunca com `--ir-para` (§7). Rode duas vezes e
>   use a segunda.
> - Não quebre as câmeras da abertura (§5.2). Não mexa na malha de ruas.
> - Conte os triângulos por chunk antes e depois (§5.1). O teto é 6.000, e a
>   praça já passa dele.
> - Marque como feito só o que foi medido. Observação livre não é critério.
> - Não faça commit sem o usuário pedir.

---

## 0. Quem mexe em quê

Havia pelo menos três sessões no repositório enquanto esta rodava. Arquivo que
muda sozinho não é bug seu.

| Área | Dono | O que isso quer dizer aqui |
|---|---|---|
| Malha de ruas, quarteirões, calçada (`malha_urbana.gd`, `chunk_builder.gd`, `vias`, `rotas`, `transito`, `ui/mapa.gd`) | sessão **psx-8a** | Ela **ancorou** a quadra da praça: RUA em x=224, VIELA em z=-96, avenidas em x=320 e z=0, área útil 79,8 × 83,8. Em `parque_builder.gd` ela só toca `planta()` (linhas de `via_x_em`) |
| `abertura.gd` (a cutscene) | **Cine2** | Não edite. Se uma peça quebrar um take, avise |
| `convidado.gd` (CasaViva, porta, dono) | outra sessão | `MoradorPraca` herda dele. Não mude a máquina de estados |
| Praça da Matriz: `planta_matriz`, `_praca_matriz`, `_chao_praca_matriz`, `_mobiliario_praca_matriz`, `rota_da_praca`, `pisos_da_matriz`, e a parte de igreja, casario, muro, cruzeiro e palmeira do `kit_parque.gd`, mais `morador_praca.gd` e `sino_igreja.gd` | **esta task** | — |

Antes de mandar mensagem a outra sessão, pergunte "quais arquivos são seus
agora". A resposta curta evita a colisão.

---

## 1. O que é AAA aqui

Não é polígono. É **a praça ser lida como um lugar de verdade a 480×270, de
noite e com névoa**. Critérios:

1. **A foto reconhece o jogo.** Posta uma captura ao lado de cada referência,
   quem conhece a capela reconhece a capela: o azul no lugar certo, as duas
   sacadas, o cruzeiro com o galo, o gramado, o muro branco.
2. **Cada peça tem motivo escrito no código.** Constante com o porquê, cota com
   a conta, e o histórico do que não funcionou.
3. **Nada aparece fora do lugar.** Nenhuma face coplanar piscando, nenhum buraco
   para o céu, nenhuma peça atravessando outra, nenhum poste dentro de parede.
   É exatamente isso que o usuário vê primeiro: o coreto "atravessando
   paredes".
4. **O lugar está habitado.** Vela acesa, harmônio atrás da porta, sino na hora
   cheia, gente andando, morador entrando em casa, fumaça de chaminé, lampião
   de parede, banco na calçada. E ninguém aparece para explicar nada.
5. **Cabe no orçamento, ou pelo menos não piora.** Triângulo por chunk medido
   antes e depois.

---

## 2. As referências, foto a foto

Guardar em `PRINTS/ref_igreja_azul/`. Os nomes e o que é azul estão no README
de lá.

| # | Foto | O que ela pede | Estado |
|---|---|---|---|
| 01 | Capela de frente, gramado | Fachada branca com o azul; porta azul com **bandeira**; duas sacadas; janela do frontão; anexo comprido à direita; palmeiras atrás; moitas na frente | **Feito** |
| 02 | Cruzeiro histórico | O cruzeiro domina o quadro, maior que a capela | **Feito**: é a composição do TAKE 5 (§5.2) |
| 03 | Cruzeiro hoje | Pedestal em degraus sobre **laje de placas**; canteiro com murete e guarda-corpo de tora; tocos; **muro branco** com portão; capela ao fundo à direita | **Feito** |
| 04 | Interior | Arco cruzeiro azul, altar-mor dourado com colunas torsas, lustre, altar lateral azul, bancos | **Fase B**, não iniciada |
| 05 | Cruzeiro com galo | **Galo** no topo; gramado com caminho até a porta; muro com **gradil azul**; **portãozinho azul**; anexo pequeno à esquerda; **cruz branca fina** na grama | **Feito** |

### 2.1 O que as fotos têm e o jogo ainda não tem

- **O interior** (foto 04), inteiro. Ver Fase B.
- **O cruzeiro de madeira da foto 05.** É outro cruzeiro, cinza e de tábua. O
  jogo tem um só cruzeiro, o de metal da foto 03, e herdou dele só o galo.
- **O entorno de cidade pequena.** Atrás da capela das fotos há mata e morro. No
  jogo, do outro lado da rua, há prédios de tijolo de seis andares (malha da
  psx-8a). Ver Fase C.
- **Sol.** As fotos são de dia e o jogo começa 22:43. Ninguém testou a praça de
  dia.

---

## 3. A planta v2

A quadra **não** cresceu. A malha é da psx-8a e está ancorada, e o pin do
acordar e a câmera da abertura estão cravados em coordenada de mundo. O que
cresceu foi a **praça dentro da quadra**. O casario foi para a borda, de frente
para dentro, com rua de pedra na frente, e o miolo virou gramado.

**Vão livre entre as fachadas de um lado e do outro: de 21 m para 58 m.**

Coordenadas locais ao centro da quadra, que fica em (270,9 · −51,1) no mundo.
Os eixos são +X leste e +Z sul. A capela olha para o sul, para o pin.

```
 z   -42 ┌───────────── rua de trás (pedra) ──────────────┐
     -37 │ casa│   ⌂      ┌── campo santo ──┐     ⌂  │casa │
         │ W1  │r         │   (x ±13)       │        r│ E1  │
     -19 │     │u  ┌── muro caiado + gradil azul ─┐   u│     │
         │ W2  │a  │ ⌂anexo  ⛪capela  ⌂anexo     │   a│ E2  │
      -3 │beco═╪═══╡portão   gramado     portão╞═══╪═beco│
         │     │   │  ✝       ║caminho║          │    │     │
      +4 │ W3  │   └── muro ═╡portão azul╞═ muro ─┘    │ E3  │
         │     │  ▦✠ cruzeiro     LARGO de pedra       │     │
     +15 │     │  grama │    faixa sul    │ grama      │     │
     +27 │     └────────┴──── rua sul ────┴────────────┘     │
     +31 │ ⌂  S1a  S1b   │entrada│   S2a  S2b  ⌂             │
     +42 └───────────────  portão sul  ─────────────────────┘
        x=-40  -29 -25 -20            0             20  25 29  40
```

| Peça | Onde (local) | Notas |
|---|---|---|
| Capela | centro (0 · −8), fachada em z −2 | Massa **inalterada** (12,4 × 12,0 × 7,0 + frontão 2,2; plinto 0,55) |
| Muro da frente do adro | z +4,0, x ±20, portão no eixo (±1,7) | Caiado, 0,92 m, nicho de vela nos dois pilares, placa de pedra em x +4,3 |
| Muros laterais | x ±20, de z +4,18 a −19 | Caiado 1,05 m + **gradil azul** 0,62 m; portão lateral em z −3 |
| Anexos | (−14 · −4) 5 m; (15,5 · −10) 7 m | Branco da capela, porta, janela e barra azuis, lampião aceso |
| Palmeiras | (−12,5 · −16,5), (12 · −17), (−2,5 · −18,8), (−22,8 · −14,5), (22,8 · 11) | Fuste de 11 a 14,5 m |
| Cruz branca | (−9,5 · 0,6) | 3,4 m, na grama |
| Cruzeiro | (−7,0 · 6,6), sobre laje (−13,4..−4,6 · 4,5..11,1) | Canteiro (−12,8..−9,6 · 5,0..10,2) com guarda-corpo em L; três tocos |
| Campo santo | centro z −29, 26 × 15 | Recuou de −25 para −29 para caber a palmeira de trás |
| Casario | fachadas em x ±29 (três trechos cada) e z +31 (quatro trechos) | Casas até x ±34,6 / z 36,6; quintal de 5 m até o gradil |
| Cabanas soltas | (±19,5 · −30), (±33,5 · 36) | Fora de esquadro, de propósito |

Quem desenha: tudo sai de `ParqueBuilder.planta_matriz()`. O chão sai de
`PISOS_MATRIZ`, que também alimenta o mapa. As peças novas estão em
`KitParque`.

---

## 4. Estado — o que está no código

### 4.1 Feito na v2 (esta sessão)

| Coisa | Arquivo | Prova |
|---|---|---|
| **Coreto removido** da Matriz. Ele atravessava o muro do adro depois que o muro avançou para +4,0, e o defeito era da sessão anterior | `parque_builder.gd` | Captura do pin: o coreto não aparece mais |
| **Buraco no chão consertado.** O ladrilho com centro no terreiro não era desenhado, meio ladrilho ficava fora da grama, e dali se via o céu. Agora a grama cobre a quadra inteira por baixo | `_chao_praca_matriz` | Vista de cima: as duas faixas azuis atrás da capela sumiram |
| **Planta v2** (§3): casario na borda, gramado no miolo, ruas de pedra, largo em T | `planta_matriz`, `PISOS_MATRIZ` | Vista de cima |
| **Muro caiado + gradil azul + portões azuis abertos** (fotos 03/05) | `muro_caiado`, `adro_capela`, `portao_lateral` | Captura do pin |
| **Velas nos nichos do portão** | `_praca_matriz` | Captura do pin: os dois nichos acesos |
| **Capeamento claro.** A rincheira em `concreto_sujo` saía marrom, e o capeamento do pilar lia como tampa de madeira. Agora vai em `reboco` | `muro_caiado`, `_pilar_caiado` | Captura do pin, antes e depois |
| **Anexos da capela** (fotos 01/05) | `anexo_capela` | Capturas do pin e do gramado |
| **Palmeiras-imperiais** | `palmeira` | Silhueta na névoa nas capturas do TAKE 5 e da foto 01 |
| **Cruz branca** (foto 05) e **moitas** no adro | `cruz_branca`, `arbusto` | Captura da foto 01 |
| **Cruzeiro no largo**, sobre laje de placas, com canteiro, guarda-corpo em L e tocos (foto 03) | `_praca_matriz`, `toco` | Captura da foto 01 |
| **Galo** no topo do cruzeiro e **corda** no braço direito | `_galo`, `cruzeiro` | Capturas do TAKE 5 e da foto 01 |
| **Porta azul com bandeira e cimalha**; o marco de pedra escura virou azul | `igreja_matriz` | Captura do pin |
| **Janelas laterais** da nave, duas com vela | `JANELAS_LATERAIS`, `velas_da_igreja` | Captura do gramado |
| **Casario com dono**: caiação de cor, barra pintada, porta pintada, moldura azul, alpendre, lampião, banco, vaso, chaminé, porta entreaberta com luz | `sorteio_da_casa`, `_modulo_colonial` | Captura da rua oeste |
| **Cachorros** sob o beiral do casario | `_telhado_de_casario` | (a névoa come) |
| **Fumaça** na chaminé das casas acesas | `_fumaca_da_chamine` | Não capturada |
| **Fileira com ponta aberta, consertado.** Nas fileiras que andavam para −X local sumiam as duas paredes de **ponta**, e não as paredes-meia | `fileira_colonial` | Código; não foi capturado de perto |
| **Oitão da cor da casa da ponta** (antes cada um escolhia a sua tinta) | `caiacao_da_casa` | Código |
| **Terra do canteiro acima da pedra.** Estava a 0,18, debaixo do calçamento de 0,22 | `canteiro`, `Y_CANTEIRO` | Captura da foto 01 |
| **Sino na hora cheia** | `sino_igreja.gd`, prop `"sino"` em `chunk_manager.gd` | Às 23:00 o log mostra 11 badaladas (§5.3) |
| **Moradores**: 3, nas casas do meio de S1b, S2a e E3, escolhidas pela linha reta até a rota | `_praca_matriz` | Não re-sondado nesta sessão |
| **Rota das pessoas** refeita: cada segmento entre dois pontos passa livre do cruzeiro, dos postes e dos bancos | `rota_da_praca` | Conferido na conta, **não** em jogo |
| **Bancos com lugar escrito** (4 no largo, 2 no gramado virados para a capela) | `planta_matriz` | Captura de perfil do banco do muro (§5.4) |
| **Comentário do `KitParque.banco` corrigido.** Ele dizia que quem senta olha para −Z local; o código sempre fez +Z. A primeira versão da lista seguiu o comentário, e os bancos do muro olhavam para o muro | `kit_parque.gd` | Código + captura |
| **Régua `--olhar-igreja=x,z,ax,az,ay`** + contagem de triângulos por chunk | `cidade.gd` | Todas as capturas desta sessão |

### 4.2 Herdado da v1 e ainda valendo

Paleta azul medida contra a luz quente (`AZUL #2f93cf`), cunhais, cornija e
cornija rampante azuis, as duas sacadas de 7 balaústres, janela do frontão,
sineira recuada, cachorros da capela, sacristia azul, `Lampada.Padrao.VELA`,
velas da porta e das sacadas, harmônio (`igreja_loop`) a 26 m com corte em
900 Hz, 4 pessoas circulando, `MoradorPraca`.

### 4.3 O que ninguém verificou

Anote como **não medido** até alguém medir:

- **Andar a praça inteira com o jogador**, procurando lugar que prende, degrau
  invisível ou buraco. Esta sessão só olhou por câmera fixa.
- **As pessoas e os moradores em jogo.** A rota nova foi conferida na conta.
- **A abertura rodando** (`--ver-abertura` suja 15 capturas versionadas, ver
  §7). O TAKE 5 foi conferido com a régua posta na posição da câmera dele, com
  FOV 70 em vez de 58.
- **`--stats`** (tempo de quadro) depois da v2.
- **A praça de dia.**

---

## 5. Medidas

### 5.1 Triângulos por chunk (teto do ART-BIBLE: 6.000)

Medido com `--olhar-igreja`, que agora imprime a grade:

| chunk | antes | v2 |
|---|---|---|
| (7,−3) | 6.364 | 6.402 |
| (8,−3) | 3.208 | 3.948 |
| (9,−3) | 6.552 | 6.600 |
| (7,−2) | 12.772 | 10.164 |
| **(8,−2)** igreja | **20.758** | **11.856** |
| (9,−2) | 7.784 | 10.448 |
| (7,−1) | 4.482 | 5.248 |
| (8,−1) | 6.358 | 6.838 |
| (9,−1) | 4.366 | 5.570 |
| **soma** | **72.644** | **67.074** |

O pior chunk caiu 43% com **mais** conteúdo. A queda veio de três coisas: quatro
fileiras saíram do chunk da igreja, cada muro lateral com gradil tem âncora
própria, e o descascado dos fundos das casas caiu de 3–5 manchas para 2.

**A praça continua acima do teto em 6 dos 9 chunks.** Ela já estava acima antes
desta sessão. Ver a Fase G.

### 5.2 As câmeras da abertura (Cine2)

A posição de cada peça nova foi conferida contra os takes:

- **TAKE 1 a 4** (câmeras a sudoeste do corpo, olhando para nordeste): o
  cruzeiro, o canteiro e os tocos ficam a oeste de x = −4,6, fora do cone. O que
  muda **ao fundo** dos TAKES 3 e 4 é o muro do adro, que era de pedra cinza e
  agora é caiado, e os dois bancos encostados nele. O poste perto do pin
  continua **morto** (índice 4) numa posição parecida com a do antigo, porque a
  luz do corpo foi afinada com ele apagado. O poste aceso mais próximo, em
  (7 · 12,5), a 8 m do corpo, ficou exatamente onde estava. Os outros acesos
  estão a mais de 11 m, fora do alcance.
- **TAKE 5** (a revelação, lente em (268,4 · −35,0)): o cruzeiro entra inteiro
  no terço esquerdo, com o galo contra o céu, e a capela fica no centro. É a
  composição da foto 02, e a sineira passou a aparecer atrás da nave. **Isso
  muda o quadro do Cine2.** A mudança é deliberada, mas a sessão dele precisa
  saber.
- **Um ponto da rota fica no portão** (0 · 4,6), como já ficava na v1. Às
  vezes uma pessoa aparece parada no portão no plano da revelação. Se o Cine2
  não quiser isso, basta tirar esse ponto de `rota_da_praca`.

### 5.3 O sino

`--sino-agora` produziu no log "teste — 3 badaladas" e as três badaladas.

**A virada de hora real foi medida.** Jogo rodando de 22:43 até passar das
23:00, com `--shot-frame=31800`, 8,8 minutos. No log saiu
`[sino] 23:00 — 11 badaladas`. Oito tocaram antes de a captura encerrar o
processo, o que bate com o intervalo de 2,6 s.

### 5.4 Os bancos

Captura de perfil do banco encostado no muro, lente em x +14,5 olhando para
oeste ao longo do muro: o encosto fica do lado do muro, e quem senta olha para
a praça.

---

## 6. Próximas fases — o roteiro AAA

Cada fase fecha com captura e medida. Fase que não fecha não vira base da
seguinte. Ordem sugerida: **B → F → C → G → E**. A D é opção do usuário.

### Fase B — O interior, primeiro pela fresta (foto 04)

**B1, vista pela fresta.** Hoje o vão da porta é uma placa acesa chapada. A
foto 04 é o que o jogador deveria ver ao encostar na porta entreaberta:

- abrir a face frontal da nave em três pedaços em volta do vão, do mesmo jeito
  que a placa clara já é partida (e pelo mesmo motivo);
- montar atrás do vão um vestíbulo de ~4 m de fundo, com faces **para dentro**.
  Cuidado com a regra do giro da face (§8, regra 3);
- no fundo, o **arco cruzeiro azul** (duas pilastras + arco em degraus, `AZUL`)
  e, depois dele, um painel `janela_acesa` dourado (altar) com quatro colunas
  escuras torsas na frente;
- um lustre: um ponto `janela_acesa` pendurado, mais uma `VELA` quente dentro;
- dois bancos de madeira no primeiro plano.

Critério: da soleira, com a lente em 1,62 m, a fresta mostra o arco azul e o
brilho do altar. De 13 m (do pin) continua lendo como porta entreaberta com luz.

**B2, a nave inteira** (se o usuário pedir): `InteriorNoMundo`, como a casa da
fumaça, com a porta abrindo de verdade.

### Fase C — A vizinhança (coordenar com a psx-8a)

Da praça se vêem prédios de tijolo de seis andares do outro lado da rua. Nada
na foto tem mais de dois pavimentos. Pedido à psx-8a: as quadras vizinhas da
praça, no lado que dá para ela, recebem **sobrados coloniais de dois
pavimentos** (`KitFachada.residencia`, com o casario e o telhado dele). A
decisão é do usuário; o código é da psx-8a.

### Fase D — Aumentar a quadra (opção, não recomendada agora)

É possível juntar a quadra da praça com a do norte, apagando o trecho da VIELA
em z = −96 entre x = 224 e 320. A praça iria para ~80 × 148 m. Custo: mexe na
malha, nas rotas de pedestre e no trânsito, tudo na área da psx-8a, que acabou
de ancorar essa viela. O ganho: fundo para o campo santo e mata atrás da
capela, que é o que as fotos têm. **Só com decisão do usuário e acordo da
psx-8a.**

### Fase E — A gradação da praça (do Cine2 / DIRECAO_PRACA)

Achados da v1 que **não** são desta task: contraste parede/chão de 10,8 : 1
contra 5,6 : 1 da referência, telha quase preta (luma 6,6), céu claro demais.
O renderer mudou para Forward+ depois dessas medidas. **Meça de novo antes de
qualquer conclusão.**

### Fase F — Vida

Especificação, nada disso existe:

1. **Na hora cheia, dois moradores saem de casa e vão até o portão** do adro,
   param e voltam. O sino vira acontecimento, e é a coisa mais barata de
   ligar: `SinoIgreja` emite um sinal, `MoradorPraca` escuta.
2. **Alguém acende a vela do nicho**: um convidado para diante do pilar do
   portão, e a `VELA` daquele nicho sobe de 0,4 para 1,4 em dois segundos.
3. **O sacristão**: o anexo grande tem porta e lampião. Um morador próprio que
   sai, fecha o portão lateral e volta.
4. **Grilos no gramado**: um emissor de ambiente por chunk de adro, como o
   `folhagem`.
5. **Rangido do portão** quando o jogador passa por ele.

### Fase G — Orçamento

Levar os chunks da praça para perto de 6.000. Em ordem de ganho estimado:

1. O descascado custa 4 caixas por mancha. Na fachada das casas, trocá-lo por
   uma variante de textura `reboco_descascado` (uma caixa).
2. O gradil tem uma barra a cada 32 cm. Um plano recortado por alfa com a
   grade pintada seria 2 triângulos por trecho. **Verifique antes se o recorte
   não cintila a 480×270.**
3. A subdivisão `2.5` das paredes do casario só é necessária onde bate
   lanterna. Nos fundos, usar `4.0`.

Meça antes e depois, chunk por chunk.

---

## 7. Réguas — como medir aqui

```
.tools/Godot_v4.7.2-stable_win64_console.exe --path game -- \
  --pular-menu --pular-abertura --nome-teste=Zeca \
  --olhar-igreja[=...] --shot="<abs>.png" --shot-frame=240 --shot-quit
```

| Flag | O que faz |
|---|---|
| `--olhar-igreja` | Lente fixa a 13,1 m da fachada, no eixo, no olho (1,62). Jogador fora da física. **Não** mexe na névoa nem na luz. Imprime os triângulos dos 9 chunks |
| `--olhar-igreja=d` | Mesmo eixo, a `d` metros da fachada |
| `--olhar-igreja=x,z,ax,az[,ay]` | Lente em (x · 1,62 · z) do **mundo**, olhando (ax · ay · az). As capturas da v2 usaram: TAKE 5 `268.4,-35.0,271.0,-54.75,3.2` · foto 01 `259.4,-33.6,264.4,-44.8,4.2` · gramado `283.4,-49.6,270.9,-59.1,3.4` · casario `254.9,-38.1,241.9,-40.1,2.2` |
| `--de-cima=x,z,tam,90,0` | Planta ortogonal vista de cima, com `fog_dia_sol` e sol próprio. Serve para achar buraco, não para medir luz. Praça inteira: `270.9,-51.1,100,90,0` |
| `--sino-agora` | O sino bate 3 vezes 2 s depois de nascer |

As armadilhas que já custaram medidas erradas:

- **`--ir-para` não é régua.** Um pedestre empurra o jogador, e a mesma linha
  de comando devolve enquadramentos diferentes. Isso já rendeu três conclusões
  falsas.
- **`--hora=HH:MM` é desfeito** pela largada do jogo antes de valer: o relógio
  volta para 22:43.
- **`--script` não carrega autoload.** `ChunkBuilder.construir` não compila
  fora do jogo (Settings, AudioDirector). Meça por dentro.
- **Rode duas vezes e use a segunda.** A primeira execução depois de mexer no
  código reimporta.
- **`--ver-abertura` suja capturas alheias**: 15 PNGs versionados. Não rode.
- Salve captura de trabalho no scratchpad, **fora** de `captures/`.
- Classe nova (`class_name`) pede `--headless --import` antes de rodar.

---

## 8. Contrato de render e regras que custaram caro

480×270 interno, `vertex_lighting`, `cull_back`, filtro nearest, dither,
texturas 256×256 que ladrilham.

1. **Meça antes de mexer.** Pixel cru, região conferida contra a imagem.
2. **`get_aabb` não vale.** A imagem é a medida.
3. **A face aparece do lado OPOSTO ao produto vetorial.** Já derrubou o Fusca,
   os carros de caixa e o chão da estrada.
4. **Com `vertex_lighting` a luz só existe no vértice.** Peça grande sem
   subdivisão fica preta mesmo com o facho no meio dela.
5. **Duas faces olhando para fora no mesmo plano piscam.** Separe por
   profundidade (tabela de F+ na fachada) ou mate uma (`faces_parede`).
6. **Recortar um piso por "centro dentro" abre buraco na borda.** Ponha uma
   camada inteira por baixo e desenhe a de cima por cima.
7. **A 480×270 só sobrevive feição grande.** A 13 m são 26 px/m. Balaústre de
   11 cm dá 2,9 px, que é o limite. Gradil a 10 m: barra de 6 cm.
8. **Luz colorida não vence albedo.** Azul debaixo de lanterna `ffc978` precisa
   de B/R da tinta perto de 4,4.
9. **Todo sorteio é função pura do índice** (`_ale`, `_tom`), porque nove
   chunks montam a mesma praça em threads separadas.
10. **Peça inteira sai do chunk que contém a âncora dela.** Peça comprida e
    cara (muro com gradil) ganha âncora própria, no meio dela.
11. **O Convidado anda em linha reta entre dois pontos quaisquer da rota.**
    Confira cada segmento, e não só cada ponto.
12. **`gerar_materiais.py` apaga `.tres` fora da tabela.**
13. **Conserte o mundo em vez de contornar. Relatório de outro agente não é
    prova.**

---

## 9. Critérios de aceite

Marque só o que **mediu**.

**Referência**
- [x] Fachada: cunhais, cornija, sacadas, porta azul com bandeira, janela do frontão (captura do pin)
- [x] Cruzeiro no largo, sobre laje, com canteiro cercado, tocos e galo (captura da foto 01)
- [x] Muro caiado com portão azul aberto; gradil azul e portão lateral nos muros do lado (vista de cima e captura do pin)
- [x] Anexos, palmeiras, cruz branca (capturas)
- [ ] Interior pela fresta (Fase B)

**Sem defeito**
- [x] Coreto fora; nada atravessa o muro do adro (captura do pin)
- [x] Vista de cima sem céu aparecendo pelo chão
- [ ] Andar a praça inteira sem prender e sem cair (**não medido**)
- [ ] Nenhuma face piscando ao andar de lado 3 m diante da fachada e do muro (**não medido**)

**Vida**
- [x] Sino dispara e toca (`--sino-agora`)
- [x] Sino na virada de hora: 23:00, 11 badaladas (§5.3)
- [ ] 4 pessoas e 3 moradores circulando sem atravessar nada (**não re-sondado**)
- [ ] Fumaça visível em pelo menos uma chaminé (**não capturado**)

**Orçamento**
- [x] Pior chunk não piorou: 20.758 → 11.856
- [ ] Chunks da praça perto de 6.000 (Fase G)
- [ ] `--stats=120` sem regressão (**não medido**)

### Achado fora desta task

- **Bancos do parquinho provavelmente de costas para a areia.** Em
  `ParqueBuilder._bancos_em_volta`, o comentário diz que "`giro` leva o −Z" e
  põe `PI` no lado norte, esperando que quem senta olhe para a areia. Pelo
  código do `KitParque.banco`, com `PI` o encosto fica do lado da areia. Foi
  deduzido pela conta e **não capturado**. Não mexi: não é da Matriz.

---

## 10. O que NÃO fazer

- Não edite `abertura.gd`. Se um take quebrar, avise o Cine2.
- Não mexa na malha de ruas nem nas linhas de `planta()`, que são da psx-8a.
- Não mexa na massa da capela (12,4 × 12,0 × 7,0 + 2,2): o enquadramento do pin
  depende dela. A superfície pode mudar.
- Não mude a máquina de estados do `Convidado`. `MoradorPraca` herda dela.
- Não rode `--ver-abertura`. Não apague `PRINTS/`, `captures/` nem arquivo não
  versionado sem revisar.
- Não substitua buraco por saliência, e não conclua nada de relatório alheio.

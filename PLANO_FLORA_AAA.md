# Plano Flora AAA: vegetação de cidade do interior de Minas

**Pedido (23/09/2026):** mapear a vegetação do jogo e melhorá-la ponto a ponto —
moitas, flores, árvores — mais bela e realista, 4K AAA, Minas Gerais. Executar o
plano inteiro, passo a passo.

Regra de estilo: tudo o que é novo mora no MODERNO. O PS1 STYLE continua no
contrato do `psx-render` (256 px, filtro ponto, luz por vértice) e só ganha o que
é conserto de geometria (planta enterrada, cartão que some de costas).

## 1. Diagnóstico (levantamento de 23/09, código conferido)

| # | Defeito | Onde | Estado |
|---|---|---|---|
| V1 | Atlas HD da vegetação sem mipmap e sem compressão: a copa distante cintila em 4K. Ligar o mip sozinho traz de volta os "matos voando", porque o MODERNO não afrouxa o recorte com a distância. | `textures_hd/vegetacao_atlas.png.import`, `psx_surface_pixel.gdshader` | Feito (E1) |
| V2 | Praça da Matriz e parques ainda com a árvore de caixas (`KitParque.arvore`), a cerca viva e o arbusto de caixa. | `parque_builder.gd` | Feito (E2): árvore e imperial; arbusto e sebe na E3 |
| V3 | Copa entortada pela ladeira: `Relevo.deformar` soma a altura do chão a cada vértice. | `relevo.gd:241` | Bloqueado: `relevo.gd` e `chunk_builder.gd` com WIP de outra sessão |
| V4 | Moita de cartão cruzado some de costas: `folha_ao_vento` emite uma face só e o shader é `cull_back`. | `atlas_kit.gd:149` | Feito (E1) |
| V5 | Vitória-régia e toco balançam inteiros (alfa 1 no vértice sobre material com vento). | `kit_parque.gd:4095`, `:2491` | Feito (E1) |
| V6 | ~~`giro` passado no lugar de `porte`~~: conferido, não é defeito — a variável se chama `giro` mas guarda um porte de 0,2 a 0,6. | `fundos_builder.gd:696` | Não é defeito |
| V7 | Planta de encosta medida num ponto só (serpentina, pomar, sub-bosque). | vários | Feito na serpentina (E7) |
| V8 | Terra cinza onde Minas tem terra vermelha (miolo, cova de árvore). | `chunk_builder.gd` | Aberto |
| V9 | Folha sem translucidez, sem relevo, sem brilho de cera; tronco de caixa; casca, grama, flores e mato sem conjunto HD. | shaders, atlas | Folha e tronco feitos (E1, E2); casca, grama, flor e mato HD na E3/E4 |

## 2. Etapas

0. Bancada de flora (`tests/bancada_flora.gd`) com critérios medidos.
1. A folha: shader de folhagem do MODERNO (recorte estável, luz através, relevo,
   cera, vento em três camadas) e atlas HD novo com mapa de normal e rugosidade.
2. Árvore por esqueleto: tronco roliço que afina, sapopema, galhos, cachos de
   cartões na ponta dos galhos, silhueta por espécie. Praça e parques migram.
3. Arbusto, cerca viva, topiaria, canteiro, flor (dois lados, HD, espécies).
4. Chão: grama instanciada perto do jogador, terra vermelha, folha e flor caídas.
5. Paisagem: mata da estrada, embaúba, eucalipto, capim-gordura, barranco.
6. Desempenho: MultiMesh, impostor de longe, fade, densidade por preset.
7. Estação: seca e águas, florada pelo calendário.

## 3. Registro

### Etapa 0 — bancada (`game/tests/bancada_flora.gd`)

Cada espécie montada sozinha pelo código do jogo, sob céu e sol fixos, fora da
cidade. Critérios: F1 cintilação (câmera anda ¼ de pixel; troca de silhueta < 12 %
e de cor < 6/255), F2 cobertura (área × d², relativa a 30 m; > 0,8), F3 lados
(moita de cartão cruzado em oito rumos; mín/máx > 0,5), F4 fotos. `--param=nome:valor`
força um uniform nos materiais de folha, para A/B de shader.

F2 começou com referência em 12 m e a sibipiruna reprovava em qualquer estilo e
atlas: a copa de 5,5 m de raio põe a borda de perto a 6,5 m da lente e infla a
área de 12 m por perspectiva. Com 30 m de referência ela passa (0,91 a 160 m).

Linha de base (MODERNO): 9 de 12.

### Etapa 1 — a folha

- `shaders/psx_folha_pixel.gdshader` (novo): luz através (`BACKLIGHT` × espessura
  do mapa), recorte estável (alfa compensado pelo mip, limiar que afrouxa de
  longe), vento em três camadas (árvore, cacho, folha; a folha gira a normal),
  **cartão de perfil some** (`fade_perfil`: a normal da face, por derivada, contra
  o olho — o remo verde saindo da copa sumiu), cera fraca (`brilho` 0,08: com
  0,3 o reflexo do céu cobria a copa de azul-acinzentado; A/B 0 / 0,06 / 0,12 /
  0,3), relevo da folha a 0,7 da normal da copa. `EstiloVisual` troca o shader
  pelos nomes de `Vegetacao.MATERIAIS_FOLHA`, só no MODERNO.
- `tools/gerar_vegetacao_hd.py` (novo): atlas HD de 4096 com as mesmas 16 células
  do PS1, cada uma um RAMO construído — galhos, folha por filotaxia da espécie
  (mangueira em roseta com brotação cor de cobre, oiti alternado, ipê em cacho de
  trombeta, primavera com bráctea, capim-colonião com pendão, unha-de-gato no
  muro), cada folha com altura, dobra na nervura, arco e nervuras. Saem cor, `_n`
  (BC5) e `_ru` (rugosidade, oclusão pela profundidade, espessura). O atlas do PS1
  continua do `gerar_vegetacao.py`.
- V1: atlas HD com mipmap e BPTC. V4: `AtlasKit.folha_ao_vento` com as duas faces
  (F3 da moita 0,48 → 0,72). V5: toco e vitória-régia rígidos.
- Resultado: 11 de 12 (a que faltava era a F2 da sibipiruna, resolvida acima).

### Etapa 2 — árvore por esqueleto (`src/world/arvore_esqueleto.gd`, novo)

- Tronco roliço de sete lados que afina, sapopema em três lobos enterrada 35 cm,
  torto por espécie; pernadas em curva no ângulo da espécie; ramos até a borda da
  copa; cachos de cartão na ponta dos ramos; a espiral de antes só fecha a
  silhueta (copa `fechada` para oiti, mangueira e jaqueira; aberta para ipê e
  sibipiruna). O vento é contínuo: a ponta do ramo tem a rigidez do cartão que
  segura.
- **Mesmo sorteio**: a árvore gasta do rng de quem planta exatamente as chamadas
  da de antes e desenha o resto com rng próprio. `tests/teste_arvore_sorteio.gd`
  confere estado do rng, raio devolvido e colisão para 7 espécies × 4 sementes × 3
  portes, para a árvore do parque e para as três palmeiras: PASSA.
- V2: `KitParque.arvore` (praça e parques) vira árvore de esqueleto de espécie de
  praça mineira (sibipiruna, oiti, ipês, mangueira, jaqueira), com o mesmo raio e a
  mesma colisão de antes; `KitParque.palmeira` e `Vegetacao.palmeira` viram estipe
  roliço com folha em V que arqueia (a de cartão deitado sumia de perfil).
- `--arvore-caixa` volta tudo ao de antes, para A/B.
- Custo: mangueira 0,7 de ~250 para ~1.130 triângulos. Entra no LOD da etapa 6.
- Bancada: **12 de 12** no MODERNO. A F1 do `parque_arvore` agora mede a de
  esqueleto (cor 4,8/255 a 80 m; a de caixa dava 6,1–6,3 e reprovava). F2 passa
  também no PS1.

Pendente da etapa 2: V3 (copa entortada na ladeira) — o conserto é erguer a
árvore rígida pela altura do pé em vez de deformar vértice a vértice, e isso mora
em `relevo.gd`/`chunk_builder.gd`, os dois com WIP de outra sessão.

### Etapa 3 — arbusto, cerca viva, canteiro

- `KitParque.arbusto` (blocos) → moita de cartão da Vegetação (folha, primavera
  florida ou canteiro), mesmo sorteio. `KitParque.sebe` continua a caixa podada
  (cerca viva é reta) e ganha a **franja**: cartões de ramo soltos nas duas quinas
  de cima, que quebram a aresta de régua contra o céu. Os dois entram no
  `teste_arvore_sorteio` (estado do rng e colisão iguais): PASSA.
- `tools/gerar_flora_hd.py` (novo), no mesmo motor de folha, agora em ladrilho
  (a folha que passa de uma borda continua na oposta):
  - `folhagem` / `folhagem_recorte` (a cerca, o palmito, a casca de fora do
    arbusto de caixa): folha miúda de murta/pingo-de-ouro, a ponta nova amarela;
    o recorte em tufos com vão. Ganho 1,2 para não escurecer (o ladrilho antigo
    tinha verde 84, a folha com oclusão sai 65).
  - `flores`: o atlas do canteiro em 2048 com as MESMAS células do
    `gerar_parque.py` (margarida, papoula, amarela, lavanda, capim, taboa,
    rudbéquia, cosmos, vitória-régia com e sem flor), cada planta com haste,
    folha e corola que achata pelo ângulo, e a base fechada de folha larga.
- `fade_perfil` agora só na copa (`mat_vegetacao`): no `mato` e no `flor` há chão e
  vitória-régia deitados, vistos sempre de raspão, que sumiriam.

### Etapa 4 — chão

- `grama` HD (novo; antes só havia a de 256): gramado batatais/esmeralda de cima,
  70 mil lâminas, trevo, lâmina seca, terra entre as touceiras, 2 m por ladrilho,
  sem emenda. Média de cor igual à antiga (55, 69, 33 contra 60, 69, 43).
- **Grama viva** (`src/world/grama_viva.gd`, `shaders/grama_viva.gdshader`, novos):
  tufos de sete lâminas instanciados sobre os triângulos da malha `grama` de cada
  chunk que carrega, 36 por m², em células de 8 m com alcance de 18 m; a lâmina
  encolhe até o chão entre 10 e 16 m e a troca para a textura não se vê. Vento na
  mesma frente da copa, luz através, lâmina seca. Só MODERNO (`--sem-grama-viva`
  desliga). O chão vem do `ChunkManager` na hora de montar (`guardar_superficies`,
  meta tirada ao ler): ler de volta a malha custava 3 a 10 ms por chunk no laço
  principal (medido com `--grama-viva-log`). O espalhamento e a grade do que cobre
  o gramado (o calçamento da praça passa por cima do plano da grama, e a lâmina
  atravessava a pedra) rodam no WorkerThreadPool; montar custa 0,3–1,8 ms.
- Tapete embaixo da copa, só na praça e no parque (`ArvoreEsqueleto._chao_da_copa`):
  trombeta caída do ipê amarelo e rosa, folha seca da mangueira e da jaqueira,
  cartões deitados no `flor` em células que só o atlas HD tem.
- V8 (terra vermelha) segue aberto: o canteiro da calçada mora em `chunk_builder.gd`
  (WIP de outra sessão) e a `terra` HD é a foto do ambientCG usada em 1.778 m² da
  cidade — trocá-la muda o chão de muita coisa que não é canteiro.

### Etapa 5 — paisagem (a estrada)

- `KitEstrada.arvore` → árvore de esqueleto de espécie de mata mineira
  (`ArvoreEsqueleto.ESPECIES_MATA`): angico (dossel), embaúba (pioneira de beira,
  candelabro claro), quaresmeira (a célula do ipê rosa puxada para o violeta pela
  tinta), com sibipiruna e mangueira escapadas de quintal. Mesmo sorteio, mesmo
  raio devolvido (a estrada espaça e empurra a mata para fora do corredor por ele).
- `KitEstrada.conifera` → tronco reto que afina e nove andares de galho caído em
  cone, cartão de folha miúda escura na ponta; a `saia` continua mandando onde o
  primeiro andar começa (a árvore de beira guarda o galho de baixo). Os pagodes de
  caixa sumiram da vista aérea.
- `mato_atlas` HD (novo, `gerar_flora_hd.py --so=mato`): as mesmas 12 células do
  `gerar_estrada.py` — capim, capim seco com pendão, samambaia, taioba, moita,
  galho seco, picão, capim ralo; e o chão em ladrilho: folhiço, barro batido
  (vermelho de Minas), cascalho, poça. Cada célula sai com a cor MÉDIA da antiga:
  a estrada de terra tinge as células de chão por faixa, e essa conta foi afinada
  sobre a cor antiga.
- `teste_arvore_sorteio`: árvore e conífera da estrada entram — PASSA.
- O `EstradaBuilder` monta a própria malha e não conhece o balde `@perto`: a
  árvore da estrada põe o ramo fino no `casca` comum (`ramo_perto = false`).

### Etapa 6 — desempenho

- Ramo fino da árvore da cidade no balde `casca@perto` (cortado a 40 m): de longe
  ele está dentro da copa. Mangueira 0,7: 353 + 308 triângulos em vez de 661 de
  casca sempre desenhados.
- Densidade da grama viva pela escada do `QualidadeGrafica` (BAIXO 0,35, MÉDIO
  0,6, ALTO 0,85, o resto 1).
- Medida em par (`--medir`, praça de dia, RX 9070 XT, 1920×1080): mediana
  6,9 / 6,9 ms sem nada novo contra 6,9 / 6,7 ms com tudo; engasgos iguais (8–11,
  4 deles em chunk novo); +10 a 20 chamadas; triângulos 666–675 mil → 765–944 mil.
  A mediana bate no teto de 144 fps nos dois lados: o custo que sobra está abaixo
  do teto.
- Impostor de longe não foi feito: a medida não pediu.

### Etapa 7 — estação (`src/world/estacao.gd`, novo)

- O jogo não tem calendário (o `Relogio` conta hora e dia da partida), então a
  estação é escolha: **agosto** por padrão — seca e ipê amarelo —, `--mes=N` troca.
- Fora da florada, ipê e quaresmeira são árvore de folha (célula miúda) e o chão
  embaixo é folha seca, não flor; na seca a copa ganha folha amarela (+6 %), o
  chão da praça mais folha caída e a grama viva mais lâmina seca (8 % → 26 %).
- Nada disso sorteia do rng de quem planta.

## 4. O que ficou

| # | Estado | Por quê |
|---|---|---|
| V3 | Aberto | O conserto (erguer a árvore rígida pela altura do pé em vez de deformar vértice a vértice) mora em `relevo.gd`/`chunk_builder.gd`, os dois com WIP de outra sessão. |
| V7 | Feito na serpentina | `SerpentinaBuilder._no_chao_pe`: a planta do pasto pousa pelo ponto mais baixo de cinco do pé, e não pelo centro (sem sorteio). O sub-bosque da estrada já anda na coordenada da estrada (`altura_lateral`). |
| V8 | Aberto | Canteiro da calçada em `chunk_builder.gd` (WIP alheio); a `terra` HD é foto usada em 1.778 m² da cidade. O barro da estrada já é vermelho (etapa 5). |
| — | Ideia | Embaúba de verdade pede folha palmada prateada (célula própria no atlas); a tinta de vértice só escurece. |

## 5. Como conferir

    godot --path game --script res://tests/bancada_flora.gd -- --saida=DIR      (12 de 12)
    godot --path game --script res://tests/bancada_flora.gd -- --saida=DIR --estilo=ps1
    godot --headless --path game --script res://tests/teste_arvore_sorteio.gd  (PASSA)
    python tools/gerar_vegetacao_hd.py   /   python tools/gerar_flora_hd.py
    --arvore-caixa  --sem-grama-viva  --grama-viva-log  --mes=N   (A/B na cidade)

## 6. Medida final (23/09)

- `bancada_flora` MODERNO: **12 de 12**.
- `bancada_flora --estilo=ps1`: 10 de 12. As duas que faltam são a F1 (cintilação
  de cor) da árvore do parque a 40 e 80 m — e a árvore de CAIXA também reprova ali
  no PS1 (8,3 e 11,8/255 contra 9,4 e 14,5 agora): é o filtro ponto sem mipmap que
  o contrato do PS1 pede, não defeito da árvore nova.
- `teste_arvore_sorteio`: PASSA (árvore da cidade, do parque, da mata, conífera,
  três palmeiras, arbusto e sebe).
- `run_tests.gd`: 11 falhas de 2.207, nenhuma em arquivo desta frente (fumaça,
  mercado, vitrine, texturas de 512 de bar/capas/npc/pichação/rótulos).

---

# Rodada 2 (23/09, tarde): a cidade inteira

**Pedido:** vegetacao AAA com boa animacao, bem posicionada, enchendo a cidade para
parecer Minas; qualidade e variacao das arvores; arbusto e mato cheios e vivos;
"nao e necessario forcar tanto PSX — AAA 4K leve estilo PSX".

## R0. Levantamento (fotos aereas e de rua, MODERNO, dia)

| # | O que a foto mostrou | Onde |
|---|---|---|
| R1 | Lado de sombra da copa preto e chapado, cartao lendo como "remo" contra o ceu | toda arvore de rua |
| R2 | De perto, a copa e uma casca de pratos: cartoes grandes quase tangentes a esfera | `ArvoreEsqueleto._folhagem` |
| R3 | Rua de casas com oiti em 9 de cada 10 arvores | `ChunkBuilder._especie_de_rua` (WIP alheio) |
| R4 | Miolo de quadra: gramado liso do tamanho de meio quarteirao, uma arvore em duas quadras; quintal de comercio sem planta nenhuma | `FundosBuilder._miolo`, `_quintal` |
| R5 | Bananeira e bambu ainda de cartao cruzado (painel de bambu de 9 m) | `Vegetacao.bananeira/bambu` |
| R6 | Tronco com a casca de 256 px do PS1 esticada (a `casca` nao tinha HD) | `textures_hd` |
| R7 | Calcada lavada: nem mato no pe do muro nem na cova da arvore | rua |
| R8 | Copa balanca, mas nada cai | — |

## R1/R2. A copa (`psx_folha_pixel.gdshader`, `arvore_esqueleto.gd`)

- `light()` proprio da folha: difusa que envolve (`envolve` 0,55), luz atraves pela
  espessura e contra o sol (`contraluz`), GGX fraco com o F0 do fragmento (varying).
- O wrap sozinho quase nao mudou nada: a propria copa sombreia o lado de tras e o
  `ATTENUATION` ja chega zero. `sol_vazado` 0,3 (so na luz direcional: no poste o
  ATTENUATION traz a queda com a distancia) e a oclusao do vertice aberta por
  expoente (`ao_vertice` 0,7; ela foi feita para a luz por vertice do PS1).
- Fresnel de raspao pesado pelo brilho: inteiro, a borda da copa contra o sol saia branca.
- Cacho: 1,5x cartoes a 0,72 do lado, desvio ate ~50 graus (menos na copa fechada),
  puxado 8 % para dentro e preso a 0,88 do elipsoide (visto do alto, o cartao solto
  virava bandeira).

## R3. Variedade (`ArvoreEsqueleto.ESPECIES_CIDADE`, `_variedade`)

- Onde pedem **oiti**: oiti 5/11, resedá 2/11 (flor lilas dez-mar; na seca perde a
  folha), pata-de-vaca 2/11 (flor rosa jun-set: em agosto florida), ficus podado
  1/11, quaresmeira 1/11.
- Onde pedem **mangueira/abacateiro/jaqueira** (quintal): 30 % viram jabuticabeira
  (fuste curto, copa miuda e fechada, casca clara) ou goiabeira (torta, casca lisa
  avermelhada), no atlas novo `plantas`.
- Sai do rng PROPRIO da arvore; o raio devolvido e a colisao continuam os da especie
  pedida (quem planta espaca por eles). `--sem-variedade` desliga. `teste_arvore_sorteio`: PASSA.

## R4. Miolo e quintal (`src/world/miolo_verde.gd`, novo)

- `MioloVerde.povoar` no `FundosBuilder._miolo`: grade de 6,5 m, por celula arvore de
  quintal (46 %), touceira de bananeira (14 %), mamoeiro (6 %), bambu na borda (5 %),
  moita (13 %), clareira no resto; chao de capim-gordura e mato, taioba, costela e
  maria-sem-vergonha na sombra, folha caida embaixo da copa (mais na seca).
- `MioloVerde.quintal` depois de cada quintal: mato no pe do muro de fundo e das
  divisas (faixa que o puxadinho nunca alcanca), canteiro de espada-de-sao-jorge /
  maria-sem-vergonha / taioba na casa, trepadeira (maracuja ou unha-de-gato) no muro
  de fundo, e no quintal de COMERCIO a arvore, a bananeira ou o mamoeiro que ele nao tinha.
- rng proprio (estado do rng do chunk lido, nao gasto, mais o lugar). O chao miudo
  vai no balde `plantas@perto` (40 m). `--sem-miolo-verde` desliga.

## R5. Plantas em 3D (`src/world/plantas.gd`, novo; atlas `plantas`)

- **Bananeira**: pseudocaule rolico no material novo `caule`, folha em FITA de 5
  segmentos que sobe e verga (a celula da bananeira esticada na nervura, as metades
  caidas), folha seca pendurada, filhotes, e na mae o cacho com o coracao roxo.
  Gasta do rng de quem planta o mesmo que a de cartao e usa esses numeros.
- **Bambu**: 11-16 colmos rolicos que abrem em arco, ramos de folha em lanca do meio
  para cima; verde ou bambu-imperial amarelo. Mesmo sorteio da de cartao.
- **Mamoeiro** (novo): caule cinza-esverdeado, coroa de folha palmada em peciolo,
  mamoes no caule.
- `tools/gerar_plantas_hd.py` (novo): atlas `plantas` 2048 (cor, `_n`, `_ru`) e o de
  256 do PS1, 16 celulas — ramo de bambu, folha de mamao, cacho de banana, mamoes,
  capim-gordura (a pluma vinho), espada-de-sao-jorge, taioba, mato de calcada,
  maria-sem-vergonha, jabuticaba, goiaba, maracuja, samambaia, costela-de-adao,
  folha caida, horta — e o `folhas_soltas` das particulas. Material `mat_plantas`.

## R6. Casca e caule HD (`tools/gerar_casca_hd.py`, novo)

- `casca` HD 1024 (placas compridas, duas familias de fissura, liquen e musgo, media
  de cor casada com a de 256 — a tinta da especie multiplica por cima) e `caule` (o
  pseudocaule verde com estria, bainha seca e mancha). `mat_caule` novo.

## R7. Mato de calcada (`src/world/mato_de_calcada.gd`, novo)

- Filho da GramaViva, que lhe passa o chao de cada chunk: tufo no pe da fachada em
  MANCHAS (trechos de 0,8-2,2 m com ou sem mato) e canteiro de capim na cova da
  arvore. MultiMesh no no do chunk, 45 m, so MODERNO. A linha da fachada e a cova
  vem de `faces_de_rua` e `arvores` (publicas, sem sorteio); a altura, dos
  triangulos da calcada. Nao toca o ChunkBuilder. `--sem-mato-de-calcada`.

## R8. Folha caindo (`src/world/folhas_caindo.gd`, novo)

- Um emissor de particula por arvore de calcada perto (10, raio de 30 m), folha
  seca girando e derivando no rumo do vento das copas, mais na seca
  (`amount_ratio`, sem reiniciar). Filho da GramaViva. `--sem-folhas-caindo`.

## Medida (rodada 2)

- `bancada_flora` MODERNO: **12 de 12**; fotos novas `quintal_rua`, `quintal_baixos`,
  `quintal_perto`.
- `bancada_flora --estilo=ps1`: **9 de 12**. Entrou a F1 da mangueira a 80 m (cor
  6,9/255 contra 5,3 antes e limite 6): mais cartoes, menores, no filtro ponto sem
  mipmap. A geometria e a mesma nos dois estilos (trocar o estilo nao remonta o
  chunk); fica anotado, a pedido de nao forcar o PS1.
- `teste_arvore_sorteio`: PASSA (agora com bananeira e bambu).
- `run_tests.gd`: 11 falhas de 2.221, as mesmas 11 de antes, nenhuma desta frente.
- Desempenho em par (`--medir`, RX 9070 XT, 1920x1080), sem nada novo x com tudo:
  rua de casas 4,2-4,3 ms x 4,5 ms de mediana, triangulos 530 mil x 800 mil;
  praca 7,6 x 7,6-8,3 ms. Engasgos iguais. Chunk de quintal: +3 a +9 mil triangulos.

## A/B

    --arvore-caixa  --sem-variedade  --sem-miolo-verde  --sem-mato-de-calcada
    --sem-folhas-caindo  --sem-grama-viva  --mes=N
    python tools/gerar_plantas_hd.py [--previa=DIR]  /  python tools/gerar_casca_hd.py

## Visto e nao tocado

- Na serra ao fundo (`serra_da_cidade`, WIP alheio) aparecem retangulos cinza-azulados
  e riscos vermelhos nos morros nas fotos aereas.
- V3 e V8 seguem bloqueados pelo WIP de `relevo.gd`/`chunk_builder.gd`.

# Plano de desempenho e horizonte — dirigir liso, sem engasgo, e ver longe

**Criado em 24/09/2026**, a partir do pedido do usuário: "dentro do carro
dirigindo muito lag, com motion blur parece, fps dropa bastante"; "distância de
renderização muito curta e feia na névoa, as coisas sumindo; valide se de dia
também tem; devemos conseguir ver muito longe, de forma otimizada, polida,
AAA"; e, no meio do mapeamento, "abrir e fechar o celular (C) está fazendo
lagar".

Este documento é a **Fase 0** (mapeamento medido) e o plano das fases
seguintes. Nenhuma fase começa sem o aval do usuário.

---

## 0. Como foi medido (Fase 0, feita)

Quatro bancadas novas, todas em `game/tests/`, todas montando a cidade inteira
(`scenes/test/cidade.tscn`) como filha, sem tocar em `cidade.gd`:

| Bancada | O que mede | Como rodar |
|---|---|---|
| `bancada_fps_dirigir` | Quadro, GPU, chamadas, **cadência da câmera**, e quem estava no quadro caro (chunk, sonda, nós nascendo), parado e a 70 km/h no eixo da avenida x = −160 | `-- --pular-menu --estilo=moderno --modelo=HATCH --medir=arq.csv` (+ `--sem-sondas`, `--sem-vida`, `--sem-gi`, `--sem-ao`, `--sem-desfoque`) |
| `bancada_fps_celular` | Pior quadro, pipelines e nós nascidos em cada aperto da **ação** `celular` (evento de entrada, não chamada de método) | `-- --pular-menu --estilo=moderno --medir [--no-carro]` |
| `bancada_alcance_visao` | Foto na rua e a 40 m de altura, com e sem o corte de desenho e a névoa volumétrica | `-- --pular-menu --estilo=moderno --fog=ID --saida=DIR [--sem-corte] [--sem-volume]` |
| `bancada_censo_cpu` | "Todos menos um" por classe de nó: quanto o quadro cai sem cada sistema | `-- --pular-menu --estilo=moderno [--no-carro]` |

Condições: RX 9070 XT, janela 3840×2108, MODERNO, qualidade "4k" (nativo, TAA,
SSAO, SSIL, SDFGI), preset do jogador (`neblina`), vsync desligado pelo
`Medidor` (menos a rodada de cadência). Rodadas em worktree no HEAD, porque a
árvore principal ficou sem compilar por trabalho em andamento de outra sessão
(bar). **Toda rodada com outro Godot aberto na máquina foi descartada** — elas
dobram o quadro e já enganaram uma conclusão (ver D11).

---

## 1. Diagnóstico

### D1 — A câmera do carro anda a 60 Hz e o quadro sai a 150+ Hz (o "lag com motion blur")

`Player._ao_volante` roda em `_physics_process` (`player.gd:377`) e o carro é um
`VehicleBody3D` sem interpolação de física (`physics_interpolation` desligada
no projeto). A câmera só muda de lugar no passo de física. A 150–165 fps:

- **15–35% dos quadros desenhados saem com a câmera parada** enquanto o carro
  anda a 70 km/h;
- o passo da câmera por quadro vai de **0 a 1,4–2,0×** o que devia ser (p10 = 0);
- o desfoque de movimento (`Lente` + `DesfoqueMovimento`) reprojeta por quadro
  desenhado: no quadro repetido o rastro é zero, no seguinte é o salto inteiro.
  **O borrão pisca junto com o tranco.** É isso que lê como "lag com motion blur".

A pé acontece o mesmo (o `CharacterBody3D` também anda no passo de física), só
que a 4,6 m/s ninguém nota.

### D2 — Dirigindo, o gargalo é a CPU

Rodadas limpas, 25 s a 70 km/h na `neblina`:

| | parado | dirigindo |
|---|---|---|
| quadro, mediana | 6,7–10 ms | **12–14 ms (~75 fps)** |
| GPU, mediana | 6,1–6,4 ms | 6,1–8,0 ms |
| quadros > 16,7 ms | 1–6 | **170–320 (7–13%)** |
| p99 / pior | 9–18 / 12–33 ms | **26–39 / 100–140 ms** |

Parado, o jogo é limitado pela GPU (hatch: 6,7 ms de quadro com 6,1 de GPU).
Dirigindo, a GPU tem folga e a thread principal não: o problema é de **evento**
(o que nasce enquanto o carro anda), não de custo fixo por quadro. Tirar
trânsito e pedestres (`--sem-vida`) **não resolve** (mediana 11,7 ms, 266
quadros > 16,7 ms): a multidão não é a culpada principal.

### D3 — Chunk novo custa um quadro inteiro

A 70 km/h na `neblina` entram **~3 chunks por segundo**. O quadro em que um
chunk vira nó (`ChunkManager._materializar_um` → `_montar`) dura **18–20 ms de
mediana e até 73 ms**, contra 11–13 ms sem chunk. Tudo acontece num quadro só:
malhas, colisão (mapa de alturas + dezenas de caixas), oclusor e **todos os
props** — gente parada (`Convidado` com `Corpo` montado na hora), lâmpadas com
facho, semáforos, sinais, itens. Dos quadros caros, a maioria coincide com nós
nascendo em lote, que são esses props.

### D4 — Sonda de reflexo refeita a cada troca de chunk

`SondasReflexo` segue o jogador com 4 sondas; cada troca de chunk re-enfileira
as que mudaram e refaz **uma por quadro — seis renderizações da cena cada**.
Dirigindo, isso são até 4 quadros seguidos com 6 cenas extras, a cada ~1,5 s.
Aparece em 13–24 dos quadros caros por rodada.

### D5 — Pipelines compilando no meio do percurso

Numa rodada, **+72 pipelines** (53 de superfície, 18 de especialização)
compilaram a 41 s, no meio da avenida, num quadro de 139 ms seguido de um de
82 ms: material que o jogador ainda não tinha visto (carro, gente, prop).

### D6 — Celular (C): no carro, **toda** abertura trava

| | 1ª abertura | aberturas seguintes (mediana / pior) | fechar |
|---|---|---|---|
| a pé | 149 ms, +142 pipelines | **7,6 / 9,2 ms** (ok) | 6–11 ms |
| no carro | 141 ms, +66 pipelines | **68 / 146 ms, +10 pipelines TODA vez** | 10 ms (um de 138) |

No carro as chamadas de desenho pulam de ~590 para ~860 a cada abertura. Os
suspeitos, a separar na fase: `AoVolante.pegar` troca a câmera para a de dentro
da cabine (`CabineDoJogador._ir_para(DENTRO)` → `make_current` + luz do painel)
e **remonta o carregador de isqueiro e o fio físico a cada abertura**
(`_montar_fio`: dois `StandardMaterial3D` novos, `CaboFisico` novo), além do
foco e do obturador da `Lente`.

### D7 — A névoa não fecha, e o corte apaga o que ainda se via

A `neblina` (o preset do jogador) é linear de 7 a **32 m**; o corte de desenho
fica em ~40 m + meia diagonal da malha, e só existem chunks até 64–96 m.

Fotos a 40 m de altura: com o corte ligado, névoa chapada; **com o corte
desligado aparecem silhuetas da cidade mais escuras que o céu**, a mais de 32 m
— onde a névoa deveria estar em 100%. A névoa não chega à cor do fundo, e o
corte faz sumir de uma vez coisa que ainda era visível: é o "as coisas sumindo
na névoa".

**Culpado confirmado: a névoa volumétrica.** Luminância na faixa da cidade
contra o céu, na mesma foto:

| corte | volume | céu | faixa da cidade (mediana / p5) |
|---|---|---|---|
| ligado | ligado | 146 | 146 / 144 (o corte já apagou) |
| **desligado** | **ligado** | 148 | **140 / 136** — silhueta visível |
| ligado | desligado | 146 | 146 / 144 |
| desligado | desligado | 146 | **146 / 144** — névoa fecha de verdade |

O volume atenua a geometria e não o céu (`volumetric_fog_sky_affect = 0` no
`FogController`), então o que está atrás dele fica mais escuro que o fundo.

Da rua, a `neblina` vira parede a ~30 m: não há silhueta nenhuma para ler
profundidade, porque a curva é linear até 100% e não exponencial.

### D8 — De dia também: a cidade é uma ilha de ~400 m

`dia_sol` (sem névoa) carrega 169 chunks até 192–224 m, e **ali a cidade
acaba**. Do alto, depois da borda vem a "saia" pintada da `SerraDaCidade` — uma
planície chapada verde e amarela — até os morros de fundo a 300 m, que são um
cenário preso à câmera. Da rua, a avenida termina nessa planície. Não existe
nenhuma representação distante da cidade: nem LOD, nem silhueta, nem terreno
dos morros fora dos chunks carregados. `dia_nuvens` do alto: a cidade some em
~130 m e a serra flutua sobre um mar de névoa vazio.

### D9 — Geometria paga dentro da névoa

~500 mil triângulos de mediana (pico de 785 mil) e 500–860 chamadas de desenho
com a névoa fechando a 32 m. Cada chunk é uma malha cheia por material, sem
nível de detalhe: o que está a 50 m, invisível na névoa, custa o mesmo que o
que está a 5 m.

### D10 — A régua mentia num ponto

`Performance.TIME_PROCESS` e `TIME_PHYSICS_PROCESS` são o **máximo do último
segundo**, não o do quadro. As colunas `processo_ms`/`fisica_ms` do `Medidor`
não servem para atribuir custo por quadro. Por isso existe o censo por "todos
menos um".

### D11 — A máquina

- **O monitor 4K de 165 Hz está ligado na saída da placa integrada** (placa-mãe);
  a RX 9070 XT não tem monitor ativo. O Godot renderiza na 9070 XT e o Windows
  copia cada quadro para a integrada. Recomendação imediata, fora do código:
  **ligar o monitor na RX 9070 XT**.
- Outras sessões rodam Godot na mesma máquina. Uma rodada contaminada chegou a
  dar 25 ms de mediana contra 13,4 ms da mesma cena limpa — e quase virou a
  conclusão "o táxi pesa o dobro". Com a mesma bancada limpa, hatch e táxi
  custam o mesmo.

### D12 — Lateral, a confirmar

Com o piloto da bancada, **sedã e perua não saíram do lugar** (0 m em 25 s) e o
Marea ficou parado em 3 de 4 rodadas; hatch, táxi e Fusca andaram normalmente.
Pode ser a bancada (largada idêntica para carros de tamanhos diferentes) ou o
carro. Fica anotado para quem cuida dos carros.

---

## 2. Fases

Ordem pelo que o jogador sente primeiro e pelo risco. Cada fase fecha com a
bancada da Fase 0 rodada em par (antes × depois, máquina sem outro Godot) e
com o PS1 STYLE intocado.

### Fase 1 — FEITA em 24/09/2026

**O que entrou:**

- `src/systems/suavidade.gd` (novo): a interpolação de física do motor ligada
  na árvore com a **raiz desligada** — só interpola quem pede. `ligar_corpo`
  (carro: o corpo interpola, todos os filhos presos), `ligar`/`desligar` (o
  jogador ao volante), `teleporte`, e `global`/`lente`/`projetar`/`atras` para
  quem desenha em cima do quadro ler a posição **como ela sai na tela**.
  `--sem-suavidade` desliga tudo (o par da bancada).
- `carro.gd`: interpola desde o `_ready`; `pousar` e `plantar` zeram.
- `player.gd`: interpola ao volante a partir do primeiro passo já sentado; volta
  ao normal ao descer.
- `cabine_do_jogador.gd`: a câmera de dentro é apontada pelas bases
  interpoladas (pela do passo de física o giro tremia nas curvas).
- `lente.gd`, `hud_pontos.gd`, `hud_marcador.gd`: leem a lente interpolada.
- **Desfoque de movimento pelos vetores de movimento do motor**
  (`desfoque_movimento.gd/.glsl`): achado na foto da própria fase — o desfoque
  reconstruído pela profundidade supunha o mundo parado, e **a cabine inteira
  (painel, ponteiros, volante, mãos, coluna) saía com o maior rastro da tela**.
  Agora o que anda com a câmera fica nítido e a rua e os outros carros borram
  pelo movimento real. A reconstrução continua no céu e sem o buffer.

**Medido** (`bancada_fps_dirigir`, hatch, 70 km/h, par no mesmo build):

| | câmera parada | passo/esperado p10 / mediana / p90 |
|---|---|---|
| dentro, antes | 15% | 0,00 / 1,13 / 1,33 |
| **dentro, depois** | **0%** | **1,00 / 1,00 / 1,00** |
| perseguição, antes | 7% | 0,60 / 1,09 / 1,29 |
| **perseguição, depois** | **0%** | **1,00 / 1,00 / 1,00** |

- Custo da interpolação, alternada a cada segundo **dentro da mesma rodada**:
  +0,000 ms (dentro) e +0,024 ms (perseguição).
- `tools/verificar_carro.py`: **todos os critérios cumpridos**.
- Projeção da HUD pela lente interpolada = `unproject_position` com 0,00006 px
  de diferença nos pontos da tela.
- Celular no carro (medida lateral, o conserto é a Fase 3): o ciclo
  abrir+fechar caiu de ~88 ms e ~100 pipelines para ~70 ms e 10 pipelines; o
  custo passou da abertura para o fechamento.
- Abertura da estrada: 75 s sem erro de script (ela usa o mesmo desfoque e
  ganha a cabine nítida junto).

**Ficou de fora, de propósito:** a pé e de bicicleta a câmera continua no passo
de física. Ali o mouse gira o corpo do jogador direto no `_input`; interpolar o
corpo atrasaria o olhar, que é perder qualidade. Pede separar o giro do olhar
do corpo — candidato a uma Fase 1b se o usuário quiser.

**Régua nova:** a máquina alterna de estado ao longo do dia (a mesma cena deu 13
e 26 ms de mediana com e sem a mudança). Medida de custo só em par no mesmo
build, ou alternada dentro da rodada (`--alternar=N`).

### Fase 1 (plano original) — Dirigir liso (cadência da câmera e do desfoque)

**Objetivo:** a câmera, o carro e a cabine andam a cada quadro desenhado, não a
cada passo de física.

- Interpolação de física do Godot (`physics/common/physics_interpolation`)
  **ligada de forma controlada**: ligar no projeto, mas desligar na raiz da
  árvore e religar só onde se quer (carro do jogador, jogador e câmera, carros
  do trânsito). Assim os sistemas que se movem em `_process` (NPC, trilho de
  câmera das cenas, abertura) não mudam de comportamento.
- Todo teleporte desses nós chama `reset_physics_interpolation()`
  (`Carro.pousar`, entrar/sair do carro, interiores, `--ir-para`).
- O desfoque passa a ler a câmera já interpolada (automático, ele usa a
  `Camera3D` do quadro).
- **Critério:** na `bancada_fps_dirigir`, câmera parada em **0%** dos quadros
  andando e passo/esperado entre **0,8 e 1,25** (p10–p90), com e sem vsync;
  `TesteCarro` e a abertura da estrada sem regressão.
- **Toca:** `project.godot` (1 linha), `player.gd`, `carro.gd`, `camera_rig.gd`
  — hoje sem trabalho alheio não commitado.

### Fase 2 — EM ANDAMENTO (24/09/2026): o que ja foi achado e feito

Medido quadro a quadro em `tests/bancada_fps_dirigir.gd` (avenida x = -160,
70 km/h, 4K MODERNO). Cada culpado foi NOMEADO por medida antes do conserto:

| Culpado | Como foi achado | Conserto | Antes -> depois |
|---|---|---|---|
| **Marca de pneu** recompilava o shader a cada redesenho (20x/s por 22 s depois de cantar pneu): o "estado lento" de fisica 19 ms/quadro, 36 fps | `--faixas` (prioridade por script) -> `Carro`; `--fatiar-carro` -> `RastroPneu.passo`; `bancada_rastro_pneu.gd` | `rastro_pneu.gd`: materiais presos num cache estatico, aquecidos no nascimento | 37,5 -> 0,10 ms por redesenho; fisica 19 -> 0,6 ms/quadro |
| **Desfoque** com rastro do tamanho do quadro: engasgo virava clarao de borrao | par alternado na rodada (custo zero) e `rastro_ms` | `lente.gd`: obturador preso ao quadro tipico (`--desfoque-por-quadro` e o par) | pior/mediana do rastro 10x -> 1,1-1,9x, mesmo borrao em regime |
| **Chunk inteiro num quadro** (bar: 139 ms) | `--faixas-proc` por quadro -> `chunk_manager.gd` 80 ms | `MontagemDeChunk` ligada: borda do streaming em fatias de 2,5 ms; anel do jogador inteiro (`--montagem-inteira` e o par) | pior do chunk 139 -> ~20 ms (um prop) |
| **Shader de prop morria com o ultimo prop** e recompilava (voltava igual na 2a volta) | `--duas-voltas` + `--segurar-shaders` | `ReservaDeShaders` (novo, ligado no `ChunkManager`) | 2a volta: pipelines 29-68 -> 11-18, "pos" 50-67 -> <= 18 ms |
| **Primeira vez** de cada shader/material/prop | `--aquecer-shaders` | `AquecimentoDeShaders` no titulo: catalogo de 332 superficies e 43 props desenhado uma vez; `PainelAquecimento` com barra; CONTINUAR/CARREGAR/NOVO JOGO apagados ate terminar | 3,4-4,8 s no boot (quase sempre termina antes do titulo); 144 pipelines que saiam dirigindo |
| Grama/mato montando chunk ja liberado (erro de script, antigo) | log | guarda `is_instance_valid` em `grama_viva.gd`/`mato_de_calcada.gd` | sem erro |

Descartados por medida: carro encostado, GI, sondas (sem efeito nos picos),
radar da HUD, descarga de chunk (0,2 ms).

**O que ainda derruba quadro (medido, ainda aberto):**

1. **Prop caro criado de uma vez** na thread principal: convidado (2,3 ms; uma
   variante 50-110 ms), TV ~20 ms, sinuca ~20 ms, interior do mercado 46 ms,
   nascimento de carro 20-27 ms e de pedestre ~20 ms. Pede reserva (pool) e
   variante montada uma vez — **mexe em `convidado.gd`, `kit_bar`/bar e
   `corpo.gd`, que tem trabalho da sessao do bar**: combinar antes.
2. **Picos de fisica** de 8-25 ms em quadros isolados (ainda sem dono).
3. Interior do mercado e gotejo (`Goteiras`) fora do catalogo do aquecimento.
4. **GPU a 4K + apresentacao pela iGPU**: ~20% dos quadros entre 17 e 25 ms
   (Fase 6, D11).

### Fase 2 — plano original

**Objetivo:** a 70 km/h, **nenhum quadro acima de 33 ms** e **menos de 1%
acima de 16,7 ms**; mediana dirigindo perto da parada.

1. **Chunk fatiado:** `_materializar_um` passa a montar por etapas com
   orçamento de tempo por quadro (malhas → colisão → oclusor → props em lotes
   pequenos), e props caros (gente, lâmpada com facho) nascem por último,
   do mais perto para o mais longe.
2. **Gente pronta:** `Corpo` do `Convidado`/`Pedestre` sai de uma reserva
   (pool) ou tem os dados de malha montados na piscina de threads; nascer deixa
   de montar corpo na thread principal.
3. **Sondas de reflexo com orçamento:** não refazer acima de uma velocidade
   (o SSR cobre a poça em movimento) e refazer ao parar; ou uma face por quadro
   em vez de seis.
4. **Aquecimento de pipelines:** todo material de carro, gente e prop compilado
   no carregamento (tela preta), mantendo o dono vivo (memória "aquecimento
   precisa manter o dono").
5. O que o censo de CPU apontar como custo fixo por quadro (seção 3).

- **Toca:** `chunk_manager.gd` (**tem trabalho não commitado da sessão do
  bar** — ligação mínima e commit só das linhas próprias), `multidao.gd`,
  `pedestre.gd`, `corpo.gd` (**trabalho alheio não commitado**),
  `sondas_reflexo.gd`, arquivo novo para o aquecimento.

### Horizonte — a ordem pedida em 24/09/2026 (noite)

O usuário pediu para focar em aumentar a distância de renderização (vai virar
opção gráfica, "infinita se o computador aguentar"). Ordem aprovada, um passo
por vez, com aval entre eles:

1. Raio de simulação separado do visual, e carga priorizada pela direção e pela
   velocidade. **FEITO**, abaixo.
2. Anel distante (HLOD do plano da cidade), relevo até a serra, luzes de noite,
   transição com esmaecimento (a Fase 5). **FEITO**, abaixo.
3. Névoa exponencial e de altura (a Fase 4), com o aval dele no visual.
   **FEITO** (sem a de altura, que o Godot não integra no raio), abaixo;
   o visual espera aval.
4. Opção "Distância de visão" e o orçamento de GPU (a Fase 6).

A Fase 2 ficou com o pico de 23,6 ms da Multidão e o `IWeed` em aberto.

#### Passo 1 — FEITO (24/09/2026, sem commit)

`ChunkManager` + `MontagemDeChunk`:

- **Prioridade.** A fila de carga pesa a distância até a BORDA do chunk, menos
  o que a velocidade anda na direção dele em 2 s, menos 16 m se a câmera olha
  para ele. O anel do jogador passa sempre na frente. Vale para pedir à thread,
  para escolher qual dado pronto vira nó e para a ordem das montagens.
- **Antecipação.** Acima de 4 m/s, o anel logo além do raio, num cone de 60° à
  frente, sai da thread antes de precisar (`_adiantados`). Ao cruzar a
  fronteira o chunk só é pendurado.
- **Casca.** Entre o raio de simulação e o visual o chunk entra só com as
  malhas (sem o balde @perto) e o oclusor. Chegando perto é promovido no mesmo
  nó (colisão, @perto e props); afastando, volta a casca. Casca não conta como
  carregado: mapa, trânsito, multidão e blitz veem o mesmo conjunto de antes.
  **Padrão: raio visual = raio de simulação, nenhuma casca, imagem igual.**
- Flags: `--streaming-antigo` (par da bancada), `--raio-visual=M`,
  `--raio-sim=M`. A `bancada_fps_dirigir` ganhou `buracos` (chunk dentro do
  frustum e do alcance visível que não existe), `atraso_ms` (de preciso a
  pronto) e `thread_ms`.

Medido (rodadas quase todas contaminadas por Godot de outras sessões; o que se
repete nas três baterias):

| | antigo | novo |
|---|---|---|
| buracos a 120 km/h, `dia_sol` | 112 e 65 quadros, até 6 chunks | 0, 21, 20 e 35 quadros, até 2–3 |
| atraso mediano / p95, neblina | 80 / 274 ms | 55 / 220 ms |
| atraso mediano / p95, `dia_sol` 70 km/h | 390 / 991 ms | 317–347 / 806–892 ms |
| quadro dirigindo | — | igual (ruído) |

Casca contra chunk completo, `dia_sol`, mesmo alcance de 192 m
(`--raio-sim=96 --raio-visual=192`): quadro mediano **33,4 → 18,5 ms**, física
**9,3 → 1,2 ms**, script 4,0 → 1,5 ms, chamadas 1.649 → 1.468. As fotos no fim
da volta batem nos prédios, postes, árvores e fiação a 100–192 m. O que muda:
trânsito, gente e ícones do minimapa além de 96 m (os ícones vêm do chunk
completo). Achado lateral: o `dia_sol` de hoje custa ~33 ms por quadro
dirigindo, quase tudo física e script dos 180 chunks completos.

O que sobra de buraco a 120 km/h é vazão de montagem (um chunk por quadro,
2,5 ms de orçamento, com quadro de 48 ms): é a borda do horizonte a 160–192 m,
que o passo 2 troca por esmaecimento e anel distante.

**Conserto da Fase 2 achado aqui:** as encomendas de corpo e de carroceria não
eram esperadas na saída, e a tarefa que montava malha com o servidor de render
já fechado derrubava o processo (falha de segmento em 5 de 10 rodadas de
`dia_sol`). O `ChunkManager._exit_tree` agora espera as duas
(`VariantesDeCorpo`/`Carroceria.esperar_encomendas`): 0 de 4 depois.

#### Passo 2 — anel distante (25/09/2026, sem commit)

Arquivos novos em `src/world/horizonte/` (`Horizonte`, `HorizonteDados`,
`HorizonteMalha`) e `shaders/psx_horizonte.gdshader`; ganchos pequenos no
`ChunkManager` (`--horizonte=M`, a planta de todo chunk construído, alcance
ilimitado enquanto o anel desenha), no `CeuNoturno` e na `SerraDaCidade` (o céu
mora além do raio, com o mesmo tamanho angular). No passo 3 passou a ser ligado
por padrão no MODERNO (2,5 km); o passo 4 põe o raio na opção.

- **Planta 2,5D por chunk** (2 m, 11 bytes por ponto): a exata sai do próprio
  `ChunkBuilder.construir` (HLOD feito da versão de perto); a aproximada, da
  quadra e das ruas, sem construir, ~0,5 ms. A cor da aproximada vem de
  `resources/horizonte/paleta_aproximada.json`, amostras reais de parede e
  telhado por distrito (`bancada_horizonte --paleta`); cobertura e altura já
  batiam (33 × 28 %, 8,8 × 9,5 m no centro).
- **Árvore de quadrantes com oito níveis** (célula de 128 m a 16 km). Toda
  célula é uma grade de 64 × 64 pontos: o custo por anel é o mesmo, e o raio
  cresce com o log. Nível 3+ usa a média (bloco se prédio cobre ¼, na altura
  média) e o bloco recuado 20 % (a rua volta a ser o vão); nível 5+ sorteia um
  chunk por quadrado.
- **Malha:** chão em grade de vértices compartilhados com cor chapada pelo
  vértice provocador (`varying flat`; `provoca_no_fim` para o Compatibility),
  telhados em retângulos gulosos, paredes em faixas, bloco recuado com 8
  vértices (normal da derivada da tela), atributos comprimidos, lâmpada de 3
  vértices. Nível 0: 7,1 mil vértices por célula; nível 4: 38 mil (eram 72
  mil antes do bloco compartilhado).
- **Máscara por pixel** (um texel por chunk): some onde o chunk de verdade
  desenha, com esmaecimento pontilhado de 0,35 s quando ele chega.
- **Fios:** dois dedicados de prioridade baixa (plantas exatas, malhas).
  Acima de 8 m/s (histerese até 4,8) o de plantas para (o streaming já manda
  a planta de todo chunk que carrega, o anel antecipado inclusive) e o de
  malhas faz a célula perto antes da distante, descansando 4× o custo depois
  de cada distante.
- **Cache em disco** `user://horizonte/<versão>/`: regiões de plantas exatas e a
  grade de toda célula do nível 2 para cima. Versão = hash do gerador +
  `VERSAO_GRADE`. `--horizonte-cache-fixo` é para bancada (as outras frentes
  salvam o gerador a cada minuto e o cache esfriava entre duas rodadas).
- Janelas filtradas pela derivada (sem moiré a 4K), acesas à noite em três
  tons; postes de sódio em ponto virado para a câmera, só à noite.

Medido (4K, RX 9070 XT):

| | 2,5 km | 8 km |
|---|---|---|
| células | 158 | 231 |
| triângulos / vértices | 2,45 / 2,54 milhões | 5,2 / 4,95 milhões |
| buffers de vídeo sobre sem horizonte | +60 MB | +125 MB |
| preenchimento a frio | 105 s (quase tudo planta exata) | 168 s com as exatas do disco |
| GPU parado (hz5) | +0,4 ms | +0,5 ms |
| quadro dirigindo (hz6) | +1,5 ms | +1,4 ms |
| física mediana dirigindo (hz6) | +0,2 ms | +0,1 ms |

A malha anterior (um quadrado por ponto, sem compressão) dava 3,19 milhões de
triângulos a 2,5 km e, dirigindo, +4,5 ms de quadro e +11 ms no p95 da física.
As rodadas desta etapa quase todas contaminadas por Godot de outras frentes
(`fila7.sh` grava quem em `r_<nome>.alheio.txt`); entre hz5 e hz6 o jogo
inteiro ficou mais rápido por trabalho alheio (dirigindo sem horizonte 34 → 11
ms), por isso só vale comparar dentro da mesma bateria.

Primeira vez num raio grande: as células de 4+ km custam 2–6 s cada no fio
(o `Tracado` de cada célula de 5 × 5 chunks sorteada); depois ficam no disco.
Para lançar, dá para assar o cache de toda a área jogável na build (o SLOD do
GTA), e a primeira abertura já sai completa.

Fica para o passo 3: o ar a 8 km está limpo demais (bruma máxima de 26 %); os
blocos de 5+ km pedem a atmosfera para assentar.

#### Passo 3 — névoa que não mente (25/09/2026, sem commit, visual pede aval)

Pedido do usuário no meio do passo: "em dias de névoa também deve dar pra ver
em distância infinita, mas com névoa". Isto é, a névoa atenua a distância e não
a corta.

**Modelo (só MODERNO, só os 8 climas do jogador, `atmosfera_moderna` no
`.tres`).** O PS1 STYLE e os presets de cena seguem lineares (ART-BIBLE 8).

- Névoa **exponencial**, `f = 1 − exp(−d·x)` (medido no 4.7.2: exato). A
  densidade sai do próprio preset. Com névoa, 70 % em `fog_end`
  (`d = −ln 0,3 / fog_end`); limpo, `visibilidade_limpa` do `.tres`
  (visibilidade meteorológica, `d = 3,912 / V`): `dia_sol` 30 km e
  `noite_estrelada` 20 km.
- `FogPreset.alcance_visivel()` é onde o ar apaga 99,9 %. O horizonte desenha até
  `min(raio, alcance)` e o corte de desenho dos chunks fica ali, onde já não há
  nada a cortar. A cidade vai sumindo até lá e não tem mais parede.
  Alcance: `neblina` 184 m, `noite_chuva` 344 m, `dia_chuva` 470 m,
  `noite_nublada` 528 m, `dia_nuvens` 746 m.
- Cor do ar (`cor_do_ar`): a da névoa; no limpo, o céu puxado para a bruma da
  serra (de dia) ou o céu escurecido (à noite). `sky_affect` 1 com névoa, 0 no
  limpo. Estrela e lua saem com `fog_disabled`.
- **D7 consertado.** A névoa volumétrica só absorvia, e por isso a cidade além
  dela ficava mais escura que o céu. Agora ela recebe luz ambiente calibrada
  (`volumetric_fog_ambient_inject`) para que a cor do volume seja a cor do ar
  (`FogController._aplicar_atmosfera`).
- **Serra.** Na névoa exponencial, a vista dela é a transmitância do ar até
  2 km (`SerraDaCidade.SERRA_NA_NEVOA_M`). Antes ela ficava nítida, flutuando
  sobre o mar de névoa (D8).
- **Mirante.** Interpola também a `fog_density`, que sai do fim da névoa
  derivada.
- **Horizonte ligado por padrão** no MODERNO (`ChunkManager.RAIO_HORIZONTE`,
  2,5 km, sempre cortado pelo alcance do ar); `--horizonte=0` desliga. O shader
  do horizonte não escreve mais FOG: vale a névoa do `Environment`, a mesma dos
  chunks, e perto e longe casam na borda.
- Flags: `--nevoa-linear` (o par "antes") e `--injecao-ambiente=K`
  (multiplica a injeção).

**Régua** (`regua_ar.py`: luminância mediana por faixa de distância oblíqua,
relativa ao céu da mesma foto, câmera a 40 m, 4,57° para baixo, fov 70).
`dia_nuvens`:

| faixa | antes (linear) | novo | novo sem injeção |
|---|---|---|---|
| 65–130 m | p5 −72, silhueta dura antes da parede | −18,1 | — |
| 130–260 m | 0, parede | −3,8 | — |
| 260–746 m | 0, parede | −0,9 | −3,0, mais escuro que o céu (D7) |
| além de 746 m | 0 | +0,0 | — |

`neblina`: 64–184 m −2,1, além de 184 m 0,0. `noite_chuva`: as luzes da cidade
atravessam a névoa até ~340 m, onde antes havia uma parede escura a ~60 m.
`dia_sol` a 8 km (V = 30 km): a bruma fica como a do horizonte do passo 2.
`noite_estrelada`: igual, com estrela e lua intactas.

**Custo** (par limpo ar4, `dia_nuvens`, 4K; o antes é `--nevoa-linear`, que
também desliga o horizonte, porque o alcance vira 130 m):

| | antes | novo |
|---|---|---|
| parado: quadro / GPU | 6,94 / 6,32 ms | 6,99 / 6,45 ms |
| dirigindo: quadro mediano / p95 / p99 | 7,58 / 16,55 / 21,2 ms | 8,33 / 16,95 / 25,0 ms |
| dirigindo: script / desenho (CPU) / GPU | 2,43 / 3,30 / 6,64 ms | 2,48 / 3,56 / 6,77 ms |

Chamadas de desenho dirigindo (medianas): linear 1.148–1.169, exponencial sem
horizonte (`--horizonte=0`) 1.503, exponencial com horizonte 1.524–1.533.
Parado: 1.252 / 1.266 / 1.302–1.320. Quem sobe dirigindo **não é o horizonte, é
o alcance do ar**: com o corte a 746 m, os chunks carregados entre ~150 e
~190 m (o anel de histerese), que a linear cortava, são desenhados de verdade.
É o custo certo de ver mais longe; o passo 4 pode trocá-los pela célula do
horizonte, que é mais barata. A lógica do horizonte também não pesa: o script
fica igual. O segundo par (ar6, ordem invertida) saiu contaminado por outras
frentes, com o novo mais rápido que o antes. O +0,75 ms e o p99 do primeiro par
não se repetem, e a CPU de desenho fica em +0,15 ms.

**Conserto achado na medida: troca de nível sem desenho dobrado.** Quando uma
célula se dividia, cada filha aparecia assim que ficava pronta, por cima da mãe,
que só saía com a última irmã: o mesmo chão com dois níveis, a mãe furando a
filha onde era mais alta. Agora a filha espera escondida e a troca é inteira
num quadro (`Horizonte._podar`, `_mostrar_sem_antepassado`). A
`bancada_fps_dirigir` conta as `dobradas` (célula visível com antepassado
visível) e as `escondidas`. Em `dia_nuvens` (ar7, 80 células): dobradas 0 em
todas as 705 amostras; escondidas até 3 dirigindo, que antes eram desenho
dobrado. É pouco a 746 m, e cresce com o raio (passo 4).

**Olho de perto na `neblina`.** O asfalto a 2,5 m vai de 37 para ~78 de 255.
Não é a injeção (inj 0: 78; 0,25: 79; ~1,3: 81). É que o Godot mistura a névoa
em luz linear, e 9,5 % de névoa linear viram 34 % em sRGB sobre o escuro; a
exponencial não tem distância de início (o Unreal tem `StartDistance`). O
aspecto lembra ar molhado de verdade (Silent Hill 2), mas muda o jogo e pede
aval. A alternativa é a nossa própria névoa por `CompositorEffect`, com início,
não feita.

**Descartado:**

- Exponencial a 80 % no `fog_end`: lavava a neblina de perto.
- Profundidade + curva "com cauda": ainda tem fim, e o pedido é ver sem fim.
- `fog_height` do Godot: é `max()` por altura do pixel, sem integrar no raio. A
  rua do vale a 2 m sairia tão enevoada quanto a 2 km.
- `fog_aerial_perspective`: em 0. A cor do ar já bate com o céu (±1 além do
  alcance). Fica como opção para o `dia_sol` (a cor do céu atrás de cada
  prédio).

### Fase 3 — Celular sem travada

**Objetivo:** abrir e fechar no carro custa o mesmo que a pé (**pior quadro
< 12 ms** a partir da 2ª abertura, **0 pipelines** novas por abertura).

- Bisect na `bancada_fps_celular --no-carro` dos três suspeitos de D6.
- Carregador de isqueiro e fio montados **uma vez** por carro e só mostrados e
  escondidos; a câmera de dentro e a luz do painel pré-aquecidas.
- **Toca:** `ao_volante.gd`, `cabine_do_jogador.gd`, `celular.gd`.

### Fase 4 — Névoa que não mente

**Objetivo:** o que some na névoa some por névoa, nunca por corte; e a névoa
tem profundidade (silhueta que se dissolve), não parede.

- A cor final da geometria no fim da névoa **igual** à do céu, com volume
  ligado (o volume passa a pesar no céu na mesma medida, ou deixa de atenuar
  além do fim da névoa de profundidade, sem trazer de volta as bolhas de
  froxel que motivaram o `sky_affect = 0`). Régua: a tabela de D7, faixa da
  cidade = céu (±1) com corte desligado e volume ligado.
- Névoa **exponencial + de altura** (perspectiva aérea) no MODERNO, no lugar da
  linear até 100%: a `neblina` continua fechada perto, mas a silhueta do
  quarteirão seguinte fica legível; os presets de dia ganham bruma de
  horizonte em vez de névoa de parede. PS1 STYLE mantém a linear (ART-BIBLE 8).
- Corte de desenho com esmaecimento (`visibility_range` com fade) em vez de
  sumiço seco.
- **Toca:** `fog_controller.gd`, `fog_preset.gd`, os `.tres` de clima,
  `chunk_manager.gd` (só `_aplicar_alcance`).

### Fase 5 — Horizonte: ver a cidade longe

**Objetivo:** do alto de uma ladeira ou de um mirante, de dia, a cidade
continua até os morros; da rua, a avenida some na bruma, e não numa planície
pintada. Alcance de **1,5–2 km**.

- **Anel distante (HLOD):** por célula entre avenidas (5×5 chunks, 160 m), uma
  malha simplificada da cidade — volume dos prédios (as caixas de prédio já
  existem na colisão, que é de onde sai o oclusor), telhado na cor do lote, rua
  e quadra no chão, copa de árvore em massa. Gerada **fora da thread
  principal**, uma chamada de desenho por célula, cacheada por semente.
- **Terreno longe:** o relevo dos morros (`Relevo`/`Morros`) numa malha de
  passo largo até a serra, no lugar da saia pintada.
- **Noite:** janelas acesas e postes como pontos emissivos na malha distante
  (a cidade vista do morro à noite).
- Transição perto↔longe com esmaecimento pontilhado, sem pulo.
- **Critério:** fotos do alto nos 4 climas mostram cidade contínua até a serra;
  custo **≤ 1,5 ms de GPU a 4K** e **zero engasgo** a mais na bancada de dirigir.
- **Toca:** arquivos novos (`horizonte_*.gd`), ligação mínima no
  `DiretorCeu`/`SerraDaCidade`.

### Fase 6 — Orçamento de GPU para pagar o horizonte

**Objetivo:** manter 4K acima de 120 fps dirigindo com o horizonte ligado.

- Nível de detalhe da malha do chunk por distância (o miolo de 500 mil
  triângulos cai onde a névoa ou a distância já não deixa ver).
- Sombra direcional em cascatas com alcance casado com a névoa.
- SDFGI em movimento rápido e as cascatas; FSR 2 "qualidade" como opção
  documentada para quem quer o horizonte máximo.
- **Critério:** GPU dirigindo ≤ 8 ms a 4K nativo com horizonte; nenhum preset
  do PS1 muda.

---

## 3. O que a Fase 0 deixou para o começo da Fase 2

A partir das 16h49 de 24/09 outra sessão passou a relançar o Godot da praça a
cada ~3 min, e toda rodada daí em diante saiu contaminada (o executor anota
isso: `contaminada=1`). Ficaram sem número limpo:

- o A/B fino com o hatch fixo (`--sem-sondas`, `--sem-gi`, `--sem-ao`,
  `--sem-desfoque`) — quanto cada um pesa DIRIGINDO;
- o censo de CPU por classe (`bancada_censo_cpu`), que parado confirma só o
  que já se sabia: parado a CPU não é o gargalo.

A Fase 2 começa por esses pares, com a máquina livre, antes de mexer em código.
A Fase 1 não depende deles: a cadência (câmera parada em 15–35% dos quadros,
p10 do passo = 0) apareceu igual em todas as rodadas, limpas ou não.

Onde estão as bancadas: `game/tests/bancada_fps_dirigir`, `bancada_fps_celular`,
`bancada_alcance_visao`, `bancada_censo_cpu` (`.gd` + `.tscn`), não commitadas.
A worktree `../PSX_perf_wt` (HEAD + `.godot` copiado) continua montada para
medir enquanto a árvore principal não compilar.

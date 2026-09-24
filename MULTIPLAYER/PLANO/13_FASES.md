# 13 — Fases (passo a passo)

> **Versão 2.1 — 21/09/2026.** A ordem de trabalho. Cada fase tem entrada, tarefas, arquivos, aceite e o que não entra. A 2.1 acrescenta o que os capítulos técnicos 04–12 decidiram na revisão contra o código (fidelidade do boneco, assinatura do mundo, caído e levantar, carona pendurado, carro estacionado, relógio do plano).
> Pronto = `14_TESTES_E_ACEITE.md` + P16 (solo intacto).
> ✋ / **Arquivo alheio**: arquivo de sistema do jogo com dono em outra frente. Antes de tocar: `git status` no arquivo; se houver trabalho não commitado de outra sessão, **não** tocar e registrar aqui. Às 18h de 21/09, o trabalho não commitado de outras sessões estava todo na cidade e no relevo (`chunk_builder`, `relevo`, `malha_urbana`, `vias`, `kit_modular`, `tracado`, `mapa`, `bicicleta` e builders novos), o que pesa na Fase 8 (memória do projeto: *sessões paralelas no repo*).

```
0 Canon ─┐
1 Base de rede ✅ ──► 2 Sistemas enxergam a sessão ──► 3 Mundo compartilhado ──► 5 Grupo e missão
                  ├─► 4 Carro com passageiros (depois de 2.7)                   ├─► 6 Dedicado persistente
                  └─► 6.1–6.3 (export Linux, strip) pode começar já             └─► 7 Título, folha de viagem, abertura co-op
                                                                                     8 Chão no servidor, NPC, DTLS, admin
                                                                                     9 Steam (opcional)
```

A diferença para a v1: o amigo aparece na rua **já na Fase 1**. A v1 punha "ver o outro andar" depois de uma refatoração de 32 arquivos. Na v2 o jogador local não muda e os outros são bonecos (`03` §4), então a refatoração deixa de ser pré-requisito para ver o outro. Ela passa a ser pré-requisito para **mexer no mundo junto**.

---

## Fase 0 — Canon

**Tarefa:** emendar `docs/PROMPT-MESTRE.md` §5, linha 90: "Não tem multiplayer, progressão por níveis, craft ou loot aleatório." (P12).
**Estado:** ⏳ pendente. O mestre é canon de outra frente, e a emenda é decisão do dono do projeto.

---

## Fase 1 — Base de rede ✅ (21/09/2026)

**Feito, com o nível 4 verde:**

| # | Tarefa | Onde |
|---|---|---|
| 1.1 | Autoload `Sessao`: SOLO, HOSPEDANDO, DEDICADO, CONECTANDO, CLIENTE | `net/sessao.gd` |
| 1.2 | ENet com compressão, 2 canais, timeout de 8 s | idem |
| 1.3 | Autenticação antes do peer: versão, senha com desafio, lotação, motivo | `sessao.gd` + `protocolo_rede.gd` |
| 1.4 | Estado a 20 Hz em bytes, carimbado na amostra | `protocolo_rede.gd` |
| 1.5 | Instantâneo por destino, com espaço e raio de interesse | `sessao.gd` |
| 1.6 | Relógio de rede monotônico; buffer de interpolação | `relogio_de_rede.gd`, `buffer_interpolacao.gd` |
| 1.7 | Boneco do outro com aparência saneada, nome, lanterna, agachar; carro como réplica | `avatar_remoto.gd` |
| 1.8 | Validação de movimento (`registrar` / `corrigir`) | `validador_movimento.gd` |
| 1.9 | Servidor dedicado: cena, configuração, console, export Windows | `servidor_dedicado.gd`, `config_servidor.gd`, `export_presets.cfg` |
| 1.10 | Relógio da cidade no servidor; acerto nos clientes | `sessao.gd` |
| 1.11 | Chegada perto de alguém, no relevo, esperando chão | `sessao.gd` |
| 1.12 | Descoberta na rede local (LAN, Hamachi, Radmin) | `descoberta_lan.gd` |
| 1.13 | Painel F7: hospedar, entrar, lista, jogadores com ping, chat, recados | `painel_online.gd` |
| 1.14 | Nível 2 (108 asserções), nível 4 (dedicados + bots que medem), duas janelas com foto | `tests/mp/`, `tools/mp_*.sh` |

**Arquivo alheio tocado:** `project.godot` (+2 linhas: autoload e `run/main_scene.dedicated_server`) e `export_presets.cfg` (+1 preset).

**Ficou para depois, de propósito:**

- prova visual da lanterna e do agachar do outro (o bit viaja e o boneco reage; falta foto);
- medir com perda e atraso simulados (8.4).

---

## Fase 2 — Sistemas enxergam a sessão, e o outro parece gente

**Entrada:** Fase 1. **Objetivo:** o jogo não fazer nada que só faz sentido sozinho quando está em rede, e o boneco do outro mostrar o que ele está fazendo sem precisar do chat. Capítulos: `06`, `07` §2.1, §3.1, §6.

**Estado em 21/09, 20h:** 2B e 2C feitos e medidos; 2A em parte. O que falta em 2A está em arquivos que **outra sessão editava na hora** (`interiores.gd`, `cidade.gd`, `convidado.gd`, `casa_viva.gd`, com trabalho não commitado): ficou para quando ela commitar.

### 2A — O que o jogo faz errado em rede

| # | Tarefa | Arquivo alheio | Estado |
|---|---|---|---|
| 2.1 | **Pausa:** em rede nada pausa a árvore; trava só o jogador local e marca `F_AUSENTE`. Antes, o anfitrião que abria a prancha congelava para todos **e parava o relógio da cidade de todos**, e cada cliente voltava no tempo a cada 5 s (`06` §6) | `ui_manager.gd`, `prancha_inventario.gd`, `menu.gd`, `modo_foto.gd` | ✅ `Sessao.pausar`/`pausado`; uma linha por ponto; sozinho é idêntico por construção. **Falta a prova de duas janelas** (`06` §11, item 1) |
| 2.2 | `Interiores.semente_atual()` público, no lugar do `get(&"_semente")` | `interiores.gd` | ✅ 23/09 |
| 2.3 | **Desmaio em rede não pula a hora**; teletransporte anunciado; o servidor aceita o bit no mesmo espaço no máximo a cada 3 s, e registra | `desmaio.gd`, `interiores.gd`, `save_game.gd`, `cidade.gd` | ✅ desmaio, interiores (entrar e sair anunciam), save (o anfitrião anuncia e reenvia o mundo); `corrigir` é o padrão desde 23/09, com zero correção no ponta a ponta que entra e sai de cômodo; `--ir-para` é atalho de captura, e o salto de mais de 8 m é marcado sozinho |
| 2.4 | Minimapa: ponto de cada jogador do mesmo espaço | `minimapa.gd` | ✅ caneta azul; quem está fora do cartão fica na borda (foto `anfitriao_ve_carro_e_lanterna.png`) |
| 2.5 | `Sessao.jogador_local()`, `corpos(espaco)`, `mais_perto(origem, raio, espaco)`; pedestre, convidado e `casa_viva` reagem aos bonecos (`06` §5.2) | `pedestre.gd`, `convidado.gd`, `casa_viva.gd` | ✅ API, pedestre (contorna o amigo) e `casa_viva` (o boneco do amigo é obstáculo para os moradores); ⏳ convidado (arquivo com trabalho de outra frente) |
| 2.6 | CONTINUAR com save + F7 → hospedar: o mundo aberto é o do save | — | ⏳ sem teste |

### 2B — O outro parece gente (`06` §4)

| # | Tarefa | Estado e prova |
|---|---|---|
| 2.7 | **Estado v2** (23 B): arfagem u8, flags u16; bits `SENTADO`, `AUSENTE` e os reservados `FERIDO`, `CAIDO`, `FALANDO`, `CARONA`; no carro, `LANTERNA` = farol, `AGACHADO` = freando, `CORRENDO` = freio de mão. `VERSAO` = 2 | ✅ nível 2 (ida e volta, extremos, bit desconhecido); nível 4 com 16 bots: p95 0,22 cm, 6,01 KB/s |
| 2.8 | Lanterna do boneco aponta pela arfagem | ✅ **medido**: chão na frente do bot 1,70× o de referência a −35°, 1,16× a +30° (`lanterna_do_amigo_baixo_e_cima.png`) |
| 2.9 | Carro do outro: motorista no banco, farol e facho, luz de freio, rodas girando e esterçando | ✅ farol, facho e **luz de freio** confirmados (`anfitriao_ve_freio_e_poses.png`: brasa vermelha acesa atrás do carro com `--bot-agachado`, que no carro é `F_FREANDO`); ⚠ **motorista não se vê**: o vidro da `Carroceria` é cor opaca (`VIDRO = (0,20; 0,23; 0,27)`), e isso vale para o NPC do trânsito também (fotos de lado e de frente). Decisão da frente de render; pesa na abertura co-op (`12` §3). ⏳ giro de roda sem foto (precisa de carro em movimento, não parado) |
| 2.10 | Passos do outro, com som | ✅ código (`PASSADA = PI / Player.BOB_FREQ`, a conta do `Player`); ⏳ sem medida de áudio |
| 2.11 | Bicicleta debaixo do boneco; sentado (`ASSENTO`); nome com "..." quando ausente | ✅ **fotografado** (`anfitriao_ve_freio_e_poses.png`: bicicleta sob o boneco e postura sentada com tronco recuado; `anfitriao_ve_ausente.png`: "BOT0 ..." sobre a cabeça). CLI do bot ganhou `--bot-sentado`, `--bot-bicicleta`, `--bot-ausente` para isso |
| 2.12 | Boneco só desenha onde **eu** tenho chão | ✅ código; o bot (sem chunk) não confere, e o nível 4 continua medindo |
| 2.13 | Empurrão suave entre jogadores a pé | ✅ código; ⏳ sem medida de corredor |

### 2C — A mesma cidade (`07` §2.1)

| # | Tarefa | Estado e prova |
|---|---|---|
| 2.14 | `AssinaturaDoMundo`: 4 chunks do `ChunkBuilder` (os props trazem a altura do relevo, então ele entra sem amostra à parte). Desafio, pedido e anúncio; "Cidade diferente."; "(outra cidade)" na lista | ✅ nível 2 (6 asserções); nível 4: bot com `--sem-relevo` **recusado com o motivo**; dedicado calcula na subida em 110–154 ms |

**Não entra:** reescrever os 43 `get_first_node_in_group(&"player")`. Eles continuam certos, porque o jogador local continua sendo o único no grupo.

**Aceite:** `06` §11 inteiro, mais: bot com `--sem-relevo` recusado com "Cidade diferente." ✅; `mp_teste.sh` verde com o estado v2 ✅; banda com 16 ≤ 6,6 KB/s por cliente ✅ (6,01).

---

## Fase 3 — Mundo compartilhado

**Entrada:** Fase 2 (teletransporte anunciado, para a validação não brigar com porta). Capítulos: `04`, `08` §1–5, §8.

| # | Tarefa |
|---|---|
| 3.1 | `ChaveMundo.de_posicao(no, coord)`: chave por decímetro para o que o gerador não numerou (porta, gaveta, luz) |
| 3.2 | `WorldState.mudou(coord, chave, valor)`: o sinal que falta para o nó vivo reagir à mudança de outro ✋ |
| 3.3 | `Sessao.mudar_mundo` (classe 2, prevê e reconcilia) e `Sessao.pedir_*` (classe 1, espera); revisão `rev`; `_negado(seq, motivo)` |
| 3.4 | Trocar os **14** `WorldState.definir` dos 8 arquivos (`16` §3) ✋; separar escrita de jogador de escrita recalculada (plantio, `08` §8) |
| 3.5 | **Terceiro canal** (carga): `_estado_de_mundo` comprimido em pedaços de 16 KB; `_mundo_pronto`; sobe `VERSAO` |
| 3.6 | Porta: o estado vai para o `WorldState` com chave por posição ✋ `porta.gd` |
| 3.7 | Item no chão: `_pedir_item` (classe 1, gesto imediato) ✋ `item_no_chao.gd` |
| 3.8 | `MochilaDoServidor` (pura); `Inventario` vira espelho em rede; kit inicial do servidor; `_pedir_usar`, `_pedir_largar`, `_pedir_dar` ✋ `inventario.gd` |
| 3.9 | **Caído e levantar** (`08` §3): `F_CAIDO`, 30 s, `_pedir_levantar`, acordar no ponto **sem pular a hora** ✋ `desmaio.gd` |
| 3.10 | NPC ocupado em conversa (`_pedir_conversa`, `_npc_ocupado`) ✋ `npc.gd`, `conversa.gd` |
| 3.11 | Visitados: união por grupo, em lote a cada 10 s |
| 3.12 | Orelhão em rede marca o ponto de volta ✋ `ponto_de_save.gd` |

**Aceite:** `04` §11 e `08` §11: item disputado com soma das mochilas = 1; dar item confere os dois lados; porta aberta num cliente aparece aberta no outro e em quem entra depois; plantio sem nenhum `_pedir_mundo` de crescimento; caído levantado por outro bot.

**Estado em 23/09/2026:** o núcleo está feito e provado de ponta a ponta. Os itens 3.1, 3.2, 3.3, 3.5, 3.6 e 3.7 estão ✅, e o 8.4 (rede ruim) também.

- **Nível 2:** `run_tests_mundo.gd`, 309 asserções, com o modelo aleatório de 3000 cenários e a recarga no meio da sessão.
- **Nível 4 com bots** (`mp_teste.sh`, cenários D e E):
  - item disputado: soma das mochilas = 1, e JA_FOI no perdedor;
  - LONGE e INVALIDO chegam com o motivo certo;
  - quem entra depois lê a porta e o item pela carga (10,6 KB, 1 parte);
  - com 150 ms de ida e volta e 2% de perda, o erro do boneco fica em p95 1,4 cm.
- **Nível 4 com o jogo de verdade** (`tools/mp_e2e.sh`, novo; duas cidades headless com `SondaE2E`, 31 conferências):
  - porta da casa da fumaça: aberta pelo anfitrião, fechada pelo convidado, reaberta, igual nas duas máquinas (folha e WorldState);
  - item disputado vai para uma mochila só;
  - chat;
  - o anfitrião carrega um save no meio da sessão, e o convidado recebe o mundo de novo;
  - quem sai volta ao próprio mundo com a mochila, e a folha da porta segue o mundo dele;
  - zero SCRIPT ERROR.
- **Carregar save em sessão** (novo, `Sessao._ao_carregar_save`):
  - o anfitrião reenvia a carga a todos, e `EspelhoDeMundo.recarga_concluida` reaplica os eventos que chegaram antes dela;
  - o convidado que carrega o próprio save sai da sessão, com o mundo do save.

**Fechado em 23/09, à tarde** (com o nível 2 em 409 asserções e o ponta a ponta em 43 conferências):

- **3.4 — todo `WorldState.definir` passa pela rede, sem tocar em nenhum dos ~30 escritores.** `WorldState.definir` pergunta a `MundoEmRede._ao_definir`, que decide pela `PoliticaDeMundo` (classe pura, uma tabela só). As famílias ficaram assim:

  | Dono | O quê | Como viaja |
  |---|---|---|
  | **MUNDO** | porta, item, plantio da estufa, prateleira da loja (`loja_N`), profissão e folha de vagas | vai ao servidor, que julga e difunde |
  | **PESSOA** | carteira, iWeed, entregas da Super, item na mão, memória de conversa (`npc_*`, `falou_*`, `repeticao`), `dono_*` (a missão é de cada um), livro-caixa iWeed por NPC | nunca sai da máquina; não vem na carga do anfitrião; vai junto na saída |
  | **LOCAL** | personagem que o cômodo marca; crescimento do plantio recalculado pelo relógio | cada máquina calcula igual |

  Chave que ninguém classificou fica LOCAL e dá um aviso `[mundo]` no console, uma vez.
- **Escrita por diferença (`FusaoDeMundo`)** para prateleira e plantio: o cliente manda só o que mudou (`_pedir_fusao`), e o servidor aplica sobre o que tem. Duas mãos na mesma prateleira, no mesmo instante, e as duas mudanças ficam (provado no jogo de verdade).
- **Cômodo por semente:** o servidor confere o espaço de quem pede contra `espaco_interior(tipo, semente)` de cada tipo (`ProtocoloRede.TIPOS_DE_INTERIOR`). Quem está no bar não mexe no mercado.
- **Casa que existe na rua:** o item de dentro dela é pedido da RUA. Antes era negado sempre ("Longe demais."). O servidor acha as casas perto de quem pede pelo mapa puro (`ChunkBuilder.pontos_de_interesse`).
- **Disputa justa de item:** o servidor segura o primeiro pedido por meia ida e volta do convidado mais lento (no máximo 150 ms). Leva quem agiu antes, pela hora estimada com o ping que o servidor mede. O anfitrião não ganha mais todo empate.
- **3.11 — mapa do grupo:** a união na entrada, e lotes de chunks visitados a cada 10 s. O convidado sai levando o mapa inteiro que viu; antes perdia o que explorou na sessão.
- **2.2:** `Interiores.semente_atual()`. **2.3:** `Interiores` anuncia os saltos de entrada e saída, e a validação passou a **corrigir** por padrão. A rota honesta (cômodo teleportado, save, chegada) dá zero correção no ponta a ponta. **2.5:** os moradores da `CasaViva` desviam do boneco do amigo.
- **Estrangulador do ENet desligado** (`ProtocoloRede.sem_estrangular`): sob oscilação de latência, ele jogava fora até um terço dos estados. Com 150 ms e jitter de 30 ms, o p95 do boneco foi de 47 para 1,1 cm.
- **O Godot anunciava 5 B/s de banda no servidor** (`create_server` passa o número de canais no lugar do `in_bandwidth`). Com mais de um convidado, o ENet deles cravava o estrangulador em 1 de 32 por até 7 s: só 2 estados em 32 saíam. Conserto em `Sessao._subir_servidor` (`bandwidth_limit(0, 0)`); ver `20` versão 4.
- **Atraso de desenho por boneco**, pela idade medida dos estados dele (p90 + 75 ms, entre 0,12 e 0,45 s). Com 150 ms de ida e volta, o atraso fixo de 0,12 s extrapolava 100 % do tempo. `--rede-ruim` em duas rodadas: fome 0 %, p95 0,12–0,18 cm, máximo 2–6 cm (antes: 5–12 %, 19–27 cm, 280 cm). Nível 2 de rede: 143 asserções.
- **DTLS** (`CriptoRede`) pronto e **desligado**. Medido em par: no ENet do Godot 4.7.2, ele entrega o estado aos solavancos (p95 de 0,1 para 2 a 23 cm). Liga com `--dtls` nas duas pontas.

**Fechado em 23/09, à noite:**

- **3.9 — caído e levantar** (`SocorroEmRede`, nó `Sessao/Socorro`). Em rede, vida zero **derruba**, não apaga. A tela fica escura e vermelha, sem cronômetro, e o corpo vai ao chão (`F_CAIDO`; os outros veem o boneco de pano). No corpo do amigo aparece **[E] Levantar FULANO**. Segurar 3 s mostra o progresso no próprio prompt ("Levantando FULANO 49%") e levanta o amigo com 25 de vida. Quem decide é o servidor: ele conta os 30 s e confere espaço e distância (1,5 m + 1 m de folga) pelas posições que ele mesmo aceitou. Sem ajuda, o caído apaga e acorda no ponto de volta **sem pular a hora**. Se a sessão cai no meio, ele acorda sem pular hora também. O tombo do atropelo (outra frente) devolve câmera e corpo pelo mesmo `Desmaio.acordou`. Não precisou mexer no `player.gd` nem no `tombo_do_jogador.gd`.
  - Nível 4, bots (cenário F): o BOT0 cai, o BOT1 vai **a pé** até ele e o levanta; na segunda queda ninguém vem, e ele apaga no fim da espera. Os outros veem `F_CAIDO`.
  - Nível 4, jogo de verdade (`mp_e2e.sh`, 48 conferências): a vida do anfitrião zera; o convidado chega, mira o corpo e **segura a tecla de verdade** (`Input.parse_input_event`) por 3,7 s. O anfitrião levanta com 25 de vida, controle de volta, e o relógio andou 1 minuto de jogo, o tempo real que passou.
- **3.12 — orelhão em rede:** o convidado não grava o mundo alheio no próprio disco. O orelhão marca o ponto de volta dele (`Desmaio.lembrar_ponto`) e diz "Ponto de volta: …". O anfitrião grava como sempre, com o que os amigos mudaram. O ponto de volta guardado no servidor (para o dedicado) fica para a Fase 6.

- **3.8 — dar item a um amigo** (`MochilaDoServidor`, pura; `MochilasEmRede`, nó `Sessao/Mochilas`). O servidor guarda a sombra da mochila de cada convidado. O convidado a manda ao entrar e a cada mudança, com meio segundo de folga, e o servidor aceita só o que presta: item que existe, pilha que cabe. Dar é **atômico no servidor**: tira de A, põe em B, e o que não coube volta para A. Confere espaço e distância (2 m + 1 m de folga), e quem está caído não dá nada. A API para a tela é `Sessao.mochilas.dar(alvo, espaco, qtd)`, com resposta no sinal `deu`; o recebedor ouve `recebeu`.
  - Nível 2: 13 asserções (pilha, sobra, relatório adulterado com pilha de 99 e item inventado). Rede: 156 asserções.
  - Nível 4 (cenário G): o BOT1 tem lugar para **uma** bandagem só; o BOT0 vai a pé e dá 3, entra 1 e voltam 2; depois dá 2 ao BOT2. Resultado 5→2, 4→5, 0→2: **9 bandagens antes e 9 depois**.

**Falta na Fase 3:**
- 3.8, o resto: largar item no chão (`_pedir_largar` e o item solto por chunk) e o gesto na tela, que é arrastar o item para o retrato do amigo na `prancha_inventario.gd` (outra frente; a chamada é uma linha). A mochila inteira com autoridade do servidor (kit do servidor, mochila guardada pelo token) fica para a Fase 6.
- 3.10, NPC ocupado em conversa: `npc.gd` e `conversa.gd` estão com trabalho de outra frente.

---

## Fase 4 — Carro com passageiros

**Entrada:** 2.7 (estado v2) e 2.9 (réplica completa). Pode correr em paralelo à 3. Capítulo: `09`.

| # | Tarefa |
|---|---|
| 4.1 | `CarroCabine.assento(lugar, medidas)`: os 5 lugares pelos números dos bancos ✋ `carro_cabine.gd` |
| 4.2 | `_pedir_assento` / `_assentos` / `_pedir_descer`; carro a < 2 m/s |
| 4.3 | **Carona pendurado:** `F_CARONA`; extensão `(lugar, motorista)`; desenhado filho do carro em todo cliente (`09` §4) |
| 4.4 | `CabineDoCarona`: cabine na réplica, câmera no lugar, três vistas |
| 4.5 | Estado do motorista +4 B: arfagem e rolagem do carro; sobe `VERSAO` |
| 4.6 | Hermite cúbica na réplica que leva carona (`09` §7.1) |
| 4.7 | **Carro estacionado é coisa do mundo** (`09` §6): `_pedir_estacionar`, `_carro_parado`, troca de dono só parado |
| 4.8 | Colisão: réplica com `AnimatableBody3D`; `_batida(alvo, impulso)` (`07` §6) |
| 4.9 | Eventos: buzina, rádio do carro (a estação é do carro), seta |

**Aceite:** `09` §12, com o carona a < 5 cm do banco no cliente do motorista em todo quadro, e o *jerk* da câmera do carona ≤ 1/3 do linear.

---

## Fase 5 — Grupo e missão

**Entrada:** 3. Capítulo: `08` §6–7.

| # | Tarefa |
|---|---|
| 5.1 | Grupo no servidor: criar, convidar, sair. HOSPEDANDO: todos no grupo do anfitrião |
| 5.2 | `MissaoDoGrupo` (pura); `Missoes` pede a etapa em rede (`_pedir_etapa`), e o segundo pedido da mesma etapa cai calado ✋ `missoes.gd` |
| 5.3 | Primeira missão pela posição do **líder**: todos vão à mesma casa |
| 5.4 | Marca no mapa para o grupo, 120 s (`_pedir_marca`, `_marca`) ✋ `gps.gd`, `minimapa.gd` |
| 5.5 | Mapa de visitados por grupo |

**Aceite:** três bots no grupo; dois pedem a etapa 1 no mesmo tick: a missão avança uma vez; quem entra depois recebe a missão do grupo.

---

## Fase 6 — Dedicado persistente e de produção

Pode **começar já** nos itens 6.1–6.3 (não dependem de outra fase).

| # | Tarefa |
|---|---|
| 6.1 | Templates Linux; preset `Servidor Dedicado Linux` (`18` §2.3) |
| 6.2 | *Strip Visuals* em `assets/`, `resources/materials/` e `shaders/` no preset de servidor; medir tamanho e RAM de novo (hoje 204 MB e 261 MB) |
| 6.3 | Imagem de container a partir do modelo de `18` §7; testar numa VPS com duas casas |
| 6.4 | Identidade por token (P21) na autenticação |
| 6.5 | Persistência: `user://servidor/mundo.json` + `jogadores/<token>.json`, escrita atômica, a cada 2 min e ao encerrar (`18` §10); carros estacionados no `mundo.json` |
| 6.6 | Reentrar devolve posição, mochila e grupo; a aparência vem sempre do cliente (`11` §3.5) |
| 6.7 | HOSPEDANDO: o save do anfitrião guarda `convidados: {token: perfil}`, **sem virar a versão do save** (`08` §4.2) |

**Aceite:** servidor reinicia; o bot reentra e acha o item que pegou na mochila, a porta que abriu aberta e o carro onde estacionou.

---

## Fase 7 — Título, folha de viagem e abertura co-op

**Entrada:** 3 e 5 (e 4.1 para a abertura). Capítulos: `10`, `11`, `12`.

| # | Tarefa |
|---|---|
| 7.1 | JOGAR ONLINE no título, abaixo de NOVO JOGO ✋ `menu.gd`, `titulo_layout.gd` |
| 7.2 | Painel ONLINE: a folha de viagem (abrir meu mundo, na rede, recentes, favoritos, endereço), retrato da carteira |
| 7.3 | Estados da entrada (`10` §4): LIGANDO, AUTENTICANDO, **SENHA pedida na folha**, CARREGANDO, CHEGANDO, FALHOU com o motivo na voz do jogo |
| 7.4 | Entrar pelo título sem a abertura (`10` §5); carteira antes de qualquer conexão (`11` §5) |
| 7.5 | Painel F7 reusa os componentes da folha |
| 7.6 | Folha de viagem da abertura co-op: até 5, PRONTO, ASSINAR (`10` §6) |
| 7.7 | Abertura co-op: ocupantes no `CarroCena`, **relógio do plano** pela hora do servidor, barreira por tomada na praça, voto de pular, roteiro plural só no co-op (`12`) ✋ `abertura_estrada.gd`, `abertura.gd`, `carro_cena.gd` |

**Aceite:** `10` §10 e `12` §8.

---

## Fase 8 — Chão no servidor, mundo vivo, segurança e medida real

| # | Tarefa |
|---|---|
| 8.1 | `ChaoDoServidor`: o mesmo `ChunkBuilder.construir`, instanciando **só** a `colisao`; props como dados; multi-alvo (2 anéis por jogador); cada interior ocupado num `World3D` próprio (`07` §3.2) |
| 8.2 | Conferência de alcance e de item de verdade (fecha os limites de `04` §6) |
| 8.3 | NPC abordado, blitz e inimigo no servidor; o cliente vê réplica. O inimigo só volta à rua com contexto (memória do projeto: *ameaça sem contexto lê como bug*) |
| 8.4 | Perda e atraso simulados no teste (proxy UDP no `mp_teste.sh`): 150 ms, 2 % de perda, *jitter* de 30 ms; ajustar `ATRASO_INTERPOLACAO` pelo número |
| 8.5 | DTLS (`ENetConnection.dtls_server_setup`) com certificado no servidor |
| 8.6 | Admin pelo chat (`/expulsar`, `/anunciar`), `admins.cfg`, lista de bloqueio |
| 8.7 | Playtest de 30 min com 4 pessoas em duas casas |

---

## Fase 9 — Steam (opcional)

`05_PLATAFORMA_STEAM.md`. `SteamMultiplayerPeer` (dentro do GodotSteam desde a 4.17; a 4.22 é a do Godot 4.7.2, conferido em 21/09) no lugar do ENet para "abrir para amigos" sem VPN; convite pelo overlay e `+connect_lobby`; *rich presence*. Primeira tarefa: medir se o peer do Steam respeita a autenticação antes do peer, os canais e o modo não confiável ordenado.

---

## Paralelo

| Seguro em paralelo | Por quê |
|---|---|
| 4 com 3 | o carro não escreve no `WorldState` (o carro estacionado, 4.7, escreve na lista de carros do servidor, não no `WorldState`) |
| 6.1–6.3 com qualquer outra | são export e infraestrutura |
| 2B e 2C com 2A | só mexem em `game/src/net/` |

| Não paralelo | Por quê |
|---|---|
| 3 antes de 2.3 | a validação `corrigir` briga com teletransporte não anunciado |
| 4 antes de 2.7 | o carona usa bits e campos do estado v2 |
| 5 antes de 3 | missão avança por mudança de mundo |
| 7.7 antes de 4.1 | a abertura co-op precisa dos lugares do carro |
| 8.1 sem combinar com a frente da cidade | o chão do servidor usa o `ChunkBuilder` que ela edita agora |

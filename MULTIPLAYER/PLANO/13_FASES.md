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
| 2.2 | `Interiores.semente_atual()` público, no lugar do `get(&"_semente")` | `interiores.gd` | ⏳ a `Sessao` já usa o acessor **se existir** (`has_method`), e avisa uma vez se o campo privado sumir; o acessor em si espera a outra frente |
| 2.3 | **Desmaio em rede não pula a hora**; teletransporte anunciado; o servidor aceita o bit no mesmo espaço no máximo a cada 3 s, e registra | `desmaio.gd`, `interiores.gd`, `save_game.gd`, `cidade.gd` | ✅ desmaio (hora e anúncio) e validador (nível 2); ⏳ interiores, save e `--ir-para` (o salto de mais de 8 m já é marcado sozinho pela `Sessao`); ⏳ `corrigir` como padrão depois do teste com rota que entra em interior |
| 2.4 | Minimapa: ponto de cada jogador do mesmo espaço | `minimapa.gd` | ✅ caneta azul; quem está fora do cartão fica na borda (foto `anfitriao_ve_carro_e_lanterna.png`) |
| 2.5 | `Sessao.jogador_local()`, `corpos(espaco)`, `mais_perto(origem, raio, espaco)`; pedestre, convidado e `casa_viva` reagem aos bonecos (`06` §5.2) | `pedestre.gd`, `convidado.gd`, `casa_viva.gd` | ✅ API e pedestre (contorna o amigo); ⏳ convidado e `casa_viva` |
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

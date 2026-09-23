# 19 — Revisão do código (21/09/2026)

> Por que a v2 do plano é o que é. Três partes:
> 1. o que o código do jogo impõe ao multiplayer hoje;
> 2. os furos da v1 do plano, conferidos contra o código;
> 3. os defeitos que só apareceram **medindo**, na implementação da Fase 1.
>
> Tudo aqui tem arquivo e linha, ou número medido. Se o repo mudar, este arquivo envelhece; os números são de `dcc662e` + working tree de 21/09.

## 1. O que o código impõe

| Fato | Onde | Consequência para o multiplayer |
|---|---|---|
| A cidade sai da coordenada: `rng.seed = hash(Vector2i(cx, cz)) ^ ...` | `chunk_builder.gd:41` | a malha não viaja; basta a mesma versão (P18) |
| Terreno com **relevo**: `Relevo.altura(x, z)`, função pura | `relevo.gd:90` | chegada e servidor calculam o chão sem carregar chunk; o nascimento da `cidade.tscn` (y = 0,5) ficou **18 m acima** do vale (−17,57) |
| O `Player` é **filho estático** da `cidade.tscn` | `cidade.tscn:23` | `MultiplayerSpawner` não serve para o jogador local sem reescrever a cena |
| `cidade.gd` fala com o jogador por `$Player` em **193 linhas** (2.675 no arquivo) | `cidade.gd:9` | a v1 contava 32 pontos de toque; são 235 |
| **42** chamadas `get_first_node_in_group(&"player")` em 30 arquivos | `16` §2 | um segundo `Player` no grupo seria pego por metade delas |
| Quem anda o relógio da cidade é a **HUD** | `hud_cidade.gd:133` | servidor sem HUD tem de andar o relógio (feito) |
| `WorldState.limpar()` **troca** o objeto do relógio | `world_state.gd:73` | ninguém guarda referência ao `Relogio`; a `Sessao` sempre lê `WorldState.relogio` |
| Prop de chunk entra **sem nome** | `chunk_manager.gd`, `_criar_prop` | caminho de nó não é identidade de rede (P20) |
| `ItemNoChao` tem `chunk` + `indice` + `chave()` | `item_no_chao.gd` | a identidade de rede do item **já existe** |
| **14** `WorldState.definir` em **8** arquivos | `08` §1 | a Fase 3 tem de passar os 14 pelo servidor, não 3 |
| `SaveGame` recusa `versao != 2` | `save_game.gd:113` | campo novo entra sem virar a versão (P9) |
| Interiores a y + 2000, no **mesmo lugar** para todo interior; Estrada Velha a y + 4000 | `interiores.gd:16`, `abertura_estrada.gd:130` | espaço por tipo + semente (P20) |
| `Interiores._semente` é **privado** | `interiores.gd:78` | lido por `get()`, com queda segura; a Fase 2 troca por acessor |
| `ChunkManager` segue **um** alvo, com raio do preset de névoa **e** do `FogController` do lugar | `chunk_manager.gd:177,191` | cada cliente carrega em volta de si; o servidor não depende disso até a Fase 8 |
| Pausa é `_unhandled_input` na prancha e na cidade | `prancha_inventario.gd:802`, `cidade.gd` | o painel F7 consome ESC antes, em `_input` |
| Renderer do HEAD: **`forward_plus`**; 32 autoloads do jogo + `Sessao` | `project.godot` | a v1 dizia `gl_compatibility` e 22 autoloads |

## 2. Os furos da v1, conferidos

| # | Furo | Como a v2 resolve |
|---|---|---|
| 1 | Contava 32 pontos de "o jogador" e ignorava o `$Player` de `cidade.gd` | o jogador local não muda; os outros são `AvatarRemoto`, fora do grupo (`03` §4) |
| 2 | `node_path` nos RPCs de item, fala e uso | chave determinística `coord + chave`/`indice` (P20, `04`) |
| 3 | "usar `interpolation` do Synchronizer": **não existe** no 4.7.2 (lista de propriedades medida: `root_path`, `replication_interval`, `delta_interval`, `visibility_update_mode`, `public_visibility`) | `BufferInterpolacao` próprio, com erro medido de 0,1 cm |
| 4 | "save v3 sem quebrar v2" com um `!=` no carregador | campos novos sem virar versão (P9) |
| 5 | A Fase 3 listava 3 arquivos que escrevem no mundo; são 8 | lista completa em `08` |
| 6 | Raio de carga de sessão contra `FogController.usar_preset` | sem raio de sessão: cada um carrega em volta de si (P5) |
| 7 | Topologia só listen server, 2 jogadores, sessão morre com o host | servidor com ou sem jogador; N; o cliente segue sozinho (P1, P2, P11) |
| 8 | Steam como transporte **base** | ENet base; Steam opcional (P3) |

## 3. Defeitos que só a medida mostrou

A Fase 1 foi escrita, rodada com processos de verdade e medida com bots que sabem onde deveriam estar (`bot_rede.gd`). Cada linha abaixo é um defeito que existia no código, com o número antes e depois. Os números servem de régua para regressão.

| # | Defeito | Sintoma medido | Causa | Correção | Depois |
|---|---|---|---|---|---|
| 1 | Estado carimbado na chegada, não na amostra | erro do boneco 7,9 cm (p50) / 16 cm (máx.) a 2,4 m/s | o servidor não sabia a idade do estado; até um tick + viagem viravam posição errada | hora da amostra no pacote do cliente; idade em ms no instantâneo | 0,06 / 0,12 cm |
| 2 | Recado a peer desconectando | `ERROR: Unable to send packet on channel 0, max channels: 0` | `rpc()` geral alcança peer que ainda está em `get_peers()` mas já fechou | `_destinos()`: só peer com ENet `STATE_CONNECTED` | sem ERROR |
| 3 | Derrubar recusado que já saiu | `ERROR: !_is_active() \|\| !peers.has(p_peer)` | o cliente recusado sai sozinho ao ler o veredito | conferir se o peer ainda existe | sem ERROR |
| 4 | Boneco desenhado antes de haver dado | 85 cm de erro no boneco recém-chegado | a primeira amostra era mostrada antes da hora dela | `BufferInterpolacao.cobre(t)`: espera o tempo alcançar | some o transiente |
| 5 | Veredito perdido sob carga | "senha errada" chegava como "o servidor fechou a porta" | no cliente, o ENet entrega a **desconexão antes** dos pacotes do mesmo quadro; o servidor derrubava em 0,3 s | derrubar em 2 s; o motivo da recusa tem precedência | motivo certo em 3/3 rodadas |
| 6 | Relógio de rede subindo devagar | desenho em 7,10 s, amostra mais nova 6,88 s: boneco parado no ar | a estimativa subia 8 % por pacote; quem entrou carimbava 0,3 s atrás por segundos | **toda amostra é limite inferior** (o pacote não chega antes de sair): subida imediata | — |
| 7 | Relógio de rede **voltando** | amostras em 6,999 e 7,000 s e nada por meio segundo | corte seco para baixo quando o desvio passava de 0,5 s: carimbos mais velhos que os entregues eram descartados | descida limitada a 5 % do tempo real: o relógio nunca volta | 3/3 rodadas limpas |
| 8 | Carimbo antes do relógio existir | 80 cm no bot que entrou depois | antes do primeiro instantâneo o cliente mandava "hora 0" e o servidor usava a de chegada | o cliente só manda estado depois do primeiro instantâneo (~50 ms) | — |
| 9 | Servidor parava na primeira entrada | quadro de **130 ms** no servidor, para todo mundo | `load("cidade.tscn")` para ler o ponto de nascimento, no meio do laço | ler ao subir, sem ninguém conectado | 17–40 ms |
| 10 | Lixo de 3 bytes na autenticação | `ERROR: Condition "len < 4"` do motor no log | `bytes_to_var` reclama no console | abaixo de 4 bytes nem decodifica | sem ERROR |
| 11 | Chegada sem relevo | **previsto pela conta, não medido antes da correção:** no dedicado, quem entrasse ficaria 6 s no ar e cairia 18 m | nascimento da cena em y = 0,5 com o chão a −17,6; raio de 9 m | altura por `Relevo.altura` + 1 m; raio de 16 m | aterrissou no chão do vale (medido) |
| 12 | Leitura um quadro atrasada | 4 cm de erro somado (17 ms × 2,4 m/s) | a `Sessao` rodava antes da lógica do jogo | `process_priority = 100` | — |

Dois enganos **meus** na medida, registrados para não se repetirem:

- **"Caiu através do chão."** O convidado apareceu em y = −19,56 e eu li como queda pelo mapa. O controle com o jogo solo, sem rede, caiu para −16,25 no mesmo lugar: é o vale do relevo, e o chão estava lá. Moral: rodar o controle solo antes de culpar a rede.
- **"O anfitrião não vê os bots."** O caminho estava certo (registro temporário: boneco visível, na posição certa). Eram a roupa escura da aparência padrão à noite e o carro posto fora do campo de visão. Moral: confirmar o estado antes de culpar o desenho.

## 3b. Segunda rodada (Fase 2, 21/09 à noite)

A revisão dos capítulos 04–12 contra o código achou quatro coisas que a v1 afirmava e não eram verdade, e a implementação da Fase 2 mediu mais sete.

**O que o plano da v1 dizia e o código desmentiu:**

| Plano v1 | Código em 21/09 |
|---|---|
| "O `Carro` da cidade não tem cabine; 1P ao volante é buraco" (`09`) | tem: `CabineDoJogador` monta a `CarroCabine` com câmera própria e três vistas (`cabine_do_jogador.gd:36`) |
| "Compra no terminal; o host tira o dinheiro" (`08`) | o terminal é a busca do registro civil; não havia dinheiro até 21/09, e o que entrou (`Dinheiro`) mora no `WorldState`, o que em rede seria uma carteira para o servidor inteiro (`08` §1.4) |
| Cinco planos na estrada, falas no lugar antigo (`12`) | sete planos, 62 s; as falas mudaram de plano |
| `RegistroCivil.jogador` sorteado vale para NPC | o id do **jogador** é sorteado (`registro_civil.gd:738`); o dos NPC sai da semente, e é isso que torna as chaves `(id, 424243)` utilizáveis na rede |

**Defeitos medidos na Fase 2:**

| # | Sintoma | Medida | Causa | Conserto | Depois |
|---|---|---|---|---|---|
| 13 | Anfitrião de menu aberto **para o relógio da cidade de todos** | relógio do cliente andou **2,0 s** de jogo em ~13 s reais, com o anfitrião na prancha | a prancha pausa a árvore; quem anda o relógio é a HUD do anfitrião, que para; o servidor segue mandando a hora parada, e o cliente é puxado de volta a cada 5 s | `Sessao.pausar`: em rede trava só o jogador local (`06` §6) | **30,0 s** de jogo no mesmo teste, com a prancha e o menu de sistema abertos a sessão inteira (foto) |
| 14 | Desmaiar pularia a hora de todo mundo | leitura do código (`desmaio.gd:199`) | 3–5 h somadas ao relógio da cidade | em rede, sem pulo | — |
| 15 | Cidade diferente entrava sem aviso | bot com `--sem-relevo` **entrava** num dedicado com relevo (antes da assinatura) | a única trava era `VERSAO`, e `--sem-relevo` nem muda versão | `AssinaturaDoMundo` na autenticação | recusado com "Cidade diferente." |
| 16 | Quadro de **100–121 ms** no dedicado com 8 entradas | 121 e 100 ms em duas rodadas (antes 25–35) | a primeira compilação do `ChunkBuilder` (e de toda a árvore de scripts da cidade), em thread, disputava o carregador com o laço | assinatura calculada **na subida**, sem thread, antes de "pronto" | 25–35 ms; a subida custa 110–154 ms uma vez |
| 17 | Fome de 4,4 % e p95 de 19 cm no cenário A | duas rodadas | os bots do cenário B subiam no meio da medida do A, cada um compilando a cidade para a assinatura | bots calculam a assinatura **antes** de ligar; B roda depois de A | fome 0 %, p95 0,04–0,13 cm |
| 18 | O motorista do carro do amigo não aparece | fotos de lado e de frente, a 5–9 m | o vidro da `Carroceria` é cor opaca (`VIDRO`), igual para o NPC do trânsito | nenhum aqui: é decisão de render. Pesa em `12` (cabeças no vidro da abertura co-op) | — |
| 19 | O trânsito local para em cima do carro do amigo | foto na avenida: um carro da IA colado na réplica | a réplica não tem colisão; a IA daqui não a enxerga | Fase 4.8 (`07` §6) | — |

E mais um engano **meu**, de bancada: pus o carro do bot para circular atrás da fachada da igreja e depois fora do quadro, e o anfitrião foi empurrado 17 m por pedestre (`--ir-para` não é régua, memória do projeto). A foto boa saiu com **câmera presa** (`--olhar-igreja` com cinco números) e **bots parados** (`--bot-parado`, `--bot-giro`), que agora são o modo `mp_dois.sh --carro`.

## 4. A decisão, em uma frase

Separar **quem sou eu** (o `Player` de sempre, intocado) de **quem são os outros** (bonecos da rede, fora do grupo), e pôr **toda a rede num autoload** com o mesmo caminho em todo processo. Isso fez o dedicado e o "abrir para amigos" serem o mesmo código, deixou os 235 pontos de toque do jogador para quando o mundo compartilhado precisar deles (Fase 2) e manteve os arquivos em edição por outra frente intocados. Toques em arquivo compartilhado: duas linhas no `project.godot` (o autoload e a cena principal do build de servidor) e um preset novo no `export_presets.cfg`.

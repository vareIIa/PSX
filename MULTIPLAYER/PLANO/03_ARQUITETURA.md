# 03 — Arquitetura

> **Versão 2.0 — 21/09/2026.** Descreve o que **está no código** (`game/src/net/`) e onde cada fase seguinte encaixa.
> A v1 desenhava `MultiplayerSpawner` + `MultiplayerSynchronizer` + um `Player` por peer. Este documento explica por que isso mudou.

## 1. Camadas

```
┌──────────────────────────────────────────────────────────────────────┐
│ ENTRADA DO JOGADOR                                                   │
│  hoje: painel F7 (PainelOnline) + flags --mp-*                       │
│  Fase 7: JOGAR ONLINE no título + folha de viagem                    │
│  Fase 9: convite Steam / +connect_lobby                              │
└───────────────────────────────┬──────────────────────────────────────┘
┌───────────────────────────────▼──────────────────────────────────────┐
│ SESSÃO — autoload Sessao (/root/Sessao)                              │
│  modo SOLO | HOSPEDANDO | DEDICADO | CONECTANDO | CLIENTE            │
│  jogadores {id: nome, aparência, ping} · chegada · relógio · chat    │
└───────────────────────────────┬──────────────────────────────────────┘
┌───────────────────────────────▼──────────────────────────────────────┐
│ AUTENTICAÇÃO — SceneMultiplayer.auth_callback (antes do peer existir)│
│  desafio{nonce, versão, senha?} → pedido{nome, aparência, prova}     │
│  → veredito{ok | versão | senha | cheio | jogo | pedido}             │
└───────────────────────────────┬──────────────────────────────────────┘
┌───────────────────────────────▼──────────────────────────────────────┐
│ TRANSPORTE — ENetMultiplayerPeer, UDP, range coder, 2 canais         │
│  canal 0: evento confiável   canal 1: estado não confiável ordenado  │
│  24567/UDP jogo   24568/UDP anúncio na rede local (DescobertaLan)    │
│  Fase 9: SteamMultiplayerPeer no mesmo lugar                         │
└───────────────────────────────┬──────────────────────────────────────┘
┌───────────────────────────────▼──────────────────────────────────────┐
│ ESTADO CONTÍNUO — 20 Hz, bytes (ProtocoloRede)                       │
│  cliente → servidor: seq + hora da amostra + estado (35 B a pé)      │
│  servidor → cliente: instantâneo por interesse (13 B + 29 B/jogador) │
│  cliente: RelogioDeRede + BufferInterpolacao → AvatarRemoto          │
└───────────────────────────────┬──────────────────────────────────────┘
┌───────────────────────────────▼──────────────────────────────────────┐
│ MUNDO (Fase 3) — pedido → servidor valida → difunde                  │
│  chave determinística (coord + chave), WorldState no servidor        │
└───────────────────────────────┬──────────────────────────────────────┘
┌───────────────────────────────▼──────────────────────────────────────┐
│ APRESENTAÇÃO — local, por processo                                   │
│  Player de sempre (câmera, input, HUD) · bonecos dos outros          │
│  preset PSX/Moderno, névoa, pós: Settings, nunca na rede             │
└──────────────────────────────────────────────────────────────────────┘
```

## 2. Um servidor, com ou sem jogador

O peer 1 é sempre o servidor. `Sessao.modo` diz se há alguém jogando nele:

- **HOSPEDANDO** (`Sessao.hospedar`): o jogo que já está rodando abre a porta. O `Player` do anfitrião entra na lista como id 1, e o estado dele é lido direto (`_estado_local`), sem passar pela rede.
- **DEDICADO** (`Sessao.hospedar_dedicado`, chamado por `ServidorDedicado`): cena principal própria (`res://scenes/net/servidor_dedicado.tscn`), sem cidade, câmera, menu ou HUD. O processo só autentica, valida, anda o relógio e repassa.
- **CLIENTE** (`Sessao.entrar`): não sabe em qual dos dois entrou.

O dedicado sai de graça deste desenho: não há código "de dedicado" no protocolo. As únicas diferenças são duas linhas:

1. O dedicado anda o relógio da cidade (`WorldState.relogio.avancar`), porque no jogo quem anda o relógio é a HUD (`hud_cidade.gd:133`), e o dedicado não tem HUD.
2. O dedicado não desenha bonecos.

## 3. Por que tudo mora em `/root/Sessao`

RPC do Godot entrega pelo **caminho do nó**. O dedicado roda uma cena principal que não é a cidade, então um RPC em `/root/Cidade/...` não teria para onde ir no servidor. Um autoload tem o mesmo caminho em todo processo.

Por isso:

- todos os `@rpc` são métodos da `Sessao`;
- os bonecos dos outros são filhos de `/root/Sessao/Jogadores` (e os `Interiores` já fazem isso: autoload com filhos 3D, desenhados no mundo da janela);
- ninguém precisa de `MultiplayerSpawner`. Os bonecos nascem de eventos explícitos (`_boas_vindas`, `_jogador_entrou`) e somem por eles (`_jogador_saiu`).

## 4. O jogador local não muda; os outros são bonecos

O `Player` continua **filho estático** de `cidade.tscn`. `cidade.gd` fala com ele por `$Player` em **193 linhas**, e **43 lugares** do jogo acham "o jogador" por `get_first_node_in_group(&"player")`.

A v1 queria tirar o `Player` da cena e spawnar um por peer. Isso exigiria reescrever esses 235 pontos **antes** de o amigo aparecer, em arquivos que outra frente está editando agora.

O desenho novo separa os papéis:

| | Local | Remoto |
|---|---|---|
| Classe | `Player` (a de sempre) | `AvatarRemoto` (novo) |
| No grupo `player` | sim | **não** |
| Câmera, input, HUD, inventário | sim | não |
| Corpo | `Corpo` com a ficha local | `Corpo` com a aparência que chegou (saneada) |
| Movimento | física local | trilha interpolada da rede |
| Carro | `Carro` com `VehicleBody3D` | lataria do mesmo modelo, sem física |

É o que o Unreal chama de *autonomous proxy* e *simulated proxy*. Nenhum dos 43 lugares precisa mudar para o amigo aparecer na rua: como o boneco não está no grupo, eles continuam achando o jogador certo.

O que a Fase 2 ainda precisa fazer é para os **sistemas de mundo** (interior com dois, conversa enquanto o outro anda, pausa que não congela o servidor). Não é mais pré-requisito para ver o outro.

## 5. Estado contínuo: o caminho de um passo

```
Máquina A (quem anda)                       Servidor                        Máquina B (quem vê)
────────────────────                        ────────                        ────────────────────
Player se move (_physics_process)
Sessao lê no MESMO quadro
 (process_priority 100)
carimba com a hora do servidor
 estimada (RelogioDeRede)
 ─── 35 B, canal 1, 20 Hz ─────────────►  valida (ValidadorMovimento)
                                          guarda estado + hora da amostra
                                          20 Hz: instantâneo por destino
                                           só mesmo espaço e < 160 m
                                           idade da amostra em ms ─────────►  RelogioDeRede.amostrar
                                                                               BufferInterpolacao.empurrar(t_amostra)
                                                                               desenha em  agora_servidor − 0,12 s
                                                                               AvatarRemoto.desenhar
```

Cada uma das quatro peças abaixo existe por causa de uma medida (19 §3):

1. **Hora da amostra.** Sem ela o servidor só sabe quando o pacote chegou, e a idade do estado vira erro de posição. Medido antes: **7,9 cm** de mediana e **16 cm** de pico a 2,4 m/s. Depois: **0,06 cm** e **0,12 cm**.
2. **Leitura no mesmo quadro.** A `Sessao` roda depois da lógica do jogo (`process_priority = 100`). Um quadro de atraso são 17 ms, que a pé dão 4 cm.
3. **Relógio que sobe na hora e desce devagar.** Toda amostra é limite inferior do desvio real, porque o pacote não chega antes de sair. A subida é imediata e a descida limitada a 5 %, então o relógio **nunca volta**. O relógio que voltava fazia os estados chegarem "velhos", o buffer descartava, e o boneco parava no ar.
4. **Não desenhar antes de haver dado.** O boneco que acabou de entrar espera o tempo alcançar a primeira amostra (`BufferInterpolacao.cobre`). Antes, ele ficava congelado e dava um pulo de 85 cm.

## 6. Autoridade

| Coisa | Quem manda | Onde está |
|---|---|---|
| Movimento a pé | o dono | cliente simula, servidor valida (`ValidadorMovimento`) |
| Carro | o motorista | idem, até 75 m/s (P6) |
| Entrada na sessão | servidor | `auth_callback` + `julgar_pedido` |
| Relógio da cidade | servidor | `_relogio` a cada 5 s; o cliente só acerta se descolou mais de 1 s |
| Lista, chat, recados | servidor | eventos no canal 0 |
| Mundo (porta, item, plantio, missão) | servidor | **Fase 3** |
| NPC abordado, blitz, inimigo | servidor | **Fase 8** (precisa de chão no servidor, 07 §3) |
| Pedestre e trânsito de rua | local | *flavor*: cada um vê a sua multidão (v1, mantido) |
| Visual (preset, névoa, pós, câmera) | local | nunca na rede |

A física do Godot não é determinística entre máquinas. Nada é simulado dos dois lados esperando que bata: quem é dono simula, e os outros interpolam.

## 7. Espaços

`Sessao.espaco_do_corpo` separa rua, Estrada Velha (y > 3000) e cada interior (y > 1000, identificado por `tipo + semente`). O boneco só desenha no espaço de quem olha, e o servidor só manda quem está no mesmo espaço do destino.

`_semente` é privado em `interiores.gd`, que está em edição em outra frente. A `Sessao` usa `Interiores.semente_atual()` **se existir**; senão lê o campo privado por nome (`_campo`), e avisa **uma vez** no log se ele sumir, em vez de juntar todos os interiores num espaço em silêncio. O acessor público entra quando a frente dos interiores topar (`06` §8).

## 8. Chegada

Quem entra é levado para perto de alguém:

- **HOSPEDANDO:** em volta do anfitrião, num anel de 1,6 m (8 lugares, e depois um anel a 2,4 m).
- **DEDICADO:** em volta do ponto de nascimento da `cidade.tscn`, lido da cena sem instanciá-la (`PackedScene.get_state`) e **pré-carregado ao subir**. Ler na primeira entrada custava **130 ms** de quadro parado no servidor inteiro.

A altura sai do **relevo** (`Relevo.altura`): o nascimento da cena está em y = 0,5, e o terreno ali desceu para −17,6 m quando a ladeira entrou. O corpo fica parado até um raio achar chão numa faixa de 16 m, a mesma espera da bicicleta do respawn. Depois olha para quem está do lado.

## 9. Relação com a outra frente (render, Vulkan, PSX)

```
Settings / EstiloVisual  ──►  shader, névoa, resolução, pós      (local)
Sessao                   ──►  peers, instantâneos, autoridade    (rede)
ChunkManager             ──►  raio de carga do PRÓPRIO jogador   (local)
```

Três eixos independentes. Hoje nada da rede lê o `ChunkManager`. Quando o servidor precisar de chão (Fase 8), ele monta **colisão** em volta de cada jogador, com raio próprio do servidor e sem malha nem material. O conflito do raio de sessão com o `FogController`, apontado na revisão (19 §2.6), deixa de existir no cliente, porque cada um já carrega em volta de si.

## 10. No disco

```
game/src/net/
  sessao.gd               autoload Sessao: modos, auth, RPCs, laço
  protocolo_rede.gd       ProtocoloRede: formato, constantes, saneamento (puro)
  relogio_de_rede.gd      RelogioDeRede: hora do servidor no cliente (puro)
  buffer_interpolacao.gd  BufferInterpolacao: trilha de um remoto (puro)
  validador_movimento.gd  ValidadorMovimento: o que o servidor aceita (puro)
  assinatura_do_mundo.gd  AssinaturaDoMundo: a mesma cidade dos dois lados (puro)
  config_servidor.gd      ConfigServidor: servidor.cfg + linha de comando (puro)
  descoberta_lan.gd       DescobertaLan: anúncio e lista na rede local
  avatar_remoto.gd        AvatarRemoto: o boneco do outro
  painel_online.gd        PainelOnline: F7 (provisório até a Fase 7)
  servidor_dedicado.gd    ServidorDedicado: processo do dedicado
  bot_rede.gd             BotRede: cliente de teste que mede em cm
game/scenes/net/
  servidor_dedicado.tscn  cena principal do dedicado
  bot_rede.tscn           cena principal do bot
game/tests/mp/
  run_tests_rede.gd       nível 2: 136 asserções, sem socket
tools/
  mp_teste.sh             nível 4: dedicados + bots, mede e reprova
  mp_dois.sh              duas janelas do jogo (e --foto, --dedicado)
game/project.godot        +1 linha: Sessao="*res://src/net/sessao.gd"
```

Os `.gd` ficam em `src/` e as cenas em `scenes/` (convenção do skill `godot-project`). As classes puras não tocam em autoload, e é por isso que o teste de nível 2 as alcança: no modo `--script` o Godot não registra autoloads como identificadores.

## 11. Flags

| Flag (depois de `--`) | Onde | Faz |
|---|---|---|
| `--mp-hospedar[=porta]` | jogo | abre este mundo |
| `--mp-entrar=host[:porta]` | jogo | entra num servidor (IP ou nome DNS) |
| `--mp-nome=NOME` | jogo | nome na sessão (senão, o primeiro nome da ficha) |
| `--mp-senha=X` / `--mp-max=N` | jogo | senha e lotação |
| `--mp-painel` | jogo | abre o F7 no início (captura) |
| `--porta= --max-jogadores= --nome= --senha= --mensagem= --sem-lan --validacao= --config= --sair-apos=` | dedicado | 18 §3 |
| `--bot-entrar= --bot-indice= --bot-duracao= --bot-senha=` | bot | 14 §3 |

Compõem com as da cidade: `--pular-menu --pular-abertura --ir-para=x,z,olharx,olharz --shot=...`.

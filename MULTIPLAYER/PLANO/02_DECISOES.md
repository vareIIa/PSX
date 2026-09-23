# 02 — Decisões de produto

> **Versão 2.0 — 21/09/2026.** Substitui a 1.0 (14/09), que era co-op de 2 com o anfitrião como único servidor.
> O pedido mudou: **vários jogadores**, **jogar com amigos pela rede local ou Hamachi**, **servidor dedicado de verdade**.
> Mudar uma decisão é emendar este arquivo **antes** de mudar código. Numeração estável: as fases citam P1–P22.

## Como ler

Cada decisão tem: o que foi escolhido, por quê, o que fica de fora, e — quando mudou da v1 — o que mudou e por quê.
Onde a decisão já está no código, a linha **Estado** diz onde e com que medida.

---

## P1 — Quantos jogadores

**N.** Padrão **8** quando o jogo é aberto para amigos; teto **32** no servidor dedicado.

Por quê: o pedido é "vários players". O protocolo não tem nada de "dois": cada jogador é uma entrada de 29 bytes no instantâneo (27 na v1), e o servidor manda a cada cliente só quem interessa a ele (P19).

Medido (`tools/mp_teste.sh --carga=16`, 17 processos numa máquina de 8 núcleos): **16 jogadores**, erro do boneco remoto **0,10 cm no p95**, **0 %** de amostras sem dado, **5,9 KB/s** por cliente, quadro mais longo do servidor **35 ms**.

Fora: acima de 32 sem nova medida. A montagem do instantâneo é O(n²) por tick e passa de 1 KB por pacote perto de 40 jogadores no mesmo lugar.

**Mudou da v1** (que era "2, só 2"): a v1 amarrava o número ao Marea de cinco lugares e à cena da praça. Isso vale para a **introdução** (P10), não para a sessão.

**Estado:** `ProtocoloRede.MAX_JOGADORES_PADRAO = 8`, `MAX_JOGADORES_TETO = 32`.

## P2 — Topologia

**Servidor autoritativo, peer 1, em dois jeitos de rodar:**

| Modo | O que é | Quem usa |
|---|---|---|
| **HOSPEDANDO** | o jogo aberto para amigos: o processo é servidor **e** jogador | LAN, Hamachi, Radmin, ZeroTier — o "Abrir para LAN" |
| **DEDICADO** | o mesmo servidor, sem jogador e sem tela (`--headless`) | VPS, container, PC ligado no canto |
| CLIENTE | quem entrou em um dos dois | todo mundo |

O cliente **não sabe** em qual dos dois entrou. É o mesmo protocolo, a mesma autenticação, o mesmo instantâneo. Por isso o dedicado não é um segundo produto; ele é o HOSPEDANDO sem a parte de jogador.

Fora: *host migration* (o servidor de amigos que cai não passa a coroa para ninguém) e *mesh* P2P.

**Mudou da v1** (listen server só, "GodotSteam Server não traz MultiplayerPeer"): a v1 descartava o dedicado porque escolheu Steam como transporte base. Com ENet como base (P3), o dedicado sai quase de graça. O custo real dele é a persistência e a autoridade de mundo (P9, Fases 3 e 6), não a conexão.

**Estado:** implementado em `game/src/net/sessao.gd` (modos) e `servidor_dedicado.gd` (processo).

## P3 — Transporte e identidade

**ENet (UDP) é o transporte base.** Ele cobre, sem nenhuma dependência:

- LAN de verdade
- VPN de jogo (Hamachi, Radmin VPN, ZeroTier, Tailscale), que para o jogo é uma LAN
- dedicado na internet (VPS com IP público e a porta UDP aberta)
- "abrir para amigos" na internet, se o anfitrião abrir a porta no roteador

A identidade na v2 é **nome + aparência da carteira**, sem conta. A persistência no dedicado usa um **token local** (P21).

**Steam vira transporte opcional**, numa fase posterior (a 9). Ele serve para convite pelo overlay e para o relay NAT de quem quer "abrir para amigos" sem VPN e sem mexer no roteador. A API alta do Godot não muda: `SteamMultiplayerPeer` entra no lugar de `ENetMultiplayerPeer`.

Fora: login próprio com e-mail e senha; Nakama, PlayFab ou Photon como eixo.

**Mudou da v1** ("Steam primeiro", ENet só para desenvolvimento): o pedido agora nomeia o Hamachi, que é ENet por IP, e servidor dedicado, que é ENet com IP público. Steam como **base** amarraria as duas coisas a uma loja e a um App ID que ainda não existe. A v1 também citava "GodotSteam 4.22 para Godot 4.7.2"; essa combinação **não foi verificada** nesta revisão, e confirmar é tarefa da Fase 9.

**Estado:** ENet com compressão *range coder*, 2 canais, porta padrão **24567/UDP**; descoberta na rede local em **24568/UDP**.

## P4 — Os dois precisam da cópia

Decisão de loja, não de código. Sem mudança.

## P5 — Distância entre jogadores (leash)

**Não há leash de rede.** Cada cliente monta a cidade em volta de si, como no solo: a cidade é determinística (`chunk_builder.gd`, semente pela coordenada) e não viaja.

O servidor manda a cada cliente só os jogadores do mesmo espaço num raio de **160 m** (P19). Quem está longe some do instantâneo do outro, e isso é interesse, não leash.

Leash volta como **regra de missão**, se o design quiser ("espera o grupo antes de entrar"), não como limite técnico.

**Mudou da v1** (soft leash de 80 m por causa do `ChunkManager` de um alvo só): o problema da v1 era o *servidor-jogador* ter de montar chão em volta dos dois. No desenho novo, o servidor não monta chão na Fase 1. Quando precisar de chão (autoridade de NPC e de física, Fase 8), monta **só colisão**, em volta de cada jogador (07 §3).

## P6 — Quem dirige

**Um motorista por carro, e os outros lugares são passageiros** (Marea: 1 + 4).

**Autoridade do carro é de quem dirige**, com validação do servidor. A máquina do motorista simula o `VehicleBody3D`; o servidor valida velocidade e salto (`ValidadorMovimento`, até 75 m/s) e repassa aos outros; passageiros e observadores veem o casco interpolado.

Por quê: com dedicado na internet, simular o carro no servidor põe 80–150 ms entre o volante e a roda. Direção com esse atraso sem predição é inguiável, e predição de veículo é projeto de meses. É o desenho da maioria dos jogos com carro e amigos: quem dirige é dono do carro.

**Mudou da v1** ("host simula o VehicleBody3D, motorista manda input"): na v1 o host era sempre um amigo na mesma cidade, com RTT baixo. Com dedicado, isso deixou de ser verdade.

**Estado:** o carro do outro já aparece como réplica visual, com a lataria do mesmo modelo, a mesma tinta e as rodas no lugar (`AvatarRemoto._montar_veiculo`). Assentos e passageiros são a Fase 4.

## P7 — Missão

**Missão por grupo.** O servidor guarda uma missão por grupo, e cada jogador está em exatamente um grupo.

- HOSPEDANDO: quem entra cai no grupo do anfitrião. É o co-op de amigos, com uma missão para todos, como a v1 queria.
- DEDICADO: cada um começa num grupo de um, e convidar põe no mesmo grupo.

O HUD de cada um lê a missão do próprio grupo. Qualquer membro cumpre a etapa, e ela avança para o grupo inteiro.

Fora: missões paralelas no mesmo grupo.

**Mudou da v1** ("uma missão compartilhada"): com 16 estranhos num dedicado, uma missão para o servidor inteiro não faz sentido. O grupo é a generalização que devolve exatamente o comportamento da v1 no caso de amigos.

## P8 — Inventário e vida

**Pessoais, com a verdade no servidor.** Cada jogador tem os seus 8 slots e a sua vida. Item no chão é do mundo, e quem pedir primeiro leva: o servidor serializa, e o segundo pedido falha em silêncio.

A identidade de rede do item é **`(chunk, indice)`**, que o `ItemNoChao` já tem (`chave()`), e **não o caminho do nó** (P20 e `04` §3).

## P9 — Save

| Modo | Quem grava | O quê |
|---|---|---|
| SOLO | o jogo | como hoje, `SaveGame` v2, 3 slots |
| HOSPEDANDO | o anfitrião | o save dele, com o mundo; os convidados não gravam o mundo do anfitrião |
| DEDICADO | o servidor | **mundo persistente** (`WorldState`, relógio) + **perfil por jogador** (inventário, vida, posição, missão, grupo) pelo token (P21), em `user://servidor/` |

O `SaveGame` **recusa qualquer versão diferente de 2** (`save_game.gd:113`, `!=`). Campo novo entra **sem virar a versão**, como o próprio arquivo já faz com `missao` e `hora`. Virar para v3 invalida todos os saves existentes.

## P10 — Introdução

**Local por padrão.** Cada jogador vê a introdução solo antes de entrar numa sessão, ou pula.

A **introdução co-op** (os corpos no Marea desde o plano 1, cinema com o tick do servidor) é só para quem **começa a viagem junto**, pela folha de viagem (Fase 7): até **5** pessoas, os lugares do carro. Quem entra depois não vê a intro de ninguém; aparece ao lado do grupo.

**Mudou da v1:** a v1 tinha dois, sempre juntos desde o título. Com entrada no meio da sessão (P17) e dedicado 24 h, "todo mundo assiste junto" não existe para a maioria das entradas.

## P11 — Quem cai

| Evento | Efeito |
|---|---|
| Cliente sai ou cai | Os outros leem "fulano saiu", e o boneco some. |
| Anfitrião (HOSPEDANDO) sai | **Cada cliente continua sozinho, no próprio mundo, onde estava.** Recado: "O servidor fechou. Você continua sozinho aqui." |
| Dedicado reinicia | Os clientes voltam para o solo; ao reentrar, o perfil volta pelo token (Fase 6). |
| Silêncio | Queda depois de **8 s** (timeout ENet: mínimo 3 s, máximo 8 s). |

**Mudou da v1** ("host sai → convidado volta ao título"): a cidade do cliente é dele, e jogá-lo no título descarta uma cidade inteira montada por nada.

**Estado:** implementado (`Sessao._ao_servidor_cair`).

## P12 — Canon

Emendar `docs/PROMPT-MESTRE.md` §5: riscar "Não tem multiplayer" e escrever "multiplayer opcional: jogar com amigos na rede (LAN, VPN de jogo) e servidor dedicado. Single-player continua sendo o caminho padrão".

**Estado:** não feito. O mestre é canon de outra frente; a emenda é do usuário.

## P13 — Renderer e netcode

**Agnósticos.** O HEAD já está em `forward_plus`, e PS1 STYLE é preset (memória do projeto: *MODERNO não é PSX forçado*).

A sessão não replica preset, névoa visual, resolução nem pós, e dois jogadores podem estar em presets diferentes.

O que **não** pode divergir: versão do jogo (P18), estado de mundo e posições.

## P14 — Voz e chat

Voz: fora (Discord, overlay).

Chat de texto: **dentro**, uma linha de até 96 caracteres, saneada, no máximo 5 mensagens por 5 s por jogador.

**Estado:** implementado (`Sessao.falar`, F7).

## P15 — Autoridade e trapaça

| Coisa | Autoridade | Guarda |
|---|---|---|
| Movimento a pé | o dono (cliente) | `ValidadorMovimento`: distância por tempo, com o menor entre o relógio do servidor e o `seq` (+0,5 s); política `registrar` (padrão) ou `corrigir` |
| Carro | o motorista | o mesmo validador, até 75 m/s |
| Mundo (porta, item, plantio, missão, relógio) | servidor | pedido → servidor valida → difunde (Fase 3) |
| Entrada | servidor | desafio com nonce, `sha256(nonce:senha)`, versão, lotação, **antes** de o peer existir |
| Texto de outra máquina | — | saneado (controle, teto), aparência presa em faixa por chave |

A política padrão é `registrar` e não `corrigir` porque o jogo ainda tem teletransportes que não se anunciam. O `F_TELEPORTE` cobre os que a `Sessao` enxerga (mudança de espaço, salto de mais de 8 m) e os que o jogo anuncia (`Sessao.anunciar_teletransporte()`, hoje no desmaio). No mesmo espaço, o servidor aceita o bit **no máximo uma vez a cada 3 s** e registra cada uso: um cliente adulterado ainda consegue "viajar" de 3 em 3 s, e num servidor de amigos isso é aceito às claras (`06` §7). Virar `corrigir` para padrão depende do teste com uma rota que entra e sai de interior.

Fora: anticheat de kernel e ban global.

## P16 — Single-player não regride

`Sessao` em SOLO não processa nada (`set_process(false)`), e o jogador local continua sendo o `Player` de sempre.

**Medido:** o boot headless do working tree tem os mesmos avisos com e sem a `Sessao` (só o vazamento de 94 objetos no encerramento, que é anterior).

---

## Decisões novas da v2

### P17 — Entrada no meio da sessão

**Sim.** O dedicado não existe sem isso. Quem entra recebe a lista, o relógio e o ponto de chegada. A partir da Fase 3 recebe também o `WorldState.para_dicionario()` do servidor.

**Estado:** entrada e chegada implementadas; o estado do mundo é da Fase 3.

### P18 — Versão e cidade

Duas travas, cada uma para uma coisa:

- **`ProtocoloRede.VERSAO`**, igual dos dois lados, sobe a cada mudança de **formato de pacote**. Hoje é 2 (estado de 23 B).
- **A assinatura da cidade** (`AssinaturaDoMundo`, `07` §2.1): o próprio gerador resume 4 chunks, e duas máquinas com cidades diferentes são recusadas, mesmo com a mesma versão. Duas versões do `chunk_builder` desenham ruas diferentes no mesmo lugar sem nenhum erro na tela, e `--sem-relevo` nem muda versão.

A v2.0 desta decisão pedia que **quem mexesse no gerador** subisse a `VERSAO`. Era a trava mais fraca possível: o gerador é editado todo dia por outra frente, e a assinatura mudou duas vezes só em 21/09. A assinatura não depende de ninguém lembrar.

Recusa sempre **com o motivo** ("Versão diferente." / "Cidade diferente. Atualize o jogo dos dois lados."), e na lista da rede local o servidor aparece marcado, sem sumir.

**Estado:** implementado e medido (nível 4: bot com `--sem-relevo` recusado, no editor e no executável exportado).

### P19 — Interesse

O servidor manda a cada cliente só os jogadores **do mesmo espaço** e a até **160 m**. Os outros continuam na lista (nome e ping), mas sem posição.

**Estado:** implementado (`Sessao._enviar_instantaneos`).

### P20 — Espaços e identidade de coisa no mundo

Dois corpos só se veem no **mesmo espaço**: rua, Estrada Velha (y 4000) ou cada interior (y 2000, por `tipo + semente`). Dois interiores diferentes são montados **no mesmo lugar**; sem espaço, quem está no mercado veria o amigo do bar andando por dentro das gôndolas.

Coisa do mundo é identificada por **chave determinística** (`coord` do chunk + `chave`/`indice`), nunca por caminho de nó: prop de chunk entra sem nome (`chunk_manager.gd`, `_criar_prop`), e o Godot numera com um contador **do processo** (`@Porta@37` aqui, `@Porta@112` lá).

**Estado:** espaço implementado; chaves de mundo são da Fase 3.

### P21 — Identidade sem conta

Na primeira vez que joga online, o cliente gera um **token aleatório** (`user://identidade.cfg`) e o manda na autenticação. No dedicado, o perfil é guardado por esse token. Quem copiar o token de outro pode entrar como ele; num servidor de amigos isso é aceitável, e para público entra a identidade Steam (Fase 9).

**Estado:** Fase 6.

### P22 — Onde o dedicado roda

**Export Linux x86_64 em modo *Dedicated Server*, com `--headless`, dentro de um container**, numa VPS ou num PC ligado. Orquestração (Edgegap, Agones, PlayFab) só quando houver fila de jogadores para escalar. Passo a passo em `18_SERVIDOR_DEDICADO.md`.

**Estado:** o processo roda hoje com o binário portable (`--headless`). Preset de export e imagem de container são da Fase 6.

---

## Resumo de uma linha

Vários jogadores, servidor manda, com ou sem jogador sentado nele; ENet para LAN, Hamachi e dedicado; Steam depois; cada um dono do próprio passo e do próprio volante, com o servidor conferindo; mundo e mochila na mão do servidor; grupo com missão; ninguém perde a própria cidade quando o servidor cai; solo intacto.

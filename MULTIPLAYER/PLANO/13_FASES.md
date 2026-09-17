# 13 — Fases (passo a passo)

> A ordem de trabalho. Não pular. Cada fase tem entrada, tarefas numeradas, arquivos, aceite e o que **não** entra.
> Definição de pronto: `14_TESTES_E_ACEITE.md` + P16 (single intacto).

```
0 Canon
  → 1 Dois processos (ENet, praça, dois Player)
    → 2 Refator “o jogador”
      → 3 Mundo compartilhado mínimo
        → 4 Carro 2P
          → 5 Intro 2P
            → 6 Lobby diegético + criação dois
              → 7 Steam (relay, convite, overlay)
                → 8 Polimento online
```

3b (dual-target streaming) e plano B (código de sala) são **depois** de 8, se a direção pedir.

A frente **Vulkan / PSX opcional** corre em paralelo e **não** é fase deste plano. O netcode não espera ela. Encaixe: P13, `07` §10, `05` §9.

---

## Fase 0 — Canon

**Entrada:** este plano existe. Código de rede ainda não.

### Tarefas

0.1 Emendar `docs/PROMPT-MESTRE.md` §5: riscar “Não tem multiplayer”; acrescentar o parágrafo de co-op 2P (P12).  
0.2 Uma linha em `PROGRESSO.md` apontando para `MULTIPLAYER/PLANO/00_LEIA-ME.md`.  
0.3 **Não** emendar ART-BIBLE. PSX vira opção em outra frente; o ART-BIBLE continua sendo o contrato do *preset* PSX.

### Aceite

- O mestre não contradiz o trabalho.
- Zero código de gameplay nesta fase.

### Não entra

Vulkan, Steam partnership, UI.

---

## Fase 1 — Dois processos locais

**Entrada:** Fase 0. Ainda pode haver `get_first_node_in_group` — o segundo corpo existe, mesmo que GPS/chunk ignorem ele. O objetivo é **ver** o outro andar.

### Tarefas

1.1 Criar `game/src/net/sessao.gd`, autoload `Sessao`. Modos SOLO / COOP. Flags `--mp-host`, `--mp-join=IP`, `--mp-pular-lobby`, `--mp-pular-intro`.  
1.2 `transporte_enet.gd`: host `create_server(24567, 2)`, client `create_client(ip, 24567)`.  
1.3 Nó `Jogadores` na cidade + `MultiplayerSpawner`. Spawn de `player.tscn` por peer, nome `p_%d`, authority no dono.  
1.4 `MultiplayerSynchronizer` em `player.tscn`: position, rotation.y.  
1.5 Input só com `is_multiplayer_authority()`. `Camera3D.current` só no local.  
1.6 Boot: `--mp-host --pular-menu --pular-abertura` e o join equivalente → os dois na praça.  
1.7 Script de lançamento `tools/mp_dois.ps1` (ou entrada em `dev.sh`): abre dois Godot `--path game` com as flags, janelas deslocadas.

### Arquivos novos / tocados

`sessao.gd`, `transporte.gd`, `transporte_enet.gd`, `project.godot` (autoload), `cidade.gd` (flags), `player.tscn` / `player.gd` (authority, camera), `scenes/test/cidade.tscn` (nó Jogadores + Spawner).

### Aceite

- Dois executáveis, um anda, o outro vê o boneco mover com atraso < 100 ms em localhost.
- Solo sem flags: um player, como hoje.
- `--headless --quit` ainda passa (Spawner sem peer não quebra o boot).

### Não entra

Steam, lobby UI, WorldState RPC, intro, inventário por peer, dual chunk.

---

## Fase 2 — Refator do jogador

**Entrada:** Fase 1 verde.

### Tarefas

2.1 API `Sessao.jogador_local / parceiro / jogadores / mais_perto / alvo_de_streaming`. Em SOLO, equivalentes ao único player.  
2.2 Reescrever os 32 call sites (`06`, tabela). Um arquivo por commit se possível.  
2.3 `RegistroCivil`: `jogador` = local; `ficha_de(peer)` para o resto.  
2.4 Inventário caminho A (`06` §6): estado no Player; autoload vira catálogo + “do local” como açúcar.  
2.5 Pausa: prancha **não** pausa a SceneTree em `modo == COOP`.  
2.6 Conversa: trava só quem falou (mesmo que o NPC ainda não replique — pelo menos o outro Player anda).

### Aceite

- GPS, minimapa, save solo, interiores solo, conversa solo: testes atuais verdes.
- Coop na praça: cada um tem HUD próprio; conversa de um não congela o outro.
- `grep get_first_node_in_group.*player` só em `Sessao` (ou zero).

### Não entra

Item no chão replicado (isso é 3), carro, Steam.

---

## Fase 3 — Mundo compartilhado mínimo

**Entrada:** Fase 2 verde.

### Tarefas

3.1 `Sessao.alvo_de_streaming()` + `RAIO_CARGA_COOP` (`07`). ChunkManager, Multidao, Transito leem isto.  
3.2 Soft leash 80 m + recado na faixa + ícone do parceiro no minimapa.  
3.3 RPCs `pedido_pegar_item` / `item_sumiu`, `pedido_porta` / `mundo_mutou`. Host é WorldState.  
3.4 Relógio do host.  
3.5 Missão: host avança, `missao_atualizou`. Qualquer um marca o GPS da etapa 1.  
3.6 Interior v1: os dois entram juntos ou a porta recusa.  
3.7 Flavor local: pedestre/trânsito **não** replicados. Blitz: host spawna uma.

### Aceite

- Um pega a semente no chão, some nos dois, só a mochila dele ganha.
- Um abre porta, os dois passam.
- Um dispara 200 m: aviso, chunks não explodem (medir `chunks_carregados` no overlay F3).
- Solo: ponto de save, missão, interior — iguais.

### Não entra

Dual-target, replicar pedestre, cabine, Steam.

---

## Fase 4 — Carro 2P

**Entrada:** Fase 3 verde. Poses de banco podem nascer aqui e a intro as reusa.

### Tarefas

4.1 `_pose_volante` e `_pose_passageiro` em `corpo.gd`. Teste `medir_sentado` equivalente (`tests/medir_sentado.gd` já existe para a pose de chão — irmão para banco).  
4.2 Assentos no `Carro` (`09`). RPCs `pedido_assento` / `assento_mudou`.  
4.3 Host simula `VehicleBody3D`; motorista manda input.  
4.4 Corpo visível no banco para o outro (`visible = false` no Player inteiro **acaba**).  
4.5 `CarroCabine` no carro da cidade quando há passageiro (ou sempre que um player senta).  
4.6 Câmera do passageiro. Saída −X / +X.  
4.7 `Transito._do_jogador` → carro da sessão.

### Aceite

Lista em `09` §9. Solo dirigir: igual (perseguição V, painel, rádio).

### Não entra

Intro, `CarroCena` ocupantes (Fase 5), bicicleta 2P.

---

## Fase 5 — Intro 2P

**Entrada:** Fase 4 tem poses e lados. Lobby ainda pode ser flags.

### Tarefas

5.1 `CarroCena` monta dois `Corpo` do roster (em dev, duas aparências dummy se o lobby não existe).  
5.2 Ocupantes visíveis nos planos 1–3 sem ligar a cabine interna que fura o vidro (`12` §3).  
5.3 `plano_de_cinema` RPC. Cliente não avança relógio próprio.  
5.4 Roteiro plural **só** em `modo == COOP`. Solo mantém `FALAS` atuais.  
5.5 Praça: dois deitados no take da igreja; fade → cada um 1P.  
5.6 Capturas em `captures/multiplayer/`.

### Aceite

`12` §8. Emenda estrada→praça no preto nos dois processos.

### Não entra

Folha de viagem, Steam, dual-target.

---

## Fase 6 — Lobby e criação dois

**Entrada:** intro 2P funciona com flags.

### Tarefas

6.1 Entrada JOGAR COM AMIGO no título (`10`).  
6.2 `lobby.gd` folha de viagem, UI-BIBLE.  
6.3 Painel `LOBBY` no Menu. Ramo “na estrada” (cor, não CRT).  
6.4 Cada peer NOME→APARENCIA existente, roster, retratos vivos.  
6.5 Host só assina com 2 prontos + 2 aparências. `viagem_comecou`.  
6.6 ESC volta ao título, peer morre, single intacto.  
6.7 Capturas `lobby_dois.png`, `lobby_espera.png`.

### Aceite

`10` §10 e `11` §7. Caminho sem flags: título → JOGAR COM AMIGO → carteiras → folha → intro.

### Não entra

Overlay Steam (stub CONVIDAR mostra IP em dev).

---

## Fase 7 — Steam

**Entrada:** Fase 6 jogável em LAN. Parceria Steamworks + App ID (ops paralelo, pode começar na Fase 0).

### Tarefas

7.1 GDExtension GodotSteam 4.22 no projeto, sem trocar o portable de `.tools/`.  
7.2 Init, falha amigável, CONTINUAR/NOVO sem Steam.  
7.3 `transporte_steam.gd`, `SteamMultiplayerPeer`, `server_relay = true`.  
7.4 Lobby friends-only max 2, metadata, overlay invite.  
7.5 `+connect_lobby` lido **antes** do CRT longo (`05` §4.5). `join_requested` in-game.  
7.6 Rich presence.  
7.7 Export: `steam_api64.dll`, App ID, teste em duas contas / duas máquinas **sem** port-forward.  
7.8 Smoke no build Vulkan, quando ele existir (`Steam.steamInitEx`).

### Aceite

- Casa A convida casa B pelo overlay. Os dois passam na folha, na intro, na praça.
- Sem Steam: JOGAR COM AMIGO explica e oferece o caminho LAN se `OS.is_debug_build()`.
- Single não pede Steam.

### Não entra

VoIP, Steam Input glyphs, dedicated server Steam.

---

## Fase 8 — Polimento online

**Entrada:** Fase 7 verde em duas casas.

### Tarefas

8.1 Host cai / convidado cai (P11) com recado, sem crash, sem nó zumbi.  
8.2 Timeout ~8 s.  
8.3 Rate limit de RPC (`04` §9).  
8.4 Filtro de texto no recado.  
8.5 Reconnect: **não** implementar; só mensagem clara.  
8.6 Medir banda e hitch com F3 nos dois presets visuais (PSX e Vulkan). Ajustar Hz do Synchronizer.  
8.7 Playtest de 30 min: carro, interior, missão, um dispara 80 m, um abre a prancha.  
8.8 Página Steam: flags Co-op (2).  
8.9 Testes automatizados da lista em `14`.

### Aceite

`17_CHECKLIST.md` inteiro. P16 verificado com a suíte solo.

---

## Depois, se a direção pedir

| Item | Depende de |
|---|---|
| Dual-target streaming (explorar separado) | 8 + medida Vulkan |
| Interior desacoplado | 8 |
| Passageiro assume volante | 4 já deixou o gancho |
| Código de sala / itch | 7 estável |
| Convidar num CONTINUAR | save v3 + 7 |
| Voz in-game | nunca, se o overlay bastar |
| 3+ jogadores | recusar até P1 mudar neste documento |

---

## Como paralelizar (quando houver mais de um executor)

Seguro em paralelo:

- Fase 0 + ops Steam (App ID) + UI mock da folha (sem peer)
- Poses de banco (`corpo.gd`) durante a Fase 2
- Roteiro plural (só texto) durante a Fase 4
- Frente Vulkan **inteira**, desde que não mude a API de `ChunkManager.alvo` sem avisar

Não paralelo:

- Fase 1 e 2 (2 precisa do spawn)
- 3 e 4 (assento é mutação de mundo)
- 5 e 6 (intro precisa das aparências; 6 pode **começar** UI, mas `viagem_comecou` é 5+6)
- 7 em cima de 1 sem 6: Steam conecta e o jogador cai num título sem folha

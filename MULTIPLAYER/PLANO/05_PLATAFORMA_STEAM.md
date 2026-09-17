# 05 — Plataforma Steam (e o que existe sem ela)

> Fase 7 no calendário. A Fase 1 **não espera** isto. O peer é plugável.

## 1. Por que Steam e não “login nosso”

O pedido é convidar amigos e jogar online. Em 2026, para um indie Godot de 2 jogadores, a lista honesta é:

| Caminho | NAT | Convite | Identidade | Custo | Serve este jogo? |
|---|---|---|---|---|---|
| ENet cru | host abre porta UDP | IP na voz | nenhuma | 0 | Só LAN / dev |
| WebRTC + signaling próprio | melhor, precisa STUN/TURN | código de sala | fraca | servidor 24/7 | Plano B |
| Noray / NodeTunnel | relay | código | fraca | hostear relay | Plano B itch |
| GD-Sync / Photon | relay deles | lobby deles | conta deles | mensalidade | Evitar como eixo |
| Nakama | você hosteia | você constrói | você constrói | ops | Overkill para 2P |
| EOS | sim | sim | Epic | 0, outra loja | Só se EGS for alvo |
| **GodotSteam + SDR** | **sim** | **overlay nativo** | **SteamID** | **$100 Direct** | **v1** |

Godot **não** traz NAT traversal. ENet sozinho não é produto. Dome Keeper (Godot, co-op em 2026) e o ecossistema GodotSteam existem exatamente para este furo.

## 2. Conta e App ID (ops, não código)

Passos reais, fora do Godot:

1. `partner.steamgames.com` — parceria Steamworks, contrato, banco, imposto (W-8BEN se Brasil).
2. Steam Direct: **USD 100** por app, recuperável depois de USD 1.000 de receita.
3. Criar o produto, anotar o **App ID**.
4. Página da loja: marcar **Co-op (2)**, Online Co-op, não só Single-player — senão o Discovery não lista em multiplayer.
5. Age gate: o jogo tem casa da fumaça, plantio, bar. Resolver classificação cedo.
6. Demo / playtest: App IDs extras. GodotSteam 4.20+ aceita vários App IDs no Project Settings e um campo de “tipo”.

Sem App ID o `Steam.steamInit()` falha fora do cliente Steam. Dev usa ENet.

## 3. GodotSteam neste repo

| Item | Valor |
|---|---|
| Godot do repo | 4.7.2 portable em `.tools/` |
| GodotSteam alvo | **4.22** (agosto 2026), SDK Steamworks **1.65** |
| Forma | **GDExtension**, não módulo C++ / Godot custom |
| Peer | `SteamMultiplayerPeer` no próprio GodotSteam (o plugin ExpressoBits está pausado desde dez/2025 — **não usar**) |
| Callbacks | `Steam.run_callbacks()` **todo frame** (autoload) |

Não trocar o binário de `.tools/` por um GodotSteam-module. O projeto inteiro (skills, `dev.sh`, captura) assume o portable. GDExtension carrega em cima dele.

`steam_api64.dll` precisa ir no export. GodotSteam 4.20+ tenta atualizar a DLL no Windows se a do editor estiver velha — conferir no pipeline de `export_presets.cfg`.

## 4. Fluxo Steam no jogo

### 4.1 Init

No autoload `Sessao` (ou `SteamBoot`):

- `Steam.steamInitEx()` no `_ready` se `OS.has_feature("steam")` ou se o cliente Steam está aberto.
- Falha: JOGAR COM AMIGO mostra “Abre a Steam e tenta de novo.” CONTINUAR / NOVO JOGO não dependem disto (P16).
- `steam_appid.txt` na pasta do `.exe` em dev. No ship, o App ID vem do Project Settings.

### 4.2 Lobby

Espelhar o tutorial oficial (atualizado junho/2026):

```
Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 2)
```

Metadados (não são netcode de gameplay; são o cartão da folha de viagem):

| Chave | Valor |
|---|---|
| `nome_host` | string |
| `fase` | `lobby` / `criacao` / `jogo` |
| `seed` | quando a viagem começa |
| `pronto_1` `pronto_2` | 0/1 |
| `aparencia_1` `aparencia_2` | JSON curto |

Teto de metadata Steam é folgado para dois retratos em dict de ints.

### 4.3 Convite

Três entradas, as três obrigatórias para “convidar amigos” ser verdade:

1. **In-game:** botão na folha de viagem abre `Steam.activateGameOverlayInviteDialog(lobby_id)` — lista de amigos do overlay.
2. **Overlay Shift+Tab** no anfitrião, convite clássico.
3. **Jogo fechado:** convidado aceita, Steam lança com `+connect_lobby <id>`. Autoload lê `OS.get_cmdline_args()` **antes** do boot CRT terminar. Se esperar o título, o convite morre.

Sinal: `Steam.join_requested` com o jogo já aberto.

### 4.4 Peer

Quando o lobby está com 2 e o host manda começar (ou já no “pronto”, conforme `10_MENU_E_LOBBY.md`):

```
var peer := SteamMultiplayerPeer.new()
peer.create_host(0)          # host
peer.server_relay = true
multiplayer.multiplayer_peer = peer
```

Convidado: `peer.create_client(host_steam_id, 0)`.

Não usar a API `Networking` depreciada do Steamworks. Valve manda Networking Sockets / Messages. `SteamMultiplayerPeer` encapsula isso e fala a língua da SceneTree.

### 4.5 Convite com o jogo no BOOT CRT

`cidade.gd` hoje segura o jogador no tubo. Se o Steam lançou com `+connect_lobby`, o caminho é:

1. Guardar o lobby id.
2. Rodar o boot CRT **ou** pular com fade curto (decisão de direção: o tubo é identidade; um convite não precisa dos 20 s).
3. Ir para o lobby-documento, não para o título.
4. Não abrir NOME/APARENCIA do single.

Recomendação: boot CRT **curto** (placa + 2 s) quando há `+connect_lobby`, depois lobby. O tubo inteiro é para quem abriu o .exe sozinho.

## 5. Rich presence

Depois que a sessão existe:

| Estado | Texto |
|---|---|
| Lobby | “Marcação — São Thomé das Letras” |
| Intro estrada | “Na Estrada Velha” |
| Praça | “Praça da Matriz” |
| Cidade | “Andando de noite” / nome do bairro se houver |
| Carro | “No Marea” |

Serve Join Game pelo overlay. Barato, alto impacto.

## 6. Voz, filtro, input

- Voz: overlay. Não implementar.
- `initFilterText` no chat da folha (GodotSteam 4.20 removeu parâmetro — conferir changelog).
- Steam Input / glyphs: GodotSteamKit tem ferramentas em 2026. **Não** bloquear v1 nisso. Teclado/mouse que já existe.

## 7. Steam Deck / Steam Machine / Frame

SDK 1.65 (GodotSteam 4.21) acrescenta detecção de hardware novo. O jogo já é 480×270 no preset PSX e Compatibility; Deck deve rodar. Verificar:

- overlay no Deck
- convite
- performance no caminho Vulkan quando ele existir

Não é bloqueio da Fase 7. É checklist de ship.

## 8. Plano B (sem Steam)

Só depois da Fase 7 estável, se itch ou build solta importar:

1. Manter `TransporteEnet`.
2. Código de sala de 4–5 chars.
3. Relay: NodeTunnel (drop-in no ENet) ou Noray (punch + relay). Alguém tem que hostear.
4. Identidade: apelido digitado (já temos ficha). Sem SteamID, convite é o código falado no WhatsApp.

Não misturar plano B na Fase 1 além do ENet local. ENet local **é** o plano de desenvolvimento, não o de itch.

## 9. O que a outra frente (Vulkan) não muda aqui

Steam não sabe se o Viewport é Compatibility ou Forward+. Init, lobby, peer, convite, presence são iguais. O export Windows continua um `.exe`; se um dia houver dois renderers no mesmo binário (feature tags) ou dois executáveis, os dois carregam a mesma GDExtension.

Único cuidado: GDExtension GodotSteam testada no renderer novo. Smoke: `Steam.steamInitEx()` no build Vulkan.

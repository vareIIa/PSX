# 05 — Steam e o que existe sem ela

> **Versão 2.0 — 21/09/2026.** Revisado. Na 1.0, Steam era **a base** do multiplayer, e ENet só servia para desenvolver. Na v2, ENet é a base (P3) e já cobre LAN, VPN de jogo e dedicado. Steam vira a **Fase 9, opcional**, e serve para duas coisas que o ENet não faz sozinho: **convidar pelo overlay** e **atravessar NAT sem VPN**.
> A 1.0 citava "GodotSteam 4.22 para Godot 4.7.2" sem fonte. Nesta revisão foi conferido (§3).

## 1. O que cada caminho resolve

| Caminho | Atravessa NAT? | Convite | Identidade | Custo | Neste jogo |
|---|---|---|---|---|---|
| **ENet por IP** (✅ Fase 1) | só com a porta aberta | IP no Discord | nome + aparência; token na Fase 6 | 0 | **base**: LAN, dedicado com IP público |
| **ENet por VPN de jogo** (Hamachi, Radmin, ZeroTier, Tailscale) (✅) | a VPN atravessa | IP virtual; a lista da rede local acha sozinha | idem | 0 (a VPN é do jogador) | **base** para "abrir para amigos" pela internet hoje |
| **Steam** (GodotSteam + `SteamMultiplayerPeer`) | sim, pelo relay da Valve (SDR) | overlay, "Entrar no jogo" | SteamID | USD 100 por app (Steam Direct) | **Fase 9**: "abrir para amigos" sem VPN e sem roteador |
| WebRTC + sinalização própria | quase sempre; precisa TURN | código de sala | fraca | um servidor 24 h | não |
| Relay de terceiros (Noray, NodeTunnel, GD-Sync, Photon) | sim | código | deles | hospedar ou mensalidade | não como eixo |
| EOS (Epic) | sim | sim | conta Epic | 0 | só se a Epic Store for alvo |

O que o Steam acrescenta **de verdade** ao que já existe: o amigo sem VPN, atrás de um roteador que não abre porta, recebe um convite e entra com um clique. É o fluxo que a maior parte das pessoas espera de "jogar com amigo" em 2026. O dedicado **não** precisa de Steam: ele tem IP público.

## 2. Conta e App ID (operação, não código)

1. `partner.steamgames.com`: parceria Steamworks, contrato, banco, imposto (W-8BEN para quem declara no Brasil).
2. Steam Direct: **USD 100** por app, recuperável depois de USD 1.000 de receita.
3. Criar o produto e anotar o **App ID**.
4. Página da loja: marcar **Online Co-op** e **LAN Co-op**, não só Single-player; sem isso, o jogo não aparece nas buscas de multijogador.
5. Classificação etária: o jogo tem bar, casa da fumaça e plantio. Resolver cedo.

Sem App ID, `Steam.steamInitEx()` falha fora do cliente Steam. Para desenvolver, o App ID de teste 480 (Spacewar) serve, e o jogo continua com ENet como caminho padrão.

## 3. GodotSteam neste repositório (conferido em 21/09/2026)

| Item | Valor | Fonte |
|---|---|---|
| Godot do repo | 4.7.2 portable (`.tools/`) | — |
| GodotSteam para o 4.7.2 | **4.22** (e GodotSteam Server **4.11**), publicados em 22/08/2026 | [godotsteam.com, "Godot 4.7.2 and GodotSteam 4.22 / 4.11"](https://godotsteam.com/blog/2026/08/22/godot-472-and-godotsteam-422--411/) |
| Módulo × GDExtension | unificados; os ramos separados de GDExtension foram aposentados | idem |
| `SteamMultiplayerPeer` | **dentro** da GDExtension principal desde a **4.17** (dez/2025) | [godotsteam.com, categoria MultiplayerPeer](https://godotsteam.com/blog/category/multiplayerpeer/) |
| Conflito | **não** usar junto com a GDExtension "SMP" da ExpressoBits: as duas registram a mesma classe | idem |
| Callbacks | `Steam.run_callbacks()` todo quadro | documentação do GodotSteam |

O que **não** foi conferido, e é a primeira tarefa da Fase 9:

- se o `SteamMultiplayerPeer` da 4.22 se comporta com o `SceneMultiplayer.auth_callback` (a autenticação da Fase 1 roda **antes** do peer existir, `20` §2);
- se o GodotSteam Server 4.11 traz um `MultiplayerPeer` (a Fase 9 não precisa: o dedicado fica em ENet);
- a versão do SDK Steamworks por trás da 4.22.

**Não trocar o binário de `.tools/`** por um Godot com módulo: o projeto inteiro (skills, `dev.sh`, captura, testes) assume o portable. A GDExtension carrega em cima dele. A `steam_api64.dll` precisa ir no export.

## 4. Como o Steam entra sem mexer na rede

A Fase 1 foi escrita para isso. A `Sessao` cria o peer num ponto só:

```gdscript
# hoje (sessao.gd, _subir_servidor / entrar)
var peer := ENetMultiplayerPeer.new()
peer.create_server(porta, max + 4, 2)        # ou create_client(host, porta, 2)
```

A Fase 9 põe uma escolha antes disso, e **nada depois muda**: autenticação, instantâneo, eventos, bonecos, validação, relógio, tudo fala com `multiplayer`, não com o ENet.

```gdscript
var peer: MultiplayerPeer
match transporte:
	Transporte.ENET:  peer = _peer_enet(...)
	Transporte.STEAM: peer = _peer_steam(...)   # SteamMultiplayerPeer.create_host / create_client(steam_id)
```

Três detalhes que a Fase 9 precisa medir, porque mudam números da Fase 1:

| Detalhe | Por quê |
|---|---|
| Canais | a Fase 1 usa 2 canais (3 a partir da Fase 3, `04` §1). Conferir se o `SteamMultiplayerPeer` respeita `transfer_channel` e o modo não confiável ordenado |
| Compressão | o range coder é do ENet. No Steam, o tamanho no fio muda: medir KB/s de novo |
| Ping | `ENetPacketPeer.PEER_ROUND_TRIP_TIME` não existe no Steam; o ping da lista precisa vir de outro lugar (`getConnectionRealTimeStatus` ou um eco próprio) |

## 5. O fluxo com Steam

### 5.1 Anfitrião

```
Folha de viagem (10 §3.2) → ABRIR MEU MUNDO → [x] amigos da Steam
  → Steam.createLobby(LOBBY_TYPE_FRIENDS_ONLY, vagas)
  → o lobby guarda metadados: nome do mundo, versão, assinatura da cidade, n/max, senha(bool)
  → SteamMultiplayerPeer.create_host(0)
```

O lobby Steam é **só o cartão de visita**: quem está, qual versão. A sessão, com autenticação, lista e chat, é a mesma da Fase 1. Não duplicar a lista de jogadores nos metadados.

### 5.2 Convite

As três portas, que precisam existir juntas para "convidar amigos" ser verdade:

1. **Na folha:** o botão CONVIDAR abre `Steam.activateGameOverlayInviteDialog(lobby_id)`.
2. **No overlay:** Shift+Tab, "Convidar para o jogo".
3. **Com o jogo fechado:** o amigo aceita, e a Steam abre o jogo com `+connect_lobby <id>`. A `Sessao` lê isso em `OS.get_cmdline_args()` **antes** de o boot CRT terminar, pula o título e vai à folha de viagem. Esperar o título e perder o convite é o defeito clássico.

Com o jogo aberto, `Steam.join_requested` faz o mesmo.

### 5.3 O boot com convite

O boot CRT é identidade do jogo, mas um convite não pode esperar 20 s de tubo. Com `+connect_lobby`: placa do CRT por 2 s, depois a folha. Sem carteira, a carteira primeiro (`11` §4).

## 6. Presença e lista de servidores

**Rich presence** (Fase 9): "Na Estrada Velha", "Praça da Matriz", "Na casa verde", "Dirigindo". A lista vem do espaço e do lugar (`Sessao.espaco_do_corpo`, nome de rua). Barato, e é o que faz o "Entrar no jogo" do perfil do amigo funcionar.

**Lista pública de dedicados:** o anúncio da Fase 1 é por broadcast, e só acha servidor na rede local ou na VPN. Um dedicado na internet se acha por RECENTES, FAVORITOS e endereço (`10` §3.3). Uma lista pública precisa de um servidor mestre, que é outro serviço para manter. Só quando houver dedicados públicos para listar; e aí a opção barata é a API de *game servers* da Steam (os dedicados se registram, o jogo lista pelo SDK), e não um mestre próprio.

## 7. O que fica fora

- Voz: overlay da Steam ou Discord.
- Filtro de texto da Steam (`initFilterText`): útil quando houver servidor público; o chat de amigos já é saneado (`sanear_texto`).
- Steam Input e ícones de botão: o jogo já tem controle (`controle.gd`); não bloquear nada nisso.
- Steam Deck: checklist de loja, não desta fase. O overlay e o convite precisam funcionar lá; conferir no dia.

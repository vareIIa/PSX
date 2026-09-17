# 02 — Decisões de produto

> Congeladas para o plano. Mudar uma delas é emendar este arquivo **antes** de mudar código.
> Numeração estável: P1–P16. As fases citam estes IDs.

## Como ler

Cada decisão tem: o que foi escolhido, por quê, o que fica de fora, o que uma mudança custaria.

## P1 — Quantos jogadores

**2. Só 2.**

Por quê: o pedido é intro com dois no carro, lobby de convite, banco de passageiro. Três pessoas não cabem num Marea de 1998 e não cabem na cena da praça sem virar outro jogo.

Fora: party de 4, drop-in de estranho, MMO de bairro.

Mudar para 3+ custa: cabine, cinema, leash, HUD, spawn, e toda a UI de lobby.

## P2 — Topologia

**Listen server.** O anfitrião é o servidor (peer 1) e um jogador. O convidado é client.

Por quê em 2026: co-op de amigos, sessão curta, sem cidade 24/7. Dedicated Linux é outro produto (frota, headless, custo, autoridade sem jogador). GodotSteam Server **não** traz `MultiplayerPeer` — o peer de Steam assume que o host joga.

Fora: dedicated na v1, mesh P2P puro (cada um authority do próprio mundo), lockstep determinístico.

Host cai → sessão acaba (P11). Sem host migration na v1.

## P3 — Loja e identidade

**Steam primeiro.**

Identidade = SteamID. Convite = overlay / Join Game / `+connect_lobby`. NAT = Steam Datagram Relay.

Por quê: é o único stack em que “convidar amigo e jogar de outra casa” funciona sem o anfitrião abrir porta UDP. GodotSteam **4.22** existe para Godot **4.7.2** (o binário deste repo), GDExtension, Steamworks SDK 1.65.

Fora na v1: login e-mail/senha, Nakama, EOS, PlayFab, Photon, GD-Sync como eixo.

Fase 1 desenvolve em **ENet `127.0.0.1`** sem Steam. A API alta (`@rpc`, Spawner) não muda quando o peer vira `SteamMultiplayerPeer`.

Código de sala + relay próprio (Noray, NodeTunnel, hospedagem própria) é **plano B** para itch / quem não tem Steam, depois que a Fase 7 estiver de pé.

## P4 — Os dois precisam da cópia

**Sim**, na Steam.

Friend’s Pass é recurso de plataforma Nintendo. Steam: os dois possuem o jogo, ou demo com convite limitado (decisão de loja, não de netcode). Não construir “convidado de graça” no Godot na v1.

## P5 — Distância entre os dois (leash)

**Política de sessão, não lei de renderer.**

O ART-BIBLE limita draw calls e névoa no **preset PSX**. O caminho Vulkan aguenta mais malha e mais horizonte. Mesmo assim, `ChunkManager` hoje segue **um** alvo: dois jogadores em distritos opostos carregam dois raios de chunk, dobram CPU de build e memória, e a missão compartilhada (P7) perde o sentido se um está na estufa e o outro na blitz.

Escolha da v1:

| Modo | Comportamento |
|---|---|
| **Padrão** | Soft leash ~80 m. Fora disso, o minimapa marca o parceiro e um recado na faixa: “espera o fulano”. Sem teleporte forçado |
| **Carro** | Os dois no mesmo veículo = leash irrelevante |
| **Interior** | Os dois entram juntos, ou o de fora vê a porta “ocupada” e espera. Sem um na sala e outro na rua na v1 |
| **Opção futura** | “Explorar separado” liga dual-target no `ChunkManager` (Fase 3b). Só depois do 2P básico existir |

Não amarrar o leash aos 18 m da névoa densa. Isso era o contrato PSX como oclusão. Com Vulkan e PSX opcional, 18 m é look, não sessão.

## P6 — Quem dirige

Na intro: anfitrião no volante, convidado no banco do passageiro (eixo +X da cabine).

No gameplay: quem entra no banco do motorista dirige. Um volante. O outro é passageiro ou desce. Troca de assento é ação explícita (tecla), não “os dois aceleram”.

## P7 — Missão

**Uma missão compartilhada.** `missoes.gd` já é “uma de cada vez, de propósito”. O host avança etapa. Os dois HUDs leem o mesmo `atual`.

Não: diário separado, missões paralelas, um completar sem o outro.

## P8 — Inventário e vida

**Pessoal.** Cada peer tem os 8 slots e a vida. Item no **chão** é do mundo (host): o primeiro que pega, pega. Plantio, porta, TV, caixa de mercado: mundo.

Não: mochila compartilhada na v1. Não: loot duplicado (clássico dos dois pegarem no mesmo frame — o host serializa).

## P9 — Save

**O host grava a sessão.** Formato continua JSON (`SaveGame` v2+). Campos novos: lista de peers (SteamID + ficha), seed, quem estava em qual assento.

CONTINUAR no título do convidado **não** abre o save do amigo. Convidado que cai volta ao lobby/título. Anfitrião que CONTINUA entra single no mundo salvo (o parceiro vira ausência — ver P11).

Não: cloud save cruzado, “os dois têm o mesmo arquivo”.

## P10 — Introdução

**Cinema travado no host.** Os dois assistem os mesmos cortes, as mesmas legendas, o mesmo fade. Os dois corpos visíveis **desde o plano 1** da Estrada Velha (silhueta no para-brisa). Controle só depois da Praça.

Não: cada um com a câmera livre na intro. Não: pular a intro só de um lado.

Roteiro no plural. Ver `12_INTRO_DOIS.md`.

## P11 — Host cai / convidado cai

| Evento | Efeito |
|---|---|
| Convidado sai | Sessão vira single. NPC-parceiro **não** aparece. Recado: “fulano saiu.” Host continua |
| Host sai | Sessão acaba. Convidado volta ao título. Sem migração |
| Timeout / NAT drop | Igual a “saiu”, depois de ~8 s sem pacote |

Reconectar no meio da rua: **não** na v1. Volta ao lobby e recomeça, ou o host continua sozinho.

## P12 — Canon

Emendar `docs/PROMPT-MESTRE.md` §5:

- Riscar “Não tem multiplayer”
- Acrescentar: co-op opcional de 2 jogadores, listen server, Steam, missão compartilhada. Single-player permanece o caminho padrão do título

O resto do mestre (horror, recurso, som) não muda. Veículos/missões já contradizem o mestre no código; a emenda só deixa o papel alinhado.

## P13 — Renderer e netcode

**Agnósticos.**

PSX é opção de vídeo (como névoa já é). Vulkan + melhorias gráficas é a outra frente. A sessão multiplayer:

- não replica preset de renderer
- não replica grão, scanline, vinheta, resolução interna
- não exige que os dois estejam no mesmo preset (um pode jogar PSX, o outro Vulkan)
- **exige** o mesmo seed de mundo e o mesmo estado de sessão

Cuidado: se o horizonte de streaming passar a depender do preset visual, dois presets diferentes carregam raios diferentes e um vê o outro “nascer” na névoa. A Fase 3 fixa: **raio de carga da sessão é o do host** (ou um raio único de co-op). Look local, mundo comum.

## P14 — Voz

**Steam Overlay / Discord na v1.** Não construir VoIP no Godot.

Chat de texto: uma linha no lobby e, se der tempo, a mesma caixa de `conversa.gd` no jogo (RPC de string curta, filtrada — GodotSteam tem tutorial de filter text).

## P15 — Anticheat e fairness

**Host authority + amigos.** Sem kernel anticheat, sem VAC obrigatório na v1.

O host ainda valida: pegar item, dano, avançar missão, entrar em interior. Não porque o amigo é inimigo — porque desync é pior que trapaça neste gênero. Cliente não manda “minha posição é esta” como verdade; manda input.

## P16 — Single-player não regrede

CONTINUAR, NOVO JOGO, criação, intro de um, save local, captura `--ver-abertura` continuam iguais. Multiplayer é um caminho a mais no título, não uma reescrita do boot.

Se um sistema ficar pior no single para servir o 2P, a mudança está errada.

---

## Resumo de uma linha

Dois amigos, Steam, host joga, um volante, uma missão, duas mochilas, cinema junto, look local, mundo comum, host cai acaba, single intacto.

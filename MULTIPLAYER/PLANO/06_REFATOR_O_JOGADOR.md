# 06 — Refator: “o jogador”

> Fase 2. Sem isto, qualquer Spawner é um segundo corpo que o jogo ignora.
> Single-player tem de continuar passando em todos os testes atuais.

## 1. O problema em uma frase

O jogo não tem um conceito de “jogadores”. Tem **o** jogador, descoberto por `get_first_node_in_group(&"player")`.

## 2. Inventário dos 32 call sites

Grupo registrado em `game/src/player/player.gd` (`add_to_group(&"player")`).

| Arquivo | Uso hoje | Vira |
|---|---|---|
| `save_game.gd` | pos, giro, bateria, desembarcar | host: corpo do host. Save de sessão não grava o convidado como “o” player do arquivo single |
| `interiores.gd` (4×) | teleporta quem entra | **todos** os players da sessão, ou recusa se o parceiro não está no raio (P5 interior) |
| `desmaio.gd` | câmera / apagão | só o local (vida é pessoal) |
| `capture_tool.gd` | shot | local / flag. Fora do produto |
| `terminal.gd` | posição | local |
| `transito.gd` | `alvo` da coroa | `Sessao.alvo_de_streaming()` (ver `07`) |
| `minimapa.gd` | centro | local; ícone extra do parceiro |
| `menu.gd` | fundo / câmera do título | local |
| `hud_missao.gd` | distância | local → alvo da missão (missão é compartilhada) |
| `pedestre.gd` | para quem olha / fala | o player **mais perto** daquele NPC, ou quem abriu a conversa |
| `gps.gd` (3×) | origem da rota | local |
| `npc.gd` | idem pedestre | idem |
| `multidao.gd` | `alvo` | streaming (07) |
| `documento.gd` | “meu” documento | ficha do local (`RegistroCivil` por peer) |
| `dialogo.gd` | trava | quem falou |
| `conversa.gd` | trava | quem falou |
| `cinematica.gd` | esconde / trava | **todos** (intro é cinema travado) |
| `celular.gd` (2×) | logado como | ficha do local |
| `convidado.gd` | atenção | mais perto |
| `chunk_manager.gd` | `alvo` | streaming (07) |
| `blitz_manager.gd` | `alvo` | host spawna relativo a um ponto de sessão (média, ou host) |
| `inimigo.gd` | perseguir | mais perto, ou quem agrediu |

Regra de reescrita, em ordem de preferência:

1. `Sessao.jogador_local()` quando o assunto é **este processo** (câmera, HUD, input, documento, celular).
2. `Sessao.jogadores()` quando o assunto é **todo mundo na viagem** (cinema, interior, “existe gente aqui”).
3. `mais_perto(origem: Vector3)` quando o assunto é um NPC / perigo no mundo.
4. `Sessao.alvo_de_streaming()` só para chunk / multidão / trânsito.

Proibido: `get_first_node_in_group(&"player")` em código novo. Os 32 viram uma destas quatro.

O grupo `"player"` **permanece** — serve para achar todos (`get_nodes_in_group`). O que morre é a ilusão de que o primeiro é *o* ser humano.

## 3. API em `Sessao`

```
func jogador_local() -> Player
func parceiro() -> Player          # null em solo ou se caiu
func jogadores() -> Array[Player]
func mais_perto(origem: Vector3) -> Player
func alvo_de_streaming() -> Node3D
func ficha_de(peer_id: int) -> Dictionary
```

Em `modo == SOLO`, `jogador_local()` é o único, `parceiro()` é `null`, `jogadores()` tem um elemento. Todo call site que usar esta API funciona nos dois modos.

## 4. `Player` o que muda no próprio script

Arquivo: `game/src/player/player.gd`.

Hoje o script:

- lê input direto (`Input.get_vector`, ações globais)
- liga a `Camera3D` como se fosse a única
- `RegistroCivil.jogador` para montar o `Corpo`
- `Inventario` autoload único
- `_entrar_no_carro` assume o volante e faz `visible = false`

Precisa:

| Ponto | Solo (hoje) | Coop |
|---|---|---|
| Input | sempre | só se `is_multiplayer_authority()` |
| `Camera3D.current` | true | true só no local |
| `_physics_process` movimento | sempre | authority; remoto interpola |
| Corpo visível | some ao dirigir | **local** some na 1P ao dirigir; **remoto** continua visível no banco |
| Ficha | `RegistroCivil.jogador` | `Sessao.ficha_de(authority)` |
| Inventário | autoload | `Inventario.do_peer(id)` ou instância no próprio Player |
| Sinal `alvo_de_interacao` | HUD global | HUD do local só escuta o local |

`MultiplayerSynchronizer` na cena:

- `position`, `rotation.y`
- `bool` agachado, lanterna, no_carro
- `StringName` pose (`andar`, `parado`, `agachar`, `volante`, `passageiro`)

Não sincronizar: `_pitch`, fôlego float, bob, `_tranco`, FOV.

## 5. `RegistroCivil.jogador`

Hoje um Dictionary. Precisa:

```
var fichas: Dictionary   # peer_id -> ficha
var jogador: Dictionary  # alias: ficha do local, para não quebrar 40 leitores de uma vez
```

Durante a Fase 2, `jogador` continua sendo o local. Código novo pergunta `ficha_de`. Código antigo de UI (prancha, celular) que lê `RegistroCivil.jogador` segue certo no processo de cada um — cada cliente tem o *seu* local.

O parceiro: `Sessao.ficha_de(parceiro.peer)`. O `Corpo` remoto monta com isso no spawn.

`criar_jogador(nome)` no menu single não muda. No coop, cada peer cria a sua ficha e manda no roster (Fase 6).

## 6. Inventário por peer

Caminhos possíveis:

**A.** Autoload deixa de ser “a bolsa” e vira **catálogo + fábrica**. Cada `Player` tem um `InventarioEstado` (8 slots, vida). HUD lê `Sessao.jogador_local().inventario`.

**B.** Autoload vira dicionário `peer_id -> estado`. API `Inventario.vida` passa a significar “vida do local”.

A é mais limpa. B é menos toque. Recomendação: **A**, porque vida/dano já emite sinais que a prancha escuta — pendurar no Player evita o sinal do parceiro acender a sua faixa.

Pickup: `pedido_pegar_item` (04). Host tira do mundo, credita no estado daquele peer, RPC de volta.

## 7. Câmera

`camera_rig.gd`: “o truque é não ter duas câmeras.”

Isso continua **por processo**. Dois processos = duas câmeras, cada uma `current` no seu player. Não é split-screen. Não é SubViewport por jogador.

O parceiro em terceira pessoa: o `Corpo` dele desenha. Em primeira pessoa, o local não vê o próprio corpo (hoje o corpo em 1P já é tratado). O parceiro sempre vê o corpo do local, inclusive ao volante (Fase 4).

Cinema (`cinematica.gd`): hoje pega “o” player para travar e às vezes para posicionar. Vira `Sessao.jogadores()`: trava os dois, esconde HUD dos dois. A `Camera3D` de cinema é uma câmera extra, `current` nos dois processos no mesmo tick (host manda `plano_de_cinema`).

## 8. Input e `travado`

`travado` hoje é um bool no Player. Continua por Player.

- Conversa: trava **quem falou**. O parceiro anda.
- Cinema: trava **os dois**.
- Menu/prancha: trava o local (pause é local — ver 08: pausa não pausa o parceiro).

`PROCESS_MODE_ALWAYS` no menu hoje pausa a árvore. Em coop, **não** pausar a SceneTree. Pausa vira “local travado + overlay”. Senão o anfitrião abrir a prancha congela o convidado no meio da rua.

## 9. Ordem da refator (dentro da Fase 2)

1. Nascer `Sessao` em modo SOLO, `jogador_local()` = o de sempre.
2. Trocar os 32 sites, um arquivo por vez, teste headless a cada um.
3. Só então ligar o Spawner (fim da Fase 1 já tem dois processos; a Fase 2 deixa os sistemas **enxergarem** o segundo).
4. Inventário A no mesmo PR da vida, porque `desmaio` e prancha quebram se a vida do parceiro emitir no autoload velho.

Não misturar Fase 2 com lobby, Steam ou intro. O aceite é: dois bonecos andam na praça, o GPS de cada um funciona, abrir conversa num não trava o outro, o single `--pular-abertura` continua idêntico.

# 01 — Estado atual da plataforma

> Snapshot contra o código em `playable`, Godot 4.7.2, setembro 2026.
> Se o repo divergir, atualize este arquivo — as fases dependem dele.

## 1. Motor e export

| Item | Valor no disco |
|---|---|
| Engine | Godot **4.7.2** portable em `.tools/` |
| Renderer hoje | `gl_compatibility` em `game/project.godot` |
| Frente paralela | Vulkan + melhorias gráficas (outra sessão). PSX vira **opção ingame** |
| Linguagem | GDScript, tipagem estática, `class_name` |
| Cena principal | `res://scenes/test/cidade.tscn` |
| Resolução interna hoje | 480×270, stretch `viewport` |
| FPS alvo (ART-BIBLE) | 30, 60 opcional |
| Export | um preset, Windows x86_64, `export/NevoaEDither.exe` |
| Dedicated server | `dedicated_server=false`. Não existe preset Linux headless |
| Store / App ID | nenhum |
| Rede | **zero**. Nenhuma ocorrência de `MultiplayerPeer`, `@rpc`, `ENet`, Steam, Nakama, Photon |

Consequência para o plano: o netcode **não** se amarra ao Compatibility. Spawner, Synchronizer e RPC são da SceneTree, não do renderer. Quando Vulkan entrar, a sessão multiplayer continua a mesma. O que muda é câmera, pós e orçamento de malha — tratados em `07_MUNDO_E_STREAMING.md`.

## 2. Canon que ainda está no papel

`docs/PROMPT-MESTRE.md` §5, linha explícita:

> Não tem multiplayer, progressão por níveis, craft ou loot aleatório.

Isso é o único parágrafo do canon que a Fase 0 emenda. O resto (horror, exploração, recurso escasso, som) continua. Veículos, missões e mapa **já existem no código** apesar do mesmo documento dizer que não — o mestre está atrasado em relação ao jogo. A emenda do multiplayer é do mesmo tipo: o jogo que queremos, não o parágrafo de 06/09.

## 3. Fluxo de uma partida nova (single)

```
Boot CRT
  → TV da Casa da Fumaça (fundo vivo)
    → título SHIMOKAWA  (CONTINUAR | NOVO JOGO | MAPA | OPÇÕES | SAIR)
      → ficha de cadastro (nome)
        → carteira / criação de aparência
          → Estrada Velha (CarroCena, Marea, 1 ocupante implícito)
            → blackout
              → Abertura na Praça da Matriz (um corpo deitado)
                → GPS, primeira missão, controle devolvido
```

Arquivos:

- `game/src/ui/menu.gd` — painéis BOOT, TITULO, OPCOES, MAPA, NOME, APARENCIA
- `game/src/levels/cidade.gd` — `_ao_comecar_pelo_menu` → `_novo_jogo` → `_rodar_abertura`
- `game/src/levels/abertura_estrada.gd` — 5 planos de cinema
- `game/src/levels/abertura.gd` — praça, avenida, blitz, mercado, casa, poste
- `game/src/ui/cinematica.gd` — tarja, legenda, mover câmera
- `game/src/ui/criacao.gd` — carteira 3D
- `game/src/ui/ficha_cadastro.gd` — nome

Não existe entrada JOGAR COM AMIGO, CRIAR PARTIDA, CONVIDAR, LOBBY, LOGIN.

## 4. Autoloads (todos single-player)

Definidos em `game/project.godot` `[autoload]`:

| Autoload | Papel hoje | Problema em 2P |
|---|---|---|
| `Settings` | `user://settings.cfg` | Local. Não replicar. Incluirá o toggle PSX/Vulkan |
| `Inventario` | 8 slots, 1 vida | Um só. Precisa instância por peer |
| `AudioDirector` | buses, ambiente | Local, com eventos do parceiro derivados |
| `WorldState` | mutações de chunk + relógio | Verdade do host |
| `ChunkManager` | carga por **um** `alvo` | Dois corpos = política de streaming |
| `Interiores` | um `dentro`, uma pilha, +Y 2000 | Um jogador entra; o outro some da rua |
| `Dialogo` | trava *o* player | Um falante |
| `RegistroCivil` | um `jogador` | Duas fichas na sessão |
| `Conversa` | um `ativo` | Um NPC por vez |
| `Documento` / `Celular` / `Gps` / `Terminal` | UI de um corpo | Tela local; dados compartilhados só quando forem de mundo |
| `Cinema` | uma câmera de cinema | Host manda o tick da intro |
| `Missoes` | uma missão | Compartilhada, host avança |
| `Multidao` | 14 pessoas na coroa de um alvo | Flavor local na v1 |
| `Transito` | 6 carros + `_do_jogador` | Um carro “do jogador” |
| `BlitzManager` | uma blitz perto do alvo | Host spawna |
| `RadioCarro` | uma estação | Do carro, não da pessoa |
| `SaveGame` | 3 slots JSON, um corpo | Host grava a sessão |
| `CaptureTool` | captura de desenvolvimento | Fora do produto |

## 5. O pressuposto “existe um Player”

`Player` se registra em `add_to_group(&"player")` (`player.gd`). Em seguida **32 call sites** fazem `get_tree().get_first_node_in_group(&"player")`. Lista completa em `16_AUTOLOADS_E_ARQUIVOS.md`.

Isso não é um detalhe. É a forma como save, GPS, chunk, trânsito, conversa, interiores, cinema e HUD descobrem quem é o ser humano. Com dois nós no grupo, cada um desses sistemas pega o primeiro da árvore — o anfitrião, ou o que nasceu antes — e o convidado vira fantasma.

Há uma única `Camera3D` no `CameraRig`. A tese do arquivo é “não ter duas câmeras”. Em online isso continua verdade **por cliente** (cada processo tem a sua `current`). Não é split-screen.

## 6. Mundo

- Grade de 32 m, `ChunkBuilder` com seed `hash(coord)` — **determinístico**. Os dois clientes geram a mesma rua sem mandar malha.
- `WorldState` guarda o que o jogador mudou (porta, item) porque chunk descarregado perde nós.
- Interiores vivem em `Y=2000`. Estrada Velha em `Y=4000`. Separação por espaço, não por troca de scene tree.
- Multidão e trânsito usam `RandomNumberGenerator.randomize()` no boot: **não** são determinísticos. “Quem” na esquina tende a repetir; “quando” não.
- Teto de draw call 120 e névoa como oclusão estão no ART-BIBLE. Valem no **preset PSX**. No caminho Vulkan o orçamento é outro. O `ChunkManager` mesmo assim segue um alvo só — isso é código, não look.

## 7. Personagem e veículo

- Criação: nome na ficha + aparência na carteira. Resto da identidade sai de `RegistroCivil` (CPF, filiação, endereço).
- `Aparencia` é função pura do dicionário / id. Replica-se o dict, não a malha.
- `Corpo` tem `_pose_sentado` — pernas cruzadas no chão da casa da fumaça. **Não** é pose de banco de carro.
- `Carro.assumir(self)`: um piloto. Corpo do player some (`visible = false`). Não há banco de passageiro.
- `CarroCena` (intro): Marea em trilho, cabine só no plano DENTRO, **zero ocupantes visíveis**.
- Falas da estrada no singular (“Eu que não queria vir”, “Aí eu peguei o carro e vim”), com germes de dupla (“A gente marcou essa viagem”).

## 8. Input

Mapas em `project.godot`: `mover_*`, `correr`, `agachar`, `alternar_camera`, `interagir`, `lanterna`, inventário, pausa. Um teclado. Sem `device` por jogador — irrelevante em online (cada processo tem o seu). Relevante só se um dia existir split-screen local, que **não** é este plano.

## 9. O que já ajuda o multiplayer (sem ser rede)

Coisas que o single-player já fez e que o 2P reusa:

| Já existe | Por que ajuda |
|---|---|
| Cidade por seed de coordenada | Malha não vai na rede |
| `RegistroCivil` invertível | CPF/ficha do NPC não replica |
| `Aparencia` pura | Replica um Dictionary pequeno |
| `WorldState.para_dicionario()` | Formato pronto para snapshot |
| `SaveGame` JSON | Mesma forma pode ir num RPC de “estado da sessão” |
| Carteira 3D (`CriacaoAparencia`) | Retrato do lobby |
| Celular / agenda | Lista de amigos diegética |
| `Cinema` + tarjas | Intro sincronizada é tick + legendas, não um vídeo |
| Túnel central na cabine | Lado motorista / lado passageiro já se lê |
| `Settings` com sinal | Toggle PSX/Vulkan e opções de vídeo ficam fora da sessão |

## 10. O que não existe de jeito nenhum

- Peer, porta, IP, lobby, convite, room code
- `MultiplayerSpawner` / `MultiplayerSynchronizer` em qualquer `.tscn`
- Identidade de plataforma (SteamID, EOS, e-mail)
- Segundo corpo, segundo inventário, segundo assento
- Política para host cair, reconectar, atrasar, trapacear
- Teste com dois processos
- Preset de export “servidor”
- Rich presence, voz, anticheat

O jogo está maduro como single-player e virgem como multiplayer. O plano trata isso como segundo produto colado no primeiro, não como um plugin.

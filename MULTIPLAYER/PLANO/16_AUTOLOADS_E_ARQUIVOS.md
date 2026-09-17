# 16 — Autoloads, arquivos e toques

> Inventário de consulta. Não é narrativa. Atualizar quando o grep mudar.

## 1. Autoloads hoje → destino

| Autoload | Script | Solo | Coop v1 |
|---|---|---|---|
| `Settings` | `systems/settings.gd` | local | local (PSX/Vulkan aqui) |
| `Inventario` | `systems/inventario.gd` | a bolsa | catálogo + açúcar do local; estado no Player |
| `AudioDirector` | `systems/audio_director.gd` | local | local + passo 3D do parceiro |
| `WorldState` | `world/world_state.gd` | verdade | verdade do **host**, cliente replica dict |
| `ChunkManager` | `world/chunk_manager.gd` | 1 alvo | `Sessao.alvo_de_streaming()` |
| `Interiores` | `systems/interiores.gd` | 1 corpo | sessão, os dois juntos |
| `Dialogo` | `ui/dialogo.gd` | 1 falante | 1 falante (host) |
| `RegistroCivil` | `systems/registro_civil.gd` | 1 `jogador` | `jogador`=local + `ficha_de` |
| `Conversa` | `ui/conversa.gd` | 1 ativo | 1 falante |
| `Documento` | `ui/documento.gd` | local | local |
| `Celular` | `ui/celular.gd` | local | local |
| `Gps` | `ui/gps.gd` | local | pin de missão compartilhado |
| `Terminal` | `ui/terminal.gd` | local | compra no host |
| `Cinema` | `ui/cinematica.gd` | 1 cam | tick do host, current nos dois |
| `Missoes` | `systems/missoes.gd` | 1 | host avança, os dois leem |
| `Multidao` | `world/multidao.gd` | 1 alvo | streaming; flavor local |
| `Transito` | `world/transito.gd` | `_do_jogador` | carro da sessão |
| `BlitzManager` | `world/blitz_manager.gd` | 1 alvo | host |
| `RadioCarro` | `ui/radio_carro.gd` | 1 | do carro, host |
| `SaveGame` | `systems/save_game.gd` | 3 slots | host grava v3 |
| `CaptureTool` | `systems/capture_tool.gd` | dev | dev |
| **`Sessao`** | `net/sessao.gd` | **criar** | SOLO/COOP, roster, peer |

## 2. `get_first_node_in_group(&"player")`

32 ocorrências no snapshot deste plano. Arquivos:

```
save_game.gd
interiores.gd          (4)
desmaio.gd             (2)
capture_tool.gd        (2)
terminal.gd
transito.gd
minimapa.gd
menu.gd
hud_missao.gd
pedestre.gd
gps.gd                 (3)
npc.gd
multidao.gd
documento.gd
dialogo.gd
conversa.gd
cinematica.gd
celular.gd             (2)
convidado.gd
chunk_manager.gd
blitz_manager.gd
inimigo.gd
player.gd              (o add_to_group)
```

Depois da Fase 2: só `Sessao` (e o `add_to_group`). Grep no aceite.

## 3. Arquivos-chave por fase

### Fase 1

```
game/src/net/sessao.gd                      novo
game/src/net/transporte.gd                  novo
game/src/net/transporte_enet.gd             novo
game/project.godot                          autoload
game/src/levels/cidade.gd                   flags, nó Jogadores
game/src/player/player.gd                   authority, camera
game/scenes/player/player.tscn              Synchronizer
game/scenes/test/cidade.tscn                Spawner
tools/mp_dois.ps1                           novo
```

### Fase 2

Todos os 32 sites + `registro_civil.gd` + `inventario.gd` + `prancha_inventario.gd` + `menu_sistema.gd` (pausa).

### Fase 3

```
chunk_manager.gd  world_state.gd  interiores.gd
missoes.gd        item_no_chao.gd porta.gd
minimapa.gd       hud_missao.gd   relogio.gd
blitz_manager.gd  plantio.gd      plantacao.gd
```

### Fase 4

```
carro.gd  carro_cabine.gd  corpo.gd  player.gd
camera_rig.gd  transito.gd  painel_carro.gd
```

### Fase 5

```
abertura_estrada.gd  abertura.gd  carro_cena.gd
cinematica.gd        cidade.gd    corpo.gd
```

### Fase 6

```
menu.gd  criacao.gd  ficha_cadastro.gd
game/src/ui/lobby.gd                     novo
```

### Fase 7

```
game/src/net/transporte_steam.gd         novo
addons/godotsteam/…                      GDExtension
export_presets.cfg
```

## 4. Cenas

| Cena | Papel 2P |
|---|---|
| `scenes/test/cidade.tscn` | jogo inteiro; Spawner mora aqui |
| `scenes/player/player.tscn` | 1 por peer |
| `scenes/player/cabine_fundo_criacao.tscn` | carteira (já) |
| Não existe lobby.tscn | lobby é Control no Menu, como o resto da UI |

## 5. Constantes a nascer

```
# sessao / transporte
PORTA_DEV := 24567
MAX_PEERS := 2
RAIO_CARGA_COOP := 3          # anéis
LEASH_M := 80.0
TIMEOUT_DROP := 8.0
HZ_TRANSFORM := 15

# assento
LADO_MOTORISTA  negativo X
LADO_PASSAGEIRO positivo X
```

Citar ART-BIBLE **não** é obrigatório nestes números: não são look. Citar este plano no comentário.

## 6. Skills do repo

| Skill | Uso no 2P |
|---|---|
| `godot-project` | binário, headless, layout `src/` vs `scenes/` |
| `psx-city` | chunk 32 m, um-chunk-por-frame, WorldState |
| `psx-render` | vale no **preset** PSX; netcode não depende |
| `psx-assets` | ícone do parceiro no minimapa, carimbo do lobby |

Skill que **valeria criar na Fase 1** (não agora): `psx-multiplayer` — listen server 2P, Sessao, ENet/Steam plugável, leash, cinema host, lobby-documento. Este plano é o rascunho dela.

## 7. Docs externos (2026)

- Godot High-level multiplayer (4.6/4.7)
- GodotSteam 4.22 + tutoriais Lobbies e MultiplayerPeer (jun–ago 2026)
- Steamworks SDK 1.65
- GodotCon US 2025, Dome Keeper co-op em GDScript existente

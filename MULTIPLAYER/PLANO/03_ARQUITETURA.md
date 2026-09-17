# 03 — Arquitetura

> O desenho do sistema. As fases implementam isto; não outro.

## 1. Camadas

```
┌─────────────────────────────────────────────────────────┐
│  Steam Overlay · convite · Join Game · +connect_lobby   │
│  (Fase 7; na Fase 1 isto não existe)                    │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  IDENTIDADE                                             │
│  SteamID → ficha RegistroCivil local de cada peer       │
│  Aparência Dictionary no metadado do lobby              │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  LOBBY  (folha de viagem, max 2)                        │
│  pronto · retratos · convite · recado                   │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  TRANSPORTE                                             │
│  Dev:  ENetMultiplayerPeer  127.0.0.1:24567             │
│  Ship: SteamMultiplayerPeer + relay, server_relay=true  │
│  A SceneTree.multiplayer não muda. Só o peer.           │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  SESSÃO  (autoload novo: Sessao)                        │
│  host=peer 1 · seed · relógio · roster · fase           │
│  (lobby / criacao / intro / jogo / encerrada)           │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  REPLICAÇÃO                                             │
│  MultiplayerSpawner  → cena Player por peer             │
│  MultiplayerSynchronizer → transform + pose             │
│  @rpc → eventos (porta, item, assento, missão, cinema)  │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  MUNDO                                                  │
│  Cidade gerada igual (seed + coord)                     │
│  WorldState só do que mudou                             │
│  Flavor local: pedestre/trânsito de rua                 │
│  Host: blitz, missão, interior, carro possuído          │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  APRESENTAÇÃO (por processo, local)                     │
│  Camera3D current do player local                       │
│  Preset PSX ou Vulkan (Settings)                        │
│  HUD, celular, GPS, prancha                             │
│  Cinema da intro: mesma câmera nos dois, tick do host   │
└─────────────────────────────────────────────────────────┘
```

## 2. Por que a cidade não vai na rede

`game/src/world/chunk_builder.gd` semeia com:

```
rng.seed = hash(Vector2i(cx, cz)) ^ (cx * 73856093) ^ (cz * 19349663)
```

Mesma coordenada, mesma malha, mesmos props, mesma porta. `RegistroCivil` e `Aparencia` são funções puras do `id`. Mandar ArrayMesh pela rede seria pagar o que o disco já sabe.

O que **não** é determinístico hoje:

- `Multidao` e `Transito` chamam `_rng.randomize()` no `_ready`
- hora de nascimento na coroa
- conversas entre pedestres

v1: deixam de ser verdade compartilhada. Cada um vê gente na névoa. NPC com quem alguém **falou**, carro que alguém **assumiu**, blitz, morador de interior: esses o host spawna e replica.

## 3. Authority

Regra do Godot 4: o servidor é authority de todo nó, salvo `set_multiplayer_authority`.

| Nó | Authority | Por quê |
|---|---|---|
| `Player` local (movimento, câmera, input) | o peer dono | Responsividade. Host ainda valida teleport/abuso |
| `Player` remoto | o peer dono, observado | Synchronizer interpola no outro processo |
| `Carro` dirigido | host | VehicleBody3D / física não é determinística entre máquinas |
| Input de volante | peer no banco do motorista → RPC para o host | Host aplica no RigidBody |
| Porta, item, plantio, missão, relógio | host | Uma verdade |
| `Cinema` / intro | host | Cortes iguais |
| Chunk, malha, névoa visual | local | Seed + Settings |

Física Godot **não** é lockstep. Nunca simular o mesmo `CharacterBody3D` nos dois lados e “esperar que bata”. Host simula; cliente interpola.

## 4. Autoload novo: `Sessao`

Não pendurar rede em `cidade.gd`. `cidade.gd` já é o arquivo mais gordo do jogo (boot CRT, menu, abertura, captura).

`Sessao` (autoload) guarda:

```
enum Fase { MENU, LOBBY, CRIACAO, INTRO, JOGO, ENCERRADA }

peer_id_local: int
sou_host: bool
seed_mundo: int
roster: Dictionary   # peer_id -> {steam_id, nome, ficha, aparencia, pronto, assento}
fase: Fase
modo: enum { SOLO, COOP }
```

API mínima:

- `criar_lobby()` / `entrar_lobby()` / `sair()`
- `marcar_pronto(bool)`
- `comecar_viagem()` — só host, só com 2 prontos
- `jogador_local() -> Player`
- `parceiro() -> Player`
- `jogadores() -> Array[Player]`
- `encerrar(motivo)`

Single-player: `modo = SOLO`, roster de um, o resto do jogo nem pergunta se há rede.

## 5. Transporte

Um wrapper `Transporte` (não autoload obrigatório; pode viver em `Sessao`):

```
func hospedar() -> Error
func conectar(endereco: String, porta: int) -> Error
func desconectar() -> void
```

Implementações:

| Classe | Quando |
|---|---|
| `TransporteEnet` | Dev, LAN, `--mp-host` / `--mp-join=127.0.0.1` |
| `TransporteSteam` | Ship, Fase 7 |

A SceneTree só vê `multiplayer.multiplayer_peer`. RPC e Spawner não sabem qual é.

Porta de dev: **24567** UDP. Constante no topo de `TransporteEnet`. Não 7777 (todo tutorial usa, conflito na máquina).

`server_relay = true` no peer Steam: o convidado só fala com o host; o host reenvia. Com 2 jogadores isso é o desenho inteiro.

## 6. Tick e banda

Horror anda a 2,4–4,6 m/s. Não é shooter.

| Canal | Modo | Hz |
|---|---|---|
| Transform do player (Synchronizer) | unreliable, on-change com teto | 15–20 |
| Pose / animação (andar, agachar, sentar) | unreliable enum | 10 |
| Eventos (porta, item, fala, assento) | reliable RPC | sob demanda |
| Cinema (número do plano + t) | reliable, no corte | sob demanda |
| Relógio (minutos) | reliable, a cada minuto de jogo | ~1/60 s real |

Budget folgado para 2 peers. Não replicar: chuva, partícula, bob de câmera, fôlego (local), Settings, pós.

Godot 4.5+ : Synchronizer **Always** vs **On Change**. Transform em Always (ou intervalo 50–70 ms). Inventário flags em On Change. Always em tudo é imposto de banda escondido.

## 7. Spawn

Cena `res://scenes/player/player.tscn` já existe. O host instancia uma por peer sob um nó `Jogadores`, nome estável `"p_%d" % peer_id`. `MultiplayerSpawner` observa esse nó.

No spawn:

1. Host cria o nó, `set_multiplayer_authority(peer_id)`
2. Aplica a ficha/aparência do roster
3. Posição: intro = bancos do `CarroCena`; gameplay = praça, dois pontos a ~1,5 m
4. Cliente recebe o spawn, liga `Camera3D.current` **só** se `is_multiplayer_authority()`

Single: o caminho atual de `cidade.gd` que já instancia um player permanece. `Sessao.modo == SOLO` não passa pelo Spawner.

## 8. Relação com Vulkan / PSX

```
Settings.renderer  ──►  Viewport, shaders, pós, resolução
Sessao             ──►  peers, seed, RPCs, authority
ChunkManager       ──►  raio de carga da SESSÃO (não do preset visual)
```

Três eixos independentes. Um jogador em PSX 480×270 e outro em Vulkan 1080p jogam a mesma viagem. O que não pode divergir: seed, WorldState, posição dos players, missão, relógio.

Se o caminho Vulkan um dia tiver streaming próprio (mais anéis de chunk), a sessão co-op usa um raio combinado definido em `Sessao`, não o raio do preset de quem está olhando.

## 9. Onde a coisa mora no disco (alvo)

Proposto, não criado. Fase 1 abre estes arquivos.

```
game/src/net/
  sessao.gd              autoload Sessao
  transporte.gd          interface
  transporte_enet.gd
  transporte_steam.gd    Fase 7
  roster_peer.gd         Resource: id, nome, ficha, aparencia, pronto
  replicacao.gd          helpers de RPC (opcional)

game/src/ui/
  lobby.gd               folha de viagem
  menu.gd                + entrada JOGAR COM AMIGO  (existente, editar)

game/scenes/player/
  player.tscn            + MultiplayerSynchronizer  (existente, editar)
```

Não misturar `.gd` em `scenes/`. Convenção do `godot-project` skill.

## 10. Single e coop no mesmo binário

O export continua um `.exe`. Não há build “só multiplayer”. Flags de boot para dev:

```
--mp-host
--mp-join=127.0.0.1
--mp-pular-lobby
--mp-pular-intro
```

Espelham `--pular-menu` / `--pular-abertura` que `cidade.gd` já entende. Captura 2P usa os mesmos `--shot*` depois que dois processos estão de pé.

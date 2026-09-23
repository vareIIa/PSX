# 01 — Estado atual

> **Snapshot de 21/09/2026, 20h**, contra `playable` (HEAD `dcc662e "Push"` + working tree), Godot 4.7.2.
> Se o repo divergir, atualize este arquivo: as fases dependem dele.
> A 1.0 deste arquivo (14/09) dizia `gl_compatibility`, 22 autoloads, 32 pontos "o jogador" e rede zero. Tudo isso mudou.

## 1. Motor e export

| Item | Valor |
|---|---|
| Motor | Godot **4.7.2** portable em `.tools/` |
| Renderer (HEAD) | **`forward_plus`**; `.mobile` em `gl_compatibility`. PS1 STYLE é preset, não teto |
| Cena principal | `res://scenes/test/cidade.tscn` |
| Cena principal do **build de servidor** | `res://scenes/net/servidor_dedicado.tscn` (`run/main_scene.dedicated_server`) |
| Resolução interna | 480×270, stretch `viewport` |
| Presets de export | `Windows Desktop` (jogo) e **`Servidor Dedicado Windows`** (`dedicated_server=true`) |
| Templates instalados | **só Windows** (`%APPDATA%/Godot/export_templates/4.7.2.stable/`). Linux exige baixar (`18` §2.3) |
| Docker nesta máquina | não há |

## 2. Rede

**Existe** (Fase 1 inteira e a Fase 2 em parte, `13`):

```
game/src/net/     12 arquivos
game/scenes/net/  servidor_dedicado.tscn, bot_rede.tscn
game/tests/mp/    run_tests_rede.gd (136 asserções)
tools/            mp_teste.sh, mp_dois.sh (--foto, --dedicado, --carro)
autoload          Sessao
protocolo         VERSAO 2: estado de 23 B, assinatura da cidade
```

Transporte ENet (UDP 24567), descoberta na rede local (UDP 24568), autenticação com senha por desafio **e assinatura da cidade**, estado a 20 Hz com interesse, bonecos com aparência, **lanterna que aponta para onde o outro olha**, **carro do outro de farol e facho aceso**, **pontos no minimapa**, chat, relógio, validação de movimento, **pausa que não congela os outros**, dedicado exportável.

**Não existe:** mundo compartilhado (porta, item, plantio, dinheiro), persistência do dedicado, identidade por token, entrada no título, grupo e missão compartilhada, passageiro, colisão entre jogadores e carros, NPC do servidor, DTLS, Steam.

**Git:** nada da rede foi commitado depois do `dcc662e`. O `dcc662e` (21/09, 17:54) levou uma versão **intermediária** de `game/src/net/`: sem o relógio monotônico, com a trava de 130 ms e com diagnóstico no bot. As correções estão no working tree: `sessao.gd`, `protocolo_rede.gd`, `relogio_de_rede.gd`, `bot_rede.gd` e `tools/mp_teste.sh` modificados; `game/tests/mp/`, `tools/mp_dois.sh` e `captures/multiplayer/` novos; `project.godot` com +1 linha (`run/main_scene.dedicated_server`) e `export_presets.cfg` com +1 preset. `avatar_remoto.gd`, `buffer_interpolacao.gd` e `servidor_dedicado.gd` já estão no HEAD na versão final.

## 3. Canon

`docs/PROMPT-MESTRE.md` §5 ainda diz "Não tem multiplayer". A emenda (P12) é do dono do projeto.

## 4. Fluxo de uma partida

Solo: igual (boot CRT → título → ficha → carteira → Estrada Velha → Praça).

Em rede, hoje: jogar normalmente → **F7** → HOSPEDAR ou ENTRAR. Com flags: `--pular-menu --pular-abertura --mp-hospedar` / `--mp-entrar=IP`. A linha JOGAR ONLINE no título é a Fase 7.

## 5. Autoloads

33, na ordem do `project.godot`:

```
Medidor Settings EstiloVisual DiretorSombra Inventario AudioDirector WorldState
ChunkManager Interiores Clima Dialogo RegistroCivil Conversa Documento Celular
Gps Terminal Cinema Missoes Multidao Transito BlitzManager RadioCarro SaveGame
CaptureTool Sessao Qualidade Lente Ceu ChuvaFora Foto Eco UIManager
```

Destino de cada um em rede: `16` §1.

## 6. "O jogador"

- **43** chamadas `get_first_node_in_group(&"player")` em **31** arquivos do jogo, mais 1 na `Sessao` (lista em `16` §2). Eram 31 em 14/09; a última a entrar foi `mirante.gd`.
- `cidade.gd` fala com o jogador por `$Player` em **193** linhas.
- O `Player` é filho estático de `cidade.tscn`.

Na v2 isso **não bloqueia** ver o outro: os bonecos não estão no grupo. Bloqueia sistema que precise enxergar **mais de um** jogador (NPC que olha para quem está perto, inimigo), e isso é a Fase 2 em diante.

## 7. Mundo

| Fato | Número / lugar |
|---|---|
| Chunk | 32 m, semente pela coordenada (`chunk_builder.gd:41`) |
| Relevo | `Relevo.altura(x, z)`, função pura; praça em y = 0; nascimento da cena em y = 0,5 sobre terreno a −17,57 |
| Interiores | y + 2000, **o mesmo lugar para todos**; `Interiores._semente` privado |
| Estrada Velha | y + 4000 |
| Escritas no `WorldState` | **14** `definir` em **8** arquivos (`08` §1), mais `Dinheiro` e `IWeed` (21/09, outra frente), que guardam estado **da pessoa** no mundo (`08` §1.4) |
| Relógio da cidade | `WorldState.relogio`, andado pela **HUD** (`hud_cidade.gd:133`); `limpar()` troca o objeto |
| Save | `VERSAO = 2`, recusa `!= 2` (`save_game.gd:113`) |
| Multidão e trânsito | aleatórios por processo (`randomize`, `randf` em `carro.gd`): *flavor* local |

## 8. O que já ajudava, e ajudou

| Existia | Serviu para |
|---|---|
| Cidade determinística | nenhuma malha na rede |
| `Aparencia` como `Dictionary` de número e cor | pedido de entrada de 1.140 bytes (aparência de 31 chaves = 912 B, medido), saneável por chave |
| `Corpo` com `montar(aparencia)` e `animar(rapidez)` | o boneco do outro é o mesmo corpo dos NPC |
| `Carroceria.montar(modelo, tinta, semente)` | a réplica do carro do outro, sem física |
| `ItemNoChao.chave()` | identidade de rede do item (Fase 3) |
| `WorldState.para_dicionario()` | estado de mundo na entrada (Fase 3) |
| `Relevo.altura` | chegada no chão sem carregar chunk, inclusive no dedicado |
| `CaptureTool --shot` | fotos das duas janelas |

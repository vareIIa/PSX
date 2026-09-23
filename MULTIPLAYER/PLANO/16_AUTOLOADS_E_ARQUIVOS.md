# 16 — Autoloads, arquivos e toques

> **Versão 2.1 — 21/09/2026, noite.** Inventário de consulta, não narrativa. Atualizar quando o grep mudar.
> Às 20h de 21/09 as outras sessões tinham trabalho não commitado também em `interiores.gd`, `cidade.gd`, `convidado.gd`, `casa_viva.gd`, `conversa.gd`, `celular.gd`, `falas_npc.gd`, `profissoes.gd`, `plantio.gd`, `chunk_manager.gd` e nos apps novos do celular (iWeed, Trampo).
> ✋ = arquivo de sistema do jogo com dono em outra frente (editado por outra sessão em 21/09). Antes de tocar: `git status` no arquivo e combinar com quem o edita. Às 18h de 21/09, o trabalho **não commitado** de outras sessões estava todo na cidade e no relevo (`chunk_builder`, `relevo`, `malha_urbana`, `vias`, `kit_modular`, `tracado`, `mapa`, `bicicleta` e builders novos), o que pesa na Fase 8 (`ChunkManager` só de colisão).

## 1. Autoloads → destino em rede

| Autoload | Solo | Em rede | Fase |
|---|---|---|---|
| `Medidor` | medidor de quadro | local | — |
| `Settings` | `user://settings.cfg` | **local**; nunca na rede | — |
| `EstiloVisual` | material, resolução, iluminação | local; no dedicado carrega 110 materiais à toa (`18` §2.2) | 6 |
| `DiretorSombra` | sombra | local | — |
| `Inventario` | a mochila | estado por jogador **no servidor** (P8) | 3 |
| `AudioDirector` | som | local | — |
| `WorldState` | o que mudou no mundo + relógio | verdade **do servidor**; o relógio já é (`_relogio`) | 3 |
| `ChunkManager` | chão em volta de **um** alvo | cliente: igual (em volta de si); servidor: só colisão, multi-alvo | 8 |
| `Interiores` | interior de um corpo | local por jogador; espaço separa quem vê quem ✋ | 2 |
| `Clima` | chuva e molhado do preset **local** | local (pode divergir entre jogadores; aceito) | — |
| `Dialogo`, `Conversa` | trava o jogador que fala | local; NPC ocupado viaja na Fase 8 | 8 |
| `RegistroCivil` | ficha do jogador | local; a aparência vai na autenticação | — |
| `Documento`, `Celular`, `Gps`, `Terminal` | telas | local; compra no terminal passa pelo servidor | 3 |
| `Cinema` | cena cortada | local; tick do servidor só na intro co-op | 7 |
| `Missoes` | uma missão | uma por **grupo**, no servidor ✋ | 5 |
| `Multidao`, `Transito` | pedestres e carros de rua | *flavor* local | — |
| `BlitzManager` | blitz perto do alvo | servidor | 8 |
| `RadioCarro` | estação | do carro; do motorista | 4 |
| `SaveGame` | 3 slots v2 | solo igual; dedicado persiste à parte (`18` §10) ✋ | 6 |
| `CaptureTool` | `--shot` | local; usado pelo `mp_dois.sh --foto` | — |
| **`Sessao`** | **nada** (`set_process(false)`); `pausar(x)` = `get_tree().paused = x` | **a rede inteira**; `pausar` trava só o jogador local | ✅ 1, 2 |
| `Qualidade`, `Lente`, `Ceu`, `ChuvaFora`, `Foto`, `Eco` | visual e áudio | local | — |
| `UIManager` | UI nova (outra frente) | local | — |

## 2. `get_first_node_in_group(&"player")` — 43 em 31 arquivos do jogo

Na v2 **nenhum precisa mudar para o amigo aparecer**: os bonecos estão fora do grupo, e todos estes continuam achando o jogador **local**, que é o certo para tela, câmera, HUD, save solo e streaming local.

Mudam só os que precisam enxergar **alguém que não seja eu**, marcados com →:

```
systems/interiores.gd (4)        local                                 ✋
world/interior_no_mundo.gd (3)   local
ui/gps.gd (3)                    local
world/entregas_da_super.gd (2)   → NPC que reage a alguém: Sessao.mais_perto   (Fase 8)
ui/celular.gd (2)                local
systems/save_game.gd (2)         local (solo); dedicado persiste à parte ✋
systems/desmaio.gd (2)           local; anunciar teletransporte (2.3)
systems/capture_tool.gd (2)      local
world/transito.gd (1)            local (flavor)
world/super_quarto.gd (1)        local
world/pedestre.gd (1)            → olhar/abordar quem está perto               (Fase 8)
world/npc.gd (1)                 → idem                                         (Fase 8)
world/multidao.gd (1)            local (flavor)
world/inimigo.gd (1)             → perseguir o mais perto, no servidor          (Fase 8)
world/diretor_chuva_fora.gd (1)  local
world/convidado.gd (1)           → quem está na sala                            (Fase 8)
world/chunk_manager.gd (1)       local (cliente); servidor multi-alvo           (Fase 8)
world/casa_viva.gd (1)           local
world/blitz_manager.gd (1)       → servidor, perto de alguém                    (Fase 8)
ui/terminal.gd (1)               local
ui/minimapa.gd (1)               local; + pontos dos bonecos                    (2.4)
ui/menu.gd (1)                   local                                          ✋
ui/hud_missao.gd (1)             local; missão do grupo                         (Fase 5)
ui/documento.gd (1)              local
ui/dialogo.gd (1)                local
ui/conversa.gd (1)               local
ui/cinematica.gd (1)             local; intro co-op trava todos                 (Fase 7) ✋
systems/rota_captura.gd (1)      local
systems/eco_ambiente.gd (1)      local
render/sondas_reflexo.gd (1)     local                                          ✋
world/mirante.gd (1)             local (névoa do mirante; outra frente, 21/09)
```

E mais 1 na rede: `net/sessao.gd`, em `corpo_local()`, que é a única permitida.

**Já trocados na Fase 2:** `world/pedestre.gd` contorna também os bonecos (`Sessao.corpos()`), sem mexer no `_jogador` dele.

A regra da v1 ("proibido em código novo, os 32 viram 4 APIs") vira: **proibido em código de rede** (a `Sessao` é a única exceção, porque é ela que acha o jogador local), e **proibido em sistema que precise de mais de um jogador**.

## 3. `WorldState.definir` — 14 em 8 arquivos (Fase 3)

| Arquivo | Chamadas | O que grava |
|---|---|---|
| `systems/profissoes.gd` | 4 | profissão de NPC, folha de vagas |
| `world/falas_morador.gd` | 3 | repetição, "falou X", chegada |
| `world/convidado.gd` | 2 | dono respondeu, dono pagou |
| `systems/falas_npc.gd` | 1 | "npc_X" já dito |
| `systems/plantio.gd` | 1 | canteiro |
| `systems/registro_civil.gd` | 1 | personagem da pessoa |
| `world/entregas_da_super.gd` | 1 | entrega |
| `world/item_no_chao.gd` | 1 | item pego (chave `chunk` + `chave()`) |

Todas passam a chamar `Sessao.mudar_mundo(coord, chave, valor)` (Fase 3, 3.1–3.2). Porta **não** está aqui: o estado dela é `_aberta`, local em `porta.gd`, e precisa ir para o `WorldState` (3.4).

## 4. Arquivos da rede

### Fase 1 (feita)

```
game/src/net/sessao.gd                 autoload
game/src/net/protocolo_rede.gd         puro
game/src/net/relogio_de_rede.gd        puro
game/src/net/buffer_interpolacao.gd    puro
game/src/net/validador_movimento.gd    puro
game/src/net/config_servidor.gd        puro
game/src/net/descoberta_lan.gd
game/src/net/avatar_remoto.gd
game/src/net/painel_online.gd
game/src/net/servidor_dedicado.gd
game/src/net/bot_rede.gd
game/scenes/net/servidor_dedicado.tscn
game/scenes/net/bot_rede.tscn
game/tests/mp/run_tests_rede.gd
tools/mp_teste.sh
tools/mp_dois.sh
game/project.godot                     +Sessao, +run/main_scene.dedicated_server
game/export_presets.cfg                +Servidor Dedicado Windows
captures/multiplayer/                  2 fotos
```

### Fase 2 (em parte, 21/09 à noite)

```
game/src/net/assinatura_do_mundo.gd    novo, puro: a assinatura da cidade
game/src/net/protocolo_rede.gd         VERSAO 2, estado de 23 B, RECUSA_CIDADE
game/src/net/sessao.gd                 pausar, corpos, mais_perto, anunciar_teletransporte,
                                       assinatura, empurrao, _campo
game/src/net/avatar_remoto.gd          arfagem, farol e facho, brasa, rodas, motorista,
                                       bicicleta, sentado, ausente, passos, chao
game/src/net/validador_movimento.gd    teletransporte declarado 1x a cada 3 s
game/src/net/buffer_interpolacao.gd    arfagem interpolada
game/src/net/descoberta_lan.gd         "cidade" no anuncio
game/src/net/painel_online.gd          "(outra cidade)"
game/src/net/bot_rede.gd               --bot-atraso --bot-arfagem --bot-parado --bot-giro;
                                       assinatura antes de ligar
game/tests/mp/run_tests_rede.gd        136 assercoes
tools/mp_teste.sh                      B depois de A; cidade; erro alheio vira aviso
tools/mp_dois.sh                       --carro
captures/multiplayer/                  anfitriao_ve_carro_e_lanterna.png, lanterna_do_amigo_baixo_e_cima.png
```

**Arquivos do jogo tocados (sem trabalho alheio pendente na hora; uma a oito linhas cada):**

```
ui/ui_manager.gd          get_tree().paused → Sessao.pausar (3 lugares)
ui/prancha_inventario.gd  idem (2)
ui/menu.gd                idem (2)
systems/modo_foto.gd      idem (2; Sessao.pausado no lugar de get_tree().paused)
systems/desmaio.gd        sem pulo de hora em rede; anunciar_teletransporte
ui/minimapa.gd            camada "Amigos": pontos de caneta azul
world/pedestre.gd         contorna os bonecos
```

### Próximas (novas, por fase)

```
Fase 3  game/src/net/mundo_rede.gd          pedido/validação/difusão de mudança de mundo (puro + RPCs na Sessao)
Fase 5  game/src/net/grupos.gd              grupos e missão por grupo (puro)
Fase 6  game/src/net/persistencia.gd        mundo.json, jogadores/<token>.json (puro)
        game/src/net/identidade.gd          token local (puro)
Fase 7  game/src/ui/folha_de_viagem.gd      lobby diegético
Fase 9  game/src/net/transporte_steam.gd
```

## 5. Constantes (vivas, em `ProtocoloRede`)

```
VERSAO 2 · PORTA_PADRAO 24567 · PORTA_DESCOBERTA 24568
TAM_ESTADO 23 · TAM_VEICULO 5 · ARFAGEM_MAX 80° · F_TODAS 8191 (13 bits)
RECUSA_* jogo versao cidade senha cheio pedido
MAX_JOGADORES_PADRAO 8 · MAX_JOGADORES_TETO 32
TICK_HZ 20 · ATRASO_INTERPOLACAO 0.12 · EXTRAPOLACAO_MAX 0.25 · SALTO_TELEPORTE 8.0
TIMEOUT_MIN_MS 3000 · TIMEOUT_MAX_MS 8000 · TEMPO_AUTENTICACAO 5.0
RAIO_INTERESSE 160 · NOME_MAX 24 · CHAT_MAX 96 · SENHA_MAX 64 · AUTH_MAX 8192
ESPACO_RUA 0 · ESPACO_ESTRADA 1 · ESPACO_INTERIOR_BASE 16 · Y_INTERIOR 1000 · Y_ESTRADA 3000
```

Na `Sessao`: `INTERVALO_RELOGIO 5` · `INTERVALO_PING 2` · `SUMIR_APOS 1` · `TETO_ESTADO_POR_S 60` · `TETO_CHAT 5` · `DISTANCIA_PESSOAL 0,55` · `EMPURRAO 1,6`.
No `AvatarRemoto`: `ALCANCE_NOME 22` · `OLHO 1,62` · `OLHO_SENTADO 0,86` · `RECUO_SENTADO 0,5` · `PASSADA PI/BOB_FREQ (1,53 m)` · `ALCANCE_PASSO 25` · `ESTERCO_MAX 0,6`.
Na `AssinaturaDoMundo`: `CHUNKS (8,−2) (−3,3) (0,0) (4,9)` · `TAMANHO 16`.
No `RelogioDeRede`: `JANELA 2` · `SUAVIZACAO 0.08` · `DESCIDA_MAX 0.05`.
No `ValidadorMovimento`: `VEL_A_PE 7.36` · `VEL_BICICLETA 16` · `VEL_CARRO 75` · `VEL_VERTICAL 45` · `FOLGA 1.5` · `INTERVALO_TELEPORTE 3`.

## 6. Skills do repo

| Skill | Uso na rede |
|---|---|
| `godot-project` | binário, headless, `src/` e `scenes/` |
| `psx-city` | chunk, `WorldState`, streaming (Fases 3 e 8) |
| `psx-render` | nada: a rede não toca em render |
| `psx-assets` | ícone do jogador no minimapa (2.4), retrato na folha (7.2) |

Uma skill `psx-multiplayer` vale ser criada quando a Fase 3 começar: regras 3–5 de `00` e o formato de `20`.

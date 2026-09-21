# SPEC AUDIO UI RE7 — Onda 4 (prep)
> PSX Audio UI · 19/09/2026 · **DRAFT** · Sem Git · Evitar Casa da Fumaça  
> Código no `game/` **só após GO pós-Onda 3** (brief PO1).  
> Norte: `docs/EPICO_UI_RE7.md` § Onda 4 · Motion: `SPEC_MOTION_RE7.md`  
> Inventário vivo: `game/src/systems/audio_director.gd` · `game/default_bus_layout.tres` · `Settings.BUSES`

## 0. Norte sonoro
Nav = **couro/tecido** · Confirm = **metal** · Deny = metal abafado · Page = madeira/papel úmido.  
Sem bipe 8-bit (`clique`/`bipe_curto` saem do fluxo de menu RE7).  
Drone LF em bus próprio. Duck + LowPass do **mundo** ao abrir opções/save/sistema/inventário.

## 1. Inventário atual (NÃO duplicar)

### 1.1 Buses (`default_bus_layout.tres`)
| Bus | volume_db layout | Settings slider | Notas |
|---|---|---|---|
| Master | 0 | GERAL | implícito |
| SFX | 0 + Reverb_sala | EFEITOS | piscina 3D/2D do AudioDirector |
| Music | −4 | MUSICA | |
| Radio | −6 | **fora** Settings (objeto mundo) | |
| Ambiente | −8 | AMBIENTE | loops vento/chuva |
| **Abafado** | runtime | — | criado por AudioDirector; LP 900 Hz → send **SFX** (oclusão paredes) |

### 1.2 AudioDirector (API relevante)
| Método | Uso hoje | UI RE7 |
|---|---|---|
| `tocar_ui(nome, db, pitch)` | `clique`/`papel`/`pegar` no bus **SFX** (piscina 2D) | manter API; **remap** stems + bus `UI` |
| `parar_ui()` | corta one-shots UI | ok |
| `ambiente` / `volume_ambiente` | mundo | duck via volume_db offset **ou** bus offset — sem matar loops |
| `_montar_bus_abafado()` | padrão runtime bus+LP | **reusar o padrão** para `UI` / `UI_Drone` / LP de menu |

HARD: não criar segundo mixer paralelo. Extender AudioDirector **ou** autoload fino `UIAudioRE7` que só faz duck/drone/hooks e delega one-shots ao Director.

### 1.3 Chamadas UI legado (a migrar no GO)
`menu_sistema.gd` / `menu.gd` / `prancha`: `clique`, `papel`, `pegar` → hooks lógicos §3.

## 2. Buses novos (runtime, padrão Abafado)
```
Master
├── SFX ← Abafado (já existe)
├── Music
├── Radio
├── Ambiente
├── UI          ← NOVO send Master · foley menu (sem Reverb_sala)
└── UI_Drone    ← NOVO send Master · loop LF (não no slider AMBIENTE)
```
`UIAudioRE7.ensure_buses()` no `_ready`. **Não** expor UI/UI_Drone em `OpcoesLista.audio()`.

## 3. Hooks lógicos → material → asset
| Hook | Material | Asset stem | Evento |
|---|---|---|---|
| `ui_nav` / `ui_focus` / `ui_move` | couro | `ui_leather_tick_0[1-3]` | move focus / hover=focus |
| `ui_confirm` / `ui_accept` | metal | `ui_metal_latch_01` | confirm / pick |
| `ui_back` / `ui_cancel` | couro | `ui_leather_flap_01` | back |
| `ui_deny` | metal abafado | `ui_metal_deny_01` | inválido / SAIR bloqueado |
| `ui_page` | madeira+papel | `ui_paper_wood_slide_01` | IMAGEM↔SOM / RAIZ→folha |
| `ui_open` | couro grosso | `ui_leather_open_01` | push menu / open prancha |
| `ui_close` | couro | `ui_leather_close_01` | pop |
| `ui_adjust` | metal fino | `ui_metal_tick_slider_0[1-2]` | hot-apply SOM |
| `ui_save_slot` | metal/cartão | `ui_metal_card_01` | focus save card |
| `ui_drag_start` | couro+metal | `ui_leather_drag_01` | Onda 2 DnD start |
| `ui_drop` | metal leve | `ui_metal_drop_01` | Onda 2 drop |
| `ui_inspect_open` | metal | `ui_metal_inspect_01` | Onda 3 open inspeção |
| `ui_inspect_tick` | couro seco (muito baixo) | `ui_leather_rub_01` | rotate tick suave (throttle) |
| `ui_destructive` | metal pesado | `ui_metal_warn_01` | SAIR PARA O TITULO |

Pasta: `res://assets/audio/ui/` (separada do banco sintético atual).

## 4. Duck + LowPass (mundo)
Gatilho: `UIManager` push/pop com depth (primeiro push liga, último pop desliga).  
Superfícies: opções, save, sistema, inventário (e inspeção se PO quiser).

| Bus | offset open | LP cutoff open |
|---|---|---|
| Music | −10 dB | ~1000 Hz |
| Ambiente | −14 dB | ~1000 Hz |
| SFX | −6 dB (opcional) | idle |
| Radio | −12 dB (recomendado) | — |

Idle LP = 20000 Hz ou efeito disabled.  
Tween paralelo `T_RE7_OPEN` 0,22 s / `T_RE7_CLOSE` 0,14 s · `TRANS_QUAD`.  
Offsets **em cima** de `Settings._aplicar_audio()` — escutar `Settings.changed`.  
**Não** gravar duck em `settings.cfg`. **Não** pausar AudioServer.

Padrão técnico: LP no bus Music/Ambiente (slot dedicado) — distinto do bus `Abafado` (oclusão).

## 5. Drone LF
| | |
|---|---|
| Bus | `UI_Drone` |
| Stream | `ui_drone_lf_01` loop seamless · energia &lt; 80 Hz |
| Open | −24 → −12 dB em `T_RE7_OPEN` |
| Close | → −48 + stop |
| Default | só overlay in-game (não boot CRT) |

## 6. Stub API (`UIAudioRE7`)
```gdscript
tocar_nav()      # ui_nav
tocar_confirm()  # ui_confirm
drone_on()       # = on_menu_push depth
drone_off()      # = on_menu_pop depth 0
play(hook)
on_menu_push(kind) / on_menu_pop()
```
Delegar one-shot a `AudioDirector` **depois** que stems existirem e piscina 2D usar bus `UI`; até lá stub toca do pool próprio.

## 7. Aceite (quando GO)
- [ ] Buses UI + UI_Drone runtime
- [ ] Open opções/save: duck+LP audível + drone
- [ ] Close restaura Settings volumes
- [ ] Sliders SOM intactos
- [ ] Menus sem `clique`/`bipe` no caminho RE7
- [ ] Sem Git · fora Casa da Fumaça

## 8. Entregáveis prep (esta onda)
| Path workspace | Função |
|---|---|
| `psx-specs/SPEC_AUDIO_UI_RE7.md` | este doc |
| `psx-specs/ASSETS_AUDIO_UI_RE7.md` | lista assets |
| `psx-menus/re7_dev/audio/ui_audio_re7.gd` | stub |
| `psx-menus/re7_dev/audio/INVENTARIO_AUDIO_VIVO.md` | snapshot Director/buses |

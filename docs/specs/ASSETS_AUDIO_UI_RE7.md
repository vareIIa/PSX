# ASSETS — Áudio UI RE7 (Onda 4 / P0 L)
> PSX Audio UI · 19/09/2026 · Sem Git · NO_GODOT  
> Pasta alvo: `res://assets/audio/` (banco indexado pelo AudioDirector)  
> Preferível subpasta `res://assets/audio/ui/` com os mesmos basenames.

## 0. Resolver runtime (`AudioDirector._stem_ui`)
Ordem: **preferidos canônicos** → fallback orgânico vivo → `papel`.  
**HARD:** nunca `clique` / `bipe_curto`.

## 1. Status no disco (KernelOS-PC · inventário 19/09)

| ID canônico (faltando) | Hook | Fallback vivo agora |
|---|---|---|
| `ui_leather_tick_01..03` | NAV / focus | **`papel`** |
| `ui_metal_latch_01` | CONFIRM | **`porta_trinco`** → `pegar` |
| `ui_leather_open_01` | OPEN | **`porta_abre`** → `papel` |
| `ui_leather_close_01` | CLOSE | **`porta_bate`** → `papel` |
| `ui_metal_deny_01` | DENY | **`celular_erro`** → `papel` |
| `ui_metal_tick_slider_01..02` | ADJUST | **`interruptor`** → `papel` |
| `ui_paper_wood_slide_01` | PAGE | *(ainda `papel` via NAV)* |
| `ui_metal_card_01` | SAVE SLOT | *(NAV no card)* |
| `ui_drone_lf_01` | DRONE loop | **`zumbido_loop`** |
| `ui_drone_rumble_02` | DRONE layer | — |

### Presentes (reuso orgânico — NÃO são bipe)
`papel` · `pegar` · `porta_trinco` · `porta_abre` · `porta_bate` · `celular_erro` · `interruptor` · `zumbido_loop`

### Proibidos no path RE7 UI
`clique` · `bipe_curto`

## 2. Código
`AudioDirector`: `STEM_*_PREFERIDOS` + `tocar_nav/confirm/open/close/deny/adjust`.  
Drop stems canônicos com o basename exato → remap automático sem novo código.

## 3. MVP gravar/comprar (8)
1. `ui_leather_tick_01` (+02/03 opcional)  
2. `ui_leather_open_01`  
3. `ui_leather_close_01`  
4. `ui_metal_latch_01`  
5. `ui_metal_deny_01`  
6. `ui_metal_tick_slider_01`  
7. `ui_paper_wood_slide_01`  
8. `ui_drone_lf_01` (loop seamless &lt;80 Hz)

## 4. Aceite P0 L
- [x] STEM_* preferidos + fallback sem bipe  
- [x] ASSETS doc com IDs faltantes  
- [ ] Stems canônicos no disco (assets) — pending art  
- [ ] Playtest pós-GO Godot  

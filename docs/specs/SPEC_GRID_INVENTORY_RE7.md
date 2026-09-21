# SPEC_GRID_INVENTORY_RE7 — Inventário Grid multi-slot (Onda 2)

**Agente:** PSX Grid Inventory  
**Data:** 19/09/2026  
**Status:** **PREP** · pending cutover GO do PO1 (pós-aceite Onda 1b)  
**HARD:** Sem Git · fora Casa da Fumaça · não tocar tipografia 1b · não merge na `prancha_inventario.gd` até GO

## 0. Referências (APPROVED)

| Doc | Uso |
|---|---|
| `docs/EPICO_UI_RE7.md` | Onda 2 — Grid + DnD |
| `docs/specs/SPEC_VISUAL_RE7.md` §5 | layout 480×270, célula 28², tokens SLOT_* |
| `docs/specs/SPEC_MOTION_RE7.md` §4 | `T_RE7_GRID_STAGGER` 35 ms, FOCUS/PRESS |
| `docs/specs/SPEC_A11Y_RE7.md` | `focus_neighbor_*`, hit ≥32, DnD teclado |

## 1. Contrato

| regra | valor |
|---|---|
| TELA lógica | 480 × 270 |
| Célula visual | **28 × 28** (gap **4**) |
| Hit / foco | área ≥ **32 × 32** (expand em torno da célula visual — A11y) |
| Colunas visíveis | **8** (+ setas 20×28) |
| Multi-slot | **1×2**, **2×2**, **N×M** (âncora = topo-esquerdo) |
| DnD | nativo `_get_drag_data` / `_can_drop_data` / `_drop_data` |
| Focus | rebuild `focus_neighbor_*` após drag/rebuild; `grab_focus` 1º slot ou último da sessão |
| Motion open | stagger row-major **35 ms**/célula (`T_RE7_GRID_STAGGER`) |
| Flag | `RE7_GRID` — cena paralela; prancha legado intocada até GO |
| Print pós-GO | `captures/ui/re7_dev/onda2_grid.png` |

### 1.1 Hit vs visual

Visual fica 28² (Visual §5). O `Control` do slot usa `custom_minimum_size = Vector2(32, 32)` (ou hit pad) para cumprir A11y ≥32 sem estourar o grid visual — ícone centrado na célula 28.

## 2. Tokens (Visual)

`PANEL_BASE` · `SLOT_EMPTY` · `SLOT_FILL` · `SLOT_FOCUS` (#c4a574 borda 2px + stain α0.12) · empty cruz `TEXT_MUTED` α0.35.

## 3. Árvore de nós (cena paralela)

```
InventarioGridRE7 (CanvasLayer, layer 110)          # inventario_grid_re7.gd
└── Raiz (Control full-rect, mouse_filter STOP)
    ├── Painel (Panel / ColorRect PANEL_BASE α)
    │   ├── Titulo (Label) "INVENTÁRIO"
    │   ├── SetaEsq / SetaDir (Button hit≥32)
    │   └── GridSlots (GridContainer cols=8, h/v sep=4)
    │       └── Slot_0 … Slot_n (InventorySlotRE7)
    └── (Onda 3+) Doc / Vitals / Retrato — stubs vazios OK
```

Scripts isolados (ui root — não conflita com `ui/re7/` do Diegetic):

| arquivo | responsabilidade |
|---|---|
| `inventario_grid_re7.gd` | open/close stub, flag, stagger, rebuild neighbors, demo fill |
| `inventory_slot_re7.gd` | célula + hit, focus, DnD nativo |
| `inventory_item_re7.gd` | Resource: `item_id`, `size_cells: Vector2i`, ícone via `Inventario.definicao` |

## 4. Occupancy multi-slot

- Grade lógica `cols × rows` (demo: 8×2 ou 8×1 faixa superior).
- Item com `size_cells` ocupa retângulo a partir da âncora.
- Drop só se **todas** as células livres (ou mesmas do drag source).
- Rebuild neighbors: só células âncora focáveis; células cobertas por multi-slot não entram na cadeia.

## 5. DnD + a11y teclado

- Mouse: drag nativo do slot.
- Teclado: `ui_accept` = pick/place; `ui_cancel` = cancelar hold (SPEC_A11Y §6).
- Após drop: `rebuild_focus_neighbors()` + focus no destino.

## 6. Demo items (IDs existentes / catálogo)

Usar ícones já em `res://resources/itens/` via `Inventario.definicao(id)` — **não** inventar assets.

Sugestão de `size_cells` (ajustável no Resource):

| id | size |
|---|---|
| lanterna | 1×2 |
| radio | 2×2 |
| fita | 1×1 |
| bateria | 1×1 |
| arma | 2×1 |
| municao | 1×1 |
| chave | 1×1 |
| (documento / id) | 1×1 |

## 7. Integração (só no GO PO1)

1. Feature-flag `RE7_GRID` em settings / const.
2. Hook em `prancha_inventario.gd` **ou** swap de cena — **não** nesta prep.
3. Print `onda2_grid.png` + aceite PO2.

## 8. Anti

- Merge na prancha antes do GO  
- Tocar `psx_*.fnt` / Onda 1b  
- Git  
- Casa da Fumaça  
- Glow neon no focus  

## 9. Changelog

- 19/09/2026 — PREP criado (Grid Inventory) a pedido PO1/PO2.

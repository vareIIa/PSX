# ONDA2 GRID — Árvore de nós

Status: Onda 2 GO · Sem Git · Sem prancha legado · Fonte: `src/ui/inventario_grid_re7.*`
Print: `captures/ui/re7_dev/onda2_grid.png`

## Arquivos

| path | papel |
|---|---|
| `src/ui/inventario_grid_re7.tscn` | cena paralela |
| `src/ui/inventario_grid_re7.gd` | `InventarioGridRE7` — open/close, stagger, occupancy, pick/place |
| `src/ui/inventory_slot_re7.gd` | `InventorySlotRE7` — hit≥32, DnD, focus |
| `src/ui/inventory_item_re7.gd` | `InventoryItemRE7` — id + size_cells |
| `docs/specs/SPEC_GRID_INVENTORY_RE7.md` | contrato |
| `scenes/test/grid_re7_teste.tscn` | shot isolado (sem prancha) |

## Runtime

```
InventarioGridRE7 (CanvasLayer 110)
└── Raiz (Control)
    └── Painel (ColorRect RE7_PANEL_BASE + edge)
        ├── Titulo (Label · UiEstilo.aplicar_re7 DISPLAY)
        └── GridSlots (GridContainer cols=8)
            └── Slot_x_y (InventorySlotRE7) × 16 (8×2)
```

## Contratos

- `abrir()` → `UIManager.push_menu(_raiz, true)` + stagger + grab_focus
- `fechar()` → `UIManager.remove_menu(_raiz)`
- Pick/place: `ui_accept` pick → `ui_accept` place; `ui_cancel` cancela hold / fecha
- DnD mouse: `_get_drag_data` / `_can_drop_data` / `_drop_data`
- Multi-slot âncora topo-esquerdo; cobertas `FOCUS_NONE`
- Flag: `RE7_GRID` (UiEstilo quando UI Dev gravar; fallback ON)

## Capture

```
Godot --path game --scene res://scenes/test/grid_re7_teste.tscn --resolution 1280x720 -- `
  --shot=<PSX>/captures/ui/re7_dev/onda2_grid.png --shot-frame=45 --shot-quit
```

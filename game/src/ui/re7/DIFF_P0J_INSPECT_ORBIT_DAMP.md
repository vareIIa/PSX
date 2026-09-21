# P0 J INSPECT_ORBIT_DAMP — diff (NO_GODOT)

## Paths
- `game/src/ui/re7/inspect_viewport.gd` — damp + enter/exit scale
- `game/src/ui/ui_estilo.gd` — `T_RE7_PANEL := 0.20` (SPEC_MOTION_RE7)
- `game/src/ui/re7/DIFF_P0J_INSPECT_ORBIT_DAMP.md` (este arquivo)

## Changes
1. **Damp:** λ = ln2 / (T_RE7_SPIN_DAMP×0.5) ≈ half-life 0,17s; ω*=e^(-λΔt) ao soltar. Sem BACK/ELASTIC/BOUNCE.
2. **Enter:** scale 0,96→1 (±4%) em `T_RE7_PANEL` EXPO out (Control + ItemSlot).
3. **Exit:** ω=0 imediato; scale→0,96 em `T_RE7_CLOSE` EXPO in; depois `closed`.

## Not touched
- `prancha_inventario.gd` wire
- Grid / Godot / Git

## Nota ID
Fatia renomeada: era P0 I (conflito tipografia) → **P0 J** (PO1/PO2).
# SPEC_INSPECT_VITALS_RE7 — Onda 3 (prep)

**Status:** PREP · Owner: PSX Diegetic 3D · PO1 GO pós-Onda 2  
**HARD:** Sem Git · Evitar PLANO_CASA_FUMACA / world Casa da Fumaça  
**Não tocar:** tipografia / `prancha_inventario.gd` (Onda 1b em curso)

## Norte
Evoluir a **vitrine SubViewport parcial** já existente na prancha (`_montar_vitrine` + `ItemModelo.criar`) para inspeção orbitável, e **substituir a polaroid** (`_montar_retrato_vivo` / label BEM) por monitor de vitals emissivo.

## 1. ItemInspectViewport

| Item | Contrato |
|---|---|
| Tipo | `Control` + `SubViewport` 140×150 (Visual §5.3) |
| Mundo | `own_world_3d = true`, void α≈0.85 |
| Câmera | `Camera3D` fov ~30, look-at origem |
| Luz | Key quente + rim fria (dramática); ambient baixa |
| Pivot | `Node3D` yaw livre / pitch ±75° |
| Input | mouse drag + stick analógico; **não** setas de slot |
| Spin damp | half-life ~0,18 s · `T_RE7_SPIN_DAMP` 0,28–0,40 s · EXPO out em ω |
| Zoom | 0,8–1,4 (opcional scroll / gatilho) |
| API | `set_item(id)`, `clear()`, `enter()`, `exit()` |
| A11y | focus trap no enter; `ui_cancel` / B restaura slot |

## 2. VitalsMonitor

| Item | Contrato |
|---|---|
| Tipo | `Control` (painel diegético sob / no lugar da polaroid) |
| LEDs | 5 segmentos 6×4 (ou barra 48×6) |
| Cores | `UiEstilo.RE7_VITAL_OK` / `_WARN` / `_CRIT` |
| Fonte HP | `Inventario.vida` / `vida_maxima` (+ sinal `vida_mudou`) |
| Motion | emission Tween SINE in-out; CRIT pulse ~0,6–1,2 s α 0,7↔1,0 |
| Anti | tipografia “BEM” como primário; glow neon RGB |

Faixas: ≥0,75 OK · ≥0,4 WARN · >0 CRIT · 0 MORTO (LEDs apagados / flicker morto).

## 3. Integração (só após GO)

1. Prancha: trocar auto-spin da vitrine por `ItemInspectViewport` no examine.  
2. Remover polaroid viva como status; montar `VitalsMonitor`.  
3. Prints `captures/ui/re7_dev/onda3_*.png`.  
4. SFX hooks: `ui_re7_inspect_in` / `_out` (Audio UI Onda 4).

## 4. Entrega prep (este pacote)

- `game/src/ui/re7/inspect_viewport.gd` + `.tscn`
- `game/src/ui/re7/vitals_monitor.gd` + `.tscn`
- `game/scenes/ui/re7_inspect_vitals_demo.tscn`
- Lista de nós: `docs/briefs/ONDA3_DIEGETIC_PREP.md`

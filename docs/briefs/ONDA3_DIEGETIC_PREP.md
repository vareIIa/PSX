# Onda 3 — Prep Diegetic 3D (PO1)

**Owner:** PSX Diegetic 3D  
**Estado:** PREP pronto · **código de integração na prancha = aguarda GO pós-Onda 2**  
**HARD:** Sem Git · sem Casa da Fumaça · sem editar tipografia/prancha (Onda 1b)

## Arquivos

| Path | Papel |
|---|---|
| `docs/specs/SPEC_INSPECT_VITALS_RE7.md` | Contrato órbita + vitals |
| `game/src/ui/re7/inspect_viewport.gd` | Skeleton `ItemInspectViewport` |
| `game/src/ui/re7/inspect_viewport.tscn` | Cena do viewport |
| `game/src/ui/re7/vitals_monitor.gd` | Skeleton `VitalsMonitor` |
| `game/src/ui/re7/vitals_monitor.tscn` | Cena dos LEDs |
| `game/scenes/ui/re7_inspect_vitals_demo.tscn` | Demo isolada |

## Árvore de nós — ItemInspectViewport

```
ItemInspectViewport (Control)           script inspect_viewport.gd
├── InspectVP (SubViewport) 140×150 · own_world_3d · transparent
│   ├── WorldEnvironment (void α0.85, ambient baixa)
│   └── World (Node3D)
│       ├── KeyLight (OmniLight3D quente)
│       ├── RimLight (OmniLight3D frio)
│       ├── OrbitPivot (Node3D) yaw/pitch
│       │   └── ItemSlot (Node3D) ← ItemModelo.criar(id)
│       └── Camera3D fov30 look-at origem
└── View (TextureRect) ← InspectVP.get_texture()
```

## Árvore de nós — VitalsMonitor

```
VitalsMonitor (Control)
├── LedRow (HBoxContainer)
│   ├── Led0..Led4 (ColorRect 6×4)  emission via color.a + modulate pulse
└── MicroLabel (Label) ESTÁVEL/FERIDO/GRAVE — secundário
```

## Legado a evoluir (não deletar às cegas)

- `prancha_inventario.gd` → `_montar_vitrine()` / `_mostrar_vitrine()` (auto-spin)
- `prancha_inventario.gd` → `_montar_retrato_vivo()` / label `_estado` (“BEM”)
- `item_modelo.gd` → `ItemModelo.criar(id)`

## Pós-GO (checklist)

- [ ] Wire examine → `ItemInspectViewport.enter()` + `set_item`
- [ ] Swap polaroid → `VitalsMonitor` bound a `Inventario.vida_mudou`
- [ ] Remover tipografia BEM como primário
- [ ] Prints `captures/ui/re7_dev/onda3_inspect.png` + `onda3_vitals_{ok,warn,crit}.png`
- [ ] PO2 valida aceite

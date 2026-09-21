# CHECKLIST P0 L — AUDIO_STEMS_UI
> 19/09/2026 · NO_GODOT

## Diff
- `game/src/systems/audio_director.gd` — `STEM_*_PREFERIDOS`, `_stem_ui`, `tocar_open/close/deny/adjust`
- `docs/specs/ASSETS_AUDIO_UI_RE7.md` — IDs faltantes + fallbacks vivos

## Review
1. [ ] Zero referência a clique/bipe nos STEM_*_PREFERIDOS
2. [ ] NAV resolve para `papel` hoje; CONFIRM para `porta_trinco` ou `pegar`
3. [ ] OPEN/CLOSE usam porta_* quando existirem
4. [ ] Drone: `zumbido_loop` até `ui_drone_lf_01`
5. [ ] Drop de `ui_leather_tick_01.wav` no assets/audio remapeia sozinho

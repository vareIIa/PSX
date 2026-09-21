# RE7 Onda 3 SUPPORT — tokens / captura inspect+vitals

Diegetic 3D is LEAD for `inspect_viewport` / `vitals_monitor` / demo.
SUPPORT: UiEstilo tokens + isolated capture runners. **No prancha edits.**

## Tokens (`ui_estilo.gd`)
- `RE7_INSPECT_SIZE` 140×150 · `RE7_INSPECT_VOID`
- `RE7_VITAL_*` colors (existing) + `RE7_VITAL_LED` / `_GAP` / `_COUNT` / `_BAR`
- `RE7_SIZE_VITAL` · `RE7_VITAL_OK_RATIO` / `_WARN_RATIO`
- `T_RE7_SPIN_DAMP` 0.34

## CLI captura (recomendado)

### Inspect
```
.tools\Godot_v4.7.2-stable_win64_console.exe --path game res://src/ui/re7/ver_inspect_re7.tscn -- --ver-inspect-re7
```
→ `captures/ui/re7_dev/onda3_inspect.png`

### Vitals
```
.tools\Godot_v4.7.2-stable_win64_console.exe --path game res://src/ui/re7/ver_vitals_re7.tscn -- --ver-vitals-re7
.tools\Godot_v4.7.2-stable_win64_console.exe --path game res://src/ui/re7/ver_vitals_re7.tscn -- --ver-vitals-re7=warn
```
→ `onda3_vitals.png` / `onda3_vitals_{ok,warn,crit}.png`

### Demo Diegetic (alt)
```
.tools\Godot_v4.7.2-stable_win64_console.exe --path game res://scenes/ui/re7_inspect_vitals_demo.tscn -- --onda3-shot=inspect
```

### Via cidade
```
.tools\Godot_v4.7.2-stable_win64_console.exe --path game -- --ver-inspect-re7
.tools\Godot_v4.7.2-stable_win64_console.exe --path game -- --ver-vitals-re7=crit
```

### Headless smoke
```
.tools\Godot_v4.7.2-stable_win64_console.exe --path game --headless --quit-after 1
```

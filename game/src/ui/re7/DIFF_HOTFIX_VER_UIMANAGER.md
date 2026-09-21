# HOTFIX P1 — UIManager abrir_ver_*_re7 (NO_GIT)

## Crash
`cidade.gd` chama `UIManager.abrir_ver_inspect_re7()` / `abrir_ver_vitals_re7()`
para `--ver-inspect-re7` / `--ver-vitals-re7`, mas os métodos não existiam.

## Fix
`game/src/ui/ui_manager.gd`:
- `abrir_ver_inspect_re7()` → instancia `res://src/ui/re7/ver_inspect_re7.tscn` no root
- `abrir_ver_vitals_re7()` → instancia `res://src/ui/re7/ver_vitals_re7.tscn` no root
- `process_mode = ALWAYS`; runners capturam PNG e dão `quit` sozinhos

## Not touched
- prancha_inventario.gd
- inspect_viewport / vitals_monitor internals (já PASS)
- Git / Godot shots nesta entrega (stubs only)

## Coord
Demos re7/* = Diegetic. UIManager stub mínimo pra destravar CLI.
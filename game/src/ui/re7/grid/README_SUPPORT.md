# RE7 Grid SUPPORT — flag / UIManager / captura

## Flag
- `UiEstilo.RE7_GRID` — `false` por default (OFF até GO).
- Enable produção: flip `const RE7_GRID := true` em `game/src/ui/ui_estilo.gd`.
- Capturas: `--ver-grid-re7` usa `UIManager.abrir_inventario_grid(force=true)` (não precisa flip).

## UIManager API
- `abrir_inventario_grid(force:=false, pausar:=true) -> Node`
- `fechar_inventario_grid()`
- `inventario_grid_aberto() -> bool`
- Cena: `res://src/ui/inventario_grid_re7.tscn` (Grid LEAD)

## CLI captura
### A) Runner isolado (recomendado SUPPORT)
```
.tools\Godot_v4.7.2-stable_win64_console.exe --path game res://src/ui/re7/grid/ver_grid_re7.tscn -- --ver-grid-re7
```
Escreve: `captures/ui/re7_dev/onda2_grid.png`

### B) Via cidade + CaptureTool
```
.tools\Godot_v4.7.2-stable_win64_console.exe --path game -- --ver-grid-re7 --shot=<ABS>\captures\ui\re7_dev\onda2_grid.png --shot-frame=90 --shot-quit
```

### Headless smoke
```
.tools\Godot_v4.7.2-stable_win64_console.exe --path game --headless --quit-after 1
```

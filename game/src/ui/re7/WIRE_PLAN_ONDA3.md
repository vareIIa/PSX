# Onda 3 — plano de wire (pronto, aguardando GO WIRE PO1)

**Estado:** stubs em `re7_onda3_wire.gd` · **prancha NÃO editada** · Sem Godot  
**Depois de:** P0 tipografia/layout (UI Dev na prancha)

## Alvos incrementais em `prancha_inventario.gd`

| Legado | Substituir por | API |
|---|---|---|
| `_mostrar_vitrine` / auto-spin no examine | `ItemInspectViewport` | `enter()`, `set_item(id)`, `exit()` |
| Label `_estado` ("BEM") | `VitalsMonitor` | auto via `Inventario.vida_mudou` / `set_ratio` |
| Polaroid Corpo vivo como **status** | LEDs diegéticos | moldura polaroid pode ficar |

## Não fazer
- Cutover grid
- Substituir scrapbook inteiro
- Abrir Godot / novos `--shot` sem GO Jamerson
- Confundir com Casa da Fumaça

## Ordem no GO WIRE
1. Diegetic edita **só** hooks em `prancha_inventario.gd` (um editor)
2. Usa `Re7Onda3Wire.mount_inspect/mount_vitals`
3. Diff → New Bot (PO2) review
4. Prints só se Jamerson liberar Godot
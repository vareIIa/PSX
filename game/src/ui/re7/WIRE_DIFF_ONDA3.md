# Onda 3 WIRE — diff paths (código only, sem Godot)

## Arquivos tocados
- `game/src/ui/prancha_inventario.gd` — wire incremental
- `game/src/ui/re7/re7_onda3_wire.gd` — `WIRE_ENABLED := true`

## O que mudou na prancha
1. **EXAMINAR** → `ItemInspectViewport` (`enter` / `set_item` / `exit`); vitrine auto-spin some durante examine
2. **Polaroid miolo + Label BEM** → `VitalsMonitor` LEDs (`Inventario.vida_mudou` / `refresh`)
3. Scrapbook / faixa / fonte_re7 / overlay / MenuSistema **preservados**
4. **Sem** cutover grid

## Helpers
- `_montar_onda3_wire()` — monta nós via `Re7Onda3Wire.mount_*`
- `_sincronizar_inspect()` — liga/desliga inspect no toggle examine

## Não feito (HOLD)
- Prints / Godot (HARD STOP até GO Jamerson)
- Git

## Review
PO2: diff em disco nos paths acima.
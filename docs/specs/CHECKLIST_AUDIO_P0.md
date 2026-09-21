# CHECKLIST AUDIO P0 — PSX Onda 4 (GO fatia)

> 19/09/2026 · Sem Git · Evitar Casa da Fumaça · Sem grid inventory merge · Sem launch Godot neste GO  
> Destino: `KernelOS-PC` `C:\Users\Administrator\Documents\Codes\Games\PSX\`  
> Box mirror: `/workspace/psx-specs/CHECKLIST_AUDIO_P0.md` + drop `/workspace/psx-specs/audio_p0_drop/`

## Entrega (código)

| Arquivo PC | Mudança | Status esperado |
|---|---|---|
| `game/src/systems/audio_director.gd` | Buses runtime `UI` + `UI_Drone`; LP menu em Music/Ambiente; `tocar_nav`/`tocar_confirm` (papel/pegar); `drone_on`/`drone_off`; `on_menu_push`/`on_menu_pop` com depth; duck offsets; re-aplica em `Settings.changed`; **não** grava duck em cfg | PATCH |
| `game/src/ui/ui_manager.gd` | `push_menu`/`pop_menu`/`remove_menu` → `AudioDirector.on_menu_push/pop` (duck+LP; drone só se `kind` ∈ sistema/opcoes/save) | PATCH |
| `game/src/ui/menu_sistema.gd` | open → `drone_on` (duck via UIManager); `abrir_em` capture → `on_menu_push(&"sistema")`; close → `drone_off` / `on_menu_pop` se own; focus/adjust → `tocar_nav`; accept → `tocar_confirm`; **zero** `clique`/`bipe` no path RE7 | PATCH |
| `game/src/ui/prancha_inventario.gd` | hooks `tocar_nav`/`tocar_confirm` + `push_menu(..., &""inventario"")` | DONE UI Dev |
| `game/default_bus_layout.tres` | Intact (UI/UI_Drone runtime) | OK |
| `game/src/systems/settings.gd` | Intact (sliders Master/Music/SFX/Ambiente) | OK |

### API AudioDirector (P0)

```
tocar_nav(db=-16)         # stem provisório: papel (bus UI)
tocar_confirm(db=-14)     # stem provisório: pegar (bus UI)
drone_on() / drone_off()  # loop UI_Drone; silêncio-safe se não houver stem
on_menu_push(kind)        # depth++; duck+LP no 1º; drone se kind sistema|opcoes|save
on_menu_pop()             # depth--; restore no 0
```

Duck offsets (em cima de Settings): Music −10 · Ambiente −14 · SFX −6 · Radio −12  
Tween: T_OPEN 0.22 / T_CLOSE 0.14 · TRANS_QUAD · LP 20000→1000 Hz (Music+Ambiente)

## Aceite PO2 (manual — humano; sem Godot neste agente)

1. [ ] Abrir **menu sistema** in-game: mundo abafa (Music/Ambiente mais surdos + LP audível).
2. [ ] Drone LF baixo presente em sistema/opções (ou silêncio-safe se stem ausente — sem erro).
3. [ ] Fechar menu: volumes voltam ao que os sliders Settings mandam (sem “grudar” duck).
4. [ ] Mexer sliders SOM **com menu aberto**: volumes respondem e **mantêm** o offset de duck.
5. [ ] Mexer sliders SOM **com menu fechado**: comportamento idêntico ao pré-P0.
6. [ ] Nav (↑↓ / focus): som **papel** (orgânico), **não** clique/bipe.
7. [ ] Confirm (accept): som **pegar**.
8. [ ] `settings.cfg` / user config **não** contém valores de duck após abrir/fechar menu.
9. [x] Prancha inventário: **sem** regressão; hooks `tocar_nav`/`tocar_confirm` / push-pop = **DONE UI Dev**.
10. [ ] Casa da Fumaça / grid inventory: **não** tocados.

## Como testar (manual)

1. Abrir projeto Godot no PC: `C:\Users\Administrator\Documents\Codes\Games\PSX\game\`
2. Rodar cena de jogo (não headless).
3. Pausar → abrir pauzinhos / menu sistema.
4. Ouvir duck + (opcional) drone; navegar e confirmar.
5. Em Opções → SOM, arrastar Master/Music/SFX/Ambiente com menu aberto e fechado.
6. Fechar menu e confirmar restore.

## Drop box (aplicar no PC)

Arquivos prontos em `/workspace/psx-specs/audio_p0_drop/`:

- `audio_director.gd` → `game/src/systems/audio_director.gd`
- `ui_manager.gd` → `game/src/ui/ui_manager.gd`
- `menu_sistema.gd` → `game/src/ui/menu_sistema.gd`
- `APPLY_AUDIO_P0.ps1` — copia in-place (Sem Git)

## Notas / blockers

- Stems `ui_*` leather/metal ainda não existem → remap orgânico `papel`/`pegar`.
- Drone: tenta `ui_drone_lf_01` / `zumbido_loop` / `hum_loop`; se ausente, só tween de volume (safe).
- Prancha: UI Dev deve chamar `AudioDirector.tocar_nav` / `tocar_confirm` e preferir `UIManager.push_menu(..., &"inventario")` para duck.
- Executor sem `ListMachines`/`CopyFromBox` nativo neste turno: se arquivos não estiverem no PC, rodar `APPLY_AUDIO_P0.ps1` no KernelOS-PC ou parent CopyFromBox.

# Onda 4 SAVE WIRE — diff (código-only · NO_GODOT · sem playtest)

## Arquivos tocados (KernelOS PSX)

| Path | Mudança |
|---|---|
| `game/src/ui/menu_sistema.gd` | Pagina CARREGAR → `SaveCardsPanelRe7`; scrim-only draw; input gate; hide on close |
| `game/src/ui/re7/save_panel.gd` | `foco_padrao()` público p/ deferred focus |
| `game/src/systems/save_game.gd` | `_capturar_thumb` via `SaveThumbCapture` após salvar |

## Comportamento

1. **MenuSistema → CARREGAR:** instancia/mostra `SaveCardsPanelRe7` (130,31), `refresh_from_savegame()` + thumbs locais; lista papel `_espacos()` deixa de ser montada (fica helper legado).
2. **Card select:** se `SaveGame.existe` → `fechar` + `carregou.emit(espaco)` (mesmo contrato prancha).
3. **Voltar / examinar / pausa:** volta RAIZ; painel some.
4. **SaveGame.salvar:** grava `user://save_thumbs/slot_N.png` (viewport → Image).

## Não tocado

- `menu.gd` título CARREGAR (ainda lista legado) — próximo GO se PO2 pedir
- `project.godot` / Git / Godot runtime / Casa da Fumaça

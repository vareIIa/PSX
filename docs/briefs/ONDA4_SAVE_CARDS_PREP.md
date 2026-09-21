# Onda 4 — Prep Save Cards (PO1)

**Owner:** PSX Save Cards  
**Estado:** PREP pronto · **wire aguarda GO**  
**HARD:** NO_GODOT_RUNTIME · Sem Git · sem Casa da Fumaça · sem editar `game/` até GO · on-top legado

## Arquivos

| Path (destino pós-GO) | Papel |
|---|---|
| `docs/specs/SPEC_SAVE_CARDS_RE7.md` | Contrato cards + thumbs |
| `game/src/ui/re7/save_card.gd` | `SaveCardRe7` (Margin/HBox + thumb) |
| `game/src/ui/re7/save_card.tscn` | Stub cena card |
| `game/src/ui/re7/save_panel.gd` | `SaveCardsPanelRe7` (3 slots + VOLTAR) |
| `game/src/ui/re7/save_panel.tscn` | Stub cena painel |
| `game/src/ui/re7/save_thumb_capture.gd` | Helper thumb viewport → disco |
| `game/scenes/ui/re7_save_cards_demo.tscn` | Demo isolada |

PREP mirror: `psx-menus/re7_dev/onda4_prep/` (GO copia → `game/src/ui/re7/`).

## Árvore de nós — SaveCardsPanelRe7

```
SaveCardsPanelRe7 (MarginContainer)     script save_panel.gd
└── RootVBox (VBoxContainer)
    ├── Title (Label) "CARREGAR"
    ├── CardsVBox (VBoxContainer)
    │   ├── SaveCardRe7 espaco=0
    │   ├── SaveCardRe7 espaco=1
    │   └── SaveCardRe7 espaco=2
    ├── Voltar (Button) focusable
    └── Hints (Label) micro TEXT_MUTED
```

## Árvore de nós — SaveCardRe7

```
SaveCardRe7 (PanelContainer)            script save_card.gd
└── Margin (MarginContainer) 8/6
    └── Row (HBoxContainer)
        ├── Thumb (Control) 72×40
        │   ├── ThumbVP (SubViewport) 72×40 UPDATE_DISABLED · void placeholder
        │   └── View (TextureRect) ← tex estática ou VP.get_texture()
        └── MetaVBox (VBoxContainer)
            ├── SlotLabel   "ESPAÇO N" / "VAZIO"
            ├── PlaceLabel  lugar/local
            ├── TimeLabel   quando
            └── StatusLabel vida/status (opcional)
```

## Legado a evoluir (não deletar às cegas)

- `menu.gd` → lista CARREGAR (papel creme / ESPAÇO N)
- `menu_sistema.gd` → página CARREGAR
- Sinais: `pediu_carregar(espaco)` · `MenuSistema.carregou(espaco)`
- `SaveGame.resumo(espaco)` · CONTINUAR = newest via `quando`

## Pós-GO (checklist)

- [ ] Wire título + menu_sistema → `SaveCardsPanelRe7`
- [ ] `refresh_from_savegame` + `SaveThumbCapture.load_thumb_local`
- [ ] Captura thumb real só com runtime (pós GO)
- [ ] `UiAudio.play(&"ui_save_slot")` no focus
- [ ] Motion `T_RE7_PANEL` EXPO out + fade cards
- [ ] Prints `captures/ui/re7_dev/onda4_save_*.png`
- [ ] PO2 valida aceite

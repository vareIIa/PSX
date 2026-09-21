# SPEC_SAVE_CARDS_RE7 — Onda 4 (prep)

**Status:** PREP · Owner: PSX Save Cards · wire aguarda GO  
**HARD:** NO_GODOT_RUNTIME · Sem Git · Evitar Casa da Fumaça · Sem código em `game/` até GO · on-top legado

## Norte
Matar baseline papel creme lista `ESPAÇO N` (`aaa_carregar.png`). Mesmo card em título **CARREGAR** (`menu.gd`) e página **CARREGAR** (`menu_sistema`). Painéis dirty translucent RE7.

## Data — `SaveGame.resumo(espaco) -> Dictionary`
| chave | tipo | notas |
|---|---|---|
| `quando` | `String` | datetime (`Time.get_datetime_string_from_system`); ordena CONTINUAR = mais recente |
| `lugar` / `local` | `String` | nome local (ex. TELEFONE DA R…); aceitar ambas no wire |
| `vida` / status | opcional | banda/status se existir; senão omitir |
| *(vazio)* | `{}` / sem arquivo | slot **VAZIO** (ainda focusável) |

Espaços: **0..2** (3 slots).

## Layout 480×270
- Painel ~220×200 centrado · card row ~48–52 · thumb 72×40 · margins 8/6
- Title CARREGAR · 3 cards · VOLTAR · hints micro

## Visual (consumir `UiEstilo` / Theme Tokens no wire)
`PANEL_BASE` · `TEXT_PRIMARY` · `TEXT_MUTED` · `TEXT_TITLE` · `ACCENT` · `SLOT_FOCUS` — ver `SPEC_VISUAL_RE7`. PREP usa Color fallbacks só se `UiEstilo` ausente.

## Focus / A11y
Vizinhos verticais · hit ≥32 · hover=focus · slots vazios focusáveis · CONTINUAR (fora deste painel) = save mais recente via `quando`.

## Motion + áudio
- Enter: `T_RE7_PANEL` · `TRANS_EXPO` · `EASE_OUT` · cards fade (`SPEC_MOTION_RE7`)
- Focus card: `UiAudio.play(&"ui_save_slot")` (`SPEC_AUDIO_UI_RE7`)

## Thumb API (helper — stub PREP; runtime pós-GO)
`SaveThumbCapture`: `capture_viewport_to_image` · `save_thumb_local` · `load_thumb_local`. Card mostra TextureRect placeholder até GO.

## Legado a evoluir (não deletar às cegas)
- `menu.gd` lista CARREGAR
- `menu_sistema` página CARREGAR · sinais `pediu_carregar(espaco)` / `MenuSistema.carregou(espaco)`

## Pós-GO
- [ ] Wire título + menu_sistema → `SaveCardsPanelRe7`
- [ ] `refresh_from_savegame` + thumbs locais
- [ ] SFX `ui_save_slot` · motion painel
- [ ] Prints `captures/ui/re7_dev/onda4_save_*.png`
- [ ] Sem código novo em `game/` antes do GO

## Entrega prep
`game/src/ui/re7/save_card.*` · `save_panel.*` · `save_thumb_capture.gd` · demo `re7_save_cards_demo.tscn` · brief `docs/briefs/ONDA4_SAVE_CARDS_PREP.md`

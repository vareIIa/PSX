# CHECKLIST_TOKENS_UIESTILO_RE7
**Owner:** PSX Theme Tokens · **P0** · **19/09/2026**  
**Consome:** PSX Godot UI Dev (prancha/sistema) · **Não:** Theme Tokens não edita prancha  
**HARD:** NO_GODOT_RUNTIME · sem Git · fora Fumaça

**Arquivo:** `game/src/ui/ui_estilo.gd`  
**Spec mãe:** `docs/specs/SPEC_POLISH_TIPO_LAYOUT_RE7.md` (+ `SPEC_VISUAL_RE7.md` · `TOKENS_SLIDER_RE7.md`)
**Status:** GO PO1+PO2 POLISH_CONTROLES_RE7 (19/09/2026) — tokens no disco

---

## Tipografia (sans — nunca `.fnt` nesta superfície)

| token | size | weight | track | API |
|---|---|---|---|---|
| DISPLAY | 18 | 600 | +40 | `aplicar_re7_display` |
| TITLE | 14 | 600 | +20 | `aplicar_re7_title` |
| BODY | 11 | 400 | 0 | `aplicar_re7_body` |
| MICRO | 9 | 400 | +40 | `aplicar_re7_micro` |
| VITAL | 10 | 600 | +60 | `aplicar_re7_vital` (preferir LED) |

- [ ] Labels RE7 passam por `fonte_re7` / `aplicar_re7_*` (não `aplicar` + bitmap)
- [ ] Sem size fora da tabela (drift = RFC PO)
- [ ] Body no papel usa `RE7_DOC_INK` `#2a2420` — nunca `RE7_TEXT_MUTED` / `#8a`

## Layout / safe (480×270)

- [ ] `RE7_SAFE` = 8 · `RE7_SAFE_HARD` = 4 · `RE7_MARGEM_MODAL` = 24
- [ ] Faixa slots `RE7_FAIXA_Y0..Y1` = 28–60 · title baseline `RE7_TITLE_BASELINE_Y` = 20
- [ ] Hit mín `RE7_HIT_MIN` / `HIT_ABA_MIN` = 32
- [ ] Pads: `RE7_PAD_PANEL` 10 · `RE7_PAD_MODAL` 12 · row 16 / gap 2

## StyleBox (factories em UiEstilo) — GO POLISH_CONTROLES / tipo

- [x] Panel modal SOM/IMAGEM/SISTEMA → `style_re7_panel()` (`RE7_PAD_MODAL` 12) — PainelRe7 em menu_sistema (P0 F 19/09)
- [ ] Doc IDENTIDADE → `style_re7_doc()` + tinta `RE7_DOC_INK`
- [ ] Slots inventário → `style_re7_slot_empty|fill|focus()` (`RE7_GRID_SLOT` 28)
- [ ] Slider SOM → `style_re7_slider_track|fill|thumb()` (sem ASCII)

## Legado

- [ ] HUD bitmap: `FONTE_*` + `aplicar()` intactos
- [ ] `MARGEM` 7 permanece p/ HUD; menus RE7 usam `RE7_SAFE`


## Slider / controles (POLISH_CONTROLES_RE7)

| token | valor | uso |
|---|---|---|
| `RE7_SLIDER_TRACK_W/H` | 72 × **6** | track (H na faixa 6–8; Visual §6 tinha 4) |
| `RE7_SLIDER_THUMB_W/H` | 4 × 8 | thumb |
| `RE7_SLIDER_ROW_PAD` | 4 | pad vertical na row 16 |
| `RE7_SLIDER_TRACK` | ~#12181a α0.85 | bg track |
| `RE7_SLIDER_FILL` | `RE7_ACCENT` #b85a42 | fill |
| `RE7_SLIDER_THUMB` | `RE7_TEXT_TITLE` | thumb |

- [ ] SOM/IMAGEM usam `style_re7_slider_track|fill|thumb` — **não** meter ASCII `[####]`
- [ ] Row de slider respeita `RE7_ROW` 16 + `RE7_SLIDER_ROW_PAD`
- [ ] Consumer: UI Dev / Settings — Theme Tokens só declara

## Motion (P0 F)

- [ ] `T_RE7_FOCUS` = **0.08** (focus sine-out; não usar `T_MENU_FOCUS` em superfície RE7)
- [x] Panel: `style_re7_panel()` — menu_sistema PainelRe7

## Aceite

- [ ] Tokens no disco; UI Dev re-aplica prancha/sistema
- [ ] Sem `--shot` / runtime até GO Jamerson

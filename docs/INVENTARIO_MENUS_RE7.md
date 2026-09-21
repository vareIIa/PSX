# INVENTARIO MENUS RE7 — PSX
> Docs Lead · 19/09/2026 · Sem código · Sem Git · Evitar Casa da Fumaça
> Espelha `docs/EPICO_UI_RE7.md`. Playbook: `docs/PLAYBOOK_MENUS_AAA.md` §0.
> Legado curto: `docs/INVENTARIO_MENUS.md` (hooks papel).

## 0. Standing: **MENU AAA CÓDIGO-COMPLETE** · **LIVE AAA FECHADO** · headless **LIMPO** · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid **OFF** · P1b hairline **pending** · Sem Git.

**Snapshot:** **MENU AAA CÓDIGO-COMPLETE** · **LIVE AAA FECHADO** · headless **LIMPO** · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid=**OFF** · P1b hairline **pending** · Sem Git.

## 0. Comportamento APPROVED (nao negociar no refactor)
| Regra | Fonte |
|---|---|
| CONTINUAR / Retomar **default focado** no open | playbook §4 / UX |
| SAIR PARA O TITULO = **destructive** (peso tipografico/tinta; modal = P1) | §4 |
| `OpcoesLista` = **fonte unica** `video()`/`audio()` | §3 |
| Hit pauzinhos / atalho aba **≥32×32** | A11y §11 + SPEC_A11Y_RE7 |
| Hover mouse = mesmo focus (stain/barra/`>` ou equivalente RE7) | §4 / A11y |
| Titulo pause-root sistema = **SISTEMA** (nunca OPCOES) na folha legado | §4 |
| HARD: sem Git; evitar Casa da Fumaca | épico |

## 0.1 Status ondas (Jamerson · 19/09/2026)

| Onda | Status | Owner |
|---|---|---|
| 1 Overlay | **ACEITE CONDICIONAL** PO2 | Godot UI Dev (feito) |
| 1b Tipografia sans | **APPROVED** | Godot UI Dev |
| POLISH_TIPO_LAYOUT / P0 C | **PASS** | FONTE_P resolvido · Theme tokens PASS |
| POLISH_AUDIO_UI / P0 D | **PASS** | Código OK · hooks AudioDirector fechados · playtest **HOLD** até GO Godot |
| POLISH_CONTROLES_RE7 / P0 E | **PASS** | Slider PASS · StyleBox panel follow-up opcional (Jamerson) · playtest HOLD |
| POLISH_PANEL_MOTION_RE7 / P0 F | **PASS** | `style_re7_panel` + focus Tween · playtest HOLD · NO_GODOT |
| 2 Grid + DnD | **APPROVED** (cena paralela) | **PSX Grid Inventory** · cutover **CANCELADO/ADIADO** |
| 3 Inspeção + Vitals | **MODULES=PASS** · **WIRE=PASS** | **PSX Diegetic 3D** · wire **PASS** |
| 4 Opções/Save/Áudio | **SAVE_CARDS_PREP=PASS** · wire **PASS** | **Save Cards** + **Audio UI** |
| O4 SAVE ÁUDIO | **PASS** | Código PASS · playtest HOLD · Audio UI |
| A11Y_FOCUS_STACK / P0 G | **PASS** | Path live · cutover grid **HOLD** · NO_GODOT |
| menu.gd CARREGAR | **PASS** | Limpeza legado PASS · NO_GODOT |
| P1 MenuSistema nested | **PASS** | Nested com `push_menu` PASS · NO_GODOT |
| P0 H TIPOGRAFIA_MENU_GD / FONTE_RE7_MENU_TITULO | **PASS** | Tipografia `menu.gd` PASS |
| P0 I TIPOGRAFIA_CRIACAO | **PASS** | Tipografia RE7 criacao+ficha_cadastro · NO_GODOT |
| P0 J INSPECT_ORBIT_DAMP | **PASS** | Owner Diegetic 3D · damp órbita · NO_GODOT |
| P0 K DOCUMENTO_RE7 / TIPOGRAFIA_DOCUMENTO | **PASS** | Tipografia documento RE7 PASS · NO_GODOT |
| P0 L AUDIO_STEMS_UI | **PASS** | Código PASS · art/assets stems canônicos pending |
| P1b hairline | **pending** | Pós LIVE AAA · grid OFF |

Canal: **PSX RE7 Epic**. Briefs: _linkar quando PO1 gravar_.

## 1. Arvore atual (baseline legado — Onda papel 1+1.5 APPROVED)

| Superficie | Script | Layer / abrir | Arvore mental (hoje) | Look |
|---|---|---|---|---|
| Boot / Titulo / Opcoes | `menu.gd` | ~150 · boot→titulo | placas titulo; OPCOES → OpcoesLista | CRT/pixel + papel |
| Prancha pause/inv | `prancha_inventario.gd` | 110 · ESC/TAB | faixa itens **horizontal**; polaroid/status; dona MenuSistema | scrapbook papel |
| Sistema pauzinhos | `menu_sistema.gd` | aba 160 · W/chip | folha RAIZ→VIDEO/AUDIO/CARREGAR; draw + chip | papel SISTEMA |
| Opcoes (dados) | `opcoes_lista.gd` | — | listas video/audio | SOM ainda `####` |
| Tokens | `ui_estilo.gd` | — | TELA 480×270; `psx_*`; `T_MENU_*` | bitmap |
| Persistencia | `settings.gd` | — | imagem/audio | — |
| Orquestracao | `cidade.gd` | — | `--ver-*`; wiring `pediu_*` **DONE** | — |

**Onda 1 no disco (PO2 · 19/09/2026) — ACEITE CONDICIONAL:** UIManager + shader + wire + `re7_dev/onda1_*.png` = **PRESENTES**.
**Onda 1b:** tipografia sans **APPROVED**.

**Ainda ausente (ondas 2–4):** GridContainer inventario, SubViewport inspecao, vitals LED, save thumbnails.

Caps legado: `captures/ui/aaa_dev/`, `captures/ui/f4_*`, `captures/menu/*`.

## 2. Alvo por onda (épico)

### Onda 1 — Fundacao (**ACEITE CONDICIONAL** PO2)
| Atual | Alvo |
|---|---|
| Abrir prancha/sistema direto | Autoload `UIManager` pilha `push_menu` / `pop_menu` |
| Sem filtro de mundo | ColorRect + `ui_menu_overlay.gdshader` (DoF, sat -40%, CA, lens dirt) |
| Pixel font menus | Sans moderna (menus novos) |
| Specs | `SPEC_VISUAL_RE7` · `SPEC_MOTION_RE7` (`T_RE7_OPEN/CLOSE`) **APPROVED** |
| Tipografia sans | **PENDENTE** — prancha ainda `psx_*.fnt` |
| Caps | `captures/ui/re7_dev/onda1_*.png` **presentes** |

### Onda 1b — Tipografia sans (**APPROVED**)
| Atual | Alvo |
|---|---|
| `psx_*.fnt` na prancha/menus | Sans moderna nos menus novos |
| Brief | _link quando PO1 gravar_ |

### POLISH_TIPO_LAYOUT / P0 C (**PASS** · FONTE_P resolvido)
Spec: `docs/specs/SPEC_POLISH_TIPO_LAYOUT_RE7.md` (**APPROVED**). Checklist: `docs/specs/CHECKLIST_TOKENS_UIESTILO_RE7.md` (UiEstilo RE7_SAFE/DOC_INK/TRACK/StyleBox). Tipografia+layout na prancha legado; O3 continua; cutover grid adiado.

### POLISH_AUDIO_UI / P0 D (**PASS** · playtest HOLD até GO Godot)
Código **PASS**; hooks AudioDirector fechados; playtest **HOLD** até GO Godot. Specs AUDIO RE7.

### POLISH_CONTROLES_RE7 / P0 E (**PASS**)
- **Escopo:** `OpcoesLista` pele RE7 — trilha/fill (slider); **zero** blocos ASCII (`####`)
- StyleBox panel onde há `Control`
- **Tokens:** `docs/specs/TOKENS_SLIDER_RE7.md` · § slider checklist
- O4 SAVE WIRE **PASS** · **playtest HOLD** · **NO_GODOT** / sem Git · P0 C/D **PASS**
- **Follow-up opcional:** StyleBox panel — **pendente decisão Jamerson** (não bloqueia P0 E PASS)

### POLISH_PANEL_MOTION_RE7 / P0 F (**PASS**)
- **Escopo:** consumer de `style_re7_panel` + focus Tween
- **Baseline:** P0 C/D/E **PASS** · O4 SAVE WIRE **PASS** · playtest **HOLD** · **NO_GODOT**

### Onda 2 — Inventario Grid (**APPROVED** · cena paralela · cutover CANCELADO/ADIADO)
| Atual | Alvo |
|---|---|
| HBox / faixa horizontal | Grid multi-slot (1×2, 2×2, N×M) + Drag&Drop |
| Polaroid scrapbook | Paineis translucidos RE7 (Visual) |
| Focus lista | `focus_neighbor_*` espacial (SPEC_A11Y_RE7) |
| Specs | Visual + Motion (`T_RE7_GRID_STAGGER`) + A11y **APPROVED** |

### Onda 3 — Inspecao + Vitals (**MODULES=PASS** · **WIRE=PASS**)
WIRE=**PASS**. HARD STOP aceites sem captura.
| Atual | Alvo |
|---|---|
| Examine 2D / polaroid | SubViewport 3D + orbita |
| Status texto/polaroid | Vitals diegeticos (LED/emission) |
| Specs | Visual RE7 · Motion RE7 |

### Onda 4 — Opcoes / Save / Audio (**SAVE_CARDS_PREP=PASS** · wire **PASS**)
Ressalva: falta `PainelRe7`/`style_re7_panel` (P0 F). Playtest HOLD · NO_GODOT.
| Atual | Alvo |
|---|---|
| Folha papel + `####` | Margin/VBox; save cards + thumbnail |
| SFX UI generico | Foley organico + drone + duck mundo |
| OpcoesLista | **Continua fonte unica** (so muda a pele) |
| Save Cards PREP | **PASS** · wire **PASS** · `save_card.gd/.tscn` · `save_panel.gd/.tscn` · `save_thumb_capture.gd` · `re7_save_cards_demo.tscn` · `SPEC_SAVE_CARDS_RE7.md` |

### O4 SAVE ÁUDIO / áudio save hooks (**PASS** · playtest HOLD)
- **PASS** (código) · Hooks save (ex. `ui_save_slot`) · owner **PSX Audio UI**
- Playtest **HOLD** · **NO_GODOT**

### A11Y_FOCUS_STACK / P0 G (**PASS** · path live)
- **A11y reaudit:** P0 G = **PASS** (confirmado)
- **P1:** `MenuSistema` nested `push_menu` = **PASS**
- Status: **PASS** (path live)
- Cutover grid = **HOLD** (fora do DoD / não desbloqueado)
- Focus stack FILO / restore (A11y)
- **O4 SAVE ÁUDIO** = **PASS** (código; playtest HOLD)
- **menu.gd CARREGAR** = **PASS**
- **NO_GODOT** / playtest HOLD


## 3. O que REUSAR da Onda 1 AAA (papel)
- Wiring `pediu_titulo` / `pediu_carregar` em `cidade.gd`
- Contrato focus: default CONTINUAR, SAIR destructive, hover=focus
- Hit ≥32 na aba; footer alinhado a SISTEMA (`[W] sistema`)
- `OpcoesLista` + `Settings` sem duplicar listas
- Timings de banda ≤250 ms input lock (adaptar easing → `TRANS_EXPO` / `T_RE7_*`)
- Caps `aaa_dev/` como **baseline visual a matar**, nao como meta

**Nao reusar como meta:** pixel font, papel `#e6dfc4` como identidade, filmstrip HBox, SOM `####`, polaroid como vitals.

## 4. Gap vs DoD do épico

**Onda 1 overlay — ACEITE CONDICIONAL (PO2).** **Onda 1b — APPROVED.** Onda 2 **APPROVED** (paralela). O4 SAVE WIRE **PASS**.

| DoD (alto nivel) | Estado |
|---|---|
| UIManager stack | **PRESENTE** |
| Shader overlay (`ui_menu_overlay.gdshader`) | **PRESENTE** |
| Wire prancha + menu_sistema → UIManager | **PRESENTE** |
| Prints `captures/ui/re7_dev/onda1_*.png` | **PRESENTES** |
| Tipografia sans aplicada nos menus | **APPROVED — Onda 1b** |
| Grid inventario + DnD | **APPROVED** (Onda 2 cena paralela) · cutover **CANCELADO/ADIADO** |
| Vitals diegeticos + inspecao 3D full | **MODULES=PASS** · **WIRE=PASS** (código) |
| Save thumbs + foley/drone/duck | Save PREP **PASS** · wire **PASS** · foley/drone ainda PREP/IMPLEMENTING |
| Headless `--quit` limpo | manter a cada onda |
| Comportamento APPROVED (§0) | **preservar** |

## Audio hooks (Onda 4 · PSX Audio UI)

Fonte: `docs/specs/SPEC_AUDIO_UI_RE7.md` + `docs/specs/ASSETS_AUDIO_UI_RE7.md` (**PREP** Onda 4) — **não** duplicar listas de volume (`OpcoesLista.audio()` / `Settings.BUSES`).

### Hooks canônicos (SFX lógicos)
| Hook | Uso típico |
|---|---|
| `ui_nav` / `ui_focus` / `ui_move` | Navegação / mudança de focus |
| `ui_confirm` / `ui_accept` | Confirmar / selecionar |
| `ui_back` / `ui_cancel` | Voltar / cancelar / pop |
| `ui_deny` | Ação inválida / ITEM_MORTO |
| `ui_page` | Troca de página/painel |
| `ui_open` / `ui_close` | Abrir/fechar overlay ou painel |
| `ui_adjust` | Slider / ajuste (hot-apply Settings) |
| `ui_save_slot` | Interação com save card |
| `ui_drag_start` / `ui_drop` | DnD inventário (Onda 2+) |
| `ui_inspect_open` / `ui_inspect_tick` | Inspeção 3D (Onda 3) |
| `ui_destructive` | SAIR / ação destrutiva |

### Duck / ambiência
- **Gancho:** `UIManager` `push_menu` / `pop_menu` (depth da pilha) → duck do mundo + drone low.
- Foley orgânico (couro/metal) nos confirms/opens — ver SPEC_AUDIO.

### Superfícies que disparam hooks
`prancha_inventario` · `menu_sistema` · `menu.gd` · grid (O2) · inspeção (O3) · save panels (O4).

## Equipe / owners (canal `PSX RE7 Epic`)
| Papel | Agente | Onda |
|---|---|---|
| PO1 | PSX Project Owner | coordenação + briefs |
| PO2 | New Bot | validação AAA/RE7 + backlog |
| Fundação / UI geral | PSX Godot UI Dev | Onda 1 (+ suporte) |
| Grid Inventory | PSX Grid Inventory | **Onda 2** |
| Diegetic 3D | PSX Diegetic 3D | **O3 MODULES=PASS** · **WIRE=PASS** |
| Audio UI | PSX Audio UI | **Onda 4** |
| Docs | PSX Docs Lead | playbook / inventário / links |
| Theme Tokens | PSX Theme Tokens | POLISH_TIPO tokens **PASS** |
| Save Cards | PSX Save Cards | O4 SAVE_CARDS_PREP=**PASS** · wire **PASS** |
| Tipografia sans | Godot UI Dev | **Onda 1b APPROVED** |

## 5. Mapa de specs
Ver tabela em `docs/EPICO_UI_RE7.md` § Specs.

## 6. Changelog
- 19/09/2026 — criado a pedido PO2 (New Bot); espelha épico RE7.
- 19/09/2026 — §4 atualizado (PO2): UIManager/shader/wire/prints Onda 1 presentes; sans ainda pendente.
- 19/09/2026 — gap §4: Onda 1 overlay ACEITE CONDICIONAL PO2; dívida 1b = sans; O2–O4 faltando.
- 19/09/2026 — Jamerson: Onda 1 ACEITE CONDICIONAL; 1b OPEN; Onda 2 BRIEFED. Briefs TBD PO1.
- 19/09/2026 — owners: Grid Inventory (O2), Diegetic 3D (O3), Audio UI (O4); canal PSX RE7 Epic.
- 19/09/2026 — ## Audio hooks + link SPEC_AUDIO_UI_RE7 (pedido Audio UI).
- 19/09/2026 — PO2: Onda 1b PASS/FECHADA; Onda 2 IMPLEMENTING.
- **Onda 2 FULL PASS (19/09/2026):** FECHADA PASS (paralela); cutover CANCELADO/ADIADO; O3 PREP aprovado. Fonte PO2.
- **Onda 2 APPROVED paralela (19/09/2026):** PO1 — cutover prancha pending Jamerson.
- **Onda 3 GO isolado (19/09/2026):** Jamerson — O3 IMPLEMENTING sem cutover prancha; cutover **CANCELADO/ADIADO**. Fonte PO2.
- **Decisão Jamerson Onda 3 (19/09/2026):** IMPLEMENTING on top do legado (inspect+vitals); cutover grid **CANCELADO/ADIADO**; O2 PASS permanece cena paralela. Fontes PO1+PO2.
- **Correção Onda 3 (19/09/2026):** IMPLEMENTING **incremental na prancha** (inspect+vitals plugados); demo isolada = apoio; cutover grid bloqueado. Fonte PO2.
- **POLISH_TIPO_LAYOUT (19/09/2026):** IMPLEMENTING on-top legado (P0); O3 continua; cutover grid adiado. Fonte PO2.
- **POLISH_AUDIO_UI (19/09/2026):** IMPLEMENTING P0 on-top (foley nav/confirm + duck/drone leve); com POLISH_TIPO_LAYOUT; O3 paralelo; cutover grid adiado. Fonte PO2 (Jamerson C+D).
- **SPEC_POLISH_TIPO_LAYOUT_RE7 APPROVED (19/09/2026):** PO2 — link P0; POLISH_AUDIO_UI=IMPLEMENTING. Sem código.
- **NO_GODOT_RUNTIME (19/09/2026):** standing order PO2 — sem shot/runtime enquanto Jamerson joga; Dev on-top legado. Owners: Theme Tokens (P0 tipo), Save Cards (prep O4).
- **O3 MODULES PASS / WIRE IMPLEMENTING (19/09/2026):** *(superseded — WIRE agora PAUSED)* demo isolada PASS. Fonte PO2.
- **CHECKLIST_TOKENS_UIESTILO_RE7 (19/09/2026):** linkado; tokens UiEstilo no disco. Fonte Theme Tokens.
- **O3 WIRE PAUSED (19/09/2026):** MODULES=PASS ok; WIRE pausado até P0 tipo/layout. Ordem: Theme Tokens → UI Dev tipo → Diegetic wire. Cutover grid adiado. Fonte PO2.
- **Theme Tokens P0 PASS (19/09/2026):** tokens PASS; POLISH_TIPO_LAYOUT=IMPLEMENTING (UI Dev re-aplicando prancha/sistema). O3 WIRE continua PAUSED. Fonte PO2.
- **Save Cards PREP (19/09/2026):** mirror `re7_dev/onda4_prep/` + specs. Fonte Save Cards.
- **O4 SAVE_CARDS_PREP PASS (19/09/2026):** PREP isolado PASS; wire pending GO. Fonte PO2.
- **O4 Save Cards PREP APPROVED (19/09/2026):** isolado APPROVED; wire pending GO. Fonte PO1.
- **Save Cards paths canônicos (19/09/2026):** `game/src/ui/re7/save_card.gd/.tscn` · `save_panel.gd/.tscn` · `save_thumb_capture.gd` (+ demo); mirror `psx-menus/re7_dev/onda4_prep/`. Fonte Save Cards / PO1.
- **P0 C PASS c/ ressalva + O3 WIRE GO (19/09/2026):** P0 C (tipo/layout)=**PASS** (`menu_sistema` ainda `FONTE_P`); O3 WIRE=**PASS** (código); Save Cards PREP=**PASS**. Fonte PO2.
- **Save Cards paths curtos + PREP APPROVED (19/09/2026):** canônico `save_card`/`save_panel`/`save_thumb_capture` (sem `_re7` no filename); class_name *Re7 ok. O4 PREP=**APPROVED** isolado · wire pending GO. Fontes Save Cards + PO1.
- **P0 D áudio PASS c/ ressalva (19/09/2026):** código OK; hooks prancha pending; playtest quando Godot liberar. Fonte PO2.
- **P0 C PASS (19/09/2026):** FONTE_P resolvido — P0 C=**PASS** (sem ressalva). O3 WIRE=PASS · P0 D=PASS COM RESSALVA. Fonte PO2.
- **O3 WIRE PASS (19/09/2026):** O3 WIRE=**PASS** · P0 C=PASS · P0 D=PASS COM RESSALVA · Save Cards PREP=PASS · NO_GODOT. Fonte PO2.
- **O4 wire HOLD (19/09/2026):** O3 WIRE=PASS confirmado; O4 SAVE WIRE=**PASS**; P0 C PASS · P0 D PASS COM RESSALVA · Save Cards PREP PASS · NO_GODOT. Fonte PO2.
- **P0 D PASS (19/09/2026):** código PASS; ressalva prancha fechada (hooks AudioDirector). Playtest=**HOLD** até GO Godot. P0 C PASS · O3 WIRE PASS · O4 Save PREP PASS · O4 wire HOLD. Fonte PO2.
- **P0 D PASS confirmado (19/09/2026):** sem ressalva; hooks prancha fechados. Snapshot: O3 WIRE PASS · P0 C PASS · Save PREP PASS · O4 wire HOLD · NO_GODOT. Fonte PO2.
- **P0 E POLISH_CONTROLES_RE7 (19/09/2026):** IMPLEMENTING — OpcoesLista slider (matar ASCII) + StyleBox panel. O4 wire HOLD · NO_GODOT · P0 C/D PASS. Fonte PO2.
- **P0 E escopo PO1 (19/09/2026):** OpcoesLista pele RE7 (trilha/fill) · zero ASCII; O4 save wire HOLD · playtest HOLD · sem Godot/Git. Fonte PO1.
- **TOKENS_SLIDER_RE7 (19/09/2026):** linkado P0 E — `docs/specs/TOKENS_SLIDER_RE7.md` + § slider em `CHECKLIST_TOKENS_UIESTILO_RE7.md`. Fonte Theme Tokens.
- **P0 E PASS (19/09/2026):** P0 E=**PASS**. Snapshot: P0 C PASS · P0 D PASS · O3 WIRE PASS · P0 E PASS · Save PREP PASS · O4 wire HOLD · playtest HOLD · NO_GODOT. Fonte PO2.
- **P0 E PASS + follow-up (19/09/2026):** P0 E=PASS (PO1). O4 save wire HOLD · playtest HOLD. Follow-up opcional StyleBox panel — pendente decisão Jamerson. Fonte PO1.
- **P0 F POLISH_PANEL_MOTION_RE7 (19/09/2026):** IMPLEMENTING — style_re7_panel consumer + focus Tween. P0 C/D/E PASS · O4 wire HOLD · NO_GODOT. Fonte PO2.
- **O4 SAVE WIRE IMPLEMENTING + loop AAA ON (19/09/2026):** O4 save wire=**IMPLEMENTING** (código-only). P0 F IMPLEMENTING. Playtest HOLD · NO_GODOT. Loop autônomo AAA ON. Fonte PO2.
- **Standing loop contínuo (19/09/2026):** Jamerson — PO2 despacha sem esperar GO. O4 SAVE WIRE IMPLEMENTING (código) · P0 F segue · playtest HOLD. Fonte PO1.
- **Inventário corrigido O4 SAVE WIRE (19/09/2026):** O4 SAVE WIRE=IMPLEMENTING (código-only) · P0 F IMPLEMENTING · P0 C/D/E PASS · playtest HOLD · NO_GODOT. Fonte PO2.
- **P0 F PASS (19/09/2026):** P0 F=**PASS**. Snapshot: C/D/E/F PASS · O3 WIRE PASS · O4 SAVE WIRE IMPLEMENTING · Save PREP PASS · playtest HOLD · NO_GODOT. Fonte PO2.
- **O4 SAVE WIRE PASS COM RESSALVA (19/09/2026):** wire OK; falta restaurar `PainelRe7`/`style_re7_panel` (P0 F). Playtest HOLD · NO_GODOT. Fonte PO2.
- **O4 SAVE WIRE PASS (19/09/2026):** ressalva PainelRe7 **fechada** — O4 SAVE WIRE=**PASS**. P0 C/D/E/F PASS · O3 WIRE PASS · playtest HOLD · NO_GODOT. Fonte PO2.
- **O4 SAVE WIRE PASS limpo + áudio save hooks (19/09/2026):** O4 SAVE WIRE=**PASS** limpo. Snapshot C/D/E/F + O3 + O4 PASS. Próximo: **áudio save hooks=IMPLEMENTING**. Playtest HOLD. Fonte PO1.
- **Áudio save hooks no disco (19/09/2026):** código no disco → **review PO2** (ainda **não PASS**). Fonte PO1.
- **O4 SAVE ÁUDIO PASS (19/09/2026):** código PASS · playtest HOLD. Snapshot: P0 C–F PASS · O3 WIRE PASS · O4 WIRE PASS · O4 áudio PASS · NO_GODOT. Fonte PO2.
- **P0 G A11Y_FOCUS_STACK (19/09/2026):** IMPLEMENTING. O4 SAVE ÁUDIO PASS. menu.gd CARREGAR = depois. NO_GODOT. Fontes PO1+PO2.
- **Próximo menu.gd CARREGAR (19/09/2026):** PO1 — limpar CARREGAR legado em `menu.gd` = próximo. P0 G A11Y_FOCUS_STACK=IMPLEMENTING. O4 SAVE ÁUDIO=PASS. Playtest HOLD. Fontes PO1+PO2.
- **menu.gd CARREGAR=depois (19/09/2026):** PO1 — P0 G A11Y_FOCUS_STACK=IMPLEMENTING; menu.gd CARREGAR=depois; O4 áudio PASS; playtest HOLD. Fonte PO1.
- **Fila agora (19/09/2026):** **agora** = P0 G A11Y_FOCUS_STACK (IMPLEMENTING). `menu.gd` CARREGAR = **depois do PASS do P0 G** — não é o próximo imediato. Fonte PO1.
- **P0 G audit FAIL→IMPLEMENTING (19/09/2026):** status FAIL→IMPLEMENTING (audit). Cutover grid **não** entra no DoD desta fatia. Fonte PO2.
- **P0 G PASS (19/09/2026):** P0 G A11Y_FOCUS_STACK=**PASS** (path live; cutover grid HOLD). Próximo: `menu.gd` CARREGAR. NO_GODOT. Fonte PO2.
- **A11y reaudit P0 G + backlog P1 (19/09/2026):** A11y reaudit P0 G=**PASS**. Backlog P1: `MenuSistema` nested sem `push_menu`. Fonte PO2.
- **menu.gd CARREGAR PASS (19/09/2026):** CARREGAR=**PASS**. Próximo/agora: P1 `MenuSistema` nested `push_menu`. NO_GODOT. Fonte PO2.
- **P1 MenuSistema nested PASS (19/09/2026):** P1 nested `push_menu`=**PASS**. NO_GODOT · playtest HOLD. Fonte PO2.
- **P0 H TIPOGRAFIA/FONTE_RE7 (19/09/2026):** IMPLEMENTING — aliases `FONTE_RE7_MENU_TITULO` + `TIPOGRAFIA_MENU_GD` (`menu.gd`). P1 nested=PASS. Playtest HOLD · NO_GODOT. Fontes PO1+PO2.
- **P0 H PASS COM RESSALVA (19/09/2026):** tipografia menu OK; hotfix `run_tests.gd` pending. Fonte PO2.
- **P0 H PASS (19/09/2026):** P0 H TIPOGRAFIA_MENU_GD=**PASS**. Snapshot: C–H + O3/O4 + P1 PASS · playtest HOLD · grid HOLD · NO_GODOT. Fonte PO2.
### P0 I TIPOGRAFIA_CRIACAO (**PASS**)
Tipografia RE7 em `criacao` + `ficha_cadastro` = **PASS**. Playtest HOLD · NO_GODOT.

### P0 J INSPECT_ORBIT_DAMP (**PASS**)
Diegetic — damp órbita inspeção. Playtest HOLD · NO_GODOT.

- **P0 I + P0 J abertos (19/09/2026):** P0 H=**PASS** limpo. P0 I TIPOGRAFIA_CRIACAO=**PASS** (criacao+ficha_cadastro). P0 J INSPECT_ORBIT_DAMP=**IMPLEMENTING** (Diegetic). Playtest HOLD. Fontes PO1+PO2.
- **P0 I+J paralelo confirmado (19/09/2026):** P0 I TIPOGRAFIA_CRIACAO + P0 J INSPECT_ORBIT_DAMP **IMPLEMENTING em paralelo**. P0 H PASS ok. Fontes PO1+PO2.
- **P0 J PASS (19/09/2026):** P0 J INSPECT_ORBIT_DAMP=**PASS**. P0 I TIPOGRAFIA_CRIACAO ainda **IMPLEMENTING**. Fonte PO2.
- **P0 I PASS (19/09/2026):** P0 I TIPOGRAFIA_CRIACAO=**PASS** · P0 J=**PASS**. Playtest HOLD · NO_GODOT. Fonte PO2.
- **P0 K DOCUMENTO_RE7 (19/09/2026):** IMPLEMENTING (alias TIPOGRAFIA_DOCUMENTO). P0 I TIPOGRAFIA_CRIACAO=**PASS** · P0 J=**PASS**. Snapshot C–J+O3/O4+P1 PASS. Playtest HOLD. Fontes PO1+PO2.

### P0 K DOCUMENTO_RE7 / TIPOGRAFIA_DOCUMENTO (**PASS**)
Tipografia documento RE7 = **PASS**. Playtest HOLD · grid HOLD · NO_GODOT.
- **P0 K PASS (19/09/2026):** P0 K DOCUMENTO_RE7=**PASS**. Snapshot C–K + O3/O4 + P1 PASS · playtest HOLD · grid HOLD · NO_GODOT. Fonte PO2.
- **MENU AAA CÓDIGO-COMPLETE (19/09/2026):** P0 C–K + O3/O4 + P1 + P0 L (código)=**PASS**. Playtest HOLD até GO Godot. Backlog parked: UI mundo + grid cutover; assets stems pending. Fontes PO1+PO2.
- **P0 L AUDIO_STEMS_UI PASS (19/09/2026):** P0 L=**PASS** (código; assets canônicos pending). Time standby · NO_GODOT. Fontes PO1+PO2.

### P0 L AUDIO_STEMS_UI (**PASS** · código; assets pending)
- Stems UI código = **PASS** (art/assets stems canônicos **pending**)
- **MENU AAA CÓDIGO-COMPLETE** (C–K + O3/O4 + P1 + L código)
- Playtest **HOLD** até GO Godot · time **standby** · **NO_GODOT**
- Backlog parked: UI mundo + grid cutover · assets stems pending
- **Godot headless LIMPO + playtest LIVE (19/09/2026):** Godot headless **LIMPO**. Live playtest AAA **em curso** (PO2). Grid **OFF**. Sem Git. Fonte PO1.
- **LIVE AAA FECHADO (19/09/2026):** Headless limpo · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid **OFF** · P1b hairline **pending**. Fonte PO1.

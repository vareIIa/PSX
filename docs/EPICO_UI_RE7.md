# ÉPICO UI RE7 — Survival Horror AAA (Godot 4.x)

Status: **MENU AAA CÓDIGO-COMPLETE** · **LIVE AAA FECHADO** · Godot headless **LIMPO** · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid=**OFF** · P1b hairline **pending** · Sem Git
PO: PSX Project Owner · Baseline legado: prancha papel + SOM ####

## Norte

### HARD STOP Godot (aceitação)
**LIVE AAA FECHADO.** Headless **LIMPO** · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid **OFF** · P1b hairline **pending**. Sem Git.

Refatorar UI placeholder Retro/PS1 → overlay diegético estilo Resident Evil 7.
Mundo 3D continua no fundo; menu é filtro sujo + tipografia moderna + grid espacial.

## Ondas / status (Jamerson · 19/09/2026)

| Onda | Status | Notas |
|---|---|---|
| **1** Fundação overlay | **ACEITE CONDICIONAL** (PO2) | UIManager + shader + wire + `re7_dev/onda1_*` presentes |
| **1b** Tipografia sans | **APPROVED** | PO2 · sans aplicada |
| **POLISH_TIPO_LAYOUT** / P0 C | **PASS** | FONTE_P resolvido · Theme tokens PASS |
| **POLISH_AUDIO_UI** / P0 D | **PASS** | Código OK · hooks AudioDirector fechados · playtest **HOLD** até GO Godot |
| **POLISH_CONTROLES_RE7** / P0 E | **PASS** | Slider/trilha PASS · StyleBox panel = follow-up opcional (Jamerson) · O4 wire/playtest HOLD |
| **POLISH_PANEL_MOTION_RE7** / P0 F | **PASS** | `style_re7_panel` consumer + focus Tween · NO_GODOT |
| **2** Inventário Grid + DnD | **APPROVED** (cena **paralela**) | **Owner: PSX Grid Inventory** · cutover **CANCELADO/ADIADO** |
| **3** Inspeção + Vitals | **MODULES=PASS** · **WIRE=PASS** | **Owner: PSX Diegetic 3D** · wire **PASS** |
| **4** Opções / Save / Áudio | **SAVE_CARDS_PREP=PASS** · wire **PASS** | **Save Cards** + **Audio UI** |
| **O4 SAVE ÁUDIO** | **PASS** | Código PASS · playtest HOLD · owner Audio UI |
| **A11Y_FOCUS_STACK** / P0 G | **PASS** | Path live · cutover grid **HOLD** · NO_GODOT |
| **menu.gd CARREGAR** | **PASS** | Limpeza legado PASS · NO_GODOT |
| **P1 MenuSistema nested** | **PASS** | Nested com `push_menu` PASS · NO_GODOT |
| **P0 H TIPOGRAFIA_MENU_GD** / FONTE_RE7_MENU_TITULO | **PASS** | Tipografia `menu.gd` PASS · NO_GODOT |
| **P0 I TIPOGRAFIA_CRIACAO** | **PASS** | Tipografia RE7 criacao+ficha_cadastro · NO_GODOT |
| **P0 J INSPECT_ORBIT_DAMP** | **PASS** | Owner Diegetic 3D · damp órbita · NO_GODOT |
| **P0 K DOCUMENTO_RE7** / TIPOGRAFIA_DOCUMENTO | **PASS** | Tipografia documento RE7 · NO_GODOT |
| **P0 L AUDIO_STEMS_UI** | **PASS** | Código PASS · art/assets stems canônicos pending |
| **P1b hairline** | **pending** | Pós LIVE AAA · grid OFF |

### Standing order — loop contínuo (Jamerson)
**MENU AAA CÓDIGO-COMPLETE.** **LIVE AAA FECHADO.** Headless **LIMPO** · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid **OFF** · P1b hairline **pending**. Sem Git.


### Onda 1 — Fundação
- Autoload `UIManager.gd` (pilha push_menu/pop_menu) — **no disco**
- Shader `ui_menu_overlay.gdshader` — **no disco**
- ColorRect full-screen + wire prancha/menu_sistema — **no disco**
- Prints `captures/ui/re7_dev/onda1_*.png` — **presentes**
- Specs: `SPEC_VISUAL_RE7.md` · `SPEC_MOTION_RE7.md` **APPROVED**
- Tipografia sans → **Onda 1b APPROVED**

### Onda 1b — Tipografia (**APPROVED**)
- Aplicar sans moderna nos menus novos (matar `psx_*.fnt` na prancha/overlay)
- Status: **APPROVED** (PO1/PO2) — sans nos menus novos

### POLISH_TIPO_LAYOUT / P0 C (**PASS** · FONTE_P resolvido)
- Tipografia + layout polish **em cima da prancha legado** (paralelo à Onda 3)
- **Spec:** `docs/specs/SPEC_POLISH_TIPO_LAYOUT_RE7.md` (**APPROVED**)
- **Checklist tokens:** `docs/specs/CHECKLIST_TOKENS_UIESTILO_RE7.md` (UiEstilo: RE7_SAFE/DOC_INK/TRACK/StyleBox + `aplicar_re7_*`)
- **Owner tokens:** PSX Theme Tokens (**PASS**)
- **Implementação prancha/sistema:** PSX Godot UI Dev (**IMPLEMENTING**)
- **NO_GODOT_RUNTIME** enquanto Jamerson joga
- Não desbloqueia cutover grid (continua **CANCELADO/ADIADO**)
- Onda 3 inspect+vitals **continua** IMPLEMENTING incremental na prancha

### POLISH_AUDIO_UI / P0 D (**PASS** · playtest HOLD até GO Godot)
- Fatia P0: foley **nav/confirm** + **duck/drone leve** na prancha/sistema legado
- Specs: `docs/specs/SPEC_AUDIO_UI_RE7.md` · `docs/specs/ASSETS_AUDIO_UI_RE7.md` (PREP → fatia P0 agora)
- Hooks: `INVENTARIO_MENUS_RE7` § Audio hooks · gancho duck via UIManager depth
- Não espera Onda 4 full; cutover grid **adiado**; O3 inspect+vitals **paralelo**

### POLISH_CONTROLES_RE7 / P0 E (**PASS**)
- **Escopo:** `OpcoesLista` pele RE7 — trilha/fill (slider); **zero** blocos ASCII (`####`)
- StyleBox panel onde há `Control`
- **Tokens:** `docs/specs/TOKENS_SLIDER_RE7.md` · § slider em `docs/specs/CHECKLIST_TOKENS_UIESTILO_RE7.md`
- **O4 save wire HOLD** · **playtest HOLD** · **NO_GODOT** / sem Git · P0 C/D **PASS**
- **Follow-up opcional:** StyleBox panel — **pendente decisão Jamerson** (não bloqueia P0 E PASS)

### POLISH_PANEL_MOTION_RE7 / P0 F (**PASS**)
- **Escopo:** consumer de `style_re7_panel` + focus Tween
- **Baseline:** P0 C/D/E **PASS** · O4 wire **HOLD** · **NO_GODOT**

### Onda 2 — Inventário Grid (**APPROVED** · cena paralela · cutover CANCELADO/ADIADO)
- **Cutover prancha legado → grid:** **CANCELADO/ADIADO** (Jamerson: Onda 3 on top do legado; O2 permanece cena paralela)
- Remover HBox horizontal legado (feature-flag / cena nova paralela)
- GridContainer multi-slot (1x2, 2x2) + Drag&Drop nativo
- Painéis translúcidos
- **Visual (APPROVED):** `docs/specs/SPEC_VISUAL_RE7.md`
- **Motion (APPROVED):** `docs/specs/SPEC_MOTION_RE7.md`
- **A11y (APPROVED):** `docs/specs/SPEC_A11Y_RE7.md`
- Brief Dev: _link quando PO1 gravar_

### Onda 3 — Inspeção + Vitals (**MODULES=PASS** · **WIRE=PASS**)

- **MODULES=PASS** — demo isolada (inspect+vitals) fechada
- **WIRE=PASS** — código on-top prancha (após P0 C)
- HARD STOP Godot permanece (aceites sem captura até GO Jamerson)
- Cutover **grid** permanece **CANCELADO/ADIADO**
- SubViewport + Camera3D + luz dramática; rotação mouse/analógico
- Monitor sinais vitais (emission Tween por HP) no lugar da polaroid
- Specs base: Visual RE7 · Motion RE7 (órbita / emission)
- **PREP Diegetic:**
  - Spec: `docs/specs/SPEC_INSPECT_VITALS_RE7.md`
  - Brief: `docs/briefs/ONDA3_DIEGETIC_PREP.md`

### Onda 4 — Opções / Save / Áudio (**SAVE_CARDS_PREP=PASS** · wire **PASS** limpo)
- O4 SAVE WIRE **PASS** limpo · Playtest **HOLD** · **NO_GODOT**
- Painéis Margin+VBox; save cards com thumbnail viewport
- Foley orgânico + drone low + duck mundo
- O4 SAVE ÁUDIO **PASS** (código; playtest HOLD)
- **SAVE_CARDS_PREP=PASS** · **wire PASS**:
  - Spec: `docs/specs/SPEC_SAVE_CARDS_RE7.md`
  - Brief: `docs/briefs/ONDA4_SAVE_CARDS_PREP.md`
  - Mirror: `psx-menus/re7_dev/onda4_prep/` (GO → `game/src/ui/re7/`)
  - Paths canônicos (filename **sem** `_re7`; `class_name` SaveCardRe7 / SaveCardsPanelRe7):
    - `game/src/ui/re7/save_card.gd` / `save_card.tscn`
    - `game/src/ui/re7/save_panel.gd` / `save_panel.tscn`
    - `game/src/ui/re7/save_thumb_capture.gd`
    - Demo: `game/scenes/ui/re7_save_cards_demo.tscn`
  - Spec: `docs/specs/SPEC_SAVE_CARDS_RE7.md`
  - Mirror box pode ter `*_re7` em `psx-menus/re7_dev/onda4_prep/`; disco PSX = nomes curtos
- **PREP Audio (sem código no game/ até GO pós-Onda 3):**
  - Spec: `docs/specs/SPEC_AUDIO_UI_RE7.md`
  - Assets: `docs/specs/ASSETS_AUDIO_UI_RE7.md`
  - Hooks: `INVENTARIO_MENUS_RE7` § Audio hooks


### O4 SAVE ÁUDIO / áudio save hooks (**PASS** · playtest HOLD)
- **PASS** (código) · Hooks save (ex. `ui_save_slot`) · owner **PSX Audio UI**
- Playtest **HOLD** · **NO_GODOT**

### A11Y_FOCUS_STACK / P0 G (**PASS** · path live)
- **A11y reaudit:** P0 G = **PASS** (confirmado)
- **P1:** `MenuSistema` nested `push_menu` = **PASS**
- Status: **PASS** (path live)
- Cutover grid = **HOLD** (fora do DoD / não desbloqueado)
- Focus stack FILO / restore (A11y) — **PASS**
- **O4 SAVE ÁUDIO** = **PASS**
- `menu.gd` CARREGAR = **PASS**
- P1 `MenuSistema` nested `push_menu` = **PASS**
- **NO_GODOT** / playtest HOLD

### menu.gd CARREGAR — limpeza legado (**PASS**)
- Limpeza CARREGAR legado = **PASS**
- P0 G = **PASS** · Playtest **HOLD** · **NO_GODOT**
- P1 `MenuSistema` nested `push_menu` = **PASS**


### P1 MenuSistema nested push_menu (**PASS**)
- Nested `MenuSistema` com `push_menu` = **PASS**
- Playtest **HOLD** · **NO_GODOT**


### P0 H TIPOGRAFIA_MENU_GD / FONTE_RE7_MENU_TITULO (**PASS**)
- Tipografia menu = **PASS**
- Aliases: `TIPOGRAFIA_MENU_GD` · `FONTE_RE7_MENU_TITULO`
- Playtest **HOLD** · grid **HOLD** · **NO_GODOT**

### P0 I TIPOGRAFIA_CRIACAO (**PASS**)
- Tipografia RE7 em `criacao` + `ficha_cadastro` = **PASS**
- Playtest **HOLD** · **NO_GODOT**

### P0 J INSPECT_ORBIT_DAMP (**PASS**)
- Owner **PSX Diegetic 3D** — damp órbita = **PASS**
- Playtest **HOLD** · **NO_GODOT**


### P0 K DOCUMENTO_RE7 / TIPOGRAFIA_DOCUMENTO (**PASS**)
- Tipografia documento RE7 = **PASS**
- Aliases: `DOCUMENTO_RE7` · `TIPOGRAFIA_DOCUMENTO`
- Playtest **HOLD** · grid **HOLD** · **NO_GODOT**


### P0 L AUDIO_STEMS_UI (**PASS** · código; assets pending)
- Stems UI código = **PASS** (art/assets stems canônicos **pending**)
- **MENU AAA CÓDIGO-COMPLETE** (C–K + O3/O4 + P1 + L código)
- Playtest **HOLD** até GO Godot · time **standby** · **NO_GODOT**
- Backlog parked: UI mundo + grid cutover · assets stems pending

## Aceite por onda
Scripts GDScript + árvore de nós + .gdshader + prints em captures/ui/re7_dev/

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

## Specs (APPROVED — link canônico)
| Spec | Escopo | Status |
|---|---|---|
| `docs/specs/SPEC_VISUAL_RE7.md` | Inventário/prancha/overlay RE7 | **APPROVED** |
| `docs/specs/SPEC_POLISH_TIPO_LAYOUT_RE7.md` | Polish tipo+layout P0 on-top | **APPROVED** |
| `docs/specs/CHECKLIST_TOKENS_UIESTILO_RE7.md` | Tokens UiEstilo RE7 (+ § slider) | Theme Tokens **PASS** |
| `docs/specs/TOKENS_SLIDER_RE7.md` | Slider track/fill/thumb RE7 | P0 E **PASS** |
| `docs/specs/SPEC_MOTION_RE7.md` | `T_RE7_*` grid/inspeção/overlay | **APPROVED** |
| `docs/specs/SPEC_A11Y_RE7.md` | Focus/hit/DnD grid + UIManager | **APPROVED** |
| `docs/specs/SPEC_INSPECT_VITALS_RE7.md` | Inspeção 3D + vitals | O3 MODULES **PASS** · WIRE **PASS** |
| `docs/briefs/ONDA3_DIEGETIC_PREP.md` | Brief Diegetic Onda 3 | O3 MODULES **PASS** · WIRE **PASS** |
| `docs/specs/SPEC_AUDIO_UI_RE7.md` | Foley/drone/duck + hooks SFX | **PREP** Onda 4 |
| `docs/specs/ASSETS_AUDIO_UI_RE7.md` | Lista stems / buses UI | **PREP** Onda 4 |
| `docs/specs/SPEC_SAVE_CARDS_RE7.md` | Save cards + thumbs RE7 | **PASS** (PREP) · wire **PASS** |
| `docs/briefs/ONDA4_SAVE_CARDS_PREP.md` | Brief Save Cards Onda 4 | **PASS** · wire **PASS** |
| `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` | Sistema/pauzinhos (`T_MENU_*`) | LOCKED (legado) |
| `docs/specs/SPEC_VISUAL_PAUZINHOS_FOLHAS.md` | Folha SISTEMA papel | LOCKED (legado) |
- **Onda 2 FULL PASS (19/09/2026):** FECHADA PASS (paralela); cutover CANCELADO/ADIADO; O3 PREP aprovado. Fonte PO2.
- **Onda 2 APPROVED paralela (19/09/2026):** PO1 — cutover prancha pending Jamerson.
- **Onda 3 GO isolado (19/09/2026):** Jamerson — O3 IMPLEMENTING sem cutover prancha; cutover **CANCELADO/ADIADO**. Fonte PO2.
- **Decisão Jamerson Onda 3 (19/09/2026):** IMPLEMENTING on top do legado (inspect+vitals); cutover grid **CANCELADO/ADIADO**; O2 PASS permanece cena paralela. Fontes PO1+PO2.
- **Correção Onda 3 (19/09/2026):** IMPLEMENTING **incremental na prancha** (inspect+vitals plugados); demo isolada = apoio; cutover grid bloqueado. Fonte PO2.
- **POLISH_TIPO_LAYOUT (19/09/2026):** IMPLEMENTING on-top legado (P0); O3 continua; cutover grid adiado. Fonte PO2.
- **POLISH_AUDIO_UI (19/09/2026):** IMPLEMENTING P0 on-top (foley nav/confirm + duck/drone leve); com POLISH_TIPO_LAYOUT; O3 paralelo; cutover grid adiado. Fonte PO2 (Jamerson C+D).
- **SPEC_POLISH_TIPO_LAYOUT_RE7 APPROVED (19/09/2026):** PO2 — link P0; POLISH_AUDIO_UI=IMPLEMENTING. Sem código.
- **NO_GODOT_RUNTIME (19/09/2026):** standing order PO2 — sem shot/runtime enquanto Jamerson joga; Dev on-top legado. Owners: Theme Tokens (P0 tipo), Save Cards (prep O4).
- **HARD STOP Godot (19/09/2026):** aceites sem captura runtime até GO. Fonte PO1.
- **O3 MODULES PASS / WIRE IMPLEMENTING (19/09/2026):** demo isolada PASS; próximo wire on-top prancha sem Godot runtime. Fonte PO2.
- **O3 WIRE PAUSED (19/09/2026):** MODULES=PASS ok; WIRE pausado até P0 tipo/layout. Ordem: Theme Tokens → UI Dev tipo → Diegetic wire. Cutover grid adiado. Fonte PO2.
- **Theme Tokens P0 PASS (19/09/2026):** tokens PASS; POLISH_TIPO_LAYOUT=IMPLEMENTING (UI Dev re-aplicando prancha/sistema). O3 WIRE continua PAUSED. Fonte PO2.
- **Save Cards PREP (19/09/2026):** specs + mirror `re7_dev/onda4_prep/` no disco. Fonte Save Cards.
- **Save Cards paths EPICO (19/09/2026):** Onda 4 PREP — SPEC_SAVE_CARDS_RE7 + `re7/save_*` (card/panel/thumb/demo). Fonte PO1.
- **O4 SAVE_CARDS_PREP PASS (19/09/2026):** PREP isolado PASS; wire pending GO. Fonte PO2.
- **O4 Save Cards PREP APPROVED (19/09/2026):** isolado APPROVED; wire pending GO. Fonte PO1.
- **Save Cards paths canônicos (19/09/2026):** `game/src/ui/re7/save_card.gd/.tscn` · `save_panel.gd/.tscn` · `save_thumb_capture.gd` (+ demo); mirror `psx-menus/re7_dev/onda4_prep/`. Fonte Save Cards / PO1.
- **P0 C PASS c/ ressalva + O3 WIRE GO (19/09/2026):** P0 C (tipo/layout)=**PASS COM RESSALVA** (`menu_sistema` ainda `FONTE_P`); O3 WIRE=**PASS** (código); Save Cards PREP=**PASS**. Fonte PO2.
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
- **P0 I + P0 J abertos (19/09/2026):** P0 H=**PASS** limpo. P0 I TIPOGRAFIA_CRIACAO=**PASS** (criacao+ficha_cadastro). P0 J INSPECT_ORBIT_DAMP=**IMPLEMENTING** (Diegetic). Playtest HOLD. Fontes PO1+PO2.
- **P0 J PASS (19/09/2026):** P0 J INSPECT_ORBIT_DAMP=**PASS**. P0 I TIPOGRAFIA_CRIACAO ainda **IMPLEMENTING**. Fonte PO2.
- **P0 I PASS (19/09/2026):** P0 I TIPOGRAFIA_CRIACAO=**PASS** · P0 J=**PASS**. Playtest HOLD · NO_GODOT. Fonte PO2.
- **P0 K DOCUMENTO_RE7 (19/09/2026):** IMPLEMENTING (alias TIPOGRAFIA_DOCUMENTO). P0 I TIPOGRAFIA_CRIACAO=**PASS** · P0 J=**PASS**. Snapshot C–J+O3/O4+P1 PASS. Playtest HOLD. Fontes PO1+PO2.
- **P0 K PASS (19/09/2026):** P0 K DOCUMENTO_RE7=**PASS**. Snapshot C–K + O3/O4 + P1 PASS · playtest HOLD · grid HOLD · NO_GODOT. Fonte PO2.
- **MENU AAA CÓDIGO-COMPLETE (19/09/2026):** P0 C–K + O3/O4 + P1 + P0 L (código)=**PASS**. Playtest HOLD até GO Godot. Backlog parked: UI mundo + grid cutover; assets stems pending. Fontes PO1+PO2.
- **P0 L AUDIO_STEMS_UI PASS (19/09/2026):** P0 L=**PASS** (código; assets canônicos pending). Time standby · NO_GODOT. Fontes PO1+PO2.
- **Godot headless LIMPO + playtest LIVE (19/09/2026):** Godot headless **LIMPO**. Live playtest AAA **em curso** (PO2). Grid **OFF**. Sem Git. Fonte PO1.
- **LIVE AAA FECHADO (19/09/2026):** Headless limpo · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid **OFF** · P1b hairline **pending**. Fonte PO1.

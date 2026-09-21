# REAUDIT_A11Y_FOCUS_STACK — P0 G after UI Dev PARTIAL PASS claim

**Ticket:** P0 G `A11Y_FOCUS_STACK`  
**Spec:** `docs/specs/SPEC_A11Y_RE7.md` · Baseline: `CHECKLIST_A11Y_FOCUS_STACK.md` (FAIL @ ~18:23 UYT)  
**Reauditoria:** 2026-09-19 ~18:35 UYT · **READ-ONLY** · sem código Godot alterado  
**Máquina:** `64365bfe-6c88-42fd-8a6c-50979e9f9aa5` · Root `C:\Users\Administrator\Documents\Codes\Games\PSX`  
**Escopo:** DoD §3.1 / §3.3 / §3.4 + Grid PREP only (cutover OFF). Motion / Visual / Git / wire live grid = OUT.

---

## 1. Verdict (scoped DoD)

| Campo | Valor |
|-------|--------|
| **Overall scoped** | **PASS** |
| Motivo | `UIManager` agora tem FILO de focus + deferred `grab_focus` + anti-null; `MenuStickGate` (deadzone 0.5 / cruz / 1 passo) wired em menu/prancha/grid PREP com consume; `HIT_LINHA_MIN`=32 + hits STOP na lista e na faixa legado; grid PREP tem `_ultimo_focus` + hover→focus e **não** está no path live. |
| vs claim UI Dev | Claim PARTIAL PASS → **upgrade para PASS** no escopo pedido. Itens fora de escopo (cutover grid live, nested sistema→FILO P1) **não** derrubam este veredito. |

**Nota PO1 (steering):** `PranchaInventario` **não** usa grade 2D `focus_neighbor_*` RE7 (clamp / coberta / multi-célula). Isso é **esperado com cutover OFF** → **OUT OF SCOPE / deferred**, **não** FAIL scoped. (Path legado ganhou neighbors de **lista** L/R nos `HitSlot*` — bônus, não substitui o grid.)

---

## 2. Table — was → now

| Item | Was (checklist FAIL) | Now | Evidence `file:line` | Status |
|------|----------------------|-----|------------------------|--------|
| §3.1 `push_menu` grava `gui_get_focus_owner` | Zero focus stack | `_focus_prev` FILO paralelo a `_stack`; captura owner antes do append | `ui_manager.gd:22-24`, `:100-103` | **PASS** |
| §3.1 deferred `grab_focus` default | Ausente | `call_deferred("_focar_menu")` → `foco_padrao` ou 1º focável | `ui_manager.gd:114-115`, `:168-178`; callers `prancha_inventario.gd:663-668`, `menu_sistema.gd:159-166`, `inventario_grid_re7.gd:118-123` | **PASS** |
| §3.1 `pop_menu` / `remove_menu` restore FILO | Só overlay/áudio | Pop/remove tiram `_focus_prev`; se pilha vazia → `gui_release_focus`; senão `_restaurar_foco` (fallback topo) | `ui_manager.gd:118-155`, `:193-197` | **PASS** |
| §3.1 anti-null com `profundidade()>0` | Nenhum | `_process` + deferred `_anti_null_foco` → `_focar_menu(topo())` | `ui_manager.gd:200-218`, `:164-165` | **PASS** |
| §3.3 stick deadzone ≥0.5 + cruz + 1 passo | Ausente / só InputMap | `MenuStickGate.DEADZONE := 0.5`; eixo dominante; exige retorno à zona (ou mudança de eixo) | `menu_stick_gate.gd:1-49` | **PASS** |
| §3.3 consume c/ menu no topo; right stick off | Sem JoypadMotion gate | Gate só `JOY_AXIS_LEFT_*`; prancha/sistema/grid `set_input_as_handled` / `tratar` return true | `menu_stick_gate.gd:15-19`; `prancha_inventario.gd:820-828`; `menu_sistema.gd:484-493`; `inventario_grid_re7.gd:43-48` | **PASS** |
| §3.3 D-pad / teclado 1 press = 1 passo | N/A gap | `is_action_pressed` → `_andar` / `_mover` uma vez por evento; stick gate separado | `menu_sistema.gd:494-501`, `:514-517`; `prancha_inventario.gd:830-833`, `:845-851` | **PASS** |
| §3.4 `HIT_LINHA_MIN` ≥32 | Era **14** | Token **32**; `_hit_linha = maxf(..., 32.0)`; hits STOP | `ui_estilo.gd:223-224`; `menu_sistema.gd:90-91`, `:356-361` | **PASS** |
| §3.4 pauzinhos / mouse STOP | Já 32×32 | Mantido `HIT_ABA` 32×32 `MOUSE_FILTER_STOP` | `menu_sistema.gd:22`, `:112-116` | **PASS** |
| §3.4 prancha legado hits ≥32 | Ícone 28, sem hit STOP | `HitSlot*` 32×32 `STOP` + `FOCUS_ALL`; visual ICONE 28 centrado | `prancha_inventario.gd:34`, `:305-316` | **PASS** |
| §3.4 hover = focus (lista / slots legado) | Parcial lista | Linha → `_focar`; slot → `_ao_slot_hover` + click `grab_focus` | `menu_sistema.gd:363`, `:425-428`, `:520-528`; `prancha_inventario.gd:313`, `:703-728` | **PASS** |
| Grid PREP `_ultimo_focus` | Declarado, nunca escrito | Persistido em `_on_slot_focus_entered`; `abrir`/`foco_padrao` preferem último | `inventario_grid_re7.gd:19`, `:110-115`, `:314-317` | **PASS (PREP)** |
| Grid PREP `mouse_entered`→`grab_focus` | Ausente no slot | `InventorySlotRE7` hover = focus (skip coberta) | `inventory_slot_re7.gd:28-39` | **PASS (PREP)** |
| Grid **not** live / cutover OFF | Não wired | `RE7_GRID := false`; prancha comenta cutover OFF; **zero** referência a `InventarioGridRE7` na prancha | `ui_estilo.gd:151-154`; `prancha_inventario.gd:662` | **CONFIRMED PREP** |
| Prancha 2D `focus_neighbor_*` grade RE7 | Ausente | Ainda sem grade 2D no path live; só neighbors **lista** L/R nos hits (top/bottom = self) | `prancha_inventario.gd:691-700` | **OUT OF SCOPE / deferred** (cutover OFF) |

---

## 3. Remaining holes (não bloqueiam scoped PASS)

| Hole | Severity | Notas |
|------|----------|--------|
| `MenuSistema.abrir` **não** chama `UIManager.push_menu` (nested sob prancha) | **P1** (ex-§3.6) | FILO do manager não empilha o sistema; restore ao fechar depende de `foco_padrao` local / anti-null na prancha (topo). Aceitável até nested sync; **fora do DoD scoped**. |
| Echo Godot em `is_action_pressed` (hold > repeat map) | **P2** | Spec pede anti-aceleração <350 ms; gate do stick cobre analógico. Se InputMap echo agressivo, D-pad pode repetir — QA §9. |
| Cutover `InventarioGridRE7` → pause live | **Deferred** | Explicitamente OUT; flag `RE7_GRID=false`. |
| QA prints `captures/ui/re7_dev/` | **QA** | Não verificado nesta reauditoria estática. |

Nenhum hole **P0 scoped** restante em §3.1 / §3.3 / §3.4 / PREP.

---

## 4. Explicit — grid still PREP (not live)

- `UiEstilo.RE7_GRID := false` — `ui_estilo.gd:151-154`.
- `PranchaInventario` path legado documentado: *"cutover InventarioGridRE7 OFF / PO1 lock"* — `prancha_inventario.gd:662`.
- Nenhum `InventarioGridRE7` / grupo `inventario_grid_re7` referenciado em `prancha_inventario.gd`.
- PREP cumpre o pedido deste ticket: `_ultimo_focus` persistido + `mouse_entered`→`grab_focus` nos slots; neighbors/clamp/coberta/hold permanecem no grid de teste/support apenas.

**Confirmação:** inventário pause live = **prancha faixa legado**, **não** `InventarioGridRE7`.

---

## 5. Checklist checkbox note (optional)

Itens DoD §3.1 (todos), §3.3 (todos scoped), §3.4 (HIT_LINHA / prancha hits / STOP / hover lista+slot RE7 PREP) → marcáveis **[x]** com esta evidência.  
§3.2 grid **live** cutover → permanece **[ ]** (deferred).  
§3.5–3.7 / QA prints → não re-auditados em profundidade aqui.

---

## 6. Evidence index (rápido)

| Tema | Onde |
|------|------|
| FILO focus | `ui_manager.gd:22-24`, `:90-218` |
| Stick gate | `menu_stick_gate.gd` (novo); consumers `menu_sistema.gd:74`, `:484+`; `prancha_inventario.gd:91`, `:820+`; `inventario_grid_re7.gd:22`, `:43+` |
| Hits ≥32 | `ui_estilo.gd:224`; `menu_sistema.gd:91`; `prancha_inventario.gd:305-311`; `inventory_slot_re7.gd:8,23-24` |
| Grid PREP | `inventario_grid_re7.gd`; flag `ui_estilo.gd:154` |

---

*Fim — scoped P0 G A11Y_FOCUS_STACK = **PASS** (grid cutover permanece PREP / OUT).*

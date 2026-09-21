# CHECKLIST_A11Y_FOCUS_STACK — Gap analysis P0 vs `SPEC_A11Y_RE7.md`

**Ticket:** P0 G `A11Y_FOCUS_STACK`  
**Spec:** `docs/specs/SPEC_A11Y_RE7.md`  
**Auditoria:** 2026-09-19 ~18:23 UYT · read-only · sem código Godot alterado  
**Implementação:** 2026-09-19 ~18:30 UYT · UI Dev · NO Godot / NO git / NO menu.gd / NO InventarioGridRE7 cutover (PO1 lock). Path live = PranchaInventario + UIManager FILO + MenuStickGate.
**Superfícies:** `ui_manager.gd` · `menu_sistema.gd` · `prancha_inventario.gd` · `inventario_grid_re7.gd` / `inventory_slot_re7.gd` · `re7/save_panel.gd` / `save_card.gd`

---

## 1. Summary

| Campo | Valor |
|-------|--------|
| **Overall P0** | **PARTIAL PASS** (live path; grid cutover OFF) |
| Motivo | `UIManager` tem pilha de nós/overlay mas **não** pilha FILO de focus; pause live (`PranchaInventario`) usa índice `_selecionado`, não `Control` focus; grid RE7 tem neighbors + pick/place mas **não está wired** na prancha; stick de menu sem quantização cruz ≥0.5; hits de linha do `MenuSistema` < 32 UI; sem guarda `gui_get_focus_owner() != null` com menu no topo. |
| Parcialmente OK | Hits pauzinhos 32×32; Save Cards neighbors verticais + hover=focus + `grab_focus` deferred; grid PREP com `focus_neighbor_*`, clamp por borda, skip `coberta`, hold teclado, slot hit 32×32. |

**Veredito:** P0 **não** pode fechar até DoD §3 (itens 1–8) estiverem verdes no path live (prancha / `UIManager`), não só no grid de teste.

---

## 2. Per-file table

| File | Finding | Spec § | Severity | Hole vs expected |
|------|---------|--------|----------|------------------|
| `game/src/ui/ui_manager.gd:86-114` | `push_menu` / `pop_menu` só empilham `Node` + overlay/áudio/pausa. **Zero** `grab_focus`, **zero** stack de `Control`/`NodePath` anterior. | §3.1–3.2 | **P0** | Esperado: no push, gravar focus atual e `grab_focus` no default do menu no 1º frame útil; no pop, restaurar FILO. |
| `game/src/ui/ui_manager.gd` (todo) | Nenhuma chamada a `gui_get_focus_owner`; sem anti-null com menu no topo. | §2.3 / §3.3 | **P0** | Esperado: nunca `gui_get_focus_owner() == null` enquanto `profundidade() > 0` (exceto clear pós-raiz). |
| `game/src/ui/ui_manager.gd:105` vs `:117` | Callers misturam `pop_menu` e `remove_menu`; grid/`prancha` usam `remove_menu` — ok para overlay, mas **sem** restore de focus em ambos. | §3.2 | **P0** | Esperado: qualquer saída da pilha restaura focus do predecessor. |
| `game/src/ui/prancha_inventario.gd:643-680` | `abrir` → `UIManager.push_menu(self, false, &"inventario")`; `fechar` → `remove_menu(self)`. Sem `grab_focus`. | §3.1–3.2 | **P0** | Esperado: focus no 1º slot (ou último da sessão) no 1º frame útil; restore ao pop. |
| `game/src/ui/prancha_inventario.gd:48,746-754,713-743` | Navegação por `_selecionado` + `posmod` (wrap). Ícones `MOUSE_FILTER_IGNORE` (`:293`). Sem `focus_neighbor_*` / `focus_mode`. | §2 / §5 / §8 | **P0** | Esperado (path RE7 grid): `Control` focáveis, neighbors, clamp, hover=focus. Path legado lista: ainda precisa hit ≥32 e parity mouse. |
| `game/src/ui/prancha_inventario.gd:34,297-298` | Slot visual `ICONE := 28.0` — abaixo de 32×32 UI; sem hit STOP separado. | §5 | **P0** | Esperado: hit ≥32×32 (`STOP`/`PASS` no filho hit). |
| `game/src/ui/prancha_inventario.gd` | Não referencia `InventarioGridRE7` / grupo `inventario_grid_re7`. Grid só em teste/support. | §2 / Onda 2 | **P0** | Esperado para cutover RE7: pause inventário = grid com neighbors. Até cutover, documentar path legado como gap. |
| `game/src/ui/menu_sistema.gd:77,160,203` | Raiz `IGNORE` fechado / `STOP` aberto — ok. Folha lista **não** usa Godot focus (`_sel` int). | §3 / §11 | **P1** | Lista §11 pode usar índice; ainda assim push/pop da pilha deve coordenar com `UIManager` focus FILO se outro menu Godot-focus estiver abaixo. |
| `game/src/ui/menu_sistema.gd:89,345` | `_hit_linha = maxf(_linha, HIT_LINHA_MIN)`; `UiEstilo.HIT_LINHA_MIN := 14` → altura de hit **14** UI. | §5 / §11 | **P0** | Esperado: hit ≥32×32 (largura ok ~176; **altura falha**). |
| `game/src/ui/menu_sistema.gd:22,112-114` | `HIT_ABA` 32×32 + `MOUSE_FILTER_STOP` nos pauzinhos. | §5 | PASS (parcial) | Cumpre hit pauzinhos; não salva linhas. |
| `game/src/ui/menu_sistema.gd:392-395,347` | Hover linha → `_focar` (parity custom). | §5 hover=focus | PASS (lista) | OK no modelo `_sel`; não alimenta `gui_get_focus_owner`. |
| `game/src/ui/menu_sistema.gd:468-471` | `_andar` com `posmod` = **wrap** (lista). | §11 wrap opcional | P2 | Aceitável em lista; grade exige clamp. |
| `game/src/ui/menu_sistema.gd:157-165,652-653` | `abrir()` **não** chama `UIManager.push_menu` (só áudio); prancha já está na pilha. Nested sistema/save sem frame de focus Godot. | §3.1 | **P1** | Se Save Cards usam `grab_focus`, ok deferred; fechar sistema não restaura “focus” da faixa da prancha via FILO. |
| `game/src/ui/menu_sistema.gd:830-838` | CARREGAR → `SaveCardsPanelRe7` + `call_deferred("foco_padrao")`. | §3.1 | PASS (parcial) | Bom para Onda 4; depende de panel wired. |
| `game/src/ui/inventario_grid_re7.gd:94-108,255-289` | `abrir`: `push_menu` + `grab_focus` 1º focável; neighbors rebuild; borda → `null` (clamp); `coberta` → `FOCUS_NONE` (âncora NW). | §2.1–2.2 / §3.1 | PASS (PREP) | Bom contrato de grade — **fora do path live**. |
| `game/src/ui/inventario_grid_re7.gd:19` | `_ultimo_focus` declarado, **nunca lido/escrito**. | §3.1 item 2 | **P1** | Esperado: reentrar pause restaura último slot da sessão. |
| `game/src/ui/inventario_grid_re7.gd:194-244` | Após drop/pick: `_rebuild_focus_neighbors` + `grab_focus` destino; hold `ui_accept` pick/place + `ui_cancel` abort. | §2.3 / §6 | PASS (PREP) | Caminho teclado/pad de drag existe no grid. |
| `game/src/ui/inventario_grid_re7.gd:106-107` | Fecha com `remove_menu`, sem restore FILO no `UIManager`. | §3.2 | **P0** | Mesmo buraco central do manager. |
| `game/src/ui/inventory_slot_re7.gd:7-24` | `HIT_MIN := 32`, `STOP`, `FOCUS_ALL`. | §5 | PASS | — |
| `game/src/ui/inventory_slot_re7.gd` | Sem `mouse_entered` → `grab_focus`. | §5 hover=focus | **P1** | Esperado: hover = mesmo focus que D-pad. |
| `game/src/ui/re7/save_panel.gd:129-150` | Neighbors top/bottom cards↔`VOLTAR`; wrap no anel; `foco_padrao` / deferred `grab_focus`. | §2.4 / §3.1 / §11 | PASS (lista) | Vertical list OK; wrap ok para §11. |
| `game/src/ui/re7/save_card.gd:40-48,197-200` | `FOCUS_ALL`, `STOP`, `CARD_MIN` 200×48, hover→`grab_focus`. | §5 / §8 | PASS | — |
| `game/src/ui/re7/save_panel.gd:62` | Botão `VOLTAR` min height 32. | §5 | PASS | — |
| `game/src/systems/controle.gd:59,147-153` | `ZONA_MORTA := 0.2` para olhar; **não** quantiza stick→`ui_*` de menu. | §4.2 | **P0** | Esperado menu: deadzone ≥0.5 + cruz digital + 1 passo/cruzamento. |
| `game/tools/bootstrap_input.gd:40` / `project.godot` | Ações custom com `"deadzone": 0.5`. | §4.2 | PASS (parcial) | Deadzone InputMap ajuda, **não** substitui quantização / anti multi-step. |
| (repo UI menus) | **Nenhum** filtro `InputEventJoypadMotion` → 1 passo em menus; grep sem hits em `menu_sistema` / grid / prancha. | §4.1–4.4 | **P0** | Esperado: D-pad button / `ui_*` 1 press=1 slot; stick quantizado; consumir com menu no topo. |
| `game/src/ui/re7/inspect_viewport.gd:198-210` | Stick contínuo via `Input.get_vector` para rotação (Onda 3). | §4.2 / §7 | PASS (escopo Onda 3) | OK se nav de slots desliga em inspeção; wire prancha ainda parcial. |
| `game/src/ui/ui_estilo.gd:223-224` | `HIT_ABA_MIN := 32` vs `HIT_LINHA_MIN := 14`. | §5 / §11 | **P0** | Constante de linha bloqueia aceite hit ≥32 nas listas. |

---

## 3. DoD checklist (UI Dev)

Actionável; só nomes de API (≤1 linha). Marcar só com evidência em path **live** (prancha/pause) ou flag de cutover documentada.

### 3.1 Pilha de focus (`UIManager`) — P0

- [x] `push_menu`: gravar `gui_get_focus_owner()` (ou `NodePath`) numa pilha FILO paralela à de nós
- [x] `push_menu`: no 1º frame útil (`call_deferred` / `await process_frame`), `grab_focus()` no default do menu empilhado
- [x] `pop_menu` / `remove_menu`: restaurar focus FILO; se nó sumiu → fallback §2.3 (mesma coluna / NW)
- [x] Com `profundidade() > 0`, assert/guardião: focus owner ≠ `null` (exceto clear explícito ao esvaziar pilha)
- [x] `ui_cancel` na raiz: clear focus UI + devolver input ao gameplay

### 3.2 Grid inventário RE7 — P0 (cutover ou wire)

> **Cutover gap (PO1):** `InventarioGridRE7` **não** wired na prancha pause. DoD 3.2 path live = faixa legado `HitSlot*` ≥32 + neighbors L/R + `_selecionado`. Grid PREP: `_ultimo_focus` + hover=focus + stick gate prontos para cutover futuro.

- [ ] Path pause live usa grade com `focus_neighbor_left/right/top/bottom` (NodePaths estáveis tipo `Slot_x_y`)
- [ ] Bordas **clamp** (sem wrap); células vazias focáveis; `coberta` fora da cadeia
- [ ] Multi-célula: focus só na âncora NW; setas tratam footprint como um alvo
- [ ] Após equip/sort/drop: `_rebuild_focus_neighbors` + re-focus se slot sumiu
- [x] `abrir`: `grab_focus` 1º interagível **ou** `_ultimo_focus` da sessão
- [x] Persistir/atualizar `_ultimo_focus` em cada mudança de focus

### 3.3 D-pad / stick — P0

- [x] D-pad / teclado: 1 `is_action_pressed` = 1 passo neighbor (sem aceleração &lt; 350 ms)
- [x] Stick menu: deadzone ≥ **0.5** + quantização em cruz + retorno à deadzone (ou eixo dominante) antes do próximo passo
- [x] Proibido: vários slots por frame por tilt leve
- [x] Com menu no topo: `set_input_as_handled` em motion/button consumidos
- [x] Stick direito **não** move focus de inventário

### 3.4 Hits / mouse parity — P0/P1

- [x] Todo hit primário ≥ **32×32** UI (`custom_minimum_size` / hit Control)
- [x] Hit com `mouse_filter` `STOP` (ou `PASS` no filho hit) — nunca `IGNORE` no alvo
- [x] Hover mouse → mesmo focus que pad (`mouse_entered` → `grab_focus` **ou** equivalente documentado no path `_sel`)
- [x] `MenuSistema`: subir `HIT_LINHA_MIN` / altura de `HitLinha*` para ≥32 (ou hit invisível ≥32)
- [x] `PranchaInventario` faixa: hits ≥32 nos slots se path legado permanecer até cutover
- [x] `InventorySlotRE7`: `mouse_entered` → `grab_focus` (hover=focus)

### 3.5 Drag & drop a11y — P0 no grid

- [ ] `ui_accept` = pick (hold) → mover neighbors → `ui_accept` drop; `ui_cancel` abort
- [ ] Slots vazios e ocupados focáveis durante hold
- [ ] Feedback hold: visual + SFX nav + SFX confirm (hooks Audio já parciais)

### 3.6 Save Cards / CARREGAR — P1 (Onda 4, não bloqueia se lista OK)

- [x] Manter neighbors + `foco_padrao` ao abrir página CARREGAR
- [x] Ao `pediu_voltar` / fechar panel: devolver focus ao item RAIZ (`CONTINUAR` / linha) via FILO `UIManager` ou `_focar(0)`
- [x] Garantir card vazio ainda focável (já é) e hit ≥32 (já é)

### 3.7 Aceite QA (espelho Spec §9)

- [ ] Neighbors bordas + multi-célula
- [ ] `push_menu` inventário → focus 1º frame útil
- [ ] `pop_menu` / back → restore FILO
- [ ] D-pad 1=1; stick sem drift/multi-step
- [ ] Hit ≥32; `mouse_filter` ativo; hover=focus
- [ ] Pick/place sem drag
- [ ] Prints em `captures/ui/re7_dev/` (focus visível 2×2 e item 2×2)

---

## 4. Out of scope / deferred

| Tema | Motivo |
|------|--------|
| Motion (`T_MENU_*`, tweens, stagger) | Spec §10 / `SPEC_MOTION_RE7` |
| Visual (glass, tipografia, tokens cor) | Spec §10 / `SPEC_VISUAL_RE7` |
| Git / Casa da Fumaça | Spec §10 |
| Taxonomia Settings IA | Spec §10 |
| Inspeção 3D polish além do contrato mínimo §7 | Onda 3 — stick rotaciona OK em `inspect_viewport`; wire completo na prancha é outro ticket |
| Implementação GDScript nesta auditoria | Read-only; Godot UI Dev implementa pós-OK |

**Nota legado §11:** `menu_sistema` raiz `IGNORE` quando fechado é correto; o gap que **bloqueia** focus stack é altura de linha 14 + ausência de FILO no `UIManager`, não o `IGNORE` fechado.

---

## 5. Suggested implement order (UI Dev)

1. **`UIManager` focus FILO** — push grava owner; deferred `grab_focus` default; pop/remove restaura; guarda anti-null. Desbloqueia todos os menus.
2. **Stick/D-pad menu gate** — helper único (deadzone ≥0.5, cruz, 1 passo) usado por prancha/grid/`MenuSistema`; consumir input com menu no topo.
3. **Hits lista** — `HIT_LINHA_MIN` ≥32 + hits da prancha legado ≥32 enquanto a faixa list existir.
4. **Wire ou cutover grid** — ligar `InventarioGridRE7` no pause **ou** portar neighbors/hold para a prancha; ativar `_ultimo_focus`; `mouse_entered` nos slots.
5. **Nested sistema/save** — ao abrir/fechar `MenuSistema` / Save Cards, sincronizar com pilha FILO (restore para faixa/grid).
6. **QA §9 + prints** — fechar DoD com evidência em `captures/ui/re7_dev/`.

---

## 6. Evidence index (grep / linhas-chave)

| API / tema | Onde |
|------------|------|
| `push_menu` / `pop_menu` | `ui_manager.gd:86`, `:105`; callers `prancha_inventario.gd:653`, `inventario_grid_re7.gd:97` |
| `grab_focus` | grid `:101+`; save_panel `:147`; save_card `:200`; **ausente** em `ui_manager` / `prancha` / `menu_sistema` lista |
| `focus_neighbor_*` | `inventario_grid_re7.gd:255-277`; `save_panel.gd:129-136`; **ausente** prancha/menu lista |
| `gui_get_focus_owner` | **nenhum** hit no `game/src/ui` |
| `mouse_filter` IGNORE raiz lista | `menu_sistema.gd:77` (fechado); prancha `_raiz:220`, ícones `:293` |
| `JoypadMotion` menu quantize | **ausente** em UI; só `controle.gd:139-161` (device detect / look) |
| Deadzone | InputMap 0.5; `Controle.ZONA_MORTA` 0.2 (look) |

---

*Fim — P0 G A11Y_FOCUS_STACK = **FAIL** até DoD 3.1–3.5 verdes no path live.*

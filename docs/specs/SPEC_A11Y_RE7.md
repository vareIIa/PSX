# SPEC_A11Y_RE7 — Contrato de input / foco (Épico UI RE7)

**Status:** **APPROVED** PO (19/09/2026) · **Sem código** até Godot na Onda 2  
**Dono:** PSX A11y Input · **Consome:** Godot UI Dev, UX Auditor, Menu QA, Docs Lead  
**Alinha com:** playbook A11y §11 (ações canônicas) · `EPICO_UI_RE7.md` Onda 2 (grid) + Onda 1 (`UIManager`)  
**Superfície principal:** inventário grid multi-slot (1×2, 2×2, N×M) + pilha `push_menu` / `pop_menu`

---

## 0. Norte

Overlay diegético estilo RE7: navegação **espacial em grade**, não lista vertical.  
Gamepad/teclado devem sentir **preciso** (cada press = um slot). Mouse/touch: mesmo estado de focus.  
Este contrato **não** define look (Visual) nem timings de tween (Motion) — só foco, hit, device e aceite.

---

## 1. Ações canônicas (herdam §11)

| Ação | Uso no grid RE7 |
|------|-----------------|
| `ui_up` / `ui_down` / `ui_left` / `ui_right` | Mover focus **um** slot na grade |
| `ui_accept` | Selecionar / abrir inspeção / confirmar drop |
| `ui_cancel` | Cancelar drag / fechar inspeção / `pop_menu` |
| `ui_open_pause` | Abrir inventário (Start/ESC) — canônico; pauzinhos = atalho secundário |
| (opcional) `ui_tab_prev` / `ui_tab_next` | Alternar painéis (ex. inventário ↔ opções) se existirem |

Regra: lógica de menu **nunca** ramifica por device — só por ação.

---

## 2. `focus_neighbor_*` em grid multi-slot

### 2.1 Obrigações

Todo slot focável (`Control` / botão de célula) declara vizinhos explícitos:

- `focus_neighbor_left` / `right` / `top` / `bottom`
- Preferir `NodePath` estáveis (nome de slot), não índices frágeis após rebuild

### 2.2 Grade regular (ex. 2×2, 3×4)

| Direção | Comportamento |
|---------|----------------|
| Interior | Vizinho ortogonal imediato |
| Borda | **Clamp** (default RE7) — não wrap para o outro lado da grade |
| Slot vazio mas válido | Ainda focável (célula vazia = destino de move/drop) |
| Slot bloqueado / oculto | Pular na cadeia de neighbors (relink ao rebuild) |

Itens **multi-célula** (1×2, 2×2): o focus pousa na **âncora** (célula NW / top-left). Setas atravessam o footprint como um único alvo (não entrar em células cobertas).

### 2.3 Rebuild / drag

Após qualquer mudança de layout (equip, sort, drop):

1. Recalcular `focus_neighbor_*` de **todos** os slots visíveis
2. Se o slot focado sumiu → focus no slot mais próximo (mesma coluna, senão NW da grade)
3. Nunca deixar `get_viewport().gui_get_focus_owner() == null` com menu no topo da pilha

### 2.4 Fora da grade

Vizinhos entre **regiões** (grade ↔ painel de detalhe ↔ vitals ↔ botões de ação):

- Explicitar ponte `focus_neighbor_*` região→região
- Não depender só do focus automático do Godot em árvores profundas

---

## 3. `grab_focus` ao `push_menu`

### 3.1 Push (`UIManager.push_menu`)

No **primeiro frame útil** após o menu entrar na pilha (após `_ready` / add_child):

1. `grab_focus()` no controle default daquele menu
2. Inventário: default = **primeiro slot interagível** (ou último selecionado se reentrar a mesma sessão de pause)
3. Opções/lista: default = primeira linha / CONTINUAR-equivalente
4. Não esperar fim de tween de open para focar — input gate ≤ 250 ms (Motion); focus visual pode fade in, ownership já é do slot

### 3.2 Pop (`pop_menu` / back)

1. Restaurar focus no controle que estava focado **antes do push** (stack FILO de `Control` ou NodePath)
2. Se o anterior sumiu → fallback da seção 2.3
3. `ui_cancel` na raiz → fecha inventário e devolve input ao gameplay (clear focus UI)

### 3.3 Anti-padrões

- Abrir menu sem `grab_focus` (D-pad “morto” até clicar)
- Focus preso no menu debaixo na pilha
- `grab_focus` em nó `MOUSE_FILTER_IGNORE` sem `focus_mode` adequado

---

## 4. D-pad preciso vs stick

### 4.1 D-pad / teclado (setas)

- **1 press = 1 passo** de neighbor (sem aceleração nos primeiros 350 ms)
- Repeat só após hold ≥ 350 ms, então ≤ 1 passo / ~80–100 ms
- Eventos: preferir `InputEventJoypadButton` (dpad) e `ui_*` do InputMap — **não** tratar D-pad como eixo analógico

### 4.2 Stick esquerdo (navegação de slots)

- Deadzone ≥ 0.5 (menu) — evitar drift entre slots
- Quantizar em **cruz digital**: só emite um `ui_*` quando o eixo cruza o limiar; exige retorno à deadzone (ou mudança de eixo dominante) antes do próximo passo
- **Proibido:** amostrar stick a cada frame e andar vários slots por tilt leve
- Em modo inspeção 3D (Onda 3): stick **roda** o objeto; navegação de slots fica desligada até sair da inspeção

### 4.3 Stick direito

- Reservado a câmera/inspeção se existir; **não** move focus de inventário

### 4.4 `_unhandled_input` / JoypadMotion

Se o projeto filtrar `InputEventJoypadMotion` manualmente:

- Converter motion → no máximo **um** passo por cruzamento de limiar
- Não competir com `ui_*` já mapeados (evitar double-step)
- Com menu no topo: consumir o evento (`set_input_as_handled`) para o gameplay debaixo não andar

---

## 5. Hit target ≥ 32

Escala **UI** do projeto (não pixels CRT brutos):

| Alvo | Mínimo |
|------|--------|
| Slot de inventário (célula 1×1) | **32×32** UI (preferível ≥ 40×40 se o grid couber) |
| Âncora de item multi-célula | União das células, cada célula ≥ 32×32 |
| Botões de ação / fechar / abas | ≥ 32×32 |
| Handle de drag (se separado) | ≥ 32×32 |

Regras:

- `mouse_filter` = STOP (ou PASS no filho hit) na área clicável — **nunca** IGNORE no hit do slot
- Hover mouse → **mesmo** focus que D-pad (parity §11)
- Gap entre hits ≥ 4 px UI
- Safe area: hits primários fora das 5% externas da tela

---

## 6. Drag & drop (a11y)

Mouse/touch: drag nativo ok.

**Obrigatório caminho sem arrastar** (teclado/gamepad):

1. Focus no item → `ui_accept` = “pegar” (estado *holding*)
2. Mover focus para destino (neighbors)
3. `ui_accept` = soltar / trocar; `ui_cancel` = abortar hold

Feedback: 3 canais no hold (visual + SFX move + SFX confirm) — Motion/Audio definem assets; A11y exige que existam.

Slots vazios e ocupados ambos focáveis durante hold.

---

## 7. Inspeção 3D (Onda 3 — contrato mínimo)

Ao entrar em inspeção:

- `grab_focus` no viewport/controle de inspeção (ou modo “focus preso” com trap)
- `ui_cancel` / B = sair e restaurar focus no slot de origem
- Rotação: mouse drag e/ou stick; **não** mapear setas de slot para rotação sem modo explícito

---

## 8. Paridade devices (aceite)

Mesmo fluxo jogável em:

1. **Só teclado** (setas + Enter/Esc)
2. **Só mouse** (hover + click; drag opcional se path teclado existir)
3. **Só gamepad** (D-pad preciso + A/B)
4. Troca mid-flow teclado ↔ mouse ↔ pad sem perder focus

---

## 9. Checklist QA (Onda 2)

- [ ] Todo slot tem `focus_neighbor_*` coerente (testar bordas + multi-célula)
- [ ] `push_menu` inventário → focus no 1º frame útil
- [ ] `pop_menu` / back → restore FILO
- [ ] D-pad: 1 press = 1 slot; sem salto
- [ ] Stick: sem drift; deadzone ≥ 0.5; sem multi-step por frame
- [ ] Hit slot ≥ 32×32; `mouse_filter` ativo
- [ ] Hover = focus visual idêntico ao pad
- [ ] Pick/place via accept sem drag
- [ ] Prints: `captures/ui/re7_dev/` com focus visível em grade 2×2 e item 2×2

---

## 10. Fora de escopo

- Implementação GDScript / cenas (Godot UI Dev)
- Tokens visuais, glass, tipografia (Visual)
- `T_MENU_*` / tweens (Motion)
- Taxonomia de opções (Settings IA)
- Git / Casa da Fumaça

---

## 11. Relação com A11y §11 (menus lista)

| Tema | §11 (lista) | RE7 (grid) |
|------|-------------|------------|
| Hit mín | 32×32 | 32×32 (igual) |
| Wrap | opcional on em listas | **clamp** na grade |
| Default focus | primeira linha / CONTINUAR | primeiro slot / último da sessão |
| Stick | deadzone + repeat | + quantização cruz + sem multi-step |

§11 continua válido para folhas de opções/sistema; este spec cobre o **grid espacial** do inventário RE7.

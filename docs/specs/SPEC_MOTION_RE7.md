# SPEC MOTION RE7 — Overlay Survival Horror AAA
> PSX Motion UI · 19/09/2026 · **APPROVED** PO · spec só (sem código)
> Norte: `docs/EPICO_UI_RE7.md`. Complementa `SPEC_MOTION_PAUZINHOS_RAIZ.md` (sistema/pauzinhos).
> Este arquivo cobre **inventário grid + inspeção 3D + overlay DoF** (ondas 1–3 do épico).

## 0. Relação com specs locked

| superfície | motion fonte |
|---|---|
| Pauzinhos + folha SISTEMA (`menu_sistema`) | `SPEC_MOTION_PAUZINHOS_RAIZ.md` (`T_MENU_*` + §7 RE-like) |
| Inventário grid / prancha RE7 / inspeção | **este arquivo** (`T_RE7_*`) |
| Cartão HUD diegético | UI-BIBLE `T_ENTRADA` / `T_SAIDA` (inalterados) |

Sem fork de comportamento: mesmos anti-padrões (sem glow neon, sem glass blur barato, input lock ≤250 ms no open de painel).

## 1. Tokens RE7

| token | duração | banda | uso |
|---|---|---|---|
| `T_RE7_OPEN` | **0,22 s** | 0,18–0,25 s | open overlay inventário (scrim+DoF+painel) |
| `T_RE7_CLOSE` | **0,14 s** | ≤ open | close overlay / pop painel |
| `T_RE7_PANEL` | **0,20 s** | 0,16–0,24 s | slide/fade de painel lateral ou modal interno |
| `T_RE7_GRID_STAGGER` | **35 ms** / célula | 30–40 ms | cascata do grid de slots |
| `T_RE7_FOCUS` | **0,08 s** | ≤0,10 s | focus slot / row |
| `T_RE7_PRESS` | **0,10 s** | 0,08–0,15 s | pick / drop / confirm |
| `T_RE7_SPIN_DAMP` | **0,28–0,40 s** | half-life ~0,18 s | inspeção 3D: freio após soltar input |

Teto: open do overlay **não** trava input >250 ms após o primeiro frame útil (grid pode stagger visual depois).

## 2. Easing canônico — painéis

| alvo | transition | ease | nota |
|---|---|---|---|
| Painéis (inventário, opções, save card, vitals) | **`TRANS_EXPO`** | **`EASE_OUT`** | peso RE: chega rápido, assenta sem bounce |
| Close de painel | `TRANS_EXPO` | `EASE_IN` | mais curto que open (`T_RE7_CLOSE`) |
| Scrim α | `TRANS_QUAD` | `EASE_OUT` / `EASE_IN` | paralelo ao painel |
| DoF / saturação shader | `TRANS_QUAD` | `EASE_OUT` | mesmo clock que scrim |
| Focus slot | `TRANS_SINE` | `EASE_OUT` | `T_RE7_FOCUS` |
| Spin damp inspeção | ver §5 | — | não usar EXPO no angular (fica “chicote”) |

`Tween`: `set_parallel(true)` **uma vez** por open (scrim + DoF + painel). Nunca `.parallel()` por linha.

## 3. Open inventário — scrim + DoF

Sequência (Onda 1–2):

1. `UIManager.push_menu(inventario)` → mundo pausado / duck áudio.
2. **Paralelo** em `T_RE7_OPEN`:
   - Scrim `ColorRect` α **0 → 0,55–0,62** (Visual AAA-RE).
   - Shader `ui_menu_overlay`: DoF blur amount **0 → pico**; saturação **0 → −40%**; CA/lens dirt fade-in suave (≤ open).
   - Painel raiz: `modulate.a` 0→1 + slide **6 px** (banda 4–8) no eixo dominante (`TRANS_EXPO` / `EASE_OUT`).
3. Após painel no ar (ou overlap 40 ms): **stagger grid** (§4).
4. Focus no slot default (primeiro válido / último usado) no 1º frame útil do grid.

Close: inverter com `T_RE7_CLOSE`; **matar tween anterior** antes de reabrir. DoF e scrim voltam a 0 juntos.

| prop shader (lógico) | idle mundo | menu aberto |
|---|---|---|
| `dof_amount` | 0 | pico calibrado na captura `re7_dev` |
| `sat_mul` | 1,0 | ~0,60 (−40%) |
| `ca_strength` | 0 | baixo, só bordas |
| `lens_dirt` | 0 | α leve |

**Anti:** blur na tipografia do painel; DoF que deixa slots ilegíveis; glow neon no focus.

## 4. Stagger grid (slots)

| parâmetro | valor |
|---|---|
| Ordem | row-major (esq→dir, cima→baixo) **ou** spiral do centro — pick **row-major** |
| Delay / célula | **35 ms** (banda 30–40) |
| Prop | `modulate.a` 0→1 + opcional y **+4 px→0** (`TRANS_EXPO` / `EASE_OUT`) |
| Cap | se `delay × (n−1) + cell_fade > T_RE7_OPEN`, **snapar** restantes no `finished` do open |
| Close | fade único do painel (sem stagger invertido) — mais rápido |

Drag&Drop: ao hover slot válido, `T_RE7_FOCUS` no stain do slot; drop usa `T_RE7_PRESS`. Sem elastic no ícone.

Multi-slot (1×2, 2×2): o bloco ocupa N células; stagger conta **âncora** (célula topo-esq); filhos não staggered à parte.

## 5. Inspeção 3D — spin damp

SubViewport + Camera3D (Onda 3). Input: mouse drag / stick.

| fase | comportamento |
|---|---|
| Drag / stick ativo | velocidade angular = input × sensibilidade; sem tween |
| Soltou input | **damp**: ω *= decay por frame **ou** tween de ω → 0 em `T_RE7_SPIN_DAMP` |
| Half-life alvo | ~**0,18 s** (para em ~0,28–0,40 s) |
| Easing do damp | `TRANS_EXPO` / `EASE_OUT` na magnitude de ω **ou** lerp exponencial `ω *= 0,85 @60fps` (equiv.) |
| Limites | clamp pitch ±75°; yaw livre; sem gimbal flip brusco |
| Enter inspeção | painel/viewport `T_RE7_PANEL` EXPO out; item scale 0,96→1 (≤4%) |
| Exit | `T_RE7_CLOSE`; matar spin (ω=0) no pop |

**Anti:** spin infinito sem atrito; spring/bounce elástico; motion blur no item que mate silhueta; glow de seleção neon.

Luz dramática: intensidade pode respirar ±5% em loop lento (4–6 s) — **não** é feedback de input.

## 6. Vitals / emission (Onda 3, motion leve)

| HP | motion |
|---|---|
| Saudável | emission idle estável |
| Ferido | pulse emission período ~1,2 s, amp baixa |
| Crítico | pulse ~0,6 s + opcional flicker 1 frame — **sem** tela vermelha full |

Tween emission com `TRANS_SINE` / `EASE_IN_OUT`. Matar tween anterior em hit consecutivo (mesma regra UI-BIBLE clareões).

## 7. Hooks SFX / áudio

| evento | hook |
|---|---|
| open inventário | `ui_re7_open` + duck mundo |
| close | `ui_re7_close` + unduck |
| move slot | `ui_move` |
| pick / drop | `ui_re7_pick` / `ui_re7_drop` |
| enter / exit inspeção | `ui_re7_inspect_in` / `_out` |
| spin idle (opcional) | foley baixo contínuo só com ω > limiar |

## 8. Mapa onda → motion

| onda épico | entrega motion |
|---|---|
| 1 Fundação | scrim+DoF open/close `T_RE7_OPEN/CLOSE`; EXPO painel |
| 2 Grid | stagger 35 ms; focus/press slots |
| 3 Inspeção + vitals | spin damp; panel enter; emission pulse |
| 4 Opções/Save | `T_RE7_PANEL` EXPO; save cards fade |

## 9. DoD

- Painéis: `TRANS_EXPO` / `EASE_OUT` (close `EASE_IN`)
- Open inventário: scrim + DoF + painel em paralelo; stagger grid 30–40 ms
- Inspeção: spin damp half-life ~0,18 s; sem bounce
- Sem glow neon · sem código neste passo
- Capturas de aceite: `captures/ui/re7_dev/` (open mid-stagger, focus slot, inspect damp)


## 10. Polish P0 #2 — Faixa legado (ícones A/D) · damp/easing

> **Doc only agora.** Implementação **depois da Onda 3** (Diegetic na prancha em curso). Não tocar `prancha_inventario.gd` neste passo.
> Superfície: faixa de couro `FAIXA` + `_icones[]` + moldura `_selecao` (`prancha_inventario.gd`).

### 10.1 Estado atual (legado — a corrigir pós-O3)

| comportamento | hoje | problema |
|---|---|---|
| Troca de slot (`_mover`) | `_selecao.scale` 1,12→1 com **`TRANS_BACK`** 0,12 s | overshoot/bounce — anti RE7 / anti bitmap |
| Posição da moldura | snap imediato no `_atualizar` | sem damp espacial entre slots |
| Ícone sob focus | modulate fixo | sem lift/stain curto |

### 10.2 Contrato pós-Onda 3

| token | duração | uso |
|---|---|---|
| `T_FAIXA_FOCUS` | **0,08 s** (≤0,10) | moldura + ícone ao mudar slot |
| `T_FAIXA_PRESS` | **0,10 s** | usar / examinar (aba) — alinhado `T_RE7_PRESS` |

| elemento | props | de → para | easing | nota |
|---|---|---|---|---|
| Moldura `_selecao` | `position` (centro do slot) | slot A → slot B | **`TRANS_EXPO` / `EASE_OUT`** **ou** `TRANS_SINE` / `EASE_OUT` | **damp** — sem BACK/ELASTIC/BOUNCE |
| Moldura | `scale` | idle **1,0** → press **1,04** máx. → 1,0 | `TRANS_SINE` / `EASE_OUT` | teto **±4%**; matar overshoot |
| Ícone focado | `modulate` ou y **−2 px** | idle → focus | `T_FAIXA_FOCUS` SINE out | opcional; sombra acompanha |
| Ícones vizinhos | — | sem stagger na navegação | — | stagger só no **open** da prancha (se houver) |

Navegação A/D (e equivalentes `ui_left/right`): **1 SFX `ui_move` por passo**; tween anterior da moldura **kill** antes do próximo (`tween.kill()`), senão a moldura “atrasa” dois slots.

### 10.3 Open da faixa (opcional, mesmo pacote pós-O3)

Se o open da prancha ganhar cascata nos ícones:

| parâmetro | valor |
|---|---|
| delay / ícone | **35 ms** (30–40) — mesmo pick do grid RE7 |
| prop | `modulate.a` 0→1 |
| easing | `TRANS_EXPO` / `EASE_OUT` |
| cap | dentro de `T_RE7_OPEN` |

Close: fade único da raiz (já `T_RE7_CLOSE`) — **sem** stagger invertido.

### 10.4 Anti

- `TRANS_BACK` / `ELASTIC` / `BOUNCE` na moldura ou ícone
- scale >1,04 no focus/press
- glow neon / outline bloom
- moldura que não mata tween ao spam A/D

### 10.5 DoD (quando Dev implementar pós-O3)

- [ ] `_mover` sem `TRANS_BACK`
- [ ] moldura damp position + scale ≤1,04
- [ ] captura `captures/ui/re7_dev/onda3_faixa_focus.png` (meio do damp entre slots)
- [ ] PO2 valida

**Ordem:** Onda 3 Diegetic (inspect+vitals na prancha) → **este polish** → Onda 4.

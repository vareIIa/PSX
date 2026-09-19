# SPEC MOTION — Pauzinhos + Folha RAIZ
> PSX Motion UI · 19/09/2026 · spec só (sem código)
> Alinha: PO pesquisa AAA (open 150–250 ms / close mais rápido / input ≤250 ms) + aceite UX + Visual (`stain`+barra 2px+`>`, sem glow)
> Convive com UI-BIBLE §5: `T_ENTRADA`/`T_SAIDA` do **cartão HUD** ficam 0,34 / 0,40 s. Menus usam a banda abaixo.

## 1. Tokens de menu (pauzinhos + RAIZ / sistema)

| token | duração | banda | uso |
|---|---|---|---|
| `T_MENU_OPEN` | **0,20 s** | 0,15–0,25 s | abrir folha RAIZ + chip pauzinhos |
| `T_MENU_CLOSE` | **0,14 s** | ≤ open | fechar folha / recolher chip |
| `T_MENU_PAGE` | **0,16 s** | 0,12–0,20 s | RAIZ → VIDEO/AUDIO/CARREGAR |
| `T_MENU_FOCUS` | **0,08 s** | ≤0,10 s | stain + barra 2px + `>` |
| `T_MENU_PRESS` | **0,10 s** | 0,08–0,15 s | flash accept/adjust (1–2 frames + SFX) |

Teto duro: **nenhum tween de menu bloqueia input >250 ms** (PO AAA). Cartão HUD continua fora desta tabela.

## 2. Alvos do tween (o que anima — não glow)

| elemento | props | de → para | token | easing |
|---|---|---|---|---|
| Folha RAIZ (papel) | `modulate.a`, `position.y` | 0→1, +8 px→0 | `T_MENU_OPEN` | `TRANS_QUAD` / `EASE_OUT` |
| Folha RAIZ close | `modulate.a`, `position.y` | 1→0, 0→+6 px | `T_MENU_CLOSE` | `TRANS_QUAD` / `EASE_IN` |
| Chip pauzinhos (hit 32×32 @ Visual) | `modulate.a` | 0→1 no open da prancha; idle estático sob vinheta | com open da prancha / snap | sem bounce |
| Página (conteúdo) | `modulate.a` **ou** `position.x` ±10 px | out→swap→in | `T_MENU_PAGE` | `TRANS_CUBIC` / `EASE_IN_OUT` |
| Focus (CONTINUAR default) | stain α + barra 2px + glifo `>` | idle→focus | `T_MENU_FOCUS` | `TRANS_SINE` / `EASE_OUT` |
| SAIR (destructive) | mesma família de focus; **sem** glow extra — peso vem da tinta `DESTAQUE` (Visual) | — | `T_MENU_FOCUS` | igual |
| Press / confirm | 1 frame stain + SFX | — | `T_MENU_PRESS` | step / linear |

**Anti (PO + Visual):** glow, blur, elastic, scale >±4 % em bitmap, open >250 ms, focus só por mudança de cor sem stain/barra/`>`.

## 3. Sequência de aceite (RAIZ + aba)

1. Open prancha → chip pauzinhos visível (α) em paralelo com folha se sistema já aberto; senão chip idle.
2. Open sistema (`W` / chip): folha em `T_MENU_OPEN`; **CONTINUAR** já focado no frame 0 do conteúdo (focus sem esperar open inteiro — stain/`>` aparecem no primeiro frame útil ≤ `T_MENU_FOCUS`).
3. Navigate: `T_MENU_FOCUS` + SFX `ui_move` (1× por mudança).
4. Page: `T_MENU_PAGE`; restore focus no back (contrato A11y/UX) — motion não zera `_sel` visualmente sem snap.
5. Close: `T_MENU_CLOSE` (< open); matar tween anterior.

## 4. Hooks SFX (3 canais PO)

| canal | quando | hook |
|---|---|---|
| visual | stain+barra+`>` | props §2 |
| SFX move | mudança de linha | `ui_move` |
| SFX confirm | accept / adjust / open / close / deny | `ui_accept` / `ui_adjust` / `ui_open` / `ui_close` / `ui_deny` |

## 5. Delta vs playbook §13

§13 espelhava cartão (`T_ENTRADA` 0,34 / `T_SAIDA` 0,40). **Para menu_sistema / pauzinhos / RAIZ, preferir esta spec** (`T_MENU_*`). Docs Lead: ao consolidar, anotar no §13 que menus usam banda AAA 150–250 ms; cartão HUD mantém UI-BIBLE.

## 6. DoD desta spec

- Open ≤250 ms, close < open, focus ≤100 ms
- Alvo = stain + barra 2px + `>` (sem glow)
- CONTINUAR focado na entrada; SAIR sem motion especial além da tinta Visual
- Zero código até PO aprovar pacote Visual+UX
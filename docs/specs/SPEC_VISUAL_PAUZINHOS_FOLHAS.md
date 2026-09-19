# SPEC VISUAL — Aba pauzinhos + folhas RAIZ / VIDEO / AUDIO
**Agente:** PSX Visual Design  
**Data:** 19/09/2026  
**Base:** `docs/PLAYBOOK_MENUS_AAA.md` · `docs/UI-BIBLE.md` · `UiEstilo` · refs `captures/ui/f4_*` + `captures/menu/*`
**Escopo:** tokens + medidas em px da **TELA do jogo**. Sem código. Sem glass.

---

## 0.1 Aceite UX (PO+Auditor — 19/09/2026)

| critério | spec |
|---|---|
| Pauzinhos hit | **≥ 32×32** @ (441, 14); placa papel legível sob vinheta (`CAMADA_ACIMA_DO_POS`) |
| Affordance | chip hamburger (3 barras), atalho **secundário**; Start/ESC canônicos |
| Título página RAIZ | **`SISTEMA`** (pause-root; preferência UX+PO — trava ao confirmar Jamerson) — **nunca** `OPCOES`/`OPÇÕES` / `PAUSA` |
| Default focus | **`CONTINUAR`** entra focado + peso tipográfico/stain default |
| Destructive | **`SAIR PARA O TITULO`** em `DESTAQUE` + tracking/peso; modal fica P1 A11y |
| Hierarquia | ações (CONTINUAR/CARREGAR) ≠ ajustes (IMAGEM/SOM) ≠ saída |
| Glass | proibido |

## 0. Contrato (não negociar)

| regra | valor |
|---|---|
| TELA | **480 × 270** (`UiEstilo.TELA`) |
| Linguagem | **papel + tinta + CRT** (scanline/grain/vinheta vêm do *pós*, não da UI) |
| Proibido | blur, frosted glass, painel semi-transparente “moderno”, sombra suave, glow RGB, cantos arredondados > 0 |
| Permitido | scrim opaco escuro, papel opaco, borda 1 px tinta, sombra dura offset 2 px, stain de foco ≤ α 0.10 |
| Fonte de verdade de opções | `OpcoesLista` (rótulos VIDEO/AUDIO); menus só desenham |
| Camada aba | `CAMADA_ACIMA_DO_POS` (160) — canto direito morre na vinheta se ficar sob o pós |
| Margem segura | **7 px** (`UiEstilo.MARGEM` / UI-BIBLE) |

---

## 1. Tokens (alinhar `UiEstilo` + UI-BIBLE)

### 1.1 Cor — tinta e papel

| token | hex / valor | uso |
|---|---|---|
| `TINTA` | `#2a1f16` | texto idle, borda de papel, barras dos pauzinhos |
| `TINTA_FRACA` | `#6a5a44` | dica de input, divisor, disabled, valor secundário |
| `TINTA_TITULO` | `#7a3a22` | título da folha (`SISTEMA` / `IMAGEM` / `SOM`) |
| `DESTAQUE` | `#8a2f1f` | foco / seleção / SAIR (destructive) / barra esquerda de foco |
| `PAPEL` | `#e6dfc4` | fill da folha e da placa dos pauzinhos (idle) |
| `PAPEL_ABERTO` | `#f4e7cc` | placa dos pauzinhos com painel aberto (já no código) |
| `PAPEL_SOMBRA` | `rgb(0.05,0.04,0.03) α 0.45` | offset **+2,+2** duro sob papel |
| `PAPEL_LUZ` | `× (1.24, 1.19, 1.06)` | só se a folha usar textura `ui_papel`; fill chapado `#e6dfc4` dispensa |
| `SCRIM` | `rgb(0.02,0.02,0.03) α 0.55` | full-screen atrás da folha (não é glass) |
| `FOCO_STAIN` | preto **α 0.07–0.10** | retângulo de linha focada (mancha de tinta, não vidro) |

Contraste mínimo texto `TINTA` sobre `PAPEL`: manter; não clarear papel sob vinheta — preferir subir camada ou andar para dentro.

### 1.2 Tipo

| papel | fonte | size nativo | line height | uso na folha |
|---|---|---|---|---|
| Título de página | `psx_media` / título curto | **14** (nativo media) | ~16 | `SISTEMA`, `IMAGEM`, `SOM` |
| Linha de menu | `psx_pequena` | **11** | **13** | itens + valores |
| Dica / footer | `psx_pequena` | **11** | **13** | `[W/S]…` em `TINTA_FRACA` |
| Cursor | mesmo glyph em **todas** as listas | — | — | `>` à esquerda do foco (playbook §5) |

Sem escala não-inteira. Sem monospace “debug” como voz principal (barra `[####....]` ok só em valores VIDEO/AUDIO).

### 1.3 Espaço

| token | px | nota |
|---|---|---|
| `MARGEM` | 7 | safe area |
| `PAD_FOLHA` | **12** | atual `menu_sistema.PAD` — manter |
| `VAO_LINHA` | **2** | atual `VAO` |
| `GAP_SECAO` | **6** | **novo** — respiro entre grupos (CONTINUAR vs settings vs SAIR) |
| `REGUA` | **1** | underline do título / divisores |
| `PAPEL_BORDA` | **1** | contorno tinta |
| `SOMBRA_OFF` | **2** | offset sombra dura |
| `HIT_LINHA_MIN` | **14** | max(13 line, 14) — mouse parity P0 |
| `HIT_ABA_MIN` | **32** | playbook P0 (24–32); hoje placa visual 18×14 é fraca |

### 1.4 Tempo (só referência visual; Motion UI detalha)

| evento | ms | nota |
|---|---|---|
| Open/close folha | 120–200 | UI-BIBLE / playbook P2 |
| Page swap | 120–160 | slide 4–8 px ou fade papel |
| Focus move | ≤ 100 | stain + SFX |

---

## 2. Aba pauzinhos (P0 affordance)

### 2.0 Contrato A11y da aba (PO §11 — aprovado)

| regra | spec |
|---|---|
| Look | **3 barras finas** (chip papel opcional; não precisa virar botão gordo) |
| Hit | **retângulo invisível ≥ 32×32** — maior que o desenho; mouse/gamepad usam o hit, não o bitmap |
| Hoje | `PAUZINHOS = Rect2(448, 19, 18, 14)` — só visual/histórico; **não** é o hit alvo |
| Alvo hit | `Rect2(441, 14, 32, 32)` (ou equivalente centrado nas barras) |
| Wiring P0 | **fora do escopo visual** — anotar só: Start/ESC canônicos; aba = atalho secundário |
| Focus visual | barra 2px + cursor `>` (não só troca de cor) — Motion 80–250ms |
| Glass | proibido |



### 2.1 Estado atual (código / `f4_pauzinhos` / `_zoom_pauzinhos`)

| | |
|---|---|
| `PAUZINHOS` | **Rect2(448, 19, 18, 14)** |
| Barras | 3 × **18×3**, passo Y **5** |
| Placa desenhada | `grow(4)` → visual ~**26×22** @ ~(444,15) |
| Camada | acima do pós |
| Problema | hit/affordance ainda “três riscos”; AAA pede chip legível ≥ 24–32 |

### 2.2 Spec alvo

```
TELA 480×270
┌─────────────────────────────────────────────┐
│                              ┌────┐ ← placa │
│                              │ ≡≡≡ │   hit  │
│                              └────┘  32×32  │
```

| elemento | px (TELA) | token |
|---|---|---|
| **Hit target** | **32 × 32** @ **(441, 14)** | `HIT_ABA_MIN`; fica a ≥7 da borda (441+32=473; 14≥7; 270−14−32=224 ok) |
| **Placa visual** | **22 × 18** centrada no hit (offset +3,+5) | fill `PAPEL` / `PAPEL_ABERTO`; borda 1 `TINTA` |
| **Barra** | **14 × 2** | 3 barras; gap vertical **3**; centradas na placa |
| Sombra placa | +1,+1 (menor que folha — canto) | `PAPEL_SOMBRA` α ≤ 0.35 |

**Estados**

| estado | placa | barras | borda |
|---|---|---|---|
| idle | `PAPEL` | `TINTA` | `TINTA` 1 px |
| hover / focus gamepad | `PAPEL` | `TINTA` | `DESTAQUE` 1 px |
| painel aberto | `PAPEL_ABERTO` | `TINTA` | `TINTA` |
| pressed (1 frame) | `PAPEL` × 0.92 luma | `TINTA` | `TINTA` |

**Não fazer:** ícone engrenagem metálica, badge neon, círculo, sombra blur.  
**Fazer:** chip de **papel grampeado** — hamburger clássico, irmão da prancha.

**Mouse:** hit 32×32; tecla W permanece (A11y fecha contrato).  
**SFX:** abrir `papel`; toggle `clique` (já no código).

---

## 3. Folha — geometria comum

### 3.1 Caixa (manter âncora atual — já centrada)

| | atual | spec |
|---|---|---|
| X | 146 | **146** `(480−188)/2` |
| Y | 44 | **44** |
| L | 188 | **188** |
| H | dinâmica | dinâmica via conteúdo (abaixo) |
| Fill | `#e6dfc4` | `PAPEL` |
| Borda | 1 `TINTA` | idem |
| Sombra | +2,+2 | `SOMBRA_OFF` + `PAPEL_SOMBRA` |
| Scrim | α 0.55 | `SCRIM` full `TELA` |

### 3.2 Anatomia vertical (topo → base)

```
y0 = FOLHA_Y + PAD                    # 44+12 = 56
[ TÍTULO ]                            # line 14–16, TINTA_TITULO
[ régua 1px ]                         # +4 após baseline título
y_lista = após régua + VAO            # início das linhas
… linhas / seções …
[ dica footer ]                       # baseline ≈ folha.bottom - PAD + 3
```

Fórmula de altura (alvo, legível para Dev):

```
H = PAD
  + lh_titulo + 4 + 1                 # título + gap + régua
  + VAO
  + Σ (HIT_LINHA + VAO) por linha
  + Σ GAP_SECAO por divisor
  + lh_dica + PAD
```

(`_linha` atual ≈ 13 com `psx_pequena`.)

### 3.3 Linha de item

| parte | px |
|---|---|
| Altura hit | **14** |
| Texto | PAD esquerdo **12** (folha) |
| Glyph `>` foco | x = folha.x + PAD − **7** |
| Stain foco | x = folha.x + PAD − **4**, w = L − 2·PAD + **8**, h = **14**, α **0.08** |
| Barra foco (novo) | **2 × 10** @ x = folha.x + **4**, centrada na linha, `DESTAQUE` |
| Valor à direita (VIDEO/AUDIO) | alinhado `folha.right − PAD`; `TINTA_FRACA` |

**Estados de linha**

| | texto | extras |
|---|---|---|
| idle | `TINTA` | — |
| focus | `DESTAQUE` | `>` + stain + barra 2 px |
| disabled | `TINTA_FRACA` | sem stain; não foca (ou foca e explica) |
| destructive focus (`SAIR…`) | `DESTAQUE` | mesma barra; opcional stain α 0.10 |

---

## 4. Folha RAIZ (`Pagina.RAIZ` → título **SISTEMA** (pause-root — nunca OPCOES/OPÇÕES/PAUSA; hold Dev até Jamerson confirmar))

### 4.1 Conteúdo (ordem = código atual)

**Default:** `_sel` inicial = índice de `CONTINUAR` (sempre focado ao abrir). Visual: stain + `>` + barra 2px `DESTAQUE` já no idle de abertura — é o único item com “peso de Retomar”.



1. `CONTINUAR` — ação  
2. `CARREGAR` — nav → CARREGAR (disabled se sem save)  
3. `IMAGEM` — nav → VIDEO  
4. `SOM` — nav → AUDIO  
5. `SAIR PARA O TITULO` — **destructive**: cor `DESTAQUE` mesmo idle; no focus, stain α0.10 + barra; tipografia mesmo size, tinta mais quente (não bold falso — bitmap). Modal confirm = P1 (fora desta spec).  

### 4.2 Hierarquia visual (P0 — sair da “lista debug”)

```
┌──────────────────── 188 ────────────────────┐
│ SISTEMA                                       │  TINTA_TITULO
│ ─────────────────────────────────────────── │  régua 1px TINTA
│ > CONTINUAR                                  │  grupo A — ação primaria
│   CARREGAR                                 ▸ │
│ · · · · · · · · · · · · · · · · · · · · · · │  GAP_SECAO 6 + hairline
│   IMAGEM                                   ▸ │  grupo B — settings
│   SOM                                      ▸ │
│ · · · · · · · · · · · · · · · · · · · · · · │  GAP_SECAO 6 + hairline
│   SAIR PARA O TITULO                         │  grupo C — destructive
│                                              │
│ [W/S] mover  [E] escolher                    │  TINTA_FRACA
└──────────────────────────────────────────────┘
```

- **Chevron `▸`** (ou `>`) só em itens que abrem página — reforça IA sem ícones bitmap novos.  
- Hairline entre grupos: 1 px `TINTA_FRACA`, inset PAD, **não** full-bleed.  
- Sem ícones ilustrados nesta entrega (escopo tokens+px); Motion/Dev podem animar página depois.

### 4.3 Altura alvo RAIZ

5 linhas × (14+2) + 2× GAP_SECAO(6) + 2 hairlines(1) + título block(~21) + footer(~13) + 2×PAD(24)  
≈ **5×16 + 12 + 2 + 21 + 13 + 24 ≈ 152 px** → folha ~**Rect2(146, 44, 188, 152)** (±4 conforme fonte real).

---

## 5. Folha VIDEO (UI title **IMAGEM**, enum `Pagina.VIDEO`)

### 5.1 Linhas (`OpcoesLista.video()` — não renomear aqui)

| # | rótulo | tipo | grupo visual |
|---|---|---|---|
| 1 | `ESTILO` | enum | **PRESET** (eyebrow opcional 1 linha `TINTA_FRACA` “PRESET” 8–10 px acima, ou só peso: stain mais largo) |
| 2 | `RESOLUCAO 3D` | enum | fine |
| 3 | `NEVOA` | enum | fine |
| 4 | `GRAO` | barra `[####......]` | **CRT** |
| 5 | `ABERRACAO` | barra | CRT |
| 6 | `SCANLINE` | barra | CRT |
| 7 | `VINHETA` | barra | CRT |
| 8 | `DITHER` | toggle LIGADO/DESLIGADO | CRT |

Divisor após `ESTILO` e após `NEVOA` (GAP_SECAO + hairline).

### 5.2 Layout

```
IMAGEM
──────
  ESTILO              PSX ……        ← master (hot-apply)
···············
  RESOLUCAO 3D     480 x 270
  NEVOA            NEBLINA…
···············
  GRAO             [#######...]
  ABERRACAO        [####......]
  SCANLINE         [#######...]
  VINHETA          [#######...]
  DITHER           LIGADO
[A/D] ajustar  [Q] voltar
```

- Barras: monospace/`psx_pequena`, 10 slots — manter diegese CRT (playbook preview P2 = depois).  
- Título página = **IMAGEM** (string atual), não “VIDEO”.  
- H alvo ~ **8×16 + 2×6 + 2 + título + footer + pads ≈ 200 px** — ainda cabe sob vinheta central.

---

## 6. Folha AUDIO (UI title **SOM**, enum `Pagina.AUDIO`)

### 6.1 Conteúdo

Uma linha por bus em `Settings.BUSES`, rótulo `BUS_ROTULO` upper — **não hardcodar lista** nesta spec.

Padrão visual idêntico a VIDEO (label esq + `[####......]` dir).

```
SOM
───
  MASTER           [########..]
  MUSICA           [######....]
  SFX              [#######...]
  …                …
[A/D] ajustar  [Q] voltar
```

Se existir bus master, **primeira linha**; sem grupo extra se N≤4; se N≥5, hairline após o primeiro (master vs resto).

H = f(N) com mesma fórmula da §3.2.

---

## 7. StyleBox / Godot (orientação — sem implementar)

| peça | abordagem |
|---|---|
| Folha | `StyleBoxFlat`: bg `PAPEL`, border 1 `TINTA`, **corner 0**, sem shadow blur; sombra = segundo rect +2,+2 |
| Scrim | `ColorRect` full screen `SCRIM` **ou** `draw_rect` — opaco, não shader blur |
| Aba | draw imediato (já é) ou StyleBoxFlat 0 radius na placa |
| Focus | não usar `StyleBox` glow; stain + barra + `>` |
| Theme | reutilizar tintas `UiEstilo`; não criar paleta paralela |

---

## 8. Diff vs refs (o que a captura deve mostrar depois)

| ref | hoje | depois (QA) |
|---|---|---|
| `f4_pauzinhos` | riscos 18×14 | chip 22×18 dentro hit 32×32; borda legível no zoom |
| `f4_raiz` | 5 linhas chapadas + `>` | 3 grupos + hairlines + chevron só em nav |
| `f4_imagem` | lista flat ESTILO…DITHER | ESTILO destacado + 2 divisores |
| `f4_som` | buses flat | mesma tipografia/valores; master primeiro |

CRT global (grain/scanline/vinheta) **permanece no pós** — a folha não redesenha scanline.

---

## 9. Entrega / DoD desta spec

- [x] Tokens nomeados batendo UI-BIBLE / `UiEstilo`  
- [x] px na TELA 480×270 para aba + 3 folhas  
- [x] Hierarquia RAIZ (P0)  
- [x] Agrupamento VIDEO (preset / fine / CRT)  
- [x] AUDIO = buses Settings  
- [x] Explicitamente **sem glass**
- [x] Hit **invisível** ≥32×32 com look de 3 barras finas (A11y §11)
- [x] Nota: P0 wiring (Start/ESC) ≠ visual  
- [ ] Aprovação **Jamerson** (emendas 1–2) → PO libera → Godot UI Dev implementa (**hold Dev agora**); Motion/A11y complementam tempos e hit/focus neighbors  

**Fora de escopo agora:** página CONTROLES, mouse hit no título, preview live dos sliders (P1/P2 playbook).

---

*Visual Design — papel/CRT. Próximo passo: PO aprova números; Dev consome sem inventar cor.*

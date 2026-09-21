# SPEC_POLISH_TIPO_LAYOUT_RE7
**Agente:** PSX Visual Design · **P0 urgente** · **19/09/2026**  
**Contrato mãe:** `SPEC_VISUAL_RE7.md` (APROVADA PO)  
**Baseline:** prints prancha + SOM (`aaa_dev/aaa_som.png`, `aaa_raiz_sistema.png`)  
**TELA:** **480 × 270** px lógicos  
**Mandato:** elevar tipografia + layout **sem matar** identidade scrapbook (papel, fita, polaroid, leve tilt). **Sem código.**

---

## 0. Princípio

| manter (scrapbook) | elevar (RE7 polish) |
|---|---|
| Papel creme, fita, polaroid | Sans limpa (não pixel) |
| Leve rotação ±1–2° nos cartões | Escala tipográfica rígida + tracking |
| Faixa de itens no topo | Densidade/ritmo medidos; safe area |
| IDENTIDADE + STATUS como “colados” | Contraste tinta/papel AA; LED vitals no STATUS |
| Modal SOM/SISTEMA centrado | Hierarquia display→micro; margens consistentes |

**Não fazer:** HUD glass flat; matar fita/papel; voltar bitmap PSX; lotar a prancha.

---

## 1. Safe area

| zona | px | regra |
|---|---|---|
| Safe outer | **inset 8** de cada borda | nenhum texto crítico / hit / LED fora |
| Safe hard | **inset 4** | só sombra/fita/vinheta podem invadir 4–8 |
| Modal safe | centro; margem ≥ **24** até borda da TELA | |
| Bottom hints | baseline ≤ **270 − 10** = y≤260 | micro só |
| Top title | baseline ≥ **8 + ascent** | display não cola na borda |

Hit mínimo continua **32×32** (aba ≡ / setas se clicáveis).

```
(0,0)                    480
  ┌─8px safe─────────────────┐
  │                          │ 270
  │   conteúdo scrapbook     │
  │                          │
  └──────────────────────────┘
```

---

## 2. Escala tipográfica (px TELA 480×270)

Face: **sans grotesk/humanista** (1 família, 2 pesos: Regular + SemiBold). Sem pixel font nesta superfície.

| token | size px | weight | line-height | tracking | uso |
|---|---|---|---|---|---|
| `TYPO_DISPLAY` | **18** | SemiBold | 22 | **+40** (≈ +2.2%) | `INVENTÁRIO` (só faixa título) |
| `TYPO_TITLE` | **14** | SemiBold | 18 | **+20** | `IDENTIDADE`, `SOM`, `SISTEMA`, `STATUS` label |
| `TYPO_BODY` | **11** | Regular | **14** | **0** | corpo doc, rows de lista modal |
| `TYPO_MICRO` | **9** | Regular | 11 | **+40** | hints `[A/D]`, footer, glyphs bus |
| `TYPO_VITAL` | **10** | SemiBold | 12 | **+60** | só se label ao lado do LED; preferir LED sem texto |

### 2.1 Regras de caixa
- DISPLAY / TITLE de painel: **VERSÃO ALTA** curta (1 palavra).
- BODY do documento: **sentence case** PT-BR, máx **4 linhas** × ~28–32 glyphs (ver §4).
- MICRO: alta ou glyphs `[A/D]` ok; nunca DISPLAY size em hint.

### 2.2 Tracking (detalhe)
| contexto | tracking | por quê |
|---|---|---|
| DISPLAY no cork | +40 | respira sobre textura suja |
| TITLE em papel | +20 | evita “bloco pixel” sem parecer letterspaced fashion |
| BODY | 0 | leitura |
| MICRO | +40 | uppercase pequeno illegible sem ar |
| Modal row focus | 0 | não dançar com o stain |

### 2.3 Contraste no papel scrapbook

Papel base `DOC_PAPER` ≈ `#d8d0c0` (creme).

| par | fg | bg | alvo |
|---|---|---|---|
| Title doc | `DOC_INK` `#2a2420` | papel | ≥ **7:1** |
| Body doc | `DOC_INK` `#2a2420` | papel | ≥ **4.5:1** |
| Micro em papel | `#4a443c` | papel | ≥ **4.5:1** (não usar `#8a8680` *sobre creme*) |
| Title modal escuro | `TEXT_TITLE` `#e8e2d6` | `PANEL_BASE` | ≥ **4.5:1** |
| Body modal | `TEXT_PRIMARY` `#d6d2c8` | panel | ≥ **4.5:1** |
| Micro modal/hints | `TEXT_MUTED` `#8a8680` | panel **ou** cork escuro | ≥ **3:1** UI large; preferir `#a29e96` se falhar |
| Accent focus | `ACCENT` `#b85a42` | papel ou panel | foco = accent **+** barra/`>` — nunca só cor |
| Vital LED | `VITAL_*` emissivo | cork escuro | LED carrega; texto “BEM” **não** substitui LED |

**Proibido:** cinza médio `#8a` em body sobre creme; branco puro `#fff` no papel; outline 2px preto em sans.

---

## 3. Anatomia da prancha — densidades

### 3.1 Faixa superior (itens)

| prop | px |
|---|---|
| Title `INVENTÁRIO` | centro X; baseline **y = 20** (`TYPO_DISPLAY`) |
| ≡ sistema | hit **32×32** @ canto dir safe: x=480−8−32=**440**, y=**8** |
| Faixa slots Y | **28 → 60** (altura útil **32**) |
| Slot | **28×28**, gap **4**, **8** visíveis |
| Setas | **20×28** fora do pack de slots |
| Pack width | 8×28 + 7×4 = **252**; + setas 40 + gaps 8 ≈ **300** centrado |
| Margem lateral pack | ≥ **90** cada lado (cork respira) |
| Separação title→slots | **8** (baseline 20 → slot top 28) |

Densidade: **não** encher 12 slots visíveis; 8 + setas = ritmo RE/scrapbook.

### 3.2 Painel IDENTIDADE (doc scrapbook)

| prop | px |
|---|---|
| Rect externo | **156 × 118** |
| Pos | x=**14**, y=**128** (abaixo da faixa; acima do safe bottom) |
| Rotação | **−1.5°** (fixo; âncora centro) |
| Pad interno | **10** L/R/T, **8** B |
| Fita | 2× (~22×8) no topo, overflow 4px ok na safe soft |
| Title | `TYPO_TITLE`, underline 1px @ +2px |
| Corpo | `TYPO_BODY`, width útil **136**, máx **4 linhas**, line-height 14 → bloco ≤ **56** |
| Gap title→body | **6** |
| Gap body→ações | **8** |
| Botões USAR / EXAMINAR | **62 × 16** cada, gap **6**, alinhados bottom pad |
| Hit botão | altura efetiva **≥ 18** (pad hit invisível +1) |

Conteúdo: 4 linhas × ~30 chars; se overflow → ellipsis, **não** reduzir font.

### 3.3 Polaroid + STATUS

| prop | px |
|---|---|
| Polaroid outer | **100 × 116** (foto 88×88 + margem branca) |
| Pos | x=**366**, y=**120** |
| Rotação | **+1.2°** |
| Margem branca foto | **6** top/sides, **18** bottom (pé da polaroid) |
| STATUS LED cluster | sob polaroid ou no pé: **48 × 8** @ centro do pé |
| Label STATUS | opcional `TYPO_MICRO` `#4a443c` acima do LED **dentro** do pé; **não** “BEM” display verde pixel |
| Distância IDENTIDADE↔polaroid | gap horizontal ≥ **20** (não colar) |

### 3.4 Zona central (sob faixa / entre cartões)

Reservada a:
- Modal (SOM/SISTEMA/IMAGEM), **ou**
- Inspeção 3D (quando EXAMINAR)

Sem modal: cork visível; **não** colocar terceiro cartão de texto.

### 3.5 Modal (referência de densidade)

| prop | px |
|---|---|
| SOM / SISTEMA | **204 × 152** centrado |
| Pad | **12** |
| Title | `TYPO_TITLE` + filete |
| Row | h **16**, gap **2** → ritmo 18 |
| Footer micro | pad bottom **8**, `TYPO_MICRO` |

---

## 4. Ritmo vertical (summary)

```
y=0..8     safe
y=8..24    DISPLAY inventário + ≡
y=28..60   faixa slots
y=60..120  cork / respiração (modal pousa aqui se aberto)
y=120..246 IDENTIDADE + polaroid/STATUS
y=246..260 micro hints
y=260..270 safe
```

---

## 5. Densidade — limites

| métrica | alvo | teto |
|---|---|---|
| Cartões scrapbook simultâneos | 2 (doc + polaroid) | 3 (só se quest slip micro) |
| Linhas body IDENTIDADE | 3–4 | 4 |
| Slots visíveis | 8 | 8 |
| Tamanhos de fonte na tela | 4 tokens | ≤4 (não inventar 15px “entre”) |
| Rotação cartão | ±1–2° | ±3° |

---

## 6. Checklist QA (print 480×270)

- [ ] Nada crítico fora do inset 8  
- [ ] `INVENTÁRIO` = 18px; IDENTIDADE/SOM = 14; body = 11; hints = 9  
- [ ] Body no creme usa `#2a2420` (não cinza muted de panel)  
- [ ] IDENTIDADE 156×118 @ (14,128); polaroid 100×116 @ (366,120); gap ≥20  
- [ ] Faixa slots y 28–60; 8×28 gap 4  
- [ ] ≡ hit 32×32  
- [ ] Fita + tilt preservados  
- [ ] STATUS = LED, não wordart pixel  
- [ ] Modal não cobre botões USAR/EXAMINAR sem scrim claro  

---

## 7. Path / handoff

**Arquivo:** `docs/specs/SPEC_POLISH_TIPO_LAYOUT_RE7.md`  
**Consome:** Godot UI Dev (ondas 1–3) · Motion (não altera px) · A11y (contraste + hit)  
**Não drift:** qualquer size fora da tabela §2 exige RFC PO.

*PSX Visual Design — polish tipográfico/layout scrapbook RE7. Sem código.*

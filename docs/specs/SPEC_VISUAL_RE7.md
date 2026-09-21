# SPEC_VISUAL_RE7 — Inventário / Prancha / Overlay (épico RE7)
**Agente:** PSX Visual Design  
**Data:** 19/09/2026  
**Pivô Jamerson:** abandonar pixel/lo-fi. Menus = AAA diegéticos sujos (inspiração *Resident Evil 7*), não UI PS1.  
**Baseline de referência:** prints `aaa_dev/aaa_som.png` (prancha + placeholder SOM) e `aaa_raiz_sistema.png` (estrutura espacial).  
**Status:** **APPROVED** PO (19/09/2026) · **Escopo:** tokens · grid · tipografia · materiais · vitals · inspeção 3D · proibições. **Sem código.**

---

## 0. Contrato

| regra | valor |
|---|---|
| TELA lógica | **480 × 270** (render interno; UI desenha em espaço lógico, depois upscale) |
| Tom | survival horror doméstico — plástico sujo, vidro fosco sujo, LED enfermo |
| Tipografia | **sans humanista/grotesk limpa** (não bitmap pixel) |
| Distorção | **shader leve** no overlay (warble/CA/grain), não “filtro PSX” chapado |
| Inventário | **grid translúcido** (slots), não filmstrip pixel |
| Inspeção | **viewport 3D** do item (órbita), não ícone 2D estático como único examine |
| Vitals | **emissivos** (LED/segmento), não texto bitmap “BEM” chapado |
| Relação c/ spec anterior | `SPEC_VISUAL_PAUZINHOS_FOLHAS` + AAA-RE = overlay **SISTEMA** (lista). **Esta spec** governa **prancha/inventário + shells de settings** no look RE7. Hierarquia SISTEMA/CONTINUAR/SAIR/hit≥32 **permanece** em comportamento; a pele visual da prancha muda aqui. |

---

## 1. O que o baseline ensina (e o que matar)

### 1.1 Manter (layout mental)
- Prancha = mesa de evidências: item ativo + documento + retrato + atalho sistema
- Faixa superior de itens + setas
- Documento à esquerda (título + corpo + ações USAR/EXAMINAR)
- Retrato/status à direita
- Folha modal centrada para SOM/IMAGEM/SISTEMA

### 1.2 Matar (lo-fi)
- Fonte pixel / stair-stepping em label
- Filmstrip “contato fotográfico” como linguagem única
- Ícones chunky 16×16 sem lighting
- Painel settings 100% opaco papel craft sem profundidade
- Status “BEM” tipográfico bloco no meio da cena
- CRT pesado *dentro* da UI (vinheta/CA extremos no painel)

---

## 2. Tokens — cor

Paleta **fria-suja** (RE7: teal doentio + âmbar de emergência + creme sujo). Hex lógicos em espaço linear sRGB.

| token | hex | uso |
|---|---|---|
| `BG_VOID` | `#0a0c0e` | letterbox / além da prancha |
| `SCRIM` | `#070809` @ **0.55–0.70** | atrás de modal; **opaco o bastante** — não frost barato |
| `PANEL_BASE` | `#1a2224` @ **0.78–0.88** | corpo de painel / grid (translúcido escuro) |
| `PANEL_EDGE` | `#8a9a90` @ 0.35 | filete 1px externo |
| `PANEL_DIRT` | multiply noise `#3a3028` @ 0.15–0.25 | mancha/sujidade no material |
| `SLOT_EMPTY` | `#12181a` @ 0.65 | célula vazia |
| `SLOT_FILL` | `#243033` @ 0.80 | célula com item |
| `SLOT_FOCUS` | `#c4a574` | borda foco slot (âmbar sujo) |
| `TEXT_PRIMARY` | `#d6d2c8` | labels sans |
| `TEXT_MUTED` | `#8a8680` | dicas / secundário |
| `TEXT_TITLE` | `#e8e2d6` | títulos de painel |
| `ACCENT` | `#b85a42` | focus lista / USAR / destructive quente |
| `ACCENT_HOT` | `#d46a48` | press / emissivo UI quente |
| `VITAL_OK` | `#5cff9a` | LED vida ok (emissivo) |
| `VITAL_WARN` | `#ffc857` | LED atenção |
| `VITAL_CRIT` | `#ff4a3a` | LED crítico + pulse lento |
| `TAPE` | `#c2a060` @ 0.9 | “fita” diegética (mínima — 2–3 peças, não scrapbook total) |
| `DOC_PAPER` | `#d8d0c0` @ 0.92 | folha de documento (quase opaca) |
| `DOC_INK` | `#2a2420` | texto do documento |

**Proibido na paleta:** neon ciano limpo, magenta UI, branco 100%, preto UI puro sem ruído, verde “matrix”.

---

## 3. Tokens — tipografia

| papel | face | size lógico (480×270) | tracking | uso |
|---|---|---|---|---|
| Display | Sans semi-bold (ex. estilo *Inter/Helvetica-ish* no project) | **16–18** | +2% | `INVENTÁRIO`, títulos de modal |
| Title | Sans medium | **13–14** | 0 | `IDENTIDADE`, `SOM`, `SISTEMA` |
| Body | Sans regular | **11–12** | 0 | itens de lista, corpo doc (máx 4–5 linhas) |
| Micro | Sans regular | **9–10** | +4% | hints `[A/D]`, glyphs de bus |
| Vital | Sans condensed / LED mask | **10–12** | +8% | só se label ao lado do LED; preferir **só LED** |

Regras:
- **Nunca** bitmap `.fnt` pixel nesta superfície.
- Hinting: preferir render em **inteiros** de px lógico.
- Uppercase ok em títulos curtos; corpo do doc = sentence case PT-BR.
- Sem outline grosso; sombra de texto = drop 0,1 α0.6 no máximo.

---

## 4. Tokens — material & shader (overlay)

### 4.1 Camadas (de trás pra frente)
1. World (3D) escurecido  
2. Prancha diegética (mesa / metal / plástico)  
3. Grid inventário translúcido  
4. Documento + retrato  
5. Vitals emissivos  
6. Modal settings (SOM/IMAGEM/SISTEMA)  
7. Shader de **distorção leve** (full-screen UI pass, não em cada Control)

### 4.2 Distorção permitida (leve)
| efeito | dose | nota |
|---|---|---|
| Chromatic aberration | 0.4–0.8 px nas bordas | cai no centro |
| Warp/breath | ±0.15% UV, 0.05–0.08 Hz | “vidro barato” |
| Film grain | 3–6% luma | mono, não color noise festivo |
| Dirt mask | decals fixos 2–4 | cantos/painel, não animar rápido |
| Vignette | suave 0.25–0.35 | **não** zerar canto da UI crítica |

### 4.3 Proibido no shader UI
- Scanlines pesadas tipo CRT TV  
- Quantize 16-bit / dither forte  
- Posterize  
- Blur frosted tipo iOS  
- Glitch spam  

---

## 5. Layout grid — prancha (480×270)

```
         7px safe
┌──────────────────────────────────────────────────────┐
│ INVENTÁRIO                    [≡ sistema hit≥32]     │  y=8–24  title band
│ ◀  [s][s][s][s][s][s][s][s]  ▶                      │  y=28–60  GRID slots
│                                                      │
│  ┌ DOC 148×130 ┐     ┌ VITAL ┐   ┌ RETRATO 96×110 ┐ │
│  │ título       │     │ LED  │   │ viewport 3D /   │ │  y=68–210
│  │ corpo        │     │ bar  │   │ foto moldura    │ │
│  │ [USAR][EXAM] │     └──────┘   └─────────────────┘ │
│  └──────────────┘                                    │
│  hints micro                                         │  y=250–262
└──────────────────────────────────────────────────────┘
```

### 5.1 Faixa de slots (substitui filmstrip)
| prop | valor |
|---|---|
| Slot | **28 × 28** (célula) |
| Gap | **4** |
| Visíveis | **8** (+ setas 20×28) |
| Pos Y | **30** |
| Pos X início | centrado: `(480 − (8×28 + 7×4 + 2×24)) / 2` |
| Corner | **0–2 px** max (quase ortogonal) |
| Fill | `PANEL_BASE` / ícone item com lighting simples |
| Focus | borda 2px `SLOT_FOCUS` + stain interno α0.12 |
| Empty | cruz fina `TEXT_MUTED` α0.35 |

Translucidez: slots mostram a textura da prancha atrás (α 0.78–0.88) — **grid translúcido**, não papel opaco.

### 5.2 Documento (esquerda)
| prop | valor |
|---|---|
| Rect | **148 × 130** @ ~(16, 68) |
| Fill | `DOC_PAPER` + dirt leve |
| Fita | 2 peças `TAPE` (topo) — diegese mínima |
| Título | 13px `DOC_INK` |
| Corpo | 11px, máx 5 linhas, ellipsis |
| Ações | duas pills 60×16 — USAR (`ACCENT` quando focused), EXAMINAR (outline) |

### 5.3 Retrato / inspeção (direita)
| modo | spec |
|---|---|
| Idle | moldura 96×110, fundo `PANEL_BASE`, personagem ou item thumbnail |
| **EXAMINAR** | abre **inspeção 3D**: viewport 140×150 centrado (ou substitui retrato), órbita yaw/pitch, luz key+rim frias, fundo void α0.85 |
| Input | mouse drag / A-D orbit; Q fecha; zoom limitado 0.8–1.4 |

Item 3D usa material do mundo (PBR baixo), **não** ícone pixel upscaled.

### 5.4 Vitals emissivos (centro-direita / sob retrato)
Substituir tipografia “BEM”:

| elemento | spec |
|---|---|
| LED cluster | 3–5 segmentos 6×4 ou barra 48×6 |
| Glow | bloom **curto** (só no LED; radius ≤4px lógico) |
| Cores | OK / WARN / CRIT tokens |
| Label | opcional micro `ESTÁVEL`/`FERIDO` em `TEXT_MUTED` — LED é primário |
| Crit | pulse 1.2s ease, amplitude α 0.7↔1.0 |

---

## 6. Modal settings (SOM / IMAGEM / SISTEMA)

Baseline SOM = caixa creme opaca centrada. Alvo RE7:

| prop | valor |
|---|---|
| Size | **200 × 150** (SOM/IMAGEM); SISTEMA **188–200 × 150–160** |
| Pos | centrado `(480−W)/2`, `(270−H)/2 − 4` |
| Fill | `PANEL_BASE` α **0.90** + dirt |
| Edge | 1px `PANEL_EDGE` + sombra dura +3,+3 α0.5 (sem blur) |
| Title | 14px `TEXT_TITLE` + filete 1px abaixo |
| Row h | **16** (hit ≥14) |
| Focus | barra 2px `ACCENT` + stain α0.12 + `>` |
| Slider SOM | track 72×4, fill `ACCENT`, thumb 4×8 — **não** `[####....]` ASCII |
| Footer | micro hints `TEXT_MUTED` |

**SISTEMA (comportamento locked):** título `SISTEMA`; `CONTINUAR` default focus (hero stain); `SAIR…` em `ACCENT` idle; grupos ações / ajustes / saída.

**Hit pauzinhos/≡:** ≥ **32×32** invisível; look = ícone hamburger limpo 18×14 dentro do hit (sans bars, não pixel).

---

## 7. Estados & feedback visual

| estado | tratamento |
|---|---|
| Idle | texto `TEXT_PRIMARY`, slot sem borda quente |
| Focus | `ACCENT` + barra + stain (nunca só troca de cor) |
| Hover mouse | **= focus** (paridade A11y) |
| Disabled | `TEXT_MUTED` α0.45, sem stain |
| Destructive | `ACCENT`/`ACCENT_HOT` mesmo idle |
| Press | 80–150ms escurece stain; Motion ownership |

---

## 8. Proibições (checklist)

- [ ] Fonte pixel / bitmap PSX nesta superfície  
- [ ] Filmstrip lo-fi como language principal  
- [ ] Glassmorphism blur / frosted iOS  
- [ ] Glow RGB neon / outline arco-íris  
- [ ] Scanline CRT pesada no painel  
- [ ] ASCII meters `[####]` no SOM  
- [ ] Status só tipográfico sem LED  
- [ ] Examine só sprite 2D sem órbita 3D  
- [ ] Cantos > 4px / pills arredondadas “mobile”  
- [ ] Opacidade de painel < 0.55 (vira vidro barato)  

---

## 9. Entregáveis / DoD visual

1. Mock ou captura: prancha RE7 (grid translúcido + doc + vitals LED + retrato)  
2. Captura: SOM modal com sliders (não ASCII)  
3. Captura: inspeção 3D orbitável  
4. Captura: SISTEMA sobre prancha (CONTINUAR focused, SAIR hot)  
5. Tokens acima refletidos em `UiEstilo` *quando* Dev implementar (fora desta spec)  

**Baseline a superar:** `aaa_som.png` / `aaa_raiz_sistema.png`.

---

## 10. Handoff

| equipe | usa |
|---|---|
| Motion | distorção breath + open modal 150–250ms + LED pulse; sem glow de focus |
| A11y | hit 32; hover=focus; contraste TEXT_PRIMARY vs PANEL ≥ AA em captura |
| Godot Dev | consumir após PO; sem código nesta entrega |
| Docs | apontar playbook: épico RE7 governa prancha; comportamento SISTEMA locked |

*PSX Visual Design — SPEC_VISUAL_RE7.md — sem código.*

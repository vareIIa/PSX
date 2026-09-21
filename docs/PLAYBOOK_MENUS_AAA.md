# PLAYBOOK MENUS AAA — PSX
> Consolidador: Docs Lead. Atualizado 19/09/2026 (pivô RE7).
> Fonte de verdade para bots. Repo: `C:\Users\Administrator\Documents\Codes\Games\PSX`
> Canais: `PSX Menus War Room`, `PSX Menus Specs`.
> Brief curto: `docs/BRIEF_AAA_MENUS.md`. Inventario legado: `docs/INVENTARIO_MENUS.md`. Inventario RE7: `docs/INVENTARIO_MENUS_RE7.md`.

## 0. Missao
**Direcao canônica (19/09/2026):** épico **UI RE7** — `docs/EPICO_UI_RE7.md` (sem duplicar aqui). Survival horror overlay; mundo 3D continua; tipografia sans moderna; inventário grid; UIManager push/pop. **HARD:** sem Git; evitar Casa da Fumaça.

### 0.0 Standing order (Jamerson jogando)
**LIVE AAA FECHADO.** Headless **LIMPO** · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid **OFF** · P1b hairline **pending**. Sem Git.
**MENU AAA CÓDIGO-COMPLETE** · P0 C–L (código)=**PASS** · L assets stems **pending**.

### 0.1 Ondas RE7 (ver épico · canal `PSX RE7 Epic`)
| Onda | Status | Owner |
|---|---|---|
| 1 Fundação overlay | **ACEITE CONDICIONAL** (Jamerson/PO2) | Godot UI Dev |
| **1b** Tipografia sans | **APPROVED** | Godot UI Dev |
| **POLISH_TIPO_LAYOUT** / P0 C | **PASS** | FONTE_P resolvido · Theme tokens PASS · **NO_GODOT_RUNTIME** |
| **POLISH_AUDIO_UI** / P0 D | **PASS** | Código OK · hooks AudioDirector fechados · playtest **HOLD** até GO Godot |
| **POLISH_CONTROLES_RE7** / P0 E | **PASS** | Slider PASS · StyleBox panel follow-up opcional (Jamerson) · NO_GODOT |
| **POLISH_PANEL_MOTION_RE7** / P0 F | **PASS** | `style_re7_panel` + focus Tween · playtest HOLD · NO_GODOT |
| 2 Inventário Grid + DnD | **APPROVED** (cena paralela) | **PSX Grid Inventory** · cutover **CANCELADO/ADIADO** |
| 3 Inspeção 3D + vitals | **MODULES=PASS** · **WIRE=PASS** | **PSX Diegetic 3D** · wire **PASS** |
| 4 Opções/Save/Áudio | **SAVE_CARDS_PREP=PASS** · wire **PASS** | **Save Cards** + **Audio UI** |
| **O4 SAVE ÁUDIO** | **PASS** | Código PASS · playtest HOLD · Audio UI |
| **A11Y_FOCUS_STACK** / P0 G | **PASS** | Path live · cutover grid **HOLD** · NO_GODOT |
| **menu.gd + título CARREGAR** | **PASS** | Limpeza legado PASS · NO_GODOT |
| **P1 MenuSistema nested** | **PASS** | Nested com `push_menu` PASS · NO_GODOT |
| **P0 H TIPOGRAFIA_MENU_GD** / FONTE_RE7_MENU_TITULO | **PASS** limpo | Tipografia `menu.gd` PASS · NO_GODOT |
| **P0 I TIPOGRAFIA_CRIACAO** | **PASS** | Tipografia RE7 `criacao`+`ficha_cadastro` PASS · NO_GODOT |
| **P0 J INSPECT_ORBIT_DAMP** | **PASS** | Owner **Diegetic 3D** · damp órbita PASS · NO_GODOT |
| **P0 K DOCUMENTO_RE7** / TIPOGRAFIA_DOCUMENTO | **PASS** | Tipografia documento RE7 PASS · NO_GODOT |
| **P0 L AUDIO_STEMS_UI** | **PASS** | Código PASS · art/assets stems canônicos pending |
| **P1b hairline** | **pending** | Pós LIVE AAA · grid OFF |

**MENU AAA CÓDIGO-COMPLETE** · **LIVE AAA FECHADO** · headless **LIMPO** · shots `aaa_live` · CARREGAR SaveCards **OK** · Onda3 runners **OK** · grid **OFF** · P1b hairline **pending** · Sem Git.

PO1 = Project Owner · PO2 = New Bot · Docs = Docs Lead.

### 0.2 Superficies / hooks (ainda vivos)
1. **Menu inicial** — `game/src/ui/menu.gd`
2. **Prancha / pause** — `game/src/ui/prancha_inventario.gd` (legado papel = baseline)
3. **Menu sistema (pauzinhos)** — `game/src/ui/menu_sistema.gd`

### 0.3 Baseline legado (Onda papel 1+1.5 APPROVED)
Prancha polaroid + SOM `####` + folha SISTEMA — caps `captures/ui/aaa_dev/`. Specs papel/CRT LOCKED = **referencia de comportamento** (focus, wiring, OpcoesLista), nao meta visual do épico RE7.

## 1. Mapa de arquivos (hooks para bots)

| Arquivo | Papel |
|---|---|
| `game/src/ui/menu.gd` | Boot CRT, titulo, opcoes (IMAGEM/SOM), saves, criacao — layer 150 |
| `game/src/ui/menu_sistema.gd` | Pauzinhos + folha RAIZ/VIDEO/AUDIO/CARREGAR in-game |
| `game/src/ui/prancha_inventario.gd` | Pause/inventario (layer 110); instancia MenuSistema; W abre sistema |
| `game/src/ui/opcoes_lista.gd` | **Fonte unica** `video()`+`audio()` — titulo E sistema leem daqui |
| `game/src/ui/opcoes_layout.gd` | Geometria medida da folha de opcoes (titulo) |
| `game/src/ui/titulo_layout.gd` | Geometria do titulo |
| `game/src/ui/carteira_layout.gd` | Criacao de personagem |
| `game/src/ui/travessia_curva.gd` | Curvas do START (plunge/lente) |
| `game/src/ui/ui_estilo.gd` / `UiEstilo` | Tokens legado + RE7 (SAFE/DOC_INK/TRACK/StyleBox/`aplicar_re7_*`) |
| `docs/specs/CHECKLIST_TOKENS_UIESTILO_RE7.md` | Checklist P0 Theme Tokens → Godot UI Dev |
| `game/src/systems/settings.gd` | Persistencia imagem/audio |
| `game/src/levels/cidade.gd` | Instancia menus + flags `--ver-*`; wiring `pediu_*` **DONE** (Onda 1) |
| `game/tests/checar_hud.gd` | Assertivas de layout |
| `docs/UI-BIBLE.md` | Contrato visual (Tempos §5, tokens) |
| `docs/BRIEF_AAA_MENUS.md` | Brief curto P0 + labels Settings |
| `captures/menu/*` | Refs boot/titulo/opcoes/saves (MODERNO+PS1) |
| `captures/ui/f4_*` | Refs pauzinhos + paginas do sistema |

## 2. Fluxos

### 2.1 Menu inicial
```
BOOT (PRESS START / travessia tubo)
  → TITULO (CONTINUAR / CARREGAR / NOVO JOGO / MAPA / OPCOES / SAIR)
      → CARREGAR (3 espacos + resumo SaveGame)
      → OPCOES pagina IMAGEM | SOM  (OpcoesLista)
      → carteira de criacao (NOVO JOGO)
```
Input: teclado + mouse nas placas do titulo (Fase C feita). Opcoes do titulo: **ainda sem mouse** (divida P0).

### 2.2 Pause / prancha
```
ESC ou TAB → PranchaInventario (get_tree().paused = true)
  → faixa de itens A/D, E/Q acoes
  → W (mover_frente) → MenuSistema.abrir()
  → ESC fecha prancha (se sistema aberto, sistema trata primeiro)
```
Dica na prancha: `[A/D] item  [E][Q]  [W] opcoes  [ESC] fechar`

Sinais emitidos pela prancha (wiring **DONE** em `cidade.gd` — Onda 1):
- `pediu_titulo` → voltar ao Menu/titulo
- `pediu_carregar(espaco)` → SaveGame.carregar + fechar prancha

### 2.3 Menu sistema (pauzinhos)
```
Aba 18×14 @ (448,19) — CanvasLayer ACIMA do pos (UiEstilo.CAMADA_ACIMA_DO_POS)
Painel FOLHA 188px @ (146,44) — altura dinamica; ABAIXO do pos
Paginas: RAIZ → VIDEO | AUDIO | CARREGAR
RAIZ: CONTINUAR · CARREGAR · IMAGEM · SOM · SAIR PARA O TITULO
```
Sinais MenuSistema: `continuar`, `sair_para_titulo`, `carregou(espaco)`
Flags: `--ver-pausa`, `--ver-pausa=imagem|som|carregar`

## 3. Inventario de opcoes (OpcoesLista — nao duplicar)

**VIDEO:** ESTILO · RESOLUCAO 3D (480×270…1280×720) · NEVOA · GRAO · ABERRACAO · SCANLINE · VINHETA · DITHER
**AUDIO:** um slider por bus em `Settings.BUSES` (blocos `[####......]`) — Master · Music · SFX · Ambiente

Qualquer bot que adicione ajuste **edita so** `opcoes_lista.gd` (+ Settings). Menus so desenham. Taxonomia de rotulos PT-BR = **pending** Settings IA (§16) — nao inventar aqui.

## 4. Dividas P0–P2 (prioridade para upgrade AAA)

> Evidencia UX Auditor + inventario codigo (19/09/2026). Wiring P0 **antes** de polish visual — senao embeleza botao morto.

### P0 — HARD / arcaico ao jogador

0. **P0 HARD — wiring `pediu_*` — DONE (Onda 1).** `PranchaInventario.pediu_titulo` e `pediu_carregar(espaco)` conectados em `cidade.gd`. Historico: antes emitidos sem listener (SAIR/CARREGAR mortos). Manter binds ao mexer na prancha.
1. **Pauzinhos** — aba `PAUZINHOS` 18×14 / barras 18×3 (`menu_sistema.gd` `:60`, `_desenhar_pauzinhos`). Affordance fraca + hit abaixo do minimo A11y (32px). Convite some na vinheta sem ler como "Opcoes".
2. **Folha RAIZ = lista chapada** — `>` + rect α0.07 (`:368–371`). Sem idle/focus/disabled/destructive. `SAIR PARA O TITULO` (`:208`) no **mesmo peso visual** de `CONTINUAR`.
3. **Titulo da pagina RAIZ imprime `OPCOES`** (`:350–351`) — modelo mental errado: RAIZ e pause-root (Retomar → …), nao settings. Aceite UX: titulo = verbo de pause-root (ex. SISTEMA / MENU), nunca OPCOES.
4. **`mouse_filter = IGNORE`** no painel e na aba (`:78`, `:128`) — zero paridade mouse na superficie de maior ROI.
5. **Opcoes do titulo sem mouse** (unica tela do fluxo inicial so-teclado).
6. **Sem pagina CONTROLES** no sistema (prometida no PLANO_UI Fase 4, nao entregue).
7. **Hierarquia tipografica** do painel = "lista de debug elegante", nao menu de produto (mesmo vocabulario de papel da prancha).

### P1 — rigor / teste
8. Mouse em Opcoes (titulo + sistema): hit areas por linha (≥32px altura, largura = linha).
9. Back ESC/Q ok (`menu_sistema.gd` `:278–282`), mas **sem restore de focus** na stack FILO ao voltar de IMAGEM/SOM/CARREGAR (`_ir_para` zera `_sel`).
10. Sem modal destrutivo em SAIR (peso tipografico/tinta ja e aceite minimo; modal = P1).
11. Cascata de entrada do titulo sem teste de curva (divida PLANO_MENU 3.1).
12. Carteira / opcoes nao fotografadas em todos os caminhos PS1 onde falta.
13. Gamepad nao exercitado nas frentes de menu.
14. CONTINUAR morto precisa sempre explicar por que (titulo ja faz; manter parity).

### P2 — polish AAA (sem quebrar PSX)
15. Transicoes de pagina (slide/fade 120–200 ms — ver §13 `T_PAGINA`).
16. Focus ring / cursor consistente (mesmo glifo + som em todas as listas).
17. Dica `[W/S]` na RAIZ enquanto `tratar` tambem aceita `ui_up/down` — glyphs estaticos; preferir glyphs dinamicos.
18. Agrupar VIDEO em preset vs fine-tune (ESTILO mestre ja existe — UI deve destacar; taxonomia pending Settings IA).
19. Safe area / vinheta: painel nunca no canto morto; aba ja sobe de camada (manter regra).
20. Localizacao-ready: strings fora de magia inline onde ainda houver.

### Contrato UX (aceitacao Visual/Motion — RAIZ + aba)
- CONTINUAR entra **default/focado**
- Secao implicita: acoes vs ajustes
- SAIR em estado **destructive** (peso/tinta; modal depois)
- Titulo de pagina = pause-root, **nunca** OPCOES
- Pauzinhos = atalho secundario, hit ≥32×32, legiveis com vinheta (`f4_pauzinhos`)
- Spec so — sem codigo ate PO aprovar Visual+UX

### Aceite Visual+Motion+UX (fatia pauzinhos+RAIZ — 19/09/2026) — **APPROVED PO**
> Status: **APPROVED** pelo Project Owner (canal PSX PO Menus). Escopo: Visual + Motion + A11y desta fatia.
> Godot UI Dev: **IMPLEMENTING** (Jamerson liberou AAA). Ordem §8. **Sem git**.
> Implementacao em curso no KernelOS-PC; specs locked — sem drift.

| criterio | aceite |
|---|---|
| Pauzinhos hit | **≥32×32** @ **(441,14)**; chip papel em `CAMADA_ACIMA_DO_POS` |
| Titulo pagina RAIZ | **`SISTEMA`** — nunca `OPCOES` / `OPÇÕES` |
| Default focus | **`CONTINUAR`** focado no 1º frame útil |
| Destructive | **`SAIR PARA O TITULO`** em tinta **`DESTAQUE`**; modal = **P1** |
| Focus visual | stain + barra **2px** + `>` (**sem glow**) |
| Motion tokens | `T_MENU_OPEN` **0,20** / `CLOSE` **0,14** / `PAGE` **0,16** / `FOCUS` **0,08** / `PRESS` **0,10** |
| A11y gate (ainda) | `mouse_filter` **STOP/PASS** nos hits; hover = mesmo focus |
| Specs | `docs/specs/SPEC_VISUAL_PAUZINHOS_FOLHAS.md` + `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` |

**P0 HARD** wiring `pediu_*` = **DONE** (Onda 1; §4 item 0) — manter binds; nao reabrir como divida.



### Onda 1 + 1.5 — **APPROVED** (PO · 19/09/2026)
> Status implementacao: **APPROVED sem ressalva P1** (UX re-check + PO).
> Caps: `captures/ui/aaa_dev/` (`aaa_pauzinhos*`, `aaa_raiz*`, imagem/som/carregar).
> Entrega Dev: wiring `pediu_*` em `cidade.gd`; pauzinhos hit≥32; RAIZ `SISTEMA`; CONTINUAR default; SAIR DESTAQUE; `T_MENU_*`; hover=focus; footer `[W] sistema`; sem leader lines (hairline secao reposicionada).

| | |
|---|---|
| **Fechado** | §4 locked + Onda 1 + Onda 1.5 P1 (leaders + footer) |
| **Divida — RE profundidade** | Addendum AAA-RE A.1/A.3 ainda fraco nas caps (scrim/sombra 2 degraus/filete/header band) — fila Onda 2 se Jamerson pedir |
| **Divida — mouse HIT_LINHA** | `HIT_LINHA_MIN=14` vs A11y ≥32 — onda mouse (nao fecha paridade) |

### Specs locked (fatia pauzinhos+RAIZ)
| Spec | Path | Status |
|---|---|---|
| Visual | `docs/specs/SPEC_VISUAL_PAUZINHOS_FOLHAS.md` | **LOCKED** (fonte Dev) |
| Motion | `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` | **LOCKED** (`T_MENU_*`) |
| A11y §11 | playbook §11 | **LOCKED** p/ onda mouse (hover=focus + `mouse_filter` STOP/PASS) |
| Addendum AAA-RE (PO) | `docs/specs/ADDENDUM_AAA_RE.md` | **APPROVED-ADDENDUM LOCKED** |
| Addendum AAA-RE Visual | `docs/specs/ADDENDUM_AAA_RE_VISUAL.md` | **APPROVED-ADDENDUM LOCKED** (+ appendix A in SPEC_VISUAL) |
| Addendum Motion §7 | `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` §7 | **APPROVED-ADDENDUM LOCKED** (`T_MENU_*` inalterados) |

Ordem de implementacao (legado papel — **fechado** Onda 1+1.5):
1. Wiring P0 (`pediu_*` em `cidade.gd`) — **DONE**
2. Visual desta fatia — **DONE**
3. Mouse (gate A11y) — divida
4. Motion (`T_MENU_*`) — **DONE** banda; RE profundidade = divida legado

**Nova fila:** `docs/EPICO_UI_RE7.md` — Onda 1 UIManager+shader **IMPLEMENTING**.

### APPROVED-ADDENDUM AAA-RE Visual (Jamerson · 19/09/2026)
Status: **APPROVED-ADDENDUM**. Base locked intacta; eleva polish (RE overlay weight). Links: `docs/specs/ADDENDUM_AAA_RE.md` + `docs/specs/ADDENDUM_AAA_RE_VISUAL.md` (+ appendix A in SPEC_VISUAL).
**P0 HARD** wiring `pediu_*` = **DONE** (Onda 1; §4 item 0).

| eixo | resumo (nao reabre base locked) |
|---|---|
| Folha | scrim α**0.55–0.62** + **2** shadow steps (+3/+1) + filete interno; L=**192**; header **22** / footer **18**; cantos **0** |
| Tipo | `SISTEMA` **14–16**; `CONTINUAR` hero; `SAIR` gap seção **10**; focus rico = stain α**0.10–0.14** + inset **1px** + barra **2px** + `>` |
| Aba | placa **24×20** moldurada dentro hit **32×32** @ **(441,14)** |
| Stagger | visual beats **0–5** → Motion consome `T_MENU_*` |
| Anti | glass/blur/neon; menu ≠ lo-fi PSX crunch (overlay de produto) |

## 5. Principios AAA aplicaveis (papel/CRT — nao copiar glass)

Alinhados com §10 (pesquisa + Brief). Resumo operacional:

- Hierarquia: titulo de pagina → secoes → linhas → dica de input sempre no rodape.
- Selection: estado idle / focus / disabled / destructive (SAIR) com contraste medido.
- Feedback: todo accept/adjust/back tem SFX + 1 frame de resposta visual (<100 ms).
- Settings IA: por tarefa do jogador (Imagem / Qualidade / Som / Controles) — nao por sistema do engine. Detalhe pending §16.
- Anti-padroes arcaicos: lista monospaca sem agrupamento; hit target < linha; teclas na dica que mentem; duas fontes de verdade para a mesma opcao; glass no papel; hops 3+.
- CRT: preferir valor/contraste a saturacao; bordas 1px tinta; evitar blur UI que mate pixel font.

## 6. Instrucoes por bot + STATUS

| Bot | Entrega | STATUS |
|---|---|---|
| **UX Auditor** | Gap P0–P2 com severidade + evidencia (arquivo:linha) | **entregue** (§4 + §15 + aceite fatia §4) |
| **Visual Design** | Spec tokens + mock textual folha RAIZ/VIDEO + aba pauzinhos (px da TELA) | **APPROVED** (fatia) + **APPROVED-ADDENDUM** AAA-RE Visual — `SPEC_VISUAL_*` + `ADDENDUM_AAA_RE_VISUAL.md` |
| **Motion UI** | Tabela tweens open/close/page/focus (UI-BIBLE Tempos) | **entregue + aprovado pacote fatia** + **APPROVED-ADDENDUM** §7 AAA RE-like — §13 + `SPEC_MOTION_*` (`T_MENU_*` inalterados) |
| **A11y Input** | Contrato teclado/mouse/gamepad + hit min + focus neighbors | **entregue** (§11 aprovado PO); fatia: mouse_filter STOP/PASS ainda gate |
| **Settings IA** | Taxonomia rotulos PT-BR + ordem linhas (RFC OpcoesLista) | **RFC** em `docs/RFC_OPCOES_LISTA_TAXONOMIA.md` — **aguarda OK PO/user** (nao marcar aprovado) |
| **Theme Tokens** | Tokens UiEstilo tipo/layout RE7 | **P0 PASS** (tokens) · P0 C **PASS** · NO_GODOT_RUNTIME |
| **Save Cards** | Save cards + thumbnail prep O4 | **PASS** (PREP) · wire **PASS** |
| **Docs Lead** | Consolida este playbook + UI-BIBLE PRs de texto | **em andamento** (patch fatia 19/09/2026) |
| **Godot UI Dev** | SO implementa apos Visual+UX aprovados pelo PO; reusa OpcoesLista | **IMPLEMENTING** — Onda 1+1.5 **APPROVED**; KernelOS-PC; **sem git**; proximas: RE profundidade + HIT_LINHA |
| **Menu QA** | Checklist captura `--ver-pausa*` + `--ver-partida` + regressao checar_hud | **entregue** mapa (§12); fotos HOLD pos-PR |

Excecao ao HOLD Godot: **P0 HARD wiring** `pediu_*` em `cidade.gd` pode (e deve) fechar antes de Visual — e bind, nao visual.

## 7. Definition of Done (qualquer PR de menu)
1. `--headless --quit` limpo
2. Captura da flag da tela + compare com `captures/`
3. Numeros citam UI-BIBLE
4. Tipagem estatica
5. Nenhuma duplicacao de lista de opcoes (`opcoes_lista.gd` unica)
6. checar_hud / testes de layout verdes
7. Mouse e teclado chegam no mesmo lugar (quando a tela for interativa)
8. Checklist §10 DoD 15 upgrades (quando a PR toca o item)

## 8. Ordem de execucao recomendada — **IMPLEMENTING**
**Fila ativa:** épico RE7 Onda 1 (`docs/EPICO_UI_RE7.md`) — UIManager + shader. Abaixo = historico papel APPROVED.
Status: Onda **1 + 1.5 APPROVED** sem ressalva P1 (19/09/2026). Dev no KernelOS-PC. **Sem git**.

| passo | status |
|---|---|
| 1. Wiring P0 `pediu_*` | **DONE** |
| 2. Visual fatia §4 | **DONE** (Onda 1) |
| 2b. Onda 1.5 P1 (leaders + footer SISTEMA) | **DONE / APPROVED** |
| 3. Mouse HIT_LINHA ≥32 + parity plena | **DIVIDA** (HIT_LINHA_MIN=14 hoje) |
| 4. Motion RE profundidade (addendum A.1/A.3 / §7 polish) | **DIVIDA** — Onda 2 se pedir |
| 5. Pagina CONTROLES | pending Settings RFC |
| 6. Paridade titulo ↔ sistema | pending |


## 9. Capturas de referencia obrigatorias
- `captures/ui/f4_pauzinhos.png`, `f4_raiz.png`, `f4_imagem.png`, `f4_som.png`, `f4_carregar.png`
- `captures/menu/titulo_*.png`, `opcoes_*.png`, `boot_*.png`, `saves_*.png`

Nao implementar "bonito" sem antes medir contraste no canto com vinheta.

## 10. Principios AAA pesquisa + Brief AAA + DoD 15

> Merge dos dois blocos §10 antigos (Principios pesquisa + Brief AAA) + `docs/BRIEF_AAA_MENUS.md`.
> Fontes: UX Collective, nastyrodent, IA settings PDF, Returnal PS Blog, Haas/Guerrilla HZD; pesquisa externa GoW Ragnarok, HZD, U4, Control, DS, Spider-Man, TLOU2 + sintese PO.
> Principio: copiar **comportamento** AAA; personalidade no material papel/CRT — nao glass.

### 10.1 Dez principios (pesquisa PO)
1. **Pause != dumping ground.** Topo = acoes frequentes (continuar; inventario ja esta na prancha). Settings no segundo nivel.
2. **UI map antes de arte.** Fluxo titulo ↔ opcoes ↔ sistema ↔ prancha = mesmos verbos (voltar, ajustar, confirmar).
3. **Settings por modelo mental do jogador:** Imagem / Qualidade / Som / Controles — nao por sistema interno do engine.
4. **Hot-apply** em audio/imagem (ja via Settings); confirmacao so em acao destrutiva (SAIR).
5. **Focus visivel + feedback <100 ms** (som + cursor). Mesmo glifo em todas as listas.
6. **Acessibilidade no fluxo**, nao ghetto separado (Returnal).
7. **CRT/retro:** paleta curta, flicker/on-off, sem camadas glass; legibilidade > efeito.
8. **Previews** quando o ajuste muda a cena (grain/scanline) — ideal no painel IMAGEM.
9. **Hit target e mouse parity** em toda tela interativa (titulo ja tem; opcoes/sistema nao).
10. **Style guide unico** (UI-BIBLE) — centesima tela igual a primeira.

### 10.2 Hierarquia (Brief AAA)
- Title: Continuar default/focado → Novo → Carregar → Opcoes → Creditos → Sair
- Pause: Retomar default → (Inventario = prancha) → Opcoes → Salvar/Carregar → Titulo
- Pauzinhos = atalho **secundario** a Opcoes; Start/ESC continua canonico
- Profundidade: ≤1 hop uso frequente; ≤2 ocasional

### 10.3 Motion (faixas Brief — detalhe operacional em §13)
| Tipo | ms | Notas |
|------|-----|-------|
| Press/focus | 80–150 | blink/cursor PSX |
| Highlight slide | 120–200 | cancelar tween anterior |
| Open panel | 150–250 | fade + leve deslocamento; ver `T_ENTRADA` 0,34 s |
| Close | 100–180 | mais rapido que open; ver `T_SAIDA` 0,40 s max bible |
| Input | — | nao espera >250 ms |

### 10.4 Focus / feedback
- Focus parity pad = mouse; restore no back (stack FILO)
- 3 canais: visual + SFX move + SFX confirm
- So a camada do topo recebe input

### 10.5 Settings labels (tarefa do jogador — Brief; taxonomia formal = pending Settings IA)
- IMAGEM / DISPLAY — resolucao, modo, vsync, brilho
- QUALIDADE / ESTETICA — preset + grain/scanline/vignette/dither (preview)
- SOM — master + buses, hot-apply
- CONTROLES — remap, sens, invert, deadzone (**ainda nao existe** — P1)
- A11y misturado onde o jogador procura o feature
- Hot-apply audio; Apply em resolucao; modal destrutivo; Defaults por categoria
- Settings no title **e** no pause

### 10.6 Tipografia CRT
Bitmap 2 tamanhos; contraste por luminancia; CRT intensity com off; safe margins (UI-BIBLE 7 px).

### 10.7 Anti-padroes
Hops 3+; Continue nao default; focus so cor; anim >400 ms; glass no papel; settings so no title; rumble no pause; input gameplay+UI juntos; lista monospaca sem secao; hit <32 px.

### 10.8 DoD — 15 upgrades
1. Continue/Retomar default
2. Pause dim + freeze; corta rumble
3. Stack back 1 nivel + focus restore
4. Highlight 120–200 ms + SFX
5. Tabs Video|Graphics|Audio|Controls|A11y (labels finais = RFC Settings)
6. Master + buses ao vivo
7. Presets + CRT toggles com preview
8. Font 2 tamanhos + Large Text
9. Foco = barra + cursor
10. Safe-area 4:3 e 16:9
11. Glyphs dinamicos
12. Modal destrutivo
13. Reduced motion + high contrast
14. Engrenagem/pauzinhos = atalho; Start canonico
15. Fila unica de toasts

Aplicacao imediata PSX: P0 = wiring `pediu_*` + hierarquia RAIZ + affordance pauzinhos + mouse nas opcoes; P1 = pagina CONTROLES; P2 = preview ao vivo dos sliders de imagem.

## 11. Contrato A11y Input (aprovado PO — 19/09/2026)
Fonte: PSX A11y Input. Sem codigo neste pacote.

### Acoes canonicas
`ui_up/down/left/right` · `ui_accept` · `ui_cancel` · `ui_open_pause` · `ui_open_sistema` · `ui_tab_prev/next`
Devices so mapeiam nessas acoes — sem `if` por device na logica de menu.

### Hits
- Linha/placa: ≥32px UI de altura; largura = linha inteira
- Pauzinhos: look fino OK, hit invisivel ≥32×32 (hoje 18×3 = anti-padrao)
- Gap ≥4px; safe 5% bordas (alinhar UI-BIBLE margem 7 px)

### Paridade mouse (DoD)
Titulo placas = Opcoes titulo = MenuSistema = prancha acionavel
**Divida P0:** Opcoes do titulo ainda sem mouse; MenuSistema `mouse_filter = IGNORE`.

### Prioridade implementacao (apos Visual+UX; wiring HARD pode antes)
1. Mouse nas Opcoes do titulo
2. Hit expandido pauzinhos + linhas sistema
3. Paridade SFX/disabled
4. Pagina CONTROLES (apos RFC Settings IA)

## 12. Checklist QA de captura (mapa — PO autorizado a fotografar so pos-implementacao)
Fonte: PSX Menu QA + fatos `captures/menu` README / UI-BIBLE flags.

| Flag | Ref |
|---|---|
| `--ver-pausa` | `captures/ui/f4_raiz.png` + `f4_pauzinhos.png` |
| `--ver-pausa=imagem` | `f4_imagem.png` |
| `--ver-pausa=som` | `f4_som.png` |
| `--ver-pausa=carregar` | `f4_carregar.png` |
| `--ver-boot` | `captures/menu/boot_*.png` |
| `--ver-partida` @340 | `titulo_*.png` (pico/estavel) |
| `--ver-partida` @78 | variante/pico cedo (README menu) |
| `--ver-opcoes` / `=som` | `opcoes_*.png` / `opcoes_som_*.png` |
| `--ver-carregar` | `saves_*.png` |

### Regras de captura (obrigatorias)
- Regressao: `checar_hud.gd` + `--headless --quit`
- Refs oficiais de titulo usam **`--ver-partida` @340 / @78**, nao so `--ver-menu`
- Fixar humor da mata: `--noite=cerracao` (ou valor documentado na ref) — senao a captura sorteia e nao compara
- Fixar estilo quando a ref exige: `--estilo=` (mesmo valor da captura canonica)
- `--shot=` com **caminho absoluto** (ou path resolvido a partir do cwd do runner) — relativo fragil entre maquinas
- Esperar fim de animacao antes do frame (`ANTES_CLIQUE` / await `T_ENTRADA`+margem) — fotografar cascata = falso negativo
- Fotos HOLD ate PO liberar pos-PR

## 13. Motion UI — tabela de tweens (aprovado PO — 19/09/2026)

> **Override fatia pauzinhos+RAIZ+`menu_sistema`:** `T_ENTRADA` / `T_SAIDA` (**0,34** / **0,40** s) = **cartao HUD only** (UI-BIBLE §5). Pauzinhos + folha RAIZ + `menu_sistema` usam `T_MENU_*` de `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` (`T_MENU_OPEN` 0,20 / `CLOSE` 0,14 / `PAGE` 0,16 / `FOCUS` 0,08 / `PRESS` 0,10) — nao misturar com o cartao.
>
> Contrato de motion para as 3 superficies. **Nao e codigo** — tabela que Godot UI Dev implementa com `Tween` / `AnimationPlayer` depois da spec Visual+UX aprovada.
> Fonte de tempos: `docs/UI-BIBLE.md` §5 Tempos (HUD). Pagina/foco de menu: ver override acima + SPEC_MOTION. Pagina: faixa 120–200 ms. Foco: <100 ms (§10.1.5).

### 13.1 Tokens (espelho UI-BIBLE + derivados de menu)

| token | duracao | origem | uso em menus |
|---|---|---|---|
| `T_ENTRADA` | **0,34 s** | UI-BIBLE §5 | abrir folha / painel / prancha / sistema |
| `T_SAIDA` | **0,40 s** | UI-BIBLE §5 | fechar folha / painel / prancha / sistema |
| `T_ENCOLHER` | **0,28 s** | UI-BIBLE §5 | dismiss secundario (nota ITEM_MORTO, popover, dica) |
| `T_LEITURA` | **12 s** | UI-BIBLE §5 | hold de leitura (HUD/faixa — nao menu interativo) |
| `T_PAGINA` | **0,16 s** | derivado (§4 P2 mid 120–200 ms) | troca VIDEO↔AUDIO↔CARREGAR / IMAGEM↔SOM |
| `T_FOCO` | **0,08 s** | derivado (§10.1.5 <100 ms) | cursor / glow / hover / accept flash |

Regra dura da bible: **acima de 0,4 s o jogador espera a animacao**. Nenhum tween de menu interativo passa de `T_SAIDA` (0,40 s).

### 13.2 Tabela open / close / page / focus

| familia | superficie | propriedades | de → para | duracao | easing (Godot) | paralelo? | SFX / haptic hook | notas |
|---|---|---|---|---|---|---|---|---|
| **OPEN** | Menu sistema (folha) | `modulate.a`, `position.y` | 0→1, +10 px→0 | `T_ENTRADA` 0,34 s | `TRANS_QUAD` / `EASE_OUT` | sim (`set_parallel(true)` **uma vez**) | `ui_open` | papel assenta; sem scale bounce (mata pixel font) |
| **OPEN** | Prancha (pause) | `modulate.a`, `position.y` | 0→1, +12 px→0 | `T_ENTRADA` 0,34 s | `TRANS_QUAD` / `EASE_OUT` | sim | `ui_pause_open` | game `paused=true` **antes** do tween; input so apos finished |
| **OPEN** | Titulo (cascata placas) | `modulate.a` por placa | 0→1, stagger 40 ms | `T_ENTRADA` total ≤0,34 s | `TRANS_QUAD` / `EASE_OUT` | sim entre props; stagger entre placas | `ui_titulo_tick` opcional | `set_parallel(true)` uma vez — nunca `.parallel()` por linha |
| **OPEN** | Boot / travessia | curvas em `travessia_curva.gd` | (existente) | propria | (existente) | — | CRT/plunge | **fora** desta tabela |
| **CLOSE** | Folha sistema / prancha | `modulate.a`, `position.y` | 1→0, 0→+8 px | `T_SAIDA` 0,40 s | `TRANS_QUAD` / `EASE_IN` | sim | `ui_close` | matar tween anterior — UI-BIBLE §6.3 |
| **CLOSE** | Dismiss nota / dica | `modulate.a`, scale opcional 1→0,96 | — | `T_ENCOLHER` 0,28 s | `TRANS_QUAD` / `EASE_IN` | sim | soft | so elementos secundarios |
| **PAGE** | Conteudo da folha (RAIZ→VIDEO/AUDIO/CARREGAR; titulo IMAGEM↔SOM) | `modulate.a` **ou** `position.x` ±12 px | out 1→0 / in 0→1 | `T_PAGINA` 0,16 s (faixa 0,12–0,20 s) | `TRANS_CUBIC` / `EASE_IN_OUT` | fade-out → troca dados → fade-in | `ui_page` | slide **ou** fade, nunca os dois no mesmo eixo; sem blur |
| **FOCUS** | Cursor `>` / focus ring / hover linha | `modulate.a` do glifo **ou** `position` snap | idle→focus | `T_FOCO` 0,08 s | `TRANS_SINE` / `EASE_OUT` | nao (1 prop) | `ui_move` ≤1 por mudanca | mesmo glifo em todas as listas |
| **FOCUS** | Accept / adjust flash | flash 1 frame + opcional `modulate` ping | — | ≤0,08 s (1–2 frames @60) | step / `TRANS_LINEAR` | — | `ui_accept` / `ui_adjust` | Feedback <100 ms — som + 1 frame |

### 13.3 Regras de implementacao (para Godot UI Dev)
1. **Uma fonte de constantes** — espelhar `T_ENTRADA` / `T_SAIDA` / `T_ENCOLHER`; `T_PAGINA` e `T_FOCO` no mesmo lugar (`UiEstilo` ou const compartilhada), comentario citando UI-BIBLE §5 + este §13.
2. **`Tween`: `set_parallel(true)` uma vez**, nunca `.parallel()` por linha.
3. **Matar tween anterior** no mesmo no antes de reabrir / re-clarear (UI-BIBLE §6.3).
4. **Input gate:** durante OPEN/CLOSE/PAGE, ignorar navigate; liberar no `finished`. FOCUS nunca bloqueia input.
5. **Reduced motion (futuro A11y):** se flag off, saltar para estado final em 0 s — mesmas props finais.
6. **Captura:** esperar fim da animacao. Usar `ANTES_CLIQUE` / await `T_ENTRADA`+margem.
7. **Anti-padroes:** elastic/bounce, blur UI, scale >±4 % em texto bitmap, pagina >0,20 s, foco >0,10 s, open >0,40 s.

### 13.4 Mapa superficie → familia obrigatoria

| superficie | OPEN | CLOSE | PAGE | FOCUS |
|---|---|---|---|---|
| `menu.gd` (titulo/opcoes) | cascata `T_ENTRADA` | `T_SAIDA` (sair de subfolha) | `T_PAGINA` IMAGEM↔SOM | `T_FOCO` placas + lista |
| `prancha_inventario.gd` | `T_ENTRADA` | `T_SAIDA` | — (faixa itens = snap) | `T_FOCO` item |
| `menu_sistema.gd` | `T_ENTRADA` folha | `T_SAIDA` | `T_PAGINA` RAIZ↔VIDEO/AUDIO/CARREGAR | `T_FOCO` linhas + aba |

### 13.5 Hooks audio/haptic (nomes logicos — Settings/Audio depois)
`ui_open` · `ui_close` · `ui_page` · `ui_move` · `ui_accept` · `ui_adjust` · `ui_back` · `ui_deny` (ITEM_MORTO).
Haptic (gamepad): pulse curto no accept/deny; nenhum no move de foco (spam).

**DoD desta entrega:** numeros citam UI-BIBLE §5; pagina 120–200 ms; foco <100 ms; zero codigo neste passo.

### APPROVED-ADDENDUM Motion §7 AAA RE-like
Status: **APPROVED-ADDENDUM**. Tokens `T_MENU_*` **inalterados**. Fonte: `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` §7.

| eixo | resumo |
|---|---|
| Scrim | `modulate.a` **0→0.45–0.55** paralelo ao open (`T_MENU_OPEN`) |
| Slide folha | **4–8 px** (pick **+6→0** open); close ≤ open |
| Stagger linhas | **30–40 ms** (pick **35 ms**); `CONTINUAR` first + focus frame **0** |
| Press | stain↑ ~20% **ou** barra **2→3px** ≤**2** frames; resto `T_MENU_PRESS` |
| Anti | glow/bloom; stagger **>40 ms**; slide fora **4–8**; scrim blur/glass |

## 14. Inventario de codigo (executor — 19/09/2026)

Espelho resumido: `docs/INVENTARIO_MENUS.md`.

### File map
| Path | Role |
|---|---|
| `game/src/ui/menu.gd` | Boot/titulo/OPCOES/CARREGAR/MAPA — layer 150 |
| `game/src/ui/menu_sistema.gd` | Pauzinhos + RAIZ/VIDEO/AUDIO/CARREGAR in-game |
| `game/src/ui/prancha_inventario.gd` | Pause scrapbook layer 110; dona do MenuSistema |
| `game/src/ui/opcoes_lista.gd` | Fonte unica `video()`/`audio()` |
| `game/src/ui/titulo_layout.gd` / `opcoes_layout.gd` / `ui_estilo.gd` | Medidas + tokens |
| `game/src/systems/settings.gd` | Persistencia |
| `game/src/levels/cidade.gd` | Instancia menus + flags `--ver-*` |

### P0 — wiring `pediu_*` (HARD) — **DONE**
`PranchaInventario.pediu_titulo` e `pediu_carregar(espaco)` **conectados** em `cidade.gd` (Onda 1).
Hooks: sinais em `prancha_inventario.gd`; binds em `cidade.gd`. Ver §4 item 0.

### Constantes
```
PAUZINHOS := Rect2(448, 19, 18, 14)   # expandir hit ≥32×32 (A11y §11)
FOLHA sistema ≈ 146/44/188 creme e6dfc4
CAMADA_POS=150 · CAMADA_ACIMA_DO_POS=160 · Prancha=110 · Menu=150
ITENS titulo: CONTINUAR CARREGAR NOVO JOGO MAPA OPCOES SAIR
BUSES: Master Music SFX Ambiente
```

### Hooks API
- `OpcoesLista.video()` / `audio()`
- `MenuSistema.abrir()` / `abrir_em(Pagina)` / `fechar()` / `tratar()`
- `PranchaInventario.menu_sistema()` / abrir / fechar

### Input
ESC/TAB = prancha; W = sistema; A/D itens; E/Q usar/examinar.
Mouse: titulo OK; Opcoes titulo + MenuSistema = teclado only.

### Flags
`--ver-pausa[=imagem|som|carregar]` · `--ver-boot|menu|partida|carregar|opcoes[=som]`
Refs: `captures/ui/f4_*.png`, `captures/menu/*`

### Nao duplicar
Lista de opcoes: so OpcoesLista. Tokens: so UiEstilo.

## 15. Gap UX Auditor (evidencia — 19/09/2026)

Fonte: UX Auditor (`UX_GAP_ROI.md` + entregas Slack). Fold tambem em §4.

### P0 (evidencia `menu_sistema.gd` + wiring)
| # | Achado | Evidencia |
|---|---|---|
| HARD | `pediu_titulo` / `pediu_carregar` — **DONE** (Onda 1) | binds em `cidade.gd`; sinais em `prancha_inventario.gd` |
| 1 | Aba pauzinhos affordance fraca + hit <32px | `:60`, `_desenhar_pauzinhos` — 18×14 / barras 18×3 |
| 2 | RAIZ lista chapada; SAIR mesmo peso de CONTINUAR | `>` + rect α0.07 `:368–371`; SAIR `:208` |
| 3 | Titulo pagina RAIZ = `OPCOES` (deveria ser pause-root) | `:350–351` |
| 4 | Zero mouse na superficie de maior ROI | `mouse_filter = IGNORE` `:78`, `:128` |

### P1
| # | Achado | Evidencia |
|---|---|---|
| 1 | Back ESC/Q ok; sem focus restore FILO | `:278–282`; `_ir_para` zera `_sel` |
| 2 | Sem modal destrutivo em SAIR | aceite minimo = peso tipografico |
| 3 | Mouse zero em Opcoes titulo + sistema | paridade §11 |

### P2
| # | Achado | Evidencia |
|---|---|---|
| 1 | Sem motion open/pagina | ate Godot aplicar §13 |
| 2 | Dica `[W/S]` vs `ui_up/down` — glyphs estaticos | `tratar` aceita ambos |
| 3 | `OpcoesLista` segue fonte unica | **ok — manter** |

### Aceite UX para Visual/Motion (RAIZ + aba)
CONTINUAR default focado; SAIR destructive (peso/tinta); titulo pagina ≠ OPCOES; pauzinhos ≥32×32 + legiveis com vinheta (`f4_pauzinhos`). Spec so — validacao UX quando Visual/Motion entregarem.

## 16. Status das specs pendentes

| Spec | Dono | Status | Notas |
|---|---|---|---|
| Visual Design (tokens + px pauzinhos / RAIZ / VIDEO) | Visual Design | **APPROVED** (fatia) + **APPROVED-ADDENDUM** AAA-RE | Spec `SPEC_VISUAL_PAUZINHOS_FOLHAS.md` + `ADDENDUM_AAA_RE.md` + `ADDENDUM_AAA_RE_VISUAL.md`. Godot **IMPLEMENTING** (liberado Jamerson); sem git. |
| Settings IA (taxonomia RFC OpcoesLista) | Settings IA | **RFC escrito / aguarda OK** | `docs/RFC_OPCOES_LISTA_TAXONOMIA.md` — **PENDING PO/user**; nao marcar aprovado. Labels Brief §10.5 = direcao. |
| Godot UI Dev (implementacao) | Godot UI Dev | **IMPLEMENTING** | Onda 1+1.5 **APPROVED** (sem ressalva P1). Dividas: RE profundidade + mouse HIT_LINHA. Sem git. |
| Motion UI | Motion UI | **APROVADO** (pacote fatia) + **APPROVED-ADDENDUM** §7 | §13 + `SPEC_MOTION_PAUZINHOS_RAIZ.md` (`T_MENU_*` inalterados; §7 AAA RE-like) |
| A11y Input | A11y Input | **APROVADO** | §11; fatia pauzinhos+RAIZ: aceite validado neste pacote; gate restante = `mouse_filter` STOP/PASS nos hits |
| UX Gap | UX Auditor | **ENTREGUE** | §4 + §15 + aceite Visual+Motion+UX |
| Menu QA mapa | Menu QA | **ENTREGUE** | §12; fotos HOLD |

## 17. Changelog 19/09/2026 — Docs Lead consolidation

- Consolidador: Docs Lead. Arquivo-alvo no PC: `docs/PLAYBOOK_MENUS_AAA.md` (esta versao = `PLAYBOOK_MENUS_AAA_CONSOLIDATED.md` no box).
- **Merge** dos dois blocos §10 duplicados (Principios pesquisa + Brief AAA) em um §10 limpo; link `docs/BRIEF_AAA_MENUS.md`.
- **§4** atualizado com evidencia UX Auditor (`menu_sistema.gd` linhas) + **P0 HARD wiring** `pediu_titulo` / `pediu_carregar` no TOPO.
- **§6** ganha coluna STATUS (entregue / em andamento / hold / pending).
- **§8** prioriza wiring HARD e A11y (mouse Opcoes → pauzinhos+sistema).
- **§11** A11y e **§12** QA mantidos como aprovados; §12 expandido (`--ver-partida` @340/@78, `--estilo=`, `--noite=cerracao`, `--shot` absoluto, `ANTES_CLIQUE`).
- **§13** Motion UI mantido (aprovado PO) — era §11 no append Motion; numeracao canônica = 13.
- **§14** Inventario de codigo (ex-duplicata §13 no playbook antigo) — P0 wiring destacado; espelho `INVENTARIO_MENUS.md`.
- **§15** Gap UX Auditor com tabela de evidencia.
- **§16** Specs pendentes: Visual + Settings = pending; Godot = HOLD.
- Conflitos resolvidos: (1) dois §10 → um; (2) Motion append §11 vs A11y §11 → Motion fica §13; (3) Inventario e Motion ambos §13 no rascunho intermediario → Inventario §14; (4) Gap UX vira §15 (nao compete com Motion).
- Nao inventado: tokens Visual, taxonomia Settings. Zero codigo de jogo.
- **Patch incremental fatia pauzinhos+RAIZ (19/09/2026):** §4 ganha ### Aceite Visual+Motion+UX (hit 32×32 @441,14; SISTEMA; CONTINUAR default; SAIR DESTAQUE; focus stain+barra+`>`; `T_MENU_*`; a11y mouse_filter; links specs); §13 nota override HUD vs `T_MENU_*` (`SPEC_MOTION_PAUZINHOS_RAIZ.md`); §6/§16 STATUS — Visual entregue (spec), Motion aprovado pacote fatia, Settings = RFC aguarda OK PO/user, Godot HOLD ate Visual+UX formal; A11y fatia validada com gate mouse_filter restante. Spec Visual copiada para `psx-specs/SPEC_VISUAL_PAUZINHOS_FOLHAS.md`. P0 HARD `pediu_*` permanece TOPO. Zero fork; zero codigo de jogo.
- **APPROVED PO (19/09/2026):** fatia Visual+Motion+A11y pauzinhos+RAIZ marcada no §4. Godot HOLD ate Jamerson decidir wiring (`pediu_*`) + Settings RFC.
- **Specs LOCKED + ordem PO (19/09/2026):** Visual/Motion/A11y fatia locked; §8 = wiring → Visual → mouse → Motion; §4 APPROVED confirmado no canal @everyone.
- **APPROVED-ADDENDUM AAA-RE (19/09/2026):** §4 ganha ### APPROVED-ADDENDUM AAA-RE Visual (Jamerson) — tabela compacta folha/tipo/aba/stagger/anti; links `ADDENDUM_AAA_RE.md` + `ADDENDUM_AAA_RE_VISUAL.md`; P0 HARD wiring TOPO inalterado. §13 ganha ### APPROVED-ADDENDUM Motion §7 AAA RE-like — scrim/slide/stagger/press/anti; `T_MENU_*` inalterados. Specs locked table + `ADDENDUM_AAA_RE*.md` como **APPROVED-ADDENDUM LOCKED**. §6/§16: addenda approved; Godot **IMPLEMENTING** (liberado); sem git. Cópia Visual addendum em `psx-specs/ADDENDUM_AAA_RE_VISUAL.md`. Zero fork; zero codigo de jogo.
- **IMPLEMENTING (19/09/2026):** Jamerson liberou AAA; §8 = IMPLEMENTING; Godot UI Dev no KernelOS-PC; **sem git**. HOLD removido.
- **Onda 1+1.5 APPROVED (19/09/2026):** §4 implementacao APPROVED sem ressalva P1 (UX+PO). Wiring+Visual+1.5 P1 fechados. Dividas: RE profundidade (Onda 2) + mouse HIT_LINHA. Caps `captures/ui/aaa_dev/`.
- **Pivô RE7 (19/09/2026):** §0 aponta `docs/EPICO_UI_RE7.md` + ondas; Onda 1 IMPLEMENTING; §8 fila ativa = épico; wiring `cidade.gd` marcado DONE onde ainda dizia falta. Sem duplicar o épico; sem git; sem fork.
- **SPEC_A11Y_RE7 APPROVED (19/09/2026):** linkado em `EPICO_UI_RE7` Onda 2 + playbook §0.1. Sem fork.
- **SPEC_VISUAL_RE7 + MOTION_RE7 APPROVED (19/09/2026):** linkados com A11y RE7 no EPICO + playbook §0.1. Sem fork.
- **INVENTARIO_MENUS_RE7 (19/09/2026):** arvore atual→alvo por onda; reuso Onda 1 AAA; gap DoD. Pedido PO2.
- **Onda 1 parcial (19/09/2026):** inventário RE7 §4 — UIManager/shader/wire/prints presentes; sans pendente. Fonte PO2.
- **Onda 1 ACEITE CONDICIONAL (19/09/2026):** inventário gap — overlay presente; dívida 1b sans; O2–O4 faltando. Fonte PO2.
- **Ondas 1 / 1b / 2 (19/09/2026):** Jamerson — Onda 1 ACEITE CONDICIONAL; 1b tipografia OPEN; Onda 2 BRIEFED. Briefs link quando PO1 gravar.
- **Owners RE7 (19/09/2026):** canal PSX RE7 Epic — Grid Inventory O2, Diegetic 3D O3, Audio UI O4; 1b APPROVED; O2 IMPLEMENTING.
- **SPEC_AUDIO_UI_RE7 (19/09/2026):** linkado no inventário RE7 § Audio hooks + épico Onda 4.
- **Audio PREP Onda 4 (19/09/2026):** EPICO linka `SPEC_AUDIO_UI_RE7.md` + `ASSETS_AUDIO_UI_RE7.md`. Sem fork.
- **Onda 3 PREP (19/09/2026):** EPICO linka `SPEC_INSPECT_VITALS_RE7.md` + `briefs/ONDA3_DIEGETIC_PREP.md`. Sem fork.
- **Onda 1b PASS / Onda 2 IMPLEMENTING (19/09/2026):** status PO2 nos docs RE7.
- **Onda 1b APPROVED / Onda 2 IMPLEMENTING (19/09/2026):** confirmado PO1 no EPICO/playbook.
- **Onda 2 FULL PASS (19/09/2026):** FECHADA PASS (paralela); cutover CANCELADO/ADIADO; O3 PREP aprovado. Fonte PO2.
- **Onda 2 APPROVED paralela (19/09/2026):** PO1 — cutover prancha pending Jamerson.
- **Onda 3 GO isolado (19/09/2026):** Jamerson — O3 IMPLEMENTING sem cutover prancha; cutover **CANCELADO/ADIADO**. Fonte PO2.
- **Decisão Jamerson Onda 3 (19/09/2026):** IMPLEMENTING on top do legado (inspect+vitals); cutover grid **CANCELADO/ADIADO**; O2 PASS permanece cena paralela. Fontes PO1+PO2.
- **Correção Onda 3 (19/09/2026):** IMPLEMENTING **incremental na prancha** (inspect+vitals plugados); demo isolada = apoio; cutover grid bloqueado. Fonte PO2.
- **POLISH_TIPO_LAYOUT (19/09/2026):** IMPLEMENTING on-top legado (P0); O3 continua; cutover grid adiado. Fonte PO2.
- **POLISH_AUDIO_UI (19/09/2026):** IMPLEMENTING P0 on-top (foley nav/confirm + duck/drone leve); com POLISH_TIPO_LAYOUT; O3 paralelo; cutover grid adiado. Fonte PO2 (Jamerson C+D).
- **SPEC_POLISH_TIPO_LAYOUT_RE7 (19/09/2026):** linkado no EPICO/playbook P0 POLISH_TIPO_LAYOUT. Sem fork.
- **SPEC_POLISH_TIPO_LAYOUT_RE7 APPROVED (19/09/2026):** PO2 — link P0; POLISH_AUDIO_UI=IMPLEMENTING. Sem código.
- **NO_GODOT_RUNTIME (19/09/2026):** standing order PO2 — sem shot/runtime enquanto Jamerson joga; Dev on-top legado. Owners: Theme Tokens (P0 tipo), Save Cards (prep O4).
- **HARD STOP Godot (19/09/2026):** aceites sem captura runtime até GO. Fonte PO1.
- **O3 MODULES PASS / WIRE IMPLEMENTING (19/09/2026):** *(superseded — WIRE agora PAUSED)* demo isolada PASS. Fonte PO2.
- **CHECKLIST_TOKENS_UIESTILO_RE7 (19/09/2026):** linkado no P0 POLISH_TIPO; UiEstilo tokens no disco. Fonte Theme Tokens.
- **O3 WIRE PAUSED (19/09/2026):** MODULES=PASS ok; WIRE pausado até P0 tipo/layout. Ordem: Theme Tokens → UI Dev tipo → Diegetic wire. Cutover grid adiado. Fonte PO2.
- **Theme Tokens P0 PASS (19/09/2026):** tokens PASS; POLISH_TIPO_LAYOUT=IMPLEMENTING (UI Dev re-aplicando prancha/sistema). O3 WIRE continua PAUSED. Fonte PO2.
- **Save Cards PREP (19/09/2026):** link playbook Onda 4 — `docs/specs/SPEC_SAVE_CARDS_RE7.md` · `docs/briefs/ONDA4_SAVE_CARDS_PREP.md` · mirror `re7_dev/onda4_prep/`. EPICO+inventário já linkados. Fonte Save Cards.
- **Save Cards paths EPICO (19/09/2026):** Onda 4 PREP — SPEC_SAVE_CARDS_RE7 + `re7/save_*` (card/panel/thumb/demo). Fonte PO1.
- **O4 SAVE_CARDS_PREP PASS (19/09/2026):** PREP isolado PASS; wire pending GO. Fonte PO2.
- **O4 Save Cards PREP APPROVED (19/09/2026):** isolado APPROVED; wire pending GO. Fonte PO1.
- **Save Cards paths canônicos (19/09/2026):** `save_card.gd/.tscn` · `save_panel.gd/.tscn` · `save_thumb_capture.gd` · `re7_save_cards_demo.tscn`; mirror pode ter `*_re7`. Fonte Save Cards.
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
- **P0 F confirmado PO1 (19/09/2026):** IMPLEMENTING — style_re7_panel + focus Tween; O4/playtest HOLD; sem Godot/Git. Fonte PO1.
- **O4 SAVE WIRE IMPLEMENTING + loop AAA ON (19/09/2026):** O4 save wire=**IMPLEMENTING** (código-only). P0 F IMPLEMENTING. Playtest HOLD · NO_GODOT. Loop autônomo AAA ON. Fonte PO2.
- **Standing loop contínuo (19/09/2026):** Jamerson — PO2 despacha sem esperar GO. O4 SAVE WIRE IMPLEMENTING (código) · P0 F segue · playtest HOLD. Fonte PO1.
- **P0 F PASS (19/09/2026):** P0 F=**PASS**. Snapshot: C/D/E/F PASS · O3 WIRE PASS · O4 SAVE WIRE IMPLEMENTING · Save PREP PASS · playtest HOLD · NO_GODOT. Fonte PO2.
- **O4 SAVE WIRE PASS COM RESSALVA (19/09/2026):** wire OK; falta restaurar `PainelRe7`/`style_re7_panel` (P0 F). Playtest HOLD · NO_GODOT. Fonte PO2.
- **O4 SAVE WIRE ressalva PO1 (19/09/2026):** PASS COM RESSALVA até `PainelRe7` voltar (UI Dev hotfix). Playtest HOLD. Fonte PO1.
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
- **P0 G PASS + CARREGAR agora (19/09/2026):** PO1 — P0 G=PASS (cutover HOLD). Próximo=`menu.gd` CARREGAR legado IMPLEMENTING. Playtest HOLD. Fonte PO1.
- **A11y reaudit P0 G + backlog P1 (19/09/2026):** A11y reaudit P0 G=**PASS**. Backlog P1: `MenuSistema` nested sem `push_menu`. Fonte PO2.
- **menu.gd CARREGAR PASS (19/09/2026):** CARREGAR=**PASS**. Próximo/agora: P1 `MenuSistema` nested `push_menu`. NO_GODOT. Fonte PO2.
- **CARREGAR PASS confirmado PO1 (19/09/2026):** menu.gd CARREGAR=PASS. Snapshot C–G + O3/O4 + título CARREGAR PASS. Próximo=P1 MenuSistema nested push IMPLEMENTING. Playtest HOLD. Fonte PO1.
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
- **P0 J PASS confirmado (19/09/2026):** P0 J INSPECT_ORBIT_DAMP=**PASS** (já aceito). P0 I tipografia ainda IMPLEMENTING. Fontes PO1+PO2.
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

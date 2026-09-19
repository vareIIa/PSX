# PLAYBOOK MENUS AAA — PSX
> Consolidador: Docs Lead. Atualizado 19/09/2026.
> Fonte de verdade para bots. Repo: `C:\Users\Administrator\Documents\Codes\Games\PSX`
> Canais: `PSX Menus War Room`, `PSX Menus Specs`.
> Brief curto: `docs/BRIEF_AAA_MENUS.md`. Inventario codigo: `docs/INVENTARIO_MENUS.md` (espelho §14).

## 0. Missao
Levar tres superficies de UI ao rigor AAA do projeto (regra num lugar + teste + medida + captura), sem abandonar a linguagem de papel/CRT/PSX:

1. **Menu inicial** (boot → titulo → opcoes/saves/carteira) — `game/src/ui/menu.gd`
2. **Prancha / pause in-game** (ESC/TAB) — `game/src/ui/prancha_inventario.gd`
3. **Menu de sistema (tres pauzinhos)** — `game/src/ui/menu_sistema.gd` (abre com W na prancha)

AAA aqui = rigor de estudio, nao glassmorphism generico. Ver `PLANO_UI_AAA.md` secao 0 e `docs/UI-BIBLE.md`.

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
| `game/src/ui/ui_estilo.gd` / `UiEstilo` | Tokens: fontes, tintas, camadas, tela |
| `game/src/systems/settings.gd` | Persistencia imagem/audio |
| `game/src/levels/cidade.gd` | Instancia menus + flags `--ver-*`; **falta** `.connect` dos sinais da prancha (§4 P0 HARD) |
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

Sinais emitidos pela prancha (hoje **sem listener** em `cidade.gd` — ver §4 P0 HARD):
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

0. **P0 HARD — wiring quebrado (TOPO).** `PranchaInventario.pediu_titulo` e `pediu_carregar(espaco)` sao **emitidos** em `prancha_inventario.gd` e **nunca** `.connect` em `cidade.gd`. SAIR PARA O TITULO / CARREGAR in-game = beco sem saida. Fix imediato (qualquer bot de implementacao, independente de Visual):
   - `prancha.pediu_titulo` → fluxo voltar ao Menu/titulo
   - `prancha.pediu_carregar(espaco)` → `SaveGame.carregar` + fechar prancha
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
> Godot UI Dev permanece **HOLD** ate Jamerson decidir wiring (`pediu_*`) + Settings RFC.
> Proximo: UX Auditor ja alinhado; implementacao so apos OK do user nos gates acima.

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

**P0 HARD** wiring `pediu_*` permanece **TOPO** (§4 item 0) — nao remover deste aceite.


### Specs locked (fatia pauzinhos+RAIZ)
| Spec | Path | Status |
|---|---|---|
| Visual | `docs/specs/SPEC_VISUAL_PAUZINHOS_FOLHAS.md` | **LOCKED** (fonte Dev) |
| Motion | `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` | **LOCKED** (`T_MENU_*`) |
| A11y §11 | playbook §11 | **LOCKED** p/ onda mouse (hover=focus + `mouse_filter` STOP/PASS) |

Ordem de implementacao (PO — quando Jamerson liberar wiring+Settings):
1. Wiring P0 (`pediu_titulo` / `pediu_carregar` em `cidade.gd`)
2. Visual desta fatia
3. Mouse (gate A11y)
4. Motion (`T_MENU_*`)


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
| **Visual Design** | Spec tokens + mock textual folha RAIZ/VIDEO + aba pauzinhos (px da TELA) | **APPROVED** (fatia pauzinhos+RAIZ) — `docs/specs/SPEC_VISUAL_PAUZINHOS_FOLHAS.md` |
| **Motion UI** | Tabela tweens open/close/page/focus (UI-BIBLE Tempos) | **entregue + aprovado pacote fatia** — §13 + `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` (`T_MENU_*`) |
| **A11y Input** | Contrato teclado/mouse/gamepad + hit min + focus neighbors | **entregue** (§11 aprovado PO); fatia: mouse_filter STOP/PASS ainda gate |
| **Settings IA** | Taxonomia rotulos PT-BR + ordem linhas (RFC OpcoesLista) | **RFC** em `docs/RFC_OPCOES_LISTA_TAXONOMIA.md` — **aguarda OK PO/user** (nao marcar aprovado) |
| **Docs Lead** | Consolida este playbook + UI-BIBLE PRs de texto | **em andamento** (patch fatia 19/09/2026) |
| **Godot UI Dev** | SO implementa apos Visual+UX aprovados pelo PO; reusa OpcoesLista | **HOLD** — fatia Visual+Motion+A11y APPROVED; aguarda Jamerson (wiring `pediu_*` + Settings RFC) |
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

## 8. Ordem de execucao recomendada
Fatia Visual+Motion+A11y (pauzinhos+RAIZ): **APPROVED PO** / specs **LOCKED**. Godot **HOLD** ate Jamerson fechar wiring + Settings.

Quando liberar, ordem PO:
1. Wiring P0 — `.connect` `pediu_titulo` / `pediu_carregar` em `cidade.gd`
2. Visual desta fatia (`SPEC_VISUAL_PAUZINHOS_FOLHAS.md`)
3. Mouse — hover=focus + `mouse_filter` STOP/PASS (A11y §11)
4. Motion — `T_MENU_*` (`SPEC_MOTION_PAUZINHOS_RAIZ.md`)
5. Pagina CONTROLES (depois Settings RFC OK)
6. Paridade titulo ↔ sistema (sons + disabled)


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

### P0 — wiring quebrado (HARD)
`PranchaInventario.pediu_titulo` e `pediu_carregar(espaco)` **emitidos, nunca `.connect` em `cidade.gd`**.
Hooks: sinais em `prancha_inventario.gd`; faltam binds em `cidade.gd`. Ver §4 item 0.

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
| HARD | `pediu_titulo` / `pediu_carregar` sobem da prancha; ninguem em `cidade.gd` escuta → SAIR/CARREGAR in-game mortos | `prancha_inventario.gd` sinais; falta `.connect` em `cidade.gd` |
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
| Visual Design (tokens + px pauzinhos / RAIZ / VIDEO) | Visual Design | **APPROVED** (fatia) | Spec `docs/specs/SPEC_VISUAL_PAUZINHOS_FOLHAS.md`. Fatia pauzinhos+RAIZ **APPROVED PO**. Godot HOLD ate Jamerson (wiring+Settings). |
| Settings IA (taxonomia RFC OpcoesLista) | Settings IA | **RFC escrito / aguarda OK** | `docs/RFC_OPCOES_LISTA_TAXONOMIA.md` — **PENDING PO/user**; nao marcar aprovado. Labels Brief §10.5 = direcao. |
| Godot UI Dev (implementacao) | Godot UI Dev | **HOLD** | Fatia Visual+Motion+A11y **APPROVED PO**. Libera so quando Jamerson decidir wiring (`pediu_*`) + Settings RFC. |
| Motion UI | Motion UI | **APROVADO** (pacote fatia) | §13 + `docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md` (`T_MENU_*` override HUD) |
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

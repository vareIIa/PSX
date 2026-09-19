# PLAYBOOK MENUS AAA — PSX Project Owner
> Fonte de verdade para bots. Atualizado 19/09/2026. Repo: `C:\Users\Administrator\Documents\Codes\Games\PSX`
> Project Owner: este agente. Canais: `PSX Menus War Room`, `PSX Menus Specs`.

## 0. Missao
Levar tres superficies de UI ao rigor AAA do projeto (regra num lugar + teste + medida + captura), sem abandonar a linguagem de papel/CRT/PSX:

1. **Menu inicial** (boot → titulo → opcoes/saves/carteira) — `game/src/ui/menu.gd`
2. **Prancha / pause in-game** (ESC/TAB) — `game/src/ui/prancha_inventario.gd`
3. **Menu de sistema (tres pauzinhos)** — `game/src/ui/menu_sistema.gd` (abre com W na prancha)

AAA aqui = rigor de estudio, nao glassmorphism generico. Ver `PLANO_UI_AAA.md` secao 0 e `docs/UI-BIBLE.md`.

## 1. Mapa de arquivos (hooks para bots)

| Arquivo | Papel |
|---|---|
| `game/src/ui/menu.gd` | Boot CRT, titulo, opcoes (IMAGEM/SOM), saves, criacao |
| `game/src/ui/menu_sistema.gd` | Pauzinhos + folha OPCOES/IMAGEM/SOM/CARREGAR in-game |
| `game/src/ui/prancha_inventario.gd` | Pause/inventario; instancia MenuSistema; W abre sistema |
| `game/src/ui/opcoes_lista.gd` | **Fonte unica** video()+audio() — titulo E sistema leem daqui |
| `game/src/ui/opcoes_layout.gd` | Geometria medida da folha de opcoes (titulo) |
| `game/src/ui/titulo_layout.gd` | Geometria do titulo |
| `game/src/ui/carteira_layout.gd` | Criacao de personagem |
| `game/src/ui/travessia_curva.gd` | Curvas do START (plunge/lente) |
| `game/src/ui/ui_estilo.gd` / equivalente `UiEstilo` | Tokens: fontes, tintas, camadas, tela |
| `game/src/systems/settings.gd` | Persistencia imagem/audio |
| `game/tests/checar_hud.gd` | Assertivas de layout |
| `docs/UI-BIBLE.md` | Contrato visual |
| `captures/menu/*` | Refs boot/titulo/opcoes/saves (MODERNO+PS1) |
| `captures/ui/f4_*` | Refs pauzinhos + paginas do sistema |

## 2. Fluxos

### 2.1 Menu inicial
```
BOOT (PRESS START / travessia tubo)
  → TITULO (NOVO / CONTINUAR / CARREGAR / OPCOES / MAPA? / SAIR)
      → CARREGAR (3 espacos + resumo SaveGame)
      → OPCOES pagina IMAGEM | SOM  (OpcoesLista)
      → carteira de criacao (NOVO JOGO)
```
Input: teclado + mouse nas placas do titulo (Fase C feita). Opcoes do titulo: **ainda sem mouse** (divida conhecida).

### 2.2 Pause / prancha
```
ESC ou TAB → PranchaInventario (get_tree().paused = true)
  → faixa de itens A/D, E/Q acoes
  → W (mover_frente) → MenuSistema.abrir()
  → ESC fecha prancha (se sistema aberto, sistema trata primeiro)
```
Dica na prancha: `[A/D] item  [E][Q]  [W] opcoes  [ESC] fechar`

### 2.3 Menu sistema (pauzinhos)
```
Aba 18×14 @ (448,19) — CanvasLayer ACIMA do pos (UiEstilo.CAMADA_ACIMA_DO_POS)
Painel FOLHA 188px @ (146,44) — altura dinamica; ABAIXO do pos
Paginas: RAIZ → VIDEO | AUDIO | CARREGAR
RAIZ: CONTINUAR · CARREGAR · IMAGEM · SOM · SAIR PARA O TITULO
```
Sinais: `continuar`, `sair_para_titulo`, `carregou(espaco)`
Flags: `--ver-pausa`, `--ver-pausa=imagem|som|carregar`

## 3. Inventario de opcoes (OpcoesLista — nao duplicar)

**VIDEO:** ESTILO · RESOLUCAO 3D (480×270…1280×720) · NEVOA · GRAO · ABERRACAO · SCANLINE · VINHETA · DITHER
**AUDIO:** um slider por bus em `Settings.BUSES` (blocos `[####......]`)

Qualquer bot que adicione ajuste **edita so** `opcoes_lista.gd` (+ Settings). Menus so desenham.

## 4. Dividas visuais / UX (prioridade para upgrade AAA)

### P0 — o que ainda parece "arcaico" ao jogador
1. **Folha de sistema = lista chapada** (`draw_string` + `>` + retangulo alfa 0.07). Sem icones, sem secoes, sem motion de pagina, sem hover/mouse.
2. **Pauzinhos** sao 3 barras 18×3 — affordance fraca vs padrao AAA (gear/hamburger reconhecivel + hit target >= 24–32px em escala UI).
3. **Opcoes do titulo sem mouse** (unica tela do fluxo inicial so-teclado).
4. **Sem pagina CONTROLES** no sistema (prometida no PLANO_UI Fase 4, nao entregue).
5. **Prancha + sistema** compartilham vocabulario de papel, mas hierarquia tipografica do painel e "lista de debug elegante", nao menu de produto.

### P1 — rigor / teste
6. Mouse em Opcoes (titulo + sistema): hit areas por linha.
7. Cascata de entrada do titulo sem teste de curva (divida PLANO_MENU 3.1).
8. Carteira / opcoes nao fotografadas em todos os caminhos PS1 onde falta.
9. Gamepad nao exercitado nas frentes de menu.
10. CONTINUAR morto precisa sempre explicar por que (titulo ja faz; manter parity).

### P2 — polish AAA (sem quebrar PSX)
11. Transicoes de pagina (slide/fade 120–200ms, UI-BIBLE tempos).
12. Focus ring / cursor consistente (mesmo glifo + som em todas as listas).
13. Agrupar VIDEO em preset vs fine-tune (ESTILO mestre ja existe — UI deve destacar).
14. Safe area / vinheta: painel nunca no canto morto; aba ja sobe de camada (manter regra).
15. Localizacao-ready: strings fora de magia inline onde ainda houver.

## 5. Principios AAA aplicaveis (papel/CRT — nao copiar glass)

- Hierarquia: titulo de pagina → secoes → linhas → dica de input sempre no rodape.
- Selection: estado idle / focus / disabled / destructive (SAIR) com contraste medido.
- Feedback: todo accept/adjust/back tem SFX + 1 frame de resposta visual.
- Settings IA: Video (preset+fine) · Audio (buses) · Controls (futuro) · Saves.
- Anti-padroes arcaicos: lista monospaca sem agrupamento; hit target < linha; teclas na dica que mentem; duas fontes de verdade para a mesma opcao.
- CRT: preferir valor/contraste a saturacao; bordas 1px tinta; evitar blur UI que mate pixel font.

## 6. Instrucoes por bot

| Bot | Entrega |
|---|---|
| **UX Auditor** | Gap analysis P0–P2 com severidade + evidencia (arquivo:linha ou capture) |
| **Visual Design** | Spec de tokens + mock textual da folha RAIZ/VIDEO e da aba pauzinhos (medidas em px da TELA do jogo) |
| **Motion UI** | Tabela de tweens (open/close/page/focus) alinhada UI-BIBLE secao Tempos |
| **A11y Input** | Contrato teclado/mouse/gamepad + tamanho minimo hit + focus neighbors |
| **Settings IA** | Taxonomia rotulos PT-BR + ordem das linhas (sem quebrar OpcoesLista sem RFC) |
| **Docs Lead** | Consolida este playbook + UI-BIBLE PRs de texto |
| **Godot UI Dev** | SO implementa apos spec Visual+UX aprovada pelo PO; reusa OpcoesLista |
| **Menu QA** | Checklist captura `--ver-pausa*` + `--ver-menu` + regressao checar_hud |

## 7. Definition of Done (qualquer PR de menu)
1. `--headless --quit` limpo
2. Captura da flag da tela + compare com `captures/`
3. Numeros citam UI-BIBLE
4. Tipagem estatica
5. Nenhuma duplicacao de lista de opcoes
6. checar_hud / testes de layout verdes
7. Mouse e teclado chegam no mesmo lugar (quando a tela for interativa)

## 8. Ordem de execucao recomendada
1. Spec Visual + UX da **aba pauzinhos + folha RAIZ** (maior ROI in-game)
2. Mouse + hit areas em Opcoes (titulo + sistema)
3. Motion de pagina + focus
4. Pagina CONTROLES (nova, so depois de IA Settings)
5. Pass de paridade titulo ↔ sistema (mesmos sons, mesmos estados disabled)

## 9. Capturas de referencia obrigatorias
- `captures/ui/f4_pauzinhos.png`, `f4_raiz.png`, `f4_imagem.png`, `f4_som.png`, `f4_carregar.png`
- `captures/menu/titulo_*.png`, `opcoes_*.png`, `boot_*.png`, `saves_*.png`

Nao implementar "bonito" sem antes medir contraste no canto com vinheta.


## 10. Principios AAA (pesquisa PO — 19/09/2026)

Fontes: UX Collective (pacing IA), nastyrodent (menu navigation), IA settings PDF (player-focused), Returnal PS Blog (CRT diegetic), Haas/Guerrilla HZD.

1. **Pause != dumping ground.** Topo = acoes frequentes (continuar, inventario ja esta na prancha). Settings no segundo nivel.
2. **UI map antes de arte.** Fluxo titulo ↔ opcoes ↔ sistema ↔ prancha tem de ser o mesmo verbo (voltar, ajustar, confirmar).
3. **Settings por modelo mental do jogador:** Jogo / Controles / Audio / Imagem — nao por sistema interno do engine.
4. **Hot-apply** em audio/imagem (ja e o caso via Settings); confirmacao so em acao destrutiva (SAIR).
5. **Focus visivel + feedback <100ms** (som + cursor). Mesmo glifo em todas as listas.
6. **Acessibilidade no fluxo**, nao ghetto separado (Returnal).
7. **CRT/retro:** paleta curta, flicker/on-off, sem camadas glass; legibilidade > efeito (Returnal).
8. **Previews** quando o ajuste muda a cena (grain/scanline) — ideal no painel IMAGEM.
9. **Hit target e mouse parity** em toda tela interativa (titulo ja tem; opcoes/sistema nao).
10. **Style guide unico** (UI-BIBLE) — centesima tela igual a primeira.

Aplicacao imediata no PSX: P0 = hierarquia da folha RAIZ + affordance dos pauzinhos + mouse nas opcoes; P1 = pagina CONTROLES; P2 = preview ao vivo dos sliders de imagem.


## 10. Brief AAA (pesquisa PO — 19/09/2026)

Fonte: pesquisa externa (GoW Ragnarök, HZD, U4, Control, DS, Spider-Man, TLOU2) + síntese PO.
Princípio: copiar **comportamento** AAA; personalidade no material papel/CRT — não glass.

### Hierarquia
- Title: Continuar default/focado → Novo → Carregar → Opções → Créditos → Sair
- Pause: Retomar default → (Inventário já é a prancha) → Opções → Salvar/Carregar → Título
- Pauzinhos = atalho **secundário** a Opções; Start/ESC continua canônico
- Profundidade: ≤1 hop uso frequente; ≤2 ocasional

### Motion
| Tipo | ms | Notas |
|------|-----|-------|
| Press/focus | 80–150 | blink/cursor PSX |
| Highlight slide | 120–200 | cancelar tween anterior |
| Open panel | 150–250 | fade + scale 95→100 |
| Close | 100–180 | mais rápido que open |
| Input | — | não espera >250 ms |

### Focus / feedback
- Focus parity pad = mouse; restore no back (stack FILO)
- 3 canais: visual + SFX move + SFX confirm
- Só a camada do topo recebe input

### Settings IA
Video/Display ≠ Graphics/Quality ≠ Audio ≠ Controls ≠ Accessibility
Hot-apply áudio; Apply em resolução; modal destrutivo; Defaults por categoria
Settings no title **e** no pause

### Tipografia CRT
Bitmap 2 tamanhos; contraste por luminância; CRT intensity com off; safe margins

### Anti-padrões
Hops 3+; Continue não default; focus só cor; anim >400 ms; glass no papel; settings só no title; rumble no pause; input gameplay+UI juntos

### DoD — 15 upgrades
1 Continue/Retomar default
2 Pause dim + freeze; corta rumble
3 Stack back 1 nível + focus restore
4 Highlight 120–200 ms + SFX
5 Tabs Video|Graphics|Audio|Controls|A11y
6 Master + buses ao vivo
7 Presets + CRT toggles com preview
8 Font 2 tamanhos + Large Text
9 Foco = barra + cursor
10 Safe-area 4:3 e 16:9
11 Glyphs dinâmicos
12 Modal destrutivo
13 Reduced motion + high contrast
14 Engrenagem = atalho; Start canônico
15 Fila única de toasts


## 11. Contrato A11y Input (aprovado PO — 19/09/2026)
Fonte: PSX A11y Input. Sem código neste pacote.

### Ações canônicas
`ui_up/down/left/right` · `ui_accept` · `ui_cancel` · `ui_open_pause` · `ui_open_sistema` · `ui_tab_prev/next`
Devices só mapeiam nessas ações — sem `if` por device na lógica de menu.

### Hits
- Linha/placa: ≥32px UI de altura; largura = linha inteira
- Pauzinhos: look fino OK, hit invisível ≥32×32 (hoje 18×3 = anti-padrão)
- Gap ≥4px; safe 5% bordas

### Paridade mouse (DoD)
Titulo placas = Opções título = MenuSistema = prancha acionável
**Dívida P0:** Opções do título ainda sem mouse.

### Prioridade implementação (após Visual+UX)
1 Mouse nas Opções do título
2 Hit expandido pauzinhos + linhas sistema
3 Paridade SFX/disabled
4 Página CONTROLES (após RFC Settings IA)

## 12. Checklist QA de captura (mapa — PO autorizado a fotografar só pós-implementação)
Fonte: PSX Menu QA.

| Flag | Ref |
|---|---|
| `--ver-pausa` | `captures/ui/f4_raiz.png` + `f4_pauzinhos.png` |
| `--ver-pausa=imagem` | `f4_imagem.png` |
| `--ver-pausa=som` | `f4_som.png` |
| `--ver-pausa=carregar` | `f4_carregar.png` |
| `--ver-boot` | `captures/menu/boot_*.png` |
| `--ver-partida` @340 | `titulo_*.png` |
| `--ver-opcoes` / `=som` | `opcoes_*.png` / `opcoes_som_*.png` |
| `--ver-carregar` | `saves_*.png` |

Regressão: `checar_hud.gd` + `--headless --quit`.
Nota: refs oficiais de título usam `--ver-partida` @340, não só `--ver-menu`.

## 11. Motion UI — tabela de tweens (PSX Motion UI · 19/09/2026)

> Contrato de motion para as 3 superficies. **Nao e codigo** — e a tabela que Godot UI Dev implementa com `Tween` / `AnimationPlayer` depois da spec Visual+UX aprovada.
> Fonte de tempos: `docs/UI-BIBLE.md` §5 Tempos. Transicoes de pagina citam tambem playbook §4 P2.11 (120–200 ms). Feedback de foco cita §10.5 (<100 ms).

### 11.1 Tokens (espelho da UI-BIBLE + derivados de menu)

| token | duracao | origem | uso em menus |
|---|---|---|---|
| `T_ENTRADA` | **0,34 s** | UI-BIBLE §5 | abrir folha / painel / prancha / sistema |
| `T_SAIDA` | **0,40 s** | UI-BIBLE §5 | fechar folha / painel / prancha / sistema |
| `T_ENCOLHER` | **0,28 s** | UI-BIBLE §5 | dismiss secundario (nota ITEM_MORTO, popover, dica) |
| `T_LEITURA` | **12 s** | UI-BIBLE §5 | hold de leitura (HUD/faixa — nao menu interativo) |
| `T_PAGINA` | **0,16 s** | derivado (§4 P2.11 mid 120–200 ms) | troca VIDEO↔AUDIO↔CARREGAR / IMAGEM↔SOM |
| `T_FOCO` | **0,08 s** | derivado (§10.5 <100 ms) | cursor / glow / hover / accept flash |

Regra dura da bible: **acima de 0,4 s o jogador espera a animacao**. Nenhum tween de menu interativo passa de `T_SAIDA` (0,40 s). Pagina e foco ficam bem abaixo.

### 11.2 Tabela open / close / page / focus

| familia | superficie | propriedades | de → para | duracao | easing (Godot) | paralelo? | SFX / haptic hook | notas |
|---|---|---|---|---|---|---|---|---|
| **OPEN** | Menu sistema (folha) | `modulate.a`, `position.y` | 0→1, +10 px→0 | `T_ENTRADA` 0,34 s | `TRANS_QUAD` / `EASE_OUT` | sim (`set_parallel(true)` **uma vez**) | `ui_open` | papel “assenta”; sem scale bounce (mata pixel font) |
| **OPEN** | Prancha (pause) | `modulate.a`, `position.y` | 0→1, +12 px→0 | `T_ENTRADA` 0,34 s | `TRANS_QUAD` / `EASE_OUT` | sim | `ui_pause_open` | game `paused=true` **antes** do tween; input so apos finished |
| **OPEN** | Titulo (cascata placas) | `modulate.a` por placa | 0→1, stagger 40 ms | `T_ENTRADA` total ≤0,34 s | `TRANS_QUAD` / `EASE_OUT` | sim entre props; stagger sequencial entre placas | `ui_titulo_tick` opcional | UI-BIBLE: `set_parallel(true)` uma vez — nunca `.parallel()` por linha |
| **OPEN** | Boot / travessia | curvas em `travessia_curva.gd` | (existente) | propria | (existente) | — | CRT/plunge | **fora** desta tabela; nao misturar com folha |
| **CLOSE** | Folha sistema / prancha | `modulate.a`, `position.y` | 1→0, 0→+8 px | `T_SAIDA` 0,40 s | `TRANS_QUAD` / `EASE_IN` | sim | `ui_close` | matar tween anterior (clareoes / reopen) — UI-BIBLE §6.3 |
| **CLOSE** | Dismiss nota / dica | `modulate.a`, scale opcional 1→0,96 | — | `T_ENCOLHER` 0,28 s | `TRANS_QUAD` / `EASE_IN` | sim | soft | so elementos secundarios |
| **PAGE** | Conteudo da folha (RAIZ→VIDEO/AUDIO/CARREGAR; titulo IMAGEM↔SOM) | `modulate.a` **ou** `position.x` ±12 px | out 1→0 / in 0→1 | `T_PAGINA` 0,16 s (faixa 0,12–0,20 s) | `TRANS_CUBIC` / `EASE_IN_OUT` | fade-out → troca dados → fade-in (nao overlap de duas paginas) | `ui_page` | slide **ou** fade, nunca os dois no mesmo eixo; sem blur |
| **FOCUS** | Cursor `>` / focus ring / hover linha | `modulate.a` do glifo **ou** `position` snap | idle→focus | `T_FOCO` 0,08 s | `TRANS_SINE` / `EASE_OUT` | nao (1 prop) | `ui_move` ≤1 por mudanca | mesmo glifo em todas as listas (§4 P2.12 / §10.5) |
| **FOCUS** | Accept / adjust flash | flash 1 frame visual + opcional `modulate` ping | — | ≤0,08 s (ideal 1–2 frames @60) | step / `TRANS_LINEAR` | — | `ui_accept` / `ui_adjust` | “Feedback <100 ms” — som + 1 frame |

### 11.3 Regras de implementacao (para Godot UI Dev)

1. **Uma fonte de constantes** — preferir espelhar `T_ENTRADA` / `T_SAIDA` / `T_ENCOLHER` ja usados no cartao; `T_PAGINA` e `T_FOCO` entram no mesmo lugar (ex. `UiEstilo` ou const compartilhada), com comentario citando UI-BIBLE §5 + este §11.
2. **`Tween`: `set_parallel(true)` uma vez**, nunca `.parallel()` por linha (UI-BIBLE, bloco do titulo).
3. **Matar tween anterior** no mesmo no antes de reabrir / re-clarear (UI-BIBLE §6.3).
4. **Input gate:** durante OPEN/CLOSE/PAGE, ignorar navigate; liberar no `finished`. FOCUS nunca bloqueia input.
5. **Reduced motion (futuro A11y):** se flag off, saltar para estado final em 0 s — mesmas props finais.
6. **Captura:** esperar fim da animacao (UI-BIBLE: captura a 83 ms com cascata pela frente = falso negativo). Usar `ANTES_CLIQUE` / await `T_ENTRADA`+margem.
7. **Anti-padroes:** elastic/bounce, blur UI, scale >±4 % em texto bitmap, pagina >0,20 s, foco >0,10 s, open >0,40 s.

### 11.4 Mapa superficie → familia obrigatoria

| superficie | OPEN | CLOSE | PAGE | FOCUS |
|---|---|---|---|---|
| `menu.gd` (titulo/opcoes) | cascata `T_ENTRADA` | `T_SAIDA` (sair de subfolha) | `T_PAGINA` IMAGEM↔SOM | `T_FOCO` placas + lista |
| `prancha_inventario.gd` | `T_ENTRADA` | `T_SAIDA` | — (faixa itens = snap) | `T_FOCO` item |
| `menu_sistema.gd` | `T_ENTRADA` folha | `T_SAIDA` | `T_PAGINA` RAIZ↔VIDEO/AUDIO/CARREGAR | `T_FOCO` linhas + aba |

### 11.5 Hooks audio/haptic (nomes logicos — Settings/Audio depois)

`ui_open` · `ui_close` · `ui_page` · `ui_move` · `ui_accept` · `ui_adjust` · `ui_back` · `ui_deny` (ITEM_MORTO).
Haptic (gamepad): pulse curto no accept/deny; nenhum no move de foco (spam).

**DoD desta entrega:** numeros acima citam UI-BIBLE §5; pagina na faixa 120–200 ms; foco <100 ms; zero codigo neste passo.

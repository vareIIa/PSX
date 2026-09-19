# RFC — Taxonomia PT-BR + ordem `OpcoesLista` + proposta CONTROLES

**Autor:** Settings IA  
**Data:** 19/09/2026 (rev. pacote completo)  
**Status:** PACOTE PARA APROVAÇÃO PO — sem código até OK deste doc  
**Escopo:** rótulos e ordem IMAGEM/SOM; proposta de página CONTROLES (taxonomia + ordem + encaixe no fluxo)  
**Fora de escopo:** implementação Godot, motion, hits, Visual Design da folha

**Histórico:** PO OK na taxonomia/ordem IMAGEM·SOM (renames). Esta rev fecha o item CONTROLES pedido no brief.

---

## 0. Decisão pedida (pacote)

- [ ] **Aprovar pacote** (IMAGEM/SOM + CONTROLES como abaixo)
- [ ] **Aprovar com emenda** (listar rótulos/ordem)
- [ ] **Rejeitar CONTROLES** / manter só IMAGEM·SOM congelados

Após A: Docs Lead atualiza playbook §3; A11y valida remap vs §11; Godot UI Dev só depois de Visual+UX da página.

---

## 1. Problema

`OpcoesLista` é fonte única título + `MenuSistema`. Rótulos misturam modelo mental do jogador com jargão de engine (`NEVOA` = clima). Página CONTROLES está prometida (PLANO_UI Fase 4 / playbook P1) e o contrato A11y §11 já existe — falta a taxonomia de linhas antes de código.

---

## 2. Inventário as-is

### 2.1 IMAGEM — `OpcoesLista.video()`

| # | Rótulo hoje | Tipo |
|---|-------------|------|
| 1 | `ESTILO` | ciclo preset |
| 2 | `RESOLUCAO 3D` | escada 480×270…1280×720 |
| 3 | `NEVOA` | ciclo FogPreset |
| 4 | `GRAO` | barra |
| 5 | `ABERRACAO` | barra |
| 6 | `SCANLINE` | barra |
| 7 | `VINHETA` | barra |
| 8 | `DITHER` | toggle LIGADO/DESLIGADO |

Nav (leitores): `SOM >` · `VOLTAR`

### 2.2 SOM — `OpcoesLista.audio()` / `Settings.BUS_ROTULO`

`GERAL` · `MUSICA` · `EFEITOS` · `AMBIENTE` (+ `< IMAGEM` · `VOLTAR`)

### 2.3 RAIZ sistema (hoje)

`CONTINUAR` · `CARREGAR` · `IMAGEM` · `SOM` · `SAIR PARA O TITULO`  
**Sem** `CONTROLES`.

### 2.4 Capacidade folha título (UI-BIBLE §6.6)

IMAGEM = 10 linhas @ 16 px · SOM = 6. Zero linhas novas em IMAGEM/SOM nesta RFC.

---

## 3. Princípios

1. Jogador, não engine.  
2. Preset mestre primeiro (`ESTILO`).  
3. Hot-apply em áudio/imagem; confirm só em destrutivo / remap “ouvir tecla”.  
4. Bitmap ALL CAPS sem acento.  
5. EN só em jargão CRT estável (`SCANLINE`, `DITHER`, `PS1 STYLE`).  
6. Uma fonte por domínio: video/audio em `OpcoesLista`; controles em `OpcoesLista.controles()` (mesmo arquivo, terceira lista — menus só desenham).  
7. Remap fala **ações canônicas** A11y §11 (`ui_*`), não teclas cruas na lógica.  
8. Rótulo ≤ largura de `RESOLUCAO 3D`.

---

## 4. Pacote A — IMAGEM / SOM (aprovado em espírito; congelar)

### 4.1 Rótulos IMAGEM

| # | ID | Rótulo UI | Diff |
|---|-----|-----------|------|
| 1 | estilo | `ESTILO` | — |
| 2 | resolucao_3d | `RESOLUCAO 3D` | — |
| 3 | fog_preset | **`CLIMA`** | era `NEVOA` |
| 4 | grain | `GRAO` | — |
| 5 | chromatic | **`CROMATICO`** | era `ABERRACAO` |
| 6 | scanline | `SCANLINE` | — |
| 7 | vignette | `VINHETA` | — |
| 8 | dither | `DITHER` | — |

Valores: `MODERNO` / `PS1 STYLE` / `PERSONALIZADO`; `"%d x %d"`; fog `display_name.to_upper()`; `blocos()`; `LIGADO`/`DESLIGADO`.

### 4.2 Ordem IMAGEM — **manter**

```
ESTILO → RESOLUCAO 3D → CLIMA → GRAO → CROMATICO → SCANLINE → VINHETA → DITHER
→ SOM > → VOLTAR
```

### 4.3 SOM — **sem mudança**

```
GERAL → MUSICA → EFEITOS → AMBIENTE → < IMAGEM → VOLTAR
```

### 4.4 Diff mínimo (pós-OK pacote)

Só 2 strings em `opcoes_lista.gd` + capturas + playbook §3. Sem reordenar arrays.

---

## 5. Pacote B — proposta CONTROLES (nova)

### 5.1 Onde entra no fluxo

```
MenuSistema RAIZ
  CONTINUAR
  CARREGAR
  IMAGEM      → OpcoesLista.video()
  SOM         → OpcoesLista.audio()
  CONTROLES   → OpcoesLista.controles()   ← NOVO
  SAIR PARA O TITULO

Menu título OPCOES
  página IMAGEM | SOM | CONTROLES
  nav entre páginas:  CONTROLES >  /  < SOM  /  etc. (mesmo padrão SOM >/ < IMAGEM)
```

**Ordem RAIZ proposta** (frequência + anti-destrutivo no fim):

```
CONTINUAR · CARREGAR · IMAGEM · SOM · CONTROLES · SAIR PARA O TITULO
```

`CONTROLES` depois de áudio/imagem (ajuste ocasional). Não sobe acima de CARREGAR.

### 5.2 Modelo mental

| Camada | O que o jogador resolve |
|--------|-------------------------|
| Dispositivo | Qual perfil edito (teclado vs gamepad) |
| Remap | Qual ação = qual input (`ui_*`) |
| Look / feel | Sensibilidade, invert, deadzone |
| Feedback | Vibração |

A11y misturado aqui (invert, deadzone, vibracao) — **não** página ghetto (playbook §10.6).

### 5.3 Linhas da página CONTROLES — ordem

| # | Rótulo UI | Tipo | Comportamento |
|---|-----------|------|----------------|
| 1 | `DISPOSITIVO` | ciclo | `TECLADO` ↔ `GAMEPAD` (perfil em edição; default = último device que gerou `ui_*`) |
| 2 | `REMAPEAR` | subfluxo `>` | Abre lista de ações §5.4; não é `passo` ±1 |
| 3 | `SENS. OLHAR` | barra | Sensibilidade câmera/look (mouse + stick). Nome curto; evita `MOUSE` só (gamepad também) |
| 4 | `INVERTER Y` | toggle | `LIGADO` / `DESLIGADO` |
| 5 | `DEADZONE` | barra | Só relevante com `DISPOSITIVO=GAMEPAD`; com TECLADO: valor `---` disabled (SFX deny A11y) |
| 6 | `VIBRACAO` | toggle | `LIGADO` / `DESLIGADO`; TECLADO → disabled `---` |
| 7 | nav | — | No título: `< SOM` (ou `< IMAGEM` se ordem de páginas for IMAGEM→SOM→CONTROLES) · `VOLTAR` |

**Ordem de páginas no título:** `IMAGEM` → `SOM` → `CONTROLES` (display → áudio → input).  
Nav sugerida:

- IMAGEM: `SOM >` … (igual hoje; CONTROLES alcança via SOM ou atalho futuro)
- SOM: `< IMAGEM` · `CONTROLES >` · `VOLTAR`
- CONTROLES: `< SOM` · `VOLTAR`

Assim SOM ganha **uma** linha nova (`CONTROLES >`). Cabe: 4 buses + 2 nav atuais = 6; +1 = 7 ≪ teto. IMAGEM intacta em 10.

### 5.4 Subfluxo REMAPEAR — rótulos das ações canônicas

Fonte: playbook §11. Uma linha por ação; valor = glifo/tecla atual do `DISPOSITIVO`.

| Ação `ui_*` | Rótulo UI | Notas |
|-------------|-----------|--------|
| `ui_up` | `CIMA` | |
| `ui_down` | `BAIXO` | |
| `ui_left` | `ESQUERDA` | |
| `ui_right` | `DIREITA` | |
| `ui_accept` | `CONFIRMAR` | |
| `ui_cancel` | `CANCELAR` | |
| `ui_open_pause` | `PAUSA` | ESC/TAB / Start |
| `ui_open_sistema` | `SISTEMA` | W / atalho pauzinhos |
| `ui_tab_prev` | `ABA ANT.` | |
| `ui_tab_next` | `ABA PROX.` | |

Rodapé subfluxo: `[CONFIRMAR] ouvir    [CANCELAR] voltar` (copy final com A11y).  
Conflito de bind: linha em tinta de aviso + `ui_deny` SFX; não silenciar.

**Fora do v1 CONTROLES:** remap de ações de gameplay (`mover_frente`, etc.). Fica P2 — senão a lista estoura e mistura menu com world. Documentar no playbook como dívida.

### 5.5 `OpcoesLista.controles()` — contrato de dados

Mesmo shape `{rotulo, ler, aplicar}` para 1,3,4,5,6.  
`REMAPEAR` é entrada especial:

```
{ "rotulo": "REMAPEAR", "tipo": "subfluxo", "alvo": "remap_ui" }
```

Leitores (menu.gd / menu_sistema.gd) já tratam nav `SOM >`; passam a tratar `tipo == subfluxo`. **Não** duplicar lista de binds em dois menus.

Persistência: `Settings` (ou módulo Input) — RFC de eng. com Godot UI Dev; Settings IA só fixa rótulos/ordem.

### 5.6 Capacidade / layout

| Superfície | Linhas CONTROLES | Risco |
|------------|------------------|-------|
| Título (papel) | 6 ajustes + `< SOM` + `VOLTAR` = 8 | OK (< 10) |
| Sistema (folha dinâmica) | 6 + VOLTAR | OK |
| Subfluxo remap | 10 ações + VOLTAR = 11 | sistema OK; título: paginar ou scroll — **A11y+Visual decidem**; taxonomia não corta ações |

### 5.7 Anti-padrões rejeitados

| Ideia | Por que não |
|-------|-------------|
| `CONTROLES` no meio de `video()` | Mistura display com input; quebra modelo BRIEF |
| Rótulos `UI_UP` / nomes de action | Jargão de engine |
| Remap gameplay no v1 | Estoura folha; A11y §11 é menu-first |
| `MASTER` / `MOUSE SENS` em inglês | Quebra voz PT-BR da folha |
| Página A11y separada | playbook: a11y no fluxo |

---

## 6. Mapa mental BRIEF ↔ pacote

| BRIEF | Linhas |
|-------|--------|
| IMAGEM / DISPLAY | `RESOLUCAO 3D` (+ futuros) |
| QUALIDADE / ESTÉTICA | `ESTILO` + `CLIMA` + barras + `DITHER` |
| SOM | buses |
| CONTROLES | §5 |
| A11y | invert / deadzone / vibracao / remap `ui_*` |

---

## 7. Ordem de implementação sugerida (não é código)

1. Strings IMAGEM (`CLIMA`, `CROMATICO`) — diff mínimo  
2. Visual+UX folha RAIZ + pauzinhos (já no ROI do PO)  
3. Mouse Opções título (A11y P0)  
4. `OpcoesLista.controles()` + item RAIZ + nav SOM→CONTROLES  
5. Subfluxo REMAPEAR (A11y + Godot)  
6. Capturas `--ver-pausa=controles` / `--ver-opcoes=controles` (QA)

---

## 8. Riscos

| Risco | Mitigação |
|-------|-----------|
| SOM com 7 linhas no título | Ainda folgado vs teto 10 |
| Remap 11 linhas no papel | Visual: segunda página ou lista rolável; não cortar ações §11 |
| `SENS. OLHAR` sem setting hoje | Linha pode nascer disabled até Settings ter chave — ou omitir no v1 se PO preferir só remap+toggles |
| Deadzone/vibração no teclado | Disabled + `---` + deny SFX |

**Emenda opcional v1 magro:** só `DISPOSITIVO` · `REMAPEAR` · `INVERTER Y` · `VIBRACAO` (+ nav). `SENS. OLHAR` / `DEADZONE` no v1.1 quando houver persistência.

---

## 9. Checklist de copy (congelar se aprovado)

**IMAGEM:** `ESTILO` `RESOLUCAO 3D` `CLIMA` `GRAO` `CROMATICO` `SCANLINE` `VINHETA` `DITHER`  
**SOM:** `GERAL` `MUSICA` `EFEITOS` `AMBIENTE`  
**CONTROLES:** `DISPOSITIVO` `REMAPEAR` `SENS. OLHAR` `INVERTER Y` `DEADZONE` `VIBRACAO`  
**Remap:** `CIMA` `BAIXO` `ESQUERDA` `DIREITA` `CONFIRMAR` `CANCELAR` `PAUSA` `SISTEMA` `ABA ANT.` `ABA PROX.`  
**Nav/RAIZ:** `IMAGEM` `SOM` `CONTROLES` `VOLTAR` `SOM >` `CONTROLES >` `< IMAGEM` `< SOM` `CONTINUAR` `CARREGAR` `SAIR PARA O TITULO`


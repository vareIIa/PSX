# ADDENDUM AAA-RE — Spec Visual (pauzinhos + RAIZ)

Anexo à `SPEC_VISUAL_PAUZINHOS_FOLHAS.md`. Pivô Jamerson 19/09/2026.
Base locked intacta; eleva profundidade/tipo/focus. Sem glass barato. Sem código.

 — profundidade / tipo / focus rico
**Pivô Jamerson (19/09/2026):** menus **podem e devem** ser AAA com profundidade e animação. Inspiração: overlays *Resident Evil* (peso, stagger, focus legível). **Não** forçar lo-fi PSX. Base locked (§0.1) permanece; este addendum **eleva** o polish.

### A.0 O que muda / o que não muda

| locked (não reabrir) | eleva (este addendum) |
|---|---|
| Hit aba ≥32×32 | Chip com **placa + moldura + sombra em degrau** (mais “objeto”) |
| Título **SISTEMA** | Título com **peso + filete duplo** (régua 1px + gap 2 + fio fino) |
| CONTINUAR default focus | CONTINUAR = **hero row** (stain mais largo + tracking) |
| SAIR destructive `DESTAQUE` | SAIR = tinta quente + **separação espacial** maior do grupo |
| Focus = stain + barra 2px + `>` | Focus **rico**: inset 1px + barra 2px + `>` + opcional second-shadow interno |
| Zero glass barato | Profundidade = **camadas opacas + offset**, nunca blur/frost |
| `T_MENU_*` (Motion) | Visual especifica *keyframes de aparência*; Motion executa |

### A.1 Profundidade de painel (folha)

Empilhar **3 retângulos opacos**, zero blur:

```
scrim full α0.55–0.62          (mais denso que o mínimo locked — peso RE)
  sombra dura +3,+3 α0.50      (degrau 1 — “chão”)
  sombra dura +1,+1 α0.35      (degrau 2 — contato)
  PAPEL fill #e6dfc4           (corpo)
  filete interno 1px           (PAPEL × 1.08 luma — “bisel” seco, não glow)
  borda 1px TINTA              (silhueta)
```

| peça | px | nota |
|---|---|---|
| Folha X/Y/L | 146 / 44 / **192** | +4 L vs 188 — respiro tipográfico AAA; ainda centrada |
| Cantos | **0** | RE clássico = caixa ortogonal |
| Header band | altura **22** | bloco título separado do body por filete |
| Body pad | **12** sides / **10** top below header | |
| Footer band | altura **18** | dicas; `TINTA_FRACA`; opcional fio superior 1px |

**Anti-padrão:** um único `draw_rect` chapado + `>` — isso é o “lista debug” que o UX matou.

### A.2 Hierarquia tipográfica (RAIZ)

| papel | size | cor | tracking / peso | uso |
|---|---|---|---|---|
| Título página | **14–16** | `TINTA_TITULO` | +1px letterspace se bitmap permitir | `SISTEMA` |
| Hero (`CONTINUAR`) | **11–12** | `TINTA` idle → `DESTAQUE` focus | stain w = L−24; barra 2×12 | default |
| Nav (`CARREGAR`, `IMAGEM`, `SOM`) | **11** | `TINTA` | chevron `▸` 6px à direita | |
| Destructive (`SAIR…`) | **11** | `DESTAQUE` **mesmo idle** | gap seção **10** acima (não 6) | |
| Meta / dica | **10–11** | `TINTA_FRACA` | footer | |

Ordem visual de leitura (olho):
1. título SISTEMA  
2. CONTINUAR (já focado)  
3. bloco ajustes  
4. SAIR (ameaça controlada)  
5. dica input  

### A.3 Focus rico (não glow)

Composição do item focado (de trás pra frente):

1. **Stain** preto α **0.10–0.12** (hero CONTINUAR pode 0.14) — retângulo inset PAD−2  
2. **Inset line** 1px `TINTA` α 0.25 no topo do stain (bisel interno)  
3. **Barra** 2×10–12 `DESTAQUE` @ x = folha.x+4  
4. Glyph **`>`** em `DESTAQUE` @ PAD−7  
5. Label em `DESTAQUE`  

Proibido: outline neon, shadow blur, pulse RGB, scale bounce > 1.02.  
Permitido (Motion): stagger de opacity/offset Y **1–3px** na abertura; press 80–150ms (escurece stain 1 frame).

### A.4 Aba pauzinhos — objeto, não risco

| camada | spec |
|---|---|
| Hit invisível | **32×32** @ (441, 14) — A11y §11 |
| Placa | **24×20** centrada no hit |
| Moldura | borda 1 `TINTA` + filete interno 1px claro |
| Sombra | +2,+2 α0.40 |
| Barras | 3× **16×2.5** gap 3; idle `TINTA`; hover/focus borda `DESTAQUE` |
| Aberto | fill `PAPEL_ABERTO`; barras levemente mais curtas (14) = “pressionado” |

Affordance sob CRT: placa **acima do pós**; contraste placa/fundo ≥ o do inventário scrapbook.

### A.5 Stagger de entrada (contrato visual → Motion)

| beat | aparência | ms (banda PO) |
|---|---|---|
| 0 | scrim fade-in | 0–80 |
| 1 | sombra+folha sobem 3px → 0 + fade | 80–200 (`T_MENU_OPEN` ~0.20) |
| 2 | título | +40 stagger |
| 3 | CONTINUAR (já focused) | +40 |
| 4 | demais linhas | +30 cada |
| 5 | footer dica | final |

Close: reverso mais rápido (`T_MENU_CLOSE` ~0.14). Input nunca espera >250ms.

### A.6 O que NÃO é AAA-RE aqui

- Glass / blur / frosted  
- “PS1 crunch” artificial na UI (dither de painel, fonte quebrada) — mundo 3D pode ser PSX; **menu é overlay de produto**  
- Lista monoespaçada sem grupos  
- Focus só por troca de cor  

### A.7 DoD addendum

- [ ] Folha com ≥2 degraus de sombra + filete interno  
- [ ] Header band distinto do body  
- [ ] CONTINUAR hero + SAIR separado  
- [ ] Focus = stain+inset+barra+`>`  
- [ ] Aba = placa moldurada dentro hit 32  
- [ ] Stagger documentado; Motion consome `T_MENU_*`  
- [ ] Captura `f4_raiz` / `f4_pauzinhos` refeitas pós-implementação  

*Visual Design — base locked + AAA-RE. Sem código até PO liberar Dev.*

# PROGRESSO — PSX (handoff Grok Bot)

Atualizado: 2026-09-08 (noite, America/Montevideo).
Para a **proxima sessao**: leia esta secao 0 e a secao 1 antes de qualquer task.

---

## 0. Pedido do Jamerson — fluxo cinematico (CANONICO)

Ordem obrigatoria do novo jogo:

1. **Criar boneco** — tela de criacao estilo **carteira/identidade** aberta, **clicavel** (mouse).
   - Fundo: personagem **sentado no banco do piloto** (cabine: volante, pernas, micro-movimento).
   - Ao confirmar → entra direto na cena do carro.
2. **Cinematica no meio do mato (Estrada Velha)** — interior MG, estrada de terra, selva, noite.
   - Fala/legendas no carro (tom jovem); frase-chave: *“Sem maldade, essa estrada nao parece ter fim.”*
   - Fecha em: *“Ai eu peguei o carro e vim.”* → **blackout** (nao fecha a historia).
3. **Cinematica que comeca na praca (Praça da Matriz)**
   - **Nao** anima o personagem levantando.
   - **POV curto:** efeito de abrir o olho, olhando pro **ceu / nevoa pura**, olhar pra um lado e pro outro.
   - **Depois:** camera **cinematica externa** (cima / 3-4): da pra ver o personagem **DEITADO** na frente da igreja; **cada legenda muda o take**.
   - Falas = lacuna de memoria (farol na terra → apagou → acorda na praca; cade o carro/pousada) — **nao** reexplica a viagem.
4. **Gameplay** — devolve controle apos a abertura (resto da cidade / missao).

Resumo numa linha: **carteira no banco → cutscene mato → acordar na praca → jogar**.

---

## 1. Estado do repo AGORA

| Item | Valor |
|------|--------|
| Path | `C:\Users\Administrator\Documents\Codes\Games\PSX` |
| GitHub | `vareIIa/PSX` |
| PC | KernelOS-PC |
| Godot | 4.7.2 em `.tools\` |
| Branch | `feat/estrada-velha` |
| Tip conhecido | merge blitz `c244c04` (Blitz AAA dentro) |
| Worktree blitz | `...\PSX-blitz-aaa` → `feat/blitz-aaa` @ `0238181` (ja mergeado) |
| Skill captura | `psx-godot-captures` (janela + `--shot*`; headless nao prova shader) |

### Pendencias tecnicas abertas no git
- Stash `wip-pre-merge-blitz-aaa` ainda no repo (pop falhou por WIP em `kit_parque.gd` / `parque_builder.gd`).
- Muitos untracked: `PRINTS\ref_*`, `PROGRESSO.md`, `captures\`, `_tmp` tools — **nao apagar** sem revisar.
- Backup captures blitz: `C:\Users\Administrator\Documents\Codes\Games\_bak_blitz_captures`

### Processo
- **Jota - PO** = fila/brief. **PO Helper** = gate.
- Gate **afrouxado:** PASS + notas; FAIL so bug critico (crash, debug no frame, chao invisivel de verdade).
- **Hermes (Fusca) + Renato (Marea) PAUSADOS** ate Jamerson liberar.
- Ownership: `abertura.gd` / `_plano_da_praca` = **Cine2**. Bob = `abertura_estrada.gd` + emenda. Cleiton nao toca `abertura.gd`.

---

## 2. Time de bots

| Bot | Id (prefixo) | Papel |
|-----|--------------|--------|
| Jota - PO | `78883c78` | Orquestra |
| PO Helper | `a4991417` | Gate PASS+notas |
| Carteira - Criacao | `09bb3b9f` | UI carteira + mouse + fundo cabine |
| Motorista - Cabine Estrada | `86b99552` | Cabine 1P/3P, chao/flora, PackedScene criacao |
| Bob - CINEMATIC | `3ee0b69f` | Emenda Estrada→Abertura + FALAS estrada |
| Cinematic 2 - Acordar Praca | `9c29832c` | Plano praca (POV + takes externos) |
| Cleiton Pedreiro dos Mapas | `b613effc` | Layout praca / igreja / coreto / cruz |
| Renatin - HUD | `b3850a66` | LOCAL/HORA |
| Policial - Blitz | `6c29032d` | Blitz AAA (A/D/E) |
| HERMES | `fae75ad9` | Fusca + vidro — **PAUSADO** |
| RENATO | `1b6b9cc5` | Marea — **PAUSADO** |

Grupo: `Jamerson Nascimento, PO Helper, Jota - PO` (`bfdeadbf-…`).

---

## 3. O que ja foi feito (por etapa do fluxo)

### 3.1 Criar boneco (Carteira + Motorista)
**Pedido:** carteira/passport aberta, mouse, fundo cabine piloto → floresta.

**Feito:**
- Mouse hit-areas `578134c`
- PackedScene fundo: `res://scenes/player/cabine_fundo_criacao.tscn` (`aaafc5b`)
- SubViewport live + polish print02 `246864a`
- Follow-up maos / passport / pescoco / cabine `d6076cd`

**Refs:** `PRINTS\ref_criacao_personagem\` (`01_atual_teclado.png`, `02_alvo_passport.jpg`)
**Provas:** `captures\criacao\01_base.png` … `05_chapeu.png`

**Notas (nao bloqueia):** cabine ainda pode ficar mais legivel atras da carteira em algumas caps.

### 3.2 Cinematica meio do mato (Estrada Velha)
**Pedido:** MG terra/selva; jogavel + cutscene; antes da praca; chao visivel; floresta nao colada; legendas.

**Feito:**
- Cabine jogavel 1P↔3P; emenda em `_rodar_abertura` (estrada antes da Abertura)
- HUD LOCAL/HORA
- FALAS `7418dc1` (incl. “Sem maldade, essa estrada nao parece ter fim.”)
- P0 vidro (para-brisa nao preto): Hermes face unica + Renato `com_vidros_frente=false` no CarroCena
- P0 chao + corredor `5ba468d` **PASS** (chao legivel + carro/mata afastada)
- Merge blitz nao afeta essa cena diretamente

**Refs:** `PRINTS\ref_estrada_velha\04_fp_chao_flora.png`
**Provas:** `captures\estrada_velha\cabine\fp_p0_chao.png`, `tp_p0_chao.png`, `falas\dentro_1_noite.png`, `emenda\`, `hud\`

**Aberto:** polish AAA barro/cipo/casebre vs ref 04 (follow-up).

### 3.3 Cinematica praca (acordar)
**Pedido:** POV olho/ceu/nevoa look L/R → takes externos personagem DEITADO + igreja; 1 take/legenda; falas continuidade.

**Feito:**
- Sequencia implementada (Cine2); pin acordar `270,-40`; look ~`271,-51`
- Cleiton: igreja perto; coreto fora do eixo; punch fachada; **cruz punch** (`13_cruz_punch.png`)
- B PASS+notas; debug vermelho removido; reshoot pos-punch `6fcd93c`
- FALAS praca continuidade (farol → apagou → praca…)

**Refs:** `PRINTS\ref_praca_matriz\`
**Provas:** `captures\praca_matriz\cine\01_acordar_ceu.png`, `02_deitado_igreja.png`, `mapa\11_fachada_punch.png`, `mapa\13_cruz_punch.png`

**Aberto:** Cine2 pode reshoot apos cruz; polish nevoa/legibilidade (nao trava).

### 3.4 Gameplay / Blitz (pos-abertura)
**Pedido:** Blitz AAA (zebra, viatura, FSM, motorista desce e conversa).

**Feito:**
- A / D / E PASS (soft gate)
- Clip “NPC em pe dentro do carro” corrigido em E
- **Merge** `feat/blitz-aaa` → `feat/estrada-velha` = **`c244c04`**

**Provas:** `captures\blitz\A_*.png`, `D_insp_janela.png`, `E_estacionado.png`

### 3.5 Carros Fusca/Marea — PAUSADO
Vidro P0 ok. Fusca silhueta nao aceita (passada 2 parada). So retomar se Jamerson pedir.
Refs: `PRINTS\ref_fusca\`, `PRINTS\ref_marea\`, `PRINTS\CARROS\`

---

## 4. Arquivos-chave

| Area | Path |
|------|------|
| Criacao | `game/src/ui/criacao.gd`, `menu.gd`, `scenes/player/cabine_fundo_criacao.tscn` |
| Estrada | `game/src/levels/abertura_estrada.gd`, `world/estrada_builder.gd`, `kit_estrada.gd`, `carro_cabine.gd`, `carro_cena.gd` |
| Emenda / cidade | `game/src/levels/cidade.gd` (`_rodar_abertura`, `_rodar_estrada`) |
| Praca cine | `game/src/levels/abertura.gd` (`_plano_da_praca`) — **dono Cine2** |
| Cinema engine | `game/src/ui/cinematica.gd` |
| Praca mapa | `world/parque_builder.gd`, `kit_parque.gd` |
| Blitz | `world/blitz.gd`, `blitz_manager.gd`, `kit_blitz.gd`, `carro.gd` |
| Vidro / lataria | `render/carroceria.gd` |

Flags uteis: `--ver-aparencia`, `--ver-estrada`, `--ver-estrada-cabine`, `--ver-praca`, `--ver-abertura`, `--pular-abertura`, `--blitz-demo`, `--olhar-blitz`, `--shot*`, `--fog=`

---

## 5. Fila sugerida na proxima sessao

1. Smoke do fluxo completo: criacao → estrada → praca → gameplay (CaptureTool).
2. Smoke blitz pos-merge (`c244c04`) A/D/E.
3. Resolver stash / WIP parque se ainda conflitar.
4. Polish opcional: flora estrada vs ref 04; cruz/fachada praca; cabine atras da carteira.
5. **Nao** retomar Fusca/Marea sem ordem do Jamerson.
6. Atualizar este arquivo a cada marco.

---

## 6. Commits ancora (referencia rapida)

```
c244c04 Merge feat/blitz-aaa into feat/estrada-velha
6fcd93c fix(cine): reshoot Gate B pos-punch fachada
d6076cd fix(ui): criacao maos / print02 follow-up
246864a criacao print02 + cabine SubViewport
5ba468d estrada P0 chao + corredor
1116adf praca POV + takes + FALAS
7418dc1 FALAS Estrada continuidade
0238181 (blitz) E AAA motorista a pe
4c08e7e (blitz) D AAA close-up janela
```

---

*Gerado/atualizado por Jota - PO para handoff. Fonte da verdade do fluxo cinematico = secao 0 (pedido Jamerson).*

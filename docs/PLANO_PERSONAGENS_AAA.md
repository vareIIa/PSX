# PLANO PERSONAGENS AAA — rosto, fala, gesto e jeito de cada um

> 23/09/2026 · referências: RDR2 (gesto de conversa, olhar), Yakuza (rosto em conversa),
> Disco Elysium (fala com cara), Metal Gear Solid 1 (boca em textura no PS1)
> Código base: `src/render/corpo.gd`, `src/render/reacao_corpo.gd`, `src/systems/voz.gd`,
> `src/ui/conversa.gd` · regra que não muda: **a cabeça continua caixa** (o AAA vai no
> que a caixa faz, não no formato dela)

## 0. Diagnóstico — por que as pessoas ainda não parecem vivas

| sintoma | causa no código |
|---|---|
| a boca não mexe quando falam | `Corpo.falar()` só guarda `_falando` (`corpo.gd:809`). Ele balança a cabeça ±0,05 rad e sobe um antebraço. Não há boca: o rosto é **uma** célula de 32 px com a boca pintada numa linha de 1 px (`gerar_npc.py:171-179`). O comentário "a boca mexendo" em `conversa.gd:110` promete o que não existe |
| cara sempre igual | não há sobrancelha, olho nem expressão animados. Só a pálpebra pisca, e **só na tela de criação** (`retrato_estudio.gd:206`). O busto da conversa, a rua e o jogador nunca piscam |
| todo mundo anda igual | a ficha só varia `passo` e `cadencia` (`aparencia.gd:307-308`). Ócio, postura, cabeça, gesto e ritmo de piscar são iguais para todos. O temperamento (`personalidade.gd`, 12 tipos) muda velocidade e voz, não o corpo |
| gente muda em conversa | o PM da blitz e o motorista não têm `dizer()`, então a conversa com eles não tem voz (`conversa.gd:383`). `Convidado.dizer` toca voz sem gesto (`convidado.gd:1802`). O morador (`Dialogo`) não tem voz nem retrato |
| voz e texto descasados | `Voz` toca no máximo 7 sílabas, ~0,95 s (`voz.gd:66`). O texto sai a 44 caracteres/s: uma frase de 100 letras digita por 2,3 s, e a voz acabou na metade. Pular a linha não cala a voz |
| quem escuta é estátua | enquanto o jogador escolhe, o busto para. Nenhuma opção provoca reação (nem riso, nem nojo, nem susto). Os 15 gestos de `ReacaoCorpo` só existem na criação |
| mudança de postura é salto | `postura()` troca na hora (`corpo.gd:814`). Sentar, levantar, parar de andar: tudo em um quadro |
| olhar de câmera de vigilância | `olhar_lateral` só gira em yaw (7 passos). Não há olho, não inclina a cabeça, o tronco não acompanha, e ninguém olha para baixo ou para cima |
| faltam poses inteiras | não há corrida (a passada só escala até 1,3x), agachar (é escala Y 0,6), pedalar, sobressalto, queda, entregar na mão, abrir porta. O motorista IA congela a pose de dirigir no primeiro quadro (`carro.gd:1008`). O jogador some ao entrar no carro, e o banco fica vazio visto de fora |
| linhas sem intenção | o diálogo é `Array[String]` em `const`. Não diz emoção, pausa nem gesto. A única pista é o temperamento de quem fala e o `?` no fim da frase |

O que **já está bom** e serve de base: o esqueleto é procedural e barato, com cache de
pose por assinatura. A camada de reação mistura por envelope e passa em teste de alvo de
mão com 4,5 cm de tolerância. A pálpebra já prova o **sobreposto na cara** (quad no osso
da cabeça, tingido de pele). A `Voz` já sabe a vogal de cada sílaba que toca (banco 1–8
= a, e, o, i, u, a, e, o). `plano_do_rosto()`/`tamanho_do_rosto()` já são API pública
para colar coisa na cara.

## 1. Regras do plano

1. **Cabeça caixa**, com o rosto pintado. Expressão é **troca de desenho** em pedaços do
   rosto (boca, sobrancelha, olhos), no padrão da pálpebra. Não há blend shape nem
   geometria de rosto. Isso respeita o ART-BIBLE §10 e o `psx-assets` ("sem blend
   shape"), e continua sendo o jeito do Metal Gear Solid.
2. **Um relógio só para fala**: texto, voz e boca andam pela mesma sílaba. Nada de três
   timers que por acaso batem.
3. **Tudo em passos de 15 Hz**, como já é o corpo. Boca a 15 Hz é exatamente o que
   jogo grande faz com viseme. Corpo liso no MODERNO é decisão sua (§9).
4. **Variação sai da ficha**. A mesma pessoa tem o mesmo jeito sempre, em rede também,
   sem sortear na hora (`randf()` global na piscada é o contraexemplo, `corpo.gd:798`).
5. **Ossos novos no fim do enum**, como SAIA/BARRIGA: os índices que o jogo usa não
   mudam. O teto do ART-BIBLE é 24, e hoje são 14.
6. **Custo por distância**: detalhe de rosto e gesto só onde o olho alcança. A multidão
   não pode pagar pelo busto.
7. **Cada item entra com régua** (situação montada + número), não com foto olhada.

## 2. Fundação A — Rosto (boca, sobrancelha, olhos)

### 2.1 Folha de rosto gerada junto com a cara

As caras da rua têm olho, boca e sobrancelha em posições **sorteadas** (olho em y 13–15,
boca de 4–6 px com curva −1/0/+1, batom, barba por fazer; `gerar_npc.py:108-203`). Um
sobreposto genérico erraria o lugar e a cor. Então o **próprio gerador** desenha, para
cada uma das 34 caras (16 da rua, 16 de estúdio, Helmer e Jota), as variações de cada
pedaço com a mesma receita, pele, batom e barba:

| pedaço | estados | tamanho na célula |
|---|---|---|
| boca (viseme) | FECHADA (o desenho original), ENTREABERTA, ABERTA, REDONDA (o/u), SORRISO, TRISTE, CERRADA | faixa ~12×6 px |
| sobrancelha | NEUTRA, ERGUIDA, FRANZIDA, CAIDA (tristeza), UMA_ERGUIDA (desconfiança) | faixa ~22×4 px |
| olhos | ABERTO, ARREGALADO, SEMICERRADO, FECHADO (a pálpebra atual), OLHA_ESQ, OLHA_DIR | faixa ~22×5 px |

- Destino: **`rosto_atlas.png` novo** (≈34 × 18 faixas pequenas). O `npc_atlas.png` fica
  como está, e o gerador escreve uma tabela `RostoMeta` (`src/systems/rosto_meta.gd`,
  gerado) com a posição de cada pedaço em cada cara.
- MODERNO: o `gerar_npc_hd.py` passa a folha pelo mesmo Scale2x ×2 e normal plana.
- No corpo: três quads colados no plano do rosto (`plano_do_rosto()`), presos em
  CABECA, cada um trocando de UV. São 6 triângulos, só com `detalhado`.

### 2.2 `Rosto`, a camada viva da cara

Classe nova `src/render/rosto.gd`, que pertence ao `Corpo` e é ligada por `corpo.rosto`:

- `expressao(tipo, intensidade, duracao)` → combinação de pedaços. Tabela inicial:

| expressão | sobrancelha | olhos | boca em repouso |
|---|---|---|---|
| NEUTRA | NEUTRA | ABERTO | FECHADA |
| SIMPATIA | ERGUIDA (leve) | ABERTO | SORRISO |
| RISO | ERGUIDA | SEMICERRADO | ABERTA |
| RAIVA | FRANZIDA | SEMICERRADO | CERRADA |
| DESCONFIANCA | UMA_ERGUIDA | SEMICERRADO | FECHADA |
| MEDO | ERGUIDA | ARREGALADO | ENTREABERTA |
| SURPRESA | ERGUIDA | ARREGALADO | REDONDA |
| TRISTEZA | CAIDA | ABERTO → baixo | TRISTE |
| NOJO | FRANZIDA | SEMICERRADO | TRISTE (torta) |
| CHAPADO | NEUTRA | SEMICERRADO | ENTREABERTA (+ olho vermelho que já existe) |
| BEBADO | CAIDA | SEMICERRADO, piscada lenta | ENTREABERTA |

- **Piscar em todo lugar**: a piscada sai de `retrato_estudio` e vai para o `Rosto`, com
  ritmo **da ficha**. Pisca ao terminar frase, ao virar a cabeça, e mais no ASSUSTADO.
- **Microexpressões** automáticas: sobrancelha sobe na pergunta (`?`), olhar desvia
  para o lado no `...`, e a boca volta ao repouso da expressão quando a fala acaba.
- **Olhos**: uma pupila de 1 px para a esquerda ou para a direita já é olhar. O olho
  chega ao alvo **antes** da cabeça (§4).

## 3. Fundação B — Fala: texto, voz e boca num relógio só

### 3.1 `Fala`, um componente para quem fala

Hoje falar é `dizer()` (voz) de um lado, `falar(bool)` (gesto) de outro e a digitação da
UI de um terceiro. Proposta: um componente `Fala` (`src/systems/fala.gd`) preso ao
falante, e **toda** fala do jogo passa por ele:

```
Fala.dizer(linha: String, opcoes := {})   # linha pode ter marcas (§3.3)
  ├─ separa a linha em sílabas do português (regra simples: vogal = núcleo)
  ├─ a cada sílaba, num passo de 15 Hz:
  │     voz   → toca o banco com a MESMA vogal da sílaba (a/e/i/o/u já existem)
  │     boca  → viseme da vogal (a→ABERTA, e/i→ENTREABERTA, o/u→REDONDA),
  │             consoante inicial fecha 1 passo (p/b/m fecham de verdade)
  │     texto → a UI revela os caracteres daquela sílaba (sinal `silaba_dita`)
  ├─ pausa em vírgula (~0,18 s) e ponto (~0,35 s): voz cala, boca fecha, texto espera
  ├─ gesto de fala (§5) no começo de cada frase e na ênfase
  └─ `pular()` cala voz, fecha boca e entrega o texto inteiro (hoje a voz segue tocando)
```

- A voz continua **ininteligível** (filosofia de `voz.gd:1-15`). O que muda é que a
  vogal do som, a da boca e a da letra na tela passam a ser a mesma.
- `Conversa`, `Dialogo`, `Cinema.fala` e as falas de rua deixam de ter relógio próprio
  e escutam `silaba_dita`. A velocidade de 44 cps passa a ser a cadência do falante
  (`aparencia.cadencia` × temperamento): o TAGARELA digita mais rápido e o MELANCOLICO
  arrasta.
- Sem som (`AudioDirector.silencioso()`), a boca e o texto seguem o mesmo relógio.

### 3.2 Quem hoje fala mudo ou sem corpo

| falante | hoje | com `Fala` |
|---|---|---|
| PM na conversa da blitz | sem voz, sem gesto | voz grave, RAIVA/DESCONFIANCA, gestos de ordem |
| PM gritando "Encosta aí" | só legenda | voz alta + CONTROLE que já existe + boca |
| motorista na conversa | o alvo é o `Carro`, sem `dizer` | o `Carro` repassa ao `Corpo` do motorista |
| motorista xingando na fila | voz sem corpo | cabeça para fora, gesto de braço (§6) |
| convidado, dono da casa, Jota, Helmer | voz sem `falar` | fala completa |
| morador (`Dialogo`) | sem voz, sem retrato | voz + busto como a `Conversa` (ou `Dialogo` vira modo da `Conversa`) |
| cliente iWeed, entregador | legenda + `falar` por tempo fixo | fala completa, com a duração vindo da linha |
| susto "Eh!" do pedestre | mudo em quem nunca falou (`pedestre.gd:668`) | `Fala` nasce com o corpo e não depende do primeiro `dizer` |

### 3.3 Linhas com intenção, sem reescrever o texto

Marcas **dentro** da string, entre colchetes. As chaves `{...}` já são do
`FalasNpc.costurar`. A UI nunca mostra as marcas:

```
"[desconfianca]Documento? [pausa]Sei não... [gesto:nega]Tá limpo, pode ir."
"[riso]Ha! Essa foi boa."            "[olha:longe]Aqui era tudo mato."
```

- Marcas: `[expressão]`, `[pausa]`, `[gesto:x]`, `[olha:x]` (longe, chão, jogador,
  alvo), `[rapido]`/`[devagar]`, `[grita]`, `[sussurra]` (volume e alcance da voz).
- Linha sem marca não fica neutra: a expressão de base vem do **temperamento** (§4.2)
  e a pontuação faz o resto (`!` dá ênfase e gesto, `?` ergue a sobrancelha, `...`
  desvia o olhar).
- Assim os ~300 textos de hoje (`personalidade.gd`, `falas_npc.gd`, `falas_morador.gd`,
  `venda_da_loja.gd`) melhoram **sem nenhuma edição**, e as marcas entram só nas linhas
  que pedem.

## 4. Fundação C — Olhar e jeito de cada um

### 4.1 `Olhar`: alvo, prioridade, olho antes da cabeça

- Substitui a chamada direta de `olhar_lateral` pelos 9 lugares que a usam.
- Alvo com prioridade: conversa > quem falou com ele > jogador a menos de 3,6 m > barulho
  (buzina, carro rápido, grito) > ponto de interesse do lugar (TV do bar, vitrine,
  celular) > vagar.
- Ordem: **olhos** no mesmo passo → **cabeça** 1–2 passos depois, em yaw **e pitch**
  (pitch novo; olhar o chão, o celular, o prédio) → **tronco** acompanha 30% além de
  45° → o **corpo** vira no lugar além do limite, com passos curtos (§6) em vez de
  girar deslizando.
- Contato de olho por temperamento: o ASSUSTADO e o VIGARISTA desviam, o MANDAO encara,
  o SONHADOR olha para cima.
- Continua em passos, mas o olho dá o salto (sacada) e a cabeça vem depois. É isso que
  tira a sensação de câmera de vigilância, mais do que suavizar.

### 4.2 `Jeito`: a assinatura de movimento da pessoa

Um dicionário novo `Aparencia.jeito(a)`, gerado da ficha (`_h(id, canal)`, canais novos
a partir de 27) e **modulado** pelo temperamento, pela idade e pela gordura. É lido pelo
`Corpo`, pelo `Rosto` e pelo `Olhar`:

| eixo | faixa | quem modula |
|---|---|---|
| curvatura do tronco / ombro caído | −0,08..+0,06 rad | idade, MELANCOLICO (+), MANDAO (−) |
| cabeça alta/baixa | −0,1..+0,12 rad | MELANCOLICO baixa, MANDAO alta |
| balanço de braço | 0,6..1,3 × `AMPLITUDE_BRACO`, com assimetria | APRESSADO grande, CINICO pequeno |
| mãos quando anda | livres, no bolso, atrás das costas, alça da bolsa, celular | ficha + roupa (bolso só com calça ou casaco) |
| quique vertical | 0,6..1,5 × 2,2 cm | idade (−), gordura (bamboleio lateral) |
| largura de passo | 0..6 cm | gordura, BEBADO (zigue-zague) |
| ócios preferidos | 3 do conjunto de ~12, com peso | temperamento (§5.2) |
| frequência e amplitude de gesto | 0,4..1,6 | TAGARELA e VIGARISTA alto, DESCONFIADO baixo |
| ritmo de piscar | 2..6 s | ASSUSTADO rápido, CHAPADO lento |
| velocidade de virar a cabeça | 1..3 passos | ASSUSTADO rápido |
| fase inicial do ciclo | 0..1 | ficha (hoje depende de quando o pedestre nasce) |

Temperamentos com corpo próprio (todos existem em `personalidade.gd`):

- **APRESSADO**: passo longo, olha o relógio (`OCIO_RELOGIO` já existe).
- **MELANCOLICO**: cabeça baixa, ombro caído, arrasta o pé.
- **BEBADO**: oscila de lado, corrige o equilíbrio, para e se apoia.
- **ASSUSTADO**: olha por cima do ombro, se encolhe com barulho.
- **MANDAO**: peito aberto, mão na cintura parado.
- **DEVOTO**: mãos juntas, se benze ao passar pela igreja.
- **VIGARISTA**: olhar rápido para os lados, esfrega as mãos.
- **TAGARELA**: gesto largo, conta nos dedos.
- **SONHADOR**: olha para o alto.
- **GENTIL**: acena com a cabeça para quem passa.
- **CINICO**: braços cruzados.
- **DESCONFIADO**: olha de canto e segue o jogador com o olho.

Régua: 50 pedestres com fichas seguidas. As assinaturas de pose do ciclo de andar e do
ócio precisam dar ≥ 40 jeitos distinguíveis, e a mesma ficha dá sempre o mesmo jeito.

## 5. Fundação D — Gestos (fala, escuta, ócio, reação)

A camada `ReacaoCorpo` já resolve o que falta (envelope, alvo de mão, régua de 4,5 cm).
Ela deixa de ser "da criação" e vira a biblioteca de gestos do jogo.

### 5.1 Gestos novos

| grupo | gestos |
|---|---|
| fala | EXPLICA (palma aberta), APONTA (alvo livre), DA_DE_OMBROS, NEGA (cabeça), CONCORDA (cabeça), CONTA_NOS_DEDOS, BRACOS_ABERTOS, MAO_NO_PEITO, ESFREGA_MAOS, BATE_NA_MAO (ênfase) |
| escuta | CONCORDA leve, CRUZA_BRACOS, MAO_NA_CINTURA, COCA_NUCA, MAO_NO_QUEIXO (já é ROSTO), peso de perna (`OCIO_PESO`) |
| cumprimento | ACENO_OI, ACENO_TCHAU, APERTO_DE_MAO (dois corpos), TOCA_O_CHAPEU (já existe CHAPEU) |
| reação | SOBRESSALTO, PROTEGE_ROSTO, RECUA, MAOS_PRO_ALTO, MAOS_NO_CAPO (revista), RISO (já há `rir`), XINGA (braço), SE_BENZE |
| objeto | ENTREGA, RECEBE, PEGA_DA_PRATELEIRA, POUSA_NO_BALCAO, CELULAR_NO_OUVIDO, OLHA_O_CELULAR, ACENDE_CIGARRO |

### 5.2 Ócios com gente dentro

O conjunto sobe de 3 para ~12: celular, relógio, peso, olhar em volta, espreguiçar,
coçar o braço, arrumar a roupa, amarrar o sapato (agachado), bocejar (boca ABERTA +
olhos fechados), mãos no bolso, cruzar os braços, fumar (já existe FUMANDO). Cada pessoa
usa os **3 dela** (§4.2), com intervalo da ficha. Dois ócios iguais lado a lado viram
coreografia.

### 5.3 Escuta ativa na conversa

- Enquanto o jogador escolhe (fase ESCOLHENDO), o busto e o corpo no mundo não congelam:
  piscam, fazem o gesto de escuta do temperamento e olham para o jogador.
- **Cada opção provoca reação** antes da resposta: escolher "sair" faz a expressão
  cair; oferecer café ao PM ergue a sobrancelha; xingar dá RAIVA e XINGA. A regra fica
  numa tabela `opcao → (expressão, gesto)` em `falas_npc.gd`, ao lado das listas de opções.

## 6. Fundação E — Poses que faltam e passagens

### 6.1 Ossos novos (14 → 19 de 24)

| osso | para quê |
|---|---|
| PESCOCO | divide cabeça e pescoço: pitch do olhar sem torcer o colarinho, cabeça para fora da janela |
| MAO_E, MAO_D | punho: acenar, apontar, entregar, segurar o volante, apoiar na mesa |
| PE_E, PE_D | pé plano no chão ao parar, ponta na corrida, pé no pedal, sentado cruzado |

A pele passa a pesar punho e tornozelo em anel de junta, como já se faz no cotovelo. O
teste de braço dentro da barriga e o de pé abaixo do piso têm de continuar verdes.

### 6.2 Locomoção e posturas novas

| pose | hoje | alvo |
|---|---|---|
| correr | andar acelerado (cap 1,3) | ciclo próprio: tronco inclinado, braço dobrado 90°, fase aérea, quique maior |
| começar e parar de andar | salto de pose | 1 passo de antecipação e 1 de acomodação |
| virar no lugar | desliza girando | 2–3 passos curtos |
| agachar | escala Y 0,6 | joelho e quadril dobrados; andar agachado |
| pedalar (jogador e rede) | em pé com `animar(0)` | sentado no selim, pernas pela fase da roda |
| dirigir (IA, jogador visto de fora, rede) | IA congelada; o jogador some; a rede fica em LIVRE afundada | DIRIGINDO vivo: respira, volante acompanha o esterço, olha o retrovisor, buzina com a mão, xinga pela janela |
| entrar e sair do carro | some e aparece | abrir porta, sentar ou descer (3–4 passos) |
| sobressalto (pedestre x carro) | recua andando de costas | SOBRESSALTO + recuo com as mãos para a frente |
| queda e levantar | não existe | **feito**: boneco de pano + levantar de costas e de bruços (§6.4) |
| jogador sentado | só a câmera desce | ASSENTO de verdade (já existe para convidado) |
| ferido | a HUD pisca | tranco de corpo e mão no lugar |

### 6.3 Passagens entre posturas

`postura()` ganha a opção de passagem: guarda a pose atual e mistura até a nova em 3–5
passos, com o mesmo envelope das reações. Isso vale para sentar e levantar, andar e
parar, ócio e conversa. Sem passagem continua possível para corte de cena.

### 6.4 Física de corpo à GTA IV — **feito** (23/09/2026)

Pedido do usuário: ragdoll no atropelo, tropeço ao trombar, "física bem influenciada
no GTA IV". O IV usa o Euphoria (NaturalMotion): ragdoll *com vontade* — o corpo é
física, mas cada junta tem músculo puxando para uma pose que o comportamento escolhe
(catchFall, braceForImpact, rollUp, writhe, bodyBalance, stumble, armsWindmill). O que
entrou, em arquivos novos:

| peça | arquivo | o que faz |
|---|---|---|
| boneco de pano | `render/boneco_de_pano.gd` | 11 RigidBody3D (um por osso), Generic6DOF só angular + PinJoint3D; músculo por *soft keying* (o que o Jolt recomenda); comportamentos amortecer / encolher / pancada mole / contorcer / desacordado; teto de velocidade e reparo de encaixe; sons de baque e arrasto; procura lugar livre para levantar |
| levantar | `render/levantar_do_chao.gd` | de costas (cotovelo → sentado → agachado → de pé) e de bruços (flexão → de quatro → um joelho → de pé); mãos e pés por IK de dois ossos com alvo no chão, joelho que não entra no piso, ponta do pé que sobe, tronco que pousa pela pele |
| equilíbrio | `render/equilibrio.gd` | pêndulo invertido com ponto de captura: balança, dá 1–3 passos para o lado do empurrão errando para menos, cai quando nenhum passo alcança; o Corpo desenha inclinação, braços em moinho e passo em qualquer direção |
| atropelo | `world/atropelo.gd`, `world/lataria_para_corpo.gd` | carro que bate (inclusive IA congelada, pela posição); perfil de sedan cinemático só para as peças (capô, para-brisa, teto) — é o que faz rolar por cima do capô |
| pedestre | `world/pedestre.gd` | estados TROPECANDO e CAÍDO; esbarrão do jogador; carro devagar empurra, rápido derruba; depois: ENFRENTA, FOGE ou ATORDOADO pelo temperamento (`systems/falas_tombo.gd`, com fala e legenda); reflexo de susto por temperamento (bêbado não desvia); IA para diante de gente caída |
| jogador | `player/tombo_do_jogador.gd` | atropelado cai, perde vida, câmera de 3ª pessoa segue o corpo, levanta e devolve controle; vida zerada fica no chão e o `Desmaio` acorda no orelhão |

Réguas: `medir_boneco` (20, junta ≤ 3,5 cm, joelho do lado certo, levanta),
`medir_levantar` (102, nada entra no chão em três corpos, apoios tocam),
`medir_tropeco` (19), `checar_atropelo.tscn` (11), `bancada_tombo` e
`tombo_na_cidade.tscn` (fotos; `--jogador` para o jogador). Armadilhas do Godot Physics
anotadas na memória `junta-6dof-do-godot-physics`.

Segunda rodada (23/09/2026), tudo com régua:

| peça | arquivo | o que faz |
|---|---|---|
| cara no tombo | `render/boneco_de_pano.gd` (`_cara`), `render/rosto.gd` (DOR, DESACORDADO) | susto no primeiro instante, medo no ar, careta em cada pancada, olho fechado desacordado, careta levantando |
| onde doeu | `BonecoDePano.onde_doi()` | cada peça que perde velocidade encostada anota a pancada (a cabeça pesa 1,6); o para-choque marca a canela do lado do carro |
| levantar sentindo | `render/reacao_corpo.gd` (4 gestos de dor), `Corpo.mancando` | mão na cabeça, na lombar, na barriga ou no braço; perna batida manca 9–18 s (apoio curto, joelho duro, corpo afunda e pende) — pedestre, jogador, PM |
| gemido | `world/pedestre.gd` (`_gemer`), `systems/falas_tombo.gd` | no chão acordado, geme com voz e boca a cada 2–5 s |
| grito com boca | `Pedestre._falar_curto` | "Eh!", "Atropelaram o cara!" e o papo de rua saem pela `Fala` (antes a boca ficava parada) |
| grab | `Corpo.agarrar`, `Pedestre._procurar_onde_agarrar` | quem tropeça segura o ombro de quem está a 1,3 m (IK de dois ossos) e o outro leva um terço do empurrão |
| testemunha olha | `Corpo.olhar_para`, pitch e torção | a cabeça baixa para o corpo no chão; além do pescoço, o tronco gira até 0,6 rad |
| todo mundo cai | `world/tombo_de_corpo.gd` | PM da blitz, cliente do iWeed e convidado com o mesmo tombo e tropeço do pedestre |

Réguas: `checar_atropelo.tscn` 23/23 (gemido, cara de dor pelo LOD, testemunha olhando para
baixo, levanta sentindo, grab com a mão a 0 cm do ombro, PM derrubado e de pé),
`bancada_dor.gd` (cara, apagado, mancando, agarra), `bancada_gestos.gd --so=dor`.

## 7. Mapa de interações, de ponta a ponta

Cada linha diz o que muda para quem joga e de quais fundações depende (A rosto, B fala,
C olhar/jeito, D gestos, E poses).

| # | interação | arquivo | hoje | alvo | depende |
|---|---|---|---|---|---|
| 1 | conversar com pedestre | `pedestre.gd:697`, `conversa.gd` | busto gesticula; o corpo no mundo gesticula sem parar; boca parada | boca e voz na mesma sílaba; expressão de temperamento; escuta ativa; reação à opção | A B C D |
| 2 | conversar com convidado, loja, estufa | `convidado.gd:1279` | corpo parado (`falar(false)`), voz sem corpo | igual ao 1; o atendente usa gestos de venda | A B D |
| 3 | atendente do mercado | `atendente_loja.gd:93-148` | "Boa noite" e "Pois não?" | olha a porta, acena, fala com boca; passa o produto no leitor (fase já prevista) | B C D E |
| 4 | morador da casa | `npc.gd:191`, `dialogo.gd` | sem voz, sem retrato | vira com o `Olhar`, fala com voz e busto | A B C |
| 5 | pares conversando na rua | `pedestre.gd:565-587` | um murmura de cada vez | turnos com `Fala`, gestos de fala e escuta, riso contagiante (já existe no convidado) | B C D |
| 6 | pedestre x carro | `carro.gd:2960`, `pedestre.gd:652` | recua andando | SOBRESSALTO + MEDO + "Eh!" com voz; xinga o motorista depois | A B D E |
| 7 | esbarrar no pedestre | `pedestre.gd:372-465` | **feito** (§6.4): tropeça, braços em moinho, segura em quem está do lado, surpresa na cara, reclama pelo temperamento com estranhamento ou raiva | — | C D |
| 8 | atropelar | `pedestre.gd`, `tombo_do_jogador.gd`, `tombo_de_corpo.gd` | **feito** (§6.4): capô, chão, medo e dor na cara, gemido, levantar sentindo onde bateu, testemunha olhando o corpo; PM, cliente e convidado também caem | — | A C |
| 9 | falar com o motorista / tirá-lo do carro | `carro.gd:1113-1189` | conversa muda; ele some do banco | fala pelo `Corpo` do motorista; pose de sair ou ser puxado | B E |
| 10 | motorista na fila | `carro.gd:2928` | voz sem corpo | cabeça para fora (PESCOCO), braço, RAIVA | A B D E |
| 11 | blitz de passagem (IA x IA) | `blitz.gd:330-393` | CONTROLE, `falar` sem voz | PM na janela com mão no teto, motorista com MAOS_NO_CAPO na revista, portas | B D E |
| 12 | blitz contra o jogador | `blitz_no_caminho.gd:148-236` | legenda; conversa muda | "Encosta aí" com voz alta; busto com DESCONFIANCA; reação a colaborar, café ou correr | A B D |
| 13 | cliente iWeed | `cliente_iweed.gd:171-264` | legenda + `falar` por tempo fixo | ENTREGA/RECEBE com a mão, SIMPATIA ou RAIVA, olha o celular esperando | A B D E |
| 14 | Entregas da Super | `entregas_da_super.gd:275-590` | entregador só fala; quem voa sobe em LIVRE | ENTREGA; reação ao efeito (SURPRESA, MEDO no voo, pose de pânico) | A D E |
| 15 | Jota e Helmer no quarto | `super_quarto.gd:204-214` | legenda + voz sem gesto | cena com `Fala` completa, olhar entre os dois | A B C D |
| 16 | bar e casa da fumaça | `kit_bar.gd`, `convidado.gd:895-959` | murmúrio, riso, dança, fumar | os mesmos + olhar para a TV e para quem entra; bêbado com jeito próprio | C D |
| 17 | abertura (cinemática) | `abertura.gd` | plateia só olha; pensamentos em legenda | plateia reage (se benze, aponta, cochicha); o jogador pisca e olha | A C D |
| 18 | jogador em 3ª pessoa | `player.gd` | agachar e bicicleta falsos; some no carro | agachar, correr, pedalar, dirigir visível, ferido, sentar | E |
| 19 | multiplayer | `avatar_remoto.gd`, `protocolo_rede.gd:117-121` | flags F_FERIDO, F_CAIDO, F_FALANDO, F_CARONA reservadas e sem uso | as quatro flags ligadas; chat de texto → `Fala` no avatar (boca e voz); emotes pelos gestos de §5 | B D E |
| 20 | criação de personagem | `criacao.gd`, `retrato_estudio.gd` | reações e piscar | prévia de voz; expressão reagindo ao campo (sobrancelha ao trocar a barba, sorriso no "visto") | A B |
| 21 | retratos do inventário e da pausa | `prancha_inventario.gd:663`, `pausa_aba_personagem.gd` | cabeça segue o cursor | piscar + expressão pelo estado (chapado, ferido, cansado) | A |
| 22 | inimigo | `inimigo.gd` (`Figura`, sem rosto) | golpe só com som | fora deste plano: é outra linguagem de propósito. Um bote de ataque cabe na fundação E se você quiser | — |

## 7.1 Estado — fase 1 **feita** (23/09/2026)

| entrega | arquivo | régua |
|---|---|---|
| folha de rosto: 6 bocas, 3 sobrancelhas por lado, 5 olhos por lado, nas 34 caras, tiradas da própria cara (desenho com e sem o pedaço) | `tools/gerar_rosto.py` → `rosto_atlas.png` (256², e 4x no HD), `systems/rosto_meta.gd` | `bancada_rosto.gd` (11 expressões + 6 bocas em 4 pessoas) |
| `Rosto`: recortes colados na cara, boca atrás da barba, piscada da ficha em todo corpo de perto | `render/rosto.gd`, `Corpo.rosto` / `com_rosto` | idem |
| `Fala`: sílaba do português, voz da mesma vogal (`Voz.silaba`), viseme, texto no mesmo passo de 15 Hz, pausas de vírgula e ponto, `pular` | `systems/fala.gd` | `medir_fala.gd` 15/15 (boca aberta em 94% das sílabas a/o/u, fechada em 100% das pausas, 158 linhas reais) |
| `Conversa` pela `Fala`; PM, motorista e quem não tinha voz ganham uma presa neles | `ui/conversa.gd` | `conversa_na_cidade.tscn` (bocas distintas, texto e boca terminam juntos) |
| morador (`Dialogo`) com voz e gesto; convidado gesticula; susto sempre com voz; cliente iWeed pela `Fala` | `ui/dialogo.gd`, `world/npc.gd`, `world/convidado.gd`, `world/pedestre.gd`, `world/cliente_iweed.gd` | nível 1 |

Falta da fase 1: o grito do PM na blitz de passagem (`blitz_no_caminho.gd` tem trabalho de outra frente) e o entregador da Super.

### Fases 2, 3 e 4 — **feitas** (23/09/2026)

| entrega | arquivo | régua |
|---|---|---|
| expressão de base por temperamento; reação a cada opção da conversa (tabela por temperamento); microexpressão da pontuação (sobrancelha na pergunta e na exclamação, olhar que foge nas reticências); marcas `[raiva] [pausa] [olha:x] [rapido] [grita] [gesto:x]` que a tela nunca mostra; riso e chapado do corpo passam para a cara | `systems/expressao_da_conversa.gd`, `render/rosto.gd` (reagir, micro), `systems/fala.gd`, `ui/conversa.gd` | `medir_fala.gd` 23/23 |
| `Jeito` da ficha: curvatura, cabeça, balanço e assimetria de braço, mãos (livres, bolso, atrás, celular), quique, largura de passo, bamboleio do gordo, cambaleio do bêbado, gesto, 3 ócios, intervalo, fase, contato de olho | `render/jeito.gd`, `Corpo.jeito`; ligado em pedestre, morador, convidado e cliente | `medir_jeito.gd` 12/12 (50 fichas → 50 jeitos) |
| 22 gestos novos com mão no alvo resolvida: 11 ócios, 8 de fala, 3 de reação, com gesto secundário (aceno, punho, esfregar, coçar) | `render/reacao_corpo.gd` | `medir_reacao.gd` 49/49 (≤ 4,5 cm), `bancada_gestos.gd` |
| ócio sozinho parado, em rodízio dos 3 da pessoa; bocejo abre a boca e fecha o olho | `Corpo._ocio` | `medir_jeito.gd` |
| gesto da fala escolhido pela frase e pelo temperamento ("não" nega, "você" do mandão aponta, pergunta dá de ombros); escuta do corpo no mundo pelo temperamento | `systems/gesto_da_fala.gd`, `ui/conversa.gd` | `medir_jeito.gd` |
| olhar: olho primeiro, cabeça um passo a cada dois; assustado e vigarista desviam | `Corpo._atualizar_olhar` | `medir_jeito.gd` |

Pitch do olhar e tronco além do pescoço: **feitos** na segunda rodada (`Corpo.olhar_lateral(giro, pitch)`, `olhar_para`).

**Sinal da cabeça consertado.** Todo o arquivo, o `Jeito` e o `ReacaoCorpo` escrevem "inclina
positivo olha para baixo", mas o osso gira ao contrário: o celular olhava para o céu e o
sonhador para o chão. `Corpo._girar_cabeca` troca o sinal num lugar só.

**LOD.** Medido em par na RX 9070 XT: 30 corpos animando custam 0,25 ms por quadro a mais que
parados (5 µs por `animar`); os 14 da multidão, ~0,12 ms. Um LOD de pose não paga o salto
visível, e fica fora. O que tinha custo e faltava era o **rosto**: ninguém no mundo tinha
cara que mexe. Agora `Corpo._lod_do_rosto` monta o rosto a 9 m da câmera e solta a 13 m.

### Fases 5, 6 e 7 — **feitas em parte** (23/09/2026)

| entrega | arquivo | régua |
|---|---|---|
| corrida (tronco inclinado, cotovelo a 90°, passada longa, 15 poses por ciclo) | `Corpo._pose_correndo` | `medir_corpo_inteiro.gd` 7/7 |
| agachar de verdade (IK com pé no chão, na ponta do pé), no jogador e no avatar da rede, no lugar da escala | `Corpo._agachar`, `player.gd`, `avatar_remoto.gd` | idem |
| pedalar: pé no pedal pela pedivela da bicicleta, mão no guidão (jogador e rede) | `Corpo._pose_pedalando`, `player.gd`, `avatar_remoto.gd` | idem (erro 0 cm) |
| passagem de 0,25 s entre posturas e entre parar, andar e correr | `Corpo._comecar_mistura` | idem |
| motorista da IA vivo: se anima sozinho, corrige o volante, confere retrovisor, mão no câmbio | `Corpo._process`, `_pose_dirigindo` | `bancada_gestos.gd` |
| rua reage: susto protege o rosto e depois xinga (quem enfrenta); esbarrão reclama com o corpo; testemunhas do atropelo param e reagem | `world/pedestre.gd` | `checar_atropelo.tscn` 12/12 |
| rede: F_CAIDO (o amigo atropelado cai aqui também) | `net/sessao.gd`, `net/avatar_remoto.gd` | `run_tests_rede` 136, `run_tests_mundo` 309 |

Segunda rodada: **feitos** o motorista reclamando (buzina abre os braços, xingo sacode o
punho com raiva e boca, `carro.gd`); a revista da blitz (PM explica na janela desconfiado,
"mão na cabeça" com medo e o PM apontando, `blitz.gd`, gesto `REACAO_MAO_NA_CABECA`); o chat
saindo da boca do amigo (`AvatarRemoto.falar`, `checar_amigo_fala.tscn`) e F_FERIDO (vida
≤ 30%: o amigo e a figura do jogador mancam). O atendente e o convidado falam pela `Fala`.

A bancada `bancada_motorista_vidro.tscn` mostrou que o vidro já é transparente e que a
passagem de postura deixava a cabeça do motorista furando o teto (a mistura partia do de pé
de um corpo recém-montado); consertado em `Corpo._ja_posou`.

Fica para depois: ossos PESCOCO, MAO e PE (mexem na pele e no atlas de todos, e a 480x270
o punho não se lê); entrar e sair do carro (a porta é risco pintado na lataria, não peça
que abre — é da frente do carro); F_FALANDO fica sem uso (o chat já leva a fala).

## 8. Ordem de implementação

Cada fase fecha com a bateria atual verde (`checar_criacao`, `medir_reacao`,
`medir_sentado`, `verificar_npc.py`) mais as réguas novas.

| fase | entrega | régua |
|---|---|---|
| **1. A boca fala** | folha de rosto e `RostoMeta` no gerador; `Rosto` com visemes e piscada; `Fala` com um relógio só; `Conversa`, `Dialogo` e `Cinema.fala` escutando `silaba_dita`; os 8 falantes mudos da §3.2 | em 100 linhas: boca ABERTA ou REDONDA em ≥ 60% das sílabas com vogal a/o/u; boca FECHADA em 100% das pausas e fins; voz, boca e texto no mesmo passo de 15 Hz; `pular()` cala em ≤ 1 passo; nenhum falante sem `Fala` (varredura dos pontos de chamada) |
| **2. A cara reage** | expressões; marcas `[...]` no texto; temperamento → expressão de base; microexpressões; escuta ativa; tabela opção → reação | cada uma das 11 expressões fotografada no busto 80×104 e em 4K; teste: toda opção de `falas_npc.gd` tem reação; nenhuma marca aparece na UI |
| **3. Cada um é um** | `Jeito` na ficha; `Olhar` com olho, pitch e tronco; os 12 ócios; o corpo de cada temperamento | 50 fichas → ≥ 40 jeitos distintos; mesma ficha → mesmo jeito em duas montagens e na rede; o olho chega ao alvo antes da cabeça |
| **4. Gestos** | biblioteca de §5.1 no `ReacaoCorpo`, resolvida pelo `--resolver`; gestos de fala amarrados à pontuação e às marcas | alvo de mão ≤ 4,5 cm para todo gesto com alvo; nenhum braço dentro do tronco no pico |
| **5. Corpo inteiro** | ossos novos; correr, agachar, pedalar, dirigir vivo, entrar e sair do carro, passagens | pé abaixo do piso = 0 em toda pose; 15 assinaturas por ciclo de corrida; motorista IA muda de pose em 10 s; teto de 1500 e 560 triângulos mantido |
| **6. A rua reage** | sobressalto, esbarrão, queda e levantar, xingar da janela, revista da blitz | cada situação montada em bancada (carro a 8 m/s passando a 2 m etc.), com tempo de reação e pose conferidos |
| **7. Rede** | F_FERIDO, F_CAIDO, F_FALANDO, F_CARONA; chat → `Fala`; emotes | dois clientes: fala e emote aparecem no outro em ≤ 1 pacote |

Custo: um **LOD de animação** entra na fase 3, junto com o que ele protege. Até 8 m
roda rosto, gesto e olhar; de 8 a 25 m, corpo e cabeça; acima de 25 m, ciclo a meio
passo; fora da tela, só o relógio anda. A régua é o custo de `animar` da multidão de 14,
medido em par (antes e depois) na mesma GPU.

## 9. Decisões que são suas

1. **Corpo liso no MODERNO?** Hoje o corpo anda a 15 poses por ciclo nos dois estilos.
   A proposta mantém os passos (é a vibe, e o rosto a 15 Hz combina), mas o MODERNO
   poderia interpolar só o corpo.
2. ~~Queda por atropelamento~~ — **decidido**: ragdoll à GTA IV, sem sangue (§6.4).
3. **Jogador visível ao volante** visto de fora: sim, com DIRIGINDO. Hoje ele some.

## 10. Nota de convivência

`conversa.gd`, `player.gd`, `avatar_remoto.gd` e `criacao.gd` estão modificados no
working tree, parte por outras frentes. As fases 1 e 5 mexem neles: a ligação nesses
arquivos deve ser mínima (como no PLANO_HUD_AAA), e o grosso fica em arquivos novos
(`rosto.gd`, `fala.gd`, `olhar.gd`, `rosto_meta.gd`, `rosto_atlas.png`).

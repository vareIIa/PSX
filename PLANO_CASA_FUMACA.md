# PLANO CASA DA FUMAÇA — AAA

> Mapa medido do lugar + plano de execução para levar a casa da fumaça (sala,
> fachada, gente, estufa e o plano 05 da abertura) ao mesmo rigor do resto do
> projeto.
> Versão 1.0 — 14/09/2026 — branch `playable`

---

## 0. O que "AAA" significa nesta frente

Igual ao `PLANO_UI_AAA.md`: não é mais efeito, é rigor de estúdio grande numa
apresentação deliberadamente limitada. Traduzido para este cômodo:

| AAA aqui significa | AAA aqui não significa |
|---|---|
| Nenhuma pessoa da sala tem osso atravessando o chão, e existe medida que prova | Mais gente na sala |
| O objeto que dá nome ao lugar é reconhecível em 480x270 | Textura maior |
| A fachada diz o que tem atrás dela antes de o jogador abrir a porta | Placa escrita "casa da fumaça" |
| O que o jogador faz lá dentro é mais do que atravessar a sala | Mais NPC para conversar |
| Cada correção sai de uma captura ou de um número, não de leitura de código | Refazer o que funciona |

A linha que mais pesa: **o cômodo gasta 2.750 triângulos de um teto de 25.000.**
Não falta orçamento. Falta conteúdo e falta conserto.

---

## 1. Onde a casa vive no código

| Arquivo | O que faz |
|---|---|
| [casa_fumaca_builder.gd](game/src/world/casa_fumaca_builder.gd) | 697 linhas. A planta inteira: casca, móveis, TV, fumaça, luz e as 8 pessoas |
| [estufa_builder.gd](game/src/world/estufa_builder.gd) | 477 linhas. O cômodo atrás da porta dos fundos |
| [convidado.gd](game/src/world/convidado.gd) | 783 linhas. Quem está na sala: circular, fumar, conversar, papel fixo |
| [corpo.gd](game/src/render/corpo.gd) | 967 linhas. O corpo de 11 ossos e as posturas `SENTADO` / `CONTROLE` |
| [televisao.gd](game/src/render/televisao.gd) | A imagem da partida, a luz e o chiado |
| [interiores.gd](game/src/systems/interiores.gd) | Monta a planta na thread, cria os props, empilha cômodos (`atravessar`) |
| [chunk_builder.gd:227](game/src/world/chunk_builder.gd#L227) | Sorteia qual porta da cidade é casa da fumaça (1 em 5 casas) |
| [porta.gd](game/src/world/porta.gd) | A porta da rua. **Genérica** — não sabe que esta leva à casa da fumaça |
| [missoes.gd:83](game/src/systems/missoes.gd#L83) | A primeira missão do jogo: marcar no GPS e chegar |
| [abertura.gd:242](game/src/levels/abertura.gd#L242) | O plano 05 da cena de introdução |
| [gerar_casa.py](tools/gerar_casa.py) | O atlas 256x256 de onde sai tudo: TV, console, controle, cartaz, planta |
| [fog_fumaca.tres](game/resources/fog/fog_fumaca.tres) | O preset de névoa/ambiente do cômodo |

Endereços reais no mundo gerado (`tests/onde_fumaca.gd`): 22 casas num raio de
24 chunks. A mais perto da origem fica no chunk `(3,-6)`, mundo `112.9, -171.8`.

---

## 2. Diagnóstico medido

Tudo abaixo foi medido com ferramenta ou lido em captura. Onde há número, o
número saiu de `tests/medir_sentado.gd` ou `tests/medir_fumaca.gd`, criados
nesta sessão.

Capturas de referência em `captures/fumaca_aaa/` e
`game/captures/abertura/05_casa_fumaca.png`.

### 2.1 O sentado no chão está fisicamente quebrado — `corpo.gd:799`

`_pose_sentado` gira as coxas em **-1,42 rad**. O comentário três linhas acima
diz "girar as coxas para a **frente**", mas na convenção do próprio arquivo
(`_pose_andando:741`, coxa positiva = perna à frente) o sinal negativo joga a
coxa **para trás**. Medido:

```
--- SENTADO ---  altura 1.67  236 triangulos  11 ossos
  quadril       x  0.000   y  0.369   z  0.000
  coxa_d        x  0.094   y  0.369   z  0.000
  canela_d      x -0.072   y  0.373   z  0.394     <- joelho 39 cm ATRAS do corpo
  ponta do pe   x  0.001   y -0.030   z  0.223     <- 3 cm ABAIXO do piso
  punho D       x  0.090   y  0.378   z  0.141     <- mao ATRAS do tronco
```

Três defeitos num só:

1. **O joelho aponta para trás.** `z = +0.394` e a frente do corpo é `-Z`.
2. **O pé atravessa o chão** em 3 cm.
3. **O quadril flutua a 37 cm.** Sentado de pernas cruzadas o quadril fica a
   18–22 cm. Ele não está sentado: está agachado no ar.
4. **O joelho direito cruzou para o lado esquerdo** (`x = -0.072` contra os
   `+0.094` da junta do quadril): as duas pernas se atravessam.

Na captura da abertura é exatamente isso que se vê: um tronco flutuando com
duas pernas penduradas entrando no piso.

### 2.2 O controle está nas costas, não nas mãos — `corpo.gd:838`

`_bracos_no_controle` gira os dois braços em **-0,62 rad** (para trás) e os
antebraços em +0,86, o que não chega a compensar. Resultado medido, de pé:

```
--- CONTROLE ---
  punho D       x  0.093   y  0.872   z  0.145     <- 14 cm atras do tronco
  punho E       x -0.087   y  0.874   z  0.144
  separacao entre os dois punhos: 0.180 m
```

Quem segura um controle põe as mãos **à frente**, na altura do umbigo, a uns
20 cm do tronco (`z ≈ -0.20`). Aqui elas estão atrás dele.

E há um segundo problema, independente do sinal: **o controle é um objeto só,
pendurado no punho direito** (`convidado.gd:268`). Dois quads cruzados de
20 x 11,5 cm com a célula `(4,1)` do atlas. Na captura ele lê como uma carteira
no quadril. Um controle é segurado **pelas duas mãos**.

### 2.3 O "PlayStation" não parece um PS2 — `casa_fumaca_builder.gd:253`

```gdscript
AtlasKit.caixa(sup, MAT, CONSOLE + Vector3(0.0, 0.04, 0.0),
    Vector3(0.30, 0.08, 0.20), C_CONSOLE)
```

Uma caixa só, 30 x 8 x 20 cm — a medida do PS2 fat deitado está certa
(301 x 78 x 182 mm). O problema é que **as seis faces usam a mesma célula**, um
preto fosco com uma listra horizontal e um circulozinho
(`gerar_casa.py:120`). Então a "listra do leitor" aparece no topo, nos lados e
no fundo, e a frente não tem nada do que faz um PS2 ser um PS2:

- a faixa vertical do logo na lateral esquerda;
- a bandeja de disco com a costura horizontal **só na frente**;
- os dois botões redondos (liga / eject) e o **LED azul**;
- as duas portas de controle e os dois slots de memory card;
- a opção de ficar **em pé na base azul**, que é como metade do Brasil usava.

Na captura ele é um losango escuro no chão, indistinguível de uma caixa de
pizza fechada.

### 2.4 A TV se ilumina a si mesma e vira um retângulo claro — `televisao.gd:110`

A `OmniLight3D` da TV fica a **0,5 m à frente do tubo**, com energia 2,4 e
alcance 6,6. A moldura preta (`C_MOLDURA`, RGB 34,34,36) está a 2,5 cm atrás da
imagem, dentro desse facho. Pixels amostrados na captura da entrada:

```
moldura renderizada:  (95, 92, 78)     <- deveria ser quase preta
parede ao lado:       (70, 50, 30)
```

Ou seja: **o "preto" do gabinete sai mais claro que a parede.** O cabeçalho do
próprio `casa_fumaca_builder.gd:63` já avisa contra isso ("a partida não
aparecia: o que se via era um retângulo claro no fundo da sala") — o defeito
voltou por outro caminho, pela luz em vez da ordem em profundidade.

E a luz azul da TV **não pinta ninguém**. Os dois jogadores estão a 2 m dela e
saem marrons na captura, do mesmo tom da parede.

### 2.5 A névoa marrom apaga a sala inteira — `fog_fumaca.tres`

```
fog_begin = 1.2
fog_end   = 11.5
fog_color = (0.32, 0.235, 0.16)   marrom
ambient_energy = 0.48  em marrom
```

A sala tem **9,8 x 8,2 m — diagonal de 12,8 m.** Com `fog_begin` em 1,2 m,
tudo além de um braço esticado já começa a receber marrom, e o canto oposto
está **100% coberto**. É a causa raiz do "tudo é da mesma cor" nas três
capturas: parede, piso, pessoa, móvel e teto convergem para o mesmo
`(0.32, 0.235, 0.16)`.

O preset foi desenhado quando a sala tinha 7,2 x 6,4 m. A sala cresceu; a névoa
não acompanhou.

### 2.6 A fumaça do teto come metade da tela — `casa_fumaca_builder.gd:527`

Quatro placas horizontais em 2,44 / 2,24 / 2,00 / **1,72 m**. O olho do jogador
fica a ~1,62 m. E o material do teto tem `fade_de_raspao = 0.0`
(`mat_fumaca_teto.tres`), que é o único parâmetro que atenuaria uma placa vista
de perfil.

Resultado na captura `03_entrada.png`: **o topo 55% do quadro é uma nuvem
marrom sólida.** Quem entra na casa não vê uma sala com fumaça no teto — vê uma
sala cuja metade de cima foi apagada.

O `fade_de_raspao = 0.0` é decisão consciente (o comentário em
`psx_fumaca.gdshader:43` explica por quê), então o conserto não é religá-lo: é
subir a placa mais baixa para acima de 1,95 m e baixar a densidade das duas de
cima.

### 2.7 A fachada não diz absolutamente nada — `chunk_builder.gd:204`

`_porta_do_chunk` devolve a **mesma porta** para casa comum e casa da fumaça:
mesma folha, mesma maçaneta, mesma verga. A única diferença é o campo
`interior`, que ninguém vê.

E o rótulo de interação cai no `_` do `match` em `porta.gd:157`: casa comum diz
"Entrar na casa", mercado diz "Entrar na loja", **casa da fumaça diz "Entrar"**.

Captura `04_fachada.png`, tirada no endereço real `112.9, -171.8`: uma casa
branca limpa, de classe média, com uma porta escura e uma janela acesa —
idêntica às duas vizinhas no mesmo quadro. Dentro: oito pessoas, som alto, luz
magenta e fumaça até o teto. **Nada vaza.**

Sem: som atravessando a parede, luz colorida na janela, fumaça saindo pela
fresta, gente fumando na calçada, tag, portão, bicicleta encostada.

### 2.8 A missão termina na porta — `missoes.gd:180`

```gdscript
func _ao_entrar() -> void:
	if Interiores.tipo_atual() != &"casa_fumaca":
		return
	avancar()   # ultima etapa -> missao concluida
```

A primeira missão do jogo acaba **no instante em que o jogador cruza a porta.**
O cômodo mais trabalhado do jogo é o cenário de um "OBJETIVO CUMPRIDO" e nada
mais. Não há nada a fazer lá dentro além de conversar e sair.

### 2.9 A sala inteira conversa sobre névoa, bairro e você — `personalidade.gd:29`

```gdscript
const ASSUNTOS_COMUNS: Array[StringName] = [&"nevoa", &"bairro", &"voce"]
```

Os oito convidados usam **os mesmos três assuntos** de qualquer pedestre da
rua. Ninguém menciona a festa, a partida na TV, o que está rolando, a estufa
atrás da porta, quem é o dono da casa, nem por que a cidade está vazia.

O `Convidado` já tem o gancho certo (`abordar:751`: "quem está jogando NÃO
larga o controle para conversar") — a fala é que não existe.

### 2.10 O orçamento está 89% vazio — medido

```
--- casa_fumaca (semente 77551) ---
  triangulos totais: 862
  superficies (draw calls da malha): 8
    piso 50 | teto 50 | reboco 80 | tabua 38 | casa 508
    casa_recorte 96 | fumaca_teto 8 | fumaca_baseado 32
  caixas de colisao: 16
  props: 15  (televisao 1, som_ambiente 1, porta_interna 1, lampada 4, convidado 8)

--- estufa ---
  triangulos totais: 1482       <- o comodo dos FUNDOS gasta 72% mais que a sala
```

Corpo por pessoa: **236 triângulos**. Cômodo completo com as 8 pessoas:
`862 + 8 x 236 = 2.750 triângulos`.

Teto do `docs/ART-BIBLE.md` seção 10: **6.000 por chunk, 25.000 visíveis,
120 draw calls.** A casa usa 11% do orçamento visível e ~20 draw calls.

Atlas `casa_atlas.png` (256x256, grade 8x8 de células de 32 px):
**20 das 64 células estão livres** — linha 0 colunas 4-7, linha 2 colunas 4-7,
linha 4 colunas 4-7, e a linha 7 inteira.

Não há nenhuma restrição técnica impedindo esta casa de ser três vezes maior.

### 2.11 Outros achados menores

- **Zero janelas.** `_casca` abre um vão só, o da porta. A rua não existe de
  dentro: nenhuma luz de poste, nenhum farol passando, nenhum som.
- **Os cabos de controle terminam no chão, não na mão.** `_console_e_cabos:265`
  manda o cabo para `(4.44, 0.34, 5.42)` — o centro do corpo do sentado. A mão
  medida está em `(4.53, 0.378, 5.56)`.
- **Não há luz de teto** (decisão correta e bem documentada), mas também não há
  **nenhuma fonte fria além da lâmpada magenta do som** — a TV, que deveria ser
  a segunda, é engolida pelo `ambient_color` marrom.
- **Cinco cinzeiros, quatro colunas de fumaça, e nenhuma delas na mão de
  ninguém que esteja no quadro da abertura.**
- **A poltrona, a estante e a bancada não têm nada em cima que interaja.**
- **A estufa tem 1 pessoa** para 8 canteiros e um cômodo maior que a sala.

---

## 3. Plano de execução

Seis fases. As três primeiras são conserto e não pedem decisão de escopo; as
três últimas são expansão e pedem.

### Fase 0 — Consertos medidos (nenhuma arte nova)

Tudo aqui já tem número no diagnóstico e prova por medida.

| # | O que | Onde | Prova |
|---|---|---|---|
| 0.1 | Coxa para a frente, canela dobrada por baixo, quadril a 0,20 m, pé em `y=0` | `corpo.gd:799` | `medir_sentado.gd`: `canela_d.z < 0`, `pe.y >= 0` |
| 0.2 | Pernas sem cruzar a linha de centro (sentado e de pé) | `corpo.gd:799,819` | `medir_sentado.gd`: sinal de `x` do pé igual ao do quadril |
| 0.3 | Braços para a frente: punhos em `z ≈ -0.20`, altura do umbigo | `corpo.gd:838` | `medir_sentado.gd`: `punho.z < -0.15` |
| 0.4 | Controle segurado pelas DUAS mãos: peça única entre os punhos | `convidado.gd:266` | captura de perto |
| 0.4b | Controle só em quem está jogando — hoje todo `papel != LIVRE` ganha um, inclusive os dois clientes do bar | `convidado.gd:267` | captura do bar |
| 0.5 | Luz da TV a 1,1 m à frente e moldura fora do facho | `televisao.gd:110` | pixel da moldura abaixo do da parede |
| 0.6 | `fog_begin` 1,2 -> 4,5 e `fog_end` 11,5 -> 22 | `fog_fumaca.tres` | captura da entrada: parede do fundo separável do piso |
| 0.7 | Placa de fumaça mais baixa 1,72 -> 2,00; densidade das de cima 0,78 -> 0,55 | `casa_fumaca_builder.gd:527` | captura da entrada: fumaça ocupa < 25% do quadro |
| 0.8 | Cabos terminando no punho medido, não no centro do corpo | `casa_fumaca_builder.gd:265` | captura de perto |

**Nota de risco — o bar usa a mesma pose.** `corpo.gd` é compartilhado com
Pedestre, NPC e jogador, mas `_pose_sentado` / `_pose_controle` /
`_bracos_no_controle` só têm dois clientes: a casa da fumaça e
[bar_builder.gd:335](game/src/world/bar_builder.gd#L335), que põe dois clientes
`Papel.SENTADO` na mesa da TV. Duas consequências:

- **O conserto melhora o bar de graça.** O comentário lá diz: *"SENTADO é no
  chão — as cadeiras ficam ao lado, não embaixo, para o colisor não nascer
  dentro do assento."* Ou seja: a pose quebrada já foi **contornada** pondo as
  cadeiras ao lado das pessoas. Consertada a pose, as cadeiras voltam para
  debaixo de quem senta.
- **Bug de tabela achado de passagem:** `convidado.gd:267` pendura o controle
  em **todo** `papel != LIVRE`. Os dois clientes sentados do bar estão
  assistindo futebol **com um controle de videogame na mão**. O `_pendurar`
  precisa depender do lugar, não do papel.

### Fase 1 — O PS2 e o canto do videogame

O objeto que dá nome à década. Custo estimado: 4 células novas do atlas
(sobram 20) e ~120 triângulos.

1. **Console em 3 células**: frente (bandeja + botões + LED + portas), lateral
   (faixa vertical do logo), topo/traseira (ranhuras). `AtlasKit.caixa` já
   aceita célula diferente por face — é como a TV faz.
2. **Em pé na base**, não deitado: é a silhueta que identifica o aparelho, e
   custa a mesma caixa girada.
3. **LED azul**: uma `OmniLight3D` minúscula (alcance 0,35, energia 0,4). É a
   única fonte fria baixa da sala e marca onde o console está no escuro.
4. **Controle DualShock 2**: célula nova, preto com os dois grips e os dois
   analógicos. A peça atual é cinza com quatro botões coloridos e um d-pad —
   lê como controle de 16 bits.
5. **Terceiro controle largado no chão** perto do rack, cabo enrolado.
6. **Caixa de jogo aberta** em cima do rack e três CD-R sem capa espalhados
   (as células `C_CD` e `C_PAPELAO` já existem).
7. **Memory card** solto no tampo do rack.

### Fase 2 — A fachada e a calçada

O que o jogador vê ANTES de abrir a porta. Esta é a fase que transforma um
endereço num lugar.

1. **Rótulo próprio** no `match` de `porta.gd:157` — algo que não entregue o
   nome, do tipo "Bater na porta".
2. **Som vazando**: um `AudioStreamPlayer3D` com passa-baixa na fachada,
   tocando a mesma `funk_batida` do canto do som, alcance ~14 m. É o primeiro
   sinal e chega antes da imagem.
3. **Janela acesa em magenta**, não em amarelo: a lâmpada do som lida de fora.
4. **Fumaça saindo pela fresta** da porta — uma coluna curta, reusando
   `_coluna_de_fumaca`.
5. **Dois a três NPCs na calçada**, fumando, encostados na parede. A postura
   `ENCOSTADO` **já existe** em `corpo.gd:905` (é a do plano 06 da abertura,
   com cigarro numa mão e celular na outra) e nunca foi usada fora dela.
6. **Bicicleta encostada** — `gerar_bicicleta.py` já existe.
7. **Tag na parede** e um par de tênis pendurado no fio.
8. **Degrau/soleira** e uma grade baixa: separa a casa das vizinhas na
   silhueta, que é o que se lê a 20 m de névoa.

**Escopo decidido (14/09/2026): toda casa da fumaça da cidade.** A variante de
fachada nasce no `chunk_builder`, ao lado de onde a planta já é sorteada
(`chunk_builder.gd:227`), e vale para as 22 casas do raio de 24 chunks. O
jogador aprende a reconhecer o lugar de longe, que é o ponto.

### Fase 3 — A sala em si

Depois que a névoa e a fumaça pararem de achatar tudo (Fase 0), a sala passa a
ter onde mostrar material.

1. **Separação de valor**: piso escuro, parede média, teto quase preto. Hoje os
   três estão dentro de 15 pontos de luminância um do outro.
2. **A TV pintando as pessoas de azul** — depois de 0.5, checar se a energia
   2,4 alcança os dois jogadores a 2 m. Provavelmente sobe para ~3,2.
3. **Uma janela na parede oeste**, com cortina, deixando entrar o sódio laranja
   da rua. Dá um segundo plano de profundidade e liga o cômodo à cidade.
4. **Cartazes legíveis**: os quatro atuais usam a mesma célula `C_POSTER`.
   Quatro células novas (sobram 20) — banda, time, filme, mulher de revista.
5. **Ventilador de teto parado** ou de pé ligado, mexendo a fumaça.
6. **Mais duas colunas de fumaça** nas mãos de quem está no quadro da abertura.
7. **Marcas de uso**: mancha no teto sobre o cinzeiro, garrafa com anel de
   condensação na mesa, resto de fita crepe na parede onde havia cartaz.

### Fase 4 — Interações

Hoje: conversar e sair. Proposta, em ordem de custo:

1. **Sentar no sofá / na poltrona** — muda a câmera e o ângulo da TV. A postura
   `SENTADO` consertada na Fase 0 já serve.
2. **Pegar o controle** e entrar na partida: o jogador vira o terceiro
   jogador, a tela da TV troca de célula, ganha um minijogo abstrato ou só o
   plano com a mão no controle.
3. **Aceitar o baseado** que alguém oferece — muda o pós-processamento por
   alguns minutos (o projeto já tem `Settings.set_post` com grain, scanline,
   vignette e chromatic).
4. **Pegar uma cerveja** na bancada — `Item` e `Inventario` já existem, e há
   11 itens no catálogo.
5. **Ligar/desligar o som** — o `som_ambiente` já é um nó no espaço.
6. **A missão continuar dentro da casa**: falar com o dono, ser mandado até a
   estufa, voltar. Hoje ela acaba na soleira (2.8).
7. **Assuntos próprios de casa**: 4–6 entradas novas em `Personalidade`, só
   para quem está neste interior.
8. **Ponto de save** — o prop `save` já existe e a casa é o lugar óbvio para o
   primeiro do jogo.

### Fase 5 — Expansão: mais cômodos e mais andar

`Interiores` **já empilha cômodos** (`atravessar`, usado hoje para a estufa), e
uma planta nova custa **uma linha** em `_planta` mais um arquivo de builder.
Não há nada a construir na infraestrutura.

Candidatos, em ordem do que mais rende:

| Cômodo | Por que existe | Custo |
|---|---|---|
| **Corredor + cozinha** | A sala hoje é a casa inteira. Uma cozinha suja com gente encostada na pia é o contraste que a sala precisa | 1 builder, ~600 tri |
| **Banheiro** | O lugar mais barato de fazer memorável num jogo PSX: espelho, luz fluorescente falhando, torneira pingando | 1 builder, ~350 tri |
| **Escada + quarto de cima** | Onde a festa não chega: silêncio, uma pessoa dormindo, o som atravessando o chão. É o contraste mais forte disponível | 2 builders, ~900 tri |
| **Laje / quintal** | Vista da cidade com névoa, de cima. Liga o interior à escala do mundo | 1 builder, ~500 tri |

Mesmo com os quatro, o total fica em ~5.100 triângulos — dentro do teto de um
único chunk.

**Escopo decidido (14/09/2026): os quatro entram.** A casa deixa de ser um
cômodo e vira uma casa. Ordem sugerida pelo contraste que cada um cria contra a
sala: corredor+cozinha, escada+quarto, banheiro, laje.

### Fase 6 — O plano 05 da abertura, reencenado

Depois das fases 0–3 a cena melhora sozinha, mas o enquadramento continua
errado. Da captura `05_casa_fumaca.png`:

- O **terço direito do quadro** é uma massa escura de móvel sem leitura.
- A TV ocupa **4% da largura** e a partida é ilegível.
- Os dois jogadores estão **na borda** do quadro, e são o assunto do plano.
- O centro-esquerda é **vazio marrom**.

Proposta: recompor `CASA_DE` / `CASA_ATE` / `CASA_OLHAR_*`
(`abertura.gd:242`) para uma travelling lateral mais baixa e mais perto, com os
dois jogadores em primeiro plano e a TV ao fundo, e mudar a legenda "Eu sei lá
que tipo de gente mora nessa cidade..." para cair quando o riso cair.

---

## 3.5. Fase 0 + Fase 1 — FEITAS em 14/09/2026

Todos os oito critérios de `tests/medir_sentado.gd` passam. Antes: 8 falhas.

| Item | Arquivo | Medida depois |
|---|---|---|
| Pose sentada resolvida a partir das posições | `corpo.gd:_pose_sentado` | quadril 0,233 m; joelho `z=-0,326` (à frente); pé `y=+0,043` |
| Perna de pé parou de cruzar | `corpo.gd:_pose_controle` | pé D em `x=+0,042`, do lado dele |
| Braços para a frente | `corpo.gd:_bracos_no_controle` | punhos em `z=-0,19`, 27 cm entre eles |
| Controle entre as DUAS mãos, 3 caixas | `convidado.gd:_montar_controle` | — |
| Controle só em quem joga (`com_controle`) | `convidado.gd`, `interiores.gd` | o bar perdeu os DualShock de brinde |
| PS2 em pé, 3 células de face, base e LED | `casa_fumaca_builder.gd:_console_e_cabos` | 4 células novas no atlas |
| DualShock preto no lugar do controle cinza | `gerar_casa.py:console` | célula `(7,2)` |
| Luz da TV virou cone e não esfera | `televisao.gd:_montar_luz` | moldura sai do facho; `ENERGIA` única |
| Névoa 1,2→4,5 e 11,5→22 | `fog_fumaca.tres` | a sala de 12,8 m de diagonal voltou a ter profundidade |
| Fumaça mais baixa 1,72→2,02 | `casa_fumaca_builder.gd:CAMADAS_FUMACA` | saiu da altura do olho (1,62) |
| Cabos terminando no controle | `_console_e_cabos` | `z` 5,42→5,62 e 5,10→5,28 |
| Terceiro controle, caixa de jogo, memory card | `_console_e_cabos` | — |
| `olhar_para` medindo o pitch do OLHO | `player.gd:olhar_para` | a captura parou de fotografar a laje |
| `--olhar-jogadores` acima do piso | `cidade.gd` | `y` -0,62 → 0,0 |

Orçamento depois: **940 triângulos** na sala (era 862), 8 superfícies, 5 lâmpadas.
Com as 8 pessoas: **2.828 de 25.000**.

Capturas do antes e depois em `captures/fumaca_aaa/`.

---

## 3.6. Fase 2 — FEITA em 14/09/2026

Vale para **toda casa da fumaça da cidade** — as 22 do raio de 24 chunks — e não
só para a da missão. Tudo mora em [kit_fumaca.gd](game/src/world/kit_fumaca.gd),
novo; `chunk_builder.gd` só ganhou o `elif` que chama.

A ordem das peças no arquivo é a ordem da **distância em que cada uma começa a
valer**, porque o que faz um lugar ser reconhecível de longe é silhueta e cor,
não detalhe:

| Distância | O que chega |
|---|---|
| antes da imagem | a batida atravessando a parede, filtrada a 820 Hz |
| ~20 m | o telheiro de duas águas e a grade baixa: a silhueta |
| ~18 m | a bandeira magenta acima da porta e a nesga sob ela |
| ~12 m | os dois fumando na calçada, com as duas brasas |
| ~8 m | a fumaça saindo pela fresta |
| ~5 m | o engradado de cerveja, a pichação, o degrau |

Mais: o rótulo da porta virou **"Bater na porta"** (era o `_` do match, que dizia
só "Entrar"), e não diz o nome do lugar — a rua inteira já está dizendo.

**Custo medido** (`tests/medir_chunk_fumaca.gd`, novo):

```
chunk (3,-6) com a casa da fumaca:  3.706 tri de 6.000   20 superficies   2 Omni de 4
chunk (3,-5) vizinho, sem ela:      4.386 tri de 6.000   17 superficies   1 Omni de 4
```

As duas brasas dos fumantes são a terceira e a quarta Omni, e é por isso que
**não** há uma segunda lâmpada na fachada: a bandeira é emissão de material, que
não entra no teto de quatro luzes por chunk.

Das 20 superfícies, só **duas são novas** (`janela_fumaca` e `fumaca_baseado`).
O engradado saiu de `metal_enferrujado` para `metal` e a pichação de `reboco`
para `concreto_sujo` justamente por isso: numa peça que se repete em 22
endereços, superfície nova é superfície nova em 22 chunks.

**Três coisas que a captura corrigiu, e o código não teria mostrado:**

1. O telheiro com 1,05 m de balanço **tapava a própria bandeira** — a peça da
   silhueta comia a peça da cor. Passou a 0,82 m e subiu 6 cm.
2. A lâmpada magenta a 0,66 m da parede **estourava a folha da porta em branco**,
   e a ombreira escura ao lado lia como uma barra preta no meio do vão. Afastada
   para 1,15 m, cai de raspão e pousa no degrau.
3. Afastar a lâmpada resolveu o perto e **matou o sinal de longe**. A correção
   não foi devolver energia à lâmpada: foi separar as duas funções — a cor de
   longe passou a sair da emissão da própria vidraça (1,15 → 2,3), que não gasta
   luz nenhuma, e a lâmpada ficou só com a poça no degrau.

**Ficou de fora**, e é curto: bicicleta encostada e o par de tênis no fio. Os
dois foram cortados pelo mesmo critério — a 18 m com névoa não se lê nenhum dos
dois, e o orçamento de superfície é melhor gasto em outra coisa.

---

## 3.7. Fase 3 — FEITA em 14/09/2026 (falta a captura)

### O item principal: a escada de valor

Isto era um palpite no diagnóstico ("os três estão dentro de 15 pontos"). Virou
medida, e o palpite estava **otimista**: a conta é média da textura × `tint` do
material × tint de vértice, e dava

```
piso   125,5      teto   128,4      parede 141-150
```

**Piso e teto a TRÊS pontos um do outro.** Um cômodo em que o chão e o teto têm
o mesmo valor não tem leitura vertical nenhuma — girar a câmera não troca o tom
de nada. Era essa a massa marrom uniforme das capturas, antes de a névoa entrar
na conta.

A escada certa sai da luz que o cômodo **tem**. Não há lâmpada de teto: quem
acende é a TV, duas luminárias de canto, a lâmpada do som e as brasas, tudo na
altura do peito ou abaixo. Então o teto é o mais escuro, o piso pega as poças, a
parede é onde a luz bate:

```
teto    54,8      piso    99,6      parede 141-150      amplitude 95
```

O teto também foi para o **frio** (`0.40, 0.43, 0.48`): escuro e quente ainda lê
marrom; escuro e azulado lê sombra, e sombra é o que há lá em cima.

Nada disso tocou em `mat_teto.tres` nem `mat_piso.tres`, que são compartilhados
com a casa comum, o mercado e o bar. O tint é de **vértice**, passado pelo
construtor — que é exatamente para isso que `psx_surface` multiplica `COLOR.rgb`.

Medida reproduzível: `python tools/medir_valor.py

# Criterio de aceite da casa e da primeira missao: 18 checagens, sai 0 ou 1
python tools/verificar_fumaca.py` (novo). Ele avisa sozinho
quando a amplitude cai abaixo de 60.

### O resto da fase

| O que | Onde |
|---|---|
| **Janela na parede oeste**, com caixilho, peitoril, cortina meio aberta e varão | `_janela_da_rua` |
| **Sódio da rua** entrando por ela — a quarta cor do cômodo e a única que vem de fora do prédio | `_luzes` |
| **Quatro cartazes diferentes** no lugar de quatro cópias do mesmo | 4 células novas, linha 7 do atlas |
| **Duas manchas amarelas no teto**, onde se fuma | `_manchas_do_teto` |
| **Quatro pedaços de fita crepe** no formato de um cartaz que não está mais lá | `_fita_do_cartaz_que_saiu` |
| **Duas colunas de fumaça a mais**, com cinzeiro, dentro do enquadramento do plano 05 | `_fumaca` / `_tralha` |

O cômodo não tinha **um** vão além da porta. Uma sala fechada de 9,8 m sem nada
por onde o lado de fora existir lê como caixa — e o lugar inteiro é construído em
cima do contraste com a rua molhada que o jogador acabou de atravessar.

**Custo:** 940 → **1.058 triângulos**, 8 → 9 superfícies (só `janela_acesa` é
nova), 5 → 6 lâmpadas. O teto de referência continua 25.000 visíveis.

### Dois erros que a medida pegou antes da captura

1. `KitModular.placa` gira em **Y**, ou seja mantém a placa **em pé**. As quatro
   manchas do teto nasceram como painéis verticais pendurados no ar na altura da
   laje. A base certa é `Basis(RIGHT, PI/2)`, a mesma do próprio teto.
2. As manchas saíram com `uv_per_meter = 100`, que é a escala do **atlas**, não
   a do teto (`0.5`). O reboco repetia cem vezes por metro: ruído, não mancha.

### Cortado, e por quê

**Ventilador de teto/pé.** A classe `Ventilador` existe e oscila, mas é do kit da
estufa: usa `mat_estufa` e as células (4,5)/(7,5)/(3,5), que são o verde-plástico
de lá. Traria a paleta errada e um material inteiro para um objeto. Vale quando
houver célula de ventilador no atlas da casa — fica anotado, não esquecido.

### O achado da fase: luz colorida nao vence albedo

O item 2 da Fase 3 era "conferir se a TV pinta os dois jogadores de azul", que o
cabecalho de `televisao.gd` promete desde sempre. Medido no plano 05, com o cone
e `ENERGIA = 3,1`:

```
jogadores na frente da TV   B-R  -28,5
parede atras deles          B-R  -37,0
bancada amber, do outro lado B-R -37,5
```

Ou seja: 8,5 pontos mais frios que a parede, e ainda assim francamente
alaranjados. Antes de mexer, o diagnostico — **subir a energia para 14 e olhar**:

```
chao na frente da TV:  -26  ->  -51        ficou MAIS laranja
```

A luz chega. O que nao chega e o azul, e nao ia chegar nunca: `ALBEDO = texel *
COLOR`, e o piso desta sala e madeira em **(164, 119, 78)** — o canal azul vale
menos da metade do vermelho. Luz azul sobre superficie laranja da laranja mais
claro, com qualquer energia. E ainda ha o `grade_tint` quente do preset
multiplicando a imagem inteira por cima.

**O que pinta de azul um comodo de albedo quente e o AR**, nao a superficie — e
foi sempre assim em jogo de PS1. Este comodo e o melhor lugar do jogo para isso:
tem quatro camadas de fumaca no teto e seis colunas subindo de cinzeiro.

Entao a TV ganhou o **mesmo cone somado que o poste da rua usa**
(`mat_cone_luz`), deitado para a frente, amarrado a `facho_forca` do preset como
todos os outros — o facho so existe onde ha ar para ele acender. Resultado
medido na mesma regiao:

```
zona onde a TV bate:  -15  ->  0        neutra, contra uma sala em -25
```

Zero nao e azul, e e o alvo certo: com `grade_tint` quente, "neutro onde a TV
bate e quente em todo o resto" e a leitura de azul a 480x270. Forcar B-R
positivo exigiria brigar com a grade e sairia errado.

O facho pulsa junto com a troca de quadro, pela mesma razao que a Lampada nunca
pisca so a Omni: facho parado com luz pulsando denuncia o truque.

### Custo final da Fase 3

```
comodo:  940 -> 1.058 triangulos    8 -> 9 superficies de malha    5 -> 6 Omni
```

Uma superficie nova no construtor (`janela_acesa`, a vidraca) mais uma chamada
de desenho no prop da TV (`mat_cone_luz`, o facho) — o facho e um
MeshInstance3D pendurado no no, e nao entra na contagem do `medir_fumaca`, que
so conta a malha do comodo.

## 3.8. Fase 4 — primeira fatia FEITA em 14/09/2026

### A missão deixou de acabar na soleira

Era o buraco mais grave do mapa (2.8): `_ao_entrar` fechava a primeira missão do
jogo **no instante em que o jogador cruzava a porta**. O cômodo mais trabalhado
do jogo — oito pessoas que andam, fumam, conversam e riem — era o cenário de um
"OBJETIVO CUMPRIDO" e nada mais, e não havia razão nenhuma para dar três passos
para dentro.

Agora são três etapas: marcar no GPS → chegar → **achar o dono da casa e falar
com ele**. O dono fica encostado na parede leste, ao lado da porta dos fundos, no
canto oposto à entrada: a terceira etapa obriga a **atravessar** a sala, que é o
único jeito de ela ser vista em vez de só cruzada.

### O assunto da casa, sem um terceiro sistema de fala

`FalasNpc.opcoes` já aceitava um `contexto` (`rua` / `volante`). Ganhou `casa`,
que acrescenta **"O QUE TÁ ROLANDO AQUI?"** à lista — antes do assunto próprio da
pessoa, porque quem entra numa festa pergunta o que está rolando antes de
perguntar da vida de quem abriu a porta.

As linhas **não** entraram na tabela de temperamentos. Doze blocos novos para um
lugar só seriam caros e estariam errados: numa festa as doze pessoas falam da
mesma coisa, e o que muda é o **tom**. Então são três blocos — áspero, neutro,
gentil — escolhidos pela mesma `aspereza` que o trânsito já usa para decidir quem
buzina. O dono tem bloco próprio, a única exceção do arquivo, porque é o fim da
primeira missão.

| O que | Onde |
|---|---|
| `contexto` de conversa por convidado | `convidado.gd`, `conversa.gd`, `interiores.gd` |
| Assunto `role` com tom por aspereza | `falas_npc.gd` |
| Rótulo próprio: "Falar com o dono da casa" | `Convidado.Gatilho` |
| Terceira etapa e `dono_respondeu()` | `missoes.gd` |
| O dono, `ENCOSTADO` e fumando, na parede leste | `casa_fumaca_builder.gd` |
| Presente (`bilhete`) ao perguntar do rolê | `Convidado._pagar_o_que_o_dono_deve` |

### Dois erros pegos antes de virar bug de jogador

1. **O dono nascia dentro da poltrona.** `Convidado` é um `CharacterBody3D`; a
   poltrona tem caixa de colisão. Ele seria empurrado para fora no primeiro
   quadro. Foi para a parede leste, onde a posição ainda cumpre as três coisas
   que ela tinha de cumprir.
2. **Bolsa cheia travava a primeira missão do jogo.** Presente e missão estavam
   amarrados: `Inventario.adicionar` devolve 0, a função saía antes de
   `dono_respondeu()` e a etapa ficava aberta para sempre, sem nada na tela
   dizendo por quê. Agora a missão fecha quando ele **responde**; o presente é
   separado e continua não evaporando.

### O que ficou da Fase 4, e por quê

Cortado por orçamento de sessão, não por escopo: sentar no sofá, pegar o
controle e entrar na partida, aceitar o baseado (muda o pós-processamento),
pegar cerveja na bancada, ligar/desligar o som, e o ponto de save. Os cinco
primeiros são interações novas; o save merece decisão à parte — na cidade o save
é o orelhão da rua, e um dentro de casa teria de ser um telefone de parede para
não quebrar a regra.

---

## 3.9. Fase 6 — plano 05 reencenado em 14/09/2026

Quatro tentativas, cada uma corrigindo o que a captura anterior mostrou. O
enquadramento antigo era `DE (1,55 / 1,42 / 2,35)` para `ATE (2,65 / 1,30 / 3,55)`
mirando em `(4,80 / 1,05 / 5,95)`, e a captura acusava quatro coisas: o quarto
direito do quadro era a bancada e a estante, um bloco laranja sem nada
acontecendo; a TV media 5% da largura sendo o motivo de o cômodo existir; os dois
jogadores ficavam pequenos e fora do centro; e o centro-esquerda era vazio.

| Tentativa | O que a captura mostrou |
|---|---|
| 1 — perto e por dentro (x 3,45→3,80) | **O facho sumiu.** A câmera correu em cima do eixo do cone, e feixe somado visto de dentro fica de perfil: não tem o que mostrar. Também ficou perto demais da área de circulação, e um convidado qualquer estacionou na lente |
| 2 — 1,5 m para oeste | Facho de volta, atravessando o quadro. Mas a mira passava 3,5 m **além** das pessoas: tubo e feixe bonitos, os dois jogadores virando vulto no canto — num plano cuja legenda é "Eu sei lá que tipo de gente mora nessa cidade" |
| 3 — mira nas pessoas | Melhor, mas a lente a 1,10 ficava **acima da cabeça de quem está sentado**, e a tarja de baixo cortava o corpo dele pela metade |
| 4 — lente a 0,92 | Fechou |

A altura final não é arbitrária: **0,92 m é o olho de quem está sentado no chão**
— o mesmo sujeito que abriu esta frente de trabalho com o quadril flutuando a
37 cm e o pé três centímetros dentro do piso.

A geometria do cômodo faz o resto sozinha a partir daí: o sentado cai no centro,
o que está de pé fica à esquerda dele, a TV entra pela direita com o facho
cruzando o vão entre os dois, e a parede leste — seis metros de reboco vazio que
comia o terço direito — sai fora do meio-campo de 29 graus que o FOV de 58
enxerga.

**Ferramenta nova:** `--olhar-plano05` põe a câmera na pose final do movimento,
com o mesmo FOV, lendo as **mesmas constantes** do roteiro. Captura em trinta
segundos em vez dos três minutos de `--ver-abertura`, e não há uma segunda cópia
do enquadramento para sair de sincronia. O que ela não reproduz são as tarjas —
para julgar com elas, a captura é cortada na proporção da tarja depois.

---

## 3.10. A validação que faltava — FEITA em 14/09/2026

Uma afirmação desta frente estava sustentada só por leitura: *"o jogador fala com
o dono e a missão termina"*. Medida não alcançava — é comportamento de três
autoloads conversando — e captura menos ainda, porque o que aparece numa foto é a
caixa de diálogo aberta, não a etapa avançando atrás dela.

Agora existe `TesteFumaca` (`--teste-fumaca`) + `tools/verificar_fumaca.py`, no
mesmo formato do `TesteCasa`/`verificar_casa.py` que o projeto já usa. **18
critérios, todos passando**, e cada um é um defeito que existiu de verdade ou a
prova de que ele não voltou:

```
ok  missao_etapas = 3            a terceira etapa existe
ok  etapa_apos_rota = 1          tracar a rota no GPS fecha a licao de mapa
ok  etapa_apos_entrar = 2        entrar ABRE a etapa do dono; 3 aqui seria a
                                 missao voltando a terminar na soleira
ok  gente = 9                    oito da festa mais o dono
ok  com_controle = 2             so os dois que jogam
ok  pe_abaixo_do_piso = 0        a pose provada no corpo que esta NA SALA
ok  role_na_casa = 1 / na_rua=0  o assunto do lugar nao vaza para fora dele
ok  missao_concluida = 1         falar com o dono termina a missao
ok  presente = 1                 e ele paga o bilhete
ok  bolsa_missao_concluida = 1   com a bolsa CHEIA a missao fecha do mesmo jeito
.   osso_mais_baixo_cm = 10      o osso mais baixo da sala, 10 cm acima do piso
```

A rotina não usa atalho: não chama `avancar()` para pular etapa. O que está
sendo testado é a amarração entre GPS, Interiores e Conversa, e um atalho
testaria o atalho.

### Três defeitos, todos no próprio teste

Vale registrar porque é a razão de a rotina existir — as três primeiras execuções
reprovaram, e nenhuma das reprovações era do jogo:

1. **`Gps.filtrar_por` sem o app aberto** não filtra nada: a lista só existe
   depois que o aparelho monta. A etapa 0 nunca fechava.
2. **`Conversa.escolher` só acha o assunto depois que a LISTA abriu**, e ela abre
   quando a saudação termina. A rotina agora avança até o assunto existir — que é
   literalmente o que o jogador faz: aperta até aparecer o menu.
3. **`avancar` sozinho nunca fecha a caixa**: terminada a resposta ela volta para
   a lista e fica esperando. E escolhendo `sair` a cada volta, a despedida
   reiniciava sozinha. As duas versões batiam no teto de 80 passos e reportavam
   "não fechou" — verdade sobre o teste, mentira sobre o jogo.

O medidor do pé também estava errado (`99 - 2000 = -1901 m`): a referência é a
transformada do **esqueleto**, que já carrega a cadeia Convidado → Corpo →
Esqueleto, e não a do corpo.

---

## 3.11. Fase 4 — interações de objeto, 14/09/2026

### Sentar

O corpo **não** desce. Um `CharacterBody3D` suspenso na altura de um assento cai
no quadro seguinte, e encaixar a cápsula dentro do móvel briga com a colisão
dele — os dois caminhos custam mais do que entregam. Quem desce é a **lente**,
por um `olho_override` que espelha o `fov_override` que o Player já tinha. Em
primeira pessoa as duas coisas leem igual, e esta não briga com gravidade nem
com cápsula.

Dois assentos, com enquadramentos **diferentes** de propósito:

| Móvel | Olha para | Lente |
|---|---|---|
| sofá | a TV, de frente — a partida vista do lugar de quem mora ali, com o facho na cara e a fumaça subindo entre você e a tela | 0,86 m |
| poltrona | o **meio da sala** — é a cadeira de quem veio conversar, e vê a roda de gente com a TV de canto | 0,90 m |

Dois assentos com o mesmo enquadramento seriam um assento desenhado duas vezes.
E os 4 cm de diferença não são gratuitos: sofá velho afunda mais que poltrona, e
é o que faz sentir que trocou de móvel.

### Três coisas que dá para pegar

Remédio e bandagem na bancada, bateria na mesa de centro — objetos que **já
estavam desenhados ali**. Até agora eram malha fundida no cômodo: o jogador via,
chegava perto e não acontecia nada. Um cenário cheio de coisa que não se pega
ensina o jogador a parar de tentar, e depois disso ele também não tenta onde
tinha.

### O teste cresceu junto, e pegou dois defeitos

`verificar_fumaca.py` foi de 18 para **26 critérios**. Os oito novos reprovaram
duas coisas na primeira execução:

1. **`levantou_voltou = 0`.** Levantar devolvia o jogador para a transformada de
   **identidade** — a origem do mundo — em vez de para onde ele estava. Causa:
   lambda em GDScript captura por **valor**, e escrever num `Transform3D`
   capturado não sobrevive à chamada. O estado foi para dentro de um `Array`,
   que é referência.
2. **`assentos = 1`.** O teste contava por nome, e Godot renomeia o segundo nó
   homônimo. Passou a contar por classe e rótulo.

O critério que mais protege é `levantou_olho_livre`: uma interação que muda três
coisas — posição, altura do olho e trava — e esquece de desfazer **uma** delas
deixa o jogador de pé no meio da sala enxergando a 86 cm pelo resto da partida, e
nada na tela diz por quê.

**Ficou de fora:** pegar o controle e entrar na partida, aceitar o baseado
(muda o pós-processamento), ligar/desligar o som, e o ponto de save — este último
ainda esperando decisão, porque na cidade o save é o orelhão da rua e um dentro
de casa teria de ser um telefone de parede.

---

## 4. Ordem decidida (14/09/2026)

```
Fase 0 + Fase 1  FEITAS (14/09)
Fase 2  (fachada)         FEITA (14/09) - vale para as 22 casas da cidade
Fase 3  (sala)            FEITA (14/09) - medida e vista
Fase 4  (interacoes)      PARCIAL (14/09) - missao, conversa, assentos e itens; controle/baseado/som ficaram
Fase 5  (4 comodos novos) -> corredor+cozinha, escada+quarto, banheiro, laje
Fase 6  (abertura)        FEITA (14/09) - quatro tentativas, cada uma medida
```

---

## 5. Ferramentas criadas nesta sessão

```bash
GODOT=".tools/Godot_v4.7.2-stable_win64_console.exe"

# Onde cada osso para nas posturas SENTADO / CONTROLE / LIVRE
"$GODOT" --headless --path game --script res://tests/medir_sentado.gd

# Triangulos, superficies, colisao e props da casa e da estufa
"$GODOT" --headless --path game --script res://tests/medir_fumaca.gd

# Endereco das casas da fumaca mais proximas da origem (ja existia)
"$GODOT" --headless --path game --script res://tests/onde_fumaca.gd

# Custo do chunk que tem a casa da fumaca, contra um vizinho sem ela
"$GODOT" --headless --path game --script res://tests/medir_chunk_fumaca.gd

# Escada de valor do comodo: piso, parede e teto em luminancia. Avisa sozinho
# quando a amplitude cai abaixo de 60 e o comodo volta a ler chapado.
python tools/medir_valor.py

# Criterio de aceite da casa e da primeira missao: 18 checagens, sai 0 ou 1
python tools/verificar_fumaca.py

# Capturas
"$GODOT" --path game -- --entrar-fumaca --shot=../captures/fumaca_aaa/entrada.png --shot-frame=330 --shot-quit
"$GODOT" --path game -- --entrar-fumaca --olhar-tv --shot=../captures/fumaca_aaa/tv.png --shot-frame=290 --shot-quit
"$GODOT" --path game -- --entrar-fumaca --olhar-fumante --shot=... --shot-frame=290 --shot-quit
"$GODOT" --path game -- --ir-para=112.9,-165.8,112.9,-171.8 --shot=../captures/fumaca_aaa/fachada.png --shot-frame=330 --shot-quit
# A mesma casa vista de 14 m rua abaixo, que e o teste que importa: a cor
# atravessa a nevoa antes de a silhueta aparecer?
"$GODOT" --path game -- --ir-para=125.5,-164.2,112.9,-171.8 --shot=../captures/fumaca_aaa/da_rua.png --shot-frame=360 --shot-quit
"$GODOT" --path game -- --ver-abertura      # roda a abertura inteira e grava os 8 planos
# ATENCAO: --ver-abertura reescreve 15 PNGs versionados, sete deles da frente da
# praca (captures/praca_matriz/cine e captures/_sessao_corpo_praca). Depois:
#   git checkout -- captures/praca_matriz/cine captures/_sessao_corpo_praca

# So o fim do movimento do plano 05, em 30 s em vez de 3 min
"$GODOT" --path game -- --entrar-fumaca --olhar-plano05 --shot=... --shot-frame=300 --shot-quit
# Outras molduras da casa: --olhar-tv  --olhar-jogadores  --olhar-fumante
#                          --olhar-janela  --olhar-dono
```

**Dois defeitos da própria ferramenta, consertados na Fase 0:**

- `--olhar-jogadores` punha a câmera em `y = -0.62` relativo à base do
  convidado, ou seja **abaixo do piso do interior**, e a captura saía só com
  névoa (`cidade.gd:653`).
- `Player.olhar_para` media o pitch a partir de `global_position`, que fica nos
  **pés**, e não do olho a 1,62 m. De longe o erro valia três graus; de perto
  ele inverte o sinal, e mirar alguém sentado no chão fazia a câmera subir para
  o teto (`player.gd:630`).

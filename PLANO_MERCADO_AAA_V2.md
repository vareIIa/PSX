# PLANO MERCADINHO AAA v2 — a loja aguenta ser olhada de perto

> Mapa medido do que falta, ponto a ponto, e o plano para fechar. Versão 2.0 —
> 22/09/2026 — branch `playable`.
> A v1 ([PLANO_MERCADO_AAA.md](PLANO_MERCADO_AAA.md)) continua valendo como
> histórico e como fonte das fases F0–F9, dos orçamentos e dos critérios de
> aceite. Esta v2 não substitui aqueles números: ela acrescenta o que a
> auditoria fotográfica encontrou depois da F2 e troca o **método** de montar
> móvel e produto.

---

## 0. O pedido

> "ainda tem inúmeras melhorias para conseguir deixar o mercado AAA perante
> plano que fizemos perante Shift at Midnight / banheiro extremamente low poly,
> sala dos funcionários low poly também, do lado da porta da garagem tem uma
> estande que deveria ter os produtos e etc, mapeie o que ainda falta para nosso
> mercadinho ficar AAA de ponto a ponto, depois de mapear, crie plano AAA
> profissional."

E, depois, os cinco defeitos que o próprio jogador confirmou nas fotos:

1. No banheiro, na copa, no escritório, na lixeira e na máquina de café, a louça
   e os móveis saem como **caixas pretas**: o material `metal`, no HD, vira
   granito escuro.
2. A **estante da garagem**, ao lado do portão, e as do estoque são uma
   **pintura chapada** de caixas.
3. As **placas de corredor** mostram **barras** no lugar de texto.
4. A **estufa de salgados** são **tábuas empilhadas**.
5. A **fachada** assenta numa calçada com **2,33 m de desnível**.

---

## 1. Como a loja foi auditada

A loja inteira leva um minuto para montar e o quadro que interessa ocupa um
canto dela. Duas ferramentas de medida, as duas desta sessão:

**O tour fotográfico** — `teste_mercado.gd --tour`, 22 poses em coordenada de
planta, cobrindo salão, caixa, garagem, corredor, banheiro, copa, escritório,
estoque, fachada e vitrine. Sai em `captures/mercado_aaa/auditoria/a01..a22`.

```
.tools/Godot_v4.7.2-stable_win64_console.exe --path game --resolution 1280x720 \
    -- --fog=leve --teste-mercado --tour
```

Roda **duas vezes**: a primeira monta o streaming e a foto sai da loja pela
metade (memória `primeira-execucao-nao-vale-captura`).

**A bancada de peça** — `tests/bancada_pecas.gd`, uma peça sozinha num piso de
ladrilho, sob a luz da loja, de quatro lados, nos dois estilos, com a contagem
de triângulos por material. É o que permite corrigir uma torneira sem montar a
cidade.

```
.tools/Godot_v4.7.2-stable_win64_console.exe --path game --resolution 1280x720 \
    --script res://tests/bancada_pecas.gd -- \
    --kit=res://src/world/mercado/kit_banheiro.gd --funcao=bancada_vaso \
    --saida=res://captures/mercado_aaa/bancada --parede
```

Contrato do kit: `static func bancada_xxx(sup, colisao) -> void`, peça em volta
da origem, chão em y = 0, frente para +Z. **Sem `--headless`**: o shader só
existe com janela.

**A sonda de calçada** — `tests/sonda_calcada_mercado.gd`, nova, mede o
desnível do passeio ao longo da fachada, loja por loja, nas 32 lojas da cidade.
É a régua do defeito 5 (§6).

---

## 2. As três causas, e por que são causas e não sintomas

Quarenta e um defeitos anotados na auditoria saem de três erros de método. Isso
importa: consertar peça por peça sem trocar o método reintroduz o defeito na
peça seguinte.

### 2.1 O material `metal` é escuro, e nenhuma tinta salva

`metal.png` tem albedo **62/255** e `metal.jpg` (HD) **63/255**. O vaso
sanitário era pintado de branco sanitário por vértice — e a tinta de vértice
**multiplica** (memória `cor-de-vertice-corta-em-um`): 62 × 0,95 ≈ 53/255. Preto.

Não era defeito do HD. Era o material errado nos **dois** estilos. A auditoria
encontrou `metal` em 31 peças do `KitMercado`, entre elas vaso, pia, espelho,
toalheiro, lixeira, mesa de trabalho, cadeira, armário de vestiário, máquina de
café e estufa.

**Consequência de projeto:** peça clara pede material claro. Foram criados seis,
todos com conjunto HD (albedo, `_n` normal, `_ru` com R = rugosidade e
G = oclusão) em `tools/gerar_mercado_aaa.py`:

| Material | Para quê | Albedo |
|---|---|---|
| `mercado_louca` | louça sanitária, caneca, papel | 241,242,239 |
| `mercado_inox` | torneira, cuba, barra, grelha | 177,181,185 escovado |
| `mercado_formica` | bancada, porta de armário | 205,199,185 |
| `mercado_plastico` | cesta, lixeira, cadeira, engradado | 238,238,236 |
| `mercado_ladrilho` | piso, 20 cm | 10×10 por 2 m |
| `mercado_revestimento` | parede de banheiro, 15 cm | 14 por 2 m |

O nome começa em `mercado_` de propósito: é o que põe o material em
`EstiloVisual.ABRIGADOS` (sem molhabilidade de chuva) e satisfaz o critério A35.

> Armadilha já paga: o `_ru` salvo em **tons de cinza** faz o shader ler a
> rugosidade como oclusão (`AO = ru.g`), e a louça de rugosidade 0,10 virou
> oclusão 0,10 — escura outra vez. O `_ru` é RGB.

### 2.2 Caixa é a única primitiva, e caixa não diz "louça"

O `KitMercado` foi escrito para o salão, onde funciona: gôndola, balcão e parede
são caixas lisas e quem enche é a imagem pregada na frente. A mobília de serviço
herdou o método e não podia: o que faz um objeto ler como ele mesmo a um metro e
meio é o **contorno** — a curva da bacia, o gargalo da garrafa térmica, o cano
da torneira, o sifão.

**Consequência de projeto:** uma biblioteca de primitivas redondas,
[peca.gd](game/src/world/mercado/peca.gd) (`class_name Peca`), que entrega
silhueta curva com o orçamento de uma caixa e meia:

- `torno(sup, material, xf, perfil, lados, cor, arco)` — revolução em Y. Ponto
  de perfil **repetido** é vinco; raio 0 fecha o polo; a normal sai da direção
  do percurso, então descer por dentro (a bacia, a cuba) vira face virada para o
  eixo. Escala não uniforme é permitida — a bacia oval é um torno achatado, e a
  normal vai pela inversa transposta.
- `tubo(sup, material, pontos, raio, lados, cor, fechar, raios)` — cano de
  torneira, alça de cesta, sifão, barra de apoio, pé tubular. Referencial
  transportado ao longo do caminho, e o anel alarga no cotovelo.
- `prisma(sup, material, xf, contorno, y0, y1, cor, ...)` — contorno 2D
  extrudado, não precisa ser convexo: tampo de canto arredondado, cantoneira em
  L, caixa acoplada.
- `esfera`, `cilindro`, `retangulo_redondo`, `caixa_redonda`, `elipse`.

Todo triângulo sai por `_tri`, que confere contra a normal pretendida e vira
sozinho — é o que aposenta a memória `giro-de-face-aponta-ao-contrario` dentro
deste arquivo.

> **`Peca.prisma` não subtrai.** Caixa dentro de caixa não abre buraco: some.
> A cuba "embutida" no tampo ficou coberta pela laje do tampo e a bancada saiu
> lisa, sem pia; o nicho do copo dentro do corpo da máquina de café sumiu. Vão
> se faz com o espaço VAZIO entre dois volumes, ou com peça sobreposta.

### 2.2b A bancada acende menos que o cômodo

Medido nesta sessão, e vale para toda peça nova: a bancada de peça foi acertada
pelo ar da loja na rua (`fog_mercado_rua.tres`: ambiente 0,38, omnis de 2,4).
A garagem tem lâmpada de **3,1** e a copa de **2,8**, com alcance de 7 a 11 m.
Resultado: a cor que a bancada mostra correta sai **lavada** no jogo. O aço
`3a3e42` da estante, cinza-chumbo na bancada, sai branco na garagem; o armário
de vestiário, o frigobar e o bebedouro saíram os três brancos e se fundiram num
borrão só (`a17`).

A conta é `albedo × tinta × luz`, e os materiais novos têm albedo 236. Regra
prática: **tinta de móvel de serviço fica entre 0,55 e 0,72**, e cor de produto
vale um terço da cor de catálogo. Tinta acima de 0,80 estoura em um.

Fica como dívida da F15: a bancada precisa de um `--luz=garagem` que reproduza a
lâmpada forte, senão ela continua aprovando cor que o jogo reprova.

### 2.3 Imagem chapada só funciona de frente

A gôndola do salão é vista de frente, a dois metros: imagem pregada resolve. A
estante do estoque é vista de **três quartos** — e de três quartos a imagem não
tem espessura: as caixas ficam todas no mesmo plano, com a mesma sombra, e a
estante lê como um cartaz de caixas encostado na parede. Foi literalmente o que
o jogador descreveu.

**Consequência de projeto:** carga em três dimensões,
[kit_estoque.gd](game/src/world/mercado/kit_estoque.gd). O que dá volume não é
a textura melhor, são quatro coisas: **aba** de papelão dobrada para fora
(caixa aberta diz que alguém mexeu ali), **profundidade desigual** (fileira
alinhada é o que mais denuncia geometria repetida), **giro pequeno** de 2 a 8
graus, e **vão** (prateleira cheia lê como parede). Tudo por
`RandomNumberGenerator` de semente fixa por estante, então a loja monta igual em
toda sessão e em todo jogador da rede.

---

## 3. O mapa, ponto a ponto

Estado em 22/09/2026. ✅ feito e verificado por foto nesta sessão; ⏳ próxima
fase; ⬜ depois.

### 3.1 Banheiro (`x` 0–2,8 / `z` 12,5–16,0 · teto 2,68)

| # | Defeito | Evidência | Estado |
|---|---|---|---|
| B1 | Vaso = 3 caixas empilhadas | `a14` | ✅ `KitBanheiro.vaso`: pé, bacia oval vincada, água, assento, caixa acoplada, botão, papeleira |
| B2 | Pia = coluna quadrada + tampo quadrado | `a15` | ✅ `KitBanheiro.pia`: coluna, cuba oval funda, torneira em arco, volante, sifão em U |
| B3 | Tudo em `metal` → preto | `a14`, `a15` | ✅ louça/inox/plástico |
| B4 | Espelho escuro lê como furo na parede | `a15` | ✅ `espelho`: vidro cinza-azul **claro** + moldura fina |
| B5 | Sem dispenser, sem barra, sem ralo, sem cano | `a14` | ✅ `dispenser` (papel e sabonete), `barra_apoio`, `ralo`, `cano_canto`, cabides |
| B6 | Piso `piso_ceramico` com albedo 80/255 | `a14` | ✅ `mercado_ladrilho` |
| B7 | Parede em `mercado_azulejo`, que lê como ladrilho decorativo de cozinha | `a14` | ✅ `mercado_revestimento` de 15 cm |
| B8 | `divisoria_box` declarada e nunca chamada | código | ⬜ comodo tem um sanitário só; ou usa, ou sai |
| B9 | Sem som de água, de porta e de passo em cerâmica | — | ⬜ F16 |
| B10 | Sem sujeira: rejunte, mancha, encardido | `a14` | ⏳ F15, no `_ru` e no albedo |

**Orçamento 2000 · medido 1886** (louça 750, inox 852, plástico 284).

### 3.2 Copa (`x` 3,0–7,6)

| # | Defeito | Estado |
|---|---|---|
| C1 | Bancada = gabinete de `metal` com seis caixas em cima | ✅ `KitServico.bancada`: fórmica, rodapé recuado, portas com puxador, cuba de inox **sobreposta**, torneira de cano alto |
| C2 | Garrafa térmica = duas caixas | ✅ `garrafa_termica` com gargalo, tampa, bico e alça (140 tri) |
| C3 | Sem máquina de café, micro-ondas, frigobar, bebedouro | ✅ os quatro, com vão do copo aberto, porta de vidro escuro, borracha e garrafão |
| C4 | Cadeira dobrável de caixas | ✅ `cadeira_plastica` monobloco, duas, uma torta |
| C5 | Mesa e armário de vestiário em `metal` escuro | ✅ `mercado_chapa` com cor clara |
| C6 | Micro-ondas flutuando **fora** do tampo | ✅ layout refeito em volta do centro da bancada |
| C7 | Piso escuro puxando o cômodo para baixo | ✅ trocado por `mercado_ladrilho`; foto de confirmação no próximo tour |
| C8 | Sem caneca, sem pote, sem pia usada | ✅ duas canecas; ⬜ pia com louça suja |

**Orçamento 3000 · medido ~2400** (bancada 1422 + eletro 748 + cadeiras).

### 3.3 Escritório (`x` 7,9–11,0)

| # | Defeito | Estado |
|---|---|---|
| E1 | Cadeira **de costas para o monitor** (giro PI + 0,18) | ✅ `cadeira_giratoria` de frente, base de cinco pontas com rodinha, coluna a gás, encosto inclinado |
| E2 | Mesa em `metal` escuro | ✅ `mercado_chapa` |
| E3 | Tela do CFTV estourada por emissão 1,7 do `mercado_luz` (relato da auditoria) | ⏳ F15 — **não reproduziu** em `a18`: a tela sai com as quatro janelas legíveis. Reavaliar com a luz do escritório acesa e de perto antes de mexer |
| E4 | Cofre e arquivo são caixas lisas | ⏳ F15: puxador, segredo, gaveta, etiqueta |
| E5 | Sem papel, sem pasta, sem caneca, sem telefone | ⬜ F15 |
| E6 | Piso escuro | ✅ trocado por `mercado_ladrilho`; foto de confirmação sai no próximo tour (`a18` ainda é do tour anterior) |

**Orçamento 2600.**

### 3.4 Estoque e garagem

| # | Defeito | Evidência | Estado |
|---|---|---|---|
| S1 | Estante = imagem chapada de caixas | `a09`, `a20` | ✅ `KitEstoque.estante_carregada`: montante de cantoneira em L, travessas, prateleiras, e carga de verdade |
| S2 | Palete = três cubos de 92 cm com a estampa esticada | `a11` | ✅ `KitEstoque.palete`: camadas de 2–3 caixas de tamanhos diferentes |
| S3 | Estrutura marrom saía creme e a estante lia como móvel de plástico | bancada | ✅ aço cinza `4e5256` |
| S4 | Engradado saía rosa: tinta clara × albedo 238 × lâmpada 3,1 estoura em um | `a09` | ✅ cores 30% mais escuras |
| S5 | Sem saco, sem engradado, sem vão | `a09` | ✅ os três, com regra que proíbe três iguais em fila |
| S6 | Carrinho, tambor e sacos de lixo ainda são caixas | `a11` | ⬜ F15 |
| S7 | `palete_bebida` ainda é imagem | `a11` | ⬜ F15 |

**Medido: estante de 2,4 m = 1776 tri** (papelão 924, plástico 624, chapa 288).
A da garagem tem 4,6 m → ~3200. Cabe no orçamento da garagem, que não tem
gôndola.

### 3.5 Salão e caixa

| # | Defeito | Evidência | Estado |
|---|---|---|---|
| L1 | Estufa de salgados = tábuas empilhadas | `a04` | ✅ `KitSalao.estufa`: base e tampa de inox, montantes nos quatro cantos, vidro, lâmpada quente, duas bandejas |
| L2 | Produto era uma placa da cor do salgado | `a04` | ✅ coxinha de torno (6 lados), pão de queijo, pastel — cada um com giro, escala e desvio próprios |
| L3 | Placa de corredor = barras pretas | `a01` | ✅ atlas de três faixas com **texto de verdade** (BISCOITOS, BEBIDAS, MERCEARIA) + `KitMercado.placa_recorte`, que tira uma faixa do atlas: três placas, um material, um lote de desenho |
| L4 | Lixeira = duas caixas de `metal` | `a06` | ✅ `KitSalao.lixeira`: corpo cônico, aro, interior escuro, saco dobrado |
| L5 | Máquina de café = caixa com placa acesa, 84 cm no chão | `a05` | ✅ `KitServico.maquina_cafe_de_piso` sobre pedestal de 82 cm |
| L6 | Cestas liam como caixas salmão | bancada | ✅ paredes inclinadas, aro, alças de arame que dobram para fora quando empilhadas (2232 tri para a pilha de 5 + 1 solta) |
| L7 | Monitor do caixa e leitor são caixas lisas | `a04` | ⬜ F15 |
| L8 | Gôndola continua imagem pregada — **e deve continuar** | `a01` | ✅ por decisão: de frente, a dois metros, imagem é o método certo (§2.3) |

### 3.6 Fachada e calçada — o defeito 5, medido

`sonda_calcada_mercado.gd`, 32 lojas da cidade, desnível da calçada ao longo dos
17 m da fachada:

```
[calcada] lojas=32 media_queda=0.70 m
[calcada] chunk=(2, -2)   queda=3.96 m  porta=-0.11  portao=-2.13
[calcada] chunk=(3, -9)   queda=3.95 m  porta=-0.06  portao=+1.96
[calcada] chunk=(1, -1)   queda=2.49 m  porta=-0.09  portao=+1.19
[calcada] chunk=(-9, 6)   queda=2.33 m  porta=-0.06  portao=+1.13
[calcada] chunk=(9, -12)  queda=2.12 m  porta=-0.08  portao=-1.17
[calcada] chunk=(12, -12) queda=1.74 m  porta=-0.10  portao=-0.99
```

O 2,33 m que o jogador viu é o chunk **(-9, 6)**, e não é o pior: em (2, -2) a
calçada cai 3,96 m e o portão da garagem abre para um passeio **2,13 m abaixo**
do piso; em (3, -9) ela sobe e o portão abre contra um passeio **1,96 m acima**.
Seis das 32 lojas passam de 1,7 m. A média, 0,70 m, é o caso que o modelo atual
já resolve: `PredioMercado._passeio` dá a cada boca a sua rampa e o granito
desce até o ponto mais baixo (medido antes: 61 cm em 17 m).

**O diagnóstico:** o defeito não é a rampa, é o **patamar**. Rampa vence 60 cm;
não vence 2 m. Loja de rua em ladeira não assenta na ladeira — ela ganha um
patamar nivelado na frente, e a ladeira é vencida **ao lado** do lote, por
escada e muro de arrimo. É o que a cidade de verdade faz, e é a mesma cirurgia
que `PredioMercado.afundar_chao` já faz com o chão da quadra: recortar o
triângulo na linha da pegada, rebaixar o que está dentro e emendar com parede.

Ver F14, §5.

### 3.7 O resto da loja

| # | Defeito | Estado |
|---|---|---|
| R1 | Porta dos cômodos do fundo sem colisão (`interiores.gd:1167-1223`) | ⏳ F14 |
| R2 | A malha do interior é uma só; o banheiro desenha junto com o salão | ⬜ F16, partir por cômodo |
| R3 | `VERDE_SERVICO_ESCURO` declarada e nunca usada | ⬜ limpeza |
| R4 | `KitMercado.bancada_copa`, `cadeira`, `lixeira`, `estante_estoque` e `caixa_quente` ficaram sem chamador | ⬜ limpeza depois da F15, quando não houver mais o que substituir |
| R5 | Atlas de rótulos reais (`textures_hd/rotulos.jpg`) com células ruins | ⏳ F15 |
| R6 | Sem som de geladeira, de porta automática, de rádio de loja | ⬜ F16 |

---

## 4. Orçamento de triângulos (revisão da §10.3 da v1)

A v1 reservava 12k para a **estrutura** da loja. A mobília nova é a que mudou:

| Área | Teto | Medido |
|---|---|---|
| Estrutura (casca, paredes, forro, vitrine) | 12 000 | inalterada |
| Banheiro mobiliado | 2 000 | 1 886 |
| Copa mobiliada | 3 000 | ~2 400 |
| Escritório mobiliado | 2 600 | a medir na F15 |
| Estoque (duas estantes + palete) | 6 000 | ~5 500 |
| Garagem (estante de 4,6 m + paletes) | 5 000 | ~4 200 |
| Estufa (peça heroína do balcão) | 2 000 | 1 976 |

A estufa custa uma gôndola inteira. É deliberado: fica a um metro do rosto do
jogador, no único ponto quente do salão, e é a peça que o jogador nomeou. Os
salgados usam **seis** lados, e não oito — a peça tem 4 cm e cabe em vinte
pixels de tela, mas quinze coxinhas de oito lados custavam 1680 triângulos.

---

## 5. Fases

A v1 fechou F0–F2. Esta v2 continua a numeração.

### F10 — Fundação (feito)

`Peca`, os seis materiais em `gerar_mercado_aaa.py`, `bancada_pecas.gd`,
`sonda_calcada_mercado.gd`. Sem fundação, cada peça consertada reintroduzia o
defeito.

### F11 — Banheiro, copa, escritório (feito)

`kit_banheiro.gd`, `kit_servico.gd`. Verificado em `a14`, `a15`, `a16` e `a18`. Falta a
foto do piso claro da copa e do escritório, trocado depois desse tour.

### F12 — Estoque em três dimensões (feito)

`kit_estoque.gd`, ligado na estante da garagem, nas duas do estoque e nos dois
paletes. Verificado em `a09`.

### F13 — Salão: estufa, lixeira, café, placa (feito)

`kit_salao.gd`, `placa_recorte`, atlas `mercado_secao` com texto.
Verificado em `a01` e `a04`.

### F14 — A loja em ladeira (próxima)

1. **Medir** o que a calçada faz hoje nas seis piores lojas: fotografar a
   fachada e o portão em (2,-2), (3,-9), (1,-1) e (-9,6). Sem foto, a correção
   é palpite.
2. `PredioMercado.nivelar_passeio(pegada)`: recortar a calçada numa faixa de
   `x` −0,25…17,25 por `z` −2,6…0 e pôr essa faixa no piso da loja, com 2% de
   queda para a sarjeta. A emenda com a calçada original, nas duas pontas, ganha
   **muro de arrimo** (a parede que `afundar_chao` já sabe emitir) e **escada**.
3. Escada de acesso com **corrimão** quando a queda na frente da porta passar de
   18 cm; rampa quando for menor (a cápsula do jogador, 32 cm de raio, bate na
   quina de um degrau de 9 cm a 49° e o degrau vira parede — já medido).
4. Rampa do portão: a de hoje resolve ±60 cm. Acima disso, **soleira elevada**
   com rampa de 8% para dentro da garagem, até `RAMPA_DENTRO`.
5. Critério: `sonda_calcada_mercado` reporta queda **na faixa da fachada** ≤ 12
   cm nas 32 lojas, e nenhuma soleira com degrau > 18 cm sem escada.
6. Colisão e navegação andam junto: `degraus_da_rampa` já é pública para a malha
   de navegação usar a MESMA rampa.

> **Território alheio.** A malha de ruas e o relevo são do psx-8a desde 21/09
> (memória `psx-8a-ancorou-a-quadra-da-praca`). A faixa da calçada na frente do
> lote é o mesmo caso do chão da quadra: a cirurgia é minha, dentro da pegada do
> lote, sem tocar em `Relevo` nem em `ChunkBuilder`. Fora da pegada, só com
> acordo.

### F15 — A segunda camada de detalhe

Cofre, arquivo, monitor do caixa, leitor, carrinho de carga, tambor, sacos de
lixo, `palete_bebida`. Sujeira e uso: rejunte encardido, mancha de tráfego,
respingo atrás da pia — no `_ru` e no albedo, não em geometria. Tela do CFTV sem
estourar. Revisão do atlas de rótulos reais.

### F16 — Som e corte de desenho

Som de água, de cerâmica, de geladeira, de porta automática. Malha do interior
partida por cômodo, para o banheiro não desenhar junto com o salão. Colisão da
porta dos cômodos do fundo.

---

## 6. Critérios de aceite (acréscimos à §11 da v1)

| # | Critério | Como se prova |
|---|---|---|
| A50 | Nenhuma peça da loja usa o material `metal` | `grep -c '&"metal"' kit_mercado.gd` = 0 |
| A51 | Toda peça nova tem foto de bancada nos dois estilos | `captures/mercado_aaa/bancada/*_moderno.png` e `*_ps1.png` |
| A52 | Banheiro mobiliado ≤ 2000 tri; copa ≤ 3000; escritório ≤ 2600 | saída `[pecas] total=` |
| A53 | Nenhuma estante de estoque usa imagem chapada de carga | `grep mercado_estoque` sem chamador |
| A54 | A placa de corredor mostra palavra legível a 5 m nos dois estilos | `a01`, `a02` |
| A55 | Queda da calçada na faixa da fachada ≤ 12 cm nas 32 lojas | `sonda_calcada_mercado` |
| A56 | Nenhuma soleira com degrau > 18 cm sem escada | `sonda_calcada_mercado` |
| A57 | O tour de 22 poses roda sem erro de script | `--tour` duas vezes |
| A58 | Nenhum móvel de serviço com tinta acima de 0,80 | §2.2b |

---

## 7. Riscos e o que não fazer

- **Não** trocar a imagem da gôndola do salão por produto modelado. É vista de
  frente, a dois metros, e a imagem é o método certo ali (§2.3). Modelar
  produto por produto custaria mil triângulos por gôndola e, com dither por
  cima, não ficaria melhor.
- **Não** rodar `tools/gerar_materiais.py --podar`: ele faz `unlink` em `.tres`
  fora da própria tabela, inclusive nos de outras frentes.
- **Não** contar com subtração em `Peca.prisma` (§2.2).
- **Não** usar `mercado_luz` aceso em painel pequeno: emissão 1,7 estoura o
  cômodo no MODERNO. Painel claro por albedo resolve.
- Toda tinta de vértice sobre material claro **estoura em um** debaixo de
  lâmpada forte. Cor de produto vai 30% mais escura do que o catálogo pede.
- A árvore é compartilhada e compila a cada passo: `class_name` novo só depois
  de `--import` (memória `edicao-compartilhada-compila-a-cada-passo`).

---

## 8. Decisões (22/09/2026)

| # | Decisão | Por quê |
|---|---|---|
| D10 | Peça de serviço é **geometria**; produto de gôndola é **imagem** | O que separa os dois é o ângulo em que o jogador vê (§2.3) |
| D11 | Cada cômodo de serviço ganha um kit próprio (`kit_banheiro`, `kit_servico`, `kit_estoque`, `kit_salao`) | Arquivo novo sobrevive a merge alheio; `kit_mercado.gd` é disputado por várias sessões |
| D12 | Material claro por peça, não tinta sobre `metal` | 62/255 de albedo não se conserta com tinta (§2.1) |
| D13 | Carga de estoque por semente fixa por estante | A loja monta igual em toda sessão e em toda máquina da rede |
| D14 | A placa de corredor leva **texto**, e as três saem de um atlas | Barra preta pendurada no teto lê como defeito, não como sinalização; e três materiais seriam três lotes de desenho |
| D15 | A loja em ladeira ganha **patamar**, não rampa maior | Rampa vence 60 cm, não 2 m (§3.6) |
| D16 | A estufa pode custar uma gôndola | É a peça que o jogador nomeou, a um metro do rosto, no único ponto quente do salão |

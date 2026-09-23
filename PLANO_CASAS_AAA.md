# Plano Casas AAA: casas e prédios de cidade mineira

**Pedido (22/09/2026):** foco total em deixar prédios e construções AAA. Paredes com
bug, repetição e pouca vida. Janelas abertas onde se vê um pouco de dentro, janelas
fechadas, umas com flor e outras sem, variação de casa e prédio, cidade interiorana.
Ruas e o resto ficam para depois.

## 1. Diagnóstico (levantamento de 22/09, código e 18 capturas, conferido por verificador)

| # | Defeito | Onde | Estado |
|---|---|---|---|
| D1 | A folha da porta de entrar ficava 5 mm atrás da parede. Fechada, o jogador via um painel cinza ou parede lisa (127 de 127 portas). | `_fileira`, `KitFachada._entrada` | **Resolvido**: vão de verdade (ParedeVazada) na porta |
| D2 | O quadro da porta saía espelhado nas faces +X e −Z, até 7,5 m longe da folha. | `_fileira` (`porta_local` medido no eixo da face) | **Resolvido**: centro da folha em `_lateral(direcao)` + 0,45 |
| D3 | Casa = placa clara na frente de uma caixa de concreto 5× mais escura. | `_massa` com `concreto_sujo` | **Resolvido** nas casas e na rua comercial: o corpo sai no reboco, na cor da casa |
| D4 | Janela era um plano 11 cm SALIENTE, sem recuo, sem sombra, igual em toda casa. | `KitFachada`, `KitModular.fachada` | **Resolvido**: vão recuado de 14 a 32 cm (ParedeVazada + JanelaViva) |
| D5 | O embasamento e a pingadeira atravessavam a porta e o portão, e a garagem ficava murada. | `KitFachada._embasamento` | **Resolvido** na casa nova: o barrado é banda da parede, cortada pelos vãos |
| D6 | Metal com albedo 63/255: o ar-condicionado, o medidor, a caixa d'água e a grade saíam pretos. | `mat_metal` | **Resolvido** na casa nova: material `metal_pintado`, caixa d'água cilíndrica de fibra azul |
| D7 | Repetição: 4 estilos, 1 janela, passo fixo de 3 m, remate por quadra (telhado em só 7% dos chunks). | `KitFachada`, `MalhaUrbana` | **Resolvido**: tipologia e remate por lote |
| D8 | Chapim do muro de quintal com 2,28 m: muros de 3,4 m. | `FundosBuilder._muro` | **Resolvido** (chapim de 8 cm) |
| D9 | Letreiro salmão aceso sem texto, "janela" de azulejo no térreo comercial. | `KitModular.fachada` | **Resolvido** na rua comercial nova: placa e testeira com o nome da loja (atlas de `tools/gerar_letreiros.py`) |
| D10 | Casa rígida enterrada no lado de cima da ladeira (27,5% dos lotes com o chão mais de 30 cm acima da soleira). | `_erguer_lote` | **Resolvido na frente** (F5-A): base no ponto alto da frente, escada, degrau e rampa; o chão desce sob a casa. Falta o porão progressivo (F5-C) |
| D11 | Esquina chanfrada nunca aparece (exige chunk em y = 0). | `_fileira` | Aberto (F5) |
| D12 | Fundo e lateral de esquina ainda em concreto escuro, com janela antiga. | `FundosBuilder` | **Resolvido** (F4): FundosVivos |
| D13 | Distrito industrial inteiro no kit antigo (177 de 177 lotes no raio 12), porta de entrar escondida em 19 chunks. | `KitModular.fachada` | **Resolvido** (F4): IndustriaViva |
| D14 | Terreno da quadra atravessando a casa e aparecendo no cômodo da janela aberta (metade dos lotes com canto mais de 30 cm acima do piso). | chão `terra` e `grama` sob o lote rígido | **Resolvido**: RebaixoDoLote |
| D15 | Cidade de laje: telha em 8,7% dos lotes, caimento de 22%, telha chapada em xadrez, cachorrada solta sob a água, comércio só platibanda. | `KitPredio.telhado`, remates | **Resolvido** (F6): TelhadoVivo |
| D16 | Miolo de quadra em caixas de concreto sobrepostas (33 pares) e entortadas pelo relevo. | `ChunkBuilder._anexos` | **Resolvido** (F6): MioloVivo |

## 2. O que foi feito (F1 e F2)

Arquivos novos (nenhum arquivo compartilhado foi reescrito; os ganchos são poucos e comentados):

- **`src/world/parede_vazada.gd` (ParedeVazada):** fachada com vãos de verdade.
  - A parede é montada em faixas costuradas em ziguezague, sem junta em T.
  - Cada vão tem ombreira, verga (reta ou em arco abatido), peitoril ou soleira, e tampa escura.
  - Aceita bandas de outra cor ou material na mesma grade: barrado, azulejo, tijolo aparente.
  - Régua: `tests/bancada_parede_vazada.gd` (raio em todo ângulo, juntas em T, controle positivo).
- **`src/world/janela_viva.gd` (JanelaViva):** o que vai no vão.
  - Modelos: guilhotina com folha de madeira, veneziana com palheta, correr de alumínio, vitrô basculante.
  - Estados: fechada, entreaberta, aberta.
  - A janela aberta monta o **cômodo** (sala, quarto ou cozinha), com parede interna iluminada pelo material `interior`, móvel, quadro, filtro de barro, cortina que o vento mexe, e lâmpada acesa.
  - Mais: floreira de gerânio ou lavanda, vaso de barro no peitoril, samambaia pendurada, grade reta ou de losango, peitoril de pedra.
  - O estado sai do estilo da casa e do **morador**: zelosa, família, idoso, jovem, fechada, abandonada.
  - Régua: `tests/bancada_janela_viva.gd`.
- **`src/world/fachada_viva.gd` (FachadaViva):** a casa por tipologia.
  - **colonial:** caiada, barrado, cunhal, cercadura, folha azul, verde ou sangue-de-boi, cachorrada no beiral.
  - **eclético:** platibanda com frontão e compoteira, sobreverga, balcão de ferro.
  - **moderno:** janela larga, faixa de azulejo, garagem, beiral fino.
  - **popular:** reboco cru ou pintura lavada, andar de tijolo aparente, vergalhão de espera, caixa d'água azul.
  - Vida na porta: número, lampião ou medidor CEMIG com caixa de correio, vaso de espada-de-são-jorge, buganvília subindo na porta, pichação e mato na abandonada.
- **`src/world/comercio_vivo.gd` (ComercioVivo):** a rua comercial.
  - Três tipos: sobrado com loja embaixo, loja de marquise, prédio de 3 a 5 andares.
  - A porta de enrolar tem três estados: fechada, meio aberta e aberta. A loja aberta mostra prateleira cheia, balcão e lâmpada tubular.
  - Mais: vitrine de alumínio com porta de vidro, armazém de duas folhas, portaria do prédio, ar-condicionado.
- **`src/world/obra.gd` (Obra):** canteiro de geometria que junta as peças por material e despeja uma vez por fachada. Motivo: `PSXMesh.acumular` copia o balde inteiro a cada peça, porque o PackedArray é copiado na escrita. Com o canteiro, o custo do chunk comercial caiu de 48,6 para 24,8 ms.
- **Materiais novos**, na tabela de `tools/gerar_materiais.py` e na política de chuva do EstiloVisual: `metal_pintado`, `cortina` (com vento), `lampada`, `interior`, `interior_aceso`, `interior_madeira`.
- **ChunkManager:** o balde `material@perto` é cortado a 40 m (`ALCANCE_PERTO`). Nele vão móvel, flor, cortina e miudeza.
- **Ganchos em `ChunkBuilder._fileira`:**
  - `planejar` antes da massa;
  - `residencia` ou `fachada` no lugar do kit antigo;
  - `coroar` do plano;
  - o `porta_local` corrigido (D2).
- `--sem-fachada-viva` volta ao caminho antigo, para comparar.
- `--janelas-abertas` abre toda janela, para fotografar os cômodos.

### Custo medido (headless, máquina com outras sessões rodando)

| Chunk | construir (média / pior) | triângulos (média / pior) | dos quais `@perto` |
|---|---|---|---|
| Residencial, antes | 18,1 / 25,5 ms | 3.750 / 5.303 | 0 |
| Residencial, agora | 21,4 / 27,5 ms | 6.671 / 9.059 | 1.296 |
| Comercial, antes | 16,4 / 25,0 ms | 3.730 / 4.459 | 0 |
| Comercial, agora | 24,8 / 31,5 ms | 10.583 / 15.161 | 2.119 |

O teto de 6.000 triângulos por chunk (ART-BIBLE §10) é da era PS1. O pedido foi "qualidade e otimização acima da estética PSX forçada", e o custo da GPU se confere na bateria de streaming (quadro em regime).

## 2b. F4 e F5-A: os quatro lados da casa, a rua de serviço e a ladeira (22/09)

Levantamento antes de mexer: seis frentes (fundos, esquina, miolo, indústria, ladeira,
telhados), 60 fotos e medidas em raio de 12 chunks da praça. Fotos em
`scratchpad/f4/<frente>/`, as de depois nas mesmas poses em `scratchpad/depois/`.

- **`src/world/fundos_vivos.gd` (FundosVivos):**
  - `fundo`: a parede de trás no mesmo material e cor do corpo (ou tijolo e reboco cru,
    que é como o fundo fica), com vão de verdade. Porta da cozinha de ferro com vidro
    canelado, de tábua (às vezes a holandesa com a de cima aberta), telhadinho de telha
    ou laje, botijão; janela da cozinha, vitrô canelado do banheiro, cobogó da área,
    quarto; varal de janela no prédio; cano e calha sob o beiral, ou buzinote com o
    escorrido na laje; condensador de ar. Vergas numa linha só (2,3 m).
  - Na ladeira, a porta da cozinha sobe com o quintal ou ganha a escadinha de cimento
    com corrimão (28% das portas flutuavam, 35% ficavam enterradas).
  - Fundo tapado pela fileira perpendicular (15%) sai só com a parede.
  - `lateral`: a lateral de esquina é fachada. As mesmas faixas (o barrado dobra a
    quina), a mesma esquadria, frisos e cimalha que dobram a quina, cunhal em L; na
    loja, a segunda porta de aço ou o nome pintado na parede cega; no galpão, vitrô alto.
    Janela nunca abaixo da calçada da transversal.
  - `quintal`: puxadinho de tijolo ou reboco com oitão até a meia-água (a cunha aberta
    sumiu), ou telheiro de pilar; tanque e máquina de lavar debaixo dele; varal,
    churrasqueira de tijolo, casinha de cachorro, mesa de plástico, vasos no muro,
    horta; no comércio, tambor e engradado.
- **`src/world/industria_viva.gd` (IndustriaViva):** galpão (arco de chapa com a
  platibanda curva, oitão para a rua, shed, laje), oficina com o vão aberto e a casa do
  dono em cima, depósito com pátio murado e portão gradeado (baias de areia e brita,
  tijolo, cimento no pallet, caco de vidro no muro), armazém de café e cerealista em
  tijolo com porta em arco e sacaria, fábrica com portaria e fita de vitrôs. Portão de
  correr fechado ou corrido para o lado com o galpão aparecendo; lanternim e exaustor;
  pneu, grade pronta e tábua encostados na parede; nome da firma pintado do atlas
  `letreiros_industria.png` (16 firmas inventadas em `tools/gerar_letreiros.py`).
- **Ladeira (F5-A), em `ChunkBuilder._fileira`:** a base do lote é o ponto ALTO da
  frente (`_altura_do_lote`; na esquina, também o canto de trás da lateral). No lote da
  porta interativa continua o chão na folha. O perfil do chão ao longo da fachada vai
  para o plano: escada na porta (de encosto, rente à parede, acima de três degraus),
  degrau de pedra na loja (a loja com a calçada mais de 75 cm abaixo não sai), rampa no
  portão; garagem e portão de galpão vão para onde a calçada encontra o piso.
- **`src/world/rebaixo_do_lote.gd` (RebaixoDoLote):** o chão da quadra desce sob a casa,
  sem junta em T (aresta por posição, vizinho em leque). `--sem-rebaixo` desliga.
- **Capa do embasamento** (`ChunkBuilder._capa_do_embasamento`): a caixa de pedra não
  tinha face de cima, e na quina se via o vazio dentro dela (bancada_quinas, -1,-2).
- Materiais novos na tabela: `vidro_canelado`, `letreiro_industria`.

### Custo e réguas depois da F4 (raio 7 da praça)

| Chunk | construir (média / pior) | triângulos (média / pior) |
|---|---|---|
| Residencial | 30,8 / 40,8 ms | 9.813 / 14.963 |
| Comercial | 35,8 / 52,6 ms | 14.342 / 24.455 |
| Industrial | 20,8 / 31,3 ms | 5.797 / 9.036 |

Streaming em par, alternando com `--sem-fachada-viva`: 326 mil triângulos na tela
contra 147 mil, e pior quadro de 7,7 e 12,1 ms contra 12,0 e 18,8 ms da cidade antiga
(teto 90). O teto por chunk em `tools/verificar_cidade.py` foi a 26.000.

Réguas: quinas 48/0; frestas 365 poses, 0 no MODERNO e 1 no PS1 (pose 387, os mesmos
três pixels de meio-fio da foto da sessão anterior: fresta antiga, fica aberta);
parede vazada e janela viva OK; pátio 1 boca (a do mercado, antiga); relevo, rota,
ameaça, trânsito, streaming, bar, casa, mercado e carro OK. A cidade só falha nas 4
portas do mercado (antiga) e a suíte nas 11 de outras frentes.

## 2c. F6: telhado mineiro e miolo de quadra (22/09)

Antes, pelo levantamento da F4: telha em 8,7% dos lotes, caimento de 22%, laje de
10 cm com textura em xadrez, beira e cumeeira retas, sem forro, cachorrada solta
sob a água, e o miolo de quadra em caixas de concreto sobrepostas. Fotos de antes
em `scratchpad/f6/antes/` (as oito poses de telhado do levantamento, com a cidade
da F4), depois em `scratchpad/f6/depois/`.

- **`src/world/telhado_vivo.gd` (TelhadoVivo):**
  - `planejar(plano)`: decide depois de FachadaViva/ComercioVivo, com sorteio
    próprio pela semente, sem mexer no gerador do chunk. Colonial em
    capa-e-canal; moderno em capa-e-canal ou francesa; platibanda do eclético e
    do comércio escondendo duas águas (francesa, capa-e-canal) ou meia-água de
    fibrocimento; metade da autoconstrução com a laje coberta de fibrocimento em
    pilaretes de tijolo.
  - A água passa rente ao topo da parede (acima da cimalha, que sai 20 cm) e
    desce até a ponta do beiral. Água plana subdividida sempre desenhada; de
    perto (balde `@perto`), a onda de capa-e-canal ou francesa com o perfil de
    verdade, alinhada às colunas da textura: a beira sai recortada.
  - Quatro águas na quina (água no lugar da empena do lado da rua transversal),
    espigão e cumeeira de capa com a argamassa dos dois lados; empena de
    alvenaria no lado da divisa, com a capa argamassada no oitão.
  - Beiral: forro de tabuado pintado, forro liso (moderno), ou telha vã com a
    cachorrada presa na face de baixo da água; beira-seveira caiada de 2 ou 3
    fiadas pelo morador ("eira e beira"). Frechal fechando parede e água.
  - Em cima: chaminé do fogão a lenha, antena espinha-de-peixe, mini-parabólica
    na parede, parabólica de tela, caixa d'água castelinho, aquecedor solar na
    água do norte, lona azul com pedra na casa pobre, mato na calha da abandonada.
  - `beiral_de_tras(plano)`: a calha e o cano da FundosVivos vão para a ponta do
    beiral de trás, e o puxadinho e o telheiro baixam para caber debaixo dela.
  - `--sem-telhado-vivo` volta ao KitPredio.telhado e ao `_anexos`.
- **`src/world/miolo_vivo.gd` (MioloVivo):** o chunk de miolo de quadra no lugar de
  `_anexos`. Edícula (tijolo ou reboco, porta, janela, degrau), galpão de fundo
  (portão de tábua, fibrocimento ou barro), galinheiro (mureta, pilares,
  meia-água), pomar, canteiros de horta e capim. Sem sobreposição, rígido na
  altura do canto mais alto, embasamento de pedra até o mais baixo, telhado do
  TelhadoVivo (quatro águas quando cabe).
- **Textura:** `tools/gerar_fachada_hd.py` refaz a capa-e-canal (canal contínuo,
  fiada de 40 cm, peça sorteada sem o xadrez, limo mais no canal) e cria a telha
  francesa (Marselha), nos dois conjuntos (256 e 1024). Material novo na tabela:
  `telha_francesa`.

### Custo e réguas depois da F6 (raio 7 da praça, em par com `--sem-telhado-vivo`)

| Chunk | construir (média / pior) | triângulos (média / pior) | antes da F6 |
|---|---|---|---|
| Casas | 32,0 / 47,4 ms | 12.294 / 19.924 | 9.813 / 14.963 |
| Comercial | 35,2 / 51,6 ms | 14.483 / 24.525 | 14.342 / 24.455 |
| Industrial | 20,6 / 28,1 ms | 6.226 / 9.036 | 5.796 / 9.036 |

Telha à vista em 69% das casas (aparente 43%, laje coberta 14%, escondida 11%) e
em 52% do comércio (atrás da platibanda). Streaming em par: pior quadro de 5,7 e
6,9 ms contra 5,4 e 4,5 ms sem a F6 (teto 90), 352 mil triângulos na tela contra
331 mil. Réguas: quinas 48/0, frestas 365/0 (MODERNO), relevo, rota, ameaça,
trânsito, streaming, bar, casa e carro OK; pátio com a boca antiga do mercado; a
cidade só com as portas do mercado. `verificar_mercado` falha 4 critérios do
interior da loja (superfícies dos fundos), igual com e sem a F6: trabalho em
andamento da sessão do mercado.

## 2d. Serpentina redonda, casa da curva no sistema novo e vegetação (22/09)

Três pedidos do usuário, na ordem em que vieram:

- **Rua pontiaguda.** A serpentina passava um Catmull-Rom PELOS cantos do
  traçado: raio mínimo de 1,0 a 1,5 m nas 20 serpentinas, 3 a 4 cotovelos cada, e
  a calçada (4,6 m do eixo) dobrava em espinho. Agora cada canto é um arco de
  círculo tangente às duas retas (`Serpentina._arredondar`, raio 16 m, 15 m na
  boca), e a última perna dobra em ângulo reto para a saída em vez de voltar em
  diagonal (grampo de quase 180°). Medido: raio mínimo de 14,8 m em todas.
  - Primeira e última perna 4 m mais para dentro (`BORDA + 16`).
  - `ENTRADA` de 20 m para 18 m: o suficiente para atravessar fileira e quintal.
- **Casa com o topo de outra cor e porta inacessível.** A casa da serpentina
  estava no kit antigo:
  - lateral em `concreto_sujo` e empena em reboco clareado;
  - porta da cozinha a quase 1 m do quintal, sem degrau.
  Agora ela sai pela FachadaViva, pelo TelhadoVivo (três em cinco com quatro
  águas, por ser casa solta) e pelo FundosVivos. O FundosVivos ganhou `xf`,
  para medir o quintal no espaço da casa girada, e com isso a escadinha com
  corrimão até o chão. O botijão pousa no chão do quintal. A empena do
  `KitPredio.telhado`, que sobra na casa da fumaça e no bar, usa o material e a
  cor do corpo.
- **Pouca vegetação.** Módulo novo `Vegetacao`. Copa de cartão cruzado sobre um
  elipsoide, com normal esférica por vértice, sombra na cor de vértice e o
  mesmo vento da casca. Atlas desenhado em `tools/gerar_vegetacao.py` (16
  células), material `vegetacao`, e `casca_palmeira` para o estipe da imperial.
  Espécies e plantas:
  - mangueira, oiti, abacateiro, jaqueira, sibipiruna, ipê amarelo e ipê rosa;
  - palmeira imperial e coqueiro;
  - bananeira, bambu, arbusto, primavera, touceira de colonião e capão de mata.

  Onde entrou:

  | Onde | O que planta |
  |---|---|
  | Calçada de rua | oiti, com ipê |
  | Avenida | sibipiruna, ipê e fileiras de imperial, por quadra |
  | Quintal | árvore em 55% dos fundos, bananeira, primavera no muro |
  | Miolo de quadra | árvore, bananeira, coqueiro, bambu |
  | Pasto da serpentina | capão de mata por zona de grota, árvore solta, bananeira, colonião |
  | Baldio | colonião, moita, bananeira, árvore |

  `--sem-vegetacao` volta à árvore de caixa.

Custo medido em par (56 chunks de bairro e serpentina):

| | triângulos por chunk (média / pior) | construir (média / pior) |
|---|---|---|
| Com vegetação | 11.120 / 19.965 | 33,2 / 66,9 ms |
| `--sem-vegetacao` | 10.932 / 20.003 | 33,4 / 68,5 ms |

Streaming em par: o pior quadro foi de 6,3 e 7,2 ms com vegetação e de 8,3 e
7,3 ms sem ela. Na tela, 367,5 mil triângulos contra 366,1 mil.

Falta na vegetação:
- a praça e o parque (domínio da sessão da praça: combinar);
- o miolo e o jardim do `FundosBuilder` (arquivo com trabalho em andamento do
  mercado);
- a serra do horizonte, que é silhueta lisa e pediria mata em textura;
- a trepadeira de muro (célula `hera` pronta, sem uso).

## 2e. Todo bar com o salão do Seu Zé (22/09)

**Pedido:** o usuário achou bares de interior vazio. Eram lojas da ComercioVivo
que sorteavam a placa "BAR DO TIÃO" (célula 3 do `letreiros.png`), com o salão
de mercearia atrás da porta de enrolar. Ele quer todo bar com o interior do Seu
Zé e só a cor, o nome e a letra da placa mudando.

**O que mudou:**
- `BarVivo` (novo) escolhe um lote comercial em cada quatro chunks. O lote
  precisa ter 6,5 m ou mais, não ser esquina nem lote da porta interativa, e o
  chunk não pode ser o do Seu Zé, do mercado, da casa da fumaça nem da célula
  ancorada da praça. Esse lote vira `ChunkBuilder._predio_do_bar`: o mesmo térreo
  vazado, com balcão, cervejeira, sinuca, TV, gente, telefone de salvar e mesas
  na calçada.
- O `estilo` escolhe:
  - a parede, entre oito cores, nunca o amarelo do Seu Zé;
  - a tinta do azulejo;
  - o toldo, com listra vermelha, verde, azul ou laranja;
  - a cor da cadeira de plástico;
  - a placa, em 16 nomes de boteco mineiro com fonte, fundo e segunda linha
    próprios (atlas `bares_nomes`, `tools/gerar_bar_variantes.py`).
  O nome anda com a coordenada, para dois bares vizinhos não repetirem.
- O KitBar ganhou `estilo` opcional em `frente`, `toldo`, `letreiro`,
  `mesas_da_calcada`, `salao` e `cadeira`. Sem ele o Seu Zé sai igual ao de antes.
- A placa "BAR DO TIÃO" das lojas virou "CASA DE RAÇÃO / AGROPECUÁRIA".
- A máquina de venda não para mais na boca de bar. A árvore nova mudou o
  sorteio do chunk, e a máquina tinha caído na frente do Seu Zé em (-9,9).

**Na janela de 16 × 20 chunks em volta da origem:** 11 bares novos, além do Seu
Zé. O mesmo nome só se repete longe.

**Falta:** o bar novo não aparece no mapa. Só o Seu Zé é ponto de interesse,
porque a posição dele sai sem montar o chunk.

## 2f. Lojas de verdade no lugar das lojas de casca (22/09)

**Pedido:** o usuário achou muitas lojas de portão aberto sem nada dentro, como os
bares antes da 2e, e muitas outras propriedades sem interior nem interação. Ele
pediu:
- menos lojas;
- cada loja com um interior polido, coerente com a placa;
- clientes, funcionários e interação.

**Censo antes**, na janela de 16 × 20 chunks em volta da origem:
- 241 lojas abertas sem nada atrás e 70 fechadas com placa, todas da
  ComercioVivo. Atrás da porta havia uma casca de 3 a 4 m, colada à parede do
  prédio.
- 66 oficinas abertas ou meio abertas da IndustriaViva, com a mesma casca.
- 12 lugares de verdade: o Seu Zé e os 11 bares.

**O que mudou:**
- A fachada comercial (`ComercioVivo`) não abre mais loja de casca. O vão que era
  loja vira porta de aço fechada, sem placa, em 45% dos casos; nos outros, vira a
  janela de grade da casa, com peitoril a 1 m. Placa e testeira só existem onde há
  loja. A lateral de esquina segue a mesma regra (`FundosVivos.lateral`).
- A oficina, o galpão e o armazém da rua de serviço ficam fechados, e a venda da
  esquina chanfrada também. O sorteio continua igual; só o estado muda.
- A loja de verdade vem de `LojaViva` (novo):
  - **Onde:** uma por chunk comercial elegível. O chunk não pode ser o de bar,
    mercado, casa da fumaça nem a célula da praça. O lote tem de ter 5,6 m ou
    mais, não ser esquina nem lote de porta. A frente pode variar até 0,9 m de
    altura na ladeira, e a boca não pode ter árvore de calçada nem poste na frente.
  - **O ramo** é a célula da placa no `letreiros.png`, então a placa e o salão são
    a mesma escolha.
  - **Os 16 ramos** e o que cada um tem:
    - padaria, farmácia, armarinho e ótica: balcão de vidro;
    - ração, mercearia, material de construção, sapataria e bazar: planta livre
      com caixa, ilha de gôndola ou pilha de sacaria;
    - lotérica: guichê de vidro;
    - salão de beleza: cadeiras e espelho;
    - açougue: balcão frigorífico e varal de linguiça;
    - papelaria: xerox;
    - lanchonete: chapa, coifa e banquetas;
    - borracharia: pneu empilhado e compressor;
    - relojoaria: relógios de parede.
- O salão é de `KitLoja` (novo), no térreo vazado do próprio prédio (a massa
  começa no primeiro andar):
  - piso rente à calçada na boca;
  - paredes, forro e o lado de dentro da frente, tudo com colisão;
  - prateleiras em que cada tábua é um cartão recortado do atlas `loja_produtos`
    (32 células, `tools/gerar_lojas.py`);
  - cartaz do ramo e calendário da santa;
  - duas calhas de lâmpada tubular e duas luzes dinâmicas;
  - ventilador de teto nas lojas quentes;
  - na calçada, o cavalete de giz, a sacaria ou a pilha de pneus.
- A fachada da loja é a porta de aço toda enrolada ou a vitrine com a porta de
  vidro aberta. O vidro é o `vitrine_loja` da loja de conveniência, transparente
  de perto e aceso de longe. O `vitrine` é azulejo pintado de loja, feito para
  casca.
- **Gente:**
  - A equipe tem de 1 a 2 pessoas por ramo, com profissão e rótulo próprios
    ("Falar com a balconista").
  - Os clientes são de 1 a 3 e andam entre as prateleiras. Na lanchonete e no
    salão, os clientes sentam na banqueta, na cadeira e no sofá, com a postura
    `ASSENTO` (`Convidado.altura_assento`).
- **Conversa:** com quem atende, o contexto `loja` troca a lista da rua pela do
  balcão (`VendaDaLoja.opcoes`, fora do `LojaViva` para o `ChunkBuilder` não
  carregar autoload):
  - "O QUE TEM DE BOM AI?", com resposta pelo tom da pessoa;
  - a compra, que cobra no `Dinheiro` e põe o item na mochila;
  - o serviço do ramo:
    - a fezinha da lotérica sorteia prêmio de R$ 50 ou R$ 500;
    - a relojoaria diz a hora do relógio da cidade;
    - a farmácia mede a pressão e devolve vida;
    - corte, graxa e botão cobram.
  - Seis itens novos de comida, com ícone: pão de queijo, cafezinho, coxinha,
    guaraná, torresmo e rapadura.
- O cômodo atrás da janela do primeiro andar não desce mais abaixo do piso do
  andar (`piso_em`, JanelaViva). Com o térreo oco, ele aparecia abaixo do forro
  da loja.
- `ChunkBuilder.construir` devolve `lojas` (ramo, boca, normal e largura), para o
  teste e para o mapa.

**Censo depois**, na mesma janela:
- 22 lojas de 12 ramos, com 35 pessoas trabalhando e 39 clientes;
- nenhuma placa de loja em chunk sem loja;
- 11 bares, que continuam.

**Custo**, medido no mesmo chunk com a loja e com `--sem-loja-viva`, porque a
comparação entre chunks diferentes enganava: de −658 a +1.448 triângulos. As
cascas removidas pagam o salão. O pior chunk de loja tem 22.555 triângulos (o
teto do chunk de bar é 24.000).

**Régua:** `tools/verificar_lojas.py` (`--teste-loja`), com 25 a 27 medidas:
- na cidade: nenhuma placa sem loja, 15 lojas ou mais, 8 ramos ou mais, e equipe,
  cliente e produto em toda loja;
- no lugar: a calçada entra no salão sem obstáculo e sem degrau, sem carregar
  interior;
- na venda: falar com o atendente abre a lista da loja, e a compra cobra o preço
  e põe o item na mochila.

**Falta:**
- A loja não aparece no mapa.
- A loja não fecha à noite.
- Borracharia e oficina de verdade na rua de serviço.
- Ramos que não caíram na janela do censo (relojoaria, bazar, borracharia e
  ração) existem em outros pontos da cidade, mas ainda não foram fotografados.

## 3. Próximas fases

- **F3. Letreiro com nome: feito.**
  - Atlas `letreiros.png` (256 px no PS1, 1024 px no MODERNO) com 16 lojas inventadas de cidade mineira, gerado por `tools/gerar_letreiros.py`. É conteúdo trocável: para nomes reais, edite a lista ou substitua os PNG.
  - Falta a luz do letreiro à noite.
- **F4. Fundos e laterais: feito** (acima). Falta:
  - Miolo de quadra: os galpões-caixa sobrepostos de `_anexos` (33 pares em 26 chunks)
    e o capim chapado; edícula, pomar, horta, pátio de galpão.
  - Empena cega entre vizinhos de alturas diferentes (60% dos pares, 23 mil m²): rufo,
    mancha, tijolo sem reboco.
  - Bar e casa da fumaça ainda no kit antigo; o beco (lixo em cubo preto, verga solta,
    casinha da vila atravessando a casa da esquina em 3 de 19 becos).
- **F5. Ladeira:**
  - Base no ponto alto com escada, degrau e rampa: **feito** (F5-A).
  - Porão progressivo em toda face exposta (gateira, janela de porão, porta em arco),
    hoje só com mais de 2,4 m e só no fundo; arremate de divisa entre vizinhos.
  - Esquina chanfrada de volta na ladeira (D11) e com a fachada nova.
- **F6. Telhado mineiro: feito** (acima), com o miolo de quadra da F4. Falta:
  - O remendo de telha nova, a telha quebrada da abandonada, gato e pombo.
  - Fumaça da chaminé de manhã e no fim da tarde (liga no ciclo do dia, F8).
  - Casario e Matriz da praça ainda no material `teto` (domínio da sessão da
    praça e da igreja: combinar antes de trocar).
- **F7. Desgaste no shader do MODERNO:** umidade no pé da parede, escorrido sob o peitoril, macrovariação de tom (UV2 já sai da ParedeVazada).
- **F8. Noite:**
  - Conferir a janela e o cômodo acesos à noite, e o lampião.
  - Luz de TV azulada em parte das salas.
- **F9. Bancada de casas:** fotografar N lotes por tipologia em três vistas e conferir o checklist (porta alinhada, vão recuado, sem coplanar, diversidade entre vizinhas).

# PLANO MERCADO AAA — o mercadinho existe, vive e trabalha

> Mapa medido do estado atual + plano de desenvolvimento para o Mercadinho
> HIKARI deixar de ser um cômodo teleportado com prateleira pintada e virar uma
> loja de conveniência de verdade: na rua, com produto na prateleira, freguês
> que entra, enche a cesta e paga, e um turno da noite jogável.
> Versão 1.0 — 21/09/2026 — branch `playable`
> Referência pedida: *Shift At Midnight* (Bun Muen, 22/07/2026).
> Precedente direto: [PLANO_CASA_FUMACA_V2.md](PLANO_CASA_FUMACA_V2.md), cuja F6
> já listava o mercado como a última porta a migrar para a rua.

---

## 0. O pedido, e como ele foi lido

O pedido, nas palavras dele:

1. **Clientes entram.** A porta de correr abre e **dá para ver dentro do
   lugar** — sem tela preta e sem teletransporte. O mercado existe no lugar.
2. **O cliente entra, pega produto e põe na cesta**, tudo bem mapeado.
3. O mercado foi inspirado no *Shift At Midnight* e "ficou bem fraco": falta
   bastante coisa. Melhoria profunda, nível AAA.
4. Passar por cada ponto como engenheiro de jogos AAA e trazer as melhorias
   óbvias e as geniais que vão além do pedido.

A leitura: o item 1 é a mesma lição do Bar do Seu Zé e da casa da fumaça
(memória `lugar-de-rua-nao-e-interior`) — o problema nunca foi a porta, é o
lugar não existir na rua. O item 2 exige que **produto seja coisa**, não
textura: hoje não há um único produto individual na loja. O item 3 pede um
**laço de jogo** que hoje não existe (não há dinheiro, preço, turno nem
julgamento). Este plano ataca os três nessa ordem, porque cada um depende do
anterior.

---

## 1. O que existe hoje (medido)

### 1.1 Capturas desta sessão

Em `captures/mercado_aaa/antes/`, 960×540, noite, preset do `settings.cfg` do
usuário:

| Captura | O que mostra |
|---|---|
| `01_fachada` | A vitrine é uma **textura opaca e emissiva** (`mercado_vidro`) com prateleira desenhada. Atrás dela há o bloco maciço do prédio |
| `02_salao` | Gôndolas com a **frente pintada**. Uma cliente anda no corredor |
| `03_caixa`, `04_balcao` | O balcão (tampo de madeira, corpo de pedra escura). Os quadros do `CENAS_MERCADO` saem baixos demais |
| `05_cliente_30s`, `06_cliente_60s` | **A cliente está parada no mesmo pixel aos 30 s e aos 60 s**, no corredor da ilha 1. Nunca chega ao caixa |

### 1.2 Estado, defeito por defeito

| Aspecto | Hoje | Onde |
|---|---|---|
| **Entrada** | A porta de vidro chama `Interiores.entrar`: cortina preta de 0,22 s, cômodo montado em `(0, 2000, 0)`, cidade escondida, jogador teleportado | [porta.gd](game/src/world/porta.gd) `_entrar`, [interiores.gd](game/src/systems/interiores.gd) `_materializar` |
| **Vitrine da rua** | Placa `mercado_vidro` opaca; nada atrás | [kit_mercado.gd:373](game/src/world/kit_mercado.gd#L373) |
| **Planta × fachada** | Planta de 19 × 13 m; fachada de 6,4 m na rua. O portão da garagem fica a 5,2 m da porta na calçada e a 9,5 m na planta. O próprio código admite: "interior e fachada nunca coincidiram" | [kit_mercado.gd:437-448](game/src/world/kit_mercado.gd#L437-L448) |
| **Produto** | Três texturas de prateleira (`mercado_prateleira_0..2`) coladas como placa na frente de uma caixa lisa. **Zero produtos individuais** | [kit_mercado.gd:80-95](game/src/world/kit_mercado.gd#L80-L95) |
| **O que se pega** | 4 ou 5 itens de jogo soltos (bandagem ×2, bateria, remédio, munição 9 mm em 50% das lojas). **De graça** | [mercado_builder.gd:817-837](game/src/world/mercado_builder.gd#L817-L837) |
| **Cliente** | Um `Convidado` com rotina `compra`: dois pontos fixos (gôndola, caixa), linha reta, sem navegação. Na mão, uma caixinha sem luz de 9 × 12 × 7 cm, vermelha ou amarela; no balcão aparece uma segunda, azul. **Travado no corredor** (capturas 05/06). A abertura e o teste pulam o trajeto com `ir_ao_caixa()`, que teleporta | [mercado_builder.gd:856-870](game/src/world/mercado_builder.gd#L856-L870), [convidado.gd](game/src/world/convidado.gd) `_avancar_compra`, `ir_ao_caixa` |
| **Cesta** | Pilha estática de 5 caixas coloridas na entrada. Ninguém usa | [kit_mercado.gd:276-285](game/src/world/kit_mercado.gd#L276-L285) |
| **Atendente** | Parado atrás do balcão. Não passa produto, não recebe, não repõe | `_gente` |
| **Conferência** | Carteira → `Documento` → leitor (3 piscadas vermelhas) → câmera vira → `Terminal` na ficha. **Nada é julgado.** A validade nunca é conferida; a situação `FALECIDO`/`SUSPENSO` existe e nenhum laço usa | `Interiores._atendimento`, `_passar_no_leitor`; [registro_civil.gd](game/src/systems/registro_civil.gd) `identidade` |
| **Dinheiro** | Não existe: nenhum preço, compra, troco ou furto. A abertura promete: "Tenho uns quarenta reais no bolso. / E tô morrendo de fome." | [abertura.gd:353-354](game/src/levels/abertura.gd#L353-L354) |
| **Emprego** | `Profissoes` tem um cargo só (fazendeiro), e é o jogador quem contrata. Nenhum turno, expediente ou horário como sistema | [profissoes.gd](game/src/systems/profissoes.gd) |
| **Som** | A loja não tem `som_ambiente`: sem geladeira, sem zumbido de reator, sem rádio. Existem `porta_desliza` e `bipe_curto` | `AudioDirector` |
| **Luz** | 13 `Lampada`, malha **fundida por material da planta inteira** (toda luz toca tudo). Limite de 24 por objeto no Compatibility; o comentário de `LUZES_AVULSAS_DO_MERCADO` ainda diz 16 | [interiores.gd](game/src/systems/interiores.gd) topo, [project.godot:219](game/project.godot#L219) |
| **Variedade** | ~12 lojas num raio de 12 chunks, **todas a mesma planta**. A semente só troca gente e estoque | [chunk_builder.gd](game/src/world/chunk_builder.gd) `_porta_do_chunk` |
| **Abertura** | **O plano 04 filma a garagem.** A câmera aponta para o layout antigo de 11 × 9 m; a captura versionada mostra paletes e o portão enrolado, sem balcão | [abertura.gd:233-239](game/src/levels/abertura.gd#L233-L239), [04_mercado.png](game/captures/abertura/04_mercado.png) |
| **Teste** | `TesteMercado` chama `Interiores.entrar` na mão, igual ao bar da primeira versão (29 medidas verdes com teleporte) | [teste_mercado.gd:30](game/src/levels/teste_mercado.gd#L30) |
| **Save** | O telefone da loja grava a posição a 2000 m de altura; `carregar` e `Desmaio._levar` não reentram no cômodo. *Lido no código, não testado* | [save_game.gd](game/src/systems/save_game.gd), [desmaio.gd](game/src/systems/desmaio.gd) |

### 1.3 O que já existe e sustenta o plano

Quase toda a infraestrutura que o mercado precisa já foi construída para
outra frente:

| Peça | O que dá | Onde |
|---|---|---|
| `InteriorNoMundo` | Três degraus (casca, pré-aquecida a 32 m, ativa a 9 m), soleira que mistura névoa e ambiente (`FogPreset.misturar`), luz isolada na camada 11, `TetoChuva`, sonda de reflexo própria | [interior_no_mundo.gd](game/src/world/interior_no_mundo.gd) |
| `CasaViva` | Malha de navegação de 8 cm assada da colisão do lote, `NavigationAgent3D` com RVO, usos com reserva, antitravamento (`presos=0` em 4 min), reação ao jogador | [casa_viva.gd](game/src/world/casa_viva.gd) (não rastreado) |
| `Corpo` | 11 ossos a 15 poses/s; posturas LIVRE, SENTADO, CONTROLE, FUMANDO, ENCOSTADO, TRABALHANDO, ASSENTO, DANCANDO; `olhar_lateral`, `falar`, `rir`; mão por `BoneAttachment3D` | [corpo.gd](game/src/render/corpo.gd) |
| `RegistroCivil` | Ficha pura da semente: CPF com dígito verificador real, RG, nascimento, validade, situação, profissão, endereço, aparência → `Retrato`. `Terminal` de 1998 com busca por nome e vínculos; `Documento` | [registro_civil.gd](game/src/systems/registro_civil.gd), [terminal.gd](game/src/ui/terminal.gd) |
| Pedestre / Multidão | Grafo de calçada; `EntregasDaSuper` já **sequestra um pedestre vivo** e o devolve — precedente do freguês que vem da rua | [entregas_da_super.gd](game/src/world/entregas_da_super.gd) |
| Tempo e ameaça | `Relogio` (22:43 → 05:00 a 2×), `Lampada` com padrões e sinais `apagou`/`acendeu`, `Radio` que chia com a proximidade, `Inimigo` desligado na rua **esperando contexto** | [relogio.gd](game/src/systems/relogio.gd), [lampada.gd](game/src/world/lampada.gd), [inimigo.gd](game/src/world/inimigo.gd) |
| Shaders prontos | Vidro molhado e gota corredora do para-brisa, tela CRT, fumaça | `psx_vidro_agua`, `psx_gota_corredora`, `tela_crt`, `psx_fumaca` |
| Mobília | `KitMovel` com PBR do ambientCG | casa da fumaça F3 |

### 1.4 Números de partida

| Medida | Valor |
|---|---|
| Planta atual | 19,0 × 13,0 m, 7 cômodos, 3 ilhas de 6 m, corredores de 1,64 m |
| Lâmpadas na loja | 13 + luz do leitor + luz do save = 15 |
| Props materializados | ~27, um por quadro (~0,45 s) |
| Faixa de triângulos aceita pelo verificador | 3.000 – 26.000 (sem medida registrada) |
| Orçamento do chunk | 6.000 triângulos (`verificar_cidade.py`); o bar tem teto próprio de 9.500 por decisão sua |
| Lojas na cidade | 1 a cada 4 portas de quadra de conveniência; ~12 num raio de 12 chunks |

---

## 2. A referência: o que o *Shift At Midnight* faz, e como vira nosso

O jogo: turno da noite num posto de gasolina dos anos 90. Entre um freguês e
outro, o jogador repõe prateleira com cota, recebe entrega, limpa sujeira e
abastece carro. No caixa ele confere documento, cruza com o banco de dados,
pergunta profissão e compara com o que a ficha diz. Os sósias erram em
detalhe: dado pessoal (inclusive **estar morto** no registro), profissão,
**hábito de compra** que não bate com a descrição, aparência, comportamento,
placa do carro. Deixar um passar faz a coisa voltar no fim do turno, e aí é
tábua na porta, armadilha e esconderijo. São 13 turnos gerados.

| Lá | Aqui |
|---|---|
| Repor com cota | Planograma com **buraco visível** onde o produto saiu; repor com a caixa do depósito e o fardo do estoque de bebida |
| Receber entrega | Caminhão às 3h pelo **portão da garagem, que passa a abrir de verdade para a rua**; conferir a nota |
| Limpeza | Pegadas molhadas de chuva, produto derrubado, placa de piso molhado |
| Caixa | Passar item a item no leitor, total no visor, **troco em cédula de 1998**, maquininha de cartão, fiado |
| Abastecer carro | Ideia 6 (§14): posto com conveniência. O trânsito já existe |
| Documento + banco NET + descrição | `Documento` + `Terminal` já existem. Falta o **julgamento** e a linha "compra habitualmente" na DESCRIÇÃO |
| Detector de emoção | Não entra. Aqui o sinal é do corpo: não pisca, o olhar gira rápido demais, passo sem som, não aparece na câmera |
| Tábuas, armadilhas, esconder | Porta de aço da frente, apagar a loja, câmara fria como esconderijo, o `Inimigo` **com contexto** |
| 13 turnos | Uma noite é um turno; semente por noite; dificuldade crescente |

O que o *Shift At Midnight* **não** tem e aqui dá para ter: a loja fica numa
cidade aberta que continua existindo lá fora. O freguês que entra é um
pedestre que você viu na calçada. O registro civil é de uma cidade inteira,
com vínculos de família. E o Brasil de 1998 tem cultura de balcão própria:
fiado, guichê gradeado, "Sorria, você está sendo filmado".

---

## 3. A decisão central: o mercado existe na rua

### 3.1 Por quê

Pela mesma razão do bar e da casa da fumaça: o que se vê pela porta de vidro
tem de ser a loja, porque ela está lá. A infraestrutura existe (§1.3); a F6 do
plano da casa da fumaça já previa o mercado por último, e o teleporte só sai do
jogo quando a última planta migrar.

### 3.2 O lote — a conta que decide a planta

Regra de hoje (`KitFumaca.lote_na_face`): o lote cabe quando a face tem pelo
menos `largura do lote + 1 m`. Em chunk de esquina, a fileira do outro eixo
ocupa os 8 m da face mais perto da outra rua, e um lote com mais de 8 m de
fundo tem de ficar fora desse trecho.

| Planta | Lote com parede | Face sem esquina (32 m) | Esquina de viela (26,4–29 m) | Esquina de rua (22,4–25 m) | Esquina de avenida (20,2–22,8 m) |
|---|---|---|---|---|---|
| Atual, 19 × 13 | 19,5 × 13,5 | cabe | só a partir de 27,5 | não | não |
| **Proposta, 17 × 16** | 17,5 × 16,5 | cabe | cabe | não | não |

Fundo disponível: o muro de trás fica a 17 m da fachada quando o quintal tem 9 m
(`FundosBuilder`, quadras de 2+ chunks). 16,5 m cabem. O lote passa 8,5 m do
corpo do prédio e entra no quintal como anexo térreo, igual à casa da fumaça.

**Regra nova: o mercado só nasce onde cabe.** A escolha em
`_porta_do_chunk` ganha a condição `lote_na_face(...)` não vazio. Onde não
cabe, a porta vira outra coisa (apartamento ou bar), **nunca teleporte**. Para
compensar as esquinas perdidas, a frequência sobe de 1/4 para 1/3. Um teste
puro (como o [game/tests/lote_fumaca.gd](game/tests/lote_fumaca.gd)) prova que continuam existindo ≥ 10 lojas
num raio de 12 chunks e que todo lote tem 17 m livres atrás. A regra é de
`chunk_builder.gd`, e não da malha: a malha de ruas é da sessão psx-8a desde
21/09 e não é tocada.

### 3.3 A planta nova (17 × 16 m)

```
 z=16 +--------+-----------+---------------------------------------+
      |BANHEIRO|   COPA    |  CORREDOR DE SERVIÇO (liga tudo)      |
 z=13 +--[p]---+----[p]----+----+----------------------------------+
      |                         |  ESTOQUE DE BEBIDA E CFTV        |
      |   DEPÓSITO / GARAGEM    |  (engradados, fardos, o monitor  |
      |   estante, paletes,     |   das 4 câmeras, a gaveta forte) |
 z=10.5  carrinho, lixo         +==== 8 portas de geladeira =======+
      |                         |  ilha 1   ilha 2   ilha 3   gôn- |
      |                        [p] (serviço, no fim do balcão)  dola|
      |                         |B                             de  |
      |                         |A  ← fila                   parede|
      |                         |L        [freezer] [café]         |
  z=0 +------[PORTÃO 3,4]-------+C-[vitrine]--[PORTA AUTO]-[revistas]
     x=0                      x=5                                x=17
                          CALÇADA
```

O que se mantém do desenho atual, porque é bom:

- Quem entra cai no eixo do corredor central e vê a **câmara fria acesa no
  fundo** (é o quadro que puxa para dentro).
- Caixa encostado na divisa, porta de serviço no fim do balcão: "atrás do
  caixa" é um lugar de verdade.
- A virada de paleta do palco (branco chapado) para a coxia (verde de
  repartição e concreto).
- **Duas bocas na mesma calçada**: vitrine com porta automática e, ao lado, o
  portão de aço. Agora **na mesma distância dentro e fora**, porque a fachada
  é a planta.

O que muda: a parede de geladeiras continua com reposição **pela frente**,
porta a porta (a câmara fria por dentro, ideia 1, ficou fora na decisão de
21/09). Os 2,5 m atrás dela viram o estoque de bebida e a sala do monitor da
CFTV (ideia 3). O depósito se junta à garagem, e o banheiro e a copa vão para
o fundo. A ilha continua baixa (1,52 m, abaixo do
olho): de qualquer ponto do salão **se vê a cabeça de quem está no outro
corredor**, o que vale para a leitura de loja cheia e para o horror.

### 3.4 Fachada = planta

- **A vitrine é a parede sul do salão.** Vidro transparente de verdade: da
  calçada se veem as gôndolas, o freguês na fila e o atendente. Adesivos de
  promoção cobrem a faixa de 1,0–1,4 m, como toda loja brasileira faz
  ("CERVEJA GELADA", "SALGADOS", "RECARGA"); acima e abaixo, loja.
- O prédio da fileira continua em cima (andares a partir de 3,35 m, como o bar
  faz com `ALTURA_SALAO`). Os 8,5 m de trás são anexo térreo com laje:
  condensadora da câmara fria (fonte de som na calçada lateral) e caixa d'água.
- O portão de aço é a porta real da garagem. Abre por dentro (botoeira
  sobe/desce), e o caminhão das 3h encosta na calçada.
- Luz: o salão acende a calçada pelo vidro (a luz de derrame que já existe,
  agora saindo da loja real). A marquise e o letreiro HIKARI ficam como estão.

### 3.5 A porta automática, de verdade

Hoje ela é uma `Area3D` que o jogador aciona com [E]. Porta automática não tem
botão:

| Comportamento | Detalhe |
|---|---|
| Sensor | Volume de 2,2 × 2,0 × 1,6 m **dos dois lados**, detecta jogador **e freguês** |
| Abertura | 0,55 s com saída suave; fica aberta enquanto houver alguém no volume; fecha 1,6 s depois com entrada suave; **reabre** se alguém entra no vão fechando |
| Som | Motor (`porta_desliza`) e o **dim-dom eletrônico** de loja. Ouvido do depósito, ele diz "alguém entrou" — informação de jogo |
| Colisão | As folhas passam a ter corpo (hoje não têm): fechada, é parede |
| Vidro | Transparente, com reflexo da rua por fresnel; gotas escorrendo por fora quando chove (`psx_gota_corredora`) |

### 3.6 A travessia

- A soleira de `InteriorNoMundo` mistura a névoa da rua com o ambiente da loja
  pela posição do jogador; `Interiores.entrou` dispara na metade (missão, HUD,
  GPS reagem como antes).
- **O olho que se acostuma**: vindo de vinte minutos de sódio e névoa, a
  exposição passa do ponto por 1,2 s e assenta. É a frase do cabeçalho do
  builder ("a luz machuca") virando imagem. Medir com o `EstiloVisual` e a
  memória `piso-da-exposicao-e-a-sensibilidade-minima`.
- A chuva continua lá fora, vista pelo vidro; dentro, o som dela passa pelo
  filtro abafado e **o vidro tamborila**.

### 3.7 O que depende do teleporte e precisa migrar

| Dependência | Conserto |
|---|---|
| `_encarar_quem_pegou` retorna cedo quando `_no == null` | Procurar o convidado pela árvore do `InteriorNoMundo` |
| `_passar_no_leitor` só vira a câmera com `_no != null` e mira `_no.global_position + monitor` | Monitor em coordenada global vinda do prop |
| `_portao_garagem` chama `sair(deslocamento)` | No mundo, o portão só abre: a rua está do outro lado |
| Rotina `compra` fixa `_alvo = pontos[0]` no `_ready`, **antes** de `CasaViva.adotar` converter para global | O primeiro alvo passa a ser pedido depois da adoção. Some de todo modo com o `Fregues` (§5) |
| `abertura.gd`, `CENAS_MERCADO` e `TesteMercado` usam `DESLOCAMENTO` | Tudo reescrito em coordenada do lote (F9) |
| `InteriorNoMundo` e `KitFumaca` têm a casa da fumaça cravada (`centro_do_vao`, `ALTURA`/`LARGURA`/`FUNDO`, `LOTE`) | A planta passa a declarar `vao`, `lote` e `altura` no dicionário; `_fileira` despacha pelo tipo em vez de chamar `_predio_da_fumaca` |

---

## 4. O produto é coisa

É o coração do pedido 2. "Bem mapeado" quer dizer: **toda posição de toda
prateleira responde "o que tem aqui, quanto custa, quantos restam"**, e é a
mesma resposta para o freguês, para o jogador, para a etiqueta de preço e para
a tarefa de repor.

### 4.1 Catálogo (`CatalogoMercado`, dados puros)

~60 produtos em 10 categorias, preços em reais de novembro de 1998
(salário mínimo: R$ 130).

| Campo | Exemplo |
|---|---|
| `id`, `nome`, `marca` | `refri_guarana_2l`, "Guaraná 2 L", marca real no atlas trocável (decisão D4) |
| `categoria` | bebidas, cerveja, mercearia, biscoito e salgadinho, doce, frios e laticínios, padaria, higiene, limpeza, tabacaria, utilidade, farmácia leve, revista e jornal, sorvete |
| `forma` | LATA, PET, VIDRO, CAIXA, PACOTE, SACHÊ, POTE, BARRA, MAÇO |
| `medida` | em cm, para a malha e para o encaixe na prateleira |
| `preco` | R$ 1,49 |
| `idade_minima` | 18 para cerveja e cigarro — é o que dá razão pé no chão ao documento no balcão |
| `validade` | perecível ou não (tarefa de tirar vencido) |
| `item` | liga ao `Item` jogável quando existe: bandagem, remédio, bateria, lanterna; novos consumíveis de comida |
| `celula` | célula do atlas de rótulos |

Amostra de preço (conferir na pesquisa da F2): pão de forma R$ 1,80,
refrigerante 2 L R$ 1,49, cerveja lata R$ 0,79, maço de cigarro R$ 1,20, leite
1 L R$ 0,85, macarrão instantâneo R$ 0,35, pilha (par) R$ 1,90.

### 4.2 Planograma (`Planograma`, dados puros)

A loja real é arrumada por regra, e o jogador sente isso sem saber o nome:

- **Hierarquia**: gôndola → módulo de 1,0 m → nível → vaga. A vaga guarda
  `sku`, `frentes`, `fundo` (unidades atrás da primeira), `estoque`, posição e
  normal em coordenada da planta, e a **faixa de altura** (baixa < 0,5 m,
  média, alta > 1,4 m). A faixa decide a pose de quem pega.
- **Ponto de parada** por vaga: 0,55 m à frente da face, no centro da coluna.
  É onde o freguês para, e é reservável (dois fregueses não disputam a mesma
  vaga — a reserva de usos da `CasaViva`).
- **Regras de vizinhança**: cerveja perto da câmara fria, salgadinho ao lado da
  cerveja, doce e chiclete no caixa (compra por impulso), higiene junto,
  tabacaria **atrás do balcão** (só o atendente alcança), produto caro na
  altura do olho, pesado embaixo.
- Semente da loja → planograma. Doze lojas, doze arrumações.

### 4.3 Prateleira viva (`PrateleiraViva`)

- Cada produto é uma **instância** de `MultiMesh`: um por forma, **por
  gôndola** (o objeto fica local, e cada pedaço vê poucas luzes), com o rótulo
  escolhido por `INSTANCE_CUSTOM` num atlas. Shader novo `psx_produto` derivado
  do `psx_surface_pixel`, com o contrato PSX (skill `psx-render`).
- Só a **fileira da frente** é desenhada. Atrás dela fica a placa pintada de
  hoje, escurecida, como fundo: é ela que diz "tem mais atrás".
- **Pegar** zera a escala da instância; a unidade de trás avança depois de
  0,5 s enquanto houver `fundo`. Com a vaga zerada, **fica o buraco** e a
  etiqueta de preço sozinha. O buraco é a tarefa de repor, visível do outro
  lado da loja.
- **Nível de detalhe por módulo** (`visibility_range`): até 9 m, malha cheia
  (lata de 8 lados, garrafa com gargalo); além disso, cartão de 2 triângulos
  com a silhueta recortada.
- **Etiqueta de preço** amarela em toda vaga, gerada do catálogo e legível a
  1280×720 a um metro. Na mão, lê-se o preço e a validade.

Estimativa, a medir na F2: ~2.800 frentes (3 ilhas × 2 lados × 6 m × 5 níveis,
mais as paredes e a câmara fria), ~15 malhas de forma × 5 gôndolas ≈ 75
chamadas de desenho, 25–55 mil triângulos instanciados perto e ~6 mil longe.

### 4.4 A mira de prateleira

Área de acionamento por produto não cabe: seriam 2.800 corpos. Em vez disso,
**um raio da mira contra o plano da face da gôndola** vira módulo, nível e
coluna — uma conta, zero física. A mira **gruda na vaga mais próxima**: é a
lição da carteira do balcão, em que doze centímetros a um metro e meio davam
três pixels de mira, e o código registrou isso como defeito, não como
dificuldade ([mercado_builder.gd:545-547](game/src/world/mercado_builder.gd#L545-L547)).
O produto sob a mira pulsa de brilho, e o rótulo diz
"Pegar — Guaraná 2 L — R$ 1,49".

Na mão: girar e ler (rótulo, preço, validade), pôr na cesta, **devolver** na
vaga certa — ou na errada, e aí vira "produto fora do lugar" para quem
trabalha (freguês de verdade faz isso).

### 4.5 Estado e conservação

- `EstoqueMercado`: diferenças por vaga (só o que mudou), por semente de loja,
  no `WorldState`, numa faixa nova (424245). Entra no save.
- **Invariante de conservação**, medida pelo teste: `estoque inicial − estoque
  atual = itens em cestas + vendidos + furtados + no chão`. É a lição da
  memória `adicionar-devolve-a-sobra`: item existindo em dois lugares passa em
  teste que conta um lado só.

---

## 5. O freguês

### 5.1 De onde ele vem

- **Da rua.** Quando a curva de demanda da loja pede alguém e um pedestre da
  `Multidao` passa a menos de 15 m da porta, ele é **trocado por um `Fregues`
  com a mesma ficha**, na mesma posição e no mesmo passo (o precedente é o
  sequestro do `EntregasDaSuper`). Ao sair, volta a ser pedestre, **com a
  sacola na mão**. O mesmo homem que você viu fumando na esquina entra, compra
  cigarro e sai.
- **Curva de demanda por hora**, no `Relogio`: 22–0h movimento médio (saída do
  bar, taxista); 0–3h pouco e esquisito; 3h caminhão; 4:30–6h trabalhador cedo
  (pão, café, cigarro).
- **Lotação**: até 5 fregueses dentro, fila incluída, mais o atendente.

### 5.2 Máquina de estados

| Estado | O que acontece |
|---|---|
| CHEGAR | Anda até a porta; o sensor abre; limpa o pé no tapete; se chove, sacode o casaco |
| CESTA | Com lista de 3 ou mais itens, pega uma cesta da pilha (5 → 4) e a leva no antebraço esquerdo; com 1 ou 2, vai de mão |
| PERCORRER | Ordena a lista por corredor (vizinho mais próximo a partir da porta), anda com a navegação da `CasaViva` e desvio RVO |
| PROCURAR | Para, varre a prateleira com a cabeça (`olhar_lateral` em passos) antes de achar |
| PEGAR | §5.3 |
| GELADEIRA | Abre a porta de vidro (dobradiça animada, luz fria e sopro de vapor, estalo da borracha), pega, fecha. 5% esquecem aberta: o alarme apita e vira tarefa |
| BALCÃO | O que fica atrás do balcão (cigarro, remédio, recarga) se **pede**: "me vê um maço de...". Com idade mínima, o documento vai para o tampo |
| FILA | Vagas marcadas no chão ("aguarde sua vez"); impaciência que cresce (olha o relógio, bate o pé, suspira, **pega um chiclete do expositor**) |
| CAIXA | Põe a cesta no tampo e tira item a item; paga (§6); recebe a sacola |
| SAIR | Devolve a cesta à pilha (ou larga no balcão, e vira tarefa); a porta abre; volta a ser pedestre |

### 5.3 Pegar — o gesto que prova o pedido

Quadro a quadro, a 15 poses/s como todo o `Corpo`:

1. **Chegar**: freia (a `ACELERACAO` que já existe), gira no lugar e encara a
   face da gôndola.
2. **Olhar primeiro** (0,4 s): a cabeça vai à vaga antes da mão. É a
   antecipação que separa gesto de gente de gesto de boneco.
3. **Alcançar** (0,35 s): IK analítico de dois ossos (braço e antebraço) até a
   vaga. **Três faixas**: baixa agacha (joelho dobra e pelve desce), média
   estica o braço, alta sobe na ponta do pé.
4. **Pegar**: a instância some da prateleira no mesmo quadro em que uma
   `MeshInstance3D` do mesmo produto nasce no `_punho`.
5. **Recolher** (0,3 s) e **pôr na cesta** (0,25 s): o produto vai para a
   próxima casa livre de uma grade 3 × 2 × 2 dentro da cesta, com giro
   pequeno.
6. **Às vezes (15%) compara**: segura dois, olha um, devolve um.

**Medida pela ponta** (memória `animacao-se-mede-pela-ponta`): a distância da
mão à vaga no quadro da pega não pode passar de 6 cm.

Posturas novas no `Corpo`: ALCANÇAR (com as três faixas), CESTA_NO_BRAÇO,
SACOLA, ENTREGAR (dinheiro, documento), PASSAR_PRODUTO (para o atendente).
Todas entram como postura, na mesma arquitetura das nove que existem.

### 5.4 A cesta

- Prop próprio, a mesma malha da pilha. A pilha tem contagem: some uma cesta,
  a pilha baixa.
- **O conteúdo é visível e exato**: dá para ler o que alguém está comprando
  olhando a cesta. Isso é também a prova da §8.
- Na saída, **sacola plástica** amarrada, com volume proporcional à compra.

### 5.5 Quem é o freguês (personas)

Da ficha do `RegistroCivil` (profissão, idade, personalidade) e da hora:

| Persona | Hora | Cesta típica | Comportamento |
|---|---|---|---|
| Taxista | toda a noite | café, cigarro, chiclete | pressa (`VELOCIDADE_PRESSA`), vai direto |
| Estudante | 22–1h | macarrão instantâneo, refrigerante, salgadinho | passeia, compara preço |
| Saída do bar | 23–2h | cerveja ×6, gelo, amendoim | anda torto, fala alto, esquece a cesta |
| Enfermeira do plantão | 1–5h | café, bolacha, pilha | cansada, lenta, educada |
| Mãe | 22–23h, 5–6h | leite, pão, fralda | lista na mão, não passeia |
| Trabalhador cedo | 4:30–6h | pão, café, cigarro | fila, impaciência |
| Morador fixo (fiado) | qualquer | **sempre a mesma coisa** | cumprimenta pelo nome, pede para pendurar |
| Furtador | 0–4h | esconde um item no casaco | olha para os dois lados, evita a câmera |
| Casal adolescente | 22–0h | refrigerante, sorvete | em dupla, riem (`gargalhar`) |

### 5.6 Comportamento de gente (o que separa AAA de funcional)

- Cortesia: "com licença" quando o jogador tapa o corredor; espera o outro
  passar no corredor de 1,64 m; abre espaço.
- Olhar: vira a cabeça para quem entra (o dim-dom), para barulho de produto
  caindo, para o jogador atrás do balcão.
- Perguntar: "onde fica o sabão em pó?" — quem trabalha precisa conhecer o
  planograma.
- Erros de gente: derruba produto (1%), devolve na vaga errada, esquece a cesta
  no balcão, deixa a geladeira aberta.
- Sem jogador trabalhando, **o atendente NPC faz o caixa** (animação de passar
  produto) e **repõe** nas horas mortas (a postura TRABALHANDO já existe). A
  loja vive sozinha.

---

## 6. O caixa e o dinheiro

O dinheiro não existe no jogo, e a abertura já promete quarenta reais e fome.
É a promessa mais barata de cumprir e a que mais sustenta o mercado.

- **Carteira do jogador** em reais, no inventário e no save. Começa com
  R$ 40,00, os da abertura.
- Dinheiro de 1998: cédulas de R$ 1, 5, 10, 50 e 100; moedas de 1, 5, 10, 25 e
  50 centavos e de R$ 1. As cédulas de R$ 2 e R$ 20 só vieram em 2001 e 2002.
  *Conferir na pesquisa da F4.*
- **Jogador freguês**: cesta, pega, fila, paga ao atendente NPC, recebe troco
  e sacola. Comida vira consumível: a fome da abertura tem resposta.
- **Jogador no caixa**: passa item a item (bip, nome e preço no visor da
  registradora, total), recebe as notas no tampo, **monta o troco na gaveta**
  clicando cédula e moeda (troco errado: o freguês reclama, ou sai contente se
  for a mais), maquininha de cartão (o freguês digita a senha, sai o
  comprovante), **fiado** no caderno para o morador fixo, sacola, cupom.
- **Furto do jogador**: sair sem pagar com o atendente vendo (cone de visão, o
  mesmo desenho do `Inimigo`) faz ele gritar e ligar para a polícia. O que
  acontece depois é decisão D3.

---

## 7. O turno da noite

A camada *Shift At Midnight*, opcional para o jogador (decisão D1).

- **Contratação**: o dono, Seu Hikari, oferece o turno das 23h às 5h.
  "Mercadinho do japonês" é uma instituição de bairro brasileiro, e o dono
  tem ficha no registro e vínculos.
- **Ritmo**: com o relógio a 2×, seis horas de turno seriam três horas reais.
  Dentro do turno o ritmo sobe para **8×** (6h em 45 min), a ajustar em teste.
- **Tarefas**, todas ligadas a sistemas deste plano:

| Tarefa | Mecânica |
|---|---|
| Caixa | §6 |
| Repor | Buraco na prateleira → caixa de papelão no depósito → carrinho → estilete → encher a vaga (mira de prateleira) |
| Repor a geladeira | Pela frente, porta a porta, com o fardo do estoque de bebida; a porta aberta embaça e apita |
| Vigiar | Monitor da CFTV (ideia 3) no balcão e na sala de estoque |
| Receber entrega | Caminhão às 3h no portão; conferir as caixas com a nota; guardar |
| Limpeza | Pegadas molhadas da chuva, produto derrubado; esfregão; placa de piso molhado |
| Vitrine quente | Reaquecer coxinha e pão de queijo; salgado passado vira lixo |
| Validade | Tirar o vencido da prateleira (etiqueta legível na mão) |
| Organizar | Produto fora do lugar |
| Lixo | Sacos até a caçamba da viela |
| Fechar o caixa | Contar a gaveta no fim; diferença é descontada |

- **Fim do turno**: bilhete do dono no quadro de avisos, salário, descontos,
  e o registro de vendas da noite no `Terminal`.
- **Regras do turno** (ideia 5): o dono deixa as regras pregadas na cortiça.
  É o contexto que a memória `ameaca-sem-contexto-le-como-bug` exige antes de
  qualquer ameaça.

---

## 8. Conferência: documentos e "os de fora"

### 8.1 Camada pé no chão (sem sobrenatural)

Ensina a mecânica num contexto chato antes de virá-la do avesso:

| Checagem | Dado que já existe |
|---|---|
| Idade para cerveja e cigarro | `nascimento` contra 14/11/1998 |
| Documento vencido | `validade` — **existe e ninguém confere**; pela fórmula, muito adulto velho já está vencido |
| Suspenso ou falecido | `situacao` (≈4% suspensos; 34% dos maiores de 74 anos falecidos), com carimbo vermelho no `Documento` |
| Foto × rosto | `Retrato` da ficha contra a `Aparencia` do corpo; as duas são função do id |
| CPF inválido | Dígito verificador real; o `Terminal` recusa |

### 8.2 "Os de fora"

Uma ficha copiada de uma pessoa real, que erra em algum lugar:

| Sinal | Como se implementa |
|---|---|
| A pessoa da ficha está **morta** | `situacao = FALECIDO` numa ficha de adulto novo |
| Descrição física não bate | DESCRIÇÃO do `Terminal` ("careca") contra `Aparencia` do corpo (cabelo) |
| **Hábito de compra não bate** | Linha nova na DESCRIÇÃO: "compra habitualmente: leite, pão de forma, cigarro". A cesta do sósia é outra (ideia 2) |
| **Já veio hoje** | O registro de vendas da noite mostra a mesma pessoa às 23:12; agora são 3:40 |
| Endereço impossível | Quadra que não é EDIFICADO na `MalhaUrbana` |
| Corpo | Não pisca, a cabeça gira rápido demais, passo sem som, **não aparece na câmera** (fora da `cull_mask` da CFTV: ideia 3) |

**O que o jogador faz**: atender, recusar ("hoje não"), chamar a polícia pelo
telefone da loja. A arma debaixo do balcão (a munição 9 mm já aparece em
metade das lojas) é decisão de tom (D2).

**Consequência** de deixar passar: no fim do turno, a coisa volta. A lâmpada
fluorescente do fundo (que já falha de propósito) apaga, o compressor da
câmara fria para (**o silêncio é o sinal**), o dim-dom toca sem ninguém na
porta. O jogador baixa a porta de aço, apaga a loja e se esconde (no banheiro,
na copa ou atrás das caixas do depósito), seguindo a coisa pelo monitor da
CFTV — onde ela **não aparece**. O `Inimigo` volta a ter
uso, agora com o contexto que faltava. Recusar um humano também custa:
reclamação ao dono, desconto, freguês fixo que não volta.

**Dificuldade**: a primeira noite só tem a camada 8.1; os sinais da 8.2 entram
um por noite; a semente é da noite.

---

## 9. Luz, vidro, som e arte

### 9.1 Luz

- Calha fluorescente com tubo **emissivo** (custo zero) e poucas luzes reais;
  malha **partida por zona** (frente do salão, fundo, câmara fria, serviço)
  para cada pedaço ver ≤ 8 luzes.
- Oscilação de 100 Hz imperceptível e **um** tubo falhando (já existe); reator
  zumbindo mais alto no tubo ruim.
- A estufa de salgados como única luz quente do salão (já existe).
- Luz de emergência (caixa branca com duas lâmpadas) para o apagão.

### 9.2 Vidro e piso

- Vitrine: transparente com reflexo por fresnel. Por fora, gota escorrendo na
  chuva (`psx_gota_corredora`); de dentro, à noite, **o próprio salão
  refletido no vidro** por cima da rua escura.
- Piso cerâmico polido com **os tubos refletidos**: é a assinatura visual de
  loja de conveniência à noite. Sonda de reflexo própria da loja (modo
  interior, `UPDATE_ONCE`, criada no pré-aquecimento — memória
  `sonda-por-chunk-custa-engasgo`) mais SSR no MODERNO.
- Pegadas molhadas: decalque que o freguês molhado deixa e que seca em minutos.

### 9.3 Câmara fria

Portas com moldura de LED vertical, **condensação no vidro que some quando a
porta abre** (parâmetro animado), produtos visíveis atrás do vidro (a mesma
`PrateleiraViva`), vapor ao abrir, zumbido do compressor por conjunto de
portas.

### 9.4 Objetos de cena (Brasil, novembro de 1998)

- Parede de cigarro atrás do balcão; expositor de chiclete e bala no caixa;
  freezer horizontal de sorvete com tampa de correr e gelo; máquina de café;
  estufa de salgados; saco de gelo; pilhas de carvão na porta.
- **Pôster da Seleção da Copa de 98** ainda na parede (a final foi em julho);
  calendário da distribuidora; **jornal de 14/11/1998** no revisteiro, com
  manchete inventada.
- Espelho convexo no canto; câmera de CFTV com LED vermelho; placa **"SORRIA,
  VOCÊ ESTÁ SENDO FILMADO"**.
- Cartaz de oferta escrito à mão em papel fluorescente ("OFERTA", "LEVE 3 PAGUE
  2"); faixa de gôndola; etiqueta amarela.
- Rádio AM/FM atrás do balcão tocando a mesma `Radio` do carro; TV pequena na
  parede (`televisao` já existe) que sai do ar depois das 2h.
- Cestas vermelhas de plástico com alça de metal; carrinho de carga no
  depósito; estilete e caixa aberta.

### 9.5 Som

| Loop | Evento |
|---|---|
| Compressor da câmara fria (3D, por conjunto de portas; **para às 3h**) | Dim-dom da porta; motor da porta |
| Reator de fluorescente (mais alto no tubo ruim) | Bip do leitor; gaveta da registradora; moedas; impressora do cupom |
| Rádio AM baixinho | Sacola plástica; cesta batendo; borracha da geladeira |
| Chuva no vidro e na marquise | Passos em cerâmica (superfície própria); produto caindo |

Hoje faltam todos os loops e metade dos eventos. Saem do `gerar_audio.py` ou
de biblioteca CC0 (decidir na F5).

---

## 10. Arquitetura técnica

### 10.1 Arquivos novos

Pasta nova `game/src/world/mercado/`. Arquivo novo sobrevive a reversão de
sessão paralela (memória `sessoes-paralelas-no-repo`).

| Arquivo | Papel |
|---|---|
| `catalogo_mercado.gd` | SKUs, preços, formas, atlas (dados puros) |
| `planograma.gd` | Vagas da planta + semente; consulta "o que tem neste ponto" (dados puros, testável no nível 2) |
| `estoque_mercado.gd` | Diferenças por vaga no `WorldState`; conservação |
| `prateleira_viva.gd` | `MultiMesh` por forma e gôndola; some, avança, repõe |
| `mira_de_prateleira.gd` | Raio → vaga, com aderência e destaque |
| `cesta.gd` | Prop de cesta com conteúdo exato; pilha com contagem |
| `fregues.gd` | `extends Convidado` (como `MoradorPraca`): o cérebro da compra |
| `diretor_da_loja.gd` | Curva de demanda, troca pedestre ↔ freguês, lotação, fila |
| `caixa_registradora.gd` | Passar, visor, total, pagamento, troco, gaveta, cupom |
| `sensor_da_porta.gd` | Volume dos dois lados, abrir/segurar/fechar/reabrir, dim-dom |
| `turno_mercado.gd` | Emprego, tarefas, ritmo, avaliação |
| `cftv.gd` | 4 câmeras em `SubViewport` de 160 × 120 a 5 quadros/s, no monitor CRT |
| `game/shaders/psx_produto.gdshader` | Rótulo por `INSTANCE_CUSTOM` com o contrato PSX |
| `tools/baixar_rotulos.py` | Rótulos **reais** (decisão D4), no mesmo molde do `baixar_capas.py`: cache em `.tools/cache_rotulos`, atlas `game/assets/textures_hd/rotulos.jpg` (2048 px, MODERNO) e `game/assets/textures/rotulos.png` (512 px, 256 cores, PS1), índice gerado `rotulos_atlas.gd`. Trocar o atlas troca todas as marcas sem mexer em código |
| `tools/gerar_produtos.py` | Etiquetas de preço, cartazes de oferta e o atlas de pastiche que substitui o real num build distribuído |
| `game/tests/planograma_mercado.gd` | Nível 2: vagas, vizinhança, lote, conservação |

`mercado_builder.gd` e `kit_mercado.gd` não têm trabalho alheio em aberto e
podem ser reescritos à vontade.

### 10.2 Ganchos em arquivos compartilhados

Hoje há **trabalho não commitado de outras sessões** em todos os arquivos de
que a F1 precisa:

| Arquivo | Diferença não commitada | Gancho necessário |
|---|---|---|
| `chunk_builder.gd` | +808 linhas | `_porta_do_chunk` (mercado com `mundo` e lote), `_fileira` (despachar por tipo) |
| `convidado.gd` | +625 linhas | nenhum, se `Fregues` herdar e só usar a API pública |
| `interiores.gd` | +85 linhas | os quatro consertos da §3.7 |
| `interior_no_mundo.gd` | +67 linhas | tirar `KitFumaca` e `CasaFumacaBuilder` cravados |
| `porta.gd` | +39 linhas | modo sensor |
| `casa_viva.gd` | **arquivo inteiro não rastreado** | nenhum; só uso |

Protocolo: antes de cada fase, `git status --short` nesses arquivos. Se o
trabalho alheio continuar sem commit, o gancho vai pelo índice (cópia do HEAD
com `git hash-object` e `update-index`, como na Fase 6 do carro) ou espera o
dono commitar. **Nunca** `git add` nesses arquivos. `casa_viva.gd` precisa ser
commitado pelo dono antes da F1: um merge alheio o apagaria, e a F1 depende
dele.

### 10.3 Orçamentos (a medir, não a supor)

| Recurso | Proposta |
|---|---|
| Casca no chunk (sempre) | + ≤ 1.500 triângulos sobre o chunk; se estourar os 6.000, teto próprio como o bar (decisão sua) |
| Estrutura da loja (pré-aquecida) | ≤ 12 mil triângulos |
| Produtos | ≤ 55 mil instanciados perto, ≤ 8 mil longe; ≤ 90 chamadas de desenho |
| Luzes | ≤ 16 na loja; ≤ 8 por pedaço de malha; sombra só nas 2 do `DiretorSombra` |
| Fregueses | ≤ 5 + atendente; IA a 10 Hz quando longe do jogador |
| Engasgo na aproximação | Pior quadro ≤ 1,5 × a mediana da rota (critério da casa da fumaça) |
| Pré-aquecimento | Dados na thread; `MultiMesh` montado na thread como `PackedFloat32Array` e entregue num quadro; 1 prop por quadro |

---

## 11. Critérios de aceite

O teste **anda**: nenhum critério chama `Interiores.entrar` na mão.

| Fase | Critério | Alvo |
|---|---|---|
| F0 | Cliente chega ao caixa sem `ir_ao_caixa` | em ≤ 40 s |
| F0 | Plano 04 da abertura enquadra o balcão com os dois | captura |
| F1 | Caminhada calçada → câmara fria, porta aberta pelo sensor | `Interiores.entrar` 0 vezes; alfa da cortina 0; saltos > 0,5 m: 0 |
| F1 | Vão da porta a 40% de abertura | pixels ≠ vidro opaco; gôndola visível |
| F1 | Luz isolada | parede do vizinho com a loja acesa e apagada: diferença ≤ 1/255 |
| F1 | Lojas na cidade | ≥ 10 num raio de 12 chunks; todo lote com 17 m livres |
| F2 | Mira de prateleira | 100% dos pontos de uma varredura de 2 cm devolvem a vaga certa |
| F2 | Pegar e devolver | estoque volta ao inicial; buraco some |
| F3 | 10 min simulados | ≥ 6 fregueses entram **pela soleira**; `presos = 0`; todos saem com sacola |
| F3 | Conservação | estoque inicial − final = Σ cestas + sacolas + furto + chão |
| F3 | Pega pela ponta | mão → vaga ≤ 6 cm no quadro da pega |
| F4 | Caixa | total do visor = Σ preços; troco correto em 20 casos sorteados |
| F5 | Captura com olho | `fachada_chuva`, `salao`, `geladeira_aberta`, `fila`, `pega_baixa`, `pega_alta`, `troco`, `cftv` |
| F7 | CFTV | o sósia some do quadro da câmera em 100% dos quadros e aparece no corredor; o humano aparece nos dois |
| F7 | A cesta é prova | freguês fixo: ≥ 80% da cesta dentro do hábito da ficha; sósia: ≤ 20% |
| F6 | Turno completo simulado | todas as tarefas aparecem e são concluíveis |
| F9 | Regressão | critérios do `verificar_mercado.py` migrados; abertura reencenada |

---

## 12. Fases

Cada fase fecha com captura e com os critérios dela.

| Fase | O que entra | Tamanho | Depende de |
|---|---|---|---|
| **F0 — consertos que sobrevivem a tudo** | Cliente travado (rota contornando a ilha); plano 04 da abertura na planta de hoje; comentário do limite de luz; conferir o save a 2000 m | P | — |
| **F1 — o mercado na rua** | `InteriorNoMundo` generalizado; lote e regra "só onde cabe"; planta 17 × 16; fachada = planta; vitrine de vidro; porta com sensor; portão que abre; conteúdo atual portado | G | `casa_viva.gd` commitado; ganchos da §10.2 |
| **F2 — produto é coisa** | Catálogo, planograma, `PrateleiraViva`, etiqueta, mira de prateleira, pegar e devolver, estoque no save | G | F1 |
| **F3 — o freguês** | `Fregues`, cesta, posturas novas (alcançar, cesta, sacola, entregar), geladeira, fila, atendente NPC fazendo o caixa, troca com o pedestre | G | F2 |
| **F4 — caixa e dinheiro** | Carteira em reais, preços, compra como freguês, caixa jogável, troco, maquininha, fiado | M | F3 |
| **F5 — luz, som e arte** | §9 inteira | G | F2 (pode correr junto da F3/F4) |
| **F6 — turno da noite** | §7: contratação, tarefas, ritmo, caminhão, fim do turno | G | F4 |
| **F7 — conferência e "os de fora"** | §8, conforme a decisão D2 | G | F6 |
| **F8 — doze lojas, doze lugares** | Variação por semente: tamanho, marca, planograma, dono | M | F2 |
| **F9 — regressão** | `TesteMercado` que anda; `verificar_mercado.py` novo; `CENAS_MERCADO` e abertura em coordenada de lote; rota de desempenho com loja no caminho | M | F1–F4 |

Ordem mínima para cumprir o pedido literal (porta que mostra dentro, freguês
que enche a cesta): **F0 → F1 → F2 → F3**.

---

## 13. Riscos

| Risco | Tratamento |
|---|---|
| Trabalho não commitado de outras sessões nos arquivos da F1 | Protocolo da §10.2; gancho mínimo; arquivo novo para todo o resto |
| `casa_viva.gd` não rastreado | Pedir ao dono que commite antes da F1 |
| Triângulos de produto | `MultiMesh` fora da malha do chunk, com nível de detalhe por módulo; medir por material antes de cortar (memória `medir-antes-de-mexer`) |
| Luz por objeto no Compatibility | Malha por zona; `PrateleiraViva` por gôndola; contagem no verificador |
| A malha de ruas é da psx-8a | A regra do lote fica em `chunk_builder`; nada em `malha_urbana.gd` |
| `gerar_materiais` apaga `.tres` fora da tabela | Material novo entra na tabela antes de rodar |
| `--ver-abertura` suja 15 PNGs versionados | Capturas desta frente só em `captures/mercado_aaa/` |
| Teste chamando o método em vez de apertar a tecla | Critérios andam e acionam como o jogador (memória `teste-que-chama-o-metodo-nao-aperta-a-tecla`) |
| Ameaça que surge sem contexto | Só depois das regras do turno e com a decisão D2 |
| Primeira execução monta o streaming | Nenhuma captura da primeira execução vale |

---

## 14. Ideias (a lista inteira)

### 14.1 As que mudam o jogo

Aprovadas em 21/09: **2**, **3** e **5** (a 5 veio com a decisão D2). As
outras ficam registradas.

1. **A câmara fria por dentro.** Repor bebida por trás das portas de vidro, de
   dentro do walk-in, vendo o salão pelas frestas entre as garrafas. Um
   freguês abre a porta e pega a cerveja a um palmo do seu rosto. No turno
   ruim, alguém fica parado do outro lado olhando pela fresta.
2. **A cesta é a prova.** A DESCRIÇÃO do `Terminal` ganha "compra
   habitualmente". O freguês fixo compra sempre o mesmo; o sósia enche a cesta
   errado. A mecânica de produto do pedido 2 vira a mecânica de dedução.
3. **CFTV de verdade.** Quatro câmeras em `SubViewport` de 160 × 120 a 5
   quadros/s no monitor CRT do balcão (resolução autêntica da época, custo
   baixo). O que está fora da `cull_mask` **não aparece na câmera**: o
   freguês que está no corredor 3 e não está no quadro 3.
4. **O guichê da madrugada.** Depois das 2h a porta automática trava e o
   atendimento passa à portinhola gradeada, como loja 24h de bairro faz. O
   freguês toca a campainha; você decide quem entra. É o *Papers, Please* com
   cara de Brasil.
5. **As regras do turno do Seu Hikari.** Bilhete pregado na cortiça: "1. Depois
   das 2h, ninguém entra sem documento. 2. Se a luz do fundo apagar, não vá lá.
   3. O Seu Tadashi morreu em 96; se ele entrar, não venda nada." É o
   contexto que falta para qualquer ameaça.
6. **Posto com conveniência.** Uma das doze lojas é um posto: bombas, carro do
   trânsito parando para abastecer, motorista que entra para pagar. **A placa
   do carro contra a ficha** é o sétimo sinal do *Shift At Midnight*.
7. **Fiado e fregueses fixos.** Caderno de fiado com nomes do registro;
   fregueses que voltam noite após noite, cumprimentam pelo nome e têm dívida.
   O sósia de um freguês fixo é o mais assustador, porque você **conhece** a
   pessoa.
8. **O som que para.** Às 3h o compressor da câmara fria desliga. O silêncio
   é o aviso.

### 14.2 As que mudam a sensação

9. **O olho que se acostuma**: a exposição estoura ao entrar e assenta em 1,2 s.
10. **Pôster da Copa de 98 e jornal de 14/11/1998**: a data do mundo vira
    cenário.
11. **Pegadas molhadas** que o freguês de guarda-chuva deixa e que secam; a
    placa de piso molhado posta pelo jogador.
12. **Furto no espelho convexo**: o espelho do canto mostra o corredor que a
    gôndola esconde.
13. **O caminhão das 3h**: o portão sobe, a luz de sódio entra na garagem, o
    motorista descarrega.
14. **Doze lojas, doze lugares**: tamanho, dono, marca da fachada e planograma
    por semente (HIKARI, "Mercadinho Bom Preço", "Conveniência 24h", o posto).
15. **A freguesa do ônibus das 5h**: a fila da madrugada tem horário, e um dia
    ela não vem.

### 14.3 As óbvias (entram de qualquer forma)

- Porta automática sem [E]: chegou perto, abriu.
- Folha da porta com colisão.
- Preço visível em toda vaga.
- Produto na mão legível (nome, preço, validade).
- Atendente que atende quando o jogador não trabalha.
- Cesta que se pega e se devolve.
- Portão da garagem que abre para a rua de verdade.
- Som ambiente de loja.
- Validade do documento conferida.
- Save no telefone da loja que devolve o jogador à loja.
- Plano da abertura filmando o balcão, não a garagem.

---

## 15. Decisões (21/09/2026)

| # | Pergunta | Decisão | Consequência no plano |
|---|---|---|---|
| D1 | O jogador é freguês, funcionário ou os dois? | **Os dois** | A loja vive sozinha com atendente NPC; o jogador compra com dinheiro (R$ 40 da abertura) e aceita o turno do Seu Hikari como atividade. F4, F6 e F7 ficam |
| D2 | "Os de fora" entram? | **Sim, com as regras do turno** | F6 traz o bilhete de regras (ideia 5, que vem junto desta decisão); F7 traz a §8.1 na primeira noite e um sinal da §8.2 por noite |
| D4 | Marcas dos produtos | **Reais, em pasta trocável** | `baixar_rotulos.py` no molde do `baixar_capas.py`; o atlas de pastiche do `gerar_produtos.py` é o substituto para build distribuído |
| D5 | Ideias da §14.1 | **2 (a cesta é a prova) e 3 (CFTV de verdade)** | As duas entram na F7, com critérios na §11. A 1 (câmara fria por dentro) e a 4 (guichê da madrugada) ficam fora: a planta perdeu o walk-in, e os 2,5 m viraram estoque de bebida e sala do monitor |

Ainda em aberto, sem bloquear a F0–F3:

| # | Pergunta | Recomendação | Quando decidir |
|---|---|---|---|
| D3 | O que acontece quando o jogador furta? | Grito, polícia e proibição de entrar naquela loja por uma noite | Antes da F4 |
| D2b | Arma debaixo do balcão contra "os de fora"? | Decidir com a F6 jogável, vendo o tom da noite | Antes da F7 |
| D6 | Teto de triângulos do chunk da loja | Medir na F1; se passar de 6.000, teto próprio como o do bar (9.500) | Na F1 |
| D7 | Ideias 6 a 15 da §14 | Ficam na lista; nenhuma bloqueia fase | Quando a fase dona chegar |

---

## 16. Fontes

- [Shift At Midnight — Steam](https://store.steampowered.com/app/3722330/Shift_At_Midnight/)
- [How To Spot Doppelgangers In Shift At Midnight — TheGamer](https://www.thegamer.com/shift-at-midnight-spot-doppelganger-guide/)
- [Shift At Midnight — TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/ShiftAtMidnight)
- [Shift at Midnight Review — indiegame.com](https://indiegame.com/en/archives/31766)

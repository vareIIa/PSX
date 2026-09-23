---
name: psx-city
description: Regras do kit modular e do streaming da cidade — grade de 32 m, convenção de chunk, carga por distância atrelada ao preset de névoa, pivôs e nomenclatura. Use ao criar ou editar chunk, kit modular, layout de rua, interior, ChunkManager, LOD ou qualquer coisa ligada ao mundo explorável.
---

# Cidade Modular e Streaming

## O princípio

A cidade é grande em **rota percorrível**, não em área bruta. A métrica de sucesso é
"quantos minutos de caminhada interessante existem", nunca "quantos km² o mapa tem".
Uma cidade vazia é o modo de falha mais comum do gênero e o risco número um do projeto.

A névoa não é enfeite: ela é o sistema de oclusão que torna a cidade possível. O
horizonte de streaming é sempre igual ou menor que o alcance da névoa, de forma que o
jogador nunca vê um chunk aparecer.

## Grade

| Item | Valor |
|---|---|
| Lado do chunk | 32 m |
| Módulo do kit | múltiplos de 2 m |
| Altura de piso | 3 m |
| Largura de rua | 6 m, 8 m em avenida |
| Calçada | 2 m de largura, 0.15 m de altura |

Todo módulo tem **pivô no canto inferior esquerdo**, alinhado à grade de 2 m. Pivô no
centro quebra o encaixe e é retrabalho garantido.

## Malha de ruas e quarteirão (o que o gerador faz hoje)

| Peça | Onde mora | Regra |
|---|---|---|
| Avenida | `MalhaUrbana.via_x(i)` | Única linha inteira, a cada 5 chunks nos dois eixos |
| Rua e viela | `Tracado` (divisão binária por célula 5×5) | Existem **por trecho**: pergunte `via_x_em(i, j)` / `via_z_em(j, i)`, nunca `via_x(i)` |
| Entroncamento em T | `Vias.existe_cruzamento` | Nó com braço dirigível nos dois eixos; mobília só nos braços que existem |
| Célula da Praça da Matriz | `Tracado._ancora(1, -1)` | Traçado fixo (cutscene): não mexa sem combinar com quem cuida da praça |
| Revestimento | `MalhaUrbana.revestimento_x/_z` | Paralelepípedo por trecho; a quina do T é da rua que atravessa |
| Fileira de prédios | `ChunkBuilder.repartir` | Reparte a face **inteira**, sem sobra: a sobra era buraco para o pátio |
| Fundo, quintal, miolo | `FundosBuilder` | Parede de trás, muro de divisa e de fundo, varal, puxadinho |
| Beco | `BecoBuilder.becos(cx, cz)` | Vão proposital entre casas, fechado pelos muros do lote |
| Baldio | `BaldioBuilder` | Capim, trilha por quarteirão, entulho, obra parada |

Depois de mexer em fileira, lote ou malha, rode `tests/varrer_patio.gd`: ele monta cada
quarteirão e acusa toda boca do anel de prédios que dá para o pátio (tem controle positivo
embutido). Rua que termina em viela é beco sem saída de carro: o `Tracado` força viela
nesse caso, não desfaça isso.

## Ladeira (`Relevo`)

`Relevo.altura(x, z)` é bilinear das alturas nos cantos dos chunks. Os nós vêm dos morros
(`Morros.bruto`: matriz com a praça em y = 0 no topo, um morro por célula de 12 chunks, vale
de até −37 m), com três ajustes:

- **Parque:** fica plano na média do terreno do GRUPO de parques encostados. O grupo é a
  componente inteira; com teto, o nível dependia de quem perguntava primeiro.
- **Patamar:** chunk de bar ou casa da fumaça. Onde se entra andando não pode ter degrau.
- **Avenida:** aterrada.

A especificação completa está em `docs/specs/SPEC_MORROS_MINAS.md`.

- Rua ou viela acima de 20% vira **escadaria** (`Ladeira`, `EscadariaBuilder`). O meio-fio ao
  lado desce um espelho inteiro (`EscadariaBuilder.SAIA`).
- Nó que fica com dois braços em eixos diferentes é **curva**, não cruzamento
  (`Vias.existe_cruzamento` pede três braços).
- Parque no alto ou na encosta com vista vira **mirante** (`MiranteBuilder`: bastião, cruzeiro,
  luneta). O nó `Mirante` abre a névoa animando o `Environment`, e não reaplicando preset.
- Teste de `--script` que monta chunk usa `load()` e não o nome da classe: citar
  `ChunkBuilder` ou `Settings` pelo nome compila a cadeia antes do autoload existir.

| O quê | Como sobe |
|---|---|
| Chão, calçada, meio-fio, pintura, quintal, beco, vila, baldio | `Relevo.assentar`: vértice a vértice; laje de colisão ≤ 0,45 m sai, caixa alta estica até o chão mais baixo |
| Lote da fileira | `_erguer_lote`: rígido pelo ponto alto da frente (`_altura_do_lote`; o lote da porta interativa, pelo chão na folha), com embasamento de pedra e capa onde o chão desce |
| Jardim, guia rebaixada | `Relevo.reassentar`: dentro do lote rígido, mas seguem o chão |
| Poste, semáforo, placa, máquina, item, porta | Pela altura do próprio pé; `pontos_de_interesse` já devolve a porta no chão |
| Colisão do chão | `Relevo.mapa_de_colisao`: HeightMapShape3D a cada 0,5 m (a calçada 16 cm acima) |

Chunk plano (`Relevo.plano`) segue o caminho antigo, byte a byte — por isso as bancadas da
origem não mudaram. Esquina chanfrada não sai em chunk inclinado. Quem põe coisa no chão
fora do chunk usa `Relevo.altura` (`Rotas.ponto`, `Vias.ponto_de_curva`, `--ir-para`,
decalque, blitz). Para fotografar: `--olhar-ladeira=x,z,mira_x,mira_z`. O mapa de alturas
não segura quem nasce DENTRO de uma caixa: a física empurra para baixo dele e o corpo cai
para sempre.

## Casa e prédio (`FachadaViva`, `ComercioVivo`)

A frente das casas e da rua comercial sai por tipologia (colonial, eclético, moderno,
popular; sobrado, loja de marquise, prédio) e por morador (zelosa, família, idoso, jovem,
fechada, abandonada). Plano em `PLANO_CASAS_AAA.md`.

- Parede com vão de verdade: `ParedeVazada.erguer` (recuo, arco abatido, bandas de
  barrado/azulejo/tijolo sem junta em T). Nada de janela colada na frente da parede.
- Conteúdo do vão: `JanelaViva.sortear` → `precisa_tampa` → `preencher_em`. A janela aberta
  monta cômodo iluminado (`interior`, `interior_aceso`).
- Peça pequena em laço vai num `Obra` e é despejada uma vez: `KitModular.caixa_cor` copia o
  balde inteiro a cada chamada.
- Miudeza em balde `material@perto` (ChunkManager corta a 40 m). Casca de cômodo nunca vai
  nele: sumindo, o vão aberto vira buraco para o limbo.
- A porta de entrar (`Porta`) fica no centro da folha: `(pos - frente_lote)·_lateral + 0,45`.
- Os quatro lados da casa são do mesmo plano (`FundosVivos`): o fundo (porta da cozinha,
  vitrô, cobogó, cano, condensador) e a lateral de esquina (as faixas e a esquadria da
  frente, frisos que dobram a quina, cunhal em L). A massa da esquina sai SEM a face da
  lateral; `info_frente` leva esquadria, faixas e nome da loja da frente para os outros
  lados. Fundo tapado pela fileira perpendicular sai cego (só a parede).
- Distrito industrial: `IndustriaViva` (galpão, oficina, depósito com pátio murado,
  armazém, fábrica; cobertura em arco, oitão, shed ou laje; nome pintado do atlas
  `letreiros_industria.png`). Plano com a chave `"industria"`.
- Quintal do lote com plano: `FundosVivos.quintal` decide primeiro o que encosta na parede
  de trás (puxadinho com oitão ou telheiro, fora da porta da cozinha).
- Ladeira: a base do lote é o ponto ALTO da frente (`ChunkBuilder._altura_do_lote`; na
  esquina, também o canto de trás da lateral). No lote da porta interativa continua sendo
  o chão na folha. O chão da fachada vai em `plano["perfil"]` (`FachadaViva.chao_em`):
  escada na porta (de encosto acima de 3 degraus), degrau de pedra na loja, rampa no
  portão; garagem só onde a guia rebaixada encontra o portão. O chão da quadra desce sob
  a casa (`RebaixoDoLote`, sem junta em T; `--sem-rebaixo` desliga) e o embasamento tem
  capa (`_capa_do_embasamento`).
- Telhado: `TelhadoVivo` (`planejar` depois do plano da casa, sorteio pela semente;
  `montar` no `coroar`). A água passa rente ao topo da parede e desce até a ponta do
  beiral; plana sempre, ondulada de capa-e-canal ou francesa no `@perto`, alinhada às
  colunas da textura (UV 0,5/m, 12 colunas em 2 m). Água na quina (`plano["quinas"]`,
  lados no sinal de `KitModular._lateral`); platibanda esconde telhado; autoconstrução
  com laje coberta. Coisa que encosta no fundo lê `TelhadoVivo.beiral_de_tras`.
- Miolo de quadra (chunk sem rua): `MioloVivo`, depois do chão assentado, rígido e com
  altura absoluta (edícula, galpão, galinheiro, pomar, horta). `--sem-telhado-vivo`
  volta ao `KitPredio.telhado` e ao `_anexos`.
- Vegetação: `Vegetacao` (árvore de copa de cartão, palmeira, bananeira, bambu,
  arbusto, touceira, mata), material `vegetacao` do atlas de `tools/gerar_vegetacao.py`.
  Planta quem já tinha árvore: calçada (`_arborizacao`, espécie por quadra em
  `_especie_de_rua`), quintal (`FundosVivos._verde`), miolo, pasto da serpentina e
  baldio. `--sem-vegetacao` volta à árvore de caixa. Arvore nova não usa
  `KitParque.arvore`/`KitEstrada.arvore` (lê como cubo de longe).
- Bar: todo bar é o salão do KitBar (`ChunkBuilder._predio_do_bar`). Os outros bares
  vêm de `BarVivo` (um lote comercial em cada 4 chunks) com `estilo` (parede,
  azulejo, toldo, cadeira, placa do atlas `bares_nomes`). Loja da ComercioVivo nunca
  anuncia bar. Lote de bar leva `"bar": true` (a máquina de venda desvia).
- Loja: nenhuma porta de loja aberta sem salão atrás. A fachada comercial não abre
  loja de casca (o vão vira porta de aço fechada sem placa, ou janela de grade);
  oficina, galpão, armazém e a venda da esquina ficam fechados. A loja de verdade é
  `LojaViva` (uma por chunk comercial elegível, ramo = célula do `letreiros.png`) com
  o salão de `KitLoja` no térreo vazado (massa começa no 1º andar), equipe com
  `contexto` `loja` (a conversa vende por `VendaDaLoja`, fora da thread do chunk) e clientes andando.
  Placa de loja só onde há loja (`verificar_lojas.py`). `--sem-loja-viva` volta às
  cascas. Vidro de loja de verdade é `vitrine_loja`; o `vitrine` é azulejo pintado.
- Serpentina: curva é arco tangente (`Serpentina._arredondar`, raio 16 m); nunca
  spline pelos cantos (raio de 1 m, a calçada dobra). A casa da curva sai pelo
  sistema novo, montada no espaço dela; `FundosVivos.fundo(..., xf)` mede o quintal.
- Réguas: `tests/bancada_parede_vazada.gd`, `tests/bancada_janela_viva.gd`,
  `tests/bancada_quinas.gd` (quina da quadra) e `bancada_frestas.gd`. Para fotografar
  cômodo: `--janelas-abertas`; caminho antigo: `--sem-fachada-viva`.

## Frestas no chão (`Costura`)

Peça de chão encostada em outra na mesma altura, cada uma na própria grade de 2 m, faz junta
em T, e o pixel sem dono pisca o limbo (no PS1, um pixel inteiro). `Costura.costurar` roda
logo depois do `_solo`, ANTES do relevo: arredonda vértices a 1/512 m, parte a aresta que
tem vértice de outra peça no meio e pendura saia de 30 cm na borda do chunk. Rodar no fim
do `construir` reabriu frestas. Chão que entra depois (grama do parque) passa por
`Costura.soldar(sup, materiais)`. A régua é `tests/bancada_frestas.gd` (`--ps1` com
`--resolution 480x270`, `--centro=cx,cz`, `--so=poses` nomeia chunk e material do buraco).

## Nomenclatura

```
scenes/world/chunks/chunk_<x>_<z>.tscn        chunk_012_007.tscn
scenes/world/kit/<categoria>_<nome>_<variante>.tscn
   kit_calcada_reta_a.tscn
   kit_fachada_loja_b.tscn
   kit_poste_fiacao_a.tscn
scenes/interiors/int_<tipo>_<id>.tscn         int_apartamento_03.tscn
```

Coordenada de chunk sempre com 3 dígitos e zero à esquerda, para ordenar direito na
listagem de arquivo.

## Kit modular v1

A lista mínima para montar o primeiro distrito. Não crie módulo fora dela antes da
Fase 4 fechar.

| Categoria | Módulos |
|---|---|
| Solo | asfalto 2x2, calçada reta, calçada esquina, meio-fio, bueiro |
| Parede | muro concreto 2 m, muro azulejo 2 m, grade metálica 2 m |
| Fachada | loja térrea, apartamento 3 andares, portão de garagem |
| Prop | poste com fiação, máquina de venda, placa vertical, lixeira, ar-condicionado, bicicleta |
| Interior | porta, batente, escada externa, corredor 2x2, janela |

Cada módulo de solo e parede vem **subdividido em quads de 2 m**, exigência da UV
afim. Ver a skill `psx-render`.

## Streaming

`ChunkManager` como autoload. Carga e descarga por distância em `WorkerThreadPool`,
nunca no frame principal.

```gdscript
# raio derivado do preset de névoa ativo
DENSO:      raio de carga 2 chunks (64 m),  descarga 3
LEVE:       raio de carga 3 chunks (96 m),  descarga 4
DESLIGADO:  raio de carga 3 chunks (96 m),  descarga 4
```

`DESLIGADO` mantém o mesmo raio de `LEVE`. O jogador ganha pop-in de chunk visível, que
é o comportamento de um jogo de PS1 real sem névoa, e não uma vista panorâmica da
cidade inteira. Essa é a resposta de design ao pedido de névoa desativável.

Regras duras:

- No máximo **um** chunk instanciado por frame. Fila, não lote.
- Descarga sempre um chunk atrás da carga, criando histerese e evitando thrash quando
  o jogador anda na fronteira.
- Chunk descarregado guarda estado alterado (porta aberta, item pego) num dicionário
  do `WorldState`, nunca na cena.
- Colisão só nos chunks do raio interno. Chunk distante entra sem `StaticBody3D`.

## Interiores

Interior carrega como filho do chunk, sem tela de loading. A transição é uma porta
com um `Area3D` que dispara o carregamento assíncrono enquanto a animação de abrir
roda. A animação de porta dura 1.2 s, que é o orçamento de tempo para o carregamento.

Interior tem `WorldEnvironment` próprio: névoa desligada, luz de fonte única, grade de
cor mais quente. As referências de corredor do moodboard são o alvo.

## Iluminação da cidade

Máximo de **4 luzes dinâmicas por chunk**. Poste, vitrine e máquina de venda são as
fontes. Todo o resto é cor de vértice assada.

À noite, a paleta vem da referência de rua japonesa: céu verde-petróleo `#16241f`,
luz de sódio `#ffb763`, vitrine e máquina de venda em branco frio saturado. O contraste
entre a fonte quente pontual e o fundo verde escuro é o que define o look.

## Ordem de trabalho

Sempre nesta ordem, nunca pule:

1. Módulo do kit existe e encaixa na grade.
2. Chunk montado com módulos existentes.
3. Distrito montado com chunks.

Montar cenário com malha única e customizada "só nesse pedaço" é dívida técnica que
sempre volta na Fase 6.

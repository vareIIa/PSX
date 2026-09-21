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

`Relevo.altura(x, z)` é bilinear das alturas nos cantos dos chunks (±7 m, até ~10% por
quadra). Plano por máscara: disco da origem (5 chunks + 3 de transição) e todo parque com
a rua em volta. Chunk de bar ou casa da fumaça vira **patamar** (os quatro cantos tomam a
média): onde se entra andando não pode ter degrau.

| O quê | Como sobe |
|---|---|
| Chão, calçada, meio-fio, pintura, quintal, beco, vila, baldio | `Relevo.assentar`: vértice a vértice; laje de colisão ≤ 0,45 m sai, caixa alta estica até o chão mais baixo |
| Lote da fileira | `_erguer_lote`: rígido pela altura do chão na porta, com embasamento de pedra onde o chão desce |
| Jardim, guia rebaixada | `Relevo.reassentar`: dentro do lote rígido, mas seguem o chão |
| Poste, semáforo, placa, máquina, item, porta | Pela altura do próprio pé; `pontos_de_interesse` já devolve a porta no chão |
| Colisão do chão | `Relevo.mapa_de_colisao`: HeightMapShape3D a cada 0,5 m (a calçada 16 cm acima) |

Chunk plano (`Relevo.plano`) segue o caminho antigo, byte a byte — por isso as bancadas da
origem não mudaram. Esquina chanfrada não sai em chunk inclinado. Quem põe coisa no chão
fora do chunk usa `Relevo.altura` (`Rotas.ponto`, `Vias.ponto_de_curva`, `--ir-para`,
decalque, blitz). Para fotografar: `--olhar-ladeira=x,z,mira_x,mira_z`. O mapa de alturas
não segura quem nasce DENTRO de uma caixa: a física empurra para baixo dele e o corpo cai
para sempre.

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

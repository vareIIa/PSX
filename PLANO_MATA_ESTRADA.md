# Mata da estrada (abertura): registro

**Pedido (25/09/2026):** a mata da introdução estava fraca. As árvores de longe
ficavam quadradas, faltava mato e floresta densa, e havia pedaços de madeira com
mato boiando na beira da estrada. Depois veio a correção de rumo: "está misturando
todo tipo de árvore, deveria ser um padrão", e "quando a câmera sobe, as de longe
mudam de padrão". O pedido era algo AAA, rico, recheado e robusto.

Estado: feito, sem commit. Nada disto toca na cidade, a não ser a
`ArvoreEsqueleto`, que é compartilhada e é chamada com `fina=false`.

## A mata

É uma mata atlântica fechada, **uma espécie de dossel** (a forma do angico) em
estratos. A riqueza vem dos estratos e do porte, não do catálogo de espécies (ver
a memória `mata-e-um-padrao-nao-catalogo`).

| Estrato | Onde | Feito de |
|---|---|---|
| Dossel perto | 6 a 30 m do eixo | `MataDaEstrada.arvore_do_dossel` (ArvoreEsqueleto 3D), 11 a 19 m de altura, copa `DOSSEL_COPA` × altura |
| Cipó | pende de dentro da copa | tubo de casca com folha miúda (hera) na metade de baixo, em 45% das árvores |
| Andar do meio | 7 a 30 m | arvoretas da mesma espécie (3 a 6 m, pé afundado para ramificar baixo), arbusto de folha miúda, samambaia, taioba |
| Beira | até 8 m | capim, capim-gordura, samambaia, mato; roçado baixo até 6,3 m para as câmeras de passagem e do bicho |
| Fundo | 10 a 212 m | impostores assados da **mesma função** da árvore de perto: 4 dosséis e 2 arvoretas |

Longe e perto saem do mesmo gerador. Por isso o padrão não muda quando a câmera
sobe.

### Impostor

Um impostor é a árvore de verdade fotografada num atlas. Cada variante tem
6 azimutes × 4 elevações (0, 25, 50 e 75°), em quadros de 1024 px reduzidos para
512 com alfa pré-multiplicado e push-pull, mais a normal no espaço da árvore. Em
jogo é um quad virado para a câmera que mistura os quadros vizinhos, com a luz da
folha (envolve, contraluz, sol vazado), vento e molhado.

- Assar: `godot --path game res://tests/assar_impostores.tscn -- --saida=DIR` (precisa de janela).
- Montar: `python tools/montar_impostores.py DIR --limpo`.
- Depois: `--import`.

### A beira de madeira que boiava

- O cipó antigo pendia do nada, de 4 a 6 m, e lia como madeira boiando. Saiu; o
  cipó novo nasce dentro da copa.
- O mourão de caixa virou mourão roliço torto, de 7 lados, com topo chanfrado.
- O muro de tábua escura virou pedra seca de quartzito (lajes em fiadas),
  material `mat_quartzito`, textura `tools/gerar_quartzito_hd.py`.

### Os retângulos escuros no plano do bicho (conserto de 25/09)

Eram céu, não mata. Pelos vãos entre os troncos do fundo, embaixo das copas,
aparecia a cúpula (`psx_ceu_estrada`): a nuvem baixa dela é 0,62 da cor da névoa,
contra 66/80/91 da mata toda coberta de névoa ao lado (47/60/72 medido no vão). O
tronco fazia o lado reto, a copa o topo rasgado e o horizonte o pé.

Como se achou:

1. `--estrada-sem=distante`, `beira`, `subbosque` e `cipo` não tiravam os retângulos.
2. `--estrada-sem=mata` tirava.
3. `--sem-ceu` tirava.

A régua foi o pixel medido.

O conserto (`CeuEstrada._erguer_serra`) usa a altura da câmera acima da pista, de
14 a 26 m:

- a serra sobe do horizonte nessa faixa;
- o céu baixo da cúpula se desfaz na névoa (`veu_baixo`).

O plano aéreo (33 a 41 m) fica como estava. Rente ao chão, o fundo é névoa limpa,
que é o que se vê de dentro de uma mata a 54 m de visibilidade.

## Flags

| Flag | Efeito |
|---|---|
| `--mata-caixa` | volta a mata de caixa antiga (A/B) |
| `--estrada-sem=beira,subbosque,distante,mata,detalhes,massa,cipo` | apaga famílias, sem mexer no sorteio do resto |
| `--sem-copa-fina` | copa só grossa na ArvoreEsqueleto |
| `--mat-debug` | cor chapada por material; o impostor e a cúpula ficam com o material deles |
| `--sem-ceu` | esconde cúpula e serra |

## Custo

- **Bancada GPU parada** (`tests/bancada_gpu_mata.tscn`, 4K, mediana de 150
  quadros): lente do carro 2,46 contra 2,21 ms da mata de caixa (+0,25 ms); lado
  2,56 contra 2,31; aérea 2,63 contra 2,33.
- **Montagem por trecho** (`tests/bancada_custo_mata.tscn`, 25/09): 150 ms na
  thread por trecho de 28,8 m, com uns 61 mil triângulos (casca 23 mil,
  vegetação 25 mil, beira 8 mil) e cerca de 320 impostores.

## Arquivos

**Novos:**

- `game/src/world/mata_da_estrada.gd`
- `game/shaders/impostor_arvore.gdshader`, `impostor_assar.gdshader`
- `game/tests/assar_impostores.*`, `bancada_gpu_mata.*`, `bancada_custo_mata.*`
- `tools/montar_impostores.py`, `tools/gerar_quartzito_hd.py`
- `game/assets/impostores/`
- `game/resources/materials/mat_quartzito.tres`
- `textures_hd/quartzito*.png`, `textures/quartzito.png`

**Mudados, cirurgicamente:**

- `estrada_builder.gd`: `_mata`, `_detalhes`, `_dados_do_trecho`, `_pendurar`,
  `MATERIAIS_DE_MATO`, `spawn_toca`.
- `kit_estrada.gd`: `arvore`, `conifera`, `cerca`, `muro_baixo`.
- `ceu_estrada.gd` e `psx_ceu_estrada.gdshader`: a serra e o véu.
- `estilo_visual.gd`: a molhabilidade do quartzito.

## Sobra para apagar

Os atlas antigos de impostor ficaram em `game/assets/impostores/`. O apagamento
foi barrado pela checagem de segurança e ninguém os lê mais. São os `_cor.png`,
`_nrm.png` e `.import` de: `angico_a`, `angico_b`, `embauba`, `sibipiruna`,
`mangueira`, `quaresmeira`, `ipe_amarelo` e `conifera`.

# Plano: os monstros da estrada em 4K AAA

Pedido de 25/09/2026. Tudo o que for feito daqui em diante é **4K AAA**: forma de
verdade, texturas em alta (2K–4K por mapa, com normal e rugosidade) e física de
pano/faixa. Julgamento sempre em captura 4K, de perto.

## Referências

Em [`referencia/`](referencia/):

| arquivo | quem |
|---|---|
| `padre_principal_1_agachado.png`, `padre_principal_2_mesa.png`, `padre_principal_3_rosto.png` | o **padre principal**, debaixo do capuz (a criatura do Mortuary Assistant) |
| `romeiro_enfaixado.png` | **os outros padres** (romeiros, vigias, os da janela, a multidão) |

## Diagnóstico: o que falta hoje

Capturas atuais em [`capturas/05_padre_quebra_e_agarra.jpg`](capturas/05_padre_quebra_e_agarra.jpg)
e na bancada (abaixo).

**Padre principal**
- Não tem rosto. É um buraco preto com dois pontos vermelhos e um sorriso
  desenhado num quad. De perto, na janela, parece um emoji, não dá medo.
- A cabeça é a caixa de 21 cm do `Corpo`. O pedido: **sem cabeça quadrada**.
- Capuz: tubo de anéis rígido com um único material preto chapado. Não tem
  espessura, trama, borda puída, peso nem balanço. Na luz vermelha vira um disco
  laranja liso.
- Mãos e braços (`BracoVivo`, `PELE_DAS_MAOS`): gordos, lisos, cor de pêssego.
  Parecem massinha. O pedido: **finos, podres, nada de branco limpo**.

**Os outros padres**
- O mesmo buraco com pontos e sorriso do padre. Não se distinguem dele.
- O pedido: **rosto enfaixado, sangrado e sujo**, com textura e física (as
  pontas soltas da faixa).

## Alvo

**Padre principal (criatura)**
- Crânio calvo, liso e um pouco alongado.
- Olhos redondos arregalados: esclera suja e íris clara e pequena, dentro de uma
  olheira funda, escura e avermelhada.
- Nariz pequeno e achatado.
- Boca **aberta, escura e torta**, larga demais, com dentes pequenos e amarelos
  e gengiva.
- Pele branco-acinzentada **craquelada** (rede de rachaduras finas), com
  manchas, **veias mortas** (azul-arroxeadas, sob a pele) e sujeira nas dobras.
- Pescoço fino, com tendões.
- Tudo isso dentro do capuz, que ganha pano de verdade.

**Romeiros (enfaixados)**
- Gaze em faixas sobrepostas em volta da cabeça inteira, com relevo de faixa
  sobre faixa.
- Sujeira, sangue seco (marrom) e sangue fresco (vermelho) que escorre das
  frestas.
- Uma fresta mostra **um olho** arregalado e vermelho. Outra mostra **dentes**.
- Pontas soltas que balançam (física).
- Capuz por cima, como hoje.

## Partes

| parte | o quê | quem | arquivos |
|---|---|---|---|
| **0** | Terreno: referências, este plano, ganchos e bancada | esta sessão (**feita**) | `monstro_da_estrada.gd`, `bancada_monstros.gd`, `folha_bancada.py` |
| **1** | **Cabeça do padre**: malha esculpida, pele 4K craquelada com veias, olhos, boca aberta com dentes; mantém `sorriso`/`olhos` animáveis | esta sessão | `game/src/render/cabeca_do_padre.gd`, `tools/gerar_padre.py`, `game/assets/monstros/padre/` |
| **2** | **Capuz e batina de pano**: tecido 4K (trama de lã, molhado, puído, borda rasgada), espessura, física Verlet do capuz, da murça e da barra | esta sessão | `game/src/render/capuz_macabro.gd` e arquivo novo de pano |
| **3** | **Braços e mãos podres**: `BracoVivo` do padre fino, dedos longos e ossudos, unha escura, pele necrosada 4K (a mesma do rosto), manga rasgada; e os braços do corpo do padre | esta sessão | `game/src/render/braco_vivo.gd` (só por parâmetro), arquivo novo |
| **4** | **Romeiros enfaixados**: cabeça enfaixada 4K, sangue e sujeira, olho e dentes pela fresta, pontas soltas com física; versão barata na `MultidaoEncapuzada` | **sessão paralela** | `game/src/render/rosto_enfaixado.gd`, `tools/gerar_faixas.py`, `game/assets/monstros/romeiro/`, `game/src/render/multidao_encapuzada.gd` |

Ordem: 1 → 2 → 3 aqui. A 4 corre em paralelo desde já.

### Parte 1: estado (25/09)

**Feito**
- `tools/gerar_padre.py` gera a cabeça esculpida por SDF, com crânio, órbitas
  sem pálpebra, nariz pequeno, boca larga e torta com dentes e gengiva, orelhas
  e pescoço com tendões. Saem ~170 mil triângulos de pele e ~80 mil de boca.
- Saem também duas texturas 4K tileáveis:
  - `pele_mapa`: craquelê em duas escalas, veias, manchas e poros;
  - `pele_n`: a normal.
- Por vértice vão olheira, lábio, goela, oclusão, peso da queixada e onde a veia
  aparece.
- `CabecaDoPadre` monta a cabeça com três shaders próprios (pele em triplanar,
  dentes e olho) e liga a abertura da boca ao `sorriso` pela queixada, que gira
  no shader.
- Os olhos são globos com esclera injetada, íris escura e verniz. De longe
  (> 2,6 m) acende o ponto vermelho em billboard, para o farol.
- Os parâmetros de ajuste estão no topo do shader. Para refazer a forma, edite o
  SDF em `cabeca()` e rode `python tools/gerar_padre.py --so-malha --previa DIR`.
  O `DIR/frente.png` e o `DIR/lado.png` saem em 8 s.

**Medido**
- **Capturas:**
  - [capturas/parte1_bancada.jpg](capturas/parte1_bancada.jpg), da esquerda
    para a direita: a boca em repouso (`sorriso=0`, o sorriso torto), a boca aberta de todo
    (`sorriso=1`, a queixada caída, que a janela anima), a luz neutra e a
    referência;
  - [capturas/parte1_na_estrada.jpg](capturas/parte1_na_estrada.jpg): janela,
    mãos, agarrada e farol.
- **GPU a 4K**, A/B no mesmo dia com `--sem-cabeca-padre`:
  - janela: 9,0 → 9,6 ms;
  - mãos: 10,4 → 11,0 ms;
  - estouro: 8,8 → 9,4 ms.

  **+0,6 ms.**

**O que fica para as próximas partes**
- **Parte 2:**
  - o capuz ainda é o tubo rígido feito para a caixa, e a boca dele fica 9 cm à
    frente do rosto;
  - na agarrada a lente entra no capuz e o rosto aparece "fora" dele;
  - a gola octogonal do `Corpo` aparece debaixo do queixo no farol de perto.
- **Parte 3:** as mãos continuam cor de pêssego e grossas.

### Parte 2: estado (25/09)

**Feito**
- **Pano simulado na placa** ([`PanoGPU`](../game/src/render/pano_gpu.gd)):
  - cada peça é uma grade de até 1024 partículas;
  - um compute shader por peça (um grupo) integra por Verlet, em 6 subpassos ×
    6 iterações de Jacobi na memória compartilhada;
  - por partícula, depois das ligações: âncora de alcance (o pano não estica),
    folga em volta do repouso esfolado no osso (a forma), cápsulas nos ossos
    (cabeça, pescoço, peito, barriga, quadril, braços, pernas), a lente e o
    chão;
  - sai em duas imagens (posição e normal em octaedro com o aperto u/v) que o
    shader de vértice lê, com Catmull-Rom e a grade subdividida em 2.
- **As três peças** ([`CapuzMacabro.vestir_pano`](../game/src/render/capuz_macabro.gd)),
  todas na medida do corpo (perfil do tronco do `Corpo`) e da cabeça de baixo
  (`elipsoide()` do rosto, ou a caixa):
  - **capuz** 32×24: nasce no ombro, abraça o pescoço (preso ali, girando do
    torso para a cabeça), boca oval 3 cm atrás da ponta do nariz, cortada por
    fragmento com borda roída e bainha, e ponta de capuz de monge que balança;
  - **murça** 40×12, do colarinho sobre os ombros, com pano sobrando na barra;
  - **batina** 40×25, da cintura ao chão, com cauda que deita no barro.
- **Lã 4K** ([`tools/gerar_pano.py`](../tools/gerar_pano.py), 17 s):
  - sarja 2/2 de fio fiado à mão (grosso e fino, cada fio num tom), fibra,
    penugem, feltro onde esfrega, bolinhas e furos de traça;
  - `pano_mapa` (altura, tom, desgaste, furo) e `pano_n`;
  - no shader: molhado, barro subindo da barra, forro escuro por dentro,
    rugas onde o pano aperta (a grade de 3–4 cm não dobra sozinha) e furos.
- `--sem-pano` desliga (A/B).
- Consertos de caminho:
  - o padre sai e volta para a árvore na janela: o pano só libera a placa no
    `PREDELETE`;
  - a caixa de corte segue o tronco, e não a raiz;
  - as cápsulas andam interpoladas nos subpassos, como o repouso. Pulando o
    quadro inteiro no primeiro subpasso, o estalo do pescoço passava a cabeça
    por baixo da murça, que ficava por cima dela (achado da Parte 4);
  - do pescoço para baixo o capuz é só do torso. Com a cabeça quase do avesso,
    a barra do capuz atravessava a murça pela frente;
  - a bancada roda o tique depois do `animar`, como a estrada. Antes, a
    `--rajada` não mostrava tique nenhum.

**Medido**
- **Capturas:** [capturas/parte2_pano.jpg](capturas/parte2_pano.jpg). Em cima,
  a bancada no farol (frente, 3/4, perfil); embaixo, a estrada (janela, vem,
  agarra).
- **Rajada de 4 s** na bancada: o pano assenta, sem tremer e sem explodir.
- **GPU a 4K**, `--sem-pano` × com pano no mesmo dia, intercalado (uma rodada
  "com" foi descartada porque cruzou com a fila da Parte 4: +5 ms até na
  conversa):

  | trecho | sem pano | com pano |
  |---|---|---|
  | romeiros | 8,0 / 8,0 | 8,1 |
  | janela | 9,1 / 9,4 | 9,6 |
  | mãos | 10,6 / 11,0 | 11,0 |
  | estouro | 8,8 / 9,2 | 9,3 |

  **+0,2 a +0,5 ms.**
- **Montagem** (GDScript, uma vez por figura, debaixo do preto do começo): o
  pior quadro do trecho `inicio` foi de 3,37–3,43 s para 3,50 s, cerca de
  +0,1 s. A VRAM subiu 55 MB (as duas texturas 4K da lã).

**O que fica**
- O pano não colide com o outro pano. O capuz segue a forma da murça 1,5 cm
  acima, e a folga é pequena o bastante para não atravessar.
- Os vetores de movimento não sabem do pano: o vértice vem da textura. Com TAA,
  ele pode deixar rastro.
- Os romeiros usam a caixa do `Corpo` até a Parte 4 expor
  `RostoEnfaixado.elipsoide()`.

### Parte 3: estado (25/09)

**Feito**
- **Forma** ([`MaosPodres.FORMA`](../game/src/render/maos_podres.gd)), que a
  `MaoModelada` usa só enquanto monta um `BracoVivo` com `forma`. A mão do
  jogador não muda: com `forma` vazio todo fator é 1.
  - dedo 30% mais comprido e tudo 30% mais fino;
  - palma estreita e de seção elíptica;
  - falange que afina no meio, com o nó crescido (o osso sob a pele);
  - unha de garra que passa da ponta e curva para baixo.
- **Material:**
  - a mesma pele 4K da cabeça (craquelê, veia, mancha), presa na coordenada
    de pele do tubo: não nada quando o braço se refaz a cada quadro;
  - ponta do dedo necrosada e terra na palma e na ruga;
  - unha amarelo-marrom com terra;
  - manga na lã 4K das batinas.
- **O corpo:** a mão do `Corpo` de longe passou de cera a cinza-esverdeado
  (`PELE_DE_CERA`).
- `--maos-de-gente` desliga (A/B).

**Medido**
- **Capturas:** [capturas/parte3_maos.jpg](capturas/parte3_maos.jpg), antes à
  esquerda e depois à direita (as mãos no vidro e a agarrada).
- **`--sonda-banco`** mede os braços do *motorista* contra os bancos. Hoje ele
  já não está em 0: 3,7 cm no encosto, igual com e sem as mãos podres. Não é
  desta parte.

### Parte 4: estado (25/09)

**Feito**
- **Cabeça de faixas de malha** ([`RostoEnfaixado`](../game/src/render/rosto_enfaixado.gd)):
  - o crânio tem testa, nariz, maçãs, queixada estreita e queixo, com o
    cocuruto largo (superelipse);
  - 14 voltas de atadura, cada uma uma faixa de latitude em volta de um eixo
    torto, com espessura, borda enrolada e franja de fio solto. A de cima fica
    0,85 mm acima da de baixo, e a sombra de uma na outra vai por vértice;
  - as frestas são o vão entre faixas:
    - o olho aparece na lente que as faixas A (em cima), B (embaixo) e E (na
      têmpora) deixam;
    - os dentes aparecem no rasgo entre C e D, que se fecham nos cantos e
      sobem (o sorriso);
    - `_desobstruir` afasta toda outra faixa das frestas;
  - quatro variantes (o lado do olho × o desenho das faixas), montadas uma vez
    e divididas por todos: ~36 mil triângulos com LOD e ~230 ms cada no
    carregamento.
- **Olho:**
  - globo de 12,5 mm com córnea, esclera injetada, íris pálida e pupila
    miúda;
  - salta 4,5 mm da órbita, que é carne inchada e viva;
  - segue a lente até 0,45 rad;
  - `por_olhos` acende a pupila de longe. O ponto vermelho em billboard nasce
    entre 1,6 e 3,4 m e cresce com a distância (farol, janela).
- **Dentes:**
  - um a um, tortos, alguns faltando, alguns de ponta;
  - marrom na raiz e amarelo no meio;
  - a fila de baixo e a faixa do queixo giram com `por_sorriso`.
- **Pontas soltas:**
  - duas por cabeça (queixada e embaixo do canto da boca), em Verlet próprio
    a 90 Hz;
  - colidem com a cabeça e com o peito;
  - a fita é desenhada no shader a partir de uniformes (nenhuma malha refeita
    por quadro);
  - só simula a menos de 9 m da lente;
  - custa 0,01 ms por passo por romeiro.
- **Texturas** ([`tools/gerar_faixas.py`](../tools/gerar_faixas.py), em
  `game/assets/monstros/romeiro/`):
  - a gaze fio a fio em 4096×2048 (albedo com a franja no alfa, normal,
    rugosidade), com duas linhas: a inteira e a gasta com rasgo;
  - `manchas` 2K no espaço da cabeça: sangue seco com linha de maré, sangue
    fresco escorrendo das frestas, barro com marca de mão, soro;
  - olho 1K e carne 1K.
- **Multidão** ([`MultidaoEncapuzada`](../game/src/render/multidao_encapuzada.gd)):
  - o fundo preto virou uma calota oval (96 triângulos) com a foto da cabeça
    de verdade, [`rosto_multidao.png`](../game/assets/monstros/romeiro/rosto_multidao.png),
    assada por `tests/assar_rosto_multidao.gd`;
  - cada figura espelha a foto ao acaso;
  - acende só o olho da fresta (um billboard por figura, como nos romeiros).
- **Gancho `elipsoide()`**: o capuz de pano se ajusta ao crânio enfaixado.
- **Bancadas novas:**
  - `scenes/test/bancada_pontas_romeiro.tscn`: rajada com o tique de verdade
    e o custo da física;
  - `scenes/test/assar_rosto_multidao.tscn`.

**Medido**
- **Capturas:**
  - [capturas/parte4_bancada.jpg](capturas/parte4_bancada.jpg): janela na luz
    do painel, janela no farol, 3/4 no farol e a referência;
  - [capturas/parte4_na_estrada.jpg](capturas/parte4_na_estrada.jpg): os
    romeiros e a multidão na beira da pista, um dos cinco da janela com a faixa
    e o olho aceso no fogo, e os de perto na névoa.
- **GPU a 4K**, RX 9070 XT, `--medir-quadros`, A/B no mesmo dia:
  - B é o stub mais a multidão antiga; A é tudo novo; C é só o rosto novo;
  - primeira rodada, com a calota de 360 triângulos: batida +0,4 ms e fogo
    +0,7 ms, e só na multidão (C = B);
  - com a calota de 96 triângulos (A4 contra B4):

    | trecho | A4 | B4 |
    |---|---|---|
    | batida | 8,6 | 8,6 |
    | fogo | 8,7 | 8,7 |
    | janela | 9,8 | 9,4 |
    | mãos | 11,1 | 11,1 |
    | estouro | 9,0 | 9,2 |

  - **Custo: zero fora da janela e até +0,4 ms na janela**, que está no ruído
    de ±0,2 ms entre rodadas. C3 contra B3 na janela deu 0,0.
  - A rodada A3 foi descartada: outra janela de Godot abriu no meio dela e a
    GPU subiu 3 ms em tudo.

**O que falta**
- A referência tem faixas mais estreitas (~2,5 cm) e muitas mais voltas
  cruzadas; aqui são 4,6 cm e 14 voltas.
- A carne em volta do olho é menor e menos laranja que na referência.
- A `BancadaMonstros` chama `TiqueMacabro.passo` ANTES de `Corpo.animar`: a
  rajada dela não mostra o tique. Para as pontas, use
  `bancada_pontas_romeiro.tscn`.
- Os olhos de longe da multidão eram dois por figura e agora são um.
  `lado != espelho(s)` no `OLHO_SHADER` da multidão volta aos dois.

## Ganchos (Parte 0, prontos)

- **`MonstroDaEstrada.vestir(c, i, largura, grande)`**
  ([monstro_da_estrada.gd](../game/src/render/monstro_da_estrada.gd)). É o único
  caminho que veste um encapuzado. A abertura (`AberturaEstrada._encapuzado`) e a
  bancada chamam essa função. Ela põe o capuz e, embaixo dele,
  `CabecaDoPadre.vestir` (se `grande`) ou `RostoEnfaixado.vestir` (se não).
  - Se o rosto devolve **null**, nada muda: continua o buraco preto.
  - Se devolve um nó, o capuz chama `abrir_para_rosto(rosto)`. Isso tira o
    fundo preto, os pontos, a luz e a boca de quad, e passa a repassar
    `capuz.sorriso` → `rosto.por_sorriso(v)` e `capuz.olhos`/`olhos_tamanho` →
    `rosto.por_olhos(forca, tamanho)`.
  - Por isso a abertura não precisa mudar: ela continua escrevendo no capuz.
- **`MonstroDaEstrada.no_da_cabeca(c, nome)`**: some com a cabeça de caixa (o
  osso da cabeça fica com escala 0,001) e devolve um `Node3D` no espaço do osso
  da cabeça, já no tamanho certo.
  - Pendure o rosto nele e use `c.plano_do_rosto()` para achar a frente (−Z).
  - O capuz, que também está pendurado nesse osso, é desencolhido junto.
- Stubs com a assinatura final:
  [cabeca_do_padre.gd](../game/src/render/cabeca_do_padre.gd) e
  [rosto_enfaixado.gd](../game/src/render/rosto_enfaixado.gd).

## Bancada de close

```bash
G=.tools/Godot_v4.7.2-stable_win64_console.exe
$G --path game --resolution 3840x2160 res://scenes/test/bancada_monstros.tscn -- \
   --fotos=DIR [--quem=padre|romeiro|ambos] [--luz=neutra|janela|farol|todas] \
   [--sorriso=0..1] [--sem-capuz] [--rajada=SEGUNDOS] [--so=rosto_frente,janela]
python tools/folha_bancada.py DIR DIR/folha.png [filtro] [colunas] [largura]
python tools/mosaico_rajada.py DIR/rajada_padre 0 3 DIR/raj.png
```

- **Planos:** `rosto_frente`, `rosto_34`, `rosto_perfil`, `rosto_baixo` (a
  0,55 m), `janela` (a pose curvada da janela, a 0,45 m), `busto`, `corpo` e
  `farol` (14 m).
- **Luzes:**
  - `neutra`: para julgar forma e textura;
  - `janela`: o vermelho do painel com o fogo;
  - `farol`: o facho.
- `--rajada` fotografa o busto a 10 fps com o tique rodando. Serve para julgar
  pano e faixa em movimento.
- A palavra final é sempre na estrada
  (`--ver-estrada --estrada-corrida --estrada-desde=dentro --susto-fotos=...`,
  ver [HANDOFF.md](HANDOFF.md)).

## Regras de convivência

- **Parte 4 só toca:**
  - `rosto_enfaixado.gd`;
  - `multidao_encapuzada.gd`;
  - arquivos novos seus (`tools/gerar_faixas.py`, `game/assets/monstros/romeiro/`).

  **Não toca:**
  - `capuz_macabro.gd`;
  - `cabeca_do_padre.gd`;
  - `braco_vivo.gd`;
  - `monstro_da_estrada.gd`;
  - `abertura_estrada.gd`;
  - `corpo.gd` (tem WIP de outra frente).

  Se precisar de algo nesses arquivos, peça.
- **Partes 1–3 não tocam** `rosto_enfaixado.gd` nem `multidao_encapuzada.gd`.
- `corpo.gd`, `convidado.gd` e outros arquivos têm WIP alheio. Não toque neles.
  Não use `git add` em arquivo misto (ver memória
  `sessoes-paralelas-no-repo`).
- Classe nova pede `--import` antes de rodar.
- Heredoc do bash sem acento. Use `python`, não `python3`.
- **Desempenho:** a cena roda a ~110 fps em 4K (ver ESTADO.md). O rosto do padre
  é um só e pode ser caro. Os romeiros são 14 figuras + 3 vigias. A multidão tem
  440 figuras e precisa continuar barata (textura no `MultiMesh`, sem malha
  nova por figura).

## Critérios de pronto (por parte)

1. **Cabeça do padre**
   - Na bancada, `rosto_frente` / `rosto_34` / `janela` nas três luzes, lado a
     lado com `padre_principal_3_rosto.png`, lê como a criatura. Isso quer dizer:
     - olhos redondos em olheira;
     - boca aberta escura com dentes;
     - rachaduras visíveis a 0,5 m;
     - nenhuma quina de caixa.
   - Na estrada, `05_padre_quebra_e_agarra` mostra o rosto no vidro.
   - Custo de GPU da janela ≤ +1 ms.
2. **Capuz**
   - Trama e borda puída visíveis a 0,5 m.
   - Na rajada, o pano balança com o tique e assenta, sem atravessar a cabeça
     nem o ombro.
   - Na foto `farol`, a silhueta continua de capuz de monge.
3. **Mãos**
   - Na foto `05`, as mãos são finas, com nó dos dedos e unha escura.
   - A cor é cinza-esverdeada podre, não pêssego.
   - `--sonda-banco` continua em 0.
4. **Romeiros**
   - Na bancada, `romeiro_rosto_*` lê como `romeiro_enfaixado.png`.
   - Na rajada, as pontas soltas balançam.
   - Na estrada, os cinco da janela (`FORA_DA_JANELA`) mostram faixa e olho no
     fogo.
   - A multidão continua sem custo novo perceptível: `--medir-quadros` antes e
     depois.

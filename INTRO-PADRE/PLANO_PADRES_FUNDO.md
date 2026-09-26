# Padres de fundo da abertura da estrada (25/09, psx-ce)

## O pedido do usuário

> Os padres que andam atrás estão mal polidos e fracos. Esse tick que eles têm
> está ruim. Coloque os braços reais com as grandes mãos neles, e a cabeça real
> também. Eles devem ter um caminhar melhor, que dê mais medo, tratado AAA.
> Hoje eles ficam só piscando, feios, no fundo. Se possível, de forma
> otimizada, multiplique o número de padres que aparecem perto do carro,
> rodeando.

Vale a regra da casa, "4K AAA", para textura, forma e física (memória
`padre-monstro-4k-aaa`). O usuário julga por prints e rajadas, e manda
críticas curtas no meio do trabalho.

## O que a captura de 25/09 às 23h15 mostra

A captura é a rajada `--estrada-desde=dentro` do snapshot `c7b544f`.

**Onde os de fundo aparecem:**
- de 17 a 19 s, pelo para-brisa, depois da batida;
- de 24 a 28 s, no fogo;
- na janela, de 37 a 47 s, atrás do principal.

**Os defeitos:**
- **O pisca.** Em `_assombrar`, os corpos com `i % 3 == 0` somem por 0,05 a
  0,16 s e voltam 35 cm mais perto. A `MultidaoEncapuzada` faz o mesmo no
  shader (`piscando`). Na tela isso é flicker.
- **O tique estalado.** O `TiqueMacabro` no modo `FUNDO` e o `estalando` do
  shader da multidão fazem estalos contínuos de cabeça e braço em todos, o
  tempo todo. O resultado é ruído, e não medo. No fogo aparece um de fundo com
  o braço duro para cima.
- **O corpo.** De pé, o romeiro é uma coluna de batina com murça. Os
  `BracosPodres` ficam dentro do pano e não aparecem. O rosto é a faixa
  (`RostoEnfaixado`).
- **O andar.** O corpo desliza (`global_position +=`) com a pose de andar
  embaixo da saia longa. Não há peso nem manqueira.

## Quem é de quem

- **psx-0d** cuida do padre do capô (romeiro 9), do da direita (7), do de trás
  (13), da meia-lua da janela (0 a 4) e do da janela do carona (3). Os
  arquivos dela são `cerco_no_carro.gd`, `padres_nas_janelas.gd` e a lente do
  capô.
- **psx-d6** é dona da árvore principal. Cuida da etapa 3 (o agarrão) e do
  padre principal. Em `abertura_estrada.gd` ela mexe em:
  - `_padre_cabeceia` do estouro em diante;
  - `_encarar`, `_agarrar_e_puxar` e `_ao_branco`;
  - `_de_dentro`;
  - o laço das `_maos_padre`.
- **Esta frente (psx-ce)** cuida dos romeiros 5, 6, 8, 10, 11 e 12, dos três
  vigias, da `MultidaoEncapuzada` e dos padres novos em volta do carro. O
  jeito de andar, o tique, a cabeça e os braços valem para todos os
  encapuzados, menos o principal e os que estão no cerco (`meta cerco`). A
  coreografia da meia-lua continua da psx-0d.

**Não mudar:**
- a assinatura de `BracosPodres.vestir`;
- os nomes dos nós `BracoPodreE` e `BracoPodreD`, que a psx-0d apaga pelo nome
  quando entra o `BracoVivo`;
- a ordem em `_assombrar`: `_cabecada.aplicar()` fica depois de `c.animar()` e
  de `tique.passo()` do padre principal.

## As três frentes, cada uma na sua worktree

Todas saem do snapshot `c7b544f`, que é a base do merge de três vias, e cada
uma tem o seu `.godot` copiado.

| frente | worktree | arquivos |
|---|---|---|
| A. andar, pisca, tique e roda em volta do carro | `PSX_fundo_a` | novo `src/render/andar_macabro.gd`, novo `src/levels/roda_de_padres.gd`, `tique_macabro.gd` (só o modo FUNDO); em `abertura_estrada.gd`, só `_assombrar`, `_montar_elenco`, `_encapuzado`, as constantes do pisca e do andar e os ganchos da roda |
| B. cabeça real, braços reais e mãos grandes | `PSX_fundo_b` | `bracos_podres.gd`, `monstro_da_estrada.gd`, `capuz_macabro.gd` (murça e manga) e `bancada_monstros.gd`; `cabeca_do_padre.gd` só se for inevitável, avisando antes (tem WIP do gore) |
| C. multidão | `PSX_fundo_c` | `multidao_encapuzada.gd`, `tests/assar_rosto_multidao.gd` e, em `abertura_estrada.gd`, só `_espalhar_multidao`, `_andar_multidao` e as constantes `MULTIDAO_*` |

A integração é feita pela psx-ce na worktree `PSX_fundo`. A volta para a
principal é por três vias contra o `c7b544f`, avisando a psx-d6 antes.

## A direção (o que é "dar medo" aqui)

- **Sem pisca e sem estalo contínuo.** O medo vem do corpo que anda errado e
  do olhar fixo.
- **O andar.**
  - Lento e pesado, arrastando uma perna (`Corpo.mancando` e `perna_ruim`).
  - O tronco curvado para a frente, com o balanço dos ombros a cada passo.
  - A cabeça pesada, meio caída de lado, mas os olhos cravados no carro.
  - Os braços compridos pendurados fora da manga, com as mãos grandes
    balançando atrasadas, em pêndulo, como peso morto.
  - Cada um num ritmo, e nenhum em passo sincronizado.
- **Eventos raros e legíveis, no lugar do ruído.** Não há estalo de fundo
  contínuo; tudo acontece de vez em quando e um por vez no grupo:
  - um para de repente e ergue a cabeça para a lente;
  - um entorta o pescoço devagar até quase 90° e fica assim;
  - uma mão abre e fecha os dedos.
  - O estalo de osso fica reservado a esses momentos.
- **Andam quando não são olhados.**
  - Fora do quadro da lente, avançam mais depressa.
  - Dentro do quadro, quase param.
  - A cada corte a lente volta e eles estão mais perto. É isso que substitui o
    "pisca e avança".
- **A roda.** Depois da batida, de 10 a 16 padres de corpo inteiro em volta do
  carro, a 3 a 10 m, girando devagar e fechando o cerco. Eles são vistos pelo
  para-brisa, pelas janelas e pelo retrovisor. Além de 10 m, a multidão
  melhorada (a mesma cabeça e os mesmos braços, sem pisca), mais densa perto
  do carro.

## Desempenho

A meta é zero queda de quadro (memória `seja-direto`).
- Tudo nasce em `_montar_elenco`, debaixo do preto do começo.
- As pipelines se aquecem na lente (`aquecer`).
- Toda adição se mede em par, antes e depois, na mesma rodada:
  `--medir-quadros --gpu-passos` a 4K. A máquina tem duas placas e outras
  sessões rodam Godot ao mesmo tempo; número de rodada isolada não vale.
- A psx-0d mediu cerca de 13 ms de GPU a 4K no ataque, contra 8 a 9,5 ms antes.
  Não piore isso sem nomear o custo.

## Captura de referência (antes)

`C:/Users/ADMINI~1/AppData/Local/Temp/claude/c--Users-Administrator-Documents-Codes-Games-PSX/9adae52a-b195-45f6-a31b-65da15e595f3/scratchpad/antes/`

- `mos_15_34.png` e `mos_34_48.png`: mosaicos da rajada;
- `fundo_6.png` e `janela_6.png`: quadros dos de fundo;
- `banc/grade.png`: o romeiro na `bancada_monstros`.

## Comandos

```
G=C:/Users/Administrator/Documents/Codes/Games/PSX/.tools/Godot_v4.7.2-stable_win64_console.exe
# a cena, do susto em diante, com rajada (640x360 a cada 0,1 s)
$G --path game --resolution 1920x1080 -- --ver-estrada --estrada-corrida --estrada-desde=dentro --susto-rajada=DIR
# a mesma cena, medindo
$G --path game --resolution 3840x2160 -- --ver-estrada --estrada-corrida --estrada-desde=dentro --medir-quadros --gpu-passos --sair-no-fim
# de perto
$G --path game --resolution 3840x2160 res://scenes/test/bancada_monstros.tscn -- --fotos=DIR --quem=romeiro --luz=todas [--rajada=S]
python tools/mosaico_rajada.py DIR/r T0 T1 SAIDA.png 5 30
```

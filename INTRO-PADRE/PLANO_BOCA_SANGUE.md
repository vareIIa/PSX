# Plano: a boca do padre, os dentes quebrando e o sangue cuspido na tela

Frente da sessão **psx-2f** (26/09/2026). Trabalho na worktree `PSX_boca`, saída de
`232344f`. Volta para a principal por três vias, avisando a psx-0c (P.O. da
abertura) e a psx-0d antes e depois. Sem commit sem o aval do usuário.

## O pedido

> A boca não tem dentes e não parece boca. Os dentes quebram a cada cabeçada. Na
> hora em que o vidro finalmente estoura e ele fala com a gente, tem vários dentes
> quebrados, sangra muito e cai sangue da boca enquanto fala. Ele cospe sangue
> AAA, que respinga na tela.

## O que existe hoje (bancada 4K de 26/09, `bancada_gore_janela --so=boca,d0..d3`)

- **Pele e lábio** (`cabeca_do_padre.gd`, `PELE_SHADER`): a borda da boca é a máscara
  `labio` pintada quase preta (0,10; 0,045; 0,042) a 92 %, e a parede de dentro
  (`goela`) é preta. Resultado: um anel preto liso em volta de um buraco. Não há
  lábio seco por fora, nem mucosa molhada por dentro, nem espessura de lábio.
- **Boca de dentro** (`boca_vit.glb`, o Vitruvian do CharMorph): 2 metades de
  gengiva com 2 228 vértices cada, língua com 553 e **64 peças de dente com 68
  vértices cada**. Os dentes lêem como plástico. A fileira de baixo quase não
  aparece: ela fica atrás do lábio de baixo e da língua, e nos lados sai
  azulada e fantasma. Nos cantos, em cima, aparecem dois triângulos pretos,
  vãos entre a pele e a gengiva. A língua é enorme, lisa, vermelho-vivo e tapa
  a boca.
- **Dano** (`por_dano 0..3`): o `BOCA_SHADER` só escurece a cor com o dano e com o
  amassado. **Nenhum dente quebra.** No d3 a fileira de cima continua inteira e
  limpa.
- **Roteiro** (`abertura_estrada.gd`):
  - `_cabecada_gore(g)` anima `por_dano` de g a g+1 em 45 ms, no quadro do golpe;
  - o estouro é seguido de `_encarar` (1,6 s calado, pingando do queixo);
  - depois vem `AgarraoDoPadre.rodar()`, em que ele fala "que bom que você veio"
    (`FALA_QUE_BOM`, 2,04 s) com a mão na cara do motorista (o rosto fica no terço
    esquerdo), empurra, puxa e dá a cabeçada final, com o branco.
- **Quem usa a `CabecaDoPadre`**: o principal, o do capô (`cerco_no_carro.gd`, que
  também chama `por_dano`), o do carona (`padres_nas_janelas.gd`) e os de fundo
  (`CabecaDeFundo`, que herda dela e monta a própria boca, barata e dividida).

## Divisão

### Parte 1 — a boca de verdade e os dentes que quebram a cada cabeçada

Da janela ao estouro. Entrega a boca que o stare e a fala vão usar.

1. **Arcada nova, gerada** (`tools/gerar_boca_padre.py`, SDF e marching cubes, o
   mesmo caminho do `gerar_padre.py`):
   - 12 dentes em cima e 12 embaixo, até os pré-molares, para os cantos não
     ficarem vazios;
   - cada dente tem a forma do seu tipo (incisivo em cinzel, canino de ponta,
     pré-molar de duas cúspides), raiz, colo e a câmara da polpa;
   - dentes tortos e desiguais, de gente morta: gengiva retraída, dente
     comprido;
   - **pré-fratura por dente**, por um plano serrilhado com ruído: `inteiro`,
     `lascado` (canto da coroa fora) e `toco` (coroa partida, com dentina e o
     ponto da polpa na face da quebra). As lascas saem como malhas soltas;
   - gengiva de cima e de baixo, com papila entre os dentes e o alvéolo de cada
     dente (é o buraco que aparece quando o dente sai);
   - língua nova, menor e mais baixa, com o sulco do meio, deitada atrás da
     fileira de baixo;
   - texturas 4K procedurais:
     - esmalte amarelo no meio, marrom no colo e translúcido na borda;
     - tártaro, trincas de esmalte e manchas;
     - dentina e polpa na face da quebra;
     - gengiva pontilhada com vasinhos;
     - papilas da língua;
     - normal e rugosidade de tudo.
2. **`DentesDoPadre`** (arquivo novo, `game/src/render/dentes_do_padre.gd`):
   - todos os dentes numa malha e numa chamada de desenho. O estado de cada dente
     é um uniforme (`inteiro`, `lascado`, `partido`, `arrancado`), e a versão que
     não vale some no vertex shader;
   - a fileira de baixo, a gengiva de baixo e a língua giram com a queixada pela
     mesma conta da pele (`QUEIXADA`, `PIVO`, `GIRO_QUEIXADA`). Hoje a boca de
     dentro é um morph calibrado a olho;
   - os amassados de `por_dano` também empurram os dentes (`AMASSO`);
   - a queixada tem um limite de fechamento: o visema M não enfia um dente no
     outro;
   - **quebra roteirizada por golpe**, disparada quando `por_dano` cruza o
     inteiro. Não precisa de linha nova no roteiro:
     - golpe 1: o incisivo central esquerdo lasca e o lateral direito parte;
     - golpe 2: o central direito parte, o esquerdo vira toco, um incisivo de
       baixo sai inteiro (fica o alvéolo sangrando) e o canino esquerdo lasca;
     - golpe 3, o estouro: o lateral esquerdo sai, o canino direito parte, o
       lateral de baixo parte, o canino de baixo lasca e um pré-molar parte.
       No stare ficam 11 dos 24 dentes quebrados;
   - **as lascas voam**: 2 a 6 por golpe, com física própria (gravidade, quique e
     atrito). Nos golpes 1 e 2 elas batem no vidro por fora e escorregam por ele,
     e algumas ficam grudadas no sangue do vidro. No 3 entram com os cacos e caem
     no parapeito;
   - **sangue na boca por nível**:
     - o dente vai sujando do colo e dos vãos para a coroa;
     - o toco e o alvéolo ficam cheios de sangue;
     - a gengiva sangra;
     - o chão da boca empoça (uma superfície de líquido com nível).
3. **Lábio e parede da boca** (`PELE_SHADER`):
   - por fora, o lábio seco e rachado, roxo-acinzentado;
   - por dentro, a mucosa molhada vermelho-escura, que só escurece para preto no
     fundo;
   - sangue no lábio a cada golpe;
   - o lábio de cima partido no golpe 2 (um talho a mais no `rosto_gore`, da lista
     `CORTES`).
4. **Som**: `dente_quebra_1..3` (o estalo de esmalte por cima do `nariz_quebra`) e
   `dente_cai` (a lasca batendo no vidro e no plástico), em
   `tools/gerar_audio_cabecada.py`.
5. **Validação**:
   - bancada 4K a 0,30 m (`boca_d0..d3`, frente e três quartos) e close da
     arcada a 0,12 m;
   - rajada 4K da cena (`--susto-rajada`, `--susto-cheio`), da janela ao stare;
   - o capô e o carona conferidos por foto, porque também quebram dentes quando
     `por_dano` sobe;
   - GPU medida com `--medir-quadros --sair-no-fim`.
6. **A/B por flag**: `--boca-velha` volta ao Vitruvian, e `--dentes-inteiros` não
   quebra nenhum.

### Parte 2 — a fala sangrando e o cuspe na tela

Do estouro ao branco.

1. **Boca cheia de sangue**: a poça sobe até transbordar no lábio de baixo e
   balança com a queixada e com a fala.
2. **Sangue caindo da boca**:
   - filetes contínuos pelos cantos e pelo lábio de baixo, em fios de Verlet
     com espessura, que soltam gota;
   - baba de sangue: fios entre os lábios que esticam quando a boca abre (visemas
     A e O) e arrebentam;
   - o pingo do queixo (`GoreDeCabecada.pingar`) mais grosso e mais frequente.
3. **O cuspe**:
   - nas plosivas e labiais da frase ("que **b**om", "**v**ocê", "**v**eio") e
     num escarro no fim;
   - cada um tem névoa de centenas de gotículas, 3 a 6 gotas grandes e um
     coágulo, às vezes com um caco de dente;
   - balístico, na direção da lente, sincronizado com a trilha da fala. O
     gatilho sai da própria `falar()`.
4. **`SangueNaLente`** (arquivo novo): toda gota que cruza o plano da lente vira
   respingo na tela, acumulado num viewport que não limpa. O respingo tem:
   - espessura;
   - refração do quadro por trás;
   - borda escura e brilho de molhado;
   - névoa fina;
   - gota grande que escorre com rastro;
   - sangue que escurece e coagula com o tempo.
   Fica até o branco. O `SANGUE_NA_VISTA` do golpe final (agarrão) passa a
   depositar no mesmo acumulador.
5. **Voz molhada**: uma versão da fala com gargarejo e borbulha de sangue na
   garganta (edge-tts Antônio mais tratamento), e os sons de cuspe e de gota
   batendo.
6. **Validação**:
   - rajada 4K da frase, em quadro cheio;
   - conferir que a boca aparece pela beira da mão, no terço esquerdo;
   - o respingo julgado em recorte de resolução cheia;
   - GPU (o acumulador e a refração são passes de tela cheia).

## Arquivos e donos

| Arquivo | Parte | Como |
|---|---|---|
| `tools/gerar_boca_padre.py`, `assets/monstros/padre/boca/*` | 1 | novos |
| `game/src/render/dentes_do_padre.gd` | 1 | novo |
| `game/src/render/cabeca_do_padre.gd` | 1 e 2 | ligação: `_montar`, `por_dano`, `_aplicar_boca`, lábio do `PELE_SHADER` |
| `game/src/levels/bancada_gore_janela.gd` | 1 | fotos novas da boca |
| `tools/gerar_audio_cabecada.py` | 1 | sons novos |
| `abertura_estrada.gd` | 1 | uma linha: o plano do vidro para as lascas (`_padre_cabeceia`) |
| `game/src/render/sangue_na_lente.gd`, `cuspe_de_sangue.gd` | 2 | novos |
| `agarrao_do_padre.gd` | 2 | ligação mínima, se precisar (o gatilho sai da `falar`) |

`CabecaDeFundo` (os de fundo) fica com a boca barata de hoje na Parte 1.

## Estado em 26/09, ~23h30

- **Parte 1:** feita e na principal (c7074f7), sem push:
  - os dentes;
  - a forma nova da boca (lábios de verdade, torta, rasgos por golpe);
  - o dente pendurado pela gengiva;
  - as lascas grudadas no vidro.
- **Parte 2 e carne do rosto:** snapshot `33ded68` na PSX_sangue (em cima de
  58c986a), mandado à psx-0c para integrar. A cena inteira rodou sem erro.
  - `SangueNaLente`: o acumulador de tela. O sangue fica, o grosso solta
    filetes que escorrem, coagula em ~15 s, refrata o que está atrás; a lama é
    um canal próprio. Fica na cena, não no carro.
  - `CuspeDeSangue`: os cuspes da frase nas plosivas e o escarro, disparados
    pela `falar`, mais o pingar do queixo na lente (último olhar).
  - `BocaSangrando`: os fios de sangue entre os lábios, que esticam e
    arrebentam com a fala, e o pingar do lábio.
  - `CarneDoRosto` (agente da PSX_rosto): a cara esmagando no vidro, a
    inércia, a onda do impacto, 12 músculos, rugas dinâmicas e hematoma.
    Custa +0,21 ms de GPU no stare e +0,28 ms no pior caso (4K).
- **Onde a Parte 2 entra no final novo:** a psx-0c chama a API nas fases do
  `PLANO_JOGADO_PARA_FORA.md`: a lama no impacto (plano 8) e o pingar no último
  olhar (plano 10). A frase já dispara sozinha.

## Pendências

- Na cena de hoje, durante a frase, a mão e o braço dele tapam quase toda a
  vista: o cuspe aparece, mas a boca quase não. Conferir na encenação nova
  (cara no terço esquerdo).
- A carne esmagando no vidro lê bem de perfil, mas de dentro do carro fica
  discreta: sangue, trinca e água cobrem o contato. Ideia do agente: um anel
  de contato úmido e escuro.
- O fio de gengiva do dente pendurado quase não aparece (a raiz o cobre).

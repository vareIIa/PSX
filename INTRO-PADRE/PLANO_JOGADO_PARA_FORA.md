# Plano: o padre nos arranca pela janela e nos joga no chão

Mapeamento pedido pela psx-0c (P.O. da abertura) em 27/09/2026. Não há código de jogo aqui, só o plano.

> "MUDANÇA DE DIREÇÃO CRÍTICA PARA RESOLVER BUG DO CABECEIO FINAL ATRAVESSA. PADRE VAI NOS PEGAR E
> JOGAR PARA FORA DO CARRO, DELEGUE AGENTE PARA FAZER ESSE MAPEAMENTO PARA CONSEGUIRMOS ENTREGAR AAA COM
> MOTION BOM, ANIMAÇÕES POLIDAS ETC."

A ideia em uma linha: **o padre fica fora do carro, e quem atravessa a janela somos nós.**

## Como foi medido

- Árvore principal, `deploy` em `25a7721`, com o WIP da boca (psx-2f) já em stage.
- Três rodadas de 1920x1080 com `--fixed-fps 30`:
  1. A pedida no briefing, com fotos e rajada:
     `--ver-estrada --estrada-corrida --estrada-desde=dentro --susto-fotos=… --susto-rajada=…/r --susto-rajada-passo=0.1 --rajada-fora --sair-no-fim`
  2. e 3. A mesma cena com uma sonda minha, feita só de leitura (`--script`, fora do repositório; ver
     "Ferramentas" no fim). A cada 0,1 s, do `janela` ao `branco`, ela mede no espaço da cabine a lente, os
     ossos do padre, as mãos e o chão. Também grava seis lentes de fora: perfil, diagonal, banco do carona,
     traseira, duas no chão e uma planta ortográfica até 1,25 m.
- As rodadas 2 e 3 deram o mesmo resultado, com as mesmas marcas `[susto]` (±0,01 s) e o mesmo "maior entrada"
  por osso até o milímetro. A medida se repete.
- Espaço da cabine = espaço do carro (a cabine está em (0, 0, 0), sem giro). X negativo é o lado do motorista.
  Z negativo é a frente. `d` é a distância ao plano do vidro do motorista, positiva para fora.
- Relógio: é o da cena com `--estrada-desde=dentro`. Na cena inteira some ~43,4 s (a batida cai em 16,69
  aqui e em ~60 lá, e o branco em 55,41 aqui e em ~99 lá).

Todas as fotos de referência estão em
`C:/Users/ADMINI~1/AppData/Local/Temp/claude/c--Users-Administrator-Documents-Codes-Games-PSX/89ac2721-6b53-4ca0-bc64-679f010069c5/scratchpad/`,
daqui em diante chamado `REF/`:

| arquivo | o que mostra |
|---|---|
| `REF/jogado_ref/01_hoje_janela_ao_estouro.png` | as fotos de beat, de `10_janela` a `10g_esfarela` |
| `REF/jogado_ref/02_hoje_estouro_ao_branco.png` | as fotos de beat, de `10h_dentro` a `11_branco` |
| `REF/jogado_ref/03_rajada_pov_estouro_ao_branco.png` | 30 quadros da lente, de 49,5 a 55,4 |
| `REF/jogado_ref/04_bug_visto_do_banco_do_carona.png` | **o bug**: a cabeça, o capuz e a murça dentro da cabine, de 49,9 ao golpe |
| `REF/jogado_ref/04b_bug_carona_quadro_cheio.png` | o mesmo em quadro cheio, em 53,17 e 54,77 |
| `REF/jogado_ref/05_de_fora_perfil.png`, `06_de_fora_diagonal.png` | o lado do motorista visto de fora: a meia-lua colada no padre |
| `REF/jogado_ref/07_planta_ate_1m25.png` | a planta cortada a 1,25 m de altura: carro, fogo e os anéis dos capuzes em volta |
| `REF/jogado_ref/08_do_chao_a_1m_do_padre.png` | a lente a 16 cm do chão, a ~1,2 m dele: uma parede preta de batina |
| `REF/jogado_ref/09_rajada_fora_console.png` | a lente `--rajada-fora` (console e vão dos pés) |
| `REF/jogado_ref/10_geometria_da_janela.png` | a abertura com as cotas, a cabeça e o tronco passando |
| `REF/jogado_ref/11_planta_do_pouso.png` | a planta com o padre, a meia-lua, a roda e o pouso candidato |
| `REF/fotos1/*.png` | as 55 fotos de beat da rodada 1, com o nome do beat |
| `REF/fotos1/r/`, `REF/fotos1/r/fora/` | a rajada inteira a 0,1 s (lente e `--rajada-fora`) |
| `REF/sonda2/<lente>/r_<t>.png` | as lentes de fora da sonda, a cada 0,5 s |
| `REF/sonda1.log`, `REF/sonda2.log` | as linhas `[sonda]` quadro a quadro |

---

## 1. O estado atual

### 1.1 A linha do tempo, do `10_janela` ao `11_branco`

As marcas `[susto]` são do log. As fotos saem um pouco depois da marca, na espera que o código pede.

| beat e foto | t (s) | o que roda |
|---|---|---|
| `janela`, foto `10_janela` | 42,60 | `_padre_cabeceia` (l. 1950) monta a `CabecadaDoPadre`, os `PadresNasJanelas` e os dois `BracoDoPadre` (0,75). A cara vira para a lente (`encara`, 0,7 s) e a testa chega a 7,5 cm do vidro (`TESTA_PERTO`). Na lente, `_foco_de` fica entre o rosto e o ponto do vidro, e o FOV vai de 56 a 46. O drone de tensão entra. `_mao_no_vidro` sobe a mão (0,6 s). |
| `mao`, fotos `10b_mao` e `10c_sorriso` | 43,43 | `CapuzMacabro`: sorriso e olhos. Sons `sorriso_abre` e `padre_riso`. A cabeça deita (`SORRI_TOMBA`). Depois `_vacuo(true)` e `PAUSA_ANTES` de 0,5 s. |
| `cabecada1`, foto `10d_cabecada1` | 46,33 | `_cabecada_vai` (recua, depois bote) e `_cabecada_bate`: `SangueNoVidro.golpe`, `TrincaDeVidro`, `cabecada_vidro_1` e `tensao_impacto_1`, `_tremor`, `_soco` e `_recua` na lente, `_carro.pancada`. `_cabecada_gore`: `CabecaDoPadre.por_dano`, que quebra os `DentesDoPadre` (psx-2f), mais `GoreDeCabecada.golpe`, `nariz_quebra` e o hit stop de 35 ms. O capô bate junto (`_cerco(&"cabecada")`). |
| `relance_capo`, foto `10e_relance_capo` | 46,86 | `_cabecada_relance(_cabecada_alvo_capo)`: a lente escapa para o capô e volta. |
| `cabecada2`, fotos `10d_cabecada2` e `10f_relance_lado` | 48,23 | O mesmo, mais o arrasto do sangue (`ARRASTO`) e o relance para o carona (`outros.golpe`). |
| `cabecada3` e `estoura`, foto `10g_esfarela` (49,68) | 49,64 | A trinca esfarela (0,07 s). `cabine.abrir_buraco`, `_sangue_cai_com_o_vidro`, `_estourar_vidro` (as partículas pré-aquecidas), `vidro_trinca` e `zumbido_ouvido`. `AgarraoDoPadre.mao_ao_parapeito` e `_soltar_o_olho` (`OlhoSolto`). **E o tween que leva a testa 19 cm para dentro em 0,16 s (`CABECA_ENTRA`)**, com o FOV em 57. |
| foto `10h_dentro` | 49,87 | `_medir_rosto`: o rosto a 0,44 m da lente. |
| `encara`, fotos `10h_encara_0/1/2` (49,90, 50,70, 51,50) | 49,90 | `_encarar(1,6 s)`: a lente segue o meio da cara (`CARA_SEGUE` 3/s), `GoreDeCabecada.pingar` no queixo, `sangue_pinga_loop`, o sorriso a 1,25, o FOV a 48 e `_ofego` a 0,2. |
| `mao_sobe`, foto `10i_mao_sobe` (51,85) | 51,57 | `_agarrar_e_puxar` monta o `AgarraoDoPadre.rodar()`: near 0,005, obturador travado, desfoque de perto, a luz da janela sem a camada do braço. A mão sai do parapeito (`SOBE` 0,28 s) com `rangido_osso` e a cabeça encolhe (`ENCOLHE`). |
| `mao_na_cara`, foto `10j_mao_na_cara` (52,06) | 52,00 | O bote (`BATE` 0,08 s). `MOLA_NA_MAO`, `TAPA_TRANCO` e a cabeça prensada no encosto (`PRESA`). Som `mao_na_cara`, e `_abafar` fecha o passa-baixa em 650 Hz. A mão esquerda do motorista agarra os dedos dele 0,35 s depois (`_motorista_agarra`). |
| `frase`, foto `10k_frase` (53,26) | 52,24 | `CabecaDoPadre.falar(FALA_QUE_BOM)` e `padre_que_bom` (2,04 s), com dois apertos (`APERTOS`). A distância cai 5 cm (ele se aproxima). Depois 0,32 s de silêncio. |
| `empurra`, foto `10l_empurra` (54,88) | 54,64 | `_motorista_arrancado`, `_gola_agarra` (a outra mão na gola, `arrasto_corpo`). A cabeça é empurrada (`EMPURRADA`) e bate no encosto; ele arma (`ARMA` 0,2 m, `RECUO_ARMADO`). `cabeca_empurrada`, `tensao_suga`, o mundo volta inteiro e o FOV vai a 44. |
| `puxa`, foto `10m_puxa` (55,33) | 55,24 | `MOLA_PUXAO` e `PUXADA`. `_mirar_rapido` e `_perseguir`: a testa persegue a lente até `BRANCO_A` (0,2 m). `puxao_ar`, `_tremor` em 1 e o FOV a 52. |
| golpe, foto `10n_golpe` | ~55,40 | `_golpear`: `cabecada_final`, o `SANGUE_NA_VISTA` (shader de tela) e `Engine.time_scale` a 0,03 por 75 ms. |
| `branco`, foto `11_branco` | 55,41 | `_ao_branco("")`: `BrancoDoSusto.estourar`, `susto_golpe`, a estrada escondida e os laços cortados. |

Do estouro ao branco há **5,77 s** (de 49,64 a 55,41).

### 1.2 O que a lente e o padre fazem em cada batida (sonda, espaço da cabine)

A lente em repouso fica em (-0,40; 1,16; 0,12), com `d` = -0,39. O olho do suporte está em (-0,40; 1,16; -0,08):
a câmera fica 20 cm atrás dele (`DENTRO_OLHO_RECUA`). O padre nasce na janela em (-1,36; 0,00; -0,02),
olhando +X, agachado e curvado (`PADRE_NA_JANELA`).

| t | lente (pos, FOV, near) | cara `d` | topo da cabeça `d` / acima do forro | ombro `d` | joelho x (`d`) | raiz do Corpo |
|---|---|---|---|---|---|---|
| 42,60 janela | repouso, 56, 0,08 | +0,26 | +0,39 / +0,16 (fora) | +0,37 | -0,97 (+0,02) | (-1,36; 0,00) |
| 45,27 sorriso | repouso, 46 | +0,09 | +0,16 | +0,24 | **-0,84** (-0,12) | (-1,23; -0,03) |
| 48,54 perto da cabeçada 2 | repouso, 46 | +0,05 | +0,06 | +0,24 | -0,92 (-0,05) | (-1,31; -0,06) |
| 49,84 estouro +0,2 | (-0,37; 1,15; 0,12), 52 | **-0,12** | -0,11 / 0,00 | +0,06 | -0,71 (-0,25) | (-1,10; -0,06) |
| 50,37 encara | repouso, 55 | -0,16 | -0,12 / +0,03 | -0,01 | -0,60 (-0,36) | (-0,99; -0,08) |
| 51,97 mão na cara | (-0,37; 1,15; 0,15), 48, **0,005** | -0,16 | -0,13 / -0,01 | +0,01 | -0,62 (-0,34) | (-1,00; -0,08) |
| 53,30 frase | (-0,35; 1,16; 0,17), 48 | -0,19 | -0,15 / +0,01 | -0,03 | -0,58 (-0,38) | (-0,97; -0,08) |
| 54,90 empurra | (-0,20; 1,16; 0,21), 43,5 | -0,07 | +0,04 / **+0,09** | +0,03 | -0,60 (-0,36) | (-0,99; -0,08) |
| 55,41 golpe | (-0,53; 1,15; 0,11), 46 | **-0,31** | -0,30 / -0,03 | **-0,14** | **-0,51 (-0,46)** | **(-0,90; -0,10)** |

O pior valor da cena inteira, de 42,6 ao branco, igual nas duas rodadas:

| ponto | pior `d` (m) |
|---|---|
| cara | **-0,306** |
| topo da cabeça | -0,299 |
| pescoço | -0,169 |
| nuca | -0,151 |
| ombros | -0,14 |
| **joelhos** | **-0,46** |
| quadril | +0,021 |
| torso | +0,005 |

As mãos (`BracoDoPadre`): na cara, o alcance do ombro à palma é de 0,44 a 0,49 m. No empurrão, a da gola e a da
cara vão a 0,67 e 0,73 m, com a palma em x = -0,29 e -0,14, perto do meio do carro.

### 1.3 O que a câmera, as mãos, o som e o sangue fazem hoje

- **A lente** (`_de_dentro`, l. 5123) herda o suporte do carro. Por cima dela entram:
  - o foco puxado (`_foco_de`, `_foco_peso`);
  - o relance;
  - o tremor (três senos);
  - o ofego;
  - o encolher (`_recua`);
  - no fim, a cabeça do agarrão (`_agarrao.cabeca(xf, suporte)`, uma mola de 170 a 1400 1/s²).
  O FOV é `_fov_cena` menos `_soco`.
- **O celular** morreu em 41,63 (`apagar_celular`) e desceu para o colo na virada (`mostrar_celular(false)`).
  No final ele não aparece.
- **As mãos do motorista**: só a esquerda. Ela agarra os dedos do padre na frase e é arrancada no empurrão
  (`braco_esquerdo_para_a_cena`, `esforco`).
- **Sangue na lente**: só o `SANGUE_NA_VISTA` do golpe final, uma camada 2D de 75 ms. O `SangueNaLente` da psx-2f
  (Parte 2) ainda não existe.
- **Som, na ordem**:
  - `vidro_trinca` e `zumbido_ouvido`;
  - `olho_sai`;
  - `sangue_pinga_loop`;
  - `rangido_osso`;
  - `mao_na_cara` e `respira_abafado`, com o bus `AgarraoAbafado`;
  - `mao_aperta`;
  - `padre_que_bom`;
  - `arrasto_corpo`, `cabeca_empurrada` e `tensao_suga`;
  - `puxao_ar`;
  - `cabecada_final`, `tapa_vidro` e `susto_golpe`.
  Por baixo, o drone e o coração sobem de degrau a cada golpe.
- **A voz** do padre: `padre_riso` no sorriso e `padre_que_bom` (edge-tts Antônio) na frase.

### 1.4 Onde está o bug

1. **O corpo inteiro desliza pela normal inclinada do vidro.**
   - `CabecadaDoPadre.aplicar` põe `_c.position = _base + _n * _desloca`. A normal é (-0,978; +0,207; -0,007):
     o vidro deita para dentro no alto.
   - Cada centímetro que a testa entra leva o `Corpo` inteiro 0,98 cm para o carro e 0,21 cm para baixo da
     terra.
   - No golpe final a raiz andou 0,47 m para a porta e afundou 10 cm (de (-1,36; 0,00) para (-0,90; -0,10)).
     Os joelhos pararam em x = -0,51, **33 cm dentro da lataria** (a porta do Marea fica em x ≈ -0,84; a
     largura é 1,66).
   - É daqui que vêm "a murça e a batina 26–37 cm para dentro da porta, abaixo do peitoril".
   - **Já antes do estouro**, no sorriso e nas cabeçadas, os joelhos encostam na lataria (x = -0,84).
2. **O roteiro pede a cabeça dentro.**
   - O stare de 1,6 s, a frase e o golpe final põem a cara de 16 a 31 cm para dentro do vidro.
   - O topo da cabeça passa do forro (1,39) em até +9 cm no empurrão, e o capuz de pano soma por cima.
   - A abertura útil tem 0,38 m de altura. Um padre de 2,0 m, com capuz e murça, não passa por ela sem o pano
     cruzar a moldura. Diminuir o padre foi rejeitado.
3. **O quick-fix do vidro** (`VidroCortaPano`, na PSX_vidro) desliga o recorte do motorista no estouro, de
   propósito ("o padre entra"). Dali em diante nada esconde o pano.

Veja `REF/jogado_ref/04b_bug_carona_quadro_cheio.png`. É a mesma coisa que a lente vê em 55,06–55,20
(`03_rajada_pov…`): o capuz e a murça debaixo do forro.

### 1.5 O que continua e o que sai

**Continua sem mudar:**
- tudo até o estouro: o sorriso, a mão no vidro, as três cabeçadas, o relance, o sangue e a trinca;
- os dentes e a boca da psx-2f;
- `mao_ao_parapeito` e `_soltar_o_olho`;
- `_sangue_cai_com_o_vidro` e os estilhaços;
- `GoreDeCabecada.pingar`;
- o `BrancoDoSusto` e o `_ao_branco`.

**Continua, mudado:**
- A primeira metade do `AgarraoDoPadre`: a mão sobe, tapa, abafa, a frase, os apertos e o gancho `cabeca()`
  na `_de_dentro`. O que muda é o alvo da cabeça: em vez de prensada no encosto, ela é **puxada para a
  janela**.
- `_gola_agarra`: a mão na gola vira a pega do puxão.
- A mola da cabeça (`_molejar`) é reaproveitada no rig.
- O stare (`_encarar`) fica, mas com a cabeça dele fora.

**Sai:**
- `CABECA_ENTRA` e `CABECA_ENTRA_TEMPO`, com o tween de entrar.
- No agarrão, do empurrão ao golpe:
  - as constantes `EMPURRADA`, `ENCOSTO_QUIQUE`, `PUXADA`, `MOLA_PUXAO`, `ARMA`, `RECUO_ARMADO`, `BOTE_FINAL`,
    `FOV_ARMADO`, `FOV_GOLPE`, `BRANCO_A`, `MIRA_DIRETA`, `MIRA_GOLPE`, `PUXA_SEGUE`, `GOLPE_CONGELA`,
    `GOLPE_ESCALA` e `SANGUE_NA_VISTA`;
  - as funções `_bater_no_encosto`, `_mirar_rapido`, `_perseguir`, `_golpear`, `_sangue_na_vista` e
    `_testa_a_lente`.
- O som `cabecada_final` fica sem uso.
- O ajuste combinado da "cabeçada com o topo da cabeça" era para o golpe final atravessar menos. Sem golpe
  final, ele cai.

---

## 2. A geometria que manda

Tudo foi medido pela sonda, no espaço da cabine (= carro). Veja `REF/jogado_ref/10_geometria_da_janela.png`
e `11_planta_do_pouso.png`.

### 2.1 A janela do motorista (`porta_frente`, lado -1)

| cota | valor |
|---|---|
| peitoril | y = 0,931 na coluna A (z = -0,42), 0,953 no meio e 0,959 na coluna B (z = +0,34); x = -0,840 |
| trilho do teto | y = 1,270 na coluna A, 1,335 no meio e 1,338 na coluna B; x = -0,761 a -0,769 (tumblehome de 8 cm) |
| coluna A / coluna B | z = -0,42 / z = +0,34. A largura é de **0,76 m** |
| vão útil no meio (z = -0,05) | de 0,953 a 1,335: **0,38 m** |
| centro e normal | centro (-0,803; 1,124; -0,040), normal (-0,978; 0,207; -0,007) |
| vizinhos | quebra-vento de z = -0,84 a -0,46 (y 0,88–1,25); vidro de trás de z = +0,41 a +0,85 |
| forro, piso e capô | forro em 1,39, piso da cabine em 0,36, painel em 1,05; o capô do Marea tem 0,93 |
| lataria | o Marea tem 1,66 m, então a porta fica em x ≈ ±0,83–0,84. A medir por raio na Fase 0 |

### 2.2 O motorista

| peça | onde está |
|---|---|
| lente (a câmera) | (-0,40; 1,16; 0,12); na frase, (-0,35; 1,16; 0,17) |
| gola, a pega da mão do padre | ≈ 19 cm abaixo e 14 cm à frente da lente (`GOLA`): ≈ (-0,41; 0,97; -0,02) |
| peito (esterno) | ≈ (-0,40; 0,85; 0,05) |
| quadril | ≈ (-0,40; 0,71; 0,02) (`MotoristaCena.QUADRIL`); o assento em 0,66 |
| volante | pivô em (-0,40; 0,995; -0,30), raio 0,185, inclinado 30° |
| ombros | a ~0,20 m abaixo do olho, meia largura de ~0,20: o esquerdo ≈ (-0,60; 0,98; 0,12), a ~0,2 m da porta (estimado, sem corpo para medir) |

O motorista **não tem corpo**, só braços (`MotoristaCena`). Toda a saída acontece na lente e no som, e isso é uma
vantagem: nada nosso atravessa geometria à vista. A conta do corpo que passa serve para o caminho da lente ser
verossímil.

### 2.3 Por onde o corpo cabe

- **A cabeça** (raio ~0,10) passa pelo meio do vão (y ≈ 1,14, z ≈ -0,05), com **9 cm de folga** em cima e
  embaixo.
  - De costas, o olho fica no alto da seção da cabeça (≈ y 1,21) e **passa a 12 cm do trilho**.
  - De bruços, o olho passa a 12 cm do peitoril.
- **O tronco** tem 0,44 de ombro a ombro e 0,25 de peito a costas.
  - Ele só passa com **a linha dos ombros deitada, a menos de ~15° do eixo do carro (z)**. Assim a seção é
    0,44 (em z) × 0,25 (em y): cabe, com 6–7 cm de folga.
  - Com os ombros em pé não passa: 0,44 > 0,38. Inclinados 25°, a seção dá 0,41 e também não passa.
- **Consequência para a lente.** Sentado, o motorista tem os ombros em X. Para sair de cabeça pela janela, o
  corpo precisa:
  1. tombar ~90° para a janela (cabeça para fora);
  2. **rolar ~90° no próprio eixo**, de costas (o peito para cima) ou de bruços.
- **O quadril** tem 0,36 × 0,22 e passa do mesmo jeito. É nele que o corpo engancha no peitoril: é o "tranco"
  natural do meio da saída.

### 2.4 Onde o padre tem de estar para puxar sem entrar

- **Hoje**: a raiz fica em (-1,36; -0,02). Os ombros do `Corpo` ficam em x = -1,18, y = 1,12, z = -0,33 e
  +0,29 (0,62 de ombro a ombro).
- **Os braços** (`BracoDoPadre`, escala 0,75):
  - 0,39 m de braço e 0,26 de antebraço, a mão com 18 cm;
  - 0,65 m do ombro ao punho;
  - com `SAI_DA_MANGA`, até **0,79 m**.
- **A regra nova**: todo o `Corpo` fica fora.
  - Com `d ≥ +0,03` acima do peitoril e **x ≤ -0,86** abaixo dele (a porta, mais 2 cm).
  - Os braços são a única coisa que cruza, e só pelo vão.
- **Para alcançar** com os ombros fora:

  | pega | ombro | distância | leitura |
  |---|---|---|---|
  | a gola, (-0,41; 0,97; -0,02) | x ≈ -1,00, y ≈ 1,10 | 0,62–0,69 m | alcança, com o braço quase reto |
  | a cara na frase | x ≈ -0,97 | 0,60–0,66 m | no limite |

  Por isso, na frase, **a mão puxa a nossa cabeça 12–15 cm para a janela**: a lente vai de x -0,40 a ≈ -0,52.
  A cara dele então fica a ~0,36 m (hoje 0,31), com ele fora.
- **No stare, a cara com `d` ≥ +0,06**: ela fica a 0,45–0,50 m da lente. O capuz, acima do trilho, não bate
  no teto porque fica fora (x < -0,78 acima de y 1,34).
- **Os pés**:
  - no puxão, o de trás recua para (-1,75; +0,35) e o da frente fica em (-1,30; -0,20);
  - o quadril vai de (-1,41; 0,64) para (-1,75; 0,55): **para trás e para baixo**;
  - os joelhos nunca passam de x = -0,90.
- **Ele está no caminho.** O corpo sai da janela para -X, reto para o peito dele (x -1,1 a -1,4, y 0,6–1,4).
  Por isso, no puxão, ele **gira ~30° e dá um passo de lado**: a nossa cabeça passa rente ao peito dele e não
  através dele.

### 2.5 O chão lá fora e quem está nele

- **A altura do chão**, pela função da estrada (`altura_da_pista` + `altura_lateral`):

  | ponto (espaço do carro) | chão em y |
  |---|---|
  | x = -0,9 | 0,010 |
  | x = -1,36 | 0,015 |
  | x = -1,8 | 0,018 |
  | x = -2,5 | 0,024 |
  | x = -3,5 (barranco) | 0,096 |
  | x = -1,36, z = -1 | +0,093 |
  | x = -1,36, z = +1 | -0,061 |

  Ao longo de z, o chão desce ~7,7 cm por metro para trás.
  - No mundo, o carro está inclinado: rola 5,5° e arfa -3,6°.
  - Na planta, a área clara atrás e à esquerda é chão abaixo de -0,10: o chão desce para a traseira.
  - A medir por raio ou pela malha na Fase 0.
- **Os corpos a menos de 2 m da porta** (sonda, 42,6 → 55,3):
  - R0 (-1,70; +0,70);
  - R1 (-1,76; -0,60);
  - R2 (-1,18; -1,43);
  - R4 (-2,00; +1,17), depois (-1,60; +0,93).

  É a meia-lua, colada no padre. A roda, no branco, está a 3–5 m: Roda1 (-3,24; 2,90), Roda3 (-4,44; 0,96),
  Roda4 (-5,36; -3,42). A lente "atrás" bate num tronco de árvore na traseira esquerda (≈ x -2,6, z +1,8).
  A posição exata é para a Fase 0.
- **Do chão, perto, é um muro.** A lente a 16 cm do chão, a ~1,2 m do padre e da meia-lua, vê só paredes pretas
  de batina contra a fumaça (`08_do_chao…`). O último olhar precisa de **2,0–2,4 m** até o padre para ler o
  corpo dele inteiro (2,0 m a 2,2 m ocupam ~42° de altura), o carro, o fogo e a roda.
- **O pouso candidato** fica em x ≈ -3,1, z ≈ -0,3 (círculo verde em `11_planta…`):
  - ~1,6 m do padre depois do passo dele; a rolada leva mais ~0,4 m, então o último olhar abre a ~2,0–2,2 m;
  - entre R1 e R0, que dão um passo para trás;
  - antes do barranco;
  - longe do tronco.

---

## 3. O roteiro novo, plano a plano

**E** é o estouro: 49,64 aqui, ~93 na cena inteira. **A versão completa dura 9,9 s depois do estouro, contra 5,77
hoje (+4,1 s)**. O branco vai de 55,4 para ~59,5 (na cena inteira, de ~99 para ~103). A versão curta (§3.12)
dura 8,1 s (+2,3 s).

Sangue na lente, boca e dentes são da psx-2f. Onde eles entram está marcado com **[psx-2f]**.

### Plano 0: o estouro (E+0,00 → E+0,30)

- **Jogador vê**: o que existe hoje, isto é, o vidro esfarelando, os grãos caindo para dentro e o olho saindo. A
  diferença é que **a cara recua para fora**: o quique do golpe que atravessou.
- **Câmera**:
  - se encolhe para longe da janela (+X 6 cm, rolagem -3°, 0,2 s, com saída suave);
  - `_tremor` 0,8 e soco de -5°;
  - FOV de 46 para 52; near 0,08.
- **Padre**:
  - a testa passa só o `AMASSA` (4 mm) e volta 8 cm em 0,15 s;
  - o tronco recua (`recua` 0,4);
  - os pés não saem do lugar;
  - a mão cai no peitoril (`mao_ao_parapeito`).
- **Som**: `vidro_trinca`, `zumbido_ouvido`, `olho_sai`, `mao_lataria_2`.
- **[psx-2f]** Os dentes do golpe 3 e as lascas caindo com os cacos, como já estão.

### Plano 1: o stare, de fora (E+0,30 → E+1,40; 1,1 s)

- **Jogador vê**: a cara destruída **emoldurada pela janela sem vidro**, a 0,45–0,50 m. A moldura é a prova de
  que ele está fora. Vê também o olho pendurado balançando, o sangue pingando no peitoril, a chuva entrando pelo
  buraco e a meia-lua atrás dele.
- **Câmera**:
  - parada, com a respiração presa (`_ofego` 0,2);
  - segue a cara devagar (3/s, como o `_encarar`);
  - o FOV fecha de 52 para 46 (o mundo encolhe); near 0,08.
- **Padre**:
  - cara com `d` +0,06 a +0,08, ombros ≥ +0,15, pés plantados;
  - respira: o peito e a murça sobem;
  - a cabeça deita (`tombo` +0,3) e a boca arreganha (sorriso 1,25).
- **Som**:
  - `sangue_pinga_loop`;
  - a chuva de fora pelo buraco (o abrigo da chuva abre um pouco no lado da janela);
  - a respiração dele, grave e molhada (**som novo**, `padre_respira`).

### Plano 2: a mão na cara (E+1,40 → E+1,85)

- **Jogador vê**: o que existe (o `AgarraoDoPadre` do parapeito à cara, com `SOBE`, `PAIRA` e `BATE`). O braço
  agora vem de fora, esticado pelo vão.
- **Câmera**: `ENCOLHE`, `TAPA_TRANCO`, near 0,005, `_abafar` (650 Hz). O desfoque de perto fica.
- **Padre**:
  - o braço entra pela janela e o ombro avança até `d` +0,12, sem passar disso;
  - o tronco inclina para a moldura;
  - a outra mão continua no parapeito.
- **Mãos do jogador**:
  - a esquerda larga o volante e agarra os dedos dele (`_motorista_agarra`, como hoje);
  - a direita segue no colo com o celular morto.
- **Som**: `rangido_osso`, `mao_na_cara`, `respira_abafado`.

### Plano 3: a frase, puxando (E+1,85 → E+4,45; 2,6 s)

- **Jogador vê**: "Que bom que você veio." A cara dele no terço esquerdo, pela beira da mão, e **chegando mais
  perto porque somos nós que estamos indo**: de 0,50 m até ~0,36 m.
- **Câmera**:
  - o alvo da mola da cabeça deixa de ser `PRESA` (prensada no encosto) e passa a **PUXADA_À_JANELA**: a lente
    vai de x -0,40 a -0,52 em ~2 s, aos trancos, nos dois `APERTOS`;
  - `LUTA` por cima;
  - FOV 48; near 0,005.
- **Padre**:
  - fala (`CabecaDoPadre.falar`);
  - o tronco vai para trás uns 5°: está recolhendo a folga;
  - a cara fica com `d` ≥ +0,04.
- **Mãos do jogador**: a esquerda puxa os dedos dele aos trancos (como hoje).
- **Som**: `padre_que_bom` e `mao_aperta` nos apertos.
- **[psx-2f]** Parte 2:
  - o cuspe nas plosivas ("que **b**om", "**v**ocê", "**v**eio"), a 0,36–0,50 m, o que dá distância para a
    balística;
  - sangue escorrendo da boca;
  - o `SangueNaLente` começa aqui.

### Plano 4: a gola e a antecipação (E+4,45 → E+4,95)

- **Jogador vê**:
  - a outra mão fecha na gola, fora do quadro: sente-se o tranco;
  - a mão da cara escorrega para a nuca, e a vista abre da direita para a esquerda;
  - ele aparece armado, a ~0,4 m, de boca aberta;
  - no canto de baixo à esquerda, **a nossa mão esquerda agarra o aro do volante**: os nós dos dedos e o aro.
- **Câmera**:
  - o tranco da gola (`GOLA_TRANCO`) para a janela;
  - depois o contra-movimento: **nós fincamos**, e a lente volta 4 cm (x de -0,52 para -0,48) em 0,25 s,
    tremendo de esforço;
  - FOV de 48 para 46.
- **Padre** (a antecipação):
  - o quadril desce 8–10 cm e os joelhos dobram;
  - o peso vai para trás (quadril de x -1,41 para -1,55);
  - o pé de trás recua 0,3 m;
  - ele puxa o ar.
- **Som**:
  - `arrasto_corpo` (a gola);
  - `mao_aperta`;
  - `passo_terra`;
  - ele inspirando, **novo** (`padre_esforco_puxa`);
  - opcional: a bota dele na porta (**novo**, `pe_na_porta`, só som; decisão D7).

### Plano 5: o puxão (E+4,95 → E+5,45; 0,5 s)

- **Jogador vê**, em ordem:
  1. o aro escorregando da mão, em 3–4 quadros;
  2. a moldura vindo para cima de nós: a coluna A passa pela borda esquerda e o trilho varre o alto do quadro;
  3. a chuva;
  4. a cara dele recuando e subindo, enquanto ele se deita para trás puxando.
- **Câmera**:
  - o pivô do peito acelera para -X num arco que sobe um nada (x de -0,48 a -1,10, y de 1,15 a 1,12), com pico de
    ~2,2 m/s e entrada em cúbica;
  - **a cabeça atrasa 2–4 quadros** (mola);
  - o giro: a lente vira para a janela (guinada ~-40°), rola ~-70° e sobe o queixo até olhar o céu (sai de
    costas);
  - a lente cruza o plano do vidro em ~E+5,25, a ≥ 0,10 m de cada aresta;
  - FOV de 46 para 58 (abre com a velocidade), near 0,02;
  - obturador travado aberto (`Lente.travar_desfoque(Lente.obturador())`), `_tremor` 1.
- **Padre**:
  - o tronco deita 25° para trás e o quadril vai a x -1,75;
  - os cotovelos passam das costelas;
  - o corpo gira ~30° para abrir o caminho;
  - a batina chicoteia: é o follow-through;
  - os pés continuam plantados.
- **Mãos do jogador**:
  - a esquerda perde o aro;
  - a direita solta o celular, que cai para o vão dos pés (D4).
- **Som**:
  - `puxao_ar`;
  - o grunhido dele, alto (**novo**);
  - a jaqueta rasgando (**novo**, `pano_rasga`);
  - o ombro batendo no batente (`baque_corpo_1` baixo);
  - os grãos de vidro raspando (**novo**, `arrasto_peitoril`);
  - o bus abafado solta: o mundo volta inteiro.

### Plano 6: o peitoril (E+5,45 → E+6,05; 0,6 s)

- **Jogador vê**, de costas:
  - o céu, com a chuva caindo na direção da lente;
  - a beira do teto do carro sumindo no pé do quadro;
  - ele em cima e atrás, de ponta-cabeça, aceso pelo fogo.
  - Em **E+5,75, o tranco**: o quadril engancha no peitoril; parada dura, 10% de ultrapassagem, 0,12 s de quase
    nada. Ele troca a pega e dá o passo.
- **Câmera**:
  - a cabeça fora, pendurada para trás, em y 1,0–1,1, com 60–90° para o alto;
  - a rolagem assentando, o solavanco do tranco e um quique curto.
- **Padre**:
  - um passo pesado para trás, com o pé esquerdo (0,35 m, pé em arco de 10 cm);
  - replanta;
  - o tronco torce 30° para a direita: é a antecipação do arremesso.
- **Som**:
  - o corpo raspando no peitoril com os grãos (`arrasto_peitoril`);
  - o sussurro da multidão subindo (`sussurros`);
  - `fogo_loop` mais perto.
- **Estilhaços**: um segundo jorro dos grãos que ficaram no peitoril, caindo com a gente. São os `_estilhacos`,
  com a caixa de emissão no peitoril.

### Plano 7: o arremesso e o voo (E+6,05 → E+6,55; 0,5 s)

- **Jogador vê**: um giro borrado com o fogo, o carro, a roda e o chão subindo para o quadro.
- **Câmera**:
  1. arco em volta do quadril dele, com raio de ~0,9 m, por 0,25 s;
  2. a soltura;
  3. balística por 0,25 s: uma parábola, de pico ~(-2,0; 0,95) até o chão;
  4. rola ~150° (de costas para de bruços, de lado) e inclina para o chão.
  O FOV vai de 58 para 66, o desfoque fica no máximo e o tremor desliga: o voo é liso, em contraste com o
  impacto.
- **Padre**:
  - pivô de 80–110° no pé da frente;
  - os braços esticam e **soltam** (mão `&"aberta"`);
  - follow-through: os braços continuam na direção do arremesso e caem, o tronco passa do ponto e volta, e a
    batina roda em volta dele.
- **Som**:
  - o sopro (`puxao_ar` mais grave);
  - o urro dele na soltura (**novo**);
  - a chuva aberta: o abrigo vai a 0.

### Plano 8: o impacto (E+6,55; um quadro e 70 ms de hit stop)

- **Jogador vê**: a lama e o chão batendo no quadro, um esguicho de poça e as duas mãos entrando para amortecer
  (catchFall), espalmadas na lama.
- **Câmera**:
  - parada com amasso: -3 cm e depois +2 cm, em mola;
  - soco de FOV de -7°;
  - `_parar_o_tempo(0,07)` com `HIT_STOP_ESCALA`;
  - o desfoque desliga no quadro congelado;
  - a lente fica a ≥ 0,09 m do chão.
- **Mãos do jogador**: as duas no mundo (as `MaoModelada` do motorista, com os ombros saindo do rig).
- **Som**:
  - `baque_corpo_2` ou `baque_corpo_3` e o baque na lama (**novo**, `baque_lama`);
  - `zumbido_ouvido` subindo;
  - `_abafar` fechando de novo por ~1 s: o ouvido tomou a pancada.
- **[psx-2f]** Lama e sangue na lente (o acumulador do `SangueNaLente`).

### Plano 9: a rolada (E+6,62 → E+7,40; 0,8 s)

- **Jogador vê**: o mundo dando uma volta (céu, fogo, chão, os pés da roda, chão) e parando deitado de lado, com o
  quadro inclinado ~75°.
- **Câmera**:
  - uma volta de rolagem desacelerando (de ~540°/s a 0);
  - dois quiques (8 cm e 3 cm);
  - o olho a ≥ 0,09 m do chão;
  - FOV 60; o desfoque diminuindo.
- **Som**: rolando na lama (**novo**, `rolar_lama`) e o fôlego que sai de uma vez (**novo**, `folego_perdido`),
  com o zumbido.
- **Alternativa B**: o `BonecoDePano` (ragdoll com músculo: `catchFall`, `rollUp` e o chão) invisível, com a lente
  presa na cabeça por mola. Fica como experimento na Fase 5, contra a rolada autoral (A).

### Plano 10: o último olhar (E+7,40 → E+9,90; 2,5 s)

- **Jogador vê**, com o quadro deitado 70–80° e a lente a 10–12 cm do chão, lama e capim na frente, gota
  batendo:
  - o carro pegando fogo (o fogo pelo para-brisa, o do capô recortado contra ele);
  - **o padre**, de 2,0 m, perto da porta, virando para nós a 2,0–2,4 m, com o fogo atrás (recorte) e o vermelho
    da janela nele;
  - a roda e a multidão fechando da névoa a 5–8 m, olhos acesos;
  - a meia-lua dando o passo que deu para trás, agora para frente.
  - Ele anda dois passos devagar, se debruça, e a cara desce de ponta-cabeça para o quadro: o olho pendurado,
    o sangue pingando na lente. A mão vem, e **o branco cai quando a palma tapa a lente** (D6).
- **Câmera**:
  - fôlego pesado (`_ofego` de 0,6 para 0,3);
  - **um piscar** em E+7,7: a pálpebra preta em 2 quadros. É a chuva no olho; a primeira pessoa não leva gota
    (regra do `GotasLente`);
  - uma tentativa de erguer a cabeça (2 cm) que não vai;
  - o foco (`Lente.focar`) passa do carro para a cara dele;
  - FOV de 60 para 52.
- **Som**:
  - o zumbido baixando;
  - o coração alto;
  - chuva e fogo;
  - `coro_baixo` e `sussurros` subindo;
  - os passos dele na lama (`passo_terra` grave);
  - o riso (`padre_riso`) ou silêncio (D2);
  - no branco, `mao_na_cara` mais `susto_golpe`.
- **[psx-2f]** Sangue pingando da boca e do queixo dele na lente.

### 3.11 A tabela do tempo

| plano | começa | dura | relógio (-desde=dentro) |
|---|---|---|---|
| 0 estouro | E+0,00 | 0,30 | 49,64 |
| 1 stare de fora | E+0,30 | 1,10 | 49,94 |
| 2 mão na cara | E+1,40 | 0,45 | 51,04 |
| 3 frase puxando | E+1,85 | 2,60 | 51,49 |
| 4 gola e antecipação | E+4,45 | 0,50 | 54,09 |
| 5 puxão | E+4,95 | 0,50 | 54,59 |
| 6 peitoril | E+5,45 | 0,60 | 55,09 |
| 7 arremesso e voo | E+6,05 | 0,50 | 55,69 |
| 8 impacto | E+6,55 | 0,07 | 56,19 |
| 9 rolada | E+6,62 | 0,78 | 56,26 |
| 10 último olhar | E+7,40 | 2,50 | 57,04 |
| branco | E+9,90 | | **59,54** (hoje 55,41) |

### 3.12 A versão curta (+2,3 s)

- O plano 1 cai para 0,7 s.
- A rolada cai para 0,6 s.
- O último olhar cai para 1,6 s.
- O branco fica em E+8,1 ≈ 57,7.

Com a D1(b), o fim no impacto, o branco ficaria em E+6,6: +0,8 s sobre hoje, mas sem último olhar.

---

## 4. A abordagem técnica de cada peça

### 4.1 O rig da lente: `ArrastoDoMotorista` (novo, `game/src/levels/arrasto_do_motorista.gd`)

- **Dois corpos**.
  - **O peito** é um pivô com posição e giro, andando por uma **curva autoral**: chaves com tempo, posição
    (espaço do carro), giro (quaternion) e entrada/saída. A interpolação é Hermite cúbica, ou Catmull-Rom
    centrípeta nas chaves desiguais. Pela memória, o Catmull pelo vértice faz ponta: conferir a ponta.
  - **A cabeça** é uma mola-amortecedor em cima do peito. O pescoço fica a (0; 0,26; -0,03) no referencial do
    peito. A posição e o giro atrasam, com a integração em sub-passos a 480 Hz do `AgarraoDoPadre._molejar` (a
    mesma conta, reaproveitada). A rigidez vai de 170 a 400 1/s² e o amortecimento de 17 a 30.
- **A passagem do agarrão para o rig é contínua.** O rig nasce da pose e da velocidade da lente no último quadro
  do plano 4: `_pos`, `_vel`, `_giro` e `_vgiro` da mola do agarrão, sem salto (critério C5).
- **A guarda contra geometria** é analítica, sem física: o carro está parado depois da batida.
  1. **Portal**: a 0,25 m do plano da janela, o centro da cabeça é projetado no plano e preso dentro do contorno
     encolhido 0,10 m.
  2. **Dentro**: a cabeça fica abaixo de forro - 0,10 e longe do forro da porta, fora do vão.
  3. **Fora**: y ≥ chão(x, z) + 0,09, e x ≤ -0,93 abaixo do peitoril (a lataria).
  4. A sonda mede `folga_moldura` e `folga_chao`.
- **Onde liga**: no `_de_dentro`, no mesmo lugar do `_agarrao.cabeca(...)`, que já devolve um `Transform3D`
  inteiro. A lente sai do carro sem trocar de `Plano`.
- **O que a saída arrasta junto**:
  - `_chuva.abrigo` vira animável: hoje é `1.0 if _plano == Plano.DENTRO`;
  - `_chuva.chao_y` passa para o chão do pouso;
  - a `FumacaNegra` vive na cabine: conferir o teto dela com a lente fora.
- **Ferramentas de cena reaproveitadas**:
  - `_fov_cena` e `_soco`;
  - `_tremor` (os três senos, com o trauma ao quadrado);
  - `Lente.travar_desfoque`, `Lente.focar`, `Lente.atributos` (DOF);
  - `_parar_o_tempo`;
  - `_abafar` e `_desabafar`.
- **Pálpebra** (novo, pequeno): uma faixa preta de tela, abaixo das faixas do cinema (camada 140, como o
  `SangueNaVista`), com fechar e abrir em 2 + 3 quadros.

### 4.2 O padre puxando: `PuxaoDoPadre` (novo, `game/src/levels/puxao_do_padre.gd`)

- **É uma camada de pose** como a `CabecadaDoPadre`: um RefCounted aplicado depois de `Corpo.animar` e do
  `TiqueMacabro`. Assume do plano 1 em diante; a `CabecadaDoPadre` fica só para as três cabeçadas.
- **A raiz não desliza.** O nó `Corpo` só anda nos passos, entre pés plantados. O que chega perto da janela é o
  **quadril e o tronco dobrando**, e nunca a raiz.
- **Chaves de pose por plano**:
  - posição do quadril (espaço do carro);
  - giro do quadril e do tronco;
  - a cabeça olhando para a lente, com o limite `ENCARA_MAX`;
  - o `tombo`;
  - tudo com entrada e saída por chave.
  As chaves dos planos 4 a 7 são as do §3: antecipação, deitar para trás, passo, torção, pivô e follow-through.
- **As pernas** usam IK de dois ossos com o pé plantado: `LevantarDoChao._ik_no_chao` já existe e protege a
  ponta do pé. Os passos são uma trajetória do pé em arco (8–12 cm), pousando no tempo da chave. Os joelhos têm
  um plano-limite em x ≤ -0,90.
- **Os braços** são os `BracoDoPadre`, que já têm IK de dois ossos com polo, `SAI_DA_MANGA` e os dedos da
  `MaoPosada`.
  - Cada quadro, a pegada = a **pega no rig**: a gola (peito × `GOLA`), a nuca (cabeça × `NUCA`, novo) ou a cara
    (as chaves do agarrão).
  - A pose da mão é `&"punho"` ou `&"garra"`.
  - Rodam depois da lente, com `process_priority` alto, como o agarrão já faz. Assim a mão presa não escorrega.
- **O corpo segue as mãos.** Se `|pega − ombro| > 0,62 m`, o quadril e o tronco ganham um deslocamento aditivo
  na direção da pega. É isso que segura o erro da pega abaixo de 1,5 cm (C3).
- **A soltura**: a pegada troca para um caminho de follow-through. Os braços seguem a direção do arremesso,
  desaceleram e caem, e a mão fica `&"aberta"`.
- **Os cotovelos** têm polo para baixo e para fora. Nenhum segmento do braço dentro do carro fora do vão (C2).
- **A cabeçada de antes do estouro também precisa de conserto**, porque os joelhos já encostam na porta ali:
  - o deslocamento da `CabecadaDoPadre` passa a ser **só horizontal**: a normal projetada no chão, sem o
    +0,207 em y que enterra o padre 10 cm;
  - ele é limitado: a raiz não passa de x -1,28;
  - o que faltar para a testa chegar ao vidro vem do tronco (`TRONCO_BOTE`).

### 4.3 O pano do padre

- **Batina, murça e capuz**: a `BatinaAAA` e o `CapuzMacabro.pano` (PanoGPU) já seguem os ossos. O pivô, o
  deitar para trás e o passo dão o follow-through de graça.
- **O colisor de vidro continua ligado depois do estouro.** Hoje `vidro_existe = false` manda a esfera de 14 m
  (`VIDRO_RAIO`) para longe. No novo roteiro o pano do `Corpo` nunca cruza o plano da janela.
- **O `VidroCortaPano` continua cortando** o pano do `Corpo` na janela do motorista depois do estouro, mas
  **nunca** o `BracoDoPadre` com a manga. Os braços são a única parte do padre que entra.
- **O risco é a estabilidade do PanoGPU** no pivô: 90° em 0,3 s dão ~300°/s no quadril, e a barra a 0,5 m anda a
  ~2,6 m/s. No PS1 STYLE ele trava a 15 passos. Medido na bancada, pela lente de fora.

### 4.4 As mãos do jogador (o viewmodel): `MotoristaCena`

- **Volante**: a mão esquerda já está no aro (`MAO_NO_ARO_GRAUS`). Ela aperta no plano 4. No plano 5
  **escorrega pelo aro** 3–4 quadros e abre (`MaoPosada &"aberta"`). Função nova: `soltar_do_aro(duracao)`.
- **Celular**: `arremessar_celular(duracao)` já existe (é o voo da batida) e serve para o celular sair do colo no
  puxão (D4).
- **No chão**: as duas mãos, com a pegada no mundo e o ombro vindo do rig (`ArrastoDoMotorista.ombros()`). A pose
  do catchFall do plano 8 e a mão na lama do plano 10, com os dedos mexendo.
- **Opcional**: a mão batendo na coluna B ao passar e sendo arrancada. É um clássico, mas custa uma pegada na
  moldura e cabe na D3.

### 4.5 Estilhaços, sangue do vidro, fogo e luz

- **Estilhaços**: os `_estilhacos` (750 grãos + 42 lascas), com um segundo jorro no plano 6. A caixa de emissão
  vai para o peitoril e as partículas reiniciam. Elas já nascem aquecidas, então não compilam no quadro.
- **Luz de fora**:
  - o fogo do capô (`IncendioDoCapo`, com a omni de sombra da PSX_fogo) é a chave: do chão, o padre fica
    recortado;
  - a leitura do rosto vem dos olhos acesos e da `_luz_janela` vermelha;
  - **sem luz falsa sem sombra**: a lição do capô foi que ela acende a cara através do capuz;
  - se faltar, sobe o piso da exposição (`Lente.forcar_piso`) só no plano 10.
- **Do chão**, a fumaça pode tapar o fogo (`08_do_chao…`). O teto da fumaça (`_teto_da_fumaca`) é conferido lá
  fora.

### 4.6 O chão de perto: `ChaoDePerto` (novo, `game/src/render/chao_de_perto.gd`)

- **O problema**: com a lente a 10 cm, o barranco da estrada (textura PSX de 128 px) e os cartões de capim da mata
  (os "X" da planta) viram borrão e papel.
- **A peça**: um retalho de 2 × 2 m no pouso, com:
  - malha deslocada: lama, folhas e tufos;
  - textura HD, pelo nome do arquivo (ver a memória);
  - poça com as ondas de chuva (o shader da `PocasEstrada`);
  - o respingo da chuva no chão da lente (`_chuva.chao_y`).
- **A altura** vem da função da estrada, conferida por raio na Fase 0.

### 4.7 Quem está em volta

- **A meia-lua** (R0, R1 e R4, a 0,7–1,2 m do padre) abre espaço para o pouso: um passo de 0,5 m para trás no
  plano 6. Depois fecha no plano 10.
  - Para virar a cabeça para nós, `olhar_lateral`: pela memória, o `olhar_para` com o corpo curvado olha o chão.
- **A roda** (`RodaDePadres`): `FECHA` passa de 37 para ~41,1 s. Ela continua chegando 2 s antes do branco, e a
  base disso é "o branco 38,7 s depois da batida", que muda para ~42,9.
- **A multidão** (`MultidaoEncapuzada`): confere o "fecha até 5,5–8 m" no novo branco.

### 4.8 O som

- **Novos**, em `tools/gerar_audio_jogado.py` (o mesmo jeito do `gerar_audio_agarrao.py`):
  - `padre_respira`;
  - `padre_esforco_puxa`, o grunhido e o urro;
  - `pe_na_porta`;
  - `pano_rasga`;
  - `arrasto_peitoril`;
  - `baque_lama`;
  - `rolar_lama`;
  - `folego_perdido`.
- **Reaproveitados**:
  - `arrasto_corpo`, `mao_aperta`, `puxao_ar`;
  - `baque_corpo_1` a `3`, `passo_terra_1` a `4`;
  - `zumbido_ouvido`, `coracao_loop`, `ofegante`;
  - `sussurros`, `coro_baixo`, `padre_riso`;
  - `fogo_loop`, `chuva_loop`, `mao_na_cara`, `susto_golpe`.
- **Mixagem**:
  - o abafado da mão na orelha (planos 2 e 3) abre no puxão;
  - o `chuva_cabine_loop` sai e a `chuva_loop` entra quando a cabeça cruza o vão;
  - o ouvido fecha de novo no impacto e abre no último olhar.

### 4.9 A voz

- `padre_que_bom` fica no plano 3, se a D2 for a janela.
- A "voz molhada" é da psx-2f.
- Nenhuma fala nova sem pedido. Pela memória, a voz narrando mensagem foi rejeitada, e ideia não pedida vira
  pergunta.

---

## 5. A barra AAA de movimento, com números

Cada critério sai numa linha `[jogado] Cn … OK/FALHA` da sonda nova (§5.12), medida a 30 quadros por segundo.

### C1. O padre fora

- **Regra**:
  - acima do peitoril (y ≥ 0,93), o `d` mínimo de todos os ossos do `Corpo`, da cara, do topo da cabeça e da nuca
    é **≥ +0,03 m**;
  - abaixo do peitoril, x ≤ -0,86;
  - de E ao branco.
- **Hoje**: cara -0,31 e joelhos -0,46 (x -0,51).
- **O pano**: com `--vidro-sonda`, **0 pixel magenta** na caixa da janela do motorista depois de E. Os braços
  não contam.

### C2. Os braços só pelo vão

- **Regra**: os segmentos ombro → cotovelo → punho dos `BracoDoPadre` só cruzam o volume do carro **dentro do
  contorno do vão encolhido 3 cm**. Zero violação.

### C3. A pega

- **Regra**: `|palma − alvo da pega| < 1,5 cm` em todo quadro de "presa", e `|alvo − ombro| ≤ 0,62 m`.
- **Sonda**: o máximo e o quadro em que ele acontece.

### C4. A lente livre

- **Regra**:
  - a folga da lente às quatro arestas do vão é **≥ 0,10 m** a menos de 0,3 m do plano;
  - **≥ 0,09 m** do chão;
  - o near é 0,02, e 0,005 só com a mão na cara;
  - nenhum quadro com a lente dentro da lataria.

### C5. Nenhum salto

- **Regra**, por quadro:
  - lente: Δpos ≤ **0,16 m** e Δgiro ≤ **18°**;
  - ossos do padre: ≤ **0,10 m**; as mãos ≤ **0,20 m** no arremesso;
  - FOV: ≤ 3° (≤ 8° no soco).
- **Exceção**: só os quadros marcados como impacto (8 e o tranco do 6), com teto de 0,25 m e 30°.
- **A troca agarrão → rig** não pode ter salto de nada.

### C6. Nada linear

- **Regra**, em cada movimento autoral (puxão, peitoril, voo, rolada, passos, braços):
  - pico / média da velocidade **≥ 1,3**;
  - nenhuma sequência de **4 quadros** com |Δv|/v < 2% enquanto v > 0,3 m/s (velocidade constante);
  - o mesmo para a velocidade angular.

### C7. Antecipação

- **Regra**, antes do puxão, do arremesso e de cada passo:
  - o quadril do padre vai **≥ 5 cm** (ou o tronco ≥ 5°) no sentido contrário;
  - a lente vai **≥ 3 cm** no sentido contrário;
  - entre 0,12 e 0,35 s antes do pico de aceleração.

### C8. Follow-through e sobreposição

- **Regra**:
  - a cabeça atrasa **2–4 quadros** em relação ao peito no puxão e no voo (pico da correlação cruzada da
    velocidade angular);
  - nas paradas (tranco, impacto, fim da rolada), ultrapassagem de **5–20%** e assentamento em < 0,3 s;
  - a saia do `Corpo` (`SAIA_F`/`SAIA_T`, mola própria) e a batina continuam andando **≥ 0,25 s** depois de o
    quadril parar.

### C9. Arcos

- **Regra**:
  - o caminho da lente no voo cabe numa parábola com resíduo **< 3 cm**;
  - nos movimentos de mão do padre maiores que 20 cm, a flecha é ≥ 5% da corda.

### C10. Ritmo e leitura

- **Regra**:
  - a rajada é quadro a quadro (`--susto-rajada-passo=0.0333 --susto-cheio-de=49.1`), com um mosaico por plano
    (`tools/mosaico_rajada.py`);
  - nos planos 1, 3 e 10, a cara dele fica nos 60% do meio do quadro por ≥ 0,4 s (a conta do `_no_quadro`);
  - as marcas `[susto]` batem a tabela do §3.11 em ±0,05 s.
- **Quem julga o ritmo é o usuário, em rajada** (memória "movimento se julga em rajada").

### C11. O custo

- **Regra**: GPU do trecho novo ≤ a do trecho final de hoje + 1 ms.
- **Medida**: `--medir-quadros --sair-no-fim`, sem foto, sem rajada e sem outro Godot aberto.
- **Atenção**: a lente do chão vê a roda, a multidão, o fogo e a névoa ao mesmo tempo.

### 5.12 Como medir

- **A sonda**: `--jogado-sonda` na cena nova. Imprime, por quadro:
  - t;
  - a pose da lente, Δpos e Δgiro;
  - a folga da moldura e a do chão;
  - o `d` mínimo do padre e o osso;
  - o erro de cada pega.
  No branco, imprime o resumo de C1–C9.
- **A bancada**: `game/src/levels/bancada_jogado.gd` com `scenes/test/bancada_jogado.tscn`, no molde da
  `bancada_cerco`.
  - Monta o carro batido, o fogo, o padre de 2,0 m com a batina AAA, a meia-lua e o rig.
  - Roda de E-0,5 ao branco em ~12 s, contra 2 min e 12 s da cena.
  - Tem as lentes de fora da minha sonda: perfil, diagonal, carona, chão e planta.
  - Flags: `--plano=N` para começar num plano e `--sem-padre` para o blockout da lente.
- **Na cena**: `--rajada-fora` já existe. Uma `--rajada-lado` nova grava a lente "carona" e a do chão, que foram
  as que mostraram o bug.
- **Molde da sonda**: a minha, feita só de leitura, está em `REF/sonda_final.gd` e `REF/sonda2.gd`. Com
  `--script`, os autoloads só existem depois que o script compila, então ela não pode citar nenhuma classe do
  jogo pelo nome. Ela serve de molde para quem precisar medir sem mexer no código.

---

## 6. O impacto nas outras frentes

### 6.1 O que sai

- A cabeçada final dentro da cabine e o stare com a cabeça dentro.
- O `SANGUE_NA_VISTA` do agarrão: o sangue na lente passa a ser só o `SangueNaLente` da psx-2f.
- O ajuste da "cabeçada com o topo da cabeça", que era da psx-0c.
- As fotos `10l_empurra`, `10m_puxa` e `10n_golpe` são renomeadas para:
  - `10l_gola`;
  - `10m_puxao`;
  - `10n_peitoril`;
  - `10o_voo`;
  - `10p_impacto`;
  - `10q_rolada`;
  - `10r_ultimo_olhar`.

### 6.2 Quem mexe em quê hoje

**psx-2f (boca, dentes e rosto)**
- A Parte 1 (dentes) está na principal, em stage.
- O rosto esmagando no vidro (PSX_rosto) é das três cabeçadas e **não muda**. O stare de fora fica a 0,45–0,50 m
  (hoje 0,40), então a bancada do rosto precisa dessa distância.
- A Parte 2 (fala sangrando, cuspe, `SangueNaLente`) estava parada esperando este plano. Ela entra:
  - na frase, na janela, a 0,36–0,50 m;
  - no impacto (lama com sangue na lente);
  - no último olhar (pingando de cima).
- O acumulador precisa sobreviver à lente saindo do carro.

**psx-9d (a manga, PSX_manga)**
- A manga tem de ser validada nas poses novas:
  - o braço esticado pelo vão até a cara (0,60–0,66 m, perto do alcance);
  - o braço dobrando no puxão;
  - o arremesso com a soltura rápida;
  - o braço caído, andando, no último olhar.
- Precisa entrar antes da Fase 3.

**O quick-fix do vidro (PSX_vidro, `VidroCortaPano`)**
- Hoje registra o material do `BracoDoPadre` e desliga o recorte do motorista no `abrir_buraco`.
- O novo roteiro pede o contrário:
  - **o recorte do motorista continua depois do estouro** para o pano do `Corpo` (batina, murça, capuz);
  - **o braço e a manga nunca são cortados**;
  - por exemplo, `registrar(material, cortar_depois_do_buraco := true)`.
- Precisa entrar antes da Fase 1.

**psx-0d (cerco e janelas)**
- O do capô aparece do chão, recortado no fogo, no plano 10: pose, tamanho e luz vistos de uma lente nova.
- O do carona fica atrás de nós. Os golpes cronometrados dele (1,4 s e 3,3 s depois da janela) não mudam.
- O fogo e a luz do fogo (dela) são a chave do plano 10: exposição e sombra conferidas lá de fora.
- **A meia-lua** (`FORA_DA_JANELA` e os romeiros 0–4 dos `PadresNasJanelas`) ganha uma reação: abrir e fechar.
  Isso toca o código dela; avisar antes.

**A roda e a multidão (psx-0c)**
- `FECHA` e a conta de "2 s antes do branco".

### 6.3 Os arquivos a tocar

| arquivo | o que muda | dono |
|---|---|---|
| `game/src/levels/abertura_estrada.gd` | `_padre_cabeceia` depois do estouro (sem `CABECA_ENTRA`, com o quique para fora), `_encarar` de fora, `_agarrar_e_puxar`, o gancho no `_de_dentro`, `_chuva.abrigo` e `chao_y`, as reações da meia-lua, as constantes e as fotos | psx-0c |
| `game/src/levels/agarrao_do_padre.gd` | para depois da frase; `PRESA` vira puxada à janela; a gola vira a pega; sai o empurrão ao golpe | psx-0c |
| `game/src/levels/cabecada_do_padre.gd` | deslocamento só horizontal e limitado; o colisor de vidro do pano fica depois do estouro | psx-0c |
| `game/src/levels/arrasto_do_motorista.gd` | **novo**: o rig da lente | psx-0c ou agente |
| `game/src/levels/puxao_do_padre.gd` | **novo**: a pose do padre puxando e arremessando | psx-0c ou agente |
| `game/src/render/chao_de_perto.gd` | **novo**: o chão do pouso | agente |
| `game/src/world/motorista_cena.gd` | `soltar_do_aro`, as mãos no mundo (catchFall, lama) | psx-0c |
| `game/src/render/vidro_corta_pano.gd` (PSX_vidro), `braco_do_padre.gd`, `batina_aaa.gd` | recorte por material depois do estouro | PSX_vidro |
| `game/src/render/manga_do_padre.gd` (PSX_manga) | validar nas poses novas | psx-9d |
| `game/src/levels/roda_de_padres.gd`, `game/src/render/multidao_encapuzada.gd` | `FECHA` e o tempo do branco | psx-0c |
| `game/src/levels/padres_nas_janelas.gd`, `cerco_no_carro.gd` | a meia-lua abrindo e fechando; conferir o do capô e o fogo do chão | psx-0d |
| `game/src/levels/bancada_jogado.gd`, `game/scenes/test/bancada_jogado.tscn` | **novo**: a bancada | agente |
| `tools/gerar_audio_jogado.py`, `game/assets/audio/*.wav` | **novo**: os sons | agente |
| `game/src/render/sangue_na_lente.gd`, `cuspe_de_sangue.gd` | Parte 2 da psx-2f, nos tempos novos | psx-2f |

O `abertura_estrada.gd` tem 5,4 mil linhas e é editado por quase todas as frentes. O trabalho vai numa worktree
do snapshot mais recente e volta por três vias, avisando a sessão dona (memória "árvore principal é o ponto de
reunião"). Depois de copiar classe nova, `--headless --import` na principal.

---

## 7. O plano em fases

Cada fase é entregável sozinha, com a sua medida. As estimativas são em dias de agente.

### Fase 0: a bancada e a sonda (0,5–1 dia)

- **Faz**:
  - `bancada_jogado` e `--jogado-sonda`;
  - a linha de base de C1–C5 no final de hoje, para reproduzir os -0,31 e -0,46;
  - a lataria da porta por raio (x real);
  - o chão por raio contra a função;
  - as árvores e a meia-lua na planta: é aqui que o pouso é escolhido.
- **Entrega**: a tabela da linha de base, as fotos das seis lentes e o pouso escolhido, com as distâncias.
- **Risco**: sem colisor na estrada, o raio pode não achar chão. Nesse caso, uma sonda por pixel na lente da
  planta (profundidade).

### Fase 1: o padre fica fora (1 dia)

- **Faz**:
  - o conserto da `CabecadaDoPadre` (só horizontal e limitado);
  - sem `CABECA_ENTRA`: o quique para fora e o stare de fora;
  - o colisor e o recorte do pano ligados depois do estouro (precisa do patch da PSX_vidro);
  - um branco provisório depois da frase.
- **Critérios**: C1 OK. A frase continua lendo, com a cara no terço esquerdo e ≥ 0,4 s no quadro.
- **Entrega**: a rajada de E a E+4,5 e a lente do carona mostrando a janela vazia de padre. Esta fase sozinha já
  mata o bug de hoje.

### Fase 2: o rig e o blockout da lente (1,5 dia)

- **Faz**: o `ArrastoDoMotorista`, com as chaves do §3 do plano 4 ao 10, com padre cinza ou sem padre.
- **Critérios**: C4, C5, C6 e C9 na lente. A GPU do chão medida cedo (C11).
- **Entrega**: a rajada do blockout para o usuário julgar o ritmo antes do padre existir. **As decisões D1–D5
  precisam estar tomadas antes.**

### Fase 3: o padre puxando (2 dias)

- **Faz**:
  - `PuxaoDoPadre` com as chaves, o IK das pernas, os passos, o pivô e o follow-through;
  - os `BracoDoPadre` nas pegas, com o solver de alcance e a soltura.
- **Critérios**: C1, C2, C3, C5, C7 e C8.
- **Precisa**: a manga (psx-9d) e o recorte por material (PSX_vidro) já na principal.
- **Entrega**: rajada da lente e das lentes de fora, perfil e diagonal.

### Fase 4: as mãos do jogador e o celular (1 dia)

- **Faz**:
  - o volante: aperta e escorrega;
  - o celular caindo;
  - as mãos no chão: catchFall e lama;
  - opcional: a mão na coluna B.
- **Critérios**: C2 para as mãos dele (nada atravessa o aro, a porta ou o banco); cada mão no quadro nos beats
  planejados.

### Fase 5: lá fora (2 dias)

- **Faz**:
  - `ChaoDePerto`;
  - a chuva e o piscar;
  - o impacto;
  - a rolada: A autoral, contra B com o `BonecoDePano`;
  - o último olhar: o padre anda e se debruça, a meia-lua abre e fecha, a roda com `FECHA` novo, o gatilho do
    branco.
- **Critérios**: C4 (chão), C8 (paradas), C10.

### Fase 6: som, psx-2f e a medida final (1–1,5 dia)

- **Faz**:
  - `gerar_audio_jogado.py` e a mixagem;
  - o encaixe da Parte 2 da psx-2f;
  - a rajada 4K quadro a quadro;
  - `--medir-quadros`.
- **Entrega**: os mosaicos por plano para o usuário, a tabela de C1–C11 e o GPU.

**Total: 9–10 dias de agente.** A Fase 1 pode ir já, porque não depende de nenhuma decisão.

### Os riscos

1. **Náusea e desorientação** com as rolagens e as guinadas em primeira pessoa.
   - Planos legíveis seguram quadros (a cara, o céu, o fogo).
   - A velocidade angular tem teto (C5).
   - O desfoque vai só no movimento.
   - O fogo serve de âncora de horizonte.
2. **O `Corpo` de 11 ossos com a batina GPU** em pose extrema (deitar 25°, pivô de 90° em 0,3 s) pode fazer o
   pano estourar ou atravessar as pernas. No PS1 STYLE ele anda a 15 passos.
3. **O chão a 10 cm da lente**: textura PSX de 128 px e cartões da mata de raspão. É o `ChaoDePerto`, e custa
   textura HD.
4. **O tempo: +4,1 s** mexe na roda, na multidão, na duração da cena inteira (99 → ~103 s) e no branco que a
   sessão da praça dissolve. Confirmar que o `BrancoDoSusto.dissolver` não depende de tempo absoluto.
5. **Frentes em voo**: o recorte do vidro e a manga precisam chegar antes das Fases 1 e 3. O
   `abertura_estrada.gd` e o `agarrao_do_padre.gd` são compartilhados.
6. **A GPU do chão**: a roda, 440 da multidão, o fogo e a névoa no mesmo quadro.
7. **O alcance**: 0,60–0,66 m contra 0,65 (+0,14) do `BracoDoPadre`. A mão na cara pede o ombro dele com `d`
   entre +0,12 e +0,15, ou a nossa cabeça já puxada.
8. **A regra "primeira pessoa não leva gota"** do `GotasLente`: por isso o piscar. A lama e o sangue na lente
   (psx-2f) são exceção declarada.
9. **Não há colisor** no carro nem na janela. Toda guarda é analítica, o que vale porque o carro está parado. A
   opção B da rolada (`BonecoDePano`) precisaria de colisor para o chão e o carro.

### As decisões que são do usuário

| # | pergunta | opções | recomendo |
|---|---|---|---|
| D1 | onde a cena termina | (a) no chão, com o último olhar e ele se debruçando; (b) no impacto, curta; (c) arrastado pela gola no chão até o meio da roda (+2–3 s) | a |
| D2 | onde vai a frase "Que bom que você veio" | (a) na janela, com a mão na cara, nos puxando (a que ele já aprovou); (b) no chão, em cima de nós; (c) a frase na janela e o riso no chão | c |
| D3 | o jogador reage? | (a) sim: agarra o volante e perde, e as mãos amortecem no chão; (b) (a) mais a mão batendo na coluna B; (c) passivo | a |
| D4 | o celular | (a) voa do colo no puxão; (b) fica na mão até o chão e cai na lama ao lado da cara (e se a tela acender uma última vez, isso é ideia nova e muda o "celular morreu"); (c) some no colo | a |
| D5 | como sai pela janela | (a) de costas, vendo ele puxar, o céu e a chuva; (b) de bruços, vendo o peitoril e o chão | a |
| D6 | quando vem o branco | (a) quando a palma dele tapa a lente; (b) no impacto; (c) depois do último olhar, com a roda fechando | a |
| D7 | a bota dele na porta, só som | sim / não | sim |
| D8 | a duração | completa (+4,1 s) / curta (+2,3 s) | completa, e corta no blockout se arrastar |

---

## Ferramentas desta medida (fora do repositório)

- `REF/sonda_final.gd` e `REF/sonda2.gd`: a sonda de leitura. Ela roda a cena de verdade:

  ```
  .tools/Godot_v4.7.2-stable_win64_console.exe --path game --resolution 1920x1080 --fixed-fps 30 \
    --script <sonda2.gd> -- --ver-estrada --estrada-corrida --estrada-desde=dentro --sair-no-fim \
    --sonda-pasta=<pasta>
  ```

  Ela acha a `AberturaEstrada` pelo nome global e mede a cada 0,1 s. As lentes de fora ficam em
  `<pasta>/<lente>/`.
- `REF/folha.py`: as folhas de fotos de beat. `REF/diagramas.py`: as figuras 10 e 11.
- Os mosaicos saíram de `tools/mosaico_rajada.py`.

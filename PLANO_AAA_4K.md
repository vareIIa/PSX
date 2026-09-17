# Plano AAA 4K — o preset MODERNO acima do PS1

**Criado em 16/09/2026**, a partir da seleção do usuário sobre a lista de 32
ideias levantadas no fim da Fase 6 da chuva na cabine
(`PLANO_CHUVA_CABINE_AAA.md`).

**Entram:** texturas 2K e PBR, luz global e sombras, 4K com TAA/FSR e presets,
pós-processo, céu e decalques, chuva fora do carro, carro AAA completo (com
olhar livre), mãos no volante, personagens e animação, áudio espacial, UI 4K,
modo foto e cutscenes, fim dos engasgos, oclusão e instanciamento, regressão
visual e branch compilável.

**Ficam de fora desta vez:** a Fase 7 da chuva (vidro de fora molhado,
retrovisor, som do limpador — continua aprovada no plano da chuva) e a cidade
noturna viva (janelas com interior falso, mais detalhe urbano, neon).

---

## 0. Decisões que este plano toma

1. **O PS1 STYLE continua sendo um preset, com o contrato do ART-BIBLE.** Tudo
   aqui é do **MODERNO** e passa pelo interruptor que já existe
   (`EstiloVisual` + `Settings`). Nenhuma fase pode mudar uma captura do PS1 —
   e isso é medido (critério A2), não prometido.
2. **O ART-BIBLE ganha uma seção "MODERNO"**, em vez de o MODERNO violar a do
   PS1 em silêncio. Hoje o documento proíbe normal map, SSAO, GI e reflexo, e o
   MODERNO já usa luz por pixel, névoa volumétrica e SSR: a regra escrita e o
   jogo já divergem.
3. **Alvo de saída 4K (3840×2160).** O preset 4K renderiza por FSR 2 em
   qualidade e reconstrói; 4K nativo fica como opção. Máquina de referência: a
   de desenvolvimento (RX 9070 XT), porque é a única medida que existe.
4. **Uma fonte para as duas fidelidades.** Textura, fonte tipográfica e malha
   de personagem nascem uma vez; o PS1 é derivado dela por redução, e não
   mantido à mão.
5. **Regra de convivência com as sessões paralelas, a mesma do plano da
   chuva:** trabalho novo em arquivo novo; em arquivo com trabalho não
   commitado de outra sessão, só a ligação mínima, commitada sozinha sobre o
   HEAD (ver a memória "sessões paralelas no repo"). A Fase 0 existe em parte
   porque isso hoje é frágil.

---

## 1. Estado medido (16/09/2026)

| Área | Hoje | Onde |
|---|---|---|
| Texturas | **74**: 60 de 256 px, 9 de 128, 2 de 512, `npc_atlas` 256×288, 2 de 16 | `game/assets/textures/` |
| Filtro | ponto, **sem mipmap, sem anisotrópico**, nos dois presets | `project.godot`, ART-BIBLE §6 |
| Origem das texturas | 18 são CC0 do ambientCG, baixadas em **1K e reduzidas** — só o mapa de cor é aproveitado; o resto são atlas gerados por script | `tools/baixar_texturas.py`, `tools/gerar_*.py` |
| Materiais | 105 `.tres`, gerados por tabela | `tools/gerar_materiais.py` (apaga o que não está na tabela — ver memória) |
| Luz no MODERNO | por pixel (`psx_surface_pixel`), sombra **dura** 2048, névoa volumétrica, SSR só no molhado, tonemap fílmico, glow | `EstiloVisual`, `FogController` |
| Sem | **SSAO, SSIL, SDFGI, sondas de reflexo, decalques, anti-serrilhado, upscaler** | — |
| Resolução | escada por `scaling_3d_scale` (bilinear), UI desenhada em 480×270 e multiplicada | `EstiloVisual._aplicar_resolucao` |
| UI | 4 fontes bitmap + 2 TTF; o próprio jogo avisa "escala quebrada" em 2,667× | `assets/fontes/`, `tools/gerar_fonte.py` |
| Personagens | caixas rígidas num esqueleto de 11 ossos, uma chamada cada, **15 poses por ciclo em degrau** | `src/render/corpo.gd` |
| Som | piscina de `AudioStreamPlayer3D` com atenuação; **sem eco por ambiente, sem oclusão** | `AudioDirector` |
| Cidade | **170 a 200 mil triângulos** visíveis, 49–63 chunks, sem oclusor e sem instanciamento de props | `--stats`, `ChunkManager` |
| Desempenho (1280×720, MODERNO) | **165 fps** (teto do monitor), pior quadro dirigindo 6–11 ms | Fase 6 da chuva |
| Engasgo | **143 a 150 ms** no primeiro segundo da cidade, em toda sessão | idem |
| Branch | **o HEAD da `playable` não compila sozinho**: `Clima`, `EstiloVisual`, `DiretorSombra` e três scripts só existem no working tree | idem |
| Comparação de imagem | `tools/comparar_capturas.py` (ignora ruído de pós) existe; referências em `PRINTS/` (21 imagens) | — |

---

## 2. O que "AAA 4K" significa aqui

| Significa | Não significa |
|---|---|
| Em 4K, a textura tem detalhe no metro em que o olho está, com mipmap e filtro | Esticar as de 256 px |
| Superfície tem relevo e rugosidade que respondem à luz | Mais polígono em parede |
| Canto escurece, a cor de um letreiro pinta a rua, a sombra tem penumbra | Uma luz por objeto |
| Borda estável em movimento (TAA/FSR) | Borrão |
| O carro e as pessoas reagem: amassam, sujam, molham, olham | Animação por `TIME` |
| O som diz onde você está (túnel, sala, rua estreita, dentro do carro) | Mais volume |
| Cada fase tem número, teste e captura — como na chuva | "Parece melhor" |
| O PS1 STYLE continua idêntico, captura por captura | Dois jogos |

---

## 3. Critérios de aceite

Cada critério tem medida. Os valores-alvo marcados com "≈" são calibrados na
fase de medida de base (F0) e ficam fixos a partir dali.

### Base técnica

| # | Critério | Como mede |
|---|---|---|
| A1 | **O HEAD compila sozinho**: um checkout limpo de `playable` passa `--headless --quit` sem erro | `git worktree` temporário no HEAD + Godot |
| A2 | **Regressão visual**: as capturas de referência (PS1 e MODERNO) ficam dentro da tolerância; o PS1 não muda em nenhuma fase | `tools/regressao_visual.py` (novo), sobre `comparar_capturas.py` |
| A3 | **Sem engasgo**: pior quadro na carga da cidade ≤ 33 ms (hoje 150); dirigindo ≤ 16,7 ms no preset 4K | `--stats` + medidor novo |
| A4 | **Métricas completas** por quadro: chamadas de desenho, triângulos, VRAM, tempo de GPU e de CPU | medidor novo |
| A5 | **Oclusão e instanciamento**: na mesma vista, ≥ 40% menos triângulos e ≥ 30% menos chamadas de desenho | medidor, antes e depois |

### Imagem 4K

| # | Critério | Como mede |
|---|---|---|
| A6 | **Desempenho**: preset 4K (FSR 2 qualidade) ≥ 60 fps na cidade, à noite, na chuva; preset Alto (1440p nativo) ≥ 120 | medidor, rota fixa de captura |
| A7 | **Borda estável**: num giro lento de câmera, ≤ ≈1% dos pixels de borda de geometria piscam entre quadros (hoje, sem AA) | captura em sequência, máscara de borda |
| A8 | **Texel**: toda superfície pisável ou encostável tem ≥ 512 px/m no MODERNO (hoje ~128–256); as 74 texturas têm versão HD | sonda de densidade + inventário |
| A9 | **Relevo**: sob luz rasante, a variância de luminância de uma parede de tijolo é ≥ ≈3× a da mesma parede sem normal map | bancada de material |
| A10 | **VRAM** do preset 4K ≤ ≈3 GB | medidor |
| A11 | **Oclusão de ambiente**: a quina entre parede e chão é ≥ ≈15% mais escura com SSAO; **sombra de contato** sob o carro | bancada de luz |
| A12 | **Luz global**: um letreiro vermelho desloca o matiz do asfalto a 2 m dele | captura com e sem GI |
| A13 | **Penumbra**: a sombra do poste tem penumbra > 0 no MODERNO e = 0 no PS1 | bancada de luz |
| A14 | **Reflexo**: com sonda, a poça continua refletindo quando o objeto sai da tela (onde o SSR perde) | captura girando a câmera |
| A15 | **Exposição**: de um interior escuro para a rua clara, a exposição assenta em ≤ 2 s; o desfoque de movimento só existe dirigindo; a profundidade de campo só em cutscene e modo foto | captura em sequência |
| A16 | **Céu**: nuvens com volume, e o relâmpago acende as nuvens (luminância do céu sobe durante o clarão) | captura |
| A31 | **Luz sem aresta**: no MODERNO, nenhuma superfície contínua tem um degrau de luminância que não venha de sombra ou de material — em particular, o facho de poste e de farol não desenha borda reta. Hoje, na parada `poste_perto`, o cone somado acende **29,9% da tela**, com **+45,7/255** de média e **+162/255** de pico, e apaga o prédio atrás dele | rota `luz`, com e sem `--sem-facho` |
| A32 | **Chuva no facho cai**: dentro do feixe, o risco de chuva desce. Hoje ele **sobe** (sinal trocado em `psx_light_cone.gdshader`) | duas capturas seguidas, deslocamento do padrão |
| A33 | **O poste reage à própria luz**: a luminária projeta sombra do poste e do braço (hoje `shadow_enabled = false` na luz da lâmpada) | captura |
| A34 | **Janela é vidro**: a janela reflete o céu e mostra o que há atrás dela; nenhum material de janela usa textura de outra superfície | inventário de materiais + captura |
| A35 | **Molhabilidade completa**: nenhuma superfície de rua fora da tabela da `EstiloVisual` (hoje: 9 de fachada, fora) | teste que varre `resources/materials/` |
| A36 | **Telhado e fachada mineira**: telha cerâmica com beiral, reboco pintado e tijolo com conjunto HD próprio; a viela deixa de ser parede de metal ondulado de alto a baixo | captura + inventário |
| A37 | **Casa em 4K**: a casa (`casa_atlas`, hoje 256 px sem conjunto HD) tem ≥ 512 px/m como o resto | sonda de densidade (A8) |
| A17 | **Decalques**: poça, óleo e pichação aparecem na rua molhada; ≤ ≈12 por chunk | contagem + captura |

### Mundo, carro e gente

| # | Critério | Como mede |
|---|---|---|
| A18 | **Chuva fora do carro**: respingo na lataria em ≤ 1 s de chuva; goteira na borda de marquise; roupa ≥ ≈20% mais escura depois de ≈30 s na chuva; gota na lente em terceira pessoa só sem cobertura | bancadas + captura |
| A19 | **Poça viva**: pneu deixa rastro na poça, passa jato d'água, farol risca o asfalto molhado | captura noturna |
| A20 | **Amassado**: batida de força ≥ 0,6 desloca ≥ 3 cm de lataria no ponto do impacto, sem atravessar a cabine (reusa `checar_cabine_contida`) | bancada de batida |
| A21 | **Sujeira**: a lama acumula com a distância em terra e a chuva lava | bancada |
| A22 | **Luzes do carro**: seta pisca a ≈1,5 Hz para o jogador também; luz de cabine; lente de farol com refletor | captura + nós |
| A23 | **Cabine interativa**: ponteiro de giro, alavanca de câmbio, pedais e rádio respondem ao que o carro está fazendo (medido pela transformada dos nós, como a ponta do limpador) | teste |
| A24 | **Olhar livre ao volante**: ±100° de guinada e ±60° de arfagem, volta ao centro em ≤ 0,8 s | teste |
| A25 | **Mãos no volante**: a ponta dos dedos acompanha o aro (≤ 1 cm) no esterço inteiro; a troca de marcha leva ≤ 0,4 s | sonda pela ponta |
| A26 | **Personagem MODERNO**: sem fresta no ombro (sonda por raio), animação interpolada a 30/60 fps, pé a ≤ 2 cm do degrau (IK), olhar dos NPCs para o jogador; **PS1 igual** | sondas + A2 |
| A27 | **Som espacial**: tempo de eco diferente por ambiente (rua, túnel, sala); ≥ 6 dB de oclusão atrás de parede; camada de chuva no teto do carro por dentro; Doppler nos carros | bancada de áudio |

### Tela

| # | Critério | Como mede |
|---|---|---|
| A28 | **Texto em qualquer escala**: hastes da fonte com a mesma largura em 1,5×, 2×, 2,667× e 4× (a medida que o jogo já faz e hoje falha) | `checar_hud` estendido |
| A29 | **Modo foto**: câmera livre, profundidade de campo, exposição, filtros, sem HUD, salva PNG 3840×2160 | teste |
| A30 | **Cutscene**: letterbox 2,35:1, profundidade de campo nos planos marcados, legenda dentro da área segura e com tempo ≥ o de leitura | captura + teste |

---

## 4. Arquitetura

### 4.1 Duas fidelidades, uma fonte

- **Texturas.** `tools/baixar_texturas.py` passa a guardar o conjunto PBR do
  ambientCG em **2K** (cor, normal, rugosidade, oclusão) em
  `game/assets/textures_hd/`, e a gerar o PS1 **da mesma fonte**, pela redução
  que já faz. Os atlas gerados (`gerar_*.py`) ganham um parâmetro de escala e
  saem em 4× para o MODERNO.
- **Importação.** Preset por pasta: `textures_hd/` com mipmap, compressão VRAM
  e anisotrópico; `textures/` continua como está (ART-BIBLE §6).
- **Materiais.** Um gerador **novo**, `tools/gerar_materiais_hd.py`, escreve
  em `resources/materials_hd/`. Não mexe em `gerar_materiais.py`: ele apaga o
  que não está na tabela dele (memória do projeto), e dois geradores na mesma
  pasta brigariam.
- **Troca.** `EstiloVisual` já troca o shader de todos os materiais de
  superfície; passa a trocar também o **conjunto** de texturas e mapas, pelo
  mesmo mapeamento que ele já faz. O PS1 continua carregando só o que carrega
  hoje.
- **Shader.** `psx_surface_pixel.gdshader` ganha normal, rugosidade e oclusão
  opcionais (uniform nulo = comportamento de hoje), com a camada de molhado que
  já existe por cima.

### 4.2 Qualidade gráfica

- `src/systems/qualidade_grafica.gd` (novo): presets **Baixo, Médio, Alto,
  Ultra, 4K** para o MODERNO — resolução interna, FSR/TAA, sombras, GI, SSAO,
  reflexos, texturas, decalques, distância de desenho. O PS1 STYLE fica fora
  da escada, como é hoje.
- O `Environment` é escrito hoje pelo `FogController`, que é de outra frente:
  a qualidade escreve **depois** dele, por um ponto de extensão pequeno, e não
  dentro dele.

### 4.3 Medir antes de mexer

- `src/systems/medidor_quadro.gd` (novo, não dentro do `CaptureTool`, que tem
  WIP alheio): chamadas de desenho, triângulos, VRAM, tempo de GPU e CPU por
  quadro, com `--medir=ARQ` escrevendo CSV.
- **Rota fixa de captura**: um percurso determinístico na cidade (noite,
  chuva, avenida, interior, rua estreita) que todas as fases usam. Sem isso,
  cada medida pega um carro e uma rua diferentes — foi exatamente o que tornou
  inconclusivo o primeiro A/B da Fase 6.

### 4.4 Regressão visual

- `tools/regressao_visual.py` (novo): roda a rota de captura nos dois
  presets, compara com as referências em `captures/referencia/` usando
  `comparar_capturas.py` (que já ignora o ruído animado do pós), e reprova
  acima da tolerância. Máscaras para o que é vivo por definição (chuva,
  trânsito).

---

## 5. Fases

Tamanho: **P** (dias), **M** (uma a duas semanas), **G** (mais que isso).
Cada fase segue o método da chuva: medida de base → bancada → implementação →
teste → captura → commit com o resultado medido escrito aqui.

### Fase 0 — Base técnica · M · **RÉGUAS FEITAS em 16/09/2026**

1. **Branch compilável (A1).** Levantar tudo que o HEAD referencia e não tem
   (`clima.gd`, `estilo_visual.gd`, `diretor_sombra.gd`, `relampago.gd`,
   autoloads no `project.godot`) e combinar com as sessões donas o commit
   deles. Script `tools/checar_head.sh`: checkout do HEAD num worktree
   temporário + `--headless --quit`.
2. **Medidor de quadro e rota fixa (A4).**
3. **Regressão visual (A2)**, com as referências tiradas **antes** de qualquer
   outra fase.
4. **Fim dos engasgos (A3).** Medir de onde vêm os 150 ms (compilação de
   shader, carga de chunk, montagem de NPC); aquecer os shaders numa tela de
   carregamento que desenha cada material uma vez fora de vista; espalhar a
   montagem de chunk por quadros.
- **Fecha A1–A4.**

**Resultado medido (16/09/2026).** A Fase 0 entregou as três réguas; o conserto
do HEAD está **medido e pronto, esperando autorização** (ver o fim da seção).

**A1 — o HEAD compila sozinho.** `tools/checar_head.sh` copia uma revisão com
`git archive` para uma pasta temporária, importa, compila todo script, carrega
toda cena, recurso e shader, e depois **roda a cidade** por 1.200 quadros sem
janela. Três decisões que a medida obrigou:

- a checagem roda como **cena principal**, e não por `--script`: no `--script` os
  nomes dos autoloads não existem para o compilador, e todo script que usa
  `Settings` ou `Clima` pareceria quebrado sem estar;
- `can_instantiate()` **não é veredito**: medido, um script cujas dependências
  não compilam volta verdadeiro. Quem decide é a mensagem do motor, atribuída ao
  arquivo pela linha `at:` logo abaixo;
- a cena confere os `global uniform` contra o `[shader_globals]`, porque o modo
  headless **não compila shader** — sem isso, um global faltando só quebraria com
  a janela aberta.

| | Resultado |
|---|---|
| HEAD `9bf5631` | **A1 FALHA**: `carro_cena.gd` usa `Motor`, `SombraContato`, `Clima`, `KitEstrada.altura_da_pista` e `MotorSom.atualizar` de 7 argumentos, e dois shaders usam `global uniform psx_facho_suave` sem o `[shader_globals]` que o declara |
| Fecho mínimo | **15 arquivos** do working tree (≈4.600 linhas), nenhum deles em branch alguma |
| Árvore candidata (HEAD + fecho) | **A1 OK**: 179 scripts, 16 shaders, 129 recursos, 10 cenas, 0 falhas; cidade com 25 chunks por 1.200 quadros, 0 erros |
| Working tree de hoje | A1 OK (linha de base) |

**A4 — medidor de quadro.** `src/systems/medidor_quadro.gd` (autoload, dorme sem
`--medir`) grava CSV com tempo de quadro, `_process`, física, CPU e GPU de
render, chamadas de desenho, triângulos, objetos, VRAM, textura, buffer,
**compilações de pipeline**, memória, nós, chunks e a parada da rota. Ele desliga
o vsync ao medir: com vsync, **toda** parada desta cidade devolve exatamente
6,1 ms (165 Hz), inclusive um interior de 24 chamadas de desenho — não dá para
ver folga nem perda assim.

Base medida, 1280×720, MODERNO, noite com chuva, sem vsync:

| Parada | Chamadas | Quadro (mediana) |
|---|---|---|
| avenida | 255 | 1,3 ms |
| cruzamento (com trânsito) | 359 | 1,4 ms |
| rua estreita (viela) | 180 | 1,4 ms |
| praça da igreja | 330 | 1,4 ms |
| interior | 24 | 1,1 ms |
| **rota inteira** | mediana 243, pior 410 | mediana **1,4 ms (720 fps)**, 95 = 1,9 ms |

Triângulos: mediana 39 mil, pior 381 mil. VRAM 248 MB, render CPU 0,34 ms, GPU
0,30 ms. **É a folga que o 4K vai gastar** — e agora ela tem número.

**Rota fixa.** `src/systems/rota_captura.gd` + `resources/rotas/cidade.json`:
cinco paradas (avenida, cruzamento, viela, fachada da igreja, interior), câmera
própria com o jogador fora da física, espera de assentamento pelo streaming,
foto **sem HUD** (o relógio da HUD muda a cada execução e envenenaria a
regressão) e cão de guarda de 120 s. As coordenadas saem da malha urbana, que é
estática e determinística. O JSON é lido pelo jogo **e** pelo Python: duas
definições seriam duas rotas.

**A2 — regressão visual.** `tools/regressao_visual.py` roda a rota nos dois
presets e compara com `captures/referencia/`. O piso de ruído da bancada, medido
rodando a mesma build duas vezes:

| Parada | Erro médio | Blocos diferentes |
|---|---|---|
| avenida | 1,27/255 | 3,9% |
| rua estreita | 1,11/255 | 2,1% |
| interior | 1,17/255 | 1,5% |
| praça da igreja | 1,75/255 | 6,5% |
| **cruzamento** | **18,27/255** | **22,5%** |

Contra a referência, na execução seguinte: **A2 OK nos dois presets**, com 0,41 a
1,96/255 — tudo dentro do piso. O cruzamento é o **trânsito**: os carros estão em lugar diferente a cada
execução. Ele ficou marcado como parada **viva** — fora da comparação, dentro da
medida de desempenho, onde é a melhor parada que existe. Referências gravadas
nos dois presets.

**A3 — de onde vêm os engasgos.** A primeira descoberta desmancha o número que
estava escrito aqui: **os "150 ms" eram o teto do `delta`** do motor, idêntico em
execução com e sem janela. O relógio conta outra história:

| | Medido |
|---|---|
| Motor + instanciação de tudo (compilar script, `_init`) | **2,58 s** |
| `_ready` de todos os autoloads + montagem da cena + 1º quadro | **0,86 s** |
| **Largada total** | **3,43 s** |
| Quadro 2 (compilação de 35 a 40 pipelines de shader) | **47 a 50 ms** |
| Regime, andando na cidade | mediana 1,4 ms, **pior 2,3 ms** |
| Materialização de chunk | 139 vezes, **0,2 a 10 ms cada, 0 engasgos** |

Ou seja: **chunk não é o culpado** (o `ChunkManager` já materializa um por
quadro), e **em regime não há engasgo nenhum**. O que existe é largada: 3,4 s
antes do primeiro quadro, e um engasgo de shader logo depois.

Onde os 2,58 s se vão, autoload por autoload (`tools/medir_largada.sh`, sem
janela, o menor de duas execuções; a repartição vale, o absoluto é menor que com
janela):

| Autoload | Custo |
|---|---|
| RegistroCivil | **+460 ms** |
| Terminal | +219 ms |
| BlitzManager | +172 ms |
| SaveGame | +136 ms |
| EstiloVisual | +120 ms |
| Missoes | +117 ms |
| Transito | +82 ms |
| Interiores | +65 ms |
| os outros 17 juntos | +230 ms |
| motor sozinho | 123 ms |

Não dá para medir isso de dentro de uma execução: quando o `_ready` do primeiro
autoload roda, os 26 filhos de `/root` **já existem** — o motor instancia tudo e
só depois propaga `_ready`. Por isso a medida vem de execuções separadas, com a
lista truncada.

**A1 fechado em `3969539`.** Com autorização do usuário, o fecho de 15 arquivos
foi commitado no estado em que estava no working tree, junto com
`tools/comparar_capturas.py` e a linha do autoload do medidor. `bash
tools/checar_head.sh` no HEAD: **A1 OK** — 181 scripts, 16 shaders, 129 recursos,
10 cenas, 0 falhas, e a cidade com 25 chunks por 1.200 quadros sem erro. A branch
volta a compilar sozinha pela primeira vez desde a Fase 3 da chuva.

**O que falta da Fase 0.** Só o conserto do A3, e ele é de outras frentes: a
largada é `RegistroCivil` (+460 ms), `Terminal` (+219), `BlitzManager` (+172) e
`SaveGame` (+136). O conserto natural é adiar o que eles fazem no `_ready` para a
primeira vez em que são usados; a medida já diz em quem mexer e quanto vale cada
um. Em regime **não há engasgo nenhum** (pior quadro 2,3 ms), então isto é tempo
de carregamento, não de jogo.


### Fase 1 — Desempenho para 4K · M · **OCLUSÃO FEITA em 16/09/2026**

- **Oclusão**: `ChunkBuilder` gera um `OccluderInstance3D` por quadra a partir
  das caixas de prédio que ele já monta (o Godot 4 faz a oclusão por
  rasterização em CPU; oclusor simples = caixa).
- **Instanciamento**: poste, placa, lixeira, árvore e prop repetido por chunk
  viram `MultiMeshInstance3D` (uma chamada por tipo).
- **Níveis de detalhe**: malha procedural gera LOD na montagem
  (`ImporterMesh.generate_lods`); distância de desenho por preset.
- **Fecha A5** e abre folga para A6.

**Resultado medido (16/09/2026).**

**Oclusão feita, e de graça em imagem.** O `ChunkManager` passou a montar um
`OccluderInstance3D` por chunk a partir das caixas de colisão que o
`ChunkBuilder` já produz — as de 3 m ou mais são prédio (4 a 6 por chunk, até
15 m). Um `ArrayOccluder3D` só por chunk, cada caixa encolhida 15 cm para ficar
**por dentro** da geometria que representa. `use_occlusion_culling` ligado no
`project.godot`.

| Parada | Chamadas antes | Depois | |
|---|---|---|---|
| avenida | 235 | **175** | −26% |
| rua estreita | 173 | **123** | −29% |
| praça da igreja | 387 | **334** | −14% |
| cruzamento | 339 | **308** | −9% |
| **mediana da rota** | 231 | **170** | **−26%** |
| triângulos (mediana) | 38.416 | **32.436** | −15% |

E o mais importante: **A2 OK nos dois presets**, 0,42 a 1,85/255 — a imagem não
mudou em pixel nenhum. Oclusão correta é exatamente isso: menos trabalho, mesma
imagem.

**O resto da Fase 1 não é onde está o custo, e a medida é que diz.** Os alvos do
A5 (−40% de triângulo, −30% de chamada) foram escritos antes de existir medida.
Com medida: a cidade desenha **32 mil triângulos** e gasta **0,3 ms de GPU** e
1,0 a 1,4 ms de quadro, num orçamento de 16,7. Níveis de detalhe e MultiMesh
mexeriam em geometria que já não pesa — e a distância de desenho, que seria o
outro lever, **já é dirigida pela névoa** (`fog_end`), então encurtá-la mudaria a
imagem. O que o 4K vai cobrar é **pixel**, não triângulo, e isso é a Fase 2.
Fica registrado: se a Fase 4 (luz global, sombras) apertar, a primeira coisa a
buscar é LOD, e o gancho é `ImporterMesh.generate_lods` na montagem do chunk.

**Achado para outra frente:** doze trechos da estrada (`trecho_001` a `012`,
**390 mil triângulos** somados) ficam residentes durante o jogo na cidade —
inclusive dentro de um apartamento. Eles não são desenhados (ficam fora do campo
de visão), mas ocupam memória e colisão o tempo todo. Quem monta é a abertura
(`EstradaBuilder`, via `cidade.gd`).

**`--rota-censo`** (novo) diz **de quem** são as malhas em cada parada, por dono
e por triângulo. O medidor diz quantas chamadas há; o censo diz de quem, que é o
que aponta onde mexer.

### Fase 2 — 4K e anti-serrilhado · M · **FEITA em 16/09/2026**

- MODERNO: `scaling_3d_mode` FSR 2 + TAA; nitidez calibrada; presets de
  `QualidadeGrafica`.
- O PS1 continua **sem** AA (ART-BIBLE: o serrilhado é parte do alvo).
- Risco conhecido: TAA com o *snap* de vértice deixa rastro — o MODERNO já tem o
  snap desligado; conferir nas capturas.
- **Fecha A6, A7** (e mede A10 com os presets).

**Resultado medido (16/09/2026).** `src/systems/qualidade_grafica.gd` (novo,
autoload depois do `EstiloVisual`) é a escada do MODERNO: cada nível manda a
**fração** da altura da janela em que o 3D é renderizado e o que reconstrói o
resto. Fração, e não número absoluto: `Settings.resolucao_3d` é 1280×720 fixo, e
num monitor 4K isso vira escala 0,33 — o "1280×720" deixa de querer dizer nada.

| Nível | Render | Reconstrução |
|---|---|---|
| baixo | 50% | FSR 2 |
| médio | 59% | FSR 2 |
| alto | 67% | FSR 2 |
| ultra | 77% | FSR 2 |
| **4k (padrão)** | **100%** | **TAA** |
| cru | 100% | nada — é a linha de base do A7 |

**A6 — desempenho em 4K.** Janela 3840×2160, cidade à noite na chuva, rota fixa:

| Nível | Quadro (mediana) | fps |
|---|---|---|
| 4k nativo + TAA | **2,8 ms** | **360** |
| ultra (FSR 2, 77%) | 2,7 ms | 372 |
| alto (FSR 2, 67%) | 2,4 ms | 420 |

O alvo do A6 era ≥ 60 fps em 4K. A medida dá **360**, e por isso o **padrão é
nativo**: reconstruir a partir de 67% pouparia meio milissegundo de um orçamento
de 16,7 e cobraria nitidez em troca. A escada existe para máquina menor, e quem
desce nela é o jogador.

**A7 — borda.** A primeira bancada mediu a coisa errada: com 0,15 s entre as duas
fotos, o TAA já reconvergiu e o que sobrou foi o deslocamento da câmera, não o
tremor — os quatro casos deram 14 a 17% e não separavam nada. A medida que separa
é estática: **quão dura é a transição na borda** (o pixel do meio fica entre os
vizinhos, ou o degrau atravessa em um pixel só).

| | Transições duras |
|---|---|
| MODERNO nativo **sem** AA (`cru`) | **87,1%** |
| MODERNO nativo + TAA | **52,5%** |
| MODERNO FSR 2 a 77% | **47,4%** |
| PS1 STYLE | **79,8%** — e continua assim, por contrato |

**A2 OK nos dois presets** depois de tudo isso: em resolução nativa o TAA não
move a comparação por blocos além do ruído, e o PS1 não é tocado (o autoload
devolve bilinear e TAA desligado quando o estilo é PS1).

**Sobre FSR 3 e FSR 4.** O Godot 4.7.2 expõe `BILINEAR`, `FSR` (1.0), `FSR2`,
`NEAREST` e MetalFX (só macOS) — conferido no motor, não na documentação. FSR 3 e
FSR 4 não existem aqui: FSR 4 é ML, exige RDNA 4 no jogador e vem do SDK da AMD,
que precisaria de uma build própria do motor. E a medida diz que não há o que
comprar com isso: em 4K nativo sobram 14 ms dos 16,7. Se um dia faltar
desempenho, o caminho barato é descer um degrau da escada que já existe.

### Fase 3 — Texturas 1K e PBR · G · **FEITA em 16/09/2026**

- Pipeline da Seção 4.1; conjuntos 2K para as 18 texturas do ambientCG;
  escolha de conjuntos CC0 para as superfícies que hoje são geradas (fachada,
  calçada, interiores); atlas gerados em 4×.
- Bancada de material (`tests/medir_material.gd`): parede sob luz rasante,
  densidade de texel, VRAM.
- **Fecha A8, A9, A10.**

**Resultado medido (16/09/2026) — seis superfícies, e as réguas prontas.**

**A fonte é a mesma, e não houve download.** `tools/texturas_hd.py` abre o
**mesmo zip** do ambientCG que `baixar_texturas.py` já tinha em cache e aproveita
o que ele descartava: normal, rugosidade e oclusão. Saem três arquivos por
superfície — cor 1024 px, normal, e um PNG com rugosidade no vermelho e oclusão
no verde. `tools/importar_hd.py` liga mipmap e compressão de VRAM só nessa pasta;
o resto do projeto continua com o contrato do ART-BIBLE (filtro ponto, sem
mipmap).

**Por que 1024 e não 2048.** `tests/medir_texel.gd` (novo) mede densidade de
textura pela malha: para cada triângulo, área em metros contra área em UV.

| | Antes | Com o conjunto HD |
|---|---|---|
| parede suja (5.232 m²) | 189 px/m | **757** |
| terra (1.778 m²) | 128 | **512** |
| asfalto (831 m²) | 128 | **512** |
| calçada (469 m²) | 128 | **512** |
| **média ponderada por área** | **164 px/m** | **596** (alvo 512) |

A 2048 seria o dobro disso e o quádruplo de VRAM, para detalhe que a rua não tem
como mostrar.

**A9 — relevo, e três erros de bancada antes do número.** `tests/bancada_relevo.gd`
(novo) monta o que a rua não oferece: painel de 4 m, luz a 8° do plano, e mais
nada. Três coisas tiveram de ser consertadas antes de a medida querer dizer algo:

1. a bancada herdava o ambiente do projeto, e a luz ambiente lavava o painel;
2. a luz vinha só de um azimute — o mapa do metal ondulado varia quase só no eixo
   Y da tangente (desvio 52,6 no verde contra 1,3 no vermelho), e luz rasante
   pelo X atravessa a nervura sem fazer sombra. Agora são três azimutes e vale o
   melhor;
3. a textura estava 4× mais comprimida que na rua (0,5 m por repetição contra os
   2 m medidos), e nessa escala o relevo de tijolo vira detalhe de um pixel.

| Superfície | Desvio com relevo | Sem | Razão |
|---|---|---|---|
| metal ondulado | 63,5 | 11,9 | **5,32×** |
| asfalto | 4,8 | 2,9 | **1,66×** |
| tijolo | 30,1 | 22,4 | 1,34× |
| calçada | 15,6 | 14,8 | 1,05× |

O alvo escrito no A9 (≥3×) vale para superfície com relevo de verdade. Asfalto e
calçada **são** quase planos na foto, e a força do relevo fica em 1,0 — o mapa
como a foto tem. Forçar 2,0 leva tijolo a 1,64× e asfalto a 2,50×, ao custo de
parecer plástico; o parâmetro existe por material, para quando uma superfície
pedir.

**A10 — VRAM.** Medido em 4K, par com e sem o conjunto, um logo após o outro:
**968 MB contra 945** (textura: 814 contra 796). O alvo era ≤ 3 GB. O custo de
quadro é **+0,5 ms** em 4K.

**A2 OK nos dois presets.** O PS1 STYLE não vê o conjunto HD: quem liga é o
`EstiloVisual`, no mesmo ponto em que troca o shader, e em PS1 o `usa_hd` vai a
falso e o material volta ao albedo de 256 px com filtro ponto.

**Duas armadilhas que custaram caro.** O mapa de normal é importado com
compressão própria (RGTC/BC5), que guarda **dois canais**: lendo `.z` direto, a
normal aponta para qualquer lado e a cidade inteira fica preta — foi a primeira
captura desta fase. E a cidade é procedural, sem tangente nas malhas, então o
`NORMAL_MAP` do Godot não serve: o shader monta a base tangente das **derivadas
de tela**, o que evita 30% a mais de vértice em memória.

**Fechamento (mesmo dia): o catálogo inteiro, e dois atlas desenhados.**

- as **18** texturas do ambientCG têm conjunto HD, e não só seis;
- **`gerar_sinais.py`** e **`gerar_cidade.py`** ganharam `--escala=N`, que **refaz
  o desenho maior** em vez de ampliar: a tinta de via sai em 512 px e a folhagem
  em 1024, com grão, falha e aglomerado de folha do mesmo tamanho **em metros**.
  Ampliar a de 256 não acrescentaria detalhe nenhum, só pixel inventado, e o A8
  mede detalhe por metro;
- a chave do conjunto passou a ser o nome da **textura**, e não o do material.
  Seis materiais usam `metal.png`, e `mat_janela_apagada` é um deles: pelo nome
  do material, a janela ficava sem conjunto mesmo com o de `metal` pronto em
  disco. Com a correção, os materiais de superfície com conjunto foram de 17 para
  **31**.

| | Antes da fase | Agora |
|---|---|---|
| Densidade média (ponderada por área) | 164 px/m | **676** |
| Superfícies da cidade sem conjunto | 14 de 14 | **1** (casca de árvore, 13 m²) |
| VRAM em 4K | 945 MB | **1.005** (teto: 3 GB) |
| Regressão | — | **A2 OK nos dois presets** |

Dois erros de escala que a medida pegou: escalar raio **e** quantidade dos
aglomerados de folha levou a cobertura do recorte de 75% para 100% — a copa
deixou de ser vazada, que é o defeito que o próprio gerador tem comentário para
evitar. A quantidade não muda com a escala; só o raio. E a densidade de falha da
tinta é por **área**: mantendo o limiar, quatro vezes mais pixels dariam dezesseis
vezes mais buracos e a tinta viraria renda.

**O que ficou:** a casca de árvore (13 m²) e os atlas com constante de desenho
própria (grama, areia, pedra do parque), que escalariam um a um sem ganho que
pague o risco de mexer na arte. E 2K, se um dia fizer falta: é baixar o zip 2K e
rodar de novo.

### Fase 4 — Luz global e sombras · G · **FEITA em 16/09/2026**

- **SDFGI** na cidade (letreiros e postes emissivos tingindo a rua), com
  distância e células por preset.
- **Interiores** (bar, mercado, casa): `VoxelGI` por cômodo — a geometria é
  procedural e não tem UV2 para lightmap; `LightmapGI` só se a Fase 3 trouxer
  desembrulho automático.
- **SSAO + SSIL**, **sombra de contato** e **sombra suave** (filtro de sombra
  por preset; o PS1 continua duro).
- **Sondas de reflexo** por rua e por cômodo.
- Cuidado: a direção de arte é noturna e escura; GI que clareia tudo é defeito.
  As referências de `PRINTS/` entram na regressão.
- **Fecha A11–A14.**

**O facho deixou de ser geometria no MODERNO — FEITO em 16/09/2026 (A31, A32).**
Medido na rota `luz` (parada `poste_perto`, noite com chuva):

| | Com o cone somado | Sem ele |
|---|---|---|
| Tela acesa pelo cone | **29,9%** | — |
| Clareamento médio nesses pixels | **+45,7/255** (pico +162) | — |
| O que se vê | um triângulo de névoa branca de bordas retas por cima do prédio | a rua molhada, com a luz da lâmpada no muro |

A lâmpada de rua é uma `OmniLight3D` **mais** um tronco de cone de 8 lados somado
por cima (`PSXMesh.cone(..., 8, 3)`, `blend_add`); o farol do carro é um
`SpotLight3D` de 34°. O que o jogador chama de "cone" é a **malha**, não a luz: o
teste com `--sem-facho` separa os dois e a rua fica correta sem ela.

**O que foi feito.** No MODERNO o cone de malha não é mais desenhado, nem no
poste (`Lampada`) nem no carro da cidade (`Carro`): o halo no ar passa a vir da
**névoa volumétrica**, que o Forward+ já desenhava por baixo dele —
`light_volumetric_fog_energy = 8` na própria lâmpada e no farol. No PS1 STYLE
nada muda: lá o cone somado **é** a técnica, e o ART-BIBLE manda.

Só ganha halo quem **tinha** cone. A lâmpada de teto de um cômodo nasce com
`facho_visivel = false` e nunca teve cone; dar o mesmo empurrão a ela encheu a
sala de bruma — medido, +11,2/255 em 80% dos blocos do interior da rota, e foi a
regressão visual que pegou.

O 8 saiu de uma calibração com duas paradas discordando. O contraste do halo
contra o céu cresce com a energia (8 → 73, 18 → 98, 36 → 124), mas a 4,5 m da
lâmpada, **dentro** do halo, 18 lava o quadro inteiro e mostra os anéis da grade
da névoa volumétrica. Contraste maior num enquadramento não vale o quadro
estragado no outro.

| Depois | Medido |
|---|---|
| Cone de malha no MODERNO | **0%** da tela (a cena com e sem `--sem-facho` é a mesma, dentro do ruído: 1,17 e 0,92/255 por bloco) |
| PS1 STYLE | **A2 OK**, 1,15 a 1,90/255 — inalterado, captura por captura |
| MODERNO | mudou só onde há poste: avenida 3,12/255 e praça 6,96; viela 1,20 (viela não ganha poste) e interior 0,41. Referências regravadas |
| Custo | **mais barato**: 228 chamadas contra 243 e 1,1 ms de mediana contra 1,4 — o cone somado era desenho transparente a mais |
| A33 | já estava resolvido: o `DiretorSombra` acende sombra nas duas lâmpadas mais próximas no MODERNO (`grupo=57 candidatas=3 ligadas=2`), e nenhuma no PS1 |
| A32 | sinal corrigido em `psx_light_cone.gdshader`. A direção na rua não serve de régua: o `dy=0` domina por causa do poste e dos fios parados, e os dois seguintes são +1 e +2 (para baixo). Uma bancada com o cone contra fundo preto fecha isso na fase da luz |

**O que ficou:** os **anéis** da grade da névoa volumétrica aparecem de perto —
é resolução de froxel, e entra na Fase 4 com o resto da luz. E o carro da
cutscene (`CarroCena`) continua com o cone somado de propósito: os planos da
abertura foram calibrados contra ele, e mexer ali é mexer nas capturas da
abertura.

**Resultado medido (16/09/2026) — A11, A12 e A13 fechados; A14 fica.**

A escada de qualidade ganhou a luz: **oclusão de ambiente (SSAO)**, **luz
indireta de tela (SSIL)**, **luz global (SDFGI)** e **penumbra**, degrau por
degrau. Quem escreve é a `QualidadeGrafica`, depois do `FogController` — que
deixou de zerar SSAO e SDFGI a cada troca de preset, pelo mesmo motivo que já não
decidia o SSR: zerar o que outro sistema ligou mata o recurso em silêncio.

**`tests/bancada_luz.gd`** (nova): três paredes cinzas, uma luz, um cubo e um
letreiro vermelho. Cada critério tem seu **par de fotos, mudando só o recurso
medido** — a primeira versão comparava tudo ligado contra tudo desligado e mediu
a quina **8% mais clara** com oclusão, porque a luz indireta devolvia ao canto
mais luz do que a oclusão tirava.

| | Medido |
|---|---|
| **A11** quina mais escura com SSAO | **16,7%** (alvo 15%) |
| **A12** viés vermelho do chão ao lado do letreiro | **+0,190** (era 0,111 sem GI) |
| **A13** dureza da borda da sombra | **1,45× mais macia** com penumbra |
| **A14** verde na poça vindo de fora da tela | **+0,210** (era −0,008 sem sonda) |

**Quatro erros de bancada antes de cada número.** A oclusão age sobre luz
**ambiente**: com o sol dominando (2,2 contra 0,3), ela mexia em 0,5% do que se
via. O letreiro precisava **emitir**, não só ser vermelho. `shadow_blur` **não faz
nada** numa luz direcional — no sol, penumbra é `light_angular_distance`. E a
largura de borda medida num ponto caía no pé do objeto, onde penumbra é zero por
definição; o que vale é a **inclinação** da transição.

**O sol tem 3°, e não 0,53°.** Com o tamanho angular real do sol a penumbra desta
cidade é **sub-pixel** (1,00× na bancada). A 2,4° dá 1,21× e a 4,8°, 1,63×. Três
graus põem a penumbra onde o olho a vê sem virar mancha — o mesmo exagero que
qualquer jogo faz.

**A noite ficou legível sem virar dia.** Com `sdfgi_energy = 1,0` a mediana da
avenida noturna sobe de 1 para 15,6 de 255: metade da tela deixa de ser preto
absoluto. Com 0,35 volta ao preto. Em **0,6**, a mediana fica em 8,0 e o realce
não se mexe (p95 39,8 → 41,1) — a sombra ganha leitura e o peso da noite fica.

| 3840×2160, cidade à noite na chuva | Quadro | fps |
|---|---|---|
| 4k nativo + TAA + AO + SSIL + GI | **8,5 ms** | **118** |
| alto (FSR 2 67%, só AO) | 6,1 ms | 165 |
| baixo (FSR 2 50%, sem luz) | 5,6 ms | 180 |

**A2 OK nos dois presets**, e o PS1 não vê nada disso: lá nenhuma luz projeta
sombra, e o `FogController` continua desligando tudo.

**A14 — sondas de reflexo, fechado no mesmo dia.** Na bancada, um painel verde
fica **acima** da poça, fora do enquadramento: com sonda ele aparece no reflexo
com **+0,210** de viés de cor; sem ela, nada (−0,008). Atrás da câmera não serve,
por geometria — o raio que sai do olho, bate na poça e reflete continua indo para
a frente, e a poça mostra a parede do fundo, nunca o que está às costas de quem
olha.

**Uma sonda por chunk não deu.** A primeira versão montava a `ReflectionProbe`
junto com o chunk: cada uma custa seis renderizações da cena no quadro em que
nasce, e a rota passou a ter **oito engasgos, cinco em quadro de chunk novo** —
o que o A3 proíbe. Reduzir o atlas de reflexo de 256 para 128 px não mudou nada,
porque o custo não é de resolução. `SondasReflexo` (novo) troca o desenho: **quatro
sondas seguem o jogador** e no máximo **uma se refaz por quadro**. O custo deixa
de crescer com a cidade.

| Andando na cidade, 4K, tudo ligado | |
|---|---|
| Quadro | **7,1 ms** (140 fps) |
| Engasgos ≥ 33 ms | **3**, e são os da largada |

**A regressão passou a capturar sem trânsito e sem multidão** (`--rota-sem-vida`).
Com luz global e sondas, um carro que passa deixou de ser detalhe no canto: o
farol dele rebate na parede, entra na sonda, e duas execuções da **mesma** build
passaram a diferir em 7,3/255 sobre 22% dos blocos da avenida. Quem mede
desempenho continua rodando com a rua viva — ali o trânsito é parte do custo.

### Fase 5 — Pós, céu e decalques · M · **FEITA em 16/09/2026**

- Tonemap AgX, **exposição automática** (`CameraAttributesPractical`), glow
  recalibrado, sujeira de lente.
- **Desfoque de movimento** ao dirigir: o Godot 4 não tem nativo; vai como
  `CompositorEffect` usando os vetores de movimento que o TAA já produz.
- **Profundidade de campo** só em cutscene e modo foto.
- **Céu**: nuvens volumétricas no `psx_nuvens` do MODERNO, e o relâmpago
  acendendo as nuvens.
- **Decalques** (`Decal`) de poça, óleo, pichação e sujeira, sorteados por
  chunk e ligados ao molhado do `Clima`.
- **Fecha A15–A17.**

**Resultado medido.** Três réguas novas — `tests/bancada_lente.gd` (A15),
`tests/bancada_ceu.gd` (A16) e o censo `--rota-decalques` (A17) — e a
regressão visual nos dois presets.

| Critério | Medido | Pedido |
|---|---|---|
| **A15a** quarto escuro fica legível | mediana 26 → **51**/255 (**1,95×**) | ≥ 1,6× |
| **A15b** sair para a rua assenta | **1,02 s** (antes: 0 s, corte seco) | 0,25 a 2 s |
| **A15c** obturador só dirigindo | força **0** a 3 m/s, **0,5** a 16 m/s; energia de borda **2,88×** menor | 0 a pé; ≥ 2× |
| **A15d** foco raso só quando pedido | nasce desligado; ligado, fundo **4,14×** mais macio | — |
| **A16a** nuvem com volume | topo/barriga **2,03** (billboard: 0,94) | ≥ 1,3 |
| **A16b** relâmpago acende a nuvem | à noite 0,006 → **0,130** (**20,7×**); o raio real escreve pico 1,0 e volta a 0 | ≥ 1,5× |
| **A17** decalques na rua molhada | óleo, pichação, encardido e poça presentes; **no máximo 7 por chunk** | ≤ 12 |
| **A2** regressão | PS1 intacto; MODERNO regravado e estável | — |

**O que ficou.** A `Lente` (autoload, `src/render/lente.gd`) é dona de
exposição, obturador e foco — as três respondem à mesma pergunta física, quanto
de luz entrou. O `DiretorCeu` (autoload `Ceu`) monta nuvens e temporal só no
MODERNO. O `DecalquesRua` segue o jogador como as poças, com duas vagas por
família em cada chunk, sorteadas por hash. As texturas de decalque e a sujeira de
lente saem de `tools/gerar_decalques.py`, em disco — a sujeira em `.hdr`, porque
a poeira precisa passar de 1,0.

**Custo em 4K** (RX 9070 XT, tempo de GPU, mediana da rota noturna, três pares
seguidos): **5,24 → 5,38 ms** com a fase inteira; o obturador no pior caso
(rastro fixo na tela toda) soma **+0,24 ms**. O quadro fica acima de 110 fps em
todo par — o tempo de quadro sai quantizado em 8,3 e 9,1 ms por um limitador de
apresentação, e por isso a comparação é pela GPU.

**Seis coisas que a medida corrigiu:**

1. **O piso de sensibilidade é quem limita cena escura.** No Godot, a
   sensibilidade *mínima* é o piso da luminância média — o contrário da
   intuição. Com piso 40 a avenida noturna foi de 7 para 31 de mediana; baixar
   o teto não mudou nada. O piso agora é do lugar (interior 100, dia 100, noite
   170), calibrado contra as fotos da Fase 4:

   | Noite | avenida | viela | praça |
   |---|---|---|---|
   | Fase 4 (sem exposição, fílmico) | 7/42 | 1/17 | 16/112 |
   | Fase 5 | **8/49** | **2/23** | **19/124** |

   O apartamento acende mais (94 → 146 de mediana): é o olho adaptado ao
   cômodo, e o preço de o quarto escuro abrir 1,95×.
2. **O buffer de velocidade não foi usado.** O rastro sai da profundidade e de
   uma matriz de reprojeção montada pela `Lente` a partir da `Camera3D`,
   conferida contra `unproject_position` (poste a 5 m andando 0,267 m por
   quadro: 29,6 px na conta, 30,2 px pintados pelo shader). Vale em todo
   degrau, inclusive o CRU sem TAA. O peso das amostras é **igual** — um
   obturador soma a luz por igual —, e o deslocamento por ruído que anda
   (o TAA funde) tira as nove cópias duras do poste.
3. **O MODERNO cortava a cor em 32 níveis sem dither.** O corte de 15 bits e o
   pontilhado são uma coisa só no PS1; sem o pontilhado, sobrava faixa — e
   colorida, porque cada canal vira de nível num ponto diferente. O corte agora
   anda junto com o dither; no MODERNO são 256 níveis.
4. **Nuvem é céu.** A névoa de profundidade termina em 60 m (noite) e 130 m
   (dia), e a camada está a 70 m: toda nuvem saía 100% névoa. O shader desliga
   a névoa e aplica a própria bruma, pela altura no céu e pela densidade do
   clima. A massa é achatada (estratocúmulo, não bola), com a borda roída pelo
   ruído, e à noite a barriga é **laranja de sódio** — a luz da cidade. A cor
   ambiente do preset, esverdeada à noite, tinha feito discos verdes.
5. **O clarão tinha a cor da lua.** Somado sobre a luz do "sol", à noite (lua
   de energia 0,06) o raio acendia a nuvem vinte vezes menos que de dia.
   Agora tem cor própria.
6. **A regressão precisou de três esperas novas.** A exposição anda por
   segundo e a rota espera por quadro: a rota agora mede a imagem até o brilho
   parar de mudar. A praça força o clima *depois* do salto, e a sonda de
   reflexo assava o céu errado: as sondas se refazem de novo com a cena parada
   (piso de ruído da praça: 3,5/10,4% → **1,0/3,0%**). E a janela da rota
   engole toda entrada — duas execuções fotografaram o inventário aberto por
   teclas digitadas na máquina.

**Pendente:** `src/world/relampago.gd` nasceu na frente da Estrada Velha e não
está no HEAD. O `DiretorCeu` o carrega por caminho e, sem ele, a cidade só fica
sem temporal; as três ligações desta fase dentro dele (o uniforme global
`psx_relampago`, o grupo e `clarao()`) esperam o commit daquela frente.

### Fase 6 — Chuva fora do carro · M · **FEITA em 17/09/2026**

- **Respingo na lataria**: camada no shader da `Carroceria` que já recebe
  `psx_chuva` (anéis de impacto, como o chão).
- **Goteira** na borda de marquise e toldo (o `ChunkBuilder` sabe onde estão).
- **Roupa molhada** no shader do `Corpo`, pelo mesmo `psx_molhado`.
- **Gota na lente** em terceira pessoa: aqui a placa presa à câmera é o certo
  — é chuva batendo na LENTE —, com o shader do vidro e cobertura por
  exposição ao céu (sem marquise em cima).
- **Poça viva**: rastro de pneu, jato d'água ao atravessar (o `SprayEstrada`
  existe na estrada), faixa de farol no asfalto molhado.
- **Fecha A18, A19.**

**Resultado medido.** Uma bancada nova (`tests/bancada_chuva_fora.gd`, seis
medidas) e a rota `goteiras` na cidade.

| Critério | Medido | Pedido |
|---|---|---|
| **A18a** gota na lataria em 1 s | energia de alta frequência no capô **1,60×** (chuva em 0,28, que é a rampa real do `Clima` a 1 s) | ≥ 1,5× |
| **A18b** goteira na borda de toldo | **601 pontos** de pingo nos 9 chunks em volta; na vitrine acesa, **+0,20%** da faixa (0,52% medido contra 0,32% de piso de ruído) | existir, e no lugar certo |
| **A18c** roupa encharca | 30 s de chuva cheia deixam a silhueta **27% mais escura** na tela | ≥ 20% |
| **A18d** gota na lente só sem cobertura | céu aberto: **9 gotas**, 0,33% da tela; sob telhado por 5 s: **0 gotas**, 0,016% (ruído descontado) | gota fora, nenhuma dentro |
| **A19a** rastro na poça | dentro da trilha o reflexo do poste cai para **54%** e volta a **100%** em 3,5 s | ≤ 75%, e volta |
| **A19b** jato d'água da roda | **0,83%** da tela a 12 m/s constante e **0,77%** acelerando | existir nos dois |
| **A19c** farol risca o asfalto molhado | risco abaixo do farol: **80 px** seco, **278 px** molhado (**3,5×**) | ≥ 2× |
| **A2** regressão | PS1 intacto; MODERNO dentro da tolerância | — |

**Custo** (RX 9070 XT, rota noturna, três pares, mediana do tempo de GPU):
**1,49 → 1,58 ms**, ou seja **+0,08 ms** com a fase inteira. A medida saiu em
3840x1055 e não em 3840x2108 como na Fase 5: a tela desta máquina hoje não
aceita janela mais alta, e o par com/sem foi tirado na mesma resolução.

**O que ficou.** Um autoload `ChuvaFora` (`DiretorChuvaFora`), pelo mesmo motivo
do `DiretorCeu`: `ChunkManager`, `Player` e `Corpo` têm trabalho não commitado
de outras frentes, e daqui tudo se monta por fora. Ele cuida da `GotasLente`, da
`Goteiras` por chunk, do `RastroMolhado` por carro e do encharcamento da roupa
do jogador. `--sem-chuva-fora` desliga tudo, e é o par de toda medida.

**Cinco coisas que a medida corrigiu:**

1. **O jato d'água da roda quase não existia em movimento.** O `SprayRoda`
   escrevia `amount` a cada quadro de física para dosar o leque pela
   velocidade, e trocar `amount` **realoca o sistema de partículas e recomeça
   todas elas**. Com velocidade constante o número não mudava e o leque
   aparecia; acelerando, ele renascia sessenta vezes por segundo. Medido:
   2,32% da tela a velocidade constante contra **0,15%** acelerando. A dosagem
   agora é `amount_ratio`, que não reinicia nada: 0,77% acelerando.
2. **Toldo e marquise não têm colisão**, então raio nenhum os acha, e ler a
   malha de volta da GPU trava o quadro. A goteira sai de refazer o chunk pelo
   `ChunkBuilder.construir` (determinístico, fora da thread principal) e ler as
   faces viradas para baixo. Só os 3x3 chunks em volta da câmera, de 0,3 a
   52 ms por chunk, em thread de trabalho.
3. **A primeira análise pingava em volta de cada árvore.** Copa também é face
   virada para baixo: 2339 pontos nos mesmos 9 chunks, a maioria em árvore.
   Folhagem saiu da conta (árvore pinga por baixo da copa inteira, não na
   borda) e sobraram 601.
4. **O rastro do pneu saía MAIS CLARO que a rua.** Com cor própria no decalque
   ele virava faixa pintada; e com rugosidade 0,72 o poste ainda acendia o
   rastro inteiro, porque rente ao chão a GGX larga devolve muito. Sem cor
   nenhuma e com o miolo quase fosco, o rastro é o que devia ser: um caminho
   aberto na água, onde o reflexo some.
5. **`mat_npc` estava fora da tabela de molhabilidade** e caía no padrão do
   shader, 0,12 — o número da poça. Ombro e alto da cabeça viravam lâmina de
   água na chuva. Ver a Fase 11: ele não era o único.

### Fase 11 — Fachada, janela e vidro · G · **A34, A35 e A36 FEITOS em 17/09/2026**

Pedido do usuário, com o defeito já medido: *"prédios em vielas que parecem
feitos de metal, material bugado, e falta de detalhamento para parecer interior
de Minas Gerais; o vidro das casas não parece vidro de casa"*.

**O que a medida achou.** O conjunto HD do MODERNO é escolhido pelo nome do
ARQUIVO de textura (Fase 3), e três materiais de fachada apontam para o arquivo
errado:

| Material | Textura que ele usa | O que aparece no MODERNO |
|---|---|---|
| `mat_janela_apagada` | `metal` | chapa de metal suja (Metal046B) na janela |
| `mat_janela_acesa` | `calcada_ladrilho` | **piso de calçada** dentro da janela acesa |
| `mat_vitrine` | `azulejo_fachada` | azulejo de parede na vitrine da loja |
| `mat_teto` | `reboco` | telhado de reboco — não existe telha no catálogo |

E a molhabilidade repete o defeito do `mat_npc`: `reboco`, `tijolo`, `teto`,
`janela_acesa`, `janela_apagada`, `porta`, `toldo`, `casa` e `vitrine` estão
**fora da tabela** da `EstiloVisual` e caem no padrão 0,12, que é o número da
lâmina de água parada. Toda superfície dessas voltada para cima vira espelho
na chuva.

Mais: a viela é parede de `metal_ondulado` (CorrugatedSteel009) de alto a
baixo, e a casa inteira (`mat_casa`, `casa_atlas`) não tem conjunto HD nenhum —
em 4K ela continua com o atlas de 256 px.

**O que a fase faz.**

- **Vidro de verdade**: material e shader próprios de janela — transparência,
  reflexo do céu, esquadria, e o que se vê atrás (cortina, cômodo escuro,
  lâmpada). Janela acesa e apagada saem do mesmo material, mudando a emissão.
- **Cada fachada com a sua textura**: conjunto HD próprio para reboco pintado,
  tijolo à vista, telha cerâmica (nova), madeira de porta e portão de enrolar.
- **Tabela de molhabilidade completa**: nenhuma superfície de rua fora dela, e
  um teste que falha quando alguém acrescenta material sem linha na tabela.
- **Detalhe de cidade do interior de Minas**: telhado de telha com beiral e
  calha, muro caiado com barrado, janela de madeira com bandeira de vidro,
  fiação e medidor na fachada, número da casa, azulejo na barra da loja. A
  viela deixa de ser corredor de galpão.
- **Fecha A34–A37.**

**Resultado medido (A34 e A35).** Bancada nova, `tests/bancada_fachada.gd`:

| Critério | Medido | Pedido |
|---|---|---|
| **A34a** a janela tem fundo | com a câmera andando 70 cm de lado, o desenho **anda 7 px dentro do vidro em relação à própria esquadria** (o vidro anda 12 px, a esquadria 5) | ≥ 3 px |
| **A34b** a janela reflete o que está em volta | do frontal para a rasante o vidro **ganha 1,39×** de luminância (0,269 → 0,374) enquanto o reboco ao lado **perde** (0,88×) | ganho ≥ 1,3× o da parede |
| **A34c** a janela tem esquadria | caixilho e montante ocupam **42%** do vão | entre 8% e 50% |
| **A35** tabela de molhabilidade completa | **0 materiais** de superfície fora da tabela (eram 9 de fachada, mais o `mat_npc` da Fase 6) | zero |
| **A2** regressão | **PS1 intacto** (1,2 a 1,9/255, o mesmo de antes); MODERNO regravado e estável (≤ 0,81/255) | — |

**O que ficou.** `shaders/psx_janela.gdshader` é a janela do MODERNO: vidro
(rugosidade 0,06 mais Fresnel, que é o que traz o céu e o poste de graça),
esquadria com caixilho e montante, e o **cômodo atrás** por caixa virtual em
espaço de mundo — uma sala por vão de 3,2 m e por andar de 3,0 m, com chão,
teto, lâmpada, cortina sorteada e um móvel no fundo. Duas janelas do mesmo
andar olham para dentro da MESMA sala, de ângulos diferentes, que é o que
sustenta a ilusão com o jogador andando na calçada. No PS1 STYLE o material
volta para `psx_surface` com a textura de sempre.

A esquadria precisou de uma coordenada que não existia: a UV do jogo é ancorada
em **metros** (é ela que faz tijolo do mesmo tamanho em parede de qualquer
largura) e não sabe dizer "onde nesta janela". O `PSXMesh` passou a emitir uma
**segunda UV, de 0 a 1 dentro da peça**, que o PS1 ignora — e o shader deduz o
tamanho real da peça pela razão entre as derivadas das duas, o que dispensa um
uniforme por janela (são milhares, com um material só).

**Duas coisas que a medida corrigiu:**

1. **Cômodo apagado claro demais.** Com a sala apagada em cinza médio, o
   Fresnel não tinha contra o que aparecer e o vidro lia como chapa: rasante
   sobre frontal dava 1,1×. Um cômodo sem luz visto da rua é quase preto (a
   transmissão caiu para 26%), e aí o reflexo aparece.
2. **A primeira referência gravada não valia.** A gravação logo após a mudança
   saiu com o interior 5,3/255 fora das duas execuções seguintes, que
   concordavam entre si — motor frio. Regravada com o motor quente, a
   regressão fecha em 0,63/255 no mesmo ponto. (Ver a memória "primeira
   execucao nao vale captura".)

**Resultado medido (A36).** A decisão de direção de arte foi tomada pelo
usuário em 17/09/2026: **alvenaria em cima, aço no térreo**.

| Critério | Medido | Pedido |
|---|---|---|
| **A36** a rua do interior | chapa ondulada cai de **16,2% para 0,8%** da área de parede do distrito industrial; o residencial ganha **4.634 m²** de telha, **31%** da parede | ≤ 5%, e telha existindo |
| **A2** regressão | referências dos **dois** presets regravadas, e estáveis na conferência (PS1 ≤ 1,6/255, MODERNO ≤ 1,3/255) | — |

O denominador é a **parede**, e não o chunk: com chão, asfalto e árvore na
conta, a chapa já era 4% antes da mudança e o número não dizia nada sobre o que
o olho vê na viela.

**O que mudou no mundo.**

- A paleta do distrito INDUSTRIAL passou de `metal_ondulado`,
  `metal_enferrujado`, `concreto_sujo` para `concreto_sujo`, `tijolo`,
  `reboco`. O térreo continua de porta de aço: é a `KitModular.fachada` que
  escolhe `metal_ondulado` para o vão quando a massa é de concreto sujo — que
  é o galpão de rua brasileira, alvenaria com portão de aço, e não um contêiner.
- **`KitPredio.telhado`**: duas águas com telha cerâmica, cumeeira e beiral de
  meio metro, como remate das quadras residenciais (duas das quatro entradas do
  sorteio). É o beiral, visto de baixo, que dá a linha horizontal que o olho lê
  como casa em vez de caixa. Duas águas e não quatro: a empena fica na divisa
  com o vizinho, onde a rua não a vê.
- **`tools/gerar_fachada_hd.py`** desenha telha, porta e toldo em 1024 px (cor,
  relevo e rugosidade), mais a telha em 256 px para o PS1. O ambientCG tem
  concreto e tijolo ótimos e não tem telha colonial, porta de casa de rua nem
  lona de toldo de padaria.
- **`mat_telha` é material novo**: `mat_teto` também forra o INTERIOR dos
  cômodos, e telha no forro da sala seria pior que laje na rua.

**Este foi o primeiro item do plano a mudar o PS1 de propósito.** As
referências dos dois presets foram regravadas; o contrato A2 continua valendo
para toda mudança de renderizador, que é para o que ele existe.

**Detalhe de fachada (parte do A36).** Pingadeira de 7 cm na altura de cada
laje e medidor de luz com conduíte descendo, na `KitModular.fachada`. A
pingadeira existe na rua de verdade porque é ela que impede a água de escorrer
pela parede inteira, e de quebra é ela que quebra o paredão: uma sombra
horizontal a cada três metros. **Custo: +6.512 triângulos nos 25 chunks
carregados (75.394 → 81.906, +8,6%)**, e nenhuma chamada de desenho nova — são
os materiais que a fachada já usava.

**O que ficou de fora, e por quê (A37).** O critério A37 pedia a casa em 4K
porque `casa_atlas` é o único conjunto de 256 px sem versão HD. Medido: esse
atlas veste **interior e prop** (`casa_fumaca_builder`, cigarro, tela de
celular, estufa), e não fachada de rua — nenhuma parede de quadra usa ele. Em
4K, quem aparece de perto na calçada são reboco, tijolo, telha, porta, janela e
portão de aço, e esses seis já têm conjunto próprio. **A37 fica adiado** até a
frente da Casa da Fumaça encostar nele, que é de quem aquele atlas é.

### Fase 7 — Carro AAA completo · G · **A20, A22 (seta e teto) e A24 FEITOS em 17/09/2026**

- **Amassado**: mapa de deslocamento por carro, escrito no ponto e na força da
  batida (`Carro.bateu` já entrega a força), aplicado no vértice da lataria;
  a cabine continua contida (A20 reusa a sonda de contenção).
- **Sujeira e lama** por carro, acumulando com distância em terra e lavando na
  chuva.
- **Luzes**: seta para o jogador, luz de cabine, lente de farol com refletor.
- **Cabine interativa**: ponteiro de giro, câmbio, pedais e rádio com
  mostrador, montados pela `CabineDoJogador`.
- **Olhar livre ao volante** pela `CabineDoJogador` e pelo sinal do jogador
  (o `CameraRig` tem WIP alheio; a ligação lá é mínima).
- **Mãos no volante**: mãos presas ao pivô do volante, a direita indo ao câmbio
  na troca de marcha; medidas pela ponta dos dedos (memória "animação se mede
  pela ponta").
- **Fecha A20–A25.**

**Por onde a fase entrou.** A frente do carro está com outra sessão (painel,
pilotagem, visibilidade da cabine — `painel_carro.gd`, `teste_carro.gd`,
`medir_cabine.gd`, todos novos e não versionados). Amassado e luzes não aparecem
em plano nenhum e vivem em arquivos que estavam limpos (`carro.gd`,
`cabine_do_jogador.gd`), então a fase começou por eles.

**Resultado medido (A20).** `src/render/amassado.gd` e
`tests/bancada_batida.gd`, que bate um sedan num muro, de frente e de lado,
fora da cidade. **8 de 8.**

| Critério | Medido |
|---|---|
| batida forte | a 15 m/s contra o muro, força **1,00** |
| a frente entrou | **13,2 cm** (pedido: 3) |
| só a frente | a traseira andou **0,00 cm** |
| custo | o quadro principal paga **0,1 ms**; o amassado chega **36 ms** depois da pancada |
| batida de lado | a 11 m/s, força 0,83, a porta entra **12,3 cm** |
| cabine contida | de 151 raios do olho do motorista para o amassado, a lataria aparece na frente do forro em **9 antes e 7 depois** |
| cabine remontada | descer e subir de novo devolve a cabine a **0,00 mm** da amassada |
| a sonda enxerga | amassando **só a lataria**, ela aparece na frente do forro em **78 raios** — o controle que prova que a régua não é cega |

**Como funciona.** A batida vira um campo de deslocamento — ponto, direção para
dentro, raio e profundidade —, com queda suave e uma ruga que depende do lugar.
O lado sai da velocidade **perdida** (quem parou de golpe andando para a frente
bateu com a frente), a altura é a do para-choque. A cabine amassa **junto** com
a lataria, pelo mesmo campo medido no plano da chapa, e as batidas ficam
guardadas para a cabine remontada nascer amassada.

**Quatro coisas que a medida corrigiu:**

1. **A grade e a placa sumiam.** A frente do sedan é um quadro grande com
   vértice só nas quinas: as quinas quase não andam, a grade anda 13 cm e some
   atrás de uma chapa que continuou reta. A malha agora é **dividida** onde o
   amassado encosta (1→4, com fechamento por posição para não abrir fenda em
   T), e vértice novo vai para o fim do array, para quem guardou "o vértice 40"
   continuar achando ele.
2. **508 ms no quadro da batida.** A primeira divisão usava o centro do
   triângulo mais o raio dele, e triângulo grande encostava em tudo: a frente
   foi de 598 para 10.423 triângulos. Com a distância exata ao triângulo, e a
   conta numa thread sobre arrays lidos **uma vez** ao assumir o carro (ler
   malha de volta do servidor trava o quadro — memória da Fase 6), o quadro
   principal só sobe a malha pronta.
3. **A primeira régua da cabine media a coisa errada.** Ela comparava cada ponto
   do forro com o ponto de chapa mais perto, a até 15 cm, e acusou 4,7 cm de
   chapa atravessando — era o gradiente do amassado entre dois pontos distantes.
   A régua nova é por **raio**, do olho do motorista, e vem com controle
   positivo: amassando só a lataria ela acusa 78 raios; amassando as duas, 7.
4. **As luzes boiavam.** `_aplicar_atlas_lanternas` remonta a malha de luzes a
   cada troca de célula a partir de um cache do nascimento, e desfazia o
   amassado na primeira pisada no freio. O amassado das luzes entra direto nesse
   cache.

**Resultado medido (A22, seta e luz de teto).** `tests/bancada_luzes_carro.gd`.
**6 de 6.**

| Critério | Medido |
|---|---|
| seta do jogador | a tecla (Z e X) liga a seta, e a lâmpada apaga 6 vezes em 4 s: **1,50 Hz** |
| pisca da frente | aceso **3,3×** mais que apagado; o outro lado fica apagado |
| desliga na tecla | a segunda pressão apaga |
| desligamento automático | **não** apaga numa troca de faixa; apaga depois de uma curva de verdade, com o volante de volta ao centro |
| luz de teto acende | **0,90** meio segundo depois de entrar |
| luz de teto apaga | **0,00** sete segundos depois |

Até aqui só o carro da IA piscava — `_atualizar_pisca` mora dentro de
`_dirigir_ia` — e a seta dele piscava a **2,27 Hz**, fora dos 60 a 120 por minuto
que a norma de instalação de iluminação (ONU R48) pede: rápido o bastante para
ler como lâmpada queimada. O período passou para 0,667 s, e isso vale para o
trânsito também. O pisca da frente, que ficava aceso sempre, agora é brasa de
lanterna quando parado e âmbar cheio quando pisca, como no Fusca, no Opala e no
Chevette, em que a mesma lente era lanterna e seta.

**O que falta nesta fase, e por quê.**

- **A21 (sujeira e lama).** Pede saber onde é terra, e a estrada — que é onde
  há terra — está com a outra sessão (`estrada_builder.gd`, `mat_leito.tres`,
  `fog_estrada*.tres` modificados).
- **A22c (lente do farol com refletor).** Pede desenho novo na célula de farol
  do `carro_atlas`, que é a mesma folha do PS1: é mudança de direção de arte,
  como foi a da viela, e fica para quando houver conjunto HD próprio de carro.
- **A23 (cabine interativa) e A25 (mãos no volante).** A cabine interativa
  passa pelo painel de dentro, e as mãos pelo `corpo.gd`, que continua com
  trabalho não versionado de outra sessão.

**Resultado medido (A24, olhar livre), pedido pelo jogador.** "Dentro do carro
devemos conseguir olhar para os lados com o mouse, e com a câmera de fora a
mesma coisa." `tests/bancada_olhar.tscn` (com `-- --teste-olhar`). **8 de 8.**

| Critério | Medido |
|---|---|
| limites de dentro | **115°** para cada lado e **60°** para cima e para baixo (pedido: 100° e 60°) |
| volta inteira por fora | o mouse pede 270° e a câmera anda **270,0°** |
| volta ao centro | andando, o olhar fica **1,25 s** onde o jogador deixou e chega na frente **0,60 s** depois (pedido: até 0,8 s) |
| parado não volta | cinco segundos parado, o olhar continua em **82,5°** |
| o mouse gira a câmera de fora | a câmera em uso fica a **80,7°** do carro (pedido 80); o controle — girar o corpo, que era o caminho antigo — some em meio segundo e sobra **−0,6°** |
| o mouse gira a cabeça de dentro | câmera da cabine em uso, **60,0°** para a esquerda e **26,6°** para cima (pedido 30, com os 3,4° que o pivô já inclina para baixo) |
| volta andando, na câmera | o carro anda e a câmera volta para trás dele **0,58 s** depois de a espera acabar |
| descer zera | o braço estava girado 1,14 rad e fica em **0,000** ao descer |

**O defeito era de ordem, e não de falta.** O mouse sempre girou alguma coisa
dentro do carro: o CORPO do jogador, como a pé. Só que `Player._ao_volante`
puxa o corpo para o rumo do carro nove vezes por segundo, e o giro sumia em um
décimo de segundo — por fora e por dentro. Agora os dois ângulos moram em
`OlharAoVolante` (classe pura), o braço da câmera gira em volta da cabeça
(`CameraRig.orbitar`) e a câmera da cabine gira entre o rumo do corpo e a
inclinação do pivô. A volta ao centro tem duração fixa, e não ritmo: com ritmo
exponencial não haveria número para "volta em até 0,8 s".

**A primeira rodada mediu a mão de alguém.** Sem um `--teste-*`, o `Player`
prende o ponteiro ao nascer, e o mouse de quem estava usando a máquina girou a
câmera no meio da medida — a câmera saiu 37° torta com o carro parado. A
bancada agora reprova sem a flag, e só prende o ponteiro no instante de
entregar cada evento.

**Painel do carro, pedido pelo jogador.** "O HUD de marcha e velocidade precisa
ser mais bonito e estar melhor posicionado." Era uma caixa de 112×52 com um
relógio de 40 px, solta à direita do meio da tela e encostada no prompt de
teclas. Virou um mostrador redondo no canto de baixo da direita, na coluna do
minimapa: arco de 24 segmentos para a rotação (osso, âmbar na faixa de troca,
vermelho no corte), velocidade grande no meio, marcha numa caixa que acende na
hora de trocar, setas, farol e freio de mão. A geometria é pura
(`PainelLayout`) e a posição sai da vinheta do estilo: no MODERNO (0,18) o
mostrador encosta na margem; no PS1 STYLE (0,45) ele anda na diagonal até todo
texto passar do piso de vinheta. `tests/bancada_painel.tscn`. **7 de 7 nos dois
estilos.**

| Critério | MODERNO | PS1 STYLE |
|---|---|---|
| lugar | centro (439, 229), borda direita na do minimapa; pior texto **0,63** | centro (412, 214), recuado pela vinheta; pior texto **0,46** (piso 0,45) |
| o arco conta a rotação, lido na foto | giro 0,45: **11** de 24 segmentos claros, o primeiro escuro é o 11 | o mesmo |
| a troca se vê | segmento âmbar, borda da marcha acesa na troca e apagada em cruzeiro | o mesmo |
| seta | flecha esquerda verde, direita apagada | o mesmo |
| freio de mão | lâmpada vermelha puxado, apagada solto | o mesmo |
| motor desligado | **0** segmentos claros com giro pedido | o mesmo |
| o texto cabe no arco | sobra 0,7 px na palavra mais larga e 13,3 px no número de três algarismos | o mesmo |

Três coisas que a foto corrigiu: com 1° de vão os segmentos viravam barra
contínua (agora 2,4°); "CAPOTOU" não cabia dentro do arco e encostava nos
segmentos (virou "VIROU", e a bancada mede a corda); com 30 segmentos os blocos
do PS1 tinham 4 px e rasterizavam como riscos tortos (agora 24).

**Defeito achado no caminho: tomar um carro podia arremessá-lo.** Quem estava ao
volante desce e vira pedestre, e o corpo dele era posto na árvore antes de
receber posição — nascia na origem do pai. Com o carro em cima dessa origem, a
física resolvia a sobreposição arremessando o carro que o jogador acabava de
tomar: **63 a 69 m/s de lado, batida de força 1, motor afogado e lataria
amassada**. Agora a posição vem antes. `bancada_batida.gd` ganhou dois casos
(encostado num muro e na origem), **10 de 10**; o controle — pôr a ordem antiga
de volta — reprova o caso da origem. No jogo isso é raro (o trânsito vive num nó
na origem do mundo, e a cidade jogável fica a mais de 60 m dali); as duas
paradas de motor nas capturas desta rodada eram batidas de verdade da rotina de
captura, que acelera às cegas.

**Um defeito que já estava lá e não é desta fase.** O
`tests/checar_cabine_contida.gd` reprova no HEAD, com os mesmos números antes e
depois deste trabalho: 4 modelos com alguns vértices do interior até 5,1 cm
além da chapa (folga de 2 cm). Conferido num worktree limpo. É da frente da
cabine, que a outra sessão está medindo agora.

### Fase 8 — Personagens e animação · G

- **Corpo MODERNO**: o mesmo esqueleto de 11 ossos, com malha suave e pesos
  distribuídos (sem a fresta de ombro do PS1), gerada pelo mesmo `Corpo`; o PS1
  continua com as caixas rígidas.
- **Animação interpolada** a 30/60 fps no MODERNO; o PS1 mantém 15 poses em
  degrau.
- **IK de pé** em escada e rampa e **olhar** dos NPCs (modificadores de
  esqueleto do Godot 4.7).
- Roupa que molha entra junto com a Fase 6.
- Orçamento: chamadas por pessoa continuam 1; triângulos por pessoa definidos
  no ART-BIBLE MODERNO.
- **Fecha A26.**

### Fase 9 — Áudio espacial · M · **A27 FEITO em 17/09/2026**

- **Eco por ambiente**: buses com reverb (rua, rua estreita, túnel, sala,
  carro), escolhidos por zona (`Interiores` já sabe onde o jogador está; rua
  estreita por raio).
- **Oclusão**: passa-baixa por raio entre fonte e ouvinte.
- **Chuva por superfície**: lata, teto de carro (a cabine já abafa a chuva),
  guarda-chuva, marquise.
- **Doppler** nos carros e pneu cantando no molhado.
- **Fecha A27.**

**Resultado medido (A27).** Bancada nova, `tests/bancada_audio.gd`, que grava a
saída com um `AudioEffectCapture` no Master e mede a onda — energia, queda e
frequência por cruzamento de zero. Nenhuma medida depende de alguém achar que
ouviu diferença. **3 de 3.**

| Critério | Antes | Depois |
|---|---|---|
| **A27a** eco por ambiente | **−25,9 dB de cauda em todo lugar do mundo** | rua **−36,1**, viela **−26,4**, túnel **−14,2**, sala **−25,9**, carro **−39,2** |
| **A27b** oclusão | não existia | **−7 dB** pedidos, **−5,1 dB** medidos na saída, e o agudo cai de 0,07 para **0,01** |
| **A27c** doppler | não existia | vindo **449 Hz**, indo **381 Hz** (18%) |

**O defeito era de nascença e estava no arquivo de buses.** O
`default_bus_layout.tres` tem **um** reverb, de sala, ligado desde sempre: o
passo na avenida aberta tinha a mesma cauda que o passo dentro de um quarto de
dois por três. O ouvido aceita muita coisa, menos isso — eco é a única pista que
uma pessoa tem, de olhos fechados, do **tamanho** do lugar onde está.

`src/systems/eco_ambiente.gd` (autoload `Eco`) reescreve os cinco números do
mesmo reverb, com rampa de meio segundo, conforme o lugar: dentro do carro vence
tudo, interior vence rua, e a geometria decide entre avenida, viela e túnel por
três raios (esquerda, direita, teto). Na rota de captura ele se comporta sozinho:

```
[eco] rua -> rua_estreita    (na viela)
[eco] rua_estreita -> rua    (saindo dela)
[eco] rua -> sala            (entrando no interior)
```

**Duas armadilhas do motor, as duas medidas:**

1. **O filtro do próprio tocador não faz efeito.** `AudioStreamPlayer3D` tem
   `attenuation_filter_cutoff_hz`, que seria o caminho óbvio para abafar o som
   atrás da parede: baixar o corte de 20 kHz para 500 Hz mudou a energia de
   **0,2891 para 0,2875**, ou seja nada. A oclusão passou a ser um **bus** com
   `AudioEffectLowPassFilter`, que envia para o `SFX` — assim o volume de
   efeitos do jogador continua valendo e o som abafado também ecoa no ambiente
   de quem ouve.
2. **`AudioStreamGenerator` sai mudo dentro de um tocador 3D** (pico 0,000001
   contra 0,41 do mesmo som em WAV), e som 3D **sem câmera corrente** sai dez
   vezes mais baixo. As duas coisas custaram meia dúzia de execuções em que a
   medida dizia zero com o som ali.

**Por que o corte de agudo importa mais que o volume.** Som atrás de parede é
som **de outro lugar**, e o que diz isso ao ouvido não é o volume: é a falta de
agudo — é a razão de só se ouvir o baixo da festa do vizinho. Baixar o volume
sem cortar o agudo produz outra coisa: uma fonte *longe*, nítida e fraca.

**O que ficou de fora, e por quê.** A camada de chuva por superfície (lata,
teto de carro por dentro, marquise) é da frente do carro e da estrada, que está
com outra sessão neste momento — `chuva_cabine_loop.wav`, `medir_chuva_cabine`
e o `teto_chuva` são de lá. Entrar nesses arquivos agora seria pegar trabalho
alheio no meio.

### Fase 10 — UI 4K, modo foto e cutscenes · M · **FEITA em 17/09/2026**

- **Fontes**: `tools/gerar_fonte.py` passa a gerar a fonte **MSDF** (ou o
  bitmap em múltiplos inteiros por resolução) para o MODERNO; o PS1 mantém o
  bitmap de hoje. Ícones em 4×.
- **Modo foto**: cena própria com câmera livre, profundidade de campo,
  exposição, filtros, HUD escondido e PNG em 3840×2160.
- **Cutscenes**: letterbox, profundidade de campo por plano, desfoque de
  movimento, ritmo de legenda (a `Cinema` já existe).
- **Fecha A28–A30.**

**Resultado medido (A28).** Bancada nova, `tests/bancada_fonte.gd`: a MESMA
haste dez vezes (dez letras I), fotografada em cada multiplicador que a janela
produz, e três números por haste — pico de tinta, pixels de meio-tom e largura
analógica.

| Fonte | Antes (bitmap), pico / meio-tom | Depois (vetorial), pico / meio-tom |
|---|---|---|
| `psx_pequena` (HUD) em 1080p | **0,87** / 4 px | **1,00** / 2 px |
| `psx_pequena` em 4K (8×) | 0,94 / **12 px** | 1,00 / **1 px** |
| `psx_media` em 4K | 1,00 / 12 px | 1,00 / 2 px |
| `psx_titulo` em 4K | 1,00 / 12 px | 1,00 / 1 px |
| `psx_mono` em 1080p | 0,87 / 4 px | 1,00 / 1 px |

E a métrica não se moveu: **0,00 px** de diferença de largura em todas as 10
frases de HUD, nas 4 fontes, com a mesma altura de linha. 8 de 8 critérios.

**O defeito era pior do que estava escrito.** O `estilo_visual.gd` já avisava
que escala quebrada deixa "hastes de larguras diferentes". A medida mostrou
outra coisa: o atlas da fonte é **magnificado com filtro linear**, então no
MODERNO o texto não tem **um** pixel com a cor do texto em escala nenhuma —
nem nas inteiras. Em 1080p uma haste de 1 px vira um monte de 8 px com pico
0,87; em 4K, 12 px de meio-tom. Em 480×270 nada disso aparece, porque lá a
escala é 1 — e foi por isso que atravessou o projeto inteiro sem ser visto.

**O que ficou.** `tools/gerar_fonte_vetor.py` vetoriza o PRÓPRIO bitmap: marcha
de aresta em volta dos pixels acesos, contorno fechado por glifo, e um TrueType
com 64 unidades por pixel. A letra é a mesma, o avanço é o mesmo inteiro, a
altura de linha é a mesma — só que agora o motor resolve a borda na resolução
da tela (MSDF). Usar a Arial dinâmica de novo teria sido mais fácil e teria
movido cada painel do jogo, porque o `gerar_fonte.py` arredonda cada avanço
para inteiro e a Arial não.

Três armadilhas do motor no caminho, todas medidas:

1. **`msdf_size` tem de ser múltiplo do tamanho nativo.** O motor mede o avanço
   no tamanho do campo e reescala; com 128 sobre uma em de 11 px, cada avanço
   volta com 0,016 px a mais e a frase sai 1 px mais larga que no `.fnt`. Com
   132 (12 × 11) a volta é exata.
2. **`take_over_path` não alcança recurso importado**, porque o `load` passa
   pelo caminho remapeado em `.godot/imported`; e `copy_from` erra em `FontFile`
   e trava a renderização seguinte. O que funciona é transplantar o conteúdo
   (`data` + os campos de MSDF) na instância que as vinte telas já seguram — e
   assim o preset troca a fonte sem reiniciar.
3. **Recurso mexido precisa de dono.** Sem uma referência viva no autoload, o
   cache soltava a instância e o `load` seguinte reimportava o `.fnt` do disco:
   o conserto passava no print e não chegava na tela.

**1,5× ficou fora do critério, e por quê.** A escala da UI é a altura da janela
sobre 270, e nenhuma janela tem 405 px de altura. Abaixo de 2× o número é
geometria, não qualidade: uma haste de 1 px vira 1,5 px de tela, e 1,5 px de
tinta não cabem igual em fase par e em fase ímpar por método nenhum (medido:
1,32 e 1,88 px alternados, as duas cristalinas). As escalas medidas passaram a
ser as que a janela produz: 2×, 2,667×, 3,333×, 4×, 5,333× e 8×.

**Resultado medido (A29).** `src/systems/modo_foto.gd` (autoload `Foto`, F10) e
`tests/bancada_foto.gd`, numa cena de duas caixas claras a 4 m e a 14 m contra
fundo escuro. **9 de 9.**

| Critério | Medido |
|---|---|
| **A29a** câmera livre | a câmera da foto assume, o jogo pausa, ela anda e a do jogador fica; o foco automático aponta e acha **3,30 m** (a caixa de 4 m menos meia caixa) |
| **A29b** sem HUD | toda camada do grupo `hud` some ao entrar e volta ao sair |
| **A29c** profundidade de campo | com foco na caixa de perto, a borda da de 14 m fica **2,1× mais mole** (0,781 → 0,378) e a de 4 m guarda **79%** da dureza |
| **A29d** exposição | duas paradas para cima clareiam **1,68×** |
| **A29e** filtro | saturação 0,031 sem filtro, **0,000** no preto e branco, 0,037 no quente |
| **A29f** foto em 4K | PNG de **3840×2160** com a janela em 1280×720 |
| **A29g** brilho da foto | a foto tem **0,97×** o brilho da tela |

**A foto não é um print.** É uma renderização própria, num `SubViewport` de
3840×2160 com o mesmo `World3D` e uma cópia da câmera: sai em 4K mesmo numa
janela de 720p, e sem nenhuma camada de interface, porque SubViewport nenhum tem
canvas do jogo dentro. Sem o pós, de propósito — grão e dither são desenhados na
grade de 480×270 e em 4K viram carimbo de outra resolução em cima da imagem.

**O defeito que a rota mostrou, e que virou critério.** Ligando o modo foto na
rota de captura (`--rota-4k=DIR`, uma foto de 4K por parada), a viela à noite
saiu com **9,7** de brilho médio contra **43,5** da mesma vista na janela, e o
interior saiu com **138**. A janela entregava 42 a 46 nas quatro paradas — que é
a exposição automática dela fazendo o trabalho. **A exposição automática não
roda no viewport da foto**: com ela ligada o brilho ficou cravado no mesmo valor
por 120 quadros; escrevendo os atributos direto na câmera passou a andar 1% a
cada oito quadros; acelerar o olho eletrônico não mudou nada.

O conserto é medir em vez de confiar: a foto lê o brilho da tela, liga a
exposição manual e procura o multiplicador que iguala os dois. Quatro rodadas
bastam, porque exposição é multiplicativa e a primeira correção já chega perto.
Depois: **1,22×, 1,24×, 1,27× e 1,35×** nas quatro paradas — e o que sobra é o
pós-processamento, que tira um quinto do brilho da janela e não existe na foto.

**Resultado medido (A30).** `tests/bancada_cinema.gd`, sobre a `Cinematica` que
já existia. **4 de 4.**

| Critério | Medido |
|---|---|
| **A30a** formato de cinema | a tarja vai de **0 para 33 px** de cada lado, deixando 204 linhas: **2,353:1** |
| **A30b** legenda na área segura | as três frases (7, 44 e 121 caracteres) cabem entre as tarjas e dentro da margem |
| **A30c** tempo de leitura | "Acorda." pede **1,8 s**; a frase de 121 caracteres pede **9,7 s** |
| **A30d** profundidade de campo | no plano marcado, a caixa de 14 m fica **2,0× mais mole** e o sujeito guarda **79%** da borda |

A tarja passou de 30 px para 33. Trinta deixavam 2,29:1, que não é formato de
nada; 33 deixam 204 linhas, e 480/204 dá 2,353 — o CinemaScope de verdade, e o
inteiro mais perto dele que uma grade de 270 px permite.

**Três defeitos que a bancada encontrou na `Cinematica` que já estava lá:**

1. **A legenda de três linhas crescia para baixo, para dentro da tarja.** A
   altura da caixa vinha de `_legenda.size.y`, que ainda era a do texto
   ANTERIOR: a frase longa nascia com a altura de uma linha e vazava 11 px
   sobre a tarja de baixo — comendo a última linha justamente na frase mais
   longa. Agora a altura é calculada do texto que vai entrar, e a caixa cresce
   para cima, com a base fixa acima da tarja.
2. **A legenda era desenhada em 16 px numa fonte desenhada para 18.** Ela usava
   `add_theme_font_override` sozinho, que é exatamente o que o cabeçalho do
   `UiEstilo` manda não fazer: sem `font_size`, o `Label` pede o padrão do tema.
3. **A câmera cinematográfica ficava fora da árvore** quando não havia cena
   corrente — entre uma troca de cena e outra, e em bancada. `enquadrar`
   chamava `look_at` num nó solto, o plano acontecia na câmera errada e o único
   aviso era uma linha de erro por quadro. O modo foto tinha o mesmo defeito, e
   os dois foram consertados do mesmo jeito.

**O desfoque de movimento na cutscene ficou de fora, e não por esquecimento.** O
critério A15 diz que ele **só existe dirigindo**, e dois critérios do mesmo
plano não podem mandar em direções opostas. O maquinário está pronto
(`DesfoqueMovimento` é um efeito de compositor e já roda no MODERNO); ligá-lo
num movimento de câmera cinematográfica é uma decisão de direção de arte, como
foi a da viela — e por isso espera.

**O tempo de leitura mexe no ritmo da abertura.** `legenda(texto, duracao)`
passou a tratar a duração do roteiro como **piso**, não como ordem: uma linha
longa com duração curta agora fica o tempo de ser lida. Quem afinar a abertura
vai ver as linhas mais longas durarem mais do que duravam.

---

## 6. Ordem e dependências

| Fase | Depende de | Tamanho | Por quê nessa ordem |
|---|---|---|---|
| 0 Base técnica | — | M | sem branch compilável, sem medida e sem regressão, nada daqui pode ser provado |
| 1 Desempenho | 0 | M | 4K, GI e texturas 2K custam; a folga vem antes |
| 2 4K e AA | 1 | M | define a resolução em que tudo o resto é calibrado |
| 3 Texturas e PBR | 0, 2 | G | a luz da Fase 4 se calibra sobre o material final |
| 4 Luz | 3 | G | |
| 5 Pós, céu, decalques | 4 | M | exposição e tonemap se calibram sobre a luz final |
| 6 Chuva fora | 3 | M | pode correr em paralelo à 4 |
| 7 Carro AAA | 0 | G | independe da imagem; pode correr em paralelo |
| 8 Personagens | 0 | G | idem |
| 9 Áudio | 0 | M | idem |
| 10 UI, foto, cutscene | 2, 5 | M | modo foto e cutscene usam DOF e resolução |

Caminho crítico: **0 → 1 → 2 → 3 → 4 → 5**. As Fases 7, 8 e 9 podem começar
logo depois da 0.

---

## 7. Riscos

| Risco | Efeito | O que fazer |
|---|---|---|
| Sessões paralelas com WIP em `FogController`, `CameraRig`, `Carro`, `cidade.gd`, `project.godot` | edição perdida ou commit levando trabalho alheio | arquivo novo; ligação mínima commitada sozinha sobre o HEAD; Fase 0 |
| O PS1 mudar sem ninguém ver | quebra do contrato do ART-BIBLE | A2 em toda fase |
| GI clareando a noite | perde a direção de arte | referências de `PRINTS/` na regressão; GI calibrado por preset |
| TAA com rastro | borrão em movimento | snap desligado no MODERNO; medida A7 |
| VRAM do 2K | queda em máquina menor | presets; A10 |
| `gerar_materiais.py` apagando arquivos | material HD sumindo | gerador e pasta próprios |
| Geometria procedural sem UV2 | lightmap impossível | VoxelGI nos interiores |
| Compatibility (perfil mobile) | recursos que não desenham e não avisam (memória "Compatibility faz sombra") | tudo desta lista é MODERNO/Forward+; o perfil mobile continua PS1 |
| Custo de VehicleBody3D e física com mais carros detalhados | NaN e engasgo (memória "VehicleBody3D tem cinco armadilhas") | bancadas de física antes de cada mudança no carro |

---

## 8. Como medir

```bash
# base
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --quit
bash tools/checar_head.sh                         # A1 (novo)
python tools/regressao_visual.py                  # A2: ps1 e moderno
python tools/regressao_visual.py --ruido          # o piso de ruido da bancada
python tools/regressao_visual.py --gravar         # refaz as referencias

# quadro (A3–A6)
.tools/Godot_v4.7.2-stable_win64_console.exe --path game --resolution 1280x720 --     --pular-menu --pular-abertura --rota=noite_chuva     --fog=noite_chuva --chuva=1.0 --molhado=0.85     --medir=medida.csv --rota-fotos=captures/regressao/agora
bash tools/medir_largada.sh          # quanto cada autoload custa na largada

# o que já existe e continua valendo
python tools/verificar_carro.py
python tools/verificar_transito.py
python tools/verificar_cidade.py
```

Toda medida de pixel roda **com janela**, com `timeout`, e na **rota fixa** —
duas lições da Fase 6 da chuva.

---

## 9. O que ficou de fora, e onde está

- **Fase 7 da chuva** (vidro de fora molhado em todos os carros, retrovisor com
  imagem, som do limpador e das gotas): aprovada e descrita em
  `PLANO_CHUVA_CABINE_AAA.md`, fora desta seleção.
- **Cidade noturna viva** (janelas com interior falso, mais detalhe urbano,
  distância de desenho, neon e postes com padrão de luz): ideias 14–16 da lista,
  não selecionadas agora.

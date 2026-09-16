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

### Fase 5 — Pós, céu e decalques · M

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

### Fase 6 — Chuva fora do carro · M

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

### Fase 7 — Carro AAA completo · G

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

### Fase 9 — Áudio espacial · M

- **Eco por ambiente**: buses com reverb (rua, rua estreita, túnel, sala,
  carro), escolhidos por zona (`Interiores` já sabe onde o jogador está; rua
  estreita por raio).
- **Oclusão**: passa-baixa por raio entre fonte e ouvinte.
- **Chuva por superfície**: lata, teto de carro (a cabine já abafa a chuva),
  guarda-chuva, marquise.
- **Doppler** nos carros e pneu cantando no molhado.
- **Fecha A27.**

### Fase 10 — UI 4K, modo foto e cutscenes · M

- **Fontes**: `tools/gerar_fonte.py` passa a gerar a fonte **MSDF** (ou o
  bitmap em múltiplos inteiros por resolução) para o MODERNO; o PS1 mantém o
  bitmap de hoje. Ícones em 4×.
- **Modo foto**: cena própria com câmera livre, profundidade de campo,
  exposição, filtros, HUD escondido e PNG em 3840×2160.
- **Cutscenes**: letterbox, profundidade de campo por plano, desfoque de
  movimento, ritmo de legenda (a `Cinema` já existe).
- **Fecha A28–A30.**

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

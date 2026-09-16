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

### Fase 0 — Base técnica · M

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

### Fase 1 — Desempenho para 4K · M

- **Oclusão**: `ChunkBuilder` gera um `OccluderInstance3D` por quadra a partir
  das caixas de prédio que ele já monta (o Godot 4 faz a oclusão por
  rasterização em CPU; oclusor simples = caixa).
- **Instanciamento**: poste, placa, lixeira, árvore e prop repetido por chunk
  viram `MultiMeshInstance3D` (uma chamada por tipo).
- **Níveis de detalhe**: malha procedural gera LOD na montagem
  (`ImporterMesh.generate_lods`); distância de desenho por preset.
- **Fecha A5** e abre folga para A6.

### Fase 2 — 4K e anti-serrilhado · M

- MODERNO: `scaling_3d_mode` FSR 2 + TAA; nitidez calibrada; presets de
  `QualidadeGrafica`.
- O PS1 continua **sem** AA (ART-BIBLE: o serrilhado é parte do alvo).
- Risco conhecido: TAA com o *snap* de vértice deixa rastro — o MODERNO já tem o
  snap desligado; conferir nas capturas.
- **Fecha A6, A7** (e mede A10 com os presets).

### Fase 3 — Texturas 2K e PBR · G

- Pipeline da Seção 4.1; conjuntos 2K para as 18 texturas do ambientCG;
  escolha de conjuntos CC0 para as superfícies que hoje são geradas (fachada,
  calçada, interiores); atlas gerados em 4×.
- Bancada de material (`tests/medir_material.gd`): parede sob luz rasante,
  densidade de texel, VRAM.
- **Fecha A8, A9, A10.**

### Fase 4 — Luz global e sombras · G

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
python tools/regressao_visual.py --preset=ps1     # A2 (novo)
python tools/regressao_visual.py --preset=moderno

# quadro
.tools/Godot_v4.7.2-stable_win64_console.exe --path game -- --rota=noite_chuva --medir=medida.csv   # A3–A6 (novo)

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

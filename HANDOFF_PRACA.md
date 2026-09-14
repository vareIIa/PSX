# Handoff — a parte da introdução DEPOIS do carro na floresta

Cole o bloco abaixo como primeira mensagem da nova sessão.

---

Você vai trabalhar num jogo de horror estilo PS1 em Godot 4 (renderizador
Compatibility) que fica em `C:\Users\Administrator\Documents\Codes\Games\PSX`,
branch `feat/estrada-velha`. Leia `PROGRESSO.md` seções 0 e 1 antes de qualquer
coisa — a seção 0 é o roteiro canônico e não se discute.

## O que é a sua parte

O fluxo da abertura é: **carteira no banco do carro → cutscene na estrada de
terra → preto → acordar na Praça da Matriz → gameplay**.

A cutscene da estrada (o carro andando no mato) está fechada e não é sua. A sua
parte é **tudo que vem depois do preto**: a emenda, o acordar na praça, e a
sequência que leva até a primeira missão.

O roteiro canônico da praça, de `PROGRESSO.md`:

- Não anima o personagem levantando.
- **POV curto:** efeito de abrir o olho, olhando pro céu / névoa pura, olhar
  pra um lado e pro outro.
- **Depois:** câmera cinemática externa (de cima / 3-4). Dá pra ver o
  personagem **DEITADO** na frente da igreja. **Cada legenda muda o take.**
- As falas são lacuna de memória (farol na terra → apagou → acorda na praça;
  cadê o carro / cadê a pousada). Elas **não** reexplicam a viagem.

## Onde está o código

| Coisa | Arquivo |
|---|---|
| Roteiro da abertura pós-preto | `game/src/levels/abertura.gd` (1563 linhas) |
| O plano da praça | `abertura.gd:723` — `_plano_da_praca`, constantes `PRACA_*` / `ACORDA_*` a partir da linha 132, falas `praca_1..praca_5` na linha 250 |
| Emenda estrada → abertura | `game/src/levels/cidade.gd` — `_rodar_estrada` (991) e `_rodar_abertura` (997) |
| Cutscene da estrada (NÃO é sua) | `game/src/levels/abertura_estrada.gd` |
| Mapa da praça / igreja / coreto | `game/src/world/parque_builder.gd`, `game/src/world/kit_parque.gd` |
| Maquinaria de tarja/legenda/câmera | `Cinema` (autoload) — sabe desenhar, não sabe história |

`abertura.gd` é **só história**: onde a câmera fica em cada plano, o que está
escrito na tela, quanto dura. Toda constante de enquadramento mora no topo do
arquivo, com nome e com o porquê escrito. Mantenha esse padrão — o comentário
explica a decisão, não o que a linha faz.

Depois da praça, `abertura.gd` já tem mais sete planos (avenida em dois planos,
blitz, mercado, casa da fumaça, poste com a bicicleta, primeira pessoa com o
cigarro, GPS). Leia o cabeçalho do arquivo: eles estão listados em ordem.

## Referências visuais

`PRINTS\ref_praca_matriz\` — tem um `README.md` que mapeia cada arquivo:

- `01_acordar.png` — FP deitado no paralelepípedo, pernas no frame, igreja/coreto
- `02_igreja.png` — eixo da praça até a igreja
- `03_coreto.png` — coreto + lanterna + igreja atrás
- `04_vista_praca.png` — vista elevada / personagem na praça

HUD alvo: `LOCAL: PRAÇA DA MATRIZ` / `HORA: 23:15`.

Capturas já existentes para comparar: `captures\praca_matriz\cine\`,
`captures\praca_matriz\mapa\`, e a emenda em `captures\estrada_velha\emenda\`
(`00_estrada_antes.png`, `01_preto_emenda.png`, `02_pos_emenda_praca.png`).

## Como rodar e capturar

Godot portátil, projeto em `game/`. As flags de captura vão **depois do `--`**:

```
.tools/Godot_v4.7.2-stable_win64_console.exe --path game -- \
  --ver-praca --shot="<caminho absoluto>.png" --shot-frame=55 --shot-quit
```

- `--shot-frame` conta frames de **física**, não de render.
- `--stats=N` imprime `pior_ms`, fps e tris a cada N frames. O primeiro bloco
  inclui o build inicial (~150 ms) e não vale; use uma janela em regime.
- Flags de cena: `--ver-praca` (só a praça, encerra depois), `--ver-abertura`
  (caminho inteiro), `--pular-abertura`, `--ver-estrada`, `--ver-aparencia`,
  `--fog=`.
- `--mat-debug` pinta cada material de uma cor chapada sem sombreado e sem
  névoa — **o que sair preto é buraco**. Atenção: ele **não vale na praça**.
  É `EstradaBuilder._material()`, método daquele builder; a praça vem de
  `ChunkBuilder`/`KitModular`, que não têm esse gancho. Rodar `--mat-debug` aqui
  devolve a cena normal e você acha que passou no teste sem ter feito teste
  nenhum. Para procurar buraco na praça, use `--de-cima=` (câmera ortogonal, que
  força `fog_dia_sol` e luz zenital própria): um vazio aparece como vazio.
- `--sem-ceu` esconde cúpula e serra, para um vazio ler como preto em vez de
  ler como superfície. Esse vale em qualquer cena.
- Headless não prova shader. Capture com janela.
- **A primeira execução depois de mexer no código não vale como captura.** O
  Godot reimporta e o streaming ainda está montando no frame do `--shot-frame`:
  a foto sai com parte do mundo faltando. Já me fez concluir que a igreja tinha
  sumido — a mesma linha de comando, repetida, mostrou a igreja no lugar. Rode
  duas vezes e confie na segunda.

## Contrato de render (não negocie sem avisar)

480×270 interno, `gl_compatibility`, `vertex_lighting`, `cull_back`, filtro
nearest, sem mipmap, dither de 15 bits, vinheta, scanlines. Texturas: 256×256,
≤256 cores, PNG, `compress/mode=0`, `mipmaps/generate=false`,
`detect_3d/compress_to=0`, e têm de ladrilhar.

## Como se trabalha aqui (aprendido caro, não repita)

1. **Meça antes de mexer.** Três rodadas de palpite perdem para uma medida que
   nomeia o culpado. Amostre pixel cru, numa região conferida contra a imagem —
   nunca ajuste no olho por cima de uma imagem clareada. Já li "laje pálida" no
   que era um render escuro multiplicado por 3,2.
2. **`get_aabb` não vale no Compatibility.** A imagem é a medida.
3. **A face aparece do lado OPOSTO ao produto vetorial.** Já derrubou o Fusca,
   os cinco carros de caixa e o chão inteiro da estrada.
4. **Com `vertex_lighting` a luz só existe nos vértices.** Objeto fino sem
   subdivisão pode ser atravessado pelo cone de luz no meio e continuar preto.
5. **Degrau entre duas superfícies sem parede lateral não é degrau, é buraco.**
   Se duas superfícies vizinhas calculam a mesma borda por caminhos diferentes,
   elas vão discordar e abrir fenda. Faça a borda ser função só da posição.
6. **A 480×270 só sobrevive feição grande** — cerca de um quinto da célula da
   textura. Detalhe fino morre na minificação e vira o mesmo chiado do dither.
7. **Conserte o mundo em vez de contornar.** A viela não devia ser evitada,
   devia ser alargada.
8. **Relatório de outro agente não é prova.** Confira.
9. **Trocar buraco por saliência não é conserto.**

## Sessões paralelas

Outras sessões mexem no mesmo repo. Arquivo que muda sozinho não é bug seu; um
merge alheio reverte working tree, mas arquivo novo sobrevive. Confira
`git status` antes de concluir que quebrou algo.

Dono declarado em `PROGRESSO.md`: `abertura.gd` / `_plano_da_praca` é do Cine2.
Confirme com o usuário se você pode editar esse arquivo antes de começar.

Há um problema conhecido e deliberadamente não tocado: `_aplicar_facho_nevoa`
em `game/src/world/carro.gd:1173` lê `Settings.fog_preset()` em vez do preset
forçado pelo `FogController`, violando o contrato do próprio FogController.
Esse arquivo estava sendo editado por outra sessão.

## Duas decisões em aberto que travam trabalho

Pergunte ao usuário antes de implementar o corte da igreja:

1. **Em que momento o corte da igreja entra na sequência?**
2. **É a capela branca da `ref 01` ou o galpão em ruína da ref com marca
   d'água** (`PRINTS\CENARIO CENA DA FLORESTA\watermarked_*.jpg`)? O galpão em
   ruína não existe no kit ainda — se for ele, é modelagem nova.

## Estado

Nada commitado na working tree atual. `git status` tem muito untracked
(`PRINTS\ref_*`, `PROGRESSO.md`, `captures\`, ferramentas `_tmp`) — **não apague
sem revisar**. Há um stash `wip-pre-merge-blitz-aaa` ainda no repo.

Comece lendo `PROGRESSO.md` seções 0, 1 e 3.3, depois `abertura.gd` do começo
até `_plano_da_praca`, e rode uma captura com `--ver-praca` para ver de onde
você está partindo.

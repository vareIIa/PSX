# PLANO DE DESENVOLVIMENTO — Jogo PSX Style

> Leia antes: [PROMPT-MESTRE](docs/PROMPT-MESTRE.md) e [ART-BIBLE](docs/ART-BIBLE.md).
> Versão 1.0 — 06/09/2026

---

## Status

| Fase | Estado |
|---|---|
| 0 — Fundação | **Concluída** em 06/09/2026 |
| 1 — O look | **Concluída** em 06/09/2026, critério de aceite verificado |
| 2 — Controle e câmera | **Concluída** em 06/09/2026 |
| 3 — Kit modular e streaming | **Concluída** em 06/09/2026, 589 m sem engasgo |
| 4 — O primeiro distrito | Em andamento |
| 5 a 7 | Não iniciadas |

O aceite visual da Fase 1 está em `captures/COMPARACAO_FASE1.png`, e a verificação
numérica do corte de 15 bits e do teste A/B de snap está registrada abaixo, na
seção de verificação.

---

## Decisões já tomadas

**Engine: Godot 4.7.2, renderizador Compatibility.**
Escolhido sobre Unity e Unreal por três motivos concretos. As cenas, scripts e
shaders são arquivos de texto, o que permite gerar e revisar o projeto inteiro sem
abrir editor gráfico. O renderizador Compatibility roda em OpenGL ES 3.0 e já impõe
naturalmente boa parte das limitações que queremos emular. E a licença MIT não cobra
royalty nem exige splash. Já está instalado em `.tools/`, versão verificada.

**Linguagem: GDScript.** C# só entraria se aparecesse gargalo de CPU no streaming, o
que é improvável nesse budget de polígono.

**Cenário: subúrbio japonês, noite.** Fixado a partir das prints. Ver PROMPT-MESTRE.

---

## Arquitetura de pastas

```
PSX/
├─ .tools/                  Godot portable (fora do versionamento)
├─ .claude/skills/          Skills do projeto
├─ docs/                    PROMPT-MESTRE, ART-BIBLE
├─ tools/                   Utilitários Python de asset pipeline
├─ PRINTS/                  Moodboard de referência
└─ game/                    Projeto Godot
   ├─ project.godot
   ├─ shaders/              psx_surface, post_psx
   ├─ src/
   │  ├─ player/            controller, câmera, alternância V
   │  ├─ world/             chunk manager, streaming, nevoeiro
   │  ├─ systems/           inventário, save, rádio, áudio
   │  └─ ui/                menus, prancha de inventário
   ├─ assets/               textures, models, audio, fonts
   ├─ scenes/               chunks, interiores, testes
   └─ resources/            presets de nevoeiro, dados de item
```

---

## Fases

Cada fase termina em algo que roda e pode ser visto. Nenhuma fase depende de uma fase
posterior. As estimativas são em sessões de trabalho focadas, não em dias de calendário.

### Fase 0 — Fundação `~1 sessão`

Projeto Godot criado, renderizador Compatibility, SubViewport de 480x270 com upscale
nearest, git inicializado, estrutura de pastas.

**Pronto quando:** `godot --headless --quit` importa sem erro e a janela abre.

### Fase 1 — O look `~3 sessões` — fase crítica

É aqui que o projeto vive ou morre. Todo o contrato do ART-BIBLE vira dois shaders.

- `psx_surface.gdshader` com vertex snap, UV afim, luz por vértice, dither de 15 bits e névoa.
- `post_psx.gdshader` com grão, aberração cromática, scanline, vinheta e LUT.
- Sala de teste que reproduz o corredor de concreto da referência: um corredor, uma
  luz, um prop, uma porta tapada com tábuas.
- Recurso `FogPreset` com os três presets do ART-BIBLE.

**Pronto quando:** um print do jogo colocado ao lado das referências do corredor de
concreto e do quarto âmbar é indistinguível em dither, tremor de vértice e queda de
luz. Se não for, nada mais começa.

**Risco resolvido.** A dúvida era se a escrita em `POSITION` e o cancelamento da
correção de perspectiva funcionariam no Compatibility do 4.7.2. Funcionam. Testado em
OpenGL 3.3 Core numa Radeon RX 9070 XT, com diferença medida de 59,3% dos pixels
entre ligado e desligado. O plano B não foi necessário.

### Fase 2 — Controle e câmera `~2 sessões`

`CharacterBody3D` com movimento em primeira pessoa e cápsula de 1.7 m. A tecla `V`
alterna para um `SpringArm3D` no enquadramento das referências de terceira pessoa,
sem corte. Head bob, passos sincronizados por superfície, corrida com fôlego
limitado. Menu de opções com os três níveis de nevoeiro, intensidade de grão,
aberração cromática, scanline e vinheta, tudo persistido em `user://settings.cfg`.

**Pronto quando:** dá para andar pela sala de teste nos dois modos e trocar em
movimento sem engasgo.

### Fase 3 — Kit modular e streaming `~4 sessões`

Grade de chunks de 32 m. O `ChunkManager` carrega e descarrega por distância em
thread separada, com o horizonte definido pelo preset de nevoeiro ativo. Kit modular
v1 com calçada, meio-fio, asfalto, muro, fachada de loja, fachada de apartamento,
poste com fiação, máquina de venda automática, placa e escada externa.

Regra do kit: tudo em múltiplos de 2 m, pivô no canto inferior esquerdo, chão e
parede subdivididos em quads de 2 m por causa da UV afim.

**Pronto quando:** dá para andar 500 m em linha reta sem engasgo e com memória estável.

### Fase 4 — O primeiro distrito `~4 sessões`

A rua noturna da referência montada de verdade: shotengai estreito, máquinas de venda
acesas, chuva, céu verde-petróleo, postes com fiação aérea. Um interior de apartamento
acessível sem tela de loading, no tom do corredor rosa.

**Pronto quando:** existe um passeio de cinco minutos que dá vontade de gravar.

### Fase 5 — Sistemas de horror `~4 sessões`

Inventário em prancha de cortiça reproduzindo a referência de UI, com recortes de
papel, fita, polaroid e status textual. Rádio com chiado modulado pela distância ao
inimigo. Lanterna com bateria contada. Um inimigo com percepção por som e visão em
cone. Save em ponto fixo. Munição e cura como itens contáveis.

**Pronto quando:** existe um loop de tensão de dez minutos: explorar, ouvir o rádio,
decidir entre fugir e gastar recurso.

### Fase 6 — Conteúdo e escala `aberto`

Mais distritos reaproveitando o kit, estação de trem, escola, narrativa por documentos
e fitas. Esta fase não tem fim definido, ela consome o tempo que sobrar.

### Fase 7 — Build `~2 sessões`

Export templates, empacotamento Windows, tela de título, créditos, ajuste final de
performance.

---

## Skills instaladas

Quatro skills locais em `.claude/skills/`, carregadas sob demanda quando o assunto
aparece. Elas existem para que o contrato do ART-BIBLE não precise ser relembrado a
cada sessão.

| Skill | Cobre |
|---|---|
| `psx-render` | Os dois shaders, os números do ART-BIBLE, armadilhas do Compatibility |
| `psx-assets` | Autoria e importação de textura e modelo dentro do budget |
| `psx-city` | Regras do kit modular, grade de 32 m, convenção de chunk e streaming |
| `godot-project` | Convenções do projeto, como rodar headless, como validar uma cena |

Também instalado o utilitário `tools/psxify.py`, que converte qualquer imagem para a
especificação do ART-BIBLE: reduz para 128 px, quantiza para 256 cores com dither e
grava PNG sem perda.

---

## Riscos

**A cidade vasta é o risco número um.** Uma cidade grande e vazia de conteúdo é o modo
de falha mais comum desse tipo de projeto. A mitigação é estrutural: o kit modular vem
antes do primeiro quarteirão, e cada distrito é jogável sozinho. Se o tempo acabar na
Fase 4, existe um jogo curto e bom em vez de um mapa grande e morto.

**O look pode não fechar.** Por isso a Fase 1 vem antes de qualquer conteúdo e tem um
critério de aceite visual explícito. Falhar cedo aqui custa três sessões. Falhar na
Fase 5 custa o projeto.

**Não há artista 3D nem Blender instalado.** Mitigado na Fase 1 de forma melhor que a
prevista: em vez de caixas CSG, existe o `PSXMesh`, um construtor que gera plano e
caixa já subdivididos no teto de 2 m exigido pela UV afim. A regra passa a ser
garantida por construção em vez de por disciplina, e o mesmo construtor serve o kit
modular da Fase 3. Blender só entra quando for preciso rigar personagem.

**Volume de textura.** Uma cidade precisa de muita textura. Mitigação: o `psxify.py`
converte imagens de referência em massa, e a variação de cor sai de tint por vértice
em cima de textura em escala de cinza, multiplicando o número de materiais sem
multiplicar o número de arquivos.

**Direitos autorais.** O artigo de referência cita o caso do Puppet Combo, que teve
que renomear seu primeiro jogo. Nada de nome, marca, música ou personagem de obra
existente, nem em asset de placeholder.

---

## Próximo passo

Executar a Fase 0 e a Fase 1. São as únicas que precisam acontecer em ordem estrita e
juntas, porque o critério de aceite da Fase 1 é o que autoriza todo o resto.

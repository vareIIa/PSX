# PLANO UI AAA — Boot, Menu, HUD, Mapa e Pausa

> Diagnóstico medido + plano de execução para levar a camada de interface ao
> mesmo rigor do resto do projeto.
> Versão 1.0 — 11/09/2026 — branch `playable`

---

## 0. O que "AAA" significa nesta frente

`docs/PADROES-ENGENHARIA.md` já fixou a tese: AAA aqui não é mais efeito, é rigor
de estúdio grande aplicado a uma apresentação deliberadamente limitada. Traduzido
para interface:

| AAA na UI significa | AAA na UI não significa |
|---|---|
| Nenhum retângulo de texto encosta em outro, e existe teste que prova | Mais animação |
| Toda medida de HUD sai de um documento canônico | HUD maior |
| A informação que o jogo tem, a tela mostra | Mais widgets |
| Cada tela é capturável por flag e comparável com referência | Mais telas |
| O que já existe no código está alcançável pelo jogador | Reescrever o que funciona |

A última linha é a mais cara deste plano: **metade do que falta já está escrito e
simplesmente não tem caminho até o jogador.** Opções de pós-processamento, três
espaços de save com resumo, HUD de vida/hora/lanterna, ícones de mapa — tudo
pronto, tudo inacessível em jogo.

---

## 1. Diagnóstico medido

Cada item abaixo foi lido no código, não estimado. Onde há número, ele foi medido.

### 1.1 Boot / PRESS START — `game/src/ui/menu.gd:340`

O fundo é uma **textura 2D parada** (`ui_boot_plate.png`), desfocada por
`soft_blur = 0.85` e misturada pelo CRT (`menu.gd:283`). A única coisa que se
move na tela inteira são 3 px de jitter no título e o pisca do prompt
(`menu.gd:984`).

O detalhe que importa: o shader CRT **já sabe ler a cena 3D renderizada** —
`scene_mix` em `shaders/crt_overlay.gdshader:14`, alimentado pelo `BackBufferCopy`
de `menu.gd:263`. A máquina para ter profundidade de verdade está montada e está
sendo alimentada com uma foto parada.

**Veredito:** não falta efeito. Falta assunto atrás do vidro.

### 1.2 Transição pós-START — `game/src/levels/cidade.gd:985`

A câmera olha −22° / +22° / 0° dentro da Casa da Fumaça, colada a 1,05 m do tubo,
FOV 32. E o cômodo foi **esvaziado de propósito**:

- `_ocultar_convidados(true)` (`cidade.gd:928`) apaga os oito convidados que andam,
  fumam e conversam;
- `_forcar_tv_estatica(true)` (`cidade.gd:950`) mata a única fonte de luz animada.

`game/src/levels/abertura.gd:26` documenta a intenção do plano da casa com todas
as letras: *"o plano existe exatamente para dizer que aquela casa é cheia de gente
viva"*. A tela mostra o contrário.

**Veredito:** o vazio é decisão de código, não limitação de cena.

### 1.3 Fundo do menu de título — `game/src/levels/cidade.gd:841`

Este é o achado central, e ele é aritmético:

| medida | valor | origem |
|---|---|---|
| altura da câmera | +15,0 m | `cidade.gd:846` |
| inclinação | −25° | `cidade.gd:851` |
| névoa forçada | `fog_denso` | `cidade.gd:855` |
| fim da névoa | **18,0 m** | `resources/fog/fog_denso.tres` |
| corte de desenho | `fog_end × ALCANCE_EXTRA` ≈ **24 m** | `chunk_manager.gd:177` |
| **distância real do chão no quadro** | **15 / sen(25°) ≈ 35,5 m** | — |

**Tudo que a tela de título enquadra está ~17 m depois do fim da névoa e ~11 m
depois do corte de desenho.** A tela é, matematicamente, uma parede cinza. A
deriva de 4 m/s (`cidade.gd:1390`) move uma parede cinza.

Isto é exatamente a lição que a memória do projeto já registrou em *"Corte de
desenho mede até o centro"* e que `abertura.gd:60-70` escreveu por extenso depois
de queimar um plano da avenida pelo mesmo motivo.

**Veredito:** nenhum ajuste de UI conserta isto. O que conserta é a câmera voltar
para dentro do alcance.

### 1.4 Cartão de missão — `game/src/ui/hud_missao.gd` **[RESOLVIDO 11/09]**

> **Correção de medida.** A primeira leitura deste plano contou a largura do texto
> pelo `xadvance` do `.fnt` e errou. `tests/medir_fonte.gd` mediu no motor e achou
> uma causa raiz mais grave, abaixo. Os números da v1.0 ficam registrados como o
> que a conta manual dava; os que valem são estes.

**A causa raiz não era o layout, era o tamanho da fonte.**

As quatro fontes do projeto são bitmap com `fixed_size_scale_mode = 2`, que é
escala livre. Um `Label` que recebe `font` e **não** recebe `font_size` usa o
padrão do tema, que é 16. Medido:

| fonte | nativa | altura de linha nativa | com o padrão do tema |
|---|---|---|---|
| `psx_pequena` | 11 | **13,0 px** | esticada 1,4545× → **18,9 px** |
| `psx_titulo` | 18 | 21,0 px | **encolhida** 0,889× |

E a varredura mostrou que **16 lugares do projeto prendiam a fonte e só 4 prendiam
o tamanho** — e esses 4 eram do serif TTF do boot, não das bitmap. Ou seja: toda
tela feita de `Label` desenhava fonte de pixel em escala não inteira, reamostrada,
ampliada depois 4× para 1080p. É isto que fazia o HUD parecer "mole". As telas
desenhadas à mão (GPS, celular, ficha, terminal) nunca tiveram o problema porque
passam o tamanho direto no `draw_string` — o que explica por que o aparelho sempre
pareceu mais nítido que o HUD.

Com a fonte esticada, a colisão medida era:

| rótulo | ocupava | colidia com |
|---|---|---|
| título | 3–21,9 | objetivo L1 — **8,9 px** |
| título (155 px de largura) | — | distância, alinhada à direita a partir de 130 px — **24,6 px** |

E título e distância nasciam no **mesmo retângulo** (`hud_missao.gd:117` e `:121`).

**Entregue:**
- `game/src/ui/ui_estilo.gd` — métrica, camadas, tinta, tempos; `aplicar()` prende
  fonte **e** tamanho.
- `game/src/ui/cartao_layout.gd` — empilhamento como **função pura**, sem `Node` e
  sem autoload, no desenho de `MalhaUrbana`.
- `game/src/ui/hud_missao.gd` — vira aplicador fino; ganhou `ETAPA 1/2`, régua de
  cabeçalho, bússola que aponta o alvo relativa ao olhar, título com reticência,
  altura derivada do conteúdo.
- `game/tests/checar_hud.gd` — **486 asserções** contra os piores casos.
- `game/tests/medir_fonte.gd` — métrica real das quatro fontes.
- `docs/UI-BIBLE.md` — o documento canônico que faltava.
- Flags `--ver-missao`, `--ver-missao=tira`, `--ver-missao=longo`.

**Segundo achado, medido na captura:** o papel ficava **29 níveis** acima da parede
em névoa densa — 11% de contraste — e o cartão lia como mancha, não como objeto.
Corrigido com `PAPEL_LUZ` (o mesmo valor que `menu.gd` já usa) mais contorno de
1 px, o mesmo recurso que o minimapa usa para separar quadra de quadra. Agora são
43 níveis e a borda fecha a forma.

### 1.5 HUD de gameplay na cidade — `game/src/levels/cidade.gd:63-67`

A cidade instancia **apenas** `PranchaInventario`, `Minimapa`, `HudMissao` e um
`Label` que mora num nó chamado `Debug/Prompt` (`cidade.gd:11`).

Não há relógio, vida, lanterna, bússola nem estado de nada. `HudEstrada`
(`hud_estrada.gd`) tem LOCAL, HORA, barra de vida segmentada e ícone de lanterna
prontos — e é usado **só** por `abertura_estrada.gd:280`.

**A sequência de abertura tem mais HUD que o jogo.** O dano existe
(`cidade.gd:_montar_dano`, `_vida_anterior`) e se manifesta como um flash vermelho
sobre uma vida que o jogador nunca vê.

### 1.6 Rota no mapa — `game/src/ui/gps.gd:750` e `game/src/ui/mapa.gd`

`Gps._tracar_rota()` grava `destino` e emite `destino_mudou`. Quem escuta desenha
**um alfinete** — `Mapa` tem `pinos` (`mapa.gd:86`) e nada mais. O minimapa vira
bússola de texto: `"270 M NE"` (`minimapa.gd:126`).

O jogador marca a rota no celular e recebe distância e rumo. **Linha, nenhuma.**

O que torna isto barato de consertar: a cidade é uma **função pura da coordenada**.
`malha_urbana.gd:107` (`via_x` / `via_z`) diz que rua passa em cada linha de grade
de 32 m, com avenida a cada 5. Um A* sobre os cruzamentos roda **sem carregar um
único chunk** — é a mesma promessa que o GPS já cumpre ao listar endereços em rua
onde ninguém pisou (`gps.gd:92-104`).

**Veredito:** falta o traçado, e o dado para traçá-lo já existe, é determinístico e
é barato.

### 1.7 Pausa e menu de sistema — `game/src/ui/prancha_inventario.gd:611`

ESC e TAB abrem a mesma prancha. Não existe menu de sistema em jogo — e
`cidade.gd:1379` diz isso em comentário: *"o menu de título não reabre no meio da
partida — escopo HUD-only"*.

O que o jogador perde por isso:

| já existe no código | alcançável em jogo? |
|---|---|
| 6 ajustes de pós (névoa, grão, aberração, scanline, vinheta, dither) — `menu.gd:115` | ❌ só antes de NOVO JOGO |
| 3 espaços de save com `resumo()` para tela de carregar — `save_game.gd:18,34` | ❌ menu só oferece CONTINUAR (espaço 0) |
| página de mapa em papel com legenda e 4 escalas — `menu.gd:559` | ❌ só pelo menu de título |
| buses Master / SFX / Music / Radio / Ambiente — `default_bus_layout.tres` | ❌ **não há nenhum controle de volume em `settings.gd`** |

O canto superior direito da prancha está vazio — é exatamente onde os três
pauzinhos cabem.

---

## 2. Plano de execução

Sete fases. Cada uma fecha pela "Definição de pronto" de
`docs/PADROES-ENGENHARIA.md` (headless sem warning, captura comparada, número
vindo de documento, tipagem estática, commit que diz o porquê).

### Fase 0 — Contrato de UI *(meia sessão)*

**Por quê primeiro:** hoje cada arquivo de UI tem suas próprias medidas soltas. O
bug do cartão de missão é filho direto disso — alguém escolheu 10 px de espaçamento
sem lugar onde conferir que a fonte tem 13. Sem este passo, a Fase 1 conserta um
cartão e o próximo widget nasce torto do mesmo jeito.

**Entregáveis**
- `docs/UI-BIBLE.md` — área segura, grade vertical de 13 px, larguras de cartão,
  paleta de tinta (já consistente: `#2a1f16`, `#6a5a44`, `#7a3a22`, `#8a2f1f`),
  tempos de animação, camadas (`CanvasLayer`) e o que cada uma significa.
- `game/src/ui/ui_estilo.gd` — as mesmas constantes em código, um lugar só.

**Pronto quando:** todo número novo das fases seguintes cita seção do UI-BIBLE no
comentário.

### Fase 1 — HUD: consertar o que está quebrado *(prioridade máxima)*

**Arquivos:** `game/src/ui/hud_missao.gd`

1. Relayout na grade de 13 px; altura do papel derivada do conteúdo, não constante.
2. **Distância sai da linha do título** e vira chip próprio (canto inferior direito
   do cartão ou linha própria), com largura reservada e o título truncado com
   reticências no que sobra.
3. Objetivo numa caixa que cabe 2 linhas de verdade (26 px), com `size.y` calculado.
4. Dica em 2 linhas ou encurtada para ≤ 174 px.
5. Acrescentar: `ETAPA 1/2`, ícone do tipo de destino (os ícones já existem em
   `assets/ui/icone_*.png`) e seta de rumo ao alvo.

**Pronto quando:** `game/tests/checar_hud.gd` afirma que (a) nenhum par de `Control`
do HUD tem retângulos que se cruzam, (b) toda string cabe na própria caixa medida
pela fonte real. É o teste que impede a classe inteira de bug de voltar.
Captura: `--ver-missao`.

### Fase 2 — HUD: o que falta para o jogo informar

**Arquivos:** `game/src/ui/hud_estrada.gd` (ou um `hud_jogo.gd` derivado),
`game/src/levels/cidade.gd`

1. Trazer o vocabulário de `HudEstrada` para a cidade: LOCAL, HORA, vida, lanterna.
   **Não como segundo HUD** — unificar, senão viram duas fontes de verdade.
2. **Decisão de camada a tomar antes de codar:** `HudEstrada` está em `layer = 160`,
   acima do pós-processamento; `Minimapa` e `HudMissao` estão em 100/101, abaixo — e
   `minimapa.gd:3` explica por quê (*"um mapa nítido por cima de uma cena suja
   denunciaria na hora"*). Na cidade o HUD deve ficar em 100/101. Mudar camada muda
   o look; é mudança de contrato, não de gosto.
3. Prompt de interação sai do nó `Debug` e ganha o vocabulário de papel do resto.
4. Dano: além do flash, leitura de vida legível e feedback direcional.

**Pronto quando:** capturas em névoa densa e em dia de sol mostram o HUD legível nas
duas; nenhum elemento novo acima da camada 150 sem justificativa escrita.

### Fase 3 — Rota traçada no mapa *(o pedido mais concreto)*

**Arquivos novos:** `game/src/world/rota.gd`, `game/tests/checar_rota.gd`
**Arquivos tocados:** `game/src/ui/gps.gd`, `game/src/ui/mapa.gd`,
`game/src/ui/minimapa.gd`

1. `Rota` — A* estático sobre os cruzamentos da malha, função pura da coordenada
   como `MalhaUrbana`. Entrada: origem e destino em mundo. Saída:
   `PackedVector2Array` de pontos. Custo de avenida menor que o de rua, e o de viela
   maior — assim a rota prefere avenida, que é como gente anda e como o jogador se
   orienta.
2. `Gps._tracar_rota()` calcula uma vez e guarda; `rota_atual()` público.
3. `Mapa.rota: PackedVector2Array` + `_desenhar_rota()`, desenhado **abaixo dos
   alfinetes e acima da névoa do desconhecido** — a rota atravessa quadra não
   visitada por definição.
4. Como minimapa, página de pausa e tela do GPS são a **mesma classe** (`mapa.gd:4`
   avisa que duas implementações divergiriam), o traçado aparece nas três de uma vez.
5. Recalcular quando o jogador sai do corredor da rota; chevron do próximo giro no
   cartão do canto.

**Pronto quando:** `checar_rota.gd` afirma que a rota (a) existe para um destino a 12
chunks, (b) é contígua, (c) só passa por linha de grade com `via_* != NENHUMA`, (d)
termina na quadra do destino. Custo medido como o do GPS foi (`tests/custo_gps.gd`:
7,3 ms / 625 chunks) e registrado no cabeçalho do arquivo — **medir antes de mexer.**
Captura: `--ver-mapa --com-rota`.

### Fase 4 — Menu de sistema em jogo (os três pauzinhos)

**Arquivos:** `game/src/ui/prancha_inventario.gd`, `game/src/ui/menu.gd`,
`game/src/systems/settings.gd`

1. Três pauzinhos no canto superior direito da prancha. Teclado/controle primeiro
   (é como o jogo inteiro se navega); mouse também — e aqui mora uma armadilha já
   documentada em `menu.gd:194`: `Control` de área zero não recebe clique nenhum.
2. Painel com: CONTINUAR · CARREGAR · OPÇÕES · ÁUDIO · CONTROLES · SAIR PARA O TÍTULO.
3. CARREGAR usa `SaveGame.resumo(espaco)` nos 3 espaços — tela nova, dado velho.
4. OPÇÕES **reusa** `Menu.Painel.OPCOES`. Não reescrever a lista: ela é a fonte única
   dos 6 ajustes de pós e reescrevê-la cria a segunda que diverge.
5. ÁUDIO é código novo de verdade: `Settings` ganha `volume_master`, `volume_sfx`,
   `volume_musica`, `volume_ambiente`, gravados em `settings.cfg` e aplicados aos
   buses do `default_bus_layout.tres`. Hoje não existe uma linha disso.

**Pronto quando:** teste afirma que toda chave de `Settings` sobrevive a
gravar→ler→aplicar; captura `--ver-pausa-sistema`; abrir e fechar o painel não
destrava a pausa nem solta o mouse no lugar errado.

### Fase 5 — Boot com profundidade

**Arquivos:** `game/src/ui/menu.gd`, `game/src/levels/cidade.gd`

1. Trocar a placa parada por **vista 3D viva**. Duas opções:
   - **(a) o tubo no fim do corredor**, câmera avançando muito devagar — mantém a
     narrativa (o jogo começa dentro de uma TV) e já prepara o plano seguinte;
   - **(b) a rua com névoa e um poste aceso**, deriva lateral — a paralaxe sai de
     graça do 3D.

   **Recomendação: (a).** O `scene_mix` já lê a cena; é ligar o que está montado.
2. Camadas de paralaxe em 2D como complemento: título numa taxa, poeira/vinheta de
   frente noutra. Profundidade lida tanto de movimento diferencial quanto de 3D.
3. O boot não pode depender do interior estar carregado — hoje `_preload_casa_boot`
   roda atrás do CRT opaco, o que está certo; manter, mas mostrar algo enquanto isso.

**Pronto quando:** captura `--ver-boot` comparada com `PRINTS/ref_crt_title.jpg`;
primeira execução **não vale** como captura (a memória do projeto já pagou por isso).

### Fase 6 — Transição e fundo do título

**Arquivos:** `game/src/levels/cidade.gd`

1. **Devolver os convidados.** A sala cheia é o plano. Manter a TV em estática (ela é
   a origem do título), mas iluminar o cômodo e deixar a gente andar.
2. **Trazer a câmera do título para dentro do alcance.** Com `fog_end = 18 m`, o
   enquadramento tem de cair dentro de ~15 m. Duas opções:
   - **(a) plano baixo, nível de rua, deriva lenta** — é exatamente a lição que
     `abertura.gd:60-70` já aprendeu e escreveu depois de queimar um plano igual;
   - **(b) manter a altura** e dar ao título um preset de névoa mais longo + abrir o
     corte de desenho (`ChunkManager.raio_extra` / alcance infinito já existem para a
     inspeção de cima).

   **Recomendação: (a).** Custa nada e usa uma lição já paga.
3. Três a quatro planos alternando com corte de estática, em vez de um olhar L/R só.

**Pronto quando:** a captura do título mostra rua, meio-fio, poste e fachada — não
um retângulo cinza.

### Fase 7 — Polimento transversal

- Tempos de entrada/saída unificados pelo UI-BIBLE.
- Som em toda transição de UI (`clique`, `papel`, `bipe_curto` já existem).
- Navegação de controle em todas as telas.
- Modo `--ui-audit`: desenha o retângulo de todo `Control` do HUD numa captura só —
  sobreposição vira coisa que se vê, não que se descobre em print de jogador.

---

## 3. Ordem recomendada

```
Fase 1  ->  Fase 3  ->  Fase 4  ->  Fase 5 + 6  ->  [decisao de morte]  ->  Fase 2  ->  Fase 7  ->  Fase 8
(Fase 0 corre junto com a 1)
```

**Decidido em 11/09/2026:** comeco pela **Fase 1**, o cartao de missao.

**Por quê:** 1 e 3 são o que o jogador encontra nos dois primeiros minutos — texto
por cima de texto e uma rota que ele marcou e não apareceu. 4 destranca seis ajustes,
três saves e uma página de mapa que **já estão escritos** e não têm porta. 5 e 6 são a
primeira impressão, e são as mais caras. 2 é acréscimo, não conserto.

---

## 4. Riscos conhecidos

| risco | origem | mitigação |
|---|---|---|
| `tools/gerar_materiais.py` apaga `.tres` fora da tabela dele | memória do projeto | não criar `.tres` de UI sem entrar na tabela |
| Mudar camada de `CanvasLayer` muda o look inteiro | `minimapa.gd:3`, `hud_estrada.gd:67` | decidir camada na Fase 2, por escrito |
| Sessões paralelas mexendo nos mesmos arquivos | memória do projeto | arquivo novo sobrevive a merge alheio; preferir arquivo novo a edição grande |
| Primeira execução não vale captura | memória do projeto | descartar o primeiro frame; usar `--shot-frame` |
| Captura de UI não roda em cena de estrada | memória (`--mat-debug`) | cada fase declara a própria flag e a cena onde ela vale |
| A* na malha custar quadro | — | medir como `tests/custo_gps.gd` mediu, antes de integrar |

---

## 5. Ideias não pedidas — **todas aprovadas em 11/09/2026**

Nenhuma delas foi solicitada. Todas saíram de código que **já existe e está parado**
— é por isso que estão aqui e não numa lista de desejos. O Jamerson aprovou as oito;
elas entram como **Fase 8**, depois do plano de UI fechar, na ordem de retorno
sobre custo abaixo.

| # | Ideia | O que já existe | Custo |
|---|---|---|---|
| 1 | **Orelhão vira ponto de save** | `save_game.gd:3` já defende ponto fixo por escrito; a varredura do GPS conta **51 orelhões** em 12 chunks (`gps.gd:96`); `icone_telefone.png` existe | baixo |
| 2 | **Nome do bairro ao cruzar** | `Mapa.onde_estou()` e `MalhaUrbana.nome_do_distrito()` já devolvem o nome | uma tarde |
| 3 | **Retrato da prancha reflete o estado** | a polaroid já é um `Corpo` 3D vivo (`prancha_inventario.gd:78`) e o cartão já tem campo STATUS | baixo |
| 4 | **Modo foto** | `CaptureTool` fotografa, `_camera_de_cima` já monta câmera livre, os 6 ajustes de pós já são sliders; falta juntar e esconder o HUD | baixo para o que entrega |
| 5 | **Escala de UI nas opções** | 480×270 numa TV é duro de ler; multiplicador de fonte do HUD | baixo |
| 6 | **Missão chega como mensagem no celular** | `app_mensagens.png` já está em `assets/ui`; resolve o objetivo sumir quando o cartão encolhe | médio |
| 7 | **Foto do celular marca destino no mapa** | `app_camera.png` e `app_galeria.png` existem sem função | médio |
| 8 | **Relógio que anda + névoa por hora** | `definir_hora_minutos()` existe; `FOG_PRESET_IDS` tem dia/noite/chuva | alto — **mexe em contrato de névoa, trata como frente própria** |

Ordem de execução dentro da Fase 8: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8. Os quatro
primeiros são de custo baixo e independentes entre si; o 8 é o único que toca o
ART-BIBLE e por isso vai por último, com captura em cada preset.

### 5.1 Morte e fim de partida — **decidido: resolver antes da Fase 2**

Buraco de sistema encontrado de passagem, e não de UI: o dano existe
(`cidade.gd:_montar_dano`) e se manifesta como flash vermelho sobre uma vida
invisível. **Não há tela de morte nem fim de partida.** Se a vida chega a zero,
nada acontece.

A Fase 2 desenha justamente a barra que torna isso visível para o jogador, então a
decisão vem antes dela: entregar uma barra que chega a zero e não significa nada é
pior do que não ter barra. O que precisa ser definido, por escrito, antes de a Fase 2
começar:

1. O que acontece em vida zero — tela, corte, ou desmaio com reaparição.
2. Onde o jogador volta — ponto de save (ver ideia 1, aprovada), cama, ou praça.
3. O que ele perde — nada, item, ou tempo.
4. Se há continuidade de narrativa (um jogo sobre registro civil pode fazer da morte
   um evento de cadastro, e não um `game over`).

---

## 6. Definição de pronto (todas as fases)

1. `--headless --quit` sem erro **e sem warning**.
2. Captura gerada pela flag da fase e comparada com a referência.
3. Todo número de estética cita a seção do UI-BIBLE ou do ART-BIBLE.
4. Tipagem estática completa, sem `Variant` implícito.
5. Commit diz o que mudou **e por quê**.
6. *(novo nesta frente)* Nenhum retângulo de UI cruza outro — provado por
   `checar_hud.gd`, não por olhar.

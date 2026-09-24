# PLANO HUD AAA — HUD, objetivo, pause e inventário numa linguagem só

> 22/09/2026 · referência: GTA V, RDR2, Cyberpunk 2077, Skyrim, TLOU
> Contrato: `UI-BIBLE.md` §6.8 · código: `game/src/ui/hud/` · teste: `tests/checar_hud_aaa.gd`

## 0. Diagnóstico — por que o HUD não parecia AAA

| sintoma na tela | causa |
|---|---|
| "-1-2" embaixo do minimapa | coordenada de **quadra** (`minimapa.gd:165`): verdadeira, mas não casa com nada que o jogador vê na rua |
| faixa do rodapé "feia" | papel bege + bitmap de 11 px na camada 100, sob grão e vinheta; centrada à força porque o canto, na 100, é multiplicado por zero |
| dois jogos na mesma tela | pause/inventário/conversa/iWeed já eram sans + painel frio (RE7); o HUD de rua ainda era papel e bitmap |
| objetivo que some | o cartão encolhia para tira e saía dentro de casa, justo onde "fale com o dono" acontece |
| minimapa que não orienta | norte fixo para cima; alvo sumia assim que saía do cartão |
| "[E]" como texto | o log de terminal dizendo o que apertar; tecla ora antes, ora depois do verbo |
| sinais sem ouvinte | `Inventario.item_recebido` e `espaco_insuficiente` existiam e ninguém avisava |

## 1. Onda 1 — HUD de jogo · **IMPLEMENTADA**

Tudo em arquivos novos em `src/ui/hud/`; ligação mínima em `cidade.gd`, `hud_cidade.gd`,
`hud_iweed.gd` e `mapa.gd`.

```
+----------------------------------------------------------------+
| OBJETIVO            [  BUSSOLA  ]                     [RADAR]  |
| A CASA DA FUMACA 1/3                                  [     ]  |
| Marque a casa...                                      [     ]  |
| <> 140 m                                         R. DA SAUDADE |
| [M] abre o GPS                        TERRENO BALDIO 22:43 NEB. |
|                     NOVA MISSAO                        avisos   |
|                   A CASA DA FUMACA                     avisos   |
|                  [E] Ligar o motor [F] Sair            avisos   |
| [iWeed: entrega]                                                |
| + vida  ≈ fôlego  lanterna ▮▮▮  PROCURADO                       |
+----------------------------------------------------------------+
```

| peça | arquivo | inspiração | o que faz |
|---|---|---|---|
| tokens e primitivas | `hud_tema.gd` | — | cor, corpo, tempo; texto com sombra, véu esfumado, tecla desenhada, losango de objetivo |
| layout puro | `hud_layout.gd` | — | posição de toda peça; empilhamento do objetivo; tecla antes do verbo; o que cabe no prompt e no banner |
| rastreador de objetivo | `hud_objetivo.gd` | Cyberpunk, RDR2 | título + etapa, objetivo (até 3 linhas), distância, dica com teclas nos primeiros 12 s; "NOVO OBJETIVO" ao mudar; "OBJETIVO CUMPRIDO" riscado e sai; **fica dentro de casa** |
| bússola | `hud_bussola.gd` | Skyrim, Cyberpunk | rosa em PT (N, NE, L...), losango da missão e ponto do destino GPS com distância; presos na ponta com seta quando fora |
| radar | `hud_radar.gd` + `Mapa.Estilo.RADAR` | GTA V | paleta escura, **gira com o olhar** sem redesenhar (gira o nó), norte no aro, alvo preso na borda, zoom abre com a velocidade do carro, amigos em azul |
| bloco de lugar | `hud_radar.gd` | GTA, Cyberpunk | **nome da rua** (`NomesDeRua.rua_perto`) · bairro · hora · tempo — substitui o "-1-2" e a faixa do rodapé |
| vitais contextuais | `hud_estado.gd` | RDR2, TLOU | vida (quando cai; fixa e pulsando abaixo de 40%), fôlego (enquanto não está cheio), lanterna com 4 gomos de bateria, selo PROCURADO |
| prompt | `hud_prompt.gd` | todos | tecla desenhada **sempre antes do verbo**, vira botão do controle (`Controle.dispositivo`) |
| avisos | `hud_avisos.gd` | GTA, Skyrim | item recebido com ícone e "+N" somando, bolsa cheia, dinheiro ±R$ |
| banner | `hud_avisos.gd` | GTA "mission passed", Skyrim | NOVA MISSÃO / MISSÃO CUMPRIDA / lugar com nome próprio (parques) |
| rádio | `hud_avisos.gd` | GTA | nome e dial da estação ao trocar, na cor dela |
| vida baixa | `hud_avisos.gd` | TLOU, GTA | vinheta vermelha pulsando nas bordas abaixo de 30% |
| porteiro | `hud_aaa.gd` | — | camada 160; sai com fade quando pause, celular, GPS, terminal, documento, diálogo ou foto abrem |

Medido: `checar_hud_aaa.gd` 644/644 (nenhuma peça cruza outra em 80, 100 e 120%,
piores textos cabem, todo prompt real cabe sem perder tecla, banners cabem).
`checar_hud.gd` segue verde (807 asserções).

## 2. Onda 2 — HUD profundo · **IMPLEMENTADA** (o que resta está no fim)

| # | item | arquivo | estado |
|---|---|---|---|
| 2.1 | **Marcador 3D no mundo**: losango com distância sobre o alvo, com anel que respira; some nos últimos metros e na borda da tela; a bússola deixa de repetir a distância quando ele está na tela | `hud_marcador.gd` | feito |
| 2.2 | **GPS curva a curva**: pílula embaixo da bússola, "↱ 51 m AV. PAULISTA", "SIGA EM FRENTE", "FAÇA O RETORNO", "DESTINO"; função pura testada | `hud_navegacao.gd`, `hud_bussola.gd` | feito |
| 2.3 | **Painel do carro** na tipografia e no branco do HUD; avisos param acima do mostrador ao dirigir | `painel_carro.gd` | feito (bancada 8/8 nos dois presets) |
| 2.4 | **iWeed** com painel, sombra, cores e opacidade do HUD; notificação em 150 px no vão entre objetivo e lugar, até 3 linhas | `hud_iweed.gd` | feito |
| 2.5 | Banner espera a notificação do iWeed sair (não dividem o topo) | `hud_avisos.gd` | feito |
| 2.9 | **Blips vetoriais** no radar e no mapa (casa, mercado, bar, orelhão, parque, fumaça), sempre em pé | `HudTema.blip` | feito |
| — | **Polimento 4K**: polígonos com borda suavizada, círculos com AA, sombra suave em pílulas, avisos e aro do radar, bordas do radar esfumadas | `HudTema.poligono/sombra` | feito |

| 2.6 | **Segurar TAB expande o HUD** (RDR2): toque abre o inventário, segurar 0,3 s mostra tudo — mesmo no modo mínimo ou desligado — com a linha "DIA 1 · R$ 1.250" | `PausaHub`, `HudConfig.expandido` | feito |
| 2.7 | **Feed da sessão** (entrou, saiu, chat) na fonte e sombra do HUD, na faixa livre da coluna esquerda (`HudLayout.FEED`); some com AVISOS desligado | `painel_online.gd` | feito |
| 2.10 | **Legenda de cena** no branco e no painel do HUD; quem fala na cor de destaque; fora de cena ela não sobe mais para cima do prompt | `cinematica.gd` | feito |
| 2.11 | **Contador de dias**: `Relogio.dia` conta a virada nos três caminhos (tempo, desmaio, acerto do servidor em rede, sem mudar o protocolo); dia 1 é sexta; vai no save; "SEX 22:43" no bloco de lugar e "DIA 1 · SEX 22:43" no rodapé da pausa | `relogio.gd`, `save_game.gd` | feito |

| 2.8 | **Botões de controle desenhados**: Xbox (A verde, B vermelho, X azul, Y amarelo; ombro LB/RB, gatilho LT/RT de topo redondo, analógico com anel, View/Menu) e PlayStation (✕ ○ □ △, L1/R1/L2/R2, Create/Options) pelo nome do SDL; na dica do objetivo, no prompt, nas abas e no rodapé da pausa ("WASD" vira analógico, "Z X" vira L2 R2); o mapa da pausa ganhou zoom nos gatilhos e recentrar no Y | `hud_glifos.gd`, `HudLayout.glifo` | feito |

## 2b. Acabamento · **FEITO** (23/09)

| item | o que era | o que ficou |
|---|---|---|
| fundo do objetivo | o véu esfumava da esquerda para a direita e embaixo: a tecla da dica e o "1/3" pousavam sem fundo na névoa | véu cheio por baixo da coluna inteira, esfuma só depois dela (`OBJETIVO_FOLGA/ESFUMA/PENA`); a dica cabe inteira no trecho cheio |
| fundo do lugar | mesmo defeito do lado direito; "NEBLI..." cortado no meio | véu da borda da tela até a linha mais larga; a linha 2 perde uma parte **inteira** (o tempo primeiro, a hora nunca) — `HudLayout.linha_de_lugar` |
| rodapé da pausa no PS1 | a vinheta do pós comia a primeira dica e a hora nos cantos | só o rodapé sobe para `CAMADA_ACIMA_DO_POS`, e sai quando documento/celular abrem por cima |

Medido: `checar_hud_aaa.gd` 784/784 (famílias de controle, todo botão do mapa de
teclas tem desenho, larguras de botão, linha de lugar); capturas do objetivo em
Xbox e PS, da pausa com controle e do HUD e da pausa no PS1.

## 3. Onda 3 — Pausa em abas · **IMPLEMENTADA**

`src/ui/hud/pausa/`: `PausaHub` + uma classe por aba. ESC abre (na última aba), TAB
abre no INVENTÁRIO, Q/E ou LB/RB trocam de aba, ESC com submodo aberto volta em vez de
fechar. Camada 112 (acima da prancha e do véu do `UIManager`); o HUD sai sozinho porque
o hub entra na pilha do `UIManager`.

| aba | o que tem |
|---|---|
| MAPA | `Mapa` em PÁGINA com a opção `escuro` (paleta e blips do radar): WASD/arrastar move, Z/X/roda dá zoom, ENTER/duplo clique marca destino e traça a rota no GPS (de novo em cima desmarca), H volta ao jogador; painel com destino, distância a pé, missão e legenda |
| MISSÕES | missão com etapas (feitas riscadas, atual com losango e dica, futuras apagadas) e agenda do iWeed; ENTER traça a rota até o selecionado |
| INVENTÁRIO | grade 4×2 com ocupação, item grande com tipo e descrição, vida; ENTER usa, X examina (documento abre o documento; o resto, a inspeção 3D da Onda 3) |
| PERSONAGEM | retrato 3D do próprio boneco em luz de estúdio (SubViewport no triplo da resolução, MSAA 4×), A/D gira; ficha, estado, PROCURADO, saldo e extrato |
| SISTEMA | duas colunas: continuar, carregar (cartões de save RE7), imagem, som, HUD, exibição e peças do HUD, sair (pede confirmação) |

A prancha antiga continua montada só para as capturas que a abrem direto
(`--ver-pausa`, `--abrir-inventario`); ESC e TAB não chegam mais nela. Provado por
entrada de verdade: `--pausa-teclas` injeta ESC, Q, S, S, ENTER, ESC, ESC e confere
cada estado.

## 4. Onda 4 — Opções de HUD e acessibilidade · **IMPLEMENTADA**

Pause › SISTEMA (e Opções do título, e o menu de sistema da prancha) › **HUD**, com três
páginas. Chaves em `HudConfig`, arquivo próprio `user://hud.cfg`.

| página | linha | valores |
|---|---|---|
| HUD | HUD | COMPLETO · MÍNIMO (ação, avisos, vitais, painel do carro) · DESLIGADO |
| | TAMANHO | 80% a 120% — cada peça cresce do próprio canto; texto reflui para não cruzar |
| | OPACIDADE | 40% a 100% |
| | CONTRASTE ALTO | véu e painéis mais fechados, texto secundário em branco cheio |
| | DESTAQUE | FERRUGEM · AZUL · AMARELO (daltonismo): objetivo, bússola, radar, rota e marcador trocam juntos |
| EXIBIÇÃO | VITAIS | QUANDO MUDAM · SEMPRE · DESLIGADOS |
| | AVISO DE DANO | TUDO · SÓ CLARÃO · SÓ ALARME · NENHUM |
| | DICA DE TECLAS | liga/desliga |
| | RADAR | GIRA COM O OLHAR · NORTE FIXO |
| | MARCADOR NO MUNDO | liga/desliga |
| | GPS CURVA A CURVA | liga/desliga |
| PEÇAS DO HUD | uma chave por peça | objetivo, bússola, radar, lugar e hora, avisos, banners e rádio, ação na tela, iWeed, painel do carro |

Medido: `checar_hud_aaa.gd` 739/739 — layout em 80, 100 e 120%, modos, páginas cabendo
nos dois menus, próxima manobra do GPS, avisos acima do painel ao dirigir, dias.

## 4b. Onda 5 — convite, chegada, legenda e controles · **IMPLEMENTADA** (23/09)

| item | arquivo | o que faz |
|---|---|---|
| **Pontos de interação** (TLOU, RE) | `hud_pontos.gd` | ponto discreto sobre todo `Interativo` habilitado a até 6,5 m, visível da câmera e na frente dela; o alvo atual ganha anel na cor de destaque; em gente sobe ao peito. Ficam de fora carro, pedestre (dezenas na rua; o convite do carro já é o prompt) e face de prateleira. Uma consulta de esfera e até 8 raios a cada 0,15 s. Opção EXIBIÇÃO › PONTOS DE INTERAÇÃO, e segue a chave AÇÃO NA TELA |
| **Chegada do GPS** | `HudNavegacao.vigiar_chegada`, `HudAAA._vigiar_chegada` | banner "VOCÊ CHEGOU" com o nome do destino, som, e a rota apagada; raio de 10 m a pé e 22 m de carro; só arma depois de o jogador ter estado longe (marcar a esquina onde já se está não dispara) |
| **Legendas configuráveis** | `HudConfig.linhas_legenda`, `cinematica.gd` | página LEGENDAS (pausa › SISTEMA e Opções do título › HUD): tamanho PEQUENA/MÉDIA/GRANDE (9/11/14), fundo LEVE/FECHADO, QUEM FALA liga/desliga. Não some com o modo do HUD: com o HUD desligado a fala continua tendo de ser lida |
| **Tela de controles** | `hud_controles.gd`, `PausaAbaSistema` | pausa › SISTEMA › CONTROLES: 14 ações com a tecla e o botão desenhado, lidos do `InputMap` e de `Controle.LIGACOES` (nada digitado duas vezes); a coluna do aparelho em uso acesa, família Xbox ou PlayStation no cabeçalho |

Medido: `checar_hud_aaa.gd` 833/833 (vigia de chegada em cinco casos, toda ação
com tecla e botão, só o GPS sem botão, tabela cabendo na coluna, página LEGENDAS
cabendo nos dois menus, pontos seguindo a ação na tela). Capturas: casa e casa
da fumaça com pontos, controles em teclado e PS, legenda grande, "VOCÊ CHEGOU"
pelo caminho real (`--hud-chegada` anda o jogador até o destino e o GPS se limpa).

## 5. O que ficou de fora de propósito

- **Indicador de ruído/furtividade**: `Player.nivel_de_ruido()` existe, mas o cabeçalho de
  `radio.gd` pede explicitamente que perigo não tenha indicador visual.
- **Munição e arma equipada**: não há arma equipável nem tiro no jogo hoje.
- **Fome/sede/sono, combustível, dano do carro**: não existem como sistema.

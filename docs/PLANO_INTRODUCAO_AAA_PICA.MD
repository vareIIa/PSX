# PLANO — Introdução AAA: "Gente, não vou"

Conceito: **quem hesita, fica.** Ele apaga a desculpa (decide ir). Um padre surge na
estrada, o carro vai para a mata e, na confusão, o dedo manda a mensagem apagada pela
metade: **"Gente, não vou"**. Ele acorda na frente da igreja e a cidade responde:
*"Ele trouxe mais um."*

Rima central: "Eu que não queria vir." (estrada) ↔ "Ele trouxe mais um." (praça).
Regra de voz: ele fala do concreto (sangue, bolso, rádio), nunca nomeia o medo; nenhuma
legenda narra a imagem.

## Linha do tempo geral

| Trecho | Hoje | Proposta |
|---|---|---|
| Estrada | 66,9 s até o preto + ~8,7 s sem imagem | ~62 s até o branco, nenhum quadro preto |
| Branco | — | 2,6 s (elástico até 4,5 s), com respiração |
| Praça | levantar em prancha, joelho quebrado, legenda sangrando no corte | ~39 s, 9 takes |
| Cidade | blitz, mercado, casa; protagonista fora de quadro ~49 s | ~42 s, ele sempre em quadro |
| Total até o controle | 2 min 54 s a 3 min 35 s | ~2 min 25 s |

Ordem nova da estrada: PASSAGEM 0–9,4 · AÉREA 9,4–20,8 · MATA 20,8–29,8 · POÇA 29,8–35,8 ·
RASANTE 35,8–43,35 · DENTRO 43,35→.

## PARTE A — O BANG (três golpes em 7 s)

**Status (23/09): implementada.** `abertura_estrada.gd` (`_plano_dentro`, `_golpe_na_estrada`,
`_plano_romeiros`, `_guiar_a_guinada`, `_bater`), `BrancoDoSusto`, sons em
`tools/gerar_audio_susto.py`. Medido no percurso inteiro: golpe 55,3 s, batida 57,4 s,
branco 62,2 s. Bancada: `-- --ver-estrada --estrada-corrida [--estrada-desde=dentro]
--susto-fotos=<pasta>` grava um quadro por beat. Fora do plano original: a trinca é uma
lâmina própria na cabine (o vidro da cabine não trinca) e o colo recebe o telefone na pausa
para a estrada aparecer.

| t (s) | Plano | Imagem | Som |
|---|---|---|---|
| 6,0 (opc.) | Passagem | num relâmpago, só um colarinho branco entre as árvores, >12 m, some no corte | trovão |
| 43,4 | Dentro | "Faz uma semana que eu acordo pensando em desmarcar." Cabeça desce (48,65), celular abre (49,30). Grupo: "Chegamos!! Frio do cão" / "Cadê vc??" / "Vc vem mesmo né?" (Hoje 22:38) | chuva na cabine |
| 51,9 | Polegar | apaga letra a letra e TRAVA em "Gente, não vou" (14 letras, trava dentro de AppMensagens); pausa 1,1 s | tique por letra, afinação 1,00→1,08 |
| 53,8 | O padre | no facho, parado no meio da pista: mãos caídas, cabeça inclinada, rosto de cera, batina gasta. O público vê antes do personagem. O limpador passa por cima dele | vácuo começa 0,6 s antes do T0 |
| **54,9** | **GOLPE 1 (T0, s≈1077)** | celular 2D arrancado; zoom 66→28° em 0,12 s, volta a 32°; tremor 0,8; relâmpago no mesmo quadro | estouro; abafado solta em 0,05 s |
| 54,9–55,85 | Guinada | volante −90°; cabeça presa no padre enquanto o carro gira; estala para a frente; padre sai pela borda | pneu, galhos |
| 55,85–56,85 | Romeiros (1,00 s) | corte externo com a lente do plano MATA (44°, 1,5 m); 6–8 figuras de roupa gasta entre troncos e moita; relâmpago MUDO 2 quadros; criança de mão dada; a mais próxima vira a cabeça nos últimos 4 quadros | coro baixo, cortado seco |
| **~57,0** | **GOLPE 2** impacto | tronco cresce no farol 0,18 s, tranco 9 cm, para-brisa trinca, farol pisca 7,5→0→5→0→3,5, motor morre, luzes vermelhas de bateria/óleo | batida, trinca |
| 57,5–58,5 | Calma falsa | mata vazia no farol fraco, carro assenta 2,5°; limpador segue (metrônomo) | respiração |
| 58,5–59,85 | Banco | celular vibra; mão entra pela borda de baixo (≥0,30 m da lente); dedo encosta; escorrega | "mensagem enviada" |
| 59,85–61,2 | Assoalho | debruça (olho (-0,12;1,00;0,02), yaw −42, pitch −56, FOV 60→44); poça de luz da tela no tapete; "Gente, não vou" — Entregue 22:44; cinto trava a mão | vibração |
| 61,2–61,66 | Trinco | maçaneta do motorista puxada duas vezes (som antes da imagem); limpador para; chicote 0,16 s para a janela | trinco 3D |
| 61,66–61,96 | Janela | revelação MUDA 0,30 s: padre curvado, palma no vidro, olho sem piscar, reza muda, luz vermelha de baixo | silêncio |
| **61,96** | **GOLPE 3** | tapa no vidro + estouro + BRANCO no mesmo quadro | mundo cortado em 10 ms; zumbido, coração, respiração + segunda respiração calma à esquerda |

## PARTE B — Praça

Joelho: neste esqueleto a canela dobra para trás com ângulo NEGATIVO (caminhada, sentado
−1,30, parede −0,72). `_pose_levantando` usa +1,65/+1,20 e `_pose_deitado_acordar`
+0,55/+0,48 → joelho quebra para a frente. Além disso o nó inteiro gira como prancha e
o corpo boia a 0,68 m; o conserto de verdade é o `LevantarDoChao`.

| t (s) | Take | |
|---|---|---|
| 2,6–5,0 | Céu | branco esfria até o cinza, duas piscadas, 1ª badalada abafada |
| 5,0–9,4 | Joelhos (1ª pessoa) | apoia nos cotovelos; cruz e torre entre os joelhos; plateia parada no adro |
| 9,4–10,2 | Queda | piscada preta 0,1 s |
| 10,2–14,8 | Zenital | "Bati numa árvore. Cadê o sangue?" + medalha do santinho de cordão arrebentado ao lado da mão |
| 14,8–18,6 | Rosto, mudo | olhos abrem; 8 quadros do rosto do padre com grão |
| 18,6–22,4 | Levantar | LevantarDoChao, câmera de grua subindo junto |
| 22,4–26,6 | Tontura | "Esse rádio não é meu." |
| 26,6–30,8 | Cadê | latidos, cabeça vira, dois moradores se benzem; "Cadê o carro? Cadê a mata?" |
| 30,8–39,2 | Igreja | "Era um padre. Na minha janela." / MORADORA: "— Ele trouxe mais um." / 2ª badalada fora de hora |

## PARTE C — Cidade

| Cena | |
|---|---|
| Adro | câmera atrás das nucas da plateia, que viram juntas; sirene ao longe (substitui a blitz); "Ninguém nem pergunta se eu tô bem." |
| O som | funk da casa da fumaça; "Pelo menos alguém tá acordado." |
| Poste | "Tava no chão do carro. Tá no meu bolso." |
| Celular 1ª pessoa | LUCAS "??", MARI "Não vai o quê", LUCAS "Kkkk desistiu né"; ele manda "Eu tô aqui" → Não Entregue; "Sem serviço" e chega MARI "Tá bom. Fica aí então."; "Logo essa que foi."; figura de 1 s na névoa, some na piscada, rádio para de uma vez |
| Decisão | "Alguém ali vai ter que me explicar."; cartão da missão; GPS 1,5 s depois |

Saem: mercado, blitz (vira sirene), falas avenida_2, mercado_*, poste_2/3.

## Falas da estrada

- passagem: "O pessoal saiu cedo. Eu fiquei enrolando."
- aerea_1: "São Thomé. Todo mundo diz: tem que ir uma vez na vida."
- aerea_2: "Duas horas de terra depois que acaba o asfalto." (mantida)
- mata: mantida
- poca: "A pousada tá paga. Eles já tão lá."
- rasante: "Eu que não queria vir." (mantida)
- dentro_1: "Faz uma semana que eu acordo pensando em desmarcar." (mantida)
- dentro_2 e saida: removidas (viram ação)

## Elenco

- Padre: batina = saia longa com barra a 8 cm do chão, sem lapela (CASACO_BATINA); calça
  por baixo (`saia=false` + `CALCA_SAIA_LONGA`); colarinho = tira branca no TORSO;
  desgaste por altura (receita da Carroceria); cabeça em caixa; olhar por
  `olhar_lateral` (olhar_para usa olhos fixos a 1,58 m).
- Romeiros: chapéu de aba + sobretudo; mulher de saia longa e xale; criança. 12 corpos ≈
  25 ms de montagem: nascem na AÉREA, pré-aquecem debaixo do preto da MATA.
- Falta: mão espalmada, expressão de transe, cabeça inclinada fixa, eyeshine (só no POV da
  cabine, 3–4 quadros).

## Marcos

| # | Marco | Tam. |
|---|---|---|
| M0 | Bancada: `--ver-estrada` sem estrada duplicada, com noite de chuva e relâmpago; flag que começa no DENTRO; prints `[susto]` | P |
| M1 | Joelho: 4 sinais em corpo.gd | P |
| M2 | Falas, conversa, trava em "Gente, não vou", tique das teclas | P |
| M3 | Padre na estrada + golpe 1 + sons (`tools/gerar_audio_susto.py`) | G |
| M4 | Guinada, clareira só no corredor, árvore do impacto, impacto | M |
| M5 | Romeiros de 1 s | M |
| M6 | Banco, queda, envio, assoalho, trinco, janela, branco | G |
| M7 | Branco → praça | M |
| M8 | Praça nova + LevantarDoChao | G |
| M9 | Cidade nova | M |
| M10 | Passe completo + export | P |

Cada marco termina com a abertura rodando inteira; prova por `--shot` com caminho fora do
repo (`--ver-abertura` suja capturas versionadas).

## Ideias

1. Figuras de 1 s três vezes, cada vez mais fracas (mata, plateia, névoa da cidade).
2. A bênção: no T0 o padre ergue a mão e abençoa o carro (extrema-unção).
3. Dobre de finados nas badaladas fora de hora → "ele morreu na árvore?".
4. O iPhone vira 1998: na cidade a tela iOS engasga em estática e vira o LCD verde "Sem serviço".
5. As figuras da mata como contexto da ameaça da Fase 5 (INIMIGO_NA_RUA).
6. "Segure para pular" a abertura a partir da segunda vez.

## Riscos conhecidos

- corpo.gd tem WIP de outra sessão; LevantarDoChao, Rosto, Vestuario, ReacaoCorpo não
  estão versionados.
- Piscina de som com 6 vozes descarta em silêncio: susto/respiração/coração em tocadores
  dedicados. Stinger respeita o volume de efeitos.
- Tremor (h/v_offset) vaza para a Camera3D do Cinema: zerar antes da praça.
- `_som.detalhar()` toca motor_partida; Chuva.abrigo fica 1 na cidade: zerar no desmontar.
- 23:00 faz o sino tocar 11 sozinho; usar 23:15.
- Números herdados de agentes (árvore do impacto, pouso do celular) precisam de sonda antes.

# 14 — Testes e aceite

> **Versão 2.0 — 21/09/2026.** Vale `docs/PADROES-ENGENHARIA.md`. A rede acrescenta os níveis 4 e 5.
> Dizer "funciona" sem dois processos é chute. Dizer "funciona" sem número também.

## 1. Níveis

| Nível | Comando | Prova | Não prova |
|---|---|---|---|
| 1 | `.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --quit` | o projeto abre, o autoload `Sessao` compila | nada de rede |
| 2 | `... --headless --path game --script res://tests/mp/run_tests_rede.gd` | o contrato: formato, saneamento, autenticação, relógio, interpolação, validação, configuração, descoberta (**136 asserções**, ~1 s) | que dois processos conversam |
| 4 | `./tools/mp_teste.sh [--carga=N]` | dedicado real + bots: entrada, recusa com motivo, visão mútua, **erro em cm**, fome, banda, chat, relógio, log sem ERROR | o jogo de verdade (cidade, `Player`, câmera) |
| 4b | `./tools/mp_dois.sh [--foto \| --dedicado]` | duas janelas do jogo: o `Player` manda estado, o boneco aparece com a roupa, o nome, a chegada no relevo | internet de verdade |
| 5 | duas casas, VPN de jogo e depois VPS (`21`) | NAT, perda, *jitter* reais | — |

O nível 3 (captura visual de shader e *look*) é o do projeto, e vale para as fotos de `captures/multiplayer/`.

**Por que o nível 2 só cobre classes puras:** no modo `--script` o Godot não registra autoloads como identificadores, e todo script que cita `Sessao`, `Interiores` ou `RadioCarro` falha ao compilar ali (memória do projeto). Por isso o contrato mora em `ProtocoloRede` e nas outras classes puras, e a `Sessao` só move bytes.

## 2. O bot que mede

`res://scenes/net/bot_rede.tscn` entra num servidor sem tela e anda num círculo de 6 m a 2,4 m/s, como **função pura do índice e da hora do servidor**. Cada bot sabe onde os outros estavam em qualquer instante. O erro medido é a distância entre o boneco desenhado e essa verdade, **no instante que o boneco representa** (`AvatarRemoto.t_desenho`). O número cobre a cadeia inteira: relógio, carimbo, instantâneo, perda e interpolação.

Separações que evitam medir a coisa errada:

- **Aquecimento de 1,5 s** depois de entrar: o relógio ainda converge.
- **Com fome** (o instante desenhado já passou da última amostra mais o teto de extrapolação) é contado **à parte**. Isso mede entrega (processo engasgado, rede), não interpolação. Com 16 Godots em 8 núcleos, o agendador do Windows sozinho produzia "erros" de 80 cm.
- O bot relata o **próprio quadro mais longo**, e o servidor o dele (`quadro mais longo N ms` no log).

Opções do bot:

| Flag | Faz |
|---|---|
| `--bot-entrar=host:porta` `--bot-indice=N` `--bot-duracao=S` `--bot-senha=` | básico |
| `--bot-falar=texto` | manda uma linha de chat 2 s depois de entrar |
| `--bot-centro=x,z` `--bot-raio=` | anda num lugar escolhido, no chão do relevo (para foto; não mede) |
| `--bot-carro=modelo,semente` `--bot-lanterna` `--bot-agachado` | estado de carro, lanterna, agachado (no carro: farol e freio, `20` §3) |
| `--bot-arfagem=graus` | para onde a cabeça e a lanterna apontam (negativo = chão) |
| `--bot-parado` `--bot-giro=graus` | com `--bot-centro`: fica parado num rumo conhecido (foto repetível) |
| `--bot-atraso=S` | pronto (assinatura calculada), espera S segundos e só então liga |
| `--sem-relevo` | a cidade plana: a assinatura muda e o servidor recusa |

Saída: uma linha `[bot] RESULTADO {json}` com estado, recusa, vistos, amostras, erro p50/p95/máx., fome, ping, banda, quadro mais longo, chat ouvido e quanto o relógio andou.

## 3. `tools/mp_teste.sh`: o que confere

Todo bot calcula a assinatura da cidade **antes** de ligar (compila o gerador; ~150 ms de CPU). Calcular ao entrar punha essa carga no meio da medida dos outros: fome de 4,4 % e p95 de 19 cm num cenário que dá 0 % e 0,1 cm (`19` §3b, linha 17).

**Cenário A:** dedicado com lotação 2, três bots (o terceiro nasce junto e liga 3 s depois).

- BOT0 e BOT1 entram e se veem;
- erro p95 ≤ **5 cm** nas amostras com dado;
- fome ≤ **3 %**;
- o chat de BOT0 chega a BOT1 (e volta a BOT0);
- o relógio de cada bot, que não tem HUD, andou ≥ 10 s de jogo só pelos acertos do servidor;
- BOT2 é recusado com "Servidor cheio.";
- o servidor não escreve ERROR.

**Cenário B**, depois de A: dedicado com senha. Senha errada é recusada com "Senha errada."; senha certa entra; um bot com `--sem-relevo` é recusado com "Cidade diferente."; o servidor não escreve ERROR.

**Cenário C** (`--carga=N`, depois de A e B, sozinho): N bots, cada um vê os N−1. Pior p95 e pior fome dentro do teto, e o servidor não escreve ERROR.

A, B e C rodam um depois do outro. Tudo junto eram 16 Godots em 8 núcleos, e o que se media era o agendador.

**Erro no log, com outra frente editando o jogo:** o dedicado compila o gerador da cidade na subida (assinatura), e com ele a árvore de scripts que outra sessão pode estar no meio de editar. Erro de **compilação** num arquivo fora de `src/net/` e `tests/mp/` vira **aviso**, com o nome do arquivo, e não reprova; erro de execução, ou qualquer erro na rede, reprova.

## 4. Números de 21/09/2026 (régua)

Protocolo v1 (Fase 1, tarde) e v2 (Fase 2, noite: estado de 23 B, assinatura da cidade).

| Medida | v1 | v2 |
|---|---|---|
| Nível 2 | 108/108 | **136/136** |
| A: erro p50 / p95 / máx. | 0,03–0,09 / 0,08–0,11 / 0,11–0,18 cm | 0,03–0,09 / 0,04–0,13 / 0,10–0,70 cm |
| C com 8 bots | pior p95 0,10–0,11 cm, fome 0 % (3 rodadas) | pior p95 0,11–0,26 cm, fome 0–0,4 % (4 rodadas) |
| C com 16 bots | pior p95 0,10 cm, fome 0 %, 5,86 KB/s, servidor 35 ms | pior p95 **0,22 cm**, fome 0,4 %, **6,01 KB/s**, servidor 25 ms |
| B: cidade diferente (`--sem-relevo`) | entrava sem aviso | **recusada** com "Cidade diferente." |
| Anfitrião na prancha: relógio do cliente em ~13 s | **2,0 s** de jogo (congelado pelo anfitrião) | **30,0 s** de jogo |
| Lanterna do boneco, chão na frente dele ÷ chão de referência | — (apontava sempre −8°) | −35°: **1,70×**; +30°: 1,16× |
| Dedicado: assinatura na subida | — | 110–154 ms, uma vez |
| Servidor exportado (`NevoaEDither_Servidor.console.exe`) + 2 bots | p95 0,11 cm | p95 0,11–0,12 cm; assinatura na subida em 91 ms; bot com `--sem-relevo` recusado. **A assinatura mudou durante o dia** (`8efc3d95…` → `8c83a469…`) porque outra frente mexeu no relevo: é a trava funcionando, e é por isso que servidor e cliente precisam sair do mesmo commit |
| Servidor, 8 jogadores | 0,5 % de um núcleo, 261 MB | ⏳ |
| Duas janelas, convidado entra no anfitrião na praça | chegou a 1,6 m, no chão (y 0,16), olhando para ele | — |
| Dedicado + janela do jogo | chegou no chão do vale do relevo (y −16,25; o terreno ali está em −17,6) | — |
| Solo, boot headless | sem erro nem aviso além do vazamento de 94 objetos | idem (com a árvore das outras frentes compilando) |

Uma regressão que piore qualquer linha acima precisa de explicação no commit.

## 5. Capturas

```
captures/multiplayer/
  convidado_ve_anfitriao.png            ✅ praça, anfitrião de costas, nome tapado por galho
  anfitriao_ve_lanterna_e_carro.png     ✅ (v1) bot a pé em frente ao portão, Marea atrás do muro
  anfitriao_ve_carro_e_lanterna.png     ✅ (v2, `mp_dois.sh --carro`) câmera presa na praça: amigo a pé com a poça
                                           da lanterna no chão, carro do outro de farol aceso e facho na névoa,
                                           nomes, dois pontos azuis no minimapa
  lanterna_do_amigo_baixo_e_cima.png    ✅ a mesma cena com a lanterna a −35° e a +30° (a medida de 2.8)
  agachado.png                          ⏳ falta
  painel_f7.png                         ⏳ falta: a folha aberta com a lista
  interior_dois.png                     ⏳ dois no mesmo interior se veem; em interiores diferentes, não
  carro_passageiro.png                  ⏳ Fase 4
```

`mp_dois.sh --foto` e `--carro` só gravam em `captures/multiplayer/` (memória do projeto: `--ver-abertura` suja capturas alheias; estes modos não a usam). A foto de cena usa **câmera presa** (`--olhar-igreja=x,z,alvo_x,alvo_z,alvo_y`) e **bots parados** (`--bot-parado`): com `--ir-para` o anfitrião foi empurrado 17 m por pedestre numa rodada, e o carro em círculo saía do quadro.

## 6. Regressão solo, sempre

Depois de toda mudança na rede:

```
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --quit
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/mp/run_tests_rede.gd
./tools/mp_teste.sh
```

E, quando a mudança tocar arquivo do jogo (Fase 2 em diante), também a suíte do projeto (`tests/run_tests.gd`) e um `--pular-menu --pular-abertura` com captura, comparados com o HEAD.

## 7. Aceite por fase

As listas de aceite estão em `13_FASES.md`, fase por fase. O aceite do produto está em `17_CHECKLIST.md`.

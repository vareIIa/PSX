# Estado da introdução da estrada (24/09, fim do dia)

Branch `claude/estrada-etapas-2-9-v3silv`. O trabalho da rodada 2 está no
commit seguinte ao `85d2e49`. Tudo foi julgado em 4K, com fotos e rajadas.

## Como a cena toca agora

Os tempos contam do começo do plano de dentro (`--estrada-desde=dentro`). Antes
dele vêm os planos de fora: passagem, aérea, mata, poça e rasante.

| tempo | o que acontece |
|---|---|
| 0–6 s | Dirigindo à noite na chuva, celular na mão, o grupo "Bonde São Thomé" aberto. Ele escreve a desculpa. |
| 6,4 s | A conversa: ele apaga a desculpa sem mandar. |
| 12,9 s | A trava: o padre no farol. |
| 14,8 s | O golpe de direção. |
| 15,9 s | Os romeiros encapuzados na beira da pista. |
| 17,0 s | A batida na árvore. O para-brisa trinca e o celular voa para o chão. |
| 17–23 s | Ele se abaixa e pega o celular do chão. O braço não atravessa mais o banco. |
| 23,7 s | O fogo começa no capô, com a fumaça preta. Abre uma conversa do "?". |
| 24–30 s | **As mensagens do "?"** (detalhe abaixo). O celular vai entrando em pane e as batidas em volta do carro crescem. |
| ~31 s | O trinco puxa duas vezes. Chega "Olha pra mim.". |
| ~32,2 s | **O celular morre.** O cerco para de uma vez. |
| 32,2–33,2 s | 0,55 s de silêncio, e ele vira para a janela. |
| 33,2 s | O padre está no vidro do motorista, sorrindo. |
| 34,6 s | **As mãos** batem no vidro três vezes, dos dois lados do rosto dele, e a lente tranca a cada batida. |
| 35,8 s | **O vidro estoura**: esfarela inteiro, os grãos caem, e o padre entra pelo buraco. |
| ~36 s | Uma mão fecha no pescoço e a outra vem na cara. |
| 36,6 s | O puxão, e a tela fica branca. |

Depois do branco a cena é da outra sessão (acordar na praça/igreja).

## As mensagens

A primeira coisa que chega é a desculpa que ele **apagou e nunca mandou**:

> Gente, não vou conseguir ir.
> Mentira.
> Você veio.
> Todo mundo vem uma vez na vida.
> O Lucas e a Mari já estão aqui.
> Abre a porta.
> *(o trinco puxa duas vezes)*
> Olha pra mim.

- Entre as mensagens aparece o balão de "digitando…". O recado inteiro leva
  ~5 s (antes, ~9 s).
- A cada mensagem:
  - a tela dá um tranco de pane: rasgo, cor separada, blocos, chuvisco, tela
    apagando e texto se corrompendo;
  - toca o zumbido GSM;
  - as batidas de mão na lataria e nos vidros ficam mais frequentes e mais
    altas.
- As batidas vêm de 12 pontos em volta do carro, em som 3D. A janela do
  motorista não está entre eles: ela fica para o padre.
- No "Olha pra mim." o aparelho apaga e tudo fica em silêncio.

## Capturas

| arquivo | o que mostra |
|---|---|
| [01_estrada_ate_o_chao.jpg](capturas/01_estrada_ate_o_chao.jpg) | da estrada à batida e ao celular no chão |
| [02_rajada_pegando_o_celular.jpg](capturas/02_rajada_pegando_o_celular.jpg) | o braço descendo e voltando, rente ao banco |
| [03_mensagens_e_pane.jpg](capturas/03_mensagens_e_pane.jpg) | "digitando…", o recado e a pane crescendo |
| [04_rajada_celular_morre.jpg](capturas/04_rajada_celular_morre.jpg) | o aparelho apagando e a virada para a janela |
| [05_padre_quebra_e_agarra.jpg](capturas/05_padre_quebra_e_agarra.jpg) | as palmas, o vidro esfarelado, as mãos vindo, a agarrada |
| [06_rajada_ataque_ate_o_branco.jpg](capturas/06_rajada_ataque_ate_o_branco.jpg) | o ataque inteiro, quadro a quadro, até o branco |

## O que foi feito na rodada 2

| pedido | estado |
|---|---|
| Padre quebrando o vidro de novo depois do branco | **Não reproduzi.** Fechei as duas portas possíveis mesmo assim: no branco a estrada some e o som do fogo para, e uma estrada não roda duas vezes. Se voltar a acontecer, preciso saber como você rodou: pelo menu? com que flags? |
| Braço atravessando o banco ao pegar o celular | Corrigido. Medido: de 916 vértices a 6,8 cm dentro do assento para 0. |
| Mensagens mais aterrorizantes | Corrigido. Veja o texto acima. |
| Padre quebrando e agarrando mais forte | Corrigido: três batidas, vidro temperado esfarelando, entrada pelo buraco, agarrada e puxão. |
| Cena das mensagens mais rápida | Corrigido: ~5 s em vez de ~9 s. |
| Celular entrando em pane com as mensagens | Corrigido. |
| Batidas no carro crescendo com as mensagens | Corrigido: de -14 dB e ~1 por segundo até ~0 dB e ~10 por segundo. |
| Gotas de chuva em cima do celular (achado meu) | Corrigido. |
| **FPS baixo na batida e no chão** | **Corrigido**: de 13–16 ms para 8,6–8,7 ms de GPU por quadro (tabela abaixo). |

## Desempenho (4K, RX 9070 XT, tempo de GPU por quadro)

| trecho | antes | agora |
|---|---|---|
| antes da batida (referência) | 7,3 ms | 7,5 ms |
| batida → pegar o celular | 13,3 ms | **8,6 ms** |
| fogo e mensagens | 16,3 ms | **8,7 ms** |
| janela | 13,6 ms | 7,7 ms |
| mãos e estouro | 15,5 ms | 9,4 ms |

A cena inteira roda a ~110 fps em 4K. Os quadros acima de 33 ms depois do
começo caíram de 7 para 1.

O que pesava:
- **A fumaça preta no chão.** Quando ele desce para pegar o celular, a lente
  fica dentro da fumaça, e ela custava 14,6 ms de um quadro de 21 ms. O ruído
  dela agora vem de uma textura 3D, com o mesmo desenho, medido. Custa 2,4 ms.
- **O engasgo de 81 ms quando o celular sobe.** Era a primeira vez que cada
  letra da tela era gerada. As letras e o aparelho agora são preparados no
  preto do começo.
- **O engasgo da travada do padre** (173 ms no começo da rodada, depois 33 ms).
  Era a revoada de fumaça nascendo naquele quadro. Agora ela nasce no começo.
- **Auras acendendo todas no mesmo quadro**, quando o padre e os cinco vão
  para a janela. Agora acendem uma por quadro.
- **O quadro da batida:** a trinca custava 28,5 ms e agora custa 0,4 ms.

O que sobra: um quadro de ~35 ms aos 24,8 s, quando a conversa do "?" abre e o
padre vai para a janela. Os mais comuns são picos soltos de 20–25 ms, inclusive
onde não acontece nada, e parecem ruído do sistema.

## Coisas que vi e você não pediu

- As gotas no vidro lateral parecem plástico-bolha: redondas, iguais e densas
  demais.
- Riscos pretos longos no ar, nos planos de fora.
- O quebra-sol tem a borda em escada.

## Arquivos

- `INTRO-PADRE/HANDOFF.md`: o prompt para colar numa sessão nova, com mapa do
  código, comandos e pendências.
- `INTRO-PADRE/ESTADO.md`: este arquivo.
- `INTRO-PADRE/capturas/`: as 6 imagens acima.

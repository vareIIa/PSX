# 12 — Introdução com os dois

> Fase 5. O pedido original: “dois personagens aparecendo no carro na introdução”, “os dois desde o começo”.
> Cinema travado no host (P10). Roteiro no plural.

## 1. O que a intro é hoje

Ordem canônica (`PROGRESSO.md` + `cidade._rodar_abertura`):

```
carteira no banco → Estrada Velha → blackout → acordar na praça → jogar
```

### Estrada Velha — `abertura_estrada.gd`

| Plano | Duração | Câmera | Ocupante hoje |
|---|---|---|---|
| 1 PASSAGEM | 9 s | beira, carro vem de longe | nenhum |
| 2 AEREA | 12 s | acima da copa | nenhum |
| 3 RASANTE | 8 s | farol, mato rente | nenhum |
| 4 DENTRO | 23 s | cabine, HUD off | nenhum (cabine vazia) |
| 5 SAIDA | ~ | afasta na névoa | nenhum |

Falas atuais (`FALAS`):

```
passagem:  "A gente marcou essa viagem faz uns dois meses."
aerea_1:   "São Thomé das Letras. Todo mundo dizia que eu tinha que conhecer."
aerea_2:   "Duas horas de terra depois que acaba o asfalto."
rasante:   "Eu que não queria vir."
dentro_1:  "Sem maldade, essa estrada não parece ter fim."
dentro_2:  "Faz uma semana que eu acordo pensando em desmarcar."
dentro_3:  "Cheguei a escrever a desculpa no celular. Não mandei."
dentro_4:  "Mas a pousada já tava paga e o pessoal já tava vindo."
saida:     "Aí eu peguei o carro e vim."
```

Já há “a gente” e “o pessoal”. O singular quebra a imagem de dois.

### Praça — `abertura.gd`

POV olho no céu → takes externos **deitado** na frente da igreja → avenida → blitz → mercado → casa da fumaça → poste → 1P, bituca, GPS, missão.

Um corpo. Camera de cinema. `Cinema.fechar_de_imediato` na emenda.

## 2. O que “desde o começo” significa

Não é “no plano 4 a gente coloca o passageiro”. É:

- **Plano 1**, para-brisa / silhueta: duas cabeças.
- **Plano 2**, aérea: dois no habitáculo (pixel, mas dois).
- **Plano 3**, rasante: perfil motorista + passageiro no vidro.
- **Plano 4**, dentro: dois corpos sentados, poses de banco, falas em diálogo.
- **Plano 5**: os dois ainda lá quando a névoa engole.

Se o plano 1 mente (um boneco), o resto é DLC.

## 3. Trabalho de cena (não é rede)

1. `_pose_volante` e `_pose_passageiro` em `corpo.gd` (compartilhar com Fase 4).
2. `CarroCena` instancia dois `Corpo` com as aparências do roster. Host = −X, convidado = +X.
3. Cabine ligada também nos planos **externos o bastante para ler ombro/cabeça** — hoje ela desliga fora do DENTRO porque atravessava o para-brisa. Precisa de um modo “ocupantes visíveis, cabine interna off” nos planos 1–3: só os dois `Corpo` + lataria, sem espelho/limpador.
4. Farol / vidro: o rasante já é o plano que mostra o perfil. Medir com captura, não a olho.

## 4. Trabalho de rede

Host:

```
plano_de_cinema { cena: "estrada", plano: PASSAGEM, t: 0 }
```

em cada corte (e no start). Cliente:

- não chama `AberturaEstrada.executar` com relógio próprio
- aplica o plano, põe a câmera de cinema `current`, trava o player local

Os dois processos montam o `MundoEstrada` em Y=4000 **localmente** (é B, seed da estrada já é constante `SEMENTE := 4410` no `CarroCena`). O carro no trilho: host manda `distancia` (C, ~10 Hz) **ou** os dois avançam com o mesmo `CRUZEIRO` a partir de `t=0` do plano — a segunda é mais simples se o tick do plano é confiável. Preferir **relógio do plano** (os dois integram `CRUZEIRO` desde o `t` do RPC). Se um frame drop dessincronizar 1 m, o cinema perdoa; a fala não.

`Cinema.legenda`: host manda o id da fala no mesmo RPC do plano ou num evento. Os dois mostram o mesmo texto no mesmo instante.

Não: cada um interpola `Cinema.mover` local e o fade não fecha junto.

## 5. Roteiro — proposta de plural

Direção pode recusar o texto; o **plano** exige que a imagem e a pessoa gramatical batam.

```
passagem:  "A gente marcou essa viagem faz uns dois meses."     (já está)
aerea_1:   "São Thomé das Letras. Todo mundo dizia que a gente tinha que conhecer."
aerea_2:   "Duas horas de terra depois que acaba o asfalto."     (já está)
rasante:   "Eu que não queria vir."  →  manter no MOTORISTA, e o PASSAGEIRO:
           "Pois é. Eu que te arrastei."
dentro_1:  "Sem maldade, essa estrada não parece ter fim."       (já está, qualquer um)
dentro_2:  "Faz uma semana que eu acordo pensando em desmarcar." (motorista)
dentro_3:  "Cheguei a escrever a desculpa. Não mandei."          (motorista)
           passageiro: "A pousada já tava paga."
dentro_4:  "E o pessoal já tava vindo."                          (os dois / passageiro)
saida:     "Aí a gente pegou o carro e veio."
```

Legendas: se for diálogo, a tarja pode prefixar o nome (curto) ou não — o jogo hoje não nomeia o narrador. v1: sem nome na tarja, a voz/câmera no plano 4 (olho do motorista vs plano no passageiro) diz quem fala. Um corte de 8 frames no ombro de quem fala, no mesmo `DENTRO_DURACAO`, cabe.

## 6. Praça com dois

Opção recomendada:

1. Cinema compartilhado até o take “deitado na frente da igreja”.
2. Os **dois** corpos deitados, ~1,2 m um do outro, mesma pose (já existe deitar na abertura).
3. POV “abrir o olho”: **cada um** no fade final, 1P do próprio corpo. Um segundo de céu local, depois controle.
4. Missão começa para os dois.

Opção rejeitada na v1: um deita e o outro já está de pé — a simetria da viagem quebra.

Avenida, blitz, mercado, casa da fumaça, poste: cinema ainda travado, os dois assistem. Os corpos podem ficar escondidos (como hoje o da praça some em alguns takes) **desde que** o take externo da igreja os tenha mostrado juntos. “Desde o começo” vale especialmente a **estrada**; a praça precisa dos dois deitados no take icônico (`02_deitado_igreja`).

Poste → 1P: hoje a câmera desce no olho **dele**. Com dois, o cinema acaba no fade e cada processo liga a câmera do seu Player. Não descer a cinema cam em dois olhos.

## 7. `--pular-abertura` e captura

- Solo: igual.
- Coop: `--mp-pular-intro` pula estrada+praça e spawna os dois na praça já de pé, 1,5 m.
- Captura 2P da estrada: dois processos, `--shot`, ou um processo host com o segundo corpo (bot) se a captura headless não aguentar dois Godot. Preferir dois processos — é o aceite real.

Pasta: `captures/multiplayer/estrada_01_passagem.png` … `praca_deitados.png`.

## 8. Aceite da Fase 5

- Plano 1: duas silhuetas no Marea, aparências da carteira.
- Plano 4: dois sentados, poses de banco, diálogo.
- Praça: dois deitados no take da igreja.
- Os dois processos cortam o preto no mesmo segundo.
- Solo: bit-idêntico em falas **se** `Sessao.modo == SOLO` — **manter o roteiro singular no solo**. O plural é ramo coop. Não reescrever a intro de quem joga sozinho.

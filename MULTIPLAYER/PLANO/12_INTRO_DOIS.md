# 12 — A abertura com o grupo

> **Versão 2.0 — 21/09/2026.** Revisado contra o código. A 1.0 era "os dois desde o começo", com cinco planos na estrada. Hoje a estrada tem **sete** planos (62 s), e as falas mudaram de lugar.
> O pedido original continua de pé: **quem começa a viagem junto aparece no carro desde o primeiro plano.** Na v2 isso vale para até **5** (os lugares do Marea), e só para quem começou junto (P10). Quem entra depois não vê abertura nenhuma.
> Fase 7. Depende de `09` (lugares e pose `ASSENTO`) e de `10` §6 (folha de viagem).

## 1. A abertura hoje

```
carteira → Estrada Velha (62 s, cena cortada) → blackout → praça (acordar) → avenida → blitz → mercado → casa → poste → bituca → jogo
```

### 1.1 Estrada Velha (`abertura_estrada.gd`)

`y + 4000` (`ALTURA`, `:130`). O carro é o `CarroCena`, em trilho: `distancia += velocidade / 3,6 · delta` (`carro_cena.gd:406`), a 68 km/h (`CRUZEIRO`) desde `PARTIDA = 40 m`. A câmera é recalculada a cada quadro (`_mover_camera`, `:911`), sem `Cinema.mover`.

| # | Plano | Duração | Fala (`FALAS`, `:355-369`) |
|---|---|---|---|
| 1 | PASSAGEM | 9,0 s | "A gente marcou essa viagem faz uns dois meses." |
| 2 | AÉREA | 11,0 s | "São Thomé das Letras. Todo mundo dizia que eu tinha que conhecer." / "Duas horas de terra depois que acaba o asfalto." |
| 3 | MATA | 9,0 s | "Sem maldade, essa estrada não parece ter fim." |
| 4 | RASANTE | 7,5 s | "Eu que não queria vir." |
| 5 | DENTRO | 13,0 s | "Faz uma semana que eu acordo pensando em desmarcar." / "Cheguei a escrever a desculpa no celular. Não mandei." |
| 6 | POÇA | 6,0 s | "Mas a pousada já tava paga e o pessoal já tava vindo." |
| 7 | SAÍDA | 6,5 s | "Aí eu peguei o carro e vim." |

**O carro está vazio.** `CarroCena` e `CarroCabine` não têm `Corpo` nenhum. No solo, o narrador **é** a câmera: no plano DENTRO, o olho dele é o suporte `Olho` (`carro_cena.gd:198`), e nos planos de fora ninguém procura cabeça no vidro.

### 1.2 Praça (`abertura.gd`)

O jogador é levado a `PIN_ACORDAR = (270, 0, −40)` (`:483`) e deitado (`Corpo.Postura.DEITADO_ACORDAR`, `:554`). As tomadas, em ordem: `01_acordar_ceu`, `01_acordar_joelhos`, **`02_deitado_igreja`**, `praca_2`, `03_levantar`, `praca_4`, `praca_5`. Depois, avenida (2 × 10 s), blitz (7 s), mercado (9,5 s), casa (9,5 s), poste (12 s), bituca, e `_entregar_o_jogo`: `Cinema.encerrar`, `Missoes.comecar_primeira`, `Gps.abrir`, em primeira pessoa.

A praça **espera** chunk e cômodo montarem entre tomadas; a duração varia de máquina para máquina.

## 2. O que "desde o começo" exige

| Plano | O que precisa aparecer com o grupo |
|---|---|
| PASSAGEM, AÉREA, RASANTE | **cabeças atrás do vidro**, uma por lugar ocupado |
| MATA, POÇA, SAÍDA | o carro com gente (silhueta, a esta distância) |
| DENTRO | **cada um do seu banco**, vendo os outros sentados |
| Praça, `02_deitado_igreja` | **todos deitados** na frente da igreja, a ~1,2 m um do outro |
| Fim | cada um abre o olho no **próprio** corpo |

Se o plano 1 mostra um carro vazio, o resto da abertura não conserta.

**O obstáculo que não é de rede, medido em 21/09:** o vidro da `Carroceria` é uma cor opaca na malha (`carroceria.gd:176`). Um corpo sentado atrás dele **não aparece** de fora, nem de lado nem de frente (fotos do carro do amigo na praça, `06` §4.3). A `CarroCena` da abertura usa a mesma carroceria. Enquanto o vidro não deixar ver uma silhueta (translúcido, ou recortado na altura das cabeças nos planos de fora), os planos PASSAGEM, AÉREA e RASANTE não conseguem mostrar o grupo, com rede ou sem. É a primeira coisa a combinar com a frente de render quando a Fase 7 começar.

## 3. Trabalho de cena (não é rede)

1. **Ocupantes no `CarroCena`.** Para cada lugar ocupado, um `Corpo` com a aparência daquele jogador, no `CarroCabine.assento(lugar)` (`09` §3.1):
   - motorista: o truque do trânsito, em pé e afundado até a cintura (`carro.gd:811`). O jogo não tem pose de volante (`corpo.gd:63`), e nos planos de fora ninguém vê a mão;
   - caronas: `Corpo.Postura.ASSENTO` (`corpo.gd:964`).
2. **Cabine nos planos de fora.** Hoje ela só aparece no DENTRO (`mostrar_cabine`, `carro_cena.gd:344`), porque atravessava o para-brisa de fora. Os planos de fora precisam de um modo "ocupantes sem cabine": só os `Corpo` e a lataria.
3. **Medir com captura, não a olho** (memória do projeto: *primeira execução não vale captura*): o RASANTE é o plano do perfil. A prova é a sonda por raio achar **cabeça** em cada janela ocupada.
4. **Poses da praça:** `N` corpos deitados em volta do `PIN_ACORDAR`, num arco de 1,2 m, e o enquadramento de `02_deitado_igreja` recalculado para o **centro do grupo**, sem cortar ninguém.

## 4. Trabalho de rede: o relógio do plano

### 4.1 O defeito do jeito ingênuo

`CarroCena.avancar(delta)` integra o `delta` de cada máquina. Um engasgo de 200 ms numa delas põe o carro dela **3,8 m** atrás do carro da outra, para sempre. As falas saem pelo `await` de cada plano, também por `delta`.

### 4.2 Plano pela hora do servidor

```
Servidor: _cena(cena = ESTRADA, plano = 1, t0 = tempo_servidor() + 0,5 s)   ← meio segundo para chegar a todos
Cliente:  espera Sessao.tempo_servidor() ≥ t0 e corta para o plano
          a cada quadro: t = Sessao.tempo_servidor() − t0
                         distancia = PARTIDA + CRUZEIRO / 3,6 · (t + inicio_do_plano)
                         _mover_camera(t / duracao)
                         a fala do instante t
```

A posição do carro vira **função da hora do servidor**, e não soma de `delta`. Duas máquinas desenham o carro no mesmo metro na mesma hora, com o erro do relógio (a Fase 1 já mede o relógio pela régua de 0,1 cm do boneco). Um engasgo não dessincroniza: o quadro seguinte já está no lugar certo.

O servidor manda um `_cena` por plano, com o `t0` de cada um. O cliente não decide quando corta.

### 4.3 Onde o tempo é da máquina: a praça

A praça espera chunk e cômodo. Com cinco máquinas, cada uma termina de montar numa hora.

**Barreira por tomada:** antes de cada tomada que depende de chão, cada cliente manda `_pronto_para(tomada)` quando montou. O servidor manda `_cena(…, t0)` quando **todos** estão prontos, ou **8 s** depois do primeiro, o que vier antes. Quem atrasou entra na tomada já em curso, com o chão que tiver.

### 4.4 Pular

| Quem | Pode |
|---|---|
| Qualquer um | votar para pular (`_pedir_pular`) |
| Maioria dos participantes | a abertura pula para o fade final, para todos |
| Anfitrião | pular sozinho, para todos (é a viagem dele) |

Não existe pular só para si: o carro e a praça são uma cena só, e quem pulasse chegaria à praça antes de os amigos acordarem nela.

### 4.5 Quem cai no meio

- **Participante cai:** o lugar dele fica vazio **no próximo corte**, e não no meio de um plano (um corpo sumindo dentro do carro em cena é um defeito visual).
- **Anfitrião cai:** a sessão acaba (P11); cada um termina a abertura sozinho, no próprio relógio, e acorda na praça no próprio mundo.
- **Alguém entra no meio da abertura:** não entra nela. Chega na praça (`10` §5) e espera.

## 5. O roteiro no plural

**Só no ramo co-op.** O solo mantém o singular, palavra por palavra (P16). A direção pode recusar o texto. O que o plano exige é que a **imagem** (N pessoas no carro) e a **pessoa gramatical** batam.

| Fala | Solo (hoje) | Co-op (proposta) | Quem diz |
|---|---|---|---|
| passagem | A gente marcou essa viagem faz uns dois meses. | (igual) | motorista |
| aerea_1 | Todo mundo dizia que **eu** tinha que conhecer. | Todo mundo dizia que **a gente** tinha que conhecer. | carona |
| aerea_2 | Duas horas de terra depois que acaba o asfalto. | (igual) | motorista |
| mata | Sem maldade, essa estrada não parece ter fim. | (igual) | carona |
| rasante | Eu que não queria vir. | (igual) | motorista |
| — | — | **Pois é. Eu que te arrastei.** | carona |
| dentro_1 | Faz uma semana que eu acordo pensando em desmarcar. | (igual) | motorista |
| dentro_2 | Cheguei a escrever a desculpa no celular. Não mandei. | (igual) | motorista |
| poca | Mas a pousada já tava paga e o pessoal já tava vindo. | **A pousada já tava paga.** / **E o pessoal já tava vindo.** | carona / atrás |
| saida | Aí **eu peguei** o carro e **vim**. | Aí **a gente pegou** o carro e **veio**. | motorista |

- **Com 2:** "carona" e "atrás" são a mesma pessoa.
- **Com 3 a 5:** "atrás" é o lugar 2; os lugares 3 e 4 não falam. Cinco vozes em 62 s é rádio, não viagem.
- **Legenda:** no co-op, a tarja leva o **primeiro nome** de quem fala ("ZE: Eu que não queria vir."). No solo, sem nome, como hoje. Com gente de verdade no carro, sem nome ninguém sabe qual amigo "disse".
- **No DENTRO:** cada um vê do próprio banco. Quando a fala é de outro lugar, a câmera de cada um gira um pouco para quem fala (a guinada do `OlharAoVolante`, com os mesmos limites), num movimento de 0,4 s. É o gesto de quem ouve alguém falar no carro.

## 6. Da estrada à praça

1. SAÍDA termina, blackout (o mesmo de hoje).
2. Cada cliente leva o **próprio** corpo para o arco em volta do `PIN_ACORDAR`, no lugar `i` do grupo, e deita.
3. `01_acordar_ceu`: POV **do próprio** olho, em cada máquina.
4. `02_deitado_igreja`: tomada externa, **a mesma** para todos (pela barreira do §4.3), mostrando o grupo deitado.
5. `03_levantar`: todos levantam juntos (`LEVANTANDO`).
6. Avenida, blitz, mercado, casa, poste: a mesma cena para todos, com os corpos escondidos onde a de hoje os esconde.
7. Bituca e `_entregar_o_jogo`: cada um volta à primeira pessoa **no próprio corpo**. A câmera de cinema não desce em cinco olhos.
8. **Missão:** uma para o grupo (P7, `08` §6), com a casa mais perto **do líder**.

## 7. `--pular-abertura` e captura

- **Solo:** igual.
- **Rede:** `--mp-pular-intro` leva o grupo direto à praça, de pé, no arco do `PIN_ACORDAR`.
- **Captura de duas ou mais máquinas:** cada processo com `--shot` numa **hora do servidor** (`--shot-t-servidor=12.0`), e não num número de quadro, que é diferente em cada máquina. Pasta: `captures/multiplayer/estrada_*.png`, `praca_*.png`.

## 8. Aceite

| # | Prova | Medida |
|---|---|---|
| 1 | PASSAGEM com 3: três cabeças no vidro, com as roupas das carteiras | sonda por raio acha `Corpo` em cada janela ocupada |
| 2 | DENTRO: cada um vê os outros sentados, do próprio banco | foto por máquina |
| 3 | Mesmo carro, mesma hora | posição do `CarroCena` nas máquinas, na mesma hora do servidor: **diferença < 5 cm**; com um engasgo de 300 ms forçado numa delas: **< 5 cm** um quadro depois |
| 4 | Mesma fala, mesma hora | a legenda muda nas máquinas com **diferença < 1 quadro** (33 ms) |
| 5 | Praça: todos deitados na mesma tomada | foto de `02_deitado_igreja` em cada máquina: mesmo enquadramento, N corpos |
| 6 | Pular por maioria | 2 de 3 votam: os 3 cortam para o fade no mesmo segundo |
| 7 | Solo | roteiro singular, sem nome na tarja, capturas iguais ao HEAD |

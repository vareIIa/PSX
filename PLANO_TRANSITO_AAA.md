# Plano do trânsito AAA — motoristas que dirigem como gente

**Criado em 24/09/2026**, a partir do pedido do usuário: "a IA de trânsito
atualmente é bugada e simples. Ela deve ser igual IA de trânsito de game AAA
(GTA 6/5/4): bem comportada, para perfeitamente nos sinais, não atropela
pedestre ou sempre tenta desviar, não faz viradas bruscas, faz viradas leves e
realistas e tem variáveis de decisão vastas e realistas." Pediu um plano de até
cinco passos, **um por sessão**, e nenhum executado nesta.

Este documento é o **Passo 0** (mapeamento) e o plano dos passos seguintes.

| Passo | O que entrega | Estado |
|---|---|---|
| 0 | Mapa do que existe, diagnóstico medido, arquitetura alvo | **feito 24/09** |
| 1 | Bancada do trânsito + curvas em arco com velocidade de curva (fim das viradas bruscas) | **feito 25/09** (sem commit) |
| 2 | Pé de motorista: IDM, parada perfeita, amarelo, tempo de reação | **feito 25/09** (sem commit) |
| 3 | Cruzamento que se respeita: juiz de cruzamento, conversão cede, pedestre na faixa | **feito 25/09** (sem commit) |
| 4 | Olhos e reflexos: percepção preditiva, desvio, reação a batida | pendente |
| 5 | Motoristas de verdade: personalidade, rota com propósito, troca de faixa, clima, densidade | pendente |

### Regras de execução (valem para todos os passos)

1. **Um passo por sessão, só com o aval do usuário.** Ao fim de cada passo,
   parar com os números de antes e depois e a mensagem de pronto. Não começar o
   seguinte sozinho.
2. **Medir antes de mexer.** Cada passo começa rodando a bancada na IA atual e
   termina rodando de novo na nova. Critério é situação MONTADA; observação da
   rua solta é leitura, nunca critério (duas rodadas iguais já deram 0,53 e
   1,00 de frota andando).
3. **Arquivo novo, ligação mínima.** Em 24/09 `carro.gd`, `transito.gd`,
   `vias.gd`, `pedestre.gd`, `rotas.gd` e `multidao.gd` têm trabalho não
   commitado de outra sessão (plano de desempenho, Fase 2). O cérebro novo mora
   em `game/src/world/transito/`; nos arquivos compartilhados entra só a
   ligação. Antes de cada passo: `git status --short` desses arquivos. Se o WIP
   alheio ainda estiver lá, commitar só as próprias linhas pelo índice
   (`git update-index --cacheinfo`), nunca `git add` no arquivo misturado.
4. **O que é da máquina vai para a bancada offline; o que é do mundo fica na
   cidade.** A cidade em headless roda ~10× mais devagar que o relógio: 45 s de
   jogo custam 7 min. Curva, freada, fila e decisão se medem em
   `tests/bancada_transito.gd` em milissegundos; na cidade fica só o que
   precisa dela (pedestre real, semáforo real, blitz, colisão).
5. **Ao terminar um passo:** atualizar a tabela acima e a seção do passo com o
   que foi medido.

---

## 1. Mapa do que existe

| Arquivo | Linhas | Papel hoje |
|---|---|---|
| `game/src/world/transito.gd` (autoload `Transito`) | 460 | Povoamento. Nasce numa coroa de 34 a 58 m do jogador, some a 74 m ou fora de chunk carregado. Teto `POPULACAO_BASE = 6` × `Vias.movimento` do distrito. Nasce um carro por quadro e encomenda lataria e motorista ao WorkerThreadPool. **Não decide nada de direção.** |
| `game/src/world/vias.gd` (`Vias`) | 468 | A malha de rolamento como função pura da coordenada: faixa por eixo e sentido (`linha_x/z`), a "quina" da curva (`ponto_de_curva`), `saidas` legais, `preferencial` do PARE, `trechos_perto` para nascer, `no_asfalto`, `movimento` do distrito. Rua: 1 faixa por sentido (meia pista 3,0 m + 1,8 m de estacionamento). Avenida: 2 faixas (4,5 m + 2,2 m). |
| `game/src/world/semaforo.gd` (`Semaforo`) | 304 | Estado puro de (cruzamento, eixo, tempo). Ciclo de 28 s em duas fases: verde 11, amarelo 2, vermelho geral 1. Só onde cruza avenida; o resto é PARE com preferencial fixa por esquina. Defasagem por cruzamento. |
| `game/src/world/sinal_pedestre.gd` | 116 | Só a cara do boneco. **Nenhum pedestre lê `estado_pedestre`.** |
| `game/src/world/carro.gd` (`Carro`) | 3294 | A IA mora aqui: `_dirigir_ia` e vizinhos, linhas ~2254–3035, misturadas com a física do carro do jogador, luzes, som e dano. O corpo da IA é congelado `FREEZE_MODE_STATIC` e a posição é escrita a cada passo — decisão certa, documentada no cabeçalho, e que fica. |
| `game/src/world/atropelo.gd` | 122 | Contato carro × pessoa, do lado da vítima (empurra, derruba). Estima a velocidade do carro congelado pelo rastro de posição. |
| `pedestre.gd`, `rotas.gd`, `multidao.gd` | 1343 / — / 479 | Pedestre anda de canto a canto de calçada e atravessa em qualquer esquina, a qualquer hora, sem olhar sinal nem carro. |
| `game/src/world/blitz.gd` | 822 | Injeta teto, mira e faixa no meio do `_dirigir_ia` via `Blitz.efeito(carro)`. **Contrato a manter.** |
| `game/src/levels/teste_transito.gd` + `tools/verificar_transito.py` | 488 | Cinco experimentos montados na cidade: parada na linha, fila, partida no verde, PARE, contorno. |

### Como um carro da IA anda hoje (um passo de física)

1. **Rota.** Mira num ponto da faixa 8 m à frente. A 8,5 m do centro do
   cruzamento sorteia a saída (62% reto; `randf()` global) e passa a mirar a
   "quina" — onde as duas linhas de faixa se cruzam. A 2,4 m dela, mira a faixa
   de saída.
2. **Rumo.** Gira no máximo **2,3 rad/s** atrás da mira, qualquer que seja a
   velocidade.
3. **Velocidade.** O menor de três tetos: via (11 m/s na rua, 14 na avenida),
   sinal ou PARE `sqrt(2·8·falta)`, obstáculo `sqrt(2·8·(d − 1,5))`. Acelera a
   4,2 e freia a 8 m/s², em degrau.
4. **Percepção.** Três raios retos na direção do nariz, a 0,6 m do chão, com
   alcance = distância de freio + 3,5 m (entre 3,5 e 18 m). Contam só `Carro`,
   `Pedestre` e o grupo `player`.
5. **Corpo.** Posição escrita direto; altura por raio; molas de carroceria de
   enfeite (`_balancar`).

---

## 2. Diagnóstico

### Medido (réplica da lei de controle, fora do jogo)

Réplica fiel em Python de `_dirigir_ia` + `_escolher_destino` + `_mira_ia`,
num cruzamento plano, 60 Hz. Descartável: **o Passo 1 refaz estas medidas no
código real, na bancada**, e elas viram a linha de base oficial.

| Situação | Hoje | Motorista de verdade |
|---|---|---|
| Curva na rua a 11 m/s (não há redução de velocidade para curva) | raio 4,8 m, **25 m/s² (2,6 g)** de aceleração lateral | 15–20 km/h na esquina, ≤ 3 m/s² (0,3 g) |
| Direita na rua a 11 m/s | sai **0,9 m dentro da contramão** da rua de saída | fica na própria faixa |
| Esquerda na rua a 11 m/s | vai a 3,84 m do eixo: **passa da pista (3,0) e entra na faixa de estacionamento** | entra na faixa da direita da rua nova |
| Avenida × avenida a 14 m/s | 3,3 g; direita cruza o eixo (+0,24 m); **esquerda sobe no meio-fio** (7,0 m contra 6,7) | idem acima |
| Parada no vermelho | desaceleração de **8 m/s² (0,82 g) do começo ao fim** — segue a toda e freia no último instante | 2–3 m/s², começando cedo |
| Seguindo outro carro a 40 km/h | 9,1 m de distância, **0,82 s** de intervalo | 1,5–2 s |

A primeira linha é o "vira brusco" que o usuário vê. As molas da carroceria
têm teto de rolagem (`ROLAR_MAX`), então a lataria nem deita: o carro gira como
peça de tabuleiro.

### Lido no código (o Passo que resolve está entre colchetes)

- **D1 — Curva é perseguição de ponto com giro fixo** e sem teto de velocidade
  por curvatura. É a causa das viradas bruscas e da invasão de faixa. [1]
- **D2 — Freio sempre máximo e acelerador em degrau**, sem tempo de reação.
  Todo sinal é uma freada de emergência. [2]
- **D3 — O carro da frente é tratado como parado.** O teto ignora a velocidade
  do líder: intervalo curto, sanfona. [2]
- **D4 — Percepção reta à frente.** Na curva os raios varrem a calçada (freada
  fantasma com gente na esquina) e não veem a faixa de saída; nada prevê quem
  VAI entrar na pista (pedestre descendo do meio-fio, carro vindo de lado). [4]
- **D5 — Conversão à esquerda no verde não cede a quem vem de frente**, e
  nenhuma conversão cede a pedestre na faixa. O semáforo de duas fases manda
  os dois fluxos juntos para o mesmo miolo. [3]
- **D6 — O PARE aceita brecha por distância (16 m), não por tempo.** A 14 m/s,
  16 m são 1,1 s — menos que o tempo de atravessar partindo do zero. [3]
- **D7 — Pedestre ignora o sinal e atravessa em qualquer esquina**; o carro só o
  percebe se ele cruzar um dos três raios. Não dá para "nunca atropelar" com
  pedestre que não obedece nada e carro que não prevê nada. [3 e 4]
- **D8 — Contorno cego.** Depois de 2,4 s atrás de um carro parado, sai sempre
  pela esquerda, sem olhar a contramão, com a mira pulando 2,1 m de uma vez
  (degrau lateral). [4]
- **D9 — Troca de faixa na avenida só DENTRO do cruzamento**, e em degrau
  (a faixa interna é uma "saída" de `Vias.saidas`). [1 e 5]
- **D10 — Todos os motoristas são iguais.** Mesma velocidade, mesmo freio,
  mesma paciência; saída sorteada a cada esquina, então ninguém vai a lugar
  nenhum. [5]
- **D11 — Batida não tem reação.** O carro da IA atingido só amassa e segue a
  rota. [4]
- **D12 — Bicicleta invisível (suspeita).** `Bicicleta` está no grupo
  `bicicleta` e não entra na lista do que os raios contam; o jogador de
  bicicleta pode ser atravessado. Confirmar em situação montada. [4]
- **D14 — A seta acende do lado oposto ao da curva** (achado e medido no
  Passo 1; ver o resultado dele). [1]
- **D13 — Blitz costurada no controlador** (sobrescreve teto, mira e faixa no
  meio de `_dirigir_ia`). Não é defeito, é contrato: o cérebro novo recebe a
  blitz como "restrição externa" e o teste da blitz (`--olhar-blitz=funil --teste-blitz`) tem de continuar verde. [1]

---

## 3. Arquitetura alvo

**Muda o cérebro, não o corpo.** O carro da IA continua cinemático
(`FREEZE_MODE_STATIC`, posição escrita): segue caminho conhecido, não deriva,
não capota, e é o mesmo nó que o jogador toma. O que troca é quem calcula a
posição.

A referência AAA é pública: os natives de direção do GTA V descrevem o
motorista como **um conjunto de bandeiras de estilo** (para antes de carro,
para antes de pedestre, desvia de carro, desvia de pedestre, obedece sinal,
usa seta, pode andar na contramão…) **mais habilidade e agressividade**, sobre
uma rede de caminhos com cruzamentos em fases. O plano replica essa forma com o
que o jogo já tem.

Arquivos novos, em `game/src/world/transito/`:

| Arquivo | Tipo | O que faz |
|---|---|---|
| `manobra.gd` | `RefCounted`, puro | Caminho de uma manobra como retas + arcos tangentes (concordância, com trecho de transição para a curvatura não pular), parametrizado por comprimento `s`: `ponto(s)`, `rumo(s)`, `curvatura(s)`, `comprimento()`. Tipos: SEGUIR, DIREITA, ESQUERDA, TROCA_DE_FAIXA (S suave), CONTORNO (S de ida e volta), RETORNO. O raio sai da geometria real do cruzamento: o maior que cabe sem invadir contramão nem meio-fio (tipicamente 5–8 m na direita, 7–11 m na esquerda). |
| `longitudinal.gd` | `RefCounted`, puro | **IDM** (Intelligent Driver Model, Treiber 2000): aceleração a partir de velocidade desejada, intervalo de tempo T, distância mínima s0, aceleração a e freada confortável b, usando a velocidade do líder. Linha de retenção = líder virtual parado. Jerk limitado. Freio forte (até 0,85 g) só por TTC, nunca no dia a dia. |
| `percepcao.gd` | `RefCounted` | Corredor ao longo da manobra (não do nariz), candidatos da vizinhança (carros, pedestres, jogador, bicicletas) com posição prevista a 2–3 s, tempo até o conflito (TTC). Devolve líder (distância, velocidade), perigo (TTC, lado) e bloqueio. |
| `juiz_de_cruzamento.gd` | estático, chaveado por `Vector2i` | Reserva de movimento com matriz de conflito (12 movimentos de carro + 4 travessias de pedestre por cruzamento). Não deixa entrar sem espaço na saída; conversão à esquerda cede por brecha de tempo; PARE por TTC e ordem de chegada; conversão cede a pedestre na faixa. |
| `perfil_motorista.gd` | `RefCounted`, puro | Parâmetros de cada motorista a partir da ficha (`Personalidade`, 12 tipos, idade) e da semente: velocidade desejada, T, s0, a, b, reação, brecha aceita, paciência, polidez de troca de faixa (MOBIL), uso de seta, bandeiras de estilo. Determinístico pela semente. |
| `motorista_ia.gd` | `RefCounted` (dono: `Carro`) | O cérebro: estado (manobra atual e próxima, `s`, velocidade), chama percepção → decisão → IDM, consome `Blitz.efeito`, e devolve a transformada do passo. Expõe o que os testes já leem (`motivo_da_parada`, `obstaculo_a_frente`, `contornando`, `linha_de_retencao`). |
| `game/tests/bancada_transito.gd` | `--script` | Roda motoristas contra `Vias`/`Semaforo` em chão plano, sem cidade, e imprime linhas `[bancada_transito] chave=valor`. |

**Ligação em `carro.gd`:** `_dirigir_ia` vira uma chamada a
`MotoristaIA.passo(delta)` + a escrita da transformada. A IA antiga fica atrás
de `--ia-antiga` até o fim do Passo 3, para a bancada comparar as duas na mesma
situação; sai no Passo 5.

**O que não muda:** o povoamento (`Transito`), a lataria, a luz, o som, o dano,
a rede (o trânsito é local por cliente), e o corpo cinemático.

---

## 4. Os cinco passos

### Passo 1 — Bancada e curvas em arco (fim das viradas bruscas)

**Resolve:** D1, D9, D13. **Arquivos:** `manobra.gd`, `motorista_ia.gd` (lateral
e velocidade de curva), `bancada_transito.gd`, ligação em `carro.gd`.

- Linha de base: a bancada roda a IA atual (`--ia-antiga`) nas manobras de rua
  e avenida e repete a tabela da seção 2 com o código real.
- O carro segue a manobra por `s`: posição e rumo vêm do caminho, não de
  perseguir um ponto. Sem mira, sem giro fixo.
- Velocidade de curva: `v ≤ sqrt(a_lat / κ)` com `a_lat = 2,5 m/s²`, olhando o
  caminho à frente, reduzindo antes da esquina com ≤ 2,5 m/s².
- Troca de faixa na avenida em S de ~3 s **antes** do cruzamento, nunca dentro.
- Esterço visual da roda dianteira vindo da curvatura (`atan(entre-eixos · κ)`).
- A longitudinal do Passo 1 ainda é a de hoje (tetos `sqrt(2ad)`), só com o
  teto de curva somado.

**Critérios (bancada, montado):**

| Medida | Hoje (réplica) | Aceite |
|---|---|---|
| Pico de aceleração lateral em direita, esquerda e troca de faixa | 25–32 m/s² | ≤ 3,0 m/s² |
| Quatro cantos da carroceria na direita | 0,9 m na contramão | nunca além do eixo |
| Quatro cantos da carroceria na esquerda | até o meio-fio | nunca além da borda da pista de saída |
| Afastamento do centro da faixa em reta | — | ≤ 0,15 m |
| Salto de taxa de guinada entre dois quadros | degrau até 2,3 rad/s | ≤ 0,3 rad/s |

E: `python tools/verificar_transito.py` e o teste da blitz (`-- --olhar-blitz=funil --teste-blitz`) continuam verdes; uma
rajada de fotos de uma esquina (ver `tools/mosaico_rajada.py`) para o olho.

#### Resultado do Passo 1 (25/09/2026)

**O que existe agora:**

- `game/src/world/transito/manobra.gd` — o caminho em pedaços: reta de faixa
  (com desvio lateral quíntico para troca de faixa, volta à faixa e contorno) e
  curva espiral–arco–espiral tangente às duas faixas, seguida pelo **eixo
  traseiro** (a roda de trás nunca anda de lado; a frente abre, como num carro).
  O raio e a espiral de cada tipo de esquina saem de uma busca que exige 15 cm
  de folga entre a lataria da maior picape e o eixo, a quina da calçada e (na
  esquerda) a borda da pista de saída. As 8 geometrias que a malha tem estão em
  `Manobra.TABELA` (raio 5,5–8,5 m, curva a 15–17 km/h); a bancada confere que
  a tabela ainda é o que a busca escolhe.
- `game/src/world/transito/motorista_ia.gd` — o motorista: planeja 70 m de
  caminho, decide a saída ao entrar no quarteirão (evitando beco quando a malha
  de lá já foi consultada), põe o carro na faixa certa da conversão com troca em
  S **depois** de sair do cruzamento anterior e **antes** do próximo, reduz para
  a curva a 2,5 m/s² de freada e 2,5 m/s² de lateral, acende a seta 3 s antes,
  contorna em S, e entrega a blitz ao comportamento antigo enquanto ela manda.
  Consulta a malha da esquina seguinte num fio de fundo (`aquecer`).
- `game/tests/bancada_transito.gd` — a bancada (seção 0 do plano: regra 4).
- Ligação: 10 linhas em `carro.gd` (`_ia`, criação no `_ready`, desvio em
  `_dirigir_ia`, `replanejar` no `plantar`, esterço visual). `--ia-antiga`
  volta a IA de antes.
- `teste_transito.gd` e `verificar_transito.py` passaram a informar o custo do
  motorista na cidade.

**Medido na bancada** (mesmo carro, mesma esquina, mesma manobra imposta;
`--sem-relevo`):

| Medida | IA antiga | IA nova | Aceite |
|---|---|---|---|
| Pico de aceleração lateral (direita/esquerda, rua e avenida) | 25,3–32,2 m/s² | 2,53–2,57 m/s² | ≤ 3,0 |
| Idem saindo do PARE | 19–24 m/s² | 2,53–2,55 | ≤ 3,0 |
| Troca de faixa | degrau dentro do cruzamento, 32 m/s² | S antes do cruzamento, 1,44 m/s² | ≤ 3,0 |
| Salto de guinada entre quadros | 2,30 rad/s | ≤ 0,057 rad/s | ≤ 0,3 |
| Direita: canto da lataria além do eixo | +1,15 a +2,25 m | −0,21 a −2,20 m (nunca) | ≤ 0 |
| Esquerda: além da borda da pista de saída | +1,08 a +3,71 m | −0,29 a −2,07 m (nunca) | ≤ 0 |
| Esquerda: canto na calçada | até +1,30 m | nunca | ≤ 0 |
| Velocidade mínima na curva | 11–14 m/s, a da via (5,8–7,6 saindo do PARE) | 3,8–4,6 m/s (14–17 km/h) | — |
| Seta | **do lado oposto em todas as curvas** | do lado da curva | lado certo |
| Critérios da bancada | 33 de 84 | **86 de 86** | todos |

**Na cidade:** `verificar_transito.py` todo verde (parou +0,00 a +0,03 m da
linha, saiu 0,4 s depois do verde, fila a 5,86–5,94 m, PARE cede e atravessa,
contorno passa; 98% da frota andando). Teste da blitz 0 falhas (parou na baia a
0,15 m, alinhado a −2,9°).

**Custo:** passo de direção 0,035–0,037 ms por carro (antiga 0,029–0,032);
pior passo 0,4–1,1 ms, no quadro em que o carro planeja o quarteirão seguinte
(antiga 0,13 ms). Na cidade, pior planejamento 1,09 ms e primeiro planejamento
1,02 ms. Com a malha totalmente fria (bancada sem cidade) o primeiro
planejamento chega a 7,2 ms — a primeira consulta de uma região ao `Tracado` e
ao `Relevo` custa 7–60 ms, e é por isso que existe o `aquecer`.

**Achados no caminho:**

- **D14 — a seta da IA antiga acendia do lado oposto ao da curva.**
  `Carro._lado_da_curva` toma o `y` positivo do produto vetorial como direita;
  andando para +Z a direita é −X, e (+Z)×(−X) tem `y` negativo. A bancada
  confirmou pelas lâmpadas (`_luz_f_dir` é x ≥ 0). Corrigido no motorista novo
  (`Manobra.lado_da_curva`); a função antiga continua errada e só serve à
  `--ia-antiga`.
- O contorno continua começando colado no carro parado (a fila para a 1,5 m):
  o S de 8 m é o mínimo que um carro faz, e o canto da frente ainda raspa a
  traseira do parado no começo. Real mesmo é dar ré ou parar mais longe — fica
  para o Passo 4, junto com olhar a contramão.
- A freada do PARE e do sinal ainda é a antiga (8 m/s² do começo ao fim): é o
  Passo 2.

**Rodar:**

```bash
godot --headless --fixed-fps 60 --path game --script res://tests/bancada_transito.gd -- --sem-relevo [--ia-antiga] [--so=rua_rua,av_av,rua_av,av_rua,pare,custo] [--csv=DIR]
godot --fixed-fps 60 --resolution 960x540 --path game --script res://tests/bancada_transito.gd -- --sem-relevo --so=rua_rua --fotos=DIR
python tools/verificar_transito.py
godot --path game --resolution 640x360 -- --olhar-blitz=funil --teste-blitz
```

### Passo 2 — Pé de motorista: parada perfeita, fila e amarelo

**Resolve:** D2, D3. **Arquivos:** `longitudinal.gd`, ajuste em `motorista_ia.gd`.

- IDM com a velocidade do líder; linha de retenção como líder parado.
- Amarelo com zona de dilema: para se a freada necessária é ≤ 3,5 m/s², senão
  passa. Nunca entra no vermelho.
- Tempo de reação na partida: o verde abre e a fila sai em cascata, cada carro
  ~1 s depois do da frente, como na rua de verdade.
- Jerk limitado nas duas pontas (sem tranco de arrancada nem de parada); o
  "assentar" no fim da freada.

**Critérios (bancada, montado):**

| Medida | Hoje (réplica) | Aceite |
|---|---|---|
| Pico de desaceleração parando no vermelho vindo de 11 e de 14 m/s | 8,0 m/s² | ≤ 3,0 m/s² |
| Onde o bico para | na linha (−0,09 m) | entre −0,8 m e 0,0 m da linha |
| Intervalo seguindo a 40 km/h | 0,82 s | 1,2 a 2,0 s |
| Onda: líder freia 11 → 0 a 3 m/s², quatro seguidores | — | sem contato; nenhum passa de 4,5 m/s² |
| Partida no verde | — | 1º carro em 0,4–1,2 s; 3º em ≤ 3,5 s |
| Amarelo | — | quem precisaria de > 3,5 m/s² passa; quem não precisa para |

E: `verificar_transito.py` verde (a parada na linha continua ≤ 1 m).

#### Resultado do Passo 2 (25/09/2026)

**O que existe agora:**

- `game/src/world/transito/longitudinal.gd` — o pé em funções puras: **IIDM**
  (o IDM melhorado de Treiber e Kesting, cujo equilíbrio é `s0 + v·T` mesmo
  perto da velocidade desejada), a freada constante até um ponto, o alívio do
  freio no fim (proporcional à freada em curso), o curso do pedal (jerk
  limitado; 30 m/s³ só em emergência) e a freada para parar contando esse curso
  (`freada_para_parar`, que decide o amarelo). O `Pe` de cada motorista:
  a 2,0, b 2,2, T 1,5 s, s0 2,0 m, reação 0,5–0,8 s pela semente (o Passo 5 tira
  o resto da ficha).
- `motorista_ia.gd`: cada coisa pede uma aceleração (seguir, curva, parada no
  cruzamento, via) e vale a menor, com o motivo. O da frente é achado
  **projetando os outros carros no caminho planejado** — acha quem vai na
  frente na curva e quem está atravessado no miolo —; os três raios ficaram para
  pedestre, jogador a pé e bicicleta (fecha a suspeita D12 no que é de ver:
  bicicleta agora conta). Sinal e PARE viram um ponto de parada na linha; o
  amarelo é decidido uma vez; parado e liberado, o pé só sai depois do tempo de
  reação; luz de freio acesa segurando o carro parado. A percepção e a curva
  rodam em quadros alternados (16 ms de atraso), e o que o cruzamento é (sinal,
  PARE) é perguntado à malha uma vez, ao planejar.
- `--diag-transito`: todo carro parado há mais de 5 s descreve por quê.
- **`Semaforo.AMARELO_S` passou de 2 para 3 s** (ciclo de 28 para 30 s). Com 2 s,
  a 50 km/h e a 30 m da linha o carro não conseguia nem parar sem emergência
  (4,1 m/s² contando o curso do pedal) nem cruzar antes do vermelho (2,1 s): a
  zona de dilema. Três segundos é o que os manuais pedem para 50 km/h.
- Bancada: cenários `parada`, `partida`, `amarelo`, `fila`, `onda` (os dois
  últimos numa reta de bancada, `MotoristaIA.caminho_de_bancada`, com o líder
  freando por `roteiro_a`), e o critério `freada` ≤ 3,0 m/s² em todas as curvas
  do Passo 1.

**Medido na bancada:**

| Medida | IA antiga | IA nova | Aceite |
|---|---|---|---|
| Parada no vermelho, rua a 11 m/s | 8,02 m/s², bico **0,16 m além** da linha | 1,43 m/s², bico 0,44 m antes; tira o pé a 66 m, freia a partir de 40 m | ≤ 3,0; 0–0,8 m antes |
| Parada no vermelho, avenida a 14 m/s | 8,00 m/s², bico **0,65 m além** | 2,33 m/s², bico 0,44 m antes | idem |
| Parada no PARE | 8,1 m/s² | 1,43 m/s² | ≤ 3,0 |
| Freada para curva | 2,8–3,0 m/s² (degrau) | 1,4–2,1 m/s² | ≤ 3,0 |
| Fila de três no verde (saída de cada um) | 0,03 / 0,18 / 0,33 s (todos juntos) | 1,02 / 2,10 / 3,13 s (em cascata) | 1º em 0,4–1,2; 3º ≤ 3,5 |
| Fila parada (centro a centro) | 5,85 m | 6,34 m | ≥ 5,0 |
| Seguindo a 38 km/h | 0,82 s (réplica) | 1,69 s | 1,2–2,0 s |
| Onda: líder freia 11→0 a 3 m/s², 4 seguidores | — | sem contato (2,05 m); 2,86 → 2,64 → 2,20 → 1,76 m/s², amortecendo | sem contato; ≤ 4,5 |
| Amarelo a 20 m e a 30 m (14 m/s) | passa | passa sem frear, cruza a 1,43 e 2,13 s | cruza antes do vermelho |
| Amarelo a 36 m | passa sem frear | para a 3,27 m/s², bico 0,47 m antes | para, ≤ 3,5 |
| Amarelo a 45 m | freia a 8 m/s² e **cruza a linha 3,2 s depois (no vermelho)** | para a 2,47 m/s², bico 0,43 m antes | para, ≤ 3,5 |
| Critérios da bancada | 52 de 115 | **120 de 120** | todos |

**Na cidade:** `verificar_transito.py` verde — parou 0,58 m antes da linha, saiu
1,7 s depois do verde (antes 0,4 s: agora há reação), fila a 6,19 m, PARE 0,63 m
antes, contorno passa; 84–100% da frota andando nas rodadas, maior parada 7,7–8,3 s
esperando sinal. Teste da blitz 0 falhas.

**Custo:** passo de direção 0,037–0,039 ms por carro (antiga 0,030; o Passo 1
fechou em 0,035). Na cidade, com outro Godot aberto na máquina, 0,088–0,10 ms.

**Achados no caminho:**

- O critério antigo de contorno ultrapassa, depois de 2,4 s, um carro de IA
  parado "sem motivo" — na onda da bancada o líder parado pelo roteiro foi
  ultrapassado. Correto pela regra; a bancada mede a onda até os carros
  pararem. O contorno de verdade (olhar a contramão, ré) é o Passo 4.
- O povoamento nasce carro com o bico já além da linha, andando, com o sinal
  fechado (visto duas vezes no mesmo ponto pelo `--diag-transito`). A regra
  "quem já está na linha andando, ou não para antes dela nem com emergência,
  segue" resolve do lado do motorista; o `Transito` (com WIP de outra sessão)
  não foi tocado.
- Carro parado atrás de outro antes da linha do PARE ficava com a freada
  "comprometida" e nunca encostava na linha — o PARE só libera quem está nela.
  Corrigido (parado, a freada comprometida acaba).

### Passo 3 — Cruzamento que se respeita

**Resolve:** D5, D6, D7 (lado do pedestre). **Arquivos:**
`juiz_de_cruzamento.gd`; ligação mínima em `pedestre.gd`/`rotas.gd` (com WIP
alheio — ver regra 3).

- Cada carro reserva o seu movimento antes da linha e libera ao sair. Matriz de
  conflito por cruzamento; não entra quem conflita com movimento reservado.
- **Não tranca o cruzamento:** só entra se a faixa de saída tem espaço para o
  carro inteiro + folga, mesmo no verde.
- **Esquerda no verde cede** ao contrafluxo que vem reto ou à direita, por
  brecha de tempo (4–5 s conforme o perfil).
- **PARE por tempo:** entra com TTC ≥ 3 s de quem vem pela preferencial; entre
  dois PAREs, quem parou primeiro sai primeiro.
- **Pedestre na faixa:** atravessa só na zebra da esquina, espera o ANDA do
  boneco (`Semaforo.estado_pedestre`), não começa no PARE piscando, e em
  esquina sem sinal olha e espera brecha. Reserva a travessia no juiz; a
  conversão que cruza a zebra cede.

**Critérios (cidade, montado, em `teste_transito.gd`):**

- Esquerda × contrafluxo com brechas de 2, 4 e 7 s: cede nas curtas, entra na
  longa; menor TTC entre os dois ≥ 1,5 s.
- PARE: preferencial a 11 e 14 m/s vindo a 16, 25 e 40 m — a secundária só
  entra com TTC ≥ 3 s. (Hoje entra aos 16 m, que a 14 m/s são 1,1 s.)
- Fila parada na saída: o carro da aproximação espera antes da linha no verde.
- Pedestre na zebra e carro convertendo: o carro para ≥ 2 m antes da pessoa, e
  a pessoa não desvia.
- Pedestre e boneco: zero travessias começadas fora do ANDA em 5 min. Contagem
  de violação tem de ser zero; por isso vale como critério mesmo observada.
- 10 min de rua solta: zero sobreposição IA × IA e IA × pedestre.

#### Resultado do Passo 3 (25/09/2026)

**O que existe agora** (tudo novo em `game/src/world/transito/`, sem commit):

- `esquina.gd` — a esquina como está pintada: a linha de retenção (asfalto da
  rua que cruza + 2,5 m + 0,28 m de tinta; a antiga, meia pista + 2,5 m, punha
  o bico em cima da zebra), a zebra de cada braço (`Zebra`: ao longo,
  atravessado, faixa) e por que braço se chega e se sai.
- `movimento.gd` — cada movimento (braço de chegada → braço de saída) como o
  caminho que a lataria varre: três discos a cada 0,5 m. `conflito(a, b)` dá os
  trechos em que dois movimentos se tocam (guardado por par), e cada movimento
  sabe quando passa por cada zebra.
- `juiz_de_cruzamento.gd` — quem entra, sem reserva central: cada carro publica
  o que vai fazer (movimento, onde está, se passa, para pela lei, cede ou já
  está dentro) e julga os outros pela mesma ordem estrita, então os dois lados
  chegam à mesma resposta. A ordem: quem já está dentro; a preferencial antes do
  PARE; entre dois PAREs, quem parou primeiro; a esquerda cede ao contrafluxo;
  empate pela chegada e pelo id. Janela de tempo no ponto de conflito com PET
  1,5 s (1,1 s depois de 10 s esperando), não entra com a saída cheia, cede a
  quem está na zebra.
- `travessia_de_pedestre.gd` — a decisão de quem atravessa: vai até o meio-fio
  pela linha da zebra; com sinal, só no ANDA e com tempo de chegar (aperta o
  passo até 1,4×); sem sinal, olha e espera brecha, com margem maior que a do
  carro — a brecha que ela aceita o carro também aceita. Não começa com um carro
  dirigido parado em cima da faixa. Quem atravessa fora de cruzamento (meio de
  quarteirão) fica registrado para os carros verem.
- `fiscal_de_travessia.gd` — conta de fora, pela posição, quem desceu da calçada
  numa zebra com sinal fora do ANDA (bancada e cidade).
- `motorista_ia.gd` — a lei (sinal, PARE) e o juiz na aproximação; compromisso
  (liberado e sem parada confortável antes da linha, entra e sai); cede a quem
  está na zebra de saída, e na direita entra e espera rente a ela; não tranca o
  cruzamento; gente atravessando no meio do quarteirão (para antes da faixa,
  guarda a decisão até a pessoa sair da faixa dele, e não espera com a lataria
  em cima da outra faixa do mesmo nó); gente na pista vista pela projeção no
  caminho planejado (os três raios saíram), só no leito da rua — pessoa a pé é
  um ponto de parada 2 m antes dela, bicicleta é seguida como carro; a troca de
  faixa confere a faixa nova antes do S; nasce devagar com vermelho, PARE ou
  gente atravessando logo à frente. `longitudinal.gd` ganhou `tempo_ate`.
- `pedestre.gd` — ~15 linhas de ligação: a travessia dá o alvo e o passo; quem
  atravessa não para para conversar nem troca de rumo; paciência maior
  atravessando.
- Bancada nova `tests/bancada_cruzamento.gd` (herda a do trânsito): 21
  situações montadas e 10 min de rua solta; `--semente=N` (padrão 1) fixa o
  sorteio global, e a rodada se repete igual.
- Cidade: `teste_transito.gd` mede a parada na linha pintada e conta travessias
  fora do ANDA; `verificar_transito.py` exige zero.

**Os critérios saíram da cidade para a bancada.** O plano pedia os critérios em
`teste_transito.gd`. Pela regra 4 foram para a bancada offline, que roda o
`Carro` e o `Pedestre` de verdade na malha de verdade, sem a cena da cidade: a
situação se monta igual toda vez e a rodada inteira custa minutos. Na cidade
ficou o que é dela: a linha pintada, o boneco e a blitz. A brecha da esquerda
virou um fluxo com intervalos crescentes (o quarto é de 7 s), e o "TTC ≥ 1,5 s"
virou PET ≥ 1,5 s — medido depois, nas trajetórias gravadas, e não previsto.

**Medido na bancada do cruzamento** (mesma bancada, `--ia-antiga` para a coluna
da esquerda):

| Situação | IA antiga | IA nova | Aceite |
|---|---|---|---|
| Esquerda × contrafluxo, avenida, parado na linha | entra na 1ª brecha (deixa passar 0 de 3), PET −0,07 s, **encosta** (−1,03 m) | deixa passar 3, entra na de 7 s, PET 2,05 s | deixa 3; PET ≥ 1,5 |
| idem, chegando | PET 0,73 s, 8,02 m/s² | PET 2,25 s, 2,64 m/s² | PET ≥ 1,5; ≤ 3,0 |
| Esquerda, rua, parado | deixa 0, PET 0,18 s, **encosta** (−0,19 m) | deixa 3, PET 2,77 s | deixa 3; PET ≥ 1,5 |
| idem, chegando | PET 0,17 s, 8,02 m/s² | PET 2,68 s, 1,65 m/s² | idem |
| PARE, preferencial a 16/25/40 m, a 11 e 14 m/s | entra na frente dela em todos: TTC 1,1–3,4 s, PET −0,48 a 1,80 s | espera ela passar em todos, PET 1,77–2,00 s | entra depois; PET ≥ 1,5 |
| PARE, preferencial a 86 m | entra (PET 5,2 s) | entra antes dela, TTC 5,1 s, PET 3,62 s | TTC ≥ 3 |
| PARE, à direita | PET 0,65 s | PET 3,10 s | ≥ 1,5 |
| Dois PAREs de frente | saem juntos (1,1 e 2,8 s), PET 1,62 s | quem parou primeiro sai primeiro (5,3 e 9,6 s), PET 2,72 s | ordem; ≥ 1,5 |
| Faixa de saída parada, no verde | não espera | espera com o bico 0,50 m antes da linha | fora do cruzamento |
| Direita × pessoa na zebra de saída | 1,11 m dela, 8,02 m/s² | 6,71 m, 2,04 m/s² | ≥ 1,0 m; ≤ 3,0 |
| Esquerda × pessoa na zebra de saída | **0,19 m**, 8,02 m/s² | 11,38 m, 1,76 m/s² | idem |
| Direita com cinco atravessando em fila (novo) | vira em 5,8 s sem ceder: susto, 8,03 m/s² | entra, espera rente à faixa, vira em 16,0 s (no mesmo ciclo); 2,02 m andando, 2,09 m/s² | no ciclo; ≥ 1,0 m; ≤ 3,0 |
| Pessoa sem sinal esperando brecha na preferencial | desce na frente em 1,5 s, PET 0,47 s, carro a 8 m/s² | espera 14,9 s, PET 3,75 s, nenhum carro freia (0,55 m/s²) | PET ≥ 1,5; carro ≤ 1,0 |
| Meio de quarteirão, avenida a 14 m/s | **atropela** (−0,26 m), 8 m/s² | 3,36 m dela, sem susto, 2,64 m/s² | ≥ 1,0 m; ≤ 3,0 |
| Meio de quarteirão, as duas zebras (novo) | não se aplica (sem travessia) | espera antes da primeira: 0 quadros em cima, 2,44 m/s² | 0 quadros |
| Boneco, oito pessoas, 70 s | 6 de 9 descem fora do ANDA | 0 de 12 | 0 |
| Rua solta, 10 min, 14 carros, 16 pessoas | 4 contatos entre carros, 21 com gente, 44 de 63 fora do ANDA, 445 freadas > 4,5 m/s² | 0, 0, 0 de 54; 4 freadas > 4,5; maior parada 17 s | 0, 0, 0 |
| Critérios | 40 de 79 | **79 de 79** | todos |

E na bancada do trânsito (Passos 1 e 2, agora pela linha pintada): **122 de
122** (a antiga, 52 de 117). A parada no vermelho fica 0,44 m antes da linha
pintada e 1,47 m antes da zebra; a antiga parava 2,6–3,1 m além da linha, em
cima da zebra.

**Na cidade:** `verificar_transito.py` verde — parou 0,53 m antes da linha
pintada, PARE 0,54 m antes, nenhuma travessia com sinal fora do ANDA. Teste da
blitz 0 falhas (numa rodada intermediária o carro sem motorista da pancada bateu
num pedestre da multidão que atravessava; o teste não afasta a multidão, e a
rodada seguinte e a final passaram). `verificar_npc`: gente andando, nenhuma
travada; o único vermelho é de outra frente (a conversa oferece 8 assuntos, o
critério espera 7).

**Custo:** passo de direção 0,039 ms por carro na bancada do trânsito (Passo 2:
0,037–0,039); 0,069 ms na do cruzamento, com juiz, gente e rua solta. Montar um
`Movimento` custa no pior 0,53 ms e um conflito 0,46 ms, uma vez cada (ficam
guardados). Pior planejamento de quarteirão 1,19 ms (teto 2,0). Com outra sessão
rodando o jogo em 4K na mesma máquina, o mesmo pior chegou a 3,2 ms na bancada e
6,0 ms na cidade: o critério de custo só vale com a máquina livre.

**Achados no caminho:**

- A linha de retenção antiga (meia pista + 2,5 m) punha o bico em cima da zebra.
- Os cantos do `Rotas` na esquina em T ficam no eixo da rua que falta: quem
  atravessava ia na diagonal. A travessia agora anda pela linha da zebra, de
  meio-fio a meio-fio.
- A troca de faixa entrava na frente de quem vinha ao lado (2 contatos na rua
  solta): o S agora confere a faixa nova e desiste sem brecha.
- Gente atravessando no meio do quarteirão (viela encostando na avenida) era
  invisível ao carro até entrar no corredor dele: três atropelos no mesmo ponto.
- Margem do pedestre menor que a do carro: a brecha que ele aceitava fazia o
  carro frear, e passando a 50 km/h na faixa ao lado ele levava susto.
- Os três raios freavam por gente na calçada da esquina na curva. A projeção no
  caminho só conta quem está no leito — a primeira versão contava a calçada e
  segurou o carro saindo da baia da blitz.
- A multidão parava para conversar no meio da rua, e o reroteamento trocava a
  travessia no meio dela.
- O carro que esperava gente na zebra de lá do meio de quarteirão parava com a
  lataria em cima da de cá (as duas a 5 m): quem atravessava a de cá passava
  rente e levava um empurrão quando ele arrancava. A rua solta pegou dois
  tropeços com zero "contatos", porque o critério só via 2 cm de caixa; agora
  tropeço ou queda com a lataria a menos de 0,3 m conta. Na bancada, sem a
  correção, o carro fica 152 quadros em cima da faixa.
- A decisão de parar por quem atravessa piscava: refeita pela previsão a cada
  quadro, freando ele chegava depois (ela já passou) e andando chegava antes
  (ela está lá); o carro rolava a 2–3 m/s na direção da pessoa. Agora ele decide
  e só solta quando ela sai da faixa dele, pelo que se vê. O mesmo com a escolha
  de parar antes da primeira zebra, e o alvo de parada interpolado entre as
  amostras de 2 m do caminho (andava aos saltos e o fim da parada virava freada
  de emergência).
- Na direita, esperar na linha por quem atravessa a zebra de saída perdia o
  verde inteiro na esquina cheia (60 s parado na rua solta; sem a correção, o
  cenário `conversao_fluxo` não vira em 45 s).
- Pessoa a pé como líder do IIDM pedia folga de carro (2 m + 1,5 s + a
  aproximação): a 1 m/s, perto do ponto de parada, uma pessoa vindo na direção
  dele virava freada de 3,2 m/s².
- A bancada que força a velocidade depois de `plantar` pulava a trava de nascer:
  carro surgindo a 14 m/s a 56 m de gente na faixa. E o sorteio global,
  semeado pelo relógio, fazia a rua solta parecer não determinística.

**Sobras para os Passos 4 e 5:**

- A esquerda ainda espera na linha. Parada no miolo, a lataria fica no caminho
  do contrafluxo; esperar dentro pede uma posição que respeite os conflitos
  (Passo 4). Na esquina cheia ela pode perder um verde.
- Carro parado em fila em cima da zebra do meio de quarteirão: a pessoa espera
  ele sair. "Manter a faixa livre" na fila é do Passo 4.
- Quem já está atravessando não reavalia: se um carro para em cima da faixa na
  frente dele, ele contorna.
- O jogador de bicicleta (D12) é seguido como carro; o critério é do Passo 4.
- O sorteio do pedestre usa o `randf` global: a bancada semeia, o jogo não.

**Rodar:**

```
godot --headless --fixed-fps 60 --path game --script res://tests/bancada_cruzamento.gd -- --sem-relevo
godot --headless --fixed-fps 60 --path game --script res://tests/bancada_cruzamento.gd -- --sem-relevo --ia-antiga
godot --headless --fixed-fps 60 --path game --script res://tests/bancada_transito.gd -- --sem-relevo
python tools/verificar_transito.py
godot --path game --resolution 640x360 -- --olhar-blitz=funil --teste-blitz
```

### Passo 4 — Olhos e reflexos: prever, desviar, reagir

**Resolve:** D4, D7 (lado do carro), D8, D11, D12. **Arquivos:** `percepcao.gd`,
decisão em `motorista_ia.gd`.

- Percepção pelo corredor da manobra, com previsão de 2–3 s e TTC. Os três
  raios saem.
- Resposta em camadas: seguir (IDM) → ceder ou esperar → frear forte (só por
  TTC) → **desviar** (S curto dentro da faixa, ou para a faixa vizinha,
  somente se o corredor do desvio está livre, contramão e calçada inclusive) →
  buzina, gesto, pisca-alerta.
- Contorno de carro parado em S suave, e só com a contramão livre por brecha de
  tempo; senão espera atrás.
- Reações: batida (para, pisca-alerta, motorista desce e reclama pela
  `Conversa`, ou vai embora, conforme o perfil); jogador na contramão ou
  dirigindo perigoso (reduz, encosta, buzina).
- **Sub-passo 4b, só se a bancada aprovar:** o carro da IA atingido pelo jogador
  vira corpo com física por alguns segundos, reage à pancada e volta a ser
  cinemático com uma manobra de retorno à faixa. Tem bancada própria por causa
  das armadilhas do `VehicleBody3D` (congelar teleporta; congelado cinemático
  parado vira NaN). Se reprovar, fica fora e registra aqui.

**Critérios (bancada e cidade, montado):**

- Pedestre saindo na frente a 40 km/h, a 25, 15, 10 e 6 m: sem contato em todo
  caso fisicamente possível (distância > reação + parada a 0,85 g); nos
  outros, desvio lateral ≥ 1 m quando há corredor livre. A velocidade residual
  de impacto sai no relatório.
- Pedestre parado na calçada da esquina, carro convertendo: zero freadas
  fantasmas.
- Carro do jogador na contramão, de frente, TTC inicial ≥ 3 s: a IA reduz e
  encosta; sem colisão.
- Contorno: zero entradas na contramão com carro vindo a menos de 5 s.
- Jogador de bicicleta na faixa: o carro segue atrás (confirma e fecha D12).
- Custo da percepção ≤ 0,05 ms por carro por passo de física, na média.

### Passo 5 — Motoristas de verdade

**Resolve:** D10 e fecha o plano. **Arquivos:** `perfil_motorista.gd`; ligação em
`transito.gd` para densidade; remove `--ia-antiga`.

- **Perfil por motorista** (da ficha): APRESSADO anda perto do limite com
  intervalo curto e aceita brecha menor; GENTIL cede e deixa entrar;
  ASSUSTADO freia cedo e hesita no PARE; MANDÃO buzina antes; SONHADOR reage
  tarde à partida do verde… Faixas: velocidade desejada 0,85–1,10 do limite, T
  1,0–2,2 s, reação 0,5–1,3 s. **O perfil muda o jeito, nunca a lei:** nenhum
  perfil fura vermelho, ultrapassa onde não pode ou deixa de ceder a pedestre.
- **Rota com propósito:** cada motorista tem destino (casa, trabalho, comércio,
  pelo distrito e pela hora do `Relogio`) e segue `Rota.tracar`. Liga a seta
  cedo, escolhe a faixa da conversão antes, não fica girando no quarteirão.
- **Troca de faixa na avenida (MOBIL):** passa o lento com brecha segura atrás.
- **Clima e hora:** chuva (`Clima`) baixa velocidade e alonga o intervalo; noite
  tem menos carros; entrada e saída de vaga na faixa de estacionamento, com
  seta.
- **Densidade:** medir o custo real por carro e subir `POPULACAO_BASE` (6 hoje)
  até onde o orçamento de quadro deixar. Fica amarrado ao
  `PLANO_DESEMPENHO_E_HORIZONTE.md`.

**Critérios:**

- 200 motoristas sorteados cobrem as faixas de cada parâmetro; a mesma semente
  dá o mesmo motorista.
- ≥ 90% das conversões com seta ≥ 3 s antes; nenhum carro repete o mesmo
  quarteirão em 5 min.
- MOBIL: zero trocas com brecha traseira < 1,0 s.
- Chuva: velocidade média cai ≥ 10% e o intervalo sobe.
- Densidade: número final de carros escolhido pela bancada de FPS, sem piorar o
  p99 do quadro dirigindo.
- `verificar_transito.py` inteiro verde, com todos os experimentos dos passos 1
  a 4.

---

## 5. Riscos conhecidos

- **WIP alheio nos arquivos de ligação** (regra 3). Se `carro.gd` não compilar
  por trabalho de outra sessão, rodar a bancada num worktree no HEAD.
- **Mudança de vazão.** Carro que reduz para 15–20 km/h na esquina e segura
  1,5 s de intervalo deixa a rua mais lenta que hoje. É o comportamento pedido;
  a densidade do Passo 5 compensa.
- **Pedestre é de outra frente.** O Passo 3 mexe no menor pedaço possível de
  `pedestre.gd`/`rotas.gd` (a decisão de atravessar); animação, fala e
  multidão ficam como estão.
- **Blitz.** Todo passo roda o teste da blitz (`-- --olhar-blitz=funil --teste-blitz`, sem script Python próprio) além de `verificar_transito`.

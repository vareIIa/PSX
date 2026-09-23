# 09 — Veículo: motorista, carona e o carro do grupo

> **Versão 2.0 — 21/09/2026.** Reescrito. Dois fatos da 1.0 não valem mais:
> 1. "O `Carro` da cidade não tem cabine, e a primeira pessoa ao volante é um buraco." **Tem.** `CabineDoJogador` (`world/cabine_do_jogador.gd`) monta a `CarroCabine` no carro assumido, com câmera própria no olho do motorista e três vistas: `LONGE`, `PERTO` e `DENTRO` (`:36`). Os comentários de `camera_rig.gd:48` e `:135` estão desatualizados.
> 2. "O host simula o `VehicleBody3D` e o motorista manda input." **Não.** Com dedicado na internet, o motorista é dono do carro (P6).

## 1. O que existe

| Peça | O que faz | Onde |
|---|---|---|
| `Carro` (`VehicleBody3D`) | um motorista: `enum Motorista { NINGUEM, IA, JOGADOR }` | `carro.gd:32`, `:326` |
| `assumir(quem)` | tira o NPC, descongela, monta a `CabineDoJogador` | `:948`, `:980` |
| `devolver()` | desmonta a cabine, congela **STATIC** (não KINEMATIC: parado vira NaN, `:826`), prega onde está | `:993` |
| `assento()` | **um** ponto: o banco do motorista | `:1056` |
| `ponto_de_saida()` | lado do motorista, senão o outro, senão por cima | `:1024` |
| `_montar_motorista()` | NPC atrás do vidro: `Corpo` em pé, afundado até a cintura | `:802` |
| Controles | `_comandos()` lê `mover_*`; freio de mão = `correr` | `:1525`, `:1551` |
| Câmbio | automático (`Motor`) | `motor.gd:303` |
| Luzes | farol e lanterna acesos = motor ligado (`_atualizar_luzes`) | `:2653` |
| Som | `MotorSom` detalhado para o jogador; camada única para a IA | `:740`, `:1507-1513` |
| `Player` ao volante | some (`visible = false`), sem colisão, copia `assento()` todo quadro, **não** é filho do carro | `player.gd:870-888`, `:1015` |
| `CarroCabine` | dois bancos da frente; banco corrido atrás se `ficha.banco_tras` | `cabine_moveis.gd:167-170` |
| `Corpo` | pose `ASSENTO` (coxa na horizontal, mãos no colo); **não há** pose de volante | `corpo.gd:964` |
| Réplica de rede | lataria + rodas do mesmo modelo e tinta, sem física, sem ninguém dentro | `avatar_remoto.gd` |

As seis armadilhas do `VehicleBody3D` (memória do projeto: *VehicleBody3D tem seis armadilhas mudas*) valem para tudo abaixo: frente em −Z, freio morto, *damp* do mundo, congelamento que teleporta, cinemático parado vira NaN, `friction_slip` é μ em g.

## 2. Papéis

| Papel | Quem simula | O que vê |
|---|---|---|
| **Motorista** | a máquina dele: o `VehicleBody3D` de verdade, com o `Motor` | a cabine e o carro dele como hoje, **e os caronas sentados** |
| **Carona** (lugares 1–4) | ninguém: vai **pendurado** na réplica do carro do motorista | a cabine montada na réplica, do banco dele |
| **Observador** | ninguém | a réplica: lataria, rodas girando, faróis, **o motorista e os caronas atrás do vidro** |

## 3. Assentos

### 3.1 Lugares

| Lugar | Onde (referencial do carro: frente −Z, direita +X) | Existe quando |
|---|---|---|
| 0 motorista | `x = CarroCabine.LADO_MOTORISTA` (−0,40) | sempre |
| 1 carona | `x = +0,40`, mesmo `z` | sempre |
| 2, 3, 4 atrás (esquerda, meio, direita) | o banco corrido (`cabine_moveis.gd:172`) | `ficha.banco_tras` (o Fusca, por exemplo, não tem) |

O Marea tem 1 + 4, que é o número da intro co-op (`12`, P10).

A posição sai de uma função pura nova, `CarroCabine.assento(lugar, medidas) -> Transform3D`, com os mesmos números que os bancos usam para se desenhar. Assim o corpo senta **no** banco, e não perto dele.

### 3.2 Pedir e soltar

```
F perto de um carro com motorista (a réplica) ──► _pedir_assento(seq, motorista, lugar = primeiro livre a partir de 1)
servidor: confere distância ≤ 3,2 m (ALCANCE_VEICULO, player.gd:170), lugar livre, carro a < 2 m/s
          ──► _assentos(motorista, [ocupantes]) para todos no interesse
carona: F de novo ──► _pedir_descer(seq)
```

| Caso | Resultado |
|---|---|
| Dois pedem o lugar 1 | o primeiro senta; o segundo recebe o próximo livre; sem livre, "O carro está cheio." |
| Pedir com o carro andando | negado acima de 2 m/s: ninguém pula dentro de carro em movimento |
| Motorista sai | o carro para e fica **estacionado** (§6); os caronas continuam sentados |
| Carona quer dirigir | com o carro estacionado, "Passar para o volante": vira motorista (§6.2) |
| Motorista cai da rede | o carro fica estacionado onde o servidor o viu por último |

## 4. O carona vai pendurado, não posicionado

Este é o ponto que decide se o carona funciona.

A tentação é o carona mandar a própria posição, como qualquer jogador. Faça a conta a 68 km/h (19 m/s):

1. o carona se desenha na réplica do motorista, que já está **120 ms** atrasada;
2. manda essa posição; o motorista a desenha com **mais 120 ms**;
3. no cliente do motorista, o carona aparece **240 ms atrás do carro: 4,5 m, do lado de fora, na estrada.**

A regra: **quem é carona não tem posição.** O estado dele leva `F_CARRO | F_CARONA`, e a extensão de 5 bytes, que no motorista é `(modelo u8, semente s32)`, no carona é `(lugar u8, motorista u32)`. Todo cliente desenha o carona **filho da réplica** (ou do carro de verdade, no cliente do motorista), no `CarroCabine.assento(lugar)`. O servidor usa a posição do motorista para o interesse e a validação do carona.

## 5. O que cada um desenha

### 5.1 Corpos

| Quem | No cliente do motorista | No do carona | No do observador |
|---|---|---|---|
| Motorista | o próprio `Corpo` escondido (1P) ou visível em LONGE/PERTO, como hoje | `Corpo` em pé afundado até a cintura, o mesmo truque do NPC (`carro.gd:811`) | idem |
| Carona | `Corpo` em `ASSENTO`, no lugar dele, **no carro de verdade** | o próprio escondido em DENTRO, visível fora | `Corpo` em `ASSENTO` na réplica |

### 5.2 A réplica do carro (Fase 2, depois 4)

| Detalhe | Fonte | Fase |
|---|---|---|
| Lataria, tinta, rodas | `Carroceria.montar(modelo, tinta, semente)` | ✅ 1 |
| Motorista no banco | §5.1; **no lugar, mas invisível**: o vidro da `Carroceria` é opaco, para o NPC também (`06` §4.3) | ✅ 2 / ⚠ render |
| Faróis e facho na névoa | bit `LANTERNA` no carro = motor ligado (`06` §4.2) | 2 |
| Luz de freio | bit `AGACHADO` no carro = freando | 2 |
| Rodas girando | rapidez / `Carroceria.RAIO_RODA` | 2 |
| Rodas da frente esterçando | `atan(entre_eixos · taxa_de_giro / rapidez)`, da derivada do `yaw` | 2 |
| **Inclinação** (ladeira, curva) | hoje só o `yaw` viaja; +4 B (§7) | 4 |
| Motor | `MotorSom` de camada única com `Motor.giro_aparente(rapidez, modelo)`, igual ao carro da IA | 4 |
| Cabine por dentro | só no cliente do carona (§5.3) | 4 |
| Colisão | caixa `AnimatableBody3D` (`07` §6) | 4 |

### 5.3 A cabine do carona

`CabineDoJogador.montar(dono: VehicleBody3D, …)` pede um `VehicleBody3D`, porque vigia NaN da física (`:165`, `sanear`) e segue o corpo. A réplica não tem física. O carona ganha uma classe irmã e menor, `CabineDoCarona` (`net/cabine_do_carona.gd`), que:

- monta a mesma `CarroCabine` (mesma ficha do modelo) como filha da réplica;
- põe uma câmera no olho do lugar dele (o `olho()` espelhado em X para o lugar 1; recuado e mais baixo atrás);
- usa as mesmas três vistas pela mesma tecla, com LONGE e PERTO orbitando a réplica;
- deixa o mouse olhar em volta com os limites do `OlharAoVolante` (`DENTRO_GUINADA_MAX := 2.0`), que já é o que o motorista tem.

## 6. O carro do grupo

### 6.1 O problema

O carro que um jogador assumiu é um carro **do `Transito` local dele** (`transito.gd:97`, `entregar_ao_jogador`). Quando ele desce, o carro volta para o trânsito **dele**, e no cliente de todo mundo **o carro some**, porque o bit `F_CARRO` apagou. Quem estacionou o Marea na porta da casa e entrou volta e o carro, para os amigos, nunca esteve ali.

### 6.2 Carro estacionado é coisa do mundo

```
Motorista desce
  └► _pedir_estacionar(seq, modelo, semente, transform)        (a máquina dele congela o carro, como hoje)
Servidor
  └► carros_parados[id] = {modelo, semente, transform, dono_antigo}
  └► _carro_parado(id, modelo, semente, transform) para todos no interesse
Cada cliente
  └► instancia um Carro CONGELADO (STATIC), com a mesma lataria e tinta, fora do Transito
```

Alguém aperta F nele: `_pedir_assento(carro_parado = id, lugar = 0)`. O servidor tira da lista e manda `_carro_assumido(id, motorista)`. **Na máquina do novo motorista** o carro congelado vira o carro de verdade (descongela e `assumir`); nas outras, ele some e a réplica do novo motorista toma o lugar, no mesmo quadro lógico.

A troca de dono só acontece com o carro **parado**. Um carro andando não troca de máquina: a física de um lado não continua a do outro, e o carro daria um tranco.

| Caso | Resultado |
|---|---|
| O motorista cai da rede andando | o servidor estaciona o carro onde viu por último, com velocidade zero; os caronas ficam num carro parado |
| Dois pedem o volante do estacionado | o primeiro dirige; o segundo vira carona, se houver lugar |
| O dedicado reinicia | os carros estacionados vão no `mundo.json` (Fase 6) |
| O chunk do carro estacionado descarrega no meu cliente | o carro some comigo e volta quando o chunk volta (a lista é do servidor) |

## 7. Estado do carro

A Fase 1 manda do carro o que manda de uma pessoa: posição, `yaw` e rapidez. Na ladeira (`relevo.gd`, que já passa de 18 m de desnível perto da praça) e na curva, o carro de verdade inclina, e a réplica fica reta, atravessando o asfalto pela frente ou pela traseira.

Extensão do motorista na Fase 4:

| Campo | Tipo | Bytes |
|---|---|---|
| modelo | u8 | 1 |
| semente | s32 | 4 |
| **arfagem do carro** | i16, centésimos de grau | 2 |
| **rolagem do carro** | i16, centésimos de grau | 2 |
| **Total** | | **9** (era 5) |

Sobe a `VERSAO`.

### 7.1 Interpolação de quem está dentro

A interpolação linear da Fase 1 é certa para medir e boa para observar: 0,1 cm de erro a pé. Para **a câmera de quem vai sentado**, ela tem um defeito que o erro em cm não mostra: a velocidade muda de degrau a cada amostra (a cada 50 ms). A 19 m/s, cada trecho tem 95 cm, e a quina entre dois trechos é um tranco de câmera a 20 Hz.

A réplica que carrega um carona usa **Hermite cúbica**: a velocidade em cada amostra é a diferença centrada das vizinhas, e a curva passa pelas amostras com derivada contínua. Custa quatro amostras em vez de duas; o buffer já guarda 40.

Métrica de aceite, e não "parece liso": com o carro a 68 km/h numa curva de 30 m de raio, a **variação da aceleração da câmera do carona** (o *jerk*, terceira derivada da posição desenhada) tem p95 **3× menor** que com a linear.

## 8. Eventos do carro

| Evento | Caminho | Por que não é estado |
|---|---|---|
| Buzina | `_buzina` → interessados, som 3D na réplica | acontece, não dura |
| Batida em outro carro | `_batida(alvo, impulso)` → o motorista do alvo aplica o impulso (`07` §6) | a física do outro é dele |
| Rádio | `_radio(estacao)` → os ocupantes sintonizam; fora, a música sai abafada da réplica (`08` §9) | muda às vezes |
| Seta | bit? não: `_seta(lado)`, porque dura segundos e muda raramente | — |

## 9. Painel e HUD

| Quem | Vê |
|---|---|
| Motorista | o `PainelCarro` de hoje (`painel_carro.gd`: conta-giros, velocímetro, marcha, luzes) |
| Carona | nada de HUD de carro. Em DENTRO, o painel de verdade está na frente dele, na cabine. Fora, o prompt "[F] Descer" |

## 10. Bicicleta

Um lugar (`bicicleta.gd:69`, `montado`). Ninguém vai na garupa. O boneco de quem pedala ganha a bicicleta debaixo dele na Fase 2 (`06` §4.1). O corpo sobre a bicicleta hoje é animado **parado** (`player.gd:988`), sem pose de pedalar; o boneco herda o mesmo.

## 11. A intro não é este carro

`CarroCena` anda em trilho (`carro_cena.gd:2`, `avancar`), sem física, e é a cena cortada da Estrada Velha. É o assunto de `12`. O que as duas coisas compartilham: `CarroCabine`, a pose `ASSENTO` e o `CarroCabine.assento(lugar)` desta fase.

## 12. Aceite da Fase 4

Dois processos na cidade (`mp_dois.sh`), depois três:

| # | Prova | Medida |
|---|---|---|
| 1 | Anfitrião entra no Marea; o convidado vê o corpo dele no banco | foto |
| 2 | Convidado aperta F, senta no carona, câmera de dentro, vê o motorista | foto |
| 3 | Anfitrião dirige a 68 km/h numa curva; o carona não sai do banco | **distância carona–banco no cliente do motorista < 5 cm** em todo quadro (a regra do §4) |
| 4 | Liso para o carona | *jerk* da câmera do carona: Hermite p95 ≤ 1/3 da linear |
| 5 | Ladeira | foto de lado: as quatro rodas da réplica no asfalto, na subida da praça |
| 6 | Motorista desce | o carro fica onde parou, **nos três clientes**, por 60 s |
| 7 | Terceiro jogador assume o estacionado | dirige; os outros veem a troca sem o carro piscar em dois lugares |
| 8 | Motorista cai da rede andando | o carro para para todos; o carona fica sentado |
| 9 | Solo | entrar, dirigir e sair **iguais** a hoje (P16) |

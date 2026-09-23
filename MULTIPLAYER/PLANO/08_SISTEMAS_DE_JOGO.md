# 08 — Sistemas de jogo

> **Versão 2.0 — 21/09/2026.** Reescrito contra o código. A 1.0 era de dois jogadores, com missão única, compra no terminal e save v3.
> Três fatos do código mudaram o desenho: **o dinheiro mora no `WorldState`** (`Dinheiro`, criado em 21/09 com o iWeed, na coordenada `(−8, 424243)`), e em rede o `WorldState` é o mundo de todos, então o saldo viraria uma carteira só para o servidor inteiro (§1.4); **desmaiar pula 3 a 5 horas do relógio** (`desmaio.gd:199`), que em rede é o relógio de todos; e a **porta não guarda estado em lugar nenhum** além do nó (`porta.gd:63`).
> Cada sistema abaixo tem: o que é hoje, com linha; o que vira em rede; quem manda; e a fase.

## Resumo

| Sistema | Em rede | Autoridade | Fase | Arquivo ✋ |
|---|---|---|---|---|
| Mochila e vida | pessoal, **verdade no servidor**, espelho no cliente | S | 3 | `inventario.gd` |
| Dinheiro e iWeed | **pessoal**, fora do `WorldState` do mundo (§1.4) | S | 3 | `dinheiro.gd`, `iweed.gd` |
| Caído e desmaio | **caído** esperando ajuda; desmaio sem pular a hora | S | 3 | `desmaio.gd` |
| Missão | por **grupo** | S | 5 | `missoes.gd`, `hud_missao.gd` |
| Save | anfitrião ou dedicado grava; convidado não | S | 6 | `save_game.gd`, `ponto_de_save.gd` |
| Conversa, diálogo | local; o NPC fica **ocupado** para os outros | S (ocupação) | 3 | `conversa.gd`, `npc.gd` |
| Falas já ditas, profissão, "dono pagou" | mundo | S | 3 | `falas_npc.gd`, `falas_morador.gd`, `profissoes.gd`, `convidado.gd` |
| Plantio | mundo; o crescimento é recalculado igual em todos | S | 3 | `plantio.gd`, `plantacao.gd` |
| Celular, documento, GPS, terminal | local; marca no mapa por grupo | L / S | 5 | — |
| Rádio do carro | do carro: o motorista sintoniza, o carona ouve | motorista | 4 | `radio_carro.gd` |
| Pausa | não pausa em rede | L | 2 | `06` §6 |
| Áudio | local; passo e motor do outro derivados do estado | L | 2 / 4 | — |

---

## 1. Mochila e vida (P8)

### 1.1 Hoje

`Inventario` (autoload, `inventario.gd`): 8 espaços (`ESPACOS := 8`, `:12`), vida 100.

| Função | Linha | Nota |
|---|---|---|
| `adicionar(id, qtd) -> int` | `:103` | devolve **a sobra que não coube** (memória do projeto: *adicionar devolve a sobra*) |
| `remover(id, qtd) -> bool` | `:139` | |
| `usar(indice) -> bool` | `:159` | só cura existe como uso (`Item.Tipo.CURA`) |
| `curar(pontos)` / `ferir(pontos, origem)` | `:175` / `:180` | `ferir` emite `feriu`, que a HUD e o `Desmaio` escutam |
| Sinais | `:14-24` | `mudou`, `item_recebido`, `espaco_insuficiente`, `vida_mudou`, `feriu` |

Quem mexe: `item_no_chao.gd:100` (pegar), `prancha_inventario.gd:865` (usar), `convidado.gd:1226` (bilhete do dono), `falas_npc.gd:352` (entrega), `plantacao.gd:366-368` (colheita), `inimigo.gd:281` (dano), `cidade.gd:1702-1706` (o kit inicial do `_novo_jogo`).

### 1.2 Em rede

```
Servidor: uma MochilaDoServidor por jogador (classe pura, mesmas regras do Inventario)
            │ _mochila(33 B) a cada mudança
            ▼
Cliente:  Inventario = ESPELHO. A prancha, o HUD, `Inventario.tem(&"lanterna")` leem dele, como hoje.
          Toda ESCRITA vira pedido: _pedir_item, _pedir_usar, _pedir_largar, _pedir_dar.
```

- **`MochilaDoServidor`** (`net/mochila_do_servidor.gd`, puro, nível 2) copia as regras de pilha do `Inventario` e **reusa** as definições (`Inventario.definicao(id)` lê os `.tres`, que são disco, não estado).
- **O anfitrião** tem a própria `MochilaDoServidor` como todo mundo, e o `Inventario` dele é espelho dela. Um caminho só.
- **Kit inicial:** quem entra num servidor recebe o kit do `_novo_jogo` (identidade, lanterna, rádio, 2 bandagens, bateria) **do servidor**. Na Fase 6 o dedicado devolve a mochila guardada pelo token.
- **Até a Fase 3 existir**, cada cliente continua com a mochila local de hoje (Fase 1: ninguém pega nada de ninguém).

### 1.3 Dar item a um amigo

O que um co-op de sobrevivência precisa, e a v1 deixava de fora:

```
_pedir_dar(seq, alvo:u32, espaco:u8, qtd:u8)
```

O servidor confere: o alvo a ≤ 2 m, no mesmo espaço, e com lugar. Então faz a transferência **atômica**: tira de um, põe no outro. Se o outro não tem lugar para tudo, a sobra volta para quem deu. O teste confere **os dois lados** (saiu de A = entrou em B + sobra devolvida), porque é exatamente o defeito que já passou duas vezes calado neste projeto.

Na tela: arrastar o item na prancha para o retrato do amigo, que aparece na prancha quando há alguém a ≤ 2 m.

### 1.4 Dinheiro: do jogador, e não do mundo

`Dinheiro` (`systems/dinheiro.gd`, 21/09, outra frente) é um saldo inteiro em reais, com extrato de 24 linhas e ganho total. Mora no `WorldState`, na coordenada `(−8, 424243)`, "para entrar no save como o resto do mundo". Hoje só entra dinheiro pela entrega do iWeed (`world/iweed.gd`, que também guarda pedidos, clientes e relógio próprio em `(−9, 424243)`).

No solo está certo: o save é de uma pessoa. **Em rede não é**: o `WorldState` do servidor é o mundo de todos (`04` §2.2). Com a Fase 3 ligada do jeito ingênuo, o amigo que entrega uma encomenda do iWeed põe o dinheiro na carteira de todo mundo, e quem gasta tira de todos.

A regra: **o que é da pessoa não mora no `WorldState` do mundo em rede.**

| Estado | Solo | Em rede |
|---|---|---|
| Saldo, extrato, ganho | `WorldState (−8, 424243)` | no perfil do jogador no servidor, ao lado da `MochilaDoServidor`; o cliente vê pelo espelho |
| Pedidos e clientes do iWeed | `WorldState (−9, 424243)` | **por jogador**; a equipe de entrega (compartilhada por casa) é decisão de design: o dono da casa é quem contrata, então a equipe é da **casa**, e o que ela ganha vai para quem a contratou |
| Pagar e receber | `Dinheiro.pagar/receber` direto | pedido ao servidor (classe 1 de `04` §4.1): `_pedir_pagar(seq, valor, motivo)`; recebe só por evento do servidor (a entrega que o servidor confirmou) |

O jeito mais barato de chegar lá, sem reescrever o `Dinheiro`: em rede, a `Sessao` aponta a `COORD` para uma faixa **por jogador** (`Vector2i(-8, 424243)` vira a do perfil), e o servidor não difunde essa faixa para os outros. Combinar com a frente do iWeed antes da Fase 3: é arquivo dela.

**Feito na Fase 3, sem tocar nos arquivos dela (22/09):** o `MundoEmRede` trata como pessoal a coordenada inteira `(−8, 424243)` (Dinheiro), a `(−9, 424243)` (iWeed) e a chave `mao` de `(−10, 424245)` (o item na mão no mercado, `estoque_mercado.gd`). Essas chaves:

- **não saem na carga de entrada**: o servidor as tira antes de empacotar. O convidado não herda a carteira do anfitrião;
- **ficam as de quem entra**: o cliente põe as próprias de volta por cima do mundo recebido. A carteira dele continua a dele durante a sessão;
- **não se escrevem pela rede**: o `ValidadorDeMundo` só aceita chave com prefixo `item_` ou `porta_` (lista explícita). Coisa nova entra na lista quando alguém decide que ela é do mundo.

O que falta é o **dinheiro com autoridade do servidor** (`_pedir_pagar`), para o dedicado. No jogo aberto para amigos, cada um cuida da própria carteira, como no solo.

### 1.5 Largar

`_pedir_largar(seq, espaco, qtd)`: o servidor tira da mochila e cria um item no mundo, com chave de sessão `(chunk, "solto_<rev>")`, e difunde `_item_largado(coord, chave, item, qtd, pos)`. Cada cliente instancia um `ItemNoChao` com aquela chave, e ele segue as regras de qualquer item (`04` §4.2). O `WorldState` guarda a lista dos soltos por chunk, para quem entrar depois ver.

---

## 2. Dano

Até a Fase 8, **nada na rua fere ninguém**: `INIMIGO_NA_RUA = false`. As fontes de dano que existem são o inimigo (`inimigo.gd:281`, `DANO := 22`) e o atalho de teste da cidade (`cidade.gd:198`, `:1290`).

Em rede, `ferir` só acontece **no servidor**: o inimigo do servidor bate, o servidor desconta na `MochilaDoServidor` e manda `_ferido(pontos, origem)` ao dono. O `Inventario` espelho do dono chama o próprio `ferir`, que emite `feriu`, e a HUD e o `Desmaio` reagem **como hoje**. O cliente nunca se fere sozinho em rede.

---

## 3. Caído, levantar, desmaio

### 3.1 Hoje

`Desmaio` (`desmaio.gd`) escuta `vida_mudou` e, no zero:

1. trava o jogador (`:161`);
2. escurece;
3. **pula 3 a 5 horas** (`:199`, `HORAS_PERDIDAS := Vector2(3.0, 5.0)`);
4. leva o jogador ao último ponto de save ou de carga (`:218`);
5. espalha os inimigos (`:225`);
6. acorda com vida 45 (`:203`).

### 3.2 O problema

O relógio é de todos (P, `04` §8). Um jogador que cai mandaria a madrugada de todos para o amanhecer.

### 3.3 Em rede: caído, e o amigo levanta

| Tempo | Quem caiu | Os outros |
|---|---|---|
| vida chega a 0 | `F_CAIDO`; o corpo deita (`Corpo.Postura.DEITADO_ACORDAR`); a câmera sai do olho e orbita o corpo; a tela perde a cor | veem o amigo no chão; o nome dele pulsa; o minimapa marca |
| 0–30 s | espera; o contador não aparece (horror não mostra cronômetro); o som abafa | quem chega a ≤ 1,5 m vê **[E] Levantar FULANO**, e segura 3 s |
| levantado | vida 25, pose `LEVANTANDO` (`corpo.gd:790`), controle de volta | — |
| 30 s sem ajuda | apaga; **acorda no último ponto com vida 45, sem pular a hora** | o corpo some; recado "FULANO apagou." |

- Quem decide tudo é o **servidor**: ele sabe a vida, conta os 30 s, confere a distância de quem levanta (`_pedir_levantar(alvo)`) e manda o teletransporte de acordar. É o único teletransporte que sai do servidor, e por isso não precisa de `F_TELEPORTE` confiado ao cliente (`06` §7).
- **Solo não muda:** `Desmaio` segue como hoje, com o pulo de horas. O pulo é bom no solo, e é a punição que o solo tem.
- O "último ponto" de cada um mora no servidor: o orelhão (`ponto_de_save.gd`) em rede **marca o ponto de volta** de quem usou (§4.3).

Por que isso e não só "desmaio sem pular a hora": é o momento do co-op. Sozinho na névoa, cair é o fim. Com um amigo, é uma chance de ser salvo. Custa um estado a mais num sistema que já existe.

---

## 4. Save (P9)

### 4.1 Hoje

`SaveGame` (`save_game.gd`): 3 espaços, JSON em `user://save_%d.json`, `VERSAO := 2`, e **recusa qualquer outra versão** (`:113`, `!=`). Grava `jogador{pos, giro, bateria, lanterna}`, `inventario`, `mundo` (`WorldState.para_dicionario()`), `visitados`, `registro`, `nevoa`, `missao`, `hora`.

Quem grava: **só o orelhão** (`ponto_de_save.gd:79`). Quem carrega: menu (CONTINUAR e CARREGAR) e `cidade.gd:1664`.

### 4.2 Regras

| Modo | Orelhão faz | O save leva |
|---|---|---|
| SOLO | grava, como hoje | igual |
| HOSPEDANDO, anfitrião | grava **o mundo** (com o que os amigos mudaram) e a mochila dele | + campo `convidados: {token: perfil}` (Fase 6) |
| HOSPEDANDO, convidado | **marca o ponto de volta** dele no servidor; não grava nada no disco dele | — |
| DEDICADO | todo orelhão marca o ponto de volta; o servidor grava sozinho a cada 2 min (`18` §10) | `mundo.json` + `jogadores/<token>.json` |

- **Campo novo não vira a versão.** `convidados` entra como `missao` e `hora` entraram: quem lê v2 sem o campo ignora. Virar para v3 **invalida todo save existente**, porque a checagem é `!=`.
- **CONTINUAR um mundo que teve amigos:** abre solo, com tudo o que os amigos mudaram. Ao hospedar de novo, quem voltar com o mesmo token recebe a própria mochila e posição (`convidados[token]`).
- **Convidado não tem save do mundo alheio.** O mundo é do anfitrião. O que é do convidado (a ficha, a carteira) já mora no `RegistroCivil` dele.

### 4.3 Carregar em rede

Cliente **não carrega save** em sessão: CONTINUAR e CARREGAR ficam cinza enquanto `Sessao.em_rede()`. O anfitrião carrega **antes** de hospedar (CONTINUAR → F7 → HOSPEDAR), e o mundo aberto é o do save.

---

## 5. Conversa e diálogo

### 5.1 Hoje

`Conversa.abrir(quem, ficha, contexto)` (`conversa.gd:246`) e `Dialogo.abrir(nome, linhas)` (`dialogo.gd:176`) travam o jogador pelo grupo (`travar(true)`) e **não pausam** a árvore. `Conversa.fechar_a_forca()` existe (`:297`).

### 5.2 Em rede

| Coisa | Regra |
|---|---|
| A caixa de texto, as escolhas | locais: só quem conversa vê |
| O NPC | **ocupado** para os outros enquanto dura (`_pedir_conversa` → `_npc_ocupado`); o [E] dele para o outro diz "Está falando com FULANO" |
| Quais NPC | só os de **id determinístico** (`npc.gd`, convidados, moradores). Pedestre da multidão é local; o amigo nem vê o mesmo pedestre |
| Efeito no mundo | "já falou", profissão, "dono pagou": `Sessao.mudar_mundo` (`04` §4.5) |
| Dano durante a conversa | `Conversa.fechar_a_forca()`. Em rede o mundo não para enquanto se lê |
| O corpo de quem conversa | `F_FALANDO`: o NPC vira para ele no cliente de todos |

---

## 6. Missão por grupo (P7)

### 6.1 Hoje

`Missoes` (`missoes.gd`): **uma** `atual` (`:50`), com `etapas` e `alvo`.

| Etapa | Avança quando | Linha |
|---|---|---|
| 0 | `Gps.destino_mudou` com destino de categoria `casa_fumaca` | `:186-192` |
| 1 | `Interiores.entrou` num `casa_fumaca` | `:197-201` |
| 2 | `Missoes.dono_respondeu()`, chamado pelo convidado | `:210`, `convidado.gd:1214` |

A primeira missão sai de `comecar_primeira(perto_de)` (`:83`), que escolhe a casa mais perto **de quem chama**.

### 6.2 Em rede

- **O servidor guarda uma missão por grupo** (`MissaoDoGrupo`, puro).
- **Quem começa:** a missão do grupo nasce com a posição do **líder** (o anfitrião, ou quem criou o grupo), para todos irem à **mesma** casa.
- **Quem avança:** qualquer membro. O `Missoes` local continua escutando GPS e interior, que são locais. Quando decidiria avançar, em rede ele **pede**: `_pedir_etapa(missao_id, etapa)`. O servidor aceita se a etapa é a atual (o segundo pedido da mesma etapa cai calado) e difunde `_missao` ao grupo.
- **O espelho:** `Missoes.de_dicionario()` (`:266`) já existe. A HUD de missão (`hud_missao.gd`) lê `Missoes.atual`, como hoje. A distância ao alvo é de cada um.
- **Quem entra depois:** recebe a missão do grupo na entrada.
- **Recompensa:** o que é do mundo (o bilhete do dono, `dono_pagou`) sai **uma vez por casa**, para quem conversou. É o mundo decidindo, não a missão.

A mudança em `missoes.gd` ✋ é uma guarda no `avancar()` e no `comecar_primeira()`. O resto do arquivo não muda.

### 6.3 Grupo

| Modo | Grupo |
|---|---|
| HOSPEDANDO | todos no grupo do anfitrião (é o co-op de amigos) |
| DEDICADO | cada um começa sozinho; **convidar** no F7 (depois, na folha de viagem) põe no mesmo grupo |

Grupo com um só jogador é o solo dentro do dedicado: missão própria, mapa próprio.

---

## 7. Celular, documento, GPS, terminal

Telas locais. O terminal é a busca do registro civil (`terminal.gd:82`), sem transação. A consulta de CPF é função pura.

**Marca no mapa, por grupo** (Fase 5): no GPS, "marcar para o grupo" manda `_pedir_marca(pos)`. O servidor difunde ao grupo por 120 s, e o minimapa e o GPS de cada um mostram o ponto com a inicial de quem marcou. É o "olha aqui" que falta a dois amigos que não estão em chamada de voz.

A rota traçada pelo GPS é local: cada um traça a sua, do lugar onde está.

---

## 8. Plantio

`Plantio` (estático, `plantio.gd`) guarda o canteiro em `WorldState` na chave `(semente, INTERIOR)` + `plantio`, com os vasos num `PackedInt32Array`, e o **minuto** da última conta. `sincronizar` recalcula o crescimento pelo relógio (`:293-298`, com a virada da meia-noite) e grava.

Em rede, isso separa duas escritas que hoje são a mesma chamada:

| Escrita | Exemplo | Caminho |
|---|---|---|
| **De jogador** | plantar, regar, colher | `Sessao.mudar_mundo` (colher é classe 1: dá item) |
| **Recalculada** | crescer | **local, sem rede**: todos têm o mesmo relógio e o mesmo estado, então calculam o mesmo número |

Se a recalculada fosse pela rede, cada cliente dentro da estufa mandaria uma mudança por passo da `Plantacao` (`plantacao.gd:112`). A regra: **o que se deduz do relógio não viaja.**

---

## 9. Rádio

| Rádio | Hoje | Em rede | Fase |
|---|---|---|---|
| De mão (`Radio`, filho do `Player`, `player.gd:665`) | chia perto do grupo `inimigo` | local; funciona com o inimigo replicado da Fase 8 | 8 |
| Do carro (`RadioCarro`, autoload, `_estacao`, `radio_carro.gd:70`) | a estação é do autoload; toca sem posição, no bus Music | a estação é **do carro**: o motorista sintoniza, `_radio(estacao)` vai aos ocupantes, e o carona ouve a mesma; **quem está fora** ouve a música do carro do amigo passando, abafada, em 3D | 4 |

---

## 10. Áudio

Local, sempre. O que o outro faz e soa:

| Som | De onde sai | Fase |
|---|---|---|
| Passo do amigo | o boneco, pela distância andada (`06` §4.4) | 2 |
| Porta do amigo | a animação da porta no meu cliente, quando chega `_mundo_mudou` (a `Porta._alternar` já toca o trinco) | 3 |
| Motor do carro do amigo | a réplica, com um `MotorSom` de camada única alimentado por `Motor.giro_aparente(rapidez, modelo)`, que é exatamente como o carro da IA soa (`carro.gd:1513`) | 4 |
| Buzina | evento `_buzina` | 4 |
| Chat | um toque curto de UI | ✅ 1 |

---

## 11. Aceite

| Sistema | Prova (nível 4, bots) |
|---|---|
| Mochila | item disputado: soma das mochilas = 1; `_pedir_dar`: saiu de A = entrou em B + sobra |
| Caído | bot com vida 0: `F_CAIDO`; outro bot a 1 m pede levantar; volta com 25. Sem ajuda: 30 s, acorda no ponto, **relógio contínuo** (sem salto) |
| Missão | três bots no grupo; dois pedem a etapa 1 no mesmo tick: a missão avança **uma** vez |
| Plantio | dois bots na estufa por 60 s de jogo: mesmo estágio calculado, **zero** `_pedir_mundo` de crescimento |
| Save | anfitrião grava, fecha, CONTINUAR: a porta que o convidado abriu está aberta |

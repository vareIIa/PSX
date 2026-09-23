# 04 — Contrato de rede: o que viaja, com que chave, e quem decide

> **Versão 2.0 — 21/09/2026.** Reescrito inteiro. A 1.0 identificava coisa do mundo por **caminho de nó** (`pedido_pegar_item {node_path}`, `pedido_falar {npc_path}`, `assento_mudou {carro_path}`). Esse é o furo 2 da revisão (`19` §2.2): o Godot numera prop sem nome com um contador **do processo**, e `@Porta@37` aqui é `@Porta@112` lá.
> O formato de fio da Fase 1 está em `20`. Este capítulo é o contrato das Fases 3 a 8: **mundo, mochila, assento, conversa, missão, cinema**.
> Regra de entrada: **uma feature que não cabe numa linha da §2 não entra na sessão.**

---

## 1. As cinco caixas

Todo dado do jogo cai em exatamente uma:

| Caixa | O que é | Como chega ao outro | Exemplo |
|---|---|---|---|
| **A — Local** | nunca sai da máquina | não chega | preset PSX/Moderno, névoa visual, FOV, *bob*, fôlego, volume, rota do GPS |
| **B — Determinístico** | os dois calculam igual a partir de semente, coordenada ou id | **não viaja**; a versão do jogo (P18) garante | malha do chunk, relevo, ficha de NPC da rua, porta e seu interior, estrada da intro |
| **C — Contínuo** | muda todo quadro; perder um pacote não importa | 20 Hz, canal 1, bytes (`20` §3–5) | posição, giro, rapidez, flags (lanterna, agachado, carro) |
| **D — Evento** | muda às vezes; perder é bug | confiável, canal 0, RPC na `Sessao` | porta, item, mochila, assento, conversa, missão, chat |
| **E — Carga** | grande, uma vez | confiável, **canal 2** (novo), em pedaços | estado do mundo na entrada, perfil do dedicado |

A caixa E é nova. Mandar 40 KB de `WorldState` no canal 0 **trava o chat e todos os eventos** atrás dele até o último pedaço chegar, porque o canal confiável do ENet é ordenado. Num canal próprio, a carga anda em paralelo. Criar o terceiro canal muda o `create_server(porta, max, 2)` para `3`, e isso sobe `ProtocoloRede.VERSAO`.

---

## 2. Tabela mestra

Autoridade: **S** = servidor, **D** = dono (o cliente que controla), **L** = cada um local.
Fase: onde a linha passa a valer. ✅ = já no código.

### 2.1 Pessoa

| Dado | Caixa | Autoridade | Caminho | Fase |
|---|---|---|---|---|
| Posição, giro, rapidez | C | D, S valida | `_estado_do_cliente` → `_instantaneo` | ✅ 1 |
| Agachado, correndo, lanterna, no chão | C | D | bits de `flags` | ✅ 1 |
| **Arfagem da cabeça** (para onde olha) | C | D | +1 byte no estado (`u8`, −80°..+80°) | 2 |
| Espaço (rua, estrada, interior) | C | D, S confere salto | campo `espaco` | ✅ 1 |
| Teletransporte próprio | C | D | `F_TELEPORTE` | ✅ 1; anúncio completo na 2.3 |
| Nome, aparência | D | D na entrada, S saneia | autenticação → perfil | ✅ 1 |
| Aparência trocada no meio da sessão | D | D, S saneia | `_pedir_perfil` → `_perfil_mudou` | 7 |
| Vida | D | **S** | `_vida` para o dono; bit `F_FERIDO` para os outros | 3 |
| Caído (esperando ajuda) | C + D | S | bit `F_CAIDO`; `_pedir_levantar` | 3 (`08` §3) |
| Mochila (8 espaços) | D | **S** | `_mochila` só para o dono | 3 |
| Fôlego, bateria em %, *bob*, FOV | A | L | — | — |
| Passo (som) | derivado de C | L | quem desenha toca pela rapidez | 2 |
| Gesto (acenar, apontar) | D | D | `_pedir_gesto` → `_gesto` | 7 |

### 2.2 Mundo

| Dado | Caixa | Autoridade | Chave | Fase |
|---|---|---|---|---|
| Chunk, prédio, poste, relevo | B | — | coordenada | ✅ |
| Hora da cidade | D | S | — (`_relogio` a cada 5 s) | ✅ 1 |
| Item no chão pego | D | S | `(chunk, item_<indice>)` — já é a do `ItemNoChao.chave()` | 3 |
| Porta aberta/fechada | D | S | `(chunk, porta_<xyz>)` por posição (§3.3) | 3 |
| Porta de fachada (vira interior) | B | — | `semente` da porta | — |
| Canteiro | D | S | `(semente, INTERIOR)` + `plantio` — já é a do `Plantio.coord()` | 3 |
| Fala de NPC já dita, profissão, "dono pagou" | D | S | as chaves que o código já grava (`08` §1) | 3 |
| Chunks visitados (mapa) | D | **S, união** | `WorldState.visitar` | 3 |
| Estado inteiro do mundo, na entrada | E | S | `para_dicionario()` + `rev` | 3 |
| Clima visual, chuva | A | L | — | — |

### 2.3 Gente e coisa que anda

| Dado | Caixa | Autoridade | Fase |
|---|---|---|---|
| Pedestre de rua, carro de trânsito | A (*flavor*) | L | — (P, `07` §6) |
| Carro dirigido por jogador | C | motorista (P6) | ✅ 1 réplica; 4 completo |
| Assento de carro (quem senta onde) | D | S | 4 |
| NPC em conversa com alguém (ocupado) | D | S | 3 |
| NPC abordado, blitz, inimigo | C + D | S | 8 (precisa de chão no servidor) |
| Convidado da casa da fumaça | B + D | S para "ocupado" | 3 |

### 2.4 Jogo

| Dado | Caixa | Autoridade | Fase |
|---|---|---|---|
| Grupo (quem joga junto) | D | S | 5 |
| Missão do grupo e etapa | D | S | 5 |
| Pino de destino da missão | D | S (vem da missão) | 5 |
| Marca livre no mapa ("olha aqui") | D | quem marcou, só para o grupo | 5 |
| Rota do GPS, celular, documento, terminal | A | L | — |
| Cena cortada: plano, tempo, fala | D | S | 7 |
| Chat, recados | D | S | ✅ 1 |
| Save | A (disco) | quem hospeda / o dedicado | 6 |

---

## 3. Identidade: como se nomeia uma coisa do mundo

### 3.1 A regra

**Coisa do mundo é `(coord: Vector2i, chave: StringName)`**: exatamente a forma que o `WorldState` já usa (`definir(coord, chave, valor)`). Nunca caminho de nó, nunca `get_instance_id()`, nunca nome de nó.

O `WorldState` já tem quatro faixas de `coord`, e todas são determinísticas:

| Faixa | `coord` | Quem usa |
|---|---|---|
| Rua | `Vector2i(cx, cz)` do chunk | item, porta, fala de morador |
| Interior | `Vector2i(semente, 424242)` (`WorldState.INTERIOR`) | item de interior, canteiro |
| Pessoa | `Vector2i(id, 424243)` (`FalasNpc.PESSOA`) | fala já dita, personagem |
| Folha de vagas | `Vector2i(0, 424244)` (`Profissoes.FOLHA`) | profissões |

A faixa de pessoa (`424243`) também guarda, em ids **negativos**, três coisas que não são de NPC nenhum:

| `coord` | O quê | Em rede |
|---|---|---|
| `(−7, 424243)` | `EntregasDaSuper.COORD` | mundo |
| `(−8, 424243)` | `Dinheiro.COORD`: saldo, extrato (21/09) | **por jogador** (`08` §1.4) |
| `(−9, 424243)` | `IWeed.COORD`: pedidos, clientes (21/09) | **por jogador** (`08` §1.4) |

Não colidem com NPC (ids de NPC são positivos), mas a faixa virou gaveta de coisa avulsa, e duas delas são da **pessoa**, não do mundo. A Fase 3 precisa separar: ou uma faixa nova para estado pessoal (`424245`), que o servidor guarda por jogador e não difunde, ou o `Dinheiro` e o `IWeed` passam a ler a coordenada de um perfil. Decidir com a frente do iWeed.

### 3.2 O que já tem chave, e o que não tem

| Coisa | Chave hoje | Serve para a rede? |
|---|---|---|
| `ItemNoChao` | `chunk` + `item_%d % indice` (`item_no_chao.gd:40`) | **sim**, se `indice` sai da ordem do gerador (sai: é o índice do prop na lista do chunk) |
| Canteiro | `Plantio.coord(semente)` + `plantio` | sim |
| Fala de NPC | `(id, PESSOA)` + `npc_<chave>` | sim, **se** o `id` do NPC for determinístico (é: sai da semente do chunk; o do **jogador** é que é sorteado) |
| `Porta` | **nenhuma**: estado em `_aberta`, só no nó (`porta.gd:63`) | não. Precisa de chave (§3.3) |
| `Porta.semente` | `77000 + cx·419 + cz·787` (`chunk_builder.gd:357`) | é **por chunk**, não por porta: duas portas do mesmo chunk têm a mesma. Serve para escolher o interior, não para identificar a folha |
| Carro de trânsito | nenhuma; `randf` por processo | não, e não precisa (*flavor*) |
| Carro de jogador | id do motorista + `modelo` + `semente` no estado | sim |

### 3.3 Chave por posição, para o que o gerador não numerou

A porta de rua não tem índice. Em vez de mexer no `chunk_builder` (✋, outra frente) para dar um, a chave sai de onde o gerador a pôs, que é determinístico:

```
chave = "porta_%d_%d_%d" % [round(local.x*10), round(local.y*10), round(local.z*10)]
local = posição da porta relativa à origem do chunk (ou do interior), em decímetros
```

Duas máquinas com a mesma `VERSAO` põem a mesma porta no mesmo decímetro, e duas portas não ocupam o mesmo decímetro. A função fica em `ChaveMundo.de_posicao(no, coord)` (classe pura, nível 2), e vale para qualquer coisa do mundo sem índice: gaveta, TV, luz, cadeira.

**O que ela não aguenta:** o gerador mudar a posição da porta. Aí as duas máquinas discordam, mas isso já é versão diferente, e a P18 recusa na entrada.

### 3.4 Pessoas

| Quem | Identidade na sessão | Identidade que persiste |
|---|---|---|
| Jogador | `peer_id` (u32, do ENet) | token local (P21, Fase 6); SteamID (Fase 9) |
| NPC da rua | `id` do `RegistroCivil`, determinístico | o mesmo |
| NPC do servidor (blitz, inimigo) | id de sessão dado pelo servidor | não persiste |

O `peer_id` muda a cada conexão. **Nada que persiste é gravado por `peer_id`.**

---

## 4. Mudança de mundo: o fluxo

### 4.1 Três classes de interação

A latência de um dedicado na internet é de 60 a 150 ms de ida e volta. Esperar a confirmação para **tudo** deixa o jogo mole; confirmar **nada** abre duplicação. Cada interação cai numa classe:

| Classe | Regra | Quando usar | Exemplos |
|---|---|---|---|
| **1 — Espera** | o efeito só acontece quando o servidor confirma; o gesto (som, animação da mão) toca na hora | recurso disputado ou que não se desfaz | pegar item, pegar do canteiro, sentar num banco de carro, abrir conversa com NPC |
| **2 — Prevê** | o efeito acontece na hora, o pedido vai junto; se o servidor negar, volta ao valor dele | reversível, e duas pessoas querendo a mesma coisa dão o mesmo resultado | porta, luz, TV, gaveta |
| **3 — Local** | não viaja | só importa para quem fez | rota do GPS, olhar o celular, abrir a prancha |

Na classe 1, o que evita a sensação de atraso é o **gesto imediato**: a mão vai ao item e o som de pegar toca no quadro do [E]. O item some quando a confirmação chega, **1 RTT depois** (≈ 100 ms). O `ItemNoChao._sumir` já dura 0,2 s de animação, então a espera fica dentro dela.

### 4.2 O caminho de um pedido (classe 1)

```
Cliente                                  Servidor                                  Outros
───────                                  ────────                                  ──────
[E] no item
 gesto + som (local)
 pedido_seq = ++n
 _pedir_item(seq, cx, cz, indice) ──►   valida (§6)
                                          ok: WorldState.definir(coord, chave, true)
                                              rev = ++rev_global
                                              mochila do remetente += item
      ◄── _mundo_mudou(rev, coord, chave, true, autor, seq) ──────────────────────►  aplica no dicionário
      ◄── _mochila(bytes)                                                            e no nó vivo, se houver
 item some, entra na mochila
                                          negado: ──► _negado(seq, motivo)
 ◄──                                                  "Alguém pegou antes." / "Mochila cheia."
 o gesto termina sem item
```

### 4.3 O caminho de uma previsão (classe 2)

```
Cliente A: [E] na porta → a porta abre JÁ → pendente[chave] = (valor=true, seq)
           _pedir_mundo(seq, coord, chave, true) ──► servidor
Servidor:  aceita → rev++ → _mundo_mudou(rev, ..., autor=A, seq) a todos
Cliente A: recebe o próprio seq → tira de pendente; nada muda na tela
Cliente B: recebe → a porta dele abre com a mesma animação
```

Se B mandou "fechar" no mesmo tick, o servidor aplica os dois **na ordem de chegada**, e todos terminam no mesmo valor final. Se A tinha a chave pendente e chegou uma mudança de outro autor, A abandona a previsão e mostra o valor do servidor. A porta anima para lá, sem estalo.

### 4.4 Revisão

- O servidor tem um contador `rev` (u32) que sobe a cada mudança aceita.
- Todo `_mundo_mudou` leva o `rev`.
- O estado de entrada (caixa E) leva o `rev` do instante em que foi montado.
- O cliente descarta `_mundo_mudou` com `rev ≤ rev_da_entrada`. Isso cobre a corrida entre a carga no canal 2 e o evento no canal 0: canais diferentes não têm ordem entre si.
- O cliente guarda o que chegou no canal 0 **durante** a carga e aplica depois dela.

### 4.5 Onde o código do jogo se liga

Hoje os 14 `WorldState.definir` do jogo acontecem **depois** de o efeito ter sido aplicado no nó. Isso é exatamente a classe 2. Para esses, a troca é uma linha:

```gdscript
# antes
WorldState.definir(chunk, chave(), true)
# depois
Sessao.mudar_mundo(chunk, chave(), true)   # SOLO: chama WorldState.definir e pronto
```

A classe 1 muda mais, porque o efeito precisa esperar. O padrão é o `ItemNoChao`:

```gdscript
func interagir(quem: Node) -> void:
	if not Sessao.em_rede():
		_pegar_local()            # o código de hoje, intacto (P16)
		return
	_gesto_de_pegar()
	var r: Dictionary = await Sessao.pedir_item(chunk, indice, item_id, quantidade)
	if r.ok:
		_sumir()                  # a mochila já chegou pelo _mochila
	else:
		_recusar(r.motivo)
```

E o nó vivo precisa **ouvir** mudança que não fez. O `WorldState` hoje não emite nada: os nós leem o estado quando nascem, e ninguém muda o mundo por baixo deles. A Fase 3 acrescenta **um** sinal:

```gdscript
signal mudou(coord: Vector2i, chave: StringName, valor: Variant)
```

emitido em `definir`. `Porta`, `ItemNoChao` e `Plantacao` conectam no `_ready` e reagem só à própria chave. O custo é uma comparação por nó interessado a cada mudança, e mudança de mundo é rara (menos de 1 por segundo por jogador).

---

## 5. Eventos (RPCs) da Fase 3 em diante

Todos na `Sessao` (regra 4 de `00`). Nomes: pedido do cliente começa com `_pedir_`, e o que o servidor afirma vem no particípio (`_mudou`, `_negado`). Payload **tipado**, sem `Dictionary` quando der, porque o `Dictionary` custa oito vezes mais (`20`).

### 5.1 Mundo (Fase 3)

| RPC | Direção | Canal | Payload | Valida |
|---|---|---|---|---|
| `_pedir_mundo` | C → S | 0 | `seq:u32, cx:i32, cz:i32, chave:StringName, valor:Variant` | §6; `valor` só `bool/int/float/String/StringName/Vector2i/Vector3/PackedInt32Array` ≤ 256 B |
| `_mundo_mudou` | S → todos | 0 | `rev:u32, cx, cz, chave, valor, autor:u32, seq:u32` | — |
| `_negado` | S → um | 0 | `seq:u32, motivo:u8` | — |
| `_pedir_item` | C → S | 0 | `seq, cx, cz, indice:i32, item:StringName, qtd:u8` | §6 + item na tabela de coisas que nascem no chão |
| `_estado_de_mundo` | S → quem entrou | **2** | `rev:u32, parte:u16, total:u16, bytes` | — |

`_estado_de_mundo` leva `var_to_bytes([WorldState.para_dicionario(), WorldState.visitados_para_lista()])` sem o estado pessoal (`08` §1.4). Vai comprimido com `compress(FileAccess.COMPRESSION_ZSTD)`, com o tamanho bruto num `u32` na frente, e cortado em pedaços de **16 KB**. O cliente trava a interação com o mundo (não o andar) até a carga fechar: sem isso, ele abriria uma porta que o servidor já sabe aberta.

**Mudou na implementação (22/09): não existe `_mundo_pronto`.** A v2.0 deste capítulo mandava um "pronto" no canal 0 depois dos pedaços no canal 2. Só que **canais diferentes não têm ordem entre si**: o "pronto" podia chegar antes dos dados que anunciava. A carga se fecha pelo último pedaço, porque cada pedaço traz `parte` e `total`, e o servidor marca quem entrou como pronto ao terminar de enviar. Pedido de mundo antes disso não acontece, porque o cliente trava a interação até ter a carga inteira.

**Onde mora:** os RPCs de mundo ficam em `/root/Sessao/Mundo` (`MundoEmRede`, filho da `Sessao`), e não na própria `Sessao`, que já passava de 1.400 linhas. O caminho é o mesmo em todo processo pelo mesmo motivo do autoload.

### 5.2 Pessoa (Fase 3)

| RPC | Direção | Payload |
|---|---|---|
| `_mochila` | S → dono | `bytes`: 8 × (`u16` índice no catálogo, `u16` qtd) + `u8` vida = 33 B |
| `_pedir_usar` | C → S | `seq, espaco:u8` |
| `_pedir_largar` | C → S | `seq, espaco:u8, qtd:u8` (o item vira `ItemNoChao` com chave de sessão, `08` §2) |
| `_ferido` | S → dono | `pontos:u8, origem:Vector3` (a HUD pisca e o `Desmaio` escuta, como hoje) |
| `_pedir_levantar` | C → S | `alvo:u32` (levantar quem caiu, `08` §3) |

### 5.3 Carro (Fase 4)

| RPC | Direção | Payload |
|---|---|---|
| `_pedir_assento` | C → S | `seq, motorista:u32, lugar:u8` (0 = motorista, 1 = carona, 2–4 = atrás) |
| `_assentos` | S → interessados | `motorista:u32, PackedInt32Array` (quem está em cada lugar, 0 = vago) |
| `_pedir_descer` | C → S | `seq` |
| `_buzina`, `_farol` | C → S → interessados | `u8` (evento, não estado: a buzina não precisa de 20 Hz) |

### 5.4 NPC e conversa (Fase 3; NPC do servidor na 8)

| RPC | Direção | Payload |
|---|---|---|
| `_pedir_conversa` | C → S | `seq, npc:i32` (id do `RegistroCivil`) |
| `_npc_ocupado` | S → todos no espaço | `npc:i32, com:u32` (0 = livre) |

### 5.5 Grupo e missão (Fase 5)

| RPC | Direção | Payload |
|---|---|---|
| `_pedir_grupo` | C → S | `acao:u8` (convidar, aceitar, sair), `alvo:u32` |
| `_grupo` | S → membros | `grupo:u32, PackedInt32Array` |
| `_missao` | S → membros | `bytes` (`Missoes.para_dicionario()` do grupo) |
| `_pedir_marca` | C → S | `pos:Vector3` |
| `_marca` | S → grupo | `autor:u32, pos:Vector3, validade_s:u8` |

### 5.6 Cena cortada (Fase 7)

| RPC | Direção | Payload |
|---|---|---|
| `_cena` | S → participantes | `cena:u8, plano:u8, t_servidor:f64` (começa o plano **naquela hora do servidor**, não na chegada do pacote) |
| `_pedir_pular` | C → S | — (voto; §7 de `12`) |

---

## 6. O que o servidor confere em todo pedido

Na ordem, e o primeiro que falhar responde `_negado(seq, motivo)`:

| # | Confere | Contra o quê | Motivo |
|---|---|---|---|
| 1 | Remetente está na lista e o servidor já terminou de mandar a carga de entrada a ele | `jogadores` | (descarta calado) |
| 2 | Cota | 10 pedidos de mundo por segundo por jogador, balde furado | (descarta calado) |
| 3 | Mesmo espaço | `coord` na faixa de interior só vale para quem está naquele interior; faixa de rua só para quem está na rua | `ESPACO` |
| 4 | Alcance | distância do último estado **aceito** do remetente à coisa ≤ `ALCANCE_INTERACAO` (2,4 m, `player.gd:124`) + 1,5 m de folga para a latência. Na faixa de rua, a coisa está no chunk `coord`: o servidor confere pelo menos que o jogador está a ≤ 1 chunk dela | `LONGE` |
| 5 | Estado | item ainda não pego; assento vago; NPC livre | `JA_FOI` / `OCUPADO` |
| 6 | Espaço na mochila (item) | `Inventario` do remetente no servidor | `CHEIO` |

**O limite honesto da conferência 4 na Fase 3:** o dedicado não monta chunk. Ele sabe onde o jogador está, mas **não sabe** onde a porta está. A folga cobre o jogador honesto, e o desonesto só consegue abrir porta a até ~45 m (a diagonal do chunk mais a folga). Em servidor de amigos, é aceitável. A Fase 8 dá ao servidor as posições (o gerador sem malha, `07` §4) e aperta para 2,4 + 1,5 m de verdade.

**O que o servidor não confere na Fase 3:** que o item `X` realmente existe no índice `i` do chunk. O cliente diz qual item pegou, e o servidor aceita se `X` está na tabela de coisas que nascem no chão e se `(chunk, i)` ainda não foi pego. Um trapaceiro consegue trocar um item comum por outro da mesma tabela, uma vez por índice. Fecha na Fase 8, junto com a conferência 4.

---

## 7. Corridas, e como cada uma termina

| Corrida | Resultado |
|---|---|
| Dois pedem o mesmo item no mesmo tick | o servidor processa na ordem de chegada; o primeiro leva, o segundo recebe `JA_FOI` e ouve "Alguém pegou antes." |
| Um abre e outro fecha a mesma porta | os dois veem o valor final do servidor, com animação, sem estalo (§4.3) |
| Dois pedem o banco da frente | o primeiro senta; o segundo recebe `OCUPADO` e o jogo oferece o próximo lugar livre (`09` §3) |
| Dois abordam o mesmo NPC | o primeiro conversa; o segundo vê "Está falando com FULANO." no rótulo do [E] |
| Pedido chega e o remetente já caiu | o servidor descarta; nada fica pela metade porque cada pedido é atômico no servidor |
| Mudança chega durante a carga de entrada | guardada, aplicada depois, descartada se `rev ≤ rev_da_entrada` (§4.4) |
| Cliente pega item com a mochila cheia em outro lugar (desincronizada) | a mochila do servidor é a verdade; `CHEIO`, e o `_mochila` seguinte acerta a tela |
| Anfitrião (HOSPEDANDO) pega item | passa pelo mesmo `_pedir_item`, chamado localmente (latência zero). **Um caminho só**, para o anfitrião não ter regra diferente |

---

## 8. Relógio

**Estado: ✅ Fase 1.** O servidor manda `_relogio(segundos)` a cada 5 s, e o cliente acerta se descolou mais de 1 s. Entre acertos, a HUD de cada um anda o relógio localmente (`hud_cidade.gd:133`); o dedicado anda sozinho (`sessao.gd:751`).

Três escritas de relógio no jogo precisam passar pelo servidor em rede:

| Quem escreve | Hoje | Em rede |
|---|---|---|
| `SaveGame.carregar` (`save_game.gd:129`) | põe a hora do save | só o anfitrião antes de hospedar; cliente não carrega save (P9) |
| `Desmaio._aplicar` (`desmaio.gd:199`) | **pula 3 a 5 horas** | **não mexe no relógio**: a hora é de todos (`08` §3) |
| `WorldState.limpar()` | **troca o objeto** `relogio` | a `Sessao` relê `WorldState.relogio` a cada uso, nunca guarda a referência |

---

## 9. Orçamento de banda

Por cliente, a 20 Hz, antes da compressão:

| Fluxo | Bytes/s | Observação |
|---|---|---|
| Subida: estado próprio | 33 × 20 = **660** | 760 de carro |
| Descida: instantâneo com 8 por perto | 202 × 20 = **4.040** | medido: 3,1 KB/s depois da compressão |
| Descida: instantâneo com 16 | 418 × 20 = **8.360** | medido: 5,9 KB/s |
| Eventos de mundo | < 100 | mudança é rara |
| Entrada: estado do mundo | 5–60 KB uma vez | medir na Fase 3 com um save de 2 h de jogo |

Teto de projeto: **16 KB/s de descida por cliente**. Cabe em qualquer conexão doméstica. O que faz passar disso é gente demais no mesmo lugar (acima de 32), e a resposta é o interesse (P19) apertar, não a compressão.

---

## 10. O que nunca entra num pacote

- Shader, material, textura, malha, `ArrayMesh` de chunk
- `Settings`, preset visual, névoa visual, volume, bus de áudio
- Estado do menu de opções, `CaptureTool`, flags `--shot`
- O save inteiro de alguém (o dedicado grava o próprio, P9)
- Caminho de nó, `get_instance_id()`, `RID`
- Objeto (`Variant` com `Object`); o `SceneMultiplayer` já recusa por padrão, e ninguém liga
- Texto de conversa digitando letra a letra: viaja a fala fechada ou o id da escolha
- A arfagem do olhar **dentro** de menu, celular ou cena cortada (fica a última do jogo)

---

## 11. Como se prova cada linha

| Linha | Nível 2 (classe pura) | Nível 4 (bots) |
|---|---|---|
| `ChaveMundo.de_posicao` | mesma posição = mesma chave; 1 dm de diferença = chave diferente; coord negativa | — |
| Validação de pedido (§6) | `ValidadorDeMundo.julgar(pedido, estado, quem)`: cada motivo | — |
| Revisão e pendentes (§4.3–4.4) | `EspelhoDeMundo`: previsão confirmada, previsão derrubada, evento velho descartado | — |
| Item disputado | — | `--bot-pegar=cx,cz,i` em dois bots no mesmo tick: **um** credita, a soma das mochilas = 1 (memória do projeto: *adicionar devolve a sobra*; conferir os dois lados da transferência) |
| Porta | — | bot abre, outro bot lê `WorldState` = aberta; terceiro bot entra depois e também lê aberta |
| Carga de entrada | tamanho de 1 h de jogo simulada | tempo até a carga fechar com 50 KB, e o chat durante a carga não atrasa mais que 1 tick |

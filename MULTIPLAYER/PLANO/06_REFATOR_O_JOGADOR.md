# 06 — O jogador local e os outros

> **Versão 2.0 — 21/09/2026.** Reescrito. A 1.0 se chamava "Refator: o jogador" e mandava tirar o `Player` da cena, spawnar um por peer e trocar os 32 `get_first_node_in_group(&"player")` por quatro APIs **antes** de o amigo aparecer.
> A v2 inverteu isso: o `Player` local não muda, e os outros são bonecos (`03` §4). Este capítulo diz o que ainda muda no jogo para ele funcionar com mais gente (Fase 2), e o que o boneco precisa mostrar para o outro **parecer uma pessoa** e não um marcador.

## 1. Os números de hoje

| Fato | Valor (21/09) |
|---|---|
| `get_first_node_in_group(&"player")` no jogo | **43** em **31** arquivos (+1 na `Sessao`, que é a única permitida em código de rede) |
| O que mudou desde a v1 | 31 → 43. O último a entrar foi `world/mirante.gd` (outra frente, local, névoa) |
| `_player` em `cidade.gd` | **193** linhas |
| Grupo `player` | só `player.gd:203` entra nele |
| `is_in_group(&"player")` | `carro.gd:2013`, `carro.gd:2422`, `transito.gd:260` (batida e atropelo: quem bateu foi o jogador?) |

Nenhum deles impede o amigo de aparecer, porque o boneco não está no grupo. O que eles impedem é o jogo **reagir** ao amigo: o pedestre desviar dele, o NPC olhar para quem fala, o inimigo escolher quem perseguir.

## 2. Três papéis

| | Jogador local | Boneco (`AvatarRemoto`) | Dedicado |
|---|---|---|---|
| Classe | `Player` | `AvatarRemoto` | — (nenhum corpo) |
| No grupo `player` | sim | não | — |
| Física | `CharacterBody3D` | nenhuma; trilha interpolada | — |
| Câmera, input, HUD, mochila | sim | não | não |
| Quem decide onde ele está | ele | a outra máquina | cada cliente |
| Papel no Unreal | *autonomous proxy* | *simulated proxy* | *authority* sem pawn |

O anfitrião (HOSPEDANDO) é servidor **e** jogador local. Tudo o que o servidor faz por um cliente, ele faz pelo anfitrião pelo mesmo caminho, chamado localmente, com latência zero. Não existe "regra do anfitrião" diferente (`04` §7, última linha).

## 3. O que o `Player` precisa expor

A `Sessao` lê hoje dois campos privados por reflexão:

```gdscript
p.get(&"_agachado") == true      # sessao.gd, _estado_local
p.get(&"_bike") != null
```

Funciona, e é frágil: se a outra frente renomear o campo, a rede passa a mandar "nunca agachado" sem nenhum erro. A Fase 2 troca por **acessores só de leitura**, que não mudam comportamento nenhum:

| Acessor novo em `player.gd` | Lê | Para quê |
|---|---|---|
| `agachado() -> bool` | `_agachado` | bit `F_AGACHADO` |
| `arfagem() -> float` | `_pitch` | a cabeça e a lanterna do boneco (§4.2) |
| `na_bicicleta() -> Bicicleta` | `_bike` | bit `F_BICICLETA` e a bike sob o boneco |
| `ocupado() -> bool` | `_ocupacao.is_valid()` | bit `F_SENTADO` (sofá, cadeira, PS2) |

São quatro funções de uma linha num arquivo ✋. Combinar antes; ninguém da outra frente perde nada.

## 4. O boneco: o que o outro vê

A régua é: **um amigo olhando para você deve entender o que você está fazendo sem ler o chat.**

### 4.1 Tabela

| O que eu faço | O que o outro vê | Estado |
|---|---|---|
| Ando, corro | o mesmo `Corpo`, com o passo animado pela rapidez | ✅ 1 |
| Agacho | o corpo encolhe (a mesma escala do `player.tscn`) | ✅ 1 |
| Ligo a lanterna | o cone de luz na névoa, **antes** do corpo | ✅ 1 (sempre 8° para baixo) |
| Olho para cima ou para baixo | a lanterna aponta para onde eu olho | **2** (arfagem) |
| Passo | o som do passo, no lugar certo, madeira dentro e concreto fora | **2** |
| Dirijo | a lataria do mesmo modelo e tinta | ✅ 1 |
| … com o motor ligado | **faróis acesos**, facho na névoa | **2** |
| … freando | **luz de freio** | **2** |
| … andando | **rodas girando** e as da frente esterçando | **2** |
| … e eu estou lá dentro | **meu corpo no banco do motorista**, como o NPC do trânsito | **2** |
| Estou de bicicleta | a bicicleta debaixo de mim | **2** |
| Sento no sofá | o corpo sentado, na pose `ASSENTO` | **2** |
| Estou no menu, na prancha ou no celular | o nome esmaecido, com "…" | **2** |
| Estou ferido | andar mais pesado (rapidez menor de animação) | 3 |
| Caí | o corpo no chão (`DEITADO_ACORDAR`), e o [E] "Levantar FULANO" | 3 (`08` §3) |
| Converso com um NPC | o NPC olha para mim, e o [E] dele diz "Está falando com FULANO" | 3 |
| Aceno, aponto | o gesto | 7 |

### 4.2 O estado v2 (23 bytes)

Os oito bits de `flags` da v1 estão quase cheios (`1 AGACHADO · 2 CORRENDO · 4 LANTERNA · 8 NO_CHAO · 16 CARRO · 32 BICICLETA · 64 TELEPORTE`). A Fase 2 põe dois bytes, e sobe `VERSAO` para 2:

| Campo | v1 | v2 |
|---|---|---|
| pos | 3 × f32 | igual |
| yaw | u16 | igual |
| rapidez | u16 cm/s | igual |
| **arfagem** | — | **u8**: −80°..+80° em 255 passos (0,63°) |
| flags | u8 | **u16** |
| espaço | u32 | igual |
| **Total** | 21 B | **23 B** |

Bits novos: `128 SENTADO · 256 AUSENTE · 512 FERIDO · 1024 CAIDO · 2048 FALANDO`.

**Dentro do carro, três bits mudam de sentido.** A pé eles não se aplicam ao carro, então o carro os reaproveita sem gastar byte:

| Bit | A pé | Com `F_CARRO` |
|---|---|---|
| `LANTERNA` | lanterna ligada | motor ligado = farol aceso (a regra do `Carro._atualizar_luzes`) |
| `AGACHADO` | agachado | freando (luz de freio) |
| `CORRENDO` | correndo | freio de mão puxado |

O custo: 2 B × 20 Hz × n no instantâneo. Com 16 jogadores, +640 B/s por cliente, ou +11 % sobre os 5,9 KB/s medidos.

### 4.3 Onde o boneco senta no carro

O `Carro` já põe gente atrás do vidro: `_montar_motorista` (`carro.gd:802`) põe um `Corpo` em pé, afundado até a cintura, em `(−largura·0,24, −0,36, −comprimento·0,04)`. O jogo não tem pose de volante (`Corpo.Postura` não tem). O boneco do motorista usa **o mesmo número**: o amigo ao volante fica igual a qualquer motorista da cidade.

**Medido em 21/09: nenhum dos dois aparece.** O vidro da `Carroceria` é uma cor opaca na malha da lataria (`carroceria.gd:176`, `VIDRO = (0,20; 0,23; 0,27)`), e as fotos de lado e de frente, a 5–9 m, mostram o vidro escuro e nada dentro. O comentário do `Carro` ("o que se vê pelo para-brisa é tronco, ombro e cabeça") é de antes do vidro atual. O corpo está no banco e aparece no dia em que o vidro deixar ver: é decisão da frente de render, e é pré-requisito da abertura co-op (`12` §3), que depende de "cabeças atrás do vidro".

A pose `Corpo.Postura.ASSENTO` (`corpo.gd:964`, coxa na horizontal, mãos no colo) é a do **carona** (Fase 4), que não tem volante para segurar.

### 4.4 Passos

O `Player` toca o próprio passo por `AudioDirector.passo(superficie, pos, forca)` (`player.gd:601`), com `superficie()` = madeira dentro de interior e concreto fora. O boneco acumula a distância desenhada e toca um passo a cada **0,75 m**, com a mesma superfície pelo espaço dele e a mesma força (`rapidez / VEL_CORRER`). Agachado não toca (a regra do `Player._ao_dar_passo`). Acima de **25 m** do ouvinte não toca: o `AudioDirector` já atenua, e 16 amigos andando longe viram ruído.

## 5. Sistemas que precisam enxergar os outros

### 5.1 A API

```gdscript
Sessao.jogador_local() -> Player                      # o do grupo; null no dedicado
Sessao.corpos(espaco := -1) -> Array[Node3D]           # o local + os bonecos visíveis naquele espaço
Sessao.mais_perto(origem: Vector3, raio: float, espaco := -1) -> Node3D
```

Em SOLO, `corpos()` devolve só o local, e `mais_perto()` devolve o local se ele estiver no raio. Todo sistema que trocar para esta API funciona igual no solo (P16).

### 5.2 Quem troca, e para quê

| Arquivo | Hoje | Em rede | Quem roda | Fase |
|---|---|---|---|---|
| `pedestre.gd:262` | desvia **do** jogador, olha para ele | desvia de **qualquer corpo** perto (o boneco tem rapidez no estado); olha para o mais perto | local (*flavor*) | 2 |
| `casa_viva.gd:100` | pendura um `NavigationObstacle3D` **no** jogador | um em cada corpo do espaço, para o convidado da casa contornar o amigo | local | 2 |
| `convidado.gd:569` | cumprimenta e abre caminho para o jogador | para o mais perto | local | 2 |
| `npc.gd:121` | vira para o jogador por distância e ângulo | para o mais perto; em conversa, para **quem fala** (`interagir(quem)` já recebe) | local; "ocupado" pelo servidor | 3 |
| `entregas_da_super.gd:169` | escolhe um pedestre na frente da câmera | igual, local | local | — |
| `inimigo.gd:105` | vê, ouve (`nivel_de_ruido`) e bate **no** jogador | escolhe o alvo entre os corpos, no **servidor** | servidor | 8 |
| `blitz_manager.gd:101` | monta a blitz perto do jogador | perto de algum jogador, no servidor | servidor | 8 |
| `minimapa.gd` | centro no jogador | + ponto de cada boneco do mesmo espaço | local | 2 |
| `hud_missao.gd` | distância do jogador ao alvo | igual (a distância é de cada um); o alvo é do grupo | local | 5 |

Os outros 34 continuam certos como estão: são câmera, HUD, streaming, save solo, captura e telas, e todos são **deste** processo.

### 5.3 O que não troca, de propósito

`Multidao`, `Transito` e `ChunkManager` seguem **o jogador local**. Cada cliente monta a cidade, os pedestres e o trânsito em volta de si (P5). O amigo a 300 m tem a própria multidão, que eu não vejo e que não precisa existir aqui.

## 6. Pausa (Fase 2.1)

### 6.1 O defeito

Hoje cinco lugares param a árvore inteira:

| Onde | Linha |
|---|---|
| `UIManager.push_menu(no, pausar = true)` | `ui_manager.gd:116` (usado por `menu_sistema.gd:181`, `prancha_inventario.gd:742`, `inventario_grid_re7.gd:106`) |
| Prancha do inventário | `prancha_inventario.gd:740` |
| Menu com o jogo por trás | `menu.gd:1573` |
| Modo foto | `modo_foto.gd:161` |

A `Sessao` é `PROCESS_MODE_ALWAYS`, então a rede continua. Mas o anfitrião que abre a prancha:

1. **congela no meio da rua** para todos (o `Player` dele para e o estado repete);
2. **para o relógio da cidade de todo mundo**: quem anda o relógio é a HUD (`hud_cidade.gd:133`), que para junto. O servidor segue mandando a hora parada, e cada cliente, cuja HUD andou, **volta no tempo a cada 5 s** no acerto;
3. a partir da Fase 3, para o crescimento das plantas e toda regra de mundo que o servidor rode no `_process`.

O item 2 também vale para um cliente: a HUD dele para, e o acerto do servidor o puxa de volta para a hora certa. Esse caso é inofensivo.

### 6.2 O conserto

```gdscript
# Sessao
func pausar(sim: bool) -> void:
	if not em_rede():
		get_tree().paused = sim            # SOLO: exatamente o de hoje
		return
	var p := jogador_local()
	if p != null:
		p.travar(sim)                      # em rede: trava só a mim
	_ausente = sim                          # bit F_AUSENTE para os outros
```

Os cinco lugares trocam `get_tree().paused = x` por `Sessao.pausar(x)`. É uma linha em quatro arquivos ✋, e o solo fica idêntico por construção.

E o servidor para de depender da HUD para o relógio: com rede ligada, a `Sessao` do servidor anda `WorldState.relogio` (como já faz no dedicado), e a HUD do servidor para de andar. Uma fonte só.

**Modo foto em rede:** trava o jogador local e solta a câmera livre, mas o mundo não para. A foto de um mundo parado é coisa de solo.

## 7. Teletransporte anunciado (Fase 2.3)

A validação `corrigir` (P15) puxa de volta quem anda rápido demais. Hoje ela é `registrar` por padrão, porque o jogo teletransporta sem avisar:

| Quem teletransporta | Linha | Mesmo espaço? | A `Sessao` já percebe? |
|---|---|---|---|
| Entrar em interior | `interiores.gd:447` (y + 2000) | não | sim, pelo espaço |
| Sair de interior | `interiores.gd:294` | não | sim |
| Desmaiar e acordar no último ponto | `desmaio.gd:218` | **sim** | só se passar de 8 m, e aí como suspeito |
| Carregar save | `save_game.gd` | talvez | idem |
| `--ir-para`, abertura (`PIN_ACORDAR`) | `cidade.gd`, `abertura.gd:483` | sim | idem |
| Chegada na sessão | `sessao.gd`, `_chegar` | sim | sim (marca sozinha) |

A API:

```gdscript
Sessao.anunciar_teletransporte()     # SOLO: não faz nada
```

põe `F_TELEPORTE` no próximo estado. O servidor aceita o bit **no máximo uma vez a cada 3 s** por jogador, e registra cada uso. Isso não impede trapaça: um cliente adulterado pode mandar o bit a cada 3 s e andar a 3 m/s de "viagem rápida". O que impede é o desonesto não ganhar nada que o honesto não tenha num servidor de amigos. Para público, o desmaio passa a ser decidido pelo servidor (Fase 3, `08` §3), e o teletransporte de desmaio deixa de ser do cliente.

Com os seis anunciados, `validacao = corrigir` vira o padrão do dedicado.

## 8. Espaço do interior (Fase 2.2)

A `Sessao` lê `Interiores.get(&"_semente")`. O acessor público:

```gdscript
func semente_atual() -> int: return _semente     # interiores.gd ✋
```

e a `Sessao` passa a chamar `Interiores.semente_atual()` se existir (`has_method`), senão o `get` de hoje. Assim a troca não precisa ser no mesmo commit das duas frentes.

`InteriorNoMundo` (a casa construída **na rua**, `interior_no_mundo.gd`) não teletransporta: quem está dentro dela está no espaço **rua**, e é certo, porque ela existe na rua e o amigo de fora vê pela janela.

## 9. Ficha e perfil

`RegistroCivil.jogador` é a ficha **deste** processo, e continua sendo: celular, documento, prancha e `Corpo` local a leem. O id da ficha do jogador é **sorteado** (`registro_civil.gd:738`, relógio ⊕ `randi`), e isso é certo: cada um é uma pessoa diferente.

Os outros não têm ficha aqui, têm **perfil** (`Sessao.jogadores[id]`: nome e aparência saneados). Nada do jogo precisa da ficha de outro jogador; se um dia precisar (ver o documento do amigo), o perfil cresce com os campos saneados da carteira, e **não** com o CPF: a ficha gerada contém mãe, pai, endereço, e isso não sai da máquina de ninguém sem motivo de jogo.

## 10. Câmera

Uma por processo, como hoje. Nada de tela dividida nem `SubViewport` por jogador.

Casos novos:

- **Caído** (`08` §3): enquanto espera ajuda, a câmera sai do olho e orbita o próprio corpo em terceira pessoa, para quem caiu ver o amigo vindo.
- **Carona** (Fase 4): a câmera do carona é a da cabine, do lado +X (`09` §5).
- **Dedicado**: sem câmera. O `CaptureTool` não roda nele.

## 11. Aceite da Fase 2

| # | Prova | Como |
|---|---|---|
| 1 | ESC do anfitrião não congela o convidado nem o relógio | ✅ **medido 21/09**: anfitrião com `--ver-pausa` (prancha e menu de sistema abertos a sessão toda, foto) e um bot medindo o relógio: **30,0 s** de jogo em ~13 s reais. O mesmo teste com a pausa antiga: **2,0 s** (o anfitrião congelava a hora de todos) |
| 2 | Solo idêntico | `--pular-menu --pular-abertura` + prancha: a árvore pausa como antes (captura igual ao HEAD) |
| 3 | Arfagem | ✅ **medido 21/09**: bot parado com a lanterna a −35°, o chão na frente dele fica 1,70× mais claro que o chão de referência; a +30°, 1,16× (`lanterna_do_amigo_baixo_e_cima.png`). A sonda por raio, que mediria o ângulo em graus, fica para quando a luz precisar de precisão |
| 4 | Motorista, faróis, freio | ✅ facho e **freio** confirmados: `anfitriao_ve_carro_e_lanterna.png` (facho aceso na névoa) e `anfitriao_ve_freio_e_poses.png` (brasa vermelha com `--bot-agachado`, que no carro vira `F_FREANDO`); ⚠ o corpo no banco **não aparece**: o vidro da `Carroceria` é opaco, igual para o NPC (fotos de lado e de frente) |
| 5 | Passos | 10 m andados pelo boneco = 6 a 7 passos tocados perto (um a cada `PI / BOB_FREQ` = 1,53 m, a conta do `Player`); 0 agachado |
| 6 | Teletransporte | `mp_teste.sh --validacao=corrigir` com um bot que entra e sai de interior e desmaia: **0** correções indevidas |
| 7 | Pedestre desvia do amigo | medir: distância mínima pedestre–boneco numa calçada ≥ `ESPACO_PESSOAL` do `pedestre.gd` |
| 8 | Nível 2 | estado v2 ida e volta; bits de carro; arfagem nos extremos |

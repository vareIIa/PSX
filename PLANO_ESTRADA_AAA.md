# Estrada Velha — o primeiro minuto do jogo

Escrito para quem pegar esta cena depois: direção de arte e a próxima sessão.

A Estrada Velha é a cutscene que roda entre a criação de personagem e a Praça da
Matriz. É o primeiro minuto de jogo de qualquer pessoa que aperte NOVO JOGO, e
por isso ela vale mais por minuto do que qualquer outro pedaço do projeto: é
onde se decide se o jogador acha que está jogando algo caprichado ou algo
inacabado, antes de ter visto uma rua sequer.

Este documento tem três partes: **o que a cena é hoje**, **o julgamento honesto
sobre ela merecer ou não o rótulo AAA**, e **o plano para que mereça**.

---

## 1. O que foi feito nesta passada

### 1.1 A terra parou de brilhar

`mat_leito.tres` tinha `tint = (1,45 · 0,68 · 0,38)` — vermelho acima de 1,0 — e
por cima disso `emission_color = (0,55 · 0,18 · 0,06)` com energia **0,38**. Terra
que EMITE luz laranja. Os dois números foram calibrados contra as prints noturnas
de referência, onde o farol é a única fonte de luz e a estrada precisa desenhar
sozinha; aplicados a um fim de tarde com sol de energia 1,9, viravam lava.

Não era um ajuste de gosto: era o mesmo material servindo a duas condições de luz
opostas, com os números de uma delas. Hoje é `tint = (1,04 · 0,73 · 0,51)` — a
razão 1 : 0,70 : 0,49 que as próprias prints medem — com um piso de emissão
neutro e baixo (0,14), na mesma lógica do `mat_carro`.

**Isto sozinho responde pela maior parte da diferença entre o antes e o depois.**
Vale em todos os climas, inclusive nos que já existiam.

### 1.2 Chove, e a chuva alcança a cena

A Estrada Velha é montada **quatro mil metros acima da cidade** (ver o cabeçalho
de `abertura_estrada.gd`). Os sistemas de água do jogo — todos escritos para a
cidade — não alcançavam lá:

| sistema | o que impedia | o que foi feito |
|---|---|---|
| `Chuva` (partícula) | respingo fixado em `y = 0,03`, o chão da cidade | `chao_y` público, escrito pela cena a cada quadro |
| `Chuva` (respingo) | `visibility_aabb` 9,5 m **abaixo** das partículas | caixa corrigida para em volta do nó |
| `Pocas` (decal) | pergunta à `MalhaUrbana` onde há asfalto | `PocasEstrada` nova, água em função de `s` |
| `SprayRoda` | exige `VehicleWheel3D`, que o carro da cena não tem | `SprayEstrada` nova, leque + jato de poça |
| `Clima` | 90 s para encharcar; a cena dura 62 | `Clima.encharcar()`, respeitando `--molhado=` |

Dois presets novos (`fog_estrada_chuva` e a variante aérea) e o clima padrão da
cutscene passou a ser o temporal. Os quatro climas antigos continuam existindo
em `--estrada-clima=`.

### 1.3 A lista de planos

| antes | | depois | |
|---|---|---|---|
| passagem | 9,0 s | passagem | 9,0 s |
| aérea | 12,0 s | aérea | 11,0 s |
| | | **mata (o bicho)** | **9,0 s** |
| rasante | 8,0 s | rasante | 7,5 s |
| dentro | **23,0 s** | dentro | **13,0 s** |
| | | **poça (a roda)** | **6,0 s** |
| saída | 6,5 s | saída | 6,5 s |
| **5 planos, 58,5 s** | 39% dentro do carro | **7 planos, 62 s** | 21% dentro do carro |

As nove falas continuam as mesmas e na mesma ordem; duas mudaram de plano.
`"Sem maldade, essa estrada não parece ter fim."` saiu da cabine e foi para o
plano do bicho — dita por cima de alguém que está OLHANDO o carro, ela deixa de
ser tédio de viagem.

**O plano do bicho** é uma câmera a 5,0 m do eixo e 1,5 m do chão, atrás de
folha colocada de propósito (`EstradaBuilder.spawn_toca`), com respiração,
inclinação de cabeça e um atraso ao seguir o carro. Não acompanha até o fim: o
pescoço trava em 30° e o carro sai de quadro sozinho.

**O plano da poça** planta a câmera a 34 cm do barro, ao lado de uma poça **que
existe** — a água é função de `s`, então dá para perguntar onde está a próxima e
ir até lá — e o carro passa por cima dela na diagonal.

### 1.4 Bugs encontrados e consertados no caminho

Nenhum destes estava no pedido; todos apareceram quando a cena passou a ser
olhada de perto.

1. **Lateral esquerda do carro não existia.** A lataria é uma casca de faces
   viradas para fora com `cull_back`: do banco do motorista não havia porta, nem
   teto, nem coluna traseira. O que a cabine desenhava parava no peitoril, 4 cm
   abaixo do olho, e dali para cima aparecia mata. Foram acrescentados caixilho
   do teto, coluna B e o painel atrás do ombro.
2. **Painel e capô viravam espelho na chuva.** `mat_painel` e `mat_carro` não
   estavam na tabela `EstiloVisual.MOLHABILIDADE` e caíam no padrão do shader
   (`rugosidade_molhada = 0,12`), que é o número da **poça**. O interior ficava
   mais claro que a estrada. O mesmo valia para `mat_folhagem_recorte`, que é o
   material de toda a mata: no plano aéreo saía um clarão branco cravado no meio
   da floresta.
3. **Roda esterçava em torno do centro do carro.** O eixo inteiro era um nó só, e
   girá-lo em Y fazia as duas rodas descreverem um arco: a 20° de esterço a roda
   de dentro andava 22 cm para a FRENTE e aparecia debaixo do bico. Agora são
   quatro pinos, um por roda.
4. **O carro não pousava na estrada.** Andava no `y` cru de `ponto_em`, que é a
   linha do caminho e não a superfície — até 20 cm de diferença. Hoje há um apoio
   de verdade, no ponto mais alto sob as quatro rodas, com limitador de
   velocidade vertical fazendo as vezes de suspensão.
5. **O plano aéreo era uma tela cinza.** A névoa aberta do plano de cima só era
   aplicada quando o clima fosse `"noite"` — e o clima da cutscene não era a
   noite. Doze segundos de plano existindo para mostrar o vale, mostrando nada,
   sem erro nenhum no log.
6. **Dither somado no shader do para-brisa.** `a += (bayer - 0,5) * 0,14` pinta
   7% de alfa em todo pixel, inclusive onde não há gota: véu branco leitoso sobre
   o quadro inteiro, imune a qualquer ajuste nas gotas. Multiplicado, respeita o
   zero. (Esta armadilha já tinha mordido o facho de luz antes.)
7. **O carro não tinha sombra nenhuma.** `SombraContato` nova — uma mancha de
   oclusão, não uma projeção de sol, então vale em todo clima. Medida: 4,68% dos
   pixels, diferença máxima de 167.

---

## 2. Isto é AAA?

> Este julgamento é de ANTES da execução da seção 3 — é ele que gerou o
> plano. Fica como está de propósito: apagar o diagnóstico depois de
> consertar é perder a régua. O que continua valendo está na seção 4.

**Não ainda.** A cena saiu de *quebrada* para *boa*. O que foi feito nesta
passada foi, em ordem de peso: consertar defeitos, ligar sistemas que já
existiam e não alcançavam a cena, e acrescentar dois planos. Nada disso é
acabamento — é o piso a partir do qual acabamento começa a fazer diferença.

O teste que eu aplicaria: **se um jogador pausar em qualquer quadro dos 62
segundos, esse quadro se sustenta?** Hoje a resposta é sim em cinco dos sete
planos. Mas AAA não se mede em quadro parado, e é aí que ainda falta:

- **A cena não reage à velocidade.** A 68 km/h a chuva deveria entrar deitada no
  para-brisa, o risco deveria inclinar para trás, e o limpador deveria varrer
  mais rápido quando o temporal aperta. Hoje a chuva cai vertical e o limpador
  tem um período fixo. Isso é o que mais denuncia que há sistemas ligados lado a
  lado em vez de um clima só.
- **Não há som novo nenhum.** Sete planos, um trovão não, chuva no teto do carro
  não, pneu entrando na água não, limpador não. Metade do que se sente numa cena
  de chuva entra pelo ouvido, e essa metade está inteira faltando.
- **Não há evento.** Os 62 segundos são sete enquadramentos de uma mesma coisa
  acontecendo. Falta a coisa que quebra o ritmo — um relâmpago, uma derrapada,
  um bicho atravessando a pista. A cena do bicho pede isso e não entrega.
- **A luz é a mesma dos 62 segundos inteiros.** Um preset, um sol, uma névoa.
  Cinema de verdade muda a luz entre planos.

---

## 3. O plano — estado de execução

Legenda: **feito** / **parcial** / **aberto**.

### Fase 1 — A chuva vira uma coisa só — **feita**

1. **Chuva inclinada pela velocidade** — feita. A `Chuva` mede a própria
   velocidade (ela já segue a câmera, basta olhar quanto ela mesma andou),
   limita a 26 m/s, suaviza, e **zera no corte de plano**: sem isso a
   teleportação da câmera entre planos daria mil metros por segundo e a chuva
   sairia deitada por meio segundo depois de todo corte. A 68 km/h contra 15 m/s
   de queda, o risco entra a 52° da vertical.
2. **Limpador atrelado à intensidade** — feito. `LIMPADOR_PASSADA` virou
   `Vector2(1,45 s, 0,55 s)`, interpolado por `Clima.chuva`.
3. **Névoa e grade por plano** — feita, e junto com a Fase 4.11. Tabela
   `LUZ_POR_PLANO` com multiplicadores sobre o clima em vigor — não arquivos
   novos, porque são sete variações de dois números do mesmo clima. O plano do
   bicho é o único mais frio da cena (`tinta` azulada, saturação 0,74); a saída
   fecha a névoa em 62% para o carro ser engolido DENTRO do plano.
   `FogController.forcar_preset()` é novo e aceita um preset em memória.

Extra não planejado: a gota do para-brisa **sobe** quando o carro corre
(uniform `vento`), e o rastro dela inverte junto — com o sinal fixo a gota subia
deixando o fio na frente, que lê como cometa.

### Fase 2 — O som — **feita**

Quatro arquivos novos, gerados no pipeline procedural do projeto
(`tools/gerar_audio.py`, função `estrada()`):

| som | o que é |
|---|---|
| `trovao_longe` | só o ronco; o ar comeu tudo acima de 400 Hz |
| `trovao_perto` | o estalo de banda larga na frente do ronco |
| `chuva_cabine_loop` | a mesma chuva sem agudo, mais a batida no teto |
| `poca_pneu` | a lâmina rasgada: quatro bandas morrendo em tempos diferentes |

4. **Chuva no teto** — feita. `Chuva.abrigo` faz o cruzamento dos dois loops em
   sentidos opostos, nunca por corte, com teto de −9 dB na de fora: entrar num
   carro não apaga a chuva lá fora.
5. **Pneu na água** — feito. Dispara em `mergulho > 0,45` com 0,35 s de silêncio
   mínimo por roda, afinação pela velocidade.
6. **Trovão × 3** — feito, na tabela `TROVOADA`, marcada no relógio da CENA e
   não pendurada nos planos: uma tempestade não sabe onde estão os cortes.

### Fase 3 — O evento — **parcial**

7. **Relâmpago** — feito. `Relampago` novo: o clarão é uma DIRECIONAL de verdade
   (recorta a mata contra o fundo, acende o capô) com envelope de piscadas em
   degraus, mais um `flash` no shader da cúpula, porque no plano de cima o céu é
   metade do quadro. O trovão é AGENDADO pela distância — `km / 0,343 s` — e é
   esse intervalo que dá tamanho ao céu.
   Dois ajustes medidos: energia 7,5 → 4,2 (a 7,5 a névoa de profundidade
   recebia a luz junto e o quadro virava corte para branco com legenda ilegível)
   e o segundo raio andou de 21,5 s para 26,0 s, porque em 21,5 ele batia em
   cima de uma fala.
8. **O bicho existe por um quadro** — **aberto, e é decisão sua.** Continuo
   achando que é o item de maior retorno da lista e o único que muda o gênero do
   primeiro minuto do jogo. Não implementei sem a sua palavra.

### Fase 4 — Acabamento — **parcial**

9. **Capô com informação** — resolvido de lado: a camada de água do para-brisa
   ficou na frente dele, então ele já é lido através de gota. Não foi preciso
   tocar na lataria.
10. **Farol como fonte na chuva** — feito. `psx_light_cone` ganhou riscos de
    água atravessando o feixe, ancorados em espaço de VISTA (presos à UV eles
    girariam com o cone e a chuva pareceria presa ao carro), e eles **tiram**
    alfa em vez de somar brilho: água atravessando luz não acende nada.
11. **Grade de cor por plano** — feita junto com a Fase 1.3.

### Dívidas — **quatro de seis quitadas**

| # | estado |
|---|---|
| D1 | **quitada.** `Carro._girar_rodas` tinha o mesmo defeito de eixo. A dianteira virou dois pinos; a traseira continua inteira porque não esterça. Custa uma chamada de desenho por carro. |
| D2 | **quitada, e melhor que o pedido.** `leito` e `mato` entraram na tabela — e o gerador **parou de apagar por padrão**: ele avisa e lista, e só poda com `--podar`. (Rodei o script sabendo da armadilha e ele apagou doze arquivos de cinco frentes; restaurados por `git checkout`. Anotar a armadilha não a desarma.) |
| D3 | **aberta.** A roda do lado oposto ainda aparece pelo vão sob o bico com a lente abaixo de 44 cm. A `SombraContato` atenua. |
| D4 | **aberta.** `mat_painel` com emissão 0,34 continua achatando o interior de dia. |
| D5 | **quitada.** `SombraContato` agora nasce também no carro do trânsito. |
| D6 | **aberta.** O retorno de emergência do plano da poça continua existindo. |

### Achado fora do plano: "os matos voando"

Relatado com print no meio da execução. Duas causas, e a investigação errou três
vezes antes de acertar:

1. **A câmera debaixo da saia de uma conífera.** `PASSAGEM_LADO` era 5,6 m, as
   árvores nascem a 6,2 m e a saia abre 2,2 m: a folhagem chegava a 4,0 m do
   eixo. O que se vê por baixo de uma saia é a face de baixo dela — retângulo
   escuro, horizontal, sem tronco atrás (o tronco está ACIMA da linha do olho).
   Conserto: `EstradaBuilder.CORREDOR_LIVRE = 5,4 m`, e quem invadiria é
   EMPURRADO para fora em vez de descartado, para não deslocar o `rng`.
2. **O capim da beira nascia enterrado.** `KitEstrada.beira` plantava no `y` do
   EIXO da pista, e o barranco já subiu 4,7 cm a 3,65 m e 35,7 cm a 7,30 m.
   Enterrada pela mesma quantidade, a fileira inteira sobrava só de ponta, e as
   pontas formavam uma linha horizontal contínua correndo a beira da estrada.
   Conserto: a `beira` recebe um `Callable` do chão. O tamanho autorado teve de
   cair junto (0,55–1,35 → 0,45–1,05): a beira tinha sido calibrada no olho com
   a perda embutida.

E um terceiro, menor, achado no caminho: o recorte por alfa comia a mata à
distância (a minificação puxa o alfa médio abaixo do limiar). O limiar agora
**afrouxa com a distância** nos dois shaders de superfície, e a massa de folha
distante virou opaca — ela nunca precisou de recorte, como o próprio cabeçalho
de `_mata_distante` já argumentava.

Ferramenta nova: `--estrada-sem=beira,subbosque,mata,detalhes,massa,distante`.
**Cuidado registrado no código:** só a `beira` faz isso preservando o `rng`. As
outras famílias pulam o laço inteiro, deslocam o sorteio e trocam a floresta —
servem para aliviar o quadro, não para bisect.

---

## 4. O que ficou, em ordem de valor

1. **O bicho por um quadro** (Fase 3.8) — sua decisão.
2. **D4**: emissão do painel escalando com o ambiente do preset.
3. **D3**: fechar o vão sob o bico do Marea.
4. **D6**: o retorno de emergência do plano da poça.
5. Chuva na cidade também inclinando com o jogador correndo — o mecanismo já
   está lá e é de graça, falta olhar se fica bom a 4 m/s.

---

## 5. O plano original (referência)

### As fases, como foram escritas

Cada fase tem um **critério de aceite mensurável**. Sem isso vira ajuste no
escuro, e esta cena já gastou tempo demais assim.

### Fase 1 — A chuva vira uma coisa só (alto impacto, baixo risco)

1. **Chuva inclinada pela velocidade.** `Chuva` recebe a velocidade do alvo e
   inclina `direction`/`linear_accel` para trás. A 19 m/s o risco deve chegar
   perto de 45°.
   *Aceite:* capturar `--estrada-plano=rasante` com o carro a 0 e a 68 km/h; o
   ângulo médio do risco tem de mudar mais de 25°.
2. **Limpador atrelado à intensidade.** `LIMPADOR_PASSADA` vira função de
   `Clima.chuva`: garoa 1,4 s, aguaceiro 0,55 s.
   *Aceite:* `--chuva=0.3` e `--chuva=1.0` têm de dar períodos diferentes no log.
3. **Névoa por plano.** Cada plano pode pedir um preset próprio, como a aérea já
   faz. A cabine fecha em 40 m, o rasante em 60, a saída em 30 para o carro
   sumir de verdade.
   *Aceite:* as sete capturas lado a lado não podem ter o mesmo horizonte.

### Fase 2 — O som (alto impacto, médio risco)

4. **Chuva no teto do carro.** O `AudioDirector` já tem `chuva_loop`; falta a
   variante abafada de dentro do carro, com o volume subindo quando a câmera
   entra na cabine. É o mesmo contrato que `Interiores` já usa.
5. **Pneu na água.** Um disparo curto quando `PocasEstrada.mergulho()` passa de
   0,5 — o dado já existe, só não tem som pendurado nele.
6. **Trovão distante, três vezes nos 62 s.** Sem relâmpago ainda; só o som, com
   atraso, é o que dá tamanho ao céu.
   *Aceite:* rodar `--estrada-corrida` com o log de áudio e conferir que os três
   eventos caem em planos diferentes.

### Fase 3 — O evento (alto impacto, alto risco)

7. **Relâmpago.** A `Fase 9` da UI já fez relâmpago distante no menu
   (`commit 6e2f947`); reaproveitar. Um clarão que lava a névoa por dois quadros
   e apaga, no plano aéreo ou no do bicho.
8. **O bicho existe por um quadro.** No fim do plano da mata, quando a cabeça já
   perdeu o carro, a câmera baixa e passa rente a alguma coisa — um flanco, uma
   pata, o que for — sem nunca mostrar o todo. É o plano mais barato de arruinar
   e o mais valioso se der certo. **Discutir antes de implementar:** isto muda o
   gênero do primeiro minuto do jogo.

### Fase 4 — O acabamento que falta

9. **Capô com informação.** No plano da cabine ele é uma chapa clara e lisa
   ocupando o terço de baixo. Gota escorrendo nele, ou o reflexo do céu
   quebrado, resolve.
10. **Farol como fonte na chuva.** O cone volumétrico hoje é uma cunha; na chuva
    ele deveria ter a água atravessando dentro dele.
11. **Grade de cor por plano.** `saturation` e `grade_tint` já existem no preset;
    usá-los para o plano do bicho ser mais frio que o resto.

---

## 4. Dívidas conhecidas

Coisas que encontrei e **não** consertei, com onde estão. Nenhuma quebra a cena
hoje; todas mordem quem chegar depois.

| # | onde | o quê |
|---|---|---|
| D1 | `game/src/world/carro.gd:1994` | **O mesmo bug de esterço** que foi consertado na Estrada Velha existe em todo carro do trânsito: `_eixo_frente` gira em Y no centro do carro, e as duas rodas andam num arco. Aparece em qualquer câmera baixa na cidade. O conserto é o mesmo (`Carroceria.roda_unica` já existe), mas lá as rodas também precisam seguir a suspensão do `VehicleBody3D`. |
| D2 | `tools/gerar_materiais.py` | `mat_leito` **não está na tabela** do gerador, e o gerador apaga todo `mat_*.tres` fora dela. Rodar o gerador hoje apaga a terra da estrada. |
| D3 | `carroceria_marea.gd` | Com a lente abaixo de ~44 cm, a roda dianteira do lado oposto aparece pelo vão sob o bico. É geometria correta e lê como defeito. A `SombraContato` atenua; fechar de vez pede um assoalho escuro mais baixo no perfil. |
| D4 | `mat_painel.tres` | `emission_energy = 0,34` com cor creme é o piso que faz o painel existir à noite. De dia ele achata o interior. Deveria escalar com o ambiente do preset. |
| D5 | `SombraContato` | Só existe no `CarroCena`. Todo carro da cidade continua sem sombra de contato. |
| D6 | `abertura_estrada.gd` | O plano da poça escolhe a primeira poça adiante. Se o RNG der um trecho seco, cai num retorno de emergência que vira um rasante rente ao chão. Nunca aconteceu em teste (62% por célula), mas o caminho existe. |

---

## 5. Como medir

```bash
GODOT=".tools/Godot_v4.7.2-stable_win64_console.exe"

# a cena inteira, os sete planos na ordem (flag nova)
"$GODOT" --path game -- --ver-estrada --estrada-corrida --estrada-clima=chuva

# um plano congelado, para conferir enquadramento
"$GODOT" --path game --resolution 1280x720 -- --ver-estrada \
  --estrada-plano=mata --estrada-clima=chuva \
  --shot=out.png --shot-frame=100 --shot-quit

# planos: passagem | aerea | mata | rasante | dentro | poca | saida | chase
# climas: chuva | entardecer | noite | amanhecer | dia

# diagnósticos
--mat-debug      cor chapada por material da estrada (acha buraco)
--sem-ceu        esconde cúpula e serra (buraco volta a ser preto)
--sem-sombra     desliga a sombra de contato (isola o efeito dela)
--debug-agua     diz por qual portão o spray não está saindo
--molhado=0..1   congela o encharcamento sem esperar 90 s
--chuva=0..1     congela a chuva caindo, independente do molhado
```

Depois de qualquer mudança em script, cena ou shader:

```bash
"$GODOT" --headless --path game --quit     # sem erro no stdout
```

Shader **não** compila em headless. Toda mudança em `.gdshader` precisa de pelo
menos uma captura com janela.

---

## 6. Uma regra para esta cena

A mata desta estrada é gerada. **Acaso não enquadra.** O plano do bicho já custou
três posições de câmera por causa disso — 11,5 m ficava acima das caixas de folha
e via a face de cima delas; 8,6 m ficava dentro delas e o quadro virava uma
parede verde. O que funciona é achar um bolsão onde a geração não planta nada
(entre 3,7 e 6,2 m do eixo, no caso) e **colocar à mão** o que tem de aparecer
perto da lente.

Vale para qualquer plano novo que alguém queira acrescentar aqui.

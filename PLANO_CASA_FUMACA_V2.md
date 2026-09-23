# PLANO CASA DA FUMAÇA v2 — a casa existe na rua

> Mapa medido do estado atual + plano para a casa da fumaça deixar de ser um
> cômodo teleportado e virar uma casa de verdade, atrás da própria porta.
> Versão 2.0 — 18/09/2026 — branch `playable`
> A v1 ([PLANO_CASA_FUMACA.md](PLANO_CASA_FUMACA.md)) continua valendo como
> histórico: pose sentada, PS2, fachada, missão e testes.

---

## 0. O pedido, e o que muda em relação à v1

O pedido: abrir a porta da casa da fumaça e **ver o interior pelo vão**, sem
parede cinza e sem teletransporte — e que isso valha para todas as portas do
jogo. Junto: casa maior e mais jovem, móveis e cartazes bonitos, capas de
álbuns brasileiros e de jogos de PS2, luz da TV e do interior realista e no
mesmo nível do resto do jogo, NPCs que se movem direito.

A v1 consertou o cômodo **dentro** do modelo de teleporte. A v2 troca o modelo:
é o mesmo erro que o Bar do Seu Zé já ensinou (memória
`lugar-de-rua-nao-e-interior`) — o problema nunca foi a entrada, era o lugar não
existir na rua.

---

## 1. O que as capturas mostraram

Capturas desta sessão, modo MODERNO 1280×720 (a configuração do jogador):
`captures/fumaca_v2/antes/01..11`.

### 1.1 A porta

| Defeito | Evidência | Causa |
|---|---|---|
| Abre e mostra parede | `10_porta_abrindo` | Atrás da folha há um painel de reboco `#9a9184` de 1,55 × 2,24 m — [kit_fachada.gd:135](game/src/world/kit_fachada.gd#L135). O prédio é uma caixa maciça de 8 m ([chunk_builder.gd:1046](game/src/world/chunk_builder.gd#L1046)) |
| Tela preta e teleporte | [interiores.gd:16](game/src/systems/interiores.gd#L16), `:311` | O interior é montado 2000 m acima da cidade; cortina preta de 0,22 s, jogador teleportado, cidade escondida |
| Abre para fora, na cara de quem bate | [porta.gd:207](game/src/world/porta.gd#L207) | A folha gira −96° para a calçada. Porta de casa brasileira abre para dentro |
| O fumante da calçada rouba o prompt | `11_porta_abrindo_lado`: apertar E abriu conversa ("Desculpa, eu estava longe") em vez de bater | NPC a 0,9 m do eixo da porta, com área de interação disputando a mesma mira — [kit_fumaca.gd:338](game/src/world/kit_fumaca.gd#L338) |

### 1.2 A sala

| Defeito | Evidência | Causa |
|---|---|---|
| Colunas de fumaça leem como **tubos de neon** | `01_entrada`, `04_janela` | Seis pares de placas cruzadas de 0,26 × 1,5 m com alfa 0,68, iluminadas pelas lâmpadas — [casa_fumaca_builder.gd:819](game/src/world/casa_fumaca_builder.gd#L819) |
| Sala inteira lavada de cinza leitoso | `07_plano05` | Facho somado da TV dentro da névoa |
| Tudo sépia, não parece o resto do jogo | todas | `fog_fumaca.tres`: ambiente marrom 0,48 + `grade_tint` (1,00 / 0,90 / 0,77) multiplicando a imagem inteira + névoa marrom |
| **Nenhuma sombra no interior**, mesmo com sombras ligadas | todas | A malha do cômodo nasce com `cast_shadow = OFF` ([interiores.gd:342](game/src/systems/interiores.gd#L342)); os corpos também ([convidado.gd:345](game/src/world/convidado.gd#L345)). E a `Lampada` entra no grupo `luz_sombra` ([lampada.gd:98](game/src/world/lampada.gd#L98)): o DiretorSombra liga sombra em duas lâmpadas do cômodo que **não têm o que projetar**. Paga-se o custo e não se desenha nada |
| Móveis "porcos" | `04`, `05`, `06` | Sofá = 4 caixas ([casa_fumaca_builder.gd:494](game/src/world/casa_fumaca_builder.gd#L494)), tudo vestindo uma célula de **32 px** do atlas 256×256. Em 1280×720 isso é um texel a cada vários centímetros |
| Cartaz que parece a bandeira de Israel | `05_dono` | Célula "time": fundo branco, faixa azul em cima e embaixo, hexágono azul no meio — [gerar_casa.py:344-354](tools/gerar_casa.py#L344-L354) |
| Cabos de controle viram vara e tripé | `02_tv`, `03_jogadores`, `06_sofa` | Tubos retos e rígidos de 2,2 cm saindo do console ([casa_fumaca_builder.gd:450](game/src/world/casa_fumaca_builder.gd#L450)) |
| Gabinete da TV claro | `02_tv` | Célula do atlas + spot sem sombra + ambiente marrom levantando o preto |
| Janela é um painel marrom | `04_janela` | É um plano emissivo tingido; não há rua atrás dele — [casa_fumaca_builder.gd:324](game/src/world/casa_fumaca_builder.gd#L324) |
| A sala é um cômodo só, e a estufa é outro teleporte | planta | 9,8 × 8,2 m; porta dos fundos chama `Interiores.atravessar` |

### 1.3 Os NPCs

| Defeito | Causa |
|---|---|
| Andam em linha reta até um ponto sorteado, sem desvio: esbarram na mesa e no sofá e deslizam | [convidado.gd:577-596](game/src/world/convidado.gd#L577-L596): `velocity = direcao * 0.85`, sem navegação e sem saída de travamento |
| Começam e param de andar no tranco | velocidade constante, sem aceleração |
| Atravessam uns aos outros e empurram o jogador | sem desvio entre agentes (a mesma armadilha do `ir-para-nao-e-regua`) |
| Conversam a 2,2 m de distância | `DISTANCIA_PAPO := 2.2` e nenhuma aproximação antes do papo |
| Ninguém senta no sofá, dança, bebe ou olha pela janela | só há quatro papéis (LIVRE, SENTADO no chão, EM_PE, ENCOSTADO) |
| O corpo é de 236 triângulos e lê como boneco de blocos no MODERNO | `corpo.gd` — frente global, fora do escopo da casa (ver §9) |

### 1.4 Custo medido

```
CasaFumacaBuilder.construir   2,50 ms  (thread, média de 10)
malhas do cômodo              0,13 ms  (principal, 9 superfícies)
cômodo                        1.058 triângulos, 6 lâmpadas, 9 convidados
```

**Montar a casa é barato.** O que custa num interior "de verdade" não é
construir: é compilar shader, nascer NPC, acender luz com sombra e renderizar
sonda de reflexo (seis passadas por sonda — memória `sonda-por-chunk-custa-engasgo`).
Isso decide a resposta da §2.

---

## 2. A decisão central: como a porta mostra o interior

### 2.1 Três caminhos

| Caminho | Como funciona | Veredito |
|---|---|---|
| **Portal** | Uma câmera no interior a 2000 m renderiza num `SubViewport`, e a imagem vai num quad no vão da porta | Não. Custa uma renderização inteira a mais; exposição não roda em `SubViewport` (memória `viewport-novo-nao-herda-a-exposicao`); névoa, luz e chuva divergem entre os dois lados; e ao cruzar ainda é teleporte |
| **Teleporte sem corte** | Pré-carrega o interior lá em cima e troca no quadro exato em que o jogador cruza | Não. O vão continua mostrando parede; só esconde melhor a troca |
| **Interior no mundo** | A casa é construída **em coordenada de rua, atrás da própria fachada**, como o Bar do Seu Zé | **Sim.** O que se vê pelo vão é o cômodo, porque ele está lá. Não há troca, não há cortina, não há mentira para esconder |

### 2.2 Carregar quando chega perto, ou só quando abre a porta?

**Nenhum dos dois sozinho — em três degraus.**

Só ao abrir a porta põe o engasgo exatamente no instante da interação (NPC
nascendo, shader compilando, sonda renderizando) e deixa a janela e a fresta
mentindo da rua. Só por proximidade paga IA e sombra de casa que ninguém vai
visitar.

| Degrau | Quando | O que existe |
|---|---|---|
| **0 — casca** | sempre, com o chunk | Paredes externas, telhado e laje, fachada, vidros, luz saindo pela janela (emissão de material, custo zero). Oclusores nas paredes, com o vão da porta e das janelas **abertos** |
| **1 — pré-aquecido** | jogador a ≤ 30 m, ou casa em vista a ≤ 45 m | Dados na thread (2,5 ms hoje), texturas por `ResourceLoader.load_threaded_request`, materialização **dividida em quadros**, luzes que se veem pela janela acesas, NPCs em pose e animação ociosa, sem IA. O som já sai de dentro da casa |
| **2 — ativo** | porta aberta, jogador a ≤ 6 m da soleira, ou dentro | IA e navegação, sombra da TV e da luz principal, sonda de reflexo do interior, volume de fumaça, som sem filtro |
| descarga | ≥ 45 m e fora de vista | Histerese, igual ao `FOLGA_DESCARGA` do ChunkManager |

### 2.3 As cinco peças que fazem o interior no mundo funcionar

1. **Lote vazado.** O chunk reserva um lote para a planta e o volume maciço do
   quarteirão não é gerado ali — é o `_predio_do_bar` generalizado. A porta
   deixa de ter posição sorteada (`t` entre 0,28 e 0,72): passa a ser função do
   lote, calculável pelo mapa sem montar o chunk, como o bar já faz.
2. **Luz isolada por camada.** Malha do interior em camada própria; lâmpada do
   interior com `light_cull_mask` só dessa camada; poste da rua sem ela. Sem
   isso, no Forward+ sem sombra, a luz magenta de dentro acende a fachada do
   vizinho através da parede. O sódio que entra pela janela e a rua vista pela
   porta viram luzes de derrame controladas, como a da janela oeste já é.
3. **Limiar com mistura.** Uma `Area3D` de 1,5 m na soleira mistura o ambiente
   da rua com o do interior pela posição do jogador, em vez de `forcar` trocar
   tudo num quadro. O ambiente do interior sai de uma `ReflectionProbe` em modo
   interior com cor de ambiente própria — não do preset global.
4. **Chuva que respeita telhado.** A `Chuva` segue a câmera e hoje é escondida
   ao entrar ([interiores.gd:1320](game/src/systems/interiores.gd#L1320)). No
   mundo, ela continua caindo lá fora (visível pela porta e pela janela) e o
   shader de partícula descarta a gota dentro da caixa do lote. O som da chuva
   passa pelo filtro abafado do lado de dentro.
5. **`Interiores` vira fachada.** 29 arquivos usam a API (`dentro`,
   `tipo_atual`, `entrou`, `saiu`, `posicao_de_retorno`...). Ela continua
   existindo, dirigida pelo limiar em vez da porta: missão, GPS, HUD, conversa e
   testes não percebem a troca. O teleporte fica como caminho das plantas ainda
   não migradas.

### 2.4 Critérios que provam a promessa

A lição do bar: a versão teleportada passou em 29 medidas verdes porque o teste
chamava `Interiores.entrar` na mão. Aqui o teste **anda**.

| Critério | Alvo |
|---|---|
| Caminhada da calçada até o sofá, porta aberta pelo E | `Interiores.entrar` chamado 0 vezes; alfa máximo da cortina 0; saltos de posição > 0,5 m num quadro: 0 |
| Captura da porta a 40% de abertura | pixels do vão ≠ cor do painel `#9a9184`; luz da TV ou magenta presente no vão |
| Engasgo na aproximação (30 m → porta) | pior quadro ≤ 1,5 × a mediana da rota |
| Luz isolada | parede do vizinho com a casa acesa e apagada: diferença ≤ 1/255 |
| Chuva | nenhuma gota dentro do lote; chuva visível pela porta |
| Os 26 critérios do `verificar_fumaca.py` | migrados e passando |

---

## 3. A casa nova: maior, mais vasta, mais jovem

### 3.1 O lote

O corpo da fileira tem 8 m de fundo (`PROF_PREDIO`), e atrás dele o pátio é terra
escura que ninguém pisa ([chunk_builder.gd:897](game/src/world/chunk_builder.gd#L897)).
A casa passa a ocupar **14 m de frente por 16 m de fundo**: o corpo da fileira
mais metade do pátio. Em chunk de esquina o lote fica na ponta da face
**oposta** à esquina, para não cruzar a fileira do outro eixo.

### 3.2 Planta

```
           QUINTAL (8 m)                      ← era pátio de terra
  +------------------------------------------+
  | [estufa de lona]      [varal] [tanque]   |   a estufa sai do teleporte e
  |                                          |   vira estufa DE VERDADE, vista
  +---------------+--[porta]--+--------------+   pela janela da cozinha
  | COZINHA        |  corredor |  BANHEIRO    |
  | balcão, gela-  |  [escada] |  espelho,    |
  | deira adesivada|     ↑     |  fluorescente|
  +-------  -------+-----------+--------------+
  |              SALA DO VIDEOGAME             |   pé-direito cheio, sala e
  |  [sofá]  [mesa de centro]   [rack + TV]   |   cozinha integradas: o
  |  [pufe]  (chão onde jogam)  [PS2 + capas]  |   "vasto" vem de enxergar
  |                                  [caixa]   |   três cômodos de uma vez
  +---+--[porta de entrada]--+----------------+
      | VARANDA / garagem:  moto, cadeira de  |
      | plástico, engradado, gente fumando    |
      +--------------[portão]-----------------+
                      CALÇADA
  Pavimento superior:  QUARTO DO DONO (luz negra, colchão no chão)
                       ESTÚDIO CASEIRO (caixa de ovo, MPC, toca-discos)
  Laje:                caixa d'água, churrasqueira de tijolo, cadeiras de praia,
                       a cidade na névoa lá embaixo
```

"Mais jovem" é programa, não enfeite: estúdio caseiro de rap, videogame, laje
com som, luz de LED atrás da TV, pisca-pisca na janela.

### 3.3 Fachada

A casa vira prédio próprio no lote, dois pavimentos mais laje, diferente das
vizinhas na silhueta: muro com portão de ferro, varanda coberta, moto encostada,
janelas acesas **mostrando o interior real** (a luz de dentro sai por elas),
pichação com textura de tag no lugar dos riscos que hoje leem como cerca
quebrada flutuando (`11_porta_abrindo_lado`).

A porta passa a **abrir para dentro**, com batente e trinco no lado certo.

---

## 4. Arte: mobília, cartazes, capas

### 4.1 Um só modelo para os dois estilos

A malha é a mesma no MODERNO e no PS1 STYLE; o que muda é o material. No
MODERNO, PBR em 1024 px (o caminho `textures_hd` que o jogo já tem); no PS1, a
mesma textura reduzida, com vértice encaixado e UV afim. Memória
`moderno-nao-e-psx-forcado`: o PS1 é preset, não teto.

### 4.2 Mobília (casa brasileira de periferia, anos 2000)

| Peça | Detalhe que vende |
|---|---|
| Sofá de courino marrom | almofada afundada no lugar de quem sempre senta, rasgo no braço com espuma, **canga do Brasil** jogada por cima |
| Pufe e colchonete | onde senta quem chegou por último |
| Rack de MDF com vidro fumê | DVD, videocassete, caixa de som pequena, controle remoto com durex |
| TV de tubo 29" | gabinete preto de plástico real, vidro curvo com reflexo, bocal de antena |
| Mesa de centro de vidro | cinzeiro, seda, isqueiro, latinha amassada, reflexo da TV no tampo |
| Cadeiras de plástico brancas | a peça mais brasileira que existe; empilhadas na varanda |
| Estante de CDs | caixinhas com lombada legível |
| Geladeira velha | ímãs de pizzaria e adesivo de time |
| Ventilador de pé | girando, mexendo a fumaça |
| Tapete, cortina, manta | tecido amassado, não caixa |

### 4.3 Cartazes e capas

O cartaz "time" sai do atlas (§1.2). Cartazes passam a ser imagem de verdade
(512 × 768 no MODERNO) com papel, dobra, fita crepe e brilho de papel couchê.

Referências pesquisadas para cartazes e capas de CD:

| Álbum | Artista | Ano |
|---|---|---|
| Sobrevivendo no Inferno | Racionais MC's | 1997 |
| Usuário / A Invasão do Sagaz Homem Fumaça | Planet Hemp | 1995 / 2000 |
| Rap É Compromisso | Sabotage | 2002 |
| Da Lama ao Caos | Chico Science & Nação Zumbi | 1994 |
| Roots | Sepultura | 1996 |
| Cabeça Dinossauro | Titãs | 1986 |
| Eu Não Sou Santo | Bezerra da Silva | 1990 |
| Transpiração Contínua Prolongada | Charlie Brown Jr. | 1997 |

Jogos de PS2 para as capinhas em volta do console (caixa de DVD de
19 × 13,5 × 1,4 cm, algumas abertas, e **CD-R pirata escrito à caneta**, que é a
cara do PS2 destravado no Brasil): Bomba Patch / Winning Eleven 10, GTA San
Andreas, "GTA Rio de Janeiro", GTA Vice City, Need for Speed Underground,
Tony Hawk's Pro Skater 3, God of War, Guitar Hero, Resident Evil 4, Shadow of the
Colossus, Silent Hill 2, Bully, Metal Gear Solid 3, Gran Turismo 3, Burnout 3,
FIFA Street, Kingdom Hearts II, Devil May Cry 3.

**Nota de direito autoral.** Capa de álbum e de jogo tem dono. A imagem real
baixada da internet serve para um build pessoal e não pode ir num build
distribuído ou vendido. O caminho que jogos grandes usam é a **paródia
reconhecível** (é o que GTA faz com marcas e discos). A escolha é sua — ver as
perguntas no fim.

---

## 5. Luz AAA do interior

### 5.1 Princípio

Toda luz tem **fonte visível** — luminária, tela, lâmpada, brasa, LED. Nenhuma
luz de preenchimento solta no ar pintando o cômodo de uma cor só. O interior
passa a usar o mesmo pipeline do MODERNO da rua (sombra, glow, AO, SSIL/SDFGI na
escada de qualidade, volume), em vez de um preset sépia próprio.

### 5.2 A TV

| Hoje | Depois |
|---|---|
| 4 quadros de 32 px do atlas a 8 fps | Tela emissiva em HDR (o glow pega), vidro curvo com reflexo do cômodo, máscara de fósforo e curvatura no MODERNO |
| Partida desenhada no atlas | Partida viva num `SubViewport` 2D de 320 × 240 — campo, placar, replay, menu. Barato (2D, sem 3D) |
| Luz azul fixa que não pinta ninguém | Cor e energia **seguem o que a tela mostra**: campo verde joga luz verde-ciano, replay e menu piscam. É o que uma TV de futebol faz de verdade |
| Spot sem sombra | Spot com sombra, **luz herói** do cômodo: a silhueta de quem joga cai no sofá e na parede de trás |
| Facho somado que lava a sala | No MODERNO, a própria luz acende o volume de fumaça (`light_volumetric_fog_energy`). No PS1 fica o cone, com força menor |
| Gabinete claro | Plástico preto PBR, moldura fora do facho |

### 5.3 O resto

- **Sombra**: malha do interior projeta, com a mesma regra do `SEM_SOMBRA` do
  ChunkManager (piso não projeta). DiretorSombra continua com duas: TV e a luz
  principal.
- **Ambiente**: sai o marrom 0,48 e o `grade_tint` sépia; entra a sonda de
  reflexo do interior com ambiente escuro neutro, e preenchimento sem especular
  onde a escada de qualidade não tem SSIL.
- **Fumaça** no MODERNO: `FogVolume` sob o teto com densidade em ruído animado,
  e fios de fumaça por partícula macia saindo do cinzeiro e da mão. Acabam os
  tubos de neon. No PS1: placa com degradê de alfa, sem iluminação somada.
- **Luz jovem**: fita de LED atrás da TV em ciclo lento, luz negra no quarto
  (cartaz fluorescente), pisca-pisca na janela, abajur com cúpula.
- **Olho**: adaptação de exposição ao cruzar o limiar.

### 5.4 Critérios

| Critério | Alvo |
|---|---|
| Moldura da TV mais escura que a parede ao lado | pixel da moldura < pixel da parede |
| Escada de valor medida **na captura**, e não só na textura como o `tools/medir_valor.py` faz hoje | piso, parede e teto separados na imagem final, com o alvo fixado na primeira captura da F4 |
| Sombra existe | captura com e sem sombra difere na região atrás dos jogadores |
| Fumaça não é tubo | luminância da coluna ≤ luminância da parede atrás dela |
| Luz da TV segue a imagem | B−R e G−R da zona iluminada mudam entre partida e menu |

---

## 6. NPCs

| Hoje | Depois |
|---|---|
| Linha reta até ponto sorteado | `NavigationRegion3D` assada na thread a partir das caixas de colisão do lote (`NavigationServer3D.bake_from_source_geometry_data_async`) e `NavigationAgent3D` com desvio entre agentes e contra o jogador |
| Tranco ao sair e ao parar | aceleração e frenagem, giro no lugar antes de sair andando |
| Preso na mesa para sempre | detecção de travamento e novo destino |
| Ponto sorteado no vazio | **lugares com uso**: sentar no sofá (pose nova, no assento e não no chão), encostar no balcão e beber, fumar na janela e na laje, dançar perto da caixa, fila do banheiro, pegar cerveja na geladeira |
| Papo a 2,2 m | aproximam a ~1 m, grupos de 3 em roda |
| Ignoram o jogador | olham para quem entra, abrem espaço, cumprimentam |
| Fumante da calçada rouba o E | a porta ganha prioridade quando a mira está nela; o fumante sai do cone da porta |

---

## 7. Fases

Cada fase fecha com captura e com os critérios da seção dela.

| Fase | O que entra | Tamanho |
|---|---|---|
| **F0 — consertos que sobrevivem à v2** | cartaz "Israel" fora; `cast_shadow` do interior (vale para toda planta teleportada, inclusive as que só migram na F6); prioridade da porta sobre o NPC | P |
| **F1 — infraestrutura do interior no mundo** | lote vazado, três degraus de streaming, luz por camada, limiar com mistura, chuva com telhado, `Interiores` como fachada. **Com o conteúdo atual da sala**, para provar só a porta: abrir e ver dentro, andar e estar dentro | G |
| **F2 — planta nova e fachada** | térreo, pavimento superior, laje, quintal com a estufa sem teleporte, fachada própria, porta abrindo para dentro | G |
| **F3 — mobília, materiais, capas e cartazes** | peças da §4.2, PBR 1024, canto do PS2 com as capinhas, cartazes novos | G |
| **F4 — luz** | §5 inteira | M |
| **F4b — PS2 jogável** | pegar o controle e jogar a partida 2D da TV | M |
| **F5 — NPCs** | §6 inteira, mais o dono atendendo a porta | M |
| **F6 — todas as portas** | casa comum → apartamento (térreo) → mercado (sete cômodos, duas bocas: por último), mais as janelas falsas nos prédios sem porta. Teleporte removido quando a última planta migrar | G |
| **F7 — regressão** | `verificar_fumaca.py` migrado e critérios novos; rota de desempenho com a casa no caminho; plano 05 da abertura reencenado na casa nova | M |
| **F8 — corpo dos NPCs** | frente global com plano próprio | G |

---

## 8. Riscos

| Risco | Tratamento |
|---|---|
| Orçamento de 6.000 triângulos por chunk (`verificar_cidade.py`) | O conteúdo do lote é nó próprio, fora da malha fundida do chunk, com orçamento próprio medido nos degraus 1 e 2 |
| Luz no PS1 STYLE (Compatibility, 24 luzes por objeto) | Malha do interior partida por cômodo, cada pedaço vendo ≤ 8 luzes |
| O plano 05 da abertura usa `Interiores.entrar(77551)` | Reencenado na F7; até lá o teleporte continua existindo para ele |
| Item pego no interior é gravado na faixa `WorldState.INTERIOR` pela semente | A semente do lote continua a mesma; o registro não muda |
| `gerar_materiais` apaga `.tres` fora da tabela | Material novo entra na tabela antes de rodar o gerador |
| `--ver-abertura` sobrescreve 15 PNGs versionados | Capturas desta frente só em `captures/fumaca_v2/` |
| Sessões paralelas em `chunk_builder.gd` e `interiores.gd` | Conferir `git status` antes de cada fase |

---

## 9. Ideias vistas de passagem (não pedidas)

1. **O dono atende a porta.** Bater faz alguém vir de dentro e abrir; com o
   interior no mundo dá para ver a pessoa chegando pelo vidro.
2. **PS2 jogável.** Com a partida num `SubViewport`, pegar o controle vira
   jogar Bomba Patch de verdade, num minijogo 2D.
3. **Janela com interior falso no resto da cidade.** Shader de *interior
   mapping* nas janelas de prédio sem porta: a rua inteira ganha profundidade
   sem um triângulo a mais.
4. **Estufa no quintal** (já dentro da F2, listada aqui porque muda a missão da
   estufa).
5. **Corpo dos NPCs.** 236 triângulos lê como boneco de blocos no MODERNO. É uma
   frente global (pedestre, convidado, jogador), fora desta casa.
6. **Rótulo do HUD.** Nas capturas em 1280×720 o local aparece como "GASA
   FUMAGA": o C da fonte bitmap reescalada lê como G. Não investigado; suspeita
   na memória `fonte-de-bitmap-reescalada-por-fator-quebrado`.

---

## 10. Decisões (18/09/2026)

| Pergunta | Decisão | Consequência no plano |
|---|---|---|
| Capas e cartazes | **Capas reais da internet** | F3 baixa as capas reais. Ficam numa pasta própria (`assets/textures/capas_reais/`) para que um build distribuído possa trocá-las sem mexer em código — a imagem real serve para cópia pessoal |
| Mobília | **Procedural + PBR CC0** | F3 cria um kit de móveis em código (chanfro, almofada, costura) com texturas do ambientCG em 1024 px; nenhum pipeline de glTF |
| Escopo das portas | **Piloto e depois todas** | Ordem da §7 mantida: casa da fumaça (F1–F5), depois casa comum, apartamento e mercado (F6) |
| Extras | **Os quatro** | Entram como abaixo |

Onde cada extra entra:

| Extra | Fase |
|---|---|
| Dono atende a porta | F5, junto dos NPCs; depende da F1 (sem interior no mundo não há ninguém para ver chegando) |
| PS2 jogável na TV | nova **F4b**, logo depois da luz: a partida em `SubViewport` da F4 é a base do minijogo |
| Janelas falsas na cidade | F6, junto da migração das portas: é a mesma pergunta — o que se vê de dentro de um prédio pela rua |
| Corpo dos NPCs | frente própria **F8**, global (pedestre, convidado, jogador), com plano separado; não bloqueia F1–F7 |

---

## 11. Fontes da pesquisa

- [As 10 capas de discos mais icônicas da música brasileira — TMDQA!](https://www.tenhomaisdiscosqueamigos.com/2024/10/10/capas-iconicas-musica-brasileira/)
- [Racionais MC's — Wikipedia](https://en.wikipedia.org/wiki/Racionais_MC%27s)
- [Brazilian hip-hop — Wikipedia](https://en.wikipedia.org/wiki/Brazilian_hip-hop)
- [Charlie Brown Jr.: discografia — Cifra Club](https://www.cifraclub.com.br/blog/discografia-charlie-brown-jr/)
- [PlayStation 2 faz 20 anos: 20 jogos icônicos — TMDQA!](https://www.tenhomaisdiscosqueamigos.com/2020/03/05/playstation-2-lista-jogos/)
- [Bomba Patch: a história cult do futebol na era PS2](https://gamerdasantigas.com/blog/bomba-patch/)
- [GTA: Rio de Janeiro — TechTudo](https://www.techtudo.com.br/guia/2025/11/gta-rio-de-janeiro-relembre-versao-de-san-andreas-que-bombou-no-ps2-edjogos.ghtml)
- [Commons: regras de direito autoral do Brasil](https://commons.wikimedia.org/wiki/Commons:Copyright_rules_by_territory/Brazil)
- [Poly Haven — modelos de mobília CC0](https://polyhaven.com/models/furniture)

## 12. Progresso (19/09/2026)

| Fase | Estado | Prova |
|---|---|---|
| F1 | feita: porta abre para dentro e mostra a sala; rotulo vira "Fechar" no trinco | captura `porta` |
| F2 | planta nova de 11,6 x 15,5 m: sala, cozinha americana com balcao, corredor, estudio, banheiro, porta dos fundos no fim do corredor (estufa). `tests/lote_fumaca.gd`: 20 m livres atras de toda casa, face minima 20,2 m | capturas `entrada`, `sofa`, `cozinha`, `corredor`, `estudio`, `banheiro` |
| F3 | `KitMovel` (sofa de courino, rack, TV de tubo, estante de CD, som com toca-discos, caixote de LP, geladeira, pia, filtro de barro, estudio com MPC, espuma, banheiro) em PBR ambientCG (`courino`, `tecido`, `tapete`, `azulejo_cozinha`, `mdf`, `plastico`); 27 capas de disco e 27 de PS2 + 4 CD-R piratas em `capas` (`tools/baixar_capas.py`) | idem |
| F4 | luz com fonte visivel por comodo (fita de LED, luminaria, pisca-pisca, pendentes, calha fria, lampada nua, luz negra), `FogVolume` de fumaca, sonda de reflexo propria da casa, `gi_escala` 0,1 no preset (SDFGI enchia o comodo: mediana 121 com GI cheio, 92 sem, 104 com 0,1) | `tv` e pares `tv_semgi` |
| Consertos de passagem | decalque de pichacao da rua fino (12 cm) e longe de porta — pintava fita laranja no fumante; casa ativa em qualquer ponto do lote (save/teleporte na cozinha) | `fachada` |

| F4b | `PartidaPS2`: partida 11 x 11 em 2D (SubViewport 320 x 240) no tubo com shader CRT (`tela_crt`), camera de transmissao, placar, radar, gol com replay, intervalo e fim; menu "Bomba Patch" na TV do PS2 e "AO VIVO" nas TVs de bar e casa. Luz da TV segue a imagem (campo verde-ciano, menu azul, gol piscando) e a torcida sai do tubo. `ControlePS2` na mesa de centro: pegar, sentar no sofa com a lente fechada no tubo e jogar ([E/A] passe, [Q/Y] chute, [Shift] correr, [Esc/B] largar). `tests/partida_ps2_sim.gd`: 7 partidas em 30 min simulados, 25 chutes, 8 gols, 10 defesas; humano com a bola 354 de 3600 ticks, 15 chutes | captura `jogando` |
| Consertos de passagem (F4b) | sentar no sofa prendia para sempre: `travado` engolia o [E]. Agora quem senta registra a saida (`Player.ocupar`); `olhar_para` mede do olho baixado | |

| F5 | `CasaViva`: malha de navegacao assada da colisao do lote num mapa proprio de celula 8 cm (na celula de 25 cm do mapa padrao a porta de 90 cm fechava), `NavigationAgent3D` com desvio RVO por convidado e o jogador como obstaculo. 17 lugares com uso e reserva (sofa, banqueta, cadeira da cozinha, pista de danca, colchao, janela de fumar, geladeira, estante de CD). Posturas novas `ASSENTO` (pelve no assento, coxa horizontal, tronco recostado ou debrucado conforme a altura) e `DANCANDO` (quique, quadril e tronco em contratempo a 2,15 Hz). Quem bate na porta da rua chama o dono, que atravessa a casa e abre por dentro. Relatorio de 4 min: 6 a 8 dos 17 usos ocupados, `presos=0` | capturas `sofa_frente`, `sofa_lado`; `--relatar-casa` |
| Consertos de passagem (F5) | sentado de costas para a TV: `_encarar` derivava o angulo no mundo e escrevia em `rotation.y` local — so batia na sala teleportada, e a planta no mundo vem girada. Todo giro passou a `global_rotation` (`_por_giro`): `frente.tv` foi de -1,00 para 1,00 com o joelho 41 cm a frente do quadril. E o vigia de empaque desistia na primeira janela de 1,5 s, contando como movel no caminho o corpo virando no lugar: exige tres faltas seguidas, e `presos` caiu de 7 para 0 na mesma sessao | |

Falta: F6 (demais portas e janelas falsas), F7 (regressao), F8 (corpos de NPC) e na F2 o pavimento de cima e a laje. A estufa de 10 andares (secao 13) esta feita — ver 13.6.

## 13. A estufa de dez andares (Jota e Helmer)

A porta dos fundos da casa da fumaca e a unica do jogo que nao devolve um
comodo do tamanho da casa. Ela e um interior teleportado — nao ocupa lote, nao
tem vizinho, nao tem teto de rua em cima —, e isso sempre foi uma limitacao
aceita. Agora e a piada: **uma casa terrea de 2,45 m de pe direito tem, atras da
porta da cozinha, um poco de vinte e oito metros.**

A graca nao esta em ser grande. Esta em ser grande **no primeiro quadro**. Quem
entra hoje ve seis linhas de vaso e um corredor de 3 m; quem entrar depois
disso tem de olhar para CIMA antes de olhar para a frente, e e por isso que a
planta muda de sala para poco.

### 13.1 O que a sala tem de dizer

|  | hoje | depois |
|---|---|---|
| planta | 7,6 x 12,0 m | 12,0 x 18,0 m |
| altura | 2,85 m | 29,25 m (9 x 2,75 + o andar 10 de 4,5) |
| enquadramento de entrada | corredor ate o fundo | poco central, 10 galerias acesas subindo |
| o que o jogador faz | o ciclo do Plantio, no chao | o mesmo ciclo, no chao — mais o elevador ate o 10 |

O ciclo de cultivo **nao muda**. `Plantio`, `Plantacao`, o censo que Helmer le
em `falas_npc.gd`, os 24 vasos de `EstufaBuilder.lugares()`: tudo continua valendo,
so que espalhado num chao quatro vezes maior. Fase nova nenhuma entra no
WorldState. E deliberado: a estufa ja tem uma operacao que funciona, e a piada
de escala nao pode custar o unico comodo do jogo que o jogador cuida.

### 13.2 Os dez andares, e quais deles sao de verdade

Dez andares simulados custariam dez vezes o comodo por nada. O que se ve e o
que se anda sao coisas separadas:

- **Terreo (andar 1) — a lavoura.** O comodo de hoje, esticado para 12 x 18.
  Vasos, bancada, insumos, secagem, os dois trabalhando. Colisao completa.
- **Andares 2 a 9 — a vista.** Galerias de 3 m de largura em volta do poco,
  cada uma com a propria fileira de refletor aceso e a propria placa pintada a
  mao. Sao geometria vestida: uma superficie fundida por material e por andar,
  planta em cruz de dois quads em vez da malha da `Plantacao`, colisao nenhuma.
  Nao da para chegar neles, e o elevador diz por que.
- **Andar 10 — o SUPER QUARTO DA MACONHA.** O unico andar de cima em que se
  pisa. Sala fechada, 9 x 7 m, com colisao, luz propria e os quadros. E o
  laboratorio de Jota e Helmer, e e onde as frases acontecem.

Quem sobe: um **elevador de carga** de andaime com talha de corrente, no canto
nordeste do poco. A lista de andares e pintada na chapa ao lado do botao, e a
lista e metade da piada:

```
  1  LAVOURA          6  NAO SUBIR
  2  SECAGEM          7  NAO SUBIR (SERIO)
  3  MUDA             8  O ANDAR DO CHEIRO
  4  MUDA TAMBEM      9  ???
  5  MUDA AINDA      10  SO O JOTA E O HELMER
```

O botao so aceita 1 e 10. Apertar qualquer outro acende a luz do andar por um
instante e devolve `"Esse andar ta interditado."` — que e o jeito de os oito
andares existirem sem custar sala nenhuma.

### 13.3 O andar 10

Nao e estufa: e oficina de quimico. Bancada de inox, becher, uma planta unica
de 2,4 m num vaso de 200 litros sob luz roxa, e as paredes tomadas de quadro.
O pe direito e 4,5 m — o dobro do resto —, porque a planta precisa caber e
porque o ultimo andar tem de ser o mais alto de todos.

**Os quadros.** Oito telas, desenhadas por `tools/gerar_quadros_maconha.py`
numa fileira propria do atlas, no mesmo caminho das capas de disco da F3 —
procedurais, e nao baixadas: sao pastiche de quadro famoso, e pastiche de
quadro famoso baixado da internet e problema de direito autoral sem necessidade
nenhuma. A lista: a folha de sete pontas em ouro sobre fundo vermelho de
bandeira, um girassol que e uma planta, a ultima ceia com um baseado girando na
mesa, uma mona lisa de olho vermelho, um retrato de Jota fardado de general, um
gato de olho fechado com a pupila em fenda, o dedo de Deus acendendo um isqueiro
e uma nota fiscal emoldurada. `KitMovel.quadro()` ja monta a moldura e a placa;
so a fileira do atlas e nova.

### 13.4 As falas

Bloco novo em `falas_npc.gd`, `SUPER_MACONHA`, escolhido quando o contexto e
`estufa` e o jogador esta no andar 10. Helmer e o que diz numero e o numero
confere (`teste_estufa.gd` ja cobra isso dele); Jota e o que quer mais.

**Jota — olho de gato**
- "Essa aqui nao e pra vender na praca nao. Dois trago e o cliente fica com
  olho de gato: enxerga no escuro, atravessa o beco sem tropecar no mei-fio."
- "Ja testei no gato da vizinha. Ficou com olho de gente. Deu errado ao
  contrario."

**Helmer — o numero**
- "Olho de gato e em nove de cada dez. O decimo enxerga som. A gente ainda nao
  sabe o que fazer com esse."

**Jota — voar/explodir**
- "Tem a linha de cima tambem. Metade dos cliente explode... e pros mais
  ousado, voam."
- "Quem voa sempre volta. Nunca no mesmo bairro, mas volta."

**Helmer — fechando**
- "A gente separou por prateleira: explode na de baixo, voa na de cima. Ja
  trocou uma vez. Foi um dia comprido."

Todas passam pelo mesmo `dizer()` dos outros NPCs, com o intervalo de
cumprimento da `CasaViva` para os dois nao falarem juntos.

### 13.5 Ordem de execucao

| Passo | O que entra | Como se prova |
|---|---|---|
| E1 | casca do poco 12 x 18 x 29,25, galerias 2-9 vestidas, terreo esticado com os 24 vasos e os insumos nos novos cantos | captura da entrada olhando para cima; `--headless` sem erro; contagem de triangulos |
| E2 | elevador de andaime, chapa de andares, botao com 1 e 10 e a recusa dos outros | captura dentro do elevador; subir e descer numa sessao |
| E3 | andar 10: sala, planta gigante, luz roxa, bancada | captura do andar 10 |
| E4 | `tools/gerar_quadros_maconha.py` + os oito quadros na parede | captura dos quadros |
| E5 | bloco `SUPER_MACONHA` com Jota e Helmer no andar 10 | as seis falas na sessao |
| E6 | LOD por andar e medida de custo contra o comodo de hoje | quadros por segundo na entrada, antes e depois |

### 13.6 O que foi feito, e o que as medidas disseram

Os seis passos estao no jogo. Cada um foi provado pelo que a tabela de 13.5
pedia, com `--entrar-estufa --andar-dez --dez-saida=PASTA` (cidade.gd), que faz
a sessao inteira pelo caminho do jogador: mira na chapa, aperta um andar
interditado, mira no botao, sobe, fotografa, desce e confere a dupla.

| Passo | Medida |
|---|---|
| E1 | o poco agora comeca na parede da porta. Com uma faixa de galeria sobre a soleira, a primeira captura olhando para cima era o forro do 2o andar a um metro da cabeca |
| E2 | a cabine e AnimatableBody3D; o pe do jogador fica a 0,000 m do piso dela a viagem inteira, subindo e descendo. Mira no botao e na chapa pelo raio de verdade: sim e sim |
| E2 | as placas dos andares estavam na parede sul e a nevoa de 16 m comia todas; viraram faixas de duas faces penduradas a 1,3 m da grade |
| E3 | a planta de 2,5 m saiu primeiro como cone fechado de folha — arvore de Natal. Refeita em galhos com tufo na ponta e vao entre eles |
| E4 | atlas proprio (`estufa_quadros.png`, 256 cores), material registrado em `gerar_materiais.py` |
| E5 | Jota e Helmer nao tem copia: estacionam no 10 tres segundos depois da partida (fora da vista) e esperam na grade quando a cabine desce; "A gente veio de escada." na primeira descida; voltam a rotina de fazendeiro 4 s depois |
| E5 | o jogo nao tinha legenda fora de cena cortada. `Cinema.fala` e a mesma legenda sem tarja e sem travar, 40 px acima do prompt de interacao |
| E6 | RX 9070 XT, Forward+: mediana 1,1 ms na entrada, 1,1 subindo, 1,2 no andar 10; 65 a 105 chamadas. Os picos de 140 ms sao todos o `get_image` da propria foto. LOD por andar nao se paga |

Consertos de passagem: o duto transversal do terreo cortava o vao do elevador
na altura do teto da cabine (recuado para rente a parede do fundo); amarelo e
zinco sobre a celula de mangueira saiam pretos (tinta multiplica, e a
mangueira e preta — agora sobre a lona).

## 14. As entregas da Super (o ciclo que liga o andar 10 a rua)

Pedido do jogador depois da secao 13: Jota e Helmer fazem as entregas; eles
encontram os clientes em pontos do mapa, entregam, e SO DEPOIS o cliente fuma e
tem o efeito que a dupla promete no andar 10.

| Tempo | Onde | O que acontece |
|---|---|---|
| colher | andar 10, [E] na planta | 4 doses de "Super" no inventario; as colas somem e a planta cresce de novo em 6 h de jogo (3 min reais) |
| encomendar | conversa com Jota ou Helmer | "LEVA A SUPER PROS CLIENTES" tira as doses do bolso e poe na conta da dupla |
| entregar | na rua, a 8-22 m na frente do jogador | um dos dois vem pela calcada ate um pedestre de verdade, entrega, e vai embora; o outro avisa "no celular" |
| efeito | o mesmo pedestre, depois do trago | olho de gato (58%), enxerga som (7%), explode (19%) ou voa (16%) |
| depois | a cidade | quem ficou com olho de gato anda na rua com os olhos acesos; quem voou volta, de vez em quando, cruzando o ceu |

Tambem entrou "andares com vida": o 8 tem nevoa verde nas galerias, o 7 tem uma
porta que bate por dentro quando a cabine passa, o 9 e o unico andar apagado e
tem dois olhos no escuro que fecham quando a cabine chega na altura deles.

Arquivos: `world/entregas_da_super.gd` (novo, o ciclo inteiro), `SuperQuarto`
(colheita), `FalasNpc.ENTREGAR`, `resources/itens/super_maconha.tres`. Nada em
`pedestre.gd` nem `multidao.gd`: o cliente e congelado por fora.

A folha de conversa desenha 8 linhas e a estufa ja usava 8. No andar 10 "E ESSA
PLANTA AI?" toma o lugar de "COMO VAI A PLANTACAO?"; com Super no bolso, o
acerto da entrega toma o lugar de "SOBRE ESTE BAIRRO". `teste_estufa` cobra os
dois (`super_lista_cabe=1`).

Provas: `--teste-entrega=olho|som|explode|voa --dez-saida=PASTA` fotografa as
tres fases e o voo de volta; `--andar-dez` colhe a planta (`colheu=4`);
`--teste-estufa` cobra oferta, lista, doses saindo do bolso e a dupla
recebendo (`super_dupla_recebe=3`).

## 15. iWeed, Trampo e a conversa nova (21/09/2026)

**Conversa (ui/conversa.gd).** Reescrita no vocabulario RE7, vetor (nitida em
4K no MODERNO): retrato de quem fala, nome, subtitulo (profissao e idade quando
identificado, "NAO IDENTIFICADO" quando nao, funcoes da folha para a equipe),
lista a direita com icone por tipo, ponto de "novo", destaque animado, teclas
desenhadas na tarja. A ultima fala fica esmaecida enquanto se escolhe. O HUD do
grupo `hud` some durante a conversa. `MAX_OPCOES = 10`. API igual.

**TRABALHO.** Opcao nova para quem tem profissao (ou funcao na folha). A pessoa
responde e mostra o perfil no celular (app Trampo); fechar o aparelho devolve a
lista.

**Celular.** TRAMPO e IWEED no lugar de CAMERA e GALERIA (so davam "sem sinal").
Apps coloridos em vetor (`AppCelular`), barra de status vetorial, relogio do
aparelho = relogio do jogo.
- Trampo: rede (equipe + conhecidos com trabalho), busca por nome (mesmo indice do
  terminal do mercadinho, mais a equipe), perfil: local, horario, expediente
  agora, tempo no cargo, avaliacao; equipe com "agora" ao vivo (REGANDO O VASO 3,
  INDO AO ORELHAO) e numeros (entregas, no prazo, tarefas, rendeu).
- iWeed: PEDIDOS (quem, o que, preco, janela, lugar, distancia, expira), AGENDA
  (quem vai: voce/JOTA/HELMER), CLIENTES (satisfacao, pedidos, OLHO DE GATO /
  EXPLODIU / EM ORBITA), EQUIPE (estoque da estufa e status ao vivo), GANHOS
  (saldo e extrato). E aceita, F passa para a equipe, X recusa, O online.

**Motor (world/iweed.gd).** Relogio absoluto proprio (1 min de jogo = 30 s
reais). Clientes de verdade do registro civil (3 iniciais; cliente contente
indica outro). Pedido: produto (maconha/Super), quantidade, preco, janela de
7-11 min de jogo, ponto de encontro sorteado entre os pontos do GPS (orelhao,
bar, praca, mercadinho, portaria) a 40-190 m. Online, o pedido chega como
notificacao; sem aceite em 2,5 min, a equipe pega se tiver gente livre e
estoque. Offline, vai direto para a equipe (e so nasce se o estoque cobre).
- Jogador aceita: rota no GPS, cartao no HUD (prazo, distancia, seta, "no bolso"),
  cliente aparece no ponto com losango verde; [E] entrega, paga o preco inteiro;
  sem mercadoria ele reclama e espera; passou do prazo, vai embora.
- Equipe: sai do estoque (prateleira da estufa / doses da Super), viagem pela
  distancia da casa, paga 70% (30% de comissao). Com o jogador perto do ponto a
  cena acontece de verdade (EntregasDaSuper.encenar); longe, resolve na conta.
- Super: efeito sorteado (olho de gato, enxerga som, explode, voa) vai para a
  ficha do cliente e para as listas da rua.

**Dupla natural.** Jota e Helmer sao a mesma dupla em qualquer estufa (id
guardado), contratados uma vez como FAZENDEIRO e ENTREGADOR (Profissoes aceita ate
2 funcoes). Pegou pedido com o jogador na estufa: "Fui, tem entrega", sai pelo
corredor e pela porta; volta pela mesma porta ("Voltei. Entregue e pago.").
Fora, a estufa anda sozinha (Plantio.sincronizar a cada 2 min de jogo), a
prateleira enche, e a Super pronta ha 12 min e colhida pela dupla. Tarefas e
colheitas contadas por pessoa. Vigia de empaque no caminho reto.

**Dinheiro (systems/dinheiro.gd).** Primeiro saldo do jogo, com extrato.

**Correcoes.** Super voltava em 360 min de jogo (3 h reais): agora 30. Pontos de
encontro lidos 3 chunks por quadro (o sorteio custava 9 ms num quadro; agora
0,2 ms).

Provas: `--teste-iweed --iw-saida=PASTA` (26 criterios, 0 falhas) e
`--entrar-estufa --teste-equipe` (13 criterios, 0 falhas); `--teste-estufa` e
`--teste-npc` verdes. Capturas em 4K com `--estilo=moderno --resolution 3840x2160`.

## 16. Loja, chat, blitz, legenda e menu (21/09/2026, segunda leva)

Escolhidas pelo usuario na lista de ideias.

- **Loja no iWeed** (6a aba): sementes, terra e regador vao para a mochila;
  lampada de cultivo (3 niveis, +25% de crescimento cada), irrigacao (agua dura o
  dobro), bicicleta da equipe (entregas na metade do tempo), luz roxa (Super em
  20 min), propaganda (cliente novo na hora). `IWeed.LOJA`, `comprar`, `nivel`;
  os fatores entram em `Plantio.fator_crescimento/fator_agua`.
- **Chat com clientes**: cada pedido tem conversa (cliente pede, diz onde e
  quando, avisa "to aqui", cobra "vai demorar?", agradece). Contraproposta uma
  vez por pedido (+25% ou +50%; chance cai com o aumento e sobe com a satisfacao;
  +50% recusado cancela). "Vou atrasar" estende a janela uma vez. [M] abre a
  conversa nos PEDIDOS e na AGENDA.
- **Blitz no caminho** (`world/blitz_no_caminho.gd`, so API publica da blitz): a
  pe e com mercadoria, entrar no funil da blitz da 40% de abordagem (100%
  procurado). Abre a conversa com contexto `blitz`: ABRIR A MOCHILA (confisca),
  OFERECER UM CAFE (R$ 30 + 20% da mercadoria; 65% aceita, 30% procurado; recusa
  confisca e multa), SAIR CORRENDO (50%: escapa procurado; 50%: confisca e multa).
  **X9**: 12% dos clientes indicados; entregar a um X9 marca PROCURADO por 4 min
  de jogo e chama uma blitz; se foi a equipe, quem foi fica detido 8 min e a
  mercadoria some. X9 aparece na carteira de clientes.
- **Legenda nova** (`Cinema.legenda/fala`): semibold vetorial sobre caixa escura
  do tamanho do texto; "NOME (celular): fala" vira etiqueta NOME · CELULAR em
  ferrugem dentro da caixa. A30b da bancada de cinema passa.
- **Menu SISTEMA**: modelo de linha unico (topo da linha manda em texto,
  destaque, barra, clique e divisor); folha centrada quando alta; icones na raiz;
  teclas desenhadas; botao dos pauzinhos acima da faixa e apagado com a folha
  aberta. Causa do bug da print: altura de clique de 32 px usada como passo.
- **Inventario**: o bonequinho que olha o cursor voltou para a polaroid (estava
  so escondido desde o "Push"); busto enquadrado pela boca de quem esta na foto;
  com o mouse parado, olha o item selecionado. Vitais desenhados centrados na
  fita marrom do cartao; saldo no cartao; carimbo PROCURADO; teclas desenhadas.

Provas: `--teste-iweed` agora com 41 criterios (loja, chat, legenda, X9, blitz),
0 falhas; fotos do menu com `--abrir-inventario`, `--ver-pausa`,
`--ver-pausa=imagem`.

Depois da revisao visual (agente revisor, tres passadas nas capturas 4K):
retrato da conversa virou busto 3D vivo (SubViewport 80x104, boca mexe na
fala; o retrato 2D nao desenhava chapeu e o policial aparecia sem farda); a
notificacao do iWeed vai para a esquerda com conversa aberta e quebra em duas
linhas; fala de celular que chega durante uma conversa espera ela fechar;
deslizante com contorno de tinta; inventario com vitais centrados, ESTÁVEL
com acento, abas acima da tarja, botao dos pauzinhos fora da seta. Fora do meu
escopo, anotado: distancia sob o minimapa ilegivel na nevoa clara
(minimapa.gd), um NPC encavalado no policial da blitz (blitz.gd).


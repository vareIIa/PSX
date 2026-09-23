# Plano Carros AAA

Levar os sete carros do jogo (Sedan, Hatch, Perua, Picape, Taxi, Marea, Fusca) a
qualidade AAA no estilo MODERNO. O PS1 STYLE continua com cara de PS1 (atlas,
480x270, vertice), mas nao e teto: geometria melhor vale para os dois presets
(memoria `moderno-nao-e-psx-forcado`).

Iniciado em 22/09/2026.

## Ponto de partida (mapeado em 22/09/2026)

- Nao ha modelo importado: toda carroceria e malha procedural (`Carroceria` +
  `carroceria_caixa/fusca/marea.gd` sobre `CarroceriaVarrida`), um atlas de
  256 px (`carro_atlas.png`) e cor de vertice.
- Um material so para lataria, vidro, cromo, plastico e pneu (`mat_carro`). No
  MODERNO ele vira `psx_surface_pixel`: `METALLIC = 0`, uma rugosidade para o
  carro inteiro, sem verniz.
- O vidro e uma placa opaca colada 1,2 cm por fora de um casco FECHADO. Nao ha
  vao atras dele: nenhum motorista aparece de fora (memoria
  `vidro-da-carroceria-e-opaco`), e isso trava a abertura co-op.
- Roda de 8 lados, calota chapada, farol e lanterna decalcados.
- Nenhuma malha do carro projeta sombra.
- A fisica (suspensao, atrito, deriva, freio) ja esta calibrada por bancada e
  fica fora deste plano.

## Regras

1. Efeito de material nasce atras do estilo (shader proprio escolhido pela
   `EstiloVisual`). Geometria nova vale nos dois, e a vitrine PS1 e fotografada
   antes e depois para provar que ele continua PS1.
2. A geracao continua procedural. Nao entra .glb.
3. Cada fase entrega teste proprio e custo medido (triangulos e chamadas de
   desenho por carro).
4. Ideia fora da lista vira pergunta ao usuario, nao decisao.

## Fases

### F1 - Vidro de verdade e gente dentro (entregue)

- Casco com VAO nas janelas, para-brisa e vigia (`CarroceriaVarrida.casco`
  recebe as mesmas tabelas `vaos` / `seg_p` / `seg_v` que desenham o vidro), com
  a borda do vao dobrada para dentro (espessura da porta e borracha).
- Vidro numa superficie propria da malha `corpo`, com `mat_carro_vidro`.
  No PS1 ele e o mesmo vidro opaco de sempre; no MODERNO e transparente, escuro,
  com Fresnel e reflexo do ceu.
- Interior simples do transito (bancos, painel, volante) numa malha separada,
  escondida quando a cabine do jogador entra.
- Criterios: motorista NPC visivel de fora no MODERNO; vitrine PS1 igual; a
  cabine do jogador continua vendo a rua pelas janelas; custo medido.

### F2 - Material por peca (entregue)

- Classe de material por vertice (UV2.x) e sujeira (UV2.y), escritas na
  montagem a partir da celula do atlas e da cor; o PS1 nao le a UV2.
- `psx_carro.gdshader` no MODERNO: pintura com verniz (clearcoat) e casca de
  laranja, cromo metalico, plastico acetinado, borracha fosca, assoalho; a
  sujeira tira o verniz. Face de tras vira forro escuro (o carro deixa de ser oco
  visto pela janela).
- Chuva na lataria (gotas, molhado) preservada do `psx_surface_pixel`.

### F3 - Rodas (entregue)

`carroceria_roda.gd`: pneu de 30 lados com perfil de dez pontos (talao, flanco
abaulado, ombro, banda com o sulco do atlas), aro com aba e prato, face com
furos de verdade e parede de chapa, tambor escuro atras. Quatro desenhos:
calota de plastico (sedan, perua, taxi, metade dos hatch), aco grafite com
porcas (picape, a outra metade dos hatch, e um em cada cinco sedans que perdeu
a calota), liga de cinco raios (Marea), aco pintado com copo cromado (Fusca).
No PS1 a roda e de 12 lados com a calota do atlas. Malhas em cache.

### F4 - Luzes (entregue)

- `psx_carro_luz.gdshader` no MODERNO: farol com refletor prateado, aneis de
  Fresnel e ponto quente da lampada; lanterna e pisca com prisma facetado;
  verniz de vidro por cima e emissao HDR para o bloom. PS1 no psx_surface.
- `CarroceriaVarrida.moldura_luz`: aro com volume em volta da lente (cromo no
  farol, preto na lanterna) e a lente recuada no tunel. Carros de caixa e Marea;
  o Fusca ja tinha o farol redondo em camadas.
- A luz de freio que pinta o chao ja existia (`_brasa` sobe na freada).

### F5 - Sombra e contato (entregue em parte)

A lataria projeta sombra no MODERNO (`Carro._aplicar_sombra`, segue a troca de
preset); no PS1 continua so a mancha de contato. Falta medir o custo no
transito cheio e rever a mancha.

### F6 - Lataria (entregue, menos a placa)

- A tinta do MODERNO deixou de ler o atlas: as celulas de pintura sao desenho
  de PS1 (linha de porta, pingo de ferrugem) repetido em cada painel — eram os
  "rabiscos". Desbotado, barro e ferrugem agora sao procedurais e sobem com a
  sujeira (UV2.y).
- Normais suaves ate 38 graus de dobra (`CarroceriaVarrida.suavizar`): o casco
  deixou de ler como poliedro; vinco, quina e espessura de janela ficam vivos.
- Porta, soleira, capo e tampa do porta-malas sao VINCO na chapa (sulco em V
  de 1 cm de boca e 6 mm de fundo, com a oclusao assada no fundo), e nao mais
  faixas pretas coladas por fora.
- Caixa de roda recortada no flanco, com para-lama interno, parede, assoalho
  estreitado e uma aba de chapa em volta da boca, no lugar da faixa escura
  pintada.
- Friso de cromo e borracha com perfil (chanfro, face, chanfro), cortado em
  cada porta; macaneta com concha e puxador.
- Falta: placa legivel com conteudo real trocavel.

### F7 - Desgaste e variedade (entregue)

Quatro tintas de epoca a mais (prata, champanhe, vinho, verde-garrafa) e
pintura metalica por semente (`Carroceria.metalica`: prata e champanhe sempre,
30% das outras; taxi e Fusca nunca), com floco de aluminio sob o verniz no
MODERNO (`instance uniform metalico`). Sujeira e ferrugem ja eram procedurais
(F6).

### F8 - Dano (entregue)

- Amassado de fabrica: um carro da rua em cinco nasce com 1 ou 2 amassados
  leves, aplicados nos dados antes de virar malha (`Carroceria.montar`,
  parametro `amassados`), na lataria, no vidro, no interior e na versao de
  longe. O amassado do carro conhece as batidas de fabrica e soma a proxima.
- Batida no transito: o carro da rua em que o jogador bate amassa do lado da
  pancada (`Carro.levar_batida`).
- Vidro trincado: batida a partir de 0,45 trinca o vidro mais perto
  (`psx_carro_vidro`, `instance uniform trinca`): teia no centro, treze raios e
  tres aneis quebrados, fio de 1,5 a 4 mm.
- A grade do casco ficou CONFORME na faixa de baixo, no topo por regiao, no
  assoalho e nas tampas: junta em T abria fresta quando o amassado deslocava o
  vertice. E o motorista sai do caminho da porta afundada
  (`Carro.afastar_da_porta`): a canela dele atravessava a lataria.

### F9 - Orcamento e LOD (entregue)

- Cache do casco por modelo e sujeira, com a tinta aplicada por conta linear
  (base preta + diferenca da branca, provado vertice a vertice pelo A6 do
  `checar_carros_aaa`). `Carroceria.aquecer` monta os 14 cascos na largada do
  `Transito` (510 ms, uma vez).
- Versao de longe a 28 m (folga de 2 m, `visibility_range`): lataria sem vinco,
  caixa de roda, friso nem macaneta, e roda de 12 lados. 1.170 a 1.680
  triangulos contra 7.700 a 9.300 de perto. O carro do jogador desliga o LOD
  (so a malha de perto amassa); o interior some a 22 m.
- Falta: medir o transito cheio contra o teto de chamadas.

### F10 - Cambio, pedal e molas (entregue)

- Cambio automatico com memoria do pe (`Motor.vontade`): o W tocado nao sobe
  marcha em cascata, soltar segura a marcha, pisar reduz (kickdown, pulando
  marcha no pe no fundo), e a reducao fica travada 1,2 s depois de uma subida
  feita com o pe embaixo.
- Pedal com curso (`Carro.PEDAL_SOBE`): o torque nao entra inteiro num quadro.
- Carro da IA com a carroceria sobre molas (`Carro._balancar`), as mesmas do
  `CarroCena`: freada afunda o bico, arrancada senta a traseira, curva deita,
  e as rodas ficam no chao.

### F11 - Cabine da cidade (entregue)

- Santinho no retrovisor, balancando com a aceleracao e a inclinacao do carro.
- Maos modeladas (`MaoModelada`, 1.408 a 1.468 triangulos cada): palma
  arredondada, quatro dedos de tres falanges fechando em volta do tubo do aro,
  polegar, punho e antebraco (ou manga com bainha), com esqueleto de dois ossos:
  a mao gira com o volante e o antebraco segue o cotovelo, que fica parado no
  carro. "Nove e quinze" na cidade; a mao esquerda da cena da estrada usa o
  mesmo construtor. So na vista de dentro. Bancada: `tests/bancada_maos.tscn`.
- Em aberto: a pele sai clara de dia no MODERNO. Medido: nao e a emissao do
  mat_npc (a 0,08 a mao continuou igual) nem a luz da cabine (apagada, igual);
  e a cor de vertice sRGB lida como linear, que clareia toda pele do jogo.

### F12 - Som do motor (entregue, falta ouvido)

- `tools/gerar_motor.py`: tres arquiteturas — quatro em linha, tres cilindros
  (hatch 1.0) e boxer a ar (Fusca) —, cada uma numa grade de 7 a 8 giros com e
  sem carga. Cada amostra e um trem de explosoes na frequencia real, com
  variacao de ciclo a ciclo, passando por coletor, abafador, ponteira e
  radiacao; admissao so em carga alta, estalo e assobio no alivio, tucho,
  correia e (no boxer) a ventoinha. Laco fechado em numero inteiro de ciclos.
  47 arquivos, 32 kHz, 3,46 MB.
- `motor_som.gd`: uma voz por amostra, cruzamento de potencia constante entre
  os dois giros vizinhos e entre com/sem carga, todas afinadas e em fase;
  zumbido de cambio pela relacao giro/roda. O transito continua com uma voz.
- `tests/bancada_motor_som.gd`: 55 de 55 sem janela, 58 de 58 com o driver de
  audio de verdade (saida capturada no Master).

## Registro

### 22/09/2026 - F1 e F2

- `tests/checar_carros_aaa.gd`: 7 modelos verdes (vao atras de cada vidro,
  interior contido no casco, classes de material, PS1 nascendo no psx_surface).
- Chamadas de desenho: +1 superficie de vidro e +1 malha de interior por carro.

### 22/09/2026 - F3, F6, F10, F11

- `checar_carros_aaa.gd`: 7 de 7 verdes depois da lataria nova. Triangulos da
  lataria do sedan: 798 -> 2910 (grade do flanco e caixas de roda); Marea 848
  -> 2960; Fusca 1060 -> 1690. A F9 (LOD) fica mais necessaria.
- `tests/bancada_cambio.gd` (nova): 98 de 98 nos sete carros. Antes: com o W
  tocado o sedan terminava em QUARTA a 47 km/h (o pe no fundo usaria a
  primeira), tirar o pe subia 1-2-3 e pisar de novo ficava em 2000 rpm.
- `tests/bancada_dirigir.gd`: 36 de 36 (SEDA, PICAPE, FUSCA, MAREA) com o pedal
  de curso.
- `tests/bancada_mola_ia.gd` (nova): 6 de 6 — freada afunda o bico 2,2 graus e
  assenta em 0,5 s, arrancada senta 1,1, curva deita 3,4 para fora, rodas no
  chassi, assumir devolve a lataria.
- Fotos: `captures/carros_aaa/f6/` (antes: `sedan_34_a`, depois: `sedan_34_b`,
  `marea_34`, `fusca_34`, `fila_ps1`, `sedan_ps1`), `f3/sedan_roda`,
  `f11/dentro_maos*`.

### 22/09/2026 - custo, cache e som

- `tests/medir_carroceria.gd` (nova): montar um carro custava 22 ms no quadro
  principal depois da lataria nova. Com o corte de estacoes pre-calculadas e o
  cache por modelo, 1,0 a 2,6 ms por carro (o primeiro de cada modelo, 33 a
  70 ms, sai no aquecimento). Triangulos por carro no MODERNO: 6.900 a 7.900
  (rodas 4.560 a 4.990, lataria 1.690 a 2.960).
- `tools/verificar_carro.py`: todos os criterios cumpridos com o som novo, o
  cambio novo e a lataria nova.
- Ninguem ouviu o som ainda; a bancada mede afinacao, fase, nivel e emenda,
  nao gosto.

### 22/09/2026 - rodada 2 (escolhas do usuario)

- Laco de audio: o `AudioDirector` terminava o laco em `data.size() / 2`, que
  so vale para PCM de 16 bits; os 12 `*_loop` sao QOA e tocavam 20% do arquivo
  (chuva, vento, igreja, lago, motor, pneu...). Agora pela duracao x taxa.
- `tests/bancada_dano.gd` (nova): 4 de 4. `tests/bancada_batida.gd` (existente,
  roda COM janela): 10 de 10 depois de a regua comparar vertice por superficie
  (o vidro virou superficie propria na F1 e a regua concatenada desalinhava).
- `tests/medir_carroceria.gd`: montar 1,4 a 3,4 ms por carro depois do cache;
  lataria de perto 2.500 a 4.400 triangulos com a grade conforme.
- Bateria: cambio 98/98, dirigir 36/36, som 55/55, carros_aaa 7/7 + A6, mola
  6/6, dano 4/4, batida 10/10, `verificar_carro.py` todos os criterios.
- Fotos: `captures/carros_aaa/f4/` (farol, lanterna, cidade acesa), `f7/`,
  `f8/` (trinca, amassado), `f9/sedan_longe`.

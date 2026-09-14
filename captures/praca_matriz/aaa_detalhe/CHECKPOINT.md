# Checkpoint — detalhamento da Praça da Matriz (igreja, casario, coreto)

Escopo: só `game/src/world/kit_parque.gd` e `game/src/world/parque_builder.gd`.
`abertura.gd` não foi tocado. O pin 270,-40 continua o mesmo.

## O que estava errado

Medido antes de mexer (`A0_eixo.png`, `A1_igreja_perto.png`, `A3_alto.png`,
`A4_casario.png`, pin 270,-40 fog=denso):

| Peça | Defeito |
|---|---|
| Igreja | Frontão em **degraus** (três caixas empilhadas) lia como zigurate. Telhado era caixa chapada: de cima, retângulo marrom sem caimento. Janelas altas liam como duas cunhas escuras sem moldura. Nave 10,4 × 4,6 m — proporção 0,44, achatada. |
| Sineira | 17,5 m por 2,7 de lado = **6,5:1**. Lia como chaminé, não como sineira. Telhado piramidal eram três caixas empilhadas. |
| Casario | Caixa com laje. Cinco casas de ~8 m plantadas a cada **4 m de passo**: atravessavam-se pela metade e as fachadas ficavam coplanares. |
| Coreto | Melhor das três. Guarda-corpo só com dois corrimãos, sem ripa; beiral sem caibro. |

## O que foi feito

**Helpers de telhado novos em `kit_parque.gd`** — não existia nenhum no repo;
o "gable" de `kit_estrada.casa_beira` também era caixa chapada.

- `agua_de_telhado()` — quadrilátero plano subdividido. **A regra de que a face
  aparece do lado oposto ao produto vetorial mora só aqui.** Quem chama informa
  para onde a água olha e a função acerta o giro. Caso degenerado (`c == d`) é a
  face triangular de uma pirâmide.
- `telhado_duas_aguas()` — cumeeira no Z local, águas caindo no X local.
  `beiral_ponta` separado do lateral: a igreja precisa dele em **zero**, senão a
  telha avança por cima do frontão e come a silhueta triangular.
- `oitao()` — o triangulo da ponta, no plano da parede.
- `telhado_piramide()` — n águas. Serve à sineira (4) e ao coreto (8).
- `QUAD_TELHA = 1.5` — com `vertex_lighting` uma água de 6 m em dois triângulos
  é atravessada pelo facho do poste sem acender.
- `TELHA_CLARA` / `TELHA_ESCURA` compartilhadas. Antes cada peça escolhia o
  próprio tom e o coreto saía laranja vivo ao lado de um casario marrom escuro.

**Igreja** — frontão é UM triângulo com a mesma altura `pico` da água (aresta é
função só da posição, então as duas superfícies concordam); cornija rampante;
pináculos nos ombros; óculo com moldura; duas janelas com moldura clara, verga e
peitoril; almofadas na folha da porta; manchas de reboco descascado; cornija em
volta; **sacristia** baixa à direita (sem ela o volume é prisma simétrico, e
prisma simétrico lê como caixa); campanário com vão em arco nas quatro faces,
aduela clara e sino; pirâmide de telha de verdade no topo.

**Casario** — `fileira_colonial()`: fileira germinada, módulos de 4,2 a 6,2 m
encostados, **um telhado corrido** do começo ao fim. Paredes-meia mascaradas
(`FACE_ESQ`/`FACE_DIR`) porque duas faces coplanares brigam por profundidade.
Pilastra entre módulos, saia de mofo, friso sob o beiral, tabica escura, porta
com ombreira clara e soleira de pedra, janela com peitoril. Quatro fileiras:
duas ladeando a praça (±14,5) e duas fechando o corredor sul (±10,0) — é a
planta da ref 02, o corredor estreito que abre na praça.

**Coreto** — telhado passou a usar `telhado_piramide`; 16 caibros aparentes sob
o beiral (a ref 03 vê o coreto por baixo, na lanterna); guarda-corpo com ripas
verticais de 9 cm e vão igual — ripa de 5 cm a doze metros não chega a um pixel
em 480×270 e o gradil inteiro cintila.

## Números

| | antes | depois |
|---|---|---|
| tris (25 chunks, pin) | 75 770 | 78 622 (+3,8 %) |
| `pior_ms` em regime | 6,1 | 6,1 |
| fps | 165 | 165 |

Topo do enquadramento no pin ≈ **9,3 m**. A ponta da cruz ficou em 9,20 (a
original era 8,98). Uma tentativa com nave de 6,6 m e pico 2,6 pôs a cruz em
10,4 e **estourou o topo do quadro** — ver `F1_pin_denso.png`. A proporção foi
ganha estreitando (10,4 → 9,8) em vez de subir.

## Capturas

| Arquivo | O quê |
|---|---|
| `A0_eixo.png` … `A4_casario.png` | estado ANTES |
| `F1_pin_denso.png` | a nave alta demais estourando o topo (não repetir) |
| `J1_pin.png` | pin canônico 270,-40 fog=denso — a foto que vale |
| `I2_praca.png` | praça inteira de z=-31, fog=leve |
| `K1_cine_acordar.png`, `K2_cine_take.png` | cutscene `--ver-praca` |
| `K3_coreto.png` | coreto |
| `L1_casario.png` | fileira colonial de perto |
| `M2_matdebug_alto.png` | de cima: cumeeira corrida, sem vazio |

## Duas armadilhas que custaram tempo

1. **`--mat-debug` não vale na praça.** É `EstradaBuilder._material()`, método
   daquele builder. Na praça devolve a cena normal e você acha que passou no
   teste. Para procurar buraco aqui, `--de-cima=` (ortogonal, força
   `fog_dia_sol` e luz zenital própria).
2. **A primeira execução depois de editar código não vale como captura.**
   `I1_pin_denso.png` saiu sem a igreja; a mesma linha de comando, repetida,
   virou `J1_pin.png` com a igreja no lugar. O streaming ainda estava montando
   no frame do `--shot-frame`.

---

# Rodada 2 - praca maior, coreto afastado, tensao

Pedido: mais cabanas brancas espalhadas, igreja maior e polida, coreto longe da
igreja, e "algo de terror e tenso".

## Planta num lugar so

`ParqueBuilder.planta_matriz(centro_q)` passou a ser a fonte unica: igreja,
coreto, fileiras, cabanas soltas e postes saem todos dela. Antes `_praca_matriz`
e `_mobiliario_praca_matriz` decidiam a mesma praca com numeros magicos
independentes e nunca se falavam - por isso um poste nascia DENTRO da parede de
uma casa, e por isso os dois lampioes da porta cairam em cima da escada da
igreja assim que ela cresceu. Agora mexer numa fileira move os postes junto.

| peca | antes | depois |
|---|---|---|
| igreja | C+(0,-5) | C+(0,-8) |
| coreto | C+(-8.5,+2) | C+(-9,+5.5) |
| distancia coreto-igreja | 11.0 m (beiral a 1.4 m da torre) | 16.2 m |
| fileiras de casario | 4 | 6 (as duas novas ladeiam a igreja ao norte) |
| cabanas soltas | 0 | 6, fora de esquadro |
| nave | 9.8 x 9.6 x 6.0 | 12.4 x 12.0 x 7.0 |
| sineira | 15.5 x 3.6 | 17.0 x 4.0 |
| sacristia | 4.4 x 6.2 x 3.4 | 5.0 x 7.4 x 4.0 |

## O teto do enquadramento

A camera travada do pin ve ate ~10.25 m no plano da fachada - medido pela altura
do apice do frontao que ainda aparece. Recuar a igreja 3 m pagou a nave mais
alta. Mesmo assim `pico` teve de cair para 2.2 e a cruz descer para caber: com
`pico` 2.45 e cruz alta a ponta saia do quadro (ver `O3_topo.png`).

Vale registrar: **o take da cutscene nao mostra o frontao**, nem antes nem
depois - a tarja corta na altura das janelas. Quem limita a altura da igreja e a
foto de camera travada, nao a cutscene.

## Tensao

Tudo ambiental, sem inventar enredo:

- Um lampiao `MORTA` e dois `SODIO_FALHANDO` no anel. O poste morto tambem apaga
  o globo (`poste_lanterna(..., aceso)`), senao ficaria vidro brilhando sobre um
  buraco de luz no chao.
- 40% dos modulos com vao pregado em X; 14% dos restantes com UMA janela acesa.
- Porta da igreja ENTREABERTA: folha direita girada 0.42 rad sobre a ombreira,
  com vao preto recuado 45 cm atras. Da paralaxe de verdade quando o jogador
  anda de lado.
- Cruz do frontao 7 graus fora de prumo.
- Cabanas soltas fora de esquadro.

## Duas medicoes que mudaram a decisao

1. **Tabua escura sobre vao escuro nao le.** A primeira versao usava marrom de
   madeira velha e o X sumia - so apareciam as pontas passando da moldura. Ficou
   madeira crua clara (`a08d6b`), 28 cm, e a moldura da janela escurece quando
   pregada. Comparar `T1_forcado.png` (escura) com `Y2_zoom.png` (clara).
2. **O retangulo palido nao era tabua, era janela ACESA.** Passei duas capturas
   procurando defeito no que era o recurso funcionando. Instrumentar
   `_modulo_colonial` com um print resolveu em uma rodada o que duas fotos nao
   resolveram: 4 de 23 modulos pregados com o limiar antigo.

## Numeros

| | base | rodada 1 | rodada 2 |
|---|---|---|---|
| tris | 75 770 | 78 622 | 85 198 (+12.4%) |
| `pior_ms` em regime | 6.1 | 6.1 | 4.5 |

## Capturas da rodada 2

`Z1_pin.png` pin canonico | `Z2_praca.png` praca de z=-28 |
`Z3_planta.png` planta de cima | `Z4_cine.png` take da cutscene |
`Y2_zoom.png` vao pregado (forcado, para julgar leitura)

---

# Rodada 3 - desgaste e o vao do beiral (2026-09-10)

Pedido: igreja e casebres com mais desgaste, e "quando se ve por tras da pra ver
atraves deles".

## O ver-atraves era o BEIRAL sem forro

As aguas de `agua_de_telhado` sao de face UNICA - a funcao orienta cada uma para
fora - e o beiral avanca `CASA_BEIRAL` = 0,55 m alem da parede. Debaixo desse
balanco nao existia superficie nenhuma. Quem olhasse a casa de tras, com a lente
abaixo da linha do beiral, via o telhado pelo lado de dentro: na tela isso le
como uma fresta aberta entre a parede e o telhado, e o telhado vira uma ripa
flutuando.

Conserto no helper `telhado_duas_aguas`, entao igreja, casario e cabanas soltas
ganharam de uma vez: uma placa horizontal no nivel do beiral, cobrindo
`largura + 2*beiral` por `comprimento + 2*beiral_ponta`. De quebra da espessura
a borda - telha sem espessura le como papel recortado.

Prova: `captures/praca_matriz/tras/Z_antes_depois_beiral.png`, mesmo
enquadramento antes e depois (as duas clareadas 3x SO para ver geometria, nunca
para julgar cor).

O coreto e a sineira nao precisaram: os dois ja tinham forro proprio por baixo
(o coreto tem forro + 16 caibros; a piramide da torre e mais estreita que a
cornija em que se apoia).

## Fundos: eram laje branca lisa

Ninguem projeta cena para o fundo da casa, mas o jogador anda por tras dela, e
ali a fileira inteira era reboco novo sem uma marca. Agora cada modulo leva no
fundo: saia de mofo mais forte que a da frente, 3 a 5 manchas de reboco caido,
uma janelinha alta de servico com peitoril e escorrido, e o tubo de descida na
quina com a mancha que ele deixa.

## Desgaste

Dois helpers novos em `kit_parque.gd`:

- `descascado()` - manchas de tijolo aparente. **Dois blocos deslocados em L, e
  nao um retangulo.** A primeira versao usava um retangulo so e na captura lia
  como CARTAZ colado na parede; e a silhueta que diz se aquilo e reboco que caiu
  ou papel que alguem pregou. Faixa minima 0,55 m: a 480x270 mancha de 30 cm nao
  chega a tres pixels e vira o mesmo chiado do dither.
- `escorrido()` - a lingua escura que desce de peitoril e de vao. E a unica
  feicao FINA que sobrevive nessa resolucao, porque o olho a le como direcao e
  nao como forma.

A igreja trocou o laco proprio de manchas (que punha um retangulo por mancha)
por `descascado`, e ganhou desgaste tambem nos dois flancos da nave - o lado que
a chuva bate e ninguem cuida.

## Numeros

| | antes desta rodada | depois |
|---|---|---|
| tris | 162 914 | 167 198 (+2,6%) |
| `pior_ms` | 11,9 | 12,2 |
| chunks | 49 | 49 |

**Atencao ao baseline:** na rodada 2 eram 85 198 tris em 25 chunks. A diferenca
nao e minha - outra sessao abriu a nevoa dos presets e o streaming passou a
carregar 49 chunks. Comparar com a rodada 2 nao vale.

## Limpeza

Removidos os `print("[DBG osso] ...")` que ficaram em `abertura.gd` na rodada
anterior.

---

# Rodada 4 - o vazio em volta, e um erro de metodo meu (2026-09-10)

## Primeiro: a medicao que eu vinha fazendo estava na cena errada

`praca_noite` so e forcado quando o argumento comeca literalmente com
`--ir-para=270` ou e `--ver-praca` (`cidade.gd:_forcar_fog_praca_se_pin`).
Medicoes feitas com `--ir-para=271,...` rodam sob `fog_leve`, nao sob o preset
da praca. Eu media o chao assim e concluia "virou um vazio preto" - e cheguei a
mexer em `ambient_energy` e na energia do lampiao por causa disso.

Sob o preset REAL:

| regiao | medido | alvo ref |
|---|---|---|
| chao (takes 1, 2, 4) | 21,7 a 23,0 | 16,3 longe / 25,3 sob poste |
| fachada da igreja | 89,6 | 90,9 |

Esta certo. **A luz nao foi tocada nesta rodada** - o ajuste que eu ia fazer
teria quebrado o que ja estava no alvo. O sintoma que denunciou foi o de sempre:
cortei 38% da energia do lampiao e a poca andou 3%. Numero que nao se move e
botao errado.

## O vazio em volta - a observacao do usuario

Eu vinha refinando a praca pelo quadro da cutscene, que olha a igreja de frente.
A planta de cima (`F_planta_larga.png`) mostra o que aquele quadro nunca
enquadra: do fundo da igreja ate a rua havia calcamento nu por uma area maior
que a praca inteira. Cenario que so fecha de um angulo e decoracao de palco, e
esta praca e o hub - o jogador anda por tras.

- **`campo_santo()`** - cemiterio murado atras da matriz (26x15 m), com portao,
  cruzeiro central e sepulturas em grade irregular (cruz / tumulo de caixa /
  vazio). E a disposicao colonial correta e resolve o vazio com o assunto que a
  cena ja tem. De longe le pelo cruzeiro aparecendo por cima do muro.
- **`adro()`** - muro baixo com portao no eixo da porta da igreja, mais tres
  cruzes de pedra a oeste. Poe uma camada intermediaria: a igreja passa a estar
  ATRAS de alguma coisa.
- **Oito arvores** escolhidas nas bordas, nao o espalhamento generico (que na
  praca entra em 0,35 de proposito).

O cemiterio e medido contra a `area` da quadra, nao contra numeros soltos:
quadra pequena encolhe o campo santo em vez de joga-lo na rua.

## `descascado` com clamp

Apareceram manchas de reboco SOLTAS NO AR, uma metade dentro e metade fora de
uma empena (`O_zoom_flutuante.png`). O sorteio ia ate 0,42 da largura contando
que quem chamasse passasse a extensao certa da parede. Agora a mancha inteira -
os dois blocos e a borda - cabe dentro de `largura` x `altura` por construcao, e
nenhum chamador consegue empurra-la para fora. Ver
[[consertar-o-mundo-em-vez-de-contornar]].

## Numeros

| | antes | depois |
|---|---|---|
| tris | 167 198 | 170 086 (+1,7%) |
| chunks | 49 | 49 |

`pior_ms` variou de 5,0 a 17,5 entre amostras no mesmo pin; nao isolei a causa e
nao vou afirmar regressao com base nisso.

## Armadilha de captura desta rodada

Duas execucoes com a MESMA linha de comando deram quadros com conteudo
diferente (`N_santo_lado` x `P_sem_laterais`), o que invalidou um teste de
A/B que eu tinha montado. Vale para o proximo: comparacao antes/depois so vale
com os dois quadros conferidos, nao so com o comando conferido.

---

# Rodada 5 - porta da igreja piscando e vazando (2026-09-10)

## A causa, por aritmetica

Medindo tudo a partir de F = face frontal da nave (`fundura * 0.5`):

    placa clara      centro F+0,06  esp. 0,12  ->  face frontal em F+0,12
    folha da porta   centro F+0,05  esp. 0,14  ->  face frontal em F+0,12

Duas superficies olhando para FORA, no mesmo plano exato. Empate de
profundidade: as duas disputam o pixel e a porta PISCA. Quando a placa ganha o
teste, aparece reboco claro no lugar da porta - que e o "ver atraves".

Terceiro defeito no mesmo bloco: o vao preto estava em `porta_c - frente * 0.45`,
ou seja **enterrado dentro da nave**, que e um volume solido. Nunca foi visto por
ninguem, e a porta nao tinha profundidade nenhuma.

## O conserto

A placa clara deixou de ser uma laje unica cobrindo a fachada inteira e passou a
ser **dois montantes e uma verga**, com vao de verdade para a porta. Isso mata a
coplanaridade E da ao portal o recuo que ele nunca teve. Todas as bordas do vao
saem da MESMA conta (`vao_meia`, `vao_topo`), senao os tres pedacos discordam
sobre onde o vao esta.

Tabela de profundidades, agora escalonada e escrita no codigo:

    vao preto        F+0,00 .. F+0,05
    folhas           F+0,05 .. F+0,19
    almofadas        F+0,19 .. F+0,24
    placa clara      F+0,00 .. F+0,26   (partida)
    marco de pedra   F+0,00 .. F+0,34   (unica peca que avanca)

A porta fica recuada 7 cm atras da placa, dentro de um marco que avanca 8 cm.

## Bug latente consertado de passagem

O arco em degraus usava `porta_c + Vector3(0.0, y, 0.02)` - aquele 0,02 e um
passo no Z do MUNDO, que so calha de ser a profundidade da fachada enquanto
`giro` for zero. Uma igreja girada empurraria os degraus para o lado em vez de
para a frente. Passou a sair de `frente`.

## Medido depois

| | valor |
|---|---|
| vao da porta | luma 3,3 (preto, opaco) |
| reboco limpo da fachada | luma 103-105 (ref 90,9) |
| tris | 170 086 -> 170 118 (+32) |
| `pior_ms` | 4,2 |

## Armadilha de captura, de novo

Comparei "antes" e "depois" e os quadros nao batiam. Rodei o mesmo comando tres
vezes com `--stats`: posicao, olhar e tris **identicos** nas tres. A camera nao
varia. O que eu tomava por porta na segunda captura era um PILAR DO PORTAO DO
ADRO a 2,85 m da lente - o adro entrou na rodada 4 e eu escolhi um pin que
ficava do lado de fora dele. Licao: quando dois quadros do mesmo comando
divergem, o suspeito e o que entrou entre eles no CENARIO, nao a captura.

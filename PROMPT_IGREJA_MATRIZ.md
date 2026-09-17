# TASK — A Capela Azul e o Cruzeiro da Praça da Matriz

Sessão **só da Praça da Matriz** — a quadra `x 7..10 / z -3..0`, e mais nada.
Não mexa em mercado, bar, casa da fumaça, estufa, estrada velha, carroceria,
criação de personagem nem nas fachadas genéricas da cidade. Outras sessões estão
nesses arquivos.

Jogo: Godot 4.7.2 Compatibility, 480×270, PSX. Branch `playable`. Código em
português, `class_name`, tipado, constante no topo com o **porquê** escrito.
Godot: `.tools/Godot_v4.7.2-stable_win64_console.exe --path game`.

> **Só o exterior.** O interior da igreja não entra nesta task. A porta fica
> entreaberta com luz de vela vazando, e é só isso que o jogador vê de dentro.

---

## 0. A medida de onde se parte

Medido nesta sessão, não herdado de documento:

| Coisa | Valor | Como foi medido |
|---|---|---|
| Quadra da praça | chunks `x 7..10`, `z -3..0` — 3×3, 96 m | `MalhaUrbana.quadra_de(8,-2)` |
| Área útil | **79,8 × 83,8 m**, mundo `x 231,0..310,8` / `z -93,0..-9,2` | `ParqueBuilder.planta` |
| Centro da quadra | **(270,9, −51,1)** | idem |
| Igreja (âncora) | **(270,9, −59,1)** | `planta_matriz` |
| Coreto | (261,9, −45,6) | idem |
| Pin do acordar | (270, −40) | `abertura.gd` |
| Miolo hoje ocupado | ~55 × 55 m | vista de cima |

**O problema em uma frase:** a praça tem 80 × 84 m e o cenário composto ocupa
55 × 55. O resto é calçamento nu. A praça não é pequena — ela está vazia.

### Fotometria — e a régua que foi preciso construir antes

**`--ir-para` não serve de régua, e isto custou três medidas erradas.**

O jogador continua sendo um `CharacterBody3D` vivo depois do teleporte. No frame
200 um pedestre já encostou nele, e a recuperação de penetração do motor empurra
os **dois** — o mesmo defeito que está escrito em `pedestre.gd` (`ESPACO_PESSOAL`),
e que já tinha tirado o jogador onze metros do lugar na saída de um interior.
Duas execuções da **mesma linha de comando** devolveram enquadramentos
diferentes: uma a fachada de frente, outra o casario da rua. Amostra de pixel
tirada sobre a segunda mede uma parede qualquer achando que mede a igreja.

Isso produziu, em sequência, **três conclusões falsas** que quase viraram
trabalho:

1. *"a fachada está em luma 9 de 255, a igreja não chega na imagem"* — não está;
2. *"aumentar a energia do lampião dez vezes não move nada"* — move, a foto é que
   era de outro lugar;
3. *"há mais omnis que o renderizador aceita por objeto e as lanternas da porta
   estão sendo descartadas"* — não há. Medido depois com régua fixa:
   `max_lights_per_object` em 24 e em 64 dá **o mesmo pixel**, dígito por dígito.

A régua é `--olhar-igreja[=dist]`, em `cidade.gd`: câmera própria, jogador fora
da física, **sem tocar em névoa e sem acrescentar luz nenhuma**. É o oposto do
`--de-cima`, que força `fog_dia_sol` e acende um sol próprio — aquele serve para
procurar buraco, este para medir luz.

```
.tools/Godot_v4.7.2-stable_win64_console.exe --path game -- \
  --pular-menu --pular-abertura --nome-teste=Zeca \
  --olhar-igreja --shot="<abs>.png" --shot-frame=220 --shot-quit
```

Lente em (270,9 · 1,62 · −40,0), 13,1 m da fachada, FOV 70. Rodar duas vezes e
usar a segunda.

### O que a régua mede hoje

| Região | Medido | Alvo `01_acordar.png` | Leitura |
|---|---|---|---|
| céu | (61,6 / 63,1 / 60,4) | (37, 41, 41) | claro demais |
| frontão | luma 118 | ~70 | claro |
| fachada da nave | (185,5 / 170,5 / 144,3) — **luma 172** | (94, 92, 76) | **2× claro** |
| porta | luma 65 | — | ok |
| lanterna | luma 149 | (190,173,97) no halo | ok |
| calçamento | (16,1 / 16,1 / 13,4) — **luma 16** | (33, 25, 13) | **escuro** |
| muro do adro | luma 67 | — | ok |
| telha | (11,1 / 5,6 / 3,3) — **luma 6,6** | — | **quase preto** |

**A fachada não está invisível — está gritando.** Parede a 172 contra calçamento
a 16 é razão **10,8 : 1**; a referência mede perto de 5,6 : 1. É a leitura de
holofote que o DIRECAO_PRACA já tinha nomeado ("a luz de poste é halo, não
holofote"), agora vinda do outro lado: o chão desceu junto com a pedra e a
parede ficou onde estava.

E a **telha em luma 6,6 é preta**. Na print 01 o telhado alaranjado é uma das
três massas de cor da imagem; aqui ele não existe. De frente quase não aparece
(o que se vê é o frontão), mas de qualquer outro ângulo da praça é metade do
edifício.

> **Isto NÃO é bloqueio, e não é desta task.** A fachada tem 172 de brilho: o
> azul, a sacada e o balaústre nascem perfeitamente visíveis. A gradação da
> praça é do Cine2 / DIRECAO_PRACA. **Registrado aqui como achado medido, com a
> régua para reproduzir — não mexa nela dentro desta task sem combinar.**

---

## ESTADO — o que já está no código

Feito e capturado nesta sessão (arquivos: `kit_parque.gd`, `parque_builder.gd`,
`chunk_manager.gd`, `lampada.gd`, `cidade.gd`, `morador_praca.gd`,
`tools/gerar_audio.py`):

| § | Coisa | Estado |
|---|---|---|
| 0 | Régua `--olhar-igreja[=dist]` | **feito** — é a única medida confiável daqui |
| 2.1 | Paleta azul medida contra a luz quente | **feito** |
| 2.2 | Cunhais azuis na fachada | **feito** |
| 2.3 | Cornija azul + remate branco | **feito** |
| 2.4 | As duas sacadas com balaustrada de 7 balaústres | **feito** |
| 2.5 | Porta azul entreaberta, com fresta acesa | **feito** |
| 2.6 | Janela do frontão | **feito** |
| 2.7 | Sineira recuada ao canto traseiro oeste | **feito** — ver a ressalva abaixo |
| 2.8 | Cachorros do beiral | **feito** |
| 2.9 | Descascado: 2 na fachada, 4 nas laterais | **feito** |
| 2.10 | Sacristia com porta e janela azuis | **feito** |
| 3 | Cruzeiro com os Instrumentos da Paixão | **feito** |
| 4 | `Lampada.Padrao.VELA` + três velas na capela | **feito** |
| 5.1 | Adro em +4,0, terreiro gramado, caminho de placas | **feito** |
| 5.2 | Guarda-corpo rústico e canteiros | **feito** |
| 5.3 | Seis fileiras e seis cabanas novas | **feito (quantidade)** |
| 7.1 | `igreja_loop` (harmônio) e `sino_igreja`, sintetizados | **feito** — o sino ainda não toca |
| 7.2 | Quatro pessoas circulando | **feito** |
| 7.3 | `MoradorPraca`: três moradores entram e saem de casa | **feito** |

Falta, e está especificado abaixo:

- **§5.3 polimento do casario** — alpendre, cachorros, chaminé, postigo azul,
  banco na fachada, vaso na soleira. Só a QUANTIDADE foi feita.
- **§7.1 o sino tocando na hora cheia.** O `.wav` existe e está importado;
  falta quem o dispare, lendo `Relogio`. `som_ambiente` só toca em loop.
- **Velas nos pilares do portão do adro** (§4, duas últimas linhas da tabela).

### Duas ressalvas medidas, que não são regressão

1. **A sineira não aparece de frente, e já não aparecia antes.** Foi medido
   perfil de luma na linha do céu onde ela deveria estar, ANTES e DEPOIS de
   recuá-la: as duas curvas são o mesmo gradiente de névoa, sem degrau. A
   névoa da praça come uma torre branca a 19 m, e comia também quando ela
   estava colada na fachada. O comentário no código que promete "espiar por
   cima da névoa" descreve uma intenção, não o que acontece. **Se quiser a
   torre de volta na silhueta, o caminho é luz no campanário, não posição** —
   um vão aceso atravessa névoa, alvenaria branca não.

2. **A tabela de fotometria do §0 não é comparável depois desta sessão.** Ela
   amostra retângulos de pixel fixos, e a geometria da fachada mudou: os mesmos
   retângulos agora caem sobre outras peças. Para comparar de novo, refaça os
   retângulos contra a imagem atual antes de tirar qualquer conclusão — foi
   exatamente assim que nasceram as três conclusões falsas descritas no §0.

---

## 1. A referência, mapeada foto a foto

Três prints. Guardar em `PRINTS/ref_igreja_azul/` com estes nomes:

| Arquivo | O que é | Para que serve |
|---|---|---|
| `01_capela_frontal.png` | A capela de frente, de dia, com gramado | **A fachada.** É desta que sai cada cota do §2 |
| `02_cruzeiro_historico.png` | Foto antiga colorizada: o cruzeiro e a multidão | Prova que o cruzeiro **domina** a praça, não decora |
| `03_cruzeiro_hoje.png` | O cruzeiro no pedestal, guarda-corpo, capela ao fundo | **A principal.** O cruzeiro, o piso e o guarda-corpo saem daqui |

### 1.1 Print 01 — a capela

Capela colonial mineira, **branca com aplicação azul-celeste**. O azul é o
assunto inteiro da fachada: é ele que diz onde está cada coisa.

Leva azul, e nada mais leva:

- **Cunhais** — as duas faixas largas nos cantos da fachada, do embasamento até
  a cornija. Largas mesmo: quase um metro.
- **Cornija** — a faixa horizontal contínua sob o beiral, dando a volta.
- **Porta** — folha dupla com almofadas, mais a moldura em volta.
- **Duas sacadas** — laje saliente + balaustrada de balaústres torneados, uma de
  cada lado do eixo, no pavimento de cima. **É a assinatura da capela.** Sem as
  sacadas a fachada é uma parede branca com uma porta.
- **Molduras das duas janelas de sacada.**
- **Janelinha do frontão** — o vão pequeno no triângulo, entre as duas sacadas.

Resto: parede caiada branca, telhado de duas águas em telha cerâmica alaranjada,
beiral avançado com **cachorros** (as pontas de caibro aparecendo por baixo),
cruz fina de metal no cume do frontão.

Ao redor: **gramado na frente**, caminho de concreto até a porta, anexo baixo à
direita (branco, telha, porta e janela azuis), muro branco baixo, poste de luz
com fios, palmeiras e mata atrás.

**A capela NÃO tem torre na frente.** Decidido com o usuário: a fachada da praça
passa a ser a da print, e a sineira recua para trás da nave — disposição real de
capela mineira. Ver §2.7.

### 1.2 Print 02 — o cruzeiro histórico

Capela ainda sem pintura, e na frente dela o cruzeiro com a multidão. O cruzeiro
**parece maior que a capela** porque está mais perto. É esta a leitura a
reproduzir: quem chega na praça encontra o cruzeiro primeiro e a igreja depois.

### 1.3 Print 03 — o cruzeiro hoje (a principal)

Mastro roliço escuro sobre **pedestal de alvenaria em degraus**, e pendurados
nele os **Instrumentos da Paixão** (Arma Christi), em metal claro:

```
                    ✦  remate
                    †  cruzinha
      ⚒ ╲        ╱    martelo e torquês cruzados em X
         ╲      ╱   ▤ escada encostada na diagonal
    ═══════╤══════   travessa
        [ INRI ]
      ╲    ○    ╱    coroa (círculo)
       ╲   │   ╱     lança e vara com esponja
        ╲__│__╱      meia-lua
           │
           │  mastro
        ▄▄▄█▄▄▄
      ▄▄▄▄▄█▄▄▄▄▄    pedestal em 3 degraus
    ▄▄▄▄▄▄▄█▄▄▄▄▄▄▄
```

No chão em volta: **placas de concreto** com junta aparente, **guarda-corpo
rústico de madeira** (montantes + duas travessas horizontais) cercando
**canteiros** de terra com arbustos e murete baixo. Casinha alaranjada à
esquerda. Capela azul-e-branca ao fundo, à direita.

---

## 2. A capela — `KitParque.igreja_matriz` reescrita

Ancorada em (270,9, −59,1), `giro = 0`, fachada olhando **+Z (sul)**.

**A massa não muda.** `largura 12,4 · fundura 12,0 · parede_h 7,0 · pico 2,2 ·
PLINTO 0,55` estão aferidos contra o enquadramento do pin (a câmera travada vê
até ~10,25 m no plano da fachada) e contra o CHECKPOINT em
`captures/praca_matriz/aaa_detalhe`. Mexer na massa refaz esse ajuste inteiro.
**O que muda é a superfície.**

### 2.1 A paleta

```gdscript
## Azul da capela. NAO e o azul da foto.
##
## O da print mede perto de #4FA8D8 sob sol de meio-dia. Aqui a cena e
## 23:15 com nevoa densa e `vertex_lighting`: a cor MULTIPLICA a textura
## `reboco` (luma 210) e depois apanha luz de omni a 6,0 de energia. Com o
## azul da foto o cunhal chega a luma 21 e le como sombra na parede branca,
## que e o mesmo que nao existir.
##
## Dois passos acima na claridade e um abaixo na saturacao. O olho continua
## lendo "azul de capela"; o dither de 15 bits continua tendo o que
## quantizar. Ver a licao `luz-colorida-nao-vence-albedo`: quem pinta de
## frio aqui e o ALBEDO, nao o facho.
const AZUL := Color("6fc2e8")
const AZUL_FUNDO := Color("4d9cc4")   ## almofada da porta, recuo da sacada
const AZUL_SOMBRA := Color("35708f")  ## sotoposto, sob a laje da sacada
```

Branco: manter `reboco "fff6e6"` / `reboco_claro "fff8ea"`.
Telha: manter `TELHA_CLARA` / `TELHA_ESCURA` — igreja, coreto e casario são o
mesmo barro, e isso não se negocia.

### 2.2 Cunhais azuis (substituem os quoins de tijolo da fachada)

Duas faixas, `0,90 × 6,60 × 0,16`, nos cantos da fachada, de `y = 0,20` até a
cornija. Peça **inteira**, não empilhada em blocos alternados: o quoin de tijolo
em xadrez é vocabulário de matriz de pedra; a capela da print tem pilastra
chapada.

Os quoins de tijolo das **laterais** ficam. É a lateral que a chuva bate.

### 2.3 Cornija azul

`largura + 0,40 · altura 0,42 · avanço 0,20`, centrada em `y = parede_h − 0,38`,
dando a volta nos quatro lados. A cornija branca de hoje (`parede_h − 0,16`,
0,34 de altura) vira a **base** dela, meio tom mais clara — a print mostra duas
faixas, a azul e uma branca fina por cima.

### 2.4 As sacadas — a peça que a capela não tem hoje

Duas, centro em `lado * ±3,10`, ou seja nos quartos da fachada.

| Parte | Tamanho (m) | Posição |
|---|---|---|
| Vão escuro | 1,30 × 2,10 × 0,06 | `y = 5,20`, em F+0,04 |
| Moldura azul | 1,74 × 2,54 × 0,10 | `y = 5,20`, em F+0,02 |
| Bandeira (verga) | 1,74 × 0,22 × 0,14 | topo da moldura |
| Laje da sacada | 2,00 × 0,16 × 0,58 | `y = 4,05`, saindo F+0,29 |
| Mãos (3 cachorros) | 0,14 × 0,30 × 0,42 | sob a laje, `x = 0, ±0,72` |
| Guarda-mão inferior | 2,00 × 0,12 × 0,12 | `y = 4,25` |
| **7 balaústres** | 0,11 × 0,62 × 0,11 | `y = 4,62`, passo 0,29 |
| Montante de ponta (2) | 0,17 × 0,86 × 0,17 | `x = ±0,95` |
| Corrimão | 2,06 × 0,15 × 0,15 | `y = 5,01` |

**Por que balaústre modelado sobrevive aqui e não sobreviveria em outro lugar.**
A conta: FOV 70, 480 px, distância do pin ao plano da fachada 13,1 m. A largura
do frustum ali é `2 · 13,1 · tan(35°) = 18,3 m`, logo **26 px/m**. Um balaústre
de 0,11 m dá 2,9 px, com 2,9 px de vão entre vizinhos. É a menor feição do jogo
que ainda conta como ritmo em vez de chiado — e ela só passa porque a sacada
está perto e é clara sobre escuro. **Não copie esta cota para nada que fique
além de 15 m.** Ver a lição dos 480×270 no §8.

Sete balaústres, e não nove: com nove o vão cai para 2,1 px e o dither come.

Atrás do vão, **luz de vela**. Ver §4.

### 2.5 Porta azul

Mantida a estrutura de hoje — e ela é boa, não reescreva:

- placa clara **partida em três** (dois montantes + verga), com o vão reservado;
- vão preto encostado na face da nave;
- folha da direita **entreaberta** em 0,42 rad, dobradiça na ombreira;
- tabela de profundidades documentada no arquivo.

O que muda: `porta` de `#0c100c` para **`AZUL`**, almofadas para `AZUL_FUNDO`,
marco de pedra continua pedra (a print mostra cantaria clara em volta do azul).

A porta entreaberta agora **vaza luz de vela**. É o melhor plano da praça: uma
igreja aberta às 23:15, com vela acesa lá dentro e ninguém à vista.

### 2.6 Janela do frontão (substitui o óculo)

O óculo girado a 45° é vocabulário de matriz grande. A print tem um vão
retangular pequeno com moldura azul, no eixo:

- moldura azul `0,96 × 1,12 × 0,08` em `y = beiral + 0,72`;
- vão escuro `0,62 × 0,78 × 0,06`;
- peitoril claro `1,06 × 0,12 × 0,16`.

### 2.7 Sineira recuada

Sai de `lado·−(largura·0,48 + 1,15) − frente·0,35` (colada na fachada) e vai
para o **canto traseiro oeste**:

```gdscript
var torre := centro - frente * (fundura * 0.5 - 1.6) - lado * (largura * 0.5 + 0.6)
```

Altura **17,0** e lado **4,0**, sem mudança — é ela que espia por cima da névoa,
e é isso que o TAKE 5 da abertura precisa.

Da praça, a nave tem 9,75 m e a torre 17,0: sobram **7,25 m de torre acima da
cumeeira**, deslocados do eixo. A fachada fica igual à print e a silhueta
continua tendo duas alturas. Ganha cunhais azuis e aduelas azuis nos arcos do
campanário, senão ela lê como outro prédio.

**Verificar no TAKE 5 antes de dar por pronto.** A câmera é
`c5 = (torso.x − 1,6 , y + 1,30 , torso.z + 5,0)` ≈ (268,4 , −35,0), lente 58,
olhando a igreja. A torre tem de entrar no quadro. Se não entrar, o recuo foi
longe demais — recue menos, não desfaça.

### 2.8 Cachorros do beiral

Pontas de caibro escuras sob o beiral **das duas laterais**, `0,14 × 0,16 ×
0,40`, passo 1,2 m, madeira `#3a2c1e`. Na fachada **não** — `beiral_ponta` é
zero ali de propósito, o frontão sobe acima da telha.

### 2.9 Descascado — menos na frente, igual atrás

A print mostra capela **cuidada**. Hoje a fachada leva `descascado(..., 5, ...)`,
cinco manchas. Cai para **2**. As laterais e o fundo mantêm 4 e 3.

Não é contradição com o horror: uma igreja bem pintada numa cidade largada é
mais incômoda que uma igreja em ruína. A ruína explica; o cuidado não explica.

### 2.10 Anexo à direita (sacristia)

Mantido onde está. Ganha da print: **porta azul** virada para a praça
(`0,95 × 2,15`, moldura azul) e moldura azul na janelinha. É o que faz o anexo
ler como parte da mesma capela e não como puxadinho.

---

## 3. O cruzeiro — `KitParque.cruzeiro`, peça nova

Substitui as **três `cruz_de_pedra`** de hoje. Uma vertical forte vale mais que
três fracas, e é o que as prints mostram.

**Posição:** local `(−7,6 , +2,8)` a partir do centro da quadra — mundo
≈ **(263,3 , −48,3)**. Ou seja: a **oeste** do eixo e ao **sul** do muro do adro,
já no calçamento da praça. Do pin fica a 8,7 m, em cima e à esquerda: primeiro
plano vertical para o quadro do acordar, e o enquadramento da print 01 (cruzeiro
à esquerda, capela à direita) visto de quem entra pela avenida.

**Cotas.** Tudo caixa; nada roliço.

| # | Peça | Tamanho (m) | Centro em y | Cor |
|---|---|---|---|---|
| 1 | Degrau 1 | 2,40 × 0,24 × 2,40 | 0,12 | `#a8a49a` |
| 2 | Degrau 2 | 1,95 × 0,24 × 1,95 | 0,36 | `#b0aca2` |
| 3 | Degrau 3 | 1,50 × 0,24 × 1,50 | 0,60 | `#a8a49a` |
| 4 | Dado | 1,10 × 0,55 × 1,10 | 1,00 | `#9a968c` |
| 5 | Mastro | 0,24 × 5,60 × 0,24 | 4,08 | `#4a3a28` |
| 6 | Travessa | 2,55 × 0,22 × 0,22 | 5,35 | `#4a3a28` |
| 7 | INRI | 0,72 × 0,26 × 0,05 | 5,62 | `#cdc4ad` |
| 8 | Cruzinha do topo | 0,55 × 0,12 / 0,12 × 0,42 | 6,55 | metal claro |
| 9 | Remate | 0,16 × 0,26 × 0,16 | 6,92 | metal claro |
| 10 | Escada: 2 longarinas | 0,09 × 2,90 × 0,09 | inclinada ~18° | metal claro |
| 11 | Escada: 5 degraus | 0,44 × 0,09 × 0,07 | passo 0,55 | metal claro |
| 12 | Lança | 0,08 × 2,60 × 0,08 + ponta 0,20 × 0,34 | diagonal | metal claro |
| 13 | Vara + esponja | 0,08 × 2,40 × 0,08 + cubo 0,26 | diagonal | metal claro |
| 14 | Martelo | cabo 0,07 × 0,85 + cabeça 0,28 × 0,16 | X superior | metal claro |
| 15 | Torquês | 2 barras 0,07 × 0,75 cruzadas | X superior | metal claro |
| 16 | Meia-lua | 2 barras 0,12 × 1,45 em V + fecho 0,55 × 0,12 | 4,30 | metal claro |
| 17 | Coroa | 8 barras 0,10 × 0,42, octógono de raio 0,52 | 3,40 | metal claro |

**O metal é CLARO, `#b9b2a0`, e isso não é gosto.** A lição já está escrita em
`_tabuas_cruzadas`: madeira/metal escuro sobre céu escuro não tem contraste com
nada, e a peça inteira vira dois riscos de dither. Ferro velho galvanizado pega
o lampião e lê como traço claro contra o preto — que é como a coisa se vê de
verdade e como Silent Hill desenha.

**Espessura mínima 0,07 m.** A 8,7 m do pin dá 39 px/m, ou seja 2,7 px. Abaixo
disso o instrumento some e sobra um mastro pelado.

Orçamento: ~35 caixas, ≈ 420 triângulos. Cabe — é o marco da praça.

Colisão: uma caixa no pedestal (2,4 × 0,84 × 2,4) e uma fina no mastro.

---

## 4. Luz de vela

`Lampada.Padrao` tem `ESTAVEL`, `SODIO_FALHANDO`, `FLUORESCENTE`, `MORTA`.
Nenhum é vela. **Acrescentar `VELA`**: ondulação lenta e irregular entre 0,72 e
1,0, com uma queda mais funda a cada 6–14 s, sem nunca apagar. Fluorescente é
rajada rápida; vela é respiração.

Onde acende, e com que número:

| Lugar | Cor | Energia | Alcance | Padrão |
|---|---|---|---|---|
| Vão da porta entreaberta | `#ffb46a` | 3,4 | 7,0 | `VELA` |
| Atrás de cada sacada (2) | `#ffc07a` | 2,2 | 5,5 | `VELA` |
| Nicho do muro do adro (2) | `#ffb46a` | 1,4 | 3,6 | `VELA` |

Todas **sem facho** (`facho: false`): cone visível dentro de vão estreito vira
bloom branco e come a ombreira — já aconteceu com as lanternas da porta.

Atrás de cada vão, painel `janela_acesa` (que tem emissão própria no material) em
`#ffcf94`, para o vão ter brilho mesmo quando a omni está no vale da ondulação.

As **duas lanternas da porta** continuam `ESTAVEL` e continuam sem falhar — são
elas que mantêm a fachada legível, e isso já está escrito no código.

---

## 5. A praça: ocupar os 80 × 84 que já existem

Decidido com o usuário: **não** mexer na malha da cidade. Nada de apagar linha de
rua. A praça cresce ocupando a própria quadra.

### 5.1 O adro avança e ganha grama

Muro do adro: de `z = centro + 1,4` para **`centro + 4,0`**, largura de 19,0 para
**21,0**.

**Conferido contra as duas câmeras que não são minhas:**

- Do **pin** (z = −40): o muro fica a 7,1 m. Topo a 0,9 m, olho a 1,6 m — a
  linha de visão passa por 0,31 m no plano da fachada, e a porta começa em 0,55.
  A porta continua inteira no quadro e o muro continua cruzando o terço inferior,
  que é a razão de ele existir.
- Do **TAKE 5** (c5 ≈ z −35): o muro fica a 12,1 m, ainda na frente da câmera.
  A camada intermediária do plano da revelação está preservada.

Dentro do adro, o chão vira **grama** (`&"grama"`, `Y_GRAMA`), em quatro faixas
em volta da pegada da igreja — mesmo recorte que `_grama_de` usa no lago, e pelo
mesmo motivo: um plano único passaria por baixo do embasamento e apareceria como
tapete verde dois centímetros acima dele.

Do portão até o primeiro degrau, **caminho de placas de concreto**, 2,2 m de
largura, placa de 1,1 m com junta e desnível de 1 cm entre vizinhas — mesmo
tratamento do calçamento, que é o que impede a superfície grande e chapada.

Isto é a print 01 inteira: gramado na frente, caminho de concreto até a porta.

### 5.2 Guarda-corpo rústico e canteiros (print 03)

Peça nova `KitParque.guarda_corpo_rustico(de, ate)`: montantes `0,12 × 0,95` a
cada 1,8 m, duas travessas horizontais `0,10 × 0,08`, madeira `#6b5539`.

Onde: contornando o **canteiro do cruzeiro** (retângulo 7,5 × 5,0 em volta dele,
com dois vãos de passagem) e mais dois canteiros simétricos no eixo sul. Dentro,
terra (`&"terra"`, `Y_TERRA`), murete de alvenaria `0,25 × 0,22` na borda e
arbustos (`KitParque.arbusto`) — o que a print mostra.

### 5.3 Mais casebres, e melhores

Hoje: 6 fileiras + 6 casas soltas, tudo dentro de ±27 m.

**Quantidade.** Acrescentar, para fechar o perímetro até a borda real:

```gdscript
# fileiras novas
{"de": (-24.0, -26.0), "ate": (-24.0, -14.0), "giro":  PI*0.5, "s": 331},
{"de": ( 24.0, -26.0), "ate": ( 24.0, -14.0), "giro": -PI*0.5, "s": 367},
{"de": (-15.0,  30.0), "ate": ( -4.0,  30.0), "giro":  PI,     "s": 401},
{"de": (  4.0,  30.0), "ate": ( 15.0,  30.0), "giro":  PI,     "s": 433},
{"de": (-31.0,   4.0), "ate": (-31.0,  18.0), "giro":  PI*0.5, "s": 467},
{"de": ( 31.0,   6.0), "ate": ( 31.0,  20.0), "giro": -PI*0.5, "s": 503},
# soltas novas, tortas de proposito
{"pos": (-30.0, -22.0), "giro":  0.21, "larg": 5.4},
{"pos": ( 29.5, -26.0), "giro": -0.17, "larg": 6.0},
{"pos": (-33.0,  26.0), "giro":  PI*0.5 + 0.24, "larg": 5.2},
{"pos": ( 32.0,  28.0), "giro": -PI*0.5 - 0.19, "larg": 5.8},
{"pos": ( -8.0,  34.0), "giro":  PI - 0.14, "larg": 6.4},
{"pos": (  9.5,  34.5), "giro":  PI + 0.11, "larg": 6.0},
```

Conferir cada uma contra `area` antes de desenhar — quadra pequena não pode
jogar casa na rua. O código já faz isso para as árvores; repetir o padrão.

**Polimento.** Em `_modulo_colonial`, acrescentar (todas opcionais por sorteio do
índice, para a fileira não virar carimbo):

1. **Alpendre** — telheiro de 1,4 m sobre dois postes de madeira `0,14 × 2,3`,
   em uma casa a cada quatro. É o que mais falta: hoje o casario é fachada
   chapada, e casario mineiro tem sombra na frente da porta.
2. **Cachorros do beiral**, iguais aos da capela, passo 1,0 m.
3. **Chaminé** `0,5 × 0,9 × 0,5` saindo da água do telhado, uma em cada três.
4. **Postigo azul** — em uma janela a cada três, o mesmo `AZUL` da capela.
   Casario que repete a cor da igreja lê como o mesmo povoado; hoje as
   esquadrias sorteiam entre três escuros e nenhum conversa com a capela.
5. **Banco de rua** encostado na fachada, uma casa em cada cinco.
6. **Vaso e trepadeira** (`moita_de_flor`) na soleira, uma em cada quatro.
7. **Número na porta** — não. A 480×270 não sobrevive; seria chiado.

**Porta aberta com luz quente**, em uma casa a cada sete: vão claro, sem folha,
`janela_acesa` no fundo. É de onde saem os moradores do §7.

---

## 6. O que ficou registrado e não é para consertar aqui

Três coisas medidas com a régua do §0, que pertencem a quem cuida da gradação da
praça e **não** a esta task:

1. **Contraste parede/chão em 10,8 : 1** contra 5,6 : 1 da referência. A saída
   provável não é escurecer a parede: é subir `TOM_PEDRA_MIN/MAX` (hoje
   0,30–0,46), que foram derrubados de 0,78–1,06 numa correção anterior e
   passaram do ponto.
2. **Telha em luma 6,6.** `TELHA_CLARA` / `TELHA_ESCURA` multiplicam o material
   `teto`, que é `reboco` tingido em 0,62 — ou seja a telha já nasce com um
   terço do albedo antes de qualquer luz. Uma textura `telha` própria (capa e
   bica, 256×256, ladrilhável) resolve isso e é o único asset novo que a
   referência realmente pede.
3. **Céu em 62 contra alvo 37.** `sky_color` do preset `praca_noite` é
   (0,232 / 0,252 / 0,252).

Se qualquer peça nova desta task parecer apagada, **meça antes** de mexer em
luz: o mais provável é o albedo da peça, não a cena.

## 7. Vida na praça

### 7.1 Música religiosa

Sintetizar em `tools/gerar_audio.py` — nada aqui depende de arquivo baixado:

- **`igreja_loop.wav`** — órgão/harmônio grave com coro: fundamental + quinta +
  oitava, vibrato lento, envelope de fole. Progressão de quatro acordes, lenta,
  em modo menor. ~20 s, emendado em loop com `emenda_para_loop`.
- **`sino_igreja.wav`** — badalada: parciais inarmônicas (1 : 2,0 : 2,4 : 3,0 :
  4,5) com decaimento longo. Toca na hora cheia, lida do `Relogio`.

Tocar pelo prop **`som_ambiente`**, que já existe e já faz o certo:

```gdscript
props.append({
    "tipo": "som_ambiente",
    "pos": <vão da porta>,
    "som": &"igreja_loop",
    "volume": -19.0,
    "alcance": 26.0,
    # Alvenaria colonial deixa passar o grave. O agudo nao atravessa
    # parede de 60 cm, e sem o corte o coro soa como se o orgao
    # estivesse no calcamento.
    "corte_hz": 900.0,
})
```

26 m de alcance com atenuação quadrática inversa: some antes da borda da praça e
cresce conforme se anda para a igreja. **É o que o usuário pediu — música que
aparece quando se passa perto.**

### 7.2 Pessoas andando pela praça

`Convidado` com `Papel.LIVRE` já circula por uma lista de pontos, para, conversa
e volta. É exatamente o comportamento de praça — e é primo do `Pedestre`, que
serve a calçada e não serviria aqui.

**Um conserto necessário:** `ChunkManager._criar_convidado` passa
`[] as Array[Vector3]` cravado no lugar dos pontos. Ler `prop["pontos"]`.

Semear 5 a 7 pontos no anel da praça + o adro, e 4 a 6 convidados ancorados no
chunk da praça, com `idade_min/idade_max` variados.

### 7.3 Moradores que entram e saem

Arquivo **novo**, `game/src/world/morador_praca.gd`. Não estenda `Convidado` nem
`Pedestre`: os dois são compartilhados com o bar, o mercado e a casa da fumaça, e
mudar a máquina de estado deles para caber uma porta quebra três lugares.

Ciclo: **em casa → sai → anda até um ponto da praça → fica → volta → entra**.

Na porta: virar de frente para ela, tocar `porta_abre`, esperar 0,4 s, sumir
(`visible = false` + colisão desligada), esperar 20–70 s, reaparecer. Sem
animação de atravessar o vão — o vão tem 1,05 m e o corpo é de caixas; a porta
abrindo e o som são a informação inteira, e é o mesmo truque que a `Porta` do
jogo já usa para esconder a construção do interior na thread.

Um morador por casa de porta aberta (§5.3), **no máximo 4 vivos** — o teto de
`POPULACAO_BASE` é 14 para a cidade toda e a praça não pode comer sozinha.

---

## 8. Contrato de render — não negocie sem avisar

480×270 interno, `gl_compatibility`, `vertex_lighting`, `cull_back`, filtro
nearest, sem mipmap, dither de 15 bits, vinheta, scanlines. Texturas 256×256,
≤256 cores, PNG, `compress/mode=0`, `mipmaps/generate=false`,
`detect_3d/compress_to=0`, e têm de ladrilhar.

As nove regras que custaram caro:

1. **Meça antes de mexer.** Amostre pixel cru numa região conferida contra a
   imagem. Nunca ajuste no olho sobre uma imagem clareada.
2. **`get_aabb` não vale no Compatibility.** A imagem é a medida.
3. **A face aparece do lado OPOSTO ao produto vetorial.**
4. **Com `vertex_lighting` a luz só existe no vértice.** Peça fina sem
   subdivisão pode ser atravessada pelo facho no meio e continuar preta.
5. **Degrau entre duas superfícies sem parede lateral é buraco.** Faça a borda
   ser função só da posição.
6. **A 480×270 só sobrevive feição grande** — ~1/5 da célula da textura. Ver a
   conta de px/m em §2.4 antes de inventar cota fina.
7. **Conserte o mundo em vez de contornar.**
8. **Relatório de outro agente não é prova.** Confira.
9. **Trocar buraco por saliência não é conserto.**

E as deste lugar:

10. **Todo sorteio é função pura do índice** (`_ale(semente, indice, canal)`).
    Um parque de 80 m nasce de nove chunks montados em threads separadas, e
    nenhum sabe dos outros. `RandomNumberGenerator` compartilhado faz a mesma
    casa nascer de dois tamanhos conforme quem a desenha.
11. **Peça inteira sai do chunk que contém a âncora dela**, mesmo a parte que
    cai no vizinho. Meia fileira desenhada de cada lado não concorda sobre onde
    começa o módulo e a junta abre.
12. **`gerar_materiais.py` apaga `.tres` fora da tabela.** Alteração não
    commitada some. Confira `git status` antes de rodar.

---

## 9. Como rodar, capturar e provar

```
.tools/Godot_v4.7.2-stable_win64_console.exe --path game -- \
  --pular-menu --pular-abertura --nome-teste=Zeca \
  --ir-para=270.9,-38,270.9,-59.1 \
  --shot="<abs>.png" --shot-frame=200 --shot-quit
```

- **Rode duas vezes e confie na segunda.** A primeira execução depois de mexer
  no código não vale: o Godot reimporta e o streaming ainda está montando no
  frame do `--shot-frame`. Já fez concluir que a igreja tinha sumido.
- `--shot-frame` conta frames de **física**.
- `--ir-para=270...` é o que força o preset `praca_noite`. Medir de outro pin
  mede `fog_leve` e o número não quer dizer nada.
- `--de-cima=x,z,alt,yaw,pitch` — câmera ortogonal, força `fog_dia_sol` e luz
  zenital. É como se acha buraco na praça: um vazio aparece como vazio.
- `--mat-debug` **não vale na praça**. É método do `EstradaBuilder`; aqui devolve
  a cena normal e você anota um teste que não aconteceu.
- `--sem-ceu` faz um vazio ler como preto em vez de ler como superfície.
- **Headless não prova shader.** Capture com janela.
- **`--ver-abertura` suja captura alheia**: uma execução deixa 15 PNGs
  versionados modificados, sete deles da praça. Use `--ver-praca` ou `--ir-para`.
- Salve captura de trabalho no scratchpad, **fora** de `captures/`.

### Critérios de aceite

Marque só o que **mediu**. Observação livre não vira critério — monte a situação.

**Fachada**
- [ ] Luma da nave, do pin, ≥ 80 (hoje: 8,7)
- [ ] Os dois cunhais azuis legíveis como azul, não como sombra (H entre 190° e 210°, S ≥ 0,25)
- [ ] Cornija azul contínua nos quatro lados
- [ ] As duas sacadas com balaústre contável a 13 m (≥ 5 dos 7 distinguíveis)
- [ ] Porta azul, folha direita entreaberta, vão preto visível na fresta
- [ ] Janela do frontão no eixo, com moldura azul
- [ ] Nenhuma face olhando para fora dividindo plano com outra (andar de lado 3 m sem piscar)

**Silhueta**
- [ ] Do pin: frontão + cruz inteiros no quadro, sem corte
- [ ] Do TAKE 5 (c5 ≈ 268,4 / −35,0, lente 58): torre entra no quadro acima da cumeeira
- [ ] Vista de cima: nenhuma peça da capela fora da pegada da quadra

**Cruzeiro**
- [ ] Do pin: mastro, travessa e ao menos 4 dos instrumentos distinguíveis
- [ ] Metal claro sobre céu escuro — contraste ≥ 18 níveis de luma
- [ ] Colisão fecha (andar contra ele não entra)

**Praça**
- [ ] Grama dentro do adro, calçamento fora, sem fresta na junta
- [ ] Caminho de placas do portão ao degrau, no eixo da porta
- [ ] Vista de cima: nenhuma área contínua de calçamento nu > 18 × 18 m
- [ ] Casebre novo nenhum na rua nem atravessando a calçada
- [ ] Poste nenhum nascendo dentro de parede (é o defeito que `planta_matriz` existe para impedir)

**Vida**
- [ ] `igreja_loop` audível a 12 m da porta e inaudível a 30 m
- [ ] Vela na porta e nas duas sacadas ondulando, sem apagar
- [ ] 4+ pessoas circulando na praça, nenhuma atravessando parede
- [ ] Um morador completa o ciclo sair → praça → voltar → entrar

**Orçamento**
- [ ] `--stats=120` em regime (descartando o primeiro bloco, que inclui o build
      de ~150 ms): `pior_ms` sem regressão contra a medida de hoje
- [ ] Triângulos por chunk da praça dentro do teto do ART-BIBLE §10

---

## 10. Ordem de trabalho

Cada passo termina com captura. Passo que não fecha não vira base do seguinte.

1. **§6** — a fachada chegar na imagem. Sem isto o resto nasce invisível.
2. **§2** — a capela azul: cunhais, cornija, sacadas, porta, janela do frontão.
3. **§2.7** — recuar a sineira; conferir o TAKE 5 **antes** de seguir.
4. **§3** — o cruzeiro.
5. **§5.1** — adro avançado, grama e caminho.
6. **§4** — velas.
7. **§5.2** — guarda-corpo e canteiros.
8. **§5.3** — casebres: quantidade primeiro, polimento depois.
9. **§7.1** — música e sino.
10. **§7.2 / §7.3** — gente e moradores.

---

## 11. O que NÃO fazer

- Não edite `game/src/levels/abertura.gd`. É do Cine2. Se uma peça nova quebrar
  um take, **avise** — não conserte lá dentro.
- Não mexa na malha de ruas. Decidido: a praça cresce dentro da própria quadra.
- Não mexa na massa da capela (12,4 × 12,0 × 7,0 + pico 2,2). Superfície, sim.
- Não toque em `carro.gd` (`_aplicar_facho_nevoa`, defeito conhecido e
  deliberadamente não tocado, arquivo em uso por outra sessão).
- Não faça interior de igreja. Só o exterior.
- Não apague `PRINTS/`, `captures/` nem untracked sem revisar.
- Não substitua buraco por saliência, e não conclua nada de relatório alheio.

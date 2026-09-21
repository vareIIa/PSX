# Morros de Minas — mapeamento e plano (21/09/2026)

Pedido: a cidade tem de ter os morros de Minas — ruas íngremes, a igreja no alto, bairros
pendurados na encosta, serra no horizonte. Os três passos foram aceitos. Este documento é
o mapa do que existe, do que muda e de como se prova cada parte. Status em cada item.

Referência: as duas fotos do pedido. A primeira é a cidade no vale, cercada de serras em
camadas que clareiam com a distância. A segunda é a encosta de pasto dourado com eucalipto
e araucária, e o casario descendo o morro até o córrego.

## Regra de convivência

Outras sessões editam o repositório ao mesmo tempo. Todo trabalho novo mora em arquivo
novo. Arquivo compartilhado recebe só gancho mínimo e comentado, e compila a cada passo.
Nada alheio é revertido. Nenhum commit sem aval do usuário.

## Arquitetura

| Camada | Arquivo | Papel | Status |
|---|---|---|---|
| Morro | `src/world/morros.gd` (novo) | Altura bruta do nó: morro da matriz, um morro por célula de 384 m, vale, ruído miúdo. Função pura | feito |
| Chão | `src/world/relevo.gd` | Nivela parque e patamar, aterra a avenida, deforma o chão, ergue o lote, gera a colisão | feito |
| Horizonte | `src/world/serra_da_cidade.gd` (novo) | Anel de cristas preso à câmera, pintado pela cor da névoa | passo 1 |
| Rua íngreme | `src/world/ladeira.gd` (novo) | Declive por trecho; decide escadaria; responde se o carro passa | passo 2 |
| Escadaria | `src/world/escadaria_builder.gd` (novo) | Degraus, patamares, corrimão e frade na boca | passo 2 |
| Encosta | `src/world/encosta_builder.gd` (novo) | Lote em socalco: arrimo de pedra, escadinha, porão | passo 2 |
| Bairro | `MalhaUrbana` (gancho) | Distrito pela altitude | passo 2 |
| Mirante | `src/world/mirante.gd` (novo) | Topo de morro com vista e névoa leve | passo 2 |
| Rua em curva | `src/world/serpentina.gd` (novo) | Grafo extra de ruas curvas dentro das quadras de encosta | passo 3 |

Ordem de dependência sem ciclo: `Morros` → `Relevo` → `ChunkBuilder`. O `Relevo` chama o
`ChunkBuilder` só por `load()` tardio (o `--script` compila antes dos autoloads, e citar
pelo nome zerava as estáticas).

## O terreno (feito)

`Relevo.altura(x, z)` é bilinear nos cantos dos chunks, então a rua sobe reta entre duas
esquinas. As alturas de nó passam por quatro etapas:

1. **Morro** (`Morros.bruto`): o máximo dos morros vizinhos, em perfil de cosseno. A matriz
   tem 36 m, raio de 14 chunks e topo plano de 2,5 chunks. Os morros das células têm de 10 a
   34 m e raio de 0,6 a 0,9 célula. Somam-se 2 m de ruído miúdo. A praça fica em y = 0 e a
   cidade inteira desce dela, então **nenhuma coordenada da abertura muda**.
2. **Parque em patamar** (`_nivelada`): o parque (ou o grupo de parques que dividem um nó)
   fica na média do terreno dele. O grupo da Praça da Matriz fica em zero. O entorno vai do
   nível ao terreno em 5 nós, e todos os parques do alcance entram com peso. Pegar só o
   mais perto criava um degrau de 42% na avenida entre dois parques. Bar e casa da fumaça
   entram como parque pequeno (patamar).
3. **Avenida aterrada** (`_aterrada`): média triangular de ±3 nós ao longo da linha. A
   avenida sobe devagar e quem fica íngreme é a travessa.
4. O `ChunkBuilder` usa o resultado assim:

| Chunk | Caminho |
|---|---|
| Plano em zero (a praça) | Caminho antigo, byte a byte |
| Inclinado | Chão deformado vértice a vértice. Lote rígido na altura da soleira, com embasamento de pedra que desce até o canto mais baixo. Quintal, beco, vila e baldio assentados no chão. Colisão por mapa de alturas de 0,5 m |
| Parque fora da praça | O `ParqueBuilder` monta plano e o chunk sobe inteiro pelo nível do patamar |

Declive medido em 48×48 chunks (`tests/checar_relevo.gd`):

| Via | Mediana | p95 | Máx | > 20% |
|---|---|---|---|---|
| Viela | 2,7% | 19,0% | 38,9% | 4,4% |
| Rua | 3,3% | 16,8% | 37,2% | 2,8% |
| Avenida | 3,3% | 13,2% | 30,5% | 0,7% |

A avenida só passa de 20% colada em parque de encosta. Rua e viela acima de 20% viram
escadaria (passo 2).

## Passo 1 — identidade

### 1.1 Igreja no alto — feito
O morro da matriz tem a praça no topo, em zero exato. Critério: `checar_relevo`, praça
plana em zero e pin 270,-40 em zero.

### 1.2 Menos área plana — feito
O disco plano da origem saiu, e a origem fica 20 m abaixo da praça. Tudo o que supunha
chão em y = 0 passou a ler o chão do morro:

| O quê | Arquivo |
|---|---|
| Nascimento da cena, despertar da abertura, raios de chão | `cidade.gd`, `abertura.gd` |
| Poste | `ChunkBuilder.posicao_poste` |
| Paradas da rota de captura | `rota_captura.gd` |
| Corredor fantasma | `player.gd --atravessar` |
| Bancadas e testes | `bancada_quinas`, `parque_teste`, `teste_horror`, `teste_npc` |
| Sonda de reflexo | `sondas_reflexo.gd` |
| Poça | `pocas.gd` |
| Respingo da chuva | `chuva.gd` |
| Pingo de toldo | `goteiras.gd` |
| Decalque | `decalques_rua.gd` |
| Carro parado segura na rampa | `carro.gd` |

**Para as outras sessões:** alturas absolutas perto da origem (1,0; 1,62) viraram
alturas acima do chão. As imagens de referência da regressão visual fora da praça
precisam ser refeitas, porque a cidade mudou.

### 1.3 Serra no horizonte — a fazer
Anel de três cristas preso à posição da câmera (mesmo padrão de `CeuEstrada._montar_serra`),
sem névoa e pintado a partir de `fog_color`. Na névoa densa ele desaparece; num dia de sol
ele se destaca em camadas. Fica além de onde a cidade para de ser desenhada (até 215 m no
dia de sol) e atrás das estrelas: o corte da câmera do jogador sobe de 220 para 420 m, as
estrelas vão para 320 m e a serra fica em 340–380 m. É ligado pelo `DiretorCeu`.

Critérios:
- Invisível em `neblina`.
- Visível em `dia_nuvens` e `dia_sol`.
- Sem tarja no pé: o saiote tem a cor exata da névoa.
- Não aparece dentro de interior.
- Custo abaixo de 400 triângulos.

## Passo 2 — morro de verdade

### 2.1 Relevo em duas escalas — feito (junto com 1.1)

### 2.2 Escadaria
Trecho de rua ou viela acima de 20% vira escadaria:
- Degrau de pedra e patamar a cada 12 degraus.
- Frade (poste baixo) nas duas bocas, onde o carro não passa.
- A colisão é a rampa do mapa de alturas: o jogador não sobe degrau.

Quem precisa saber:
- `Vias.saidas` e `proxima_*`: o trânsito não entra.
- A pintura de faixa não é desenhada.
- `Rotas`: o pedestre sobe.
- O GPS de carro desvia.

Critérios:
- Nenhum carro da IA dentro de escadaria em 10 min de trânsito.
- Pedestre atravessa.
- A bancada de quinas não vê buraco.

### 2.3 Lote em encosta
Acima de ~12% o lote rígido deixa de bastar:
- **Casa acima da rua:** fica em socalco, com muro de arrimo de pedra na linha da calçada e
  escadinha até a porta.
- **Casa abaixo da rua:** ganha porão ou garagem no andar de baixo, visto do quintal.
- **Porta interativa:** continua rente à calçada.

Critério: `varrer_patio` com zero bocas, e nenhum embasamento com mais de 4 m à vista.

### 2.4 Bairro pela altitude
O distrito passa a pesar a altura: comércio no fundo do vale, casas na encosta, casario
solto no alto. O gancho fica em `MalhaUrbana` (lê `Morros.bruto`, sem ciclo). Critério:
distribuição de distrito por faixa de altura, impressa e conferida.

### 2.5 Mirante
No topo de alguns morros, uma quadra vira mirante: murada, banco, orelhão e vista. A névoa
alivia ali e o horizonte mostra a cidade lá embaixo. Critério: foto do mirante com a serra
e o casário do vale.

### 2.6 Veículos
- Carro: segura na rampa (feito).
- Bicicleta: inclina com o chão.
- Carro da IA: arfagem pelo `Relevo` (feito).

## Passo 3 — rua que segue o morro

A cidade é uma grade, e a rua mora na borda do chunk. Rua em curva não entra nessa grade
sem reescrever o trânsito, a rota, o mapa e o chão. O desenho que convive com tudo:

- **Serpentina** é um grafo extra dentro das quadras de encosta (como beco e parque já
  são). Cada trecho é um objeto:
  - id, dois nós na grade e classe;
  - polilinha em XZ, com `ponto_em(s, lateral)` e `tangente_em(s)` no padrão de
    `EstradaBuilder`.
- **Quem aprende o grafo extra:**
  - `Vias.saidas` (o carro entra);
  - `Rotas.vizinhos` (o pedestre anda);
  - `Rota._vizinhos` (o GPS roteia);
  - `Mapa` (desenha a polilinha).
- **O chunk desenha** a fita de asfalto deformada pelo relevo, a calçada, o meio-fio e os
  lotes ao longo da curva.
- **A IA do carro** segue `s` ao longo do trecho em vez de mirar no ponto de curva.

Critérios:
- A quadra de encosta tem ao menos uma serpentina.
- Carro e pedestre atravessam.
- O GPS passa por ela.
- `varrer_patio` fica sem boca.

## Como se mede

| Teste | O que prova |
|---|---|
| `tests/checar_relevo.gd` | Praça, parque, patamar e declive |
| `tests/varrer_patio.gd` | Quarteirão fechado, com relevo |
| `tests/bancada_quinas.gd` | Buraco pro limbo, com relevo |
| `tools/verificar_*.py` | Trânsito, cidade, NPC, streaming, bar, casa, mercado |
| `--olhar-ladeira=x,z,mira_x,mira_z` | Foto na altura do olho, de dia |

# Rodada 3 da abertura da estrada (25/09): pegada, olho, agarrão e tela

Pedidos do usuário de 25/09 à noite, julgados na rajada de 200 ms da sessão
`acf891fc` (4K, `--ver-estrada --estrada-corrida --estrada-desde=dentro
--susto-rajada --susto-cheio`). Os tempos são o relógio da cena nessa rodada.

Linha do tempo medida: conversa 6,5 · trava 13,2 · golpe 15,1 · romeiros 16,2 ·
batida 17,2 · fogo 24,1 · janela 33,9 · mão 34,7 · cabeçada1 37,6 · relance ao
capô 38,2 · cabeçada2 39,6 · cabeçada3/estoura 41,15 · encara 41,6 · branco 44,1.

## Estado de partida

Nada está commitado desde `8576024`. Duas sessões, ambas paradas, deixaram
trabalho no working tree:

- **pegada do celular** (`69384c9e`):
  - `motorista_cena.gd`, `diag_pegar_celular.gd`;
  - arquivos novos `pegada_leitura.gd`, `trajeto_do_braco.gd`,
    `braco_sem_esporao.gd` e a bancada `bancada_pegada_estrada`.
- **gore do padre** (`e1d9179d`):
  - `abertura_estrada.gd`, `cabeca_do_padre.gd`, `olho_solto.gd`,
    `bancada_gore_janela.gd`;
  - arquivos novos `padres_nas_janelas.gd`, `boca_vit.glb` e
    `padre_que_bom.wav`.

Esse estado inteiro foi congelado no commit solto `cc63feb`, que não está em
branch nenhuma. As worktrees das etapas delegadas saem dele.

## Etapa 1: o celular alinhado na mão ao pegar do chão (sessão principal)

**O defeito**, na rajada de 22,1 a 24,1 s:
- A pinça fecha certo (22,6 s).
- Na subida, a mão e o aparelho se desencontram:
  - 23,1–23,4 s: os dedos entram pela quina de baixo da tela;
  - 23,6–23,7 s: o aparelho boia acima da mão aberta;
  - 23,8 s: o indicador deita atravessado na frente da tela.
- A pegada de leitura só assenta aos 23,9 s.

**Onde mexer:**
- `motorista_cena.gd`:
  - `pegar_do_chao` (a pinça);
  - `erguer_celular` (o aparelho anda por `TrajetoDoBraco.volta_do_chao`, e a
    mão por `PegadaLeitura.troca` a cada quadro);
  - `_animar_bracos` (`_braco_d.pular(levar(fone, _pega_no_fone))`).
- `pegada_leitura.gd` (`CHEGA`, `TROCA`, `troca()`).
- `braco_vivo.gd` (alcance e ordem do IK).

**Não mudar:** onde o celular cai, o alcance esticado, os tempos e o esforço
(ver a memória `conserto-de-clip-nao-muda-a-encenacao`).

**Pronto quando:** do fechar da pinça até a leitura, o aparelho fica preso
entre polegar e dedos em todo quadro, sem dedo sobre a tela e sem vão. Isso se
mede pelo esqueleto no espaço do aparelho (a polpa de cada dedo contra as faces
e a borda da tela) e se confere na rajada 4K.

**Feita (25/09, à noite).**
- **A causa.** A pinça da tarde tinha médio, anelar e mínimo fechados **na
  frente** da tela, 16–21 mm acima do vidro. Para chegar à borda esquerda, a
  troca os arrastava pela frente da tela, e as chaves "abertas" que evitavam a
  malha faziam o médio abrir e fechar três vezes em 150 ms.
- **A pinça e a troca novas:** um C na borda direita. O polegar fica no vidro e
  os quatro dedos nas costas, e a troca inteira acontece por trás do aparelho.
- **Arquivos:**
  - `pegada_leitura.gd` ganhou `PINCA`, `CHEGA` e `TROCA` novas;
  - o resolvedor está em `tests/resolver_pegada_c.gd`.
- **Medido na cena** (`diag_pegar_celular` a 60 fps fixos, trecho denso de 21,2
  a 23,4 s):
  - nenhum dedo sobre a tela até a própria leitura (antes, até 59 mm);
  - os quatro dedos a 0–2 mm das costas o tempo todo (antes, até 10 mm);
  - curvatura do médio de 81 a 153 sem voltar;
  - no máximo 0,69 mm de malha dentro do aparelho;
  - nenhum toque do braço direito na cabine.
- **Não mudou:** onde o celular cai, o alcance (o ombro fica a 1,083 m da palma,
  contra 1,084 m antes) e os tempos.

## Etapa 2: o olho voa no estouro e cai no celular do colo (CANCELADA)

**Cancelada pelo usuário em 25/09, às 21h**, depois de ver a primeira rodada do
agente: "cair olho no celular ficou forçado"; o olho pendurado no nervo fica
melhor. Nada da `PSX_e2` entra na árvore principal. O olho continua como estava:
sai da órbita no estouro e fica pendurado. O registro abaixo fica só como
histórico.

**O pedido.** Na cabeçada que quebra a janela, o olho solto sai voando e cai em
cima do celular que está no colo, sujando tudo de sangue. O personagem olha
para o celular com o olho em cima dele, volta a olhar para o padre, e a cena
continua.

**Hoje:**
- `_soltar_o_olho()` (`abertura_estrada.gd`, ~l. 2269) solta o globo com
  `OLHO_SAI` e ele fica pendurado no nervo (`OlhoSolto`, uma corrente de Verlet
  presa na órbita).
- O celular morreu antes da janela (`apagar_celular`).
- `mostrar_celular(false)` (`motorista_cena.gd`, ~l. 867) desce o aparelho e,
  no fim, **esconde** `_mao_direita`, e o aparelho vai junto porque é filho
  dela.

**Onde mexer:**
- `_padre_cabeceia`: o trecho entre o estouro e `_encarar` (~l. 1893–1925).
- `_soltar_o_olho` e `OLHO_SAI`.
- `olho_solto.gd`:
  - o nervo arrebenta;
  - o voo balístico, mirado para cair no aparelho;
  - o quique, o rolar e o assentar, com o sangue ainda saindo.
- O aparelho **visível** no colo (tela apagada) enquanto a lente desce.
- O sangue no vidro e na carcaça do celular, num nó novo por cima do
  `Iphone4S`.
- O relance da lente: descer ao colo, parar no olho, voltar ao padre.

**Pronto quando:**
- Na rajada, o olho sai no estouro, voa, bate e para em cima da tela.
- Aparecem as gotas e a mancha no aparelho.
- A lente desce, fica no olho e volta ao padre.
- `encara` e o agarrão seguem inteiros.

## Etapa 3: o agarrão (feita na árvore principal em 26/09, espera o aval)

**Como ficou** (`src/levels/agarrao_do_padre.gd`, novo; tempos da rodada
1080p com o plano novo do capô):
1. **Estouro (48,8 s):** a mão que empurrava o vidro cai com ele e agarra o
   parapeito (`mao_ao_parapeito`).
2. **Stare de 1,6 s, calado.** A frase saiu de `_encarar`, e a boca arreganha
   devagar.
3. **A mão sobe (50,6 s):** a garra sai do parapeito acelerando e entra no
   quadro na frente da cara dele. Ele se encolhe tarde.
4. **O tapa (51,0 s):** ela espalma na cara e cobre dois terços da vista, pelo
   lado direito.
   - Os dedos escuros e desfocados atravessam a vista, com o vão entre o médio
     e o anelar.
   - A cabeça vai virada pela mão, e a cara dele fica no terço esquerdo.
   - O som é o `mao_na_cara`; o mundo abafa (`_vacuo`) e entra a respiração
     abafada do motorista.
5. **A frase (51,2 s):** "que bom que você veio", com a mão ali. Ele chega
   mais perto para dizer, e a mão aperta duas vezes.
6. **O empurrão (53,6 s):** a palma joga a cabeça para longe e a nuca bate no
   encosto. Ele leva a cabeça para trás e fica armado 0,28 s, com a lente
   fechando (dolly).
7. **O puxão (54,2 s):** a mão arranca a cabeça para a testa dele, que
   persegue a lente. O branco cai no golpe (54,4 s), com o som
   `cabecada_final`.

**As quatro ideias aprovadas pelo usuário (26/09)**, todas em
`agarrao_do_padre.gd`:
1. **A mão do motorista reage:** 0,35 s depois do tapa, a esquerda dele sobe do
   colo e agarra os dedos do padre pela borda de baixo à esquerda.
   - Ela puxa aos trancos, e a mão do padre não sai do lugar.
   - No empurrão ela é arrancada e cai.
   - O braço é o `_braco_e` do `MotoristaCena`, tomado por
     `braco_esquerdo_para_a_cena`.
2. **A outra mão na gola:** no empurrão, a mão da frente do padre fecha na gola
   da jaqueta.
   - Fica fora do quadro: a gola está uns 50° abaixo do olhar, e ele olha o
     padre.
   - O que se sente é o pano sendo agarrado (`arrasto_corpo`) e o tranco do
     peito para a janela.
3. **Sangue na vista no golpe:** o golpe congela 0,075 s, com o tempo do jogo
   a 3%.
   - A lente olha os olhos dele a 20 cm, nítida (o obturador fecha).
   - O sangue abre em raios e gotas do ponto da testa (camada 140, abaixo das
     faixas do cinema).
   - Só então vem o branco. O som da cabeçada toca no contato.
4. **Mundo abafado de verdade:** do tapa ao empurrão, um passa-baixa de 650 Hz
   atua sobre dois alvos:
   - no bus `Ambiente`, por cima do filtro do menu;
   - num bus próprio, `AgarraoAbafado`, para onde vão os laços do fogo.

   O coração sobe 4 dB. No empurrão a mão sai da orelha e o mundo volta
   inteiro, de uma vez, para o golpe. Tudo é desmontado no golpe e em
   `_exit_tree`.

**A mão ferida** (pedido do usuário na sessão psx-ce) está PAUSADA desde
26/09: o usuário parou o agente. O rascunho ficou em
`PSX_mao/game/src/render/mao_ferida.gd`, sem ligação na principal. O plano era
este:
- material novo `MaoFerida.vestir(b)`, só para a mão do agarrão;
- mantém `sangue` e `perto_da_lente`;
- eu ligo com uma linha em `_padre_cabeceia` quando ela entregar.

**Por que a mão vive no espaço da lente:** ela é refeita depois da câmera, a
cada quadro. Refeita antes, como as outras mãos, escorregava centímetros na
cara no puxão.

**O que ficou para trás nas rodadas:**
- a palma de frente parada: lia como placa;
- a mão trocando de lugar no empurrão: saía do quadro, e o dedo cortava no
  plano de perto;
- a cabeça virada e deitada demais no golpe armado: a lente via o teto.

**Mexido fora do arquivo novo:**
- `abertura_estrada.gd`:
  - `_encarar` sem a fala, e `CABECA_DENTRO` de 2,0 para 1,6;
  - `_agarrar_e_puxar` reescrita;
  - a mão ao parapeito no estouro;
  - o gancho no fim de `_de_dentro`;
  - a mão presa na cara fora do laço de `_process`;
  - `_ao_branco(golpe)`;
  - a flag `--susto-rajada-passo=`;
  - saíram `_puxao`, `PUXAO_*`, `AGARRA_*` e `MAOS_ENTRAM`/`FECHAM`.
- `render/maos_podres.gd`: dois parâmetros por mão, com zero de padrão. São o
  `sangue` (o do vidro, na palma e nas polpas) e o `perto_da_lente` (o escuro
  da mão colada na cara).
- **Sons novos** (`tools/gerar_audio_agarrao.py`): `mao_na_cara`,
  `mao_aperta`, `respira_abafado`, `cabeca_empurrada`, `puxao_ar` e
  `cabecada_final`.

## Etapa 3: o pedido original

**O pedido, na ordem:**
1. Ele põe a mão no nosso rosto, e a mão entra na visão e a tampa.
2. Ele fala a frase de boas-vindas. Hoje ela é o `padre_que_bom.wav`, "que bom
   que você veio", dita no `_encarar`.
3. Com a mão na cara ele empurra a cabeça para longe, para pegar impulso.
4. Depois puxa na direção da cabeçada final dele, e a tela fica branca.

**Onde mexer:**
- `_agarrar_e_puxar` (~l. 2162): as `_maos_padre`, `_puxao`, `PUXAO_TEMPO`,
  `PUXAO_CORTA` e `_ao_branco`.
- A fala, que sai de `_encarar` (`falar(FALA_QUE_BOM)` e `padre_que_bom`).
- Onde `_puxao` move a lente.
- As poses da `MaoPosada` perto da lente: a palma cobrindo a câmera e o
  antebraço fora do rosto do padre.

A etapa 2 foi cancelada, então o tempo do estouro ao agarrão continua o de hoje.

## Etapa 4: a tela do celular no chão e as mensagens do padre (delegada)

**4a. A tela no chão.**
- De 20,6 a 22,4 s o aparelho no chão mostra uma conversa vazia: o fundo
  branco, o campo e "Enviar".
- Deve continuar mostrando o grupo "Bonde São Thomé" como estava na mão quando
  ele apagou a desculpa: a conversa do grupo e o campo vazio.
- Onde olhar:
  - `cair_na_batida` (`motorista_cena.gd`);
  - o trecho da batida ao chão em `abertura_estrada.gd` (~l. 1270–1330, o
    `tela().zoom`);
  - `tela_do_celular.gd` e `app_mensagens.gd`.

**4b. As mensagens do "?".**
- Hoje o glitch é forte demais e mal se lê. `PANE_POR_MENSAGEM` vai até 0,85, e
  `pane_no_celular` corrompe o texto a partir de 0,25.
- O pedido:
  - glitch mais fraco;
  - **mais** mensagens macabras do padre, diferentes, chegando em rajada, todas
    legíveis, com o aparelho falhando por cima;
  - no fim a tela apaga e a cena segue.
- Onde olhar:
  - `FALAS["recado"]`, `RECADO_TEMPOS`, `PANE_POR_MENSAGEM`, `PANE_TRANCO`,
    `_receber_do_padre` e `BATIDAS_POR_MENSAGEM`;
  - o `_cerco(&"mensagem", [i, n])`, que conta as mensagens;
  - `CELULAR_MORRE`;
  - `Iphone4S.pane` e o `corrompe` do `AppMensagens`.
- Tem de continuar valendo:
  - o padre vai para a janela no começo das mensagens;
  - o trinco puxa;
  - "Olha pra mim." é a última;
  - o cerco para de uma vez quando o aparelho morre.

**4c. "Olha pra mim."** Pedido do usuário às 21h30. Quando essa mensagem
chega, a lente dá um zoom leve em direção a ela. Meio segundo depois vem um TOC
TOC TOC realista no vidro da janela do motorista, e a cena continua.

**Pedidos das 21h20 para o glitch:**
- só a partir das mensagens do padre;
- no nível da versão anterior, que dava para ler;
- o teste final é em janela e tempo real, para o usuário validar, e fecha
  sozinho depois do branco.

## Estado em 25/09, 23h

- **Etapa 1 (pegada do chão): APROVADA pelo usuário.** Depois da pegada em C,
  um agente refez o movimento, porque o usuário achou que ficou "robótico, ombro
  travado".
  - O ombro agora avança e desce, o cotovelo dobra e gira, e há três tentativas
    no chão.
  - O tremor é de ruído e há peso ao erguer.
  - Os arquivos: `src/world/alcance_vivo.gd` (novo) e as funções dos braços do
    susto em `motorista_cena.gd`.
- **Etapa 2: cancelada.** O olho continua pendurado no nervo.
- **Etapa 3 (agarrão): feita em 26/09 na árvore principal, espera o aval do
  usuário.** Ver a seção da etapa 3.
- **Etapa 4 (tela no chão, mensagens, glitch, zoom e TOC TOC TOC): APROVADA e
  juntada** na árvore principal.
  - Merge de três vias contra o `cc63feb`, sem conflito, junto com a pegada
    nova.
  - Os sons são `toc_vidro_1..3.wav`, gerados por `tools/gerar_audio_toc.py`.
  - A flag `--sair-no-fim` fecha a cena depois do branco.
  - A rodada juntada (`--susto-rajada`, 1080p) passou inteira: a conversa do
    grupo no chão, as 14 mensagens, o TOC TOC TOC aos 35,2 s e o branco aos
    47,0 s.
  - A cópia `PSX_e4` foi removida.
- **Suspeita anotada:** um quadro da rajada (23,31 s) saiu com a tela do
  celular rolada na vertical. Não se repetiu no diagnóstico a 60 fps, em que
  cada quadro de 22,4 a 23,9 s saiu normal e a textura do app nunca rolou.

## Quem mexe onde (para as três frentes não se atropelarem)

| arquivo | etapa 1 | etapa 2 | etapa 4 |
|---|---|---|---|
| `motorista_cena.gd` | pegar, erguer, braços | só uma função nova no fim (deixar o aparelho visível no colo) | `cair_na_batida`, só se precisar |
| `pegada_leitura.gd`, `trajeto_do_braco.gd`, `braco_vivo.gd` | sim | não | não |
| `abertura_estrada.gd` | não | do estouro ao `_encarar` | falas, recado, pane, trecho do chão |
| `olho_solto.gd` | não | sim | não |
| `iphone_4s.gd` | não | não (o sangue vai num nó novo) | pane |
| `app_mensagens.gd`, `tela_do_celular.gd` | não | não | sim |

As etapas 2 e 4 rodam em worktrees próprias:
- `C:/Users/Administrator/Documents/Codes/Games/PSX_e2`
- `C:/Users/Administrator/Documents/Codes/Games/PSX_e4`

As duas saem de `cc63feb`, com o `.godot` copiado. A sessão principal traz o
resultado de volta com merge de três vias contra a base guardada.

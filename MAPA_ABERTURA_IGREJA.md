# Mapa — abertura depois do branco (igreja/praça → cidade → controle)

Escrito em 24/09/2026 para a frente que cuida da abertura **depois** da tela
branca. A estrada (carro, padre, batida, branco) é de outra sessão.

## 1. Fronteira com a sessão da estrada

| Coisa | Dono | Observação |
|---|---|---|
| `game/src/levels/abertura_estrada.gd` | estrada | tem WIP não commitado |
| `game/src/ui/branco_do_susto.gd` | estrada | nós só chamamos `dissolver()` |
| `cidade.gd` → `_rodar_abertura` (~1731) | estrada | WIP: guarda `_estrada_rodando`. Não commitar este arquivo sem separar hunks |
| `game/src/levels/abertura.gd` | **nós** | limpo, sem WIP. É o roteiro inteiro depois do branco |
| `corpo.gd`, `convidado.gd` | frente da estufa (sacola) | WIP alheio (`gesto`, `LidaDaSacola`). Mexer por cima, nunca reverter |

**A emenda:** a estrada chama `_ao_branco()` → `BrancoDoSusto.estourar()`
(branco, zumbido, coração, respiração; mais uma respiração calma à esquerda
1,6 s depois). Ela espera 2,6 s ([abertura_estrada.gd:1553](game/src/levels/abertura_estrada.gd#L1553)),
desmonta e só então `cidade.gd` chama `Abertura.executar()`. Nosso
`_preparar_cenario` gasta de 1,5 a 3,5 s assentando o corpo, e `dissolver(2,4)`
([abertura.gd:953-956](game/src/levels/abertura.gd#L953-L956)) vem depois disso.
**Somando, o branco dura de 7 a 9 s**; o plano pedia 2,6 s (4,5 s no máximo).

**O que a estrada entrega à história hoje:**
- Ele **apagou a desculpa inteira**, ou seja, decidiu ir. **Nada foi enviado**
  (`TRAVA_LETRAS := 0`).
- Bateu na árvore, e o capô pegou fogo.
- O celular caiu e ele o pegou do chão. Um contato "?" mandou "Bem vindo" cinco
  vezes; a outra sessão vai trocar essas mensagens por outras mais
  aterrorizantes.
- O padre quebrou o vidro com as duas mãos, agarrou e puxou, e então veio o
  branco.
- Há um santinho pendurado no retrovisor.

Consequência: a Parte C do `docs/PLANO_INTRODUCAO_AAA_PICA.MD` (LUCAS "??",
MARI "Não vai o quê") depende de "Gente, não vou" ter sido enviado, e isso não
acontece mais.

## 2. O roteiro de hoje ([abertura.gd](game/src/levels/abertura.gd))

`executar` (483) → `_preparar_cenario` (520): pin (270, −40), o corpo deitado
por `_deitar` e a pose `DEITADO_ACORDAR` → `_plano_da_praca` (899) → avenida
(1401) → blitz (1310) → mercado (1343) → casa (1659) → poste (1530) → bituca
(1762) → `_entregar_o_jogo` (1987).

| Take | Linhas | Hoje (base 4K de 24/09, MODERNO) |
|---|---|---|
| Céu (POV) | 938–965 | névoa e o branco dissolvendo |
| Mãos e pernas (POV) | 967–989 | câmera parada; as mãos postas no ar, sem ação. A igreja e o cruzeiro já aparecem inteiros, e a revelação do TAKE 5 se perde |
| Deitado, plongée + avanço | 1021–1069 | o corpo **boia** duro, com as mãos juntas no ar; a tarja corta a cabeça da plateia |
| Levantar | 1084–1098, `_levantar` 699 | o nó inteiro gira como **prancha** junto com `Corpo.levantar`; o tronco não empurra o chão |
| Olha em volta | 1105–1123, `_olhar_em_volta` 1254 | três giros de cabeça (−0,55 / +0,62 / −0,28 rad), câmera nas costas dele, rosto nunca aparece |
| Igreja | 1130–1142 | boa composição (capela de frente, cruzeiro à esquerda); a foto sai antes de a legenda subir |
| Mercado | 1343–1370 | entra no **cômodo teleportado** (`Interiores.entrar`, semente 77451) |

**O vidro branco do mercado:** o cômodo teleportado fica a 2000 m de altura, e a
vitrine dele é, de propósito, um painel fosco branco aceso (`mercado_vidro`
`#dfeaee`, [mercado_builder.gd:556-561](game/src/world/mercado_builder.gd#L556-L561)).
O jogo usa a loja da rua (`InteriorNoMundo`), cuja vitrine mostra a rua. O
conserto é filmar a loja real, e não mexer no vidro.

## 3. Maquinaria disponível e limites

- **`Cinema`** ([cinematica.gd](game/src/ui/cinematica.gd)):
  - `mover` (402) faz só uma **reta** entre dois pontos, com easing fixo em
    SINE, e não dá para esperar por ele. Não tem órbita, curva, tremor, câmera
    na mão nem roll.
  - `enquadrar` não mata um `mover` em curso.
  - `profundidade(foco, força)` (347) existe e nunca foi usada.
  - `legenda("MORADORA: ...")` já desenha o nome de quem fala.
  - A estrada faz a própria câmera: pega `Cinema.assumir()` e escreve o
    transform a cada quadro, com tremor, respiração e foco
    (abertura_estrada.gd:3300-3337). **O 360 e a câmera na mão pedem o mesmo:
    um operador próprio.**
- **`LevantarDoChao`** ([levantar_do_chao.gd](game/src/render/levantar_do_chao.gd)):
  - Chaves por alvo de mão e pé, com IK e régua (`tests/medir_levantar.gd`).
  - De bruços (86): flexão → de quatro → um joelho → de pé.
  - De costas (51): apoia nos cotovelos → senta → agacha → de pé.
  - Só o `BonecoDePano` usa. Os tempos são de ragdoll (~2 s) e ficam curtos
    para cinema.
- **Mãos boas:** `BracoVivo` + `MaoPosada` (as da cabine, com unha, pele e
  poses de dedo). Hoje o POV da praça usa as mãos do corpo de caixas.
- **Rosto** (`rosto.gd`): 11 expressões e 6 bocas, com bancada própria
  (`tests/bancada_rosto.gd`).
- **Plateia:** `Convidado.estacionar(ponto, olhar)` e `liberar()`; hoje entram
  7 moradores.
- **Sino** (`SinoIgreja`): só toca na virada da hora ou com `--sino-agora`. Não
  tem API para bater na hora que a cena quiser. Precisa de `badalar(n)` (arquivo
  sem WIP).
- **Som:**
  - `AudioDirector.tocar_ui` descarta som em silêncio quando as 6 vozes estão
    ocupadas. Para susto, use um tocador próprio, como o `_som` da estrada.
  - Há `sino_igreja`, `coro_baixo`, `cachorro_longe_1..3`, `sussurros`,
    `respiracao_calma`, `coracao_loop`, `zumbido_loop`, `grilo` e
    `igreja_loop` (harmônio).
- **Captura:** `Foto.fotografar_camera(cam, pasta, nome)` tira 4K sem tarja e
  sem o `Cinema.profundidade`.

## 4. Bancada — o que falta para medir

- `--ver-praca` sai do **preto**, não do branco: a emenda real não é
  exercitada.
- `_capturar_plano` grava **21 PNGs versionados** (`captures/_sessao_corpo_praca`,
  `captures/praca_matriz/cine`, `game/captures/abertura`). Depois de rodar,
  restaure-os com `git checkout --` se estavam limpos.
- A praça não tem rajada.

Falta criar: `--praca-rajada=<dir>` (um quadro a cada 0,1 s com o tempo da cena
no nome, mais `--praca-cheio` em 4K), `--praca-fotos=<dir>` fora do repositório,
`--praca-desde=<take>`, e uma flag que monte o `BrancoDoSusto` para a praça
dissolver.

Linha de base de hoje: 7 fotos 4K na pasta de rascunho da sessão
(`base/praca/`).

## 5. Fases propostas

1. **F0 — Bancada:** rajada, fotos fora do repositório, pular para um take e
   começar pelo branco.
2. **F1 — Acordar em POV:**
   - Pálpebra de verdade: piscadas curtas, com o foco voltando.
   - As mãos `BracoVivo` entram no quadro, uma sobe diante do rosto e treme,
     os dedos abrem e fecham, e ela desce.
   - Ele se apoia nos cotovelos (a chave 1 "de costas") e as pernas entram no
     quadro, com um joelho dobrando.
   - A igreja fica fora do quadro até a revelação.
3. **F2 — Levantar de verdade:**
   - Uma sequência cinematográfica nova no `LevantarDoChao`: de costas → vira
     de lado → **mãos à frente no chão** → de quatro → um joelho → de pé.
   - Mais lenta e trôpega: falha uma vez e volta ao chão.
   - Sai o giro de prancha (`_levantar`/`_deitar`), e o corpo deitado encosta
     no chão, sem boiar.
4. **F3 — Olhar 360:**
   - Um operador de câmera próprio dá a volta inteira nele, na altura do olho,
     **passando pela frente do rosto** (expressão de medo pelo `Rosto`).
   - A cabeça e os olhos procuram em sincronia.
   - A volta mostra a praça, o casario, a igreja e a plateia inteira parada
     olhando.
5. **F4 — Mercado:** filmar a loja da rua (`InteriorNoMundo`) com o atendente e
   o cliente, em vez do cômodo teleportado.
6. **F5 — Tensão, no tom da estrada:**
   - Branco de 2,6 a 4,5 s: a praça é montada debaixo dos 2,6 s da estrada.
   - O zumbido e o coração baixam.
   - A "respiração calma à esquerda" continua na praça e não tem dono.
   - O sino bate **fora de hora** e dobra.
   - A plateia vira a cabeça junta, alguém se benze, e a MORADORA diz "Ele
     trouxe mais um."
   - O padre aparece de relance na porta entreaberta da capela.
   - Marcas da batida: caco de vidro no cabelo, corte na mão, o santinho
     arrebentado ao lado da mão.
   - Roupa molhada numa praça seca.
   - Câmera na mão com tremor residual e foco de plano.
   - Falas reescritas para a história atual (padre, janela, "Bem vindo").
7. **F6 — O resto da cidade** (avenida, blitz, casa, poste, bituca, GPS):
   capturar de novo com a bancada nova e revisar plano a plano.

Toda fase fecha com rajada 4K e mosaico (`tools/mosaico_rajada.py`), mais
recortes em resolução cheia.

### Andamento (24/09)

- **F0, F1 e F2 feitas.** POV com pálpebra, mão diante do rosto, cotovelos e
  pernas (`AcordarNaPraca`, `ChavesDoAcordar`, `PalpebraDaLente`); levantar com
  as mãos à frente, escorregão e de quatro. Réguas: `tests/medir_acordar.gd`.
- **Levantar de helicóptero** (pedido no meio da F2): um plano só, alto e ao
  sul, descendo de 25 m para 19 m. A igreja entra no fundo, e o facho quente da
  janela do coro (`_acender_igreja`) faz a poça onde ele está.
- **Névoa da abertura:** `fog_praca_nevoa.tres` (12→44 m, cor de ar aceso).
  Comparados no mesmo plano: `praca_noite`, `estrada_noite`,
  `estrada_noite_chuva`, `noite_chuva`, `neblina` e `denso`. Os de chuva põem
  gota na lente, `neblina`/`denso` apagam a noite, e os de noite quase não têm
  névoa. A praça do jogo segue em `praca_noite`.
- **Desempenho:** os picos "periódicos" de ~135 ms eram as fotos da própria
  bancada (hoje desligadas sob `--medir`). O de +106 pipelines dos braços do POV
  caía no olho abrindo: `entrar_no_olho_aquecido` o põe sob o branco chapado.
  Depois do carregamento, 190 fps de mediana em 4K e p99,9 de 11 ms.
- **F3 feita (olhar 360°).** Uma volta inteira da câmera em volta dele, na
  altura do rosto (`AcordarNaPraca.orbitar`), rápida nas costas e devagar na
  frente. Ele leva a mão à nuca, procura para os lados, ergue o rosto para a
  torre quando a lente passa na frente e, quando a respiração calma da estrada
  volta pela esquerda, vira por cima do ombro esquerdo direto para a lente.
  As chaves estão em `ChavesDoAcordar.chaves_olhar` (régua 144/144). O medo é
  montado por partes (`TRISTEZA` + `micro` ERGUIDA/ARREGALADO): a boca do
  `MEDO`, de baixo, lê como sorriso. Bancada: `--praca-desde=olhar
  --praca-ate=olhar`.
- **F4 feita (mercado).** O plano filma a loja de rua mais perto
  (`InteriorNoMundo`, porta com `mundo`), e não o cômodo teleportado, cuja
  frente é um painel fosco (as "fotos brancas"). A câmera
  (`TrilhoDeCamera`, novo) vem da rua, de frente para a vitrine acesa, entra
  pela porta automática e termina no corredor do balcão, com atendente e
  cliente lado a lado e o vidro com a rua escura atrás. Três detalhes:
  - a porta abre pelo corpo escondido dele, parado no sensor e fora da soleira;
  - o ar muda pela posição da lente (`_ar_da_loja`), porque a loja mistura
    com o preset do jogador e a noite virava neblina de dia no meio da porta;
  - `Multidao.semear()` no preto: a multidão repovoa a um pedestre a cada
    0,8 s depois de teleporte, cada um um quadro de 15 a 25 ms.

  Medido: 6,7 ms de mediana, p99 de 8,3 ms, nenhum quadro acima de 16,7 ms.
  Bancada: `--abertura-desde=mercado --praca-ate=mercado`. O
  `src/levels/teste_mercado.gd` (de outra frente) ainda diz que a abertura usa o
  cômodo teleportado.
- **Fumo feito (poste, POV e casa da fumaça).**
  - **Cigarro:** um Marlboro branco (`Cigarro`, filho da `Blunt`), com 84 mm,
    filtro de cortiça, marca impressa, brasa, cinza e queima. A textura sai de
    `tools/gerar_cigarro.py`. Ele substitui o bastão bege do `Adereco`
    parafusado no osso.
  - **Poste:** ele fuma de verdade, com a `Tragada` da casa e a mão indo à
    boca por IK. A tragada funda sai no meio da descida, e o sopro para o alto
    acontece com a câmera chegando.
  - **Enquadramento do poste:** a câmera terminava 1,2 m acima dele, porque o
    `_levar_para` saía no primeiro quadro com o `is_on_floor` do lugar
    anterior. O lado da calçada era sondado antes de o bairro carregar.
  - **POV:** mão `BracoVivo` com o cigarro entre os dedos, o último trago, o
    sopro e o peteleco. A bituca quica soltando faíscas, e o olho fecha em cima
    dela no chão.
  - **Casa:**
    - fio de fumaça em fitas (`FumacaParticulas.Tipo.FIO`);
    - a baforada deixou de sumir no rosto (esmaecimento de 25 cm para 4 cm);
    - a brasa não pinta mais a cara de laranja.
  - **Sons novos:** `tools/gerar_audio_cigarro.py`.
  - **Medido em 4K:**
    - poste: p50 6,0 ms, p99 8,8 ms;
    - POV: p50 6,7 ms, p99 8,8 ms, com o aquecimento da mão e da faísca no
      preto;
    - os picos de CPU da casa (40 a 80 ms) são os mesmos com o fio antigo, logo
      não vêm do fumo.
  - **Bancadas:**
    - `--abertura-desde=poste` (com `--praca-ate=poste`);
    - `tests/bancada_cigarro.gd`, e `--ponto-fixo` acha a pega na boca.
- Pendente de F5: as nuvens do céu viram manchas escuras no POV (já eram
  assim com `praca_noite`).

## 6. Riscos herdados

- `Interiores.sair` libera a névoa. A abertura reimpõe a noite
  (`_impor_a_noite`); mantenha.
- 23:00 faz o sino tocar 11 vezes sozinho. Hoje a praça começa por volta de
  22:46.
- `Cinema.enquadrar` com um `mover` vivo é sobrescrito no quadro seguinte.
- Um `Cinema.mover` rápido (acima de 6 m/s) liga o desfoque de movimento da
  `Lente`. Trave com `Lente.travar_desfoque(0)` se não for desejado.
- Classe nova (`class_name`) pede `--headless --import`.
- A primeira execução depois de mexer no código não vale como captura.

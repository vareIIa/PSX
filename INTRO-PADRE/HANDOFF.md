# Handoff: introdução da estrada (do volante até o branco), rodada 2

Cole o bloco abaixo como primeira mensagem de uma sessão nova. O estado da cena,
com capturas, está em `INTRO-PADRE/ESTADO.md`.

---

# Continuação: introdução da estrada, rodada 2 das críticas do trailer

Responda sempre em português. Faça commit só quando eu pedir.

## 1. Contexto

Jogo de terror em Godot 4.7.2, na pasta `game/`, com renderer Forward+ no estilo
MODERNO. A meta é **qualidade AAA em 4K**. O estilo PS1 é só um preset, não uma
regra.

A cena é a abertura na estrada, à noite e com chuva:
1. O personagem dirige lendo o grupo no celular, apaga a desculpa e dá com o
   padre no farol.
2. O carro desvia e bate numa árvore; o celular cai e ele o pega no chão.
3. Chegam as mensagens do "?", ele vira para a janela, o padre quebra o vidro,
   agarra, e a tela fica branca.

O que vem depois do branco (acordar na praça/igreja) é **de outra sessão**.

Histórico:
- As 9 etapas da primeira lista de críticas estão no commit `85d2e49`, branch
  `claude/estrada-etapas-2-9-v3silv`.
- Depois veio a **rodada 2** de críticas. Ela foi feita na sessão anterior,
  está descrita na seção 5 e está **commitada na mesma branch**, no commit
  seguinte ao `85d2e49`.
- O desempenho foi resolvido. O que sobra está na seção 6.

Leia antes de começar:
- `C:\Users\Administrator\.claude\projects\c--Users-Administrator-Documents-Codes-Games-PSX\memory\MEMORY.md`,
  sobretudo:
  - `etapas-do-trailer-da-estrada.md`
  - `movimento-se-julga-em-rajada.md`
  - `bancada-morre-se-o-script-muda.md`
  - `print-de-tela-do-windows-pede-dpi.md`
  - `seja-direto.md`
  - `sessoes-paralelas-no-repo.md`
  - `duas-armadilhas-mudas-do-godot.md`
- `.claude/skills/godot-project`, que explica como rodar o Godot.
- `INTRO-PADRE/ESTADO.md`.

## 2. Regras deste trabalho

- **Julgue em 4K.** Meu monitor é 4K e a janela sai com 3840x2108. Toda
  captura é com `--resolution 3840x2160`. Para ver detalhe, recorte na
  resolução cheia com PIL: a leitura de imagem reduz para ~2000 px.
- **Movimento se julga em rajada**, com `--susto-rajada` e
  `tools/mosaico_rajada.py`. Foto parada engana: o capuz atravessando o
  batente só apareceu na rajada.
- **Meça antes de mexer.** As sondas da seção 3 existem para isso.
- **Convivência:**
  - A outra sessão trabalha no **pós-branco**: `game/src/levels/abertura.gd`,
    `game/src/ui/branco_do_susto.gd` e as capturas da praça. Não mexa nesses
    arquivos.
  - Há WIP alheio de estufa e sacola: `ver_estufa.gd`, `corpo.gd`,
    `convidado.gd`, `plantacao.gd`, `sacola_de_colheita.gd`,
    `gesto_de_carga.gd`, `lida_da_sacola.gd`. Não toque.
- `--ver-abertura` reescreve 12 PNG versionados da praça. Se rodar, restaure
  com:
  `git checkout -- captures/_sessao_corpo_praca captures/praca_matriz/cine game/captures/abertura`.
- **Laço de medida no fundo = código congelado.** Salvar `.gd` com o laço
  rodando mata a rodada, que sai só com o cabeçalho do Godot, e troca a linha
  de base.
- Use `python`, não `python3`. Heredoc do bash **sem acento**; para texto com
  acento, use as ferramentas Edit/Write.

## 3. Comandos

```bash
G=.tools/Godot_v4.7.2-stable_win64_console.exe
S=<pasta de rascunho da sessão>

# depois de classe nova, shader novo ou WAV novo
$G --headless --path game --import

# a cena em 4K: fotos por momento, rajada a cada ~0,1 s, quadro cheio a cada 1 s
$G --path game --resolution 3840x2160 -- --ver-estrada --estrada-corrida --estrada-desde=dentro \
   --susto-fotos=$S/vNN --susto-rajada=$S/vNN/r --susto-cheio > $S/vNN.log 2>&1
grep "\[susto\]" $S/vNN.log     # conversa, trava, golpe, romeiros, batida, fogo, janela, maos, estoura, branco
python tools/mosaico_rajada.py $S/vNN/r <t0> <t1> $S/saida.png [colunas] [n]

# DESEMPENHO: sem nenhuma flag de captura (get_image trava o quadro)
$G --path game --resolution 3840x2160 -- --ver-estrada --estrada-corrida --estrada-desde=dentro --medir-quadros
#   [quadros] por trecho: media/pior do quadro, cpu, e GPU (medida pelo RenderingServer)
#   [batida]  quanto cada passo do quadro da batida custou (ms)
# bisect de GPU: esconde da batida em diante
#   --gpu-sem=incendio|fumaca|trincas|corredoras|vidros|elenco|auras|luzes
#   --sem-multidao (nao cria a multidao)

# GPU por passe (a flag do motor vai ANTES do --)
$G --path game --resolution 3840x2160 --gpu-profile -- ... --medir-quadros --gpu-passos
# quem custa placa, objeto por objeto, com a cena congelada S s depois da batida
... --sonda-gpu=4.0

# sondas
--sonda-banco    # vertices dos bracos dentro do assento/encosto (e o quanto)
--rajada-fora    # cada quadro da rajada tambem de uma lente na quina do banco do carona
--medir-sons     # cada som que toca, com dB (o cerco aparece como "cerco")
```

- As flags do jogo vão **depois** do `--`.
- A cena leva ~40 s; com captura, ~3 min. Rode em segundo plano.
- Com captura o jogo fecha no branco. Para ver **depois** do branco sem as
  flags, fotografe a tela por fora. Há um script PowerShell DPI-aware descrito
  em `memory/print-de-tela-do-windows-pede-dpi.md`.
- A pele e a roupa do personagem mudam a cada rodada. Não é bug.

## 4. Mapa do código (o que esta rodada tocou)

- **`game/src/levels/abertura_estrada.gd`**, o roteiro. `_plano_dentro()` é a
  sequência inteira.
  - **Mensagens:**
    - `FALAS["recado"]` e `FALAS["olha"]`;
    - `RECADO_TEMPOS`, `OLHA_LE`;
    - `_receber_do_padre()`, que sobe a pane e o cerco a cada mensagem;
    - `PANE_POR_MENSAGEM`, `BATIDAS_POR_MENSAGEM`, `CELULAR_MORRE`,
      `SILENCIO_ANTES_DE_VIRAR`.
  - **O cerco** (batidas em volta do carro): `BATIDA_LUGARES`,
    `_bater_em_volta()`, `_uma_batida()`, `_calar_as_batidas()`.
  - **O padre**:
    - `_maos_no_vidro()`: três batidas, esfarelar, entrar, agarrar, puxão;
    - `_bater_no_vidro()`;
    - mãos posicionadas **pela tela**: `_na_tela()`, `_raio_da_tela()`,
      `_da_tela_ao_plano()`, `_da_tela_a_distancia()`;
    - constantes `MAOS_TELA_*`, `AGARRA_*`, `PADRE_AFASTA`, `PADRE_ENTRA`,
      `PELE_DAS_MAOS`;
    - `_medir_rosto()`, a distância lente→rosto no log.
  - **Estilhaços**: `_preparar_estilhacos()` (emissores feitos no
    pré-aquecimento, escondidos) e `_estourar_vidro()`. Material em
    `_preaquecer_a_batida()`, com refração.
  - **Pré-aquecimento**:
    - `_aquecer_na_lente()` fecha a cortina e desenha uma vez: o elenco, a
      multidão, os estilhaços, as trincas, a névoa e a treva, as revoadas, o
      celular aceso com todas as letras e o fogo do capô;
    - `_preparar_trincas()`, `_revoada(i)`;
    - `_auras_na_fila`, que acende uma aura por quadro.
  - **Branco**:
    - `_ao_branco()` é idempotente e esconde `_raiz` no quadro seguinte;
    - `_lacos` guarda os laços do incêndio, que o branco corta.
  - **Câmera**: `_soco` (FOV) e `_recua` (ele se encolhe), somados em
    `_mover_camera()`.
  - **Bancadas**:
    - `_sondar_banco()`, `_seguir_lente_de_fora()`, `_gpu_sem_aplicar()`;
    - `_custo_da_batida()`;
    - GPU em `_medir_quadro()`.
- **`game/src/world/motorista_cena.gd`**:
  - `aquecer_celular()`;
  - `MAO_NO_COLO` e `MAO_E_NO_COLO` agora ficam em cima da coxa (antes, dentro
    do assento);
  - polos dos cotovelos em `_ombros()`;
  - `_cotovelo_baixo` na descida do aro;
  - `pane_no_celular()`, `apagar_celular()`;
  - em `mostrar_celular(false)` o brilho desce do valor atual.
- **`game/src/world/iphone_4s.gd`**: `pane` no `TELA_SHADER`, `pane()` (a luz
  da tela pisca junto) e `brilho_atual()`.
- **`game/src/ui/app_mensagens.gd`**:
  - `escrevendo`, o balão de "digitando…" (`_escrevendo()`);
  - `corrompe` e `_corromper()`, que trocam letras por lixo.
- **`game/shaders/psx_trinca_vidro.gdshader`**: `esfarela` e `grao`, o
  temperado virando mosaico de grãos.
- **`game/src/render/fumaca_negra.gd`**:
  - raymarch recortado no topo da fumaça e no elipsoide da frente;
  - saída cedo da densidade;
  - ruído por `ImageTexture3D` (`_criar_rede`, `ruido4`);
  - passos pelo tamanho do trecho.
- **`game/src/ui/tela_do_celular.gd`**: fontes MSDF compartilhadas e
  `aquecer_letras()`.
- **`game/src/render/incendio_do_capo.gd`**: `aquecer()`.
- **`game/src/render/gotas_lente.gd`**: câmera com a meta `dentro_do_carro` não
  molha. Era a gota em cima do celular e do polegar.
- **`game/src/levels/cidade.gd`**: `_estrada_rodando` impede uma segunda
  estrada em cima da primeira.
- **`tools/gerar_audio_susto.py`**: gera `mao_lataria_1..4`, `mao_vidro_1..2`
  e `celular_pane`. Pode gerar só esses com
  `python tools/gerar_audio_susto.py <nomes>`.

## 5. Feito na rodada 2 (validado em 4K, rajada)

1. **Bug do padre depois do branco:**
   - Não reproduzi. Em `--ver-estrada` o branco fica parado; em `--ver-abertura`
     ele dissolve na praça.
   - Fechei a porta mesmo assim, de dois jeitos:
     - no branco, a estrada inteira some e os laços do fogo param;
     - uma estrada não roda duas vezes.
   - **Pergunte a ele como rodou**: pelo menu? com que flags?
2. **Braço atravessando o banco:**
   - A causa era a mão "no colo", 11 cm dentro do assento, e os cotovelos
     entrando nos encostos.
   - `--sonda-banco`: a direita tinha 916 vértices a 6,8 cm dentro do próprio
     assento; agora, 0.
3. **Mensagens mais aterrorizantes e rápidas:**
   - O "?" devolve a desculpa apagada; o texto completo está no `ESTADO.md`.
   - Há um "digitando…" entre as mensagens, e o recado inteiro leva ~5 s.
   - **O celular entra em pane** a cada mensagem: rasgo, separação de cor,
     blocos, chuvisco, tela apagando, texto corrompendo e zumbido GSM.
   - **O cerco:** palmas na lataria e nos vidros, em 3D, cada vez mais.
   - No "Olha pra mim." o aparelho morre, o cerco para de uma vez e ele vira no
     silêncio.
4. **Padre mais forte:**
   - Três batidas das palmas nos dois lados do rosto, com tranco na lente.
   - O vidro esfarela inteiro e desaba em grãos de vidro refratário (antes eram
     cubos brancos).
   - Ele entra pelo buraco. O capuz não atravessa mais o batente antes da
     quebra, porque ele recua 8 cm enquanto bate.
   - Uma mão fecha no pescoço e a outra vem na cara; o puxão dá o tranco de
     saída e corta no branco.
5. **Gotas da chuva em cima do celular:** a lente do Cinema molhava dentro do
   carro. Corrigido.

## 6. O que falta, em ordem

### 6.1 Desempenho: feito (continuação da rodada 2)

RX 9070 XT, 4K, `--medir-quadros`, **GPU média por trecho** (ms):

| trecho | início da rodada | depois da 1ª parte | agora |
|---|---|---|---|
| golpe/romeiros (referência) | 7,3 | 7,3 | 7,5 |
| batida (batida → pega o celular) | 13,3 | 11,7 | **8,6** |
| fogo (celular na mão, mensagens) | 16,3 | 13,7 | **8,7** |
| janela | 13,6 | 9,6 | 7,7 |
| mãos / estoura | 15,5 / 13,8 | 11,7 / 10,6 | 9,4 / 7,7 |

Quadros acima de 33 ms depois do começo: de 7 para 1.

**O que era, e como foi achado:**
- **A fumaça no chão.** A `FumacaNegra` custava 14,6 ms num quadro de 21 ms
  quando a lente desce para pegar o celular. A lente fica dentro dela, e cada
  pixel em 4K fazia 30 passos com 8 ruídos de hash por passo.
  - O ruído virou uma leitura de uma `ImageTexture3D` 32³ RGBA de sorteios, com
    o filtro linear do hardware no ponto remapeado pela curva suave. É o mesmo
    ruído de valor: medi 512² amostras e os quantis batem a 0,01.
  - A volta usa uma leitura só, com os três eixos nos canais g, b e a.
  - O número de passos segue o trecho do raio (`passo_min` 3,5 cm, de 8 a 30).
  - Resultado: 14,6 → 2,4 ms.
- **O pico de 81 ms aos 5,6 s**, quando o celular sobe. Cada `TelaDoCelular`
  duplicava as fontes MSDF, com o cache de glifos vazio. Agora:
  - as fontes são uma cópia só, estática (`_msdf`);
  - o app nasce antes do aquecimento;
  - `aquecer_letras()` escreve todas as letras e o lixo da pane debaixo do
    preto;
  - `MotoristaCena.aquecer_celular()` mostra o aparelho aceso nos quadros de
    aquecimento.
- **O pico de 33 ms na trava.** `AuraNegra.revoada` custava 19 ms: material
  novo compila, e o motor tira o shader do cache quando o último material
  morre, então a revoada de aquecimento jogada fora não adiantava. As duas
  revoadas agora nascem no aquecimento e ficam guardadas apagadas
  (`_revoada(i)`).
- **Auras acendendo juntas.** O `preprocess` de cada aura roda 96 passos de
  partícula num quadro só, e o padre com os cinco da janela davam 576.
  `_mostrar` agora enfileira, e `_acender_uma_aura()` acende uma por quadro.
- **Fogo do capô.** Entra no aquecimento com `IncendioDoCapo.aquecer()`, que
  acende tudo e apaga sem deixar partícula no ar.
- **Cortina no aquecimento.** `_aquecer_na_lente` fecha a cortina
  (`Cinema.fechar_de_imediato()`). Com `--estrada-desde=dentro` ela começava
  aberta, e os quatro quadros de aquecimento apareciam.

**Ferramentas novas** (todas em `abertura_estrada.gd`):
- `--sonda-gpu=S`: S segundos depois da batida a cena congela
  (`Engine.time_scale` 0,0001). Depois esconde por grupo e objeto por objeto,
  sempre pelas **camadas**, e mede contra o antes e o depois.
  - Imprime primeiro o **controle positivo** (sem nada). Se ele não cair, a
    medida não vale.
  - Com `--gpu-profile` antes do `--`, também imprime os passes do quadro.
- `--gpu-passos`, com `--gpu-profile` no motor: GPU por passe do renderer,
  somada por trecho.
- `[pico]`, com `--medir-quadros`: cada quadro acima de 20 ms, com a GPU, a
  física, os scripts (`MarcoDoQuadro`), a CPU de render e as partes da cena.
- `_custo_da_batida()` também marca o nascimento da multidão, do app do "?" e
  do fogo.

**O que sobra:**
1. Um quadro de ~35 ms aos 24,8 s (fogo), logo depois do app do "?" e de
   `_padre_na_janela`. O quadro seguinte tem 15 ms de GPU (as auras, agora uma
   por quadro, ainda 3,5–5 ms cada).
   - O pico não é de script (3 ms), nem de física, nem de CPU de render
     (0,7 ms).
   - Suspeita: a fila de quadros esperando a GPU, ou a religação dos Corpo que
     mudam de pai (padre e romeiros vão para `_carro`).
2. Picos soltos de 20–25 ms em toda a cena, até na conversa, onde nada
   acontece. Parece ruído de sistema; não perseguir.
3. `bracos` gasta 4,8 ms de CPU por quadro com as mãos do padre
   (`BracoVivo.refazer` remonta a malha inteira em GDScript). Hoje não limita,
   porque a GPU (9,4 ms) é maior, mas em máquina mais fraca pesa.

### 6.2 Coisas que eu vi e ele NÃO pediu (ofereça, não faça)

- Gotas do vidro lateral com cara de plástico-bolha: redondas, iguais,
  densas.
- Riscos pretos longos no ar nos planos de fora (06_romeiros).
- Quebra-sol com borda em escada.
- `tests/bancada_braco_chao.gd` chama funções que não existem mais
  (`alcancar_celular`, `derrubar_celular`): a bancada está quebrada.

## 7. Como validar cada coisa

- Rode a cena com fotos e rajada em 4K e mostre:
  - os mosaicos do trecho mexido;
  - os quadros cheios, com recortes no detalhe.
- Desempenho: sempre `--medir-quadros` **sem** captura, em par
  (antes/depois), com a GPU por trecho. Fale o nome da placa, que está na
  2ª linha do log.
- Diga os caminhos das imagens e o que cada uma prova.

# Handoff: abertura da estrada, etapas que faltam das críticas do trailer

Cole o bloco abaixo como primeira mensagem da nova sessão. Branch `playable`. A
tag `continuar/abertura-estrada-etapa3` marca o commit em que as etapas 1 e 2
fecharam. Depois dele o plano mudou (a etapa 2 é revista e entram vidros e
suspensão); este arquivo é a versão em vigor.

---

# Continuação: abertura da estrada (etapas que faltam das críticas do trailer)

Responda sempre em português. Faça commit só quando eu pedir.

## 1. Contexto

Jogo de terror em Godot 4.7.2, na pasta `game/`, com renderer Forward+ no estilo
MODERNO. A meta é **qualidade AAA em 4K**. O estilo PS1 é só um preset e não deve
ser forçado.

A cena em questão é a abertura na estrada, à noite e com chuva:
1. O personagem dirige lendo no celular a conversa do grupo.
2. Ele apaga a mensagem em que dizia que não ia, levanta os olhos e dá com o
   padre no farol.
3. O carro desvia e bate numa árvore; o celular vai ao chão e ele o pega.
4. Chegam mensagens "?", o padre aparece na janela e a tela fica branca.

Eu (o usuário) vi o trailer e fiz uma lista de críticas. Ela virou 9 etapas. **A
etapa 1 está pronta.** A 2 foi feita, mas o plano mudou e ela precisa ser revista.
Sua tarefa é fazer o que falta (a revisão da 2 e as etapas 3 a 9), uma por vez,
mostrando capturas de cada uma.

Antes de começar, leia:
- `C:\Users\Administrator\.claude\projects\c--Users-Administrator-Documents-Codes-Games-PSX\memory\MEMORY.md`
  (índice de lições do projeto);
- principalmente as memórias `etapas-do-trailer-da-estrada.md`,
  `movimento-se-julga-em-rajada.md`, `moderno-nao-e-psx-forcado.md`,
  `sessoes-paralelas-no-repo.md`, `duas-armadilhas-mudas-do-godot.md`,
  `vehiclebody3d-tem-quatro-armadilhas-mudas.md` e
  `camera-de-cabine-mede-se-do-volante.md`;
- `.claude/skills/godot-project`: como rodar o Godot.

## 2. O monitor é 4K: é assim que se julga

Meu monitor principal é 4K (a janela do jogo sai com 3840x2108). Captura em
qualidade maior é o que deixa ver o que falta para o jogo ficar polido e AAA: a
quina de malha, a textura borrada, a borda serrilhada, o efeito que pisca, a mão
atravessando objeto.

- Toda captura de validação é em **`--resolution 3840x2160`**. Não julgue nada
  por captura pequena.
- A leitura de imagem reduz o quadro inteiro para uns 2000 px de largura, então
  detalhe fino some. **Para julgar detalhe, recorte a região na resolução cheia**
  com PIL e leia o recorte:
  ```bash
  python -c "from PIL import Image; im=Image.open('<quadro 4K>.png'); im.crop((x0,y0,x1,y1)).save('<recorte>.png')"
  ```
  Recorte, por exemplo, as trincas do vidro, a água escorrendo, a lataria
  amassada, o fogo, as mãos do padre e o celular no chão.
- Use `--susto-cheio`, que grava quadros em resolução cheia além da rajada
  pequena: o mosaico serve para o movimento, e o quadro cheio para o acabamento.
- Compare antes e depois na mesma região e no mesmo tempo da cena.

## 3. Convivência no repositório

- A outra sessão **já terminou o trabalho no carro** (lataria, física, cabine,
  vidros). Você pode mexer nesses arquivos.
- Outras sessões ainda podem editar outras partes do repositório ao mesmo tempo.
  - Antes de editar um arquivo, rode `git diff` nele e veja se há trabalho alheio
    não commitado.
  - Se houver, não sobrescreva nem reverta: faça a mudança em cima.
- Arquivo que muda sozinho não é bug seu.
- Erros de parse em arquivos de outras frentes (`plantacao.gd`, estufa...) são
  trabalho alheio em andamento: ignore.
- "Class not declared" de classe nova alheia se resolve com `--import`.
- Os arquivos são LF.
  - Faça patches com `python - <<'EOF' ... EOF`, com o heredoc **sem nenhum
    acento** (acento quebra o shell), ou com as ferramentas Edit/Write.
  - Use `python`, não `python3`.

## 4. Comandos

```bash
G=.tools/Godot_v4.7.2-stable_win64_console.exe
S=<pasta de rascunho da sessão>

# depois de criar classe nova ou mudar shader
$G --headless --path game --import

# a cena inteira em 4K, com fotos por momento, rajada a cada 0,1 s e quadros cheios a cada 1 s
$G --path game --resolution 3840x2160 -- --ver-estrada --estrada-corrida --estrada-desde=dentro \
   --susto-fotos=$S/sNN --susto-rajada=$S/sNN/r --susto-cheio > $S/sNN.log 2>&1
grep "\[susto\]" $S/sNN.log        # tempos: conversa, trava, enviou, golpe, romeiros, batida, janela, branco
grep "SCRIPT ERROR" -A3 $S/sNN.log

# mosaico de um trecho da rajada (tempos da cena)
python tools/mosaico_rajada.py $S/sNN/r <t0> <t1> $S/saida.png [colunas] [n]

# bancada das mãos com o volante
$G --path game --resolution 3840x2160 res://tests/bancada_maos.tscn -- --estilo=moderno --saida=$S/u --estrada
```

- As flags do jogo vão **depois** do `--`.
- A cena leva cerca de 3 min; rode em segundo plano e espere a notificação.
- A marca "enviou" some quando a etapa 2 for revista.
- `--check-only` não enxerga autoloads (`RegistroCivil`, `Settings`), então o
  erro que ele acusa nesses nomes não prova nada.
- A cor da pele do personagem muda a cada rodada: não é bug.

## 5. Mapa do código

- **`game/src/levels/abertura_estrada.gd`**: o roteiro.
  - `_plano_dentro()` é a sequência inteira, com `await` por momento,
    `_marca("...")` para os tempos e `_foto("...")` para as capturas.
  - Batida: `_golpe_na_estrada()`, `_guiar_a_guinada()`, `_plantar_batida()`,
    `_bater()` (marca "batida"), `_trincar_por_dentro()`,
    `_escurecer_depois_da_batida()`.
  - Fumaça do chão: `_montar_fumaca()`, `_animar_fumaca()`, `_teto_da_fumaca()`.
  - Padre: `_plantar_padre()`, `_padre_na_janela()`, `_rosto_do_padre()`,
    `_capuz_padre` (olhos e sorriso), `_tique_de()` (TiqueMacabro: estalar a
    cabeça).
  - Final: `_branco` (`BrancoDoSusto`: `tocar()` e `estourar()`).
  - Som: `_som(&"nome", db, afinação)`.
  - Câmera: `_foco_de` (Callable que devolve o ponto mirado), `_foco_peso`,
    `_fov_cena`, `_debruca`, `_vira`, `_tremor`, animados com
    `_animar(&"prop", alvo, dur)`.
  - Há um comentário, perto de `_trincar_por_dentro`: "O vidro da cabine
    (`psx_vidro_agua`) não sabe trincar...".
- **`game/src/world/motorista_cena.gd`**: as mãos e o celular do personagem.
  - Mãos no aro: `_montar_mao_no_aro`, `pegada_para_o_cotovelo`.
  - Celular na mão: `_segurar_o_celular`, polegar com `teclar(uv)`,
    `segurar_tecla(uv)`, `repousar_em(uv)`, sinais `tecla_encostou` e
    `tecla_soltou`.
  - Depois da batida: `vibrar_celular`, `alcancar_celular`, `derrubar_celular`,
    `seguir_ao_chao`, `pegar_do_chao`, `erguer_celular`, `mostrar_celular`.
  - Os braços vivos são `BracoVivo` (`game/src/render/braco_vivo.gd`, shader de
    pele com unha).
- **Carro:**
  - `game/src/world/carro_cabine.gd`: interior. O volante é `VolanteEsportivo`
    (`game/src/render/volante_esportivo.gd`); os limpadores ficam em
    `limpadores()`.
  - As peças da cabine ficam em `game/src/render/cabine_*.gd` (casca, portas,
    painel, console, bancos, interior).
  - `game/src/world/carro.gd`: física, com a suspensão por `VehicleBody3D`, e a
    detecção de batida em `_sentir_batida()`.
  - `game/src/systems/motor_som.gd`: sons do carro (`bateu()` toca
    `batida_carro`).
  - `Carroceria`: a lataria.
- **Vidro e água:**
  - Shaders: `game/shaders/psx_vidro_agua.gdshader` (vidro da cabine, filme de
    água, gotas, embaçado), `psx_gota_corredora.gdshader` (gotas que escorrem),
    `psx_gota_lente.gdshader`.
  - Scripts: `game/src/render/vidro_cabine.gd`, `agua_corredoras.gd`,
    `gotas_lente.gd`.
  - Os dois primeiros shaders já ignoram, pela profundidade, o que está na frente
    do vidro na refração (`na_frente_do_vidro`). Mantenha isso: sem ela, o volante
    e as mãos vazavam como pontos coloridos nas gotas.
- **Celular:** `game/src/world/iphone_4s.gd` (aparelho 3D),
  `game/src/ui/tela_do_celular.gd` (SubViewport) e `game/src/ui/app_mensagens.gd`
  (a conversa: `travar_em`, `apertar_apagar`, `rascunho_vazio`, `enviar`,
  `receber`, `sem_teclado`, `zoom`).

## 6. O que já foi feito (não refazer)

1. **Unhas e volante esportivo** (camurça preta, faixa amarela, três raios com
   fenda, buzina). Cada mão tem ~2800 triângulos; o teto da bancada é 3200.
2. **Mensagem enviada com o celular na mão.** Feita, mas **o plano mudou**: veja
   a etapa 2 abaixo, que desfaz o envio.

## 7. Etapas que faltam (na ordem)

### Etapa 2 (revisão): ele não manda nada; só apaga, olha para a frente e dá com o padre

Decisão nova: o personagem **não digita nem manda "Gente, não vou"**. Ele apaga a
mensagem em que dizia que não ia, e quando levanta os olhos para a estrada dá de
cara com o padre.

- **Como está hoje:**
  - o polegar dá três toques no apagar e segura até sobrar "Gente, não vou"
    (`TRAVA_LETRAS` 14);
  - hesita e toca no ENVIAR (`MotoristaCena.ENVIAR_NA_MAO_UV`,
    `_mandar_a_mensagem`);
  - o balão sobe com "Entregue" e só então o padre é plantado.
- **Como deve ficar:**
  1. ele apaga a desculpa **inteira** (`app.travar_em(0)`; `rascunho_vazio()` diz
     quando o campo esvaziou), com o campo vazio e o cursor piscando;
  2. um respiro;
  3. o olhar sobe para o para-brisa e o padre já está no farol.
- **Nada é enviado.** Retire:
  - `_mandar_a_mensagem`, `_mandou`, `ENVIAR_HESITA`, `ENVIAR_LE`, `BALAO_MIRA`
    e o ramo do ENVIAR no `tecla_encostou`;
  - no `MotoristaCena`, `ENVIAR_NA_MAO_UV`;
  - `repousar_em` e `REPOUSO_DEPOIS_UV`, se não servirem mais. O polegar ainda
    precisa sair de cima do campo para a lente ver o campo vazio.
- **Revise tudo que dependia da mensagem enviada:**
  - o celular no chão lia "o balão azul e o Entregue" (`ASSOALHO_MIRA`,
    `ASSOALHO_ZOOM` e os comentários em volta);
  - os textos e comentários da conversa (`FALAS`, `TRAVA_LETRAS`);
  - a marca "enviou".
- **Pronto quando:** a rajada do "trava" ao "golpe" mostra o campo esvaziando, o
  campo vazio legível em 4K, o olhar subindo e o padre no farol, sem balão novo
  na conversa em nenhum momento da cena, inclusive no chão.

### Etapa 3: vidros maiores vistos de dentro

- De dentro do carro o vidro deve ser **um pouco maior**, para enxergar melhor o
  lado de fora:
  - para-brisa e janelas mais altos;
  - colunas e molduras menos grossas;
  - a cintura da porta e o painel sem tapar a estrada.
- **Por onde começar:**
  - a casca e as peças da cabine: `game/src/render/cabine_casca.gd`,
    `cabine_portas.gd`, `cabine_painel.gd`, `cabine_interior.gd`;
  - as medidas de `CarroCabine`: `PAINEL_TOPO`, `OLHO_DO_ASSOALHO`,
    `z_do_vidro()`.
- **Cuidados:**
  - o vidro da cabine precisa continuar casando com o vidro da lataria
    (`Carroceria`), senão o painel atravessa o vidro ou abre fresta;
  - para o olho do motorista e a câmera, veja a memória
    `camera-de-cabine-mede-se-do-volante.md`.
- **Pronto quando:**
  - um quadro 4K do plano de dentro, antes e depois, mostra mais estrada e mata
    pelos vidros;
  - o padre continua enquadrado no farol;
  - nada da cabine atravessa o vidro.

### Etapa 4: a suspensão pulando e o "PA PA PA"

O carro pula demais na suspensão nesta estrada. De fora, as rodas sobem e descem
sem parar. De dentro, cada pulo faz um estalo, "PA PA PA", muito ruim.

- **Suspeita forte, a confirmar por medida antes de mexer:**
  - em `game/src/world/carro.gd`, `_sentir_batida()` mede a perda de velocidade
    **em 3D, inclusive a vertical**;
  - com `BATIDA_MINIMA` 2,2 m/s e contato com o chão, cada ondulação que derruba
    a velocidade vertical vira "batida";
  - cada "batida" toca `_som.bateu()` (o som `batida_carro`, em
    `motor_som.gd`) e ainda chama `_amassar()` na lataria.
- **Como medir:** registre cada disparo, com a perda separada em horizontal e
  vertical e com o que o carro tocou.
- **A outra metade é a suspensão em si:**
  - rigidez, curso e amortecedores: `AMORTECE_COMPRESSAO`, `AMORTECE_RETORNO`,
    `ESTABILIZADORA` e `_ficha["curso"]`, por volta das linhas 200–215 e 790–800;
  - o casco batendo no fim do curso;
  - a própria estrada da cena, se o relevo dela for serrilhado.
- **Veja também** como o carro da abertura é conduzido (`--estrada-corrida`,
  `_carro.distancia`): a física dele pode diferir do carro jogável.
- **Cuidado:** não quebre o carro jogável da cidade. Ele acabou de ganhar
  amortecedor de verdade e barra estabilizadora (commit "Carro: pneu de rua,
  amortecedor de verdade...").
- **Pronto quando:**
  - de fora, as rodas acompanham a estrada sem pular;
  - de dentro, não há estalo nenhum com o carro rodando;
  - a batida de verdade, na árvore, continua tocando o estrondo e amassando.

### Etapa 5: batida com estrago de verdade

- A lataria amassa mais na batida contra a árvore: frente e capô deformados,
  farol quebrado ou apagando.
- **O vidro lateral trinca de forma realista:** trinca radial a partir do ponto
  de impacto, com teia de estilhaço, crescendo em alguns quadros e com refração e
  brilho nas rachaduras. Não serve um decalque parado.
- O para-brisa fica mais quebrado do que está hoje.
- **Água mais real escorrendo no vidro:** filetes que descem e se juntam, gotas
  que param e seguem, a água desviando pelas trincas.
- **Pronto quando:**
  - a rajada de ~0,5 s antes a ~3 s depois da "batida" mostra as trincas
    crescendo e a água escorrendo, sem piscar nem "Z-fight";
  - recortes 4K das trincas e da água resistem a um olhar de perto.

### Etapa 6: o celular caindo durante a batida

- O celular deve ir ao chão NA batida, com uma queda natural e cinematográfica
  vista pelo jogador. De preferência em física, ou com uma curva crível: quica no
  tapete e gira. Ele não deve pousar no banco e escorregar depois.
- Ajuste o trecho seguinte para ele já procurar o aparelho no chão. Hoje o
  celular vibra no banco e vêm `alcancar_celular`, `derrubar_celular` e
  `seguir_ao_chao`.
- `tocar_tela()` e `ENVIAR_UV` (do banco) já estão sem uso: apague.
- **Pronto quando:** o mosaico da batida até pegar o celular não mostra teleporte,
  mão atravessando objeto, aparelho flutuando nem braço tapando a lente.

### Etapa 7: gasolina, fumaça e fogo

- Segundos depois da batida:
  1. som de gasolina vazando (gotejar e escorrer, crescendo);
  2. fumaça saindo do capô ou do motor;
  3. depois fogo pegando, com luz tremulando dentro da cabine.
- Precisa ser visível pelo para-brisa e iluminar a cena, e não pode derrubar o
  FPS (veja a etapa 9).
- Encaixe no tempo entre a batida e a janela (hoje cerca de 18 s → 29 s).
- Se não houver sons prontos, veja como `_som` e `AudioDirector` carregam os
  áudios e procure no repositório. Não invente arquivo inexistente sem me avisar.

### Etapa 8: o final com o padre quebrando o vidro

- Depois do trabalho no vidro, no último instante antes do corte, o padre bate com
  as DUAS mãos no vidro e o quebra.
- A gente sente ele pegando o personagem com toda a força: mãos agarrando e um
  tranco na câmera.
- No instante em que o personagem começa a ser puxado para a frente, corta para a
  tela branca (`_branco`).
- Hoje, depois da marca "janela", o fim é: o sorriso, um bote do corpo, "tapa no
  vidro" e o branco.
- **Pronto quando:** o mosaico dos últimos ~2 s mostra as duas mãos, o vidro
  estourando, o puxão começando e o corte no quadro certo.

### Etapa 9: desempenho

- Trava muito e o FPS é baixo, principalmente na batida e na hora de pegar o
  celular no chão.
- **Meça antes de mexer:** registre o tempo por quadro e os picos por momento da
  cena, em 4K, que é a resolução em que eu jogo.
  - Meça **sem** `--susto-rajada`, `--susto-cheio` e `--susto-fotos`: a captura
    por `get_image` causa engasgo e falseia a medida.
  - Suspeitas comuns:
    - shader compilando na primeira vez que um efeito aparece (pré-aquecer);
    - partículas e fumaça;
    - o SubViewport da tela do celular;
    - a malha dos braços refeita a cada quadro;
    - luzes e sombras novas.
- Ataque quem aparece na medida e mostre os números antes e depois.

## 8. Como validar e entregar cada etapa

- Rode a cena em 4K e faça mosaicos da rajada no trecho mexido (movimento).
- Leia os quadros cheios de `r/cheio/` e **recortes em resolução cheia** das
  regiões mexidas (acabamento). Defeito de movimento aparece entre os momentos,
  não na foto de um só momento.
- Me diga os caminhos das imagens (quadros inteiros, recortes e mosaicos) e o que
  ficou pendente.
- Atualize a memória `etapas-do-trailer-da-estrada.md` ao fechar cada etapa,
  marcando como feita e com o que foi feito.
- Não faça commit.

# Handoff: gore do padre na janela do motorista

Cole o bloco abaixo como primeira mensagem de uma sessão nova.

---

# Continuação: gore do padre na janela do motorista (abertura da estrada)

Responda em português. Não faça commit. Seja direto: sem narrar espera, sem
inspecionar o trabalho do agente do capô.

## Escopo

**Só** o padre principal na janela do motorista: a mão no vidro, o sorriso, as
três cabeçadas, o rosto se destruindo, o olho saindo, o stare e o agarrão.

**Não toque em:**
- `cerco_no_carro.gd`, `escalador_do_carro.gd` e `bancada_cerco.gd`. O capô e
  os escaladores são de outro agente.
- O celular (`motorista_cena.gd`, `iphone_4s.gd`, `app_mensagens.gd`).
- `corpo.gd` e `capuz_macabro.gd`.

## O que já é verdade (não remapeie)

- **Roteiro:** está em `game/src/levels/abertura_estrada.gd`. São coroutines e
  Tweens, sem AnimationPlayer.
  - `_padre_cabeceia()` (l. ~1735) é a sequência inteira;
  - `_cabecada_vai(g)` e `_cabecada_bate(g)` (l. ~1986);
  - `_cabecada_gore(g)` (l. ~2161) cuida do dano do rosto, do esguicho e do
    hit stop;
  - `_soltar_o_olho()` (l. ~2194);
  - `_sangue_cai_com_o_vidro()` (l. ~2208);
  - `_encarar(dur)` (l. ~1908) é o stare de `CABECA_DENTRO = 2.0` s;
  - `_parar_o_tempo()` (l. ~2184) é o hit stop: `Engine.time_scale` 0,02 por
    `HIT_STOP = [0.035, 0.05, 0.075]` s;
  - `_preparar_sangue()` (l. ~2233) cria a lâmina de sangue, o `OlhoSolto`, o
    `GoreDeCabecada` e o parapeito.
- **Pose da cabeçada:** `game/src/levels/cabecada_do_padre.gd`
  (`CabecadaDoPadre`).
  - A cena anima `encara`, `recua`, `bote`, `distancia` e `tombo`.
  - O corpo anda na normal do vidro até a testa ficar a `distancia` do plano.
    É chamado em `_assombrar` depois do tique.
  - `prender_pano()` põe o vidro como colisor do capuz: uma esfera de 14 m do
    lado de dentro, movida a cada quadro, que some com `vidro_existe = false`.
  - `ENCARA_MAX = 0.95` limita o giro do pescoço.
- **Sangue no vidro:** `game/src/render/sangue_no_vidro.gd` e
  `game/shaders/sangue_vidro.gdshader`.
  - É uma lâmina no contorno da janela, filha da cabine, 2,5 mm para fora do
    vidro, e desenha o atlas assado.
  - `quebrar()` faz a lâmina morrer no quadro do estouro. Antes, `_escrever()`
    religava `visible` e o respingo ficava flutuando no ar.
  - Na quebra, `GoreDeCabecada.do_vidro` joga as gotas das marcas junto com os
    cacos.
- **Rosto:** `game/src/render/cabeca_do_padre.gd` (arquivo não rastreado da
  frente dos monstros; editado aqui).
  - `por_sangue(p)`: o sangue projetado de frente.
  - `por_dano(0..3)`:
    - amassados reais no vértice (`AMASSO` e `AMASSOS`: nariz, testa, meio da
      cara, órbita esquerda, maxilar);
    - camadas de ferida no fragmento (músculo, gordura, osso, talhos, coágulo);
    - relevo por derivada.
  - `olho_esquerdo()` e `por_orbita_vazia(v)`.
  - `OlhoE` e `OlhoD` são esferas. O `OlhoE` tem material próprio (`arrancado`).
- **Olho solto:** `game/src/render/olho_solto.gd`.
  - O nervo é uma corrente de Verlet que estica até 7,5 cm.
  - Os fios de muco arrebentam entre 8 e 16 quadros.
  - Há gotas saindo da órbita e do globo.
- **Partículas:** `game/src/render/gore_de_cabecada.gd` tem o esguicho, os
  pedaços, os coágulos, o sangue do vidro, os pingos do queixo e a caixa de
  colisão do parapeito.
- **Colisor movível:** `game/src/render/pano_gpu.gd` ganhou `colisor()`
  devolvendo o índice e `mover_colisor()`. São três linhas.
- **Geradores** (rodar depois de mexer na forma; `--import` depois):
  - `tools/gerar_sangue_vidro.py [--previa DIR]` gera, em
    `game/assets/monstros/sangue/`:
    - `vidro_sangue.png` (atlas 4K);
    - `rosto_sangue.png` e `rosto_gore.png` (2048×4096). A lista `CORTES` diz
      em que golpe cada talho abre.
  - `tools/gerar_audio_cabecada.py [nomes]`: os sons de cabeçada, tensão e gore
    (44,1 kHz).

## Estado dos testes

**v02 (qualidade 2/10).**
- **Impacto no vidro:** ok. O capuz não fura mais o vidro nos golpes. O
  sangue e a teia estão bons.
- **Stare ruim:**
  - (a) a ferida sai preta-azulada, com o clearcoat espelhando o céu e brilho
    de purpurina;
  - (b) o nervo do olho parece um palito;
  - (c) gotas ficam paradas no ar.
- **Relance ao capô:** mirou o teto porque o padre do capô ainda escalava.
  Agora tem guarda (só vira se o rosto estiver na frente do motorista e abaixo
  do teto). O capô em si é do outro agente.

**Correções aplicadas depois da v02, ainda NÃO validadas.**

A rodada `v03` foi lançada e interrompida sem leitura. Os arquivos dela estão
na pasta de rascunho da sessão anterior. Refaça.
- **(a) Ferida:**
  - os uniformes de carne estão em sRGB claro (antes davam quase preto);
  - o amassado ficou vermelho-escuro, e não roxo;
  - o relevo agora vem só da fibra e da mancha, sem a racha de 4K;
  - na ferida a normal volta à da malha;
  - specular 0,32, roughness 0,2, clearcoat 0,3.
- **(b) Nervo:** raio de 3,4 mm, mais gordo junto à órbita, cor rosa-carne, sem
  clearcoat.
- **(c) Gotas no ar:** a caixa do parapeito ficava em pé atravessando a janela,
  porque a "frente" era tirada da aresta vertical do contorno. Agora ela vem de
  `pontos` e é horizontal. Um print `[padre] parapeito em ...` no log confirma.
  As gotas ficaram mais curtas (conta, e não cone).
- **Queixo:** `QUEIXO_BOTE` foi de -0,62 para -0,48. Com -0,62 o golpe mostrava
  o cocuruto em vez da cara.

## Próximo passo (só isto)

1. Rodar uma rajada POV de dentro:

   ```bash
   G=.tools/Godot_v4.7.2-stable_win64_console.exe
   S=<rascunho>/v04
   $G --path game --resolution 3840x2160 -- --ver-estrada --estrada-corrida --estrada-desde=dentro \
      --susto-fotos=$S --susto-rajada=$S/r --susto-cheio > $S.log 2>&1
   grep "\[susto\]\|\[padre\]" $S.log     # cabecada1..3, estoura, encara, branco
   python tools/mosaico_rajada.py $S/r <janela-0.3> <branco> <saida.png> 8 64
   ```

   Fotos 4K prontas:
   - `10d_cabecada1`, `10d_cabecada2`, `10g_esfarela`;
   - `10h_dentro` (quebra +3);
   - `10h_encara_0`, `10h_encara_1` e `10h_encara_2` (stare 0, 1 e 2 s).

   Recorte em resolução cheia com PIL.
2. Julgar e corrigir **só** (a), (b) e (c), e confirmar:
   - o capuz não fura o vidro;
   - o sangue do vidro some na quebra;
   - o rosto piora do hit 1 ao 3;
   - o `OlhoE` descola no hit 3;
   - o stare dura 2,0 s olhando para a lente.
3. Mosaico, e PARA.

## Regras

- Os `.gd` estão em CRLF no working tree. Ao patchear com Python, leia normal e
  grave com `newline='\r\n'` nos arquivos que já eram CRLF: `abertura_estrada.gd`
  e `cabeca_do_padre.gd`. Os arquivos novos são LF.
- Classe, shader ou som novo pede `--import` antes de rodar.
- Salvar `.gd` com uma rodada carregando mata a rodada; se o log sair só com o
  cabeçalho, rode de novo.
- `abertura_estrada.gd` tem WIP de outras frentes (Partes 1 a 4 dos monstros).
  Edite por cima, sem reverter.
- Julgue em 4K e por rajada. Memórias úteis: `movimento-se-julga-em-rajada`,
  `seja-direto` e `sessoes-paralelas-no-repo`.
- Use `python`, não `python3`. Heredoc do bash sem acento; para Python com aspas
  triplas, escreva o script com a ferramenta Write.

# Plano Bar e Cidade AAA

**Pedido (24/09/2026):** levantar o que prédios, casas e bares precisam. No bar: cadeiras feias e viradas para o lado errado, mesas feias e mal colocadas, gente sentada no chão, salgados feios (usar os do mercado), prateleira com produtos em imagem (usar os produtos do mercado). A sinuca tem de funcionar, dar para jogar, e a mesa tem de ser bonita. Mercado e casa da fumaça ficam fora.

**Provas:** capturas de hoje em `captures/bar_aaa/antes/` (8 do Bar do Seu Zé, 4 da cidade). Bar do Seu Zé mais perto da origem: chunk (-9, 9). Linha de base do `tools/verificar_bar.py`: **já falha** com 27.972 triângulos no chunk (teto de 24.000). O peso vem de `cabo` 3.320, `reboco` 2.931, `metal` 2.646 e `vegetacao` 1.864; as cadeiras (`bar_cadeira`) somam 1.008.

## 1. Diagnóstico do bar (código e captura)

| # | Defeito | Causa | Onde |
|---|---|---|---|
| B1 | Cadeiras de costas para a mesa | A cadeira fica em ±x da mesa com giro de ±90°, e o encosto (local −z) cai **entre** a cadeira e a mesa | `KitBar.cadeira` e as chamadas em `salao` e `mesas_da_calcada` |
| B2 | Cadeira de caixa | Assento, duas chapas de pé e um encosto, todos como caixa. Lê como cubo amarelo | `KitBar.cadeira` |
| B3 | Mesa de caixa, mal distribuída | Tampo quadrado com um pé central. Quatro mesas amontoadas à esquerda, uma sem cadeira ("quem assiste senta no chão"). Na calçada há 3 cadeiras por mesa, todas viradas para fora | `KitBar.mesa`, `salao`, `mesas_da_calcada` |
| B4 | Gente sentada no chão | Os clientes da TV usam o papel `SENTADO` (pernas cruzadas no chão). O prop nunca passa `assento`, e o `Convidado` só senta na cadeira com `altura_assento > 0` | `KitBar._gente` |
| B5 | Cliente em pé dentro da banqueta | O cliente do balcão está `LIVRE` e é plantado **no ponto da banqueta**, sem `assento` | `KitBar._gente` |
| B6 | Cliente olhando para o nada | O `foco` sai em coordenada **local do chunk**, e o `ChunkManager` não converte para o mundo (os `pontos` ele converte). Isso vale para todo convidado de rua, não só para o bar | `ChunkManager._criar_convidado` |
| B7 | Salgados em textura | `vitrine_salgados` é uma caixa com a textura `bar_salgados`. O mercado já tem a estufa com coxinha, pão de queijo e pastel modelados | `KitBar.vitrine_salgados` → `KitSalao.estufa` |
| B8 | Cervejeira com produto pintado | A porta é uma placa com a textura `bar_cervejeira` (garrafas desenhadas + dither). O mercado tem produto 3D com o rótulo real no atlas | `KitBar.cervejeira` → `ProdutoMalhas` + `RotulosAtlas` |
| B9 | Prateleira de "garrafas" em caixa colorida | 3 prateleiras de cubinhos coloridos atrás do balcão | `KitBar.prateleira_garrafas` |
| B10 | Sinuca de enfeite | Tampo, 4 tabelas de caixa, bolas em cubo de 5 cm, taco em caixa. Não joga | `KitBar.sinuca` |
| B11 | Miudeza em caixa | Copo, garrafa, cinzeiro, pendente, coifa flutuando e caixa de som, tudo em caixa | `KitBar` (várias) |
| B12 | Guarda-sol chapado | Copa em caixa de 5 cm, sem varetas | `KitBar.guarda_sol` |
| B13 | Captura do bar quebrada | `--ver-bar` só procurava num raio de 9 chunks, e o bar mais perto está no anel 9 | `cidade._ir_para_o_bar` (**corrigido** nesta sessão, raio 16) |
| B14 | Bares da `BarVivo` fora do mapa | Só o Seu Zé é ponto de interesse | `PLANO_CASAS_AAA` 2e |

## 2. Diagnóstico da cidade (capturas de hoje)

| # | Defeito | Onde se vê |
|---|---|---|
| C1 | Térreo comercial todo de porta de enrolar **fechada**: a rua comercial lê como domingo | `cidade_rua_comercial.png` |
| C2 | Placa branca acesa sem desenho na porta de entrada do prédio (parece um marcador de depuração) | `cidade_rua_comercial.png` |
| C3 | Degrau de soleira saindo como bloco na calçada, em cada porta de enrolar | `cidade_rua_comercial.png` |
| C4 | Casa com parede grande lisa e poucas janelas pequenas, sem cimalha, frisos ou rodapé | `cidade_rua_residencial.png` |
| C5 | Muro de arrimo em bloco de pedra enorme: a textura na escala errada lê como Lego | `cidade_avenida.png`, `cidade_cruzamento.png` |
| C6 | Andar de cima do bar: parede cinza lisa com duas janelas | `bar_rua.png` |
| C7 | Parada `rua_estreita` da rota `dia_seco` fotografa um muro de tijolo (a malha mudou) | rota `dia_seco` |
| C8 | Pendências do `PLANO_CASAS_AAA` ainda abertas: letreiro aceso à noite (F3), empena cega (F4), porão progressivo (F5), desgaste no shader (F7), noite (F8), bancada de casas (F9) | plano das casas |

## 3. Fases

### Fase 1: móveis, gente e produtos do bar (B1–B9, B11)

1. **Cadeira monobloco modelada:** assento côncavo, 4 pernas abertas, encosto vazado com curva. Molde montado uma vez por salão e copiado por cadeira. **Sempre de frente para a mesa.**
2. **Mesa plástica modelada:** tampo de canto arredondado com aba, 4 pernas. Toalha xadrez em parte delas.
3. **Planta nova do salão:** mesas em fileira na metade livre (TV à esquerda, balcão à direita), 4 cadeiras por mesa, corredor livre da boca ao fundo. Na calçada, 2 mesas de cada lado da boca, com 2 a 3 cadeiras voltadas para a mesa.
4. **Gente na cadeira:** clientes sentados nas cadeiras reais (`assento` = altura do assento), olhando para a mesa ou para a TV. O cliente do balcão sentado na banqueta. O `foco` passa a ser convertido para o mundo no `ChunkManager` (B6).
5. **Salgados do mercado:** `KitSalao.estufa` no lugar da caixa texturizada.
6. **Produtos do mercado:** a cervejeira ganha vidro de verdade, prateleiras e latas e garrafas 3D com rótulo do atlas (cerveja, refrigerante, 600 ml). A prateleira atrás do balcão ganha cachaça, destilados e maços. Nó novo `ProdutosDoBar` (MultiMesh por forma, o mesmo material do mercado).
7. **Miudeza redonda:** copo americano, garrafa de 600 e cinzeiro com `Peca`.
8. **Aceite:** `verificar_bar` sem regressão no que é do bar (mesas, gente, caminho livre), o custo do salão medido antes e depois, e capturas `salao`, `tv`, `balcao`, `boca`, `calcada`, `de_dentro` comparadas com `antes/`.

#### Estado da Fase 1 (24/09, feita, sem commit)

Capturas em `captures/bar_aaa/depois_f1/`, para comparar com `antes/`.

**Arquivos novos:**
- `src/world/moveis_do_bar.gd` (`MoveisDoBar`): moldes de cadeira monobloco com braço, mesa de plástico, toalha, banqueta redonda, copo americano com cerveja, cinzeiro, cúpula esmaltada e a estufa do `KitSalao`. Cada molde é montado uma vez, sob trava, e copiado por `acumular`.
- `src/world/produtos_do_bar.gd` (`ProdutosDoBar`): MultiMesh por forma com a malha e o rótulo do mercado. Os itens vão relativos ao `pos` do prop, porque o relevo só move essa chave.
- Material `bar_monobloco` e `bar_monobloco_mesa`, com a textura neutra `bar_monobloco.png`. A cor da cadeira vem do vértice.

**Ligações em arquivos que já existiam:**
- `KitBar`: planta nova (`salao`, `mesas_da_calcada`, `_mesa_posta`, `_gente`, `_sentar`), cervejeira de vidro, prateleira com produtos e pendente redondo. `KitBar.cadeira` e `banqueta` antigas ficam para a casa da fumaça.
- `ChunkManager`: prop `produtos`, e o `foco` do convidado de rua convertido para o mundo (B6).
- `ChunkBuilder`: a calçada do bar recebe `props`.
- `cidade.gd`: `--ver-bar` procura em 16 anéis.
- `teste_bar.gd`: materiais novos, contagem de mesas pelo molde, `ms_construir_bar` e `ms_salao`.

**Medidas no chunk do Seu Zé (-9, 9):**

| Medida | Antes | Depois |
|---|---|---|
| Mesas | 7 | 6 (4 na calçada, 2 no salão, porque a sinuca ocupa o fundo) |
| Pessoas | 6 (2 no chão) | 9, todas na cadeira ou em pé no lugar certo |
| Caminho da calçada ao fundo | livre | livre |
| Triângulos do chunk | 27.972 (já acima do teto de 24.000) | 33.490 (cadeiras 3.240, salgados 1.536 no balde `@perto`) |
| Montar o bar sozinho (média de 5) | — | 7,1 a 7,8 ms |
| Montar o pior chunk de bar | — | 68 a 73 ms |

**Pendente de decisão:** o teto de triângulos do chunk do bar (24.000). O `verificar_bar` só reprova nisso, e já reprovava antes da Fase 1 (fiação, reboco e vegetação).

### Fase 2: sinuca jogável e mesa AAA (B10)

- **Mesa modelada:** tabelas com perfil de borracha, 6 caçapas com boca de couro e rede, diamantes, saia de madeira, pés torneados e luminária de 3 cúpulas. Taco no suporte de parede.
- **Física própria (`FisicaSinuca`)**, determinística e em passo fixo, com as equações do *pooltool* (Evan Kiefl):
  - estados deslizando, rolando, girando e parado, com atrito de deslize μs ≈ 0,2, de rolamento μr ≈ 0,01 e de giro;
  - bola contra bola elástica, com e ≈ 0,95;
  - bola contra tabela no modelo de Han (2005), com e ≈ 0,85 e a altura do nariz da tabela;
  - tacada de ponto instantâneo, com V0, ângulo, elevação e ponto de contato (efeito lateral, puxada e seguida).
  - O motor de física do Godot fica de fora: não segura rolamento nem efeito, e não repete a mesma tacada.
- **Jogo:** [E] na mesa, câmera por cima do taco, mira com o mouse, força puxando o taco, efeito na bola branca, linha-guia curta, regras de bola 8 (lisas e listradas), falta, bola na mão.
- **Adversário NPC:** escolhe a tacada mais fácil com erro pela habilidade. Aposta de fichas opcional.
- **Som:** batida, tabela e caçapa.
- **Aceite:** bancada headless de física (conservação, quebra que espalha, bola que rola até parar, tabela em 45°) e partida inteira contra o NPC na captura.

#### Estado da Fase 2 (24/09, feita, sem commit)

**Arquivos novos, em `src/world/sinuca/`:**
- `mesa_sinuca.gd` (`MesaSinuca`): medidas de mesa de bar de 7 pés, com área de jogo de 1,98 × 0,99 m e bola de 57,15 mm. Também a geometria que a física usa: nariz das tabelas, bochechas das caçapas, seis caçapas e o triângulo. É puro, sem dependência de autoload.
- `desenho_sinuca.gd` (`DesenhoSinuca`): o molde da mesa. Tem pano e tábua de mogno recortados em arco nas caçapas, borracha com bochecha a 45°, copo de couro, diamantes de madrepérola, saia, pés torneados e luminária de 3 cúpulas.
- `fisica_sinuca.gd` (`FisicaSinuca`): as equações do pooltool, a 600 Hz.
  - Estados analíticos com troca no instante exato.
  - Choque bola-bola rebobinado até o contato.
  - Tabela pelo modelo de Han (2005).
  - Tacada com massa do taco, efeito, puxada, seguida e desvio (squirt).
  - Raio para a linha-guia e para a IA.
- `regras_sinuca.gd` (`RegrasSinuca`): bola 8 de bar.
  - Mesa aberta, grupos, bola na mão e a 8 recolocada na quebra.
  - Faltas: não tocar em bola, tocar primeiro na bola errada, nenhuma bola na tabela e a branca na caçapa.
- `cerebro_sinuca.gd` (`CerebroSinuca`): o adversário.
  - Mira pela bola fantasma e confere o caminho livre.
  - Corte, força pela distância e erro pela habilidade.
  - Bola na mão atrás da tacada.
- `jogo_sinuca.gd` (`JogoSinuca`): o prop do chunk, que se joga com [E].
  - Câmera própria: mira atrás da branca, vista da jogada abaixo das cúpulas e vista de cima com [C].
  - Taco animado, linha-guia com bola fantasma, 16 bolas em MultiMesh girando pelo giro de verdade e queda na caçapa.
  - Sons e adversário que mira devagar.
  - Parado, não processa nada.
- `painel_sinuca.gd` (`PainelSinuca`): placar com as bolas de cada grupo, indicador de efeito, barra de força e recados.
- Arte e som:
  - `tools/gerar_bolas_sinuca.py`: atlas equirretangular com o número projetado no plano tangente, 128 px por célula no PS1 e 512 no HD.
  - `mat_bar_sinuca_bola.tres`.
  - `tools/gerar_audio_sinuca.py`: bola, tabela, caçapa e taco.
- Réguas:
  - `tests/bancada_sinuca.gd`, headless.
  - `tools/verificar_sinuca.py`: a bancada mais uma partida demo com `--sinuca-demo`, `--sinuca-fotos=DIR` e `--sinuca-sair`.

**Ligações:** `KitBar.salao` troca a mesa de caixa pela `DesenhoSinuca` e cria o prop `sinuca`; `ChunkManager` cria o `JogoSinuca`.

**Medidas:**

| Critério da bancada | Resultado |
|---|---|
| Rolamento contra a conta fechada | erro de 0,016 mm |
| Choque de frente: fração da velocidade que passa | 0,975 (esperado (1+e)/2 = 0,975) |
| Corte de 30°: ângulo entre as duas bolas | 87,5° |
| Tabela a 45°: fração da normal devolvida | 0,77 |
| Quebra | para em 5 a 7 s, determinista, 0 sobrepostas, 0 fora |
| Custo da física | 16 a 18 ms de CPU por segundo simulado, cerca de 0,3 ms por quadro enquanto as bolas andam |
| Partida IA contra IA, headless | termina em cerca de 30 tacadas |

| Critério no jogo | Resultado |
|---|---|
| Partida inteira IA contra IA na mesa do Seu Zé (`--sinuca-demo`) | termina com vencedor em 33 tacadas e 2 faltas, sem erro de script |
| Caminho humano pela entrada real (`--sinuca-humano`, eventos injetados) | branca na mão, clique, mira, segurar e puxar, soltar, tacada, vez passa, Esc sai |

No chunk do bar, a mesa modelada e o porta-tacos somam cerca de 2.150 triângulos (35.642 no total). As bolas somam 3.600 triângulos numa chamada de desenho e somem a 22 m. Parada, a mesa não processa nada. Fotos em `captures/bar_aaa/sinuca/`.

**Fica para depois:**
- A partida é local: em rede, os outros jogadores não veem as bolas.
- O adversário não anda até a mesa nem segura o taco.
- Não há aposta.

### Fase 3: bar vivo

- Atendente que serve. Pedir cerveja ou salgado no balcão, pelo mesmo caixa do mercado (`VendaDaLoja`).
- Cliente que bebe, brinda e levanta. TV com luz azulada no salão.
- Bares da `BarVivo` no mapa e no GPS (B14).
- Noite: letreiro aceso, luz vazando para a calçada, guarda-sol modelado (B12).

#### Estado da Fase 3 (24/09, feita, sem commit)

Classes novas em `game/src/world/bar/`:

- `Gole` (herda de `Tragada`): o relógio de quem bebe. Gole, golão de cabeça para trás e brinde. O `Corpo` leva a mão à boca por IK como na tragada; `convidado.gd` e `corpo.gd` não foram tocados.
- `VidaDoBar` (prop `vida_bar`, um no salão e um na calçada): acha quem sentou em cada assento e dá copo e `Gole`. O copo é posto a cada quadro: em pé na mão pousada no tampo (`Corpo.agarrar`), inclinado com a borda nos lábios no gole, e no brinde as duas mãos vão ao meio da mesa e os copos se tocam, com o tim-tim no quadro da batida. A mesa conversa: um fala (voz e boca da `Fala`), os outros olham, há gesto e risada. Gol na TV (`PartidaPS2.estado`): uns levantam os braços, outros põem a mão na cabeça, alguém grita. Quem atende faz ronda atrás do balcão e troca fala com o cliente da banqueta.
- `VendaDoBar`: o cardápio de quem atende (contexto `&"bar"` na `FalasNpc`). Cerveja R$ 2, pinga R$ 1, coxinha R$ 2, torresmo R$ 3, guaraná R$ 1, "pendura na conta?" e a conversa de sempre.
- Serviço: pedido pago não vai para a mochila. Quem atende anda (pelos próprios pés: `pontos` + `liberar`) até a fonte. A cerveja e o guaraná saem do freezer debaixo do balcão (abaixa, som da geladeira), a pinga da prateleira e a coxinha e o torresmo da estufa. Depois anda até a altura de quem pediu e pousa na fórmica. `PedidoNoBalcao`: a 600 com o rótulo do mercado e o copo, a dose no copinho ou o pires com o salgado. [E] pega.
- `BaresDaCidade` (B14): o bar da `BarVivo` se anuncia ao mapa, ao radar e ao GPS quando o chunk dele é montado (prop `ponto_bar`). Não entra em `pontos_de_interesse`, que é pura e a rede conta com isso. O lote do bar sai do sorteio da fileira, então só montando o chunk se sabe onde ele fica.

Outras mudanças:

- Guarda-sol modelado (B12): 8 gomos com as duas cores do toldo de cada bar, babado, varetas e mastro. São 260 triângulos (antes, uma placa e quatro abas).
- Correção: na ladeira, o chão da quadra atravessava o piso do salão, e o Bar do Tião (-2,-2) era grama. Os dois bares agora passam `rebaixo`/`rebaixo_y` como os lotes comuns (`ChunkBuilder._rebaixo_do_bar`).
- Quem senta no bar bebe. Os dois fumantes sentados deixaram de fumar; quem fuma é o da sinuca, em pé.
- Itens `cerveja` e `pinga` (ícones em `tools/gerar_itens_do_bar.py`). Sons `copo_brinde`, `garrafa_balcao` e `pires_balcao` (`tools/gerar_audio_bar.py`).
- A TV com luz e partida já existia (`Televisao`), e a lâmpada do toldo já esquenta a calçada à noite.

Medidas (`python tools/verificar_bar.py`, e `--bar-vivo` para o Bar do Tião):

- 6 copos na mão e 5 a 7 goles em 16 s. O brinde sai.
- Cerveja cobrada (R$ 2) e servida em 2,7 s, pousada a 1,13 m (o tampo) e a 0,47 m do cliente.
- Coxinha pedida do fundo do balcão servida em 6,7 s, com o atendente andando até a estufa.
- Custo com o jogador dentro: cerca de 40 µs por quadro mais 99 µs por tique de 0,2 s, os dois diretores juntos. Longe (> 30 m) o tique volta na primeira linha e os copos somem.
- Fotos com `--bar-fotos=DIR`.

Pendências:

- Cliente que levanta e circula: pede o `Convidado` saber sair da postura de assento e contornar a cadeira, e `convidado.gd` tem trabalho de outra sessão.
- ~~Letreiro luminoso dos bares da `BarVivo`~~: engano, a placa já acende (ver Fase 4, parte 2).
- O teto de triângulos do chunk: 36.082 (os guarda-sóis somaram 440).
- Em rede, brinde e serviço são locais; o pedido é pago só na máquina de quem pediu.

### Fase 4: prédios e casas (C1–C8)

- Térreo comercial com metade das lojas abertas ou meio abertas e vitrine acesa (C1). Tirar a placa branca (C2). Soleira rente à calçada (C3).
- Fachada residencial: densidade de janelas por metro de parede, cimalha, friso, rodapé e pingadeira (C4).
- Muro de arrimo com a escala da pedra corrigida e capa (C5). Andar de cima do bar com janela e sacada, como o sobrado vizinho (C6).
- Atualizar a parada `rua_estreita` (C7) e fechar as pendências F3–F9 do `PLANO_CASAS_AAA` (C8).

#### Estado da Fase 4, parte 1 (24/09, sem commit)

**Pedido do usuário:** "o prédio que fica junto ao bar sempre fica com as janelas piscando". Mais um ajuste no balcão: a ripa de madeira elevada cortava o braço do cliente da banqueta.

**Régua nova: `tests/bancada_coplanar.tscn`.** Varre chunks montados por `ChunkBuilder.construir` e acha todo par de triângulos que ocupa o mesmo plano, virado para o mesmo lado, e se sobrepõe. Mede a área com recorte Sutherland-Hodgman. Depois testa se o par aparece: cinco raios saem da sobreposição, com os oito chunks vizinhos no corpo de raio. Um raio fecha se bate no verso de uma face, se bate em algo a menos de 25 cm ou se bate num cômodo de janela, que é só diorama. Cada peça é nomeada pelo material e pela cor de vértice.
- `--raio=N`, `--coords=cx,cz;...`, `--caixas`, `--filtro=`, `--peca=#cor`.
- A normal segue o sentido horário do Godot, não a regra da mão direita.

**O pisca do bar.** Em `_predio_do_bar`, cada janela de cima era um quad no plano exato da fachada: 62 pares nos dois bares.
- O andar de cima agora sai pela `ComercioVivo`: sobrado ou prédio, janela de vão com folha e floreira, balcão, friso e platibanda.
- A `ComercioVivo.fachada` ganhou `terreo_vazado`: um vão da largura toda sobre o salão do KitBar. Ganhou também `letreiro`: a janela do primeiro andar sobe acima da placa e não leva balcão ali.
- O sorteio do chunk anda o mesmo tanto que antes (`_sorteio_da_fachada_antiga`), para o resto do quarteirão sair igual.
- A casca do salão, o pilar e o forro coincidiam com a lateral da massa na faixa de 3,00 a 3,26 m. Agora a massa começa no topo do forro (`KitBar.ALTURA_CASCA`), o forro fica entre as paredes e o pilar entra 1 cm.
- A rajada lateral de 30 posições de câmera não mostra pisca.

**Balcão:** o peitoril elevado de 6 cm saiu. O antebraço do cliente passa sobre a fórmica.

**O resto da cidade, pela régua.** Área de sobreposição à vista nos 81 chunks em volta da praça: **784 → 435 m²**.

| Origem | Área à vista | Conserto |
|---|---|---|
| Poste DT: rebaixo escuro a 3 mm da face | 290 m² | 8 mm (`KitRede._corpo`) |
| Peitoril de pedra da janela: topo no plano do fundo do vão | 72 m² | só para fora da parede |
| Cômodos de janelas vizinhas se cruzando 30 cm; o de baixo subindo 28 cm no de cima | ~90 m² | largura até metade da parede livre, forro abaixo do andar de cima; mobília refeita pela largura (cama de solteiro, bancada menor) |
| Barra escura do muro do depósito com o verso no plano do verso do muro | 27 m² | centrada no muro |
| Peitoril sob a porta do balcão, no plano da laje do balcão | parte dos 16 m² | sem peitoril quando há balcão |
| Piso e forro da loja (`KitLoja`) na face de fora da parede | 14 m² | entre as paredes |
| Grade do condensador a 2 mm da caixa | 16 m² | 6 mm |

A `bancada_janela_viva` continua OK em todo estado e direção.

**C2, a "placa branca acesa":** era a máquina de venda, um quad com textura de ladrilho de calçada e emissão 2,0. Agora é a `MaquinaDeVenda` (arquivo novo):
- casco na cor da marca e faixa acesa;
- vitrine com cinco grades de lata com rótulo do mercado (`ProdutosDoBar`);
- painel de moedas e gaveta.

**C5, a pedra de Lego:** o embasamento da ladeira, a capa dele e o do miolo de quadra usavam o calçamento da praça em pé, com repetição de 2,1 m. Agora usam `mat_pedra_embasamento`: pedra de mão de 25 a 45 cm, gerada por `tools/gerar_pedra_hd.py` com Voronoi toroidal ponderado e distorcido, com conjunto HD (albedo, normal e rugosidade) e versão PS1. O material entrou na tabela do `gerar_materiais.py` e na molhabilidade da `EstiloVisual`.

**Rota de fotos: `--teste-fachadas --fachadas-fotos=DIR`** (`TesteFachadas`). Fotografa a face mais longa de N chunks comerciais e N de casa, de frente e de viés.

**Medidas:**
- `verificar_bar`: tudo passa, menos o teto de triângulos (37.934; era 36.082).
- `verificar_cidade`: falha só nas 4 portas do mercado de antes e no teto (pior chunk: o do Bar do Tião, 32.470).

Capturas em `captures/bar_aaa/fase4/`.

#### Estado da Fase 4, parte 2 (25/09, sem commit)

**Porão progressivo (F5, e o resto do C5): `PoraoVivo`** (arquivo novo, chamado pela `FachadaViva.residencia` e pela `ComercioVivo.fachada`; `--sem-porao` desliga). Onde a calçada fica abaixo do piso, o embasamento da frente ganha, pela altura de pedra à vista:
- a partir de 0,55 m, a gateira;
- a partir de 1,7 m, a janela de porão gradeada;
- a partir de 2,35 m, uma porta de porão de madeira rente à calçada, no ponto mais baixo.

As peças vão sob as janelas do térreo e, na parede cega, a cada 2,4 m, sempre fora da porta, da garagem, da loja e da escada de encosto. A moldura é de cantaria e sai 3 cm da pedra. O fundo escuro fica a 1,2 cm e o ferro é claro o bastante para ler contra ele. O porão dos fundos (`ChunkBuilder._porao`) usa as mesmas peças; antes eram placas de textura chapadas. Custo: +432 triângulos no pior chunk de loja.

**C3, degrau na frente da porta de aço:** a `ComercioVivo` só põe porta de aço de depósito ou garagem onde a calçada encontra o piso (±20 cm), como a garagem da `FachadaViva`. No resto entra a janela de grade da casa, alta na ladeira, com o porão embaixo.

**F8, noite:** metade das salas com janela aberta têm a TV ligada, com tela azulada (`mercado_luz` com a cor no vértice), 1 cm à frente da caixa da TV. O cômodo aceso e a janela acesa já existiam.

**Mais pisca achado pela régua:**
- O cimentado do quintal era um plano a 2 cm da terra, que o triângulo de 8 m alcançava na ladeira. Virou laje de 10 cm: de 7,8 para 0,02 m² nos dois chunks.
- A capa do embasamento ficava no plano do patamar e do degrau de toda porta de ladeira. Desceu 12 mm.
- Os embasamentos de lotes vizinhos saíam 3 cm cada e cruzavam 6 cm na divisa, com as frentes no mesmo plano. Agora ficam 1 cm para dentro.
- O `pedra_parque#9e998f` dos 72 m² da parte 1 não era a praça: era esse embasamento.

A área à vista nos 81 chunks em volta da praça foi de **784 para 357 m²** somando as duas partes. O que resta é quase todo chão (terra e grama do quintal e do baldio: ~200 m²), o mercado (fora do escopo) e casos da régua que se julgam no olho (cercadura e friso virados para dentro do prédio).

**Correção de pendência da Fase 3:** a placa da `BarVivo` já acende de noite (`mat_bar_nomes` tem emissão 2,0, ver `vivo/bar_do_tiao_noite.png`).

**Itens que se fecham por decisão já tomada:**
- **C1** (térreo comercial fechado): a 2f do `PLANO_CASAS_AAA` tirou as lojas de casca a pedido do usuário ("menos lojas, cada uma com interior"). O térreo fechado é essa decisão, não defeito.
- **C4** (fachada residencial): cimalha, friso, barrado, cercadura, peitoril e janela funda já vêm da `FachadaViva`; as fotos de `fase4/cidade_casas_depois.png` confirmam.

**C7, parada `rua_estreita` (feito em 25/09, com aval):** o Traçado tirou a viela de x = 64 no trecho z = 24 a 130, e a foto saía num muro. A primeira proposta (a viela de z = 64) corre entre dois baldios: viela sem prédio, que não mede o que a parada mede (`fase4/rua_estreita_z64_baldio_noite.png`). Ficou o **Beco dos Milagres**, na mesma linha x = 64, de z = 160 a 256, com comércio dos dois lados, bar com mesa na calçada, toldo, sacada e porta de aço perto da lente: `"onde": [64.0, 1.62, 250.0], "olhar": [64.0, 1.62, 150.0]` nas rotas `noite_chuva` e `dia_seco` (`game/resources/rotas/cidade.json`). Piso de ruído da parada nova, duas rodadas: PS1 1,58/255 e 4,73% dos blocos, moderno 0,79/255 e 1,91% (limite 3,0 e 12%). Gravada **só** `rua_estreita.png` em `captures/referencia/noite_chuva/{ps1,moderno}`.

**Achado para quem mede:** a referência de `noite_chuva` já reprova em 5 das 6 outras paradas comparáveis (PS1: avenida 5,70 e praça 11,15; moderno: avenida 10,24, praça 15,77 e interior 18,17 por 255; o cruzamento é parada viva e fica fora). É deriva das outras frentes desde a gravação (commit 5f3f514), e o `--gravar` inteiro a teria engolido sem ninguém olhar. Regravar essas cinco pede que alguém olhe cada uma e diga que a mudança é a desejada.

**Medidas finais:**
- `verificar_bar` (Seu Zé e `--bar-vivo`): tudo passa, menos o teto de 24.000 (37.958).
- `verificar_cidade`: só as 4 portas do mercado e o teto de 26.000 (33.436).
- `verificar_lojas`: só o teto de 24.000. O pior chunk de loja, (2,−9), tem 28.855; sem o porão tem 28.423. O número de 22.555 no plano das casas é de 22/09, e desde então entraram outras frentes; não separei a parte de cada uma.
- `bancada_janela_viva`: OK.

**Decisão do usuário:** os tetos de triângulos dos chunks (bar 24.000, loja 24.000, cidade 26.000) já estouravam e seguem estourando.

### Orçamento por balde (25/09, medido; decisão pedida: "a mais AAA, sem perder detalhe")

`tests/bancada_orcamento_chunk.tscn` separa o triângulo que se desenha até o horizonte (casca) do que some a 40 m (balde `@perto`), por material e por peça (material#cor do vértice). Nos 121 chunks do `teste_cidade` (raio 5):

| | média | p90 | pior |
|---|---|---|---|
| total | 15.217 | 26.416 | 33.710 (−2,−2, o do Seu Zé) |
| casca | 12.151 | 19.497 | 26.288 |
| @perto | 3.066 | 7.696 | 10.778 |

**80% do triângulo é casca**, e a casca é paga em todo chunk dentro do alcance visual (uma centena), enquanto o `@perto` só na dezena em volta do jogador. O teto único soma as duas contas e esconde isso. O que pesa na casca, somado na cidade:

| peça | triângulos | área média do triângulo | dono |
|---|---|---|---|
| fiação (`cabo`, três cores) | 238.680 (16% da casca) | 0,004–0,009 m² | rede elétrica |
| guarda-corpo de ferro do balcão e escuro da máquina (`metal#2a2c2e`) | 29.612 | 0,007 m² | `FachadaViva._balcao`, `MaquinaDeVenda` |
| casca de árvore (`casca`, várias cores) | ~45.000 | 0,005–0,027 m² | flora |
| `metal_pintado#854d38`, `#7d4835`, `#75787a` | 24.552 | **0,0005–0,0007 m²** (sub-centímetro) | a localizar |
| peitoril da janela (`concreto#d8d2c2`) | 17.052 | 0,04 m² | `JanelaViva` |
| cadeira monobloco da calçada (`bar_monobloco`) | 6.660 | 0,007 m² | `MoveisDoBar` |

No chunk (2,−9), o de loja, flora soma 5.759 dos 29.034 (vegetação 2.196, casca 1.169 + 1.092 @perto, plantas 634, flor 620, folhagem 48) e o porão 432.

**Decisão, pelo que um jogo de mundo aberto AAA faz: nenhum detalhe sai; cada detalhe vai para a distância em que ele se lê.**
1. Barra de 18 mm a 60 m ocupa meio pixel a 4K (0,018 / 60 × 1.770 px/rad) e só vira cintilação. Balaústre de guarda-corpo, peça sub-centímetro e miudeza de fachada vão para o `@perto`. Corrimão, montantes de canto e a laje do balcão ficam na casca: a silhueta do balcão continua de qualquer distância.
2. Face encostada em parede (a de trás do peitoril, da moldura, do medidor) não aparece de lugar nenhum e sai. É ganho sem troca.
3. A fiação ganha nível de detalhe próprio: perto o cabo como é hoje, longe menos lados e menos segmentos, com a mesma catenária. É a maior alavanca (16% da casca), mas é da frente da rede elétrica.
4. Troca de nível sem estalo pede faixa de esmaecimento no corte do `@perto` (`visibility_range_end_margin` com fade), e um balde "só de longe" para o LOD da cadeira e do cabo. As duas coisas moram no `chunk_manager.gd`, da sessão de otimização.
5. O teto único vira **dois tetos, casca e `@perto`**, cada um fixado pela medida de quadro em par na `bancada_fps_dirigir` (como os aumentos de 22/09), e não por número de era PS1.

**Feito em 25/09 (aval do usuário a todos os itens, sem commit):**

| | vista de longe (casca), média / p90 / pior | vista de perto, pior |
|---|---|---|
| antes | 12.151 / 19.497 / 26.288 | 33.710 |
| + guarda-corpo, grade, faces escondidas (B) | 11.874 / 18.533 / 24.860 | 33.342 |
| + fiação e isolador em dois níveis (C) | 10.207 / 16.569 / 22.916 | 33.342 |
| + cadeira do bar em dois níveis | 10.165 / — / 22.916 | 33.342 |

- **B:** as barras do guarda-corpo, as barras e os losangos da grade de janela passam a sumir a 40 m (balde `@perto`). Corrimão, montante de canto (novo, 3 cm), laje e as duas travessas da grade continuam visíveis de qualquer distância. Sai a face de trás encostada na parede da laje do balcão, do corrimão lateral, da cercadura e do peitoril. Par de fotos em pose fixa a 20, 60 e 110 m: 0,6 a 0,8/255, abaixo do ruído (`fase4/balcao_lod_*`).
- **D:** balde `material@longe` no `ChunkManager`: casca, com `visibility_range_begin` no mesmo ponto em que o `@perto` acaba (`e_longe`, `marcar_balde`, `triangulos_por_vista`). **Esmaecimento: medido e descartado.** Com o `psx_surface`, o esmaecimento do Godot apaga as duas malhas na faixa inteira (cobertura 0 de 17 a 23 m, `tests/bancada_esmaecer.tscn -- --psx`); com material padrão ele mistura por transparência, centrado na troca. Um esmaecimento pontilhado exigiria `discard` no shader de toda a cidade, com perda do descarte antecipado de profundidade (early-z). Fica a troca seca: o que troca é sub-pixel nessa distância por construção.
- **C:** vão em catenária com `cabo@perto` (6 lados, hélice) e `cabo@longe` (3 lados, metade dos segmentos, mesma flecha, balança junto); isolador com `metal_pintado@perto_rede` e `@longe_rede` (nome próprio, para as duas malhas terem a mesma caixa). `--rede-sem-lod` é o par. `checar_fiacao`: F1–F5 OK; cabo por chunk 2.160 de perto e 516 de longe (mediana). Rajada de 16 fotos de 2 em 2 m atravessando a troca: igual ao sem nível em todas, fora um carro passando (`fase4/fiacao_lod_*`).
- **Cadeira do bar:** `bar_monobloco@perto` (a de 180 triângulos) e `@longe` (70: assento reto, pernas retas, as duas faixas do encosto vazado). Par a 25, 50 e 75 m no ruído (`fase4/cadeira_lod_*`).
- **E:** o teto único virou dois nos três verificadores, `TETO_LONGE` e `TETO_PERTO` (cidade e lojas 24.000 e 36.000; bar 27.000 e 40.000). Medida de quadro em par na `bancada_fps_dirigir` (4K, MODERNO, RX 9070 XT, com outro Godot aberto, rodadas alternadas): GPU dirigindo 8,75 ms com nível de detalhe contra 8,65–8,80 sem, render_cpu igual, chamadas +5%. Nesta placa o triângulo não é o gargalo. O teto de longe é o que cresce com a opção "Distância de visão"; o de perto guarda contra regressão.
- Verificadores: `verificar_bar` (Seu Zé e `--bar-vivo`) e `verificar_lojas` **passam inteiros** pela primeira vez; `verificar_cidade` só reprova nas 4 portas do mercado, antigas e fora do escopo. `bancada_janela_viva` OK; `rua_estreita` contra a referência nova: PS1 1,62 e moderno 0,86/255.

**Achado para a sessão de otimização (não mexi):** com o streaming novo, depois de `--ir-para=-20,-63,100,-56,4`, o quarteirão a uns 40 m a leste (o prédio de quatro andares com balcões, o cruzamento e os semáforos) não aparece nem depois de 20 s. No lugar fica o painel da serra do horizonte, com os carros andando no ar. Com `--streaming-antigo`, na mesma pose, a cena sai inteira (`fase4/buraco_streaming_novo.png` e `buraco_streaming_antigo_mesma_pose.png`). Não há erro no log.

## 4. Regras desta frente

- Mercado e casa da fumaça não se tocam: só se **chamam** as peças (`KitSalao`, `ProdutoMalhas`, `RotulosAtlas`, `CatalogoMercado`).
- Arquivo compartilhado recebe só a ligação mínima. `cidade.gd` e `chunk_manager.gd` estavam limpos no início; `convidado.gd` tem trabalho de outra sessão e **não** entra.
- Geometria nova vai por molde copiado (e não por `Peca` no balde do chunk), porque `Peca._v` copia o balde inteiro a cada vértice.

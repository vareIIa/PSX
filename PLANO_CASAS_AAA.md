# Plano Casas AAA: casas e prédios de cidade mineira

**Pedido (22/09/2026):** foco total em deixar prédios e construções AAA. Paredes com
bug, repetição e pouca vida. Janelas abertas onde se vê um pouco de dentro, janelas
fechadas, umas com flor e outras sem, variação de casa e prédio, cidade interiorana.
Ruas e o resto ficam para depois.

## 1. Diagnóstico (levantamento de 22/09, código e 18 capturas, conferido por verificador)

| # | Defeito | Onde | Estado |
|---|---|---|---|
| D1 | A folha da porta de entrar ficava 5 mm atrás da parede. Fechada, o jogador via um painel cinza ou parede lisa (127 de 127 portas). | `_fileira`, `KitFachada._entrada` | **Resolvido**: vão de verdade (ParedeVazada) na porta |
| D2 | O quadro da porta saía espelhado nas faces +X e −Z, até 7,5 m longe da folha. | `_fileira` (`porta_local` medido no eixo da face) | **Resolvido**: centro da folha em `_lateral(direcao)` + 0,45 |
| D3 | Casa = placa clara na frente de uma caixa de concreto 5× mais escura. | `_massa` com `concreto_sujo` | **Resolvido** nas casas e na rua comercial: o corpo sai no reboco, na cor da casa |
| D4 | Janela era um plano 11 cm SALIENTE, sem recuo, sem sombra, igual em toda casa. | `KitFachada`, `KitModular.fachada` | **Resolvido**: vão recuado de 14 a 32 cm (ParedeVazada + JanelaViva) |
| D5 | O embasamento e a pingadeira atravessavam a porta e o portão, e a garagem ficava murada. | `KitFachada._embasamento` | **Resolvido** na casa nova: o barrado é banda da parede, cortada pelos vãos |
| D6 | Metal com albedo 63/255: o ar-condicionado, o medidor, a caixa d'água e a grade saíam pretos. | `mat_metal` | **Resolvido** na casa nova: material `metal_pintado`, caixa d'água cilíndrica de fibra azul |
| D7 | Repetição: 4 estilos, 1 janela, passo fixo de 3 m, remate por quadra (telhado em só 7% dos chunks). | `KitFachada`, `MalhaUrbana` | **Resolvido**: tipologia e remate por lote |
| D8 | Chapim do muro de quintal com 2,28 m: muros de 3,4 m. | `FundosBuilder._muro` | **Resolvido** (chapim de 8 cm) |
| D9 | Letreiro salmão aceso sem texto, "janela" de azulejo no térreo comercial. | `KitModular.fachada` | **Resolvido** na rua comercial nova: placa e testeira com o nome da loja (atlas de `tools/gerar_letreiros.py`) |
| D10 | Casa rígida enterrada no lado de cima da ladeira (27,5% dos lotes com o chão mais de 30 cm acima da soleira). | `_erguer_lote` | **Resolvido na frente** (F5-A): base no ponto alto da frente, escada, degrau e rampa; o chão desce sob a casa. Falta o porão progressivo (F5-C) |
| D11 | Esquina chanfrada nunca aparece (exige chunk em y = 0). | `_fileira` | Aberto (F5) |
| D12 | Fundo e lateral de esquina ainda em concreto escuro, com janela antiga. | `FundosBuilder` | **Resolvido** (F4): FundosVivos |
| D13 | Distrito industrial inteiro no kit antigo (177 de 177 lotes no raio 12), porta de entrar escondida em 19 chunks. | `KitModular.fachada` | **Resolvido** (F4): IndustriaViva |
| D14 | Terreno da quadra atravessando a casa e aparecendo no cômodo da janela aberta (metade dos lotes com canto mais de 30 cm acima do piso). | chão `terra` e `grama` sob o lote rígido | **Resolvido**: RebaixoDoLote |

## 2. O que foi feito (F1 e F2)

Arquivos novos (nenhum arquivo compartilhado foi reescrito; os ganchos são poucos e comentados):

- **`src/world/parede_vazada.gd` (ParedeVazada):** fachada com vãos de verdade.
  - A parede é montada em faixas costuradas em ziguezague, sem junta em T.
  - Cada vão tem ombreira, verga (reta ou em arco abatido), peitoril ou soleira, e tampa escura.
  - Aceita bandas de outra cor ou material na mesma grade: barrado, azulejo, tijolo aparente.
  - Régua: `tests/bancada_parede_vazada.gd` (raio em todo ângulo, juntas em T, controle positivo).
- **`src/world/janela_viva.gd` (JanelaViva):** o que vai no vão.
  - Modelos: guilhotina com folha de madeira, veneziana com palheta, correr de alumínio, vitrô basculante.
  - Estados: fechada, entreaberta, aberta.
  - A janela aberta monta o **cômodo** (sala, quarto ou cozinha), com parede interna iluminada pelo material `interior`, móvel, quadro, filtro de barro, cortina que o vento mexe, e lâmpada acesa.
  - Mais: floreira de gerânio ou lavanda, vaso de barro no peitoril, samambaia pendurada, grade reta ou de losango, peitoril de pedra.
  - O estado sai do estilo da casa e do **morador**: zelosa, família, idoso, jovem, fechada, abandonada.
  - Régua: `tests/bancada_janela_viva.gd`.
- **`src/world/fachada_viva.gd` (FachadaViva):** a casa por tipologia.
  - **colonial:** caiada, barrado, cunhal, cercadura, folha azul, verde ou sangue-de-boi, cachorrada no beiral.
  - **eclético:** platibanda com frontão e compoteira, sobreverga, balcão de ferro.
  - **moderno:** janela larga, faixa de azulejo, garagem, beiral fino.
  - **popular:** reboco cru ou pintura lavada, andar de tijolo aparente, vergalhão de espera, caixa d'água azul.
  - Vida na porta: número, lampião ou medidor CEMIG com caixa de correio, vaso de espada-de-são-jorge, buganvília subindo na porta, pichação e mato na abandonada.
- **`src/world/comercio_vivo.gd` (ComercioVivo):** a rua comercial.
  - Três tipos: sobrado com loja embaixo, loja de marquise, prédio de 3 a 5 andares.
  - A porta de enrolar tem três estados: fechada, meio aberta e aberta. A loja aberta mostra prateleira cheia, balcão e lâmpada tubular.
  - Mais: vitrine de alumínio com porta de vidro, armazém de duas folhas, portaria do prédio, ar-condicionado.
- **`src/world/obra.gd` (Obra):** canteiro de geometria que junta as peças por material e despeja uma vez por fachada. Motivo: `PSXMesh.acumular` copia o balde inteiro a cada peça, porque o PackedArray é copiado na escrita. Com o canteiro, o custo do chunk comercial caiu de 48,6 para 24,8 ms.
- **Materiais novos**, na tabela de `tools/gerar_materiais.py` e na política de chuva do EstiloVisual: `metal_pintado`, `cortina` (com vento), `lampada`, `interior`, `interior_aceso`, `interior_madeira`.
- **ChunkManager:** o balde `material@perto` é cortado a 40 m (`ALCANCE_PERTO`). Nele vão móvel, flor, cortina e miudeza.
- **Ganchos em `ChunkBuilder._fileira`:**
  - `planejar` antes da massa;
  - `residencia` ou `fachada` no lugar do kit antigo;
  - `coroar` do plano;
  - o `porta_local` corrigido (D2).
- `--sem-fachada-viva` volta ao caminho antigo, para comparar.
- `--janelas-abertas` abre toda janela, para fotografar os cômodos.

### Custo medido (headless, máquina com outras sessões rodando)

| Chunk | construir (média / pior) | triângulos (média / pior) | dos quais `@perto` |
|---|---|---|---|
| Residencial, antes | 18,1 / 25,5 ms | 3.750 / 5.303 | 0 |
| Residencial, agora | 21,4 / 27,5 ms | 6.671 / 9.059 | 1.296 |
| Comercial, antes | 16,4 / 25,0 ms | 3.730 / 4.459 | 0 |
| Comercial, agora | 24,8 / 31,5 ms | 10.583 / 15.161 | 2.119 |

O teto de 6.000 triângulos por chunk (ART-BIBLE §10) é da era PS1. O pedido foi "qualidade e otimização acima da estética PSX forçada", e o custo da GPU se confere na bateria de streaming (quadro em regime).

## 2b. F4 e F5-A: os quatro lados da casa, a rua de serviço e a ladeira (22/09)

Levantamento antes de mexer: seis frentes (fundos, esquina, miolo, indústria, ladeira,
telhados), 60 fotos e medidas em raio de 12 chunks da praça. Fotos em
`scratchpad/f4/<frente>/`, as de depois nas mesmas poses em `scratchpad/depois/`.

- **`src/world/fundos_vivos.gd` (FundosVivos):**
  - `fundo`: a parede de trás no mesmo material e cor do corpo (ou tijolo e reboco cru,
    que é como o fundo fica), com vão de verdade. Porta da cozinha de ferro com vidro
    canelado, de tábua (às vezes a holandesa com a de cima aberta), telhadinho de telha
    ou laje, botijão; janela da cozinha, vitrô canelado do banheiro, cobogó da área,
    quarto; varal de janela no prédio; cano e calha sob o beiral, ou buzinote com o
    escorrido na laje; condensador de ar. Vergas numa linha só (2,3 m).
  - Na ladeira, a porta da cozinha sobe com o quintal ou ganha a escadinha de cimento
    com corrimão (28% das portas flutuavam, 35% ficavam enterradas).
  - Fundo tapado pela fileira perpendicular (15%) sai só com a parede.
  - `lateral`: a lateral de esquina é fachada. As mesmas faixas (o barrado dobra a
    quina), a mesma esquadria, frisos e cimalha que dobram a quina, cunhal em L; na
    loja, a segunda porta de aço ou o nome pintado na parede cega; no galpão, vitrô alto.
    Janela nunca abaixo da calçada da transversal.
  - `quintal`: puxadinho de tijolo ou reboco com oitão até a meia-água (a cunha aberta
    sumiu), ou telheiro de pilar; tanque e máquina de lavar debaixo dele; varal,
    churrasqueira de tijolo, casinha de cachorro, mesa de plástico, vasos no muro,
    horta; no comércio, tambor e engradado.
- **`src/world/industria_viva.gd` (IndustriaViva):** galpão (arco de chapa com a
  platibanda curva, oitão para a rua, shed, laje), oficina com o vão aberto e a casa do
  dono em cima, depósito com pátio murado e portão gradeado (baias de areia e brita,
  tijolo, cimento no pallet, caco de vidro no muro), armazém de café e cerealista em
  tijolo com porta em arco e sacaria, fábrica com portaria e fita de vitrôs. Portão de
  correr fechado ou corrido para o lado com o galpão aparecendo; lanternim e exaustor;
  pneu, grade pronta e tábua encostados na parede; nome da firma pintado do atlas
  `letreiros_industria.png` (16 firmas inventadas em `tools/gerar_letreiros.py`).
- **Ladeira (F5-A), em `ChunkBuilder._fileira`:** a base do lote é o ponto ALTO da
  frente (`_altura_do_lote`; na esquina, também o canto de trás da lateral). No lote da
  porta interativa continua o chão na folha. O perfil do chão ao longo da fachada vai
  para o plano: escada na porta (de encosto, rente à parede, acima de três degraus),
  degrau de pedra na loja (a loja com a calçada mais de 75 cm abaixo não sai), rampa no
  portão; garagem e portão de galpão vão para onde a calçada encontra o piso.
- **`src/world/rebaixo_do_lote.gd` (RebaixoDoLote):** o chão da quadra desce sob a casa,
  sem junta em T (aresta por posição, vizinho em leque). `--sem-rebaixo` desliga.
- **Capa do embasamento** (`ChunkBuilder._capa_do_embasamento`): a caixa de pedra não
  tinha face de cima, e na quina se via o vazio dentro dela (bancada_quinas, -1,-2).
- Materiais novos na tabela: `vidro_canelado`, `letreiro_industria`.

### Custo e réguas depois da F4 (raio 7 da praça)

| Chunk | construir (média / pior) | triângulos (média / pior) |
|---|---|---|
| Residencial | 30,8 / 40,8 ms | 9.813 / 14.963 |
| Comercial | 35,8 / 52,6 ms | 14.342 / 24.455 |
| Industrial | 20,8 / 31,3 ms | 5.797 / 9.036 |

Streaming em par, alternando com `--sem-fachada-viva`: 326 mil triângulos na tela
contra 147 mil, e pior quadro de 7,7 e 12,1 ms contra 12,0 e 18,8 ms da cidade antiga
(teto 90). O teto por chunk em `tools/verificar_cidade.py` foi a 26.000.

Réguas: quinas 48/0; frestas 365 poses, 0 no MODERNO e 1 no PS1 (pose 387, os mesmos
três pixels de meio-fio da foto da sessão anterior: fresta antiga, fica aberta);
parede vazada e janela viva OK; pátio 1 boca (a do mercado, antiga); relevo, rota,
ameaça, trânsito, streaming, bar, casa, mercado e carro OK. A cidade só falha nas 4
portas do mercado (antiga) e a suíte nas 11 de outras frentes.

## 3. Próximas fases

- **F3. Letreiro com nome: feito.**
  - Atlas `letreiros.png` (256 px no PS1, 1024 px no MODERNO) com 16 lojas inventadas de cidade mineira, gerado por `tools/gerar_letreiros.py`. É conteúdo trocável: para nomes reais, edite a lista ou substitua os PNG.
  - Falta a luz do letreiro à noite.
- **F4. Fundos e laterais: feito** (acima). Falta:
  - Miolo de quadra: os galpões-caixa sobrepostos de `_anexos` (33 pares em 26 chunks)
    e o capim chapado; edícula, pomar, horta, pátio de galpão.
  - Empena cega entre vizinhos de alturas diferentes (60% dos pares, 23 mil m²): rufo,
    mancha, tijolo sem reboco.
  - Bar e casa da fumaça ainda no kit antigo; o beco (lixo em cubo preto, verga solta,
    casinha da vila atravessando a casa da esquina em 3 de 19 becos).
- **F5. Ladeira:**
  - Base no ponto alto com escada, degrau e rampa: **feito** (F5-A).
  - Porão progressivo em toda face exposta (gateira, janela de porão, porta em arco),
    hoje só com mais de 2,4 m e só no fundo; arremate de divisa entre vizinhos.
  - Esquina chanfrada de volta na ladeira (D11) e com a fachada nova.
- **F6. Telhado mineiro:**
  - Telha capa-e-canal com relevo e caimento de 35 a 40%.
  - Quatro águas na casa solta.
  - Telha envelhecida com limo perto do beiral.
- **F7. Desgaste no shader do MODERNO:** umidade no pé da parede, escorrido sob o peitoril, macrovariação de tom (UV2 já sai da ParedeVazada).
- **F8. Noite:**
  - Conferir a janela e o cômodo acesos à noite, e o lampião.
  - Luz de TV azulada em parte das salas.
- **F9. Bancada de casas:** fotografar N lotes por tipologia em três vistas e conferir o checklist (porta alinhada, vão recuado, sem coplanar, diversidade entre vizinhas).

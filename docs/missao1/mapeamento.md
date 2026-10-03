# Missão 1 — Mapeamento técnico e divisão em tarefas

**Branch base: `missao1/base`**, criada a partir de **`deploy`** @ e848992 (a `main` está parada desde 7/9 e não tem estrada, padre, Praça da Matriz, Jota nem Helmer).
Toda tarefa sai de `missao1/base` e abre PR de volta para ela. A tarefa E abre o PR final **`missao1/base → deploy`**.
Roteiro: `/mnt/project-files/missao1/roteiro.md` (as listas da seção 8 dimensionaram as tarefas abaixo). Caminhos de código relativos a `game/`.

## 0. Como rodar numa sessão na nuvem (Linux)

O `dev.sh` aponta para o Godot Windows em `.tools/`; na base ele aceita `GODOT` do ambiente.

```bash
curl -sSL -o /tmp/g.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -o -q /tmp/g.zip -d ~/godot && export GODOT=~/godot/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path game --import   # a primeira vez demora (~800 MB de assets); rode em background
bash dev.sh check                       # nível 1 (sem ERROR/WARNING) + nível 2
```

Linha de base na `deploy` (medida aqui com import parcial): o nível 2 já falha em **19 de 2435** asserções, todas de textura acima de 256 px, material e névoa, nenhuma de código. Regra: **não aumentar esse número** e não deixar nenhum `SCRIPT ERROR`/`Parse Error` no nível 1. O import completo dos assets passa de 30 min numa sessão nova; rode em background e valide script antes com `$GODOT --headless --path game --quit 2>&1 | grep -E "SCRIPT ERROR|Compile Error"`. Nome de classe novo precisa de um `--import` curto para entrar no cache de classes (foi assim que apareceu a colisão `Plano` × `AberturaEstrada.Plano`, por isso a classe se chama `PlanoCena`).

Headless não renderiza: a verificação na nuvem é log, asserção e teste próprio. Regras do repo valem para todos (`docs/PADROES-ENGENHARIA.md`, skills em `.claude/skills/`): GDScript tipado, comentário em português sem acento explicando o porquê, pose procedural quantizada, teto de draw calls, mundo determinístico.

## 1. O que já existe na `deploy` (e o que falta)

| Sistema | Onde | Estado |
|---|---|---|
| Cena cortada | `src/ui/cinematica.gd`, autoload **`Cinema`**: `iniciar/encerrar`, `assumir/devolver`, `enquadrar(de,para,fov)`, `mover(...)`, `profundidade/sem_profundidade` (DOF), `legenda`, `fala`, `escurecer/clarear/corte`. Tarjas 33 px. | Bom. **Faltam** plano com nome, tremor, interior de carro. `src/levels/trilho_de_camera.gd` (`TrilhoDeCamera.rodar`, spline Catmull-Rom com tremor e fov) é a base para grua e acompanhamento. Precedente de roteiro: `levels/abertura.gd` (58 chamadas a `Cinema.*`, funções `_plano_xxx`). |
| Fala | `ui/dialogo.gd` (`abrir(nome, linhas, quem, ficha)`, sem escolha), `ui/conversa.gd` (assuntos de `FalasNpc`), `systems/fala.gd` (texto+voz+boca, marca `[gesto:x]`), `gesto_da_fala.gd`, `expressao_da_conversa.gd` | **Falta** fala roteirizada com escolha que devolve o resultado. |
| Efeito borboleta | — | **Faltava.** Base cria `Borboleta` + `OlhoBorboleta`. (`OlhoSolto` e `PalpebraDaLente` existentes não são isso.) |
| Missão | `systems/missoes.gd`: dicionário com `etapas`; `comecar_primeira():83` (3 etapas: marcar no GPS, ir, achar o dono), `dono_respondeu():210` chamado por `convidado.gd:1704`. Começa em `abertura.gd:2568`. HUD: `ui/hud_missao.gd`, `ui/hud/hud_objetivo.gd`, `ui/hud/pausa/pausa_aba_missoes.gd`. | Missão salva no save. **Falta** gatilho genérico e etapa opcional; a Missão 1 pendura em `Missoes.concluiu`. |
| Save | `systems/save_game.gd` v2: jogador, inventário, `WorldState`, registro, missão, relógio, celular | Base acrescenta `borboleta` e `missao1`. |
| Corpo | `render/corpo.gd` (2591 l.): 11 ossos, pose **procedural** (sem AnimationPlayer). `enum Postura:72` (… `DIRIGINDO`, `ASSENTO`), `postura()`, `olhar_para`, `falar`, `rir`, `reagir(tipo)` → `render/reacao_corpo.gd` (poses-chave: `GESTO_APONTA`, `GESTO_OMBROS`, `GESTO_ACENO`, `OCIO_CRUZA`…), IK em `render/gesto_de_carga.gd` e `render/levantar_do_chao.gd`, fumo em `tragada.gd`/`cigarro.gd`. | **Faltam** os gestos do roteiro (porta, papel, óculos, entrar/sair do carro…), pose de carona e óculos destacável (`Vestuario.oculos`, `render/vestuario.gd:431`, é fundido na malha). |
| NPCs | `world/convidado.gd` (`estacionar(onde, olhar):862`, `encarar`, `dizer`, `gargalhar`, rotinas), `world/morador_praca.gd` (sai, passeia, some), `world/pedestre.gd` | **Falta** ator com verbos `await`. Berg não existe. |
| Elenco | `systems/aparencia.gd`: `ELENCO` (Helmer `:336`, Jota `:368`), `personagem()`, `de_personagem()`, `LINHA_ELENCO = 8` do atlas (`tools/gerar_npc.py`) | Jota e Helmer prontos, com rotina de fazendeiro (`estufa_builder.gd:1625`, `interior_no_mundo.gd:778`) e falas (`FalasNpc`). **Falta Berg.** |
| Casa da fumaça | `world/casa_fumaca_builder.gd` (interior no mundo, sala, cozinha, corredor, estúdio, banheiro; `_gente():1137`), dono = `Convidado` com `dono_da_casa`, falas `FalasNpc.ROLE_DONO:108`, paga em `_pagar_o_que_o_dono_deve():1688` | Existe. Descida com escada em U a partir dos fundos: `_porao():769` → estufa (`ESTUFA_NA_CASA:128`). **O porão do roteiro (teto 2,05 m, luz roxa, lâmpada que balança, bancada, prancheta, quadros) não existe.** |
| Igreja | **Fixa**, Praça da Matriz: `Tracado._ancora` (`world/tracado.gd:134`), `ParqueBuilder.planta_matriz():1151`, `KitParque.igreja_matriz():1531` (fachada para +Z, 4 degraus), `cidade.gd:811` `IGREJA_ANCORA (270.9, 0, -59.1)`, pino do despertar (270, −40) em `abertura.gd` | Existe. **Falta** API de porta/adro/vaga e pino no GPS (`ui/gps.gd:32 FILTROS`, `ChunkBuilder.pontos_de_interesse:228`). |
| Carro | `world/carro.gd` (3306 l.): `Carro.sentar(corpo, medidas)` estático `:1010` (motorista), `pilotar():1376`, `pousar():1400`, `estacionar_solto():1435`, `prender_estacionado():1451`, `tinta_fixa:396`; `Carroceria.Modelo.MAREA` (`render/carroceria_marea.gd`); vãos de porta em `Carroceria.aberturas():933` e `CarroCabine._abertura():299`; cabine `world/carro_cabine.gd`, `render/cabine_*.gd`, `world/cabine_do_jogador.gd` (só lugar do motorista); IA `world/transito/motorista_ia.gd`; viatura com duas rodas na calçada em `world/blitz.gd:649` (`_pegada_livre:676`); `Transito.registrar_estacionado()` | **Faltam** porta animada, carona, embarque animado (hoje `player.gd:892/918` é instantâneo), `ir_para` um ponto, sumir depois do passeio. |
| Celular | `celular/app_contatos.gd` (lista `RegistroCivil.conhecidos()`), `celular/app_telefone.gd` (`ligar(id)`, respostas aleatórias `RESPOSTAS:16`), `Celular.abrir_conversa_em_cena` | **Falta** ligação com falas fixas e contato BERG. |
| Sons | `assets/audio`: `porta_carro`, `motor_partida`, `funk_batida`, `risada_m_1`, `papel`, `pegar`, `celular_ok`, `estatica` | Todos existem. |

## 2. O que a base entrega (codar contra isto)

Os stubs compilam e rodam; o comportamento é placeholder. **A tarefa dona muda o corpo, não a assinatura** (se precisar, avisa o coordenador).

| Interface | Arquivo | Dono |
|---|---|---|
| `Borboleta` (autoload): `marcar(chave, valor=true, mostrar_olho=true)`, `valor`, `tem`, sinal `marcou`, save. Flags do roteiro no cabeçalho. | `src/systems/borboleta.gd` | pronto |
| `OlhoBorboleta` (autoload): `mostrar()`, sinal `terminou`; liga sozinho em `Borboleta.marcou` | `src/ui/olho_borboleta.gd` | A |
| `Escolha` (autoload): `await falar(nome, linhas, quem)`, `await perguntar(nome, pergunta, opcoes, quem) -> StringName`; opção `{chave, titulo, borboleta?, valor?}` | `src/ui/escolha.gd` | A |
| `PlanoCena.Tipo` (13) e `PlanoCena.calcular(tipo, alvo, outro, opcoes)` | `src/cinema/plano_cena.gd` | A |
| `Cinema.plano(tipo, alvo, outro, duracao, opcoes)`, `Cinema.tremor(i)` | `src/ui/cinematica.gd` | A |
| `Corpo.Postura.ENCOSTADO_CARRO / CARONA`, `Corpo.GestoCena` (20 gestos do roteiro), `await fazer_gesto(g)`, `duracao_do_gesto(g)`, `abaixar_oculos(t)`, sinal `gesto_de_cena_terminou` | `src/render/corpo.gd` | B |
| `Ator` (grupo `elenco`): `preparar(quem, ficha)`, `await andar_ate`, `encarar`, `olhar_para`, `await fazer(gesto)`, `postura`, `falar`, `soltar_papel()`, `vagar_em`, `await entrar_no_carro / sair_do_carro`, `rotulo`, sinal `interagido` | `src/world/ator.gd` | B |
| `Elenco`: `BERG/HELMER/JOTA/DONO`, `IDS`, `ficha(quem)`, `no(tree, quem) -> Node3D` (Ator, ou Convidado com meta `elenco`) | `src/systems/elenco.gd` | D |
| `Lugares.igreja()` → `{mundo, frente, giro, vaga, area, nome}`, `casa_fumaca_mais_perto`, `vaga_na_calcada(perto_de, frente_para)` | `src/world/lugares.gd` | D |
| `Carro.Banco`, `medidas()`, `ponto_da_porta`, `await abrir_porta/fechar_porta`, `sentar_no_banco`, `levantar_do_banco`, `ocupante`, `await ir_para(pos)`, `await estacionar_na_calcada(pose)`, `vagar(s)`, sinais `porta_abriu/porta_fechou/chegou_ao_destino/sumiu` | `src/world/carro.gd` (fim) | C |
| `Transito.criar_carro_de_cena(ficha, pose, modelo=MAREA, tinta=preto)` | `src/world/transito.gd` (fim) | C |
| `Player.await embarcar(carro, banco, animado)`, `await desembarcar_animado()`, `de_carona()` | `src/player/player.gd` (fim) | C |
| `Missao1` (autoload): `iniciar()`, save | `src/missoes/missao1.gd` | E |

## 3. Tarefas

A, B, C e D rodam **em paralelo**; E começa depois dos quatro merges (pode esboçar contra os stubs). Os arquivos donos não se sobrepõem e ninguém mexe em `project.godot`. Cada tarefa testa num arquivo próprio `game/tests/m1_<letra>.gd` e não edita `tests/run_tests.gd`.

### A — Câmera de cinema, fala com escolha e o olho · Opus 5.5 **high**
- `PlanoCena.calcular` para os 13 tipos (estabelecimento, dois-shot médio, close, close extremo, sobre o ombro, contra-plongée, plongée, interior do carro via `Carro.medidas()` e transform do carro, céu/grua, acompanhamento de nó ou carro andando, dolly in/out, POV), com regra dos 180° (`opcoes.lado`) e teste de oclusão (raio câmera→alvo; se bater em parede, aproxima).
- `Cinema.plano` com movimento real (grua e acompanhamento sobre `TrilhoDeCamera`, dolly com `mover`), `tremor`, corte seco.
- `Escolha`: papel do `Dialogo` com texto revelando e voz via `Fala`, lista de opções no visual da `Conversa`, chama `quem.falar(true/false)`; opção com `borboleta` → `Borboleta.marcar`.
- `OlhoBorboleta` conforme a seção 1 do roteiro: só o contorno, translúcido, vértices tremendo no grid 480×270, abre, olha esquerda, direita, fecha, com som curto; abaixo do pós-processamento.
- Donos: `src/cinema/`, `src/ui/cinematica.gd`, `src/ui/escolha.gd`, `src/ui/olho_borboleta.gd`, `src/levels/trilho_de_camera.gd`, assets novos `assets/ui/olho_*`, nível novo `src/levels/teste_cinema.gd`, `tests/m1_a.gd`.
- Verificar: teste que percorre os 13 planos em volta de dois `Ator` e um carro, roda uma `perguntar` com borboleta e confere flag gravada e `OlhoBorboleta.terminou`.

### B — Gestos de personagem e o Ator · Opus 5.5 **high**
- `Corpo`: `ENCOSTADO_CARRO` (braços cruzados, cigarro, troca de peso), `CARONA` (sentado, mãos soltas, olha o motorista e a janela), e os 20 `GestoCena` (lista 8.1 do roteiro), reaproveitando `ReacaoCorpo`, `GestoDeCarga` e o IK de `LevantarDoChao`; inclui o loop "ouriçado" do Berg (gira o chaveiro, troca de perna) e a rotina na igreja (andar, parar, olhar a torre, fumar).
- Óculos destacável: separar a peça em `Vestuario` para `abaixar_oculos` descer na ponta do nariz.
- `Ator`: caminhada real (`move_and_slide`, giro suave, `Corpo.animar`), cabeça seguindo `olhar_para`, `vagar_em`, interação `Interativo`, voz e risada com som (`risada_m_*`), `soltar_papel()` (papel em arco até o chão, vira `ItemNoChao` do item novo `bilhete_berg`, texto "BERG (35) 9 ••••-••••", ícone `bilhete`), `entrar_no_carro/sair_do_carro` em sincronia com a porta do carro.
- Donos: `src/render/corpo.gd`, `src/render/reacao_corpo.gd`, `src/render/vestuario.gd`, `src/render/gesto_de_carga.gd`, `src/world/ator.gd`, `src/world/item_no_chao.gd`, recurso do item `bilhete_berg`, nível novo `src/levels/teste_ator.gd`, `tests/m1_b.gd`.
- Verificar: teste com um Ator `Elenco.ficha(&"berg")` tocando cada gesto (sinal emitido, ossos mudando); nível de captura mostrando Berg encostado, desencostando, jogando o papel, baixando o óculos e rindo.

### C — Carro: portas, carona e direção roteirizada · Opus 5.5 **high**
- Portas dianteiras como malha própria girando na dobradiça (vãos de `Carroceria.aberturas` / `CarroCabine._abertura`), por fora e por dentro da cabine, som `porta_carro`, sem estourar o orçamento de draw calls com o carro parado.
- Bancos: `sentar_no_banco` (motorista com `Carro.sentar`/`DIRIGINDO`, carona com `CARONA`), `levantar_do_banco`, `ocupante`.
- `ir_para(pos)`: rota pela malha de ruas até o destino com a condução da IA e chegada suave; `estacionar_na_calcada`: duas rodas sobem o meio-fio, carro torto (padrão da viatura da blitz), termina preso; `vagar(s)`: IA aleatória e, no fim, some fora da vista do jogador.
- O Marea preto do Berg: rebaixado, uma calota faltando, adesivo desbotado "SÃO THOMÉ DAS LETRAS" no vidro traseiro, único no mundo.
- Jogador: `embarcar` animado como carona (abre a porta, câmera desce para o banco, fecha), olhar livre limitado sem dirigir, `desembarcar_animado`, `de_carona()`; câmera de carona em `CabineDoJogador`. O `F` de motorista continua igual.
- Donos: `src/world/carro.gd`, `src/render/carroceria*.gd`, `src/world/carro_cabine.gd`, `src/render/cabine_*.gd`, `src/world/cabine_do_jogador.gd`, `src/player/player.gd`, `src/player/olhar_ao_volante.gd`, `src/world/transito.gd`, `src/world/transito/*.gd`, `tools/gerar_carro.py`, `tests/m1_c.gd`.
- Verificar: teste que cria o carro de cena, abre/fecha as duas portas, senta um Ator e confere `ocupante`, `ir_para` três quadras, `estacionar_na_calcada` com as rodas do lado da calçada acima de `ALTURA_MEIO_FIO`, `vagar(5)` e `sumiu`.

### D — Lugares, elenco e o telefone do Berg · Opus 5.5 **medium**
- Berg em `Aparencia.ELENCO` (linha nova do atlas via `tools/gerar_npc.py`, óculos escuro, jaqueta) e `Elenco` com id fixo conferido.
- Dono, Jota e Helmer marcados ao nascer (`set_meta(&"elenco", chave)` + grupo `elenco`).
- Porão do roteiro no fim da descida existente (`CasaFumacaBuilder._porao`): teto 2,05 m, luz roxa de cultivo, lâmpada pendurada que balança (pêndulo amortecido de 4 s), bancada com potes e prancheta, mona lisa de olho vermelho e retrato do Jota de general, ventilador; Jota e Helmer posicionados ali para a cena 2. **Escolha padrão:** reaproveitar a escada em U que já existe em vez da escada de 4 a 6 degraus pela cozinha que o roteiro descreve.
- `Lugares.igreja()` calculado de `planta_matriz` (porta no topo da escadaria, adro, `area`) e `vaga` na calçada da praça de frente para a escadaria; `vaga_na_calcada` com a checagem de calçada livre da blitz. Pino e categoria IGREJA no GPS e no app de mapas.
- Celular: contato BERG ao pegar o papel (`RegistroCivil.conhecer`) e ligação com falas fixas do roteiro em `AppTelefone`.
- Donos: `src/systems/aparencia.gd`, `src/systems/elenco.gd`, `src/world/lugares.gd`, `src/world/casa_fumaca_builder.gd`, `src/world/kit_fumaca.gd`, `src/world/convidado.gd` (só a marcação), `src/world/interior_no_mundo.gd`, `src/world/estufa_builder.gd`, `src/ui/gps.gd`, `src/celular/app_mapas.gd`, `src/celular/app_telefone.gd`, `src/celular/app_contatos.gd`, `src/world/chunk_builder.gd` (só o POI), `tools/gerar_npc.py`, `tests/m1_d.gd`.
- Verificar: teste com `Lugares.igreja()` batendo na geometria (raio acha os degraus e a calçada), `Elenco.no` achando os três na casa, ligação para o Berg com as falas fixas.

### E — Missão 1: o roteiro virando jogo · Opus 5.5 **high** · depois de A, B, C e D
- Pendurar `Missao1.iniciar()` em `Missoes.concluiu` da casa da fumaça; etapas no HUD com a opcional do porão; gatilhos por evento (interagiu com X, pisou no último degrau, saiu da casa).
- Cenas 1 a 7 do roteiro com os planos, as falas e as seis escolhas (E1–E6) e as variantes `[se flag]`; os dois ramos 4A/5A/6A e 4B/6B; o NPC do Berg pela cidade (`vagar(120)`, depois carro na `vaga` da igreja e Berg com `vagar_em(area)`), respawn só com o chunk da praça carregado; o barato de 45 s pós-E2 com os efeitos de lente que já existem; o trago em primeira pessoa (C2-11a) reaproveitando o plano da bituca de `abertura.gd`; pegar o papel em primeira pessoa; `m1_concluida`.
- Save no meio da missão (`Missao1.para_dicionario/de_dicionario`).
- Donos: `src/missoes/` (pode quebrar em `cenas/*.gd`), `src/systems/missoes.gd`, `src/levels/cidade.gd`, `src/ui/hud_missao.gd`, `src/ui/hud/hud_objetivo.gd`, `src/ui/hud/pausa/pausa_aba_missoes.gd`, `tests/m1_e.gd`.
- Verificar: atalhos `--m1-casa`, `--m1-saida` e `--m1-igreja`; teste que roda os dois ramos respondendo a `Escolha` por código e confere flags e estado final. No fim, PR `missao1/base → deploy`.

## 4. Branches

1. `git fetch origin missao1/base && git checkout -b missao1/<letra>-<nome> origin/missao1/base`
2. `bash dev.sh check` limpo antes de todo push; PR para `missao1/base`.
3. Merge na ordem que ficar pronto: não há arquivo compartilhado entre A–D.
4. E sai de `missao1/base` depois dos quatro merges; PR final para **`deploy`**.

Nomes: `missao1/a-cinema`, `missao1/b-atores`, `missao1/c-carro`, `missao1/d-lugares`, `missao1/e-missao`.

# TASK — Bar do Seu Zé

Sessão **só deste lugar**. Não mexa em mercado, casa da fumaça, kit da praça, estrada velha, carroceria, criação, nem nas fachadas genéricas da cidade (outro agente está nisso).

Jogo: Godot 4.7.2 Compatibility, 480×270, PSX. Branch `playable`. Código em português, `class_name`, tipado, constante no topo. Godot: `.tools/Godot_v4.7.2-stable_win64_console.exe --path game`.

---

## O que é

Bar de interior brasileiro, caricato e legível a 480×270. Não é pub, não é boteco genérico de GTA, não é marca real.

Da calçada: porta **grande e aberta** (vão de ~2,2–2,6 m, **sem folha fechando** — o bar “é” a rua). Mesas e cadeiras plásticas **na calçada e dentro**. Letreiro aceso. Som e TV de futebol vazando.

Nome inventado: **BAR DO ZÉ** (ou SEU ZÉ). **Proibido** logo/nome Brahma, Skol, Antarctica, Coca. Cadeira amarela de plástico = o tipo, não a marca.

Referência viva: boteco de cidade pequena — piso de cimento, parede amarela suja, balcão de formica, freezer de cerveja, TV alta no canto, caixa de som pendurada, toalha xadrez ou mesa plástica crua, cadeira monobloco, porta de enrolar **aberta o dia todo** encostada no batente.

---

## Contrato de interior (copie o mercado)

Todo lugar novo é **dados puros** numa thread. `Interiores._planta` escolhe o builder; o resto do sistema não muda.

Builder devolve:

```
superficies, props, colisao, triangulos, entrada, olhar, saida
ambiente  (opcional)  fog preset próprio
```

Interiores vivem em `Interiores.DESLOCAMENTO = (0, 2000, 0)`. Vidro transparente mostra o vazio. Porta/vão **opaco ou aberto para o próprio comodo**, nunca para a cidade.

Arquivos a criar/alterar:

| Papel | Path |
|---|---|
| Planta | `game/src/world/bar_builder.gd` (`class_name BarBuilder`) |
| Peças | `game/src/world/kit_bar.gd` (`class_name KitBar`) |
| Texturas | `tools/gerar_bar.py` + `tools/gerar_materiais.py` |
| Hook planta | `game/src/systems/interiores.gd` → `_planta`, match `&"bar"` |
| Hook rua | `game/src/world/chunk_builder.gd` → `_porta_do_chunk` e fachada |
| GPS | `game/src/ui/gps.gd` categoria `&"bar"` |
| Captura | `game/src/levels/cidade.gd` `--entrar-bar`, `--ver-fachada-do-bar`, `--bar-cena=` |
| Teste | `game/src/levels/teste_bar.gd` + `tools/verificar_bar.py` |

**Não** reescreva `Porta` para a entrada da rua: o vão é **aberto**. A área de acionamento (`Interativo`) fica no vão. Folha de enrolar, se existir, fica **recolhida** no tambor (só silhueta).

---

## Onde nasce na cidade

Espelho da loja, mais raro.

- Só distrito **COMERCIAL** (`quadra["conveniencia"]` / `MalhaUrbana.Distrito.COMERCIAL`).
- Uma porta de bar a cada **6** portas comerciais que **não** forem mercado. Nunca na mesma fachada do HIKARI.
- `_porta_do_chunk`: `planta = &"bar"` com semente própria, **não** deslizante.
- Fachada saliente ~0,15–0,25 m (menos que `KitMercado.SALIENCIA`). Letreiro + toldo listrado + vão aberto.
- Mesas na **calçada** entram no **chunk** (props do `ChunkBuilder`), não no interior. Sem isso, da rua o bar não existe.

Constantes de afastamento (eixo da porta → mesa da calçada) num **único** lugar (`KitBar`), iguais à disciplina do portão do mercado.

---

## Planta (sugestão, pode ajustar se medir)

Salão único, ~10 × 7 m, pé-direito 3,0.

```
z=0  RUA / vão aberto 2,4 m no centro
     mesas 2–3 na calçada (chunk) + 1 logo dentro
     piso cimento + faixa de ladrilho na entrada

     balcão em L no fundo-direita (atendente atrás)
     freezer/cervejeira no fundo, portas de vidro
     TV alta na parede esquerda, 1,9 m do chão
     caixas de som nos cantos do teto
     banheiro de porta estreita no fundo-esquerda (opcional, 1 box)
```

`entrada` / `olhar` no vão, olhando o salão. `saida` = o mesmo vão (sair = calçada, como a porta automática do mercado, **sem** folhas correndo).

Luzes: no máximo **6** Omni no comodo (teto 16 por objeto no Compatibility). Cor quente `#ffcf8a` + uma fria no freezer. Preset `fog_bar.tres`: névoa off, ambiente âmbar baixo.

---

## Peças do kit (caixa + textura, como `KitMercado`)

Obrigatórias:

1. **Vão aberto** — batente grosso, tambor de porta de enrolar em cima, folha enrolada. Colisão nas ombreiras, **não** no vão.
2. **Mesa de bar** — redonda ou quadrada plástica, Ø ~0,7 m.
3. **Cadeira monobloco** — amarela ou branca, 4 pés, encosto vazado (silhueta basta).
4. **Balcão** — formica + peitoril; uma ponta com caixa registradora.
5. **Cervejeira** — reusa ideia de `KitMercado.geladeira_parede`, paleta de latas, emissão baixa.
6. **TV** — reusa `Televisao` / `quadro.gd` se já existir no mundo; senão placa emissiva com textura de campo. Precisa **parecer** jogo, não um retângulo azul.
7. **Caixa de som** — cubo preto na parede/teto, 2–4.
8. **Letreiro** — `BAR DO ZÉ` + faixa amarelo/vermelho. Emissão alta. Na névoa é o que puxa o olho.
9. **Toldo** listrado sobre o vão.
10. **Lixeira / caixa de plástico / vassoura** no canto — 3 props, não 30.

Texturas 256 px, paleta curta, `tools/gerar_bar.py`. Materiais via tabela em `gerar_materiais.py`. **Não** rode o gerador e apague material de rua (já aconteceu). Se for regenerar, só acrescente linhas.

---

## Gente e som

- 2–4 NPCs sentados (reusa `Convidado` / papel sentado, como a casa da fumaça). Um atrás do balcão.
- TV com áudio baixo de estádio **ou** rádio AM. `AudioDirector`, loop curto. Sem música licenciada.
- Interação: entrar pelo vão; sentar é opcional. Save no telefone da parede, se o mercado já faz isso no balcão — **não** duplique o computador de CPF aqui.

---

## Critério de aceite (automatizar)

`python tools/verificar_bar.py` deve afirmar:

1. Existe porta `&"bar"` na malha comercial, sem ter comido mercado/casa.
2. Fachada tem letreiro + vão (não folha fechada).
3. Interior monta; superfícies exigidas: piso, teto, balcão, cervejeira, tv.
4. ≥ 4 cadeiras e ≥ 2 mesas **dentro**; ≥ 2 mesas no chunk da calçada.
5. Cabe pessoa em pé no vão e no salão (esfera 0,35 m).
6. Sair pelo vão devolve o jogador na calçada, desvio no plano < 0,4 m.
7. Ambiente troca para `bar` e volta ao sair.
8. Tris da planta entre 2500 e 18000.
9. Luzes ≤ 8.

Capturas (janela, **não** headless — shader):

```
--pular-abertura --fog=leve --entrar-bar --bar-cena=salao --shot=../captures/bar/salao.png --shot-frame=280 --shot-quit
--pular-abertura --fog=leve --ver-fachada-do-bar --shot=../captures/bar/rua.png --shot-frame=320 --shot-quit
```

Cenas mínimas: `rua`, `vao`, `salao`, `balcao`, `tv`, `calcada`.

Olho humano: da névoa tem que ler **AMARELO + VÃO PRETO + MESA NA CALÇADA**. Se ler como loja fechada ou como HIKARI, falhou.

---

## Orçamento e estilo

- Chunk da rua: teto **6000** tris (`verificar_cidade.py`). Fachada do bar + mesas de calçada cabem nisso. Placa, não caixa, onde o volume não se lê a 480×270.
- Máx **4 luzes dinâmicas no chunk** (skill psx-city). Letreiro e uma lâmpada sobre o vão. O resto é vértice.
- Paleta: amarelo sujo, vermelho de toldo, formica marrom, cimento, plástico amarelo, tubo de TV frio.
- Comentários só onde a restrição não é óbvia (vão sem folha, mesas no chunk vs interior, constante de afastamento).

---

## Como o mercado faz (leia antes de escrever)

```
game/src/world/mercado_builder.gd     planta + contrato
game/src/world/kit_mercado.gd         peças + AFASTAMENTO_PORTAO
game/src/systems/interiores.gd        _planta, props porta/computador
game/src/world/chunk_builder.gd       _porta_do_chunk, _fachada_de_loja
game/src/levels/teste_mercado.gd      medidas
tools/verificar_mercado.py            critério
```

TV: `game/src/render/televisao.gd`. Sentar: `convidado.gd` papéis. Porta/vão: `porta.gd` **não** é o modelo — o bar não gira folha na rua.

Validação: `GODOT --headless --path game --quit` sem `SCRIPT ERROR`. Depois as capturas com janela.

Pronto quando o teste passa **e** as três fotos (rua / vão / salão) leem como boteco brasileiro, não como sala amarela.

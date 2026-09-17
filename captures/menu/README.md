# Referência do menu — as seis telas, nos dois presets

Doze capturas, tiradas em 16/09/2026. Servem para a próxima sessão comparar antes
de mexer, que é a regra do `docs/PADROES-ENGENHARIA.md`.

## Como refazer, exatamente

```bash
GODOT=".tools/Godot_v4.7.2-stable_win64_console.exe"
R="$(pwd)/captures/menu"
for est in moderno ps1; do
  "$GODOT" --path game --resolution 1600x900 -- --estilo=$est --noite=cerracao \
    --ver-boot        --shot="$R/boot_$est.png"       --shot-frame=150 --shot-quit
  "$GODOT" --path game --resolution 1600x900 -- --estilo=$est --noite=cerracao \
    --ver-partida     --shot="$R/pico_$est.png"       --shot-frame=78  --shot-quit
  "$GODOT" --path game --resolution 1600x900 -- --estilo=$est --noite=cerracao \
    --ver-partida     --shot="$R/titulo_$est.png"     --shot-frame=340 --shot-quit
  "$GODOT" --path game --resolution 1600x900 -- --estilo=$est --noite=cerracao \
    --ver-carregar    --shot="$R/saves_$est.png"      --shot-frame=120 --shot-quit
  "$GODOT" --path game --resolution 1600x900 -- --estilo=$est --noite=cerracao \
    --ver-opcoes      --shot="$R/opcoes_$est.png"     --shot-frame=70  --shot-quit
  "$GODOT" --path game --resolution 1600x900 -- --estilo=$est --noite=cerracao \
    --ver-opcoes=som  --shot="$R/opcoes_som_$est.png" --shot-frame=70  --shot-quit
done
```

Cinco coisas dessa linha de comando não são opcionais:

- **`--estilo=`** — sem ela a captura lê o `settings.cfg` do usuário e duas
  máquinas fotografam presets diferentes achando que fotografam o mesmo.
- **`--noite=cerracao`** — o humor da mata é sorteado; sem fixar, a captura não
  compara com nada.
- **o caminho ABSOLUTO no `--shot`** — caminho relativo resolve contra `--path
  game`, e a captura vai parar em `game/captures/` sem avisar. Aconteceu aqui.
- **`--resolution 1600x900`** e não 1920x1080 — a janela pedida nem sempre é a
  janela obtida: com decoração e barra de tarefas, um pedido de 1920x1080 voltou
  como 1875x1055 numa das execuções, e referência que muda de tamanho sozinha não
  compara.
- **os quadros** — 150 é o boot montado; 78 é o pico da travessia (o START é
  disparado em 0,8 s e o pico cai em `TRAVESSIA/2` de `DURACAO`); 340 é o título
  já assentado, depois da cascata. Contam física a 60 Hz, então não dependem da
  máquina.

> Primeira execução não vale captura: os primeiros quadros são a cena montando
> (medido: 148,7 ms no primeiro, 6,1 ms em regime).

## O que estava medido no dia

Estrutura é o desvio da luminância depois de reduzir a imagem a 240 px de largura
— o grão vira média e o que sobra é forma. Ruído é o resíduo sobre a versão
borrada, na escala da própria captura. Estourado é a fração de pixels acima de
250, que é o que diz se o burst da travessia saturou.

| tela | preset | nativo | estrutura | ruído | estourado |
|---|---|---|---|---|---|
| boot | MODERNO | 1600x900 | 31,48 | 5,61 | 0,00 % |
| boot | PS1 STYLE | 480x270 | 27,41 | 8,39 | 0,00 % |
| pico da travessia | MODERNO | 1600x900 | 49,83 | 6,57 | 0,12 % |
| pico da travessia | PS1 STYLE | 480x270 | 46,09 | 12,02 | 0,07 % |
| título | MODERNO | 1600x900 | 28,23 | 4,77 | 0,00 % |
| título | PS1 STYLE | 480x270 | 25,91 | 7,81 | 0,00 % |
| espaços de save | MODERNO | 1600x900 | 28,43 | 4,63 | 0,00 % |
| espaços de save | PS1 STYLE | 480x270 | 26,02 | 7,69 | 0,00 % |
| opções · IMAGEM | MODERNO | 1600x900 | 81,09 | 3,92 | 0,00 % |
| opções · IMAGEM | PS1 STYLE | 480x270 | 81,06 | 6,10 | 0,00 % |
| opções · SOM | MODERNO | 1600x900 | 81,23 | 2,92 | 0,00 % |
| opções · SOM | PS1 STYLE | 480x270 | 81,23 | 4,54 | 0,00 % |

Três leituras que essa tabela permite, e que valem mais que as capturas:

1. **PS1 STYLE tem ~50% mais ruído e um pouco menos de forma**, nas quatro telas
   que mostram a estrada. É a relação que os dois presets têm de ter.
2. **As duas colunas não se comparam entre presets em pixel.** Em PS1 STYLE a
   janela inteira renderiza em 480x270 (`content_scale_mode = VIEWPORT`), então o
   arquivo sai com 480x270 de verdade — não é erro de captura — e o ruído dele
   mora numa grade quatro vezes maior. Comparar número de preset com número de
   preset foi o erro que a primeira rodada desta medição cometeu.
3. **A folha de OPÇÕES tem estrutura 81 nos dois presets**, contra 26 a 31 das
   telas de estrada. Papel claro ocupando metade do quadro é assim mesmo: a
   métrica mede contraste de forma, e uma folha branca sobre noite é o maior
   contraste do menu. Não confundir com "mais detalhe".

**O pico não satura em nenhum dos dois**, e essa era a pergunta em aberto: o burst
da travessia deixou de ser multiplicado pelo grão e passou a somar, e soma tem
teto. Medido: 0,12 % dos pixels acima de 250 em MODERNO, 0,07 % em PS1.

## O que não deu para medir

O **teste de identidade** do PS1 — a tela de hoje contra a de antes desta frente —
não roda: o `cidade.gd` do `HEAD` não compila contra o `kit_bar.gd` do diretório
de trabalho (`Cannot find member "LARGURA_VAO" in base "KitBar"`), porque outra
sessão está no meio de uma mudança ali. `git stash` dos meus arquivos devolve uma
árvore que não é nem o antes nem o depois.

O que sustenta o ramo PS1 enquanto isso é o código, não a foto: `CRT_BOOT_PS1` e
`CRT_TITULO_PS1` são literalmente os valores que estavam cravados em
`_aplicar_crt_boot` e `_aplicar_crt_menu` antes da dosagem existir. Quando o
`kit_bar` da outra frente assentar, o teste de identidade vale a pena.

# Handoff — dois pendentes da Praça da Matriz

Cole o bloco abaixo como primeira mensagem da nova sessão.

---

Você vai trabalhar num jogo de horror estilo PS1 em Godot 4 (renderizador
Compatibility) em `C:\Users\Administrator\Documents\Codes\Games\PSX`, branch
`feat/estrada-velha`. A cutscene da Praça da Matriz (o acordar, depois da cena
da estrada) já está dirigida e funcionando — leia `DIRECAO_PRACA.md` antes de
qualquer coisa, é a decupagem em vigor. Você vem fechar **dois buracos** que
ficaram, e os dois estão fora do arquivo do roteiro.

## AVISO — o repo tem várias sessões trabalhando ao mesmo tempo

`kit_parque.gd` e `parque_builder.gd` estavam sendo editados por outra sessão às
16:25 de 09/09. `abertura.gd` foi sobrescrito por outra sessão às 15:29 e
retomado depois. **Confira `git status` e o mtime dos arquivos antes de editar**,
e se um arquivo mudar sozinho no meio do seu trabalho não é bug seu — é merge
alheio. Arquivo novo sobrevive; edição em arquivo disputado, não.

---

## PENDENTE 1 — O calçamento está 3× mais claro que a referência

**É o defeito visual que sobrou.** Ele é o que faz a praça noturna ler como dia.

Medido em `captures/praca_matriz/cine/02_deitado_igreja.png` contra
`PRINTS/ref_praca_matriz/01_acordar.png`:

| Região | Print | Nosso | Situação |
|---|---|---|---|
| céu | (37,41,41) | (37.5,41.8,41.5) | fechado |
| névoa ao fundo | (50,54,52) | ok | fechado |
| **calçamento** | **(33,25,13)** | **(97,83,54)** | **3× claro** |
| fachada da igreja | (94,92,76) | (74,66,51) | baixa e quente demais |
| halo do poste | (190,173,97) | cone sólido branco | forma errada |

Note a inversão: na print a fachada (94) é **três vezes mais clara** que o
calçamento (33). No nosso, o calçamento (97) é mais claro que a fachada (74).
A luz está vindo do chão, e deveria vir da névoa e dos postes nas fachadas.

### O que já foi eliminado — não refaça

- **Não é `ambient_energy` do preset de névoa.** Testado com `0.0`: o calçamento
  não se move um ponto. O preset é `game/resources/fog/fog_praca_noite.tres`,
  aplicado por `FogController.PRESET_PRACA`.
- **Não é emissão do material.** `mat_pedra_parque.tres` tem
  `emission_energy = 0` e `tint = (1,1,1)`.
- **Não é modo unshaded.** `game/shaders/psx_surface.gdshader` declara
  `render_mode vertex_lighting, specular_disabled, shadows_disabled,
  diffuse_lambert, cull_back` — iluminação normal.

Ou seja: **`ambient_energy` deveria funcionar e não funciona.** Vale descobrir
por quê antes de mexer em outra coisa — pode ser que a resposta resolva sozinha.

### Onde procurar

- Piso da praça: `KitParque.piso(sup, &"pedra_parque", ...)`, chamado em
  `parque_builder.gd` nas linhas ~275 e ~870.
- `Y_CALCAMENTO := 0.22` em `kit_parque.gd:51` (a superfície da pedra fica aí
  acima do `onde.y` — importante para qualquer conta de altura).
- Os postes: os prints `[lampada] <nó> <energia>` no log saem de algum lugar da
  praça e é onde a outra sessão estava mexendo. Ache quem os cria.

### Como medir

```
.tools/Godot_v4.7.2-stable_win64_console.exe --path game -- --ver-praca
```

Escreve os cinco takes em `captures/praca_matriz/cine/`. Meça pixel cru numa
região conferida contra a imagem — **nunca ajuste no olho por cima de imagem
clareada**, esta cena já enganou duas vezes assim. Região usada nas medidas
acima, em `02_deitado_igreja.png`: calçamento `(150,150)-(260,180)`, fachada
`(90,45)-(180,95)`, céu `(300,35)-(420,55)`.

### Alvo

Calçamento em (33,25,13) e fachada em (94,92,76), com o céu ficando onde está.
Cuidado: o céu está calibrado e sai de `sky_color`; se você mexer nele para
consertar o chão, quebra o que já está certo.

O halo do poste é o segundo item: hoje é um **cone branco sólido apontando para
baixo**, quatro deles iguais e igualmente espaçados. Na print o poste é uma
lâmpada quente com brilho no vidro (190,173,97) e uma poça curta no chão. Cone
sólido é erro de PS1, não estética de PS1.

---

## PENDENTE 2 — O corpo lê como caixas nos dois primeiros takes

Nos TAKE 1 e TAKE 2 (ver `DIRECAO_PRACA.md`) o sujeito deitado é reconhecível
como forma humana, mas de perto vira caixa: um cubo bege de tronco, um cubo
laranja de cabeça, lascas finas de membro. **Isso é o rig, não o enquadramento**
— já foi tentado de todas as distâncias e ângulos.

Duas coisas já foram aprendidas e estão na decupagem; não repita nenhuma:

1. **Câmera baixa não resolve.** Um corpo deitado tem 18 cm de espessura e dois
   metros de comprimento: filmado da altura dele aparece a lâmina, doze pixels.
   Câmera baixa é para silhueta de quem está **de pé**; para quem está no chão o
   ângulo é **alto**.
2. **Detalhe fechado não resolve.** A mão desse boneco tem três caixas; a dois
   palmos da lente ela lê como caixa. O TAKE 2 hoje é um avanço lento de câmera
   justamente porque movimento não pede anatomia.

### O caminho que a referência aponta

`PRINTS/ref_praca_matriz/01_acordar.png` **nunca mostra o corpo deitado de
fora**. Ela resolve em primeira pessoa: a câmera está na cabeça dele e o que
aparece no rodapé do quadro são **os joelhos dobrados**, em silhueta escura
contra o calçamento. Você vê a praça inteira por cima deles.

Isso funciona porque joelho visto de cima, em silhueta e a meio metro da lente,
não precisa de anatomia — precisa de duas massas escuras com a forma certa.

**Tarefa:** montar esse plano de primeira pessoa e enfiá-lo na sequência.
Sugestão de lugar: entre o TAKE 0 (o olho abrindo, POV, já existe) e o TAKE 1 —
é a transição natural de "abri o olho" para "olhei o meu corpo".

Detalhe do código que atrapalha: `_plano_da_praca` faz
`_jogador.mostrar_corpo(false)` durante o POV, e há um comentário antigo dizendo
"sem props FP de pernas". Esse comentário descreve uma decisão que **está sendo
revertida** — a referência pede as pernas no quadro.

### Onde

- `game/src/levels/abertura.gd`, função `_plano_da_praca` (~linha 730).
- O corpo é `Corpo` (`game/src/render/corpo.gd`), pose
  `Postura.DEITADO_ACORDAR`, `_pose_deitado_acordar()`. Os joelhos já estão
  dobrados nessa pose exatamente para isto — o comentário dela diz
  "coxa+canela+bota separam no FP (ref 01)".
- O corpo é deitado por `_deitar(figura, true)` em `abertura.gd`, que gira o
  `Node3D` inteiro. **O giro é em torno dos pés**, que é a origem do `Corpo`.

---

## Coisas que valem para as duas tarefas

- **Meça antes de mexer.** Três rodadas de palpite perdem para uma medida que
  nomeia o culpado. Nesta mesma cena eu girei o `tint` do material da estrada em
  48% e o vermelho andou 12% — era o botão errado, e só a medida disse isso.
- **`get_aabb` não vale no Compatibility.** A imagem é a medida.
- **A face aparece do lado OPOSTO ao produto vetorial.** Já derrubou o chão
  inteiro da estrada e cinco carros.
- **Com `vertex_lighting` a luz só existe nos vértices.** Objeto fino sem
  subdivisão pode ser atravessado pelo cone de luz e continuar preto.
- **Degrau entre duas superfícies sem parede lateral não é degrau, é buraco.**
- **A 480×270 só sobrevive feição grande** — cerca de um quinto da célula da
  textura.
- `--mat-debug` pinta cada material de cor chapada sem sombreado nem névoa: **o
  que sair preto é buraco**. `--sem-ceu` esconde cúpula e serra. Os dois são
  permanentes e foi com eles que os defeitos anteriores foram nomeados.
- Headless não prova shader. Capture com janela.
- Contrato de render: 480×270 interno, `gl_compatibility`, `vertex_lighting`,
  `cull_back`, nearest, sem mipmap, dither de 15 bits, vinheta, scanlines.

## Estado

Nada commitado. `git status` tem muito untracked (`PRINTS/ref_*`, `PROGRESSO.md`,
`captures/`, `DIRECAO_PRACA.md`) — **não apague sem revisar**.

Comece rodando `--ver-praca` e comparando as cinco capturas com
`PRINTS/ref_praca_matriz/`. O que estiver bom não precisa de você.

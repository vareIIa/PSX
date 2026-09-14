# Direção — Sequência 2: Praça da Matriz

Briefing de direção + validação de roteiro para a cena que vem depois da estrada.
Escrito como decupagem: cada take diz **o que ele precisa dizer**, e só depois
onde fica a câmera.

> **Aviso de posse.** Em 09/09 15:29 outra sessão ("Cine Praça - Takes")
> sobrescreveu `abertura.gd` e está dentro de `_plano_da_praca` (deixou a versão
> anterior em `abertura.gd.bak_corpo_praca`). Este documento é para quem estiver
> com o arquivo na mão. Não aplique daqui sem combinar.

---

## 1. Premissa da sequência

Um homem acorda num lugar que não escolheu, sem a memória de como chegou.
A sequência responde três perguntas, nesta ordem:

1. **Onde eu estou?**
2. **O que aconteceu comigo?**
3. **Eu estou sozinho?** ← nunca é respondida. É o gancho para a cidade.

**Regra de ouro:** o corpo é o assunto até ele ficar de pé; a praça é o assunto
depois. A versão atual inverte — abre com a praça inteira a 11,5 m e o homem
some. A legenda "e eu acordo no meio de uma praça" toca sobre um quadro em que
não dá para achar quem acordou. Quando o texto precisa explicar o que a imagem
deixou de mostrar, o problema é da imagem.

---

## 2. Decupagem

### TAKE 0 — O OLHO (POV, ~4 s) — sem legenda

Preto. Duas piscadas: pálpebra 0,2 s fechada, 0,4 s aberta, repete. Névoa pura,
sem chão e sem horizonte — câmera a 18 cm da pedra olhando reto para cima.
Varre esquerda (1,0 s), segura, varre direita (1,35 s). FOV 70 → 68.

Na varredura para a direita, **um poste entra no canto do quadro**. É a primeira
informação de que existe um lugar, e ela chega pela imagem.

Cortar a legenda `"acorda": "..."`. Três pontos brancos sozinhos na tela não são
um plano — são o placeholder que sobrou.

### TAKE 1 — ELE (externo, ~4 s) — *"Última coisa que eu lembro era o farol na terra."*

Corte seco. **Plongée: câmera a 1,95 m, a 2,35 m do corpo, lente 55.**

> **Correção — este parágrafo dizia câmera baixa a 0,45 m, e estava errado.**
> Um corpo deitado tem 18 cm de espessura e quase dois metros de comprimento.
> Filmado da altura dele aparece a **lâmina** — doze pixels de nada, e a captura
> saiu sem sujeito nenhum no quadro duas vezes seguidas. Filmado de cima aparece
> o comprimento inteiro. **Câmera baixa é para silhueta de quem está de pé; para
> quem está no chão, o ângulo é alto.** Regra geral, não só desta cena.

**A igreja não entra ainda.** Guardar.

Único take estático da sequência. Ele ainda não se mexeu.

### TAKE 2 — O AVANÇO (~3 s) — *"Aí... apagou. Tipo, do nada."*

**Sem corte.** A câmera do TAKE 1 avança 80 cm em três segundos, lente 55 → 50.

> **Correção — este take era um detalhe da mão abrindo e fechando na pedra.**
> Ideia certa, rig errado: a mão deste boneco tem três caixas e a dois palmos da
> lente ela lê como caixa. O substituto é **movimento, que não pede anatomia**:
> aproximação lenta sobre um corpo parado é a gramática de "ele ainda está
> vivo?", e funciona com um sujeito feito de caixas porque quem atua é a lente.

### TAKE 3 — O LEVANTAR (externo, ~5 s) — *linha nova, ver §4.1*

**É o take que a cena existe para ter.**

Câmera a 4,5 m, altura **1,1 m — a altura em que ele TERMINA**, não onde começa:
ele sobe até a lente. Lente 52.

`_levantar(figura, 2.2)` já faz o certo: tween da raiz e `Corpo.levantar` no
mesmo relógio. O doc de `Corpo.levantar()` avisa por quê — relógios diferentes
fazem a mão largar o chão antes de o tronco terminar de subir, e o braço
atravessa a perna no meio do caminho.

Dois acréscimos:

- **A câmera recua 60 cm durante a subida.** Recuo lento contra um corpo que sobe
  faz ele crescer no quadro sem a lente mexer. É o oposto de um zoom.
- **O susto é um passo perdido.** Ao chegar de pé, o corpo recua 25 cm em 0,3 s
  com `EASE_OUT`. O olho lê como quem perdeu o equilíbrio. Sem isso o levantar é
  atlético, e atlético não é assustado.

### TAKE 4 — OLHA EM VOLTA (externo, ~4 s) — *"Cadê o carro? Cadê a estrada?"*

Contra-plongée leve: 2,8 m, altura **1,35 — abaixo do olho dele**. Aqui ele é
maior que a praça, que é o oposto de todo o resto da sequência, e é o único take
em que isso vale.

Cabeça esquerda → direita → esquerda em **três tempos desiguais** (0,5 / 0,8 /
0,4). Tempos iguais leem como metrônomo.

A câmera acompanha o segundo giro num pan curto e **para antes dele**. A câmera
perder o sujeito é o que faz o plano parecer procurado em vez de coreografado.

### TAKE 5 — A IGREJA (externo, ~5 s) — *"Isso aqui não é a pousada. Nem de longe."*

**A revelação, e é por isso que a igreja ficou guardada até aqui.**

Contra-plongée da base da fachada: câmera a 1,0 m do chão, 9 m da igreja, lente
58, inclinada para cima. Torre e cruz entram contra a névoa. Ele aparece em
silhueta no canto inferior esquerdo, de costas, pequeno.

Corta direto para a cidade. Sem fade — a cena não terminou, ela foi interrompida.

---

## 3. Regras que valem para a sequência inteira

- **A altura da câmera DESCE enquanto ele sobe:** 0,18 / 1,95 / 1,72 / 1,10 /
  1,35 / 1,30. A lente começa acima dele, que está no chão, e termina na altura
  dos olhos dele, que ficou de pé. A troca de quem domina o quadro acontece pela
  altura da câmera, e não por corte de tamanho — é por isso que o levantar pesa.
- **Regra dos 180°.** A linha é o corpo dele. A câmera não atravessa: se o TAKE 1
  está do sul, o TAKE 4 pode ir ao leste, nunca ao norte.
- **A legenda entra 0,4 s DEPOIS do corte.** Imagem limpa primeiro. Legenda junto
  com o corte faz o jogador ler antes de ver.
- **Uma legenda por take.** Já é assim; manter.
- **A luz de poste é halo, não holofote.** Medido em `01_acordar.png`: o halo do
  poste dá (190,173,97) e o chão embaixo dele dá (33,25,13). Cone sólido branco
  apontando para baixo é erro de PS1, não estética de PS1.

---

## 4. Validação de roteiro

Ordem completa: 9 falas na estrada, 6 na praça, 10 na cidade.

### 4.1 Continuidade

| Onde | Fala | Problema | Correção proposta |
|---|---|---|---|
| praça | `"acorda": "..."` | Placeholder. É a única coisa na tela no TAKE 0. | **Cortar.** A piscada carrega o beat. |
| praça | *"E eu acordo no meio de uma praça."* | **Narra a imagem.** O jogador está vendo exatamente isso. | *"Isso aqui é uma igreja. Que igreja é essa?"* — dá informação nova e arma o TAKE 5. |
| cidade | *"São Thomé, a galera, a pousada... tudo sumiu da minha cabeça."* | **Contradiz.** Ele nomeou São Thomé (estrada 2), a pousada (estrada 8 e praça 5) e a galera (estrada 8) minutos antes, corretamente. | *"Da estrada até essa praça não tem nada. Só apagado."* — a amnésia passa a ser do trecho, que é o que a história quer. |
| cidade | *"Sem maldade, eu não reconheço nada disso."* | **Repete a abertura** de `dentro_1`, que é a frase-chave do jogo. Duas vezes em dez linhas gasta o bordão. | *"Eu não reconheço nada disso. Nem o cheiro."* |
| cidade | *"Tô preocupado pra saber como vou sair daqui."* e *"Quero sair daqui logo..."* | **Mesma ideia** abrindo e fechando o bloco final. | A primeira vira consequência: *"Não tem sinal. Não tem placa. Não tem ninguém pra perguntar."* |

### 4.2 Tom

- *"E tem blitz na saída. Claro que tem."* — a piada derruba o pavor que as duas
  linhas anteriores construíram. Se a blitz é sorteada, a fala pode ainda tocar
  sobre nada. Sugestão: *"Blitz. A essa hora, nessa cidade."*
- *"Tenho uns quarenta reais no bolso." / "E tô morrendo de fome."* — é tutorial
  vestido de pensamento, e cai logo depois do beat de horror. Funciona como
  motivação da primeira missão; só precisa vir **depois** do bloco da casa.

### 4.3 Acentuação — metade corrigida

As falas estavam em ASCII: *"Sao Thome"*, *"nao"*, *"ja"*, *"Ai"*, *"Cade"*,
*"praca"*. Não é limitação de fonte: `psx_titulo.fnt` e `psx_mono.fnt` têm os 152
glifos, com á, ã, ç, é, ê, í, ó, ú e õ — e o `á` mede 10×14 contra 10×10 do `a`,
ou seja o acento está no bitmap. O próprio HUD já escrevia "PRAÇA DA MATRIZ" com
cedilha na mesma tela.

- **Feito:** as 9 falas de `abertura_estrada.gd`.
- **Falta:** as 16 de `abertura.gd` (praça + cidade) — arquivo em uso por outra
  sessão.

---

## 5. Alvos medidos das prints

De `PRINTS/ref_praca_matriz/01_acordar.png`:

| Região | Alvo | Estado |
|---|---|---|
| céu | (37,41,41) | **(37.5, 41.8, 41.5)** — fecha |
| névoa ao fundo | (50,54,52) | ok |
| fachada da igreja | (94,92,76) | (74,66,51) — baixa e quente demais |
| calçamento | (33,25,13) | **(97,83,54)** — 3× claro; é o que faz a cena ler como dia |
| halo do poste | (190,173,97) | cone sólido, não halo |

O calçamento e os postes estão em `kit_parque.gd` / `parque_builder.gd`.
`ambient_energy` do preset **não tem efeito** nessa cena — testado com 0,0, o
valor não se move. Quem acende a pedra são os postes, e é lá que se resolve.

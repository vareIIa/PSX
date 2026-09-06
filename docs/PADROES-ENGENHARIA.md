# PADRÕES DE ENGENHARIA

> O que "profissional e robusto" significa em termos verificáveis neste projeto.
> Versão 1.0 — 06/09/2026

---

## A tensão entre "AAA" e "PSX"

Produção AAA e estética PSX puxam para lados opostos, e confundir os dois mata o
projeto. A tese do gênero, e deste plano, é que o PSX horror ganha justamente por
**não** competir em valor de produção. Então "AAA" aqui nunca significa mais
polígono, mais efeito ou mais conteúdo.

Significa o rigor de engenharia de um estúdio grande aplicado a uma apresentação
deliberadamente limitada:

| AAA aqui significa | AAA aqui não significa |
|---|---|
| Nada entra sem validação automatizada | Mais polígonos |
| Todo número vem de um documento canônico | Iluminação moderna |
| Sistema testável isolado do conteúdo | Mundo maior |
| Performance medida, não estimada | Mais sistemas |
| Zero warning no build | Mais horas |

## Definição de pronto

Uma tarefa só está pronta quando as cinco condições valem. Não existe "pronto, só
falta". Se falta, não está pronto.

1. `--headless --quit` roda sem erro e **sem warning** no stdout.
2. Se mexeu em shader ou visual, a captura automatizada foi gerada e comparada com a
   print de referência correspondente.
3. Todo valor numérico de estética veio do ART-BIBLE, com o nome da seção no
   comentário. Nenhum número mágico solto no meio da lógica.
4. Script novo tem tipagem estática completa. Sem `Variant` implícito.
5. O commit descreve o que mudou e por quê, não só o quê.

## Validação automatizada

Três níveis, do mais barato ao mais caro. Rode sempre o mais barato que cobre a
mudança.

```bash
# 1. Sintaxe e carga de recurso — segundos, roda a cada mudança
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --quit

# 2. Suíte de asserções — valida contrato do ART-BIBLE contra o projeto real
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/run_tests.gd

# 3. Captura visual — abre janela, compila shader, grava PNG e sai
.tools/Godot_v4.7.2-stable_win64_console.exe --path game -- --shot=out.png --shot-frame=30
```

O nível 3 é o único que compila shader de verdade. Headless não compila. Qualquer
mudança em `.gdshader` exige nível 3, sem exceção.

## Regras de código

**Tipagem estática obrigatória.** `var hp: int = 3`, `func mover(delta: float) -> void:`.
GDScript sem tipo não avisa erro em tempo de carga, e o objetivo do nível 1 de
validação é justamente pegar erro antes de rodar.

**Constante no topo, citando a fonte.**

```gdscript
## ART-BIBLE secao 3 — grade de snap = metade da resolucao interna
const SNAP_RESOLUTION := Vector2(240.0, 135.0)
```

**Sem `get_node` com caminho relativo longo.** Referência distante vem de autoload ou
de `@export`. `get_node("../../../Player")` quebra na primeira reorganização de cena.

**Sinal no passado, verbo no presente.** `item_picked_up` para sinal, `pick_up_item`
para método.

**Recurso em vez de constante espalhada.** Preset de névoa, dado de item e curva de
tuning viram `.tres`, editáveis sem recompilar e diffáveis no git.

## Estrutura de teste

`tests/` fica dentro de `game/`, roda headless e não entra no build final. Cada teste
é uma função que retorna `bool` e imprime a falha.

O que a suíte cobre desde a Fase 1:

- Todo preset de névoa carrega e tem começo menor que fim.
- O horizonte de streaming de cada preset é maior ou igual ao fim da névoa.
- A cor de fundo do ambiente é igual à cor da névoa, que é a regra da linha de horizonte.
- Resolução interna do projeto bate com a do ART-BIBLE.
- Renderizador é `gl_compatibility`.
- Filtro de textura de canvas é nearest.
- Todo `.gdshader` referenciado por material existe no disco.

Teste que verifica configuração de projeto parece burocracia até alguém trocar o
renderizador sem querer e o look inteiro mudar sem ninguém notar por três dias.

## Performance

Medida, nunca estimada. `Performance.get_monitor()` gravado num overlay de debug
ligado por `F3`, mostrando fps, draw calls, primitivas e memória de vídeo. Os tetos
estão no ART-BIBLE seção 10.

A medição vale só em build de release exportado. O editor adiciona overhead que
distorce draw call e frame time.

## Git

Um commit por unidade lógica. Mensagem no imperativo, primeira linha com no máximo
72 caracteres, corpo explicando a decisão quando houve decisão.

Branch `main` sempre passa no nível 1 e no nível 2. Trabalho que quebra a validação
vive em branch próprio.

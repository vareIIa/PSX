# Refs — Capela azul e Cruzeiro da Praça da Matriz

As três prints que o mapeamento do `PROMPT_IGREJA_MATRIZ.md` usa. **Os arquivos
de imagem ainda não estão aqui** — eles vieram coladas no chat. Salve com estes
nomes exatos, que são os que o prompt cita:

| Arquivo | Conteúdo | O que sai dela |
|---|---|---|
| `01_capela_frontal.png` | Capela branca e azul de frente, de dia, gramado na frente, anexo baixo à direita, palmeiras atrás | **A fachada inteira.** Cunhais, cornija, porta, as duas sacadas, janela do frontão, cruz do cume, cachorros do beiral |
| `02_cruzeiro_historico.png` | Foto antiga colorizada: cruzeiro com os Instrumentos da Paixão e uma multidão, capela ainda sem pintura ao fundo | Prova que o cruzeiro **domina** a praça — de perto ele parece maior que a capela |
| `03_cruzeiro_hoje.png` | Cruzeiro sobre pedestal em degraus, guarda-corpo rústico de madeira, canteiros, piso de placas de concreto, capela azul ao fundo à direita | **A principal.** O cruzeiro peça a peça, o piso da praça e a cerca de tora |

## O que é azul, e só isso

Cunhais dos cantos · cornija sob o beiral · porta dupla e sua moldura · as duas
sacadas (laje, balaustrada e molduras das janelas) · janelinha do frontão ·
porta e janela do anexo.

Parede caiada branca, telha cerâmica alaranjada, cantaria clara em volta da
porta. **A capela não tem torre na frente** — a sineira do jogo foi para o canto
traseiro oeste por causa disso.

## Atenção ao azul do jogo

O azul implementado **não é** o `#4FA8D8` da foto: é `#2f93cf`, mais saturado.
A cena é 23:15 e as duas lanternas da porta são `ffc978`, cuja componente azul
vale menos da metade da vermelha — com o azul da foto o cunhal renderiza
**laranja**. A conta está escrita em `KitParque`, na constante `AZUL`.

Ordem no jogo: Estrada Velha → preto → abertura na praça → primeira missão.
HUD alvo: `LOCAL: PRAÇA DA MATRIZ` / `HORA: 23:15`.

Refs vizinhas: `PRINTS/ref_praca_matriz/` (o acordar, o coreto, a vista da praça).

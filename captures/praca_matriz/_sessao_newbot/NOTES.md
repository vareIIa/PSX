# Sessao New Bot — igreja colonial vs refs

## Meta
PRINTS/ref_praca_matriz (capela branca, torre esq, porta no muro, cruz no frontao).

## Mudancas
- kit_parque.igreja_matriz: removeu portal freestanding +1.4m, cruz punch mid-air e rim janela_acesa.
  Porta escura flush na fachada, plinto baixo, cruz pequena no frontao, torre a esquerda, face clara.
- parque_builder: igreja nudge sul (offset -1.5 -> +0.8) p/ porta ~6m do pin (antes ~8m sem portal).
  Lanternas da porta alinhadas; facho=false (cone comia a fachada no denso).
- abertura.gd: cams praca_1 / praca_5 olham mais norte/alto.

## Provas
- before: captures/praca_matriz/cine/ (backup em _sessao_newbot/before_*)
- after mapa: mapa_eixo_denso2.png / mapa_eixo_denso3.png
- after cine: after3_02.png, after3_praca_5.png

## Ainda aberto
- Torre/janelas ainda fracas no fog=denso vs ref 02
- Cine takes ainda lavados vs silhueta colonial da print
- menu.gd de outra sessao estava quebrado; restaurado do HEAD nesta sessao

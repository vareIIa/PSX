# 08 — Sistemas de jogo

> Inventário, missão, save, conversa, celular, GPS, plantio, rádio, pausa.
> Cada um hoje é “um humano”. Aqui, o que vira compartilhado e o que continua pessoal.

## 1. Inventário e vida — pessoais (P8)

`game/src/systems/inventario.gd` autoload: 8 slots, vida 100, catálogo de `.tres`.

Fase 2/3 (ver `06` §6): estado por Player. Catálogo (os `.tres`) continua global — é disco, não sessão.

| Ação | Quem decide | O que o outro vê |
|---|---|---|
| Pegar item no chão | host, primeiro pedido válido | item some; só a mochila de quem pegou ganha |
| Usar bandagem | local, host confirma vida | o corpo do parceiro não “usa”; vida replica se cair |
| Morrer / desmaio | host no 0 de vida | apagão **local**; o parceiro vê o corpo; não reseta a sessão |
| Dar item ao parceiro | fora da v1 | — |

Sinal `feriu`: só a HUD de quem levou escuta. O parceiro pode ver um flash no `Corpo` (pose), não a faixa.

## 2. Missão — compartilhada (P7)

`missoes.gd`: uma `atual`, etapas, ouve GPS e Interiores.

Em coop:

- Host chama `comecar` no fim da intro (como hoje, depois da abertura).
- `missao_atualizou` para o convidado.
- Marcar destino no GPS: **qualquer um** pode cumprir a etapa “marcar a casa” — o primeiro que marca, a etapa avança para os dois.
- Entrar na casa: os dois (regra de interior, `07`).

HUD (`hud_missao.gd`): os dois leem o mesmo texto. Distância: de **cada** corpo até o alvo (número diferente nas duas telas, objetivo igual).

Não duplicar a missão no save do convidado.

## 3. Save — host (P9)

`save_game.gd` v2: jogador, inventario, mundo, visitados, registro, nevoa, missao, hora.

v3 (coop) acrescenta, **sem quebrar v2**:

```
"sessao": {
  "modo": "coop" | "solo",
  "seed": int,
  "parceiro": { "steam_id": "", "nome": "", "ficha_id": 0 } | null
}
```

Regras:

- Só o host chama `salvar`.
- CONTINUAR no título: se o save é coop e o parceiro não está, entra **solo** no mesmo mundo (P11). O campo `parceiro` vira histórico.
- Convidado não tem `user://save_*` desta viagem.
- `nevoa` no save é o preset do host. Cada um aplica o look que quiser ao carregar; o campo fica para solo.

Ponto de save no mundo (`ponto_de_save.gd`): os dois precisam estar perto, ou só o host salva e ponto. v1: **host salva**, como um descanso. O convidado vê a animação.

## 4. Conversa e diálogo — um falante

`conversa.gd` / `dialogo.gd`: `ativo`, travam o player, CanvasLayer.

v1:

- `pedido_falar` → host aceita se ninguém está falando com aquele NPC.
- Quem falou trava e vê a caixa.
- Parceiro: o NPC fica ocupado (não dá E), faixa “fulano está falando com MARIA SILVA”. Sem a caixa inteira na tela do outro (privacidade barata e menos UI).
- Cinema / morador da casa da fumaça no plano da abertura: cinema travado, os dois assistem (P10).

Assuntos que mudam o mundo (“contratar serviço”, plantio): o host aplica o efeito, os dois veem o mundo mudar, só um leu a fala.

## 5. Celular, documento, GPS, terminal — tela local

Consulta de CPF é função pura (`RegistroCivil`). Não precisa de rede.

GPS:

- Rota desenhada: local (cada um traça a sua).
- Etapa de missão “marcar o destino”: o pin da missão é compartilhado (já é o alvo de `Missoes`).
- Minimapa: centro = local; **ponto do parceiro** (ícone pequeno, cor da tinta de destaque). Sem isto o leash de 80 m é crueldade.

Celular “logado” como a ficha do local. Agenda de abordados: **união** no `RegistroCivil` da sessão, ou pessoal. v1: **pessoal** (cada um abordou quem abordou). Missão não depende disso.

Terminal / mercado / caixa: host confirma a compra (tira dinheiro do inventario daquele peer, spawna item). Os dois não pagam a mesma cerveja duas vezes.

## 6. Plantio

`plantio.gd` / `plantacao.gd`: mundo. Host: plantar, regar, crescer (relógio do host), colher. Cliente manda pedido se está no alcance. Visual da planta: ou B (seed + estado no WorldState) ou D (estado: estágio, água). Preferir WorldState `{canteiro_id: {estagio, agua}}` — já é o espírito do arquivo.

## 7. Rádio do carro

`RadioCarro` autoload. Se os dois estão no mesmo carro, a estação é do **carro** (host). Roleta: quem está no banco do passageiro também pode girar? v1: **só o motorista**, para não brigar. O passageiro ouve.

Fora do carro: rádio de chiado do `Player` (`radio: Radio`) é local.

## 8. Pausa e prancha

Hoje ESC abre a prancha e o menu de sistema usa `PROCESS_MODE_ALWAYS`; a árvore pausa.

Em coop **a árvore não pausa**.

- ESC local: prancha overlay, input do local travado, mundo anda, o parceiro vê o corpo parado.
- “Encerrar viagem” na prancha do host: `sessao_encerrada`.
- Convidado: “Sair da viagem” → ele cai, host segue (P11).

Opções de vídeo (incluindo o futuro toggle PSX/Vulkan) são locais e já vivem em `Settings`. Não replicar.

## 9. Áudio

`AudioDirector` local.

- Passo do parceiro: derivado da velocidade replicada (já há sinal `passo_dado` no Player — no remoto, tocar se dist < 20 m).
- Motor do carro: no nó do carro, 3D, os dois ouvem.
- Falas da intro: legendas iguais (cinema); se um dia houver VO, o host dispara o mesmo `tocar` nos dois no `plano_de_cinema`.
- UI beeps: local.

## 10. Relógio e HUD LOCAL/HORA

Hora: host. Local: “PRAÇA DA MATRIZ” etc. pode ser o chunk do **local** (os dois a 80 m podem estar em ruas com nomes diferentes). O cartão de missão é que é igual.

## 11. Mercado, bar, estufa, casa da fumaça

São interiores + NPC + às vezes economia. Recaem nas regras já escritas:

- entrar: `07` interiores
- falar: um falante
- comprar / plantar: host
- TV, sinuca, cervejeira: WorldState se o estado importa para os dois; senão local (TV como look)

Não fazer netcode especial por kit. Se o objeto já é `Interativo`, o pedido cabe em `pedido_porta` / um `pedido_usar` genérico com `node_path`. Preferir **um** RPC `pedido_usar` a dez especiais, com o host despachando para o script do objeto.

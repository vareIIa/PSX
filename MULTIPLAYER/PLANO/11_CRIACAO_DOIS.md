# 11 — Criação de dois personagens

> A carteira já é o melhor menu do jogo. Não substituir. Só deixar os dois passarem por ela sem um apagar o outro.

## 1. O que existe

- `ficha_cadastro.gd`: nome, assinatura. Emite a ficha via `RegistroCivil.criar_jogador`.
- `criacao.gd`: abas ROSTO/CABELO/ROUPA/…, SubViewport com `Corpo` real, `confirmou`.
- Comentário em `cidade._novo_jogo`: se emitir outra ficha depois da carteira, o jogador “começa a partida como outra pessoa”. Este bug voltará em 2P se o host chamar `criar_jogador` de novo no `viagem_comecou`.

## 2. O que muda

Cada peer tem a sua ficha, gravada **no roster da Sessao**, não num `RegistroCivil.jogador` global único.

Ordem no coop:

1. Entra no lobby (folha).
2. Se este peer ainda não tem ficha na sessão → NOME → APARENCIA (os painéis que já existem).
3. `confirmou` → manda aparência + nome no roster (`pedido` ao host / metadata Steam).
4. Volta à folha com retrato vivo.
5. O outro pode ainda estar na carteira. A folha espera.

Não: os dois na carteira **ao mesmo tempo na mesma tela**. Cada processo mostra a carteira **local**. A folha do outro mostra “NA CARTEIRA”.

## 3. Sincronizar aparência **antes** da intro

O plano 1 da Estrada Velha precisa dos dois `Corpo` no Marea. Se a aparência chegar no primeiro quadro da praça, o rasante mostrou dois bonecos genéricos e o pedido “desde o começo” falhou.

Contrato:

- `viagem_comecou` só dispara com as duas `aparencia` no roster.
- Payload: o Dictionary de `Aparencia` (células + cores). É pequeno.
- `CarroCena` / spawn lê `Sessao.roster[peer].aparencia`.

## 4. `RegistroCivil` no coop

- `criar_jogador` local gera id, CPF, etc. como hoje (sorteio).
- Host **não** resorteia o convidado. A ficha que o convidado mandou é a verdade.
- Colisão de id (dois sortearem o mesmo entre 100 milhões): irrelevante na prática; se quiser, host incrementa.

`RegistroCivil.jogador` em cada processo = ficha **local**, para celular/prancha/documento não quebrarem.

## 5. Continuar / save

CONTINUAR é solo (P9, P16). Não passa na carteira.

Um dia “convidar no save”: o convidado faria a carteira e apareceria na praça / no último ponto. Fora da v1.

## 6. Nome igual

Dois “JOSE” podem. O lobby distingue pelo retrato e pelo papel MOTORISTA/PASSAGEIRO. Não forçar apelido único.

## 7. Aceite

- Host e convidado saem da carteira com rostos diferentes.
- Folha mostra os dois.
- Intro plano 1: as duas silhuetas batem com as carteiras (captura lado a lado com `captures/criacao/`).
- Single NOME→APARENCIA→estrada: bit-idêntico em comportamento.

# 11 — Criação de personagem com N jogadores

> **Versão 2.0 — 21/09/2026.** Revisado. A 1.0 era "dois personagens" e mandava a aparência pelo *roster* do lobby Steam. Na v2 a aparência já viaja **na autenticação** (Fase 1, medido), e são N jogadores.
> A carteira é o melhor menu do jogo. A rede não a substitui: só deixa cada um passar pela sua sem apagar a de ninguém.

## 1. O que existe

| Peça | O que faz | Onde |
|---|---|---|
| `RegistroCivil.criar_jogador(nome)` | sorteia um **id** (`relógio ⊕ randi`), monta a ficha, põe só o primeiro nome digitado | `registro_civil.gd:733-754` |
| `RegistroCivil.identidade(id)` | a ficha inteira a partir do id: **função pura** (`_h(id, n)`, nenhum `randi`) | `:440-469` |
| Ficha | id, nome, sexo, idade, nascimento, naturalidade, mãe, pai, CPF, RG, profissão, endereço, `cx`, `cz`, personalidade… | `:440-466` |
| `Aparencia.de_ficha(ficha)` | 31 chaves (altura, rosto, pele, cabelo, camisa, calça, chapéu, passo, voz…); lê só `id`, `sexo`, `idade`; pura | `aparencia.gd:139`, `:175-222` |
| Ajustes da carteira | 14 chaves que o jogador muda (rosto, pele, cabelo e cor, camisa, casaco, calça, chapéu, altura, gordura) | `aparencia.gd:348` |
| `CriacaoAparencia` | a carteira: abas, `Corpo` real num `SubViewport`, `confirmou` | `criacao.gd:26`, `:95` |
| `FichaCadastro` | o nome e a assinatura; os campos 02–04 vêm travados e sorteados | `ficha_cadastro.gd:431` |
| Save | guarda só `jogador` (id), `nome`, `ajustes` (cores em HTML) e `conhecidos` | `:803-815` |

## 2. Na rede, hoje (Fase 1)

- Cada um faz a **própria** carteira, na própria máquina, como no solo.
- A aparência (as 31 chaves, **912 B**, medido) e o nome vão no pedido de entrada (`20` §2).
- O servidor **saneia** chave por chave: só as chaves conhecidas, cada número preso na faixa (`ProtocoloRede.FAIXAS_APARENCIA`), cor de volta a `Color`. O cliente saneia de novo o que recebe.
- O boneco do outro é montado com o mesmo `Corpo.montar(aparencia)` dos NPC.

Nada disso depende de lobby. Quem entra no meio da sessão chega com a própria roupa (foto `convidado_ve_anfitriao.png`).

## 3. Decisões

### 3.1 A aparência é de quem a escolheu

O servidor não sorteia, não corrige e não troca a aparência de ninguém. Ele só **prende em faixa** o que chegou. Um jogador com cliente adulterado consegue, no máximo, o maior chapéu e a maior altura que a carteira já permite.

### 3.2 A ficha não sai da máquina

A ficha do jogador tem mãe, pai, CPF e endereço. São dados de ficção, mas são **a pessoa que o jogador é** no jogo, e nada do jogo do outro precisa deles. Viajam só o nome (o primeiro, ou o `--mp-nome`) e a aparência.

**Alternativa medida e descartada, por enquanto:** mandar `{id, ajustes}` em vez das 31 chaves. Seriam uns 200 B, e o outro reconstruiria a aparência com `identidade(id)` → `de_ficha` → `com_ajustes`, tudo puro. Economiza 700 B **uma vez por entrada**, o que não importa, e expõe o id, que dá a ficha inteira. Fica registrado para o dia em que a entrada precisar caber num pacote só.

### 3.3 Nome

- Vale o primeiro nome da ficha. `--mp-nome` e o campo do F7 trocam.
- Saneado: sem controle, até 24 caracteres (`ProtocoloRede.NOME_MAX`).
- **Nomes iguais podem.** Dois "JOSE" são duas pessoas. Na lista de jogadores e no chat, o segundo aparece como "JOSE (2)", pelo id da sessão; na cabeça do boneco, só "JOSE". O retrato e a roupa distinguem.

### 3.4 Quando a carteira muda no meio da sessão

Hoje o jogo não tem guarda-roupa: a carteira só abre no NOVO JOGO. Se um dia abrir (espelho em casa, loja de roupa), a troca vai por `_pedir_perfil(aparencia)` → o servidor saneia → `_perfil_mudou(id, perfil)` para todos, e o `AvatarRemoto.aplicar_perfil` remonta o corpo só se a aparência mudou de fato (`hash`, já implementado).

### 3.5 Persistência no dedicado (Fase 6)

O perfil guardado pelo token (P21) é **mochila, vida, posição, grupo**, e não a aparência. A aparência vem sempre do cliente, na entrada: quem começou um NOVO JOGO com outra carteira entra no dedicado com a cara nova e a mochila antiga. É o comportamento de "mesma conta, personagem trocado", e evita o servidor guardar uma aparência que o jogador já não tem.

## 4. A carteira antes da viagem junto

Para a intro co-op (`12`), a aparência precisa estar **no servidor antes do primeiro plano**: o plano 1 da Estrada Velha mostra quem está no carro.

```
Folha de viagem (10 §6)
  ├─ sem carteira → NOME → APARENCIA → volta à folha
  ├─ a folha dos outros mostra "NA CARTEIRA" nesse retrato
  └─ PRONTO só existe com carteira; ASSINAR só com todos PRONTO
```

Cada processo mostra **a sua** carteira. Não há carteira "dos cinco numa tela".

## 5. O defeito que volta se ninguém olhar

`cidade._novo_jogo` só cria a ficha se não houver uma (`if RegistroCivil.jogador.is_empty()`). O comentário diz por quê: emitir outra ficha depois da carteira faz o jogador "começar a partida como outra pessoa".

Em rede, o risco é qualquer caminho novo (entrar pelo título, folha de viagem) chamar `_novo_jogo` **e** `criar_jogador` numa ordem diferente. Regra: **a carteira é feita uma vez, antes de qualquer conexão**, e o caminho online chama o `_novo_jogo` de sempre, que respeita a ficha existente.

## 6. Aceite

| Prova | Como |
|---|---|
| Aparências diferentes | três processos, três carteiras; cada um vê os outros dois com a roupa certa (foto lado a lado com a captura da carteira de cada um) |
| Saneamento | bot manda altura 50 e cor inválida: o boneco sai na altura máxima e na cor padrão; servidor sem ERROR (nível 2 já cobre `sanear_aparencia`) |
| Nome igual | dois bots "JOSE": lista mostra "JOSE" e "JOSE (2)" |
| Não trocar a pessoa | entrar pelo título com carteira feita: `RegistroCivil.jogador.id` igual antes e depois da entrada |
| Solo | NOME → APARENCIA → estrada: igual ao HEAD |

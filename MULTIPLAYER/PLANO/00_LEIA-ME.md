# 00 — Leia-me

> Bíblia de execução do multiplayer de *Névoa e Dither* / SHIMOKAWA.
> **Versão 2.1 — 21/09/2026, noite.** Substitui a 1.0 (14/09). A 2.1 reescreve os capítulos técnicos 04–12 contra o código (a 2.0 só tinha revisado 00–03 e 13–21) e registra a Fase 2 em parte, medida.
> Contra o código em `playable` (HEAD `dcc662e` + working tree), Godot 4.7.2.

## O que mudou da 1.0

| 1.0 (14/09) | 2.0 (21/09) |
|---|---|
| Co-op de **2** | **N**: 8 no "abrir para amigos", até 32 no dedicado (P1) |
| Anfitrião = servidor, sempre jogando | Servidor com **ou sem** jogador: HOSPEDANDO e DEDICADO, mesmo protocolo (P2) |
| Steam como base; ENet só para desenvolvimento | **ENet como base** (LAN, Hamachi, Radmin, dedicado); Steam opcional (P3) |
| Um `Player` por peer via `MultiplayerSpawner` | Jogador local intocado; os outros são **bonecos** (`AvatarRemoto`) (`03` §4) |
| Interpolação do `MultiplayerSynchronizer` | Não existe no 4.7.2; buffer próprio, **0,1 cm** medido (`19`) |
| Host cai → convidado volta ao título | Cada um continua sozinho no próprio mundo (P11) |
| Plano | **Fase 1 implementada e medida; Fase 2 em parte** (`13`): lanterna que aponta para onde o outro olha, carro do outro de farol aceso, minimapa com os amigos, pausa que não congela ninguém, cidade diferente recusada |

## O que isto é

O plano passo a passo, mais o registro do que já foi feito e medido. Cobre:

- o estado real do repo (`01`) e o que o código impõe (`19` §1);
- as decisões de produto (`02`) e a arquitetura (`03`);
- o protocolo byte a byte (`20`) e o contrato do mundo (`04`);
- o servidor dedicado de ponta a ponta (`18`);
- como jogar junto hoje: LAN, Hamachi, dedicado (`21`);
- cada sistema do jogo que ainda assume um jogador (`06`–`12`);
- as fases com estado, os testes e o que é proibido (`13`–`17`).

## A tese em uma página

*Névoa e Dither* é survival horror de exploração numa cidade procedural de chunks de 32 m, com relevo e interiores. A cidade é **determinística**: sai da coordenada, e não viaja na rede. Viajam as pessoas e, a partir da Fase 3, o que elas mudam.

O multiplayer que cabe aqui é **amigos e servidores pequenos**, e não MMO nem competitivo:

```
servidor autoritativo (peer 1)
 ├─ HOSPEDANDO: o jogo aberto para amigos        ← LAN, Hamachi, Radmin, porta aberta
 └─ DEDICADO:   o mesmo servidor, --headless      ← VPS, container, PC ligado
        │ ENet UDP 24567, autenticação antes do peer existir
        ▼
cliente: o Player de sempre + bonecos dos outros, desenhados 120 ms no passado
```

As três ideias que fazem isso funcionar neste código, e não num código genérico:

1. **O jogador local não muda.** 43 lugares procuram "o jogador" pelo grupo, e `cidade.gd` fala com ele em 193 linhas. Os outros jogadores são bonecos fora do grupo, então nenhum desses pontos precisa mudar para o amigo aparecer.
2. **Toda a rede mora num autoload** (`/root/Sessao`), com o mesmo caminho em qualquer processo. É isso que deixa o dedicado rodar uma cena principal sem cidade, e ser o mesmo código do "abrir para amigos".
3. **Cada número foi medido com bots que sabem a verdade.** Doze defeitos só apareceram assim (`19` §3): carimbo de chegada em vez de amostra, relógio que voltava no tempo, servidor que travava 130 ms na primeira entrada.

## Como usar

1. Leia `00`, `01`, `02`, `03`. Sem eles, as fases não fazem sentido.
2. Para jogar ou testar agora: `21`.
3. Para subir um servidor: `18`.
4. Para executar uma fase: o capítulo técnico **e** a fase em `13`. Antes de mexer em arquivo marcado ✋ em `13`, combine com a frente que o edita.
5. Para dizer "pronto": `14` e `17`.

## Ordem de leitura

| # | Arquivo | Lê quando |
|---|---|---|
| 00 | este | sempre |
| 01 | [`01_ESTADO_ATUAL.md`](01_ESTADO_ATUAL.md) | antes de qualquer fase |
| 02 | [`02_DECISOES.md`](02_DECISOES.md) | antes de qualquer fase; decisão muda aqui antes do código |
| 03 | [`03_ARQUITETURA.md`](03_ARQUITETURA.md) | antes de qualquer fase |
| 04 | [`04_CONTRATO_DE_REDE.md`](04_CONTRATO_DE_REDE.md) | Fases 3–5 (mundo) |
| 05 | [`05_PLATAFORMA_STEAM.md`](05_PLATAFORMA_STEAM.md) | Fase 9 |
| 06 | [`06_REFATOR_O_JOGADOR.md`](06_REFATOR_O_JOGADOR.md) | Fase 2 |
| 07 | [`07_MUNDO_E_STREAMING.md`](07_MUNDO_E_STREAMING.md) | Fases 3 e 8 |
| 08 | [`08_SISTEMAS_DE_JOGO.md`](08_SISTEMAS_DE_JOGO.md) | Fases 3 e 5 |
| 09 | [`09_VEICULO.md`](09_VEICULO.md) | Fase 4 |
| 10 | [`10_MENU_E_LOBBY.md`](10_MENU_E_LOBBY.md) | Fase 7 |
| 11 | [`11_CRIACAO_DOIS.md`](11_CRIACAO_DOIS.md) | Fase 7 |
| 12 | [`12_INTRO_DOIS.md`](12_INTRO_DOIS.md) | Fase 7 |
| 13 | [`13_FASES.md`](13_FASES.md) | **o passo a passo, com estado** |
| 14 | [`14_TESTES_E_ACEITE.md`](14_TESTES_E_ACEITE.md) | toda fase |
| 15 | [`15_RISCOS_E_NAO_FAZER.md`](15_RISCOS_E_NAO_FAZER.md) | quando der vontade de atalhar |
| 16 | [`16_AUTOLOADS_E_ARQUIVOS.md`](16_AUTOLOADS_E_ARQUIVOS.md) | inventário; consulta |
| 17 | [`17_CHECKLIST.md`](17_CHECKLIST.md) | aceite do produto |
| 18 | [`18_SERVIDOR_DEDICADO.md`](18_SERVIDOR_DEDICADO.md) | subir, configurar, hospedar |
| 19 | [`19_REVISAO_DO_CODIGO.md`](19_REVISAO_DO_CODIGO.md) | por que a v2 é assim; defeitos medidos |
| 20 | [`20_PROTOCOLO.md`](20_PROTOCOLO.md) | formato de fio; régua de regressão |
| 21 | [`21_COMO_JOGAR_JUNTO.md`](21_COMO_JOGAR_JUNTO.md) | jogar e testar hoje |

## Regras de execução

Valem as de `docs/PADROES-ENGENHARIA.md`, mais:

1. **Solo não regride** (P16). Em SOLO a `Sessao` não processa nada.
2. Tipagem estática; `class_name` em classe nova, **menos** no script de autoload (nome de autoload e `class_name` iguais conflitam).
3. **Lógica de rede nova vai para classe pura**, testável no nível 2. A `Sessao` só move bytes.
4. **Todo RPC mora na `Sessao`.** Nó de cena com `@rpc` não existe no dedicado.
5. **Coisa do mundo por chave determinística**, nunca por caminho de nó (P20).
6. Rede se prova com o nível 4, e o resultado vai no commit em números.
7. Um commit por unidade lógica.
8. **Sessões paralelas:** código novo em arquivo novo; arquivo marcado ✋ em `13` só com combinado.

## Vocabulário

| Termo | Significa |
|---|---|
| **Servidor** | o peer 1. Manda no mundo. Pode ter jogador (HOSPEDANDO) ou não (DEDICADO) |
| **Anfitrião** | quem HOSPEDA: servidor e jogador no mesmo processo |
| **Dedicado** | servidor sem jogador e sem tela |
| **Cliente** | quem entrou num servidor |
| **Jogador local** | o `Player` deste processo; o único no grupo `player` |
| **Boneco** | `AvatarRemoto`: outro jogador, como este processo o desenha |
| **Instantâneo** | pacote de 20 Hz do servidor com o estado de quem interessa a um cliente |
| **Espaço** | rua, Estrada Velha ou um interior específico; só se vê quem está no mesmo |
| **Interesse** | mesmo espaço e a ≤ 160 m |
| **Grupo** | quem divide a missão (Fase 5) |
| **Fome** | o boneco não tem dado para o instante que desenha: é entrega, não interpolação |

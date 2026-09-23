# 10 — Menu, entrada online e folha de viagem

> **Versão 2.0 — 21/09/2026.** Reescrito. A 1.0 tinha "JOGAR COM AMIGO", dois retratos e Steam como caminho de convite. Na v2 são N jogadores, ENet como base, entrada no meio da sessão, e um painel F7 provisório que já funciona (Fase 1).
> Fase 7. Vocabulário: `docs/UI-BIBLE.md`, `ui_estilo.gd`, ficha, carteira, papel, carimbo. O lobby é produto: não é um `ItemList` cinza.

## 1. Hoje

### 1.1 O título

`menu.gd` (2.371 linhas), painel `TITULO`. Os itens moram em `titulo_layout.gd:55`:

```
CONTINUAR · CARREGAR · NOVO JOGO · MAPA · OPCOES · SAIR
```

O título é "SHIMOKAWA", o subtítulo é "subúrbio · névoa · madrugada", e o fundo é a mata da Estrada Velha (`cabine_fundo_criacao.tscn`). O despacho é por nome, em `Menu._acionar` (`menu.gd:2291`).

`enum Painel { BOOT, TITULO, CARREGAR, OPCOES, MAPA, NOME, APARENCIA }` (`:96`). NOME e APARENCIA são "na estrada" (`:1605`): saem do CRT preto e branco para a mata em cor.

NOVO JOGO: NOME (ficha, assinatura) → `RegistroCivil.criar_jogador` → APARENCIA (carteira, `CriacaoAparencia.confirmou`) → `jogar.emit(nome)` → `cidade._novo_jogo` + `_rodar_abertura`.

A lista se empilha pelo conteúdo e já passou de cinco para seis itens uma vez (`titulo_layout.gd:61-70`). Um sétimo cabe; o teste de layout mede a partir da constante.

### 1.2 A rede, hoje

O painel **F7** (`PainelOnline`, CanvasLayer 140), dentro do jogo:

- nome, endereço (IP, nome DNS, `host:porta`) e senha;
- HOSPEDAR e ENTRAR;
- a lista da rede local (LAN, Hamachi, Radmin), com "(outra versão)" marcado;
- os jogadores, com ping;
- o chat, e os recados no canto (5 linhas, 7 s).

Funciona e está medido, mas é um painel de desenvolvedor dentro do jogo. Quem abre o `.exe` para jogar com amigos precisa achar a porta **no título**.

## 2. A linha no título

```
CONTINUAR
CARREGAR
NOVO JOGO
JOGAR ONLINE          ← nova, logo abaixo de NOVO JOGO, com o mesmo peso
MAPA
OPCOES
SAIR
```

Não é um submenu "Multiplayer" em OPCOES. Jogar com alguém é um jeito de começar, do mesmo tamanho que começar sozinho.

JOGAR ONLINE abre o painel `ONLINE` (novo no `enum Painel`), "na estrada" como NOME e APARENCIA.

## 3. O painel ONLINE: a folha de viagem

Uma folha de papel, na gramática da ficha de cadastro (`ficha_cadastro.gd`): tinta, campo sublinhado, carimbo. Desenhada à mão, como a ficha, e não 15 `Label` soltos. 480×270, margem 7 px, fontes nativas por `UiEstilo.aplicar`.

```
┌────────────────────────────────────────────────────────────────┐
│ VIAGEM                                          [retrato 3D]   │
│ ─────────────────────────────────────────────  JOSE            │
│                                                                │
│  ABRIR MEU MUNDO                                               │
│    ( ) mundo novo      ( ) espaço 1 · Praça · 03:12            │
│    senha ________     vagas [8]                                │
│                                                   [ ABRIR ]    │
│  ENTRAR                                                        │
│    NA REDE                                                     │
│      MUNDO DE ZE ········· 3/8  🔒                              │
│      SERVIDOR DO BAR ····· 12/32     (outra cidade)            │
│    RECENTES                                                    │
│      jogo.exemplo.com:24567 ··· ontem                          │
│    endereço ___________________                  [ ENTRAR ]    │
│                                                                │
│  [W/S] escolher  [E] abrir  [ESC] voltar          recado: —    │
└────────────────────────────────────────────────────────────────┘
```

### 3.1 Quem é você

O canto superior direito é o **retrato da carteira** (o mesmo `SubViewport` de `CriacaoAparencia`, com o `Corpo` de verdade) e o primeiro nome.

**Sem ficha ainda** (primeira vez no jogo): o retrato é uma silhueta e a folha diz "Faça sua carteira antes de viajar." A seta leva a NOME → APARENCIA, os painéis que já existem, e volta para a folha. Ninguém entra num servidor sem carteira: a aparência e o nome vão na autenticação.

### 3.2 Abrir meu mundo (HOSPEDANDO)

| Escolha | Faz |
|---|---|
| Mundo novo | como NOVO JOGO, com a abertura (P10); a porta abre **antes** da abertura, e quem entrar espera na praça (§5) |
| Espaço N | como CONTINUAR daquele espaço, e abre a porta com o mundo do save |
| Senha | vazia = aberto para quem tiver o endereço |
| Vagas | 2 a 8 (o teto de 32 é do dedicado) |

Ao abrir, a folha mostra **como os amigos entram**: o IP da LAN e, se houver, o do Hamachi ou do Radmin (25.x, 26.x), primeiro. O F7 já monta essa lista (`PainelOnline._enderecos`, `painel_online.gd:287`); a folha usa a mesma função, com um botão para copiar. Esse é o momento em que o amigo pergunta "qual é o IP?" no Discord.

### 3.3 Entrar

| Seção | O que é | Fonte |
|---|---|---|
| NA REDE | servidores anunciados na rede local e na VPN de jogo | `DescobertaLan` (✅ 1) |
| RECENTES | os últimos 8 endereços onde entrou, com o nome que o servidor tinha | `user://servidores.cfg` (novo) |
| FAVORITOS | os que marcou com [F] | idem |
| Endereço | IP, nome DNS, `host:porta` | `ProtocoloRede.separar_endereco` (✅ 1) |

Cada linha da lista mostra nome, `n/max`, cadeado se tem senha, e **"(outra versão)"** ou **"(outra cidade)"** (assinatura do mundo, `07` §2.1), sem sumir: o jogador precisa saber que o servidor existe e por que não entra.

Um dedicado na internet não aparece em NA REDE (o anúncio é por broadcast). Por isso RECENTES e FAVORITOS não são enfeite: são o jeito de voltar a um dedicado. Uma lista pública de servidores na internet é outro produto, com um servidor mestre; fica fora até haver servidores públicos para listar (`05` §6).

## 4. Os estados da entrada

Da hora em que se aperta ENTRAR até o controle voltar à mão:

| Estado | O que a tela mostra | Sai para |
|---|---|---|
| LIGANDO | "Ligando para ZE…", o carimbo girando | AUTENTICANDO, ou FALHOU depois de 8 s |
| AUTENTICANDO | "Conferindo a carteira…" | SENHA, CARREGANDO, FALHOU |
| **SENHA** | o campo de senha **na folha**, com o nome do servidor | AUTENTICANDO de novo |
| CARREGANDO | "Recebendo a cidade…" com a fração (Fase 3, `04` §5.1) | CHEGANDO |
| CHEGANDO | fade para preto; a cidade monta em volta do ponto de chegada | JOGANDO, quando há chão (`Sessao._chegar`) |
| FALHOU | o motivo, em uma linha, e [E] tentar de novo / [ESC] voltar | — |

**SENHA não é um erro.** O desafio já diz se o servidor tem senha (`desafio.senha`, `20` §2). Hoje, sem senha digitada, a entrada falha com "Senha errada.". Na folha, o jogo pede a senha antes de mandar a prova, e só mostra "Senha errada." se a digitada estiver errada.

Os motivos, na voz do jogo (`ProtocoloRede.TEXTO_RECUSA`, mais os novos):

| Motivo | Texto |
|---|---|
| `jogo` | Isso não é um servidor deste jogo. |
| `versao` | Versão diferente. Atualize o jogo dos dois lados. |
| `cidade` (novo, `07` §2.1) | Cidade diferente. Atualize o jogo dos dois lados. |
| `senha` | Senha errada. |
| `cheio` | Servidor cheio. |
| `pedido` | Pedido de entrada inválido. |
| tempo esgotado | Ninguém atendeu em ZE. Confira o endereço e a porta 24567/UDP. |
| expulso | O dono do servidor tirou você. (+ o motivo dele) |

## 5. Entrar sem a abertura

Quem entra num mundo que já existe não vê a abertura de ninguém (P10). O caminho do título:

```
JOGAR ONLINE → (carteira, se não tiver) → ENTRAR → estados do §4
  → cidade: como _novo_jogo, SEM _rodar_abertura, SEM o kit local (vem do servidor na Fase 3)
  → Sessao._chegar: perto do anfitrião, ou no ponto de nascimento do dedicado, no chão do relevo
```

`cidade.gd` já pula a abertura com `--pular-abertura` (`:1635`). A entrada online usa o mesmo desvio por um parâmetro, e não por flag de linha de comando.

**Anfitrião ainda na abertura:** quem entra enquanto o anfitrião está na Estrada Velha (espaço 1) não vai para lá. A chegada só segue o anfitrião se ele estiver na rua (`Sessao._ponto_de_chegada`), e a regra já existe. O convidado espera na praça, no ponto de nascimento, e o anfitrião acorda ali perto no fim da abertura.

## 6. A folha de viagem da intro co-op

É o mesmo painel ONLINE, num modo a mais, para quem quer **começar junto** (P10, `12`):

```
ABRIR MEU MUNDO → mundo novo → [x] começar a viagem junto
```

- O anfitrião abre o mundo, mas **não** começa a abertura. A folha vira a lista da viagem: até **5** retratos (os lugares do Marea), cada um com o carimbo **ESPERANDO** ou **PRONTO**.
- Quem entra pela folha **não** vai para a cidade: fica na folha (estado `LOBBY` na `Sessao`: conectado, sem corpo no mundo).
- Cada um carimba PRONTO com [E]. O anfitrião vê **ASSINAR**, o mesmo gesto da ficha, quando todos estão prontos, e assina.
- Assinou: a abertura co-op começa para os 5, pelo relógio do servidor (`12` §4).
- O sexto em diante entra depois, como no §5.

## 7. F7 continua

O painel F7 (`PainelOnline`) fica como atalho de quem já está na rua: o "Abrir para LAN". Ele passa a usar os mesmos componentes da folha (a lista, os recentes, os estados), para as duas portas não divergirem.

## 8. Controle e teclado

O jogo tem suporte a controle (`controle.gd`). A folha navega por [W/S] e setas, [E] e [ESC], como o resto do menu. O campo de texto (endereço, senha) abre o teclado da tela quando a entrada é de controle. **A folha não pode exigir mouse.**

## 9. Som

`AudioDirector.tocar_ui`. O carimbo é o carimbo da ficha. A chegada de alguém na folha é um toque curto, o mesmo do chat. Sem música de lobby: o título já tem a mata.

## 10. Aceite da Fase 7

| # | Prova |
|---|---|
| 1 | JOGAR ONLINE no título, 480×270, com o teste de layout do título verde com sete itens |
| 2 | Entrar pelo título, sem carteira: passa por NOME e APARENCIA e entra |
| 3 | Servidor com senha, sem senha digitada: a folha **pede**, não falha |
| 4 | Cada motivo de recusa aparece com o texto certo (bots com versão, cidade e senha erradas) |
| 5 | RECENTES guarda o dedicado e reentra com [E] |
| 6 | Folha de viagem com 3 prontos: o anfitrião assina e os 3 entram na abertura co-op juntos |
| 7 | Solo: título, NOVO JOGO, CONTINUAR e CARREGAR idênticos (captura contra o HEAD) |
| 8 | Capturas: `captures/multiplayer/folha_*.png`, uma por estado do §4 |

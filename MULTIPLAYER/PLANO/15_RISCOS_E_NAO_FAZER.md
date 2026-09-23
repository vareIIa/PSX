# 15 — Riscos e o que não fazer

> **Versão 2.1 — 21/09/2026, noite.** Acrescenta os riscos que a Fase 2 mediu (R18–R22) e o estado novo de R7, R8 e R9.

## 1. Riscos reais, com estado

| # | Risco | Por que dói aqui | Estado / mitigação |
|---|---|---|---|
| R1 | Um segundo `Player` no grupo `player` | 42 lugares pegariam o boneco errado | ✅ evitado: os bonecos ficam fora do grupo (`03` §4) |
| R2 | RPC em nó de cena | o dedicado roda outra cena principal, e o RPC não teria destino | ✅ evitado: todo RPC na `Sessao` |
| R3 | Caminho de nó como identidade | prop de chunk é numerado pelo processo | regra P20; a Fase 3 usa chave |
| R4 | Interpolação que não existe no Synchronizer | amigo andando em degraus de 12 cm | ✅ buffer próprio, 0,1 cm |
| R5 | Relógio de rede errado | boneco parado no ar, pulos, estados descartados | ✅ três defeitos achados e corrigidos (`19` §3) |
| R6 | Carga no laço do servidor | todos travam juntos | ✅ ponto de chegada pré-carregado (130 → 17–40 ms). **Vigiar** qualquer `load()` no caminho de entrada |
| R7 | Teletransporte não anunciado com validação `corrigir` | jogador puxado de volta ao entrar em interior no mundo | ⏳ parcial: salto de espaço e de mais de 8 m já marcados pela `Sessao`; desmaio anuncia; o servidor aceita o bit no mesmo espaço 1× a cada 3 s. Padrão `registrar` até o teste de rota com interior |
| R8 | ESC do anfitrião pausa a árvore | o anfitrião congela para todos **e para o relógio da cidade de todos** | ✅ `Sessao.pausar`: relógio do cliente 2,0 s → 30,0 s de jogo no mesmo teste |
| R9 | Versão diferente do gerador de mundo | ruas diferentes no mesmo lugar, sem erro | ✅ **assinatura da cidade** na autenticação (`07` §2.1): o próprio gerador diz se mudou; `--sem-relevo` recusado com o motivo. Não depende mais de ninguém lembrar |
| R10 | Sem criptografia | senha protegida por desafio, mas o conteúdo vai em claro | Fase 8.3 (DTLS) |
| R11 | Pacote confiável gigante | teto do ENet de 32 MB, não exposto | Fase 8 (DTLS + bloqueio); risco baixo entre amigos |
| R12 | Localhost esconde a rede real | 0,1 cm em localhost não diz nada de 150 ms com 2 % de perda | Fase 8.4 (perda simulada) e nível 5 |
| R13 | Carro com dono no cliente | quem trapaceia pode "dirigir" a 270 km/h em qualquer lugar | validação até 75 m/s; aceitável para servidor de amigos (P15) |
| R14 | Edição por baixo de outra frente | o working tree perde trabalho, ou o HEAD deixa de compilar | ✋ em `13`/`16`; código novo em arquivo novo |
| R15 | Commit em massa com a rede no meio | o `dcc662e` levou a rede intermediária | ver §3 |
| R16 | Dedicado de 204 MB e 261 MB carregando visual | custo de VPS e tempo de subida | Fase 6.2 (*Strip Visuals*) |
| R17 | `Relevo` e `ChunkManager` mudando agora (outra frente) | o servidor da Fase 8 depende deles | combinar a API de colisão multi-alvo antes |
| R18 | **Dinheiro e iWeed no `WorldState`** (outra frente, 21/09) | em rede, o `WorldState` é o mundo de todos: uma carteira só para o servidor inteiro | Fase 3: estado pessoal fora do mundo (`08` §1.4); combinar com a frente do iWeed |
| R19 | O dedicado compila o gerador da cidade (assinatura) | erro de compilação de outra frente aparece no log do servidor; se o gerador quebrar, a assinatura fica indisponível | a sessão segue só com a versão; `mp_teste.sh` separa erro alheio de compilação (aviso) de erro da rede (falha) |
| R20 | **Vidro opaco da `Carroceria`** | nenhum motorista aparece, NPC ou amigo; a abertura co-op depende de "cabeças atrás do vidro" | decisão de render, antes da Fase 7 (`12` §2) |
| R21 | Réplica de carro sem colisão | o trânsito local para em cima do carro do amigo (visto na avenida) | Fase 4.8 |
| R22 | Campos privados lidos por nome (`_pitch`, `_agachado`, `_bike`, `_rotulo_ocupacao`, `_freando`, `_semente`) | a outra frente renomeia e a rede passa a mandar valor neutro | `Sessao._campo` avisa uma vez; acessores públicos quando a frente topar (`06` §3) |

## 2. Não fazer

### Arquitetura

- `MultiplayerSpawner` / `MultiplayerSynchronizer` para jogador: o caminho de nó não é estável entre a cena do dedicado e a da cidade, e o Synchronizer não interpola
- `@rpc` fora da `Sessao`
- Pôr o boneco no grupo `player`
- Caminho de nó em pacote de mundo
- Dicionário em pacote de 20 Hz (8 vezes mais bytes; ver `20`)
- Simular o mesmo corpo físico nos dois lados esperando que bata
- `load()` de cena no laço do servidor
- Relógio de rede que volta
- Host migration, lockstep, rollback: não é este jogo

### Plataforma

- Steam como **base** (é opcional, Fase 9)
- UPnP como plano A
- VoIP próprio
- Login com e-mail
- Anticheat de kernel

### Produto

- Intro co-op para quem entra no meio (P10)
- Uma missão para o servidor inteiro (P7: grupo)
- Leash de rede (P5)
- Pausar o mundo dos outros

### Processo

- Dizer "funciona" sem o nível 4
- Dizer "0,1 cm" sem dizer "em localhost"
- Mexer em arquivo ✋ sem combinar
- Commitar a rede sem rodar `mp_teste.sh`

## 3. Duas regras para o repositório inteiro

1. ~~Quem mudar o gerador sobe `VERSAO`.~~ **Não precisa mais** (desde a v2): a assinatura da cidade compara o que o gerador produz de fato. `VERSAO` sobe só quando o **formato de pacote** muda.
2. **Antes de commitar `game/src/net/`**: `tests/mp/run_tests_rede.gd` e `tools/mp_teste.sh` verdes.

## 4. Atalhos que parecem espertos e não são

**"É só pôr um MultiplayerSynchronizer no player.tscn."**
Ele não interpola no 4.7.2, o caminho não bate com a cena do dedicado, e o `Player` extra cai no grupo que 42 lugares usam.

**"Localhost deu 0,1 cm, então está pronto."**
Localhost não perde pacote nem varia atraso. O número prova que a cadeia está certa, não que ela aguenta a internet (R12).

**"Deixa o carro no servidor, é mais seguro."**
Com dedicado na internet, são 80–150 ms entre o volante e a roda. Sem predição (meses de trabalho) é inguiável (P6).

**"Dedicado é outro projeto."**
Neste desenho, ele é a `Sessao` sem jogador e uma cena de 84 linhas. O que é projeto de verdade é a persistência (Fase 6) e o chão no servidor (Fase 8).

## 5. Dívida aceita de propósito

- Pedestre e trânsito diferentes para cada um (*flavor*)
- Carro com dono no cliente
- Sem reconexão até a Fase 6
- Sem voz
- Painel F7 como entrada até a Fase 7
- Espaço de interior lido por nome (`_campo(Interiores, &"_semente")`) até o acessor público (2.2)
- Motorista invisível no carro do amigo até o vidro deixar ver (R20)

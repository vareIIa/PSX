# 15 — Riscos e o que não fazer

## 1. Riscos reais deste projeto

| # | Risco | Por que dói aqui | Mitigação |
|---|---|---|---|
| R1 | `get_first_node_in_group("player")` em 32 sítios | O segundo corpo é invisível para o jogo | Fase 2 inteira, grep no aceite |
| R2 | ChunkManager um alvo | Convidado no vazio ou hitch | P5 + `RAIO_CARGA_COOP` |
| R3 | `visible = false` no Player ao dirigir | Parceiro some do carro | Fase 4, malha 1P vs 3P |
| R4 | Intro no singular + CarroCena vazio | O pedido “desde o começo” falha | Fase 5 com captura plano 1 |
| R5 | ENet na internet | Ninguém abre porta | Fase 1 = localhost; Fase 7 = Steam relay |
| R6 | Pausar a SceneTree no ESC | Host abre prancha, convidado congela | Fase 2.5 |
| R7 | `_novo_jogo` recria ficha | Carteira do convidado morre | `11` §1, `cidade.gd` já tem o comentário |
| R8 | Física não determinística | Carro dessinc | Host simula veículo |
| R9 | Item duplicado | Dois E no mesmo tick | Host serializa |
| R10 | Frente Vulkan muda `ChunkManager` | Dual raio silencioso, pop-in | P13, raio de **sessão** |
| R11 | GodotSteam módulo vs GDExtension | Quebra `.tools/` portable | Só GDExtension 4.22 |
| R12 | Convite com o jogo no CRT | `+connect_lobby` morre | Ler cmdline antes do tubo |
| R13 | Lobby genérico | Quebra o jogo que é documento | `10`, UI-BIBLE |
| R14 | Escopo 4 jogadores / dedicated / voz | Não entrega intro 2P | P1 P2 P14, este arquivo |
| R15 | “O contrato PSX impede 2P” | Falso: PSX é opção de vídeo | Este plano, `00`, P13 |

## 2. Não fazer

### Arquitetura

- Dedicated server na v1
- Host migration
- Mid-session join (entrar no meio da rua)
- Lockstep / rollback / predição de shooter
- Replicar chunk, pedestre de rua, chuva, Settings, pós
- Synchronizer em “Always” em tudo
- Split-screen
- Dois renderers exigindo a mesma sessão visual

### Plataforma

- Login e-mail na v1
- Nakama / PlayFab / Photon / EOS como eixo
- ExpressoBits steam-multiplayer-peer (pausado)
- Godot custom compilado com módulo Steam
- VoIP próprio
- Anticheat kernel
- UPnP como plano A de conexão

### Produto

- 3+ jogadores
- Friend’s Pass improvisado
- Reescrever a intro solo no plural
- Pausar o mundo do parceiro
- Mochila compartilhada
- Explorar em distritos opostos na v1 (dual-target é 3b)

### Processo

- Começar pelo lobby bonito (Fase 6 antes da 1)
- Começar pelo Steam (Fase 7 antes da 1)
- Um PR de 80 arquivos “multiplayer”
- Dizer pronto sem dois processos
- Tratar ART-BIBLE 120 draw calls como teto do netcode

## 3. Atalhos que parecem inteligentes e não são

**“A gente só sincroniza transform e o resto é local.”**  
Porta, item e missão dessincronizam em um minuto. Transform sem WorldState é fantasma.

**“Listen server sem relay, o amigo é técnico.”**  
Metade das casas em 2026 é NAT simétrico / CGNAT. O convite “não conecta” vira o review da Steam.

**“Vulkan resolve o streaming, então sem leash.”**  
Vulkan não instancia chunk por mágica. Thread pool e hitch continuam. Leash é sessão; horizonte é look.

**“O host é authority do Player também, mais simples.”**  
Andar a 2,4 m/s com 80 ms de RTT é jogável; 200 ms de café da manhã no Wi-Fi do convidado não é. Meio-termo da `04` §4.

**“Um bot no segundo assento na intro, o coop de verdade depois.”**  
O pedido é os dois personagens. Bot na intro é trailer mentindo.

## 4. Dívida que o plano aceita de propósito

- Pedestre diferente nos dois (flavor)
- Interior só juntos
- Sem reconnect
- Sem passageiro assumir volante (gancho na 4)
- Sem voz in-game
- Sem save coop para o convidado

Escrever isso no ship (folha / recado) é honesto. Fingir que é MMO não é.

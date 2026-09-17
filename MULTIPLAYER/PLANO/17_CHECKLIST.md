# 17 — Checklist de “multiplayer funciona”

> Só marca quando o nível de teste correspondente em `14` passou.
> Isto é o aceite do **produto** 2P, não de uma fase.

## Produto

- [ ] JOGAR COM AMIGO no título, peso igual a NOVO JOGO
- [ ] Folha de viagem (lobby) no vocabulário de documento, 480×270, margem 7 px
- [ ] Convidar amigo Steam (overlay) **e** aceitar com o jogo fechado
- [ ] LAN/ENet ainda existe para dev
- [ ] Cada um cria nome + carteira; os dois retratos na folha
- [ ] Host só começa com 2 prontos
- [ ] CONTINUAR e NOVO JOGO iguais ao de hoje (P16)
- [ ] PSX ou Vulkan (quando existir) é opção local; a sessão não quebra se os dois diferirem

## Intro

- [ ] Plano 1 da Estrada Velha: duas silhuetas, aparências da carteira
- [ ] Planos 2–3: dá para ler dois no carro
- [ ] Plano 4: dois sentados, diálogo no plural
- [ ] Plano 5: os dois na névoa
- [ ] Solo: falas no singular, um ocupante implícito como hoje
- [ ] Praça: dois deitados no take da igreja
- [ ] Cortes e fades iguais nos dois processos
- [ ] Controle só depois da praça

## Gameplay

- [ ] Cada um anda, se vê o outro, 1P/3P local
- [ ] Um volante, um passageiro, corpos visíveis, desce do lado certo
- [ ] Item, porta, plantio, missão, relógio: verdade do host
- [ ] Inventário e vida pessoais
- [ ] Um fala com NPC, o outro não congela
- [ ] Interior: regra v1 (juntos)
- [ ] Minimapa marca o parceiro
- [ ] Soft leash ~80 m com recado, sem explodir chunk
- [ ] ESC local não pausa o parceiro
- [ ] Host salva; convidado não “continua” o save do amigo

## Quedas

- [ ] Convidado sai: host segue, recado
- [ ] Host sai: convidado ao título, sem crash
- [ ] Steam cai / timeout: mensagem, não freeze

## Plataforma 2026

- [ ] GodotSteam 4.22 GDExtension, Godot 4.7.2 portable intacto
- [ ] Relay: duas casas sem port-forward
- [ ] Rich presence
- [ ] Página Steam com Co-op (2)
- [ ] Sem VoIP próprio, sem dedicated, sem 3º jogador

## Qualidade

- [ ] `run_tests.gd` verde
- [ ] `--headless --quit` sem warning
- [ ] Capturas em `captures/multiplayer/`
- [ ] Grep: zero `get_first_node_in_group(&"player")` fora de `Sessao`
- [ ] Playtest 30 min anotado

Quando esta página estiver inteira marcada, o multiplayer **deste** jogo existe. Até lá, existe um plano.

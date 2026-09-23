# 17 — Checklist de "multiplayer funciona"

> **Versão 2.1 — 21/09/2026, noite.** Só marca quando o nível de teste de `14` passou. Cada ✅ diz qual prova.
> Isto é o aceite do **produto**. O aceite de cada fase está em `13`.

## Conexão

- [x] Abrir o próprio jogo para amigos (HOSPEDANDO) — `mp_dois.sh --foto`
- [x] Entrar por IP ou por nome (DNS), com porta opcional — nível 2 (`separar_endereco`) + nível 4
- [x] Lista de servidores na rede local, com a versão marcada — nível 2 (`ler_anuncio`); **sem teste de dois processos** (a porta 24568 é uma por máquina)
- [x] Hamachi / Radmin: endereço virtual listado primeiro, broadcast dirigido /8 — código; **nível 5 pendente** (duas casas)
- [x] Servidor dedicado sem tela — nível 4
- [x] Servidor dedicado exportado como executável próprio — build `NevoaEDither_Servidor` + 2 bots, p95 0,11 cm
- [ ] Servidor dedicado Linux — Fase 6.1
- [ ] Container — Fase 6.3
- [x] Senha, sem a senha viajar — nível 2 (a prova de uma conexão não abre outra) + nível 4
- [x] Lotação, com "Servidor cheio." — nível 4
- [x] Versão diferente recusada com o motivo — nível 2
- [x] **Cidade diferente** (outro gerador, `--sem-relevo`) recusada com o motivo — nível 2 + nível 4 (bot `--sem-relevo`, editor e executável exportado)
- [x] Servidor exportado no protocolo 2 — build + 2 bots, p95 0,11–0,12 cm
- [x] Queda: timeout de 8 s; o recado de quem saiu — código; **timeout sem medida**
- [x] Anfitrião sai → cada um continua sozinho no próprio mundo — código (`_ao_servidor_cair`); visto no log dos bots ("O servidor fechou. Você continua sozinho aqui.")
- [ ] Reentrar e o dedicado lembrar — Fase 6

## Ver os outros

- [x] Posição certa: erro p95 ≤ 5 cm — medido 0,08–0,11 cm
- [x] 16 juntos — medido: p95 0,10 cm, fome 0 %, 5,9 KB/s por cliente
- [x] Aparência da carteira — foto `convidado_ve_anfitriao.png`
- [x] Nome sobre a cabeça, tapado por parede — foto
- [x] Carro do outro, mesmo modelo e cor — foto `anfitriao_ve_lanterna_e_carro.png`
- [x] Lanterna do outro na névoa, **apontando para onde ele olha** — medido: chão 1,70× mais claro com a lanterna a −35°, 1,16× a +30° (`lanterna_do_amigo_baixo_e_cima.png`)
- [x] Agachado — foto `anfitriao_ve_agachado.png` (corpo mais baixo, lanterna na altura do olho agachado)
- [x] Espaços: interior e rua não se misturam — código + nível 2 (`espaco_interior`); **falta foto** de dois no mesmo interior
- [ ] Corpo sentado no carro do outro — Fase 4
- [x] Ponto do outro no minimapa, preso na borda quando está longe — foto (`anfitriao_ve_carro_e_lanterna.png`)
- [x] Farol e facho do carro do outro — foto
- [ ] Motorista visível no carro do outro — o corpo está no banco; **o vidro da `Carroceria` é opaco** (R20, render)
- [x] Luz de freio do carro do outro — foto `anfitriao_ve_freio_e_poses.png` (brasa vermelha com `--bot-agachado`, que no carro é `F_FREANDO`)
- [ ] Passos do outro com som — código; sem medida de áudio
- [x] Sentado, de bicicleta, ausente ("...") — foto `anfitriao_ve_freio_e_poses.png` (sentado e bicicleta) e `anfitriao_ve_ausente.png` ("BOT0 ...")
- [ ] Pedestre desvia do amigo — código (`pedestre.gd`); sem medida
- [ ] Carro do outro com colisão — Fase 4.8 (o trânsito local para em cima da réplica, visto)

## Junto no mundo

- [x] Hora da cidade igual para todos — nível 4 (relógio do bot anda 20 s de jogo só pelo servidor)
- [x] Chat — nível 4
- [x] Lista com ping — nível 4
- [ ] Porta, item, plantio iguais para todos — Fase 3
- [ ] Inventário e vida no servidor — Fase 3
- [ ] Carona — Fase 4
- [ ] Grupo e missão — Fase 5
- [ ] NPC, blitz, inimigo iguais — Fase 8
- [x] ESC do anfitrião não congela os outros **nem o relógio de todos** — medido: relógio do cliente 2,0 s (antes) → 30,0 s (depois) de jogo, com a prancha aberta a sessão toda
- [x] Desmaio em rede não pula a hora de todos — código (`desmaio.gd`)

## Produto

- [ ] JOGAR ONLINE no título — Fase 7
- [ ] Folha de viagem — Fase 7
- [ ] Intro co-op até 5 — Fase 7
- [x] Entrada provisória F7 — código e flags; **falta foto** do painel
- [ ] Canon emendado — Fase 0 (dono do projeto)

## Segurança e operação

- [x] Autenticação antes do peer existir
- [x] Pacote de tamanho exato; estado inválido descartado inteiro — nível 2
- [x] Teto de pacotes e de chat por cliente
- [x] Texto e aparência saneados dos dois lados — nível 2
- [x] Movimento implausível registrado; `corrigir` disponível — nível 2
- [x] Log do servidor sem ERROR nos cenários de teste — nível 4
- [ ] DTLS — Fase 8.3
- [ ] Admin e bloqueio — Fase 8.5
- [ ] Medida com perda e atraso — Fase 8.4
- [ ] Duas casas, sem porta aberta, com VPN — nível 5
- [ ] Duas casas, dedicado em VPS — nível 5

## Qualidade

- [x] Solo sem regressão (boot headless com os mesmos avisos de antes) — P16
- [x] Nível 2: 136/136
- [x] Nível 4 verde três vezes seguidas com 8 bots (v1) e quatro rodadas com a v2; 16 bots com a v2: p95 0,22 cm, 6,01 KB/s
- [ ] Playtest de 30 min com 4 pessoas — Fase 8.6

Quando esta página estiver inteira marcada, o multiplayer **deste** jogo existe. Hoje existe a base: as pessoas se veem, conversam, entram e saem, e o servidor dedicado roda como executável.

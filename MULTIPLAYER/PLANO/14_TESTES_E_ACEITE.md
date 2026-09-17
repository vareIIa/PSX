# 14 — Testes e aceite

> Vale `docs/PADROES-ENGENHARIA.md`. Rede acrescenta o nível 4: dois processos.
> Dizer “funciona” sem dois Godot abertos é chute.

## 1. Níveis

| Nível | Comando | Quando |
|---|---|---|
| 1 | `.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --quit` | Toda mudança |
| 2 | `--headless --path game --script res://tests/run_tests.gd` | Toda mudança de sistema |
| 3 | Janela + `--shot=` (shader, look, intro) | Visual |
| 4 | Dois processos `tools/mp_dois.ps1` | Qualquer netcode |
| 5 | Duas máquinas, duas contas Steam, **sem** port-forward | Fase 7+ |

Headless **não** prova shader nem interpolação visual do parceiro. Nível 4 é o mínimo do 2P.

## 2. Flags de boot (a criar na Fase 1)

```
--mp-host
--mp-join=127.0.0.1
--mp-porta=24567
--mp-pular-lobby
--mp-pular-intro
```

Composição com as que já existem: `--pular-menu`, `--pular-abertura`, `--ver-praca`, `--shot=`.

`--pular-abertura` no coop **não** substitui `--mp-pular-intro`: a primeira é o ramo solo da cidade; a segunda pula cinema 2P e spawna os dois.

## 3. Suíte nova (Fase 8, esqueleto desde a 1)

Pasta `game/tests/mp/`. Headless com dois peers no mesmo processo **só** se alguém encapsular dois `SceneTree` — caro. Preferir testes de contrato **sem** socket:

- `Sessao.jogador_local` em SOLO devolve o único
- WorldState: dois pedidos de item, só um credita (host simulado)
- Roster: viagem_comecou recusa com 1 pronto
- RegistroCivil: duas fichas, `jogador` é o local

Testes de socket: script Python/ps1 que abre dois Godot `--quit-after=` se existir, ou checklist manual por fase (`13`).

## 4. Checklist por fase (manual nível 4)

### Fase 1

- [ ] Host anda, client vê
- [ ] Client anda, host vê
- [ ] Fechar o client: host não crasha
- [ ] Sem flags: um player, câmera 1P, V funciona

### Fase 2

- [ ] GPS dos dois aponta origem certa
- [ ] Minimapa de cada um centra nele
- [ ] Conversa: um fala, o outro anda
- [ ] ESC coop: prancha local, o outro continua
- [ ] Save solo, carregar, posição certa
- [ ] `run_tests.gd` verde

### Fase 3

- [ ] Item no chão: primeiro pega, segundo não duplica
- [ ] Porta abre nos dois
- [ ] Missão avança nos dois HUDs
- [ ] 100 m de distância: recado, sem hitch de 20 chunks num frame
- [ ] Interior: sozinho a porta recusa; juntos entram
- [ ] Relógio igual

### Fase 4

- [ ] `09` §9 inteiro
- [ ] Solo: F entra/sai, painel, rádio, V perseguição

### Fase 5

- [ ] `12` §8
- [ ] Solo: falas no singular, um corpo na igreja

### Fase 6

- [ ] `10` §10, `11` §7
- [ ] Título sem JOGAR COM AMIGO quebrando o layout CRT (medir margem 7 px)

### Fase 7

- [ ] Overlay convida
- [ ] Jogo fechado + convite lança no lobby
- [ ] Duas casas, NAT simétrico, **sem** UPnP
- [ ] Steam fechada: single ok; coop explica

### Fase 8

- [ ] Host Alt+F4: client volta ao título em < 3 s, sem erro no stdout
- [ ] Client cai: host segue, ícone some
- [ ] 30 min de playtest anotado
- [ ] Preset PSX e preset Vulkan (quando existir): sessão a mesma

## 5. Capturas obrigatórias

```
captures/multiplayer/
  lobby_espera.png
  lobby_dois.png
  carteiras_lado_a_lado.png      # dois retratos diferentes
  estrada_01_passagem.png        # duas silhuetas
  estrada_03_rasante.png
  estrada_04_dentro.png          # dois sentados
  praca_deitados.png
  rua_dois_tp.png
  carro_passageiro.png
  leash_recado.png
```

Comparar intro solo em `captures/estrada_velha/` e `captures/praca_matriz/cine/` para não regressar.

## 6. Regressão single — não negociável

Rodar depois de **cada** fase:

```
--pular-menu --pular-abertura
--ver-abertura
--ver-menu
tests/run_tests.gd
```

Se a carteira, o CRT ou a estrada solo mudarem sem pedido, a fase não fechou (P16).

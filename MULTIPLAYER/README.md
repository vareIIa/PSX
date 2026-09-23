# MULTIPLAYER

Plano e registro do multiplayer de *Névoa e Dither*. **Versão 2.1, 21/09/2026, noite.**

## Hoje

A base de rede está **no código e medida** (Fase 1):

- **jogar com amigos:** qualquer jogador abre o próprio mundo (**F7 → HOSPEDAR**). Os outros entram pelo IP da LAN, do **Hamachi** ou do **Radmin**, ou clicando na lista da rede;
- **servidor dedicado de verdade:** processo sem tela, com configuração em arquivo e build próprio (`NevoaEDither_Servidor.exe`). Roda em PC ou VPS;
- **vários jogadores:** 8 por padrão, até 32. Medido com 16: 0,1 cm de erro, 5,9 KB/s por cliente;
- os outros aparecem com a roupa da carteira, o nome e o carro deles; tem chat, hora igual para todos, senha e lotação;
- **o outro parece gente** (Fase 2): a lanterna dele aponta para onde ele olha, o carro dele anda de farol aceso com o facho na névoa, o minimapa mostra onde estão os amigos, e abrir o menu não congela mais o mundo nem a hora de ninguém;
- **a mesma cidade**: quem tem outra versão do gerador (ou `--sem-relevo`) é recusado com "Cidade diferente." em vez de ver o amigo andar por dentro de prédio.

Ainda **não**: mexer no mundo junto (portas, itens, dinheiro), carona, missão em grupo, colisão com o carro do amigo, o dedicado lembrar do mundo. É o que vem nas fases 3 a 9.

## Onde ler

| Quero | Arquivo |
|---|---|
| jogar ou testar agora | [`PLANO/21_COMO_JOGAR_JUNTO.md`](PLANO/21_COMO_JOGAR_JUNTO.md) |
| subir um servidor | [`PLANO/18_SERVIDOR_DEDICADO.md`](PLANO/18_SERVIDOR_DEDICADO.md) |
| entender o desenho | [`PLANO/00_LEIA-ME.md`](PLANO/00_LEIA-ME.md) → `02` → `03` |
| saber o que falta | [`PLANO/13_FASES.md`](PLANO/13_FASES.md) e [`PLANO/17_CHECKLIST.md`](PLANO/17_CHECKLIST.md) |
| por que é assim | [`PLANO/19_REVISAO_DO_CODIGO.md`](PLANO/19_REVISAO_DO_CODIGO.md) |

## Testar

```
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/mp/run_tests_rede.gd
./tools/mp_teste.sh --carga=8
./tools/mp_dois.sh            # --foto, --dedicado, --carro
```

O código mora em `game/src/net/`. A única ligação com o resto do jogo é o autoload `Sessao`.

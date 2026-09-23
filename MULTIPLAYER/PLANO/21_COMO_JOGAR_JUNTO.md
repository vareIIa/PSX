# 21 — Como jogar junto

> Guia prático, para quem joga e para quem testa. Vale para o que existe hoje (Fase 1).
> A entrada é a tecla **F7**, dentro do jogo. A linha JOGAR ONLINE no título vem na Fase 7 (`10`).

## Resumo

| Situação | Quem hospeda faz | Quem entra digita |
|---|---|---|
| Mesma casa (Wi-Fi ou cabo) | F7 → HOSPEDAR | o IP da rede local, ou clica no servidor na lista NA REDE |
| Casas diferentes, com **Hamachi** | os dois na mesma rede do Hamachi; F7 → HOSPEDAR | o IP do Hamachi do anfitrião (25.x.x.x), ou a lista |
| Casas diferentes, com **Radmin VPN** | idem | o IP do Radmin (26.x.x.x), ou a lista |
| Casas diferentes, **ZeroTier / Tailscale** | idem | o IP da rede virtual |
| Casas diferentes, **sem VPN** | abrir a porta 24567/UDP no roteador; F7 → HOSPEDAR | o IP público do anfitrião |
| **Servidor dedicado** | `18_SERVIDOR_DEDICADO.md` | o IP ou nome do servidor (ex. `jogo.meudominio.com:24567`) |

Todo mundo precisa do **mesmo build** do jogo: a mesma versão do protocolo **e a mesma cidade**. Versão diferente é recusada com "Versão diferente. Atualize o jogo dos dois lados"; mesma versão com a cidade gerada diferente (outro commit do gerador, ou alguém com `--sem-relevo`), com "Cidade diferente. Atualize o jogo dos dois lados". Na lista da rede local os dois aparecem marcados, "(outra versão)" e "(outra cidade)", sem sumir.

## 1. Hospedar (o jogo aberto para amigos)

1. Comece ou continue uma partida normal, e ande até onde quiser.
2. Aperte **F7**. A folha SESSÃO abre.
3. Opcional: escreva uma SENHA.
4. **HOSPEDAR.** A folha passa a mostrar a porta e os seus endereços, com o do Hamachi ou Radmin primeiro. Passe um deles aos amigos.
5. **F7** fecha a folha, e você continua jogando. Quem entrar aparece do seu lado, olhando para você.

O canto de cima da tela mostra os recados ("MARIA entrou", "MARIA saiu") e o chat.

Quando você sai do jogo ou aperta SAIR DA SESSÃO, **quem estava com você continua jogando sozinho**, no mundo dele, onde estava.

## 2. Entrar

1. Comece uma partida (ou continue uma).
2. **F7.**
3. Se o servidor aparecer em **NA REDE**, clique nele: o endereço é preenchido. Se não aparecer, digite o IP no ENDEREÇO, com `:porta` se não for a 24567.
4. SENHA, se houver.
5. **ENTRAR.** A folha diz "LIGANDO...", depois "EM <nome do servidor>".

Você é levado para perto do anfitrião (ou do ponto de chegada, no dedicado) e fica olhando para ele. O nome dele aparece sobre a cabeça e some com a distância; parede e árvore tapam o nome.

## 3. Hamachi, Radmin, ZeroTier, Tailscale

Esses programas criam uma **rede local de mentira** entre casas. Para o jogo, é uma LAN.

1. Todos instalam o mesmo programa e entram na **mesma rede** (nome e senha da rede, no programa).
2. O anfitrião vê o próprio IP virtual no programa. Hamachi começa com **25.**, Radmin com **26.**
3. O anfitrião aperta HOSPEDAR. A folha já lista o IP 25.x ou 26.x primeiro.
4. Quem entra digita esse IP, ou clica no servidor em NA REDE, se aparecer.

A lista NA REDE tenta os endereços de broadcast de cada placa de rede, inclusive as virtuais do Hamachi e do Radmin. Mesmo assim, algumas redes virtuais não repassam broadcast. **Se a lista ficar vazia, digitar o IP sempre funciona.**

## 4. Sem VPN, pela internet

1. O anfitrião abre (redireciona) a porta **24567/UDP** no roteador para o IP do PC dele.
2. Libera a porta no firewall do Windows: `18` §4.
3. Descobre o IP público (qualquer site de "qual é meu IP").
4. Quem entra digita esse IP.

Se o provedor usa **CGNAT** (comum em internet móvel e em alguns provedores de fibra), nada disso funciona. Use a seção 3 ou um servidor dedicado numa VPS.

## 5. Quando não conecta

| Recado | Causa provável | O que fazer |
|---|---|---|
| "Ninguém respondeu nesse endereço." | IP errado; servidor fechado; firewall ou roteador bloqueando **UDP** | conferir o IP; conferir que a regra do firewall é **UDP**; testar primeiro na mesma rede |
| "Versão diferente..." | builds diferentes | os dois atualizam |
| "Cidade diferente..." | mesma versão, mas o gerador da cidade mudou entre os dois builds (acontece durante o desenvolvimento: a cidade mudou duas vezes em 21/09), ou alguém abriu com `--sem-relevo` | os dois no mesmo build; tirar `--sem-relevo` |
| "Senha errada." | senha | — |
| "Servidor cheio." | lotação (padrão 8) | o dono aumenta `max_jogadores` (até 32) |
| "Não deu para abrir a porta 24567..." (quem hospeda) | outro programa usando a porta, ou outro jogo aberto hospedando | fechar o outro, ou hospedar com `ENDEREÇO` terminando em `:outra_porta` |
| Entra e o amigo não aparece | vocês estão em espaços diferentes (um dentro de uma casa, outro na rua) ou a mais de 160 m | chegar perto; entrar no mesmo lugar |
| O amigo "trava" e depois pula | Wi-Fi fraco, ou PC engasgando | olhar o ping na folha F7 (JUNTO); cabo resolve a maior parte |

## 6. O que funciona junto hoje, e o que ainda não

**Funciona (Fase 1):**

| O quê | Prova |
|---|---|
| ver os outros andando, na posição certa | medido: erro de 0,1 cm no p95 (`tools/mp_teste.sh`) e foto (`captures/multiplayer/anfitriao_ve_lanterna_e_carro.png`) |
| com a aparência da carteira de cada um | foto `convidado_ve_anfitriao.png` (o anfitrião com a roupa da ficha dele) |
| o carro do outro, com o mesmo modelo e a mesma cor | foto `anfitriao_ve_lanterna_e_carro.png` (Marea atrás do muro da igreja) |
| nome sobre a cabeça, tapado por parede e árvore | foto (os galhos cruzam o "A" de ANFITRIAO) |
| hora do jogo igual para todos, chat, lista com ping | nível 4: o chat de um bot chega ao outro; o relógio do bot (que não tem HUD e não anda sozinho) avança 20 s de jogo só pelos acertos do servidor; o ping aparece no resultado de cada bot (20–23 ms em localhost) |
| entrar e sair a qualquer momento, senha, lotação | nível 4 (recusa por senha e por "cheio" com o motivo certo) |
| até 16 juntos (teto 32) | medido: 16 bots, 5,9 KB/s por cliente |
| a lanterna do outro, apontando para onde ele olha | medido: o chão na frente dele fica 1,70× mais claro com a lanterna para baixo, 1,16× para cima (`lanterna_do_amigo_baixo_e_cima.png`) |
| o carro do outro de farol aceso, com o facho na névoa | foto `anfitriao_ve_carro_e_lanterna.png` |
| os amigos no minimapa (caneta azul; preso na borda quando está longe) | a mesma foto |
| abrir a prancha ou o menu sem congelar ninguém | medido: com o anfitrião na prancha, o relógio de quem estava conectado andou 30 s de jogo (antes: 2 s, parado) |
| agachar, sentar, pedalar, passos do outro, "..." quando ele está no menu | no código; **sem prova visual ainda** |

**Ainda não (fases seguintes, em `13`):**

- porta aberta, item pego, planta regada e dinheiro por um valerem para todos (Fase 3). Hoje cada um mexe no **próprio** mundo
- o carro do outro ter colisão: hoje você atravessa ele, e o trânsito da sua máquina pode parar em cima dele (Fase 4)
- ver o motorista pelo vidro: o vidro dos carros é opaco para todo mundo, NPC incluído (decisão de render)
- entrar de carona no carro do outro (Fase 4)
- missão em grupo (Fase 5)
- o servidor dedicado lembrar de você e do mundo depois de reiniciar (Fase 6)
- JOGAR ONLINE no título e folha de viagem (Fase 7)
- NPC, blitz e inimigo iguais para todos (Fase 8)
- convite pela Steam (Fase 9)

# MULTIPLAYER

Pasta de planejamento do co-op. **Nada aqui é código.** Nada aqui autoriza implementar.

O jogo hoje é single-player de ponta a ponta. Esta pasta descreve o que precisa existir para dois jogadores criarem uma partida no menu, se verem na introdução (os dois no carro desde o primeiro plano) e jogarem online de forma eficaz em 2026.

O look PSX **não é teto de arquitetura**. Outra frente está levando o projeto a Vulkan, com melhorias gráficas; PSX passa a ser opção do jogador nas configurações. O netcode tem de funcionar nos dois caminhos de render. O que ainda limita dois jogadores no mesmo mundo é o código (um `Player`, um alvo de streaming, zero de rede) — não o dither.

Comece em [`PLANO/00_LEIA-ME.md`](PLANO/00_LEIA-ME.md).

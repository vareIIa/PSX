# 00 — Leia-me

> Bíblia de execução do multiplayer de *Névoa e Dither* / SHIMOKAWA.
> Versão 1.0 — 14/09/2026.
> Mapeamento contra o código em `playable` (Godot 4.7.2). Nenhum arquivo desta pasta altera o jogo.

## O que isto é

Um plano passo a passo, detalhado o bastante para um profissional (ou um agente) executar sem reinventar a arquitetura no meio do caminho. Cobre:

- o estado real do repo hoje
- as decisões de produto que **não** podem ficar implícitas
- a arquitetura de rede que cabe neste jogo (não num MMO, não num shooter)
- cada sistema que hoje assume *um* jogador
- o menu, o lobby diegético, a criação de dois personagens
- a introdução com os dois no Marea desde o plano 1
- a ordem de fases, os testes e o que é proibido

## O que isto não é

- Não é autorização para começar a implementar. O pedido que gerou estes arquivos foi *mapear e documentar*.
- Não é um design doc genérico de “Godot multiplayer”. Cada parágrafo aponta para arquivo, autoload ou constante deste projeto.
- Não substitui `docs/PROMPT-MESTRE.md`, `docs/ART-BIBLE.md`, `docs/UI-BIBLE.md` nem `docs/PADROES-ENGENHARIA.md`. Onde houver conflito, o canon do jogo ganha — **exceto** o não-objetivo “não tem multiplayer”, que a Fase 0 emenda.

## Como usar

1. Leia este índice.
2. Leia **01 → 03** de uma vez (estado, decisões, arquitetura). Sem isso as fases não fazem sentido.
3. Quando for executar uma fase, leia o capítulo técnico correspondente **e** a fase em `13_FASES.md`.
4. Não pule fase. A Fase 7 (Steam) em cima de um jogo que ainda chama `get_first_node_in_group(&"player")` em 32 lugares é um convite que conecta e um jogo que quebra.

## Ordem de leitura

| # | Arquivo | Lê quando |
|---|---|---|
| 00 | Este arquivo | Sempre |
| 01 | [`01_ESTADO_ATUAL.md`](01_ESTADO_ATUAL.md) | Antes de qualquer fase |
| 02 | [`02_DECISOES.md`](02_DECISOES.md) | Antes de qualquer fase. Se uma decisão mudar, atualize **este** arquivo, não o código primeiro |
| 03 | [`03_ARQUITETURA.md`](03_ARQUITETURA.md) | Antes de qualquer fase |
| 04 | [`04_CONTRATO_DE_REDE.md`](04_CONTRATO_DE_REDE.md) | Antes das Fases 1 e 3 |
| 05 | [`05_PLATAFORMA_STEAM.md`](05_PLATAFORMA_STEAM.md) | Antes da Fase 7; o fallback LAN está na Fase 1 |
| 06 | [`06_REFATOR_O_JOGADOR.md`](06_REFATOR_O_JOGADOR.md) | Fase 2 |
| 07 | [`07_MUNDO_E_STREAMING.md`](07_MUNDO_E_STREAMING.md) | Fase 3 |
| 08 | [`08_SISTEMAS_DE_JOGO.md`](08_SISTEMAS_DE_JOGO.md) | Fase 3 |
| 09 | [`09_VEICULO.md`](09_VEICULO.md) | Fase 4 |
| 10 | [`10_MENU_E_LOBBY.md`](10_MENU_E_LOBBY.md) | Fase 6 |
| 11 | [`11_CRIACAO_DOIS.md`](11_CRIACAO_DOIS.md) | Fases 5–6 |
| 12 | [`12_INTRO_DOIS.md`](12_INTRO_DOIS.md) | Fase 5 |
| 13 | [`13_FASES.md`](13_FASES.md) | **O passo a passo.** É a ordem de trabalho |
| 14 | [`14_TESTES_E_ACEITE.md`](14_TESTES_E_ACEITE.md) | Toda fase, na hora de dizer “pronto” |
| 15 | [`15_RISCOS_E_NAO_FAZER.md`](15_RISCOS_E_NAO_FAZER.md) | Quando der vontade de atalhar |
| 16 | [`16_AUTOLOADS_E_ARQUIVOS.md`](16_AUTOLOADS_E_ARQUIVOS.md) | Inventário de toque. Consulta, não narrativa |
| 17 | [`17_CHECKLIST.md`](17_CHECKLIST.md) | Aceite final de “multiplayer funciona” |

## A tese em uma página

Este jogo é um survival horror de exploração numa cidade procedural (chunks de 32 m), um personagem, um volante, uma missão, um save. O look PSX (480×270, névoa como oclusão) é o caminho visual **atual** e vai virar opção; Vulkan corre em outra sessão. O canon original dizia que não tinha multiplayer.

O multiplayer que cabe aqui é **co-op de 2 amigos**, não MMO, não competitivo, não dedicated server. Em 2026 o caminho que realmente conecta duas casas sem o jogador abrir porta no roteador é:

```
Steamworks (identidade + convite + overlay)
  → GodotSteam 4.22 (GDExtension, Godot 4.7.2)
    → SteamMultiplayerPeer + relay
      → API alta do Godot (Spawner, Synchronizer, @rpc)
        → listen server (o anfitrião é o servidor)
```

A cidade **não viaja na rede**. O `ChunkBuilder` já é determinístico pela coordenada. Viaja o que *mudou* e quem *é gente*.

O look PSX **não é uma limitação do multiplayer**. Uma frente paralela está migrando o render para Vulkan e melhorias gráficas; PSX vira opção ingame (como névoa já é). Rede, lobby e sessão são **agnósticas de renderer**: o mesmo listen server serve o caminho Compatibility/PSX e o caminho Vulkan.

O risco técnico número um não é o Steam nem o dither. É o código assumir um único ser humano: `ChunkManager` segue um `alvo`, 32 sistemas perguntam `get_first_node_in_group(&"player")`, um inventário, um volante, uma missão. Dois corpos no mundo ainda exigem uma política de streaming (ver `07` e decisão P5), porque chunk custa memória e CPU em qualquer renderer — mas isso é engenharia de mundo, não contrato de 120 draw calls.

## Regras de execução (quando chegar a hora)

Valem as de `docs/PADROES-ENGENHARIA.md`, mais estas:

1. Single-player **não pode regredir**. CONTINUAR e NOVO JOGO continuam iguais.
2. Tipagem estática. `class_name` em script novo.
3. Número de estética da **UI** vem do UI-BIBLE, citado no comentário. Número de look 3D: o ART-BIBLE continua valendo no preset PSX; o caminho Vulkan tem o próprio contrato, e o netcode não depende de nenhum dos dois.
4. `--headless --path game --quit` limpo depois de cada unidade.
5. Rede se testa com **dois processos**, não com fé.
6. Captura visual da intro 2P entra em `captures/` com o mesmo rigor das outras cenas.
7. Um commit por unidade lógica. Fase não vira um commit de 80 arquivos.

## Vocabulário

Estes termos são canônicos neste plano. Não invente sinônimo.

| Termo | Significa |
|---|---|
| **Anfitrião / host** | Peer 1. Simula o mundo. É um jogador, não um servidor cego |
| **Convidado / client** | Peer 2. Manda input, interpola o que o host manda |
| **Listen server** | O processo do anfitrião é o servidor *e* um jogador |
| **Sessão** | Uma viagem de dois, do lobby até alguém sair |
| **Leash** | Política de distância entre os dois corpos (design + streaming). Não é lei do PSX; é escolha de sessão. Ver P5 |
| **Jogador local** | O `Player` cujo `multiplayer_authority` é este peer |
| **Parceiro** | O outro `Player` da sessão |
| **Seed de mundo** | Inteiro que o host escolhe; os dois geram a mesma cidade |
| **Flavor local** | Pedestre/trânsito que cada um vê diferente e ninguém interage |
| **Lobby-documento** | A tela de convite no vocabulário de ficha/carteira, não HUD de e-sport |
| **Cinema travado** | Intro avançada só pelo host; o convidado assiste os mesmos cortes |

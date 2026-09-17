# 10 — Menu e lobby

> Fase 6. O lobby é produto, não um `ItemList` cinza.
> Vocabulário: `docs/UI-BIBLE.md`, `ui_estilo.gd`, ficha, carteira, celular, CRT.

## 1. O título hoje

`menu.gd`, painel TITULO, entradas:

```
CONTINUAR
NOVO JOGO
MAPA
OPCOES
SAIR
```

CRT B&W sobre a mata da Estrada Velha. Fonte serif no boot, bitmap no resto. Título “SHIMOKAWA”, oxblood.

Acrescentar **uma** linha, não um submenu “Multiplayer”:

```
CONTINUAR
NOVO JOGO
JOGAR COM AMIGO
MAPA
OPCOES
SAIR
```

Posição: imediatamente abaixo de NOVO JOGO. É o mesmo peso, não um extra de opções.

Se Steam não iniciou, a linha existe mesmo assim: entra no lobby em modo LAN (Fase 1) ou mostra o recado “Abre a Steam” (Fase 7) com a opção de código/IP em dev.

## 2. O que o lobby não é

- Não é lista Steam default.
- Não é HUD de CS (pronto em verde neon, ping, slots 1/16).
- Não é split da tela 480×270.
- Não abre um browser de login.

É uma **folha de viagem**, a mesma gramática da ficha de cadastro e da carteira: papel, tinta `2a1f16`, visto, retrato 3D.

## 3. Estrutura da tela (480×270)

Margem 7 px. Fontes nativas via `UiEstilo.aplicar`.

```
┌──────────────────────────────────────────────────────────┐
│  VIAGEM — SÃO THOMÉ DAS LETRAS              14/11/1998   │  psx_pequena, tinta fraca
│  ──────────────────────────────────────────────────────  │
│                                                          │
│   ┌─────────────┐     túnel     ┌─────────────┐          │
│   │  RETRATO 3D │               │  RETRATO 3D │          │
│   │  anfitrião  │               │  convidado  │          │
│   │  MOTORISTA  │               │  PASSAGEIRO │          │
│   └─────────────┘               └─────────────┘          │
│    NOME                      ou  silhueta + AGUARDANDO   │
│    visto PRONTO / ESPERA                                 │
│                                                          │
│   [ CONVIDAR ]     [ CÓDIGO 4A2C ]     recado uma linha  │
│                                                          │
│   [W/S] retrato   [E] pronto   [ESC] desistir            │
└──────────────────────────────────────────────────────────┘
```

Fundo: a mata que o título já usa (`usar_fundo_vivo` / `_fundo_mata`). A folha é um Control desenhado à mão, como `ficha_cadastro.gd` e `criacao.gd` — **não** 15 Labels soltos.

Retratos: o mesmo SubViewport de `CriacaoAparencia` (o `Corpo` de verdade). Trocar camisa no passo anterior atualiza o retrato. Silhueta do lado vazio: `Corpo` sem ficha, modulate baixo, ou um retângulo de hachura.

Carimbo PRONTO: verde `Missoes.VERDE` (`2f6b2a`), torto alguns graus, como o visto da carteira. ESPERA: tinta fraca.

## 4. Fluxo

```
TÍTULO ── JOGAR COM AMIGO
              │
              ├─ Steam ok ── criar lobby friends-only (host)
              │                 ou join_requested / +connect_lobby (convidado)
              │
              ├─ Dev ── --mp-host / --mp-join
              │
              ▼
         FOLHA DE VIAGEM
              │
              ├─ cada um: se ainda não tem ficha nesta sessão
              │      → Painel NOME (ficha) → Painel APARENCIA (carteira)
              │      → volta à folha com retrato
              │
              ├─ CONVIDAR → overlay Steam (Fase 7) / mostra IP (Fase 1)
              │
              ├─ os dois PRONTO
              │      → anfitrião vê ASSINAR (mesmo gesto da ficha)
              │      → viagem_comecou
              │
              ▼
         INTRO (12)  ou  --mp-pular-intro → praça
```

O anfitrião **não** começa com 1 pronto. Os dois carimbam. Assinar é do host, como “é a viagem dele” na folha.

Convidado que entra no meio da criação do host: espera na folha, silhueta, vê “fulano está na carteira”.

## 5. Convite e “login”

**Steam (Fase 7):** o login *é* ter a Steam aberta. Não há e-mail. CONVIDAR chama o overlay. Lista de amigos **dentro** do jogo, se quiserem diegese: reusar a **agenda do celular** (`celular.gd`) — nomes da lista `Steam.getFriendCount` / `getFriendByIndex`, filtro `ingame` / `online`. Não inventar um terceiro widget.

**Dev / LAN (Fase 1):** a folha mostra `24567` e o IPv4 local. O segundo processo `--mp-join=IP`. Sem romance, sem fingir que é Steam.

**Código de sala (plano B):** quatro caracteres no carimbo, tipo placa. Fora da v1.

## 6. Painel novo no Menu

```
enum Painel { BOOT, TITULO, OPCOES, MAPA, NOME, APARENCIA, LOBBY }
```

`lobby.gd` é `class_name Lobby` extends Control, filho do Menu ou CanvasLayer 150 (abaixo do pós? o título CRT hoje é o próprio menu. A folha de viagem pode **sair** do B&W: a mata em cor, a folha em papel — a criação já faz isso (`na_estrada` no menu). Usar o mesmo ramo: NOME, APARENCIA e LOBBY são “na estrada”, não CRT.

Camada: 150 com o menu, vinheta UI que já existe.

## 7. Estados visuais

| Estado | Folha |
|---|---|
| CONECTANDO | “Ligando…” no recado, retratos vazios |
| AGUARDANDO AMIGO | host preenchido, silhueta à direita, CONVIDAR pulsa |
| CRIANDO | um dos lados “NA CARTEIRA” |
| OS DOIS AQUI | retratos vivos, visto ESPERA |
| PRONTOS | dois carimbos, host pode assinar |
| COMEÇANDO | fade preto → intro |
| FALHOU | recado “Não deu. Cód. X”, volta ao título depois de 3 s |
| AMIGO SAIU | silhueta de novo, host permanece |

## 8. Chat

Uma linha, 80 chars, fonte pequena, 44 letras/s se quiserem o mesmo ritmo da conversa. Filtro Steam quando houver. Não é prioridade do aceite da Fase 6 — o recado de sistema (“MARIA entrou”) basta.

## 9. Som

Já existe `AudioDirector.tocar_ui`. Carimbo = carimbo da carteira se houver. Convite = um toque de linha (se existir `telefone` no banco; senão o UI click). Não loop de lobby-music diferente do título — o título já tem os grilos da mata.

## 10. Aceite da Fase 6

- Título tem JOGAR COM AMIGO, 480×270, UI-BIBLE (margem, font_size).
- Dois processos ENet: host cria, join entra, dois retratos.
- Cada um passa na carteira sem resetar a ficha do outro.
- Host não dispara intro com 1 jogador.
- ESC no lobby destrói o peer e volta ao título, single intacto.
- Captura `captures/multiplayer/lobby_dois.png` e `lobby_espera.png`.

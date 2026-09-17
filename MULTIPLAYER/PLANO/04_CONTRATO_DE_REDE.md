# 04 — Contrato de rede

> O que viaja, o que não viaja, de quem é a verdade.
> Se uma feature nova não cabe numa linha desta tabela, ela não entra na sessão.

## 1. Classificação

Tudo no jogo cai em uma de quatro caixas.

### A — Local puro

Nunca sai da máquina. Settings, look, áudio de ambiente, bob de câmera, fôlego na barra, scanline.

### B — Determinístico

Os dois calculam igual a partir do seed / id / coordenada. Não manda payload. Cidade, ficha de NPC estranho, UV de `Aparencia`.

### C — Replicado contínuo

Synchronizer. Posição, rotação, pose, velocidade do carro possuído.

### D — Evento confiável

RPC reliable. Porta, item, assento, missão, fala, corte de cinema, “fulano saiu”.

## 2. Tabela mestra

| Dado | Caixa | Authority | Notas |
|---|---|---|---|
| Malha de chunk, poste, fachada | B | — | seed + coord |
| Clima visual (grão, PSX/Vulkan, FOV) | A | local | Settings |
| Raio de **carga** de chunk | sessão | host define | ver P13 |
| Preset de névoa **visual** | A | local | pode divergir |
| Relógio de jogo (minutos) | D | host | 22:43 igual nos dois |
| Posição / yaw do Player | C | peer dono, host valida | 15–20 Hz |
| Pitch da câmera | A | local | o outro não precisa do olhar interno; em TP o yaw já conta |
| Agachar, correr, lanterna ligada | C | peer dono | bool/enum |
| Fôlego, bateria (número) | A | local | o outro vê a lanterna acesa (bool), não o % |
| Vida | D | host | `feriu` / `curar` |
| Inventário slots | D | host confirma pickup | UI local lê a cópia |
| Item no chão | D | host | some nos dois |
| Porta aberta | D | host | `WorldState.definir` |
| Plantio / regar / colher | D | host | |
| Missão `atual` + etapa | D | host | |
| Conversar com NPC | D | host | um falante; o outro vê “fulano está falando com X” |
| Celular, GPS, documento, terminal | A | local | consulta CPF é B (função pura) |
| Destino do GPS (pin) | D opcional | quem marcou | missão compartilhada já tem alvo; pin pessoal pode ser local |
| Carro possuído (transform, vel, marcha) | C | host | input do motorista é RPC |
| Assento (livre / motorista / passageiro) | D | host | |
| Pedestre de rua, carro de trânsito | A na v1 | local | flavor |
| Pedestre abordado, motorista que desceu | D | host | replica o id + transform |
| Blitz | D | host | os dois veem a mesma |
| Multidão da casa da fumaça (convidados) | B/D | host | interior é instância do host |
| Cinema: plano, t, legenda | D | host | |
| Aparência do parceiro | D no lobby | cada um manda a sua | metadata, antes da intro |
| Áudio de passo do parceiro | derivado de C | local | toca se velocidade > limiar |
| Voz | fora | Steam/Discord | |
| Save | A no disco do host | host | |

## 3. RPCs nomeados (contrato)

Nomes no passado, como o resto do projeto. Canal default 0. Reliable salvo nota.

| RPC | Quem chama | Quem executa | Payload |
|---|---|---|---|
| `pedido_pronto` | client | host | `bool` |
| `roster_atualizado` | host | todos | array de `RosterPeer` |
| `viagem_comecou` | host | todos | `{seed, hora, ids}` |
| `plano_de_cinema` | host | todos | `{cena, plano, t}` |
| `pedido_input_veiculo` | motorista | host | `Vector3` acelera/freia/esterco |
| `pedido_assento` | client | host | `enum { MOTORISTA, PASSAGEIRO, DESCER }` |
| `assento_mudou` | host | todos | `{peer, assento, carro_path}` |
| `pedido_pegar_item` | client | host | `{item_id, node_path}` |
| `item_sumiu` | host | todos | `{node_path}` / chave WorldState |
| `pedido_porta` | client | host | `{coord, chave}` |
| `mundo_mutou` | host | todos | `{coord, chave, valor}` |
| `pedido_falar` | client | host | `{npc_path}` |
| `fala_aberta` | host | todos | `{peer, npc_id}` |
| `fala_fechou` | host | todos | `{peer}` |
| `missao_atualizou` | host | todos | dict `Missoes.atual` |
| `pedido_entrar_interior` | client | host | `{semente, tipo, porta}` |
| `interior_aberto` | host | todos | `{semente, tipo, retorno}` |
| `peer_saiu` | host | resto | `{peer, motivo}` |
| `sessao_encerrada` | host | todos | `{motivo}` |

Client **nunca** executa efeito de mundo no próprio `_input` e depois avisa. O fluxo é pedido → host → broadcast. Exceção: movimento a pé (C), para não sentir lag de 80 ms andando.

## 4. Movimento a pé — o meio-termo

Godot não tem predição pronta. A 2,4 m/s, 80 ms de RTT é 20 cm. Aceitável.

Desenho:

1. Peer dono aplica input local no próprio `CharacterBody3D` (authority dele).
2. Synchronizer manda transform para o host e para o parceiro.
3. Host **não** reconcilia a cada frame. Host rejeita só absurdo: teleporte > 8 m num pacote, velocidade > 2× corrida, movimento com `travado` / em cinema / em conversa.
4. Rejeição: RPC `corrigir_transform` (raro).

Isso é “client-authoritative com guarda”, não “server-authoritative puro”. Para horror co-op de amigos é o que fecha. Shooter pediria outra coisa; este jogo não é.

Carro **não** usa este meio-termo. Física de veículo é host-only. O motorista manda input (D), o host simula, Synchronizer devolve o casco. A 68 km/h na terra, interpolação de 50 ms é 0,9 m — o passageiro sente se o interpolate estiver errado. Usar `interpolation` do Synchronizer.

## 5. Snapshot de mundo

`WorldState.para_dicionario()` já serializa. Quando o convidado entra no lobby **depois** de o host já ter andado? v1 **não** tem mid-session join. Os dois entram juntos no `comecar_viagem`. O dict de mundo no começo é vazio (partida nova) ou o save do host (se um dia houver “convidar no CONTINUAR” — fora da v1).

Se o convidado chega atrasado no lobby, ele espera o host apertar. Não entra no meio da praça.

## 6. Idempotência

Dois pedidos de pegar o mesmo item no mesmo tick: host processa em ordem de `get_rpc_sender_id` / fila. O segundo recebe falha silenciosa (item já não existe). Não spawnar dois.

Porta: toggle com versão (`WorldState` guarda bool). O segundo toggle no mesmo frame não inverte duas vezes se o host serializar.

## 7. Relógio

`WorldState.relogio` é a hora da cidade. Host manda `minutos()` quando muda o minuto de jogo, e no `viagem_comecou`. Cliente **não** avança o relógio no próprio process: aplica o que chegou e interpola visualmente os ponteiros se houver.

## 8. O que nunca entra num pacote

- Shader, material, textura
- ArrayMesh de chunk
- Settings, bus de áudio, volume
- Estado do menu de opções
- CaptureTool, flags `--shot`
- Conteúdo de `user://save_*.json` inteiro (salvo um dia um “mandar save”, que não é v1)
- Posição da mouse look em primeira pessoa
- Texto digitando caractere a caractere na conversa (manda a fala fechada / a escolha). A digitação 44 letras/s é local, igual hoje

## 9. Segurança mínima (mesmo entre amigos)

- Validar path de item: tem que ser um `ItemNoChao` no raio de interação do sender
- Validar porta: mesma regra de `Interativo` (alcance 2,4 m)
- Rate limit: 10 pedidos de mundo por segundo por peer; excesso descarta
- String de chat: teto 80 chars, filtro Steam quando existir

Não é anticheat de MMO. É para o desync não abrir porta “de 200 m de longe” e o parceiro cair no vazio.

# 20 — Protocolo de fio

> Especificação do que viaja, byte a byte. A fonte da verdade é `game/src/net/protocolo_rede.gd`; se divergir, o código ganha e este arquivo é corrigido.
> `ProtocoloRede.VERSAO = 2` (21/09/2026). Qualquer mudança de **formato** aqui sobe a versão. Mudança no **gerador de mundo** não precisa mais de ninguém lembrar: a assinatura da cidade (§2.1) recusa sozinha.
>
> | Versão | O que mudou |
> |---|---|
> | 1 | Fase 1: estado de 21 B, flags de 8 bits |
> | 2 | estado de 23 B (arfagem da cabeça, flags de 16 bits); assinatura da cidade na autenticação e no anúncio; motivo de recusa `cidade` |

## 1. Transporte

| Item | Valor |
|---|---|
| Peer | `ENetMultiplayerPeer`, UDP |
| Compressão | `ENetConnection.COMPRESS_RANGE_CODER`, **nos dois lados** (compressão diferente = lixo) |
| Canais | 0 = evento confiável; 1 = estado não confiável ordenado |
| Porta do jogo | 24567/UDP |
| Porta de descoberta | 24568/UDP |
| Lotação ENet | `max_jogadores + 4` (folga para recusar com motivo, em vez de timeout mudo) |
| Timeout por peer | `set_timeout(0, 3000, 8000)`: queda depois de 8 s de silêncio |
| Relay de cliente para cliente | desligado (`server_relay = false`) |
| Objetos em Variant | desligado (padrão do `SceneMultiplayer`; `bytes_to_var` sem objetos) |

## 2. Autenticação (antes do peer existir)

Mensagens no canal de autenticação do `SceneMultiplayer`, cada uma um `Dictionary` em `var_to_bytes`, com no máximo 8192 bytes; abaixo de 4 bytes nem se decodifica.

```
servidor → cliente   desafio   { tipo:"desafio", jogo, v, cidade:hex16, nonce:hex32, senha:bool, nome, n, max }
cliente  → servidor  pedido    { tipo:"pedido", jogo, v, cidade:hex16, nome, aparencia:{...}, prova:sha256hex|"" }
servidor → cliente   veredito  { tipo:"veredito", ok:bool, motivo:"" | jogo | versao | cidade | senha | cheio | pedido }
```

- `prova = sha256(nonce + ":" + senha)`, com o `nonce` novo a cada conexão (16 bytes de `Crypto.generate_random_bytes`).
- O servidor julga nesta ordem: `jogo` → `v` → `tipo` → **`cidade`** → senha → lotação (`ProtocoloRede.julgar_pedido`). A versão vem antes da cidade: quem está em outra versão lê "Versão diferente", que diz o que fazer.
- O cliente confere a cidade do desafio **antes** de mandar o pedido, para ler o motivo sem esperar a volta; o servidor confere de novo, porque é ele quem decide.
- Aceito: `complete_auth(id)` dos dois lados, e só então `peer_connected`.
- Recusado: veredito com motivo, e o servidor derruba **2 s** depois, se o cliente ainda não tiver saído (19 §3, linha 5).
- O servidor guarda nome e aparência **saneados** (`sanear_nome`, `sanear_aparencia`), e o cliente saneia de novo o que recebe.

### 2.1 Assinatura da cidade

`AssinaturaDoMundo.calcular(construir)` (`net/assinatura_do_mundo.gd`, puro): `sha256` de um resumo de 4 chunks fixos — `(8,−2)` a praça, `(−3,3)` o nascimento, `(0,0)`, `(4,9)` —, construídos com o mesmo `ChunkBuilder.construir` do jogo. Por chunk: cada prop (tipo, posição ao **decímetro**, semente), quantas formas de colisão, quantos triângulos. Os props carregam a altura do terreno, então o relevo entra junto. 16 caracteres hex (64 bits).

| Onde | Quando | Custo medido |
|---|---|---|
| Dedicado | na subida, **sem thread**, antes de "pronto" (em thread, a primeira compilação do gerador disputava o carregador com o laço: quadro de 100–120 ms com 8 entradas juntas) | 110–154 ms |
| Anfitrião | ao hospedar, em thread (o jogo já tem o gerador compilado e o relevo quente) | ~28 ms quente |
| Cliente | ao chamar `entrar`, em thread; a conexão e o desafio levam mais que isso | 81 ms frio |
| Bot de teste | **antes** de ligar (senão a compilação caía no meio da medida dos outros bots) | idem |

Se a thread terminar sem resultado (script da cidade que não compila), a sessão segue **sem** assinatura, e a versão continua valendo. O dedicado escreve `assinatura da cidade INDISPONIVEL` no log.

O que ela pega, medido no nível 4: um bot com `--sem-relevo` (cidade plana) entrando num dedicado com relevo é recusado com "Cidade diferente. Atualize o jogo dos dois lados.".

## 3. Estado de um corpo (23 bytes, +5 com carro)

Little-endian (`StreamPeerBuffer`).

| Campo | Tipo | Bytes | Observação |
|---|---|---|---|
| pos.x, pos.y, pos.z | f32 | 12 | finitos; y em −200..5000; \|x\|,\|z\| < 10⁶ |
| yaw | u16 | 2 | `fposmod(yaw, TAU) / TAU * 65535`; passo de 0,0055° |
| rapidez | u16 | 2 | cm/s |
| **arfagem** | u8 | 1 | cabeça, −80°..+80°; 128 = horizonte exato; passo de 0,63° |
| flags | **u16** | 2 | abaixo; bit desconhecido é zerado na leitura |
| espaço | u32 | 4 | 0 rua, 1 Estrada Velha, ≥16 interior (`16 + hash([tipo, semente]) & 0x3FFFFFFF`) |
| modelo | u8 | 1 | só com `F_CARRO`; `Carroceria.Modelo` |
| semente | s32 | 4 | só com `F_CARRO`; a tinta sai da semente como no `Carro` |

Flags: `1 AGACHADO · 2 CORRENDO · 4 LANTERNA · 8 NO_CHAO · 16 CARRO · 32 BICICLETA · 64 TELEPORTE · 128 SENTADO · 256 AUSENTE · 512 FERIDO · 1024 CAIDO · 2048 FALANDO · 4096 CARONA`. `FERIDO`, `CAIDO`, `FALANDO` e `CARONA` são reservados para as Fases 3 e 4: existem para o formato não mudar de novo.

**Com `F_CARRO`, três bits mudam de sentido** (quem dirige não agacha, não corre e não segura lanterna):

| Bit | A pé | No carro | Nome no código |
|---|---|---|---|
| 4 | lanterna | motor ligado: farol, facho, lanterna traseira | `F_FAROL` |
| 1 | agachado | freando: luz de freio | `F_FREANDO` |
| 2 | correndo | freio de mão | `F_FREIO_DE_MAO` |

`F_TELEPORTE` é declarado pelo cliente quando ele mesmo pulou (mudou de espaço, andou mais de 8 m sem carro, ou o jogo chamou `Sessao.anunciar_teletransporte()`). Quem desenha corta seco em vez de deslizar. O servidor aceita o salto sempre que o espaço muda junto; **no mesmo espaço, no máximo uma vez a cada 3 s** (`ValidadorMovimento.INTERVALO_TELEPORTE`), e cada uso vai no log.

## 4. Cliente → servidor: `_estado_do_cliente` (35 bytes a pé, 40 de carro)

```
u32 seq            monotônico por conexão
f64 t_amostra      hora do SERVIDOR (estimada pelo cliente) em que o estado foi lido
Estado
```

- 20 Hz, canal 1, `unreliable_ordered`, **só depois do primeiro instantâneo**, quando o relógio já existe (19 §3, linha 8).
- Tamanho diferente de 35 ou 40 bytes, ou estado inválido: o pacote é descartado inteiro.
- `seq` menor ou igual ao último: descartado.
- `t_amostra` é presa em `[chegada − 1 s, chegada + 0,05 s]` (`hora_de_amostra_aceita`); não finita, ou ≤ 0, vira a hora de chegada.
- Teto de 60 pacotes por segundo por cliente; o excesso é descartado.

## 5. Servidor → cliente: `_instantaneo` (13 + 29·n bytes a pé)

```
u32 tick
f64 t_servidor
u8  n                 ≤ 255
n × { u32 id, u16 idade_ms, Estado }
```

- 20 Hz, canal 1, `unreliable_ordered`, **um por destino**.
- Entra só quem está **no mesmo espaço** do destino e a **≤ 160 m** no plano XZ (P19). Instantâneo vazio também sai: ele carrega a hora.
- `idade_ms = round((t_servidor − t_amostra) * 1000)`, presa em 0..65535. O cliente reconstrói `t = t_servidor − idade`.

Tamanhos: 2 jogadores = 42 B; 8 = 216 B; 16 = 448 B; 32 = 912 B (a pé, antes da compressão).

## 6. Eventos confiáveis (canal 0)

| RPC | Direção | Payload | Quando |
|---|---|---|---|
| `_boas_vindas` | servidor → quem entrou | `{id, jogadores:{id:perfil}, servidor, mensagem, relogio:f64, chegada:V3, olhar:V3}` | ao completar a entrada |
| `_jogador_entrou` | servidor → os outros | `id, perfil` | idem |
| `_jogador_saiu` | servidor → todos | `id, motivo` | `peer_disconnected` |
| `_relogio` | servidor → todos | `segundos:f64` | a cada 5 s; o cliente acerta se descolou mais de 1 s |
| `_pings` | servidor → todos | `{id: ms}` (não confiável) | a cada 2 s |
| `_pedir_chat` | cliente → servidor | `texto` | até 5 por 5 s; ≤ 96 caracteres saneados |
| `_chat` | servidor → todos | `nome, texto` | difusão |
| `_aviso` | servidor → um ou todos | `texto` | expulsão, anúncio |
| `_corrigir` | servidor → um | `pos:V3` | validação `corrigir` |

Perfil: `{nome:String ≤ 24, aparencia:{chaves do Corpo}, ping:int}`.

Todo RPC de servidor é `@rpc("authority", ...)`: só o peer 1 consegue chamar, e o Godot recusa os outros. Todo RPC de cliente confere `multiplayer.is_server()` e se o remetente está na lista.

## 7. Relógio e desenho do lado do cliente

- `RelogioDeRede`: amostra `t_servidor − t_local` a cada instantâneo; o desvio é o **máximo** numa janela de 2 s. **Sobe na hora** (toda amostra é limite inferior) e **desce no máximo 5 %** do tempo real: nunca volta.
- Desenho em `agora_servidor − 0,12 s`. Interpolação linear da posição, da rapidez e da arfagem; giro pelo arco curto; o que é discreto troca na metade.
- Na rua, o boneco só é desenhado onde **esta** máquina tem chunk montado (`ChunkManager.esta_carregado`); sem chunk nenhum (bot, dedicado), não se confere.
- Sem dado adiante: extrapola na última velocidade por até 0,25 s, depois para.
- Salto (espaço diferente, `F_TELEPORTE`, ou mais de 8 m entre amostras, 24 m com carro): corta seco.
- Nada é desenhado antes de haver amostra para o instante (`cobre`). Sem estado há mais de 1 s: o boneco some.

## 8. Descoberta na rede local

JSON UTF-8, até 512 bytes, 1 por segundo, para `255.255.255.255` **e** para o broadcast dirigido de cada IPv4 local: `/8` para 25.x (Hamachi) e 26.x (Radmin), `/24` para o resto.

```json
{"jogo":"nevoa_e_dither","v":2,"nome":"MUNDO DE ZE","porta":24567,"n":3,"max":8,"senha":true,"cidade":"8efc3d95cbad2fd1"}
```

Some da lista depois de 4 s sem anúncio. Versão diferente aparece marcada "(outra versão)" e cidade diferente "(outra cidade)", sem sumir. `cidade` que não seja hex de até 16 caracteres é descartada na leitura. A escuta só fica ligada com o F7 aberto, porque a porta 24568 é uma por máquina.

## 9. Medidas de referência (régua de regressão)

`tools/mp_teste.sh --carga=16`, localhost, 21/09/2026. Versão 1 (estado de 21 B) e versão 2 (23 B):

| Medida | v1 | v2 |
|---|---|---|
| Erro do boneco remoto contra a verdade, p50 / p95 / máx. (2 bots) | 0,03–0,09 / 0,08–0,11 / 0,11–0,18 cm | 0,03–0,09 / 0,04–0,13 / 0,10–0,70 cm |
| Pior p95 entre 8 / 16 bots | 0,10–0,11 / 0,10 cm | 0,11–0,26 / 0,22 cm |
| Amostras sem dado (fome) | 0 % | 0–0,4 % |
| Banda recebida por cliente (2 / 8 / 16 jogadores juntos) | 1,0 / 3,1 / 5,9 KB/s | 1,04 / 3,27 / **6,01** KB/s (+2,6 % com 16; a previsão sem compressão era +11 %) |
| Ping em localhost | 20–23 ms (igual nas duas). Provável causa, não verificada: o ENet só confirma quando o jogo chama o *service*, uma vez por quadro de cada lado. Não é o RTT do loopback |
| Servidor: CPU / RAM com 8 jogadores | 0,5 % de um núcleo / 261 MB |
| Servidor: quadro mais longo | 17–40 ms (v2: 17–50 ms) |
| Servidor: assinatura da cidade na subida | — (v2: 110–154 ms, uma vez, antes de "pronto") |

Localhost não tem perda nem *jitter* de rede. As medidas dizem que a cadeia (relógio, carimbo, instantâneo, interpolação) está certa; não dizem como fica com 150 ms e 2 % de perda. Esse é o item 8.4 de `13`: medir com perda e atraso simulados.

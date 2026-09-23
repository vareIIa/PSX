# 18 — Servidor dedicado

> Novo na v2 (21/09/2026). Decisões: P2, P9, P17, P21, P22.
> Tudo o que está marcado **medido** foi rodado nesta máquina (Ryzen 7 9800X3D, 8 núcleos, Windows 11) com o código de `game/src/net/`.

## 1. O que o dedicado é hoje

Um processo sem tela, sem cidade, sem câmera, que:

- **autentica** quem chega: versão, senha com desafio e lotação, antes de o peer existir para o jogo;
- **valida** o movimento de cada um (`ValidadorMovimento`);
- **repassa** a cada cliente, 20 vezes por segundo, só quem está no mesmo espaço a menos de 160 m;
- **anda o relógio** da cidade e acerta o de todo mundo a cada 5 s;
- mantém a **lista** com ping a cada 2 s, o **chat** e os recados;
- escreve o estado no console a cada 60 s: jogadores, hora do mundo e quadro mais longo.

O que ele **ainda não** faz, em ordem de fase:

| Falta | Fase | Por quê importa |
|---|---|---|
| Ser dono do mundo (porta, item, plantio, missão) | 3 | Hoje cada cliente muda o próprio mundo; porta aberta num não abre no outro |
| Guardar mundo e perfis em disco | 6 | Reiniciar o servidor hoje zera tudo |
| Ter chão (colisão) em volta de cada jogador | 8 | Para NPC, blitz e inimigo do servidor andarem em algo |

## 2. Rodar

### 2.1 Pelo binário do repositório (desenvolvimento, qualquer PC)

```
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path game res://scenes/net/servidor_dedicado.tscn -- --porta=24567
```

### 2.2 Pelo executável exportado (**medido:** funciona)

```
cd game
../.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Servidor Dedicado Windows"
../export/servidor/NevoaEDither_Servidor.console.exe --headless -- --porta=24567
```

O preset `Servidor Dedicado Windows` (`game/export_presets.cfg`) exporta com `dedicated_server=true`. A linha abaixo, no `project.godot`, faz o build abrir **direto** na cena do servidor, e o jogo normal não é afetado, porque não tem a *feature tag* `dedicated_server`:

```
run/main_scene.dedicated_server="res://scenes/net/servidor_dedicado.tscn"
```

**Medido:** dois bots do editor entraram no executável exportado, com erro de 0,11 cm no p95. Reexportado com o protocolo 2 em 21/09 à noite: p95 de 0,11–0,12 cm, e um bot com `--sem-relevo` recusado com "Cidade diferente.".

**Servidor e jogo saem do mesmo commit.** Na subida, o dedicado calcula a assinatura da cidade (`07` §2.1) e a escreve no log:

```
[servidor 20:13:43] Nevoa e Dither 0.1.0 — protocolo 2
[servidor] assinatura da cidade 8c83a46996b8456f (91 ms)
```

Um jogador com outra cidade (outro commit do gerador, ou `--sem-relevo`) é recusado com o motivo. Isso não é teoria: a assinatura do repositório mudou **durante** 21/09 (`8efc3d95…` à tarde, `8c83a469…` à noite) porque a frente do relevo mexeu em `tem_patamar`. Um dedicado exportado de tarde recusaria o jogo exportado de noite, e é o certo: os dois veriam ruas em lugares diferentes. Para comparar à mão, o jogo e o servidor imprimem a mesma linha (`[sessao] cidade do servidor X, a minha Y` quando recusam). `INDISPONIVEL` no log quer dizer que o gerador não compilou nessa máquina; a entrada segue só pela versão.

Tamanho: **204 MB**, quase o do jogo. O modo *Dedicated Server* só corta textura e malha das pastas marcadas como *Strip Visuals* (aba *Resources* do preset), e nenhuma foi marcada ainda. Tarefa da Fase 6: marcar `assets/`, `resources/materials/` e `shaders/` como *Strip Visuals*, e medir de novo.

### 2.3 Linux

Os templates de export instalados (`%APPDATA%/Godot/export_templates/4.7.2.stable/`) são **só de Windows**. Para Linux:

1. Baixar os templates oficiais 4.7.2 (o `.tpz` completo) e instalar pelo gerenciador do editor, ou extrair os arquivos `linux_*` na mesma pasta.
2. Duplicar o preset como `Servidor Dedicado Linux`, `platform="Linux"`, `binary_format/architecture="x86_64"`.
3. `--export-release "Servidor Dedicado Linux"` → `NevoaEDither_Servidor.x86_64`.

Linux é o alvo certo para VPS: mais barato, sem licença, e é o que Docker e as orquestradoras esperam.

## 3. Configuração

Na primeira vez, o servidor escreve um modelo comentado em `user://servidor.cfg` (ou no caminho de `--config=`) e **nunca sobrescreve**. Três camadas, e a de cima ganha:

1. padrão do código (`ConfigServidor`)
2. `servidor.cfg`, seção `[servidor]`
3. linha de comando depois de `--`

| Chave no .cfg | Flag | Padrão | O que é |
|---|---|---|---|
| `porta` | `--porta=` | 24567 | UDP |
| `max_jogadores` | `--max-jogadores=` | 8 | 1..32 |
| `nome` | `--nome=` | SERVIDOR | aparece na lista da rede local e no "Você entrou em ..." |
| `senha` | `--senha=` | vazia | vazia = sem senha |
| `mensagem` | `--mensagem=` | vazia | recado para quem entra |
| `anunciar_lan` | `--sem-lan` | true | anúncio na rede local; desligue em VPS |
| `validacao` | `--validacao=` | registrar | `registrar` anota, `corrigir` devolve ao último ponto aceito |
| — | `--config=` | `user://servidor.cfg` | outro arquivo (volume de container) |
| — | `--sair-apos=` | 0 | encerra sozinho (teste) |

Onde fica `user://`:

- Windows: `%APPDATA%\Godot\app_userdata\Nevoa e Dither\`
- Linux: `~/.local/share/godot/app_userdata/Nevoa e Dither/`

Configuração errada (porta fora de 1024..65535, lotação fora de 1..32, validação desconhecida) **não sobe**. O servidor escreve o motivo e sai com código 2. Porta ocupada sai com código 3 e a mensagem "A porta 24567/UDP está livre?" (**medido**).

## 4. Rede

| Porta | Protocolo | Para quê | Abrir no firewall? |
|---|---|---|---|
| 24567 | UDP | o jogo | **sim** |
| 24568 | UDP | anúncio na rede local | só em LAN ou VPN de jogo |

É **UDP**. Regra de TCP não serve para nada aqui, e é o erro mais comum.

Windows (PowerShell como administrador):

```
New-NetFirewallRule -DisplayName "Nevoa e Dither servidor" -Direction Inbound -Protocol UDP -LocalPort 24567 -Action Allow
```

Linux (ufw):

```
sudo ufw allow 24567/udp
```

Servidor em casa, na internet: redirecionar a porta 24567/UDP do roteador para o IP do PC servidor. Não funciona se o provedor usa **CGNAT**: o IP que o roteador vê não é o IP público, e nenhum redirecionamento resolve. Nesse caso, use VPN de jogo (`21`) ou uma VPS.

## 5. Quanto custa (medido)

| Medida | Valor |
|---|---|
| CPU do servidor, 8 jogadores | **0,5 %** de um núcleo |
| RAM do servidor | **261 MB** (quase toda de autoload visual; ver §2.2) |
| Banda recebida por cliente, 16 jogadores juntos | **5,9 KB/s** |
| Banda de saída do servidor, 16 jogadores juntos | ~16 × 5,9 ≈ **95 KB/s** (0,8 Mbit/s) |
| Quadro mais longo do servidor | 17 a 40 ms |

Consequência prática: qualquer VPS pequena roda o servidor. O limite hoje é o teto de 32 jogadores (P1), não a máquina. Quando o servidor passar a ter chão e NPC (Fase 8), medir de novo: CPU e RAM vão subir com os chunks de colisão.

## 6. Onde hospedar

| Caminho | Quando | Observação |
|---|---|---|
| PC em casa + porta aberta | amigos, custo zero | não funciona com CGNAT; o PC fica ligado |
| PC em casa + VPN de jogo | amigos, sem mexer no roteador | cada um instala a VPN (`21`) |
| **VPS Linux** | servidor público ou 24 h | 1 vCPU e 1–2 GB sobram; abrir a UDP no painel do provedor **e** no firewall |
| Container (Docker) na VPS | reiniciar sozinho, atualizar trocando a imagem | §7 |
| Orquestradora (Edgegap, Agones/Kubernetes, PlayFab Multiplayer Servers) | muitos servidores sob demanda, matchmaking | só quando houver fila de jogadores; exige imagem de container e API de alocação. **Fora da v2** |

## 7. Container (modelo, **não testado**)

Nesta máquina não há Docker, e o export Linux depende dos templates (§2.3). O modelo abaixo segue o padrão de servidor Godot headless e precisa ser validado na Fase 6:

```dockerfile
FROM debian:bookworm-slim
RUN useradd -m jogo
WORKDIR /home/jogo
COPY NevoaEDither_Servidor.x86_64 ./servidor
RUN chmod +x ./servidor
USER jogo
EXPOSE 24567/udp
VOLUME ["/home/jogo/dados"]
ENTRYPOINT ["./servidor", "--headless", "--", "--config=/home/jogo/dados/servidor.cfg", "--sem-lan"]
```

```
docker run -d --restart unless-stopped -p 24567:24567/udp -v nevoa_dados:/home/jogo/dados nevoa-servidor
```

systemd, sem container:

```ini
[Unit]
Description=Nevoa e Dither servidor
After=network-online.target

[Service]
User=jogo
WorkingDirectory=/home/jogo
ExecStart=/home/jogo/servidor --headless -- --config=/home/jogo/servidor.cfg --sem-lan
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## 8. Segurança

| Camada | Estado |
|---|---|
| Autenticação antes do peer existir (`SceneMultiplayer.auth_callback`) | **feito**. Um peer sem autenticação não entrega RPC nenhum |
| Senha por desafio: `sha256(nonce:senha)`, nonce novo por conexão | **feito**. A senha não viaja; a prova de uma conexão não abre outra (teste de nível 2) |
| Versão e lotação | **feito**, com o motivo devolvido ao cliente |
| Tamanho exato de pacote de estado; posição finita e na faixa | **feito**. Pacote de tamanho errado nem é lido |
| Teto de 60 pacotes de estado/s e de 5 mensagens de chat/5 s por cliente | **feito** |
| Texto e aparência saneados no servidor **e** no cliente | **feito** |
| Movimento implausível | **feito**, `registrar` por padrão |
| `server_relay = false` (cliente não fala com cliente) | **feito** |
| **Criptografia do canal (DTLS)** | **não.** O ENet do 4.7.2 tem `ENetConnection.dtls_server_setup` (verificado na API). Precisa de certificado no servidor e de verificação no cliente. Fase 8 |
| Pacote confiável gigante (string de 10 MB num RPC) | **não coberto.** O teto do ENet (32 MB) não é exposto no GDScript; o texto é cortado depois de chegar. Mitigação: DTLS + lista de bloqueio. Fase 8 |
| Ban por IP ou token, lista de admins | Fase 8 |

## 9. Administração

Hoje:

- o console mostra entrada, saída, recusa com motivo, movimento implausível (no máximo uma linha por segundo por jogador) e a linha de estado a cada 60 s;
- `Sessao.expulsar(id, motivo)` e `Sessao.anunciar_a_todos(texto)` existem na API, mas **sem comando** para chamar de fora.

Fase 8: comandos pelo chat de quem estiver na lista de admins (`/expulsar NOME`, `/anunciar texto`) e um arquivo `admins.cfg` com os tokens (P21). Ler do console está fora: `OS.read_string_from_stdin` bloqueia o laço do Godot.

## 10. Persistência (Fase 6)

```
user://servidor/
  mundo.json                 WorldState.para_dicionario() + relogio.segundos + versao
  jogadores/<token>.json     inventario, vida, posicao, espaco, grupo, missao
```

- Salvar a cada 2 minutos e no encerramento (`_encerrar`), com escrita atômica (arquivo `.tmp` e depois renomear): queda de energia no meio da escrita não pode corromper o mundo.
- Ao entrar, o token (P21) acha o perfil. Sem perfil, a pessoa nasce no ponto de chegada, com o inventário inicial de `cidade._novo_jogo`.
- O `WorldState` do servidor é a verdade. O cliente recebe o dicionário inteiro na entrada (P17) e, depois, só as mudanças (`04`).

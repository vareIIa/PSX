# 07 — Mundo e streaming

> Fase 3. A cidade já é o milagre do projeto. O 2P não pode desmontá-la.
> PSX opcional / Vulkan na outra frente: o orçamento de malha muda; o fato de o ChunkManager seguir um alvo não muda.

## 1. O que já está certo

- Chunk 32 m, seed por coordenada → os dois geram a mesma rua (`01` §6, `03` §2).
- `WorldState` já é o dicionário de “o que o jogador mudou depois que o chunk morreu”. É exatamente o snapshot de mundo.
- Interiores e Estrada Velha já se separam por **altura** (Y=2000 / Y=4000), não por troca de `.tscn`. A cidade permanece carregada atrás da intro. Em 2P isso é ouro: não há “load da cidade” no blackout.

## 2. O que está errado para dois corpos

`ChunkManager.alvo: Node3D` — um.

`Multidao.alvo`, `Transito.alvo`, `BlitzManager.alvo` — um.

Dois jogadores a 300 m:

- ou o segundo anda no vazio (chunk não montou)
- ou o manager passa a seguir os dois e o custo de build/memória dobra

Isto **não** é o teto de 120 draw calls do ART-BIBLE. Aquele teto vale no preset PSX. No Vulkan o teto será outro. Mesmo no Vulkan, `WorkerThreadPool` com `MAX_EM_VOO := 4` e “um chunk instanciado por frame” continua verdadeiro: é thread e hitch, não dither.

## 3. Política v1 (P5)

`Sessao.alvo_de_streaming()` devolve:

1. Se os dois estão no mesmo veículo: o veículo.
2. Se os dois estão a ≤ R metros no XZ: o ponto médio.
3. Se estão a > R: o **host** (ou o local, ver abaixo) e o outro recebe aviso de leash.

R recomendado na v1: **80 m**. Não 18 m (névoa densa, look). Não “infinito”.

Por que o host no caso 3: um único raio de carga, previsível. O convidado que disparar vê pop-in — aceitável por uns segundos, o recado pede para esperar.

Fase 3b (depois do 2P jogável): dual-target, dois raios, culling por câmera. Não começar por aí.

## 4. Raio de carga vs look (P13)

Hoje o raio sai do preset de névoa. Se um jogador está em PSX/denso e o outro em Vulkan/longe:

- malhas diferentes
- um vê o outro aparecer do nada

Contrato: **o raio de carga da sessão é único**, definido pelo host no `viagem_comecou` (constante de co-op, não o preset visual). Névoa, grão, distância de fog no shader: locais. Chunk no disco: o mesmo conjunto nos dois.

Constante proposta:

```
# Sessão coop. Independente do FogPreset.
const RAIO_CARGA_COOP := 3   # anéis de chunk, ~96 m
```

Solo continua derivado do preset, como hoje.

## 5. WorldState

Já tem `definir` / `obter` / `para_dicionario` / `de_dicionario`.

Fase 3:

- Toda mutação passa no host.
- Host escreve `WorldState` e manda `mundo_mutou`.
- Cliente aplica no dict **e** no nó se o chunk estiver vivo.

Não deixar o cliente chamar `WorldState.definir` direto no `_input` da porta.

Chaves atuais (porta, item, visitados) continuam. Visitados: **união**. Se um dos dois pisou o chunk, o mapa de papel dos dois pode revelar — é viagem juntos. (Se a direção quiser mapa pessoal, é um bit a mais; v1 união é mais simples e combina com missão compartilhada.)

Relógio: host. Ver `04` §7.

## 6. Interiores

`interiores.gd`: um `dentro`, uma `_pilha`, teleporta `get_first_node_in_group("player")` para Y+2000.

v1, a regra mais barata que não quebra a casa da fumaça:

**Os dois entram juntos, ou ninguém entra.**

- Quem aperta E na porta: `pedido_entrar_interior`.
- Host checa: parceiro a ≤ 4 m da porta (ou já em conversa na calçada).
- Se sim: os dois teleportam, um interior só, `dentro = true` na sessão.
- Se não: recado “espera o fulano”. Porta não abre.

Sair: os dois saem, ou o que sai espera na rua e o interior continua até o segundo sair (mais estado). v1: **os dois saem juntos** no E do primeiro, com fade — ruim se um está no banheiro. v1.1: quem sai vai à calçada; o interior vive enquanto houver alguém dentro; o de fora não vê o de dentro (câmeras locais).

Recomendação de implementação: v1 juntos; v1.1 desacoplado **depois** da intro 2P existir. Interiores aninhados (estufa atrás da casa) já têm pilha — a pilha vira da sessão, não de um player.

Convidados da sala (`convidado.gd`): host spawna, replica id + transform barato, ou trata como B se a semente do interior for a mesma (provavelmente é). Conferir `casa_fumaca_builder` / semente. Se for seed pura, flavor local na sala também serve — conversar com um convidado específico precisa do id no host.

## 7. Multidão e trânsito

v1 **flavor local** (P, `04` tabela).

Não replicar 14 pedestres a 15 Hz. Horror na névoa até ganha se o outro “viu alguém que eu não vi”.

Exceções, host-owned:

- Pedestre com `Conversa.ativo` (o abordado)
- Motorista que desceu (`Carro.assumir` devolve à rua com o mesmo id)
- Blitz inteira
- Carro que um player assumiu (`Transito.entregar_ao_jogador` vira “entregar à sessão”)

`Transito._do_jogador`: hoje um. Vira `_dos_jogadores: Array` ou o carro na sessão. Um Marea, dois assentos (Fase 4). Não dois carros “do jogador” na v1 só porque há dois peers — eles compartilham o que assumiram.

## 8. Blitz, inimigo, ameaça

`BlitzManager` segue o alvo. Em coop: o host spawna **uma** blitz no caminho da missão / perto do ponto médio. Os dois a veem. FSM no host. Conversa com o policial: um falante (08).

`inimigo.gd`: persegue `mais_perto`. Dano no `Inventario` da vítima (host confirma). Desmaio é local (tela preta de um; o outro vê o corpo cair).

## 9. Chuva, céu, farol

Locais. Relógio comum já alinha “está de noite”. Se um desliga chuva nas opções (se existir) e o outro não, ok.

Farol de carro possuído: parte do nó do carro, replica com o casco.

## 10. Vulkan / horizonte longo

Quando a frente Vulkan abrir o far plane:

- Solo Vulkan pode pedir `raio_extra` (já existe no ChunkManager para inspeção aérea).
- Coop **não** herda automaticamente. `RAIO_CARGA_COOP` sobe numa decisão explícita, medida com dois processos, hitch por frame, memória.
- Dual-target é Fase 3b, com orçamento medido, não “o Vulkan deixa então liga”.

O netcode não espera a frente Vulkan. Os dois desenvolvimentos se encontram no `ChunkManager.alvo` e no raio de sessão.

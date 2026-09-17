# 09 — Veículo (dois no carro)

> Fase 4 no gameplay. A intro (Fase 5) usa `CarroCena`, que **não** é este `Carro`.
> Os dois arquivos precisam da mesma pose de banco e dos mesmos lados.

## 1. O que existe

### `Carro` — `game/src/world/carro.gd`

- `VehicleBody3D`, trânsito e jogável.
- `assumir(self)`: um piloto. Congela/descongela física. `_montar_motorista` põe um `Corpo` de NPC **atrás do vidro** quando ninguém assumiu.
- Ao assumir, o `Player` some (`visible = false`), colisão off, `CameraRig.seguir_veiculo`.
- `ponto_de_saida()`: lado do motorista.
- `_do_jogador` no `Transito`: um.

Não existe: assento de passageiro, segundo `ponto_de_saida`, pose ao volante, corpo visível de quem dirige para o outro jogador.

### `CarroCena` — `game/src/world/carro_cena.gd`

- Trilho na Estrada Velha. Sem `VehicleBody3D`.
- `mostrar_cabine` só no plano DENTRO.
- Zero ocupantes.

### `CarroCabine` — `game/src/world/carro_cabine.gd`

- Interior da cena. Túnel central **já separa** motorista (−X) e passageiro (+X).
- Comentário explícito: sem o túnel “a cabine lê como banco corrido de van”.
- Porta-luvas no lado do passageiro. Rádio no console.

### `Corpo._pose_sentado`

Pernas cruzadas, quadril a 24 cm do chão, casa da fumaça. **Inútil no banco.** Precisa de `_pose_volante` e `_pose_passageiro` (mãos no colo / no grab handle, pés no assoalho, tronco no encosto).

### Câmera no carro

`camera_rig.gd` documenta que primeira pessoa ao volante no `Carro` da cidade é um **buraco**: não há cabine no carro dirigível, só no `CarroCena`. A tecla V no carro troca duas distâncias de perseguição, não 1P/3P.

Para o passageiro online isso importa: o convidado no banco **precisa** de um ponto de câmera dentro da cabine, senão ele voa atrás do carro como terceira pessoa de perseguição e não “está” no banco.

## 2. Contrato de assentos

```
enum Assento { NENHUM, MOTORISTA, PASSAGEIRO }
```

Um `Carro` tem no máximo dois. Host guarda `{ MOTORISTA: peer_id|null, PASSAGEIRO: peer_id|null }`.

| Ação | Resultado |
|---|---|
| E perto, motorista vago | pede MOTORISTA |
| E perto, motorista ocupado, passageiro vago | pede PASSAGEIRO |
| E perto, os dois ocupados | recusa |
| F no motorista | desce no −X; se havia passageiro, passageiro **não** vira motorista sozinho (v1). Carro fica à deriva / freio de mão. v1.1: prompt “assumir volante” no passageiro |
| F no passageiro | desce no +X |

Não: os dois mandam volante. Input de veículo só do peer MOTORISTA → `pedido_input_veiculo` → host aplica.

## 3. Física

Host simula o `VehicleBody3D`. Synchronizer no casco: `global_transform`, `linear_velocity` (para interpolar), marcha/ligado se o painel do passageiro mostrar.

Cliente motorista: **não** move o RigidBody local. Manda input. Se o RTT doer, a Fase 8 pode predizer esterço visual; v1 não.

Freio de mão, buzina, ligar motor: eventos D, host.

Batida: sinal `bateu` já existe. Host emite; os dois sentem tranco na câmera se estão neste carro (`_ao_bater` no Player — hoje só o piloto). Estender ao passageiro.

## 4. Corpos visíveis

Regra que o single não teve que resolver:

| Quem | O que desenha |
|---|---|
| Piloto local, câmera perto / 1P | próprio corpo oculto; vê cabine (quando houver) e o **parceiro** no banco |
| Passageiro local | próprio corpo oculto em 1P; vê o piloto (mãos no volante) |
| Qualquer 3P / o outro jogador olhando de fora | os dois `Corpo` nos assentos, cabine on ou off conforme distância |

`visible = false` no Player inteiro, como hoje, **apaga o parceiro para o mundo**. Errado em 2P.

Fazer:

- Esconder só malhas da 1P (braços se existirem, ou nada — o jogo em 1P já não mostra o próprio tronco).
- Manter o `Corpo` filho visível para os outros (camadas / `cull` / `visible` no mesh da 1P vs 3P).
- NPC `_montar_motorista`: só quando **os dois assentos de player estão vazios**. Se um player assumiu, o NPC desce (já é o desenho de `assumir`).

## 5. Cabine no carro da cidade

Hoje a cabine é do `CarroCena`. O passageiro online na rua precisa ver o interior.

Duas vias:

**A.** Reusar `CarroCabine` no `Carro` quando alguém senta no passageiro ou quando a câmera entra. Custo de malha só com gente dentro.

**B.** Não ter cabine na rua; passageiro usa câmera de ombro interno (offset +X, +Y no casco) olhando para a estrada **através** da lataria (faces invertidas — o bug documentado em `camera_rig.gd`).

**A é obrigatória** para o pedido “dois personagens aparecendo no carro”. Sem interior, o passageiro não está no carro; está numa câmera parentada. Fazer A na Fase 4, mesmo que a 1P do piloto na rua continue sendo perseguição até a cabine estar boa.

A intro (Fase 5) já tem cabine. Não misturar os dois PRs, mas compartilhar `CarroCabine` e as poses.

## 6. Pontos de câmera

```
MOTORISTA_OLHO  = CarroCabine.pos_olho()          # já existe o espírito
PASSAGEIRO_OLHO = espelho em +X
```

`CameraRig.seguir_veiculo` ganha parâmetro de assento. Passageiro: distâncias menores, ombro invertido.

FOV `FOV_NO_CARRO` já existe no Player. Vale nos dois assentos.

## 7. Bicicleta

`Bicicleta`: um lugar. v1 **não** põe dois numa bike. O parceiro anda ou pega outro carro. Não gastar a Fase 4 aqui.

## 8. Painel e rádio

`PainelCarro` nasce no Player hoje. Em 2P: o painel é do **local se MOTORISTA**. Passageiro: pode ver um painel mais pobre ou o mesmo, sem input de marcha. v1: painel só no motorista; passageiro tem o prompt “[F] descer”.

Rádio: `08` §7.

## 9. Aceite da Fase 4

Dois processos, cidade, `--mp-pular-intro`:

1. Host entra no Marea da rua. Convidado vê o corpo do host **no banco**, não um casco vazio.
2. Convidado aperta E, senta no passageiro, câmera de dentro, vê o piloto.
3. Host dirige; o casco nos dois processos interpola sem teleporte.
4. Convidado F, desce no lado direito.
5. Host F, desce no esquerdo. Carro para.
6. Solo: entrar/sair do carro **igual** a hoje (P16).

# 07 — Mundo, streaming e espaços

> **Versão 2.0 — 21/09/2026.** Reescrito. A 1.0 tinha um `ChunkManager` para dois corpos e resolvia com *leash* de 80 m, ponto médio e raio de carga único da sessão. Na v2 cada cliente monta a cidade em volta de si (P5), e o servidor não monta nada até a Fase 8.
> A cidade é o milagre do projeto. A rede não a transporta, não a divide e não a desmonta.

## 1. Por que a cidade não viaja

A cidade inteira sai da coordenada:

| Peça | Semente | Onde |
|---|---|---|
| Chunk | `hash(Vector2i(cx, cz)) ^ (cx·73856093) ^ (cz·19349663)` | `chunk_builder.gd:40-44` |
| Portas do chunk | `77000 + cx·419 + cz·787` | `chunk_builder.gd:287-288` |
| Ruído da malha urbana | `hash(Vector2i(a, b)) ^ … ^ (sal·83492791)` | `malha_urbana.gd:477` |
| Relevo | função pura estática, cache com `Mutex` | `relevo.gd:92` |
| Interior | `(tipo, semente)` da porta | `interiores.gd:342`, `_planta` |
| Estrada Velha | `CarroCena.SEMENTE = 4410`, `EstradaBuilder` | `carro_cena.gd:29` |

**Auditoria de 21/09** (todos os `*_builder.gd`, `kit_*`, `malha_urbana`, `morros`, `relevo`, `vias`, `rotas`, `nomes_de_rua`, `tracado`, `ladeira`, `serpentina`, `lago`, `capas_atlas`): **zero** `randi()`, `randf()`, `randomize()`, `shuffle()` ou `pick_random()` sem semente. Todo `RandomNumberGenerator` é semeado pela coordenada, por uma semente, por uma constante ou pelo `randi()` de um pai semeado. Nenhum builder lê `Settings`, `WorldState`, `Clima` ou `Time`.

Duas máquinas com o mesmo código montam a mesma cidade, byte a byte. Por isso **nenhuma malha, textura ou colisão entra na rede** (`04` §10).

## 2. O que faz duas máquinas discordarem

| Fonte | Efeito | Guarda |
|---|---|---|
| Versão diferente do gerador | ruas em lugares diferentes; o amigo anda por dentro de prédio | P18: `VERSAO` na entrada. **Depende de alguém lembrar de subir** (`15` §3) |
| `--sem-relevo` numa das máquinas | uma cidade plana e outra com morro; o amigo flutua ou afunda 18 m | **nenhuma hoje** (`relevo.gd:73`) |
| Mod, arquivo trocado em `resources/` | o que mudar | nenhuma |

### 2.1 Assinatura do mundo (Fase 2)

Confiar numa constante que alguém precisa lembrar de subir é a trava mais fraca possível. O próprio gerador sabe se mudou. A Fase 2 acrescenta:

```gdscript
class_name AssinaturaDoMundo   # game/src/net/assinatura_do_mundo.gd, puro
static func calcular() -> int
```

que faz `sha256` do resumo de `ChunkBuilder.construir(cx, cz)` para 4 chunks fixos — `(8,−2)` a praça, `(−3,3)` o nascimento, `(0,0)` e `(4,9)`: número de props, tipo, posição ao decímetro e semente de cada prop, número de formas de colisão, triângulos.

**Implementado e medido em 21/09.** A primeira versão também amostrava `Relevo.altura` numa grade de 9 × 9 pontos de −2 km a +2 km, e isso custou **1,3–1,5 s** (o cache do relevo esquenta por região, e 81 pontos espalhados são 81 regiões frias). Não precisa: os props de cada chunk já trazem a altura do terreno (a lâmpada do chunk `(0,0)` está em y = −12,94), então o relevo entra pela assinatura dos chunks. Com `--sem-relevo`, essa lâmpada vai para y = 0 e a assinatura muda.

O servidor calcula uma vez ao subir. O cliente calcula antes de entrar. A assinatura vai no desafio e no pedido; diferente, a entrada é recusada com **"Cidade diferente. Atualize o jogo dos dois lados."** Na lista da rede local, o servidor aparece marcado "(outra cidade)", como já acontece com "(outra versão)".

A `VERSAO` continua existindo para o **formato de pacote**. A assinatura cuida do **mundo**. A regra 1 de `15` §3 deixa de depender de memória humana.

Custo medido: 81 ms com o gerador frio, 28 ms quente. No cliente e no anfitrião, em thread. No **dedicado, na subida e sem thread** (110–154 ms): em thread, a primeira compilação do gerador disputava o carregador com o laço do servidor e deu quadros de 100–121 ms com oito entradas juntas (`19` §3b, linha 16).

## 3. Streaming: cada um em volta de si

`ChunkManager.alvo` é **o jogador local** (`cidade.gd:46`). O raio de carga sai do preset de névoa **local**:

```
_raio_carga = ceil(preset.stream_radius / 32) + raio_extra        (chunk_manager.gd:210)
```

| Preset | `stream_radius` |
|---|---|
| `fog_denso`, `fog_bar` | 64 m |
| `fog_dia_chuva` | 128 m |
| `fog_dia_nuvens` | 160 m |
| `fog_dia_sol` | 192 m |

Dois jogadores em presets diferentes carregam raios diferentes, e **está certo**: o raio é o que cada máquina aguenta e o que cada névoa esconde. O que não pode divergir é **o que há** em cada chunk (§2), não quantos chunks cada um vê.

### 3.1 O amigo fora do meu chão

O interesse é de 160 m (P19); o meu raio de carga pode ser de 64 m. O servidor me manda o amigo a 120 m, e ali eu não tenho chunk: ele anda sobre nada, e a lanterna dele acende uma névoa sem chão.

Regra do boneco (Fase 2): **na rua, só desenha onde eu tenho chão.**

```gdscript
if espaco == ESPACO_RUA and not ChunkManager.esta_carregado(ChunkManager.coord_de(pos)):
	visible = false
```

`esta_carregado` já existe (`chunk_manager.gd:232`). O boneco reaparece quando o chunk dele monta, e a névoa já o escondia de qualquer jeito.

### 3.2 Quando o servidor precisar de chão

O servidor não tem chão na Fase 1, e não precisa: ele não simula corpo. Precisa a partir da Fase 8, para NPC, blitz e inimigo andarem, e para conferir alcance de verdade (`04` §6).

O desenho, já verificado contra o código:

- `ChunkBuilder.construir(cx, cz)` é **estático** e devolve dados com chaves separadas: `superficies` (malha), `props`, `colisao`, `triangulos` (`chunk_builder.gd:88-93`). O `ChunkManager._montar` já trata cada uma num laço à parte (`chunk_manager.gd:342-390`).
- Então o chão do servidor é um arquivo novo, `net/chao_do_servidor.gd`, que chama o **mesmo** `construir` e instancia **só** a `colisao` (`HeightMapShape3D` na ladeira, `BoxShape3D` no resto) e guarda os `props` como dados (posição e tipo, para conferir alcance e item).
- **Multi-alvo:** a união dos chunks a ≤ 2 anéis de cada jogador na rua. Oito jogadores juntos pedem os mesmos 25 chunks; oito espalhados, até 200.
- **Interiores no servidor:** no cliente todo interior mora no **mesmo** lugar (`interiores.gd:16`, y + 2000), porque só existe um por vez. No servidor podem existir vários ao mesmo tempo, e as colisões se misturariam. Cada interior ocupado ganha um `World3D` próprio (um `SubViewport` com `own_world_3d = true`), que tem espaço de física isolado.
- O custo de `construir` inclui montar malha que o servidor joga fora. Se medir caro, pedir à frente da cidade um `construir(cx, cz, so_colisao := true)`. **Combinar antes**; não é esta fase que decide.

## 4. Espaços

`Sessao.espaco_do_corpo` separa quem se vê de quem não se vê:

| Espaço | Faixa | Identidade | Quem monta |
|---|---|---|---|
| Rua | y < 1000 | `0` | cada cliente, em volta de si |
| Interior teletransportado | 1000 ≤ y < 3000 (mora em y + 2000) | `16 + hash([tipo, semente])` | cada cliente, **só o que ele está** |
| Estrada Velha | y ≥ 3000 (mora em y + 4000, `abertura_estrada.gd:130`) | `1` | cada cliente, na intro |
| `InteriorNoMundo` (casa construída na rua) | rua | `0` | cada cliente, a ≤ 32 m (`interior_no_mundo.gd:40`) |

**Dois no mesmo interior se veem; em interiores diferentes, não.** Não há regra de "entrar junto": cada um entra e sai quando quer, e quem ficou na rua não vê quem entrou. A v1 exigia os dois juntos na porta porque o servidor-jogador só conseguia montar **um** interior. Na v2, cada cliente monta o seu.

Interiores aninhados (a estufa atrás da casa) usam a `_pilha` do `Interiores` (`interiores.gd:90`), que é por processo. O espaço é o do cômodo **atual**, então dois amigos na mesma estufa se veem, venham de onde vierem.

**O que diverge dentro do mesmo interior:** a rotina dos convidados da casa da fumaça é local (`convidado.gd`). Dois amigos na sala veem os mesmos convidados, com a mesma cara e roupa (a ficha é determinística), mas não necessariamente no mesmo sofá. Aceito como *flavor*, com uma exceção: conversa. O convidado **ocupado** por um jogador é estado do servidor (`04` §5.4), e o outro vê "Está falando com FULANO".

## 5. Multidão, trânsito e o que é de cada um

`Multidao`, `Transito`, `BlitzManager` e `EntregasDaSuper` usam `_rng.randomize()` (`multidao.gd:80`, `transito.gd:57`, `blitz_manager.gd:30`, `entregas_da_super.gd:61`). Cada máquina tem a sua multidão e o seu trânsito.

É decisão, não dívida:

- replicar 14 pedestres e 8 carros a 20 Hz para cada jogador custaria mais que todos os jogadores juntos;
- num jogo de névoa, "você viu aquele cara parado no poste? eu não vi" é um sintoma de horror, não um defeito.

| Exceção | Por quê | Quem manda | Fase |
|---|---|---|---|
| Pedestre em conversa com um jogador | o outro precisa ver que ele está ocupado | servidor | 3 |
| Carro que um jogador assumiu | vira carro **de jogador**: sai do `Transito` local (`transito.gd:97`) e passa a ir no estado do motorista | motorista | ✅ 1 |
| Blitz | parar dois amigos na mesma blitz é o que ela significa | servidor | 8 |
| Inimigo | quem ele persegue tem de ser o mesmo para todos | servidor | 8 |

`ChunkBuilder.INIMIGO_NA_RUA = false` hoje (`chunk_builder.gd:2215`, pedido do usuário). O inimigo volta, em rede, só com contexto e decidido no servidor (memória do projeto: *ameaça sem contexto lê como bug*).

## 6. Colisão entre jogadores

O boneco não tem colisão hoje: eu atravesso o amigo, e o meu carro atravessa o carro dele.

| Caso | Decisão | Por quê | Fase |
|---|---|---|---|
| A pé × a pé | **empurrão suave**, sem bloqueio: o jogador local é afastado do boneco com uma força de separação quando a distância é menor que 0,5 m | bloqueio duro com 120 ms de atraso vira briga de porta; um amigo parado no corredor estreito da casa não pode prender o outro | 2 |
| Carro local × boneco a pé | o boneco tem uma cápsula `AnimatableBody3D` na camada de veículos | o carro não atravessa gente; o `Carro` já trata atropelo (`carro.gd:2013`) | 4 |
| Carro local × carro do amigo | a réplica do carro tem uma caixa `AnimatableBody3D` com as medidas da carroceria | o meu carro bate no dele de verdade | 4 |
| O carro dele sente a batida | evento `_batida(alvo, impulso)` para o motorista dele, que aplica o impulso | a física do carro dele é dele (P6) | 4 |
| Trânsito local × carro do amigo | a mesma caixa: a IA do trânsito já desvia de corpo físico no caminho | — | 4 |

## 7. Chuva, céu, névoa, clima

Locais. O preset de névoa é opção gráfica de cada um, e o `Clima` segue o preset (`16` §1). Um jogador pode ver chuva e o outro não.

O que é de todos é a **hora**: o relógio é do servidor (✅ Fase 1), então "é madrugada" é verdade para todo mundo.

## 8. Mapa e visitados

`WorldState.visitar(coord)` é chamado pelo `ChunkManager` de cada um (`chunk_manager.gd:247`). Em rede:

- **Cliente:** continua marcando os próprios visitados, e **manda** os novos ao servidor em lote (a cada 10 s, só os novos, `PackedInt32Array` de pares).
- **Servidor:** guarda a **união**, por grupo. Viagem junto é mapa junto: o que um andou, o mapa de papel do grupo mostra.
- **Entrada:** o cliente recebe a união do grupo na carga (`04` §5.1).

## 9. Aceite

| Prova | Como |
|---|---|
| Mesma cidade | ✅ nível 2 com chunks sintéticos (o `ChunkBuilder` não compila no `--script`, por isso a classe recebe o construtor como `Callable`): mesma cidade, mesma assinatura; relevo, prop a 20 cm e colisão a mais mudam; ruído abaixo do decímetro não. Três dedicados em sequência deram a mesma assinatura (`8efc3d95cbad2fd1`) |
| Cidade diferente recusada | ✅ nível 4: bot com `--sem-relevo` recusado com "Cidade diferente."; servidor sem ERROR |
| Interior | dois bots no mesmo `(tipo, semente)` se veem; em interiores diferentes, não; um na rua não vê nenhum dos dois |
| Chão do outro | boneco a 120 m com o preset `fog_denso`: invisível; a 40 m: visível e no chão |
| Empurrão | ⏳ dois jogadores andando um contra o outro num corredor de 1 m: nenhum fica preso mais de 0,5 s (código em `Sessao._afastar_dos_outros`, sem medida ainda) |
| Colisão da réplica | ⏳ Fase 4. **Visto em 21/09:** na avenida, um carro do trânsito local parou colado na réplica do carro do amigo |

## A impressao digital da cidade: duas maquinas com a mesma assinatura montam a
## mesma rua no mesmo lugar.
##
## Por que existe
## --------------
## A cidade nao viaja na rede. Cada maquina a gera da coordenada (plano 07 secao
## 1), e isso so funciona se as duas rodarem o MESMO gerador. Ate a versao 1 do
## protocolo a unica trava era `ProtocoloRede.VERSAO`, que alguem precisava
## lembrar de subir toda vez que mexesse em `chunk_builder`, `relevo`, `vias` ou
## em qualquer builder — e sao justamente os arquivos que outra frente edita todo
## dia. Um esquecimento e o amigo anda por dentro de um predio sem erro nenhum na
## tela. E ha um caso que nenhuma versao pega: uma maquina com `--sem-relevo`
## monta a cidade plana, e a outra com morro (relevo.gd, `ativo`).
##
## A assinatura pergunta ao proprio gerador. Quatro chunks conhecidos sao
## construidos com o mesmo `ChunkBuilder.construir` do jogo, e o que sai deles
## (cada prop, seu tipo, sua posicao ao decimetro, a semente, quantas formas de
## colisao, quantos triangulos) vira um sha256. Os props carregam a altura do
## terreno, entao o relevo entra junto sem amostra a parte.
##
## Custo medido em 21/09/2026: 81 ms com o gerador frio, 28 ms quente. Roda em
## thread (`Sessao`), uma vez, na hora de abrir ou de entrar.
##
## Por que o construtor chega como Callable
## ----------------------------------------
## `ChunkBuilder` depende de scripts que citam autoloads, e no modo `--script` do
## teste de nivel 2 esses nao compilam. Recebendo o construtor de fora, esta
## classe fica pura e o teste alimenta chunks sinteticos.
class_name AssinaturaDoMundo
extends RefCounted

## Os chunks que entram na conta. A praca (onde todo mundo acorda), o nascimento
## da cidade.tscn, a origem e um canto de ladeira. Mudar a lista muda a
## assinatura de todo mundo, entao ela so muda junto com a VERSAO.
const CHUNKS: Array[Vector2i] = [
	Vector2i(8, -2), Vector2i(-3, 3), Vector2i(0, 0), Vector2i(4, 9),
]
## Caracteres hex guardados. 16 = 64 bits: colisao por acaso entre duas cidades
## diferentes nao acontece.
const TAMANHO := 16


## A assinatura, com `construir(cx, cz) -> Dictionary` do jogo.
static func calcular(construir: Callable) -> String:
	var b := StreamPeerBuffer.new()
	for c: Vector2i in CHUNKS:
		var dados: Variant = construir.call(c.x, c.y)
		resumir_chunk(b, c, dados if typeof(dados) == TYPE_DICTIONARY else {})
	return de_bytes(b.data_array)


## Escreve em `b` o que importa de um chunk para dizer se duas maquinas o montaram
## igual. Decimetro, e nao a posicao crua: o que se compara e a cidade, e nao o
## ultimo bit do float.
static func resumir_chunk(b: StreamPeerBuffer, coord: Vector2i, dados: Dictionary) -> void:
	b.put_32(coord.x)
	b.put_32(coord.y)
	var props: Array = dados.get("props", [])
	b.put_u32(props.size())
	for p: Variant in props:
		if typeof(p) != TYPE_DICTIONARY:
			b.put_u8(0)
			continue
		var prop: Dictionary = p
		b.put_u8(1)
		var tipo := String(prop.get("tipo", "")).to_utf8_buffer()
		b.put_u16(tipo.size())
		b.put_data(tipo)
		var pos: Variant = prop.get("pos", Vector3.ZERO)
		var v: Vector3 = pos if typeof(pos) == TYPE_VECTOR3 else Vector3.ZERO
		b.put_32(roundi(v.x * 10.0))
		b.put_32(roundi(v.y * 10.0))
		b.put_32(roundi(v.z * 10.0))
		b.put_64(int(prop.get("semente", 0)))
	var colisao: Array = dados.get("colisao", [])
	b.put_u32(colisao.size())
	b.put_u32(int(dados.get("triangulos", 0)))


static func de_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, TAMANHO)

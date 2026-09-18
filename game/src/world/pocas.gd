## Pocas de chuva. Decals ancorados no mundo, materializados perto do jogador.
##
## Por que decal e nao geometria
## -----------------------------
## Uma poca e uma mancha molhada no asfalto, nao um objeto. Como geometria ela
## exigiria assentar um quad rente ao chao e brigar com z-fighting em todo
## desnivel; como decal ela se projeta sobre o que estiver la, inclusive sobre o
## meio-fio e o remendo, e escreve rugosidade — que e o que faz o reflexo de tela
## aparecer ali e so ali.
##
## Decal e recurso de Forward+. No perfil de Compatibility ele e aceito sem aviso
## e nao desenha NADA — medido em 0,00% de diferenca de pixel. Por isso este no
## se desliga sozinho quando o estilo nao tem luz por pixel, em vez de tentar e
## ficar invisivel sem explicacao.
##
## Onde a poca nasce
## -----------------
## Nao e sorteio por quadro, e nao e lista guardada: a posicao sai de um HASH da
## celula da grade. A mesma celula devolve sempre a mesma poca, entao ela nao
## desliza quando o jogador anda nem troca de lugar ao recarregar o chunk. O pool
## de decals so e REAPONTADO para as celulas mais proximas.
class_name Pocas
extends Node3D

## Lado da celula da grade, em metros. Uma poca por celula, no maximo.
const CELULA := 6.0
## Raio de materializacao. Alem disto a poca nao sobrevive a nevoa mesmo leve.
const RAIO := 26.0
## Decals no pool. Vinte cobre o raio com folga; alem disso e desenho que a
## nevoa engole.
const MAX := 20
## Fracao das celulas que tem poca. Alto demais vira alagamento, baixo demais
## some — 0,42 deixa a rua pontilhada sem virar piscina.
const CHANCE := 0.42
## Raio da poca, em metros.
const RAIO_MIN := 0.85
const RAIO_MAX := 2.1
## Abaixo deste molhado nao ha poca nenhuma. A agua empoca DEPOIS de a
## superficie encharcar — nao junto.
const LIMIAR := 0.35
## Passo da reavaliacao, em segundos.
const PASSO := 0.4
## Altura da caixa do decal. Precisa cobrir o desnivel entre asfalto e sarjeta
## sem alcancar o teto de nada.
const ALTURA := 1.1

## Lado das texturas geradas, em pixels.
##
## Era 128, escrito com `set_pixel` — 32.768 chamadas de GDScript por textura,
## duas texturas, tudo no `_ready`. O custo disso e um ENGASGO na carga da cena,
## e ele foi pego por acidente: a captura de aceite, que era identica entre
## execucoes ha meia duzia de fases, passou a variar 49% porque a camera do
## jogador assentava num numero diferente de quadros a cada boot.
##
## 64 px com escrita direta em PackedByteArray sao 4.096 iteracoes por textura em
## vez de 32.768 chamadas. A mancha e um degrade suave: nao ha detalhe em 128 que
## se perca em 64, e o decal e projetado sobre metros de asfalto de qualquer jeito.
const N_TEX := 64

## Cinza da lamina, de 0 a 255.
##
## ESCURO, e isso e o contrato, nao um gosto. Agua escurece o que esta embaixo
## dela; o brilho vem do REFLEXO, que e outro canal. Ja errei isto duas vezes na
## mesma fase — primeiro pintando a cor do ceu aqui, depois so clareando — e as
## duas viraram poca de tinta clara num dia de sol. Se este numero subir acima do
## cinza medio, a poca voltou a ser pigmento.
const CINZA_LAMINA := 56

var _pool: Array[Decal] = []
static var _cache_albedo: ImageTexture
static var _cache_orm: ImageTexture
var _tex_albedo: Texture2D
var _tex_orm: Texture2D
var _relogio: float = 0.0
var _alvo: Node3D


func _ready() -> void:
	_tex_albedo = textura_albedo()
	_tex_orm = textura_orm()
	for i in MAX:
		var d := Decal.new()
		d.texture_albedo = _tex_albedo
		d.texture_orm = _tex_orm
		# Nao 1.0: a poca ESCURECE e alisa o asfalto, nao apaga ele. Com mistura
		# cheia a textura da rua sumia por baixo e a poca virava um adesivo.
		# 0,52: a poca deixa o asfalto APARECER por baixo. Em 0,78 ela cobria a
		# textura da rua e, num ceu claro, lia como mancha de tinta clara em vez
		# de agua. Agua e transparente — o que se ve nela e o fundo mais o
		# reflexo, nunca uma cor propria opaca.
		d.albedo_mix = 0.62
		# A borda some por cima e por baixo em vez de cortar reto no limite da
		# caixa, que e o que denuncia decal como decal quando o chao inclina.
		d.upper_fade = 0.6
		d.lower_fade = 0.4
		d.distance_fade_enabled = true
		d.distance_fade_begin = RAIO * 0.7
		d.distance_fade_length = RAIO * 0.4
		d.visible = false
		add_child(d)
		_pool.append(d)


## A mancha e a rugosidade da poca, geradas uma vez por execucao.
##
## Publicas e estaticas porque ha DOIS lugares que empocam agua e eles nao se
## conhecem: a cidade, em grade de asfalto, e a Estrada Velha, que e uma
## esteira de terra montada quatro mil metros acima e nao passa pelo
## ChunkManager. A geometria de onde a poca nasce e diferente nos dois; a
## APARENCIA da lamina de agua tem de ser a mesma, senao chove de dois jeitos
## no mesmo jogo. Duas senoides e um degrau num PackedByteArray de 64 px nao
## valem um segundo arquivo.
static func textura_albedo() -> ImageTexture:
	if _cache_albedo == null:
		_cache_albedo = _gerar_albedo()
	return _cache_albedo


static func textura_orm() -> ImageTexture:
	if _cache_orm == null:
		_cache_orm = _gerar_orm()
	return _cache_orm

func _process(delta: float) -> void:
	_relogio += delta
	if _relogio < PASSO:
		return
	_relogio = 0.0
	_reavaliar()


func _reavaliar() -> void:
	# Decal nao desenha fora do Forward+, e no PS1 STYLE a superficie nem tem
	# specular para a poca conversar. Nos dois casos, sumir e mais honesto do que
	# desenhar algo que ninguem ve.
	var forca := Clima.molhado_visivel() if Settings.luz_por_pixel else 0.0
	if forca < LIMIAR:
		_esconder_tudo()
		return

	var seguido := _seguido()
	if seguido == null:
		_esconder_tudo()
		return
	var centro := seguido.global_position

	# A poca cresce com o molhado, mas nao do zero: ela aparece com dois tercos
	# do tamanho e engorda dali. Poca nascendo como um ponto e crescendo parece
	# mancha de tinta espalhando, nao agua juntando numa depressao.
	var escala := 0.66 + 0.34 * inverse_lerp(LIMIAR, 1.0, forca)

	var achadas: Array[Vector3] = []
	var c0 := Vector2i(floori((centro.x - RAIO) / CELULA), floori((centro.z - RAIO) / CELULA))
	var c1 := Vector2i(ceili((centro.x + RAIO) / CELULA), ceili((centro.z + RAIO) / CELULA))
	for gx in range(c0.x, c1.x + 1):
		for gz in range(c0.y, c1.y + 1):
			var p := _poca_da_celula(gx, gz)
			if p.w <= 0.0:
				continue
			var pos := Vector3(p.x, p.y, p.z)
			if pos.distance_to(centro) > RAIO:
				continue
			achadas.append(Vector3(p.x, p.z, p.w))  # x, z, raio

	# Mais celulas do que decals: fica com as mais proximas. Sem a ordenacao, o
	# pool se enche do canto do quadrado de busca e deixa buraco na frente da
	# camera, que e justo onde a poca precisa estar.
	achadas.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x, a.y).distance_squared_to(Vector2(centro.x, centro.z)) \
			< Vector2(b.x, b.y).distance_squared_to(Vector2(centro.x, centro.z)))

	for i in MAX:
		var d := _pool[i]
		if i >= achadas.size():
			d.visible = false
			continue
		var a := achadas[i]
		var lado := a.z * 2.0 * escala
		d.global_position = Vector3(a.x, 0.02, a.y)
		d.size = Vector3(lado, ALTURA, lado)
		# A poca reflete o CEU, e por isso a cor vem de la em vez de ser fixa.
		# Com um cinza escuro constante ela lia como buraco no asfalto ao meio-dia
		# nublado — uma poca de dia e mais CLARA que a rua, nao mais escura, porque
		# o que ela devolve e o ceu. A noite o mesmo calculo a deixa quase preta,
		# com as listras do poste por cima.
		# Escura, e sem a cor do ceu.
		#
		# A cor do ceu morou aqui por duas voltas e estava errada: pintar o ceu no
		# albedo faz a poca ser TINTA CLARA, e num dia de sol ela ficava mais
		# clara que o asfalto por pigmento, nao por reflexo. Quem devolve o ceu
		# agora e o reflexo de verdade — o FogController alimenta um Sky de
		# radiancia com a cor do preset. Aqui sobra o que a agua realmente faz ao
		# que esta embaixo dela: escurece.
		d.modulate = Color(1.0, 1.0, 1.0, clampf(forca * 1.15, 0.0, 1.0))
		d.visible = true


func _esconder_tudo() -> void:
	for d: Decal in _pool:
		d.visible = false


func _seguido() -> Node3D:
	if _alvo != null and is_instance_valid(_alvo):
		return _alvo
	_alvo = get_viewport().get_camera_3d()
	return _alvo


## A poca desta celula: (x, y, z, raio). Raio 0 significa "nao ha poca aqui".
##
## Tudo sai do hash da celula, entao a resposta e a mesma em toda execucao e em
## toda maquina: a poca da esquina fica na esquina.
static func _poca_da_celula(gx: int, gz: int) -> Vector4:
	var h := _hash(gx, gz)
	if _frac(h) > CHANCE:
		return Vector4.ZERO
	var ox := _frac(h * 7.13) - 0.5
	var oz := _frac(h * 3.71) - 0.5
	var x := (float(gx) + 0.5 + ox * 0.7) * CELULA
	var z := (float(gz) + 0.5 + oz * 0.7) * CELULA
	if not _e_asfalto(x, z):
		return Vector4.ZERO
	var r := lerpf(RAIO_MIN, RAIO_MAX, _frac(h * 11.37))
	return Vector4(x, 0.0, z, r)


## A posicao de mundo cai sobre asfalto?
##
## Perguntado a MalhaUrbana, e nao por raycast. A malha e a fonte da verdade
## sobre onde passa rua — e um raycast responderia "bati em alguma coisa" sem
## saber se era asfalto, grama ou o teto de um carro parado.
static func _e_asfalto(x: float, z: float) -> bool:
	var cx := floori(x / MalhaUrbana.TAM)
	var cz := floori(z / MalhaUrbana.TAM)
	var lx := x - float(cx) * MalhaUrbana.TAM
	var lz := z - float(cz) * MalhaUrbana.TAM
	var b := MalhaUrbana.bordas(cx, cz)

	# Mesma conta do ChunkBuilder._solo: a faixa de asfalto encosta na borda do
	# chunk e vai ate meia_asfalto da via daquele lado.
	if lx <= MalhaUrbana.meia_asfalto(b["x0"]):
		return true
	if lx >= MalhaUrbana.TAM - MalhaUrbana.meia_asfalto(b["x1"]):
		return true
	if lz <= MalhaUrbana.meia_asfalto(b["z0"]):
		return true
	if lz >= MalhaUrbana.TAM - MalhaUrbana.meia_asfalto(b["z1"]):
		return true
	return false


static func _hash(a: int, b: int) -> float:
	var n := a * 374761393 + b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float(absi(n ^ (n >> 16)) % 1000003) / 1000003.0


static func _frac(v: float) -> float:
	return v - floorf(v)


## Mancha irregular com alfa caindo para a borda.
##
## Gerada em codigo em vez de virar PNG no repositorio por um motivo pratico: a
## textura e uma funcao de tres senoides e um degrau, e um arquivo de 128 px
## indexado no pipeline de assets existiria so para guardar isso — mais um item
## para o gerador de materiais apagar quando alguem esquecer de listar.
static func _gerar_albedo() -> ImageTexture:
	var buf := PackedByteArray()
	buf.resize(N_TEX * N_TEX * 4)
	var i := 0
	for y in N_TEX:
		var v := (float(y) / float(N_TEX - 1) - 0.5) * 2.0
		for x in N_TEX:
			var u := (float(x) / float(N_TEX - 1) - 0.5) * 2.0
			var ang := atan2(v, u)
			# Tres lobos em razao irracional: a borda fica irregular sem repetir
			# um padrao que o olho reconheca como carimbo.
			var borda := 0.76 + 0.13 * sin(ang * 3.0) + 0.07 * sin(ang * 5.7 + 1.3) 				+ 0.04 * sin(ang * 9.1 + 2.7)
			var r := sqrt(u * u + v * v)
			# Borda CURTA. Com o degrau comecando em 0,72 do raio, a poca tinha
			# 28% de si em gradiente e lia como nevoa no chao em vez de agua —
			# apareceu na primeira ampliacao. Agua parada tem borda definida.
			var a := 1.0 - smoothstep(borda * 0.93, borda, r)
			# Branco: a cor de verdade entra pelo `modulate`, que vem do ceu. Uma
			# textura ja colorida multiplicaria duas vezes e prenderia a poca a um
			# unico clima.
			# Cinza escuro: a lamina escurece o asfalto. O brilho vem do reflexo.
			buf[i] = CINZA_LAMINA - 2
			buf[i + 1] = CINZA_LAMINA
			buf[i + 2] = CINZA_LAMINA + 2
			buf[i + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
			i += 4
	return ImageTexture.create_from_image(
		Image.create_from_data(N_TEX, N_TEX, false, Image.FORMAT_RGBA8, buf))


## Rugosidade da poca. G = rugosidade; R e B nao importam aqui.
##
## O centro vai a 0,04 — quase espelho, que e o que faz o reflexo de tela pegar
## dentro da poca e so dentro dela. A borda volta para 1,0 para a transicao com
## o asfalto seco nao ser um degrau.
static func _gerar_orm() -> ImageTexture:
	var buf := PackedByteArray()
	buf.resize(N_TEX * N_TEX * 4)
	var i := 0
	for y in N_TEX:
		var v := (float(y) / float(N_TEX - 1) - 0.5) * 2.0
		for x in N_TEX:
			var u := (float(x) / float(N_TEX - 1) - 0.5) * 2.0
			var r := sqrt(u * u + v * v)
			# 0,22 e nao 0,10. Com 0,10 a poca era espelho liso virado para cima,
			# e sob o sol de `dia_sol` (energia 2,2) o realce especular passava de
			# 1,0 na poca INTEIRA — o glow mordia o estouro e ela virava uma
			# piscina acesa. Uma lamina de agua de rua tem ondulacao; espalhar o
			# realce e o que devolve o reflexo sem o clarao.
			var rug := lerpf(0.22, 1.0, smoothstep(0.45, 0.95, r))
			buf[i] = 255                              # R: oclusao, cheia
			buf[i + 1] = int(clampf(rug, 0.0, 1.0) * 255.0)  # G: rugosidade
			buf[i + 2] = 0                            # B: metalico, nenhum
			buf[i + 3] = 255
			i += 4
	return ImageTexture.create_from_image(
		Image.create_from_data(N_TEX, N_TEX, false, Image.FORMAT_RGBA8, buf))

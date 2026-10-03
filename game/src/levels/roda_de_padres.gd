## A roda: os padres de corpo inteiro que cercam o carro depois da batida,
## girando devagar e fechando o circulo toda vez que a lente olha para outro
## lado.
##
## Por que existe
## --------------
## Depois da batida os romeiros sumiam (o plano das figuras os esconde) e o carro
## ficava cercado so pela multidao de longe, que pisca. O pedido: mais padres
## perto do carro, rodeando, sem custar quadro.
##
## Onde entra
## ----------
## A `AberturaEstrada` carrega este arquivo pelo caminho (como o `CercoNoCarro`)
## e so avisa os momentos: `montar` (debaixo do preto do comeco), `aquecer`,
## `batida` e `desligar`.
##
## Como funciona
## -------------
## Quem roda sao os seis romeiros sem outro papel depois do plano das figuras
## (`ROMEIROS`; os outros sao da meia-lua, do carona e do cerco) e os `NOVOS`.
## Os novos sao montados pela propria cena (`_encapuzado`, a mesma veste de
## todos) em `montar`. Cada um tem uma vaga num anel em volta do carro, as
## vagas igualmente espacadas, e o anel gira devagar (`GIRO`). Depois da batida
## cada um entra na sua vaga, escalonados nos primeiros segundos (`ENTRA_ATE`),
## fundo na mata e na nevoa, num quadro em que nem a lente nem o retrovisor a
## veem (um por quadro), e dali:
##
## - a vaga fecha em passo constante (`VEM`, sorteado por corpo) ate o raio final
##   do setor em que ela esta, e chega nele uns 2 s antes do branco (`FECHA`): a
##   lente o ve vindo em todo plano, e ninguem chega cedo para ficar parado.
##   Na frente do capo fica longe: o do capo e o fogo tem de se ler. Do
##   lado do motorista, atras da meia-lua: longe enquanto ela nao chega, e depois
##   um passo atras dela. Do lado do carona e atras chega rente, fora do caminho
##   de quem sobe na tampa;
## - anda para a vaga pelo `AndarMacabro`: quase parado com a lente (ou o
##   retrovisor) em cima, depressa fora dela. Quem foi olhado fica para tras da
##   vaga e alcanca quando a lente sai. A cada corte a lente volta e eles estao
##   mais perto. Seguindo vagas, e nao cada um o seu giro, a roda nao se
##   amontoa onde a lente olha.
##
## Ninguem atravessa ninguem. Empurram para fora o carro (uma caixa), a arvore da
## batida (um circulo), os outros da roda e todo encapuzado de pe em volta: a
## meia-lua, o do carona, os do cerco, o padre e os vigias.
##
## Custo
## -----
## A treva de volume de cada corpo sai (a da cena ja cobre o mato, e doze volumes
## a mais pesam na nevoa) e a aura fica rala. O `Corpo` deles nao escreve a pose
## que o `AndarMacabro` sobrescreve (`dominado`), e fora da lente a pose e escrita
## um quadro em cada tres (`FORA_DA_LENTE`). Medido em 26/09 a 4K na RX 9070 XT:
## o quadro da roda custa 0,46 ms de CPU (pior 1,5), o pano dos doze uns 0,5 ms
## (`tests/bancada_andar.tscn --custo=12`), e a GPU dela inteira fica abaixo de
## 0,5 ms (`--roda-sonda`). Quem esta fora do quadro nao custa placa: esconde-los
## nao poupou nada.
##
## `--sem-roda` desliga tudo: e o lado A das medidas. `--roda-log` imprime a roda
## a cada meio segundo (o espaco do carro, as folgas e a CPU do quadro dela),
## `--roda-raio` o raio de cada um a cada segundo e cada entrada (com a
## conferencia de que nasceu fora do quadro), no relogio da cena, e
## `--roda-sonda=S` para o tempo S segundos depois da batida e mede a GPU dela
## com e sem, intercalado.
class_name RodaDePadres
extends Node

## Os romeiros livres depois do plano das figuras (indices em `_romeiros`).
const ROMEIROS := [5, 6, 8, 10, 11, 12]
## Os que a roda monta: [altura, tipo] (tipo como em `AberturaEstrada.FIGURAS`:
## 0 de pe, 1 curvado, 3 velho torto).
const NOVOS := [[1.86, 0], [1.78, 1], [1.92, 3], [1.80, 0], [1.84, 1], [1.76, 3]]
## A semente dos novos em `_encapuzado`: longe dos romeiros (1 a 14), dos
## vigias (40 a 42) e do padre (0).
const SEMENTE := 60
## De que raio (m, espaco do carro) eles entram, no minimo e no maximo. Dentro
## disso, o raio e o que falta andar ate o raio final do setor a `VEM` m/s ate
## `FECHA`: fundo na mata e na nevoa, 12 a 16 m. Com 8,8 a 11,5 m o caminho era
## curto e eles chegavam na metade da cena (`--roda-raio`, 26/09).
const ENTRA_RAIO := Vector2(8.0, 16.5)
## A rapidez (m/s) com que a vaga de cada um fecha, sorteada por corpo: andar
## lento e decidido, na lente e fora dela.
const VEM := Vector2(0.25, 0.31)
## A entrada escalonada: o k-esimo da ordem so entra `ENTRA_ATE * k / (n - 1)`
## segundos depois da batida (e so fora da lente e do retrovisor).
const ENTRA_ATE := 6.0
## O raio final por setor. O angulo e o do carro: 0 no nariz, positivo para o
## lado do carona (+X), pi na tampa de tras.
## Do lado do carona, sorteado por corpo.
const RAIO_CARONA := Vector2(3.3, 4.2)
## Na frente: o capo, o fogo e o que sobe tem de se ler.
const RAIO_FRENTE := 6.2
const FRENTE := 0.87
## Atras: o que sobe pela tampa esta a 2,6 m do meio.
const RAIO_TRAS := 4.6
const TRAS := 2.62
## Do lado do motorista, atras da meia-lua: antes de ela chegar, fora de onde
## ela nasce (ate 6,05 m do meio); depois, a este tanto atras do mais longe dela,
## e nunca mais perto que o minimo.
const RAIO_MOTORISTA := 7.6
const RAIO_MOTORISTA_MIN := 4.6
const ATRAS_DA_MEIA_LUA := 2.3
const MOTORISTA := Vector2(-2.62, -0.78)
## Quantos romeiros sao da meia-lua (os primeiros de `_romeiros`).
const MEIA_LUA := 5
## A largura (rad) da passagem de um setor para o outro.
const BORDA := 0.28
## Em quantos segundos depois da batida o circulo fecha de todo, e a curva. O
## branco cai 38,7 s depois da batida: fechando em 37 s, em passo constante, cada
## um vem da entrada ate o raio do setor e chega uns 2 s antes do branco. Com
## 26 s e curva 1,5 eles chegavam cedo e ficavam parados justo nos planos que
## mais os mostram (a lente tem de ve-los vindo aos poucos em toda cena).
const FECHA := 37.0
const FECHA_CURVA := 1.0
## O giro do anel das vagas (rad/s: do carona para o nariz, dali para o lado
## do motorista), a rapidez com que cada um vai atras da vaga (m/s; fora da
## lente o `AndarMacabro` multiplica) e o quanto ele acelera por metro que falta.
## O giro e lento: a 15 m, 0,026 rad/s eram 0,39 m/s de lado, mais que o passo
## para o carro, e o que a lente lia era a roda girando, e nao vindo.
const GIRO := 0.008
const CHEGA := 0.5
const PUXA := 0.7
## Folgas: entre dois corpos (m, de centro a centro), a caixa do carro (meia
## largura, meio comprimento) com a folga dela, e a arvore da batida (no espaco
## do carro: a frente direita abracou o tronco) com o raio que ninguem pisa.
const FOLGA := 1.3
const CARRO := Vector2(0.95, 2.3)
const CARRO_FOLGA := 0.65
const ARVORE := Vector2(0.55, -2.6)
const ARVORE_RAIO := 1.8
## O quanto ele pode entrar alem do raio do setor (m), no maximo.
const PISO := 0.5
## Quanto os vizinhos empurram (m/s) quando estao dentro de 1,5 folga.
const AFASTA := 0.6
## Fora da lente e do retrovisor a pose e escrita um quadro em cada tantos.
const FORA_DA_LENTE := 3
## A aura dos da roda: rala. A 4K, na janela, a fumaca transparente dos que
## estao no quadro era o que mais custava deles (0,8 ms com 0,45).
const AURA := 0.25
## O quanto o corpo vira por segundo (rad/s) e o quanto ele olha para o carro
## em vez de para onde anda.
const VIRA := 1.6
const OLHA_O_CARRO := 1.2

var _ab: Node
var _carro: CarroCena
var _raiz: Node3D
var _cam: Camera3D
var _espelho: Node
var _corpos: Array[Corpo] = []
var _novos: Array[Corpo] = []
var _andares: Array[AndarMacabro] = []
## Por corpo: ja entrou na roda, o raio de onde veio, o raio final (carona).
var _dentro: Array[bool] = []
var _r_ini: PackedFloat32Array = []
var _r_fim: PackedFloat32Array = []
var _lugar: PackedFloat32Array = []
## Por corpo: a rapidez com que a vaga fecha (`VEM`), quando pode entrar e
## quando entrou (s depois da batida).
var _vem: PackedFloat32Array = []
var _t_pode: PackedFloat32Array = []
var _t_entrou: PackedFloat32Array = []
## `--roda-raio`: o raio de cada um a cada segundo e cada entrada, com o relogio
## da cena.
var _log_raio: bool = OS.get_cmdline_user_args().has("--roda-raio")
var _t_raio: float = 0.0
## O tempo desde a ultima pose escrita, por corpo (ver `FORA_DA_LENTE`).
var _acumulado: PackedFloat32Array = []
## Tempo desde a batida; negativo antes dela.
var _t: float = -1.0
var _desligado: bool = false
## O raio do lado do motorista agora (ver `RAIO_MOTORISTA`), e se a meia-lua ja
## chegou.
var _r_motorista: float = RAIO_MOTORISTA
var _meia_lua_veio: bool = false
var _log: bool = OS.get_cmdline_user_args().has("--roda-log")
## `--roda-sonda=S`: S segundos depois da batida o tempo para e a roda mede o
## que custa de GPU (ver `_sondar`). -1 desligado.
var _sonda_em: float = -1.0
var _sondando: bool = false
## `--roda-log`: o tempo de CPU do quadro da roda (media e pior do meio segundo).
var _ms_soma: float = 0.0
var _ms_n: int = 0
var _ms_pior: float = 0.0
## `--roda-log`: quanto disso foi achar a multidao perto (`_obstaculos`).
var _ms_multidao: float = 0.0
var _t_log: float = 0.0
var _rng := RandomNumberGenerator.new()


# --- ganchos ----------------------------------------------------------------

func montar(abertura: Node) -> void:
	if OS.get_cmdline_user_args().has("--sem-roda"):
		return
	_ab = abertura
	_carro = abertura.get(&"_carro") as CarroCena
	_raiz = abertura.get(&"_raiz") as Node3D
	if _carro == null or _raiz == null or not abertura.has_method(&"_encapuzado"):
		return
	_rng.seed = 7_310
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--roda-sonda="):
			_sonda_em = float(a.trim_prefix("--roda-sonda="))
	var romeiros: Array = abertura.get(&"_romeiros")
	for i: int in ROMEIROS:
		if romeiros != null and i < romeiros.size():
			_corpos.append(romeiros[i] as Corpo)
	var us := Time.get_ticks_usec()
	for k in NOVOS.size():
		var n: Array = NOVOS[k]
		var c := abertura.call(&"_encapuzado", "Roda%d" % k, SEMENTE + k, float(n[0]),
			int(n[1])) as Corpo
		if c != null:
			_corpos.append(c)
			_novos.append(c)
	for c: Corpo in _corpos:
		_andares.append(c.get_meta(&"andar") as AndarMacabro if c.has_meta(&"andar") else null)
		_dentro.append(false)
		_r_ini.append(0.0)
		_r_fim.append(_rng.randf_range(RAIO_CARONA.x, RAIO_CARONA.y))
		_lugar.append(0.0)
		_acumulado.append(0.0)
		_vem.append(VEM.x)
		_t_pode.append(0.0)
		_t_entrou.append(0.0)
	for c: Corpo in _novos:
		_rarear(c)
	# A `--andar-sonda` marca o tempo com o relogio desta cena.
	AndarMacabro.sonda_na_cena(abertura)
	# O retrovisor (o que ele mostra conta como olhado): a camera dele nasce
	# com a cabine; aqui so se acha o no.
	if _carro.cabine != null:
		_espelho = _achar_espelho(_carro.cabine)
	print("[roda] montou %d corpos (%d novos) em %.1f ms, retrovisor %s" % [_corpos.size(),
		_novos.size(), (Time.get_ticks_usec() - us) / 1000.0, "sim" if _espelho != null else "nao"])


## Desenha os novos uns quadros debaixo do preto, na frente da lente e abaixo do
## asfalto: o pano deles cria as texturas da placa, a aura roda o `preprocess`,
## e a pipeline de cada material entra no cache antes da batida.
func aquecer(ligar: bool, onde: Vector3) -> void:
	if _novos.is_empty():
		return
	var cam := _ab.get(&"_cam") as Camera3D if _ab != null else null
	var lado := cam.global_basis.x if cam != null else Vector3.RIGHT
	var frente := -cam.global_basis.z if cam != null else Vector3.FORWARD
	for k in _novos.size():
		var c := _novos[k]
		if ligar:
			c.global_position = onde + frente * 1.2 + lado * (float(k) - float(_novos.size() - 1) * 0.5) * 0.75
		c.visible = ligar
		var aura := c.get_meta(&"aura", null) as GPUParticles3D
		if aura != null:
			aura.emitting = ligar


## A batida: dali em diante a roda e deles.
func batida() -> void:
	if _corpos.is_empty() or _t >= 0.0 or _desligado:
		return
	_t = 0.0
	_cam = _ab.get(&"_cam") as Camera3D
	if _espelho != null:
		AndarMacabro.usar_espelho(_espelho.get(&"_cam") as Camera3D,
			_espelho.get(&"_vp") as SubViewport)
	# As vagas: igualmente espacadas no anel, um fio de sorteio em cada uma, e
	# cada corpo numa vaga sorteada (romeiros e novos misturados).
	var n := _corpos.size()
	var ordem: Array[int] = []
	for i in n:
		ordem.append(i)
	_embaralhar(ordem)
	for k in n:
		var i := ordem[k]
		var c := _corpos[i]
		c.set_meta(&"roda", true)
		_rarear(c)
		_lugar[i] = TAU * (float(k) + _rng.randf_range(-0.2, 0.2)) / float(n)
		_vem[i] = _rng.randf_range(VEM.x, VEM.y)
	# A ordem de entrada salteada de novo: vizinhos nao entram em fila. E
	# escalonada: sempre tem alguem saindo da nevoa nos primeiros segundos.
	_embaralhar(ordem)
	_ordem = ordem
	for k in n:
		_t_pode[ordem[k]] = ENTRA_ATE * float(k) / float(maxi(n - 1, 1))


func _embaralhar(lista: Array[int]) -> void:
	for i in lista.size():
		var j := _rng.randi_range(i, lista.size() - 1)
		var tmp := lista[i]
		lista[i] = lista[j]
		lista[j] = tmp


func desligar() -> void:
	_desligado = true
	for c: Corpo in _corpos:
		if is_instance_valid(c):
			c.visible = false
			c.set_meta(&"em_cena", false)


# --- o quadro ---------------------------------------------------------------

var _ordem: Array[int] = []


func _process(delta: float) -> void:
	if _t < 0.0 or _desligado or _sondando or _carro == null or _cam == null \
			or not is_instance_valid(_cam):
		return
	_t += delta
	if _sonda_em >= 0.0 and _t >= _sonda_em:
		_sondar()
		return
	var us := Time.get_ticks_usec()
	_entrar_um()
	var ct := _quadro_do_carro()
	var inv := ct.affine_inverse()
	var olho := _cam.global_position
	var outros := _obstaculos(inv)
	_medir_meia_lua(inv)
	var pos := PackedVector2Array()
	pos.resize(_corpos.size())
	for i in _corpos.size():
		var p := inv * _corpos[i].global_position
		pos[i] = Vector2(p.x, p.z)
	for i in _corpos.size():
		if not _dentro[i]:
			continue
		var c := _corpos[i]
		var xz := pos[i]
		var quer := _querer(i, xz) + _afastar(i, xz, pos, outros)
		var andar := _andares[i]
		var visto := AndarMacabro.olhado(c)
		# O plano das figuras esconde todos os romeiros quando acaba: aqui ele e da
		# roda, e volta. (Esconder quem esta fora da lente nao poupa placa nenhuma:
		# medido com a cena andando, 11,06 contra 11,15 ms de GPU a 4K.)
		if not c.visible:
			c.visible = true
		var v := 0.0
		if andar != null:
			v = andar.ritmo(delta, quer.length(), visto)
		var dir := quer.normalized() if quer.length_squared() > 0.000001 else Vector2.ZERO
		xz = _fora_dos_obstaculos(i, xz + dir * v * delta, pos, outros)
		pos[i] = xz
		_por_no_chao(c, ct * Vector3(xz.x, 0.0, xz.y))
		_virar(c, ct, xz, dir * v, delta)
		# A pose: todo quadro com a lente (ou o retrovisor) em cima; fora dela, um
		# quadro em cada `FORA_DA_LENTE`, cada corpo no seu (o no anda todo quadro).
		_acumulado[i] += delta
		if andar == null or (not visto and (Engine.get_process_frames() + i) % FORA_DA_LENTE != 0):
			continue
		# Quem escreve os onze ossos e o `AndarMacabro`: o `Corpo` nao precisa
		# escrever a pose de sempre por baixo (`dominado`), so o resto do quadro dele.
		c.dominado = true
		c.animar(0.0, _acumulado[i])
		var estalo := andar.passo(_acumulado[i], olho)
		_acumulado[i] = 0.0
		if estalo > 0.0 and _ab != null:
			_ab.call(&"_estalar", c, estalo, true)
	if _log:
		var ms := (Time.get_ticks_usec() - us) / 1000.0
		_ms_soma += ms
		_ms_n += 1
		_ms_pior = maxf(_ms_pior, ms)
		_t_log -= delta
		if _t_log <= 0.0:
			_t_log = 0.5
			_imprimir(pos, outros)
	if _log_raio:
		_t_raio -= delta
		if _t_raio <= 0.0:
			_t_raio = 1.0
			_imprimir_raio(pos, outros)


## Um por quadro, cada um na sua vaga, longe, num quadro em que nem a lente nem
## o retrovisor a veem. Quem tem a vaga a vista espera (a da frente, na calma,
## so enche quando a lente desce para o chao). Entra tao longe quanto ele anda,
## a `VEM`, ate `FECHA`: quem entra tarde entra mais perto, no mesmo passo.
func _entrar_um() -> void:
	var ct := _quadro_do_carro()
	for i: int in _ordem:
		if _dentro[i] or _t < _t_pode[i]:
			continue
		var c := _corpos[i]
		var th := _vaga(i)
		var r := clampf(_raio_do_setor(i, th, RAIO_MOTORISTA_MIN) + _vem[i] * maxf(FECHA - _t, 0.0),
			ENTRA_RAIO.x, ENTRA_RAIO.y)
		var xz := Vector2(sin(th), -cos(th)) * r
		_por_no_chao(c, ct * Vector3(xz.x, 0.0, xz.y))
		_virar(c, ct, xz, Vector2.ZERO, 0.0)
		if AndarMacabro.olhado(c):
			continue
		_dentro[i] = true
		_r_ini[i] = r
		_t_entrou[i] = _t
		if _log:
			print("[roda] entra %d t=%.2f r=%.1f th=%.0f" % [i, _t, xz.length(), rad_to_deg(th)])
		if _log_raio:
			_imprimir_entrada(c, r, th)
		if _ab != null and _ab.has_method(&"_mostrar"):
			_ab.call(&"_mostrar", c)
		c.visible = true
		c.set_meta(&"rapidez", 0.0)
		return


## O espaco do carro sem a inclinacao dele: so a posicao e o rumo. Depois da
## batida o carro fica torto (o nariz na arvore, o tranco das molas), e com a
## inclinacao cada pe posto no chao voltava deslocado no espaco dele: a roda
## escorregava para dentro sozinha, quadro a quadro.
func _quadro_do_carro() -> Transform3D:
	var t := _carro.global_transform
	var frente := -t.basis.z
	frente.y = 0.0
	if frente.length_squared() < 0.0001:
		frente = Vector3.FORWARD
	return Transform3D(Basis.looking_at(frente.normalized(), Vector3.UP), t.origin)


## O angulo da vaga de `i` agora (0 no nariz, positivo para o carona).
func _vaga(i: int) -> float:
	return wrapf(_lugar[i] - GIRO * _t, -PI, PI)


## Para onde ele quer ir (m/s, espaco do carro): para a vaga dele pelo arco, e
## nao pela corda (quem ficou para tras com a lente em cima cortava caminho e
## chegava mais perto do carro que o setor deixa), no raio do setor em que ELE
## esta, mais o passo do anel girando.
func _querer(i: int, xz: Vector2) -> Vector2:
	var r := xz.length()
	if r < 0.01:
		return Vector2(1.0, 0.0) * CHEGA
	var fora := xz / r
	var th := atan2(xz.x, -xz.y)
	var r_alvo := _raio_alvo(i, th)
	# Theta crescendo e (cos, sen); o anel anda com theta diminuindo.
	var tangente := Vector2(cos(th), sin(th))
	var falta_ang := wrapf(_vaga(i) - th, -PI, PI)
	# O passo da vaga fechando vai junto (e nao so o que falta): sem ele, quem
	# segue a vaga fica um tanto para tras dela, e a lente chegando pegava o
	# passo pela metade.
	var quer := fora * ((r_alvo - r) * PUXA - _fechando(i, th)) \
		+ tangente * (falta_ang * r * PUXA - GIRO * r)
	return quer.limit_length(CHEGA)


## O quanto a vaga de `i` ja fechou (0 na entrada, 1 em `FECHA`).
func _fechado(i: int) -> float:
	var u := clampf((_t - _t_entrou[i]) / maxf(FECHA - _t_entrou[i], 1.0), 0.0, 1.0)
	return 1.0 - pow(1.0 - u, FECHA_CURVA)


## O raio em que ele deve estar agora no angulo `th`: de onde entrou ate o raio
## final do setor (o do motorista no minimo), fechando com o tempo, e nunca
## dentro do raio do setor de agora. Do lado do motorista o raio de agora cai
## quando a meia-lua chega (7,6 a 4,6 m, a 0,3 m/s): mirando nele, o passo
## somava a queda e quem estava ali ia a 0,5 m/s na lente (`--roda-raio`, 26/09).
func _raio_alvo(i: int, th: float) -> float:
	var fim := _raio_do_setor(i, th, RAIO_MOTORISTA_MIN)
	return maxf(lerpf(maxf(_r_ini[i], fim), fim, _fechado(i)), _raio_do_setor(i, th))


## A rapidez (m/s) com que o raio da vaga de `i` cai agora (0 se quem segura e o
## raio do setor de agora).
func _fechando(i: int, th: float) -> float:
	var falta := maxf(FECHA - _t_entrou[i], 1.0)
	var u := (_t - _t_entrou[i]) / falta
	if u < 0.0 or u >= 1.0:
		return 0.0
	var fim := _raio_do_setor(i, th, RAIO_MOTORISTA_MIN)
	var de := maxf(_r_ini[i], fim)
	if lerpf(de, fim, _fechado(i)) < _raio_do_setor(i, th):
		return 0.0
	return (de - fim) * FECHA_CURVA * pow(1.0 - u, FECHA_CURVA - 1.0) / falta


## O raio final do setor no angulo `th`. `motorista` no lugar do raio do lado
## do motorista agora (negativo: o de agora).
func _raio_do_setor(i: int, th: float, motorista: float = -1.0) -> float:
	var r := _r_fim[i]
	var a := absf(th)
	r = lerpf(r, maxf(r, RAIO_FRENTE), 1.0 - smoothstep(FRENTE, FRENTE + BORDA, a))
	r = lerpf(r, maxf(r, RAIO_TRAS), smoothstep(TRAS - BORDA, TRAS, a))
	var no_motorista := smoothstep(MOTORISTA.x - BORDA, MOTORISTA.x, th) \
		* (1.0 - smoothstep(MOTORISTA.y, MOTORISTA.y + BORDA, th))
	return lerpf(r, maxf(r, _r_motorista if motorista < 0.0 else motorista), no_motorista)


## O raio do lado do motorista: longe enquanto a meia-lua nao veio; depois um
## passo atras do mais longe dela (ela anda para a porta).
func _medir_meia_lua(inv: Transform3D) -> void:
	var romeiros: Variant = _ab.get(&"_romeiros")
	if not romeiros is Array:
		return
	var longe := 0.0
	var alguem := false
	for k in mini(MEIA_LUA, (romeiros as Array).size()):
		var c := (romeiros as Array)[k] as Corpo
		if c == null or not is_instance_valid(c) or c.get_parent() != _carro \
				or not c.is_visible_in_tree():
			continue
		var p := inv * c.global_position
		# O do carona saiu da meia-lua.
		if p.x > 0.0:
			continue
		alguem = true
		longe = maxf(longe, Vector2(p.x, p.z).length())
	if alguem:
		_meia_lua_veio = true
	var alvo := RAIO_MOTORISTA
	if _meia_lua_veio:
		alvo = clampf(longe + ATRAS_DA_MEIA_LUA, RAIO_MOTORISTA_MIN, RAIO_MOTORISTA) \
			if alguem else RAIO_MOTORISTA_MIN
	_r_motorista = move_toward(_r_motorista, alvo, get_process_delta_time() * 0.3)


## Os vizinhos e os de pe em volta empurram, antes de encostar.
func _afastar(i: int, xz: Vector2, pos: PackedVector2Array, outros: PackedVector2Array) -> Vector2:
	var empurra := Vector2.ZERO
	var alcance := FOLGA * 1.5
	for j in pos.size():
		if j == i or not _dentro[j]:
			continue
		empurra += _empurrao(xz, pos[j], alcance)
	for o: Vector2 in outros:
		empurra += _empurrao(xz, o, alcance)
	return empurra


func _empurrao(xz: Vector2, de: Vector2, alcance: float) -> Vector2:
	var d := xz - de
	var l := d.length()
	if l >= alcance or l < 0.0001:
		return Vector2.ZERO
	return d / l * AFASTA * (alcance - l) / (alcance - FOLGA * 0.5)


## O que nao pode ser atravessado de jeito nenhum: a caixa do carro, a arvore, e
## a folga dos outros. Empurra para fora na hora.
func _fora_dos_obstaculos(i: int, xz: Vector2, pos: PackedVector2Array,
		outros: PackedVector2Array) -> Vector2:
	for j in pos.size():
		if j != i and _dentro[j]:
			xz = _fora_do_circulo(xz, pos[j], FOLGA)
	for o: Vector2 in outros:
		xz = _fora_do_circulo(xz, o, FOLGA)
	xz = _fora_do_circulo(xz, ARVORE, ARVORE_RAIO)
	# E nunca mais perto do carro que o setor deixa.
	var r := xz.length()
	if r > 0.01:
		var piso := _raio_do_setor(i, atan2(xz.x, -xz.y)) - PISO
		if r < piso:
			xz *= piso / r
	var meia := CARRO + Vector2.ONE * CARRO_FOLGA
	if absf(xz.x) < meia.x and absf(xz.y) < meia.y:
		var dx := meia.x - absf(xz.x)
		var dz := meia.y - absf(xz.y)
		if dx < dz:
			xz.x = signf(xz.x) * meia.x if xz.x != 0.0 else meia.x
		else:
			xz.y = signf(xz.y) * meia.y if xz.y != 0.0 else meia.y
	return xz


static func _fora_do_circulo(xz: Vector2, centro: Vector2, raio: float) -> Vector2:
	var d := xz - centro
	var l := d.length()
	if l >= raio:
		return xz
	if l < 0.0001:
		d = Vector2(1.0, 0.0)
		l = 1.0
	return centro + d / l * raio


## Todo encapuzado de pe em volta que nao e da roda, no espaco do carro.
func _obstaculos(inv: Transform3D) -> PackedVector2Array:
	var saida := PackedVector2Array()
	var lista: Array = []
	var padre: Variant = _ab.get(&"_padre")
	if padre is Corpo:
		lista.append(padre)
	var romeiros: Variant = _ab.get(&"_romeiros")
	if romeiros is Array:
		lista.append_array(romeiros)
	var vigias: Variant = _ab.get(&"_vigias")
	if vigias is Array:
		lista.append_array(vigias)
	for o: Variant in lista:
		var c := o as Corpo
		if c == null or not is_instance_valid(c) or c.get_meta(&"roda", false) \
				or not c.is_visible_in_tree():
			continue
		var p := inv * c.global_position
		saida.append(Vector2(p.x, p.z))
	# E a multidao, que agora tambem vem ate perto do carro (3 a 9 m, pelo lado):
	# so as figuras perto de algum da roda (`MultidaoEncapuzada.perto_de`).
	var multidao := _ab.get(&"_multidao") as Node3D
	if multidao != null and multidao.has_method(&"perto_de"):
		var us := Time.get_ticks_usec()
		var pontos := PackedVector3Array()
		for i in _corpos.size():
			if _dentro[i]:
				pontos.append(_corpos[i].global_position)
		for m: Vector3 in multidao.call(&"perto_de", pontos, FOLGA * 1.6):
			var p := inv * m
			saida.append(Vector2(p.x, p.z))
		_ms_multidao += (Time.get_ticks_usec() - us) / 1000.0
	return saida


## Os pes no chao da estrada: a altura da mata (ou da pista) debaixo de `onde`.
func _por_no_chao(c: Corpo, onde: Vector3) -> void:
	var lp := _raiz.to_local(onde)
	lp.y = chao_em(lp)
	c.position = lp if c.get_parent() == _raiz else c.get_parent().to_local(_raiz.to_global(lp))


## A altura do chao em `p` (espaco da estrada): o ponto do eixo mais perto (um
## passo de Newton a partir de s = -z, que e o s do eixo), e dali a lateral.
static func chao_em(p: Vector3) -> float:
	var s := -p.z
	var o := EstradaBuilder.ponto_em(s)
	var t := EstradaBuilder.direcao_em(s)
	var dx := t.x / -t.z if absf(t.z) > 0.001 else 0.0
	s += (p.x - o.x) * dx / (dx * dx + 1.0)
	o = EstradaBuilder.ponto_em(s)
	var d := (p - o).dot(EstradaBuilder.lado_em(s))
	if absf(d) < KitEstrada.MEIA_PISTA:
		return o.y + KitEstrada.altura_da_pista(o, d)
	return o.y + EstradaBuilder.altura_lateral(d)


## De frente para onde anda, puxado para o carro: ele cerca olhando para dentro.
## A cabeca e do `AndarMacabro`, que acha a lente sozinha.
func _virar(c: Corpo, ct: Transform3D, xz: Vector2, vel: Vector2, delta: float) -> void:
	var para_o_carro := -xz.normalized() if xz.length_squared() > 0.0001 else Vector2(0.0, 1.0)
	var quer := vel + para_o_carro * OLHA_O_CARRO
	if quer.length_squared() < 0.000001:
		return
	var alvo := (ct.basis * Vector3(quer.x, 0.0, quer.y))
	alvo.y = 0.0
	alvo = alvo.normalized()
	var frente := -c.global_basis.z
	frente.y = 0.0
	if delta <= 0.0 or frente.length_squared() < 0.0001:
		c.global_basis = Basis.looking_at(alvo, Vector3.UP)
		return
	frente = frente.normalized()
	var giro := frente.signed_angle_to(alvo, Vector3.UP)
	var passo := clampf(giro, -VIRA * delta, VIRA * delta)
	c.global_basis = Basis.looking_at(frente.rotated(Vector3.UP, passo), Vector3.UP)


## A veste dos da roda: sem a treva de volume (doze volumes a mais na nevoa, e a
## cena ja tem as manchas de treva do mato) e com a aura rala.
func _rarear(c: Corpo) -> void:
	for f: Node in c.get_children():
		if f is FogVolume:
			(f as FogVolume).visible = false
	var aura := c.get_meta(&"aura", null) as AuraNegra
	if aura != null:
		aura.forca = AURA


static func _achar_espelho(no: Node) -> Node:
	if no is EspelhoRetrovisor:
		return no
	for f: Node in no.get_children():
		var e := _achar_espelho(f)
		if e != null:
			return e
	return null


func _imprimir(pos: PackedVector2Array, outros: PackedVector2Array) -> void:
	var linha := "[roda] t=%.1f" % _t
	var pior := INF
	for i in pos.size():
		if not _dentro[i]:
			continue
		var xz := pos[i]
		var th := rad_to_deg(atan2(xz.x, -xz.y))
		linha += " %d:(%.1f,%.1f r%.1f/%.1f %+.0f%s)" % [i, xz.x, xz.y, xz.length(),
			_raio_alvo(i, deg_to_rad(th)), th, "*" if AndarMacabro.olhado(_corpos[i]) else ""]
		for j in pos.size():
			if j > i and _dentro[j]:
				pior = minf(pior, xz.distance_to(pos[j]))
		for o: Vector2 in outros:
			pior = minf(pior, xz.distance_to(o))
		pior = minf(pior, xz.distance_to(ARVORE) + FOLGA - ARVORE_RAIO)
	var fora := ""
	for o: Vector2 in outros:
		fora += " (%.1f,%.1f)" % [o.x, o.y]
	print("%s | folga min %.2f | motorista %.1f | cpu %.2f/%.2f ms (multidao %.2f) | outros%s" % [
		linha, pior, _r_motorista, _ms_soma / maxf(1.0, float(_ms_n)), _ms_pior,
		_ms_multidao / maxf(1.0, float(_ms_n)), fora])
	_ms_soma = 0.0
	_ms_multidao = 0.0
	_ms_n = 0
	_ms_pior = 0.0


## O relogio da cena (s), o mesmo das marcas `[susto]` e da rajada.
func _relogio() -> float:
	var r: Variant = _ab.get(&"_relogio_cena") if _ab != null else null
	return float(r) if r != null else _t


## `--roda-raio`: quem entrou, onde, e a conferencia por fora do `olhado`: pe,
## meio e topo do corpo contra o quadro da lente e do retrovisor, sem folga.
func _imprimir_entrada(c: Corpo, r: float, th: float) -> void:
	var h := c.altura()
	var pe := c.global_position
	var lente := 0
	var espelho := 0
	var cam := c.get_viewport().get_camera_3d()
	var e := AndarMacabro._espelho_ativo()
	for p: Vector3 in [pe, pe + Vector3.UP * h * 0.5, pe + Vector3.UP * h]:
		if cam != null and cam.is_position_in_frustum(p):
			lente += 1
		if e != null and e.is_position_in_frustum(p):
			espelho += 1
	print("[roda-raio] entra %s t=%.2f r=%.1f th=%+.0f vem %.2f | lente %d/3 retrovisor %d/3" % [
		c.name, _relogio(), r, rad_to_deg(th), _vem[_corpos.find(c)], lente, espelho])


## `--roda-raio`: a cada segundo, por corpo, o raio (m, do meio do carro), o
## raio da vaga e o angulo (* no quadro da lente ou do retrovisor), e as folgas
## minimas: entre dois da roda, da roda para os outros de pe, e da roda para a
## caixa do carro (sem a folga dela; negativo e dentro).
func _imprimir_raio(pos: PackedVector2Array, outros: PackedVector2Array) -> void:
	var linha := "[roda-raio] t=%.2f" % _relogio()
	var entre := INF
	var com_outros := INF
	var carro := INF
	for i in pos.size():
		var c := _corpos[i]
		if not _dentro[i]:
			linha += " %s:-" % c.name
			continue
		var xz := pos[i]
		var th := atan2(xz.x, -xz.y)
		linha += " %s:%.2f/%.2f/%+.0f%s" % [c.name, xz.length(), _raio_alvo(i, th),
			rad_to_deg(th), "*" if AndarMacabro.olhado(c) else ""]
		for j in range(i + 1, pos.size()):
			if _dentro[j]:
				entre = minf(entre, xz.distance_to(pos[j]))
		for o: Vector2 in outros:
			com_outros = minf(com_outros, xz.distance_to(o))
		var d := Vector2(absf(xz.x) - CARRO.x, absf(xz.y) - CARRO.y)
		carro = minf(carro, d.max(Vector2.ZERO).length() if d.x > 0.0 or d.y > 0.0 \
			else maxf(d.x, d.y))
	print("%s | folga roda %.2f outros %.2f carro %.2f | motorista %.1f" % [linha, entre,
		com_outros, carro, _r_motorista])


# --- `--roda-sonda=S`: o custo de GPU da roda, com e sem, intercalado --------

## Tempo parado, e cada parte da roda aparece e some em ciclos: a media dos
## "com" contra a dos "sem" na mesma rodada, intercalados, e o que desconta a
## placa disputada (outras sessoes com Godot aberto). Partes: a roda inteira,
## so as auras, so o pano, e so o corpo (malha e bracos, sem pano e aura).
func _sondar() -> void:
	_sondando = true
	Engine.time_scale = 0.0001
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var dentro: Array[Corpo] = []
	for i in _corpos.size():
		if _dentro[i]:
			dentro.append(_corpos[i])
	var vistos := 0
	for c: Corpo in dentro:
		if AndarMacabro.olhado(c):
			vistos += 1
	var partes: Dictionary = {"roda": [], "auras": [], "pano": [], "corpo": []}
	for c: Corpo in dentro:
		(partes["roda"] as Array).append(c)
		var aura := c.get_meta(&"aura") as Node3D if c.has_meta(&"aura") else null
		if aura != null:
			(partes["auras"] as Array).append(aura)
		var capuz := c.get_meta(&"capuz") as CapuzMacabro if c.has_meta(&"capuz") else null
		if capuz != null and capuz.pano != null:
			for pc: PanoGPU.PecaDePano in capuz.pano.pecas:
				if pc.instancia != null:
					(partes["pano"] as Array).append(pc.instancia)
		var esq := c.esqueleto()
		if esq != null:
			for f: Node in esq.get_children():
				if f is MeshInstance3D:
					(partes["corpo"] as Array).append(f)
	print("[roda-sonda] %.1f s depois da batida: %d na roda, %d no quadro (lente ou retrovisor)" % [
		_t, dentro.size(), vistos])
	for nome: String in partes:
		var nos: Array = partes[nome]
		var com := 0.0
		var sem := 0.0
		for ciclo in 8:
			com += await _gpu_por(vp, nos, true)
			sem += await _gpu_por(vp, nos, false)
		print("[roda-sonda] %-6s %3d nos: com %.2f ms, sem %.2f ms de GPU -> custa %.2f ms" % [
			nome, nos.size(), com / 8.0, sem / 8.0, (com - sem) / 8.0])
	get_tree().quit()


func _gpu_por(vp: RID, nos: Array, ligado: bool) -> float:
	for n: Variant in nos:
		(n as Node3D).visible = ligado
	for _i in 6:
		await get_tree().process_frame
	var soma := 0.0
	for _i in 10:
		await get_tree().process_frame
		soma += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return soma / 10.0


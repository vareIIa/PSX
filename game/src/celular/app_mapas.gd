## Mapas: o app de mapas do iPhone de 2010, com o aparelho deitado nas duas
## maos.
##
## O que ele faz
## -------------
## E o GPS do jogo (`Gps` guarda os lugares, o destino e a rota; este app so
## desenha e conversa com o jogador), com a cara do iOS 4:
##   - a busca: toca no campo e escolhe uma categoria; os alfinetes vermelhos
##     caem um a um em cima dos lugares achados, e o mapa se ajusta a eles;
##   - o balao do alfinete: nome, rua e distancia, com o botao azul de rota;
##   - a bolinha azul de onde a pessoa esta, com o circulo de precisao pulsando;
##     o botao de localizar alterna entre solto, seguindo e bussola (o mapa gira
##     com o rumo, como o iPhone 4 fazia com a bussola dele);
##   - a aba Rotas: o caminho roxo ate o destino, a distancia, quanto tempo a pe
##     e de carro, e a proxima manobra;
##   - a pagina que dobra no canto de baixo: Mapa, Satelite, Hibrido, Lista,
##     largar um alfinete no meio do mapa e ligar o transito;
##   - arrastar com o dedo (com inercia), a roda do mouse e o toque duplo dao
##     zoom, e o toque longo larga um alfinete roxo.
##
## Tecla e controle: setas/analogico esquerdo escolhem lugar (cima/baixo) e
## categoria (lados), E/A traca a rota, Q/Y localiza, Z X ou LT RT dao zoom,
## R/RB abre a pagina dobrada, e o analogico direito arrasta o mapa.
##
## Deitado ou em pe
## ----------------
## O desenho le `largura` e `alto_tela`, que o `Celular` troca quando o aparelho
## gira. A pe ele deita nas duas maos (`quer_deitar`); ao volante continua em pe
## — a outra mao esta no volante.
class_name AppMapas
extends AppCelular

const BARRA := SoFundo.BARRA
const NAV := 15.0
const FERRAMENTAS := 15.0

## Metros por unidade da tela: o mais perto, o mais longe e o de abrir (uns
## 480 m de largura deitado).
const MPU_MIN := 0.3
const MPU_MAX := 14.0
const MPU_ABRE := 2.2
## O passo de uma tecla de zoom, e de um toque duplo.
const PASSO_ZOOM := 1.45
## Voo da vista ate um lugar escolhido (s).
const VOO := 0.55
## Inercia do arrasto: quanto da velocidade sobra por segundo.
const ATRITO := 0.02
## Velocidade de quem anda a pe e de quem dirige na cidade (m/s), para o tempo
## estimado da aba Rotas.
const A_PE := 1.35
const DE_CARRO := 8.5

enum Seguir { NAO, SEGUIR, BUSSOLA }
enum Aba { BUSCA, ROTAS }

const AZUL := Color("2f7cf6")
const PINO := Color("e0302a")
const PINO_ROXO := Color("8e44d6")
const PINO_VERDE := Color("35a852")
const ROTA := Color(0.40, 0.36, 0.95, 0.80)
const ROTA_HALO := Color(0.16, 0.12, 0.52, 0.40)
const NAV_CIMA := Color("b2bfd1")
const NAV_BAIXO := Color("6e85a5")
const SEL_CIMA := Color("0a8cf5")
const SEL_BAIXO := Color("0160e3")

## Quanto da pagina fica enrolado por cima do mapa, a partir da dobra
## (unidades).
const ABA_FUNDO := 20.0
## As opcoes debaixo da pagina dobrada, na ordem do foco de tecla.
const OPCOES: Array[StringName] = [&"largar", &"transito", &"mapa", &"satelite",
	&"hibrido", &"lista"]

var largura: float = AppCelular.L
var mapa := MapaDoIphone.new()

var _seguir: Seguir = Seguir.SEGUIR
var _aba: Aba = Aba.BUSCA
var _t: float = 0.0
## A lista de categorias aberta sob o campo de busca, e a linha em foco.
var _busca_aberta: bool = false
var _busca_sel: int = 1
## A pagina dobrada: 0 fechada, 1 aberta; e a opcao em foco.
var _curl: float = 0.0
var _curl_alvo: float = 0.0
var _opcao: int = 0
## A vista de lista dos resultados (Lista, na pagina dobrada).
var _lista: bool = false
var _lista_rolagem: float = 0.0
## O balao aberto: o indice do resultado, -2 o alfinete roxo, -1 nenhum.
var _balao: int = -1
## O alfinete largado pelo jogador (toque longo ou "Largar Alfinete").
var _alfinete: Dictionary = {}
## Quando cada alfinete comecou a cair (s em `_t`).
var _quedas: Array[float] = []
var _inercia := Vector2.ZERO
var _arrasto_vel := Vector2.ZERO
var _arrasto_us: int = 0
var _mpu_alvo: float = MPU_ABRE
var _zoom_foco := Vector2(-1.0, -1.0)
var _voo: Dictionary = {}
var _ultimo_toque: float = -9.0
var _ultimo_ponto := Vector2.ZERO
var _area := Rect2()


func quer_deitar() -> bool:
	return true


func abrir() -> void:
	Gps.preparar()
	_t = 0.0
	_seguir = Seguir.SEGUIR
	_busca_aberta = false
	_curl = 0.0
	_curl_alvo = 0.0
	_lista = false
	_inercia = Vector2.ZERO
	_voo = {}
	var p := Gps.posicao()
	mapa.centro = Vector2(p.x, p.z)
	mapa.mpu = MPU_ABRE
	_mpu_alvo = MPU_ABRE
	mapa.giro = 0.0
	_aba = Aba.ROTAS if not Gps.destino.is_empty() and Gps.filtro == 0 else Aba.BUSCA
	_soltar_alfinetes(false)
	_balao = Gps.sel if Gps.filtro != 0 and not Gps.resultados().is_empty() else -1


## A busca mudou de fora (o `Gps.filtrar_por` de uma cena ou teste).
func mudou_busca() -> void:
	_soltar_alfinetes(true)
	_balao = 0 if not Gps.resultados().is_empty() else -1


# --- tempo --------------------------------------------------------------------------

func processar(delta: float) -> void:
	super.processar(delta)
	_t += delta
	mapa.processar(delta)
	_curl = move_toward(_curl, _curl_alvo, delta / 0.42)
	# O zoom anda atras do alvo, em volta do ponto pedido.
	if absf(mapa.mpu - _mpu_alvo) > 0.0005:
		var novo := exp(lerpf(log(mapa.mpu), log(_mpu_alvo), 1.0 - exp(-12.0 * delta)))
		if _zoom_foco.x >= 0.0 and _seguir == Seguir.NAO:
			mapa.zoom_em(_zoom_foco, novo)
		else:
			mapa.mpu = novo
	if not _voo.is_empty():
		_voo["t"] = float(_voo["t"]) + delta
		var k := clampf(float(_voo["t"]) / float(_voo["dur"]), 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		mapa.centro = (_voo["de"] as Vector2).lerp(_voo["para"], e)
		if _voo.has("mpu"):
			var m := exp(lerpf(log(float(_voo["mpu_de"])), log(float(_voo["mpu"])), e))
			mapa.mpu = m
			_mpu_alvo = m
		if k >= 1.0:
			_voo = {}
	elif _seguir != Seguir.NAO:
		var p := Gps.posicao()
		mapa.centro = mapa.centro.lerp(Vector2(p.x, p.z), 1.0 - exp(-8.0 * delta))
	elif _inercia.length() > 0.05:
		mapa.arrastar(_inercia * delta)
		_inercia *= pow(ATRITO, delta)
	# O mapa gira com a pessoa so no modo bussola; voltar ao norte tambem gira.
	var giro_alvo := Gps.rumo() if _seguir == Seguir.BUSSOLA else 0.0
	mapa.giro = lerp_angle(mapa.giro, giro_alvo, 1.0 - exp(-7.0 * delta))


# --- entrada ------------------------------------------------------------------------

func acao(nome: StringName) -> bool:
	if _curl_alvo > 0.0:
		return _acao_na_pagina(nome)
	if _lista:
		return _acao_na_lista(nome)
	if _busca_aberta:
		match nome:
			&"cima":
				_busca_sel = maxi(1, _busca_sel - 1)
			&"baixo":
				_busca_sel = mini(Gps.FILTROS.size() - 1, _busca_sel + 1)
			&"ok":
				_buscar(_busca_sel)
			&"voltar":
				_busca_aberta = false
		return true
	var res := Gps.resultados()
	match nome:
		&"cima", &"baixo":
			if res.is_empty():
				return true
			var passo := -1 if nome == &"cima" else 1
			var novo := posmod(_balao + passo, res.size()) if _balao >= 0 \
				else (0 if passo > 0 else res.size() - 1)
			_escolher(novo)
		&"esq", &"dir":
			var n := Gps.FILTROS.size()
			var i := posmod(Gps.filtro + (-1 if nome == &"esq" else 1), n)
			if i == 0:
				i = posmod(i + (-1 if nome == &"esq" else 1), n)
			_buscar(i)
		&"ok":
			if _balao >= 0 and _balao < res.size():
				_rota_para(res[_balao])
			elif _balao == -2 and not _alfinete.is_empty():
				_rota_para(_alfinete)
			elif _aba == Aba.ROTAS and not Gps.destino.is_empty():
				_enquadrar_rota()
			else:
				_busca_aberta = true
				_busca_sel = maxi(1, Gps.filtro)
		&"voltar":
			if _balao != -1:
				_balao = -1
			elif _aba == Aba.ROTAS:
				_aba = Aba.BUSCA
			else:
				return false
	return true


## Os comandos que nao sao de navegacao: zoom, localizar e a pagina dobrada.
func acao_extra(nome: StringName) -> bool:
	match nome:
		&"zoom_mais":
			_zoom(1.0 / PASSO_ZOOM)
		&"zoom_menos":
			_zoom(PASSO_ZOOM)
		&"examinar":
			_localizar()
		&"opcoes":
			_alternar_pagina()
		_:
			return false
	return true


func tecla(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_Z, KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom(PASSO_ZOOM)
		KEY_X, KEY_EQUAL, KEY_KP_ADD, KEY_PLUS:
			_zoom(1.0 / PASSO_ZOOM)
		KEY_R:
			_alternar_pagina()
		_:
			return false
	return true


## O analogico direito: arrasta o mapa como um dedo parado empurrando.
func analogico(eixo: Vector2, delta: float) -> void:
	if eixo.length() < 0.05 or _curl_alvo > 0.0 or _lista:
		return
	_seguir = Seguir.NAO
	_voo = {}
	_inercia = Vector2.ZERO
	mapa.arrastar(-eixo * 95.0 * delta)


func tocar(id: Variant) -> bool:
	if id is Array:
		var a: Array = id
		match StringName(a[0]):
			&"pino":
				_escolher(int(a[1]))
			&"rota":
				var res := Gps.resultados()
				if int(a[1]) >= 0 and int(a[1]) < res.size():
					_rota_para(res[int(a[1])])
			&"cat":
				_buscar(int(a[1]))
			&"linha":
				_lista = false
				_curl_alvo = 0.0
				_escolher(int(a[1]))
			&"opcao":
				_opcao = int(a[1])
				_aplicar_opcao(OPCOES[_opcao])
		return true
	match StringName(id):
		&"mapa":
			_tocar_no_mapa()
		&"pagina_fora":
			_curl_alvo = 0.0
		&"busca":
			_busca_aberta = not _busca_aberta
			_busca_sel = maxi(1, Gps.filtro)
			_balao = -1
		&"busca_fora":
			_busca_aberta = false
		&"limpar_busca":
			_buscar(0)
		&"localizar":
			_localizar()
		&"aba_busca":
			_aba = Aba.BUSCA
		&"aba_rotas":
			_aba = Aba.ROTAS
			_balao = -1
			if not Gps.destino.is_empty():
				_enquadrar_rota()
		&"curl":
			_alternar_pagina()
		&"alfinete":
			_balao = -2
		&"rota_alfinete":
			_rota_para(_alfinete)
		&"limpar_rota":
			Gps.limpar_rota()
			aviso("Rota apagada", Color.WHITE)
		&"fechar_lista":
			_lista = false
		_:
			return false
	return true


## Toque no mapa vazio: fecha o balao; o segundo toque logo depois da zoom.
func _tocar_no_mapa() -> void:
	var p := ponteiro
	if _t - _ultimo_toque < 0.32 and p.distance_to(_ultimo_ponto) < 6.0:
		_seguir = Seguir.NAO
		_zoom_foco = p
		_mpu_alvo = clampf(mapa.mpu / 2.0, MPU_MIN, MPU_MAX)
		_ultimo_toque = -9.0
		return
	_ultimo_toque = _t
	_ultimo_ponto = p
	_balao = -1
	_busca_aberta = false


## O toque longo no mapa larga o alfinete roxo, como no iPhone.
func segurar(p: Vector2) -> bool:
	if _curl_alvo > 0.0 or _lista or _busca_aberta or not _area.has_point(p):
		return false
	_largar_alfinete(mapa.para_mundo(p))
	return true


func arrastar(_desde: Vector2, delta: Vector2, fim: bool) -> bool:
	if _curl_alvo > 0.0 or _busca_aberta:
		return false
	if _lista:
		_lista_rolagem = maxf(0.0, _lista_rolagem - delta.y)
		return true
	if fim:
		# Dedo parado antes de soltar nao joga o mapa.
		var parado := float(Time.get_ticks_usec() - _arrasto_us) / 1000000.0 > 0.08
		_inercia = Vector2.ZERO if parado else _arrasto_vel
		_arrasto_vel = Vector2.ZERO
		_arrasto_us = 0
		return true
	_seguir = Seguir.NAO
	_voo = {}
	mapa.arrastar(delta)
	# Velocidade do dedo (unidades por segundo), filtrada: e ela que vira inercia
	# na hora de soltar.
	var agora := Time.get_ticks_usec()
	if _arrasto_us > 0:
		var dt := clampf(float(agora - _arrasto_us) / 1000000.0, 1.0 / 240.0, 0.1)
		_arrasto_vel = _arrasto_vel.lerp(delta / dt, 0.5)
	_arrasto_us = agora
	return true


func rolar(passos: float) -> bool:
	if _lista:
		_lista_rolagem = maxf(0.0, _lista_rolagem + passos * 8.0)
		return true
	if _curl_alvo > 0.0 or _busca_aberta:
		return true
	_zoom(pow(1.22, passos), ponteiro)
	return true


# --- o que as acoes fazem -----------------------------------------------------------

func _zoom(fator: float, foco := Vector2(-1.0, -1.0)) -> void:
	_mpu_alvo = clampf(_mpu_alvo * fator, MPU_MIN, MPU_MAX)
	_zoom_foco = foco if foco.x >= 0.0 else _area.get_center()
	AudioDirector.tocar_ui(&"clique", -28.0)


## Localizar: solto -> seguindo -> bussola -> seguindo.
func _localizar() -> void:
	match _seguir:
		Seguir.NAO:
			_seguir = Seguir.SEGUIR
		Seguir.SEGUIR:
			_seguir = Seguir.BUSSOLA
		_:
			_seguir = Seguir.SEGUIR
	_voo = {}
	_inercia = Vector2.ZERO
	AudioDirector.tocar_ui(&"clique", -18.0)


func _buscar(i: int) -> void:
	_busca_aberta = false
	_aba = Aba.BUSCA
	var n := Gps.escolher_filtro(i)
	_soltar_alfinetes(true)
	if i == 0:
		_balao = -1
		return
	if n == 0:
		aviso("Nada por perto", Color.WHITE)
		_balao = -1
		return
	_balao = -1
	_enquadrar_resultados()
	AudioDirector.tocar_ui(&"celular_ok", -16.0)


func _soltar_alfinetes(animar: bool) -> void:
	_quedas.clear()
	var n := Gps.resultados().size() if Gps.filtro != 0 else 0
	for i in n:
		_quedas.append(_t + float(i) * 0.05 if animar else -9.0)


## Escolhe o resultado `i`: o balao abre e a vista voa ate ele.
func _escolher(i: int) -> void:
	var res := Gps.resultados()
	if i < 0 or i >= res.size():
		return
	Gps.sel = i
	_balao = i
	var m: Vector3 = res[i]["mundo"]
	_voar(Vector2(m.x, m.z))
	AudioDirector.tocar_ui(&"clique", -24.0)


func _voar(para: Vector2, novo_mpu: float = -1.0) -> void:
	_seguir = Seguir.NAO
	_inercia = Vector2.ZERO
	_voo = {"de": mapa.centro, "para": para, "t": 0.0, "dur": VOO}
	if novo_mpu > 0.0:
		_voo["mpu_de"] = mapa.mpu
		_voo["mpu"] = clampf(novo_mpu, MPU_MIN, MPU_MAX)


## Enquadra os lugares achados mais perto junto com a pessoa.
func _enquadrar_resultados() -> void:
	var p := Gps.posicao()
	var caixa := Rect2(Vector2(p.x, p.z), Vector2.ZERO)
	var res := Gps.resultados()
	for i in mini(6, res.size()):
		var m: Vector3 = res[i]["mundo"]
		caixa = caixa.expand(Vector2(m.x, m.z))
	_enquadrar(caixa)


func _enquadrar_rota() -> void:
	if Gps.rota.size() < 2:
		return
	var caixa := Rect2(Gps.rota[0], Vector2.ZERO)
	for q: Vector2 in Gps.rota:
		caixa = caixa.expand(q)
	_enquadrar(caixa)


func _enquadrar(caixa: Rect2) -> void:
	var util := _area.grow(-14.0)
	var k := maxf(caixa.size.x / maxf(util.size.x, 1.0), caixa.size.y / maxf(util.size.y, 1.0))
	_voar(caixa.get_center(), clampf(maxf(k, 0.9), MPU_MIN, MPU_MAX))


func _rota_para(lugar: Dictionary) -> void:
	if lugar.is_empty():
		return
	if Gps.tracar_para(lugar):
		_aba = Aba.ROTAS
		_balao = -1
		_enquadrar_rota()
		AudioDirector.tocar_ui(&"celular_ok", -10.0)
	else:
		aviso("Rota apagada", Color.WHITE)
		AudioDirector.tocar_ui(&"clique", -12.0)


func _largar_alfinete(mundo: Vector2) -> void:
	var m3 := Vector3(mundo.x, 0.0, mundo.y)
	var rua := NomesDeRua.rua_perto(m3, 40.0)
	_alfinete = {"categoria": &"marca", "nome": "Alfinete Colocado",
		"endereco": MapaDoIphone._curto(rua) if not rua.is_empty() else "Toque para a rota",
		"mundo": m3, "t": _t}
	_balao = -2
	AudioDirector.tocar_ui(&"celular_tecla", -14.0)


func _alternar_pagina() -> void:
	_curl_alvo = 0.0 if _curl_alvo > 0.0 else 1.0
	_busca_aberta = false
	if _curl_alvo > 0.0:
		_balao = -1
	AudioDirector.tocar_ui(&"clique", -18.0)


func _acao_na_pagina(nome: StringName) -> bool:
	match nome:
		&"esq", &"cima":
			_opcao = posmod(_opcao - 1, OPCOES.size())
		&"dir", &"baixo":
			_opcao = posmod(_opcao + 1, OPCOES.size())
		&"ok":
			_aplicar_opcao(OPCOES[_opcao])
		&"voltar":
			_curl_alvo = 0.0
	return true


func _aplicar_opcao(o: StringName) -> void:
	match o:
		&"largar":
			_curl_alvo = 0.0
			_largar_alfinete(mapa.centro)
		&"transito":
			mapa.transito = not mapa.transito
		&"mapa":
			mapa.estilo = MapaDoIphone.Estilo.MAPA
			_lista = false
			_curl_alvo = 0.0
		&"satelite":
			mapa.estilo = MapaDoIphone.Estilo.SATELITE
			_lista = false
			_curl_alvo = 0.0
		&"hibrido":
			mapa.estilo = MapaDoIphone.Estilo.HIBRIDO
			_lista = false
			_curl_alvo = 0.0
		&"lista":
			_lista = true
			_lista_rolagem = 0.0
			_curl_alvo = 0.0
	AudioDirector.tocar_ui(&"clique", -20.0)


func _acao_na_lista(nome: StringName) -> bool:
	var res := Gps.resultados()
	match nome:
		&"cima":
			Gps.sel = maxi(0, Gps.sel - 1)
		&"baixo":
			Gps.sel = mini(maxi(0, res.size() - 1), Gps.sel + 1)
		&"ok":
			_lista = false
			_escolher(Gps.sel)
		&"voltar":
			_lista = false
	# A linha em foco sempre visivel.
	var y := float(Gps.sel) * 16.0
	_lista_rolagem = clampf(_lista_rolagem, y - _area.size.y + 18.0, y)
	return true


## As teclas do que se pode fazer agora, para a dica do `Celular`.
func dicas() -> Array[String]:
	if _curl_alvo > 0.0:
		return ["[WASD] Opcao", "[E] Escolher", "[R] Fechar"]
	if _lista:
		return ["[W S] Lugar", "[E] Ver no mapa", "[ESC] Mapa"]
	if _busca_aberta:
		return ["[W S] Categoria", "[E] Buscar", "[ESC] Fechar"]
	var saida: Array[String] = []
	if not Gps.resultados().is_empty() and Gps.filtro != 0:
		saida.append("[W S] Lugar")
	saida.append("[A D] Buscar")
	if _balao != -1:
		saida.append("[E] Rota")
	elif Gps.filtro == 0:
		saida.append("[E] Buscar")
	saida.append_array(["[Q] Localizar", "[Z X] Zoom", "[R] Opcoes"])
	return saida


# --- desenho ------------------------------------------------------------------------

func desenhar(visor: Control) -> void:
	v = visor
	var W := largura
	var H := alto_tela
	var nav := Rect2(0.0, BARRA, W, NAV)
	var barra := Rect2(0.0, H - FERRAMENTAS, W, FERRAMENTAS)
	_area = Rect2(0.0, nav.end.y, W, barra.position.y - nav.end.y)
	mapa.area = _area
	if _lista:
		_desenhar_lista()
	else:
		alvo(_area, &"mapa")
		mapa.desenhar(v, f_semi, f_bold)
		_desenhar_rota()
		_desenhar_alfinetes()
		_desenhar_eu()
		_desenhar_balao()
		_desenhar_google()
		_desenhar_bussola()
		if Gps.sem_sinal():
			_faixa(Rect2(_area.position.x + 6.0, _area.position.y + 4.0, _area.size.x - 12.0, 10.0),
				"Sem sinal de GPS - ultima posicao conhecida")
		if _aba == Aba.ROTAS:
			_desenhar_resumo_da_rota()
	if _curl > 0.0:
		_desenhar_pagina()
	_desenhar_nav(nav)
	_desenhar_ferramentas(barra)
	if _busca_aberta:
		_desenhar_busca()
	desenhar_aviso()


func _desenhar_nav(r: Rect2) -> void:
	grad_v(r, NAV_CIMA, NAV_BAIXO)
	v.draw_line(Vector2(0.0, r.position.y + 0.25), Vector2(r.end.x, r.position.y + 0.25),
		Color(1, 1, 1, 0.45), 0.5)
	v.draw_line(Vector2(0.0, r.end.y - 0.25), Vector2(r.end.x, r.end.y - 0.25), Color("2d3e56"), 0.5)
	if _aba == Aba.ROTAS:
		var limpar := Rect2(r.end.x - 34.0, r.position.y + 2.5, 29.0, 10.0)
		var campo := Rect2(5.0, r.position.y + 2.5, limpar.position.x - 9.0, 10.0)
		_campo(campo)
		var destino := String(Gps.destino.get("nome", "")) if not Gps.destino.is_empty() else ""
		var texto := "Local Atual  >  " + (MapaDoIphone._curto(destino) if not destino.is_empty() \
			else "Escolha um lugar")
		t(Vector2(campo.position.x + 5.0, campo.position.y + 7.2), cortar(texto, 5, campo.size.x - 9.0),
			5, Color("1c1f24") if not destino.is_empty() else Color("8b8f96"), f_semi)
		_botao_barra(limpar, "Limpar", Gps.destino.is_empty())
		if not Gps.destino.is_empty():
			alvo(limpar, &"limpar_rota")
		return
	var campo := Rect2(5.0, r.position.y + 2.5, r.size.x - 10.0, 10.0)
	_campo(campo)
	alvo(campo, &"busca")
	# A lupa.
	var lupa := Vector2(campo.position.x + 5.2, campo.position.y + 4.6)
	v.draw_arc(lupa, 1.7, 0.0, TAU, 16, Color("8b8f96"), 0.6, true)
	v.draw_line(lupa + Vector2(1.2, 1.2), lupa + Vector2(2.7, 2.7), Color("8b8f96"), 0.8, true)
	var tem := Gps.filtro != 0
	var texto := MapaDoIphone._curto(String(Gps.FILTROS[Gps.filtro]["nome"])) if tem else "Buscar lugares"
	t(Vector2(campo.position.x + 9.5, campo.position.y + 7.2), texto, 5,
		Color("1c1f24") if tem else Color("8b8f96"), f_semi)
	if tem:
		var x := Vector2(campo.end.x - 5.5, campo.get_center().y)
		v.draw_circle(x, 2.6, Color("b4b8be"))
		v.draw_line(x - Vector2(1.1, 1.1), x + Vector2(1.1, 1.1), Color.WHITE, 0.55, true)
		v.draw_line(x + Vector2(-1.1, 1.1), x + Vector2(1.1, -1.1), Color.WHITE, 0.55, true)
		alvo(Rect2(x - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), &"limpar_busca")
	else:
		# O livrinho dos favoritos, dentro do campo.
		var b := Rect2(campo.end.x - 8.0, campo.position.y + 2.4, 4.2, 5.2)
		arred(b, 0.5, Color("8b8f96"), false, 0.5)
		v.draw_line(Vector2(b.position.x + 1.2, b.position.y), Vector2(b.position.x + 1.2, b.end.y),
			Color("8b8f96"), 0.4)


## O campo branco em capsula do iOS, com a sombra de dentro em cima.
func _campo(r: Rect2) -> void:
	arred(r.grow(0.4), r.size.y * 0.5, Color(0.1, 0.15, 0.25, 0.45))
	arred(r, r.size.y * 0.5, Color.WHITE)
	v.draw_line(Vector2(r.position.x + 3.0, r.position.y + 0.6), Vector2(r.end.x - 3.0, r.position.y + 0.6),
		Color(0, 0, 0, 0.12), 0.8)


func _botao_barra(r: Rect2, texto: String, apagado: bool, ativo := false) -> void:
	var cima := Color("7f93b3") if not ativo else Color("4a8df5")
	var baixo := Color("4d6690") if not ativo else Color("1f5fd6")
	if sob_dedo(r):
		cima = cima.darkened(0.2)
		baixo = baixo.darkened(0.2)
	var pts := AppCelular.cantos(r, 2.0)
	var cores := PackedColorArray()
	for p: Vector2 in pts:
		cores.append(cima.lerp(baixo, (p.y - r.position.y) / r.size.y))
	v.draw_polygon(pts, cores)
	pts.append(pts[0])
	v.draw_polyline(pts, Color(0.1, 0.14, 0.22, 0.8), 0.45, true)
	if not texto.is_empty():
		t(Vector2(r.position.x, r.position.y + 7.0), texto, 5, Color(1, 1, 1, 0.45 if apagado else 1.0),
			f_bold, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _desenhar_ferramentas(r: Rect2) -> void:
	grad_v(r, NAV_CIMA, NAV_BAIXO)
	v.draw_line(Vector2(0.0, r.position.y + 0.25), Vector2(r.end.x, r.position.y + 0.25),
		Color("2d3e56"), 0.5)
	# Localizar.
	var loc := Rect2(5.0, r.position.y + 2.5, 17.0, 10.0)
	_botao_barra(loc, "", false, _seguir != Seguir.NAO)
	alvo(loc, &"localizar")
	var c := loc.get_center()
	if _seguir == Seguir.BUSSOLA:
		# O feixe da bussola.
		v.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, 2.2), c + Vector2(-3.0, -3.0),
			c + Vector2(3.0, -3.0)]), Color(1, 1, 1, 0.55))
		v.draw_circle(c + Vector2(0.0, 1.6), 1.4, Color.WHITE)
	else:
		v.draw_colored_polygon(PackedVector2Array([c + Vector2(3.2, -3.2), c + Vector2(-3.4, -0.3),
			c + Vector2(-0.4, 0.4), c + Vector2(0.3, 3.4)]), Color.WHITE)
	# Buscar | Rotas.
	var seg_w := 72.0
	var seg := Rect2((r.size.x - seg_w) * 0.5, r.position.y + 2.5, seg_w, 10.0)
	for k in 2:
		var metade := Rect2(seg.position.x + float(k) * seg_w * 0.5, seg.position.y, seg_w * 0.5, seg.size.y)
		var sel := (k == 0 and _aba == Aba.BUSCA) or (k == 1 and _aba == Aba.ROTAS)
		var cima := Color("5b6f8f") if sel else Color("93a4bd")
		var baixo := Color("30476e") if sel else Color("61789a")
		v.draw_polygon(PackedVector2Array([metade.position, Vector2(metade.end.x, metade.position.y),
			metade.end, Vector2(metade.position.x, metade.end.y)]),
			PackedColorArray([cima, cima, baixo, baixo]))
		t(Vector2(metade.position.x, metade.position.y + 7.0), ["Buscar", "Rotas"][k], 5,
			Color.WHITE, f_bold, metade.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		alvo(metade, &"aba_busca" if k == 0 else &"aba_rotas")
	arred(seg, 2.0, Color(0.1, 0.14, 0.22, 0.85), false, 0.5)
	v.draw_line(Vector2(seg.get_center().x, seg.position.y), Vector2(seg.get_center().x, seg.end.y),
		Color(0.1, 0.14, 0.22, 0.85), 0.5)
	# A pagina dobrada.
	var pag := Rect2(r.size.x - 22.0, r.position.y + 2.5, 17.0, 10.0)
	_botao_barra(pag, "", false, _curl_alvo > 0.0)
	alvo(pag, &"curl")
	var q := pag.get_center()
	v.draw_colored_polygon(PackedVector2Array([q + Vector2(-4.0, -3.0), q + Vector2(4.0, -3.0),
		q + Vector2(4.0, 0.5), q + Vector2(0.5, 3.0), q + Vector2(-4.0, 3.0)]), Color(1, 1, 1, 0.9))
	v.draw_colored_polygon(PackedVector2Array([q + Vector2(4.0, 0.5), q + Vector2(0.5, 3.0),
		q + Vector2(1.2, 0.4)]), Color("9aa6b8"))


func _faixa(r: Rect2, texto: String) -> void:
	arred(r, 2.5, Color(0.08, 0.1, 0.14, 0.78))
	t(Vector2(r.position.x, r.position.y + 6.6), texto, 5, Color.WHITE, f_semi, r.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)


# --- por cima do mapa ---------------------------------------------------------------

func _desenhar_rota() -> void:
	if Gps.rota.size() < 2:
		return
	var pts := PackedVector2Array()
	var m := mapa.xf()
	for q: Vector2 in Gps.rota:
		pts.append(m * q)
	v.draw_polyline(pts, ROTA_HALO, 3.6, true)
	v.draw_polyline(pts, ROTA, 2.5, true)


func _desenhar_alfinetes() -> void:
	var m := mapa.xf()
	for p: Dictionary in Missoes.pinos():
		_pino(m * (p["pos"] as Vector2), PINO_VERDE.darkened(0.15), 1.0)
	var res := Gps.resultados()
	if Gps.filtro != 0:
		for i in res.size():
			var mundo: Vector3 = res[i]["mundo"]
			var tela := m * Vector2(mundo.x, mundo.z)
			if not _area.grow(10.0).has_point(tela):
				continue
			var queda := 1.0
			if i < _quedas.size():
				queda = clampf((_t - _quedas[i]) / 0.38, 0.0, 1.0)
			_pino(tela, PINO, queda)
			alvo(Rect2(tela - Vector2(4.0, 11.0), Vector2(8.0, 12.0)), ["pino", i])
	if not Gps.destino.is_empty():
		var d: Vector3 = Gps.destino["mundo"]
		_pino(m * Vector2(d.x, d.z), PINO, 1.0)
	if not _alfinete.is_empty():
		var a: Vector3 = _alfinete["mundo"]
		var tela := m * Vector2(a.x, a.z)
		_pino(tela, PINO_ROXO, clampf((_t - float(_alfinete["t"])) / 0.38, 0.0, 1.0))
		alvo(Rect2(tela - Vector2(4.0, 11.0), Vector2(8.0, 12.0)), &"alfinete")


## O alfinete do iOS: a cabeca de vidro na ponta de uma agulha, a sombra deitada
## para a direita no chao, e a queda com um quique ao chegar.
func _pino(p: Vector2, cor: Color, queda: float) -> void:
	if queda <= 0.0:
		return
	var e := _quique(queda)
	var alto := -(1.0 - e) * 34.0
	var agulha := 5.2
	var raio := 2.1
	# Sombra no chao: cresce enquanto o alfinete desce.
	var s := clampf(queda * 1.4 - 0.2, 0.0, 1.0)
	v.draw_line(p, p + Vector2(4.4, -3.0), Color(0, 0, 0, 0.28 * s), 0.7, true)
	v.draw_circle(p + Vector2(5.4, -3.8), raio * 0.9, Color(0, 0, 0, 0.18 * s))
	var base := p + Vector2(0.0, alto)
	var cabeca := base + Vector2(0.0, -agulha - raio * 0.6)
	v.draw_line(base, cabeca, Color("7d8185"), 0.55, true)
	v.draw_circle(cabeca, raio, cor.darkened(0.3))
	v.draw_circle(cabeca + Vector2(-0.15, -0.15), raio * 0.86, cor)
	v.draw_circle(cabeca + Vector2(-0.7, -0.7), raio * 0.38, Color(1, 1, 1, 0.75))


static func _quique(x: float) -> float:
	if x < 0.72:
		var k := x / 0.72
		return k * k
	var k := (x - 0.72) / 0.28
	return 1.0 - sin(k * PI) * 0.08


func _desenhar_eu() -> void:
	var p := Gps.posicao()
	var c := mapa.para_tela(Vector2(p.x, p.z))
	if not _area.grow(20.0).has_point(c):
		return
	var sem := Gps.sem_sinal()
	var azul := Color("8f99a6") if sem else AZUL
	var precisao := maxf(4.5, (60.0 if sem else 12.0) / mapa.mpu)
	v.draw_circle(c, precisao, Color(azul, 0.13))
	v.draw_arc(c, precisao, 0.0, TAU, 40, Color(azul, 0.35), 0.4, true)
	if not sem:
		var k := fmod(_t, 2.2) / 2.2
		v.draw_arc(c, lerpf(2.5, precisao * 1.15, k), 0.0, TAU, 40, Color(azul, 0.45 * (1.0 - k)),
			0.6, true)
		# O feixe do rumo: forte na bussola, um sussurro nos outros modos.
		var f := Vector2(-sin(Gps.rumo()), -cos(Gps.rumo())).rotated(mapa.giro)
		var lado := Vector2(-f.y, f.x)
		var forca := 0.42 if _seguir == Seguir.BUSSOLA else 0.2
		var ponta := 15.0
		v.draw_polygon(PackedVector2Array([c, c + f * ponta + lado * ponta * 0.52,
			c + f * ponta - lado * ponta * 0.52]),
			PackedColorArray([Color(azul, forca), Color(azul, 0.0), Color(azul, 0.0)]))
	v.draw_circle(c + Vector2(0.25, 0.35), 3.2, Color(0, 0, 0, 0.18))
	v.draw_circle(c, 3.1, Color.WHITE)
	v.draw_circle(c, 2.25, azul.darkened(0.12))
	v.draw_circle(c + Vector2(-0.4, -0.5), 1.4, azul.lightened(0.25))


## O balao do alfinete: preto de vidro, titulo, rua e distancia, e o botao azul
## de rota a esquerda.
func _desenhar_balao() -> void:
	var lugar: Dictionary = {}
	var id: Variant = null
	if _balao >= 0 and _balao < Gps.resultados().size() and Gps.filtro != 0:
		lugar = Gps.resultados()[_balao]
		id = ["rota", _balao]
	elif _balao == -2 and not _alfinete.is_empty():
		lugar = _alfinete
		id = &"rota_alfinete"
	if lugar.is_empty():
		return
	var m3: Vector3 = lugar["mundo"]
	var ponta := mapa.para_tela(Vector2(m3.x, m3.z)) + Vector2(0.0, -10.0)
	var de := Gps.posicao()
	var dist := Vector2(de.x, de.z).distance_to(Vector2(m3.x, m3.z))
	var titulo := MapaDoIphone._curto(String(lugar["nome"]))
	var sub := "%s  ·  %s %s" % [MapaDoIphone._curto(String(lugar.get("endereco", ""))),
		Gps.distancia_texto(dist), Gps.bussola_texto(de, m3)]
	var larg := clampf(maxf(w(titulo, 6, f_bold), w(sub, 4, f_semi)) + 30.0, 48.0, _area.size.x - 10.0)
	var r := Rect2(ponta.x - larg * 0.5, ponta.y - 19.0, larg, 16.0)
	r.position.x = clampf(r.position.x, _area.position.x + 4.0, _area.end.x - larg - 4.0)
	r.position.y = maxf(r.position.y, _area.position.y + 2.0)
	var cima := Color(0.30, 0.30, 0.32, 0.93)
	var baixo := Color(0.05, 0.05, 0.06, 0.93)
	if sob_dedo(r):
		cima = cima.lightened(0.1)
	arred(r.grow(0.6), 4.0, Color(0, 0, 0, 0.3))
	var pts := AppCelular.cantos(r, 3.6)
	var cores := PackedColorArray()
	for q: Vector2 in pts:
		cores.append(cima.lerp(baixo, (q.y - r.position.y) / r.size.y))
	v.draw_polygon(pts, cores)
	var bico := clampf(ponta.x, r.position.x + 5.0, r.end.x - 5.0)
	v.draw_colored_polygon(PackedVector2Array([Vector2(bico - 3.0, r.end.y - 0.3),
		Vector2(bico + 3.0, r.end.y - 0.3), Vector2(bico, r.end.y + 3.5)]), baixo)
	arred(Rect2(r.position + Vector2(0.8, 0.8), Vector2(r.size.x - 1.6, r.size.y * 0.45)), 3.0,
		Color(1, 1, 1, 0.1))
	pts.append(pts[0])
	v.draw_polyline(pts, Color(1, 1, 1, 0.35), 0.4, true)
	# O botao de rota: a seta que dobra, em azul.
	var b := Rect2(r.position.x + 2.5, r.position.y + 2.5, 11.0, 11.0)
	var bp := AppCelular.cantos(b, 2.0)
	var bc := PackedColorArray()
	for q: Vector2 in bp:
		bc.append(Color("4d97f7").lerp(Color("1a5bd2"), (q.y - b.position.y) / b.size.y))
	v.draw_polygon(bp, bc)
	var o := b.get_center()
	v.draw_polyline(PackedVector2Array([o + Vector2(-2.0, 3.2), o + Vector2(-2.0, -0.6),
		o + Vector2(1.5, -0.6)]), Color.WHITE, 0.9, true)
	v.draw_colored_polygon(PackedVector2Array([o + Vector2(1.2, -2.6), o + Vector2(3.4, -0.6),
		o + Vector2(1.2, 1.4)]), Color.WHITE)
	t(Vector2(r.position.x + 16.0, r.position.y + 7.2), cortar(titulo, 6, r.size.x - 26.0, f_bold), 6,
		Color.WHITE, f_bold)
	t(Vector2(r.position.x + 16.0, r.position.y + 13.0), cortar(sub, 4, r.size.x - 26.0, f_semi), 4,
		Color(0.82, 0.83, 0.85), f_semi)
	# A setinha azul de detalhe a direita.
	var d := Vector2(r.end.x - 5.5, r.get_center().y)
	v.draw_circle(d, 3.2, Color.WHITE)
	v.draw_circle(d, 2.7, Color("2b74e8"))
	v.draw_polyline(PackedVector2Array([d + Vector2(-0.6, -1.3), d + Vector2(0.8, 0.0),
		d + Vector2(-0.6, 1.3)]), Color.WHITE, 0.6, true)
	alvo(r, id)


## "Google" no canto do mapa, nas cores dele: o mapa do iPhone era do Google, e
## o logo estava sempre la.
func _desenhar_google() -> void:
	var cores := [Color("3369e8"), Color("d50f25"), Color("eeb211"), Color("3369e8"),
		Color("009925"), Color("d50f25")]
	var x := _area.position.x + 4.0
	var y := _area.end.y - 3.0
	var sat := mapa.estilo != MapaDoIphone.Estilo.MAPA
	var letras := "Google"
	for i in letras.length():
		var l := letras.substr(i, 1)
		v.draw_string_outline(f_bold, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 2,
			Color(1, 1, 1, 0.85) if not sat else Color(0, 0, 0, 0.5))
		v.draw_string(f_bold, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
			cores[i] if not sat else Color.WHITE)
		x += f_bold.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x


## A rosa pequena no canto, so com o mapa girado: diz onde ficou o norte.
func _desenhar_bussola() -> void:
	if absf(wrapf(mapa.giro, -PI, PI)) < 0.03:
		return
	var c := Vector2(_area.end.x - 9.0, _area.position.y + 9.0)
	v.draw_circle(c, 5.6, Color(0, 0, 0, 0.35))
	v.draw_circle(c, 5.0, Color(1, 1, 1, 0.92))
	var n := Vector2(0.0, -1.0).rotated(mapa.giro)
	var lado := Vector2(-n.y, n.x)
	v.draw_colored_polygon(PackedVector2Array([c + n * 3.8, c + lado * 1.2, c - lado * 1.2]),
		Color("e0302a"))
	v.draw_colored_polygon(PackedVector2Array([c - n * 3.8, c + lado * 1.2, c - lado * 1.2]),
		Color("8b8f96"))


func _desenhar_resumo_da_rota() -> void:
	var r := Rect2(_area.position.x + 6.0, _area.position.y + 4.0, _area.size.x - 12.0, 15.0)
	if Gps.destino.is_empty():
		_faixa(Rect2(r.position, Vector2(r.size.x, 10.0)), "Toque num alfinete e na seta azul")
		return
	var de := Gps.posicao()
	var total := Gps.comprimento_da_rota()
	if total <= 0.0:
		var d: Vector3 = Gps.destino["mundo"]
		total = Vector2(de.x, de.z).distance_to(Vector2(d.x, d.z))
	arred(r, 3.0, Color(0.08, 0.1, 0.14, 0.82))
	var a_pe := ceili(total / A_PE / 60.0)
	var carro := ceili(total / DE_CARRO / 60.0)
	t(Vector2(r.position.x + 5.0, r.position.y + 6.5), "%s  ·  %d min a pe  ·  %d min de carro" % [
		Gps.distancia_texto(total), a_pe, carro], 5, Color.WHITE, f_bold)
	var prox := HudNavegacao.proxima(Gps.rota, Vector2(de.x, de.z))
	var frase := ""
	if not prox.is_empty():
		var tipo: StringName = prox.get("tipo", &"siga")
		frase = "%s em %s" % [HudNavegacao.verbo(tipo), Gps.distancia_texto(float(prox.get("dist", 0.0)))] \
			if tipo != &"chegada" else "Chegando em %s" % Gps.distancia_texto(float(prox.get("dist", 0.0)))
	t(Vector2(r.position.x + 5.0, r.position.y + 12.5),
		cortar(frase if not frase.is_empty() else MapaDoIphone._curto(String(Gps.destino.get("endereco", ""))),
			4, r.size.x - 10.0, f_semi), 4, Color(0.8, 0.84, 0.9), f_semi)


# --- lista de busca -----------------------------------------------------------------

func _desenhar_busca() -> void:
	var r := Rect2(_area.position.x, _area.position.y, _area.size.x, _area.size.y)
	# Fora da lista, um veu: tocar nele fecha.
	v.draw_rect(r, Color(0, 0, 0, 0.35))
	alvo(r, &"busca_fora")
	var linha := 12.5
	var n := Gps.FILTROS.size() - 1
	var tabela := Rect2(r.position.x, r.position.y, r.size.x, minf(r.size.y, linha * float(n)))
	v.draw_rect(tabela, Color.WHITE)
	for k in n:
		var i := k + 1
		var y := tabela.position.y + float(k) * linha
		var lr := Rect2(0.0, y, r.size.x, linha)
		var sel := (foco_visivel and i == _busca_sel) or sob_dedo(lr)
		if sel:
			grad_v(lr, SEL_CIMA, SEL_BAIXO)
		var tinta := Color.WHITE if sel else Color("1c1f24")
		var cat: StringName = Gps.FILTROS[i]["id"]
		_icone_categoria(Vector2(8.0, y + linha * 0.5), cat, sel)
		t(Vector2(16.0, y + 8.2), MapaDoIphone._curto(String(Gps.FILTROS[i]["nome"])), 6, tinta, f_bold)
		var qtd := Gps.contagem(i)
		t(Vector2(0.0, y + 8.0), "%d por perto" % qtd if qtd > 0 else "nenhum", 5,
			Color(1, 1, 1, 0.85) if sel else Color("8b8f96"), f_semi, r.size.x - 6.0,
			HORIZONTAL_ALIGNMENT_RIGHT)
		if k < n - 1:
			v.draw_line(Vector2(16.0, y + linha), Vector2(r.size.x, y + linha), Color("e0e0e0"), 0.4)
		alvo(lr, ["cat", i])


## O desenho de cada categoria, num quadradinho arredondado.
func _icone_categoria(c: Vector2, cat: StringName, claro: bool) -> void:
	var cores := {&"casa_fumaca": Color("3f9b3a"), &"mercado": Color("e3822a"), &"bar": Color("b0452f"),
		&"casa": Color("6f7d8c"), &"apartamento": Color("5a6aa8"), &"parque": Color("3c8f4f"),
		&"telefone": Color("2f78c9")}
	var cor: Color = cores.get(cat, Color("8b8f96"))
	var r := Rect2(c - Vector2(4.0, 4.0), Vector2(8.0, 8.0))
	arred(r, 1.8, Color.WHITE if claro else cor)
	var tinta := cor if claro else Color.WHITE
	match cat:
		&"casa_fumaca":
			AppCelular.folha(v, c + Vector2(0.0, -0.6), 3.0, tinta)
		&"mercado":
			v.draw_polyline(PackedVector2Array([c + Vector2(-3.0, -2.2), c + Vector2(-2.0, -2.2),
				c + Vector2(-1.1, 1.2), c + Vector2(2.4, 1.2), c + Vector2(3.0, -1.2), c + Vector2(-1.7, -1.2)]),
				tinta, 0.6, true)
			v.draw_circle(c + Vector2(-0.6, 2.4), 0.6, tinta)
			v.draw_circle(c + Vector2(2.0, 2.4), 0.6, tinta)
		&"bar":
			v.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.6, -2.4), c + Vector2(2.6, -2.4),
				c + Vector2(0.0, 0.6)]), tinta)
			v.draw_line(c + Vector2(0.0, 0.6), c + Vector2(0.0, 2.4), tinta, 0.6)
			v.draw_line(c + Vector2(-1.4, 2.6), c + Vector2(1.4, 2.6), tinta, 0.6)
		&"casa":
			v.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -3.0), c + Vector2(3.0, -0.4),
				c + Vector2(-3.0, -0.4)]), tinta)
			v.draw_rect(Rect2(c + Vector2(-2.1, -0.4), Vector2(4.2, 3.0)), tinta)
		&"apartamento":
			v.draw_rect(Rect2(c + Vector2(-2.0, -3.0), Vector2(4.0, 6.0)), tinta)
			for yy in 3:
				v.draw_rect(Rect2(c + Vector2(-1.2, -2.2 + float(yy) * 1.7), Vector2(0.8, 0.8)), cor if not claro else Color.WHITE)
				v.draw_rect(Rect2(c + Vector2(0.4, -2.2 + float(yy) * 1.7), Vector2(0.8, 0.8)), cor if not claro else Color.WHITE)
		&"parque":
			v.draw_circle(c + Vector2(0.0, -0.8), 2.3, tinta)
			v.draw_line(c + Vector2(0.0, 0.8), c + Vector2(0.0, 3.0), tinta, 0.8)
		&"telefone":
			v.draw_rect(Rect2(c + Vector2(-1.6, -3.0), Vector2(3.2, 6.0)), tinta)
			v.draw_rect(Rect2(c + Vector2(-1.0, -2.2), Vector2(2.0, 2.2)), cor if not claro else Color.WHITE)


# --- a pagina dobrada ---------------------------------------------------------------

## A pagina que dobra no canto de baixo e mostra as opcoes por baixo do mapa.
## A dobra e uma reta que sobe do canto; o que fica do lado do canto e o fundo
## de linho com as opcoes, e a aba dobrada e o espelho dele pela reta.
func _desenhar_pagina() -> void:
	var e := _curl * _curl * (3.0 - 2.0 * _curl)
	var canto := _area.end
	var n := Vector2(-0.55, -1.9).normalized()
	var aberto := Vector2(_area.position.x + _area.size.x * 0.55, _area.position.y + _area.size.y * 0.36)
	var f := canto.lerp(aberto, e)
	var retangulo := PackedVector2Array([_area.position, Vector2(_area.end.x, _area.position.y),
		_area.end, Vector2(_area.position.x, _area.end.y)])
	var fundo := _cortar(retangulo, f, n)
	if fundo.size() < 3:
		return
	# O fundo de linho.
	v.draw_colored_polygon(fundo, Color("d6d9de"))
	var passo := 2.0
	var y := _area.position.y
	while y < _area.end.y:
		var linha := _cortar(PackedVector2Array([Vector2(_area.position.x, y), Vector2(_area.end.x, y),
			Vector2(_area.end.x, y + 0.3), Vector2(_area.position.x, y + 0.3)]), f, n)
		if linha.size() >= 3:
			v.draw_colored_polygon(linha, Color(1, 1, 1, 0.25))
		y += passo
	if _curl >= 0.98:
		_desenhar_opcoes()
	# Tocar no mapa que sobrou fecha a pagina.
	alvo(_area, &"pagina_fora")
	if _curl >= 0.98:
		_registrar_opcoes()
	# A aba dobrada: o espelho do fundo pela reta, cortado na area.
	var aba := PackedVector2Array()
	for q: Vector2 in fundo:
		aba.append(q - 2.0 * (q - f).dot(n) * n)
	# A aba e so a faixa da pagina que enrola perto da dobra; alem dela o mapa
	# continua a vista, como no aparelho.
	aba = _cortar(aba, f + n * ABA_FUNDO, n)
	for plano: Array in [[_area.position, Vector2(1, 0)], [_area.position, Vector2(0, 1)],
			[_area.end, Vector2(-1, 0)], [_area.end, Vector2(0, -1)]]:
		aba = _cortar(aba, plano[0], -(plano[1] as Vector2))
	if aba.size() < 3:
		return
	var sombra := PackedVector2Array()
	for q: Vector2 in aba:
		sombra.append(q + n * -1.2 + Vector2(1.0, 1.2))
	v.draw_colored_polygon(sombra, Color(0, 0, 0, 0.22))
	var longe := 0.001
	for q: Vector2 in aba:
		longe = maxf(longe, absf((q - f).dot(n)))
	var cores := PackedColorArray()
	for q: Vector2 in aba:
		var d := absf((q - f).dot(n)) / longe
		cores.append(Color("c3c7cd").lerp(Color("f6f6f4"), sqrt(d)))
	v.draw_polygon(aba, cores)


## Corta o poligono convexo pelo semiplano (q - p) . n <= 0.
static func _cortar(poli: PackedVector2Array, p: Vector2, n: Vector2) -> PackedVector2Array:
	var saida := PackedVector2Array()
	var k := poli.size()
	for i in k:
		var a := poli[i]
		var b := poli[(i + 1) % k]
		var da := (a - p).dot(n)
		var db := (b - p).dot(n)
		if da <= 0.0:
			saida.append(a)
		if (da <= 0.0) != (db <= 0.0):
			saida.append(a.lerp(b, da / (da - db)))
	# Sem pontos repetidos nem lasca sem area: no comeco da dobra (a reta ainda
	# rente ao canto) o fundo e as listras do linho saiam triangulos de area
	# quase zero, e o motor recusava o poligono no meio da animacao.
	var limpa := PackedVector2Array()
	for q: Vector2 in saida:
		if limpa.is_empty() or q.distance_squared_to(limpa[limpa.size() - 1]) > 1e-6:
			limpa.append(q)
	if limpa.size() > 1 and limpa[0].distance_squared_to(limpa[limpa.size() - 1]) <= 1e-6:
		limpa.remove_at(limpa.size() - 1)
	if limpa.size() < 3:
		return PackedVector2Array()
	var area := 0.0
	for i in limpa.size():
		area += limpa[i].cross(limpa[(i + 1) % limpa.size()])
	if absf(area) < 0.02:
		return PackedVector2Array()
	return limpa


func _rect_opcao(i: int) -> Rect2:
	var base := _area.end.y - 6.0
	var W := _area.size.x
	if i < 2:
		var larg := (W - 30.0) * 0.5
		return Rect2(10.0 + float(i) * (larg + 10.0), base - 30.0, larg, 11.0)
	var seg := W - 20.0
	var q := seg / 4.0
	return Rect2(10.0 + float(i - 2) * q, base - 12.0, q, 11.0)


func _desenhar_opcoes() -> void:
	for i in 2:
		var r := _rect_opcao(i)
		var foco := (foco_visivel and _opcao == i) or sob_dedo(r)
		arred(r.grow(0.4), 3.0, Color(0, 0, 0, 0.25))
		arred(r, 3.0, Color("e9ecf1") if foco else Color.WHITE)
		var texto := "Largar Alfinete" if i == 0 else ("Ocultar Transito" if mapa.transito else "Mostrar Transito")
		t(Vector2(r.position.x, r.position.y + 7.4), texto, 5, Color("2c4f8c"), f_bold, r.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		if foco and foco_visivel:
			arred(r.grow(0.8), 3.4, Color(SEL_CIMA, 0.9), false, 0.6)
	var nomes := ["Mapa", "Satelite", "Hibrido", "Lista"]
	for k in 4:
		var i := k + 2
		var r := _rect_opcao(i)
		var escolhido := (k == 0 and mapa.estilo == MapaDoIphone.Estilo.MAPA and not _lista) \
			or (k == 1 and mapa.estilo == MapaDoIphone.Estilo.SATELITE and not _lista) \
			or (k == 2 and mapa.estilo == MapaDoIphone.Estilo.HIBRIDO and not _lista) \
			or (k == 3 and _lista)
		var cima := Color("5b6f8f") if escolhido else Color("f4f5f7")
		var baixo := Color("30476e") if escolhido else Color("d9dde3")
		v.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]), PackedColorArray([cima, cima, baixo, baixo]))
		v.draw_rect(r, Color("8d96a3"), false, 0.4)
		t(Vector2(r.position.x, r.position.y + 7.4), nomes[k], 5,
			Color.WHITE if escolhido else Color("4a5566"), f_bold, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if foco_visivel and _opcao == i:
			v.draw_rect(r.grow(0.6), Color(SEL_CIMA, 0.95), false, 0.6)


func _registrar_opcoes() -> void:
	for i in OPCOES.size():
		alvo(_rect_opcao(i), ["opcao", i])


# --- a lista de resultados ----------------------------------------------------------

func _desenhar_lista() -> void:
	v.draw_rect(_area, Color.WHITE)
	var res := Gps.resultados()
	if Gps.filtro == 0 or res.is_empty():
		t(Vector2(0.0, _area.get_center().y), "Busque uma categoria para ver a lista", 6,
			Color("8b8f96"), f_semi, _area.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		alvo(_area, &"fechar_lista")
		return
	var linha := 16.0
	var maximo := maxf(0.0, float(res.size()) * linha - _area.size.y)
	_lista_rolagem = clampf(_lista_rolagem, 0.0, maximo)
	var de := Gps.posicao()
	for i in res.size():
		var y := _area.position.y + float(i) * linha - _lista_rolagem
		if y + linha < _area.position.y or y > _area.end.y:
			continue
		var lr := Rect2(0.0, y, _area.size.x, linha)
		var sel := (foco_visivel and i == Gps.sel) or sob_dedo(lr)
		if sel:
			grad_v(lr, SEL_CIMA, SEL_BAIXO)
		var lugar: Dictionary = res[i]
		var tinta := Color.WHITE if sel else Color("1c1f24")
		_icone_categoria(Vector2(9.0, y + linha * 0.5), lugar["categoria"], sel)
		t(Vector2(18.0, y + 7.0), MapaDoIphone._curto(String(lugar["nome"])), 6, tinta, f_bold)
		t(Vector2(18.0, y + 13.0), MapaDoIphone._curto(String(lugar["endereco"])), 4,
			Color(1, 1, 1, 0.85) if sel else Color("8b8f96"), f_semi)
		var m3: Vector3 = lugar["mundo"]
		t(Vector2(0.0, y + 9.5), "%s %s" % [Gps.distancia_texto(float(lugar["distancia"])),
			Gps.bussola_texto(de, m3)], 5, Color(1, 1, 1, 0.9) if sel else Color("2c4f8c"), f_semi,
			_area.size.x - 6.0, HORIZONTAL_ALIGNMENT_RIGHT)
		v.draw_line(Vector2(18.0, y + linha), Vector2(_area.size.x, y + linha), Color("e0e0e0"), 0.4)
		alvo(lr, ["linha", i])

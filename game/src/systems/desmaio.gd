## O que acontece quando a vida chega a zero.
##
## A decisao, por escrito (12/09/2026)
## -----------------------------------
## **Nao ha tela de GAME OVER.** O jogador desmaia e acorda horas depois, no
## ultimo orelhao em que salvou — e a partida continua exatamente de onde estava:
## mesmos itens, mesmo mundo, mesma missao. O que ele perde e TEMPO.
##
## Por que assim, e nao "volta no ultimo save"
## -------------------------------------------
## Porque voltar ao save desfaz o mundo, e este jogo tem `WorldState` justamente
## para o mundo NAO se consertar sozinho quando o jogador da meia volta
## (`world_state.gd:1`). Uma tela de morte que recarrega o arquivo desmente essa
## regra toda vez que aparece.
##
## E porque tempo agora e uma moeda que existe. `Relogio` nasceu na Fase 2 da UI
## e ate aqui era so um numero no rodape; adiantar o relogio em quatro horas e
## uma punicao real num jogo que acontece numa noite so, e nao custa nenhuma
## tela nova.
##
## Por que o orelhao
## -----------------
## Porque `PontoDeSave` ja existe, ja tem nome de lugar e a varredura do GPS
## conta 51 deles em doze quadras. Narrativamente fecha: quem desmaia na rua
## acorda onde alguem o arrastou, e o telefone publico da esquina e o lugar mais
## proximo de "alguem me achou" que este mapa tem.
##
## Camada 200
## ----------
## Acima do pos-processamento (150) e acima da excecao do menu de sistema (160).
## E a unica coisa no jogo que pode: um apagao TEM de cobrir a tela inteira,
## inclusive a interface. Se ficasse na 100, a vinheta o deixaria preto no canto
## e cinza no meio — e o clarao, o cartao de missao e a faixa continuariam
## visiveis por cima do desmaio. UI-BIBLE secao 3.
##
## A arvore NAO pausa
## ------------------
## `PROCESS_MODE_ALWAYS` existe para o apagao continuar se a prancha tiver
## pausado a arvore. O mundo em si segue rodando atras do preto de proposito:
## o ChunkManager precisa carregar o quarteirao do orelhao enquanto a tela esta
## preta, senao o jogador acordaria no vazio e os predios nasceriam na frente
## dele. Quem trava e o jogador, nao o streaming.
class_name Desmaio
extends CanvasLayer

## Camada do apagao. Ver o cabecalho: e a excecao, e esta e a justificativa
## escrita que a UI-BIBLE exige.
const CAMADA := UiEstilo.CAMADA_APAGAO

## Quanto tempo de jogo se perde. Sorteado: "quatro horas exatas toda vez" e um
## numero que o jogador decora e passa a contar com ele.
const HORAS_PERDIDAS := Vector2(3.0, 5.0)

## Com quanta vida ele acorda. Nao e cheia: acordar novo em folha apaga a
## consequencia, e a bandagem passa a nao servir para nada.
const VIDA_AO_ACORDAR := 45

const T_APAGAR := 1.6
const T_ESCURO := 2.2
const T_ACORDAR := 2.4
## Depois de acordar, o golpe nao pega. Sem isso, quem nunca salvou acorda no
## mesmo chao em que caiu e o segundo desmaio encosta no primeiro.
const T_PROTECAO := 2.5

signal desmaiou()
signal acordou(onde: String)

## Sem espera. O teste de horror liga isto para afirmar a consequencia sem
## gastar os seis segundos da cortina — a cortina e apresentacao, a prova e o
## teleporte, o relogio e a vida.
var instantaneo: bool = false

var _preto: ColorRect
var _texto: Label
var _caindo: bool = false
var _protecao: float = 0.0
var _ultimo_ponto: Vector3 = Vector3.INF
var _ultimo_nome: String = ""


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"desmaio")
	_montar()
	Inventario.vida_mudou.connect(_ao_mudar_vida)
	SaveGame.salvou.connect(_ao_lembrar_do_save)
	SaveGame.carregou.connect(_ao_lembrar_do_save)


func _process(delta: float) -> void:
	if _protecao > 0.0:
		_protecao = maxf(0.0, _protecao - delta)


func _montar() -> void:
	_preto = ColorRect.new()
	_preto.name = "Apagao"
	_preto.color = Color(0, 0, 0, 0)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preto)
	# Tamanho na mao: CanvasLayer nao e Control, FULL_RECT ancora contra zero
	# e o preto nao cobre nada. Foi o que a primeira captura mostrou — o aviso
	# no canto e o mundo inteiro atras.
	_preto.position = Vector2.ZERO
	_preto.size = UiEstilo.TELA

	_texto = Label.new()
	_texto.name = "Aviso"
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.add_theme_color_override(&"font_color", Color(0.78, 0.74, 0.64))
	var fonte := UiEstilo.FONTE_P
	if ResourceLoader.exists(fonte):
		UiEstilo.aplicar(_texto, load(fonte))
	_preto.add_child(_texto)
	_texto.position = Vector2.ZERO
	_texto.size = UiEstilo.TELA
	_texto.modulate.a = 0.0


## Quem chama guarda onde o jogador salvou pela ultima vez. Sem isso o desmaio
## teria de varrer a cena atras de um orelhao no meio de um apagao, com os
## chunks em volta ja descarregados.
func lembrar_ponto(onde: Vector3, nome: String) -> void:
	_ultimo_ponto = onde
	_ultimo_nome = nome


func esta_indisponivel() -> bool:
	return _caindo or _protecao > 0.0


func _ao_lembrar_do_save(espaco: int) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return
	var r := SaveGame.resumo(espaco)
	lembrar_ponto(jogador.global_position, str(r.get("local", "")))


func _ao_mudar_vida(atual: int, _maximo: int) -> void:
	if atual > 0 or _caindo:
		return
	desmaiar()


func desmaiar() -> void:
	if _caindo:
		return
	_caindo = true
	desmaiou.emit()
	_correr()


func _correr() -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if not instantaneo:
		if jogador != null and jogador.has_method("travar"):
			jogador.call("travar", true)
		AudioDirector.tocar_ui(&"ofegante", -3.0)
		var t := create_tween()
		t.tween_property(_preto, "color:a", 1.0, T_APAGAR)
		await t.finished
	else:
		_preto.color.a = 1.0

	# So agora o mundo se mexe: teleporte e relogio acontecem atras do preto,
	# senao o jogador ve o proprio corpo saltar pela rua.
	var onde := _aplicar(jogador)

	if instantaneo:
		_preto.color.a = 0.0
		_texto.modulate.a = 0.0
		_protecao = T_PROTECAO
		_caindo = false
		acordou.emit(onde)
		return

	var hora := WorldState.relogio.texto()
	_texto.text = "Voce acordou em %s.\n%s" % [onde.to_upper(), hora]
	var t2 := create_tween()
	t2.tween_property(_texto, "modulate:a", 1.0, 0.5)
	t2.tween_interval(T_ESCURO)
	t2.tween_property(_texto, "modulate:a", 0.0, 0.4)
	t2.parallel().tween_property(_preto, "color:a", 0.0, T_ACORDAR)
	await t2.finished

	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", false)
	_protecao = T_PROTECAO
	_caindo = false
	acordou.emit(onde)


func _aplicar(jogador: Node3D) -> String:
	# As horas perdidas sao do solo. Em rede o relogio da cidade e de todo mundo:
	# um jogador desmaiando mandaria a madrugada dos amigos para o amanhecer (plano
	# multiplayer 08 secao 3). Ele acorda no mesmo ponto, na mesma hora deles.
	if not Sessao.em_rede():
		var horas := randf_range(HORAS_PERDIDAS.x, HORAS_PERDIDAS.y)
		WorldState.relogio.definir_minutos(
				WorldState.relogio.minutos() + int(horas * 60.0))
	_levar(jogador)
	_dispersar()
	Inventario.vida = VIDA_AO_ACORDAR
	Inventario.vida_mudou.emit(Inventario.vida, Inventario.vida_maxima)
	return _ultimo_nome if not _ultimo_nome.is_empty() else "algum lugar"


## Leva o jogador ao ultimo orelhao. Sem orelhao lembrado ele acorda onde caiu —
## que e pior de proposito: quem nunca salvou acorda no mesmo lugar em que
## desmaiou, e aprende para que serve o telefone da esquina.
##
## A posicao lembrada e a do JOGADOR na hora do save, nao a do poste: ele ja
## estava na calcada na frente do telefone. Somar outro deslocamento o enfiaria
## na parede do outro lado da rua.
func _levar(jogador: Node3D) -> void:
	if jogador == null or not _ultimo_ponto.is_finite():
		return
	jogador.global_position = _ultimo_ponto + Vector3(0.0, 0.05, 0.0)
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	# Quem ve este jogador de outra maquina corta seco para o orelhao, em vez de
	# ve-lo deslizar pela cidade; o servidor nao conta como velocidade.
	Sessao.anunciar_teletransporte()


## Tres, cinco horas depois, a coisa nao continua em cima dele. Volta para o
## ponto de onde patrulhava e esquece o rastro.
func _dispersar() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"inimigo"):
		if n.has_method("dispersar"):
			n.call("dispersar")

## O processo do servidor dedicado. Cena principal alternativa, sem cidade, sem
## camera, sem menu:
##
##     Godot --headless --path game res://scenes/net/servidor_dedicado.tscn -- --porta=24567
##
## Tudo o que ele faz de rede e a Sessao em modo DEDICADO; este no so le a
## configuracao, sobe, escreve o estado no console e sabe encerrar. Separar a
## cena e o que deixa o dedicado nascer sem tocar em cidade.gd: a cidade monta
## chunk, multidao, transito, HUD e abertura, e um servidor que so repassa
## estado nao precisa de nenhum deles (ainda — plano 18 secao 5 diz quando
## passa a precisar do chao).
##
## Plano: MULTIPLAYER/PLANO/18_SERVIDOR_DEDICADO.md.
class_name ServidorDedicado
extends Node

## Linha de estado no console, em segundos.
const INTERVALO_ESTADO := 60.0
## Teto de quadros. Headless nao tem vsync: sem teto, o laco gira a 100% de um
## nucleo repassando pacote de 20 Hz. 60 da tres voltas por tick, que e o que
## basta para o pacote que chega nao esperar mais que 17 ms na fila.
const QUADROS := 60

var _config: ConfigServidor
var _t := 0.0
var _acc_estado := 0.0
## Quadro mais longo desde que subiu. Servidor que engasga para todo mundo de
## uma vez: e o primeiro numero a olhar quando "o amigo travou".
var _quadro_max := 0.0


func _ready() -> void:
	Engine.max_fps = QUADROS
	_config = ConfigServidor.carregar(OS.get_cmdline_user_args())
	if _config.escrever_modelo_se_faltar():
		_log("modelo de configuracao escrito em %s" % ProjectSettings.globalize_path(_config.caminho))
	var problemas := _config.erros()
	if not problemas.is_empty():
		for p: String in problemas:
			printerr("[servidor] configuracao: %s" % p)
		get_tree().quit(2)
		return

	_log("Nevoa e Dither %s — protocolo %d" % [
		ProjectSettings.get_setting("application/config/version", "?"), ProtocoloRede.VERSAO])
	_log("nome '%s'  porta %d/UDP  max %d  senha %s  lan %s  validacao %s" % [
		_config.nome_publico(), _config.porta, _config.max_jogadores,
		"sim" if not _config.senha.is_empty() else "nao",
		"sim" if _config.anunciar_lan else "nao", _config.validacao])
	# `--mundo-sintetico=N`: enche o mundo com N chunks alterados de mentira,
	# so para a carga de entrada ter o tamanho de uma tarde de jogo no teste.
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mundo-sintetico="):
			var n := a.trim_prefix("--mundo-sintetico=").to_int()
			MundoEmRede.preencher_sintetico(n)
			_log("mundo sintetico: %d chunks alterados" % WorldState.chunks_alterados())
	var err := Sessao.hospedar_dedicado(_config)
	if err != OK:
		printerr("[servidor] nao subiu (erro %d). A porta %d/UDP esta livre?" % [err, _config.porta])
		get_tree().quit(3)
		return
	_log("pronto. Ctrl+C encerra.")


func _process(delta: float) -> void:
	_t += delta
	if _t > 1.0:
		_quadro_max = maxf(_quadro_max, delta)
	_acc_estado += delta
	if _acc_estado >= INTERVALO_ESTADO:
		_acc_estado = 0.0
		_log("%d/%d jogadores, hora do mundo %s, quadro mais longo %d ms" % [
			Sessao.jogadores.size(), _config.max_jogadores, WorldState.relogio.texto(),
			roundi(_quadro_max * 1000.0)])
	if _config.sair_apos > 0.0 and _t >= _config.sair_apos:
		_encerrar("tempo de teste acabou")


func _notification(o_que: int) -> void:
	if o_que == NOTIFICATION_WM_CLOSE_REQUEST:
		_encerrar("pedido de fechamento")


func _encerrar(motivo: String) -> void:
	_log("encerrando: %s (quadro mais longo %d ms)" % [motivo, roundi(_quadro_max * 1000.0)])
	Sessao.sair()
	get_tree().quit(0)


func _log(texto: String) -> void:
	print("[servidor %s] %s" % [Time.get_time_string_from_system(), texto])

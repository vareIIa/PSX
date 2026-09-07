## Verificacao do aplicativo de GPS, sem carregar a cidade.
##
##   godot --headless --path game --script res://tests/checar_gps.gd
##
## Roda so em cima dos autoloads: o GPS le a cidade por funcao estatica, entao
## ele tem de funcionar sem nenhum chunk montado — que e exatamente a promessa
## que o app faz ao listar uma casa da fumaca em rua onde ninguem pisou.
##
## Em modo `--script` o autoload nao vira identificador global, so no da arvore:
## por isso o aparelho e buscado por caminho e chamado por `call`.
extends SceneTree

var _falhas: int = 0
var Gps: Node
var Celular: Node


func _initialize() -> void:
	# Um quadro para os autoloads entrarem na arvore antes de mexer neles.
	process_frame.connect(_rodar, CONNECT_ONE_SHOT)


func _rodar() -> void:
	Gps = root.get_node_or_null("Gps")
	Celular = root.get_node_or_null("Celular")
	_afirmar("gps existe", Gps != null)
	if Gps == null:
		quit(1)
		return

	Gps.call("abrir")
	_afirmar("abriu", bool(Gps.get("ativo")))
	_afirmar("aparelho_visivel", Gps.get_node("Gps").visible)

	var vazios := PackedStringArray()
	for filtro: Dictionary in (Gps.get("FILTROS") as Array):
		var quantos := int(Gps.call("filtrar_por", StringName(filtro["id"])))
		print("  %-12s %d" % [filtro["id"], quantos])
		if quantos <= 0:
			vazios.append(String(filtro["id"]))
	_afirmar("nenhum filtro vazio (%s)" % " ".join(vazios), vazios.is_empty())

	var casas := int(Gps.call("filtrar_por", &"casa_fumaca"))
	_afirmar("casa da fumaca na lista", casas > 0)

	Gps.call("tracar_rota_no_primeiro")
	_afirmar("rota tracada", not (Gps.get("destino") as Dictionary).is_empty())
	_afirmar("rotulo da rota", String(Gps.call("rotulo_do_destino", Vector3.ZERO)) != "")
	_afirmar("alfinete para o minimapa", (Gps.call("pinos_do_destino") as Array).size() == 1)
	print("  rota: %s %s" % [(Gps.get("destino") as Dictionary)["nome"], String(Gps.call("rotulo_do_destino", Vector3.ZERO))])

	# Apertar de novo na mesma linha apaga a rota. Sem isso o jogador traca um
	# destino e nao tem como desfazer sem escolher outro.
	Gps.call("tracar_rota_no_primeiro")
	_afirmar("rota apagada no segundo toque", (Gps.get("destino") as Dictionary).is_empty())

	Gps.call("fechar")
	_afirmar("fechou", not bool(Gps.get("ativo")))

	# O aparelho em pe nao pode abrir por cima do deitado, e vice-versa.
	Gps.call("abrir")
	Celular.call("abrir")
	_afirmar("celular nao abre sobre o gps", not bool(Celular.get("ativo")))
	Gps.call("fechar")

	print("\n%s  %d falha(s)\n" % ["FALHOU" if _falhas > 0 else "OK", _falhas])
	quit(1 if _falhas > 0 else 0)


func _afirmar(o_que: String, certo: bool) -> void:
	if not certo:
		_falhas += 1
	print("%s %s" % ["  ok  " if certo else "FALHA ", o_que])

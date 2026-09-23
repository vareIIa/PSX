## Autoload. Salva e carrega em ponto fixo.
##
## Ponto fixo, nao automatico. Salvar sozinho a cada esquina tira o peso de cada
## decisao: com salvamento livre, gastar a ultima bandagem nao custa nada, basta
## recarregar. Com ponto fixo, a caminhada de volta ate ele e parte do jogo.
##
## O arquivo e JSON legivel de proposito. Save binario esconde bug de
## persistencia ate o dia em que alguem perde progresso; em texto da para abrir e
## ver o que ficou errado.
extends Node

const CAMINHO := "user://save_%d.json"
## Versao 2: o save passou a guardar a identidade do jogador e a agenda de quem
## ele abordou. Um save da versao 1 nao tem portador, e sem portador o celular
## nao loga, a prancha nao tem nome e a carteira do inventario abre vazia — e
## melhor recusar do que carregar um jogo pela metade.
const VERSAO := 2
const ESPACOS := 3

signal salvou(espaco: int)
signal carregou(espaco: int)
signal falhou(motivo: String)


func caminho(espaco: int) -> String:
	return CAMINHO % clampi(espaco, 0, ESPACOS - 1)


func existe(espaco: int) -> bool:
	return FileAccess.file_exists(caminho(espaco))


## Resumo para a tela de carregar, sem montar o mundo inteiro.
func resumo(espaco: int) -> Dictionary:
	if not existe(espaco):
		return {}
	var f := FileAccess.open(caminho(espaco), FileAccess.READ)
	if f == null:
		return {}
	var dados: Variant = JSON.parse_string(f.get_as_text())
	if typeof(dados) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = dados
	return {
		"quando": d.get("quando", ""),
		"local": d.get("local", ""),
		"vida": d.get("inventario", {}).get("vida", 0),
	}


func salvar(espaco: int = 0, local: String = "") -> bool:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		falhou.emit("nao ha jogador na cena")
		return false

	# Sozinho, o mundo desta maquina. Jogando no mundo de outro, o proprio: o
	# convidado nao grava o mundo do anfitriao (plano 02, P9).
	var mundo := Sessao.mundo_para_salvar()
	var dados := {
		"versao": VERSAO,
		"quando": Time.get_datetime_string_from_system(false, true),
		"local": local,
		"jogador": {
			"pos": _v3(jogador.global_position),
			"giro": jogador.rotation.y,
			"bateria": jogador.get("bateria"),
			"lanterna": jogador.get("lanterna_ligada"),
		},
		"inventario": Inventario.para_dicionario(),
		"mundo": mundo[0],
		"visitados": mundo[1],
		# So o id do jogador e a lista de quem ele abordou. O resto do registro
		# civil se deduz do id, entao guardar a ficha seria guardar uma copia que
		# pode divergir da funcao que a gera.
		"registro": RegistroCivil.para_dicionario(),
		"nevoa": String(Settings.fog_preset_id),
		# A missao em andamento. Campo novo sem virada de VERSAO de proposito:
		# ele so acrescenta: um save antigo carrega sem missao nenhuma, que e
		# exatamente o estado certo para uma partida que comecou antes de haver
		# missao. Virar a versao aqui recusaria todo save existente para nao
		# ganhar nada.
		"missao": Missoes.para_dicionario(),
		# Minutos desde a meia-noite. Campo novo sem virada de VERSAO, pela mesma
		# razao de "missao": save antigo carrega sem ele e o relogio fica na hora
		# de abertura, que e onde a partida dele estava.
		"hora": WorldState.relogio.minutos(),
	}

	var f := FileAccess.open(caminho(espaco), FileAccess.WRITE)
	if f == null:
		falhou.emit("nao consegui abrir %s para escrita" % caminho(espaco))
		return false
	f.store_string(JSON.stringify(dados, "  "))
	f.close()
	_capturar_thumb(espaco)
	salvou.emit(espaco)
	return true


func carregar(espaco: int = 0) -> bool:
	if not existe(espaco):
		falhou.emit("espaco %d vazio" % espaco)
		return false

	var f := FileAccess.open(caminho(espaco), FileAccess.READ)
	if f == null:
		falhou.emit("nao consegui abrir %s" % caminho(espaco))
		return false
	var bruto: Variant = JSON.parse_string(f.get_as_text())
	if typeof(bruto) != TYPE_DICTIONARY:
		falhou.emit("save corrompido em %s" % caminho(espaco))
		return false

	var dados: Dictionary = bruto
	if int(dados.get("versao", 0)) != VERSAO:
		# Versao diferente e recusa explicita, nao tentativa de adivinhar. Save
		# de outra versao carregado pela metade e pior que save nao carregado.
		falhou.emit("save da versao %s, o jogo esta na %d"
			% [dados.get("versao", "?"), VERSAO])
		return false

	if Interiores.dentro:
		Interiores.sair()

	WorldState.de_dicionario(dados.get("mundo", {}))
	WorldState.visitados_de_lista(dados.get("visitados", []))
	RegistroCivil.de_dicionario(dados.get("registro", {}))
	Inventario.de_dicionario(dados.get("inventario", {}))
	Missoes.de_dicionario(dados.get("missao", {}))
	Settings.set_fog_preset(StringName(dados.get("nevoa", "denso")))
	WorldState.relogio.definir_minutos(int(dados.get("hora", Relogio.INICIO / 60)))

	var j: Dictionary = dados.get("jogador", {})
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		# Carregar com o jogador ao volante deixaria o corpo invisivel e sem
		# colisao, preso a um carro que pertence a partida que acabou de ser
		# descartada. Desembarcar primeiro e a unica ordem que funciona.
		if jogador.has_method("desembarcar"):
			jogador.call("desembarcar")
		jogador.global_position = _para_v3(j.get("pos", [0, 1, 0]))
		jogador.rotation.y = float(j.get("giro", 0.0))
		jogador.set("bateria", float(j.get("bateria", 1.0)))
		jogador.set("lanterna_ligada", false)
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")

	carregou.emit(espaco)
	return true


func apagar(espaco: int) -> void:
	if existe(espaco):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho(espaco)))


func _v3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _para_v3(a: Variant) -> Vector3:
	if typeof(a) != TYPE_ARRAY or (a as Array).size() < 3:
		return Vector3.ZERO
	var l: Array = a
	return Vector3(float(l[0]), float(l[1]), float(l[2]))


## Onda 4 — thumb local do viewport (SaveThumbCapture). Sem-op se classe ausente.
func _capturar_thumb(espaco: int) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var img: Image = SaveThumbCapture.capture_viewport_to_image(vp)
	if img == null:
		return
	SaveThumbCapture.save_thumb_local(espaco, img)

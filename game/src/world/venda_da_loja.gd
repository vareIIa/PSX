## A venda no balcao das lojas de verdade (LojaViva): as opcoes da conversa com
## quem atende, a compra e o servico de cada ramo.
##
## Separada de LojaViva de proposito: aquela e regra de chunk e roda na thread do
## ChunkBuilder, e todo script que monta chunk fora do jogo (as bancadas em
## `--script`) a carrega. Esta mexe em autoload — Inventario, WorldState,
## AudioDirector —, que nao existe em `--script`; junto dela, a bancada de quinas
## deixava de compilar. So a conversa (FalasNpc) chama daqui.
class_name VendaDaLoja
extends RefCounted

const TITULO_SOBRE := "O QUE TEM DE BOM AI?"
const TITULOS_SERVICO := {
	&"pressao": "MEDIR A PRESSAO",
	&"botao": "PREGAR UM BOTAO (R$ 1)",
	&"fezinha": "FAZER UMA FEZINHA (R$ 5)",
	&"corte": "CORTAR O CABELO (R$ 8)",
	&"xerox": "TIRAR UMA XEROX",
	&"engraxar": "ENGRAXAR O SAPATO (R$ 3)",
	&"oculos": "LIMPAR OS OCULOS",
	&"calibrar": "CALIBRAR O PNEU",
	&"hora": "QUE HORAS SAO?",
}
const PRECO_SERVICO := {&"botao": 1, &"fezinha": 5, &"corte": 8, &"engraxar": 3}

## O que o ramo diz de si, pelo tom da pessoa (FalasNpc.aspereza).
const SOBRE := {
	&"padaria": {
		"aspero": ["Pao, ue. Tem a fornada das seis e a das cinco.", "O resto e o que ta no balcao."],
		"neutro": ["Pao de queijo saiu agora, ta quentinho.", "Cafe e na garrafa ali, pode servir."],
		"gentil": ["Chegou na hora boa! A fornada acabou de sair.", "Leva um pao de queijo, que o de hoje ta caprichado."]},
	&"farmacia": {
		"aspero": ["Remedio controlado so com receita. O resto ta ai."],
		"neutro": ["Tem de tudo pra dor. Curativo tambem, se precisar."],
		"gentil": ["Ta com cara de quem precisa de um curativo.", "Senta ali que eu vejo sua pressao, nao custa nada."]},
	&"armarinho": {
		"aspero": ["Linha, agulha, botao, ziper. Nao vendo fiado."],
		"neutro": ["Tem linha de toda cor. Tecido vendo por metro."],
		"gentil": ["Faltou botao? Me da aqui que eu prego rapidinho.", "Aqui ninguem sai com a roupa rasgada."]},
	&"racao": {
		"aspero": ["Racao, adubo, semente. Quer o que?"],
		"neutro": ["Racao a granel ou no saco fechado.", "Terra adubada tambem, pra quem planta."],
		"gentil": ["Tem terra preta boa, das que a planta gosta.", "Se tiver horta, leva um regador que o sol ta brabo."]},
	&"loterica": {
		"aspero": ["Conta, jogo e boleto. Pega a senha."],
		"neutro": ["A fezinha e cinco reais. Sai premio toda semana, dizem."],
		"gentil": ["Faz uma fezinha! Semana passada um senhor ganhou aqui.", "Nao custa sonhar, ne?"]},
	&"mercearia": {
		"aspero": ["O que ta na prateleira ta a venda."],
		"neutro": ["Tem rapadura da roca e guarana gelado.", "Pilha tambem, se o radio morreu."],
		"gentil": ["Leva uma rapadura, e da roca do meu cunhado.", "Aqui tem de tudo um pouco, como toda venda de Minas."]},
	&"construcao": {
		"aspero": ["Cimento, tinta, ferramenta. Obra e com a gente."],
		"neutro": ["Pe de cabra ta ali no painel. Lanterna tambem."],
		"gentil": ["Precisando abrir alguma coisa? Esse pe de cabra aguenta.", "Lanterna boa, de pilha grande."]},
	&"salao": {
		"aspero": ["Corte e oito. Escova e doze. Tem fila."],
		"neutro": ["Senta ali que ja te atendo.", "Corte e oito reais, sem escova."],
		"gentil": ["Nossa, esse cabelo ta pedindo socorro, hein?", "Senta, que eu dou um jeito rapidinho."]},
	&"acougue": {
		"aspero": ["Carne e pra quem cozinha. Torresmo e pra quem ta com pressa."],
		"neutro": ["O torresmo e feito aqui toda manha. Pururuca."],
		"gentil": ["Prova o torresmo, sai quentinho de manha.", "A linguica e caseira, receita da minha mae."]},
	&"papelaria": {
		"aspero": ["Xerox, caderno, pilha. Fecha as seis."],
		"neutro": ["Xerox e dez centavos. Pilha tem tambem."],
		"gentil": ["Se precisar tirar copia de documento, e aqui mesmo.", "Tem pilha pra lanterna, se for andar de noite."]},
	&"sapataria": {
		"aspero": ["Sapato, bota, tenis. Numero que nao tem, nao tem."],
		"neutro": ["Tem liquidacao no fundo. Engraxo tambem."],
		"gentil": ["Com essa lama toda, seu sapato ta pedindo graxa.", "Senta ali que eu engraxo rapidinho."]},
	&"bazar": {
		"aspero": ["Tudo um e noventa e nove. Quase tudo."],
		"neutro": ["Lanterna, pilha, radinho. Chegou mercadoria nova."],
		"gentil": ["Olha, tem radinho de pilha! Pega ate a radio da serra.", "Lanterna tambem, que aqui a noite e escura."]},
	&"lanchonete": {
		"aspero": ["Coxinha, pastel, cafe. Pede no balcao."],
		"neutro": ["A coxinha saiu agora. Guarana ta gelado."],
		"gentil": ["Senta ai! A coxinha de hoje ta boa demais.", "Quer um cafezinho? Acabei de passar."]},
	&"otica": {
		"aspero": ["Exame de vista e na quinta. Armacao ta na vitrine."],
		"neutro": ["Limpo seus oculos de graca, se quiser."],
		"gentil": ["Enxergar bem nessa nevoa ja e dificil, imagina com lente suja.", "Me da que eu limpo pra voce."]},
	&"borracharia": {
		"aspero": ["Pneu, camara, calibragem. Vinte e quatro horas, quase."],
		"neutro": ["Calibro de graca. Remendo e cinco."],
		"gentil": ["Se o carro tiver puxando pra um lado, traz aqui.", "Calibragem e por conta da casa."]},
	&"relojoaria": {
		"aspero": ["Conserto e pra semana que vem. Pilha tem na hora."],
		"neutro": ["Troco pilha de relogio na hora. Conserto demora."],
		"gentil": ["Relogio parado e mau agouro, sabia?", "Deixa eu acertar o seu, rapidinho."]},
}


## As opcoes de quem esta trabalhando no balcao. Substitui a lista da rua: no
## meio do expediente a pessoa atende, e a lista cabe sem cortar (Conversa
## mostra dez). A vida dela (o assunto proprio) e o documento continuam.
static func opcoes(ficha: Dictionary) -> Array[Dictionary]:
	var loja: Dictionary = ficha.get("loja", {})
	var id := int(ficha["id"])
	var saida: Array[Dictionary] = []
	if loja.is_empty():
		return saida
	var r: Dictionary = LojaViva.RAMOS[int(loja["ramo"])]
	saida.append({"chave": &"loja_sobre", "titulo": TITULO_SOBRE,
		"visto": FalasNpc.ja_falou(id, &"loja_sobre")})
	for item: StringName in r["venda"]:
		var d: Dictionary = LojaViva.ITENS[item]
		saida.append({"chave": StringName("loja_comprar_" + String(item)),
			"titulo": "COMPRAR %s (%s)" % [d["nome"], Dinheiro.formatar(int(d["preco"]))],
			"visto": false})
	if r.has("servico"):
		saida.append({"chave": StringName("loja_servico_" + String(r["servico"])),
			"titulo": String(TITULOS_SERVICO[r["servico"]]), "visto": false})
	var p := Personalidade.de(int(ficha["personalidade"]))
	var proprio: Dictionary = p["proprio"]
	saida.append({"chave": &"proprio", "titulo": FalasNpc.costurar(String(proprio["titulo"]), ficha),
		"visto": FalasNpc.ja_falou(id, &"proprio")})
	saida.append({"chave": &"sair", "titulo": FalasNpc.TITULO_SAIR, "visto": false})
	saida.append({"chave": &"documento", "titulo": FalasNpc.TITULO_DOCUMENTO,
		"visto": FalasNpc.ja_falou(id, &"documento")})
	return saida


static func _tom(ficha: Dictionary) -> String:
	var a := FalasNpc.aspereza(Personalidade.de(int(ficha["personalidade"])))
	return "aspero" if a > 0.6 else ("gentil" if a < 0.35 else "neutro")


## A resposta a uma opcao `loja_*`. Comprar cobra e entrega; sem saldo ou sem
## lugar na mochila, a pessoa diz e nada muda.
static func responder(ficha: Dictionary, chave: StringName) -> Array[String]:
	var loja: Dictionary = ficha.get("loja", {})
	if loja.is_empty():
		return ["Hm."]
	var r: Dictionary = LojaViva.RAMOS[int(loja["ramo"])]
	var texto := String(chave)
	var id := int(ficha["id"])
	if chave == &"loja_sobre":
		FalasNpc.marcar(id, chave)
		var linhas: Array[String] = []
		for l: String in SOBRE[r["id"]][_tom(ficha)]:
			linhas.append(FalasNpc.costurar(l, ficha))
		return linhas
	if texto.begins_with("loja_comprar_"):
		return _comprar(StringName(texto.trim_prefix("loja_comprar_")), ficha)
	if texto.begins_with("loja_servico_"):
		return _servico(StringName(texto.trim_prefix("loja_servico_")), ficha)
	return ["Hm."]


static func _comprar(item: StringName, ficha: Dictionary) -> Array[String]:
	if not LojaViva.ITENS.has(item):
		return ["Isso acabou."]
	var d: Dictionary = LojaViva.ITENS[item]
	var preco := int(d["preco"])
	if Dinheiro.saldo() < preco:
		return ["Da %s. Voce ta sem, ne?" % Dinheiro.formatar(preco),
			"Volta quando tiver, que eu guardo."]
	if not Dinheiro.pagar(preco, String(d["nome"])):
		return ["Da %s." % Dinheiro.formatar(preco)]
	# `adicionar` devolve a SOBRA: o que nao coube volta em dinheiro.
	var sobra := Inventario.adicionar(item)
	if sobra > 0:
		Dinheiro.receber(preco * sobra, "DEVOLVIDO")
		return ["Nao cabe mais nada nessa mochila, moco.", "Esvazia ela e volta."]
	AudioDirector.tocar_ui(&"pegar", -8.0)
	var tom := _tom(ficha)
	if tom == "aspero":
		return ["%s. Ta pago." % Dinheiro.formatar(preco)]
	if tom == "gentil":
		return ["Aqui, fresquinho. Volta sempre!"]
	return ["Pronto. %s." % Dinheiro.formatar(preco)]


static func _servico(s: StringName, ficha: Dictionary) -> Array[String]:
	var preco := int(PRECO_SERVICO.get(s, 0))
	if preco > 0:
		if not Dinheiro.pagar(preco, String(TITULOS_SERVICO[s]).get_slice(" (", 0)):
			return ["Sao %s. Sem dinheiro nao da, ne?" % Dinheiro.formatar(preco)]
	match s:
		&"pressao":
			Inventario.curar(3)
			return ["Doze por oito. Ta boa.", "Mas para de subir ladeira correndo."]
		&"botao":
			return ["Pronto, pregado. Linha dupla, nao solta mais."]
		&"fezinha":
			return _fezinha(ficha)
		&"corte":
			return ["Pronto. Agora sim, parece gente.", "Oito reais. Volta daqui a um mes."]
		&"xerox":
			return ["Xerox de que? Voce nao trouxe papel nenhum.", "Quando precisar, e dez centavos."]
		&"engraxar":
			return ["Olha o brilho. Ate da pena pisar nessa lama."]
		&"oculos":
			return ["Pronto, limpinho. Mas essa nevoa ai fora, nem lente resolve."]
		&"calibrar":
			return ["Traz o carro que eu calibro. De graca, e so parar ali na frente."]
		&"hora":
			return [_hora()]
	return ["Hm."]


## A fezinha: um em doze devolve cinquenta, um em cento e vinte, quinhentos.
## O sorteio e na hora, e o premio entra no extrato como qualquer dinheiro.
static func _fezinha(ficha: Dictionary) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := rng.randi() % 120
	if n == 0:
		Dinheiro.receber(500, "PREMIO DA LOTERICA")
		return ["Nao acredito... Quina! Quinhentos reais!", "Conta pra ninguem, senao aparece parente."]
	if n < 10:
		Dinheiro.receber(50, "PREMIO DA LOTERICA")
		return ["Olha so, deu terno! Cinquenta reais.", "Ta com sorte hoje, hein?"]
	return ["Nao foi dessa vez.", "Mas semana que vem sai, fe em Deus." if _tom(ficha) != "aspero"
		else "Proximo."]


## A hora certa, lida do relogio da cidade: o unico servico que responde com o
## estado do mundo.
static func _hora() -> String:
	if WorldState.relogio == null:
		return "Meu relogio parou. Acontece nas melhores relojoarias."
	var m := WorldState.relogio.minutos()
	return "Sao %d e %02d. Esse aqui nao atrasa um minuto." % [m / 60, m % 60]

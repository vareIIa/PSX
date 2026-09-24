## O que cada tecla e cada botao faz — a tabela da tela CONTROLES da pausa.
##
## Nada aqui e digitado duas vezes. A tecla sai do `InputMap` (o que o
## `project.godot` liga de verdade) e o botao sai de `Controle.LIGACOES` (o que
## `Controle` registra em tempo de execucao). Uma tabela escrita a mao mentiria
## na primeira tecla trocada; esta so pode estar errada se o jogo estiver.
class_name HudControles
extends RefCounted

## Ordem da tela: andar e olhar primeiro, o que se usa na rua, depois o que
## abre tela. `&"olhar"` e `&"andar"` nao sao acoes: sao eixos.
const ACOES := [
	[&"andar", "ANDAR"],
	[&"olhar", "OLHAR"],
	[&"correr", "CORRER"],
	[&"agachar", "AGACHAR  ·  BUZINA"],
	[&"interagir", "INTERAGIR  ·  FALAR"],
	[&"veiculo", "ENTRAR E SAIR DO CARRO"],
	[&"lanterna", "LANTERNA"],
	[&"examinar", "EXAMINAR"],
	[&"radio", "RADIO"],
	[&"alternar_camera", "CAMERA"],
	[&"celular", "CELULAR"],
	[&"gps", "GPS"],
	[&"inventario", "BOLSA  ·  SEGURAR: HUD"],
	[&"pausa", "PAUSA"],
]

## Passo da tabela na aba SISTEMA: 14 acoes na altura da coluna.
const LINHA := 11.0

## Botao do Godot (indice) para o nome que `HudGlifos` desenha.
const BOTAO := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "SELECT", 6: "START", 7: "L3", 8: "R3",
	9: "LB", 10: "RB"}
## Eixo com sentido para o nome: so os gatilhos sao acao; 0 e 1 sao o analogico.
const EIXO := {"a:4+": "LT", "a:5+": "RT"}
## Nome de tecla do Godot para o que cabe numa tecla desenhada.
const TECLA := {"ESCAPE": "ESC", "SPACE": "ESPACO", "CTRL": "CTRL", "SHIFT": "SHIFT",
	"TAB": "TAB", "ENTER": "ENTER"}


## `[{acao, rotulo, tecla, botao}]`. `botao` vazio: a acao nao tem botao (o GPS
## mora dentro do celular, como `Controle` explica).
static func linhas() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for a: Array in ACOES:
		var acao: StringName = a[0]
		saida.append({"acao": acao, "rotulo": String(a[1]), "tecla": tecla_de(acao),
			"botao": botao_de(acao)})
	return saida


static func tecla_de(acao: StringName) -> String:
	match acao:
		&"andar":
			return "WASD"
		&"olhar":
			return "MOUSE"
	if not InputMap.has_action(acao):
		return ""
	for ev: InputEvent in InputMap.action_get_events(acao):
		var k := ev as InputEventKey
		if k == null:
			continue
		var codigo := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if codigo == KEY_NONE:
			continue
		var nome := OS.get_keycode_string(codigo).to_upper()
		return String(TECLA.get(nome, nome))
	return ""


static func botao_de(acao: StringName) -> String:
	match acao:
		&"andar":
			return "LS"
		&"olhar":
			return "RS"
		&"pausa":
			# Pausa esta no B e no START; na tabela vai o START, que e o que o
			# jogador procura. O B e "voltar", e o rodape de cada tela ja diz.
			return "START"
	var ligacoes: Dictionary = Controle.LIGACOES
	if not ligacoes.has(acao):
		return ""
	for codigo: String in ligacoes[acao]:
		if EIXO.has(codigo):
			return String(EIXO[codigo])
		if codigo.begins_with("b:"):
			var i := codigo.trim_prefix("b:").to_int()
			if BOTAO.has(i):
				return String(BOTAO[i])
	return ""

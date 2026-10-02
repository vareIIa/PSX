## Missao 1, tarefa A: camera de cinema, fala com escolha e o olho.
##
##     godot --headless --path game --script res://tests/m1_a.gd
##
## Sem cidade: monta o palco do `TesteCinema` (chao, parede, dois Ator e o
## Marea de cena), percorre os 13 planos afirmando onde a lente ficou, roda uma
## pergunta com efeito borboleta e espera o olho terminar. O que cada afirmacao
## quer dizer esta em `src/levels/teste_cinema.gd`.
extends SceneTree


func _initialize() -> void:
	print("\n=== missao 1 / A: cinema, escolha e olho ===\n")
	var mundo := Node3D.new()
	mundo.name = "BancadaM1A"
	root.add_child(mundo)
	current_scene = mundo
	_rodar.call_deferred(mundo)


## O palco e carregado aqui, e nao citado pelo nome da classe: o script
## principal do `--script` compila antes de os autoloads existirem, e o
## TesteCinema depende (via Ator, Carro, Elenco) de scripts que citam autoload.
func _rodar(mundo: Node3D) -> void:
	var teste: GDScript = load("res://src/levels/teste_cinema.gd")
	var palco: Dictionary = teste.call(&"montar_palco", mundo)
	var falhas: PackedStringArray = await teste.call(&"verificar", self, palco)
	if falhas.is_empty():
		print("OK")
		quit(0)
	else:
		print("FALHOU: %s" % ", ".join(falhas))
		quit(1)

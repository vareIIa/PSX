## Escreve o mapa de entrada no project.godot pelo proprio Godot.
##
##     godot --headless --path game --script res://tools/bootstrap_input.gd
##
## Serializar InputEventKey na mao dentro do project.godot e fonte de erro silencioso:
## o formato muda entre versoes e um campo errado nao da erro, so faz a tecla nao
## funcionar. Deixar o motor gravar elimina a classe inteira de problema.
extends SceneTree

const ACOES := {
	# movimento
	"mover_frente": [KEY_W, KEY_UP],
	"mover_tras": [KEY_S, KEY_DOWN],
	"mover_esq": [KEY_A, KEY_LEFT],
	"mover_dir": [KEY_D, KEY_RIGHT],
	"correr": [KEY_SHIFT],
	"agachar": [KEY_CTRL],
	# camera e interacao
	"alternar_camera": [KEY_V],
	"interagir": [KEY_E],
	"lanterna": [KEY_F],
	"inventario": [KEY_TAB],
	"pausa": [KEY_ESCAPE],
	# debug
	"debug_nevoa": [KEY_F1],
	"debug_info": [KEY_F3],
}


func _initialize() -> void:
	for nome: String in ACOES:
		var caminho := "input/" + nome
		var eventos: Array = []
		for tecla: int in ACOES[nome]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			eventos.append(ev)
		ProjectSettings.set_setting(caminho, {"deadzone": 0.5, "events": eventos})
		print("  %s -> %s" % [nome, ", ".join(ACOES[nome].map(
			func(k: int) -> String: return OS.get_keycode_string(k)))])

	var err := ProjectSettings.save()
	if err != OK:
		push_error("falha ao gravar project.godot (erro %d)" % err)
		quit(1)
		return
	print("\n%d acoes gravadas em project.godot" % ACOES.size())
	quit(0)

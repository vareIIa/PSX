## Metrica real das fontes de bitmap do projeto.
##
##     godot --headless --path game --script res://tests/medir_fonte.gd
##
## Existe porque o `.fnt` e o Godot nao concordam sozinhos. O arquivo declara
## `size=11 lineHeight=13`, mas quem desenha e o `TextServer`, e o que ele usa
## depende de `FontFile.fixed_size` e do modo de escala. Medir aqui e o que
## separa "a linha tem 13 px" de "achei que tinha".
##
## O numero que sai daqui e o que entra no UI-BIBLE. Se um dia a importacao da
## fonte mudar, este script muda de resposta antes de o HUD sair do lugar.
extends SceneTree

const FONTES := {
	"psx_pequena": "res://assets/fontes/psx_pequena.fnt",
	"psx_media": "res://assets/fontes/psx_media.fnt",
	"psx_titulo": "res://assets/fontes/psx_titulo.fnt",
	"psx_mono": "res://assets/fontes/psx_mono.fnt",
}

## Strings que o HUD desenha de verdade. Medir a frase real vale mais que medir
## o alfabeto: e ela que tem de caber na caixa.
const AMOSTRAS: Array[String] = [
	"A CASA DA FUMACA",
	"270 M",
	"1.2 KM",
	"Va ate a casa da fumaca.",
	"[M] abre o GPS   [E] traca a rota",
	"OBJETIVO CUMPRIDO",
	"ETAPA 1/2",
]


func _initialize() -> void:
	print("\n=== metrica de fonte ===\n")
	for nome: String in FONTES:
		var caminho: String = FONTES[nome]
		if not ResourceLoader.exists(caminho):
			print("x %s ausente em %s" % [nome, caminho])
			continue
		var fonte := load(caminho) as Font
		var ff := fonte as FontFile
		var fixo := ff.fixed_size if ff != null else 0
		print("-- %s" % nome)
		print("   fixed_size          %d" % fixo)
		print("   escala de tamanho   %d" % (ff.fixed_size_scale_mode if ff != null else -1))
		# A pergunta que importa: pedir tamanho diferente muda a metrica?
		for pedido: int in [11, 14, 16, 18]:
			var h := fonte.get_height(pedido)
			var l := fonte.get_string_size("A CASA DA FUMACA",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, pedido).x
			print("   pedido %2d -> altura %5.1f  largura da amostra %6.1f"
				% [pedido, h, l])
		if nome == "psx_pequena":
			print("   --- amostras no tamanho fixo ---")
			var t := fixo if fixo > 0 else 16
			for s: String in AMOSTRAS:
				print("   %6.1f px  %s" % [
					fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, t).x, s])
	print("")
	quit(0)

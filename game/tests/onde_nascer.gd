## Diz o que ha em volta do PARQUINHO SAKURA, para escolher um respawn.
## Ferramenta, nao teste.
extends SceneTree

const USOS := ["EDIFICADO", "PARQUE", "BALDIO"]


func _init() -> void:
	for cz in range(1, 7):
		var linha := ""
		for cx in range(-6, 4):
			var q := MalhaUrbana.quadra_de(cx, cz)
			var u := int(q["uso"])
			var via := MalhaUrbana.tem_via(cx, cz)
			var c := "."
			if via:
				c = "="
			elif u == MalhaUrbana.Uso.PARQUE:
				c = "P"
			elif u == MalhaUrbana.Uso.BALDIO:
				c = "b"
			else:
				c = "E"
			linha += c
		print("z=%2d  x=-6..3  %s" % [cz, linha])
	print("legenda: = via   P parque   E edificado   b baldio")
	quit()

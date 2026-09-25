## Onde estao as palmeiras de avenida, e quantas folhas a poda tira de cada uma
## (PLANO_FLORA_AAA, rodada 3: "arvore gigante sem folhas").
##
##     godot --headless --path game res://tests/sonda_palmeiras.tscn -- [--raio=8]
##
## Cena, e nao --script: o ChunkBuilder precisa dos autoloads para compilar
## (memoria "censo de chunk roda em cena"). Refaz os sorteios da palmeira como a
## Vegetacao faz e aplica as duas regras de poda (a de antes, o V das arvores, e
## a de agora, so a folha que chega a 1,3 m do fio). Imprime as mais peladas.
extends Node


func _ready() -> void:
	var raio := 8
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--raio="):
			raio = a.trim_prefix("--raio=").to_int()
	var total := 0
	var peladas := 0
	var linhas: Array[String] = []
	for cx in range(-raio, raio + 1):
		for cz in range(-raio, raio + 1):
			var plantio := ChunkBuilder.arvores(cx, cz)
			if plantio.is_empty():
				continue
			var poda := KitRede.faixas_de_poda(cx, cz)
			for base: Vector3 in plantio:
				if ChunkBuilder._especie_de_rua(cx, cz, base, true) != &"palmeira":
					continue
				if ChunkBuilder._arvore_de_rua(MalhaUrbana.bordas(cx, cz), base):
					continue
				total += 1
				var antes := _folhas_com(base, poda, true)
				var agora := _folhas_com(base, poda, false)
				if antes.x == 0:
					peladas += 1
				linhas.append("palmeira chunk (%d,%d) mundo (%.1f, %.1f): folhas antes %d/%d, agora %d/%d" % [
					cx, cz, base.x + cx * 32.0, base.z + cz * 32.0, antes.x, antes.y, agora.x, agora.y])
	for l in linhas:
		if l.contains("antes 0/"):
			print(l)
	print("[sonda_palmeiras] %d palmeiras de avenida, %d sem folha nenhuma na regra de antes" % [total, peladas])
	get_tree().quit()


## Folhas que ficam (x) de quantas (y), com a regra de antes (`v`) ou a de agora.
func _folhas_com(base: Vector3, poda: PackedVector3Array, v: bool) -> Vector2i:
	var altura := 13.5
	var topo := base + Vector3(0.0, altura + 1.8, 0.0)
	var comp := 3.9
	var ficam := 0
	var n := 13
	for k in n:
		var a := TAU * float(k) / float(n)
		var queda := -0.3 if k % 3 != 0 else 0.6
		var fora := Vector3(cos(a), 0.0, sin(a))
		var eixo := (fora * cos(queda) + Vector3(0.0, sin(queda), 0.0)).normalized()
		var arco := lerpf(0.55, 0.2, clampf((queda + 0.9) / 1.7, 0.0, 1.0))
		var corta := false
		if not poda.is_empty():
			for s: float in [0.35, 0.7, 1.0]:
				var q := topo + eixo * comp * s * 0.92 + Vector3(0.0, -arco * comp * s * s, 0.0)
				if (v and PodaEmV.podado(q, poda, comp * 0.25)) \
						or (not v and ArvoreEsqueleto._perto_do_fio(q, poda, 1.3)):
					corta = true
					break
		if not corta:
			ficam += 1
	return Vector2i(ficam, n)

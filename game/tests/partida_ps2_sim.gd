## Joga partidas inteiras da PartidaPS2 sem tela e conta o que aconteceu.
##
##   godot --headless --path game --script res://tests/partida_ps2_sim.gd
##
## A captura mostra UM quadro; isto mostra se o jogo anda: se sai gol, se a bola
## troca de pe, se o intervalo e o fim chegam, e se nenhum estado prende a
## partida (bola parada sem dono, gol que nao volta ao jogo).
extends SceneTree


func _init() -> void:
	var p := PartidaPS2.new()
	root.add_child(p)
	await process_frame
	var estados: Dictionary = {}
	var gols := 0
	var trocas := 0
	var dono_antes := -2
	var parado := 0.0
	var pior_parado := 0.0
	var partidas := 0
	var ultimo_estado := p.estado
	var ticks := int(60.0 * 60.0 * 30.0 * 0.5)  # meia hora de jogo simulado a 30 Hz
	for i in ticks:
		p._tick()
		var e := p.estado
		estados[e] = int(estados.get(e, 0)) + 1
		if e != ultimo_estado:
			if e == PartidaPS2.Estado.GOL:
				gols += 1
			if e == PartidaPS2.Estado.MENU:
				partidas += 1
			ultimo_estado = e
		if e == PartidaPS2.Estado.JOGO:
			var time_dono := -1 if p._dono < 0 else (0 if p._dono < 11 else 1)
			if time_dono >= 0 and dono_antes >= 0 and time_dono != dono_antes:
				trocas += 1
			if time_dono >= 0:
				dono_antes = time_dono
			if p._dono < 0 and p._bola_v.length() < 0.3:
				parado += PartidaPS2.PASSO
				pior_parado = maxf(pior_parado, parado)
			else:
				parado = 0.0
	var nomes := PartidaPS2.Estado.keys()
	for e: int in estados:
		print("  %-10s %6.1f s" % [nomes[e], float(estados[e]) / 30.0])
	print("partidas completas: %d  gols: %d  trocas de posse: %d  bola morta mais longa: %.1f s"
		% [partidas, gols, trocas, pior_parado])
	print("placar atual: %s  %s" % [str(p._placar), str(p.estat)])

	# O humano: P1 corre para o gol adversario e chuta a cada dois segundos.
	# Prova o caminho do controle (jogador da vez, passe, chute), e nao so a CPU.
	p.humano = true
	var chutes_antes: int = p.estat["chutes"]
	var controlou := 0
	var com_bola := 0
	for i in 30 * 120:
		if p.estado == PartidaPS2.Estado.MENU:
			p.passe()
		p.entrada(Vector2(1.0, 0.0), true)
		if i % 60 == 0:
			p.chute()
		elif i % 60 == 30:
			p.passe()
		p._tick()
		if p._controlado >= 0 and p._controlado < 11:
			controlou += 1
		if p._dono >= 0 and p._dono == p._controlado:
			com_bola += 1
	print("humano: controlou %d de %d ticks, com a bola %d, chutes %d" % [controlou,
		30 * 120, com_bola, int(p.estat["chutes"]) - chutes_antes])
	quit()

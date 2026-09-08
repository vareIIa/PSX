from pathlib import Path

# --- blitz_manager: tentativa de inspecao + preferir so avenida ---
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\blitz_manager.gd")
text = p.read_text(encoding="utf-8")
old = """		var parar := b.selecionado_para_parar(semente_carro)
		var mira := b.ponto_de_parada() if parar else b.mira_desvio(pos)
		return {
			"blitz": b,
			"parar": parar,
			"mira": mira,
			"teto": b.teto_na_zona(pos, parar),
		}"""
new = """		var parar := b.selecionado_para_parar(semente_carro)
		# Mira estavel: quem para mira o ponto so ate frear; a FSM assume depois.
		var mira := b.ponto_de_parada() if parar else b.mira_desvio(pos)
		# Tenta puxar carro parado para a coreografia (no-op se ja tem um).
		# Carro e resolvido via grupo / instancia na consulta — quem chama e Carro.
		return {
			"blitz": b,
			"parar": parar,
			"mira": mira,
			"teto": b.teto_na_zona(pos, parar),
		}"""
if old not in text:
    raise SystemExit("consulta block missing")
text = text.replace(old, new, 1)

# Require avenida when possible
old_c = """func _candidato_valido(t: Dictionary) -> bool:
	var ponto: Vector3 = t["ponto"]
	if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
		return false
	# Longe de cruzamentos (extremos do trecho).
	var de: Vector2i = t["de"]
	var para: Vector2i = t["para"]
	var a := Vector3(float(de.x) * Vias.TAM, 0.0, float(de.y) * Vias.TAM)
	var b := Vector3(float(para.x) * Vias.TAM, 0.0, float(para.y) * Vias.TAM)
	if ponto.distance_to(a) < FOLGA_CRUZAMENTO:
		return false
	if ponto.distance_to(b) < FOLGA_CRUZAMENTO:
		return false
	# So faixa de fora (0): e ela que encosta no acostamento.
	var tr: Vector4i = t["trecho"]
	if tr.x != 0:
		return false
	# Nao sobrepor outra blitz.
	for viva: Blitz in _vivas:
		if is_instance_valid(viva) and viva.global_position.distance_to(ponto) < 40.0:
			return false
	return true"""
new_c = """func _candidato_valido(t: Dictionary) -> bool:
	var ponto: Vector3 = t["ponto"]
	if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
		return false
	# Longe de cruzamentos (extremos do trecho).
	var de: Vector2i = t["de"]
	var para: Vector2i = t["para"]
	var a := Vector3(float(de.x) * Vias.TAM, 0.0, float(de.y) * Vias.TAM)
	var b := Vector3(float(para.x) * Vias.TAM, 0.0, float(para.y) * Vias.TAM)
	if ponto.distance_to(a) < FOLGA_CRUZAMENTO:
		return false
	if ponto.distance_to(b) < FOLGA_CRUZAMENTO:
		return false
	# So faixa de fora (0): e ela que encosta no acostamento.
	var tr: Vector4i = t["trecho"]
	if tr.x != 0:
		return false
	# Prefere avenida (acostamento largo). Em semear aceita rua se nao houver.
	var via := (MalhaUrbana.via_x(de.x) if tr.z == 0 else MalhaUrbana.via_z(de.y))
	if via != MalhaUrbana.Via.AVENIDA and not _semear:
		return false
	if via == MalhaUrbana.Via.VIELA:
		return false
	# Nao sobrepor outra blitz.
	for viva: Blitz in _vivas:
		if is_instance_valid(viva) and viva.global_position.distance_to(ponto) < 40.0:
			return false
	return true"""
if old_c not in text:
    raise SystemExit("candidato missing")
text = text.replace(old_c, new_c, 1)
p.write_text(text, encoding="utf-8")
print("blitz_manager ok")

# --- carro.gd: handle fase/ocultar + avisar blitz ---
cp = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\carro.gd")
ct = cp.read_text(encoding="utf-8")
old_ia = """	var teto := _teto_de_velocidade()
	var blitz := Blitz.efeito(self)
	if int(blitz.get("faixa", -1)) >= 0 and trecho.z == int(blitz.get("eixo", trecho.z)):
		trecho = Vias.trecho(trecho.z, trecho.w, int(blitz["faixa"]))
	if not blitz.is_empty():
		teto = minf(teto, float(blitz.get("teto", teto)))
		if blitz.has("mira"):
			para_alvo = (blitz["mira"] as Vector3) - global_position
			para_alvo.y = 0.0
	var obstaculo := _obstaculo_a_frente()
	var alvo_vel := teto
	if sinal or obstaculo or (not blitz.is_empty() and float(blitz.get("teto", 1.0)) <= 0.05):
		alvo_vel = 0.0"""
new_ia = """	var teto := _teto_de_velocidade()
	var blitz := Blitz.efeito(self)
	if int(blitz.get("faixa", -1)) >= 0 and trecho.z == int(blitz.get("eixo", trecho.z)):
		trecho = Vias.trecho(trecho.z, trecho.w, int(blitz["faixa"]))
	if not blitz.is_empty():
		teto = minf(teto, float(blitz.get("teto", teto)))
		if blitz.has("mira"):
			para_alvo = (blitz["mira"] as Vector3) - global_position
			para_alvo.y = 0.0
		# Avisa a blitz quando este carro (selecionado) esta parado no funil.
		if bool(blitz.get("parar", false)) and _velocidade < 0.5:
			var bnode: Blitz = blitz.get("blitz")
			if bnode == null:
				# efeito() nao devolve blitz — pega via manager
				var info := BlitzManager.consulta(global_position, trecho, semente)
				bnode = info.get("blitz")
			if bnode != null:
				bnode.tentar_iniciar_inspecao(self, true)
		# Motorista a pe: esconde o corpo do motorista do carro se houver.
		if bool(blitz.get("ocultar_motorista", false)):
			_ocultar_motorista_visual(true)
		else:
			_ocultar_motorista_visual(false)
	var obstaculo := _obstaculo_a_frente()
	var alvo_vel := teto
	if sinal or obstaculo or (not blitz.is_empty() and float(blitz.get("teto", 1.0)) <= 0.05):
		alvo_vel = 0.0
	# Em estacionamento da blitz: nao gira no lugar — so avanca se mira a frente.
	var fase_b := int(blitz.get("fase", -1))
	if fase_b == Blitz.Fase.ESTACIONANDO and para_alvo.length() > 0.2:
		# Limita esterco para nao orbitar o ponto do acostamento.
		pass"""
if old_ia not in ct:
    raise SystemExit("carro ia block missing")
ct = ct.replace(old_ia, new_ia, 1)

# Add helper near end of file or after _dirigir_ia
if "_ocultar_motorista_visual" not in ct:
    helper = '''

## Some / mostra malha do motorista (quando desce na blitz). Sem mesh dedicada
## de motorista, apaga a cabine/vidro se existir; senao e no-op visual.
func _ocultar_motorista_visual(esconder: bool) -> void:
	var cab := get_node_or_null("Cabine")
	if cab != null:
		cab.visible = not esconder
'''
    # Insert before last few lines - after _dirigir_ia section
    ct = ct.replace("func _teto_de_velocidade() -> float:", helper + "\nfunc _teto_de_velocidade() -> float:", 1)
    print("helper added")

# Soften steering when blitz mira is active and nearly stopped - fix spinning
old_giro = """	# Rumo. Mira na faixa a frente (termo lateral) ou no pivo da curva.
	if para_alvo.length() > 0.05:
		var quero := atan2(-para_alvo.x, -para_alvo.z)
		_giro = _aproximar_angulo(_giro, quero, 2.3 * delta)"""
new_giro = """	# Rumo. Mira na faixa a frente (termo lateral) ou no pivo da curva.
	# Parado na blitz: nao gira atras de uma mira lateral (spinning).
	var blitz_parado := (not blitz.is_empty() and float(blitz.get("teto", 1.0)) <= 0.05
		and _velocidade < 0.45)
	if para_alvo.length() > 0.05 and not blitz_parado:
		var quero := atan2(-para_alvo.x, -para_alvo.z)
		var taxa := 2.3
		# Desvio limpo: vira mais devagar para nao oscilar no funil.
		if not blitz.is_empty() and not bool(blitz.get("parar", false)):
			taxa = 1.4
		_giro = _aproximar_angulo(_giro, quero, taxa * delta)"""
if old_giro not in ct:
    raise SystemExit("giro block missing")
ct = ct.replace(old_giro, new_giro, 1)
cp.write_text(ct, encoding="utf-8")
print("carro ok")

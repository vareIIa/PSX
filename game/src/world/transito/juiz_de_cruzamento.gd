## Quem entra primeiro no cruzamento (PLANO_TRANSITO_AAA, Passo 3).
##
## A lei (sinal, PARE) diz se o carro PODE entrar; o juiz diz se ele DEVE. Cada
## motorista publica o que vai fazer no proximo cruzamento — o movimento
## (`Movimento`), onde esta nele, a que velocidade, se passa, se espera, ou se ja
## entrou (`MotoristaIA.pub_*`) —, e quem vai entrar pergunta aqui se o chao
## que ele vai ocupar esta livre de quem tem a vez.
##
## Quem tem a vez (`_precede`)
## ---------------------------
##   ja entrou            sempre: quem esta dentro tem de sair
##   sem sinal            quem vem pela preferencial (`Vias.preferencial`); entre
##                        duas secundarias paradas no PARE, quem parou primeiro
##   de frente            quem segue reto ou vira a direita; a esquerda cede
##                        (vale no verde e na preferencial)
##   empate               quem chega antes; depois, uma ordem fixa por carro
## A ordem e estrita: de cada par, so um cede ao outro. Por isso dois carros
## parados em PAREs opostos nunca saem juntos, mesmo decidindo no mesmo quadro.
##
## Brecha por tempo, e nao por distancia
## ------------------------------------
## Cada um tem uma janela na zona de conflito — quando entra, o mais cedo que
## pode, e quando sai, o mais tarde razoavel (`janela`). Quem cede so entra se
## sai da zona `PET` antes de o outro chegar, ou se o outro sai `PET_DEPOIS`
## antes de ele chegar. A brecha aceita sai do tamanho da manobra: sair do PARE
## cruzando a rua inteira pede uns 6 s de quem vem pela preferencial, virar a
## direita pede menos — perto dos 6,5 e 6,2 s que os manuais de capacidade medem
## em motorista de verdade. A IA antiga aceitava qualquer um a mais de 16 m, o
## que a 14 m/s era 1,1 s.
##
## Pedestre (`pedestre`)
## ---------------------
## Quem atravessa numa zebra por onde o carro vai passar tem a vez: o carro
## espera na linha, ou, se ja entrou, antes da zebra de saida. Quem espera na
## calcada (`TravessiaDePedestre` ESPERANDO) nao conta — e ele que espera a brecha.
class_name JuizDeCruzamento
extends RefCounted

enum Veredito { LIVRE, CEDE_CARRO, OCUPADO, SAIDA_CHEIA }

## Folga de tempo (PET, "post-encroachment time") entre um sair da zona de
## conflito e o outro entrar, em segundos: quem cede sai da zona PET antes de o
## outro chegar...
const PET := 1.5
## ... ou o outro ja saiu dela PET_DEPOIS antes de ele chegar.
const PET_DEPOIS := 1.0
## Impaciencia: esperando ha mais disto, o PET desce ate PET_MINIMO em mais
## IMPACIENCIA_S. Gente aceita brecha menor depois de esperar muito (e o que a
## literatura de brecha aceita mede); sem isto uma rua cheia prendia o PARE para
## sempre.
const IMPACIENCIA_S := 10.0
const PET_MINIMO := 1.1
## Aceleracao de quem parte (a do Pe) e a de quem passa devagar, para a janela.
const A_PARTE := 2.0
const A_SAI := 1.2
## Ate onde se olha: carros ate ALCANCE_CARRO do centro; carros sem plano aqui,
## so dentro de ALCANCE_MIOLO; pedestres ate ALCANCE_PEDESTRE. A esquerda na
## avenida pede uns 5,8 s de brecha (sair da zona mais o PET): a 14 m/s sao 81 m,
## e com 80 de alcance o carro que fechava a brecha ainda nao existia para o juiz.
const ALCANCE_CARRO := 110.0
const ALCANCE_MIOLO := 16.0
const ALCANCE_PEDESTRE := 24.0
## Pedestre: margem em volta da lataria ao longo da zebra, e em volta da faixa ao
## longo da rua, em metros.
const PED_MARGEM := 1.2
const PED_FAIXA := 1.0
## Folga de tempo com o pedestre, em segundos: ele tem de ter saido da frente
## PED_ANTES antes de o carro chegar, ou chegar nela PED_DEPOIS depois de o carro
## ter passado. O pedestre decide com folgas MAIORES que estas
## (`TravessiaDePedestre.PET_*`, `MARGEM`): quem atravessa numa brecha que ele
## mesmo aceitou nunca faz carro frear.
const PED_ANTES := 1.0
const PED_DEPOIS := 1.5
## Horizonte de quem anda sem plano (o jogador), em segundos.
const HORIZONTE := 8.0

## Diagnostico: quem fez o ultimo carro ceder (lido por `--diag-transito`).
static var ultimo_motivo := ""


## (entra, sai) da zona [s_in, s_out] do movimento `mov` de quem esta em `s` a
## `v`: entra o mais cedo que pode, acelerando a A_PARTE ate a velocidade de
## passagem; sai o mais tarde razoavel — quem vem mais rapido que a curva chega
## nela freando (na media das duas) e faz o resto na de passagem; quem vem
## devagar sai acelerando so A_SAI. Quem esta parado ainda paga a reacao.
static func janela(mov: Movimento, s_in: float, s_out: float, s: float, v: float,
		reacao: float) -> Vector2:
	var vp := mov.v_passa
	var t_in := reacao + Longitudinal.tempo_ate(s_in - s, v, A_PARTE, maxf(v, vp))
	var t_out: float
	if mov.tipo != Movimento.Tipo.RETO and v > vp and s < mov.s_ref:
		var d1 := minf(mov.s_ref, s_out) - s
		t_out = reacao + d1 / ((v + vp) * 0.5) + maxf(s_out - mov.s_ref, 0.0) / vp
	else:
		t_out = reacao + Longitudinal.tempo_ate(s_out - s, minf(v, vp), A_SAI, maxf(vp, 3.0))
	return Vector2(t_in, t_out)


## Pode `eu` entrar agora pelo movimento `mov`, estando em `s` a `v`? `espera` e
## ha quanto tempo ele espera por ele (impaciencia).
static func avaliar(eu: MotoristaIA, mov: Movimento, s: float, v: float, espera: float,
		sinal: bool, pref: int, pet_forcado := -1.0) -> int:
	var carro := eu.carro
	var ij := mov.ij
	var c := Vector2(float(ij.x) * Vias.TAM, float(ij.y) * Vias.TAM)
	var reacao := eu.reacao_restante()
	var pet := lerpf(PET, PET_MINIMO, clampf((espera - IMPACIENCIA_S) / IMPACIENCIA_S, 0.0, 1.0))
	if pet_forcado > 0.0:
		pet = pet_forcado
	for no: Node in carro.get_tree().get_nodes_in_group(&"carro"):
		if no == carro:
			continue
		var o := no as Carro
		if o == null or not is_instance_valid(o) or o.has_meta(&"ignorar_ia"):
			continue
		var op := Vector2(o.global_position.x, o.global_position.z)
		var d2 := op.distance_squared_to(c)
		if d2 > ALCANCE_CARRO * ALCANCE_CARRO:
			continue
		var o_ia := MotoristaIA.ia_de(o)
		var plano := o_ia.plano_em(ij) if o_ia != null else 0
		if plano == 0:
			# Sem plano por aqui: o jogador, carro sem motorista, a blitz. Conta
			# pelo que se ve dele — onde esta e para onde vai. Carro da IA com o
			# plano em outro lugar so conta se ja esta no miolo.
			if o_ia != null and d2 > ALCANCE_MIOLO * ALCANCE_MIOLO:
				continue
			var ocupa := _sem_plano(mov, s, v, reacao, o, pet)
			if ocupa != Veredito.LIVRE:
				ultimo_motivo = "%s (sem plano)" % o.name
				return ocupa
			continue
		var o_mov: Movimento = o_ia.pub_mov if plano == 1 else o_ia.pub_saindo_mov
		var o_s: float = o_ia.pub_s if plano == 1 else o_ia.pub_saindo_s
		var o_vez: int = o_ia.pub_vez if plano == 1 else MotoristaIA.Vez.DENTRO
		# Mesma chegada: e fila, e quem cuida e o pe (IIDM).
		if o_mov.chegada.z == mov.chegada.z and o_mov.chegada.w == mov.chegada.w:
			continue
		# Parado pela lei (vermelho, PARE antes de parar): nao entra.
		if o_vez == MotoristaIA.Vez.PARA_LEI:
			continue
		var cf := Movimento.conflito(mov, o_mov)
		if cf.x == INF or o_s > cf.w or s > cf.y:
			continue
		var o_v := absf(o.velocidade())
		var jo := janela(o_mov, cf.z, cf.w, o_s, o_v, o_ia.reacao_restante())
		var je := janela(mov, cf.x, cf.y, s, v, reacao)
		if not _precede(o_ia, o_mov, o_vez, o_ia.pub_desde, jo.x, eu, mov, eu.pub_desde,
				je.x, sinal, pref):
			continue
		if je.y + pet <= jo.x or jo.y + PET_DEPOIS <= je.x:
			continue
		ultimo_motivo = "%s (%s, entra %.1f s, sai %.1f s; eu %.1f-%.1f)" % [o.name,
			MotoristaIA.Vez.keys()[o_vez], jo.x, jo.y, je.x, je.y]
		return Veredito.CEDE_CARRO
	return Veredito.LIVRE


static func _rank(tipo: int) -> int:
	return 1 if tipo == Movimento.Tipo.ESQUERDA else 0


## O outro (`o`) tem a vez sobre `eu`? Ver o cabecalho. Estrita: de cada par, so
## um e verdadeiro.
static func _precede(o: MotoristaIA, o_mov: Movimento, o_vez: int, o_desde: float,
		o_t: float, eu: MotoristaIA, mov: Movimento, eu_desde: float, eu_t: float,
		sinal: bool, pref: int) -> bool:
	var eu_vez := eu.pub_vez
	var o_dentro := o_vez == MotoristaIA.Vez.DENTRO
	var eu_dentro := eu_vez == MotoristaIA.Vez.DENTRO
	if o_dentro != eu_dentro:
		return o_dentro
	var mesmo_eixo := o_mov.chegada.z == mov.chegada.z
	if not sinal and not o_dentro:
		var o_pref := o_mov.chegada.z == pref
		var eu_pref := mov.chegada.z == pref
		if o_pref != eu_pref:
			return o_pref
		if not eu_pref:
			# Dois PAREs: quem parou primeiro sai primeiro.
			if o_desde >= 0.0 and (eu_desde < 0.0 or o_desde < eu_desde - 0.3):
				return true
			if eu_desde >= 0.0 and (o_desde < 0.0 or eu_desde < o_desde - 0.3):
				return false
	if mesmo_eixo:
		var ro := _rank(o_mov.tipo)
		var re := _rank(mov.tipo)
		if ro != re:
			return ro < re
	if absf(o_t - eu_t) > 0.3:
		return o_t < eu_t
	return o.carro.get_instance_id() < eu.carro.get_instance_id()


## Um carro sem plano neste cruzamento, pelo que se ve: parado em cima do
## caminho e OCUPADO; andando, a lataria dele e um segmento que segue reto na
## velocidade dele, e a janela sai de quando esse segmento cruza os discos do
## caminho. Ninguem tem a vez sobre ele: quem nao se sabe o que vai fazer, se
## espera (e o que o motorista de verdade faz com o carro que vem sem seta).
static func _sem_plano(mov: Movimento, s: float, v: float, reacao: float, o: Carro,
		pet: float) -> int:
	var vel := MotoristaIA._velocidade_de(o)
	var rapidez := vel.length()
	var op := Vector2(o.global_position.x, o.global_position.z)
	var fo := -o.global_transform.basis.z
	var h := Vector2(fo.x, fo.z).normalized()
	var meia_c := float(o._medidas.get("comprimento", 4.5)) * 0.5
	var r_soma := Movimento.RAIO + float(o._medidas.get("largura", 1.8)) * 0.5 + Movimento.FOLGA
	var t_in := INF
	var t_out := -INF
	var s_in := INF
	var s_out := -INF
	var vh := vel / rapidez if rapidez > 0.5 else h
	for k in range(mov._k0, mov._s.size()):
		var sk := mov._s[k]
		if sk < s - 1.0:
			continue
		for u in 3:
			var rel := mov._d[3 * k + u] - op
			if rapidez < 0.5:
				var al := clampf(rel.dot(h), -meia_c, meia_c)
				if (rel - h * al).length_squared() < r_soma * r_soma:
					s_in = minf(s_in, sk)
					s_out = maxf(s_out, sk)
					t_in = 0.0
					t_out = INF
			else:
				var x := rel.dot(vh)
				var y := absf(rel.cross(vh))
				if y >= r_soma:
					continue
				var dx := sqrt(r_soma * r_soma - y * y) + meia_c
				var ta := (x - dx) / rapidez
				var tb := (x + dx) / rapidez
				if tb < 0.0 or ta > HORIZONTE:
					continue
				t_in = minf(t_in, maxf(ta, 0.0))
				t_out = maxf(t_out, tb)
				s_in = minf(s_in, sk)
				s_out = maxf(s_out, sk)
	if s_in == INF:
		return Veredito.LIVRE
	if t_out == INF:
		return Veredito.OCUPADO
	var je := janela(mov, s_in, s_out, s, v, reacao)
	if je.y + pet <= t_in or t_out + PET_DEPOIS <= je.x:
		return Veredito.LIVRE
	return Veredito.CEDE_CARRO


# --- pedestre -------------------------------------------------------------------

## Onde parar por causa de gente numa zebra do caminho: o `s` (do movimento) em
## que a lataria comecaria a cobrir essa zebra, ou INF.
static func pedestre(eu: MotoristaIA, mov: Movimento, s: float, v: float) -> float:
	var reacao := eu.reacao_restante()
	var arvore := eu.carro.get_tree()
	var c := Vector2(float(mov.ij.x) * Vias.TAM, float(mov.ij.y) * Vias.TAM)
	var perto: Array[Node3D] = []
	for no: Node in arvore.get_nodes_in_group(&"pedestre"):
		var n3 := no as Node3D
		if n3 != null and is_instance_valid(n3) and Vector2(n3.global_position.x,
				n3.global_position.z).distance_squared_to(c) < ALCANCE_PEDESTRE * ALCANCE_PEDESTRE:
			perto.append(n3)
	# O jogador a pe (dentro de um carro ele e o carro).
	var jogador := arvore.get_first_node_in_group(&"player") as CharacterBody3D
	if jogador != null and jogador.is_inside_tree() and jogador.visible and Vector2(
			jogador.global_position.x, jogador.global_position.z).distance_squared_to(c) \
			< ALCANCE_PEDESTRE * ALCANCE_PEDESTRE:
		perto.append(jogador)
	if perto.is_empty():
		return INF
	var melhor := INF
	for qual in 2:
		var w: Vector4 = mov.z_chegada if qual == 0 else mov.z_saida
		if w.x == INF or s > w.y:
			continue
		var z := Esquina.zebra(mov.ij, Esquina.braco_de_chegada(mov.chegada) if qual == 0
			else Esquina.braco_de_saida(mov.saida))
		var je := janela(mov, w.x, w.y, s, v, reacao)
		for n3: Node3D in perto:
			if _pessoa_na_faixa(n3, z, w.z - PED_MARGEM, w.w + PED_MARGEM, je):
				ultimo_motivo = "pedestre %s na zebra %s" % [n3.name, Esquina.Braco.keys()[z.braco]]
				melhor = minf(melhor, w.x)
				break
	return melhor


## A pessoa `n3` estara na faixa `z`, entre `u_lo` e `u_hi` de atravessado,
## enquanto o carro passa por ela (janela `je`, com `antes` antes e `depois`
## depois)? Quem esta atravessando esta zebra anda na velocidade da travessia, e
## nao na do quadro: no primeiro passo ela ainda e zero, e o carro que previa a
## pessoa parada na calcada decidia passar e freava forte um quadro depois.
static func _pessoa_na_faixa(n3: Node3D, z: Esquina.Zebra, u_lo: float, u_hi: float,
		je: Vector2, antes := PED_ANTES, depois := PED_DEPOIS) -> bool:
	var p := Vector2(n3.global_position.x, n3.global_position.z)
	var vel := Vector2.ZERO
	var trav: TravessiaDePedestre = null
	var ped := n3 as Pedestre
	if ped != null:
		trav = ped._travessia
		if ped.de_pe():
			vel = Vector2(ped.velocity.x, ped.velocity.z)
	elif n3 is CharacterBody3D:
		var cb := n3 as CharacterBody3D
		vel = Vector2(cb.velocity.x, cb.velocity.z)
	if trav != null and trav.esperando():
		return false
	if trav != null and trav.zebra == z and ped.estado_nome() == &"andando":
		vel = trav.velocidade_prevista()
	var ac0 := z.atravessado(p)
	if trav == null or trav.zebra != z:
		# Sem travessia nesta zebra (o pedestre antigo, quem levou susto, o
		# jogador): conta quem esta no asfalto ou descendo para ele.
		var al0 := z.ao_longo(p)
		if al0 < z.lo - PED_FAIXA - 0.5 or al0 > z.hi + PED_FAIXA + 0.5:
			return false
		if absf(ac0) > z.meia + 1.0:
			return false
		if absf(ac0) > z.meia and vel.dot(z.u) * signf(ac0) > -0.3:
			return false
	var t := maxf(0.0, je.x - antes)
	var t1 := minf(je.y + depois, HORIZONTE)
	while t <= t1:
		var q := p + vel * t
		var al := z.ao_longo(q)
		var ac := z.atravessado(q)
		if al >= z.lo - PED_FAIXA and al <= z.hi + PED_FAIXA and ac >= u_lo and ac <= u_hi:
			return true
		t += 0.25
	return false

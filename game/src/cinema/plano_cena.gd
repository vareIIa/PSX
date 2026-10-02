## O vocabulario de planos da cena cortada.
##
## A Cinematica sabe por a camera num ponto e mover entre dois. Isto sabe ONDE
## por a camera para um plano com nome — close no Berg, dois-shot dentro do
## carro, grua subindo para o ceu — a partir de quem esta em cena. O roteiro
## escreve `Cinema.plano(PlanoCena.Tipo.CLOSE, berg)` e nao um Vector3.
##
## Calcular a partir dos atores, e nao gravar posicao, e obrigatorio aqui: a
## cidade e gerada, entao a casa da fumaca e a calcada em frente a ela nunca
## estao no mesmo lugar duas partidas seguidas. Movimento de camera em curva
## (grua, acompanhamento) reaproveita `TrilhoDeCamera`.
##
## Regra dos 180 graus
## -------------------
## Com dois em cena, a linha de acao e a reta entre eles, e `opcoes.lado` (-1 ou
## 1) escolhe de que lado dela a camera fica. O roteiro passa o MESMO lado para
## todos os planos de uma conversa, inclusive no contraplano (o lado e da
## linha, nao de quem e o alvo), e o lado so muda num corte motivado (alguem
## atravessou a linha). Sem isso o Berg olha para a direita num plano e para a
## esquerda no seguinte, e o jogador perde quem esta falando com quem. Com um so
## em cena a linha e o ombro direito dele.
##
## Oclusao
## -------
## A cidade e gerada, entao nao ha como saber se atras do Berg tem um muro.
## Todo plano lanca um raio do assunto ate a lente; se bater em alguma coisa,
## a camera vem para a frente do obstaculo. Close dentro de uma sala de 3 m nao
## pode nascer do outro lado da parede.
class_name PlanoCena
extends RefCounted

enum Tipo {
	ESTABELECIMENTO,   ## geral do lugar, alto e longe
	DOIS_MEDIO,        ## dois personagens da cintura para cima
	CLOSE,             ## rosto e ombros
	CLOSE_EXTREMO,     ## so olhos, ou so a mao, ou so o oculos
	SOBRE_OMBRO,       ## por cima do ombro de `outro`, olhando `alvo`
	CONTRA_PLONGEE,    ## de baixo para cima (low angle)
	PLONGEE,           ## de cima para baixo (high angle)
	CARRO_INTERIOR,    ## dentro do carro, pelo para-brisa, os dois bancos
	CEU_GRUA,          ## grua subindo ate o ceu, alvo ficando pequeno
	ACOMPANHAMENTO,    ## tracking: segue `alvo` andando ou o carro rodando
	DOLLY_IN,          ## aproxima devagar
	DOLLY_OUT,         ## afasta devagar
	POV,               ## o olho de `alvo`, olhando para `outro`
}

## Lente de cada tipo (fov vertical), da tabela de vocabulario do roteiro,
## secao 0.
const FOV := {
	Tipo.ESTABELECIMENTO: 68.0, Tipo.DOIS_MEDIO: 50.0, Tipo.CLOSE: 34.0,
	Tipo.CLOSE_EXTREMO: 22.0, Tipo.SOBRE_OMBRO: 42.0, Tipo.CONTRA_PLONGEE: 55.0,
	Tipo.PLONGEE: 55.0, Tipo.CARRO_INTERIOR: 78.0, Tipo.CEU_GRUA: 60.0,
	Tipo.ACOMPANHAMENTO: 58.0, Tipo.DOLLY_IN: 45.0, Tipo.DOLLY_OUT: 45.0,
	Tipo.POV: 70.0,
}

## Duracao de um plano movel quando o roteiro passa zero. Plano fixo com zero
## corta e devolve na hora; plano movel com zero nao teria movimento nenhum.
const DURACAO_MOVEL := {
	Tipo.ESTABELECIMENTO: 4.0, Tipo.CEU_GRUA: 6.0, Tipo.ACOMPANHAMENTO: 5.0,
	Tipo.DOLLY_IN: 4.0, Tipo.DOLLY_OUT: 4.0,
}

## Altura dos olhos de quem esta de pe. O Corpo tem 1,7 m com a cabeca; o olho
## fica um palmo abaixo do topo.
const OLHO := 1.58
## Quanto acima do olho fica o meio de um rosto em close: o olho no terco de
## cima do quadro, e nao no meio, que e onde o rosto fica com cara de foto 3x4.
const TERCO := 0.04
## Assento ate o olho de quem esta sentado no carro.
const OLHO_SENTADO := 0.74
## O raio de oclusao para esta distancia antes do obstaculo, para a lente nao
## encostar no reboco e pegar a face de tras da parede.
const FOLGA_OCLUSAO := 0.18
## Mais perto que isto do assunto a camera nao chega nem fugindo de parede: um
## close a 30 cm vira um olho do tamanho da tela.
const MINIMO_OCLUSAO := 0.45
## Largura sobre altura da imagem entre as tarjas (480 por 270 menos duas de
## 33). O mesmo numero de `Cinematica.FORMATO`, que nao tem class_name.
const FORMATO := 480.0 / (270.0 - 66.0)
## Camada 1 e o mundo (parede, muro, carro). Personagem tambem esta nela, por
## isso quem esta em cena entra na lista de excecoes do raio.
const MASCARA_OCLUSAO := 1


## Enquadramento calculado. Chaves:
##   de, para: Vector3        camera e ponto olhado no inicio
##   ate, para_ate: Vector3   fim do movimento (iguais ao inicio em plano fixo)
##   meio: Vector3            ponto do meio da curva (so CEU_GRUA)
##   fov, fov_ate: float
##   movel: bool              se a camera anda durante `duracao`
##   duracao: float           duracao padrao do movimento (plano movel)
##   seguir: Node3D           para ACOMPANHAMENTO, quem a camera persegue
##   local_de, local_para     ACOMPANHAMENTO: lente e mira no espaco de `seguir`
##   foco: float              distancia de foco (so close, close extremo e
##                            sobre o ombro; 0 = tudo nitido)
##   ocluido: bool            o raio bateu e a camera foi trazida para a frente
## `opcoes` aceita: lado (-1/1), altura, distancia, fov, foco (false desliga),
## ponto (Vector3 do mundo a enquadrar no close extremo), de_tras (bool, carro
## por tras), olhar_ceu (bool, grua termina olhando o ceu), carro (Carro),
## excluir (Array de CollisionObject3D que o raio ignora), sem_oclusao (bool).
static func calcular(tipo: Tipo, alvo: Node3D, outro: Node3D = null,
		opcoes: Dictionary = {}) -> Dictionary:
	var q: Dictionary
	match tipo:
		Tipo.ESTABELECIMENTO:
			q = _estabelecimento(alvo, outro, opcoes)
		Tipo.DOIS_MEDIO:
			q = _dois_medio(alvo, outro, opcoes)
		Tipo.CLOSE:
			q = _close(alvo, outro, opcoes, 1.15)
		Tipo.CLOSE_EXTREMO:
			q = _close_extremo(alvo, outro, opcoes)
		Tipo.SOBRE_OMBRO:
			q = _sobre_ombro(alvo, outro, opcoes)
		Tipo.CONTRA_PLONGEE:
			q = _angulo(alvo, outro, opcoes, true)
		Tipo.PLONGEE:
			q = _angulo(alvo, outro, opcoes, false)
		Tipo.CARRO_INTERIOR:
			q = _carro_interior(alvo, outro, opcoes)
		Tipo.CEU_GRUA:
			q = _grua(alvo, outro, opcoes)
		Tipo.ACOMPANHAMENTO:
			q = _acompanhamento(alvo, outro, opcoes)
		Tipo.DOLLY_IN, Tipo.DOLLY_OUT:
			q = _dolly(alvo, outro, opcoes, tipo == Tipo.DOLLY_IN)
		Tipo.POV:
			q = _pov(alvo, outro, opcoes)
		_:
			q = _close(alvo, outro, opcoes, 2.4)

	# Valores que todo plano tem, para o Cinema nao precisar de `get` com padrao.
	var fov := float(opcoes.get("fov", FOV.get(tipo, 55.0)))
	if not q.has("fov"):
		q["fov"] = fov
	if not q.has("fov_ate"):
		q["fov_ate"] = q["fov"]
	if not q.has("ate"):
		q["ate"] = q["de"]
	if not q.has("para_ate"):
		q["para_ate"] = q["para"]
	if not q.has("movel"):
		q["movel"] = false
	q["duracao"] = float(DURACAO_MOVEL.get(tipo, 0.0)) if bool(q["movel"]) else 0.0
	q["tipo"] = tipo
	if opcoes.get("foco", true) is bool and not bool(opcoes.get("foco", true)):
		q["foco"] = 0.0
	elif not q.has("foco"):
		q["foco"] = 0.0
	q["ocluido"] = false

	# POV e interior de carro nascem dentro de alguma coisa de proposito: o raio
	# bateria no proprio carro, ou na cabeca de quem olha.
	if not bool(opcoes.get("sem_oclusao", false)) and tipo != Tipo.POV \
			and tipo != Tipo.CARRO_INTERIOR and tipo != Tipo.ACOMPANHAMENTO:
		var excluir := _excecoes(alvo, outro, opcoes)
		var de_livre := desocluir(alvo, q["para"], q["de"], excluir)
		if de_livre != q["de"]:
			q["ocluido"] = true
			# O movimento inteiro anda junto, para o dolly nao comecar livre e
			# terminar dentro da parede (ou o contrario).
			q["de"] = de_livre
			if not bool(q["movel"]):
				q["ate"] = de_livre
		if bool(q["movel"]):
			# Do assunto, e nao da mira final: a grua que termina olhando o ceu
			# lancaria o raio de um ponto no ar.
			var ate_livre := desocluir(alvo, q["para"], q["ate"], excluir)
			if ate_livre != q["ate"]:
				q["ocluido"] = true
				q["ate"] = ate_livre
	return q


## Traz a lente para a frente do primeiro obstaculo entre o assunto e ela.
## Devolve `lente` se o caminho estiver livre.
static func desocluir(no: Node3D, assunto: Vector3, lente: Vector3,
		excluir: Array[RID] = []) -> Vector3:
	if no == null or not no.is_inside_tree():
		return lente
	var mundo := no.get_world_3d()
	if mundo == null:
		return lente
	var espaco := mundo.direct_space_state
	if espaco == null:
		return lente
	var consulta := PhysicsRayQueryParameters3D.create(assunto, lente,
		MASCARA_OCLUSAO, excluir)
	consulta.collide_with_areas = false
	var bateu := espaco.intersect_ray(consulta)
	if bateu.is_empty():
		return lente
	var ponto: Vector3 = bateu["position"]
	var dir := (lente - assunto).normalized()
	var dist := maxf(MINIMO_OCLUSAO, assunto.distance_to(ponto) - FOLGA_OCLUSAO)
	return assunto + dir * dist


# --- ajudantes --------------------------------------------------------------

## O olho de alguem, no mundo. Carro: o meio do teto. Ator sentado: o Corpo
## sabe onde a cabeca esta melhor que uma constante.
static func olho_de(no: Node3D) -> Vector3:
	if no == null:
		return Vector3.ZERO
	if no is Carro:
		var m := (no as Carro).medidas()
		return no.global_position + Vector3.UP * float(m.get("altura", 1.4)) * 0.7
	var cabeca := _cabeca(no)
	if cabeca != Vector3.INF:
		return cabeca
	return no.global_position + Vector3.UP * OLHO


## A cabeca pelo esqueleto, quando o no tem um Corpo montado. Personagem
## sentado, agachado ou deitado no chao da praca nao tem o olho a 1,58 m.
static func _cabeca(no: Node3D) -> Vector3:
	if not no.has_method("corpo"):
		return Vector3.INF
	var c := no.call("corpo") as Corpo
	if c == null or not c.is_inside_tree():
		return Vector3.INF
	var sk := c.esqueleto()
	if sk == null or not sk.is_inside_tree() or sk.get_bone_count() <= Corpo.Osso.CABECA:
		return Vector3.INF
	var p := (sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.CABECA)).origin
	# A raiz do osso da cabeca e o pescoco; o olho fica um palmo acima.
	return p + Vector3.UP * 0.1


## Para onde o no olha, no chao. Godot olha para -Z.
static func frente_de(no: Node3D) -> Vector3:
	var f := -no.global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return Vector3.FORWARD
	return f.normalized()


## O lado da linha de acao, ja com `opcoes.lado`. Com dois em cena e a normal da
## reta entre eles; com um so, a direita dele.
static func _lado(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Vector3:
	var s := signf(float(opcoes.get("lado", 1.0)))
	if s == 0.0:
		s = 1.0
	if outro != null:
		# A reta vai sempre do mesmo para o mesmo (ordem fixa entre os dois), e
		# nao de `alvo` para `outro`: assim plano e contraplano, que trocam
		# alvo e outro, recebem o MESMO `lado` do roteiro e caem do mesmo lado.
		var de := alvo
		var ate := outro
		if outro.get_instance_id() < alvo.get_instance_id():
			de = outro
			ate = alvo
		var eixo := ate.global_position - de.global_position
		eixo.y = 0.0
		if eixo.length_squared() > 0.0004:
			return eixo.normalized().cross(Vector3.UP) * s
	return frente_de(alvo).cross(Vector3.UP) * s


static func _excecoes(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Array[RID]:
	var r: Array[RID] = []
	for no: Variant in [alvo, outro, opcoes.get("carro", null)]:
		if no is Node:
			_coletar_rids(no as Node, r)
	for no: Variant in opcoes.get("excluir", []):
		if no is Node:
			_coletar_rids(no as Node, r)
	# O jogador e quase sempre o `outro` ou a nuca em primeiro plano. Quando
	# nao e, ainda assim a capsula dele nao e parede.
	var arvore := alvo.get_tree() if alvo != null and alvo.is_inside_tree() else null
	if arvore != null:
		for j: Node in arvore.get_nodes_in_group(&"player"):
			_coletar_rids(j, r)
	return r


static func _coletar_rids(no: Node, r: Array[RID]) -> void:
	if no is CollisionObject3D:
		r.append((no as CollisionObject3D).get_rid())
	for f: Node in no.get_children():
		_coletar_rids(f, r)


static func _carro(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Carro:
	var c: Variant = opcoes.get("carro", null)
	if c is Carro:
		return c as Carro
	for no: Node3D in [alvo, outro]:
		var p: Node = no
		while p != null:
			if p is Carro:
				return p as Carro
			p = p.get_parent()
	return null


# --- os planos --------------------------------------------------------------

static func _estabelecimento(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Dictionary:
	var centro := alvo.global_position
	if outro != null:
		centro = centro.lerp(outro.global_position, 0.5)
	var lado := _lado(alvo, outro, opcoes)
	var frente := frente_de(alvo)
	var dist := float(opcoes.get("distancia", 14.0))
	var alto := float(opcoes.get("altura", 6.5))
	# Diagonal (lado e frente), e nao de frente: geral de frente e cartao-postal,
	# na diagonal o lugar tem profundidade e a nevoa tem onde aparecer.
	var dir := (lado * 0.8 + frente * 0.6).normalized()
	var de := centro + dir * dist + Vector3.UP * alto
	var para := centro + Vector3.UP * 1.2
	# Deriva lenta de lado: geral parado em PSX parece tela de carregamento.
	var ate := de + lado.cross(Vector3.UP).normalized() * 1.6 - dir * 1.2
	return {"de": de, "para": para, "ate": ate, "para_ate": para, "movel": true}


static func _dois_medio(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Dictionary:
	if outro == null:
		return _close(alvo, null, opcoes, float(opcoes.get("distancia", 2.6)))
	var a := alvo.global_position
	var b := outro.global_position
	var meio := a.lerp(b, 0.5)
	var sep := Vector2(b.x - a.x, b.z - a.z).length()
	var fov := float(opcoes.get("fov", FOV[Tipo.DOIS_MEDIO]))
	# Distancia para os dois caberem com folga de meio corpo de cada lado, pelo
	# fov horizontal (16:9 menos as tarjas da 2,35).
	var meia_h := atan(tan(deg_to_rad(fov) * 0.5) * FORMATO)
	var dist := float(opcoes.get("distancia",
		maxf(2.4, (sep * 0.5 + 0.55) / tan(meia_h) + 0.3)))
	var alt := float(opcoes.get("altura", 1.42))
	var de := meio + _lado(alvo, outro, opcoes) * dist + Vector3.UP * alt
	var para := meio + Vector3.UP * 1.32
	return {"de": de, "para": para}


## Close de frente para o rosto. Com `outro`, a lente fica perto da linha do
## olhar entre os dois (o personagem olha QUASE para a camera, como no cinema);
## sem `outro`, um pouco para o lado da direita dele.
static func _close(alvo: Node3D, outro: Node3D, opcoes: Dictionary, dist_padrao: float) -> Dictionary:
	var olho := olho_de(alvo)
	var dir: Vector3
	if outro != null:
		var para_outro := olho_de(outro) - olho
		para_outro.y = 0.0
		dir = para_outro.normalized() if para_outro.length_squared() > 0.0004 else frente_de(alvo)
		dir = (dir + _lado(alvo, outro, opcoes) * 0.38).normalized()
	else:
		dir = (frente_de(alvo) + _lado(alvo, null, opcoes) * 0.3).normalized()
	var dist := float(opcoes.get("distancia", dist_padrao))
	var alt := float(opcoes.get("altura", 0.0))
	var de := olho + dir * dist + Vector3.UP * alt
	var para := olho + Vector3.UP * TERCO
	return {"de": de, "para": para, "foco": dist}


static func _close_extremo(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Dictionary:
	var p: Variant = opcoes.get("ponto", null)
	if p is Vector3:
		# Objeto (mao, papel, oculos): de cima e de lado, como inserto.
		var ponto: Vector3 = p
		var dist := float(opcoes.get("distancia", 0.55))
		var dir := (frente_de(alvo) + _lado(alvo, outro, opcoes) * 0.5 + Vector3.UP * 0.6).normalized()
		return {"de": ponto + dir * dist, "para": ponto, "foco": dist}
	var q := _close(alvo, outro, opcoes, 0.6)
	# Nos olhos, e nao no terco: close extremo e a faixa dos olhos.
	q["para"] = olho_de(alvo)
	return q


static func _sobre_ombro(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Dictionary:
	if outro == null:
		return _close(alvo, null, opcoes, 1.4)
	var olho_a := olho_de(alvo)
	var olho_o := olho_de(outro)
	var eixo := olho_a - olho_o
	eixo.y = 0.0
	var dir := eixo.normalized() if eixo.length_squared() > 0.0004 else frente_de(outro)
	var lado := _lado(alvo, outro, opcoes)
	# Atras e ao lado da nuca de quem escuta, um palmo acima do ombro dele.
	var atras := float(opcoes.get("distancia", 0.75))
	var de := olho_o - dir * atras + lado * 0.42 + Vector3.UP * float(opcoes.get("altura", 0.08))
	var para := olho_a + Vector3.UP * TERCO - lado * 0.08
	return {"de": de, "para": para, "foco": de.distance_to(para)}


static func _angulo(alvo: Node3D, outro: Node3D, opcoes: Dictionary, de_baixo: bool) -> Dictionary:
	var olho := olho_de(alvo)
	var chao := alvo.global_position
	var dir := (frente_de(alvo) + _lado(alvo, outro, opcoes) * 0.45).normalized()
	if de_baixo:
		# Lente no joelho olhando a cabeca e o ceu atras dela: e o plano que faz
		# o Berg encostado no carro ficar maior que a cidade.
		var dist := float(opcoes.get("distancia", 1.9))
		var de := chao + dir * dist + Vector3.UP * float(opcoes.get("altura", 0.42))
		return {"de": de, "para": olho + Vector3.UP * 0.12}
	var dist_p := float(opcoes.get("distancia", 2.2))
	var de_p := chao + dir * dist_p + Vector3.UP * float(opcoes.get("altura", 3.7))
	return {"de": de_p, "para": chao.lerp(olho, 0.55)}


## Dentro do carro. Padrao: no painel, de costas para o para-brisa, os dois
## bancos da frente no quadro. `de_tras`: do banco de tras, as duas nucas e a
## rua pelo para-brisa.
static func _carro_interior(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Dictionary:
	var carro := _carro(alvo, outro, opcoes)
	if carro == null:
		return _dois_medio(alvo, outro, opcoes)
	var m := carro.medidas()
	var comp := float(m.get("comprimento", 4.4))
	var banco: Vector3 = m.get("banco_motorista", Vector3(-0.4, 0.46, -comp * 0.04))
	var base: Vector2 = m.get("vidro_base", Vector2(-comp * 0.2, 0.95))
	var topo: Vector2 = m.get("vidro_topo", Vector2(-comp * 0.05, 1.32))
	var olhos_y := banco.y + OLHO_SENTADO
	var mira := Vector3(0.0, olhos_y - 0.06, banco.z)
	var de_local: Vector3
	var para_local: Vector3
	if bool(opcoes.get("de_tras", false)):
		de_local = Vector3(0.0, olhos_y + 0.04, banco.z + 0.95)
		para_local = Vector3(0.0, olhos_y - 0.05, base.x - 1.5)
	else:
		# Logo atras do vidro, no meio da altura dele. A lente e grande-angular
		# (78) porque a cabine tem 1,4 m de largura e os dois tem de caber.
		var z := lerpf(base.x, topo.x, 0.45) + 0.16
		var y := minf(lerpf(base.y, topo.y, 0.45), olhos_y + 0.02)
		de_local = Vector3(0.0, y, z)
		para_local = mira
	# `lado` aqui puxa a lente para um dos dois bancos: -1 o motorista no meio,
	# 1 o carona.
	if opcoes.has("lado"):
		var s := signf(float(opcoes["lado"]))
		de_local.x = absf(banco.x) * 0.45 * s
	var xf := carro.global_transform
	return {"de": xf * de_local, "para": xf * para_local,
		"seguir": carro, "local_de": de_local, "local_para": para_local}


static func _grua(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Dictionary:
	var centro := alvo.global_position
	if outro != null:
		centro = centro.lerp(outro.global_position, 0.5)
	var lado := _lado(alvo, outro, opcoes)
	var frente := frente_de(alvo)
	var dir := (frente * 0.7 + lado * 0.7).normalized()
	var alto := float(opcoes.get("altura", 16.0))
	var dist := float(opcoes.get("distancia", 3.6))
	var de := centro + dir * dist + Vector3.UP * 1.7
	# Sobe e recua: a grua de verdade sobe num arco, e o assunto vai ficando
	# pequeno no meio do quadro em vez de sair por baixo dele.
	var ate := centro + dir * (dist + alto * 0.35) + Vector3.UP * alto
	var meio := de.lerp(ate, 0.5) + dir * 1.2 - Vector3.UP * alto * 0.12
	var para := centro + Vector3.UP * 1.4
	var para_ate := centro + Vector3.UP * 0.9
	if bool(opcoes.get("olhar_ceu", false)):
		# Termina no ceu: a mira passa por cima do assunto e sobe.
		para_ate = centro - dir * 30.0 + Vector3.UP * (alto + 22.0)
	return {"de": de, "para": para, "ate": ate, "para_ate": para_ate, "meio": meio,
		"movel": true, "fov_ate": float(opcoes.get("fov", FOV[Tipo.CEU_GRUA])) + 6.0}


## Tracking. A lente fica num ponto FIXO no espaco do alvo (atras e ao lado) e
## o Cinema persegue esse ponto a cada quadro, com atraso de mao.
static func _acompanhamento(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Dictionary:
	var s := signf(float(opcoes.get("lado", 1.0)))
	if s == 0.0:
		s = 1.0
	var de_local: Vector3
	var para_local: Vector3
	if alvo is Carro:
		# Carro andando: tres quartos de tras, baixo, como camera de reboque.
		var m := (alvo as Carro).medidas()
		var comp := float(m.get("comprimento", 4.4))
		var d := float(opcoes.get("distancia", comp * 1.15))
		de_local = Vector3(s * 2.6, float(opcoes.get("altura", 1.35)), comp * 0.5 + d)
		para_local = Vector3(0.0, 0.8, -comp * 0.5)
	else:
		# Gente andando: na frente e ao lado, de costas para onde ela vai. O rosto
		# vem para a camera, que recua no passo dela.
		var d2 := float(opcoes.get("distancia", 2.8))
		de_local = Vector3(s * 0.9, float(opcoes.get("altura", 1.55)), -d2)
		para_local = Vector3(0.0, 1.35, 0.0)
	var xf := alvo.global_transform
	var de := xf * de_local
	var para := xf * para_local
	if outro != null:
		# Com `outro` (quem anda junto), a mira fica entre os dois.
		para = para.lerp(olho_de(outro) - Vector3.UP * 0.2, 0.5)
	return {"de": de, "para": para, "ate": de, "para_ate": para, "movel": true,
		"seguir": alvo, "local_de": de_local, "local_para": para_local}


static func _dolly(alvo: Node3D, outro: Node3D, opcoes: Dictionary, entra: bool) -> Dictionary:
	var olho := olho_de(alvo)
	var dir := frente_de(alvo)
	if outro != null:
		var e := olho_de(outro) - olho
		e.y = 0.0
		if e.length_squared() > 0.0004:
			dir = e.normalized()
	dir = (dir + _lado(alvo, outro, opcoes) * 0.2).normalized()
	var longe := float(opcoes.get("distancia", 3.8))
	var perto := float(opcoes.get("perto", 1.3))
	var alt := float(opcoes.get("altura", 0.0))
	var a := olho + dir * longe + Vector3.UP * alt
	var b := olho + dir * perto + Vector3.UP * alt
	var para := olho + Vector3.UP * TERCO
	var fov := float(opcoes.get("fov", FOV[Tipo.DOLLY_IN]))
	# Um pouco de zoom junto com o carrinho: o fundo "respira" (vertigo leve),
	# que e o que diferencia dolly de zoom digital.
	if entra:
		return {"de": a, "para": para, "ate": b, "para_ate": para, "movel": true,
			"fov": fov, "fov_ate": fov - 4.0}
	return {"de": b, "para": para, "ate": a, "para_ate": para, "movel": true,
		"fov": fov - 4.0, "fov_ate": fov}


static func _pov(alvo: Node3D, outro: Node3D, opcoes: Dictionary) -> Dictionary:
	var olho := olho_de(alvo)
	# Um dedo a frente do olho, para a lente nao enxergar o proprio cabelo.
	var de := olho + frente_de(alvo) * 0.12
	var para: Vector3
	var p: Variant = opcoes.get("ponto", null)
	if p is Vector3:
		para = p
	elif outro != null:
		para = olho_de(outro)
	else:
		para = olho + frente_de(alvo) * 5.0
	return {"de": de, "para": para}

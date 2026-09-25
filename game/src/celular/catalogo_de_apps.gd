## O que existe para o iPhone do jogo: cada app, o tamanho dele, quem o fez, o
## que ele faz e o icone.
##
## Por que o tamanho importa
## -------------------------
## O aparelho e de 8 GB e quase tudo ja esta tomado pelo sistema, pelas fotos e
## pelas musicas de quem era dono dele antes. Sobra pouco, e a App Store vende
## mais do que cabe: instalar a Cobrinha pede apagar alguma coisa. E essa
## escolha que faz da loja uma mecanica, e nao uma vitrine — o jogador decide o
## que o telefone dele e.
##
## Os apps do sistema (Telefone, Mensagens, Contatos, Mapas, Ajustes e a propria
## App Store) nao saem, como no iPhone de verdade. O resto sai, e volta pela loja
## quando fizer falta; os dados de cada um moram no mundo (a carteira do iWeed,
## a rede do Trampo, as notas), entao reinstalar devolve tudo.
##
## O icone e desenhado, e nao textura: vetor, nitido no vidro a qualquer
## distancia, no brilho do iOS 4 (degrade, a lamina de reflexo em arco em cima
## e a sombra embaixo).
class_name CatalogoDeApps
extends RefCounted

## Capacidade do aparelho e o que ja esta ocupado fora dos apps (MB). Com os
## apps que vem instalados sobram uns 200 MB: cabem todos os pequenos, e a
## Cobrinha so entra apagando um app grande.
const CAPACIDADE_MB := 7400.0
const SISTEMA_MB := 1380.0
const FOTOS_MB := 3910.0
const MUSICAS_MB := 1789.0

## Velocidade da rede ao baixar (MB/s) e o tempo minimo de uma instalacao (s):
## ate o app de 1 MB passa por "Carregando..." e "Instalando...", que e o que
## diz ao jogador que alguma coisa aconteceu.
const REDE_MB_S := 22.0
const INSTALA_MIN_S := 1.6

## Os apps. `sistema` nao sai do aparelho; `inicial` vem instalado.
const APPS := {
	&"telefone": {"nome": "Telefone", "dev": "Apple", "cat": "Utilitarios", "mb": 0.0,
		"sistema": true, "c1": Color("7fe36f"), "c2": Color("159a1f"),
		"sobre": "Ligue para quem esta na sua agenda."},
	&"mensagens": {"nome": "Mensagens", "dev": "Apple", "cat": "Redes Sociais", "mb": 0.0,
		"sistema": true, "c1": Color("8ae67a"), "c2": Color("1f9d2d"),
		"sobre": "Suas conversas."},
	&"contatos": {"nome": "Contatos", "dev": "Apple", "cat": "Utilitarios", "mb": 0.0,
		"sistema": true, "c1": Color("c8a47a"), "c2": Color("7a5431"),
		"sobre": "Todo mundo que voce conheceu na rua."},
	&"mapas": {"nome": "Mapas", "dev": "Apple", "cat": "Navegacao", "mb": 0.0,
		"sistema": true, "c1": Color("f1ecdc"), "c2": Color("d7cfb6"),
		"sobre": "O mapa da cidade, com rota ate onde voce precisa ir."},
	&"ajustes": {"nome": "Ajustes", "dev": "Apple", "cat": "Utilitarios", "mb": 0.0,
		"sistema": true, "c1": Color("b9bec6"), "c2": Color("5d636c"),
		"sobre": "Brilho, armazenamento, fundo de tela e o dono do aparelho."},
	&"loja": {"nome": "App Store", "dev": "Apple", "cat": "Utilitarios", "mb": 0.0,
		"sistema": true, "c1": Color("63c3fb"), "c2": Color("1360c9"),
		"sobre": "Baixe e instale aplicativos."},

	&"portal": {"nome": "Portal", "dev": "Prefeitura Municipal", "cat": "Governo",
		"mb": 12.4, "preco": 0, "inicial": true, "nota": 2.5, "votos": 1832,
		"c1": Color("3c9a63"), "c2": Color("14532f"), "versao": "3.1",
		"sobre": "Consulta de CPF do cidadao: nome, filiacao, endereco e quem mora no mesmo endereco. Entre com o seu CPF."},
	&"trampo": {"nome": "Trampo", "dev": "Trampo Tecnologia", "cat": "Negocios",
		"mb": 24.8, "preco": 0, "inicial": true, "nota": 4.0, "votos": 9120,
		"c1": Color("2f86d1"), "c2": Color("0e3a5b"), "versao": "5.4.2",
		"sobre": "Perfis de trabalho da cidade. Veja onde cada pessoa trabalha, o horario e se esta no expediente agora."},
	&"iweed": {"nome": "iWeed", "dev": "Verde Delivery", "cat": "Estilo de Vida",
		"mb": 38.2, "preco": 0, "inicial": true, "nota": 4.5, "votos": 420,
		"c1": Color("2d8a4e"), "c2": Color("0b2a17"), "versao": "1.0.9",
		"sobre": "Pedidos, equipe e carteira da sua estufa. Entrega discreta, cliente satisfeito."},

	&"radio": {"nome": "Radio FM", "dev": "Ondas Ltda", "cat": "Musica", "mb": 6.1,
		"preco": 0, "nota": 3.5, "votos": 2204, "c1": Color("ffb24a"), "c2": Color("c5461c"),
		"versao": "2.0",
		"sobre": "Liga e desliga o radio de pilha que voce carrega, sem tirar do bolso."},
	&"calculadora": {"nome": "Calculadora", "dev": "Pocket Labs", "cat": "Utilitarios",
		"mb": 1.2, "preco": 0, "nota": 4.5, "votos": 15230, "c1": Color("5a5f66"),
		"c2": Color("1d2024"), "versao": "1.4",
		"sobre": "Soma, subtrai, multiplica e divide. Use os numeros do teclado ou toque nas teclas."},
	&"notas": {"nome": "Notas", "dev": "Pocket Labs", "cat": "Produtividade", "mb": 3.4,
		"preco": 0, "nota": 4.0, "votos": 8611, "c1": Color("fff29a"), "c2": Color("e9c94a"),
		"versao": "2.2",
		"sobre": "Anote o que nao pode esquecer: um CPF, um endereco, um nome. As notas ficam no aparelho."},
	&"lanterna": {"nome": "Lanterna", "dev": "Luz & Cia", "cat": "Utilitarios", "mb": 0.9,
		"preco": 0, "nota": 4.5, "votos": 30512, "c1": Color("3a3f47"), "c2": Color("0c0e11"),
		"versao": "1.1",
		"sobre": "Acende o flash de LED atras do aparelho."},
	&"bussola": {"nome": "Bussola", "dev": "Norte Apps", "cat": "Navegacao", "mb": 2.1,
		"preco": 0, "nota": 3.5, "votos": 1310, "c1": Color("4a4f57"), "c2": Color("15171b"),
		"versao": "1.0",
		"sobre": "Para onde voce esta olhando. Funciona sem sinal."},
	&"tempo": {"nome": "Tempo", "dev": "Clima Brasil", "cat": "Clima", "mb": 9.8,
		"preco": 0, "nota": 3.0, "votos": 5120, "c1": Color("6cc1ff"), "c2": Color("1f6fd0"),
		"versao": "4.0.1",
		"sobre": "Chuva, neblina e a hora, agora e na sua rua."},
	&"cobrinha": {"nome": "Cobrinha", "dev": "Pixel Gordo Jogos", "cat": "Jogos",
		"mb": 236.0, "preco": 5, "nota": 5.0, "votos": 48210, "c1": Color("a6d86a"),
		"c2": Color("3e6b1e"), "versao": "3.0",
		"sobre": "O classico: coma, cresca e nao morda o proprio rabo. Setas ou analogico. Com recorde."},
}

## A ordem da loja em Destaques, e a primeira arrumacao da tela de inicio.
const DESTAQUES: Array[StringName] = [&"cobrinha", &"lanterna", &"notas", &"calculadora",
	&"tempo", &"bussola", &"radio", &"portal", &"trampo", &"iweed"]
const DOCK: Array[StringName] = [&"telefone", &"mensagens", &"contatos", &"loja"]
const INICIAIS: Array[StringName] = [&"portal", &"trampo", &"iweed", &"mapas",
	&"ajustes"]


static func existe(id: StringName) -> bool:
	return APPS.has(id)


static func dados(id: StringName) -> Dictionary:
	return APPS.get(id, {})


static func nome(id: StringName) -> String:
	return String(dados(id).get("nome", String(id)))


static func do_sistema(id: StringName) -> bool:
	return bool(dados(id).get("sistema", false))


static func tamanho(id: StringName) -> float:
	return float(dados(id).get("mb", 0.0))


static func preco(id: StringName) -> int:
	return int(dados(id).get("preco", 0))


## "12,4 MB" / "1,2 GB".
static func formatar_mb(mb: float) -> String:
	if mb >= 1000.0:
		return ("%.1f GB" % (mb / 1000.0)).replace(".", ",")
	if mb >= 100.0:
		return "%d MB" % roundi(mb)
	return ("%.1f MB" % mb).replace(".", ",")


static func rotulo_preco(id: StringName) -> String:
	var p := preco(id)
	return "GRATIS" if p <= 0 else Dinheiro.formatar(p)


# --- icones -----------------------------------------------------------------

## O icone do app `id` em `r` (quadrado), com o brilho do iOS 4. `k` e a
## opacidade; `cinza` desbota as cores (o app que ainda esta baixando).
static func icone(ci: CanvasItem, id: StringName, r: Rect2, k: float = 1.0,
		cinza: bool = false) -> void:
	var d := dados(id)
	var raio := r.size.x * 0.19
	var c1: Color = d.get("c1", Color("8a8f96"))
	var c2: Color = d.get("c2", Color("3b3f45"))
	if cinza:
		var neutro := Color(0.55, 0.57, 0.6)
		c1 = c1.lerp(neutro, 0.55)
		c2 = c2.lerp(neutro.darkened(0.4), 0.55)
	var pts := AppCelular.cantos(r, raio)
	var cores := PackedColorArray()
	for p: Vector2 in pts:
		var t := clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)
		cores.append(Color(c1.lerp(c2, t), k))
	ci.draw_polygon(pts, cores)
	_glifo(ci, id, r, k)
	_brilho(ci, r, raio, k)
	# O fio claro na borda de cima e o escuro embaixo: e o que da espessura.
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.28 * k), maxf(0.3, r.size.x * 0.012), true)


## A lamina de reflexo: a metade de cima clara, cortada por um arco largo que
## desce nas pontas. Degrade de 45% a 8% de branco.
static func _brilho(ci: CanvasItem, r: Rect2, raio: float, k: float) -> void:
	var pts := PackedVector2Array()
	var cores := PackedColorArray()
	var topo := AppCelular.cantos(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.62)), raio)
	# Os pontos de cima do contorno arredondado (os dois cantos de cima).
	var y_corte := r.position.y + r.size.y * 0.47
	for p: Vector2 in topo:
		if p.y <= r.position.y + raio + 0.001:
			pts.append(p)
	# Ordena da esquerda para a direita pelo topo.
	var ordenado := Array(pts)
	ordenado.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	pts = PackedVector2Array()
	for p: Vector2 in ordenado:
		pts.append(p)
	# O arco de baixo, da direita para a esquerda.
	var n := 12
	for i in n + 1:
		var u := 1.0 - float(i) / float(n)
		var x := r.position.x + r.size.x * u
		var curva := sin(u * PI)
		pts.append(Vector2(x, y_corte + r.size.y * 0.06 * curva - r.size.y * 0.1 * (1.0 - curva)))
	for p: Vector2 in pts:
		var t := clampf((p.y - r.position.y) / (y_corte - r.position.y + 0.001), 0.0, 1.0)
		cores.append(Color(1.0, 1.0, 1.0, lerpf(0.46, 0.07, t) * k))
	if pts.size() >= 3:
		ci.draw_polygon(pts, cores)


static func _glifo(ci: CanvasItem, id: StringName, r: Rect2, k: float) -> void:
	var c := r.get_center()
	var s := r.size.x
	var branco := Color(1.0, 1.0, 1.0, 0.96 * k)
	match id:
		&"telefone":
			_fone(ci, c, s * 0.3, branco)
		&"mensagens":
			var b := Rect2(c.x - s * 0.3, c.y - s * 0.24, s * 0.6, s * 0.42)
			ci.draw_colored_polygon(_elipse(b, 20), branco)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - s * 0.16, c.y + s * 0.1),
				Vector2(c.x - s * 0.24, c.y + s * 0.3), Vector2(c.x - s * 0.02, c.y + s * 0.15)]),
				branco)
		&"contatos":
			var pag := Rect2(r.position.x + s * 0.22, r.position.y + s * 0.14, s * 0.58, s * 0.72)
			ci.draw_colored_polygon(AppCelular.cantos(pag, s * 0.04), Color(0.96, 0.93, 0.86, k))
			for i in 4:
				ci.draw_rect(Rect2(pag.end.x, pag.position.y + s * (0.05 + 0.16 * i), s * 0.06,
					s * 0.12), Color(0.85, 0.3 + 0.12 * i, 0.25, k))
			var cor := Color(0.45, 0.33, 0.22, k)
			ci.draw_circle(Vector2(pag.get_center().x, pag.position.y + s * 0.24), s * 0.1, cor)
			ci.draw_colored_polygon(_elipse(Rect2(pag.get_center().x - s * 0.19,
				pag.position.y + s * 0.38, s * 0.38, s * 0.3), 16), cor)
			ci.draw_rect(Rect2(pag.position.x, pag.end.y - s * 0.12, pag.size.x, s * 0.12),
				Color(0.96, 0.93, 0.86, k))
		&"mapas":
			ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(s * 0.55, 0.0),
				r.position + Vector2(s, 0.0), r.position + Vector2(s, s * 0.45)]),
				Color(0.55, 0.78, 0.96, k))
			ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0.0, s * 0.62),
				r.position + Vector2(s * 0.38, s), r.position + Vector2(0.0, s)]),
				Color(0.62, 0.82, 0.5, k))
			ci.draw_line(r.position + Vector2(-s * 0.05, s * 0.3), r.position + Vector2(s * 1.05, s * 0.8),
				Color(1.0, 0.86, 0.35, k), s * 0.1)
			ci.draw_line(r.position + Vector2(s * 0.3, s * 1.05), r.position + Vector2(s * 0.62, -s * 0.05),
				Color(1.0, 1.0, 1.0, k), s * 0.07)
			_alfinete(ci, c + Vector2(s * 0.08, -s * 0.02), s * 0.13, Color(0.86, 0.12, 0.1, k))
		&"ajustes":
			_engrenagem(ci, c, s * 0.34, 12, Color(0.3, 0.32, 0.35, k), Color(0.78, 0.8, 0.83, k))
		&"loja":
			ci.draw_arc(c, s * 0.33, 0.0, TAU, 40, branco, s * 0.045, true)
			var w := s * 0.07
			ci.draw_line(c + Vector2(-s * 0.15, s * 0.19), c + Vector2(0.0, -s * 0.2), branco, w, true)
			ci.draw_line(c + Vector2(s * 0.15, s * 0.19), c + Vector2(0.0, -s * 0.2), branco, w, true)
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.06), c + Vector2(s * 0.2, s * 0.06), branco, w, true)
		&"portal":
			var card := Rect2(c.x - s * 0.3, c.y - s * 0.2, s * 0.6, s * 0.4)
			ci.draw_colored_polygon(AppCelular.cantos(card, s * 0.05), branco)
			ci.draw_rect(Rect2(card.position.x, card.position.y, card.size.x, s * 0.08),
				Color(1.0, 0.82, 0.2, k))
			ci.draw_circle(card.position + Vector2(s * 0.14, s * 0.21), s * 0.07,
				Color(0.2, 0.45, 0.3, k))
			for i in 3:
				ci.draw_line(card.position + Vector2(s * 0.27, s * (0.16 + 0.07 * i)),
					card.position + Vector2(s * (0.52 - 0.08 * i), s * (0.16 + 0.07 * i)),
					Color(0.35, 0.4, 0.38, k), s * 0.03)
		&"trampo":
			AppCelular.maleta(ci, c + Vector2(0.0, s * 0.04), s * 0.27, branco)
		&"iweed":
			AppCelular.folha(ci, c - Vector2(0.0, s * 0.04), s * 0.36, Color(0.44, 0.9, 0.6, k))
		&"radio":
			ci.draw_line(c + Vector2(0.0, -s * 0.05), c + Vector2(-s * 0.13, s * 0.3), branco, s * 0.05, true)
			ci.draw_line(c + Vector2(0.0, -s * 0.05), c + Vector2(s * 0.13, s * 0.3), branco, s * 0.05, true)
			ci.draw_circle(c + Vector2(0.0, -s * 0.06), s * 0.06, branco)
			for i in 2:
				var rr := s * (0.16 + 0.1 * i)
				ci.draw_arc(c + Vector2(0.0, -s * 0.06), rr, -PI * 0.8, -PI * 0.2, 10, branco, s * 0.04, true)
		&"calculadora":
			for i in 4:
				for j in 3:
					var cor := Color(0.95, 0.55, 0.12, k) if j == 2 else Color(0.82, 0.83, 0.85, k)
					ci.draw_colored_polygon(AppCelular.cantos(Rect2(r.position.x + s * (0.2 + 0.21 * j),
						r.position.y + s * (0.16 + 0.18 * i), s * 0.17, s * 0.14), s * 0.03), cor)
		&"notas":
			ci.draw_rect(Rect2(r.position.x, r.position.y, s, s * 0.2), Color(0.55, 0.36, 0.2, k))
			for i in 5:
				var y := r.position.y + s * (0.36 + 0.13 * i)
				ci.draw_line(Vector2(r.position.x + s * 0.08, y), Vector2(r.end.x - s * 0.08, y),
					Color(0.55, 0.62, 0.8, 0.8 * k), s * 0.02)
			ci.draw_line(Vector2(r.position.x + s * 0.22, r.position.y + s * 0.2),
				Vector2(r.position.x + s * 0.22, r.end.y - s * 0.06), Color(0.85, 0.3, 0.3, 0.8 * k), s * 0.02)
		&"lanterna":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.08, s * 0.1),
				c + Vector2(-s * 0.36, -s * 0.36), c + Vector2(s * 0.36, -s * 0.36),
				c + Vector2(s * 0.08, s * 0.1)]), Color(1.0, 0.93, 0.55, 0.45 * k))
			ci.draw_colored_polygon(AppCelular.cantos(Rect2(c.x - s * 0.09, c.y + s * 0.06,
				s * 0.18, s * 0.3), s * 0.03), Color(0.75, 0.77, 0.8, k))
			ci.draw_circle(c + Vector2(0.0, s * 0.09), s * 0.08, Color(1.0, 0.97, 0.75, k))
		&"bussola":
			ci.draw_circle(c, s * 0.34, Color(0.95, 0.95, 0.93, k))
			ci.draw_arc(c, s * 0.34, 0.0, TAU, 36, Color(0.1, 0.1, 0.1, 0.6 * k), s * 0.03, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s * 0.28),
				c + Vector2(s * 0.07, 0.0), c + Vector2(-s * 0.07, 0.0)]), Color(0.86, 0.14, 0.12, k))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, s * 0.28),
				c + Vector2(s * 0.07, 0.0), c + Vector2(-s * 0.07, 0.0)]), Color(0.25, 0.27, 0.3, k))
		&"tempo":
			ci.draw_circle(c + Vector2(-s * 0.1, -s * 0.1), s * 0.17, Color(1.0, 0.86, 0.3, k))
			var nuvem := Color(1.0, 1.0, 1.0, 0.97 * k)
			ci.draw_circle(c + Vector2(s * 0.02, s * 0.1), s * 0.13, nuvem)
			ci.draw_circle(c + Vector2(s * 0.17, s * 0.04), s * 0.15, nuvem)
			ci.draw_circle(c + Vector2(s * 0.3, s * 0.13), s * 0.1, nuvem)
			ci.draw_rect(Rect2(c.x + s * 0.02, c.y + s * 0.1, s * 0.28, s * 0.13), nuvem)
		&"cobrinha":
			var q := s * 0.1
			var corpo := [Vector2(2, 6), Vector2(3, 6), Vector2(4, 6), Vector2(5, 6), Vector2(5, 5),
				Vector2(5, 4), Vector2(4, 4), Vector2(3, 4)]
			for p: Vector2 in corpo:
				ci.draw_rect(Rect2(r.position + p * q, Vector2(q * 0.92, q * 0.92)),
					Color(0.1, 0.22, 0.06, k))
			ci.draw_rect(Rect2(r.position + Vector2(7, 3) * q, Vector2(q * 0.92, q * 0.92)),
				Color(0.85, 0.12, 0.1, k))
		_:
			pass


## O fone do Telefone: o monofone deitado em diagonal.
static func _fone(ci: CanvasItem, c: Vector2, s: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(PI * 0.1, PI * 0.9, float(i) / 8.0)
		pts.append(c + Vector2(cos(a), sin(a) * 0.55).rotated(-PI * 0.25) * s * 0.9)
	ci.draw_polyline(pts, cor, s * 0.3, true)
	ci.draw_circle(pts[0], s * 0.2, cor)
	ci.draw_circle(pts[pts.size() - 1], s * 0.2, cor)


static func _alfinete(ci: CanvasItem, c: Vector2, raio: float, cor: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-raio * 0.55, raio * 0.3),
		c + Vector2(0.0, raio * 1.9), c + Vector2(raio * 0.55, raio * 0.3)]), cor)
	ci.draw_circle(c, raio, cor)
	ci.draw_circle(c + Vector2(-raio * 0.3, -raio * 0.3), raio * 0.3, Color(1, 1, 1, 0.55 * cor.a))


static func _engrenagem(ci: CanvasItem, c: Vector2, raio: float, dentes: int, cor: Color,
		cubo: Color) -> void:
	var pts := PackedVector2Array()
	for i in dentes * 4:
		var a := float(i) / float(dentes * 4) * TAU
		var fora := (i % 4) < 2
		pts.append(c + Vector2(cos(a), sin(a)) * raio * (1.0 if fora else 0.8))
	ci.draw_colored_polygon(pts, cor)
	ci.draw_circle(c, raio * 0.5, cubo)
	ci.draw_circle(c, raio * 0.22, cor)


static func _elipse(r: Rect2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := r.get_center()
	for i in n:
		var a := float(i) / float(n) * TAU
		pts.append(c + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5))
	return pts

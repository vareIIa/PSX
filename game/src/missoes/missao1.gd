## Autoload. Missao 1: a casa da fumaca, o porao, o Berg e a igreja.
##
## O roteiro de cinema esta em docs/missao1/roteiro.md (copia do
## /mnt/project-files/missao1/roteiro.md) e o mapa de sistemas em
## docs/missao1/mapeamento.md. Este arquivo e o diretor: ouve onde o jogador
## esta (a porta da casa, o porao, a rua, a igreja), chama as cenas cortadas na
## ordem do roteiro e grava o estado. As escolhas vao para o `Borboleta` pela
## propria `Escolha`; as cenas moram em `src/missoes/cenas/`.
##
## O fio da missao
## ---------------
##   FORA          armada enquanto a missao da casa da fumaca esta aberta (ou
##                 nenhuma esta, num save antigo). O dono abrindo a porta, ou o
##                 jogador falando com ele, dispara a Cena 1.
##   DONO          Cena 1. No fim o dono paga, a missao da casa fecha e esta
##                 comeca: o Marea e o Berg ja nascem na calcada.
##   NA_CASA       "Saia da casa", com o porao de opcional. Pisar no ultimo
##                 degrau dispara a Cena 2; cruzar a porta da rua, a Cena 3.
##   BERG          Cenas 3 e 4A/5A/6A ou 4B, uma atras da outra.
##   SEGUIR_BERG   (carona) o Berg anda da vaga ate a escadaria, esperando.
##   VOLTAR_PRACA  (recusa) o Marea passeia dois minutos, some e reaparece na
##                 vaga da igreja; falar com o Berg la dispara a Cena 6B.
##   IGREJA        Cenas 6B e 7.
##   CONCLUIDA     o Berg fica na praca, encostado no carro, com fala de rotina.
##
## Por que um estado so, e nao uma lista de etapas
## ------------------------------------------------
## A missao ramifica na Cena 3 e de novo no papel. O `Missoes` desenha UMA
## etapa por vez e nao sabe ramificar; aqui o estado decide o texto e o
## alfinete e entrega com `Missoes.trocar_etapa`. O save guarda o estado e o
## lugar da casa; o resto (onde o Berg esta) e refeito do estado na carga.
class_name DiretorMissao1
extends Node

signal comecou()
signal terminou()
signal estado_mudou(estado: Estado)

enum Estado { FORA, DONO, NA_CASA, PORAO, BERG, SEGUIR_BERG, VOLTAR_PRACA, IGREJA, CONCLUIDA }
## Onde o Berg anda no ramo da recusa (4B-NPC).
enum Passeio { NENHUM, DIRIGINDO, SUMIDO, NA_IGREJA }

const ID := &"missao1"
const TITULO := "VOCÊ NÃO VAI LONGE"

## O passeio do Marea no ramo da recusa (roteiro 4B-NPC: 120 s).
const PASSEIO := 120.0
## Passado o passeio, se o carro nao sumiu (o jogador esta colado nele), ele
## vai sozinho para a igreja e estaciona: o resultado e o mesmo.
const PASSEIO_COLADO := 25.0
## Distancia da igreja em que o Berg da igreja pode nascer: o chunk da vaga
## tem de estar montado (o carro assenta nas rodas pelo chao de verdade).
const PERTO_DA_IGREJA := 140.0
## Pisar no ultimo degrau do porao, em metros do ponto `PORAO_ENTRADA`.
const RAIO_DEGRAU := 1.3
## Seguir o Berg (6A): ele espera se o jogador ficar mais longe que isto, e a
## Cena 7 comeca com os dois a esta distancia do pe da escadaria.
const SEGUIR_ESPERA := 8.0
const SEGUIR_CHEGA := 3.0
const SEGUIR_PERTO := 5.0
## Do pe da escadaria ate onde o jogador para quando a cena posiciona os dois.
const FRENTE_JOGADOR := Vector3(1.1, 0.0, 1.6)
const FRENTE_BERG := Vector3(-0.7, 0.0, 0.9)

## Falas do Berg depois da missao (C7-09: "falas de rotina ate a Missao 2").
const ROTINA_BERG: Array[String] = [
	"Amanhã a gente entra. Hoje cê dorme, sô.",
	"Cê ainda tá procurando a saída? Eu sei. Eu procurei também.",
	"Não sai daqui sem me avisar, uai.",
	"Essa igreja é a única coisa que não muda de lugar. Repara.",
]

var estado: Estado = Estado.FORA
## Uma cena cortada desta missao esta rodando.
var em_cena: bool = false
## A porta da rua da casa da missao: origem no vao, -Z da base aponta a rua.
var casa_porta := Transform3D()
var casa_semente: int = 0
var berg: Ator
var carro: Carro
var dono: Convidado
var papel: BilheteNoAr
var passeio: Passeio = Passeio.NENHUM
## Quem faz o jogador no carro (Cenas 4A a 6A). O Player de verdade fica
## escondido e preso ao carro: e ele que o streaming da cidade segue.
var duble: Ator

## Verificacoes antigas que falam com o dono pela Conversa (TesteFumaca)
## desligam a missao para a conversa de sempre abrir.
var desligada: bool = false
## Bancada automatica (tests/m1_e.gd): chaves de opcao que o piloto escolhe.
## Vazio desliga. Com o piloto ligado as falas avancam sozinhas.
var piloto: Dictionary = {}

var _relogio: float = 0.0
var _passeio_t: float = 0.0
var _piloto_t: float = 0.0
var _jogador_preso_ao: Node3D
var _jogador_camadas := Vector2i(1, 1)
var _rotina_vez: int = 0
var _cenas: Dictionary = {}
## A lente presa a um no que anda (o carro): ver `lente_presa`.
var _lente_no: Node3D
var _lente_de := Vector3.ZERO
var _lente_ate := Vector3.ZERO
var _lente_para := Vector3.ZERO
var _lente_fov: float = 60.0
var _lente_t: float = 0.0
var _lente_dur: float = 0.0
## Um `corte_preto` deixou a cortina fechada: o proximo plano abre.
var _cortina_pendente: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Missoes.concluiu.connect(_ao_concluir_missao)
	Interiores.saiu.connect(_ao_sair_de_casa)
	Borboleta.marcou.connect(_ao_marcar)


# --- ciclo de vida ----------------------------------------------------------

## Comeca a Missao 1: a HUD, a dupla no porao e o Berg esperando na calcada.
## Chamado quando a missao da casa da fumaca termina (`Missoes.concluiu`, que a
## Cena 1 fecha ao pagar o dono).
func iniciar() -> void:
	if estado != Estado.FORA and estado != Estado.DONO:
		return
	Elenco.levar_dupla_ao_porao(get_tree(), true)
	Missoes.comecar({
		"id": ID,
		"titulo": TITULO,
		"etapas": [_etapa_na_casa()],
	})
	_mudar(Estado.NA_CASA)
	_montar_berg_na_porta()
	comecou.emit()


## Novo jogo: tudo para tras.
func limpar() -> void:
	_desmontar()
	estado = Estado.FORA
	em_cena = false
	casa_porta = Transform3D()
	casa_semente = 0
	passeio = Passeio.NENHUM
	Elenco.dupla_no_porao = false


func _mudar(novo: Estado) -> void:
	estado = novo
	estado_mudou.emit(novo)


## A missao esta esperando o dono (a Cena 1 pode comecar).
func armada() -> bool:
	if desligada or estado != Estado.FORA or em_cena:
		return false
	if bool(Borboleta.valor(&"m1_concluida", false)):
		return false
	var id := StringName(Missoes.atual.get("id", &""))
	return Missoes.atual.is_empty() or id == &"casa_da_fumaca"


# --- ganchos chamados de fora -------------------------------------------------

## O dono abriu a porta da rua (Convidado._na_porta). Devolve se a missao
## assumiu o dono: a Cena 1 comeca na soleira.
func dono_na_porta(c: Convidado) -> bool:
	if not armada():
		return false
	_comecar_cena_dono(c, true)
	return true


## O jogador falou com o dono sem ter batido (a porta ja estava aberta, ou um
## save antigo). A Cena 1 comeca na bancada.
func dono_abordado(c: Convidado) -> bool:
	if not armada():
		return false
	_comecar_cena_dono(c, false)
	return true


func _comecar_cena_dono(c: Convidado, na_porta: bool) -> void:
	preparar_casa(c)
	_mudar(Estado.DONO)
	_rodar(&"dono", [na_porta])


## A casa da missao e a do dono: guarda a porta da rua (onde o Berg espera).
func preparar_casa(c: Convidado) -> void:
	dono = c
	var interior := _interior_de(c)
	if interior != null:
		casa_porta = Transform3D(interior.global_transform.basis.orthonormalized(),
			interior.to_global(LoteNoMundo.centro_do_vao(interior.planta)))
		casa_semente = interior.semente


## Atalho (`--m1-casa` pulando a Cena 1): a casa conhecida, a missao comecada.
func pular_cena_dono(c: Convidado) -> void:
	preparar_casa(c)
	_mudar(Estado.DONO)
	dono_terminou()


## Atalho (`--m1-igreja`): ramo da recusa, o Berg ja na igreja.
func retomar_na_igreja() -> void:
	_desmontar()
	Borboleta.marcar(&"m1_aceitou_carona_berg", false, false)
	_mudar(Estado.VOLTAR_PRACA)
	_garantir_missao({"texto": "", "dica": ""})
	_atualizar_etapa_da_praca()
	passeio = Passeio.SUMIDO


## A Cena 1 terminou: o dono pagou e respondeu. Fecha a missao da casa (que
## chama `iniciar` pelo `Missoes.concluiu`) ou comeca direto, num save sem ela.
func dono_terminou() -> void:
	if StringName(Missoes.atual.get("id", &"")) == &"casa_da_fumaca":
		var etapas: Array = Missoes.atual["etapas"]
		Missoes.atual["etapa"] = etapas.size() - 1
		Missoes.avancar()
	if estado == Estado.DONO:
		iniciar()


func _ao_concluir_missao(m: Dictionary) -> void:
	if StringName(m.get("id", &"")) == &"casa_da_fumaca" and estado == Estado.DONO:
		iniciar()


## Saiu pela soleira de uma casa da rua. Da casa da missao, e a Cena 3.
func _ao_sair_de_casa() -> void:
	if estado != Estado.NA_CASA or em_cena:
		return
	var j := jogador()
	if j == null or carro == null or berg == null:
		return
	if j.global_position.distance_to(casa_porta.origin) > 6.0:
		return
	Missoes.trocar_etapa({"texto": "", "dica": ""})
	_mudar(Estado.BERG)
	_rodar(&"berg", [])


func _ao_marcar(chave: StringName, _valor: Variant, _olho: bool) -> void:
	if chave == &"m1_ligou_pro_berg" and estado == Estado.VOLTAR_PRACA:
		_atualizar_etapa_da_praca()
	elif chave == &"m1_pegou_numero_berg" and estado == Estado.VOLTAR_PRACA:
		_atualizar_etapa_da_praca()


# --- etapas na HUD --------------------------------------------------------------

func _etapa_na_casa() -> Dictionary:
	var dica := "" if bool(Borboleta.valor(&"m1_desceu_ao_porao", false)) \
		else "(Opcional) Desça ao porão."
	return {"texto": "Saia da casa da fumaça.", "dica": dica}


## A etapa do ramo da recusa, pelo que o jogador ja fez com o papel.
func _atualizar_etapa_da_praca() -> void:
	if bool(Borboleta.valor(&"m1_ligou_pro_berg", false)):
		var ig := Lugares.igreja()
		Missoes.trocar_etapa({"texto": "Encontre o Berg na igreja.", "dica": ""},
			{"mundo": ig["frente"], "nome": String(ig["nome"])})
	elif bool(Borboleta.valor(&"m1_pegou_numero_berg", false)):
		Missoes.trocar_etapa({"texto": "Ligue para o Berg.",
			"dica": "Celular > Contatos > BERG"})
	else:
		Missoes.trocar_etapa({"texto": "Volte para a praça onde você acordou.", "dica": ""})


## Fim da Cena 3 com a carona: segue o Berg da vaga ate a escadaria.
func comecar_seguir() -> void:
	Missoes.trocar_etapa({"texto": "Siga o Berg.", "dica": ""})
	_mudar(Estado.SEGUIR_BERG)
	_seguir_berg()


## Fim da Cena 4B: o Marea sai passeando e o papel fica na calcada.
func comecar_recusa() -> void:
	_mudar(Estado.VOLTAR_PRACA)
	_atualizar_etapa_da_praca()
	if papel != null and is_instance_valid(papel) and not papel.pego.is_connected(_ao_pegar_papel):
		papel.pego.connect(_ao_pegar_papel, CONNECT_ONE_SHOT)
	_comecar_passeio()


## E4: pegou o papel do chao. O olho, o contato e a etapa.
func _ao_pegar_papel(_quem: Node) -> void:
	Borboleta.marcar(&"m1_pegou_numero_berg", true)
	Elenco.dar_numero_do_berg()


## Fim da Cena 7.
func concluir() -> void:
	Borboleta.marcar(&"m1_concluida", true, false)
	Elenco.levar_dupla_ao_porao(get_tree(), false)
	_mudar(Estado.CONCLUIDA)
	if StringName(Missoes.atual.get("id", &"")) == ID:
		Missoes.avancar(false)
	_berg_de_rotina()
	terminou.emit()


# --- o Berg e o carro -----------------------------------------------------------

## O Marea parado na calcada da casa, duas rodas no meio-fio, e o Berg
## encostado no paralama do lado da casa, fumando (inicio da Cena 3).
func _montar_berg_na_porta() -> void:
	if casa_porta == Transform3D():
		return
	_desmontar()
	var rua := -casa_porta.basis.z
	rua.y = 0.0
	rua = rua.normalized()
	# Mao de direcao: a calcada da casa a direita do carro (o lado do carona),
	# o motorista do lado da rua. E por ali que o Berg contorna para entrar.
	var lado := Vector3.UP.cross(-rua).normalized()
	var perto := casa_porta.origin + rua * 4.0 + lado * 3.2
	var vaga := Lugares.vaga_na_calcada(perto, perto + lado * 20.0)
	carro = Transito.criar_carro_de_cena(Elenco.ficha(Elenco.BERG), vaga)
	_novo_berg()
	var local := carro.to_local(casa_porta.origin)
	var lado_carro := 1.0 if local.x >= 0.0 else -1.0
	berg.global_position = carro.global_transform * Vector3(lado_carro * 1.6, 0.0, -1.6)
	berg.encarar(casa_porta.origin)
	berg.encostar_no_carro(carro, lado_carro)
	berg.acender_cigarro()


func _novo_berg() -> Ator:
	if berg != null and is_instance_valid(berg):
		return berg
	berg = Ator.new()
	berg.name = "Berg"
	berg.preparar(Elenco.BERG, Elenco.ficha(Elenco.BERG))
	_cena().add_child(berg)
	berg.interagido.connect(_ao_interagir_berg)
	return berg


func _desmontar() -> void:
	for n: Node in [berg, carro, duble]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	berg = null
	carro = null
	duble = null
	_soltar_jogador()


## Ramo da recusa: o Marea anda a esmo e some longe da vista.
func _comecar_passeio() -> void:
	if carro == null or not is_instance_valid(carro):
		passeio = Passeio.SUMIDO
		return
	passeio = Passeio.DIRIGINDO
	_passeio_t = 0.0
	if not carro.sumiu.is_connected(_ao_sumir):
		carro.sumiu.connect(_ao_sumir, CONNECT_ONE_SHOT)
	carro.vagar(PASSEIO)


func _ao_sumir() -> void:
	passeio = Passeio.SUMIDO
	carro = null


## Passou do tempo e o carro nao sumiu (o jogador esta colado): ele vai
## sozinho para a vaga da igreja, estaciona, e o Berg desce.
func _passeio_ate_a_igreja() -> void:
	passeio = Passeio.NA_IGREJA
	var ig := Lugares.igreja()
	var vaga: Transform3D = ig["vaga"]
	if carro.sumiu.is_connected(_ao_sumir):
		carro.sumiu.disconnect(_ao_sumir)
	await carro.ir_para(vaga.origin)
	if carro == null or not is_instance_valid(carro):
		return
	await carro.estacionar_na_calcada(vaga, true)
	if berg != null and is_instance_valid(berg) and carro != null:
		await berg.sair_do_carro(carro, Carro.Banco.MOTORISTA)
		_berg_vagar_na_igreja()


## O Berg da igreja: o Marea na vaga (mesmo ponto do C6A-01) e ele andando
## pela area da capela ate o jogador falar com ele.
func montar_berg_na_igreja() -> void:
	var ig := Lugares.igreja()
	var vaga: Transform3D = ig["vaga"]
	if carro == null or not is_instance_valid(carro):
		carro = Transito.criar_carro_de_cena(Elenco.ficha(Elenco.BERG), vaga)
	_novo_berg()
	berg.process_mode = Node.PROCESS_MODE_INHERIT
	berg.visible = true
	if berg.has_meta(&"sumiu_com_carro"):
		berg.remove_meta(&"sumiu_com_carro")
	if berg.get_parent() != _cena():
		berg.reparent(_cena(), false)
	berg.global_position = no_chao(carro.global_transform * Vector3(-1.6, 0.0, -1.2))
	passeio = Passeio.NA_IGREJA
	_berg_vagar_na_igreja()


func _berg_vagar_na_igreja() -> void:
	var ig := Lugares.igreja()
	var area: Rect2 = ig["area"]
	var c3 := no_chao(Vector3(area.get_center().x, KitParque.Y_CALCAMENTO, area.get_center().y))
	var torre: Vector3 = no_chao(ig["centro"]) + Vector3.UP * 14.0
	berg.rotulo = "Falar com Berg"
	berg.vagar_em(c3, minf(area.size.x, area.size.y) * 0.5, torre, carro)


## Depois da missao: o Berg na praca, interativo, fala de rotina.
func _berg_de_rotina() -> void:
	if berg == null or not is_instance_valid(berg):
		return
	berg.rotulo = "Falar com Berg"
	if carro != null and is_instance_valid(carro):
		berg.encostar_no_carro(carro, -1.0)


func _ao_interagir_berg(_quem: Node) -> void:
	if em_cena or Escolha.ativo:
		return
	match estado:
		Estado.VOLTAR_PRACA:
			if passeio == Passeio.NA_IGREJA:
				berg.rotulo = ""
				_mudar(Estado.IGREJA)
				_rodar(&"igreja", [false])
		Estado.CONCLUIDA:
			_rotina_vez += 1
			var linha := ROTINA_BERG[_rotina_vez % ROTINA_BERG.size()]
			berg.encarar(jogador().global_position, true)
			var l: Array[String] = [linha]
			await Escolha.falar("BERG", l, berg)


## 6A: o Berg anda da vaga ate a frente da capela pelo calcamento, devagar;
## para e espera (acende um cigarro) se o jogador ficar para tras.
func _seguir_berg() -> void:
	var ig := Lugares.igreja()
	var pe: Vector3 = no_chao(ig["frente"])
	var alvo_berg := pe + FRENTE_BERG
	berg.rotulo = ""
	while estado == Estado.SEGUIR_BERG and is_instance_valid(berg):
		var j := jogador()
		var longe := j.global_position.distance_to(berg.global_position) > SEGUIR_ESPERA
		var chegou := berg.global_position.distance_to(alvo_berg) < 0.6
		if chegou or longe:
			if longe and not berg.fumando():
				berg.acender_cigarro()
			berg.encarar(j.global_position, true)
			if chegou and j.global_position.distance_to(pe) < SEGUIR_CHEGA + SEGUIR_PERTO:
				_mudar(Estado.IGREJA)
				_rodar(&"igreja", [true])
				return
			await get_tree().create_timer(0.3).timeout
			continue
		# Um trecho de cada vez: o laco volta a conferir o jogador.
		var falta := alvo_berg - berg.global_position
		falta.y = 0.0
		var passo := berg.global_position + falta.limit_length(3.0)
		var antes := berg.global_position
		await berg.andar_ate(passo)
		if is_instance_valid(berg) and berg.global_position.distance_to(antes) < 0.2:
			# Preso num banco ou numa arvore do largo: passa por cima do trecho.
			berg.global_position = no_chao(passo)


# --- relogio ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not piloto.is_empty():
		_pilotar(delta)
	_andar_lente(delta)
	_relogio += delta
	if _relogio < 0.1:
		return
	var dt := _relogio
	_relogio = 0.0
	if get_tree().paused:
		return
	match estado:
		Estado.FORA:
			if armada() and not Elenco.dupla_no_porao \
					and StringName(Missoes.atual.get("id", &"")) == &"casa_da_fumaca":
				# A dupla tem de nascer no porao: liga ja, antes de a casa montar.
				Elenco.levar_dupla_ao_porao(get_tree(), true)
		Estado.NA_CASA:
			_vigiar_porao()
			if (carro == null or not is_instance_valid(carro)) and casa_porta != Transform3D():
				_respawn_na_porta()
		Estado.VOLTAR_PRACA:
			_vigiar_passeio(dt)
		Estado.CONCLUIDA:
			if berg == null or not is_instance_valid(berg):
				if _igreja_carregada():
					montar_berg_na_igreja()
					_berg_de_rotina()
	if _jogador_preso_ao != null:
		_prender_jogador()


func _vigiar_porao() -> void:
	if em_cena or bool(Borboleta.valor(&"m1_desceu_ao_porao", false)):
		return
	var estufa := estufa_da_casa()
	var j := jogador()
	if estufa == null or j == null:
		return
	var degrau := estufa.to_global(EstufaBuilder.PORAO_ENTRADA)
	var d := j.global_position - degrau
	if Vector2(d.x, d.z).length() < RAIO_DEGRAU and absf(d.y) < 1.0:
		_mudar(Estado.PORAO)
		_rodar(&"porao", [])


## Fim da Cena 2: volta a "Saia da casa", sem a opcional.
func porao_terminou() -> void:
	_mudar(Estado.NA_CASA)
	Missoes.trocar_etapa(_etapa_na_casa())


## Save carregado no meio: o carro nasce quando o chunk da porta estiver montado.
func _respawn_na_porta() -> void:
	var j := jogador()
	if j == null or j.global_position.distance_to(casa_porta.origin) > 60.0:
		return
	if not ChunkManager.esta_carregado(ChunkManager.coord_de(casa_porta.origin)):
		return
	_montar_berg_na_porta()


func _vigiar_passeio(dt: float) -> void:
	match passeio:
		Passeio.DIRIGINDO:
			_passeio_t += dt
			if _passeio_t > PASSEIO + PASSEIO_COLADO and carro != null and is_instance_valid(carro):
				_passeio_ate_a_igreja()
		Passeio.SUMIDO:
			if _igreja_carregada():
				montar_berg_na_igreja()


func _igreja_carregada() -> bool:
	var j := jogador()
	if j == null:
		return false
	var vaga: Transform3D = Lugares.igreja()["vaga"]
	if j.global_position.distance_to(vaga.origin) > PERTO_DA_IGREJA:
		return false
	return ChunkManager.esta_carregado(ChunkManager.coord_de(vaga.origin))


# --- as cenas -------------------------------------------------------------------

func _rodar(qual: StringName, args: Array) -> void:
	em_cena = true
	var script: GDScript = _script_da_cena(qual)
	await script.callv(&"rodar", [self] + args)
	em_cena = false


func _script_da_cena(qual: StringName) -> GDScript:
	if not _cenas.has(qual):
		_cenas[qual] = load("res://src/missoes/cenas/m1_cena_%s.gd" % qual)
	return _cenas[qual]


# --- ferramentas das cenas ----------------------------------------------------------

func jogador() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


## Corta para um plano com nome e espera a duracao dele (ver `Cinema.plano`).
func plano(tipo: PlanoCena.Tipo, alvo: Node3D, outro: Node3D = null,
		duracao: float = 0.0, opcoes: Dictionary = {}) -> void:
	_lente_no = null
	var o := opcoes
	if _cortina_pendente:
		_cortina_pendente = false
		o = opcoes.duplicate()
		o["corte_preto"] = 0.02
	await Cinema.plano(tipo, alvo, outro, duracao, o)


## Corte preto do roteiro (`Cinema.corte`): a tela fica preta e o proximo plano
## abre ja montado. Entre um e outro a cena pode mover gente e carro.
func corte_preto(segundos: float = 0.4) -> void:
	await Cinema.corte(segundos)
	_cortina_pendente = true


func _abrir_cortina() -> void:
	if not _cortina_pendente:
		return
	_cortina_pendente = false
	var c := Cinema.get(&"_cortina") as ColorRect
	if c != null:
		c.color.a = 0.0


## Lente parafusada num no que anda, no espaco dele: o close do Berg com o
## Marea rodando, a grua que sobe acompanhando o carro. `Cinema.plano` so
## prende a lente no interior e no acompanhamento; os outros planos da corrida
## ficariam para tras na primeira esquina. Com `ate` e `duracao` a lente anda
## de `de` ate `ate` (grua, travelling) sem largar o no. Espera a duracao.
func lente_presa(no: Node3D, de: Vector3, para: Vector3, fov: float,
		duracao: float = 0.0, ate: Vector3 = Vector3.INF) -> void:
	Cinema.call(&"_parar_plano")
	Cinema.sem_profundidade()
	_lente_no = no
	_lente_de = de
	_lente_ate = ate if ate.is_finite() else de
	_lente_para = para
	_lente_fov = fov
	_lente_t = 0.0
	_lente_dur = duracao
	_andar_lente(0.0)
	_abrir_cortina()
	Lente.recomecar()
	if duracao > 0.0:
		await esperar(duracao)


func soltar_lente() -> void:
	_lente_no = null


func _andar_lente(delta: float) -> void:
	if _lente_no == null:
		return
	if not is_instance_valid(_lente_no) or not Cinema.ativa:
		_lente_no = null
		return
	_lente_t += delta
	var k := 1.0 if _lente_dur <= 0.0 else clampf(_lente_t / _lente_dur, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var xf := _lente_no.global_transform
	Cinema.enquadrar(xf * _lente_de.lerp(_lente_ate, k), xf * _lente_para, _lente_fov)


## Plano feito a mao (a lente num ponto, olhando outro), e espera.
func quadro(de: Vector3, para: Vector3, fov: float, duracao: float = 0.0) -> void:
	_lente_no = null
	Cinema.call(&"_parar_plano")
	Cinema.enquadrar(de, para, fov)
	_abrir_cortina()
	Lente.recomecar()
	if duracao > 0.0:
		await esperar(duracao)


## Dolly a mao, de `de` ate `ate`, olhando de `olhar_de` ate `olhar_ate`.
func dolly(de: Vector3, ate: Vector3, olhar_de: Vector3, olhar_ate: Vector3,
		fov: float, duracao: float) -> void:
	_lente_no = null
	Cinema.call(&"_parar_plano")
	Cinema.enquadrar(de, olhar_de, fov)
	_abrir_cortina()
	Lente.recomecar()
	Cinema.mover(de, ate, olhar_de, olhar_ate, duracao, fov)
	await esperar(duracao)


## Linhas na caixa de fala, avancando na tecla. `quem` mexe a boca.
func fala(nome: String, linhas: Array[String], quem: Node3D = null) -> void:
	await Escolha.falar(nome, linhas, quem)


## A fala do jogador. A fita mostra o primeiro nome da ficha (`{primeiro}`).
func eu(linhas: Array[String]) -> void:
	await Escolha.falar(nome_do_jogador(), linhas, null)


func pergunta(nome: String, texto: String, opcoes: Array[Dictionary],
		quem: Node3D = null) -> StringName:
	return await Escolha.perguntar(nome, texto, opcoes, quem)


func nome_do_jogador() -> String:
	var f := RegistroCivil.jogador
	var nome := String(f.get("nome", "VOCÊ"))
	var primeiro := nome.get_slice(" ", 0)
	return primeiro.to_upper() if not primeiro.is_empty() else "VOCÊ"


func primeiro_nome() -> String:
	return nome_do_jogador().capitalize()


## O jogador de frente para um ponto, com o corpo a mostra (as cenas o filmam).
func virar_jogador(ponto: Vector3) -> void:
	var j := jogador()
	if j == null:
		return
	var d := ponto - j.global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	j.rotation.y = atan2(-d.x, -d.z)


## O chao de verdade debaixo de um ponto. Os lugares da missao (`Lugares`)
## vem sem o relevo da cidade; quem poe gente ou lente neles assenta aqui.
## Primeiro um raio curto de cima do ponto (o piso de dentro de casa, sem pegar
## o forro), depois um do alto do relevo.
func no_chao(p: Vector3) -> Vector3:
	var espaco := get_viewport().world_3d.direct_space_state
	var base := Relevo.altura(p.x, p.z) if Relevo.ativo else 0.0
	for de_y: float in [p.y + 1.2, base + 4.0]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, de_y, p.z),
			Vector3(p.x, de_y - 8.0, p.z))
		var r := espaco.intersect_ray(q)
		if r.is_empty():
			continue
		var col: Object = r.get("collider")
		if col is CharacterBody3D or col is Carro:
			continue
		return r["position"]
	return Vector3(p.x, base, p.z)


## Poe o jogador num ponto (assentado no chao), olhando outro. A camera dele
## nao esta na tela.
func por_jogador(onde: Vector3, olhando: Vector3) -> void:
	var j := jogador()
	if j == null:
		return
	j.global_position = no_chao(onde) + Vector3.UP * 0.05
	if j.has_method(&"zerar_velocidade"):
		j.call(&"zerar_velocidade")
	virar_jogador(olhando)


## Comeca uma cena cortada: tarjas, corpo do jogador visivel.
func entrar_em_cena() -> void:
	Cinema.iniciar()
	var j := jogador()
	if j != null:
		j.mostrar_corpo(true)


func sair_de_cena() -> void:
	_lente_no = null
	_abrir_cortina()
	var j := jogador()
	if j != null:
		j.mostrar_corpo(false)
	Cinema.sem_profundidade()
	await Cinema.encerrar()


## O dono e a dupla sao Convidados: gesto de cena pelo corpo.
func gesto(quem: Node3D, g: Corpo.GestoCena, alvo: Vector3 = Vector3.INF,
		lado: float = 1.0) -> void:
	if quem == null or not is_instance_valid(quem):
		return
	if quem is Ator:
		await (quem as Ator).fazer(g, alvo, lado)
		return
	var c := Carro.corpo_de(quem)
	if c == null:
		return
	c.lado_do_gesto = lado
	c.alvo_do_gesto = alvo
	await c.fazer_gesto(g)


## O jogador sai de cena por um tempo (vai no carro): escondido, sem fisica,
## preso a um no que anda (o streaming segue o jogador, entao ele vai junto).
func prender_jogador_a(no: Node3D) -> void:
	var j := jogador()
	if j == null:
		return
	_jogador_preso_ao = no
	j.visible = false
	j.process_mode = Node.PROCESS_MODE_DISABLED
	# Sem colisao: a capsula parada dentro do carro andando seria uma parede
	# no meio da lataria.
	_jogador_camadas = Vector2i(j.collision_layer, j.collision_mask)
	j.collision_layer = 0
	j.collision_mask = 0
	_prender_jogador()


func _prender_jogador() -> void:
	var j := jogador()
	if j == null or not is_instance_valid(_jogador_preso_ao):
		_jogador_preso_ao = null
		return
	j.global_position = _jogador_preso_ao.global_position + Vector3.UP * 0.2


## Devolve o jogador ao mundo num ponto.
func soltar_jogador(onde: Vector3 = Vector3.INF, olhando: Vector3 = Vector3.INF) -> void:
	_soltar_jogador()
	if onde.is_finite():
		por_jogador(onde, olhando if olhando.is_finite() else onde + Vector3.FORWARD)


func _soltar_jogador() -> void:
	if _jogador_preso_ao == null:
		return
	_jogador_preso_ao = null
	var j := jogador()
	if j == null:
		return
	j.process_mode = Node.PROCESS_MODE_INHERIT
	j.visible = true
	j.collision_layer = _jogador_camadas.x
	j.collision_mask = _jogador_camadas.y


func _pilotar(delta: float) -> void:
	_piloto_t += delta
	if _piloto_t < 0.12 or not Escolha.ativo:
		return
	_piloto_t = 0.0
	if Escolha.escolhendo():
		var chaves := Escolha.chaves()
		for k: StringName in chaves:
			if piloto.has(k):
				Escolha.escolher(k)
				return
		Escolha.escolher(chaves[0])
		return
	Escolha.avancar()


func _cena() -> Node:
	var c := get_tree().current_scene
	return c if c != null else get_tree().root


static func _interior_de(no: Node) -> InteriorNoMundo:
	var n := no
	while n != null:
		if n is InteriorNoMundo:
			return n as InteriorNoMundo
		n = n.get_parent()
	return null


## A estufa debaixo da casa da missao (onde fica o porao).
func estufa_da_casa() -> Node3D:
	var interior: InteriorNoMundo = null
	if dono != null and is_instance_valid(dono):
		interior = _interior_de(dono)
	if interior == null:
		for n: Node in get_tree().get_nodes_in_group(&"elenco"):
			if n.get_meta(&"elenco", &"") == Elenco.DONO:
				interior = _interior_de(n)
				if interior != null and interior.global_position.distance_to(casa_porta.origin) < 30.0:
					break
	return interior.estufa() if interior != null else null


# --- save -------------------------------------------------------------------

func para_dicionario() -> Dictionary:
	if estado == Estado.FORA:
		return {}
	var o := casa_porta.origin
	var e := _estado_para_salvar()
	return {
		"estado": int(e),
		"porta": [o.x, o.y, o.z, casa_porta.basis.get_euler().y],
		"semente": casa_semente,
	}


## Cena no meio nao vai para o save: volta ao ponto de controle anterior.
func _estado_para_salvar() -> Estado:
	match estado:
		Estado.DONO:
			return Estado.FORA
		Estado.PORAO:
			return Estado.NA_CASA
		Estado.BERG:
			if bool(Borboleta.valor(&"m1_aceitou_carona_berg", false)):
				return Estado.SEGUIR_BERG
			return Estado.NA_CASA if not Borboleta.tem(&"m1_aceitou_carona_berg") \
				else Estado.VOLTAR_PRACA
		Estado.IGREJA:
			return Estado.VOLTAR_PRACA if not bool(Borboleta.valor(&"m1_concluida", false)) \
				else Estado.CONCLUIDA
	return estado


func de_dicionario(dados: Dictionary) -> void:
	_desmontar()
	em_cena = false
	passeio = Passeio.NENHUM
	if dados.is_empty():
		estado = Estado.FORA
		casa_porta = Transform3D()
		Elenco.dupla_no_porao = false
		return
	var p: Array = dados.get("porta", [0, 0, 0, 0])
	casa_porta = Transform3D(Basis(Vector3.UP, float(p[3])),
		Vector3(float(p[0]), float(p[1]), float(p[2])))
	casa_semente = int(dados.get("semente", 0))
	estado = int(dados.get("estado", 0)) as Estado
	Elenco.dupla_no_porao = estado == Estado.NA_CASA
	call_deferred(&"_retomar")


## Depois da carga: a HUD e onde o Berg esta, pelo estado.
func _retomar() -> void:
	match estado:
		Estado.NA_CASA:
			_garantir_missao(_etapa_na_casa())
		Estado.SEGUIR_BERG, Estado.VOLTAR_PRACA:
			# O ponto de controle dos dois ramos e o Berg na igreja: a carona
			# salva no meio do caminho retoma com ele la, esperando.
			estado = Estado.VOLTAR_PRACA
			_garantir_missao({"texto": "", "dica": ""})
			_atualizar_etapa_da_praca()
			passeio = Passeio.SUMIDO
		Estado.CONCLUIDA:
			pass
	estado_mudou.emit(estado)


func _garantir_missao(etapa: Dictionary) -> void:
	if StringName(Missoes.atual.get("id", &"")) != ID:
		Missoes.comecar({"id": ID, "titulo": TITULO, "etapas": [etapa]})
	else:
		Missoes.trocar_etapa(etapa)

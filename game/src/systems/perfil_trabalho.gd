## O perfil de trabalho de qualquer pessoa da cidade, para o app Trampo.
##
## O registro civil so guarda a profissao como texto. Local, horario, tempo de
## casa e avaliacao sao derivados do id aqui, pelo mesmo principio do registro:
## deterministico, sem nada gravado, e a mesma pessoa tem o mesmo perfil em
## qualquer partida. Quem trabalha para o jogador (Jota, Helmer, contratados)
## tem perfil de verdade: funcoes da folha, o que esta fazendo agora e os numeros
## do iWeed e da estufa.
class_name PerfilTrabalho
extends RefCounted

## Onde cada profissao trabalha. Tres opcoes cada, escolhidas pelo id.
const LOCAIS := {
	"COMERCIARIO": ["LOJAS BRASILIA", "MAGAZINE CENTRAL", "CASA DAS LINHAS"],
	"OPERARIO": ["METALURGICA ACO FORTE", "FABRICA SAO JOSE", "TECELAGEM NEBLINA"],
	"MOTORISTA": ["VIACAO NEVOEIRO", "TAXI PONTO 14", "TRANSPORTADORA RIO CINZA"],
	"COSTUREIRA": ["ATELIE DONA CIDA", "CONFECCOES PRIMAVERA", "EM CASA, POR ENCOMENDA"],
	"PEDREIRO": ["OBRA DA AVENIDA", "CONSTRUTORA ALICERCE", "POR EMPREITADA"],
	"ENFERMEIRA": ["POSTO DE SAUDE CENTRAL", "HOSPITAL SANTA LUZIA", "PRONTO-SOCORRO"],
	"PROFESSOR": ["ESCOLA ESTADUAL ANITA", "COLEGIO SAO BENTO", "SUPLETIVO NOTURNO"],
	"CONTADOR": ["ESCRITORIO NUMERUS", "CONTABIL SILVA & FILHOS", "PREFEITURA"],
	"VIGILANTE": ["BANCO DO ESTADO", "GARAGEM MUNICIPAL", "CONDOMINIO BELA VISTA"],
	"COZINHEIRO": ["RESTAURANTE O TROPEIRO", "BAR DO SEU ZE", "COZINHA INDUSTRIAL"],
	"MECANICO": ["AUTO CENTER NEVOA", "OFICINA DO BIGODE", "RETIFICA ALIANCA"],
	"ELETRICISTA": ["COMPANHIA DE LUZ", "ELETRICA FAISCA", "POR CHAMADO"],
	"BANCARIO": ["BANCO DO ESTADO", "CAIXA ECONOMICA", "BANCO NACIONAL"],
	"FEIRANTE": ["FEIRA DE SABADO", "MERCADAO MUNICIPAL", "FEIRA DA PRACA"],
	"PORTEIRO": ["EDIFICIO SOLAR", "CONDOMINIO BELA VISTA", "EDIFICIO ITAPUA"],
	"CABELEIREIRA": ["SALAO CHARME", "STUDIO DIVA", "EM CASA"],
	"MARCENEIRO": ["MARCENARIA CEDRO", "MOVEIS SOB MEDIDA", "OFICINA PROPRIA"],
	"FARMACEUTICO": ["DROGARIA POPULAR", "FARMACIA SAO JOAO", "POSTO DE SAUDE CENTRAL"],
	"TELEFONISTA": ["TELEFONICA ESTADUAL", "CENTRAL DE TAXI", "HOSPITAL SANTA LUZIA"],
	"PADEIRO": ["PADARIA PAO QUENTE", "PANIFICADORA ESTRELA", "PADARIA DA ESQUINA"],
	"AUXILIAR DE LIMPEZA": ["PREFEITURA", "HOSPITAL SANTA LUZIA", "EDIFICIO SOLAR"],
	"DESPACHANTE": ["DESPACHANTE RAPIDO", "PORTA DO DETRAN", "ESCRITORIO PROPRIO"],
	"SAPATEIRO": ["SAPATARIA DO ZE", "CONSERTOS EXPRESSO", "BANCA DA PRACA"],
	"RELOJOEIRO": ["RELOJOARIA TIC-TAC", "JOALHERIA OURO FINO", "BANCA DA PRACA"],
	"MOTOBOY": ["DISQUE PIZZA", "ENTREGAS JA", "FARMACIA SAO JOAO"],
	"GARCOM": ["BAR DO SEU ZE", "RESTAURANTE O TROPEIRO", "CHURRASCARIA GAUCHA"],
}

## Turnos, em minutos do dia. [inicio, fim, rotulo]; fim menor que inicio vira a
## noite.
const TURNOS: Array = [
	[7 * 60, 16 * 60], [8 * 60, 18 * 60], [9 * 60, 17 * 60],
	[14 * 60, 22 * 60], [22 * 60, 6 * 60],
]
## Quem tem turno fixo pela natureza do trabalho.
const TURNO_FIXO := {
	"PADEIRO": [4 * 60, 12 * 60], "FEIRANTE": [5 * 60, 13 * 60],
	"VIGILANTE": [19 * 60, 7 * 60], "GARCOM": [18 * 60, 2 * 60],
	"PORTEIRO": [22 * 60, 6 * 60], "ENFERMEIRA": [19 * 60, 7 * 60],
}

const LOCAL_FAZENDA := "ESTUFA DA CASA DA FUMACA"
const LOCAL_IWEED := "IWEED ENTREGAS"


static func _h(id: int, canal: int) -> int:
	var x := (id * 2654435761 + canal * 40503 + 97) & 0x7fffffff
	x = ((x >> 13) ^ x) * 1274126177
	return (x ^ (x >> 16)) & 0x7fffffff


## Tudo o que o perfil mostra. `ficha` e a do RegistroCivil.
static func de(ficha: Dictionary) -> Dictionary:
	var id := int(ficha["id"])
	var profissao := String(ficha.get("profissao", ""))
	var funcoes := Profissoes.funcoes(id)
	var equipe := not funcoes.is_empty()
	var saida := {
		"id": id,
		"equipe": equipe,
		"cargos": Profissoes.titulos(id),
		"profissao": profissao,
	}
	if equipe:
		var locais := PackedStringArray()
		if funcoes.has(&"fazendeiro"):
			locais.append(LOCAL_FAZENDA)
		if funcoes.has(&"entregador"):
			locais.append(LOCAL_IWEED)
		saida["titulo"] = " E ".join(Profissoes.titulos(id))
		saida["local"] = "  /  ".join(locais)
		saida["horario"] = "QUANDO A ESTUFA PEDIR"
		var s := IWeed.situacao(id)
		saida["agora"] = String(s["texto"])
		saida["agora_extra"] = String(s.get("quando", ""))
		saida["ativo"] = true
		saida["fora"] = bool(s["fora"])
		var st := IWeed.estatisticas(id)
		saida["stats"] = st
		# Nota de verdade: parte fixa e o resto pelo que ele entregou no prazo.
		var entregas := int(st["entregas"])
		var prazo := float(st["no_prazo"]) / float(maxi(1, entregas))
		saida["estrelas"] = snappedf(clampf(3.5 + prazo * 1.5 if entregas > 0 else 4.5, 0.0, 5.0), 0.5)
		saida["avaliacoes"] = entregas
		saida["desde"] = "DESDE O COMECO" if RegistroCivil.personagem_de(id) != &"" \
			else "CONTRATADO POR VOCE"
		saida["sobre"] = _sobre_equipe(id)
		return saida

	var locais_prof: Array = LOCAIS.get(profissao, ["AUTONOMO"])
	saida["titulo"] = profissao
	saida["local"] = String(locais_prof[_h(id, 3) % locais_prof.size()])
	var turno: Array = TURNO_FIXO.get(profissao, TURNOS[_h(id, 5) % TURNOS.size()])
	var ini := int(turno[0])
	var fim := int(turno[1])
	saida["horario"] = "%02d:%02d - %02d:%02d" % [ini / 60, ini % 60, fim / 60, fim % 60]
	var m := WorldState.relogio.minutos() if WorldState.relogio != null else 0
	var ativo := (m >= ini and m < fim) if fim > ini else (m >= ini or m < fim)
	saida["ativo"] = ativo
	saida["fora"] = false
	saida["agora"] = "EM EXPEDIENTE" if ativo else "FORA DO EXPEDIENTE"
	saida["agora_extra"] = ""
	var idade := int(ficha.get("idade", 30))
	var anos := 1 + _h(id, 7) % maxi(1, mini(idade - 17, 30))
	saida["desde"] = "HA %d ANO%s NO CARGO" % [anos, "S" if anos > 1 else ""]
	saida["estrelas"] = 2.5 + float(_h(id, 11) % 6) * 0.5
	saida["avaliacoes"] = 3 + _h(id, 13) % 140
	saida["stats"] = {}
	saida["sobre"] = ""
	return saida


static func _sobre_equipe(id: int) -> String:
	match RegistroCivil.personagem_de(id):
		&"jota":
			return "Planta, colhe e entrega. Nao atende depois das tres, atende sim."
		&"helmer":
			return "Responsavel tecnico da Super. Cliente satisfeito ou em orbita."
	return "Trabalha para voce pela folha da estufa."

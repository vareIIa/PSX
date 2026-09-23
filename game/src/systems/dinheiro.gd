## O dinheiro do jogador. Nasce com o iWeed: ate aqui o jogo nao tinha moeda,
## e o "pagamento" do dono da casa era um bilhete.
##
## Por que nao e item de inventario
## --------------------------------
## Oito espacos de mochila e cada um deles vale ouro — pilha de nota ocupando um
## deles seria castigo, e uma pilha de 99 notas nao comporta a entrega da Super.
## Dinheiro aqui e um numero, com extrato, guardado no WorldState: entra no save
## como todo o resto do mundo, sem tocar no formato do inventario.
##
## Tudo e inteiro, em reais. 1998: ninguem paga baseado com centavo.
class_name Dinheiro
extends RefCounted

## Faixa reservada do WorldState, vizinha da das entregas da Super (-7) e do
## iWeed (-9). Ver FalasNpc.PESSOA.
const COORD := Vector2i(-8, 424243)
## Quantas linhas o extrato guarda. O app mostra as ultimas; o resto nao serve
## para nada alem de inchar o save.
const EXTRATO_MAX := 24


static func saldo() -> int:
	return int(WorldState.obter(COORD, &"saldo", 0))


## Soma `valor` e anota no extrato. Valor negativo e gasto; use `pagar`, que
## recusa quando nao ha saldo.
static func receber(valor: int, motivo: String) -> void:
	if valor == 0:
		return
	WorldState.definir(COORD, &"saldo", saldo() + valor)
	var lista: Array = extrato()
	var minuto := WorldState.relogio.minutos() if WorldState.relogio != null else 0
	lista.push_front({"valor": valor, "motivo": motivo, "hora": minuto})
	while lista.size() > EXTRATO_MAX:
		lista.pop_back()
	WorldState.definir(COORD, &"extrato", lista)
	if valor > 0:
		WorldState.definir(COORD, &"ganho_total", ganho_total() + valor)


static func pagar(valor: int, motivo: String) -> bool:
	if valor <= 0 or saldo() < valor:
		return false
	receber(-valor, motivo)
	return true


static func ganho_total() -> int:
	return int(WorldState.obter(COORD, &"ganho_total", 0))


## Mais recente primeiro. Cada linha: {valor, motivo, hora (minuto do dia)}.
static func extrato() -> Array:
	var bruto: Variant = WorldState.obter(COORD, &"extrato", [])
	return (bruto as Array).duplicate() if bruto is Array else []


## "R$ 1.250". Ponto de milhar, sem centavos.
static func formatar(valor: int) -> String:
	var negativo := valor < 0
	var s := str(absi(valor))
	var saida := ""
	while s.length() > 3:
		saida = "." + s.substr(s.length() - 3) + saida
		s = s.substr(0, s.length() - 3)
	return ("-R$ " if negativo else "R$ ") + s + saida

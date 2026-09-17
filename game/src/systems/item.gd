## Definicao de um item. Recurso, nao classe de codigo.
##
## Item em .tres e editavel sem recompilar, aparece no diff do git e pode ser
## referenciado por outros recursos. Item em constante de script obriga a mexer
## em codigo para mudar o texto de uma bandagem.
class_name Item
extends Resource

enum Tipo {
	CURA,        ## bandagem, remedio
	MUNICAO,     ## conta em unidades, nunca em porcentagem
	ARMA,
	FERRAMENTA,  ## lanterna, pe de cabra
	CHAVE,       ## abre uma porta especifica
	DOCUMENTO,   ## bilhete, fita, foto
	## terra, semente, colheita. Entra no fim da lista de proposito: os .tres
	## gravam o tipo como NUMERO, e inserir um valor no meio trocaria em
	## silencio a bandagem por municao em onze arquivos ja gravados.
	INSUMO,
}

@export var id: StringName = &""
@export var nome: String = "Item"

## Texto do painel de exame. Primeira pessoa, do personagem, nunca de manual:
## a referencia de inventario diz "espero nao precisar", nao "arma de fogo
## semiautomatica".
@export_multiline var descricao: String = ""

@export var tipo: Tipo = Tipo.DOCUMENTO
@export var icone: Texture2D

@export_group("Pilha")
@export var empilhavel: bool = false
@export_range(1, 99) var max_pilha: int = 1

@export_group("Uso")
## Some do inventario ao ser usado.
@export var consumivel: bool = false
## Quanto de vida devolve. So vale para Tipo.CURA.
@export_range(0, 100) var cura: int = 0
## Municao que este item repoe, por id de arma.
@export var municao_de: StringName = &""


func e_empilhavel() -> bool:
	return empilhavel and max_pilha > 1


## Rotulo curto do tipo, para o painel. Cabe pouco numa tela de 480x270.
func rotulo_tipo() -> String:
	match tipo:
		Tipo.CURA: return "CURATIVO"
		Tipo.MUNICAO: return "MUNICAO"
		Tipo.ARMA: return "ARMA"
		Tipo.FERRAMENTA: return "FERRAMENTA"
		Tipo.CHAVE: return "CHAVE"
		Tipo.INSUMO: return "INSUMO"
		_: return "DOCUMENTO"

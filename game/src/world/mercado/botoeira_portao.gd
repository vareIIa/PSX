## A botoeira da parede da garagem: sobe e desce o portao de aco.
##
## Mora na planta (MercadoBuilder, `no_mundo`), e o portao mora no predio
## (PortaoEnrolar): os dois nascem em momentos diferentes, um com a loja e o
## outro com o chunk. A botoeira acha o portao pela proximidade na hora em que e
## apertada, e nao quando nasce — o portao pode ainda nem existir quando a loja
## e montada, e pode ter sido recriado pelo streaming desde entao.
class_name BotoeiraPortao
extends Interativo

## O portao fica a poucos metros da botoeira. Mais que isto e o portao da loja
## vizinha, e a botoeira nao abre portao de outra loja.
const ALCANCE := 6.0


static func criar(prop: Dictionary) -> BotoeiraPortao:
	var b := BotoeiraPortao.new()
	b.name = "BotoeiraPortao"
	b.position = prop["pos"]
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = prop.get("tamanho", Vector3(0.5, 0.6, 0.6))
	forma.shape = caixa
	b.add_child(forma)
	return b


func interagir(quem: Node) -> void:
	if not habilitado:
		return
	var p := portao()
	if p == null:
		return
	AudioDirector.tocar(&"interruptor", global_position, -6.0)
	p.alternar()
	acionado.emit(quem)


func rotulo_atual() -> String:
	var p := portao()
	if p == null:
		return "Portao"
	if p.em_movimento():
		return "Parar e descer" if p.abrindo() else "Parar e subir"
	return "Descer o portao" if p.abrindo() else "Subir o portao"


func portao() -> PortaoEnrolar:
	var melhor: PortaoEnrolar = null
	var perto := ALCANCE
	for no: Node in get_tree().get_nodes_in_group(&"portao_enrolar"):
		var p := no as PortaoEnrolar
		if p == null:
			continue
		var d := p.global_position.distance_to(global_position)
		if d < perto:
			perto = d
			melhor = p
	return melhor

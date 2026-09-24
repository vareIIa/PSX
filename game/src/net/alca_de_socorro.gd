## O [E] no amigo caido: "Levantar ZE", e, enquanto se segura, "Levantando ZE
## 60%". O progresso vai no proprio prompt, que o `Player` ja relê a cada quadro
## (`rotulo_atual`); nao precisa de barra nova na HUD.
##
## Fica sem camada nenhuma enquanto o amigo esta de pe: uma area desligada ainda
## pararia o raio de mira, e o amigo na frente de uma porta esconderia a porta.
class_name AlcaDeSocorro
extends Interativo

var dono: int = 0
var nome: String = ""


func _ready() -> void:
	super()
	name = "Socorro"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	# O corpo deitado, de qualquer lado: dois metros em volta dos pes, um de altura.
	caixa.size = Vector3(2.0, 1.0, 2.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.5, 0.0)
	add_child(forma)
	atualizar(false)


func atualizar(usavel: bool) -> void:
	habilitado = usavel
	collision_layer = CAMADA if usavel else 0


func interagir(_quem: Node) -> void:
	if habilitado:
		Sessao.socorro.comecar_a_levantar(dono)


func rotulo_atual() -> String:
	var p := Sessao.socorro.progresso(dono)
	if p >= 0.0:
		return "Levantando %s %d%%" % [nome, int(p * 100.0)]
	return "Levantar %s" % nome

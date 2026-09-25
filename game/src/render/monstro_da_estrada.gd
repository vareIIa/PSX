## O que veste um encapuzado da estrada: o capuz, e debaixo dele o rosto.
##
## Por que existe
## --------------
## O padre principal e os romeiros deixaram de ser o buraco preto com dois
## pontos: o padre tem a cabeca da criatura (`CabecaDoPadre`), os outros o rosto
## enfaixado (`RostoEnfaixado`). A abertura e a bancada de close
## (`BancadaMonstros`) vestem pelo mesmo caminho, e cada rosto mora no seu
## arquivo — duas frentes trabalham neles ao mesmo tempo.
##
## A cabeca de caixa do `Corpo`
## ----------------------------
## O rosto de verdade nao cabe dentro da caixa de 21 cm: ela furaria a pele. O
## osso da cabeca e encolhido (`ESCALA_SUMIDA`) e a caixa some com ele; o que
## estiver pendurado nesse osso (o capuz, o rosto) recebe a escala inversa e
## fica do tamanho certo. Nenhuma pose do `Corpo` escreve escala, entao o
## encolhido dura ate o proximo `montar`.
class_name MonstroDaEstrada
extends RefCounted

const ESCALA_SUMIDA := 0.001


## Veste o capuz em `c` (ja montado) e poe o rosto debaixo dele: a criatura se
## `grande`, a faixa se nao. Deixa os metas `capuz` e `rosto` (este so se o
## rosto existe). Devolve o capuz.
static func vestir(c: Corpo, i: int, largura: float, grande: bool) -> CapuzMacabro:
	var capuz := CapuzMacabro.vestir(c, i, largura, true)
	c.set_meta(&"capuz", capuz)
	if capuz == null:
		return null
	var rosto: Node3D
	if grande:
		rosto = CabecaDoPadre.vestir(c, capuz)
	else:
		rosto = RostoEnfaixado.vestir(c, capuz, i)
	if rosto != null:
		capuz.abrir_para_rosto(rosto)
		c.set_meta(&"rosto", rosto)
	# O pano vem por ultimo: o capuz se ajusta ao cranio que ficou debaixo.
	if not OS.get_cmdline_user_args().has("--sem-pano"):
		capuz.vestir_pano(c)
	return capuz


## Some com a cabeca de caixa de `c` e devolve um no no espaco do osso da
## cabeca, do tamanho certo, para o rosto de verdade. O plano do rosto do
## `Corpo` (`plano_do_rosto`) continua valendo nesse espaco.
static func no_da_cabeca(c: Corpo, nome: String) -> Node3D:
	var esq := c.esqueleto()
	if esq == null:
		return null
	esq.set_bone_pose_scale(Corpo.Osso.CABECA, Vector3.ONE * ESCALA_SUMIDA)
	var preso := BoneAttachment3D.new()
	preso.name = nome + "Osso"
	preso.bone_idx = Corpo.Osso.CABECA
	esq.add_child(preso)
	# Quem ja estava pendurado na cabeca (o capuz) volta ao tamanho.
	for f: Node in esq.get_children():
		var ba := f as BoneAttachment3D
		if ba == null or ba == preso or ba.bone_idx != Corpo.Osso.CABECA:
			continue
		for g: Node in ba.get_children():
			var n := g as Node3D
			if n != null and not n.has_meta(&"desencolhido"):
				n.scale = Vector3.ONE / ESCALA_SUMIDA
				n.set_meta(&"desencolhido", true)
	var no := Node3D.new()
	no.name = nome
	no.scale = Vector3.ONE / ESCALA_SUMIDA
	no.set_meta(&"desencolhido", true)
	preso.add_child(no)
	return no

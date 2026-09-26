## O que veste um encapuzado da estrada: o capuz, e debaixo dele o rosto.
##
## Por que existe
## --------------
## O padre principal e os romeiros deixaram de ser o buraco preto com dois
## pontos: todos tem a cabeca da criatura — o padre a `CabecaDoPadre` inteira,
## os outros a `CabecaDeFundo` (a mesma criatura, variada por semente, com
## material dividido e parada). A faixa (`RostoEnfaixado`) ficou para o A/B e
## para quem assa a multidao. A abertura e a bancada de close
## (`BancadaMonstros`) vestem pelo mesmo caminho, e cada rosto mora no seu
## arquivo — duas frentes trabalham neles ao mesmo tempo.
##
## Os de fundo usam os bracos para fora (meta `bracos_de_fora` no `Corpo`):
## murca curta e batina mais justa no capuz (`CapuzMacabro.vestir_pano`), e os
## `BracosPodres` compridos, com a manga larga e a mao grande. O principal fica
## como era.
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

## Os de fundo com a faixa no lugar da cabeca (quem assa o rosto da multidao a
## partir da faixa liga isto antes de vestir).
static var faixa_nos_de_fundo := false


## Veste o capuz em `c` (ja montado) e poe o rosto debaixo dele: a criatura do
## principal se `grande`, a de fundo (`rosto_de_fundo`) se nao. Deixa os metas
## `capuz` e `rosto` (este so se o rosto existe) e, pelos `BracosPodres`, o
## `dedos`. Devolve o capuz.
static func vestir(c: Corpo, i: int, largura: float, grande: bool) -> CapuzMacabro:
	var capuz := CapuzMacabro.vestir(c, i, largura, true)
	c.set_meta(&"capuz", capuz)
	if capuz == null:
		return null
	var rosto: Node3D
	if grande:
		rosto = CabecaDoPadre.vestir(c, capuz)
	else:
		rosto = rosto_de_fundo(c, capuz, i)
	if rosto != null:
		capuz.abrir_para_rosto(rosto)
		c.set_meta(&"rosto", rosto)
	# Os de fundo mostram os bracos: a murca nao cobre, a batina nao engole, e
	# os `BracosPodres` saem compridos, de manga larga e mao grande.
	c.set_meta(&"bracos_de_fora",
		not grande and not OS.get_cmdline_user_args().has("--bracos-de-caixa"))
	# O pano vem por ultimo: o capuz se ajusta ao cranio que ficou debaixo.
	if not OS.get_cmdline_user_args().has("--sem-pano"):
		capuz.vestir_pano(c)
	# E os bracos de caixa viram os podres (o do padre, na janela, some inteiro
	# pela escala do osso e da lugar aos `BracoVivo`).
	BracosPodres.vestir(c)
	return capuz


## O rosto de quem nao e o padre principal: a criatura do principal, variada
## pela semente e barata (`CabecaDeFundo`). A faixa (`RostoEnfaixado`) volta com
## `--romeiro-faixa` (o A/B) ou `faixa_nos_de_fundo` (quem assa o rosto da
## multidao a partir da faixa), e se a malha da cabeca nao carregar.
static func rosto_de_fundo(c: Corpo, capuz: CapuzMacabro, i: int) -> Node3D:
	if faixa_nos_de_fundo or OS.get_cmdline_user_args().has("--romeiro-faixa"):
		return RostoEnfaixado.vestir(c, capuz, i)
	var cab := CabecaDeFundo.vestir_fundo(c, capuz, i)
	if cab != null:
		return cab
	return RostoEnfaixado.vestir(c, capuz, i)


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

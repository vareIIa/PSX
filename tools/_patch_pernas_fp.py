# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# Add var near other vars
if "var _pernas_fp" not in t:
    t = t.replace("var _apoio: OmniLight3D\n", "var _apoio: OmniLight3D\nvar _pernas_fp: Node3D\n", 1)

# Insert helpers before _plano_da_praca (after _ponto_osso)
helpers = r'''
## Pernas FP (calca+bota) coladas na camera de cinema — o Corpo deitado le como
## massa/cubo no FOV baixo. Removidas no levantar.
func _limpar_pernas_fp() -> void:
	if _pernas_fp != null and is_instance_valid(_pernas_fp):
		_pernas_fp.queue_free()
	_pernas_fp = null


func _caixa_fp(pai: Node3D, tam: Vector3, pos: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tam
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.92
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = mat
	pai.add_child(mi)
	mi.position = pos


func _montar_pernas_fp(cam: Camera3D) -> void:
	_limpar_pernas_fp()
	if cam == null:
		return
	_pernas_fp = Node3D.new()
	_pernas_fp.name = "PernasFPAcordar"
	cam.add_child(_pernas_fp)
	# Espaco da camera: -Z frente, Y cima. Terco baixo do frame (ref 01).
	var calca := Color("2a3340")
	var bota := Color("1a1410")
	for lado in [-1.0, 1.0]:
		var x := 0.11 * lado
		_caixa_fp(_pernas_fp, Vector3(0.13, 0.38, 0.16), Vector3(x, -0.32, -0.55), calca)
		_caixa_fp(_pernas_fp, Vector3(0.11, 0.34, 0.14), Vector3(x, -0.48, -0.88), calca)
		_caixa_fp(_pernas_fp, Vector3(0.12, 0.08, 0.26), Vector3(x, -0.62, -1.12), bota)


'''

if "_montar_pernas_fp" not in t:
    marker = "func _ponto_osso(figura: Corpo, osso: int) -> Vector3:"
    # insert AFTER _ponto_osso function
    idx = t.find(marker)
    if idx < 0:
        raise SystemExit("ponto_osso missing")
    # find next func after ponto_osso
    end = t.find("\nfunc _plano_da_praca", idx)
    if end < 0:
        raise SystemExit("plano after ponto missing")
    t = t[:end] + "\n" + helpers + t[end:]

# In _plano_da_praca after Cinema.mover, mount legs and hide corpo
old = """\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\t# Lampiao quente a ESQUERDA (ref 01 / pin SW ~265,-40).
\tif _apoio != null and is_instance_valid(_apoio):
\t\t_apoio.global_position = Vector3(265.0, onde.y + 3.4, -40.0)
\t\t_apoio.light_color = Color(\"ffb45a\")
\t\t_apoio.light_energy = 6.0
\t\t_apoio.omni_range = 10.0

\tif _hud != null:"""
old = old.replace('\\"', '"')
new = """\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\t# Lampiao quente a ESQUERDA (ref 01 / pin SW ~265,-40).
\tif _apoio != null and is_instance_valid(_apoio):
\t\t_apoio.global_position = Vector3(265.0, onde.y + 3.4, -40.0)
\t\t_apoio.light_color = Color(\"ffb45a\")
\t\t_apoio.light_energy = 6.0
\t\t_apoio.omni_range = 10.0

\t# Corpo deitado vira massa no FP — pernas reais na camera; esconde o mesh.
\t_jogador.mostrar_corpo(false)
\t_montar_pernas_fp(Cinema.assumir())

\tif _hud != null:"""
new = new.replace('\\"', '"')
if old not in t:
    raise SystemExit("mover block for pernas missing")
t = t.replace(old, new, 1)

# Before levantar: remove FP legs, show corpo again
old_l = """\tif figura != null:
\t\t_levantar(figura, ACORDA_SUBIDA)"""
new_l = """\t_limpar_pernas_fp()
\t_jogador.mostrar_corpo(true)
\tif figura != null:
\t\tfigura.postura(Corpo.Postura.LIVRE)
\t\t_levantar(figura, ACORDA_SUBIDA)"""
if old_l not in t:
    raise SystemExit("levantar hook missing")
t = t.replace(old_l, new_l, 1)

p.write_text(t, encoding="utf-8")
print("OK pernas FP props")

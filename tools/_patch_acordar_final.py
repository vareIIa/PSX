# -*- coding: utf-8 -*-
from pathlib import Path
import re

p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

if "var _pernas_fp" not in t:
    m = re.search(r"(var _apoio[^\n]*\n)", t)
    if not m:
        raise SystemExit("no _apoio var")
    t = t[: m.end()] + "var _pernas_fp: Node3D = null\n" + t[m.end() :]

HELPERS = """
func _limpar_pernas_fp() -> void:
\tif _pernas_fp != null and is_instance_valid(_pernas_fp):
\t\t_pernas_fp.queue_free()
\t_pernas_fp = null


func _caixa_fp(pai: Node3D, tam: Vector3, pos: Vector3, cor: Color) -> void:
\tvar mi := MeshInstance3D.new()
\tvar box := BoxMesh.new()
\tbox.size = tam
\tmi.mesh = box
\tvar mat := StandardMaterial3D.new()
\tmat.albedo_color = cor
\tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
\tmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
\tmi.material_override = mat
\tpai.add_child(mi)
\tmi.position = pos


func _montar_pernas_fp(cam: Camera3D) -> void:
\t_limpar_pernas_fp()
\tif cam == null:
\t\treturn
\t_pernas_fp = Node3D.new()
\t_pernas_fp.name = "PernasFPAcordar"
\tcam.add_child(_pernas_fp)
\tvar calca := Color("3a4555")
\tvar bota := Color("0a0806")
\tfor s in [-1.0, 1.0]:
\t\tvar x: float = 0.11 * s
\t\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.12, 0.48), Vector3(x, -0.08, -0.50), calca)
\t\t_caixa_fp(_pernas_fp, Vector3(0.12, 0.11, 0.40), Vector3(x, -0.14, -0.96), calca)
\t\t_caixa_fp(_pernas_fp, Vector3(0.13, 0.10, 0.16), Vector3(x, -0.17, -1.24), bota)
\t\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.07, 0.14), Vector3(x, -0.20, -1.40), bota)


"""

if "func _montar_pernas_fp" not in t:
    idx = t.find("func _plano_da_praca")
    if idx < 0:
        raise SystemExit("no _plano_da_praca")
    t = t[:idx] + HELPERS + t[idx:]

if "yaw travado norte" not in t:
    pat = (
        r"\t# Virar pra praca antes de deitar:.*?\n(?:\t#[^\n]*\n)*"
        r"\tvar praca_alvo := _praca_mais_perto\(onde\)\n"
        r"\tif praca_alvo != Vector3\.INF:\n"
        r"\t\tvar para := Vector3\(praca_alvo\.x - onde\.x, 0\.0, praca_alvo\.z - onde\.z\)\n"
        r"\t\tif para\.length_squared\(\) > 1\.0:\n"
        r"\t\t\t#[^\n]*\n"
        r"\t\t\t_jogador\.rotation\.y = atan2\(-para\.x, -para\.z\)\n"
    )
    m = re.search(pat, t, re.S)
    if not m:
        raise SystemExit("yaw block missing")
    t = (
        t[: m.start()]
        + "\t# Pin Cleiton/Jota: yaw travado norte (lampiao SW a esquerda).\n"
        + "\t_jogador.rotation.y = 0.0\n"
        + t[m.end() :]
    )

plano = t.find("func _plano_da_praca")
i = t.find("var alvo_look := Vector3(", plano)
if i < 0:
    raise SystemExit("alvo_look missing")
j = t.find("var t0 := Time.get_ticks_msec()", i)
cam = """\tvar alvo_look := Vector3(272.0, 0.0, -58.0)
\tvar frente_praca := Vector3(alvo_look.x - onde.x, 0.0, alvo_look.z - onde.z)
\tif frente_praca.length_squared() < 0.01:
\t\tfrente_praca = Vector3(0.0, 0.0, -1.0)
\tfrente_praca = frente_praca.normalized()

\t# Pin-world rasteiro + props FP na cam (Corpo deitado le como massa).
\tvar cam_de := Vector3(onde.x, onde.y + 0.20, onde.z)
\tvar olhar_de := Vector3(onde.x, onde.y + 0.06, onde.z) + frente_praca * 2.4
\tvar cam_ate := Vector3(onde.x, onde.y + ACORDA_ALTURA.y, onde.z)
\tvar olhar_ate := Vector3(onde.x, onde.y + 1.15, onde.z) + frente_praca * ACORDA_OLHAR_LONGE

"""
t = t[:i] + cam + t[j:]

k = t.find("# Lampiao quente a ESQUERDA", plano)
if k < 0:
    raise SystemExit("lamp missing")
seg = t[k : k + 800]
if "_jogador.mostrar_corpo(false)" not in seg:
    hud = t.find("\tif _hud != null:\n\t\t_hud.visible = true", k)
    if hud < 0:
        raise SystemExit("hud show missing")
    t = t[:hud] + "\t_jogador.mostrar_corpo(false)\n\n" + t[hud:]

if "_montar_pernas_fp(Cinema.assumir())" not in t[plano : plano + 2500]:
    needle = 'await Cinema.clarear(2.2)\n\tCinema.legenda(FALAS["acorda"], 2.2)'
    repl = 'await Cinema.clarear(2.2)\n\t_montar_pernas_fp(Cinema.assumir())\n\tCinema.legenda(FALAS["acorda"], 2.2)'
    if needle not in t:
        raise SystemExit("clarear needle missing")
    t = t.replace(needle, repl, 1)

chao = t.find('await _capturar_plano("01_acordar_chao")')
pe = t.find('await _capturar_plano("01_acordar_pe")')
frag = t[chao:pe]
if "_limpar_pernas_fp()" not in frag:
    old = "\tif figura != null:\n\t\t_levantar(figura, ACORDA_SUBIDA)"
    new = (
        "\t_limpar_pernas_fp()\n"
        "\t_jogador.mostrar_corpo(true)\n"
        "\tif figura != null:\n"
        "\t\tfigura.postura(Corpo.Postura.LIVRE)\n"
        "\t\t_levantar(figura, ACORDA_SUBIDA)"
    )
    if old not in frag:
        raise SystemExit("levantar missing")
    t = t[:chao] + frag.replace(old, new, 1) + t[pe:]

p.write_text(t, encoding="utf-8", newline="\n")
print("OK abertura final")

# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
t = p.read_text(encoding="utf-8")
old = '''func _tapar_vao_pescoco_retrato() -> void:
	var apar := aparencia_atual()
	var pele := Aparencia.pele_na_tela(apar)
	var camisa: Color = (apar["casaco_cor"] if bool(apar.get("casaco", false))
		else apar["camisa_cor"])
	var cx := RETRATO.position.x + RETRATO.size.x * 0.5
	# Faixa do vão no crop atual da CameraRetrato (~55–70% da altura).
	var y0 := RETRATO.position.y + RETRATO.size.y * 0.52
	draw_rect(Rect2(cx - 16.0, y0, 32.0, 12.0), pele)
	draw_rect(Rect2(cx - 12.0, y0 + 2.0, 24.0, 8.0), pele.darkened(0.08))
	draw_rect(Rect2(cx - 34.0, y0 + 10.0, 68.0, 16.0), camisa)
	draw_rect(Rect2(cx - 30.0, y0 + 12.0, 60.0, 6.0), camisa.lightened(0.08))
'''
new = '''func _tapar_vao_pescoco_retrato() -> void:
	var apar := aparencia_atual()
	var pele := Aparencia.pele_na_tela(apar)
	var camisa: Color = (apar["casaco_cor"] if bool(apar.get("casaco", false))
		else apar["camisa_cor"])
	var cx := RETRATO.position.x + RETRATO.size.x * 0.5
	# Medido no capture: vão escuro em ~42–51% da altura do RETRATO.
	var y0 := RETRATO.position.y + RETRATO.size.y * 0.42
	draw_rect(Rect2(cx - 22.0, y0, 44.0, 24.0), pele)
	draw_rect(Rect2(cx - 18.0, y0 + 3.0, 36.0, 16.0), pele.darkened(0.10))
	draw_rect(Rect2(cx - 42.0, y0 + 18.0, 84.0, 24.0), camisa)
	draw_rect(Rect2(cx - 36.0, y0 + 20.0, 72.0, 8.0), camisa.lightened(0.08))
'''
if old not in t:
    raise SystemExit("missing tapar")
p.write_text(t.replace(old, new, 1), encoding="utf-8")
print("ok")

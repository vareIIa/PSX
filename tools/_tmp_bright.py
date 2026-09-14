from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
t = p.read_text(encoding="utf-8")
t = t.replace(
'''	if _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false,
			Color(0.85, 0.86, 0.82, 1.0))
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.28))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.45))
''',
'''	if _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.42))
''')
p.write_text(t, encoding="utf-8")
print("brightened")

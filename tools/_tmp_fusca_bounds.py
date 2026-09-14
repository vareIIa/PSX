from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")
func_idx = text.find("static func _lataria_fusca")
start = text.rfind("## Fusca:", 0, func_idx)
end = text.index("## A cacamba da picape")
print("start", start, "end", end, "len", end-start)
print(text[start:start+80])

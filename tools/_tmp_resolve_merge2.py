from pathlib import Path
import re
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
t = p.read_text(encoding="utf-8")
pattern = re.compile(r"<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> feat/blitz-aaa\n", re.S)

def resolve(ours, theirs):
    if "--ver-estrada-cabine" in ours and "--blitz-demo" in theirs:
        return '\t\tif a in ["--pular-menu", "--ver-abertura", "--ver-estrada", "--ver-estrada-cabine", "--ver-praca", "--olhar-blitz", "--blitz-demo"] or a.begins_with("--olhar-blitz=") or a.begins_with("--blitz-demo="):\n'
    if "Ordem: Estrada Velha" in ours and "_rodar_estrada" in theirs:
        helper = (
            "\n## Caminho de captura / inspecao da Estrada Velha (mapa) sem passar pelo menu.\n"
            "func _rodar_estrada() -> void:\n"
            "\tvar _scr = load(\"res://src/levels/abertura_estrada.gd\")\n"
            "\tvar estrada = _scr.new()\n"
            "\tadd_child(estrada)\n"
            "\testrada.executar(self)\n\n"
        )
        return ours + "\n" + helper
    raise SystemExit("unknown conflict\nOURS:\n%s\nTHEIRS:\n%s" % (ours[:300], theirs[:300]))

parts = []
last = 0
n = 0
for m in pattern.finditer(t):
    parts.append(t[last:m.start()])
    parts.append(resolve(m.group(1), m.group(2)))
    last = m.end()
    n += 1
parts.append(t[last:])
out = "".join(parts)
assert n == 2, n
assert "<<<<<<<" not in out
p.write_text(out, encoding="utf-8", newline="\n")
print("ok resolved", n)
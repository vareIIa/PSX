from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
old = "\t# --- Part A: POV olho no ceu / nevoa (sem stand-up) --------------------\n\t_limpar_pernas_fp()\n\t_jogador.mostrar_corpo(false)\n"
new = "\t# --- Part A: POV olho no ceu / nevoa (sem stand-up) --------------------\n\t_jogador.mostrar_corpo(false)\n"
if old not in t:
    raise SystemExit("needle missing")
t = t.replace(old, new, 1)
# drop unused _pernas_fp var if still declared
t2 = t.replace("\nvar _pernas_fp: Node3D = null\n", "\n", 1)
if t2 == t:
    print("warn: _pernas_fp var not removed")
else:
    t = t2
    print("removed _pernas_fp var")
p.write_text(t, encoding="utf-8")
print("OK fixed limpar call")

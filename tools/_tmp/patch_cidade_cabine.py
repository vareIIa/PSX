from pathlib import Path
src = Path(r"game/src/levels/cidade.gd")
t = src.read_text(encoding="utf-8")

# Boot hook line
old = 'if OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-estrada") or OS.get_cmdline_user_args().has("--ver-praca"):'
new = 'if OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-estrada") or OS.get_cmdline_user_args().has("--ver-estrada-cabine") or OS.get_cmdline_user_args().has("--ver-praca"):'
if old not in t:
    # try shorter variants
    for cand in [
        'if OS.get_cmdline_user_args().has("--ver-abertura"):',
        'if OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-estrada"):',
    ]:
        if cand in t:
            t = t.replace(cand, new, 1)
            break
    else:
        raise SystemExit("boot hook missing: "+repr([ln for ln in t.splitlines() if "ver-abertura" in ln][:5]))
else:
    t = t.replace(old, new, 1)

# skip menu list
old = 'if a in ["--pular-menu", "--ver-abertura", "--ver-estrada", "--ver-praca"]:'
new = 'if a in ["--pular-menu", "--ver-abertura", "--ver-estrada", "--ver-estrada-cabine", "--ver-praca"]:'
if old not in t:
    old2 = 'if a in ["--pular-menu", "--ver-abertura"]:'
    if old2 in t:
        t = t.replace(old2, new, 1)
    else:
        raise SystemExit("skip menu missing: "+repr([ln for ln in t.splitlines() if "pular-menu" in ln][:5]))
else:
    t = t.replace(old, new, 1)

# _rodar_abertura so_estrada should treat cabine as so_estrada (don't continue to praca)
old = 'var so_estrada := OS.get_cmdline_user_args().has("--ver-estrada")'
new = 'var so_estrada := (OS.get_cmdline_user_args().has("--ver-estrada")\n\t\tor OS.get_cmdline_user_args().has("--ver-estrada-cabine"))'
if old in t:
    t = t.replace(old, new, 1)
else:
    print("WARN: so_estrada line not found — may be ok if structure differs")

src.write_text(t, encoding="utf-8")
print("cidade ok")
for ln in t.splitlines():
    if "ver-estrada" in ln:
        print(ln.strip())

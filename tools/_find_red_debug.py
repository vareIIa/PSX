import os, re
root = r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src"
pat = re.compile(
    r"CaptureTool|ver-praca|ver_praca|debug_draw|DebugDraw|visible_collision|"
    r'Color\(1,\s*0,\s*0|"ff0000"|"c02020"|"e01010"|debug_pin|DEBUG_MARK|'
    r"marcador_debug|gizmo|debug_flor|flor_debug",
    re.I,
)
n = 0
for dp, _, fs in os.walk(root):
    for f in fs:
        if not f.endswith(".gd"):
            continue
        p = os.path.join(dp, f)
        try:
            lines = open(p, encoding="utf-8", errors="ignore").read().splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines, 1):
            if pat.search(line):
                rel = os.path.relpath(p, root)
                print("%s:%d:%s" % (rel, i, line.strip()[:140]))
                n += 1
                if n >= 60:
                    raise SystemExit
print("done", n)

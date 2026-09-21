from pathlib import Path
import re
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\ui_estilo.gd")
t = p.read_text(encoding="utf-8")
t2 = t.replace("const RE7_SIZE_DISPLAY := 16", "const RE7_SIZE_DISPLAY := 18")
t2 = t2.replace("const RE7_SIZE_TITLE := 13", "const RE7_SIZE_TITLE := 14")
if "const RE7_PAD_PANEL" not in t2:
    needle = "const RE7_SIZE_MICRO := 9\n"
    insert = needle + (
        "## SPEC_POLISH_TIPO_LAYOUT_RE7 — pad/ritmo (prancha/sistema).\n"
        "const RE7_PAD_PANEL := 10\n"
        "const RE7_PAD_MODAL := 12\n"
        "const RE7_ROW := 16\n"
        "const RE7_ROW_GAP := 2\n"
        "const RE7_LINE_BODY := 14\n"
        "const RE7_LINE_TITLE := 18\n"
        "const RE7_LINE_DISPLAY := 22\n"
        "const RE7_LINE_MICRO := 11\n"
    )
    if needle in t2:
        t2 = t2.replace(needle, insert, 1)
p.write_text(t2, encoding="utf-8", newline="\n")
print(re.findall(r"RE7_(?:SIZE|PAD|ROW|LINE)_\w+ := \d+|RE7_ROW := \d+|RE7_ROW_GAP := \d+", t2))

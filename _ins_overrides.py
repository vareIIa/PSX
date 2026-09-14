# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura_estrada.gd")
t = p.read_text(encoding="utf-8")
if "func _aplicar_overrides_hud" in t:
    print("already defined")
else:
    helper = (
        "\n## Overrides de captura: --hora=HH:MM, --vida=N, --lanterna-off, --local=NOME.\n"
        "func _aplicar_overrides_hud() -> void:\n"
        "\tif _hud == null:\n"
        "\t\treturn\n"
        "\tfor arg: String in OS.get_cmdline_user_args():\n"
        '\t\tif arg.begins_with("--hora="):\n'
        '\t\t\t_hud.definir_hora(arg.trim_prefix("--hora="))\n'
        '\t\telif arg.begins_with("--vida="):\n'
        '\t\t\t_hud.definir_vida(int(arg.trim_prefix("--vida=")), 10)\n'
        '\t\telif arg.begins_with("--local="):\n'
        '\t\t\t_hud.definir_local(arg.trim_prefix("--local=").replace("_", " "))\n'
        '\t\telif arg == "--lanterna-off":\n'
        "\t\t\t_hud.definir_lanterna(false)\n\n\n"
    )
    marker = "func _flag_estrada_qualquer() -> bool:"
    if marker not in t:
        raise SystemExit("marker missing")
    t = t.replace(marker, helper + marker, 1)
    p.write_text(t, encoding="utf-8", newline="\n")
    print("inserted _aplicar_overrides_hud")
print("def count", t.count("func _aplicar_overrides_hud"))

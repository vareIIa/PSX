from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
t = p.read_text(encoding="utf-8")
# normalize comment
import re
t = re.sub(r"## Fundo de cabine.*\n",
           "## Fundo de cabine (capture) atras da carteira: evita o preto morto.\n", t, count=1)
old = "func _desenhar_abas() -> void:\n\tvar x := PAGINA_DIR.position.x\n\tvar largura := 28.0\n\tfor i in ABAS.size():"
new = "func _desenhar_abas() -> void:\n\tfor i in ABAS.size():"
if old in t:
    t = t.replace(old, new, 1)
    print("cleaned abas")
else:
    print("abas already clean or missing")
oldv = "\t_viewport.msaa_3d = Viewport.MSAA_DISABLED\n\tadd_child(_viewport)"
newv = "\t_viewport.msaa_3d = Viewport.MSAA_DISABLED\n\t_viewport.process_mode = Node.PROCESS_MODE_ALWAYS\n\tadd_child(_viewport)"
if oldv in t:
    t = t.replace(oldv, newv, 1)
    print("viewport process_mode set")
p.write_text(t, encoding="utf-8")
print("done")

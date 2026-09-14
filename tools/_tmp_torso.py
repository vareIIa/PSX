from pathlib import Path
from PIL import Image
import numpy as np

# Inspect lower third of after_02 for non-ground (character?)
im = np.array(Image.open(r"C:\Users\Administrator\Documents\Codes\Games\PSX\captures\praca_matriz\_sessao_praca_visual\after_02_deitado.png").convert("RGB"))
h,w,_=im.shape
low=im[int(h*0.55):int(h*0.92), int(w*0.25):int(w*0.75)]
# cobble is greyish; character clothes often darker or colored
print("low mid", low.mean(axis=(0,1)), "std", low.std())
# count dark reddish / blueish pixels
r,g,b = low[:,:,0], low[:,:,1], low[:,:,2]
clothes = ((r>40)&(r<120)&(g<90)&(b<90)) | ((b>g+15)&(b>40))
print("clothes-ish frac", clothes.mean())

ab = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = ab.read_text(encoding="utf-8")
# torso look should track deitado thickness on calcamento
old = "\tvar torso := Vector3(meio.x, onde.y + 0.38, meio.z)"
new = "\tvar torso := Vector3(meio.x, onde.y + KitParque.Y_CALCAMENTO + DEITADO_ALTURA + 0.12, meio.z)"
if old in t:
    t = t.replace(old, new, 1); print("torso Y OK")
else:
    print("MISS torso", "KitParque.Y_CALCAMENTO + DEITADO_ALTURA + 0.12" in t)
ab.write_text(t, encoding="utf-8")

# Also force night fog when ir-para near pin — patch cidade if --fog= handler exists via Settings
# Soften fog_denso wash for night look is too global; instead write NOTES that ir-para should use -- without fog=denso
# Patch fog_denso ambient down? Risky. Create mapping: when cmdline has ver-praca OR ir-para 270, force night.
cid = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
ct = cid.read_text(encoding="utf-8")
marker = "func _rodar_abertura() -> void:"
inject = '''func _rodar_abertura() -> void:
\t# Praça Matriz visual: noite escura (não fog_denso lavado).
\tvar args := OS.get_cmdline_user_args()
\tif args.has("--ver-praca") or any(a.begins_with("--ir-para=270") for a in args):
\t\tvar fog := get_node_or_null("Ambiente") as FogController
\t\tif fog != null:
\t\t\tfog.forcar("res://resources/fog/fog_noite_nublada.tres")
'''
# GDScript doesn't have Python any() — fix
inject = '''func _rodar_abertura() -> void:
\tvar args := OS.get_cmdline_user_args()
\tvar pin_praca := false
\tfor a in args:
\t\tif a.begins_with("--ir-para=270"):
\t\t\tpin_praca = true
\t\t\tbreak
\tif args.has("--ver-praca") or pin_praca:
\t\tvar fog := get_node_or_null("Ambiente") as FogController
\t\tif fog != null:
\t\t\tfog.forcar("res://resources/fog/fog_noite_nublada.tres")
'''
if "pin_praca" not in ct:
    if marker not in ct:
        print("MISS _rodar_abertura")
    else:
        # Keep original body after inject header — replace only the func line
        ct = ct.replace(marker, inject.rstrip() + "\n", 1)
        # Wait that removed the rest of function start - need to not duplicate. Better insert after func line.
        print("WARN need careful insert")
cid.write_text(ct, encoding="utf-8") if False else None
print("skip cidade for now - check abertura torso only")

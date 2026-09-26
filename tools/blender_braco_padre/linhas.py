import sys, json
from PIL import Image, ImageDraw
d = json.load(open(sys.argv[1]))
foto, saida, eixo = sys.argv[2], sys.argv[3], sys.argv[4]
c = [float(a) for a in sys.argv[5:8]]; s = float(sys.argv[8])
MAPA = {"+x": ((2, -1), (1, 1)), "-x": ((2, 1), (1, 1)), "+z": ((0, 1), (1, 1)), "-z": ((0, -1), (1, 1))}
(ed, sd), (ec, sc) = MAPA[eixo]
im = Image.open(foto).convert("RGB"); L = im.size[0]; dr = ImageDraw.Draw(im)
def uv(p): return ((0.5 + (p[ed] - c[ed]) * sd / s) * L, (0.5 - (p[ec] - c[ec]) * sc / s) * L)
cores = {"polegar": (255, 60, 60), "indicador": (255, 200, 0), "medio": (60, 255, 60), "anelar": (0, 200, 255), "minimo": (255, 0, 255)}
for nome, f in d.items():
    pts = [uv(q["c"]) for q in f["pts"]]
    dr.line(pts, fill=cores[nome], width=3)
    for i, q in enumerate(f["pts"]):
        if i % 5 == 0:
            u, v = uv(q["c"]); dr.ellipse([u - 4, v - 4, u + 4, v + 4], outline=cores[nome])
            dr.text((u + 6, v - 6), "%.2f" % q["d"], fill=cores[nome])
im.save(saida)

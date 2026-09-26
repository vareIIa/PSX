import sys, json
from PIL import Image, ImageDraw
j = json.load(open(sys.argv[1]))
foto, saida, eixo = sys.argv[2], sys.argv[3], sys.argv[4]
c = [float(a) for a in sys.argv[5:8]]; s = float(sys.argv[8])
MAPA = {"+x": ((2, -1), (1, 1)), "-x": ((2, 1), (1, 1)), "+z": ((0, 1), (1, 1)), "-z": ((0, -1), (1, 1))}
(ed, sd), (ec, sc) = MAPA[eixo]
im = Image.open(foto).convert("RGB"); L = im.size[0]; dr = ImageDraw.Draw(im)
def uv(p): return ((0.5 + (p[ed] - c[ed]) * sd / s) * L, (0.5 - (p[ec] - c[ec]) * sc / s) * L)
cores = {"polegar": (255, 60, 60), "indicador": (255, 200, 0), "medio": (60, 255, 60), "anelar": (0, 200, 255), "minimo": (255, 0, 255)}
pu = uv(j["braco"]["punho"])
for nome, lista in j["dedos"].items():
    pts = [pu] + [uv(q["p"]) for q in lista]
    dr.line(pts, fill=cores[nome], width=4)
    for u, v in pts:
        dr.ellipse([u - 9, v - 9, u + 9, v + 9], outline=(255, 255, 255), width=3)
im.save(saida)

"""Tira as tres texturas PBR da batina de IA (glb) sem recodificar: cor (sRGB),
normal (OpenGL, Y+) e MR (rugosidade no verde, metal no azul).
python r_texturas.py <glb> <dir> <prefixo>"""
import sys, json, struct, os
glb, saida, pref = sys.argv[1], sys.argv[2], sys.argv[3]
d = open(glb, "rb").read()
assert d[:4] == b"glTF"
n0 = struct.unpack_from("<I", d, 12)[0]
js = json.loads(d[20:20 + n0])
b0 = 20 + n0
n1 = struct.unpack_from("<I", d, b0)[0]
binc = d[b0 + 8:b0 + 8 + n1]
mat = js["materials"][0]
pbr = mat["pbrMetallicRoughness"]
qual = {pbr["baseColorTexture"]["index"]: "cor", mat["normalTexture"]["index"]: "normal",
        pbr["metallicRoughnessTexture"]["index"]: "mr"}
for ti, nome in qual.items():
    img = js["images"][js["textures"][ti]["source"]]
    bv = js["bufferViews"][img["bufferView"]]
    ext = ".png" if img.get("mimeType", "image/png") == "image/png" else ".jpg"
    caminho = os.path.join(saida, "%s_%s%s" % (pref, nome, ext))
    open(caminho, "wb").write(binc[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])
    print("[texturas]", caminho, bv["byteLength"])

"""Baixa do corpo, UV unica, materiais procedurais na ALTA, assar (Cycles) e exportar crucifixo.glb.

blender -b cruz_alto.blend --python c_assar.py -- <pasta_rascunho> <saida.glb> [px=2048] [amostras=64]

Grupos assados um a um no MESMO atlas (use_clear=False), cada um so com a
sua alta selecionada, para a madeira nao pegar o corpo e vice-versa:
  corpo   (bronze)  corpo, cabeca, cabelo, pano, coroa, espinhos
  madeira           alta_haste, alta_trave
  titulo  (bronze)  alta_titulo, alta_letras
  ferro             alta_cravos, alta_olhal, alta_argola
Passes: cor (albedo sRGB), orm (R=oclusao G=rugosidade B=metal) e normal (OpenGL, Y+).
Na exportacao: origem no centro da argola, giro de 180 graus em Z (corpo para -Z no Godot).
"""
import sys, os, math, json, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from c_comum import *

argv = sys.argv[sys.argv.index("--") + 1:]
PASTA = argv[0]
SAIDA_GLB = argv[1]
PX = int(argv[2]) if len(argv) > 2 else 2048
AMOSTRAS = int(argv[3]) if len(argv) > 3 else 64
ALVO_CORPO = 6500
cena = bpy.context.scene
META = json.loads(cena["cruz_meta"])
random.seed(5)
os.makedirs(PASTA, exist_ok=True)

ALTAS = {
    "corpo": ["corpo", "cabeca", "cabelo", "pano", "coroa", "espinhos"],
    "madeira": ["alta_haste", "alta_trave"],
    "titulo": ["alta_titulo", "alta_letras"],
    "ferro": ["alta_cravos", "alta_olhal", "alta_argola"],
}
BAIXAS = {"corpo": ["baixa_corpo"], "madeira": ["baixa_haste", "baixa_trave"],
          "titulo": ["baixa_titulo"], "ferro": ["baixa_cravos", "baixa_olhal", "baixa_argola"]}
EXTRUSAO = {"corpo": (0.0007, 0.0018), "madeira": (0.0008, 0.0018), "titulo": (0.0004, 0.0010),
            "ferro": (0.0004, 0.0010)}
OB = bpy.data.objects


# ------------------------------------------------------------ baixa do corpo
def copia(o):
    c = o.copy()
    c.data = o.data.copy()
    return ligar(c)


fonte = [copia(OB[n]) for n in ("corpo", "cabeca", "cabelo", "pano", "coroa")]
bc = juntar(fonte, "baixa_corpo")
remesh(bc, 0.00018)
n0 = tris(bc)
# maos, pes e cabeca custam mais para colapsar: dedos e espinhos nao viram agulha
co = co_de(bc)
w = np.clip((np.abs(co[:, 0]) - 0.030) / 0.004, 0, 1)
w = np.maximum(w, np.clip((-0.132 - co[:, 2]) / 0.006, 0, 1))
w = np.maximum(w, np.clip((0.011 - np.linalg.norm(co - np.array([-0.0035, -0.013, -0.050]), axis=1)) / 0.003, 0, 1))
ww = np.round(1.0 - 0.5 * w, 2)
vg = bc.vertex_groups.new(name="detalhe")
idx = np.arange(len(ww))
for val in np.unique(ww):
    vg.add(idx[ww == val].tolist(), float(val), "REPLACE")
dec = bc.modifiers.new("dec", "DECIMATE")
dec.decimate_type = "COLLAPSE"
dec.ratio = ALVO_CORPO / n0
dec.use_collapse_triangulate = True
dec.vertex_group = "detalhe"
dec.vertex_group_factor = 0.008
aplicar(bc)
suave(bc)
print("[assar] corpo baixa: %d -> %d tris" % (n0, tris(bc)))

# espinhos baixos: piramides de 3 lados nos 24 maiores
esp = OB["espinhos"]
co = co_de(esp)
pai = np.arange(len(co))


def raiz(i):
    while pai[i] != i:
        pai[i] = pai[pai[i]]
        i = pai[i]
    return i


for e in esp.data.edges:
    a, b = raiz(e.vertices[0]), raiz(e.vertices[1])
    if a != b:
        pai[a] = b
grupos = {}
for i in range(len(co)):
    grupos.setdefault(raiz(i), []).append(i)
cones = []
for idx in grupos.values():
    P = co[idx]
    c = P.mean(0)
    u, s_, vt = np.linalg.svd(P - c)
    ax = vt[0]
    t = (P - c) @ ax
    lado_a = P[t > t.max() * 0.6]
    lado_b = P[t < t.min() * 0.6]
    ra = np.linalg.norm(lado_a - lado_a.mean(0), axis=1).mean()
    rb = np.linalg.norm(lado_b - lado_b.mean(0), axis=1).mean()
    if ra < rb:
        ponta, base = P[t.argmax()], lado_b.mean(0)
    else:
        ponta, base = P[t.argmin()], lado_a.mean(0)
    cones.append((np.linalg.norm(ponta - base), Vector(base), Vector(ponta)))
cones.sort(key=lambda q: -q[0])
verts, faces = [], []
for L, base, ponta in cones[:24]:
    ax = (ponta - base).normalized()
    per = ax.orthogonal().normalized()
    per2 = ax.cross(per)
    r = 0.00022
    i0 = len(verts)
    for k in range(3):
        a = 2 * math.pi * k / 3
        verts.append(base + (per * math.cos(a) + per2 * math.sin(a)) * r)
    verts.append(ponta)
    faces += [(i0 + k, i0 + (k + 1) % 3, i0 + 3) for k in range(3)]
be = malha("baixa_espinhos", verts, faces)
bc = juntar([bc, be], "baixa_corpo")
suave(bc)

# ----------------------------------------------------- manchas (por vertice)
cravos = [Vector(p) for p in META["cravos"]]


def por_attr(ob, nome, val):
    me = ob.data
    if nome in me.attributes:
        me.attributes.remove(me.attributes[nome])
    at = me.attributes.new(nome, "FLOAT", "POINT")
    at.data.foreach_set("value", np.ascontiguousarray(val, dtype=np.float32))


def escorridos(co, nv, fontes, frente_so=True):
    """Filetes de sangue seco que descem (-Z) de cada fonte: (x, y, z, largura, comprimento, n)."""
    f = np.zeros(len(co))
    for (x0, y0, z0, larg, comp, n) in fontes:
        for k in range(n):
            xk = x0 + random.uniform(-1, 1) * larg
            wk = random.uniform(0.00035, 0.0008)
            Lk = comp * random.uniform(0.4, 1.0)
            fq = random.uniform(300, 700)
            ondula = 0.0003 * np.sin(co[:, 2] * fq + k * 1.7)
            dz = z0 - co[:, 2]
            afina = np.clip(1 - dz / Lk, 0, 1)
            m = (np.exp(-((co[:, 0] - xk - ondula) / (wk * (0.4 + 0.6 * afina))) ** 2)
                 * np.clip(dz / 0.0006 + 1, 0, 1) * (afina > 0) * np.clip(afina * 4, 0, 1))
            m *= np.exp(-((co[:, 1] - y0) / 0.012) ** 2)
            if frente_so:
                m *= np.clip(-nv[:, 1] * 2 + 0.3, 0, 1)
            gota = np.exp(-((co[:, 0] - xk) ** 2 + (co[:, 2] - (z0 - Lk)) ** 2) / (wk * 1.3) ** 2)
            f = np.maximum(f, np.maximum(m, gota * (afina.max() > 0)))
    return f


def manchas():
    # madeira: abaixo das maos e dos pes
    for n in ALTAS["madeira"]:
        o = OB[n]
        co, nv = co_de(o), normais_de(o)
        fontes = [(c.x, -0.0045, c.z - 0.0045, 0.0035, 0.012, 4) for c in cravos[:2]]
        fontes.append((cravos[2].x, -0.0045, cravos[2].z - 0.004, 0.003, 0.012, 5))
        por_attr(o, "mancha", escorridos(co, nv, fontes))
    # corpo: palmas, pes, chaga do lado e testa
    for n in ALTAS["corpo"]:
        o = OB[n]
        co, nv = co_de(o), normais_de(o)
        fontes = [(c.x, c.y, c.z + 0.0005, 0.0018, 0.007, 4) for c in cravos[:2]]
        fontes.append((cravos[2].x, cravos[2].y, cravos[2].z + 0.0008, 0.002, 0.010, 4))
        fontes.append((-0.0060, -0.0165, -0.0700, 0.0012, 0.014, 3))     # chaga do lado direito
        fontes.append((-0.0045, -0.0150, -0.0455, 0.0030, 0.0045, 5))    # testa, sob a coroa
        f = escorridos(co, nv, fontes, frente_so=False)
        # chaga: corte curto no costado direito
        chaga = np.exp(-((co[:, 0] + 0.0060) / 0.0014) ** 2 - ((co[:, 2] + 0.0697) / 0.0005) ** 2)
        f = np.maximum(f, chaga)
        por_attr(o, "mancha", f * 0.85)
    for g in ("titulo", "ferro"):
        for n in ALTAS[g]:
            por_attr(OB[n], "mancha", np.zeros(len(OB[n].data.vertices)))


manchas()


def relevos():
    """Relevo (convexo grande: testa, joelho, peito) e cavidade (miuda) por suavizacao da propria malha."""
    for g, nomes in ALTAS.items():
        for n in nomes:
            o = OB[n]
            co, nv = co_de(o), normais_de(o)
            res = {}
            for nome, it, norma in (("relevo", 400, 0.0008), ("cavidade", 12, 0.00014)):
                if nome == "relevo" and g not in ("corpo", "titulo"):
                    res[nome] = np.full(len(co), 0.5)
                    continue
                c = copia(o)
                m = c.modifiers.new("s", "SMOOTH")
                m.factor = 1.0
                m.iterations = it
                aplicar(c)
                cs = co_de(c)
                bpy.data.objects.remove(c, do_unlink=True)
                res[nome] = np.clip(0.5 + ((co - cs) * nv).sum(1) / norma * 0.5, 0, 1)
            por_attr(o, "relevo", res["relevo"])
            por_attr(o, "cavidade", res["cavidade"])
            print("[assar] relevo %-12s rel %.2f..%.2f cav %.2f..%.2f" % (
                n, np.percentile(res["relevo"], 5), np.percentile(res["relevo"], 95),
                np.percentile(res["cavidade"], 5), np.percentile(res["cavidade"], 95)))


relevos()


# --------------------------------------------------------------- nos (helpers)
class Arv:
    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.x = 0

    def no(self, tipo, **kw):
        n = self.nt.nodes.new(tipo)
        n.location = (self.x, 0)
        self.x += 180
        for k, v in kw.items():
            setattr(n, k, v)
        return n

    def lig(self, a, b):
        self.nt.links.new(a, b)

    def val(self, v):
        n = self.no("ShaderNodeValue")
        n.outputs[0].default_value = v
        return n.outputs[0]

    def mat(self, op, a, b=None, clamp=False):
        n = self.no("ShaderNodeMath", operation=op, use_clamp=clamp)
        for i, x in enumerate((a, b)):
            if x is None:
                continue
            if isinstance(x, (int, float)):
                n.inputs[i].default_value = x
            else:
                self.lig(x, n.inputs[i])
        return n.outputs[0]

    def mix(self, fac, a, b, tipo="RGBA", modo="MIX"):
        n = self.no("ShaderNodeMix", data_type=tipo, blend_type=modo, clamp_factor=True)
        suf = "Color" if tipo == "RGBA" else "Float"
        ent = {s.identifier: s for s in n.inputs}
        for sock, x in ((ent["Factor_Float"], fac), (ent["A_" + suf], a), (ent["B_" + suf], b)):
            if isinstance(x, (int, float)):
                sock.default_value = x
            elif isinstance(x, tuple):
                sock.default_value = x + (1,) if len(x) == 3 else x
            else:
                self.lig(x, sock)
        return {s.identifier: s for s in n.outputs}["Result_" + suf]

    def ruido(self, vetor, escala, detalhe=3, rug=0.55):
        n = self.no("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = escala
        n.inputs["Detail"].default_value = detalhe
        n.inputs["Roughness"].default_value = rug
        if vetor is not None:
            self.lig(vetor, n.inputs["Vector"])
        return n.outputs["Fac"]

    def rampa(self, fac, pontos):
        n = self.no("ShaderNodeValToRGB")
        el = n.color_ramp.elements
        while len(el) > len(pontos):
            el.remove(el[-1])
        while len(el) < len(pontos):
            el.new(0.5)
        for e, (p, c) in zip(el, pontos):
            e.position = p
            e.color = c + (1,) if len(c) == 3 else c
        self.lig(fac, n.inputs["Fac"])
        return n.outputs["Color"]

    def smooth(self, x, a, b):
        n = self.no("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP", clamp=True)
        self.lig(x, n.inputs["Value"])
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        return n.outputs["Result"]


def material_alto(nome, construir):
    m = bpy.data.materials.new(nome)
    try:
        m.use_nodes = True
    except Exception:
        pass
    A = Arv(m)
    saidas = construir(A)      # dict: cor, rug, metal, ao, normal
    bsdf = A.no("ShaderNodeBsdfPrincipled")
    A.lig(saidas["cor"], bsdf.inputs["Base Color"])
    A.lig(saidas["rug"], bsdf.inputs["Roughness"])
    A.lig(saidas["metal"], bsdf.inputs["Metallic"])
    A.lig(saidas["normal"], bsdf.inputs["Normal"])
    emi = A.no("ShaderNodeEmission")
    orm = A.no("ShaderNodeCombineColor")
    A.lig(saidas["ao"], orm.inputs["Red"])
    A.lig(saidas["rug"], orm.inputs["Green"])
    A.lig(saidas["metal"], orm.inputs["Blue"])
    out = A.no("ShaderNodeOutputMaterial")
    m["_bsdf"], m["_emi"], m["_out"] = bsdf.name, emi.name, out.name
    m["_cor"] = saidas["cor"].node.name + "|" + saidas["cor"].identifier
    m["_orm"] = orm.name
    return m


def modo_passe(m, passe):
    nt = m.node_tree
    bsdf, emi, out = nt.nodes[m["_bsdf"]], nt.nodes[m["_emi"]], nt.nodes[m["_out"]]
    for l in list(nt.links):
        if l.to_node in (out, emi):
            nt.links.remove(l)
    if passe == "normal":
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        return
    if passe == "cor":
        nn, ident = m["_cor"].split("|")
        src = [s for s in nt.nodes[nn].outputs if s.identifier == ident][0]
    else:
        src = nt.nodes[m["_orm"]].outputs["Color"]
    nt.links.new(src, emi.inputs["Color"])
    nt.links.new(emi.outputs["Emission"], out.inputs["Surface"])


def ao_no(A, dist, amostras=16):
    n = A.no("ShaderNodeAmbientOcclusion", samples=amostras, only_local=False, inside=False)
    n.inputs["Distance"].default_value = dist
    return n.outputs["AO"]


def attr(A, nome):
    return A.no("ShaderNodeAttribute", attribute_name=nome).outputs["Fac"]


def bronze(A):
    tc = A.no("ShaderNodeTexCoord").outputs["Object"]
    geo = A.no("ShaderNodeNewGeometry")
    mancha, rel, cav = attr(A, "mancha"), attr(A, "relevo"), attr(A, "cavidade")
    ao_g = ao_no(A, 0.0040)
    sep = A.no("ShaderNodeSeparateXYZ")
    A.lig(geo.outputs["Normal"], sep.inputs["Vector"])
    frente = A.mat("MULTIPLY", sep.outputs["Y"], -1.0)
    n1 = A.ruido(tc, 900.0, 4, 0.6)
    n2 = A.ruido(tc, 260.0, 3, 0.5)
    n3 = A.ruido(tc, 60.0, 2, 0.5)
    # polimento so nos pontos altos (relevo grande + crista miuda), manchado
    # exposto (ao grande), virado para quem toca (frente), crista miuda (cavidade) e um pouco de relevo
    s = A.mat("ADD", A.mat("MULTIPLY", A.mat("MAXIMUM", frente, 0.0), 0.40), A.mat("MULTIPLY", ao_g, 0.30))
    s = A.mat("ADD", s, A.mat("MULTIPLY", A.mat("SUBTRACT", cav, 0.5), 0.70))
    s = A.mat("ADD", s, A.mat("MULTIPLY", A.mat("SUBTRACT", rel, 0.5), 0.15))
    s = A.mat("ADD", s, A.mat("MULTIPLY", A.mat("SUBTRACT", n2, 0.5), 0.30))
    pol = A.smooth(s, 0.60, 0.88)
    recesso = A.smooth(cav, 0.47, 0.30)
    patina = A.mix(n3, (0.030, 0.022, 0.014), (0.046, 0.040, 0.028))
    patina = A.mix(A.mat("MULTIPLY", recesso, n1), patina, (0.030, 0.046, 0.036))
    polido = A.mix(n1, (0.26, 0.170, 0.085), (0.36, 0.245, 0.125))
    cor = A.mix(pol, patina, polido)
    cor = A.mix(A.mat("MULTIPLY", recesso, 0.85), cor, (0.010, 0.011, 0.009))
    sangue = A.mix(n1, (0.050, 0.009, 0.006), (0.028, 0.006, 0.004))
    cor = A.mix(mancha, cor, sangue)
    metal = A.mix(recesso, A.mix(pol, 0.30, 1.0, "FLOAT"), 0.20, "FLOAT")
    metal = A.mix(mancha, metal, 0.15, "FLOAT")
    rug = A.mix(recesso, A.mix(pol, 0.70, 0.34, "FLOAT"), 0.84, "FLOAT")
    rug = A.mix(mancha, rug, 0.55, "FLOAT")
    bump = A.no("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.00004
    A.lig(A.ruido(tc, 4000.0, 2, 0.5), bump.inputs["Height"])
    ao_orm = A.mix(ao_g, 0.35, 1.0, "FLOAT")
    return {"cor": cor, "rug": rug, "metal": metal, "ao": ao_orm, "normal": bump.outputs["Normal"]}


def madeira(eixo):
    def f(A):
        tc = A.no("ShaderNodeTexCoord").outputs["Object"]
        mancha, cav = attr(A, "mancha"), attr(A, "cavidade")
        mp = A.no("ShaderNodeMapping")
        A.lig(tc, mp.inputs["Vector"])
        mp.inputs["Location"].default_value = (0.045, 0.030, 0.0) if eixo == "Z" else (0.0, 0.030, 0.045)
        anel = A.no("ShaderNodeTexWave", wave_type="RINGS", rings_direction=eixo, wave_profile="SIN")
        anel.inputs["Scale"].default_value = 280.0
        anel.inputs["Distortion"].default_value = 3.5
        anel.inputs["Detail"].default_value = 3.0
        anel.inputs["Detail Scale"].default_value = 0.6
        A.lig(mp.outputs["Vector"], anel.inputs["Vector"])
        mp2 = A.no("ShaderNodeMapping")
        A.lig(tc, mp2.inputs["Vector"])
        mp2.inputs["Scale"].default_value = (1, 1, 0.03) if eixo == "Z" else (0.03, 1, 1)
        fio = A.ruido(mp2.outputs["Vector"], 1600.0, 4, 0.65)
        fio2 = A.ruido(mp2.outputs["Vector"], 420.0, 3, 0.6)
        ao_p = ao_no(A, 0.0012)
        ao_g = ao_no(A, 0.0050)
        suj = A.ruido(tc, 70.0, 3, 0.6)
        v = A.mat("ADD", A.mat("MULTIPLY", anel.outputs["Fac"], 0.40), A.mat("MULTIPLY", fio, 0.35))
        v = A.mat("ADD", v, A.mat("MULTIPLY", fio2, 0.25))
        base = A.rampa(v, [(0.25, (0.012, 0.0075, 0.0045)), (0.45, (0.030, 0.018, 0.010)),
                           (0.62, (0.058, 0.035, 0.018)), (0.80, (0.085, 0.052, 0.027))])
        # encardido nos cantos, fuligem em manchas grandes
        enc = A.mix(A.mat("MULTIPLY", ao_p, ao_g), 0.35, 1.0, "FLOAT")
        enc = A.mat("MULTIPLY", enc, A.mix(A.smooth(suj, 0.35, 0.7), 0.60, 1.0, "FLOAT"))
        enc = A.mat("MULTIPLY", enc, A.mix(A.smooth(cav, 0.45, 0.30), 1.0, 0.45, "FLOAT"))
        cc = A.no("ShaderNodeCombineColor")
        for k in ("Red", "Green", "Blue"):
            A.lig(enc, cc.inputs[k])
        cor = A.mix(1.0, base, cc.outputs["Color"], "RGBA", "MULTIPLY")
        # quina gasta pelo manuseio: um pouco mais clara e lisa
        gasto = A.smooth(cav, 0.62, 0.90)
        cor = A.mix(A.mat("MULTIPLY", gasto, 0.55), cor, (0.105, 0.068, 0.038))
        sangue = A.mix(fio, (0.030, 0.006, 0.004), (0.050, 0.010, 0.006))
        cor = A.mix(A.mat("MULTIPLY", mancha, 0.9), cor, sangue)
        rug = A.mix(gasto, A.mix(enc, 0.90, 0.72, "FLOAT"), 0.52, "FLOAT")
        rug = A.mix(mancha, rug, 0.45, "FLOAT")
        metal = A.val(0.0)
        bump = A.no("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.35
        bump.inputs["Distance"].default_value = 0.00006
        A.lig(A.mat("ADD", A.mat("MULTIPLY", fio, 0.6), A.mat("MULTIPLY", anel.outputs["Fac"], 0.4)),
              bump.inputs["Height"])
        return {"cor": cor, "rug": rug, "metal": metal, "ao": A.mix(ao_g, 0.40, 1.0, "FLOAT"),
                "normal": bump.outputs["Normal"]}
    return f


def ferro(A):
    tc = A.no("ShaderNodeTexCoord").outputs["Object"]
    cav = attr(A, "cavidade")
    ao_p = ao_no(A, 0.0006)
    n1 = A.ruido(tc, 1800.0, 4, 0.6)
    n2 = A.ruido(tc, 500.0, 3, 0.5)
    ferrugem = A.smooth(A.mat("ADD", A.mat("MULTIPLY", A.mat("SUBTRACT", 1.0, ao_p), 1.2), n2), 0.60, 0.90)
    gasto = A.smooth(cav, 0.58, 0.85)
    base = A.mix(n1, (0.085, 0.080, 0.074), (0.130, 0.122, 0.112))
    base = A.mix(gasto, base, (0.24, 0.225, 0.21))
    rust = A.mix(n1, (0.10, 0.040, 0.017), (0.19, 0.085, 0.035))
    cor = A.mix(ferrugem, base, rust)
    metal = A.mix(ferrugem, 0.70, 0.10, "FLOAT")
    rug = A.mix(ferrugem, A.mix(gasto, 0.55, 0.35, "FLOAT"), 0.90, "FLOAT")
    bump = A.no("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.4
    bump.inputs["Distance"].default_value = 0.00003
    A.lig(n1, bump.inputs["Height"])
    return {"cor": cor, "rug": rug, "metal": metal, "ao": A.mix(ao_p, 0.5, 1.0, "FLOAT"),
            "normal": bump.outputs["Normal"]}


m_bronze = material_alto("alta_bronze", bronze)
m_mad_v = material_alto("alta_madeira_v", madeira("Z"))
m_mad_h = material_alto("alta_madeira_h", madeira("X"))
m_ferro = material_alto("alta_ferro", ferro)
MATS = [m_bronze, m_mad_v, m_mad_h, m_ferro]
for n in ALTAS["corpo"] + ALTAS["titulo"]:
    OB[n].data.materials.clear()
    OB[n].data.materials.append(m_bronze)
OB["alta_haste"].data.materials.clear()
OB["alta_haste"].data.materials.append(m_mad_v)
OB["alta_trave"].data.materials.clear()
OB["alta_trave"].data.materials.append(m_mad_h)
for n in ALTAS["ferro"]:
    OB[n].data.materials.clear()
    OB[n].data.materials.append(m_ferro)

# ------------------------------------------------------------- UV unica
GRUPO_IDX = {"corpo": 0, "madeira": 1, "titulo": 2, "ferro": 3}
ESCALA_UV = {"corpo": 1.40, "madeira": 1.0, "titulo": 1.8, "ferro": 1.2}
baixas = []
for g, nomes in BAIXAS.items():
    for n in nomes:
        o = OB[n]
        for p in o.data.polygons:
            p.material_index = GRUPO_IDX[g]
        baixas.append(o)
uni = juntar(baixas, "crucifixo")
# triangula ja: a base tangente do bake (MikkTSpace) fica igual a exportada e o exportador
# nao desiste das tangentes por causa de n-gonos
bm = bmesh.new()
bm.from_mesh(uni.data)
bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
bm.to_mesh(uni.data)
bm.free()
for i in range(4):
    uni.data.materials.append(None)
uni.data.uv_layers.new(name="UV")
bpy.context.view_layer.objects.active = uni
for o in cena.objects:
    o.select_set(o == uni)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(62), island_margin=0.0, area_weight=0.0,
                         correct_aspect=True, scale_to_bounds=False)
bpy.ops.object.mode_set(mode="OBJECT")
me = uni.data
uv = np.empty(len(me.loops) * 2)
me.uv_layers["UV"].data.foreach_get("uv", uv)
uv = uv.reshape(-1, 2)
mi = np.empty(len(me.polygons), dtype=np.int32)
me.polygons.foreach_get("material_index", mi)
ls = np.empty(len(me.polygons), dtype=np.int32)
me.polygons.foreach_get("loop_start", ls)
lt = np.empty(len(me.polygons), dtype=np.int32)
me.polygons.foreach_get("loop_total", lt)
fator = np.ones(len(me.loops))
for g, k in GRUPO_IDX.items():
    for f in np.where(mi == k)[0]:
        fator[ls[f]:ls[f] + lt[f]] = ESCALA_UV[g]
uv *= fator[:, None]
me.uv_layers["UV"].data.foreach_set("uv", uv.ravel())
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.pack_islands(rotate=True, margin_method="FRACTION", margin=0.0035, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
print("[assar] uv ok; tris total", tris(uni))

# separa de volta por grupo (mesma UV) para assar grupo a grupo
def separar(uni, k, nome):
    bm = bmesh.new()
    bm.from_mesh(uni.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != k], context="FACES")
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    return ligar(bpy.data.objects.new(nome, me))


# --------------------------------------------------------------- assar
ligar_hip()
cena.cycles.samples = AMOSTRAS
cena.cycles.use_denoising = False
bk = cena.render.bake
bk.use_selected_to_active = True
bk.use_cage = False
bk.margin = 12
bk.margin_type = "EXTEND"
bk.use_clear = False
bk.normal_space = "TANGENT"
bk.normal_r, bk.normal_g, bk.normal_b = "POS_X", "POS_Y", "POS_Z"
IMGS = {}
for nome, cs, fundo in (("cor", "sRGB", (0.05, 0.035, 0.025, 1)), ("orm", "Non-Color", (1.0, 0.8, 0.0, 1)),
                        ("normal", "Non-Color", (0.5, 0.5, 1.0, 1))):
    im = bpy.data.images.new("crucifixo_" + nome, PX, PX, alpha=False, float_buffer=False)
    im.colorspace_settings.name = cs
    im.generated_color = fundo
    IMGS[nome] = im
m_asse = bpy.data.materials.new("assar")
try:
    m_asse.use_nodes = True
except Exception:
    pass
no_img = m_asse.node_tree.nodes.new("ShaderNodeTexImage")
m_asse.node_tree.nodes.active = no_img
partes = {}
for g, k in GRUPO_IDX.items():
    o = separar(uni, k, "assar_" + g)
    o.data.materials.clear()
    o.data.materials.append(m_asse)
    partes[g] = o
# as normais de cada parte vem de uni (bordas vivas preservadas pelo bmesh)
for o in list(partes.values()) + [uni]:
    o.visible_camera = o.visible_diffuse = o.visible_glossy = False
    o.visible_shadow = o.visible_transmission = o.visible_volume_scatter = False
uni.hide_render = True
for passe, tipo in (("cor", "EMIT"), ("orm", "EMIT"), ("normal", "NORMAL")):
    for m in MATS:
        modo_passe(m, passe)
    no_img.image = IMGS[passe]
    for g, o in partes.items():
        ext, dist = EXTRUSAO[g]
        for ob in cena.objects:
            ob.select_set(False)
        for n in ALTAS[g]:
            OB[n].select_set(True)
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.bake(type=tipo, use_selected_to_active=True, cage_extrusion=ext,
                            max_ray_distance=dist, margin=12, use_clear=False)
        print("[assar] %s %s ok" % (passe, g))
    im = IMGS[passe]
    im.filepath_raw = os.path.join(PASTA, "crucifixo_%s.png" % passe)
    im.file_format = "PNG"
    im.save()

# --------------------------------------------------- material final e glb
for o in partes.values():
    bpy.data.objects.remove(o, do_unlink=True)
uni.hide_render = False
uni.visible_camera = uni.visible_diffuse = uni.visible_glossy = True
uni.visible_shadow = uni.visible_transmission = uni.visible_volume_scatter = True
mf = bpy.data.materials.new("crucifixo")
try:
    mf.use_nodes = True
except Exception:
    pass
A = Arv(mf)
tc = A.no("ShaderNodeUVMap", uv_map="UV")
t_cor = A.no("ShaderNodeTexImage", image=IMGS["cor"])
t_orm = A.no("ShaderNodeTexImage", image=IMGS["orm"])
t_nor = A.no("ShaderNodeTexImage", image=IMGS["normal"])
for t in (t_cor, t_orm, t_nor):
    A.lig(tc.outputs["UV"], t.inputs["Vector"])
sep = A.no("ShaderNodeSeparateColor")
A.lig(t_orm.outputs["Color"], sep.inputs["Color"])
nm = A.no("ShaderNodeNormalMap", space="TANGENT", uv_map="UV")
A.lig(t_nor.outputs["Color"], nm.inputs["Color"])
bsdf = A.no("ShaderNodeBsdfPrincipled")
A.lig(t_cor.outputs["Color"], bsdf.inputs["Base Color"])
A.lig(sep.outputs["Green"], bsdf.inputs["Roughness"])
A.lig(sep.outputs["Blue"], bsdf.inputs["Metallic"])
A.lig(nm.outputs["Normal"], bsdf.inputs["Normal"])
out = A.no("ShaderNodeOutputMaterial")
A.lig(bsdf.outputs["BSDF"], out.inputs["Surface"])
gl = bpy.data.node_groups.get("glTF Material Output") or bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
if not gl.interface.items_tree:
    gl.interface.new_socket(name="Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
ng = A.no("ShaderNodeGroup")
ng.node_tree = gl
A.lig(sep.outputs["Red"], ng.inputs["Occlusion"])
mf.use_backface_culling = True
uni.data.materials.clear()
uni.data.materials.append(mf)
# origem no centro da argola; corpo para +Y do Blender (= -Z do Godot)
uni.data.transform(Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation((0, 0, -META["ORIGEM_Z"])))
uni.data.update()
for o in list(cena.objects):
    if o != uni:
        o.hide_render = True
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(PASTA, "crucifixo_assado.blend"))
for o in cena.objects:
    o.select_set(o == uni)
bpy.context.view_layer.objects.active = uni
os.makedirs(os.path.dirname(SAIDA_GLB), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=SAIDA_GLB, export_format="GLB", use_selection=True, export_yup=True,
                          export_apply=True, export_texcoords=True, export_normals=True, export_tangents=True,
                          export_materials="EXPORT", export_image_format="AUTO", export_animations=False,
                          export_skins=False, export_morph=False)
print("[assar] tris final", tris(uni), "glb", SAIDA_GLB)

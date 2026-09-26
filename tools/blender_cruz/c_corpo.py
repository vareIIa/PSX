"""Corpo de Cristo do crucifixo peitoral, malha ALTA (para assar), em metros reais.

blender -b --factory-startup --python c_corpo.py -- <saida.blend>

Modelado em "unidades humanas" (um homem de 1,75 m, pes em z~0, olhando -Y,
direita DELE em -X, costas no plano y=+0,10) e depois reduzido por ESC e
posto na cruz: as palmas no eixo da trave (z=-0,0448) e as costas na face da
madeira (y=-0,0045). Metodo: Skin sobre esqueleto de vertices com raio,
subdivisao, uniao por voxel, suavizacao e deslocamento analitico (costelas,
barriga, joelhos, rosto, barba, cabelo e dobras do pano).

Objetos salvos: corpo, cabeca, cabelo, pano, coroa, espinhos (todos no mesmo
referencial da cruz, antes do giro de exportacao).
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from c_comum import *

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAIDA_BLEND = argv[0] if argv else os.path.join(RASC, "corpo_alto.blend")
ESC = 0.060           # homem de 1,75 m (pernas encolhidas) -> ~0,104 m da cabeca aos pes
K_PERNA = 0.93        # encolhe as pernas abaixo do quadril (o pe em ponta alonga a figura)
Z_PALMA = 1.71        # altura humana do centro da palma
Z_TRAVE = -0.0448     # eixo da trave na cruz (m)
Y_COSTAS = 0.10       # plano das costas (humano)
Y_MADEIRA = -0.0045   # face da madeira (m)
VOX = 0.0040          # voxel da uniao do corpo (humano)
random.seed(7)
limpar()


def elipsoide(nome, c, r, rot=(0, 0, 0), n=24):
    ob = esfera_cubo(nome, n)
    ob.scale = r
    ob.rotation_euler = rot
    ob.location = c
    return ob


def espelhar_x(pts):
    return [(-p[0],) + tuple(p[1:]) for p in pts]


def janela(v, a, b, borda):
    return np.clip((v - a) / borda, 0, 1) * np.clip((b - v) / borda, 0, 1)


# ---------------------------------------------------------------- esqueleto
TRONCO = [
    (0.022, 0.030, 0.82, 0.075, 0.062),
    (0.024, 0.004, 0.90, 0.146, 0.096),
    (0.022, 0.008, 0.98, 0.138, 0.092),
    (0.015, 0.012, 1.06, 0.124, 0.086),
    (0.006, 0.004, 1.15, 0.140, 0.096),
    (-0.003, -0.002, 1.24, 0.150, 0.102),
    (-0.009, 0.004, 1.32, 0.155, 0.096),
    (-0.015, 0.014, 1.39, 0.140, 0.084),
    (-0.028, 0.010, 1.45, 0.068, 0.060),
    (-0.046, -0.004, 1.51, 0.054, 0.052),
]
# braco direito DELE (-X); cadeia no plano XZ: raio x -> profundidade (Y)
BRACO_D = [
    (-0.100, 0.036, 1.385, 0.070, 0.072),
    (-0.170, 0.037, 1.428, 0.064, 0.066),
    (-0.225, 0.043, 1.460, 0.056, 0.060),
    (-0.275, 0.048, 1.489, 0.053, 0.058),
    (-0.335, 0.054, 1.523, 0.045, 0.048),
    (-0.388, 0.060, 1.553, 0.037, 0.040),
    (-0.430, 0.062, 1.577, 0.041, 0.048),
    (-0.480, 0.066, 1.606, 0.037, 0.042),
    (-0.540, 0.070, 1.640, 0.029, 0.035),
    (-0.598, 0.075, 1.673, 0.021, 0.031),
]
MAO_D = [
    (-0.560, 0.072, 1.652, 0.022, 0.032),
    (-0.598, 0.075, 1.673, 0.019, 0.032),
    (-0.638, 0.078, 1.696, 0.018, 0.043),
    (-0.678, 0.080, 1.719, 0.017, 0.047),
    (-0.712, 0.080, 1.738, 0.015, 0.045),
]
PERNA_D = [
    (-0.050, 0.020, 0.96, 0.092, 0.086),
    (-0.068, 0.000, 0.87, 0.092, 0.088),
    (-0.064, -0.018, 0.76, 0.083, 0.078),
    (-0.050, -0.040, 0.65, 0.068, 0.066),
    (-0.032, -0.062, 0.56, 0.056, 0.055),
    (-0.022, -0.074, 0.51, 0.050, 0.050),
    (-0.016, -0.066, 0.45, 0.046, 0.050),
    (-0.013, -0.042, 0.37, 0.047, 0.058),
    (-0.010, -0.020, 0.28, 0.040, 0.047),
    (-0.007, -0.004, 0.19, 0.031, 0.034),
    (-0.005, 0.006, 0.12, 0.029, 0.032),
]
PERNA_E = [
    (0.100, 0.020, 0.96, 0.092, 0.086),
    (0.122, 0.000, 0.87, 0.092, 0.088),
    (0.124, -0.014, 0.76, 0.083, 0.078),
    (0.118, -0.032, 0.65, 0.068, 0.066),
    (0.108, -0.050, 0.56, 0.056, 0.055),
    (0.100, -0.060, 0.51, 0.050, 0.050),
    (0.093, -0.052, 0.45, 0.046, 0.050),
    (0.075, -0.022, 0.37, 0.047, 0.058),
    (0.057, 0.006, 0.28, 0.040, 0.047),
    (0.047, 0.030, 0.19, 0.031, 0.034),
    (0.041, 0.046, 0.12, 0.029, 0.032),
]
# pes em extensao (dedos para baixo), dorso para a frente; o direito por cima
PE_E = [
    (0.047, 0.030, 0.19, 0.030, 0.033),
    (0.042, 0.056, 0.09, 0.034, 0.036),
    (0.044, 0.066, 0.03, 0.040, 0.036),
    (0.048, 0.068, -0.03, 0.043, 0.033),
    (0.052, 0.066, -0.080, 0.049, 0.026),
    (0.054, 0.064, -0.095, 0.046, 0.022),
]
PE_D = [
    (-0.007, -0.004, 0.19, 0.030, 0.033),
    (-0.004, 0.012, 0.10, 0.034, 0.036),
    (0.002, 0.016, 0.04, 0.039, 0.037),
    (0.008, 0.018, -0.02, 0.043, 0.034),
    (0.014, 0.020, -0.065, 0.049, 0.027),
    (0.017, 0.019, -0.080, 0.046, 0.023),
]


def grossa(P, k=1.07):
    return [tuple(q[:3]) + (q[3] * k, q[4] * k) for q in P]


def dedos(lado):
    """Quatro dedos e o polegar, quase estendidos e curvando para -Y (para quem olha)."""
    s = 1 if lado == "e" else -1
    d = Vector((0.866 * s, 0, 0.5))          # ao longo do braco, para fora
    a = Vector((-0.5 * s, 0, 0.866))          # atravessa a palma, lado do polegar
    frente = Vector((0, -1, 0))
    base = Vector((0.712 * s, 0.080, 1.738))
    obs = []
    tabela = [(0.030, (0.040, 0.025, 0.019), 0.0118),   # indicador
              (0.010, (0.045, 0.028, 0.021), 0.0121),   # medio
              (-0.011, (0.042, 0.026, 0.020), 0.0115),  # anelar
              (-0.030, (0.033, 0.020, 0.017), 0.0104)]  # minimo
    curva = (0.10, 0.24, 0.18)   # MCP, PIP, DIP (rad), para a palma (-Y)
    for i, (off, comp, r) in enumerate(tabela):
        p = base + a * off - d * 0.010
        dirv = (d * 0.97 + a * off * 0.6).normalized()
        pts = [tuple(p) + (r * 0.95, r * 1.05)]
        ang = 0.0
        for k in range(3):
            ang += curva[k] * (1.0 + 0.15 * i)
            v = (dirv * math.cos(ang) + frente * math.sin(ang)).normalized()
            p = p + v * comp[k]
            rr = r * (0.95 - 0.08 * k)
            pts.append(tuple(p) + (rr * 0.95, rr))
        obs.append(cadeia_skin("dedo", pts, sub=2))
    # polegar: nasce perto do punho, do lado de cima, aberto
    p = Vector((0.630 * s, 0.076, 1.690)) + a * 0.026
    v0 = (d * 0.80 + a * 0.60).normalized()
    pts = [tuple(p) + (0.015, 0.017)]
    ang = 0.0
    for k, (L, c) in enumerate([(0.030, 0.15), (0.024, 0.35), (0.019, 0.30)]):
        ang += c
        v = (v0 * math.cos(ang) + frente * math.sin(ang)).normalized()
        p = p + v * L
        pts.append(tuple(p) + (0.0125 - 0.0015 * k, 0.0135 - 0.0015 * k))
    obs.append(cadeia_skin("polegar", pts, sub=2))
    return obs


partes = [cadeia_skin("tronco", TRONCO, sub=2),
          cadeia_skin("braco_d", BRACO_D), cadeia_skin("braco_e", espelhar_x(BRACO_D)),
          cadeia_skin("mao_d", MAO_D), cadeia_skin("mao_e", espelhar_x(MAO_D)),
          cadeia_skin("perna_d", grossa(PERNA_D)), cadeia_skin("perna_e", grossa(PERNA_E)),
          cadeia_skin("pe_d", PE_D), cadeia_skin("pe_e", PE_E)]
partes += dedos("d") + dedos("e")


def artelhos(P, medial):
    """Cinco dedos do pe saindo da bola do pe (pe em ponta: descem e dobram para a sola, +Y)."""
    bola = Vector(P[-2][:3])
    ax = (Vector(P[-1][:3]) - bola).normalized()
    obs = []
    # dedos lado a lado quase encostados (o vinco entre eles fica), o grande do lado de dentro
    raios = [0.0125, 0.0097, 0.0090, 0.0083, 0.0076]
    comps = [0.052, 0.046, 0.041, 0.036, 0.030]
    off = 0.047 - raios[0]
    for k, (L, r) in enumerate(zip(comps, raios)):
        if k:
            off -= raios[k - 1] + r + 0.0012
        b = bola + Vector((medial * off, -0.002, 0)) + ax * 0.004
        p1 = b + (ax + Vector((medial * off * 0.25, 0, 0))).normalized() * (L * 0.6)
        p2 = p1 + (ax * 0.9 + Vector((0, 0.3, 0))).normalized() * (L * 0.4)
        obs.append(cadeia_skin("artelho", [tuple(b) + (r * 1.1, r * 0.95), tuple(p1) + (r, r * 0.9),
                                           tuple(p2) + (r * 0.85, r * 0.8)], sub=2))
    # tornozelos (maleolos)
    tz = Vector(P[1][:3])
    for sx in (-1, 1):
        obs.append(elipsoide("maleolo", tuple(tz + Vector((sx * 0.024, -0.002, 0.005))), (0.012, 0.013, 0.018)))
    return obs


partes += artelhos(PE_D, 1) + artelhos(PE_E, -1)
# volumes anatomicos que a corrente de raios nao faz (eixo longo em X, girado em Y)
for s in (-1, 1):
    g = -s * math.radians(30)          # alinha com o braco erguido
    partes.append(elipsoide("deltoide", (s * 0.182 - 0.004, 0.036, 1.444), (0.072, 0.054, 0.052), (0, g, 0)))
    partes.append(elipsoide("trapezio", (s * 0.090 - 0.020, 0.045, 1.430), (0.080, 0.045, 0.032), (0, -s * 0.45, 0)))
partes.append(elipsoide("ventre", (0.022, -0.055, 0.975), (0.095, 0.042, 0.065)))
partes.append(elipsoide("rotula_d", (-0.021, -0.106, 0.515), (0.026, 0.012, 0.028)))
partes.append(elipsoide("rotula_e", (0.101, -0.092, 0.515), (0.026, 0.012, 0.028)))
for P, s in ((PERNA_D, -1), (PERNA_E, 1)):
    zz = [q[2] for q in P][::-1]
    cen = lambda h: [float(np.interp(h, zz, [q[k] for q in P][::-1])) for k in range(3)]
    c = cen(0.37)
    partes.append(elipsoide("gemeo_int", (c[0] - s * 0.018, c[1] + 0.016, 0.36), (0.030, 0.034, 0.075)))
    partes.append(elipsoide("gemeo_ext", (c[0] + s * 0.020, c[1] + 0.012, 0.39), (0.027, 0.032, 0.065)))
    c = cen(0.58)
    partes.append(elipsoide("vasto", (c[0] - s * 0.030, c[1] - 0.012, 0.585), (0.034, 0.030, 0.052)))
    c = cen(0.72)
    partes.append(elipsoide("reto", (c[0], c[1] - 0.030, 0.74), (0.050, 0.050, 0.11)))
partes.append(elipsoide("calcanhar_e", (0.032, 0.080, 0.070), (0.028, 0.025, 0.034)))
partes.append(elipsoide("calcanhar_d", (-0.004, 0.040, 0.080), (0.028, 0.025, 0.034)))
corpo = juntar(partes, "corpo")
remesh(corpo, VOX)
suavizar(corpo, 0.6, 8)
print("[corpo] uniao", len(corpo.data.vertices))

# ------------------------------------------------- deslocamento anatomico
co = co_de(corpo)
nv = normais_de(corpo)
x, y, z = co[:, 0], co[:, 1], co[:, 2]
tz = np.array([p[2] for p in TRONCO])
cx = np.interp(z, tz, [p[0] for p in TRONCO])
cy = np.interp(z, tz, [p[1] for p in TRONCO])
th = np.arctan2(x - cx, -(y - cy))          # 0 na frente, + para a esquerda dele
ath = np.abs(th)
no_tronco = np.clip((0.19 - np.abs(x - cx)) / 0.04, 0, 1) * janela(z, 0.95, 1.47, 0.02)
d = np.zeros(len(co))
# costelas: descem da lateral para a frente; so acima do arco costal e abaixo do peito
arco = 1.215 - 0.11 * np.clip(ath / 1.0, 0, 1)
fase = (z - 0.050 * (ath - 0.4)) / 0.034
costela = np.abs(np.cos(np.pi * fase)) ** 1.6
z_pec = 1.262 + 0.085 * np.clip((ath - 0.12) / 0.95, 0, 1) ** 1.3   # borda de baixo do peitoral, sobe para a axila
m_cost = (janela(ath, 0.55, 1.75, 0.35) * np.clip((z - arco) / 0.02, 0, 1)
          * np.clip((z_pec - 0.012 - z) / 0.03, 0, 1))
d += 0.0026 * costela * m_cost * no_tronco
# arco costal: borda e o oco abaixo dela (barriga funda de quem pende)
dist_arco = z - arco
d += 0.0020 * np.exp(-(dist_arco / 0.016) ** 2) * janela(ath, -0.1, 1.1, 0.2) * no_tronco
d -= 0.007 * np.exp(-((dist_arco + 0.045) / 0.038) ** 2) * janela(ath, -0.1, 1.2, 0.3) * no_tronco
# peitoral: placa chata, mais grossa na borda de baixo, que some no ombro
m_pec = (np.clip((z - z_pec) / 0.022, 0, 1) ** 1.5 * np.clip((1.415 - z) / 0.05, 0, 1)
         * np.clip((1.25 - ath) / 0.45, 0, 1) * np.clip((ath - 0.04) / 0.08, 0, 1))
d += (0.003 + 0.004 * np.clip((1.36 - z) / 0.08, 0, 1)) * m_pec * no_tronco
# esterno e linha alba
d -= 0.0035 * np.exp(-(th / 0.10) ** 2) * janela(z, 1.24, 1.40, 0.03) * no_tronco
d -= 0.0025 * np.exp(-(th / 0.07) ** 2) * janela(z, 1.00, 1.19, 0.03) * no_tronco
# umbigo
d -= 0.008 * np.exp(-((th + 0.02) / 0.06) ** 2 - ((z - 1.030) / 0.011) ** 2) * no_tronco
# clavicula: do alto do esterno ao ombro
zc = 1.425 + 0.025 * np.clip(ath - 0.15, 0, 1.2)
d += 0.0035 * np.exp(-((z - zc) / 0.010) ** 2) * janela(ath, 0.12, 1.2, 0.1) * no_tronco
d -= 0.0035 * np.exp(-((z - zc + 0.022) / 0.012) ** 2) * janela(ath, 0.2, 1.1, 0.1) * no_tronco
# canela (crista da tibia) e dedos dos pes
for px, py in ((-0.013, -0.050), (0.068, -0.034)):
    d += 0.0025 * janela(z, 0.16, 0.44, 0.05) * np.exp(-((x - px) / 0.03) ** 2) * (y < py)
co += nv * d[:, None]
baixo = co[:, 2] < 0.96
co[baixo, 2] = 0.96 - (0.96 - co[baixo, 2]) * K_PERNA
por_co(corpo, co)
suavizar(corpo, 0.3, 1)

# ---------------------------------------------------------------- cabeca
# referencial local: centro do cranio na origem, rosto para -Y
EC = 1.12       # cabeca um pouco maior que a anatomica: le melhor a 15 cm
ax, ay_f, ay_t, az_c, az_b = 0.073, 0.097, 0.102, 0.112, 0.116
cab = esfera_cubo("cabeca", 64)
u = co_de(cab)
ry_ = np.where(u[:, 1] < 0, ay_f, ay_t)
rz_ = np.where(u[:, 2] > 0, az_c, az_b)
r0 = 1.0 / np.sqrt((u[:, 0] / ax) ** 2 + (u[:, 1] / ry_) ** 2 + (u[:, 2] / rz_) ** 2)
p = u * r0[:, None]
X, Y, Z = p[:, 0], p[:, 1], p[:, 2]


def bolha(c, s, A):
    return A * np.exp(-(((X - c[0]) / s[0]) ** 2 + ((Y - c[1]) / s[1]) ** 2 + ((Z - c[2]) / s[2]) ** 2))


dd = np.zeros(len(p))
dd -= 0.010 * np.exp(-((Y + 0.1) / 0.03) ** 2) * np.clip(np.abs(X) / 0.05, 0, 1) * (Z < 0.04)
dd += bolha((0, -0.100, -0.010), (0.010, 0.030, 0.026), 0.023)      # dorso do nariz
dd += bolha((0, -0.097, -0.036), (0.013, 0.020, 0.011), 0.015)      # ponta do nariz
for s in (-1, 1):
    dd += bolha((s * 0.031, -0.092, 0.005), (0.018, 0.030, 0.012), -0.017)   # orbitas
    dd += bolha((s * 0.046, -0.084, -0.042), (0.014, 0.020, 0.016), -0.006)  # face encovada
    dd += bolha((s * 0.050, -0.078, -0.016), (0.018, 0.020, 0.014), 0.006)   # macas
    dd += bolha((s * 0.018, -0.099, -0.049), (0.019, 0.012, 0.007), 0.007)   # bigode
    dd += bolha((s * 0.052, -0.050, -0.070), (0.020, 0.040, 0.040), 0.012)   # barba lateral
dd += bolha((0, -0.098, 0.028), (0.050, 0.030, 0.010), 0.008)       # sobrancelha
dd += bolha((0, -0.100, 0.022), (0.010, 0.020, 0.014), -0.004)      # vinco entre as sobrancelhas
dd += bolha((0, -0.101, -0.060), (0.016, 0.020, 0.004), -0.006)     # boca entreaberta
dd += bolha((0, -0.075, -0.100), (0.048, 0.050, 0.038), 0.030)      # barba
dd += bolha((0.004, -0.068, -0.140), (0.022, 0.030, 0.028), 0.026)  # ponta da barba
barba = np.clip((-Z - 0.055) / 0.02, 0, 1) * (Y < -0.02)
dd += 0.0028 * np.sin(X / 0.0060 * 2 * np.pi + Z * 40) * barba
p = (p + u * dd[:, None]) * EC
por_co(cab, p)

# cabelo: casca sobre o cranio (sem o rosto), risca no meio
cabelo = esfera_cubo("cabelo", 56)
u = co_de(cabelo)
r0 = 1.0 / np.sqrt((u[:, 0] / (ax + 0.010)) ** 2 + (u[:, 1] / np.where(u[:, 1] < 0, ay_f + 0.006, ay_t + 0.012)) ** 2
                   + (u[:, 2] / np.where(u[:, 2] > 0, az_c + 0.010, az_b)) ** 2)
p = u * r0[:, None]
X, Y, Z = p[:, 0], p[:, 1], p[:, 2]
rosto = np.clip((-Y - 0.045) / 0.02, 0, 1) * np.clip((0.036 - Z) / 0.015, 0, 1)
risca = np.exp(-(X / 0.006) ** 2) * (Z > 0.05) * (Y < 0.06)
p = p * (1.0 - 0.25 * rosto - 0.04 * risca)[:, None] * EC
por_co(cabelo, p)

# coroa de espinhos: dois ramos torcidos num anel inclinado (frente mais baixa)
def anel(t, fase_):
    R = Vector((0.086 * math.cos(t), 0.106 * math.sin(t), 0))
    zt = 0.050 + 0.014 * math.sin(t)        # t=-90 graus e a testa (y<0)
    radial = Vector((math.cos(t), math.sin(t), 0))
    c = Vector((R.x, R.y + 0.004, zt))
    return (c + (radial * math.cos(7 * t + fase_) + Vector((0, 0, 1)) * math.sin(7 * t + fase_)) * 0.0085) * EC


ramos = []
N = 220
for fase_ in (0.0, math.pi):
    ramos.append(tubo("ramo", [anel(2 * math.pi * i / N, fase_) for i in range(N)], 0.0072 * EC, lados=10, laco=True))
ramos.append(tubo("ramo", [anel(2 * math.pi * i / N, 1.7) + Vector((0, 0, 0.003)) for i in range(N)],
                  0.0045 * EC, lados=8, laco=True))
coroa = juntar(ramos, "coroa")
esp = []
for i in range(44):
    t = 2 * math.pi * (i + random.uniform(-0.3, 0.3)) / 44
    c = anel(t, random.choice((0.0, math.pi)))
    radial = Vector((math.cos(t), math.sin(t), 0))
    v = (radial * random.uniform(0.4, 1.0) + Vector((0, 0, random.uniform(-0.7, 0.8)))
         + Vector((random.uniform(-.5, .5), random.uniform(-.5, .5), 0))).normalized()
    L = random.uniform(0.013, 0.024)
    base = c + v * 0.005
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.0034, radius2=0.0003, depth=L)
    mat = Matrix.Translation(base + v * L * 0.5) @ v.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
    me = bpy.data.meshes.new("esp")
    bm.to_mesh(me)
    bm.free()
    esp.append(ligar(bpy.data.objects.new("esp", me)))
espinhos = juntar(esp, "espinhos")

# a cabeca pende: para baixo, tombada para a direita dele (-X), rosto virado para a direita
R_cab = (Matrix.Rotation(math.radians(-12), 4, "Z") @ Matrix.Rotation(math.radians(-24), 4, "Y")
         @ Matrix.Rotation(math.radians(21), 4, "X"))
piv_local = Vector((0, 0.020, -0.085)) * EC      # articulacao atlas-occipital
piv_corpo = Vector((-0.048, -0.010, 1.530))
M_cab = Matrix.Translation(piv_corpo) @ R_cab @ Matrix.Translation(-piv_local)
for o in (cab, cabelo, coroa, espinhos):
    o.data.transform(M_cab)

# mechas: das temporas caem com a gravidade, a da direita sobre o ombro
mechas = []
for s, L in ((-1, 0.85), (1, 0.75)):
    a0 = M_cab @ (Vector((s * 0.070, 0.014, -0.005)) * EC)
    pts = [tuple(a0) + (0.038, 0.026)]
    # desce pelo lado do pescoco e deita sobre o ombro (nao pende do queixo)
    passos = [(0.016, -0.004, -0.045, 0.040), (0.018, -0.006, -0.048, 0.038),
              (0.014, -0.008, -0.046, 0.032), (0.008, -0.004, -0.040, 0.024), (0.004, 0.0, -0.028, 0.015)]
    for k, (dx, dy, dz, r) in enumerate(passos):
        a0 = a0 + Vector((s * dx, dy, dz)) * L
        pts.append(tuple(a0) + (r, r * 0.6))
    mechas.append(cadeia_skin("mecha", pts, sub=2))
cabelo = juntar([cabelo] + mechas, "cabelo")
remesh(cabelo, 0.0030)
suavizar(cabelo, 0.5, 3)
# fios: sulcos ao longo do escoamento (planos de Y local constante, a partir da risca)
cm = co_de(cabelo)
nm = normais_de(cabelo)
Mi = np.array(M_cab.inverted())
loc = cm @ Mi[:3, :3].T + Mi[:3, 3]
Yl, Zl = loc[:, 1], loc[:, 2]
# na casca o fio desce da risca (Y local constante); na mecha desce na vertical (X constante)
w_m = np.clip((-Zl - 0.07) / 0.05, 0, 1)
xm = cm[:, 0]
fio_c = (0.0008 * np.sin(2 * np.pi * Yl / 0.009 + 0.8 * np.sin(Zl * 35) + 1.5 * np.sin(np.abs(loc[:, 0]) * 60))
         + 0.0012 * np.sin(2 * np.pi * Yl / 0.030 + 1.3 * np.sin(Zl * 18) + 2.0 * np.sin(np.abs(loc[:, 0]) * 25))
         - 0.0030 * np.exp(-(loc[:, 0] / 0.005) ** 2) * (Zl > 0.02))
fio_m = (0.0032 * np.sin(2 * np.pi * xm / 0.030 + 4.0 * cm[:, 2])
         + 0.0010 * np.sin(2 * np.pi * xm / 0.010 + 9.0 * cm[:, 2]))
fio = fio_c * (1 - w_m) + fio_m * w_m
cm += nm * fio[:, None]
por_co(cabelo, cm)

# ------------------------------------------------------ perizonio (pano)
XC_P, YC_P = 0.024, 0.0          # eixo do quadril em volta do qual o pano enrola
NB_P = 144


def envelope(co_corpo):
    """Funcao-suporte de cada fatia do corpo (fecha o vao das coxas): R[theta, z]."""
    ts = -np.pi + 2 * np.pi * np.arange(NB_P) / NB_P
    U = np.stack([np.sin(ts), -np.cos(ts)])            # direcao de cada theta no plano XY
    zs = np.arange(0.66, 1.06, 0.005)
    R = np.zeros((NB_P, len(zs)))
    rel = co_corpo[:, :2] - np.array([XC_P, YC_P])
    for j, zz in enumerate(zs):
        m = np.abs(co_corpo[:, 2] - zz) < 0.012
        if m.sum() < 8:
            continue
        R[:, j] = (rel[m] @ U).max(0)
    for _ in range(6):
        R = 0.25 * np.roll(R, 1, 0) + 0.5 * R + 0.25 * np.roll(R, -1, 0)
    return R, zs


def raio_env(R, zs, t, zz):
    i = ((t + np.pi) / (2 * np.pi) * NB_P) % NB_P
    i0 = int(i) % NB_P
    f = i - int(i)
    a = np.interp(zz, zs, R[i0])
    b = np.interp(zz, zs, R[(i0 + 1) % NB_P])
    return a * (1 - f) + b * f


def pano(co_corpo):
    R, zs = envelope(co_corpo)
    NT, NZ = 220, 70
    th_k, z_k = -1.30, 0.975           # o no fica no quadril direito dele
    rng = np.random.default_rng(3)
    dobras = [(0.14 + 0.21 * i + rng.uniform(-0.04, 0.04), rng.uniform(0.7, 1.25)) for i in range(6)]
    verts, faces = [], []
    for j in range(NZ + 1):
        v = j / NZ
        for i in range(NT):
            t = -math.pi + 2 * math.pi * i / NT
            z_top = 1.005 - 0.012 * math.sin(t)
            z_bot = (0.800 - 0.040 * math.sin(t) - 0.020 * math.exp(-((t - 0.2) / 0.6) ** 2)
                     + 0.007 * math.sin(7 * t + 1.0))
            zz = z_top + (z_bot - z_top) * v
            r = raio_env(R, zs, t, zz) + 0.007 + 0.004 * v
            # dobras em leque saindo do no, cristas redondas que se juntam no no
            s_arc = (t - th_k) * 0.16
            tt = z_k - zz
            rr = math.hypot(s_arc, tt)
            dob = 0.0
            if s_arc > 0.0 and t < 1.9:
                phi = math.atan2(tt, s_arc) + 0.30 * rr * math.sin(rr * 12)
                sig = 0.07 + 0.25 * rr
                for ph, amp in dobras:
                    dob += amp * math.exp(-((phi - ph) / sig) ** 2)
                dob *= 0.018 * min(rr / 0.06, 1.0) * min(1.0, (1.9 - t) / 0.4)
            # dobras de caimento: descem da cintura do lado esquerdo dele e ondulam a bainha
            if -0.4 < t < 2.2:
                cai = max(0.0, math.sin(t * 11.0 + 0.8 + 0.9 * v + 0.6 * math.sin(t * 3))) ** 1.3
                dob += 0.015 * cai * v ** 1.1 * min(1.0, (t + 0.4) / 0.5) * min(1.0, (2.2 - t) / 0.5)
            dob += 0.003 * math.exp(-((v - 0.04) / 0.04) ** 2)       # bainha dobrada em cima
            r += dob
            X = XC_P + r * math.sin(t)
            Y = min(YC_P - r * math.cos(t), Y_COSTAS + 0.004)
            verts.append((X, Y, zz))
    for j in range(NZ):
        for i in range(NT):
            a = j * NT + i
            b = j * NT + (i + 1) % NT
            faces.append((a, b, b + NT, a + NT))
    ob = malha("pano_faixa", verts, faces)
    sol = ob.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.008
    sol.offset = -1.0
    sol.use_even_offset = True
    aplicar(ob)
    # o no, na superficie do pano
    rk = raio_env(R, zs, th_k, z_k) + 0.020
    Kp = Vector((XC_P + rk * math.sin(th_k), YC_P - rk * math.cos(th_k), z_k))
    nn = Vector((math.sin(th_k), -math.cos(th_k), 0)).normalized()
    eu = Vector((math.cos(th_k), math.sin(th_k), 0)).normalized()     # tangente, para a frente
    # aba que cai do no ao longo da coxa direita, abrindo e dobrando
    NU, NV = 26, 48
    verts, faces = [], []
    for j in range(NV + 1):
        v = j / NV
        for i in range(NU + 1):
            uu = i / NU - 0.5
            w = 0.040 + 0.070 * v
            Lc = 0.27 + 0.06 * uu + 0.012 * math.sin(uu * 11)
            dob = 0.012 * math.sin(uu * 2 * math.pi * 2.2 + v * 2.2) * (0.25 + 0.9 * v)
            P = Kp + eu * (uu * w + 0.02 * v) + Vector((0, 0, -Lc * v)) + nn * (dob + 0.020 * v * v - 0.004)
            verts.append(tuple(P))
    for j in range(NV):
        for i in range(NU):
            a = j * (NU + 1) + i
            faces.append((a, a + 1, a + NU + 2, a + NU + 1))
    aba = malha("aba", verts, faces)
    sol = aba.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.008
    sol.offset = 0.0
    aplicar(aba)
    # o no: no de trevo de pano grosso, virado para fora
    pts = []
    for k in range(120):
        t = 2 * math.pi * k / 120
        pts.append(Vector((math.sin(t) + 2 * math.sin(2 * t), math.cos(t) - 2 * math.cos(2 * t), -math.sin(3 * t))))
    base = Matrix((eu, Vector((0, 0, 1)), nn)).transposed().to_4x4()
    M_no = Matrix.Translation(Kp) @ base @ Matrix.Scale(0.0115, 4)
    no = tubo("no", [M_no @ q for q in pts], 0.0150, lados=10, laco=True)
    remesh(no, 0.003)
    suavizar(no, 0.5, 4)
    return juntar([ob, aba, no], "pano")


pano_ob = pano(co_de(corpo))

# ------------------------------------------------- escala e lugar na cruz
M = (Matrix.Translation((0, Y_MADEIRA - Y_COSTAS * ESC, Z_TRAVE - Z_PALMA * ESC))
     @ Matrix.Scale(ESC, 4))
for o in (corpo, cab, cabelo, coroa, espinhos, pano_ob):
    o.data.transform(M)
    o.data.update()
    suave(o)
    print("[corpo] %-9s verts=%7d" % (o.name, len(o.data.vertices)))
tudo = np.vstack([co_de(o) for o in (corpo, cab, cabelo, pano_ob)])
print("[corpo] caixa min", tudo.min(0).round(4), "max", tudo.max(0).round(4))
bpy.ops.wm.save_as_mainfile(filepath=SAIDA_BLEND)
print("[corpo] salvo", SAIDA_BLEND)

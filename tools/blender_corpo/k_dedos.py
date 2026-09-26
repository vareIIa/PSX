"""Dedos das maos do corpo de IA (corpo_jogo.blend): formas por vertice.

O corpo do gerador veio em pose T com a mao espalmada; no `Corpo` do jogo a mao
pende do punho, reta, a palma para dentro (para a coxa), os dedos esticados e
juntos. Nao ha osso de dedo (a mao vai rigida no antebraco), entao a mao muda
por forma (blend shape) por vertice:
- `relaxa`: a mao morta, pendurada (dedos dobrados em MCP/PIP/DIP, em cascata
  do indicador ao minimo; o polegar um pouco dobrado). Vai ASSADA na malha
  base, entao tem de ficar bonita parada.
- `garra_e`/`garra_d`: garra fechada (horror), relativa a `relaxa`.
- `aberta_e`/`aberta_d`: dedos esticados e abertos em leque, tensos, relativa a
  `relaxa`.
Cada lado sai em forma propria (o jogo pesa esquerda e direita em separado).

Como:
1. A mao: vertices do antebraco abaixo do punho, de um lado. Cada dedo sai da
   ponta (aproximada no cfg, ajustada ao vertice mais longe do punho pela pele
   perto dela). A distancia geodesica da ponta faz aneis perpendiculares ao
   dedo enquanto o dedo esta solto (abaixo da membrana a malha dos dedos e
   separada); o anel que incha (a frente passou pela membrana para o vizinho)
   marca a membrana. O eixo do dedo e a reta principal (PCA) do trecho solto; as
   juntas ficam em fracoes anatomicas do comprimento ponta->MCP, e a MCP fica
   alem da membrana, dentro da palma (a membrana e ~20% do dedo antes do no).
2. Pertenca: cada vertice pertence a um dedo por interpolacao harmonica na malha
   (o trecho solto de cada dedo vale 1 so para ele; na membrana e nos nos dos
   dedos mistura, sem costura). O polegar tem a sua, que se apaga no punho.
3. Pose: cinematica direta por dedo (DIP, PIP e MCP; no polegar IP, MCP e CMC),
   cada junta girando pelo seu eixo (flexao: dedo x normal da palma, dobra para a
   palma; leque: em torno da normal) no centro do anel, com o angulo
   fracionado por uma rampa suave que atravessa a junta (mais larga no dorso,
   onde a pele estica sobre o no). Depois um delta mush so nas juntas tira a
   aresta esticada e o vinco dobrado. Os angulos sao absolutos (a partir da mao
   reta) e estao no cfg.
4. Mede, em cada pose, a penetracao das duas falanges da ponta de cada dedo na
   palma e nos outros dedos (raio pela normal; imprime a pior).
5. Grava `dedos.json` (indices de `me.vertices` do `Corpo` e deslocamentos no
   quadro do jogo no Blender; `garra_*`/`aberta_*` relativos a base+relaxa), as
   fotos EEVEE de cada mao (reta, relaxa, garra, aberta; de frente, palma, dorso
   e tres quartos) e o mosaico (montado pelo `python` do sistema com Pillow).

Limite da malha: o decimador do gerador deixou triangulos compridos (ate 57 mm)
nas paredes entre os dedos, da membrana ate a DIP. Dobrar a PIP alem de ~50
graus faz desses triangulos cordas que saem do dedo (lascas entre os dedos e no
no). A garra do cfg fica nesse limite. Com a mao refinada (arestas acima de
1 cm dos dedos divididas antes de exportar) a garra forte fica limpa: rode com
`--malha-fina`, que troca as poses por `poses_malha_fina` do cfg.

blender -b corpo_jogo.blend --python k_dedos.py -- <saida_dir> [cfg_dedos.json] [--sem-fotos] [--malha-fina]
"""
import sys, os, json, math, heapq, subprocess
import bpy
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

a = sys.argv[sys.argv.index("--") + 1:]
fotos = "--sem-fotos" not in a
a = [x for x in a if not x.startswith("--")]
saida = os.path.abspath(a[0])
aqui = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index("--python") + 1]))
cfg = json.load(open(a[1] if len(a) > 1 else os.path.join(aqui, "cfg_dedos.json")))
if "--malha-fina" in sys.argv:
    for _p, _d in cfg["poses_malha_fina"].items():
        cfg["poses"][_p].update(_d)
os.makedirs(saida, exist_ok=True)
DEDOS = ["indicador", "medio", "anelar", "minimo"]
DIGITOS = ["polegar"] + DEDOS
LADOS = {"e": -1.0, "d": 1.0}

ob = bpy.data.objects["Corpo"]
me = ob.data
n = len(me.vertices)
co = np.empty(n * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(n, 3)
E = np.empty(len(me.edges) * 2, np.int64)
me.edges.foreach_get("vertices", E)
E = E.reshape(-1, 2)
FACES = [tuple(p.vertices) for p in me.polygons]
grupo = {g.name: g.index for g in ob.vertex_groups}
Wab = {"e": np.zeros(n), "d": np.zeros(n)}
for v in me.vertices:
    for g in v.groups:
        for lado in LADOS:
            if g.group == grupo["antebraco_" + lado]:
                Wab[lado][v.index] = g.weight


def unit(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-12)


def perp(v, eixo):
    """v sem a componente em `eixo`, normalizado."""
    return unit(v - (v @ eixo) * eixo)


def smooth01(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def rampa(P, c, d, h):
    """0 antes da junta, 1 depois, suave numa faixa de 2h ao longo de d."""
    return smooth01(((P - c) @ d + h) / (2 * h))   # h escalar ou por vertice


def gira(P, c, eixo, ang):
    """Rodrigues com angulo por vertice (ang: (N,))."""
    v = P - c
    cs = np.cos(ang)[:, None]
    sn = np.sin(ang)[:, None]
    return c + v * cs + np.cross(eixo, v) * sn + eixo[None, :] * (v @ eixo)[:, None] * (1 - cs)


class Mao:
    """Um lado: grafo da pele, dedos, juntas e pertenca."""

    def __init__(self, lado):
        self.lado = lado
        s = LADOS[lado]
        pz = cfg["punho_z"]
        m = (Wab[lado] > 0.3) & (co[:, 2] < pz + 0.015) & (np.sign(co[:, 0]) == s)
        self.g = np.where(m)[0]                 # indices globais
        loc = -np.ones(n, np.int64)
        loc[self.g] = np.arange(len(self.g))
        ee = E[m[E[:, 0]] & m[E[:, 1]]]
        a_, b_ = loc[ee[:, 0]], loc[ee[:, 1]]
        self.P = co[self.g]
        w = np.linalg.norm(self.P[a_] - self.P[b_], axis=1)
        N = len(self.g)
        self.viz = [[] for _ in range(N)]
        for i, j, wij in zip(a_, b_, w):
            self.viz[i].append((j, wij))
            self.viz[j].append((i, wij))
        self.ea, self.eb, self.ew = np.concatenate([a_, b_]), np.concatenate([b_, a_]), np.concatenate([w, w])
        self.loc = loc
        # triangulos inteiros da mao (para a BVH da penetracao)
        self.tris = [tuple(loc[list(f)]) for f in FACES if all(m[i] for i in f)]
        self.T = np.array([t for t in self.tris if len(t) == 3])
        self.viz0 = np.array([v[0][0] if v else i for i, v in enumerate(self.viz)])
        topo = np.where(self.P[:, 2] > pz + 0.010)[0]
        self.gw = self.dijkstra(list(topo))
        print("[dedos] mao %s: %d vertices, %d no punho" % (lado, N, len(topo)))

    def dijkstra(self, fontes):
        N = len(self.g)
        dist = np.full(N, np.inf)
        fila = [(0.0, int(f)) for f in fontes]
        heapq.heapify(fila)
        while fila:
            d, i = heapq.heappop(fila)
            if d >= dist[i]:
                continue
            dist[i] = d
            for j, w in self.viz[i]:
                if d + w < dist[j]:
                    heapq.heappush(fila, (d + w, j))
        return dist

    def dedo(self, nome, aprox):
        """Ponta, trecho solto, eixo e membrana de um dedo."""
        ca = cfg["anel"]
        perto = np.where(np.linalg.norm(self.P - np.array(aprox), axis=1) < ca["busca_ponta"])[0]
        perto = perto[np.isfinite(self.gw[perto])]
        ponta = int(perto[np.argmax(self.gw[perto])])
        gt = self.dijkstra([ponta])
        larg, incha = ca["largura"], ca["incha"]
        ref0, ref1 = ca["ref_polegar"] if nome == "polegar" else ca["ref"]
        ts = np.arange(0.0, 0.14, ca["passo"])
        cen, rmax = [], []
        for t in ts:
            r = np.where((gt >= t) & (gt < t + larg))[0]
            if len(r) < 3:
                cen.append(None)
                rmax.append(np.nan)
                continue
            c = self.P[r].mean(0)
            cen.append(c)
            rmax.append(np.linalg.norm(self.P[r] - c, axis=1).max())
        rmax = np.array(rmax)
        ref = np.nanmedian(rmax[(ts >= ref0) & (ts <= ref1)])
        if not ref < ca["raio_max"]:
            raise SystemExit("[dedos] %s %s: anel de %.1f mm perto da ponta; a ponta caiu fora do dedo "
                             "(corrija `pontas` no cfg)" % (self.lado, nome, ref * 1000))
        # O raio do anel e ruidoso (malha irregular, aresta de ate 2 cm): mediana
        # de 3 e o inchaco tem de durar `dura` amostras seguidas.
        rm = np.array([np.nanmedian(rmax[max(0, i - 1):i + 2]) for i in range(len(rmax))])
        t_web = None
        for i, t in enumerate(ts):
            if t > ref1 and np.all(rm[i:i + ca["dura"]] > incha * ref):
                t_web = t
                break
        if os.environ.get("DEDOS_DEPURA") or t_web is None:
            print("   perfil", nome, "ref %.1f" % (ref * 1000), " ".join("%d:%.0f" % (t * 1000, r * 1000) for t, r in zip(ts, rmax) if int(round(t * 1000)) % 3 == 0))
        if t_web is None:
            raise SystemExit("[dedos] %s %s: o anel nunca inchou (sem membrana); veja o perfil acima" % (self.lado, nome))
        solto = gt < t_web - ca["margem"]
        # eixo: PCA do trecho solto sem a tampa da ponta
        corpo_ = solto & (gt > ca["tampa"])
        Q = self.P[corpo_]
        mq = Q.mean(0)
        _, _, vt = np.linalg.svd(Q - mq, full_matrices=False)
        d = unit(vt[0])
        if (self.P[ponta] - mq) @ d < 0:
            d = -d                             # d aponta para a ponta
        ap = mq + d * ((self.P[ponta] - mq) @ d)   # ponta no eixo
        # posicao axial (da ponta para dentro) da membrana: o centro do anel
        cw = [c for t, c in zip(ts, cen) if c is not None and t <= t_web - ca["margem"]][-1]
        a_web = (ap - cw) @ d
        raio = float(np.median(np.linalg.norm(Q - (mq + np.outer((Q - mq) @ d, d)), axis=1)))
        print("[dedos]   %-9s ponta=(%.3f %.3f %.3f) membrana a %.1f mm do eixo (geo %.1f) raio %.1f mm, %d soltos" % (
            nome, *self.P[ponta], a_web * 1000, t_web * 1000, raio * 1000, int(solto.sum())))
        return {"ponta": ponta, "gt": gt, "solto": solto, "d": d, "ap": ap, "a_web": a_web, "raio": raio}

    def montar(self):
        s = LADOS[self.lado]
        self.D = {nm: self.dedo(nm, cfg["pontas"][self.lado][nm]) for nm in DIGITOS}
        # normal da palma: perpendicular ao plano dos quatro dedos, para dentro
        u = unit(sum(self.D[k]["d"] for k in DEDOS))
        lat = self.D["indicador"]["ap"] - self.D["minimo"]["ap"]
        nn = unit(np.cross(u, lat))
        if nn[0] * (-s) < 0:
            nn = -nn
        self.n = perp(nn, u)
        self.u = u
        self.r = unit(np.cross(self.n, u))      # para o polegar
        if self.r @ lat < 0:
            self.r = -self.r
        print("[dedos]   palma n=%s  dedos u=%s  polegar r=%s" % (
            np.round(self.n, 3), np.round(self.u, 3), np.round(self.r, 3)))
        # juntas (centro no eixo, direcao distal), da mais proxima a ponta
        self.J = {}
        for nm in DIGITOS:
            dd = self.D[nm]
            a_mcp = dd["a_web"] * (1 + cfg["mcp_alem"][nm])
            fr = cfg["juntas_frac"][nm]
            if nm == "polegar":
                d = dd["d"]
                mcp = dd["ap"] - d * a_mcp
                cmc = mcp - d * cfg["polegar_cmc_alem"]
                ip = dd["ap"] - d * (fr[0] * a_mcp)
                self.J[nm] = [("cmc", cmc), ("mcp", mcp), ("ip", ip)]
            else:
                d = dd["d"]
                self.J[nm] = [("mcp", dd["ap"] - d * a_mcp), ("pip", dd["ap"] - d * (fr[0] * a_mcp)),
                              ("dip", dd["ap"] - d * (fr[1] * a_mcp))]
            # desloca o centro para o dorso (fracao do raio), por tipo de junta
            dor = cfg.get("dorso", {})
            self.J[nm] = [(k, c - self.n * dor.get(k, 0.0) * dd["raio"]) for k, c in self.J[nm]]
            print("[dedos]   %-9s " % nm + "  ".join("%s(%.3f %.3f %.3f)" % (k, *c) for k, c in self.J[nm]))
        self.pertenca()

    def harmonica(self, fixo, val, voltas):
        """Interpolacao harmonica (Jacobi, peso 1/comprimento) com `fixo` preso."""
        x = val.copy()
        wgt = 1.0 / np.maximum(self.ew, 1e-5)
        soma_w = np.bincount(self.ea, weights=wgt, minlength=len(x))
        livre = ~fixo & (soma_w > 0)
        for _ in range(voltas):
            if x.ndim == 1:
                media = np.bincount(self.ea, weights=wgt * x[self.eb], minlength=len(x)) / np.maximum(soma_w, 1e-12)
            else:
                media = np.stack([np.bincount(self.ea, weights=wgt * x[self.eb, k], minlength=len(x))
                                  for k in range(x.shape[1])], 1) / np.maximum(soma_w, 1e-12)[:, None]
            x[livre] = media[livre]
        return x

    def pertenca(self):
        N = len(self.g)
        voltas = cfg["harmonica_voltas"]
        # quatro dedos: particao da unidade, o trecho solto de cada um vale 1
        fixo = np.zeros(N, bool)
        val = np.full((N, 4), 0.25)
        for k, nm in enumerate(DEDOS):
            sl = self.D[nm]["solto"]
            fixo |= sl
            val[sl] = 0.0
            val[sl, k] = 1.0
        pf = self.harmonica(fixo, val, voltas)
        pf /= pf.sum(1, keepdims=True)
        # polegar: 1 no trecho solto, 0 nos outros dedos e no punho
        topo = self.P[:, 2] > cfg["punho_z"] - cfg["polegar_punho_livre"]
        fx = self.D["polegar"]["solto"].copy()
        fixo_t = fx | fixo | topo
        vt = np.where(fx, 1.0, 0.0)
        mt = self.harmonica(fixo_t, vt, voltas)
        self.m = {"polegar": mt}
        for k, nm in enumerate(DEDOS):
            self.m[nm] = (1 - mt) * pf[:, k]

    def dobra_polegar(self):
        """Direcoes do polegar: rumo a PIP do indicador (aduz), para a palma
        (opoe) e a polpa, o lado para onde a MCP e a IP dobram: entre as duas,
        `polegar_polpa_ang` graus a partir do indicador. (O eixo menor da secao
        do polegar, que seria a polpa de verdade, sai torto nesta malha: a
        flexao por ele levantava o polegar para fora da palma.)"""
        d = self.D["polegar"]["d"]
        ip = self.J["polegar"][2][1]
        g_ind = perp(self.J["indicador"][1][1] - ip, d)
        g_pal = perp(self.n, d)
        a_ = math.radians(cfg["polegar_polpa_ang"])
        return d, g_ind, g_pal, perp(math.cos(a_) * g_ind + math.sin(a_) * g_pal, d)

    def eixos(self, nm, pose):
        """[(centro, direcao distal, meia rampa, vetor de giro, polpa)] da junta
        mais proxima a ponta; `polpa` e o lado para onde a junta dobra (o
        oposto e o dorso, onde a rampa alarga)."""
        dd = self.D[nm]
        d = dd["d"]
        rp = cfg["rampa"]
        ang = cfg["poses"][pose][nm]
        out = []
        if nm == "polegar":
            d, g_ind, g_pal, polpa = self.dobra_polegar()
            k_flex = unit(np.cross(d, polpa))
            k_aduz = unit(np.cross(d, g_ind))
            k_opoe = unit(np.cross(d, g_pal))
            (_, cmc), (_, mcp), (_, ip) = self.J[nm]
            om_cmc = math.radians(ang["aduz"]) * k_aduz + math.radians(ang["opoe"]) * k_opoe
            out.append((cmc, d, rp["cmc"], om_cmc, polpa))
            out.append((mcp, d, rp["mcp_polegar"], math.radians(ang["mcp"]) * k_flex, polpa))
            out.append((ip, d, rp["ip"], math.radians(ang["ip"]) * k_flex, polpa))
        else:
            k_flex = unit(np.cross(d, self.n))
            k_abre = unit(np.cross(d, perp(self.r, d)))
            mcp_a, pip_a, dip_a, abre_a = ang
            (_, mcp), (_, pip), (_, dip) = self.J[nm]
            g = perp(self.n, d)
            out.append((mcp, d, rp["mcp"], math.radians(mcp_a) * k_flex + math.radians(abre_a) * k_abre, g))
            out.append((pip, d, rp["pip"], math.radians(pip_a) * k_flex, g))
            out.append((dip, d, rp["dip"], math.radians(dip_a) * k_flex, g))
        return out

    def fk(self, nm, pose, P0):
        js = self.eixos(nm, pose)
        # No dorso a rampa alarga com a altura sobre o centro: a pele por cima do
        # no estica num arco largo; na polpa fica curta (a dobra vira vinco).
        kd = cfg["rampa_dorso"]
        ws = [rampa(P0, c, d, h + kd * np.maximum(0.0, -(P0 - c) @ g)) for c, d, h, _, g in js]
        P = P0.copy()
        for (c, d, h, om, g), w in reversed(list(zip(js, ws))):
            ang = float(np.linalg.norm(om))
            if ang > 1e-9:
                P = gira(P, c, om / ang, w * ang)
        return P, ws

    def pose(self, nome):
        """Posicoes da mao na pose (absoluta, a partir da mao reta)."""
        X = self.P.copy()
        self.pesos = {}
        for nm in DIGITOS:
            m = self.m[nm]
            sel = m > 1e-4
            Pn, ws = self.fk(nm, nome, self.P[sel])
            X[sel] += m[sel, None] * (Pn - self.P[sel])
            wfull = [np.zeros(len(self.P)) for _ in ws]
            for k, w in enumerate(ws):
                wfull[k][sel] = w
            self.pesos[nm] = wfull
        return self.mush(X)

    def suaviza(self, S, voltas, lam):
        cnt = np.maximum(np.bincount(self.ea, minlength=len(S)), 1)[:, None]
        for _ in range(voltas):
            media = np.stack([np.bincount(self.ea, weights=S[self.eb, k], minlength=len(S))
                              for k in range(S.shape[1])], 1) / cnt
            S = S + lam * (media - S)
        return S

    def quadros(self, S):
        """Quadro local por vertice (tangente, bitangente, normal) na malha S."""
        T = self.T
        fn = np.cross(S[T[:, 1]] - S[T[:, 0]], S[T[:, 2]] - S[T[:, 0]])
        N = np.zeros_like(S)
        for k in range(3):
            np.add.at(N, T[:, k], fn)
        N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
        t = S[self.viz0] - S
        t -= (t * N).sum(1, keepdims=True) * N
        t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-12)
        return np.stack([t, np.cross(N, t), N], 1)

    def mush(self, X):
        """Delta mush (o Corrective Smooth do Blender) so onde as juntas dobram:
        suaviza a pose e devolve o relevo do repouso no quadro local. Tira a
        aresta esticada 3x no dorso do no e o vinco dobrado na polpa."""
        cm = cfg["mush"]
        if cm["voltas"] <= 0:
            return X
        if not hasattr(self, "delta"):
            Sr = self.suaviza(self.P, cm["voltas"], cm["lam"])
            self.delta = np.einsum("nij,nj->ni", self.quadros(Sr), self.P - Sr)
        Sp = self.suaviza(X, cm["voltas"], cm["lam"])
        Xm = Sp + np.einsum("nji,nj->ni", self.quadros(Sp), self.delta)
        # zona: onde alguma junta esta no meio da rampa, alargada na malha
        z = np.zeros(len(X))
        for nm in DIGITOS:
            for w in self.pesos[nm]:
                z = np.maximum(z, self.m[nm] * 4 * w * (1 - w))
        # e a membrana do polegar (entre ele e o indicador), que dobra quando ele fecha
        mt = self.m["polegar"]
        z = np.maximum(z, 4 * mt * (1 - mt) * self.pesos["polegar"][0])
        z = np.clip(self.suaviza(z[:, None], cm["alarga"], 0.5)[:, 0] * cm["ganho"], 0, 1)
        return X + z[:, None] * (Xm - X)

    def penetracao(self, X):
        """Penetracao das duas falanges da ponta de cada dedo na palma e nos
        outros dedos: do vertice, um raio para fora (a normal); se a primeira
        face que ele cruza for de outra peca e estiver de costas para o raio, o
        vertice esta dentro dela (a mao e fechada, fora o punho). Devolve
        {dedo>alvo: (vertices, profundidade maxima em mm)}."""
        N = len(self.g)
        rotulo = np.full(N, "palma", dtype=object)
        forte = np.zeros(N)
        for nm in DIGITOS:
            mv = self.m[nm] * self.pesos[nm][0]
            mais = mv > np.maximum(forte, 0.5)
            rotulo[mais] = nm
            forte = np.maximum(forte, mv)
        T = self.T
        rot_f = [max(set(rotulo[list(t)]), key=list(rotulo[list(t)]).count) for t in T]
        bvh = BVHTree.FromPolygons([Vector(p) for p in X], [tuple(int(i) for i in t) for t in T])
        nor = self.quadros(X)[:, 2]
        res = {}
        for nm in DIGITOS:
            ponta = (rotulo == nm) & (self.pesos[nm][1] > 0.5) & (self.m[nm] > 0.9)
            for i in np.where(ponta)[0]:
                dv = Vector(nor[i])
                loc, fn, fi, dist = bvh.ray_cast(Vector(X[i]) + dv * 1e-4, dv, 0.02)
                if loc is None or rot_f[fi] == nm or fn.dot(dv) <= 0:
                    continue
                k = "%s>%s" % (nm, rot_f[fi])
                c, p = res.get(k, (0, 0.0))
                res[k] = (c + 1, max(p, round(dist * 1000, 1)))
        return res


maos = {lado: Mao(lado) for lado in LADOS}
for mao in maos.values():
    mao.montar()

# --- poses ---
X = {}
for lado, mao in maos.items():
    for pose in ("reta", "relaxa", "garra", "aberta"):
        X[(lado, pose)] = mao.pose(pose)
        if pose != "reta":
            print("[dedos] penetracao %s %-7s %s" % (lado, pose, mao.penetracao(X[(lado, pose)])))


def forma(pares, limite=1e-6):
    idx, d = [], []
    for gidx, delta in pares:
        mag = np.linalg.norm(delta, axis=1)
        for i, dv, mg in zip(gidx, delta, mag):
            if mg > limite:
                idx.append(int(i))
                d.append([round(float(c), 6) for c in dv])
    return {"idx": idx, "d": d}


formas = {"relaxa": forma([(maos[l].g, X[(l, "relaxa")] - maos[l].P) for l in LADOS])}
for pose in ("garra", "aberta"):
    for l in LADOS:
        formas["%s_%s" % (pose, l)] = forma([(maos[l].g, X[(l, pose)] - X[(l, "relaxa")])])
for k, f in formas.items():
    dm = max((np.linalg.norm(v) for v in f["d"]), default=0.0)
    print("[dedos] forma %-9s %5d vertices, maior %.1f mm" % (k, len(f["idx"]), dm * 1000))
json.dump({"formas": formas}, open(os.path.join(saida, "dedos.json"), "w"))
jj = {l: {nm: {k: [round(float(x), 4) for x in c] for k, c in maos[l].J[nm]} for nm in DIGITOS} for l in LADOS}
json.dump(jj, open(os.path.join(saida, "juntas.json"), "w"), indent=1)
print("[dedos] gravado", os.path.join(saida, "dedos.json"))

if not fotos:
    sys.exit(0)

# --- fotos: chaves de forma com as quatro poses (as duas maos juntas) ---
ob.shape_key_add(name="Basis", from_mix=False)
for pose in ("relaxa", "garra", "aberta"):
    k = ob.shape_key_add(name=pose, from_mix=False)
    arr = co.copy()
    for l in LADOS:
        arr[maos[l].g] = X[(l, pose)]
    k.data.foreach_set("co", arr.reshape(-1))
cena = bpy.context.scene
cena.render.engine = "BLENDER_EEVEE"
cena.render.resolution_x = cena.render.resolution_y = 640
w = bpy.data.worlds.new("w")
cena.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.33, 0.34, 0.37, 1)
for ang, el, en in ((40, 50, 3.0), (-130, 25, 1.4), (180, -35, 0.8)):
    luz = bpy.data.lights.new("l", "SUN")
    luz.energy = en
    lo = bpy.data.objects.new("l", luz)
    cena.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(el), 0, math.radians(ang))
cam_d = bpy.data.cameras.new("c")
cam_d.lens = 85
cam_d.clip_start = 0.01
cam = bpy.data.objects.new("c", cam_d)
cena.collection.objects.link(cam)
cena.camera = cam
mascara = ob.vertex_groups.new(name="mascara_foto")
mk = ob.modifiers.new("MascaraFoto", "MASK")
mk.vertex_group = "mascara_foto"
VISTAS = ["frente", "palma", "dorso", "tres_quartos"]
ESTADOS = ["reta", "relaxa", "garra", "aberta"]
lista = []
for l, mao in maos.items():
    s = LADOS[l]
    braco = [int(i) for i in np.where(Wab[l] > 0.05)[0]]   # antebraco e mao, sem a coxa
    mascara.remove(list(range(n)))
    mascara.add(braco, 1.0, "REPLACE")
    dirs = {"frente": np.array([0.0, 1.0, 0.05]), "palma": mao.n + np.array([0, 0.12, 0.05]),
            "dorso": -mao.n + np.array([0, 0.12, 0.05]),
            "tres_quartos": 0.75 * np.array([0.0, 1.0, 0.0]) + 0.55 * mao.n - 0.45 * np.array([0, 0, 1.0])}
    for est in ESTADOS:
        for kb in me.shape_keys.key_blocks[1:]:
            kb.value = 1.0 if kb.name == est else 0.0
        # a camera mira a mao na pose (a garra sobe uns 3 cm)
        Xe = X[(l, est)]
        C = Xe[mao.P[:, 2] < cfg["punho_z"] - 0.03].mean(0)
        for vista in VISTAS:
            dv = unit(dirs[vista])
            pos = Vector(C + dv * 0.55)
            q = (Vector(C) - pos).to_track_quat("-Z", "Y")
            cam.matrix_world = Matrix.Translation(pos) @ q.to_matrix().to_4x4()
            arq = os.path.join(saida, "foto_%s_%s_%s.png" % (l, est, vista))
            cena.render.filepath = arq
            bpy.ops.render.render(write_still=True)
            lista.append(arq)
print("[dedos] %d fotos" % len(lista))

MOSAICO = r'''
import sys, os
from PIL import Image, ImageDraw
pasta = sys.argv[1]
vistas = ["frente", "palma", "dorso", "tres_quartos"]
estados = ["reta", "relaxa", "garra", "aberta"]
T = 400
im = Image.new("RGB", (T * 8, T * 4 + 24), (20, 20, 22))
d = ImageDraw.Draw(im)
for c, (l, v) in enumerate([(l, v) for l in "ed" for v in vistas]):
    d.text((c * T + 6, 6), "mao_%s %s" % (l, v), fill=(255, 255, 255))
    for r, e in enumerate(estados):
        f = os.path.join(pasta, "foto_%s_%s_%s.png" % (l, e, v))
        if os.path.exists(f):
            im.paste(Image.open(f).convert("RGB").resize((T, T)), (c * T, 24 + r * T))
        d.text((c * T + 6, 24 + r * T + 6), e, fill=(255, 255, 0))
im.save(os.path.join(pasta, "mosaico_dedos.png"))
print("[dedos] mosaico", os.path.join(pasta, "mosaico_dedos.png"))
'''
try:
    subprocess.run(["python", "-c", MOSAICO, saida], check=True)
except Exception as e:  # sem python com Pillow no PATH
    print("[dedos] mosaico falhou (%s): monte as fotos foto_*.png a mao" % e)

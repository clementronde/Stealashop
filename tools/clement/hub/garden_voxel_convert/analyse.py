# Décompose chaque maillage d'un GLB en composantes connexes et dit si chacune est une boîte (orientée) ou un prisme.
import json, struct, sys, pathlib, math
from collections import defaultdict

def read_glb(path):
    data = pathlib.Path(path).read_bytes()
    off = 12; js = binc = None
    while off < len(data):
        clen, ctype = struct.unpack_from("<I4s", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == b"JSON": js = json.loads(chunk)
        elif ctype == b"BIN\x00": binc = chunk
        off += 8 + clen
    return js, binc

CT = {5126: ("f", 4), 5125: ("I", 4), 5123: ("H", 2), 5121: ("B", 1)}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
def acc_read(js, binc, ai):
    a = js["accessors"][ai]; bv = js["bufferViews"][a["bufferView"]]
    fmt, sz = CT[a["componentType"]]; n = NC[a["type"]]
    stride = bv.get("byteStride", sz * n)
    base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [struct.unpack_from("<" + fmt * n, binc, base + i * stride) for i in range(a["count"])]

def qmat(q):
    x, y, z, w = q
    return [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]
def mat4(n):
    if "matrix" in n:
        m = n["matrix"]; return [[m[0], m[4], m[8], m[12]], [m[1], m[5], m[9], m[13]], [m[2], m[6], m[10], m[14]], [0, 0, 0, 1]]
    t = n.get("translation", [0, 0, 0]); r = qmat(n.get("rotation", [0, 0, 0, 1])); s = n.get("scale", [1, 1, 1])
    return [[r[i][0]*s[0], r[i][1]*s[1], r[i][2]*s[2], t[i]] for i in range(3)] + [[0, 0, 0, 1]]
def mmul(a, b): return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def apply(m, p): return tuple(m[i][0]*p[0] + m[i][1]*p[1] + m[i][2]*p[2] + m[i][3] for i in range(3))

def sub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def norm(a):
    l = math.sqrt(dot(a, a)); return (a[0]/l, a[1]/l, a[2]/l) if l > 1e-12 else (0, 0, 0)
def key(p): return (round(p[0], 4), round(p[1], 4), round(p[2], 4))

def lin2srgb(c): return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055

def components(tris):
    parent = {}
    def f(x):
        while parent.setdefault(x, x) != x:
            parent[x] = parent[parent[x]]; x = parent[x]
        return x
    for t in tris:
        a, b, c = (key(p) for p in t)
        parent[f(a)] = f(b); parent[f(b)] = f(c)
    g = defaultdict(list)
    for t in tris: g[f(key(t[0]))].append(t)
    return list(g.values())

def classify(comp):
    pts = {key(p): p for t in comp for p in t}
    ns = []
    for t in comp:
        n = norm(cross(sub(t[1], t[0]), sub(t[2], t[0])))
        if n != (0, 0, 0) and not any(abs(dot(n, m) - 1) < 1e-3 for m in ns): ns.append(n)
    if len(pts) == 8 and len(ns) == 6:
        # 3 paires opposées, orthogonales ?
        axes = []
        for n in ns:
            if not any(abs(abs(dot(n, a)) - 1) < 1e-3 for a in axes): axes.append(n)
        if len(axes) == 3 and all(abs(dot(axes[i], axes[j])) < 1e-3 for i in range(3) for j in range(i+1, 3)):
            return "box", axes, list(pts.values())
    if len(pts) == 6 and len(ns) == 5:
        return "prism", ns, list(pts.values())
    return "other(%d pts, %d normales, %d tris)" % (len(pts), len(ns), len(comp)), ns, list(pts.values())

def analyse(path, verbose=False):
    js, binc = read_glb(path)
    nodes, meshes, mats = js["nodes"], js["meshes"], js.get("materials", [])
    stats = defaultdict(int); others = []
    def walk(ni, m, chain):
        n = nodes[ni]; mm = mmul(m, mat4(n)); ch = chain + [n.get("name", "?")]
        if "mesh" in n:
            for prim in meshes[n["mesh"]]["primitives"]:
                pos = [apply(mm, p) for p in acc_read(js, binc, prim["attributes"]["POSITION"])]
                idx = [i[0] for i in acc_read(js, binc, prim["indices"])] if "indices" in prim else list(range(len(pos)))
                tris = [(pos[idx[i]], pos[idx[i+1]], pos[idx[i+2]]) for i in range(0, len(idx), 3)]
                for c in components(tris):
                    kind, _, _ = classify(c)
                    stats[kind.split("(")[0]] += 1
                    if kind.startswith("other"): others.append("/".join(ch) + " " + kind)
        for c in n.get("children", []): walk(c, mm, ch)
    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    for r in js["scenes"][js.get("scene", 0)]["nodes"]: walk(r, ident, [])
    return dict(stats), others

if __name__ == "__main__":
    for p in sys.argv[1:]:
        s, o = analyse(p)
        print(pathlib.Path(p).name, s, ("; autres : " + " | ".join(o[:4])) if o else "")

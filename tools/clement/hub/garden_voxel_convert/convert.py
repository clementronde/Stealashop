# GLB de Claude Design -> données Luau de pièces (boîtes) pour reconstruire les modèles en Parts à tenons.
# Usage (depuis ce dossier, les GLB passés en arguments, « @0.5 » = rocher à passer en voxels de 0,5 stud) :
#   python -I convert.py brut.luau <pack1>/ENV_Nature_Bush_Berry.glb ... <rochers>/ENV_Nature_Rock_Boulder.glb@0.5
#   python -I compact.py brut.luau ../garden_voxel_data.luau
# Liste et réglages du 2026-11-24 : pack 1 sans fontaine ni petit rocher ; pack 2 : Planter_Marble, Statue_Trophy,
# Mushroom_Cluster ; rochers low-poly : Boulder@0.5, Cluster@0.375, SteppingStones@0.375.
# Boîtes : reprises telles quelles. Solides en escalier (normales sur les axes) : découpés en boîtes sur la grille de leurs
# coordonnées. Maillages à facettes (rochers low-poly) : passés en voxels (cases de VOX studs), dessus plus clair, bas plus
# sombre, mousse là où est la facette Moss.
import sys, pathlib, math
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from analyse import read_glb, acc_read, mat4, mmul, apply, components, classify, lin2srgb, sub, cross, dot, norm, key


def hexcol(mat):
    bc = mat.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
    return "%02X%02X%02X" % tuple(round(255 * lin2srgb(c)) for c in bc[:3])


def ray_hits(o, d, tris):
    n = 0
    for a, b, c in tris:
        e1, e2 = sub(b, a), sub(c, a)
        p = cross(d, e2)
        det = dot(e1, p)
        if abs(det) < 1e-12:
            continue
        inv = 1 / det
        t0 = sub(o, a)
        u = dot(t0, p) * inv
        if u < 0 or u > 1:
            continue
        q = cross(t0, e1)
        v = dot(d, q) * inv
        if v < 0 or u + v > 1:
            continue
        if dot(e2, q) * inv > 1e-9:
            n += 1
    return n


DIR = norm((1, 0.0137, 0.0071))


def inside(p, tris):
    return ray_hits(p, DIR, tris) % 2 == 1


def merge(cells):
    # cells : dict (i, j, k) -> couleur ; fusion gloutonne x puis z puis y
    boxes, used = [], set()
    for c in sorted(cells, key=lambda t: (t[1], t[2], t[0])):
        if c in used:
            continue
        col = cells[c]
        i, j, k = c

        def free(x, y, z):
            return (x, y, z) in cells and (x, y, z) not in used and cells[(x, y, z)] == col

        i1 = i
        while free(i1 + 1, j, k):
            i1 += 1

        def row_ok(kk, jj):
            return all(free(x, jj, kk) for x in range(i, i1 + 1))

        k1 = k
        while row_ok(k1 + 1, j):
            k1 += 1

        def lay_ok(jj):
            return all(row_ok(kk, jj) for kk in range(k, k1 + 1))

        j1 = j
        while lay_ok(j1 + 1):
            j1 += 1
        for x in range(i, i1 + 1):
            for y in range(j, j1 + 1):
                for z in range(k, k1 + 1):
                    used.add((x, y, z))
        boxes.append(((i, j, k), (i1, j1, k1), col))
    return boxes


def rectilinear(comp):
    pts = {key(p) for t in comp for p in t}
    xs, ys, zs = (sorted({p[a] for p in pts}) for a in range(3))
    cells = {}
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            for k in range(len(zs) - 1):
                c = ((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2, (zs[k] + zs[k + 1]) / 2)
                if inside(c, comp):
                    cells[(i, j, k)] = 1
    out = []
    for (i, j, k), (i1, j1, k1), _ in merge(cells):
        lo, hi = (xs[i], ys[j], zs[k]), (xs[i1 + 1], ys[j1 + 1], zs[k1 + 1])
        out.append((tuple((lo[a] + hi[a]) / 2 for a in range(3)), tuple(hi[a] - lo[a] for a in range(3)), None))
    return out


def neg(a):
    return tuple(-v for v in a)


def box_of(pts, axes):
    ax = [axes[0], axes[1], cross(axes[0], axes[1])]
    ax.sort(key=lambda a: -abs(a[1]))
    up = ax[0] if ax[0][1] > 0 else neg(ax[0])
    rest = sorted(ax[1:], key=lambda a: -abs(a[0]))
    rx = rest[0] if rest[0][0] >= 0 else neg(rest[0])
    rz = cross(rx, up)
    R = (rx, up, rz)
    proj = [[dot(p, a) for p in pts] for a in R]
    size = tuple(max(pr) - min(pr) for pr in proj)
    cl = [(max(pr) + min(pr)) / 2 for pr in proj]
    center = tuple(sum(R[a][w] * cl[a] for a in range(3)) for w in range(3))
    ident = abs(rx[0] - 1) < 1e-4 and abs(up[1] - 1) < 1e-4
    return center, size, (None if ident else R)


def shade(h, f):
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return "%02X%02X%02X" % tuple(max(0, min(255, round(v * f))) for v in (r, g, b))


def voxelize(ft, c):
    rock, moss = ft.get("Rock", []), ft.get("Moss", [])
    base, mossc = ft.get("_col_Rock", "A9B0BC"), ft.get("_col_Moss", "5AB04A")
    allt = rock + moss
    pts = [p for t in allt for p in t]
    lo = [min(p[a] for p in pts) for a in range(3)]
    hi = [max(p[a] for p in pts) for a in range(3)]
    nx = max(1, round((hi[0] - lo[0]) / c))
    nz = max(1, round((hi[2] - lo[2]) / c))
    h = hi[1] - lo[1]
    ny = max(1, round(h / c))
    cy = h / ny
    ox = lo[0] + ((hi[0] - lo[0]) - nx * c) / 2
    oz = lo[2] + ((hi[2] - lo[2]) - nz * c) / 2

    def ctr(i, j, k):
        return (ox + (i + 0.5) * c, lo[1] + (j + 0.5) * cy, oz + (k + 0.5) * c)

    filled = set()
    for i in range(nx):
        for j in range(ny):
            for k in range(nz):
                if inside(ctr(i, j, k), allt):
                    filled.add((i, j, k))

    def in_tri_xz(p, t):
        (ax, _, az), (bx, _, bz), (cx_, _, cz) = t
        d = (bz - cz) * (ax - cx_) + (cx_ - bx) * (az - cz)
        if abs(d) < 1e-12:
            return False
        l1 = ((bz - cz) * (p[0] - cx_) + (cx_ - bx) * (p[2] - cz)) / d
        l2 = ((cz - az) * (p[0] - cx_) + (ax - cx_) * (p[2] - cz)) / d
        return l1 >= -0.1 and l2 >= -0.1 and 1 - l1 - l2 >= -0.1

    top_c, low_c = shade(base, 1.13), shade(base, 0.84)
    cells = {}
    for (i, j, k) in filled:
        col = base
        if (i, j + 1, k) not in filled:
            col = mossc if any(in_tri_xz(ctr(i, j, k), t) for t in moss) else top_c
        elif j == 0 and ny > 2:
            col = low_c
        cells[(i, j, k)] = col
    out = []
    for (i, j, k), (i1, j1, k1), col in merge(cells):
        a, b = ctr(i, j, k), ctr(i1, j1, k1)
        center = tuple((a[w] + b[w]) / 2 for w in range(3))
        size = ((i1 - i + 1) * c, (j1 - j + 1) * cy, (k1 - k + 1) * c)
        part = "Moss" if col == mossc else ("RockTop" if col == top_c else ("RockDark" if col == low_c else "Rock"))
        out.append(("", part, center, size, None, col))
    return out, len(filled)


def convert(path, vox=None):
    js, binc = read_glb(path)
    nodes, meshes, mats = js["nodes"], js["meshes"], js.get("materials", [])
    root = js["scenes"][0]["nodes"][0]
    name = nodes[root].get("name", pathlib.Path(path).stem)
    parts, ft = [], {}

    def walk(ni, m, groups):
        n = nodes[ni]
        mm = mmul(m, mat4(n))
        if "mesh" in n:
            for prim in meshes[n["mesh"]]["primitives"]:
                pos = [apply(mm, p) for p in acc_read(js, binc, prim["attributes"]["POSITION"])]
                idx = [i[0] for i in acc_read(js, binc, prim["indices"])] if "indices" in prim else list(range(len(pos)))
                tris = [(pos[idx[i]], pos[idx[i + 1]], pos[idx[i + 2]]) for i in range(0, len(idx), 3)]
                col = hexcol(mats[prim["material"]]) if "material" in prim else "FFFFFF"
                if vox:
                    ft.setdefault(n["name"], []).extend(tris)
                    ft.setdefault("_col_" + n["name"], col)
                    continue
                for comp in components(tris):
                    kind, axes, pts = classify(comp)
                    if kind == "box":
                        c, s, r = box_of(pts, axes)
                        parts.append(("/".join(groups), n["name"], c, s, r, col))
                    else:
                        for c, s, r in rectilinear(comp):
                            parts.append(("/".join(groups), n["name"], c, s, r, col))
        for ch in n.get("children", []):
            g = groups if (ni == root or "mesh" in n) else groups + [n["name"]]
            walk(ch, mm, g)

    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    walk(root, ident, [])
    info = ""
    if vox:
        parts, nf = voxelize(ft, vox)
        info = " (%d voxels de %.3g)" % (nf, vox)
    return name, parts, info


def lua_num(v):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


if __name__ == "__main__":
    out_path = pathlib.Path(sys.argv[1])
    lines = ["-- Généré par voxel/convert.py depuis les GLB de Claude Design (ne pas retoucher à la main).",
             "-- [nom] = { { groupe, pièce, cx, cy, cz, sx, sy, sz, couleur, [r00, r01, r02, r10, ..., r22] }, ... }",
             "-- Repère du modèle : origine au centre-bas, Y vers le haut, avant vers -Z (1 unité = 1 stud).", "return {"]
    for spec in sys.argv[2:]:
        path, _, vox = spec.partition("@")
        name, parts, info = convert(path, float(vox) if vox else None)
        rows = []
        for g, pn, c, s, r, col in parts:
            row = '{ "%s", "%s", %s, "%s"' % (g, pn, ", ".join(lua_num(v) for v in (*c, *s)), col)
            if r:
                rx, up, rz = r
                m = [rx[0], up[0], rz[0], rx[1], up[1], rz[1], rx[2], up[2], rz[2]]
                row += ", " + ", ".join(lua_num(v) for v in m)
            rows.append("\t\t" + row + " },")
        lines.append("\t%s = {" % name)
        lines += rows
        lines.append("\t},")
        print(name, len(parts), "pièces" + info)
    lines.append("}")
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

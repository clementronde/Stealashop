import re, sys, pathlib
src = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
models = {}
cur = None
for line in src.splitlines():
    m = re.match(r"\t(ENV_\w+) = \{$", line)
    if m:
        cur = m.group(1); models[cur] = []; continue
    m = re.match(r'\t\t\{ "([^"]*)", "([^"]*)", (.*) \},$', line)
    if m and cur:
        g, p, rest = m.groups()
        f = [x.strip() for x in rest.split(",")]
        nums, col, rot = f[0:6], f[6].strip('"'), f[7:]
        models[cur].append((g, p, nums, col, tuple(rot)))
def sn(s):
    s = s.replace("-0.", "-.") if s.startswith("-0.") else (s[1:] if s.startswith("0.") else s)
    return s
groups, parts, cols, rots = [], [], [], [()]
def idx(lst, v):
    if v not in lst: lst.append(v)
    return lst.index(v)
out_models = []
for name, rows in models.items():
    enc = []
    for g, p, nums, col, rot in rows:
        fields = [str(idx(groups, g)), str(idx(parts, p))] + [sn(x) for x in nums] + [str(idx(cols, col))]
        r = idx(rots, rot)
        if r: fields.append(str(r))
        enc.append(" ".join(fields))
    out_models.append('\t%s = "%s",' % (name, ";".join(enc)))
lua = ["-- Généré par garden_voxel_convert (convert.py puis compact.py) depuis les GLB de Claude Design : ne pas retoucher.",
       "-- Chaque modèle : lignes « groupe pièce cx cy cz sx sy sz couleur [rotation] » (index dans les palettes, base 0),",
       "-- repère du modèle : origine au centre-bas, Y vers le haut, avant vers -Z, 1 unité = 1 stud.",
       "-- À envoyer à execute_luau AVANT tools/clement/hub/garden_voxel_build.luau, qui lit _G.ClaudeGardenVoxel.",
       "local G = { %s }" % ", ".join('"%s"' % g for g in groups),
       "local P = { %s }" % ", ".join('"%s"' % p for p in parts),
       "local C = { %s }" % ", ".join('"%s"' % c for c in cols),
       "local R = { {}, %s }" % ", ".join("{ %s }" % ", ".join(sn(x) for x in r) for r in rots[1:]),
       "local M = {"] + out_models + ["}",
       "local out, n = {}, 0",
       "for name, s in M do",
       "\tlocal rows = {}",
       "\tfor line in string.gmatch(s, \"[^;]+\") do",
       "\t\tlocal f = {}",
       "\t\tfor w in string.gmatch(line, \"%S+\") do table.insert(f, tonumber(w)) end",
       "\t\tlocal row = { G[f[1] + 1], P[f[2] + 1], f[3], f[4], f[5], f[6], f[7], f[8], C[f[9] + 1] }",
       "\t\tlocal r = f[10] and R[f[10] + 1]",
       "\t\tif r then for _, v in r do table.insert(row, v) end end",
       "\t\ttable.insert(rows, row)",
       "\tend",
       "\tout[name] = rows; n += 1",
       "end",
       "_G.ClaudeGardenVoxel = out",
       'return n .. " modèles voxel en mémoire"']
pathlib.Path(sys.argv[2]).write_text("\n".join(lua) + "\n", encoding="utf-8")
print(len(groups), "groupes,", len(parts), "pièces,", len(cols), "couleurs,", len(rots) - 1, "rotations")

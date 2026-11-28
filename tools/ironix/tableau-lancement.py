# Tableau des fonctions pour la liste de lancement (chef code, 28/11).
# Lit src/shared/Config/Features.luau, docs/claude/interrupteurs-test.md et la liaison ;
# écrit docs/claude/liste-lancement.md. Aucune valeur n'est inventée : tout vient de ces fichiers.
# Usage : py -I tools/ironix/tableau-lancement.py   (depuis la racine du dépôt)
import re, os, subprocess

ROOT = os.getcwd()
def rd(p):
    with open(os.path.join(ROOT, p), encoding='utf-8') as f:
        return f.read()

feat = rd('src/shared/Config/Features.luau')
body = feat[feat.index('local Features = {'):feat.index('\nexport type Features')]
entries = []  # (name, value, comment)
pending = []
for ln in body.splitlines()[1:]:
    s = ln.strip()
    if s.startswith('--'):
        pending.append(s[2:].strip())
        continue
    m = re.match(r'([A-Za-z0-9_]+)\s*=\s*(true|false)\s*,?\s*(?:--\s*(.*))?$', s)
    if m:
        com = ' '.join(pending + ([m.group(3)] if m.group(3) else []))
        entries.append((m.group(1), m.group(2) == 'true', com))
        pending = []
    elif s == '}' or s == '':
        pending = []
    else:
        m2 = re.match(r'([A-Za-z0-9_]+)\s*=', s)
        if m2:
            entries.append((m2.group(1), None, 'valeur non booléenne : ' + s))
            pending = []

vals = {n: (v, c) for n, v, c in entries}

# descriptions courtes de la fiche du 27/11
fiche = {}
section = ''
for ln in rd('docs/claude/interrupteurs-test.md').splitlines():
    if ln.startswith('### '):
        section = ln[4:].strip()
    m = re.match(r'\|\s*`Feature_([A-Za-z0-9_]+)`\s*\|\s*([^|]+)\|', ln)
    if m:
        k = m.group(1)
        base = k[:-3] if k.endswith('Dev') and k[:-3] in vals else k
        fiche.setdefault(base, (section, m.group(2).strip()))

liaison = rd('docs/Liaison-Code-Visuel.md')
hist = rd('docs/Liaison-Historique.md') if os.path.exists('docs/Liaison-Historique.md') else ''
tests_sec = liaison[liaison.index('## Tests à faire'):liaison.index('## 1. Attentes ouvertes')]
open_tests = {}
for ln in tests_sec.splitlines():
    m = re.match(r'- (T-\d+) \|\s*([^|]*)\|', ln)
    if m:
        open_tests[m.group(1)] = m.group(2).strip()
lrows = {}
for txt in (hist, liaison):
    for ln in txt.splitlines():
        m = re.match(r'\| (L-\d+) \|', ln)
        if m:
            lrows[m.group(1)] = ln

def tnorm(t):
    n = int(t[2:])
    return 'T-%03d' % n

# fonctions : X avec son éventuel XDev
names = [n for n, _, _ in entries]
funcs = []
seen = set()
for n in names:
    if n in seen:
        continue
    if n.endswith('Dev') and n[:-3] in vals:
        continue  # traité avec sa base
    dev = n + 'Dev' if (n + 'Dev') in vals else None
    seen.add(n)
    if dev:
        seen.add(dev)
    funcs.append((n, dev))
# XDev sans X
for n in names:
    if n not in seen:
        funcs.append((n, None)); seen.add(n)

rows = []
for base, dev in funcs:
    v, c = vals[base]
    dv = vals[dev][0] if dev else None
    com = c + (' ' + vals[dev][1] if dev else '')
    if base.endswith('Dev') and dev is None:
        prod = False; devstate = v
    else:
        prod = bool(v); devstate = bool(v) or bool(dv)
    Ls = sorted(set(re.findall(r'L-\d+', com)), key=lambda x: int(x[2:]))
    Ts = set(tnorm(t) for t in re.findall(r'T-\d+', com))
    for L in Ls:
        r = lrows.get(L, '')
        Ts |= set(tnorm(t) for t in re.findall(r'T-\d+', r))
    Ts = sorted(Ts, key=lambda x: int(x[2:]))
    ouverts = [t for t in Ts if t in open_tests]
    fermes = [t for t in Ts if t not in open_tests]
    sec, desc = fiche.get(base, ('', ''))
    if not desc:
        d = re.sub(r'\s+', ' ', com)
        desc = (d[:160] + '…') if len(d) > 160 else d
    if prod:
        cat = 'A'
    elif not devstate:
        cat = 'D'
    elif Ts and not ouverts:
        cat = 'B'
    elif ouverts:
        cat = 'C'
    else:
        cat = 'E'
    rows.append(dict(base=base, dev=dev, prod=prod, devs=devstate, Ls=Ls, ouverts=ouverts,
                     fermes=fermes, sec=sec, desc=desc.replace('|', '/'), cat=cat))

head = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip()
CATS = {
    'A': "A. Déjà allumées en PROD (à garder ou à éteindre)",
    'B': "B. Éteintes en PROD, allumées en DEV, aucun test ouvert (test passé ou retiré : à confirmer)",
    'C': "C. Éteintes en PROD, allumées en DEV, au moins un test ouvert",
    'E': "E. Éteintes en PROD, allumées en DEV, aucun test relié trouvé par le script (à relier à la main)",
    'D': "D. Éteintes partout (pas prêtes, ou en attente d'une décision)",
}
out = []
out.append('# Liste de lancement : tableau des fonctions\n')
out.append(f"Généré par `tools/ironix/tableau-lancement.py` sur le commit `{head}`. Ne pas éditer à la main : relancer le script.\n")
out.append("Sources : `src/shared/Config/Features.luau` (valeurs du fichier, sans clé du Creator Hub), `docs/claude/interrupteurs-test.md` (descriptions), la liaison (tests ouverts de « Tests à faire » ; T- relié par le commentaire de l'interrupteur ou par une ligne L- qu'il cite).\n")
out.append("- **PROD** = valeur de `X` ; **DEV** = `X` ou `XDev`. Une fonction sans `XDev` a la même valeur partout.\n- **Tests ouverts** : encore dans la liste. **Hors liste** : passé ou retiré (sans objet) ; le script ne sait pas lequel.\n- **Lancement ?** : la case que Cantin remplit (oui / non).\n")
for k in 'ABCED':
    rs = [r for r in rows if r['cat'] == k]
    out.append(f"\n## {CATS[k]} — {len(rs)}\n")
    out.append('| Lancement ? | Interrupteur | Ce que ça fait | PROD | DEV | Tests ouverts | Hors liste | Lignes L- |')
    out.append('| --- | --- | --- | --- | --- | --- | --- | --- |')
    for r in rs:
        nm = f"`{r['base']}`" + (f" (+ `{r['dev']}`)" if r['dev'] else '')
        out.append('|  | %s | %s | %s | %s | %s | %s | %s |' % (
            nm, r['desc'], 'oui' if r['prod'] else 'non', 'oui' if r['devs'] else 'non',
            ', '.join(r['ouverts']) or '—', ', '.join(r['fermes']) or '—', ', '.join(r['Ls']) or '—'))
os.makedirs('docs/claude', exist_ok=True)
with open('docs/claude/liste-lancement.md', 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(out) + '\n')
from collections import Counter
print(len(entries), 'lignes,', len(rows), 'fonctions', dict(Counter(r['cat'] for r in rows)))

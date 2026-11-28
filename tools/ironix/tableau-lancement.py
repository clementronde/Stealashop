# Tableau des fonctions pour la liste de lancement (chef code, 28/11).
# Lit src/shared/Config/Features.luau, docs/claude/interrupteurs-test.md, la liaison et son historique ;
# écrit docs/claude/liste-lancement.md. Aucune valeur n'est inventée : tout vient de ces fichiers.
# Usage : py -I -X utf8 tools/ironix/tableau-lancement.py   (depuis la racine du dépôt)
import re, os, subprocess
from collections import Counter, OrderedDict

def rd(p):
    with open(p, encoding='utf-8') as f:
        return f.read()

# --- interrupteurs ---
feat = rd('src/shared/Config/Features.luau')
body = feat[feat.index('local Features = {'):feat.index('\nexport type Features')]
entries, pending = [], []
for ln in body.splitlines()[1:]:
    s = ln.strip()
    if s.startswith('--'):
        pending.append(s[2:].strip()); continue
    m = re.match(r'([A-Za-z0-9_]+)\s*=\s*(true|false)\s*,?\s*(?:--\s*(.*))?$', s)
    if m:
        entries.append((m.group(1), m.group(2) == 'true', ' '.join(pending + ([m.group(3)] if m.group(3) else []))))
        pending = []
    elif s in ('}', ''):
        pending = []
    else:
        raise SystemExit('ligne non lue dans Features.luau : ' + s)
vals = {n: (v, c) for n, v, c in entries}

# --- descriptions et domaines de la fiche du 27/11 ---
fiche, section = {}, ''
for ln in rd('docs/claude/interrupteurs-test.md').splitlines():
    if ln.startswith('### '):
        section = ln[4:].strip()
    m = re.match(r'\|\s*`Feature_([A-Za-z0-9_]+)`\s*\|\s*([^|]+)\|', ln)
    if m:
        k = m.group(1)
        base = k[:-3] if k.endswith('Dev') and k[:-3] in vals else k
        fiche.setdefault(base, (section, m.group(2).strip()))

# --- liaison ---
liaison = rd('docs/Liaison-Code-Visuel.md')
hist = rd('docs/Liaison-Historique.md')
tests_sec = liaison[liaison.index('## Tests à faire'):liaison.index('## 1. Attentes ouvertes')]
open_tests = OrderedDict()
for ln in tests_sec.splitlines():
    m = re.match(r'- (T-\d+) \|', ln)
    if m:
        open_tests[m.group(1)] = ln
lrows = {}
for txt in (hist, liaison):
    for ln in txt.splitlines():
        m = re.match(r'\| (L-\d+) \|', ln)
        if m:
            lrows[m.group(1)] = ln
def tn(t): return 'T-%03d' % int(t[2:])
def tlist(txt): return set(tn(t) for t in re.findall(r'T-\d+', txt))

# --- fonctions : X avec son XDev ---
funcs, seen = [], set()
for n, _, _ in entries:
    if n in seen or (n.endswith('Dev') and n[:-3] in vals):
        continue
    dev = n + 'Dev' if n + 'Dev' in vals else None
    seen |= {n} | ({dev} if dev else set())
    funcs.append((n, dev))
for n, _, _ in entries:
    if n not in seen:
        funcs.append((n, None)); seen.add(n)

rows = []
for base, dev in funcs:
    v, c = vals[base]
    com = c + (' ' + vals[dev][1] if dev else '')
    prod = bool(v)
    devs = bool(v) or (bool(vals[dev][0]) if dev else False)
    Ls = sorted(set(re.findall(r'L-\d+', com)), key=lambda x: int(x[2:]))
    # lien 1 : T- cités par le commentaire de l'interrupteur, ou par une ligne L- qu'il cite
    T1 = tlist(com)
    for L in Ls:
        T1 |= tlist(lrows.get(L, ''))
    # lien 2 : le nom de l'interrupteur cité dans une ligne de test ouverte ou dans une ligne L-
    pat = re.compile(r'(?:`|Features\.|Feature_)(?:%s)\b' % '|'.join(re.escape(x) for x in [base] + ([dev] if dev else [])))
    T2 = set(t for t, ln in open_tests.items() if pat.search(ln))
    L2 = sorted((L for L, ln in lrows.items() if pat.search(ln)), key=lambda x: int(x[2:]))
    for L in L2:
        T2 |= tlist(lrows[L])
    # lien 3 : le numéro d'agent (aNNN) du commentaire cité dans une ligne de test ouverte
    ags = set(re.findall(r'\ba\d{3}[a-z]?\b', com))
    if ags:
        pa = re.compile(r'\b(?:%s)\b' % '|'.join(sorted(ags)))
        T2 |= set(t for t, ln in open_tests.items() if pa.search(ln))
    T2 -= T1
    Ts = T1 | T2
    srt = lambda xs: sorted(xs, key=lambda x: int(x[2:]))
    ouverts = srt(t for t in Ts if t in open_tests)
    fermes = srt(t for t in Ts if t not in open_tests)
    sec, desc = fiche.get(base, ('', ''))
    if not desc:
        d = re.sub(r'\s+', ' ', com)
        desc = (d[:150] + '…') if len(d) > 150 else d
    if prod:
        cat = 'A'
    elif not devs:
        cat = 'D'
    elif ouverts:
        cat = 'C'
    elif Ts:
        cat = 'B'
    else:
        cat = 'E'
    rows.append(dict(base=base, dev=dev, prod=prod, devs=devs, Ls=srt(set(Ls) | set(L2)),
                     ouverts=ouverts, fermes=fermes, lien2=bool(T2 and not T1), sec=sec or 'Autres (absentes de la fiche du 27/11)',
                     desc=desc.replace('|', '/'), cat=cat))

head = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip()
cnt = Counter(r['cat'] for r in rows)
TITRES = {
    'C': "C. Éteintes en PROD, allumées en DEV, au moins un test humain encore ouvert",
    'B': "B. Éteintes en PROD, allumées en DEV, tests reliés tous hors de la liste (passés ou retirés)",
    'E': "E. Éteintes en PROD, allumées en DEV, aucun test relié automatiquement",
    'D': "D. Éteintes partout (DEV compris)",
    'A': "A. Déjà allumées en PROD",
}
out = []
w = out.append
w('# Liste de lancement : tableau des fonctions\n')
w(f"Généré par `tools/ironix/tableau-lancement.py` sur le commit `{head}` ; ne pas éditer à la main, relancer le script.\n")
w('## Comment lire\n')
w(f"- **{len(rows)} fonctions** = les {len(entries)} lignes de `src/shared/Config/Features.luau`, une paire `X` / `XDev` comptant pour une fonction.")
w("- **Groupes exclusifs** : chaque fonction est dans un seul groupe, choisi dans cet ordre : allumée en PROD → A ; éteinte partout → D ; sinon (éteinte en PROD, allumée en DEV) : un test ouvert → C, des tests reliés mais tous hors liste → B, aucun test relié → E.")
w('- Compte : ' + ' + '.join(f"{k} {cnt.get(k,0)}" for k in 'ACBED') + f" = {sum(cnt.values())}.")
w("- **PROD / DEV** : valeur du fichier (`X` pour la PROD ; `X` ou `XDev` pour DEV et TEST). Les clés `Feature_*` posées dans les Configs du Creator Hub du jeu PROD ne sont pas lues ici : elles peuvent changer la valeur réelle.")
w("- **Test relié** : (1) un T- cité dans le commentaire de l'interrupteur ou dans une ligne L- qu'il cite ; (2) le nom de l'interrupteur, entre accents graves ou écrit `Features.X` / `Feature_X`, cité dans une ligne de test ouverte ou dans une ligne L- (liaison ou historique) ; (3) le numéro d'agent (aNNN) du commentaire cité dans une ligne de test ouverte. Les cas (2) et (3) seuls sont marqués « (lien indirect) » : à relire, un test peut y être relié à tort.")
w("- **« Aucun test relié automatiquement »** veut dire que ces trois recherches ne trouvent rien. Ce n'est **pas** une couverture vérifiée comme absente : un test peut exister sous un autre nom, et les bancs ne sont pas comptés.")
w("- **Hors liste** : un T- relié qui n'est plus dans « Tests à faire » : passé, ou retiré sans objet ; le script ne sait pas lequel.")
w("- **Règle C2** : en PROD, seul ce qui a passé un test humain s'allume. Cocher une fonction = la vouloir au lancement ; ses tests ouverts passent alors en priorité.\n")

def table(rs):
    w('| Au lancement ? | Fonction | Ce que ça fait | PROD | DEV | Tests ouverts | Hors liste | Lignes L- |')
    w('| --- | --- | --- | --- | --- | --- | --- | --- |')
    for r in rs:
        nm = f"`{r['base']}`" + (f" (+ `{r['dev']}`)" if r['dev'] else '')
        to = ', '.join(r['ouverts']) or '—'
        if r['lien2'] and r['ouverts']:
            to += ' (lien indirect)'
        w('|  | %s | %s | %s | %s | %s | %s | %s |' % (nm, r['desc'], 'oui' if r['prod'] else 'non',
          'oui' if r['devs'] else 'non', to, ', '.join(r['fermes']) or '—', ', '.join(r['Ls']) or '—'))

w('# Partie 1 — Les fonctions sur lesquelles Cantin décide\n')
w("Éteintes en PROD aujourd'hui. Pour chacune : la veux-tu allumée au lancement ?\n")
for k in 'CBE':
    rs = [r for r in rows if r['cat'] == k]
    if not rs:
        w(f"\n## {TITRES[k]} — 0\n"); continue
    w(f"\n## {TITRES[k]} — {len(rs)}\n")
    for sec in sorted(set(r['sec'] for r in rs), key=lambda s: (s.startswith('Autres'), s)):
        w(f"\n### {sec}\n")
        table([r for r in rs if r['sec'] == sec])
w(f"\n## {TITRES['D']} — {cnt.get('D',0)}\n")
w("Éteintes même en DEV : à allumer seulement sur décision (certaines sont retirées de la V1, voir leurs lignes L-).\n")
table([r for r in rows if r['cat'] == 'D'])
w('\n# Partie 2 — Pour information\n')
w(f"\n## {TITRES['A']} — {cnt.get('A',0)}\n")
w("Rien à décider sauf si tu veux en éteindre une.\n")
table([r for r in rows if r['cat'] == 'A'])
with open('docs/claude/liste-lancement.md', 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(out) + '\n')
print(len(entries), 'lignes ;', len(rows), 'fonctions ;', dict(cnt))
print('E :', ' '.join(r['base'] for r in rows if r['cat'] == 'E'))
print('lien par le nom seulement :', ' '.join(r['base'] for r in rows if r['lien2']))

# Trouve la vue 3D de Studio sur une capture de l'écran prise pendant l'écran noir de T.prepare().
#   python -I find_viewport.py ecran.png [largeur hauteur]
# Affiche "x y w h" (pixels de l'écran) : le plus grand rectangle noir, c'est-à-dire le viewport masqué
# par la pièce noire de synchro. Avec largeur et hauteur (Camera.ViewportSize), vérifie que ça colle.
import sys
from collections import Counter

import numpy as np
from PIL import Image

img = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.int16)
black = (img.max(axis=2) < 12)

runs = []
for y in range(black.shape[0]):
    row = black[y]
    best, start, cur, s = 0, 0, 0, 0
    for x, b in enumerate(row):
        if b:
            if cur == 0:
                s = x
            cur += 1
            if cur > best:
                best, start = cur, s
        else:
            cur = 0
    if best >= 200:
        runs.append((y, start, best))

if not runs:
    sys.exit("aucun rectangle noir : lancer T.prepare() avant la capture")

(start, length), _ = Counter((s, l) for _, s, l in runs).most_common(1)[0]
rows = [y for y, s, l in runs if s == start and l == length]
y0, y1 = min(rows), max(rows)
w, h = length, y1 - y0 + 1
if len(sys.argv) >= 4:
    ew, eh = int(sys.argv[2]), int(sys.argv[3])
    if abs(w - ew) > 4 or abs(h - eh) > 4:
        print(f"attention : rectangle {w}x{h}, viewport attendu {ew}x{eh}", file=sys.stderr)
print(start, y0, w - (w % 2), h - (h % 2))

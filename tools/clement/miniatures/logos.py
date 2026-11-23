# Logos « STEAL A SHOP » : 3 propositions, PNG transparents (MOD-043, 2026-11-21).
# Polices libres (OFL) livrées avec Roblox Studio : Luckiest Guy, Fredoka One.
# Lancer : py -I tools/clement/miniatures/logos.py
# Sorties : docs/claude/miniatures/2026-11-21_logo/
#   LOGO_<n>_<nom>_fond-clair.png  : contour noir seul (fonds clairs ou moyens)
#   LOGO_<n>_<nom>_fond-sombre.png : contour noir + liseré blanc (fonds sombres)
#   apercu-200px.png               : chaque logo à 200 px de large sur 4 fonds
import glob
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "docs", "claude", "miniatures", "2026-11-21_logo")
os.makedirs(OUT, exist_ok=True)

INK = (27, 27, 36)  # #1B1B24, contour de l'UI
WHITE = (255, 255, 255)


def font_path(name):
    hits = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions", "*", "content", "fonts", name))
    if not hits:
        raise SystemExit("police introuvable : " + name)
    return hits[0]


def vgrad(size, stops):
    """Dégradé vertical, stops = [(t, (r, g, b)), ...]"""
    w, h = size
    col = Image.new("RGB", (1, h))
    px = col.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                k = (t - t0) / max(1e-6, t1 - t0)
                px[0, y] = tuple(int(c0[j] + (c1[j] - c0[j]) * k) for j in range(3))
                break
    return col.resize((w, h))


class Word:
    """Un mot dessiné lettre par lettre : masque du remplissage et masque avec contour."""

    def __init__(self, text, fpath, size, stroke, track=-0.02, wobble=0.0, seed=1):
        self.font = ImageFont.truetype(fpath, size)
        self.stroke = stroke
        rnd = random.Random(seed)
        asc, desc = self.font.getmetrics()
        pad = stroke * 3
        # espace élargie : « STEAL A » ne doit pas se lire « STEALA » à 200 px
        widths = [self.font.getlength(c) * (1.9 if c == " " else 1) for c in text]
        W = int(sum(widths) + size * track * (len(text) - 1) + pad * 2)
        H = int(asc + desc + pad * 2)
        self.fill = Image.new("L", (W, H), 0)
        self.sil = Image.new("L", (W, H), 0)
        self.letters = []  # (char, x, y) pour retrouver une lettre
        x = pad
        for c, w in zip(text, widths):
            y = pad + (rnd.uniform(-1, 1) * wobble * size if wobble else 0)
            ImageDraw.Draw(self.fill).text((x, y), c, font=self.font, fill=255)
            ImageDraw.Draw(self.sil).text((x, y), c, font=self.font, fill=255, stroke_width=stroke, stroke_fill=255)
            self.letters.append((c, x, y, w))
            x += w + size * track
        bbox = self.sil.getbbox()
        self.fill, self.sil = self.fill.crop(bbox), self.sil.crop(bbox)
        self.letters = [(c, lx - bbox[0], ly - bbox[1], lw) for c, lx, ly, lw in self.letters]
        self.size = self.sil.size


def render_word(word, stops, shadow, ring=0, highlight=True):
    """Calque RGBA : liseré blanc (option), ombre dure, contour noir, dégradé, reflet."""
    W, H = word.size
    m = ring + shadow + 4
    lay = Image.new("RGBA", (W + 2 * m, H + 2 * m), (0, 0, 0, 0))
    off = (m, m)

    def at(mask, dx=0, dy=0):
        full = Image.new("L", lay.size, 0)
        full.paste(mask, (off[0] + dx, off[1] + dy))
        return full

    sil, sil_down = at(word.sil), at(word.sil, 0, shadow)
    if ring:
        both = ImageChops.lighter(sil, sil_down)
        for _ in range(ring // 2):
            both = both.filter(ImageFilter.MaxFilter(5))
        lay.paste(Image.new("RGBA", lay.size, WHITE + (255,)), (0, 0), both)
    lay.paste(Image.new("RGBA", lay.size, INK + (255,)), (0, 0), sil_down)  # ombre dure dessous
    lay.paste(Image.new("RGBA", lay.size, INK + (255,)), (0, 0), sil)  # contour
    fill = at(word.fill)
    lay.paste(vgrad(lay.size, stops).convert("RGBA"), (0, 0), fill)
    if highlight:  # reflet doux sur le haut des lettres
        hl = Image.new("L", lay.size, 0)
        bb = fill.getbbox()
        ImageDraw.Draw(hl).rectangle((0, 0, lay.size[0], bb[1] + (bb[3] - bb[1]) * 0.42), fill=70)
        hl = ImageChops.multiply(hl, fill.filter(ImageFilter.MinFilter(9)))
        lay.paste(Image.new("RGBA", lay.size, WHITE + (255,)), (0, 0), hl)
    return lay


def stack(layers, gap, align="left", indents=None):
    """Empile des calques de haut en bas (gap négatif = recouvrement)."""
    W = max(l.size[0] + (indents[i] if indents else 0) for i, l in enumerate(layers))
    H = sum(l.size[1] for l in layers) + gap * (len(layers) - 1)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    y = 0
    for i, l in enumerate(layers):
        x = (W - l.size[0]) // 2 if align == "center" else (indents[i] if indents else 0)
        out.alpha_composite(l, (x, y))
        y += l.size[1] + gap
    return out


def finish(img, angle, pad=24):
    img = img.rotate(angle, resample=Image.BICUBIC, expand=True)
    img = img.crop(img.getbbox())
    out = Image.new("RGBA", (img.size[0] + 2 * pad, img.size[1] + 2 * pad), (0, 0, 0, 0))
    out.alpha_composite(img, (pad, pad))
    return out


GOLD = [(0, (255, 236, 120)), (0.45, (255, 194, 26)), (1, (240, 140, 0))]
SILVER = [(0, (255, 255, 255)), (0.6, (240, 244, 252)), (1, (196, 206, 224))]
RED = [(0, (255, 140, 120)), (0.45, (255, 59, 59)), (1, (200, 20, 40))]
ORANGE = [(0, (255, 214, 110)), (0.5, (255, 138, 31)), (1, (232, 70, 30))]
GLASS = [(0, (236, 249, 255)), (0.5, (170, 222, 255)), (1, (110, 186, 240))]


def logo_1(ring):
    """Classique : comme l'écran de chargement (STEAL A blanc, SHOP or), sans pictogramme."""
    fp = font_path("LuckiestGuy-Regular.ttf")
    top = render_word(Word("STEAL A", fp, 170, 16, wobble=0.015, seed=3), SILVER, 12, ring)
    shop = render_word(Word("SHOP", fp, 330, 26, wobble=0.02, seed=5), GOLD, 20, ring)
    return finish(stack([top, shop], gap=-62, indents=[18, 0]), 4)


def glass_pane(w, h, ring):
    """Pictogramme : vitre bleue fendue depuis un point d'impact, éclats qui partent."""
    m = 170
    lay = Image.new("RGBA", (w + 2 * m, h + 2 * m), (0, 0, 0, 0))
    pane = Image.new("L", lay.size, 0)
    ImageDraw.Draw(pane).rounded_rectangle((m, m, m + w, m + h), radius=34, fill=255)
    # morceaux arrachés en haut à droite (le trou de la casse)
    hole = Image.new("L", lay.size, 0)
    hx, hy = m + w * 0.86, m + h * 0.2
    ImageDraw.Draw(hole).polygon([(hx - 120, m - 5), (m + w + 5, m - 5), (m + w + 5, hy + 110), (hx + 10, hy + 40), (hx - 40, hy + 70), (hx - 70, hy - 10)], fill=255)
    pane = ImageChops.subtract(pane, hole)
    sil = pane.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.MaxFilter(13))
    if ring:
        r = sil
        for _ in range(ring // 2):
            r = r.filter(ImageFilter.MaxFilter(5))
        lay.paste(Image.new("RGBA", lay.size, WHITE + (255,)), (0, 0), r)
    lay.paste(Image.new("RGBA", lay.size, INK + (255,)), (0, 0), sil)
    lay.paste(vgrad(lay.size, GLASS).convert("RGBA"), (0, 0), pane)
    cr = Image.new("L", lay.size, 0)
    d = ImageDraw.Draw(cr)
    rnd = random.Random(8)
    ix, iy = hx - 30, hy + 30
    for k in range(13):
        a = math.radians(100 + k * 13 + rnd.uniform(-5, 5))
        pts, r = [(ix, iy)], 0
        while r < w * 1.1:
            r += rnd.uniform(40, 90)
            a2 = a + rnd.uniform(-0.12, 0.12)
            pts.append((ix + r * math.cos(a2), iy + r * math.sin(a2)))
        d.line(pts, fill=255, width=13, joint="curve")
    for r in (80, 170):
        d.arc((ix - r, iy - r, ix + r, iy + r), 90, 250, fill=255, width=10)
    lay.paste(Image.new("RGBA", lay.size, WHITE + (255,)), (0, 0), ImageChops.multiply(cr, pane))
    # éclats en vol
    for (sx, sy, s, rot) in ((m + w + 20, m - 10, 70, 20), (m + w + 95, m + 70, 50, 70), (m + w - 60, m - 75, 44, 130)):
        pts = [(sx + s * math.cos(math.radians(rot + q * 125)), sy + s * math.sin(math.radians(rot + q * 125))) for q in range(3)]
        sh = Image.new("L", lay.size, 0)
        ImageDraw.Draw(sh).polygon(pts, fill=255)
        lay.paste(Image.new("RGBA", lay.size, INK + (255,)), (0, 0), sh.filter(ImageFilter.MaxFilter(11)))
        lay.paste(vgrad(lay.size, GLASS).convert("RGBA"), (0, 0), sh)
    return lay


def logo_2(ring):
    """Vitrine cassée : STEAL A rouge, SHOP or, devant une vitre fendue."""
    fp = font_path("LuckiestGuy-Regular.ttf")
    top = render_word(Word("STEAL A", fp, 175, 16, seed=7), RED, 12, ring)
    shop = render_word(Word("SHOP", fp, 330, 26, seed=9), GOLD, 20, ring)
    text = stack([top, shop], gap=-60, align="center")
    tw, th = text.size
    # la vitre dépasse en haut à droite : c'est là qu'on voit l'impact, les fêlures et les éclats
    pane = glass_pane(int(tw * 0.82), int(th * 0.86), ring).rotate(-5, resample=Image.BICUBIC, expand=True)
    W, H = int(tw * 1.42), int(th * 1.55)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    tx, ty = int(W * 0.04), int(H - th - H * 0.04)
    out.alpha_composite(pane, (tx + int(tw * 0.3) - 170, ty - int(th * 0.34) - 170))
    out.alpha_composite(text, (tx, ty))
    return finish(out, 3)


def hammer(length, ring):
    """Pictogramme : masse (manche bois, tête acier), posée en diagonale."""
    L = length
    m = 80
    lay = Image.new("RGBA", (L + 2 * m, int(L * 0.3) + 2 * m), (0, 0, 0, 0))
    handle = Image.new("L", lay.size, 0)
    head = Image.new("L", lay.size, 0)
    cy = lay.size[1] // 2
    t = max(18, int(L * 0.024))
    ImageDraw.Draw(handle).rounded_rectangle((m, cy - t, m + L * 0.9, cy + t), radius=t, fill=255)
    ImageDraw.Draw(head).rounded_rectangle((m + L * 0.8, cy - L * 0.13, m + L, cy + L * 0.13), radius=24, fill=255)
    sil = ImageChops.lighter(handle, head).filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.MaxFilter(15))
    if ring:
        r = sil
        for _ in range(ring // 2):
            r = r.filter(ImageFilter.MaxFilter(5))
        lay.paste(Image.new("RGBA", lay.size, WHITE + (255,)), (0, 0), r)
    lay.paste(Image.new("RGBA", lay.size, INK + (255,)), (0, 0), sil)
    lay.paste(vgrad(lay.size, [(0, (214, 150, 90)), (1, (140, 80, 35))]).convert("RGBA"), (0, 0), handle)
    lay.paste(vgrad(lay.size, [(0, (226, 232, 242)), (0.5, (150, 162, 180)), (1, (96, 106, 124))]).convert("RGBA"), (0, 0), head)
    return lay


def logo_3(ring):
    """La masse : STEAL A blanc, SHOP orange, masse en travers derrière, étoile d'impact."""
    fp = font_path("FredokaOne-Regular.ttf")
    top = render_word(Word("STEAL A", fp, 180, 16, track=0.0, seed=2), SILVER, 12, ring)
    shop = render_word(Word("SHOP", fp, 330, 26, track=-0.01, seed=4), ORANGE, 20, ring)
    text = stack([top, shop], gap=-58, align="center")
    tw, th = text.size
    # masse en travers derrière le texte, assez longue pour que le manche sorte en bas à gauche
    # et la tête en haut à droite : l'œil reconstitue la masse entière
    hm = hammer(int(math.hypot(tw, th) * 1.12), ring).rotate(32, resample=Image.BICUBIC, expand=True)
    W, H = max(hm.size[0], tw) + 40, max(hm.size[1], th) + 40
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hx, hy = (W - hm.size[0]) // 2, (H - hm.size[1]) // 2
    # étoile d'impact derrière la tête de la masse
    st = Image.new("L", out.size, 0)
    cx, cy, n = int(hx + hm.size[0] * 0.86), int(hy + hm.size[1] * 0.17), 9
    pts = []
    for i in range(n * 2):
        r = 120 if i % 2 == 0 else 55
        a = math.pi * i / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    ImageDraw.Draw(st).polygon(pts, fill=255)
    out.paste(Image.new("RGBA", out.size, INK + (255,)), (0, 0), st.filter(ImageFilter.MaxFilter(15)))
    out.paste(vgrad(out.size, GOLD).convert("RGBA"), (0, 0), st)
    out.alpha_composite(hm, (hx, hy))
    out.alpha_composite(text, ((W - tw) // 2, (H - th) // 2))
    return finish(out, -3)


def checker(size, s=16):
    img = Image.new("RGB", size, (235, 235, 235))
    d = ImageDraw.Draw(img)
    for y in range(0, size[1], s):
        for x in range(0, size[0], s):
            if (x // s + y // s) % 2:
                d.rectangle((x, y, x + s - 1, y + s - 1), fill=(205, 205, 205))
    return img.convert("RGBA")


def main():
    logos = [("1", "classique", logo_1), ("2", "vitrine-cassee", logo_2), ("3", "masse", logo_3)]
    rendered = []
    for n, name, fn in logos:
        for variant, ring in (("fond-clair", 0), ("fond-sombre", 18)):
            img = fn(ring)
            img.save(os.path.join(OUT, f"LOGO_{n}_{name}_{variant}.png"))
            rendered.append((n, name, variant, img))
            print("ok", n, name, variant, img.size)
    # aperçu : 200 px de large sur 4 fonds (fond-clair sur les 2 clairs, fond-sombre sur les 2 sombres)
    bgs = [("blanc", (255, 255, 255)), ("ciel du jeu", (143, 208, 255)), ("bleu nuit UI", (44, 33, 99)), ("noir", (18, 18, 24))]
    cell_w, cell_h = 240, 170
    sheet = Image.new("RGBA", (180 + cell_w * 4, 60 + cell_h * 3), (250, 250, 252, 255))
    d = ImageDraw.Draw(sheet)
    fl = ImageFont.truetype(font_path("Montserrat-Bold.ttf"), 18)
    for j, (bn, _) in enumerate(bgs):
        d.text((180 + j * cell_w + 10, 20), bn, font=fl, fill=INK)
    for i, (n, name, fn) in enumerate(logos):
        d.text((10, 60 + i * cell_h + 70), f"{n} · {name}", font=fl, fill=INK)
        for j, (bn, col) in enumerate(bgs):
            variant = "fond-clair" if j < 2 else "fond-sombre"
            img = next(r[3] for r in rendered if r[0] == n and r[2] == variant)
            small = img.resize((200, int(img.size[1] * 200 / img.size[0])), Image.LANCZOS)
            cell = Image.new("RGBA", (cell_w - 10, cell_h - 10), col + (255,))
            cell.alpha_composite(small, ((cell.size[0] - 200) // 2, max(0, (cell.size[1] - small.size[1]) // 2)))
            sheet.alpha_composite(cell, (180 + j * cell_w, 60 + i * cell_h))
    sheet.convert("RGB").save(os.path.join(OUT, "apercu-200px.png"))
    # planche en grand sur damier (transparence visible)
    big = [r[3] for r in rendered if r[2] == "fond-sombre"]
    Wb = sum(b.size[0] for b in big) + 40 * (len(big) + 1)
    Hb = max(b.size[1] for b in big) + 80
    board = checker((Wb, Hb))
    x = 40
    for b in big:
        board.alpha_composite(b, (x, 40))
        x += b.size[0] + 40
    board.convert("RGB").resize((Wb // 2, Hb // 2), Image.LANCZOS).save(os.path.join(OUT, "planche-damier.png"))
    print("ok", OUT)


if __name__ == "__main__":
    main()

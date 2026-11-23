# Croquis rapides des 3 pistes d'icône (MOD-043, 2026-11-21).
# Ce ne sont PAS des images à publier : formes simples pour choisir une composition,
# vue à 512, 150 et 64 px. La vraie icône part d'une capture Studio.
# Lancer : py -I tools/clement/miniatures/croquis_pistes_icone.py
import glob
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "docs", "claude", "miniatures", "2026-11-21_icone")
os.makedirs(OUT, exist_ok=True)

S = 1024  # dessin à 2x, réduit à 512
INK = (27, 27, 36, 255)  # #1B1B24, contour de l'UI


def font(name, size):
    # polices libres (OFL) livrées avec Roblox Studio : Montserrat, Luckiest Guy, Fredoka One
    hits = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions", "*", "content", "fonts", name))
    return ImageFont.truetype(hits[0], size) if hits else ImageFont.load_default()


def radial_bg(c_in, c_out, center=(0.5, 0.5), power=1.4):
    img = Image.new("RGBA", (S, S))
    px = img.load()
    cx, cy = center[0] * S, center[1] * S
    maxd = math.hypot(S, S) * 0.62
    for y in range(S):
        for x in range(S):
            t = min(1.0, (math.hypot(x - cx, y - cy) / maxd)) ** power
            px[x, y] = tuple(int(c_in[i] + (c_out[i] - c_in[i]) * t) for i in range(3)) + (255,)
    return img


def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def outlined(lay, px=20, color=INK):
    a = lay.split()[3]
    for _ in range(px // 2):
        a = a.filter(ImageFilter.MaxFilter(5))
    ol = Image.new("RGBA", lay.size, color)
    ol.putalpha(a)
    return Image.alpha_composite(ol, lay)


def glow(base, center, radius, color, alpha=200, blur=60):
    g = layer()
    d = ImageDraw.Draw(g)
    x, y = center
    d.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color + (alpha,))
    g = g.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(base, g)


def rays(base, center, color, n=14, length=700, alpha=70, spread=0.11, colors=None):
    g = layer()
    d = ImageDraw.Draw(g)
    x, y = center
    for i in range(n):
        a = i / n * 2 * math.pi
        c = colors[i % len(colors)] if colors else color
        p = [(x, y),
             (x + length * math.cos(a - spread), y + length * math.sin(a - spread)),
             (x + length * math.cos(a + spread), y + length * math.sin(a + spread))]
        d.polygon(p, fill=c + (alpha,))
    g = g.filter(ImageFilter.GaussianBlur(6))
    return Image.alpha_composite(base, g)


def rot_rect(cx, cy, w, h, ang):
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def limb(d, p0, p1, w, fill):
    # bras ou jambe en bloc, de p0 à p1
    ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
    L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    d.polygon(rot_rect((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, L + w * 0.3, w, ang), fill=fill)


def face(d, cx, cy, s, mood="shout"):
    # visage Roblox simple : yeux, sourcils levés, bouche ouverte
    ew, eh = s * 0.11, s * 0.2
    for sx in (-1, 1):
        ex = cx + sx * s * 0.2
        d.rounded_rectangle((ex - ew / 2, cy - s * 0.12 - eh / 2, ex + ew / 2, cy - s * 0.12 + eh / 2), radius=ew / 2, fill=INK)
        d.line((ex - s * 0.1, cy - s * 0.33 - sx * s * 0.02, ex + s * 0.1, cy - s * 0.33 + sx * s * 0.02), fill=INK, width=int(s * 0.05))
    if mood == "shout":
        d.chord((cx - s * 0.2, cy - s * 0.05, cx + s * 0.2, cy + s * 0.33), 0, 180, fill=(120, 20, 30, 255))
        d.chord((cx - s * 0.2, cy - s * 0.05, cx + s * 0.2, cy + s * 0.33), 0, 180, outline=INK, width=int(s * 0.03))
    else:  # grand sourire
        d.chord((cx - s * 0.24, cy - s * 0.02, cx + s * 0.24, cy + s * 0.3), 0, 180, fill=(120, 20, 30, 255))


def shards(d, center, n, rmin, rmax, seed, size=(18, 60), col=(200, 235, 255), arc=(0, 360)):
    rnd = random.Random(seed)
    cx, cy = center
    for _ in range(n):
        a = math.radians(rnd.uniform(*arc))
        r = rnd.uniform(rmin, rmax)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        s = rnd.uniform(*size)
        rot = rnd.uniform(0, 360)
        pts = [(x + s * math.cos(math.radians(rot + k * 120 + rnd.uniform(-25, 25))),
                y + s * math.sin(math.radians(rot + k * 120 + rnd.uniform(-25, 25)))) for k in range(3)]
        d.polygon(pts, fill=col + (235,), outline=(255, 255, 255, 255), width=3)


def star(d, c, r1, r2, n, fill):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.pi * i / n - math.pi / 2
        pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
    d.polygon(pts, fill=fill)


def crown(d, cx, cy, w):
    h = w * 0.62
    gold, dark = (255, 194, 26, 255), (214, 140, 0, 255)
    top = cy - h / 2
    pts = [(cx - w / 2, cy + h / 2), (cx - w / 2, top + h * 0.25), (cx - w * 0.27, top + h * 0.55),
           (cx, top), (cx + w * 0.27, top + h * 0.55), (cx + w / 2, top + h * 0.25), (cx + w / 2, cy + h / 2)]
    d.polygon(pts, fill=gold)
    d.rectangle((cx - w / 2, cy + h * 0.22, cx + w / 2, cy + h / 2), fill=dark)
    for gx, col in ((-0.3, (47, 155, 255, 255)), (0, (255, 59, 92, 255)), (0.3, (47, 225, 143, 255))):
        d.ellipse((cx + gx * w - w * 0.07, cy + h * 0.29, cx + gx * w + w * 0.07, cy + h * 0.45), fill=col)
    for bx, by in ((-0.5, 0.25), (0, 0), (0.5, 0.25)):
        r = w * 0.06
        d.ellipse((cx + bx * w - r, top + by * h - r, cx + bx * w + r, top + by * h + r), fill=gold)
    d.polygon([(cx - w * 0.38, top + h * 0.42), (cx - w * 0.3, top + h * 0.42), (cx - w * 0.3, cy + h * 0.15), (cx - w * 0.38, cy + h * 0.15)], fill=(255, 240, 170, 255))


def piste_a():
    img = radial_bg((170, 225, 255), (25, 85, 160), center=(0.62, 0.42))
    img = rays(img, (700, 420), (255, 255, 255), n=16, alpha=45)
    img = glow(img, (705, 420), 210, (168, 85, 247), alpha=230, blur=70)  # halo Épique de la Couronne
    obj = layer(); d = ImageDraw.Draw(obj)
    crown(d, 705, 420, 330)
    img = Image.alpha_composite(img, outlined(obj, 18))
    # vitre qui explose depuis le point d'impact
    g = layer(); d = ImageDraw.Draw(g)
    impact = (585, 560)
    for k in range(14):
        a = math.radians(k * 360 / 14 + 7)
        d.line((impact, (impact[0] + 420 * math.cos(a), impact[1] + 420 * math.sin(a))), fill=(255, 255, 255, 170), width=5)
    shards(d, impact, 46, 60, 430, seed=4, size=(16, 58))
    img = Image.alpha_composite(img, g)
    fl = layer(); d = ImageDraw.Draw(fl)
    star(d, impact, 150, 40, 8, (255, 255, 255, 235))
    img = Image.alpha_composite(img, fl.filter(ImageFilter.GaussianBlur(3)))
    # perso de trois quarts, masse à l'impact
    ch = layer(); d = ImageDraw.Draw(ch)
    hood, skin, pants = (255, 106, 42, 255), (245, 205, 48, 255), (40, 52, 90, 255)
    limb(d, (250, 760), (205, 1010), 95, pants)
    limb(d, (330, 760), (380, 1010), 95, pants)
    d.polygon(rot_rect(290, 650, 230, 260, 8), fill=hood)
    limb(d, (360, 560), (520, 560), 82, hood)  # bras avant
    limb(d, (230, 570), (470, 600), 82, hood)  # bras arrière
    d.polygon(rot_rect(285, 405, 190, 175, 6), fill=skin)
    d.polygon(rot_rect(282, 330, 200, 70, 6), fill=(30, 30, 40, 255))  # bonnet
    face(d, 300, 420, 175)
    # masse : manche bois + tête acier, à l'impact
    limb(d, (440, 600), (560, 560), 26, (150, 90, 40, 255))
    d.polygon(rot_rect(575, 555, 70, 140, -18), fill=(120, 130, 145, 255))
    d.polygon(rot_rect(590, 550, 22, 120, -18), fill=(190, 200, 215, 255))
    img = Image.alpha_composite(img, outlined(ch, 20))
    return img


def piste_b():
    img = radial_bg((255, 150, 190), (90, 20, 80), center=(0.5, 0.35))
    img = rays(img, (512, 330), (255, 210, 225), n=18, alpha=55)
    img = glow(img, (512, 330), 300, (255, 59, 92), alpha=210, blur=80)  # halo Mythique
    # objet colossal porté au-dessus de la tête : coffre de diamants
    obj = layer(); d = ImageDraw.Draw(obj)
    d.rounded_rectangle((250, 250, 774, 520), radius=30, fill=(120, 60, 25, 255))
    d.rectangle((250, 330, 774, 360), fill=(255, 194, 26, 255))
    d.rectangle((490, 330, 534, 420), fill=(255, 194, 26, 255))
    rnd = random.Random(2)
    for _ in range(26):
        x, y, s = rnd.uniform(280, 744), rnd.uniform(140, 270), rnd.uniform(30, 55)
        d.polygon([(x, y - s), (x + s * 0.8, y), (x, y + s * 0.9), (x - s * 0.8, y)], fill=rnd.choice([(150, 230, 255, 255), (255, 255, 255, 255), (110, 200, 255, 255)]))
    img = Image.alpha_composite(img, outlined(obj, 18))
    # perso qui court vers nous, bras levés
    ch = layer(); d = ImageDraw.Draw(ch)
    hood, skin, pants = (47, 155, 255, 255), (245, 205, 48, 255), (40, 52, 90, 255)
    limb(d, (440, 520), (390, 360), 80, hood)
    limb(d, (590, 520), (640, 360), 80, hood)
    limb(d, (470, 830), (420, 1010), 95, pants)
    limb(d, (555, 830), (610, 960), 95, pants)
    d.rectangle((400, 700, 625, 860), fill=hood)
    d.polygon(rot_rect(512, 610, 200, 180, 0), fill=skin)
    face(d, 512, 625, 180, mood="shout")
    img = Image.alpha_composite(img, outlined(ch, 20))
    g = layer(); d = ImageDraw.Draw(g)
    shards(d, (512, 880), 30, 120, 420, seed=7, size=(14, 40), arc=(180, 360))
    img = Image.alpha_composite(img, g)
    # vigile surpris, à droite
    gd = layer(); d = ImageDraw.Draw(gd)
    d.rectangle((790, 690, 900, 800), fill=(30, 45, 80, 255))
    d.rectangle((800, 600, 890, 690), fill=(245, 205, 48, 255))
    d.rectangle((790, 585, 900, 615), fill=(20, 30, 60, 255))
    d.text((910, 520), "!", font=font("LuckiestGuy-Regular.ttf", 130), fill=(255, 59, 59, 255))
    img = Image.alpha_composite(img, outlined(gd, 12))
    return img


def piste_c():
    img = radial_bg((90, 60, 170), (20, 12, 45), center=(0.55, 0.45))
    rainbow = [(255, 59, 59), (255, 194, 26), (59, 225, 90), (47, 155, 255), (168, 85, 247)]
    img = rays(img, (560, 440), None, n=20, alpha=95, colors=rainbow, spread=0.09)
    img = glow(img, (560, 440), 250, (255, 230, 150), alpha=170, blur=70)
    # chat porte-bonheur doré (Secret)
    obj = layer(); d = ImageDraw.Draw(obj)
    gold, dark = (255, 194, 26, 255), (214, 140, 0, 255)
    d.ellipse((380, 420, 740, 760), fill=gold)  # corps
    d.ellipse((400, 200, 720, 480), fill=gold)  # tête
    d.polygon([(420, 280), (450, 150), (530, 230)], fill=gold)
    d.polygon([(700, 280), (670, 150), (590, 230)], fill=gold)
    d.rounded_rectangle((690, 230, 790, 470), radius=45, fill=gold)  # patte levée
    for ex in (500, 620):
        d.arc((ex - 35, 300, ex + 35, 360), 200, 340, fill=INK, width=14)
    d.ellipse((545, 370, 575, 395), fill=(255, 120, 140, 255))
    d.ellipse((500, 560, 620, 680), fill=dark)
    d.ellipse((520, 580, 600, 660), fill=gold)
    img = Image.alpha_composite(img, outlined(obj, 18))
    # vitre fissurée devant, impact en bas à gauche + masse qui entre
    g = layer(); d = ImageDraw.Draw(g)
    d.rectangle((0, 0, S, S), fill=(200, 235, 255, 40))
    impact = (330, 720)
    rnd = random.Random(3)
    for k in range(16):
        a = math.radians(k * 360 / 16 + rnd.uniform(-8, 8))
        pts = [impact]
        r = 0
        while r < 700:
            r += rnd.uniform(60, 120)
            pts.append((impact[0] + r * math.cos(a + rnd.uniform(-0.08, 0.08)), impact[1] + r * math.sin(a + rnd.uniform(-0.08, 0.08))))
        d.line(pts, fill=(255, 255, 255, 220), width=6)
    for r in (90, 180):
        d.ellipse((impact[0] - r, impact[1] - r, impact[0] + r, impact[1] + r), outline=(255, 255, 255, 160), width=4)
    shards(d, impact, 22, 30, 260, seed=5, size=(12, 40))
    img = Image.alpha_composite(img, g)
    h = layer(); d = ImageDraw.Draw(h)
    limb(d, (60, 960), (250, 790), 34, (150, 90, 40, 255))
    d.polygon(rot_rect(290, 760, 90, 170, 42), fill=(120, 130, 145, 255))
    img = Image.alpha_composite(img, outlined(h, 18))
    return img


def rounded(img, r):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius=r, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out


def main():
    pistes = [("A · La casse", "perso + masse, vitre qui explose, Couronne (Épique)", piste_a()),
              ("B · Le butin colossal", "objet Mythique Colossal porté, vigile surpris", piste_b()),
              ("C · Le trésor derrière la vitre", "Secret arc-en-ciel, vitre fissurée, masse", piste_c())]
    W, H = 3 * 560 + 40, 820
    sheet = Image.new("RGBA", (W, H), (245, 246, 250, 255))
    d = ImageDraw.Draw(sheet)
    ft, fs = font("Montserrat-Black.ttf", 30), font("Montserrat-Bold.ttf", 19)
    for i, (title, sub, im) in enumerate(pistes):
        x0 = 40 + i * 560
        t512 = im.resize((512, 512), Image.LANCZOS)
        t512.convert("RGB").save(os.path.join(OUT, f"croquis_{title[0]}_512.png"))
        sheet.alpha_composite(rounded(t512, 46), (x0, 100))
        t150 = rounded(t512.resize((150, 150), Image.LANCZOS), 14)
        t64 = rounded(t512.resize((64, 64), Image.LANCZOS), 7)
        sheet.alpha_composite(t150, (x0, 640))
        sheet.alpha_composite(t64, (x0 + 175, 726))
        d.text((x0, 30), title, font=ft, fill=INK)
        d.text((x0, 68), sub, font=fs, fill=(80, 80, 95, 255))
        d.text((x0 + 175, 650), "150 px et 64 px", font=fs, fill=(80, 80, 95, 255))
    sheet.convert("RGB").save(os.path.join(OUT, "croquis-pistes.png"))
    print("ok", OUT)


if __name__ == "__main__":
    main()

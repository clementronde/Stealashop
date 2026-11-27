# -*- coding: utf-8 -*-
"""Icônes des offres Robux et des badges de Steal a Shop (L-352, 2026-11-26).

Toutes les images : 512 x 512, PNG transparent.
  - gamepasses et produits : le sceau dentelé de UI_Icon_GP_x2Cash.png (22 dents, contour 14142B,
    anneau, reflet), dans la couleur de la carte ;
  - badges : la médaille ronde à studs de BADGE_Legendary (essai validé le 26/11).
Le dessin est fait à 4 fois la taille puis réduit. La pile de billets, les coffres, l'aimant,
le chronomètre, le présentoir, le sac, le cadenas ouvert, l'éclair et les éclats sont dessinés ici ;
les autres symboles sont les images du dossier StealAShop-Art (voir SOURCES).

Relançable : python -P build_offres.py [morceau du nom ...]   (Pillow + numpy seulement)
  sans argument : toutes les images, puis PLANCHE_offres_completes.png
  --pile-test   : planche de contrôle de la pile (dans _src)
"""
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

sys.dont_write_bytecode = True

# ---------------------------------------------------------------- chemins
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)                      # ...\icones\offres_2026-11-26
ICONES = os.path.dirname(OUT)                    # ...\icones (lecture seule)
ESSAIS = os.path.join(ICONES, "essais_2026-11-26")
ART = r"C:\Users\Charment\Documents\StealAShop-Art"
FONT = os.path.join(ART, r"Video\Trailer\_outils\Montserrat-Black.ttf")
FONT_LABEL = r"C:\Windows\Fonts\segoeuib.ttf"
SRC = {
    "cash": r"UI\_A_importer\UI_Icon_Cash.png",
    "speed": r"UI\_A_importer\UI_Icon_Speed.png",
    "lock": r"UI\Figma_a_importer\22_Icon_Lock.png",
    "hammer": r"UI\_A_importer\UI_Icon_Damage.png",
    "house": r"UI\_A_importer\UI_Icon_Base.png",
    "rebirth": r"UI\_A_importer\UI_Icon_Rebirth.png",
    "ingot": r"UI\Figma_a_importer\19_Tab_Zone6.png",
    "box_common": r"Boxes\Icons\ToImport\ICON_BOX_Common.png",
    "box_mythic": r"Boxes\Icons\ToImport\ICON_BOX_Mythic.png",
    "box_secret": r"Boxes\Icons\ToImport\ICON_BOX_Secret.png",
    "display": r"UI\Images_UI_groupe\UI_Btn_Icon_Display.png",
}
REF_X2 = os.path.join(ICONES, "UI_Icon_GP_x2Cash.png")

N = 512
SS = 4
B = N * SS
C = 256.0

SEAL_DARK = (0x14, 0x14, 0x2B)
NAVY = (0x04, 0x04, 0x35)
WHITE = (255, 255, 255)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(c, d, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c, d))


def S(v):
    return v * SS


# ---------------------------------------------------------------- calques
def new_layer(size=B):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def down(layer, size=N):
    return layer.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")


def fill_mask(layer, mask, color, alpha=1.0):
    if alpha < 1.0:
        mask = mask.point(lambda v: int(v * alpha))
    if isinstance(color, Image.Image):
        src = color.convert("RGB").copy()
    else:
        src = Image.new("RGB", layer.size, tuple(color))
    src.putalpha(mask)
    layer.alpha_composite(src)


def vgrad_arr(base_arr, t_top, t_bot, size=B, to=WHITE):
    """base_arr : (size,size,3) ou (3,) ; mêle vers `to` de t_top (haut) à t_bot (bas)."""
    ys = (np.arange(size) + 0.5) / (size / N)
    t = (t_top + (t_bot - t_top) * ys / N)[:, None, None]
    b = np.broadcast_to(np.asarray(base_arr, float), (size, size, 3))
    return b + (np.array(to, float) - b) * t


def to_img(arr):
    return Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8), "RGB")


def vgrad(base, t_top, t_bot):
    return to_img(vgrad_arr(base, t_top, t_bot))


def circle_mask(r, cx=C, cy=C, size=B):
    m = Image.new("L", (size, size), 0)
    k = size / N
    ImageDraw.Draw(m).ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], fill=255)
    return m


def poly_mask(pts, size=B):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def mask_sub(a, b):
    return Image.fromarray(np.clip(np.array(a, int) - np.array(b, int), 0, 255).astype(np.uint8), "L")


def mask_mul(a, b):
    return Image.fromarray((np.array(a, np.uint16) * np.array(b, np.uint16) // 255).astype(np.uint8), "L")


def stroke_poly(draw, pts, w, fill):
    """Polygone + contour arrondi d'épaisseur w (somme de Minkowski avec un disque)."""
    draw.polygon(pts, fill=fill)
    draw.line(list(pts) + [pts[0]], fill=fill, width=max(1, int(round(2 * w))), joint="curve")
    for (x, y) in pts:
        draw.ellipse([x - w, y - w, x + w, y + w], fill=fill)


def dot(d, p, r, fill=WHITE):
    d.ellipse([p[0] - S(r), p[1] - S(r), p[0] + S(r), p[1] + S(r)], fill=fill)


def seg(d, a, b, w, fill=WHITE):
    """Trait à bouts ronds (a, b en espace SS, w en 512)."""
    d.line([a, b], fill=fill, width=int(S(w)))
    dot(d, a, w / 2, fill)
    dot(d, b, w / 2, fill)


# ---------------------------------------------------------------- sceau dentelé (mesuré sur x2Cash)
SEAL_PHI = np.arange(0, 8.01, 0.5).tolist() + [360 / 44]
SEAL_IN = [215.1, 213.8, 211.55, 209.5, 207.6, 205.45, 203.5, 201.8, 200.5, 199.5,
           198.6, 197.9, 197.2, 196.85, 196.45, 196.25, 196.15, 196.15]
SEAL_OUT = [232.2, 232.0, 231.55, 230.8, 229.8, 228.2, 226.3, 224.25, 222.0, 220.0,
            218.05, 216.2, 214.4, 213.15, 212.25, 211.75, 211.6, 211.6]
RING = (174.5, 180.5)
RING_ALPHA = 0.35
HL = dict(cx=236, cy=129, a=110, b=35, alpha=0.28)
BAND_T = (0.357, 0.357 - 0.000714 * N)
DISC_T = (0.40, 0.40 - 0.00027 * N)


def seal_pts(table, n_per_tooth=240):
    P = 360 / 22
    th = np.linspace(0, 360, 22 * n_per_tooth, endpoint=False)
    ph = np.abs(((th - 90 + P / 2) % P) - P / 2)
    r = np.interp(ph, SEAL_PHI, table)
    x = (C + r * np.cos(np.radians(th))) * SS
    y = (C - r * np.sin(np.radians(th))) * SS
    return list(zip(x.tolist(), y.tolist()))


def highlight_mask(clip):
    m = Image.new("L", (B, B), 0)
    h = HL
    ImageDraw.Draw(m).ellipse([S(h["cx"] - h["a"]), S(h["cy"] - h["b"]),
                               S(h["cx"] + h["a"]), S(h["cy"] + h["b"])], fill=255)
    return mask_mul(m, clip)


def glow_mask(cx, cy, r, clip):
    yy, xx = np.mgrid[0:B, 0:B]
    d = np.hypot(xx / SS - cx, yy / SS - cy) / r
    del yy, xx
    g = np.clip(1.0 - d, 0, 1) ** 1.6
    return Image.fromarray((g * np.array(clip, float)).astype(np.uint8), "L")


def rays_mask(cx, cy, n, phase, clip, r_fade=(60, 190)):
    m = Image.new("L", (B, B), 0)
    d = ImageDraw.Draw(m)
    R = 600
    for k in range(n):
        a0 = math.radians(phase + 360 * k / n)
        a1 = math.radians(phase + 360 * (k + 0.5) / n)
        d.polygon([(S(cx), S(cy)), (S(cx + R * math.cos(a0)), S(cy + R * math.sin(a0))),
                   (S(cx + R * math.cos(a1)), S(cy + R * math.sin(a1)))], fill=255)
    yy, xx = np.mgrid[0:B, 0:B]
    rr = np.hypot(xx / SS - cx, yy / SS - cy)
    fade = np.clip(1.0 - (rr - r_fade[0]) / (r_fade[1] - r_fade[0]), 0.25, 1.0)
    del yy, xx, rr
    return Image.fromarray((np.array(m, float) * fade * (np.array(clip, float) / 255)).astype(np.uint8), "L")


def inner_parts(L, base, band_mask, disc_t=DISC_T, glow=None, rays=None):
    """Disque clair (passe sous l'anneau), lueur, rayons, anneau sombre, reflet (comme x2Cash)."""
    disc = circle_mask(RING[1])
    fill_mask(L, disc, vgrad(base, *disc_t))
    if glow:
        fill_mask(L, glow_mask(glow[0], glow[1], glow[2], disc), WHITE, glow[3])
    if rays:
        fill_mask(L, rays_mask(rays[0], rays[1], rays[2], rays[3], disc, rays[5]), WHITE, rays[4])
    fill_mask(L, mask_sub(disc, circle_mask(RING[0])), SEAL_DARK, RING_ALPHA)
    fill_mask(L, highlight_mask(band_mask), WHITE, HL["alpha"])


def seal_layer(base, glow=None):
    """Sceau des gamepasses et des produits (identique à x2Cash, couleur au choix)."""
    base = hexrgb(base)
    L = new_layer()
    fill_mask(L, poly_mask(seal_pts(SEAL_OUT)), SEAL_DARK)
    band = poly_mask(seal_pts(SEAL_IN))
    fill_mask(L, band, vgrad(base, *BAND_T))
    inner_parts(L, base, band, glow=glow)
    return down(L)


# ---------------------------------------------------------------- médaille à studs (badges, cf. BADGE_Legendary)
MED = dict(outer=232.0, band=214.0, studs=28, stud_r=8.6, stud_at=197.3)
MED_DISC_T = (0.60, 0.40)


def conic_arr(colors, size=B):
    """Couleur qui tourne autour du centre (arc-en-ciel), départ en haut, sens horaire."""
    yy, xx = np.mgrid[0:size, 0:size]
    ang = (np.degrees(np.arctan2(xx / SS - C, -(yy / SS - C))) % 360) / 360.0
    del yy, xx
    cols = np.array([hexrgb(c) for c in colors] + [hexrgb(colors[0])], float)
    pos = ang * (len(colors))
    i = np.floor(pos).astype(int) % len(colors)
    f = (pos - np.floor(pos))[..., None]
    f = f * f * (3 - 2 * f)
    return cols[i] * (1 - f) + cols[i + 1] * f


def medal_layer(base, rainbow=None):
    """base : couleur du bord ; rainbow : liste de couleurs pour un bord arc-en-ciel."""
    L = new_layer()
    fill_mask(L, circle_mask(MED["outer"]), SEAL_DARK)
    band = circle_mask(MED["band"])
    if rainbow:
        col = conic_arr(rainbow)
        disc_base = np.array(hexrgb("FFE9A8"), float)
    else:
        col = np.array(hexrgb(base), float)
        disc_base = col
    fill_mask(L, band, to_img(vgrad_arr(col, *BAND_T)))
    sh = Image.new("L", (B, B), 0)
    body = Image.new("L", (B, B), 0)
    lit = Image.new("L", (B, B), 0)
    ds, db, dl = ImageDraw.Draw(sh), ImageDraw.Draw(body), ImageDraw.Draw(lit)
    rr = MED["stud_r"]
    for k in range(MED["studs"]):
        a = math.radians(90 + 360 * k / MED["studs"])
        x, y = C + MED["stud_at"] * math.cos(a), C - MED["stud_at"] * math.sin(a)
        ds.ellipse([S(x - rr + 1.4), S(y - rr + 2.2), S(x + rr + 1.4), S(y + rr + 2.2)], fill=255)
        db.ellipse([S(x - rr), S(y - rr), S(x + rr), S(y + rr)], fill=255)
        dl.ellipse([S(x - rr), S(y - rr), S(x + rr), S(y + rr)], fill=255)
        dl.ellipse([S(x - rr + 2.0), S(y - rr + 2.4), S(x + rr + 2.0), S(y + rr + 2.4)], fill=0)
    dark = np.broadcast_to(col, (B, B, 3)) * 0.58 + np.array(SEAL_DARK, float) * 0.42
    fill_mask(L, sh, to_img(dark))
    fill_mask(L, body, to_img(vgrad_arr(col, 0.50, 0.16)))
    fill_mask(L, lit, WHITE, 0.75)
    disc = circle_mask(RING[1])
    fill_mask(L, disc, to_img(vgrad_arr(disc_base, *MED_DISC_T)))
    fill_mask(L, glow_mask(256, 262, 175, disc), WHITE, 0.55)
    fill_mask(L, rays_mask(256, 266, 16, 0, disc, (60, 190)), WHITE, 0.30)
    fill_mask(L, mask_sub(disc, circle_mask(RING[0])), SEAL_DARK, RING_ALPHA)
    fill_mask(L, highlight_mask(band), WHITE, HL["alpha"])
    return down(L)


# ---------------------------------------------------------------- chiffres (style ×2)
LBL = dict(size=145, stroke=20, shadow=(-5, 9), angle=8)


def label_layer(text, size=None, stroke=None, angle=None, track=0.0, lines=None):
    """Montserrat Black blanc, contour 14142B, ombre pleine, penché de 8°.
    lines : [(texte, taille)] pour un libellé sur deux lignes (centrées).
    Rend (calque SS, ancrage = centre du blanc en unités 512)."""
    angle = LBL["angle"] if angle is None else angle
    stroke = LBL["stroke"] if stroke is None else stroke
    if lines is None:
        lines = [(text, size or LBL["size"])]
    sw = int(stroke * SS)
    pad = int((stroke + 30) * SS)
    rows = []
    for (t, sz) in lines:
        f = ImageFont.truetype(FONT, int(sz * SS))
        xs, x = [], 0.0
        for ch in t:
            xs.append(x)
            x += f.getlength(ch) + track * SS
        bb = f.getbbox(t)
        rows.append((t, f, xs, x, bb))
    W = int(max(r[3] for r in rows) + 2 * pad)
    gap = int(0.06 * lines[0][1] * SS)
    H = int(sum(r[4][3] - r[4][1] for r in rows) + gap * (len(rows) - 1) + 2 * pad)
    fillw = Image.new("L", (W, H), 0)
    full = Image.new("L", (W, H), 0)
    dw, df = ImageDraw.Draw(fillw), ImageDraw.Draw(full)
    y = pad
    for (t, f, xs, wid, bb) in rows:
        x0 = (W - wid) / 2
        for ch, xx in zip(t, xs):
            df.text((x0 + xx, y - bb[1]), ch, font=f, fill=255, stroke_width=sw, stroke_fill=255)
            dw.text((x0 + xx, y - bb[1]), ch, font=f, fill=255)
        y += (bb[3] - bb[1]) + gap
    fillw = fillw.rotate(angle, resample=Image.BICUBIC, expand=True)
    full = full.rotate(angle, resample=Image.BICUBIC, expand=True)
    sx, sy = int(LBL["shadow"][0] * SS), int(LBL["shadow"][1] * SS)
    pad2 = int(20 * SS)
    out = Image.new("RGBA", (full.width + 2 * pad2, full.height + 2 * pad2), (0, 0, 0, 0))
    sil = Image.new("RGBA", full.size, SEAL_DARK + (0,))
    sil.putalpha(full)
    out.alpha_composite(sil, (pad2 + sx, pad2 + sy))
    out.alpha_composite(sil, (pad2, pad2))
    wt = Image.new("RGBA", full.size, WHITE + (0,))
    wt.putalpha(fillw)
    out.alpha_composite(wt, (pad2, pad2))
    bb = fillw.getbbox()
    return out, ((pad2 + (bb[0] + bb[2]) / 2) / SS, (pad2 + (bb[1] + bb[3]) / 2) / SS)


def place_ss(canvas_ss, layer_ss, center_512, anchor_512):
    x = int(round(S(center_512[0] - anchor_512[0])))
    y = int(round(S(center_512[1] - anchor_512[1])))
    cx0, cy0 = max(0, -x), max(0, -y)
    canvas_ss.alpha_composite(layer_ss.crop((cx0, cy0, layer_ss.width, layer_ss.height)), (max(0, x), max(0, y)))


R_SAFE = 248.0     # rien au-delà : Roblox découpe les gamepasses et les badges en cercle (r = 256)


def label_rmax(lay, anc, center):
    a = np.array(lay.getchannel("A"))[::4, ::4] > 80
    ys, xs = np.nonzero(a)
    X = xs * 4 / SS + center[0] - anc[0]
    Y = ys * 4 / SS + center[1] - anc[1]
    return float(np.hypot(X - C, Y - C).max())


def add_label(top, text, center, **kw):
    """Pose le libellé à `center` ; s'il sort du cercle sûr, le rapproche du centre puis le réduit."""
    size = kw.pop("size", None) or LBL["size"]
    lines = kw.get("lines")
    for _ in range(12):
        if lines:
            kw["lines"] = [(t, sz * size / LBL["size"]) for (t, sz) in lines]
        lay, anc = label_layer(text, size=size, **kw)
        cx, cy = center
        for _ in range(10):
            if label_rmax(lay, anc, (cx, cy)) <= R_SAFE:
                place_ss(top, lay, (cx, cy), anc)
                return
            cx, cy = cx - 3.0, cy - 3.0
        size *= 0.95
    place_ss(top, lay, (cx, cy), anc)


# ---------------------------------------------------------------- petits dessins communs
def sparkle(draw, cx, cy, R, fill=(0xFF, 0xF4, 0xC8), outline=NAVY, ow=4.5, k=2.6):
    pts = []
    for i in range(96):
        t = 2 * math.pi * i / 96
        c, s_ = math.cos(t), math.sin(t)
        pts.append((S(cx + R * math.copysign(abs(c) ** k, c)), S(cy + R * math.copysign(abs(s_) ** k, s_))))
    stroke_poly(draw, pts, S(ow), outline)
    draw.polygon(pts, fill=fill)


GOLD_SPARK = hexrgb("FFD84A")


def xf(pts, cx, cy, ang, sc=1.0, off=(0.0, 0.0)):
    a = math.radians(ang)
    c, s_ = math.cos(a), math.sin(a)
    return [(S(cx + (x * c - y * s_) * sc + off[0]), S(cy + (x * s_ + y * c) * sc + off[1])) for x, y in pts]


def arc_pts(r, a0, a1, n=48, rx=None):
    rx = r if rx is None else rx
    return [(rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             -r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def capsule(draw, p0, p1, w, ow=4.5, fill=WHITE):
    a = [(S(p0[0]), S(p0[1])), (S(p1[0]), S(p1[1]))]
    for width, col in ((w + 2 * ow, NAVY), (w, fill)):
        r = S(width / 2)
        draw.line(a, fill=col, width=int(S(width)))
        for (x, y) in a:
            draw.ellipse([x - r, y - r, x + r, y + r], fill=col)


def speed_lines(draw, specs, w=8.0, ow=4.5):
    """specs : [(x0, y0, x1, y1)] ; traits de vitesse blancs à bouts ronds, contour bleu nuit.
    Les contours d'abord, puis le blanc, pour que les traits voisins ne se coupent pas."""
    for (x0, y0, x1, y1) in specs:
        a = [(S(x0), S(y0)), (S(x1), S(y1))]
        r = S(w / 2 + ow)
        draw.line(a, fill=NAVY, width=int(S(w + 2 * ow)))
        for (x, y) in a:
            draw.ellipse([x - r, y - r, x + r, y + r], fill=NAVY)
    for (x0, y0, x1, y1) in specs:
        a = [(S(x0), S(y0)), (S(x1), S(y1))]
        r = S(w / 2)
        draw.line(a, fill=WHITE, width=int(S(w)))
        for (x, y) in a:
            draw.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)


def convex_hull(pts):
    pts = sorted(set(pts))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


# ---------------------------------------------------------------- vue iso (pile, coffres)
class Iso:
    """Projection axonométrique : yaw autour de la verticale, pitch de la caméra. Unités du monde
    -> pixels 512 par `s`. Faces visibles : dessus, +x (côté, sombre), +y (face avant, moyenne)."""

    def __init__(self, cx, cy, s, yaw=36.0, pitch=36.0):
        self.cx, self.cy, self.s = cx, cy, s
        a, t = math.radians(yaw), math.radians(pitch)
        self.ca, self.sa, self.st, self.ct = math.cos(a), math.sin(a), math.sin(t), math.cos(t)

    def p(self, x, y, z):
        u = x * self.ca - y * self.sa
        v = x * self.sa + y * self.ca
        return (S(self.cx + u * self.s), S(self.cy + (v * self.st - z * self.ct) * self.s))

    def depth(self, x, y, z):
        return (x * self.sa + y * self.ca) * self.ct + z * self.st


# couleurs de UI_Icon_Cash
CASH = dict(top=hexrgb("39B54A"), top_hi=hexrgb("6FD45B"), front=hexrgb("009245"), front_st=hexrgb("39B54A"),
            side=hexrgb("006837"), side_st=hexrgb("008A43"), band_top=hexrgb("FDBC0D"),
            band_hi=hexrgb("FEE854"), band_front=hexrgb("FC9504"), band_side=hexrgb("D97A00"))
BUNDLE = (1.75, 1.0, 0.92)     # longueur, largeur, épaisseur d'une liasse (unités du monde)
YAW, PITCH = 38.0, 30.0


def obox(iso, cx, cy, z0, L, W, H, rot):
    """Boîte tournée de `rot` degrés autour de la verticale. Rend les coins (bas, haut) en monde."""
    r = math.radians(rot)
    c, s_ = math.cos(r), math.sin(r)
    loc = [(-L / 2, -W / 2), (L / 2, -W / 2), (L / 2, W / 2), (-L / 2, W / 2)]
    base = [(cx + x * c - y * s_, cy + x * s_ + y * c) for x, y in loc]
    return base, (c, s_)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def quad(iso, p0, p1, za, zb):
    """Bande verticale du mur p0 -> p1 (points du sol) entre za et zb."""
    P = iso.p
    return [P(p0[0], p0[1], za), P(p1[0], p1[1], za), P(p1[0], p1[1], zb), P(p0[0], p0[1], zb)]


def bundle_hull(iso, cx, cy, z0, rot, dims=BUNDLE):
    L, W, H = dims
    base, _ = obox(iso, cx, cy, z0, L, W, H, rot)
    return convex_hull([iso.p(x, y, z) for (x, y) in base for z in (z0, z0 + H)])


def draw_bundle(d, iso, cx, cy, z0, rot=0.0, ow_in=5.0, dims=BUNDLE, pal=CASH, glint=True):
    """Une liasse : dessus clair, murs à rayures (côté éclairé moyen, côté loin sombre), bande jaune-orange."""
    L, W, H = dims
    P = iso.p
    base, (c, s_) = obox(iso, cx, cy, z0, L, W, H, rot)
    z1 = z0 + H
    stroke_poly(d, bundle_hull(iso, cx, cy, z0, rot, dims), S(ow_in), NAVY)
    cam = (iso.sa, iso.ca)
    # murs : (coin a, coin b, normale, est-ce un grand côté ?)
    walls = [(base[0], base[1], (s_, -c), True), (base[1], base[2], (c, s_), False),
             (base[2], base[3], (-s_, c), True), (base[3], base[0], (-c, -s_), False)]
    for (a, b, n, long_) in walls:
        if n[0] * cam[0] + n[1] * cam[1] <= 0:
            continue
        u = n[0] * iso.ca - n[1] * iso.sa            # >0 : le mur regarde vers la droite de l'écran
        lit = u < 0.25
        col, st = (pal["front"], pal["front_st"]) if lit else (pal["side"], pal["side_st"])
        d.polygon(quad(iso, a, b, z0, z1), fill=col)
        for k in range(3):
            za = z0 + H * (0.17 + 0.25 * k)
            d.polygon(quad(iso, a, b, za, za + H * 0.085), fill=st)
        if long_:
            t0, t1 = 0.5 - 0.085, 0.5 + 0.085
            if a is base[2]:                          # le mur est parcouru dans l'autre sens
                t0, t1 = 1 - t1, 1 - t0
            d.polygon(quad(iso, lerp(a, b, t0), lerp(a, b, t1), z0, z1),
                      fill=pal["band_front"] if lit else pal["band_side"])
    top = [P(x, y, z1) for (x, y) in base]
    d.polygon(top, fill=pal["top"])
    # liseré clair du billet, le long du grand côté arrière
    def tp(fx, fy):   # point du dessus en coordonnées locales (fx, fy dans [-0.5, 0.5])
        x, y = fx * L, fy * W
        return P(cx + x * c - y * s_, cy + x * s_ + y * c, z1)
    d.polygon([tp(-0.42, -0.34), tp(0.42, -0.34), tp(0.42, -0.22), tp(-0.42, -0.22)], fill=pal["top_hi"])
    d.polygon([tp(-0.085, -0.5), tp(0.085, -0.5), tp(0.085, 0.5), tp(-0.085, 0.5)], fill=pal["band_top"])
    for f0, f1 in ((-0.36, -0.16), (0.02, 0.12)):
        d.polygon([tp(-0.085, f0), tp(0.085, f0 - 0.14), tp(0.085, f1 - 0.14), tp(-0.085, f1)], fill=pal["band_hi"])
    if glint:
        # reflet blanc près du coin le plus à gauche du dessus, le long de l'arête avant
        i = min(range(4), key=lambda k: top[k][0])
        nb = [top[(i - 1) % 4], top[(i + 1) % 4]]
        j = max(nb, key=lambda q: q[1])
        a = lerp(top[i], j, 0.10)
        b = lerp(top[i], j, 0.34)
        inset = lerp(top[i], top[(i + 2) % 4], 0.07)
        dx, dy = inset[0] - top[i][0], inset[1] - top[i][1]
        a, b = (a[0] + dx, a[1] + dy), (b[0] + dx, b[1] + dy)
        k = iso.s / 60
        seg(d, a, b, 3.4 * k)
        q = lerp(top[i], j, 0.43)
        dot(d, (q[0] + dx, q[1] + dy), 1.9 * k)


def draw_bundles(layer, iso, spots, ow_out=9.0, ow_in=5.0, dims=BUNDLE):
    """spots : [(cx, cy, z0, rot)] ; contour extérieur épais commun, puis liasses de l'arrière vers l'avant."""
    d = ImageDraw.Draw(layer)
    for (cx, cy, z0, rot) in spots:
        stroke_poly(d, bundle_hull(iso, cx, cy, z0, rot, dims), S(ow_out), NAVY)
    for (cx, cy, z0, rot) in sorted(spots, key=lambda q: iso.depth(q[0], q[1], q[2] + dims[2] / 2)):
        draw_bundle(d, iso, cx, cy, z0, rot, ow_in=ow_in, dims=dims)


# tas de liasses : (centre x, centre y, bas z, rotation) ; liasse 1,75 x 1 x 0,92
H_ = BUNDLE[2]
PILES = {
    "liasse": [(0, 0, 0, 0)],
    "deux": [(0, 0, 0, 0), (0.08, -0.04, H_, -7)],
    "pile": [(0.0, 0.0, 0, 0), (1.80, 0.02, 0, 2), (0.02, 1.04, 0, -2), (1.82, 1.06, 0, 3),
             (0.92, 0.52, H_, 6)],
    "grosse": [(0.0, 0.0, 0, 0), (1.80, 0.0, 0, 2), (3.60, 0.04, 0, -2),
               (0.02, 1.04, 0, -2), (1.82, 1.05, 0, 3), (3.62, 1.08, 0, 1),
               (0.92, 0.50, H_, 5), (2.72, 0.54, H_, -4), (1.82, 0.54, 2 * H_, 8)],
}


def pile_extent(spots, dims=BUNDLE):
    pts = []
    L, W, H = dims
    for (cx, cy, z0, rot) in spots:
        base, _ = obox(None, cx, cy, z0, L, W, H, rot)
        for (x, y) in base:
            pts += [(x, y, z0), (x, y, z0 + H)]
    return pts


def iso_fit(spots, cx, cy, width, yaw=YAW, pitch=PITCH):
    """Iso centrée sur (cx, cy) dont le tas fait `width` px de large."""
    probe = Iso(0, 0, 1.0, yaw, pitch)
    pr = [probe.p(*q) for q in pile_extent(spots)]
    xs = [p[0] / SS for p in pr]
    ys = [p[1] / SS for p in pr]
    s = width / (max(xs) - min(xs))
    mx, my = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    return Iso(cx - mx * s, cy - my * s, s, yaw, pitch)


def draw_pile(layer, name, cx, cy, width, ow_out=9.0, ow_in=5.0, yaw=YAW, pitch=PITCH):
    spots = PILES[name] if isinstance(name, str) else name
    iso = iso_fit(spots, cx, cy, width, yaw, pitch)
    draw_bundles(layer, iso, spots, ow_out, ow_in)
    return iso


def pile_test():
    """Planche de contrôle : pile dessinée à côté de UI_Icon_Cash et du ×2 Cash."""
    W = Image.new("RGBA", (1560, 560), (28, 28, 36, 255))
    ref = Image.open(os.path.join(ART, SRC["cash"])).convert("RGBA").resize((380, 380), Image.LANCZOS)
    W.alpha_composite(ref, (10, 20))
    for i, name in enumerate(["liasse", "deux", "pile", "grosse"]):
        L = new_layer()
        draw_pile(L, name, 256, 256, {"liasse": 250, "deux": 260, "pile": 300, "grosse": 330}[name])
        im = down(L)
        W.alpha_composite(im.resize((380, 380), Image.LANCZOS), (390 + i * 290 - 40, 20))
        W.alpha_composite(im.resize((100, 100), Image.LANCZOS), (440 + i * 290, 420))
    W.alpha_composite(Image.open(REF_X2).convert("RGBA").resize((100, 100), Image.LANCZOS), (150, 420))
    W.save(os.path.join(HERE, "_pile_test.png"))


# ---------------------------------------------------------------- coffre bleu nuit ouvert (5H, 12H)
CHEST = dict(L=3.3, W=2.05, H=1.45, rim=0.17, lid_h=0.42, lid_open=104.0)
CH = dict(front=hexrgb("2A3DAE"), front_hi=hexrgb("3B55D2"), side=hexrgb("1B2575"), side_hi=hexrgb("25309A"),
          rim=hexrgb("4A66E0"), rim_side=hexrgb("2D3FA8"), inside=hexrgb("0C1038"), inside_wall=hexrgb("151B55"),
          lid_in=hexrgb("1A2268"), lid_edge=hexrgb("4A66E0"), lid_end=hexrgb("1B2575"),
          met=hexrgb("EEF2FA"), met_sh=hexrgb("B4BED3"), met_side=hexrgb("7F8AA8"),
          gold=hexrgb("FFC21A"), gold_sh=hexrgb("E08A00"), key=hexrgb("8A4A12"))


def chest_pts(iso, ch=CHEST):
    L, W, H = ch["L"], ch["W"], ch["H"]
    x0, x1, y0, y1 = -L / 2, L / 2, -W / 2, W / 2
    a = math.radians(ch["lid_open"])

    def lid(x, dy, dz):      # point du couvercle (dy depuis la charnière arrière, dz épaisseur)
        y = y0 + dy * math.cos(a) - dz * math.sin(a)
        z = H + dy * math.sin(a) + dz * math.cos(a)
        return iso.p(x, y, z)
    return (x0, x1, y0, y1, L, W, H), lid


def draw_chest(layer, iso, inside=(), above=(), ground=(), ch=CHEST, ow_out=9.5, ow_in=5.0, dims=BUNDLE):
    """Coffre ouvert vu en iso. inside : liasses dans le coffre (sous le bord) ; above : par-dessus le bord ;
    ground : posées par terre devant. Chaque liasse : (cx, cy, z0, rot)."""
    d = ImageDraw.Draw(layer)
    (x0, x1, y0, y1, L, W, H), lid = chest_pts(iso, ch)
    P = iso.p
    lh = ch["lid_h"]
    lid_corners = [lid(x, dy, dz) for x in (x0, x1) for dy in (0, W) for dz in (0, lh)]
    body = [P(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (0, H)]
    # contour extérieur commun (coffre + couvercle + liasses)
    stroke_poly(d, convex_hull(body), S(ow_out), NAVY)
    stroke_poly(d, convex_hull(lid_corners), S(ow_out), NAVY)
    for grp in (inside, above, ground):
        for (cx, cy, z0, rot) in grp:
            stroke_poly(d, bundle_hull(iso, cx, cy, z0, rot, dims), S(ow_out), NAVY)
    # couvercle ouvert (derrière)
    stroke_poly(d, convex_hull(lid_corners), S(ow_in), NAVY)
    d.polygon([lid(x1, 0, 0), lid(x1, W, 0), lid(x1, W, lh), lid(x1, 0, lh)], fill=CH["lid_end"])
    d.polygon([lid(x0, W, 0), lid(x1, W, 0), lid(x1, W, lh), lid(x0, W, lh)], fill=CH["lid_edge"])
    d.polygon([lid(x0, 0, 0), lid(x1, 0, 0), lid(x1, W, 0), lid(x0, W, 0)], fill=CH["lid_in"])
    # renforts métal du couvercle (bandes) + coin
    for u in (0.2, 0.8):
        xa, xb = x0 + L * (u - 0.045), x0 + L * (u + 0.045)
        d.polygon([lid(xa, 0.02, 0), lid(xb, 0.02, 0), lid(xb, W, 0), lid(xa, W, 0)], fill=CH["met_sh"])
        d.polygon([lid(xa, W, 0), lid(xb, W, 0), lid(xb, W, lh), lid(xa, W, lh)], fill=CH["met"])
    d.polygon([lid(x1 - 0.32, W - 0.32, 0), lid(x1, W - 0.32, 0), lid(x1, W, 0), lid(x1 - 0.32, W, 0)], fill=CH["met"])
    # intérieur
    r = ch["rim"]
    d.polygon([P(x0, y0, H), P(x1, y0, H), P(x1, y1, H), P(x0, y1, H)], fill=CH["rim"])
    d.polygon([P(x0 + r, y0 + r, H), P(x1 - r, y0 + r, H), P(x1 - r, y1 - r, H), P(x0 + r, y1 - r, H)], fill=CH["inside"])
    d.polygon([P(x0 + r, y0 + r, H), P(x1 - r, y0 + r, H), P(x1 - r, y0 + r, H - 0.5), P(x0 + r, y0 + r, H - 0.5)],
              fill=CH["inside_wall"])
    for (cx, cy, z0, rot) in sorted(inside, key=lambda q: iso.depth(q[0], q[1], q[2])):
        draw_bundle(d, iso, cx, cy, z0, rot, ow_in=ow_in, dims=dims)
    # murs avant (cachent le bas des liasses du dedans)
    stroke_front = [P(x0, y1, 0), P(x1, y1, 0), P(x1, y0, 0), P(x1, y0, H), P(x1, y1, H), P(x0, y1, H)]
    d.line(stroke_front + [stroke_front[0]], fill=NAVY, width=int(S(ow_in) * 2), joint="curve")
    d.polygon([P(x0, y1, 0), P(x1, y1, 0), P(x1, y1, H), P(x0, y1, H)], fill=CH["front"])
    d.polygon([P(x1, y0, 0), P(x1, y1, 0), P(x1, y1, H), P(x1, y0, H)], fill=CH["side"])
    # planches : bande claire en haut de la face avant, liseré du bas
    d.polygon([P(x0, y1, H * 0.70), P(x1, y1, H * 0.70), P(x1, y1, H * 0.86), P(x0, y1, H * 0.86)], fill=CH["front_hi"])
    d.polygon([P(x1, y0, H * 0.70), P(x1, y1, H * 0.70), P(x1, y1, H * 0.86), P(x1, y0, H * 0.86)], fill=CH["side_hi"])
    # bord avant (dessus des murs avant, devant les liasses)
    d.polygon([P(x0, y1 - r, H), P(x1, y1 - r, H), P(x1, y1, H), P(x0, y1, H)], fill=CH["rim"])
    d.polygon([P(x1 - r, y0, H), P(x1, y0, H), P(x1, y1, H), P(x1 - r, y1, H)], fill=CH["rim"])
    # renforts : bandes verticales et coins en métal
    for u in (0.2, 0.8):
        xa, xb = x0 + L * (u - 0.045), x0 + L * (u + 0.045)
        d.polygon([P(xa, y1, 0), P(xb, y1, 0), P(xb, y1, H), P(xa, y1, H)], fill=CH["met"])
        d.polygon([P(xa, y1, 0), P(xa + (xb - xa) * 0.35, y1, 0), P(xa + (xb - xa) * 0.35, y1, H), P(xa, y1, H)],
                  fill=WHITE)
    cw, chh = 0.34, 0.36
    for (zz0, zz1) in ((0, chh), (H - chh, H)):
        d.polygon([P(x0, y1, zz0), P(x0 + cw, y1, zz0), P(x0 + cw, y1, zz1), P(x0, y1, zz1)], fill=CH["met"])
        d.polygon([P(x1 - cw, y1, zz0), P(x1, y1, zz0), P(x1, y1, zz1), P(x1 - cw, y1, zz1)], fill=CH["met"])
        d.polygon([P(x1, y1 - cw, zz0), P(x1, y1, zz0), P(x1, y1, zz1), P(x1, y1 - cw, zz1)], fill=CH["met_side"])
        d.polygon([P(x1, y0, zz0), P(x1, y0 + cw, zz0), P(x1, y0 + cw, zz1), P(x1, y0, zz1)], fill=CH["met_side"])
    # serrure dorée au milieu du haut de la face avant
    lw, lz0, lz1 = 0.30, H * 0.48, H * 1.02
    d.polygon([P(-lw - 0.05, y1 + 0.01, lz0 - 0.05), P(lw + 0.05, y1 + 0.01, lz0 - 0.05),
               P(lw + 0.05, y1 + 0.01, lz1 + 0.05), P(-lw - 0.05, y1 + 0.01, lz1 + 0.05)], fill=NAVY)
    d.polygon([P(-lw, y1 + 0.01, lz0), P(lw, y1 + 0.01, lz0), P(lw, y1 + 0.01, lz1), P(-lw, y1 + 0.01, lz1)], fill=CH["gold"])
    d.polygon([P(-lw, y1 + 0.01, lz0), P(lw, y1 + 0.01, lz0), P(lw, y1 + 0.01, lz0 + 0.09), P(-lw, y1 + 0.01, lz0 + 0.09)],
              fill=CH["gold_sh"])
    kc = P(0, y1 + 0.01, (lz0 + lz1) / 2 + 0.05)
    kr = 0.07 * iso.s
    d.ellipse([kc[0] - S(kr), kc[1] - S(kr), kc[0] + S(kr), kc[1] + S(kr)], fill=CH["key"])
    d.polygon([P(-0.05, y1 + 0.01, (lz0 + lz1) / 2 + 0.05), P(0.05, y1 + 0.01, (lz0 + lz1) / 2 + 0.05),
               P(0.08, y1 + 0.01, lz0 + 0.12), P(-0.08, y1 + 0.01, lz0 + 0.12)], fill=CH["key"])
    # reflet blanc sur l'arête avant gauche du bord
    seg(d, P(x0 + 0.42, y1 - r * 0.5, H), P(x0 + 0.95, y1 - r * 0.5, H), 3.4 * iso.s / 60)
    for (cx, cy, z0, rot) in sorted(above, key=lambda q: iso.depth(q[0], q[1], q[2])):
        draw_bundle(d, iso, cx, cy, z0, rot, ow_in=ow_in, dims=dims)
    for (cx, cy, z0, rot) in sorted(ground, key=lambda q: iso.depth(q[0], q[1], q[2])):
        draw_bundle(d, iso, cx, cy, z0, rot, ow_in=ow_in, dims=dims)


def chest_iso(cx, cy, width, extra=(), yaw=YAW, pitch=PITCH, ch=CHEST):
    probe = Iso(0, 0, 1.0, yaw, pitch)
    (x0, x1, y0, y1, L, W, H), lid = chest_pts(probe, ch)
    pts = [probe.p(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (0, H)]
    pts += [lid(x, dy, dz) for x in (x0, x1) for dy in (0, W) for dz in (0, ch["lid_h"])]
    pts += [probe.p(*q) for q in pile_extent(list(extra))]
    xs = [p[0] / SS for p in pts]
    ys = [p[1] / SS for p in pts]
    s = width / (max(xs) - min(xs))
    mx, my = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    return Iso(cx - mx * s, cy - my * s, s, yaw, pitch)


# liasses du coffre (unités du monde, coffre 3,3 x 2,05 x 1,45 centré)
CHEST_5H = dict(inside=[(-0.72, -0.30, 1.02, 4), (0.78, -0.28, 1.02, -5), (-0.70, 0.42, 0.86, -3),
                        (0.80, 0.45, 0.86, 6)],
                above=[(0.04, -0.02, 1.72, 9)], ground=[])
CHEST_12H = dict(inside=[(-0.72, -0.30, 0.80, 4), (0.78, -0.28, 0.80, -5), (-0.70, 0.42, 0.62, -3),
                         (0.80, 0.45, 0.62, 6)],
                 above=[(-0.74, -0.22, 1.40, -8), (0.84, -0.18, 1.40, 7), (0.06, -0.34, 2.24, 4)],
                 ground=[(-2.45, 0.70, 0, 26)])


def draw_chest_full(layer, spec, cx, cy, width):
    allb = spec["inside"] + spec["above"] + spec["ground"]
    iso = chest_iso(cx, cy, width, extra=allb)
    draw_chest(layer, iso, spec["inside"], spec["above"], spec["ground"])
    return iso


# ---------------------------------------------------------------- billet volant (comme dans l'essai Auto Collect)
B_FACE, B_EDGE, B_SIDE, B_LIGHT = hexrgb("39B54A"), hexrgb("009245"), hexrgb("006837"), hexrgb("8FE07E")


def bill_pts(w, h, wave, inset=0.0, n=24):
    top, bot = [], []
    for i in range(n + 1):
        u = -w / 2 + inset + (w - 2 * inset) * i / n
        dy = wave * math.sin(2 * math.pi * (u / w))
        top.append((u, -h / 2 + inset + dy))
        bot.append((u, h / 2 - inset + dy))
    return top + bot[::-1]


def draw_bill(d, cx, cy, ang, sc=1.0):
    w, h, wave = 66 * sc, 36 * sc, 3.6 * sc
    ex, ey = 3.0 * sc, 5.0 * sc
    body = bill_pts(w, h, wave)
    for i in range(7):
        t = i / 6
        stroke_poly(d, xf(body, cx, cy, ang, off=(ex * t, ey * t)), S(6.5 * sc), NAVY)
    for i in range(6, 0, -1):
        t = i / 6
        d.polygon(xf(body, cx, cy, ang, off=(ex * t, ey * t)), fill=B_SIDE)
    d.polygon(xf(body, cx, cy, ang), fill=B_FACE)
    inner = xf(bill_pts(w, h, wave, inset=5.0 * sc), cx, cy, ang)
    d.line(inner + [inner[0]], fill=B_EDGE, width=int(S(3.2 * sc)), joint="curve")
    oval = []
    for i in range(40):
        t = 2 * math.pi * i / 40
        u = 8.5 * sc * math.cos(t)
        oval.append((u, 10.5 * sc * math.sin(t) + wave * math.sin(2 * math.pi * (u / w))))
    d.polygon(xf(oval, cx, cy, ang), fill=B_EDGE)
    d.polygon(xf([(-w / 2 + 2 * sc, -h / 2 + 2 * sc), (-w / 2 + 16 * sc, -h / 2 + 2 * sc),
                  (-w / 2 + 2 * sc, -h / 2 + 12 * sc)], cx, cy, ang), fill=B_LIGHT)
    a = xf([(-w / 2 + 12 * sc, -h / 2 + 9 * sc - wave * 0.9), (-w / 2 + 24 * sc, -h / 2 + 8 * sc - wave * 0.8)], cx, cy, ang)
    d.line(a, fill=WHITE, width=int(S(3.6 * sc)))


# ---------------------------------------------------------------- chronomètre (Quick Lock)
RED, RED_LIGHT, RED_DEEP = hexrgb("E8343C"), hexrgb("FF7068"), hexrgb("B81C30")
MET, MET_SH, MET_SIDE = hexrgb("EEF2FA"), hexrgb("B4BED3"), hexrgb("7F8AA8")
GOLD, GOLD_LIGHT, GOLD_SH = hexrgb("FFC21A"), hexrgb("FFE066"), hexrgb("E08A00")


def circ(d, cx, cy, r, fill):
    d.ellipse([S(cx - r), S(cy - r), S(cx + r), S(cy + r)], fill=fill)


def draw_stopwatch(d, cx, cy, R, ang=12.0, ow=8.0, sweep=(-90, 30)):
    """Chronomètre : boîtier rouge, cadran blanc, secteur écoulé bleu clair, aiguille, remontoir argent."""
    a = math.radians(ang)

    def rp(dx, dy):      # point tourné autour du centre
        return (cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a))

    stem = [rp(-R * 0.14, -R * 1.02), rp(R * 0.14, -R * 1.02), rp(R * 0.14, -R * 1.22), rp(-R * 0.14, -R * 1.22)]
    cap = [rp(-R * 0.30, -R * 1.20), rp(R * 0.30, -R * 1.20), rp(R * 0.30, -R * 1.42), rp(-R * 0.30, -R * 1.42)]
    side_b = [rp(R * 0.62, -R * 0.80), rp(R * 0.80, -R * 0.94), rp(R * 0.92, -R * 0.78), rp(R * 0.74, -R * 0.64)]
    for poly in (stem, cap, side_b):
        stroke_poly(d, [(S(x), S(y)) for x, y in poly], S(ow), NAVY)
    circ(d, cx, cy, R + ow, NAVY)
    d.polygon([(S(x), S(y)) for x, y in stem], fill=MET_SH)
    d.polygon([(S(x), S(y)) for x, y in side_b], fill=MET_SH)
    d.polygon([(S(x), S(y)) for x, y in cap], fill=MET)
    capl = [rp(-R * 0.30, -R * 1.20), rp(-R * 0.10, -R * 1.20), rp(-R * 0.10, -R * 1.42), rp(-R * 0.30, -R * 1.42)]
    d.polygon([(S(x), S(y)) for x, y in capl], fill=WHITE)
    # boîtier : rouge, ombre en bas à droite, lumière en haut à gauche
    circ(d, cx, cy, R, RED_DEEP)
    circ(d, cx - R * 0.05, cy - R * 0.06, R * 0.95, RED)
    m = Image.new("L", (B, B), 0)
    dm = ImageDraw.Draw(m)
    circ(dm, cx, cy, R * 0.97, 255)
    circ(dm, cx + R * 0.09, cy + R * 0.10, R * 0.97, 0)
    d.bitmap((0, 0), m, fill=RED_LIGHT)
    # cadran
    rf = R * 0.76
    circ(d, cx, cy, rf + 4.5, NAVY)
    circ(d, cx, cy, rf, hexrgb("D7DEEC"))
    circ(d, cx - rf * 0.04, cy - rf * 0.05, rf * 0.95, hexrgb("F7F9FD"))
    # secteur écoulé (court : le temps file vite)
    pts = [(S(cx), S(cy))]
    for i in range(41):
        t = math.radians(sweep[0] + (sweep[1] - sweep[0]) * i / 40)
        pts.append((S(cx + rf * 0.92 * math.cos(t)), S(cy + rf * 0.92 * math.sin(t))))
    d.polygon(pts, fill=hexrgb("9FDBFF"))
    # graduations
    for k in range(12):
        t = math.radians(k * 30 - 90)
        r0 = rf * (0.70 if k % 3 == 0 else 0.78)
        p0 = (S(cx + r0 * math.cos(t)), S(cy + r0 * math.sin(t)))
        p1 = (S(cx + rf * 0.88 * math.cos(t)), S(cy + rf * 0.88 * math.sin(t)))
        seg(d, p0, p1, 5.0 if k % 3 == 0 else 3.2, NAVY)
    # aiguille vers la fin du secteur
    t = math.radians(sweep[1])
    seg(d, (S(cx), S(cy)), (S(cx + rf * 0.72 * math.cos(t)), S(cy + rf * 0.72 * math.sin(t))), 7.0, NAVY)
    circ(d, cx, cy, 9, NAVY)
    circ(d, cx, cy, 4, GOLD)
    # reflet blanc sur le boîtier
    arc = [(S(cx + R * 0.86 * math.cos(math.radians(t_))), S(cy + R * 0.86 * math.sin(math.radians(t_))))
           for t_ in np.linspace(196, 236, 16)]
    d.line(arc, fill=WHITE, width=int(S(R * 0.075)), joint="curve")
    dot(d, arc[0], R * 0.0375)
    dot(d, arc[-1], R * 0.0375)
    p = (S(cx + R * 0.86 * math.cos(math.radians(248))), S(cy + R * 0.86 * math.sin(math.radians(248))))
    dot(d, p, R * 0.042)


# ---------------------------------------------------------------- éclair
def draw_bolt(d, cx, cy, sc=1.0, ang=12.0, ow=8.0):
    pts = [(-8, -70), (40, -70), (14, -14), (44, -14), (-22, 74), (-6, 12), (-34, 12)]
    ext = (6 * sc, 9 * sc)
    for i in range(9):
        t = i / 8
        stroke_poly(d, xf(pts, cx, cy, ang, sc, off=(ext[0] * t, ext[1] * t)), S(ow), NAVY)
    for i in range(8, 0, -1):
        t = i / 8
        d.polygon(xf(pts, cx, cy, ang, sc, off=(ext[0] * t, ext[1] * t)), fill=GOLD_SH)
    d.polygon(xf(pts, cx, cy, ang, sc), fill=hexrgb("FFD21F"))
    d.polygon(xf([(-8, -70), (40, -70), (34, -58), (-4, -58), (-24, 4), (-34, 12)], cx, cy, ang, sc), fill=GOLD_LIGHT)
    a = xf([(2, -62), (-14, -14)], cx, cy, ang, sc)
    seg(d, a[0], a[1], 5.5 * sc)


# ---------------------------------------------------------------- cadenas ouvert (d'après 22_Icon_Lock)
LOCK = dict(front=hexrgb("FFC21A"), front_hi=hexrgb("FFD84A"), left=hexrgb("FF7A22"), right=hexrgb("FFA21E"),
            key=hexrgb("C86030"), key_sh=hexrgb("A84820"), shk=hexrgb("7098B8"), shk_sh=hexrgb("587FA0"),
            shk_hi=hexrgb("9DBCD6"))


def rrect_pts(x0, y0, x1, y1, r, n=10):
    pts = []
    for (cx_, cy_, a0) in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(n + 1):
            t = math.radians(a0 + 90 * i / n)
            pts.append((cx_ + r * math.cos(t), cy_ + r * math.sin(t)))
    return pts


def u_shape(Ro, Ri, L0, L1=None):
    """Anse en U ouverte vers le bas ; jambes jusqu'à L0 (gauche) et L1 (droite)."""
    L1 = L0 if L1 is None else L1
    return arc_pts(Ro, 180, 0) + [(Ro, L1), (Ri, L1)] + arc_pts(Ri, 0, 180) + [(-Ri, L0), (-Ro, L0)]


def draw_open_lock(d, cx, cy, sc=1.0, ow=9.0):
    """Cadenas doré ouvert : anse levée et pivotée, corps comme 22_Icon_Lock."""
    k = sc
    bw, bh, br = 196 * k, 150 * k, 24 * k
    bx0, by0 = cx - bw / 2, cy - bh / 2 + 30 * k
    bx1, by1 = bx0 + bw, by0 + bh
    # anse : levée de `lift`, pivotée autour de la jambe droite qui reste dans son trou
    Ro, Ri = 66 * k, 38 * k
    lift, ang = 30 * k, 17.0
    acx, acy = bx0 + bw * 0.5, by0 - 44 * k - lift          # centre de l'arc
    leg_x = acx + (Ro + Ri) / 2
    pivot = (leg_x, by0 + 22 * k)
    sh = u_shape(Ro, Ri, 40 * k, pivot[1] - acy)

    def shp(pts, off=(0, 0)):
        a = math.radians(ang)
        out = []
        for (x, y) in pts:
            dx, dy = acx + x - pivot[0], acy + y - pivot[1]
            out.append((S(pivot[0] + dx * math.cos(a) - dy * math.sin(a) + off[0]),
                        S(pivot[1] + dx * math.sin(a) + dy * math.cos(a) + off[1])))
        return out
    ext = (7 * k, 0)
    for i in range(7):
        stroke_poly(d, shp(sh, (ext[0] * i / 6, 0)), S(ow), NAVY)
    for i in range(6, 0, -1):
        d.polygon(shp(sh, (ext[0] * i / 6, 0)), fill=LOCK["shk_sh"])
    d.polygon(shp(sh), fill=LOCK["shk"])
    d.polygon(shp(arc_pts(Ro - 6 * k, 178, 110) + arc_pts(Ro - 18 * k, 110, 178)), fill=LOCK["shk_hi"])
    # bout libre de la jambe gauche : trou visible (coupe sombre)
    d.polygon(shp([(-Ro + 4 * k, 40 * k - 8 * k), (-Ri - 4 * k, 40 * k - 8 * k), (-Ri - 4 * k, 40 * k), (-Ro + 4 * k, 40 * k)]),
              fill=LOCK["shk_sh"])
    # corps
    body = [(S(x), S(y)) for x, y in rrect_pts(bx0, by0, bx1, by1, br)]
    stroke_poly(d, body, S(ow), NAVY)
    d.polygon(body, fill=LOCK["right"])
    d.polygon([(S(x), S(y)) for x, y in rrect_pts(bx0, by0, bx1 - 14 * k, by1, br)], fill=LOCK["front"])
    d.polygon([(S(x), S(y)) for x, y in rrect_pts(bx0, by0, bx0 + 40 * k, by1, br)], fill=LOCK["left"])
    d.polygon([(S(x), S(y)) for x, y in rrect_pts(bx0 + 26 * k, by0, bx1 - 14 * k, by1, br * 0.6)], fill=LOCK["front"])
    d.polygon([(S(x), S(y)) for x, y in rrect_pts(bx0 + 26 * k, by0, bx1 - 14 * k, by0 + 26 * k, br * 0.5)],
              fill=LOCK["front_hi"])
    # trou de serrure
    kx, ky = cx + 8 * k, by0 + bh * 0.42
    circ(d, kx + 3 * k, ky + 3 * k, 22 * k, LOCK["key_sh"])
    d.polygon([(S(kx - 10 * k + 3 * k), S(ky)), (S(kx + 10 * k + 3 * k), S(ky)),
               (S(kx + 20 * k + 3 * k), S(ky + 58 * k)), (S(kx - 20 * k + 3 * k), S(ky + 58 * k))], fill=LOCK["key_sh"])
    circ(d, kx, ky, 22 * k, LOCK["key"])
    d.polygon([(S(kx - 10 * k), S(ky)), (S(kx + 10 * k), S(ky)), (S(kx + 20 * k), S(ky + 56 * k)),
               (S(kx - 20 * k), S(ky + 56 * k))], fill=LOCK["key"])
    # étincelle blanche du coin, comme sur la source
    sparkle(d, bx0 + 30 * k, by0 + 24 * k, 22 * k, fill=WHITE, ow=0.01)


# ---------------------------------------------------------------- présentoir (d'après UI_Btn_Icon_Display)
GEM = dict(l=hexrgb("E27BFF"), m=hexrgb("C03CF5"), d=hexrgb("9408EE"), dd=hexrgb("6A06B8"), t=hexrgb("F2B8FF"))
PED = dict(gold=hexrgb("FFD23A"), gold_sh=hexrgb("F59A00"), gold_hi=hexrgb("FFF0A0"), blue=hexrgb("1AA8F8"),
           blue_sh=hexrgb("1170C8"), blue_hi=hexrgb("7FD6FF"), top=hexrgb("8FE3FF"), top_c=hexrgb("D8F6FF"))


def cyl_pts(cx, y_top, y_bot, a, b, n=48):
    """Contour d'un cylindre vu de trois-quarts (ellipse du haut + moitié basse de l'ellipse du bas)."""
    pts = [(cx + a * math.cos(math.radians(t)), y_top + b * math.sin(math.radians(t))) for t in np.linspace(180, 360, n)]
    pts += [(cx + a * math.cos(math.radians(t)), y_bot + b * math.sin(math.radians(t))) for t in np.linspace(0, 180, n)]
    return pts


def ell_pts(cx, cy, a, b, n=64):
    return [(cx + a * math.cos(t), cy + b * math.sin(t)) for t in np.linspace(0, 2 * math.pi, n, endpoint=False)]


def SP(pts):
    return [(S(x), S(y)) for x, y in pts]


def hshade(d, pts, cx, a, lit, dark, frac=0.62):
    """Ombre verticale sur la droite d'un cylindre : polygone recoupé à droite de cx + a*(2*frac-1)."""
    m = Image.new("L", (B, B), 0)
    ImageDraw.Draw(m).polygon(SP(pts), fill=255)
    cut = Image.new("L", (B, B), 0)
    xs = cx + a * (2 * frac - 1)
    ImageDraw.Draw(cut).rectangle([S(xs), 0, B, B], fill=255)
    d.bitmap((0, 0), mask_mul(m, cut), fill=dark)


def draw_display(d, cx, cy, sc=1.0, ow=9.0):
    """Gemme violette taillée posée sur un socle bleu à bords dorés et plaque dorée."""
    k = sc
    a = 112 * k
    b = 30 * k
    y_top = cy + 40 * k           # dessus du socle
    rim1 = (y_top, y_top + 13 * k)
    drum = (y_top + 13 * k, y_top + 64 * k)
    rim2 = (y_top + 64 * k, y_top + 80 * k)
    # gemme : table, couronne, rondiste, culasse (pointe en bas, posée sur le socle)
    gw, gy = 98 * k, cy - 52 * k
    G = dict(tl=(cx - gw * 0.52, gy - 48 * k), tr=(cx + gw * 0.52, gy - 48 * k), gl=(cx - gw, gy), gr=(cx + gw, gy),
             p=(cx, y_top + 8 * k))
    gem_out = [G["tl"], G["tr"], G["gr"], G["p"], G["gl"]]
    # contour commun
    stroke_poly(d, SP(cyl_pts(cx, rim2[0], rim2[1], a + 6 * k, b + 2 * k)), S(ow), NAVY)
    stroke_poly(d, SP(cyl_pts(cx, rim1[0] - 2 * k, rim1[1], a + 4 * k, b + 1 * k)), S(ow), NAVY)
    stroke_poly(d, SP(gem_out), S(ow), NAVY)
    # socle
    for (yt, yb, aa, col, colsh) in ((rim2[0], rim2[1], a + 6 * k, PED["gold"], PED["gold_sh"]),
                                     (drum[0], drum[1], a - 8 * k, PED["blue"], PED["blue_sh"]),
                                     (rim1[0], rim1[1], a + 4 * k, PED["gold"], PED["gold_sh"])):
        bb = b + (2 * k if aa > a else -2 * k)
        pts = cyl_pts(cx, yt, yb, aa, bb)
        stroke_poly(d, SP(pts), S(4.5), NAVY)
        d.polygon(SP(pts), fill=col)
        hshade(d, pts, cx, aa, col, colsh, 0.80)
        d.polygon(SP(cyl_pts(cx, yt, yt + (yb - yt) * 0.30, aa * 0.98, bb)), fill=col)
        seg(d, (S(cx - aa * 0.78), S(yt + bb * 0.62 + (yb - yt) * 0.5)), (S(cx - aa * 0.52), S(yt + bb * 0.86 + (yb - yt) * 0.5)),
            4.2 * k, PED["gold_hi"] if col == PED["gold"] else PED["blue_hi"])
    # dessus lumineux
    d.polygon(SP(ell_pts(cx, y_top, a + 4 * k, b + 1 * k)), fill=PED["gold"])
    d.polygon(SP(ell_pts(cx, y_top + 1 * k, a - 10 * k, b - 6 * k)), fill=PED["top"])
    d.polygon(SP(ell_pts(cx - 8 * k, y_top - 1 * k, (a - 10 * k) * 0.6, (b - 6 * k) * 0.55)), fill=PED["top_c"])
    # plaque dorée
    plq = rrect_pts(cx - 38 * k, drum[0] + b + 4 * k, cx + 38 * k, drum[1] + b - 4 * k, 6 * k)
    stroke_poly(d, SP(plq), S(4.5), NAVY)
    d.polygon(SP(plq), fill=PED["gold"])
    d.polygon(SP(rrect_pts(cx - 38 * k, drum[0] + b + 4 * k, cx + 38 * k, drum[0] + b + 14 * k, 5 * k)), fill=PED["gold_hi"])
    # gemme : facettes
    d.polygon(SP(gem_out), fill=GEM["d"])
    top_mid_l, top_mid_r = (cx - gw * 0.18, gy - 48 * k), (cx + gw * 0.18, gy - 48 * k)
    gm_l, gm_r, gm_c = (cx - gw * 0.52, gy), (cx + gw * 0.52, gy), (cx, gy)
    d.polygon(SP([G["tl"], top_mid_l, gm_l, G["gl"]]), fill=GEM["l"])
    d.polygon(SP([top_mid_l, top_mid_r, gm_c]), fill=GEM["t"])
    d.polygon(SP([top_mid_l, gm_c, gm_l]), fill=GEM["m"])
    d.polygon(SP([top_mid_r, G["tr"], gm_r, gm_c]), fill=GEM["m"])
    d.polygon(SP([G["tr"], G["gr"], gm_r]), fill=GEM["d"])
    d.polygon(SP([G["gl"], gm_l, G["p"]]), fill=GEM["m"])
    d.polygon(SP([gm_l, gm_c, G["p"]]), fill=GEM["l"])
    d.polygon(SP([gm_c, gm_r, G["p"]]), fill=GEM["d"])
    d.polygon(SP([gm_r, G["gr"], G["p"]]), fill=GEM["dd"])
    for (p, q) in ((G["gl"], G["gr"]),):
        d.line(SP([p, q]), fill=GEM["dd"], width=int(S(2.5 * k)))
    seg(d, (S(cx - gw * 0.45), S(gy - 38 * k)), (S(cx - gw * 0.28), S(gy - 38 * k)), 5 * k)
    seg(d, (S(cx - gw * 0.72), S(gy + 10 * k)), (S(cx - gw * 0.42), S(gy + 46 * k)), 5 * k)


# ---------------------------------------------------------------- sac de voleur
SACK = dict(m=hexrgb("C68A4E"), d=hexrgb("9C6236"), l=hexrgb("E2AE72"), rope=hexrgb("E4C27A"), rope_d=hexrgb("A9823F"))


def blob(cx, cy, rx, ry, n=96, squash=0.0, neck=0.0):
    """Corps de sac : ellipse aplatie en bas, resserrée vers le haut (col)."""
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = math.cos(t), math.sin(t)
        if y < 0:                         # moitié haute : se resserre vers le col
            x *= 1 - neck * (-y) ** 1.6
        else:
            y *= 1 - squash * y ** 2
        pts.append((cx + rx * x, cy + ry * y))
    return pts


def draw_sack(d, cx, cy, sc=1.0, ow=9.0):
    k = sc
    body = blob(cx, cy + 26 * k, 122 * k, 104 * k, squash=0.18, neck=0.62)
    neck_y = cy + 26 * k - 104 * k * 0.92
    # tissu froncé au-dessus du lien : trois lobes arrondis
    lobes = [(cx - 36 * k, neck_y - 22 * k, 30 * k, 22 * k, -30), (cx + 2 * k, neck_y - 34 * k, 26 * k, 28 * k, 0),
             (cx + 38 * k, neck_y - 22 * k, 30 * k, 22 * k, 28)]

    def lobe_pts(x, y, rx, ry, rot):
        a = math.radians(rot)
        return [(x + rx * math.cos(t) * math.cos(a) - ry * math.sin(t) * math.sin(a),
                 y + rx * math.cos(t) * math.sin(a) + ry * math.sin(t) * math.cos(a))
                for t in np.linspace(0, 2 * math.pi, 48, endpoint=False)]
    knot = rrect_pts(cx - 40 * k, neck_y - 6 * k, cx + 40 * k, neck_y + 18 * k, 10 * k)
    for poly in [body, knot] + [lobe_pts(*lb) for lb in lobes]:
        stroke_poly(d, SP(poly), S(ow), NAVY)
    rope_end = ((cx + 34 * k, neck_y + 12 * k), (cx + 56 * k, neck_y + 46 * k))
    # corps : moyen, ombre à droite et en bas, lumière en haut à gauche
    d.polygon(SP(body), fill=SACK["d"])
    d.polygon(SP(blob(cx - 10 * k, cy + 18 * k, 108 * k, 96 * k, squash=0.18, neck=0.60)), fill=SACK["m"])
    d.polygon(SP(blob(cx - 48 * k, cy - 4 * k, 40 * k, 46 * k)), fill=SACK["l"])
    for (p0, p1, p2) in (((cx - 70 * k, cy + 70 * k), (cx - 50 * k, cy + 96 * k), (cx - 20 * k, cy + 108 * k)),
                         ((cx + 62 * k, cy - 10 * k), (cx + 84 * k, cy + 26 * k), (cx + 82 * k, cy + 64 * k))):
        pts = [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in np.linspace(0, 1, 16)]
        d.line(SP(pts), fill=SACK["d"], width=int(S(6 * k)), joint="curve")
    for n_, lb in enumerate(lobes):
        d.polygon(SP(lobe_pts(*lb)), fill=SACK["d"] if n_ == 2 else SACK["m"])
    x, y, rx, ry, rot = lobes[0]
    d.polygon(SP(lobe_pts(x - 4 * k, y - 4 * k, rx * 0.6, ry * 0.55, rot)), fill=SACK["l"])
    x, y, rx, ry, rot = lobes[1]
    d.polygon(SP(lobe_pts(x - 5 * k, y - 6 * k, rx * 0.55, ry * 0.55, rot)), fill=SACK["l"])
    # lien de corde
    stroke_poly(d, SP(knot), S(4.5), NAVY)
    d.polygon(SP(knot), fill=SACK["rope"])
    for i in range(5):
        xx = cx - 30 * k + i * 15 * k
        d.line(SP([(xx, neck_y - 4 * k), (xx + 8 * k, neck_y + 16 * k)]), fill=SACK["rope_d"], width=int(S(3.5 * k)))
    capsule(d, rope_end[0], rope_end[1], 13 * k, ow=4.5, fill=SACK["rope"])
    seg(d, SP([lerp(rope_end[0], rope_end[1], 0.35)])[0], SP([lerp(rope_end[0], rope_end[1], 0.85)])[0], 3.2 * k,
        SACK["rope_d"])
    # « $ » doré
    f = ImageFont.truetype(FONT, int(S(130 * k)))
    tx, ty = S(cx - 6 * k), S(cy + 44 * k)
    d.text((tx, ty), "$", font=f, fill=NAVY, anchor="mm", stroke_width=int(S(9 * k)), stroke_fill=NAVY)
    d.text((tx, ty), "$", font=f, fill=GOLD, anchor="mm")
    # reflets
    seg(d, (S(cx - 86 * k), S(cy + 6 * k)), (S(cx - 76 * k), S(cy - 22 * k)), 6.5 * k)
    dot(d, (S(cx - 70 * k), S(cy - 38 * k)), 3.6 * k)


# ---------------------------------------------------------------- éclats de vitre
GLASS, GLASS_SH, GLASS_HI = hexrgb("CFF4FF"), hexrgb("86D3F2"), WHITE


def draw_shard(d, cx, cy, pts, ang=0.0, sc=1.0, ow=5.0):
    P = xf(pts, cx, cy, ang, sc)
    stroke_poly(d, P, S(ow), NAVY)
    d.polygon(P, fill=GLASS)
    c = (sum(p[0] for p in P) / len(P), sum(p[1] for p in P) / len(P))
    d.polygon([P[1], P[2], c], fill=GLASS_SH)
    a, b = P[0], P[1]
    seg(d, lerp(a, c, 0.25), lerp(b, c, 0.45), 3.0 * sc)


SHARDS = [[(-14, -22), (16, -10), (-2, 26)], [(-18, -6), (10, -20), (20, 12), (-6, 18)],
          [(-10, -18), (14, -4), (-12, 16)], [(-16, -10), (18, -16), (4, 20)]]


# ---------------------------------------------------------------- images sources
def load(name, scale):
    im = Image.open(os.path.join(ART, SRC[name])).convert("RGBA")
    w, h = im.size
    im = im.convert("RGBa").resize((int(round(w * scale)), int(round(h * scale))), Image.LANCZOS).convert("RGBA")
    if scale > 1.0:
        im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    return im


RMAX = []        # rayons max des symboles posés (contrôle : rien ne doit toucher le contour du sceau)


def note_r(im512, ox=0, oy=0):
    a = np.array(im512.getchannel("A")) > 60
    ys, xs = np.nonzero(a)
    if len(xs):
        RMAX.append(float(np.hypot(xs + ox - C, ys + oy - C).max()))


def paste_c(canvas, im, cx, cy, rot=0.0):
    if rot:
        im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    bb = im.getbbox()
    ox, oy = int(round(cx - (bb[0] + bb[2]) / 2)), int(round(cy - (bb[1] + bb[3]) / 2))
    note_r(im, ox, oy)
    canvas.alpha_composite(im, (ox, oy))


def layer_down(fn):
    """Dessine fn(draw, layer) dans un calque 4x et le rend réduit (rayon noté pour le contrôle)."""
    L = new_layer()
    fn(ImageDraw.Draw(L), L)
    im = down(L)
    note_r(im)
    return im


def chest_test():
    W = Image.new("RGBA", (1100, 560), (28, 28, 36, 255))
    for i, spec in enumerate([CHEST_5H, CHEST_12H]):
        L = new_layer()
        draw_chest_full(L, spec, 256, 256, 320)
        im = down(L)
        W.alpha_composite(im, (20 + i * 540, 20))
        W.alpha_composite(im.resize((100, 100), Image.LANCZOS), (440 + i * 540, 440))
    W.save(os.path.join(HERE, "_chest_test.png"))


# ---------------------------------------------------------------- les images
JOBS = {}
LABEL_C = (385, 340)          # centre du blanc du ×2 sur UI_Icon_GP_x2Cash (mesuré)
BADGE_SPARKS = [(378, 148, 18), (116, 178, 13), (380, 362, 11), (150, 380, 9)]


def job(name):
    def deco(fn):
        JOBS[name] = fn
        return fn
    return deco


def sparkles(d, specs, fill=(0xFF, 0xF4, 0xC8)):
    for (x, y, r) in specs:
        sparkle(d, x, y, r, fill=fill)


# --- gamepasses
@job("UI_Icon_GP_DoubleSpeed")
def gp_double_speed():
    img = seal_layer("F2553A")

    def lines(d, L):
        speed_lines(d, [(150, 198, 92, 198), (138, 240, 76, 240), (150, 282, 100, 282)], w=10)
    img.alpha_composite(layer_down(lines))
    shoe = load("speed", 1.12).transpose(Image.FLIP_LEFT_RIGHT)
    paste_c(img, shoe, 262, 238, rot=6)
    top = new_layer()
    add_label(top, "×2", LABEL_C)
    img.alpha_composite(down(top))
    return img


@job("UI_Icon_GP_FastOpen")
def gp_fast_open():
    img = seal_layer("2FA8F0")

    def lines(d, L):
        speed_lines(d, [(124, 194, 90, 194), (112, 238, 74, 238), (124, 282, 94, 282)], w=10)
    img.alpha_composite(layer_down(lines))
    paste_c(img, load("lock", 0.96), 244, 232)

    def watch(d, L):
        draw_stopwatch(d, 356, 334, 60, ang=14)
    img.alpha_composite(layer_down(watch))
    return img


@job("UI_Icon_GP_Displays")
def gp_displays():
    img = seal_layer("E05AD8")

    def disp(d, L):
        draw_display(d, 228, 214, sc=0.94)
        sparkles(d, [(134, 132, 13), (352, 118, 16)])
    img.alpha_composite(layer_down(disp))
    top = new_layer()
    add_label(top, "+4", LABEL_C)
    img.alpha_composite(down(top))
    return img


# --- produits : argent
MIN_LINES = dict(size_num=124, size_unit=70)


def cash_label(L, text, center=LABEL_C):
    if text.endswith("MIN"):
        num = text.split()[0]
        add_label(L, None, center, size=LBL["size"],
                  lines=[(num, MIN_LINES["size_num"]), ("MIN", MIN_LINES["size_unit"])])
    else:
        add_label(L, text, center, size=145 if len(text) <= 2 else 116)


def cash_job(name, color, label, draw_symbol):
    @job(name)
    def _fn():
        img = seal_layer(color)

        def sym(d, L):
            draw_symbol(d, L)
        img.alpha_composite(layer_down(sym))
        top = new_layer()
        cash_label(top, label, (376, 350) if label.endswith("MIN") else (LABEL_C if len(label) <= 2 else (372, 350)))
        img.alpha_composite(down(top))
        return img
    return _fn


cash_job("UI_Icon_DP_Cash_1", "5BCB3A", "10 MIN", lambda d, L: draw_pile(L, "liasse", 234, 228, 236))
cash_job("UI_Icon_DP_Cash_2", "3EBA4A", "30 MIN", lambda d, L: draw_pile(L, "deux", 232, 232, 228))
cash_job("UI_Icon_DP_Cash_3", "22A85A", "1H", lambda d, L: draw_pile(L, "pile", 238, 236, 268))
cash_job("UI_Icon_DP_Cash_4", "85A739", "3H", lambda d, L: draw_pile(L, "grosse", 242, 238, 290))
cash_job("UI_Icon_DP_Cash_5", "E8A618", "5H", lambda d, L: draw_chest_full(L, CHEST_5H, 226, 236, 262))


def _cash6(d, L):
    for (x, y, a, sc) in [(112, 200, -24, 0.84), (382, 168, 22, 0.80), (214, 112, -10, 0.74)]:
        draw_bill(d, x, y, a, sc)
    draw_chest_full(L, CHEST_12H, 228, 232, 286)
    sparkles(d, [(146, 140, 14), (318, 100, 12), (408, 256, 13)], fill=GOLD_SPARK)


cash_job("UI_Icon_DP_Cash_6", "FFC21A", "12H", _cash6)


@job("UI_Icon_DP_StarterPack")
def dp_starter():
    img = seal_layer("FF8A1F")

    def pile(d, L):
        draw_pile(L, "pile", 222, 268, 262)
    img.alpha_composite(layer_down(pile))
    paste_c(img, load("hammer", 0.80), 262, 200, rot=-38)
    top = new_layer()
    add_label(top, "×2", (392, 352), size=108)
    img.alpha_composite(down(top))
    return img


@job("UI_Icon_DP_OpenNow")
def dp_open_now():
    img = seal_layer("18B894")

    def sym(d, L):
        draw_open_lock(d, 232, 262, sc=0.90)
        draw_bolt(d, 360, 322, sc=1.04, ang=14)
    img.alpha_composite(layer_down(sym))
    return img


# --- badges
@job("BADGE_Welcome")
def b_welcome():
    img = medal_layer("2F9BFF")
    paste_c(img, load("house", 1.04), 256, 262)
    img.alpha_composite(layer_down(lambda d, L: sparkles(d, BADGE_SPARKS[:3])))
    return img


@job("BADGE_FirstHeist")
def b_first_heist():
    img = medal_layer("FF7A22")

    def shards(d, L):
        for (x, y, k, a, sc) in [(136, 200, 0, -20, 1.2), (172, 148, 1, 15, 1.0), (128, 268, 2, 40, 0.95),
                                 (236, 128, 3, -10, 0.9), (392, 272, 2, -30, 0.85)]:
            draw_shard(d, x, y, SHARDS[k], a, sc)
    img.alpha_composite(layer_down(shards))
    paste_c(img, load("box_common", 0.50), 246, 304)
    paste_c(img, load("hammer", 0.66), 330, 196, rot=34)
    return img


@job("BADGE_FirstSteal")
def b_first_steal():
    img = medal_layer("A855F7")

    def sym(d, L):
        draw_sack(d, 258, 262, sc=1.0)
        sparkles(d, [(126, 166, 13), (390, 150, 15), (392, 360, 10)])
    img.alpha_composite(layer_down(sym))
    return img


def box_badge(name, color, src, rainbow=None):
    @job(name)
    def _fn():
        img = medal_layer(color, rainbow=rainbow)
        paste_c(img, load(src, 0.62), 256, 266)
        img.alpha_composite(layer_down(lambda d, L: sparkles(d, BADGE_SPARKS)))
        return img
    return _fn


box_badge("BADGE_Mythic", "FF3B5C", "box_mythic")
box_badge("BADGE_Secret", "FFC21A", "box_secret", rainbow=["FF3B3B", "FFC21A", "3BE15A", "2F9BFF", "A855F7"])


@job("BADGE_Zone6")
def b_zone6():
    img = medal_layer("E8A618")
    paste_c(img, load("ingot", 0.92), 232, 244)
    top = new_layer()
    add_label(top, "6", (372, 344), size=190)
    img.alpha_composite(down(top))
    img.alpha_composite(layer_down(lambda d, L: sparkles(d, [(120, 160, 13), (368, 128, 15)])))
    return img


@job("BADGE_Reborn")
def b_reborn():
    img = medal_layer("E05AD8")
    paste_c(img, load("rebirth", 1.10), 256, 262)
    paste_c(img, load("house", 0.44), 256, 264)
    return img


@job("BADGE_Millionaire")
def b_millionaire():
    img = medal_layer("45D63A")
    img.alpha_composite(layer_down(lambda d, L: draw_pile(L, "grosse", 244, 234, 272)))
    top = new_layer()
    add_label(top, "1M/s", (346, 356), size=100)
    img.alpha_composite(down(top))
    return img


COPIES = {
    "UI_Icon_GP_x2Cash": os.path.join(ICONES, "UI_Icon_GP_x2Cash.png"),
    "UI_Icon_GP_x2Training": os.path.join(ICONES, "UI_Icon_GP_x2Training.png"),
    "UI_Icon_GP_AutoCollect": os.path.join(ESSAIS, "UI_Icon_GP_AutoCollect.png"),
    "BADGE_Legendary": os.path.join(ESSAIS, "BADGE_Legendary.png"),
}

ROWS = [
    ("Gamepasses (sceau)", None, ["UI_Icon_GP_x2Cash", "UI_Icon_GP_x2Training", "UI_Icon_GP_DoubleSpeed",
                                  "UI_Icon_GP_AutoCollect", "UI_Icon_GP_FastOpen", "UI_Icon_GP_Displays"]),
    ("Produits (sceau, couleur de la carte)", "une image pour Open Now 1 à 4",
     ["UI_Icon_DP_Cash_1", "UI_Icon_DP_Cash_2", "UI_Icon_DP_Cash_3", "UI_Icon_DP_Cash_4", "UI_Icon_DP_Cash_5",
      "UI_Icon_DP_Cash_6", "UI_Icon_DP_StarterPack", "UI_Icon_DP_OpenNow"]),
    ("Badges (médaille à studs)", None, ["BADGE_Welcome", "BADGE_FirstHeist", "BADGE_FirstSteal", "BADGE_Legendary",
                                         "BADGE_Mythic", "BADGE_Secret", "BADGE_Zone6", "BADGE_Reborn",
                                         "BADGE_Millionaire"]),
]
REPRISES = {"UI_Icon_GP_x2Cash", "UI_Icon_GP_x2Training", "UI_Icon_GP_AutoCollect", "BADGE_Legendary"}


def build_planche():
    BG = (28, 28, 36)
    cell, img_s, small, gap = 272, 220, 100, 40
    W = gap * 2 + 9 * cell
    row_h = 46 + img_s + 10 + small + 34 + 26
    H = 78 + len(ROWS) * row_h + 10
    pl = Image.new("RGBA", (W, H), BG + (255,))
    d = ImageDraw.Draw(pl)
    ft = ImageFont.truetype(FONT_LABEL, 34)
    fr = ImageFont.truetype(FONT_LABEL, 26)
    fn = ImageFont.truetype(FONT_LABEL, 17)
    fnote = ImageFont.truetype(FONT_LABEL, 20)
    d.text((gap, 20), "L-352 : icônes des offres et des badges (26/11)  —  220 px et 100 px ; "
                      "en gris : image reprise telle quelle", font=ft, fill=(235, 235, 245))
    y = 78
    for (title, note, names) in ROWS:
        d.text((gap, y), title, font=fr, fill=(255, 214, 90))
        if note:
            tw = d.textlength(title, font=fr)
            d.text((gap + tw + 24, y + 5), "(" + note + ")", font=fnote, fill=(170, 170, 190))
        yy = y + 46
        for i, name in enumerate(names):
            x = gap + i * cell
            im = Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")
            pl.alpha_composite(im.convert("RGBa").resize((img_s, img_s), Image.LANCZOS).convert("RGBA"), (x, yy))
            pl.alpha_composite(im.convert("RGBa").resize((small, small), Image.LANCZOS).convert("RGBA"),
                               (x + (img_s - small) // 2, yy + img_s + 10))
            col = (150, 150, 165) if name in REPRISES else (220, 220, 232)
            label = name.replace("UI_Icon_", "")
            tw = d.textlength(label, font=fn)
            d.text((x + (img_s - tw) / 2, yy + img_s + 10 + small + 8), label, font=fn, fill=col)
        y += row_h
    pl.convert("RGB").save(os.path.join(OUT, "PLANCHE_offres_completes.png"))
    return pl.size


def main():
    if "--pile-test" in sys.argv:
        pile_test()
        return
    if "--chest-test" in sys.argv:
        chest_test()
        return
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for name, fn in JOBS.items():
        if only and not any(o.lower() in name.lower() for o in only):
            continue
        RMAX.clear()
        fn().save(os.path.join(OUT, name + ".png"))
        r = max(RMAX) if RMAX else 0
        print("écrit", name, "| rayon max des symboles %.0f px%s" % (r, "  <-- TOUCHE LE BORD" if r > 196 else ""))
    for name, src in COPIES.items():
        shutil.copyfile(src, os.path.join(OUT, name + ".png"))
    if not only or "--planche" in sys.argv:
        print("planche", build_planche())


if __name__ == "__main__":
    main()

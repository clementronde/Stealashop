# -*- coding: utf-8 -*-
"""Essais d'icônes 512 x 512 pour L-352 (2026-11-26).

Fabrique, dans le dossier parent (essais_2026-11-26) :
  - UI_Icon_GP_AutoCollect.png  (gamepass, sceau dentelé FFC928, aimant + billets + pile)
  - UI_Icon_DP_Cash_3.png       (produit Cash60 « 1 Hour of Cash », carré 22A85A, pile + « 1H »)
  - BADGE_Legendary.png         (badge, médaille ronde sans dents FFC21A, studs, colis Légendaire)
  - PLANCHE_essais_offres.png   (512, vue Roblox, 100 px ; référence ×2 Cash à côté)

Relançable : python -P build_essais.py   (Pillow + numpy seulement)
Le sceau reprend les mesures de UI_Icon_GP_x2Cash.png (profil des 22 dents, dégradés,
anneau, reflet) ; tout ce qui est dessiné l'est à 4 fois la taille, puis réduit.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ---------------------------------------------------------------- chemins
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)                      # ...\icones\essais_2026-11-26
ICONES = os.path.dirname(OUT)                    # ...\icones (lecture seule)
ART = r"C:\Users\Charment\Documents\StealAShop-Art"
FONT = os.path.join(ART, r"Video\Trailer\_outils\Montserrat-Black.ttf")
FONT_LABEL = r"C:\Windows\Fonts\segoeuib.ttf"
PILE = os.path.join(ART, r"UI\_A_importer\UI_Icon_Cash.png")
BOX_LEG = os.path.join(ART, r"Boxes\Icons\ToImport\ICON_BOX_Legendary.png")
REF_X2 = os.path.join(ICONES, "UI_Icon_GP_x2Cash.png")

N = 512          # taille finale
SS = 4           # suréchantillonnage du dessin
B = N * SS
C = 256.0        # centre

SEAL_DARK = (0x14, 0x14, 0x2B)   # contour du sceau (mesuré)
NAVY = (0x04, 0x04, 0x35)        # contour des objets (colis, couronne, chaussure)
WHITE = (255, 255, 255)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(c, d, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c, d))


def S(v):
    """512 -> espace de dessin."""
    return v * SS


# ---------------------------------------------------------------- outils de calque
def new_layer(size=B):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def down(layer, size=N):
    """Réduction propre (alpha prémultiplié)."""
    return layer.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")


def fill_mask(layer, mask, color, alpha=1.0):
    """Peint `color` (RGB ou image RGB) dans `layer` à travers `mask` (L)."""
    if alpha < 1.0:
        mask = mask.point(lambda v: int(v * alpha))
    if isinstance(color, Image.Image):
        src = color.convert("RGB")
    else:
        src = Image.new("RGB", layer.size, tuple(color))
    src = src.copy()
    src.putalpha(mask)          # couleur pleine, opacité = masque (pas d'assombrissement)
    layer.alpha_composite(src)


def vgrad(base, t_top, t_bot, y0=0.0, y1=float(N), to=WHITE, size=B):
    """Image RGB : base mêlée à `to` de t_top (y0) à t_bot (y1), coordonnées 512."""
    ys = (np.arange(size) + 0.5) / (size / N)
    t = t_top + (t_bot - t_top) * np.clip((ys - y0) / (y1 - y0), 0, 1)
    b = np.array(base, float)
    tgt = np.array(to, float)
    col = b[None, :] + (tgt - b)[None, :] * t[:, None]
    arr = np.repeat(col[:, None, :], size, axis=1)
    return Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8), "RGB")


def circle_mask(r, cx=C, cy=C, size=B):
    m = Image.new("L", (size, size), 0)
    k = size / N
    ImageDraw.Draw(m).ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], fill=255)
    return m


def rrect_mask(x0, y0, x1, y1, rad, size=B):
    m = Image.new("L", (size, size), 0)
    k = size / N
    ImageDraw.Draw(m).rounded_rectangle([x0 * k, y0 * k, x1 * k, y1 * k], radius=rad * k, fill=255)
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
    pts2 = list(pts) + [pts[0]]
    draw.line(pts2, fill=fill, width=int(round(2 * w)), joint="curve")
    for (x, y) in pts:
        draw.ellipse([x - w, y - w, x + w, y + w], fill=fill)


# ---------------------------------------------------------------- sceau dentelé (mesuré sur x2Cash)
SEAL_PHI = np.arange(0, 8.01, 0.5).tolist() + [360 / 44]
SEAL_IN = [215.1, 213.8, 211.55, 209.5, 207.6, 205.45, 203.5, 201.8, 200.5, 199.5,
           198.6, 197.9, 197.2, 196.85, 196.45, 196.25, 196.15, 196.15]
SEAL_OUT = [232.2, 232.0, 231.55, 230.8, 229.8, 228.2, 226.3, 224.25, 222.0, 220.0,
            218.05, 216.2, 214.4, 213.15, 212.25, 211.75, 211.6, 211.6]
DISC_R = 174.5           # disque intérieur
RING = (174.5, 180.5)    # fin anneau sombre (14142B à 35 %)
RING_ALPHA = 0.35
HL = dict(cx=236, cy=129, a=110, b=35, rot=0.0, alpha=0.28)   # reflet (ajusté au pixel)


def seal_pts(table, n_per_tooth=240):
    P = 360 / 22
    th = np.linspace(0, 360, 22 * n_per_tooth, endpoint=False)
    ph = np.abs(((th - 90 + P / 2) % P) - P / 2)
    r = np.interp(ph, SEAL_PHI, table)
    x = (C + r * np.cos(np.radians(th))) * SS
    y = (C - r * np.sin(np.radians(th))) * SS
    return list(zip(x.tolist(), y.tolist()))


def band_grad(base):
    # mesuré : blanc 34 % en haut -> 1 % en bas (linéaire en y)
    return vgrad(base, 0.357, 0.357 - 0.000714 * N)


DISC_T = (0.40, 0.40 - 0.00027 * N)     # disque : blanc 40 % en haut -> 26 % en bas (mesuré)


def disc_grad(base, t=DISC_T):
    return vgrad(base, t[0], t[1])


def highlight_mask(clip, h=None):
    h = h or HL
    m = Image.new("L", (B, B), 0)
    ImageDraw.Draw(m).ellipse([S(h["cx"] - h["a"]), S(h["cy"] - h["b"]),
                               S(h["cx"] + h["a"]), S(h["cy"] + h["b"])], fill=255)
    if h.get("rot"):
        m = m.rotate(h["rot"], resample=Image.BICUBIC, center=(S(h["cx"]), S(h["cy"])))
    return mask_mul(m, clip)


def glow_mask(cx, cy, r, clip):
    """Lueur ronde douce (1 au centre -> 0 au rayon r)."""
    yy, xx = np.mgrid[0:B, 0:B]
    d = np.hypot(xx / SS - cx, yy / SS - cy) / r
    del yy, xx
    g = np.clip(1.0 - d, 0, 1) ** 1.6
    return Image.fromarray((g * np.array(clip, float)).astype(np.uint8), "L")


def inner_parts(layer, base, disc_mask, ring_mask, hl_clip, extra=None, disc_t=DISC_T, hl=None, glow=None):
    """Disque clair, (lueur, rayons), fin anneau sombre, reflet : commun aux trois cadres.
    Comme sur x2Cash, le reflet passe par-dessus l'anneau et déborde sur la bande."""
    fill_mask(layer, disc_mask, disc_grad(base, disc_t))
    if glow:
        gx, gy, gr, ga = glow
        fill_mask(layer, glow_mask(gx, gy, gr, disc_mask), WHITE, ga)
    if extra:
        extra(layer, disc_mask)
    fill_mask(layer, ring_mask, SEAL_DARK, RING_ALPHA)
    h = hl or HL
    fill_mask(layer, highlight_mask(hl_clip, h), WHITE, h["alpha"])


def seal_layer(base, rays=None):
    base = hexrgb(base) if isinstance(base, str) else base
    L = new_layer()
    fill_mask(L, poly_mask(seal_pts(SEAL_OUT)), SEAL_DARK)
    band = poly_mask(seal_pts(SEAL_IN))
    fill_mask(L, band, band_grad(base))
    disc = circle_mask(RING[1])          # le disque passe sous l'anneau
    ring = mask_sub(circle_mask(RING[1]), circle_mask(RING[0]))
    inner_parts(L, base, disc, ring, band, rays)
    return down(L)


# ---------------------------------------------------------------- cadres carré (produits) et médaille (badges)
SQ = dict(m=10, rad=28, stroke=18, band=30, ring=6)   # marge, coin ext. (5,5 %), contour, bande, anneau


SQ_HL = dict(cx=256, cy=60, a=250, b=58, alpha=0.22)   # reflet du carré : bande vitrée en haut


def square_layer(base, rays=None, disc_t=DISC_T, glow=None):
    base = hexrgb(base) if isinstance(base, str) else base
    q = SQ
    o0, o1 = q["m"], N - q["m"]
    b0, b1 = o0 + q["stroke"], o1 - q["stroke"]
    r0, r1 = b0 + q["band"], b1 - q["band"]            # bord extérieur de l'anneau
    p0, p1 = r0 + q["ring"], r1 - q["ring"]            # panneau clair
    L = new_layer()
    fill_mask(L, rrect_mask(o0, o0, o1, o1, q["rad"]), SEAL_DARK)
    band = rrect_mask(b0, b0, b1, b1, q["rad"] - q["stroke"] * 0.6)
    fill_mask(L, band, band_grad(base))
    panel_out = rrect_mask(r0, r0, r1, r1, 10)
    ring = mask_sub(panel_out, rrect_mask(p0, p0, p1, p1, 6))
    inner_parts(L, base, panel_out, ring, panel_out, rays, disc_t=disc_t, hl=SQ_HL, glow=glow)
    return down(L)


MED = dict(outer=232.0, band=214.0, studs=28, stud_r=8.6, stud_at=197.3)


def medal_layer(base, rays=None, disc_t=DISC_T, glow=None):
    base = hexrgb(base) if isinstance(base, str) else base
    L = new_layer()
    fill_mask(L, circle_mask(MED["outer"]), SEAL_DARK)
    band = circle_mask(MED["band"])
    fill_mask(L, band, band_grad(base))
    # anneau de studs (style Roblox) : ombre en bas à droite, corps plus clair, croissant de lumière
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
    fill_mask(L, sh, mix(base, SEAL_DARK, 0.42))
    fill_mask(L, body, vgrad(base, 0.50, 0.16))
    fill_mask(L, lit, WHITE, 0.75)
    disc = circle_mask(RING[1])
    ring = mask_sub(circle_mask(RING[1]), circle_mask(RING[0]))
    inner_parts(L, base, disc, ring, band, rays, disc_t=disc_t, glow=glow)
    return down(L)


def rays_fn(cx, cy, n=16, alpha=0.18, phase=0.0, r_fade=(40, 230)):
    """Rayons doux (blancs, fondus vers le bord) peints dans le disque ou le panneau."""
    def _draw(layer, clip):
        m = Image.new("L", (B, B), 0)
        d = ImageDraw.Draw(m)
        R = 600
        for k in range(n):
            a0 = math.radians(phase + 360 * k / n)
            a1 = math.radians(phase + 360 * (k + 0.5) / n)
            d.polygon([(S(cx), S(cy)),
                       (S(cx + R * math.cos(a0)), S(cy + R * math.sin(a0))),
                       (S(cx + R * math.cos(a1)), S(cy + R * math.sin(a1)))], fill=255)
        yy, xx = np.mgrid[0:B, 0:B]
        rr = np.hypot(xx / SS - cx, yy / SS - cy)
        fade = np.clip(1.0 - (rr - r_fade[0]) / (r_fade[1] - r_fade[0]), 0.25, 1.0)
        del yy, xx, rr
        mm = (np.array(m, float) * fade * (np.array(clip, float) / 255)).astype(np.uint8)
        fill_mask(layer, Image.fromarray(mm, "L"), WHITE, alpha)
    return _draw


# ---------------------------------------------------------------- chiffre (style ×2 des gamepasses)
LBL = dict(size=145, stroke=20, shadow=(-5, 9), angle=8)


def label_layer(text, size=None, stroke=None, shadow=None, angle=None, track=0.0):
    """Montserrat Black blanc, gros contour 14142B, ombre pleine, penché de 8°.
    Rend (calque en espace SS, ancrage = centre du blanc en unités 512)."""
    size = size or LBL["size"]
    stroke = LBL["stroke"] if stroke is None else stroke
    shadow = shadow or LBL["shadow"]
    angle = LBL["angle"] if angle is None else angle
    f = ImageFont.truetype(FONT, int(size * SS))
    sw = int(stroke * SS)
    pad = int((stroke + 30) * SS)
    xs, x = [], 0.0
    for ch in text:                      # lettres posées une à une (approche réglable)
        xs.append(x)
        x += f.getlength(ch) + track * SS
    W = int(x + 2 * pad)
    asc, desc = f.getmetrics()
    H = int(asc + desc + 2 * pad)
    fillw = Image.new("L", (W, H), 0)
    full = Image.new("L", (W, H), 0)
    dw, df = ImageDraw.Draw(fillw), ImageDraw.Draw(full)
    for ch, xx in zip(text, xs):
        df.text((pad + xx, pad), ch, font=f, fill=255, stroke_width=sw, stroke_fill=255)
        dw.text((pad + xx, pad), ch, font=f, fill=255)
    fillw = fillw.rotate(angle, resample=Image.BICUBIC, expand=True)
    full = full.rotate(angle, resample=Image.BICUBIC, expand=True)
    W, H = full.size
    sx, sy = int(shadow[0] * SS), int(shadow[1] * SS)
    pad2 = int(20 * SS)
    out = Image.new("RGBA", (W + 2 * pad2, H + 2 * pad2), (0, 0, 0, 0))
    sil = Image.new("RGBA", full.size, SEAL_DARK + (0,))
    sil.putalpha(full)
    out.alpha_composite(sil, (pad2 + sx, pad2 + sy))
    out.alpha_composite(sil, (pad2, pad2))
    wt = Image.new("RGBA", full.size, WHITE + (0,))
    wt.putalpha(fillw)
    out.alpha_composite(wt, (pad2, pad2))
    bb = fillw.getbbox()
    cx = (pad2 + (bb[0] + bb[2]) / 2) / SS
    cy = (pad2 + (bb[1] + bb[3]) / 2) / SS
    return out, (cx, cy)


def place_ss(canvas_ss, layer_ss, center_512, anchor_512):
    """Colle un calque (espace SS) pour que son point d'ancrage tombe sur center_512."""
    x = int(round(S(center_512[0] - anchor_512[0])))
    y = int(round(S(center_512[1] - anchor_512[1])))
    cx0, cy0 = max(0, -x), max(0, -y)
    src = layer_ss.crop((cx0, cy0, layer_ss.width, layer_ss.height))
    canvas_ss.alpha_composite(src, (max(0, x), max(0, y)))


# ---------------------------------------------------------------- petits dessins (style autocollant)
def sparkle(draw, cx, cy, R, fill=(0xFF, 0xF4, 0xC8), outline=NAVY, ow=4.5, k=2.6):
    """Étoile à 4 branches aux côtés creusés, contour bleu nuit."""
    pts = []
    for i in range(96):
        t = 2 * math.pi * i / 96
        c, s_ = math.cos(t), math.sin(t)
        x = R * math.copysign(abs(c) ** k, c)
        y = R * math.copysign(abs(s_) ** k, s_)
        pts.append((S(cx + x), S(cy + y)))
    stroke_poly(draw, pts, S(ow), outline)
    draw.polygon(pts, fill=fill)


def xf(pts, cx, cy, ang, sc=1.0, off=(0.0, 0.0)):
    a = math.radians(ang)
    c, s_ = math.cos(a), math.sin(a)
    return [(S(cx + (x * c - y * s_) * sc + off[0]), S(cy + (x * s_ + y * c) * sc + off[1])) for x, y in pts]


def arc_pts(r, a0, a1, n=48):
    """Points d'un arc (angles en degrés, 0 = droite, 90 = haut ; y vers le bas)."""
    return [(r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             -r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def u_shape(Ro, Ri, L0):
    """Fer à cheval ouvert vers le bas (+y) : arc + deux jambes jusqu'à y = L0."""
    return arc_pts(Ro, 180, 0) + [(Ro, L0), (Ri, L0)] + arc_pts(Ri, 0, 180) + [(-Ri, L0), (-Ro, L0)]


def band_pts(Ro, Ri, a0, a1, n=40):
    return arc_pts(Ro, a0, a1, n) + arc_pts(Ri, a1, a0, n)


MAG = dict(cx=320, cy=186, ang=45, Ro=78, Ri=35, L=60, T=25, ext=(5.5, 9.0), ow=8.5)
RED, RED_LIGHT, RED_SIDE, RED_DEEP = hexrgb("E8343C"), hexrgb("FF7068"), hexrgb("9E1430"), hexrgb("C21F35")
SILVER, SILVER_SH, SILVER_SIDE = hexrgb("F2F4FA"), hexrgb("C3CADB"), hexrgb("7F89A6")


def dot(d, p, r):
    d.ellipse([p[0] - S(r), p[1] - S(r), p[0] + S(r), p[1] + S(r)], fill=WHITE)


def draw_magnet(layer, m=None):
    m = m or MAG
    d = ImageDraw.Draw(layer)
    cx, cy, ang = m["cx"], m["cy"], m["ang"]
    Ro, Ri, L, T = m["Ro"], m["Ri"], m["L"], m["T"]
    ex, ey = m["ext"]
    full = u_shape(Ro, Ri, L)
    red = u_shape(Ro, Ri, L - T)
    tipL = [(-Ro, L - T), (-Ri, L - T), (-Ri, L), (-Ro, L)]
    tipR = [(Ri, L - T), (Ro, L - T), (Ro, L), (Ri, L)]
    steps = 10
    # 1) silhouette + contour (balayage de l'épaisseur)
    for i in range(steps + 1):
        t = i / steps
        stroke_poly(d, xf(full, cx, cy, ang, off=(ex * t, ey * t)), S(m["ow"]), NAVY)
    # 2) côtés (épaisseur)
    for i in range(steps, 0, -1):
        t = i / steps
        off = (ex * t, ey * t)
        d.polygon(xf(red, cx, cy, ang, off=off), fill=RED_SIDE)
        d.polygon(xf(tipL, cx, cy, ang, off=off), fill=SILVER_SIDE)
        d.polygon(xf(tipR, cx, cy, ang, off=off), fill=SILVER_SIDE)
    # 3) face avant
    d.polygon(xf(red, cx, cy, ang), fill=RED)
    d.polygon(xf(tipL, cx, cy, ang), fill=SILVER)
    d.polygon(xf(tipR, cx, cy, ang), fill=SILVER)
    w = Ro - Ri
    # ombre propre : bord intérieur de l'arc et jambe droite (loin de la lumière)
    d.polygon(xf(band_pts(Ri + w * 0.28, Ri, -2, 120), cx, cy, ang), fill=RED_DEEP)
    d.polygon(xf([(Ri, 0), (Ri + w * 0.28, 0), (Ri + w * 0.28, L - T), (Ri, L - T)], cx, cy, ang), fill=RED_DEEP)
    d.polygon(xf([(Ri, L - T), (Ri + w * 0.30, L - T), (Ri + w * 0.30, L), (Ri, L)], cx, cy, ang), fill=SILVER_SH)
    d.polygon(xf([(-Ro + w * 0.70, L - T), (-Ri, L - T), (-Ri, L), (-Ro + w * 0.70, L)], cx, cy, ang), fill=SILVER_SH)
    # lumière : bord extérieur gauche (haut-gauche à l'écran)
    hl_o, hl_i = Ro - w * 0.12, Ro - w * 0.36
    d.polygon(xf(band_pts(hl_o, hl_i, 178, 92), cx, cy, ang), fill=RED_LIGHT)
    d.polygon(xf([(-hl_o, 0), (-hl_i, 0), (-hl_i, L - T - 7), (-hl_o, L - T - 7)], cx, cy, ang), fill=RED_LIGHT)
    # reflets blancs (traits arrondis)
    rr = (hl_o + hl_i) / 2
    spec = xf(arc_pts(rr, 168, 128, 20), cx, cy, ang)
    d.line(spec, fill=WHITE, width=int(S(5.5)), joint="curve")
    for p in (spec[0], spec[-1]):
        dot(d, p, 2.75)
    dot(d, xf([(rr * math.cos(math.radians(116)), -rr * math.sin(math.radians(116)))], cx, cy, ang)[0], 3)
    a = xf([(-(Ro - w * 0.24), L - T + 6), (-(Ro - w * 0.24), L - 6)], cx, cy, ang)
    d.line(a, fill=WHITE, width=int(S(5)))
    for p in a:
        dot(d, p, 2.5)
    # joints rouge / argent (trait bleu nuit fin)
    for sx in (-1, 1):
        d.line(xf([(sx * Ro, L - T), (sx * Ri, L - T)], cx, cy, ang), fill=NAVY, width=int(S(4)))


BILL = dict(w=66, h=36, wave=3.6, ext=(3.0, 5.0), ow=6.5)
B_FACE, B_EDGE, B_SIDE, B_LIGHT = hexrgb("39B54A"), hexrgb("009245"), hexrgb("006837"), hexrgb("8FE07E")


def bill_pts(w, h, wave, inset=0.0, n=24):
    top, bot = [], []
    for i in range(n + 1):
        u = -w / 2 + inset + (w - 2 * inset) * i / n
        dy = wave * math.sin(2 * math.pi * (u / w))
        top.append((u, -h / 2 + inset + dy))
        bot.append((u, h / 2 - inset + dy))
    return top + bot[::-1]


def draw_bill(layer, cx, cy, ang, sc=1.0, b=None):
    b = b or BILL
    d = ImageDraw.Draw(layer)
    w, h, wave = b["w"] * sc, b["h"] * sc, b["wave"] * sc
    ex, ey = b["ext"][0] * sc, b["ext"][1] * sc
    body = bill_pts(w, h, wave)
    steps = 6
    for i in range(steps + 1):
        t = i / steps
        stroke_poly(d, xf(body, cx, cy, ang, off=(ex * t, ey * t)), S(b["ow"] * sc), NAVY)
    for i in range(steps, 0, -1):
        t = i / steps
        d.polygon(xf(body, cx, cy, ang, off=(ex * t, ey * t)), fill=B_SIDE)
    d.polygon(xf(body, cx, cy, ang), fill=B_FACE)
    inner = xf(bill_pts(w, h, wave, inset=5.0 * sc), cx, cy, ang)
    d.line(inner + [inner[0]], fill=B_EDGE, width=int(S(3.2 * sc)), joint="curve")
    oval = []                            # médaillon central
    for i in range(40):
        t = 2 * math.pi * i / 40
        u = 8.5 * sc * math.cos(t)
        oval.append((u, 10.5 * sc * math.sin(t) + wave * math.sin(2 * math.pi * (u / w))))
    d.polygon(xf(oval, cx, cy, ang), fill=B_EDGE)
    # coin de lumière + reflet
    d.polygon(xf([(-w / 2 + 2 * sc, -h / 2 + 2 * sc), (-w / 2 + 16 * sc, -h / 2 + 2 * sc),
                  (-w / 2 + 2 * sc, -h / 2 + 12 * sc)], cx, cy, ang), fill=B_LIGHT)
    a = xf([(-w / 2 + 12 * sc, -h / 2 + 9 * sc - wave * 0.9), (-w / 2 + 24 * sc, -h / 2 + 8 * sc - wave * 0.8)], cx, cy, ang)
    d.line(a, fill=WHITE, width=int(S(3.6 * sc)))


def speed_wedge(draw, x0, y0, x1, y1, w0, ow=5.0):
    """Traînée : coin allongé de (x0,y0) (large w0) à la pointe (x1,y1), blanc + bas bleuté."""
    dx, dy = x1 - x0, y1 - y0
    Lg = math.hypot(dx, dy)
    nx, ny = -dy / Lg, dx / Lg
    p0 = (x0 + nx * w0 / 2, y0 + ny * w0 / 2)
    p1 = (x0 - nx * w0 / 2, y0 - ny * w0 / 2)
    pts = [(S(p0[0]), S(p0[1])), (S(x1), S(y1)), (S(p1[0]), S(p1[1]))]
    stroke_poly(draw, pts, S(ow), NAVY)
    draw.polygon(pts, fill=(0xDD, 0xE8, 0xFF))
    draw.polygon([(S(p0[0]), S(p0[1])), (S(x1), S(y1)), (S(x0), S(y0))], fill=WHITE)


def bezier(p0, p1, p2, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def swoosh(draw, p0, p1, p2, w_head, w_tail=1.5, ow=4.5, fill=WHITE, shade=(0xDD, 0xE8, 0xFF)):
    """Traînée courbe effilée (tête large en p2, queue fine en p0), blanche, contour bleu nuit."""
    path = bezier(p0, p1, p2, 40)
    left, right = [], []
    n = len(path)
    for i, (x, y) in enumerate(path):
        j0, j1 = max(0, i - 1), min(n - 1, i + 1)
        tx, ty = path[j1][0] - path[j0][0], path[j1][1] - path[j0][1]
        tl = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / tl, tx / tl
        u = i / (n - 1)
        w = w_tail + (w_head - w_tail) * (u ** 0.8)
        left.append((x + nx * w / 2, y + ny * w / 2))
        right.append((x - nx * w / 2, y - ny * w / 2))
    poly = [(S(x), S(y)) for x, y in left + right[::-1]]
    stroke_poly(draw, poly, S(ow), NAVY)
    draw.polygon(poly, fill=shade)
    half = [(S(x), S(y)) for x, y in left + path[::-1]]
    draw.polygon(half, fill=fill)


def capsule(draw, p0, p1, w, ow=4.5, fill=WHITE):
    """Trait de vitesse : bâton arrondi blanc, contour bleu nuit."""
    a = [(S(p0[0]), S(p0[1])), (S(p1[0]), S(p1[1]))]
    for width, col in ((w + 2 * ow, NAVY), (w, fill)):
        r = S(width / 2)
        draw.line(a, fill=col, width=int(S(width)))
        for (x, y) in a:
            draw.ellipse([x - r, y - r, x + r, y + r], fill=col)


def motion_lines(draw, cx, cy, ang_deg, specs, w=7.0):
    """Traits derrière un objet qui va dans la direction ang_deg (0 = droite, y vers le bas).
    specs : (recul du début, longueur, décalage latéral)."""
    a = math.radians(ang_deg)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    for back, length, lat in specs:
        x0 = cx - dx * back + nx * lat
        y0 = cy - dy * back + ny * lat
        capsule(draw, (x0, y0), (x0 - dx * length, y0 - dy * length), w)


# ---------------------------------------------------------------- images sources
def load_scaled(path, scale):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    im = im.convert("RGBa").resize((int(round(w * scale)), int(round(h * scale))), Image.LANCZOS).convert("RGBA")
    if scale > 1.0:   # agrandi : petit renfort de netteté
        im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    return im


def paste_center(canvas, im, cx, cy):
    """Colle `im` (espace 512) pour que le centre de son contenu tombe sur (cx, cy)."""
    bb = im.getbbox()
    ox = int(round(cx - (bb[0] + bb[2]) / 2))
    oy = int(round(cy - (bb[1] + bb[3]) / 2))
    canvas.alpha_composite(im, (ox, oy))


# ---------------------------------------------------------------- 1. gamepass Auto Collect
AC = dict(pile_scale=1.6, pile_c=(194, 337),
          magnet=dict(cx=314, cy=188, ang=45, Ro=93, Ri=42, L=64, T=29, ext=(8.0, 12.5), ow=9.0),
          # billets : (x, y, angle, échelle)
          bills=[(164, 196, -8, 1.08), (254, 258, -42, 1.08)],
          # traits de vitesse : (x, y, direction du mouvement, [(recul, longueur, décalage)])
          lines=[(164, 196, -4, [(48, 28, -9), (50, 16, 10)])],
          sparkles=[(410, 300, 17), (150, 122, 12), (330, 372, 10)])


def build_autocollect():
    img = seal_layer("FFC928")
    pile = load_scaled(PILE, AC["pile_scale"])
    paste_center(img, pile, *AC["pile_c"])
    top = new_layer()
    d = ImageDraw.Draw(top)
    for (x, y, a, specs) in AC["lines"]:
        motion_lines(d, x, y, a, specs)
    for (x, y, a, sc) in AC["bills"]:
        draw_bill(top, x, y, a, sc)
    draw_magnet(top, AC["magnet"])
    for (x, y, r) in AC["sparkles"]:
        sparkle(d, x, y, r)
    img.alpha_composite(down(top))
    return img


# ---------------------------------------------------------------- 2. produit 1 Hour of Cash
DP = dict(pile_scale=1.6, pile_c=(240, 234), label="1H", label_size=128, label_c=(372, 386), rays_c=(240, 238),
          disc_t=(0.56, 0.38), glow=(240, 238, 175, 0.62),
          sparkles=[(126, 120, 13), (372, 128, 10), (120, 380, 9)])


def build_cash3():
    img = square_layer("22A85A", rays=rays_fn(*DP["rays_c"], n=16, alpha=0.24, phase=4, r_fade=(30, 250)),
                       disc_t=DP["disc_t"], glow=DP["glow"])
    pile = load_scaled(PILE, DP["pile_scale"])
    paste_center(img, pile, *DP["pile_c"])
    top = new_layer()
    d = ImageDraw.Draw(top)
    for (x, y, r) in DP["sparkles"]:
        sparkle(d, x, y, r)
    lay, anc = label_layer(DP["label"], size=DP["label_size"])
    place_ss(top, lay, DP["label_c"], anc)
    img.alpha_composite(down(top))
    return img


# ---------------------------------------------------------------- 3. badge Legendary
BD = dict(box_scale=0.62, box_c=(256, 266), disc_t=(0.60, 0.40), glow=(256, 262, 175, 0.55),
          sparkles=[(378, 148, 18), (116, 178, 13), (380, 362, 11), (150, 380, 9)])


def build_badge():
    img = medal_layer("FFC21A", rays=rays_fn(256, 266, n=16, alpha=0.30, phase=0, r_fade=(60, 190)),
                      disc_t=BD["disc_t"], glow=BD["glow"])
    box = load_scaled(BOX_LEG, BD["box_scale"])
    paste_center(img, box, *BD["box_c"])
    top = new_layer()
    d = ImageDraw.Draw(top)
    for (x, y, r) in BD["sparkles"]:
        sparkle(d, x, y, r)
    img.alpha_composite(down(top))
    return img


# ---------------------------------------------------------------- planche
BG = (28, 28, 36)
TILE = (57, 59, 61)      # fond des vignettes Roblox (thème sombre)


def roblox_view(img, shape, size=256):
    v = img.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")
    tile = Image.new("RGBA", (size, size), TILE + (255,))
    tile.alpha_composite(v)
    m = Image.new("L", (size * 4, size * 4), 0)
    dm = ImageDraw.Draw(m)
    if shape == "circle":
        dm.ellipse([0, 0, size * 4 - 1, size * 4 - 1], fill=255)
    else:
        dm.rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * 0.03), fill=255)
    tile.putalpha(m.resize((size, size), Image.LANCZOS))
    return tile


def build_planche(items):
    """items : liste de (titre, image 512, forme)."""
    gap, top = 40, 70
    W = gap + len(items) * (N + gap)
    H = top + 40 + N + 24 + 34 + 256 + gap
    pl = Image.new("RGBA", (W, H), BG + (255,))
    d = ImageDraw.Draw(pl)
    ft = ImageFont.truetype(FONT_LABEL, 34)
    fl = ImageFont.truetype(FONT_LABEL, 24)
    fs = ImageFont.truetype(FONT_LABEL, 20)
    d.text((gap, 18), "L-352 : essais d'icônes d'offres (26/11)  —  512 px / comme sur Roblox / 100 et 50 px",
           font=ft, fill=(235, 235, 245))
    for i, (title, img, shape) in enumerate(items):
        x = gap + i * (N + gap)
        d.text((x, top), title, font=fl, fill=(255, 214, 90) if i else (170, 170, 190))
        pl.alpha_composite(img, (x, top + 40))
        y2 = top + 40 + N + 24
        d.text((x, y2), "Comme sur Roblox (" + ("cercle" if shape == "circle" else "carré") + ")",
               font=fs, fill=(200, 200, 215))
        pl.alpha_composite(roblox_view(img, shape), (x, y2 + 34))
        d.text((x + 256 + 40, y2), "À 100 px", font=fs, fill=(200, 200, 215))
        pl.alpha_composite(img.convert("RGBa").resize((100, 100), Image.LANCZOS).convert("RGBA"), (x + 256 + 40, y2 + 34))
        d.text((x + 256 + 40, y2 + 34 + 112), "À 50 px", font=fs, fill=(150, 150, 165))
        pl.alpha_composite(img.convert("RGBa").resize((50, 50), Image.LANCZOS).convert("RGBA"), (x + 256 + 40, y2 + 34 + 146))
    return pl


def main():
    if "--seal-test" in sys.argv:
        img = seal_layer("45D63A")
        img.save(os.path.join(HERE, "_test_seal.png"))
        ref = np.array(Image.open(REF_X2).convert("RGBA")).astype(int)
        me = np.array(img).astype(int)
        yy, xx = np.mgrid[0:N, 0:N]
        zone = (xx < 200) & (yy < 250) | (yy < 120)
        dd = np.abs(ref - me)[zone]
        print("écart moyen (zone libre) RGBA :", dd.mean(0).round(2), "max", dd.max(0))
        return
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    out = {}
    jobs = [("UI_Icon_GP_AutoCollect.png", build_autocollect),
            ("UI_Icon_DP_Cash_3.png", build_cash3),
            ("BADGE_Legendary.png", build_badge)]
    for name, fn in jobs:
        path = os.path.join(OUT, name)
        if not only or any(o in name for o in only):
            fn().save(path)
            print("écrit", path)
        out[name] = Image.open(path).convert("RGBA") if os.path.exists(path) else None
    if all(v is not None for v in out.values()):
        ref = Image.open(REF_X2).convert("RGBA")
        pl = build_planche([("Référence : ×2 Cash (existante)", ref, "circle"),
                            ("Gamepass Auto Collect", out["UI_Icon_GP_AutoCollect.png"], "circle"),
                            ("Produit 1 Hour of Cash", out["UI_Icon_DP_Cash_3.png"], "square"),
                            ("Badge Legendary", out["BADGE_Legendary.png"], "circle")])
        pl.convert("RGB").save(os.path.join(OUT, "PLANCHE_essais_offres.png"))
        print("écrit planche", pl.size)


if __name__ == "__main__":
    main()

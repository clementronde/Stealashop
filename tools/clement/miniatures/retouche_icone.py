# Retouche de l'icône « La casse » (MOD-043, 2026-11-21) à partir de 2 captures Studio du même cadrage :
#   brut.png  : la scène telle qu'elle est rendue dans Studio ;
#   matte.png : la même, avec le perso et la masse (copies) en néon vert pur et la Couronne en néon magenta pur,
#               pour en tirer les masques.
# Rien n'est dessiné qui ne soit pas dans le jeu : recadrage, lumière (+12 %), flou léger du décor, contour
# sombre de l'UI (#1B1B24), halo de la Couronne renforcé (il existe en jeu), flash blanc d'impact (le jeu en
# fait un de 80 ms à la casse).
# Lancer : py -I tools/clement/miniatures/retouche_icone.py <dossier> <x> <y> <côté> [<impact_x> <impact_y>]
#   x y côté : carré à garder (pixels de la capture) ; impact_x impact_y : point d'impact (pixels de la capture).
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

INK = (27, 27, 36)
EPIC = (168, 85, 247)


def chroma(img, kind):
    """Masque des pixels néon vert (perso) ou magenta (couronne) de la capture matte."""
    r, g, b = img.convert("RGB").split()
    if kind == "green":
        m = ImageChops.subtract(g, ImageChops.lighter(r, b))  # G - max(R, B)
    else:
        m = ImageChops.subtract(ImageChops.darker(r, b), g)  # min(R, B) - G
    # seuil haut : seul le néon pur passe (le violet du halo Épique, lui, ne passe pas)
    m = m.point(lambda v: 255 if v > 140 else 0)
    return m.filter(ImageFilter.MedianFilter(5))


def grow(mask, px):
    """Dilate un masque d'environ px pixels, bords arrondis."""
    m = mask.filter(ImageFilter.GaussianBlur(px * 0.55))
    return m.point(lambda v: 255 if v > 18 else 0).filter(ImageFilter.GaussianBlur(1))


def vignette(size, strength=0.55):
    w, h = size
    v = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(v)
    steps = 60
    for i in range(steps):
        t = i / steps
        a = int(255 * strength * (1 - t) ** 2)
        d.ellipse((-w * 0.25 + t * w * 0.38, -h * 0.25 + t * h * 0.38, w * 1.25 - t * w * 0.38, h * 1.25 - t * h * 0.38), outline=a, width=int(max(w, h) / steps) + 2)
    return v.filter(ImageFilter.GaussianBlur(max(w, h) / 30))


def flash(size, center, radius):
    """Flash blanc d'impact : halo radial + 8 rayons fins."""
    w, h = size
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    cx, cy = center
    for i in range(30, 0, -1):
        r = radius * i / 30
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=int(235 * (1 - i / 30) ** 1.6))
    for k in range(8):
        a = k * math.pi / 4 + 0.2
        L = radius * (2.2 if k % 2 == 0 else 1.5)
        p = [(cx + L * math.cos(a), cy + L * math.sin(a)),
             (cx + radius * 0.12 * math.cos(a + 1.57), cy + radius * 0.12 * math.sin(a + 1.57)),
             (cx + radius * 0.12 * math.cos(a - 1.57), cy + radius * 0.12 * math.sin(a - 1.57))]
        d.polygon(p, fill=170)
    return m.filter(ImageFilter.GaussianBlur(radius * 0.06))


def main():
    folder = sys.argv[1]
    x, y, s = (int(v) for v in sys.argv[2:5])
    impact = (int(sys.argv[5]) - x, int(sys.argv[6]) - y) if len(sys.argv) >= 7 else None
    brut = Image.open(os.path.join(folder, "brut.png")).convert("RGB").crop((x, y, x + s, y + s))
    matte = Image.open(os.path.join(folder, "matte.png")).convert("RGB").crop((x, y, x + s, y + s))
    k = s / 512  # les tailles sont données pour l'icône finale en 512
    hero = chroma(matte, "green")
    crown = chroma(matte, "magenta")

    # 1. lumière : contraste et saturation un peu poussés (+12 %), l'image reste le jeu
    base = ImageEnhance.Color(ImageEnhance.Contrast(brut).enhance(1.12)).enhance(1.12)
    # 2. décor de la rue légèrement flou (profondeur) : net = perso, couronne et zone de l'impact
    sharp = ImageChops.lighter(grow(hero, 14 * k), grow(crown, 10 * k))
    if impact:
        ImageDraw.Draw(sharp).ellipse((impact[0] - 90 * k, impact[1] - 90 * k, impact[0] + 90 * k, impact[1] + 90 * k), fill=255)
    sharp = sharp.filter(ImageFilter.GaussianBlur(10 * k))
    back = base.filter(ImageFilter.GaussianBlur(3.2 * k))
    # le décor recule : un peu plus sombre et tiré vers le bleu du ciel du jeu (#8FD0FF -> nuit #2C2163)
    back = Image.blend(back, Image.new("RGB", back.size, (44, 33, 99)), 0.28)
    img = Image.composite(base, back, sharp)
    # 3. vignette sombre vers les bords
    img = Image.composite(Image.new("RGB", img.size, (14, 18, 44)), img, vignette(img.size, 0.7))
    # 4. halo Épique de la Couronne renforcé, autour d'elle seulement (elle reste dorée)
    glow = crown.filter(ImageFilter.GaussianBlur(34 * k)).point(lambda v: min(255, int(v * 1.7)))
    glow = ImageChops.multiply(glow, ImageChops.invert(crown)).point(lambda v: int(v * 0.6))
    img = Image.composite(Image.new("RGB", img.size, EPIC), img, glow)
    crown_lit = ImageEnhance.Brightness(ImageEnhance.Color(brut).enhance(1.25)).enhance(1.1)
    img = Image.composite(crown_lit, img, crown)
    # 5. flash blanc au point d'impact
    if impact:
        img = Image.composite(Image.new("RGB", img.size, (255, 255, 255)), img, flash(img.size, impact, 70 * k))
    # 6. contour sombre de 9 px (à 512) autour du perso et de la masse, 6 px autour de la couronne
    img = Image.composite(Image.new("RGB", img.size, INK), img, ImageChops.subtract(grow(crown, 6 * k), crown))
    img = Image.composite(Image.new("RGB", img.size, INK), img, grow(hero, 9 * k))
    img = Image.composite(ImageEnhance.Brightness(ImageEnhance.Color(ImageEnhance.Contrast(brut).enhance(1.15)).enhance(1.15)).enhance(1.06), img, hero)

    out = img.resize((512, 512), Image.LANCZOS)
    out.save(os.path.join(folder, "ICON_StealAShop_v1.png"))
    out.resize((150, 150), Image.LANCZOS).save(os.path.join(folder, "controle_150px.png"))
    out.resize((64, 64), Image.LANCZOS).save(os.path.join(folder, "controle_64px.png"))
    # planche de contrôle : 512, 150 et 64 px aux coins arrondis, cercle de 440 px
    sheet = Image.new("RGB", (512 + 40 + 150 + 30 + 64 + 40, 552), (245, 246, 250))
    m = Image.new("L", (512, 512), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 511, 511), radius=46, fill=255)
    sheet.paste(out, (20, 20), m)
    for size, px, rr in ((150, 572, 14), (64, 752, 7)):
        t = out.resize((size, size), Image.LANCZOS)
        mm = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mm).rounded_rectangle((0, 0, size - 1, size - 1), radius=rr, fill=255)
        sheet.paste(t, (px, 20), mm)
    ImageDraw.Draw(sheet).ellipse((20 + 36, 20 + 36, 20 + 476, 20 + 476), outline=(255, 255, 255), width=2)
    sheet.save(os.path.join(folder, "controle_planche.png"))
    print("ok", folder, "carré", (x, y, s), "impact", impact)


if __name__ == "__main__":
    main()

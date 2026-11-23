# Finit une icône carrée en 512 × 512 à partir d'une image source carrée (MOD-043), puis fait les contrôles du
# brief : réductions à 150 et 64 px, planche aux coins arrondis avec le cercle de 440 px, mise en grille au milieu
# des 14 icônes du benchmark (à la place de la v1) et comparaison à 150 et 64 px avec les versions d'avant.
# Lancer : py -I tools/clement/miniatures/controle_icone.py <source.png> <dossier_sortie> <ICON_Nom_vN.png> [<icône d'avant.png> ...]
#   sans icône d'avant, la comparaison se fait avec la v1.
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

MINI = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "claude", "miniatures"))
V1 = os.path.join(MINI, "2026-11-21_icone", "ICON_StealAShop_v1.png")
GRILLE_V1 = os.path.join(MINI, "2026-11-21_icone", "controle_grille.png")
FOND = (245, 246, 250)
INK = (27, 27, 36)


def arrondi(size, rayon):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=rayon, fill=255)
    return m


def police(taille):
    try:
        return ImageFont.load_default(size=taille)
    except TypeError:  # Pillow plus ancien que 10.1
        return ImageFont.load_default()


def main():
    source, dossier, nom = sys.argv[1:4]
    avant = sys.argv[4:] or [V1]
    im = Image.open(source).convert("RGB")
    w, h = im.size
    assert abs(w - h) <= 2, f"source non carrée : {w} × {h}"
    s = min(w, h)
    im = im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
    # réduction en 512, puis un léger renfort de netteté (la réduction adoucit les contours)
    icone = im.resize((512, 512), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.0, percent=35, threshold=2))
    chemin = os.path.join(dossier, nom)
    icone.save(chemin, optimize=True)
    icone.resize((150, 150), Image.LANCZOS).save(os.path.join(dossier, "controle_150px.png"))
    icone.resize((64, 64), Image.LANCZOS).save(os.path.join(dossier, "controle_64px.png"))

    # planche : 512, 150 et 64 px aux coins arrondis, cercle de 440 px
    planche = Image.new("RGB", (836, 552), FOND)
    planche.paste(icone, (20, 20), arrondi((512, 512), 46))
    for taille, x, rayon in ((150, 572, 14), (64, 752, 7)):
        planche.paste(icone.resize((taille, taille), Image.LANCZOS), (x, 20), arrondi((taille, taille), rayon))
    ImageDraw.Draw(planche).ellipse((56, 56, 496, 496), outline=(255, 255, 255), width=2)
    planche.save(os.path.join(dossier, "controle_planche.png"))

    # grille : la nouvelle icône à 150 px à la place de la v1, au milieu des 14 icônes du benchmark
    # (grille de la v1 : 5 × 3 cases de 150 px espacées de 10 px, la v1 dans la case du milieu)
    grille = Image.open(GRILLE_V1).convert("RGB")
    x0, y0 = 10 + 2 * 160, 10 + 160
    ImageDraw.Draw(grille).rectangle((x0 - 4, y0 - 4, x0 + 153, y0 + 153), fill=grille.getpixel((2, 2)))
    grille.paste(icone.resize((150, 150), Image.LANCZOS), (x0, y0), arrondi((150, 150), 14))
    grille.save(os.path.join(dossier, "controle_grille.png"))

    # comparaison avec les versions d'avant, à 150 et à 64 px (titres tirés des noms : « v1 », « v2 »…)
    versions = [(Image.open(p).convert("RGB"), p) for p in avant] + [(icone, nom)]
    comp = Image.new("RGB", (len(versions) * 180 + 10, 292), FOND)
    d = ImageDraw.Draw(comp)
    for i, (img, fichier) in enumerate(versions):
        x = 20 + i * 180
        d.text((x, 12), os.path.splitext(os.path.basename(fichier))[0].rsplit("_", 1)[-1], fill=INK, font=police(16))
        comp.paste(img.resize((150, 150), Image.LANCZOS), (x, 40), arrondi((150, 150), 14))
        comp.paste(img.resize((64, 64), Image.LANCZOS), (x + 43, 206), arrondi((64, 64), 7))
    comp.save(os.path.join(dossier, "controle_comparaison.png"))
    print("ok", chemin, icone.size, os.path.getsize(chemin), "octets")


if __name__ == "__main__":
    main()

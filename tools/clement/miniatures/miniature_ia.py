# Finit une miniature 1920 × 1080 (MOD-043) à partir d'une image déjà retouchée par l'IA (ChatGPT) : recadrage
# exact en 16:9, agrandissement, léger renfort de netteté, puis le texte du brief avec title() de
# retouche_miniature.py (Montserrat Black blanc, contour #1B1B24, ombre dure, jamais dans les 216 px du bas).
# Fait aussi les contrôles : réduction à 320 × 180, et les zones (bande des 216 px du bas, tiers) à 960 × 540.
# Lancer : py -I tools/clement/miniatures/miniature_ia.py <source.png> <dossier_sortie> "<TEXTE>" <coin> <NOM.png> [taille] [haut]
#   <TEXTE> "-" : pas de titre (PowerShell 5.1 ne transmet pas un argument vide) ; <coin> : haut-droite | haut-gauche | haut-centre ; taille : corps du texte en px
#   (158 donne 110 px de capitales) ; haut : position du haut du texte en px (60 par défaut).
# Étiquette BB_Item du jeu au-dessus d'un objet (facultative), par variables d'environnement :
#   ETIQUETTE="Crown|EPIC|COLOSSAL|+$4.9K/s"   nom, rareté, mutation (vide : pas de ligne), revenu (Format.income)
#   ETIQUETTE_CENTRE="1540,292"                 centre horizontal et ligne de base du revenu, en px
#   ETIQUETTE_TAILLES="54,40,40,100"            corps des 4 lignes, en px
#   ETIQUETTE_RARETE="#A855F7"                  couleur de la rareté (Config/Rarities)
#   ETIQUETTE_ARC_EN_CIEL=1                      revenu en arc-en-ciel (Rarities.Secret.RainbowColors) au lieu du vert
#   plusieurs étiquettes : séparer par « ; », ex. ETIQUETTE="|||+$1/s;|||+$999T/s", ETIQUETTE_CENTRE="300,500;1450,215",
#                                                ETIQUETTE_TAILLES="54,40,40,96;54,40,40,128", ETIQUETTE_ARC_EN_CIEL="0;1"
# Autres ajouts facultatifs :
#   EXCLAMATION="1000,500,150,-8"               « !! » de la bulle du vigile (BB_GuardShout) : centre x, y, corps, angle
#   FLECHE="905,170,1085,200,835,318,24"        flèche rouge courbe : départ, point de contrôle, pointe, épaisseur
#   FLECHE_ARC="250,280,125,-105,-260,30"       flèche rouge en arc de cercle : centre, rayon, angle de départ et
#                                                d'arrivée (degrés, 0 = droite, 90 = bas), épaisseur ; trait plein,
#                                                contour fin, grosse pointe (remplace FLECHE)
#   FLECHE_TETE=0.7                              taille de la pointe (1 par défaut ; plus petit pour une flèche courte)
#   FLECHE_IMAGE="chemin.png|cx|cy|taille|angle|miroir"   flèche prise dans une image à fond transparent (celle de
#                                                Clément : docs/claude/miniatures/elements/fleche_rouge_clement.png) :
#                                                centre, plus grand côté en px, rotation en degrés (sens inverse des
#                                                aiguilles d'une montre), miroir 1 = retournée gauche-droite ; plusieurs
#                                                flèches séparées par « ; »
#   RETOUCHE="1.08,1.18"                         contraste et saturation, plus un léger éclat sur les hautes lumières
#                                                (pour un rendu Blender, plus terne qu'une image de ChatGPT)
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from retouche_miniature import INK, font, title  # noqa: E402

# Couleurs de BB_Item (ReplicatedStorage/Assets/UI, relevées dans Studio le 2026-11-21) : nom blanc, mutation
# #FFC21A, revenu en dégradé vertical #D4FF5C → #2FCB1F ; police Montserrat Heavy (ici Black, la plus proche livrée).
NOM_BB = (255, 255, 255)
MUTATION_BB = (255, 194, 26)
REVENU_BB = ((212, 255, 92), (47, 203, 31))
# Arc-en-ciel du jeu (Config/Rarities, Secret.RainbowColors) ; « ! » et contour de BB_GuardShout ; rouge de son texte.
ARC_EN_CIEL = [(255, 59, 59), (255, 194, 26), (59, 225, 90), (47, 155, 255), (168, 85, 247)]
BANG = (255, 45, 85)
BANG_TRAIT = (4, 4, 53)
ROUGE_FLECHE = (227, 36, 27)


def degrade_horizontal(largeur, hauteur, couleurs):
    """Dégradé de gauche à droite passant par `couleurs`, à intervalles égaux."""
    ligne = Image.new("RGB", (max(1, largeur), 1))
    n = len(couleurs) - 1
    for x in range(largeur):
        t = x / max(1, largeur - 1) * n
        i = min(int(t), n - 1)
        k = t - i
        ligne.putpixel((x, 0), tuple(int(a + (b - a) * k) for a, b in zip(couleurs[i], couleurs[i + 1])))
    return ligne.resize((max(1, largeur), max(1, hauteur)))


def hexa(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def ligne_bb(img, texte, police, centre_x, haut, couleur):
    """Une ligne de BB_Item : texte centré, contour sombre et ombre dure (plus épais qu'en jeu, pour la miniature) ;
    couleur = (r, g, b), dégradé vertical ((haut), (bas)) ou "arc" (arc-en-ciel horizontal du jeu)."""
    d = ImageDraw.Draw(img)
    trait = max(4, int(police.size * 0.1))
    x = centre_x - d.textlength(texte, font=police) / 2
    d.text((x, haut + police.size * 0.07), texte, font=police, fill=INK, stroke_width=trait, stroke_fill=INK)
    if couleur == "arc" or isinstance(couleur[0], tuple):
        d.text((x, haut), texte, font=police, fill=INK, stroke_width=trait, stroke_fill=INK)
        masque = Image.new("L", img.size, 0)
        ImageDraw.Draw(masque).text((x, haut), texte, font=police, fill=255)
        g, t, dr, b = masque.getbbox()
        if couleur == "arc":
            degrade = degrade_horizontal(dr - g, b - t, ARC_EN_CIEL)
        else:
            degrade = Image.new("RGB", (1, b - t))
            for i in range(b - t):
                k = i / max(1, b - t - 1)
                degrade.putpixel((0, i), tuple(int(a + (c - a) * k) for a, c in zip(couleur[0], couleur[1])))
            degrade = degrade.resize((dr - g, b - t))
        img.paste(degrade, (g, t), masque.crop((g, t, dr, b)))
    else:
        d.text((x, haut), texte, font=police, fill=couleur, stroke_width=trait, stroke_fill=INK)


def etiquette(img):
    """Billboard BB_Item, dans l'ordre du jeu (LayoutOrder) : nom, rareté, mutation, revenu, aligné par le bas.
    Plusieurs étiquettes : les séparer par « ; » dans ETIQUETTE, ETIQUETTE_CENTRE et, au besoin, ETIQUETTE_TAILLES et
    ETIQUETTE_ARC_EN_CIEL (une valeur seule vaut pour toutes les étiquettes)."""
    textes = os.environ["ETIQUETTE"].split(";")

    def par_etiquette(nom, defaut):
        valeurs = os.environ.get(nom, defaut).split(";")
        return valeurs + [valeurs[-1]] * (len(textes) - len(valeurs))

    rarete = hexa(os.environ.get("ETIQUETTE_RARETE", "#A855F7"))
    for texte_e, centre, tailles_e, arc in zip(textes, par_etiquette("ETIQUETTE_CENTRE", ""),
                                               par_etiquette("ETIQUETTE_TAILLES", "54,40,40,100"),
                                               par_etiquette("ETIQUETTE_ARC_EN_CIEL", "0")):
        lignes = texte_e.split("|")
        cx, base = (int(v) for v in centre.split(","))
        tailles = [int(v) for v in tailles_e.split(",")]
        revenu = "arc" if arc.strip() == "1" else REVENU_BB
        couleurs = [NOM_BB, rarete, MUTATION_BB, revenu]
        rangs = [(t, font("Montserrat-Black.ttf", s), c) for t, s, c in zip(lignes, tailles, couleurs) if t]
        # de bas en haut : la ligne de base du revenu sur `base`, chaque ligne au-dessus d'un corps de la sienne
        hauts = []
        bas = base
        for texte, police, couleur in reversed(rangs):
            ascent, _ = police.getmetrics()
            hauts.append((texte, police, couleur, bas - ascent))
            bas -= police.size * 1.1
        for texte, police, couleur, haut in reversed(hauts):
            ligne_bb(img, texte, police, cx, haut, couleur)
            print("étiquette", repr(texte), "corps", police.size, "haut", int(haut))
    return img


def fleches_image(img):
    """Flèches prises dans une image à fond transparent, recadrée sur son contenu, retournée, tournée, mise à la
    taille voulue et posée centrée sur (cx, cy)."""
    for spec in os.environ["FLECHE_IMAGE"].split(";"):
        chemin, cx, cy, taille, angle, miroir = spec.split("|")
        f = Image.open(chemin).convert("RGBA")
        f = f.crop(f.getbbox())
        if miroir.strip() == "1":
            f = ImageOps.mirror(f)
        f = f.rotate(float(angle), resample=Image.BICUBIC, expand=True)
        f = f.crop(f.getbbox())
        k = float(taille) / max(f.size)
        f = f.resize((max(1, round(f.width * k)), max(1, round(f.height * k))), Image.LANCZOS)
        x, y = int(float(cx) - f.width / 2), int(float(cy) - f.height / 2)
        img.paste(f, (x, y), f)
        print("fleche image", (int(float(cx)), int(float(cy))), "taille", f.size, "angle", angle, "miroir", miroir.strip())
    return img


def exclamation(img):
    """« !! » dans le style du « ! » de BB_GuardShout (#FF2D55, contour #040435), un peu penché, centré sur (x, y)."""
    cx, cy, taille, angle = (float(v) for v in os.environ["EXCLAMATION"].split(","))
    police = font("Montserrat-Black.ttf", int(taille))
    trait = max(4, int(taille * 0.07))
    calque = Image.new("RGBA", (int(taille * 2.2), int(taille * 1.8)), (0, 0, 0, 0))
    d = ImageDraw.Draw(calque)
    w = d.textlength("!", font=police)
    ecart = taille * 0.12
    x0 = (calque.width - (2 * w + ecart)) / 2
    y = calque.height * 0.08
    for x in (x0, x0 + w + ecart):  # deux « ! » séparés, pour que leurs contours ne se collent pas
        d.text((x, y + taille * 0.06), "!", font=police, fill=BANG_TRAIT + (255,), stroke_width=trait, stroke_fill=BANG_TRAIT + (255,))
    for x in (x0, x0 + w + ecart):
        d.text((x, y), "!", font=police, fill=BANG + (255,), stroke_width=trait, stroke_fill=BANG_TRAIT + (255,))
    calque = calque.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.paste(calque, (int(cx - calque.width / 2), int(cy - calque.height / 2)), calque)
    print("exclamation", (int(cx), int(cy)), "corps", int(taille))
    return img


def fleche(img):
    """Flèche rouge courbe, contour sombre, pointe orientée selon la courbe. FLECHE_ARC : arc de cercle (trait plein,
    contour fin, grosse pointe) ; sinon FLECHE : courbe de Bézier quadratique."""
    points = []
    if os.environ.get("FLECHE_ARC"):
        ox, oy, rayon, a0, a1, ep = (float(v) for v in os.environ["FLECHE_ARC"].split(","))
        for i in range(361):
            a = math.radians(a0 + (a1 - a0) * i / 360)
            points.append((ox + rayon * math.cos(a), oy + rayon * math.sin(a)))
        longueur, demi, epaisseur_contour = ep * 2.6, ep * 1.9, 0.18
    else:
        x0, y0, cx, cy, x1, y1, ep = (float(v) for v in os.environ["FLECHE"].split(","))
        for i in range(241):
            t = i / 240
            points.append(((1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t ** 2 * x1, (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t ** 2 * y1))
        longueur, demi, epaisseur_contour = ep * 2.6, ep * 1.9, 0.18  # même style que l'arc (référence de Clément)
    tete = float(os.environ.get("FLECHE_TETE", "1"))  # taille de la pointe (0,7 pour une flèche courte)
    longueur, demi = longueur * tete, demi * tete
    (x0, y0), (x1, y1) = points[0], points[-1]
    # la pointe : triangle dans l'axe de la fin de courbe (tangente prise sur les derniers points)
    ax, ay = x1 - points[-12][0], y1 - points[-12][1]
    n = math.hypot(ax, ay) or 1
    ux, uy = ax / n, ay / n
    base = (x1 - ux * longueur, y1 - uy * longueur)
    pointe = [(x1 + ux * ep * 0.6, y1 + uy * ep * 0.6), (base[0] - uy * demi, base[1] + ux * demi), (base[0] + uy * demi, base[1] - ux * demi)]
    corps = [p for p in points if math.hypot(p[0] - x1, p[1] - y1) > longueur * 0.6]
    d = ImageDraw.Draw(img)
    contour = max(3, int(ep * epaisseur_contour))
    for couleur, extra in ((INK, contour), (ROUGE_FLECHE, 0)):
        # trait lisse : des disques serrés le long de la courbe (les traits larges de Pillow sont crénelés)
        r = ep / 2 + extra
        for px, py in corps:
            d.ellipse((px - r, py - r, px + r, py + r), fill=couleur)
        if extra:
            # pointe agrandie de l'épaisseur du contour
            gx = sum(p[0] for p in pointe) / 3
            gy = sum(p[1] for p in pointe) / 3
            grossi = 1 + contour * 2.2 / demi
            d.polygon([(gx + (px - gx) * grossi, gy + (py - gy) * grossi) for px, py in pointe], fill=couleur)
        else:
            d.polygon(pointe, fill=couleur)
    print("fleche", (int(x0), int(y0)), "->", (int(x1), int(y1)))
    return img


def main():
    source, dossier, texte, coin, nom = sys.argv[1:6]
    taille = int(sys.argv[6]) if len(sys.argv) > 6 else 150
    haut = int(sys.argv[7]) if len(sys.argv) > 7 else 60
    texte = texte.replace("\\n", "\n")
    im = Image.open(source).convert("RGB")
    w, h = im.size
    # recadrage exact en 16:9 (centré), puis 1920 × 1080
    if w * 9 > h * 16:
        nw = h * 16 // 9
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = w * 9 // 16
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    img = im.resize((1920, 1080), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.5, percent=50, threshold=2))
    if os.environ.get("RETOUCHE"):
        contraste, saturation = (float(v) for v in os.environ["RETOUCHE"].split(","))
        img = ImageEnhance.Color(ImageEnhance.Contrast(img).enhance(contraste)).enhance(saturation)
        eclat = img.convert("L").point(lambda v: 255 if v > 225 else 0).filter(ImageFilter.GaussianBlur(18))
        img = ImageChops.screen(img, Image.merge("RGB", (eclat, eclat, eclat)).point(lambda v: int(v * 0.35)))
    if texte.strip() not in ("", "-"):
        f = font("Montserrat-Black.ttf", taille)
        d = ImageDraw.Draw(img)
        for ligne in texte.split("\n"):
            print("ligne", repr(ligne), "largeur", int(d.textlength(ligne, font=f)), "px, capitales", int(taille * 0.7), "px")
        img = title(img, texte, coin, size=taille, top=haut)
    if os.environ.get("FLECHE") or os.environ.get("FLECHE_ARC"):
        img = fleche(img)
    if os.environ.get("FLECHE_IMAGE"):
        img = fleches_image(img)
    if os.environ.get("ETIQUETTE"):
        img = etiquette(img)
    if os.environ.get("EXCLAMATION"):
        img = exclamation(img)
    chemin = os.path.join(dossier, nom)
    img.save(chemin, optimize=True)
    poids = os.path.getsize(chemin)
    assert poids < 3 * 1024 * 1024, f"plus de 3 Mo : {poids} octets"
    img.resize((320, 180), Image.LANCZOS).save(chemin.replace(".png", "_controle_320x180.png"))
    # zones : bande du bas (216 px, couverte par le nombre de joueurs) en rouge, tiers en blanc
    voile = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dv = ImageDraw.Draw(voile)
    dv.rectangle((0, 1080 - 216, 1919, 1079), fill=(255, 40, 60, 90))
    for x in (640, 1280):
        dv.line((x, 0, x, 1079), fill=(255, 255, 255, 160), width=3)
    zones = Image.alpha_composite(img.convert("RGBA"), voile).convert("RGB")
    zones.resize((960, 540), Image.LANCZOS).save(chemin.replace(".png", "_controle_zones.png"))
    print("ok", chemin, img.size, poids // 1024, "Ko")


if __name__ == "__main__":
    main()
